# Invoke-ClickUntil 운영 함수를 직접 불러 원본 화면 조건이 재클릭을 차단하는지 검사합니다.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
Invoke-Expression (Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-ClickUntil'))

$script:screenCaptureFailing = $false
$script:clickCount = 0
function Focus-Game { param($Game) }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY); $script:clickCount++ }
function Test-SafeStopDuringCaptureFail {}
function Start-Sleep { param([int]$Milliseconds) }

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ($Actual -eq $Expected) { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

$game = Get-Process -Id $PID

$script:conditionChecks = 0
$script:clickCount = 0
Invoke-ClickUntil -Game $game -Point @(1, 1) -Description 'source gone' -TimeoutSeconds 1 `
  -Condition { [void]($script:conditionChecks++); $script:conditionChecks -ge 2 } -SourceCondition { $false }
Check-Equal '원본 화면이 사라지면 재클릭하지 않음' $script:clickCount 0

$script:conditionChecks = 0
$script:clickCount = 0
Invoke-ClickUntil -Game $game -Point @(1, 1) -Description 'source present' -TimeoutSeconds 1 `
  -Condition { [void]($script:conditionChecks++); $script:conditionChecks -ge 3 } -SourceCondition { $true }
Check-Equal '원본 화면이 유지되면 클릭 후 목표를 재확인' $script:clickCount 1

$workerRaw = Get-Content -LiteralPath $workerPath -Raw -Encoding UTF8
$callCount = ([regex]::Matches($workerRaw, 'Invoke-ClickUntil\s+-Game')).Count
$sourceCount = ([regex]::Matches($workerRaw, '-SourceCondition\s*\{')).Count
Check-Equal '현재 운영 호출부 전체에 원본 화면 조건 적용' $sourceCount $callCount

exit $fails
