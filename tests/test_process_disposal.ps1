# 장기 반복에서 Start-Process -PassThru 객체를 모든 종료 경로가 명시적으로 해제하는지 검사합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$root = Split-Path -Parent $PSScriptRoot

function Check-Pattern {
  # Expect=$false 면 '그 패턴이 **없어야** 한다'는 뜻입니다 (금지 계약 - 10차 점검에서 필요해짐)
  param([string]$Name, [string]$Text, [string]$Pattern, [bool]$Expect = $true)
  $found = [bool]($Text -match $Pattern)
  if ($found -eq $Expect) { "OK   $Name" }
  else { "FAIL $Name (있음=$found / 기대=$Expect)"; $script:fails++ }
}

$gui = Get-Content -LiteralPath (Join-Path $root 'mabinogi_gui.ps1') -Raw -Encoding UTF8
$controller = Get-Content -LiteralPath (Join-Path $root 'mabinogi_controller.ps1') -Raw -Encoding UTF8
$worker = Get-Content -LiteralPath (Join-Path $root 'mabinogi_run_once.ps1') -Raw -Encoding UTF8

Check-Pattern 'GUI 강제 정지 Process.Dispose' $gui '\$workerToDispose\.Dispose\(\)'
Check-Pattern 'GUI 정상 종료 Process.Dispose' $gui '\$finishedWorker\.Dispose\(\)'
Check-Pattern 'GUI 창 닫기 Process.Dispose' $gui '\$closingWorker\.Dispose\(\)'
# 2026-08-01 3차 점검: 무기한 WaitForExit() 는 종료 신호가 안 오면 GUI 전체가 멈춰
# 타임아웃 대기(WaitForExit(10000))로 교체 - 가드도 새 형태를 요구
Check-Pattern 'GUI 강제 종료 WaitForExit(타임아웃)' $gui '\$workerToDispose\.Kill\(\)[\s\S]{0,160}\$workerToDispose\.WaitForExit\(10000\)'
Check-Pattern 'GUI 타이머 Dispose' $gui '\$uiTimer\.Dispose\(\)'
# ★ 10차 점검: 종료 경로에서 **진행 중인** 조회에 동기 Stop()/Dispose() 를 부르면 안 됩니다.
#   둘 다 실행 중 파이프라인이 끝날 때까지 블로킹해(PS 5.1 실측 12초 슬립에 11.5초),
#   그동안 프로세스가 살아 있는 채 Global 뮤텍스를 쥐고 있어 **재실행이 '이미 실행 중'으로
#   차단**됩니다. 창은 닫혔는데 다시 열리지도 않는 상태가 됩니다.
#   → 계약을 '중단 요청은 비동기(BeginStop), Dispose 는 끝난 것만'으로 바꿨습니다.
Check-Pattern 'GUI 미완료 조회는 비동기 중단' $gui '\[void\]\$pendingPs\.Ps\.BeginStop\(\$null, \$null\)'
Check-Pattern 'GUI 완료된 조회만 Dispose' $gui '\$pendingPs\.Ps\.Dispose\(\)'
Check-Pattern 'GUI 종료 경로에 동기 Stop 없음' $gui '\$script:(updateCheckPs|approvalPs)\.Stop\(\)' $false
Check-Pattern 'GUI 업데이트/승인 조회를 같은 계약으로 정리' $gui '\$script:updateCheckPs; Async = \$script:updateCheckAsync'
Check-Pattern 'GUI 전역 뮤텍스 해제' $gui '\$script:guiMutex\.ReleaseMutex\(\)'
Check-Pattern 'GUI 전역 뮤텍스 Dispose' $gui '\$script:guiMutex\.Dispose\(\)'
Check-Pattern '레거시 즉시 종료 Process.Dispose' $controller '\$workerToDispose\.Dispose\(\)'
Check-Pattern '레거시 정상 종료 Process.Dispose' $controller '\$finishedWorker\.Dispose\(\)'
Check-Pattern '레거시 강제 종료 입력 해제' $controller '\$workerWasKilled[\s\S]{0,700}Release-ControllerStuckInput'
Check-Pattern '레거시 시작 정리 입력 해제' $controller '\$script:startupKilledAutomation[\s\S]{0,4000}Release-ControllerStuckInput'
Check-Pattern 'RDP 예약 작업 고유 이름' $controller '\$redirectTaskName\s*=\s*''HoneyNogiRDPToConsole'''
Check-Pattern 'RDP 이전 예약 작업 정리' $controller "Unregister-ScheduledTask\s+-TaskName\s+'MabinogiRDPToConsole'"
Check-Pattern 'OCR 설치 dism Process.Dispose' $worker '\$dismProc\.Dispose\(\)'
Check-Pattern 'OCR 설치 강제 종료 WaitForExit' $worker '\$dismProc\.Kill\(\);\s*\$dismProc\.WaitForExit\(\)'

exit $fails
