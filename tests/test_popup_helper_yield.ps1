# 팝업 치우는 공용 함수 2개(구매 스윕·주간 리셋)의 사용자 조작 양보 계약 + 호출부 예산 (2026-09-13)
#
# 함수 안에서 user-active 취소를 '커서 확인 실패'로 적고 1~2초를 이미 쓴 뒤 돌아왔습니다. 호출부
# 대부분은 continue/return $false 로 재판독하니 실피해는 대기 낭비였지만, 시작 스윕 for(1..2) 3곳과
# 생활 메뉴 회전은 취소된 회전이 시도를 그대로 먹었습니다. 여기서 고정하는 계약(설계 합의):
#   함수: 전송 → 로그+대기 / user-active → 사유 로그 + Wait-UserYieldEnd + 즉시 $true (대기 생략) /
#         cursor-not-ready → 사유 로그 + 기존 대기. 반환값 의미('팝업을 감지해 이번 흐름을 처리')는 불변.
#   시작 스윕: user-active 면 $startSweep-- 후 continue (외부 1.2초 대기도 건너뜀)
#   생활 메뉴: 각 호출 직후 메타 확인, user-active 면 $menuTry-- 후 continue
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-PurchasePopupSweep', 'Close-WeeklyCoopResetPopup')) {
  Invoke-Expression $definition
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

exit $fails
