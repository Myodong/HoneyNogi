# 자동 부활 상태 머신 진리표 (2026-09-25 설계 합의 A+B - 목록 1절 1번, 09-21 22:33 실사고. 구현 리뷰 1차 반려 반영 포함)
#
# 09-21 22:33: 남은 부활 0회 화면에서 거점 버튼 글자를 못 찾아 예비 좌표를 7회 클릭 → 전부 무효(화면 그대로)인데 '전송됨' 만으로
# revive.maxPerCycle(10) 을 소진 → 상한 도달 뒤 파티 전멸 화면을 24분 방치(전투 연장이 사망 화면을 '전투 중' 으로 읽음).
# 여기서 고정하는 계약 (운영 함수를 AST 로 추출해 실행 - 사본 재구현 금지):
#   ① 계상은 전송이 아니라 성공 확인(전송 뒤 다음 유효 표본이 사망·전멸 아님) - 거점 성공 수만 checkpointReviveLimit 의 대상(가루는 로그용)
#   ② 사망 1회(에피소드)당 실제 전송은 $reviveDispatchBudget 회. 그 뒤 유효 사망 표본 = 'stop-exhausted' (마지막 전송 직후가 아님)
#   ③ 거점 부활(캠프파이어·여신상·전멸 재도전) 성공이 상한(기본 3)에 닿은 뒤 **거점 부활이 필요한** 사망·전멸 = 'leave' (어비스: 부활 대신 퇴장 →
#      호출부가 선택 화면 복귀 + 코드 10). 가루(R) 부활은 세지 않음. 던전·심층·사냥터(LeaveOnLimit 거짓)는 상한 없음. 2026-09-25 저녁 사용자 확정 -
#      옛 '전체 부활 상한 10 → 코드 4' 는 게임 규칙이 아니었음(캠프파이어 착석·여신상 부활로 횟수 초기화, 실기 1 에서 이길 수 있는 판을 끊음)
#   ④ 무효 표본(캡처 실패·판독 도중 실패)은 성공도 실패도 아님 - 카운터·pending 유지, stop 확정 금지 (규칙 15)
#   ⑤ 생략(user-active)은 예산·20초 상한을 소모하지 않음 / cursor-not-ready·전면 미확인만 20초 (연속 생략 사이 경과 합 - 시도 없는 회전 제외)
#   ⑥ Dead↔Wiped 전환은 같은 에피소드(전송 수 유지) / R키 뒤 구매 팝업은 거점 전환 + pending 해제, 전송 수 유지
#   ⑦ 정착 창(구현 리뷰 P1): 전송 뒤 $reviveSettleSeconds 안의 사망 표본은 'settling' - 무효 전송으로 확정하지 않음. 생존 표본은 즉시 확인
#   ⑧ 캡처 실패 누적 시계(Get-CaptureFailTotalMs): 끝난 구간 합 + 진행 중 경과, 단조 증가 (연장 절대 한도 동결의 근거)
#   ⑨ 호출부 배선: 마감 판정이 사망 화면·pending 에서 물러섬, 표본·앵커·재확인 전부 일련번호 게이트, 개인 예비 좌표는 개인 사망에서만,
#      팝업 검사는 에피소드 중 매 폴, 마감 초기화는 confirmed 에서만, stop 은 진단 + [완료] + exit 4, 시도 없는 회전은 연속 끊기
#   ⑩ 퇴장 배선: 'leave' → Invoke-AbyssDeathExit(문 아이콘은 사망 화면일 때만, '나가기' 는 팝업 제목 확인 뒤 글자 위치 클릭, 캡처 동결·양보,
#      필드 2연속 = 'left') → 어비스 본류·파티원이 'left' 를 코드 10 으로 마침 (회차 미계상). config 는 schema 10 (maxPerCycle 제거)
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

# ── 운영 코드 추출 ─────────────────────────────────────────────────────────────
foreach ($name in @('New-ReviveState', 'Resolve-ReviveSample', 'Register-ReviveDispatch', 'Register-RevivePurchasePopup',
    'Register-ReviveNoAttempt', 'Resolve-ReviveDispatchSkip', 'Get-CaptureFailTotalMs', 'Register-CaptureSuccess', 'Test-AbyssExitPopupText', 'Get-ReviveEpisodeAgeMs')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}
$workerSource = [IO.File]::ReadAllText($workerPath)
$workerCode = Remove-SourceComments -Text $workerSource
# 계약 상수는 소스에서 캡처하되, 설계 합의로 못 박은 값은 그 값 자체도 단언합니다 (바꾸려면 합의부터 - 구현 리뷰 지적)
$budgetMatch = [regex]::Match($workerCode, '(?m)^\$reviveDispatchBudget = (\d+)\s*$')
Check-Equal '상수: $reviveDispatchBudget 선언 1곳' $budgetMatch.Success $true
$budget = [int]$budgetMatch.Groups[1].Value
Check-Equal '상수: 전송 예산은 설계 합의 값 3 (첫 시도 + 재시도 2)' $budget 3
$settleMatch = [regex]::Match($workerCode, '(?m)^\$reviveSettleSeconds = (\d+)\s*$')
Check-Equal '상수: $reviveSettleSeconds 선언 1곳' $settleMatch.Success $true
$settle = [int]$settleMatch.Groups[1].Value
Check-Equal '상수: 정착 창은 실측 상한 4초 + 회전 오버헤드 여유 1초 = 5초 (자체 리뷰: 4초는 3초 대기 뒤 여유가 0~1초)' $settle 5
$limitMatch = [regex]::Match($workerCode, "\`$reviveCheckpointLimit = Get-ConfigInteger \`$config @\('revive', 'checkpointReviveLimit'\) (\d+) 0 1000")
Check-Equal '상수: 거점 부활 상한 config 키 checkpointReviveLimit (기본 3 - 사용자 확정 "3회까지 허용")' ('{0}/{1}' -f $limitMatch.Success, $limitMatch.Groups[1].Value) 'True/3'

# ── 시나리오 러너: 표본·이벤트 열을 순서대로 먹이고 행동 열을 기록 ──────────────
# 표본 'A'=유효 생존 / 'D'=유효 사망(R키 경로 - 남은 횟수 있음) / 'C'=유효 사망 + 거점 필요(남은 0회·가루 부족 전환) / 'W'=유효 전멸(거점 필요) /
#      'X'=무효(캡처 실패·판독 도중 실패)
# 이벤트 'ok:<종류>'=입력이 실제로 나감 / 'skip:<사유>'=입력 생략 / 'noattempt'=시도 없는 회전 / 'popup'=R키 뒤 구매 팝업 /
#      'yield:<ms>'=간접 양보(구매 팝업 스윕의 커서 대피 등 - userYieldTotalMs 누적만 움직임)
# 시각: 각 단계에 '@<초>' 를 붙이면 그 절대 시각, 없으면 직전 시각 + 5초 (전송 뒤 3초 대기 + 판독 1회를 넘는 보통 회전 간격)
function Run-Scenario {
  param([string[]]$Steps, [int]$Limit = 3, [bool]$Leave = $true)
  $s = New-ReviveState
  $actions = @(); $skips = @()
  $yieldTotal = [double]0
  $base = [datetime]'2026-01-01 00:00:00'
  $clock = -5.0
  foreach ($raw in $Steps) {
    $step = $raw
    if ($raw -match '^(.*)@([0-9.]+)$') { $step = $Matches[1]; $clock = [double]$Matches[2] } else { $clock += 5 }
    $now = $base.AddSeconds($clock)
    if ($step -like 'ok:*') { Register-ReviveDispatch -State $s -Kind $step.Substring(3) -Now $now -SettleSeconds $settle; $actions += 'sent'; continue }
    if ($step -like 'skip:*') { $skips += (Resolve-ReviveDispatchSkip -State $s -Reason $step.Substring(5) -Now $now -YieldTotalMs $yieldTotal); $actions += 'skip'; continue }
    if ($step -like 'yield:*') { $yieldTotal += [double]$step.Substring(6); $actions += 'yield'; continue }
    if ($step -eq 'noattempt') { Register-ReviveNoAttempt -State $s; $actions += 'noattempt'; continue }
    if ($step -eq 'popup') { Register-RevivePurchasePopup -State $s; $actions += 'popup'; continue }
    $valid = ($step -ne 'X')
    $dead = ($step -eq 'D' -or $step -eq 'C'); $wiped = ($step -eq 'W'); $needCheckpoint = ($step -eq 'C' -or $step -eq 'W')
    $actions += (Resolve-ReviveSample -State $s -Valid $valid -Dead $dead -Wiped $wiped -CheckpointNeeded $needCheckpoint -CheckpointLimit $Limit -LeaveOnLimit $Leave -Now $now -DispatchBudget $budget)
  }
  return [pscustomobject]@{
    State = $s; Actions = ($actions -join ','); Skips = ($skips -join ',')
    Summary = ('{0}/{1}/{2}/{3}' -f ($s.PowderConfirmed + $s.CheckpointConfirmed), $s.Dispatched, $s.Pending, $s.Episode)
  }
}
function Last-Action { param($Result) return ($Result.Actions -split ',')[-1] }

# ── ① 계상은 성공 확인 시점 ──────────────────────────────────────────────────────
$r = Run-Scenario @('A', 'D', 'ok:가루 부활', 'A')
Check-Equal '① 기준 행동열: 생존→사망→전송→생존' $r.Actions 'none,dispatch,sent,confirmed'
Check-Equal '① 기준 상태 Confirmed/Dispatched/Pending/Episode' $r.Summary '1/0/False/False'
Check-Equal '① 완료 로그용 종류 전달' $r.State.LastConfirmedKind '가루 부활'
$r = Run-Scenario @('D', 'ok:가루 부활')
Check-Equal '① 전송 직후: Confirmed 0 (전송은 계상이 아님), Dispatched 1, pending' $r.Summary '0/1/True/True'

# ── ② 에피소드 전송 예산 ───────────────────────────────────────────────────────────
$steps = @('D'); foreach ($i in 1..$budget) { $steps += 'ok:여신상 부활'; $steps += 'D' }
$r = Run-Scenario $steps
Check-Equal '② 예산 소진 뒤 유효 사망 표본 = stop-exhausted' (Last-Action $r) 'stop-exhausted'
Check-Equal '② 그때 Confirmed 0 / Dispatched = 예산' ('{0}/{1}' -f ($r.State.PowderConfirmed + $r.State.CheckpointConfirmed), $r.State.Dispatched) "0/$budget"
Check-Equal '② 예산 안의 재시도는 전부 dispatch (09-21 은 이 자리에서 7회를 계상했음)' (@(($r.Actions -split ',') | Where-Object { $_ -eq 'dispatch' }).Count) $budget
$steps = @('D'); foreach ($i in 1..$budget) { $steps += 'ok:여신상 부활'; if ($i -lt $budget) { $steps += 'D' } }; $steps += 'A'
$r = Run-Scenario $steps
Check-Equal '② 마지막 전송이 먹으면 confirmed (마지막 전송 직후 stop 금지)' (Last-Action $r) 'confirmed'
Check-Equal '② 그 뒤 상태: Confirmed 1, 에피소드 종료' $r.Summary '1/0/False/False'

# ── ③ 거점 부활 상한 → 퇴장 (2026-09-25 저녁 사용자 확정: 3회까지 허용, 4회째 필요 시 나가기) ──
$r = Run-Scenario @('C', 'ok:여신상 부활', 'A', 'C', 'ok:캠프파이어 부활', 'A', 'W', 'ok:전멸 재도전', 'A', 'C')
Check-Equal '③ 거점 3회(여신상·캠프파이어·전멸 재도전) 뒤 거점이 필요한 사망 = leave (전송 없이)' (Last-Action $r) 'leave'
Check-Equal '③ 그때 거점 3 / 가루 0 / Dispatched 0 / 에피소드 열림' ('{0}/{1}/{2}/{3}' -f $r.State.CheckpointConfirmed, $r.State.PowderConfirmed, $r.State.Dispatched, $r.State.Episode) '3/0/0/True'
$r = Run-Scenario @('D', 'ok:가루 부활', 'A', 'D', 'ok:가루 부활', 'A', 'D', 'ok:가루 부활', 'A', 'D', 'ok:가루 부활', 'A', 'D', 'ok:가루 부활', 'A', 'C')
Check-Equal '③ 가루(R) 부활은 세지 않는다 - 5회 뒤 거점 필요 사망도 dispatch' ('{0}/{1}/{2}' -f (Last-Action $r), $r.State.PowderConfirmed, $r.State.CheckpointConfirmed) 'dispatch/5/0'
$r = Run-Scenario @('C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'D')
Check-Equal '③ 거점 3회 뒤라도 R 경로 사망(남은 횟수 있음)은 dispatch (거점이 필요할 때만 퇴장)' (Last-Action $r) 'dispatch'
$r = Run-Scenario @('W', 'ok:전멸 재도전', 'A', 'W', 'ok:전멸 재도전', 'A', 'W', 'ok:전멸 재도전', 'A', 'W')
Check-Equal '③ 전멸 재도전도 거점 - 3회 뒤 전멸 = leave' (Last-Action $r) 'leave'
$r = Run-Scenario @('C') -Limit 0
Check-Equal '③ 상한 0: 첫 거점 필요 사망에서 leave' $r.Actions 'leave'
$r = Run-Scenario @('D') -Limit 0
Check-Equal '③ 상한 0 이라도 R 경로 사망은 dispatch' $r.Actions 'dispatch'
$r = Run-Scenario @('C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'C') -Leave $false
Check-Equal '③ 던전·심층·사냥터(LeaveOnLimit 거짓): 거점 4회 뒤에도 dispatch (상한 없음)' ('{0}/{1}' -f (Last-Action $r), $r.State.CheckpointConfirmed) 'dispatch/4'
$r = Run-Scenario @('C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'D', 'ok:가루 부활', 'D', 'ok:가루 부활', 'D', 'ok:가루 부활', 'C')
Check-Equal '③ 같은 에피소드에서 예산을 다 쓴 뒤의 거점 필요 사망은 stop-exhausted 가 leave 보다 먼저 (입력 계통 장애 우선)' (Last-Action $r) 'stop-exhausted'
$r = Run-Scenario @('C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A')
Check-Equal '③ 상한 뒤 leave 없이 거점 부활이 확인되면 그대로 4 (호출부가 nagagi 전 화면이 바뀐 stay 경로)' $r.State.CheckpointConfirmed 4
$r = Run-Scenario @('C', 'ok:여신상 부활', 'A', 'X', 'C')
Check-Equal '③ 무효 표본은 거점 계수·판정에 영향 없음 (1회 뒤 dispatch)' ((($r.Actions -split ',')[-2..-1]) -join ',') 'skip,dispatch'
$r = Run-Scenario @('C', 'ok:여신상 부활', 'A', 'C', 'ok:캠프파이어 부활', 'A', 'W', 'ok:전멸 재도전', 'A', 'C@100', 'A@101', 'C@102')
Check-Equal '③ leave 판정 뒤 생존 표본(직접 부활 등) → cleared, 다시 거점 필요 사망 → 다시 leave' ((($r.Actions -split ',')[-3..-1]) -join ',') 'leave,cleared,leave'

# ── ④ 무효 표본은 성공도 실패도 아님 ─────────────────────────────────────────────
$r = Run-Scenario @('D', 'ok:가루 부활', 'X', 'X', 'A')
Check-Equal '④ 전송 뒤 무효 표본 2회는 skip, 그 뒤 생존에서 confirmed' $r.Actions 'dispatch,sent,skip,skip,confirmed'
$r = Run-Scenario @('D', 'ok:가루 부활', 'X')
Check-Equal '④ 무효 표본은 pending·Dispatched 유지' $r.Summary '0/1/True/True'
$steps = @('D'); foreach ($i in 1..$budget) { $steps += 'ok:여신상 부활'; $steps += 'D' }
$steps[-1] = 'X'; $steps += 'A'
$r = Run-Scenario $steps
Check-Equal '④ 예산 소진 뒤 무효 표본은 stop 을 확정하지 않음 (다음 생존에서 confirmed)' ((($r.Actions -split ',')[-2..-1]) -join ',') 'skip,confirmed'
$r = Run-Scenario @('X', 'X')
Check-Equal '④ 무효 표본만으로는 에피소드도 열리지 않음' $r.Summary '0/0/False/False'
$r = Run-Scenario @('C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'C', 'ok:여신상 부활', 'A', 'X', 'C')
Check-Equal '④ 거점 상한 뒤 무효 표본은 leave 아님, 그 뒤 유효 거점 필요 사망에서 leave' ((($r.Actions -split ',')[-2..-1]) -join ',') 'skip,leave'

# ── ⑤ 생략 3갈래 (규칙 4) ─────────────────────────────────────────────────────────
$r = Run-Scenario @('D', 'skip:user-active@0', 'D', 'skip:user-active@30', 'D', 'skip:user-active@60', 'D', 'ok:가루 부활', 'A')
Check-Equal '⑤ user-active 생략 3회: 전부 yield (상한 시계 없음)' $r.Skips 'yield,yield,yield'
Check-Equal '⑤ 생략 뒤 전송·확인은 정상 (Dispatched 는 생략을 세지 않음)' $r.Summary '1/0/False/False'
$r = Run-Scenario @('D', 'skip:user-active')
Check-Equal '⑤ 생략 직후 Dispatched 0 (생략은 전송이 아님)' $r.State.Dispatched 0
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'D', 'skip:cursor-not-ready@10', 'D', 'skip:cursor-not-ready@21')
Check-Equal '⑤ cursor-not-ready 연속: 0→10초 wait, 21초 누적 timeout' $r.Skips 'wait,wait,timeout'
$r = Run-Scenario @('D', 'skip:foreground@0', 'D', 'skip:foreground@19.9', 'D', 'skip:foreground@20.0')
Check-Equal '⑤ 전면 미확인(R키)도 같은 상한, 정확히 20.0초 경계에서 timeout' $r.Skips 'wait,wait,timeout'
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'D', 'skip:user-active@5', 'D', 'skip:cursor-not-ready@30')
Check-Equal '⑤ user-active 가 끼면 누적 초기화 (30초 뒤 생략도 wait)' $r.Skips 'wait,yield,wait'
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'X', 'D', 'skip:cursor-not-ready@30')
Check-Equal '⑤ 캡처 실패 표본이 끼면 누적 초기화 (현행 유지 - 동결 아닌 초기화)' $r.Skips 'wait,wait'
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'A', 'D', 'skip:cursor-not-ready@30')
Check-Equal '⑤ 생존 표본 뒤 새 에피소드는 새 시계' $r.Skips 'wait,wait'
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'D', 'ok:가루 부활@5', 'D', 'skip:cursor-not-ready@30')
Check-Equal '⑤ 전송 성공이 시계를 초기화' $r.Skips 'wait,wait'
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'D', 'noattempt@5', 'D', 'skip:cursor-not-ready@30', 'D', 'skip:cursor-not-ready@31')
Check-Equal '⑤ 시도 없는 회전(앵커 미탐)이 끼면 그 구간은 제외 - 30초 뒤 wait, 이어진 1초만 누적' ('{0}/{1}' -f $r.Skips, [int]$r.State.SkipElapsedMs) 'wait,wait,wait/1000'
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'D', 'skip:cursor-not-ready@12', 'D', 'noattempt@13', 'D', 'skip:cursor-not-ready@40', 'D', 'skip:cursor-not-ready@48')
Check-Equal '⑤ 누적은 유지되고 연속만 끊김: 12초 + (40→48) 8초 = 20초 timeout' $r.Skips 'wait,wait,wait,timeout'
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'yield:30000', 'D', 'skip:cursor-not-ready@35', 'D', 'skip:cursor-not-ready@40')
Check-Equal '⑤ 두 생략 사이 간접 양보(30초)가 있었으면 그 생략은 yield 로 (누적 0), 양보 뒤 첫 생략은 새 연속의 시작이라 누적 0 → wait (자체 리뷰 P2)' ('{0}/{1}' -f $r.Skips, [int]$r.State.SkipElapsedMs) 'wait,yield,wait/0'
$r = Run-Scenario @('D', 'skip:cursor-not-ready@0', 'yield:1', 'D', 'skip:cursor-not-ready@25')
Check-Equal '⑤ 양보 누적이 1ms 라도 움직였으면 사용자 시간 - timeout 아님' $r.Skips 'wait,yield'
$r = Run-Scenario @('D', 'skip:user-active@0', 'A')
Check-Equal '⑤ 전송 없이 해소 = cleared, Confirmed 0' ('{0}/{1}' -f $r.Actions, ($r.State.PowderConfirmed + $r.State.CheckpointConfirmed)) 'dispatch,skip,cleared/0'

# ── ⑥ 에피소드 경계 ────────────────────────────────────────────────────────────────
$steps = @('D', 'ok:가루 부활', 'W', 'ok:전멸 재도전')
if ($budget -gt 2) { foreach ($i in 3..$budget) { $steps += 'W'; $steps += 'ok:전멸 재도전' } }
$steps += 'W'
$r = Run-Scenario $steps
Check-Equal '⑥ 사망→전멸 전환 뒤에도 전송 수 누적 → 예산 뒤 stop-exhausted' (Last-Action $r) 'stop-exhausted'
$r = Run-Scenario @('D', 'ok:가루 부활', 'W')
Check-Equal '⑥ 사망→전멸 전환은 같은 에피소드 (Dispatched 1 유지, 재전송 차례)' ('{0}/{1}' -f (Last-Action $r), $r.State.Dispatched) 'dispatch/1'
$r = Run-Scenario @('W', 'ok:전멸 재도전', 'D')
Check-Equal '⑥ 전멸→사망 역전환도 같은 에피소드' ('{0}/{1}' -f (Last-Action $r), $r.State.Dispatched) 'dispatch/1'
$r = Run-Scenario @('D', 'ok:가루 부활', 'popup')
Check-Equal '⑥ 팝업 뒤 상태: StatueMode, pending 해제, Dispatched 1 유지' ('{0}/{1}/{2}' -f $r.State.StatueMode, $r.State.Pending, $r.State.Dispatched) 'True/False/1'
$r = Run-Scenario @('D', 'ok:가루 부활', 'popup', 'D', 'ok:여신상 부활', 'A')
Check-Equal '⑥ 팝업 뒤 거점 전송 → 성공 확인 종류는 거점' ('{0}/{1}' -f (Last-Action $r), $r.State.LastConfirmedKind) 'confirmed/여신상 부활'
$r = Run-Scenario @('D', 'ok:가루 부활', 'popup', 'A')
Check-Equal '⑥ 팝업으로 pending 해제된 뒤 생존 = cleared (허위 성공 계상 금지)' ('{0}/{1}' -f (Last-Action $r), ($r.State.PowderConfirmed + $r.State.CheckpointConfirmed)) 'cleared/0'
$r = Run-Scenario @('D', 'ok:가루 부활@0', 'popup@1', 'D@2')
Check-Equal '⑥ 팝업 뒤 정착 창 안 사망 표본도 곧바로 재전송 차례 (pending 해제 = 정착 창 해제)' (Last-Action $r) 'dispatch'
$steps = @('D'); foreach ($i in 1..$budget) { $steps += 'ok:여신상 부활'; if ($i -lt $budget) { $steps += 'D' } }; $steps += @('A', 'D')
$r = Run-Scenario $steps
Check-Equal '⑥ 확인 뒤 새 사망은 dispatch (예산 초기화)' (Last-Action $r) 'dispatch'
$r = Run-Scenario @('D', 'ok:가루 부활', 'A', 'D', 'ok:가루 부활', 'A')
Check-Equal '⑥ 에피소드 2회 성공 = 가루 2 (거점 0)' ('{0}/{1}' -f $r.State.PowderConfirmed, $r.State.CheckpointConfirmed) '2/0'

# ── ⑦ 정착 창 (구현 리뷰 P1 - 3초 대기 직후 표본으로 무효 확정 금지) ──────────────
$r = Run-Scenario @('D@0', 'ok:가루 부활@0', 'D@3')
Check-Equal '⑦ 전송 3초 뒤 사망 표본 = settling (pending·Dispatched 유지, 재전송 없음)' ('{0}/{1}' -f (Last-Action $r), $r.Summary) 'settling/0/1/True/True'
$r = Run-Scenario @('D@0', 'ok:가루 부활@0', 'D@3', 'A@4')
Check-Equal '⑦ 3초 사망 → 4초 생존 = confirmed (재전송 없이, 실측 3~4초 완료)' $r.Actions 'dispatch,sent,settling,confirmed'
$r = Run-Scenario @('D@0', 'ok:가루 부활@0', 'A@1')
Check-Equal '⑦ 생존 표본은 창과 무관하게 즉시 confirmed' (Last-Action $r) 'confirmed'
$r = Run-Scenario @('D@0', 'ok:가루 부활@0', 'D@3', "D@$settle")
Check-Equal '⑦ 창 끝(=정착 초)의 사망 표본은 무효 전송 확정 → dispatch (Dispatched 1 유지)' ('{0}/{1}' -f (Last-Action $r), $r.State.Dispatched) 'dispatch/1'
$r = Run-Scenario @('D@0', 'ok:가루 부활@0', 'X@3', 'D@3.5')
Check-Equal '⑦ 창 안의 무효 표본은 skip, 이어진 창 안 사망은 settling' ((($r.Actions -split ',')[-2..-1]) -join ',') 'skip,settling'
$steps = @('D@0'); $clockAt = 0
foreach ($i in 1..$budget) { $steps += "ok:여신상 부활@$clockAt"; $clockAt += 3; $steps += "D@$clockAt"; $clockAt += 2; $steps += "D@$clockAt" }
$r = Run-Scenario $steps
Check-Equal '⑦ 예산 소진은 정착 창 밖 표본에서만 센다 (3초 settling, 5초 dispatch 반복 뒤 stop-exhausted)' (Last-Action $r) 'stop-exhausted'
Check-Equal '⑦ 그 열의 settling 수 = 예산' (@(($r.Actions -split ',') | Where-Object { $_ -eq 'settling' }).Count) $budget

# ── ⑧ 캡처 실패 누적 시계 (연장 절대 한도 동결의 근거 - 규칙 15) ────────────────────
# 운영 Register-CaptureSuccess 를 그대로 쓰되 주변 의존은 최소 모의 (가상 시계·로그·세션 이름)
function Get-Date { return $script:vclock }
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Get-CaptureRecoveryMessage { param($FailCause) return '복구' }
function Get-SessionStationName { return 'Console' }
$script:logs = @(); $script:lastGoodStationName = $null; $script:gameWindowMissingSince = $null
$script:captureFailTotalMs = [double]0; $script:screenCaptureFailing = $false; $script:captureFailingSince = $null
$script:captureFailMessage = $null; $script:captureFailCause = $null
$t0 = [datetime]'2026-01-01 00:00:00'
$script:vclock = $t0
Check-Equal '⑧ 실패 없음 = 0' (Get-CaptureFailTotalMs) 0
$script:screenCaptureFailing = $true; $script:captureFailingSince = $t0.AddSeconds(10)   # Register-CaptureFailure 가 세우는 상태
$script:vclock = $t0.AddSeconds(15)
Check-Equal '⑧ 진행 중 구간은 경과를 실시간으로 더함 (10→15초 = 5000)' (Get-CaptureFailTotalMs) 5000
$script:vclock = $t0.AddSeconds(17)
Register-CaptureSuccess
Check-Equal '⑧ 복구 시 끝난 구간을 정확히 한 번 가산 (7000) + 플래그·시작 시각 해제' ('{0}/{1}/{2}' -f (Get-CaptureFailTotalMs), $script:screenCaptureFailing, ($null -eq $script:captureFailingSince)) '7000/False/True'
$script:vclock = $t0.AddSeconds(30)
Check-Equal '⑧ 복구 뒤에는 시간이 흘러도 불변 (단조, 진행 구간 없음)' (Get-CaptureFailTotalMs) 7000
$script:screenCaptureFailing = $true; $script:captureFailingSince = $t0.AddSeconds(40)
$script:vclock = $t0.AddSeconds(43)
Check-Equal '⑧ 두 번째 구간 진행 중 = 7000 + 3000' (Get-CaptureFailTotalMs) 10000
$script:vclock = $t0.AddSeconds(44)
Register-CaptureSuccess
Check-Equal '⑧ 두 번째 복구 뒤 = 11000' (Get-CaptureFailTotalMs) 11000
# 대기 루프의 차분 적용식 (회전 서두): 마지막 관측값과의 차분만큼 한도를 미룸 - 여러 회전에 걸쳐도 합이 정확히 누적과 같음
$extendLimit = $t0.AddSeconds(1800); $seen = [double]0
foreach ($probe in @(0, 5000, 7000, 7000, 10000, 11000)) {
  $script:captureFailTotalMs = $probe; $script:screenCaptureFailing = $false; $script:captureFailingSince = $null
  $delta = (Get-CaptureFailTotalMs) - $seen
  if ($delta -gt 0) { $extendLimit = $extendLimit.AddMilliseconds($delta); $seen += $delta }
}
Check-Equal '⑧ 차분 누적의 합 = 총 실패 시간 (1800초 + 11초)' (($extendLimit - $t0).TotalSeconds) 1811

# ── ⑨ 호출부 배선 (주석 뺀 사본) ─────────────────────────────────────────────────
$clearBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Wait-ForDungeonClearScreen'))
$clearCode = Remove-SourceComments -Text $clearBody
Check-Equal '⑨ 선언: 상태 머신 1개 + 누적 관측값 + 마감 안내 플래그' ('{0}/{1}/{2}' -f ([regex]::Matches($clearCode, '\$reviveState = New-ReviveState').Count), ([regex]::Matches($clearCode, '\$seenCaptureFailMs = Get-CaptureFailTotalMs').Count), ([regex]::Matches($clearCode, '\$deadlineDeathLogged = \$false').Count)) '1/1/2'
Check-Equal '⑨ 회전 서두: 캡처 실패 누적 차분만큼 연장 절대 한도를 미룸 (마감 블록 앞)' ($clearCode -match '(?s)while \(\$true\) \{\s*\r?\n\s*\$captureFailDelta = \(Get-CaptureFailTotalMs\) - \$seenCaptureFailMs\s*\r?\n\s*if \(\$captureFailDelta -gt 0\) \{ \$extendLimit = \$extendLimit\.AddMilliseconds\(\$captureFailDelta\); \$seenCaptureFailMs \+= \$captureFailDelta \}\s*\r?\n\s*\$deadlineSerial = \$script:captureFailSerial\s*\r?\n\s*if \(\(Get-Date\) -ge \$deadline\)') $true
Check-Equal '⑨ 마감 블록: 캡처 실패 → (pending 또는 유효 사망 화면이면 물러섬) → 전투 연장 순서' ($clearCode -match '(?s)if \(\(Get-Date\) -ge \$deadline\) \{\s*\r?\n\s*if \(\$script:screenCaptureFailing\) \{\s*\r?\n\s*\} elseif \(\$reviveEnabled -and \(\$reviveState\.Pending -or \(Test-DeathScreenValid -Game \$Game\)\)\) \{[\s\S]{0,900}?\} elseif \(\(Get-Date\) -lt \$extendLimit -and \(Test-CombatStillRunning') $true   # 09-25: 사이에 일련번호 동결 분기 1개 (구현 리뷰 2차)
Check-Equal '⑨ 마감 물러섬 분기에 throw·exit 없음 (판정은 상태 머신)' ($clearCode -match '(?s)elseif \(\$reviveEnabled -and \(\$reviveState\.Pending[^\r\n]*\r?\n[\s\S]{0,600}?\} elseif') $true
$deferRegion = [regex]::Match($clearCode, '(?s)elseif \(\$reviveEnabled -and \(\$reviveState\.Pending[\s\S]{0,600}?\} elseif').Value
Check-Equal '⑨ 마감 물러섬 분기 본문에 throw/exit 없음' ($deferRegion -match '\b(throw|exit)\b') $false
$validHelper = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-DeathScreenValid')))
Check-Equal '⑨ Test-DeathScreenValid: 일련번호·플래그 게이트 뒤에만 Dead/Wiped 를 믿음' ($validHelper -match '(?s)\$serial = \$script:captureFailSerial\s*\r?\n\s*\$info = Get-DeathScreenInfo -Game \$Game\s*\r?\n\s*if \(\$script:screenCaptureFailing -or \(\$script:captureFailSerial -ne \$serial\)\) \{ return \$false \}\s*\r?\n\s*return \[bool\]\(\$info\.Dead -or \$info\.Wiped\)') $true
Check-Equal '⑨ 표본 유효성: 기준 일련번호·차단 플래그는 구매 팝업 스윕 **앞**에서 기록 (스윕 도중 실패·스윕 생략도 표본 무효 - 구현 리뷰 2차 P2)' ($clearCode -match '(?s)\$deathSampleSerial = \$script:captureFailSerial\s*\r?\n\s*\$deathSampleBlocked = \[bool\]\$script:screenCaptureFailing\s*\r?\n\s*if \(\(\(\$pollCounter % 2\) -eq 0 -or \$reviveState\.Episode\) -and -not \$script:screenCaptureFailing\)') $true
Check-Equal '⑨ 표본 유효성: 사망 판독 뒤 차단 플래그·실패 플래그·일련번호 셋을 대조' ($clearCode -match '(?s)\$death = Get-DeathScreenInfo -Game \$Game\s*\r?\n\s*\$deathValid = \(-not \$deathSampleBlocked\) -and \(-not \$script:screenCaptureFailing\) -and \(\$script:captureFailSerial -eq \$deathSampleSerial\)') $true
Check-Equal '⑨ 표본 유효성: 옛 판독 직전 기준(deathSerial)은 클리어 대기에 남지 않음' ($clearCode -match '\$deathSerial\b') $false
Check-Equal '⑨ 거점 필요 판정 = 전멸 ∨ 가루 부족 전환 ∨ 남은 횟수 0 (판독 실패 null 은 아님)' ($clearCode -match '\$checkpointNeeded = \[bool\]\(\$death\.Wiped -or \$reviveState\.StatueMode -or \(\(\$null -ne \$death\.Remaining\) -and \(\$death\.Remaining -le 0\)\)\)') $true
Check-Equal '⑨ 판정 호출이 유효성·거점 필요·상한·퇴장 허용(어비스만)·시각·예산을 전부 넘김' ($clearCode -match 'Resolve-ReviveSample -State \$reviveState -Valid \$deathValid -Dead \(\[bool\]\$death\.Dead\) -Wiped \(\[bool\]\$death\.Wiped\)\s*`\s*\r?\n\s*-CheckpointNeeded \$checkpointNeeded -CheckpointLimit \$reviveCheckpointLimit -LeaveOnLimit \(-not \$DungeonMode\)\s*`\s*\r?\n\s*-Now \(Get-Date\) -DispatchBudget \$reviveDispatchBudget') $true
Check-Equal '⑨ 전송 등록이 시각·정착 창 상수를 넘김 + 3초 대기 + continue' ($clearCode -match '(?s)if \(\$dispatchKind\) \{\s*\r?\n\s*Register-ReviveDispatch -State \$reviveState -Kind \$dispatchKind -Now \(Get-Date\) -SettleSeconds \$reviveSettleSeconds\s*\r?\n\s*Start-Sleep -Seconds 3\s*\r?\n\s*continue') $true
Check-Equal '⑨ 계상은 상태 머신 안 종류별 1곳씩 (가루/거점)' ('{0}/{1}' -f ([regex]::Matches($workerCode, 'PowderConfirmed\+\+').Count), ([regex]::Matches($workerCode, 'CheckpointConfirmed\+\+').Count)) '1/1'
Check-Equal '⑨ 클리어 마감 초기화는 선언·성공 확인·캡처 동결 3곳만 (전송 시점 초기화 제거)' (@([regex]::Matches($clearCode, '\$deadline = \(Get-Date\)\.AddSeconds\(\$TimeoutSeconds\)')).Count) 3
Check-Equal '⑨ 성공 확인 분기: 완료 로그 → 마감 초기화 → 마감 안내 플래그 초기화' ($clearCode -match "(?s)if \(\`$reviveAction -eq 'confirmed'\) \{[\s\S]{0,600}?부활 완료[\s\S]{0,300}?\`$deadline = \(Get-Date\)\.AddSeconds\(\`$TimeoutSeconds\)\s*\r?\n\s*\`$deadlineDeathLogged = \`$false\s*\r?\n\s*\} elseif") $true
$stopStart = $clearCode.IndexOf("if (`$reviveAction -eq 'stop-exhausted') {")
$stopEnd = $(if ($stopStart -ge 0) { $clearCode.IndexOf('exit 4', $stopStart) } else { -1 })
Check-Equal '⑨ stop 분기 존재 + exit 4 로 끝남' (($stopStart -ge 0) -and ($stopEnd -gt $stopStart) -and (($stopEnd - $stopStart) -lt 1500)) $true
$stopRegion = $(if ($stopEnd -gt $stopStart -and $stopStart -ge 0) { $clearCode.Substring($stopStart, $stopEnd - $stopStart) } else { '' })
$diagMax = [regex]::Matches($stopRegion, "Write-LifeDiagnostics -Game \`$Game -Context '자동 부활 상한 도달 뒤 사망' -CaptureOnly").Count
$diagBudget = [regex]::Matches($stopRegion, "Write-LifeDiagnostics -Game \`$Game -Context '부활 입력 예산 소진 뒤 사망 화면 지속' -CaptureOnly").Count
$doneLogs = [regex]::Matches($stopRegion, 'Write-RunLog "\[완료\]').Count
Check-Equal '⑨ stop 분기: 상한 진단 없음(폐기) + 예산 진단 1 + [완료] 사유 1줄' ('{0}/{1}/{2}' -f $diagMax, $diagBudget, $doneLogs) '0/1/1'
Check-Equal '⑨ stop 분기에 throw 없음 (코드 1 은 죽은 화면에 재시작을 붙임)' ($stopRegion -match '\bthrow\b') $false
Check-Equal '⑨ stop-max 분기·옛 상한 상수가 남아 있지 않다' (($workerCode -match "'stop-max'") -or ($workerCode -match '\$reviveMaxPerCycle')) $false
# ⑩ 퇴장 배선
Check-Equal '⑩ leave 분기: 퇴장 헬퍼가 left 면 클리어 대기가 left 를 반환, 아니면 재판정(continue)' ($clearCode -match "(?s)elseif \(\`$reviveAction -eq 'leave'\) \{[\s\S]{0,900}?if \(\(Invoke-AbyssDeathExit -Game \`$Game\) -eq 'left'\) \{ return 'left' \}[\s\S]{0,300}?continue") $true
# 2026-10-13 구현 명세 ② 2.3 (3.4 · 설계 R2 3.3 ④): 'left' 의 복귀 호출 줄 끝에 코드 10 출구의 열쇠 닫기 사유 ` -LeaveEntryReason 'abandoned-death-exit'` 가
#   붙었습니다 - 바로 아래 'left' 흐름 단언과 ⑬ 의 [완료] 문구 조합 단언은 그 꼬리를 정확히 그 글자로 받습니다(순서·나머지 그대로). 다른 사유·꼬리 없음은 둘 다 FAIL
# 2026-10-25 구현 명세 ⑤b5 W3 (3.4): 'left' 의 복귀 호출 안전 중지 코드가 식 `$(if ($script:finishOnly) { 4 } else { 10 })` 가 되고(마무리 실행은 exit 10 을 내지
#   않음 - 설계 v11 R2 M4 · R1 2.4), 원인 대입과 준비 실행 [완료] 줄 사이에 마무리 실행 갈래 if 블록([완료] 마무리 줄 + exit 4)이 섭니다. 아래 두 단언(⑩ · ⑬)은
#   그 식과 블록을 정확한 글자로 받습니다(다른 꼴 · 블록 없음은 FAIL - 지금 정밀도 유지)
Check-Equal '⑩ 어비스 본류: left → 선택 화면 복귀(안전 중지 코드 = 마무리 실행이면 4 · 아니면 10 · 열쇠 닫기 사유 abandoned-death-exit) → 마무리 실행이면 [완료] 마무리 줄 → exit 4 / 아니면 [완료] 준비 실행 → exit 10 (회차 미계상)' ($workerCode -match "(?s)\`$clearOutcome = Wait-ForDungeonClearScreen -Game \`$game -TimeoutSeconds \`$timeoutClear\s*\r?\n\s*if \(\`$clearOutcome -eq 'left'\) \{\s*\r?\n\s*Return-ToAbyssSelection -Game \`$game -SafeStopExitCode \`$\(if \(\`$script:finishOnly\) \{ 4 \} else \{ 10 \}\) -LeaveEntryReason 'abandoned-death-exit'\s*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*\`$leaveCause = [^\r\n]*\r?\n\s*if \(\`$script:finishOnly\) \{\s*\r?\n\s*Write-RunLog `"\[완료\] \`$\{leaveCause\} 던전을 나왔습니다 - 마무리 실행이라 다시 입장하지 않고 멈춥니다`"\s*\r?\n\s*exit 4\s*\r?\n\s*\}\s*\r?\n\s*Write-RunLog `"\[완료\] \`$\{leaveCause\} 던전을 나왔습니다[^\r\n]*준비 실행[^\r\n]*`"\s*\r?\n\s*exit 10") $true   # 09-26: [완료] 사유는 원인 조각(거점 상한 / 부활 불가 대기 초과) 조합
Check-Equal '⑩ 파티원: left → [완료] 사유(원인 조각 조합) → exit 4 (파티원은 퇴장 뒤 자동 재입장 흐름이 없음 - 코드 10 이면 30분 준비 대기 뒤 코드 1)' ($workerCode -match "(?s)if \(\`$clearOutcome -eq 'left'\) \{\s*\r?\n\s*\`$leaveCause = [^\r\n]*\r?\n\s*Write-RunLog `"\[완료\] 파티원: \`$\{leaveCause\} 던전을 나왔습니다[^\r\n]*자동 재입장 흐름이 없어[^\r\n]*`"\s*\r?\n\s*exit 4") $true
# ⑬ 부활 불가 화면 대기 (2026-09-26 03:13 실사고 - 파티 회차, 부활 제한 구역 남은 0회 + 파티 생존 → 거점 버튼 없음. 사용자 확정 설계)
Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-ReviveBlockedNoteText')))
Check-Equal '⑬ 안내 판정: 09-26 파티 캡처 실측(할→한 깨짐)' (Test-ReviveBlockedNoteText -Text '남은부활횟수가없어서부활한수없습니다.') $true
Check-Equal '⑬ 안내 판정: 실기 5 솔로 0회 프레임 실측(정상)' (Test-ReviveBlockedNoteText -Text '남은부활횟수가없어서부활할수없습니다.') $true
Check-Equal '⑬ 안내 판정: 공백·전투 프레임·버튼 영역 판독은 거짓 (여기서부활/성장가이드 조각 미사용)' ((@('', '0크로스+18', '되수-.”아난검은파도선원x38', '여기서부활9성장가이드', '여신상에서부활') | ForEach-Object { Test-ReviveBlockedNoteText -Text $_ }) -join ',') 'False,False,False,False,False'
$bs = New-ReviveState; $t0 = Get-Date '2026-09-26 03:13:00'
Check-Equal '⑬ 상태 머신: BlockedSince 없으면 기존과 동일 (dispatch)' (Resolve-ReviveSample -State $bs -Valid $true -Dead $true -Wiped $false -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $t0 -DispatchBudget 3) 'dispatch'
$bs.BlockedSince = $t0; $bs.BlockedFailMs = [double]1000; $bs.BlockedYieldMs = [double]2000; $bs.Dispatched = 3; $bs.CheckpointConfirmed = 3
Check-Equal '⑬ 상태 머신: 대기 중(599초)에는 예산 소진·상한(leave)보다 앞서 dispatch (호출부가 앵커 재탐색)' (Resolve-ReviveSample -State $bs -Valid $true -Dead $true -Wiped $false -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $t0.AddSeconds(599) -DispatchBudget 3 -CaptureFailTotalMs 1000 -YieldTotalMs 2000 -BlockedWaitSeconds 600) 'dispatch'
Check-Equal '⑬ 상태 머신: 600초 도달이면 blocked-timeout' (Resolve-ReviveSample -State $bs -Valid $true -Dead $true -Wiped $false -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $t0.AddSeconds(600) -DispatchBudget 3 -CaptureFailTotalMs 1000 -YieldTotalMs 2000 -BlockedWaitSeconds 600) 'blocked-timeout'
Check-Equal '⑬ 상태 머신: 캡처 실패 300초 + 양보 200초는 대기에서 뺀다 (1099초 경과여도 dispatch - 유효 599초)' (Resolve-ReviveSample -State $bs -Valid $true -Dead $true -Wiped $false -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $t0.AddSeconds(1099) -DispatchBudget 3 -CaptureFailTotalMs 301000 -YieldTotalMs 202000 -BlockedWaitSeconds 600) 'dispatch'
Check-Equal '⑬ 상태 머신: 같은 차감으로 유효 600초면 blocked-timeout (1100초 경과)' (Resolve-ReviveSample -State $bs -Valid $true -Dead $true -Wiped $false -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $t0.AddSeconds(1100) -DispatchBudget 3 -CaptureFailTotalMs 301000 -YieldTotalMs 202000 -BlockedWaitSeconds 600) 'blocked-timeout'
Check-Equal '⑬ 상태 머신: 무효 표본은 skip (대기 유지)' ((Resolve-ReviveSample -State $bs -Valid $false -Dead $true -Wiped $false -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $t0.AddSeconds(700) -DispatchBudget 3 -CaptureFailTotalMs 1000 -YieldTotalMs 2000 -BlockedWaitSeconds 600) + '/' + $(if ($null -ne $bs.BlockedSince) { 'kept' } else { 'reset' })) 'skip/kept'
Check-Equal '⑬ 상태 머신: 전멸 표본은 대기 해제 뒤 정상 판정 (예산 소진 상태라 stop-exhausted)' ((Resolve-ReviveSample -State $bs -Valid $true -Dead $false -Wiped $true -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $t0.AddSeconds(700) -DispatchBudget 3 -CaptureFailTotalMs 1000 -YieldTotalMs 2000 -BlockedWaitSeconds 600) + '/' + $(if ($null -eq $bs.BlockedSince) { 'reset' } else { 'kept' })) 'stop-exhausted/reset'
$bs.BlockedSince = $t0; $bs.BlockedLogged = $true
Check-Equal '⑬ 상태 머신: 생존 표본은 대기·안내 플래그 해제' ((Resolve-ReviveSample -State $bs -Valid $true -Dead $false -Wiped $false -CheckpointNeeded $false -CheckpointLimit 3 -LeaveOnLimit $true -Now $t0.AddSeconds(10) -DispatchBudget 3) + '/' + $(if ($null -eq $bs.BlockedSince -and -not $bs.BlockedLogged) { 'reset' } else { 'kept' })) 'cleared/reset'
Check-Equal '⑬ 배선: 상수 (대기 600초, 안내 영역 900,585,210,55)' (($workerCode -match '\$reviveBlockedWaitSeconds = 600') -and ($workerCode -match '\$rgReviveBlockedNote = @\(900, 585, 210, 55\)')) $true
$deathInfoFn = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-DeathScreenInfo')))
Check-Equal '⑬ 배선: 사망 판독은 개인 사망·전멸 아님·남은 0 또는 공백에서만 안내를 읽어 Blocked 로' ($deathInfoFn -match '(?s)\$info\.Blocked = \$false\s*\r?\n\s*if \(\$info\.Dead -and -not \$info\.Wiped -and \(\(\$null -eq \$info\.Remaining\) -or \(\$info\.Remaining -le 0\)\)\) \{[\s\S]{0,400}?\$rgReviveBlockedNote\[0\][\s\S]{0,300}?\$info\.Blocked = Test-ReviveBlockedNoteText -Text \$noteText') $true
Check-Equal '⑬ 배선: 판정 호출이 캡처 실패 누적·양보 누적·대기 상한을 넘김' ($clearCode -match 'Resolve-ReviveSample -State \$reviveState[\s\S]{0,400}?-CaptureFailTotalMs \(Get-CaptureFailTotalMs\) -YieldTotalMs \(\[double\]\$script:userYieldTotalMs\) -BlockedWaitSeconds \$reviveBlockedWaitSeconds') $true
Check-Equal '⑬ 배선: 안내·대기 중·같은 회전 거점 필요·에피소드 앵커 관측이면 판독 공백이어도 거점 경로 (R 헛전송 방지 - 2라운드 P2)' ($clearCode -match 'if \(\$reviveState\.StatueMode -or \(\$null -ne \$death\.Remaining -and \$death\.Remaining -le 0\) -or \$death\.Blocked -or \$blockedNow -or \$checkpointNeeded -or \$reviveState\.CheckpointSeen\) \{') $true
Check-Equal '⑬ 배선: 사전 블록이 앵커 적중·미탐 모두 CheckpointSeen 을 세움' ('{0}/{1}' -f ([regex]::Matches($clearCode, '\$reviveState\.CheckpointSeen = \$true').Count), [int]($clearCode -match '(?s)\} elseif \(\$preAnchorHit\) \{[\s\S]{0,400}?\$reviveState\.CheckpointSeen = \$true\s*\r?\n\s*\$checkpointNeeded = \$true[\s\S]{0,300}?\} else \{\s*\r?\n\s*\$blockedNow = \$true\s*\r?\n\s*\$reviveState\.CheckpointSeen = \$true')) '2/1'
$rsFn = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Resolve-ReviveSample')))
Check-Equal '⑬ 상태 머신: 생존 표본이 CheckpointSeen 도 해제' ($rsFn -match '\$State\.BlockedSince = \$null; \$State\.BlockedLogged = \$false; \$State\.CheckpointSeen = \$false\s*\r?\n\s*if \(\$State\.Pending\)') $true
$cs = New-ReviveState; $cs.CheckpointSeen = $true; $cs.BlockedSince = Get-Date '2026-09-26 03:13:00'
Check-Equal '⑬ 상태 머신: 생존 표본 뒤 CheckpointSeen·BlockedSince 해제' ((Resolve-ReviveSample -State $cs -Valid $true -Dead $false -Wiped $false -CheckpointNeeded $false -CheckpointLimit 3 -LeaveOnLimit $true -Now (Get-Date '2026-09-26 03:13:05') -DispatchBudget 3) + '/' + $(if (-not $cs.CheckpointSeen -and $null -eq $cs.BlockedSince) { 'reset' } else { 'kept' })) 'none/reset'
Check-Equal '⑬ 배선: 클릭 직전 재확인이 Blocked 면 예비 좌표 대신 대기 재확립(입력 없음), 아니면 기존 예비 좌표' ($clearCode -match '(?s)if \(\$recheckValid -and \$deadRecheck\.Dead -and -not \$deadRecheck\.Wiped -and \$deadRecheck\.Blocked\) \{\s*\r?\n\s*if \(\$null -eq \$reviveState\.BlockedSince\) \{\s*\r?\n\s*\$reviveState\.BlockedSince = Get-Date;[^\r\n]*\r?\n\s*\}\s*\r?\n\s*if \(-not \$reviveState\.BlockedLogged\) \{[\s\S]{0,400}?\}\s*\r?\n\s*\} elseif \(\$recheckValid -and \$deadRecheck\.Dead -and -not \$deadRecheck\.Wiped\) \{\s*\r?\n\s*Write-RunLog "\[경고\] 거점 부활 버튼 글자') $true
$recheckBlocked = [regex]::Match($clearCode, '(?s)-and \$deadRecheck\.Blocked\) \{(.*?)\} elseif \(\$recheckValid -and \$deadRecheck\.Dead').Groups[1].Value
Check-Equal '⑬ 배선: 재확인 Blocked 분기에 클릭·키 전송·시도 표시 없음' (($recheckBlocked -match 'Click-|Press-Key|dispatchAttempted = \$true')) $false
Check-Equal '⑬ 배선: 판정기 호출 직전에 거점 필요 판정이 CheckpointSeen 을 합침 (상한 leave 가 클릭 경로와 같은 근거 - 3라운드 P2)' ($clearCode -match '(?s)\$checkpointNeeded = \[bool\]\(\$checkpointNeeded -or \$reviveState\.CheckpointSeen\)\s*\r?\n\s*\$reviveAction = Resolve-ReviveSample -State \$reviveState') $true
$ws = New-ReviveState; $ws.CheckpointSeen = $true; $ws.BlockedSince = Get-Date '2026-09-26 03:13:00'
$wsAct = Resolve-ReviveSample -State $ws -Valid $true -Dead $false -Wiped $true -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now (Get-Date '2026-09-26 03:13:10') -DispatchBudget 3
Check-Equal '⑬ 상태 머신: 전멸 표본은 BlockedSince 만 해제하고 CheckpointSeen 은 유지 (같은 에피소드 - 생존 표본에서만 해제)' ($wsAct + '/' + $(if ($ws.CheckpointSeen -and $null -eq $ws.BlockedSince) { 'seen-kept,blocked-reset' } else { 'wrong' })) 'dispatch/seen-kept,blocked-reset'
$ls = New-ReviveState; $ls.CheckpointConfirmed = 3; $ls.CheckpointSeen = $true
Check-Equal '⑬ 상태 머신: 상한 도달 + 거점 필요(CheckpointSeen 합산)면 공백 표본에서도 leave' (Resolve-ReviveSample -State $ls -Valid $true -Dead $true -Wiped $false -CheckpointNeeded ([bool]($false -or $ls.CheckpointSeen)) -CheckpointLimit 3 -LeaveOnLimit $true -Now (Get-Date '2026-09-26 03:13:20') -DispatchBudget 3) 'leave'
Check-Equal '⑬ 배선: 부활 불가 상태는 판정기보다 앞에서 확정 - 안내 또는 대기 중이면 사전 앵커 탐색(일련번호 게이트) → 무효면 표본 무효 / 적중이면 대기 해제 + 거점 필요=참 / 미탐이면 대기 확립(시각·누적 기록·안내 1회)' ($clearCode -match '(?s)\$blockedNow = \$false\s*\r?\n\s*if \(\$deathValid -and \$death\.Dead -and -not \$death\.Wiped -and \(\$death\.Blocked -or \(\$null -ne \$reviveState\.BlockedSince\)\)\) \{\s*\r?\n\s*\$preAnchorSerial = \$script:captureFailSerial\s*\r?\n\s*\$preAnchorHit = Find-ReviveAnchorPoint -Game \$Game\s*\r?\n\s*\$preAnchorValid = \(-not \$script:screenCaptureFailing\) -and \(\$script:captureFailSerial -eq \$preAnchorSerial\)\s*\r?\n\s*if \(-not \$preAnchorValid\) \{\s*\r?\n\s*\$deathValid = \$false[\s\S]{0,300}?\} elseif \(\$preAnchorHit\) \{[\s\S]{0,400}?\$reviveState\.BlockedSince = \$null; \$reviveState\.BlockedLogged = \$false\s*\r?\n\s*\$reviveState\.CheckpointSeen = \$true[^\r\n]*\r?\n\s*\$checkpointNeeded = \$true[\s\S]{0,300}?\} else \{\s*\r?\n\s*\$blockedNow = \$true\s*\r?\n\s*\$reviveState\.CheckpointSeen = \$true\s*\r?\n\s*if \(\$null -eq \$reviveState\.BlockedSince\) \{\s*\r?\n\s*\$reviveState\.BlockedSince = Get-Date; \$reviveState\.BlockedFailMs = Get-CaptureFailTotalMs; \$reviveState\.BlockedYieldMs = \[double\]\$script:userYieldTotalMs') $true
Check-Equal '⑬ 배선: 사전 확정 블록이 판정기 호출보다 앞' (($clearCode.IndexOf('$blockedNow = $false') -gt 0) -and ($clearCode.IndexOf('$blockedNow = $false') -lt $clearCode.IndexOf('$reviveAction = Resolve-ReviveSample'))) $true
Check-Equal '⑬ 배선: 거점 경로는 대기 중이면 통째로 무입력(빈 분기) / 아닐 때만 전면화·앵커 탐색·클릭·예비 좌표' ($clearCode -match '(?s)\$statueReason = [^\r\n]*\r?\n\s*if \(\$blockedNow\) \{\s*\r?\n\s*\} else \{\s*\r?\n\s*Focus-Game -Game \$Game[\s\S]{0,1400}?\} elseif \(\$anchorHit\) \{\s*\r?\n\s*\$reviveState\.BlockedSince = \$null; \$reviveState\.BlockedLogged = \$false\s*\r?\n\s*\$dispatchAttempted = \$true') $true
Check-Equal '⑬ 배선: 옛 앵커 미탐 뒤 안내 분기(elseif $death.Blocked)는 남지 않음 (사전 확정 블록으로 이동)' ($clearCode -match 'elseif \(\$death\.Blocked\)') $false
$blockedNoop = [regex]::Match($clearCode, '(?s)if \(\$blockedNow\) \{(.*?)\} else \{\s*\r?\n\s*Focus-Game -Game \$Game').Groups[1].Value
Check-Equal '⑬ 배선: 대기 분기 본문에 클릭·키 전송·시도 표시가 없다 (시도 없는 회전)' (($blockedNoop -match 'Click-|Press-Key|dispatchAttempted = \$true')) $false
Check-Equal '⑬ 배선: blocked-timeout 분기 - 어비스는 원인 조각 뒤 퇴장 헬퍼(left 반환), 던전류는 진단 캡처 + [완료] + exit 4' ($clearCode -match "(?s)elseif \(\`$reviveAction -eq 'blocked-timeout'\) \{\s*\r?\n\s*if \(-not \`$DungeonMode\) \{[\s\S]{0,300}?\`$script:abyssLeaveCause = '부활 불가 화면 대기 초과로'\s*\r?\n\s*if \(\(Invoke-AbyssDeathExit -Game \`$Game\) -eq 'left'\) \{ return 'left' \}[\s\S]{0,400}?continue\s*\r?\n\s*\}\s*\r?\n\s*Write-LifeDiagnostics -Game \`$Game -Context '부활 불가 화면 대기 초과' -CaptureOnly\s*\r?\n\s*Write-RunLog `"\[완료\] 부활 불가 화면[^\r\n]*`"\s*\r?\n\s*exit 4") $true
Check-Equal '⑬ 배선: leave 분기도 원인 조각을 둔다 (퇴장 헬퍼 호출 앞)' ($clearCode -match "(?s)elseif \(\`$reviveAction -eq 'leave'\) \{[\s\S]{0,600}?\`$script:abyssLeaveCause = '거점 부활 상한으로'[\s\S]{0,400}?Invoke-AbyssDeathExit -Game \`$Game") $true
Check-Equal '⑬ 배선: 어비스 본류 [완료] 문구가 원인 조각으로 조합 (기본 거점 부활 상한으로 · 마무리 실행 갈래 블록도 같은 조각)' ($workerCode -match "(?s)Return-ToAbyssSelection -Game \`$game -SafeStopExitCode \`$\(if \(\`$script:finishOnly\) \{ 4 \} else \{ 10 \}\) -LeaveEntryReason 'abandoned-death-exit'\s*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*\`$leaveCause = \`$\(if \(\`$script:abyssLeaveCause\) \{ \`$script:abyssLeaveCause \} else \{ '거점 부활 상한으로' \}\)\s*\r?\n\s*if \(\`$script:finishOnly\) \{\s*\r?\n\s*Write-RunLog `"\[완료\] \`$\{leaveCause\} 던전을 나왔습니다 - 마무리 실행이라 다시 입장하지 않고 멈춥니다`"\s*\r?\n\s*exit 4\s*\r?\n\s*\}\s*\r?\n\s*Write-RunLog `"\[완료\] \`$\{leaveCause\} 던전을 나왔습니다 - 선택 화면 복귀 완료[^\r\n]*`"\s*\r?\n\s*exit 10") $true
Check-Equal "⑩ settling 은 사망 화면 - 아래 감시로 내려가지 않고 800ms 뒤 continue" ($clearCode -match "(?s)elseif \(\`$reviveAction -eq 'settling'\) \{\s*\r?\n\s*Start-Sleep -Milliseconds 800\s*\r?\n\s*continue") $true
Check-Equal "⑩ R키 전면 미확인은 사용자 조작 중이면 user-active 사유 (규칙 4)" ($clearCode -match "\`$dispatchSkipReason = \`$\(if \(Test-UserRecentlyActive\) \{ 'user-active' \} else \{ 'foreground' \}\)") $true
Check-Equal "⑩ 생략 헬퍼 호출이 양보 누적을 넘김" ($clearCode -match 'Resolve-ReviveDispatchSkip -State \$reviveState -Reason \$dispatchSkipReason -Now \(Get-Date\) -YieldTotalMs \(\[double\]\$script:userYieldTotalMs\)') $true
# 2026-10-13 구현 명세 ② 2.3 (3.4 · 부록 B-16): 옛 단언은 주석 뺀 사본에서 `if ($clearOutcome -eq 'left') {` 부터 `.{0,600}?exit 10` 창을 잘라 마커를 찾았습니다.
#   'left' 복귀 호출에 ` -LeaveEntryReason 'abandoned-death-exit'`(41자)가 붙으면 창 안이 566 → 607자라 일치가 없고, 빈 값('')이 기대 거짓과 늘 같아져
#   마커를 넣어도 통과합니다(빈 참). 그래서 창 대신 AST 로 본류(함수 밖)의 'left' if 블록을 잘라 블록 1개를 먼저 단언하고, 그 본문(주석 뺀 사본)에서 마커를
#   봅니다 - 파티원 사이클의 같은 조건 if 는 함수 안이라 뺍니다(그 블록은 exit 4). 블록이 없으면 마커 단언도 '(블록 없음)' 으로 FAIL
$leftWorkerAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$mainLeftIfs = @($leftWorkerAst.FindAll({ param($node)
      ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq "`$clearOutcome -eq 'left'") }, $true) | Where-Object {
      $leftInsideFunction = $false
      for ($leftAncestor = $_.Parent; $null -ne $leftAncestor; $leftAncestor = $leftAncestor.Parent) {
        if ($leftAncestor -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $leftInsideFunction = $true }
      }
      -not $leftInsideFunction })
Check-Equal "⑩ 본류 left 분기 - 함수 밖 'left' if 블록 1개 (아래 마커 단언의 대상 - 창 단언의 빈 참 방지, ② 2.3)" $mainLeftIfs.Count 1
$mainLeftMarker = $(if ($mainLeftIfs.Count -eq 1) { [bool]((Remove-SourceComments -Text $mainLeftIfs[0].Clauses[0].Item2.Extent.Text) -match 'Write-CustomClearMarker') } else { '(블록 없음)' })
Check-Equal '⑩ 본류 left 분기는 커스텀 클리어 마커를 쓰지 않는다 (클리어가 아님)' $mainLeftMarker $false
$exitBody = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-AbyssDeathExit')))
Check-Equal '⑩ 퇴장 헬퍼: 캡처 실패 동결(안전 중지 진입점 + 복구 탐침 + 마감 되돌림 + continue)' ($exitBody -match '(?s)if \(\$script:screenCaptureFailing\) \{\s*\r?\n\s*Test-SafeStopDuringCaptureFail\s*\r?\n\s*Start-Sleep -Seconds 2\s*\r?\n\s*\[void\]\(Test-CaptureRecovered -Game \$Game\)\s*\r?\n\s*\$deadline = \(Get-Date\)\.AddSeconds\(\$TimeoutSeconds\)\s*\r?\n\s*\$seenYieldMs = \[double\]\$script:userYieldTotalMs\s*\r?\n\s*continue') $true
Check-Equal '⑩ 퇴장 헬퍼: 마감은 양보 차분 반영 + 초과는 진단 캡처 뒤 throw' ($exitBody -match '(?s)Get-YieldAdjustedDeadline -Deadline \(\[ref\]\$deadline\) -SeenYieldMs \(\[ref\]\$seenYieldMs\)[\s\S]{0,900}?Write-LifeDiagnostics[\s\S]{0,200}?throw') $true   # 09-25: 사이에 캡처 탐침 + 주석 (구현 리뷰 2차)
Check-Equal '⑩ 퇴장 헬퍼: 조작 중이면 양보(Wait-UserYieldEnd) + 연속 수 초기화' ($exitBody -match 'if \(Test-UserRecentlyActive\) \{ \$fieldStreak = 0; \$insideStreak = 0; Wait-UserYieldEnd -Game \$Game -Context') $true
Check-Equal "⑩ 퇴장 헬퍼: '나가기' 는 팝업 제목(Test-AbyssExitPopupText)이 확인된 뒤 버튼 영역에서 글자 위치 클릭, 전송 여부로 계수" ($exitBody -match "(?s)if \(Test-AbyssExitPopupText -Text \`$popupTitle\) \{[\s\S]{0,400}?Find-GameTextPoint -Game \`$Game -ReferenceX \`$rgAbyssExitPopupButtons\[0\][\s\S]{0,300}?-SearchText '나가기'[\s\S]{0,400}?Click-ScreenPoint -X \`$exitWord\.X -Y \`$exitWord\.Y\s*\r?\n\s*if \(\`$script:lastClickPerformed\) \{ \`$exitClicks\+\+") $true
Check-Equal '⑩ 퇴장 헬퍼: 문 아이콘은 사망·전멸 화면이 유효하게 확인될 때만 (팝업 분기 뒤)' ($exitBody -match '(?s)\$death = Get-DeathScreenInfo -Game \$Game\s*\r?\n\s*if \(\$script:screenCaptureFailing -or \$script:captureFailSerial -ne \$deathSerial\) \{ continue \}\s*\r?\n\s*if \(\$death\.Dead -or \$death\.Wiped\) \{[\s\S]{0,300}?Click-GamePoint -Game \$Game -ReferenceX \$ptAbyssDeathExit\[0\] -ReferenceY \$ptAbyssDeathExit\[1\]') $true
Check-Equal '⑩ 퇴장 헬퍼: 키 입력(Space 등) 없음 - 위험 화면 오입력 금지' ($exitBody -match 'Press-Key|keybd_event|SendKeys') $false
Check-Equal "⑩ 퇴장 헬퍼: 필드 2연속은 '나가기' 를 보낸 뒤에만 left, 안 보냈으면 stay (던전 안 필드 오판 방어) / 던전 안 2연속(나가기 전) → stay, 나가기 뒤면 관측 경고 1회 + 재시도(규칙 8)" ($exitBody -match "(?s)if \(\`$fieldStreak -ge 2\) \{\s*\r?\n\s*if \(\`$exitClicks -gt 0\) \{[\s\S]{0,200}?return 'left'\s*\r?\n\s*\}\s*\r?\n\s*return 'stay'[\s\S]{0,200}?if \(\`$insideStreak -ge 2\) \{\s*\r?\n\s*if \(\`$exitClicks -eq 0\) \{ return 'stay' \}\s*\r?\n\s*if \(-not \`$insideAfterExitLogged\) \{[\s\S]{0,600}?\`$insideAfterExitLogged = \`$true") $true
# ⑫ 구현 리뷰 2차 반영 배선 (2026-09-25 밤)
Check-Equal '⑫ 마감 블록: 진입 전 일련번호 기록' ($clearCode -match '(?s)\$deadlineSerial = \$script:captureFailSerial\s*\r?\n\s*if \(\(Get-Date\) -ge \$deadline\) \{') $true
Check-Equal '⑫ 마감 블록: 사망 표본 탐침 뒤(전투 연장 앞)에 플래그∨일련번호 동결 분기' ($clearCode -match '(?s)\} elseif \(\$reviveEnabled -and \(\$reviveState\.Pending -or \(Test-DeathScreenValid -Game \$Game\)\)\) \{[\s\S]{0,600}?\} elseif \(\$script:screenCaptureFailing -or \(\$script:captureFailSerial -ne \$deadlineSerial\)\) \{\s*\r?\n\s*\} elseif \(\(Get-Date\) -lt \$extendLimit') $true
# 2026-09-30 ⑥e 설계 3절 4: 파티원(-MemberMode) 마감 탐침 뒤에 같은 모양의 동결 분기가 하나 더 붙어 4 → 5 (비파티원에게는 탐침이 단락돼 무동작 -
#   탐침 도중 같은 회전 실패 → 복구면 종료를 확정하지 않고 동결에 맡김, 규칙 15). 개수는 test_audit_fixes 의 '캡처 실패 분기 6곳' 과 짝입니다
Check-Equal '⑫ 마감 블록: 동결 분기 5곳 전부 일련번호 대조 (탐침 사이 실패를 뒤 성공이 가리지 못함)' ([regex]::Matches($clearCode, '\} elseif \(\$script:screenCaptureFailing -or \(\$script:captureFailSerial -ne \$deadlineSerial\)\) \{').Count) 5
Check-Equal '⑫ 마감 블록: 플래그만 보는 elseif 는 남지 않음' ([regex]::Matches($clearCode, '\} elseif \(\$script:screenCaptureFailing\) \{').Count) 0
Check-Equal '⑫ 퇴장 헬퍼: 회전 서두에서 생략 사유 비움 (규칙 4)' ($exitBody -match '(?s)\$turnSerial = \$script:captureFailSerial\s*\r?\n\s*\$script:lastClickSkipReason = ''''\s*\r?\n\s*if \(\$script:screenCaptureFailing\)') $true
Check-Equal '⑫ 퇴장 헬퍼: 조작 양보가 마감 판정보다 앞' ($exitBody -match '(?s)if \(Test-UserRecentlyActive\) \{ \$fieldStreak = 0; \$insideStreak = 0; Wait-UserYieldEnd -Game \$Game -Context ''던전 퇴장''; continue \}\s*\r?\n\s*if \(\(Get-Date\) -ge \(Get-YieldAdjustedDeadline') $true
Check-Equal "⑫ 퇴장 헬퍼: 두 클릭('나가기'·문 아이콘) 모두 user-active 생략이면 양보 뒤 continue (마감 미소비)" ([regex]::Matches($exitBody, "elseif \(\`$script:lastClickSkipReason -eq 'user-active'\) \{[^\r\n]*Wait-UserYieldEnd -Game \`$Game -Context '던전 퇴장'; continue \}").Count) 2
Check-Equal "⑫ 퇴장 헬퍼: '나가기' 클릭 직후 전송 판정 → 바로 다음 줄이 user-active 양보 (지역 짝)" ($exitBody -match "(?s)Click-ScreenPoint -X \`$exitWord\.X -Y \`$exitWord\.Y\s*\r?\n\s*if \(\`$script:lastClickPerformed\) \{ \`$exitClicks\+\+; \`$lastExitClickAt = Get-Date;[^\r\n]*\}\s*\r?\n\s*elseif \(\`$script:lastClickSkipReason -eq 'user-active'\) \{ \`$fieldStreak = 0; \`$insideStreak = 0; Wait-UserYieldEnd") $true
Check-Equal "⑫ 퇴장 헬퍼: 문 아이콘 클릭 뒤 전송 판정 블록 → 바로 user-active 양보 (지역 짝)" ($exitBody -match "(?s)Click-GamePoint -Game \`$Game -ReferenceX \`$ptAbyssDeathExit\[0\] -ReferenceY \`$ptAbyssDeathExit\[1\]\s*\r?\n\s*if \(\`$script:lastClickPerformed\) \{[\s\S]{0,400}?\}\s*\r?\n\s*elseif \(\`$script:lastClickSkipReason -eq 'user-active'\) \{ Wait-UserYieldEnd -Game \`$Game -Context '던전 퇴장'; continue \}\s*\r?\n\s*Start-Sleep -Milliseconds 1500") $true
Check-Equal '⑫ 퇴장 헬퍼: 마감 확정 전 캡처 탐침(Test-CaptureRecovered) - 실패면 continue (서두 동결이 마감 되돌림), 성공 뒤에만 진단·throw' ($exitBody -match '(?s)if \(\(Get-Date\) -ge \(Get-YieldAdjustedDeadline[^\r\n]*\r?\n\s*if \(-not \(Test-CaptureRecovered -Game \$Game\)\) \{ continue \}\s*\r?\n\s*Write-LifeDiagnostics -Game \$Game -Context ''던전 퇴장 확인 초과'' -CaptureOnly\s*\r?\n\s*throw') $true
Check-Equal '⑫ 기준 변수 대입은 각 1회 (탐침 뒤에서 덮어쓰지 않음 - 리뷰 보강)' ('{0}/{1}/{2}' -f ([regex]::Matches($clearCode, '\$deathSampleSerial = ').Count), ([regex]::Matches($clearCode, '\$deathSampleBlocked = ').Count), ([regex]::Matches($clearCode, '\$deadlineSerial = ').Count)) '1/1/1'
Check-Equal '⑫ 퇴장 헬퍼: 회전 일련번호 대입 1회 + 마지막 나가기 시각 기록' ('{0}/{1}' -f ([regex]::Matches($exitBody, '\$turnSerial = ').Count), ([regex]::Matches($exitBody, '\$lastExitClickAt = Get-Date').Count)) '1/1'
Check-Equal '⑫ 퇴장 헬퍼: 팝업 회전이 필드/던전 안 연속을 끊음' ($exitBody -match '(?s)if \(Test-AbyssExitPopupText -Text \$popupTitle\) \{\s*\r?\n\s*\$fieldStreak = 0; \$insideStreak = 0') $true
Check-Equal '⑫ 퇴장 헬퍼: 관측 경고 플래그 선언' ($exitBody -match '\$insideAfterExitLogged = \$false') $true
Check-Equal '⑩ 팝업 제목 판정: 실측 제목' (Test-AbyssExitPopupText -Text '던전에서 퇴장하시겠습니까?') $true
Check-Equal '⑩ 팝업 제목 판정: 공백 제거·조각' (Test-AbyssExitPopupText -Text '던전에서 퇴장 하시겠') $true
Check-Equal '⑩ 팝업 제목 판정: 음성 - 빈 문자열/사망 안내/보상 나가기/전멸 재도전 문구' ((@('', '행동불능 부활 제한 구역입니다', '나가기 다시 하기', '마지막 캠프파이어에서부터 재도전하시겠습니까?') | ForEach-Object { Test-AbyssExitPopupText -Text $_ }) -join ',') 'False,False,False,False'
Check-Equal '⑩ 팝업 제목 판정: 실기 2 오프라인 재현 판독(제목+본문) 3장·수동 캡처 1장' ((@('던전에서퇴장하ÅI겠습LI)가?완료하지못한도전이있습니다.', '던전에서퇴장하kl겠습LI)가?완료하天l못한도전이있습니다.', '완료하지못한도전이있습니다.', '-00') | ForEach-Object { Test-AbyssExitPopupText -Text $_ }) -join ',') 'True,True,True,False'
Check-Equal '⑩ 팝업 제목 영역 기본값은 제목+본문을 덮는 (400,440,470,110) (실기 2: (420,465,430,55)는 실제 팝업에서 -00)' ($workerCode -match "\`$rgAbyssExitPopupTitle   = @\(Get-ConfigValue \`$config @\('ocrRegions', 'abyssExitPopupTitle'\) @\(400, 440, 470, 110\)\)") $true
Check-Equal '⑩ 좌표·영역 config 키 (실측 1229,62 / 팝업 제목·버튼 줄)' ($workerCode -match "\`$ptAbyssDeathExit  = @\(Get-ConfigValue \`$config @\('clickPoints', 'abyssDeathExit'\) @\(1229, 62\)\)") $true
Check-Equal '⑨ 팝업 훅: 가루 부활 pending 에서만 거점 전환 헬퍼' ($clearCode -match "if \(\`$reviveState\.Pending -and \`$reviveState\.PendingKind -eq '가루 부활'\) \{\s*\r?\n\s*Register-RevivePurchasePopup -State \`$reviveState") $true
Check-Equal '⑨ 팝업 검사는 사망 에피소드 중 매 폴 (짝수 폴 게이트에 Episode 병기)' ($clearCode -match 'if \(\(\(\$pollCounter % 2\) -eq 0 -or \$reviveState\.Episode\) -and -not \$script:screenCaptureFailing\) \{') $true
Check-Equal '⑨ 앵커 탐색 2곳 전부 정착 게이트(에피소드 1.5초) 안에서 일련번호 게이트 (정착 전·무효면 시도·미탐·예산 불변)' (@([regex]::Matches($clearCode, '(?s)\$anchorSerial = \$script:captureFailSerial\s*\r?\n\s*\$\w+ = \$null; \$anchorValid = \$false\s*\r?\n\s*if \(\(Get-ReviveEpisodeAgeMs -State \$reviveState -Now \(Get-Date\)\) -ge \$reviveAnchorSettleMs\) \{\s*\r?\n\s*\$\w+ = Find-ReviveAnchorPoint -Game \$Game\s*\r?\n\s*\$anchorValid = \(-not \$script:screenCaptureFailing\) -and \(\$script:captureFailSerial -eq \$anchorSerial\)\s*\r?\n\s*\}\s*\r?\n\s*if \(-not \$anchorValid\) \{')).Count) 2
$settleAnchorMatch = [regex]::Match($workerCode, '(?m)^\$reviveAnchorSettleMs = (\d+)\s*$')
Check-Equal '상수: 거점 버튼 등장 정착 1500ms (실기 2 첫 클릭 미수신 3/3, 실기 1 등장 2초 뒤 클릭 4/4)' ('{0}/{1}' -f $settleAnchorMatch.Success, $settleAnchorMatch.Groups[1].Value) 'True/1500'
# 에피소드 시작 시각: 첫 유효 사망 표본에서 기록, 같은 에피소드에서는 유지, 종료(confirmed/cleared)에서 해제
$r = Run-Scenario @('D@10', 'ok:가루 부활@11', 'D@16', 'ok:가루 부활@17', 'A@21')
Check-Equal '⑥ 에피소드 시작 시각은 첫 사망 표본(10초)에서 잡고 재전송에도 유지, 확인 뒤 해제' ('{0}/{1}' -f (($r.State.EpisodeSince -eq $null)), 'x') 'True/x'
$s2 = New-ReviveState; $base2 = [datetime]'2026-01-01 00:00:00'
[void](Resolve-ReviveSample -State $s2 -Valid $true -Dead $true -Wiped $false -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $base2.AddSeconds(10) -DispatchBudget $budget)
$age1 = Get-ReviveEpisodeAgeMs -State $s2 -Now $base2.AddSeconds(10.8)
Register-ReviveDispatch -State $s2 -Kind '여신상 부활' -Now $base2.AddSeconds(12) -SettleSeconds $settle
[void](Resolve-ReviveSample -State $s2 -Valid $true -Dead $true -Wiped $false -CheckpointNeeded $true -CheckpointLimit 3 -LeaveOnLimit $true -Now $base2.AddSeconds(17) -DispatchBudget $budget)
$age2 = Get-ReviveEpisodeAgeMs -State $s2 -Now $base2.AddSeconds(17.5)
Check-Equal '⑥ 에피소드 경과: 시작 0.8초 뒤 800ms(정착 전), 재전송 뒤에도 시작 시각 기준 7500ms' ('{0}/{1}' -f [int]$age1, [int]$age2) '800/7500'
Check-Equal '⑥ 에피소드 밖의 경과는 아주 큰 값 (정착 게이트를 막지 않음)' ((Get-ReviveEpisodeAgeMs -State (New-ReviveState) -Now $base2) -ge 100000) $true
Check-Equal '⑨ 개인 예비 좌표 직전 재확인: 일련번호 게이트 + 개인 사망(전멸 아님)에서만' ($clearCode -match '(?s)\$recheckSerial = \$script:captureFailSerial\s*\r?\n\s*\$deadRecheck = Get-DeathScreenInfo -Game \$Game\s*\r?\n\s*\$recheckValid = \(-not \$script:screenCaptureFailing\) -and \(\$script:captureFailSerial -eq \$recheckSerial\)\s*\r?\n\s*if \(\$recheckValid -and \$deadRecheck\.Dead -and -not \$deadRecheck\.Wiped -and \$deadRecheck\.Blocked\) \{[\s\S]{0,900}?\} elseif \(\$recheckValid -and \$deadRecheck\.Dead -and -not \$deadRecheck\.Wiped\) \{[\s\S]{0,700}ptStatueRevive\[0\]') $true   # 09-26: Blocked 선행 분기(대기 재확립) 뒤 예비 좌표
Check-Equal '⑨ 개인 예비 좌표 조건에 Dead -or Wiped 가 남아 있지 않다' ($clearCode -match '\$deadRecheck\.Dead -or \$deadRecheck\.Wiped') $false
Check-Equal '⑨ 시도 없는 회전은 연속 끊기 (Register-ReviveNoAttempt) 뒤 800ms + continue' ($clearCode -match '(?s)\} else \{\s*\r?\n\s*Register-ReviveNoAttempt -State \$reviveState\s*\r?\n\s*\}\s*\r?\n\s*Start-Sleep -Milliseconds 800\s*\r?\n\s*continue') $true
Check-Equal '⑨ 생략 안내는 사유군이 바뀔 때마다 (SkipLoggedReason 대조)' ($clearCode -match '(?s)\$skipGroup = \$\(if \(\$skipOutcome -eq ''yield''\) \{ ''user'' \} else \{ ''auto'' \}\)\s*\r?\n\s*if \(\$reviveState\.SkipLoggedReason -ne \$skipGroup\) \{\s*\r?\n\s*\$reviveState\.SkipLoggedReason = \$skipGroup') $true
$diagWipeFlag = [regex]::Matches($clearCode, "if \(-not \`$wipeAnchorDiagDone\) \{ \`$wipeAnchorDiagDone = \`$true; Write-LifeDiagnostics -Game \`$Game -Context '전멸 거점 부활 앵커 미탐'").Count
$diagDeadFlag = [regex]::Matches($clearCode, "if \(-not \`$reviveAnchorDiagDone\) \{ \`$reviveAnchorDiagDone = \`$true; Write-LifeDiagnostics -Game \`$Game -Context '거점 부활 앵커 미탐'").Count
Check-Equal '⑨ 진단 플래그 분리: 전멸/개인 각각 1곳' ('{0}/{1}' -f $diagWipeFlag, $diagDeadFlag) '1/1'
Check-Equal '⑨ 바닥 동결 블록은 마감만 되돌림 (회전 표식 $freezeMark 제거)' (($clearCode -match '(?s)Test-SafeStopDuringCaptureFail\s*\r?\n\s*\$deadline = \(Get-Date\)\.AddSeconds\(\$TimeoutSeconds\)\s*\r?\n\s*\}') -and ($clearCode -notmatch '\$freezeMark')) $true
Check-Equal '⑨ 캡처 복구 등록이 끝난 구간을 누적 (Register-CaptureSuccess)' ((Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Register-CaptureSuccess')))) -match '(?s)if \(\$script:screenCaptureFailing\) \{\s*\r?\n\s*if \(\$script:captureFailingSince\) \{ \$script:captureFailTotalMs = \[double\]\$script:captureFailTotalMs \+ \(\(Get-Date\) - \$script:captureFailingSince\)\.TotalMilliseconds \}\s*\r?\n\s*\$script:screenCaptureFailing = \$false') $true
$clickBody = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Click-ScreenPoint')))
Check-Equal '⑪ 클릭 함수: 커서 이동 확인 뒤 자기 입력 등록 → 250ms → 주입 직전 관측 → 클릭 → 자기 입력 등록 (커서 이동 되돌림이 사용자 후보가 되지 않게 - 실기 3)' ($clickBody -match "(?s)if \(-not \`$cursorReady\) \{ \`$script:lastClickSkipReason = 'cursor-not-ready'; return \}\s*\r?\n\s*Register-SelfInput\s*\r?\n\s*Start-Sleep -Milliseconds 250\s*\r?\n\s*Update-UserInputObservation\s*\r?\n\s*\[HoneyNogiInput\]::mouse_event\(0x0002[\s\S]{0,200}?Register-SelfInput") $true
Check-Equal '⑨ 옛 변수 잔존 없음 (reviveCount/reviveConfirmPending/useStatueRevive/reviveBlockedLogged/reviveDispatchDeadline/SkipDeadline)' (@([regex]::Matches($workerCode, '\$(reviveCount|reviveConfirmPending|useStatueRevive|reviveBlockedLogged|reviveDispatchDeadline)\b|SkipDeadline')).Count) 0
$configText = [IO.File]::ReadAllText((Join-Path $root 'config.json'))
Check-Equal '⑨ config: schema 12(이 상태 머신이 10, 10-08 커스텀 진행 세대가 11, 12 = ui.theme), maxPerCycle 제거, checkpointReviveLimit 3 + 설명(거점·재입장), 퇴장 좌표·영역 키' (('{0}/{1}/{2}/{3}/{4}' -f ($configText -match '"configSchemaVersion":\s*12,'), ($configText -match 'maxPerCycle'), ($configText -match '"_checkpointReviveLimit":\s*"[^"]*거점[^"]*재입장[^"]*",\s*\r?\n\s*"checkpointReviveLimit":\s*3,'), ($configText -match '"abyssDeathExit":'), (($configText -match '"abyssExitPopupTitle":') -and ($configText -match '"abyssExitPopupButtons":')))) 'True/False/True/True/True'
$guiText = [IO.File]::ReadAllText((Join-Path $root 'mabinogi_gui.ps1'))
Check-Equal '⑨ GUI 저장의 revive 신규 객체는 checkpointReviveLimit 을 UI 값으로 쓰고 maxPerCycle 은 없음 (09-26 GUI 노출)' (('{0}/{1}/{2}' -f ($guiText -match 'checkpointReviveLimit = \[int\]\$numCheckpointLimit\.Value'), ($guiText -match '\$numCheckpointLimit\.Value = 3'), ($guiText -match 'maxPerCycle'))) 'True/True/False'

if ($fails -gt 0) { "FAIL 합계 $fails" }
exit $fails
