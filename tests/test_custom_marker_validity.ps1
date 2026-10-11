# 완료 마커는 '파일이 있는가'가 아니라 '지금 항목의 유효한 소유자 마커인가'로 판단해야 한다
# (2026-08-09 6차 점검에서 신설).
#
# 무엇이 문제였나:
#   Clear-CustomMarkerFile 은 파일이 잠겨 삭제가 막히면 내용을 '{}' 로 덮어 **소유자 형식을
#   무효화**하고 성공으로 끝냅니다. 그게 그 폴백의 목적입니다. 그런데 종료 코드 처리부는
#   Test-Path 만 봤습니다. 그러면 남은 '{}' 파일이 '이번 판 클리어 확정'으로 읽혀,
#   **돌지도 않은 항목을 완료로 계상하고 건너뜁니다**(코드 4 경로) / **마무리 복구로
#   잘못 분기합니다**(코드 1 경로).
#
#   기존 잠금 테스트는 FileShare::Read 로 열어 삭제와 쓰기를 **둘 다** 막았기 때문에
#   '{}' 분기 자체가 한 번도 실행되지 않았습니다. 여기서는 FileShare::ReadWrite 로 열어
#   **삭제만 막고 쓰기는 허용**해 그 분기를 실제로 태웁니다.
#
# 2026-10-08 스키마 11(설계 v10 1.7 · 구현 명세 ① 2.2): 마커 owner 가 version 3(5필드 + 진행 세대 generation)이 됐습니다.
#   컨텍스트를 스텁 대신 **실제 Get-CustomCurrentContext**(Read-Config 스텁 + 섹션 config)로 만들어, 세대를 config 노드에서
#   읽는 코드까지 그대로 탑니다. ⑭ 매트릭스 = 섹션 3 × version 2/3 × 세대(키 없음/0/일치/불일치/역행 - 역행은 2026-10-09 변이 검증 보강).
$ErrorActionPreference = 'Stop'
$fails = 0

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw "GUI 파서 오류: $($parseErrors[0].Message)" }
foreach ($name in @('Format-CustomItemToken', 'Get-CustomFingerprint', 'Get-CustomOrderKey',
    'ConvertTo-StrictBoolean', 'Get-CustomRandomOrderEnabled', 'Get-CustomPositionText', 'Get-CustomCurrentContext',
    'New-CustomMarkerOwnerJson', 'Get-CustomCanonicalOwner', 'ConvertTo-CustomMarkerOwnerJson', 'Read-CustomMarkerOwner', 'Test-CustomMarkerOwnerMatchesContext',
    'Test-CustomMarkerValidForCurrent', 'Get-CustomMarkerStaleFile', 'Clear-CustomMarkerFile')) {
  $fn = $ast.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true) | Select-Object -First 1
  if (-not $fn) { throw "본체 함수를 찾지 못했습니다: $name" }
  Invoke-Expression $fn.Extent.Text
}

$testRoot = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),
  ('honeynogi_marker_test_' + [guid]::NewGuid().ToString('N')))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
$customMarkerFile = [System.IO.Path]::Combine($testRoot, 'custom_done.marker')

# 현재 항목 컨텍스트는 실제 Get-CustomCurrentContext 가 메모리 config 에서 만듭니다 (GUI 전역 상태를 끌어오지 않고 계약만 봅니다).
# Read-Config 스텁이 $script:testConfig 를 돌려주고, $null 이면 '설정 파일을 못 읽음' 과 같습니다.
$items = @(
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-3'; coin = $true; doubleLoot = $true },
  [pscustomobject]@{ difficulty = '일반'; stage = '2-1'; coin = $false; doubleLoot = $false }
)
function New-TestSectionNode {
  # 커스텀 섹션 노드(순차·무한). -Generation 을 생략하면 progressGeneration 키 자체가 없습니다(스키마 11 이전 config 와 같음)
  param($Items, $Generation = $null, [int]$Lap = 1, [int]$Index = 0)
  $node = [pscustomobject]@{
    items = [array]$Items; randomOrder = $false; listRepeat = 'infinite'; listRepeatCount = 1
    progress = [pscustomobject]@{ lap = $Lap; index = $Index; fingerprint = (Get-CustomFingerprint -Items $Items) }
  }
  if ($null -ne $Generation) { $node | Add-Member -NotePropertyName 'progressGeneration' -NotePropertyValue $Generation }
  return $node
}
$script:testConfig = [pscustomobject]@{ customRepeat = (New-TestSectionNode -Items $items) }
function Read-Config { return $script:testConfig }
$script:customConfigSection = 'customRepeat'
$script:lastGuiLog = ''
function Add-GuiLog { param([string]$Message) $script:lastGuiLog = $Message }

try {
  # ── ① 유효한 소유자 마커는 인정 ─────────────────────────────────────────────
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context (Get-CustomCurrentContext)))
  Assert-Case '정상: 이번 항목의 마커면 유효' (Test-CustomMarkerValidForCurrent) $true

  # ── ② 다른 항목/바퀴의 마커는 거절 ──────────────────────────────────────────
  $otherContext = [pscustomobject]@{ Items = $items; Order = $null; Lap = 1; Index = 1; Item = $items[1] }
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context $otherContext))
  Assert-Case '거절: 다음 항목의 마커는 무효' (Test-CustomMarkerValidForCurrent) $false
  $nextLap = [pscustomobject]@{ Items = $items; Order = $null; Lap = 2; Index = 0; Item = $items[0] }
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context $nextLap))
  Assert-Case '거절: 다음 바퀴의 마커는 무효' (Test-CustomMarkerValidForCurrent) $false

  # ── ③ 파일이 없으면 당연히 무효 ─────────────────────────────────────────────
  Remove-Item -LiteralPath $customMarkerFile -Force
  Assert-Case '없음: 파일이 없으면 무효' (Test-CustomMarkerValidForCurrent) $false

  # ── ④ ★ '{}' 무효화 폴백이 남긴 파일은 완료로 계상되면 안 된다 ───────────────
  # ※ 이 상태를 **파일 잠금으로는 만들 수 없습니다.** 실측(2026-08-09, 공유 모드 10조합):
  #     공유 Read / Write / ReadWrite  → 삭제 X, Set-Content 도 X (IOException)
  #     공유 Delete / ReadWrite+Delete → 삭제 O (그러면 폴백에 안 들어감)
  #   즉 PS 5.1 의 Set-Content 는 남의 핸들이 DELETE 공유를 안 주면 쓰기도 실패합니다.
  #   그래서 '삭제 실패 + 쓰기 성공'은 잠금이 아니라 **ACL(삭제 거부·쓰기 허용)이나
  #   두 호출 사이에 잠금이 풀리는 타이밍**으로만 생깁니다 - 테스트로 재현하기엔 불안정합니다.
  #   폴백을 억지로 태우는 대신 **그 분기가 남기는 최종 상태**를 직접 만들어 검증합니다.
  #   방어의 본질은 '어떻게 그 파일이 생겼나'가 아니라 '그 파일을 완료로 세지 않는가'입니다.
  [System.IO.File]::WriteAllText($customMarkerFile, '{}')
  Assert-Case '폴백: Test-Path 는 참(옛 판정이 속던 지점)' (Test-Path -LiteralPath $customMarkerFile) $true
  Assert-Case '폴백: 소유자 판독은 null' ($null -eq (Read-CustomMarkerOwner)) $true
  # ★ 여기가 6차에서 닫은 구멍입니다. 파일은 있지만 완료로 계상하면 안 됩니다.
  Assert-Case '폴백: 유효 마커로 인정하지 않음' (Test-CustomMarkerValidForCurrent) $false

  # 잠금으로 둘 다 막히는 경우는 기존 계약(실패 반환 + 묘비)이 그대로여야 합니다
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context (Get-CustomCurrentContext)))
  $lock = [System.IO.File]::Open($customMarkerFile, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try { $cleared = Clear-CustomMarkerFile -Path $customMarkerFile }
  finally { $lock.Dispose() }
  Assert-Case '잠금: 무효화 실패를 정직하게 반환' $cleared $false
  Assert-Case '잠금: 묘비 생성' (Test-Path -LiteralPath (Get-CustomMarkerStaleFile -Path $customMarkerFile)) $true
  Remove-Item -LiteralPath (Get-CustomMarkerStaleFile -Path $customMarkerFile) -Force -ErrorAction SilentlyContinue

  # ── ⑤ 부분 파일/구버전 형식도 거절 ──────────────────────────────────────────
  [System.IO.File]::WriteAllText($customMarkerFile, '2026-08-09 12:00:00')   # v1 타임스탬프 마커
  Assert-Case '거절: 구버전 타임스탬프 마커' (Test-CustomMarkerValidForCurrent) $false
  # 필수 필드 누락 (version·정수 세대는 맞게 - 필드 검사만 보이게. 2026-10-09 변이 검증 보강: 예전 픽스처 '{"version":3,"lap":1}' 은
  #   세대도 없어 세대 정수 판정이 대신 거절했고, 필드 검사를 무력화한 변이가 살아남았습니다)
  [System.IO.File]::WriteAllText($customMarkerFile, '{"version":3,"generation":0,"lap":1}')
  Assert-Case '거절: 필수 필드 누락 - 판독 null · 무효' ('{0}/{1}' -f ($null -eq (Read-CustomMarkerOwner)), (Test-CustomMarkerValidForCurrent)) 'True/False'
  # 필드 하나(orderKey)만 빠진 version 3 - 대조 함수는 orderKey 없음을 ''(순차)로 보므로(명세 5절 C10) 순차 컨텍스트에서는 읽기가
  #   거르지 않으면 유효 마커로 인정됩니다
  $noOrderKeyOwner = (New-CustomMarkerOwnerJson -Context (Get-CustomCurrentContext)) | ConvertFrom-Json
  $noOrderKeyOwner.PSObject.Properties.Remove('orderKey')
  $noOrderKeyJson = $noOrderKeyOwner | ConvertTo-Json -Compress
  [System.IO.File]::WriteAllText($customMarkerFile, $noOrderKeyJson)
  Assert-Case '거절: orderKey 만 빠진 version 3 - 판독 null · 무효' ('{0}/{1}' -f ($null -eq (Read-CustomMarkerOwner)), (Test-CustomMarkerValidForCurrent)) 'True/False'
  [System.IO.File]::WriteAllText($customMarkerFile, '{ 깨진 json')
  Assert-Case '거절: 깨진 JSON' (Test-CustomMarkerValidForCurrent) $false

  # ── ⑤-2 ★ 판단 불가(컨텍스트 없음)와 무효를 구분한다 (7차 점검) ──────────────
  # Get-CustomCurrentContext 는 부를 때마다 config 를 디스크에서 다시 읽습니다. 그 읽기가
  # 한 번 실패하면 $null 입니다. 이걸 '무효'로 처리하면 **정당하게 끝낸 판을 안 세고 그
  # 항목을 한 번 더 돌립니다** = 재화 이중 소모. 6차 수정이 새로 만든 위험이라 여기서 막습니다.
  # 단, 판단 불가여도 **소유자 형식이 아닌 것('{}')은 여전히 거절**해야 합니다 - 안 그러면
  # 6차에서 닫은 구멍이 이 경로로 다시 열립니다.
  $validOwnerJson = New-CustomMarkerOwnerJson -Context (Get-CustomCurrentContext)
  $savedConfig = $script:testConfig
  $script:testConfig = $null   # 설정 파일 읽기 실패 → 실제 Get-CustomCurrentContext 가 $null
  $script:lastGuiLog = ''
  [System.IO.File]::WriteAllText($customMarkerFile, $validOwnerJson)
  Assert-Case '판단불가: 컨텍스트가 정말 $null' ($null -eq (Get-CustomCurrentContext)) $true
  Assert-Case '판단불가: 소유자 형식이면 인정(이중 소모 방지)' (Test-CustomMarkerValidForCurrent) $true
  Assert-Case '판단불가: 그 사실을 경고로 남긴다' `
    ([bool]($script:lastGuiLog -match '커스텀 진행 정보를 읽지 못해')) $true
  [System.IO.File]::WriteAllText($customMarkerFile, '{}')
  Assert-Case "판단불가: 그래도 '{}' 는 거절(6차 구멍 재개방 방지)" (Test-CustomMarkerValidForCurrent) $false
  [System.IO.File]::WriteAllText($customMarkerFile, '2026-08-09 12:00:00')
  Assert-Case '판단불가: 구버전 타임스탬프도 거절' (Test-CustomMarkerValidForCurrent) $false
  # 스키마 11: 판단 불가여도 version 2 마커(세대 없음 - 이전 버전이 쓴 모양)는 소유자 형식이 아니라 거절
  [System.IO.File]::WriteAllText($customMarkerFile, '{"version":2,"fingerprint":"x","orderKey":"","lap":1,"index":0,"item":"y"}')
  Assert-Case '판단불가: version 2 마커도 거절' (Test-CustomMarkerValidForCurrent) $false
  # 이 경로는 소유자 형식만으로 인정하므로 읽기의 필수 필드 검사가 유일한 문턱입니다 - version 3 + 정수 세대만 맞고 필드가 빠진 것도
  #   거절해야 합니다(2026-10-09 변이 검증 보강 - 필드 검사를 무력화해도 이 경로에서 완료로 계상되던 구멍)
  [System.IO.File]::WriteAllText($customMarkerFile, '{"version":3,"generation":0,"lap":1}')
  Assert-Case '판단불가: version 3 + 세대만 있고 필수 필드가 빠진 마커는 거절' (Test-CustomMarkerValidForCurrent) $false
  [System.IO.File]::WriteAllText($customMarkerFile, $noOrderKeyJson)
  Assert-Case '판단불가: orderKey 만 빠진 version 3 도 거절' (Test-CustomMarkerValidForCurrent) $false
  $script:testConfig = $savedConfig

  # ── ⑭ 섹션 × version × 진행 세대 매트릭스 (스키마 11 - 설계 v10 1.7) ────────────────
  # 진행 세대 = 그 섹션 config 노드의 progressGeneration(키 없음 = 0), 진행 초기화마다 1씩 오릅니다. 순차 목록은 초기화 뒤
  # 1바퀴 0번이 5필드 그대로 다시 맞아서, 세대가 없으면 초기화 전에 남은 마커가 지금 판의 마무리로 오인됩니다(유료 판
  # 오계상·오복구). 기대: version 3 + 세대 일치만 참 / 세대 불일치 거짓 / version 2 는 6필드를 다 갖춰도 거절.
  # 마커는 손으로 쓰지 않고 **실제 New-CustomMarkerOwnerJson 이 실제 컨텍스트로 만든 JSON** 입니다 - 쓰는 쪽이 generation 을
  # 빠뜨리면 version 3 행이 거짓이 되어 잡힙니다. version 2 행은 그 JSON 의 version 만 2 로 바꾼 것입니다(읽기 문턱만 보이게).
  $abyssItems = @(
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '없음' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '입문'; dungeon = '허상의 정박지'; matching = '우연한 만남' }
  )
  $deepItems = @(
    [pscustomobject]@{ difficulty = '어려움'; stage = '1-2'; coin = $true; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false },
    [pscustomobject]@{ difficulty = '어려움'; stage = '1-3'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
  )
  $matrixSections = @(
    @{ Name = 'customRepeat'; Items = $items },
    @{ Name = 'abyssCustomRepeat'; Items = $abyssItems },
    @{ Name = 'deepCustomRepeat'; Items = $deepItems })
  # Write = 마커를 쓸 때의 config 세대($null = 키 없음) / Check = 판정할 때의 세대. 불일치 = 마커를 쓴 뒤 진행 초기화로 세대가 오른 경우.
  # 역행 = 마커 세대가 지금보다 높은 경우(옛 config 사본으로 되돌린 뒤 등) - 계약은 '같음' 이라 이것도 거짓입니다(2026-10-09 변이 검증 보강:
  #   불일치 행이 '마커 < 지금' 하나뿐이면 비교를 '-ge' 로 바꿔도 같은 답이었습니다)
  $generationCases = @(
    @{ Case = '키 없음'; Write = $null; Check = $null; ExpectV3 = $true },
    @{ Case = '0'; Write = 0; Check = 0; ExpectV3 = $true },
    @{ Case = '일치(5)'; Write = 5; Check = 5; ExpectV3 = $true },
    @{ Case = '불일치(마커 4 · 지금 5)'; Write = 4; Check = 5; ExpectV3 = $false },
    @{ Case = '역행(마커 6 · 지금 5)'; Write = 6; Check = 5; ExpectV3 = $false })
  foreach ($matrixSection in $matrixSections) {
    $sectionName = [string]$matrixSection.Name
    $script:customConfigSection = $sectionName
    $customMarkerFile = [System.IO.Path]::Combine($testRoot, "$sectionName.marker")
    foreach ($markerVersion in @(2, 3)) {
      foreach ($generationCase in $generationCases) {
        # 다른 두 섹션은 세대 7 로 둡니다 - 컨텍스트가 지금 섹션 노드의 세대만 읽는지(다른 섹션 값이 새지 않는지)
        $script:testConfig = [pscustomobject]@{}
        foreach ($otherSection in $matrixSections) {
          $script:testConfig | Add-Member -NotePropertyName ([string]$otherSection.Name) `
            -NotePropertyValue (New-TestSectionNode -Items $otherSection.Items -Generation 7 -Lap 2 -Index 1)
        }
        $script:testConfig.$sectionName = New-TestSectionNode -Items $matrixSection.Items -Generation $generationCase.Write -Lap 2 -Index 1
        $ownerJson = New-CustomMarkerOwnerJson -Context (Get-CustomCurrentContext)
        if ($markerVersion -eq 2) {
          $ownerObject = $ownerJson | ConvertFrom-Json
          $ownerObject.version = 2
          $ownerJson = $ownerObject | ConvertTo-Json -Compress
        }
        [System.IO.File]::WriteAllText($customMarkerFile, $ownerJson)
        $script:testConfig.$sectionName = New-TestSectionNode -Items $matrixSection.Items -Generation $generationCase.Check -Lap 2 -Index 1
        $expectValid = (($markerVersion -eq 3) -and [bool]$generationCase.ExpectV3)
        Assert-Case ('⑭ {0} · version {1} · 세대 {2}' -f $sectionName, $markerVersion, $generationCase.Case) `
          ([bool](Test-CustomMarkerValidForCurrent)) $expectValid
      }
    }
  }
  # 키 없는 섹션의 Generation 은 $null 이 아니라 [int] 0 이어야 합니다 - PS 5.1 은 [int]$null 이 0 이라 비교 예외로는 드러나지
  # 않으므로(구현 명세 ① 5절 C 정정) 형식과 값을 직접 봅니다
  $script:customConfigSection = 'customRepeat'
  $script:testConfig = [pscustomobject]@{ customRepeat = (New-TestSectionNode -Items $items) }
  $noKeyContext = Get-CustomCurrentContext
  Assert-Case '⑭ 키 없는 섹션: 컨텍스트 Generation 은 [int] 0' ('{0}/{1}' -f ($noKeyContext.Generation -is [int]), $noKeyContext.Generation) 'True/0'
  $script:testConfig.customRepeat = New-TestSectionNode -Items $items -Generation 5
  $keyContext = Get-CustomCurrentContext
  Assert-Case '⑭ 키 있는 섹션: 컨텍스트 Generation 은 [int] 5' ('{0}/{1}' -f ($keyContext.Generation -is [int]), $keyContext.Generation) 'True/5'
  $script:testConfig.customRepeat = New-TestSectionNode -Items $items -Generation 'abc'
  Assert-Case '⑭ 세대를 정수로 못 읽으면 0' ((Get-CustomCurrentContext).Generation) 0
  # 마커 owner JSON 왕복: generation 은 정수, 필드 순서·개수 = version + 5필드 + generation
  $ownerRoundTrip = (New-CustomMarkerOwnerJson -Context $keyContext) | ConvertFrom-Json
  Assert-Case '⑭ owner JSON: version 3 + 5필드 + generation(정수 5)' `
    ('{0}|{1}|{2}' -f (($ownerRoundTrip.PSObject.Properties | ForEach-Object { $_.Name }) -join ','), $ownerRoundTrip.version, $ownerRoundTrip.generation.GetType().Name) `
    'version,fingerprint,orderKey,lap,index,item,generation|3|Int32'
  # 읽기 문턱: 세대 키 없는 version 3 · 정수가 아닌 세대는 소유자 형식이 아님
  $customMarkerFile = [System.IO.Path]::Combine($testRoot, 'custom_done.marker')
  $canonicalOwner = (New-CustomMarkerOwnerJson -Context $keyContext) | ConvertFrom-Json
  $canonicalOwner.PSObject.Properties.Remove('generation')
  [System.IO.File]::WriteAllText($customMarkerFile, ($canonicalOwner | ConvertTo-Json -Compress))
  Assert-Case '⑭ 읽기: generation 없는 version 3 은 $null' ($null -eq (Read-CustomMarkerOwner)) $true
  foreach ($badGeneration in @('"5x"', '-1', '1.5', 'true', 'null', '"abc"')) {
    $badJson = ($ownerRoundTrip | ConvertTo-Json -Compress) -replace '"generation":5', ('"generation":' + $badGeneration)
    [System.IO.File]::WriteAllText($customMarkerFile, $badJson)
    Assert-Case ('⑭ 읽기: 정수가 아닌 세대({0})는 null' -f $badGeneration) `
      ('{0}/{1}' -f ($badJson -ne ($ownerRoundTrip | ConvertTo-Json -Compress)), ($null -eq (Read-CustomMarkerOwner))) 'True/True'
  }
  # -Path: 10→11 이전 블록은 섹션별 마커 경로를 넘겨 읽습니다 (기본 = 전역 $customMarkerFile)
  $otherMarkerPath = [System.IO.Path]::Combine($testRoot, 'abyss_by_path.marker')
  [System.IO.File]::WriteAllText($otherMarkerPath, ($ownerRoundTrip | ConvertTo-Json -Compress))
  Remove-Item -LiteralPath $customMarkerFile -Force -ErrorAction SilentlyContinue
  Assert-Case '⑭ 읽기 -Path: 전역 마커 없음이어도 넘긴 경로를 읽음' `
    ('{0}/{1}' -f ($null -eq (Read-CustomMarkerOwner)), [int](Read-CustomMarkerOwner -Path $otherMarkerPath).generation) 'True/5'

  # ── ⑥ 배선: 종료 코드 처리부가 Test-Path 가 아니라 유효성으로 판단하는가 ─────
  $guiRaw = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
  Assert-Case '배선: 코드 4 완료 계상이 유효성으로 판단' `
    ($guiRaw -match '\$script:customActive -and -not \$script:customMarkerIgnore -and \(Test-CustomMarkerValidForCurrent\)') $true
  Assert-Case '배선: 코드 1 마무리 복구도 유효성으로 판단' `
    ($guiRaw -match '\(\(-not \$script:customMarkerIgnore\) -and \(Test-CustomMarkerValidForCurrent\)\)') $true
  # 종료 코드 처리부에 맨 Test-Path 판정이 남아 있으면 같은 구멍이 다시 열립니다
  Assert-Case '배선: 종료 코드 처리부에 맨 Test-Path 마커 판정 없음' `
    ([regex]::Matches($guiRaw, '(?:customMarkerIgnore\)? -and \(Test-Path -LiteralPath \$customMarkerFile\))').Count) 0
  # 이어가기 복구와 **같은 판정**을 써야 계상과 복구가 어긋나지 않습니다
  Assert-Case '배선: 이어가기 복구도 같은 소유자 판정을 사용' `
    ($guiRaw -match 'Test-CustomMarkerOwnerMatchesContext -Owner \$markerOwner -Context \$resumeContext') $true
  # ★ 시작 게이트도 '판단 불가'와 '불일치'를 구분해야 합니다 (2026-08-10 8차 점검).
  #   7차는 종료 코드 경로에만 그 구분을 넣었는데, 시작 게이트는 컨텍스트가 $null 이면
  #   '불일치'로 보고 **정당한 완료 마커를 디스크에서 지웁니다.** 종료 코드 경로는 계상만
  #   건너뛰고 마커는 남기지만 이쪽은 되돌릴 수 없어 더 파괴적입니다 - 이미 클리어한 판을
  #   처음부터 다시 돌아 재화를 이중 소모합니다.
  Assert-Case '배선: 시작 게이트가 컨텍스트 읽기를 재시도한다' `
    ($guiRaw -match '(?s)\$resumeContext = Get-CustomCurrentContext\s*\r?\n\s*for \(\$ctxTry = 1; \$ctxTry -le 3 -and -not \$resumeContext') $true
  Assert-Case '배선: 판단 불가면 마커를 지우지 않고 시작을 멈춘다' `
    ($guiRaw -match '(?s)if \(\$markerOwner -and -not \$resumeContext\) \{[\s\S]{0,400}?완료 기록을 지우지 않고 시작을 멈춥니다[\s\S]{0,200}?return') $true
  # 그 분기가 마커 폐기(Clear-CustomMarkerFile)보다 **앞**에 있어야 의미가 있습니다
  $gateIdx = $guiRaw.IndexOf('if ($markerOwner -and -not $resumeContext) {')
  $clearIdx = $guiRaw.IndexOf('현재 진행 위치와 맞지 않는 이전 완료 마커를 정리했습니다')
  Assert-Case '배선: 보호 분기가 마커 폐기보다 앞' `
    ([bool]($gateIdx -ge 0 -and $clearIdx -gt $gateIdx)) $true
} finally {
  Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit $fails
