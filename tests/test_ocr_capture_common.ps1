# OCR 세 진입점이 캡처·확대·해제 공통 헬퍼 하나를 공유하는지 검사합니다.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
$names = @('Get-GameRegionCapture', 'Get-GameRegionOcrText', 'Find-GameTextPoint', 'Get-GameRegionOcrWords')
$definitions = Get-SourceFunctionDefinitions -Path $workerPath -Names $names
$fails = 0

function Check-Pattern {
  param([string]$Name, [string]$Text, [string]$Pattern)
  if ($Text -match $Pattern) { "OK   $Name" }
  else { "FAIL $Name"; $script:fails++ }
}

function Check-NoPattern {
  param([string]$Name, [string]$Text, [string]$Pattern)
  if ($Text -notmatch $Pattern) { "OK   $Name" }
  else { "FAIL $Name"; $script:fails++ }
}

$capture = [string]$definitions[0]
Check-Pattern '공통 캡처가 화면 복사 담당' $capture 'CopyFromScreen\('
Check-Pattern '공통 캡처가 실패 상태 등록' $capture 'Register-CaptureFailure'
Check-Pattern '공통 캡처가 복구 상태 등록' $capture 'Register-CaptureSuccess'
Check-Pattern '공통 캡처가 미반환 Bitmap 해제' $capture 'if \(-not \$keepScaledCapture\).*Dispose\(\)'

for ($i = 1; $i -lt $definitions.Count; $i++) {
  $name = $names[$i]
  $body = [string]$definitions[$i]
  Check-Pattern "$name 공통 캡처 사용" $body 'Get-GameRegionCapture'
  Check-Pattern "$name 반환 Bitmap 해제" $body '\$capture\.Bitmap\.Dispose\(\)'
  Check-NoPattern "$name 직접 화면 복사 없음" $body 'CopyFromScreen\('
}

exit $fails
