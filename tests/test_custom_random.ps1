# 커스텀 반복 '랜덤 진행' - 순열/마커/배선 진리표 (2026-08-04 확정 스펙, 설계 합의)
# 본체 순수 함수는 AST로 직접 불러와 실물 검증하고, IO/UI 계약은 소스 가드로 고정합니다.
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('ConvertTo-StrictBoolean', 'Format-CustomItemToken', 'Get-CustomFingerprint',
      'New-CustomShuffleOrder', 'Test-CustomShuffleOrder', 'Get-CustomOrderKey',
      'Get-CustomExecutionItems', 'Get-CustomRandomOrderEnabled',
      'New-CustomMarkerOwnerJson', 'Test-CustomMarkerOwnerMatchesContext')) {
  Invoke-Expression $definition
}
$guiSource = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_gui.ps1'))

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 1. 순열 검증 진리표 ─────────────────────────────────────────────────────────
Assert-Case '순열: 정상 치환 인정' (Test-CustomShuffleOrder -Order @(2, 0, 1) -ItemCount 3) $true
Assert-Case '순열: 길이 불일치 거부' (Test-CustomShuffleOrder -Order @(0, 1) -ItemCount 3) $false
Assert-Case '순열: 중복 거부' (Test-CustomShuffleOrder -Order @(0, 0, 1) -ItemCount 3) $false
Assert-Case '순열: 범위 밖 거부' (Test-CustomShuffleOrder -Order @(0, 1, 3) -ItemCount 3) $false
Assert-Case '순열: 정수 아님 거부' (Test-CustomShuffleOrder -Order @('a', 1, 2) -ItemCount 3) $false
Assert-Case '순열: null 거부' (Test-CustomShuffleOrder -Order $null -ItemCount 3) $false
Assert-Case '순열: 0항목 거부' (Test-CustomShuffleOrder -Order @() -ItemCount 0) $false
Assert-Case '순열: 1항목 [0] 인정' (Test-CustomShuffleOrder -Order @(0) -ItemCount 1) $true

# ── 2. 순열 생성 ────────────────────────────────────────────────────────────────
Assert-Case '생성: 1항목 = [0]' ((@(New-CustomShuffleOrder -ItemCount 1) -join ',')) '0'
Assert-Case '생성: 6항목 = 유효한 치환' (Test-CustomShuffleOrder -Order @(New-CustomShuffleOrder -ItemCount 6) -ItemCount 6) $true
Assert-Case '생성: 0항목 = 빈 배열' (@(New-CustomShuffleOrder -ItemCount 0).Count) 0

# ── 3. 실행 순서 매핑 (중복 항목 = 인덱스 치환으로 정확히 1회씩) ─────────────────
$mapItems = @(
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-1'; coin = $true; doubleLoot = $false; exhaustContinue = $true; noDoubleSweep = $false },
  [pscustomobject]@{ difficulty = '입문'; stage = '1-1'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false },
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-2'; coin = $true; doubleLoot = $false; exhaustContinue = $true; noDoubleSweep = $false }
)
$mapped = @(Get-CustomExecutionItems -Items $mapItems -Order @(2, 0, 1))
Assert-Case '매핑: 순서 재배열' (($mapped | ForEach-Object { $_.stage + $_.difficulty }) -join '|') '1-2어려움|1-1어려움|1-1입문'
$dupItems = @($mapItems[0], $mapItems[0], $mapItems[1])
$dupMapped = @(Get-CustomExecutionItems -Items $dupItems -Order @(1, 2, 0))
Assert-Case '매핑: 중복 항목도 3개 유지' $dupMapped.Count 3
Assert-Case '순서키: null = 빈 문자열(순차)' (Get-CustomOrderKey -Order $null) ''
Assert-Case '순서키: 배열 = 콤마 결합' (Get-CustomOrderKey -Order @(2, 0, 1)) '2,0,1'

# ── 4. randomOrder 읽기 (JSON 불리언만) ─────────────────────────────────────────
Assert-Case '설정: 불리언 true 인정' (Get-CustomRandomOrderEnabled -Node ([pscustomobject]@{ randomOrder = $true })) $true
Assert-Case '설정: 문자열 true 불인정' (Get-CustomRandomOrderEnabled -Node ([pscustomobject]@{ randomOrder = 'true' })) $false
Assert-Case '설정: 키 없음 = false' (Get-CustomRandomOrderEnabled -Node ([pscustomobject]@{})) $false

# ── 5. 완료 마커 v2 (orderKey 대조 - 진행 초기화 후 낡은 마커 오계상 방지) ────────
$mkContext = @{ Items = $mapItems; Order = @(1, 0, 2); Lap = 2; Index = 1; Item = $mapItems[0]; RandomOrder = $true }
$mkOwnerJson = New-CustomMarkerOwnerJson -Context $mkContext
$mkOwner = $mkOwnerJson | ConvertFrom-Json
Assert-Case '마커: 소유자 version 2' ([int]$mkOwner.version) 2
Assert-Case '마커: orderKey 기록' ([string]$mkOwner.orderKey) '1,0,2'
Assert-Case '마커: 동일 순열 = 일치' (Test-CustomMarkerOwnerMatchesContext -Owner $mkOwner -Context $mkContext) $true
$mkOtherOrder = @{ Items = $mapItems; Order = @(0, 1, 2); Lap = 2; Index = 1; Item = $mapItems[1]; RandomOrder = $true }
Assert-Case '마커: 다른 순열 = 불일치' (Test-CustomMarkerOwnerMatchesContext -Owner $mkOwner -Context $mkOtherOrder) $false
$mkSeqContext = @{ Items = $mapItems; Order = $null; Lap = 1; Index = 0; Item = $mapItems[0]; RandomOrder = $false }
$mkV1Owner = (New-CustomMarkerOwnerJson -Context $mkSeqContext) | ConvertFrom-Json
$mkV1Owner.PSObject.Properties.Remove('orderKey')   # v1 마커 모사 (orderKey 필드 없음)
Assert-Case '마커: v1(orderKey 없음) - 순차와 일치(하위 호환)' `
  (Test-CustomMarkerOwnerMatchesContext -Owner $mkV1Owner -Context $mkSeqContext) $true
Assert-Case '마커: v1 - 랜덤 컨텍스트와 불일치' `
  (Test-CustomMarkerOwnerMatchesContext -Owner $mkV1Owner -Context (@{ Items = $mapItems; Order = @(0, 1, 2); Lap = 1; Index = 0; Item = $mapItems[0]; RandomOrder = $true })) $false

# ── 6. 소스 계약 가드 (IO/UI 배선) ──────────────────────────────────────────────
Assert-Case '가드: Step - 바퀴 전환만 새 순열' `
  ($guiSource -match 'if \(\[int\]\$next\.index -eq 0\) \{\s+\$stepShuffle = @\(New-CustomShuffleOrder') $true
Assert-Case '가드: Step - 같은 바퀴는 기존 순열 검증 후 복사(손상 시 정지)' `
  ($guiSource -match 'Test-CustomShuffleOrder -Order \$stepShuffle -ItemCount \$items\.Count\)\)[\s\S]{0,300}진행을 전진시키지 못했습니다') $true
Assert-Case '가드: 시작 게이트 배선(순열 선확보 - 마커 복구 검사 전)' `
  ($guiSource -match 'if \(-not \(Confirm-CustomShuffleReady\)\)') $true
Assert-Case '가드: 게이트 - 바퀴 중간 순열 손상은 전체 초기화' `
  ($guiSource -match '처음\(1바퀴\)부터 새로 시작') $true
Assert-Case '가드: 게이트 - 층 혼합 config 는 랜덤 해제 정규화' `
  ($guiSource -match '혼합 리스트는 랜덤 진행을 쓸 수 없어 해제') $true
Assert-Case '가드: 워커 NEXT/LIST 는 실행 순서 기준' `
  ([regex]::Matches($guiSource, '\$customContext\.ExecutionItems').Count -ge 3) $true
Assert-Case '가드: 마커 읽기 v1/v2 인정' `
  ($guiSource -match '@\(1, 2\) -notcontains \[int\]\$owner\.version') $true
# 2026-08-09 감사: 마커 삭제가 전역($customMarkerFile = 마지막으로 시작한 섹션)을 쓰고 있어
# 다른 콘텐츠의 유효 마커를 파괴했습니다. 이 계약을 '섹션별 마커'로 격상합니다.
# 무효화는 공용 계약(Clear-CustomMarkerFile: 삭제 → 확인 → '{}')을 거칩니다.
# 단순 Remove-Item + SilentlyContinue 는 파일이 잠겼을 때 실패를 조용히 삼켜, progress 만
# 초기화되고 옛 마커는 살아 있는 불일치를 만듭니다 (2026-08-09 리뷰).
Assert-Case '가드: 진행 초기화 시 그 섹션 마커만 무효화' `
  ($guiSource -match '커스텀 진행 초기화 저장 실패[\s\S]{0,900}Clear-CustomMarkerFile -Path \(Get-CustomMarkerFileForSection -SectionName \$SectionName\)') $true
Assert-Case '가드: 랜덤 토글도 그 섹션 마커만 무효화' `
  ($guiSource -match '랜덤 진행 설정 저장 실패[\s\S]{0,500}Clear-CustomMarkerFile -Path \(Get-CustomMarkerFileForSection -SectionName \$SectionName\)') $true
Assert-Case '가드: 무효화 계약은 단일 함수' `
  ([regex]::Matches($guiSource, '(?m)^function Clear-CustomMarkerFile').Count) 1
Assert-Case '가드: 무효화 실패를 삼키지 않음(호출부가 반환값 확인)' `
  ([regex]::Matches($guiSource, 'if \(-not \(Clear-CustomMarkerFile -Path').Count -ge 2) $true
# 전역 $customMarkerFile('마지막으로 시작한 섹션')은 시작/종료 흐름에서만 정당합니다.
# SectionName 을 파라미터로 받는 함수 안에서는 컨텍스트가 갈라지므로 금지합니다.
foreach ($sectionScopedFn in @('Reset-CustomProgress', 'Save-CustomRandomOrder')) {
  $fnBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
      -Names @($sectionScopedFn))
  # 주석에서 전역 이름을 '설명하는' 것은 위반이 아니므로 주석 줄은 빼고 검사합니다
  $fnBody = (($fnBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
  Assert-Case "가드: $sectionScopedFn 은 전역 마커를 참조하지 않음" `
    ($fnBody -match '\$customMarkerFile') $false
  Assert-Case "가드: $sectionScopedFn 은 섹션 매핑 함수로 마커를 고름" `
    ($fnBody -match 'Get-CustomMarkerFileForSection -SectionName \$SectionName') $true
}
Assert-Case '가드: 섹션→마커 매핑은 단일 함수' `
  ([regex]::Matches($guiSource, '(?m)^function Get-CustomMarkerFileForSection').Count) 1
# 진리표: 섹션 X 를 초기화하면 X 마커만 사라지고 나머지 3종은 보존돼야 합니다
Invoke-Expression ((Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Get-CustomMarkerFileForSection')) -join "`n")
$customDungeonMarkerFile = 'D:\dungeon.marker'
$customAbyssMarkerFile = 'D:\abyss.marker'
$customDeepMarkerFile = 'D:\deep.marker'
$customLifeMarkerFile = 'D:\life.marker'
foreach ($markerCase in @(
    @{ Section = 'customRepeat'; Expected = 'D:\dungeon.marker' },
    @{ Section = 'abyssCustomRepeat'; Expected = 'D:\abyss.marker' },
    @{ Section = 'deepCustomRepeat'; Expected = 'D:\deep.marker' },
    @{ Section = 'lifeCustomRepeat'; Expected = 'D:\life.marker' },
    @{ Section = ''; Expected = 'D:\dungeon.marker' })) {
  Assert-Case "진리표: 섹션 '$($markerCase.Section)' → 자기 마커" `
    (Get-CustomMarkerFileForSection -SectionName $markerCase.Section) $markerCase.Expected
}
Assert-Case '가드: 정지 시 등록 순서 표기 복원(모든 경로 공용)' `
  ($guiSource -match 'if \(-not \$IsRunning\) \{ Restore-CustomListRegisteredView \}') $true
Assert-Case '가드: 저장 함수는 Tag 정렬로 등록 순서 보존 4곳(던전/어비스/심층/생활)' `
  ([regex]::Matches($guiSource, 'if \(\$script:customViewShuffled\) \{ \$\w+SourceRows').Count) 4
Assert-Case '가드: 랜덤 토글 4개 생성' `
  ([regex]::Matches($guiSource, '\$chk(Cr|Acr|Dcr|Lcr)Random = New-Object System\.Windows\.Forms\.CheckBox').Count) 4
Assert-Case '가드: 토글 배치 - 버튼 열 5번째(listTop+144) 4곳' `
  ([regex]::Matches($guiSource, 'Random\.Top = \$\w+ListTop \+ 144').Count) 4
Assert-Case '가드: 반복 줄 30px 하향(listTop+186) 4곳' `
  ([regex]::Matches($guiSource, 'Repeat\.Top = \$\w+ListTop \+ 186').Count) 4
Assert-Case '가드: 저장 노드에 randomOrder 4섹션' `
  ([regex]::Matches($guiSource, 'randomOrder     = \[bool\]\$chk\w+Random\.Checked').Count) 4
Assert-Case '가드: 층 혼합 게이트 호출 6곳(저장2+롤백2+로드2)' `
  ([regex]::Matches($guiSource, 'Update-CustomRandomMixGate -Toggle').Count) 6
Assert-Case '가드: 랜덤 상태 표기((랜덤) 접미)' `
  ($guiSource -match "\`$positionText \+= ' \(랜덤\)'") $true
Assert-Case '가드: 회차 시작 시 섞인 순서 표시 배선' `
  ($guiSource -match 'Set-CustomListRandomView -Context \$customContext') $true

# config.json 기본 키
$configJson = Get-Content (Join-Path $projectRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
# 스키마는 **새 설정 키를 추가할 때마다** 올려야 합니다. 안 올리면 기존 사용자는 이전 게이트에
# 걸려 새 키를 영영 못 받습니다 (2026-08-10 실기에서 repeat.mode/untilTime 으로 적발).
Assert-Case 'config: schema 8' ([int]$configJson.configSchemaVersion) 8   # v2.0.0: life 신설(5) → '채집 대기' 의미 변경(6) → 가방/도구 옵션 제거(7) → 반복 모드 저장(8)
Assert-Case 'config: randomOrder 기본 false 4섹션' `
  (($configJson.customRepeat.randomOrder -eq $false) -and ($configJson.deepCustomRepeat.randomOrder -eq $false) -and ($configJson.abyssCustomRepeat.randomOrder -eq $false) -and ($configJson.lifeCustomRepeat.randomOrder -eq $false)) $true

exit $fails
