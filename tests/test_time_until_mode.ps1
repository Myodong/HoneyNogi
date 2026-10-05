# 시간 지정 '지정 시각이 지나면 그 판까지' GUI 회귀 (2026-10-02 신설 - 시간 지정 '그 판까지' 설계_v2 8.2 T4·T5, 설계 리뷰 1차 12절 P2)
#
# 배경: 전투의 시간 지정 규칙을 '지금 + 클리어 대기 <= 지정 시각이면 다음 회차'에서 '지금 < 지정 시각이면 새 판 시작, 그 전에 시작한 판은
# 끝까지'로 바꿨다. 워커가 지정 시각 전에 다음 판으로 이어 가기로 정하고 끝내면 새 종료 코드 11 을 내고, GUI 는 11 이면 지정 시각을 보지 않고
# 다음 워커를 띄운다(판단 주체 하나 - 조건 4). 옛 판단 사슬은 타이머 스크립트블록 안에 있어 이름으로 추출할 수 없었고 어떤 테스트도 그 사슬을
# 실행하지 못했다. 그래서 판단(순수부 Get-NextCycleAction)과 실행(Invoke-NextCycleDecision)을 함수로 뺐다 - 여기서는 그 함수들을 GUI 소스에서
# 그대로 추출해 돌리고(사본 금지), 타이머에 남은 호출 한 줄씩은 주석 뺀 사본에서 원문으로 고정한다.
# 여기서 고정하는 계약 (설계 8.2 표 번호 그대로. T4-g·T4-h 는 설계 표 밖에서 더한 행동 확인 - 소스 블록을 그대로 실행):
#   T4-a Get-NextCycleAction 진리표 - 안전 중지 > (지정 횟수 | 준비 실행 3회 연속) > 지정 시간 > 다음 회차, 코드 11 은 '지정 시간' 칸만 건너뜀
#   T4-b Test-TimeAllowsNextCycle - 전투 '지금 < 목표', 생활·기타 '지금 + 사이클 상한 <= 목표'(옛 식 그대로)
#   T4-c Test-WorkerTimeJudgeActive - 던전·심층·어비스 파티원(전투·비커스텀)만. 생활·기타로 바꿔도 보존되는 전투 라디오를 모형화 (설계 회귀 R-3)
#   T4-d 문구 보조 함수 - 전투만 새 문구, 생활·기타 출력은 옛 문구와 글자 그대로
#   T4-e 배선 (주석 뺀 GUI 사본) - 타이머 바깥 조건·호출 두 곳·완료 줄·옛 사슬 리터럴 위치·판단 호출 인자·시작 게이트·UNTIL 분기·상태줄·설명서
#   T4-f Invoke-NextCycleDecision 행동 - Stop-AllRun·Start-NextCycle·Add-GuiLog 를 모의로 바꿔 '무엇을 했는지'로 지킴 (인자 누락·고정값 변이를 잡는 곳)
#   T4-g 시작 게이트 행동 - Invoke-StartAutomation 의 시간 지정 블록을 그대로 실행 (전투는 거부 없음 - 조건 2, 생활·기타는 거부 원문 - 조건 5)
#   T4-h UNTIL 전달 범위 행동 - Start-NextCycle 의 UNTIL 구간을 그대로 실행 (설계 2.5 표 - 받는 워커는 생활·던전·심층·어비스 파티원뿐)
#   P2   문화권 왕복 - GUI 목표 시각 계산·전투 생산식 → 워커 Get-LifeUntilDeadline → 던전·파티원 판단을 ko-KR·th-TH·fi-FI × (21:20 / 자정 넘김)
#        으로 돌려 해석값이 원래 DateTime 과 같음을 단언한다 (현재 문화권으로 만들면 th-TH 는 불기 연도로 '정상' 해석, fi-FI 는 해석 실패)
#   T5   생활 그대로 = T4-b 5~7 · T4-d 생활 열 · T4-f 13·14 · T4-g 생활 행 · T4-h 생활 행 (+ test_life_gather 의 생활 배선 원문 단언)
# 모의: 시각은 Get-Date($script:fakeNow), 라디오·숫자 칸·상태줄·시각 선택기는 속성 객체입니다. 정지·다음 회차·GUI 로그는 기록만 합니다.
# 문화권: 문구의 시각 서식(HH:mm·MM-dd HH:mm)과 생활 분기 생산식이 현재 문화권을 따르므로 실사용 문화권 ko-KR 로 고정해 돌리고 끝에서 되돌립니다.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# Invoke-NextCycleDecision 의 준비 실행 3회 연속 갈래가 [System.Drawing.Color]::Firebrick 을 씁니다 (설계 S4)
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$fails = 0
$originalCulture = [Threading.Thread]::CurrentThread.CurrentCulture
$baselineCulture = [Globalization.CultureInfo]::GetCultureInfo('ko-KR')
[Threading.Thread]::CurrentThread.CurrentCulture = $baselineCulture
# T4-h·P2 가 이 프로세스의 UNTIL·추정치 환경 변수를 직접 씁니다 - 끝에서 원래 값으로 되돌립니다
$originalUntilEnv = $env:HONEYNOGI_UNTIL_TIME
$originalEstimateEnv = $env:HONEYNOGI_CYCLE_ESTIMATE_SEC

# ── 공용 헬퍼 (쓰기 전에 정의 - 파일 머리가 $ErrorActionPreference = 'Stop' 이라 정의 전 호출은 파일 전체를 멈춤, 설계 리뷰 1차 P3 과 같은 이유) ──
function Assert-Case {
  # 글자까지 같아야 통과합니다(-ceq) - 문구 진리표가 앞뒤 공백까지 보게 (기본 -eq 는 대소문자를 무시)
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -ceq "$Expect") { "OK   {0}: [{1}]" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}
function Remove-CommentsByTokens {
  # 주석 토큰을 같은 길이의 공백으로 바꾼 사본 (줄바꿈 보존 - 오프셋이 원문과 같아 AST 범위로 잘라 쓸 수 있습니다).
  # 원문(주석 포함) 단언은 옛 코드가 주석에만 남아도 통과하므로 배선 단언은 전부 이 사본으로 합니다 (설계 8.5).
  # 토큰을 한 번에 이어 붙이는 방식이라 600KB 인 GUI 에서도 빠릅니다 (test_abyss_party_member 와 같은 구현)
  param([string]$Text, $Tokens)
  $builder = New-Object System.Text.StringBuilder ($Text.Length)
  $position = 0
  foreach ($token in $Tokens) {
    if ($token.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment) { continue }
    [void]$builder.Append($Text, $position, $token.Extent.StartOffset - $position)
    [void]$builder.Append(($token.Text -replace '[^\r\n]', ' '))
    $position = $token.Extent.EndOffset
  }
  [void]$builder.Append($Text, $position, $Text.Length - $position)
  return $builder.ToString()
}
function Get-TextCount {
  # 원문 조각(정규식 아님)의 출현 수
  param([string]$Text, [string]$Literal)
  return [regex]::Matches($Text, [regex]::Escape($Literal)).Count
}
function New-SequencePattern {
  # 원문 조각을 순서대로 잇는 정규식 - 조각 사이에는 공백·줄바꿈만 허용합니다 (주석 뺀 사본에서 주석 자리는 공백).
  # 조각은 원문 그대로 적고 이스케이프는 여기서 합니다 - 손으로 이스케이프하다 틀린 정규식이 '아무것도 안 지키는' 단언이 되는 것을 막음
  param([string[]]$Parts)
  return (@($Parts | ForEach-Object { [regex]::Escape($_) }) -join '\s*')
}
function Get-PatternCount {
  param([string]$Text, [string]$Pattern)
  return [regex]::Matches($Text, $Pattern).Count
}
function Get-EnclosingFunctionName {
  # AST 노드를 감싼 함수 이름 ('' = 함수 밖 - 타이머·버튼 처리기 스크립트블록)
  param($Node)
  $parent = $Node.Parent
  while ($null -ne $parent) {
    if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $parent.Name }
    $parent = $parent.Parent
  }
  return ''
}
function Get-CommandCalls {
  # 이름이 같은 명령 호출(CommandAst) 전부 - 주석·문자열·함수 정의 이름은 세지 않습니다 (이름 텍스트로 세면 주석과 정의가 섞임)
  param($Ast, [string]$Name)
  return $Ast.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq $Name) }, $true)
}
function Get-CallOwners {
  # 그 명령을 부르는 곳(감싼 함수 이름)을 '개수|이름,이름' 으로 - 함수 밖(타이머·버튼 처리기)은 '(함수 밖)'.
  # 이름은 서수(ordinal)로 정렬합니다 - 문화권 정렬은 기호·하이픈 처리가 문화권마다 달라 기대 문자열이 흔들릴 수 있음
  param($Ast, [string]$Name)
  $calls = @(Get-CommandCalls $Ast $Name)
  [string[]]$owners = @($calls | ForEach-Object { $owner = Get-EnclosingFunctionName $_; if ($owner -eq '') { '(함수 밖)' } else { $owner } })
  [Array]::Sort($owners, [StringComparer]::Ordinal)
  return ('{0}|{1}' -f $calls.Count, ($owners -join ','))
}
function Format-Moment {
  # 시각 비교용 문자열 - 문화권을 바꿔 가며 도는 P2 에서도 같은 글자가 나오게 InvariantCulture 로 씁니다
  param($Value)
  if ($null -eq $Value) { return '(없음)' }
  return ([datetime]$Value).ToString('yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture)
}
function Invoke-Guarded {
  # 예외를 FAIL 로 보이게 문자열로 바꿉니다 - 한 행의 예외가 파일 전체를 멈춰 뒤 단언이 하나도 안 도는 것을 막음
  param([scriptblock]$Body)
  try { return (& $Body) } catch { return ('예외: ' + $_.Exception.Message) }
}

# ── 소스 추출 (사본 금지 - 운영 함수를 그대로 올립니다) ──────────────────────────
foreach ($definition in Get-SourceFunctionDefinitions -Path $guiPath -Names @('Get-NextCycleAction', 'Invoke-NextCycleDecision',
    'Test-TimeAllowsNextCycle', 'Get-CycleWaitSecondsForEstimate', 'Test-WorkerTimeJudgeActive', 'Test-AbyssMemberRunActive',
    'Get-TimeStartNotice', 'Get-TimeStatusSuffix', 'Get-TimeStopNotice')) {
  Invoke-Expression $definition
}
# P2 왕복의 받는 쪽 - 워커의 실제 파서(InvariantCulture 고정 형식)와 던전·파티원 시간 판단 함수
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-LifeUntilDeadline', 'Get-DgTimeVerdict', 'Get-AbyssMemberStopReason')) {
  Invoke-Expression $definition
}
$guiTokens = $null; $guiErrors = $null
$guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$guiErrors)
if ($guiErrors.Count -gt 0) { throw "GUI 파서 오류: $($guiErrors[0].Message)" }
$guiCode = Remove-CommentsByTokens $guiAst.Extent.Text $guiTokens
# 주석 뺀 사본은 원문과 길이·오프셋이 같아야 AST 범위로 자를 수 있습니다 (어긋나면 아래 함수 범위 단언이 엉뚱한 곳을 봄)
Assert-Case '준비: 주석 뺀 GUI 사본의 길이·시작 오프셋이 원문과 같음' ('{0}/{1}' -f [int]($guiCode.Length -eq $guiAst.Extent.Text.Length), $guiAst.Extent.StartOffset) '1/0'
function Get-GuiFunctionAst {
  # GUI 함수 정의 AST (정확히 1개가 아니면 throw - 이름이 바뀌거나 겹친 것 자체가 결함)
  param([string]$Name)
  $found = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $Name) }, $true))
  if ($found.Count -ne 1) { throw "GUI 함수 '$Name' 정의가 1개가 아닙니다 ($($found.Count)개)" }
  return $found[0]
}
function Get-GuiFunctionCode {
  # 주석 뺀 GUI 사본에서 그 함수 범위만 잘라냅니다
  param([string]$Name)
  $functionAst = Get-GuiFunctionAst $Name
  return $guiCode.Substring($functionAst.Extent.StartOffset, $functionAst.Extent.EndOffset - $functionAst.Extent.StartOffset)
}

# ── 모의 (GUI 컨트롤·시각·부수 효과) ─────────────────────────────────────────────
$script:fakeNow = [datetime]::new(2026, 10, 1, 21, 20, 0)
$script:fakeNowQueue = New-Object System.Collections.Queue   # 값이 있으면 Get-Date 가 차례로 꺼내 씀 (정각 직전 [시작] 경합 행 - T4-g g2)
function Get-Date {
  # 시각 모의 - GUI 판단 함수는 반드시 Get-Date 로 시각을 읽습니다(그 함수 주석의 계약). 고급 함수라 인자(-Format 등)가 오면 오류로 드러납니다
  [CmdletBinding()]
  param()
  if ($script:fakeNowQueue.Count -gt 0) { return [datetime]$script:fakeNowQueue.Dequeue() }
  return $script:fakeNow
}
$numGatherWait = [pscustomobject]@{ Value = 600 }   # 생활 '진행 없음' 한도 (설계 T4 의 600 그대로)
$numClearWait = [pscustomobject]@{ Value = 900 }    # 전투 '클리어 대기' - 일부러 생활 값과 다르게 둡니다 (두 칸을 바꿔 읽는 변이를 잡기 위해)
$lblStatus = [pscustomobject]@{ Text = ''; ForeColor = $null }
$dtpUntil = [pscustomobject]@{ Value = [datetime]::new(2000, 1, 1, 21, 20, 0) }   # 시각 선택기 - 날짜는 무시되고 시·분(·숨은 초)만 쓰임
$rbCatAbyss = [pscustomobject]@{ Checked = $false }
$rbCatDungeon = [pscustomobject]@{ Checked = $true }
$rbCatDeep = [pscustomobject]@{ Checked = $false }
$rbCatHunting = [pscustomobject]@{ Checked = $false }
$rbModeSolo = [pscustomobject]@{ Checked = $true }
$rbModeParty = [pscustomobject]@{ Checked = $false }
$rbAbyssChance = [pscustomobject]@{ Checked = $true }
$rbAbyssFindParty = [pscustomobject]@{ Checked = $false }
$rbAbyssPartyLead = [pscustomobject]@{ Checked = $false }
$rbAbyssPartyMember = [pscustomobject]@{ Checked = $false }
function Set-RadioModel {
  # 전투 라디오 3그룹(콘텐츠·어비스 모드·어비스 매칭)을 실제처럼 그룹마다 하나만 켭니다 - 같은 패널끼리 배타입니다.
  # 대분류($script:mainCategory)는 따로 둡니다: 생활·기타로 바꿔도 전투 라디오의 Checked 는 복귀 대비로 보존되므로
  # '대분류 생활 + 던전 라디오 켜짐' 같은 보존 상태를 그대로 만들 수 있어야 합니다 (설계 회귀 R-3)
  param(
    [ValidateSet('abyss', 'dungeon', 'deep', 'hunting')][string]$Content,
    [ValidateSet('solo', 'party')][string]$Mode = 'solo',
    [ValidateSet('chance', 'find', 'lead', 'member')][string]$Matching = 'chance'
  )
  $rbCatAbyss.Checked = ($Content -eq 'abyss')
  $rbCatDungeon.Checked = ($Content -eq 'dungeon')
  $rbCatDeep.Checked = ($Content -eq 'deep')
  $rbCatHunting.Checked = ($Content -eq 'hunting')
  $rbModeSolo.Checked = ($Mode -eq 'solo')
  $rbModeParty.Checked = ($Mode -eq 'party')
  $rbAbyssChance.Checked = ($Matching -eq 'chance')
  $rbAbyssFindParty.Checked = ($Matching -eq 'find')
  $rbAbyssPartyLead.Checked = ($Matching -eq 'lead')
  $rbAbyssPartyMember.Checked = ($Matching -eq 'member')
}
function Stop-AllRun {
  # GUI Stop-AllRun 과 같은 서명. 호출 기록만 남기고, 호출부가 기대는 상태 변화 두 가지만 흉내 냅니다 -
  #  ① 목표 시각을 지움 (그래서 정지 문구의 HH:mm 는 정지 전에 만들어야 함)
  #  ② 상태줄 색을 회색으로 바꿈 (그래서 오류 정지의 빨강은 정지 뒤에 칠해야 남음 - 준비 실행 3회 연속 갈래)
  param([string]$Reason, [switch]$IsError)
  $script:actions += ('stop|{0}|{1}' -f $Reason, [bool]$IsError)
  $script:stopRequested = $false
  $script:targetTime = $null
  $lblStatus.ForeColor = [System.Drawing.Color]::DimGray
}
function Start-NextCycle { $script:actions += 'next' }
function Add-GuiLog { param([string]$Message) $script:guiLogs += $Message }
function Write-RunLog { param($Message) $script:runLogs += [string]$Message }   # 워커 파서의 형식 오류 경고 1줄이 여기로 옴
function Reset-GuiState {
  # 행마다 GUI 상태를 기본값(전투 · 던전 · 시간 지정 아님 · 비커스텀)으로 되돌립니다
  $script:actions = @()
  $script:guiLogs = @()
  $script:runLogs = @()
  $script:targetTime = $null
  $script:mainCategory = 'battle'
  $script:stopRequested = $false
  $script:targetCycles = 0
  $script:completedCycles = 0
  $script:preparedStreak = 0
  $script:customActive = $false
  $script:fakeNowQueue.Clear()
  $lblStatus.ForeColor = $null
  Set-RadioModel -Content 'dungeon'
}
function Get-ColorLabel {
  # 실행 함수가 끝난 뒤 상태줄 색 (모의 정지가 회색으로 칠하므로 '색 그대로' = 정지가 없었음)
  if ($null -eq $lblStatus.ForeColor) { return '색 그대로' }
  return [string]$lblStatus.ForeColor.Name
}
function Get-ParamSignature {
  # 함수 정의의 매개변수 서명 '타입 $이름, …' - 모의와 실제를 같은 방식으로 뽑아 비교합니다
  param($Ast, [string]$Name)
  $functionAst = @($Ast.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $Name) }, $true)) | Select-Object -First 1
  if ($null -eq $functionAst) { return '(정의 없음)' }
  $paramBlock = $functionAst.Body.ParamBlock
  if ($null -eq $paramBlock) { return '(매개변수 없음)' }
  return (@($paramBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}
# 모의 서명 대조 - 모의가 실제 함수와 같은 서명이어야 실행 함수의 호출 모양(-IsError 스위치 + 위치 인자 사유)이 실제와 같게 묶입니다.
# 실제 함수의 서명이 바뀌면 여기서 먼저 드러납니다 (모의를 사본처럼 방치하지 않게)
$selfAst = [System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$null, [ref]$null)
foreach ($mockName in @('Stop-AllRun', 'Start-NextCycle', 'Add-GuiLog')) {
  Assert-Case "준비: 모의 $mockName 서명 = GUI 실제 서명" (Get-ParamSignature $selfAst $mockName) (Get-ParamSignature $guiAst $mockName)
}

$baseTarget = [datetime]::new(2026, 10, 1, 21, 20, 0)   # 지정 시각 T (설계 8.2 의 21:20)
$gatherLimit = [int]$numGatherWait.Value
$clearLimit = [int]$numClearWait.Value
$stopNoticeBattle = '지정 시간(21:20) 이후라 새 판을 시작하지 않습니다.'
$stopNoticeLife = '지정 시간(21:20)까지 남은 시간이 부족해 다음 회차를 시작하지 않습니다.'
$startNoticeBattle = '시간 지정 모드: 10-01 21:20 지나면 새 판을 시작하지 않습니다 - 그 전에 시작한 판은 끝까지 하고 멈춥니다.'
$startNoticeLife = '시간 지정 모드: 10-01 21:20 까지 반복합니다.'

# ── T4-a 다음 회차 판단 순수부 Get-NextCycleAction ────────────────────────────────
$t4aRows = @(
  @{ N = 1; Code = 0; Stop = $false; Reached = $false; Streak = 0; TimeOk = $true; X = 'next'; Why = '' }
  @{ N = 2; Code = 0; Stop = $false; Reached = $false; Streak = 0; TimeOk = $false; X = 'time'; Why = '' }
  @{ N = 3; Code = 11; Stop = $false; Reached = $false; Streak = 0; TimeOk = $false; X = 'next'; Why = ' - 조건 4 핵심: 이어 간 판은 지정 시각을 보지 않고 이어받음' }
  @{ N = 4; Code = 11; Stop = $true; Reached = $false; Streak = 0; TimeOk = $false; X = 'safe-stop'; Why = ' - 안전 중지는 11 보다 이김 (10-02 결정 Q4)' }
  @{ N = 5; Code = 11; Stop = $false; Reached = $true; Streak = 0; TimeOk = $false; X = 'count'; Why = ' - 순서 완결' }
  @{ N = 6; Code = 0; Stop = $true; Reached = $true; Streak = 0; TimeOk = $false; X = 'safe-stop'; Why = '' }
  @{ N = 7; Code = 0; Stop = $false; Reached = $true; Streak = 0; TimeOk = $false; X = 'count'; Why = '' }
  @{ N = 8; Code = 10; Stop = $false; Reached = $false; Streak = 2; TimeOk = $true; X = 'next'; Why = '' }
  @{ N = 9; Code = 10; Stop = $false; Reached = $false; Streak = 3; TimeOk = $true; X = 'prepared-streak'; Why = '' }
  @{ N = 10; Code = 10; Stop = $false; Reached = $false; Streak = 0; TimeOk = $false; X = 'time'; Why = '' }
  @{ N = 11; Code = 10; Stop = $true; Reached = $false; Streak = 3; TimeOk = $false; X = 'safe-stop'; Why = '' }
  @{ N = 12; Code = 10; Stop = $false; Reached = $true; Streak = 0; TimeOk = $true; X = 'next'; Why = ' - 코드 10 은 회차로 세지 않아 지정 횟수를 보지 않음' }
  @{ N = 13; Code = 11; Stop = $false; Reached = $false; Streak = 0; TimeOk = $true; X = 'next'; Why = '' }
)
$t4aRun = 0
foreach ($row in $t4aRows) {
  $rowName = 'T4-a {0}: 코드 {1} · 안전 중지 {2} · 횟수 도달 {3} · 준비 실행 연속 {4} · 시간 허용 {5}{6}' -f $row.N, $row.Code, $row.Stop, $row.Reached, $row.Streak, $row.TimeOk, $row.Why
  Assert-Case $rowName (Invoke-Guarded { Get-NextCycleAction -ExitCode $row.Code -StopRequested $row.Stop -ReachedTarget $row.Reached -PreparedStreak $row.Streak -TimeAllows $row.TimeOk }) $row.X
  $t4aRun++
}

# ── T4-b 시간 판단 Test-TimeAllowsNextCycle ───────────────────────────────────────
$t4bRows = @(
  @{ N = '1a'; D = '지정 시각 없음 · 전투'; Cat = 'battle'; Target = $null; Now = $baseTarget; X = $true }
  @{ N = '1b'; D = '지정 시각 없음 · 생활'; Cat = 'life'; Target = $null; Now = $baseTarget; X = $true }
  @{ N = '1c'; D = '지정 시각 없음 · 기타'; Cat = 'etc'; Target = $null; Now = $baseTarget; X = $true }
  @{ N = '2'; D = '전투 · 지정 1초 전 (옛 식이면 거짓 - 클리어 대기 추정치를 다시 넣는 변이를 잡음)'; Cat = 'battle'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-1); X = $true }
  @{ N = '3'; D = '전투 · 지정 시각과 같음 (같은 시각 포함 - 새 판 없음)'; Cat = 'battle'; Target = $baseTarget; Now = $baseTarget; X = $false }
  @{ N = '4'; D = '전투 · 지정 1초 뒤'; Cat = 'battle'; Target = $baseTarget; Now = $baseTarget.AddSeconds(1); X = $false }
  @{ N = '5'; D = "생활 · 지정 $($gatherLimit + 1)초 전 (T5)"; Cat = 'life'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-($gatherLimit + 1)); X = $true }
  @{ N = '6'; D = "생활 · 지정 ${gatherLimit}초 전 (<= - T5)"; Cat = 'life'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-$gatherLimit); X = $true }
  @{ N = '7'; D = "생활 · 지정 $($gatherLimit - 1)초 전 (T5)"; Cat = 'life'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-($gatherLimit - 1)); X = $false }
  @{ N = '8'; D = "기타 · 지정 $($clearLimit + 1)초 전 (클리어 대기 ${clearLimit} - 옛 식 그대로)"; Cat = 'etc'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-($clearLimit + 1)); X = $true }
  @{ N = '9'; D = "기타 · 지정 $($clearLimit - 1)초 전 (해당 없음 - 옛 식 그대로 거짓)"; Cat = 'etc'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-($clearLimit - 1)); X = $false }
)
$t4bRun = 0
foreach ($row in $t4bRows) {
  Reset-GuiState
  $script:mainCategory = $row.Cat
  $script:targetTime = $row.Target
  $script:fakeNow = $row.Now
  Assert-Case ('T4-b {0}: {1}' -f $row.N, $row.D) (Invoke-Guarded { Test-TimeAllowsNextCycle }) $row.X
  $t4bRun++
}

# ── T4-c UNTIL 을 받는 워커 판정 Test-WorkerTimeJudgeActive (보존된 전투 라디오 모형화) ──
$t4cRows = @(
  @{ N = 1; D = 'battle · 던전'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; X = $true }
  @{ N = 2; D = 'battle · 심층'; Cat = 'battle'; Content = 'deep'; Mode = 'solo'; Matching = 'chance'; Custom = $false; X = $true }
  @{ N = 3; D = 'battle · 어비스 + 함께하기 + 파티원 · 비커스텀'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; X = $true }
  @{ N = 4; D = 'battle · 어비스 혼자하기 (매칭 라디오는 파티원으로 보존)'; Cat = 'battle'; Content = 'abyss'; Mode = 'solo'; Matching = 'member'; Custom = $false; X = $false }
  @{ N = 5; D = 'battle · 어비스 + 함께하기 + 파티장'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'lead'; Custom = $false; X = $false }
  @{ N = 6; D = 'battle · 사냥터'; Cat = 'battle'; Content = 'hunting'; Mode = 'solo'; Matching = 'chance'; Custom = $false; X = $false }
  @{ N = 7; D = 'battle · 던전 · 커스텀'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $true; X = $false }
  @{ N = 8; D = 'life · 던전 라디오 켜짐(보존)'; Cat = 'life'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; X = $false }
  @{ N = 9; D = 'etc · 던전 라디오 켜짐(보존)'; Cat = 'etc'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; X = $false }
  @{ N = 10; D = 'life · 어비스 + 함께하기 + 파티원 라디오 모두 켜짐(보존)'; Cat = 'life'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; X = $false }
  @{ N = 11; D = 'etc · 어비스 + 함께하기 + 파티원 라디오 모두 켜짐(보존)'; Cat = 'etc'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; X = $false }
)
$t4cRun = 0
foreach ($row in $t4cRows) {
  Reset-GuiState
  $script:mainCategory = $row.Cat
  Set-RadioModel -Content $row.Content -Mode $row.Mode -Matching $row.Matching
  $script:customActive = $row.Custom
  Assert-Case ('T4-c {0}: {1}' -f $row.N, $row.D) (Invoke-Guarded { Test-WorkerTimeJudgeActive }) $row.X
  $t4cRun++
}

# ── T4-d 문구 보조 함수 (지정 시각 2026-10-01 21:20) ──────────────────────────────
Assert-Case 'T4-d 정지 안내 · battle' (Invoke-Guarded { Get-TimeStopNotice -TargetText '21:20' -MainCategory 'battle' }) $stopNoticeBattle
Assert-Case 'T4-d 정지 안내 · life (옛 문구 그대로 - T5)' (Invoke-Guarded { Get-TimeStopNotice -TargetText '21:20' -MainCategory 'life' }) $stopNoticeLife
Assert-Case 'T4-d 정지 안내 · etc (생활과 같음)' (Invoke-Guarded { Get-TimeStopNotice -TargetText '21:20' -MainCategory 'etc' }) $stopNoticeLife
Assert-Case 'T4-d 상태줄 꼬리 · battle' (Invoke-Guarded { Get-TimeStatusSuffix -TargetTime $baseTarget -MainCategory 'battle' }) ' (21:20 지나면 그 판까지)'
Assert-Case 'T4-d 상태줄 꼬리 · life (옛 꼬리 그대로 - T5)' (Invoke-Guarded { Get-TimeStatusSuffix -TargetTime $baseTarget -MainCategory 'life' }) ' (21:20 까지)'
Assert-Case 'T4-d 상태줄 꼬리 · etc (생활과 같음)' (Invoke-Guarded { Get-TimeStatusSuffix -TargetTime $baseTarget -MainCategory 'etc' }) ' (21:20 까지)'
Assert-Case 'T4-d 상태줄 꼬리 · 지정 시각 $null (타입 없는 인자 - [datetime] 이면 변환 오류)' (Invoke-Guarded { Get-TimeStatusSuffix -TargetTime $null -MainCategory 'battle' }) ''
Assert-Case 'T4-d 상태줄 꼬리 · 지정 시각 인자 생략' (Invoke-Guarded { Get-TimeStatusSuffix -MainCategory 'life' }) ''
Assert-Case 'T4-d 시작 로그 · battle' (Invoke-Guarded { Get-TimeStartNotice -TargetTime $baseTarget -MainCategory 'battle' }) $startNoticeBattle
Assert-Case 'T4-d 시작 로그 · life (옛 문구 그대로 - T5)' (Invoke-Guarded { Get-TimeStartNotice -TargetTime $baseTarget -MainCategory 'life' }) $startNoticeLife
Assert-Case 'T4-d 시작 로그 · etc (생활과 같음)' (Invoke-Guarded { Get-TimeStartNotice -TargetTime $baseTarget -MainCategory 'etc' }) $startNoticeLife

# ── T4-e 배선 (주석 뺀 GUI 사본) ──────────────────────────────────────────────────
$decisionCode = Get-GuiFunctionCode 'Invoke-NextCycleDecision'
$stopNoticeCode = Get-GuiFunctionCode 'Get-TimeStopNotice'
$startNoticeCode = Get-GuiFunctionCode 'Get-TimeStartNotice'
$judgeActiveCode = Get-GuiFunctionCode 'Test-WorkerTimeJudgeActive'
$nextCycleCode = Get-GuiFunctionCode 'Start-NextCycle'
$startAutomationCode = Get-GuiFunctionCode 'Invoke-StartAutomation'

# 1. 바깥 조건 - 11 을 빼면 11 이 그 밖 코드 사슬(오류 정지)로 갑니다 (변이 G8)
Assert-Case 'T4-e 1: 타이머 바깥 조건이 코드 0 과 11 을 같은 갈래로 받음' (Get-TextCount $guiCode 'if (($exitCode -eq 0) -or ($exitCode -eq 11)) {') 1

# 2. 실행 함수 호출 두 곳 - 타이머에 남은 것은 이 호출 한 줄씩뿐입니다 (0 고정 변이 G14)
Assert-Case 'T4-e 2: 실행 함수 호출 = 원문 2곳 · 호출 2개가 둘 다 함수 밖(타이머 스크립트블록)' ('{0} · {1}' -f (Get-TextCount $guiCode 'Invoke-NextCycleDecision -ExitCode $exitCode'), (Get-CallOwners $guiAst 'Invoke-NextCycleDecision')) '2 · 2|(함수 밖),(함수 밖)'
Assert-Case 'T4-e 2a: 코드 0·11 의 비커스텀 꼬리 = 실행 함수 한 줄 (바로 뒤가 코드 10 갈래)' (Get-PatternCount $guiCode (New-SequencePattern @('} else {', 'Invoke-NextCycleDecision -ExitCode $exitCode', '}', '} elseif ($exitCode -eq 10) {'))) 1
Assert-Case 'T4-e 2b: 코드 10 꼬리 = 커스텀 PREV 정리 뒤 실행 함수 한 줄 (바로 뒤가 코드 2 갈래)' (Get-PatternCount $guiCode (New-SequencePattern @('$script:customRestart = $false', '}', 'Invoke-NextCycleDecision -ExitCode $exitCode', '} elseif ($exitCode -eq 2) {'))) 1

# 3. 완료 줄 - 실기에서 워커 11 → 호스트 → GUI 수신을 이 줄로 봅니다 (설계 9.1·9.2). 원문 + 소스 그대로 실행
Assert-Case 'T4-e 3: 완료 줄 꼬리는 변수에 먼저 담음(PS 5.1 파서 함정 S2) · 완료 줄 1곳' ('{0}/{1}' -f (Get-TextCount $guiCode '$cycleDoneSuffix = $(if ($exitCode -eq 11) { '' (다음 판으로 이어 감)'' } else { '''' })'), (Get-TextCount $guiCode 'Add-GuiLog "=== $($script:completedCycles)회차 완료$cycleDoneSuffix ==="')) '1/1'
$doneLineBlock = $null
$suffixAssigns = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$cycleDoneSuffix') }, $true))
if ($suffixAssigns.Count -eq 1) {
  $doneParent = $suffixAssigns[0].Parent
  $doneIndex = $doneParent.Statements.IndexOf($suffixAssigns[0])
  if (($doneIndex -ge 0) -and ($doneIndex + 1 -lt $doneParent.Statements.Count)) {
    $doneLineBlock = [scriptblock]::Create($suffixAssigns[0].Extent.Text + "`n" + $doneParent.Statements[$doneIndex + 1].Extent.Text)
  }
}
function Invoke-DoneLine {
  # 타이머의 완료 줄 두 문장(꼬리 대입 + Add-GuiLog)을 소스 그대로 실행합니다 - 점소싱이라 $exitCode 는 이 함수의 매개변수로 보임
  param([int]$exitCode)
  . $doneLineBlock
}
if ($null -eq $doneLineBlock) {
  'FAIL T4-e 3 행동: 완료 줄 문장($cycleDoneSuffix 대입 + 다음 문장)을 AST 에서 찾지 못했습니다'; $fails++
} else {
  Reset-GuiState
  $script:completedCycles = 3
  Invoke-DoneLine -exitCode 11
  Invoke-DoneLine -exitCode 0
  Assert-Case 'T4-e 3 행동: 코드 11 / 0 의 완료 줄 (11 만 꼬리)' ($script:guiLogs -join ' / ') '=== 3회차 완료 (다음 판으로 이어 감) === / === 3회차 완료 ==='
}

# 4. 옛 사슬의 리터럴은 실행 함수·문구 함수 안에만 (타이머에 직접 남으면 그 갈래는 새 판단을 타지 않음 - 변이 G15)
$chainLiterals = @(
  @{ L = "Stop-AllRun '지정 횟수 완료'"; F = 'Invoke-NextCycleDecision'; C = $decisionCode }
  @{ L = "'준비 실행(화면 복귀)이 3회 연속 반복"; F = 'Invoke-NextCycleDecision'; C = $decisionCode }
  @{ L = 'Stop-AllRun "지정 시간($targetText) 도달"'; F = 'Invoke-NextCycleDecision'; C = $decisionCode }
  @{ L = '남은 시간이 부족해 다음 회차를 시작하지 않습니다'; F = 'Get-TimeStopNotice'; C = $stopNoticeCode }
  @{ L = '까지 반복합니다'; F = 'Get-TimeStartNotice'; C = $startNoticeCode }
)
foreach ($item in $chainLiterals) {
  Assert-Case ('T4-e 4: 리터럴 [{0}] 은 GUI 전체 1곳이고 {1} 안' -f $item.L, $item.F) ('{0}/{1}' -f (Get-TextCount $guiCode $item.L), (Get-TextCount $item.C $item.L)) '1/1'
}
$noticeOwners = '{0} / {1} / {2}' -f (Get-CallOwners $guiAst 'Get-TimeStopNotice'), (Get-CallOwners $guiAst 'Get-TimeStartNotice'), (Get-CallOwners $guiAst 'Get-TimeStatusSuffix')
Assert-Case 'T4-e 4: 문구 함수 호출 위치 - 정지 안내는 실행 함수, 시작 로그는 시작 처리, 상태줄 꼬리는 안전 중지 버튼 처리기(함수 밖)·회차 시작' $noticeOwners '1|Invoke-NextCycleDecision / 1|Invoke-StartAutomation / 2|(함수 밖),Start-NextCycle'

# 5. 판단 함수에 넘기는 인자 - -ExitCode 누락이면 11 이 0 이 되고, -TimeAllows $true 고정이면 전투 시간 지정이 영영 안 멈춤 (변이 G10·G11)
$actionCalls = @(Get-CommandCalls $guiAst 'Get-NextCycleAction')
$actionCallText = $(if ($actionCalls.Count -ge 1) { ($actionCalls[0].Extent.Text -replace '\s+', ' ').Trim() } else { '' })
$actionCallOwner = $(if ($actionCalls.Count -ge 1) { Get-EnclosingFunctionName $actionCalls[0] } else { '' })
Assert-Case 'T4-e 5: 판단 함수 호출은 GUI 전체 1곳(실행 함수 안) · 인자 원문(공백 정규화)' ('{0}|{1}|{2}' -f $actionCalls.Count, $actionCallOwner, $actionCallText) '1|Invoke-NextCycleDecision|Get-NextCycleAction -ExitCode $ExitCode -StopRequested $script:stopRequested -ReachedTarget $reachedTarget -PreparedStreak $script:preparedStreak -TimeAllows $timeAllows'

# 6. 시작 게이트 - 생활·기타만 거부(문구 원문 그대로), 전투는 게이트를 타지 않음 (변이 G6)
$gateLine = 'if (($script:mainCategory -ne ''battle'') -and (-not (Test-TimeAllowsNextCycle))) {'
$labelLine = '$estimateLabel = $(if ($script:mainCategory -eq ''life'') { ''진행 없음 한도'' } else { ''클리어 대기'' })'
$refuseLine = 'Add-GuiLog "[안내] 지정 시간($($script:targetTime.ToString(''HH:mm'')))까지 남은 시간이 ${estimateLabel}($(Get-CycleWaitSecondsForEstimate)초)보다 짧아 시작할 수 없습니다."'
$startNoticeLine = 'Add-GuiLog (Get-TimeStartNotice -TargetTime $script:targetTime -MainCategory $script:mainCategory)'
Assert-Case 'T4-e 6: 시작 게이트·거부 라벨·거부 문구(원문)·시작 로그 호출이 GUI 전체에 1곳씩' ('{0}/{1}/{2}/{3}' -f (Get-TextCount $guiCode $gateLine), (Get-TextCount $guiCode $labelLine), (Get-TextCount $guiCode $refuseLine), (Get-TextCount $guiCode $startNoticeLine)) '1/1/1/1'
Assert-Case 'T4-e 6: 게이트 → 라벨 → 거부 → 목표 시각 해제 → return → 시작 로그 순서로 붙어 있음 (Invoke-StartAutomation 안)' (Get-PatternCount $startAutomationCode (New-SequencePattern @($gateLine, $labelLine, $refuseLine, '$script:targetTime = $null', 'return', '}', $startNoticeLine))) 1

# 7. 시간 판단 호출 위치
Assert-Case 'T4-e 7: 시간 판단 호출 2곳 = 실행 함수 · 시작 게이트' (Get-CallOwners $guiAst 'Test-TimeAllowsNextCycle') '2|Invoke-NextCycleDecision,Invoke-StartAutomation'

# 8. UNTIL 전달 - 매 회차 먼저 비우고, 생활 분기는 원문 그대로, 전투 분기는 판단 워커만 + InvariantCulture 생산 (변이 G9·P2)
$envPattern = New-SequencePattern @(
  '$env:HONEYNOGI_UNTIL_TIME = ''''',
  'if (($null -ne $script:targetTime) -and ($script:mainCategory -eq ''life'')) {',
  '$env:HONEYNOGI_UNTIL_TIME = $script:targetTime.ToString(''yyyy-MM-dd HH:mm'')',
  '}',
  'if (($null -ne $script:targetTime) -and (Test-WorkerTimeJudgeActive)) {',
  '$env:HONEYNOGI_UNTIL_TIME = $script:targetTime.ToString(''yyyy-MM-dd HH:mm'', [Globalization.CultureInfo]::InvariantCulture)',
  '}')
Assert-Case 'T4-e 8: Start-NextCycle 의 UNTIL - 비움 → 생활 분기(원문) → 전투 분기(판단 워커만, InvariantCulture 생산 - 리뷰 P2)' (Get-PatternCount $nextCycleCode $envPattern) 1
Assert-Case 'T4-e 8: UNTIL 대입은 GUI 전체에 이 세 곳뿐 · 사이클 추정치 env 0건 (설정·비움 모두 삭제)' ('{0}/{1}' -f (Get-TextCount $guiCode '$env:HONEYNOGI_UNTIL_TIME ='), (Get-TextCount $guiCode 'HONEYNOGI_CYCLE_ESTIMATE_SEC')) '3/0'
Assert-Case 'T4-e 8: 판단 워커 판정 호출은 Start-NextCycle 1곳' (Get-CallOwners $guiAst 'Test-WorkerTimeJudgeActive') '1|Start-NextCycle'

# 9. 상태줄 꼬리 - 두 곳 모두 대분류별 문구 함수 (옛 꼬리 코드가 남으면 전투에 옛 문구)
$suffixCallLine = '$statusSuffix = Get-TimeStatusSuffix -TargetTime $script:targetTime -MainCategory $script:mainCategory'
Assert-Case 'T4-e 9: 상태줄 꼬리 호출 원문 2곳 · 옛 꼬리 코드 0건' ('{0}/{1}' -f (Get-TextCount $guiCode 'Get-TimeStatusSuffix -TargetTime $script:targetTime -MainCategory $script:mainCategory'), (Get-TextCount $guiCode '" ($($script:targetTime.ToString(''HH:mm'')) 까지)"')) '2/0'
Assert-Case 'T4-e 9: 회차 시작 상태줄이 꼬리 변수를 씀 (Start-NextCycle)' (Get-PatternCount $nextCycleCode (New-SequencePattern @($suffixCallLine, '$lblStatus.Text = "${cycleNumber}회차 실행 중...$statusSuffix"'))) 1
Assert-Case 'T4-e 9: 안전 중지 취소 상태줄도 같은 함수 (버튼 처리기)' (Get-PatternCount $guiCode (New-SequencePattern @($suffixCallLine, '$lblStatus.Text = "$($script:completedCycles + 1)회차 실행 중...$statusSuffix (안전 중지 취소됨)"'))) 1

# 10. 설명서 공통 머리말의 '[반복 - 시간 지정]' 문단 - 우변(문자열 결합)을 그대로 평가해 실제 글자로도 봅니다
$manualAssigns = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$manualCommon') }, $true))
$manualRightText = ''
$manualValue = ''
if ($manualAssigns.Count -eq 1) {
  $manualRightText = [string]$manualAssigns[0].Right.Extent.Text
  $manualValue = [string](Invoke-Guarded { Invoke-Expression $manualRightText })
}
Assert-Case 'T4-e 10: 공통 머리말 대입 1곳 · 그 안에 문단 머리 1곳 · GUI 전체(주석 제외)에도 1곳 (생활·기타 설명서에는 없음)' ('{0}/{1}/{2}' -f $manualAssigns.Count, (Get-TextCount $manualRightText '"[반복 - 시간 지정]`n" +'), (Get-TextCount $guiCode '[반복 - 시간 지정]')) '1/1/1'
Assert-Case 'T4-e 10: 문단은 단축키 줄 뒤 · 생활·기타 설명서는 공통 머리말보다 앞에서 반환' ('{0}/{1}' -f [int]($manualValue.IndexOf('(게임 화면에서도 동작합니다)') -ge 0 -and $manualValue.IndexOf('(게임 화면에서도 동작합니다)') -lt $manualValue.IndexOf('[반복 - 시간 지정]')),
    [int](($guiCode.IndexOf("'생활 설명서'") -ge 0) -and ($guiCode.IndexOf("'기타 설명서'") -ge 0) -and ($guiCode.IndexOf("'생활 설명서'") -lt $guiCode.IndexOf('$manualCommon = ')) -and ($guiCode.IndexOf("'기타 설명서'") -lt $guiCode.IndexOf('$manualCommon = ')))) '1/1'
Assert-Case "T4-e 10: 문단 내용 - 규칙·끝 모양·파티원 따라감·내일 처리 줄 있음, '2분'(두 PC 안내 - 10-02 결정 Q1)·'최대 한 판'(이월 예외와 어긋남) 없음" ('{0}/{1}/{2}/{3}/{4}/{5}' -f
    [int]$manualValue.Contains("[반복 - 시간 지정]`n - 지정한 시각이 지나면 새 판을 시작하지 않습니다. 그 전에 시작한 판은`n   끝까지 하고 멈추므로 지정 시각보다 늦게 끝납니다."),
    [int]$manualValue.Contains(" - 멈추는 모습은 횟수 지정의 마지막 판과 같습니다: 던전·심층·파티원은`n   '나가기'로 필드에 나와 멈추고, 어비스 혼자하기·파티장은 선택 화면,`n   사냥터는 첫 화면에서 멈춥니다."),
    [int]$manualValue.Contains(' - 파티원은 파티장이 다음 판을 이미 시작했으면 그 판까지 따라간 뒤 나옵니다.'),
    [int]$manualValue.Contains(' - 오늘 그 시각이 이미 지났으면 내일 그 시각으로 잡습니다.'),
    [int]$manualValue.Contains('2분'), [int]$manualValue.Contains('최대 한 판')) '1/1/1/1/0/0'

# 11. 판단 워커 판정 본문 원문 (설계 2.5)
Assert-Case 'T4-e 11: Test-WorkerTimeJudgeActive 본문 = 전투 · 비커스텀 · (던전 | 심층 | 파티원 실행)' (Get-PatternCount $judgeActiveCode (New-SequencePattern @('return (($script:mainCategory -eq ''battle'') -and (-not $script:customActive) -and', '($rbCatDungeon.Checked -or $rbCatDeep.Checked -or (Test-AbyssMemberRunActive)))'))) 1

# ── T4-f 실행부 Invoke-NextCycleDecision 행동 (지정 시각 21:20) ────────────────────
$noticeCarry = '[안내] 지정 시간(21:20) 전에 워커가 다음 판으로 이어 가기로 정했습니다 - 다음 워커가 이어받아 마무리합니다.'
$stopTime = 'stop|지정 시간(21:20) 도달|False'
$stopCount = 'stop|지정 횟수 완료|False'
$stopSafe = 'stop|안전 중지|False'
$stopStreak = 'stop|준비 실행(화면 복귀)이 3회 연속 반복 - 게임 화면 상태를 확인해 주세요|True'
$colorKept = '색 그대로'
$t4fRows = @(
  @{ N = 1; D = '시간 지정 아님 · 횟수 미달 → 다음'; Code = 0; Stop = $false; Cycles = 0; Done = 1; Streak = 0; Target = $null; Now = $baseTarget; Cat = 'battle'; Act = 'next'; Log = ''; Color = $colorKept }
  @{ N = 2; D = '지정 횟수 도달 → 정지'; Code = 0; Stop = $false; Cycles = 3; Done = 3; Streak = 0; Target = $null; Now = $baseTarget; Cat = 'battle'; Act = $stopCount; Log = ''; Color = 'DimGray' }
  @{ N = 3; D = '안전 중지 + 횟수 도달 → 안전 중지가 이김'; Code = 0; Stop = $true; Cycles = 3; Done = 3; Streak = 0; Target = $null; Now = $baseTarget; Cat = 'battle'; Act = $stopSafe; Log = ''; Color = 'DimGray' }
  @{ N = 4; D = '전투 · 지정 1초 전 → 다음 (클리어 대기 추정치 없음)'; Code = 0; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget.AddSeconds(-1); Cat = 'battle'; Act = 'next'; Log = ''; Color = $colorKept }
  @{ N = 5; D = '전투 · 지정 시각 → 정지 + 전투 안내'; Code = 0; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget; Cat = 'battle'; Act = $stopTime; Log = $stopNoticeBattle; Color = 'DimGray' }
  @{ N = 6; D = '지정 1초 뒤 → 이어받음 + 11 안내 1줄 (조건 4)'; Code = 11; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget.AddSeconds(1); Cat = 'battle'; Act = 'next'; Log = $noticeCarry; Color = $colorKept }
  @{ N = 7; D = '지정 60초 전 → 다음 (안내 없음)'; Code = 11; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget.AddSeconds(-60); Cat = 'battle'; Act = 'next'; Log = ''; Color = $colorKept }
  @{ N = 8; D = '안전 중지 예약 → 안전 중지 (10-02 결정 Q4)'; Code = 11; Stop = $true; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget.AddSeconds(1); Cat = 'battle'; Act = $stopSafe; Log = ''; Color = 'DimGray' }
  @{ N = 9; D = '준비 실행 연속 2 · 지정 60초 전 → 다음'; Code = 10; Stop = $false; Cycles = 0; Done = 2; Streak = 2; Target = $baseTarget; Now = $baseTarget.AddSeconds(-60); Cat = 'battle'; Act = 'next'; Log = ''; Color = $colorKept }
  @{ N = 10; D = '준비 실행 연속 3 → 오류 정지 + 빨강(정지 뒤에 칠해야 남음)'; Code = 10; Stop = $false; Cycles = 0; Done = 2; Streak = 3; Target = $baseTarget; Now = $baseTarget.AddSeconds(-60); Cat = 'battle'; Act = $stopStreak; Log = ''; Color = 'Firebrick' }
  @{ N = 11; D = '지정 시각 → 정지 + 전투 안내 (옛 코드 10 사슬엔 안내 없었음)'; Code = 10; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget; Cat = 'battle'; Act = $stopTime; Log = $stopNoticeBattle; Color = 'DimGray' }
  @{ N = 12; D = '횟수 도달 → 다음 (미계상이라 횟수를 안 봄)'; Code = 10; Stop = $false; Cycles = 3; Done = 3; Streak = 0; Target = $null; Now = $baseTarget; Cat = 'battle'; Act = 'next'; Log = ''; Color = $colorKept }
  @{ N = 13; D = "생활 · 지정 $($gatherLimit - 1)초 전(한도 ${gatherLimit}) → 정지 + 생활 옛 안내 (T5)"; Code = 0; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget.AddSeconds(-($gatherLimit - 1)); Cat = 'life'; Act = $stopTime; Log = $stopNoticeLife; Color = 'DimGray' }
  @{ N = 14; D = "생활 · 지정 ${gatherLimit}초 전 → 다음 (<= - T5)"; Code = 0; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget.AddSeconds(-$gatherLimit); Cat = 'life'; Act = 'next'; Log = ''; Color = $colorKept }
  @{ N = 15; D = '횟수 도달 → 지정 횟수 완료 (순서 완결 - 실제로는 겹치지 않음)'; Code = 11; Stop = $false; Cycles = 3; Done = 3; Streak = 0; Target = $baseTarget; Now = $baseTarget.AddSeconds(1); Cat = 'battle'; Act = $stopCount; Log = ''; Color = 'DimGray' }
)
$t4fRun = 0
foreach ($row in $t4fRows) {
  Reset-GuiState
  $script:stopRequested = $row.Stop
  $script:targetCycles = $row.Cycles
  $script:completedCycles = $row.Done
  $script:preparedStreak = $row.Streak
  $script:targetTime = $row.Target
  $script:fakeNow = $row.Now
  $script:mainCategory = $row.Cat
  try { Invoke-NextCycleDecision -ExitCode $row.Code } catch { $script:actions += ('예외|' + $_.Exception.Message) }
  $actualRecord = '{0} :: 로그[{1}] :: {2}' -f ($script:actions -join ' / '), ($script:guiLogs -join ' / '), (Get-ColorLabel)
  $expectRecord = '{0} :: 로그[{1}] :: {2}' -f $row.Act, $row.Log, $row.Color
  Assert-Case ('T4-f {0}: 코드 {1} · {2}' -f $row.N, $row.Code, $row.D) $actualRecord $expectRecord
  $t4fRun++
}

# ── T4-g 시작 게이트 행동 (Invoke-StartAutomation 의 if ($rbTime.Checked) 블록을 그대로 실행) ──
$timeBlock = $null
$startFunctionAst = Get-GuiFunctionAst 'Invoke-StartAutomation'
$timeIfs = @($startFunctionAst.Body.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq '$rbTime.Checked') }, $true))
Assert-Case 'T4-g 추출: 시작 처리 안의 시간 지정 블록 if ($rbTime.Checked) 1개' $timeIfs.Count 1
if ($timeIfs.Count -eq 1) {
  $timeBlock = [scriptblock]::Create((@($timeIfs[0].Clauses[0].Item2.Statements | ForEach-Object { $_.Extent.Text }) -join "`n"))
}
function Invoke-StartTimeBlock {
  # 시간 지정 블록(목표 시각 계산 → 생활·기타 게이트 → 시작 로그)을 소스 그대로 실행합니다 - 점소싱(규칙 3).
  # 블록 안 return(시작 거부)은 블록만 끝냅니다 - 실제로는 Invoke-StartAutomation 을 끝내 시작하지 않습니다
  if ($null -eq $timeBlock) { throw '시간 지정 블록을 추출하지 못했습니다' }
  . $timeBlock
}
$t4gRows = @(
  @{ N = 'g1'; D = '전투 · 남은 90초(클리어 대기보다 짧음) → 거부 없이 시작 + 전투 시작 로그 (조건 2)'; Cat = 'battle'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 18, 30); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '2026-10-01 21:20:00.000'; XLog = $startNoticeBattle }
  @{ N = 'g2'; D = '전투 · 정각 직전 [시작] - 목표 계산은 21:19:59.9, 그 뒤 판단 시각은 21:20:00.1 (분이 바뀌어도 옛 클리어 대기 거부 문구가 전투에 안 찍힘)'; Cat = 'battle'
    Queue = @([datetime]::new(2026, 10, 1, 21, 19, 59, 900), [datetime]::new(2026, 10, 1, 21, 19, 59, 900)); Now = [datetime]::new(2026, 10, 1, 21, 20, 0, 100); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '2026-10-01 21:20:00.000'; XLog = $startNoticeBattle }
  @{ N = 'g3'; D = '전투 · 오늘 그 시각이 지남 → 내일 그 시각'; Cat = 'battle'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 20, 30); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '2026-10-02 21:20:00.000'; XLog = '시간 지정 모드: 10-02 21:20 지나면 새 판을 시작하지 않습니다 - 그 전에 시작한 판은 끝까지 하고 멈춥니다.' }
  @{ N = 'g4'; D = '전투 · 자정 넘김 (23:50 시작 · 00:30 지정) → 다음 날 00:30'; Cat = 'battle'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 23, 50, 0); Until = [datetime]::new(2000, 1, 1, 0, 30, 0)
    XTarget = '2026-10-02 00:30:00.000'; XLog = '시간 지정 모드: 10-02 00:30 지나면 새 판을 시작하지 않습니다 - 그 전에 시작한 판은 끝까지 하고 멈춥니다.' }
  @{ N = 'g5'; D = '전투 · 시각 선택기의 숨은 초(21:20:37)는 잘라 분 단위로'; Cat = 'battle'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 0, 0); Until = [datetime]::new(2000, 1, 1, 21, 20, 37)
    XTarget = '2026-10-01 21:20:00.000'; XLog = $startNoticeBattle }
  @{ N = 'g6'; D = '생활 · 남은 90초 < 진행 없음 한도 → 거부 문구 원문 + 목표 해제 (조건 5 - T5)'; Cat = 'life'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 18, 30); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '(없음)'; XLog = "[안내] 지정 시간(21:20)까지 남은 시간이 진행 없음 한도(${gatherLimit}초)보다 짧아 시작할 수 없습니다." }
  @{ N = 'g7'; D = '생활 · 남은 1200초 → 시작 + 옛 시작 로그 (T5)'; Cat = 'life'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 0, 0); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '2026-10-01 21:20:00.000'; XLog = $startNoticeLife }
  @{ N = 'g8'; D = '기타 · 남은 90초 < 클리어 대기 → 거부 문구 원문 (해당 없음 - 지금 그대로)'; Cat = 'etc'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 18, 30); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '(없음)'; XLog = "[안내] 지정 시간(21:20)까지 남은 시간이 클리어 대기(${clearLimit}초)보다 짧아 시작할 수 없습니다." }
  @{ N = 'g9'; D = "기타 · 남은 1200초(클리어 대기 ${clearLimit} 이상) → 시작 + 옛 시작 로그"; Cat = 'etc'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 0, 0); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '2026-10-01 21:20:00.000'; XLog = $startNoticeLife }
)
$t4gRun = 0
foreach ($row in $t4gRows) {
  Reset-GuiState
  $script:mainCategory = $row.Cat
  foreach ($moment in @($row.Queue)) { $script:fakeNowQueue.Enqueue($moment) }
  $script:fakeNow = $row.Now
  $dtpUntil.Value = $row.Until
  try { Invoke-StartTimeBlock } catch { $script:guiLogs += ('예외: ' + $_.Exception.Message) }
  Assert-Case ('T4-g {0}: {1}' -f $row.N, $row.D) ('목표[{0}] 로그[{1}]' -f (Format-Moment $script:targetTime), ($script:guiLogs -join ' / ')) ('목표[{0}] 로그[{1}]' -f $row.XTarget, $row.XLog)
  $t4gRun++
}

# ── T4-h UNTIL 전달 범위 행동 (Start-NextCycle 의 UNTIL 구간을 그대로 실행 - 설계 2.5 표) ──
$envBlock = $null
$nextCycleStatements = @((Get-GuiFunctionAst 'Start-NextCycle').Body.EndBlock.Statements)
$envClearIndex = -1
$envEndIndex = -1
for ($statementIndex = 0; $statementIndex -lt $nextCycleStatements.Count; $statementIndex++) {
  $statement = $nextCycleStatements[$statementIndex]
  $isAssignment = $statement -is [System.Management.Automation.Language.AssignmentStatementAst]
  if (($envClearIndex -lt 0) -and $isAssignment -and ($statement.Left.Extent.Text -eq '$env:HONEYNOGI_UNTIL_TIME') -and ($statement.Right.Extent.Text -eq "''")) { $envClearIndex = $statementIndex; continue }
  if (($envClearIndex -ge 0) -and $isAssignment -and ($statement.Left.Extent.Text -eq '$script:lastWorkerDoneReason')) { $envEndIndex = $statementIndex; break }
}
$envSegment = @()
if (($envClearIndex -ge 0) -and ($envEndIndex -gt $envClearIndex)) { $envSegment = @($nextCycleStatements[$envClearIndex..($envEndIndex - 1)]) }
Assert-Case 'T4-h 추출: UNTIL 비움부터 [완료] 사유 초기화 앞까지 = 비움 1줄 + if 2개 (사이클 추정치 줄 없음)' (@($envSegment | ForEach-Object { $_.GetType().Name }) -join ',') 'AssignmentStatementAst,IfStatementAst,IfStatementAst'
if ($envSegment.Count -gt 0) { $envBlock = [scriptblock]::Create((@($envSegment | ForEach-Object { $_.Extent.Text }) -join "`n")) }
function Invoke-UntilEnvBlock {
  # UNTIL 구간을 소스 그대로 실행합니다 - 점소싱(규칙 3). 결과는 이 프로세스의 $env:HONEYNOGI_UNTIL_TIME
  if ($null -eq $envBlock) { throw 'UNTIL 구간을 추출하지 못했습니다' }
  . $envBlock
}
$t4hRows = @(
  @{ N = 'h1'; D = '생활 + 시간 지정 → UNTIL (생활 분기 원문 - ko-KR 현재 문화권 생산, T5)'; Cat = 'life'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h2'; D = '던전 + 시간 지정 → UNTIL (신설)'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h3'; D = '심층 + 시간 지정 → UNTIL (신설)'; Cat = 'battle'; Content = 'deep'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h4'; D = '어비스 함께하기 파티원 + 시간 지정 → UNTIL 만 (사이클 추정치 없음)'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h5'; D = '어비스 혼자하기 → 없음 (GUI 가 회차 종료 때 판단 - 설계 5절)'; Cat = 'battle'; Content = 'abyss'; Mode = 'solo'; Matching = 'member'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h6'; D = '어비스 함께하기 파티장 → 없음'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'lead'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h7'; D = '사냥터 → 없음'; Cat = 'battle'; Content = 'hunting'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h8'; D = '기타 + 보존된 던전 라디오 → 없음 (기타 워커는 UNTIL 을 받으면 그 시각에 뽑기를 마침)'; Cat = 'etc'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h9'; D = '기타 + 보존된 어비스 함께하기 파티원 라디오 → 없음'; Cat = 'etc'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h10'; D = '던전 커스텀 → 없음'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $true; Target = $baseTarget; X = '' }
  @{ N = 'h11'; D = '던전 · 시간 지정 아님(목표 시각 없음) → 없음'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $null; X = '' }
  @{ N = 'h12'; D = '생활 · 시간 지정 아님 → 없음 (앞 회차 값도 먼저 지움)'; Cat = 'life'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $null; X = '' }
)
$t4hRun = 0
foreach ($row in $t4hRows) {
  Reset-GuiState
  $script:mainCategory = $row.Cat
  Set-RadioModel -Content $row.Content -Mode $row.Mode -Matching $row.Matching
  $script:customActive = $row.Custom
  $script:targetTime = $row.Target
  $env:HONEYNOGI_UNTIL_TIME = '앞 회차 값'
  $env:HONEYNOGI_CYCLE_ESTIMATE_SEC = $null
  try { Invoke-UntilEnvBlock } catch { $env:HONEYNOGI_UNTIL_TIME = ('예외: ' + $_.Exception.Message) }
  Assert-Case ('T4-h {0}: {1}' -f $row.N, $row.D) ('UNTIL[{0}] 추정치[{1}]' -f ([string]$env:HONEYNOGI_UNTIL_TIME), ([string]$env:HONEYNOGI_CYCLE_ESTIMATE_SEC)) ('UNTIL[{0}] 추정치[]' -f $row.X)
  $t4hRun++
}

# ── P2 문화권 왕복 (설계 리뷰 1차 12절) ────────────────────────────────────────────
# GUI 목표 시각 계산(시작 블록) → 전투 생산식(UNTIL 구간) → 워커 실제 파서 → 던전 14-T·파티원 G 판단을 문화권마다 소스 그대로 잇습니다.
# 해석 '성공'이 아니라 원래 DateTime 과의 일치를 봅니다 - th-TH 의 불기 연도 문자열은 해석에는 성공하지만 543년 뒤 시각이 됩니다.
$p2Scenarios = @(
  @{ N = '지정 21:20 (21:00 시작)'; Start = [datetime]::new(2026, 10, 2, 21, 0, 0); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    Target = [datetime]::new(2026, 10, 2, 21, 20, 0); Before = [datetime]::new(2026, 10, 2, 21, 19, 0) }
  @{ N = '자정 넘김 (23:50 시작 · 00:30 지정)'; Start = [datetime]::new(2026, 10, 1, 23, 50, 0); Until = [datetime]::new(2000, 1, 1, 0, 30, 0)
    Target = [datetime]::new(2026, 10, 2, 0, 30, 0); Before = [datetime]::new(2026, 10, 2, 0, 29, 0) }
)
$p2Contents = @(
  @{ N = '던전'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance' }
  @{ N = '어비스 파티원'; Content = 'abyss'; Mode = 'party'; Matching = 'member' }
)
# 대조(하니스 자체 확인): 같은 시각을 '현재 문화권'으로 서식하면 실제로 문화권 차이가 생겨야 이 표가 무엇이든 지킵니다
# (전환이 안 먹으면 세 문화권이 모두 ko-KR 로 돌아 생산식에서 InvariantCulture 를 빼도 통과)
$p2Controls = @{ 'ko-KR' = '2026-10-02 21:20'; 'th-TH' = '2569-10-02 21:20'; 'fi-FI' = '2026-10-02 21.20' }
$p2Run = 0
foreach ($cultureName in @('ko-KR', 'th-TH', 'fi-FI')) {
  try {
    [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($cultureName)
    Assert-Case "P2 ${cultureName} 대조(하니스): 같은 시각의 현재 문화권 서식" ([datetime]::new(2026, 10, 2, 21, 20, 0).ToString('yyyy-MM-dd HH:mm')) $p2Controls[$cultureName]
    foreach ($scenario in $p2Scenarios) {
      foreach ($content in $p2Contents) {
        $p2Label = 'P2 {0} · {1} · {2}' -f $cultureName, $scenario.N, $content.N
        Reset-GuiState
        $script:mainCategory = 'battle'
        Set-RadioModel -Content $content.Content -Mode $content.Mode -Matching $content.Matching
        $dtpUntil.Value = $scenario.Until
        $script:fakeNow = $scenario.Start
        Invoke-StartTimeBlock
        Assert-Case "${p2Label}: GUI 목표 시각 계산 = 원래 시각" (Format-Moment $script:targetTime) (Format-Moment $scenario.Target)
        $env:HONEYNOGI_UNTIL_TIME = '앞 회차 값'
        Invoke-UntilEnvBlock
        $producedText = [string]$env:HONEYNOGI_UNTIL_TIME
        Assert-Case "${p2Label}: 전투 생산 문자열 = 고정 형식 yyyy-MM-dd HH:mm (양력·':')" $producedText ($scenario.Target.ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture))
        $parsedUntil = Get-LifeUntilDeadline -Raw $producedText
        Assert-Case "${p2Label}: 워커 해석 = 원래 DateTime (분 단위) · 해석 경고 0줄" ('{0} · 경고 {1}줄' -f (Format-Moment $parsedUntil), $script:runLogs.Count) ('{0} · 경고 0줄' -f (Format-Moment $scenario.Target))
        if ($content.Content -eq 'dungeon') {
          $verdictText = (@($scenario.Start, $scenario.Before, $scenario.Target, $scenario.Target.AddMinutes(1)) | ForEach-Object { Get-DgTimeVerdict -UntilTime $parsedUntil -Now $_ }) -join ','
          Assert-Case "${p2Label}: 던전 14-T 판단 (시작 시각 / 1분 전 / 지정 시각 / 1분 뒤)" $verdictText 'continue,continue,last,last'
        } else {
          $gateText = (@(
              (Get-AbyssMemberStopReason -Phase 'start' -LastRun $false -UntilTime $parsedUntil -SafeStopFlag $false -Now $scenario.Start),
              (Get-AbyssMemberStopReason -Phase 'clear' -LastRun $false -UntilTime $parsedUntil -SafeStopFlag $false -Now $scenario.Before),
              (Get-AbyssMemberStopReason -Phase 'clear' -LastRun $false -UntilTime $parsedUntil -SafeStopFlag $false -Now $scenario.Target),
              (Get-AbyssMemberStopReason -Phase 'start' -LastRun $false -UntilTime $parsedUntil -SafeStopFlag $false -Now $scenario.Target)) | ForEach-Object { if ([string]$_ -eq '') { '-' } else { [string]$_ } }) -join ','
          Assert-Case "${p2Label}: 파티원 G (START 시작 시각 / 경계 1분 전 / 경계 지정 시각 / START 지정 시각)" $gateText '-,-,time,time'
        }
        $p2Run++
      }
    }
  } catch {
    "FAIL P2 ${cultureName} 실행 중 예외: $($_.Exception.Message)"; $fails++
  } finally {
    [Threading.Thread]::CurrentThread.CurrentCulture = $baselineCulture
  }
}
Assert-Case 'P2 문화권 원복 (기준 ko-KR 로 돌아옴)' ([Threading.Thread]::CurrentThread.CurrentCulture.Name) 'ko-KR'

# ── 실행 행 수 (예외로 표가 중간에 끊기면 여기서 드러남) ─────────────────────────────
Assert-Case '실행 행 수 T4-a/T4-b/T4-c/T4-f/T4-g/T4-h/P2' ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $t4aRun, $t4bRun, $t4cRun, $t4fRun, $t4gRun, $t4hRun, $p2Run) '13/11/11/15/9/12/12'

[Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
$env:HONEYNOGI_UNTIL_TIME = $originalUntilEnv
$env:HONEYNOGI_CYCLE_ESTIMATE_SEC = $originalEstimateEnv
if ($fails -gt 0) { "FAIL 합계: $fails"; exit 1 }
'OK 전체 통과'
exit 0
