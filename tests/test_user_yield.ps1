# 사용자 조작 양보 (v2.1.1 - 2026-08-16 신설) 진리표 + 배선 가드
# 배경: 자동화 중 사용자가 가방 확인 등으로 게임을 조작하면 커서 대피가 커서를 계속 뺏는
# 실사용 불편 제보. 실측(2026-08-16 오프라인): SetCursorPos 는 GetLastInputInfo.dwTime 을
# 갱신하지 않고 mouse_event/keybd_event 만 갱신 → 자기 주입 시각 기록으로 사용자 입력 구분.
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-TickDeltaMilliseconds', 'Test-UserInputContinuing', 'Test-UserInputBurstEnded', 'Test-UserInputNearSelfInput')) {
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

# ── 지속 확인 순수부 (2026-09-08 실측: 자기 클릭 뒤 ~100ms 단발 커서 이벤트 / 자동출발 뒤 게임 커서 워프
#    4건/92ms 가 '사용자'로 분류돼 매 회차 양보 1초 오발동 - 실제 이동은 2~4초에 51~52건 연속) ──
Assert-Case '지속: 확정 조작 없음(0) → 연장 아님(재확인 필요)' (Test-UserInputContinuing -Candidate 5000 -ConfirmedTick 0 -IdleMs 2500) $false
Assert-Case '지속: 확정 1초 뒤 후보 → 연장(재확인 없이 인정)' (Test-UserInputContinuing -Candidate 6000 -ConfirmedTick 5000 -IdleMs 2500) $true
Assert-Case '지속: 확정 3초 뒤 후보 → 연장 아님(유휴 뒤 재개 = 재확인)' (Test-UserInputContinuing -Candidate 8000 -ConfirmedTick 5000 -IdleMs 2500) $false
Assert-Case '지속: 랩어라운드 후보(4294967290 → 10) 도 연장' (Test-UserInputContinuing -Candidate 10 -ConfirmedTick 4294967290 -IdleMs 2500) $true
# 흡수 대상 창: 우리 주입 뒤 2.5초 안의 후보만 (반박 검토 major - 그 밖의 '이동 후 정지' 조작은 예전 2.5초 보호 유지)
Assert-Case '여파 창: 클릭 뒤 100ms 후보 → 지속 확인 대상' (Test-UserInputNearSelfInput -Candidate 5100 -SelfTick 5000 -WindowMs 2500) $true
Assert-Case '여파 창: Space 뒤 1.7초 후보(실측 게임 워프) → 대상' (Test-UserInputNearSelfInput -Candidate 6700 -SelfTick 5000 -WindowMs 2500) $true
Assert-Case '여파 창: 주입 뒤 4초 후보(사용자 조작) → 대상 아님(바로 확정)' (Test-UserInputNearSelfInput -Candidate 9000 -SelfTick 5000 -WindowMs 2500) $false
Assert-Case '여파 창: 후보가 주입보다 과거(주입 직전 보존된 사용자 입력) → 대상 아님(Codex P1)' (Test-UserInputNearSelfInput -Candidate 4900 -SelfTick 5000 -WindowMs 2500) $false
Assert-Case '여파 창: 후보 = 주입 시각 → 대상 아님(하한 0 배타)' (Test-UserInputNearSelfInput -Candidate 5000 -SelfTick 5000 -WindowMs 2500) $false
# 재확인 2창: **진전이 전혀 없을 때만** 흡수 (Codex P2 - 둘째 창에서 조작을 시작한 사용자를 놓치지 않음)
Assert-Case '재확인: 두 창 모두 진전 없음 → 끝난 묶음(흡수)' (Test-UserInputBurstEnded -Candidate 5000 -RecheckDw1 5000 -RecheckDw2 5000) $true
Assert-Case '재확인: 첫 창 진전 → 사용자(흡수 안 함)' (Test-UserInputBurstEnded -Candidate 5000 -RecheckDw1 5200 -RecheckDw2 5200) $false
Assert-Case '재확인: 첫 창 없음, 둘째 창 진전 → 사용자(둘째 창 시작 조작 보호)' (Test-UserInputBurstEnded -Candidate 5000 -RecheckDw1 5000 -RecheckDw2 5600) $false
Assert-Case '재확인: 두 창 모두 진전 → 사용자' (Test-UserInputBurstEnded -Candidate 5000 -RecheckDw1 5200 -RecheckDw2 5600) $false
Assert-Case '재확인: dwTime 이 후보보다 과거(틱 해상도 겹침) → 끝난 묶음' (Test-UserInputBurstEnded -Candidate 5000 -RecheckDw1 4990 -RecheckDw2 4990) $true

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
# v2.1.7: 50ms 조건 뒤에 '흡수 tick 이하 재후보 금지' 조건이 -and 로 붙음
Assert-Case '배선: 판별 여유 50ms + 유휴 기본 2500ms' `
  (($workerText -match '-gt 50 -and\r?\n\s+\(\$script:lastAbsorbedInputTick[^\r\n]*\)\) \{\r?\n\s+\$script:lastUserInputTick = \[uint32\]\$observedInfo\.dwTime') -and
   ($workerText -match '\[int\]\$IdleMs = 2500')) 'True'
# 양보 루프: 커서가 게임 위 + 사용자 활동 중일 때만, 상한 없음 (Codex: 조작 중 상한 도달로
# 커서를 뺏으면 요청을 정면으로 깸 - 손을 떼거나 커서가 게임 밖으로 나가면 즉시 풀림)
Assert-Case '배선: 대피 진입부 양보 루프 (게임 위 + 최근 입력)' `
  ([bool]($workerText -match 'while \(\(Test-CursorOverGame -Game \$Game\) -and \(Test-UserRecentlyActive\)\)')) 'True'
Assert-Case '배선: 양보 루프에 시간 상한 없음' `
  ([bool]($workerText -match '\$userYieldClock\.Elapsed\.TotalSeconds -g[et]')) 'False'
# v2.1.7: 안내에 입력 종류($script:lastUserInputKind - '마우스 이동'/'키/버튼 입력')를 표기 (2026-09-08 사용자
# 지적 "꿀비 자기 클릭에 양보하는 것 같다" - 채팅 타이핑 등 키보드 입력도 조작으로 잡히는 것을 로그로 구분)
Assert-Case '배선: 양보 시작/재개 안내 로그 (입력 종류 표기)' `
  (($workerText.Contains('사용자 입력 감지($($script:lastUserInputKind)) - 조작이 끝날 때까지 자동화를 잠시 양보합니다')) -and
   ($workerText.Contains('사용자 조작이 끝나 자동화를 재개합니다 (양보 {0}초)'))) 'True'
Assert-Case '배선: 입력 종류 추정 - 관측 커서 기준점 갱신 3곳(관측/자기 주입/대피 이동)' `
  ([regex]::Matches($workerText, '(?m)^\s+Update-ObservedCursor\b').Count) 3
Assert-Case '배선: 입력 종류는 커서 이동 여부로 분기' `
  (($workerText.Contains("`$script:lastUserInputKind = '마우스 이동'")) -and ($workerText.Contains("`$script:lastUserInputKind = '키/버튼 입력'"))) 'True'
# 지속 확인 배선: 새 후보(확정과 다름) → 연장 아니면 350ms 재확인 → 단발이면 기준 시각을 그 이벤트로 옮기고
# 사용자 기록을 확정값으로 되돌림 (같은 dwTime 이 다시 후보가 되지 않음), 지속이면 확정 갱신
Assert-Case '배선: 새 후보 3단 판정(연장 / 창 밖 즉시 확정 / 여파 창 안 2창 재확인) + 흡수는 주입 시각 불변·흡수 tick 기록' `
  (($workerText -match 'if \(\$script:lastUserInputTick -ne \$script:userInputConfirmedTick\) \{') -and
   ($workerText -match 'elseif \(-not \(Test-UserInputNearSelfInput -Candidate \$candidate -SelfTick \$script:lastSelfInputTick -WindowMs 2500\)\) \{') -and
   ($workerText -match 'Start-Sleep -Milliseconds 350\s+\$recheckDw1 = Get-LastInputTick\s+Start-Sleep -Milliseconds 350\s+\$recheckDw2 = Get-LastInputTick') -and
   ($workerText -match '\$script:lastAbsorbedInputTick = \$candidate\s+\$script:lastUserInputTick = \$script:userInputConfirmedTick') -and
   ($workerText -notmatch '\$script:lastSelfInputTick = \$candidate') -and
   ($workerText -match '\$script:userInputConfirmedTick = \$script:lastUserInputTick')) 'True'
Assert-Case '배선: 흡수 tick 이하의 dwTime 은 재후보 금지(관측부) + 주입 시각은 Register-SelfInput 만 갱신' `
  (($workerText -match 'lastAbsorbedInputTick -eq \[uint32\]0 -or \(Get-TickDeltaMilliseconds -From \$script:lastAbsorbedInputTick') -and
   ([regex]::Matches($workerText, '(?m)^\s*\$script:lastSelfInputTick = ').Count -eq 3)) 'True'   # 선언 + 첫 호출 초기화 + Register-SelfInput (흡수 경로에서는 대입 금지)
Assert-Case '배선: 새 주입(Register-SelfInput)이 흡수 tick 초기화 (24.86일 부호 반전 방지 - Codex P3)' `
  ([bool]($workerText -match '\$script:lastSelfInputTick = \[HoneyNogiInput\]::GetTickCount\(\)\r?\n\s+\$script:lastAbsorbedInputTick = \[uint32\]0\r?\n\s+Update-ObservedCursor')) 'True'
Assert-Case '배선: 지속 확인 상태 변수 3종 초기화' `
  (($workerText -match '(?m)^\$script:userInputConfirmedTick = \[uint32\]0') -and ($workerText -match '(?m)^\$script:inputDiagNoticeTick = \[uint32\]0') -and
   ($workerText -match '(?m)^\$script:lastAbsorbedInputTick = \[uint32\]0')) 'True'
Assert-Case '배선: 판정 진단 로그(분기명 + now/후보/확정/재확인/흡수) 3분기' `
  (([regex]::Matches($workerText, "Write-UserInputDiag -Branch '흡수'").Count -eq 1) -and
   ($workerText -match "Write-UserInputDiag -Branch \`$diagBranch") -and
   ($workerText.Contains("[진단] 입력 판정 {0}: now {1} / 후보 {2} / 확정 {3} / 재확인1 {4} / 재확인2 {5} / 흡수 {6}"))) 'True'
# 클릭 취소 게이트: 조작 중에는 기다리지 않고 이번 클릭을 버림 (Codex 조건 - 판독과 클릭
# 사이에 화면이 바뀌었을 수 있어 옛 좌표 클릭 금지. lastClickPerformed=false 계약 재사용)
# v2.1.6: false 초기화와 게이트 사이에 생략 원인 메타 초기화($lastClickSkipReason = '')가
# 끼어듦 - 주석과 그 초기화 줄만 허용 (계약 = 게이트가 초기화 직후라는 순서 불변)
Assert-Case '배선: Click-ScreenPoint 사용자 조작 취소 게이트 (lastClickPerformed=false 직후)' `
  ([bool]($workerText -match "\`$script:lastClickPerformed = \`$false\r?\n(?:\s*(?:#[^\r\n]*|\`$script:lastClickSkipReason = '')\r?\n)*\s+if \(Test-UserRecentlyActive\) \{")) 'True'
# 2026-09-09 계약 변경(실기 실측): 생활 드래그는 '건너뛰기'가 아니라 **대기**입니다.
# 건너뛰기만 하면 호출부가 그 회전의 예산을 그대로 소모해, 목록이 한 칸도 안 움직인 채
# 탐색 12스텝이 6초 만에 소진되고 '대상 미발견' 조건부 정지가 났습니다 (20:46 실기).
# 상세 진리표는 tests/test_life_scroll_yield.ps1 (본체 실행 + 변이 검증).
Assert-Case '배선: 생활 드래그는 조작 중 **대기**(건너뛰기 아님) + 양보 표시' `
  (($workerText -match 'if \(Test-UserRecentlyActive\) \{[\s\S]{0,300}?Wait-UserYieldEnd -Game \$Game -Context ''채집 목록 스크롤''[\s\S]{0,300}?\$script:lifeScrollYielded = \$true') -and
   (-not $workerText.Contains('목록 스크롤: 사용자 마우스 조작 감지로 건너뜀'))) 'True'

exit $fails
