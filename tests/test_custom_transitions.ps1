# 커스텀 반복 - 전환 규칙 검증(Get-CustomTransitionIssues) 진리표 (2026-07-20 실기 실측 기반)
# 본체 순수 함수를 AST로 직접 불러옵니다. 호출부는 btnStart 게이트(시작 거부) +
#            btnCrAdd 경고(추가 허용). 실측 근거: '다시 하기' 화면은 같은 층 구역만 선택 가능,
#            1층→2층은 1-3 '다음 층으로'만, 2층→1층 불가('나가기'는 필드행이라 금지).
# 위반 규칙: ① 2층→1층 금지 ② 1층→2층은 출발이 1-3일 때만. 같은 층/같은 구역 항상 허용.
# 바퀴 순환(마지막→첫)은 리스트 반복이 무한이거나 2바퀴 이상일 때만 검사.
$fails = 0

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Get-CustomTransitionIssues')) {
  Invoke-Expression $definition
}

function NewItem([string]$d, [string]$s) {
  [pscustomobject]@{ difficulty = $d; stage = $s; coin = $false; doubleLoot = $false
    exhaustContinue = $false; noDoubleSweep = $false }
}

function Check([string]$name, $items, [string]$rep, [int]$laps, [int]$expectCount, [string]$expectWraps) {
  # expectWraps: 위반들의 Wrap 플래그를 순서대로 '1'/'0' 으로 이은 문자열 (기대 위반 0건이면 '')
  $r = @(Get-CustomTransitionIssues -Items $items -ListRepeat $rep -ListRepeatCount $laps)
  $wraps = (@($r | ForEach-Object { if ([bool]$_.Wrap) { '1' } else { '0' } }) -join '')
  if ($r.Count -eq $expectCount -and $wraps -eq $expectWraps) {
    Write-Host ("PASS {0} (count={1} wraps='{2}')" -f $name, $r.Count, $wraps)
  } else {
    Write-Host ("FAIL {0}: got count={1} wraps='{2}' expected count={3} wraps='{4}'" -f $name, $r.Count, $wraps, $expectCount, $expectWraps)
    foreach ($i in $r) { Write-Host ("     {0} -> {1} wrap={2} : {3}" -f $i.From, $i.To, $i.Wrap, $i.Reason) }
    $script:fails++
  }
}

# 1) 같은 층만 - 무한: 위반 0 (같은 층 역방향 1-2→1-1 포함 - 실측: 다시 하기 화면에서 선택 가능)
Check 'same-floor-infinite' @((NewItem '일반' '1-1'), (NewItem '어려움' '1-2'), (NewItem '일반' '1-1')) 'infinite' 1 0 ''
# 2) 1-3 → 2-1 (다음 층으로) - 1바퀴: 위반 0
Check 'ladder-1lap' @((NewItem '일반' '1-3'), (NewItem '일반' '2-1')) 'count' 1 0 ''
# 3) 같은 리스트 - 무한: 바퀴 순환 2-1→1-3 이 2층→1층 위반 (Wrap=true)
Check 'ladder-infinite-wrap' @((NewItem '일반' '1-3'), (NewItem '일반' '2-1')) 'infinite' 1 1 '1'
# 4) 같은 리스트 - 횟수 2바퀴: 순환 전환이 실제로 발생하므로 wrap 위반
Check 'ladder-2laps-wrap' @((NewItem '일반' '1-3'), (NewItem '일반' '2-1')) 'count' 2 1 '1'
# 5) 2-3 → 1-2 연속 위반 (2층→1층 금지)
Check 'down-transition' @((NewItem '어려움' '2-3'), (NewItem '일반' '1-2')) 'count' 1 1 '0'
# 6) 1-1 → 2-1 연속 위반 (1-3 아닌 1층→2층)
Check 'up-not-from-1-3' @((NewItem '일반' '1-1'), (NewItem '일반' '2-1')) 'count' 1 1 '0'
# 7) 단일 항목 - 무한: 자기 자신 순환 = 같은 구역이라 항상 허용
Check 'single-infinite' @((NewItem '어려움' '2-3')) 'infinite' 1 0 ''
# 8) 2층만 - 무한: 위반 0
Check 'floor2-only' @((NewItem '일반' '2-1'), (NewItem '어려움' '2-3')) 'infinite' 1 0 ''
# 9) 복합 사다리 1-1,1-3,2-1,2-3 - 무한: wrap(2-3→1-1) 위반 1건만
Check 'full-ladder-infinite' @((NewItem '일반' '1-1'), (NewItem '일반' '1-3'), (NewItem '일반' '2-1'), (NewItem '어려움' '2-3')) 'infinite' 1 1 '1'
# 10) 같은 복합 사다리 - 1바퀴: 순환 미검사 → 위반 0 (혼합 리스트 1바퀴 전용 규칙의 허용면)
Check 'full-ladder-1lap' @((NewItem '일반' '1-1'), (NewItem '일반' '1-3'), (NewItem '일반' '2-1'), (NewItem '어려움' '2-3')) 'count' 1 0 ''
# 11) 빈 리스트: 위반 0 (빈 배열 반환 - 호출부 @() 규약)
Check 'empty' @() 'infinite' 1 0 ''
# 12) 다중 위반: 2-1,1-1,2-2 - 1바퀴 → 2-1→1-1(하강) + 1-1→2-2(1-3 아님) = 2건, 순환 미검사
Check 'multi-violation' @((NewItem '일반' '2-1'), (NewItem '일반' '1-1'), (NewItem '일반' '2-2')) 'count' 1 2 '00'
# 13) 난이도만 다른 같은 구역 - 무한: 위반 0 (난이도 알약 클릭으로 해소 - 제약 없음)
Check 'difficulty-only' @((NewItem '일반' '2-3'), (NewItem '어려움' '2-3')) 'infinite' 1 0 ''

# 메시지 형식 고정 (GUI 로그 문구가 이 표기에 의존: 'N번(난이도 구역)' + 한국어 사유)
$fmt = @(Get-CustomTransitionIssues -Items @((NewItem '일반' '1-2'), (NewItem '어려움' '2-3'), (NewItem '일반' '1-2')) -ListRepeat 'count' -ListRepeatCount 1)
if ($fmt.Count -eq 2 -and
    $fmt[0].From -eq '1번(일반 1-2)' -and $fmt[0].To -eq '2번(어려움 2-3)' -and
    $fmt[0].Reason -eq "1층에서 2층으로 올라가는 전환은 1-3에서만('다음 층으로' 버튼) 가능합니다" -and
    $fmt[1].From -eq '2번(어려움 2-3)' -and $fmt[1].To -eq '3번(일반 1-2)' -and
    $fmt[1].Reason -eq '2층에서 1층으로 내려가는 전환은 게임에서 불가능합니다') {
  Write-Host 'PASS message-format'
} else {
  Write-Host 'FAIL message-format:'
  foreach ($i in $fmt) { Write-Host ("     From='{0}' To='{1}' Reason='{2}'" -f $i.From, $i.To, $i.Reason) }
  $fails++
}

if ($fails -gt 0) { Write-Host ("RESULT: {0} FAIL" -f $fails); exit 1 }
Write-Host 'RESULT: ALL PASS (14 cases)'
exit 0
