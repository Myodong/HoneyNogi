# 마지막 판 나가기 기능 진리표 (2026-07-25 - 마지막 판 완료 시 '나가기'로 필드 복귀)
# 본체: mabinogi_gui.ps1 Test-CustomLastRun + Start-NextCycle env / mabinogi_run_once.ps1 14-0 단계
# + 시간 지정 '그 판까지' (2026-10-02, 그 설계 8.2 T3·T3-6): 결과 화면 14-T 의 판단 함수 진리표와 던전 함수 안 배선 - 14-T 가 'last' 면
#   14-0 '나가기' 를 그대로 타고(끝 모양 = 횟수 지정 마지막 판), 'continue' 면 꼬리에서 종료 코드 11 (꼬리 행동은 test_dg_party_reenter T6)
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Test-CustomLastRun')) {
  Invoke-Expression $definition
}
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-DgLastRunExitStep', 'Get-DgTimeVerdict')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 커스텀 마지막 판 판정 (횟수 모드 x 마지막 바퀴 x 마지막 항목일 때만 true) ──
$lastRunCases = @(
  @{ N = '2바퀴 마지막 바퀴 마지막 항목'; R = 'count'; C = 2; L = 2; I = 2; T = 3; E = $true }
  @{ N = '2바퀴 마지막 바퀴 중간 항목';   R = 'count'; C = 2; L = 2; I = 1; T = 3; E = $false }
  @{ N = '2바퀴 첫 바퀴 마지막 항목';     R = 'count'; C = 2; L = 1; I = 2; T = 3; E = $false }
  @{ N = '1바퀴 단일 항목';               R = 'count'; C = 1; L = 1; I = 0; T = 1; E = $true }
  @{ N = '1바퀴 6항목 마지막 (실기 구성)'; R = 'count'; C = 1; L = 1; I = 5; T = 6; E = $true }
  @{ N = '1바퀴 6항목 첫 항목';           R = 'count'; C = 1; L = 1; I = 0; T = 6; E = $false }
  @{ N = '무한 반복은 마지막 없음';       R = 'infinite'; C = 1; L = 9; I = 5; T = 6; E = $false }
  @{ N = '방어: 바퀴 수 0';               R = 'count'; C = 0; L = 1; I = 0; T = 1; E = $false }
  @{ N = '방어: 바퀴 초과 진행도 저장분'; R = 'count'; C = 2; L = 3; I = 2; T = 3; E = $true }
)
foreach ($case in $lastRunCases) {
  Assert-Case "마지막판: $($case.N)" `
    (Test-CustomLastRun -ListRepeat $case.R -ListRepeatCount $case.C -Lap $case.L -Index $case.I -Total $case.T) $case.E
}

# ── 나가기 확인 루프의 한 판독분 판정 (리뷰 2차 리뷰 반영 - 단발 OCR 오판 방지) ──
$exitStepCases = @(
  @{ N = '나가기 팝업 (탐험+계속하)'; H = $false; Q = ''; C = '던전탐험을 계속하시겠습니까?'; R = $false; E = 'popup-exit' }
  @{ N = '팝업이 결과 화면 판독보다 우선'; H = $true; Q = ''; C = '던전탐험을계속하시겠습니까'; R = $true; E = 'popup-exit' }
  @{ N = "'계속하' 조각만으로는 팝업 아님 (느슨 매칭 금지)"; H = $false; Q = ''; C = '계속하'; R = $false; E = 'wait' }
  @{ N = '결과 화면 잔존 = 재클릭'; H = $false; Q = ''; C = ''; R = $true; E = 'reclick' }
  @{ N = '필드 증거 (HUD + 던전 목표 없음)'; H = $true; Q = '반호르 가기'; C = ''; R = $false; E = 'field-evidence' }
  @{ N = 'HUD 있어도 던전 목표(구역) 있으면 보류'; H = $true; Q = '1층 1구역 클리어'; C = ''; R = $false; E = 'wait' }
  @{ N = 'HUD 없음 = 보류'; H = $false; Q = ''; C = ''; R = $false; E = 'wait' }
)
foreach ($case in $exitStepCases) {
  Assert-Case "나가기판정: $($case.N)" `
    (Get-DgLastRunExitStep -HudVisible $case.H -QuestText $case.Q -CenterText $case.C -RetryVisible $case.R) $case.E
}

# ── 결과 화면 시간 지정 판단 14-T (시간 지정 '그 판까지' 설계 8.2 T3) ──
# Get-DgTimeVerdict: 지정 시각 없음 '' (기존 흐름) / 지금 >= 지정 시각 'last' (같은 시각 포함 - 파티원 G 와 같은 -ge,
# 조건 1 '새 판은 지금 < 지정 시각 일 때만') / 그 밖 'continue' ('다시 하기' 로 이어 가고 종료 코드 11). 자정 넘김은 전체 타임스탬프 비교라 그대로 '전'
$timeVerdictUntil = [datetime]'2026-10-01 10:00:00'
$timeVerdictCases = @(
  @{ N = "T3-1 지정 시각 없음(`$null) → '' (기존 흐름)"; U = $null; Now = [datetime]'2026-10-01 12:34:56'; E = '' }
  @{ N = "T3-2 지정 시각 1초 전 → 'continue'"; U = $timeVerdictUntil; Now = [datetime]'2026-10-01 09:59:59'; E = 'continue' }
  @{ N = "T3-3 지정 시각과 같은 시각 → 'last' (같은 시각 포함)"; U = $timeVerdictUntil; Now = [datetime]'2026-10-01 10:00:00'; E = 'last' }
  @{ N = "T3-4 지정 시각 1초 뒤 → 'last'"; U = $timeVerdictUntil; Now = [datetime]'2026-10-01 10:00:01'; E = 'last' }
  @{ N = "T3-5 자정 넘김(10-01 23:50 판단, 10-02 00:30 지정) → 'continue'"; U = [datetime]'2026-10-02 00:30:00'; Now = [datetime]'2026-10-01 23:50:00'; E = 'continue' }
)
foreach ($case in $timeVerdictCases) {
  Assert-Case "시간판단: $($case.N)" (Get-DgTimeVerdict -UntilTime $case.U -Now $case.Now) $case.E
}
# 인자 생략 호출 (14-T 밖에서 부를 일은 없지만 서명 계약): $UntilTime 은 타입 없이 기본값 $null - [datetime] 으로 두면 $null 이 변환 실패로 죽습니다 (규칙 3)
Assert-Case "시간판단: T3-1′ -UntilTime 인자 생략 → '' (타입 없는 기본값 `$null)" (Get-DgTimeVerdict -Now ([datetime]'2026-10-01 12:00:00')) ''

# ── 본체 소스 계약 검사 ──────────────────────────────────────────────────────
$guiSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_gui.ps1') -Raw -Encoding UTF8
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8

Assert-Case 'GUI: 커스텀/비커스텀 두 분기 모두 신호 설정 + 정리 목록 포함' `
  ([regex]::Matches($guiSource, 'HONEYNOGI_LAST_RUN').Count -ge 3) $true
Assert-Case 'GUI: 비커스텀은 시간 지정 아님 + 횟수 모드 조건 포함' `
  ($guiSource -match "HONEYNOGI_LAST_RUN = \`$\(if \(\(\`$null -eq \`$script:targetTime\) -and \(\`$script:targetCycles -gt 0\)") $true
Assert-Case '워커: 신호는 문자열 1 비교로 해석' `
  ($workerSource.Contains("`$script:dgLastRun = ([string]`$env:HONEYNOGI_LAST_RUN -eq '1')")) $true
# ★ 10차: 두 앵커가 **주석 문구**라 주석 한 단어만 바꿔도 실패하고, 반대로 코드 순서를
#   바꿔도 주석이 그대로면 통과했습니다. 코드 사본에서 **실행문**으로 봅니다 (아래 '판독 도중 캡처 실패' 단언).
#   '마지막 판 나가기(14-0)는 은동전 잔량 검사(14-1)보다 앞' 순서는 2026-10-02 맨 아래 던전 시간 배선(T3-6)의 함수 범위 순서
#   단언으로 옮겼습니다 - 옛 단언은 파일 첫 $script:dgLastRun(최상위 신호 대입)과 첫 $ptDgResultExit[0] 을 비교해 늘 참이었습니다
#   (시간 지정 '그 판까지' 설계 8.1·map_tests 2.3)
$workerCodeOnly = (($workerSource -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '워커: 수동 정리 모드는 나가기 제외' `
  ($workerSource -match "if \(\`$script:dgLastRun -and -not \`$script:customCleanupOnly\)") $true
Assert-Case '워커: 필드 확정은 HUD + 퀘스트 추적기 구역 부재 이중 확인' `
  ($workerSource -match "dgLastRun[\s\S]{0,4000}Test-HomeEndEscHud[\s\S]{0,600}rgQuestTracker") $true
Assert-Case '워커: 계속하시겠습니까 팝업은 나가기(Space) 선택' `
  ($workerSource.Contains('나가기(Space) 선택')) $true
Assert-Case '워커: 필드 미확인 시 진단 저장 후 정상 종료 (오류 재시작 방지)' `
  ($workerSource -match "마지막 판 나가기 후 필드 미확인[\s\S]{0,600}exit 0") $true
Assert-Case '워커: 필드 확정은 연속 2회 증거 요구 (단발 OCR 오판 방지)' `
  ($workerSource.Contains('$fieldStreak -ge 2')) $true
# ★ 10차: 이 단언도 **주석 문구**에만 걸려 있었습니다. 가드를 통째로 지워도 통과합니다.
#   계약은 '판독 중 실패가 누적되면 그 회전의 판독분을 버린다'이므로 코드로 못 박습니다.
Assert-Case '워커: 판독 도중 캡처 실패 시 그 판독분 폐기' `
  ([bool]($workerCodeOnly -match '(?s)\$probeFailed = \$false.{0,900}?if \(\$probeFailed\) \{ continue \}')) $true
Assert-Case '워커: 마지막 판 복구는 필드 상태를 복구 완료로 인정' `
  ($workerSource -match "customRecoveryOnly[\s\S]{0,1500}dgLastRun[\s\S]{0,1600}재입장 없이 복구 완료") $true

# ── 던전 시간 지정 배선 (시간 지정 '그 판까지' 설계 8.2 T3-6 - 경합 P2-2·회귀 R-4) ──────────────────────
# 주석 뺀 Invoke-NormalDungeonCycle 사본(함수 범위)으로 봅니다 - 파일 전체로 보면 최상위 신호 대입($script:dgLastRun = …)이나 다른 함수의 같은
# 글자가 먼저 잡혀 순서 단언이 늘 참이 됩니다. 판단은 결과 화면 14-T 한 곳이고 꼬리는 그 값만 씁니다 - 꼬리에서 시각을 다시 보면 14-T 가
# '이어 감' 으로 정해 '다시 하기' 로 파티 재입장한 판 뒤에 꼬리가 '마지막'(코드 0)을 내 GUI 가 멈추고 던전 안에 남습니다 (조건 4)
$ndCode = Remove-SourceComments ([string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Invoke-NormalDungeonCycle')))
$ndTokens = $null; $ndErrors = $null
$ndAst = [System.Management.Automation.Language.Parser]::ParseInput($ndCode, [ref]$ndTokens, [ref]$ndErrors)
$ndLoop = $ndAst.Find({ param($n) $n -is [System.Management.Automation.Language.WhileStatementAst] -and $n.Label -eq 'dgClearCycle' }, $true)
$ndLoopStart = $(if ($ndLoop) { $ndLoop.Extent.StartOffset } else { -1 })
$ndLoopEnd = $(if ($ndLoop) { $ndLoop.Extent.EndOffset } else { -1 })
$timeAssignText = '$dgTimeVerdict = Get-DgTimeVerdict -UntilTime $dgUntil -Now (Get-Date)'
# (1) 순서: 14 안전 중지 < 14-T 판단 < 14-0 '나가기' < 14-1 잔량 < '다시 하기'. 14 뒤 = F9 가 이김(횟수 지정과 같음), 14-1 앞 = 마지막 판에는
#     '다음 판' 잔량 판단이 무의미 (14-1 정지는 코드 4·미계상, 14-0 은 코드 0·계상)
$ndOrderAnchors = @('Invoke-SafeStopExitIfRequested -Game $Game', $timeAssignText, 'if ($script:dgLastRun -and -not $script:customCleanupOnly)',
  'if (-not $script:customMode -and $ndUseCoin)', "'다시 하기' 클릭 - 옵션 화면 복귀 대기")
$ndOrder = @($ndOrderAnchors | ForEach-Object { $ndCode.IndexOf($_) })
$ndOrderOk = ($ndOrder[0] -ge 0)
for ($i = 1; $i -lt $ndOrder.Count; $i++) { if ($ndOrder[$i] -le $ndOrder[$i - 1]) { $ndOrderOk = $false } }
$ndOrderText = $ndOrder -join ','
Assert-Case "던전 시간 배선: 순서 14 안전 중지 < 14-T 판단 < 14-0 나가기 < 14-1 잔량 < 다시 하기 (함수 범위 위치 $ndOrderText)" $ndOrderOk $true
# (2) 14-T 대입문 원문 1곳이고 바로 앞 문장(AST 같은 블록의 이전 형제)이 14 안전 중지 호출 - 사이에 다른 판독·대기가 끼지 않음
$timeAssigns = @($ndAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Extent.Text -eq $timeAssignText }, $true))
$timePrevText = ''
if ($timeAssigns.Count -eq 1) {
  $timeSiblings = @($timeAssigns[0].Parent.Statements)
  $timeIndex = [array]::IndexOf($timeSiblings, $timeAssigns[0])
  if ($timeIndex -gt 0) { $timePrevText = [string]$timeSiblings[$timeIndex - 1].Extent.Text }
}
Assert-Case '던전 시간 배선: 14-T 대입문 원문 1곳 · 바로 앞 문장 = Invoke-SafeStopExitIfRequested -Game $Game' "$($timeAssigns.Count)|$timePrevText" '1|Invoke-SafeStopExitIfRequested -Game $Game'
# (3) 판단값 대입은 정확히 2곳(루프 앞 '' 초기화 · 14-T)이고 판단 함수 호출은 1곳 - 다른 변수에 담거나(오타) 꼬리에서 다시 판단하면 어긋남
$verdictAssigns = @($ndAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$dgTimeVerdict' }, $true))
$verdictRights = @($verdictAssigns | ForEach-Object { [string]$_.Right.Extent.Text }) -join ' | '
$verdictInitBeforeLoop = @($verdictAssigns | Where-Object { $_.Right.Extent.Text -eq "''" -and $_.Extent.StartOffset -lt $ndLoopStart }).Count
$verdictCommands = @($ndAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Get-DgTimeVerdict' }, $true)).Count
$verdictExpect = '2|' + "''" + ' | Get-DgTimeVerdict -UntilTime $dgUntil -Now (Get-Date)|1|1'
Assert-Case "던전 시간 배선: 판단값 대입 2곳(루프 앞 '' · 14-T) · 루프 앞 초기화 1 · Get-DgTimeVerdict 호출 1곳" "$($verdictAssigns.Count)|$verdictRights|$verdictInitBeforeLoop|$verdictCommands" $verdictExpect
# (4) 'last' 는 14-0 의 기존 플래그를 세울 뿐입니다 - 함수 안 대입 1곳이고 if ($dgTimeVerdict -eq 'last') 블록 안 (14-0 블록 자체는 무변경)
$lastRunSets = @($ndAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Extent.Text -eq '$script:dgLastRun = $true' }, $true))
$lastRunSetCond = ''
if ($lastRunSets.Count -eq 1) {
  $lastRunParent = $lastRunSets[0].Parent
  while ($null -ne $lastRunParent -and $lastRunParent -isnot [System.Management.Automation.Language.IfStatementAst]) { $lastRunParent = $lastRunParent.Parent }
  if ($null -ne $lastRunParent) { $lastRunSetCond = [string]$lastRunParent.Clauses[0].Item1.Extent.Text }
}
Assert-Case "던전 시간 배선: 마지막 판 플래그 대입 1곳이고 'last' 판단 블록 안" "$($lastRunSets.Count)|$lastRunSetCond" "1|`$dgTimeVerdict -eq 'last'"
# (5) 지정 시각 읽기 원문 1곳이고 재입장 루프 앞 (판단은 루프 안 14-T, 읽기는 회차마다 한 번)
$untilReadText = '$dgUntil = Get-LifeUntilDeadline -Raw ([string]$env:HONEYNOGI_UNTIL_TIME)'
$untilReads = @($ndAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$dgUntil' }, $true))
$untilReadOk = [int](($untilReads.Count -eq 1) -and ($untilReads[0].Extent.Text -eq $untilReadText) -and ($untilReads[0].Extent.StartOffset -lt $ndLoopStart))
Assert-Case '던전 시간 배선: 지정 시각 읽기(대입) 1곳 = 원문이고 :dgClearCycle 루프 앞' "$($untilReads.Count)|$untilReadOk" '1|1'
# (6) 꼬리 조건 원문 1곳이고 :dgClearCycle 루프 끝 뒤 (판단값 'continue' 하나만 봄 - 꼬리 행동은 test_dg_party_reenter T6)
$tailCondText = 'if ($dgTimeVerdict -eq ''continue'') {'
$tailCondAt = $ndCode.IndexOf($tailCondText)
$tailCondCount = ([regex]::Matches($ndCode, [regex]::Escape($tailCondText))).Count
$tailCondAfterLoop = [int](($ndLoopEnd -gt 0) -and ($tailCondAt -gt $ndLoopEnd))
Assert-Case "던전 시간 배선: 꼬리 조건 원문 1곳 · 루프 끝 뒤" "$tailCondCount|$tailCondAfterLoop" '1|1'

exit $fails
