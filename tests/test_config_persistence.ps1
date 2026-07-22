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
    'Step-CustomProgress', 'Reset-CustomProgress')) {
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
  $defaultConfig = [pscustomobject]@{
    configSchemaVersion = 2
    coordsVersion = 6
    ui = [pscustomobject]@{ logFontSize = 9 }
    diagnostics = [pscustomobject]@{ keepScreenshots = 10 }
    revive = [pscustomobject]@{ enabled = $false }
    afterEntry = [pscustomobject]@{ keys = @([pscustomobject]@{ key = 32; enabled = $false }) }
    customRepeat = [pscustomobject]@{ progress = $null }
    abyssCustomRepeat = [pscustomobject]@{ items = @(); listRepeat = 'infinite'; listRepeatCount = 1; progress = $null }
  }
  $userConfig = [pscustomobject]@{
    coordsVersion = 6
    ui = [pscustomobject]@{ logFontSize = 17 }
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
  Assert-Case '구조이전: 최신 schemaVersion 적용' $migrationResult.configSchemaVersion 2
  Assert-Case '구조이전: 어비스 커스텀 기본 섹션 추가' ($null -ne $migrationResult.abyssCustomRepeat) $true
  Assert-Case '구조이전: ui.logFontSize 보존' $migrationResult.ui.logFontSize 17
  Assert-Case '구조이전: 다른 사용자 설정 보존' $migrationResult.diagnostics.keepScreenshots 7
  Assert-Case '구조이전: 문자열 revive 불리언은 최신 기본값 유지' $migrationResult.revive.enabled $false
  Assert-Case '구조이전: 문자열 키 불리언은 최신 기본값 유지' $migrationResult.afterEntry.keys[0].enabled $false
  Assert-Case '구조이전: 성공 후 이전 오류 초기화' ($null -eq $script:configMigrationError) $true

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
} finally {
  # 이 테스트가 만든 정확한 임시 파일만 개별 삭제합니다.
  foreach ($path in @($configPath, $defaultPath)) {
    if ([System.IO.File]::Exists($path)) { [System.IO.File]::Delete($path) }
  }
  if ([System.IO.Directory]::Exists($testRoot)) { [System.IO.Directory]::Delete($testRoot, $false) }
}

exit $fails
