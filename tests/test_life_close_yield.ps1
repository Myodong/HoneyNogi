# 채집 시작 정리(Close-LifeOpenWindows)의 사용자 조작 양보 계약 (2026-09-13)
#
# 규칙 4 를 지키지 않던 마지막 생활 자리. 취소된 클릭이 X 시도 2회를 소모하고 사유를
# '커서 확인이 안 돼' 로 잘못 적었으며, 상세 팝업 '확인'은 전송 확인 자체가 없어 팝업이 남은 채
# X 가 모달에 막혔습니다. 여기서 고정하는 계약(설계 합의):
#   X: 전송 → 시도 +1 / user-active → 미소모, 기다린 뒤 재판독 / cursor-not-ready → 시도 +1
#   확인: user-active 면 상한 없이 기다렸다 상세 OCR 부터 / cursor-not-ready 는 1회로 끝
#   반환값 = 닫기 입력을 하나 이상 **전송**했음 (미전송만으로는 참이 되지 않음)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Close-LifeOpenWindows')) {
  Invoke-Expression $definition
}

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ($Actual -eq $Expected) { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
$game = Get-Process -Id $PID

# ── 화면 모형: 팝업·창은 상태이고 **실제 전송된 클릭으로만** 사라집니다 ─────────────
$rgLifeDetail = @(1,1,1,1); $ptLifeDetailConfirm = @(700,600); $ocrKoreanEngine = $null
$script:detailOpen = $false; $script:windowOpen = $false
$script:logs = @(); $script:yieldWaits = 0
$script:confirmSent = 0; $script:closeSent = 0
$script:lastClickPerformed = $false; $script:lastClickSkipReason = ''
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Focus-Game { param($Game) $script:focusCalls++ }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) }
function Get-GameRegionOcrText { param($Game,$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight,$Scale,$Engine) if ($script:detailOpen) { '채집물:갑옷나무' } else { '' } }
function Test-LifeDetailHasLabel { param([string]$Text) $Text.Contains('집물') }
function Test-LifeWindowOpen { param($Game) $script:windowOpen }
function Test-LifeInfoScreen { param($Game) $false }

$script:activeSeq = @(); $script:activeIdx = 0
$script:sendSeq = @();   $script:sendIdx = 0
function Test-UserRecentlyActive {
  if ($script:activeIdx -lt $script:activeSeq.Count) { $v = $script:activeSeq[$script:activeIdx]; $script:activeIdx++; return $v }
  return $false
}
function Wait-UserYieldEnd { param($Game, $Context) $script:yieldWaits++; $script:userYieldTotalMs += 3000 }
function Invoke-ClickModel {
  param([string]$Kind)
  $r = 'sent'
  if ($script:sendIdx -lt $script:sendSeq.Count) { $r = $script:sendSeq[$script:sendIdx]; $script:sendIdx++ }
  $script:lastClickPerformed = ($r -eq 'sent')
  $script:lastClickSkipReason = if ($r -eq 'sent') { '' } else { $r }
  if ($r -eq 'sent') {
    if ($Kind -eq 'confirm') { $script:confirmSent++; $script:detailOpen = $false }
    # 상세 팝업은 모달 - 팝업이 남아 있으면 X 는 전송돼도 창을 닫지 못합니다 (구현 리뷰 지적:
    # 이 조건이 없으면 '확인 미전송 → X 가 막힘' 시나리오가 재현되지 않음)
    else { $script:closeSent++; if (-not $script:detailOpen) { $script:windowOpen = $false } }
  }
}
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) Invoke-ClickModel -Kind 'confirm' }
function Invoke-LifeWindowCloseClick { param($Game) Invoke-ClickModel -Kind 'close' }

function Reset-Case {
  param([bool]$Detail = $false, [bool]$Window = $true, $ActiveSeq = @(), $SendSeq = @())
  $script:detailOpen = $Detail; $script:windowOpen = $Window
  $script:logs = @(); $script:yieldWaits = 0; $script:focusCalls = 0
  $script:confirmSent = 0; $script:closeSent = 0
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타 - 회전 서두에서 비워야 함
  $script:userYieldTotalMs = [double]0
  $script:activeIdx = 0; $script:activeSeq = @($ActiveSeq)
  $script:sendIdx = 0;   $script:sendSeq = @($SendSeq)
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }

# ── 1. 기준 동작 ─────────────────────────────────────────────────────────────
Reset-Case -Window $true
$r = Close-LifeOpenWindows -Game $game
Check-Equal '창만 열림: X 1회로 닫힘' $script:closeSent 1
Check-Equal '창만 열림: 반환 참(전송함)' $r $true
Check-Equal '창만 열림: 로그 1회차' (Count-Log '닫기\(X\) - 1 회차') 1

Reset-Case -Window $false
$r = Close-LifeOpenWindows -Game $game
Check-Equal '아무것도 없음: 클릭 0, 반환 거짓' ("$($script:closeSent)/$r") '0/False'
Check-Equal '아무것도 없음: 잔존 user-active 메타로 오발동하지 않음' $script:yieldWaits 0

Reset-Case -Detail $true -Window $true
$r = Close-LifeOpenWindows -Game $game
Check-Equal '팝업+창: 확인 1회 → X 1회 순서' ("$($script:confirmSent)/$($script:closeSent)") '1/1'

# ── 2. X 루프: user-active 는 시도를 쓰지 않는다 ────────────────────────────
#    생략 3회 뒤 전송 → 예전엔 2회째 생략에서 예산 소진 + '커서 확인이 안 돼' 로그 2줄 + 창 잔존.
Reset-Case -Window $true -SendSeq @('user-active','user-active','user-active','sent')
$r = Close-LifeOpenWindows -Game $game
Check-Equal 'X 경합 백업: 생략 3회 뒤에도 닫힘' $script:closeSent 1
Check-Equal 'X 경합 백업: 생략마다 양보 대기' $script:yieldWaits 3
Check-Equal 'X 경합 백업: 전송된 시도만 1 회차' (Count-Log '닫기\(X\) - 1 회차') 1
Check-Equal 'X 경합 백업: 사유가 사용자 조작으로 기록' (Count-Log '사용자 조작으로 창 닫기\(X\) 클릭을 취소') 3
Check-Equal 'X 경합 백업: 커서 미확인 로그 없음' (Count-Log '커서 확인이 안 돼 창 닫기') 0

#    사전 게이트: 루프 머리에서 조작이 잡히면 Focus-Game 도 클릭도 없이 기다린다.
#    ★ 확인 루프의 게이트가 먼저 시퀀스를 소비하므로, X 게이트를 보려면 첫 값은 $false 여야 합니다
#      (구현 리뷰 지적: @($true,$true,$false) 는 전부 확인 루프에서 소비돼 X 게이트를 Focus-Game 뒤로
#       옮긴 변이도 통과했음). 확인 게이트는 아래 별도 케이스가 봅니다.
Reset-Case -Window $true -ActiveSeq @($false,$true,$true,$false)
$r = Close-LifeOpenWindows -Game $game
Check-Equal 'X 사전 게이트: 조작 2회 양보 후 닫힘' ("$($script:yieldWaits)/$($script:closeSent)") '2/1'
Check-Equal 'X 사전 게이트: 게이트가 잡은 회전에는 전면화 시도 없음(Focus 1회 = 클릭 회전만)' $script:focusCalls 1
#    확인 루프의 사전 게이트도 같은 계약
Reset-Case -Detail $true -Window $false -ActiveSeq @($true,$true,$false)
$r = Close-LifeOpenWindows -Game $game
Check-Equal '확인 사전 게이트: 조작 2회 양보 후 확인 전송' ("$($script:yieldWaits)/$($script:confirmSent)") '2/1'
Check-Equal '확인 사전 게이트: Focus 는 클릭 회전 1회만' $script:focusCalls 1

# ── 3. X 루프: cursor-not-ready 는 기존대로 시도를 쓴다 ────────────────────
Reset-Case -Window $true -SendSeq @('cursor-not-ready','cursor-not-ready','sent')
$r = Close-LifeOpenWindows -Game $game
Check-Equal '커서 미확인: 2회로 예산 소진, 3번째 전송 없음' $script:closeSent 0
Check-Equal '커서 미확인: 양보 대기 없음' $script:yieldWaits 0
Check-Equal '커서 미확인: 회차 소모 로그 1·2' ((Count-Log '건너뜀 - 1 회차') + (Count-Log '건너뜀 - 2 회차')) 2
Check-Equal '커서 미확인: 창 잔존 경고' (Count-Log '2회 후에도 창이 남아') 1
Check-Equal '커서 미확인: 반환 거짓(전송한 입력 없음)' $r $false

# ── 4. 상세 팝업 확인: user-active 는 상한 없이 기다렸다 상세 OCR 부터 ─────────
#    취소 3회 뒤 전송. 예전엔 취소돼도 '확인 클릭' 로그 + $closed 참 + 팝업 잔존 → X 가 모달에 막힘.
Reset-Case -Detail $true -Window $true -SendSeq @('user-active','user-active','user-active','sent','sent')
$r = Close-LifeOpenWindows -Game $game
Check-Equal '확인 취소 3회: 그래도 확인이 전송됨(상한 없음)' $script:confirmSent 1
Check-Equal '확인 취소 3회: 취소마다 양보 대기' $script:yieldWaits 3
Check-Equal '확인 취소 3회: 취소된 클릭은 확인 로그를 남기지 않음' (Count-Log '상세 팝업 확인 클릭$') 1
Check-Equal '확인 취소 3회: 팝업이 닫힌 뒤 X 도 닫힘' $script:closeSent 1

#    사용자가 양보 중 팝업을 직접 닫았으면 재판독에서 라벨이 사라져 추가 확인 클릭 없이 X 단계로
Reset-Case -Detail $true -Window $true -SendSeq @('user-active','sent')
function Wait-UserYieldEnd { param($Game, $Context) $script:yieldWaits++; $script:detailOpen = $false }   # 양보 중 사용자가 닫음
$r = Close-LifeOpenWindows -Game $game
Check-Equal '확인 취소 후 사용자가 닫음: 재판독이 잡아 확인 재클릭 없음' $script:confirmSent 0
Check-Equal '확인 취소 후 사용자가 닫음: X 는 정상 진행' $script:closeSent 1
function Wait-UserYieldEnd { param($Game, $Context) $script:yieldWaits++; $script:userYieldTotalMs += 3000 }

#    cursor-not-ready 는 1회로 끝내고 X 단계로 (무제한 재시도로 확대하지 않음)
#    합의된 한계: 팝업이 남은 채 X 단계로 내려가면 X 는 모달에 막혀 예산 2회를 소모하고 경고로 끝납니다
Reset-Case -Detail $true -Window $true -SendSeq @('cursor-not-ready','sent','sent')
$r = Close-LifeOpenWindows -Game $game
Check-Equal '확인 커서 미확인: 1회로 끝내고 X 단계로 (X 전송 2회, 모달에 막힘)' ("$($script:confirmSent)/$($script:closeSent)") '0/2'
Check-Equal '확인 커서 미확인: 팝업·창 잔존 + 경고' (($script:detailOpen -and $script:windowOpen) -and ((Count-Log '2회 후에도 창이 남아') -eq 1)) $true
Check-Equal '확인 커서 미확인: 사유 로그' (Count-Log '커서 확인이 안 돼 상세 팝업 확인') 1

# ── 5. 반환값 = 전송 여부 (미전송만으로 참이 되지 않음) ─────────────────────
Reset-Case -Detail $true -Window $false -SendSeq @('cursor-not-ready')
$r = Close-LifeOpenWindows -Game $game
Check-Equal '반환값: 확인 미전송 + 창 없음 → 거짓' $r $false

# ── 6. 소스 구조 단언 (주석 제거본) ───────────────────────────────────────────
$body = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Close-LifeOpenWindows'))
$code = (($body -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Check-Equal '구조: X 루프가 전송된 시도로 센다' ($code -match 'while \(\$sentTries -lt 2\)') $true
Check-Equal '구조: 두 루프 모두 회전 머리에서 사유 메타를 비움' ([regex]::Matches($code, '\$script:lastClickSkipReason = ''''').Count) 2
Check-Equal '구조: 두 루프 모두 사전 게이트' ([regex]::Matches($code, 'if \(Test-UserRecentlyActive\) \{').Count) 2
Check-Equal '구조: 되돌림은 user-active 만 (cursor-not-ready 는 소모)' ([regex]::Matches($code, "lastClickSkipReason -eq 'user-active'").Count) 2
Check-Equal '구조: Focus-Game 유지(AutoRefocus 치환 금지)' (($code -match 'Focus-Game -Game \$Game') -and ($code -notmatch 'Invoke-AutoRefocus')) $true
Check-Equal '구조: 확인·X 예산·좌표 계약 유지(1.2초 재판독 대기)' ($code -match 'Start-Sleep -Milliseconds 1200') $true

exit $fails
