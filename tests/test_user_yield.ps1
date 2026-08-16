# 사용자 조작 양보 (v2.1.1 - 2026-08-16 신설) 진리표 + 배선 가드
# 배경: 자동화 중 사용자가 가방 확인 등으로 게임을 조작하면 커서 대피가 커서를 계속 뺏는
# 실사용 불편 제보. 실측(2026-08-16 오프라인): SetCursorPos 는 GetLastInputInfo.dwTime 을
# 갱신하지 않고 mouse_event/keybd_event 만 갱신 → 자기 주입 시각 기록으로 사용자 입력 구분.
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-TickDeltaMilliseconds')) {
  Invoke-Expression $definition
}
$workerText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 부호 있는 tick 차 (사용자 입력 판별의 핵심 - 랩어라운드 오인 방지) ──
Assert-Case '틱차: 100ms 뒤 → +100' (Get-TickDeltaMilliseconds -From 1000 -To 1100) 100
Assert-Case '틱차: 100ms 전 → -100 (기존 elapsed 헬퍼는 +42.9억으로 오인 - 주입 직후 dwTime 이 기준보다 과거인 실제 상황)' `
  (Get-TickDeltaMilliseconds -From 1100 -To 1000) (-100)
Assert-Case '틱차: 같은 tick → 0' (Get-TickDeltaMilliseconds -From 5000 -To 5000) 0
Assert-Case '틱차: 랩 통과 미래 (4294967290 → 10) → +16' (Get-TickDeltaMilliseconds -From 4294967290 -To 10) 16
Assert-Case '틱차: 랩 통과 과거 (10 → 4294967290) → -16' (Get-TickDeltaMilliseconds -From 10 -To 4294967290) (-16)

# ── 배선 가드 (워커) ──
Assert-Case '배선: 양보 상태 변수 3종 초기화' `
  (($workerText -match '(?m)^\$script:lastSelfInputTick = \[uint32\]0') -and
   ($workerText -match '(?m)^\$script:lastUserInputTick = \[uint32\]0') -and
   ($workerText -match '(?m)^\$script:lastYieldClickNoticeTick = \[uint32\]0')) 'True'
# 주입 4곳(클릭/ALT 전면화/범용 키/생활 드래그) 전부: 직전 관측 + 직후 자기 시각 기록.
# 하나라도 빠지면 그 주입이 dwTime 을 덮어 이후 판별이 전부 '사용자'로 오인됩니다.
Assert-Case '배선: 주입 직후 Register-SelfInput 4곳' `
  ([regex]::Matches($workerText, '(?m)^\s+Register-SelfInput\b').Count) 4
Assert-Case '배선: 주입 직전 관측(Update-UserInputObservation) 4곳 + 판별 내 1곳' `
  ([regex]::Matches($workerText, '(?m)^\s+Update-UserInputObservation\b').Count) 5
Assert-Case '배선: 판별 여유 50ms + 유휴 기본 2500ms' `
  (($workerText -match '-gt 50\) \{\r?\n\s+\$script:lastUserInputTick') -and
   ($workerText -match '\[int\]\$IdleMs = 2500')) 'True'
# 양보 루프: 커서가 게임 위 + 사용자 활동 중일 때만, 상한 없음 (Codex: 조작 중 상한 도달로
# 커서를 뺏으면 요청을 정면으로 깸 - 손을 떼거나 커서가 게임 밖으로 나가면 즉시 풀림)
Assert-Case '배선: 대피 진입부 양보 루프 (게임 위 + 최근 입력)' `
  ([bool]($workerText -match 'while \(\(Test-CursorOverGame -Game \$Game\) -and \(Test-UserRecentlyActive\)\)')) 'True'
Assert-Case '배선: 양보 루프에 시간 상한 없음' `
  ([bool]($workerText -match '\$userYieldClock\.Elapsed\.TotalSeconds -g[et]')) 'False'
Assert-Case '배선: 양보 시작/재개 안내 로그' `
  (($workerText.Contains('사용자 마우스 조작 감지 - 조작이 끝날 때까지 자동화를 잠시 양보합니다')) -and
   ($workerText.Contains('사용자 조작이 끝나 자동화를 재개합니다 (양보 {0}초)'))) 'True'
# 클릭 취소 게이트: 조작 중에는 기다리지 않고 이번 클릭을 버림 (Codex 조건 - 판독과 클릭
# 사이에 화면이 바뀌었을 수 있어 옛 좌표 클릭 금지. lastClickPerformed=false 계약 재사용)
Assert-Case '배선: Click-ScreenPoint 사용자 조작 취소 게이트 (lastClickPerformed=false 직후)' `
  ([bool]($workerText -match '\$script:lastClickPerformed = \$false\r?\n(?:\s*#[^\r\n]*\r?\n)*\s+if \(Test-UserRecentlyActive\) \{')) 'True'
Assert-Case '배선: 생활 드래그도 사용자 조작 취소 게이트' `
  ($workerText.Contains('목록 스크롤: 사용자 마우스 조작 감지로 건너뜀')) 'True'

exit $fails
