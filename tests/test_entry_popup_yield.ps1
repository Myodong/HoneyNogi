# 입장 직후 팝업 정리(Invoke-AfterEntryKeys)와 클리어 대기의 구매 팝업 분기 - 사용자 조작 양보 계약 (2026-09-13)
#
# 09-13 실기가 새로 잡은 자리(09-09 감사 목록에 없었음). 회복 물약 팝업은 던전 안에 들어간 뒤 뜨므로 공용
# 스윕이 아니라 이 두 자리가 실제로 만납니다. 둘 다 전송은 세지만 user-active 를 구분하지 않았습니다.
# 고정하는 계약(설계 합의):
#   자리 1: 전송 → 클릭 +1 / user-active → 사유 로그 + Wait-UserYieldEnd + $popupTry-- (시도 미소모, 같은 번호 재탐색)
#           / cursor-not-ready → 시도 소모. 4회째는 클릭 없이 잔존 판정(클릭보다 앞이라 되돌림은 1~3회에서만).
#   자리 2: 사유 3갈래 로그만. user-active 도 **기다리지 않고** 1초 뒤 다음 감지 (600초 감시형 - 컷신 처리와 같은 방식).
#           여신상 전환 판정(가루 부활 직후)은 사유와 무관하게 성립.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-AfterEntryKeys')) {
  Invoke-Expression $definition
}

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
$game = $null

# ── 모의 ─────────────────────────────────────────────────────────────────────
$script:vclock = [datetime]'2026-01-01 00:00:00'
function Get-Date { return $script:vclock }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) $ms = $Milliseconds; if ($Seconds) { $ms = $Seconds * 1000 }; $script:vclock = $script:vclock.AddMilliseconds($ms) }
function Focus-Game { param($Game) }
function Move-CursorOutsideGame { param($Game) }   # 창 밖 조작 모형 - 대피 게이트가 안 도는 상황
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Press-KeyVerified { param($Game, $VirtualKey, $Label) $script:keysSent += $Label; $true }
function Get-KeyDisplayName { param($Key) "K$Key" }
$rgPopupClose = @(1,1,1,1)
$afterEntryActions = @(@{ Key = 32; Label = '자동출발' })
$afterEntryDelayMs = 100
# 팝업 상태: 남은 연쇄 개수. 전송된 클릭이 하나를 닫음.
$script:popupChain = 0
function Find-GameTextPoint { param($Game,$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight,$SearchText) if ($script:popupChain -gt 0) { [pscustomobject]@{ X = 640; Y = 500 } } else { $null } }
$script:sendSeq = @(); $script:sendIdx = 0
function Click-ScreenPoint {
  param($X, $Y)
  $r = 'sent'
  if ($script:sendIdx -lt $script:sendSeq.Count) { $r = $script:sendSeq[$script:sendIdx]; $script:sendIdx++ }
  $script:lastClickPerformed = ($r -eq 'sent')
  $script:lastClickSkipReason = if ($r -eq 'sent') { '' } else { $r }
  if ($r -eq 'sent') { $script:clicksSent++; $script:popupChain-- }
}
$script:userBusyMs = 0
function Wait-UserYieldEnd {
  param($Game, $Context)
  $script:yieldCalls++; $script:yieldContexts += $Context
  if ($script:userBusyMs -le 0) { return }
  $script:vclock = $script:vclock.AddMilliseconds($script:userBusyMs); $script:userYieldTotalMs += $script:userBusyMs; $script:userBusyMs = 0
  if ($script:popupGoneDuringYield) { $script:popupChain = 0 }   # 양보 중 사용자가 닫음
}
function Reset-Case {
  param([int]$Chain = 1, $SendSeq = @(), [int]$BusyMs = 3000, [bool]$GoneDuringYield = $false)
  $script:vclock = [datetime]'2026-01-01 00:00:00'
  $script:popupChain = $Chain; $script:popupGoneDuringYield = $GoneDuringYield
  $script:logs = @(); $script:keysSent = @(); $script:clicksSent = 0; $script:yieldCalls = 0; $script:yieldContexts = @()
  $script:userBusyMs = $BusyMs; $script:userYieldTotalMs = [double]0
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타
  $script:screenCaptureFailing = $false
  $script:sendIdx = 0; $script:sendSeq = @($SendSeq)
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }

# ── 1. 자리 1 기준 동작 ────────────────────────────────────────────────────────
Reset-Case -Chain 0
Invoke-AfterEntryKeys -Game $game -LogPrefix '[심층]'
Check-Equal '팝업 없음: 클릭 0, 키 입력 진행, 잔존 메타 오발동 없음' ("$($script:clicksSent)/$($script:keysSent.Count)/$($script:yieldCalls)") '0/1/0'

Reset-Case -Chain 1
Invoke-AfterEntryKeys -Game $game -LogPrefix '[심층]'
Check-Equal '팝업 1개: 1클릭으로 닫고 키 입력' ("$($script:clicksSent)/$((Count-Log '닫은 뒤 키 입력 진행'))/$($script:keysSent.Count)") '1/1/1'

# ── 2. ★ user-active 취소는 시도를 쓰지 않는다 ─────────────────────────────────
#    취소 3회 뒤 전송. 예전엔 취소가 4회 시도를 소모해 '한 번도 보내지 못했습니다(커서 확인)' 경고 + 키 입력.
Reset-Case -Chain 1 -SendSeq @('user-active','user-active','user-active','sent')
Invoke-AfterEntryKeys -Game $game -LogPrefix '[심층]'
Check-Equal '취소 3회: 그래도 닫힘 (시도 미소모)' ("$($script:clicksSent)/$($script:popupChain)") '1/0'
Check-Equal '취소 3회: 사유 로그 3 + 양보 호출 3' ("$((Count-Log '사용자 조작으로 닫기 클릭을 취소'))/$($script:yieldCalls)") '3/3'
Check-Equal '취소 3회: 옛 커서 실패 경고 없음' ((Count-Log '보내지 못했습니다') + (Count-Log '커서 확인')) 0
Check-Equal '취소 3회: 정상 닫힘 로그 후 키 입력' ("$((Count-Log '닫은 뒤 키 입력 진행'))/$($script:keysSent.Count)") '1/1'

#    양보 중 사용자가 팝업을 닫음 → 재탐색에서 없음 → 이미 봤으므로 연쇄 재확인(1.2초) 한 번 뒤 종료, 클릭 0
Reset-Case -Chain 1 -SendSeq @('user-active') -GoneDuringYield $true
Invoke-AfterEntryKeys -Game $game -LogPrefix '[심층]'
Check-Equal '양보 중 소멸: 재클릭 0, 연쇄 재확인 뒤 종료' ("$($script:clicksSent)/$($script:yieldCalls)") '0/1'
Check-Equal '양보 중 소멸: 잔존 경고 없음 (봤지만 닫힘)' (Count-Log '남아 있습니다') 0

# ── 3. cursor-not-ready 는 기존대로 시도를 쓴다 (3회 → 잔존 경고 + 키 입력 진행) ──
Reset-Case -Chain 1 -SendSeq @('cursor-not-ready','cursor-not-ready','cursor-not-ready','sent')
Invoke-AfterEntryKeys -Game $game -LogPrefix '[심층]'
Check-Equal '커서 실패 3회: 클릭 0 + 양보 없음 (시도 소모)' ("$($script:clicksSent)/$($script:yieldCalls)") '0/0'
Check-Equal '커서 실패 3회: 0회 잔존 경고(커서 확인) + 키 입력 진행' ("$((Count-Log '한 번도 보내지 못했습니다\(커서 확인\)'))/$($script:keysSent.Count)") '1/1'

# ── 4. 연쇄 팝업 + 취소 섞임: 2개 연쇄, 첫 클릭 취소 → 전송 → 전송 ─────────────
Reset-Case -Chain 2 -SendSeq @('user-active','sent','sent')
Invoke-AfterEntryKeys -Game $game -LogPrefix '[심층]'
Check-Equal '연쇄 2 + 취소 1: 전송 2회로 모두 닫힘' ("$($script:clicksSent)/$($script:popupChain)") '2/0'

# ── 5. 자리 2: 클리어 대기의 팝업 블록을 AST 로 잘라 **1회 루프 안에서 실행** ──────────────
# 구현 리뷰 지적: 문구 존재·IndexOf 비교만으로는 여신상 대입 삭제·분기 조건 변경·% 2 게이트 제거를 못 잡았다
# (IndexOf 가 -1 이어도 '< 양수' 로 통과). 실제 `if ($popupClosePoint) { … continue }` 블록을 잘라 1회 루프에
# 넣어 돌리면 로그 분류·상태 변수 두 개·1초 대기·양보 미호출·continue 까지 실행으로 확인된다.
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$tokens, [ref]$parseErrors)
$popupIf = $ast.Find({
    param($n)
    $n -is [System.Management.Automation.Language.IfStatementAst] -and
    $n.Clauses[0].Item1.Extent.Text -eq '$popupClosePoint' -and
    $n.Extent.Text -match '구매 팝업 감지 - 닫기 클릭"'
  }, $true)
Check-Equal '클리어 대기: 팝업 if 블록 추출' ($null -ne $popupIf) $true
# 1회 루프로 감싸 continue 를 소비합니다 - 블록 뒤에 도달하면 $reachedAfter 가 참 (continue 가 없으면 실패)
$popupLoop = [scriptblock]::Create("for (`$__once = 0; `$__once -lt 1; `$__once++) {`n" + $popupIf.Extent.Text + "`n`$script:reachedAfter = `$true`n}")
$script:contentTag = '[심층]'
function Run-PopupBlock {
  param([bool]$Pending, [string]$Kind, [string]$Click)
  $script:vclock = [datetime]'2026-01-01 00:00:00'
  $script:logs = @(); $script:yieldCalls = 0; $script:clicksSent = 0; $script:reachedAfter = $false
  $script:userBusyMs = 3000
  $script:sendIdx = 0; $script:sendSeq = @($Click)
  $script:popupChain = 1
  $popupClosePoint = [pscustomobject]@{ X = 640; Y = 500 }
  $reviveConfirmPending = $Pending; $revivePendingKind = $Kind; $useStatueRevive = $false
  $Game = $null
  # 점소싱(.) 으로 실행 - & 로 부르면 새 스코프라 블록 안의 $useStatueRevive/$reviveConfirmPending 대입이
  # 이 함수의 지역 변수에 닿지 않는다 (PS 5.1: 읽기는 부모로 올라가지만 쓰기는 새 변수를 만듦)
  . $popupLoop
  return [pscustomobject]@{
    Statue = $useStatueRevive; Pending = $reviveConfirmPending; Sleep = (($script:vclock - [datetime]'2026-01-01 00:00:00').TotalSeconds)
    Yield = $script:yieldCalls; After = $script:reachedAfter; Logs = $script:logs
  }
}
# 일반 상태 × 클릭 3종
$r = Run-PopupBlock -Pending $false -Kind '' -Click 'sent'
Check-Equal '클리어 일반/전송: 닫기 로그 + 1초 + continue + 양보 없음' ("$((@($r.Logs | Where-Object { $_ -match '구매 팝업 감지 - 닫기 클릭$' })).Count)/$($r.Sleep)/$($r.After)/$($r.Yield)") '1/1/False/0'
$r = Run-PopupBlock -Pending $false -Kind '' -Click 'user-active'
Check-Equal '클리어 일반/user-active: 사유 로그 + 기다리지 않음(1초만) + continue' ("$((@($r.Logs | Where-Object { $_ -match '사용자 조작으로 닫기 클릭을 취소' })).Count)/$($r.Yield)/$($r.Sleep)/$($r.After)") '1/0/1/False'
Check-Equal '클리어 일반/user-active: 커서 실패 문구 아님' (@($r.Logs | Where-Object { $_ -match '커서 확인 실패' }).Count) 0
$r = Run-PopupBlock -Pending $false -Kind '' -Click 'cursor-not-ready'
Check-Equal '클리어 일반/커서 실패: 기존 문구 + 1초 + continue' ("$((@($r.Logs | Where-Object { $_ -match '커서 확인 실패로 닫기 클릭을 건너뜀' })).Count)/$($r.Sleep)/$($r.After)") '1/1/False'
# 가루 부활 pending × 클릭 3종 - 여신상 전환은 사유와 무관하게 성립
foreach ($c in @('sent','user-active','cursor-not-ready')) {
  $r = Run-PopupBlock -Pending $true -Kind '가루 부활' -Click $c
  Check-Equal ("클리어 가루부활/{0}: 여신상 전환 + pending 해제 (사유 무관)" -f $c) ("$($r.Statue)/$($r.Pending)") 'True/False'
  Check-Equal ("클리어 가루부활/{0}: 재료 부족 로그 1 + 양보 없음" -f $c) ("$((@($r.Logs | Where-Object { $_ -match '재료 부족 추정' })).Count)/$($r.Yield)") '1/0'
}
$r = Run-PopupBlock -Pending $true -Kind '가루 부활' -Click 'user-active'
Check-Equal '클리어 가루부활/user-active: 사유가 사용자 조작' (@($r.Logs | Where-Object { $_ -match '재료 부족 추정\) - 사용자 조작으로' }).Count) 1
# 다른 종류 pending / pending 없이 종류만 남음 → 여신상 전환 없음, 일반 분기
$r = Run-PopupBlock -Pending $true -Kind '여신상 부활' -Click 'sent'
Check-Equal '클리어 다른 부활 pending: 여신상 전환 없음, 일반 닫기 로그' ("$($r.Statue)/$((@($r.Logs | Where-Object { $_ -match '구매 팝업 감지 - 닫기 클릭$' })).Count)") 'False/1'
$r = Run-PopupBlock -Pending $false -Kind '가루 부활' -Click 'sent'
Check-Equal '클리어 pending 없음(종류만 잔존): 여신상 전환 없음' $r.Statue $false
# 주기 게이트: 구매 팝업 탐색을 **직접** 감싸는 조건이 % 2 인지 (함수 전체가 아니라 탐색 줄 바로 앞)
$clearBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Wait-ForDungeonClearScreen'))
$clearCode = (($clearBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Check-Equal '클리어 대기: 구매 팝업 탐색이 % 2 게이트 바로 안에' ($clearCode -match '(?s)if \(\(\$pollCounter % 2\) -eq 0 -and -not \$script:screenCaptureFailing\) \{\s*Move-CursorOutsideGame -Game \$Game\s*\$popupClosePoint = Find-GameTextPoint') $true

# ── 6. 자리 1 소스 구조 단언 ──────────────────────────────────────────────────
$entryBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-AfterEntryKeys'))
$entryCode = (($entryBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Check-Equal '입장 직후: 회전 서두 사유 메타 초기화' ($entryCode -match "for \(\`$popupTry = 1; \`$popupTry -le 4; \`$popupTry\+\+\) \{\s*\`$script:lastClickSkipReason = ''") $true
Check-Equal '입장 직후: 취소 되돌림이 Wait-UserYieldEnd 뒤, 1초 대기 앞' ($entryCode -match "(?s)elseif \(\`$script:lastClickSkipReason -eq 'user-active'\) \{.{0,300}?Wait-UserYieldEnd.{0,60}?\`$popupTry--\s*continue\s*\}\s*Start-Sleep -Seconds 1") $true
Check-Equal '입장 직후: 4회째 잔존 판정이 클릭보다 앞 (되돌림은 1~3회에서만)' ($entryCode.IndexOf('$popupTry -ge 4') -lt $entryCode.IndexOf('Click-ScreenPoint -X $entryPopupPoint.X')) $true
Check-Equal '입장 직후: 시도 상한·잔존 경고 문구 유지' (($entryCode -match '\$popupTry -le 4') -and ($entryCode -match '\$\{entryPopupClicks\}회 뒤에도')) $true

exit $fails
