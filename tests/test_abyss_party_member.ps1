# 어비스 '파티(파티원)' 관측 루프 D·퇴장 절차 P 회귀 (⑥e 설계 5.1 - 2026-10-01 설계 합의)
#
# 배경: ⑥a 의 파티원 '두 출구'(S 터치 헬퍼 + 보상 '나가기' 뒤 필드 복귀 루프)를 관측 루프 D(Invoke-AbyssPartyMemberCycle) 하나와
# 퇴장 절차 P(Invoke-AbyssMemberLeave) 하나로 바꿨다. D 는 어느 화면에서 시작해도 화면을 분류해 이어받고, 클리어 뒤 첫 신호(회차 경계)에서
# 다음 워커에게 인계(exit 0 - 시간 지정이면 exit 11)하며, 정지 사유(마지막 회차·안전 중지·지정 시간·대기 한도 M·준비 시계)가 있을 때만 P('나가기' 로 필드를
# 확인한 뒤 정지)를 탄다. 'left'(필드 확인)는 끊김 없이 관측된 퇴장 전이 계약(무장 → 떠남 → 도착, 사이에 끊김·커밋 없음)으로만 나온다 -
# HUD + 추적기 던전명 없음은 던전 안 추적기 오독(09-21 7/10·09-25 4/9·09-29 2/6)과 입장 과도에서도 2초 넘게 이어져 필드 증거가 못 된다.
# 시간 지정 '그 판까지' (2026-10-02, 그 설계 8.1·8.2): G 의 'time' = 지금 >= 지정 시각(추정치·여유 없음), 지정 시각 전의 경계 인계 12곳은 exit 11
# (GUI 가 지정 시각을 보지 않고 이어받음). 체인 하니스는 GUI 소스의 다음 회차 판단 함수(GUI 모형)로 다음 워커를 띄울지 정한다.
# 여기서 고정하는 계약 (설계 5.1 절 번호 그대로):
#   §0 소스 값 캡처 - 스크립트 상수 6개·클릭 좌표·판독 영역·대기 한도를 AST 대입문에서 캡처한다(사본 금지). W 4.2 < 6 < 30,
#      스윕 연속 한도 3 범위 단언은 상수 변이를 잡는 유일한 자리다 (진리표·행동 케이스는 캡처값으로 기대를 다시 계산한다).
#      시간 게이트 여유 상수·사이클 추정치 env 는 워커 전체(주석 뺀 사본) 0건이다 (시간 지정 '그 판까지' - ⑥e ㉰ 폐기).
#   §1 순수 진리표 (항상 실행 - 판독문은 재생 실측 그대로): (a) 화면 분류 (a2) 보상 위 판별 (b) 재펼침 앵커 (c) 나가기 단어 (d) 정지 게이트 G
#      (e) 시계 헬퍼 (f) 파티원 보상 게임 상태 (g) 클리어 감시 반환 (h) 클리어 감시 마감 탐침 (i) 퇴장 전이 표 36칸 + 사건 열 i1~i25
#      (j) 스윕 참 회전 생략 사유 (k) 화면 라벨
#   §2 행동 하니스 - 운영 D·P 를 AST 로 추출해 가상 시계·화면 계획표·판독 모의 위에서 실행한다. exit N 은 센티널 throw 로 바꾸고(치환 뒤 다시
#      파싱해 ExitStatementAst 0건 확인), 가상 20000초·판독 5만 회·스윕 5만 회를 넘으면 '__VTIMEOUT__' 으로 끝낸다(러너에는 자식 시간 제한이 없음).
#      케이스 ID(A·B·C·K·R·X·X-M·S·RC·SP·SJ)는 설계 5.1 표 그대로다. 미관측 전이·조합은 케이스 이름에 그 사실을 적는다(규칙 8).
#   §3 배선 - 주석 뺀 D·P 본문과 새 헬퍼 집합만 범위로 회전 순서·동결 블록·스윕 참 분기·복구 회전·퇴장 전이·클릭 계약·exit 모양을 단언한다
#   §4 클리어 감시 -MemberMode 배선   §5 GUI 배선(파티원 env 분기·설명서·시작 안내)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
function Check-True {
  # 범위·복합 조건 단언 - 실패 줄에 실제 값(Detail)을 함께 남겨 원인을 바로 볼 수 있게 합니다
  param([string]$Name, [bool]$Condition, [string]$Detail = '')
  if ($Condition) { "OK   $Name" }
  else { "FAIL $Name ($Detail)"; $script:fails++ }
}

# ── §0 소스 값 캡처 ─────────────────────────────────────────────────────────────
# 스크립트 상수는 워커 최상위 대입문(함수 밖)을 AST 로 찾아 우변을 평가합니다. config 를 읽는 대입문(좌표·판독 영역·대기 한도)은
# Get-ConfigValue / Get-ConfigInteger 를 '기본값 반환' 모의로 두고 평가합니다 - 사본 값(예: 옛 하니스의 @(1030,655))을 쓰지 않기 위함입니다.
$workerTokens = $null; $workerErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$workerTokens, [ref]$workerErrors)
if ($workerErrors.Count -gt 0) { throw "워커 파서 오류: $($workerErrors[0].Message)" }
# 큰 소스(워커·GUI)의 '주석 뺀 사본'은 토큰으로 한 번에 만듭니다 (Remove-SourceComments 의 문자열 치환 반복은 1MB 에서 느림).
# 정의를 §0 앞에 두는 이유 (시간 지정 '그 판까지' 설계 리뷰 1차 P3): §0 의 0건 단언이 이 사본을 쓰는데, 파일 머리가
# $ErrorActionPreference = 'Stop' 이라 정의보다 앞에서 부르면 파일 전체가 거기서 멈춥니다 (옛 정의 자리는 §3 디스패치 앞이었음)
function Remove-CommentsByTokens {
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
$workerCode = Remove-CommentsByTokens $workerAst.Extent.Text $workerTokens   # §0 0건 단언 · §3 디스패치 · §4 가 함께 씀
function Test-AstInsideFunction {
  # 대입문이 함수 정의 안에 있는지 (같은 이름의 지역 변수 대입을 상수로 잘못 잡지 않게)
  param($Node)
  $parent = $Node.Parent
  while ($null -ne $parent) {
    if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $true }
    $parent = $parent.Parent
  }
  return $false
}
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
function Get-ConfigInteger { param([object]$Root, [string[]]$Path, [int]$Default, [int]$Minimum, [int]$Maximum) return $Default }
$config = $null
function Get-SourceAssignmentValue {
  # 최상위 첫 대입문의 우변을 평가해 돌려줍니다 (없으면 throw - 상수가 사라진 것 자체가 결함)
  param([string]$Name)
  $node = $workerAst.FindAll({
      param($n)
      $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq ('$' + $Name)
    }, $true) | Where-Object { -not (Test-AstInsideFunction $_) } | Sort-Object { $_.Extent.StartOffset } | Select-Object -First 1
  if (-not $node) { throw "소스 상수 대입문을 찾지 못했습니다: `$$Name" }
  return (Invoke-Expression $node.Right.Extent.Text)
}
$memberReadyLimitSeconds = Get-SourceAssignmentValue 'memberReadyLimitSeconds'
$memberLeaveLimitSeconds = Get-SourceAssignmentValue 'memberLeaveLimitSeconds'
$memberUnknownOverlaySeconds = Get-SourceAssignmentValue 'memberUnknownOverlaySeconds'
$memberFieldSettleSeconds = Get-SourceAssignmentValue 'memberFieldSettleSeconds'
$memberSweepStreakLimit = Get-SourceAssignmentValue 'memberSweepStreakLimit'
$ptMemberPanelCollapse = @(Get-SourceAssignmentValue 'ptMemberPanelCollapse')
$ptPartyEnter = @(Get-SourceAssignmentValue 'ptPartyEnter')
$ptClearCenter = @(Get-SourceAssignmentValue 'ptClearCenter')
$rgClearExit = @(Get-SourceAssignmentValue 'rgClearExit')
$rgPartyEnterBtn = @(Get-SourceAssignmentValue 'rgPartyEnterBtn')
$rgQuestTracker = @(Get-SourceAssignmentValue 'rgQuestTracker')
$allDungeonKeywords = @(Get-SourceAssignmentValue 'allDungeonKeywords')   # 첫 대입(내장 목록) - 추적기 판독문을 운영 Test-InDungeonQuest 로 판정하기 위함
$timeoutClear = Get-SourceAssignmentValue 'timeoutClear'                  # 486 대입문 = Get-ConfigInteger 기본값 (M = 클리어 대기 설정)
$timeoutPartyMatch = Get-SourceAssignmentValue 'timeoutPartyMatch'        # 시작 패널 입장 대기·시작 패널 판정 한도 (SP·SJ)
$capturedTimeoutClear = $timeoutClear                                        # C3·C14 가 잠시 바꾼 뒤 케이스마다 되돌리는 원본
$ocrKoreanEngine = 'ko'
"INFO 캡처: 준비 시계 $memberReadyLimitSeconds / P 한도 $memberLeaveLimitSeconds / 알 수 없음 $memberUnknownOverlaySeconds / W $memberFieldSettleSeconds / 스윕 한도 $memberSweepStreakLimit / 접기 $($ptMemberPanelCollapse -join ',') / 준비 $($ptPartyEnter -join ',') / 터치 $($ptClearCenter -join ',') / M $timeoutClear / 재매칭 $timeoutPartyMatch"
# 시간 게이트에는 상수·추정치가 없습니다 (시간 지정 '그 판까지' 설계 4.1·4.2·8.1): G 의 'time' 은 '지금 >= 지정 시각' 하나이고, 지정 시각 전에
# 이어 간 경계는 종료 코드 11 로 GUI 가 지정 시각을 다시 보지 않고 이어받습니다 - ⑥e ㉰ 의 여유 5초와 GUI 가 넘기던 사이클 추정치 env 는 폐기됐습니다.
# 둘 중 하나라도 되살아나면 G 진리표((d))·B14 가 다시 '추정치 + 여유' 를 전제하게 되므로 워커 전체(주석 뺀 사본)에서 0건을 단언합니다
# (주석에 옛 이름이 남아도 거짓 실패하지 않게 주석은 뺍니다 - 단언은 코드에 걸어야 함)
$marginConstantRefs = [regex]::Matches($workerCode, 'memberTimeGateMarginSeconds').Count
$estimateEnvRefs = [regex]::Matches($workerCode, 'HONEYNOGI_CYCLE_ESTIMATE_SEC').Count
Check-Equal '§0 시간 게이트 여유 상수(memberTimeGateMarginSeconds)·사이클 추정치 env(HONEYNOGI_CYCLE_ESTIMATE_SEC) 0건 (워커 전체, 주석 뺀 사본)' "$marginConstantRefs/$estimateEnvRefs" '0/0'
# W 범위: 관측 입장 과도 상한(09-21 185241_363 → 185245_580 inside, 4.2초 미만)보다 커야 'stayed-field' 가 입장 중인 파티원을 멈추지 않고,
# 위쪽 30 은 P 마감 60초의 절반입니다. 실기 계측 s 최대 m 이 W 이상이면 이 단언도 W 도 고치지 않습니다(재설계 대상 - ㉷)
Check-True "§0 W 범위 4.2 < W < 30 (캡처 $memberFieldSettleSeconds)" (([double]$memberFieldSettleSeconds -gt 4.2) -and ([double]$memberFieldSettleSeconds -lt 30)) "W=$memberFieldSettleSeconds"
# 스윕 연속 한도: 관측된 겹친 팝업 2개(2026-08-01 물약 부족 + 협동 미션 완료)를 넘는 연속만 굶김으로 봅니다(㉺). 2 이하면 관측된 겹침에서
# 굶김 회전이 생기고, 크게 올리면 굶김 진입이 늦어집니다
Check-Equal '§0 스윕 연속 한도 = 3 (관측된 겹친 팝업 2개를 넘는 연속만 굶김)' $memberSweepStreakLimit 3
Check-Equal '§0 M = 클리어 대기 설정 기본값 600 (486 대입문을 Get-ConfigInteger 모의로 평가)' $timeoutClear 600
Check-Equal '§0 접기 좌표 = 보상 위 펼친 패널 밖 나가기 자리 (492,654) - 09-29 재생 4/8 프레임' ($ptMemberPanelCollapse -join ',') '492,654'

# ── 운영 함수 추출 (사본 재구현 금지) ─────────────────────────────────────────
# 순수 함수·시계·퇴장 전이·판정 보조는 그대로 올리고, D·P 와 클리어 감시 탐침은 §2 에서 exit 센티널로 바꿔 올립니다.
$pureNames = @('Resolve-AbyssMemberScreen', 'Test-AbyssPanelOverRewardText', 'Resolve-AbyssMemberClearWaitExit', 'Select-AbyssEntryWaitingAnchor',
  'Select-AbyssMemberLeaveWord', 'Get-AbyssMemberStopReason', 'Get-AbyssMemberScreenLabel', 'Resolve-AbyssMemberSweepTurn',
  'New-AbyssMemberClock', 'Update-AbyssMemberClockFreeze', 'Set-AbyssMemberClock', 'Suspend-AbyssMemberClock', 'Resume-AbyssMemberClock',
  'Test-AbyssMemberClockExpired', 'New-AbyssMemberLeaveTransition', 'Update-AbyssMemberLeaveTransition', 'Test-AbyssMemberClearWaitProbe',
  'Get-FreezeAdjustedDeadline', 'Get-YieldAdjustedDeadline', 'Get-LifeUntilDeadline', 'Test-AbyssMemberReward', 'Test-AbyssMemberRewardText',
  'Test-AbyssEntryWaitingText', 'Test-AbyssRewardText', 'Get-AbyssReadyButtonState', 'Select-AbyssExitWord', 'Test-InDungeonQuest')
$sourceDefs = @{}
foreach ($name in $pureNames) {
  $sourceDefs[$name] = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name))
  Invoke-Expression $sourceDefs[$name]
}

# ── §1 순수 진리표 (항상 실행 - 판독문은 재생 실측 그대로) ───────────────────────
# 실측 판독문 출처: 09-29 ⑥a 실기1 frames(던전이미지\어비스\20260929_⑥a_실기1_파티원2인) · 09-26 준비패널4인 · 09-21 파티원2인/4인 폴더를
# 워커와 같은 영역·배율·엔진(clearAndExitText (430,570,420,125) 배율 3 ko / partyEnterButton (900,630,260,48) 배율 4 / questTracker 배율 3)으로
# 오프라인 판독한 문자열 그대로입니다 (tools\ocr_offline_regions.ps1 - 2026-10-01 재판독, 설계 작성자 주의 재생 결과와 글자 단위 일치).
function W { param([string]$Text, [int]$X, [int]$Y = 654) @{ Text = $Text; X = $X; Y = $Y } }
# 추적기 판독문 → 던전 안 여부는 운영 Test-InDungeonQuest(내장 키워드 '정박'·'광기'·'물길')로 판정합니다 - 오독 문자열이 실제로 거짓이 되는지까지 봄
$script:pureOcrText = ''
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine, [switch]$BinaryWhiteText) return [string]$script:pureOcrText }
function Get-TrackerQuest { param([string]$Text) $script:pureOcrText = $Text; return [bool](Test-InDungeonQuest -Game $null) }
$trk = [ordered]@{
  inside0929   = '11:00뮈스트十-허상의정박지클리어•파티부활6회이내로글리어'          # cap_211244_025 (09-29 3판 입장 뒤 던전 안)
  inside0921   = '010:59뮈스트十수광기의동굴클리어부활6회이내로들리어'               # cap_185245_580 (09-21 입장 과도 뒤 첫 inside)
  field0929    = '추천밴스트十!목표]모험가길드의성기의회'                            # cap_210525_840 (09-29 1판 나가기 뒤 필드)
  misreadA     = '1021뮈스트十수허상의정-지클리어•파티부활6회이내皀글리어'          # error_20260929_h21m06s37 (던전 안 - '정박' 탈락, 관측 5)
  misreadB     = '견인09•43뮈스트十수허상의。박지클리어iLlEl부활6회이내로글리어'   # error_20260929_h21m17s34
  transient1   = '11:00뮈스트十'                                                  # cap_185241_363 (09-21 입장 과도 1)
  transient2   = '11:00뮈스트十-기의동굴클리어부활6회이내로글리어'                 # cap_185242_423 (09-21 입장 과도 2)
  transient3   = '11:00뮈스트十-뚀h기의동굴클리어부활6회이내로들리어'              # cap_185243_493 (09-21 입장 과도 3)
  transient0929 = '0C11:000뮈스트十흠:상으]집드:•-고•뇨가E!6회0!-h르들리'        # cap_211242_966 (09-29 3판 입장 과도)
  matching0921 = '[주간목표]모험가길드의정기의뢰|口회길=이고난도심査곹럌'            # cap_184838_830 (재매칭 - HUD 참·추적기 거짓)
  arrival0929  = '추천뙨스트十!목표]모험가길드의정기의뢰'                            # cap_211009_900 (필드 도착 - HUD 글자 미표시)
}
Check-Equal '§1 추적기 전제: 던전 안 2종 참 / 필드·오독 2종·입장 과도 4종·재매칭 거짓 (운영 Test-InDungeonQuest)' (
  (@('inside0929', 'inside0921', 'field0929', 'misreadA', 'misreadB', 'transient1', 'transient2', 'transient3', 'transient0929', 'matching0921') |
    ForEach-Object { [int](Get-TrackerQuest $trk[$_]) }) -join '') '1100000000'

# (a) Resolve-AbyssMemberScreen + 보상 위 판별 ($overReward = 패널 'ready' AND Test-AbyssPanelOverRewardText)
function Get-ScreenRow {
  # 한 행 = 판독 입력 → 운영 분류와 보상 위 판별 ("분류/보상위")
  param([bool]$Prompt, [string]$Bottom, [string]$Panel, [bool]$Hud, [string]$Tracker = '', [string]$Button = '')
  $quest = $(if ($Hud) { Get-TrackerQuest $Tracker } else { $false })
  $state = $(if ($Panel -eq 'ready') { Get-AbyssReadyButtonState -Text ($Button -replace '\s', '') } else { 'none' })
  $screen = Resolve-AbyssMemberScreen -PromptVisible $Prompt -BottomText $Bottom -PanelKind $Panel -HudVisible $Hud -InDungeonQuest $quest -ButtonState $state
  $over = ($Panel -eq 'ready') -and (Test-AbyssPanelOverRewardText -Text $Bottom)
  return "$screen/$over"
}
$b = [ordered]@{
  ready211944  = '아이템을누르면상세정보를모든Space나가기'                  # cap_211944_558 (09-29 보상 위 준비 패널)
  readyM2p1    = '0田I들1을누르면&)dl정보를Space모든'                     # 09-26 M2+1
  readyL3      = '아이템을누르면상세정보를모든'                            # 09-26 L3 (파티장 준비 취소 상태, 보상 위)
  readyM51     = '아이템을누르면상세정보를긴나가기모든Space'               # 09-26 M5-1 (패널 소멸 혼합 1초 - 나가기@515)
  entry        = '아이템을누르면상세정보를수있습니다나가기입장대기중'      # cap_212409_212
  entryM4pre   = '아이템을누르면상세정보를수있습니다나가기자대기중'        # 09-26 M4-pre (커서가 '입장' 을 가림 - test_abyss_party_signatures entryCur 와 같은 판독)
  occluded1    = '아이템을누르면상세정보를수있습니다나가기입장대가축'      # cap_211946_682 (커서가 '입장 대기 중' 을 가림)
  occluded2    = '아이템을누르면상세정보를수있습니다나가기입장[중'         # cap_212938_431
  member       = '아이템을누르면상세정보를를수있습니다나가기파티장선택대기' # cap_211928_495
  matching0918 = '사제아이템을누르면상세정보를7나가기'                     # 09-18 재매칭 패널 (매칭 취소 '나가기')
  prompt       = '화면을터치해주세요'                                      # 09-21 S4
  reward3      = '아이템을누르면상세정보테볼수있습니다나가기Space다세하기다른던전가기'   # 09-18 3버튼 보상
  itemPopup    = '아이템을누르면상)`引정보를수있습니다Space확인'           # cap_211927_433 (아이템 상세 팝업)
  click210520  = '아이템을누르면상세정보를를수있습니다파티장선택대기'      # cap_210520_595 (커서가 '나가기' 를 가린 클릭 프레임)
  arrivalNoise = '&여h결'                                                   # cap_211608_902 (던전 도착 잡음 조각)
}
$aRows = @(
  @('cap_211944_558 보상 위 준비 패널 → ready-available·보상 위', (Get-ScreenRow $false $b.ready211944 'ready' $false '' '준비완료'), 'ready-available/True'),
  @('09-26 M2+1 → ready-available·보상 위', (Get-ScreenRow $false $b.readyM2p1 'ready' $false '' '준비완료'), 'ready-available/True'),
  @("09-26 L3 '준비취소' → ready-done·보상 위", (Get-ScreenRow $false $b.readyL3 'ready' $false '' '준비취소'), 'ready-done/True'),
  @("cap_210545_900 필드 위, 버튼 '주년``완료' → ready-other·보상 위 아님", (Get-ScreenRow $false 'Space' 'ready' $false '' '주년`완료'), 'ready-other/False'),
  @("M1 필드 위(HUD·추적기 거짓, 하단 'Space') → ready-available·보상 위 아님", (Get-ScreenRow $false 'Space' 'ready' $false '' '준비완료'), 'ready-available/False'),
  @("cap_210547_992 하단 '모Space' → ready-available·보상 위 아님", (Get-ScreenRow $false '모Space' 'ready' $false '' '준비완료'), 'ready-available/False'),
  @("09-21 B3 하단 '' → ready-available·보상 위 아님", (Get-ScreenRow $false '' 'ready' $false '' '준비완료'), 'ready-available/False'),
  @('M5-1 혼합 1초(나가기@515 - 접기 좌표가 보상 나가기 안) → ready-available·보상 위', (Get-ScreenRow $false $b.readyM51 'ready' $false '' '준비완료'), 'ready-available/True'),
  @('cap_212409_212 접힌 패널 → entry-waiting', (Get-ScreenRow $false $b.entry 'none' $false), 'entry-waiting/False'),
  @("cap_211946_682 '…입장대가축'(커서 가림) → unknown", (Get-ScreenRow $false $b.occluded1 'none' $false), 'unknown/False'),
  @("cap_212938_431 '…입장[중'(커서 가림) → unknown", (Get-ScreenRow $false $b.occluded2 'none' $false), 'unknown/False'),
  @('cap_211928_495 파티원 보상 → member-reward', (Get-ScreenRow $false $b.member 'none' $false), 'member-reward/False'),
  @('파티원 보상 하단 + HUD 참 → field (HUD 조건)', (Get-ScreenRow $false $b.member 'none' $true $trk.field0929), 'field/False'),
  @('09-18 재매칭 → matching', (Get-ScreenRow $false $b.matching0918 'matching' $false), 'matching/False'),
  @('S(화면을 터치) → prompt', (Get-ScreenRow $true $b.prompt 'none' $false), 'prompt/False'),
  @('HUD·추적기 참 → inside', (Get-ScreenRow $false '' 'none' $true $trk.inside0929), 'inside/False'),
  @('09-18 3버튼 보상 → reward3', (Get-ScreenRow $false $b.reward3 'none' $false), 'reward3/False'),
  @("cap_211927_433 '…Space확인'(아이템 상세 팝업) → unknown", (Get-ScreenRow $false $b.itemPopup 'none' $false), 'unknown/False'),
  @("전부 '' → unknown", (Get-ScreenRow $false '' 'none' $false), 'unknown/False'),
  @("09-29 퇴장 로딩(cap_210521_682 등 - 하단 ''·패널 none·HUD 거짓·추적기 '') → unknown (떠남 표본)", (Get-ScreenRow $false '' 'none' $false ''), 'unknown/False'),
  @('09-29 필드 도착 cap_211009_900 / cap_213316_932 (HUD 글자 미표시) → unknown', (Get-ScreenRow $false '' 'none' $false $trk.arrival0929), 'unknown/False'),
  @("09-29 클릭 프레임 cap_210520_595('나가기' 가 커서에 가림) → unknown", (Get-ScreenRow $false $b.click210520 'none' $false), 'unknown/False'),
  @("09-29 오독 error_h21m06s37 (HUD 참·추적기 '…허상의정-지클리어…') → field (던전 안인데 필드 모양 - 관측 5 재현)", (Get-ScreenRow $false '' 'none' $true $trk.misreadA), 'field/False'),
  @("09-29 오독 error_h21m17s34 (추적기 '…허상의。박지클리어…') → field", (Get-ScreenRow $false '' 'none' $true $trk.misreadB), 'field/False'),
  @('입장 과도 09-21 cap_185241_363 → field', (Get-ScreenRow $false '' 'none' $true $trk.transient1), 'field/False'),
  @('입장 과도 09-21 cap_185242_423 → field', (Get-ScreenRow $false '' 'none' $true $trk.transient2), 'field/False'),
  @('입장 과도 09-29 cap_211242_966 → field', (Get-ScreenRow $false '' 'none' $true $trk.transient0929), 'field/False'),
  @("입장 로딩 09-21 cap_185237_205 / 09-29 cap_211239_838 (하단 ''·HUD 거짓) → unknown", (Get-ScreenRow $false '' 'none' $false ''), 'unknown/False'),
  @("던전 도착 cap_211608_902 (하단 잡음 조각·HUD 거짓) → unknown", (Get-ScreenRow $false $b.arrivalNoise 'none' $false), 'unknown/False'),
  @("컷신 cap_210853_776 (전부 '') → unknown", (Get-ScreenRow $false '' 'none' $false ''), 'unknown/False'),
  @('재매칭(파티원) 09-21 cap_184830_364 → matching', (Get-ScreenRow $false '사제' 'matching' $false), 'matching/False'),
  @('재매칭(파티원) 09-21 cap_184838_830 (HUD 참·추적기 거짓) → matching (순위 3 이 field 보다 먼저)', (Get-ScreenRow $false '사제' 'matching' $true $trk.matching0921), 'matching/False'),
  @('경합: ready + prompt → ready-*', (Get-ScreenRow $true $b.ready211944 'ready' $false '' '준비완료'), 'ready-available/True'),
  @('경합: matching + prompt → matching', (Get-ScreenRow $true '' 'matching' $false), 'matching/False'),
  @('경합: 접힌 패널 텍스트 + HUD → field', (Get-ScreenRow $false $b.entry 'none' $true $trk.field0929), 'field/False'),
  @('경합: prompt + inside → prompt', (Get-ScreenRow $true $b.prompt 'none' $true $trk.inside0929), 'prompt/False')
)
foreach ($row in $aRows) { Check-Equal "§1(a) $($row[0])" $row[1] $row[2] }

# (a2) Test-AbyssPanelOverRewardText - 보상 위 준비 패널 하단 19종 참 / 필드·상세 위 6종 거짓 (재생: 보상 위 19/19, 필드·상세 위 0/6)
$overRewardTexts = @(
  '아이템을누르면상세정보를Space모든', '아01템을누르면상)`Ⅱ정보를Space모든', '아이템을누르면상시|정보를Space모든',            # 09-29 211602·212407·212408
  '아이템을누르면상세정보를모든Space나가기', '아이템을누르면상세정보를모든Space나가기', '아이들ll을누르면상세정보를Space모든',   # 09-29 211944·211945·211947
  '아이템을누르면상세정보를나가기모든Space(0', '아이템을누르면상세정보를7나가기모든Space',                            # 09-29 212032·212939
  '아이템을누르면상세정보를모든', '0田I들!을누르면&)dl정보를모든', '0田I들1을누르면상人l|정보를모든',                     # 09-26 L3·L3c·L5p
  '아이템을누르면상)`引정보를나가기모든Space', '0田I들1을누르면&)dl정보를Space모든', '0田I들1을누르면상人l|정보를Space모든', # 09-26 M2·M2+1·M4-pre2
  '아이템을누르면상세정보를긴나가기모든Space',                                                                         # 09-26 M5-1
  '아이템을누르면상세정보를7Space나가기', '0田l들ll전누르면상세정보를모든', '0田l들1을누르면상)(Ⅱ정보를모든', '아이템을누르면상세정보를모든나가기'   # 09-21 B1·B2·C1·D1b
)
$fieldPanelTexts = @('', 'Space', '', '', 'Space', '모Space')   # 09-26 L1(파티장 필드) · M1 / 09-21 B3(필드) · E1(상세) / 09-29 210545 · 210547
Check-Equal '§1(a2) 보상 위 준비 패널 하단 19종 → 전부 참' ("$($overRewardTexts.Count)/" + (@($overRewardTexts | Where-Object { Test-AbyssPanelOverRewardText -Text $_ }).Count)) '19/19'
Check-Equal "§1(a2) 필드·상세 위 6종('', 'Space', '모Space') → 전부 거짓" ("$($fieldPanelTexts.Count)/" + (@($fieldPanelTexts | Where-Object { Test-AbyssPanelOverRewardText -Text $_ }).Count)) '6/0'
Check-Equal '§1(a2) $null → 거짓' (Test-AbyssPanelOverRewardText -Text $null) $false

# (b) Select-AbyssEntryWaitingAnchor - 접힌 패널 7프레임 앵커 (743,654) 7/7 (재생 확인), 고정 좌표 폴백 없음
$wEntryA = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591),
  (W '나가기' 492), (W '입장' 700), (W '대기' 743), (W '중' 776))                                                     # 212409·211959·212410·212411·212414 (같은 판독)
$wEntryB = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '를' 687 591), (W '수' 704 591),
  (W '있습니다' 742 591), (W '나가기' 492), (W '입장' 700), (W '대기' 743), (W '중' 776))                              # 212005·212937 ('를' 조각)
$wMember = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '를' 687 591), (W '수' 704 591),
  (W '있습니다' 742 591), (W '나가기' 515), (W '파티장' 714), (W '선택' 765), (W '대기' 808))                          # cap_211928_495
$wOccluded = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591),
  (W '나가기' 492), (W '입장' 702), (W '대가축' 754))                                                                 # cap_211946_682
$wExpanded = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '모든' 839 605), (W 'Space' 749 638),
  (W '나가기' 492))                                                                                                    # cap_211944_558 (펼친 패널)
$wM4pre = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591),
  (W '나가기' 492), (W '자대기중' 744))                                                                                # 09-26 M4-pre (커서가 '입장' 을 가림)
$wSplit = @((W '나가기' 492), (W '입장' 700), (W '대' 735), (W '기중' 760))                                            # 합성 - 이어 붙이면 서명 참, '대기' 담은 단어 없음 (C14 입력)
function Get-Pick { param($Word) if ($null -eq $Word) { 'null' } else { "$($Word.X),$($Word.Y)" } }
Check-Equal '§1(b) 접힌 패널 7프레임(212409·211959·212005·212937·212410·212411·212414) → (743,654) 7/7' (
  (@($wEntryA, $wEntryB, $wEntryB, $wEntryB, $wEntryA, $wEntryA, $wEntryA) | ForEach-Object { Get-Pick (Select-AbyssEntryWaitingAnchor -Words $_) }) -join ' ') '743,654 743,654 743,654 743,654 743,654 743,654 743,654'
Check-Equal "§1(b) M4-pre '자대기중'@744 → (744,654) (고정 좌표가 아니라 단어 중심)" (Get-Pick (Select-AbyssEntryWaitingAnchor -Words $wM4pre)) '744,654'
Check-Equal "§1(b) cap_211928 파티원 보상('대기'@808) → null" (Get-Pick (Select-AbyssEntryWaitingAnchor -Words $wMember)) 'null'
Check-Equal "§1(b) cap_211946 가린 접힘('대가축'@754) → null" (Get-Pick (Select-AbyssEntryWaitingAnchor -Words $wOccluded)) 'null'
Check-Equal '§1(b) cap_211944 펼친 패널 → null' (Get-Pick (Select-AbyssEntryWaitingAnchor -Words $wExpanded)) 'null'
Check-Equal '§1(b) @() → null' (Get-Pick (Select-AbyssEntryWaitingAnchor -Words @())) 'null'
Check-Equal "§1(b) 합성 '나가기'·'입장'·'대'·'기중' (서명 참, '대기' 담은 단어 없음 - C14 입력) → null" (Get-Pick (Select-AbyssEntryWaitingAnchor -Words $wSplit)) 'null'
# 합성 행 2개 (실측 판독 아님 - 순수 함수 진리표의 입력일 뿐 새 런타임 방어가 아닙니다, 규칙 7·8). 위 실측 행은 모두 두 서명 중 하나만 참이거나 '대기' 를
# 담은 단어가 없어서, ① 의 두 조건 중 하나를 지워도 결과가 같았습니다 (변이 검증 2026-10-01 - 두 변이 생존). 조건마다 그 조건만이 null 을 만드는 행:
#  - 두 서명이 함께 참 → 파티원 보상 서명 배제가 null 을 만듦 (배제가 없으면 '대기중'@808 을 고름)
#  - 두 서명이 함께 거짓인데 '대기' 단어가 있음('선택' 이 빠진 보상 판독 모양) → 접힌 패널 서명 조건이 null 을 만듦 (조건이 없으면 '대기'@808 을 고름)
$wBothSignatures = @((W '나가기' 515), (W '파티장' 714), (W '선택' 765), (W '대기중' 808))   # 합성 - 접힌 패널 서명 참 + 파티원 보상 서명 참
$wNoSignature = @((W '나가기' 515), (W '파티장' 714), (W '대기' 808))                        # 합성 - 두 서명 모두 거짓 ('대기중'·'선택' 없음)
$joinedBothSignatures = (@($wBothSignatures | ForEach-Object { $_.Text }) -join '')
$joinedNoSignature = (@($wNoSignature | ForEach-Object { $_.Text }) -join '')
Check-Equal '§1(b) 합성 행 전제: 이어 붙인 판독의 서명(접힌 패널/파티원 보상) = 참/참 · 거짓/거짓 (각 행이 겨냥한 조건에만 닿는지)' (
  "$(Test-AbyssEntryWaitingText -Text $joinedBothSignatures)/$(Test-AbyssMemberRewardText -Text $joinedBothSignatures) · $(Test-AbyssEntryWaitingText -Text $joinedNoSignature)/$(Test-AbyssMemberRewardText -Text $joinedNoSignature)") 'True/True · False/False'
Check-Equal "§1(b) 합성(실측 아님) '나가기'@515·'파티장'@714·'선택'@765·'대기중'@808 - 두 서명 모두 참 → null (파티원 보상 서명 배제)" (Get-Pick (Select-AbyssEntryWaitingAnchor -Words $wBothSignatures)) 'null'
Check-Equal "§1(b) 합성(실측 아님) '나가기'@515·'파티장'@714·'대기'@808 - 두 서명 모두 거짓, '대기' 단어 있음 → null (접힌 패널 서명 조건)" (Get-Pick (Select-AbyssEntryWaitingAnchor -Words $wNoSignature)) 'null'

# (c) Select-AbyssMemberLeaveWord - 기대 서명일 때만 기존 Select-AbyssExitWord 결과
Check-Equal '§1(c) 보상 + Expect member-reward → (515,654)' (Get-Pick (Select-AbyssMemberLeaveWord -Words $wMember -Expect 'member-reward')) '515,654'
Check-Equal '§1(c) 보상 + Expect entry-waiting → null (서명 조건)' (Get-Pick (Select-AbyssMemberLeaveWord -Words $wMember -Expect 'entry-waiting')) 'null'
Check-Equal '§1(c) 접힘 + Expect entry-waiting → (492,654)' (Get-Pick (Select-AbyssMemberLeaveWord -Words $wEntryA -Expect 'entry-waiting')) '492,654'
Check-Equal '§1(c) 가린 접힘 + Expect entry-waiting → null (현행 헬퍼는 이 프레임에서 492 = 퇴장을 누름 - D·P 가 헬퍼를 쓰지 않는 이유)' (Get-Pick (Select-AbyssMemberLeaveWord -Words $wOccluded -Expect 'entry-waiting')) 'null'
Check-Equal '§1(c) 펼친 패널(나가기@492) + 두 Expect 모두 → null' ((@('member-reward', 'entry-waiting') | ForEach-Object { Get-Pick (Select-AbyssMemberLeaveWord -Words $wExpanded -Expect $_) }) -join '/') 'null/null'

# (d) Get-AbyssMemberStopReason - 시간 지정 '그 판까지' 설계 8.2 T1 (옛 표 'D = U − (Now + E)' 를 교체 - 추정치·여유 매개변수가 없어졌습니다).
#     'time' = 지금 >= 지정 시각 (같은 시각 포함 - 던전 Get-DgTimeVerdict 와 같은 -ge), Phase 와 무관 (START 에서는 새 판
#     참가를 막고, 경계에서는 이어 가지 않음). 우선순위(안전 중지 > 시간 > 마지막 회차)와 'last-run' 의 경계(Phase 'clear') 한정은 그대로입니다
$gU = [datetime]'2026-10-01 10:00:00'
function Get-GateAt {
  # T1 한 행 - 지정 시각 기본값은 U (-UntilTime $null 이면 시간 지정 아님)
  param([string]$Phase = 'clear', [bool]$LastRun = $false, [bool]$SafeStop = $false, $UntilTime = $gU, [datetime]$Now)
  return (Get-AbyssMemberStopReason -Phase $Phase -LastRun $LastRun -UntilTime $UntilTime -SafeStopFlag $SafeStop -Now $Now)
}
Check-Equal "§1(d) T1-1 경계 · 지정 시각 1초 전 → '' (이어 감)" (Get-GateAt -Now ($gU.AddSeconds(-1))) ''
Check-Equal "§1(d) T1-2 경계 · 지정 시각과 같은 시각 → 'time' (같은 시각 포함)" (Get-GateAt -Now $gU) 'time'
Check-Equal "§1(d) T1-3 경계 · 지정 시각 1초 뒤 → 'time'" (Get-GateAt -Now ($gU.AddSeconds(1))) 'time'
Check-Equal "§1(d) T1-4 START · 같은 시각 → 'time' (Phase 무관 - 새 판 참가를 막음)" (Get-GateAt -Phase 'start' -Now $gU) 'time'
Check-Equal "§1(d) T1-5 START · 1초 전 → ''" (Get-GateAt -Phase 'start' -Now ($gU.AddSeconds(-1))) ''
Check-Equal "§1(d) T1-6 경계 · UNTIL `$null(시간 지정 아님) → '' (지정 시각 한참 뒤 시각이어도)" (Get-GateAt -UntilTime $null -Now ($gU.AddHours(1))) ''
Check-Equal "§1(d) T1-7 LastRun · UNTIL `$null: START → '' (이월 아님 - 이 워커는 판을 마치지 않음) / 경계 → 'last-run'" ("$(Get-GateAt -Phase 'start' -LastRun $true -UntilTime $null -Now $gU)/$(Get-GateAt -LastRun $true -UntilTime $null -Now $gU)") '/last-run'
Check-Equal '§1(d) T1-8 우선순위 F9 > 시간 > 마지막 회차 (경계 · 같은 시각 - 셋·둘 겹침)' ("$(Get-GateAt -LastRun $true -SafeStop $true -Now $gU)/$(Get-GateAt -LastRun $true -Now $gU)") 'safe-stop/time'
Check-Equal "§1(d) T1-9 SafeStopFlag 는 래치 입력 포함 (파일 없음 OR 래치 참 → 'safe-stop', START 에서도)" (Get-GateAt -Phase 'start' -SafeStop ($false -or $true) -UntilTime $null -Now $gU) 'safe-stop'
# T1-10 소스: 매개변수 목록 자체 (옛 호출 모양 -EstimateSeconds·-MarginSeconds 가 남으면 바인딩 오류로 파일이 멈추므로 위 행과 함께 서명도 못 박음)
$gDefinition = $workerAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-AbyssMemberStopReason' }, $true)
$gParamNames = @($gDefinition.Body.ParamBlock.Parameters | ForEach-Object { [string]$_.Name.VariablePath.UserPath })
$gParamText = $gParamNames -join ','
$gOldParamCount = @($gParamNames | Where-Object { $_ -eq 'EstimateSeconds' -or $_ -eq 'MarginSeconds' }).Count
Check-Equal '§1(d) T1-10 G 매개변수(AST ParamBlock) = Phase·LastRun·UntilTime·SafeStopFlag·Now - 추정치·여유(EstimateSeconds·MarginSeconds) 없음' "$gParamText/$gOldParamCount" 'Phase,LastRun,UntilTime,SafeStopFlag,Now/0'

# ── 가상 시계·캡처 계층 모의 (§1(e) 와 §2 공용) ──────────────────────────────────
# 운영 계약 그대로: Register-CaptureFailure = 일련번호 +1·플래그·실패 시작 시각(첫 실패 때만), Register-CaptureSuccess = 끝난 구간을 복구 시각까지
# 한 번 누적, Get-CaptureFailTotalMs = 누적 + 진행 중 구간 경과. 가상 시계는 모의 대기(Start-Sleep·Wait-UserYieldEnd·스윕 공백·느린 실패)에서만 흐릅니다.
$script:vclock = [datetime]'2026-10-01 09:00:00'
$script:caseStart = $script:vclock
$script:userYieldTotalMs = [double]0
$script:failTotalMs = [double]0
$script:failSince = $null
$script:screenCaptureFailing = $false
$script:captureFailSerial = 0
function Get-Date { return $script:vclock }
function Elapsed { return (($script:vclock - $script:caseStart).Ticks / 10000000.0) }
function Tick {
  # 가상 시간 상한(리뷰 C2): 케이스 시작부터 20000초를 넘으면 끝나지 않는 케이스로 보고 멈추지 않고 FAIL 로 끝냅니다
  param([double]$Seconds)
  $script:vclock = $script:vclock.AddMilliseconds($Seconds * 1000)
  if ((Elapsed) -gt 20000) { throw '__VTIMEOUT__' }
}
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) Tick (($Milliseconds + $Seconds * 1000) / 1000.0) }
function Register-MockFail {
  $script:captureFailSerial++
  if (-not $script:screenCaptureFailing) { $script:failSince = $script:vclock; $script:screenCaptureFailing = $true }
  $script:failedReads++
}
function Register-MockSuccess {
  if ($script:screenCaptureFailing) {
    if ($null -ne $script:failSince) { $script:failTotalMs += ($script:vclock - $script:failSince).TotalMilliseconds }
    $script:failSince = $null
    $script:screenCaptureFailing = $false
  }
}
function Get-CaptureFailTotalMs {
  $total = [double]$script:failTotalMs
  if ($script:screenCaptureFailing -and $null -ne $script:failSince) { $total += ($script:vclock - $script:failSince).TotalMilliseconds }
  return $total
}

# (e) 시계 헬퍼 (가상 Get-Date·Get-CaptureFailTotalMs·$script:userYieldTotalMs)
function Reset-ClockCase {
  $script:vclock = [datetime]'2026-10-01 09:00:00'; $script:caseStart = $script:vclock
  $script:userYieldTotalMs = [double]0; $script:failTotalMs = [double]0; $script:failSince = $null; $script:screenCaptureFailing = $false
}
function Get-DeadlineSec { param($Clock) [Math]::Round(([datetime]$Clock.Deadline - $script:caseStart).TotalSeconds, 3) }
Reset-ClockCase
$clk = New-AbyssMemberClock -LimitSeconds 100
Check-Equal '§1(e) Set 뒤 만료 시각 = 지금 + 한도 (진행으로 시작)' "$(Get-DeadlineSec $clk)/$($clk.Paused)" '100/False'
Tick 50; $script:userYieldTotalMs += 20000
[void](Test-AbyssMemberClockExpired -Clock $clk)
Check-Equal '§1(e) 양보 20초 → 마감 +20초' (Get-DeadlineSec $clk) 120
$script:failTotalMs += 30000
[void](Test-AbyssMemberClockExpired -Clock $clk)
Check-Equal '§1(e) 캡처 실패 30초 → 마감 +30초 (같은 양보는 다시 더하지 않음)' (Get-DeadlineSec $clk) 150
Tick 99.9
$beforeExpiry = Test-AbyssMemberClockExpired -Clock $clk
Tick 0.1
Check-Equal '§1(e) 만료 판정: 조정 마감 직전 거짓 / 도달 참' "$beforeExpiry/$(Test-AbyssMemberClockExpired -Clock $clk)" 'False/True'
# 진행 중 양보·실패(만료 판정 없이) → Suspend → Resume: Suspend 가 먼저 조정해야 그 시간이 한도에서 빠지지 않음 (리뷰 A1·C5)
Reset-ClockCase
$clk = New-AbyssMemberClock -LimitSeconds 100
Tick 10; $script:userYieldTotalMs += 20000
Suspend-AbyssMemberClock -Clock $clk
$remainAfterSuspend = [double]$clk.RemainingMs
Tick 50
Resume-AbyssMemberClock -Clock $clk
Check-Equal '§1(e) 진행 중 양보 20초 → Suspend(남은 110초) → Resume → 만료 +20초 (재개 60 + 110)' "$remainAfterSuspend/$(Get-DeadlineSec $clk)" '110000/170'
[void](Test-AbyssMemberClockExpired -Clock $clk)
Check-Equal '§1(e) Resume 은 기준값을 재설정 - 같은 양보 이중 가산 없음' (Get-DeadlineSec $clk) 170
Reset-ClockCase
$clk = New-AbyssMemberClock -LimitSeconds 100
Tick 10; $script:failTotalMs += 30000
Suspend-AbyssMemberClock -Clock $clk
Tick 50
Resume-AbyssMemberClock -Clock $clk
Check-Equal '§1(e) 진행 중 캡처 실패 30초 → Suspend → Resume → +30초 (재개 60 + 120)' (Get-DeadlineSec $clk) 180
# 멱등: 정지 상태 Suspend 반복·진행 상태 Resume 반복
Reset-ClockCase
$clk = New-AbyssMemberClock -LimitSeconds 100
Tick 25
Suspend-AbyssMemberClock -Clock $clk
$remainFirst = [double]$clk.RemainingMs
Tick 30; $script:userYieldTotalMs += 5000
Suspend-AbyssMemberClock -Clock $clk
Check-Equal '§1(e) Suspend 는 남은 값 보존 · 정지 상태 Suspend 반복 → 불변' "$remainFirst/$($clk.RemainingMs)/$($clk.Paused)" '75000/75000/True'
Check-Equal '§1(e) 정지 상태 Expired = 거짓 (한도를 한참 넘겨도)' (& { Tick 500; Test-AbyssMemberClockExpired -Clock $clk }) $false
Reset-ClockCase
$clk = New-AbyssMemberClock -LimitSeconds 100
Tick 5
$deadlineBefore = Get-DeadlineSec $clk
Resume-AbyssMemberClock -Clock $clk; Resume-AbyssMemberClock -Clock $clk
Check-Equal '§1(e) 진행 상태 Resume 반복 → 마감 불변 (멱등 - 매 회전 불러도 되감기지 않음)' "$deadlineBefore/$(Get-DeadlineSec $clk)" '100/100'
Suspend-AbyssMemberClock -Clock $clk -Reset
Check-Equal '§1(e) Suspend -Reset → 정지·남은 값 = 전체 한도' "$($clk.Paused)/$($clk.RemainingMs)" 'True/100000'
# Set 의 짝 갱신: Set 앞에 쌓인 양보는 새 마감에 더하지 않음 (기준값을 마감과 함께 갱신 - 짝이 어긋나면 이중 가산)
Reset-ClockCase
$clk = New-AbyssMemberClock -LimitSeconds 100 -Paused
$script:userYieldTotalMs += 40000; $script:failTotalMs += 15000
Tick 7
Set-AbyssMemberClock -Clock $clk
[void](Test-AbyssMemberClockExpired -Clock $clk)
Check-Equal '§1(e) Set 뒤 만료 판정 - Set 앞의 양보·실패는 더하지 않음 (마감·기준값 짝)' (Get-DeadlineSec $clk) 107
Check-Equal '§1(e) New -Paused → 정지·남은 값 전체 한도·만료 거짓' (& { $p = New-AbyssMemberClock -LimitSeconds 30 -Paused; "$($p.Paused)/$($p.RemainingMs)/$(Test-AbyssMemberClockExpired -Clock $p)" }) 'True/30000/False'

# (f) Test-AbyssMemberReward 게임 상태 (⑥a 4-21 이전) - 패널 조건 변이는 여기서만 잡힙니다 (분류 순위 6 에 오는 PanelKind 는 늘 'none')
$memberRewardCases = @(
  (Test-AbyssMemberReward -Game $null -BottomText $b.member -PanelKind 'none' -HudVisible $false),
  (Test-AbyssMemberReward -Game $null -BottomText $b.member -PanelKind 'ready' -HudVisible $false),
  (Test-AbyssMemberReward -Game $null -BottomText $b.member -PanelKind 'none' -HudVisible $true),
  (Test-AbyssMemberReward -Game $null -BottomText $b.entry -PanelKind 'none' -HudVisible $false))
Check-Equal '§1(f) 파티원 보상 게임 상태: 문구+패널 없음+HUD 없음 참 / 패널 있음·HUD 있음·다른 문구 거짓' ($memberRewardCases -join ',') 'True,False,False,False'

# (g) Resolve-AbyssMemberClearWaitExit (리뷰 C7) - 09-29 판독문
$ready0929 = @($overRewardTexts[0..7])
$entry0929 = @($b.entry, '아이템을누르면상세정보를를수있습니다나가기입장대기중')   # 212409·211959·212410·212411·212414 / 212005·212937
$member0929 = @($b.member)                                                               # 212401·211928·212031 (같은 판독)
Check-Equal "§1(g) 준비 패널 8장(HUD 거짓) → 'ready' 8" (@($ready0929 | Where-Object { (Resolve-AbyssMemberClearWaitExit -PanelKind 'ready' -BottomText $_ -HudVisible $false) -eq 'ready' }).Count) 8
Check-Equal "§1(g) 준비 패널 + HUD 참 → ''" (Resolve-AbyssMemberClearWaitExit -PanelKind 'ready' -BottomText $ready0929[0] -HudVisible $true) ''
Check-Equal "§1(g) 접힌 패널 7장 → 'entry-waiting'" ((@($entry0929[0], $entry0929[0], $entry0929[1], $entry0929[1], $entry0929[0], $entry0929[0], $entry0929[0]) | ForEach-Object { Resolve-AbyssMemberClearWaitExit -PanelKind 'none' -BottomText $_ -HudVisible $false } | Select-Object -Unique) -join ',') 'entry-waiting'
Check-Equal "§1(g) 파티원 보상 3장 → 'member-reward'" ((@($member0929[0], $member0929[0], $member0929[0]) | ForEach-Object { Resolve-AbyssMemberClearWaitExit -PanelKind 'none' -BottomText $_ -HudVisible $false } | Select-Object -Unique) -join ',') 'member-reward'
Check-Equal "§1(g) 가린 접힘 2장 → ''" ((@($b.occluded1, $b.occluded2) | ForEach-Object { "[$(Resolve-AbyssMemberClearWaitExit -PanelKind 'none' -BottomText $_ -HudVisible $false)]" }) -join '') '[][]'
Check-Equal "§1(g) 재매칭 → '' (관측 지속 - 10절 17)" (Resolve-AbyssMemberClearWaitExit -PanelKind 'matching' -BottomText $b.matching0918 -HudVisible $false) ''
Check-Equal "§1(g) 필드 위 준비 패널('Space') → 'ready'" (Resolve-AbyssMemberClearWaitExit -PanelKind 'ready' -BottomText 'Space' -HudVisible $false) 'ready'
Check-Equal "§1(g) 3버튼 보상 → ''" (Resolve-AbyssMemberClearWaitExit -PanelKind 'none' -BottomText $b.reward3 -HudVisible $false) ''
Check-Equal "§1(g) '' → ''" (Resolve-AbyssMemberClearWaitExit -PanelKind 'none' -BottomText '' -HudVisible $false) ''

# (h) Test-AbyssMemberClearWaitProbe 모의표 - 하단은 호출부 스태시(추가 판독 0), 패널 1회, 후보일 때만 HUD 1회, 판독 도중 일련번호 변화 → 거짓
$script:probePanel = 'none'; $script:probeHud = $false; $script:probePanelCalls = 0; $script:probeHudCalls = 0; $script:probePanelFail = $false; $script:probeHudFail = ''
function Get-AbyssPanelKind { param($Game)
  $script:probePanelCalls++
  if ($script:probePanelFail) { $script:captureFailSerial++; $script:screenCaptureFailing = $true; return 'none' }
  return $script:probePanel }
function Test-HomeEndEscHud { param($Game)
  $script:probeHudCalls++
  if ($script:probeHudFail -eq 'failing') { $script:captureFailSerial++; $script:screenCaptureFailing = $true; return $false }
  if ($script:probeHudFail -eq 'recovered') { $script:captureFailSerial++; return $false }   # 같은 판독 안에서 실패 → 복구 (플래그 거짓, 일련번호만 바뀜)
  return $script:probeHud }
function Get-ProbeRow {
  param([string]$Panel, [string]$Bottom, [bool]$Hud = $false, [bool]$PanelFail = $false, [string]$HudFail = '')
  $script:probePanel = $Panel; $script:probeHud = $Hud; $script:probePanelCalls = 0; $script:probeHudCalls = 0
  $script:probePanelFail = $PanelFail; $script:probeHudFail = $HudFail; $script:screenCaptureFailing = $false
  $r = Test-AbyssMemberClearWaitProbe -Game $null -BottomText $Bottom
  return "$r/패널$($script:probePanelCalls)/HUD$($script:probeHudCalls)"
}
Check-Equal '§1(h) 보상 위 준비 패널(HUD 거짓) → 참, 패널 1·HUD 1' (Get-ProbeRow 'ready' $b.ready211944) 'True/패널1/HUD1'
Check-Equal '§1(h) 파티원 보상 → 참, HUD 1' (Get-ProbeRow 'none' $b.member) 'True/패널1/HUD1'
Check-Equal '§1(h) 접힌 패널 → 참, HUD 1' (Get-ProbeRow 'none' $b.entry) 'True/패널1/HUD1'
Check-Equal '§1(h) 후보 아님(전투 하단 잡음) → 거짓, HUD 호출 0 (후보일 때만 HUD 판독)' (Get-ProbeRow 'none' '11:00') 'False/패널1/HUD0'
Check-Equal '§1(h) 재매칭은 후보가 아님 → 거짓, HUD 0' (Get-ProbeRow 'matching' $b.matching0918) 'False/패널1/HUD0'
Check-Equal '§1(h) 준비 패널 + HUD 참 → 거짓 (전투·필드)' (Get-ProbeRow 'ready' $b.ready211944 $true) 'False/패널1/HUD1'
Check-Equal '§1(h) 패널 판독 도중 캡처 실패(일련번호 변화) → 거짓, HUD 0' (Get-ProbeRow 'ready' $b.ready211944 $false $true) 'False/패널1/HUD0'
Check-Equal '§1(h) HUD 판독 도중 캡처 실패(아직 실패 중) → 거짓' (Get-ProbeRow 'none' $b.member $false $false 'failing') 'False/패널1/HUD1'
Check-Equal '§1(h) HUD 판독 도중 실패 → 같은 판독에서 복구(플래그 거짓·일련번호만 변화) → 거짓 (규칙 15 - 판독 불가를 판정으로 쓰지 않음)' (Get-ProbeRow 'none' $b.member $false $false 'recovered') 'False/패널1/HUD1'
$script:screenCaptureFailing = $false

# (i) Update-AbyssMemberLeaveTransition (09-30 리뷰1 P1-1 - 'left' = 끊김 없이 관측된 퇴장 전이 계약. W 는 소스 캡처값)
$W = [int]$memberFieldSettleSeconds
$tNow = [datetime]'2026-10-01 12:00:00'
$tOld = $tNow.AddSeconds(-30)
# (i-1) 표 직접 단언: 사건 9행 × Stage 4열 = 36칸. 칸마다 시작 상태(Stage·FieldCount 1·FieldSince = Now − W·DepartSamples·LastSendAt)를 직접
# 만들어 사건 1개를 넣고 다음 Stage·FieldCount·DepartSamples·LastSendAt·판정을 단언합니다 (두 화면 행은 화면마다 따로 - 44 적용)
function Invoke-TransitionCell {
  param([string]$Stage, [string]$Event, [string]$Screen = '', [int]$FieldCount = 1, [double]$FieldAgo = $W, [int]$Depart = -1)
  $tr = @{ Stage = $Stage; FieldCount = $FieldCount; FieldSince = $(if ($FieldCount -gt 0) { $tNow.AddSeconds(-$FieldAgo) } else { $null })
    DepartSamples = $(if ($Depart -ge 0) { $Depart } elseif ($Stage -eq 'departed') { 1 } else { 0 }); LastSendAt = $tOld }
  $verdict = Update-AbyssMemberLeaveTransition -Transition $tr -Event $Event -Screen $Screen -Now $tNow -SettleSeconds $W
  $send = $(if ($tr.LastSendAt -eq $tNow) { 'now' } elseif ($tr.LastSendAt -eq $tOld) { 'old' } else { "$($tr.LastSendAt)" })
  return "$($tr.Stage)|$($tr.FieldCount)|$($tr.DepartSamples)|$send|$verdict"
}
$stages = @('none', 'collapse-sent', 'sent', 'departed')
$cellExpect = [ordered]@{
  'leave-sent'             = @('sent|0|0|now|', 'sent|0|0|now|', 'sent|0|0|now|', 'sent|0|0|now|')
  'collapse-sent'          = @('collapse-sent|0|0|now|', 'collapse-sent|0|0|now|', 'collapse-sent|0|0|now|', 'collapse-sent|0|0|now|')
  'interrupt'              = @('none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|')
  'sweep'                  = @('none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|')
  'probe-sent'             = @('none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|')
  'sample:member-reward'   = @('none|0|0|old|', 'sent|0|0|old|', 'sent|0|0|old|', 'none|0|0|old|')
  'sample:entry-waiting'   = @('none|0|0|old|', 'sent|0|0|old|', 'sent|0|0|old|', 'none|0|0|old|')
  'sample:ready-available' = @('none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|')
  'sample:ready-other'     = @('none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|', 'none|0|0|old|')
  'sample:unknown'         = @('none|0|0|old|', 'departed|0|1|old|', 'departed|0|1|old|', 'departed|0|2|old|')
  'sample:field'           = @('none|2|0|old|stayed-field', 'collapse-sent|0|0|old|', 'sent|0|0|old|', 'departed|2|1|old|left')
}
$cellActual = @{}
foreach ($key in $cellExpect.Keys) {
  $cellEvent = $key; $cellScreen = ''
  if ($key -like 'sample:*') { $cellEvent = 'sample'; $cellScreen = $key.Substring(7) }
  $row = @(foreach ($stage in $stages) { Invoke-TransitionCell -Stage $stage -Event $cellEvent -Screen $cellScreen })
  $cellActual[$key] = $row
  for ($i = 0; $i -lt 4; $i++) { Check-Equal "§1(i-1) $key × $($stages[$i]) → Stage|FieldCount|DepartSamples|LastSendAt|판정" $row[$i] $cellExpect[$key][$i] }
}
# 판정이 나오는 두 칸의 짝 단언 - none × field: W 미달(Now − (W − 1))이면 '' / departed × field: 시작 FieldCount 0 이면 ''
Check-Equal "§1(i-1) 짝: none × field, FieldSince = Now − (W−1) → '' (W 미달)" ((Invoke-TransitionCell -Stage 'none' -Event 'sample' -Screen 'field' -FieldAgo ($W - 1)).Split('|')[4]) ''
Check-Equal "§1(i-1) 짝: departed × field, 시작 FieldCount 0 → '' (연속 1)" ((Invoke-TransitionCell -Stage 'departed' -Event 'sample' -Screen 'field' -FieldCount 0).Split('|')[4]) ''
# 열·행 동치: 'collapse-sent' 열과 'sent' 열의 판정은 칸마다 같고(라벨만 다름), 'sweep'·'probe-sent' 행은 'interrupt' 행과 칸마다 같다 (무장 해제)
$colSame = @(foreach ($key in $cellExpect.Keys) { ($cellActual[$key][1].Split('|')[4] -eq $cellActual[$key][2].Split('|')[4]) -and (($cellActual[$key][1].Split('|')[0] -replace '^collapse-sent$', 'sent') -eq ($cellActual[$key][2].Split('|')[0] -replace '^collapse-sent$', 'sent')) }) -notcontains $false
Check-Equal "§1(i-1) 'collapse-sent' 열 = 'sent' 열 (판정 칸마다 같음 - 라벨만 다름)" $colSame $true
Check-Equal "§1(i-1) 'sweep' 행 = 'interrupt' 행 (무장 해제 - v4 는 연속 수만 비웠음)" (($cellActual['sweep'] -join ';') -eq ($cellActual['interrupt'] -join ';')) $true
Check-Equal "§1(i-1) 'probe-sent' 행 = 'interrupt' 행 (무장 해제 - v5 는 탐침이 전이 밖이었음)" (($cellActual['probe-sent'] -join ';') -eq ($cellActual['interrupt'] -join ';')) $true
# (i-2) 사건 열 - s:<화면>@<초> = 표본 (@ 를 적지 않으면 직전 사건 +1초), 사건은 그 시각의 전이. 마지막 판정과 최종 Stage 를 단언하고
# 그 사이 판정은 모두 '' 여야 합니다 (중간 판정 목록을 함께 봄)
function Invoke-TransitionSequence {
  param([string[]]$Events)
  $tr = New-AbyssMemberLeaveTransition
  $t = -1.0; $verdicts = @()
  foreach ($raw in $Events) {
    $seqEvent = $raw; $seqScreen = ''; $at = $null
    if ($raw -match '^s:([a-z\-]+)(?:@([\d.]+))?$') { $seqEvent = 'sample'; $seqScreen = $Matches[1]; if ($Matches[2]) { $at = [double]$Matches[2] } }
    elseif ($raw -match '^([a-z\-]+)(?:@([\d.]+))?$') { $seqEvent = $Matches[1]; if ($Matches[2]) { $at = [double]$Matches[2] } }
    $t = $(if ($null -ne $at) { $at } else { $t + 1 })
    $v = Update-AbyssMemberLeaveTransition -Transition $tr -Event $seqEvent -Screen $seqScreen -Now $tNow.AddSeconds($t) -SettleSeconds $W
    $verdicts += $(if ($v) { $v } else { '-' })
  }
  $last = $verdicts[-1]
  $middleClean = (@($verdicts | Select-Object -First ($verdicts.Count - 1)) | Where-Object { $_ -ne '-' }).Count -eq 0
  return @{ Last = $(if ($last -eq '-') { '' } else { $last }); Stage = [string]$tr.Stage; Depart = [int]$tr.DepartSamples; Field = [int]$tr.FieldCount
    Middle = $middleClean; SendAge = $(if ($null -ne $tr.LastSendAt) { [Math]::Round(($tNow.AddSeconds($t) - [datetime]$tr.LastSendAt).TotalSeconds, 1) } else { -1 }) }
}
function Get-SeqSummary { param($R) "$($R.Last)/$($R.Stage)/중간$(if ($R.Middle) { '없음' } else { '있음' })" }
$seqCases = @(
  @('i1 leave-sent → unknown → field → field → left (DepartSamples 1, 전송 뒤 3초)', @('leave-sent@0', 's:unknown@1', 's:field@2', 's:field@3'), 'left/departed/중간없음', { param($r) "$($r.Depart)/$($r.SendAge)" }, '1/3'),
  @("i2 전송 없이 시작부터 필드 @0…@5 '' → @6 stayed-field (Stage none)", @('s:field@0', 's:field@1', 's:field@2', 's:field@3', 's:field@4', 's:field@5', 's:field@6'), 'stayed-field/none/중간없음', $null, ''),
  @("i3 관측 5 재현: 오독 field 2표본(전송 없음) → '' (W 미달 - v2 left, v3 stayed-field)", @('s:field@0', 's:field@1'), '/none/중간없음', $null, ''),
  @("i4 leave-sent → field × 8 (떠남 없음) → '' (Stage sent, FieldCount 0)", @('leave-sent', 's:field', 's:field', 's:field', 's:field', 's:field', 's:field', 's:field', 's:field'), '/sent/중간없음', { param($r) "$($r.Field)" }, '0'),
  @("i5 leave-sent → unknown → interrupt → field → field → '' (양보가 무장을 풂)", @('leave-sent', 's:unknown', 'interrupt', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @("i6 leave-sent → unknown → member-reward → field → field → '' (떠남 뒤 원래 화면)", @('leave-sent', 's:unknown', 's:member-reward', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @("i7 leave-sent → unknown → entry-waiting → unknown → field → field → '' (재무장은 새 전송뿐 - v3 left)", @('leave-sent', 's:unknown', 's:entry-waiting', 's:unknown', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @("i7′ i7 의 entry-waiting 뒤 leave-sent → unknown → field → field → left", @('leave-sent', 's:unknown', 's:entry-waiting', 'leave-sent', 's:unknown', 's:field', 's:field'), 'left/departed/중간없음', $null, ''),
  @("i8 collapse-sent → ready-available → field → field → '' (펼친 패널)", @('collapse-sent', 's:ready-available', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @('i9 collapse-sent → unknown → field → field → left (X-C - 접기 좌표가 보상 나가기에 떨어짐)', @('collapse-sent', 's:unknown', 's:field', 's:field'), 'left/departed/중간없음', $null, ''),
  @('i10 collapse-sent → entry-waiting → leave-sent → unknown × 2 → field × 2 → left (DepartSamples 2 - B9)', @('collapse-sent', 's:entry-waiting', 'leave-sent', 's:unknown', 's:unknown', 's:field', 's:field'), 'left/departed/중간없음', { param($r) "$($r.Depart)" }, '2'),
  @('i11 leave-sent → unknown → field → unknown → field → field → left 는 마지막에서만 (연속이 끊기면 처음부터)', @('leave-sent', 's:unknown', 's:field', 's:unknown', 's:field', 's:field'), 'left/departed/중간없음', $null, ''),
  @("i12 leave-sent → unknown → interrupt(캡처 실패 차분 - 동결) → field → field → '' (v3 left)", @('leave-sent', 's:unknown', 'interrupt', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @("i13 leave-sent → unknown → ready-other → field → field → '' (펼친 패널)", @('leave-sent', 's:unknown', 's:ready-other', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @('i14 unknown@0 → field@1…@7 (전송 없음) → @7 stayed-field (무장 없는 unknown 은 떠남 아님)', @('s:unknown@0', 's:field@1', 's:field@2', 's:field@3', 's:field@4', 's:field@5', 's:field@6', 's:field@7'), 'stayed-field/none/중간없음', $null, ''),
  @("i15 collapse-sent → member-reward → field → field → '' (Stage sent - 무장, 떠남 없음)", @('collapse-sent', 's:member-reward', 's:field', 's:field'), '/sent/중간없음', $null, ''),
  @("i16 field@0 → field@1 → interrupt → field@2…@7 '' → @8 stayed-field (양보 × none - 연속 수를 비움)", @('s:field@0', 's:field@1', 'interrupt@1.5', 's:field@2', 's:field@3', 's:field@4', 's:field@5', 's:field@6', 's:field@7', 's:field@8'), 'stayed-field/none/중간없음', $null, ''),
  @('i17 i16 과 같되 sweep (스윕 참 회전도 연속 수를 비움)', @('s:field@0', 's:field@1', 'sweep@1.5', 's:field@2', 's:field@3', 's:field@4', 's:field@5', 's:field@6', 's:field@7', 's:field@8'), 'stayed-field/none/중간없음', $null, ''),
  @("i18 leave-sent → unknown → leave-sent(재전송) → field → field → '' (Stage sent - 재전송은 떠남을 비움)", @('leave-sent', 's:unknown', 'leave-sent', 's:field', 's:field'), '/sent/중간없음', $null, ''),
  @("i19 입장 과도(09-21 관측 4 재생 시각) unknown@37.2 → field@41.4 → @42.4 → @43.5 → '' (연속 3 · 2.1초 < W)", @('s:unknown@37.2', 's:field@41.4', 's:field@42.4', 's:field@43.5'), '/none/중간없음', $null, ''),
  @("i20 입장 과도(09-29 3판) unknown@41.9 → field@43.0 → ''", @('s:unknown@41.9', 's:field@43.0'), '/none/중간없음', $null, ''),
  @("i21 leave-sent → unknown → field → interrupt → field → field → '' (도착 도중 끊김)", @('leave-sent', 's:unknown', 's:field', 'interrupt', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @("i22 leave-sent → unknown → sweep → unknown → field → field → '' (스윕 참 회전이 무장을 풂 - v4 left)", @('leave-sent', 's:unknown', 'sweep', 's:unknown', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @("i23 leave-sent → unknown → sweep × 5 → unknown(입장 로딩) → field → field(입장 과도) → '' (리뷰 3차 P1-1 경로 - v4 left)", @('leave-sent', 's:unknown', 'sweep', 'sweep', 'sweep', 'sweep', 'sweep', 's:unknown', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @("i24 leave-sent → entry-waiting → probe-sent → unknown(입장 로딩) → field → field(입장 과도) → '' (무장 중 탐침 - v5 left)", @('leave-sent', 's:entry-waiting', 'probe-sent', 's:unknown', 's:field', 's:field'), '/none/중간없음', $null, ''),
  @('i25 leave-sent → entry-waiting → probe-sent → ready-available → collapse-sent → entry-waiting → leave-sent → unknown → field → field → left (관측된 퇴장 흐름은 막지 않음)', @('leave-sent', 's:entry-waiting', 'probe-sent', 's:ready-available', 'collapse-sent', 's:entry-waiting', 'leave-sent', 's:unknown', 's:field', 's:field'), 'left/departed/중간없음', $null, '')
)
foreach ($case in $seqCases) {
  $seqResult = Invoke-TransitionSequence -Events $case[1]
  Check-Equal "§1(i-2) $($case[0])" (Get-SeqSummary $seqResult) $case[2]
  if ($null -ne $case[3]) { Check-Equal "§1(i-2) $($case[0].Split(' ')[0]) 부가 (DepartSamples·전송 뒤 초·FieldCount)" (& $case[3] $seqResult) $case[4] }
}
# i2·i14·i16 의 '@N 까지 판정 없음' 은 위 '중간없음' 이 함께 지킵니다 (마지막 한 표본만 stayed-field)

# (j) Resolve-AbyssMemberSweepTurn - Limit 은 소스 캡처값 (기대를 캡처값으로 다시 계산 - 한도 자체는 §0 단언)
$sweepLimit = [int]$memberSweepStreakLimit
function Get-CountedAction { param([int]$Streak) if (($Streak + 1) -lt $sweepLimit) { "counted/$($Streak + 1)" } else { "starved/$($Streak + 1)" } }
$jRows = @(
  @($true, $true, $false, 'cursor-not-ready', 1, 'freeze/1', '아직 실패 중 + cursor-not-ready → freeze'),
  @($true, $true, $true, '', 2, 'freeze/2', '아직 실패 중 + 전송 → freeze (아직 실패 중이 먼저 - 규칙 15)'),
  @($true, $true, $false, 'user-active', 2, 'freeze/2', '실패 중이면 양보보다 동결 (다음 회전 ① 뒤 ② 가 조작을 봄)'),
  @($true, $false, $true, '', 0, 'freeze/0', '플래그만으로 동결 (D·P 는 ① 이 먼저 거르지만 함수는 동결로 닫음)'),
  @($false, $true, $false, 'cursor-not-ready', 1, 'recovered/1', '이미 복구 + cursor-not-ready → recovered (복구 회전, 미소모 - ㉻)'),
  @($false, $true, $true, '', 2, 'recovered/2', '이미 복구 + 전송 → recovered (소모면 3회째 굶김)'),
  @($false, $true, $false, 'user-active', 1, 'yield/1', '이미 복구 + user-active → yield (조작이 복구보다 먼저 - 규칙 4)'),
  @($false, $false, $false, 'user-active', 2, 'yield/2', 'user-active → yield (미소모)'),
  @($false, $false, $true, '', 0, (Get-CountedAction 0), '전송(연속 0) → 소모'),
  @($false, $false, $false, 'cursor-not-ready', 1, (Get-CountedAction 1), 'cursor-not-ready(연속 1) → 소모'),
  @($false, $false, $false, 'cursor-not-ready', 2, (Get-CountedAction 2), 'cursor-not-ready(연속 2) → 한도째 굶김'),
  @($false, $false, $true, '', 2, (Get-CountedAction 2), '전송(연속 2) → 한도째 굶김 (전송도 소모)'),
  @($false, $false, $true, '', 7, (Get-CountedAction 7), '전송(연속 7) → 굶김 유지'),
  @($false, $false, $false, '', 0, (Get-CountedAction 0), "메타 없음 → 소모 쪽으로 닫음 (D·P 회전 서두 메타 비움 - §3)")
)
foreach ($row in $jRows) {
  $sweepTurn = Resolve-AbyssMemberSweepTurn -CaptureFailingNow $row[0] -CaptureFailedInTurn $row[1] -Performed $row[2] -SkipReason $row[3] -Streak $row[4] -Limit $sweepLimit
  Check-Equal "§1(j) $($row[6])" "$($sweepTurn.Action)/$($sweepTurn.Streak)" $row[5]
}
Check-Equal '§1(j) 캡처값 한도로 다시 계산한 경계 (연속 2 → starved, 연속 1 → counted - 한도 3)' "$(Get-CountedAction 1)|$(Get-CountedAction 2)" 'counted/2|starved/3'

# (k) Get-AbyssMemberScreenLabel - 행동 케이스의 라벨 단언은 모두 이 함수를 거칩니다 (S2·RC6 변이는 추출한 이 함수로 드러남)
$fieldLabel = '필드로 보이는 화면(HUD, 던전 목표 없음)'
$kRows = @(
  @('field · Stage none · 전송 없음 → 꼬리 없음', (Get-AbyssMemberScreenLabel -Screen 'field' -OverReward $false -Stage 'none' -ExitSent $false), $fieldLabel),
  @("field · Stage sent → ' - 나가기 뒤 로딩 화면 미관측'", (Get-AbyssMemberScreenLabel -Screen 'field' -OverReward $false -Stage 'sent' -ExitSent $true), "$fieldLabel - 나가기 뒤 로딩 화면 미관측"),
  @("field · Stage collapse-sent → ' - 나가기 뒤 로딩 화면 미관측'", (Get-AbyssMemberScreenLabel -Screen 'field' -OverReward $false -Stage 'collapse-sent' -ExitSent $true), "$fieldLabel - 나가기 뒤 로딩 화면 미관측"),
  @("field · Stage none · 전송 있음(무장 해제) → ' - 나가기 뒤 화면 전이를 끊김 없이 보지 못함'", (Get-AbyssMemberScreenLabel -Screen 'field' -OverReward $false -Stage 'none' -ExitSent $true), "$fieldLabel - 나가기 뒤 화면 전이를 끊김 없이 보지 못함"),
  @("popup(굶김 마감) → '닫히지 않는 팝업 화면'", (Get-AbyssMemberScreenLabel -Screen 'popup' -OverReward $false -Stage 'sent' -ExitSent $true), '닫히지 않는 팝업 화면'),
  @("capture(복구 마감) → '판독 도중 캡처가 끊기는 화면'", (Get-AbyssMemberScreenLabel -Screen 'capture' -OverReward $true -Stage 'none' -ExitSent $false), '판독 도중 캡처가 끊기는 화면'),
  @('ready-available · 보상 위 / 필드 위', "$(Get-AbyssMemberScreenLabel -Screen 'ready-available' -OverReward $true)|$(Get-AbyssMemberScreenLabel -Screen 'ready-available' -OverReward $false)", '보상 위 준비 패널(준비 전)|필드 위 준비 패널(준비 전)'),
  @('ready-done · 보상 위 / 필드 위', "$(Get-AbyssMemberScreenLabel -Screen 'ready-done' -OverReward $true)|$(Get-AbyssMemberScreenLabel -Screen 'ready-done' -OverReward $false)", '보상 위 준비 패널(준비 완료 상태)|필드 위 준비 패널(준비 완료 상태)'),
  @('member-reward · entry-waiting · unknown (X3·A7·S2 변이의 기대값)', "$(Get-AbyssMemberScreenLabel -Screen 'member-reward' -OverReward $false)|$(Get-AbyssMemberScreenLabel -Screen 'entry-waiting' -OverReward $false)|$(Get-AbyssMemberScreenLabel -Screen 'unknown' -OverReward $false)", '파티원 보상 화면|접힌 준비 패널|알 수 없는 화면')
)
foreach ($row in $kRows) { Check-Equal "§1(k) $($row[0])" $row[1] $row[2] }
# 설계 표에 없는 키(ready-other·matching·prompt·inside·reward3)는 구현이 정한 라벨입니다 - 문구 자체가 아니라 '키마다 제 라벨이 있고 알 수 없음으로
# 떨어지지 않는다' 만 고정합니다 (구현 1부 보고의 문구 선택 - 설계가 문구를 정하면 위 표로 옮김)
$otherKeys = @('ready-other', 'matching', 'prompt', 'inside', 'reward3')
$otherLabels = @($otherKeys | ForEach-Object { Get-AbyssMemberScreenLabel -Screen $_ -OverReward $false })
Check-Equal '§1(k) 표 밖 키 5종도 제 라벨(서로 다름·알 수 없음 아님)' ("$(@($otherLabels | Select-Object -Unique).Count)/$(@($otherLabels | Where-Object { $_ -eq '알 수 없는 화면' -or -not $_ }).Count)") '5/0'

# ── §2 행동 하니스 ───────────────────────────────────────────────────────────────
# test_abyss_exit_button(⑥a) 4절의 가상 시계·계획표·Read-Guard·센티널을 옮겨 D·P 에 맞게 넓힌 것입니다.
#  - D·P 는 소스 그대로 추출합니다. exit N 은 센티널 throw('__EXIT__N')로 바꾸고(함수 안 exit 는 워커 전체를 끝내므로 return 치환은 부정확),
#    치환 뒤 정의를 다시 파싱해 ExitStatementAst 가 0건인지, 원본 exit 수 = 치환 수인지 단언합니다 (리뷰 C3).
#  - P 는 이름을 바꿔 올리고 같은 이름의 얇은 기록 래퍼를 둡니다 - 호출 수·사유·결과를 세기 위함이고 동작은 그대로 넘깁니다.
#  - 화면은 가상 시계 위의 계획표($script:plan - 케이스 시작 기준 초·화면 키)로 흐르고, 클릭 전송이 관측된 전이를 끼워 넣습니다.
#    화면 키별 판독문·단어 목록은 §1 의 재생 실측 그대로입니다 (추적기 판독문은 운영 Test-InDungeonQuest 로 판정).
# (주의) 큰따옴표 문자열 안의 $( ) 에 괄호가 든 따옴표 문자열을 넣으면 PS 5.1 파서가 하위식 끝을 못 찾습니다 - 여러 값을 한 줄로 단언할 때는
# J @(값, …) 로 이어 붙입니다 (⑥a 하니스와 같은 주의)
function J { param([object[]]$Parts) return (@($Parts | ForEach-Object { if ($null -eq $_) { '' } else { "$_" } }) -join '/') }
function Convert-ExitSentinel {
  # exit 줄을 센티널 throw 로 바꾸고, 원본 ExitStatementAst 수 = 줄 단독 exit 수 = 치환 수 / 치환 뒤 ExitStatementAst 0 을 단언합니다
  param([string]$Text, [string]$Label)
  $tk = $null; $er = $null
  $originalAst = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tk, [ref]$er)
  $originalExits = @($originalAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count
  $lineExits = [regex]::Matches($Text, '(?m)^(\s*)exit (\d+)\s*$').Count
  $converted = $Text -replace '(?m)^(\s*)exit (\d+)\s*$', '$1throw "__EXIT__$2"'
  $convertedAst = [System.Management.Automation.Language.Parser]::ParseInput($converted, [ref]$tk, [ref]$er)
  $remaining = @($convertedAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count
  # 단언 줄은 나중에 한꺼번에 찍습니다 - 이 함수의 출력이 곧 Invoke-Expression 에 넘길 정의 문자열이라 섞이면 안 됨
  $script:sentinelChecks += , @($Label, $originalExits, $lineExits, $remaining)
  return $converted
}
$script:sentinelChecks = @()
$sourceDefs['Invoke-AbyssPartyMemberCycle'] = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-AbyssPartyMemberCycle'))
$sourceDefs['Invoke-AbyssMemberLeave'] = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-AbyssMemberLeave'))
$sourceDefs['Invoke-PurchasePopupSweep'] = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-PurchasePopupSweep'))
Invoke-Expression (Convert-ExitSentinel -Text $sourceDefs['Invoke-AbyssPartyMemberCycle'] -Label 'D')
Invoke-Expression ((Convert-ExitSentinel -Text $sourceDefs['Invoke-AbyssMemberLeave'] -Label 'P') -replace '^function Invoke-AbyssMemberLeave\b', 'function Invoke-AbyssMemberLeaveCore')
# 운영 공용 스윕은 RC10(b)·SP5(b) 에서만 씁니다 (모의 스윕 대신 - 첫 판독 가드의 행동 확인)
Invoke-Expression ((Convert-ExitSentinel -Text $sourceDefs['Invoke-PurchasePopupSweep'] -Label '공용 스윕') -replace '^function Invoke-PurchasePopupSweep\b', 'function Invoke-RealPurchasePopupSweep')
foreach ($sentinel in $script:sentinelChecks) {
  Check-Equal "§2 센티널($($sentinel[0])): 원본 ExitStatementAst = 줄 단독 exit = 치환 수, 치환 뒤 ExitStatementAst 0" (J @($sentinel[1], $sentinel[2], $sentinel[3])) (J @($sentinel[1], $sentinel[1], 0))
}
Check-True "§2 센티널: D 의 exit 는 여러 곳(인계·정지 경로), P 는 0 (P 는 결과를 돌려주고 D 가 매핑)" (($script:sentinelChecks[0][1] -ge 20) -and ($script:sentinelChecks[1][1] -eq 0)) (J @($script:sentinelChecks[0][1], $script:sentinelChecks[1][1]))
function Invoke-AbyssMemberLeave {
  # P 기록 래퍼 - 호출 시각·사유·중단 허용·소비 여부와 결과를 남기고 운영 P 결과를 그대로 돌려줍니다
  param([System.Diagnostics.Process]$Game, [string]$Reason, [switch]$AllowAbort, [switch]$ConsumeSafeStop)
  $entry = @{ At = (Elapsed); Reason = $Reason; AllowAbort = [bool]$AllowAbort; Consume = [bool]$ConsumeSafeStop; Result = $null
    FailMs = (Get-CaptureFailTotalMs); YieldMs = [double]$script:userYieldTotalMs }
  $script:pCalls.Add($entry)
  $leaveResult = Invoke-AbyssMemberLeaveCore -Game $Game -Reason $Reason -AllowAbort:$AllowAbort -ConsumeSafeStop:$ConsumeSafeStop
  $entry.Result = $leaveResult
  $entry.EndAt = (Elapsed)
  $entry.EndFailMs = (Get-CaptureFailTotalMs)
  $entry.EndYieldMs = [double]$script:userYieldTotalMs
  return $leaveResult
}

# ── 화면 키 → 판독 (§1 실측 판독문) ──
$wReadyDone = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '모든' 839 597))   # 09-26 L3
$wSpace = @((W 'Space' 749 630))
$scr = @{
  memberReward   = @{ Bottom = $b.member; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = $wMember }
  readyAvail     = @{ Bottom = $b.ready211944; Panel = 'ready'; Hud = $false; Tracker = ''; Button = '준비완료'; Words = $wExpanded }
  readyDone      = @{ Bottom = $b.readyL3; Panel = 'ready'; Hud = $false; Tracker = ''; Button = '준비취소'; Words = $wReadyDone }
  readyField     = @{ Bottom = 'Space'; Panel = 'ready'; Hud = $false; Tracker = ''; Button = '준비완료'; Words = $wSpace }
  readyDoneField = @{ Bottom = 'Space'; Panel = 'ready'; Hud = $false; Tracker = ''; Button = '준비취소'; Words = $wSpace }
  readyOther     = @{ Bottom = 'Space'; Panel = 'ready'; Hud = $false; Tracker = ''; Button = '주년`완료'; Words = $wSpace }      # cap_210545_900
  entryWaiting   = @{ Bottom = $b.entry; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = $wEntryA }
  entryWaitingM4 = @{ Bottom = $b.entryM4pre; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = $wM4pre }      # 09-26 M4-pre (앵커 '자대기중'@744 - A6′·B10′)
  entryOccluded  = @{ Bottom = $b.occluded1; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = $wOccluded }
  prompt         = @{ Bottom = $b.prompt; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = @() }
  matching       = @{ Bottom = '사제'; Panel = 'matching'; Hud = $false; Tracker = ''; Button = ''; Words = @() }                 # cap_184830_364
  inside         = @{ Bottom = '&쇨죠돈출'; Panel = 'none'; Hud = $true; Tracker = $trk.inside0929; Button = ''; Words = @() }    # cap_211244_025
  field          = @{ Bottom = ''; Panel = 'none'; Hud = $true; Tracker = $trk.field0929; Button = ''; Words = @() }               # cap_210525_840
  fieldMisread   = @{ Bottom = ''; Panel = 'none'; Hud = $true; Tracker = $trk.misreadA; Button = ''; Words = @() }                # error h21m06s37 (던전 안 오독)
  transient      = @{ Bottom = '시(쯔3'; Panel = 'none'; Hud = $true; Tracker = $trk.transient0929; Button = ''; Words = @() }     # cap_211242_966 (입장 과도)
  transient1     = @{ Bottom = '〔삶월i월특'; Panel = 'none'; Hud = $true; Tracker = $trk.transient1; Button = ''; Words = @() }  # cap_185241_363
  transient2     = @{ Bottom = ''; Panel = 'none'; Hud = $true; Tracker = $trk.transient2; Button = ''; Words = @() }              # cap_185242_423
  transient3     = @{ Bottom = '聳돈살&'; Panel = 'none'; Hud = $true; Tracker = $trk.transient3; Button = ''; Words = @() }      # cap_185243_493
  loading        = @{ Bottom = ''; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = @() }                         # 퇴장 로딩 '이멘마하' (cap_210521_682)
  arrival        = @{ Bottom = ''; Panel = 'none'; Hud = $false; Tracker = $trk.arrival0929; Button = ''; Words = @() }           # 필드 도착 HUD 미표시 (cap_211009_900)
  entryLoading   = @{ Bottom = ''; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = @() }                         # 입장 로딩 (cap_185237_205·211239_838 - 2인 '모든 파티원이 준비가 되어 …' 포함)
  reward3        = @{ Bottom = $b.reward3; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = @() }
  unknown        = @{ Bottom = ''; Panel = 'none'; Hud = $false; Tracker = ''; Button = ''; Words = @() }
}
function Screen-Now {
  # 계획표의 지금 화면. 'transientRun' 은 회전 단위 수열입니다 - 입장 과도 길이를 시간이 아니라 표본 수로 정하기 위함(반영본 검증, 09-30 리뷰2):
  # 회전(모의 스윕 호출이 회전 번호를 올림)마다 $script:transientSeq 에서 하나씩 꺼내고(같은 회전의 판독은 같은 화면), 다 쓰면 $script:transientThen
  $now = $script:plan[0].Screen
  $t = Elapsed
  foreach ($step in $script:plan) { if ($step.At -le $t) { $now = $step.Screen } }
  if ($now -eq 'transientRun') {
    if ($script:transientTurn -ne $script:turnId) {
      $script:transientTurn = $script:turnId
      if ($script:transientIdx -lt @($script:transientSeq).Count) { $script:transientCur = [string]@($script:transientSeq)[$script:transientIdx]; $script:transientIdx++ }
      else { $script:transientCur = $script:transientThen }
      $script:transientLog.Add("$($script:transientCur)@$([Math]::Round($t, 1))")
    }
    return $script:transientCur
  }
  return $now
}
function Step { param([double]$Offset, [string]$Screen) @{ Offset = $Offset; Screen = $Screen } }
function P { param([double]$At, [string]$Screen) $script:planSeq++; @{ At = $At; Screen = $Screen; Seq = $script:planSeq } }
$script:planSeq = 0
function Set-ScreenAfter {
  # 지금 + Delay 부터의 계획을 새 전이로 바꿉니다 (지금 이후에 잡혀 있던 계획은 버림 - 화면이 그 전이로 갈라졌으므로. 지금 화면은 남김).
  # $script:keepPlan 이면 뒤 계획을 남기고 끼워 넣습니다 (케이스가 시각표를 미리 정한 경우 - 예: 파티장 취소 시각).
  # 같은 시각의 단계는 나중에 넣은 것이 이깁니다 (Seq 로 안정 정렬 - Screen-Now 는 시각 ≤ 지금인 마지막 단계를 씀)
  param([double]$Delay, [object[]]$Steps)
  $nowAt = Elapsed
  $at = $nowAt + $Delay
  $kept = @(if ($script:keepPlan) { $script:plan } else { $script:plan | Where-Object { $_.At -le $nowAt } })   # @() - 한 칸짜리 계획이 해시로 풀리지 않게
  foreach ($stepItem in $Steps) { $script:planSeq++; $kept += @{ At = $at + $stepItem.Offset; Screen = $stepItem.Screen; Seq = $script:planSeq } }
  $script:plan = @($kept | Sort-Object @{ Expression = { $_.At } }, @{ Expression = { $_.Seq } })
}
function Add-PlanSteps {
  # 지금 기준 시각표를 뒤 계획을 버리지 않고 더합니다 (훅에서 장면을 잇는 데 씀)
  param([object[]]$Steps)
  $at = Elapsed
  $all = @($script:plan)
  foreach ($stepItem in $Steps) { $script:planSeq++; $all += @{ At = $at + $stepItem.Offset; Screen = $stepItem.Screen; Seq = $script:planSeq } }
  $script:plan = @($all | Sort-Object @{ Expression = { $_.At } }, @{ Expression = { $_.Seq } })
}
function In-Window { param($Window) return ($null -ne $Window -and (Elapsed) -ge $Window[0] -and (Elapsed) -lt $Window[1]) }

# ── 캡처 계층 모의 (Read-Guard) ──
#  ① 시간창 실패 $script:capWindow [a, b) - 그 안의 모든 캡처(판독·복구 탐침)가 실패를 등록
#  ② 교대 실패 $script:persistFail - 실패가 분기점까지 이어지다 다음 회전 ① 동결의 복구 탐침(Test-CaptureRecovered)이 복구
#  ③ 주입 훅 $script:failHook - 판독 이름을 받아 음수면 성공, 0 이상이면 실패 등록 뒤 그만큼 가상 초를 흘림(느린 실패 = 같은 회전 복구 주입)
function Read-Guard {
  param([string]$Name)
  $script:captureTimes.Add((Elapsed))
  if (In-Window $script:capWindow) { Register-MockFail; return $false }
  if ($script:persistFail) {
    if ($Name -eq 'probe') { $script:persistFail = $false } else { Register-MockFail; return $false }
  }
  if ($null -ne $script:failHook) {
    $hookResult = & $script:failHook $Name
    if ($null -ne $hookResult -and [double]$hookResult -ge 0) {
      Register-MockFail
      if ([double]$hookResult -gt 0) { Tick ([double]$hookResult) }
      return $false
    }
  }
  Register-MockSuccess
  return $true
}
function Test-CaptureRecovered { param($Game) $script:probeCalls++; return (Read-Guard 'probe') }
function Test-SafeStopDuringCaptureFail { $script:safeStopCalls++ }
function Focus-Game { param($Game) }

# ── 판독 모의 (호출 순번 기록 - 회전 안 순번은 모의 스윕이 회전마다 비움) ──
function Invoke-ReadHook { param([string]$Name) if ($null -ne $script:readHook) { & $script:readHook $Name } }
function Test-DungeonClearPrompt { param($Game)
  $script:promptReads++
  if ($script:promptReads -gt 50000) { throw '__VTIMEOUT__' }
  $script:promptReadTimes.Add((Elapsed))   # 판독 호출 상한 - 대기 없이 continue 로 도는 변이는 가상 시계에 닿지 않음 (09-30 리뷰1)
  $script:turnReads['prompt']++
  Invoke-ReadHook 'prompt'
  if (-not (Read-Guard 'prompt')) { $script:lastClearPromptText = ''; return $false }
  $s = Screen-Now
  if ($script:turnReads['prompt'] -eq 1) { $script:samples.Add(@{ T = (Elapsed); S = $s }) }   # 회전의 첫 판독 = 그 회전의 표본 화면 (시계 기대값 계산용)
  $script:lastClearPromptText = [string]$scr[$s].Bottom
  return ($s -eq 'prompt')
}
function Get-FirstSampleAt { param([string]$Screen, [double]$After = -1) $hit = @($script:samples | Where-Object { $_.S -eq $Screen -and $_.T -gt $After }) | Select-Object -First 1; if ($hit) { return [double]$hit.T } return -1 }
function Get-AbyssPanelKind { param($Game)
  $script:turnReads['panel']++
  Invoke-ReadHook 'panel'
  if (-not (Read-Guard 'panel')) { return 'none' }
  return [string]$scr[(Screen-Now)].Panel
}
function Test-HomeEndEscHud { param($Game)
  Invoke-ReadHook 'hud'
  if (-not (Read-Guard 'hud')) { return $false }
  return [bool]$scr[(Screen-Now)].Hud
}
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine, [switch]$BinaryWhiteText)
  # 준비 버튼(partyEnterButton)·추적기(questTracker) 판독만 모의 - 운영 Get-AbyssReadyButtonState·Test-InDungeonQuest 가 판정
  $readName = $(if ($ReferenceX -eq $rgPartyEnterBtn[0]) { 'button' } elseif ($ReferenceX -eq $rgQuestTracker[0]) { 'quest' } else { 'text' })
  Invoke-ReadHook $readName
  if (-not (Read-Guard $readName)) { return '' }
  $s = Screen-Now
  if ($readName -eq 'button') { return [string]$scr[$s].Button }
  if ($readName -eq 'quest') { return [string]$scr[$s].Tracker }
  return ''
}
function Get-GameRegionOcrWords { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine)
  $script:wordReads++
  $script:turnReads['words']++
  Invoke-ReadHook 'words'
  if (-not (Read-Guard 'words')) { return @() }
  if ($null -ne $script:wordsOverride) { return $script:wordsOverride }   # C14·A19: 클릭 직전 새 단어 판독의 앵커 null 영구 (§1(b) 합성 행)
  return $scr[(Screen-Now)].Words
}

# ── 조작 모의 ──
function Test-UserRecentlyActive {
  if ($script:activeQueue -gt 0) { $script:activeQueue--; return $true }
  if (In-Window $script:activeWindow) { return $true }
  return $false
}
function Wait-UserYieldEnd { param($Game, $Context)
  # 조작 창 안이면 창 끝까지 가상 시계를 흘리고 그만큼 양보 누적을 올립니다 (운영: 마지막 입력 뒤 유휴까지 대기 + 누적). 창 밖(클릭 user-active 생략 등)은 기본 3초
  $script:yieldWaits++
  $script:yieldContexts.Add([string]$Context)
  $script:yieldTimes.Add((Elapsed))
  $seconds = $(if (In-Window $script:activeWindow) { $script:activeWindow[1] - (Elapsed) } else { $script:yieldSeconds })
  if ($null -ne $script:onYield) { & $script:onYield }
  Tick $seconds
  $script:userYieldTotalMs += $seconds * 1000
}

# ── 스윕 모의 ──
# $script:sweepPlan 이 회전마다 이번 스윕의 결과를 정합니다: $null(팝업 없음) / @{ Kind; Gap } -
#  sent(닫기 전송) · cursor(커서 미확인) · ua-wait('닫기'·주간 - 스윕 안에서 기다려 양보 누적이 오름) · ua-deleg(위임 넷 - 기다리지 않고 참, 누적 없음,
#  다음 회전 ② 가 조작을 봄) · recover(스윕 안 실패 → 스윕 안 복구, cursor-not-ready 로 참) · fail-false(스윕 안 실패 → 거짓, 뒤 판독이 복구)
#  한 회전 공백은 기본 1초, 주입으로 최대 5.5초 (실측 2~5.5초 - 스윕 대기 1~3초 + 전면화·클릭)
function Invoke-PurchasePopupSweep { param($Game)
  $script:sweepCalls++
  if ($script:sweepCalls -gt 50000) { throw '__VTIMEOUT__' }   # 스윕 호출 상한 - 굶김 회전은 판독이 없어 판독 상한에 닿지 않음 (09-30 리뷰2)
  $script:turnReads = @{ prompt = 0; panel = 0; words = 0 }
  $script:turnId++                                            # 회전 번호 - ③ 스윕은 판독하는 회전마다 ④ 판독보다 먼저 불림
  if ($script:useRealSweep) { return (Invoke-RealPurchasePopupSweep -Game $Game) }
  if ($script:screenCaptureFailing) { return $false }
  if (-not (Read-Guard 'sweep')) { return $false }            # 첫 판독(재시작 팝업)의 캡처 실패 → 곧바로 거짓 (공용 스윕 첫 판독 가드와 같은 뜻)
  $plan = $null
  if ($null -ne $script:sweepPlan) { $plan = & $script:sweepPlan }
  elseif ($null -ne $script:sweepSpec -and (Elapsed) -ge [double]$script:sweepSpec.From -and [int]$script:sweepSpec.Count -ne 0) {
    if ([int]$script:sweepSpec.Count -gt 0) { $script:sweepSpec.Count = [int]$script:sweepSpec.Count - 1 }
    $plan = @{ Kind = [string]$script:sweepSpec.Kind; Gap = [double]$script:sweepSpec.Gap }
  }
  if ($null -eq $plan) { return $false }
  $gap = $(if ($plan.ContainsKey('Gap')) { [double]$plan.Gap } else { 1.0 })
  $script:sweepTrue++
  switch ([string]$plan.Kind) {
    'sent' { Tick $gap; $script:lastClickPerformed = $true; $script:lastClickSkipReason = ''; return $true }
    'cursor' { Tick $gap; $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'cursor-not-ready'; return $true }
    'ua-wait' {
      $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'
      Wait-UserYieldEnd -Game $Game -Context '구매 팝업 닫기'
      return $true
    }
    'ua-deleg' { Tick $gap; $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'; $script:activeQueue = 1; return $true }
    'recover' { Register-MockFail; Tick $gap; Register-MockSuccess; $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'cursor-not-ready'; return $true }
    'fail-false' { Register-MockFail; Tick $gap; $script:sweepTrue--; return $false }
  }
  throw "모의 스윕 종류 오류: $($plan.Kind)"
}
function Set-SweepFrom {
  # 케이스 시작 기준 From 초부터 같은 결과의 스윕 참 (Count 를 주면 그 횟수만, -1 = 영구). 클로저를 쓰지 않습니다 - 함수 안 GetNewClosure 는
  # `$script:` 변수를 `$null` 로 읽음(규칙 3)
  param([double]$From, [string]$Kind, [double]$Gap = 1.0, [int]$Count = -1)
  $script:sweepPlan = $null
  $script:sweepSpec = @{ From = $From; Kind = $Kind; Gap = $Gap; Count = $Count }
}

# ── 클릭 모의 (관측된 전이만 기본값) ──
#  터치(636,358) on prompt → 1초 뒤 afterTouch(기본 파티원 보상) / 준비(1077,655) on 준비 전 패널 → afterReady(기본 0.5초 뒤 준비됨 - 3인 이상 흐름)
#  앵커 on 접힘 → afterAnchor(기본 0.3초 뒤 보상 위 준비 전 패널) / (492,654) on 보상 위 펼침 → 0.3초 뒤 접힘(관측)
#   (접힘 = entryWaiting(앵커 '대기'@743) · entryWaitingM4(M4-pre 앵커 '자대기중'@744). 743·744 는 같은 버튼 안이라 두 자리 모두 펼침 - 어느 자리를
#    눌렀는지는 케이스가 클릭 좌표로 단언합니다)
#  '나가기'(515 보상·492 접힘)·(492,654) on 보상 → afterLeave(기본 1초 뒤 로딩 4초 → 도착(HUD 거짓 1초) → 필드 - 09-29 1·2·6판)
#  필드 위 펼친 패널의 (492,654) 는 전이 없이 오클릭으로만 기록 (미관측 - 누르면 안 되는 자리)
$touchPoint = "$($ptClearCenter[0]),$($ptClearCenter[1])"
$readyPoint = "$($ptPartyEnter[0]),$($ptPartyEnter[1])"
$collapsePoint = "$($ptMemberPanelCollapse[0]),$($ptMemberPanelCollapse[1])"
function Get-NextSend { param([string]$Point)
  if ($script:sendByPoint.ContainsKey($Point) -and @($script:sendByPoint[$Point]).Count -gt 0) {
    $q = @($script:sendByPoint[$Point]); $script:sendByPoint[$Point] = @($q | Select-Object -Skip 1); return [string]$q[0] }
  if ($script:sendSeq.Count -gt $script:sendIdx) { $r = $script:sendSeq[$script:sendIdx]; $script:sendIdx++; return [string]$r }
  return 'sent'
}
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY)
  $pt = "$ReferenceX,$ReferenceY"
  $result = Get-NextSend $pt
  $script:lastClickPerformed = ($result -eq 'sent')
  $script:lastClickSkipReason = $(if ($result -eq 'sent') { '' } else { $result })
  $script:clickAttempts.Add("$pt@$([Math]::Round((Elapsed), 1))")
  if ($result -ne 'sent') { $script:skipped++; if ($result -eq 'user-active') { $script:skippedActive++ } else { $script:skippedCursor++ }; return }
  $script:clicks.Add($pt)
  $script:clickTimes.Add((Elapsed))
  $s = Screen-Now
  if ($null -ne $script:clickHook) { if (& $script:clickHook $pt $s) { return } }   # 케이스 전용 전이가 처리했으면 기본 전이 생략
  if ($pt -eq $touchPoint -and $s -eq 'prompt') {
    if ($script:afterTouch -is [string]) { if ($script:afterTouch) { Set-ScreenAfter 1 @((Step 0 $script:afterTouch)) } }
    elseif ($null -ne $script:afterTouch) { Set-ScreenAfter 0 $script:afterTouch }
    return
  }
  if ($pt -eq $readyPoint -and ($s -eq 'readyAvail' -or $s -eq 'readyField')) {
    if (-not $script:readyIgnored) {
      $steps = $null
      if ($script:afterReadyQueueIdx -lt @($script:afterReadyQueue).Count) { $steps = $script:afterReadyQueue[$script:afterReadyQueueIdx]; $script:afterReadyQueueIdx++ }
      elseif ($null -ne $script:afterReady) { $steps = $script:afterReady }
      elseif ($s -eq 'readyAvail') { $steps = @((Step 0.5 'readyDone')) }
      else { $steps = @((Step 0.5 'readyDoneField')) }
      if ($null -ne $steps) { Set-ScreenAfter 0 $steps }
    }
    return
  }
  if (($pt -eq '743,654' -or $pt -eq '744,654') -and ($s -eq 'entryWaiting' -or $s -eq 'entryWaitingM4')) {
    $steps = $script:afterAnchor
    if ($script:afterAnchorQueueIdx -lt @($script:afterAnchorQueue).Count) { $steps = $script:afterAnchorQueue[$script:afterAnchorQueueIdx]; $script:afterAnchorQueueIdx++ }
    if ($null -ne $steps -and @($steps).Count -gt 0) { Set-ScreenAfter 0 $steps }
    return
  }
  if ($pt -eq $collapsePoint -and $s -eq 'readyAvail') { Set-ScreenAfter 0.3 @((Step 0 'entryWaiting')); return }
  if ($pt -eq $collapsePoint -and ($s -eq 'readyField' -or $s -eq 'readyDoneField' -or $s -eq 'readyOther')) { $script:misclicks.Add("$pt@$s"); return }
  if (($pt -eq '515,654' -and $s -eq 'memberReward') -or ($pt -eq '492,654' -and ($s -eq 'entryWaiting' -or $s -eq 'memberReward'))) {
    $script:leaveSendTimes.Add((Elapsed))
    if (-not $script:leaveIgnored) { Set-ScreenAfter 0 $script:afterLeave }
    return
  }
  $script:misclicks.Add("$pt@$s")
}

# ── 그 밖의 운영 경계 모의 ──
function Write-RunLog { param([string]$Message)
  $script:logs.Add(('{0,8} {1}' -f ([Math]::Round((Elapsed), 1)).ToString([Globalization.CultureInfo]::InvariantCulture), $Message))
  foreach ($hook in @($script:logHooks)) {
    if (-not $hook.Done -and $Message -match $hook.Pattern) { if ($hook.Once) { $hook.Done = $true }; & $hook.Action }
  }
}
function Write-LifeDiagnostics { param($Game, $Context, [switch]$CaptureOnly) $script:diag.Add("$Context|$([bool]$CaptureOnly)") }
function Invoke-AfterEntryKeys { param($Game, $LogPrefix) $script:keys++; $script:keyTimes.Add((Elapsed)) }
function Clear-EventOverlay { param($Game) $script:overlays++; $script:overlayTimes.Add((Elapsed)); return $false }
function Wait-ForDungeonClearScreen { param($Game, $TimeoutSeconds, [switch]$DungeonMode, $FindResultButton, [switch]$MemberMode)
  # 클리어 감시 모의: -MemberMode 를 기록하고 계획의 다음 결과를 돌려줍니다 (기본: 60초 뒤 'clear' + 화면 S). Throw 를 주면 그 메시지로 throw (X9)
  $script:clearWaits++
  $script:memberModeCalls += [int][bool]$MemberMode
  $spec = $(if ($script:clearPlan.Count -ge $script:clearWaits) { $script:clearPlan[$script:clearWaits - 1] } else { $script:clearDefault })
  if ($spec.ContainsKey('Throw')) { Tick ([double]$spec.Advance); throw [string]$spec.Throw }
  if ($spec.ContainsKey('At')) { Tick ([double]$spec.At - (Elapsed)) } else { Tick ([double]$spec.Advance) }
  $script:clearReturnTimes.Add((Elapsed))
  if ($spec.ContainsKey('Steps')) { Set-ScreenAfter 0 $spec.Steps }
  if ($spec.ContainsKey('Hook')) { & $spec.Hook }
  return [string]$spec.Return
}
function Clear-Spec { param([string]$Return = 'clear', [object[]]$Steps = $null, [double]$Advance = 60)
  $stepList = $(if ($null -ne $Steps) { $Steps } elseif ($Return -eq 'clear') { @((Step 0 'prompt')) } elseif ($Return -eq 'member-reward') { @((Step 0 'memberReward')) } elseif ($Return -eq 'ready') { @((Step 0 'readyAvail')) } elseif ($Return -eq 'entry-waiting') { @((Step 0 'entryWaiting')) } else { @() })
  return @{ Return = $Return; Steps = $stepList; Advance = $Advance }
}
$safeStopFlagPath = 'HoneyNogi_member_safe_stop_test.flag'
function Test-Path { param($LiteralPath, $Path, $PathType)
  if ($LiteralPath -eq $safeStopFlagPath) { return [bool]$script:safeStopFlag }
  return $false
}
function Remove-Item { param($LiteralPath, $Path, [switch]$Force, $ErrorAction)
  # 소비 = 실제 Remove-Item 호출 수로 셉니다. -ErrorAction 이 없는데 파일이 없으면 운영처럼 예외 (F9 취소 경합 - R-F9)
  if ($LiteralPath -eq $safeStopFlagPath) {
    $script:removes++
    if ($script:flagVanishOnRemove) { $script:safeStopFlag = $false }
    if (-not $script:safeStopFlag -and "$ErrorAction" -ne 'SilentlyContinue') { throw "경로가 없어 찾을 수 없습니다: $LiteralPath" }
    $script:safeStopFlag = $false
  }
}

# ── GUI 모형 (시간 지정 '그 판까지' 설계 8.1 - 회귀 R-10) ──
# 워커 체인(§2-K)에서 '다음 워커를 띄울지' 를 사본이 아니라 GUI 소스가 정하게 합니다. 옛 하니스는 'exit 0 이면 늘 이어 감' 이라 시간 지정의
# 판단 주체 하나(조건 4 - 이어 간 판은 이어받고 마지막 뒤에는 멈춤)를 행동으로 보지 못했습니다. 다음 회차 판단 순수부·실행부와 그 둘이 부르는
# 시간 판단·문구 함수는 GUI 소스에서 추출하고, 그 밖의 GUI 경계(정지·다음 회차 기동·로그 창·상태줄 색·숫자 상자)만 기록 모의로 둡니다.
# 시각은 위 Get-Date 모의(가상 시계)를 그대로 씁니다 - GUI 의 '지금 < 지정 시각' 도 같은 가상 시계로 판단합니다
$guiTokens = $null; $guiErrors = $null
$guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$guiErrors)   # §5 GUI 배선 단언도 이 AST·토큰을 씀
if ($guiErrors.Count -gt 0) { throw "GUI 파서 오류: $($guiErrors[0].Message)" }
Add-Type -AssemblyName System.Drawing   # Invoke-NextCycleDecision 의 준비 실행 3회 연속 갈래가 [System.Drawing.Color]::Firebrick 을 씀 (시간 지정 설계 S4)
foreach ($definition in Get-SourceFunctionDefinitions -Path $guiPath -Names @('Get-NextCycleAction', 'Invoke-NextCycleDecision', 'Test-TimeAllowsNextCycle', 'Get-CycleWaitSecondsForEstimate', 'Get-TimeStopNotice')) {
  Invoke-Expression $definition
}
function Stop-AllRun { param([string]$Reason, [switch]$IsError) $script:guiDecision = "stop:$Reason" }   # GUI 와 같은 서명 - 정지 사유만 기록
function Start-NextCycle { $script:guiDecision = 'next' }                                                 # 다음 회차 기동 = 체인이 다음 워커를 돌림
function Add-GuiLog { param([string]$Message) $script:guiLogs += $Message }                               # 로그 창 줄 (시간 정지 안내·11 안내)
$lblStatus = [pscustomobject]@{ ForeColor = $null }
$numGatherWait = [pscustomobject]@{ Value = 600 }   # 생활 '진행 없음 한도' 숫자 상자 (전투 케이스에서는 읽지 않음)
$numClearWait = [pscustomobject]@{ Value = 600 }    # 전투 '클리어 대기' 숫자 상자 (전투 시간 판단은 이 값을 쓰지 않음 - 기타의 시작 거부 전용)
# 전투 UNTIL 생산식 = GUI Start-NextCycle 의 '판 끝에서 스스로 판단하는 워커' 분기(Test-WorkerTimeJudgeActive) 대입문 우변 - 설계 리뷰 1차 P2 의
# InvariantCulture 생산을 사본 없이 그대로 평가합니다. 케이스의 목표 시각 하나에서 GUI 모형의 $script:targetTime 과 워커가 읽는 UNTIL 을 함께 만들어
# 두 값이 갈라지지 않게 합니다 (설계 8.1). 분기·대입이 정확히 1곳이 아니면 모형이 성립하지 않으므로 여기서 멈춥니다 (fail-closed)
$guiNextCycleAst = $guiAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Start-NextCycle' }, $true)
$battleUntilIfs = @($guiNextCycleAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text.Contains('Test-WorkerTimeJudgeActive') }, $true))
$battleUntilAssigns = @(if ($battleUntilIfs.Count -eq 1) {
    $battleUntilIfs[0].Clauses[0].Item2.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$env:HONEYNOGI_UNTIL_TIME' }, $true) })
if ($battleUntilAssigns.Count -ne 1) { throw "GUI 전투 UNTIL 생산식을 찾지 못했습니다 (판단 워커 분기 $($battleUntilIfs.Count)곳, UNTIL 대입 $($battleUntilAssigns.Count)곳)" }
$battleUntilExpression = [string]$battleUntilAssigns[0].Right.Extent.Text
function Set-MemberTimeTarget {
  # 시간 지정 케이스의 목표 시각 ('yyyy-MM-dd HH:mm') - GUI 모형의 목표 시각을 정하고, 워커가 읽는 HONEYNOGI_UNTIL_TIME 은 그 값을 GUI 생산식으로 만듭니다
  param([string]$Text)
  $script:targetTime = [datetime]::ParseExact($Text, 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
  $env:HONEYNOGI_UNTIL_TIME = [string](Invoke-Expression $battleUntilExpression)
}

# ── 케이스 초기화·실행·집계 ──
$script:clearDefault = (Clear-Spec 'clear')
function Reset-Member {
  param([object[]]$Plan)
  $script:vclock = [datetime]'2026-10-01 10:00:00'; $script:caseStart = $script:vclock
  $script:plan = @($Plan)
  $script:logs = New-Object 'System.Collections.Generic.List[string]'
  $script:diag = New-Object 'System.Collections.Generic.List[string]'
  $script:clicks = New-Object 'System.Collections.Generic.List[string]'
  $script:clickTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:clickAttempts = New-Object 'System.Collections.Generic.List[string]'
  $script:misclicks = New-Object 'System.Collections.Generic.List[string]'
  $script:leaveSendTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:keyTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:captureTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:yieldContexts = New-Object 'System.Collections.Generic.List[string]'
  $script:pCalls = New-Object 'System.Collections.Generic.List[object]'
  $script:skipped = 0; $script:skippedActive = 0; $script:skippedCursor = 0; $script:keys = 0
  $script:clearWaits = 0; $script:memberModeCalls = 0; $script:clearPlan = @(); $script:overlays = 0; $script:removes = 0
  $script:safeStopFlag = $false; $script:flagVanishOnRemove = $false; $script:safeStopCalls = 0; $script:probeCalls = 0
  $script:yieldWaits = 0; $script:yieldSeconds = 3; $script:userYieldTotalMs = [double]0; $script:onYield = $null
  $script:screenCaptureFailing = $false; $script:captureFailSerial = 0; $script:failSince = $null; $script:failTotalMs = [double]0; $script:failedReads = 0
  $script:capWindow = $null; $script:persistFail = $false; $script:failHook = $null; $script:readHook = $null
  $script:activeWindow = $null; $script:activeQueue = 0
  $script:promptReads = 0; $script:wordReads = 0; $script:turnReads = @{ prompt = 0; panel = 0; words = 0 }; $script:wordsOverride = $null
  $script:sweepCalls = 0; $script:sweepTrue = 0; $script:sweepPlan = $null; $script:useRealSweep = $false
  $script:sendSeq = @(); $script:sendIdx = 0; $script:sendByPoint = @{}; $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타 - 서두 비움이 없으면 오발동
  $script:afterTouch = 'memberReward'; $script:afterReady = $null; $script:afterAnchor = @((Step 0.3 'readyAvail')); $script:readyIgnored = $false
  $script:afterLeave = @((Step 1 'loading'), (Step 5 'arrival'), (Step 6 'field')); $script:leaveIgnored = $false; $script:clickHook = $null
  $script:logHooks = @()
  $script:dgLastRun = $false; $script:abyssLeaveCause = $null
  # 시간 지정은 케이스가 Set-MemberTimeTarget 으로만 켭니다 (GUI 모형 목표 시각과 UNTIL 을 한 값에서). 사이클 추정치 env 는 워커가 읽지 않습니다 (§0)
  $env:HONEYNOGI_UNTIL_TIME = ''
  # GUI 모형 상태 (회귀 R-10 - 체인 하니스가 워커마다 이 상태로 GUI 판단을 돌림): 비시간·무한 반복·전투·비커스텀이 기본
  $script:targetTime = $null; $script:mainCategory = 'battle'; $script:stopRequested = $false; $script:targetCycles = 0
  $script:completedCycles = 0; $script:preparedStreak = 0; $script:customActive = $false; $script:guiDecision = ''; $script:guiLogs = @()
  $script:exitCode = $null; $script:threw = ''; $script:el = 0
  $script:keepPlan = $false; $script:afterReadyQueue = @(); $script:afterAnchorQueue = @(); $script:afterReadyQueueIdx = 0; $script:afterAnchorQueueIdx = 0; $script:sweepSpec = $null
  $script:turnId = 0; $script:transientSeq = @('transient', 'transient2'); $script:transientThen = 'inside'; $script:transientIdx = 0; $script:transientTurn = -1; $script:transientCur = ''
  $script:transientLog = New-Object 'System.Collections.Generic.List[string]'
  $script:promptReadTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:yieldTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:overlayTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:clearReturnTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:samples = New-Object 'System.Collections.Generic.List[object]'
  $script:cursorParkCalls = 0; $script:cursorParkInFail = 0; $script:restartArmed = $false
  $script:timeoutClear = $capturedTimeoutClear
}
function Run-Member {
  # D 한 워커를 끝까지 돌립니다 - 모든 출구가 exit(센티널)이라 반환은 결함, 그 밖의 예외는 메시지를 남깁니다 (X9 - 클리어 감시 throw 는 삼키지 않음)
  $script:exitCode = $null; $script:threw = ''
  try { Invoke-AbyssPartyMemberCycle -Game $null; $script:threw = '(반환됨)' }
  catch {
    if ($_.Exception.Message -match '^__EXIT__(\d+)$') { $script:exitCode = [int]$Matches[1] }
    else { $script:threw = $_.Exception.Message }
  }
  $script:el = [Math]::Round((Elapsed), 1)
}
function Add-LogHook { param([string]$Pattern, [scriptblock]$Action, [switch]$Every)
  $script:logHooks = @($script:logHooks) + @(@{ Pattern = $Pattern; Action = $Action; Once = (-not $Every); Done = $false })
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }
function Count-Click { param([string]$Point) @($script:clicks | Where-Object { $_ -eq $Point }).Count }
function Last-Done { $done = @($script:logs | Where-Object { $_ -match '\[완료\]' }); if ($done.Count) { $done[-1] -replace '^\s*[\d.,]+\s', '' } else { '' } }
function Test-LastDone { param([string]$Pattern) return [int]((Last-Done) -match $Pattern) }
function Get-LeaveResults { return (@($script:pCalls | ForEach-Object { [string]$_.Result.Result }) -join ',') }
function Get-Summary { "exit=$($script:exitCode) threw=$($script:threw) t=$($script:el) clicks=$($script:clicks -join ';') P=$(Get-LeaveResults) done=$(Last-Done)" }
function Get-AdjustedStop { return [Math]::Round((Elapsed) - ($script:failTotalMs / 1000.0), 1) }
function Get-MaxCaptureGap { param([double]$From, [double]$Until)
  $times = @($script:captureTimes | Where-Object { $_ -ge $From -and $_ -lt $Until } | Sort-Object)
  if ($times.Count -lt 2) { return 9999 }
  $gap = 0.0
  for ($i = 1; $i -lt $times.Count; $i++) { if (($times[$i] - $times[$i - 1]) -gt $gap) { $gap = $times[$i] - $times[$i - 1] } }
  return [Math]::Round($gap, 2)
}
function Get-LeaveLog { @($script:logs | Where-Object { $_ -match '필드 확인 \(퇴장 방향 클릭 → 로딩 (\d+)표본' }) }
function Get-LeftDepartSamples {
  # 'left' 로그의 로딩 표본 수 n (설계 5.1 끝 단락 - 'left' 를 기대하는 케이스는 n ≥ 1 을 함께 단언)
  $line = @(Get-LeaveLog) | Select-Object -Last 1
  if ($line -match '로딩 (\d+)표본') { return [int]$Matches[1] }
  return -1
}

# ── §2-A. START 열 (새 워커 - 어느 화면에서 시작해도 이어받음) ───────────────────
$anchorPoint = '743,654'
$leavePoint = '515,654'
$wLimit = [double]$memberFieldSettleSeconds
$mLimit = [double]$capturedTimeoutClear
function Get-Label { param([string]$Screen, [bool]$OverReward = $false, [string]$Stage = '', [bool]$ExitSent = $false) Get-AbyssMemberScreenLabel -Screen $Screen -OverReward $OverReward -Stage $Stage -ExitSent $ExitSent }
function Get-FirstLeave { if ($script:pCalls.Count -gt 0) { return $script:pCalls[0].Result } return @{ Result = '(P 없음)'; Screen = ''; Stage = ''; ExitSends = -1 } }
function Test-LastDoneContains { param([string]$Text) return [int]((Last-Done).Contains($Text)) }
$stopClear = @{ Return = ''; Throw = '__STOP__'; Advance = 1 }   # 입장 확인 뒤 케이스를 끝낼 때 - 클리어 감시에서 멈춤 표지를 던짐

# A1 field 시작 → 클릭 0, M 뒤 P → 필드 모양 W 이상 → 'stayed'(필드 모양, 나가기 0) → 진단 + exit 4 (09-30 리뷰1 - 옛 기대 'left')
Reset-Member -Plan @((P 0 'field'))
Run-Member
$lr = Get-FirstLeave
Check-Equal "A1 필드 시작: exit 4, 클릭 0, P 1회('member-timeout') → stayed(Screen field, 전송 0), 필드 모양 M 초과 문구" (
  J @($script:exitCode, $script:clicks.Count, $script:pCalls.Count, $script:pCalls[0].Reason, $lr.Result, $lr.Screen, $lr.ExitSends,
    (Test-LastDone '^\[완료\] 파티원: 필드로 보이는 화면이라 누르지 않고 대기를 마칩니다 \(필드 미확정\) - 파티장의 다음 입장이'))) '4/0/1/member-timeout/stayed/field/0/1'
Check-True "A1 정지 = M($mLimit) + W($wLimit) ± 3초 (실제 $($script:el))" ([Math]::Abs($script:el - ($mLimit + $wLimit)) -le 3) (Get-Summary)
Check-Equal 'A1 진단 캡처(png 만) 1' (@($script:diag | Where-Object { $_ -like '*|True' }).Count) 1

# A2 보상 시작 → 대기 → M → 나가기@515 1 → 로딩 → field 2연속 → left → exit 4('M 초과' left 문구)
Reset-Member -Plan @((P 0 'memberReward'))
Run-Member
Check-Equal "A2 보상 시작: 나가기@515 1, P left, exit 4 'M 초과' left 문구" (
  J @((Count-Click $leavePoint), (Get-FirstLeave).Result, $script:exitCode, (Test-LastDone '^\[완료\] 파티장의 다음 입장이 \d+초\(클리어 대기 설정\) 안에 없어 나가기로 필드에 나와 파티원 대기를 마칩니다$'))) '1/left/4/1'
Check-True "A2 P 서두 = M 만료(약 $mLimit 초, 실제 $($script:pCalls[0].At)) · 'left' 로그의 로딩 표본 n ≥ 1 (실제 $(Get-LeftDepartSamples))" (
  ($script:pCalls[0].At -ge $mLimit) -and ($script:pCalls[0].At -le $mLimit + 1.5) -and ((Get-LeftDepartSamples) -ge 1)) (Get-Summary)

# A3 prompt 시작 → 터치 1 → 보상(계상 0) → A2 경로, 터치 총 1
Reset-Member -Plan @((P 0 'prompt'))
Run-Member
Check-Equal 'A3 S 시작: 터치 총 1, 나가기 1, left, exit 4 (START 는 계상 대기 없음)' (J @((Count-Click $touchPoint), (Count-Click $leavePoint), (Get-FirstLeave).Result, $script:exitCode)) '1/1/left/4'

# A4 readyAvail 시작 + LAST_RUN=1 → 준비 1 → 입장 → 키 1 → -MemberMode 1 → 'clear' → 터치 1 → 보상 → P → 나가기 → 로딩 → left → exit 0
Reset-Member -Plan @((P 0 'readyAvail'))
$script:dgLastRun = $true
$script:afterReady = @((Step 0.5 'readyDone'), (Step 5 'entryLoading'), (Step 9 'inside'))
Run-Member
Check-Equal 'A4 준비 시작 + 마지막 회차: 준비 1(START 는 last-run 미적용), 키 1, -MemberMode 1, 터치 1, 나가기 1, left → exit 0' (
  J @((Count-Click $readyPoint), $script:keys, $script:memberModeCalls, (Count-Click $touchPoint), (Count-Click $leavePoint), (Get-LeaveResults), $script:exitCode)) '1/1/1/1/1/left/0'
Check-Equal "A4 문구 '마지막 회차(횟수 지정)라 나가기로 필드에 나와 마칩니다' · left 로그 n ≥ 1" (
  J @((Test-LastDone '^\[완료\] 파티원 회차 완료 - 마지막 회차\(횟수 지정\)라 나가기로 필드에 나와 마칩니다$'), [int]((Get-LeftDepartSamples) -ge 1))) '1/1'

# A5 readyDone 시작 → 클릭 0 → 300초(준비 시계) → P committed → exit 4 '준비 상태는 그대로'
Reset-Member -Plan @((P 0 'readyDone'))
Run-Member
Check-Equal "A5 준비됨 시작: 클릭 0, P 'ready-timeout' committed, exit 4 '준비 상태는 그대로 둡니다'" (
  J @($script:clicks.Count, $script:pCalls[0].Reason, (Get-FirstLeave).Result, $script:exitCode, (Test-LastDone '준비 상태는 그대로 둡니다\)$'))) '0/ready-timeout/committed/4/1'
Check-True "A5 P 서두 = 준비 시계 $memberReadyLimitSeconds 초 (실제 $($script:pCalls[0].At))" (($script:pCalls[0].At -ge $memberReadyLimitSeconds) -and ($script:pCalls[0].At -le $memberReadyLimitSeconds + 1.5)) (Get-Summary)

# A6 entry 시작 → 앵커 1 → readyAvail → 준비 1
Reset-Member -Plan @((P 0 'entryWaiting'))
Run-Member
Check-Equal 'A6 접힌 패널 시작: 재펼침 앵커(743,654) 1 → 펼친 준비 전 패널 → 준비 1' (J @((Count-Click $anchorPoint), (Count-Click $readyPoint))) '1/1'

# A6′ entry 시작 - 09-26 M4-pre 판독(커서가 '입장' 을 가림 → 앵커 '자대기중'@744) → D 재펼침 클릭은 정확히 (744,654) → readyAvail → 준비 1.
#     실측 접힘 7프레임의 앵커는 모두 743 이라 D 가 앵커 대신 고정 (743,654) 를 눌러도 행동이 같습니다 - 그 변이는 이 프레임으로만 행동에서 드러남
#     (변이 검증 2026-10-01, §3 앵커 클릭 배선과 짝)
Reset-Member -Plan @((P 0 'entryWaitingM4'))
Run-Member
Check-Equal "A6′ 접힌 패널(M4-pre '자대기중'@744) 시작: 클릭 순서 = 재펼침 (744,654) → 준비, (744,654) 1·(743,654) 0, 재펼침 로그 기준좌표 (744,654), 오클릭 0" (
  J @(($script:clicks -join ';'), (Count-Click '744,654'), (Count-Click $anchorPoint), (Count-Log "'입장 대기 중' 클릭 \(1/2, 기준좌표 \(744,654\)\)"), $script:misclicks.Count)) "744,654;$readyPoint/1/0/1/0"

# A7 entry 지속(재펼침 무반응) → D 재펼침 2 → M 만료 → P(중단 없음) 재펼침 2 → P 마감 → stayed(퇴장 방향 전송 0) → 진단 + exit 4, 재펼침 총 4 (09-30 정정)
Reset-Member -Plan @((P 0 'entryWaiting'))
$script:afterAnchor = $null
Run-Member
$lr = Get-FirstLeave
Check-Equal 'A7 접힘 무반응: 재펼침 총 4(D 2 + P 탐침 2), P stayed·전송 0·Screen entry-waiting, exit 4, 라벨(접힌 준비 패널)' (
  J @((Count-Click $anchorPoint), $lr.Result, $lr.ExitSends, $lr.Screen, $script:exitCode, (Test-LastDoneContains "($(Get-Label 'entry-waiting'))"))) '4/stayed/0/entry-waiting/4/1'
Check-Equal "A7 START 재펼침 중단 안내 1 ('2번 눌러도 펼쳐지지 않아 더 누르지 않고 관측')" (Count-Log '접힌 준비 패널을 2번 눌러도 펼쳐지지 않아 더 누르지 않고 관측합니다') 1

# A8 matching → 클릭 0 → M → committed → exit 4
Reset-Member -Plan @((P 0 'matching'))
Run-Member
Check-Equal 'A8 재매칭 시작: 클릭 0, 재매칭 안내 1, M 만료 P committed(matching) → exit 4' (
  J @($script:clicks.Count, (Count-Log '재매칭 패널 감지 - 누를 것이 없어'), (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode)) '0/1/committed/matching/4'

# A9 inside → 키 1, -MemberMode 1
Reset-Member -Plan @((P 0 'inside'))
Run-Member
Check-Equal 'A9 던전 안 시작: inside 2연속 → INSIDE 전이 → 키 1, -MemberMode 1 (이후 보상 인계 exit 0)' (J @($script:keys, $script:memberModeCalls, (Count-Log '던전 입장 완료 감지'), $script:exitCode)) '1/1/1/0'

# A10 unknown - 29초 오버레이 0, 31초 1, 120초 1, 알려진 화면 뒤 31초 → 2
Reset-Member -Plan @((P 0 'unknown'), (P 120 'memberReward'), (P 125 'unknown'))
$script:keepPlan = $true
Run-Member
$overlayAt = @($script:overlayTimes)
Check-Equal "A10 알 수 없음 $memberUnknownOverlaySeconds 초 → 이벤트 정리 1회: 29초까지 0 · 31초까지 1 · 120초까지 1 · 알려진 화면 뒤 31초 → 2 (그 뒤 늘지 않음)" (
  J @(@($overlayAt | Where-Object { $_ -lt 29 }).Count, @($overlayAt | Where-Object { $_ -lt 31 }).Count, @($overlayAt | Where-Object { $_ -lt 120 }).Count,
    @($overlayAt | Where-Object { $_ -lt (125 + 31 + 1) }).Count, $overlayAt.Count)) '0/1/1/2/2'
Check-Equal "A10 이벤트 정리 안내 문구 2 ('알 수 없는 화면이 30초 이어져')" (Count-Log '알 수 없는 화면이 30초 이어져 이벤트 화면 정리를 한 번 시도합니다') 2

# A11 reward3 → 진단 + exit 4, 클릭 0
Reset-Member -Plan @((P 0 'reward3'))
Run-Member
Check-Equal "A11 3버튼 보상: 클릭 0, 진단 '파티원 3버튼 보상 화면', exit 4 (역할 오설정 문구)" (
  J @($script:clicks.Count, [int]($script:diag -contains '파티원 3버튼 보상 화면|True'), $script:exitCode, (Test-LastDone "3버튼 보상 화면\('다시 하기'\)이 보여 정지합니다"))) '0/1/4/1'

# A12 스윕 참 1회 → 다음 회전에서 보상 분류
Reset-Member -Plan @((P 0 'memberReward'))
Set-SweepFrom -From 0 -Kind 'sent' -Gap 1 -Count 1
Run-Member
$startLine = @($script:logs | Where-Object { $_ -match '시작 화면: ' })
Check-Equal "A12 스윕 참 1회 → 그 회전은 판독 없음, 다음 회전 시작 화면 '파티원 보상 화면' 1" (
  J @($script:sweepTrue, $startLine.Count, [int]($startLine[0].EndsWith("시작 화면: $(Get-Label 'member-reward')")), [int]($script:promptReadTimes[0] -ge 1))) '1/1/1/1'

# A13 가린 접힘 → 앵커 0·나가기 0
Reset-Member -Plan @((P 0 'entryOccluded'))
Run-Member
Check-Equal "A13 가린 접힘('…입장대가축' - unknown): 앵커 0·나가기(492/515) 0, 클릭 0 (현행 헬퍼라면 492 = 퇴장)" (
  J @((Count-Click $anchorPoint), (Count-Click '492,654'), (Count-Click $leavePoint), $script:clicks.Count)) '0/0/0/0'

# A14 readyField 시작 + G 없음 → 준비 1 (필드 위 준비 - 09-29 1·2판 관측 흐름)
Reset-Member -Plan @((P 0 'readyField'))
Run-Member
Check-Equal 'A14 필드 위 준비 패널 시작(G 없음): 준비 1, 접기 0, 오클릭 0' (J @((Count-Click $readyPoint), (Count-Click $collapsePoint), $script:misclicks.Count)) '1/0/0'

# A15 (미관측 — 2인 파티로 관측 불가) readyAvail 시작 → 준비 1 → (모의) 접힘 → 앵커 1 → readyDone → 준비 0·대기 → 입장 → 키 1 (결정 ⑵)
Reset-Member -Plan @((P 0 'readyAvail'))
$script:afterReady = @((Step 0.5 'entryWaiting'))
$script:afterAnchor = @((Step 0.3 'readyDone'), (Step 5 'entryLoading'), (Step 9 'inside'))
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal 'A15 (미관측 — 2인 파티로 관측 불가) 준비 뒤 접힘: 준비 1, 앵커 1, 준비됨에서 추가 준비 0, 입장 → 키 1' (J @((Count-Click $readyPoint), (Count-Click $anchorPoint), $script:keys, $script:threw)) '1/1/1/__STOP__'

# A16 (미관측 — 2인 파티로 관측 불가) entry 시작, 재펼치면 readyDone → 앵커 1 → 준비 0 → 입장 → 키 1
Reset-Member -Plan @((P 0 'entryWaiting'))
$script:afterAnchor = @((Step 0.3 'readyDone'), (Step 5 'entryLoading'), (Step 9 'inside'))
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal 'A16 (미관측 — 2인 파티로 관측 불가) 재펼침 뒤 준비됨: 앵커 1, 준비 0(준비 취소 금지), 키 1' (J @((Count-Click $anchorPoint), (Count-Click $readyPoint), $script:keys, $script:threw)) '1/0/1/__STOP__'

# A17 ready-other(cap_210545_900 '주년`완료') 10초 → 판독 회복(readyAvail) → ready-other 동안 클릭 0((1077,655) 포함), 회복 뒤 준비 1
Reset-Member -Plan @((P 0 'readyOther'), (P 10 'readyAvail'))
Run-Member
$clicksBefore10 = @(for ($i = 0; $i -lt $script:clicks.Count; $i++) { if ($script:clickTimes[$i] -lt 10) { $script:clicks[$i] } })
Check-Equal 'A17 ready-other 10초: 그동안 클릭 0(준비 버튼 포함), 회복 뒤 준비 1' (J @($clicksBefore10.Count, (Count-Click $readyPoint))) '0/1'

# A18 readyAvail 시작 + 준비 전송 수열 user-active, cursor-not-ready, cursor-not-ready, sent → 준비 1, 건너뜀 3, 관측 전환 로그 0 → 입장 → 키 1 (B3′ 의 START 짝)
Reset-Member -Plan @((P 0 'readyAvail'))
$script:sendByPoint[$readyPoint] = @('user-active', 'cursor-not-ready', 'cursor-not-ready', 'sent')
$script:afterReady = @((Step 0.5 'readyDone'), (Step 5 'entryLoading'), (Step 9 'inside'))
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal 'A18 준비 생략 수열(조작 1·커서 2·전송): 준비 전송 1, 건너뜀 3(조작 1·커서 2), 관측 전환 0, 키 1 (조작 생략은 커서 예산 미소모)' (
  J @((Count-Click $readyPoint), $script:skipped, $script:skippedActive, $script:skippedCursor, (Count-Log '관측하며 대기 한도를 다시 셉니다'), $script:keys)) '1/3/1/2/0/1'

# A19 entry 시작 + 클릭 직전 새 단어 판독의 앵커 null 지속(§1(b) 합성 행) → 판독 불일치 3 → 관측 로그 1 → 앵커 0 → M 600 → P 탐침도 불일치(클릭 0) → P 60초 → stayed(접힌 패널) → exit 4, 약 660초 (09-30 리뷰1 P1-2)
Reset-Member -Plan @((P 0 'entryWaiting'))
$script:wordsOverride = $wSplit
Run-Member
$lr = Get-FirstLeave
Check-Equal 'A19 앵커 null 지속: D 불일치 로그 3, 관측 안내 1, 앵커 0, P stayed(entry-waiting·전송 0), exit 4, VTIMEOUT 없음' (
  J @((Count-Log '재펼침 건너뜀 - 클릭 직전 판독이 접힌 패널과 다릅니다'), (Count-Log '클릭 직전 판독에서 3번 확인하지 못해 더 누르지 않고 관측합니다'), (Count-Click $anchorPoint),
    $lr.Result, $lr.Screen, $lr.ExitSends, $script:exitCode, $script:threw)) '3/1/0/stayed/entry-waiting/0/4/'
Check-True "A19 정지 약 M + P 한도 = $($mLimit + $memberLeaveLimitSeconds) 초 (실제 $($script:el))" ([Math]::Abs($script:el - ($mLimit + $memberLeaveLimitSeconds)) -le 3) (Get-Summary)
$a19Label = [regex]::Escape((Get-Label 'entry-waiting'))
Check-Equal "A19 'M 초과' stayed 문구(라벨 접힌 준비 패널)" (Test-LastDone ('안에 없어 파티원 대기를 마칩니다 - 나갈 수 없는 화면이라\(' + $a19Label + '\) 누르지 않음$')) 1

# ── §2-B. CLEAR 열 (클리어 뒤 첫 신호 = 회차 경계) ─────────────────────────────
# 시작은 던전 안(inside 2연속 → INSIDE 전이 → 키 → 클리어 감시 모의)이고, 클리어 감시 모의가 돌려준 결과·화면이 경계 신호입니다.
function Get-ClicksAfter { param([double]$From) @(for ($i = 0; $i -lt $script:clicks.Count; $i++) { if ($script:clickTimes[$i] -ge $From) { $script:clicks[$i] } }) }
$leftHandoff = '^\[완료\] 파티원 회차 완료 - 마지막 회차\(횟수 지정\)라 나가기로 필드에 나와 마칩니다$'
$readyHandoff = '^\[완료\] 파티원 회차 완료 - 준비 완료를 누르고 다음 워커가 입장을 이어받습니다$'

# B1 'clear' → 터치 1 → 보상 → exit 0, 추가 클릭 0 (G 없음 - 경계에서 나가기 없음)
Reset-Member -Plan @((P 0 'inside'))
Run-Member
Check-Equal "B1 'clear' → 터치 1 → 보상 → exit 0 '보상 화면에서 다음 워커가', 추가 클릭 0" (
  J @($script:exitCode, (Count-Click $touchPoint), $script:clicks.Count, (Test-LastDone '보상 화면에서 다음 워커가 파티장의 입장을 이어받습니다$'), $script:pCalls.Count)) '0/1/1/1/0'

# B2 'member-reward'(S 놓침) → exit 0, 터치 0
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'member-reward'))
Run-Member
Check-Equal "B2 'member-reward'(S 놓침) → 터치 0, exit 0" (J @($script:exitCode, (Count-Click $touchPoint), $script:clicks.Count)) '0/0/0'

# B3 'ready' — 보상 위 readyAvail / 필드 위 readyField 두 변형 → 준비 1(전송 확인) → 1초 → exit 0 '준비 완료를 누르고', 접기·나가기 0 (09-30 결정 D1)
foreach ($variant in @('readyAvail', 'readyField')) {
  Reset-Member -Plan @((P 0 'inside'))
  $script:clearPlan = @((Clear-Spec 'ready' @((Step 0 $variant))))
  Run-Member
  $readyAt = $(if ($script:clickTimes.Count) { $script:clickTimes[$script:clickTimes.Count - 1] } else { -1 })
  Check-Equal "B3 ($variant) 경계 준비 1 → 1초 → exit 0 '준비 완료를 누르고', 접기·나가기 0" (
    J @($script:exitCode, (Count-Click $readyPoint), (Count-Click $collapsePoint), (Count-Click $leavePoint), (Test-LastDone $readyHandoff), [Math]::Round($script:el - $readyAt, 1))) '0/1/0/0/1/1'
}

# B3′ B3 + 준비 전송 수열 user-active, cursor-not-ready, cursor-not-ready, sent → 양보 1 → 새 판독 → 준비 1, 건너뜀 3 → exit 0 (생략 회전에는 exit 0 없음)
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'ready'))
$script:sendByPoint[$readyPoint] = @('user-active', 'cursor-not-ready', 'cursor-not-ready', 'sent')
Run-Member
Check-Equal "B3′ 조작 1·커서 2 뒤 전송: 양보 ≥ 1, 준비 1, 건너뜀 3, '보내지 못해' 0, exit 0 '준비 완료를 누르고' (조작 생략은 커서 예산 미소모)" (
  J @([int]($script:yieldWaits -ge 1), (Count-Click $readyPoint), $script:skipped, (Count-Log '보내지 못해'), $script:exitCode, (Test-LastDone $readyHandoff))) '1/1/3/0/0/1'

# B3″ B3 + 커서 미확인 3회 → 준비 전송 0 → 인계 exit 0 '보내지 못해'. 관측 전환·M Set 없음
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'ready'))
$script:sendByPoint[$readyPoint] = @('cursor-not-ready', 'cursor-not-ready', 'cursor-not-ready')
Run-Member
Check-Equal "B3″ 경계 커서 미확인 3회 → 준비 0, 건너뜀 3, 인계 exit 0 '보내지 못해(커서 미확인 3회)', 관측 전환 0" (
  J @((Count-Click $readyPoint), $script:skippedCursor, $script:exitCode, (Test-LastDone "'준비 완료'를 보내지 못해\(커서 미확인 3회\) 다음 워커가 준비합니다$"), (Count-Log '관측하며 대기 한도를 다시 셉니다'))) '0/3/0/1/0'

# B3‴ B3 + 생략 뒤 양보 중 F9 파일 생성 (09-30 결정 D1·D2·D3)
#   보상 위: 다음 회전 G → P(G) → 접기 1 → 접힘 → 나가기 1 → 로딩 → left → exit 0, 준비 0, 소비 1
#   필드 위: 접기·나가기 0, 준비 0, 60초 → stayed → 반환 직전 소비 1 → 진단 + exit 4 '필드 위 준비 패널이라 … (회차 미계상)'
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyAvail'))))
$script:sendByPoint[$readyPoint] = @('user-active')
$script:onYield = { $script:safeStopFlag = $true }
Run-Member
Check-Equal 'B3‴ (보상 위) 생략 뒤 양보 중 F9 → P(G): 준비 0, 접기 1 + 나가기(단어 492) 1, 소비 1, left → exit 0' (
  J @((Count-Click $readyPoint), (Count-Click $collapsePoint), $script:removes, (Get-LeaveResults), $script:exitCode, (Test-LastDone '마지막 회차\(안전 중지 예약\)라 나가기로 필드에 나와 마칩니다$'))) '0/2/1/left/0/1'
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyField'))))
$script:sendByPoint[$readyPoint] = @('user-active')
$script:onYield = { $script:safeStopFlag = $true }
Run-Member
Check-Equal "B3‴ (필드 위) → 접기·나가기 0, 준비 0, P 60초 stayed, 반환 직전 소비 1, exit 4 '필드 위 준비 패널이라 … (회차 미계상)'" (
  J @((Count-Click $readyPoint), (Count-Click $collapsePoint), (Get-LeaveResults), $script:removes, $script:exitCode,
    (Test-LastDone '마지막 회차\(안전 중지 예약\)지만 필드 위 준비 패널이라 준비를 누르지 않고 마칩니다 \(회차 미계상\)$'), $script:misclicks.Count)) '0/0/stayed/1/4/1/0'

# B4~B6 readyDone / matching / inside 2연속 → exit 0, 추가 키 0, 클릭 0((1077,655) 포함 — ready-done 의 그 자리는 '준비 취소')
$b46 = @(
  @('B4 ready-done', 'ready', 'readyDone', '이미 준비된 다음 판을 다음 워커가 이어받습니다$'),
  @('B5 matching', 'clear', 'matching', '재매칭 중인 다음 판을 다음 워커가 이어받습니다$'),
  @('B6 inside 2연속', 'clear', 'inside', "다음 판 입장을 확인했습니다 \(다음 실행이 던전 안에서 이어받아 입장 키를 보냅니다\)$"))
foreach ($row in $b46) {
  Reset-Member -Plan @((P 0 'inside'))
  $script:clearPlan = @((Clear-Spec $row[1] @((Step 0 $row[2]))))
  Run-Member
  Check-Equal "$($row[0]) → 경계 인계 exit 0, 키 합 1(추가 키 0), 클릭 0(준비 버튼 포함)" (J @($script:exitCode, $script:keys, $script:clicks.Count, (Test-LastDone $row[3]))) '0/1/0/1'
}

# B7 'entry-waiting' → 앵커 1 → readyAvail → 준비 1 → exit 0 '준비 완료를 누르고' (09-30 결정 D1)
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'entry-waiting'))
Run-Member
Check-Equal "B7 경계 접힘 → 재펼침 1 → 준비 1 → exit 0 '준비 완료를 누르고'" (J @((Count-Click $anchorPoint), (Count-Click $readyPoint), $script:exitCode, (Test-LastDone $readyHandoff))) '1/1/0/1'

# B7′ 'entry-waiting' + 재펼침 무반응 → 앵커 2 → 준비 0 → 인계 exit 0 '다시 펼쳐지지 않아'
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'entry-waiting'))
$script:afterAnchor = $null
Run-Member
Check-Equal "B7′ 경계 재펼침 무반응 → 앵커 2(3번째 없음), 준비 0, 인계 exit 0 '다시 펼쳐지지 않아'" (
  J @((Count-Click $anchorPoint), (Count-Click $readyPoint), $script:exitCode, (Test-LastDone '접힌 준비 패널이 다시 펼쳐지지 않아 다음 워커가 이어받습니다$'))) '2/0/0/1'

# B7″ 'entry-waiting' + 재펼침 뒤 readyDone (미관측 — 2인 파티로 관측 불가) → 앵커 1 → 준비 0 → 인계 exit 0 '이미 준비된'
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'entry-waiting'))
$script:afterAnchor = @((Step 0.3 'readyDone'))
Run-Member
Check-Equal "B7″ (미관측 — 2인 파티로 관측 불가) 재펼침 뒤 준비됨 → 앵커 1, 준비 0, 인계 exit 0 '이미 준비된'" (
  J @((Count-Click $anchorPoint), (Count-Click $readyPoint), $script:exitCode, (Test-LastDone '이미 준비된 다음 판을 다음 워커가 이어받습니다$'))) '1/0/0/1'

# B8 LAST_RUN + 보상 → 나가기@515 1 → 로딩 → left → exit 0, 준비 0
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'member-reward'))
Run-Member
Check-Equal "B8 마지막 회차 + 보상 → 나가기@515 1, 준비 0, left → exit 0 '마지막 회차(횟수 지정)라'" (
  J @((Count-Click $leavePoint), (Count-Click $readyPoint), (Get-LeaveResults), $script:exitCode, (Test-LastDone $leftHandoff), [int]((Get-LeftDepartSamples) -ge 1))) '1/0/left/0/1/1'

# B9 LAST_RUN + 보상 위 readyAvail → 접기@(492,654) 1 → entry(무장) → 나가기(단어 492) 1 → 로딩 → left → exit 0, 준비 0·앵커 0
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready'))
Run-Member
Check-Equal 'B9 마지막 회차 + 보상 위 준비 전 패널 → 접기 1 + 나가기(단어 492) 1 = (492,654) 2, 준비 0, 앵커 0, left → exit 0' (
  J @((Count-Click $collapsePoint), (Count-Click $readyPoint), (Count-Click $anchorPoint), (Get-LeaveResults), $script:exitCode, (Test-LastDone $leftHandoff))) '2/0/0/left/0/1'
Check-Equal 'B9 접기 안내 1 (준비는 누르지 않음) · left 로그 n ≥ 1' (J @((Count-Log '준비 패널 접기 - 패널 밖'), [int]((Get-LeftDepartSamples) -ge 1))) '1/1'

# B10 LAST_RUN + entry → 앵커 1 → readyAvail → 접기 1 → 나가기 1 → 로딩 → left → exit 0
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'entry-waiting'))
Run-Member
Check-Equal 'B10 마지막 회차 + 접힘 → P 탐침 1 → 펼침(보상 위) → 접기 1 + 나가기 1, 준비 0, left → exit 0' (
  J @((Count-Click $anchorPoint), (Count-Click $collapsePoint), (Count-Click $readyPoint), (Get-LeaveResults), $script:exitCode)) '1/2/0/left/0'

# B10′ LAST_RUN + 경계 접힘 - 09-26 M4-pre 판독(앵커 '자대기중'@744) → P(G) 재펼침 탐침 클릭은 정확히 (744,654) → 펼침(보상 위) → 접기 1 + 나가기(단어 492) 1 →
#      left → exit 0. B10 의 실측 앵커 743 으로는 P 가 앵커 대신 고정 (743,654) 를 눌러도 행동이 같습니다 - 그 변이는 이 프레임으로만 행동에서 드러남
#      (변이 검증 2026-10-01, §3 앵커 클릭 배선과 짝)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'entry-waiting' @((Step 0 'entryWaitingM4'))))
Run-Member
Check-Equal "B10′ 마지막 회차 + 접힘(M4-pre '자대기중'@744) → 클릭 순서 = P 탐침 (744,654) → 접기 → 나가기(단어 492), (743,654) 0, 탐침 로그 기준좌표 (744,654), 준비 0, left → exit 0" (
  J @(($script:clicks -join ';'), (Count-Click $anchorPoint), (Count-Log '퇴장 절차 - 준비 상태 확인, 1/2\) - 기준좌표 \(744,654\)'), (Count-Click $readyPoint), (Get-LeaveResults), $script:exitCode)) "744,654;$collapsePoint;492,654/0/1/0/left/0"

# B11 LAST_RUN + readyDone → 이월 → 판 2 키 1 → -MemberMode 2 → 보상 → P → exit 0, 키 합 2
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyDone'), (Step 20 'entryLoading'), (Step 24 'inside'))), (Clear-Spec 'member-reward'))
Run-Member
Check-Equal 'B11 마지막 회차 + 경계 준비됨 → 이월 → 판 2 키(합 2) → -MemberMode 2 → 보상 → P left → exit 0 (이월 로그 1)' (
  J @($script:keys, $script:memberModeCalls, (Count-Log '\(이월\)$'), (Count-Click $leavePoint), (Get-LeaveResults), $script:exitCode, (Test-LastDone $leftHandoff))) '2/2/1/1/left/0/1'
$b11Keys = $script:keys

# B12 F9 + 보상(CLEAR) → 나가기 전송 직후 소비 1 → 로딩 → left → exit 0
Reset-Member -Plan @((P 0 'inside'))
$script:safeStopFlag = $true
$script:clearPlan = @((Clear-Spec 'member-reward'))
Run-Member
$leaveLogAt = @($script:logs | Where-Object { $_ -match '나가기 클릭 - 글자 탐색 기준좌표' } | ForEach-Object { [double](($_.Trim() -split '\s+')[0]) })
$consumeLogAt = @($script:logs | Where-Object { $_ -match '안전 중지 예약 확인 - 예약을 소비합니다' } | ForEach-Object { [double](($_.Trim() -split '\s+')[0]) })
Check-Equal "B12 F9 + 경계 보상 → 나가기 1, 소비 1(나가기 전송 직후 - 같은 시각), left → exit 0 '마지막 회차(안전 중지 예약)라'" (
  J @((Count-Click $leavePoint), $script:removes, [int]($consumeLogAt.Count -eq 1 -and $leaveLogAt.Count -eq 1 -and $consumeLogAt[0] -eq $leaveLogAt[0]), (Get-LeaveResults), $script:exitCode,
    (Test-LastDone '마지막 회차\(안전 중지 예약\)라 나가기로 필드에 나와 마칩니다$'))) '1/1/1/left/0/1'

# B13 F9 + readyDone(CLEAR) → 소비 0 → 이월 → 다음 경계 소비 1 → exit 0
Reset-Member -Plan @((P 0 'inside'))
$script:safeStopFlag = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyDone'), (Step 20 'entryLoading'), (Step 24 'inside'))), (Clear-Spec 'member-reward'))
Run-Member
$carryAt = @($script:logs | Where-Object { $_ -match '\(이월\)$' } | ForEach-Object { [double](($_.Trim() -split '\s+')[0]) })
Check-Equal 'B13 F9 + 경계 준비됨 → 이월(소비 0) → 다음 경계 P 1회 소비 1 → exit 0' (
  J @($carryAt.Count, $script:pCalls.Count, $script:removes, [int]($script:pCalls[0].At -gt $carryAt[0]), (Get-LeaveResults), $script:exitCode)) '1/1/1/1/left/0'

# B13′ (미관측 — 2인 파티로 관측 불가) START 접힘 + 숨은 readyDone + F9 → 탐침 재펼침 1 → committed → 소비 0(파일 유지) → 판 완주 → CLEAR 경계 P 1회 → exit 0
Reset-Member -Plan @((P 0 'entryWaiting'))
$script:safeStopFlag = $true
$script:afterAnchor = @((Step 0.3 'readyDone'), (Step 5 'entryLoading'), (Step 9 'inside'))
$script:clearPlan = @((Clear-Spec 'member-reward'))
Run-Member
Check-Equal 'B13′ (미관측 — 2인 파티로 관측 불가) START 접힘 + 숨은 준비됨 + F9: P 탐침 1 → committed(소비 0) → 완주 → 경계 P → 소비 1 → exit 0' (
  J @((Count-Click $anchorPoint), (Get-LeaveResults), ([bool]$script:pCalls[0].Result.Consumed), $script:removes, $script:keys, $script:exitCode)) '1/committed,left/False/1/1/0'

# B14 시간(경계) — 시간 지정 '그 판까지' 설계 8.2 T2. 지정 시각 U = 10:30 (케이스 시작 10:00 기준 1800초). 경계 판단 시각 = 클리어 감시 반환 시각 At
#   (반환 뒤 첫 회전 ⑧ 이 대기 없이 같은 가상 시각에 G 를 봄). G 'time' = 지금 >= U. G 가 빈 경계 인계(지금 < U)는 이어 감 인계라 exit 11 입니다
$untilText = '2026-10-01 10:30'
$untilElapsed = 1800
$leftTimeHandoff = '^\[완료\] 파티원 회차 완료 - 마지막 회차\(지정 시간 10:30\)라 나가기로 필드에 나와 마칩니다$'
# B14(−1) 경계 신호 보상 위 준비 전 패널이 U − 1초 → G '' → 경계 준비 1 → 1초 → exit 11 '준비 완료를 누르고' (P 0).
#         종료는 U 뒤(1초 대기)지만 판단은 ⑧ 의 U − 1초입니다 - GUI 는 11 이라 지정 시각을 보지 않고 이어받습니다 (K-T1 이 체인으로 확인)
Reset-Member -Plan @((P 0 'inside'))
Set-MemberTimeTarget $untilText
$script:clearPlan = @(@{ Return = 'ready'; Steps = @((Step 0 'readyAvail')); At = $untilElapsed - 1 })
Run-Member
$b14ReadyAt = $(if ($script:clickTimes.Count) { $script:clickTimes[$script:clickTimes.Count - 1] } else { -1 })
Check-Equal "B14(−1) U−1초 경계 보상 위 준비 전 패널 → G '' → 경계 준비 1 → 1초 → exit 11(이어 감 인계) '준비 완료를 누르고', P 0" (
  J @($script:pCalls.Count, (Count-Click $readyPoint), $script:exitCode, (Test-LastDone $readyHandoff), [Math]::Round($script:el - $b14ReadyAt, 1))) '0/1/11/1/1'
# B14(0)·(+1) 경계 신호 보상이 U · U + 1초 → G 'time'(같은 시각 포함) → P(G) → 나가기 1 → 로딩 → left → exit 0 '마지막 회차(지정 시간 10:30)라', 'left' 로딩 표본 n ≥ 1
foreach ($delta in @(0, 1)) {
  Reset-Member -Plan @((P 0 'inside'))
  Set-MemberTimeTarget $untilText
  $script:clearPlan = @(@{ Return = 'member-reward'; Steps = @((Step 0 'memberReward')); At = $untilElapsed + $delta })
  Run-Member
  $b14Label = $(if ($delta -eq 0) { 'B14(0) 경계 보상이 U(같은 시각)' } else { 'B14(+1) 경계 보상이 U+1초' })
  Check-Equal "$b14Label → G 'time' → P(G) → 나가기 1 → left → exit 0 '마지막 회차(지정 시간 10:30)라', left 로딩 n ≥ 1" (
    J @($script:pCalls[0].Reason, (Count-Click $leavePoint), (Get-LeaveResults), $script:exitCode, (Test-LastDone $leftTimeHandoff), [int]((Get-LeftDepartSamples) -ge 1))) 'time/1/left/0/1/1'
}
# B14′ 경계 신호 보상이 U − 1초 → G '' → 보상 인계(누르지 않는 위임 인계 - 설계 4.5) exit 11, 클릭 0
Reset-Member -Plan @((P 0 'inside'))
Set-MemberTimeTarget $untilText
$script:clearPlan = @(@{ Return = 'member-reward'; Steps = @((Step 0 'memberReward')); At = $untilElapsed - 1 })
Run-Member
Check-Equal "B14′ U−1초 경계 보상 → G '' → 보상 인계 exit 11 '보상 화면에서 다음 워커가', 클릭 0, P 0" (
  J @($script:exitCode, $script:clicks.Count, $script:pCalls.Count, (Test-LastDone '보상 화면에서 다음 워커가 파티장의 입장을 이어받습니다$'))) '11/0/0/1'
# B14″ 경계 신호 재매칭(커밋)이 U − 1초 → G '' → 커밋 화면 인계 exit 11 / U + 1초 → G 'time' 이지만 다음 판이 이미 커밋 → 이월 1 → 그 판 완주
#      (입장 키 합 2 = 첫 판 1 + 이월 판 1) → 경계 보상 → P(G) → left → exit 0 (두 판에 1계상)
$carrySteps = @((Step 0 'matching'), (Step 10 'entryLoading'), (Step 14 'inside'))   # 재매칭 → 입장 로딩 → 던전 안 (토글 ON 자동 준비 - 관측 4)
foreach ($delta in @(-1, 1)) {
  Reset-Member -Plan @((P 0 'inside'))
  Set-MemberTimeTarget $untilText
  $script:clearPlan = @(@{ Return = 'clear'; Steps = $carrySteps; At = $untilElapsed + $delta }, (Clear-Spec 'member-reward'))
  Run-Member
  if ($delta -lt 0) {
    Check-Equal "B14″ U−1초 경계 재매칭 → G '' → exit 11 '재매칭 중인 다음 판', 이월 0, P 0, 키 1" (
      J @($script:exitCode, (Count-Log '\(이월\)$'), $script:pCalls.Count, $script:keys, (Test-LastDone '재매칭 중인 다음 판을 다음 워커가 이어받습니다$'))) '11/0/0/1/1'
  } else {
    Check-Equal "B14″ U+1초 경계 재매칭 → 이월 1 → 다음 판 완주(키 합 2·-MemberMode 2) → 경계 보상 P(G 'time') 1 → left → exit 0 '마지막 회차(지정 시간 10:30)라'" (
      J @((Count-Log '\(이월\)$'), $script:keys, $script:memberModeCalls, $script:pCalls.Count, $script:pCalls[0].Reason, (Get-LeaveResults), $script:exitCode, (Test-LastDone $leftTimeHandoff))) '1/2/2/1/time/left/0/1'
  }
}
# B14‴ (이월 반복 - 경합 P2-1. 설계가 받아들인 '판 수 상한 없음'(1.6 예외)을 진리표로 기록) 경계 재매칭이 U+1초 → 이월 → 이월 판의 경계도 재매칭(G 'time') →
#      또 이월 → 세 번째 경계 보상 → P(G) 1 → left → exit 0 1회 (세 판에 1계상). 입장 키 합 3 = 첫 판 1 + 이월 판 2 ('이월에 횟수 상한' 변이면 이월 로그 1)
Reset-Member -Plan @((P 0 'inside'))
Set-MemberTimeTarget $untilText
$script:clearPlan = @(@{ Return = 'clear'; Steps = $carrySteps; At = $untilElapsed + 1 }, (Clear-Spec 'clear' $carrySteps), (Clear-Spec 'member-reward'))
Run-Member
Check-Equal "B14‴ 경계 재매칭 U+1초 → 이월 → 이월 판 경계도 재매칭 → 이월 → 세 번째 경계 보상 P(G) 1 → left → exit 0 (이월 로그 2·키 합 3·-MemberMode 3 - 세 판에 exit 0 1회)" (
  J @((Count-Log '\(이월\)$'), $script:keys, $script:memberModeCalls, $script:pCalls.Count, (Get-LeaveResults), $script:exitCode, (Test-LastDone $leftTimeHandoff))) '2/3/3/1/left/0/1'

# B15 LAST_RUN + field 지속(CLEAR) → P → 필드 모양 W 이상 → 'stayed'(필드 모양, 클릭 0) → 진단 + exit 4 (필드 미확정, 회차 미계상), exit 0 0 (09-30 리뷰1 P1-1)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'clear' @((Step 0 'field'))))
Run-Member
Check-Equal "B15 마지막 회차 + 경계 뒤 필드 지속 → P(G) stayed(field·전송 0), 클릭 0, exit 4 '필드로 보이는 화면이라 … (필드 미확정, 회차 미계상)'" (
  J @((Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:clicks.Count, $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 마지막 회차\(횟수 지정\)지만 필드로 보이는 화면이라 누르지 않고 마칩니다 \(필드 미확정, 회차 미계상\)$'), $script:diag.Count)) 'stayed/field/0/4/1/1'

# B16 LAST_RUN + S 잔존 → 터치 정확히 1 → M 만료 → 계상 대기+G → P(G) → stayed → 진단 + exit 4 '(회차 미계상)' (09-30 결정 D2 - 터치 수 단언)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:afterTouch = ''
Run-Member
Check-Equal "B16 마지막 회차 + S 잔존 → 터치 정확히 1, M 만료 P(G 'last-run') stayed(prompt) → exit 4 '(회차 미계상)'" (
  J @((Count-Click $touchPoint), $script:pCalls[0].Reason, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode, (Test-LastDone '\(회차 미계상\)$'))) '1/last-run/stayed/prompt/4/1'
Check-True "B16 P 서두 = 클리어 감시 반환 뒤 M(실제 $($script:pCalls[0].At - $script:clearReturnTimes[0]))" ([Math]::Abs(($script:pCalls[0].At - $script:clearReturnTimes[0]) - $mLimit) -le 1.5) (Get-Summary)

# B17 'clear' → ready-other(cap_210545_900 판독문) → 클릭 0((1077,655) 포함) → exit 0 '누르지 않고 인계'
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyOther'))))
Run-Member
Check-Equal "B17 경계 ready-other('주년``완료') → 클릭 0(준비 버튼 포함), exit 0 '누르지 않고 인계'" (J @($script:clicks.Count, $script:exitCode, (Test-LastDone '준비 패널은 다음 워커가 확인해 준비합니다 \(누르지 않고 인계\)$'))) '0/0/1'

# B18 'clear' → field 2연속(G 없음) → 필드 위 readyAvail → field 동안 인계 0·클릭 0 → 경계 준비 1 → exit 0 '준비 완료를 누르고'
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'clear' @((Step 0 'field'), (Step 10 'readyField'))))
Run-Member
$fieldPhaseClicks = @(Get-ClicksAfter 0 | Where-Object { $_ }).Count - @(Get-ClicksAfter ($script:clearReturnTimes[0] + 10)).Count
Check-Equal "B18 경계 뒤 필드 2연속(G 없음) → 인계 0·클릭 0 → 필드 위 준비 전 패널 → 경계 준비 1 → exit 0 '준비 완료를 누르고'" (
  J @($fieldPhaseClicks, (Count-Click $readyPoint), $script:exitCode, (Test-LastDone $readyHandoff), [int]($script:el -ge $script:clearReturnTimes[0] + 10))) '0/1/0/1/1'

# B19 LAST_RUN + readyDone(CLEAR) → 이월 → 파티장 취소(보상) → START 열 P(G) → 나가기 1 → 로딩 → left → exit 0 '마지막 회차(횟수 지정)라 …', 키 합 1, 준비 0
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyDone'), (Step 10 'memberReward'))))
Run-Member
Check-Equal "B19 이월 중 파티장 취소(보상) → START 열 P(G) → 나가기 1 → left → exit 0 (앞 판 계상), 키 합 1, 준비 0" (
  J @((Count-Log '\(이월\)$'), (Count-Click $leavePoint), (Get-LeaveResults), $script:exitCode, (Test-LastDone $leftHandoff), $script:keys, (Count-Click $readyPoint))) '1/1/left/0/1/1/0'

# B20 (미관측 조합) F9 + CLEAR 경계 보상 위 readyAvail → P 접기 전송(소비 1) → 양보 중 사용자가 재펼침·준비(모의: 양보 종료 → 입장 로딩 1~2표본
#     → 입장 과도 field 2표본 → inside) → interrupt 가 무장을 풂 → 로딩은 떠남 아님 → 과도 field 는 W 미달 → P committed(inside) → 래치 → 이월 →
#     INSIDE → 키 합 2 → -MemberMode 2 → 보상 → 다음 경계 P(G — 파일 없음·래치, 소비 로그 0) → 나가기 1 → left → exit 0, 소비 합 1. 'left' 는 첫 P 에서 0
Reset-Member -Plan @((P 0 'inside'))
$script:safeStopFlag = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyAvail'))), (Clear-Spec 'member-reward'))
$script:clickHook = {
  param($Point, $Screen)
  if ($Point -eq $collapsePoint -and $Screen -eq 'readyAvail' -and -not $script:b20Done) {
    $script:b20Done = $true
    $script:activeWindow = @(((Elapsed) + 0.2), ((Elapsed) + 6))
    Set-ScreenAfter 0 @((Step 0.3 'entryWaiting'), (Step 6 'entryLoading'), (Step 7.2 'transientRun'))
    return $true
  }
  return $false
}
$script:b20Done = $false
Run-Member
$firstLeave = Get-FirstLeave
Check-Equal "B20 (미관측 조합) 첫 P: committed(inside)·소비 1 → 'left' 0, 무장 해제 로그 1('조작·캡처 실패')" (
  J @($firstLeave.Result, $firstLeave.Screen, [bool]$firstLeave.Consumed, (Count-Log '나가기 뒤 화면 전이가 끊겼습니다\(조작·캡처 실패\)'))) 'committed/inside/True/1'
Check-Equal 'B20 래치 → 이월 → INSIDE(키 합 2, -MemberMode 2) → 다음 경계 P(래치 - 파일 없음, 소비 로그 0) → left → exit 0, Remove-Item 합 1' (
  J @((Count-Log '\(이월\)$'), $script:keys, $script:memberModeCalls, (Get-LeaveResults), $script:removes, (Count-Log '안전 중지 예약 확인 - 예약을 소비합니다'), $script:exitCode,
    (Test-LastDone '마지막 회차\(안전 중지 예약\)라 나가기로 필드에 나와 마칩니다$'), @(Get-LeaveLog).Count)) '1/2/2/committed,left/1/1/0/1/1'

# ── §2-C. 시계 (M = 클리어 대기 설정, 준비 시계 300초 - 설계 2.6) ─────────────────
function Get-LogTimes { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern } | ForEach-Object { [double](($_.Trim() -split '\s+')[0]) }) }

# C1 첫 ready → M 정지 + 준비 시계 → 300초에 준비 시계로 정지. 준비 시계는 전송이 아니라 에피소드 첫 관측(ready-*)부터입니다 - 첫 20초는 버튼 판독이
#    어긋난 ready-other(cap_210545_900)라 전송이 20초 늦습니다 (양보·캡처 실패로 늦추면 두 시계가 그만큼 연장돼 구별이 안 됨)
Reset-Member -Plan @((P 0 'readyOther'), (P 20 'readyAvail'))
$script:keepPlan = $true
Run-Member
Check-Equal "C1 첫 준비 패널 관측부터 준비 시계: 첫 전송이 약 30초 늦어도 P('ready-timeout') 서두는 $memberReadyLimitSeconds 초 (M 은 정지 - 'member-timeout' 아님)" (
  J @($script:pCalls[0].Reason, [int](($script:pCalls[0].At -ge $memberReadyLimitSeconds) -and ($script:pCalls[0].At -le $memberReadyLimitSeconds + 1.5)), (Count-Click $readyPoint), [int]($script:clickTimes[0] -ge 20))) 'ready-timeout/1/1/1'

# C2 ready(0~10) → entry(10~110, 앵커 커서 3회) → ready(110) → 보상(120) → M 은 620초에 만료 (에피소드 첫 관측의 M 초기화 뒤 재펼침에서 M 을 다시 초기화하지 않음)
Reset-Member -Plan @((P 0 'readyAvail'), (P 10 'entryWaiting'), (P 110 'readyAvail'), (P 120 'memberReward'))
$script:keepPlan = $true
$script:readyIgnored = $true
$script:sendByPoint[$anchorPoint] = @('cursor-not-ready', 'cursor-not-ready', 'cursor-not-ready')
Run-Member
$c2Entry = Get-FirstSampleAt 'entryWaiting'; $c2Ready = Get-FirstSampleAt 'readyAvail' $c2Entry; $c2Reward = Get-FirstSampleAt 'memberReward'
$c2Expected = $c2Reward + ($mLimit - ($c2Ready - $c2Entry))   # 접힘 표본 구간(약 100초)만큼만 M 이 흐름 → 약 620초
Check-Equal "C2 준비 에피소드 중 접힘 약 100초 → M 은 그만큼만 흐름(재펼침 커서 3회 뒤 관측) → 보상에서 재개 → P('member-timeout') 서두 = 기대 $([Math]::Round($c2Expected, 1)) 초(약 620) (실제 $($script:pCalls[0].At))" (
  J @($script:pCalls[0].Reason, [int](($script:pCalls[0].At -ge $c2Expected - 0.05) -and ($script:pCalls[0].At -le $c2Expected + 0.8)), [int]([Math]::Abs($c2Expected - 620) -le 3), $script:skippedCursor,
    (Count-Log '다시 펼침을 커서 미확인으로 3회 보내지 못해'))) 'member-timeout/1/1/3/1'

# C3 준비 커서 3회 소진, $timeoutClear 100 주입 → 소진 뒤 M 재개 → 300초 전에 M 만료가 aborted 로그 2회, 300초 준비 시계 → P(접기 → 나가기 → 로딩) → left → exit 4 (리뷰 C4)
Reset-Member -Plan @((P 0 'readyAvail'))
$script:timeoutClear = 100
$script:sendByPoint[$readyPoint] = @('cursor-not-ready', 'cursor-not-ready', 'cursor-not-ready')
Run-Member
Check-Equal "C3 준비 커서 소진 뒤 M(100) 재개 → aborted 2회(각각 '대기 한도 도달 순간 파티장 요청' 로그 뒤 M Set) → 준비 시계 P 가 접기·나가기 → left → exit 4" (
  J @((Count-Log '관측하며 대기 한도를 다시 셉니다'), (Count-Log '대기 한도 도달 순간 파티장 요청이 보여 나가지 않고 이어갑니다'), (Get-LeaveResults), $script:pCalls[2].Reason, (Count-Click $collapsePoint), $script:exitCode,
    (Test-LastDone '준비 패널 뒤 \d+초 안에 입장이 없어 나가기로 필드에 나와 파티원 대기를 마칩니다$'))) '1/2/aborted,aborted,left/ready-timeout/2/4/1'
$script:timeoutClear = $capturedTimeoutClear

# C5 matching → M 600 → exit 4
Reset-Member -Plan @((P 0 'matching'))
Run-Member
Check-Equal "C5 재매칭 지속 → M($mLimit) → P committed → exit 4" (J @($script:pCalls[0].Reason, [int]([Math]::Abs($script:pCalls[0].At - $mLimit) -le 1.5), $script:exitCode)) 'member-timeout/1/4'

# C6 INSIDE → M 정지 → 반환 뒤 M 전체 (클리어 감시가 M 보다 오래 걸려도 만료 없음, 반환 뒤 S 잔존이면 반환 시각 + M 에 P)
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'clear' $null 900))
$script:afterTouch = ''
Run-Member
Check-Equal "C6 INSIDE 동안 M 정지(클리어 감시 900초) → 반환 뒤 M 전체 → P 서두 = 반환 + $mLimit 초" (
  J @($script:clearWaits, [int]([Math]::Abs(($script:pCalls[0].At - $script:clearReturnTimes[0]) - $mLimit) -le 1.5), $script:pCalls[0].Reason)) '1/1/member-timeout'

# C7 M5 뒤 → 준비 시계 폐기, 재요청 → 새 에피소드 → 준비 +1 (옛 시계를 쓰면 300초, 새 시계면 재요청 + 300초에 P)
Reset-Member -Plan @((P 0 'readyAvail'), (P 20 'memberReward'), (P 40 'readyAvail'))
$script:keepPlan = $true
Run-Member
Check-Equal "C7 파티장 취소(M5) → 준비 시계 폐기 → 재요청 새 에피소드 → 준비 2, M5 로그 1, 에피소드 로그 2, 준비 시계 P 는 재요청 + $memberReadyLimitSeconds 초" (
  J @((Count-Click $readyPoint), (Count-Log '준비 패널이 사라졌습니다\(입장 시작 또는 파티장 취소\)'), (Count-Log '준비 패널 감지 - '), $script:pCalls[0].Reason,
    [int]([Math]::Abs($script:pCalls[0].At - (40 + $memberReadyLimitSeconds)) -le 1.5))) '2/1/2/ready-timeout/1'

# C9 동결·양보 → 캡처 실패 30초 → +30, 양보 20초 → +20, 같은 회전 실패→복구 → +차분 (M 만료 = 600 + 누적 실패 + 누적 양보)
Reset-Member -Plan @((P 0 'memberReward'))
$script:capWindow = @(100, 130)
$script:activeWindow = @(200, 220)
$script:c9Done = $false
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge 300 -and -not $script:c9Done) { $script:c9Done = $true; return 5 } return -1 }
Run-Member
$p0 = $script:pCalls[0]
$expectedAt = $mLimit + ($p0.FailMs + $p0.YieldMs) / 1000.0
Check-True "C9 M 만료 = $mLimit + 누적 실패 $([Math]::Round($p0.FailMs / 1000, 1)) + 양보 $([Math]::Round($p0.YieldMs / 1000, 1)) = $([Math]::Round($expectedAt, 1)) 초 (실제 $($p0.At)) - 실패 약 30+5 · 양보 약 20" (
  ($p0.At -ge $expectedAt) -and ($p0.At -le $expectedAt + 1.5) -and ([Math]::Abs($p0.FailMs / 1000 - 35) -le 3) -and ([Math]::Abs($p0.YieldMs / 1000 - 20) -le 1)) (Get-Summary)

# C10 에피소드 중 entry(M 진행) → 양보 700초 → ready(에피소드 중) → member-reward → M 은 원래 남은 값으로 만료(즉시 P 없음) (리뷰 A1)
Reset-Member -Plan @((P 0 'readyAvail'), (P 10 'entryWaiting'), (P 700 'readyAvail'), (P 760 'memberReward'))
$script:keepPlan = $true
$script:readyIgnored = $true
$script:afterAnchor = $null
$script:activeWindow = @(50, 750)
Run-Member
# M: 0 에서 초기화(에피소드) → 10~50 접힘 동안 40초 흐름(남은 560) → 50~750 양보(정지 아님 - 조정으로 연장) → 750 준비 패널(에피소드 중)에서 Suspend 가 먼저 조정해
#    남은 560 보존 → 760 보상에서 재개 → 760 + 560 = 1320 (조정 없이 남은 값을 잡으면 610 − 750 < 0 → 0 → 760 에서 즉시 P)
$c10Entry = Get-FirstSampleAt 'entryWaiting'; $c10Ready = Get-FirstSampleAt 'readyAvail' 700; $c10Reward = Get-FirstSampleAt 'memberReward'
$c10Expected = $c10Reward + (($c10Entry + $mLimit + $script:pCalls[0].YieldMs / 1000.0) - $c10Ready)   # 남은 값 = (접힘에서 재개한 마감 + 양보) − 준비 패널 재정지 시각
Check-Equal "C10 양보 700초를 낀 에피소드 → 보상 재개 뒤 M 은 남은 값(약 560초)으로 만료: P 서두 = 기대 $([Math]::Round($c10Expected, 1))(약 1320) 초 (실제 $($script:pCalls[0].At)), 760초 직후 P 없음" (
  J @($script:pCalls[0].Reason, [int](($script:pCalls[0].At -ge $c10Expected - 0.05) -and ($script:pCalls[0].At -le $c10Expected + 0.8)), [int]([Math]::Abs($c10Expected - 1320) -le 4), [int]($script:pCalls[0].At -gt 800))) 'member-timeout/1/1/1'

# C11 readyDone 280초 → 한 회전 안 취소·재요청(readyAvail) → 새 에피소드 로그, 준비 +1, 300초 시점 P 없음 (리뷰 A7 - ㉶)
Reset-Member -Plan @((P 0 'readyDone'), (P 280 'readyAvail'))
$script:keepPlan = $true
Run-Member
Check-Equal "C11 준비됨 280초 → 준비 전으로 바뀜 → 새 요청 로그 1, 준비 1, 첫 P 는 280 + $memberReadyLimitSeconds 초 (300초 시점 P 없음)" (
  J @((Count-Log '준비 완료 상태였던 패널이 다시 준비 전으로 보입니다 - 새 요청으로 보고'), (Count-Click $readyPoint), [int]($script:pCalls[0].At -gt 300), [int]([Math]::Abs($script:pCalls[0].At - (280 + $memberReadyLimitSeconds)) -le 1.5))) '1/1/1/1'

# C12 'clear' → 터치 1 → S 잔존(G 없음) → M 만료로 P 가 불린 직후 재매칭 등장 → P('member-timeout') 첫 회전 committed(matching) → M Set → continue →
#     경계 인계 exit 0 '재매칭 중인 다음 판', P 서두 로그 1, P 호출 수 정확히 1 (09-30 정정, 09-30 리뷰1)
Reset-Member -Plan @((P 0 'inside'))
$script:afterTouch = ''
Add-LogHook '다음 입장이 \d+초\(클리어 대기 설정\) 안에 없습니다 - 나가기로 필드에 나온 뒤 마칩니다' { Set-ScreenAfter 0 @((Step 0 'matching')) }
Run-Member
Check-Equal "C12 CLEAR S 잔존 → M 만료 P 직후 재매칭 → committed(matching) → 경계 인계 exit 0 '재매칭 중인 다음 판', 터치 1, P 서두 1, P 호출 1" (
  J @((Count-Click $touchPoint), (Get-LeaveResults), (Count-Log '안에 없습니다 - 나가기로 필드에 나온 뒤 마칩니다'), $script:pCalls.Count, $script:exitCode, (Test-LastDone '재매칭 중인 다음 판을 다음 워커가 이어받습니다$'))) '1/committed/1/1/0/1'

# C13 'clear' → S 잔존 → M 만료 회전에 접힌 패널이 처음 보임 → ⑨ 건너뜀 → 경계 재펼침 1 → readyAvail → 준비 1 → exit 0 '준비 완료를 누르고', P 0
Reset-Member -Plan @((P 0 'inside'))
$script:afterTouch = ''
$script:keepPlan = $true
$script:clearPlan = @(@{ Return = 'clear'; Steps = @((Step 0 'prompt')); Advance = 60; Hook = { Add-PlanSteps @((Step $mLimit 'entryWaiting')) } })
Run-Member
Check-Equal "C13 M 만료 회전에 처음 보인 접힘 → ⑨ 건너뜀(경계 처리 먼저) → 재펼침 1 → 준비 1 → exit 0 '준비 완료를 누르고', P 0" (
  J @($script:pCalls.Count, (Count-Click $anchorPoint), (Count-Click $readyPoint), $script:exitCode, (Test-LastDone $readyHandoff))) '0/1/1/0/1'
Check-True "C13 접힘이 보인 첫 회전 = M 만료 이후 (클리어 반환 + $mLimit 초 ≤ 앵커 시각 - 실제 $($script:clickTimes[1] - $script:clearReturnTimes[0]))" (($script:clickTimes[1] - $script:clearReturnTimes[0]) -ge $mLimit) (Get-Summary)

# C14 'clear' → 접힘(바깥 판독 entry-waiting 영구) + 클릭 직전 새 단어 판독의 앵커 null 영구(§1(b) 합성 행), $timeoutClear 1 주입 →
#     M 만료 상태의 ⑨ 건너뜀 회전 3 → 판독 불일치 로그 3(1·2회째는 클릭 0 → 회전 끝 700ms) → 3번째 불일치 회전에서 인계 exit 0 '…위치를 확인하지 못해(클릭 직전 판독 3회)…',
#     관측 전환 로그 0, 앵커 클릭 0, P 0, 가상 시간 약 1.4~3초 (09-30 리뷰1 P1-2 - 옛 설계는 판독 호출 상한 VTIMEOUT)
Reset-Member -Plan @((P 0 'inside'))
$script:timeoutClear = 1
$script:clearPlan = @((Clear-Spec 'entry-waiting' $null 0))
$script:wordsOverride = $wSplit
Run-Member
Check-Equal "C14 경계 앵커 null 영구 → 불일치 3 → 3번째 회전에서 인계 exit 0 '위치를 확인하지 못해(클릭 직전 판독 3회)', 관측 0, 앵커 0, P 0, VTIMEOUT 없음" (
  J @((Count-Log '재펼침 건너뜀 - 클릭 직전 판독이 접힌 패널과 다릅니다'), $script:exitCode, (Test-LastDone "접힌 준비 패널의 '입장 대기 중' 위치를 확인하지 못해\(클릭 직전 판독 3회\) 다음 워커가 이어받습니다$"),
    (Count-Log '더 누르지 않고 관측합니다'), (Count-Click $anchorPoint), $script:pCalls.Count, $script:threw)) '3/0/1/0/0/0/'
Check-True "C14 가상 시간 약 1.4~3초 (실제 $($script:el)) - 불일치 1·2회째는 회전 끝 700ms 대기" (($script:el -ge 1.4) -and ($script:el -le 3)) (Get-Summary)
$script:timeoutClear = $capturedTimeoutClear

# ── §2-K. 키·체인·이월 ────────────────────────────────────────────────────────
function Invoke-WorkerChain {
  # 워커 체인: 각 워커는 새 D(지역 상태 새로), 가상 시계·화면 계획표·캡처 상태는 이어짐. 워커가 끝날 때마다 GUI 모형이 다음 워커를 띄울지 정합니다
  # (시간 지정 '그 판까지' 설계 8.1 - 회귀 R-10. 옛 하니스는 'exit 0 이면 늘 이어 감' 이라 GUI 판단을 흉내 내지 않았음).
  # 바깥 분기는 GUI 타이머와 같습니다: 0·11 → 계상 뒤 Invoke-NextCycleDecision / 10 → 미계상 Invoke-NextCycleDecision / 그 밖(4·1·2·3·반환·예외) →
  # 시간 판정과 무관하게 정지 (K-T4 가 지킴). 코드 10 앞부분(잔여 로그 수집·거점 퇴장 판별·준비 실행 연속 수)은 모형에 없습니다 - 파티원 D 는
  # 코드 10 을 내지 않습니다 (§3 exit 모양). 'next' 일 때만 기동 지연 뒤 다음 워커
  param([int]$Workers, [double]$StartupDelay = 2)
  $results = @()
  for ($w = 1; $w -le $Workers; $w++) {
    $keysBefore = $script:keys; $modeBefore = $script:memberModeCalls; $clicksBefore = $script:clicks.Count; $logsBefore = $script:logs.Count; $startAt = Elapsed
    $pBefore = $script:pCalls.Count; $guiLogsBefore = @($script:guiLogs).Count
    Run-Member
    $endAt = Elapsed
    $workerClicks = @(for ($i = $clicksBefore; $i -lt $script:clicks.Count; $i++) { $script:clicks[$i] })
    $workerLogs = @(for ($i = $logsBefore; $i -lt $script:logs.Count; $i++) { $script:logs[$i] })
    # GUI 모형 - 타이머 바깥 분기 (판단은 GUI 소스에서 추출한 Invoke-NextCycleDecision 이 Stop-AllRun·Start-NextCycle 모의로 기록)
    $workerExit = $script:exitCode
    $script:guiDecision = ''
    if (($workerExit -eq 0) -or ($workerExit -eq 11)) {
      $script:completedCycles++
      Invoke-NextCycleDecision -ExitCode $workerExit
    } elseif ($workerExit -eq 10) {
      Invoke-NextCycleDecision -ExitCode 10
    } else {
      $script:guiDecision = "stop:code $workerExit"
    }
    $workerGuiLogs = @(@($script:guiLogs) | Select-Object -Skip $guiLogsBefore)
    $results += , @{ Exit = $script:exitCode; Threw = $script:threw; Keys = $script:keys - $keysBefore; Mode = $script:memberModeCalls - $modeBefore; Clicks = $workerClicks; Logs = $workerLogs; StartAt = $startAt
      EndAt = $endAt; P = $script:pCalls.Count - $pBefore; Decision = $script:guiDecision; GuiLogs = $workerGuiLogs }
    if ($script:guiDecision -ne 'next') { break }
    Tick $StartupDelay
  }
  return , $results
}
function Get-EntryMeasure {
  # 입장 계측 줄 '[파티원] 입장 계측 - 던전 안 2연속 앞 로딩(알 수 없음) u표본, 필드 모양 n표본[, 첫 필드 모양 표본부터 던전 안 s초], 관측 끊김 k회' 를 풉니다
  param([string[]]$Logs)
  $lines = @($Logs | Where-Object { $_ -match '입장 계측 - 던전 안 2연속 앞 로딩\(알 수 없음\) (\d+)표본, 필드 모양 (\d+)표본(?:, 첫 필드 모양 표본부터 던전 안 ([\d.]+)초)?, 관측 끊김 (\d+)회' })
  if ($lines.Count -ne 1) { return @{ Count = $lines.Count; U = -1; N = -1; S = -1; K = -1 } }
  [void]($lines[0] -match '입장 계측 - 던전 안 2연속 앞 로딩\(알 수 없음\) (\d+)표본, 필드 모양 (\d+)표본(?:, 첫 필드 모양 표본부터 던전 안 ([\d.]+)초)?, 관측 끊김 (\d+)회')
  return @{ Count = 1; U = [int]$Matches[1]; N = [int]$Matches[2]; S = $(if ($Matches[3]) { [double]$Matches[3] } else { -1 }); K = [int]$Matches[4] }
}

# K1 정상 흐름 → 키 1/판 (클리어 뒤 보상 인계 - B1 과 같은 흐름)
Reset-Member -Plan @((P 0 'inside'))
Run-Member
Check-Equal 'K1 정상 흐름: 판당 키 1 (INSIDE 전이 1곳)' (J @($script:keys, $script:exitCode)) '1/0'
# K2 B11 → 키 2 (이월 전이가 키 플래그를 리셋 - ㉳)
Check-Equal 'K2 (B11 흐름) 이월한 판도 입장 키 → 키 합 2' $b11Keys 2

# K3 워커 체인 3판, 2판째 클리어 감시가 'member-reward' 반환 → exit 0 3회, 판당 키 1 (클리어 감시 자체의 관측 2 회귀는 §1(g)(h)·§4)
Reset-Member -Plan @((P 0 'inside'))
$script:afterTouch = @((Step 1 'memberReward'), (Step 11 'readyAvail'))
$script:afterReady = @((Step 0.5 'readyDone'), (Step 5 'entryLoading'), (Step 9 'inside'))
$script:clearPlan = @((Clear-Spec 'clear'), (Clear-Spec 'member-reward' @((Step 0 'memberReward'), (Step 10 'readyAvail'))), (Clear-Spec 'clear'))
$chain = Invoke-WorkerChain -Workers 3
Check-Equal 'K3 워커 체인 3판(2판째 파티원 보상 반환): exit 0 ×3, 판당 키 1, 판당 -MemberMode 1' (
  J @((($chain | ForEach-Object { $_.Exit }) -join ','), (($chain | ForEach-Object { $_.Keys }) -join ','), (($chain | ForEach-Object { $_.Mode }) -join ','))) '0,0,0/1,1,1/1,1,1'

# K4 워커 체인 2판(3인 이상 흐름), 1판 경계 신호가 보상 위 readyAvail → 워커 1 준비 1 → exit 0 → 워커 2 readyDone 시작·클릭 0 → 입장 → 키 1 (판당 준비 1)
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'ready'), (Clear-Spec 'member-reward'))
$script:afterReady = @((Step 0.5 'readyDone'), (Step 10 'entryLoading'), (Step 14 'inside'))
$chain = Invoke-WorkerChain -Workers 2
Check-Equal "K4 (3인 이상) 워커 1 경계 준비 1 → exit 0 → 워커 2 는 준비됨에서 시작·준비 0 → 입장 → 키 1" (
  J @($chain[0].Exit, @($chain[0].Clicks | Where-Object { $_ -eq $readyPoint }).Count, [int](@($chain[1].Logs | Where-Object { $_ -match '시작 화면: ' })[0] -match '준비 완료 상태'),
    @($chain[1].Clicks | Where-Object { $_ -eq $readyPoint }).Count, $chain[1].Keys, $chain[1].Exit)) '0/1/1/0/1/0'

# K4′ K4 의 2인 변형(준비 전송 1.8초 뒤 로딩, 7초 뒤 던전 안) - 워커 2 는 로딩 → inside 2연속 → INSIDE → 키 1, 준비 0. 입장 계측 줄 정확히 1 (2.3 ⑦):
#   기본 변형 u ≥ 1 · n 0 · 끊김 0 (계측된 입장, 과도 없음) / 과도 변형 u ≥ 1 · n 2 · s = 2 × 0.7 = 1.4(± 0.1) · 끊김 0 / 기동 지연 > 로딩 → u 0 · n 0 (계측된 입장 아님)
$k4Variants = @(
  @{ Name = '기본'; Steps = @((Step 1.8 'entryLoading'), (Step 8.8 'inside')); Delay = 2 },
  @{ Name = '입장 과도'; Steps = @((Step 1.8 'entryLoading'), (Step 8.8 'transientRun')); Delay = 2 },
  @{ Name = '기동 지연이 로딩보다 김'; Steps = @((Step 1.8 'entryLoading'), (Step 8.8 'inside')); Delay = 9 })
foreach ($variant in $k4Variants) {
  Reset-Member -Plan @((P 0 'inside'))
  $script:clearPlan = @((Clear-Spec 'ready'), (Clear-Spec 'member-reward'))
  $script:afterReady = $variant.Steps
  $chain = Invoke-WorkerChain -Workers 2 -StartupDelay $variant.Delay
  $measure = Get-EntryMeasure -Logs $chain[1].Logs
  $w2Field = @($chain[1].Logs | Where-Object { $_ -match '시작 화면: ' })
  Check-Equal "K4′ ($($variant.Name)) 워커 1 준비 1 → exit 0 → 워커 2 준비 0·클릭 0 → INSIDE → 키 1" (
    J @($chain[0].Exit, @($chain[0].Clicks | Where-Object { $_ -eq $readyPoint }).Count, @($chain[1].Clicks | Where-Object { $_ -eq $readyPoint }).Count, $chain[1].Keys, $chain[1].Exit)) '0/1/0/1/0'
  if ($variant.Name -eq '기본') {
    Check-Equal 'K4′ (기본) 워커 2 입장 계측 줄 1: u ≥ 1 · n 0 · 끊김 0 (계측된 입장 - 과도 없음의 증거)' (J @($measure.Count, [int]($measure.U -ge 1), $measure.N, $measure.K)) '1/1/0/0'
  } elseif ($variant.Name -eq '입장 과도') {
    Check-Equal 'K4′ (입장 과도) 워커 2 입장 계측 줄 1: u ≥ 1 · n 2 · s = 2 × 회전 0.7 = 1.4(± 0.1) · 끊김 0, 과도 동안 클릭 0' (
      J @($measure.Count, [int]($measure.U -ge 1), $measure.N, [int]([Math]::Abs($measure.S - 1.4) -le 0.1), $measure.K, $chain[1].Clicks.Count)) '1/1/2/1/0/0'
  } else {
    Check-Equal 'K4′ (기동 지연 > 로딩) 워커 2 입장 계측 줄 1: u 0 · n 0 (워커가 로딩 뒤에 관측 시작 - 계측된 입장 아님)' (J @($measure.Count, $measure.U, $measure.N)) '1/0/0'
  }
}

# K5 LAST_RUN, 경계 신호 ready-other → P(G) 클릭 0 대기 중 (양보 중) 준비·입장(모의: 양보 종료 → 입장 로딩 → 입장 과도 field 2표본 → inside) → P committed(inside)
#    → 이월 전이(키 플래그 리셋) → INSIDE → 키 1(합 2) → -MemberMode 2 → 보상 → P(G) → 나가기 → 로딩 → left → exit 0 (W 가 없으면 'stayed' 코드 4 - 던전 안에 남음)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyOther'))), (Clear-Spec 'member-reward'))
Add-LogHook '마지막 회차\(횟수 지정\) - 준비하지 않고 나가기로 필드에 나옵니다' {
  $script:activeWindow = @(((Elapsed) + 5), ((Elapsed) + 15))
  Set-ScreenAfter 0 @((Step 0 'readyOther'), (Step 15 'entryLoading'), (Step 16 'transientRun'))
}
Run-Member
Check-Equal "K5 경계 ready-other → P(G) 대기 중 양보·입장 → 과도 field 2 는 W 미달 → committed(inside) → 이월 → 키 합 2·-MemberMode 2 → 다음 경계 P left → exit 0" (
  J @((Get-LeaveResults), (Get-FirstLeave).Screen, (Count-Log '\(이월\)$'), $script:keys, $script:memberModeCalls, $script:exitCode, (Test-LastDone $leftHandoff), @(Get-LeaveLog).Count)) 'committed,left/inside/1/2/2/0/1/1'
Check-Equal 'K5 첫 P 는 클릭 0 (필드 위 준비 패널 - 누르지 않음), stayed-field 판정 0' (J @(@($script:clicks | Where-Object { $_ -ne $leavePoint }).Count, (Count-Log '필드로 보이는 화면입니다 \(나가기로 나온 전환'))) '0/0'

# K6 (미관측 — 2인 파티로 관측 불가) START 접힘 재펼침 무반응 2회(숨은 준비됨) → 입장 → 클리어 → 경계 접힘 → INSIDE 전이의 카운터 리셋으로 경계 재펼침 1 → readyAvail → 준비 1 →
#    exit 0 '준비 완료를 누르고'('다시 펼쳐지지 않아' 인계 0)
Reset-Member -Plan @((P 0 'entryWaiting'), (P 20 'entryLoading'), (P 25 'inside'))
$script:keepPlan = $true
$script:afterAnchorQueue = @($null, $null, @((Step 0.3 'readyAvail')))
$script:afterAnchor = $null
$script:clearPlan = @((Clear-Spec 'entry-waiting'))
Run-Member
Check-Equal "K6 (미관측 — 2인 파티로 관측 불가) START 재펼침 2회 무반응 → 입장 → 경계 접힘: 카운터 리셋으로 경계 재펼침 1 → 준비 1 → exit 0 '준비 완료를 누르고', '다시 펼쳐지지 않아' 인계 0" (
  J @((Count-Click $anchorPoint), (Count-Click $readyPoint), $script:exitCode, (Test-LastDone $readyHandoff), (Count-Log '다시 펼쳐지지 않아 다음 워커가'), $script:keys)) '3/1/0/1/0/1'

# ── 체인 + GUI 모형 - 시간 지정 '그 판까지' (설계 8.2 T2 의 K-T1~K-T4). U = 10:30 (1800초 - B14 와 같은 값) ──
# 판단 주체 하나(조건 4)를 워커 → GUI 이어받기로 봅니다: 워커가 지정 시각 전에 이어 가기로 정하고 낸 11 은 GUI 가 지정 시각을 보지 않고 이어받고,
# 지정 시각 뒤의 '마지막'(left - exit 0)과 START 비참가(exit 4) 뒤에는 GUI 가 멈춥니다
$timeNoticeHead = '[안내] 지정 시간(10:30) 전에 워커가 다음 판으로 이어 가기로 정했습니다'   # GUI 11 안내 (지정 시각 뒤에 11 을 받은 드문 경우 1줄)
$timeStopNotice = '지정 시간(10:30) 이후라 새 판을 시작하지 않습니다.'                          # GUI 전투 정지 안내 (Get-TimeStopNotice 전투 갈래)
$timeStopDecision = 'stop:지정 시간(10:30) 도달'

# K-T1 (조건 4 핵심) 워커 1: 경계 보상 위 준비 전 패널이 U − 0.5초 → G '' → 준비 → 1초 → exit 11 이 U 뒤 → GUI 모형: 11 이라 지정 시각을 보지 않고
#      다음 워커 + 11 안내 1줄 → 워커 2 START 입장 로딩 → 던전 안 → 입장 키 1·준비 0 → 판 → 경계 보상 P(G) → left → exit 0 → GUI 모형 시간 정지(전투 안내).
#      ('11 이면 시간 판단 생략' 이 빠지거나 GUI 가 -ExitCode 를 넘기지 않으면 워커 1 뒤에 멈춥니다 - 준비된 파티원이 워커 없이 끌려 들어가는 사고)
Reset-Member -Plan @((P 0 'inside'))
Set-MemberTimeTarget $untilText
$script:clearPlan = @(@{ Return = 'ready'; Steps = @((Step 0 'readyAvail')); At = $untilElapsed - 0.5 }, (Clear-Spec 'member-reward'))
$script:afterReady = @((Step 0.5 'readyDone'), (Step 1.8 'entryLoading'), (Step 8.8 'inside'))   # 2인 이동 (K4′ 기본 변형과 같은 시각표)
$chain = Invoke-WorkerChain -Workers 3
Check-Equal "K-T1 워커 1 경계 준비(U−0.5초) → exit 11 이 U 뒤 → GUI 모형 'next' + 11 안내 1 → 워커 2 입장 키 1·준비 0 → 경계 P(G) 1 → left → exit 0 → GUI 모형 '$timeStopDecision' + 전투 정지 안내 1 (체인 11,0·계상 2)" (
  J @((($chain | ForEach-Object { $_.Exit }) -join ','), $script:completedCycles, [int]($chain[0].EndAt -gt $untilElapsed), $chain[0].Decision,
    @($chain[0].GuiLogs | Where-Object { $_.StartsWith($timeNoticeHead) }).Count, $chain[1].Keys, @($chain[1].Clicks | Where-Object { $_ -eq $readyPoint }).Count,
    $chain[1].P, $chain[1].Decision, @($chain[1].GuiLogs | Where-Object { $_ -eq $timeStopNotice }).Count, (Test-LastDone $leftTimeHandoff))) "11,0/2/1/next/1/1/0/1/$timeStopDecision/1/1"

# K-T2 워커 1: 경계 보상이 U − 1초 → G '' → 보상 인계 exit 11 → GUI 모형 'next'(지정 시각 전이라 안내 없음) → 워커 2 START 보상(U + 1초) → G 'time' →
#      준비 0 → P(G) → left → exit 4 (새 판에 참가하지 않음 - 회차 미완료) → GUI 모형 'stop:code 4' (시간 판정 없음). 계상 1 (워커 1 의 11 만)
Reset-Member -Plan @((P 0 'inside'))
Set-MemberTimeTarget $untilText
$script:clearPlan = @(@{ Return = 'member-reward'; Steps = @((Step 0 'memberReward')); At = $untilElapsed - 1 })
$chain = Invoke-WorkerChain -Workers 3
Check-Equal "K-T2 워커 1 보상 인계(U−1초) exit 11 → GUI 모형 'next'·안내 0 → 워커 2 START 보상(U+1초) G 'time' → 준비 0 → P(G) left → exit 4 '지정 시간 10:30 도달 - 다음 판에 참가하지 않고 …' → 'stop:code 4' (체인 11,4·계상 1)" (
  J @((($chain | ForEach-Object { $_.Exit }) -join ','), $script:completedCycles, $chain[0].Decision, @($chain[0].GuiLogs).Count, @($chain[1].Clicks | Where-Object { $_ -eq $readyPoint }).Count,
    $chain[1].P, (Get-LeaveResults), $chain[1].Decision, (Test-LastDone '^\[완료\] 파티원: 지정 시간 10:30 도달 - 다음 판에 참가하지 않고 나가기로 필드에 나와 마칩니다$'))) '11,4/1/next/0/0/1/left/stop:code 4/1'

# K-T3 (회귀 R-15) 워커 1: 경계 재매칭이 U − 1초 → exit 11 → 워커 2 START 재매칭(U + 1초 - G 'time' 이지만 커밋 화면이라 P 없이 그 판을 진행) → 입장 → 판 →
#      경계 보상 P(G) 1 → left → exit 0 → GUI 모형 시간 정지. 워커 2 의 P 는 경계 1회뿐 - START 0 ('START 비커밋 목록에 재매칭 추가' 변이면 2)
Reset-Member -Plan @((P 0 'inside'))
Set-MemberTimeTarget $untilText
$script:clearPlan = @(@{ Return = 'clear'; Steps = @((Step 0 'matching'), (Step 12 'entryLoading'), (Step 16 'inside')); At = $untilElapsed - 1 }, (Clear-Spec 'member-reward'))
$chain = Invoke-WorkerChain -Workers 3
$kt3BoundaryAt = $(if ($script:clearReturnTimes.Count -ge 2) { $script:clearReturnTimes[1] } else { -1 })   # 워커 2 의 클리어 감시 반환 = 그 판의 경계
Check-Equal "K-T3 워커 1 재매칭 인계(U−1초) exit 11 → 워커 2 START 재매칭(U+1초)은 P 없이 대기·입장 → 판 → 경계 P(G) 1(START 0) → left → exit 0 → '$timeStopDecision' (체인 11,0)" (
  J @((($chain | ForEach-Object { $_.Exit }) -join ','), $chain[0].Decision, $chain[1].P, [int](($kt3BoundaryAt -gt 0) -and ($script:pCalls[0].At -ge $kt3BoundaryAt)), $chain[1].Keys,
    @($chain[1].Logs | Where-Object { $_ -match '재매칭 패널 감지 - 누를 것이 없어 입장을 기다립니다' }).Count, $chain[1].Decision)) "11,0/next/1/1/1/1/$timeStopDecision"

# K-T4 (회귀 R-10 - GUI 모형 자체의 단언) 워커 1 START 3버튼 보상(역할 오설정) → 즉시 exit 4, 지정 시각은 먼 미래(시간 허용) → 체인 길이 1, 'stop:code 4' -
#      모형의 바깥 분기가 시간 판정과 무관하게 정지시킴 (코드 4 를 다음 회차 판단에 넘기는 모형이면 시간이 허용해 다음 워커를 띄움)
Reset-Member -Plan @((P 0 'reward3'))
Set-MemberTimeTarget '2026-10-02 10:00'
$chain = Invoke-WorkerChain -Workers 3
Check-Equal "K-T4 워커 1 START 3버튼 보상 → exit 4 → GUI 모형 'stop:code 4' (지정 시각이 먼 미래여도 - 체인 길이 1·계상 0·GUI 로그 0)" (
  J @($chain.Count, $chain[0].Exit, $chain[0].Decision, $script:completedCycles, @($script:guiLogs).Count)) '1/4/stop:code 4/0/0'

# ── §2-R. 회귀 (⑥a 4절 이전 + 규칙 4·15 경계) ───────────────────────────────────
# R1 (⑥a 4-14) 필드 → readyAvail → 준비 1 → 던전 안 1표본(깜빡임) → 로딩 → 던전 안 지속 → INSIDE 전이는 지속 구간의 2연속에서만 — 키 1, 키 시각 ≥ 깜빡임 + 4초
Reset-Member -Plan @((P 0 'field'), (P 5 'readyAvail'))
$script:keepPlan = $false
$script:afterReady = @((Step 0.5 'readyDone'), (Step 3 'transientRun'))
$script:transientSeq = @('inside', 'entryLoading', 'entryLoading', 'entryLoading', 'entryLoading', 'entryLoading', 'entryLoading')   # 던전 안 1표본 → 로딩 6표본(약 4.2초) → 지속
$script:clearPlan = @($stopClear)
Run-Member
$flickerAt = [double](($script:transientLog[0] -split '@')[1])
Check-Equal "R1 (⑥a 4-14) 입장 깜빡임(던전 안 1표본) → 로딩 → 지속: 준비 1, 키 1, 키 시각 ≥ 깜빡임 + 4초 (깜빡임 $flickerAt, 키 $($script:keyTimes[0]))" (
  J @((Count-Click $readyPoint), $script:keys, [int]($script:keyTimes[0] -ge $flickerAt + 4), [int]($script:transientLog[0] -like 'inside@*'))) '1/1/1/1'

# R2 (⑥a 4-15) 보상 시작, 첫 회전 하단 판독 캡처 실패(같은 회전 뒤 판독이 복구) → 그 회전 폐기 — 실패 판독 1, 시작 화면 로그 '파티원 보상' 1(알 수 없음 로그 0), 클릭 0, 이후 A2 와 같음
Reset-Member -Plan @((P 0 'memberReward'))
$script:r2Done = $false
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and -not $script:r2Done) { $script:r2Done = $true; return 0 } return -1 }
Run-Member
$startLines = @($script:logs | Where-Object { $_ -match '시작 화면: ' })
Check-Equal "R2 (⑥a 4-15) 첫 하단 판독 실패 → 그 회전 폐기: 실패 판독 1, 시작 화면 '파티원 보상 화면' 1(알 수 없는 화면 0), 이후 A2(나가기 1·left·exit 4)" (
  J @($script:failedReads, $startLines.Count, [int]($startLines[0].EndsWith((Get-Label 'member-reward'))), (Count-Log '시작 화면: 알 수 없는 화면'), (Count-Click $leavePoint), (Get-LeaveResults), $script:exitCode)) '1/1/1/0/1/left/4'
Check-Equal 'R2 첫 유효 표본 전 클릭 0 (실패 회전은 복구 회전 - 클릭 없음)' (@(for ($i = 0; $i -lt $script:clicks.Count; $i++) { if ($script:clickTimes[$i] -lt 1) { 1 } }).Count) 0

# R3 (⑥a 4-16) prompt 시작(터치 1, 먹지 않음) + 599.5~620초 캡처 실패 → 마감 미확정·동결(안전 확인 5회 이상·복구 탐침), M 이 실패 시간만큼 늘어
#    P 서두 로그 618~626초 → 즉시 stayed → 진단 + exit 4('M 초과' 문구), 정지 618~630초, 터치 정확히 1
Reset-Member -Plan @((P 0 'prompt'))
$script:afterTouch = ''
$script:capWindow = @(599.5, 620)
Run-Member
Check-Equal 'R3 (⑥a 4-16) S 잔존 + 마감 직전 캡처 실패 20초: 안전 확인 ≥ 5·탐침 ≥ 5, P 서두 618~626초, 즉시 stayed, exit 4, 정지 618~630초, 터치 정확히 1' (
  J @([int]($script:safeStopCalls -ge 5), [int]($script:probeCalls -ge 5), [int](($script:pCalls[0].At -ge 618) -and ($script:pCalls[0].At -le 626)), (Get-FirstLeave).Result, $script:exitCode,
    [int](($script:el -ge 618) -and ($script:el -le 630)), (Count-Click $touchPoint))) '1/1/1/stayed/4/1/1'

# R4 (⑥a 4-17) prompt 시작 + 598~630초 조작 → 양보 먼저(마감 판정 없음) — 조작 중 정지 없음, 양보만큼 연장, 정지 ≥ 630초, exit 4, 양보 1회 이상
Reset-Member -Plan @((P 0 'prompt'))
$script:afterTouch = ''
$script:activeWindow = @(598, 630)
Run-Member
Check-Equal 'R4 (⑥a 4-17) S 잔존 + 마감 직전 조작 32초: 조작 중 정지·P 없음(P 서두 ≥ 630), 정지 ≥ 630, exit 4, 양보 ≥ 1' (
  J @([int]($script:pCalls[0].At -ge 630), [int]($script:el -ge 630), $script:exitCode, [int]($script:yieldWaits -ge 1))) '1/1/4/1'

# R5 (⑥a 4-18) 필드 → 사용자가 손으로 입장(준비 버튼 없음)
#    (a) 조작 4~20초 중의 던전 안 증거는 표본에 넣지 않음 → 조작 뒤 2연속 → 키 1(키 시각 ≥ 20초)
Reset-Member -Plan @((P 0 'field'), (P 10 'inside'))
$script:keepPlan = $true
$script:activeWindow = @(4, 20)
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal "R5(a) 조작 중 던전 안 증거는 표본 아님 → 조작 뒤 2연속 → 키 1 (키 시각 $($script:keyTimes[0]) ≥ 20)" (J @($script:keys, [int]($script:keyTimes[0] -ge 20), [int]($script:yieldWaits -ge 1))) '1/1/1'
#    (b) 간접 양보: 스윕 모의가 판독 전 커서 대피에서 $script:userYieldTotalMs 를 올리고 거짓을 돌려준 회전 → ⑤ 가 그 회전 앞의 연속 수를 비움 → INSIDE 전이가 한 회전 늦음.
#        주입 회전 = 던전 안 연속이 1 이 된 뒤의 회전(연속 2 가 될 자리). 설계 문구의 '던전 안이 처음 보인 회전' 에 넣으면 운영 D(설계 2.3 의사 코드 그대로)는 ⑤ 리셋 뒤
#        그 회전 표본을 1 로 세어 늦어지지 않고 변이('간접 양보 리셋 제거')도 잡지 못해, 리셋이 효과를 내는 자리에 넣습니다 (보고서 deviations)
foreach ($inject in @($false, $true)) {
  Reset-Member -Plan @((P 0 'field'), (P 10 'inside'))
  $script:keepPlan = $true
  $script:clearPlan = @($stopClear)
  $script:r5Seen = 0
  if ($inject) {
    $script:sweepPlan = { if ((Screen-Now) -eq 'inside') { $script:r5Seen++; if ($script:r5Seen -eq 2) { $script:userYieldTotalMs += 1500; Tick 1.5 } }; return $null }
  }
  Run-Member
  if (-not $inject) { $r5BaseKeyAt = $script:keyTimes[0] }
  else {
    Check-Equal "R5(b) 간접 양보(스윕 안 커서 대피)가 던전 안 연속 1 뒤 회전에 끼면 그 회전 앞 연속 수를 비움 → INSIDE 한 회전 늦음 (기준 키 $r5BaseKeyAt → $($script:keyTimes[0]))" (
      J @($script:keys, [int]([Math]::Abs(($script:keyTimes[0] - $r5BaseKeyAt) - (0.7 + 1.5)) -le 0.05))) '1/1'
  }
}

# R6 (⑥a 4-19 → P) X-FC 배치 + P 시작 55~95초 조작 → 조작 중 정지 없음, P 마감이 양보만큼 늘어 stayed 는 조작이 끝난 뒤(약 100초), 진단 + exit 4 '필드 위 준비 패널 … (회차 미계상)'
function Set-XfcPlan { Reset-Member -Plan @((P 0 'inside')); $script:dgLastRun = $true; $script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyField')))) }
Set-XfcPlan
Add-LogHook '마지막 회차\(횟수 지정\) - 준비하지 않고 나가기로 필드에 나옵니다' { $script:activeWindow = @(((Elapsed) + 55), ((Elapsed) + 95)) }
Run-Member
$pDur = $script:pCalls[0].EndAt - $script:pCalls[0].At
Check-Equal "R6 (⑥a 4-19 → P) P 도중 조작 40초 → P 마감 연장, stayed 는 조작 뒤(P 시작 + 약 100초, 실제 $([Math]::Round($pDur, 1))), exit 4 '필드 위 준비 패널이라 … (회차 미계상)'" (
  J @((Get-FirstLeave).Result, [int](($pDur -ge 95) -and ($pDur -le 102)), $script:exitCode, (Test-LastDone '필드 위 준비 패널이라 준비를 누르지 않고 마칩니다 \(회차 미계상\)$'), [int]($script:yieldWaits -ge 1))) 'stayed/1/4/1/1'

# R7 (⑥a 4-20 → P, P 도중 캡처 실패 90초) X-FC 배치 + P 시작 1~91초 캡처 실패 → P 마감 미확정·동결(안전 확인·복구 탐침), 복구 뒤 약 60초 → stayed 약 150초, 진단 + exit 4
Set-XfcPlan
Add-LogHook '마지막 회차\(횟수 지정\) - 준비하지 않고 나가기로 필드에 나옵니다' { $script:capWindow = @(((Elapsed) + 1), ((Elapsed) + 91)) }
Run-Member
$pDur = $script:pCalls[0].EndAt - $script:pCalls[0].At
Check-Equal "R7 (⑥a 4-20 → P) P 도중 캡처 실패 90초 → 동결(안전 확인 ≥ 1·탐침 ≥ 1) → stayed 약 150초 (실제 $([Math]::Round($pDur, 1))), exit 4" (
  J @((Get-FirstLeave).Result, [int]($script:safeStopCalls -ge 1), [int]($script:probeCalls -ge 1), [int](($pDur -ge 147) -and ($pDur -le 154)), $script:exitCode)) 'stayed/1/1/1/4'

# R8 (⑥a 4-22) prompt 시작 + 100초에 느린 실패 150초(같은 회전 복구) → M 이 150초 늘어 정지 745~760초, exit 4, 안전 확인 0(서두 동결 블록을 안 탐)
Reset-Member -Plan @((P 0 'prompt'))
$script:afterTouch = ''
$script:slowOnce = $false
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge 100 -and -not $script:slowOnce) { $script:slowOnce = $true; return 150 } return -1 }
Run-Member
Check-Equal "R8 (⑥a 4-22) 같은 회전 실패→복구 150초 → M 연장, 정지 745~760초 (실제 $($script:el)), exit 4, 안전 확인 0" (
  J @($script:exitCode, [int](($script:el -ge 745) -and ($script:el -le 760)), $script:safeStopCalls)) '4/1/0'

# R9 (⑥a 4-23 → P) X-FC 배치 + P 10초에 느린 실패 25초 → P 마감 60 + 25 → stayed 약 85초, exit 4
Set-XfcPlan
$script:slowOnce = $false
Add-LogHook '마지막 회차\(횟수 지정\) - 준비하지 않고 나가기로 필드에 나옵니다' { $script:slowFrom = (Elapsed) + 10 }
$script:slowFrom = 99999
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge $script:slowFrom -and -not $script:slowOnce) { $script:slowOnce = $true; return 25 } return -1 }
Run-Member
$pDur = $script:pCalls[0].EndAt - $script:pCalls[0].At
Check-Equal "R9 (⑥a 4-23 → P) P 10초에 같은 회전 실패→복구 25초 → stayed 약 85초 (실제 $([Math]::Round($pDur, 1))), exit 4, 안전 확인 0" (
  J @((Get-FirstLeave).Result, [int](($pDur -ge 84) -and ($pDur -le 87)), $script:exitCode, $script:safeStopCalls)) 'stayed/1/4/0'

# R10 (⑥a 4-24) 필드 시작 + 550초에 느린 실패 150초 → M 750 → P → 필드 모양 W 이상 → 'stayed'(필드 모양) → 진단 + exit 4, 정지 748+W~760+W초, throw 0
Reset-Member -Plan @((P 0 'field'))
$script:slowOnce = $false
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge 550 -and -not $script:slowOnce) { $script:slowOnce = $true; return 150 } return -1 }
Run-Member
Check-Equal "R10 (⑥a 4-24) 필드 + 550초 같은 회전 실패→복구 150초 → M 750 → stayed(필드 모양) → exit 4, 정지 $(748 + $wLimit)~$(760 + $wLimit)초 (실제 $($script:el)), throw 0" (
  J @((Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode, [int](($script:el -ge 748 + $wLimit) -and ($script:el -le 760 + $wLimit)), $script:threw)) 'stayed/field/4/1/'

# R11 (신규, 미관측 — 2인 파티로 관측 불가) entry 시작, 재펼침 직전 양보 중 패널이 readyDone 으로 펼쳐짐 → 양보 뒤 새 판독 → ready-done → 앵커 0·준비 0, 대기(커밋)
Reset-Member -Plan @((P 0 'entryWaiting'))
$script:r11Calls = 0
$script:activeQueue = 0
$script:readHook = { param($Name) if ($Name -eq 'words' -and $script:r11Calls -eq 0) { $script:r11Calls = 1; $script:activeQueue = 2 } }   # 재펼침 직전 새 판독 동안 조작 시작 (새 판독 검사 + 다음 회전 ②)
$script:onYield = { Set-ScreenAfter 0 @((Step 0.5 'readyDone')) }                                                                              # 양보 중 사용자가 펼침(숨은 준비됨)
Run-Member
Check-Equal "R11 (미관측 — 2인 파티로 관측 불가) 재펼침 직전 조작 → 클릭 없이 양보 → 새 판독 ready-done → 앵커 0·준비 0, 준비 시계 P committed → exit 4 '준비 상태는 그대로'" (
  J @((Count-Click $anchorPoint), (Count-Click $readyPoint), [int]($script:yieldWaits -ge 1), (Get-FirstLeave).Result, $script:exitCode)) '0/0/1/committed/4'

# R12 (⑥a 4-9) readyAvail 시작, 준비가 게임에 먹지 않음(버튼 '준비 완료' 그대로), 13초 입장 → 상태 기반 재클릭 3초 간격 — 10초 동안 3~4회, 입장 뒤 키 1
Reset-Member -Plan @((P 0 'readyAvail'), (P 13 'inside'))
$script:keepPlan = $true
$script:readyIgnored = $true
$script:clearPlan = @($stopClear)
Run-Member
$readyTimes = @(for ($i = 0; $i -lt $script:clicks.Count; $i++) { if ($script:clicks[$i] -eq $readyPoint) { $script:clickTimes[$i] } })
$minGap = 999.0; for ($i = 1; $i -lt $readyTimes.Count; $i++) { $minGap = [Math]::Min($minGap, $readyTimes[$i] - $readyTimes[$i - 1]) }
Check-Equal "R12 (⑥a 4-9) 먹지 않는 준비 → 3초 간격 재클릭(10초 안 3~4회, 최소 간격 $([Math]::Round($minGap, 1)) ≥ 3) → 입장 뒤 키 1" (
  J @([int]((@($readyTimes | Where-Object { $_ -lt 10 }).Count -ge 3) -and (@($readyTimes | Where-Object { $_ -lt 10 }).Count -le 4)), [int]($minGap -ge 3), $script:keys)) '1/1/1'

# R13 (⑥a 4-4) prompt 시작, 터치 첫 시도 user-active → 양보 1 → 재판독 → 터치 전송 1, 건너뜀 1
Reset-Member -Plan @((P 0 'prompt'))
$script:sendByPoint[$touchPoint] = @('user-active')
Run-Member
Check-Equal 'R13 (⑥a 4-4) 터치 첫 시도 조작 생략 → 양보 → 재판독 → 터치 전송 1, 건너뜀 1 (전송 수·예산 미소모)' (J @([int]($script:yieldWaits -ge 1), (Count-Click $touchPoint), $script:skippedActive)) '1/1/1'

# R14 (⑥a 4-10) readyAvail 시작, 준비 첫 시도 user-active → 양보 1 → 버튼 재판독 → 준비 전송 1, 준비 클릭 로그 1(생략 회전 로그 0)
Reset-Member -Plan @((P 0 'readyAvail'))
$script:sendByPoint[$readyPoint] = @('user-active')
Run-Member
Check-Equal "R14 (⑥a 4-10) 준비 첫 시도 조작 생략 → 양보 → 재판독 → 준비 전송 1, 준비 클릭 로그 1, 생략 로그 0 (거짓 '클릭' 로그 없음)" (
  J @([int]($script:yieldWaits -ge 1), (Count-Click $readyPoint), (Count-Log "'준비 완료' 클릭 - 전원 준비되면 자동 입장"), (Count-Log "'준비 완료' 클릭 건너뜀"))) '1/1/1/0'

# R15 'clear' → 접힘, 클릭 직전 새 판독이 캡처 실패(일련번호 변화, 같은 회전 복구) 3회 + 새 판독 중 사용자 조작 2회 → 그 뒤 앵커 정상 →
#     판독 불일치 예산 미소모('위치를 확인하지 못해' 인계 0) → 재펼침 1 → readyAvail → 준비 1 → exit 0 '준비 완료를 누르고' (09-30 리뷰1 - 규칙 4·15)
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'entry-waiting'))
$script:r15Words = 0
$script:failHook = { param($Name) if ($Name -eq 'words') { $script:r15Words++; if ($script:r15Words -le 3) { return 0 } } return -1 }
$script:readHook = { param($Name) if ($Name -eq 'words' -and ($script:r15Words -eq 3 -or $script:r15Words -eq 4)) { $script:userYieldTotalMs += 800 } }   # 4·5번째 새 판독 동안 조작(양보 누적 변화)
Run-Member
Check-Equal "R15 새 판독 캡처 실패 3 + 조작 2 → 불일치 예산 미소모(불일치 로그 0·'위치를 확인하지 못해' 0) → 재펼침 1 → 준비 1 → exit 0 '준비 완료를 누르고'" (
  J @($script:r15Words, (Count-Log '재펼침 건너뜀 - 클릭 직전 판독'), (Count-Log '위치를 확인하지 못해'), (Count-Click $anchorPoint), (Count-Click $readyPoint), $script:exitCode, (Test-LastDone $readyHandoff))) '6/0/0/1/1/0/1'

# R-S 클릭 직전 새 판독에서 S 거짓(④ 뒤 S 소멸) → 터치 0(다음 회전 보상) (리뷰 A5, 09-30 리뷰1)
Reset-Member -Plan @((P 0 'prompt'))
$script:rsDone = $false
$script:readHook = { param($Name) if ($Name -eq 'prompt' -and $script:turnReads['prompt'] -eq 2 -and -not $script:rsDone) { $script:rsDone = $true; Set-ScreenAfter 0 @((Step 0 'memberReward')) } }
Run-Member
Check-Equal 'R-S ④ 뒤 S 소멸(새 판독 S 거짓) → 터치 0, 다음 회전 파티원 보상 → 이후 A2 경로(나가기 1)' (J @((Count-Click $touchPoint), (Count-Click $leavePoint), $script:exitCode)) '0/1/4'

# R-S2 클릭 직전 새 판독 S 참 → 뒤이은 패널 판독 'ready'(두 확인 사이 패널 등장 주입) → 터치 0 → 다음 회전 ready-* 분류(보상 위 판별로 처리) (09-30 리뷰1 P2-1).
#      순서를 '패널 → S' 로 되돌리면 패널 판독이 먼저 'none' 이라 터치 1 → FAIL
Reset-Member -Plan @((P 0 'prompt'))
$script:rs2Done = $false
$script:readHook = { param($Name) if ($Name -eq 'panel' -and $script:turnReads['prompt'] -ge 2 -and -not $script:rs2Done) { $script:rs2Done = $true; Set-ScreenAfter 0 @((Step 0 'readyAvail')) } }
Run-Member
Check-Equal "R-S2 S 새 판독 참 → 패널 판독에서 준비 패널 등장 → 터치 0 → 다음 회전 준비 패널(보상 위) 분류 → 준비 1" (
  J @((Count-Click $touchPoint), (Count-Log '준비 패널 감지 - 준비 전, 보상 위'), (Count-Click $readyPoint))) '0/1/1'

# R-P P 재펼침 직전 새 판독에서 패널이 이미 펼쳐짐 → 앵커 0 (리뷰 A3)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'entry-waiting'))
$script:rpDone = $false
$script:readHook = { param($Name) if ($Name -eq 'panel' -and $script:turnReads['words'] -ge 1 -and $script:pCalls.Count -ge 1 -and -not $script:rpDone) { $script:rpDone = $true; Set-ScreenAfter 0 @((Step 0 'readyAvail')) } }
Run-Member
Check-Equal 'R-P P 탐침 직전 새 판독에서 이미 펼쳐짐 → 앵커 0 → 펼친 패널로 접기 → 나가기 → left → exit 0' (J @((Count-Click $anchorPoint), (Count-Click $collapsePoint), (Get-LeaveResults), $script:exitCode)) '0/2/left/0'

# R-K (미관측 — 2인 파티로 관측 불가) P 양보 중 사용자가 재펼침 → 준비 → 접기 → readyKnown 무효 → 탐침 → ready-done → committed, 나가기 0 (리뷰 A3)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready'))
$script:afterAnchor = @((Step 0.3 'readyDone'))
$script:clickHook = {
  param($Point, $Screen)
  if ($Point -eq $collapsePoint -and $Screen -eq 'readyAvail' -and -not $script:rkDone) {
    $script:rkDone = $true
    Set-ScreenAfter 0.3 @((Step 0 'entryWaiting'))
    $script:activeWindow = @(((Elapsed) + 0.5), ((Elapsed) + 5))   # 접기 뒤 사용자 조작 - 그 사이 재펼침·준비·접기(화면은 다시 접힘 - 숨은 준비됨)
    return $true
  }
  return $false
}
$script:rkDone = $false
Run-Member
Check-Equal 'R-K (미관측 — 2인 파티로 관측 불가) 접기 뒤 양보 중 숨은 준비됨 → readyKnown 무효 → 탐침 1 → ready-done → committed, 나가기 0(접기 1 뿐)' (
  J @((Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Count-Click $anchorPoint), (Count-Click $collapsePoint), (Count-Click $leavePoint))) 'committed/ready-done/1/1/0'

# R-K′ (미관측 — 2인 파티로 관측 불가 · 변이 짝) P 접기 전송 뒤 스윕 참 회전 1(모의: 그 사이 숨은 준비됨으로 접힘) → entry. 스윕 생략 사유는 '전송' 고정,
#      그 회전과 다음 유효 표본 사이에 양보·캡처 실패 없음 → 스윕 참 회전이 readyKnown 을 무효화 → 나가기 대신 탐침 → ready-done → committed, 나가기 0 (09-30 리뷰2 P1-1)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready'))
$script:afterAnchor = @((Step 0.3 'readyDone'))
$script:clickHook = {
  param($Point, $Screen)
  if ($Point -eq $collapsePoint -and $Screen -eq 'readyAvail' -and -not $script:rkDone) {
    $script:rkDone = $true
    Set-ScreenAfter 0.3 @((Step 0 'entryWaiting'))
    Set-SweepFrom -From ((Elapsed) + 0.1) -Kind 'sent' -Gap 1 -Count 1
    return $true
  }
  return $false
}
$script:rkDone = $false
Run-Member
Check-Equal "R-K′ (미관측 — 2인 파티로 관측 불가 · 변이 짝) 접기 뒤 스윕 참(전송) 1 → readyKnown 무효 → 탐침 → committed(ready-done), 나가기 0, 양보·캡처 실패 0" (
  J @((Get-FirstLeave).Result, (Count-Click $anchorPoint), (Count-Click $collapsePoint), $script:sweepTrue, $script:yieldWaits, $script:failedReads)) 'committed/1/1/1/0/0'

# R-F9 F9 취소 경합(소비 직전 파일 사라짐) → 종료 코드 1 아님 (리뷰 B5 - -ErrorAction SilentlyContinue)
Reset-Member -Plan @((P 0 'inside'))
$script:safeStopFlag = $true
$script:flagVanishOnRemove = $true
$script:clearPlan = @((Clear-Spec 'member-reward'))
Run-Member
Check-Equal 'R-F9 소비 직전 파일이 사라져도(GUI F9 취소 경합) 예외 없음 → throw 0, exit 0 (코드 1 아님), Remove-Item 1' (J @($script:threw, $script:exitCode, $script:removes)) '/0/1'

# ── §2-X. 종료 매핑·경계 경합 (설계 2.9 - 사유 × P 결과) ──────────────────────────
$pendingNoCount = '\(회차 미계상\)$'
$mHeader = '다음 입장이 \d+초\(클리어 대기 설정\) 안에 없습니다 - 나가기로 필드에 나온 뒤 마칩니다'
$lastRunHeader = '마지막 회차\(횟수 지정\) - 준비하지 않고 나가기로 필드에 나옵니다'
function Get-WarningLines { @($script:logs | Where-Object { $_ -match '\[경고\] 파티원: 나가기 뒤 필드를 확인하지 못했습니다' }) }

# X1 START 보상 → M 600 → P → 나가기가 먹지 않음(보상 잔존) → 3초 넘게 남으면 재클릭, 실제 전송 3회 → P 60초 → unconfirmed → 진단 + exit 4('M 초과' 행)
Reset-Member -Plan @((P 0 'memberReward'))
$script:leaveIgnored = $true
Run-Member
$leaveTimes = @($script:leaveSendTimes)
$minLeaveGap = 999.0; for ($i = 1; $i -lt $leaveTimes.Count; $i++) { $minLeaveGap = [Math]::Min($minLeaveGap, $leaveTimes[$i] - $leaveTimes[$i - 1]) }
Check-Equal "X1 나가기 무반응: 3초 넘게 남을 때만 재클릭(최소 간격 $([Math]::Round($minLeaveGap, 1)) > 3) · 실제 전송 3회 → P 60초 → unconfirmed(전송 3) → [경고] + 진단 + exit 4 'M 초과' 행" (
  J @($leaveTimes.Count, [int]($minLeaveGap -gt 3), (Get-FirstLeave).Result, (Get-FirstLeave).ExitSends, @(Get-WarningLines).Count, $script:exitCode,
    (Test-LastDone '안에 없어 파티원 대기를 마칩니다 - 나가기 뒤 필드를 확인하지 못함$'), [int]($script:diag.Count -ge 1))) '3/1/unconfirmed/3/1/4/1/1'

# X2 G@CLEAR(LAST_RUN) + 보상, 나가기 첫 시도 user-active → 양보 → 새 판독 → 나가기 1(건너뜀 1, 전송 예산 미소모) → 로딩 → left → exit 0
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'member-reward'))
$script:sendByPoint[$leavePoint] = @('user-active')
Run-Member
Check-Equal 'X2 경계 나가기 첫 시도 조작 생략 → 양보 → 새 판독 → 나가기 1(건너뜀 1) → left → exit 0' (
  J @([int]($script:yieldWaits -ge 1), (Count-Click $leavePoint), $script:skippedActive, (Get-LeaveResults), $script:exitCode, (Test-LastDone $leftHandoff), [int]((Get-LeftDepartSamples) -ge 1))) '1/1/1/left/0/1/1'

# X3 START unknown 지속 → 30초 오버레이 1 → M 600 → P → 클릭 0 → 60초 → stayed → 진단 + exit 4 'M 초과' stayed 문구(라벨 '알 수 없는 화면')
Reset-Member -Plan @((P 0 'unknown'))
Run-Member
Check-Equal "X3 알 수 없음 지속: 이벤트 정리 1, 클릭 0, P stayed(unknown·전송 0), exit 4 'M 초과' stayed 문구 라벨 '알 수 없는 화면'" (
  J @($script:overlays, $script:clicks.Count, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode, (Test-LastDoneContains "나갈 수 없는 화면이라($(Get-Label 'unknown')) 누르지 않음"))) '1/0/stayed/unknown/4/1'

# X4 'clear' → 터치 1 → 보상 없이 필드 지속(G 없음) → 인계 0 → M 600 → P('member-timeout') → 필드 모양 W 이상 → 'stayed'(필드 모양) → 진단 + exit 4 'M 초과' 필드 모양 문구
Reset-Member -Plan @((P 0 'inside'))
$script:afterTouch = 'field'
Run-Member
Check-Equal "X4 CLEAR 터치 뒤 필드 지속(G 없음) → 인계 0, P('member-timeout') stayed(field) → exit 4 필드 모양 M 초과 문구 (계상 손실 수용)" (
  J @((Count-Click $touchPoint), $script:pCalls[0].Reason, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 필드로 보이는 화면이라 누르지 않고 대기를 마칩니다 \(필드 미확정\)'))) '1/member-timeout/stayed/field/4/1'

# X5 'clear' → 터치 1(먹지 않음) → S 잔존(G 없음) → 터치 정확히 1 → M 600 → P → 즉시 stayed → 진단 + exit 4 (계상 손실, 수용 - 'S 재터치 허용' 변이 짝)
Reset-Member -Plan @((P 0 'inside'))
$script:afterTouch = ''
Run-Member
Check-Equal 'X5 CLEAR S 잔존(G 없음) → 터치 정확히 1, 35초 관측 안내 1, P 즉시 stayed(prompt) → exit 4' (
  J @((Count-Click $touchPoint), (Count-Log '35초째 화면이 그대로입니다'), (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode)) '1/1/stayed/prompt/4'

# X6 START 보상 위 readyAvail, 준비가 게임에 먹지 않음 → 준비 재클릭(3초 간격) → 300초 준비 시계 → P('ready-timeout') → 접기 1 → 나가기 1 → 로딩 → left → exit 4
Reset-Member -Plan @((P 0 'readyAvail'))
$script:readyIgnored = $true
Run-Member
Check-Equal "X6 먹지 않는 준비 → 준비 시계 P('ready-timeout') → 접기 1 + 나가기 1 → left → exit 4 '…나가기로 필드에 나와 파티원 대기를 마칩니다'" (
  J @([int]((Count-Click $readyPoint) -ge 2), $script:pCalls[0].Reason, (Count-Click $collapsePoint), (Get-LeaveResults), $script:exitCode,
    (Test-LastDone '준비 패널 뒤 \d+초 안에 입장이 없어 나가기로 필드에 나와 파티원 대기를 마칩니다$'))) '1/ready-timeout/2/left/4/1'

# X7 START readyDone, 300초 만료 순간 입장 — D 의 만료 회전 판독 = readyDone, P 첫 표본 = inside → P committed(inside) → M Set + 준비 시계 Suspend -Reset·에피소드 종료 →
#    continue → inside 2연속 → INSIDE 전이 → 키 1, P 호출 수 정확히 1, 준비 시계 서두 로그 1 (09-30 리뷰1)
Reset-Member -Plan @((P 0 'readyDone'))
Add-LogHook '준비 패널 뒤 \d+초 안에 입장이 없습니다 - 대기를 마칩니다' { Set-ScreenAfter 0 @((Step 0 'inside')) }
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal 'X7 준비 시계 만료 순간 입장 → P committed(inside) → inside 2연속 → INSIDE → 키 1, P 호출 1, 준비 시계 서두 1' (
  J @((Get-LeaveResults), (Get-FirstLeave).Screen, $script:keys, $script:pCalls.Count, (Count-Log '준비 패널 뒤 \d+초 안에 입장이 없습니다 - 대기를 마칩니다'), $script:threw)) 'committed/inside/1/1/1/__STOP__'

# X7′ START field → M 만료 → P('member-timeout') 첫 표본 inside → P committed(inside) → M Set → continue → inside 2연속 → INSIDE 전이 → 키 1, P 호출 수 정확히 1 (09-30 리뷰1)
Reset-Member -Plan @((P 0 'field'))
Add-LogHook $mHeader { Set-ScreenAfter 0 @((Step 0 'inside')) }
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal "X7′ M 만료 P 첫 표본 inside → committed → M Set → INSIDE → 키 1, P 호출 정확히 1 ('committed 뒤 M Set 누락' 변이면 2)" (
  J @((Get-LeaveResults), $script:keys, $script:pCalls.Count, $script:threw)) 'committed/1/1/__STOP__'

# X8 INSIDE → 클리어 감시 'left'(거점 부활 상한) → exit 4, 'left' 블록 문구(revive 280 모양)
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @(@{ Return = 'left'; Steps = @(); Advance = 60 })
Run-Member
Check-Equal "X8 클리어 감시 'left'(거점 부활 상한) → exit 4 '파티원: 거점 부활 상한으로 던전을 나왔습니다 - … 자동 재입장 흐름이 없어 정지합니다'" (
  J @($script:exitCode, (Test-LastDone '^\[완료\] 파티원: 거점 부활 상한으로 던전을 나왔습니다 - 파티원은 퇴장 뒤 자동 재입장 흐름이 없어 정지합니다$'), $script:clicks.Count)) '4/1/0'

# X9 INSIDE → 클리어 감시 throw(마감) → D 가 삼키지 않음 — 러너가 원래 예외 메시지를 받음(코드 1 경로)
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @(@{ Return = ''; Throw = '던전 클리어 화면 감지 대기 시간이 초과됐습니다.'; Advance = 600 })
Run-Member
Check-Equal 'X9 클리어 감시 throw 를 삼키지 않음 (원래 메시지 그대로 - 최상위 catch → 코드 1·오류 세트)' (J @($script:threw, $script:exitCode)) '던전 클리어 화면 감지 대기 시간이 초과됐습니다./'

# X10 START 보상 → M 만료로 P 가 불린 직후 보상 위 readyAvail → P 첫 회전 aborted → '대기 한도 도달 순간 …' 로그 → M Set → D 준비 1, P 호출 수 정확히 1
Reset-Member -Plan @((P 0 'memberReward'))
Add-LogHook $mHeader { Set-ScreenAfter 0 @((Step 0 'readyAvail')) }
$script:afterReady = @((Step 0.5 'readyDone'), (Step 5 'entryLoading'), (Step 9 'inside'))
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal "X10 M 만료 P 직후 요청(보상 위 준비 전) → aborted → '대기 한도 도달 순간' 1 → D 준비 1 → 입장, P 호출 정확히 1" (
  J @((Get-LeaveResults), (Count-Log '대기 한도 도달 순간 파티장 요청이 보여 나가지 않고 이어갑니다'), (Count-Click $readyPoint), $script:pCalls.Count, $script:keys)) 'aborted/1/1/1/1'

# X11 START field + F9 → field 2연속 → P(G) → 필드 모양 W 이상 → 'stayed'(필드 모양) → 반환 직전 소비 1 → 진단 + exit 4 '안전 중지 예약 - 필드로 보이는 화면이라 … (필드 미확정, 회차 미완료)'
Reset-Member -Plan @((P 0 'field'))
$script:safeStopFlag = $true
Run-Member
Check-Equal "X11 START 필드 + F9 → P(G) stayed(field) → 반환 직전 소비 1 → exit 4 '안전 중지 예약 - 필드로 보이는 화면이라 누르지 않고 마칩니다 (필드 미확정, 회차 미완료)'" (
  J @($script:pCalls[0].Reason, (Get-FirstLeave).Result, $script:removes, [bool](Get-FirstLeave).Consumed, $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 안전 중지 예약 - 필드로 보이는 화면이라 누르지 않고 마칩니다 \(필드 미확정, 회차 미완료\)$'), $script:clicks.Count)) 'safe-stop/stayed/1/True/4/1/0'

# X12 START readyDone + F9 → 소비 0·클릭 0 → 입장 → 키 1 → 클리어 → 경계 P(G) → 나가기 1 → 소비 1 → 로딩 → left → exit 0
Reset-Member -Plan @((P 0 'readyDone'), (P 10 'entryLoading'), (P 14 'inside'))
$script:keepPlan = $true
$script:safeStopFlag = $true
$script:clearPlan = @((Clear-Spec 'member-reward'))
Run-Member
Check-Equal 'X12 START 준비됨 + F9 → 소비 0·클릭 0(커밋 상태는 경계로 미룸) → 입장 → 키 1 → 경계 P(G) → 나가기 1·소비 1 → left → exit 0' (
  J @($script:pCalls.Count, $script:keys, (Count-Click $leavePoint), $script:clicks.Count, $script:removes, (Get-LeaveResults), $script:exitCode)) '1/1/1/1/1/left/0'

# X-F START F9 + readyField → 클릭 0 → P 60초 → stayed → 반환 직전 소비 → exit 4 '필드 위 준비 패널' (리뷰 C1, 09-30 결정 D3)
Reset-Member -Plan @((P 0 'readyField'))
$script:safeStopFlag = $true
Run-Member
Check-Equal "X-F START F9 + 필드 위 준비 패널 → 클릭 0 → P 60초 stayed → 반환 직전 소비 1 → exit 4 '안전 중지 예약 - 필드 위 준비 패널이라 준비를 누르지 않고 마칩니다 (회차 미완료)'" (
  J @($script:clicks.Count, $script:misclicks.Count, (Get-FirstLeave).Result, $script:removes, $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 안전 중지 예약 - 필드 위 준비 패널이라 준비를 누르지 않고 마칩니다 \(회차 미완료\)$'))) '0/0/stayed/1/4/1'

# X-FA M 만료, P 첫 회전 readyField → aborted → D 준비 1
Reset-Member -Plan @((P 0 'field'))
Add-LogHook $mHeader { Set-ScreenAfter 0 @((Step 0 'readyField')) }
$script:afterReady = @((Step 0.5 'readyDoneField'), (Step 5 'entryLoading'), (Step 9 'inside'))
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal 'X-FA M 만료 P 첫 회전 필드 위 준비 전 패널 → aborted → D 준비 1 (P 는 누르지 않음)' (J @((Get-LeaveResults), (Count-Click $readyPoint), $script:pCalls.Count, $script:misclicks.Count)) 'aborted/1/1/0'

# X-FD (미관측 — 2인 파티로 관측 불가) START 필드 → M 만료로 P 가 불린 직후 readyDone 이 펼친 채 등장 → P 첫 회전 aborted(-AllowAbort 면 ready-done 도 커밋보다 중단이 먼저)
#      → M Set → D 대기(커밋) → 입장 → 키 1, 준비 0, P 호출 수 정확히 1 (09-30 정정)
Reset-Member -Plan @((P 0 'field'))
Add-LogHook $mHeader { Set-ScreenAfter 0 @((Step 0 'readyDone'), (Step 10 'entryLoading'), (Step 14 'inside')) }
$script:clearPlan = @($stopClear)
Run-Member
Check-Equal 'X-FD (미관측 — 2인 파티로 관측 불가) M 만료 P 직후 펼친 준비됨 → aborted(중단이 커밋보다 먼저) → D 대기 → 입장 → 키 1, 준비 0, P 호출 1' (
  J @((Get-LeaveResults), (Get-FirstLeave).Screen, $script:keys, (Count-Click $readyPoint), $script:pCalls.Count)) 'aborted/ready-done/1/0/1'

# X-C G@CLEAR, 접기 판독 뒤 파티장 취소(보상 전이) → 접기 좌표가 보상 '나가기' → 로딩(접기 전송 무장 + 떠남) → field 2 → left → exit 0 (리뷰 A6, 09-30 리뷰1)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready'))
$script:clickHook = {
  param($Point, $Screen)
  if ($Point -eq $collapsePoint -and $Screen -eq 'readyAvail' -and -not $script:xcDone) {
    $script:xcDone = $true   # 판독과 전송 사이에 파티장 취소 → 좌표가 파티원 보상 '나가기'(402~628) 안 → 퇴장 전이 (09-26 23:18:28, 09-29 21:20:31 관측)
    $script:leaveSendTimes.Add((Elapsed))
    Set-ScreenAfter 0 @((Step 0 'memberReward'), (Step 0.5 'loading'), (Step 4.5 'arrival'), (Step 5.5 'field'))   # 전송 순간 화면은 이미 보상 → 곧 퇴장 로딩 (§1(i) i9 의 다음 표본 unknown)
    return $true
  }
  return $false
}
$script:xcDone = $false
Run-Member
Check-Equal 'X-C 접기 좌표가 파티장 취소로 보상 나가기에 떨어짐 → 접기 전송 무장 + 로딩(떠남) + 필드 2 → left → exit 0 (접기 1 뿐, 나가기 0)' (
  J @((Count-Click $collapsePoint), (Count-Click $leavePoint), (Get-LeaveResults), (Get-FirstLeave).Stage, $script:exitCode, (Test-LastDone $leftHandoff), [int]((Get-LeftDepartSamples) -ge 1))) '1/0/left/departed/0/1/1'

# X-U G@CLEAR, 나가기 뒤 readyField(HUD 가림) → 60초 → unconfirmed → [경고] + 진단 + exit 4 '(회차 미계상)' (리뷰 B3 → 09-30 결정 D2)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'member-reward'))
$script:afterLeave = @((Step 1 'readyField'))
Run-Member
Check-Equal "X-U 나가기 뒤 필드 위 준비 패널(HUD 가림) → P 60초 unconfirmed(전송 1) → [경고] + exit 4 '나가기 뒤 필드를 확인하지 못해 마칩니다 (회차 미계상)'" (
  J @((Get-FirstLeave).Result, (Get-FirstLeave).ExitSends, @(Get-WarningLines).Count, $script:exitCode, (Test-LastDone '^\[완료\] 파티원: 마지막 회차\(횟수 지정\) - 나가기 뒤 필드를 확인하지 못해 마칩니다 \(회차 미계상\)$'), $script:misclicks.Count)) 'unconfirmed/1/1/4/1/0'

# X-UT (X-U 의 시간 지정 쌍둥이 - 계약 P2-1, 2인 실기에서 두 번 관측된 끝 모양: 순서표 104~116·146~157) 경계 보상 위 준비 전 패널이 U(10:30) + 1초 →
#      P(G 'time'): 접기 → 접힘 → 나가기(단어 492) → 로딩 1초 → 필드 위 준비 패널(파티장이 '다시 하기' 를 먼저 눌러 요청이 따라옴) → 무장 해제 1('준비 패널') →
#      P 60초 unconfirmed → [경고] + exit 4 (마지막 판 미계상 - 결정 D2 그대로, 설계 4.3·R13). 헛클릭 0: 필드 위 패널의 준비·접기는 누르지 않음
Reset-Member -Plan @((P 0 'inside'))
Set-MemberTimeTarget $untilText
$script:clearPlan = @(@{ Return = 'ready'; Steps = @((Step 0 'readyAvail')); At = $untilElapsed + 1 })
$script:afterLeave = @((Step 1 'loading'), (Step 2 'readyField'))
Run-Member
Check-Equal "X-UT 경계 보상 위 준비 전 패널(U+1초) → P(G 'time') 접기 1·나가기 1(=(492,654) 2)·준비 0 → 로딩 → 필드 위 준비 패널 → 무장 해제 1('준비 패널') → unconfirmed → [경고] 1 + exit 4 '마지막 회차(지정 시간 10:30) - 나가기 뒤 필드를 확인하지 못해 마칩니다 (회차 미계상)', 헛클릭 0" (
  J @($script:pCalls[0].Reason, (Count-Log '준비 패널 접기 - 패널 밖'), @($script:leaveSendTimes).Count, (Count-Click $collapsePoint), (Count-Click $readyPoint),
    (Count-Log '나가기 뒤 화면 전이가 끊겼습니다\(준비 패널\)'), (Get-FirstLeave).Result, @(Get-WarningLines).Count, $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 마지막 회차\(지정 시간 10:30\) - 나가기 뒤 필드를 확인하지 못해 마칩니다 \(회차 미계상\)$'), $script:misclicks.Count)) 'time/1/1/2/0/1/unconfirmed/1/4/1/0'

# X-CR 이월 + 준비 시계 만료(readyDone) → ⑨ 서두 $pendingCount 로 P(G) → committed → 진단 + exit 4 '준비 상태 그대로, 회차 미계상' (리뷰 B3 → 09-30 결정 D2)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyDone'))))
Run-Member
Check-Equal "X-CR 이월 뒤 준비됨 지속 → 준비 시계 만료 P(G 'last-run') committed → exit 4 '…다음 판 준비 상태(…)라 나가지 못하고 마칩니다 (준비 상태 그대로, 회차 미계상)'" (
  J @((Count-Log '\(이월\)$'), $script:pCalls[0].Reason, (Get-FirstLeave).Result, $script:exitCode, (Test-LastDone '다음 판 준비 상태\(.+\)라 나가지 못하고 마칩니다 \(준비 상태 그대로, 회차 미계상\)$'))) '1/last-run/committed/4/1'

# X-FC G@CLEAR(LAST_RUN), 경계 신호가 readyField → 클릭 0 → P 60초 → stayed → 진단 + exit 4 '필드 위 준비 패널이라 … (회차 미계상)' (09-30 결정 D2·D3)
Set-XfcPlan
Run-Member
Check-Equal "X-FC 경계 필드 위 준비 패널 + 마지막 회차 → 클릭 0 → P 60초 stayed → exit 4 '필드 위 준비 패널이라 준비를 누르지 않고 마칩니다 (회차 미계상)'" (
  J @($script:clicks.Count, $script:misclicks.Count, (Get-FirstLeave).Result, [int](([Math]::Abs(($script:pCalls[0].EndAt - $script:pCalls[0].At) - $memberLeaveLimitSeconds)) -le 1), $script:exitCode,
    (Test-LastDone '마지막 회차\(횟수 지정\)지만 필드 위 준비 패널이라 준비를 누르지 않고 마칩니다 \(회차 미계상\)$'))) '0/0/stayed/1/4/1'

# ── START 의 시간 판단 (시간 지정 '그 판까지' 설계 8.2 T2 - X-T 계열). START 의 G 'time' = 새 판 참가를 막음: 비커밋 화면(보상·필드 위 준비 패널·
#    접힌 패널·필드)이면 P → 코드 4 (회차 미완료). 옛 X-T·X-T′ 는 U 가 M 만료 시각과 같아 M 만료 회전에서 우연히 통과했으므로(map_tests 0-1)
#    U 를 케이스 시작(10:00 - 이미 지남)으로 두고 P 서두 시각을 함께 봅니다. START 시간 문구 5종은 아래 5개 케이스가 행동으로 하나씩 지킵니다 (회귀 R-11)
# X-T START 보상 + 지정 시각 지남 → 첫 회전 G 'time' → P(G) → 나가기 1 → 로딩 → left → exit 4 '지정 시간 10:00 도달 - 다음 판에 참가하지 않고 …'(계상 0)
Reset-Member -Plan @((P 0 'memberReward'))
Set-MemberTimeTarget '2026-10-01 10:00'
Run-Member
Check-Equal "X-T START 보상 + 지정 시각 지남 → 첫 회전 P(G 'time')(서두 ≤ 0.5초) → 나가기 1 → left → exit 4 '지정 시간 10:00 도달 - 다음 판에 참가하지 않고 나가기로 필드에 나와 마칩니다'" (
  J @($script:pCalls[0].Reason, [int]($script:pCalls.Count -ge 1 -and $script:pCalls[0].At -le 0.5), (Count-Click $leavePoint), (Get-LeaveResults), $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 지정 시간 10:00 도달 - 다음 판에 참가하지 않고 나가기로 필드에 나와 마칩니다$'))) 'time/1/1/left/4/1'

# X-TP START 필드 + 지정 시각 지남 → 필드 2연속 → P(G 'time') → 필드 모양 W 이상 → 'stayed'(필드 모양, 누를 것 없음) → 진단 + exit 4, 클릭 0
#      (옛 X-T′ '빠른 PC 여분 워커' 는 ⑥e ㉰ 의 여유가 만든 창이라 사라졌습니다 - 'left' 뒤 GUI 는 반드시 멈춤, 설계 4.7)
Reset-Member -Plan @((P 0 'field'))
Set-MemberTimeTarget '2026-10-01 10:00'
Run-Member
Check-Equal "X-TP START 필드 + 지정 시각 지남 → P(G 'time') stayed(field) → exit 4 '필드로 보이는 화면이라 누르지 않고 마칩니다 (필드 미확정) - 지정 시간 10:00 도달', 클릭 0" (
  J @($script:pCalls[0].Reason, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:clicks.Count, $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 필드로 보이는 화면이라 누르지 않고 마칩니다 \(필드 미확정\) - 지정 시간 10:00 도달$'))) 'time/stayed/field/0/4/1'

# X-TF START 필드 위 준비 패널 + 지정 시각 지남 → 첫 회전 G 'time'(⑩ 준비보다 먼저) → P(G) 는 필드 위 패널에서 누르지 않음 → P 60초 stayed → exit 4.
#      기대는 전체 원문입니다 (회귀 R-11 - 옛 기대는 꼬리만 봐서 사유 앞부분이 바뀌어도 통과했음)
Reset-Member -Plan @((P 0 'readyField'))
Set-MemberTimeTarget '2026-10-01 10:00'
Run-Member
Check-Equal "X-TF START 필드 위 준비 패널 + 지정 시각 지남 → 클릭 0 → P(G 'time') 60초 stayed → exit 4 '지정 시간 10:00 도달 - 필드 위 준비 패널이라 준비를 누르지 않고 마칩니다'" (
  J @($script:clicks.Count, $script:misclicks.Count, $script:pCalls[0].Reason, (Get-FirstLeave).Result, $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 지정 시간 10:00 도달 - 필드 위 준비 패널이라 준비를 누르지 않고 마칩니다$'))) '0/0/time/stayed/4/1'

# X-TU (회귀 R-11) START 보상 + 지정 시각 지남 → P(G) 나가기 1 → 로딩 1초 → 필드 위 준비 패널(파티장 요청이 따라옴) → 무장 해제 → P 60초 unconfirmed → [경고] + exit 4
Reset-Member -Plan @((P 0 'memberReward'))
Set-MemberTimeTarget '2026-10-01 10:00'
$script:afterLeave = @((Step 1 'loading'), (Step 2 'readyField'))
Run-Member
Check-Equal "X-TU START 보상 + 지정 시각 지남 → P(G 'time') 나가기 1 → 로딩 → 필드 위 준비 패널 → unconfirmed → [경고] 1 + exit 4 '지정 시간 10:00 도달 - 나갔지만 나가기 뒤 필드를 확인하지 못해 마칩니다'" (
  J @($script:pCalls[0].Reason, (Count-Click $leavePoint), (Get-FirstLeave).Result, @(Get-WarningLines).Count, $script:exitCode,
    (Test-LastDone '^\[완료\] 파티원: 지정 시간 10:00 도달 - 나갔지만 나가기 뒤 필드를 확인하지 못해 마칩니다$'))) 'time/1/unconfirmed/1/4/1'

# X-TN START 접힌 패널 + 지정 시각 지남 → P(G) 재펼침 탐침 2회 무반응 → P 60초 stayed(접힌 패널) → exit 4 '…도달 - 나갈 수 없는 화면이라(접힌 준비 패널) …'
#      (START 시간 문구 5종의 다섯째 - 설계 표의 선택 케이스지만 문구 5종을 모두 행동으로 지키려고 둡니다)
Reset-Member -Plan @((P 0 'entryWaiting'))
Set-MemberTimeTarget '2026-10-01 10:00'
$script:afterAnchor = $null
Run-Member
$xtnLabel = [regex]::Escape((Get-Label 'entry-waiting'))
Check-Equal "X-TN START 접힌 패널 + 지정 시각 지남 → P(G 'time') 탐침 2(무반응) → stayed(entry-waiting) → exit 4 '지정 시간 10:00 도달 - 나갈 수 없는 화면이라(접힌 준비 패널) 누르지 않고 마칩니다'" (
  J @($script:pCalls[0].Reason, (Count-Click $anchorPoint), (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode,
    (Test-LastDone ('^\[완료\] 파티원: 지정 시간 10:00 도달 - 나갈 수 없는 화면이라\(' + $xtnLabel + '\) 누르지 않고 마칩니다$')))) 'time/2/stayed/entry-waiting/4/1'

# X-TS(a) (회귀 R-2) START 보상 유지 + 지정 시각 = 케이스 시작 + 60초(M 600초보다 훨씬 앞 - M 만료가 원인일 수 없음) → G 를 매 회전 다시 계산하므로
#         지정 시각을 넘긴 첫 회전(회전 격자 0.7초 - 60.2초)에 P(G 'time') → 나가기(515,654) 1 → left → exit 4, 준비 0
#         ('G 를 루프 앞에서 한 번만 계산' 변이면 P 가 M 만료(600초)의 'member-timeout' 이 됨)
Reset-Member -Plan @((P 0 'memberReward'))
Set-MemberTimeTarget '2026-10-01 10:01'
Run-Member
$xtsPAt = @($script:pCalls | ForEach-Object { $_.At }) -join ','
Check-Equal "X-TS(a) START 보상 유지 + 지정 시각 +60초 → P(G 'time') 서두 ∈ [60, 60.7] (실제 $xtsPAt) → 나가기 1·준비 0 → left → exit 4 '지정 시간 10:01 도달 - 다음 판에 참가하지 않고 …'" (
  J @([int]($script:pCalls.Count -ge 1 -and $script:pCalls[0].At -ge 60 -and $script:pCalls[0].At -le 60.7), $script:pCalls[0].Reason, (Count-Click $leavePoint), (Count-Click $readyPoint),
    (Get-LeaveResults), $script:exitCode, (Test-LastDone '^\[완료\] 파티원: 지정 시간 10:01 도달 - 다음 판에 참가하지 않고 나가기로 필드에 나와 마칩니다$'))) '1/time/1/0/left/4/1'

# X-TS(b) START 보상 → 준비 전 패널(보상 위)이 계획 At = 60초 - 지정 시각을 넘긴 첫 회전(60.2초)에 처음 보임 (회전 격자 U−0.7 < At ≤ U) → 그 회전 ⑧ 의
#         G 'time' 이 ⑩ 준비보다 먼저 → 준비 0, P(G) 접기 1 → 접힘 → 나가기(단어 492) 1 → left → exit 4
Reset-Member -Plan @((P 0 'memberReward'), (P 60 'readyAvail'))
Set-MemberTimeTarget '2026-10-01 10:01'
Run-Member
Check-Equal "X-TS(b) 준비 전 패널이 지정 시각과 같은 회전에 처음 보임 → 준비 0 → P(G 'time') 접기 1 → 나가기 1 (=(492,654) 2) → left → exit 4" (
  J @((Count-Click $readyPoint), (Count-Log '준비 패널 접기 - 패널 밖'), @($script:leaveSendTimes).Count, (Count-Click $collapsePoint), $script:pCalls[0].Reason, (Get-LeaveResults), $script:exitCode)) '0/1/1/2/time/left/4'

# X-TC (조건 1 - 지정 시각 전에 시작한 판은 끝까지) START 보상 → 준비 전 패널이 U − 5초 → G '' → 준비 1 → 입장 → 키 1 → 판(지정 시각을 넘겨 끝남) →
#      경계 보상 P(G 'time') 1 → left → exit 0 '마지막 회차(지정 시간 10:01)라' (START 의 준비됨·입장 로딩 구간은 지정 시각을 넘겨도 G 와 무관하게 진행)
Reset-Member -Plan @((P 0 'memberReward'), (P 55 'readyAvail'))
Set-MemberTimeTarget '2026-10-01 10:01'
$script:afterReady = @((Step 0.5 'readyDone'), (Step 5 'entryLoading'), (Step 9 'inside'))
$script:clearPlan = @((Clear-Spec 'member-reward'))
Run-Member
Check-Equal "X-TC 지정 시각 5초 전 준비 1 → 입장(지정 시각 뒤) → 키 1 → 판 → 경계 P(G 'time') 1(서두 > 60초) → left → exit 0 '마지막 회차(지정 시간 10:01)라 나가기로 필드에 나와 마칩니다'" (
  J @((Count-Click $readyPoint), [int]($script:clickTimes.Count -ge 1 -and $script:clickTimes[0] -lt 60), $script:keys, $script:pCalls.Count, $script:pCalls[0].Reason, [int]($script:pCalls.Count -ge 1 -and $script:pCalls[0].At -gt 60),
    (Get-LeaveResults), $script:exitCode, (Test-LastDone '^\[완료\] 파티원 회차 완료 - 마지막 회차\(지정 시간 10:01\)라 나가기로 필드에 나와 마칩니다$'))) '1/1/1/1/time/1/left/0/1'

# ── §2-X-M. 'left' = 끊김 없이 관측된 퇴장 전이 계약 (09-30 리뷰1 P1-1 이후) ─────────────
# 모든 'left' 기대 케이스는 'left' 로그의 로딩 표본 n ≥ 1 을, 무장 해제가 끼는 케이스는 무장 해제 로그 1(사유 포함)을 함께 단언합니다 (설계 5.1 끝 단락)
function Get-UnarmCount { param([string]$Cause) Count-Log ('나가기 뒤 화면 전이가 끊겼습니다\(' + [regex]::Escape($Cause) + '\)') }
function Get-FirstPLeft { if ($script:pCalls.Count -eq 0) { return -1 } return [int](@($script:logs | Where-Object { $_ -match '필드 확인 \(퇴장 방향' } | Where-Object { [double](($_.Trim() -split '\s+')[0]) -le $script:pCalls[0].EndAt }).Count) }
function Set-LeaveHook {
  # 경계 P(G)의 첫 '나가기'(보상 @515) 전송 순간에 케이스 전용 장면을 겁니다 (한 번만) - 기본 퇴장 전이 대신
  param([scriptblock]$Action)
  $script:leaveHookAction = $Action
  $script:leaveHookDone = $false
  $script:clickHook = {
    param($Point, $Screen)
    if ($Point -eq $leavePoint -and $Screen -eq 'memberReward' -and -not $script:leaveHookDone) {
      $script:leaveHookDone = $true
      $script:leaveSendTimes.Add((Elapsed))
      & $script:leaveHookAction
      return $true
    }
    return $false
  }
}
function Set-GClearReward { Reset-Member -Plan @((P 0 'inside')); $script:dgLastRun = $true; $script:clearPlan = @((Clear-Spec 'member-reward'), (Clear-Spec 'member-reward')) }

# X-M1 관측 5 회귀 (START): F9 + 던전 안(워커가 던전 안에서 시작), 추적기 오독 모의(HUD 참·추적기 거짓 - error png 판독문)
#   (a) 관측 모양 — 오독 2표본으로 D field 2연속 → P(G) → P 첫 표본 inside → committed(전송 0 — 소비 0, 파일 유지) → 계속 → INSIDE → 키 1 → 완주 → CLEAR 경계 P(G) → 나가기 → 로딩 → left → exit 0
#   (b) 미관측 최악 — 오독이 W 이상 연속 → 'stayed'(필드 모양) → 반환 직전 소비 1 → 진단 + exit 4 '…필드로 보이는 화면이라 누르지 않고 마칩니다 (필드 미확정, 회차 미완료)'
#   두 변형 모두 첫 P 에서 'left' 0 · 나가기 0 · '나가기로 필드에 나와' 문구 0 (09-30 리뷰1 P1-1)
Reset-Member -Plan @((P 0 'transientRun'))
$script:transientSeq = @('fieldMisread', 'fieldMisread')
$script:safeStopFlag = $true
$script:clearPlan = @((Clear-Spec 'member-reward'))
Run-Member
Check-Equal "X-M1(a) 던전 안 오독 2표본 → D field 2연속 → P(G) 첫 표본 inside → committed(소비 0·파일 유지) → INSIDE → 키 1 → 경계 P(G) left → exit 0" (
  J @((Get-LeaveResults), [bool](Get-FirstLeave).Consumed, (Get-FirstLeave).ExitSends, $script:keys, $script:removes, $script:exitCode, (Test-LastDone '마지막 회차\(안전 중지 예약\)라 나가기로 필드에 나와 마칩니다$'))) 'committed,left/False/0/1/1/0/1'
Check-Equal "X-M1(a) 첫 P 에서 'left' 0 · 나가기 0" (J @((Get-FirstPLeft), @($script:leaveSendTimes | Where-Object { $_ -le $script:pCalls[0].EndAt }).Count)) '0/0'
Reset-Member -Plan @((P 0 'fieldMisread'))
$script:safeStopFlag = $true
Run-Member
Check-Equal "X-M1(b) (미관측 최악) 오독이 W 이상 → stayed(field) → 반환 직전 소비 1 → exit 4 '안전 중지 예약 - 필드로 보이는 화면이라 … (필드 미확정, 회차 미완료)', left 0·나가기 0·'나가기로 필드에 나와' 0" (
  J @((Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:removes, $script:exitCode, (Test-LastDone '안전 중지 예약 - 필드로 보이는 화면이라 누르지 않고 마칩니다 \(필드 미확정, 회차 미완료\)$'),
    (Get-FirstPLeft), $script:clicks.Count, (Count-Log '나가기로 필드에 나와'))) 'stayed/field/1/4/1/0/0/0'

# X-M2 관측 5·입장 과도 회귀 (이월 + G): LAST_RUN, 경계 신호 ready-done → 이월 → 다음 판 입장 로딩 뒤 오독(모의)
#   (a) 입장 과도 2표본(관측) → D field 2연속 + G('clear' 의미) → P(G) → 과도 field 는 W 미달 → inside → committed(inside) → 이월 유지 → INSIDE → 키 1 → … → 다음 경계 P → left → exit 0(두 판에 1)
#   (b) 오독이 W 이상 연속(미관측 최악) → 'stayed'(필드 모양) → 진단 + exit 4 '…(필드 미확정, 회차 미계상)'. 두 변형 모두 오독 구간에서 exit 0 0
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyDone'), (Step 10 'entryLoading'), (Step 14 'transientRun'))), (Clear-Spec 'member-reward'))
Run-Member
Check-Equal 'X-M2(a) 이월 뒤 입장 과도 2표본 → D field 2연속 + G → P(G) committed(inside) → 이월 유지 → INSIDE(키 합 2) → 경계 P left → exit 0' (
  J @((Count-Log '\(이월\)$'), (Get-LeaveResults), (Get-FirstLeave).Screen, $script:keys, $script:exitCode, (Get-FirstPLeft), (Test-LastDone $leftHandoff))) '1/committed,left/inside/2/0/0/1'
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyDone'), (Step 10 'entryLoading'), (Step 14 'fieldMisread'))))
Run-Member
Check-Equal "X-M2(b) (미관측 최악) 이월 뒤 오독 W 이상 → P(G) stayed(field) → exit 4 '…필드로 보이는 화면이라 누르지 않고 마칩니다 (필드 미확정, 회차 미계상)', exit 0 0" (
  J @((Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode, (Test-LastDone '마지막 회차\(횟수 지정\)지만 필드로 보이는 화면이라 누르지 않고 마칩니다 \(필드 미확정, 회차 미계상\)$'))) 'stayed/field/4/1'

# X-M3 (빠른 PC 가정 — 미관측) G@CLEAR(LAST_RUN) + 보상, 나가기 뒤 로딩 0초로 곧바로 field → 나가기 1 → '로딩 화면 없이 필드로 보입니다' 로그 1 → 떠남 없음 → P 60초 →
#      unconfirmed(Stage 'sent', 라벨 '… - 나가기 뒤 로딩 화면 미관측') → [경고] + 진단 + exit 4 '(회차 미계상)'. exit 0 0 (09-30 리뷰1)
Set-GClearReward
$script:afterLeave = @((Step 0 'field'))
Run-Member
$xm3Label = Get-Label 'field' $false 'sent' $true
Check-Equal "X-M3 (빠른 PC 가정 — 미관측) 나가기 뒤 로딩 없이 필드 → 로그 1 → P 60초 unconfirmed(Stage sent) → [경고] 라벨 '$xm3Label' + exit 4 '(회차 미계상)'" (
  J @((Count-Click $leavePoint), (Count-Log '퇴장 방향 클릭 뒤 로딩 화면 없이 필드로 보입니다'), (Get-FirstLeave).Result, (Get-FirstLeave).Stage, [int](@(Get-WarningLines | Where-Object { $_.Contains("($xm3Label)") }).Count -eq 1),
    $script:exitCode, (Test-LastDone $pendingNoCount))) '1/1/unconfirmed/sent/1/4/1'

# X-M4 양보 중 입장 (관측 타이밍): G@CLEAR(LAST_RUN) + 보상 → 나가기 1 → 로딩 1표본(떠남) → 사용자 조작(양보) — 그 사이 파티원이 필드에 닿고 사용자가 필드 위 패널에서 준비 →
#      양보 종료 → 입장 로딩 1~2표본 → 입장 과도 field 2표본 → inside → interrupt 무장 해제 → 입장 로딩은 떠남 아님 → 과도 field 는 W 미달 → committed(inside) → 이월 → … → left → exit 0(두 판에 1)
Set-GClearReward
Set-LeaveHook {
  Set-ScreenAfter 0 @((Step 1 'loading'), (Step 10 'entryLoading'), (Step 11.2 'transientRun'))
  $script:activeWindow = @(((Elapsed) + 1.8), ((Elapsed) + 10))
}
Run-Member
Check-Equal "X-M4 퇴장 로딩 뒤 양보 중 입장 → 무장 해제 1('조작·캡처 실패') → 첫 P committed(inside)·left 0 → 이월 → 다음 경계 P left → exit 0 (키 합 2)" (
  J @((Get-UnarmCount '조작·캡처 실패'), (Get-LeaveResults), (Get-FirstLeave).Screen, (Get-FirstPLeft), (Count-Log '\(이월\)$'), $script:keys, $script:exitCode, @(Get-LeaveLog).Count)) '1/committed,left/inside/0/1/2/0/1'
Check-Equal 'X-M4 떠남 표본을 본 뒤에 양보가 끼었음 (첫 P 의 로딩 표본 ≥ 1 - 모의 전제 확인)' ([int](@($script:samples | Where-Object { $_.S -eq 'loading' -and $_.T -le $script:pCalls[0].EndAt }).Count -ge 1)) 1

# X-M5 G@CLEAR + 접힘(readyKnown) → 나가기 1 → (모의) unknown 1(떠남) → 2초 뒤 접힘 재출현 → (모의) field 지속 → 떠남 뒤 접힘이 무장을 풂(Stage none, 재클릭은 3초 규칙 전이라 없음)
#      → 필드 모양 W 이상 → unconfirmed(Stage none·전송 있음 - 라벨 '… 나가기 뒤 화면 전이를 끊김 없이 보지 못함') → [경고] + exit 4. left 0 (09-30 리뷰1)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready'))
$script:clickHook = {
  param($Point, $Screen)
  if ($Point -eq '492,654' -and $Screen -eq 'entryWaiting' -and -not $script:xm5Done) {
    $script:xm5Done = $true
    $script:leaveSendTimes.Add((Elapsed))
    Set-ScreenAfter 0 @((Step 0.5 'loading'), (Step 1.2 'entryWaiting'), (Step 2.5 'field'))
    return $true
  }
  return $false
}
$script:xm5Done = $false
Run-Member
$xm5Label = Get-Label 'field' $false 'none' $true
Check-Equal "X-M5 떠남 뒤 접힘 재출현 → 무장 해제 1('나가기 전 화면'), 재클릭 0 → 필드 모양 W → unconfirmed(Stage none) → [경고] 라벨 '$xm5Label' + exit 4, left 0" (
  J @((Get-UnarmCount '나가기 전 화면'), @($script:leaveSendTimes).Count, (Get-FirstLeave).Result, (Get-FirstLeave).Stage, [int]((Get-FirstLeave).ExitSends -ge 1),
    [int](@(Get-WarningLines | Where-Object { $_.Contains("($xm5Label)") }).Count -eq 1), $script:exitCode, (Get-FirstPLeft))) '1/1/unconfirmed/none/1/1/4/0'

# X-M6 동결 중 자동 입장: G@CLEAR(LAST_RUN) + 보상 → 나가기 1 → 로딩 1표본(떠남) → 캡처 실패 180초(그 사이 모의 재매칭 자동 입장 — 관측 4) →
#      복구 뒤 185241·185242·185243 판독문(입장 과도 field) → inside → interrupt(captureFailSerial 차분) → 무장 해제 → 과도 3표본 W 미달 → committed(inside) → 이월 → …
#      변형(미관측 최악): 복구 뒤 오독이 W 이상 → unconfirmed(Stage none·전송 1) → [경고] + exit 4 '(회차 미계상)'
foreach ($variant in @('관측', '최악')) {
  Set-GClearReward
  $script:transientSeq = @('transient1', 'transient2', 'transient3')
  $script:xm6Variant = $variant
  Set-LeaveHook {
    $afterRecovery = $(if ($script:xm6Variant -eq '관측') { 'transientRun' } else { 'fieldMisread' })
    Set-ScreenAfter 0 @((Step 1 'loading'), (Step 2 'matching'), (Step 175 'entryLoading'), (Step 181.4 $afterRecovery))
    $script:capWindow = @(((Elapsed) + 1.8), ((Elapsed) + 181.8))
  }
  Run-Member
  if ($variant -eq '관측') {
    Check-Equal "X-M6 (관측) 퇴장 로딩 뒤 캡처 실패 180초 중 자동 입장 → 복구 뒤 무장 해제 1('조작·캡처 실패') → 과도 3표본 → 첫 P committed(inside)·left 0 → 이월 → exit 0" (
      J @((Get-UnarmCount '조작·캡처 실패'), (Get-LeaveResults), (Get-FirstLeave).Screen, (Get-FirstPLeft), [int]($script:safeStopCalls -ge 1), $script:exitCode)) '1/committed,left/inside/0/1/0'
  } else {
    Check-Equal "X-M6 (변형 - 미관측 최악) 복구 뒤 오독 W 이상 → unconfirmed(Stage none·전송 1) → [경고] + exit 4 '(회차 미계상)', left 0·exit 0 0" (
      J @((Get-FirstLeave).Result, (Get-FirstLeave).Stage, (Get-FirstLeave).ExitSends, @(Get-WarningLines).Count, $script:exitCode, (Test-LastDone $pendingNoCount), (Get-FirstPLeft))) 'unconfirmed/none/1/1/4/1/0'
  }
}

# X-M7 퇴장 중 양보: G@CLEAR(LAST_RUN) + 보상 → 나가기 1 → 로딩 1표본 → 양보 20초
#   (a) 파티원은 필드 도착 → 양보 뒤 field 지속 → 'interrupt' 무장 해제 → 필드 모양 W 이상 → unconfirmed(Stage none·전송 1) → [경고] + exit 4 '(회차 미계상)' (퇴장 중 조작의 계상 손실 - 수용, D2)
#   (b) 양보 중 재매칭 자동 입장 → 양보 뒤 185237_205(입장 로딩) → 185241·185242(과도 field) → inside → left 0 → committed → 이월
Set-GClearReward
Set-LeaveHook { Set-ScreenAfter 0 @((Step 1 'loading'), (Step 5 'arrival'), (Step 6 'field')); $script:activeWindow = @(((Elapsed) + 1.8), ((Elapsed) + 21.8)) }
Run-Member
Check-Equal "X-M7(a) 퇴장 로딩 뒤 양보 20초 → 필드 도착 → 무장 해제 1 → 필드 모양 W → unconfirmed(Stage none·전송 1) → [경고] + exit 4 '(회차 미계상)'" (
  J @((Get-UnarmCount '조작·캡처 실패'), (Get-FirstLeave).Result, (Get-FirstLeave).Stage, (Get-FirstLeave).ExitSends, @(Get-WarningLines).Count, $script:exitCode, (Test-LastDone $pendingNoCount))) '1/unconfirmed/none/1/1/4/1'
Set-GClearReward
$script:transientSeq = @('transient1', 'transient2')
Set-LeaveHook { Set-ScreenAfter 0 @((Step 1 'loading'), (Step 2 'matching'), (Step 21.8 'entryLoading'), (Step 22.8 'transientRun')); $script:activeWindow = @(((Elapsed) + 1.8), ((Elapsed) + 21.8)) }
Run-Member
Check-Equal 'X-M7(b) 퇴장 로딩 뒤 양보 중 재매칭 자동 입장 → 입장 로딩·과도 2 → 첫 P committed(inside)·left 0 → 이월 → exit 0' (
  J @((Get-UnarmCount '조작·캡처 실패'), (Get-LeaveResults), (Get-FirstLeave).Screen, (Get-FirstPLeft), $script:exitCode)) '1/committed,left/inside/0/0'

# X-M8 스윕 안 양보: G@CLEAR(LAST_RUN) + 보상 → 나가기 1 → 로딩 1표본 → 스윕이 '닫기' 팝업에서 user-active 로 양보 20초 뒤 참(③ continue — 그 사이 모의 재매칭 자동 입장)
#      → 입장 로딩 → 과도 field 2 → inside → ③ 스윕 참 회전이 곧바로 무장을 풂(무장 해제 로그 1 — '팝업 정리', 생략 사유 'yield' 라 연속 수 그대로) → left 0 → committed → 이월
Set-GClearReward
Set-LeaveHook {
  Set-ScreenAfter 0 @((Step 1 'loading'))
  $script:xm8From = (Elapsed) + 1.8
  $script:sweepPlan = {
    if ((Elapsed) -ge $script:xm8From -and -not $script:xm8Done) {
      $script:xm8Done = $true
      Set-ScreenAfter 0 @((Step 0 'matching'), (Step 20 'entryLoading'), (Step 21.2 'transientRun'))   # 양보 20초 동안 재매칭 자동 입장 (관측 4)
      $script:yieldSeconds = 20
      return @{ Kind = 'ua-wait'; Gap = 0 }
    }
    $script:yieldSeconds = 3
    return $null
  }
}
$script:xm8Done = $false
Run-Member
Check-Equal "X-M8 스윕 안 양보 20초(user-active) → 스윕 참 회전이 무장 해제 1('팝업 정리') → 입장 로딩·과도 2 → 첫 P committed(inside)·left 0 → 이월 → exit 0" (
  J @((Get-UnarmCount '팝업 정리'), (Get-UnarmCount '조작·캡처 실패'), (Get-LeaveResults), (Get-FirstLeave).Screen, (Get-FirstPLeft), $script:sweepTrue, $script:exitCode)) '1/0/committed,left/inside/0/1/0'

# X-M9 전송 확인 밖 무장 변이 검출: G@CLEAR(LAST_RUN) + 보상, 나가기 첫 시도 cursor-not-ready(전송 없음·양보 없음) → 그 사이 파티장 나가기 이동(관측 4 18:48:08 —
#      파티원 입력 없이 로딩 → 필드) → Stage none → 로딩은 떠남이 아님 → 필드 모양 W 이상 → 'stayed'(필드 모양, 전송 0) → 진단 + exit 4 '…(필드 미확정, 회차 미계상)'
Set-GClearReward
$script:sendByPoint[$leavePoint] = @('cursor-not-ready')
Add-LogHook '나가기 클릭 건너뜀 \(커서 미확인 1/3\)' { Set-ScreenAfter 0 @((Step 0.3 'loading'), (Step 4.3 'arrival'), (Step 5.3 'field')) }   # 곧바로 파티장 나가기 이동 - 다음 회전은 이미 로딩(보상 재시도 없음)
Run-Member
Check-Equal "X-M9 나가기 생략(커서 미확인) 뒤 파티장 나가기 이동 → 전송 0 → 떠남 아님 → stayed(field) → exit 4 '…필드로 보이는 화면이라 … (필드 미확정, 회차 미계상)', left 0" (
  J @((Count-Click $leavePoint), $script:skippedCursor, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Get-FirstLeave).ExitSends, $script:exitCode,
    (Test-LastDone '필드로 보이는 화면이라 누르지 않고 마칩니다 \(필드 미확정, 회차 미계상\)$'), (Get-FirstPLeft))) '0/1/stayed/field/0/4/1/0'

# X-M10 스윕 반복 중 자동 입장 (리뷰 3차 P1-1 경로): G@CLEAR(LAST_RUN) + 보상 → 나가기 1 → 로딩 1표본(떠남) → 스윕 참 회전이 이어짐(생략 사유 '전송') —
#   (a) 3회 × 공백 4초 (b) 12회 × 1초 (c) P 마감까지 영구(미관측 — 종료 보장 확인). 한도 3 이라 (a)(b) 모두 3회째부터 굶김 회전.
#   그 사이 재매칭 11.5초(첫 스윕 회전과 함께 시작해 스윕 공백 안에 끝남 - 케이스 조건: 11.5 ≤ 0.7 + 12) → 스윕 끝 → 입장 로딩(185237_205) → 과도 field 2(185241·185242) → inside
#   (a)(b) 첫 스윕 참 회전이 무장을 풂('팝업 정리') → committed(inside) → 이월 → … → left → exit 0 / (c) 굶김 → P 마감 60초 → unconfirmed(Screen 'popup', 전송 1) → [경고] + exit 4 '(회차 미계상)'
$xm10 = @(@{ Name = '(a) 3회 × 4초'; Count = 3; Gap = 4 }, @{ Name = '(b) 12회 × 1초'; Count = 12; Gap = 1 }, @{ Name = '(c) 영구 (미관측 — 종료 보장 확인)'; Count = -1; Gap = 1 })
foreach ($variant in $xm10) {
  Set-GClearReward
  $script:transientSeq = @('transient1', 'transient2')
  $script:xm10 = $variant
  Set-LeaveHook {
    Set-ScreenAfter 0 @((Step 1 'loading'))
    $script:xm10From = (Elapsed) + 1.8
    $script:xm10Left = [int]$script:xm10.Count
    $script:sweepPlan = {
      if ((Elapsed) -ge $script:xm10From -and $script:xm10Left -ne 0) {
        if ($script:xm10Left -eq [int]$script:xm10.Count) { Set-ScreenAfter 0 @((Step 0 'matching'), (Step 11.5 'entryLoading'), (Step 13.5 'transientRun')) }   # 재매칭이 첫 스윕 회전과 함께 시작
        if ($script:xm10Left -gt 0) { $script:xm10Left-- }
        return @{ Kind = 'sent'; Gap = [double]$script:xm10.Gap }
      }
      return $null
    }
  }
  Run-Member
  if ($variant.Count -gt 0) {
    Check-Equal "X-M10$($variant.Name) 스윕 참 반복(굶김 포함) 중 자동 입장 → 무장 해제 1('팝업 정리') → 첫 P committed(inside)·left 0 → 이월 → exit 0" (
      J @((Get-UnarmCount '팝업 정리'), (Get-LeaveResults), (Get-FirstLeave).Screen, (Get-FirstPLeft), $script:exitCode, [int]($script:sweepTrue -eq $variant.Count))) '1/committed,left/inside/0/0/1'
  } else {
    $xm10Popup = Get-Label 'popup'
    Check-Equal "X-M10$($variant.Name) 굶김 → P 마감 60초 → unconfirmed(Screen popup·전송 1) → [경고] 라벨 '$xm10Popup' + exit 4 '(회차 미계상)', left 0·exit 0 0" (
      J @((Get-UnarmCount '팝업 정리'), (Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Get-FirstLeave).ExitSends, [int](@(Get-WarningLines | Where-Object { $_.Contains("($xm10Popup)") }).Count -eq 1),
        $script:exitCode, (Test-LastDone $pendingNoCount), (Get-FirstPLeft))) '1/unconfirmed/popup/1/1/4/1/0'
  }
}

# X-M8′ 판독 도중 캡처 실패 반복 중 자동 입장 (09-30 리뷰2): G@CLEAR(LAST_RUN) + 보상 → 나가기 1 → 로딩 1표본(떠남) → 반복 느린 실패 1초 × 8회전(회전마다 첫 판독이 실패를
#       등록하며 가상 1초, 같은 회전 뒤 판독은 성공 — 일련번호만 늘고 ① 동결 없음, ⑤ 에서 복구 회전(⑫ 마감만 + 700ms), 약 13.6초. 그 사이 재매칭 11.5초 → 입장 로딩 4초)
#       → 입장 과도 field 2 → inside. 케이스 조건: 재매칭 끝(11.5) < 복구 구간 끝(약 13.6) < 입장 로딩 끝(15.5) → 다음 유효 표본의 ⑥ 이 일련번호 차분으로 무장 해제
#       ('조작·캡처 실패') → left 0 → committed → 이월 (시간창 실패로 주입하면 다음 회전이 ① 로 가 변이가 생존 - 반복 느린 실패 모의가 필요)
Set-GClearReward
$script:transientSeq = @('transient1', 'transient2')
Set-LeaveHook {
  Set-ScreenAfter 0 @((Step 1 'loading'))
  $script:xm8pFrom = (Elapsed) + 1.8
  $script:xm8pLeft = 8
}
$script:xm8pFrom = 99999; $script:xm8pLeft = 0; $script:xm8pStart = -1
$script:failHook = {
  param($Name)
  if ($Name -eq 'prompt' -and (Elapsed) -ge $script:xm8pFrom -and $script:xm8pLeft -gt 0) {
    if ($script:xm8pLeft -eq 8) { $script:xm8pStart = Elapsed; Set-ScreenAfter 0 @((Step 0 'matching'), (Step 11.5 'entryLoading'), (Step 15.5 'transientRun')) }
    $script:xm8pLeft--
    return 1
  }
  return -1
}
Run-Member
$firstValidAfter = Get-FirstSampleAt 'entryLoading' $script:xm8pStart
Check-Equal "X-M8′ 반복 느린 실패 8회전(동결 0) 중 자동 입장 → 복구 뒤 첫 유효 표본 = 입장 로딩(케이스 조건) → 무장 해제 1('조작·캡처 실패') → 첫 P committed(inside)·left 0 → 이월 → exit 0" (
  J @($script:safeStopCalls, [int](($firstValidAfter - $script:xm8pStart) -gt 11.5 -and ($firstValidAfter - $script:xm8pStart) -lt 15.5), (Get-UnarmCount '조작·캡처 실패'), (Get-LeaveResults), (Get-FirstLeave).Screen, (Get-FirstPLeft), $script:exitCode)) '0/1/1/committed,left/inside/0/0'

# X-M11 (미관측 조합 — 모의로만) 무장 중 재펼침 탐침의 경합 (리뷰 4차 P1-1 경로): G@CLEAR(LAST_RUN) + 보상 → P(G) 첫 회전 보상 판독(패널 none) → 나가기 판독 뒤 전송 전
#        파티장 요청 도착('나가기'@515 가 패널 밖 클릭 = 접힘) → 전송 확인(leave-sent - Stage sent) → 다음 표본 접힘(readyKnown 거짓 - 무장 유지) → 탐침 전송 확인 →
#   (a) 탐침 자동 펼침(앵커가 '준비 완료', 준비됨 표본 없이 0.5초 뒤 입장 로딩 → 과도 field 2 → inside) → 'probe-sent' 무장 해제 1('접힌 패널 다시 펼침') → committed(inside)
#       → 이월 → INSIDE → 키 합 2 → -MemberMode 2 → 다음 경계 P(G) → left → exit 0. 첫 P 에서 left 0 · exit 0 0
#   (b) 자동 펼침 없음 — 탐침이 패널을 펼침(보상 위 readyAvail) → 무장 해제 1 → readyKnown → 접기 1 → 접힘 → 나가기 1(단어 492) → 로딩 → field 2 → left → exit 0
#       (탐침 1·접기 1·나가기 2(첫째는 접힘이 됨)·준비 0)
foreach ($variant in @('a', 'b')) {
  Set-GClearReward
  $script:xm11Variant = $variant
  $script:clickHook = {
    param($Point, $Screen)
    if ($Point -eq $leavePoint -and $Screen -eq 'memberReward' -and -not $script:xm11Leave) {
      $script:xm11Leave = $true   # 전송 순간 요청이 펼친 채 도착 - '나가기'@515 가 패널 밖 클릭 = 접힘 (2.1 표 '(492,654) on 보상 위 펼침 = 접기' 와 같은 자리 효과)
      Set-ScreenAfter 0.3 @((Step 0 'entryWaiting'))
      return $true
    }
    if ($Point -eq $anchorPoint -and $Screen -eq 'entryWaiting' -and -not $script:xm11Probe) {
      $script:xm11Probe = $true
      if ($script:xm11Variant -eq 'a') { Set-ScreenAfter 0.5 @((Step 0 'entryLoading'), (Step 2.2 'transientRun')) }   # 자동 펼침 → 앵커가 '준비 완료' → 2인 이동 (가장 나쁜 박자)
      else { Set-ScreenAfter 0.3 @((Step 0 'readyAvail')) }
      return $true
    }
    return $false
  }
  $script:xm11Leave = $false; $script:xm11Probe = $false
  Run-Member
  if ($variant -eq 'a') {
    Check-Equal "X-M11(a) (미관측 조합 — 모의로만) 무장 중 탐침 자동 펼침 → 무장 해제 1('접힌 패널 다시 펼침') → 첫 P committed(inside)·left 0 → 이월 → 키 합 2·-MemberMode 2 → left → exit 0" (
      J @((Get-UnarmCount '접힌 패널 다시 펼침'), (Get-LeaveResults), (Get-FirstLeave).Screen, (Get-FirstPLeft), $script:keys, $script:memberModeCalls, $script:exitCode)) '1/committed,left/inside/0/2/2/0'
  } else {
    Check-Equal 'X-M11(b) (미관측 조합 — 모의로만) 탐침이 패널을 펼침 → 무장 해제 1 → 접기 1 → 나가기(단어 492) 1 → left → exit 0 (탐침 1·@515 1·(492,654) 2·준비 0)' (
      J @((Get-UnarmCount '접힌 패널 다시 펼침'), (Count-Click $anchorPoint), (Count-Click $leavePoint), (Count-Click $collapsePoint), (Count-Click $readyPoint), (Get-LeaveResults), $script:exitCode)) '1/1/1/2/0/left/0'
  }
}

# ── §2-S. 스윕 참 회전의 생략 사유·굶김·재무장 예산 (㉺ - 09-30 리뷰2) ────────────
# '닫히지 않는 팝업'·'교대하는 팝업' 은 미관측이라 케이스 이름에 '(미관측 — 종료 보장 확인)' 을 붙입니다
$dStarveLog = "팝업이 닫히지 않고 ${memberSweepStreakLimit}회 이어집니다\(팝업 닫기 클릭 전송 또는 커서 미확인\)"
$pStarveLog = "팝업이 닫히지 않고 ${memberSweepStreakLimit}회 이어집니다 - 화면 판독 없이 나가기 확인 한도"
$popupLabel = Get-Label 'popup'
$captureLabel = Get-Label 'capture'
$reArmDone = '^\[완료\] 파티원: 던전 안으로 보이지만 입장 확인\(던전 안 2연속\)을 대기 한도 두 번 동안 이어받지 못해 마칩니다'
function Get-LogsBetween { param([double]$From, [double]$Until) @($script:logs | Where-Object { $t = [double](($_.Trim() -split '\s+')[0]); ($t -gt $From) -and ($t -lt $Until) }) }

# S1 (미관측 — 종료 보장 확인) D 굶김 — 팝업 지속 + 커서 미확인 영구: START unknown 10초 → 10초부터 스윕 매 회전 참(cursor-not-ready, 모의 스윕 1초) 영구 →
#    스윕 참 2회는 곧바로 다음 회전, 3회째 굶김 진입 로그 1 → 이후 판독 0·클릭 0·이벤트 정리 0 → M 600 → P 1 → P 도 굶김 → P 마감 60초 → 'stayed'(Screen popup) → exit 4.
#    정지 약 660초, 모의 스윕 호출 약 650회로 유한 (변이 '굶김 처리 제거' 면 호출 상한 VTIMEOUT)
Reset-Member -Plan @((P 0 'unknown'))
Set-SweepFrom -From 10 -Kind 'cursor' -Gap 1
Run-Member
$dStarveAt = @(Get-LogTimes $dStarveLog)
Check-Equal "S1 (미관측 — 종료 보장 확인) D 굶김: 3회째(약 12초) 굶김 진입 로그 1 · P 굶김 로그 1, 10초 뒤 판독 0·클릭 0·이벤트 정리 0, P 1 stayed(popup·전송 0) → exit 4 라벨 '$popupLabel'" (
  J @($dStarveAt.Count, [int](($dStarveAt[0] -ge 11.5) -and ($dStarveAt[0] -le 13.5)), (Count-Log $pStarveLog), @($script:promptReadTimes | Where-Object { $_ -ge 10 }).Count, $script:clicks.Count, $script:overlays,
    $script:pCalls.Count, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Get-FirstLeave).ExitSends, $script:exitCode, (Test-LastDoneContains "나갈 수 없는 화면이라($popupLabel) 누르지 않음"))) '1/1/1/0/0/0/1/stayed/popup/0/4/1'
Check-True "S1 정지 약 660초 (실제 $($script:el)) · 모의 스윕 호출 약 650회로 유한 (실제 $($script:sweepCalls)) · VTIMEOUT 없음" (
  ($script:el -ge 655) -and ($script:el -le 668) -and ($script:sweepCalls -ge 600) -and ($script:sweepCalls -le 700) -and ($script:threw -eq '')) (Get-Summary)

# S1′ (미관측 — 종료 보장 확인) S1 의 생략 사유를 '전송'(네트워크 불안정 팝업이 재접속 실패로 다시 뜨는 모양), 모의 스윕 3초 → 같은 종료, 모의 스윕 호출 약 220회 (변이 '전송은 미소모' 면 VTIMEOUT)
Reset-Member -Plan @((P 0 'unknown'))
Set-SweepFrom -From 10 -Kind 'sent' -Gap 3
Run-Member
Check-True "S1′ (미관측 — 종료 보장 확인) 전송 반복 3초 → exit 4 stayed(popup), 정지 약 660~670초 (실제 $($script:el)), 스윕 호출 약 220회 (실제 $($script:sweepCalls))" (
  ($script:exitCode -eq 4) -and ((Get-FirstLeave).Screen -eq 'popup') -and ($script:el -ge 655) -and ($script:el -le 672) -and ($script:sweepCalls -ge 200) -and ($script:sweepCalls -le 240)) (Get-Summary)

# S2 (미관측 — 종료 보장 확인) P 굶김: G@CLEAR(LAST_RUN) + 보상 → P(G) 첫 회전 보상 표본(나가기 시도는 cursor-not-ready 로 생략 — 전송 0) → 다음 회전부터 스윕 참 영구(cursor-not-ready) →
#    P 스윕 참 2회 뒤 굶김 → P 마감 60초 → 'stayed'(Screen popup, 전송 0) → exit 4 `[완료] 파티원: 마지막 회차(횟수 지정)지만 나갈 수 없는 화면이라(닫히지 않는 팝업 화면) 누르지 않고 마칩니다 (회차 미계상)`
#    (변이 '굶김 마감의 Screen 을 마지막 유효 화면으로' 면 라벨 '파티원 보상 화면' → FAIL - 추출한 Get-AbyssMemberScreenLabel 로 드러남)
Set-GClearReward
$script:sendByPoint[$leavePoint] = @('cursor-not-ready')
Add-LogHook '나가기 클릭 건너뜀 \(커서 미확인 1/3\)' { Set-SweepFrom -From (Elapsed) -Kind 'cursor' -Gap 1 }
Run-Member
$s2Done = "[완료] 파티원: 마지막 회차(횟수 지정)지만 나갈 수 없는 화면이라($popupLabel) 누르지 않고 마칩니다 (회차 미계상)"
Check-Equal "S2 (미관측 — 종료 보장 확인) P 굶김 → stayed(popup·전송 0) → exit 4 '$s2Done', 나가기 전송 0·left 0, 모의 스윕 호출 약 60회 (실제 $($script:sweepCalls))" (
  J @((Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Count-Click $leavePoint), (Count-Log $pStarveLog), $script:exitCode, [int]((Last-Done) -eq $s2Done), @(Get-LeaveLog).Count,
    [int](($script:sweepCalls -ge 50) -and ($script:sweepCalls -le 75)))) 'stayed/popup/0/1/4/1/0/1'

# S3 START 보상 + 스윕이 user-active 로 참 5회(위임 길 - 누적 없음, 다음 회전 ② 양보) 뒤 거짓 → 굶김 로그 0, 양보 동안 마감 판정 0, 이후 A2 와 같음(M 은 양보만큼 연장)
#    (변이 'user-active 도 소모' 면 굶김 로그 1 → FAIL)
Reset-Member -Plan @((P 0 'memberReward'))
Set-SweepFrom -From 0 -Kind 'ua-deleg' -Gap 1 -Count 5
Run-Member
Check-Equal "S3 스윕 user-active 5회(위임 - 다음 회전 ② 양보 5) → 굶김 로그 0 → M 은 양보만큼 연장 → A2 (나가기 1·left·exit 4)" (
  J @($script:sweepTrue, $script:yieldWaits, (Count-Log $dStarveLog), [int](($script:pCalls[0].At -ge $mLimit + $script:pCalls[0].YieldMs / 1000) -and ($script:pCalls[0].At -le $mLimit + $script:pCalls[0].YieldMs / 1000 + 1.5)),
    (Get-LeaveResults), $script:exitCode)) '5/5/0/1/left/4'

# S4 START 보상 + 스윕 참 5회가 모두 스윕 도중 캡처 실패(일련번호 증가, 같은 회전 복구 — 생략 사유 cursor-not-ready) 뒤 거짓 → 굶김 로그 0(다섯 회전은 복구 회전 - ⑨ 만 보고 700ms),
#    이후 A2 와 같음 (변이 '캡처 실패도 소모' 면 굶김 로그 1 → FAIL - 규칙 15)
Reset-Member -Plan @((P 0 'memberReward'))
Set-SweepFrom -From 0 -Kind 'recover' -Gap 1 -Count 5
Run-Member
Check-Equal 'S4 스윕 도중 실패→복구 5회(복구 회전 - 미소모) → 굶김 로그 0, 안전 확인 0, 이후 A2 (나가기 1·left·exit 4)' (
  J @($script:sweepTrue, (Count-Log $dStarveLog), $script:safeStopCalls, (Get-LeaveResults), $script:exitCode)) '5/0/0/left/4'

# S5 START 보상 + 스윕 '전송' 참 (한도−1) → 유효 표본 1 → 참 (한도−1) → 유효 표본 1 → 참 한도 → 유효 표본 → 앞 두 묶음은 굶김 0(유효 표본이 연속 수를 비움), 셋째 묶음 한도째
#    굶김 진입 로그 1 → 다음 유효 표본에서 해제 로그 1 (한도는 소스 캡처값 - 기대를 캡처값으로 다시 계산)
Reset-Member -Plan @((P 0 'memberReward'))
$s5Pattern = @(@('T') * ($sweepLimit - 1)) + @('F') + @(@('T') * ($sweepLimit - 1)) + @('F') + @(@('T') * $sweepLimit) + @('F')
$script:s5Seq = $s5Pattern; $script:s5Idx = 0; $script:s5StarveGroup = -1
$script:sweepPlan = { if ($script:s5Idx -lt $script:s5Seq.Count) { $x = $script:s5Seq[$script:s5Idx]; $script:s5Idx++; if ($x -eq 'T') { return @{ Kind = 'sent'; Gap = 1 } } }; return $null }
Add-LogHook $dStarveLog { $script:s5StarveGroup = $script:s5Idx }
Run-Member
Check-Equal "S5 스윕 참 묶음 $($sweepLimit - 1)·$($sweepLimit - 1)·$sweepLimit (사이 유효 표본) → 굶김 진입 1(셋째 묶음 $sweepLimit 번째 = 호출 $($s5Pattern.Count - 1)) · 해제 1" (
  J @((Count-Log $dStarveLog), $script:s5StarveGroup, (Count-Log '팝업이 사라져 화면 판독을 다시 시작합니다'))) (J @(1, ($s5Pattern.Count - 1), 1))

# S6 (미관측 — 2인 파티로 관측 불가 · 종료 보장 확인) 이월 틈의 굶김: LAST_RUN, CLEAR 경계 ready-done → 이월 전이(M 정지·준비 시계 초기화 — 두 시계 정지) → 곧바로 스윕 참 영구(cursor) →
#    굶김 회전이 M 을 재개(⑦′) → M 600 → ⑨ 서두 $pendingCount(이월)·G → P(G) → 굶김 → P 60초 → 'stayed'(popup) → exit 4 '(회차 미계상)' (변이 '굶김 회전 M Resume 누락' 이면 VTIMEOUT)
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyDone'))))
Add-LogHook '\(이월\)$' { Set-SweepFrom -From (Elapsed) -Kind 'cursor' -Gap 1 }
Run-Member
Check-Equal "S6 (미관측 — 2인 파티로 관측 불가 · 종료 보장 확인) 이월 틈 굶김 → M 재개 → P(G 'last-run') stayed(popup) → exit 4 '…나갈 수 없는 화면이라($popupLabel) … (회차 미계상)', VTIMEOUT 없음" (
  J @($script:pCalls[0].Reason, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode, [int]((Last-Done) -eq "[완료] 파티원: 마지막 회차(횟수 지정)지만 나갈 수 없는 화면이라($popupLabel) 누르지 않고 마칩니다 (회차 미계상)"), $script:threw)) 'last-run/stayed/popup/4/1/'

# S7 (미관측 — 종료 보장 확인) 다시 뜨는 팝업의 교대 — START 던전 안: 스윕 교대 모드(참 - '전송', 공백 3초 / 거짓 - 유효 inside 표본) 영구 → inside 2연속 없음 → M 600 → P 1 → 첫 유효
#    표본 inside → committed → 재무장 1 → M Set → 교대 계속 → M 600 → P 2 → committed(inside) → 예산 소진 → 진단 + exit 4 '던전 안으로 보이지만 …'(계상 대기 아님 — 꼬리 없음).
#    P 호출 정확히 2, 정지 약 1200~1210초, 키 0·INSIDE 전이 0 (변이 '재무장 예산 제거' 면 VTIMEOUT)
function Set-AlternateSweep { $script:altFlip = $false; $script:sweepPlan = { $script:altFlip = -not $script:altFlip; if ($script:altFlip) { return @{ Kind = 'sent'; Gap = 3 } }; return $null } }
Reset-Member -Plan @((P 0 'inside'))
Set-AlternateSweep
Run-Member
Check-Equal "S7 (미관측 — 종료 보장 확인) START 던전 안 + 교대 팝업 → P 2(committed ×2) → 재무장 예산 소진 exit 4 (꼬리 없음), 키 0·INSIDE 0" (
  J @($script:pCalls.Count, (Get-LeaveResults), $script:exitCode, (Test-LastDone ($reArmDone + '$')), $script:keys, (Count-Log '던전 입장 완료 감지'), [int]($script:diag -contains '파티원 던전 안 확인 반복 실패|True'))) '2/committed,committed/4/1/0/0/1'
Check-True "S7 정지 약 1200~1215초 (실제 $($script:el)), 스윕 호출 유한 (실제 $($script:sweepCalls))" (($script:el -ge 1200) -and ($script:el -le 1215) -and ($script:sweepCalls -lt 5000)) (Get-Summary)

# S8 (미관측 — 종료 보장 확인) S7 의 CLEAR 판: 'clear' → 다음 판 입장(모의) 뒤 같은 교대(G 없음) → M 600 → P → committed(inside) → M 600 → P → committed → 예산 소진 →
#    exit 4 같은 문구 + ' (회차 미계상)'. P 호출 정확히 2, exit 0 0.
#    짝 변형(G = LAST_RUN): 첫 만료 P(G) committed(inside) → 이월 전이(예산 0 으로) → START 이월 교대 → 만료 P(G) 2·3 → 예산 소진 → exit 4 '(회차 미계상)', P 호출 정확히 3
foreach ($lastRun in @($false, $true)) {
  Reset-Member -Plan @((P 0 'inside'))
  $script:dgLastRun = $lastRun
  $script:clearPlan = @(@{ Return = 'clear'; Steps = @((Step 0 'inside')); Advance = 60; Hook = { Set-AlternateSweep } })
  Run-Member
  if (-not $lastRun) {
    Check-Equal "S8 (미관측 — 종료 보장 확인) CLEAR 판 교대 → P 2(committed ×2) → exit 4 '던전 안으로 보이지만 … (회차 미계상)', exit 0 0" (
      J @($script:pCalls.Count, (Get-LeaveResults), $script:exitCode, (Test-LastDone ($reArmDone + ' \(회차 미계상\)$')))) '2/committed,committed/4/1'
  } else {
    Check-Equal "S8 짝 변형 (G = 마지막 회차) 첫 만료 P(G) committed → 이월(예산 0) → 만료 P(G) 2·3 → 예산 소진 exit 4 '(회차 미계상)', P 호출 정확히 3" (
      J @($script:pCalls.Count, (Get-LeaveResults), (Count-Log '\(이월\)$'), $script:exitCode, (Test-LastDone ($reArmDone + ' \(회차 미계상\)$')))) '3/committed,committed,committed/1/4/1'
  }
}

# S8′ (미관측 — 종료 보장 확인) 재무장 1 을 안고 이월: S8 의 CLEAR 판 교대(G 없음) → M 600 → P('member-timeout') committed(inside) → 재무장 1 → 그 P 동안 F9 →
#     M 600 → P(G 'safe-stop') committed(inside) → 이월 전이(재무장 예산 0 으로) → START 이월 교대 → 만료 P(G) 두 번(재무장 1 → 2) → 예산 소진 → exit 4 '(회차 미계상)'.
#     P 호출 정확히 4, 소비 0(퇴장 방향 전송 없음 - 예약 파일 유지). S8 짝 변형은 이월 앞 재무장이 0 이라(계상 대기 G 의 committed 는 재무장을 세지 않고 이월)
#     '이월 전이에서 재무장 예산을 비우지 않음' 변이와 행동이 같았습니다 - 이 케이스는 이월 앞 재무장이 1 이라 그 변이면 이월 뒤 첫 만료에서 소진(P 3)으로
#     드러납니다 (변이 검증 2026-10-01 - 그 변이는 §3 재무장 예산 0 대입 자리 단언만 잡았음)
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @(@{ Return = 'clear'; Steps = @((Step 0 'inside')); Advance = 60; Hook = { Set-AlternateSweep } })
Add-LogHook '파티장의 다음 입장이 \d+초\(클리어 대기 설정\) 안에 없습니다 - 나가기로 필드에 나온 뒤 마칩니다' { $script:safeStopFlag = $true }
Run-Member
Check-Equal "S8′ (미관측 — 종료 보장 확인) CLEAR 판 교대 → P('member-timeout') committed(재무장 1) → F9 → P(G) committed → 이월(예산 0) → 만료 P(G) 2번 → 예산 소진 exit 4 '(회차 미계상)', P 호출 정확히 4·소비 0" (
  J @($script:pCalls.Count, (@($script:pCalls | ForEach-Object { $_.Reason }) -join ','), (Get-LeaveResults), (Count-Log '\(이월\)$'), $script:removes, $script:exitCode,
    (Test-LastDone ($reArmDone + ' \(회차 미계상\)$')))) '4/member-timeout,safe-stop,safe-stop,safe-stop/committed,committed,committed,committed/1/0/4/1'

# S9 (미관측 — 종료 보장 확인) CLEAR 경계 굶김의 준비 시계: 'clear' → 경계 신호 보상 위 readyAvail(G 없음) → 경계 준비 클릭 cursor-not-ready 1회 → 다음 회전부터 스윕 참 영구(cursor)
#   (a) 굶김 회전이 M 을 전체에서 재개, 준비 시계는 계속 → 준비 시계 300 이 먼저 → P('ready-timeout') → 굶김 → 60초 → 'stayed'(popup) → exit 4 '준비 패널 뒤 300초 안에 … (준비 상태는
#       그대로 둡니다)'(라벨 자리 없음 - 2.9 예외), P 호출 1, 준비 전송 0
#   (b) P 가 불리는 순간 팝업이 사라지고 재매칭(토글 ON 자동 입장 모의) → P 첫 유효 표본 matching → committed → 준비 시계 폐기·에피소드 종료·M Set → continue → 스윕 참 1회(D 연속 수는 굶김
#       그대로라 곧바로 굶김 회전 - ⑨ 를 봄) → 유효 표본 matching → 경계 인계 exit 0 '재매칭 중인 다음 판'. P 호출 정확히 1
foreach ($variant in @('a', 'b')) {
  Reset-Member -Plan @((P 0 'inside'))
  $script:clearPlan = @((Clear-Spec 'ready'))
  $script:sendByPoint[$readyPoint] = @('cursor-not-ready')
  Add-LogHook "'준비 완료' 클릭 건너뜀 \(커서 미확인 1/3\)" { Set-SweepFrom -From (Elapsed) -Kind 'cursor' -Gap 1 }
  if ($variant -eq 'b') {
    Add-LogHook '준비 패널 뒤 \d+초 안에 입장이 없습니다 - 대기를 마칩니다' {
      Set-ScreenAfter 0 @((Step 0 'matching'))
      $script:s9bAfter = $false
      $script:sweepPlan = {
        if ($script:pCalls.Count -ge 1 -and $null -ne $script:pCalls[0].Result -and -not $script:s9bAfter) { $script:s9bAfter = $true; return @{ Kind = 'cursor'; Gap = 1 } }   # P 뒤 스윕 참 1회
        return $null
      }
    }
  }
  Run-Member
  if ($variant -eq 'a') {
    Check-Equal "S9(a) (미관측 — 종료 보장 확인) 경계 준비 생략 뒤 굶김 → 준비 시계 먼저 → P('ready-timeout') stayed(popup) → exit 4 '…(준비 상태는 그대로 둡니다)', P 1, 준비 전송 0" (
      J @($script:pCalls.Count, $script:pCalls[0].Reason, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode, (Test-LastDone '^\[완료\] 준비 패널 뒤 \d+초 안에 입장이 없어 파티원 대기를 마칩니다 \(준비 상태는 그대로 둡니다\)$'),
        (Count-Click $readyPoint))) '1/ready-timeout/stayed/popup/4/1/0'
  } else {
    Check-Equal "S9(b) (미관측 — 종료 보장 확인) 준비 시계 P 순간 재매칭 → committed → 준비 시계 폐기 → 굶김 1회 뒤 재매칭 표본 → 경계 인계 exit 0 '재매칭 중인 다음 판', P 호출 정확히 1" (
      J @($script:pCalls.Count, (Get-LeaveResults), $script:exitCode, (Test-LastDone '재매칭 중인 다음 판을 다음 워커가 이어받습니다$'))) '1/committed/0/1'
  }
}

# ── §2-RC. 같은 회전 복구·교대 모양의 복구 회전 (㉻ - 09-30 리뷰3) ─────────────
# 모두 미관측 조합(RC5 는 '시계 불변 확인', 나머지는 '종료 보장 확인'). VTIMEOUT·판독/스윕 호출 상한 0, 복구 구간의 클릭·이벤트 정리·예산 소모 0,
# 동결 블록(안전 확인 호출)은 같은 회전 복구(RC1~RC7)에서 0, 교대 모양(RC8·RC9)에서 1 이상. 정지 시각은 '가상 경과 − 누적 실패 시간' 으로 단언합니다
function Get-PDurationAdjusted { param($Entry) [Math]::Round(($Entry.EndAt - $Entry.At) - ($Entry.EndFailMs - $Entry.FailMs) / 1000.0, 1) }

# RC1 (미관측 — 종료 보장 확인) D 의 ④ 판독 도중 복구 영구: START unknown 20초 → 20초부터 매 회전 ④ 첫 판독이 실패 등록 + 가상 1초 → 뒤 판독(패널)이 복구 →
#     20초 뒤 분류·클릭·연속 수 변화 0, 동결 0, 이벤트 정리 0 → M 은 실패 시간을 뺀 600초 → P 1 → P 도 복구 회전 → 60초 → 'stayed'(capture) → exit 4 (라벨 '판독 도중 캡처가 끊기는 화면')
Reset-Member -Plan @((P 0 'unknown'))
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge 20) { return 1 } return -1 }
Run-Member
Check-Equal "RC1 (미관측 — 종료 보장 확인) D ④ 판독 도중 복구 영구 → 20초 뒤 D 로그·클릭·이벤트 정리 0, 안전 확인 0, P 1 stayed(capture·전송 0) → exit 4 라벨 '$captureLabel'" (
  J @(@(Get-LogsBetween 20.5 $script:pCalls[0].At).Count, $script:clicks.Count, $script:overlays, $script:safeStopCalls, (Count-Log $dStarveLog), $script:pCalls.Count, (Get-FirstLeave).Result, (Get-FirstLeave).Screen,
    $script:exitCode, (Test-LastDoneContains "나갈 수 없는 화면이라($captureLabel) 누르지 않음"), $script:threw)) '0/0/0/0/0/1/stayed/capture/4/1/'
Check-True "RC1 (가상 경과 − 누적 실패) = M + P 한도 ± 3 = $($mLimit + $memberLeaveLimitSeconds) (실제 $(Get-AdjustedStop))" ([Math]::Abs((Get-AdjustedStop) - ($mLimit + $memberLeaveLimitSeconds)) -le 3) (Get-Summary)

# RC2 (미관측 — 종료 보장 확인) D 의 스윕 도중 복구 영구: START 보상 10초 → 10초부터 스윕 매 회전 참(cursor)이고 그 스윕 안에서 실패 → 1초 → 복구(영구) → 스윕 연속 수 불변(굶김 로그 0),
#     10초 뒤 판독 0, M 600(실패 제외) → P → P 도 스윕 도중 복구('sweep' — 무장이 없어 무장 해제 로그 0) → 60초 → 'stayed'(capture) → exit 4 (변이 '복구를 소모' 면 굶김 로그·popup)
Reset-Member -Plan @((P 0 'memberReward'))
Set-SweepFrom -From 10 -Kind 'recover' -Gap 1
Run-Member
Check-Equal "RC2 (미관측 — 종료 보장 확인) 스윕 도중 복구 영구 → 굶김 로그 0, 10초 뒤 판독 0, 무장 해제 로그 0, 안전 확인 0, P stayed(capture) → exit 4" (
  J @((Count-Log '팝업이 닫히지 않고'), @($script:promptReadTimes | Where-Object { $_ -ge 10 }).Count, (Count-Log '나가기 뒤 화면 전이가 끊겼습니다'), $script:safeStopCalls, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode)) '0/0/0/0/stayed/capture/4'
Check-True "RC2 (가상 경과 − 누적 실패) = 660 ± 3 (실제 $(Get-AdjustedStop))" ([Math]::Abs((Get-AdjustedStop) - ($mLimit + $memberLeaveLimitSeconds)) -le 3) (Get-Summary)

# RC3 (미관측 — 종료 보장 확인) D 의 CLEAR 경계 재펼침 클릭 직전 판독 복구 영구: 'clear' → 접힘(entry-waiting 영구) + 클릭 직전 새 단어 판독이 매번 실패 → 1초 → 뒤이은 패널 판독이 복구
#     (P 탐침의 클릭 직전 판독도 같음) → 재펼침 전송 0, 불일치 로그 0, $boundaryReadFailed 로 ⑨ 를 봄 → M 은 반환 뒤 600초(실패 제외) → P 1 → P 탐침 0 → P 60 → 'stayed'(entry-waiting) → exit 4
Reset-Member -Plan @((P 0 'inside'))
$script:clearPlan = @((Clear-Spec 'entry-waiting'))
$script:failHook = { param($Name) if ($Name -eq 'words') { return 1 } return -1 }
Run-Member
$rc3M = ($script:pCalls[0].At - $script:clearReturnTimes[0]) - ($script:pCalls[0].FailMs / 1000.0)
Check-Equal "RC3 (미관측 — 종료 보장 확인) 경계 재펼침 직전 판독 복구 영구 → 재펼침 0, 불일치 로그 0, '위치를 확인하지 못해' 0, P(G 없음) stayed(entry-waiting·전송 0) → exit 4 라벨 '접힌 준비 패널', M = 반환 뒤 600(실패 제외 - 실제 $([Math]::Round($rc3M, 1)))" (
  J @((Count-Click $anchorPoint), (Count-Log '재펼침 건너뜀'), (Count-Log '위치를 확인하지 못해'), $script:pCalls[0].Reason, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Get-FirstLeave).ExitSends, $script:exitCode,
    (Test-LastDoneContains "나갈 수 없는 화면이라($(Get-Label 'entry-waiting')) 누르지 않음"), [int](($rc3M -ge $mLimit - 0.05) -and ($rc3M -le $mLimit + 1.5)), $script:threw)) '0/0/0/member-timeout/stayed/entry-waiting/0/4/1/1/'

# RC4 (미관측 — 2인 파티로 관측 불가 · 종료 보장 확인) D 의 이월 틈 복구 영구: LAST_RUN, CLEAR 경계 ready-done → 이월(두 시계 정지) → 곧바로 매 회전 ④ 판독 복구(영구) →
#     첫 복구 회전의 ⑦″ 가 두 시계 정지를 보고 M 재개 → M 600(실패 제외) → P(G) 1 → 복구 회전 → 60 → 'stayed'(capture) → exit 4 '…나갈 수 없는 화면이라(판독 도중 캡처가 끊기는 화면) … (회차 미계상)'
Reset-Member -Plan @((P 0 'inside'))
$script:dgLastRun = $true
$script:clearPlan = @((Clear-Spec 'ready' @((Step 0 'readyDone'))))
$script:rc4From = 99999
Add-LogHook '\(이월\)$' { $script:rc4From = Elapsed }
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge $script:rc4From) { return 1 } return -1 }
Run-Member
Check-Equal "RC4 (미관측 — 2인 파티로 관측 불가 · 종료 보장 확인) 이월 틈 복구 영구 → M 재개 → P(G) stayed(capture) → exit 4 '[완료] 파티원: 마지막 회차(횟수 지정)지만 나갈 수 없는 화면이라($captureLabel) 누르지 않고 마칩니다 (회차 미계상)'" (
  J @($script:pCalls.Count, $script:pCalls[0].Reason, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode, [int]((Last-Done) -eq "[완료] 파티원: 마지막 회차(횟수 지정)지만 나갈 수 없는 화면이라($captureLabel) 누르지 않고 마칩니다 (회차 미계상)"), $script:threw)) '1/last-run/stayed/capture/4/1/'

# RC5 (미관측 — 시계 불변 확인) D 의 준비 에피소드 중 복구 구간: START ready-other(cap_210545_900 - 클릭 0) 0~10초 → 10~260초 매 회전 ④ 판독 복구 → 260초부터 member-reward(M5) →
#     복구 구간 동안 P 0(준비 시계 조정 경과 = 260 − F < 300), 에피소드 첫 관측의 M 초기화 값 보존(복구 회전은 M 을 재개하지 않음) → 보상에서 준비 시계 폐기(M5 로그 1)·M 재개 →
#     P('member-timeout') 서두 가상 경과 = 260 + 600 = 860 ± 3초 (조정 = 860 − F ≈ 713) → 나가기 → left → exit 4 (변이 '복구 회전도 M 재개' 면 약 757초 → FAIL)
Reset-Member -Plan @((P 0 'readyOther'), (P 260 'memberReward'))
$script:keepPlan = $true
$script:rc5F = -1
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge 10 -and (Elapsed) -lt 260) { return 1 } return -1 }
$script:readHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge 260 -and $script:rc5F -lt 0) { $script:rc5F = (Get-CaptureFailTotalMs) / 1000.0 } }
Run-Member
Check-Equal "RC5 (미관측 — 시계 불변 확인) 준비 에피소드 중 복구 구간 → 그동안 P 0, M5 로그 1, P('member-timeout') 서두 = 260 + $mLimit ± 3 (실제 $($script:pCalls[0].At)), F ≈ 147 (실제 $([Math]::Round($script:rc5F, 1))), 조정 = 기대 − F, left → exit 4" (
  J @(@($script:pCalls | Where-Object { $_.At -lt 260 }).Count, (Count-Log '준비 패널이 사라졌습니다\(입장 시작 또는 파티장 취소\)'), $script:pCalls[0].Reason, [int]([Math]::Abs($script:pCalls[0].At - (260 + $mLimit)) -le 3),
    [int](($script:rc5F -ge 140) -and ($script:rc5F -le 155)), [int]([Math]::Abs(($script:pCalls[0].At - $script:rc5F) - (260 + $mLimit - $script:rc5F)) -le 3), [int]($script:clicks.Count -ge 1), (Get-LeaveResults), $script:exitCode)) '0/1/member-timeout/1/1/1/1/left/4'

# RC6 (미관측 — 종료 보장 확인) P 의 ④ 판독 도중 복구 영구: G@CLEAR(LAST_RUN) + 보상 → P(G) 첫 회전 유효(보상) → 나가기 1(무장) → 다음 회전부터 P 의 ④ 첫 판독 복구(영구) →
#     나가기 재클릭 0, left 0, P 마감 60초(실패 제외, P 시작 기준) → 'unconfirmed'(capture, 전송 1) → [경고] 라벨 '판독 도중 캡처가 끊기는 화면' + exit 4 '…나가기 뒤 필드를 확인하지 못해 마칩니다 (회차 미계상)'
$rc6Done = '[완료] 파티원: 마지막 회차(횟수 지정) - 나가기 뒤 필드를 확인하지 못해 마칩니다 (회차 미계상)'
Set-GClearReward
$script:rcFrom = 99999
Set-LeaveHook { Set-ScreenAfter 0 $script:afterLeave; $script:rcFrom = (Elapsed) + 0.1 }
$script:failHook = { param($Name) if ($Name -eq 'prompt' -and (Elapsed) -ge $script:rcFrom) { return 1 } return -1 }
Run-Member
Check-Equal "RC6 (미관측 — 종료 보장 확인) P 나가기 뒤 ④ 판독 도중 복구 영구 → 재클릭 0·left 0 → unconfirmed(capture·전송 1) → [경고] 라벨 '$captureLabel' + exit 4 '$rc6Done'" (
  J @(@($script:clickAttempts | Where-Object { [double]($_ -split '@')[1] -gt $script:rcFrom }).Count, @(Get-LeaveLog).Count, (Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Get-FirstLeave).ExitSends,
    [int](@(Get-WarningLines | Where-Object { $_.Contains("($captureLabel)") }).Count -eq 1), $script:exitCode, [int]((Last-Done) -eq $rc6Done), $script:safeStopCalls)) '0/0/unconfirmed/capture/1/1/4/1/0'
Check-True "RC6 P 마감 = P 시작 + 60 (실패 제외) ± 3 (실제 $(Get-PDurationAdjusted $script:pCalls[0]))" ([Math]::Abs((Get-PDurationAdjusted $script:pCalls[0]) - $memberLeaveLimitSeconds) -le 3) (Get-Summary)

# RC7 (미관측 — 종료 보장 확인) P 의 스윕 도중 복구 영구: RC6 과 같되 나가기 뒤 매 회전 스윕이 참(cursor)이고 그 안에서 실패 → 복구 → 첫 스윕 참 회전의 'sweep' 이 무장을 풂
#     (무장 해제 로그 1 - '팝업 정리'), 이후 복구 회전 → P 60 → 'unconfirmed'(capture, 전송 1) → [경고] + exit 4 '(회차 미계상)' (변이 '복구를 소모' 면 3회째 굶김 → popup)
Set-GClearReward
Set-LeaveHook { Set-ScreenAfter 0 $script:afterLeave; Set-SweepFrom -From ((Elapsed) + 0.1) -Kind 'recover' -Gap 1 }
Run-Member
Check-Equal "RC7 (미관측 — 종료 보장 확인) P 나가기 뒤 스윕 도중 복구 영구 → 무장 해제 1('팝업 정리'), 굶김 로그 0 → unconfirmed(capture·전송 1) → [경고] + exit 4 '(회차 미계상)'" (
  J @((Get-UnarmCount '팝업 정리'), (Count-Log '팝업이 닫히지 않고'), (Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Get-FirstLeave).ExitSends, @(Get-WarningLines).Count, $script:exitCode, (Test-LastDone $pendingNoCount), $script:safeStopCalls)) '1/0/unconfirmed/capture/1/1/4/1/0'

# RC8 (미관측 — 종료 보장 확인) D 의 교대 모양 영구: START unknown 20초 → 20초부터 교대 실패(회전의 마지막 캡처인 HUD 판독이 실패 → 분기점까지 이어짐 → 다음 회전 ① 탐침이 복구) →
#     20초 뒤 D 변화·클릭 0, ① 동결 회전마다 안전 확인(≥ 1)·탐침 복구 → 표식 → 복구 회전(스윕 0·판독 0 - ⑨ + 700ms), 이벤트 정리 0 → M 은 실패를 뺀 600초 → P 1 → P 도 교대 →
#     P 마감 60초 → 'stayed'(capture, 전송 0) → exit 4 (변이 '① 의 표식 대입 제거' 면 VTIMEOUT)
Reset-Member -Plan @((P 0 'unknown'))
$script:failHook = { param($Name) if ($Name -eq 'hud' -and (Elapsed) -ge 20) { $script:persistFail = $true; return 0 } return -1 }
Run-Member
Check-Equal "RC8 (미관측 — 종료 보장 확인) D 교대 모양 영구 → 20초 뒤 D 로그·클릭·이벤트 정리 0, 안전 확인 ≥ 1 = 탐침 수, P 1 stayed(capture·전송 0) → exit 4 라벨 '$captureLabel', VTIMEOUT 없음" (
  J @(@(Get-LogsBetween 20.5 $script:pCalls[0].At).Count, $script:clickAttempts.Count, $script:overlays, [int]($script:safeStopCalls -ge 1), [int]($script:safeStopCalls -eq $script:probeCalls), $script:pCalls.Count,
    (Get-FirstLeave).Result, (Get-FirstLeave).Screen, $script:exitCode, (Test-LastDoneContains "나갈 수 없는 화면이라($captureLabel) 누르지 않음"), $script:threw)) '0/0/0/1/1/1/stayed/capture/4/1/'
Check-True "RC8 (가상 경과 − 누적 실패) = 660 ± 3 (실제 $(Get-AdjustedStop))" ([Math]::Abs((Get-AdjustedStop) - ($mLimit + $memberLeaveLimitSeconds)) -le 3) (Get-Summary)

# RC9 (미관측 — 종료 보장 확인) P 의 교대 모양 영구: G@CLEAR(LAST_RUN) + 보상 → P(G) 첫 회전 유효 → 나가기 1(무장) → 다음 회전부터 P 에 교대 실패(HUD 실패 → 다음 회전 ① 탐침 복구) →
#     나가기 재클릭 0, left 0, 표식 회전마다 ⑫ + 700ms → P 마감 60초(실패 제외) → 'unconfirmed'(capture, 전송 1) → [경고] + exit 4 '…나가기 뒤 필드를 확인하지 못해 마칩니다 (회차 미계상)'
Set-GClearReward
$script:rcFrom = 99999
Set-LeaveHook { Set-ScreenAfter 0 $script:afterLeave; $script:rcFrom = (Elapsed) + 0.1 }
$script:failHook = { param($Name) if ($Name -eq 'hud' -and (Elapsed) -ge $script:rcFrom) { $script:persistFail = $true; return 0 } return -1 }
Run-Member
Check-Equal "RC9 (미관측 — 종료 보장 확인) P 나가기 뒤 교대 모양 영구 → 재클릭 0·left 0, 안전 확인 ≥ 1 → unconfirmed(capture·전송 1) → [경고] + exit 4 '$rc6Done'" (
  J @(@($script:clickAttempts | Where-Object { [double]($_ -split '@')[1] -gt $script:rcFrom }).Count, @(Get-LeaveLog).Count, [int]($script:safeStopCalls -ge 1), (Get-FirstLeave).Result, (Get-FirstLeave).Screen, (Get-FirstLeave).ExitSends,
    [int](@(Get-WarningLines | Where-Object { $_.Contains("($captureLabel)") }).Count -eq 1), $script:exitCode, [int]((Last-Done) -eq $rc6Done))) '0/0/1/unconfirmed/capture/1/1/4/1'
Check-True "RC9 P 마감 = P 시작 + 60 (실패 제외) ± 3 (실제 $(Get-PDurationAdjusted $script:pCalls[0]))" ([Math]::Abs((Get-PDurationAdjusted $script:pCalls[0]) - $memberLeaveLimitSeconds) -le 3) (Get-Summary)

# RC10 (D — 캡처 실패 + 유한 조작, 09-30 리뷰5 P2-1): START 보상(G 없음 - 대기), 시간창 캡처 실패 [100, 400)초·조작 [200, 500)초 → 실패 동안 ① 동결 회전마다 탐침 1(탐침 = 안전 확인),
#      실패 창 안 캡처 시도 최대 간격 ≤ 2.5초, 실패 중 양보 0·클릭 0, 복구 뒤 ② 양보 1(약 100초) → 표식 회전 → P('member-timeout') 서두 = 600 + 실패(약 300) + 양보(약 100) = 1000 ± 5 →
#      나가기 → 로딩 → left → exit 4 (변이 '① 을 ② 뒤로' 면 조작 동안 캡처 0 - 간격 약 300초·서두 약 1300초)
Reset-Member -Plan @((P 0 'memberReward'))
$script:capWindow = @(100, 400)
$script:activeWindow = @(200, 500)
Run-Member
Check-Equal "RC10(a) 캡처 실패 [100,400) + 조작 [200,500): 탐침 = 안전 확인(≥ 1), 실패 창 캡처 최대 간격 $(Get-MaxCaptureGap 100 400) ≤ 2.5, 실패 중 양보·클릭 0, 양보 1, P 서두 1000 ± 5 (실제 $($script:pCalls[0].At)), left → exit 4" (
  J @([int](($script:probeCalls -ge 1) -and ($script:probeCalls -eq $script:safeStopCalls)), [int]((Get-MaxCaptureGap 100 400) -le 2.5), @($script:yieldTimes | Where-Object { $_ -ge 100 -and $_ -lt 400 }).Count,
    @($script:clickTimes | Where-Object { $_ -ge 100 -and $_ -lt 400 }).Count, $script:yieldWaits, [int]([Math]::Abs($script:pCalls[0].At - 1000) -le 5), (Get-LeaveResults), $script:exitCode)) '1/1/0/0/1/1/left/4'

# RC10(b) 공용 스윕 첫 판독에서 실패 시작 + 커서 위 조작 (운영 스윕 추출 - 반영본 검증, 09-30 리뷰5): START 보상, 100초 회전의 스윕 첫 판독(재시작 팝업)이 실패 창 [100, 400)의 첫 실패를
#      등록(느린 실패 1초 - 스윕 안에서 101초), 조작 창 [100.5, 300)(② 게이트가 본 뒤·스윕 안에서 시작) → 스윕은 첫 판독 뒤 곧바로 거짓 — 실패 창 안 커서 대피·'닫기' 탐색·하단 판독 0,
#      실패 창 캡처 최대 간격 ≤ 2.5초, 실패 중 양보 0, 복구(≈400초) 때 조작은 끝나 양보 0 → P 서두 = 600 + 실패(약 300) = 약 900 ± 5 → left → exit 4
#      (변이 '스윕 첫 판독 가드 제거' 면 커서 대피가 [101, 300) 캡처 없이 기다려 양보 약 199초가 실패와 겹쳐 이중 연장 → 서두 약 1100)
$rgPopupClose = @(0, 0, 10, 10)
function Test-GameRestartPopup { param($Game)
  if ($script:restartArm -gt 0 -and (Elapsed) -ge $script:restartArm -and -not $script:restartArmed) {
    $script:restartArmed = $true
    $script:capWindow = @($script:restartArm, $script:restartWindowEnd)
    $script:activeWindow = @(($script:restartArm + 0.5), $script:restartActiveEnd)
    Register-MockFail; Tick 1
    return $false
  }
  [void](Read-Guard 'restart')
  return $false
}
function Move-CursorOutsideGame { param($Game)
  # 운영 3119~3131 흉내: 커서가 게임 위(모의 상수 참)이고 조작 창 안이면 창 끝까지 캡처 없이 기다리고 그만큼 양보 누적 (호출 수를 셈)
  $script:cursorParkCalls++
  if ($script:screenCaptureFailing) { $script:cursorParkInFail++ }
  if (In-Window $script:activeWindow) { Wait-UserYieldEnd -Game $Game -Context '커서 대피' }
}
function Find-GameTextPoint { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText) if (In-Window $script:capWindow) { $script:sweepInnerInFail++ }; [void](Read-Guard 'find'); return $null }
function Get-GameOcrText { param($Game) if (In-Window $script:capWindow) { $script:sweepInnerInFail++ }; [void](Read-Guard 'bottom'); return '' }
function Close-QuestRewardScreen { param($Game, $LogPrefix, $BottomText) return $false }
function Close-CoopMissionScreen { param($Game, $LogPrefix) return $false }
function Close-CoopMissionBoardScreen { param($Game, $LogPrefix) return $false }
function Close-WeeklyCoopResetPopup { param($Game, $LogPrefix) return $false }
function Close-NetworkUnstablePopup { param($Game, $LogPrefix) return $false }
function Click-ScreenPoint { param($X, $Y) $script:lastClickPerformed = $true; $script:lastClickSkipReason = '' }
Reset-Member -Plan @((P 0 'memberReward'))
$script:useRealSweep = $true
$script:restartArm = 100; $script:restartWindowEnd = 400; $script:restartActiveEnd = 300; $script:sweepInnerInFail = 0
Run-Member
Check-Equal "RC10(b) 운영 공용 스윕 첫 판독 실패 + 커서 위 조작 → 스윕 곧바로 거짓(실패 창 안 커서 대피 0·'닫기' 탐색·하단 판독 0), 캡처 최대 간격 $(Get-MaxCaptureGap 100 400) ≤ 2.5, 양보 0, P 서두 약 900 ± 5 (실제 $($script:pCalls[0].At)), left → exit 4" (
  J @($script:cursorParkInFail, $script:sweepInnerInFail, [int]((Get-MaxCaptureGap 100 400) -le 2.5), $script:yieldWaits, [int]([Math]::Abs($script:pCalls[0].At - 900) -le 5), (Get-LeaveResults), $script:exitCode, [int]($script:cursorParkCalls -ge 50))) '0/0/1/0/1/left/4/1'
$script:restartArm = 0

# RC11 (P — 같은 시험, 09-30 리뷰5 P2-1): G@CLEAR(LAST_RUN) + 경계 신호 readyField(X-FC 배치 — P 는 클릭 0 으로 마감까지 기다림), P 시작 기준 캡처 실패 [10, 40)초·조작 [20, 50)초 →
#      P ① 동결 회전마다 탐침 1, 실패 중 클릭 0·양보 0, 복구 뒤 ② 양보 1(약 10초) → 표식 회전(⑫) → 'stayed' = P 시작 + 60 + 30 + 10 = + 100 ± 2 → exit 4 '…필드 위 준비 패널이라 … (회차 미계상)'
Set-XfcPlan
Add-LogHook $lastRunHeader { $script:rc11Start = Elapsed; $script:capWindow = @(((Elapsed) + 10), ((Elapsed) + 40)); $script:activeWindow = @(((Elapsed) + 20), ((Elapsed) + 50)) }
Run-Member
$rc11Dur = $script:pCalls[0].EndAt - $script:pCalls[0].At
Check-Equal "RC11 P 캡처 실패 [10,40) + 조작 [20,50) → 탐침 = 안전 확인(≥ 1), 실패 중 양보·클릭 0, 양보 1, stayed = P 시작 + 100 ± 2 (실제 $([Math]::Round($rc11Dur, 1))), 캡처 간격 ≤ 2.5, exit 4 '필드 위 준비 패널'" (
  J @([int](($script:probeCalls -ge 1) -and ($script:probeCalls -eq $script:safeStopCalls)), @($script:yieldTimes | Where-Object { $_ -ge $script:rc11Start + 10 -and $_ -lt $script:rc11Start + 40 }).Count, $script:clicks.Count,
    $script:yieldWaits, [int]([Math]::Abs($rc11Dur - 100) -le 2), [int]((Get-MaxCaptureGap ($script:rc11Start + 10) ($script:rc11Start + 40)) -le 2.5), $script:exitCode, (Test-LastDone '필드 위 준비 패널이라 준비를 누르지 않고 마칩니다 \(회차 미계상\)$'))) '1/0/0/1/1/1/4/1'

# ── §2-SP·SJ. ⑥a 시작 패널 루프 (설계 2.12·2.13) - 운영 본문의 while 문을 잘라 점소싱으로 실행 ─────────────
# 두 루프는 함수가 아니라 워커 본문(시작 디스패치)에 있어 함수 추출이 안 됩니다. 앞 대입문(시작 패널 입장 대기 = `$startInsideStreak = 0`,
# 시작 패널 판정 = `$startPanelProbeRecovered = $false`) 뒤 첫 `while ($true)` 문을 AST 로 잘라, exit 를 센티널로 바꾼 뒤(치환 뒤 다시 파싱해
# ExitStatementAst 0건 확인) 점소싱으로 실행합니다 - 새 스코프(&)면 루프 안 대입(마감·연속 수·표식)이 케이스가 둔 지역 변수에 닿지 않습니다(규칙 3).
# 루프 앞 변수(마감·두 기준값·표식·라벨)는 운영 대입문과 같은 식으로 케이스가 먼저 둡니다. 가상 시계·스윕·판독 모의는 §2 하니스 그대로입니다.
function Get-StartLoopText {
  # 워커 본문(함수 밖)에서 AssignText 대입문(첫 번째) 뒤 첫 `while ($true)` 문의 원문을 돌려줍니다 (못 찾으면 '')
  param([string]$AssignText)
  $assign = @($workerAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Extent.Text -eq $AssignText }, $true) |
      Where-Object { -not (Test-AstInsideFunction $_) } | Sort-Object { $_.Extent.StartOffset }) | Select-Object -First 1
  if ($null -eq $assign) { return '' }
  $loop = @($workerAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.WhileStatementAst] -and $n.Condition.Extent.Text -eq '$true' }, $true) |
      Where-Object { $_.Extent.StartOffset -gt $assign.Extent.EndOffset } | Sort-Object { $_.Extent.StartOffset }) | Select-Object -First 1
  if ($null -eq $loop) { return '' }
  return [string]$loop.Extent.Text
}
$spLoopText = Get-StartLoopText '$startInsideStreak = 0'
$sjLoopText = Get-StartLoopText '$startPanelProbeRecovered = $false'
Check-True '§2 SP·SJ 추출: 입장 대기 루프(스윕·HUD·추적기 판독)와 판정 루프(패널·접힌 패널 판독)를 찾음' (
  $spLoopText.Contains('Invoke-PurchasePopupSweep -Game $game') -and $spLoopText.Contains('Test-InDungeonQuest -Game $game') -and
  $sjLoopText.Contains('Get-AbyssPanelKind -Game $game') -and $sjLoopText.Contains('Test-AbyssEntryWaiting -Game $game')) "sp=$($spLoopText.Length) sj=$($sjLoopText.Length)"
$script:sentinelChecks = @()
$script:spBlock = [scriptblock]::Create((Convert-ExitSentinel -Text $spLoopText -Label 'SP 루프'))
$script:sjBlock = [scriptblock]::Create((Convert-ExitSentinel -Text $sjLoopText -Label 'SJ 루프'))
foreach ($sentinel in $script:sentinelChecks) {
  Check-Equal "§2 센티널($($sentinel[0])): 원본 ExitStatementAst = 줄 단독 exit = 치환 수, 치환 뒤 ExitStatementAst 0" (J @($sentinel[1], $sentinel[2], $sentinel[3])) (J @($sentinel[1], $sentinel[1], 0))
}
Check-Equal '§2 센티널(SP·SJ): 입장 대기 루프 exit 4곳(표식 회전·스윕 참·판독 도중 복구·일반 마감), 판정 루프 exit 1곳(표식 회전 한도)' (J @($script:sentinelChecks[0][1], $script:sentinelChecks[1][1])) '4/1'

# 판정 루프의 접힌 패널 판정은 운영 Test-AbyssEntryWaiting 그대로 (하단 판독 Get-GameOcrText 만 모의 - 교대 실패 주입 자리)
Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-AbyssEntryWaiting')))
function Get-GameOcrText { param($Game)
  # 하단 판독 모의 - 화면 키의 하단 판독문 (실패 창 안 호출은 RC10(b)·SP5(b) 의 '스윕 안 뒤 판독' 계수에도 셈)
  if (In-Window $script:capWindow) { $script:sweepInnerInFail++ }
  if (-not (Read-Guard 'bottom')) { return '' }
  return [string]$scr[(Screen-Now)].Bottom
}
function Run-StartLoop {
  # 잘라 낸 루프를 한 번 끝까지 돌립니다. 앞 변수는 운영 대입문과 같은 식입니다 (시작 패널 라벨은 재매칭 - 설계 SP 케이스)
  param([string]$Kind)
  $script:exitCode = $null; $script:threw = ''; $script:loopBroke = $false; $script:loopStreak = -1; $script:sjPanelKind = ''; $script:sjEntryWaiting = ''
  $game = $null
  if ($Kind -eq 'SP') {
    $startPanelLabel = '재매칭 패널'
    $startMatchDeadline = (Get-Date).AddSeconds($timeoutPartyMatch)
    $startMatchSeenYieldMs = [double]$script:userYieldTotalMs
    $startMatchSeenFailMs = Get-CaptureFailTotalMs
    $startInsideStreak = 0
    $startFreezeRecovered = $false
  } else {
    $startPanelLimitDeadline = (Get-Date).AddSeconds($timeoutPartyMatch)
    $startPanelSeenYieldMs = [double]$script:userYieldTotalMs
    $startPanelSeenFailMs = Get-CaptureFailTotalMs
    $startPanelProbeRecovered = $false
    $startPanelKind = 'none'
    $startEntryWaiting = $false
  }
  try {
    if ($Kind -eq 'SP') { . $script:spBlock } else { . $script:sjBlock }
    $script:loopBroke = $true
  } catch {
    if ($_.Exception.Message -match '^__EXIT__(\d+)$') { $script:exitCode = [int]$Matches[1] } else { $script:threw = $_.Exception.Message }
  }
  if ($Kind -eq 'SP') { $script:loopStreak = $startInsideStreak } else { $script:sjPanelKind = $startPanelKind; $script:sjEntryWaiting = [string]$startEntryWaiting }
  $script:el = [Math]::Round((Elapsed), 1)
}
$spGeneralDone = "[완료] 재매칭 패널 에서 시작해 ${timeoutPartyMatch}초 안에 입장을 확인하지 못했습니다 - 취소·나가기 없이 정지합니다. 화면을 확인하고 다시 시작해 주세요."
$spPopupDone = "[완료] 재매칭 패널 에서 시작해 ${timeoutPartyMatch}초 안에 입장을 확인하지 못했습니다 - 취소·나가기 없이 정지합니다 (팝업이 이어짐). 화면을 확인하고 다시 시작해 주세요."
$sjDone = "[완료] 시작 화면이 파티 패널인지 ${timeoutPartyMatch}초 안에 확정하지 못했습니다(판독 도중 캡처가 끊김) - 누르지 않고 정지합니다. 화면을 확인하고 다시 시작해 주세요."
function Get-DiagCount { param([string]$Context) @($script:diag | Where-Object { $_ -eq "$Context|True" }).Count }
function Get-SpSummary { "exit=$($script:exitCode) threw=$($script:threw) broke=$($script:loopBroke) t=$($script:el) 조정=$(Get-AdjustedStop) 스윕=$($script:sweepCalls) 탐침=$($script:probeCalls) 안전=$($script:safeStopCalls) 양보=$($script:yieldWaits) done=$(Last-Done)" }

# SP1 (미관측 — 종료 보장 확인) 시작 패널 입장 대기의 스윕 굶김: 시작 패널 = 재매칭, 스윕 참 영구 — (a) cursor-not-ready(모의 공백 1초) (b) '전송'(3초)
#     → 마감 300초 뒤 스윕 참 분기에서 진단 1 + exit 4 '(팝업이 이어짐)', 정지 300~303초, 모의 스윕 호출 유한(약 300·100회)
#     (변이 '스윕 참 분기 마감 제거(⑥a 작업 트리)' 면 VTIMEOUT)
foreach ($variant in @(@{ Id = 'a'; Kind = 'cursor'; Gap = 1; Calls = @(290, 310) }, @{ Id = 'b'; Kind = 'sent'; Gap = 3; Calls = @(95, 105) })) {
  Reset-Member -Plan @((P 0 'matching'))
  Set-SweepFrom -From 0 -Kind $variant.Kind -Gap $variant.Gap
  Run-StartLoop 'SP'
  Check-Equal "SP1($($variant.Id)) (미관측 — 종료 보장 확인) 시작 재매칭 + 스윕 참 영구($($variant.Kind), $($variant.Gap)초) → 진단 '시작 패널 입장 대기 초과(팝업)' 1 + exit 4 '…(팝업이 이어짐)…', 입장 판정 0" (
    J @($script:exitCode, [int]((Last-Done) -eq $spPopupDone), (Get-DiagCount '시작 패널 입장 대기 초과(팝업)'), $script:loopStreak, $script:threw)) '4/1/1/0/'
  Check-True "SP1($($variant.Id)) 정지 300~303초 (실제 $($script:el)), 모의 스윕 호출 $($variant.Calls[0])~$($variant.Calls[1])회 (실제 $($script:sweepCalls))" (
    ($script:el -ge 300) -and ($script:el -le 303) -and ($script:sweepCalls -ge $variant.Calls[0]) -and ($script:sweepCalls -le $variant.Calls[1])) (Get-SpSummary)
}
# SP1(c) 스윕 user-active 5회(위임 길 — 누적 없음, 다음 회전 양보 게이트가 조작을 봄 → 양보 3초씩) 뒤 거짓 → 305초에 입장(던전 안 HUD + 추적기)
#     → 조작 동안 마감 판정 0 · 마감은 양보(15초)만큼 연장돼 300초를 넘겨도 정지하지 않고 입장 2연속 → break, exit 0건
#     (변이 '양보 연장 제거' 면 300초에 exit 4)
Reset-Member -Plan @((P 0 'matching'), (P 305 'inside'))
Set-SweepFrom -From 0 -Kind 'ua-deleg' -Gap 1 -Count 5
Run-StartLoop 'SP'
Check-Equal 'SP1(c) 스윕 user-active 5회 → 양보 5(누적 15초) → 300초를 넘겨 305초 입장 2연속 → break (exit 0건·진단 0)' (
  J @($script:loopBroke, $script:exitCode, $script:yieldWaits, [Math]::Round($script:userYieldTotalMs / 1000.0, 1), $script:diag.Count, [int](($script:el -gt 305) -and ($script:el -lt 315)), $script:threw)) 'True//5/15/0/1/'

# SP2 (미관측 — 종료 보장 확인) 같은 회전 복구 반복 (영구): (a) 스윕 모의가 거짓을 돌려주되 그 안에서 실패 등록 → 가상 1초 → 뒤 HUD 판독이 복구
#     (b) 스윕 모의가 참(cursor-not-ready)을 돌려주며 그 안에서 실패 → 복구 → (a) 진단 '시작 패널 입장 대기 초과' 1 + exit 4 일반 문구 /
#     (b) 진단 '…(팝업)' 1 + exit 4 '(팝업이 이어짐)'. 두 변형 모두 (가상 경과 − 누적 실패) 300~303초, 동결 블록 0(안전 확인 0), 입장 판정 0
#     (변이 '판독 도중 복구 회전 블록 제거' 면 (a), '스윕 분기가 스윕 도중 복구도 제외' 면 (b), '복구 블록의 2초 대기 제거' 면 (a) 가 VTIMEOUT)
foreach ($variant in @(@{ Id = 'a'; Kind = 'fail-false'; Done = $spGeneralDone; Diag = '시작 패널 입장 대기 초과' }, @{ Id = 'b'; Kind = 'recover'; Done = $spPopupDone; Diag = '시작 패널 입장 대기 초과(팝업)' })) {
  Reset-Member -Plan @((P 0 'matching'))
  Set-SweepFrom -From 0 -Kind $variant.Kind -Gap 1
  Run-StartLoop 'SP'
  Check-Equal "SP2($($variant.Id)) (미관측 — 종료 보장 확인) 같은 회전 복구 영구($($variant.Kind)) → 진단 '$($variant.Diag)' 1 + exit 4, 안전 확인 0, 입장 판정 0" (
    J @($script:exitCode, [int]((Last-Done) -eq $variant.Done), (Get-DiagCount $variant.Diag), $script:diag.Count, $script:safeStopCalls, $script:loopStreak, $script:threw)) '4/1/1/1/0/0/'
  Check-True "SP2($($variant.Id)) (가상 경과 − 누적 실패) 300~303초 (실제 $(Get-AdjustedStop), 누적 실패 $([Math]::Round($script:failTotalMs / 1000.0, 1)))" (
    ((Get-AdjustedStop) -ge 300) -and ((Get-AdjustedStop) -le 303) -and ($script:failTotalMs -gt 0)) (Get-SpSummary)
}

# SP3 (미관측 — 종료 보장 확인) 섞인 모양: SP2(a) 의 같은 회전 복구에 20회전마다 한 번, HUD 판독의 실패가 폐기 줄까지 이어지고 다음 회전 동결 블록 탐침이
#     복구하는 회전을 섞음(영구) → 입장 판정 0, 동결 회전의 마감 되돌림 0 → 마감 300초(실패 제외)에 진단 '시작 패널 입장 대기 초과' 1 + exit 4(일반 문구)
#     (변이 '서두 동결의 마감 되돌림 세 줄 되살림' 이면 20회전마다 마감이 300초로 돌아가 VTIMEOUT)
Reset-Member -Plan @((P 0 'matching'))
$script:sp3Turn = 0; $script:sp3HudFail = $false
$script:sweepPlan = { $script:sp3Turn++; if ($script:sp3Turn % 20 -eq 0) { $script:sp3HudFail = $true; return $null }; return @{ Kind = 'fail-false'; Gap = 1 } }
$script:failHook = { param($Name) if ($Name -eq 'hud' -and $script:sp3HudFail) { $script:sp3HudFail = $false; $script:persistFail = $true; return 0 } return -1 }
Run-StartLoop 'SP'
Check-Equal "SP3 (미관측 — 종료 보장 확인) 섞인 모양 → 진단 '시작 패널 입장 대기 초과' 1 + exit 4 일반 문구, 동결 회전 ≥ 1(안전 확인 = 탐침), 입장 판정 0" (
  J @($script:exitCode, [int]((Last-Done) -eq $spGeneralDone), (Get-DiagCount '시작 패널 입장 대기 초과'), $script:diag.Count, [int]($script:safeStopCalls -ge 1), [int]($script:safeStopCalls -eq $script:probeCalls), $script:loopStreak, $script:threw)) '4/1/1/1/1/1/0/'
Check-True "SP3 (가상 경과 − 누적 실패) 300~303초 (실제 $(Get-AdjustedStop))" (((Get-AdjustedStop) -ge 300) -and ((Get-AdjustedStop) -le 303)) (Get-SpSummary)

# SP4 (미관측 — 종료 보장 확인) 교대 모양: 스윕 모의는 성공, HUD 판독이 실패를 등록하고 폐기 줄까지 이어짐 → 다음 회전 동결 블록 탐침이 복구(영구)
#     → 동결 회전마다 안전 확인·탐침 복구 → 표식 → 표식 블록(스윕·판독 없이 마감 + 2초) → 마감 300초(실패 제외)에 진단 + exit 4(일반 문구)
#     (변이 '동결 블록 표식 제거' 면 VTIMEOUT)
Reset-Member -Plan @((P 0 'matching'))
$script:failHook = { param($Name) if ($Name -eq 'hud') { $script:persistFail = $true; return 0 } return -1 }
Run-StartLoop 'SP'
Check-Equal "SP4 (미관측 — 종료 보장 확인) 교대 모양 → 진단 '시작 패널 입장 대기 초과' 1 + exit 4 일반 문구, 안전 확인 ≥ 1 = 탐침 수, 입장 판정 0" (
  J @($script:exitCode, [int]((Last-Done) -eq $spGeneralDone), (Get-DiagCount '시작 패널 입장 대기 초과'), [int]($script:safeStopCalls -ge 1), [int]($script:safeStopCalls -eq $script:probeCalls), $script:loopStreak, $script:threw)) '4/1/1/1/1/0/'
Check-True "SP4 (가상 경과 − 누적 실패) 300~303초 (실제 $(Get-AdjustedStop))" (((Get-AdjustedStop) -ge 300) -and ((Get-AdjustedStop) -le 303)) (Get-SpSummary)

# SJ1 (미관측 — 종료 보장 확인) 시작 패널 판정의 교대 모양: 매 회전 Get-AbyssPanelKind 성공('none' - 필드), 뒤 하단 판독(Test-AbyssEntryWaiting 안
#     Get-GameOcrText)이 실패를 등록하고 다음 회전 동결 블록 탐침이 복구(영구) → 판정 확정 0(break 0), 동결 회전마다 안전 확인·탐침 복구 → 표식 회전
#     (판독 없이 한도 + 2초) → 한도 300초(실패 제외)에 진단 '시작 패널 판정 불가' 1 + exit 4 (변이 '한도 제거(⑥a 작업 트리)' 면 VTIMEOUT)
Reset-Member -Plan @((P 0 'field'))
$script:failHook = { param($Name) if ($Name -eq 'bottom') { $script:persistFail = $true; return 0 } return -1 }
Run-StartLoop 'SJ'
Check-Equal "SJ1 (미관측 — 종료 보장 확인) 판정 루프 교대 모양 → break 0, 진단 '시작 패널 판정 불가' 1 + exit 4 '$sjDone', 안전 확인 ≥ 1 = 탐침 수" (
  J @($script:loopBroke, $script:exitCode, [int]((Last-Done) -eq $sjDone), (Get-DiagCount '시작 패널 판정 불가'), [int]($script:safeStopCalls -ge 1), [int]($script:safeStopCalls -eq $script:probeCalls), $script:threw)) 'False/4/1/1/1/1/'
Check-True "SJ1 (가상 경과 − 누적 실패) 300~303초 (실제 $(Get-AdjustedStop))" (((Get-AdjustedStop) -ge 300) -and ((Get-AdjustedStop) -le 303)) (Get-SpSummary)

# SP5 (2.12 — 캡처 실패 + 유한 조작, 09-30 리뷰5 P2-1): 시작 패널 = 재매칭, 캡처 실패 [50, 150)·조작 [100, 200) → 서두 동결 회전마다 탐침 1,
#     실패 중 양보 0·입장 판정 0, 복구 뒤 양보 1(약 50초) → 표식 회전 → 마감 = 300 + 100 + 50 = 450 ± 3초에 진단 + exit 4(일반 문구)
#     (겹침 이중이면 약 550초, '동결을 양보 뒤로' 면 조작 동안 캡처 0 - 간격 약 50초)
Reset-Member -Plan @((P 0 'matching'))
$script:capWindow = @(50, 150)
$script:activeWindow = @(100, 200)
Run-StartLoop 'SP'
Check-Equal "SP5 캡처 실패 [50,150) + 조작 [100,200) → 탐침 = 안전 확인(≥ 1), 실패 중 양보 0, 양보 1, 캡처 최대 간격 $(Get-MaxCaptureGap 50 150) ≤ 2.5, 정지 450 ± 3 (실제 $($script:el)), 진단 + exit 4 일반 문구" (
  J @([int](($script:probeCalls -ge 1) -and ($script:probeCalls -eq $script:safeStopCalls)), @($script:yieldTimes | Where-Object { $_ -ge 50 -and $_ -lt 150 }).Count, $script:yieldWaits,
    [int]((Get-MaxCaptureGap 50 150) -le 2.5), [int]([Math]::Abs($script:el - 450) -le 3), $script:exitCode, [int]((Last-Done) -eq $spGeneralDone), (Get-DiagCount '시작 패널 입장 대기 초과'), $script:loopStreak)) '1/0/1/1/1/4/1/1/0'

# SP5(b) 공용 스윕 첫 판독에서 실패 시작 + 커서 위 조작 (RC10(b) 와 같은 모의 - 운영 스윕 추출): 50초 회전의 스윕 첫 판독이 실패 창 [50, 150)의 첫 실패
#     (느린 실패 1초), 조작 창 [50.5, 120) → 스윕 곧바로 거짓(실패 창 안 커서 대피 0·'닫기' 탐색·하단 판독 0), 서두 동결 회전마다 탐침 1, 실패 중 양보 0,
#     복구(≈150초) 때 조작은 끝나 양보 0 → 마감 = 300 + 100 = 400 ± 3초에 진단 + exit 4(일반 문구)
#     (변이 '스윕 첫 판독 가드 제거' 면 커서 대피 [51, 120) 대기(양보 약 69초 겹침 이중) → 약 469초)
Reset-Member -Plan @((P 0 'matching'))
$script:useRealSweep = $true
$script:restartArm = 50; $script:restartWindowEnd = 150; $script:restartActiveEnd = 120; $script:sweepInnerInFail = 0
Run-StartLoop 'SP'
Check-Equal "SP5(b) 운영 공용 스윕 첫 판독 실패 + 커서 위 조작 → 실패 창 안 커서 대피·'닫기' 탐색·하단 판독 0, 탐침 = 안전 확인(≥ 1), 양보 0, 캡처 간격 ≤ 2.5, 정지 400 ± 3 (실제 $($script:el)), exit 4 일반 문구" (
  J @($script:cursorParkInFail, $script:sweepInnerInFail, [int](($script:probeCalls -ge 1) -and ($script:probeCalls -eq $script:safeStopCalls)), $script:yieldWaits, [int]((Get-MaxCaptureGap 50 150) -le 2.5),
    [int]([Math]::Abs($script:el - 400) -le 3), $script:exitCode, [int]((Last-Done) -eq $spGeneralDone), [int]($script:cursorParkCalls -ge 20))) '0/0/1/0/1/1/4/1/1'
$script:restartArm = 0

# SJ2 (2.13 시작 패널 판정 — 같은 시험, 09-30 리뷰5 P2-1): 시작 화면 필드(패널 none), 캡처 실패 [0, 35)·조작 [20, 50) → 첫 회전 패널 판독 실패(0초) →
#     동결 회전(2초 대기 + 탐침) 18회 — 탐침 2~34초 실패, 36초 탐침 복구 → 표식 → 표식 블록 게이트 양보 1(36 → 50초) → 표식 회전(한도 한참 남음, 2초) →
#     약 52초 유효 회전에서 break(패널 none — 유효 판독으로만 확정). 탐침 = 안전 확인 = 18(± 1), 실패 중 양보 0·판정 확정 0, exit 0건
#     (변이 '동결 블록의 복구 탐침 제거' 면 자기 잠금 VTIMEOUT)
Reset-Member -Plan @((P 0 'field'))
$script:capWindow = @(0, 35)
$script:activeWindow = @(20, 50)
Run-StartLoop 'SJ'
Check-Equal "SJ2 판정 루프 캡처 실패 [0,35) + 조작 [20,50) → 탐침 = 안전 확인 = 18 ± 1 (실제 $($script:probeCalls)), 실패 중 양보 0, 양보 1, 약 52초 유효 회전에서 break (실제 $($script:el)) - 패널 none·접힌 패널 아님, exit 0건" (
  J @([int](($script:probeCalls -ge 17) -and ($script:probeCalls -le 19) -and ($script:probeCalls -eq $script:safeStopCalls)), @($script:yieldTimes | Where-Object { $_ -lt 35 }).Count, $script:yieldWaits,
    $script:loopBroke, [int](($script:el -ge 50) -and ($script:el -le 54)), $script:sjPanelKind, $script:sjEntryWaiting, $script:exitCode, $script:threw)) '1/0/1/True/1/none/False//'

# ── §3 배선 (설계 5.1 §3) ───────────────────────────────────────────────────────
# 범위는 추출한 D·P 본문과 새 시계 헬퍼 집합의 '주석 뺀 사본' 입니다 (파일 전체에는 생활의 UNTIL 참조·결과 화면 나가기 좌표 상수가 이미 있어
# 파일 전체로 세면 단언이 흐려짐 - 리뷰 C11). 문자열 단언은 주석을 뺀 사본으로만 합니다 (주석에만 걸리는 단언 금지 - 검증 방법).
# 위치 비교는 IndexOf, 블록 소속은 AST(조건절 사슬)로 봅니다 - 정규식만으로는 '같은 분기 안' 을 확인할 수 없기 때문입니다.
$dCode = Remove-SourceComments $sourceDefs['Invoke-AbyssPartyMemberCycle']
$pCode = Remove-SourceComments $sourceDefs['Invoke-AbyssMemberLeave']
$astTokens = $null; $astErrors = $null
$dAst = [System.Management.Automation.Language.Parser]::ParseInput($dCode, [ref]$astTokens, [ref]$astErrors)
$pAst = [System.Management.Automation.Language.Parser]::ParseInput($pCode, [ref]$astTokens, [ref]$astErrors)
function Get-TextCount { param([string]$Text, [string]$Literal) return ([regex]::Matches($Text, [regex]::Escape($Literal))).Count }
function Get-ClauseChain {
  # 노드를 감싼 if 절 사슬(안쪽부터). 항목 @{ Cond = 조건식 원문; IsElse; Body = 그 절 본문 } - else 절이면 Cond 에 형제 조건을 ' | ' 로 이어 둡니다
  param($Node)
  $chain = @()
  $parent = $Node.Parent
  while ($null -ne $parent) {
    if ($parent -is [System.Management.Automation.Language.IfStatementAst]) {
      $entry = $null
      foreach ($clause in $parent.Clauses) {
        if ($clause.Item2.Extent.StartOffset -le $Node.Extent.StartOffset -and $clause.Item2.Extent.EndOffset -ge $Node.Extent.EndOffset) {
          $entry = @{ Cond = [string]$clause.Item1.Extent.Text; IsElse = $false; Body = [string]$clause.Item2.Extent.Text }
        }
      }
      if ($null -eq $entry -and $null -ne $parent.ElseClause -and $parent.ElseClause.Extent.StartOffset -le $Node.Extent.StartOffset -and $parent.ElseClause.Extent.EndOffset -ge $Node.Extent.EndOffset) {
        $entry = @{ Cond = (@($parent.Clauses | ForEach-Object { [string]$_.Item1.Extent.Text }) -join ' | '); IsElse = $true; Body = [string]$parent.ElseClause.Extent.Text }
      }
      if ($null -ne $entry) { $chain += , $entry }
    }
    $parent = $parent.Parent
  }
  return $chain
}
function Get-CommandNodes { param($Ast, [string]$Name) return @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq $Name }, $true)) }
function Get-AssignNodes { param($Ast, [string]$Variable) return @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq $Variable }, $true)) }
function Get-IfByCondition { param($Ast, [string]$Condition) return @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -eq $Condition }, $true)) }
function Get-EventNodes {
  # Update-AbyssMemberLeaveTransition 호출을 -Event 인자('sweep' 등 따옴표 포함)별로 모읍니다
  param($Ast)
  $byEvent = @{}
  foreach ($cmd in (Get-CommandNodes $Ast 'Update-AbyssMemberLeaveTransition')) {
    $elements = @($cmd.CommandElements)
    for ($i = 0; $i -lt $elements.Count - 1; $i++) {
      if ($elements[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and $elements[$i].ParameterName -eq 'Event') {
        $key = [string]$elements[$i + 1].Extent.Text
        if (-not $byEvent.ContainsKey($key)) { $byEvent[$key] = @() }
        $byEvent[$key] += , $cmd
      }
    }
  }
  return $byEvent
}
function Get-OrderIndices {
  # 순서 단언: 단계마다 @(찾을 문자열, 방식) - 'first' = 본문 첫 위치, 'after' = 직전 단계 뒤 첫 위치, 'last' = 마지막 위치
  param([string]$Text, [object[]]$Steps)
  $positions = @(); $previous = -1
  foreach ($step in $Steps) {
    $needle = [string]$step[0]; $mode = [string]$step[1]
    $index = $(if ($mode -eq 'after') { $(if ($previous -ge 0) { $Text.IndexOf($needle, $previous + 1) } else { -1 }) } elseif ($mode -eq 'last') { $Text.LastIndexOf($needle) } else { $Text.IndexOf($needle) })
    $positions += $index
    $previous = $index
  }
  return $positions
}
function Test-Increasing { param([int[]]$Positions) for ($i = 0; $i -lt $Positions.Count; $i++) { if ($Positions[$i] -lt 0) { return $false }; if ($i -gt 0 -and $Positions[$i] -le $Positions[$i - 1]) { return $false } }; return $true }
function Test-ShapeAt { param([string]$Text, [int]$Index, [string]$Pattern) if ($Index -lt 0) { return $false }; return [bool]($Text.Substring($Index) -match ('^' + $Pattern)) }

$dWhiles = @($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.WhileStatementAst] }, $true))
$pWhiles = @($pAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.WhileStatementAst] }, $true))
Check-Equal '§3 D·P 본문의 반복문은 회전 루프 while ($true) 하나씩' (J @($dWhiles.Count, $pWhiles.Count, $dWhiles[0].Condition.Extent.Text, $pWhiles[0].Condition.Extent.Text)) '1/1/$true/$true'
$dLoop = $dCode.Substring($dWhiles[0].Extent.StartOffset, $dWhiles[0].Extent.EndOffset - $dWhiles[0].Extent.StartOffset)
$pLoop = $pCode.Substring($pWhiles[0].Extent.StartOffset, $pWhiles[0].Extent.EndOffset - $pWhiles[0].Extent.StartOffset)
$dLoopStart = $dWhiles[0].Extent.StartOffset
$pLoopStart = $pWhiles[0].Extent.StartOffset

# 회전 순서 (D - 설계 2.3). 모든 IndexOf 는 while 본문 안에서 셉니다 (루프 앞 초기화 `$sweepStreak = 0` 이 먼저 잡히지 않게)
$freezeShape = 'if \(\$script:screenCaptureFailing\) \{\s*Test-SafeStopDuringCaptureFail\s*Start-Sleep -Seconds 2\s*\[void\]\(Test-CaptureRecovered -Game \$Game\)\s*\$freezeRecovered = -not \$script:screenCaptureFailing\s*continue\s*\}'
$starvedShape = 'if \(\$sweepStarved\) \{\s*continue\s*\}'
$recoveredShape = 'if \(\$turnRecovered\) \{\s*Start-Sleep -Milliseconds 700\s*continue\s*\}'
$dOrder = @(Get-OrderIndices $dLoop @(
    @('$script:lastClickSkipReason = ''''', 'first'), @('$turnRecovered = $false', 'first'), @('if ($script:screenCaptureFailing) {', 'first'),
    @('if (Test-UserRecentlyActive)', 'first'), @('if ($freezeRecovered) {', 'first'), @('(-not $turnRecovered) -and (Invoke-PurchasePopupSweep', 'first'),
    @('Resolve-AbyssMemberSweepTurn', 'first'), @('Test-DungeonClearPrompt', 'first'), @('-ne $turnYieldMs)', 'after'), @('-ne $turnSerial) {', 'after'),
    @('$turnRecovered = -not $script:screenCaptureFailing', 'first'), @('$sweepStreak = 0', 'after'), @('Resolve-AbyssMemberScreen -PromptVisible', 'first'),
    @('Test-AbyssMemberClockExpired', 'last'), @('if ($sweepStarved) {', 'after'), @('if ($turnRecovered) {', 'after'), @('Click-GamePoint', 'first')))
Check-True '§3 회전 순서(D): 서두 메타 비움 < 표식 비움 < ① 동결 < ② 양보 < 표식 블록 < ③ 스윕(-not $turnRecovered) < 생략 사유 분류 < ④ 판독 < 간접 양보 < 유효성 < 복구 표식 < 연속 수 비움 < 분류 < ⑨ 마지막 만료 판정 < 굶김 continue < 복구 700ms continue < 첫 클릭' (
  (Test-Increasing $dOrder) -and (Test-ShapeAt $dLoop $dOrder[2] $freezeShape) -and (Test-ShapeAt $dLoop $dOrder[14] $starvedShape) -and (Test-ShapeAt $dLoop $dOrder[15] $recoveredShape)) ($dOrder -join ',')
$pOrder = @(Get-OrderIndices $pLoop @(
    @('$script:lastClickSkipReason = ''''', 'first'), @('$turnRecovered = $false', 'first'), @('if ($script:screenCaptureFailing) {', 'first'),
    @('if (Test-UserRecentlyActive)', 'first'), @('if ($freezeRecovered) {', 'first'), @('(-not $turnRecovered) -and (Invoke-PurchasePopupSweep', 'first'),
    @('-Event ''sweep''', 'first'), @('Resolve-AbyssMemberSweepTurn', 'first'), @('Test-DungeonClearPrompt', 'first'), @('-ne $turnSerial) {', 'after'),
    @('$turnRecovered = -not $script:screenCaptureFailing', 'first'), @('$sweepStreak = 0', 'after'), @('-Event ''interrupt''', 'first'),
    @('Resolve-AbyssMemberScreen -PromptVisible', 'first'), @('Result = ''aborted''', 'first'), @('Result = ''committed''', 'first'),
    @('if ($screen -eq ''prompt'' -or $screen -eq ''reward3'') {', 'first'), @('-Event ''sample''', 'first'), @('Test-AbyssMemberClockExpired', 'last'),
    @('if ($sweepStarved) {', 'after'), @('if ($turnRecovered) {', 'after'), @('Click-GamePoint', 'first')))
Check-True '§3 회전 순서(P, 설계 2.8): 서두 메타 < 표식 비움 < ① 동결 < ② 양보 < 표식 블록 < ③ 스윕 < sweep 무장 해제 < 생략 사유 분류 < ④ 판독 < 유효성 < 복구 표식 < 연속 수 비움 < interrupt < 분류 < 중단 < 커밋 < 즉시 반환 < sample < ⑫ 마감 < 굶김 continue < 복구 700ms continue < 첫 클릭' (
  (Test-Increasing $pOrder) -and (Test-ShapeAt $pLoop $pOrder[2] $freezeShape) -and (Test-ShapeAt $pLoop $pOrder[19] $starvedShape) -and (Test-ShapeAt $pLoop $pOrder[20] $recoveredShape)) ($pOrder -join ',')

# 동결 블록: test_stall_guards 와 같은 AST 규칙(조건식이 정확히 `$script:screenCaptureFailing` 인 if 의 본문에 줄 머리 continue)으로 D·P 각 1곳,
# 그 밖에 조건식이 정확히 그것인 if·elseif·while 은 0건 (복구 회전 분기 포함)
function Get-FreezeSpotCounts {
  param($Ast)
  $exactClauses = 0; $spinClauses = 0
  foreach ($ifNode in @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true))) {
    foreach ($clause in $ifNode.Clauses) {
      if ($clause.Item1.Extent.Text -match '^\(?\$script:screenCaptureFailing\)?$') {
        $exactClauses++
        if ($clause.Item2.Extent.Text -match '(?m)^\s*continue\b') { $spinClauses++ }
      }
    }
  }
  $exactWhiles = @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.WhileStatementAst] -and $n.Condition.Extent.Text -match '^\(?\$script:screenCaptureFailing\)?$' }, $true)).Count
  return (J @($exactClauses, $spinClauses, $exactWhiles))
}
Check-Equal '§3 동결 블록: D·P 각각 정확 조건 if-continue 1곳, 그 밖 정확 조건 if·elseif·while 0건 (stall 규칙)' (J @((Get-FreezeSpotCounts $dAst), (Get-FreezeSpotCounts $pAst))) '1/1/0/1/1/0'
$dFreeze = @(Get-IfByCondition $dAst '$script:screenCaptureFailing')[0].Clauses[0].Item2.Extent.Text
$pFreeze = @(Get-IfByCondition $pAst '$script:screenCaptureFailing')[0].Clauses[0].Item2.Extent.Text
Check-True '§3 동결 블록 안: 시계·마감 대입과 퇴장 전이 호출 0건 (D·P)' (
  -not (($dFreeze + $pFreeze) -match 'Set-AbyssMemberClock|Suspend-AbyssMemberClock|Resume-AbyssMemberClock|Deadline|AddSeconds|Update-AbyssMemberLeaveTransition')) ''

# 스윕 참 분기 (09-30 리뷰2·리뷰3): 분류 헬퍼 1곳 · 인자 · 출구 · 연속 수 대입
$sweepArgs = 'Resolve-AbyssMemberSweepTurn -CaptureFailingNow \$script:screenCaptureFailing -CaptureFailedInTurn \(\$script:captureFailSerial -ne \$turnSerial\)\s*`\s*-Performed \$script:lastClickPerformed -SkipReason \$script:lastClickSkipReason -Streak \$sweepStreak -Limit \$memberSweepStreakLimit'
function Get-SweepBranchFacts {
  # 스윕 참 분기 본문의 사실 목록: 분류 헬퍼 수·인자·continue 수(조건)·exit/return/break 수·굶김/복구 대입·분기 안 `$sweepStreak = 0` 수
  param($Ast, [string]$Code)
  $branchIf = @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -match 'Invoke-PurchasePopupSweep' }, $true))
  if ($branchIf.Count -ne 1) { return "분기 수 $($branchIf.Count)" }
  $body = $branchIf[0].Clauses[0].Item2
  $continues = @($body.FindAll({ param($n) $n -is [System.Management.Automation.Language.ContinueStatementAst] }, $true))
  $continueConds = @($continues | ForEach-Object { @(Get-ClauseChain $_)[0].Cond })
  $leaves = @($body.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] -or $n -is [System.Management.Automation.Language.ReturnStatementAst] -or $n -is [System.Management.Automation.Language.BreakStatementAst] }, $true)).Count
  $bodyText = [string]$body.Extent.Text
  return (J @((Get-TextCount $Code 'Resolve-AbyssMemberSweepTurn'), (Get-TextCount $bodyText 'Resolve-AbyssMemberSweepTurn'), [int]($bodyText -match $sweepArgs), $continues.Count,
      [int](($continueConds -join '') -eq '$sweepTurn.Action -eq ''freeze'' -or $sweepTurn.Action -eq ''yield'' -or $sweepTurn.Action -eq ''counted'''), $leaves,
      [int]($bodyText.Contains('$sweepStarved = ($sweepTurn.Action -eq ''starved'')')), [int]($bodyText.Contains('$turnRecovered = ($sweepTurn.Action -eq ''recovered'')')),
      @(Get-AssignNodes $body '$sweepStreak' | Where-Object { $_.Right.Extent.Text -eq '0' }).Count))
}
Check-Equal '§3 스윕 참 분기(D·P): 분류 헬퍼 1곳(분기 안) · 인자(-CaptureFailingNow 플래그 · -CaptureFailedInTurn 일련번호 차분 · 두 메타) · 출구는 freeze/yield/counted continue 1개와 굶김·복구 대입뿐 · 분기 안 연속 수 0 대입 0' (
  J @((Get-SweepBranchFacts $dAst $dCode), (Get-SweepBranchFacts $pAst $pCode))) '1/1/1/1/1/0/1/1/0/1/1/1/1/1/0/1/1/0'
function Get-SweepStreakFacts {
  # 회전 루프 안 `$sweepStreak` 대입은 반환(.Streak)과 유효 표본의 0 둘뿐, 루프 앞 초기화 0 은 1곳
  param($Ast, $WhileNode)
  $inLoop = @(Get-AssignNodes $WhileNode '$sweepStreak' | ForEach-Object { [string]$_.Right.Extent.Text } | Sort-Object)
  $before = @(Get-AssignNodes $Ast '$sweepStreak' | Where-Object { $_.Extent.StartOffset -lt $WhileNode.Extent.StartOffset } | ForEach-Object { [string]$_.Right.Extent.Text })
  return (J @(($inLoop -join '+'), ($before -join '+')))
}
Check-Equal '§3 회전 루프 안 $sweepStreak 대입 = [int]$sweepTurn.Streak·0 둘, 루프 앞 초기화 0 한 곳 (D·P)' (J @((Get-SweepStreakFacts $dAst $dWhiles[0]), (Get-SweepStreakFacts $pAst $pWhiles[0]))) '[int]$sweepTurn.Streak+0/0/[int]$sweepTurn.Streak+0/0'
$pSweepBody = @($pAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -match 'Invoke-PurchasePopupSweep' }, $true))[0].Clauses[0].Item2.Extent.Text
Check-True '§3 P 스윕 참 분기 첫머리: -Event ''sweep'' 과 $readyKnown = $false 가 분류 헬퍼 앞 (모든 스윕 참 회전)' (
  ($pSweepBody.IndexOf('-Event ''sweep''') -ge 0) -and ($pSweepBody.IndexOf('$readyKnown = $false') -ge 0) -and
  ($pSweepBody.IndexOf('-Event ''sweep''') -lt $pSweepBody.IndexOf('Resolve-AbyssMemberSweepTurn')) -and ($pSweepBody.IndexOf('$readyKnown = $false') -lt $pSweepBody.IndexOf('Resolve-AbyssMemberSweepTurn'))) ''

# 굶김·복구 회전은 판독·클릭에 닿지 않음: ④~⑧(P ④~⑪)은 `if ((-not $sweepStarved) -and (-not $turnRecovered))` 안
function Get-ReadBlockFacts {
  param($Ast, [string[]]$MustContain)
  $blocks = @(Get-IfByCondition $Ast '(-not $sweepStarved) -and (-not $turnRecovered)')
  if ($blocks.Count -ne 1) { return "블록 수 $($blocks.Count)" }
  $text = [string]$blocks[0].Clauses[0].Item2.Extent.Text
  return (J @($blocks.Count, (@($MustContain | Where-Object { -not $text.Contains($_) }).Count), (Get-TextCount $text 'Click-GamePoint')))
}
Check-Equal '§3 판독 블록(D ④~⑧ / P ④~⑪): 굶김·복구가 아닐 때만 - 판독·분류·게이트가 그 안, 클릭은 그 밖 (D·P)' (
  J @((Get-ReadBlockFacts $dAst @('Test-DungeonClearPrompt -Game $Game', 'Resolve-AbyssMemberScreen -PromptVisible', 'Get-AbyssMemberStopReason -Phase $(if ($gatePending)')),
    (Get-ReadBlockFacts $pAst @('Test-DungeonClearPrompt -Game $Game', 'Resolve-AbyssMemberScreen -PromptVisible', '-Event ''sample''')))) '1/0/0/1/0/0'
$overlayChain = @(Get-ClauseChain (Get-CommandNodes $dAst 'Clear-EventOverlay')[0])
Check-True '§3 D ⑨ 3단계(이벤트 정리) 조건에 -not $sweepStarved 와 -not $turnRecovered' (
  (@(Get-CommandNodes $dAst 'Clear-EventOverlay').Count -eq 1) -and $overlayChain[0].Cond.Contains('(-not $sweepStarved)') -and $overlayChain[0].Cond.Contains('(-not $turnRecovered)')) $overlayChain[0].Cond
$starvedRecovered = @($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Clauses.Count -eq 2 -and $n.Clauses[0].Item1.Extent.Text -eq '$sweepStarved' -and $n.Clauses[1].Item1.Extent.Text -eq '$turnRecovered' }, $true))
$starvedBody = $(if ($starvedRecovered.Count -eq 1) { [string]$starvedRecovered[0].Clauses[0].Item2.Extent.Text } else { '' })
$recoveredBody = $(if ($starvedRecovered.Count -eq 1) { [string]$starvedRecovered[0].Clauses[1].Item2.Extent.Text } else { '' })
Check-Equal '§3 D ⑦′ 굶김 블록: M 재개 있음·알 수 없음 시계 대입 없음 / ⑦″ 복구 블록: 두 시계 정지 조건 아래 M 재개만, Suspend·Set·시계·연속 수 대입 없음' (
  J @($starvedRecovered.Count, [int]$starvedBody.Contains('Resume-AbyssMemberClock -Clock $mClock'), [int]($starvedBody -match '\$unknownClock\s*='),
    [int]($recoveredBody -match 'if \(\$mClock\.Paused -and \$rClock\.Paused\) \{ Resume-AbyssMemberClock -Clock \$mClock \}'), (Get-TextCount $recoveredBody 'Resume-AbyssMemberClock'),
    [int]($recoveredBody -match 'Suspend-AbyssMemberClock|Set-AbyssMemberClock|\$unknownClock\s*=|\$insideStreak\s*=|\$fieldStreak\s*=|\$sweepStreak\s*='))) '1/1/0/1/1/0'

# 계측 로그 (로그 전용 - 판정·클릭에 쓰지 않음, ㉷)
$entryMeasureNodes = @($dAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -and $n.Extent.Text.Contains('입장 계측') }, $true))
$entryMeasureChain = @(Get-ClauseChain $entryMeasureNodes[0])
$entryRunLines = @($dCode -split "`r?`n" | Where-Object { $_ -match '\$entryRun\w*\s*(\+)?=' })
$conditionTexts = @(@($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true) | ForEach-Object { $_.Clauses | ForEach-Object { [string]$_.Item1.Extent.Text } }) +
  @($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.WhileStatementAst] }, $true) | ForEach-Object { [string]$_.Condition.Extent.Text }))
$pMeasureNodes = @($pAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -and $n.Extent.Text.Contains('표본 뒤 던전 안 표본(퇴장 절차)') }, $true))
$pMeasureChain = @(Get-ClauseChain $pMeasureNodes[0])
Check-Equal '§3 계측 로그: D 입장 계측 1곳(던전 안 2연속 자리) · P 계측 1곳(⑨ 커밋 안 inside) - 두 블록과 $entryRun* 대입 줄에 클릭·exit·return·경계 클릭 대입 없음, $entryRun*·$insideStreakSince 는 판정 조건에 없음' (
  J @($entryMeasureNodes.Count, $entryMeasureChain[0].Cond, [int]($entryMeasureChain[0].Body -match 'Click-|\bexit\b|\breturn\b|\$boundaryClick\s*='),
    [int](($entryRunLines -join "`n") -match 'Click-|\bexit\b|\breturn\b|\$boundaryClick'), [int]($entryRunLines.Count -ge 5),
    @($conditionTexts | Where-Object { $_ -match '\$entryRun|\$insideStreakSince' }).Count,
    $pMeasureNodes.Count, [int]$pMeasureChain[0].Cond.Contains('$screen -eq ''inside'''), [int]($pMeasureChain[0].Body -match 'Click-|\bexit\b|\breturn\b'))) '1/$insideStreak -eq 2/0/0/1/0/1/1/0'

# 재무장 예산 (㉺): 증가 1곳 = ⑨ P 결과의 committed(inside)·비이월 분기, 그 안에서 증가 < -ge 2 검사(진단 + exit 4) < M Set < continue. 0 대입은 초기화·INSIDE 전이·이월 전이 셋
$commitIncrement = @($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.UnaryExpressionAst] -and $n.Extent.Text -eq '$expiryInsideCommits++' }, $true))
$commitChain = @(Get-ClauseChain $commitIncrement[0])
$commitBody = [string]$commitChain[0].Body
$commitOrder = @(Get-OrderIndices $commitBody @(@('$expiryInsideCommits++', 'first'), @('if ($expiryInsideCommits -ge 2) {', 'first'), @('Set-AbyssMemberClock -Clock $mClock', 'first'), @('continue', 'after')))
$budgetIf = @(Get-IfByCondition $dAst '$expiryInsideCommits -ge 2')
$zeroAssigns = @(Get-AssignNodes $dAst '$expiryInsideCommits' | Where-Object { $_.Right.Extent.Text -eq '0' })
$zeroPlaces = @($zeroAssigns | ForEach-Object {
    if ($_.Extent.StartOffset -lt $dLoopStart) { 'init' }
    elseif (@(@(Get-ClauseChain $_) | Where-Object { $_.Body.Contains('던전 입장 완료 감지') }).Count) { 'inside' }
    elseif (@(@(Get-ClauseChain $_) | Where-Object { $_.Cond -eq '$carryRequest' }).Count) { 'carry' }
    else { 'other' } }) -join ','
Check-Equal '§3 재무장 예산: 증가 1곳(committed·inside·비게이트 분기) · 증가 < -ge 2(진단 + 단독 exit 4) < M Set < continue · 0 대입 = 초기화·INSIDE 전이·이월 전이' (
  J @($commitIncrement.Count, [int]($commitChain[0].Cond.Contains('$leave.Result -eq ''committed''') -and $commitChain[0].Cond.Contains('$leaveScreen -eq ''inside''') -and $commitChain[0].Cond.Contains('$leaveSource -ne ''gate''')),
    [int](Test-Increasing $commitOrder), [int]($budgetIf.Count -eq 1 -and $budgetIf[0].Clauses[0].Item2.Extent.Text.Contains('Write-LifeDiagnostics') -and ($budgetIf[0].Clauses[0].Item2.Extent.Text -match '(?m)^\s*exit 4\s*$')),
    $zeroPlaces)) '1/1/1/1/init,inside,carry'

# 복구 회전 (㉻): 유효성 블록 안 복구 표식 + 아직 실패 중이면 단독 continue, 연속 수 비움·분류는 else 쪽에만
function Get-ValidityFacts {
  param($Ast, [string]$Code)
  $validity = @(Get-IfByCondition $Ast '$script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial')
  if ($validity.Count -ne 1) { return "블록 수 $($validity.Count)" }
  $thenText = [string]$validity[0].Clauses[0].Item2.Extent.Text
  $elseText = $(if ($null -ne $validity[0].ElseClause) { [string]$validity[0].ElseClause.Extent.Text } else { '' })
  return (J @([int]$thenText.Contains('$turnRecovered = -not $script:screenCaptureFailing'), [int]($thenText -match 'if \(-not \$turnRecovered\) \{\s*continue\s*\}'),
      [int]($thenText -match '\$sweepStreak = 0|Resolve-AbyssMemberScreen'), [int]$elseText.Contains('$sweepStreak = 0'), [int]$elseText.Contains('Resolve-AbyssMemberScreen -PromptVisible'),
      (Get-TextCount $Code 'Resolve-AbyssMemberScreen -PromptVisible')))
}
Check-Equal '§3 복구 회전: 유효성 블록 then = 복구 표식 + 아직 실패 중 continue (연속 수·분류 없음), else = 연속 수 비움·분류 (분류 호출 1곳) (D·P)' (J @((Get-ValidityFacts $dAst $dCode), (Get-ValidityFacts $pAst $pCode))) '1/1/0/1/1/1/1/1/0/1/1/1'
$readFailedTrue = @(Get-AssignNodes $dAst '$boundaryReadFailed' | Where-Object { $_.Right.Extent.Text -eq '$true' })
$readFailedChain = @(Get-ClauseChain $readFailedTrue[0])
$readFailedFalse = @(Get-AssignNodes $dAst '$boundaryReadFailed' | Where-Object { $_.Right.Extent.Text -eq '$false' })
Check-Equal '§3 $boundaryReadFailed: = $true 1곳(재펼침 클릭 직전 판독의 캡처 실패 분기, $boundaryClick 조건 아래) · ⑨ 건너뜀 조건 · ⑨ 서두 = $false · 루프 앞 초기화 (P 에는 없음)' (
  J @($readFailedTrue.Count, $readFailedChain[0].Cond, $readFailedChain[1].Cond, [int]($dCode -match '\$skipDeadline = \(\$boundaryClick -ne ''''\) -and \(-not \$boundaryReadFailed\)\s*\$boundaryReadFailed = \$false'),
    $readFailedFalse.Count, @($readFailedFalse | Where-Object { $_.Extent.StartOffset -lt $dLoopStart }).Count, (Get-TextCount $pCode '$boundaryReadFailed'))) '1/$boundaryClick -eq ''reexpand''/$script:screenCaptureFailing -or $script:captureFailSerial -ne $freshSerial/1/2/1/0'
function Get-FreshFailFacts {
  # 클릭 직전 새 판독의 캡처 실패 분기(D 재펼침 / P 나가기·재펼침 탐침)에는 continue 가 없음 (회전 끝 700ms 대기로 감 - ㉻)
  param($Ast)
  $branches = @(Get-IfByCondition $Ast '$script:screenCaptureFailing -or $script:captureFailSerial -ne $freshSerial')
  $withContinue = @($branches | Where-Object { @($_.Clauses[0].Item2.FindAll({ param($n) $n -is [System.Management.Automation.Language.ContinueStatementAst] }, $true)).Count -gt 0 }).Count
  return (J @($branches.Count, $withContinue))
}
Check-Equal '§3 클릭 직전 판독의 캡처 실패 분기: D 1곳·P 2곳, 모두 continue 없음' (J @((Get-FreshFailFacts $dAst), (Get-FreshFailFacts $pAst))) '1/0/2/0'

# 탐침 복구 표식 (교대 모양 - ㉻): $freezeRecovered 대입은 초기화·동결 블록·표식 블록 셋, 표식 블록 안 $turnRecovered = $true
function Get-FreezeMarkerFacts {
  param($Ast, $WhileNode)
  $assigns = @(Get-AssignNodes $Ast '$freezeRecovered')
  $places = @($assigns | ForEach-Object {
      $chain = @(Get-ClauseChain $_)
      if ($_.Extent.StartOffset -lt $WhileNode.Extent.StartOffset) { "init:$($_.Right.Extent.Text)" }
      elseif ($chain.Count -and $chain[0].Cond -eq '$script:screenCaptureFailing') { "freeze:$($_.Right.Extent.Text)" }
      elseif ($chain.Count -and $chain[0].Cond -eq '$freezeRecovered') { "marker:$($_.Right.Extent.Text)" }
      else { 'other' } }) -join ','
  $marker = @(Get-IfByCondition $Ast '$freezeRecovered')
  return (J @($places, $marker.Count, [int]($marker.Count -eq 1 -and $marker[0].Clauses[0].Item2.Extent.Text.Contains('$turnRecovered = $true'))))
}
Check-Equal '§3 탐침 복구 표식: $freezeRecovered 대입 = 초기화 $false · 동결 블록 -not 플래그 · 표식 블록 $false, 표식 블록 1곳에 $turnRecovered = $true (D·P)' (
  J @((Get-FreezeMarkerFacts $dAst $dWhiles[0]), (Get-FreezeMarkerFacts $pAst $pWhiles[0]))) 'init:$false,freeze:-not $script:screenCaptureFailing,marker:$false/1/1/init:$false,freeze:-not $script:screenCaptureFailing,marker:$false/1/1'

# exit 모양·시계 헬퍼·호출 범위
function Get-ExitShape { param($Ast, [string]$Code) J @(@($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count, [regex]::Matches($Code, '(?m)^\s*exit \d+\s*$').Count) }
$dExitShape = @((Get-ExitShape $dAst $dCode).Split('/'))
$pExitShape = @((Get-ExitShape $pAst $pCode).Split('/'))
Check-True '§3 D·P 의 exit 는 전부 줄 단독 (ExitStatementAst 수 = 줄 단독 exit 수 - D 는 인계·정지 경로 여러 곳, P 는 0)' (
  ($dExitShape[0] -eq $dExitShape[1]) -and ([int]$dExitShape[0] -ge 20) -and ($pExitShape[0] -eq '0') -and ($pExitShape[1] -eq '0')) (J @($dExitShape + $pExitShape))
$clockHelperNames = @('New-AbyssMemberClock', 'Update-AbyssMemberClockFreeze', 'Set-AbyssMemberClock', 'Suspend-AbyssMemberClock', 'Resume-AbyssMemberClock', 'Test-AbyssMemberClockExpired')
$clockCode = @{}
foreach ($name in $clockHelperNames) { $clockCode[$name] = Remove-SourceComments $sourceDefs[$name] }
Check-True '§3 Set-AbyssMemberClock 본문: 마감·양보 기준값·실패 기준값 3줄이 짝으로' (
  $clockCode['Set-AbyssMemberClock'] -match '\$Clock\.Deadline = \(Get-Date\)\.AddMilliseconds\(\$setMs\)\s*\$Clock\.SeenYieldMs = \[double\]\$script:userYieldTotalMs\s*\$Clock\.SeenFailMs = Get-CaptureFailTotalMs') ''
$adjustedCalls = @($clockHelperNames | ForEach-Object { "$($_):$(Get-TextCount $clockCode[$_] 'Get-FreezeAdjustedDeadline')" }) + @("D:$(Get-TextCount $dCode 'Get-FreezeAdjustedDeadline')", "P:$(Get-TextCount $pCode 'Get-FreezeAdjustedDeadline')")
$suspendText = $clockCode['Suspend-AbyssMemberClock']
Check-Equal '§3 Get-FreezeAdjustedDeadline 호출은 새 시계 헬퍼 집합 + D·P 범위에서 Update-AbyssMemberClockFreeze 1곳뿐, Suspend(비초기화 경로)·만료 판정이 그것을 부름, D·P 에 (Get-Date).AddSeconds( · .Deadline = 직접 대입 0' (
  J @(($adjustedCalls -join ','), [int]($suspendText.IndexOf('Update-AbyssMemberClockFreeze -Clock $Clock') -gt $suspendText.IndexOf('if ($Reset) {')), (Get-TextCount $clockCode['Test-AbyssMemberClockExpired'] 'Update-AbyssMemberClockFreeze -Clock $Clock'),
    (Get-TextCount ($dCode + $pCode) '(Get-Date).AddSeconds('), [regex]::Matches($dCode + $pCode, '\.Deadline\s*=').Count)) 'New-AbyssMemberClock:0,Update-AbyssMemberClockFreeze:1,Set-AbyssMemberClock:0,Suspend-AbyssMemberClock:0,Resume-AbyssMemberClock:0,Test-AbyssMemberClockExpired:0,D:0,P:0/1/1/0/0'
Check-Equal '§3 D·P 에 Invoke-AbyssExitClick · Test-ExitButton · Invoke-ClickUntil · throw 0건, 입장 직후 키 D 1곳(P 0), 경계 준비 클릭 D 1곳(P 0), 접기 클릭 P 1곳(D 0), (743,654)·(515,654) 리터럴 0건' (
  J @((Get-TextCount ($dCode + $pCode) 'Invoke-AbyssExitClick'), (Get-TextCount ($dCode + $pCode) 'Test-ExitButton'), (Get-TextCount ($dCode + $pCode) 'Invoke-ClickUntil'), [regex]::Matches($dCode + $pCode, '\bthrow\b').Count,
    (Get-TextCount $dCode 'Invoke-AfterEntryKeys'), (Get-TextCount $pCode 'Invoke-AfterEntryKeys'), (Get-TextCount $dCode '-ReferenceX $ptPartyEnter[0]'), (Get-TextCount $pCode '-ReferenceX $ptPartyEnter[0]'),
    (Get-TextCount $pCode '-ReferenceX $ptMemberPanelCollapse[0]'), (Get-TextCount $dCode '-ReferenceX $ptMemberPanelCollapse[0]'), [regex]::Matches($dCode + $pCode, '743\s*,\s*654|515\s*,\s*654').Count)) '0/0/0/0/1/0/1/0/1/0/0'
# 앵커 클릭 배선 (설계 2.7 - 앵커 단어 중심, 고정 좌표 폴백 없음): D 재펼침·P 탐침 클릭은 클릭 직전 새 판독이 고른 앵커 단어의 .X/.Y 를 넘깁니다 - 앵커 대입은
# 1곳씩(패널 none 일 때만 새 단어 판독의 Select-AbyssEntryWaitingAnchor), 클릭도 1곳씩(앵커 null 검사의 else 쪽). 그리고 D·P 의 어떤 Click-GamePoint 도 상수 인자
# (숫자·문자열 리터럴 - 매개변수·콜론·위치 인자 모두)를 넘기지 않습니다. 위 리터럴 정규식은 '743,654' 쉼표 모양만 봐서, 매개변수 모양
# '-ReferenceX 743 -ReferenceY 654' 의 고정 좌표 클릭 변이(D·P 각각)가 살아남았습니다 (변이 검증 2026-10-01 - 행동 짝은 A6′·B10′)
function Get-ClickArgText {
  # Click-GamePoint 호출 하나의 -ReferenceX·-ReferenceY 인자 원문 'X|Y' (매개변수 이름 뒤 요소, 또는 콜론 모양 '-ReferenceX:값' 의 인자)
  param($Command)
  $elements = @($Command.CommandElements); $xText = ''; $yText = ''
  for ($i = 0; $i -lt $elements.Count; $i++) {
    if ($elements[$i] -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
    $argument = $(if ($null -ne $elements[$i].Argument) { $elements[$i].Argument } elseif ($i + 1 -lt $elements.Count) { $elements[$i + 1] } else { $null })
    if ($null -eq $argument) { continue }
    if ($elements[$i].ParameterName -eq 'ReferenceX') { $xText = [string]$argument.Extent.Text }
    elseif ($elements[$i].ParameterName -eq 'ReferenceY') { $yText = [string]$argument.Extent.Text }
  }
  return "$xText|$yText"
}
function Get-ConstantArgClickCount {
  # 인자에 상수(ConstantExpressionAst - 숫자·문자열 리터럴)가 직접 있는 Click-GamePoint 호출 수. 첫 요소(명령 이름)는 빼고, 매개변수 요소는 콜론 모양의 인자를 봅니다
  param($Ast)
  return @(Get-CommandNodes $Ast 'Click-GamePoint' | Where-Object {
      @(@($_.CommandElements) | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.CommandParameterAst]) { $_.Argument } else { $_ } } |
        Where-Object { $_ -is [System.Management.Automation.Language.ConstantExpressionAst] }).Count -gt 0 }).Count
}
function Get-AnchorClickFacts {
  # 앵커 변수 하나의 배선 사실: 앵커 .X|.Y 클릭 수 · 그 클릭의 첫 조건 절이 앵커 null 검사의 else · 사슬에 entry-waiting 분기 1개 · 앵커 대입 수 · 대입 우변
  param($Ast, [string]$Anchor)
  $anchorClicks = @(Get-CommandNodes $Ast 'Click-GamePoint' | Where-Object { (Get-ClickArgText $_) -eq "`$$Anchor.X|`$$Anchor.Y" })
  $anchorChain = @(if ($anchorClicks.Count -eq 1) { Get-ClauseChain $anchorClicks[0] })
  $anchorAssigns = @(Get-AssignNodes $Ast "`$$Anchor")
  return (J @($anchorClicks.Count, [int]($anchorChain.Count -gt 0 -and $anchorChain[0].IsElse -and $anchorChain[0].Cond -eq "`$null -eq `$$Anchor"),
      @($anchorChain | Where-Object { (-not $_.IsElse) -and $_.Cond.Contains('$screen -eq ''entry-waiting''') }).Count, $anchorAssigns.Count,
      [int]($anchorAssigns.Count -eq 1 -and $anchorAssigns[0].Right.Extent.Text -eq '$(if ($freshPanel -eq ''none'') { Select-AbyssEntryWaitingAnchor -Words $freshWords } else { $null })')))
}
Check-Equal '§3 앵커 클릭(D 재펼침 $reexpandAnchor · P 탐침 $probeAnchor): 앵커 .X/.Y 클릭 1곳(앵커 null 검사의 else, entry-waiting 분기 안) · 앵커 대입 1곳 = 패널 none 일 때만 새 단어 판독의 Select-AbyssEntryWaitingAnchor' (
  J @((Get-AnchorClickFacts $dAst 'reexpandAnchor'), (Get-AnchorClickFacts $pAst 'probeAnchor'))) '1/1/1/1/1/1/1/1/1/1'
Check-Equal "§3 D·P 의 Click-GamePoint 에 상수 인자 0건(매개변수·콜론·위치 인자 - 고정 (743,654)·(744,654)·(515,654) 클릭 금지) · 매개변수 모양 '-ReferenceX 743|744|515 / -ReferenceY 654' 0건" (
  J @((Get-ConstantArgClickCount $dAst), (Get-ConstantArgClickCount $pAst), [regex]::Matches($dCode + $pCode, '-ReferenceX:?\s*[''"]?(743|744|515)\b|-ReferenceY:?\s*[''"]?654\b').Count)) '0/0/0'
$collapseClick = @(Get-CommandNodes $pAst 'Click-GamePoint' | Where-Object { $_.Extent.Text.Contains('$ptMemberPanelCollapse[0]') })
Check-True "§3 P 접기 클릭의 조건 사슬에 'ready-available' 과 보상 위 판별(`$overReward)이 함께" (
  @(@(Get-ClauseChain $collapseClick[0]) | Where-Object { (-not $_.IsElse) -and $_.Cond.Contains('''ready-available''') -and $_.Cond.Contains('$overReward') }).Count -eq 1) ''
Check-True "§3 'left' 블록 모양 = revive ⑩ 파티원 정규식 (left → [완료] 원인 조각 → exit 4)" (
  $dCode -match "(?s)if \(\`$clearOutcome -eq 'left'\) \{\s*\r?\n\s*\`$leaveCause = [^\r\n]*\r?\n\s*Write-RunLog `"\[완료\] 파티원: \`$\{leaveCause\} 던전을 나왔습니다[^\r\n]*자동 재입장 흐름이 없어[^\r\n]*`"\s*\r?\n\s*exit 4") ''

# 경계 인계 exit 0 (09-30 결정 D1·리뷰1): 문구 종류별 개수와 조건 사슬
$exitZeroRows = @(foreach ($exitNode in @($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] -and $null -ne $n.Pipeline -and $n.Pipeline.Extent.Text -eq '0' }, $true))) {
    $block = $exitNode.Parent
    $prefix = $dCode.Substring($block.Extent.StartOffset, $exitNode.Extent.StartOffset - $block.Extent.StartOffset)
    $logMatches = [regex]::Matches($prefix, 'Write-RunLog\s+(?:"([^"]*)"|''((?:[^'']|'''')*)'')')
    $logText = $(if ($logMatches.Count) { $last = $logMatches[$logMatches.Count - 1]; if ($last.Groups[1].Success) { $last.Groups[1].Value } else { $last.Groups[2].Value } } else { '' })
    $kind = $(if ($logText.Contains('준비 완료를 누르고')) { 'ready-sent' } elseif ($logText.Contains('보내지 못해(커서 미확인 3회)')) { 'ready-cursor' } elseif ($logText.Contains('다시 펼쳐지지 않아')) { 'reexpand-stall' }
      elseif ($logText.Contains('위치를 확인하지 못해')) { 'reexpand-check' } elseif ($logText -match '보상 화면에서 다음 워커가|준비 패널은 다음 워커가 확인해|이미 준비된 다음 판을|재매칭 중인 다음 판을|다음 판 입장을 확인했습니다') { 'handoff' }
      elseif ($logText.Contains('나가기로 필드에 나와 마칩니다')) { 'left' } else { "other:$logText" })
    @{ Kind = $kind; Chain = @(Get-ClauseChain $exitNode) }
  })
function Get-KindCount { param([string]$Kind) @($exitZeroRows | Where-Object { $_.Kind -eq $Kind }).Count }
function Test-KindChain { param([string]$Kind, [string]$Pattern) return (@($exitZeroRows | Where-Object { $_.Kind -eq $Kind } | Where-Object { -not (@($_.Chain | Where-Object { (-not $_.IsElse) -and $_.Cond -match $Pattern }).Count) }).Count -eq 0) }
$readySent = @($exitZeroRows | Where-Object { $_.Kind -eq 'ready-sent' })
Check-Equal "§3 exit 0 문구 종류: 준비 전송 1 · 준비 커서 소진 2 · 재펼침 소진 2 · 위치 확인 실패 2 · 비준비 신호 인계 5(보상·ready-other·준비됨·재매칭·inside) · 'left' 1 · 그 밖 0" (
  J @((Get-KindCount 'ready-sent'), (Get-KindCount 'ready-cursor'), (Get-KindCount 'reexpand-stall'), (Get-KindCount 'reexpand-check'), (Get-KindCount 'handoff'), (Get-KindCount 'left'),
    @($exitZeroRows | Where-Object { $_.Kind -like 'other*' }).Count)) '1/2/2/2/5/1/0'
Check-Equal "§3 exit 0 ①~④: '준비 완료를 누르고' 는 경계 준비 클릭의 전송 참 분기 안에만 · 커서 소진 exit 는 `$readyCursorMisses -ge 3 · 재펼침 소진은 전송 2/커서 3 · 위치 확인 실패는 `$reexpandCheckMisses -ge 3 조건 안에만" (
  J @($readySent[0].Chain[0].Cond, $readySent[0].Chain[1].Cond, [int](Test-KindChain 'ready-cursor' '\$readyCursorMisses -ge 3'),
    [int](Test-KindChain 'reexpand-stall' '\$reexpandSends -ge 2|\$reexpandCursorMisses -ge 3'), [int](Test-KindChain 'reexpand-check' '\$reexpandCheckMisses -ge 3'))) '$boundaryClick -eq ''ready''/$script:lastClickPerformed/1/1/1'
Check-Equal '§3 exit 0 ②: user-active 분기(경계 준비·재펼침)와 재펼침 클릭 직전 판독의 캡처 실패·사용자 조작 분기에는 exit 0 없음' (
  @($exitZeroRows | Where-Object { @($_.Chain | Where-Object { (-not $_.IsElse) -and $_.Cond -match "lastClickSkipReason -eq 'user-active'|-ne \`$freshSerial|Test-UserRecentlyActive" }).Count }).Count) 0
$checkMissIncrement = @($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.UnaryExpressionAst] -and $n.Extent.Text -eq '$reexpandCheckMisses++' }, $true))
$checkMissChain = @(Get-ClauseChain $checkMissIncrement[0])
Check-True '§3 $reexpandCheckMisses 증가 1곳 - 같은 분기의 캡처 실패(플래그·일련번호) 검사와 사용자 조작(Test-UserRecentlyActive·양보 누적) 검사 뒤(else)의 앵커 없음 분기에만' (
  ($checkMissIncrement.Count -eq 1) -and ($checkMissChain[0].Cond -eq '$null -eq $reexpandAnchor') -and $checkMissChain[1].IsElse -and
  $checkMissChain[1].Cond.Contains('$script:screenCaptureFailing') -and $checkMissChain[1].Cond.Contains('-ne $freshSerial') -and $checkMissChain[1].Cond.Contains('Test-UserRecentlyActive') -and $checkMissChain[1].Cond.Contains('-ne $freshYieldMs')) (J @($checkMissIncrement.Count, $checkMissChain[0].Cond))
$boundaryAssigns = @(Get-AssignNodes $dAst '$boundaryClick' | Where-Object { $_.Right.Extent.Text -ne "''" })
$boundaryFacts = @($boundaryAssigns | ForEach-Object {
    $chain = @(Get-ClauseChain $_)
    $inClear = (@($chain | Where-Object { $_.Cond -eq '$phase -eq ''clear''' }).Count -eq 1)
    $budget = $(if ($_.Right.Extent.Text -eq "'ready'") { @($chain | Where-Object { $_.Cond -eq '$readyCursorMisses -lt 3' }).Count } else { @($chain | Where-Object { $_.Cond -eq '$reexpandSends -lt 2 -and $reexpandCursorMisses -lt 3 -and $reexpandCheckMisses -lt 3' }).Count })
    "$($_.Right.Extent.Text):$([int]$inClear):$budget" }) -join ','
Check-Equal "§3 ⑨ 건너뜀 표식: 비어 있지 않은 `$boundaryClick 대입은 ⑧(phase 'clear') 안 예산 조건 아래 'ready'·'reexpand' 둘뿐" $boundaryFacts "'ready':1:1,'reexpand':1:1"
function Get-MismatchContinue { param($Ast, [string]$Condition) $ifs = @(Get-IfByCondition $Ast $Condition); return (J @($ifs.Count, @($ifs | ForEach-Object { $_.Clauses[0].Item2.FindAll({ param($n) $n -is [System.Management.Automation.Language.ContinueStatementAst] }, $true) }).Count)) }
Check-Equal '§3 판독 불일치(예산을 쓰는) 분기에 continue 없음 - D 재펼침·P 재펼침 탐침 (회전 끝 700ms 대기)' (J @((Get-MismatchContinue $dAst '$null -eq $reexpandAnchor'), (Get-MismatchContinue $pAst '$null -eq $probeAnchor'))) '1/0/1/0'
$touchIf = @($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true) | ForEach-Object { $_.Clauses | Where-Object { $_.Item1.Extent.Text -eq '$screen -eq ''prompt''' } })
$touchBody = $(if ($touchIf.Count -eq 1) { [string]$touchIf[0].Item2.Extent.Text } else { '' })
Check-True '§3 S 터치 분기 안 순서: Test-DungeonClearPrompt < Get-AbyssPanelKind < Click-GamePoint (패널이 마지막 게이트)' (
  ($touchIf.Count -eq 1) -and (Test-Increasing @(Get-OrderIndices $touchBody @(@('Test-DungeonClearPrompt', 'first'), @('Get-AbyssPanelKind', 'first'), @('Click-GamePoint', 'first'))))) "절 수 $($touchIf.Count)"

# 퇴장 전이 배선 (09-30 리뷰1 P1-1)
$pEvents = Get-EventNodes $pAst
$dEvents = Get-EventNodes $dAst
$leftReturn = @($pAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.ReturnStatementAst] -and $n.Extent.Text.Contains('Result = ''left''') }, $true))
Check-Equal "§3 P 'left' 반환 1곳 = 전이 함수 반환이 'left' 인 분기 안 (전이 판정은 'sample' 1곳의 반환), P 에 자체 필드 연속 판정(`$fieldStreak) 0" (
  J @($leftReturn.Count, @(Get-ClauseChain $leftReturn[0])[0].Cond, [int]$pCode.Contains('$transitionVerdict = Update-AbyssMemberLeaveTransition -Transition $leaveTransition -Event ''sample'''),
    (Get-TextCount $pCode '$fieldStreak'), (Get-TextCount $pCode 'Result = ''left'''))) '1/$transitionVerdict -eq ''left''/1/0/1'
function Get-EventChainHead { param([string]$EventName) $nodes = @($pEvents[$EventName]); if ($nodes.Count -ne 1) { return "수 $($nodes.Count)" }; $chain = @(Get-ClauseChain $nodes[0]); return $chain[0].Cond }
Check-Equal "§3 P 전이 사건: 'leave-sent'·'collapse-sent'·'probe-sent' 는 각 1곳, 모두 그 클릭의 전송 참(`$script:lastClickPerformed) 분기 안" (
  J @((Get-EventChainHead '''leave-sent'''), (Get-EventChainHead '''collapse-sent'''), (Get-EventChainHead '''probe-sent'''))) '$script:lastClickPerformed/$script:lastClickPerformed/$script:lastClickPerformed'
$interruptChain = @(Get-ClauseChain @($pEvents['''interrupt'''])[0])
$sampleYieldAssigns = @(Get-AssignNodes $pAst '$sampleYieldMs')
$sampleSerialAssigns = @(Get-AssignNodes $pAst '$sampleFailSerial')
function Get-BaselinePlaces { param([object[]]$Assigns) (@($Assigns | ForEach-Object { if ($_.Extent.StartOffset -lt $pLoopStart) { 'head' } elseif (@(Get-ClauseChain $_)[0].Cond -match '-ne \$sampleYieldMs') { 'interrupt' } else { 'other' } }) -join ',') }
Check-Equal "§3 P 'interrupt' 1곳 = 유효 표본(유효성 else) 안 연속성 블록(양보 누적·일련번호를 두 기준값과 비교, 같은 블록에 `$readyKnown = `$false), 두 기준값 대입은 P 서두와 그 블록뿐" (
  J @(@($pEvents['''interrupt''']).Count, [int]($interruptChain[0].Cond -match '\$script:userYieldTotalMs -ne \$sampleYieldMs' -and $interruptChain[0].Cond -match '\$script:captureFailSerial -ne \$sampleFailSerial'),
    [int]$interruptChain[0].Body.Contains('$readyKnown = $false'), [int]($interruptChain[1].IsElse -and $interruptChain[1].Cond.Contains('-ne $turnSerial')),
    (Get-BaselinePlaces $sampleYieldAssigns), (Get-BaselinePlaces $sampleSerialAssigns))) '1/1/1/1/head,interrupt/head,interrupt'
Check-Equal "§3 P 'sweep' 1곳(스윕 참 분기) · 'sample' 1곳 · 'yield' 0건(D·P) · D 에 전이 호출 0 · 동결 블록 안 전이 호출 0" (
  J @(@($pEvents['''sweep''']).Count, [int](@(Get-ClauseChain @($pEvents['''sweep'''])[0] | Where-Object { $_.Cond -match 'Invoke-PurchasePopupSweep' }).Count -eq 1), @($pEvents['''sample''']).Count,
    (Get-TextCount ($dCode + $pCode) '-Event ''yield'''), $dEvents.Count, [int]($pFreeze.Contains('Update-AbyssMemberLeaveTransition')))) '1/1/1/0/0/0'

# P 뒤 M 순서 (리뷰 의견): P 결과가 aborted·committed 이고 이어가는 분기(continue)마다 M Set 이 continue 앞, inside 분기는 준비 시계 폐기·에피소드 종료도 앞
$continueRows = @(foreach ($continueNode in @($dAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.ContinueStatementAst] }, $true))) {
    $chain = @(Get-ClauseChain $continueNode)
    if (-not (@($chain | Where-Object { (-not $_.IsElse) -and $_.Cond -match '\$leave\.Result -eq ''(aborted|committed)''' }).Count)) { continue }
    $block = $continueNode.Parent
    $prefix = $dCode.Substring($block.Extent.StartOffset, $continueNode.Extent.StartOffset - $block.Extent.StartOffset)
    $insideCase = (@($chain | Where-Object { $_.Cond.Contains('$leaveScreen -eq ''inside''') }).Count -gt 0) -or $prefix.Contains('if ($leaveScreen -eq ''inside'')')
    $ok = $prefix.Contains('Set-AbyssMemberClock -Clock $mClock') -and ((-not $insideCase) -or ($prefix.Contains('Suspend-AbyssMemberClock -Clock $rClock -Reset') -and $prefix.Contains('$episodeActive = $false')))
    "$([int]$ok)"
  })
$carryAssign = @(Get-AssignNodes $dAst '$carryRequest' | Where-Object { $_.Right.Extent.Text -eq '$leaveStopReason' })
$carryPrefix = $(if ($carryAssign.Count -eq 1) { $dCode.Substring($carryAssign[0].Parent.Extent.StartOffset, $carryAssign[0].Extent.StartOffset - $carryAssign[0].Parent.Extent.StartOffset) } else { '' })
Check-Equal '§3 P 뒤 M 순서: aborted·committed 로 이어가는 continue 6곳 모두 M Set 이 앞(inside 분기는 준비 시계 폐기·에피소드 종료도 앞), 이월 전이(committed@CLEAR)도 M Set 이 앞' (
  J @($continueRows.Count, @($continueRows | Where-Object { $_ -eq '1' }).Count, $carryAssign.Count, [int]($carryPrefix.Contains('Set-AbyssMemberClock -Clock $mClock')))) '6/6/1/1'
$removeNodes = @(@(Get-CommandNodes $dAst 'Remove-Item') + @(Get-CommandNodes $pAst 'Remove-Item'))
$removeOk = @($removeNodes | Where-Object { $_.Extent.Text -eq 'Remove-Item -LiteralPath $safeStopFlagPath -Force -ErrorAction SilentlyContinue' -and
    (@(Get-ClauseChain $_ | Where-Object { (-not $_.IsElse) -and $_.Cond.Contains('Test-Path -LiteralPath $safeStopFlagPath') }).Count -gt 0) })
Check-Equal '§3 안전 중지 소비: Remove-Item 은 P 3곳(D 0) 모두 -ErrorAction SilentlyContinue 형태이고 Test-Path 참 분기 안' (J @(@(Get-CommandNodes $dAst 'Remove-Item').Count, $removeNodes.Count, $removeOk.Count)) '0/3/3'
# 시간 지정 입력 (시간 지정 '그 판까지' 설계 4.2·8.1): UNTIL 은 D 서두 1곳(루프 앞), 사이클 추정치 env 는 0곳. $memberUntil 은 대입·G 인자·로그 서식과
# 경계 인계 12곳의 종료 코드 11 분기('if ($null -ne $memberUntil) {' 다음 줄 exit 11)에만 씁니다 - 그 밖에서 쓰면 넷째 값이 실패합니다.
# 셋째 값은 UNTIL 만 봅니다 (옛 단언은 사이클 추정치 위치도 함께 봤는데, 참조가 없으면 IndexOf 가 -1 이라 '루프 앞' 이 빈 참이 됨)
$untilUses = [regex]::Matches($dCode, '\$memberUntil\b')
$untilAllowed = [regex]::Matches($dCode, '\$memberUntil = Get-LifeUntilDeadline|\$null -ne \$memberUntil\) \{ Write-RunLog|-UntilTime \$memberUntil|\$memberUntil\.ToString\(''HH:mm''\)|\$null -ne \$memberUntil\) \{\s*exit 11')
$untilEnvAt = $dCode.IndexOf('HONEYNOGI_UNTIL_TIME')
Check-Equal '§3 UNTIL 환경 변수 참조는 D 서두 1곳(루프 앞)·사이클 추정치 env 0곳, $memberUntil 은 대입·G 인자·로그 서식·경계 인계의 11 분기에만' (
  J @((Get-TextCount $dCode 'HONEYNOGI_UNTIL_TIME'), (Get-TextCount $dCode 'HONEYNOGI_CYCLE_ESTIMATE_SEC'), [int](($untilEnvAt -ge 0) -and ($untilEnvAt -lt $dLoopStart)),
    [int]($untilUses.Count -eq $untilAllowed.Count), (Get-TextCount $dCode '-UntilTime $memberUntil'))) '1/0/1/1/2'
# 경계 인계 → 시간 지정이면 exit 11 (설계 4.4): D 의 exit 0 13곳 가운데 'left'(마지막 - P 뒤)를 뺀 12곳 바로 앞에 줄 단독 11 블록이 있습니다. 블록 안에는
# 로그·주석을 두지 않습니다 - 위 exit 0 문구 분류가 exit 0 앞의 마지막 Write-RunLog 를 사유로 보고, 하니스 센티널은 줄 단독 exit 만 바꿉니다
# (한 줄 'if (…) { exit 11 }' 이면 센티널 3중 단언이 막음). 'left' 의 exit 0 은 [완료] 로그 바로 다음 줄이어야 합니다 - 앞에 11 블록이 끼면 마지막 판 뒤에도
# GUI 가 지정 시각을 보지 않고 다음 워커를 띄웁니다
$exit11Lines = [regex]::Matches($dCode, '(?m)^\s*exit 11\s*$').Count
$exit11Blocks = [regex]::Matches($dCode, 'if \(\$null -ne \$memberUntil\) \{\s*\r?\n\s*exit 11\s*\r?\n\s*\}\s*\r?\n\s*exit 0\b').Count
$exit0Lines = [regex]::Matches($dCode, '(?m)^\s*exit 0\s*$').Count
$leftExitDirect = [regex]::Matches($dCode, '라 나가기로 필드에 나와 마칩니다"\s*\r?\n\s*exit 0\b').Count
Check-Equal "§3 exit 11: 줄 단독 12곳 = '11 블록 + 다음 줄 exit 0' 모양 12곳, exit 0 은 13곳 그대로, 'left' 의 exit 0 은 [완료] 로그 바로 다음 줄 1곳 (앞에 11 블록 없음)" (
  J @($exit11Lines, $exit11Blocks, $exit0Lines, $leftExitDirect)) '12/12/13/1'
# START 시간 문구 5종 (설계 4.6 - 'start-g' 의 비안전중지 갈래라 시간 사유에서만 나옴): 새 원문이 각 1곳, 옛 '한 판을 마칠 시간' 은 0곳 (회귀 R-11).
# 행동은 X-T·X-TU·X-TP·X-TF·X-TN 이 하나씩 지킵니다 (원문은 소스 그대로의 큰따옴표 문자열 - ${…} 는 확장하지 않은 글자)
$startTimePhrases = @(
  '"[완료] 파티원: ${reasonLabel} 도달 - 다음 판에 참가하지 않고 나가기로 필드에 나와 마칩니다"',
  '"[완료] 파티원: ${reasonLabel} 도달 - 나갔지만 나가기 뒤 필드를 확인하지 못해 마칩니다"',
  '"[완료] 파티원: 필드로 보이는 화면이라 누르지 않고 마칩니다 (필드 미확정) - ${reasonLabel} 도달"',
  '"[완료] 파티원: ${reasonLabel} 도달 - 필드 위 준비 패널이라 준비를 누르지 않고 마칩니다"',
  '"[완료] 파티원: ${reasonLabel} 도달 - 나갈 수 없는 화면이라(${leaveLabel}) 누르지 않고 마칩니다"')
Check-Equal "§3 START 시간 문구 5종 각 1곳(소스 원문) · 옛 '한 판을 마칠 시간' 0곳" (J @((@($startTimePhrases | ForEach-Object { Get-TextCount $dCode $_ }) -join ','), (Get-TextCount $dCode '한 판을 마칠 시간'))) '1,1,1,1,1/0'

# 디스패치 (2.11) - 워커 본문은 크기 때문에 토큰으로 한 번에 주석을 뺀 사본($workerCode)을 씁니다. 그 사본과 Remove-CommentsByTokens 정의는 §0 앞에서 만듭니다
# (§0 의 0건 단언이 먼저 쓰기 때문 - 시간 지정 '그 판까지' 설계 리뷰 1차 P3)
Check-True '§3 디스패치: 기타 분기 뒤·이벤트 정리 앞, 조건에 -not customSpecInvalid, 호출 뒤 throw (옛 디스패치·옛 S 터치 헬퍼·시작 패널 대기의 파티원 제외 항 0건)' (
  ($workerCode.IndexOf('Invoke-NyanMerchantRun -Game $game') -lt $workerCode.IndexOf('Invoke-AbyssPartyMemberCycle -Game $game')) -and
  ($workerCode.IndexOf('Invoke-AbyssPartyMemberCycle -Game $game') -lt $workerCode.IndexOf('if (Clear-EventOverlay -Game $game) {')) -and
  ($workerCode -match '\$abyssPartyMemberRun = \(\(-not \$script:customMode\) -and \(-not \$script:customSpecInvalid\) -and[\s\S]{0,300}?\$abyssMatching -eq ''파티\(파티원\)''\)\s*if \(\$abyssPartyMemberRun\) \{\s*Invoke-AbyssPartyMemberCycle -Game \$game\s*throw ''파티원 흐름이 종료 코드 없이 반환됐습니다 - 내부 오류''\s*\}') -and
  ((Get-TextCount $workerCode 'Invoke-AbyssPartyMemberCycle -Game') -eq 1) -and ((Get-TextCount $workerCode 'Invoke-AbyssMemberClearTouch') -eq 0) -and ((Get-TextCount $workerCode '$abyssPartyMemberRun') -eq 2)) (
  J @((Get-TextCount $workerCode 'Invoke-AbyssPartyMemberCycle -Game'), (Get-TextCount $workerCode 'Invoke-AbyssMemberClearTouch'), (Get-TextCount $workerCode '$abyssPartyMemberRun')))

# ── §4 클리어 감시 -MemberMode 배선 (설계 3절) ───────────────────────────────────
$clearWaitCode = Remove-SourceComments ([string]$workerAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Wait-ForDungeonClearScreen' }, $true).Extent.Text)
$clearProbeCode = Remove-SourceComments $sourceDefs['Test-AbyssMemberClearWaitProbe']
Check-Equal '§4 -MemberMode 호출은 워커 전체에 1곳(D 의 INSIDE 구간), 인자 [switch]$MemberMode, 매칭 즉시 반환 0건' (
  J @([regex]::Matches($workerCode, 'Wait-ForDungeonClearScreen\b[^\r\n]*-MemberMode').Count, (Get-TextCount $dCode 'Wait-ForDungeonClearScreen -Game $Game -TimeoutSeconds $timeoutClear -MemberMode'),
    [int]($clearWaitCode -match '\[switch\]\$MemberMode'), (Get-TextCount $clearWaitCode 'return ''matching'''))) '1/1/1/0'
Check-True '§4 패널 분기 첫머리 = 파티원 분기(재매칭 제외, 준비 패널은 HUD 새 판독 + 판독 도중 실패면 반환 안 함) → 반환 없으면 기존 관측(로그 1회 + 2초 + continue)' (
  $clearWaitCode -match 'if \(\$panelKindNow -ne ''none'' -or \$entryWaitingNow\) \{\s*if \(\$MemberMode -and \$panelKindNow -ne ''matching''\) \{\s*\$memberHudNow = \$false\s*if \(-not \$entryWaitingNow\) \{\s*\$memberHudSerial = \$script:captureFailSerial\s*\$memberHudNow = Test-HomeEndEscHud -Game \$Game\s*if \(\$script:screenCaptureFailing -or \$script:captureFailSerial -ne \$memberHudSerial\) \{ \$memberHudNow = \$true \}\s*\}\s*\$memberExit = Resolve-AbyssMemberClearWaitExit -PanelKind \$panelKindNow -BottomText \$script:lastClearPromptText -HudVisible \$memberHudNow\s*if \(\$memberExit\) \{[\s\S]{0,400}?return \$memberExit\s*\}\s*\}\s*\$panelWaitKind = [\s\S]{0,1500}?Start-Sleep -Seconds 2\s*continue\s*\}') ''
Check-True "§4 파티원 보상 반환(하단 스태시·HUD 새 판독·일련번호 가드)이 3버튼 보상 판정 'if (Test-ExitButton' 바로 앞" (
  $clearWaitCode -match 'if \(\$MemberMode -and \(Test-AbyssMemberRewardText -Text \$script:lastClearPromptText\)\) \{\s*\$memberRewardSerial = \$script:captureFailSerial\s*\$memberRewardHud = Test-HomeEndEscHud -Game \$Game\s*if \(\(-not \$script:screenCaptureFailing\) -and \$script:captureFailSerial -eq \$memberRewardSerial -and\s*\(Resolve-AbyssMemberClearWaitExit -PanelKind ''none'' -BottomText \$script:lastClearPromptText -HudVisible \$memberRewardHud\) -eq ''member-reward''\) \{[\s\S]{0,300}?return ''member-reward''\s*\}\s*\}\s*if \(Test-ExitButton -Game \$Game\) \{') ''
Check-Equal '§4 본문 두 곳과 마감 탐침이 모두 Resolve-AbyssMemberClearWaitExit 를 부름' (J @((Get-TextCount $clearWaitCode 'Resolve-AbyssMemberClearWaitExit'), [int]((Get-TextCount $clearProbeCode 'Resolve-AbyssMemberClearWaitExit') -ge 1))) '2/1'
Check-True '§4 마감 블록: 최종 탐침의 동결 가드 바로 뒤 파티원 탐침 elseif(탐침만) + 그 탐침 도중 실패 가드 elseif, 그 뒤 기존 보상 전체 화면 닫기' (
  $clearWaitCode -match '\(\(-not \$DungeonMode\) -and \(Test-ExitButton -Game \$Game\) -and -not \(Test-HomeEndEscHud -Game \$Game\)\)\) \{\s*\} elseif \(\$script:screenCaptureFailing -or \(\$script:captureFailSerial -ne \$deadlineSerial\)\) \{\s*\} elseif \(\$MemberMode -and \(Test-AbyssMemberClearWaitProbe -Game \$Game -BottomText \$script:lastClearPromptText\)\) \{\s*\} elseif \(\$script:screenCaptureFailing -or \(\$script:captureFailSerial -ne \$deadlineSerial\)\) \{\s*\} elseif \(Close-QuestRewardScreen') ''

# ── §5 GUI 배선 (설계 4절) ──────────────────────────────────────────────────────
# GUI AST·토큰은 §2 의 GUI 모형 준비에서 이미 파싱했습니다 (같은 것을 씀 - 한 번만 파싱)
$guiCode = Remove-CommentsByTokens $guiAst.Extent.Text $guiTokens
function Get-GuiFunctionCode { param([string]$Name) $fn = $guiAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true); if ($null -eq $fn) { return '' }; return (Remove-SourceComments ([string]$fn.Extent.Text)) }
$nextCycleCode = Get-GuiFunctionCode 'Start-NextCycle'
$startAutomationCode = Get-GuiFunctionCode 'Invoke-StartAutomation'
$memberActiveCode = Get-GuiFunctionCode 'Test-AbyssMemberRunActive'
# Start-NextCycle 의 UNTIL 배선 (시간 지정 '그 판까지' 설계 2.5·8.1 + 설계 리뷰 1차 P2, 생활 확장 설계 v3 2.4): 매 회차 먼저 지우고 →
# 전투 분기(판 끝에서 스스로 판단하는 워커 - 던전·심층·어비스 파티원, Test-WorkerTimeJudgeActive)만 InvariantCulture 'yyyy-MM-dd HH:mm' 으로 넘깁니다.
# 생활에는 넘기지 않습니다(2026-10-02 생활 확장 A안 - GUI 가 사이클이 끝난 뒤 판단). 사이클 추정치 env 는 GUI 전체(주석 뺀 사본)에서 0건 - 워커가 더 읽지 않습니다
Check-True '§5 Start-NextCycle: UNTIL 을 매 회차 먼저 지우고, 생활 분기 없이 전투 분기(시간 지정 + 판 끝 판단 워커)만 InvariantCulture 로 넘김 · 사이클 추정치 env 0건(GUI 전체)' (
  ($nextCycleCode -match '\$env:HONEYNOGI_UNTIL_TIME = ''''\s*if \(\(\$null -ne \$script:targetTime\) -and \(Test-WorkerTimeJudgeActive\)\) \{\s*\$env:HONEYNOGI_UNTIL_TIME = \$script:targetTime\.ToString\(''yyyy-MM-dd HH:mm'', \[Globalization\.CultureInfo\]::InvariantCulture\)\s*\}') -and
  ((Get-TextCount $guiCode 'HONEYNOGI_CYCLE_ESTIMATE_SEC') -eq 0)) "사이클 추정치 env 참조 $(Get-TextCount $guiCode 'HONEYNOGI_CYCLE_ESTIMATE_SEC')곳"
Check-True '§5 Test-AbyssMemberRunActive = 전투 대분류 + 어비스 + 함께하기 + 매칭 파티원 + 비커스텀' (
  $memberActiveCode -match 'return \(\(\$script:mainCategory -eq ''battle''\) -and \$rbCatAbyss\.Checked -and \$rbModeParty\.Checked -and \$rbAbyssPartyMember\.Checked -and \(-not \$script:customActive\)\)') ''
$leaderLines = @('"※ 매칭 ''파티(파티장)'': 파티를 먼저 짠 상태에서 시작하세요.`n" +', '"   입장하기 후 파티원 전원이 준비되면 자동 입장됩니다.`n" +', '"   (인원이 부족해도 채우지 않고 확인 팝업을 넘겨 그대로 도전합니다)`n" +')
$memberLines = @('"※ 매칭 ''파티(파티원)'': 파티를 짠 상태에서 시작하세요 (필드·보상 화면 어디서든).`n" +', '"   파티장이 입장을 요청하면 ''준비 완료''를 누르고 따라 들어가며, 클리어 뒤에는`n" +',
  '"   보상 화면에서 다음 요청을 기다렸다가 ''준비 완료''를 누르고 이어 갑니다`n" +', '"   (준비 패널을 접어 두면 다시 펼침).`n" +',
  '"   마지막 회차·안전 중지·지정 시간, 그리고 파티장 요청이 ''클리어 대기(초)'' 동안 없으면`n" +', '"   ''나가기''로 필드에 나온 뒤 멈춥니다 - 마지막 회차는 파티장 PC 를 먼저 멈추세요."')
$manualOrder = @(Get-OrderIndices $guiCode @(@($leaderLines[0], 'first'), @($leaderLines[1], 'after'), @($leaderLines[2], 'after'), @($memberLines[0], 'after'), @($memberLines[1], 'after'), @($memberLines[2], 'after'), @($memberLines[3], 'after'), @($memberLines[4], 'after'), @($memberLines[5], 'after')))
Check-Equal "§5 설명서: 파티장 문단 3줄 그대로 → 파티원 새 문구 6줄(D1 - 요청마다 '준비 완료' 를 누르고 이어 감, 정지 사유에서만 나가기) 순서대로, 옛 '나가기만 반복' 0건" (
  J @([int](Test-Increasing $manualOrder), (Get-TextCount $guiCode '나가기만 반복'), (Get-TextCount $guiCode '파티를 짠 상태로 캐릭터를 필드에 두고'))) '1/0/0'
$noticePattern = 'if \(Test-AbyssMemberRunActive\) \{ Add-GuiLog "\[안내\] 파티원: 파티장의 입장 요청마다 ''준비 완료''를 누르고 따라 들어갑니다\(클리어 뒤 다음 요청도 같음\)\. 마지막 회차·안전 중지·지정 시간·대기 한도\(클리어 대기 \$\(\[int\]\$numClearWait\.Value\)초\) 초과 때는 ''나가기''로 필드에 나온 뒤 멈춥니다 - 파티장 PC 도 함께 정지해 주세요" \}'
Check-Equal "§5 시작 안내 1줄(반복 설정 뒤, D4 확정 문안 - '준비 완료'를 누르고 따라 들어감) · GUI 전체에 파티원 안내 1곳" (
  J @([regex]::Matches($startAutomationCode, $noticePattern).Count, [int]($startAutomationCode.IndexOf('if ($script:customActive) { $script:targetCycles = 0; $script:targetTime = $null }') -lt $startAutomationCode.IndexOf('if (Test-AbyssMemberRunActive) { Add-GuiLog')),
    (Get-TextCount $guiCode 'Add-GuiLog "[안내] 파티원:'), [int](($memberLines[1] + $memberLines[2]).Contains('''준비 완료''를 누르고') -and $startAutomationCode.Contains('''준비 완료''를 누르고 따라 들어갑니다')))) '1/1/1/1'

if ($fails -gt 0) { "FAIL 합계: $fails"; exit 1 }
'OK 전체 통과'
exit 0
