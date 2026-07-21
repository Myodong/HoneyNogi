# 장기 반복에서 Start-Process -PassThru 객체를 모든 종료 경로가 명시적으로 해제하는지 검사합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$root = Split-Path -Parent $PSScriptRoot

function Check-Pattern {
  param([string]$Name, [string]$Text, [string]$Pattern)
  if ($Text -match $Pattern) { "OK   $Name" }
  else { "FAIL $Name"; $script:fails++ }
}

$gui = Get-Content -LiteralPath (Join-Path $root 'mabinogi_gui.ps1') -Raw -Encoding UTF8
$controller = Get-Content -LiteralPath (Join-Path $root 'mabinogi_controller.ps1') -Raw -Encoding UTF8
$worker = Get-Content -LiteralPath (Join-Path $root 'mabinogi_run_once.ps1') -Raw -Encoding UTF8

Check-Pattern 'GUI 강제 정지 Process.Dispose' $gui '\$workerToDispose\.Dispose\(\)'
Check-Pattern 'GUI 정상 종료 Process.Dispose' $gui '\$finishedWorker\.Dispose\(\)'
Check-Pattern 'GUI 창 닫기 Process.Dispose' $gui '\$closingWorker\.Dispose\(\)'
Check-Pattern 'GUI 강제 종료 WaitForExit' $gui '\$workerToDispose\.Kill\(\)[\s\S]{0,160}\$workerToDispose\.WaitForExit\(\)'
Check-Pattern '레거시 즉시 종료 Process.Dispose' $controller '\$workerToDispose\.Dispose\(\)'
Check-Pattern '레거시 정상 종료 Process.Dispose' $controller '\$finishedWorker\.Dispose\(\)'
Check-Pattern '레거시 강제 종료 입력 해제' $controller '\$workerWasKilled[\s\S]{0,700}Release-ControllerStuckInput'
Check-Pattern '레거시 시작 정리 입력 해제' $controller '\$script:startupKilledAutomation[\s\S]{0,4000}Release-ControllerStuckInput'
Check-Pattern 'RDP 예약 작업 고유 이름' $controller '\$redirectTaskName\s*=\s*''HoneyNogiRDPToConsole'''
Check-Pattern 'RDP 이전 예약 작업 정리' $controller "Unregister-ScheduledTask\s+-TaskName\s+'MabinogiRDPToConsole'"
Check-Pattern 'OCR 설치 dism Process.Dispose' $worker '\$dismProc\.Dispose\(\)'
Check-Pattern 'OCR 설치 강제 종료 WaitForExit' $worker '\$dismProc\.Kill\(\);\s*\$dismProc\.WaitForExit\(\)'

exit $fails
