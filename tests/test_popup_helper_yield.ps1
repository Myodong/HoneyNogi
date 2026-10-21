# 팝업 치우는 공용 함수 2개(구매 스윕·주간 리셋)의 사용자 조작 양보 계약 + 호출부 예산 (2026-09-13)
#
# 함수 안에서 user-active 취소를 '커서 확인 실패'로 적고 1~2초를 이미 쓴 뒤 돌아왔습니다. 호출부
# 대부분은 continue/return $false 로 재판독하니 실피해는 대기 낭비였지만, 시작 스윕 for(1..2) 3곳과
# 생활 메뉴 회전은 취소된 회전이 시도를 그대로 먹었습니다. 여기서 고정하는 계약(설계 합의):
#   함수: 전송 → 로그+대기 / user-active → 사유 로그 + Wait-UserYieldEnd + 즉시 $true (대기 생략) /
#         cursor-not-ready → 사유 로그 + 기존 대기. 반환값 의미('팝업을 감지해 이번 흐름을 처리')는 불변.
#   시작 스윕: user-active 면 $startSweep-- 후 continue (외부 1.2초 대기도 건너뜀)
#   생활 메뉴: 각 호출 직후 메타 확인, user-active 면 $menuTry-- 후 continue
# 6. 주간 리셋 캡처 실패 게이트(구현 단위 ④′ - 2026-10-18): 두 번째 판독 실패(원인 셋) → 포커스·클릭·메타 0 · 참 · 스윕 freeze / 시작 스윕 for(1..2) 3곳은 복구까지 동결 → 같은 시도로 다시 스윕해 닫음(시도 미소모) / 정상 경로 그대로 / 네트워크는 그대로(사전 포커스 1 · 클릭 0)
# 7. 시작부 팝업 정리의 캡처 실패 회전(구현 단위 C8): 스윕 안에 실패가 있었으면(이미 복구 포함) 끊지 않고 블록이 복구까지 동결 → 같은 시도로 다시 스윕(시도 미소모 · 스윕이 참이어도 1.2초 없이) / 그 회전에 사용자 조작 취소가 겹치면 조작이 끝날 때까지 기다린 뒤 한 번 되돌림(분기 순서) / 평상시 그대로
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-PurchasePopupSweep', 'Close-WeeklyCoopResetPopup')) {
  # 원문 스윕은 Invoke-RealPurchasePopupSweep 이름으로 올리고 아래 감싸개가 호출 수를 셉니다 (구현 단위 C8)
  Invoke-Expression ($definition -replace '^function Invoke-PurchasePopupSweep\b', 'function Invoke-RealPurchasePopupSweep')
}
function Invoke-PurchasePopupSweep {
  # 호출 수 상한 감싸개 - 시작 스윕 루프가 대기 없이 끝없이 도는 변이(끊기가 영영 거짓 · 동결 while 삭제)에서도 러너가 멈추지 않고
  # FAIL 로 끝나게 합니다(러너에 파일별 시간 상한 없음 · 정상 실행 합계는 이 상한보다 훨씬 작음). 반환은 원문 그대로
  param($Game)
  $script:sweepCallCount++
  if ($script:sweepCallCount -gt 1000) { throw '스윕 호출 1000회 초과 - 시작 스윕 루프가 끝나지 않습니다' }
  return (Invoke-RealPurchasePopupSweep -Game $Game)
}

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
$game = $null

# ── 모의: 가상 시계 + 팝업 상태(전송된 클릭으로만 사라짐) ─────────────────────
$script:vclock = [datetime]'2026-01-01 00:00:00'
function Get-Date { return $script:vclock }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) $ms = $Milliseconds; if ($Seconds) { $ms = $Seconds * 1000 }; $script:vclock = $script:vclock.AddMilliseconds($ms) }
function Focus-Game { param($Game) }
function Move-CursorOutsideGame { param($Game) }   # 커서가 창 밖인 조작을 모형화 - 대피 게이트는 안 도는 상황
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Test-GameRestartPopup { param($Game) $false }
function Close-QuestRewardScreen {
  # 위임 함수 모형 - 실제 함수처럼 **기다리지 않고** 취소돼도 1초 대기 뒤 $true (클릭 메타는 공용 클릭이 남김)
  param($Game, $BottomText)
  if (-not $script:rewardOpen) { return $false }
  if ($script:rewardCancelLeft -gt 0) { $script:rewardCancelLeft--; $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active' }
  else { $script:lastClickPerformed = $true; $script:lastClickSkipReason = ''; $script:clicksSent++; $script:rewardOpen = $false }
  $script:vclock = $script:vclock.AddMilliseconds(1000)
  return $true
}
function Close-CoopMissionScreen { param($Game) $false }
function Close-CoopMissionBoardScreen { param($Game, $LogPrefix) $false }
function Close-NetworkUnstablePopup { param($Game) $false }
function Get-GameOcrText { param($Game) '' }
$rgPopupClose = @(1,1,1,1); $rgClearExit = @(2,2,2,2); $ocrKoreanEngine = $null
$script:purchaseOpen = $false; $script:weeklyOpen = $false
function Find-GameTextPoint { param($Game,$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight,$SearchText,$ExactText)
  if ($ReferenceX -eq 1 -and $script:purchaseOpen) { return [pscustomobject]@{ X = 640; Y = 500 } }
  if ($ReferenceX -eq 2 -and $script:weeklyOpen)   { return [pscustomobject]@{ X = 495; Y = 654 } }
  $null }
function Get-GameRegionOcrText { param($Game,$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight,$Scale,$Engine) if ($ReferenceX -eq 2 -and $script:weeklyOpen) { '닫기협동미션참여하기' } else { '' } }

$script:sendSeq = @(); $script:sendIdx = 0
# 실제 계약대로: 조작이 이미 끝났으면(유휴) 즉시 반환, 조작 중이면 끝날 때까지 기다림. 구현 리뷰 지적 -
# 호출마다 무조건 3초를 더하는 모의는 '직접 닫기가 이미 기다렸으면 호출부의 재대기는 즉시 반환' 계약을 못 봄.
$script:userBusyMs = 0   # 남은 조작 시간 (0이면 유휴)
function Wait-UserYieldEnd {
  param($Game, $Context)
  $script:yieldCalls++; $script:yieldContexts += $Context
  if ($script:userBusyMs -le 0) { return }   # 유휴 - 즉시 반환, 누적 없음
  $script:yieldWaits++
  $script:vclock = $script:vclock.AddMilliseconds($script:userBusyMs)
  $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $script:userBusyMs
  $script:userBusyMs = 0
}
function Invoke-ClickModel {
  param([string]$Kind)
  $r = 'sent'
  if ($script:sendIdx -lt $script:sendSeq.Count) { $r = $script:sendSeq[$script:sendIdx]; $script:sendIdx++ }
  $script:lastClickPerformed = ($r -eq 'sent')
  $script:lastClickSkipReason = if ($r -eq 'sent') { '' } else { $r }
  if ($r -eq 'sent') { $script:clicksSent++; if ($Kind -eq 'purchase') { $script:purchaseOpen = $false } else { $script:weeklyOpen = $false } }
}
function Click-ScreenPoint { param($X, $Y) Invoke-ClickModel -Kind $(if ($Y -eq 500) { 'purchase' } else { 'weekly' }) }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) Invoke-ClickModel -Kind 'weekly' }
function Reset-Case {
  param([bool]$Purchase = $false, [bool]$Weekly = $false, $SendSeq = @())
  $script:vclock = [datetime]'2026-01-01 00:00:00'
  $script:purchaseOpen = $Purchase; $script:weeklyOpen = $Weekly
  $script:logs = @(); $script:yieldWaits = 0; $script:yieldCalls = 0; $script:yieldContexts = @(); $script:clicksSent = 0
  $script:userBusyMs = 3000   # 기본: 첫 양보 호출 때 조작 중(3초), 그 뒤 유휴
  $script:rewardOpen = $false; $script:rewardCancelLeft = 0
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = ''
  $script:userYieldTotalMs = [double]0; $script:screenCaptureFailing = $false
  $script:sendIdx = 0; $script:sendSeq = @($SendSeq)
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }
function Elapsed { ($script:vclock - [datetime]'2026-01-01 00:00:00').TotalSeconds }

# ── 1. 구매 스윕 ────────────────────────────────────────────────────────────
Reset-Case -Purchase $true
$r = Invoke-PurchasePopupSweep -Game $game
Check-Equal '스윕 전송: $true + 닫기 로그 + 1초 대기' ("$r/$((Count-Log '닫기 클릭 \(입장 대기 중\)'))/$((Elapsed))") 'True/1/1'

Reset-Case -Purchase $true -SendSeq @('user-active')
$r = Invoke-PurchasePopupSweep -Game $game
Check-Equal '스윕 user-active: $true (반환 의미 불변)' $r $true
Check-Equal '스윕 user-active: 사유 로그가 사용자 조작 (커서 실패 아님)' ("$((Count-Log '사용자 조작으로 닫기 클릭을 취소'))/$((Count-Log '커서 확인 실패로'))") '1/0'
Check-Equal '스윕 user-active: 기다린 뒤 즉시 반환 (1초 대기 생략 → 경과 = 양보 3초)' ("$($script:yieldWaits)/$((Elapsed))") '1/3'
Check-Equal '스윕 user-active: 팝업은 그대로 (호출부 재판독이 다시 봄)' $script:purchaseOpen $true
Check-Equal '스윕 user-active: 메타가 호출부에 남음' ("$($script:lastClickPerformed)/$($script:lastClickSkipReason)") 'False/user-active'

Reset-Case -Purchase $true -SendSeq @('cursor-not-ready')
$r = Invoke-PurchasePopupSweep -Game $game
Check-Equal '스윕 cursor-not-ready: 기존대로 사유 로그 + 1초 대기 + 양보 없음' ("$r/$((Count-Log '커서 확인 실패로'))/$((Elapsed))/$($script:yieldWaits)") 'True/1/1/0'

Reset-Case
Check-Equal '스윕 팝업 없음: $false' (Invoke-PurchasePopupSweep -Game $game) $false

# ── 2. 주간 리셋 ────────────────────────────────────────────────────────────
Reset-Case -Weekly $true
$r = Close-WeeklyCoopResetPopup -Game $game -LogPrefix '[심층] '
Check-Equal '주간 전송: $true + 닫기 로그 + 2초 대기' ("$r/$((Count-Log '주간 협동 미션 팝업 감지 - 닫기 클릭'))/$((Elapsed))") 'True/1/2'

Reset-Case -Weekly $true -SendSeq @('user-active')
$r = Close-WeeklyCoopResetPopup -Game $game -LogPrefix '[심층] '
Check-Equal '주간 user-active: $true + 사유 로그 + 즉시 반환' ("$r/$((Count-Log '사용자 조작으로 닫기 클릭을 취소'))/$($script:yieldWaits)/$((Elapsed))") 'True/1/1/3'
Check-Equal '주간 user-active: 접두어 유지' (Count-Log '^\[안내\] \[심층\] 주간') 1

Reset-Case -Weekly $true -SendSeq @('cursor-not-ready')
$r = Close-WeeklyCoopResetPopup -Game $game -LogPrefix '[심층] '
Check-Equal '주간 cursor-not-ready: 사유 로그 + 2초 대기 + 양보 없음' ("$r/$((Count-Log '커서 확인 실패로 닫기 클릭을 건너뜀'))/$((Elapsed))/$($script:yieldWaits)") 'True/1/2/0'

# ── 3. 호출부: 시작 스윕 for(1..2) 3곳 - 실제 루프문을 AST 로 잘라 실행 ──────────
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$tokens, [ref]$parseErrors)
$sweepLoops = @($ast.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.ForStatementAst] -and
    $n.Extent.Text -match 'Invoke-PurchasePopupSweep' -and $n.Extent.Text -match '\$startSweep'
  }, $true))
Check-Equal '시작 스윕: 운영 루프 3곳 추출' $sweepLoops.Count 3
foreach ($loopAst in $sweepLoops) {
  $loop = [scriptblock]::Create($loopAst.Extent.Text)
  $Game = $game
  # (a) 팝업 1개 정상 → 스윕 1회 닫고(1초) + 외부 1.2초 → 2회째 팝업 없음 → break
  Reset-Case -Purchase $true
  & $loop
  Check-Equal ("시작 스윕 {0}: 정상 - 클릭 1, 경과 2.2초" -f $loopAst.Extent.StartLineNumber) ("$($script:clicksSent)/$((Elapsed))") '1/2.2'
  # (b) ★ 취소 2회 뒤 전송 → 시도를 안 써서 결국 닫힘. 예전엔 취소 2회로 for 가 끝나 클릭 0 + 2.4초 낭비
  Reset-Case -Purchase $true -SendSeq @('user-active', 'user-active', 'sent')
  & $loop
  Check-Equal ("시작 스윕 {0}: 취소 2회 뒤에도 닫힘 (시도 미소모)" -f $loopAst.Extent.StartLineNumber) ("$($script:clicksSent)/$($script:purchaseOpen)") '1/False'
  # 직접 닫기가 이미 기다렸으므로 호출부의 재대기는 유휴 즉시 반환 - 실제 대기는 스윕 안 첫 1회뿐.
  # 호출 수 4 = 취소 2회 × (스윕 안 1 + 호출부 1). 첫 호출만 조작 중(3초), 나머지 3회는 유휴 즉시 반환.
  Check-Equal ("시작 스윕 {0}: 직접 닫기 취소는 중복 대기 없음 (실대기 1, 호출 4)" -f $loopAst.Extent.StartLineNumber) ("$($script:yieldWaits)/$($script:yieldCalls)") '1/4'
  # (d) ★ 위임 경로(보상 화면) 취소: 위임 함수는 안 기다리므로 **호출부가** 기다려야 한다 (구현 리뷰 P2)
  Reset-Case
  $script:rewardOpen = $true; $script:rewardCancelLeft = 2
  & $loop
  Check-Equal ("시작 스윕 {0}: 위임 취소 2회 - 호출부가 기다린 뒤 되돌려 닫힘" -f $loopAst.Extent.StartLineNumber) ("$($script:clicksSent)/$($script:rewardOpen)/$($script:yieldWaits)") '1/False/1'
  Check-Equal ("시작 스윕 {0}: 위임 취소는 시도를 안 씀 (경과 = 양보 3초 + 위임 1초×3 + 외부 1.2초)" -f $loopAst.Extent.StartLineNumber) ((Elapsed) -lt 9) $true
  # (c) cursor-not-ready 2회 → 기존대로 시도 소모 → 클릭 0 으로 끝남 (유한)
  Reset-Case -Purchase $true -SendSeq @('cursor-not-ready', 'cursor-not-ready', 'sent')
  & $loop
  Check-Equal ("시작 스윕 {0}: 커서 미확인 2회는 시도 소모로 유한 종료" -f $loopAst.Extent.StartLineNumber) ("$($script:clicksSent)/$($script:yieldWaits)") '0/0'
}

# ── 4. 호출부: 생활 메뉴 회전의 팝업 방어 2줄 - 소스 구조 단언 ─────────────────
$workerRaw = Get-Content -LiteralPath $workerPath -Raw -Encoding UTF8
$code = (($workerRaw -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
$menuBlock = [regex]::Match($code, '(?s)while \(\$menuTry -lt 3 -and -not \$menuOk.{0,3000}?Close-LifeBlockingDialog').Value
Check-Equal '생활 메뉴: 회전 블록 추출' ($menuBlock.Length -gt 0) $true
Check-Equal '생활 메뉴: 스윕 직후 메타 확인 + user-active 면 기다린 뒤 회전 되돌림' ($menuBlock -match '(?s)if \(Invoke-PurchasePopupSweep -Game \$Game\) \{\s*if \(-not \$script:lastClickPerformed -and \$script:lastClickSkipReason -eq ''user-active''\) \{\s*Wait-UserYieldEnd[^
]*\s*\$menuTry--\s*continue') $true
Check-Equal '생활 메뉴: 주간 리셋 직후 메타 확인 + user-active 면 기다린 뒤 회전 되돌림' ($menuBlock -match '(?s)if \(Close-WeeklyCoopResetPopup -Game \$Game -LogPrefix ''\[생활\] ''\) \{\s*if \(-not \$script:lastClickPerformed -and \$script:lastClickSkipReason -eq ''user-active''\) \{\s*Wait-UserYieldEnd[^
]*\s*\$menuTry--\s*continue') $true
Check-Equal '생활 메뉴: 두 호출 앞에서 사유 메타 초기화' ([regex]::Matches($menuBlock, "\`$script:lastClickSkipReason = ''").Count -ge 2) $true

# ── 5. 함수 구조 단언 ───────────────────────────────────────────────────────
$sweepCode = (([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-PurchasePopupSweep')) -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
$weeklyCode = (([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Close-WeeklyCoopResetPopup')) -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Check-Equal '구조: 스윕 user-active 분기가 대기 앞에서 return $true' ($sweepCode -match "(?s)-eq 'user-active'\) \{.{0,200}?Wait-UserYieldEnd.{0,80}?return \`$true.{0,400}?Start-Sleep -Seconds 1") $true
Check-Equal '구조: 주간 user-active 분기가 대기 앞에서 return $true' ($weeklyCode -match "(?s)-eq 'user-active'\) \{.{0,200}?Wait-UserYieldEnd.{0,80}?return \`$true.{0,400}?Start-Sleep -Seconds 2") $true
Check-Equal '구조: 두 함수 모두 $false 로 바꾸지 않음 (user-active 뒤 return $false 없음)' (($sweepCode -notmatch "user-active'\) \{[^}]*return \`$false") -and ($weeklyCode -notmatch "user-active'\) \{[^}]*return \`$false")) $true

# ── 6. 주간 리셋 캡처 실패 게이트 (구현 단위 ④′ - 2026-10-18) ─────────────────────
# 주간 리셋 팝업 닫기는 첫 판독(스위치 판독)이 '협동'+'참여' 를 확정한 뒤 두 번째 판독(Find-GameTextPoint - 스위치 없음)으로 '닫기' 를
# 찾습니다. 그 두 번째 판독에서 캡처 실패가 시작되면 게이트 없는 꼴은 포커스(ALT 주입) 뒤 예비 좌표를 화면 확인 없이 누르거나(눈감은 클릭)
# 클릭 경로가 창 좌표·최소화로 던져 코드 1 로 끝납니다 - 규칙 4·15 위반(두 판독 사이의 경합이라 실기 관측 0 - 구현 명세 ④′ 0.3).
# 이 섹션이 고정하는 것(구현 명세 ④′ 2.2 · 3.2 - 19행):
#   GT0       게이트 if(첫 절 조건 = $script:screenCaptureFailing 단독 · 본문 return $true) 1 · 그 본문 Write-RunLog 1(안내 문구 캡처까지) · 클릭 메타 대입 0 (소스 캡처)
#   GT1~GT7   주간 helper 원문 단독 - 원인 셋(창 좌표 · 최소화 복원 실패/성공 · 그 밖)이면 포커스·클릭·대기·안전 확인·탐침·메타 쓰기 0 · 참 · 안내 1,
#             정상 경로(두 번째 판독 성공)는 지금과 같음, 옛 메타는 미전송(False/user-active)·전송(True/'') 양쪽 그대로
#   GS1~GS4   공용 스윕 원문 → 원문 Resolve-AbyssMemberSweepTurn = 'freeze' (다음 회전 동결 블록이 받음)
#   GS5~GS10  시작 스윕 for(1..2) 3곳(섹션 3 의 원문 루프) - 게이트 회전은 복구까지 동결(공통 진입점 · 2초 · 탐침) → 같은 시도로 다시 스윕해
#             정상 경로로 닫음 · 시도 미소모 (덮인 팝업 위 시작 판정이 08-17 꼴로 결과 화면을 오판하지 않게 - 사용자 결정 2026-10-18)
#   GN1       네트워크 불안정 팝업은 그대로 - 사전 포커스 1 · 클릭 0 · 거짓
# 앞 섹션의 행은 그대로 두고 이 섹션 안에서 모의를 다시 정의합니다(재정의는 이 뒤 호출에만 적용). 원인 셋 · 클릭 경로 문구 둘 · 게이트 안내
# 문구는 워커 원문에서 캡처합니다(다시 박지 않음). 클릭 helper 모의는 게이트 없는 꼴의 결과 모형이라 '고치기 전 재현' 이 행 안에서 보입니다
# (게이트·시작부 블록이 없는 워커에서는 GT0~GT4 · GT6 · GS1~GS10 16행이 FAIL). 반복 변수는 Reset-WeeklyGateCase 가 비우는 $script: 상태
# 이름과 겹치지 않게 둡니다 - 이 섹션은 스크립트 범위에서 돌아 같은 이름이면 같은 변수입니다.

# 6-0. 준비 - 워커 원문 캡처 (섹션 3 의 $ast = 워커 전체 AST). 원인·문구를 못 읽으면 아래 행이 뜻을 잃으므로 FAIL 로 끝냅니다
$workerFunctionNodes = @{}
foreach ($functionNode in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
  if (-not $workerFunctionNodes.ContainsKey($functionNode.Name)) { $workerFunctionNodes[$functionNode.Name] = $functionNode }
}
function Get-ReturnedCauseValue {
  # return @{ Cause = '…'; Message = '…' } 문장의 Cause 값을 꺼냅니다 (꼴이 다르면 $null - 준비 단계가 FAIL 로 끝냄)
  param($Statement)
  if (-not ($Statement -is [System.Management.Automation.Language.ReturnStatementAst]) -or -not $Statement.Pipeline) { return $null }
  $tableNode = $Statement.Pipeline.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $true)
  if (-not $tableNode) { return $null }
  foreach ($pair in $tableNode.KeyValuePairs) {
    if ([string]$pair.Item1.Extent.Text -cne 'Cause') { continue }
    $valueNode = $pair.Item2.Find({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)
    if ($valueNode) { return [string]$valueNode.Value }
  }
  return $null
}
try {
  foreach ($requiredName in @('Get-CaptureFailInfo', 'Get-ScaledScreenPoint', 'Close-WeeklyCoopResetPopup', 'Resolve-AbyssMemberSweepTurn', 'Close-NetworkUnstablePopup', 'Select-NetworkRetryWord')) {
    if (-not $workerFunctionNodes.ContainsKey($requiredName)) { throw "워커 함수 $requiredName 를 찾지 못했습니다" }
  }
  # ① 원인 셋 - Get-CaptureFailInfo 의 rect-failed · minimized 갈래 return 과 함수 끝 return(그 밖)
  $failInfoIfNodes = @($workerFunctionNodes['Get-CaptureFailInfo'].FindAll({ param($node) $node -is [System.Management.Automation.Language.IfStatementAst] }, $true))
  $windowGoneIfNodes = @($failInfoIfNodes | Where-Object { $_.Clauses[0].Item1.Extent.Text -ceq "`$GameWindowIssue -eq 'rect-failed'" })
  $minimizedIfNodes = @($failInfoIfNodes | Where-Object { $_.Clauses[0].Item1.Extent.Text -ceq "`$GameWindowIssue -eq 'minimized'" })
  if ($windowGoneIfNodes.Count -ne 1 -or $minimizedIfNodes.Count -ne 1) { throw "Get-CaptureFailInfo 의 rect-failed · minimized 갈래가 각 1개가 아닙니다 ($($windowGoneIfNodes.Count)/$($minimizedIfNodes.Count))" }
  $CAUSE_WINDOW_GONE = Get-ReturnedCauseValue (@($windowGoneIfNodes[0].Clauses[0].Item2.Statements)[0])
  $CAUSE_MINIMIZED = Get-ReturnedCauseValue (@($minimizedIfNodes[0].Clauses[0].Item2.Statements)[0])
  $CAUSE_OTHER = Get-ReturnedCauseValue (@($workerFunctionNodes['Get-CaptureFailInfo'].Body.EndBlock.Statements)[-1])
  if (-not $CAUSE_WINDOW_GONE -or -not $CAUSE_MINIMIZED -or -not $CAUSE_OTHER) { throw "원인 셋을 읽지 못했습니다 ([$CAUSE_WINDOW_GONE] [$CAUSE_MINIMIZED] [$CAUSE_OTHER])" }
  # ② 클릭 경로 문구 둘 - Get-ScaledScreenPoint 의 throw 가운데 '최소화' · '좌표' 를 담은 문자열 상수
  $clickThrowTexts = @(foreach ($throwNode in $workerFunctionNodes['Get-ScaledScreenPoint'].FindAll({ param($node) $node -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)) {
      if (-not $throwNode.Pipeline) { continue }
      $throwTextNode = $throwNode.Pipeline.Find({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)
      if ($throwTextNode) { [string]$throwTextNode.Value }
    })
  $clickMinimizedTexts = @($clickThrowTexts | Where-Object { $_.Contains('최소화') })
  $clickRectFailTexts = @($clickThrowTexts | Where-Object { $_.Contains('좌표') })
  if ($clickMinimizedTexts.Count -ne 1 -or $clickRectFailTexts.Count -ne 1) { throw "Get-ScaledScreenPoint 의 최소화 · 창 좌표 throw 문구가 각 1개가 아닙니다 ($($clickMinimizedTexts.Count)/$($clickRectFailTexts.Count))" }
  $CLICK_MINIMIZED_TEXT = $clickMinimizedTexts[0]
  $CLICK_RECT_FAIL_TEXT = $clickRectFailTexts[0]
} catch {
  "FAIL 섹션 6 준비: 워커 원문 캡처 실패 ($($_.Exception.Message))"
  $fails++
  exit $fails
}
# ③ 게이트 안내 문구 + GT0 - 주간 helper 안 게이트 if(첫 절 조건 = 플래그 단독 · 본문 return $true) · 그 본문의 Write-RunLog · 클릭 메타 대입문
#    (AST 라 주석 무관. 메타 대입 0 은 행동 행 GT6 · GT7 이 못 보는 '옛 메타와 같은 값을 쓰는 꼴' 까지 막습니다 - 구현 명세 ④′ 3.4)
$gateIfNodes = @($workerFunctionNodes['Close-WeeklyCoopResetPopup'].Body.FindAll({ param($node)
    ($node -is [System.Management.Automation.Language.IfStatementAst]) -and
    ($node.Clauses[0].Item1.Extent.Text -match '^\$script:screenCaptureFailing$') -and
    (@($node.Clauses[0].Item2.FindAll({ param($inner) ($inner -is [System.Management.Automation.Language.ReturnStatementAst]) -and $inner.Pipeline -and ($inner.Pipeline.Extent.Text -match '^\$true$') }, $true)).Count -gt 0)
  }, $true))
$gateLogNodes = @(if ($gateIfNodes.Count -eq 1) { $gateIfNodes[0].Clauses[0].Item2.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Write-RunLog') }, $true) })
$gateMetaAssignNodes = @(if ($gateIfNodes.Count -eq 1) { $gateIfNodes[0].Clauses[0].Item2.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -match '\$script:lastClick(Performed|SkipReason)\b') }, $true) })
$GATE_NOTICE_PREFIX = '[안내] ${LogPrefix}주간 협동 미션 팝업 감지 - '   # 작은따옴표 - ${LogPrefix} 를 글자 그대로 대조합니다
$GATE_NOTICE_KEY = '<게이트 안내 문구 캡처 실패>'                         # 못 찾으면 GT0 이 FAIL 하고 다른 행은 이 표지로 대조를 이어 갑니다
$gateNoticeCaptured = $false
if ($gateLogNodes.Count -eq 1) {
  $gateNoticeArgument = @($gateLogNodes[0].CommandElements | Select-Object -Skip 1 | Where-Object { -not ($_ -is [System.Management.Automation.Language.CommandParameterAst]) })[0]
  if (($gateNoticeArgument -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -or ($gateNoticeArgument -is [System.Management.Automation.Language.StringConstantExpressionAst])) {
    $gateNoticeRaw = [string]$gateNoticeArgument.Value
    if ($gateNoticeRaw.StartsWith($GATE_NOTICE_PREFIX, [System.StringComparison]::Ordinal) -and ($gateNoticeRaw.Length -gt $GATE_NOTICE_PREFIX.Length)) {
      $GATE_NOTICE_KEY = $gateNoticeRaw.Substring($GATE_NOTICE_PREFIX.Length)
      $gateNoticeCaptured = $true
    }
  }
}
# GT0 의 둘째 값은 'Write-RunLog 1 → 안내 문구 캡처' 입니다(구현 명세 ④′ 2.2 ③ · 3.2 GT0). 줄 수만 세면 안내 줄은 있는데 문구를 못 읽는 꼴(접두가
# 다름 · 인자가 문자열이 아님)에서 GT0 이 통과하고, 그 캡처 실패가 GT1~GT4 · GS5~GS7 의 '안내 0' 으로만 드러났습니다(2026-10-18 구현 리뷰 - 게이트
# 안내에서 ${LogPrefix} 를 지운 변이로 확인). 그래서 문구를 못 읽으면 줄 수 뒤에 표지를 붙여 이 행이 FAIL 합니다 - 기대 '1/1/0' 은 그대로
$gateLogCountShown = "$($gateLogNodes.Count)"
if (-not $gateNoticeCaptured) { $gateLogCountShown += '(문구 캡처 실패)' }
Check-Equal 'GT0 소스 캡처 - 주간 helper 의 게이트 if(조건 = 플래그 단독 · 본문 return $true) 1 · 그 본문 Write-RunLog 1(안내 문구 캡처) · 클릭 메타 대입 0' ("$($gateIfNodes.Count)/$gateLogCountShown/$($gateMetaAssignNodes.Count)") '1/1/0'
"INFO 섹션 6 캡처: 원인 [$CAUSE_WINDOW_GONE] [$CAUSE_MINIMIZED] [$CAUSE_OTHER] · 클릭 경로 문구 [$CLICK_RECT_FAIL_TEXT] [$CLICK_MINIMIZED_TEXT] · 게이트 안내 문구 [$GATE_NOTICE_KEY]"
# ④ 원문 어비스 스윕 분류 (GS1~GS4 가 스윕 결과를 그대로 넘김)
Invoke-Expression ([string]$workerFunctionNodes['Resolve-AbyssMemberSweepTurn'].Extent.Text)

# 6-1. 모의 재정의 (이 뒤 호출에만 적용 - 앞 38행 무관)
function Focus-Game { param($Game) $script:focusCalls++ }
function Register-MockCaptureFailure {
  # 원문 Register-CaptureFailure 의 상태 모형 - 일련번호 +1 · 플래그 참 · 원인 (경고 줄은 생략)
  param([string]$Cause)
  $script:captureFailSerial++
  $script:screenCaptureFailing = $true
  $script:captureFailCause = $Cause
}
function Find-GameTextPoint {
  # 두 번째 판독 모드는 주간 helper 의 '닫기' 탐색(-ReferenceX $rgClearExit[0] · -SearchText '닫기')에만, 남은 횟수만큼 겁니다: 원인 이름이면
  # 그 원인으로 실패를 등록한 뒤 $null(원문은 스위치가 없어 등록만 하고 $null), 'miss' 면 등록 없이 $null. 스윕의 구매 '닫기' 탐색($rgPopupClose)에는
  # 걸지 않습니다 - 걸면 구매 탐색이 먼저 실패를 등록해(이 하니스의 판독 모의는 성공 등록이 없음) 주간 helper 서두 가드가 끊고 올바른 게이트에서도
  # 스윕이 거짓이 됩니다(구현 명세 ④′ 2.2). 남은 횟수가 다하면 섹션 3 과 같은 응답 - 복구 뒤 같은 시도로 다시 스윕한 회전은 판독이 성공해야 닫힘을 봅니다
  param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText, $ExactText)
  if (($ReferenceX -eq $rgClearExit[0]) -and ($SearchText -eq '닫기') -and ($script:secondReadFailuresLeft -gt 0)) {
    $script:secondReadFailuresLeft--
    if ($script:secondReadMode -ne 'miss') { Register-MockCaptureFailure -Cause $script:secondReadMode }
    return $null
  }
  if (($ReferenceX -eq $rgPopupClose[0]) -and $script:purchaseOpen) { return [pscustomobject]@{ X = 640; Y = 500 } }
  if (($ReferenceX -eq $rgClearExit[0]) -and $script:weeklyOpen) { return [pscustomobject]@{ X = 495; Y = 654 } }
  return $null
}
function Get-GameOcrText {
  # 하단 판독 - 보관 캡처(08-17 06:02 타 PC 실사고 '던전이미지\공통\20260817_주간리셋팝업_입장대기_1272.png')를 워커 원문 판독으로 읽은 문구.
  # 주간 팝업이 열려 있고 캡처가 살아 있을 때만 - 닫은 뒤 둘째 시도의 스윕은 거짓으로 break 합니다
  param($Game)
  if ($script:weeklyOpen -and -not $script:screenCaptureFailing) { return '〔㉬닫기Space협동미션참여하기' }
  return ''
}
function Click-GamePoint {
  # 기준 좌표 클릭 - 게이트 없는 꼴의 결과 모형. 원문은 최소화 복원 대기 뒤 창 좌표 환산(Get-ScaledScreenPoint)을 거치므로 던지는 갈래가 여기
  # 있습니다: 원인이 창 좌표면 클릭 경로 문구, 최소화이고 복원 실패면 최소화 문구로 던지고, 그 밖은 클릭(플래그 참이면 눈감은 클릭으로 셈)
  param($Game, $ReferenceX, $ReferenceY)
  $script:gamePointClicks++
  if ($script:screenCaptureFailing -and ($script:captureFailCause -eq $CAUSE_WINDOW_GONE)) { throw $CLICK_RECT_FAIL_TEXT }
  if ($script:screenCaptureFailing -and ($script:captureFailCause -eq $CAUSE_MINIMIZED) -and -not $script:restoreSucceeds) { throw $CLICK_MINIMIZED_TEXT }
  if ($script:screenCaptureFailing) { $script:blindClicks++ }
  Invoke-ClickModel -Kind 'weekly'
}
function Click-ScreenPoint {
  # 화면 좌표 클릭 - 원문은 창 좌표를 읽지 않아 던지는 갈래가 없습니다. 클릭하고, 플래그 참이면 눈감은 클릭으로 셈
  param($X, $Y)
  $script:screenPointClicks++
  if ($script:screenCaptureFailing) { $script:blindClicks++ }
  Invoke-ClickModel -Kind $(if ($Y -eq 500) { 'purchase' } else { 'weekly' })
}
function Test-SafeStopDuringCaptureFail {
  # 공통 진입점 - 셈. 30회를 넘으면 '동결이 복구를 영영 못 봄'(복구 탐침이 빠진 자기 잠금 - 규칙 15 ⑤)으로 보고 던져, 무한 회전 대신 행이 FAIL 합니다
  $script:safeStopCalls++
  if ($script:safeStopCalls -gt 30) { throw '섹션 6 모의: 공통 진입점 30회 초과 - 동결이 복구를 보지 못합니다(복구 탐침 누락 = 자기 잠금)' }
}
function Test-CaptureRecovered {
  # 복구 탐침 - 셈. 이 행이 정한 N 회째 탐침에서 캡처가 돌아옵니다(원문 Register-CaptureSuccess 모형 - 플래그·원인 비움). 원문처럼 복구 여부를 돌려줌
  param($Game)
  $script:probeCalls++
  if ($script:screenCaptureFailing -and ($script:recoverAtProbe -gt 0) -and ($script:probeCalls -ge $script:recoverAtProbe)) {
    $script:screenCaptureFailing = $false
    $script:captureFailCause = $null
  }
  return (-not $script:screenCaptureFailing)
}
function Reset-WeeklyGateCase {
  # 섹션 6 전용 초기화 - 앞 Reset-Case(가상 시계 · 팝업 · 로그 · 클릭 메타 · 플래그) 위에 두 번째 판독 모드·남은 횟수, 복원 성공 여부, 복구 탐침 회차,
  # 구매 팝업 동시 열림(GS8~GS10), 셈 · 일련번호 · 원인을 비웁니다. 조작은 0 (양보 모의는 호출 수만 셈)
  param([string]$SecondRead = '', [int]$SecondReadFails = 1, [bool]$RestoreSucceeds = $false, [int]$RecoverAtProbe = 0,
    [bool]$Purchase = $false, [bool]$Weekly = $true)
  Reset-Case -Purchase $Purchase -Weekly $Weekly
  $script:userBusyMs = 0
  $script:secondReadMode = $SecondRead
  $script:secondReadFailuresLeft = $(if ($SecondRead) { $SecondReadFails } else { 0 })
  $script:restoreSucceeds = $RestoreSucceeds
  $script:recoverAtProbe = $RecoverAtProbe
  $script:focusCalls = 0; $script:gamePointClicks = 0; $script:screenPointClicks = 0; $script:blindClicks = 0
  $script:safeStopCalls = 0; $script:probeCalls = 0
  $script:captureFailSerial = 0; $script:captureFailCause = $null
}
function Invoke-WeeklyHelperOnce {
  # 원문 주간 helper 를 한 번 부르고 예외 문구·반환값을 남깁니다 (기대는 예외 0 - 게이트 없는 꼴의 클릭 경로 throw 는 여기 문구로 보임)
  param([string]$LogPrefix)
  $script:weeklyCallError = ''
  $script:weeklyCallResult = $null
  try { $script:weeklyCallResult = Close-WeeklyCoopResetPopup -Game $game -LogPrefix $LogPrefix }
  catch { $script:weeklyCallError = $_.Exception.Message }
}

# 6-2. GT - 주간 helper 원문 단독 (하단 주간 문구 · 접두 '[심층] ')
$gateCauseRows = @(
  @{ Id = 1; Label = '창 좌표'; Cause = $CAUSE_WINDOW_GONE; Restore = $false },
  @{ Id = 2; Label = '최소화 · 복원 실패'; Cause = $CAUSE_MINIMIZED; Restore = $false },
  @{ Id = 3; Label = '최소화 · 복원 성공'; Cause = $CAUSE_MINIMIZED; Restore = $true },
  @{ Id = 4; Label = '그 밖'; Cause = $CAUSE_OTHER; Restore = $false })
foreach ($gateCauseRow in $gateCauseRows) {
  Reset-WeeklyGateCase -SecondRead $gateCauseRow.Cause -RestoreSucceeds $gateCauseRow.Restore
  Invoke-WeeklyHelperOnce -LogPrefix '[심층] '
  # 예외 | 반환 | 포커스 | 예비 좌표 클릭 | 화면 좌표 클릭 | 눈감은 클릭 | 플래그 | 원인 | 경과 | 안전 확인 | 탐침 | 게이트 안내 | '감지 - 닫기 클릭' 로그
  Check-Equal ('GT{0} 주간 게이트 - 두 번째 판독 캡처 실패 {1}({2}) → 포커스·클릭·대기·안전 확인·탐침 0 · 참 · 원인 그대로 · 안내 1' -f $gateCauseRow.Id, $gateCauseRow.Label, $gateCauseRow.Cause) `
    ("$($script:weeklyCallError)|$($script:weeklyCallResult)|$($script:focusCalls)|$($script:gamePointClicks)|$($script:screenPointClicks)|$($script:blindClicks)|$($script:screenCaptureFailing)|$($script:captureFailCause)|$((Elapsed))|$($script:safeStopCalls)|$($script:probeCalls)|$(Count-Log ('^\[안내\] \[심층\] 주간 협동 미션 팝업 감지 - ' + [regex]::Escape($GATE_NOTICE_KEY)))|$(Count-Log '주간 협동 미션 팝업 감지 - 닫기 클릭$')") `
    ("|True|0|0|0|0|True|$($gateCauseRow.Cause)|0|0|0|1|0")
}
# GT5 - 정상 경로(두 번째 판독 캡처 성공 · '닫기' 못 찾음 - 등록 0): 지금과 같음
Reset-WeeklyGateCase -SecondRead 'miss'
Invoke-WeeklyHelperOnce -LogPrefix '[심층] '
# 예외 | 반환 | 포커스 | 예비 좌표 클릭 | 화면 좌표 클릭 | 닫기 로그 | 경과 | 플래그 | 게이트 안내
Check-Equal "GT5 주간 정상 경로 - 두 번째 판독 성공 · '닫기' 못 찾음 → 포커스 1 · 예비 좌표 클릭 1 · 닫기 로그 1 · 2초 (지금과 같음)" `
  ("$($script:weeklyCallError)|$($script:weeklyCallResult)|$($script:focusCalls)|$($script:gamePointClicks)|$($script:screenPointClicks)|$(Count-Log '주간 협동 미션 팝업 감지 - 닫기 클릭$')|$((Elapsed))|$($script:screenCaptureFailing)|$(Count-Log ([regex]::Escape($GATE_NOTICE_KEY)))") `
  '|True|1|1|0|1|2|False|0'
# GT6 · GT7 - 게이트는 클릭 메타를 쓰지 않습니다(값을 쓰는 것은 Click-ScreenPoint 뿐). 옛 메타 양쪽 상태를 둡니다 - 한쪽만 보면 그 옛 값과 같은 값을 쓰는 꼴이 남음
Reset-WeeklyGateCase -SecondRead $CAUSE_OTHER
$script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 옛 메타 - 미전송(사용자 조작 취소)
Invoke-WeeklyHelperOnce -LogPrefix '[생활] '
# 반환 | Performed | SkipReason | 양보 호출
Check-Equal 'GT6 주간 게이트 - 옛 메타 미전송(False/user-active) 그대로 · 양보 호출 0' ("$($script:weeklyCallResult)|$($script:lastClickPerformed)|$($script:lastClickSkipReason)|$($script:yieldCalls)") 'True|False|user-active|0'
Reset-WeeklyGateCase -SecondRead $CAUSE_OTHER
$script:lastClickPerformed = $true; $script:lastClickSkipReason = ''   # 옛 메타 - 전송(운용에서 가장 흔한 값)
Invoke-WeeklyHelperOnce -LogPrefix '[생활] '
Check-Equal "GT7 주간 게이트 - 옛 메타 전송(True/'') 그대로 · 양보 호출 0" ("$($script:weeklyCallResult)|$($script:lastClickPerformed)|$($script:lastClickSkipReason)|$($script:yieldCalls)") 'True|True||0'

# 6-3. GS1~GS4 - 공용 스윕 원문 → 원문 분류 'freeze' (원인 넷은 GT1~GT4 와 같음 · 스윕 앞 사유 비움 · 일련번호 기록 - 어비스 분류 루프의 회전 꼴)
foreach ($gateCauseRow in $gateCauseRows) {
  Reset-WeeklyGateCase -SecondRead $gateCauseRow.Cause -RestoreSucceeds $gateCauseRow.Restore
  $script:lastClickSkipReason = ''
  $serialBeforeSweep = $script:captureFailSerial
  $sweepCallError = ''; $sweepCallResult = $null
  try { $sweepCallResult = Invoke-PurchasePopupSweep -Game $game } catch { $sweepCallError = $_.Exception.Message }
  $sweepVerdict = Resolve-AbyssMemberSweepTurn -CaptureFailingNow $script:screenCaptureFailing -CaptureFailedInTurn ($script:captureFailSerial -ne $serialBeforeSweep) `
    -Performed $script:lastClickPerformed -SkipReason $script:lastClickSkipReason -Streak 0 -Limit 3
  # 예외 | 스윕 반환 | 포커스 | 클릭(예비 좌표 + 화면 좌표) | 분류
  Check-Equal ('GS{0} 공용 스윕 - 주간 두 번째 판독 캡처 실패 {1}({2}) → 스윕 참 · 포커스·클릭 0 · 원문 분류 freeze' -f $gateCauseRow.Id, $gateCauseRow.Label, $gateCauseRow.Cause) `
    ("$sweepCallError|$sweepCallResult|$($script:focusCalls)|$($script:gamePointClicks + $script:screenPointClicks)|$($sweepVerdict.Action)") '|True|0|0|freeze'
}

# 6-4. GS5~GS10 - 시작 스윕 for(1..2) 3곳(섹션 3 의 $sweepLoops - 원문 루프를 [scriptblock]::Create 로 만들어 & 로 실행: 자식 범위라 루프 안 대입이
#      이 파일 변수로 새지 않음). 네트워크 helper 는 섹션 3 모의($false) 그대로 - 닫은 뒤 둘째 시도의 스윕이 그 자리까지 내려갑니다(아래 GN1 순서 계약)
# GS5~GS7 - 하단 주간 문구 · 두 번째 판독 '그 밖' 1회 · 복구는 탐침 2회째(복구까지 기다리는지 - 한 회전만 동결하면 서두 가드로 끊김):
#   동결(공통 진입점 2 · 탐침 2 · 4초) → 복구 → 같은 시도로 다시 스윕 → 정상 경로로 닫음(포커스 1 · 화면 좌표 클릭 1 · 2초) → 1.2초 → 둘째 시도 스윕 거짓 → break
$weeklyRowId = 5
foreach ($weeklyLoopAst in $sweepLoops) {
  $weeklyLoopBlock = [scriptblock]::Create($weeklyLoopAst.Extent.Text)
  Reset-WeeklyGateCase -SecondRead $CAUSE_OTHER -RecoverAtProbe 2
  $loopCallError = ''
  try { & $weeklyLoopBlock } catch { $loopCallError = $_.Exception.Message }
  # 예외 | 포커스 | 클릭(예비 좌표 + 화면 좌표) | 눈감은 클릭 | 주간 팝업 열림 | 공통 진입점 | 탐침 | 경과 | 게이트 안내(접두 없음) | 닫기 로그
  Check-Equal ('GS{0} 시작 스윕 {1}: 게이트 회전(그 밖) → 복구까지 동결(탐침 2회째) → 같은 시도로 다시 스윕해 닫음 · 눈감은 클릭 0' -f $weeklyRowId, $weeklyLoopAst.Extent.StartLineNumber) `
    ("$loopCallError|$($script:focusCalls)|$($script:gamePointClicks + $script:screenPointClicks)|$($script:blindClicks)|$($script:weeklyOpen)|$($script:safeStopCalls)|$($script:probeCalls)|$((Elapsed))|$(Count-Log ('^\[안내\] 주간 협동 미션 팝업 감지 - ' + [regex]::Escape($GATE_NOTICE_KEY)))|$(Count-Log '주간 협동 미션 팝업 감지 - 닫기 클릭$')") `
    '|1|1|0|False|2|2|7.2|1|1'
  $weeklyRowId++
}
# GS8~GS10 - 시도 미소모: 구매 팝업과 주간 팝업이 함께 열린 채 시작(스윕 순서상 구매가 먼저 - 08-01 겹침 꼴) · 두 번째 판독 '그 밖' 1회 · 복구는 탐침 1회째.
#   첫 시도가 구매를 닫고(1초 + 1.2초) 둘째 시도가 게이트 회전 → 동결(공통 진입점 1 · 탐침 1 · 2초) → 그 시도를 되돌려 둘째 시도를 다시 돌아 주간을 닫음
#   (2초 + 1.2초). 시도를 소모하면 두 시도가 끝나 주간 팝업이 남습니다(클릭 1 · 4.2초)
foreach ($weeklyLoopAst in $sweepLoops) {
  $weeklyLoopBlock = [scriptblock]::Create($weeklyLoopAst.Extent.Text)
  Reset-WeeklyGateCase -SecondRead $CAUSE_OTHER -RecoverAtProbe 1 -Purchase $true
  $loopCallError = ''
  try { & $weeklyLoopBlock } catch { $loopCallError = $_.Exception.Message }
  # 예외 | 전송 클릭 | 구매 팝업 열림 | 주간 팝업 열림 | 눈감은 클릭 | 공통 진입점 | 탐침 | 경과
  Check-Equal ('GS{0} 시작 스윕 {1}: 구매 팝업 뒤 둘째 시도의 게이트 회전 → 시도 미소모로 주간까지 닫음' -f $weeklyRowId, $weeklyLoopAst.Extent.StartLineNumber) `
    ("$loopCallError|$($script:clicksSent)|$($script:purchaseOpen)|$($script:weeklyOpen)|$($script:blindClicks)|$($script:safeStopCalls)|$($script:probeCalls)|$((Elapsed))") `
    '|2|False|False|0|1|1|7.4'
  $weeklyRowId++
}

# 6-5. GN1 - 네트워크 불안정 팝업은 그대로(사전 포커스 1 · 클릭 0). 순서 계약(구현 명세 ④′ 2.2): 원문 적재와 이 행 전용 모의는 GS10 뒤 · 이 행 바로 앞에
#      둡니다 - 앞에 두면 GS5~GS7 의 마지막 스윕(주간을 닫은 뒤 둘째 시도)이 원문 네트워크 helper 의 제목 참 → 짝 판독 실패 → 사전 포커스까지 가서
#      올바른 구현에서도 GS5~GS7 이 포커스 2 로 FAIL 합니다
foreach ($networkFunctionName in @('Close-NetworkUnstablePopup', 'Select-NetworkRetryWord')) {
  Invoke-Expression ([string]$workerFunctionNodes[$networkFunctionName].Extent.Text)
}
function Get-GameRegionOcrText {
  # 네트워크 제목 영역(420,355) - 캡처가 살아 있을 때만 제목, 실패 중이면 ''(스위치 판독 꼴). 그 밖 영역은 ''
  param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine)
  if (($ReferenceX -eq 420) -and -not $script:screenCaptureFailing) { return '네트워크연결이불안정합니다' }
  return ''
}
function Get-GameRegionOcrWords {
  # 짝 판독(스위치 없음) - 캡처 실패 등록(그 밖) 뒤 빈 목록 (원문 실패 갈래 꼴). 이 파일과 공용 헬퍼에 정의가 없어 여기서 정의합니다
  param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine)
  Register-MockCaptureFailure -Cause $CAUSE_OTHER
  return @()
}
Reset-WeeklyGateCase -Weekly $false
$networkCallError = ''; $networkCallResult = $null
try { $networkCallResult = Close-NetworkUnstablePopup -Game $game } catch { $networkCallError = $_.Exception.Message }
# 예외 | 반환 | 사전 포커스 | 클릭(예비 좌표 + 화면 좌표) | 플래그
Check-Equal 'GN1 네트워크 그대로 - 짝 판독 캡처 실패 → 사전 포커스 1 · 재판독이 막아 클릭 0 · 거짓 · 플래그 참' `
  ("$networkCallError|$networkCallResult|$($script:focusCalls)|$($script:gamePointClicks + $script:screenPointClicks)|$($script:screenCaptureFailing)") '|False|1|0|True'

# ── 7. 시작부 팝업 정리의 캡처 실패 회전 (구현 단위 C8 - 2026-10-19) ─────────────────────────────
# 섹션 3 의 원문 루프 셋($sweepLoops)을 그대로 돌립니다. 스윕 안에 캡처 실패가 있던 회전(진입 때 이미 실패 · 첫 판독/구매 탐색/하단 판독에서 시작 ·
# 같은 스윕 안 복구)을 주입하고, 기대는 '끊지 않고 블록이 복구까지 동결 → 같은 시도로 다시 스윕(시도 미소모)' / 평상시 그대로입니다.
# SF12 는 그 회전에 사용자 조작 취소가 겹친 꼴입니다(같은 스윕 안 복구 뒤 위임 함수 - 섹션 1 보상 화면 모형처럼 기다리지 않고 참). 기대는 '조작이
# 끝날 때까지 기다린 뒤 시도를 한 번 되돌려 새로 스윕' - 실패 쪽 되돌림이 먼저 넘기면 다음 회전 서두가 클릭 메타를 비워, 다음 스윕이 거짓일 때
# 양보 없이 시작 판정으로 내려갑니다(규칙 4). 이 행만 끝에 두 열(양보 호출 수 · 루프 끝 남은 조작 ms)을 더 봅니다.
# SF13 은 SF12 와 같은 꼴에서 위임 함수의 클릭이 전송된 회전입니다(조작 0 · 스윕 참 · 놓친 구매 팝업은 다시 스윕이 닫음). 기대는 '스윕이 참이어도 그 안에
# 실패가 있었으면 시도를 쓰지 않고 1.2초 없이 같은 시도로 다시 스윕'(구현 명세 C8 1.1 '스윕 참 회전') - SF12 는 그 회전을 양보 분기가 먼저 받으므로, 미룸 표지의 일련번호 몫을 스윕 참 회전에서 보는 행은 이것뿐입니다.
# 7-1. 모의 재정의(이 뒤 호출에만 적용) - 앞 GN1 의 원문 네트워크 helper·단어 판독 모의가 닿지 않게 끊습니다(순서 계약)
function Close-NetworkUnstablePopup { param($Game) $false }
function Get-GameRegionOcrWords { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine) return @() }
Invoke-Expression ([string]$workerFunctionNodes['Close-CoopMissionScreen'].Extent.Text)   # 원문 - 서두 가드 없는 판독이 스윕 안 복구 지점
function Close-QuestRewardScreen {
  # 위임 함수 모형 - 섹션 1 과 같은 꼴(기다리지 않고, 취소돼도 1초 뒤 참) + 원문 서두 가드 + 취소 뒤 '조작 중 사용자가 직접 닫음'(SF12 - 다음 스윕 거짓)
  param($Game, $BottomText)
  if ($script:screenCaptureFailing) { return $false }
  if (-not $script:rewardOpen) { return $false }
  if ($script:rewardCancelLeft -gt 0) {
    $script:rewardCancelLeft--; $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'
    if ($script:rewardClosedByUser) { $script:rewardOpen = $false }
  } else { $script:lastClickPerformed = $true; $script:lastClickSkipReason = ''; $script:clicksSent++; $script:rewardOpen = $false }
  $script:vclock = $script:vclock.AddMilliseconds(1000)
  return $true
}
$WEEKLY_BOTTOM_TEXT = '〔㉬닫기Space협동미션참여하기'   # 08-17 보관 캡처 판독문 - 하단 판독과 주간 helper 첫 판독은 같은 영역·배율
function Get-GameRegionOcrText {
  param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine)
  if ($ReferenceX -eq 360) {
    # 협동 완료 부제 - 주간 팝업 위라 '' · 지정하면 이 판독이 캡처를 되살림(원문 Register-CaptureSuccess 꼴)
    $script:coopReads++
    if ($script:screenCaptureFailing -and $script:recoverOnCoopRead) { $script:screenCaptureFailing = $false; $script:captureFailCause = $null }
    return ''
  }
  if (($ReferenceX -eq $rgClearExit[0]) -and $script:weeklyOpen -and -not $script:screenCaptureFailing) { return $WEEKLY_BOTTOM_TEXT }
  return ''
}
function Test-GameRestartPopup {
  # 스윕 첫 판독 - 지정 회차면 실패 등록 뒤 거짓(스위치 판독의 그 밖 원인 꼴) · 50회 초과는 '끝나지 않는 루프' 표지(러너 멈춤 방지)
  param($Game)
  $script:restartReads++
  if ($script:restartReads -gt 50) { throw '섹션 7 모의: 스윕 50회 초과 - 루프가 끝나지 않습니다' }
  if ($script:restartFailCalls -contains $script:restartReads) { Register-MockCaptureFailure -Cause $script:injectCause }
  return $false
}
function Find-GameTextPoint {
  param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText, $ExactText)
  if ($ReferenceX -eq $rgPopupClose[0]) {
    $script:purchaseReads++
    if ($script:purchaseFailCalls -contains $script:purchaseReads) { Register-MockCaptureFailure -Cause $script:injectCause; return $null }
    if ($script:purchaseOpen -and -not $script:screenCaptureFailing) { return [pscustomobject]@{ X = 640; Y = 500 } }
    return $null
  }
  if (($ReferenceX -eq $rgClearExit[0]) -and $script:weeklyOpen -and -not $script:screenCaptureFailing) { return [pscustomobject]@{ X = 495; Y = 654 } }
  return $null
}
function Get-GameOcrText {
  # 하단 판독(스위치 판독) - 지정 회차면 실패 등록 뒤 '' · 지정하면 이 판독이 캡처를 되살림(같은 스윕 안 복구)
  param($Game)
  $script:bottomReads++
  if ($script:bottomFailCalls -contains $script:bottomReads) { Register-MockCaptureFailure -Cause $script:injectCause; return '' }
  if ($script:recoverOnBottomRead -and $script:screenCaptureFailing) { $script:screenCaptureFailing = $false; $script:captureFailCause = $null }
  if ($script:weeklyOpen -and -not $script:screenCaptureFailing) { return $WEEKLY_BOTTOM_TEXT }
  return ''
}
function Test-SafeStopDuringCaptureFail {
  $script:safeStopCalls++
  if (($script:exitAtSafeStop -gt 0) -and ($script:safeStopCalls -ge $script:exitAtSafeStop)) { throw 'EXIT4-모의: 게임 프로세스 종료(공통 진입점 코드 4)' }
  if ($script:safeStopCalls -gt 30) { throw '섹션 7 모의: 공통 진입점 30회 초과 - 동결이 복구를 보지 못합니다(자기 잠금)' }
}
function Test-CaptureRecovered {
  # 복구 탐침 - 정한 회차부터 복구 · 실패 탐침은 일련번호 +1(원문은 실패 캡처마다 등록) · 30회 초과 표지(공통 진입점을 빠뜨린 변이도 멈추지 않게)
  param($Game)
  $script:probeCalls++
  if ($script:probeCalls -gt 30) { throw '섹션 7 모의: 복구 탐침 30회 초과 - 동결이 끝나지 않습니다' }
  if ($script:screenCaptureFailing -and ($script:recoverAtProbe -gt 0) -and ($script:probeCalls -ge $script:recoverAtProbe)) {
    $script:screenCaptureFailing = $false; $script:captureFailCause = $null
  } elseif ($script:screenCaptureFailing) { $script:captureFailSerial++ }
  return (-not $script:screenCaptureFailing)
}
function Reset-StartFreezeCase {
  param([bool]$FailingAtEntry = $false, [string]$Cause = '', [int[]]$RestartFailCalls = @(), [int[]]$PurchaseFailCalls = @(), [int[]]$BottomFailCalls = @(),
    [int]$RecoverAtProbe = 0, [bool]$Purchase = $false, [bool]$Weekly = $false, [int]$ExitAtSafeStop = 0, [bool]$RecoverOnBottomRead = $false, [bool]$RecoverOnCoopRead = $false,
    [bool]$Reward = $false, [int]$RewardCancel = 0, [bool]$RewardClosedByUser = $false, [int]$UserBusyMs = 0)
  Reset-WeeklyGateCase -Purchase $Purchase -Weekly $Weekly -RecoverAtProbe $RecoverAtProbe
  $script:recoverOnBottomRead = $RecoverOnBottomRead; $script:recoverOnCoopRead = $RecoverOnCoopRead
  $script:injectCause = $(if ($Cause) { $Cause } else { $CAUSE_OTHER })
  $script:restartFailCalls = @($RestartFailCalls); $script:purchaseFailCalls = @($PurchaseFailCalls); $script:bottomFailCalls = @($BottomFailCalls)
  $script:restartReads = 0; $script:purchaseReads = 0; $script:bottomReads = 0; $script:coopReads = 0
  $script:exitAtSafeStop = $ExitAtSafeStop
  # 보상 화면(위임 함수 모형) · 사용자 조작 - Reset-WeeklyGateCase 가 비운 값(보상 닫힘 · 취소 0 · 조작 0) 위에 이 행 값을 둡니다
  $script:rewardOpen = $Reward; $script:rewardCancelLeft = $RewardCancel; $script:rewardClosedByUser = $RewardClosedByUser; $script:userBusyMs = $UserBusyMs
  if ($FailingAtEntry) { Register-MockCaptureFailure -Cause $script:injectCause }
}
function Get-StartFreezeShown {
  param([string]$CallError)
  # 예외 | 끝 플래그 | 공통 진입점 | 탐침 | 경과(불변 문화권 - -f 는 현재 문화권을 따라 소수점이 바뀜) | 전송 클릭 | 눈감은 클릭 | 구매 열림 | 주간 열림 | 첫 판독 수
  return ("{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}" -f $CallError, $script:screenCaptureFailing, $script:safeStopCalls, $script:probeCalls, (Elapsed).ToString([Globalization.CultureInfo]::InvariantCulture),
    $script:clicksSent, $script:blindClicks, $script:purchaseOpen, $script:weeklyOpen, $script:restartReads)
}
$sfRows = @(
  @{ Id = 1; Label = '진입 때 이미 실패(그 밖) · 팝업 없음 · 탐침 2회째 복구'; Args = @{ FailingAtEntry = $true; RecoverAtProbe = 2 }; Expect = '|False|2|2|4|0|0|False|False|1' },
  @{ Id = 2; Label = '진입 때 이미 실패(그 밖) · 주간 팝업 · 탐침 2회째 복구'; Args = @{ FailingAtEntry = $true; RecoverAtProbe = 2; Weekly = $true }; Expect = '|False|2|2|7.2|1|0|False|False|2' },
  @{ Id = 3; Label = '진입 때 이미 실패(최소화) · 구매 팝업 · 탐침 1회째 복구'; Args = @{ FailingAtEntry = $true; Cause = 'MIN'; RecoverAtProbe = 1; Purchase = $true }; Expect = '|False|1|1|4.2|1|0|False|False|2' },
  @{ Id = 4; Label = '첫 판독에서 실패 시작(그 밖) · 팝업 없음 · 탐침 2회째 복구'; Args = @{ RestartFailCalls = @(1); RecoverAtProbe = 2 }; Expect = '|False|2|2|4|0|0|False|False|2' },
  @{ Id = 5; Label = '구매 닫기 탐색에서 실패 시작(그 밖) · 구매 팝업 · 탐침 1회째 복구'; Args = @{ PurchaseFailCalls = @(1); RecoverAtProbe = 1; Purchase = $true }; Expect = '|False|1|1|4.2|1|0|False|False|3' },
  @{ Id = 6; Label = '둘째 시도 첫 판독에서 실패 시작 · 구매+주간 팝업 · 탐침 1회째 복구'; Args = @{ RestartFailCalls = @(2); RecoverAtProbe = 1; Purchase = $true; Weekly = $true }; Expect = '|False|1|1|7.4|2|0|False|False|3' },
  @{ Id = 7; Label = '진입 때 이미 실패(창 좌표) · 복구 없음 · 공통 진입점 3회째 게임 종료'; Args = @{ FailingAtEntry = $true; Cause = 'WG'; ExitAtSafeStop = 3 }; Expect = 'EXIT4-모의: 게임 프로세스 종료(공통 진입점 코드 4)|True|3|2|4|0|0|False|False|0' },
  @{ Id = 8; Label = '교대 - 첫 판독 실패 다섯 번 · 매번 탐침 1회째 복구'; Args = @{ RestartFailCalls = @(1, 2, 3, 4, 5); RecoverAtProbe = 1 }; Expect = '|False|5|5|10|0|0|False|False|6' },
  @{ Id = 9; Label = '평상시 - 실패 없음 · 팝업 없음'; Args = @{}; Expect = '|False|0|0|0|0|0|False|False|1' },
  @{ Id = 10; Label = '구매 탐색 실패 → 같은 스윕 하단 판독이 복구 · 구매 팝업'; Args = @{ PurchaseFailCalls = @(1); Purchase = $true; RecoverOnBottomRead = $true }; Expect = '|False|0|0|2.2|1|0|False|False|3' },
  @{ Id = 11; Label = '하단 판독 실패 → 같은 스윕 협동 완료 helper 판독이 복구 · 주간 팝업'; Args = @{ BottomFailCalls = @(1); Weekly = $true; RecoverOnCoopRead = $true }; Expect = '|False|0|0|3.2|1|0|False|False|3' },
  @{ Id = 12; Label = '구매 탐색 실패 → 같은 스윕 하단 판독이 복구 → 보상 화면 확인이 사용자 조작으로 취소(위임 - 기다리지 않음) · 조작 중 사용자가 닫음 · 조작 3초'; Args = @{ PurchaseFailCalls = @(1); RecoverOnBottomRead = $true; Reward = $true; RewardCancel = 1; RewardClosedByUser = $true; UserBusyMs = 3000 }; Expect = '|False|0|0|4|0|0|False|False|2|1|0'; YieldColumns = $true },
  @{ Id = 13; Label = '구매 탐색 실패 → 같은 스윕 하단 판독이 복구 → 보상 화면 확인 전송(스윕 참) · 구매 팝업'; Args = @{ PurchaseFailCalls = @(1); RecoverOnBottomRead = $true; Reward = $true; Purchase = $true }; Expect = '|False|0|0|3.2|2|0|False|False|3' }
)
foreach ($sfLoopAst in $sweepLoops) {
  $sfLoopBlock = [scriptblock]::Create($sfLoopAst.Extent.Text)
  foreach ($sfRow in $sfRows) {
    $sfArgs = @{} + $sfRow.Args
    if ($sfArgs.Cause -eq 'MIN') { $sfArgs.Cause = $CAUSE_MINIMIZED } elseif ($sfArgs.Cause -eq 'WG') { $sfArgs.Cause = $CAUSE_WINDOW_GONE }
    Reset-StartFreezeCase @sfArgs
    $sfError = ''
    try { & $sfLoopBlock } catch { $sfError = $_.Exception.Message }
    $sfShown = Get-StartFreezeShown -CallError $sfError
    # SF12 만: + 양보 호출 수 | 루프 끝 남은 조작(ms) - 시작 판정 전에 조작이 끝났는지
    if ($sfRow.YieldColumns) { $sfShown += ('|{0}|{1}' -f $script:yieldCalls, $script:userBusyMs) }
    Check-Equal ('SF{0} 시작 스윕 {1}: {2}' -f $sfRow.Id, $sfLoopAst.Extent.StartLineNumber, $sfRow.Label) $sfShown $sfRow.Expect
  }
}

exit $fails
