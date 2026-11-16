# 커스텀 반복 '랜덤 진행' - 순열/마커/배선 진리표 (2026-08-04 확정 스펙, 설계 합의)
# 본체 순수 함수는 AST로 직접 불러와 실물 검증하고, IO/UI 계약은 소스 가드로 고정합니다.
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('ConvertTo-StrictBoolean', 'Format-CustomItemToken', 'Get-CustomFingerprint',
      'New-CustomShuffleOrder', 'Test-CustomShuffleOrder', 'Get-CustomOrderKey',
      'Get-CustomExecutionItems', 'Get-CustomRandomOrderEnabled',
      'New-CustomMarkerOwnerJson', 'Get-CustomCanonicalOwner', 'ConvertTo-CustomMarkerOwnerJson', 'Test-CustomMarkerOwnerMatchesContext')) {
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

# ── 5. 완료 마커 v3 (orderKey + 진행 세대 대조 - 진행 초기화 후 낡은 마커 오계상 방지) ──
# 세대(generation) 매트릭스는 test_custom_marker_validity(⑭)가 실제 컨텍스트로 봅니다 - 여기는 순열(orderKey) 축만
$mkContext = @{ Items = $mapItems; Order = @(1, 0, 2); Lap = 2; Index = 1; Item = $mapItems[0]; RandomOrder = $true }
$mkOwnerJson = New-CustomMarkerOwnerJson -Context $mkContext
$mkOwner = $mkOwnerJson | ConvertFrom-Json
Assert-Case '마커: 소유자 version 3' ([int]$mkOwner.version) 3
Assert-Case '마커: generation 기록 (컨텍스트에 세대 없음 = 0)' ([string]$mkOwner.generation) '0'
Assert-Case '마커: orderKey 기록' ([string]$mkOwner.orderKey) '1,0,2'
Assert-Case '마커: 동일 순열 = 일치' (Test-CustomMarkerOwnerMatchesContext -Owner $mkOwner -Context $mkContext) $true
$mkOtherOrder = @{ Items = $mapItems; Order = @(0, 1, 2); Lap = 2; Index = 1; Item = $mapItems[1]; RandomOrder = $true }
Assert-Case '마커: 다른 순열 = 불일치' (Test-CustomMarkerOwnerMatchesContext -Owner $mkOwner -Context $mkOtherOrder) $false
$mkSeqContext = @{ Items = $mapItems; Order = $null; Lap = 1; Index = 0; Item = $mapItems[0]; RandomOrder = $false }
$mkNoOrderKeyOwner = (New-CustomMarkerOwnerJson -Context $mkSeqContext) | ConvertFrom-Json
$mkNoOrderKeyOwner.PSObject.Properties.Remove('orderKey')   # orderKey 필드가 없는 소유자 객체 (대조 함수 단독 - 파일 읽기는 version 3 만이라 거절)
Assert-Case '마커 대조: orderKey 없는 소유자 = 순차와 일치(대조 함수의 선택 처리 유지)' `
  (Test-CustomMarkerOwnerMatchesContext -Owner $mkNoOrderKeyOwner -Context $mkSeqContext) $true
Assert-Case '마커 대조: orderKey 없는 소유자 - 랜덤 컨텍스트와 불일치' `
  (Test-CustomMarkerOwnerMatchesContext -Owner $mkNoOrderKeyOwner -Context (@{ Items = $mapItems; Order = @(0, 1, 2); Lap = 1; Index = 0; Item = $mapItems[0]; RandomOrder = $true })) $false

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
# 스키마 11(10-08): 마커 읽기는 version 3 만 - version 2 이하는 진행 세대가 없어 지금 진행의 기록인지 증명할 수 없음 (설계 v10 1.7)
$readOwnerBody = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
      -Names @('Read-CustomMarkerOwner')))
Assert-Case '가드: 마커 읽기는 version 3 만 인정 + 필수 6필드(orderKey·generation 포함) + 세대 정수 판정 · 옛 v1/v2 허용 없음' `
  ('{0}/{1}/{2}/{3}' -f ($readOwnerBody -match '\(\[int\]\$owner\.version -ne 3\)'),
    ($readOwnerBody -match "@\('fingerprint', 'orderKey', 'lap', 'index', 'item', 'generation'\)"),
    ($readOwnerBody -match "\(\[string\]\`$owner\.generation\) -notmatch '\^\\d\+\$'"),
    ($readOwnerBody -match '@\(1, 2\)')) 'True/True/True/False'
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
Assert-Case 'config: schema 12' ([int]$configJson.configSchemaVersion) 12   # ui.theme 신설(12) ← 10-08 커스텀 진행 세대 progressGeneration 신설(11) ← 09-25 revive.maxPerCycle 제거·checkpointReviveLimit 신설(10) ← life 신설(5) → '채집 대기' 의미 변경(6) → 가방/도구 옵션 제거(7) → 반복 모드 저장(8) → etc(기타) 신설(9)
Assert-Case 'config: randomOrder 기본 false 4섹션' `
  (($configJson.customRepeat.randomOrder -eq $false) -and ($configJson.deepCustomRepeat.randomOrder -eq $false) -and ($configJson.abyssCustomRepeat.randomOrder -eq $false) -and ($configJson.lifeCustomRepeat.randomOrder -eq $false)) $true

# ── 비랜덤 현재 행 표시 (2026-08-15 사용자 요청 - 헤드리스 ListView 실물 검증, 리뷰 조건) ──
# 계약: 재배열·번호 표기·열 폭 불변 / 현재 행만 크림색 / 생활은 등록 순번 행 / 정지 후 전체 복원
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Get-CustomActiveListView', 'Set-CustomListRandomView', 'Restore-CustomListRegisteredView')) {
  Invoke-Expression $definition
}
$script:crLoading = $false
$script:customViewShuffled = $false
$lvCrList = New-Object System.Windows.Forms.ListView
$lvCrList.View = 'Details'
[void]$lvCrList.Columns.Add('', 24)
[void]$lvCrList.Columns.Add('#', 32)
[void]$lvCrList.Columns.Add('내용', 120)
foreach ($rowNo in 1..3) {
  $lvRow = New-Object System.Windows.Forms.ListViewItem('')
  [void]$lvRow.SubItems.Add([string]$rowNo)
  [void]$lvRow.SubItems.Add('항목' + $rowNo)
  [void]$lvCrList.Items.Add($lvRow)
}
$lvAcrList = $lvCrList; $lvDcrList = $lvCrList; $lvLcrList = $lvCrList
$creamArgb = [System.Drawing.Color]::FromArgb(245, 231, 201).ToArgb()
# 행 색은 팔레트 변수(themeListRow · themeListCurrent - 2026-11-12 다크 모드)라 팔레트 함수를 소스에서 꺼내 라이트로 정합니다. 위 크림 리터럴은
# 그대로 둡니다 - 기대값을 소스에서 캡처하면 라이트 값이 바뀌어도 기대가 따라가 '라이트는 지금과 같다' 를 지키지 못합니다(다크 모드 설계 v3 H11)
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') -Names @('Get-HoneyPaletteTable', 'Set-HoneyPalette')) {
  Invoke-Expression $definition
}
Set-HoneyPalette -Theme 'light'
Set-CustomListRandomView -Context @{ RandomOrder = $false; RegisteredTotal = 3; Index = 1; SectionName = 'customRepeat' }
Assert-Case '비랜덤 표시: 현재(2번) 행만 크림색' `
  (($lvCrList.Items[1].BackColor.ToArgb() -eq $creamArgb) -and ($lvCrList.Items[0].BackColor.ToArgb() -ne $creamArgb) -and ($lvCrList.Items[2].BackColor.ToArgb() -ne $creamArgb)) $true
Assert-Case '비랜덤 표시: 행 순서·번호 텍스트 불변' `
  ((($lvCrList.Items | ForEach-Object { $_.SubItems[1].Text + $_.SubItems[2].Text }) -join '|')) '1항목1|2항목2|3항목3'
Assert-Case '비랜덤 표시: # 열 폭 불변 (32)' ([int]$lvCrList.Columns[1].Width) 32
Set-CustomListRandomView -Context @{ RandomOrder = $false; RegisteredTotal = 3; Index = 2; SectionName = 'customRepeat' }
Assert-Case '비랜덤 표시: 진행 이동 시 하이라이트 이동 (2번 해제, 3번 크림)' `
  (($lvCrList.Items[1].BackColor.ToArgb() -ne $creamArgb) -and ($lvCrList.Items[2].BackColor.ToArgb() -eq $creamArgb)) $true
# 생활 비랜덤: 실행 칸 Index 가 아니라 등록 순번(RegisteredIndex) 행을 칠한다 (반복 횟수로
# 펼친 칸이 진행돼도 같은 등록 행 유지)
Set-CustomListRandomView -Context @{ RandomOrder = $false; RegisteredTotal = 3; Index = 5; RegisteredIndex = 0; SectionName = 'lifeCustomRepeat' }
Assert-Case '비랜덤 표시(생활): 등록 순번 행(1번) 크림 - 펼친 칸 번호 무시' `
  (($lvCrList.Items[0].BackColor.ToArgb() -eq $creamArgb) -and ($lvCrList.Items[2].BackColor.ToArgb() -ne $creamArgb)) $true
Restore-CustomListRegisteredView
Assert-Case '비랜덤 표시: 정지 복원 - 전 행 White + Tag 해제 + 플래그 해제' `
  ((@($lvCrList.Items | Where-Object { $_.BackColor.ToArgb() -eq $creamArgb }).Count -eq 0) -and ($null -eq $lvCrList.Items[0].Tag) -and (-not $script:customViewShuffled)) $true
# 행 수 불일치(화면-config 어긋남)면 표시만 생략 - Tag/플래그도 건드리지 않음
Set-CustomListRandomView -Context @{ RandomOrder = $false; RegisteredTotal = 4; Index = 0; SectionName = 'customRepeat' }
Assert-Case '비랜덤 표시: 행 수 불일치면 생략 (플래그 미설정)' ([bool]$script:customViewShuffled) $false


# ── 9. 다음 판 이어받기 env NX (구현 명세 ⑤b5 3.1 crandom ⑨ · ⑤b6 3.1 crandom §9 · dev:982 ⑨ · 사용자 결정 U-⑤-2 (가) · 2026-10-26 '랜덤 + 섞인 리스트 바퀴 경계 = 필드') ──
# GUI Get-CustomNextHandoffEnv(순수)의 두 값 - NEXT_OWNER = 같은 바퀴 다음 칸(index+1)의 owner JSON / 바퀴 끝 판(1항목 리스트는 매 판)이면 빈 값 · NEXT_BOUNDARY '1' 또는 'mixed'.
#   Owner 는 워커 원문 ConvertTo-AbyssJournalOwner 로 되읽어(어비스 보상 결정이 실제로 읽는 길) 지금 판 owner(같은 컨텍스트의 New-CustomMarkerOwnerJson)와 지문 · 순서 키 ·
#   바퀴 · 세대가 같고 index 가 +1 · item 이 실행 순서 다음 칸 토큰인지 봅니다. 랜덤 바퀴 끝은 빈 값이어야 합니다 - 다음 바퀴의 새 순열을 미리 가정한 owner 를 만들면
#   FAIL(dev:982 'NEXT_OWNER 에 다음 바퀴 순열 가정 → FAIL')
# ⑤b6: 랜덤 진행(순열 있음 또는 랜덤 켬)의 바퀴 끝 판에서 등록 항목의 입장 방식(어비스 토큰의 방식 · 공백 뺀 매칭)이 둘 이상이면 NEXT_BOUNDARY 'mixed' - 다음 바퀴 첫 칸
#   (새 순열)의 입장 방식을 아직 모르므로 워커 보상 결정이 ④ 'next-unknown' 으로 '나가기' 합니다. 순차 바퀴 끝 · 입장 방식이 한 가지인 랜덤 · 어비스가 아닌 리스트는
#   '1' 그대로입니다(순차 바퀴 끝 NEXT 는 다음 바퀴 첫 칸이라 워커가 ⑤ 로 대조). 'mixed' · '1' 기대는 계약 열거값이고, EQ 는 GUI 원문 함수의 'mixed' 와 워커 원문 해석
#   (ConvertFrom-AbyssCustomItemSpec)의 입장 방식 다름이 같은지 6×6 쌍으로 봅니다(사본 재구현 금지). 가드는 'mixed' 계산이 바퀴 끝 갈래 안에만 있고 순열 생성이 없는지 AST 로 봅니다
$nxHandoffFnText = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') -Names @('Get-CustomNextHandoffEnv'))
Invoke-Expression $nxHandoffFnText
foreach ($definition in @(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('ConvertTo-AbyssJournalOwner', 'ConvertFrom-AbyssCustomItemSpec'))) { Invoke-Expression $definition }
$nxA = [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '없음' }
$nxB = [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '없음' }
$nxC = [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '입문'; dungeon = '흩어진 물길'; matching = '우연한 만남' }
# ⑤b6 픽스처: 혼자하기 매칭 빈 값(토큰은 '없음') · 우연한 만남 공백 없는 표기 · 파티 찾기 두 표기 · 파티장 (워커 해석이 받는 던전 · 난이도만)
$nxBBlank = [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '' }
$nxCNs = [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '우연한만남' }
$nxFindSp = [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '파티 찾기' }
$nxFindNs = [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '흩어진 물길'; matching = '파티찾기' }
$nxLead = [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '파티(파티장)' }
function New-NxContext {
  # Start-NextCycle 이 쓰는 컨텍스트 모양(Items · ExecutionItems · Order · RandomOrder · Total · Lap · Index · Item · Generation) - 랜덤이면 실행 순서 = 원문 Get-CustomExecutionItems.
  # RandomOrder 를 주지 않으면 순열이 있을 때만 참입니다(Get-CustomCurrentContext 는 랜덤이고 저장 순열이 유효할 때만 Order 를 채움 - 랜덤 켬 · 순열 없음은 NX10 이 직접 줌)
  param([object[]]$Items, $Order, [int]$Lap, [int]$Index, [int]$Generation, $RandomOrder = $null)
  $executionItems = $Items
  if ($null -ne $Order) { $executionItems = @(Get-CustomExecutionItems -Items $Items -Order $Order) }
  $randomFlag = $(if ($null -eq $RandomOrder) { $null -ne $Order } else { [bool]$RandomOrder })
  return @{ Items = $Items; ExecutionItems = $executionItems; Order = $Order; RandomOrder = $randomFlag; Total = @($executionItems).Count; Lap = $Lap; Index = $Index; Item = @($executionItems)[$Index]; Generation = $Generation }
}
function Get-NxRow {
  # 한 행 → '경계 [b] · owner <빈 값 | 되읽음 · 지문/순서키/바퀴/세대 같음 · index · item>' (되읽기는 워커 원문)
  param($Context)
  $nx = Get-CustomNextHandoffEnv -Context $Context
  if ([string]::IsNullOrEmpty([string]$nx.Owner)) { return ('경계 [{0}] · owner 빈 값 · 되읽음 {1}' -f $nx.Boundary, [int]($null -ne (ConvertTo-AbyssJournalOwner -OwnerJson ([string]$nx.Owner)))) }
  $parsed = ConvertTo-AbyssJournalOwner -OwnerJson ([string]$nx.Owner)
  if ($null -eq $parsed) { return ('경계 [{0}] · owner 되읽기 실패' -f $nx.Boundary) }
  $current = (New-CustomMarkerOwnerJson -Context $Context) | ConvertFrom-Json
  $same = ([string]$parsed.Owner.fingerprint -ceq [string]$current.fingerprint) -and ([string]$parsed.Owner.orderKey -ceq [string]$current.orderKey) -and
    ([int]$parsed.Owner.lap -eq [int]$current.lap) -and ([int]$parsed.Generation -eq [int]$current.generation)
  return ('경계 [{0}] · owner 되읽음 · 지문·순서키·바퀴·세대 같음 {1} · index {2} · item {3} · 순서키 [{4}] · 세대 {5}' -f $nx.Boundary, $same, $parsed.Owner.index, $parsed.Owner.item,
      $parsed.Owner.orderKey, $parsed.Generation)
}
$nxTokenA = Format-CustomItemToken -Item $nxA
$nxTokenB = Format-CustomItemToken -Item $nxB
Assert-Case 'NX1 순차 [A,A,B] 1바퀴 index 0(세대 3) → 경계 빈 값 · 다음 칸 index 1 · item A' (Get-NxRow (New-NxContext @($nxA, $nxA, $nxB) $null 1 0 3)) `
  ('경계 [] · owner 되읽음 · 지문·순서키·바퀴·세대 같음 True · index 1 · item {0} · 순서키 [] · 세대 3' -f $nxTokenA)
Assert-Case 'NX2 순차 [A,A,B] index 1 → 다음 칸 index 2 · item B' (Get-NxRow (New-NxContext @($nxA, $nxA, $nxB) $null 1 1 3)) `
  ('경계 [] · owner 되읽음 · 지문·순서키·바퀴·세대 같음 True · index 2 · item {0} · 순서키 [] · 세대 3' -f $nxTokenB)
Assert-Case 'NX3 순차 [A,A,B] index 2(바퀴 끝 판) → 경계 1 · owner 빈 값(다음 바퀴 owner 를 만들지 않음 - U-⑤-2 (가))' (Get-NxRow (New-NxContext @($nxA, $nxA, $nxB) $null 1 2 3)) '경계 [1] · owner 빈 값 · 되읽음 0'
Assert-Case 'NX4 1항목 [A] (매 판 바퀴 끝) → 경계 1 · owner 빈 값' (Get-NxRow (New-NxContext @($nxA) $null 4 0 0)) '경계 [1] · owner 빈 값 · 되읽음 0'
Assert-Case 'NX5 랜덤 [A,B,C] 순열 2,0,1 · 2바퀴 index 0(세대 1) → 다음 칸 = 실행 순서 index 1(등록 0번 A) · 순서키 그대로' (Get-NxRow (New-NxContext @($nxA, $nxB, $nxC) @(2, 0, 1) 2 0 1)) `
  ('경계 [] · owner 되읽음 · 지문·순서키·바퀴·세대 같음 True · index 1 · item {0} · 순서키 [2,0,1] · 세대 1' -f $nxTokenA)
Assert-Case 'NX6 랜덤 [A,B,C](혼자 · 혼자 · 우연) 순열 2,0,1 · index 2(바퀴 끝 판) → 경계 mixed(입장 방식이 섞인 랜덤 바퀴 끝 - ⑤b6) · owner 빈 값(다음 바퀴 순열 가정 0)' (Get-NxRow (New-NxContext @($nxA, $nxB, $nxC) @(2, 0, 1) 2 2 1)) '경계 [mixed] · owner 빈 값 · 되읽음 0'
Assert-Case 'NX6s 랜덤 [혼자, 혼자](매칭 없음 · 빈 값) 순열 1,0 · 바퀴 끝 판 → 경계 1(입장 방식 한 가지) · owner 빈 값' (Get-NxRow (New-NxContext @($nxA, $nxBBlank) @(1, 0) 2 1 1)) '경계 [1] · owner 빈 값 · 되읽음 0'
Assert-Case 'NX7 반환 = 해시 1개 · 키 Boundary,Owner' ('{0} · {1}' -f @(Get-CustomNextHandoffEnv -Context (New-NxContext @($nxA, $nxB) $null 1 0 0)).Count,
  ((@((Get-CustomNextHandoffEnv -Context (New-NxContext @($nxA, $nxB) $null 1 0 0)).Keys) | Sort-Object) -join ',')) '1 · Boundary,Owner'
# ⑤b6 'mixed' 경계 (구현 명세 ⑤b6 1.10 · G10): 랜덤 진행의 바퀴 끝 판 · 입장 방식이 섞인 리스트만 'mixed'
Assert-Case 'NX8 순차 [혼자, 우연] 바퀴 끝 판 → 경계 1(순차는 섞여도 1 - NEXT 가 다음 바퀴 첫 칸 그대로라 입장 방식 대조는 워커) · owner 빈 값' (Get-NxRow (New-NxContext @($nxA, $nxC) $null 1 1 0)) '경계 [1] · owner 빈 값 · 되읽음 0'
Assert-Case 'NX9 랜덤 [A,B,C](섞임) 순열 2,0,1 · index 1(바퀴 중간) → 경계 빈 값 · owner 있음(다음 칸 index 2 · item B)' (Get-NxRow (New-NxContext @($nxA, $nxB, $nxC) @(2, 0, 1) 2 1 1)) `
  ('경계 [] · owner 되읽음 · 지문·순서키·바퀴·세대 같음 True · index 2 · item {0} · 순서키 [2,0,1] · 세대 1' -f $nxTokenB)
Assert-Case 'NX10 랜덤 켬 · 순열 없음(손상) · [혼자, 우연] 바퀴 끝 판 → 경계 mixed · owner 빈 값' (Get-NxRow (New-NxContext @($nxA, $nxC) $null 1 1 0 $true)) '경계 [mixed] · owner 빈 값 · 되읽음 0'
Assert-Case 'NX11 던전 랜덤 [1-1 어려움, 1-1 입문] 순열 1,0 · 바퀴 끝 판 → 경계 1(어비스 토큰이 아니면 한 종류)' (Get-NxRow (New-NxContext @($mapItems[0], $mapItems[1]) @(1, 0) 1 1 0)) '경계 [1] · owner 빈 값 · 되읽음 0'
Assert-Case 'NX12 랜덤 [우연한 만남, 우연한만남](매칭 공백 표기 둘) 순열 1,0 · 바퀴 끝 판 → 경계 1(공백 무시)' (Get-NxRow (New-NxContext @($nxC, $nxCNs) @(1, 0) 1 1 0)) '경계 [1] · owner 빈 값 · 되읽음 0'
# EQ - 원문 GUI 경계 함수를 두 항목 랜덤 바퀴 끝 문맥으로 불러 'mixed' ⇔ 워커 원문 해석(ConvertFrom-AbyssCustomItemSpec)의 입장 방식(Mode · Matching) 다름 - 다르게 나온 쌍을 이어 적습니다
$eqItems = [ordered]@{ 'solo빈' = $nxBBlank; 'solo없음' = $nxA; '우연' = $nxC; '찾기공백' = $nxFindSp; '찾기붙임' = $nxFindNs; '파티장' = $nxLead }
$eqBad = @()
foreach ($eqKeyA in @($eqItems.Keys)) {
  foreach ($eqKeyB in @($eqItems.Keys)) {
    $eqGuiMixed = ([string](Get-CustomNextHandoffEnv -Context (New-NxContext @($eqItems[$eqKeyA], $eqItems[$eqKeyB]) @(0, 1) 1 1 0)).Boundary -ceq 'mixed')
    $eqParsedA = ConvertFrom-AbyssCustomItemSpec -Spec (Format-CustomItemToken -Item $eqItems[$eqKeyA])
    $eqParsedB = ConvertFrom-AbyssCustomItemSpec -Spec (Format-CustomItemToken -Item $eqItems[$eqKeyB])
    if (($null -eq $eqParsedA) -or ($null -eq $eqParsedB)) { $eqBad += ('{0}/{1}(해석 실패)' -f $eqKeyA, $eqKeyB); continue }
    $eqWorkerDiff = -not (([string]$eqParsedA.Mode -ceq [string]$eqParsedB.Mode) -and ([string]$eqParsedA.Matching -ceq [string]$eqParsedB.Matching))
    if ($eqGuiMixed -ne $eqWorkerDiff) { $eqBad += ('{0}/{1}' -f $eqKeyA, $eqKeyB) }
  }
}
Assert-Case "EQ GUI 경계 함수의 'mixed' = 워커 해석의 입장 방식 다름(6×6 쌍)" ($eqBad -join ',') ''
# 가드(AST - 주석 무관): 'mixed' 계산(등록 항목 열거 · 'mixed' 글자)은 바퀴 끝 갈래(if ($nextIndex -ge [int]$Context.Total)) 안에서만 하고, 이 함수는 순열을 만들거나
#   실행 순서를 다시 매핑하지 않습니다(다음 바퀴 순열 가정 0 - NX6 의 owner 빈 값과 같은 계약)
$nxFnTokens = $null; $nxFnErrors = $null
$nxFnAst = [System.Management.Automation.Language.Parser]::ParseInput($nxHandoffFnText, [ref]$nxFnTokens, [ref]$nxFnErrors)
$nxEndIf = $nxFnAst.Find({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -ceq '$nextIndex -ge [int]$Context.Total') }, $true)
$nxEndBlock = $(if ($null -ne $nxEndIf) { $nxEndIf.Clauses[0].Item2 } else { $null })
function Test-NxInsideEndBlock {
  # 노드가 바퀴 끝 갈래의 몸통 안에 있는지 (같은 파싱 결과의 문자 위치로 비교)
  param($Node)
  return (($null -ne $nxEndBlock) -and ($Node.Extent.StartOffset -ge $nxEndBlock.Extent.StartOffset) -and ($Node.Extent.EndOffset -le $nxEndBlock.Extent.EndOffset))
}
$nxMixedConsts = @($nxFnAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and ($node.Value -ceq 'mixed') }, $true))
$nxItemLoops = @($nxFnAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.ForEachStatementAst]) -and ($node.Condition.Extent.Text -match '\$Context\.Items\b') }, $true))
$nxShuffleCalls = @($nxFnAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and (@('New-CustomShuffleOrder', 'Get-CustomExecutionItems', 'Get-Random') -contains $node.GetCommandName()) }, $true))
Assert-Case "가드(⑤b6): Get-CustomNextHandoffEnv - 'mixed' 계산은 바퀴 끝 갈래 안에서만(갈래 1 · 'mixed' 글자 1 · 그중 갈래 안 1 · 등록 항목 열거 갈래 안 1 · 갈래 밖 0) · 순열 생성 · 매핑 호출 0" `
  ('{0}/{1}/{2}/{3}/{4}/{5}' -f [int]($null -ne $nxEndIf), $nxMixedConsts.Count, @($nxMixedConsts | Where-Object { Test-NxInsideEndBlock -Node $_ }).Count,
    @($nxItemLoops | Where-Object { Test-NxInsideEndBlock -Node $_ }).Count, @($nxItemLoops | Where-Object { -not (Test-NxInsideEndBlock -Node $_) }).Count, $nxShuffleCalls.Count) '1/1/1/1/0/0'
# 가드(주석 뺀 GUI 사본): Start-NextCycle 이 OWNER 와 같은 $customContext 로 부름(호출 1 · 두 env 대입은 그 결과의 Owner · Boundary) · Clear-CustomEnv 목록에 두 env
$nxNextCycle = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') -Names @('Start-NextCycle')))
Assert-Case '가드(⑤b5): Start-NextCycle - OWNER 와 같은 $customContext 로 다음 판 env 계산 1곳 · NEXT_OWNER/NEXT_BOUNDARY 는 그 결과 그대로' `
  ('{0}/{1}/{2}/{3}' -f [regex]::Matches($nxNextCycle, '\$env:HONEYNOGI_CUSTOM_OWNER = New-CustomMarkerOwnerJson -Context \$customContext').Count,
    [regex]::Matches($nxNextCycle, '\$customNextHandoff = Get-CustomNextHandoffEnv -Context \$customContext').Count,
    [regex]::Matches($nxNextCycle, '\$env:HONEYNOGI_CUSTOM_NEXT_OWNER = \$customNextHandoff\.Owner').Count,
    [regex]::Matches($nxNextCycle, '\$env:HONEYNOGI_CUSTOM_NEXT_BOUNDARY = \$customNextHandoff\.Boundary').Count) '1/1/1/1'
$nxClearEnv = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') -Names @('Clear-CustomEnv')))
Assert-Case '가드(⑤b5): Clear-CustomEnv 목록에 NEXT_OWNER · NEXT_BOUNDARY (비커스텀 다음 회차 워커에 앞 실행 값이 남지 않게)' `
  ('{0}/{1}' -f ($nxClearEnv -match "'HONEYNOGI_CUSTOM_NEXT_OWNER'"), ($nxClearEnv -match "'HONEYNOGI_CUSTOM_NEXT_BOUNDARY'")) 'True/True'
exit $fails
