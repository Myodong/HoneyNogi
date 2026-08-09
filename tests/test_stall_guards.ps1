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

# ── ① 동결 루프는 전부 공통 진입점을 거쳐야 한다 ─────────────────────────────
$freezeLoops = [regex]::Matches($workerCode, 'while \(\$script:screenCaptureFailing\) \{')
Assert-Case '동결 루프 개수 (늘리면 이 숫자도 함께 올릴 것)' $freezeLoops.Count 7
# 각 루프 본문 앞부분에 Test-SafeStopDuringCaptureFail 이 있는지 확인
$loopMissing = 0
foreach ($m in $freezeLoops) {
  $tail = $workerCode.Substring($m.Index, [Math]::Min(400, $workerCode.Length - $m.Index))
  if ($tail -notmatch 'Test-SafeStopDuringCaptureFail') { $loopMissing++ }
}
Assert-Case '동결 루프 전부가 공통 진입점을 호출' $loopMissing 0

# ── ② 공통 진입점이 게임 생존을 확인한다 ────────────────────────────────────
$safeStopBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-SafeStopDuringCaptureFail'))
Assert-Case '생존 확인: 프로세스 종료면 즉시 오류 종료' `
  ([bool]($safeStopBody -match 'HasExited[\s\S]{0,400}exit 1')) 'True'
Assert-Case '생존 확인: 종료 판정 전에 Refresh (MainWindowHandle 캐시 방지)' `
  ([bool]($safeStopBody -match '\$script:gameProcess\.Refresh\(\)')) 'True'
Assert-Case '생존 확인: 핸들 접근 실패도 사라진 것으로 취급' `
  ([bool]($safeStopBody -match 'catch \{ \$gameGone = \$true \}')) 'True'
Assert-Case '생존 확인: 창 핸들 소실은 60초 이어질 때만 종료(전환 중 오탐 방지)' `
  ([bool]($safeStopBody -match 'MainWindowHandle -eq \[IntPtr\]::Zero[\s\S]{0,300}60')) 'True'
Assert-Case '생존 확인: 기존 안전 중지(F9) 계약은 유지' `
  ([bool]($safeStopBody -match 'safeStopFlagPath[\s\S]{0,400}120[\s\S]{0,600}exit 4')) 'True'
Assert-Case '배선: 게임 프로세스를 스크립트 스코프에 보관' `
  ([bool]($workerCode -match '\$script:gameProcess = \$game')) 'True'

# 진리표: 생존 판정식만 떼어내 확인 (실제 프로세스 없이 순수 판정)
function Test-ShouldStopForDeadGame {
  param([bool]$HasProcess, [bool]$Exited, [bool]$HandleZero, [int]$FailingSeconds)
  if (-not $HasProcess) { return 'continue' }
  if ($Exited) { return 'exit1-dead' }
  if ($HandleZero -and $FailingSeconds -ge 60) { return 'exit1-nowindow' }
  return 'continue'
}
Assert-Case '진리표: 프로세스 종료 → 즉시 종료' (Test-ShouldStopForDeadGame $true $true $false 0) 'exit1-dead'
Assert-Case '진리표: 핸들 0 + 10초 → 계속 대기(전환 중일 수 있음)' (Test-ShouldStopForDeadGame $true $false $true 10) 'continue'
Assert-Case '진리표: 핸들 0 + 60초 → 종료' (Test-ShouldStopForDeadGame $true $false $true 60) 'exit1-nowindow'
Assert-Case '진리표: 정상 생존 → 계속 대기' (Test-ShouldStopForDeadGame $true $false $false 300) 'continue'
Assert-Case '진리표: 프로세스 참조 없음 → 계속(초기화 전)' (Test-ShouldStopForDeadGame $false $false $false 300) 'continue'

# ── ③ 최소화는 복원을 기다린 뒤에만 던진다 ──────────────────────────────────
$scaledBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-ScaledScreenPoint'))
Assert-Case '최소화: 바로 던지지 않고 복원을 기다린다' `
  ([bool]($scaledBody -match 'IsIconic[\s\S]{0,400}Invoke-AutoRefocus[\s\S]{0,300}IsIconic')) 'True'
Assert-Case '최소화: 복원 대기는 유한하다(무한 루프 아님)' `
  ([bool]($scaledBody -match 'for \(\$restoreTry = 1; \$restoreTry -le \d+;')) 'True'
Assert-Case '최소화: 끝내 안 되면 사유가 분명한 오류' `
  ([bool]($scaledBody -match '최소화된 상태가 계속됩니다')) 'True'
Assert-Case '최소화: 복원 시도는 유휴 계약을 지키는 경로(Focus-Game 직접 호출 아님)' `
  ([bool]($scaledBody -notmatch 'Focus-Game -Game \$Game')) 'True'
Assert-Case '최소화: 기존 과소 창 throw 는 유지' `
  ([bool]($scaledBody -match '게임 창 크기가 너무 작습니다')) 'True'

exit $fails
