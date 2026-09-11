# 출석·공지 팝업 넘기기(Clear-EventOverlay)의 사용자 조작 양보 계약 (2026-09-11)
#
# 실측 09-10 23:51: 조작으로 생략된 클릭이 '클릭' 로그를 남기고 시도 횟수를 소모했습니다.
# 시도 횟수는 예산(20)·격상 문턱(6)·X 후보 인덱스 세 가지로 쓰이고, X 후보 첫 좌표는
# 던전 우상단 X 와 겹쳐 던전을 닫고 필드로 나간 실사고가 있는 자리입니다.
#
# 여기서 고정하는 계약 (설계 합의):
#   클릭 전송 → 시도 소모 + 로그 / user-active 생략 → 미소모 + 로그 없음 + 기다림 /
#   cursor-not-ready → 기존대로 소모 / Space 전송 → 소모 / 헬퍼가 양보 후 $false → 폴백 안 탐
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'

# 운영 함수를 소스에서 그대로 추출합니다 (사본 재구현 금지).
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @(
    'Clear-EventOverlay', 'Invoke-EventSkipOrConfirm')) {
  Invoke-Expression $definition
}

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ($Actual -eq $Expected) { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
$game = Get-Process -Id $PID

# ── 화면 모형: 팝업은 상태이고, **실제로 전송된 클릭으로만** 사라집니다 ─────────────
# 'known' = 자동화가 아는 화면 / 'notice' = 공지 보드 / 'stella' = 스텔라 픽 1단계 /
# 'reward' = 출석 완료(Space) / 'unknown' = 아무것도 못 알아보는 화면
$script:screen = 'known'
$script:clicks = 0
$script:yieldWaits = 0
$script:logs = @()
$script:lastClickPerformed = $false
$script:lastClickSkipReason = ''
$script:screenCaptureFailing = $false
$script:userYieldTotalMs = [double]0

# 영역·좌표 상수 (값은 무의미 - 스텁이 이름으로 구분)
$rgStellaTitle = @(1,1,1,1); $rgStellaPickBtn = @(2,2,2,2); $rgEventTodayOff = @(3,3,3,3)
$rgEventCloseBtn = @(4,4,4,4); $rgNoticeBoardTabs = @(5,5,5,5); $rgNpcDialogue = @(6,6,6,6)
$rgEventSkip = @(7,7,7,7); $rgEventReward = @(8,8,8,8); $rgEventConfirm = @(9,9,9,9)
$ptStellaCard = @(640,420); $ptStellaClose = @(1229,67); $ptNoticeBoardClose = @(1092,135)
$ptClearCenter = @(636,358); $ocrKoreanEngine = $null

function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Focus-Game { param($Game) }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) }
function Test-SafeStopDuringCaptureFail {}
function Test-KnownScreen { param($Game) $script:screen -eq 'known' }
function Close-GhostRegisterPrompt { param($Game, $LogPrefix) $false }
function Close-CoopMissionBoardScreen { param($Game, $LogPrefix) $false }
function Close-NetworkUnstablePopup { param($Game, $LogPrefix) $false }
function Close-WeeklyCoopResetPopup { param($Game, $LogPrefix) $false }

function Get-GameRegionOcrText {
  param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine)
  switch ($ReferenceX) {
    1 { if ($script:screen -eq 'stella') { return '오늘의스텔라픽' }; return '' }
    8 { if ($script:screen -eq 'reward') { return '지원품이지급되었습니다' }; return '' }
    6 { return '' }   # 말풍선 없음 → 알 수 없는 화면은 격상 경로
  }
  return ''
}
function Find-GameTextPoint {
  param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText)
  if ($ReferenceX -eq 5 -and $script:screen -eq 'notice') { return [pscustomobject]@{ X = 1092; Y = 135 } }
  return $null
}

# 시퀀스는 인덱스로 소비 (소진 후 기본값으로 - 무한 루프 방지, 09-10 교훈)
$script:userActiveSeq = @(); $script:userActiveIdx = 0
$script:sendSeq = @();       $script:sendIdx = 0
function Test-UserRecentlyActive {
  if ($script:userActiveIdx -lt $script:userActiveSeq.Count) {
    $v = $script:userActiveSeq[$script:userActiveIdx]; $script:userActiveIdx++; return $v
  }
  return $false
}
function Wait-UserYieldEnd { param($Game, $Context) $script:yieldWaits++; $script:userYieldTotalMs += 3000 }

# 클릭 스텁: 시퀀스로 전송/생략 사유를 정합니다. 'sent' | 'user-active' | 'cursor-not-ready'
function Invoke-ClickModel {
  $result = 'sent'
  if ($script:sendIdx -lt $script:sendSeq.Count) { $result = $script:sendSeq[$script:sendIdx]; $script:sendIdx++ }
  $script:lastClickPerformed = ($result -eq 'sent')
  $script:lastClickSkipReason = if ($result -eq 'sent') { '' } else { $result }
  if ($result -eq 'sent') { $script:clicks++; $script:screen = 'known' }   # 실제 전송으로만 닫힘
}
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) Invoke-ClickModel }
function Click-ScreenPoint { param($X, $Y) Invoke-ClickModel }
$script:spacePresses = 0
function Press-KeyOnce { param($VirtualKey) $script:spacePresses++; $script:screen = 'known' }   # 메타를 건드리지 않음 (실제 계약)

function Reset-Case {
  param([string]$Screen = 'notice', $ActiveSeq = @(), $SendSeq = @())
  $script:screen = $Screen
  $script:clicks = 0; $script:yieldWaits = 0; $script:spacePresses = 0; $script:logs = @()
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = ''
  $script:userActiveIdx = 0; $script:userActiveSeq = @($ActiveSeq)
  $script:sendIdx = 0;       $script:sendSeq = @($SendSeq)
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }

# ── 1. 기준: 조작이 없으면 한 번 눌러 닫습니다 ──────────────────────────────
Reset-Case -Screen 'notice'
[void](Clear-EventOverlay -Game $game)
Check-Equal '조작 없음: 클릭 1회로 닫힘' $script:clicks 1
Check-Equal '조작 없음: 클릭 로그 1건' (Count-Log '공지 보드 팝업 - 우상단 닫기') 1
Check-Equal '조작 없음: 양보 대기 없음' $script:yieldWaits 0

# ── 2. 사전 게이트: 루프 머리에서 조작이 잡히면 기다리고 시도를 안 씁니다 ─────
#    조작 3회 뒤 정상 → 클릭 1회로 닫혀야 하고, 로그의 시도 번호가 (1/20) 이어야 합니다.
#    (게이트 없이 시도가 소모됐다면 다음 유효 시도가 4번째로 찍혔을 것)
Reset-Case -Screen 'unknown' -ActiveSeq @($true, $true, $true, $false)
$script:sendSeq = @('sent'); $script:sendIdx = 0
[void](Clear-EventOverlay -Game $game)
Check-Equal '사전 게이트: 조작한 만큼 양보 대기' $script:yieldWaits 3
Check-Equal '사전 게이트: 시도 번호가 1부터 (횟수 미소모)' (Count-Log '\(1/20\)') 1

# ── 3. 경합 백업: 게이트는 통과했는데 클릭 직전 조작으로 생략 ────────────────
#    생략 2회(user-active) 뒤 전송 → 기다린 뒤 되돌려, 시도 번호가 계속 1 이어야 합니다.
Reset-Case -Screen 'unknown' -SendSeq @('user-active', 'user-active', 'sent')
[void](Clear-EventOverlay -Game $game)
Check-Equal '경합 백업: 생략된 만큼 양보 대기' $script:yieldWaits 2
Check-Equal '경합 백업: 되돌려서 시도 번호가 1' (Count-Log '\(1/20\)') 1
Check-Equal '경합 백업: 생략된 클릭은 로그를 남기지 않음' (Count-Log '중앙 클릭으로 진행 시도') 1

# ── 4. 커서 미확인은 **기존대로** 시도를 씁니다 (자동화의 실패 시도) ───────────
Reset-Case -Screen 'unknown' -SendSeq @('cursor-not-ready', 'cursor-not-ready', 'sent')
[void](Clear-EventOverlay -Game $game)
Check-Equal '커서 미확인: 양보 대기 없음' $script:yieldWaits 0
Check-Equal '커서 미확인: 시도가 소모돼 3번째에 전송' (Count-Log '\(3/20\)') 1

# ── 5. ★ 격상 문턱: 생략이 6번 넘게 이어져도 X 후보로 격상되지 않아야 합니다 ───
#    수정 전에는 생략 6회로 attempt 가 6이 되어 X 후보(1229,67 = 던전 우상단 X) 맹클릭이 시작됐습니다.
Reset-Case -Screen 'unknown' -SendSeq @('user-active','user-active','user-active','user-active','user-active','user-active','user-active','sent')
[void](Clear-EventOverlay -Game $game)
Check-Equal '격상 문턱: 생략 7회 뒤에도 X 후보로 격상 안 됨' (Count-Log '닫기\(X\) 후보') 0
Check-Equal '격상 문턱: 첫 유효 시도는 여전히 중앙 클릭' (Count-Log '중앙 클릭으로 진행 시도 \(1/20\)') 1

# ── 6. X 후보 순환: 생략된 후보는 '써 본 후보'가 아닙니다 ─────────────────────
#    5회를 전송해 격상(6회)에 도달한 뒤, 6번째(첫 후보 1229,67)가 생략되면 다음 유효 시도도
#    같은 번호·같은 후보여야 합니다.
Reset-Case -Screen 'unknown' -SendSeq @('sent','sent','sent','sent','sent','user-active','sent')
$script:screen = 'unknown'
function Invoke-ClickModel {
  $result = 'sent'
  if ($script:sendIdx -lt $script:sendSeq.Count) { $result = $script:sendSeq[$script:sendIdx]; $script:sendIdx++ }
  $script:lastClickPerformed = ($result -eq 'sent')
  $script:lastClickSkipReason = if ($result -eq 'sent') { '' } else { $result }
  if ($result -eq 'sent') { $script:clicks++; if ($script:clicks -ge 6) { $script:screen = 'known' } }  # 6번째 전송에서 닫힘
}
[void](Clear-EventOverlay -Game $game)
Check-Equal 'X 후보 순환: 생략된 6번째 뒤 유효 6번째가 같은 후보(1229,67)' (Count-Log '후보\(1229,67\) 클릭 시도 \(6/20\)') 1
Check-Equal 'X 후보 순환: 두 번째 후보로 건너뛰지 않음' (Count-Log '후보\(1090,137\)') 0
# 클릭 모형 원복
function Invoke-ClickModel {
  $result = 'sent'
  if ($script:sendIdx -lt $script:sendSeq.Count) { $result = $script:sendSeq[$script:sendIdx]; $script:sendIdx++ }
  $script:lastClickPerformed = ($result -eq 'sent')
  $script:lastClickSkipReason = if ($result -eq 'sent') { '' } else { $result }
  if ($result -eq 'sent') { $script:clicks++; $script:screen = 'known' }
}

# ── 7. 스텔라 카드 카운터는 실제 전송 뒤에만 오릅니다 ─────────────────────────
#    수정 전: 생략 2회로 카운터가 2가 되어 카드를 한 번도 못 고른 채 닫기 X(1229,67)로 전환.
Reset-Case -Screen 'stella' -SendSeq @('user-active', 'user-active', 'sent')
[void](Clear-EventOverlay -Game $game)
Check-Equal '스텔라: 생략 2회 뒤에도 닫기(X)로 새지 않고 카드 선택' (Count-Log '가운데 카드 선택') 1
Check-Equal '스텔라: 닫기(X) 클릭 없음' (Count-Log '닫기\(X\) 클릭') 0

# ── 8. 헬퍼가 양보 후 $false 를 돌려주면 폴백을 타지 않습니다 ────────────────
#    출석 완료(Space) 화면에서 조작 중 → 헬퍼가 기다린 뒤 $false + 'user-active'.
#    수정 전에는 그 $false 를 '처리할 이벤트 없음'으로 읽어 **중앙 클릭 폴백**으로 내려갔습니다.
Reset-Case -Screen 'reward'
# 헬퍼 안의 게이트만 조작으로: 루프 머리 게이트는 통과, 헬퍼 안 Test-UserRecentlyActive 는 참
$script:userActiveSeq = @($false, $true, $false, $false); $script:userActiveIdx = 0
[void](Clear-EventOverlay -Game $game)
Check-Equal '헬퍼 양보: 폴백 중앙 클릭이 나가지 않음' (Count-Log '중앙 클릭') 0
Check-Equal '헬퍼 양보: 이후 Space 로 정상 처리' $script:spacePresses 1

# ★ 헬퍼 양보의 예산 반환을 **직접** 검증합니다. 위 단언들은 폴백 차단만 보고 있어서,
#   '$attempt--' 만 지워도 통과했습니다 (2026-09-11 구현 리뷰가 변이로 확인한 구멍).
#   시나리오: 헬퍼 양보 2회 → Space 전송(시도 1 소모) → 화면이 '알 수 없음'으로 바뀜 →
#   중앙 클릭. 양보 2회가 되돌려졌으면 그 중앙 클릭 로그는 (2/20) 이어야 합니다.
#   (되돌리지 않았으면 (4/20). Space 가 시도를 쓰는 것도 같이 확인됩니다.)
Reset-Case -Screen 'reward'
$script:userActiveSeq = @($false, $true, $false, $true, $false, $false, $false); $script:userActiveIdx = 0
function Press-KeyOnce { param($VirtualKey) $script:spacePresses++; $script:screen = 'unknown' }   # Space 뒤 다른 팝업
[void](Clear-EventOverlay -Game $game)
Check-Equal '헬퍼 양보 예산 반환: 양보 2회 + Space 뒤 중앙 클릭이 (2/20)' (Count-Log '중앙 클릭으로 진행 시도 \(2/20\)') 1
Check-Equal '헬퍼 양보 예산 반환: 양보 회전이 소모됐다면 나올 (4/20) 없음' (Count-Log '\(4/20\)') 0
function Press-KeyOnce { param($VirtualKey) $script:spacePresses++; $script:screen = 'known' }   # 원복

# ── 9. Space 는 메타를 안 건드려도 시도를 씁니다 (전송이므로) ─────────────────
Reset-Case -Screen 'reward'
[void](Clear-EventOverlay -Game $game)
Check-Equal 'Space: 양보 대기 없음' $script:yieldWaits 0
Check-Equal 'Space: 1회로 닫힘' $script:spacePresses 1

# ── 10. 헬퍼의 -Outcome 계약 (직접 호출) ───────────────────────────────────────
$script:screen = 'reward'
$script:userActiveSeq = @($true); $script:userActiveIdx = 0
$outcome = ''
$ret = Invoke-EventSkipOrConfirm -Game $game -Outcome ([ref]$outcome)
Check-Equal 'Outcome: 양보 경로는 $false + user-active' ("$ret/$outcome") 'False/user-active'
$script:userActiveSeq = @(); $script:userActiveIdx = 0
$outcome = ''
$ret = Invoke-EventSkipOrConfirm -Game $game -Outcome ([ref]$outcome)
Check-Equal 'Outcome: Space 경로는 $true + sent' ("$ret/$outcome") 'True/sent'
$script:screen = 'known'
$outcome = 'stale'
$ret = Invoke-EventSkipOrConfirm -Game $game -Outcome ([ref]$outcome)
Check-Equal 'Outcome: 처리할 것 없으면 $false + 빈 값 (진입 시 초기화)' ("$ret/$outcome") 'False/'
Check-Equal 'Outcome 없이 불러도 동작 (기존 호출부 호환)' (Invoke-EventSkipOrConfirm -Game $game) $false

# ── 11. 소스 구조 단언 (주석 제거본) ──────────────────────────────────────────
$workerRaw = Get-Content -LiteralPath $workerPath -Raw -Encoding UTF8
$code = (($workerRaw -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
$fnStart = $code.IndexOf('function Clear-EventOverlay')
$fnEnd = $code.IndexOf("`nfunction ", $fnStart + 10)
$fn = $code.Substring($fnStart, $fnEnd - $fnStart)
Check-Equal '구조: 사전 게이트가 attempt 증가보다 앞' ($fn.IndexOf('elseif (Test-UserRecentlyActive)') -lt $fn.IndexOf('$attempt++')) $true
Check-Equal '구조: 회전마다 사유 메타를 비움' ($fn -match '\$script:lastClickSkipReason = ''''') $true
Check-Equal '구조: 되돌림은 user-active 두 조건을 함께 봄' ($fn -match '-not \$script:lastClickPerformed -and \$script:lastClickSkipReason -eq ''user-active''') $true
Check-Equal '구조: 헬퍼 양보를 폴백 조건에서 제외' ($fn -match '\$eventOutcome -ne ''user-active''') $true
Check-Equal '구조: 되돌림 횟수 상한 없음 (설계 합의)' ($fn -notmatch 'rollback|undoCount|restoreLimit') $true
$unconditionalLogs = ([regex]::Matches($fn, '(?m)^\s*Click-(Game|Screen)Point[^\n]*\n\s*Write-RunLog')).Count
Check-Equal '구조: 클릭 직후 무조건 로그가 남아 있지 않음' $unconditionalLogs 0

exit $fails
