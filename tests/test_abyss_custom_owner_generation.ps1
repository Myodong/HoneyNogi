# 어비스 커스텀 owner·진행 세대 회귀 ㉒ - 구현 명세 ① 2.3·3.2 (2026-10-08 신설)
#
# 지키는 것 (설계 v10 1.3·1.7·6.3 '진행 초기화·재구성 경로의 journal·pending 폐기' · 구현 명세 ① 2.2·2.3):
#   - owner 대조 = 5필드(fingerprint·orderKey·lap·index·item) AND 진행 세대(generation). 완료 마커(owner version 3)와 완료 기록(journal)이
#     같은 열쇠로 같은 판을 봅니다 - journal 은 5필드를 owner 에, 세대를 항목의 형제 필드에 둡니다(O01·O05·O09).
#   - 진행 초기화 3경로(Reset-CustomProgress · Save-CustomRandomOrder · Confirm-CustomShuffleReady 의 새 순열)의 순서 ②①③:
#     ② 진행 null(또는 새 순열) + 세대 +1 을 한 번의 저장으로 → ① 어비스 완료 기록 폐기(Remove-AbyssJournalSectionEntries - 실패는 경고만)
#     → ③ 마커 정리(새 순열은 ③ 없음). ① 이 ② 보다 앞이면 ② 가 실패했을 때 pending 만 사라져 클리어한 항목을 다시 돕니다(O02·O03·O06·O07).
#     세대 +1 은 전투 3섹션만 - 생활 노드에는 키를 만들지 않습니다(O10 - 명세 리뷰 2 P2). 어비스가 아니면 journal 을 열지도 않습니다.
#   - 세대가 바뀌지 않는 경로(바퀴 전환 Step · 이미 유효한 순열 · 혼합 리스트 랜덤 해제 - 명세 5절 C8)와 설정 이전의 세대 처리(O04·O11),
#     10→11 구버전 마커 정리(O08 - 저장 성공 뒤 경로당 1회), 섹션 노드 재작성 3함수의 세대 이월(O12 - 명세 5절 A1 'M6').
# 방법:
#   - GUI 함수와 저장소 묶음(머리 주석 ~ '묶음 끝' 표지 주석 사이 최상위 함수)을 이 파일 **최상위**에서 정의합니다 - 클로저 mutator 쪽에서
#     보이는 함수는 최상위 정의뿐입니다(구현 명세 ① 2.0 체크리스트 6). config·마커·journal 은 케이스마다 새 임시 폴더의 **실제 파일**입니다.
#   - 관측용 감시 함수: Save-Config · Update-AbyssJournal · Open-AbyssJournalLock · Read-AbyssJournalCandidate · Clear-CustomMarkerFile ·
#     Remove-AbyssJournalSectionEntries 를 같은 이름으로 가려 호출 순서·횟수를 적고 실제 함수로 넘깁니다(실제 본문은 ${function:…} 로 잡아 둠).
#     '종료 주입' 은 그 지점에서 예외를 던져 뒤 단계를 끊습니다 - 디스크에는 그때까지 쓴 것만 남아 프로세스가 죽은 것과 같습니다.
#     journal 접근 수 = 잠금 열기 + 후보 파일 읽기 수(모든 읽기·쓰기 경로가 둘 중 하나를 지남).
#   - 재시작 판정은 시작 게이트의 마커 대조 블록(if ($script:customActive -and -not $markerStaleBlocked -and (Test-Path …)))을 AST 로 잘라
#     점소싱합니다. 설정 이전 안내 2줄은 최상위 if ($script:configMigrated) 블록을 같은 방식으로 돌립니다(T4-e 3 방식).
#   - O13(단계 2.10 - 구현 명세 ① 2.10 W4): GUI 가 기동 env 로 넘기는 소유자 JSON(완료 마커와 같은 version 3 - New-CustomMarkerOwnerJson ·
#     마무리 실행의 ConvertTo-CustomMarkerOwnerJson)을 워커의 실제 ConvertTo-AbyssJournalOwner 가 꺼낸 owner 5필드·세대가 GUI 의 canonical
#     owner(Get-CustomCanonicalOwner)·진행 세대와 같고, 그 값으로 만든 완료 기록 항목을 GUI 대조(Test-AbyssJournalOwnerMatch)가 같은 판으로 봅니다.
#     워커 함수는 워커 소스에서 이름으로 꺼내 이 파일 최상위에 정의합니다.
# 변이 검증 보강(2026-10-09 - 살아남은 변이를 잡는 행): 폐기할 것의 모양 2종(O02) · 저장소 복구 경고 기록(O03) · 구버전 건수 0(O04) ·
#   세대 역행(O05) · 건수 1 안내(O08) · 세대 키 없는 섹션의 +1(O10) · 설명 키 문구 = config.json(O12 - 명세 대조 P3-1).
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')   # Remove-SourceComments (정적 단언은 주석 뺀 사본으로)

# ===== 상수 =====
$BUNDLE_HEADER_FRAGMENT = '어비스 완료 기록(handoff journal) 저장소'   # 저장소 묶음 머리 주석 (회귀 test_abyss_journal_store 와 같은 경계)
$BUNDLE_END_FRAGMENT = '어비스 완료 기록 저장소 묶음 끝'                 # 저장소 묶음 끝 표지 주석
$ABYSS_SECTION = 'abyssCustomRepeat'
$LIFE_SECTION = 'lifeCustomRepeat'
$BATTLE_SECTIONS = @('customRepeat', 'abyssCustomRepeat', 'deepCustomRepeat')
$ALL_SECTIONS = @('customRepeat', 'abyssCustomRepeat', 'deepCustomRepeat', 'lifeCustomRepeat')
$CRASH_MESSAGE = '주입: 이 지점에서 프로세스 종료'
$GATE_CONDITION_TEXT = '$script:customActive -and -not $markerStaleBlocked -and (Test-Path -LiteralPath $customMarkerFile)'
$NOTICE_CONDITION_TEXT = '$script:configMigrated'
$GATE_DISCARD_NOTICE = '[안내] 현재 진행 위치와 맞지 않는 이전 완료 마커를 정리했습니다.'
$GATE_RECOVERY_NOTICE = '[커스텀] 이전 완료 항목의 마무리를 복구합니다.'
$CLEANUP_WARNING_PATTERN = '^\[경고\] 완료 기록 정리 실패\('
# 명세 2.3 ① 의 경고 문구(종류는 설계 R2 3.6 의 태그별 낱말)
$CLEANUP_WARNING_LOCKED = '[경고] 완료 기록 정리 실패(파일 사용 중) - 옛 세대 기록은 무시됩니다'
$CLEANUP_WARNING_CORRUPT = '[경고] 완료 기록 정리 실패(파일 손상) - 옛 세대 기록은 무시됩니다'
$CLEANUP_WARNING_IO = '[경고] 완료 기록 정리 실패(기록 실패) - 옛 세대 기록은 무시됩니다'
$INJECTED_JOURNAL_EXCEPTION = '주입: 완료 기록 저장 예외'
# 저장소가 잠금 아래 직전본으로 복구했을 때 돌려주는 경고(구현 명세 ① 2.1 읽기 규칙 (c)) - 로그는 호출부 몫
$STORE_RECOVER_WARNING = '[경고] 완료 기록 파일 손상 - 직전본으로 복구'
# 명세 2.2 ⑧ 의 안내 문구({0} = 무효화 건수)
$LEGACY_NOTICE_FORMAT = '[안내] 구버전 커스텀 완료 기록 {0}건을 무효화했습니다 (새 형식 세대 검사 도입 - 해당 항목은 처음부터 다시 진행합니다)'
$LEGACY_NOTICE_THREE = $LEGACY_NOTICE_FORMAT -f 3
$LEGACY_WARNING_PATTERN = '^\[경고\] 구버전 커스텀 완료 기록 파일을 지우지 못했습니다'
$RESET_MARKER_WARNING_PATTERN = '^\[경고\] 이전 완료 기록 파일을 지우지 못했습니다'
$UTF8_BOM = New-Object System.Text.UTF8Encoding($true)
$GUI_FUNCTION_NAMES = @(
    'Read-Config', 'ConvertTo-StrictBoolean', 'Write-Utf8FileAtomic', 'Save-Config', 'Update-ConfigToLatest',
    'Format-CustomItemToken', 'Get-CustomFingerprint', 'Get-CustomOrderKey', 'New-CustomShuffleOrder', 'Test-CustomShuffleOrder',
    'Get-CustomExecutionItems', 'Get-CustomRandomOrderEnabled', 'Get-CustomPositionText', 'Get-CustomTransitionIssues',
    'Get-CustomCurrentContext', 'Get-CustomNextProgress', 'Step-CustomProgress', 'Step-CustomProgressGeneration',
    'Reset-CustomProgress', 'Save-CustomRandomOrder', 'Confirm-CustomShuffleReady', 'Remove-AbyssJournalSectionEntries',
    'New-CustomMarkerOwnerJson', 'Get-CustomCanonicalOwner', 'ConvertTo-CustomMarkerOwnerJson', 'Read-CustomMarkerOwner',
    'Test-CustomMarkerOwnerMatchesContext', 'Test-CustomMarkerValidForCurrent',
    'Get-CustomMarkerFileForSection', 'Get-CustomMarkerStaleFile', 'Clear-CustomMarkerFile', 'Test-CustomMarkerStale',
    'Set-CustomRepeatOnConfig', 'Set-AbyssCustomRepeatOnConfig', 'Set-DeepCustomRepeatOnConfig', 'Save-SettingsFromUi',
    # 단계 2.9 - 마커 대조 블록의 마무리 복구 예약 문장이 S3 와 같은 함수 하나가 됨(구현 명세 ① 2.9 S3 - 블록을 점소싱하면 이 함수를 부름)
    'Set-CustomRecoveryReservation')

# ===== 소스 추출 (최상위 정의) =====
$guiTokens = $null
$parseErrors = $null
$guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ('GUI 파서 오류: ' + $parseErrors[0].Message) }
$bundleHeaders = @($guiTokens | Where-Object {
        $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and $_.Text.Contains($BUNDLE_HEADER_FRAGMENT) })
$bundleEnds = @($guiTokens | Where-Object {
        $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and $_.Text.Contains($BUNDLE_END_FRAGMENT) })
if ($bundleHeaders.Count -ne 1 -or $bundleEnds.Count -ne 1) {
    throw ('저장소 묶음 경계 주석이 1개씩이 아닙니다 (머리 {0} · 끝 {1})' -f $bundleHeaders.Count, $bundleEnds.Count)
}
$bundleFunctionNames = @()
foreach ($statement in $guiAst.EndBlock.Statements) {
    if (-not ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst])) { continue }
    if ($statement.Extent.StartOffset -lt $bundleHeaders[0].Extent.StartOffset) { continue }
    if ($statement.Extent.StartOffset -gt $bundleEnds[0].Extent.StartOffset) { break }
    Invoke-Expression $statement.Extent.Text
    $bundleFunctionNames += $statement.Name
}
if ($bundleFunctionNames -notcontains 'Update-AbyssJournal' -or $bundleFunctionNames -notcontains 'Test-AbyssJournalOwnerMatch') {
    throw '저장소 묶음에서 Update-AbyssJournal · Test-AbyssJournalOwnerMatch 를 찾지 못했습니다'
}
$guiFunctionTexts = @{}
foreach ($functionName in $GUI_FUNCTION_NAMES) {
    $functionAst = $guiAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true) | Select-Object -First 1
    if (-not $functionAst) { throw ('GUI 함수를 찾지 못했습니다: ' + $functionName) }
    $guiFunctionTexts[$functionName] = $functionAst.Extent.Text
    # Save-SettingsFromUi 는 정적 단언만 합니다(UI 의존이 넓어 본체는 돌리지 않음 - 명세 3.2 O12)
    if ($functionName -ne 'Save-SettingsFromUi') { Invoke-Expression $functionAst.Extent.Text }
}
$gateIfs = @($guiAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.IfStatementAst] -and $node.Clauses[0].Item1.Extent.Text -eq $GATE_CONDITION_TEXT
        }, $true))
if ($gateIfs.Count -ne 1) { throw ('시작 게이트 마커 대조 블록이 {0}개입니다(1개여야 함)' -f $gateIfs.Count) }
$gateMarkerBlock = [scriptblock]::Create($gateIfs[0].Extent.Text)
$noticeIfs = @($guiAst.EndBlock.Statements | Where-Object {
        ($_ -is [System.Management.Automation.Language.IfStatementAst]) -and ($_.Clauses[0].Item1.Extent.Text -eq $NOTICE_CONDITION_TEXT) })
if ($noticeIfs.Count -ne 1) { throw ('설정 이전 안내 블록이 {0}개입니다(1개여야 함)' -f $noticeIfs.Count) }
$migrationNoticeBlock = [scriptblock]::Create($noticeIfs[0].Extent.Text)
$script:abyssJournalSavedBy = 'gui'
# O13 - 워커의 소유자 JSON 해석 함수(단계 2.10 W4 - 묶음 끝 표지 뒤의 워커 전용 순수 함수). 최상위 정의(체크리스트 6)
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('ConvertTo-AbyssJournalOwner')))

# ===== GUI 의존 모형 =====
$script:guiLogLines = New-Object System.Collections.Generic.List[string]
function Add-GuiLog {
    # GUI 로그(실제 서명 param([string]$Message)) - 찍힌 줄을 모읍니다
    param([string]$Message)
    $script:guiLogLines.Add($Message)
}
# O12 섹션 노드 재작성 3함수가 읽는 목록 함수·컨트롤(Checked·Value 만 가진 객체) - 명세 3.2 O12 의 모의 범위
function Get-CustomItemsFromList { return $DUNGEON_ITEMS }
function Get-AbyssCustomItemsFromList { return $ABYSS_ITEMS }
function Get-DeepCustomItemsFromList { return $DEEP_ITEMS }
$chkCrRandom = [pscustomobject]@{ Checked = $false }
$rbCrCount = [pscustomobject]@{ Checked = $false }
$numCrLaps = [pscustomobject]@{ Value = 1 }
$chkAcrRandom = [pscustomobject]@{ Checked = $false }
$rbAcrCount = [pscustomobject]@{ Checked = $false }
$numAcrLaps = [pscustomobject]@{ Value = 1 }
$chkDcrRandom = [pscustomobject]@{ Checked = $false }
$rbDcrCount = [pscustomobject]@{ Checked = $false }
$numDcrLaps = [pscustomobject]@{ Value = 1 }
$script:customEnabledWish = $true

# ===== 감시 함수 (실제 본문을 잡아 두고 같은 이름으로 가림) =====
$script:realSaveConfig = ${function:Save-Config}
function Save-Config {
    param($Config)
    $script:eventLog.Add('save')
    if ($null -ne $script:onSaveObserver) { & $script:onSaveObserver }
    if ($script:saveConfigMode -eq 'throw') { throw '주입: config 저장 예외' }
    & $script:realSaveConfig $Config
}
$script:realUpdateAbyssJournal = ${function:Update-AbyssJournal}
function Update-AbyssJournal {
    param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect = $null)
    $script:eventLog.Add('journal')
    if ($script:journalUpdateMode -eq 'throw') { throw $INJECTED_JOURNAL_EXCEPTION }
    $spyResult = & $script:realUpdateAbyssJournal -Path $Path -Mutator $Mutator -Expect $Expect
    $script:journalUpdateTags.Add([string]$spyResult.Tag)
    return $spyResult
}
$script:realOpenAbyssJournalLock = ${function:Open-AbyssJournalLock}
function Open-AbyssJournalLock {
    param([string]$Path, $Budget)
    $script:journalAccessCount++
    return (& $script:realOpenAbyssJournalLock -Path $Path -Budget $Budget)
}
$script:realReadAbyssJournalCandidate = ${function:Read-AbyssJournalCandidate}
function Read-AbyssJournalCandidate {
    param([string]$FilePath)
    $script:journalAccessCount++
    return (& $script:realReadAbyssJournalCandidate -FilePath $FilePath)
}
$script:realClearCustomMarkerFile = ${function:Clear-CustomMarkerFile}
function Clear-CustomMarkerFile {
    # 모드(파일 이름별): fail-always = 늘 실패 / fail-first = 첫 시도만 실패 / fail-after-first = 두 번째 시도부터 실패.
    # 실패 주입은 실제 함수를 부르지 않고 $false - 파일은 그대로 남습니다
    param([string]$Path)
    $script:eventLog.Add('marker')
    $clearKey = [System.IO.Path]::GetFileName($Path)
    $script:markerClearCounts[$clearKey] = 1 + [int]$script:markerClearCounts[$clearKey]
    if ($script:crashPoint -eq 'marker') { throw $CRASH_MESSAGE }
    $clearMode = [string]$script:markerClearModes[$clearKey]
    $callNumber = [int]$script:markerClearCounts[$clearKey]
    if ($clearMode -eq 'fail-always') { return $false }
    if ($clearMode -eq 'fail-first' -and $callNumber -eq 1) { return $false }
    if ($clearMode -eq 'fail-after-first' -and $callNumber -gt 1) { return $false }
    return (& $script:realClearCustomMarkerFile -Path $Path)
}
$script:realRemoveAbyssJournalSectionEntries = ${function:Remove-AbyssJournalSectionEntries}
function Remove-AbyssJournalSectionEntries {
    param([string]$SectionName)
    $script:eventLog.Add('cleanup')
    if ($script:crashPoint -eq 'cleanup') { throw $CRASH_MESSAGE }
    & $script:realRemoveAbyssJournalSectionEntries -SectionName $SectionName
}

# ===== 공통 단언·관측 =====
function Assert-Case {
    param([string]$Name, $Actual, $Expect)
    if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
    else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Reset-Observation {
    # 케이스마다 관측 상태와 주입 모드를 비웁니다
    $script:eventLog = New-Object System.Collections.Generic.List[string]
    $script:guiLogLines = New-Object System.Collections.Generic.List[string]
    $script:journalUpdateTags = New-Object System.Collections.Generic.List[string]
    $script:journalAccessCount = 0
    $script:journalUpdateMode = ''
    $script:saveConfigMode = ''
    $script:crashPoint = ''
    $script:onSaveObserver = $null
    $script:markerClearCounts = @{}
    $script:markerClearModes = @{}
}

$testRootFolder = Join-Path ([System.IO.Path]::GetTempPath()) ('honeynogi_owner_generation_' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($testRootFolder) | Out-Null
$script:caseCounter = 0
function Use-CaseFolder {
    # 케이스마다 새 임시 폴더 - GUI 함수가 읽는 경로 변수(config·마커 4개·journal·기본 config 위치)를 전부 그 폴더로 돌립니다
    param([string]$Name)
    $script:caseCounter++
    $folder = Join-Path $testRootFolder ('{0:D2}_{1}' -f $script:caseCounter, $Name)
    [System.IO.Directory]::CreateDirectory($folder) | Out-Null
    $script:caseFolder = $folder
    $script:scriptRoot = $folder
    $script:configPath = Join-Path $folder 'config.json'
    $script:customDungeonMarkerFile = Join-Path $folder 'custom_done.marker'
    $script:customAbyssMarkerFile = Join-Path $folder 'abyss_custom_done.marker'
    $script:customDeepMarkerFile = Join-Path $folder 'deep_custom_done.marker'
    $script:customLifeMarkerFile = Join-Path $folder 'life_custom_done.marker'
    $script:customMarkerFile = $script:customDungeonMarkerFile
    $script:abyssJournalPath = Join-Path $folder 'abyss_handoff.json'
    Reset-Observation
}

function Get-FileDigest {
    # 파일 내용 해시 앞 16자(없으면 '없음') - '바뀌지 않음' 단언용
    param([string]$Path)
    if (-not [System.IO.File]::Exists($Path)) { return '없음' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($Path)))).Replace('-', '').Substring(0, 16) }
    finally { $sha.Dispose() }
}

function Get-FolderListing {
    param([string]$Folder)
    if (-not [System.IO.Directory]::Exists($Folder)) { return '(폴더 없음)' }
    return ((@([System.IO.Directory]::GetFiles($Folder)) | ForEach-Object { [System.IO.Path]::GetFileName($_) } | Sort-Object) -join ',')
}

function Get-CaseState {
    # config · 마커 4개 · journal 본 파일·직전본의 내용 해시와 폴더 목록 - '아무것도 바뀌지 않음' 단언용
    return ('cfg={0} mk={1}/{2}/{3}/{4} jr={5}/{6} ls={7}' -f (Get-FileDigest $script:configPath),
        (Get-FileDigest $script:customDungeonMarkerFile), (Get-FileDigest $script:customAbyssMarkerFile),
        (Get-FileDigest $script:customDeepMarkerFile), (Get-FileDigest $script:customLifeMarkerFile),
        (Get-FileDigest $script:abyssJournalPath), (Get-FileDigest ($script:abyssJournalPath + '.bak')), (Get-FolderListing $script:caseFolder))
}

function Get-JournalState {
    # journal 본 파일·직전본·임시·잠금 파일 상태만(config·마커 제외)
    $journalFiles = @(@([System.IO.Directory]::GetFiles($script:caseFolder)) | ForEach-Object { [System.IO.Path]::GetFileName($_) } |
            Where-Object { $_ -like '*abyss_handoff*' } | Sort-Object)
    return ('{0}/{1} [{2}]' -f (Get-FileDigest $script:abyssJournalPath), (Get-FileDigest ($script:abyssJournalPath + '.bak')), ($journalFiles -join ','))
}

function Get-EventOrder {
    # 감시 함수가 적은 순서 중 ② 저장(save) · ① 완료 기록 저장(journal) · ③ 마커 정리(marker)만
    return ((@($script:eventLog) | Where-Object { @('save', 'journal', 'marker') -contains $_ }) -join ',')
}

function Get-LogCount {
    param([string]$Pattern)
    return @(@($script:guiLogLines) | Where-Object { $_ -match $Pattern }).Count
}

function Get-ExactLogCount {
    param([string]$Line)
    return @(@($script:guiLogLines) | Where-Object { $_ -eq $Line }).Count
}

function Get-ResultText {
    # 함수 출력 전체를 '개수:값,…' 으로 - bool 반환에 다른 출력이 섞이면(헬퍼 출력 누수) 개수가 늘어 드러납니다.
    # 호출부는 출력을 @(…) 로 받아 넘깁니다 - 출력이 없을 때 그냥 대입하면 $null 이 되고 @($null) 은 1개로 셉니다(PS 5.1)
    param($Output)
    $outputItems = @($Output)
    return ('{0}:{1}' -f $outputItems.Count, (($outputItems | ForEach-Object { [string]$_ }) -join ','))
}

# ===== 픽스처 =====
$DUNGEON_ITEMS = @(
    [pscustomobject]@{ difficulty = '어려움'; stage = '1-1'; coin = $true; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false },
    [pscustomobject]@{ difficulty = '일반'; stage = '1-2'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false },
    [pscustomobject]@{ difficulty = '어려움'; stage = '1-3'; coin = $true; doubleLoot = $true; exhaustContinue = $true; noDoubleSweep = $false })
$ABYSS_ITEMS = @(
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '없음' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '입문'; dungeon = '허상의 정박지'; matching = '우연한 만남' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '일반'; dungeon = '흩어진 물길'; matching = '없음' })
$DEEP_ITEMS = @(
    [pscustomobject]@{ difficulty = '어려움'; stage = '1-2'; coin = $true; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false },
    [pscustomobject]@{ difficulty = '어려움'; stage = '1-3'; coin = $false; doubleLoot = $false; exhaustContinue = $true; noDoubleSweep = $false })
$LIFE_ITEMS = @(
    [pscustomobject]@{ kind = 'life'; skill = 'wood'; target = '뾰족 나무'; count = 1 },
    [pscustomobject]@{ kind = 'life'; skill = 'ore'; target = '철광석'; count = 2 })
$SECTION_ITEMS = @{ customRepeat = $DUNGEON_ITEMS; abyssCustomRepeat = $ABYSS_ITEMS; deepCustomRepeat = $DEEP_ITEMS; lifeCustomRepeat = $LIFE_ITEMS }

function New-TestProgress {
    param([string]$Section, [int]$Lap = 1, [int]$Index = 0, $ShuffleOrder = $null)
    $progress = [pscustomobject]@{ lap = $Lap; index = $Index; fingerprint = (Get-CustomFingerprint -Items $SECTION_ITEMS[$Section]) }
    if ($null -ne $ShuffleOrder) { $progress | Add-Member -NotePropertyName 'shuffleOrder' -NotePropertyValue ([array]@($ShuffleOrder)) }
    return $progress
}

function New-TestConfig {
    # 커스텀 4섹션 config. -Generations: 섹션 → 세대(키가 없는 섹션은 progressGeneration 키 자체가 없음) / -Progress: 섹션 → 진행 /
    # -Random: 랜덤 진행을 켤 섹션 / -Items: 섹션 → 항목(기본 픽스처 대신)
    param([hashtable]$Generations = @{}, [hashtable]$Progress = @{}, [string[]]$Random = @(), [hashtable]$Items = @{})
    $config = [pscustomobject]@{ configSchemaVersion = 11 }
    foreach ($section in $ALL_SECTIONS) {
        $sectionItems = $SECTION_ITEMS[$section]
        if ($Items.ContainsKey($section)) { $sectionItems = $Items[$section] }
        $node = [pscustomobject]@{
            items           = [array]$sectionItems
            randomOrder     = ($Random -contains $section)
            listRepeat      = 'infinite'
            listRepeatCount = 1
            progress        = $null
        }
        if ($Progress.ContainsKey($section)) { $node.progress = $Progress[$section] }
        if ($Generations.ContainsKey($section)) {
            $node | Add-Member -NotePropertyName 'progressGeneration' -NotePropertyValue $Generations[$section]
        }
        $config | Add-Member -NotePropertyName $section -NotePropertyValue $node
    }
    return $config
}

function Write-TestConfig {
    param($Config)
    [System.IO.File]::WriteAllText($script:configPath, ($Config | ConvertTo-Json -Depth 20), $UTF8_BOM)
}

function Read-TestConfig {
    return ([System.IO.File]::ReadAllText($script:configPath) | ConvertFrom-Json)
}

function Get-GenerationText {
    # 섹션별 세대(키 없음 = '없음') 한 줄
    param($Config)
    return ((@($ALL_SECTIONS) | ForEach-Object {
                $generationProperty = $Config.$_.PSObject.Properties['progressGeneration']
                '{0}={1}' -f $_, $(if ($generationProperty) { [string]$generationProperty.Value } else { '없음' })
            }) -join ' ')
}

function New-TestOwner {
    # journal owner(5필드) = 마커 owner JSON(version 3)에서 version·generation 을 뺀 나머지 전부. 세대는 항목의 형제 필드로 따로 둡니다
    # (명세 2.1 owner 비교 · 2.10 W3 - 워커 기록과 같은 열쇠)
    param($Context)
    $markerOwner = (New-CustomMarkerOwnerJson -Context $Context) | ConvertFrom-Json
    $owner = [pscustomobject]@{}
    foreach ($property in $markerOwner.PSObject.Properties) {
        if ($property.Name -eq 'version' -or $property.Name -eq 'generation') { continue }
        $owner | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
    }
    return $owner
}

function New-TestEntry {
    # 완료 기록 항목 - 저장소 기본값(New-AbyssJournalEntry) 위에 이 케이스가 쓰는 필드만 덮습니다
    param([string]$Section, $Owner, [int]$Generation = 0, [string]$Stage = 'cleared', [string]$RunId = '')
    $entry = New-AbyssJournalEntry -Stage $Stage
    $entry.section = $Section
    $entry.generation = $Generation
    $entry.owner = $Owner
    $entry.runId = $RunId
    $entry.decision = 'exit'
    return $entry
}

function New-TestPending {
    # pending 원소(명세 2.5a ① - owner 5필드 · generation · nonce · stage · createdAt). section 필드는 없습니다(어비스 커스텀 전용 - 5절 C6)
    param($Owner, [int]$Generation, [string]$Nonce, [string]$Stage = 'inside-handoff')
    return [pscustomobject]@{ owner = $Owner; generation = $Generation; nonce = $Nonce; stage = $Stage; createdAt = (Get-AbyssJournalTimeText) }
}

function Write-TestJournal {
    # 저장소 직렬화(ConvertTo-AbyssJournalText - 읽기 규칙 검사 포함) 그대로 파일을 씁니다
    param([string]$Path, $Entries = @(), $Applied = @(), $Pending = @(), [long]$Seq = 1)
    $journal = New-AbyssJournalEmpty
    $journal.seq = $Seq
    $journal.entries = [object[]]@($Entries)
    $journal.applied = [object[]]@($Applied)
    $journal.pending = [object[]]@($Pending)
    [System.IO.File]::WriteAllText($Path, (ConvertTo-AbyssJournalText -Journal $journal), $UTF8_BOM)
}

function Read-TestJournal {
    if (-not [System.IO.File]::Exists($script:abyssJournalPath)) { return $null }
    return ([System.IO.File]::ReadAllText($script:abyssJournalPath) | ConvertFrom-Json)
}

function Get-JournalSummary {
    # 'entries=nonce,… pending=n applied=nonce,…' - 남은 항목·큐·applied 를 한 줄로
    $journal = Read-TestJournal
    if ($null -eq $journal) { return '(파일 없음)' }
    return ('entries={0} pending={1} applied={2}' -f ((@($journal.entries) | ForEach-Object { [string]$_.nonce }) -join ','),
        @($journal.pending).Count, ((@($journal.applied) | ForEach-Object { [string]$_ }) -join ','))
}

function Get-AdvanceCandidateCount {
    # 큐 반영(단계 2.5a)의 전제 - pending 중 지금 owner 와 5필드 + 세대가 모두 같은 원소 수. 0 이면 그 큐로는 전진하지 않습니다
    param($Journal, $Context, $Generation = $null)
    if ($null -eq $Journal) { return 0 }
    if ($null -eq $Generation) { $Generation = $Context.Generation }
    $owner = New-TestOwner -Context $Context
    return @(@($Journal.pending) | Where-Object { Test-AbyssJournalOwnerMatch -Entry $_ -Owner $owner -Generation $Generation }).Count
}

function Write-TestMarker {
    # 그 섹션 마커 파일에 지금 컨텍스트의 owner(version 3)를 씁니다 - 워커가 클리어 확정 때 남기는 모양
    param([string]$Section, $Context)
    [System.IO.File]::WriteAllText((Get-CustomMarkerFileForSection -SectionName $Section), (New-CustomMarkerOwnerJson -Context $Context))
}

function ConvertTo-LegacyV2MarkerJson {
    # 스키마 10 까지의 GUI 가 쓰던 owner(version 2 + 5필드, 세대 없음) - 같은 컨텍스트의 version 3 에서 만듭니다
    param($Context)
    $owner = (New-CustomMarkerOwnerJson -Context $Context) | ConvertFrom-Json
    $owner.version = 2
    $owner.PSObject.Properties.Remove('generation')
    return ($owner | ConvertTo-Json -Compress)
}

function Lock-TestJournal {
    # 같은 프로세스에서 .lock 을 쥡니다(실제 잠금 함수 - 감시 함수의 접근 수에 넣지 않음). 저장소의 다음 잠금 시도는 예산 끝까지 실패해 locked
    $held = & $script:realOpenAbyssJournalLock -Path $script:abyssJournalPath -Budget @{ Left = 1 }
    if ($null -eq $held.Stream) { throw ('시험용 잠금을 얻지 못했습니다: ' + $held.Tag) }
    return $held.Stream
}

function Lock-TestConfig {
    # config 를 FileShare.Read 로 쥡니다 - 읽기는 되고 File.Replace(저장)는 실패합니다(기존 회귀와 같은 주입)
    return [System.IO.File]::Open($script:configPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
}

function Invoke-StartGateMarkerCheck {
    # 재시작 모사 - 시작 게이트의 마커 대조 블록을 소스 그대로 점소싱합니다. 반환 @{ Recovery; MarkerLeft; Clears; Discarded; RecoveryLog }
    param([string]$Section)
    $script:customConfigSection = $Section
    $script:customMarkerFile = Get-CustomMarkerFileForSection -SectionName $Section
    $script:customActive = $true
    $script:customRecoveryPending = $false
    $script:customRestart = $false
    $script:customPrevItem = ''
    $script:customMarkerIgnore = $false
    $script:crashPoint = ''
    $script:markerClearCounts = @{}
    $script:guiLogLines.Clear()
    $markerStaleBlocked = $false
    . $gateMarkerBlock
    return @{
        Recovery    = [bool]$script:customRecoveryPending
        MarkerLeft  = [System.IO.File]::Exists($script:customMarkerFile)
        Clears      = [int]$script:markerClearCounts[[System.IO.Path]::GetFileName($script:customMarkerFile)]
        Discarded   = (Get-ExactLogCount $GATE_DISCARD_NOTICE)
        RecoveryLog = (Get-ExactLogCount $GATE_RECOVERY_NOTICE)
    }
}

function Format-GateResult {
    param($Result)
    return ('복구 예약 {0} · 마커 남음 {1} · 정리 {2} · 폐기 안내 {3}' -f $Result.Recovery, $Result.MarkerLeft, $Result.Clears, $Result.Discarded)
}

function Invoke-MigrationNotice {
    # 설정 이전 안내 블록(최상위 if)을 소스 그대로 실행 - 블록이 읽는 $script: 상태는 직전 Update-ConfigToLatest 가 남긴 값
    $script:guiLogLines.Clear()
    $script:configMigrated = $true
    $script:gatherWaitReset = 0
    . $migrationNoticeBlock
}

function Invoke-WithCrash {
    # 종료 주입 지점(cleanup = ① 직전 · marker = ③ 직전)에서 끊긴 호출 → 끊겼으면 $true
    param([string]$CrashPoint, [scriptblock]$Call)
    $script:crashPoint = $CrashPoint
    $crashed = $false
    try {
        [void](& $Call)
    } catch {
        if ($_.Exception.Message -ne $CRASH_MESSAGE) { throw }
        $crashed = $true
    } finally {
        $script:crashPoint = ''
    }
    return $crashed
}

$REAL_DEFAULT_CONFIG_TEXT = [System.IO.File]::ReadAllText((Join-Path $projectRoot 'config.json'))
function Initialize-MigrationCase {
    # 설정 이전 케이스: 저장소 config.json 을 내장 기본(config.default.json)으로 두고, 사용자 config = 그 사본에서 스키마를 낮추고
    # 전투 3섹션의 세대·설명 키를 뺀 것(스키마 11 이전 모양). 반환 = 사용자 config 객체(쓰기는 호출부)
    param([string]$Name, [int]$UserSchema)
    Use-CaseFolder -Name $Name
    [System.IO.File]::WriteAllText((Join-Path $script:caseFolder 'config.default.json'), $REAL_DEFAULT_CONFIG_TEXT, $UTF8_BOM)
    $userConfig = $REAL_DEFAULT_CONFIG_TEXT | ConvertFrom-Json
    $userConfig.configSchemaVersion = $UserSchema
    foreach ($section in $BATTLE_SECTIONS) {
        $userConfig.$section.PSObject.Properties.Remove('progressGeneration')
        $userConfig.$section.PSObject.Properties.Remove('_progressGeneration')
    }
    return $userConfig
}

function Get-MarkerDigests {
    return ('{0}/{1}/{2}/{3}' -f (Get-FileDigest $script:customDungeonMarkerFile), (Get-FileDigest $script:customAbyssMarkerFile),
        (Get-FileDigest $script:customDeepMarkerFile), (Get-FileDigest $script:customLifeMarkerFile))
}

function Write-LegacyMarkers {
    # 마커 4개(생활 포함)에 version 2 owner 를 씁니다 - 생활은 이전 대상이 아니라 그대로 남아야 합니다
    param([string[]]$Sections = $ALL_SECTIONS)
    $legacyContext = @{ Items = $DUNGEON_ITEMS; Order = $null; Lap = 1; Index = 0; Item = $DUNGEON_ITEMS[0]; Generation = 0 }
    foreach ($section in $Sections) {
        [System.IO.File]::WriteAllText((Get-CustomMarkerFileForSection -SectionName $section), (ConvertTo-LegacyV2MarkerJson -Context $legacyContext))
    }
}

function Get-StaleCount {
    return @(@($script:customDungeonMarkerFile, $script:customAbyssMarkerFile, $script:customDeepMarkerFile, $script:customLifeMarkerFile) |
            Where-Object { [System.IO.File]::Exists($_ + '.stale') }).Count
}

function Initialize-AbyssFixture {
    # 어비스 섹션 고정 픽스처: 세대 2 · 진행(기본 1바퀴 2번 = index 1, -NoProgress 면 없음) · 랜덤(-Random) · 완료 기록 = 어비스 cleared 1
    # (지금 owner) + 비커스텀 1(section '') · applied 둘 다 · pending 1(지금 owner) · 지금 위치의 v3 마커. 반환 = @{ ClearedNonce; OtherNonce; Context }
    # -Index 0 = 1바퀴 0번: 진행 초기화 뒤 위치가 그대로라 5필드가 다시 맞습니다 - 세대만이 옛 기록을 가르는 상황(O07)
    param([string]$Name, [switch]$Random, [switch]$NoProgress, [int]$Index = 1)
    Use-CaseFolder -Name $Name
    $progressTable = @{}
    if (-not $NoProgress) { $progressTable[$ABYSS_SECTION] = New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index $Index }
    $randomSections = @()
    if ($Random) { $randomSections = @($ABYSS_SECTION) }
    Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 0; abyssCustomRepeat = 2; deepCustomRepeat = 0 } -Progress $progressTable -Random $randomSections)
    $context = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    $owner = New-TestOwner -Context $context
    $clearedEntry = New-TestEntry -Section $ABYSS_SECTION -Owner $owner -Generation 2
    $otherEntry = New-TestEntry -Section '' -Owner ([pscustomobject]@{ runId = 'run-other' }) -RunId 'run-other'
    Write-TestJournal -Path $script:abyssJournalPath -Entries @($clearedEntry, $otherEntry) `
        -Applied @($otherEntry.nonce, $clearedEntry.nonce) -Pending @(New-TestPending -Owner $owner -Generation 2 -Nonce $clearedEntry.nonce)
    Write-TestMarker -Section $ABYSS_SECTION -Context $context
    return @{ ClearedNonce = [string]$clearedEntry.nonce; OtherNonce = [string]$otherEntry.nonce; Context = $context }
}

function Invoke-ResetPath {
    # 진행 초기화 3경로 공용 호출 - Path: reset / random(랜덤 켬) / shuffle(새 순열). 반환 = 함수 출력 그대로
    param([string]$Path, [string]$Section = $ABYSS_SECTION)
    if ($Path -eq 'reset') { return (Reset-CustomProgress -SectionName $Section) }
    if ($Path -eq 'random') { return (Save-CustomRandomOrder -SectionName $Section -Enabled $true) }
    return (Confirm-CustomShuffleReady -SectionName $Section)
}

# ===== O01 canonical 비교 - 순열 변경 · 동일 토큰 중복 =====
function Test-CaseO01 {
    # 같은 fingerprint·lap·index·item 에서 orderKey 만 다름 (두 순열 모두 실행 0번 = 등록 1번 항목)
    $contextA = @{ Items = $DUNGEON_ITEMS; Order = @(0, 2, 1); Lap = 2; Index = 0; Item = $DUNGEON_ITEMS[0]; Generation = 4 }
    $contextB = @{ Items = $DUNGEON_ITEMS; Order = @(0, 1, 2); Lap = 2; Index = 0; Item = $DUNGEON_ITEMS[0]; Generation = 4 }
    $ownerA = New-TestOwner -Context $contextA
    $ownerB = New-TestOwner -Context $contextB
    Assert-Case 'O01 순열 변경 전제: fingerprint·lap·index·item 같음 · orderKey 만 다름' `
        ('{0}/{1}/{2}/{3}/{4}' -f ($ownerA.fingerprint -eq $ownerB.fingerprint), ($ownerA.lap -eq $ownerB.lap), ($ownerA.index -eq $ownerB.index),
            ($ownerA.item -eq $ownerB.item), ($ownerA.orderKey -ne $ownerB.orderKey)) 'True/True/True/True/True'
    $markerOwnerA = (New-CustomMarkerOwnerJson -Context $contextA) | ConvertFrom-Json
    Assert-Case 'O01 순열 변경 - 마커 대조: 같은 순열 일치 · 순열만 다르면 불일치' `
        ('{0}/{1}' -f (Test-CustomMarkerOwnerMatchesContext -Owner $markerOwnerA -Context $contextA),
            (Test-CustomMarkerOwnerMatchesContext -Owner $markerOwnerA -Context $contextB)) 'True/False'
    $entryA = New-TestEntry -Section $ABYSS_SECTION -Owner $ownerA -Generation 4
    Assert-Case 'O01 순열 변경 - journal 대조: 같은 순열 일치 · 순열만 다르면 불일치' `
        ('{0}/{1}' -f (Test-AbyssJournalOwnerMatch -Entry $entryA -Owner $ownerA -Generation 4),
            (Test-AbyssJournalOwnerMatch -Entry $entryA -Owner $ownerB -Generation 4)) 'True/False'
    # 같은 항목 토큰이 0번·2번에 중복된 순차 목록 - index 가 둘을 가릅니다
    $duplicateItems = @($ABYSS_ITEMS[0], $ABYSS_ITEMS[1], $ABYSS_ITEMS[0])
    $contextFirst = @{ Items = $duplicateItems; Order = $null; Lap = 1; Index = 0; Item = $duplicateItems[0]; Generation = 0 }
    $contextThird = @{ Items = $duplicateItems; Order = $null; Lap = 1; Index = 2; Item = $duplicateItems[2]; Generation = 0 }
    $ownerFirst = New-TestOwner -Context $contextFirst
    $ownerThird = New-TestOwner -Context $contextThird
    Assert-Case 'O01 동일 토큰 중복 전제: 0번·2번 owner 는 index 만 다름' `
        ('{0}/{1}/{2}/{3}' -f ($ownerFirst.item -eq $ownerThird.item), ($ownerFirst.fingerprint -eq $ownerThird.fingerprint),
            ($ownerFirst.orderKey -eq $ownerThird.orderKey), ('{0}-{1}' -f $ownerFirst.index, $ownerThird.index)) 'True/True/True/0-2'
    $markerOwnerFirst = (New-CustomMarkerOwnerJson -Context $contextFirst) | ConvertFrom-Json
    Assert-Case 'O01 동일 토큰 중복 - 마커 대조: 0번 마커는 0번만 일치(2번 불일치)' `
        ('{0}/{1}' -f (Test-CustomMarkerOwnerMatchesContext -Owner $markerOwnerFirst -Context $contextFirst),
            (Test-CustomMarkerOwnerMatchesContext -Owner $markerOwnerFirst -Context $contextThird)) 'True/False'
    $entryFirst = New-TestEntry -Section $ABYSS_SECTION -Owner $ownerFirst -Generation 0
    Assert-Case 'O01 동일 토큰 중복 - journal 대조: 0번 기록은 0번만 일치(2번 불일치)' `
        ('{0}/{1}' -f (Test-AbyssJournalOwnerMatch -Entry $entryFirst -Owner $ownerFirst -Generation 0),
            (Test-AbyssJournalOwnerMatch -Entry $entryFirst -Owner $ownerThird -Generation 0)) 'True/False'
}

# ===== O02 첫 항목 pending 뒤 진행 초기화 → 세대 +1 → 5필드가 다시 맞아도 stale =====
function Test-CaseO02 {
    Use-CaseFolder -Name 'O02'
    Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 0; abyssCustomRepeat = 0; deepCustomRepeat = 0 } `
            -Progress @{ abyssCustomRepeat = (New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index 0) })
    $oldContext = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    $oldOwner = New-TestOwner -Context $oldContext
    $clearedEntry = New-TestEntry -Section $ABYSS_SECTION -Owner $oldOwner -Generation 0
    $otherEntry = New-TestEntry -Section '' -Owner ([pscustomobject]@{ runId = 'run-other' }) -RunId 'run-other'
    Write-TestJournal -Path $script:abyssJournalPath -Entries @($clearedEntry, $otherEntry) `
        -Applied @($otherEntry.nonce) -Pending @(New-TestPending -Owner $oldOwner -Generation 0 -Nonce $clearedEntry.nonce)
    Write-TestMarker -Section $ABYSS_SECTION -Context $oldContext
    Assert-Case 'O02 전제: 1바퀴 0번 pending 이 지금 진행(세대 0)의 전진 후보' (Get-AdvanceCandidateCount -Journal (Read-TestJournal) -Context $oldContext) 1
    $resetOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION)
    $newContext = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    $newOwner = New-TestOwner -Context $newContext
    Assert-Case 'O02 Reset: 반환 True 하나 · 세대 0 → 1 · 진행 null' `
        ('{0} · {1} · {2}' -f (Get-ResultText $resetOutput), (Read-TestConfig).abyssCustomRepeat.progressGeneration,
            ($null -eq (Read-TestConfig).abyssCustomRepeat.progress)) '1:True · 1 · True'
    Assert-Case 'O02 Reset 뒤 위치는 다시 1바퀴 0번 - 5필드가 옛 owner 와 그대로 같음' `
        (($newOwner | ConvertTo-Json -Compress) -eq ($oldOwner | ConvertTo-Json -Compress)) $true
    Assert-Case 'O02 Reset 뒤: 옛 pending 의 5필드만 보면 일치하지만 세대 1 로는 불일치 - 대조 결과(옛 세대로/지금 세대로)' `
        ('{0}/{1}' -f (Test-AbyssJournalOwnerMatch -Entry (New-TestPending -Owner $oldOwner -Generation 0 -Nonce 'x') -Owner $newOwner -Generation 0),
            (Test-AbyssJournalOwnerMatch -Entry (New-TestPending -Owner $oldOwner -Generation 0 -Nonce 'x') -Owner $newOwner -Generation $newContext.Generation)) 'True/False'
    Assert-Case 'O02 Reset 뒤 journal: 어비스 항목·pending 제거 · 비커스텀 항목과 그 applied 는 그대로 · 전진 후보 0' `
        ('{0} · {1}' -f (Get-JournalSummary), (Get-AdvanceCandidateCount -Journal (Read-TestJournal) -Context $newContext)) `
        ('entries={0} pending=0 applied={0} · 0' -f $otherEntry.nonce)
    Assert-Case 'O02 Reset 뒤 마커: 정리됨 · 경고 0' `
        ('{0}/{1}' -f [System.IO.File]::Exists($script:customAbyssMarkerFile), (Get-LogCount '^\[경고\]')) 'False/0'

    # 변형 - ① 이 실패해(완료 기록 잠김) pending 이 파일에 남아도: 세대가 달라 전진 후보 0 (세대가 정답이고 폐기는 정리 - 설계 v10 6.3)
    Use-CaseFolder -Name 'O02-locked'
    Write-TestConfig (New-TestConfig -Generations @{ abyssCustomRepeat = 0 } `
            -Progress @{ abyssCustomRepeat = (New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index 0) })
    $lockedOldContext = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    $lockedOldOwner = New-TestOwner -Context $lockedOldContext
    $lockedEntry = New-TestEntry -Section $ABYSS_SECTION -Owner $lockedOldOwner -Generation 0
    Write-TestJournal -Path $script:abyssJournalPath -Entries @($lockedEntry) -Pending @(New-TestPending -Owner $lockedOldOwner -Generation 0 -Nonce $lockedEntry.nonce)
    $journalBefore = Get-JournalState
    $lockStream = Lock-TestJournal
    try { $lockedOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION) }
    finally { $lockStream.Dispose() }
    $lockedNewContext = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    Assert-Case 'O02 변형(① 잠김): 성공 반환 · 경고 1 · journal 그대로(pending 남음)' `
        ('{0} · {1} · {2} · {3}' -f (Get-ResultText $lockedOutput), (Get-ExactLogCount $CLEANUP_WARNING_LOCKED), ((Get-JournalState) -eq $journalBefore),
            @((Read-TestJournal).pending).Count) '1:True · 1 · True · 1'
    Assert-Case 'O02 변형(① 잠김): 남은 pending 의 전진 후보 - 옛 세대로 세면 1 · 지금 세대(1)로 세면 0' `
        ('{0}/{1}' -f (Get-AdvanceCandidateCount -Journal (Read-TestJournal) -Context $lockedNewContext -Generation 0),
            (Get-AdvanceCandidateCount -Journal (Read-TestJournal) -Context $lockedNewContext)) '1/0'

    # 변형 - 폐기할 것의 모양 두 가지(변이 검증 보강 2026-10-09): ⓐ 어비스 항목만 있고 pending 은 없음(클리어 뒤 전진까지 끝난 가장
    #   흔한 모양) ⓑ 어비스 항목 없이 pending 만 있음. 위 픽스처는 항목과 pending 이 늘 함께 있어서, 걷어 낼 조건을 '둘 다 있을 때만'
    #   이나 '항목이 있을 때만' 으로 좁혀도 통과했습니다 - 그러면 한쪽이 파일에 남습니다(세대가 달라 오계상은 없지만 파일이 계속 커짐)
    foreach ($shape in @('항목만', 'pending만')) {
        Use-CaseFolder -Name ('O02-shape-' + $shape)
        Write-TestConfig (New-TestConfig -Generations @{ abyssCustomRepeat = 1 } `
                -Progress @{ abyssCustomRepeat = (New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index 1) })
        $shapeOwner = New-TestOwner -Context (Get-CustomCurrentContext -SectionName $ABYSS_SECTION)
        $shapeOther = New-TestEntry -Section '' -Owner ([pscustomobject]@{ runId = 'run-other' }) -RunId 'run-other'
        if ($shape -eq '항목만') {
            $shapeEntry = New-TestEntry -Section $ABYSS_SECTION -Owner $shapeOwner -Generation 1
            Write-TestJournal -Path $script:abyssJournalPath -Entries @($shapeEntry, $shapeOther) -Applied @($shapeEntry.nonce, $shapeOther.nonce)
        } else {
            Write-TestJournal -Path $script:abyssJournalPath -Entries @($shapeOther) -Applied @($shapeOther.nonce) `
                -Pending @(New-TestPending -Owner $shapeOwner -Generation 1 -Nonce ([guid]::NewGuid().ToString('D')))
        }
        $shapeOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION)
        Assert-Case ('O02 폐기 모양({0}): 성공 반환 · 저장 changed · 비커스텀 항목과 그 applied 만 남음' -f $shape) `
            ('{0} · {1} · {2}' -f (Get-ResultText $shapeOutput), ($script:journalUpdateTags -join ','), (Get-JournalSummary)) `
            ('1:True · changed · entries={0} pending=0 applied={0}' -f $shapeOther.nonce)
    }
}

# ===== O03 ②①③ 3경로 - 순서 · ② 실패 · ① 실패 =====
function Test-CaseO03 {
    $pathCases = @(
        @{ Path = 'reset'; Random = $false; NoProgress = $false; Order = 'save,journal,marker'; Output = '1:True'; MarkerLeft = $false; Notice = '' },
        @{ Path = 'random'; Random = $false; NoProgress = $false; Order = 'save,journal,marker'; Output = '0:'; MarkerLeft = $false
            Notice = '[안내] 랜덤 진행 켬 - 매 바퀴 시작 때 리스트 순서를 무작위로 섞습니다 (진행 기록은 처음부터).' },
        @{ Path = 'shuffle'; Random = $true; NoProgress = $true; Order = 'save,journal'; Output = '1:True'; MarkerLeft = $true; Notice = '' })
    foreach ($pathCase in $pathCases) {
        $pathName = [string]$pathCase.Path
        # (가) 정상: 순서 ②→①→③ · 세대 2 → 3 · 어비스 항목·pending 제거 · applied 는 남은 항목 것만
        $fixture = Initialize-AbyssFixture -Name ('O03-' + $pathName) -Random:([bool]$pathCase.Random) -NoProgress:([bool]$pathCase.NoProgress)
        $markerBefore = Get-FileDigest $script:customAbyssMarkerFile
        $output = @(Invoke-ResetPath -Path $pathName)
        $configAfter = Read-TestConfig
        Assert-Case ('O03 {0} 정상: 출력 · 순서(② 저장 → ① 완료 기록 → ③ 마커) · 세대 · 정리 경고 0' -f $pathName) `
            ('{0} · {1} · {2} · {3}' -f (Get-ResultText $output), (Get-EventOrder), $configAfter.abyssCustomRepeat.progressGeneration,
                (Get-LogCount $CLEANUP_WARNING_PATTERN)) ('{0} · {1} · 3 · 0' -f $pathCase.Output, $pathCase.Order)
        Assert-Case ('O03 {0} 정상: journal 은 비커스텀 항목과 그 applied 만 남음' -f $pathName) (Get-JournalSummary) `
            ('entries={0} pending=0 applied={0}' -f $fixture.OtherNonce)
        $markerText = $(if ($pathCase.MarkerLeft) { '그대로' } else { '없음' })
        Assert-Case ('O03 {0} 정상: 마커 {1}' -f $pathName, $markerText) `
            $(if ([System.IO.File]::Exists($script:customAbyssMarkerFile)) { $(if ((Get-FileDigest $script:customAbyssMarkerFile) -eq $markerBefore) { '그대로' } else { '바뀜' }) } else { '없음' }) $markerText
        if ($pathCase.Notice) {
            Assert-Case ('O03 {0} 정상: 토글 안내 1줄' -f $pathName) (Get-ExactLogCount $pathCase.Notice) 1
        }
        if ($pathName -eq 'shuffle') {
            Assert-Case 'O03 shuffle 정상: 새 순열이 저장됨(유효한 순열)' `
                (Test-CustomShuffleOrder -Order $configAfter.abyssCustomRepeat.progress.shuffleOrder -ItemCount $ABYSS_ITEMS.Count) $true
        }

        # (나) ② 실패(config 저장 실패): 아무것도 바뀌지 않음 - config·마커·journal 해시 그대로 · journal 접근 0 · 폐기 호출 0
        [void](Initialize-AbyssFixture -Name ('O03-' + $pathName + '-save-fail') -Random:([bool]$pathCase.Random) -NoProgress:([bool]$pathCase.NoProgress))
        $stateBefore = Get-CaseState
        $configLock = Lock-TestConfig
        try { $failOutput = @(Invoke-ResetPath -Path $pathName) }
        finally { $configLock.Dispose() }
        $expectedFailOutput = $(if ($pathName -eq 'random') { '0:' } else { '1:False' })
        $expectedFailLog = $(if ($pathName -eq 'reset') { '^\[오류\] 커스텀 진행 초기화 저장 실패' }
            elseif ($pathName -eq 'random') { '^\[경고\] 랜덤 진행 설정 저장 실패' } else { '^\[오류\] 랜덤 진행 순서 저장 실패' })
        Assert-Case ('O03 {0} ② 실패: 출력 · 실패 안내 1 · 바뀐 것 없음 · journal 접근 0 · 폐기 호출 0 · 마커 정리 0' -f $pathName) `
            ('{0} · {1} · {2} · {3} · {4} · {5}' -f (Get-ResultText $failOutput), (Get-LogCount $expectedFailLog), ((Get-CaseState) -eq $stateBefore),
                $script:journalAccessCount, @($script:eventLog | Where-Object { $_ -eq 'cleanup' }).Count, @($script:eventLog | Where-Object { $_ -eq 'marker' }).Count) `
            ('{0} · 1 · True · 0 · 0 · 0' -f $expectedFailOutput)
        if ($pathName -eq 'random') {
            Assert-Case 'O03 random ② 실패: 토글 안내 없음(경고만 - 명세 5절 C14)' (Get-LogCount '^\[안내\] 랜덤 진행') 0
        }

        # (다) ① 실패(완료 기록 잠김): [경고] 한 줄 + 성공 그대로 - 세대는 이미 올랐고 ③ 은 계속
        [void](Initialize-AbyssFixture -Name ('O03-' + $pathName + '-journal-locked') -Random:([bool]$pathCase.Random) -NoProgress:([bool]$pathCase.NoProgress))
        $journalBefore = Get-JournalState
        $lockStream = Lock-TestJournal
        try { $lockedOutput = @(Invoke-ResetPath -Path $pathName) }
        finally { $lockStream.Dispose() }
        Assert-Case ('O03 {0} ① 잠김: 출력 그대로 · 경고 정확히 1줄 · 세대 3 · journal 그대로 · 순서' -f $pathName) `
            ('{0} · {1}/{2} · {3} · {4} · {5}' -f (Get-ResultText $lockedOutput), (Get-ExactLogCount $CLEANUP_WARNING_LOCKED), (Get-LogCount $CLEANUP_WARNING_PATTERN),
                (Read-TestConfig).abyssCustomRepeat.progressGeneration, ((Get-JournalState) -eq $journalBefore), (Get-EventOrder)) `
            ('{0} · 1/1 · 3 · True · {1}' -f $pathCase.Output, $pathCase.Order)
        Assert-Case ('O03 {0} ① 잠김: 마커 {1}' -f $pathName, $markerText) `
            $(if ([System.IO.File]::Exists($script:customAbyssMarkerFile)) { '그대로' } else { '없음' }) $markerText
    }

    # ① 실패 종류별 문구(진행 초기화로 확인): 손상 · 기록 실패(폴더 없음) · 예외 - 셋 다 성공 반환 · 경고 1줄 · journal 파일 그대로
    [void](Initialize-AbyssFixture -Name 'O03-reset-corrupt')
    [System.IO.File]::WriteAllText($script:abyssJournalPath, '{ 깨진 본 파일')
    [System.IO.File]::WriteAllText(($script:abyssJournalPath + '.bak'), '{ 깨진 직전본')
    $corruptBefore = Get-JournalState
    $corruptOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION)
    Assert-Case 'O03 ① 손상: 성공 반환 · 손상 경고 1줄 · journal 파일 그대로(고치지 않음 - 명세 5절 B6) · 마커 정리' `
        ('{0} · {1}/{2} · {3} · {4}' -f (Get-ResultText $corruptOutput), (Get-ExactLogCount $CLEANUP_WARNING_CORRUPT), (Get-LogCount $CLEANUP_WARNING_PATTERN),
            ((Get-JournalState) -eq $corruptBefore), [System.IO.File]::Exists($script:customAbyssMarkerFile)) '1:True · 1/1 · True · False'
    [void](Initialize-AbyssFixture -Name 'O03-reset-io-failed')
    $missingFolder = Join-Path $script:caseFolder 'missing'
    $script:abyssJournalPath = Join-Path $missingFolder 'abyss_handoff.json'
    $ioOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION)
    Assert-Case 'O03 ① 기록 실패(폴더 없음): 성공 반환 · 기록 실패 경고 1줄 · 폴더를 만들지 않음' `
        ('{0} · {1}/{2} · {3}' -f (Get-ResultText $ioOutput), (Get-ExactLogCount $CLEANUP_WARNING_IO), (Get-LogCount $CLEANUP_WARNING_PATTERN),
            [System.IO.Directory]::Exists($missingFolder)) '1:True · 1/1 · False'
    [void](Initialize-AbyssFixture -Name 'O03-reset-exception')
    $exceptionBefore = Get-JournalState
    $script:journalUpdateMode = 'throw'
    $exceptionOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION)
    $script:journalUpdateMode = ''
    Assert-Case 'O03 ① 예외: 밖으로 내지 않음 - 성공 반환 · 예외 경고 1줄(메시지 포함) · journal 그대로 · 마커 정리' `
        ('{0} · {1}/{2} · {3} · {4}' -f (Get-ResultText $exceptionOutput),
            (Get-ExactLogCount ('[경고] 완료 기록 정리 실패(예외: {0}) - 옛 세대 기록은 무시됩니다' -f $INJECTED_JOURNAL_EXCEPTION)),
            (Get-LogCount $CLEANUP_WARNING_PATTERN), ((Get-JournalState) -eq $exceptionBefore), [System.IO.File]::Exists($script:customAbyssMarkerFile)) '1:True · 1/1 · True · False'
    # 저장소의 복구 경고(변이 검증 보강 2026-10-09): 본 파일 손상 + 직전본 유효면 저장소가 잠금 아래 직전본으로 복구한 뒤 폐기까지 마치고
    #   (성공) 복구 사실은 Warnings 로 돌려줍니다 - 로그는 호출부 몫(저장소 계약). 위 손상 행은 직전본도 손상이라 corrupt 로 끝나 이 경로를
    #   타지 않았습니다
    $recoverFixture = Initialize-AbyssFixture -Name 'O03-reset-recover-bak'
    [System.IO.File]::Copy($script:abyssJournalPath, ($script:abyssJournalPath + '.bak'), $true)
    [System.IO.File]::WriteAllText($script:abyssJournalPath, '{ 깨진 본 파일')
    $recoverOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION)
    Assert-Case 'O03 ① 본 파일 손상 + 직전본 유효: 성공 반환 · 복구 경고 1줄 · 정리 실패 경고 0 · 저장 changed · 어비스 항목·pending 제거' `
        ('{0} · {1} · {2} · {3} · {4}' -f (Get-ResultText $recoverOutput), (Get-ExactLogCount $STORE_RECOVER_WARNING), (Get-LogCount $CLEANUP_WARNING_PATTERN),
            ($script:journalUpdateTags -join ','), (Get-JournalSummary)) ('1:True · 1 · 0 · changed · entries={0} pending=0 applied={0}' -f $recoverFixture.OtherNonce)

    # 세대를 올리지 않는 Confirm 갈래(명세 5절 C8): 이미 유효한 순열 · 층 혼합 리스트의 랜덤 해제 - 세대 그대로 · journal 접근 0
    [void](Initialize-AbyssFixture -Name 'O03-shuffle-valid' -Random)
    $validConfig = Read-TestConfig
    $validConfig.abyssCustomRepeat.progress = New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index 1 -ShuffleOrder @(2, 0, 1)
    Write-TestConfig $validConfig
    $stateBeforeValid = Get-CaseState
    $validOutput = @(Confirm-CustomShuffleReady -SectionName $ABYSS_SECTION)
    Assert-Case 'O03 shuffle 유효 순열: True · 세대 그대로 · 저장 0 · journal 접근 0 · 아무것도 안 바뀜' `
        ('{0} · {1} · {2} · {3} · {4}' -f (Get-ResultText $validOutput), (Read-TestConfig).abyssCustomRepeat.progressGeneration,
            @($script:eventLog | Where-Object { $_ -eq 'save' }).Count, $script:journalAccessCount, ((Get-CaseState) -eq $stateBeforeValid)) '1:True · 2 · 0 · 0 · True'
    Use-CaseFolder -Name 'O03-shuffle-mixed'
    $mixedItems = @(
        [pscustomobject]@{ difficulty = '어려움'; stage = '1-3'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false },
        [pscustomobject]@{ difficulty = '어려움'; stage = '2-1'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false })
    Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 4 } -Random @('customRepeat') -Items @{ customRepeat = $mixedItems })
    $mixedOutput = @(Confirm-CustomShuffleReady -SectionName 'customRepeat')
    $mixedConfig = Read-TestConfig
    Assert-Case 'O03 shuffle 층 혼합 랜덤 해제: True · 랜덤 꺼짐 · 세대 그대로 4 · journal 접근 0' `
        ('{0} · {1} · {2} · {3}' -f (Get-ResultText $mixedOutput), $mixedConfig.customRepeat.randomOrder, $mixedConfig.customRepeat.progressGeneration,
            $script:journalAccessCount) '1:True · False · 4 · 0'
}

# ===== O04 설정 이전 · 바퀴 전환 =====
function Test-CaseO04 {
    # 이전: 진행을 지운 섹션만 +1 (스키마 10 사용자 - 던전·심층·생활에 진행, 어비스는 없음)
    $userConfig = Initialize-MigrationCase -Name 'O04-migrate' -UserSchema 10
    $userConfig.customRepeat.progress = [pscustomobject]@{ lap = 2; index = 1; fingerprint = 'x' }
    $userConfig.deepCustomRepeat.progress = [pscustomobject]@{ lap = 1; index = 0; fingerprint = 'y' }
    $userConfig.lifeCustomRepeat.progress = [pscustomobject]@{ lap = 1; index = 1; fingerprint = 'z' }
    Write-TestConfig $userConfig
    $migrated = Update-ConfigToLatest
    Assert-Case 'O04 이전(스키마 10 → 11): 진행을 지운 전투 섹션만 +1 · 진행 없던 어비스 0 · 생활 키 없음' `
        ('{0} · {1}' -f $migrated, (Get-GenerationText -Config (Read-TestConfig))) `
        'True · customRepeat=1 abyssCustomRepeat=0 deepCustomRepeat=1 lifeCustomRepeat=없음'
    # 같은 이전에 구버전 마커는 없음 → 구버전 무효화 0건 · 안내 0줄 · 진행 초기화 안내만 1줄 (변이 검증 보강 2026-10-09 - 진행 초기화
    #   경로의 정리 성공(마커가 없어 '할 일 없음' 성공)까지 구버전 건수로 세면 없는 무효화를 안내합니다)
    Invoke-MigrationNotice
    Assert-Case 'O04 이전(진행 초기화만 · 구버전 마커 없음): 구버전 무효화 0건 · [안내] 구버전 0줄 · 진행 초기화 안내 1줄' `
        ('{0} · {1} · {2}' -f $script:legacyMarkerClearedCount, (Get-LogCount '^\[안내\] 구버전 커스텀 완료 기록'),
            (Get-LogCount '^\[안내\] 업데이트로 커스텀 반복 진행 기록을 초기화했습니다')) '0 · 0 · 1'

    # 바퀴 전환(Step): 새 순열로 orderKey 만 바뀌고 세대는 그대로 · journal 접근 0 (설계 v10 6.3 '초기화 아님')
    Use-CaseFolder -Name 'O04-step-lap'
    Write-TestConfig (New-TestConfig -Generations @{ abyssCustomRepeat = 4 } -Random @($ABYSS_SECTION) `
            -Progress @{ abyssCustomRepeat = (New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index 2 -ShuffleOrder @(2, 0, 1)) })
    $beforeStep = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    # 새 순열을 정해진 값으로(실제 Get-Random 이면 우연히 같은 순열이 나올 수 있음) - 이 케이스 함수 안에서만 가립니다
    function New-CustomShuffleOrder { param([int]$ItemCount) return @(1, 2, 0) }
    $stepProgress = Step-CustomProgress -SectionName $ABYSS_SECTION
    $afterStep = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    Assert-Case 'O04 Step 바퀴 전환: 1바퀴 2번 → 2바퀴 0번 · orderKey 2,0,1 → 1,2,0 · 세대 4 그대로 · journal 접근 0' `
        ('{0}-{1} → {2}-{3} · {4} → {5} · {6}/{7} · {8}' -f $beforeStep.Lap, $beforeStep.Index, $afterStep.Lap, $afterStep.Index,
            (Get-CustomOrderKey -Order $beforeStep.Order), (Get-CustomOrderKey -Order $afterStep.Order), $beforeStep.Generation, $afterStep.Generation,
            $script:journalAccessCount) '1-2 → 2-0 · 2,0,1 → 1,2,0 · 4/4 · 0'
    Assert-Case 'O04 Step 바퀴 전환: 반환 진행이 디스크와 같음' ('{0}-{1}' -f $stepProgress.lap, $stepProgress.index) '2-0'
    # 같은 바퀴 전진(순차)도 세대 그대로
    Use-CaseFolder -Name 'O04-step-same-lap'
    Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 9 } -Progress @{ customRepeat = (New-TestProgress -Section 'customRepeat' -Lap 1 -Index 0) })
    [void](Step-CustomProgress -SectionName 'customRepeat')
    $sameLap = Get-CustomCurrentContext -SectionName 'customRepeat'
    Assert-Case 'O04 Step 같은 바퀴(순차): 1바퀴 1번 · 세대 9 그대로' ('{0}-{1} · {2}' -f $sameLap.Lap, $sameLap.Index, $sameLap.Generation) '1-1 · 9'
}

# ===== O05 마커 owner 와 journal owner - 5필드 집합 동일, generation 은 형제 필드 =====
function Test-CaseO05 {
    $context = @{ Items = $ABYSS_ITEMS; Order = @(2, 0, 1); Lap = 3; Index = 1; Item = $ABYSS_ITEMS[0]; Generation = 6 }
    $markerOwner = (New-CustomMarkerOwnerJson -Context $context) | ConvertFrom-Json
    $markerFieldNames = @($markerOwner.PSObject.Properties | ForEach-Object { $_.Name } | Where-Object { $_ -ne 'version' -and $_ -ne 'generation' })
    Assert-Case 'O05 마커 owner(version 3)의 version·generation 을 뺀 필드' ($markerFieldNames -join ',') 'fingerprint,orderKey,lap,index,item'
    $journalOwner = New-TestOwner -Context $context
    $entry = New-TestEntry -Section $ABYSS_SECTION -Owner $journalOwner -Generation 6
    Assert-Case 'O05 journal 대조: 같은 owner·같은 세대 일치 · 세대만 다르면 불일치' `
        ('{0}/{1}' -f (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $journalOwner -Generation 6),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $journalOwner -Generation 7)) 'True/False'
    # 세대 역행(변이 검증 보강 2026-10-09): 저장된 세대가 지금보다 높아도 불일치 - 계약은 '같음'(옛 config 사본으로 되돌린 뒤 높은 세대의
    #   옛 기록·마커가 지금 판으로 인정되면 안 됨). 다른 불일치 행은 전부 '저장된 세대 < 지금' 이라 비교를 '-ge' 로 바꿔도 같은 답이었습니다
    Assert-Case 'O05 세대 역행(저장 6 · 지금 5): journal 대조 불일치 · 마커 대조 불일치' `
        ('{0}/{1}' -f (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $journalOwner -Generation 5),
            (Test-CustomMarkerOwnerMatchesContext -Owner $markerOwner -Context @{ Items = $ABYSS_ITEMS; Order = @(2, 0, 1); Lap = 3; Index = 1; Item = $ABYSS_ITEMS[0]; Generation = 5 })) 'False/False'
    # 마커의 5필드를 하나씩 바꾸면 journal 대조가 불일치 = journal 은 그 다섯을 전부 비교합니다(⊇)
    $journalResults = @()
    $markerResults = @()
    foreach ($fieldName in $markerFieldNames) {
        $changedOwner = New-TestOwner -Context $context
        if ($fieldName -eq 'lap' -or $fieldName -eq 'index') { $changedOwner.$fieldName = [int]$changedOwner.$fieldName + 1 }
        else { $changedOwner.$fieldName = [string]$changedOwner.$fieldName + '*' }
        $journalResults += ('{0}={1}' -f $fieldName, (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $changedOwner -Generation 6))
        $changedMarker = (New-CustomMarkerOwnerJson -Context $context) | ConvertFrom-Json
        $changedMarker.$fieldName = $changedOwner.$fieldName
        $markerResults += ('{0}={1}' -f $fieldName, (Test-CustomMarkerOwnerMatchesContext -Owner $changedMarker -Context $context))
    }
    Assert-Case 'O05 필드 하나만 바꾸면 journal 대조 불일치(5필드 전부 비교)' ($journalResults -join ' ') `
        'fingerprint=False orderKey=False lap=False index=False item=False'
    Assert-Case 'O05 필드 하나만 바꾸면 마커 대조도 불일치(같은 5필드)' ($markerResults -join ' ') `
        'fingerprint=False orderKey=False lap=False index=False item=False'
    # 5필드만 가진 owner 끼리 일치 = journal 은 그 밖의 필드를 요구하지 않습니다(⊆) → 두 집합이 같음
    $fiveFieldOwner = [pscustomobject]@{}
    foreach ($fieldName in $markerFieldNames) { $fiveFieldOwner | Add-Member -NotePropertyName $fieldName -NotePropertyValue $markerOwner.$fieldName }
    $fiveFieldEntry = New-TestEntry -Section $ABYSS_SECTION -Owner $fiveFieldOwner -Generation 6
    Assert-Case 'O05 5필드만 가진 owner 로 일치(다른 필드 요구 없음)' (Test-AbyssJournalOwnerMatch -Entry $fiveFieldEntry -Owner $fiveFieldOwner -Generation 6) $true
    # 세대는 owner 안이 아니라 항목의 형제 필드: owner 안에 같은 세대를 넣어도 항목 세대가 다르면 불일치, 항목에 세대가 없으면 불일치
    $ownerWithGeneration = New-TestOwner -Context $context
    $ownerWithGeneration | Add-Member -NotePropertyName 'generation' -NotePropertyValue 6
    $siblingMismatch = New-TestEntry -Section $ABYSS_SECTION -Owner $ownerWithGeneration -Generation 5
    $noSibling = New-TestEntry -Section $ABYSS_SECTION -Owner $ownerWithGeneration -Generation 6
    $noSibling.PSObject.Properties.Remove('generation')
    Assert-Case 'O05 세대는 항목의 형제 필드 - owner 안 세대는 보지 않음 / 항목에 세대 없음 = 불일치' `
        ('{0}/{1}' -f (Test-AbyssJournalOwnerMatch -Entry $siblingMismatch -Owner $journalOwner -Generation 6),
            (Test-AbyssJournalOwnerMatch -Entry $noSibling -Owner $journalOwner -Generation 6)) 'False/False'
    Assert-Case 'O05 마커 대조: 세대만 다르면 불일치' `
        (Test-CustomMarkerOwnerMatchesContext -Owner $markerOwner -Context @{ Items = $ABYSS_ITEMS; Order = @(2, 0, 1); Lap = 3; Index = 1; Item = $ABYSS_ITEMS[0]; Generation = 7 }) $false
}

# ===== O06 journal 파일 없음 · 어비스 항목 없음 → 폐기 성공 = unchanged · 파일 생성 0 =====
function Test-CaseO06 {
    Use-CaseFolder -Name 'O06-no-file'
    Write-TestConfig (New-TestConfig -Generations @{ abyssCustomRepeat = 1 } -Progress @{ abyssCustomRepeat = (New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index 1) })
    $noFileOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION)
    $journalFileCount = @(@([System.IO.Directory]::GetFiles($script:caseFolder)) | Where-Object { [System.IO.Path]::GetFileName($_) -like '*abyss_handoff*' }).Count
    Assert-Case 'O06 파일 없음: 성공 반환 · 저장 태그 unchanged · 완료 기록 파일 생성 0 · 경고 0' `
        ('{0} · {1} · 파일 {2} · 경고 {3}' -f (Get-ResultText $noFileOutput), ($script:journalUpdateTags -join ','), $journalFileCount,
            (Get-LogCount '^\[경고\]')) '1:True · unchanged · 파일 0 · 경고 0'
    $directNoFile = @(Remove-AbyssJournalSectionEntries -SectionName $ABYSS_SECTION)
    Assert-Case 'O06 파일 없음: 폐기 함수 직접 호출 - 출력 0 · 파일 생성 0' ('{0} · {1}' -f (Get-ResultText $directNoFile), (Get-FolderListing $script:caseFolder)) '0: · config.json'

    Use-CaseFolder -Name 'O06-no-entries'
    Write-TestConfig (New-TestConfig -Generations @{ abyssCustomRepeat = 1 } -Progress @{ abyssCustomRepeat = (New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index 1) })
    $otherEntry = New-TestEntry -Section '' -Owner ([pscustomobject]@{ runId = 'run-other' }) -RunId 'run-other'
    Write-TestJournal -Path $script:abyssJournalPath -Entries @($otherEntry) -Applied @($otherEntry.nonce) -Seq 4
    Write-TestJournal -Path ($script:abyssJournalPath + '.bak') -Entries @() -Seq 3
    $journalBefore = Get-JournalState
    $noEntryOutput = @(Reset-CustomProgress -SectionName $ABYSS_SECTION)
    Assert-Case 'O06 어비스 항목 없음: 성공 반환 · unchanged · 본 파일·직전본 바이트 그대로 · 파일 목록 그대로 · 경고 0' `
        ('{0} · {1} · {2} · {3}' -f (Get-ResultText $noEntryOutput), ($script:journalUpdateTags -join ','), ((Get-JournalState) -eq $journalBefore),
            (Get-LogCount '^\[경고\]')) '1:True · unchanged · True · 0'
}

# ===== O07 마커 v3 - ② 저장 직후 종료 / ① 직후 종료 → 재시작 · version 2 =====
function Test-CaseO07 {
    # 픽스처는 1바퀴 0번(-Index 0) - 진행 초기화 뒤에도 위치가 그대로라 마커의 5필드가 지금 위치와 다시 맞고, 세대만이 옛 마커를 가릅니다
    # (index 가 바뀌는 위치에서 보면 세대 비교가 빠져도 index 차이로 폐기돼 이 케이스가 아무것도 지키지 못합니다 - 변이 검증 2026-10-08)
    # 대조군: 진행 초기화 없이 재시작하면 지금 위치의 v3 마커는 마무리 복구로 이어집니다(게이트 블록이 실제로 대조 경로를 탑니다)
    [void](Initialize-AbyssFixture -Name 'O07-control' -Index 0)
    $control = Invoke-StartGateMarkerCheck -Section $ABYSS_SECTION
    Assert-Case 'O07 대조군(초기화 없음): 복구 예약 · 마커 그대로 · 정리 0' `
        ('{0} · 복구 안내 {1}' -f (Format-GateResult $control), $control.RecoveryLog) '복구 예약 True · 마커 남음 True · 정리 0 · 폐기 안내 0 · 복구 안내 1'

    # ② 저장 직후(①③ 전) 종료 → 재시작: 마커는 남았지만 세대가 달라 복구 예약 0 · 폐기 1
    $saveFixture = Initialize-AbyssFixture -Name 'O07-crash-after-save' -Index 0
    $journalBefore = Get-JournalState
    $crashedAfterSave = Invoke-WithCrash -CrashPoint 'cleanup' -Call { Reset-CustomProgress -SectionName $ABYSS_SECTION }
    Assert-Case 'O07 ② 직후 종료: 끊김 · 디스크 = 진행 null + 세대 3 · 마커 남음 · journal 그대로' `
        ('{0} · {1}/{2} · {3} · {4}' -f $crashedAfterSave, ($null -eq (Read-TestConfig).abyssCustomRepeat.progress), (Read-TestConfig).abyssCustomRepeat.progressGeneration,
            [System.IO.File]::Exists($script:customAbyssMarkerFile), ((Get-JournalState) -eq $journalBefore)) 'True · True/3 · True · True'
    $restartContext = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    Assert-Case 'O07 ② 직후 종료 전제: 재시작 위치의 5필드 = 남은 마커의 5필드(다른 것은 세대 2 → 3 뿐)' `
        ('{0}/{1}' -f (((New-TestOwner -Context $restartContext) | ConvertTo-Json -Compress) -eq ((New-TestOwner -Context $saveFixture.Context) | ConvertTo-Json -Compress)),
            ('{0}→{1}' -f $saveFixture.Context.Generation, $restartContext.Generation)) 'True/2→3'
    $afterSaveGate = Invoke-StartGateMarkerCheck -Section $ABYSS_SECTION
    Assert-Case 'O07 ② 직후 종료 → 재시작: 복구 예약 0 · 폐기 1' (Format-GateResult $afterSaveGate) '복구 예약 False · 마커 남음 False · 정리 1 · 폐기 안내 1'

    # ① 직후(③ 전) 종료 → 재시작: journal 은 정리됐고 마커만 남음 → 같은 결과
    $fixture = Initialize-AbyssFixture -Name 'O07-crash-after-journal' -Index 0
    $crashedAfterJournal = Invoke-WithCrash -CrashPoint 'marker' -Call { Reset-CustomProgress -SectionName $ABYSS_SECTION }
    Assert-Case 'O07 ① 직후 종료: 끊김 · journal 정리됨 · 마커 남음' `
        ('{0} · {1} · {2}' -f $crashedAfterJournal, (Get-JournalSummary), [System.IO.File]::Exists($script:customAbyssMarkerFile)) `
        ('True · entries={0} pending=0 applied={0} · True' -f $fixture.OtherNonce)
    $afterJournalGate = Invoke-StartGateMarkerCheck -Section $ABYSS_SECTION
    Assert-Case 'O07 ① 직후 종료 → 재시작: 복구 예약 0 · 폐기 1' (Format-GateResult $afterJournalGate) '복구 예약 False · 마커 남음 False · 정리 1 · 폐기 안내 1'

    # version 2 마커는 5필드가 지금 위치와 같아도 판독 $null → 시작 게이트 폐기. 세대 0(진행이 없던 1바퀴 0번 사용자 - 10→11 이전의 주 대상)
    # 에서 봅니다 - 세대가 0 이 아니면 세대 불일치만으로도 폐기돼 version 판정을 가리지 못합니다. 5필드 = 스키마 10 까지의 GUI 가 쓰던 모양,
    # 6필드 = 같은 마커에 generation 0 까지 있는 것(읽기 문턱이 version 3 만 인정하는지 - 'version 2 허용' 을 잡음)
    foreach ($legacyShape in @('5필드', '6필드')) {
        Use-CaseFolder -Name ('O07-version2-' + $legacyShape)
        Write-TestConfig (New-TestConfig -Generations @{ abyssCustomRepeat = 0 } `
                -Progress @{ abyssCustomRepeat = (New-TestProgress -Section $ABYSS_SECTION -Lap 1 -Index 0) })
        $legacyContext = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
        $legacyJson = ConvertTo-LegacyV2MarkerJson -Context $legacyContext
        if ($legacyShape -eq '6필드') {
            $legacyObject = $legacyJson | ConvertFrom-Json
            $legacyObject | Add-Member -NotePropertyName 'generation' -NotePropertyValue 0
            $legacyJson = $legacyObject | ConvertTo-Json -Compress
        }
        [System.IO.File]::WriteAllText($script:customAbyssMarkerFile, $legacyJson)
        $legacyObjectRead = $legacyJson | ConvertFrom-Json
        $currentOwner = New-TestOwner -Context $legacyContext
        $sameFiveFields = @(@('fingerprint', 'orderKey', 'lap', 'index', 'item') | Where-Object { [string]$legacyObjectRead.$_ -ne [string]$currentOwner.$_ }).Count -eq 0
        Assert-Case ('O07 version 2 마커({0}): 5필드는 지금 위치와 같음 · 세대 0 · 판독은 $null' -f $legacyShape) `
            ('{0}/{1}/{2}' -f $sameFiveFields, $legacyContext.Generation, ($null -eq (Read-CustomMarkerOwner -Path $script:customAbyssMarkerFile))) 'True/0/True'
        $legacyGate = Invoke-StartGateMarkerCheck -Section $ABYSS_SECTION
        Assert-Case ('O07 version 2 마커({0}) → 재시작: 복구 예약 0 · 폐기 1' -f $legacyShape) (Format-GateResult $legacyGate) `
            '복구 예약 False · 마커 남음 False · 정리 1 · 폐기 안내 1'
    }
}

# ===== O08 10→11 구버전 마커 - 저장 실패 · 정상 · 삭제 실패 · 진행 있음 + 같은 경로 =====
function Test-CaseO08 {
    # (가) Save-Config 예외 주입: 이전 실패 · 원인 보존 · config·마커 해시 그대로 · 묘비 0 (마커 정리는 저장 성공 뒤)
    $userConfig = Initialize-MigrationCase -Name 'O08-save-throw' -UserSchema 10
    Write-TestConfig $userConfig
    Write-LegacyMarkers
    $configBefore = Get-FileDigest $script:configPath
    $markersBefore = Get-MarkerDigests
    $script:saveConfigMode = 'throw'
    $throwResult = Update-ConfigToLatest
    $script:saveConfigMode = ''
    Assert-Case 'O08 저장 예외: 이전 false · 원인 보존 · config 그대로 · 마커 4개 그대로 · 묘비 0 · 마커 정리 호출 0' `
        ('{0} · {1} · {2} · {3} · {4} · {5}' -f $throwResult, (-not [string]::IsNullOrWhiteSpace($script:configMigrationError)),
            ((Get-FileDigest $script:configPath) -eq $configBefore), ((Get-MarkerDigests) -eq $markersBefore), (Get-StaleCount),
            @($script:eventLog | Where-Object { $_ -eq 'marker' }).Count) 'False · True · True · True · 0 · 0'

    # (나) 정상(진행 없음 = 1바퀴 0번 사용자): 블록 통과 시점(= 저장 직전)에 마커 그대로 → 저장 뒤 3섹션 무효화 · 생활 그대로 · [안내] 3건
    $userConfig = Initialize-MigrationCase -Name 'O08-normal' -UserSchema 10
    Write-TestConfig $userConfig
    Write-LegacyMarkers
    $markersBefore = Get-MarkerDigests
    $script:onSaveObserver = { $script:markersAtSave = Get-MarkerDigests }
    $normalResult = Update-ConfigToLatest
    $script:onSaveObserver = $null
    Assert-Case 'O08 정상: 이전 · 블록 통과 시점 마커 해시 그대로 · 모은 경로 3(생활 제외)' `
        ('{0} · {1} · {2}' -f $normalResult, ($script:markersAtSave -eq $markersBefore),
            ((@($script:legacyMarkerPathsToClear) | ForEach-Object { [System.IO.Path]::GetFileName($_) }) -join ',')) `
        'True · True · custom_done.marker,abyss_custom_done.marker,deep_custom_done.marker'
    Assert-Case 'O08 정상: 저장 뒤 3섹션 마커 없음 · 생활 마커 그대로 · 무효화 3건 · 실패 없음' `
        ('{0}/{1}/{2}/{3} · {4}/{5}' -f [System.IO.File]::Exists($script:customDungeonMarkerFile), [System.IO.File]::Exists($script:customAbyssMarkerFile),
            [System.IO.File]::Exists($script:customDeepMarkerFile), [System.IO.File]::Exists($script:customLifeMarkerFile),
            $script:legacyMarkerClearedCount, $script:legacyMarkerClearFailed) 'False/False/False/True · 3/False'
    Invoke-MigrationNotice
    Assert-Case 'O08 정상 안내: [안내] … 3건 1줄 · 구버전 경고 0' ('{0}/{1}' -f (Get-ExactLogCount $LEGACY_NOTICE_THREE), (Get-LogCount $LEGACY_WARNING_PATTERN)) '1/0'

    # (다) 삭제 실패 주입(어비스 마커를 실제로 잠금 - 진행 없는 픽스처): 구버전 실패 플래그 · [경고] 1줄 · 나머지 2건 무효화
    $userConfig = Initialize-MigrationCase -Name 'O08-delete-fail' -UserSchema 10
    Write-TestConfig $userConfig
    Write-LegacyMarkers
    $markerLock = [System.IO.File]::Open($script:customAbyssMarkerFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try { $deleteFailResult = Update-ConfigToLatest }
    finally { $markerLock.Dispose() }
    Assert-Case 'O08 삭제 실패: 이전 성공 · 구버전 실패 플래그 · 무효화 2건 · 진행 초기화 실패 아님' `
        ('{0} · {1} · {2} · {3}' -f $deleteFailResult, $script:legacyMarkerClearFailed, $script:legacyMarkerClearedCount, $script:customMarkerClearFailed) 'True · True · 2 · False'
    Invoke-MigrationNotice
    Assert-Case 'O08 삭제 실패 안내: 구버전 경고 1줄 · [안내] 2건 1줄' `
        ('{0}/{1}' -f (Get-LogCount $LEGACY_WARNING_PATTERN), (Get-LogCount '^\[안내\] 구버전 커스텀 완료 기록 2건을 무효화했습니다')) '1/1'

    # (라) 진행 있는 던전의 version 2 마커 = 두 목록(진행 초기화 · 구버전)에 다 듦(명세 리뷰 2 P3) → 그 경로 정리는 1회.
    #      정리 결과 하나를 두 용도에 나눠 쓰므로: 두 번째 시도에서만 나는 일시 실패(fail-after-first)는 생기지 않아 플래그 거짓,
    #      첫 시도 실패(fail-first)·계속 실패(fail-always)는 실패 플래그 = 파일이 실제로 남았는가, 경고는 1줄(같은 파일 경고 두 줄 금지).
    #      무효화 건수 안내는 건수가 1 이어도 1줄(변이 검증 보강 2026-10-09 - 문턱이 '2건 이상' 으로 밀리면 한 모드만 쓰던 사용자는 못 봄)
    $unionCases = @(
        @{ Mode = ''; Expect = '던전 1회 · 어비스 1회 · 플래그 False/False · 무효화 2 · 던전 마커 남음 False · 마커 경고 0' },
        @{ Mode = 'fail-after-first'; Expect = '던전 1회 · 어비스 1회 · 플래그 False/False · 무효화 2 · 던전 마커 남음 False · 마커 경고 0' },
        @{ Mode = 'fail-first'; Expect = '던전 1회 · 어비스 1회 · 플래그 True/False · 무효화 1 · 던전 마커 남음 True · 마커 경고 1' },
        @{ Mode = 'fail-always'; Expect = '던전 1회 · 어비스 1회 · 플래그 True/False · 무효화 1 · 던전 마커 남음 True · 마커 경고 1' })
    foreach ($unionCase in $unionCases) {
        $caseLabel = $(if ($unionCase.Mode) { [string]$unionCase.Mode } else { '성공' })
        $userConfig = Initialize-MigrationCase -Name ('O08-union-' + $caseLabel) -UserSchema 10
        $userConfig.customRepeat.progress = [pscustomobject]@{ lap = 1; index = 1; fingerprint = 'x' }
        Write-TestConfig $userConfig
        Write-LegacyMarkers -Sections @('customRepeat', 'abyssCustomRepeat')
        if ($unionCase.Mode) { $script:markerClearModes['custom_done.marker'] = [string]$unionCase.Mode }
        $unionResult = Update-ConfigToLatest
        Invoke-MigrationNotice
        $markerWarnings = (Get-LogCount $RESET_MARKER_WARNING_PATTERN) + (Get-LogCount $LEGACY_WARNING_PATTERN)
        Assert-Case ('O08 진행 있음 + 같은 경로 version 2 ({0}): 이전 성공 · 경로당 정리 1회 · 플래그(진행 초기화/구버전) = 남은 파일과 일치 · 경고 · 건수 안내' -f $caseLabel) `
            ('{0} · 던전 {1}회 · 어비스 {2}회 · 플래그 {3}/{4} · 무효화 {5} · 던전 마커 남음 {6} · 마커 경고 {7} · 건수 안내 {8}줄' -f $unionResult,
                [int]$script:markerClearCounts['custom_done.marker'], [int]$script:markerClearCounts['abyss_custom_done.marker'],
                $script:customMarkerClearFailed, $script:legacyMarkerClearFailed, $script:legacyMarkerClearedCount,
                [System.IO.File]::Exists($script:customDungeonMarkerFile), $markerWarnings,
                (Get-ExactLogCount ($LEGACY_NOTICE_FORMAT -f $script:legacyMarkerClearedCount))) ('True · ' + $unionCase.Expect + ' · 건수 안내 1줄')
    }
}

# ===== O09 owner JSON 왕복 - generation 정수 =====
function Test-CaseO09 {
    $roundTrip = @()
    foreach ($generation in @(0, 7, 2147483647)) {
        $context = @{ Items = $ABYSS_ITEMS; Order = $null; Lap = 1; Index = 2; Item = $ABYSS_ITEMS[2]; Generation = $generation }
        $parsed = (New-CustomMarkerOwnerJson -Context $context) | ConvertFrom-Json
        $roundTrip += ('{0}:{1}/{2}' -f $generation, ($parsed.generation -is [int]), ([int]$parsed.generation -eq $generation))
    }
    Assert-Case 'O09 마커 owner JSON 왕복: generation 은 정수 그대로(0·7·Int32 최대)' ($roundTrip -join ' ') '0:True/True 7:True/True 2147483647:True/True'
    # journal 왕복: GUI 쪽 저장소로 쓴 항목·pending 의 세대와 owner 의 lap·index 가 다시 읽어도 정수
    Use-CaseFolder -Name 'O09-journal'
    $context = @{ Items = $ABYSS_ITEMS; Order = @(1, 2, 0); Lap = 2; Index = 1; Item = $ABYSS_ITEMS[2]; Generation = 7 }
    $owner = New-TestOwner -Context $context
    $entryToAdd = New-TestEntry -Section $ABYSS_SECTION -Owner $owner -Generation 7
    $pendingToAdd = New-TestPending -Owner $owner -Generation 7 -Nonce $entryToAdd.nonce
    $seedMutator = {
        param($journal, $change)
        $journal.entries = @($journal.entries) + @($entryToAdd)
        $journal.pending = @($journal.pending) + @($pendingToAdd)
        $change.Changed = $true
    }.GetNewClosure()
    $seedResult = & $script:realUpdateAbyssJournal -Path $script:abyssJournalPath -Mutator $seedMutator
    $readBack = Read-AbyssJournal -Path $script:abyssJournalPath
    $readEntry = @($readBack.Journal.entries)[0]
    $readPending = @($readBack.Journal.pending)[0]
    Assert-Case 'O09 journal 왕복: 저장 changed · 읽기 ok · 항목·pending 세대 Int32 7 · owner lap·index Int32' `
        ('{0} · {1} · {2}/{3} · {4}/{5} · {6}/{7}' -f $seedResult.Tag, $readBack.Status, $readEntry.generation.GetType().Name, $readEntry.generation,
            $readPending.generation.GetType().Name, $readPending.generation, $readEntry.owner.lap.GetType().Name, $readEntry.owner.index.GetType().Name) `
        'changed · ok · Int32/7 · Int32/7 · Int32/Int32'
    Assert-Case 'O09 journal 왕복 뒤에도 지금 owner·세대와 일치' (Test-AbyssJournalOwnerMatch -Entry $readEntry -Owner (New-TestOwner -Context $context) -Generation 7) $true
}

# ===== O10 섹션 매트릭스 =====
function Test-CaseO10 {
    # 각 섹션 Reset 은 그 노드만 +1 (던전 1 · 어비스 2 · 심층 3 · 생활 키 없음에서 시작)
    $resetRows = @()
    foreach ($section in $BATTLE_SECTIONS) {
        Use-CaseFolder -Name ('O10-reset-' + $section)
        $progressTable = @{}
        foreach ($anySection in $ALL_SECTIONS) { $progressTable[$anySection] = New-TestProgress -Section $anySection -Lap 1 -Index 1 }
        Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 1; abyssCustomRepeat = 2; deepCustomRepeat = 3 } -Progress $progressTable)
        [void](Reset-CustomProgress -SectionName $section)
        $resetRows += ('{0} → {1}' -f $section, (Get-GenerationText -Config (Read-TestConfig)))
    }
    Assert-Case 'O10 섹션별 Reset: 그 노드만 +1 · 생활 키 없음' ($resetRows -join ' | ') (@(
            'customRepeat → customRepeat=2 abyssCustomRepeat=2 deepCustomRepeat=3 lifeCustomRepeat=없음',
            'abyssCustomRepeat → customRepeat=1 abyssCustomRepeat=3 deepCustomRepeat=3 lifeCustomRepeat=없음',
            'deepCustomRepeat → customRepeat=1 abyssCustomRepeat=2 deepCustomRepeat=4 lifeCustomRepeat=없음') -join ' | ')

    # ② 직후 종료 → 재시작: 3섹션 모두 복구 예약 0 · 폐기 1 (+1 이 그 섹션 노드에 같은 저장으로 들어가야 성립)
    $crashRows = @()
    foreach ($section in $BATTLE_SECTIONS) {
        Use-CaseFolder -Name ('O10-crash-' + $section)
        Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 5; abyssCustomRepeat = 5; deepCustomRepeat = 5 } `
                -Progress @{ $section = (New-TestProgress -Section $section -Lap 1 -Index 0) })
        Write-TestMarker -Section $section -Context (Get-CustomCurrentContext -SectionName $section)
        $controlGate = Invoke-StartGateMarkerCheck -Section $section
        Write-TestMarker -Section $section -Context (Get-CustomCurrentContext -SectionName $section)
        $crashed = Invoke-WithCrash -CrashPoint 'cleanup' -Call { Reset-CustomProgress -SectionName $section }
        $gate = Invoke-StartGateMarkerCheck -Section $section
        $crashRows += ('{0}: 대조군 복구 {1} · 끊김 {2} · 세대 {3} · {4}' -f $section, $controlGate.Recovery, $crashed,
            (Read-TestConfig).$section.progressGeneration, (Format-GateResult $gate))
    }
    Assert-Case 'O10 ② 직후 종료 3섹션 동일: 복구 예약 0 · 폐기 1' ($crashRows -join ' | ') (@(
            'customRepeat: 대조군 복구 True · 끊김 True · 세대 6 · 복구 예약 False · 마커 남음 False · 정리 1 · 폐기 안내 1',
            'abyssCustomRepeat: 대조군 복구 True · 끊김 True · 세대 6 · 복구 예약 False · 마커 남음 False · 정리 1 · 폐기 안내 1',
            'deepCustomRepeat: 대조군 복구 True · 끊김 True · 세대 6 · 복구 예약 False · 마커 남음 False · 정리 1 · 폐기 안내 1') -join ' | ')

    # 던전·심층(·생활)은 journal 접근 0 - 어비스 항목이 든 journal 이 있어도 손대지 않음 / 어비스는 저장 1회
    $accessRows = @()
    foreach ($section in $ALL_SECTIONS) {
        foreach ($pathName in @('reset', 'random', 'shuffle')) {
            Use-CaseFolder -Name ('O10-access-' + $section + '-' + $pathName)
            $randomSections = @()
            if ($pathName -eq 'shuffle') { $randomSections = @($section) }
            $progressTable = @{}
            if ($pathName -ne 'shuffle') { $progressTable[$section] = New-TestProgress -Section $section -Lap 1 -Index 1 }
            Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 0; abyssCustomRepeat = 0; deepCustomRepeat = 0 } -Progress $progressTable -Random $randomSections)
            $abyssOwner = New-TestOwner -Context @{ Items = $ABYSS_ITEMS; Order = $null; Lap = 1; Index = 0; Item = $ABYSS_ITEMS[0]; Generation = 0 }
            $abyssEntry = New-TestEntry -Section $ABYSS_SECTION -Owner $abyssOwner -Generation 0
            Write-TestJournal -Path $script:abyssJournalPath -Entries @($abyssEntry) -Pending @(New-TestPending -Owner $abyssOwner -Generation 0 -Nonce $abyssEntry.nonce)
            $journalBefore = Get-JournalState
            [void](Invoke-ResetPath -Path $pathName -Section $section)
            $journalChanged = $(if ((Get-JournalState) -eq $journalBefore) { '그대로' } else { '바뀜' })
            $accessRows += ('{0}/{1}: 저장 {2} · 접근 {3} · {4}' -f $section, $pathName, @($script:eventLog | Where-Object { $_ -eq 'journal' }).Count,
                $(if ($script:journalAccessCount -gt 0) { '있음' } else { '0' }), $journalChanged)
        }
    }
    $expectedAccessRows = @()
    foreach ($section in $ALL_SECTIONS) {
        foreach ($pathName in @('reset', 'random', 'shuffle')) {
            if ($section -eq $ABYSS_SECTION) { $expectedAccessRows += ('{0}/{1}: 저장 1 · 접근 있음 · 바뀜' -f $section, $pathName) }
            else { $expectedAccessRows += ('{0}/{1}: 저장 0 · 접근 0 · 그대로' -f $section, $pathName) }
        }
    }
    Assert-Case 'O10 journal 접근: 어비스만 저장 1회 · 던전·심층·생활은 접근 0(파일 그대로)' ($accessRows -join ' | ') ($expectedAccessRows -join ' | ')

    # 키 없는 섹션의 컨텍스트 세대 = [int] 0
    Use-CaseFolder -Name 'O10-no-key'
    Write-TestConfig (New-TestConfig -Progress @{ deepCustomRepeat = (New-TestProgress -Section 'deepCustomRepeat' -Lap 1 -Index 1) })
    $noKeyContext = Get-CustomCurrentContext -SectionName 'deepCustomRepeat'
    Assert-Case 'O10 키 없는 섹션: 컨텍스트 Generation 은 [int] 0' ('{0}/{1}' -f ($noKeyContext.Generation -is [int]), $noKeyContext.Generation) 'True/0'

    # 키 없는 전투 섹션(스키마 11 이전 config 를 이전 없이 읽은 경우 - 저장소에서 직접 실행 등)의 초기화 3경로 → 키를 만들어 세대 1
    #   (변이 검증 보강 2026-10-09: 다른 행은 늘 세대 키를 미리 둬서 키를 붙이는 갈래(Add-Member)가 한 번도 돌지 않았습니다)
    $noKeyRows = @()
    foreach ($section in $BATTLE_SECTIONS) {
        foreach ($pathName in @('reset', 'random', 'shuffle')) {
            Use-CaseFolder -Name ('O10-no-key-' + $section + '-' + $pathName)
            $randomSections = @()
            if ($pathName -eq 'shuffle') { $randomSections = @($section) }
            $progressTable = @{}
            if ($pathName -ne 'shuffle') { $progressTable[$section] = New-TestProgress -Section $section -Lap 1 -Index 1 }
            Write-TestConfig (New-TestConfig -Progress $progressTable -Random $randomSections)
            [void](Invoke-ResetPath -Path $pathName -Section $section)
            $noKeyNode = (Read-TestConfig).$section
            $noKeyRows += ('{0}/{1}={2}' -f $section, $pathName,
                $(if ($noKeyNode.PSObject.Properties['progressGeneration']) { [string]$noKeyNode.progressGeneration } else { '없음' }))
        }
    }
    $expectedNoKeyRows = @(foreach ($section in $BATTLE_SECTIONS) { foreach ($pathName in @('reset', 'random', 'shuffle')) { '{0}/{1}=1' -f $section, $pathName } })
    Assert-Case 'O10 키 없는 전투 섹션: 진행 초기화·랜덤 토글·새 순열 뒤 세대 키 생성 = 1' ($noKeyRows -join ' ') ($expectedNoKeyRows -join ' ')

    # 생활 섹션 음성(명세 리뷰 2 P2): Reset · 랜덤 토글 · 새 순열 뒤에도 progressGeneration 키(와 설명 키)가 생기지 않음
    $lifeRows = @()
    foreach ($pathName in @('reset', 'random', 'shuffle')) {
        Use-CaseFolder -Name ('O10-life-' + $pathName)
        $randomSections = @()
        if ($pathName -eq 'shuffle') { $randomSections = @($LIFE_SECTION) }
        $progressTable = @{}
        if ($pathName -ne 'shuffle') { $progressTable[$LIFE_SECTION] = New-TestProgress -Section $LIFE_SECTION -Lap 1 -Index 1 }
        Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 0; abyssCustomRepeat = 0; deepCustomRepeat = 0 } -Progress $progressTable -Random $randomSections)
        $lifeOutput = @(Invoke-ResetPath -Path $pathName -Section $LIFE_SECTION)
        $lifeNode = (Read-TestConfig).lifeCustomRepeat
        $lifeRows += ('{0}: 저장 {1} · 키 {2}/{3} · 순열 {4}' -f $pathName, @($script:eventLog | Where-Object { $_ -eq 'save' }).Count,
            [bool]$lifeNode.PSObject.Properties['progressGeneration'], [bool]$lifeNode.PSObject.Properties['_progressGeneration'],
            $(if ($pathName -eq 'shuffle') { [string](Test-CustomShuffleOrder -Order $lifeNode.progress.shuffleOrder -ItemCount $LIFE_ITEMS.Count) } else { '-' }))
    }
    Assert-Case 'O10 생활 음성: 진행 초기화·랜덤 토글·새 순열 뒤에도 세대 키·설명 키 없음' ($lifeRows -join ' | ') `
        'reset: 저장 1 · 키 False/False · 순열 - | random: 저장 1 · 키 False/False · 순열 - | shuffle: 저장 1 · 키 False/False · 순열 True'
}

# ===== O11 스키마 9 → 11 (마지막 배포본 v2.1.11 의 스키마 - 점검 P2-8) =====
function Test-CaseO11 {
    $userConfig = Initialize-MigrationCase -Name 'O11-schema9' -UserSchema 9
    $userConfig.abyssCustomRepeat.progress = [pscustomobject]@{ lap = 1; index = 2; fingerprint = 'a' }
    # 생활은 진행 없음 - 진행이 있으면 기존 '진행 초기화 섹션의 마커 정리' 로 지워져 '구버전 수집에서 빠짐' 을 볼 수 없습니다
    Write-TestConfig $userConfig
    Write-LegacyMarkers
    $migrated = Update-ConfigToLatest
    $result = Read-TestConfig
    Assert-Case 'O11 스키마 9 → 11: 이전 · 최신 스키마 · 세대(진행 지운 어비스만 1) · 생활 키 없음' `
        ('{0} · {1} · {2}' -f $migrated, $result.configSchemaVersion, (Get-GenerationText -Config $result)) `
        ('True · {0} · customRepeat=0 abyssCustomRepeat=1 deepCustomRepeat=0 lifeCustomRepeat=없음' -f ($REAL_DEFAULT_CONFIG_TEXT | ConvertFrom-Json).configSchemaVersion)
    Assert-Case 'O11 스키마 9 → 11: 전투 3섹션 설명 키 · 구버전 마커 3개 무효화(생활 그대로) · 3건 · 어비스 정리 1회' `
        ('{0} · {1}/{2}/{3}/{4} · {5} · {6}' -f ((@($BATTLE_SECTIONS) | ForEach-Object { [bool]$result.$_.PSObject.Properties['_progressGeneration'] }) -join '/'),
            [System.IO.File]::Exists($script:customDungeonMarkerFile), [System.IO.File]::Exists($script:customAbyssMarkerFile),
            [System.IO.File]::Exists($script:customDeepMarkerFile), [System.IO.File]::Exists($script:customLifeMarkerFile),
            $script:legacyMarkerClearedCount, [int]$script:markerClearCounts['abyss_custom_done.marker']) 'True/True/True · False/False/False/True · 3 · 1'
    Invoke-MigrationNotice
    Assert-Case 'O11 스키마 9 → 11 안내: 구버전 [안내] 3건 1줄 · 진행 초기화 안내 1줄' `
        ('{0}/{1}' -f (Get-ExactLogCount $LEGACY_NOTICE_THREE), (Get-LogCount '^\[안내\] 업데이트로 커스텀 반복 진행 기록을 초기화했습니다')) '1/1'
}

# ===== O12 섹션 노드 재작성 3함수의 세대 이월(M6 - 명세 5절 A1) =====
function Test-CaseO12 {
    Use-CaseFolder -Name 'O12-carry'
    $progressTable = @{}
    foreach ($section in $BATTLE_SECTIONS) { $progressTable[$section] = New-TestProgress -Section $section -Lap 2 -Index 1 }
    Write-TestConfig (New-TestConfig -Generations @{ customRepeat = 3; abyssCustomRepeat = 5; deepCustomRepeat = 7 } -Progress $progressTable)
    $config = Read-Config
    Set-CustomRepeatOnConfig -Config $config
    Set-AbyssCustomRepeatOnConfig -Config $config
    Set-DeepCustomRepeatOnConfig -Config $config
    Save-Config $config
    $saved = Read-TestConfig
    Assert-Case 'O12 이월: 세 섹션 세대 3·5·7 · 진행(2바퀴 1번) 그대로 · 설명 키' `
        ('{0} · {1} · {2}' -f (Get-GenerationText -Config $saved),
            ((@($BATTLE_SECTIONS) | ForEach-Object { '{0}-{1}' -f $saved.$_.progress.lap, $saved.$_.progress.index }) -join '/'),
            ((@($BATTLE_SECTIONS) | ForEach-Object { [bool]$saved.$_.PSObject.Properties['_progressGeneration'] }) -join '/')) `
        'customRepeat=3 abyssCustomRepeat=5 deepCustomRepeat=7 lifeCustomRepeat=없음 · 2-1/2-1/2-1 · True/True/True'
    Assert-Case 'O12 이월 뒤 저장 왕복: 컨텍스트 Generation 3·5·7 ([int])' `
        ((@($BATTLE_SECTIONS) | ForEach-Object {
                    $carryContext = Get-CustomCurrentContext -SectionName $_
                    '{0}={1}/{2}' -f $_, $carryContext.Generation, ($carryContext.Generation -is [int]) }) -join ' ') `
        'customRepeat=3/True abyssCustomRepeat=5/True deepCustomRepeat=7/True'
    # 설명 키 문구는 세 함수의 리터럴 사본과 내장 config.json 사본이 같아야 합니다 - 매 시작 저장이 세 함수의 문구로 사용자 config 를 덮으므로
    #   한쪽만 고치면 업데이트 직후(config.json 문구)와 첫 저장 뒤(함수 문구)의 설명이 달라집니다(명세 대조 2.2·2.3 P3-1 - 문구 정정 때 추가)
    $defaultConfigObject = $REAL_DEFAULT_CONFIG_TEXT | ConvertFrom-Json
    Assert-Case 'O12 설명 키 문구: 세 함수가 쓴 _progressGeneration = config.json 의 같은 섹션 값(대소문자 구분)' `
        ((@($BATTLE_SECTIONS) | ForEach-Object {
                    '{0}={1}' -f $_, ([string]$saved.$_._progressGeneration -ceq [string]$defaultConfigObject.$_._progressGeneration) }) -join ' ') `
        'customRepeat=True abyssCustomRepeat=True deepCustomRepeat=True'
    # 세대 키가 없거나(스키마 11 이전) 정수가 아니면 0 으로 이월
    Use-CaseFolder -Name 'O12-carry-default'
    $odd = New-TestConfig -Generations @{ abyssCustomRepeat = 'abc' }
    Write-TestConfig $odd
    $oddConfig = Read-Config
    Set-CustomRepeatOnConfig -Config $oddConfig
    Set-AbyssCustomRepeatOnConfig -Config $oddConfig
    Assert-Case 'O12 이월: 키 없음 → 0 · 정수 아님 → 0' ('{0}/{1}' -f $oddConfig.customRepeat.progressGeneration, $oddConfig.abyssCustomRepeat.progressGeneration) '0/0'
    # 세 함수 × {키 없음, 정수 아님} 전부 - 값 0 이고 [int](구현 리뷰 2.2·2.3 P2: 위 단언은 심층이 빠져 있었음)
    foreach ($carryShape in @('missing', 'nonint')) {
        Use-CaseFolder -Name ('O12-carry-default-' + $carryShape)
        $shapeGenerations = @{}
        if ($carryShape -eq 'nonint') { foreach ($battleSection in $BATTLE_SECTIONS) { $shapeGenerations[$battleSection] = 'abc' } }
        Write-TestConfig (New-TestConfig -Generations $shapeGenerations)
        $shapeConfig = Read-Config
        Set-CustomRepeatOnConfig -Config $shapeConfig
        Set-AbyssCustomRepeatOnConfig -Config $shapeConfig
        Set-DeepCustomRepeatOnConfig -Config $shapeConfig
        Assert-Case ('O12 이월 매트릭스({0}): 세 함수 모두 [int] 0' -f $carryShape) `
            ((@($BATTLE_SECTIONS) | ForEach-Object {
                        '{0}={1}/{2}' -f $_, $shapeConfig.$_.progressGeneration, ($shapeConfig.$_.progressGeneration -is [int]) }) -join ' ') `
            'customRepeat=0/True abyssCustomRepeat=0/True deepCustomRepeat=0/True'
    }
    # 진행 초기화 두 경로의 마커 삭제 실패 경고(구현 리뷰 2.2·2.3 P3): 전투 섹션은 저장에서 세대가 올라 옛 마커가 복구에 쓰이지 않고,
    # 세대가 없는 생활은 옛 경고가 그대로 맞습니다
    $markerWarningResults = @()
    foreach ($warningCase in @(@($ABYSS_SECTION, 'reset'), @($ABYSS_SECTION, 'random'), @($LIFE_SECTION, 'reset'))) {
        Use-CaseFolder -Name ('O12-marker-warning-{0}-{1}' -f $warningCase[0], $warningCase[1])
        Write-TestConfig (New-TestConfig)
        $script:markerClearModes[[System.IO.Path]::GetFileName((Get-CustomMarkerFileForSection -SectionName $warningCase[0]))] = 'fail-always'
        if ($warningCase[1] -eq 'reset') { $null = @(Reset-CustomProgress -SectionName $warningCase[0]) }
        else { $null = @(Save-CustomRandomOrder -SectionName $warningCase[0] -Enabled $true) }
        $warningLine = [string](@(@($script:guiLogLines) | Where-Object { $_ -match $RESET_MARKER_WARNING_PATTERN }) -join '|')
        $markerWarningResults += ('{0}/{1}={2}' -f $warningCase[0], $warningCase[1], $(if ($warningLine.Contains('옛 세대 기록이라 복구에 쓰이지 않습니다')) { 'new' }
                elseif ($warningLine.Contains('이미 끝낸 판을 복구하려 할 수 있습니다')) { 'old' } else { 'none' }))
    }
    Assert-Case 'O12 마커 삭제 실패 경고: 전투(어비스) 진행 초기화·랜덤 토글 = 세대 문구 · 생활 = 옛 문구' ($markerWarningResults -join ' ') `
        'abyssCustomRepeat/reset=new abyssCustomRepeat/random=new lifeCustomRepeat/reset=old'
    # 매 시작 저장(Save-SettingsFromUi)이 세 함수를 부르는 배선 - 본체는 UI 의존이 넓어 주석 뺀 원문으로 봅니다(명세 3.2 O12)
    $settingsBody = Remove-SourceComments -Text $guiFunctionTexts['Save-SettingsFromUi']
    $callIndexes = @(@('Set-CustomRepeatOnConfig -Config $cfg', 'Set-AbyssCustomRepeatOnConfig -Config $cfg', 'Set-DeepCustomRepeatOnConfig -Config $cfg',
            'Save-Config $cfg') | ForEach-Object { $settingsBody.IndexOf($_) })
    Assert-Case 'O12 배선: Save-SettingsFromUi 가 세 함수를 부른 뒤 같은 객체를 저장' `
        ('{0}/{1}' -f (@($callIndexes | Where-Object { $_ -lt 0 }).Count -eq 0),
            (($callIndexes[0] -lt $callIndexes[1]) -and ($callIndexes[1] -lt $callIndexes[2]) -and ($callIndexes[2] -lt $callIndexes[3]))) 'True/True'
}

# ===== O13 GUI owner JSON → 워커 추출(W4) - 5필드·세대 값 일치 · 세대 0·양수 · 순차 orderKey '' =====
function Get-O13TypeName {
    # 값의 형식 이름(null 이면 'null') - 추출이 빈 값을 돌려준 변이에서 GetType() 예외가 아니라 단언 차이로 드러나게(단계 2.10 구현 검증)
    param($Value)
    if ($null -eq $Value) { return 'null' }
    return $Value.GetType().Name
}

function Test-CaseO13 {
    # 기동 env 의 소유자 JSON 두 생산 경로(일반 기동 New-CustomMarkerOwnerJson · 마무리 실행 ConvertTo-CustomMarkerOwnerJson -Owner 보류 Owner)
    # 그대로 → 워커 ConvertTo-AbyssJournalOwner → owner 5필드(이름·순서 · lap·index 정수) = GUI canonical owner · Generation(정수) = 진행 세대 →
    # 그 owner·세대로 만든 완료 기록 항목을 GUI 대조가 같은 판으로 봄(세대가 하나 다르면 거짓 - 역행 포함)
    $rows = @(
        @{ N = '순차 · 세대 0'; Context = @{ Items = $ABYSS_ITEMS; Order = $null; Lap = 1; Index = 0; Item = $ABYSS_ITEMS[0]; Generation = 0 }; Path = 'context' },
        @{ N = '순차 · 세대 5'; Context = @{ Items = $ABYSS_ITEMS; Order = $null; Lap = 3; Index = 2; Item = $ABYSS_ITEMS[2]; Generation = 5 }; Path = 'context' },
        @{ N = '랜덤 순열 · 세대 7'; Context = @{ Items = $ABYSS_ITEMS; Order = @(2, 0, 1); Lap = 2; Index = 1; Item = $ABYSS_ITEMS[0]; Generation = 7 }; Path = 'context' },
        @{ N = '마무리 실행 보류 Owner · 세대 2'; Context = @{ Items = $ABYSS_ITEMS; Order = $null; Lap = 1; Index = 1; Item = $ABYSS_ITEMS[1]; Generation = 2 }; Path = 'hold' })
    $results = foreach ($row in $rows) {
        $context = $row.Context
        $canonical = Get-CustomCanonicalOwner -Context $context
        $ownerJson = $(if ($row.Path -eq 'hold') { ConvertTo-CustomMarkerOwnerJson -Owner $canonical } else { New-CustomMarkerOwnerJson -Context $context })
        $extracted = ConvertTo-AbyssJournalOwner -OwnerJson $ownerJson
        if ($null -eq $extracted) { '{0}: 추출 $null' -f $row.N; continue }
        $fieldNames = (@($extracted.Owner.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
        $sameFields = (([string]$extracted.Owner.fingerprint -ceq [string]$canonical.fingerprint) -and ([string]$extracted.Owner.orderKey -ceq [string]$canonical.orderKey) -and
            ($extracted.Owner.lap -eq $canonical.lap) -and ($extracted.Owner.index -eq $canonical.index) -and ([string]$extracted.Owner.item -ceq [string]$canonical.item))
        $entry = [pscustomobject]@{ owner = $extracted.Owner; generation = $extracted.Generation }
        '{0}: 5필드 {1}({2}) · lap·index {3}/{4} · 세대 {5}/{6} · orderKey [{7}] · 대조 같은 세대 {8} · 세대 +1 {9} · 세대 -1 {10}' -f $row.N, $sameFields, $fieldNames,
            (Get-O13TypeName $extracted.Owner.lap), (Get-O13TypeName $extracted.Owner.index), $extracted.Generation, (Get-O13TypeName $extracted.Generation),
            $(if ($null -eq $context.Order) { $extracted.Owner.orderKey } else { [string]($extracted.Owner.orderKey -ceq (Get-CustomOrderKey -Order $context.Order) -and $extracted.Owner.orderKey -ne '') }),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $canonical -Generation $context.Generation),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $canonical -Generation ($context.Generation + 1)),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $canonical -Generation ($context.Generation - 1))
    }
    $wantRows = foreach ($row in $rows) {
        '{0}: 5필드 True(fingerprint,orderKey,lap,index,item) · lap·index Int32/Int32 · 세대 {1}/Int32 · orderKey [{2}] · 대조 같은 세대 True · 세대 +1 False · 세대 -1 False' -f $row.N,
            $row.Context.Generation, $(if ($null -eq $row.Context.Order) { '' } else { 'True' })
    }
    Assert-Case 'O13 GUI 소유자 JSON(일반 기동·마무리 실행) → 워커 추출 owner 5필드·세대 = GUI canonical · 순차 orderKey '''' · 랜덤은 같은 orderKey · GUI 대조 같은 판' `
        ($results -join ' || ') ($wantRows -join ' || ')
    # 세대가 없는 JSON(옛 모양)은 0, 해석 못 하는 값은 $null(부른 쪽이 기록을 남기지 않음 - 워커 기록 함수의 [경고] 는 test_abyss_journal_store X4-d)
    $noGeneration = ConvertTo-AbyssJournalOwner -OwnerJson '{"version":2,"fingerprint":"f","orderKey":"","lap":1,"index":0,"item":"i"}'
    $unreadable = @('', 'not json', '[1,2]', '{"version":3,"fingerprint":"f","orderKey":"","lap":"x","index":0,"item":"i","generation":1}' | ForEach-Object { $null -eq (ConvertTo-AbyssJournalOwner -OwnerJson $_) })
    Assert-Case 'O13 세대 없음 → 0(Int32) · 해석 못 함(빈 값·JSON 아님·배열·lap 정수 아님) → $null' `
        ('{0}/{1} · {2}' -f $noGeneration.Generation, (Get-O13TypeName $noGeneration.Generation), ($unreadable -join ',')) '0/Int32 · True,True,True,True'
}

# ===== 정적 배선 (주석 뺀 원문) =====
function Test-CaseStatic {
    $guiCode = Remove-SourceComments -Text ([System.IO.File]::ReadAllText($guiPath))
    Assert-Case '정적: 폐기 헬퍼 호출은 3곳(진행 초기화·랜덤 토글·새 순열)' `
        ([regex]::Matches($guiCode, '(?m)^\s*Remove-AbyssJournalSectionEntries -SectionName \$SectionName\s*$').Count) 3
    $orderRows = @()
    foreach ($functionName in @('Reset-CustomProgress', 'Save-CustomRandomOrder', 'Confirm-CustomShuffleReady')) {
        $body = Remove-SourceComments -Text $guiFunctionTexts[$functionName]
        $generationIndex = $body.LastIndexOf('Step-CustomProgressGeneration -Node $node -SectionName $SectionName')
        $saveIndex = $body.LastIndexOf('Save-Config $cfg')
        $cleanupIndex = $body.IndexOf('Remove-AbyssJournalSectionEntries -SectionName $SectionName')
        $markerIndex = $body.IndexOf('Clear-CustomMarkerFile -Path (Get-CustomMarkerFileForSection -SectionName $SectionName)')
        $orderRows += ('{0}: 세대<저장 {1} · 저장<폐기 {2} · 폐기<마커 {3} · 세대 {4}회' -f $functionName, ($generationIndex -ge 0 -and $generationIndex -lt $saveIndex),
            ($saveIndex -ge 0 -and $saveIndex -lt $cleanupIndex), $(if ($markerIndex -lt 0) { '-' } else { [string]($cleanupIndex -lt $markerIndex) }),
            [regex]::Matches($body, 'Step-CustomProgressGeneration').Count)
    }
    Assert-Case '정적: 세 경로 모두 ② 세대 +1 → 저장 → ① 폐기 → ③ 마커(새 순열은 ③ 없음) · 세대 +1 은 한 번' ($orderRows -join ' | ') `
        ('Reset-CustomProgress: 세대<저장 True · 저장<폐기 True · 폐기<마커 True · 세대 1회 | ' +
            'Save-CustomRandomOrder: 세대<저장 True · 저장<폐기 True · 폐기<마커 True · 세대 1회 | ' +
            'Confirm-CustomShuffleReady: 세대<저장 True · 저장<폐기 True · 폐기<마커 - · 세대 1회')
    # 폐기 헬퍼: 저장 함수 1회 · 래퍼 읽기 없음 · mutator 는 클로저이고 $script: 를 읽지 않음(체크리스트 5·6)
    $helperBody = Remove-SourceComments -Text $guiFunctionTexts['Remove-AbyssJournalSectionEntries']
    $helperAst = [System.Management.Automation.Language.Parser]::ParseInput($guiFunctionTexts['Remove-AbyssJournalSectionEntries'], [ref]$null, [ref]$null)
    $closureBlocks = @($helperAst.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $node.Member.Extent.Text -eq 'GetNewClosure' -and
                $node.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst]
            }, $true))
    $closureScriptVariables = @()
    foreach ($closureBlock in $closureBlocks) {
        $closureScriptVariables += @($closureBlock.Expression.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.VariableExpressionAst] -and $node.VariablePath.UserPath -like 'script:*'
                }, $true))
    }
    Assert-Case '정적: 폐기 헬퍼 - Update-AbyssJournal 1회 · Read-AbyssJournal 0 · 클로저 mutator 1개 · 그 안의 $script: 0' `
        ('{0}/{1}/{2}/{3}' -f [regex]::Matches($helperBody, 'Update-AbyssJournal\b').Count, [regex]::Matches($helperBody, 'Read-AbyssJournal').Count,
            $closureBlocks.Count, $closureScriptVariables.Count) '1/0/1/0'
}

# ===== 실행 =====
$caseFunctions = @('Test-CaseO01', 'Test-CaseO02', 'Test-CaseO03', 'Test-CaseO04', 'Test-CaseO05', 'Test-CaseO06', 'Test-CaseO07',
    'Test-CaseO08', 'Test-CaseO09', 'Test-CaseO10', 'Test-CaseO11', 'Test-CaseO12', 'Test-CaseO13', 'Test-CaseStatic')
$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    foreach ($caseFunction in $caseFunctions) {
        try {
            & $caseFunction
        } catch {
            "FAIL {0}: 예외 {1} (줄 {2})" -f $caseFunction, $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber
            $script:fails++
        }
    }
} finally {
    try { [System.IO.Directory]::Delete($testRootFolder, $true) } catch { "참고: 임시 폴더 정리 실패 - $($_.Exception.Message)" }
}
'걸린 시간 {0:N1}초' -f ($totalWatch.ElapsedMilliseconds / 1000)
exit $fails
