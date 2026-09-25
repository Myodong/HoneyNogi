# 어비스 선택 화면 복귀 루프(Return-ToAbyssSelection) 행동 진리표 (v2.1.12 - 2026-09-21 구현 리뷰 2차 P1·P2)
#
# 09-20 23:25 실사고: 복귀 루프가 던전 안 HUD 를 '던전 밖' 으로 보고 ESC → 메뉴 '어비스' 로 던전 안에서 선택 화면 오버레이를 열어
# '복귀 완료'(코드 0). 1차 핫픽스는 필드(HUD + 추적기 던전명 없음)를 직접 확인하고 ESC 를 실제 전송했을 때만 발급하는 일회성
# 토큰($fieldProven)으로 메뉴 '어비스' 클릭을 막았는데, 폐기가 서두 양보 게이트·캡처 실패·패널·던전 안 증거뿐이라 **메뉴 '어비스'
# 클릭이 조작으로 생략된 뒤의 양보**(게이트를 지나지 않음)에서 옛 토큰이 살아남았다 - 양보 중 사용자가 재입장하고 던전 안에서
# ESC 메뉴를 열면 그 '어비스' 를 눌러 원 사고가 재현된다 (구현 리뷰 2차 P1 - 코드로 확정, 실기 미관측).
# 여기서 고정하는 계약 (운영 함수를 AST 로 추출해 모의 화면 상태 기계로 실행 - 사본 재구현 금지, exit 는 기록 뒤 return 으로 치환):
#   ① 기준: 필드 → ESC 전송(토큰 발급) → 메뉴 → '어비스' 클릭 → 선택 화면 → '선택 화면 복귀 확인'
#   ② P1: 토큰 발급 뒤 **어떤 양보든** 있었으면('어비스' 클릭 생략 뒤 양보 / ESC 클릭 생략 뒤 양보) 메뉴의 '어비스' 를 누르지 않고
#      ESC 로 닫아 화면을 재확인 → 던전 안(HUD + 추적기)이면 2연속·20초 뒤 코드 4 ('어비스' 클릭 전송 0, 복귀 확인 0)
#   ③ P1: 발급 뒤 캡처 실패가 있던 회전은 토큰 **폐기**(캡처 공백 중 게임 상태는 멈추지 않음 - 3차 리뷰) → 메뉴를 닫고 필드부터 재증명
#   ④ P2: 던전 안 첫 확인 뒤 캡처 실패 동결 시간은 20초 창에서 제외 (복구 직후 두 번째 표본에서 즉시 코드 4 금지 - 규칙 15)
#   ⑤ P1(4차): 필드 표본 뒤 판독(공지 팝업)에서 캡처 실패 → 뒤 ESC 글자 탐색 성공이 플래그를 풀어도 그 회전은 ESC 를 보내지 않음
#      (실패 뒤 일련번호로 토큰을 발급하면 다음 메뉴 대조가 실패를 못 보는 '세탁')
#   ⑥ P1(4차): 토큰 보유 뒤 메뉴가 아닌 복구 분기(이벤트 헬퍼 등)로 내려가면 토큰 폐기 - 헬퍼 안 0ms 양보는 직접 폐기 8곳도 누적 차분도 못 봄
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

# ── 운영 코드 추출 (사본 재구현 금지) ─────────────────────────────────────────
foreach ($name in @('Get-YieldAdjustedDeadline', 'Invoke-UserYieldWithDeadline')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}
$loopDef = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Return-ToAbyssSelection'))
Check-Equal '추출: 복귀 루프의 exit 는 4곳 (안전 중지 2 + 메뉴 출처 미확인 + 던전 안 확인)' ([regex]::Matches($loopDef, '(?m)^\s*exit (4|\$SafeStopExitCode)\s*$').Count) 4
$loopDef = $loopDef -replace '(?m)^(\s*)exit 4\s*$', '$1$script:exitCode = 4; return'
$loopDef = $loopDef -replace '(?m)^(\s*)exit \$SafeStopExitCode\s*$', '$1$script:exitCode = $SafeStopExitCode; return'
Invoke-Expression $loopDef

# ── 운영 상수 (값은 계약과 무관 - 마감 60초·영역 좌표만 형식을 맞춤) ──
$timeoutHud = 30; $timeoutAbyssMenu = 15; $timeoutAbyssSelect = 15
$safeStopFlagPath = 'HoneyNogi_safe_stop_test.flag'
$rgAbyssMenu = @(850, 180, 350, 520); $rgHomeEndEsc = @(1000, 40, 260, 90); $ptEscButton = @(1083, 89); $ocrEnglishEngine = 'en'
$ptNoticeClose = @(1090, 137); $rgStellaTitle = @(0, 0, 10, 10); $ocrKoreanEngine = 'ko'; $ptStellaCard = @(0, 0); $rgStellaPickBtn = @(0, 0, 10, 10)
$refocusEverySeconds = 0
$game = $null

# ── 모의: 가상 시계 + 화면 상태 기계 ────────────────────────────────────────────
# $script:screen = 'field'(필드 HUD) / 'menu'(필드에서 연 ESC 메뉴) / 'menuInside'(던전 안에서 연 ESC 메뉴) / 'inside'(던전 안 HUD+추적기) /
#                  'selection'(선택 화면) / 'panel'(재매칭 패널). 클릭·키 전송이 화면을 전이시키고, 양보 중 전이는 $script:screenAfterYield 로 줍니다.
function Get-Date { return $script:vclock }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) $script:vclock = $script:vclock.AddMilliseconds($Milliseconds + $Seconds * 1000) }
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Write-LifeDiagnostics { param($Game, $Context, [switch]$CaptureOnly) $script:diagCalls++; $script:diagContext = $Context }
function Focus-Game { param($Game) }
function Test-Path { param($LiteralPath, $Path) return $false }
function Remove-Item { param($LiteralPath, [switch]$Force, $ErrorAction) $script:flagRemoved++ }
function Test-SafeStopDuringCaptureFail {
  $script:safeStopCalls++
  # 동결 회전 수 예산: 서두 동결 블록이 회전마다 한 번 부르므로 여기서 남은 실패 회전을 셉니다
  if ($script:capfailRounds -gt 0) { $script:capfailRounds--; if ($script:capfailRounds -le 0) { $script:capfailActive = $false } }
}
function Next-Seq { param([string]$Name, $Default)
  $seq = Get-Variable -Name ($Name + 'Seq') -Scope Script -ValueOnly
  $idx = Get-Variable -Name ($Name + 'Idx') -Scope Script -ValueOnly
  if ($idx -lt $seq.Count) { Set-Variable -Name ($Name + 'Idx') -Scope Script -Value ($idx + 1); return $seq[$idx] }
  return $Default
}
function Test-UserRecentlyActive { return [bool](Next-Seq 'active' $false) }
function Wait-UserYieldEnd { param($Game, $Context)
  # 실제처럼 양보 시간을 $script:userYieldTotalMs 에 누적 - 추출한 Invoke-UserYieldWithDeadline 이 이 값으로 마감을 늘립니다
  $script:yieldWaits++; $script:vclock = $script:vclock.AddSeconds($script:yieldSeconds)
  $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $script:yieldSeconds * 1000
  if ($script:screenAfterYield) { $script:screen = $script:screenAfterYield; $script:screenAfterYield = '' }
}
# 판독 모의: 캡처 실패 구간(capfailActive)이면 실패 등록(플래그·일련번호 - Register-CaptureFailure 계약)하고 거짓,
# 아니면 성공 등록(플래그 해제 - Register-CaptureSuccess 계약) 뒤 화면 상태로 답합니다
function Read-Mock { param([bool]$Value)
  $script:readCalls++
  if ($script:capfailActive) { $script:screenCaptureFailing = $true; $script:captureFailSerial++; return $false }
  $script:screenCaptureFailing = $false; return $Value
}
function Test-AbyssMatchingPanel { param($Game)
  $script:panelReads++   # 회전의 첫 판독 - 회전 번호 역할
  if ($script:panelReads -eq $script:capfailTriggerRead) { $script:capfailActive = $true }
  if ($script:panelReads -eq $script:panelFailAtRead) {
    # 이 판독만 일시 실패 (뒤 판독 성공이 플래그를 풂). 캡처 공백 중 화면이 바뀌는 반례는 $script:screenAtPanelFail 로 줍니다 (3차 리뷰 P1)
    $script:readCalls++; $script:screenCaptureFailing = $true; $script:captureFailSerial++
    if ($script:screenAtPanelFail) { $script:screen = $script:screenAtPanelFail }
    return $false
  }
  return (Read-Mock ($script:screen -eq 'panel'))
}
function Test-AbyssSelectionScreen { param($Game) return (Read-Mock ($script:screen -eq 'selection')) }
function Test-AbyssMenu { param($Game) $r = Read-Mock ($script:screen -eq 'menu' -or $script:screen -eq 'menuInside'); if ($r) { $script:menuChecks++ }; return $r }
function Test-HomeEndEscHud { param($Game) return (Read-Mock ($script:screen -eq 'field' -or $script:screen -eq 'inside')) }
function Test-InDungeonQuest { param($Game) return (Read-Mock ($script:screen -eq 'inside')) }
function Test-ExitButton { param($Game) return (Read-Mock ($script:screen -eq 'reward')) }
function Test-NoticeBoardPopup { param($Game)
  # 필드 표본 뒤의 판독 - N번째 호출에서 일시 캡처 실패(플래그·일련번호) + 그 공백 중 화면 전이를 모의 (4차 리뷰 P1 '세탁')
  $script:noticeCalls++
  if ($script:noticeCalls -eq $script:noticeFailAtCall) {
    $script:readCalls++; $script:screenCaptureFailing = $true; $script:captureFailSerial++
    if ($script:screenAtNoticeFail) { $script:screen = $script:screenAtNoticeFail }
    return $false
  }
  return $false
}
function Invoke-EventSkipOrConfirm { param($Game, $LogPrefix)
  # 복구 분기의 이벤트 헬퍼 - 내부 user-active 대기가 0ms 로 끝나 누적 양보에 잡히지 않는 경우를 모의: 화면만 바뀌고 반환 $false (4차 리뷰 P1)
  if ($script:eventYieldToScreen) { $script:screen = $script:eventYieldToScreen; $script:eventYieldToScreen = '' }
  return $false
}
function Close-GhostRegisterPrompt { param($Game, $LogPrefix) return $false }
function Invoke-AutoRefocus { param($Game) return $false }
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine, [switch]$BinaryWhiteText) return '' }
function Invoke-AbyssExitClick { param($Game, $LogPrefix, $Context) return @{ Result = 'gone'; FrozenMs = 0 } }
function Find-GameTextPoint { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText, $ExactText, $Scale, $Engine)
  $script:screenCaptureFailing = $false   # 글자 탐색 성공 = 캡처 성공 등록(플래그 해제) - 앞 판독의 실패를 '풀어 버리는' 실제 계약
  if ($SearchText -eq 'ESC') { return @{ X = 1102; Y = 74 } }
  if ($SearchText -eq '어비스') { return @{ X = 971; Y = 531 } }
  return $null
}
function Send-Mock { param([int]$X, [int]$Y)
  $r = Next-Seq 'send' 'sent'
  $script:lastClickPerformed = ($r -eq 'sent'); $script:lastClickSkipReason = $(if ($r -eq 'sent') { '' } else { $r })
  if ($r -ne 'sent') { return }
  if ($X -eq 1102) {
    # ESC 버튼: 필드 → 메뉴 / 던전 안 → 던전 안 메뉴 / 메뉴 → 닫힘 (게임이 무시한 경우 화면 유지, $script:escLeadsTo 로 전이 화면 강제)
    $script:escClicksSent++
    if ($script:escIgnoredOnce) { $script:escIgnoredOnce = $false }
    elseif ($script:escLeadsTo) { $script:screen = $script:escLeadsTo; $script:escLeadsTo = '' }
    else {
      switch ($script:screen) {
        'field'      { $script:screen = 'menu' }
        'inside'     { $script:screen = 'menuInside' }
        'menu'       { $script:screen = 'field' }
        'menuInside' { $script:screen = 'inside' }
      }
    }
  } elseif ($X -eq 971) {
    # 메뉴 '어비스' → 선택 화면. 던전 안에서 연 메뉴였다면 오버레이 = 원 사고 (09-20 23:25)
    $script:abyssClicksSent++; $script:abyssClickAtMenuCheck = $script:menuChecks
    if ($script:screen -eq 'menuInside') { $script:abyssClickedFromInside++ }
    $script:screen = 'selection'
  } else { $script:otherClicksSent++ }
}
function Click-ScreenPoint { param([int]$X, [int]$Y) Send-Mock -X $X -Y $Y }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) Send-Mock -X ([int]$ReferenceX) -Y ([int]$ReferenceY) }
function Press-KeyVerified { param($Game, $VirtualKey, $Label)
  # 메뉴 닫기 ESC - 메뉴가 열려 있던 화면으로 돌아감
  $script:keyVerified++
  if ($script:screen -eq 'menu') { $script:screen = 'field' } elseif ($script:screen -eq 'menuInside') { $script:screen = 'inside' }
  return $true
}
function Press-KeyOnce { param($VirtualKey) $script:keyOnce++ }
function Reset-Case {
  param([string]$Screen = 'field', $ActiveSeq = @(), $SendSeq = @())
  $script:screen = $Screen; $script:screenAfterYield = ''; $script:escIgnoredOnce = $false
  $script:activeSeq = @($ActiveSeq); $script:activeIdx = 0; $script:sendSeq = @($SendSeq); $script:sendIdx = 0
  $script:vclock = [datetime]'2026-09-21 12:00:00'; $script:startClock = $script:vclock
  $script:logs = @(); $script:yieldWaits = 0; $script:yieldSeconds = 5; $script:userYieldTotalMs = [double]0
  $script:readCalls = 0; $script:panelReads = 0; $script:menuChecks = 0; $script:safeStopCalls = 0; $script:diagCalls = 0; $script:diagContext = ''
  $script:escClicksSent = 0; $script:abyssClicksSent = 0; $script:abyssClickAtMenuCheck = -1; $script:abyssClickedFromInside = 0; $script:otherClicksSent = 0
  $script:keyVerified = 0; $script:keyOnce = 0; $script:flagRemoved = 0; $script:exitCode = $null; $script:threw = ''
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타 - 오발동 없어야 함
  $script:screenCaptureFailing = $false; $script:captureFailSerial = 0
  $script:capfailActive = $false; $script:capfailRounds = 0; $script:capfailTriggerRead = -1; $script:panelFailAtRead = -1; $script:screenAtPanelFail = ''
  $script:escLeadsTo = ''; $script:noticeCalls = 0; $script:noticeFailAtCall = -1; $script:screenAtNoticeFail = ''; $script:eventYieldToScreen = ''
}
function Run-Loop { param([int]$SafeStopExitCode = 0) try { Return-ToAbyssSelection -Game $game -SafeStopExitCode $SafeStopExitCode } catch { $script:threw = $_.Exception.Message } }
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }

# ── 1. 기준: 필드 → ESC(토큰) → 메뉴 → 어비스 → 선택 화면 ─────────────────────────
Reset-Case -Screen 'field'
Run-Loop
Check-Equal '기준: ESC 1 → 어비스 1 → 복귀 확인 1 (메뉴 닫기 0, 코드 없음, 출처 재확인 로그 0)' ("$($script:escClicksSent)/$($script:abyssClicksSent)/$((Count-Log '선택 화면 복귀 확인'))/$($script:keyVerified)/$($script:exitCode)/$((Count-Log '메뉴 출처를 다시 확인'))") '1/1/1/0//0'
Check-Equal '기준: 던전 안 메뉴에서 누른 어비스 0, throw 없음' ("$($script:abyssClickedFromInside)/$($script:threw)") '0/'
#    1b. 발급 **전** 양보는 토큰과 무관 - 기준값을 발급 시점에 찍지 않으면(변이) 이전 양보 누적 때문에 첫 메뉴에서 헛폐기 → 메뉴 닫기 1
Reset-Case -Screen 'field' -ActiveSeq @($true)
Run-Loop
Check-Equal '발급 전 양보: 양보 1 → ESC 1 → 어비스 1 → 복귀 확인 1, 메뉴 닫기 0, 출처 재확인 로그 0' ("$($script:yieldWaits)/$($script:escClicksSent)/$($script:abyssClicksSent)/$((Count-Log '선택 화면 복귀 확인'))/$($script:keyVerified)/$((Count-Log '메뉴 출처를 다시 확인'))") '1/1/1/1/0/0'

# ── 2. ★ P1: 어비스 클릭 생략(조작) → 양보 중 재입장 + 던전 안 ESC 메뉴 → 옛 토큰으로 누르면 안 됨 ──
#    필드 → ESC 전송(토큰) → 메뉴 → 어비스 클릭이 user-active 로 생략 → 양보(화면: 던전 안 메뉴) → 메뉴 재감지 → 토큰 폐기 →
#    ESC 로 닫기(1회) → 던전 안(HUD+추적기) 2연속·20초 → 코드 4. 옛 코드(변이): 양보 뒤 옛 토큰으로 어비스 클릭 → 오버레이 → '복귀 확인'
Reset-Case -Screen 'field' -SendSeq @('sent', 'user-active')
$script:screenAfterYield = 'menuInside'
Run-Loop
#    (출처 재확인 로그 0 = 생략 자리의 명시 폐기가 먼저 걸려 게이트에 닿지 않음. 게이트 로그는 간접 양보·캡처 공백 전용 - 아래 3·3b)
Check-Equal 'P1 어비스 생략 뒤 양보: 어비스 전송 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, 복귀 확인 0, 출처 재확인 로그 0' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$((Count-Log '선택 화면 복귀 확인'))/$((Count-Log '메뉴 출처를 다시 확인'))") '0/0/1/4/0/0'
# (주의) 큰따옴표 문자열 안의 $( ) 에 괄호가 든 따옴표 문자열을 넣으면 PS 5.1 파서가 하위식 끝을 못 찾습니다 - 패턴 개수는 변수로 미리 셉니다
$insideStopLogs = Count-Log '던전 안 상태\(HUD \+ 던전 목표\)를 확인해'
Check-Equal 'P1 어비스 생략 뒤 양보: 정지 사유 = 던전 안 확인, 진단 캡처 1(문맥)' ("$insideStopLogs/$($script:diagCalls)/$($script:diagContext)") '1/1/어비스 복귀 중 던전 안 확인'
$skipLogs = Count-Log '어비스 메뉴 클릭 건너뜀 \(사용자 조작\)'; $clickLogs = Count-Log '어비스 메뉴 클릭 \(글자'
Check-Equal 'P1 어비스 생략 뒤 양보: 양보 1회, 클릭 생략 로그 1 (거짓 클릭 로그 없음)' ("$($script:yieldWaits)/$skipLogs/$clickLogs") '1/1/0'

#    2b. ESC 클릭 생략(조작) 뒤 양보 - 앞 회전에 발급된 토큰이 남아 있어도 같은 계약 (첫 ESC 는 전송됐지만 게임이 무시 → 메뉴 안 열림)
Reset-Case -Screen 'field' -SendSeq @('sent', 'user-active')
$script:escIgnoredOnce = $true; $script:screenAfterYield = 'menuInside'
Run-Loop
Check-Equal 'P1 ESC 생략 뒤 양보: 어비스 전송 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, ESC 전송 1, 출처 재확인 로그 0(명시 폐기)' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$($script:escClicksSent)/$((Count-Log '메뉴 출처를 다시 확인'))") '0/0/1/4/1/0'
#    2c. ★ 3차 리뷰 P1: 클릭 시점엔 조작 중이었지만 양보 대기가 즉시 끝나(Wait-UserYieldEnd 의 유휴 재검사) 누적 양보가 0 인 경계 -
#    누적값 차분만으로는 못 잡으므로 생략 자리에서 토큰을 직접 폐기해야 함 (변이: 그 폐기 줄 제거 → 옛 토큰으로 던전 안 어비스 클릭)
Reset-Case -Screen 'field' -SendSeq @('sent', 'user-active')
$script:yieldSeconds = 0; $script:screenAfterYield = 'menuInside'
Run-Loop
Check-Equal 'P1 어비스 생략 뒤 0초 양보: 어비스 전송 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, 누적 양보 0' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$([int]$script:userYieldTotalMs)") '0/0/1/4/0'

# ── 3. P1(3차): 발급 뒤 캡처 실패가 있던 회전은 토큰 폐기 - 캡처 공백 중 게임 상태는 멈추지 않으므로(재입장·던전 안 메뉴 가능) 메뉴를 닫고 필드부터 재증명 ──
#    필드 → ESC(토큰) → [회전 2] 패널 판독만 실패(일련번호 +1, 뒤 선택 화면 판독 성공이 플래그 해제) → 메뉴 감지 → 폐기 → ESC 닫기(1) →
#    필드 → ESC(2) → 메뉴 → 어비스 클릭 → 선택 화면. (2차 반영 초안은 '기준 갱신 + 재판독' 이었고 3차 리뷰가 아래 3b 반례로 반려)
Reset-Case -Screen 'field'
$script:panelFailAtRead = 2
Run-Loop
Check-Equal '발급 뒤 캡처 실패 회전: 토큰 폐기 → 메뉴 닫기 1 → ESC 2회 → 어비스 1 → 복귀 확인 1, 출처 재확인 로그 1, 동결 0' ("$($script:keyVerified)/$($script:escClicksSent)/$($script:abyssClicksSent)/$((Count-Log '선택 화면 복귀 확인'))/$((Count-Log '메뉴 출처를 다시 확인'))/$($script:safeStopCalls)") '1/2/1/1/1/0'
#    3b. ★ 3차 리뷰 P1 반례: 캡처 공백 중 사용자가 재입장하고 던전 안에서 ESC 메뉴를 열어 둠 → 복구 뒤 보이는 것은 '메뉴' 뿐 → 옛 토큰으로 누르면 원 사고
Reset-Case -Screen 'field'
$script:panelFailAtRead = 2; $script:screenAtPanelFail = 'menuInside'
Run-Loop
Check-Equal '캡처 공백 중 재입장 + 던전 안 메뉴: 어비스 전송 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)") '0/0/1/4'

# ── 4. P2: 던전 안 첫 확인 뒤 캡처 실패 동결(15회전 ≈ 21초)은 20초 창에서 제외 ─────────
#    던전 안(1, t=0) → 회전 2 부터 캡처 실패 15회전 → 복구 직후 표본(2연속)에서 즉시 코드 4 금지 → 동결 제외 20초 뒤 코드 4 (t ≥ 40)
#    옛 코드(변이): 복구 직후 t≈23 에서 즉시 코드 4
Reset-Case -Screen 'inside'
$script:capfailTriggerRead = 2; $script:capfailRounds = 15
Run-Loop
$insideElapsed = [int](($script:vclock - $script:startClock).TotalSeconds)
Check-Equal '던전 안 + 캡처 실패 동결: 코드 4, 안전 확인 15회(동결 회전마다), 어비스 전송 0, 메뉴 닫기 0' ("$($script:exitCode)/$($script:safeStopCalls)/$($script:abyssClicksSent)/$($script:keyVerified)") '4/15/0/0'
Check-Equal ('던전 안 + 캡처 실패 동결: 정지 시각이 시작 40초 이후 (동결 약 21초 제외 후 20초 - 실제 ' + $insideElapsed + '초)') ([int]($insideElapsed -ge 40)) 1
#    4b. 동결 없는 기준: 던전 안 2연속·20초 → 코드 4 (t ≈ 20~22)
Reset-Case -Screen 'inside'
Run-Loop
$insideElapsedPlain = [int](($script:vclock - $script:startClock).TotalSeconds)
$plainInWindow = [int]($insideElapsedPlain -ge 20 -and $insideElapsedPlain -le 24)
Check-Equal ('던전 안(동결 없음): 코드 4, 정지 시각 20~24초 (실제 ' + $insideElapsedPlain + '초), 안전 확인 0') ("$($script:exitCode)/$plainInWindow/$($script:safeStopCalls)") '4/1/0'

# ── 5. ★ 4차 리뷰 P1-1 '토큰 세탁': 필드 표본 뒤 공지 팝업 판독에서 캡처 실패(그 공백 중 사용자가 재입장 = 던전 안) → ESC 글자 탐색 성공이 ──
#    플래그를 풂. 옛 코드: ESC 전송(던전 안이라 던전 안 메뉴가 열림) + 실패 뒤 일련번호로 토큰 발급 → 다음 회전 메뉴 대조 통과 → 어비스
#    클릭 → 오버레이 → '복귀 확인'(원 사고). 수정: 실패 회전은 ESC 를 보내지 않고 재판독 → 다음 회전 던전 안 → 코드 4
Reset-Case -Screen 'field'
$script:noticeFailAtCall = 1; $script:screenAtNoticeFail = 'inside'
Run-Loop
Check-Equal '발급 직전 캡처 실패(세탁 금지): ESC 전송 0, 어비스 0, 던전 안 클릭 0, 복귀 확인 0, 코드 4' ("$($script:escClicksSent)/$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$((Count-Log '선택 화면 복귀 확인'))/$($script:exitCode)") '0/0/0/0/4'

# ── 6. ★ 4차 리뷰 P1-2 간접 0ms 양보: 토큰 보유 뒤 화면이 메뉴가 아닌 '알 수 없음'(전환) → 복구 분기의 이벤트 헬퍼 안 양보 중 던전 안 메뉴가 열림 ──
#    (헬퍼 대기가 즉시 끝나 누적 양보 0 → 직접 폐기 8곳도 누적 차분도 못 봄). 옛 코드: 다음 회전 메뉴 대조 통과 → 어비스 클릭. 수정: 복구 분기
#    진입 = 토큰 폐기 → 다음 회전 메뉴 → 출처 미확인 → ESC 닫기 → 던전 안 → 코드 4
Reset-Case -Screen 'field'
$script:escLeadsTo = 'unknown'; $script:eventYieldToScreen = 'menuInside'
Run-Loop
Check-Equal '복구 분기 진입 시 토큰 폐기: ESC 1, 어비스 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, 누적 양보 0' ("$($script:escClicksSent)/$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$([int]$script:userYieldTotalMs)") '1/0/0/1/4/0'

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
