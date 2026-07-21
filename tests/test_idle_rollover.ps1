# GetTickCount 32비트 rollover 경과 시간 계산 - 워커 본체 함수를 직접 실행합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $root 'mabinogi_run_once.ps1') `
    -Names @('Get-TickElapsedMilliseconds')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

Assert-Case 'tick: 일반 경과' (Get-TickElapsedMilliseconds 5000 3000) 2000
Assert-Case 'tick: 동일 시각' (Get-TickElapsedMilliseconds 1234 1234) 0
Assert-Case 'tick: rollover 직후' (Get-TickElapsedMilliseconds 1000 4294967000) 1296
Assert-Case 'tick: 최대값→0' (Get-TickElapsedMilliseconds 0 4294967295) 1

exit $fails
