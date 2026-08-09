# config 원자적 저장 + 구조 버전 마이그레이션 회귀 테스트
# 본체 함수를 AST로 직접 추출해 검사하므로 테스트 사본과 운영 구현이 어긋나지 않습니다.
$ErrorActionPreference = 'Stop'
$fails = 0

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$guiPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'mabinogi_gui.ps1'
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw "GUI 파서 오류: $($parseErrors[0].Message)" }
  foreach ($name in @('Read-Config', 'ConvertTo-StrictBoolean', 'Write-Utf8FileAtomic', 'Save-Config', 'Update-ConfigToLatest',
    'Format-CustomItemToken', 'Get-CustomFingerprint', 'Get-CustomNextProgress',
    'Step-CustomProgress', 'Reset-CustomProgress', 'Get-CustomMarkerFileForSection', 'Clear-CustomMarkerFile',
    'Get-CustomMarkerStaleFile', 'Test-CustomMarkerStale',
    'Get-CustomRandomOrderEnabled', 'New-CustomShuffleOrder', 'Test-CustomShuffleOrder')) {
  $fn = $ast.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true) | Select-Object -First 1
  if (-not $fn) { throw "본체 함수를 찾지 못했습니다: $name" }
  Invoke-Expression $fn.Extent.Text
}

function Add-GuiLog {
  param([string]$Message)
  $script:lastGuiLog = $Message
}

$testRoot = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),
  ('honeynogi_config_test_' + [guid]::NewGuid().ToString('N')))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
$scriptRoot = $testRoot
$configPath = [System.IO.Path]::Combine($testRoot, 'config.json')
$defaultPath = [System.IO.Path]::Combine($testRoot, 'config.default.json')
$customMarkerFile = [System.IO.Path]::Combine($testRoot, 'custom_marker.json')   # 시작 시 결정되는 전역(마지막 시작 섹션)
# 2026-08-09 감사: Reset-CustomProgress 는 전역이 아니라 $SectionName 에 해당하는 마커만
# 지워야 합니다 (Get-CustomMarkerFileForSection). 섹션별 경로를 실제 파일로 두고 검증합니다.
$customDungeonMarkerFile = [System.IO.Path]::Combine($testRoot, 'custom_done.marker')
$customAbyssMarkerFile = [System.IO.Path]::Combine($testRoot, 'abyss_custom_done.marker')
$customDeepMarkerFile = [System.IO.Path]::Combine($testRoot, 'deep_custom_done.marker')
$customLifeMarkerFile = [System.IO.Path]::Combine($testRoot, 'life_custom_done.marker')
$utf8Bom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true

try {
  Assert-Case '엄격 불리언: JSON false 유지' (ConvertTo-StrictBoolean $false $true) $false
  Assert-Case '엄격 불리언: 문자열 false는 기본값 사용' (ConvertTo-StrictBoolean 'false' $false) $false
  Assert-Case '엄격 불리언: 숫자 0은 기본값 사용' (ConvertTo-StrictBoolean 0 $true) $true

  # 1) 대상 파일이 없을 때 생성 + 한글/BOM 보존
  Save-Config ([pscustomobject]@{ value = '첫 저장'; nested = [pscustomobject]@{ ok = $true } })
  $created = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '원자저장: 새 파일 생성' $created.value '첫 저장'
  $bytes = [System.IO.File]::ReadAllBytes($configPath)
  Assert-Case '원자저장: UTF-8 BOM' ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) $true

  # 2) 기존 파일 교체
  Save-Config ([pscustomobject]@{ value = '교체 저장'; nested = [pscustomobject]@{ ok = $true } })
  $replaced = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '원자저장: 기존 파일 교체' $replaced.value '교체 저장'

  # 3) 대상 파일을 교체 불가 상태로 잠갔을 때 예외 전파 + 기존 파일 보존
  $lock = [System.IO.File]::Open($configPath, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  $saveFailed = $false
  try { Save-Config ([pscustomobject]@{ value = '덮어쓰면 안 됨' }) }
  catch { $saveFailed = $true }
  finally { $lock.Dispose() }
  Assert-Case '원자저장: 잠금 실패 예외 전파' $saveFailed $true
  $afterFailure = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '원자저장: 실패 시 기존 파일 보존' $afterFailure.value '교체 저장'
  $leftovers = @(Get-ChildItem -LiteralPath $testRoot | Where-Object {
      $_.Name -like '*.tmp' -or $_.Name -like '*.tmp.bak'
    })
  Assert-Case '원자저장: 임시 파일 정리' $leftovers.Count 0

  # 4) 자동 이전 실패와 '이전 불필요'를 구분할 수 있도록 실패 원인을 보존
  [System.IO.File]::WriteAllText($defaultPath, '{잘못된 JSON', $utf8Bom)
  $migrationFailed = Update-ConfigToLatest
  Assert-Case '구조이전: 잘못된 기본 설정은 false 반환' $migrationFailed $false
  Assert-Case '구조이전: 실패 원인 보존' `
    (-not [string]::IsNullOrWhiteSpace($script:configMigrationError)) $true

  # 5) 좌표 버전이 같아도 구조 버전이 낮으면 마이그레이션하고 ui 값을 보존
  # (schema 3 = 2026-07-28 심층던전 섹션 추가 - deepDungeon/deepCustomRepeat 이전 검증 포함)
  $defaultConfig = [pscustomobject]@{
    configSchemaVersion = 4
    coordsVersion = 6
    ui = [pscustomobject]@{ logFontSize = 9; settingsOpen = $false; logOpen = $false }
    diagnostics = [pscustomobject]@{ keepScreenshots = 10 }
    revive = [pscustomobject]@{ enabled = $false }
    afterEntry = [pscustomobject]@{ keys = @([pscustomobject]@{ key = 32; enabled = $false }) }
    customRepeat = [pscustomobject]@{ randomOrder = $false; progress = $null }
    abyssCustomRepeat = [pscustomobject]@{ randomOrder = $false; items = @(); listRepeat = 'infinite'; listRepeatCount = 1; progress = $null }
    deepDungeon = [pscustomobject]@{ difficulty = '어려움'; stage = '1-1'; useTribute = $false; continueWithoutTribute = $false; matching = '우연한 만남' }
    deepCustomRepeat = [pscustomobject]@{ randomOrder = $false; items = @(); listRepeat = 'infinite'; listRepeatCount = 1; progress = $null }
  }
  $userConfig = [pscustomobject]@{
    coordsVersion = 6
    ui = [pscustomobject]@{ logFontSize = 17; settingsOpen = $true; logOpen = $true }
    diagnostics = [pscustomobject]@{ keepScreenshots = 7 }
    revive = [pscustomobject]@{ enabled = 'true' }
    afterEntry = [pscustomobject]@{ keys = @([pscustomobject]@{ key = 32; enabled = 'true' }) }
    customRepeat = [pscustomobject]@{ progress = $null }
  }
  [System.IO.File]::WriteAllText($defaultPath, ($defaultConfig | ConvertTo-Json -Depth 10), $utf8Bom)
  [System.IO.File]::WriteAllText($configPath, ($userConfig | ConvertTo-Json -Depth 10), $utf8Bom)
  $migrated = Update-ConfigToLatest
  $migrationResult = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '구조이전: schemaVersion만 낮아도 실행' $migrated $true
  Assert-Case '구조이전: 최신 schemaVersion 적용' $migrationResult.configSchemaVersion 4
  Assert-Case '구조이전: 어비스 커스텀 기본 섹션 추가' ($null -ne $migrationResult.abyssCustomRepeat) $true
  Assert-Case '구조이전: 심층던전 기본 섹션 추가' ($null -ne $migrationResult.deepDungeon) $true
  Assert-Case '구조이전: 심층 커스텀 기본 섹션 추가' ($null -ne $migrationResult.deepCustomRepeat) $true
  Assert-Case '구조이전: ui.logFontSize 보존' $migrationResult.ui.logFontSize 17
  # 탭 토글 표시 상태 보존 (2026-08-04 신설 - 기본 config 에 키가 있어야 이전에서 보존됨)
  Assert-Case '구조이전: ui.settingsOpen 보존' $migrationResult.ui.settingsOpen $true
  Assert-Case '구조이전: randomOrder 기본 보충(false)' $migrationResult.deepCustomRepeat.randomOrder $false
  Assert-Case '구조이전: ui.logOpen 보존' $migrationResult.ui.logOpen $true
  Assert-Case '구조이전: 다른 사용자 설정 보존' $migrationResult.diagnostics.keepScreenshots 7
  Assert-Case '구조이전: 문자열 revive 불리언은 최신 기본값 유지' $migrationResult.revive.enabled $false
  Assert-Case '구조이전: 문자열 키 불리언은 최신 기본값 유지' $migrationResult.afterEntry.keys[0].enabled $false
  Assert-Case '구조이전: 성공 후 이전 오류 초기화' ($null -eq $script:configMigrationError) $true

  # 5-1) schema 4 → 5 (v2.0.0 생활 대분류 신설 - 리뷰 검증 조건): mainCategory/life 가 없는
  #      구 config 는 기본값 보충, 이미 생활을 쓰던 config 는 값 보존, contentCategory 불변
  $defaultConfigV5 = [pscustomobject]@{
    configSchemaVersion = 5
    coordsVersion = 6
    mainCategory = 'battle'
    contentCategory = 'abyss'
    life = [pscustomobject]@{ content = 'gather'; skill = 'daily'; target = '둥지'
      bagFull = 'stop'; toolWorn = 'stop'; gatherWaitSeconds = 600 }
    ui = [pscustomobject]@{ logFontSize = 9; settingsOpen = $false; logOpen = $false }
  }
  $userConfigV4 = [pscustomobject]@{
    configSchemaVersion = 4
    coordsVersion = 6
    contentCategory = 'deepdungeon'
    ui = [pscustomobject]@{ logFontSize = 17; settingsOpen = $true; logOpen = $false }
  }
  [System.IO.File]::WriteAllText($defaultPath, ($defaultConfigV5 | ConvertTo-Json -Depth 10), $utf8Bom)
  [System.IO.File]::WriteAllText($configPath, ($userConfigV4 | ConvertTo-Json -Depth 10), $utf8Bom)
  $migratedV5 = Update-ConfigToLatest
  $resultV5 = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '4→5: 실행됨' $migratedV5 $true
  Assert-Case '4→5: schema 5 적용' $resultV5.configSchemaVersion 5
  Assert-Case '4→5: mainCategory 기본 battle 보충' $resultV5.mainCategory 'battle'
  Assert-Case '4→5: life 기본 섹션 보충' $resultV5.life.skill 'daily'
  Assert-Case '4→5: contentCategory 보존' $resultV5.contentCategory 'deepdungeon'
  $userConfigV4Life = [pscustomobject]@{
    configSchemaVersion = 4
    coordsVersion = 6
    contentCategory = 'dungeon'
    mainCategory = 'life'
    life = [pscustomobject]@{ content = 'gather'; skill = 'wood'; target = '뾰족 나무'
      bagFull = 'continue'; toolWorn = 'stop'; gatherWaitSeconds = 300 }
  }
  [System.IO.File]::WriteAllText($configPath, ($userConfigV4Life | ConvertTo-Json -Depth 10), $utf8Bom)
  $migratedV5Life = Update-ConfigToLatest
  $resultV5Life = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '4→5(생활 사용자): 실행됨' $migratedV5Life $true
  Assert-Case '4→5(생활 사용자): mainCategory 보존' $resultV5Life.mainCategory 'life'
  Assert-Case '4→5(생활 사용자): life.skill 보존' $resultV5Life.life.skill 'wood'
  # '채집 대기'는 **의미가 바뀐 설정**이라 보존하지 않고 기본값으로 되돌립니다 (schema 6).
  # 옛 값은 '사이클 총 시간' 기준으로 정한 숫자라, 새 의미('진행이 멈춘 시간')에서는 뜻이
  # 달라집니다 - 실제로 구 기본값 120 이 남아 멀쩡한 채집을 잘랐습니다 (2026-08-08 실사고)
  Assert-Case '4→6(생활 사용자): life.gatherWaitSeconds 는 의미 변경으로 기본값 복귀' $resultV5Life.life.gatherWaitSeconds 600
  Assert-Case '4→6(생활 사용자): 되돌리기 전 값을 안내용으로 보관' $script:gatherWaitReset 300
  Assert-Case '4→5(생활 사용자): contentCategory 보존' $resultV5Life.contentCategory 'dungeon'

  # 5-2) 자동 이전이 진행 기록을 지우면 완료 마커도 함께 버려야 합니다 (2026-08-09 감사).
  #      progress 만 0 으로 돌아가고 마커가 남으면, 마커가 progress 보다 앞선 상태가 되어
  #      다음 시작에서 '마무리 복구'가 잘못 발동해 1번 항목을 건너뛸 수 있습니다.
  $defaultWithCustom = [pscustomobject]@{
    configSchemaVersion = 5
    coordsVersion = 6
    mainCategory = 'battle'
    customRepeat = [pscustomobject]@{ randomOrder = $false; items = @(); progress = $null }
    abyssCustomRepeat = [pscustomobject]@{ randomOrder = $false; items = @(); progress = $null }
    deepCustomRepeat = [pscustomobject]@{ randomOrder = $false; items = @(); progress = $null }
    lifeCustomRepeat = [pscustomobject]@{ randomOrder = $false; items = @(); progress = $null }
  }
  # 던전 진행만 있는 사용자 - 어비스/심층/생활은 진행이 없습니다.
  $userWithProgress = [pscustomobject]@{
    configSchemaVersion = 4
    coordsVersion = 6
    customRepeat = [pscustomobject]@{
      items = @()
      progress = [pscustomobject]@{ lap = 3; index = 1; fingerprint = 'abc' }
    }
    abyssCustomRepeat = [pscustomobject]@{ items = @(); progress = $null }
  }
  function Reset-TestMarkers {
    foreach ($markerPath in @($customDungeonMarkerFile, $customAbyssMarkerFile,
        $customDeepMarkerFile, $customLifeMarkerFile)) {
      [System.IO.File]::WriteAllText($markerPath, '{}')
    }
  }
  Reset-TestMarkers
  [System.IO.File]::WriteAllText($defaultPath, ($defaultWithCustom | ConvertTo-Json -Depth 10), $utf8Bom)
  [System.IO.File]::WriteAllText($configPath, ($userWithProgress | ConvertTo-Json -Depth 10), $utf8Bom)
  $script:customProgressReset = $false
  $migratedMarker = Update-ConfigToLatest
  Assert-Case '이전+마커: 이전 실행됨' $migratedMarker $true
  Assert-Case '이전+마커: 진행 초기화 플래그 켜짐' $script:customProgressReset $true
  Assert-Case '이전+마커: 실제 초기화된 섹션만 수집' `
    ((@($script:customProgressResetSections) -join ',')) 'customRepeat'
  Assert-Case '이전+마커: 던전 마커 삭제' (Test-Path -LiteralPath $customDungeonMarkerFile) $false
  # 진행이 없던 섹션의 **정상** 마커는 파괴하면 안 됩니다 (집계 플래그 하나로 4종을 다
  # 지우면 어비스의 유효한 미완료 마무리 근거가 사라져 클리어한 판을 다시 돕니다 - 리뷰 적발)
  Assert-Case '이전+마커: 진행 없던 어비스 마커 보존' (Test-Path -LiteralPath $customAbyssMarkerFile) $true
  Assert-Case '이전+마커: 진행 없던 심층 마커 보존' (Test-Path -LiteralPath $customDeepMarkerFile) $true
  Assert-Case '이전+마커: 진행 없던 생활 마커 보존' (Test-Path -LiteralPath $customLifeMarkerFile) $true

  # 지울 진행 기록이 애초에 없었으면 마커는 건드리지 않습니다
  $userNoProgress = [pscustomobject]@{
    configSchemaVersion = 4
    coordsVersion = 6
    customRepeat = [pscustomobject]@{ items = @(); progress = $null }
  }
  Reset-TestMarkers
  [System.IO.File]::WriteAllText($configPath, ($userNoProgress | ConvertTo-Json -Depth 10), $utf8Bom)
  $script:customProgressReset = $false
  Update-ConfigToLatest | Out-Null
  Assert-Case '이전+마커: 진행 없으면 플래그 꺼짐' $script:customProgressReset $false
  Assert-Case '이전+마커: 진행 없으면 마커 보존' (Test-Path -LiteralPath $customDungeonMarkerFile) $true

  # ★ 저장 실패 주입: 마커를 **먼저** 지우면 옛 progress + 마커 없음이 되어 완료한 유료 판을
  #   다시 돕니다. 삭제는 반드시 저장 성공 뒤여야 합니다 (비트랜잭션 - 리뷰 적발).
  Reset-TestMarkers
  [System.IO.File]::WriteAllText($configPath, ($userWithProgress | ConvertTo-Json -Depth 10), $utf8Bom)
  $script:customProgressReset = $false
  $saveLock = [System.IO.File]::Open($configPath, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  try { $migrateLocked = Update-ConfigToLatest }
  finally { $saveLock.Dispose() }
  Assert-Case '저장실패: 이전 실패 반환' $migrateLocked $false
  Assert-Case '저장실패: 던전 마커 보존(삭제는 저장 성공 뒤)' (Test-Path -LiteralPath $customDungeonMarkerFile) $true
  Assert-Case '저장실패: 다른 섹션 마커도 보존' `
    ((Test-Path -LiteralPath $customAbyssMarkerFile) -and (Test-Path -LiteralPath $customDeepMarkerFile)) $true
  Assert-Case '저장실패: 디스크 진행 기록 그대로' `
    ((Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).customRepeat.progress.lap) 3

  # ★ 반대 방향 주입: config 저장은 성공했는데 **마커 파일이 잠겨** 삭제가 안 되는 경우.
  #   조용히 성공으로 처리하면 'progress 는 초기화됐는데 옛 마커는 살아 있는' 원래 불일치가
  #   그대로 재현됩니다. 삭제 실패 시 '{}' 로 소유자 형식을 무효화하고, 그것도 실패하면
  #   플래그로 알려야 합니다 (2026-08-09 리뷰).
  Reset-TestMarkers
  [System.IO.File]::WriteAllText($configPath, ($userWithProgress | ConvertTo-Json -Depth 10), $utf8Bom)
  $script:customProgressReset = $false
  $script:customMarkerClearFailed = $false
  $markerLock = [System.IO.File]::Open($customDungeonMarkerFile, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
  try { $migrateMarkerLocked = Update-ConfigToLatest }
  finally { $markerLock.Dispose() }
  Assert-Case '마커잠금: 이전 자체는 성공' $migrateMarkerLocked $true
  Assert-Case '마커잠금: 무효화 실패를 플래그로 보고' $script:customMarkerClearFailed $true
  # 무효화 계약 자체(삭제 → 확인 → '{}')는 단일 함수로 직접 검증합니다
  $clearProbe = [System.IO.Path]::Combine($testRoot, 'clear_probe.marker')
  [System.IO.File]::WriteAllText($clearProbe, '{"version":2,"lap":1,"index":0}')
  Assert-Case '무효화: 정상 삭제는 true' (Clear-CustomMarkerFile -Path $clearProbe) $true
  Assert-Case '무효화: 파일 사라짐' (Test-Path -LiteralPath $clearProbe) $false
  [System.IO.File]::WriteAllText($clearProbe, '{"version":2,"lap":1,"index":0}')
  $probeLock = [System.IO.File]::Open($clearProbe, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
  try { $probeResult = Clear-CustomMarkerFile -Path $clearProbe }
  finally { $probeLock.Dispose() }
  Assert-Case '무효화: 잠긴 파일은 실패를 정직하게 반환' $probeResult $false
  Assert-Case '무효화: 잠금 해제 후 삭제되면 다시 true' (Clear-CustomMarkerFile -Path $clearProbe) $true
  Assert-Case '무효화: 없는 경로는 true(할 일 없음)' `
    (Clear-CustomMarkerFile -Path ([System.IO.Path]::Combine($testRoot, 'nope.marker'))) $true

  # ★ 재시작 생존: 실패 사실이 메모리 플래그로만 있으면 프로그램을 껐다 켜는 순간 사라지고,
  #   그 사이 잠금이 풀리면 옛 마커가 유효 마커로 되살아납니다. 특히 옛 진행이 1바퀴 0번이면
  #   초기화된 위치와 소유자가 정확히 일치해 잘못된 마무리 복구가 발동합니다 (리뷰 적발).
  #   그래서 실패는 디스크(.stale 묘비)에 남고, 시작 게이트가 그것을 소비해야 합니다.
  $staleProbe = [System.IO.Path]::Combine($testRoot, 'stale_probe.marker')
  $staleFlagPath = Get-CustomMarkerStaleFile -Path $staleProbe
  [System.IO.File]::WriteAllText($staleProbe, '{"version":2,"lap":1,"index":0}')
  Assert-Case '묘비: 잠기기 전에는 묘비 없음' (Test-CustomMarkerStale -Path $staleProbe) $false
  $staleLock = [System.IO.File]::Open($staleProbe, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
  try { Clear-CustomMarkerFile -Path $staleProbe | Out-Null }
  finally { $staleLock.Dispose() }
  Assert-Case '묘비: 무효화 실패 시 묘비 파일 생성' (Test-Path -LiteralPath $staleFlagPath) $true
  Assert-Case '묘비: 마커는 아직 살아 있음(잠겨서 못 지움)' (Test-Path -LiteralPath $staleProbe) $true
  # 프로그램 재시작을 모사: 메모리 플래그를 지워도 묘비로 stale 을 계속 안다
  $script:customMarkerClearFailed = $false
  Assert-Case '묘비: 재시작 후에도 stale 로 인식(메모리 플래그 무관)' (Test-CustomMarkerStale -Path $staleProbe) $true
  # 잠금이 풀린 뒤 시작 게이트가 재시도하면 정리되고 묘비도 사라진다
  Assert-Case '묘비: 잠금 해제 후 재시도 성공' (Clear-CustomMarkerFile -Path $staleProbe) $true
  Assert-Case '묘비: 마커 삭제됨 (복구 근거 소멸)' (Test-Path -LiteralPath $staleProbe) $false
  Assert-Case '묘비: 묘비도 함께 정리됨' (Test-Path -LiteralPath $staleFlagPath) $false
  Assert-Case '묘비: 정리 후에는 stale 아님' (Test-CustomMarkerStale -Path $staleProbe) $false
  # 마커가 원래 없던 경우에도 남은 묘비는 청소합니다 (묘비만 영구히 남아 매번 경고하는 것 방지)
  [System.IO.File]::WriteAllText($staleFlagPath, 'stale')
  Assert-Case '묘비: 마커 없는데 묘비만 있으면 청소' (Clear-CustomMarkerFile -Path $staleProbe) $true
  Assert-Case '묘비: 청소 확인' (Test-Path -LiteralPath $staleFlagPath) $false

  # ★ 묘비가 **다음 회차의 정상 마커**를 오염시키면 안 됩니다 (리뷰 적발 시나리오 그대로):
  #   코드 0 에서 일시적 잠금으로 삭제 실패 → 묘비 생성 → 잠금 해제 → 자동 다음 회차 →
  #   그 회차가 정상 마커를 기록 → GUI 종료 후 재시작 → 남은 묘비 때문에 **정상** 마커가
  #   삭제되어, 복구했어야 할 판을 다시 돌고 재화를 이중 소모.
  #   다음 회차 준비가 마커와 묘비를 같은 계약으로 치우면 이 사슬이 끊깁니다.
  $chainMarker = [System.IO.Path]::Combine($testRoot, 'chain.marker')
  $chainStale = Get-CustomMarkerStaleFile -Path $chainMarker
  [System.IO.File]::WriteAllText($chainMarker, '{"version":2,"lap":1,"index":0}')
  $chainLock = [System.IO.File]::Open($chainMarker, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
  try { $chainCleared = Clear-CustomMarkerFile -Path $chainMarker }   # 코드 0 정리 실패
  finally { $chainLock.Dispose() }
  Assert-Case '사슬: 코드0 정리 실패' $chainCleared $false
  Assert-Case '사슬: 묘비 생성됨' (Test-Path -LiteralPath $chainStale) $true
  # 잠금 해제 후 '다음 회차 준비'가 같은 계약으로 정리 (마커가 이미 없어도 묘비는 치워야 함)
  Assert-Case '사슬: 다음 회차 준비에서 정리 성공' (Clear-CustomMarkerFile -Path $chainMarker) $true
  Assert-Case '사슬: 워커 시작 전에 묘비가 사라짐' (Test-Path -LiteralPath $chainStale) $false
  # 이제 그 회차 워커가 정상 마커를 기록
  [System.IO.File]::WriteAllText($chainMarker, '{"version":2,"lap":1,"index":1}')
  Assert-Case '사슬: 새 정상 마커는 stale 아님' (Test-CustomMarkerStale -Path $chainMarker) $false
  Assert-Case '사슬: GUI 재시작해도 정상 마커 보존' (Test-Path -LiteralPath $chainMarker) $true
  Remove-Item -LiteralPath $chainMarker -Force -ErrorAction SilentlyContinue

  # 시작 게이트 배선: stale 이면 재시도하고, 그래도 실패하면 복구 진입을 막아야 합니다
  $guiRaw = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
  # 다음 회차 준비도 같은 계약을 써야 합니다. 마커만 직접 지우면 묘비가 살아남습니다.
  Assert-Case '배선: 다음 회차 준비가 마커+묘비를 한 계약으로 정리' `
    ($guiRaw -match 'if \(-not \$script:customRecoveryPending\) \{\s*\r?\n\s*if \(-not \(Clear-CustomMarkerFile -Path \$customMarkerFile\)\)') $true
  Assert-Case '배선: 회차 준비 정리를 Test-Path 로 감싸지 않음(마커 없어도 묘비 청소)' `
    ($guiRaw -match '\(-not \$script:customRecoveryPending\) -and \(Test-Path -LiteralPath \$customMarkerFile\)') $false
  Assert-Case '배선: 마커 정리 결과를 버리는 호출 없음' `
    ([regex]::Matches($guiRaw, 'Clear-CustomMarkerFile -Path [^\r\n]*\| Out-Null').Count) 0
  Assert-Case '배선: 시작 게이트가 묘비를 소비' `
    ($guiRaw -match 'if \(\$script:customActive -and \(Test-CustomMarkerStale -Path \$customMarkerFile\)\)') $true
  Assert-Case '배선: 재시도 실패 시 복구 진입 차단' `
    ($guiRaw -match '\$markerStaleBlocked = \$true[\s\S]{0,400}if \(\$script:customActive -and -not \$markerStaleBlocked -and \(Test-Path -LiteralPath \$customMarkerFile\)\)') $true

  # 6) 진행 저장 실패는 $null/false 로 호출부까지 전달되고 디스크 진행도는 바뀌지 않음
  $item = [pscustomobject]@{
    difficulty = '일반'; stage = '1-1'; coin = $true; doubleLoot = $false
    exhaustContinue = $false; noDoubleSweep = $false
  }
  $progressConfig = [pscustomobject]@{
    customRepeat = [pscustomobject]@{
      items = @($item)
      progress = [pscustomobject]@{ lap = 1; index = 0; fingerprint = (Get-CustomFingerprint @($item)) }
    }
  }
  Save-Config $progressConfig
  $lock = [System.IO.File]::Open($configPath, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  try { $failedAdvance = Step-CustomProgress }
  finally { $lock.Dispose() }
  Assert-Case '진행저장: 잠금 실패 시 전진 결과 null' ($null -eq $failedAdvance) $true
  $afterAdvanceFailure = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '진행저장: 실패 시 기존 lap 보존' $afterAdvanceFailure.customRepeat.progress.lap 1
  $advanced = Step-CustomProgress
  Assert-Case '진행저장: 성공 시 다음 lap 반환' $advanced.lap 2
  $afterAdvance = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '진행저장: 성공 시 디스크 전진' $afterAdvance.customRepeat.progress.lap 2

  $lock = [System.IO.File]::Open($configPath, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  try { $failedReset = Reset-CustomProgress }
  finally { $lock.Dispose() }
  Assert-Case '진행초기화: 잠금 실패 반환 false' $failedReset $false
  $afterResetFailure = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '진행초기화: 실패 시 기존 진행 보존' $afterResetFailure.customRepeat.progress.lap 2
  Assert-Case '진행초기화: 성공 반환 true' (Reset-CustomProgress) $true
  $afterReset = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '진행초기화: 성공 시 progress null' ($null -eq $afterReset.customRepeat.progress) $true

  # 7) 어비스 커스텀 진행은 던전 커스텀과 다른 섹션·지문을 사용하고 서로 건드리지 않음
  $abyssItem = [pscustomobject]@{
    kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '우연한 만남'
  }
  $separateConfig = [pscustomobject]@{
    customRepeat = [pscustomobject]@{
      items = @($item)
      progress = [pscustomobject]@{ lap = 7; index = 0; fingerprint = (Get-CustomFingerprint @($item)) }
    }
    abyssCustomRepeat = [pscustomobject]@{
      items = @($abyssItem)
      progress = [pscustomobject]@{ lap = 1; index = 0; fingerprint = (Get-CustomFingerprint @($abyssItem)) }
    }
  }
  Save-Config $separateConfig
  Assert-Case '어비스 토큰: 던전 토큰과 구분되는 A 접두사' `
    (Format-CustomItemToken $abyssItem) 'A|party|어려움|광기의 동굴|우연한 만남'
  $abyssAdvanced = Step-CustomProgress -SectionName 'abyssCustomRepeat'
  Assert-Case '어비스 진행: 별도 섹션 전진' $abyssAdvanced.lap 2
  $afterAbyssAdvance = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '어비스 진행: 던전 진행 보존' $afterAbyssAdvance.customRepeat.progress.lap 7
  Assert-Case '어비스 진행: 디스크 전진' $afterAbyssAdvance.abyssCustomRepeat.progress.lap 2
  Assert-Case '어비스 초기화: 별도 섹션 성공' (Reset-CustomProgress -SectionName 'abyssCustomRepeat') $true
  $afterAbyssReset = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '어비스 초기화: 어비스 progress만 null' ($null -eq $afterAbyssReset.abyssCustomRepeat.progress) $true
  Assert-Case '어비스 초기화: 던전 진행 계속 보존' $afterAbyssReset.customRepeat.progress.lap 7

  # 7-1) 완료 마커도 섹션별로 분리 (2026-08-09 감사 - progress 는 SectionName 으로 분기하는데
  #      마커만 전역을 써서, 어비스를 초기화하면 마지막으로 시작했던 던전의 유효 마커가
  #      지워지고 클리어한 판을 다시 도는 오복구가 가능했습니다)
  foreach ($markerPath in @($customDungeonMarkerFile, $customAbyssMarkerFile,
      $customDeepMarkerFile, $customLifeMarkerFile)) {
    [System.IO.File]::WriteAllText($markerPath, '{}')
  }
  Assert-Case '마커분리: 어비스 초기화 재실행 성공' (Reset-CustomProgress -SectionName 'abyssCustomRepeat') $true
  Assert-Case '마커분리: 어비스 마커만 삭제' (Test-Path -LiteralPath $customAbyssMarkerFile) $false
  Assert-Case '마커분리: 던전 마커 보존' (Test-Path -LiteralPath $customDungeonMarkerFile) $true
  Assert-Case '마커분리: 심층 마커 보존' (Test-Path -LiteralPath $customDeepMarkerFile) $true
  Assert-Case '마커분리: 생활 마커 보존' (Test-Path -LiteralPath $customLifeMarkerFile) $true
  Assert-Case '마커분리: 던전 초기화는 던전 마커 삭제' (Reset-CustomProgress -SectionName 'customRepeat') $true
  Assert-Case '마커분리: 던전 마커 삭제됨' (Test-Path -LiteralPath $customDungeonMarkerFile) $false
  Assert-Case '마커분리: 심층/생활 마커는 그대로' `
    ((Test-Path -LiteralPath $customDeepMarkerFile) -and (Test-Path -LiteralPath $customLifeMarkerFile)) $true
} finally {
  # 이 테스트가 만든 정확한 임시 파일만 개별 삭제합니다.
  foreach ($path in @($configPath, $defaultPath, $customMarkerFile, $customDungeonMarkerFile,
      $customAbyssMarkerFile, $customDeepMarkerFile, $customLifeMarkerFile,
      [System.IO.Path]::Combine($testRoot, 'clear_probe.marker'),
      [System.IO.Path]::Combine($testRoot, 'stale_probe.marker'),
      [System.IO.Path]::Combine($testRoot, 'stale_probe.marker.stale'),
      ($customDungeonMarkerFile + '.stale'), ($customAbyssMarkerFile + '.stale'),
      ($customDeepMarkerFile + '.stale'), ($customLifeMarkerFile + '.stale'))) {
    if ([System.IO.File]::Exists($path)) { [System.IO.File]::Delete($path) }
  }
  if ([System.IO.Directory]::Exists($testRoot)) { [System.IO.Directory]::Delete($testRoot, $false) }
}

exit $fails
