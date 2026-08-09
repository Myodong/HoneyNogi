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

# ── 창 온전성 게이트 (2026-08-09 감사) ──────────────────────────────────────
# 최소화된 창은 검은 화면이 아니라 그 좌표에 있는 **다른 창**이 찍힐 수 있어, 빈 프레임
# 판정을 통과하고 캡처 '성공'으로 등록됩니다. 그러면 진행 중이던 실패 플래그까지 거짓
# 해제돼, 화면이 망가진 채로 자동화가 계속 굴러갑니다.
Check-Pattern '캡처: 최소화 창은 실패로 등록' $capture `
  'IsIconic\(\$Game\.MainWindowHandle\)\)\s*\{'
Check-Pattern '캡처: 최소화는 실패 등록 + 복원 시도' $capture `
  '(?s)IsIconic.*Invoke-AutoRefocus -Game \$Game.*Register-CaptureFailure -GameWindowIssue ''minimized'''
# 복원은 반드시 Invoke-AutoRefocus 경유여야 합니다. Focus-Game 을 직접 부르면
# focus.onlyWhenUserIdleSeconds 계약을 우회해, 사용자가 PC 를 쓰는 중에도 게임 창을 도로
# 띄우고 포커스를 뺏습니다 (2026-08-09 리뷰 적발).
Check-NoPattern '캡처: 복원이 유휴 계약을 우회하지 않음(직접 Focus-Game 금지)' $capture 'Focus-Game -Game \$Game'
# 실패로만 돌리면 대기 루프가 영원히 멈춥니다 (모든 대기 루프가 '같은 캡처 재시도'만 하고
# 전면화를 부르지 않기 때문). 복원 시도는 반드시 같이 있어야 합니다 - 2026-08-09 리뷰 적발.
Check-Pattern '캡처: 복원 시도는 시간 간격 제한(무인 중 사용자 방해 방지)' $capture `
  '\$script:lastMinimizedRestoreAt'
Check-Pattern '캡처: 게이트가 CopyFromScreen 앞에 있음' $capture `
  '(?s)Register-CaptureFailure -GameWindowIssue.*CopyFromScreen\('
# 과소 창은 캡처에서 막지 않습니다 - 자동 복원 수단이 없어 '빠른 실패'가 '무한 대기'로 바뀝니다.
# Get-ScaledScreenPoint 의 throw 가 첫 클릭에서 즉시 끝내 주는 것이 기존 계약입니다.
Check-NoPattern '캡처: 과소 창 게이트는 두지 않음(빠른 실패 보존)' $capture `
  "Register-CaptureFailure -GameWindowIssue 'tooSmall'"
# 원시 좌표 경로(클릭/픽셀)도 최소화를 막아야 합니다. 캡처만 막으면 최소화된 창 뒤의 다른
# 창 픽셀을 '회색 비활성 카드'로 오판해 상태 확인이 통과됩니다 (리뷰 적발).
$scaledPoint = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-ScaledScreenPoint'))
Check-Pattern '좌표: 최소화 창은 throw (클릭·픽셀 공용 입구)' $scaledPoint `
  "IsIconic\(\`$Game\.MainWindowHandle\)\)\s*\{\s*\r?\n\s*throw '게임 창이 최소화"
Check-Pattern '좌표: 기존 과소 창 throw 유지' $scaledPoint '게임 창 크기가 너무 작습니다'

# 원인 안내가 함께 추가되지 않으면 게이트만 넣은 셈이라 'RDP 창을 다시 열어 주세요' 라는
# 오진단이 그대로 나갑니다 - 원인/복구 문구를 실제 함수로 검증합니다.
foreach ($causeDefinition in (Get-SourceFunctionDefinitions -Path $workerPath `
      -Names @('Get-CaptureFailInfo', 'Get-CaptureRecoveryMessage'))) {
  Invoke-Expression $causeDefinition
}
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (실제 [$Actual] 기대 [$Expected])"; $script:fails++ }
}
$minInfo = Get-CaptureFailInfo -GameWindowIssue 'minimized'
Check-Equal '원인: 게임 창 최소화는 전용 Cause' $minInfo.Cause 'gameMinimized'
Check-Pattern '원인: 안내가 게임 창을 지목(RDP 오진단 아님)' $minInfo.Message '게임 창이 최소화'
Check-NoPattern '원인: RDP 창 안내가 섞이지 않음' $minInfo.Message 'RDP 창'
Check-Pattern '원인: 자동 복원 시도를 안내에 명시' $minInfo.Message '자동으로 복원'
# 복구 문구는 RDP 세션 상태를 참조하므로 최소 스텁을 심어 둡니다 (원격 아님 = 0)
if (-not ('HoneyNogiInput' -as [type])) {
  Add-Type -TypeDefinition 'public class HoneyNogiInput { public static int GetSystemMetrics(int index) { return 0; } }'
}
Check-Pattern '복구: 게임 창 최소화 전용 복구 문구' `
  (Get-CaptureRecoveryMessage -FailCause 'gameMinimized') '게임 창이 다시 열려'

for ($i = 1; $i -lt $definitions.Count; $i++) {
  $name = $names[$i]
  $body = [string]$definitions[$i]
  Check-Pattern "$name 공통 캡처 사용" $body 'Get-GameRegionCapture'
  Check-Pattern "$name 반환 Bitmap 해제" $body '\$capture\.Bitmap\.Dispose\(\)'
  Check-NoPattern "$name 직접 화면 복사 없음" $body 'CopyFromScreen\('
}

exit $fails
