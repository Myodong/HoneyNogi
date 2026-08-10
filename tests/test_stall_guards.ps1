# 무인 운용 '영구 정지' 차단 계약 (2026-08-09 3차 점검).
#
# 배경 두 가지:
# ① 캡처 실패 대기 루프가 **7곳**이고 전부 `while ($script:screenCaptureFailing)` 인데,
#    그 플래그는 캡처가 성공해야만 풀립니다. 게임 프로세스가 죽으면 화면은 영영 돌아오지
#    않으므로 7곳 전부 무한 대기가 됩니다. 안전 중지는 사용자가 F9 를 눌러야 발동하므로
#    무인 상태에서는 밤새 조용히 멈춰 있게 됩니다.
#    → 7곳이 공통으로 거치는 Test-SafeStopDuringCaptureFail 한 곳에서 막습니다.
# ② Get-ScaledScreenPoint 의 최소화 throw 는 Click-GamePoint(호출부 80여 곳)와 Get-GamePixel 이
#    잡지 않아 최상위 catch → exit 1 로 갑니다. 판독 성공 직후 클릭 직전에 창이 내려가는
#    짧은 경합만으로 회차가 오류로 끝납니다. → 복원을 기다렸다 재확인하고 그때 던집니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$workerSource = [IO.File]::ReadAllText($workerPath)
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# 주석에 같은 문자열이 있으면 개수 계약이 어긋나므로 주석을 뺀 사본으로 셉니다
$workerCode = (($workerSource -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")

# ── ① 동결 지점은 전부 공통 진입점을 거쳐야 한다 ─────────────────────────────
# ★ 7차 점검: 예전에는 `while ($script:screenCaptureFailing)` 형태 **7곳만** 셌습니다.
#   그런데 생활(채집)에는 같은 일을 하는 `if ($script:screenCaptureFailing) { … continue }`
#   형태가 2곳 더 있었고, 거기엔 공통 진입점이 없어 F9 안전 중지도 게임 사망도 감지되지
#   않은 채 채집 한도(권장 1200초)까지 조용히 돌았습니다. 정규식 모양이 아니라
#   **'캡처 실패로 제자리 회전하는 지점'** 이라는 뜻으로 세도록 AST 로 바꿉니다.
$stallAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]([ref]$null).Value)
$freezeSpots = @()
foreach ($node in $stallAst.FindAll({
      param($n)
      ($n -is [System.Management.Automation.Language.WhileStatementAst] -or
       $n -is [System.Management.Automation.Language.IfStatementAst])
    }, $true)) {
  if ($node -is [System.Management.Automation.Language.WhileStatementAst]) {
    if ($node.Condition.Extent.Text -notmatch '^\(?\$script:screenCaptureFailing\)?$') { continue }
    $freezeSpots += , @{ Kind = 'while'; Line = $node.Extent.StartLineNumber; Body = $node.Body.Extent.Text }
    continue
  }
  # PS 5.1 의 IfStatementAst.Clauses 는 Tuple 컬렉션입니다 - 인덱스가 아니라 Item1/Item2 로
  # 꺼내야 합니다(인덱스로 접근하면 조용히 $null 이 되어 이 검사가 통째로 무력해집니다).
  $clause = $node.Clauses[0]
  if ($clause.Item1.Extent.Text -notmatch '^\(?\$script:screenCaptureFailing\)?$') { continue }
  # '동결 지점' = 캡처 실패 때문에 **시간이 흐르지 않게 만드는** 자리입니다. 두 형태가 있습니다:
  #   ① 제자리 회전(continue)  ② 한도 되돌림(AddSeconds) - continue 없이 마감만 미루는 형태
  # ★ 11차 점검: ①만 세는 바람에 ②(클리어 대기 본문의 마감 되돌림)가 감시망 밖이었고,
  #   그 자리의 공통 진입점을 지워도 52종이 전부 통과했습니다. 거긴 클리어 대기의 유일한
  #   게임 사망 감지 지점이라, 빠지면 무인 운용이 캡처 실패 중 영원히 돕니다.
  #   `return $false` 같은 즉시 이탈은 시간을 멈추지 않으므로 동결 지점이 아닙니다.
  $clauseIsSpin = [bool]($clause.Item2.Extent.Text -match '(?m)^\s*continue\b')
  $clauseIsRenew = [bool]($clause.Item2.Extent.Text -match 'AddSeconds')
  if (-not ($clauseIsSpin -or $clauseIsRenew)) { continue }
  # 이 회전에서 캡처를 한 번이라도 시도하는지 보려면 **감싼 반복문의 검사 이전 구간**도
  # 함께 봐야 합니다. 어떤 자리는 반복 첫 줄이 판독이라(4050·4944) 그것이 복구 탐침이 되고,
  # 어떤 자리는 첫 줄이 Start-Sleep 이라 continue 하면 캡처 시도가 0이 됩니다(자기 잠금).
  $enclosing = $null
  foreach ($loop in $stallAst.FindAll({
        param($l)
        $l -is [System.Management.Automation.Language.LoopStatementAst]
      }, $true)) {
    if ($loop.Extent.StartOffset -lt $node.Extent.StartOffset -and
        $loop.Extent.EndOffset -gt $node.Extent.EndOffset) {
      if ($null -eq $enclosing -or $loop.Extent.StartOffset -gt $enclosing.Extent.StartOffset) { $enclosing = $loop }
    }
  }
  $preCheck = ''
  if ($enclosing) {
    $bodyExtent = $enclosing.Body.Extent
    if ($clauseIsSpin) {
      # continue 형은 블록 뒤가 **실행되지 않으므로** 검사 이전 구간만 봅니다
      $preCheck = $bodyExtent.Text.Substring(0, [Math]::Max(0, $node.Extent.StartOffset - $bodyExtent.StartOffset))
    } else {
      # 한도 되돌림 형은 블록을 지나 **반복 본문 나머지가 그대로 실행**되므로, 그 안 어디서든
      # 캡처를 시도하면 복구를 감지할 수 있습니다 (예: 어비스 복귀 루프는 바로 아래 화면 판정).
      $preCheck = $bodyExtent.Text
    }
  }
  $freezeSpots += , @{ Kind = $(if ($clauseIsSpin) { 'if-continue' } else { 'if-renew' })
    Line = $node.Extent.StartLineNumber
    Body = $clause.Item2.Extent.Text; PreCheck = $preCheck }
}
Assert-Case '동결 지점 개수 (늘리면 이 숫자도 함께 올릴 것)' $freezeSpots.Count 20
Assert-Case '동결 지점: while 형' (@($freezeSpots | Where-Object { $_.Kind -eq 'while' }).Count) 7
# 한도 되돌림 형 3곳 (클리어 대기 본문 / 어비스 선택 화면 복귀 / 그 밖). 11차에서 감시망에
# 새로 들어온 형태입니다 - 이 자리들이 캡처 실패 중 유일한 게임 사망 감지 지점입니다.
Assert-Case '동결 지점: if-renew 형(한도 되돌림)' (@($freezeSpots | Where-Object { $_.Kind -eq 'if-renew' }).Count) 3
# if-continue 형이 9곳입니다 - 3차 점검이 while 7곳만 세는 바람에 이 9곳은 계약 밖에
# 있었습니다(공통 진입점 호출 여부는 우연히 전부 지키고 있었지만, 복구 탐침은 4곳이
# 빠져 무한 회전이었습니다 - 7차 점검에서 발견·수정).
Assert-Case '동결 지점: if-continue 형' (@($freezeSpots | Where-Object { $_.Kind -eq 'if-continue' }).Count) 10
$loopMissing = @()
foreach ($spot in $freezeSpots) {
  $bodyCode = (($spot.Body -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
  if ($bodyCode -notmatch 'Test-SafeStopDuringCaptureFail') { $loopMissing += "$($spot.Kind)@$($spot.Line)" }
}
if ($loopMissing.Count -gt 0) { "     └ 누락: $($loopMissing -join ', ')" }
Assert-Case '동결 지점 전부가 공통 진입점을 호출' $loopMissing.Count 0
# 복구 탐침도 필수입니다 - 플래그는 캡처가 성공해야만 풀리므로 판독을 건너뛰기만 하면
# 화면이 돌아와도 영영 감지하지 못합니다 (2026-08-07 실사고)
# ★ 7차 점검이 이 검사를 넣자마자 **던전/사냥터 4곳(fieldDeadline·floorDeadline·
#   optionsDeadline·returnDeadline)** 이 걸렸습니다. 전부 `Start-Sleep` 으로 회전을 시작해
#   continue 하면 그 회전에 캡처 시도가 0이고, 바로 다음 줄이 한도를 40초로 되돌려
#   **무한 회전**이 되던 자리입니다 (채집에서 2026-08-07 에 고친 자기 잠금과 같은 형태).
#   판독 함수 이름은 자리마다 달라 '캡처를 여는 호출' 전체를 후보로 둡니다.
$probePattern = 'Test-CaptureRecovered|Get-GameRegionCapture|Get-GameRegionOcrText|Get-GameOcrText|' +
  'Find-GameTextPoint|Get-GamePixel|Test-ExitButton|Get-DgTributeCost|Find-HtEntryButtonPoint|& \$Condition'
$probeMissing = @()
foreach ($spot in $freezeSpots) {
  $scan = [string]$spot.Body + "`n" + [string]$spot.PreCheck
  if ($scan -notmatch $probePattern) { $probeMissing += "$($spot.Kind)@$($spot.Line)" }
}
if ($probeMissing.Count -gt 0) { "     └ 복구 탐침 누락: $($probeMissing -join ', ')" }
Assert-Case '동결 지점 전부가 이번 회전에 캡처를 시도한다(자기 잠금 방지)' $probeMissing.Count 0
# ※ '한도를 되돌리는 블록은 그 안에 탐침이 있어야 한다'는 더 엄한 규칙도 시험해 봤지만
#   4050·4944 는 **반복 첫 줄이 판독**이라(각각 `& $Condition`, 컷신 '넘기' 탐색) 회전마다
#   캡처를 시도합니다. 한도를 되돌려도 플래그가 풀리므로 무한이 아닙니다. 위 검사가 이미
#   '이번 회전에 캡처를 시도하는가'를 정확히 보므로 중복 규칙은 두지 않습니다.

# ── ② 공통 진입점이 게임 생존을 확인한다 ────────────────────────────────────
$safeStopBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-SafeStopDuringCaptureFail'))
# 코드 1(오류)이 아니라 4(조건부 정상 정지). 게임 사망은 자동 복구 불가라 재시도할 이유가
# 없는데, 코드 1 이면 커스텀 모드가 죽은 게임에 워커를 2번 더 붙입니다. 게다가 함수 안의
# exit 는 최상위 catch 를 건너뛰어 오류 세트도 안 남습니다 (4차 점검).
Assert-Case '생존 확인: 프로세스 종료면 조건 정지(코드 4)로 마침' `
  ([bool]($safeStopBody -match '게임 프로세스가 종료되어[\s\S]{0,120}exit 4')) 'True'
Assert-Case '생존 확인: 죽은 게임에 오류 재시도를 유발하지 않음(exit 1 아님)' `
  ([bool]($safeStopBody -match '게임 프로세스가 종료되어[\s\S]{0,200}exit 1')) 'False'
# ★ 7차 점검 변이 실측: 아래 핸들 소실 분기의 `exit 4` 를 `exit 1` 로 바꿔도 52종이 전부
#   통과했습니다. 위 단언의 옛 패턴 `HasExited[\s\S]{0,600}exit 4` 가 **다른 분기(프로세스
#   종료)의 exit 4** 를 끌어다 쓰고, 아래 52-53행은 숫자 60만 봤기 때문입니다. 그래서 각
#   분기의 종료 코드를 **문구와 짝지어** 따로 못 박습니다 (양방향 - 있어야 할 것과 없어야 할 것).
Assert-Case '생존 확인: 창 핸들 소실도 조건 정지(코드 4)' `
  ([bool]($safeStopBody -match '게임 창을 찾을 수 없는 상태가 60초[\s\S]{0,160}exit 4')) 'True'
Assert-Case '생존 확인: 창 핸들 소실을 오류 코드로 마치지 않는다' `
  ([bool]($safeStopBody -match '게임 창을 찾을 수 없는 상태가 60초[\s\S]{0,160}exit 1')) 'False'
Assert-Case '생존 확인: 종료 판정 전에 Refresh (MainWindowHandle 캐시 방지)' `
  ([bool]($safeStopBody -match '\$script:gameProcess\.Refresh\(\)')) 'True'
Assert-Case '생존 확인: 핸들 접근 실패도 사라진 것으로 취급' `
  ([bool]($safeStopBody -match 'catch \{ \$gameGone = \$true \}')) 'True'
Assert-Case '생존 확인: 창 핸들 소실은 60초 이어질 때만 종료(전환 중 오탐 방지)' `
  ([bool]($safeStopBody -match 'MainWindowHandle -eq \[IntPtr\]::Zero[\s\S]{0,300}60')) 'True'
# ★ 그 60초는 **핸들이 사라진 시각**부터 재야 합니다. 처음엔 $script:captureFailingSince
#   (= 캡처 실패가 시작된 시각)를 썼는데, 그러면 RDP 단절 등으로 캡처 실패가 이미 60초를
#   넘긴 뒤 핸들이 **한 번만 깜빡여도** 즉시 종료합니다 (2026-08-09 4차 점검 - 잘못된 시계).
Assert-Case '생존 확인: 핸들 소실 전용 시계를 쓴다' `
  ([bool]($safeStopBody -match '\$script:gameWindowMissingSince')) 'True'
Assert-Case '생존 확인: 캡처 실패 시작 시각으로 핸들 유예를 재지 않는다' `
  ([bool]($safeStopBody -match 'MainWindowHandle -eq \[IntPtr\]::Zero[\s\S]{0,200}captureFailingSince')) 'False'
Assert-Case '생존 확인: 핸들이 돌아오면 유예 시계를 초기화(연속 60초 요구)' `
  ([bool]($safeStopBody -match '\$script:gameWindowMissingSince = \$null')) 'True'
# ★ 캡처가 **복구되면** 동결 루프를 더 이상 돌지 않으므로, 그 안에서만 초기화하면 옛 시각이
#   그대로 남습니다. 나중에 핸들이 잠깐 0이 되면 과거 시각 기준으로 '60초 지속'이 즉시 참이
#   되어 회차가 바로 정지합니다 (5차 점검 실행 확인: captureFailing=False 인데 age=300).
$successBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Register-CaptureSuccess'))
Assert-Case '생존 확인: 캡처 복구 시에도 핸들 시계를 푼다' `
  ([bool]($successBody -match '\$script:gameWindowMissingSince = \$null')) 'True'

# 시퀀스: 소실 30초 → **캡처 복구**(동결 루프 이탈) → 한참 뒤 핸들이 잠깐 0
# 복구에서 시계를 안 풀면 두 번째 소실이 즉시 정지가 된다
function Step-ClockWithRecovery {
  param([bool]$HandleZero, [bool]$CaptureOk, [double]$Now, $MissingSince, [bool]$ResetOnRecovery)
  # ★ 캡처가 복구되면 동결 루프를 빠져나가므로 Test-SafeStopDuringCaptureFail 이 **아예
  #   호출되지 않습니다**. 그 안에서만 초기화하는 옛 동작에서는 시계가 그대로 남습니다.
  #   (처음 이 시뮬레이션은 복구 회전에도 함수가 도는 것처럼 써서 결함을 가렸습니다.)
  if ($CaptureOk) {
    if ($ResetOnRecovery) { return @{ MissingSince = $null; Stop = $false } }
    return @{ MissingSince = $MissingSince; Stop = $false }
  }
  if (-not $HandleZero) { return @{ MissingSince = $null; Stop = $false } }
  if ($null -eq $MissingSince) { $MissingSince = $Now }
  return @{ MissingSince = $MissingSince; Stop = [bool](($Now - $MissingSince) -ge 60) }
}
foreach ($mode in @($true, $false)) {
  $clk = $null; $verdict = '계속'
  foreach ($st in @(
      @{ T = 0;   Zero = $true;  Ok = $false },
      @{ T = 30;  Zero = $true;  Ok = $false },
      @{ T = 35;  Zero = $false; Ok = $true  },   # 캡처 복구
      @{ T = 400; Zero = $true;  Ok = $false })) {
    $r = Step-ClockWithRecovery -HandleZero $st.Zero -CaptureOk $st.Ok -Now $st.T -MissingSince $clk -ResetOnRecovery:$mode
    $clk = $r.MissingSince
    if ($r.Stop) { $verdict = '즉시정지' }
  }
  Assert-Case "시퀀스: 복구 시 시계 초기화 $(if ($mode) { '있음' } else { '없음(옛 동작)' })" `
    $verdict $(if ($mode) { '계속' } else { '즉시정지' })
}

# 시퀀스 진리표: '정상 → 30초 소실 → 정상 복귀 → 오래된 캡처 실패 중 소실 재발' 에서
# 두 번째 소실이 즉시 종료되면 안 됩니다 (연속이 아니므로 시계가 처음부터 다시 시작).
function Step-WindowMissingClock {
  param([bool]$HandleZero, [double]$Now, $MissingSince)
  if (-not $HandleZero) { return @{ MissingSince = $null; Stop = $false } }
  if ($null -eq $MissingSince) { $MissingSince = $Now }
  return @{ MissingSince = $MissingSince; Stop = [bool](($Now - $MissingSince) -ge 60) }
}
$clock = $null
$seq = @()
foreach ($step in @(
    @{ T = 0;   Zero = $false }, @{ T = 10;  Zero = $true },  @{ T = 40;  Zero = $true },
    @{ T = 45;  Zero = $false }, @{ T = 300; Zero = $true },  @{ T = 330; Zero = $true },
    @{ T = 365; Zero = $true })) {
  $r = Step-WindowMissingClock -HandleZero $step.Zero -Now $step.T -MissingSince $clock
  $clock = $r.MissingSince
  $seq += $(if ($r.Stop) { "T$($step.T):정지" } else { "T$($step.T):계속" })
}
Assert-Case '시퀀스: 30초 소실 → 복귀 → 오래된 실패 중 재소실은 즉시 정지하지 않음' `
  ($seq -join ' ') 'T0:계속 T10:계속 T40:계속 T45:계속 T300:계속 T330:계속 T365:정지'
Assert-Case '생존 확인: 기존 안전 중지(F9) 계약은 유지' `
  ([bool]($safeStopBody -match 'safeStopFlagPath[\s\S]{0,400}120[\s\S]{0,600}exit 4')) 'True'
Assert-Case '배선: 게임 프로세스를 스크립트 스코프에 보관' `
  ([bool]($workerCode -match '\$script:gameProcess = \$game')) 'True'

# 진리표: 생존 판정식만 떼어내 확인 (실제 프로세스 없이 순수 판정)
function Test-ShouldStopForDeadGame {
  param([bool]$HasProcess, [bool]$Exited, [bool]$HandleZero, [int]$MissingSeconds)
  if (-not $HasProcess) { return 'continue' }
  if ($Exited) { return 'exit4-dead' }
  if ($HandleZero -and $MissingSeconds -ge 60) { return 'exit4-nowindow' }
  return 'continue'
}
Assert-Case '진리표: 프로세스 종료 → 즉시 조건 정지' (Test-ShouldStopForDeadGame $true $true $false 0) 'exit4-dead'
Assert-Case '진리표: 핸들 0 + 10초 → 계속 대기(전환 중일 수 있음)' (Test-ShouldStopForDeadGame $true $false $true 10) 'continue'
Assert-Case '진리표: 핸들 0 + 60초 → 조건 정지' (Test-ShouldStopForDeadGame $true $false $true 60) 'exit4-nowindow'
Assert-Case '진리표: 정상 생존 → 계속 대기' (Test-ShouldStopForDeadGame $true $false $false 300) 'continue'
Assert-Case '진리표: 프로세스 참조 없음 → 계속(초기화 전)' (Test-ShouldStopForDeadGame $false $false $false 300) 'continue'

# ── ③ 최소화는 복원을 기다린 뒤에만 던진다 ──────────────────────────────────
$scaledBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-ScaledScreenPoint'))
$waitBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Wait-GameRestoredIfMinimized'))
$clickBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Click-GamePoint'))
# ★ 대기는 **클릭 진입점에만** 둡니다. 공용 입구(Get-ScaledScreenPoint)에 두면 픽셀 판정의
#   표본 수(한 판정에 27회) × 재시도 횟수만큼 곱해져 수십 분을 무음으로 태웁니다
#   (4차 점검 실측: 27표본 × 25초 × 5회전 ≈ 56분, catch { continue } 가 예외를 삼킴).
Assert-Case '최소화: 공용 입구는 기다리지 않고 즉시 던진다(곱셈 방지)' `
  ([bool]($scaledBody -match 'IsIconic[\s\S]{0,120}throw')) 'True'
$scaledCode = (($scaledBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '최소화: 공용 입구에 대기 루프가 없다' `
  ([bool]($scaledCode -match 'Invoke-AutoRefocus|Start-Sleep')) 'False'
Assert-Case '최소화: 클릭 진입점에서만 복원을 기다린다' `
  ([bool]($clickBody -match 'Wait-GameRestoredIfMinimized -Game \$Game')) 'True'
Assert-Case '최소화: 대기 함수가 복원을 시도한다' `
  ([bool]($waitBody -match 'Invoke-AutoRefocus -Game \$Game')) 'True'
# ★ 7차 변이 실측: 루프 안 **복원 감지 4줄**을 통째로 지워도 이 파일의 단언이 전부 통과했습니다
#   (test_guard_constants 만 잡았음). 그러면 창이 곧 돌아와도 예산 25초를 끝까지 태우고
#   거짓 경고를 남기며, Click-GamePoint 는 호출부가 80여 곳이라 클릭 1회마다 25초가 붙습니다.
#   이 계약의 주인은 이 파일이므로 여기에도 앵커를 답니다 (아래 $waitCodeOnly 정의보다
#   앞이라 여기서 따로 만듭니다 - 주석에 걸리는 거짓 안심을 피하려면 코드 사본이어야 합니다).
$waitCodeEarly = (($waitBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '최소화: 복원되면 즉시 탈출한다(예산을 끝까지 태우지 않음)' `
  ([bool]($waitCodeEarly -match "IsIconic\(\`$Game\.MainWindowHandle\)\) \{\s*\r?\n\s*Write-RunLog '\[안내\] 최소화된 게임 창을 복원해 진행합니다\.'\s*\r?\n\s*return")) 'True'
Assert-Case '최소화: IsIconic 검사는 진입 1 + 루프 1 = 정확히 2곳' `
  ([regex]::Matches($waitCodeEarly, 'IsIconic\(\$Game\.MainWindowHandle\)').Count) 2
# ★ 캡처 경로의 스로틀($script:lastMinimizedRestoreAt)을 **공유하면 안 됩니다.** 캡처가 방금
#   복원을 시도해 시각을 찍어 둔 상태로 들어오면 '이미 기다린 실패'로 오해해 17ms 만에
#   복원 0회로 반환하고, 바로 뒤 Get-ScaledScreenPoint 가 throw 해 회차가 죽습니다
#   (5차 점검 실행 확인). 끝내 복원 안 되면 어차피 예외로 끝나므로 스로틀 자체가 불필요합니다.
$waitCodeOnly = (($waitBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '최소화: 캡처 경로 스로틀을 공유하지 않는다' `
  ([bool]($waitCodeOnly -match 'lastMinimizedRestoreAt')) 'False'
# 직접 좌표 변환을 쓰는 곳도 같은 복원 계약에 넣어야 합니다 (난이도 알약 탐색 / 생활 목록 드래그)
Assert-Case '최소화: 복원 대기를 부르는 곳 3곳 (클릭 + 난이도 + 생활 스크롤)' `
  ([regex]::Matches($workerCode, 'Wait-GameRestoredIfMinimized -Game \$Game').Count) 3
foreach ($direct in @('Find-DgDifficultyPoint', 'Invoke-LifeListScroll')) {
  $b = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($direct))
  Assert-Case "최소화: $direct 도 복원 계약에 포함" `
    ([bool]($b -match 'Wait-GameRestoredIfMinimized -Game \$Game')) 'True'
}
# ★ 이 두 단언은 7차 점검 전까지 **주석에만 걸려 있었습니다.** $waitBody 는 AST 의
#   Extent.Text 라 주석을 포함하는데, 6차에서 로그 문구를 바꾼 뒤에도 설명 주석에 옛 문구가
#   남아 계속 초록이었습니다. 즉 '문구 계약을 검증한다'는 착각만 준 거짓 안심이었고,
#   누군가 주석을 정리하면 동작은 그대로인데 2건이 FAIL 로 터지는 상태이기도 했습니다.
#   → 위에서 만들어 둔 주석 제거본($waitCodeOnly)으로 **실제 로그 문구**를 못 박습니다.
Assert-Case '최소화: 대기 종료를 실제 결과 표현으로 남긴다' `
  ([bool](($waitCodeOnly -match '복원 대기를 끝냅니다') -and
          ($waitCodeOnly -match '클릭 경로면 이어서 회차가 오류로 끝납니다'))) 'True'
Assert-Case '최소화: 대기 진입/종료를 로그로 남긴다(무음 금지)' `
  ([bool](($waitCodeOnly -match '복원을 기다립니다') -and ($waitCodeOnly -match '복원 대기를 끝냅니다'))) 'True'
# 호출부마다 뒷일이 다르므로(생활 스크롤은 Focus-Game 이 살려 진행) 결과를 단정하면 안 됩니다
Assert-Case '최소화: 옛 단정 문구를 코드에 되살리지 않는다' `
  ([bool]($waitCodeOnly -match '회차를 오류로 마칩니다')) 'False'
# ★ 대기 예산은 **횟수가 아니라 시간**이고, 유휴 기준(기본 15초)을 넘길 수 있어야 합니다.
#   '12회 x 1초'로 썼더니 우리 입력이 유휴를 0으로 리셋해 Invoke-AutoRefocus 가 12초 내내
#   막히고 **실제 복원 시도 0회**로 같은 예외를 던졌습니다 (4차 점검 실측).
Assert-Case '최소화: 대기 예산이 유휴 기준을 넘긴다(횟수 아닌 시간)' `
  ([bool]($waitBody -match '\$restoreBudget = \[Math\]::Max\(25, \[int\]\$refocusIdleSeconds \+ 10\)')) 'True'
Assert-Case '최소화: 고정 횟수 루프가 아니다' `
  ([bool]($waitBody -match 'for \(\$restoreTry = 1; \$restoreTry -le \d+;')) 'False'
Assert-Case '최소화: 복원 시도는 간격 제한(Focus-Game 이 ~2초라 매초 연타 금지)' `
  ([bool]($waitBody -match '\$lastRestoreTry[\s\S]{0,120}-ge 3')) 'True'

# 예산 계산 진리표: 유휴 설정이 커져도 최소 한 번은 시도할 수 있어야 합니다
function Get-RestoreBudget { param([int]$IdleSeconds) return [Math]::Max(25, $IdleSeconds + 10) }
Assert-Case '예산: 기본 유휴 15초 → 25초' (Get-RestoreBudget 15) 25
Assert-Case '예산: 유휴 0(검사 없음) → 최소 25초' (Get-RestoreBudget 0) 25
Assert-Case '예산: 유휴 60초 → 70초 (항상 유휴보다 큼)' (Get-RestoreBudget 60) 70
Assert-Case '예산: 어떤 유휴 설정에서도 예산 > 유휴' `
  ([bool](@(0, 5, 15, 30, 60, 120, 300) | ForEach-Object { (Get-RestoreBudget $_) -gt $_ } | Where-Object { -not $_ } | Measure-Object).Count -eq 0) 'True'
Assert-Case '최소화: 끝내 안 되면 대기한 시간을 밝히고 클릭을 건너뛴다' `
  ([bool]($waitBody -match '\$\{restoreBudget\}초를 기다렸지만')) 'True'
Assert-Case '최소화: 복원 시도는 유휴 계약을 지키는 경로(Focus-Game 직접 호출 아님)' `
  ([bool]($waitBody -notmatch 'Focus-Game -Game \$Game')) 'True'
Assert-Case '최소화: 기존 과소 창 throw 는 유지' `
  ([bool]($scaledBody -match '게임 창 크기가 너무 작습니다')) 'True'

exit $fails
