# 시간 지정 '지정 시각이 지나면 그 판까지' GUI 회귀 (2026-10-02 신설 - 시간 지정 '그 판까지' 설계_v2 8.2 T4·T5, 설계 리뷰 1차 12절 P2;
# 2026-10-07 생활 '그 사이클까지' 확장 반영 - 생활 확장 설계 v3 6.1·6.2)
#
# 배경: 전투의 시간 지정 규칙을 '지금 + 클리어 대기 <= 지정 시각이면 다음 회차'에서 '지금 < 지정 시각이면 새 판 시작, 그 전에 시작한 판은
# 끝까지'로 바꿨다. 워커가 지정 시각 전에 다음 판으로 이어 가기로 정하고 끝내면 새 종료 코드 11 을 내고, GUI 는 11 이면 지정 시각을 보지 않고
# 다음 워커를 띄운다(판단 주체 하나 - 조건 4). 옛 판단 사슬은 타이머 스크립트블록 안에 있어 이름으로 추출할 수 없었고 어떤 테스트도 그 사슬을
# 실행하지 못했다. 그래서 판단(순수부 Get-NextCycleAction)과 실행(Invoke-NextCycleDecision)을 함수로 뺐다 - 여기서는 그 함수들을 GUI 소스에서
# 그대로 추출해 돌리고(사본 금지), 타이머에 남은 호출 한 줄씩은 주석 뺀 사본에서 원문으로 고정한다.
# 여기서 고정하는 계약 (설계 8.2 표 번호 그대로. T4-g·T4-h 는 설계 표 밖에서 더한 행동 확인 - 소스 블록을 그대로 실행):
#   T4-a Get-NextCycleAction 진리표 - 안전 중지 > (지정 횟수 | 준비 실행 3회 연속) > 지정 시간 > 다음 회차, 코드 11 은 '지정 시간' 칸만 건너뜀
#   T4-b Test-TimeAllowsNextCycle - 전투·생활 '지금 < 목표', 기타 '지금 + 클리어 대기 <= 목표'(옛 식 그대로)
#   T4-c Test-WorkerTimeJudgeActive(UNTIL 전달 대상 술어) - 던전·심층·어비스(전투·비커스텀) - 사냥터·생활·기타·커스텀 제외(설계 v11 R3 Q3).
#        생활·기타로 바꿔도 보존되는 전투 라디오를 모형화 (설계 회귀 R-3)
#   T4-d 문구 보조 함수 - 전투 '판'·생활 '사이클' 새 문구, 기타 출력은 옛 문구와 글자 그대로
#   T4-e 배선 (주석 뺀 GUI 사본) - 타이머 바깥 조건·공통 최종 수집 자리(1b)·호출 두 곳·완료 줄·옛 사슬 리터럴 위치·판단 호출 인자·시작 게이트·UNTIL 분기·상태줄·설명서
#        + 단계 2.6(구현 명세 ① · 설계 v11 R1 6.1 · R2 5.4): 재입장 실행부·완주 호출 자리(2c) · 0·11 갈래의 판별 → 일반 끝 처리 순서(2d) · 코드 10 첫 문장(S6)
#        + 단계 2.7(구현 명세 ① 2.7 ⑥): 코드 4 갈래 = 계상 한 줄 → 사유 계산 → 끝 정지 계획(2e)
#        + 단계 2.8(구현 명세 ① 2.8 · 설계 v11 R1 6.1): 코드 1 을 받는 갈래 = 마무리 실행 판별 → 완료 기록 라우팅 한 줄(2c) · T4-a 코드 1 행 4개
#          · 예전 처리 recover 갈래 안전 중지의 nonce 닫기 → 정지 순서(2c - 단계 2.7·2.8 구현 리뷰 확인 라운드 · retry 갈래는 열어 둠 - 구현 리뷰 확인)
#   T4-f Invoke-NextCycleDecision 행동 - Stop-AllRun·Start-NextCycle·Add-GuiLog 를 모의로 바꿔 '무엇을 했는지'로 지킴 (인자 누락·고정값 변이를 잡는 곳)
#   T4-g 시작 게이트 행동 - Invoke-StartAutomation 의 시간 지정 블록을 그대로 실행 (전투·생활은 거부 없음 - 조건 2·생활 확장 조건 2, 기타는 거부 원문 - 해당 없음)
#   T4-h UNTIL 전달 범위 행동 - Start-NextCycle 의 UNTIL 구간을 그대로 실행 (설계 2.5 표 - 받는 워커는 던전·심층·어비스(전투·비커스텀) - 사냥터·생활·기타·
#        커스텀 제외(설계 v11 R3 Q3), 생활은 받지 않음 - 생활 확장 A안)
#   P2   문화권 왕복 - GUI 목표 시각 계산·전투 생산식 → 워커 Get-LifeUntilDeadline → 던전·파티원 판단을 ko-KR·th-TH·fi-FI × (21:20 / 자정 넘김)
#        으로 돌려 해석값이 원래 DateTime 과 같음을 단언한다 (현재 문화권으로 만들면 th-TH 는 불기 연도로 '정상' 해석, fi-FI 는 해석 실패)
#   T5   생활 새 규칙(2026-10-02 생활 확장 '그 사이클까지' - 설계_v3_생활) = T4-b 5~7 · T4-d 생활 열 · T4-e 4(생활 리터럴)·6·8·10 · T4-f 13·14 · T4-g g6·g7·g10 · T4-h h1
#        (+ test_life_gather 의 워커 가드·GUI 부재 단언·시뮬레이터 until-* 4 시나리오)
# 모의: 시각은 Get-Date($script:fakeNow), 라디오·숫자 칸·상태줄·시각 선택기는 속성 객체입니다. 정지·다음 회차·GUI 로그는 기록만 합니다.
# 문화권: 문구의 시각 서식(HH:mm·MM-dd HH:mm)이 현재 문화권을 따르므로 실사용 문화권 ko-KR 로 고정해 돌리고 끝에서 되돌립니다.
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
function Start-NextCycle {
  # GUI Start-NextCycle 과 같은 서명 (구현 명세 ① 2.5 ④ - 재개·재입장 실행부·마무리 실행 기동의 선택 인자. 실행 함수는 인자 없이 부름). 호출 기록만
  param([switch]$PreserveMarker, [switch]$FromInsideHandoff, $FinishOnlyHold = $null, [string]$ResumeNonce = '')
  $script:actions += 'next'
}
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
$stopNoticeLife = '지정 시간(21:20) 이후라 새 사이클을 시작하지 않습니다.'
$stopNoticeEtc = '지정 시간(21:20)까지 남은 시간이 부족해 다음 회차를 시작하지 않습니다.'
$startNoticeBattle = '시간 지정 모드: 10-01 21:20 지나면 새 판을 시작하지 않습니다 - 그 전에 시작한 판은 끝까지 하고 멈춥니다.'
$startNoticeLife = '시간 지정 모드: 10-01 21:20 지나면 새 사이클을 시작하지 않습니다 - 그 전에 시작한 사이클은 끝까지 하고 멈춥니다.'
$startNoticeEtc = '시간 지정 모드: 10-01 21:20 까지 반복합니다.'

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
  # 코드 1 - 재입장(reentered) 뒤 오류 종료를 코드 1 라우팅이 재입장 실행부로 넘기면 같은 순수부가 판단합니다(구현 명세 ① 2.8 · 설계 v11 R1 4·6.1).
  # 코드 1 은 11 이 아니라 지정 시간 칸이 살고(H23), 회차로 센 판이라 지정 횟수도 봅니다(H43 - 도달 경로 없는 완결용)
  @{ N = 14; Code = 1; Stop = $false; Reached = $false; Streak = 0; TimeOk = $true; X = 'next'; Why = ' - 코드 1 재입장 (설계 R1 H22)' }
  @{ N = 15; Code = 1; Stop = $false; Reached = $false; Streak = 0; TimeOk = $false; X = 'time'; Why = ' - 코드 1 은 11 이 아니라 시간 칸이 삶 (H23)' }
  @{ N = 16; Code = 1; Stop = $true; Reached = $false; Streak = 0; TimeOk = $false; X = 'safe-stop'; Why = ' - (H25)' }
  @{ N = 17; Code = 1; Stop = $false; Reached = $true; Streak = 0; TimeOk = $true; X = 'count'; Why = ' - (H43)' }
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
  @{ N = '5'; D = '생활 · 지정 1초 전 (옛 식이면 거짓 - 진행 없음 한도 추정치를 다시 넣는 변이를 잡음, 생활 확장)'; Cat = 'life'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-1); X = $true }
  @{ N = '6'; D = '생활 · 지정 시각과 같음 (같은 시각 포함 - 새 사이클 없음)'; Cat = 'life'; Target = $baseTarget; Now = $baseTarget; X = $false }
  @{ N = '7'; D = '생활 · 지정 1초 뒤'; Cat = 'life'; Target = $baseTarget; Now = $baseTarget.AddSeconds(1); X = $false }
  @{ N = '8'; D = "기타 · 지정 $($clearLimit + 1)초 전 (클리어 대기 ${clearLimit} - 옛 식 그대로)"; Cat = 'etc'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-($clearLimit + 1)); X = $true }
  @{ N = '8b'; D = "기타 · 지정 ${clearLimit}초 전 (<= - 남은 시간 = 클리어 대기면 옛 식 그대로 참)"; Cat = 'etc'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-$clearLimit); X = $true }
  @{ N = '9'; D ="기타 · 지정 $($clearLimit - 1)초 전 (해당 없음 - 옛 식 그대로 거짓)"; Cat = 'etc'; Target = $baseTarget; Now = $baseTarget.AddSeconds(-($clearLimit - 1)); X = $false }
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
  @{ N = 4; D = 'battle · 어비스 혼자하기 (매칭 라디오는 파티원으로 보존) - 어비스 혼자하기·파티장도 받음(설계 v11 R3 Q3)'; Cat = 'battle'; Content = 'abyss'; Mode = 'solo'; Matching = 'member'; Custom = $false; X = $true }
  @{ N = 5; D = 'battle · 어비스 + 함께하기 + 파티장 - 어비스 혼자하기·파티장도 받음(설계 v11 R3 Q3)'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'lead'; Custom = $false; X = $true }
  @{ N = 6; D = 'battle · 사냥터'; Cat = 'battle'; Content = 'hunting'; Mode = 'solo'; Matching = 'chance'; Custom = $false; X = $false }
  @{ N = 7; D = 'battle · 던전 · 커스텀'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $true; X = $false }
  @{ N = 8; D = 'life · 던전 라디오 켜짐(보존)'; Cat = 'life'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; X = $false }
  @{ N = 9; D = 'etc · 던전 라디오 켜짐(보존)'; Cat = 'etc'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; X = $false }
  @{ N = 10; D = 'life · 어비스 + 함께하기 + 파티원 라디오 모두 켜짐(보존)'; Cat = 'life'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; X = $false }
  @{ N = 11; D = 'etc · 어비스 + 함께하기 + 파티원 라디오 모두 켜짐(보존)'; Cat = 'etc'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; X = $false }
  # 12~14 설계 v11 R3 5.1 U6~U8 - 어비스는 매칭·역할 라디오를 보지 않고(우연한 만남·파티 찾기도 받음), 커스텀은 받지 않음
  @{ N = 12; D = 'battle · 어비스 + 함께하기 + 우연한 만남 (설계 v11 R3 Q3)'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'chance'; Custom = $false; X = $true }
  @{ N = 13; D = 'battle · 어비스 + 함께하기 + 파티 찾기 (받기만 - 설계 v11 R3 4.2)'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'find'; Custom = $false; X = $true }
  @{ N = 14; D = 'battle · 어비스 혼자하기 · 커스텀 (커스텀은 받지 않음 - 설계 v11 R3 Q3)'; Cat = 'battle'; Content = 'abyss'; Mode = 'solo'; Matching = 'chance'; Custom = $true; X = $false }
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
Assert-Case 'T4-d 정지 안내 · life (새 사이클 문구 - 생활 확장)' (Invoke-Guarded { Get-TimeStopNotice -TargetText '21:20' -MainCategory 'life' }) $stopNoticeLife
Assert-Case 'T4-d 정지 안내 · etc (옛 문구 그대로 - 해당 없음)' (Invoke-Guarded { Get-TimeStopNotice -TargetText '21:20' -MainCategory 'etc' }) $stopNoticeEtc
Assert-Case 'T4-d 상태줄 꼬리 · battle' (Invoke-Guarded { Get-TimeStatusSuffix -TargetTime $baseTarget -MainCategory 'battle' }) ' (21:20 지나면 그 판까지)'
Assert-Case 'T4-d 상태줄 꼬리 · life (그 사이클까지 - 생활 확장)' (Invoke-Guarded { Get-TimeStatusSuffix -TargetTime $baseTarget -MainCategory 'life' }) ' (21:20 지나면 그 사이클까지)'
Assert-Case 'T4-d 상태줄 꼬리 · etc (옛 꼬리 그대로 - 해당 없음)' (Invoke-Guarded { Get-TimeStatusSuffix -TargetTime $baseTarget -MainCategory 'etc' }) ' (21:20 까지)'
Assert-Case 'T4-d 상태줄 꼬리 · 지정 시각 $null (타입 없는 인자 - [datetime] 이면 변환 오류)' (Invoke-Guarded { Get-TimeStatusSuffix -TargetTime $null -MainCategory 'battle' }) ''
Assert-Case 'T4-d 상태줄 꼬리 · 지정 시각 인자 생략' (Invoke-Guarded { Get-TimeStatusSuffix -MainCategory 'life' }) ''
Assert-Case 'T4-d 시작 로그 · battle' (Invoke-Guarded { Get-TimeStartNotice -TargetTime $baseTarget -MainCategory 'battle' }) $startNoticeBattle
Assert-Case 'T4-d 시작 로그 · life (새 사이클 문구 - 생활 확장)' (Invoke-Guarded { Get-TimeStartNotice -TargetTime $baseTarget -MainCategory 'life' }) $startNoticeLife
Assert-Case 'T4-d 시작 로그 · etc (옛 문구 그대로 - 해당 없음)' (Invoke-Guarded { Get-TimeStartNotice -TargetTime $baseTarget -MainCategory 'etc' }) $startNoticeEtc

# ── T4-e 배선 (주석 뺀 GUI 사본) ──────────────────────────────────────────────────
$decisionCode = Get-GuiFunctionCode 'Invoke-NextCycleDecision'
$stopNoticeCode = Get-GuiFunctionCode 'Get-TimeStopNotice'
$startNoticeCode = Get-GuiFunctionCode 'Get-TimeStartNotice'
$judgeActiveCode = Get-GuiFunctionCode 'Test-WorkerTimeJudgeActive'
$nextCycleCode = Get-GuiFunctionCode 'Start-NextCycle'
$startAutomationCode = Get-GuiFunctionCode 'Invoke-StartAutomation'
$suffixCode = Get-GuiFunctionCode 'Get-TimeStatusSuffix'

# 1. 바깥 조건 - 11 을 빼면 11 이 그 밖 코드 사슬(오류 정지)로 갑니다 (변이 G8)
Assert-Case 'T4-e 1: 타이머 바깥 조건이 코드 0 과 11 을 같은 갈래로 받음' (Get-TextCount $guiCode 'if (($exitCode -eq 0) -or ($exitCode -eq 11)) {') 1
# 1b. 공통 최종 수집 자리 (구현 명세 ① 2.4 · v11 R1 6.1) - 준비 실행 연속 수 초기화 뒤·코드 0·11 갈래 앞의 호출 한 줄이고 GUI 전체에서 그 한
#     곳(타이머)뿐입니다. 갈래 안이나 판별 뒤로 옮기면 그 밖 갈래가 종료 직전 [완료] 줄을 못 봅니다(변이 R1-M14 · 행동은 test_abyss_handoff_gui C 행)
Assert-Case 'T4-e 1b: 공통 최종 수집 호출 = 연속 수 초기화 → 수집 → 코드 0·11 갈래 순서 1곳 · GUI 전체 호출 1곳(함수 밖 - 타이머)' `
  ('{0} · {1}' -f (Get-PatternCount $guiCode (New-SequencePattern @('if ($exitCode -ne 10) { $script:preparedStreak = 0 }', 'Invoke-ExitLogFinalCollect', 'if (($exitCode -eq 0) -or ($exitCode -eq 11)) {'))),
    (Get-CallOwners $guiAst 'Invoke-ExitLogFinalCollect')) '1 · 1|(함수 밖)'

# 2. 실행 함수 호출 두 곳 - 타이머에 남은 것은 이 호출 한 줄씩뿐입니다 (0 고정 변이 G14)
Assert-Case 'T4-e 2: 실행 함수 호출 = 원문 2곳 · 호출 2개가 둘 다 함수 밖(타이머 스크립트블록)' ('{0} · {1}' -f (Get-TextCount $guiCode 'Invoke-NextCycleDecision -ExitCode $exitCode'), (Get-CallOwners $guiAst 'Invoke-NextCycleDecision')) '2 · 2|(함수 밖),(함수 밖)'
Assert-Case 'T4-e 2a: 코드 0·11 의 비커스텀 꼬리 = 실행 함수 한 줄 (바로 뒤가 코드 10 갈래)' (Get-PatternCount $guiCode (New-SequencePattern @('} else {', 'Invoke-NextCycleDecision -ExitCode $exitCode', '}', '} elseif ($exitCode -eq 10) {'))) 1
Assert-Case 'T4-e 2b: 코드 10 꼬리 = 커스텀 PREV 정리 뒤 실행 함수 한 줄 (바로 뒤가 코드 2 갈래)' (Get-PatternCount $guiCode (New-SequencePattern @('$script:customRestart = $false', '}', 'Invoke-NextCycleDecision -ExitCode $exitCode', '} elseif ($exitCode -eq 2) {'))) 1
# 2c. 재입장 실행부·마무리 실행 완주의 호출 자리 (구현 명세 ① 2.6·2.8 · 설계 v11 R1 6.1) - 실행부는 0·11 갈래(타이머) 1곳 + 코드 1 라우팅(reentered 의
#     이어받기 - 단계 2.8), 완주는 0·11 갈래·코드 10 갈래 2곳 - 둘 다 타이머. 코드 10 갈래 = 첫 문장 완료 기록 끝 처리 → 바로 다음 마무리 실행 판별
#     (변이 R1-M10·M23). 코드 1 을 받는 갈래(그 밖 코드 포함) = 첫 문장 마무리 실행 판별(오류 정지 · return - 변이 R1-M17) → 바로 다음 라우팅 한 줄 →
#     라우팅이 끝냈으면 return, 라우팅 호출은 타이머 1곳. 라우팅 함수 안의 순서(비커스텀 재입장 오류 상한이 실행부보다 앞 - 설계 R1 H48)는 함수 안이라
#     원문 패턴이 아니라 test_abyss_handoff_gui 의 행동 행이 지킵니다(구현 명세 ① 2.8 · 검토 P3-16).
#     + 단계 2.7·2.8 구현 리뷰 확인 라운드: 코드 1 갈래의 예전 처리에서 안전 중지로 멈추는 두 곳 중 recover 갈래 = 안전 중지 if → 이번 기동 nonce 닫기(-RoutedNonce
#     빈 값) → '안전 중지' 정지 → else 순서 1곳 · 닫기 호출 = 타이머 1 + 라우팅 4. retry 갈래의 안전 중지는 닫지 않고 열어 둠(구현 리뷰 확인 - 그 자리는
#     test_abyss_handoff_gui S21). 기대값 이력: 끝 두 칸 없음 '… · 1|(함수 밖)'(단계 2.8) → '… · 2 · 6|(함수 밖),(함수 밖),…'(확인 라운드 - 두 곳 닫음) →
#     '… · 1 · 5|(함수 밖),…'(구현 리뷰 확인 - retry 열어 둠). 행동은 test_abyss_handoff_gui NC9~NC11
Assert-Case 'T4-e 2c: 재입장 실행부 호출 = 타이머 · 코드 1 라우팅 · 완주 호출 2곳(둘 다 타이머) · 코드 10 갈래 = 첫 문장 끝 처리 → 마무리 실행 판별 순서 1 · 코드 1 갈래 = 마무리 실행 판별 → 라우팅 순서 1 · 라우팅 호출 = 타이머 · 예전 처리 안전 중지 = 닫기 → 정지 순서 1(recover) · 닫기 호출 = 타이머 1 + 라우팅 4' `
  ('{0} · {1} · {2} · {3} · {4} · {5} · {6}' -f (Get-CallOwners $guiAst 'Invoke-InsideHandoffExit'), (Get-CallOwners $guiAst 'Complete-FinishOnlyCycle'),
    (Get-PatternCount $guiCode (New-SequencePattern @('} elseif ($exitCode -eq 10) {', 'if (-not (Complete-AbyssExitJournal -ExitCode $exitCode)) { return }',
          "if (`$script:lastLaunchKind -eq 'finish-only') { Complete-FinishOnlyCycle -ExitCode `$exitCode; return }"))),
    (Get-PatternCount $guiCode (New-SequencePattern @('} else {', "if (`$script:lastLaunchKind -eq 'finish-only') {",
          'Stop-AllRun -IsError "마무리 실행 중 오류 종료(코드 $exitCode) - 자동 재시작하지 않고 정지 (진행 기록 보존, 캐릭터가 던전 안일 수 있습니다)"',
          '$lblStatus.ForeColor = [System.Drawing.Color]::Firebrick', 'return', '}',
          '$code1Route = Invoke-Code1JournalRouting -ExitCode $exitCode', "if (`$code1Route -eq 'handled') { return }"))),
    (Get-CallOwners $guiAst 'Invoke-Code1JournalRouting'),
    (Get-PatternCount $guiCode (New-SequencePattern @('if ($script:stopRequested) {', "Close-AbyssLaunchNonceOnStop -RoutedNonce ''", "Stop-AllRun '안전 중지'", '} else {'))),
    (Get-CallOwners $guiAst 'Close-AbyssLaunchNonceOnStop')) `
  ('2|(함수 밖),Invoke-Code1JournalRouting · 2|(함수 밖),(함수 밖) · 1 · 1 · 1|(함수 밖) · 1 · ' +
    '5|(함수 밖),Invoke-Code1JournalRouting,Invoke-Code1JournalRouting,Invoke-Code1JournalRouting,Invoke-Code1JournalRouting')
# 2d. 0·11 갈래의 완료 기록 처리 순서 (설계 v11 R1 3.3 코드 모양 · 6.1) - 비커스텀 완료 줄 뒤 판별 → 기록 오류면 정지·return → 재입장이면 실행부·return →
#     마무리 실행이면 완주·return → 일반 끝 처리 한 줄 → 커스텀 사슬 머리. 조각 사이는 공백만(주석 자리 포함) - 판별을 완료 줄 앞으로 옮기거나 return 을
#     지워 아래 사슬로 흘리거나(변이 R1-M9) 끝 처리와 사슬 머리 사이에 문장을 끼우면 깨집니다(재입장 오류 연속 0 은 끝 처리 안 - 명세 5절 B4)
Assert-Case 'T4-e 2d: 0·11 갈래 = 완료 줄 → 판별 → 오류 정지 → 실행부 → 완주 → 일반 끝 처리 한 줄 → 커스텀 사슬 순서 1' `
  (Get-PatternCount $guiCode (New-SequencePattern @(
        'Add-GuiLog "=== $($script:completedCycles)회차 완료$cycleDoneSuffix ==="', '}',
        '$handoffExit = Read-AbyssExitHandoff -ExitCode $exitCode -Context $finishedContext',
        "if (`$handoffExit.Kind -eq 'journal-error') {", 'Stop-AllRun -IsError $handoffExit.Reason', '$lblStatus.ForeColor = [System.Drawing.Color]::Firebrick', 'return', '}',
        "if (`$handoffExit.Kind -eq 'inside-handoff') {", 'Invoke-InsideHandoffExit -ExitCode $exitCode -Handoff $handoffExit -FinishedContext $finishedContext', 'return', '}',
        "if (`$script:lastLaunchKind -eq 'finish-only') {", 'Complete-FinishOnlyCycle -ExitCode $exitCode', 'return', '}',
        'if (-not (Complete-AbyssExitJournal -ExitCode $exitCode -Context $finishedContext)) { return }',
        'if ($script:customActive) {'))) 1
# S6 (설계 v11 R2 5.4). 코드 10 갈래의 첫 문장 = 종료 처리 mutation(완료 기록 끝 처리) - ① 갈래 머리 바로 다음 ② 같은 갈래의 다음 회차 판단보다 앞.
#    판단 안의 Start-NextCycle 이 다음 기동 후보를 고르므로, 이번 기동 nonce 를 열어 둔 채 넘어가면 같은 항목을 다시 넘깁니다(변이 R2 '끝 처리를 판단 뒤로').
#    사이에 다른 문장(판별·연속 수·커스텀 PREV)이 있어 ② 는 같은 갈래 안의 위치(IndexOf)로 봅니다
$exitChainIfs = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -ceq '($exitCode -eq 0) -or ($exitCode -eq 11)') }, $true))
$code10Block = ''
if ($exitChainIfs.Count -eq 1) {
  $code10Clauses = @($exitChainIfs[0].Clauses | Where-Object { $_.Item1.Extent.Text -ceq '$exitCode -eq 10' })
  if ($code10Clauses.Count -eq 1) { $code10Block = $guiCode.Substring($code10Clauses[0].Item2.Extent.StartOffset, $code10Clauses[0].Item2.Extent.EndOffset - $code10Clauses[0].Item2.Extent.StartOffset) }
}
$code10Mutation = 'if (-not (Complete-AbyssExitJournal -ExitCode $exitCode)) { return }'
$code10MutationAt = $code10Block.IndexOf($code10Mutation)
$code10DecisionAt = $code10Block.IndexOf('Invoke-NextCycleDecision -ExitCode $exitCode')
Assert-Case 'S6 코드 10 갈래: 첫 문장 = 완료 기록 끝 처리(갈래 머리 바로 다음 1) · 그 위치 < 같은 갈래의 다음 회차 판단 위치' `
  ('{0} · {1}' -f (Get-PatternCount $guiCode (New-SequencePattern @('} elseif ($exitCode -eq 10) {', $code10Mutation))), [int](($code10MutationAt -ge 0) -and ($code10DecisionAt -gt $code10MutationAt))) '1 · 1'
# 2e. 코드 4 갈래 (구현 명세 ① 2.7 ⑥ · 설계 v11 R1 6.1 · 3.7 표 4행): ⓐ 갈래 머리 바로 다음 = 계상 함수 한 줄(거짓이면 함수 안에서 오류 정지까지 했으니 return -
#     정지 두 번 금지) ⓑ 끝 정지 = 사유·심각도 순수부(Get-Code4StopPlan) 결과로 - 마무리 실행 기동의 오류 보류를 정상 정지로 덮지 않음(변이 R1-M22 의 배선 짝,
#     행동은 test_abyss_handoff_gui H32d). 두 조각은 코드 4 갈래 안에서 세고(사유 계산 뒤), 코드 4 사유를 그대로 정지하는 옛 리터럴은 GUI 전체 0 · 두 함수 호출은 타이머 1곳씩
$code4Block = ''
if ($exitChainIfs.Count -eq 1) {
  $code4Clauses = @($exitChainIfs[0].Clauses | Where-Object { $_.Item1.Extent.Text -ceq '$exitCode -eq 4' })
  if ($code4Clauses.Count -eq 1) { $code4Block = $guiCode.Substring($code4Clauses[0].Item2.Extent.StartOffset, $code4Clauses[0].Item2.Extent.EndOffset - $code4Clauses[0].Item2.Extent.StartOffset) }
}
$code4StopPattern = New-SequencePattern @('$code4Plan = Get-Code4StopPlan -Code4Reason $code4Reason -LaunchKind $script:lastLaunchKind -Hold $script:finishOnlyHold',
  'if ($code4Plan.IsError) {', 'Stop-AllRun -IsError $code4Plan.Reason', '$lblStatus.ForeColor = [System.Drawing.Color]::Firebrick', '} else {',
  'Stop-AllRun $code4Plan.Reason', '$lblStatus.ForeColor = [System.Drawing.Color]::SteelBlue', '}')
Assert-Case 'T4-e 2e: 코드 4 갈래 = 머리 → 계상 한 줄(거짓이면 return) 1 · 갈래 안 끝 정지 = 정지 계획 → 오류면 빨강 / 아니면 SteelBlue 1 · 사유 계산 뒤 · 옛 리터럴 0 · 호출 소유자 타이머' `
  ('{0} · {1} · {2} · {3} · {4} · {5}' -f (Get-PatternCount $guiCode (New-SequencePattern @('} elseif ($exitCode -eq 4) {', 'if (-not (Invoke-Code4Accounting)) { return }'))),
    (Get-PatternCount $code4Block $code4StopPattern), [int](($code4Block.IndexOf('$code4Reason = ''''') -ge 0) -and ($code4Block.IndexOf('$code4Plan = Get-Code4StopPlan') -gt $code4Block.IndexOf('$code4Reason = '''''))),
    (Get-TextCount $guiCode 'Stop-AllRun $code4Reason'), (Get-CallOwners $guiAst 'Invoke-Code4Accounting'), (Get-CallOwners $guiAst 'Get-Code4StopPlan')) `
  '1 · 1 · 1 · 0 · 1|(함수 밖) · 1|(함수 밖)'

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
  @{ L = '지나면 새 사이클을 시작하지 않습니다 - 그 전에 시작한 사이클은 끝까지 하고 멈춥니다.'; F = 'Get-TimeStartNotice'; C = $startNoticeCode }
  @{ L = '이후라 새 사이클을 시작하지 않습니다.'; F = 'Get-TimeStopNotice'; C = $stopNoticeCode }
  @{ L = '지나면 그 사이클까지)'; F = 'Get-TimeStatusSuffix'; C = $suffixCode }
)
foreach ($item in $chainLiterals) {
  Assert-Case ('T4-e 4: 리터럴 [{0}] 은 GUI 전체 1곳이고 {1} 안' -f $item.L, $item.F) ('{0}/{1}' -f (Get-TextCount $guiCode $item.L), (Get-TextCount $item.C $item.L)) '1/1'
}
$noticeOwners = '{0} / {1} / {2}' -f (Get-CallOwners $guiAst 'Get-TimeStopNotice'), (Get-CallOwners $guiAst 'Get-TimeStartNotice'), (Get-CallOwners $guiAst 'Get-TimeStatusSuffix')
Assert-Case 'T4-e 4: 문구 함수 호출 위치 - 정지 안내는 실행 함수, 시작 로그는 시작 처리, 상태줄 꼬리는 안전 중지 버튼 처리기(함수 밖)·회차 시작' $noticeOwners '1|Invoke-NextCycleDecision / 1|Invoke-StartAutomation / 2|(함수 밖),Start-NextCycle'

# 5. 판단 함수에 넘기는 인자 - -ExitCode 누락이면 11 이 0 이 되고, -TimeAllows $true 고정이면 전투 시간 지정이 영영 안 멈춤 (변이 G10·G11).
#    2026-10-09 (구현 명세 ① 2.6 · 설계 v11 R1 6.1): 재입장 실행부도 같은 순수부를 부릅니다(준비 실행 연속은 0 - 코드 10 으로 부르지 않음, 변이 R1-M3·M4).
#    호출마다 '감싼 함수|인자 원문' 을 서수 정렬해 둘 다 봅니다(예전 단언은 첫 호출 하나만 봤음)
$actionCalls = @(Get-CommandCalls $guiAst 'Get-NextCycleAction')
[string[]]$actionCallTexts = @($actionCalls | ForEach-Object { '{0}|{1}' -f (Get-EnclosingFunctionName $_), (($_.Extent.Text -replace '\s+', ' ').Trim()) })
[Array]::Sort($actionCallTexts, [StringComparer]::Ordinal)
Assert-Case 'T4-e 5: 판단 함수 호출 2곳 = 재입장 실행부 · 실행 함수 - 감싼 함수와 인자 원문(공백 정규화)' ('{0}: {1}' -f $actionCalls.Count, ($actionCallTexts -join ' / ')) `
  ('2: Invoke-InsideHandoffExit|Get-NextCycleAction -ExitCode $ExitCode -StopRequested $script:stopRequested -ReachedTarget $reachedTarget -PreparedStreak 0 -TimeAllows $timeAllows / ' +
  'Invoke-NextCycleDecision|Get-NextCycleAction -ExitCode $ExitCode -StopRequested $script:stopRequested -ReachedTarget $reachedTarget -PreparedStreak $script:preparedStreak -TimeAllows $timeAllows')

# 6. 시작 게이트 - 기타만 거부(문구 원문 그대로), 전투·생활은 게이트를 타지 않음 (변이 G6 · 생활 확장 L2·L3)
$gateLine = 'if (($script:mainCategory -eq ''etc'') -and (-not (Test-TimeAllowsNextCycle))) {'
$oldGateLine = 'if (($script:mainCategory -ne ''battle'') -and (-not (Test-TimeAllowsNextCycle))) {'
$refuseLine = 'Add-GuiLog "[안내] 지정 시간($($script:targetTime.ToString(''HH:mm'')))까지 남은 시간이 클리어 대기($(Get-CycleWaitSecondsForEstimate)초)보다 짧아 시작할 수 없습니다."'
$startNoticeLine = 'Add-GuiLog (Get-TimeStartNotice -TargetTime $script:targetTime -MainCategory $script:mainCategory)'
Assert-Case 'T4-e 6: 시작 게이트(기타 전용)·거부 문구(인라인 원문)·시작 로그 호출이 GUI 전체에 1곳씩 · 옛 게이트(-ne battle)·라벨 변수 0건' ('{0}/{1}/{2}/{3}/{4}' -f (Get-TextCount $guiCode $gateLine), (Get-TextCount $guiCode $refuseLine), (Get-TextCount $guiCode $startNoticeLine), (Get-TextCount $guiCode $oldGateLine), (Get-TextCount $guiCode '$estimateLabel')) '1/1/1/0/0'
Assert-Case 'T4-e 6: 게이트 → 거부 → 목표 시각 해제 → return → 시작 로그 순서로 붙어 있음 (Invoke-StartAutomation 안)' (Get-PatternCount $startAutomationCode (New-SequencePattern @($gateLine, $refuseLine, '$script:targetTime = $null', 'return', '}', $startNoticeLine))) 1

# 7. 시간 판단 호출 위치 (2026-10-09 구현 명세 ① 2.6 - 재입장 실행부가 더함: 지정 시각 뒤 재입장은 마무리 실행으로 정지 - 설계 v11 R1 H5)
Assert-Case 'T4-e 7: 시간 판단 호출 3곳 = 재입장 실행부 · 실행 함수 · 시작 게이트' (Get-CallOwners $guiAst 'Test-TimeAllowsNextCycle') '3|Invoke-InsideHandoffExit,Invoke-NextCycleDecision,Invoke-StartAutomation'

# 8. UNTIL 전달 - 매 회차 먼저 비우고, 전투 분기(판단 워커만 + InvariantCulture 생산)만 남음 - 생활 분기 없음 (변이 G9·P2 · 생활 확장 L6)
$envPattern = New-SequencePattern @(
  '$env:HONEYNOGI_UNTIL_TIME = ''''',
  'if (($null -ne $script:targetTime) -and (Test-WorkerTimeJudgeActive)) {',
  '$env:HONEYNOGI_UNTIL_TIME = $script:targetTime.ToString(''yyyy-MM-dd HH:mm'', [Globalization.CultureInfo]::InvariantCulture)',
  '}')
Assert-Case 'T4-e 8: Start-NextCycle 의 UNTIL - 비움 → 전투 분기(판단 워커만, InvariantCulture 생산 - 리뷰 P2), 생활 분기 없음 (생활 확장 A안)' (Get-PatternCount $nextCycleCode $envPattern) 1
Assert-Case 'T4-e 8: UNTIL 대입은 GUI 전체에 비움·전투 두 곳뿐 · 사이클 추정치 env 0건 · 현재 문화권 생산식 0건' ('{0}/{1}/{2}' -f (Get-TextCount $guiCode '$env:HONEYNOGI_UNTIL_TIME ='), (Get-TextCount $guiCode 'HONEYNOGI_CYCLE_ESTIMATE_SEC'), (Get-TextCount $guiCode '.ToString(''yyyy-MM-dd HH:mm'')')) '2/0/0'
Assert-Case 'T4-e 8: 판단 워커 판정 호출은 Start-NextCycle 1곳' (Get-CallOwners $guiAst 'Test-WorkerTimeJudgeActive') '1|Start-NextCycle'

# 9. 상태줄 꼬리 - 두 곳 모두 대분류별 문구 함수 (옛 꼬리 코드가 남으면 전투에 옛 문구)
$suffixCallLine = '$statusSuffix = Get-TimeStatusSuffix -TargetTime $script:targetTime -MainCategory $script:mainCategory'
Assert-Case 'T4-e 9: 상태줄 꼬리 호출 원문 2곳 · 옛 꼬리 코드 0건' ('{0}/{1}' -f (Get-TextCount $guiCode 'Get-TimeStatusSuffix -TargetTime $script:targetTime -MainCategory $script:mainCategory'), (Get-TextCount $guiCode '" ($($script:targetTime.ToString(''HH:mm'')) 까지)"')) '2/0'
Assert-Case 'T4-e 9: 회차 시작 상태줄이 꼬리 변수를 씀 (Start-NextCycle)' (Get-PatternCount $nextCycleCode (New-SequencePattern @($suffixCallLine, '$lblStatus.Text = "${cycleNumber}회차 실행 중...$statusSuffix"'))) 1
Assert-Case 'T4-e 9: 안전 중지 취소 상태줄도 같은 함수 (버튼 처리기)' (Get-PatternCount $guiCode (New-SequencePattern @($suffixCallLine, '$lblStatus.Text = "$($script:completedCycles + 1)회차 실행 중...$statusSuffix (안전 중지 취소됨)"'))) 1

# 10. 설명서의 '[반복 - 시간 지정]' 문단 - 전투는 공통 머리말, 생활은 생활 설명서 자기 문단('사이클' 말투 - 생활 확장 2.5), 기타는 없음.
#     우변(문자열 결합)을 그대로 평가해 실제 글자로도 봅니다
function Get-GuiAssignRight {
  # 그 변수의 대입문이 정확히 1개면 우변 원문, 아니면 '' (개수는 따로 단언 - 이름이 바뀌어 0개가 되면 빈 참을 막기 위해)
  param([string]$VariableText)
  $found = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq $VariableText) }, $true))
  return [pscustomobject]@{ Count = $found.Count; Right = $(if ($found.Count -eq 1) { [string]$found[0].Right.Extent.Text } else { '' }) }
}
$manualAssign = Get-GuiAssignRight '$manualCommon'
$lifeManualAssign = Get-GuiAssignRight '$lifeManualText'
$etcManualAssign = Get-GuiAssignRight '$etcManualText'
$manualRightText = $manualAssign.Right
$manualValue = $(if ($manualRightText) { [string](Invoke-Guarded { Invoke-Expression $manualRightText }) } else { '' })
$lifeManualValue = $(if ($lifeManualAssign.Right) { [string](Invoke-Guarded { Invoke-Expression $lifeManualAssign.Right }) } else { '' })
Assert-Case 'T4-e 10: 문단 머리 - 공통 머리말 대입 1·그 안 1 / 생활 설명서 대입 1·그 안 1 / 기타 설명서 대입 1·그 안 0 / GUI 전체(주석 제외) 2' ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $manualAssign.Count, (Get-TextCount $manualRightText '"[반복 - 시간 지정]`n" +'),
    $lifeManualAssign.Count, (Get-TextCount $lifeManualAssign.Right '"[반복 - 시간 지정]`n" +'), $etcManualAssign.Count, (Get-TextCount $etcManualAssign.Right '[반복 - 시간 지정]'), (Get-TextCount $guiCode '[반복 - 시간 지정]')) '1/1/1/1/1/0/2'
$lifeHeadAt = $lifeManualValue.IndexOf('[반복 - 시간 지정]')
$lifeSettingsAt = $lifeManualValue.IndexOf('[설정]')
$lifeCustomAt = $lifeManualValue.IndexOf('[커스텀 반복]')
$lifeParagraph = $(if (($lifeHeadAt -ge 0) -and ($lifeCustomAt -gt $lifeHeadAt)) { $lifeManualValue.Substring($lifeHeadAt, $lifeCustomAt - $lifeHeadAt) } else { '' })
Assert-Case "T4-e 10: 생활 문단 - [설정] 뒤·[커스텀 반복] 앞 · 규칙 첫 줄 · 내일 처리 줄 있음, 전투 말투('새 판'·'그 판')·상한 표현('최대 한 사이클') 없음, 완주·소요 조각 있음, 옛 [설정] '채집 대기'·'권장 1200초' 없음" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}/{7}/{8}' -f
    [int](($lifeSettingsAt -ge 0) -and ($lifeSettingsAt -lt $lifeHeadAt) -and ($lifeHeadAt -lt $lifeCustomAt)),
    [int]$lifeParagraph.Contains("[반복 - 시간 지정]`n - 지정한 시각이 지나면 새 사이클을 시작하지 않습니다.`n"),
    [int]$lifeParagraph.Contains(' - 오늘 그 시각이 이미 지났으면 내일 그 시각으로 잡습니다.'),
    [int]($lifeParagraph.Contains('새 판') -or $lifeParagraph.Contains('그 판')),
    [int]$lifeManualValue.Contains('최대 한 사이클'),
    [int]$lifeParagraph.Contains('퀘스트가 사라질 때(1회 완료)까지'),
    [int]$lifeParagraph.Contains('(대상·수량·이동 거리에 따라 수 분~수십 분).'),
    [int]$lifeManualValue.Contains('채집 대기:'),
    [int]$lifeManualValue.Contains('권장 1200초')) '1/1/1/0/0/1/1/0/0'
Assert-Case 'T4-e 10: 문단은 단축키 줄 뒤 · 생활·기타 설명서는 공통 머리말보다 앞에서 반환' ('{0}/{1}' -f [int]($manualValue.IndexOf('(게임 화면에서도 동작합니다)') -ge 0 -and $manualValue.IndexOf('(게임 화면에서도 동작합니다)') -lt $manualValue.IndexOf('[반복 - 시간 지정]')),
    [int](($guiCode.IndexOf("'생활 설명서'") -ge 0) -and ($guiCode.IndexOf("'기타 설명서'") -ge 0) -and ($guiCode.IndexOf("'생활 설명서'") -lt $guiCode.IndexOf('$manualCommon = ')) -and ($guiCode.IndexOf("'기타 설명서'") -lt $guiCode.IndexOf('$manualCommon = ')))) '1/1'
Assert-Case "T4-e 10: 문단 내용 - 규칙·끝 모양·파티원 따라감·내일 처리 줄 있음, '2분'(두 PC 안내 - 10-02 결정 Q1)·'최대 한 판'(이월 예외와 어긋남) 없음" ('{0}/{1}/{2}/{3}/{4}/{5}' -f
    [int]$manualValue.Contains("[반복 - 시간 지정]`n - 지정한 시각이 지나면 새 판을 시작하지 않습니다. 그 전에 시작한 판은`n   끝까지 하고 멈추므로 지정 시각보다 늦게 끝납니다."),
    [int]$manualValue.Contains(" - 멈추는 모습은 횟수 지정의 마지막 판과 같습니다: 던전·심층·파티원은`n   '나가기'로 필드에 나와 멈추고, 어비스 혼자하기·파티장은 선택 화면,`n   사냥터는 첫 화면에서 멈춥니다."),
    [int]$manualValue.Contains(' - 파티원은 파티장이 다음 판을 이미 시작했으면 그 판까지 따라간 뒤 나옵니다.'),
    [int]$manualValue.Contains(' - 오늘 그 시각이 이미 지났으면 내일 그 시각으로 잡습니다.'),
    [int]$manualValue.Contains('2분'), [int]$manualValue.Contains('최대 한 판')) '1/1/1/1/0/0'

# 11. 판단 워커 판정 본문 원문 (설계 2.5 · v11 R3 4.1 - 셋째 항은 어비스 콘텐츠 라디오, 매칭·역할 라디오는 보지 않음. 행동이 같은 다른 모양(예: 사냥터가 아님)은
#     이 원문 단언만 잡습니다 - 변이 R3-M5)
Assert-Case 'T4-e 11: Test-WorkerTimeJudgeActive 본문 = 전투 · 비커스텀 · (던전 · 심층 · 어비스) - 설계 v11 R3 Q3' (Get-PatternCount $judgeActiveCode (New-SequencePattern @('return (($script:mainCategory -eq ''battle'') -and (-not $script:customActive) -and', '($rbCatDungeon.Checked -or $rbCatDeep.Checked -or $rbCatAbyss.Checked))'))) 1

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
  @{ N = 13; D = '생활 · 지정 1초 전 → 다음 (진행 없음 한도 추정치 없음 - 생활 확장)'; Code = 0; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget.AddSeconds(-1); Cat = 'life'; Act = 'next'; Log = ''; Color = $colorKept }
  @{ N = 14; D = '생활 · 지정 시각 → 정지 + 생활 안내 (새 사이클)'; Code = 0; Stop = $false; Cycles = 0; Done = 2; Streak = 0; Target = $baseTarget; Now = $baseTarget; Cat = 'life'; Act = $stopTime; Log = $stopNoticeLife; Color = 'DimGray' }
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
  # 시간 지정 블록(목표 시각 계산 → 기타 게이트 → 시작 로그)을 소스 그대로 실행합니다 - 점소싱(규칙 3).
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
  @{ N = 'g6'; D = "생활 · 남은 90초(진행 없음 한도 ${gatherLimit}초보다 짧음) → 거부 없이 시작 + 생활 시작 로그 (생활 확장 조건 2)"; Cat = 'life'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 18, 30); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '2026-10-01 21:20:00.000'; XLog = $startNoticeLife }
  @{ N = 'g7'; D = '생활 · 남은 1200초 → 시작 + 생활 시작 로그'; Cat = 'life'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 0, 0); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '2026-10-01 21:20:00.000'; XLog = $startNoticeLife }
  @{ N = 'g8'; D = '기타 · 남은 90초 < 클리어 대기 → 거부 문구 원문 (해당 없음 - 지금 그대로)'; Cat = 'etc'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 18, 30); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '(없음)'; XLog = "[안내] 지정 시간(21:20)까지 남은 시간이 클리어 대기(${clearLimit}초)보다 짧아 시작할 수 없습니다." }
  @{ N = 'g9'; D = "기타 · 남은 1200초(클리어 대기 ${clearLimit} 이상) → 시작 + 옛 시작 로그"; Cat = 'etc'; Queue = @(); Now = [datetime]::new(2026, 10, 1, 21, 0, 0); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
    XTarget = '2026-10-01 21:20:00.000'; XLog = $startNoticeEtc }
  @{ N = 'g10'; D = '생활 · 정각 직전 [시작] - 목표 계산은 21:19:59.9, 그 뒤 판단 시각은 21:20:00.1 (생활이 게이트를 타면 거부 문구가 찍히고 목표가 지워짐)'; Cat = 'life'
    Queue = @([datetime]::new(2026, 10, 1, 21, 19, 59, 900), [datetime]::new(2026, 10, 1, 21, 19, 59, 900)); Now = [datetime]::new(2026, 10, 1, 21, 20, 0, 100); Until = [datetime]::new(2000, 1, 1, 21, 20, 0)
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
Assert-Case 'T4-h 추출: UNTIL 비움부터 [완료] 사유 초기화 앞까지 = 비움 1줄 + 전투 if 1개 (생활 분기·사이클 추정치 줄 없음)' (@($envSegment | ForEach-Object { $_.GetType().Name }) -join ',') 'AssignmentStatementAst,IfStatementAst'
if ($envSegment.Count -gt 0) { $envBlock = [scriptblock]::Create((@($envSegment | ForEach-Object { $_.Extent.Text }) -join "`n")) }
function Invoke-UntilEnvBlock {
  # UNTIL 구간을 소스 그대로 실행합니다 - 점소싱(규칙 3). 결과는 이 프로세스의 $env:HONEYNOGI_UNTIL_TIME
  if ($null -eq $envBlock) { throw 'UNTIL 구간을 추출하지 못했습니다' }
  . $envBlock
}
$t4hRows = @(
  @{ N = 'h1'; D = '생활 + 시간 지정 → 없음 (GUI 가 사이클이 끝난 뒤 판단 - 생활 확장 A안)'; Cat = 'life'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h2'; D = '던전 + 시간 지정 → UNTIL (신설)'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h3'; D = '심층 + 시간 지정 → UNTIL (신설)'; Cat = 'battle'; Content = 'deep'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h4'; D = '어비스 함께하기 파티원 + 시간 지정 → UNTIL 만 (사이클 추정치 없음)'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h5'; D = '어비스 혼자하기 → UNTIL (설계 v11 R3 Q3)'; Cat = 'battle'; Content = 'abyss'; Mode = 'solo'; Matching = 'member'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h6'; D = '어비스 함께하기 파티장 → UNTIL (설계 v11 R3 Q3)'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'lead'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h7'; D = '사냥터 → 없음'; Cat = 'battle'; Content = 'hunting'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h8'; D = '기타 + 보존된 던전 라디오 → 없음 (기타 워커는 UNTIL 을 받으면 그 시각에 뽑기를 마침)'; Cat = 'etc'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h9'; D = '기타 + 보존된 어비스 함께하기 파티원 라디오 → 없음'; Cat = 'etc'; Content = 'abyss'; Mode = 'party'; Matching = 'member'; Custom = $false; Target = $baseTarget; X = '' }
  @{ N = 'h10'; D = '던전 커스텀 → 없음'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $true; Target = $baseTarget; X = '' }
  @{ N = 'h11'; D = '던전 · 시간 지정 아님(목표 시각 없음) → 없음'; Cat = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $null; X = '' }
  @{ N = 'h12'; D = '생활 · 시간 지정 아님 → 없음 (앞 회차 값도 먼저 지움)'; Cat = 'life'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance'; Custom = $false; Target = $null; X = '' }
  # h13~h15 설계 v11 R3 5.1 U6~U8 - 어비스는 매칭·역할 라디오와 무관하게 받고(파티 찾기는 받기만), 커스텀은 받지 않음
  @{ N = 'h13'; D = '어비스 함께하기 우연한 만남 → UNTIL (설계 v11 R3 Q3)'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'chance'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h14'; D = '어비스 함께하기 파티 찾기 → UNTIL (받기만 - 설계 v11 R3 4.2)'; Cat = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'find'; Custom = $false; Target = $baseTarget; X = '2026-10-01 21:20' }
  @{ N = 'h15'; D = '어비스 혼자하기 커스텀 → 없음 (커스텀은 받지 않음 - 설계 v11 R3 Q3)'; Cat = 'battle'; Content = 'abyss'; Mode = 'solo'; Matching = 'chance'; Custom = $true; Target = $baseTarget; X = '' }
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
Assert-Case '실행 행 수 T4-a/T4-b/T4-c/T4-f/T4-g/T4-h/P2' ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $t4aRun, $t4bRun, $t4cRun, $t4fRun, $t4gRun, $t4hRun, $p2Run) '17/12/14/15/10/15/12'

[Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
$env:HONEYNOGI_UNTIL_TIME = $originalUntilEnv
$env:HONEYNOGI_CYCLE_ESTIMATE_SEC = $originalEstimateEnv
if ($fails -gt 0) { "FAIL 합계: $fails"; exit 1 }
'OK 전체 통과'
exit 0
