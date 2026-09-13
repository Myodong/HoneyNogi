# 마지막 판 '나가기'의 사용자 조작 양보 계약 (2026-09-13)
#
# 09-09 전수 감사 잔여의 마지막 던전 자리. 첫 클릭·재클릭 모두 전송 확인이 없어 취소돼도 '나가며
# 마칩니다'를 기록했고, 40초 마감에 양보가 반영되지 않았습니다. 여기서 고정하는 계약(설계 합의):
#   첫 클릭: 전송 → 로그 / user-active → 기다린 뒤 확인 루프 진입 / cursor-not-ready → 사유 로그 후 루프
#   루프: 판독 뒤·분기 전 게이트(Space·wait 경로는 클릭 메타에 안 잡힘) → 양보 후 전체 재판독, 증거 연속 리셋
#   재클릭: 'reclick' 판정(결과 화면 잔존)일 때만, 전송 확인, user-active 면 양보
#   40초 마감은 양보 차분만큼 연장 (Get-YieldAdjustedDeadline), 캡처 실패 재설정 시 기준값 갱신
#   완료 마커·은동전 순서·실패 래치·필드 증거 2연속·미확인 시 exit 0 은 불변 (test_last_run_exit 가 봄)
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
function Find-GameTextPoint { param($Game,$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight,$SearchText,$ExactText) if ($script:screen -eq 'result') { [pscustomobject]@{ X = 480; Y = 660 } } else { $null } }
function Find-DgRetryButtonPoint { param($Game) if ($script:screen -eq 'result') { [pscustomobject]@{ X = 640; Y = 660 } } else { $null } }
function Test-HomeEndEscHud { param($Game) $script:screen -eq 'field' }
function Get-GameRegionOcrText { param($Game,$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight,$Scale,$Engine) if ($script:screen -eq 'field') { '주간목표' } else { '심층2층1구역클리어' } }
function Get-GameOcrText { param($Game) if ($script:screen -eq 'popup') { '던전탐험을계속하시겠습니까' } else { '' } }

$script:activeSeq = @(); $script:activeIdx = 0
$script:sendSeq = @();   $script:sendIdx = 0
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
  # 실제로 전송된 '나가기'만 화면을 바꿉니다 (결과 → 필드)
  if ($r -eq 'sent') { $script:clicksSent++; if ($script:screen -eq 'result') { $script:screen = 'field' } }
}
function Click-ScreenPoint { param($X, $Y) Invoke-ClickModel }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) Invoke-ClickModel }

function Reset-Case {
  param([string]$Screen = 'result', $ActiveSeq = @(), $SendSeq = @(), [int]$YieldMs = 3000)
  $script:vclock = [datetime]'2026-01-01 00:00:00'
  $script:screen = $Screen; $script:screenAfterYield = $null
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

# ── 2. 첫 클릭이 user-active 로 취소 → 기다린 뒤 루프의 reclick 이 다시 누름 ─────
Reset-Case -SendSeq @('user-active', 'sent')
Run-Block
Check-Equal '첫 클릭 취소: 옛 "나가며 마칩니다" 로그 없음' (Count-Log '나가며 자동화를 마칩니다') 0
Check-Equal '첫 클릭 취소: 사유 로그 + 양보 1회' ("$((Count-Log '사용자 조작으로 .나가기. 클릭을 취소'))/$($script:yieldWaits)") '1/1'
Check-Equal '첫 클릭 취소: 루프의 reclick 으로 전송 1회 → 완료' ("$($script:clicksSent)/$($script:exitCode)") '1/0'
Check-Equal '첫 클릭 취소: 재클릭 로그는 전송된 것만' (Count-Log "다시 클릭했습니다") 1

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

# ── 5. ★ 판독 뒤 게이트: 조작 중에는 분기(Space/재클릭)로 내려가지 않고 증거 연속 리셋 ──
#    탐험 계속 팝업 + 조작 중 → Space 가 나가면 안 됨 → 조작 끝난 뒤 Space → 필드
Reset-Case -Screen 'popup' -ActiveSeq @($true, $true, $false)
Run-Block
Check-Equal '게이트: 조작 중 2회전은 Space 없이 양보' ("$($script:yieldWaits)/$($script:spacePresses)") '2/1'
Check-Equal '게이트: 그 뒤 Space 로 나가기 선택 → 완료' ("$((Count-Log '나가기\(Space\) 선택'))/$($script:exitCode)") '1/0'
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

# ── 9. 소스 구조 단언 (주석 제거본) ─────────────────────────────────────────────
$code = (($blockText -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Check-Equal '구조: 첫 클릭·루프 서두에서 사유 메타 초기화 2곳' ([regex]::Matches($code, "\`$script:lastClickSkipReason = ''").Count) 2
Check-Equal '구조: 마감 조건식이 양보 차분 반영' ($code -match 'while \(\(Get-Date\) -lt \(Get-YieldAdjustedDeadline -Deadline \(\[ref\]\$fieldDeadline\) -SeenYieldMs \(\[ref\]\$fieldSeenYieldMs\)\)\)') $true
Check-Equal '구조: 캡처 실패 재설정 시 기준값 갱신' ([regex]::Matches($code, '\$fieldSeenYieldMs = \[double\]\$script:userYieldTotalMs').Count) 2
Check-Equal '구조: 판독 뒤·분기 전 게이트 (probeFailed 검사 다음, exitStep 앞)' ($code -match '(?s)if \(\$probeFailed\) \{ continue \}\s*if \(Test-UserRecentlyActive\) \{.{0,200}?\$fieldStreak = 0.{0,40}?continue.{0,40}?\}\s*\$exitStep = Get-DgLastRunExitStep') $true
Check-Equal '구조: 양보 되돌림은 user-active 만 (cursor-not-ready 는 소모)' ([regex]::Matches($code, "lastClickSkipReason -eq 'user-active'").Count) 2
Check-Equal '구조: 옛 무조건 로그 문구 없음' ($code -notmatch '나가며 자동화를 마칩니다') $true

exit $fails
