# 마지막 판 '나가기'의 사용자 조작 양보 계약 (2026-09-13)
#
# 09-09 전수 감사 잔여의 마지막 던전 자리. 첫 클릭·재클릭 모두 전송 확인이 없어 취소돼도 '나가며
# 마칩니다'를 기록했고, 40초 마감에 양보가 반영되지 않았습니다. 여기서 고정하는 계약(설계 합의):
#   첫 클릭: 전송 → 로그 / user-active → 기다린 뒤 확인 루프 진입 / cursor-not-ready → 사유 로그 후 루프
#   루프: 판독 뒤·분기 전 게이트(Space·wait 경로는 클릭 메타에 안 잡힘) → 양보 후 전체 재판독, 증거 연속 리셋
#   재클릭: 'reclick' 판정(결과 화면 잔존)일 때만, 전송 확인, user-active 면 양보
#   40초 마감은 양보 차분만큼 연장 (Get-YieldAdjustedDeadline), 캡처 실패 재설정 시 기준값 갱신
#   완료 마커·은동전 순서·실패 래치·필드 증거 2연속·미확인 시 exit 0 은 불변 (test_last_run_exit 가 봄)
#   'wait' 회전의 블로커 스윕 (2026-09-13 14:22 관측 - 나가기 뒤 필드 위 구매 팝업이 HUD 를 가려 40초 경고):
#     아무 화면도 인식 못 한 회전에만 Invoke-PurchasePopupSweep, 닫으면 continue 로 재판독. 결과/필드/탐험 팝업 회전에는
#     호출하지 않음(호출 위치 카운터로 단언). 'continue 제거' 변이는 루프 끝이라 행동이 같아 구조 단언으로만 고정.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-DgLastRunExitStep', 'Get-YieldAdjustedDeadline')) {
  Invoke-Expression $definition
}

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

# ── 운영 코드 추출: 최상위 흐름의 `if ($script:dgLastRun -and -not $script:customCleanupOnly) { … }` 블록 ──
# 함수가 아니라 AST 로 그 if 문을 그대로 잘라 실행합니다 (사본 재구현 금지 - test_party_find_yield 선례).
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$tokens, [ref]$parseErrors)
$lastRunIf = $ast.Find({
    param($n)
    $n -is [System.Management.Automation.Language.IfStatementAst] -and
    $n.Clauses[0].Item1.Extent.Text -eq '$script:dgLastRun -and -not $script:customCleanupOnly'
  }, $true)
if (-not $lastRunIf) { 'FAIL 마지막 판 나가기 if 블록을 찾지 못했습니다'; exit 1 }
# 블록 끝의 `exit 0` 은 테스트 프로세스를 죽이므로 결과 기록으로 바꿉니다 (그 자리 하나뿐)
$blockText = $lastRunIf.Extent.Text
Check-Equal '추출: 블록 안 exit 0 은 정확히 1곳' ([regex]::Matches($blockText, '(?m)^\s*exit 0\s*$').Count) 1
$blockText = $blockText -replace '(?m)^(\s*)exit 0\s*$', '$1$script:exitCode = 0'
$lastRunBlock = [scriptblock]::Create($blockText)

# ── 모의: 가상 시계 + 화면 상태 + 클릭 결과 시퀀스 ───────────────────────────────
$script:vclock = [datetime]'2026-01-01 00:00:00'
function Get-Date { return $script:vclock }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) $ms = $Milliseconds; if ($Seconds) { $ms = $Seconds * 1000 }; $script:vclock = $script:vclock.AddMilliseconds($ms) }
function Focus-Game { param($Game) }
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Test-SafeStopDuringCaptureFail {}
function Test-CaptureRecovered { param($Game) $script:screenCaptureFailing = $false; $true }
function Write-DgStageDiagnostics { param($Game, $Context, $MapKind) $script:diagCalls++ }
function Press-KeyOnce { param($VirtualKey) $script:spacePresses++; if ($script:screen -eq 'popup') { $script:screen = 'field' } }
$script:contentTag = '[심층]'
$ptDgResultExit = @(470, 655); $rgQuestTracker = @(1,1,1,1); $ocrKoreanEngine = $null
$script:customCleanupOnly = $false

# 화면: 'result'(결과 화면, 나가기 버튼 보임) / 'popup'(탐험 계속 팝업) / 'field'(필드) / 'loading'(아무것도 아님)
#       / 'purchase'(필드 위 구매 팝업 - 14:22 캡처 재현: HUD 미탐·재시도 미탐·중앙 문구에 탐험/계속하 없음 = 'wait')
function Find-GameTextPoint { param($Game,$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight,$SearchText,$ExactText) if ($script:screen -eq 'result') { [pscustomobject]@{ X = 480; Y = 660 } } else { $null } }
function Find-DgRetryButtonPoint { param($Game) if ($script:screen -eq 'result') { [pscustomobject]@{ X = 640; Y = 660 } } else { $null } }
function Test-HomeEndEscHud { param($Game) $script:screen -eq 'field' }
function Get-GameRegionOcrText { param($Game,$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight,$Scale,$Engine) if ($script:screen -eq 'field') { '주간목표' } elseif ($script:screen -eq 'purchase') { '' } else { '심층2층1구역클리어' } }
function Get-GameOcrText { param($Game) if ($script:screen -eq 'popup') { '던전탐험을계속하시겠습니까' } else { '' } }

$script:activeSeq = @(); $script:activeIdx = 0
$script:sendSeq = @();   $script:sendIdx = 0
$script:sweepSeq = @();  $script:sweepIdx = 0
# 구매 팝업 스윕 모의: 'purchase' 일 때만 팝업을 처리합니다. 전송이면 닫고 'field' 로(+1초 - 소스의 클릭 후 1초 대기),
# user-active 면 소스 계약(Wait-UserYieldEnd 뒤 즉시 $true, 화면 유지). 그 외 화면은 $false + 가상 시계 불변
# (기존 '경과 40초대' 단언이 그대로 살아야 함). 호출 시점의 화면을 기록해 '어느 회전에서 불렸나'를 단언합니다.
function Invoke-PurchasePopupSweep {
  param($Game)
  $script:sweepCalls++; $script:sweepScreens += $script:screen
  if ($script:screen -ne 'purchase') { return $false }
  $r = 'sent'
  if ($script:sweepIdx -lt $script:sweepSeq.Count) { $r = $script:sweepSeq[$script:sweepIdx]; $script:sweepIdx++ }
  if ($r -eq 'user-active') { Wait-UserYieldEnd -Game $Game -Context '구매 팝업 닫기'; return $true }
  $script:vclock = $script:vclock.AddSeconds(1); $script:screen = 'field'; $script:sweepClosed++
  return $true
}
function Test-UserRecentlyActive {
  if ($script:activeIdx -lt $script:activeSeq.Count) { $v = $script:activeSeq[$script:activeIdx]; $script:activeIdx++; return [bool]$v }
  return $false
}
function Wait-UserYieldEnd {
  param($Game, $Context)
  $script:yieldWaits++; $script:yieldContexts += $Context
  $script:vclock = $script:vclock.AddMilliseconds($script:yieldMs)
  $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $script:yieldMs
  if ($script:screenAfterYield) { $script:screen = $script:screenAfterYield; $script:screenAfterYield = $null }
}
function Invoke-ClickModel {
  $r = 'sent'
  if ($script:sendIdx -lt $script:sendSeq.Count) { $r = $script:sendSeq[$script:sendIdx]; $script:sendIdx++ }
  $script:lastClickPerformed = ($r -eq 'sent')
  $script:lastClickSkipReason = if ($r -eq 'sent') { '' } else { $r }
  # 실제로 전송된 '나가기'만 화면을 바꿉니다 (결과 → 필드. 'purchase' 로 지정하면 필드에 팝업이 덮인 상태)
  if ($r -eq 'sent') { $script:clicksSent++; if ($script:screen -eq 'result') { $script:screen = $script:screenAfterExit } }
}
function Click-ScreenPoint { param($X, $Y) Invoke-ClickModel }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) Invoke-ClickModel }

function Reset-Case {
  param([string]$Screen = 'result', $ActiveSeq = @(), $SendSeq = @(), [int]$YieldMs = 3000, [string]$ScreenAfterExit = 'field', $SweepSeq = @())
  $script:vclock = [datetime]'2026-01-01 00:00:00'
  $script:screen = $Screen; $script:screenAfterYield = $null; $script:screenAfterExit = $ScreenAfterExit
  $script:sweepCalls = 0; $script:sweepScreens = @(); $script:sweepClosed = 0
  $script:sweepIdx = 0;  $script:sweepSeq = @($SweepSeq)
  $script:logs = @(); $script:yieldWaits = 0; $script:yieldContexts = @(); $script:clicksSent = 0; $script:spacePresses = 0; $script:diagCalls = 0
  $script:exitCode = $null
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타 - 서두 초기화로 무해해야 함
  $script:userYieldTotalMs = [double]0; $script:screenCaptureFailing = $false
  $script:yieldMs = $YieldMs
  $script:activeIdx = 0; $script:activeSeq = @($ActiveSeq)
  $script:sendIdx = 0;   $script:sendSeq = @($SendSeq)
  $script:dgLastRun = $true
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }
function Run-Block { & $lastRunBlock }
function Elapsed { ($script:vclock - [datetime]'2026-01-01 00:00:00').TotalSeconds }

# ── 1. 기준: 조작 없음 → 1클릭, 필드 2연속, 회차 완료 ──────────────────────────
Reset-Case
Run-Block
Check-Equal '기준: 나가기 1클릭으로 필드 복귀' ("$($script:clicksSent)/$($script:exitCode)") '1/0'
Check-Equal '기준: 전송된 클릭에만 클릭 로그' (Count-Log "'나가기' 클릭 - 필드 복귀를 확인합니다") 1
Check-Equal '기준: 필드 복귀 확인 로그' (Count-Log '필드 복귀 확인 - 회차 완료') 1
Check-Equal '기준: 잔존 user-active 메타로 오발동 없음(양보 0)' $script:yieldWaits 0
Check-Equal '기준: 필드 회전에서는 스윕을 부르지 않음' $script:sweepCalls 0

# ── 2. 첫 클릭이 user-active 로 취소 → 기다린 뒤 루프의 reclick 이 다시 누름 ─────
Reset-Case -SendSeq @('user-active', 'sent')
Run-Block
Check-Equal '첫 클릭 취소: 옛 "나가며 마칩니다" 로그 없음' (Count-Log '나가며 자동화를 마칩니다') 0
Check-Equal '첫 클릭 취소: 사유 로그 + 양보 1회' ("$((Count-Log '사용자 조작으로 .나가기. 클릭을 취소'))/$($script:yieldWaits)") '1/1'
Check-Equal '첫 클릭 취소: 루프의 reclick 으로 전송 1회 → 완료' ("$($script:clicksSent)/$($script:exitCode)") '1/0'
Check-Equal '첫 클릭 취소: 재클릭 로그는 전송된 것만' (Count-Log "다시 클릭했습니다") 1
Check-Equal '첫 클릭 취소: 결과 화면(reclick) 회전에서는 스윕을 부르지 않음' $script:sweepCalls 0

# ── 3. 첫 클릭 cursor-not-ready → 사유 로그, 기다리지 않고 루프에서 재시도 ─────────
Reset-Case -SendSeq @('cursor-not-ready', 'sent')
Run-Block
Check-Equal '커서 미확인: 사유 로그 + 양보 없음' ("$((Count-Log '커서 확인이 안 돼 .나가기. 클릭을 건너뜀'))/$($script:yieldWaits)") '1/0'
Check-Equal '커서 미확인: 루프에서 재클릭해 완료' ("$($script:clicksSent)/$($script:exitCode)") '1/0'

# ── 4. ★ 40초를 넘는 양보에도 초과로 끝나지 않음 (마감 연장) ─────────────────────
#    첫 클릭 취소 + 50초 양보 → 마감은 그 뒤에 잡힘 → 루프 첫 회전에 reclick 전송 → 완료
Reset-Case -SendSeq @('user-active', 'sent') -YieldMs 50000
Run-Block
Check-Equal '긴 양보(50초): 첫 클릭 앞 양보는 마감에 안 들어가 정상 완료' ("$($script:clicksSent)/$($script:exitCode)/$($script:diagCalls)") '1/0/0'
#    루프 안 게이트 양보 50초 (판독은 되지만 조작 중) → 연장 → 조작 끝난 뒤 reclick → 완료
Reset-Case -ActiveSeq @($true) -SendSeq @('user-active', 'sent') -YieldMs 50000
Run-Block
Check-Equal '긴 양보(루프 안 50초): 마감 연장으로 초과 없이 완료' ("$($script:exitCode)/$($script:diagCalls)") '0/0'
Check-Equal '긴 양보(루프 안): 게이트 문맥으로 기다림' (@($script:yieldContexts | Where-Object { $_ -eq '마지막 판 필드 복귀 확인' }).Count) 1
#    대조: 양보 없이 화면이 영영 안 바뀌면 기존대로 40초 뒤 경고 종료 (연장이 무한 대기를 만들지 않음)
Reset-Case -Screen 'loading'
Run-Block
Check-Equal '대조: 양보 없는 미확인은 40초 뒤 진단 + 경고 + exit 0' ("$($script:diagCalls)/$((Count-Log '필드 복귀를 확인하지 못했습니다'))/$($script:exitCode)") '1/1/0'
Check-Equal '대조: 경과가 40초대(연장 없음)' ((Elapsed) -ge 40 -and (Elapsed) -lt 46) $true
Check-Equal '대조: 인식 못 한(wait) 회전마다 스윕을 불렀고 전부 무팝업($false)' (($script:sweepCalls -ge 10) -and ($script:sweepClosed -eq 0)) $true

# ── 5. ★ 판독 뒤 게이트: 조작 중에는 분기(Space/재클릭)로 내려가지 않고 증거 연속 리셋 ──
#    탐험 계속 팝업 + 조작 중 → Space 가 나가면 안 됨 → 조작 끝난 뒤 Space → 필드
Reset-Case -Screen 'popup' -ActiveSeq @($true, $true, $false)
Run-Block
Check-Equal '게이트: 조작 중 2회전은 Space 없이 양보' ("$($script:yieldWaits)/$($script:spacePresses)") '2/1'
Check-Equal '게이트: 그 뒤 Space 로 나가기 선택 → 완료' ("$((Count-Log '나가기\(Space\) 선택'))/$($script:exitCode)") '1/0'
Check-Equal '게이트: 탐험 팝업(popup-exit) 회전에서는 스윕을 부르지 않음' $script:sweepCalls 0
#    필드 증거 1회 뒤 조작 → 연속이 리셋돼 2연속을 다시 채워야 확정
Reset-Case -Screen 'field' -ActiveSeq @($false, $true, $false, $false)
Run-Block
Check-Equal '게이트: 증거 1회 뒤 양보 → 연속 리셋 → 이후 2연속으로 확정' ("$($script:yieldWaits)/$($script:exitCode)") '1/0'
Check-Equal '게이트: 리셋 때문에 회전이 4회 이상 (2초 간격)' ((Elapsed) -ge 8) $true

# ── 6. 양보 중 사용자가 직접 필드로 나간 경우: 재클릭 없이 필드 확정 ──────────────
Reset-Case -Screen 'result' -SendSeq @('user-active')
$script:screenAfterYield = 'field'
Run-Block
Check-Equal '양보 중 사용자가 나감: 재클릭 0 + 필드 확정' ("$($script:clicksSent)/$($script:exitCode)") '0/0'

# ── 7. 재클릭 경합: 게이트는 지났는데 재클릭이 취소 → 기다린 뒤 다음 회전 ────────
Reset-Case -SendSeq @('cursor-not-ready', 'user-active', 'sent')
Run-Block
Check-Equal '재클릭 경합: 취소된 재클릭은 로그 없이 양보 → 다음 회전에 전송' ("$((Count-Log '다시 클릭했습니다'))/$($script:yieldWaits)/$($script:clicksSent)") '1/1/1'
Check-Equal '재클릭 경합: 재클릭 문맥으로 기다림' (@($script:yieldContexts | Where-Object { $_ -like "*재클릭*" }).Count) 1

# ── 8. 캡처 실패 재설정 시 기준값 갱신 (과거 양보 중복 가산 없음) ───────────────────
# 리뷰 지적: 양보가 재설정 **뒤**에 오면 중복 가산을 검증하지 못한다 → 복구 탐침 **안에서** 30초 양보를
# 누적한 뒤 마감이 재설정되는 순서로. 기준값 갱신이 없으면 그 30초가 새 마감에 또 더해져 경과가 70초를 넘는다.
Reset-Case -Screen 'loading' -YieldMs 30000
$script:screenCaptureFailing = $true
function Test-CaptureRecovered { param($Game)
  # 탐침 안의 커서 대피 양보를 모형화: 이 회전에서 30초 양보가 누적된 뒤 캡처가 복구됨
  $script:vclock = $script:vclock.AddMilliseconds(30000); $script:userYieldTotalMs = [double]$script:userYieldTotalMs + 30000
  $script:screenCaptureFailing = $false; $true }
Run-Block
# 산식: 탐침 30초(양보) + 재설정 뒤 40초 + 폴링 2초 = 72초. 기준값 갱신이 없으면 그 30초가 새 마감에 또
# 붙어 102초가 된다 - 경계 80 은 두 값 사이(실측 72 / 결함 102).
Check-Equal '캡처 실패 재설정: 탐침 안 30초 양보가 새 마감에 또 더해지지 않음 (경과 72 < 80, 결함이면 102)' ((Elapsed) -lt 80) $true
Check-Equal '캡처 실패 재설정: 재설정 뒤 40초 안에 미확인 종료' ("$($script:diagCalls)/$($script:exitCode)") '1/0'
function Test-CaptureRecovered { param($Game) $script:screenCaptureFailing = $false; $true }

# ── 10. ★ 'wait' 회전의 블로커 스윕 (2026-09-13 14:22 관측 재현) ────────────────────
#    나가기 전송 → 필드에 도착했지만 구매 팝업이 덮음('purchase') → HUD 미탐이라 'wait' → 스윕이 닫음 → 필드 2연속 → 완료
Reset-Case -ScreenAfterExit 'purchase'
Run-Block
Check-Equal '팝업 가림: 스윕 1회로 닫고 필드 확정 (exit 0, 진단 0)' ("$($script:sweepClosed)/$($script:exitCode)/$($script:diagCalls)") '1/0/0'
Check-Equal '팝업 가림: 스윕은 purchase 회전에서만 불림 (result/field 회전 0)' (@($script:sweepScreens | Where-Object { $_ -ne 'purchase' }).Count) 0
Check-Equal '팝업 가림: 40초 안에 완료' ((Elapsed) -lt 40) $true
Check-Equal '팝업 가림: 옛 경고 없음' (Count-Log '필드 복귀를 확인하지 못했습니다') 0
#    스윕의 닫기 클릭이 user-active 로 취소 → 함수가 50초 기다린 뒤 $true → continue → 마감 연장 → 다음 회전 재스윕 → 완료
#    (양보 50초는 40초 잔여 예산을 넘어야 연장 여부가 판정을 가릅니다 - 케이스 4 와 같은 이유)
Reset-Case -ScreenAfterExit 'purchase' -SweepSeq @('user-active', 'sent') -YieldMs 50000
Run-Block
Check-Equal '스윕 취소(50초 양보): 마감 연장으로 초과 없이 재스윕 → 완료' ("$($script:sweepClosed)/$($script:exitCode)/$($script:diagCalls)") '1/0/0'
Check-Equal '스윕 취소: 양보 1회(스윕 안) + 재클릭 없음(팝업 회전은 reclick 이 아님)' ("$($script:yieldWaits)/$($script:clicksSent)") '1/1'
#    대조: 스윕이 팝업을 못 닫으면(전송 0) 기존대로 40초 뒤 경고 종료 - 스윕이 무한 대기를 만들지 않음
Reset-Case -ScreenAfterExit 'purchase' -SweepSeq @(@('user-active') * 20) -YieldMs 1000
Run-Block
Check-Equal '대조: 취소만 반복돼 못 닫으면 40초(+양보) 뒤 경고 종료' ("$($script:diagCalls)/$($script:exitCode)/$($script:sweepClosed)") '1/0/0'
#    산식: 회전마다 폴링 2초 + 양보 1초, 마감은 양보만큼만 연장 → 3n ≥ 40 + n → n = 20 회전, 경과 60초 중 양보 20초.
#    리뷰 지적: 위 단언만으로는 '양보를 절반만 연장'하는 변이(16회·48초 종료)도 통과 → 벽시계 예산이 정확히 40초임을 못 박음.
Check-Equal '대조: 벽시계 예산은 정확히 40초 (경과 60 − 양보 20), 양보 20회' ("$((Elapsed) - $script:userYieldTotalMs / 1000)/$($script:yieldWaits)") '40/20'

# ── 9. 소스 구조 단언 (주석 제거본) ─────────────────────────────────────────────
$code = (($blockText -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Check-Equal '구조: 첫 클릭·루프 서두에서 사유 메타 초기화 2곳' ([regex]::Matches($code, "\`$script:lastClickSkipReason = ''").Count) 2
Check-Equal '구조: 마감 조건식이 양보 차분 반영' ($code -match 'while \(\(Get-Date\) -lt \(Get-YieldAdjustedDeadline -Deadline \(\[ref\]\$fieldDeadline\) -SeenYieldMs \(\[ref\]\$fieldSeenYieldMs\)\)\)') $true
Check-Equal '구조: 캡처 실패 재설정 시 기준값 갱신' ([regex]::Matches($code, '\$fieldSeenYieldMs = \[double\]\$script:userYieldTotalMs').Count) 2
Check-Equal '구조: 판독 뒤·분기 전 게이트 (probeFailed 검사 다음, exitStep 앞)' ($code -match '(?s)if \(\$probeFailed\) \{ continue \}\s*if \(Test-UserRecentlyActive\) \{.{0,200}?\$fieldStreak = 0.{0,40}?continue.{0,40}?\}\s*\$exitStep = Get-DgLastRunExitStep') $true
Check-Equal '구조: 양보 되돌림은 user-active 만 (cursor-not-ready 는 소모)' ([regex]::Matches($code, "lastClickSkipReason -eq 'user-active'").Count) 2
Check-Equal '구조: 옛 무조건 로그 문구 없음' ($code -notmatch '나가며 자동화를 마칩니다') $true
# 'continue 제거' 는 루프 끝이라 행동상 동등 - 형제 루프와 같은 계약(닫은 회전은 재판독)을 구조로만 고정합니다
Check-Equal "구조: 'wait' 전용 스윕 + continue (정확 매치)" ($code -match "(?s)if \(\`$exitStep -eq 'wait'\) \{\s*if \(Invoke-PurchasePopupSweep -Game \`$Game\) \{ continue \}") $true
Check-Equal '구조: 스윕 호출은 블록에 1곳, reclick 분기 뒤' (([regex]::Matches($code, 'Invoke-PurchasePopupSweep').Count -eq 1) -and ($code.IndexOf('Invoke-PurchasePopupSweep') -gt $code.IndexOf("-eq 'reclick'"))) $true

exit $fails
