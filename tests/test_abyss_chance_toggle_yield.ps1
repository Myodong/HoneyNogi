# 어비스 '우연한 만남' 스위치 켜기의 사용자 조작 양보 계약 + "같이 할 동료가 필요합니다" 팝업 복구 (v2.1.10 - 2026-09-16)
#
# 실기 관측(2026-09-16 01:15, 보관 던전이미지\실측기록\20260916_어비스_토글클릭취소_경고후진행_재현\): 스위치 켜기 클릭이
# 조작으로 취소됐는데 전송 여부를 읽지 않고 '켜진 것을 확인하지 못했습니다 - 현재 상태로 진행' → 스위치 꺼진 채 입장하기 →
# 게임의 "같이 할 동료가 필요합니다" 팝업을 모른 채 매칭 대기 300초 초과 오류. 여기서 고정하는 계약 (2026-09-10 합의 ①~④ + 설계 리뷰):
#   ① 조작 취소 → 기다림 → 커서 대피 → 목표 던전 제목 확인 → 토글 재판독 → 사용자가 켰으면 재클릭 0 / 여전히 꺼짐이면 재클릭
#   ② 커서 미확인(전송 0회) → 다시 읽어 on 진행 / unknown 경고 진행 / 여전히 off 만 조건부 정지(exit 4)
#   ③ unknown → 정지로 확대 금지 (경고 진행)   ④ 전송된 클릭의 미확인 → 기존 경고 진행
#   캡처 실패 중에는 정지를 확정하지 않고 재판독 (규칙 15)
#   팝업: 판정은 하단 문구 '만남'+'입장' 두 조각, 복구는 글자 앵커 '만남'→'우연한' 클릭(Space 금지), 입장하기 클릭 확인은 팝업을 종료 조건으로
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
# 순수 함수·복구 함수는 소스에서 그대로
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-AbyssPartyNeededPopupText', 'Invoke-AbyssPartyNeededPopupEnter')) {
  Invoke-Expression $definition
}

# ── 운영 코드 추출: 함께하기 분기 if 문의 `elseif ($abyssMatching -eq '우연한 만남')` 절 본문 (사본 재구현 금지) ──
$ast = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$chanceClause = $null
foreach ($ifAst in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true)) {
  foreach ($clause in $ifAst.Clauses) {
    if ($clause.Item1.Extent.Text -eq "`$abyssMatching -eq '우연한 만남'") { $chanceClause = $clause.Item2; break }
  }
  if ($chanceClause) { break }
}
if (-not $chanceClause) { "FAIL '우연한 만남' 절을 찾지 못했습니다"; exit 1 }
# StatementBlockAst 의 Extent 는 중괄호를 포함 - 그대로 스크립트블록을 만들면 '중첩 블록 리터럴'이 되어 실행되지 않으므로 벗겨냅니다
$clauseText = $chanceClause.Extent.Text.Trim()
$clauseText = $clauseText.Substring(1, $clauseText.Length - 2)
Check-Equal '추출: 절 안 exit 4 는 정확히 2곳 (제목 미확인 / 커서 미확인 전송 실패)' ([regex]::Matches($clauseText, '(?m)^\s*exit 4\s*$').Count) 2
# exit 4 는 테스트 프로세스를 죽이므로 '기록 뒤 즉시 중단'으로 치환 (return = 점소싱된 블록 종료)
$clauseText = $clauseText -replace '(?m)^(\s*)exit 4\s*$', '$1$script:exitCode = 4; return'
$chanceBlock = [scriptblock]::Create($clauseText)

# 매칭 대기(Wait-ForScreen '파티 매칭 완료 후 던전 입장')의 -Condition 블록 - 어비스 쪽(Test-InDungeonQuest 사용)만
$matchCondition = $null
foreach ($cmd in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Wait-ForScreen' }, $true)) {
  $text = $cmd.Extent.Text
  if ($text.Contains("'파티 매칭 완료 후 던전 입장'") -and $text.Contains('Test-InDungeonQuest')) {
    $sb = $cmd.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] } | Select-Object -First 1
    $matchCondition = [scriptblock]::Create($sb.ScriptBlock.EndBlock.Extent.Text)
  }
}
if (-not $matchCondition) { "FAIL 어비스 매칭 대기 -Condition 블록을 찾지 못했습니다"; exit 1 }

# ── 모의 ─────────────────────────────────────────────────────────────────────
$game = $null
$ptAbyssChanceToggle = @(1208, 339); $ptPartyEnter = @(1077, 655); $rgClearExit = @(430, 570, 420, 125)
function Focus-Game { param($Game) }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) }
function Move-CursorOutsideGame { param($Game) $script:parkCalls++ }
function Test-SafeStopDuringCaptureFail { $script:safeStopCalls++ }
function Test-CaptureRecovered { param($Game) $script:probeCalls++; $script:screenCaptureFailing = $false; return $true }   # 복구 탐침 - 실제 계약대로 캡처 성공이 플래그를 풂
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Next-Seq { param([string]$Name, $Default)
  $seq = Get-Variable -Name ($Name + 'Seq') -Scope Script -ValueOnly
  $idx = Get-Variable -Name ($Name + 'Idx') -Scope Script -ValueOnly
  if ($idx -lt $seq.Count) { Set-Variable -Name ($Name + 'Idx') -Scope Script -Value ($idx + 1); return $seq[$idx] }
  return $Default
}
function Get-ChanceToggleState { param($Game, $Point) $script:toggleReads++; return (Next-Seq 'toggle' 'off') }
function Test-UserRecentlyActive { return [bool](Next-Seq 'active' $false) }
function Wait-UserYieldEnd { param($Game, $Context) $script:yieldWaits++; $script:yieldContexts += $Context }
function Test-AbyssDetailTargetConfirmed { param($Game)
  $r = Next-Seq 'title' $true
  # 주의: `$true -eq 'capfail'` 은 PS 형 변환으로 참이 되므로 문자열로 비교 (모의 결함으로 무한 대기했던 자리)
  if ("$r" -eq 'capfail') { $script:screenCaptureFailing = $true; $script:captureFailOnce++; return $false }
  if ("$r" -eq 'throwfail') { $script:screenCaptureFailing = $true; $script:captureFailOnce++; throw '창 좌표 확인 실패 (모의 - 플래그를 세운 뒤 예외)' }
  return [bool]$r
}
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY)
  $r = Next-Seq 'send' 'sent'
  $script:lastClickPerformed = ($r -eq 'sent'); $script:lastClickSkipReason = $(if ($r -eq 'sent') { '' } else { $r })
  if ($r -eq 'sent') { $script:clicksSent++ }
}
function Click-ScreenPoint { param($X, $Y)
  $r = Next-Seq 'send' 'sent'
  $script:lastClickPerformed = ($r -eq 'sent'); $script:lastClickSkipReason = $(if ($r -eq 'sent') { '' } else { $r })
  if ($r -eq 'sent') { $script:clicksSent++ }
}
function Test-PartyDetailScreen { param($Game) return $script:detailVisible }
function Test-AbyssPartyNeededPopup { param($Game) return $script:popupVisible }
function Test-InDungeonQuest { param($Game) return $script:inDungeon }
function Invoke-PurchasePopupSweep { param($Game) return $false }
function Find-GameTextPoint { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText, $ExactText, $Scale, $Engine, [switch]$BinaryWhiteText)
  $script:findRegion = "$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight"
  $script:findWords += $SearchText
  if ($script:anchorWords -contains $SearchText) { return [pscustomobject]@{ X = $(if ($SearchText -eq '만남') { 732 } else { 660 }); Y = 617 } } else { return $null }
}
function Invoke-ClickUntil { param($Game, $Point, $Condition, $SourceCondition, $Description, $TimeoutSeconds, $ReclickEverySeconds, $FallbackPoint, $FallbackCondition)
  # 실제 헬퍼 대신 조건 블록만 평가해 배선을 검사합니다 (입장하기 클릭 확인 단계)
  $script:clickUntilCalls++
  $script:clickUntilCondition = [bool](& $Condition)
  $script:clickUntilSource = [bool](& $SourceCondition)
}
function Reset-Case {
  param($ToggleSeq = @(), $ActiveSeq = @(), $SendSeq = @(), $TitleSeq = @())
  $script:toggleSeq = @($ToggleSeq); $script:toggleIdx = 0
  $script:activeSeq = @($ActiveSeq); $script:activeIdx = 0
  $script:sendSeq = @($SendSeq); $script:sendIdx = 0
  $script:titleSeq = @($TitleSeq); $script:titleIdx = 0
  $script:logs = @(); $script:yieldWaits = 0; $script:yieldContexts = @(); $script:clicksSent = 0; $script:toggleReads = 0
  $script:parkCalls = 0; $script:safeStopCalls = 0; $script:captureFailOnce = 0; $script:probeCalls = 0; $script:exitCode = $null
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타 - 오발동 없어야 함
  $script:screenCaptureFailing = $false
  $script:detailVisible = $true; $script:popupVisible = $false; $script:inDungeon = $false; $script:anchorWords = @('만남', '우연한'); $script:findWords = @()
  $script:abyssPartyPopupAnchorMissLogged = $false
  $script:clickUntilCalls = 0; $script:clickUntilCondition = $null; $script:clickUntilSource = $null
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }
function Run-Clause { . $chanceBlock }   # 점소싱 - 블록 안 대입이 이 스코프에 닿아야 함 (규칙 3)

# ── 1. 기준: 꺼짐 → 클릭 전송 → 켬 확인 ──
Reset-Case -ToggleSeq @('off', 'on')
Run-Clause
Check-Equal '기준: 클릭 1회 전송 → 토글 켬' ("$($script:clicksSent)/$((Count-Log "토글 켬$"))/$($script:exitCode)") '1/1/'
Check-Equal '기준: 양보·정지 없음, 입장하기 확인 단계 진입' ("$($script:yieldWaits)/$($script:clickUntilCalls)") '0/1'

# ── 2. ★ 관측 사고: 클릭이 조작으로 취소 → 기다림 → 제목 확인 → 재판독 ──
#    2a. 사용자가 양보 중 직접 켰음 → 재클릭 0
Reset-Case -ToggleSeq @('off', 'on') -SendSeq @('user-active')
Run-Clause
Check-Equal '취소→사용자가 켬: 양보 1회, 재클릭 0, 클릭 없이 확인 로그' ("$($script:yieldWaits)/$($script:clicksSent)/$((Count-Log '클릭 없이 재판독으로 확인'))") '1/0/1'
Check-Equal '취소→사용자가 켬: 옛 경고(확인하지 못했습니다) 없음 + 진행' ("$((Count-Log '켜진 것을 확인하지 못했습니다'))/$($script:exitCode)/$($script:clickUntilCalls)") '0//1'
Check-Equal '취소→사용자가 켬: 양보 뒤 커서 대피 + 제목 확인 순서 (대피 1회)' $script:parkCalls 1
#    2a-2. 취소 2회 연속 → 양보 2회 → 재클릭 전송 (루프 제거 변이는 이 케이스가 잡음)
Reset-Case -ToggleSeq @('off', 'off', 'off', 'on') -SendSeq @('user-active', 'user-active', 'sent')
Run-Clause
Check-Equal '취소 2회 연속: 양보 2회, 전송 1회, 토글 켬' ("$($script:yieldWaits)/$($script:clicksSent)/$((Count-Log "토글 켬$"))") '2/1/1'
#    2b. 여전히 꺼짐 → 재클릭 전송 → 켬
Reset-Case -ToggleSeq @('off', 'off', 'on') -SendSeq @('user-active', 'sent')
Run-Clause
Check-Equal '취소→여전히 꺼짐: 재클릭 1회 전송 → 토글 켬' ("$($script:yieldWaits)/$($script:clicksSent)/$((Count-Log "토글 켬$"))/$($script:exitCode)") '1/1/1/'
Check-Equal '취소→여전히 꺼짐: 재판독 3회(첫 판독·양보 후·전송 후)' $script:toggleReads 3
#    2c. 양보 뒤 목표 던전 제목 미확인 → 조건부 정지
Reset-Case -ToggleSeq @('off') -SendSeq @('user-active') -TitleSeq @($false)
Run-Clause
Check-Equal '취소→제목 미확인: exit 4 + 사유 로그, 입장하기로 내려가지 않음' ("$($script:exitCode)/$((Count-Log '양보 후 목표 던전 상세 화면을 확인하지 못했습니다'))/$($script:clickUntilCalls)") '4/1/0'
#    2d. 양보 뒤 unknown → 경고 진행 (합의 ③ - 정지 확대 금지)
Reset-Case -ToggleSeq @('off', 'unknown') -SendSeq @('user-active')
Run-Clause
Check-Equal '취소→unknown: 경고 진행 (exit 없음, 입장하기 확인 단계 진입)' ("$($script:exitCode)/$((Count-Log '양보 후 .우연한 만남. 토글 상태를 판별하지 못했습니다'))/$($script:clickUntilCalls)") '/1/1'
#    2e. 제목 확인 중 캡처 실패 → 정지 확정 없이 재판독 (규칙 15)
Reset-Case -ToggleSeq @('off', 'on') -SendSeq @('user-active') -TitleSeq @('capfail', $true)
Run-Clause
Check-Equal '캡처 실패(빈 제목): 안전 검사 1회 + 복구 탐침 1회 뒤 재양보·재판독으로 복구, exit 없음' ("$($script:safeStopCalls)/$($script:probeCalls)/$($script:yieldWaits)/$($script:exitCode)/$((Count-Log '클릭 없이 재판독으로 확인'))") '1/1/2//1'
#    2f. 제목 판독이 창 좌표 실패로 플래그를 세운 뒤 **예외**를 던지는 경로 (구현 리뷰 P2: 받지 않으면 최상위 catch 의 exit 1 로 동결 우회)
Reset-Case -ToggleSeq @('off', 'on') -SendSeq @('user-active') -TitleSeq @('throwfail', $true)
$thrown = $false
try { Run-Clause } catch { $thrown = $true }
Check-Equal '캡처 실패(예외): 예외가 밖으로 새지 않고 동결 분기로 - 안전 검사 1·탐침 1·복구 후 확인' ("$thrown/$($script:safeStopCalls)/$($script:probeCalls)/$($script:exitCode)/$((Count-Log '클릭 없이 재판독으로 확인'))") 'False/1/1//1'
#    2g. 플래그 없는 예외(다른 오류)는 그대로 올라감
Reset-Case -ToggleSeq @('off') -SendSeq @('user-active')
function Test-AbyssDetailTargetConfirmed { param($Game) throw '다른 오류 (모의)' }
$thrown = $false
try { Run-Clause } catch { $thrown = $true }
Check-Equal '다른 예외: 삼키지 않고 그대로 전파' $thrown $true
function Test-AbyssDetailTargetConfirmed { param($Game)
  $r = Next-Seq 'title' $true
  if ("$r" -eq 'capfail') { $script:screenCaptureFailing = $true; $script:captureFailOnce++; return $false }
  if ("$r" -eq 'throwfail') { $script:screenCaptureFailing = $true; $script:captureFailOnce++; throw '창 좌표 확인 실패 (모의 - 플래그를 세운 뒤 예외)' }
  return [bool]$r
}

# ── 3. 커서 미확인 (합의 ②): 다시 읽어 갈래 ──
Reset-Case -ToggleSeq @('off', 'off') -SendSeq @('cursor-not-ready')
Run-Clause
Check-Equal '커서 미확인→여전히 꺼짐: exit 4 (전송하지 못했습니다)' ("$($script:exitCode)/$((Count-Log '켜기 클릭을 전송하지 못했습니다 \(커서 미확인\)'))") '4/1'
Reset-Case -ToggleSeq @('off', 'on') -SendSeq @('cursor-not-ready')
Run-Clause
Check-Equal '커서 미확인→재판독 on: 정지 없이 진행' ("$($script:exitCode)/$((Count-Log '클릭 없이 재판독으로 확인'))/$($script:clickUntilCalls)") '/1/1'
Reset-Case -ToggleSeq @('off', 'unknown') -SendSeq @('cursor-not-ready')
Run-Clause
Check-Equal '커서 미확인→재판독 unknown: 경고 진행' ("$($script:exitCode)/$((Count-Log '상태도 판별하지 못했습니다'))/$($script:clickUntilCalls)") '/1/1'

# ── 4. 합의 ④: 전송됐는데 900ms 뒤 미확인 → 기존 경고 진행 ──
Reset-Case -ToggleSeq @('off', 'off')
Run-Clause
Check-Equal '전송 후 미확인: 기존 경고 + 진행 (정지 아님)' ("$((Count-Log '켜진 것을 확인하지 못했습니다 - 현재 상태로 진행합니다'))/$($script:exitCode)/$($script:clickUntilCalls)") '1//1'
#    첫 판독 unknown → 기존 경고 진행 (변경 없음)
Reset-Case -ToggleSeq @('unknown')
Run-Clause
Check-Equal '첫 판독 unknown: 클릭 없이 경고 진행 (불변)' ("$($script:clicksSent)/$((Count-Log '판별하지 못했습니다\(화면 확인 불가\) - 클릭 없이'))/$($script:exitCode)") '0/1/'
#    이미 켜짐 → 클릭 없이 확인 (불변)
Reset-Case -ToggleSeq @('on')
Run-Clause
Check-Equal '이미 켜짐: 클릭 0, 켜짐 확인 로그' ("$($script:clicksSent)/$((Count-Log "토글 켜짐 확인$"))") '0/1'

# ── 5. 입장하기 클릭 확인 배선: 팝업이 뜨면 종료 조건 + 재클릭 금지 ──
Reset-Case -ToggleSeq @('on')
$script:popupVisible = $true; $script:detailVisible = $true
Run-Clause
Check-Equal '팝업+상세 글자 동시 참: 종료 조건 참(복구로 이관), 원래 버튼 재클릭 조건 거짓' ("$($script:clickUntilCondition)/$($script:clickUntilSource)") 'True/False'
Reset-Case -ToggleSeq @('on')
$script:popupVisible = $false; $script:detailVisible = $true
Run-Clause
Check-Equal '팝업 없음+상세 남음: 종료 조건 거짓, 재클릭 조건 참 (기존 계약)' ("$($script:clickUntilCondition)/$($script:clickUntilSource)") 'False/True'
Reset-Case -ToggleSeq @('on')
$script:popupVisible = $false; $script:detailVisible = $false
Run-Clause
Check-Equal '상세 사라짐: 종료 조건 참' $script:clickUntilCondition $true

# ── 6. 팝업 판정 순수 함수 진리표 ──
Check-Equal "팝업 판정: 실측 원문 '취소 Space 우연한 만남으로 입장' → 참" (Test-AbyssPartyNeededPopupText -Text '취소 Space 우연한 만남으로 입장') $true
Check-Equal "팝업 판정: 상세 하단 'Space 입장하기' → 거짓 (조각 하나)" (Test-AbyssPartyNeededPopupText -Text 'Space 입장하기') $false
Check-Equal "팝업 판정: '우연한 만남'만 → 거짓" (Test-AbyssPartyNeededPopupText -Text '우연한 만남') $false
Check-Equal "팝업 판정: 상세 하단(스위치 끔) '파티 찾기 이동하기' → 거짓" (Test-AbyssPartyNeededPopupText -Text '파티 찾기 이동하기') $false
Check-Equal '팝업 판정: 빈 문자열 → 거짓' (Test-AbyssPartyNeededPopupText -Text '') $false
Check-Equal "팝업 판정: 결과 화면 하단 '나가기 다시 하기' → 거짓" (Test-AbyssPartyNeededPopupText -Text '나가기 다시 하기') $false

# ── 7. 복구 함수 (소스 그대로): 글자 앵커 클릭 계약 ──
Reset-Case
Check-Equal '복구: 앵커 있음 + 전송 → 처리 참, 클릭 1, 로그' ("$((Invoke-AbyssPartyNeededPopupEnter -Game $null))/$($script:clicksSent)/$((Count-Log "우연한 만남으로 입장' 클릭 \(설정이 우연한 만남\)"))") 'True/1/1'
Check-Equal '복구: 앵커 탐색은 하단 문구 영역으로 한정' $script:findRegion '430,570,420,125'
Reset-Case -SendSeq @('user-active')
Check-Equal '복구: 취소 → 기다린 뒤 처리 참 (호출부 재판독)' ("$((Invoke-AbyssPartyNeededPopupEnter -Game $null))/$($script:yieldWaits)/$($script:clicksSent)") 'True/1/0'
Reset-Case -SendSeq @('cursor-not-ready')
Check-Equal '복구: 커서 미확인 → 처리 참, 양보 없음 (호출부 대기 예산 소모)' ("$((Invoke-AbyssPartyNeededPopupEnter -Game $null))/$($script:yieldWaits)/$((Count-Log '커서 확인 실패로 클릭을 건너뜀'))") 'True/0/1'
Check-Equal "복구: 1차 앵커 '만남'(버튼 중앙) 사용" ($script:findWords[0]) '만남'
Reset-Case; $script:anchorWords = @('우연한')
Check-Equal "복구: '만남' 없고 '우연한'만 있으면 2차 앵커로 클릭 1" ("$((Invoke-AbyssPartyNeededPopupEnter -Game $null))/$($script:clicksSent)/$($script:findWords -join ',')") 'True/1/만남,우연한'
Reset-Case; $script:anchorWords = @()
Check-Equal '복구: 앵커 둘 다 없음(팝업 사라짐/단어 분할 다름) → 거짓, 클릭 0, 경고 1회' ("$((Invoke-AbyssPartyNeededPopupEnter -Game $null))/$($script:clicksSent)/$((Count-Log '버튼 글자를 찾지 못했습니다'))") 'False/0/1'
Check-Equal '복구: 앵커 미발견 로그는 회차당 1회만' ("$((Invoke-AbyssPartyNeededPopupEnter -Game $null))/$((Count-Log '버튼 글자를 찾지 못했습니다'))") 'False/1'

# ── 8. 매칭 대기 조건 배선 (운영 -Condition 블록 실행) ──
function Invoke-AbyssPartyNeededPopupEnter { param($Game) $script:recoverCalls++; return $true }
Reset-Case; $script:recoverCalls = 0
$abyssMatching = '우연한 만남'; $script:popupVisible = $true; $script:inDungeon = $false
Check-Equal '매칭 대기: 우연한 만남 + 팝업 → 복구 1회, 조건 거짓(재판독)' ("$((& $matchCondition))/$($script:recoverCalls)") 'False/1'
$script:popupVisible = $false; $script:inDungeon = $true
Check-Equal '매칭 대기: 팝업 없음 + 던전 안 → 참' ([bool](& $matchCondition)) $true
$abyssMatching = '파티(파티장)'; $script:popupVisible = $true; $script:inDungeon = $false; $script:recoverCalls = 0
Check-Equal '매칭 대기: 다른 매칭 모드에서는 팝업 복구를 부르지 않음' ("$((& $matchCondition))/$($script:recoverCalls)") 'False/0'

# ── 9. 구조 (주석 제거본) ──
$code = (($clauseText -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Check-Equal '구조: 클릭 전송 여부를 읽음 (lastClickPerformed / user-active)' (($code -match 'lastClickPerformed') -and ($code -match "lastClickSkipReason -eq 'user-active'")) $true
$lines = @($code -split "`r?`n")
$idxWait = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match "Wait-UserYieldEnd -Game \`$game -Context `"'우연한 만남' 토글 켜기`"" })
$idxPark = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match 'Move-CursorOutsideGame -Game \$game' })
$idxTitle = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match '\$targetConfirmed = Test-AbyssDetailTargetConfirmed' })
$idxRead = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match '\$toggleState = Get-ChanceToggleState' -and [Array]::IndexOf($lines, $l) -gt $idxTitle })
Check-Equal '구조: 양보 → 커서 대피 → 제목 확인 → 토글 재판독 순서 (줄 순서)' (($idxWait -ge 0) -and ($idxWait -lt $idxPark) -and ($idxPark -lt $idxTitle) -and ($idxTitle -lt $idxRead)) $true
Check-Equal '구조: 제목 판독 뒤 캡처 실패 동결에 복구 탐침 포함 (규칙 15 ⑤)' ($code -match '(?s)\$targetConfirmed = Test-AbyssDetailTargetConfirmed.{0,200}?screenCaptureFailing.{0,120}?Test-SafeStopDuringCaptureFail\s+\[void\]\(Test-CaptureRecovered -Game \$game\)') $true
Check-Equal '구조: 캡처 실패 동결 분기는 제목 판독 뒤 1곳만 - 픽셀 판독(토글) 뒤에는 없음 (죽은 분기 금지)' ([regex]::Matches($code, 'if \(\$script:screenCaptureFailing\) \{').Count) 1
Check-Equal '구조: 입장하기 클릭 확인의 종료 조건에 팝업, 재클릭 조건에 팝업 부정' ($code -match "-Condition \{ \(Test-AbyssPartyNeededPopup -Game \`$game\) -or -not \(Test-PartyDetailScreen -Game \`$game\) \}" -and $code -match "-SourceCondition \{ \(Test-PartyDetailScreen -Game \`$game\) -and -not \(Test-AbyssPartyNeededPopup -Game \`$game\) \}") $true

exit $fails
