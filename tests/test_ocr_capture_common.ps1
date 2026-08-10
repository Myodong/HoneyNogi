# OCR 세 진입점이 캡처·확대·해제 공통 헬퍼 하나를 공유하는지 검사합니다.
$ErrorActionPreference = 'Stop'
# ★ 10차 추가 계약: 캡처 진입점의 **모든 실패 원인**이 Register-CaptureFailure 를 거쳐야 합니다.
#   9차까지 GetWindowRect 실패만 기록 없이 $null 을 돌려줘, 창이 사라지는 중인 상태가
#   '판독 결과 없음'으로 둔갑하고 동결 계약(게임 사망/F9 감지)이 통째로 비껴갔습니다.
#   (이 블록은 아래 본문보다 먼저 두어, 나머지 검사가 실패해도 이 계약은 반드시 평가됩니다.)
$capProjectRoot = Split-Path -Parent $PSScriptRoot
$capWorkerPath = Join-Path $capProjectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$capBody = [string](Get-SourceFunctionDefinitions -Path $capWorkerPath -Names @('Get-GameRegionCapture'))
$capCode = (($capBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
$capFails = 0
if ($capCode -match "GetWindowRect\(\`$Game\.MainWindowHandle, \[ref\]\`$rect\)\) \{[\s\S]{0,400}?Register-CaptureFailure -GameWindowIssue 'rect-failed'") {
  "OK   캡처: 창 좌표 실패도 캡처 실패로 등록"
} else { "FAIL 캡처: 창 좌표 실패가 캡처 실패로 등록되지 않습니다"; $capFails++ }
if ($capCode -match "IsIconic\(\`$Game\.MainWindowHandle\)\) \{[\s\S]{0,900}?Register-CaptureFailure -GameWindowIssue 'minimized'") {
  "OK   캡처: 최소화도 캡처 실패로 등록(형제 계약 유지)"
} else { "FAIL 캡처: 최소화 등록이 사라졌습니다"; $capFails++ }
$failInfoBody = [string](Get-SourceFunctionDefinitions -Path $capWorkerPath -Names @('Get-CaptureFailInfo'))
$recoverBody = [string](Get-SourceFunctionDefinitions -Path $capWorkerPath -Names @('Get-CaptureRecoveryMessage'))
if (($failInfoBody -match "GameWindowIssue -eq 'rect-failed'") -and ($failInfoBody -match "Cause\s*=\s*'gameWindowGone'")) {
  "OK   캡처: 창 좌표 실패 전용 사유(gameWindowGone) 존재"
} else { "FAIL 캡처: 창 좌표 실패 전용 사유가 없습니다"; $capFails++ }
if ($recoverBody -match "'gameWindowGone'") {
  "OK   캡처: 그 사유의 복구 안내도 존재"
} else { "FAIL 캡처: gameWindowGone 복구 안내가 없습니다"; $capFails++ }
if ($capFails -gt 0) { exit $capFails }
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
# 2026-08-09 4차 점검: 이 함수는 Get-GamePixel 의 공용 입구라 **여기서는 기다리지 않습니다**.
# 픽셀 판정은 표본을 27회씩 찍으면서 catch { continue } 로 예외를 삼키므로, 여기에 대기를 두면
# 표본 수 × 재시도 횟수만큼 곱해져 수십 분을 무음으로 태웁니다(실측 ≈ 56분).
# 복원 대기는 클릭 1회에 1번만 도는 Click-GamePoint 로 옮겼습니다.
# 상세 계약은 tests\test_stall_guards.ps1 이 담당합니다.
Check-Pattern '좌표: 최소화 창은 즉시 throw (대기는 클릭 진입점에서)' $scaledPoint `
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
