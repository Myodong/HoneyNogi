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
  # 스키마 11(10-08): 10→11 이전 블록이 Read-CustomMarkerOwner -Path 로 섹션 마커를 읽고, 진행을 지운 섹션은 Step-CustomProgressGeneration
  # 으로 세대를 올립니다. 정상 마커 픽스처는 실제 New-CustomMarkerOwnerJson(version 3)으로 만듭니다
  foreach ($name in @('Read-Config', 'ConvertTo-StrictBoolean', 'Write-Utf8FileAtomic', 'Save-Config', 'Update-ConfigToLatest',
    'Format-CustomItemToken', 'Get-CustomFingerprint', 'Get-CustomNextProgress',
    'Step-CustomProgress', 'Reset-CustomProgress', 'Get-CustomMarkerFileForSection', 'Clear-CustomMarkerFile',
    'Get-CustomMarkerStaleFile', 'Test-CustomMarkerStale',
    'Get-CustomRandomOrderEnabled', 'New-CustomShuffleOrder', 'Test-CustomShuffleOrder',
    'Read-CustomMarkerOwner', 'Step-CustomProgressGeneration', 'New-CustomMarkerOwnerJson', 'Get-CustomCanonicalOwner',
    'ConvertTo-CustomMarkerOwnerJson', 'Get-CustomOrderKey', 'Remove-AbyssJournalSectionEntries')) {
  $fn = $ast.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true) | Select-Object -First 1
  if (-not $fn) { throw "본체 함수를 찾지 못했습니다: $name" }
  Invoke-Expression $fn.Extent.Text
}
# 단계 2.3(10-08): 어비스 진행 초기화가 완료 기록 폐기 헬퍼(Remove-AbyssJournalSectionEntries)를 부르고, 헬퍼는 저장소 묶음
#   (Update-AbyssJournal …)을 씁니다. 묶음 = 머리 주석 ~ '묶음 끝' 표지 주석 사이 최상위 함수 전부(회귀 test_abyss_journal_store 와 같은
#   경계). 이 파일 최상위 foreach 에서 정의합니다 - 클로저 mutator 쪽에서 보이는 함수는 최상위 정의뿐입니다(구현 명세 ① 2.0 체크리스트 6)
$journalBundleHeader = @($tokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and
    $_.Text.Contains('어비스 완료 기록(handoff journal) 저장소') })
$journalBundleEnd = @($tokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and
    $_.Text.Contains('어비스 완료 기록 저장소 묶음 끝') })
if ($journalBundleHeader.Count -ne 1 -or $journalBundleEnd.Count -ne 1) { throw '완료 기록 저장소 묶음의 머리 주석·끝 표지를 찾지 못했습니다' }
$journalBundleNames = @()
foreach ($statement in $ast.EndBlock.Statements) {
  if (-not ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst])) { continue }
  if ($statement.Extent.StartOffset -lt $journalBundleHeader[0].Extent.StartOffset) { continue }
  if ($statement.Extent.StartOffset -gt $journalBundleEnd[0].Extent.StartOffset) { break }
  Invoke-Expression $statement.Extent.Text
  $journalBundleNames += $statement.Name
}
if ($journalBundleNames -notcontains 'Update-AbyssJournal') { throw '완료 기록 저장소 묶음에 Update-AbyssJournal 이 없습니다' }
$script:abyssJournalSavedBy = 'gui'

$script:guiLogLines = @()
function Add-GuiLog {
  param([string]$Message)
  $script:lastGuiLog = $Message
  $script:guiLogLines += $Message   # 시작 안내 블록(최상위 if)을 소스 그대로 돌릴 때 줄 수를 셉니다
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
# 어비스 완료 기록(journal)도 임시 폴더로 - 7) 의 어비스 진행 초기화는 파일이 없어 바꿀 것이 없으므로(unchanged) 아무 파일도 만들지 않아야 합니다
$abyssJournalPath = [System.IO.Path]::Combine($testRoot, 'abyss_handoff.json')
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
  # ★ 실배포 config 로 '새 키가 실제로 들어오는가'를 확인합니다 (2026-08-10 실기에서 적발).
  #   config.json 에 repeat.mode / untilTime 을 추가하면서 **configSchemaVersion 을 올리지
  #   않아**, 기존 사용자(스키마가 같음)는 마이그레이션 게이트(`usrSchema -ge $defSchema`)에
  #   걸려 새 키를 영영 못 받았습니다. 값은 첫 저장 때 Add-Member 로 들어가지만 `_설명` 키는
  #   끝내 안 들어가고, 그 사이 화면과 실제 동작이 어긋납니다.
  #   → 저장소의 **실제** config.json 을 기본값으로 놓고, 그보다 한 단계 낮은 사용자 config 가
  #     새 키를 받아 오는지 확인합니다. 새 키를 넣고 버전을 안 올리면 여기서 잡힙니다.
  $realDefault = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $realSchema = [int]$realDefault.configSchemaVersion
  [System.IO.File]::WriteAllText($defaultPath, ($realDefault | ConvertTo-Json -Depth 20), $utf8Bom)
  $oldUser = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json   # 깊은 복사
  $oldUser.configSchemaVersion = $realSchema - 1
  $oldUser.repeat.PSObject.Properties.Remove('mode')
  $oldUser.repeat.PSObject.Properties.Remove('untilTime')
  $oldUser.repeat.PSObject.Properties.Remove('_mode')
  $oldUser.repeat.PSObject.Properties.Remove('_untilTime')
  $oldUser.repeat.defaultCount = 42          # 사용자가 바꾼 값 - 보존돼야 함
  [System.IO.File]::WriteAllText($configPath, ($oldUser | ConvertTo-Json -Depth 20), $utf8Bom)
  $migratedReal = Update-ConfigToLatest
  $resultReal = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '실배포: 한 단계 낮은 스키마는 이전이 실행됨' $migratedReal $true
  Assert-Case '실배포: 스키마가 최신으로' $resultReal.configSchemaVersion $realSchema
  Assert-Case '실배포: 새 키(mode)가 들어옴' ([bool]$resultReal.repeat.PSObject.Properties['mode']) $true
  Assert-Case '실배포: 새 키(untilTime)가 들어옴' ([bool]$resultReal.repeat.PSObject.Properties['untilTime']) $true
  Assert-Case '실배포: 설명 키(_mode)도 들어옴' ([bool]$resultReal.repeat.PSObject.Properties['_mode']) $true
  Assert-Case '실배포: 사용자가 바꾼 값은 보존' $resultReal.repeat.defaultCount 42
  # 같은 스키마면 이전을 하지 않는 것도 계약입니다 (매 실행 재작성 방지)
  $sameUser = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  [System.IO.File]::WriteAllText($configPath, ($sameUser | ConvertTo-Json -Depth 20), $utf8Bom)
  Assert-Case '실배포: 같은 스키마면 이전하지 않음' (Update-ConfigToLatest) $false
  # ★ 좌표 버전만 낮은 실배포 config (v15, 2026-09-15): 기존 좌표 키 값을 바꾸며 coordsVersion 만 올린 배포에서
  #   스키마가 같은 기존 사용자가 새 좌표를 실제로 받는지. 위 검증은 스키마만 낮춰서 이 경로를 보지 못했습니다.
  $realCoords = [int]$realDefault.coordsVersion
  $coordsUser = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  $coordsUser.coordsVersion = $realCoords - 1
  $coordsUser.ocrRegions.questTracker = @(980, 190, 285, 77)   # v14 영역을 가진 사용자
  $coordsUser.repeat.defaultCount = 43
  [System.IO.File]::WriteAllText($configPath, ($coordsUser | ConvertTo-Json -Depth 20), $utf8Bom)
  $migratedCoords = Update-ConfigToLatest
  $resultCoords = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '실배포(좌표만 낮음): 이전이 실행됨' $migratedCoords $true
  Assert-Case '실배포(좌표만 낮음): coordsVersion 이 최신으로' ([int]$resultCoords.coordsVersion) $realCoords
  Assert-Case '실배포(좌표만 낮음): questTracker 가 최신 기본값으로' (($resultCoords.ocrRegions.questTracker -join ',')) (($realDefault.ocrRegions.questTracker -join ','))
  Assert-Case '실배포(좌표만 낮음): 사용자가 바꾼 값은 보존' $resultCoords.repeat.defaultCount 43
  # 2026-09-25: 거점 부활 상한은 사용자 편집값 - 좌표 버전 이전에서 기본값(3)으로 되돌리지 않는다 (실기 4 에서 상한 0 테스트 설정이 되돌아갔음)
  $limitUser = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  $limitUser.coordsVersion = $realCoords - 1
  $limitUser.revive.checkpointReviveLimit = 0
  [System.IO.File]::WriteAllText($configPath, ($limitUser | ConvertTo-Json -Depth 20), $utf8Bom)
  [void](Update-ConfigToLatest)
  $resultLimit = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '실배포(좌표만 낮음): revive.checkpointReviveLimit 편집값(0) 보존' ([int]$resultLimit.revive.checkpointReviveLimit) 0
  $limitUser.revive.checkpointReviveLimit = 'abc'
  [System.IO.File]::WriteAllText($configPath, ($limitUser | ConvertTo-Json -Depth 20), $utf8Bom)
  [void](Update-ConfigToLatest)
  $resultLimit = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '실배포(좌표만 낮음): 정수가 아닌 상한은 기본값(3)으로' ([int]$resultLimit.revive.checkpointReviveLimit) 3

  # ★ 스키마 11(10-08 커스텀 진행 세대 progressGeneration - 설계 v10 1.2·1.3): 사용자 스키마를 10·9 로 **고정**한 픽스처로 키 유입을
  #   봅니다. 위 '$realSchema - 1' 은 config.json 의 번호를 안 올리고 키만 넣으면 함께 내려가(10 - 1 = 9) 그 실수를 못 잡습니다.
  #   9 = 마지막 배포본(v2.1.11)의 스키마. 생활 섹션은 마커를 만들지 않아 키가 없어야 합니다.
  $generationSections = @('customRepeat', 'abyssCustomRepeat', 'deepCustomRepeat')
  function Remove-TestGenerationKeys {
    # 스키마 11 이전 config 모사 - 전투 3섹션의 세대 키와 설명 키를 뺍니다
    param($Config)
    foreach ($genSection in $generationSections) {
      $Config.$genSection.PSObject.Properties.Remove('progressGeneration')
      $Config.$genSection.PSObject.Properties.Remove('_progressGeneration')
    }
  }
  function Get-TestGenerationText {
    # 섹션별 '세대/설명 키 유무' (키 없음 = '없음')
    param($Config)
    return ((@($generationSections) + 'lifeCustomRepeat' | ForEach-Object {
          $genProperty = $Config.$_.PSObject.Properties['progressGeneration']
          '{0}={1}/{2}' -f $_, $(if ($genProperty) { [string]$genProperty.Value } else { '없음' }), [bool]$Config.$_.PSObject.Properties['_progressGeneration']
        }) -join ' ')
  }
  foreach ($fixedUserSchema in @(10, 9)) {
    $genUser = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $genUser.configSchemaVersion = $fixedUserSchema
    Remove-TestGenerationKeys -Config $genUser
    [System.IO.File]::WriteAllText($configPath, ($genUser | ConvertTo-Json -Depth 20), $utf8Bom)
    $migratedGen = Update-ConfigToLatest
    $resultGen = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Case "스키마 11 키 유입(사용자 스키마 $fixedUserSchema 고정): 이전 실행 · 최신 스키마" `
      ('{0}/{1}' -f $migratedGen, ([int]$resultGen.configSchemaVersion -eq $realSchema)) 'True/True'
    Assert-Case "스키마 11 키 유입(사용자 스키마 $fixedUserSchema 고정): 전투 3섹션 세대 0 + 설명 키 · 생활은 키 없음" `
      (Get-TestGenerationText -Config $resultGen) 'customRepeat=0/True abyssCustomRepeat=0/True deepCustomRepeat=0/True lifeCustomRepeat=없음/False'
  }
  # 이전이 진행을 지운 섹션만 세대 +1 (같은 저장 - 설계 v10 1.3). ① 스키마 10 사용자(키 없음): 진행 있던 던전·심층 = 0+1, 진행 없던 어비스 = 0,
  #   생활은 진행이 있어도 키를 만들지 않음 ② 좌표만 낮은 스키마 11 사용자(세대 3·5·7): 사용자 값 이월 + 진행 있던 어비스만 +1
  $bumpUser = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  $bumpUser.configSchemaVersion = 10
  Remove-TestGenerationKeys -Config $bumpUser
  $bumpUser.customRepeat.progress = [pscustomobject]@{ lap = 2; index = 1; fingerprint = 'x' }
  $bumpUser.deepCustomRepeat.progress = [pscustomobject]@{ lap = 1; index = 0; fingerprint = 'y' }
  $bumpUser.lifeCustomRepeat.progress = [pscustomobject]@{ lap = 1; index = 2; fingerprint = 'z' }
  [System.IO.File]::WriteAllText($configPath, ($bumpUser | ConvertTo-Json -Depth 20), $utf8Bom)
  [void](Update-ConfigToLatest)
  $resultBump = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '세대 +1(스키마 10 → 11): 진행을 지운 전투 섹션만 1 · 생활 키 없음' `
    (Get-TestGenerationText -Config $resultBump) 'customRepeat=1/True abyssCustomRepeat=0/True deepCustomRepeat=1/True lifeCustomRepeat=없음/False'
  Assert-Case '세대 +1(스키마 10 → 11): 진행 기록은 전부 지움 · 지운 섹션 목록' `
    ('{0}/{1}/{2} · {3}' -f ($null -eq $resultBump.customRepeat.progress), ($null -eq $resultBump.deepCustomRepeat.progress),
      ($null -eq $resultBump.lifeCustomRepeat.progress), (@($script:customProgressResetSections) -join ',')) 'True/True/True · customRepeat,deepCustomRepeat,lifeCustomRepeat'
  # 이 시점에는 마커 파일이 하나도 없어 진행 초기화 경로의 정리는 '할 일 없음' 성공입니다 - 그것을 구버전 무효화 건수로 세면 없는 무효화를
  #   안내합니다(변이 검증 보강 2026-10-09)
  Assert-Case '세대 +1(스키마 10 → 11): 구버전 마커가 없으면 구버전 무효화 0건 · 구버전 실패 없음' `
    ('{0}/{1}' -f $script:legacyMarkerClearedCount, $script:legacyMarkerClearFailed) '0/False'
  $carryUser = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  $carryUser.coordsVersion = $realCoords - 1
  $carryUser.customRepeat.progressGeneration = 3
  $carryUser.abyssCustomRepeat.progressGeneration = 5
  $carryUser.deepCustomRepeat.progressGeneration = 7
  $carryUser.abyssCustomRepeat.progress = [pscustomobject]@{ lap = 1; index = 1; fingerprint = 'a' }
  [System.IO.File]::WriteAllText($configPath, ($carryUser | ConvertTo-Json -Depth 20), $utf8Bom)
  [void](Update-ConfigToLatest)
  $resultCarry = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case '세대 이월(좌표만 낮은 스키마 11): 사용자 세대 그대로 + 진행 지운 어비스만 +1' `
    (Get-TestGenerationText -Config $resultCarry) 'customRepeat=3/True abyssCustomRepeat=6/True deepCustomRepeat=7/True lifeCustomRepeat=없음/False'

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
  # 스키마 11(10-08): 정상 마커 픽스처는 owner version 3(5필드 + generation 0 - 실제 New-CustomMarkerOwnerJson). 예전처럼 '{}' 로 두면
  #   10→11 이전이 '구버전(세대를 증명할 수 없는) 마커' 로 모아 지워서 '진행 없던 섹션의 정상 마커 보존' 을 볼 수 없습니다(구현 명세 ① 5절 A8 (가))
  $markerFixtureItem = [pscustomobject]@{ difficulty = '일반'; stage = '1-1'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
  $canonicalV3MarkerJson = New-CustomMarkerOwnerJson -Context @{
    Items = @($markerFixtureItem); Order = $null; Lap = 1; Index = 0; Item = $markerFixtureItem; Generation = 0 }
  function Reset-TestMarkers {
    foreach ($markerPath in @($customDungeonMarkerFile, $customAbyssMarkerFile,
        $customDeepMarkerFile, $customLifeMarkerFile)) {
      [System.IO.File]::WriteAllText($markerPath, $canonicalV3MarkerJson)
    }
  }
  Reset-TestMarkers
  $fixtureOwner = Read-CustomMarkerOwner -Path $customAbyssMarkerFile
  Assert-Case '이전+마커: 픽스처 마커는 정상 version 3 (version + 필수 6필드 = 속성 7 · generation 0)' `
    ('{0}/{1}/{2}' -f [int]$fixtureOwner.version, @($fixtureOwner.PSObject.Properties).Count, [string]$fixtureOwner.generation) '3/7/0'
  [System.IO.File]::WriteAllText($defaultPath, ($defaultWithCustom | ConvertTo-Json -Depth 10), $utf8Bom)
  [System.IO.File]::WriteAllText($configPath, ($userWithProgress | ConvertTo-Json -Depth 10), $utf8Bom)
  $script:customProgressReset = $false
  $migratedMarker = Update-ConfigToLatest
  Assert-Case '이전+마커: 이전 실행됨' $migratedMarker $true
  Assert-Case '이전+마커: 진행 초기화 플래그 켜짐' $script:customProgressReset $true
  Assert-Case '이전+마커: 실제 초기화된 섹션만 수집' `
    ((@($script:customProgressResetSections) -join ',')) 'customRepeat'
  Assert-Case '이전+마커: 정상 version 3 마커는 구버전 정리 대상이 아님' (@($script:legacyMarkerPathsToClear).Count) 0
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
  Remove-Item -LiteralPath ($customDungeonMarkerFile + '.stale') -Force -ErrorAction SilentlyContinue

  # 5-3) 스키마 10→11 구버전 완료 마커 (설계 v10 1.3·1.7 · 구현 명세 ① 2.2 ④⑥⑧). 이전 블록은 던전·어비스·심층 마커 중 version 3 으로
  #      읽히지 않는 것의 경로를 **모으기만** 하고, 무효화는 Save-Config 성공 뒤 진행 초기화 마커 정리와 같은 단계에서 경로당 1회.
  #      안내 2줄은 진행 초기화 안내 밖 - 진행이 없던(1바퀴 0번) 사용자가 주 대상이라 그 안에 두면 아무것도 안 보입니다.
  #      시작 안내 블록은 최상위 if 라 이름으로 뽑을 수 없어 AST 로 잘라 점소싱합니다(T4-e 3 방식).
  $legacyV2MarkerJson = '{"version":2,"fingerprint":"","orderKey":"","lap":1,"index":0,"item":"x"}'   # 스키마 10 까지의 GUI 가 쓰던 모양
  $testMarkerPaths = @($customDungeonMarkerFile, $customAbyssMarkerFile, $customDeepMarkerFile, $customLifeMarkerFile)
  function Get-TestMarkerState {
    # 마커 4개의 내용(없으면 '없음', 잠금 주입 중이라 못 읽으면 '잠김') - 블록 통과 시점과 이전 시점의 비교용
    return ((@($testMarkerPaths) | ForEach-Object {
          if (-not [System.IO.File]::Exists($_)) { '없음' }
          else { try { [System.IO.File]::ReadAllText($_) } catch { '잠김' } }
        }) -join ' | ')
  }
  function Set-TestLegacyMarkers {
    foreach ($markerPath in $testMarkerPaths) { [System.IO.File]::WriteAllText($markerPath, $legacyV2MarkerJson) }
  }
  function New-TestLegacyUser {
    # 스키마 10 사용자(세대 키 없음 · 진행 없음 = 1바퀴 0번)
    $legacyUser = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $legacyUser.configSchemaVersion = 10
    Remove-TestGenerationKeys -Config $legacyUser
    return $legacyUser
  }
  $migrationNoticeIf = @($ast.EndBlock.Statements | Where-Object {
      ($_ -is [System.Management.Automation.Language.IfStatementAst]) -and ($_.Clauses[0].Item1.Extent.Text -eq '$script:configMigrated') })
  Assert-Case '시작 안내: 최상위 if ($script:configMigrated) 블록 1개' $migrationNoticeIf.Count 1
  $migrationNoticeBlock = [scriptblock]::Create($migrationNoticeIf[0].Extent.Text)
  function Invoke-MigrationNotice {
    # 시작 안내 블록을 소스 그대로 실행하고 찍힌 줄을 $script:guiLogLines 에 남깁니다 (점소싱 - 블록이 읽는 $script: 상태는 이 테스트가 정함)
    $script:guiLogLines = @()
    $script:configMigrated = $true
    $script:gatherWaitReset = 0
    . $migrationNoticeBlock
  }
  function Get-TestNoticeCount {
    param([string]$Pattern)
    return @($script:guiLogLines | Where-Object { $_ -match $Pattern }).Count
  }
  # 블록 통과 시점의 마커 상태를 찍으려고 저장 함수를 감쌉니다 (블록 → 2-1)~5) → 저장 순서라 저장 직전 = 블록 통과 뒤 · 마커 정리 전)
  $realSaveConfig = ${function:Save-Config}
  function Save-Config {
    param($Config)
    $script:markerStateAtSave = Get-TestMarkerState
    & $realSaveConfig $Config
  }
  [System.IO.File]::WriteAllText($defaultPath, ($realDefault | ConvertTo-Json -Depth 20), $utf8Bom)

  # ⓐ-0 저장 실패 주입(config 잠금): 이전 실패 · 마커 4개 그대로 · 묘비 0 - 무효화는 저장 성공 뒤라 옛 진행과 마커가 함께 남습니다
  Set-TestLegacyMarkers
  $markerStateBefore = Get-TestMarkerState
  [System.IO.File]::WriteAllText($configPath, ((New-TestLegacyUser) | ConvertTo-Json -Depth 20), $utf8Bom)
  $legacySaveLock = [System.IO.File]::Open($configPath, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  try { $migratedLegacySaveFail = Update-ConfigToLatest }
  finally { $legacySaveLock.Dispose() }
  Assert-Case '구버전 마커(저장 실패): 이전 실패 · 실패 원인 보존 · 마커 4개 그대로 · 묘비 0 · 설정 스키마 그대로' `
    ('{0}/{1}/{2}/{3}/{4}' -f $migratedLegacySaveFail, (-not [string]::IsNullOrWhiteSpace($script:configMigrationError)),
      ((Get-TestMarkerState) -eq $markerStateBefore), @($testMarkerPaths | Where-Object { [System.IO.File]::Exists($_ + '.stale') }).Count,
      [int](Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json).configSchemaVersion) 'False/True/True/0/10'

  # ⓐ 진행 없음 + 4섹션 version 2 마커 → 모으기만(저장 직전 마커 그대로) → 저장 뒤 3섹션 무효화 · 생활 그대로 · '[안내] … 3건'
  Set-TestLegacyMarkers
  $markerStateBefore = Get-TestMarkerState
  $script:markerStateAtSave = $null
  [System.IO.File]::WriteAllText($configPath, ((New-TestLegacyUser) | ConvertTo-Json -Depth 20), $utf8Bom)
  $script:customProgressReset = $false
  $migratedLegacy = Update-ConfigToLatest
  Assert-Case '구버전 마커: 이전 실행 · 진행 초기화 아님' ('{0}/{1}' -f $migratedLegacy, $script:customProgressReset) 'True/False'
  Assert-Case '구버전 마커: 블록은 모으기만 - 저장 직전 시점에 마커 4개 그대로' ($script:markerStateAtSave -eq $markerStateBefore) $true
  Assert-Case '구버전 마커: 모은 경로 = 던전·어비스·심층(생활 제외)' `
    ((@($script:legacyMarkerPathsToClear) | ForEach-Object { [System.IO.Path]::GetFileName($_) }) -join ',') 'custom_done.marker,abyss_custom_done.marker,deep_custom_done.marker'
  Assert-Case '구버전 마커: 저장 뒤 3섹션 무효화 · 생활 마커 그대로' `
    ((@($testMarkerPaths) | ForEach-Object { [System.IO.File]::Exists($_) }) -join '/') 'False/False/False/True'
  Assert-Case '구버전 마커: 무효화 3건 · 구버전 실패 없음 · 진행 초기화 실패 없음' `
    ('{0}/{1}/{2}' -f $script:legacyMarkerClearedCount, $script:legacyMarkerClearFailed, $script:customMarkerClearFailed) '3/False/False'
  Invoke-MigrationNotice
  Assert-Case '구버전 마커 안내: [안내] … 3건 1줄(진행 초기화 안내 없이도) · 구버전 경고 0' `
    ('{0}/{1}/{2}' -f @($script:guiLogLines | Where-Object { $_ -eq '[안내] 구버전 커스텀 완료 기록 3건을 무효화했습니다 (새 형식 세대 검사 도입 - 해당 항목은 처음부터 다시 진행합니다)' }).Count,
      (Get-TestNoticeCount '구버전 커스텀 완료 기록 파일을 지우지 못했습니다'), (Get-TestNoticeCount '진행 기록을 초기화했습니다')) '1/0/0'

  # ⓑ 같은 구성 + 어비스 마커 잠금(삭제·덮어쓰기 모두 실패) → 구버전 실패 플래그 → 진행 초기화가 없어도 '[경고] 구버전 …' 1줄
  Set-TestLegacyMarkers
  [System.IO.File]::WriteAllText($configPath, ((New-TestLegacyUser) | ConvertTo-Json -Depth 20), $utf8Bom)
  $script:customProgressReset = $false
  $legacyLock = [System.IO.File]::Open($customAbyssMarkerFile, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
  try { $migratedLegacyLocked = Update-ConfigToLatest }
  finally { $legacyLock.Dispose() }
  Assert-Case '구버전 마커(잠금): 이전 성공 · 무효화 2건 · 구버전 실패 · 진행 초기화 실패 아님' `
    ('{0}/{1}/{2}/{3}' -f $migratedLegacyLocked, $script:legacyMarkerClearedCount, $script:legacyMarkerClearFailed, $script:customMarkerClearFailed) 'True/2/True/False'
  Invoke-MigrationNotice
  Assert-Case '구버전 마커(잠금) 안내: [안내] 2건 1 · [경고] 구버전 1 · 진행 초기화 경고 0' `
    ('{0}/{1}/{2}' -f (Get-TestNoticeCount '^\[안내\] 구버전 커스텀 완료 기록 2건을 무효화했습니다'),
      (Get-TestNoticeCount '^\[경고\] 구버전 커스텀 완료 기록 파일을 지우지 못했습니다'), (Get-TestNoticeCount '^\[경고\] 이전 완료 기록 파일을 지우지 못했습니다')) '1/1/0'
  Remove-Item -LiteralPath ($customAbyssMarkerFile + '.stale') -Force -ErrorAction SilentlyContinue

  # ⓒ 진행 있던 던전의 version 2 마커 = 두 목록에 다 듦(명세 리뷰 2 P3) → 그 경로 정리 1회. 성공은 구버전 건수에 들고, 계속 실패하면
  #    경고는 진행 초기화 쪽 1줄만(같은 파일 경고 두 줄 금지). 정리 함수를 감싸 경로별 호출 수를 셉니다
  $realClearMarker = ${function:Clear-CustomMarkerFile}
  function Clear-CustomMarkerFile {
    param([string]$Path)
    $clearKey = [System.IO.Path]::GetFileName($Path)
    $script:clearMarkerCalls[$clearKey] = 1 + [int]$script:clearMarkerCalls[$clearKey]
    return (& $realClearMarker -Path $Path)
  }
  foreach ($unionCase in @('성공', '계속 실패')) {
    Set-TestLegacyMarkers
    Remove-Item -LiteralPath $customDeepMarkerFile -Force
    $unionUser = New-TestLegacyUser
    $unionUser.customRepeat.progress = [pscustomobject]@{ lap = 1; index = 1; fingerprint = 'x' }
    [System.IO.File]::WriteAllText($configPath, ($unionUser | ConvertTo-Json -Depth 20), $utf8Bom)
    $script:customProgressReset = $false
    $script:clearMarkerCalls = @{}
    $unionLock = $null
    if ($unionCase -eq '계속 실패') {
      $unionLock = [System.IO.File]::Open($customDungeonMarkerFile, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    }
    try { $migratedUnion = Update-ConfigToLatest }
    finally { if ($unionLock) { $unionLock.Dispose() } }
    Assert-Case "두 목록 같은 경로($unionCase): 이전 성공 · 던전 정리 1회 · 어비스 정리 1회" `
      ('{0}/{1}/{2}' -f $migratedUnion, [int]$script:clearMarkerCalls['custom_done.marker'], [int]$script:clearMarkerCalls['abyss_custom_done.marker']) 'True/1/1'
    Invoke-MigrationNotice
    # 무효화가 1건(계속 실패)이어도 건수 안내는 1줄입니다 - 안내 문턱이 '2건 이상' 으로 밀리면 한 모드만 쓰던 사용자는 못 봅니다(변이 검증 보강 2026-10-09)
    Assert-Case "두 목록 같은 경로($unionCase): [안내] 구버전 … N건(N = 무효화 건수) 1줄" `
      (@($script:guiLogLines | Where-Object { $_ -eq ('[안내] 구버전 커스텀 완료 기록 {0}건을 무효화했습니다 (새 형식 세대 검사 도입 - 해당 항목은 처음부터 다시 진행합니다)' -f $script:legacyMarkerClearedCount) }).Count) 1
    $unionWarnings = (Get-TestNoticeCount '^\[경고\] 이전 완료 기록 파일을 지우지 못했습니다') + (Get-TestNoticeCount '^\[경고\] 구버전 커스텀 완료 기록 파일을 지우지 못했습니다')
    if ($unionCase -eq '성공') {
      Assert-Case '두 목록 같은 경로(성공): 실패 플래그 둘 다 거짓 · 무효화 2건(던전+어비스) · 마커 경고 0' `
        ('{0}/{1}/{2}/{3}' -f $script:customMarkerClearFailed, $script:legacyMarkerClearFailed, $script:legacyMarkerClearedCount, $unionWarnings) 'False/False/2/0'
    } else {
      Assert-Case '두 목록 같은 경로(계속 실패): 진행 초기화 실패 플래그만 · 무효화 1건(어비스) · 마커 경고 1줄' `
        ('{0}/{1}/{2}/{3}' -f $script:customMarkerClearFailed, $script:legacyMarkerClearFailed, $script:legacyMarkerClearedCount, $unionWarnings) 'True/False/1/1'
    }
    Remove-Item -LiteralPath ($customDungeonMarkerFile + '.stale') -Force -ErrorAction SilentlyContinue
  }
  ${function:Clear-CustomMarkerFile} = $realClearMarker

  # ⓓ 이미 스키마 11 인 사용자의 다음 이전(좌표만 낮음)은 구버전 수집을 하지 않습니다 - 문턱이 $defSchema 가 아니라 11 고정이라,
  #    version 3 을 쓰는 사용자의 마커가 그때 잠깐 못 읽혀도(= $null) 지워지지 않습니다. 여기서는 '{}' 마커로 '수집 안 함' 만 봅니다
  [System.IO.File]::WriteAllText($customAbyssMarkerFile, '{}')
  $coordsOnlyUser = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  $coordsOnlyUser.coordsVersion = $realCoords - 1
  [System.IO.File]::WriteAllText($configPath, ($coordsOnlyUser | ConvertTo-Json -Depth 20), $utf8Bom)
  $migratedCoordsOnly = Update-ConfigToLatest
  Assert-Case '구버전 마커(스키마 11 사용자의 좌표 이전): 수집 0 · 마커 그대로 · 무효화 0건' `
    ('{0}/{1}/{2}/{3}' -f $migratedCoordsOnly, @($script:legacyMarkerPathsToClear).Count,
      $(if ([System.IO.File]::Exists($customAbyssMarkerFile)) { [System.IO.File]::ReadAllText($customAbyssMarkerFile) } else { '없음' }), $script:legacyMarkerClearedCount) 'True/0/{}/0'
  # ⓓ-2 다음 스키마 이전(내장 스키마 = 지금 + 1 가상): 스키마가 같은 위 ⓓ 로는 문턱 '11 고정' 과 '$defSchema' 가 같은 답이라
  #    가르지 못합니다(변이 검증 보강 2026-10-09). 문턱이 $defSchema 를 따라가면 version 3 사용자의 마커가 다음 스키마 이전 때 그 순간
  #    못 읽혔다는 이유로 지워집니다 - 2-0b 주석이 막겠다고 한 경우
  $nextSchemaDefault = $realDefault | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  $nextSchemaDefault.configSchemaVersion = $realSchema + 1
  [System.IO.File]::WriteAllText($defaultPath, ($nextSchemaDefault | ConvertTo-Json -Depth 20), $utf8Bom)
  [System.IO.File]::WriteAllText($customAbyssMarkerFile, '{}')
  [System.IO.File]::WriteAllText($configPath, ($realDefault | ConvertTo-Json -Depth 20), $utf8Bom)
  $migratedNextSchema = Update-ConfigToLatest
  Assert-Case '구버전 마커(스키마 11 사용자의 다음 스키마 이전 - 가상 내장 스키마 +1): 이전 실행 · 수집 0 · 마커 그대로 · 무효화 0건' `
    ('{0}/{1}/{2}/{3}' -f $migratedNextSchema, @($script:legacyMarkerPathsToClear).Count,
      $(if ([System.IO.File]::Exists($customAbyssMarkerFile)) { [System.IO.File]::ReadAllText($customAbyssMarkerFile) } else { '없음' }), $script:legacyMarkerClearedCount) 'True/0/{}/0'
  [System.IO.File]::WriteAllText($defaultPath, ($realDefault | ConvertTo-Json -Depth 20), $utf8Bom)
  ${function:Save-Config} = $realSaveConfig
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
  $journalLogLinesBefore = @($script:guiLogLines).Count
  Assert-Case '어비스 초기화: 별도 섹션 성공' (Reset-CustomProgress -SectionName 'abyssCustomRepeat') $true
  # 단계 2.3: 어비스 초기화는 완료 기록 폐기를 거칩니다 - 파일이 없으면 바꿀 것이 없어 조용히 지나가야 합니다(경고 0 · 파일 생성 0)
  Assert-Case '어비스 초기화: 완료 기록 파일이 없으면 폐기는 조용히 지나감(완료 기록 파일 0 · 정리 실패 경고 0)' `
    ('{0}/{1}' -f @(Get-ChildItem -LiteralPath $testRoot -Force | Where-Object { $_.Name -like '*abyss_handoff*' }).Count,
      @(@($script:guiLogLines) | Select-Object -Skip $journalLogLinesBefore | Where-Object { $_ -match '완료 기록 정리 실패' }).Count) '0/0'
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
      ($customDeepMarkerFile + '.stale'), ($customLifeMarkerFile + '.stale'),
      $abyssJournalPath, ($abyssJournalPath + '.bak'))) {
    if ([System.IO.File]::Exists($path)) { [System.IO.File]::Delete($path) }
  }
  if ([System.IO.Directory]::Exists($testRoot)) { [System.IO.Directory]::Delete($testRoot, $false) }
}

exit $fails
