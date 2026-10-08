# 어비스 선택 화면 복귀 루프(Return-ToAbyssSelection) 행동 진리표 (v2.1.12 - 2026-09-21 구현 리뷰 2차 P1·P2 / ⑥e 2026-09-30 설계 2.13·2.14)
#
# 09-20 23:25 실사고: 복귀 루프가 던전 안 HUD 를 '던전 밖' 으로 보고 ESC → 메뉴 '어비스' 로 던전 안에서 선택 화면 오버레이를 열어
# '복귀 완료'(코드 0). 1차 핫픽스는 필드(HUD + 추적기 던전명 없음)를 직접 확인하고 ESC 를 실제 전송했을 때만 발급하는 일회성
# 토큰($fieldProven)으로 메뉴 '어비스' 클릭을 막았는데, 폐기가 서두 양보 게이트·캡처 실패·패널·던전 안 증거뿐이라 **메뉴 '어비스'
# 클릭이 조작으로 생략된 뒤의 양보**(게이트를 지나지 않음)에서 옛 토큰이 살아남았다 - 양보 중 사용자가 재입장하고 던전 안에서
# ESC 메뉴를 열면 그 '어비스' 를 눌러 원 사고가 재현된다 (구현 리뷰 2차 P1 - 코드로 확정, 실기 미관측).
# 여기서 고정하는 계약 (운영 함수를 AST 로 추출해 모의 화면 상태 기계로 실행 - 사본 재구현 금지, exit 는 기록 뒤 return 으로 치환):
#   ① 기준: 필드 → (필드 확정 W) → ESC 전송(토큰) → 메뉴 → '어비스' 클릭(선택 화면 출처 발급) → 확인 루프가 출처 있는 선택 화면으로 완료 예약 →
#      다음 회전 서두에서 '선택 화면 복귀 확인' (그 회전의 판독 0)
#   ② P1: 토큰 발급 뒤 **어떤 양보든** 있었으면('어비스' 클릭 생략 뒤 양보 / ESC 클릭 생략 뒤 양보) 메뉴의 '어비스' 를 누르지 않고
#      ESC 로 닫아 화면을 재확인 → 던전 안(HUD + 추적기)이면 2연속·20초 뒤 코드 4 ('어비스' 클릭 전송 0, 복귀 확인 0)
#   ③ P1: 발급 뒤 캡처 실패가 있던 회전은 토큰 **폐기**(캡처 공백 중 게임 상태는 멈추지 않음 - 3차 리뷰) → 메뉴를 닫고 필드부터 재증명
#   ④ P2: 던전 안 첫 확인 뒤 캡처 실패 동결 시간은 20초 창에서 제외 (복구 직후 두 번째 표본에서 즉시 코드 4 금지 - 규칙 15)
#   ⑤ P1(4차): 필드 표본 뒤 판독(공지 팝업)에서 캡처 실패 → 뒤 ESC 글자 탐색 성공이 플래그를 풀어도 그 회전은 ESC 를 보내지 않음
#      (실패 뒤 일련번호로 토큰을 발급하면 다음 메뉴 대조가 실패를 못 보는 '세탁')
#   ⑥ P1(4차): 토큰 보유 뒤 메뉴가 아닌 복구 분기(이벤트 헬퍼 등)로 내려가면 토큰 폐기 - 헬퍼 안 0ms 양보는 직접 폐기 8곳도 누적 차분도 못 봄
#   ⑦ ⑥a(2026-09-26 설계 합의): 파티 준비 패널·접힌 준비 패널('입장 대기 중')도 재매칭 패널처럼 클릭 없이 기다리고(패널 위 '나가기' 는
#      패널 닫기·던전 퇴장, 판정이 없으면 '알 수 없는 화면 20초' 폴백이 X 후보를 누름), 마감까지 이어지면 진단 + 코드 4 (재매칭 패널은 기존 throw)
#   ⑧ ⑥e 설계 2.13 (09-30 리뷰3~5): 만료 판정은 모두 Get-FreezeAdjustedDeadline(양보 + 캡처 실패 누적 차분). 같은 회전 복구·섞인 모양·교대 모양·
#      판정 자리 가로지름·헬퍼 안 복구 회전(부모 마감)이 이어져도 유한하게 끝남(RL1~RL6 - 미관측, 종료 보장 확인). 동결 블록은 양보 게이트 앞
#      입력 없는 복구 탐침 + continue 형(RL7 - 캡처 실패 + 조작이면 옛 대기형은 조작이 끝날 때까지 캡처 시도 0, 같은 벽시계를 두 번 셈)
#   ⑨ ⑥e 설계 2.14 (09-30 리뷰5 P1-1 · 결정 D7): 선택 화면 양성은 던전 밖의 증명이 아님(오버레이). 완료는 워커 자신의 '어비스' 클릭 출처가
#      살아 있는 판독에서만(RLP1~RLP7 - 출처 없는 선택 화면은 누르지 않고 조정 마감이면 진단 + 코드 4). 필드 모양은 W 초 확정 뒤에만 ESC(RLP8 -
#      입장 직후·보스 오독이 같은 두 판독으로 필드 모양을 냄)
#   ⑩ 리뷰 6차 조건: 정상 복귀 중 짧은 사용자 입력 두 가지(W 누적 도중 / 필드 ESC 뒤·메뉴 판독 전)는 입력 중 자동 클릭 0, 코드 1·4 없이 출처 있는 완료 1
#   ⑪ ESC 메뉴 '어비스' 아이콘 폴백 (2026-10-07 설계 v2 10.3 - RLI0~RLI10): 글자 탐색이 유효 캡처에서 실패하고 그 회전의 메뉴 판정이 2차 신호('게임 종료')
#      만으로 참일 때만 아이콘을 찾아 같은 클릭 블록으로 누름. 글자·아이콘 판독의 캡처 실패 회전(가드 두 줄)은 미발견·클릭 없이 끝내고, 토큰(출처) 없는
#      메뉴·던전 안 메뉴에서는 부르지 않음. 클릭 무반응·오클릭·지속 필드 오독(수용 위험 R10)의 결말은 특성으로 고정
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
function Check-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = '')
  if ($Condition) { "OK   $Name $Detail" }
  else { "FAIL $Name $Detail"; $script:fails++ }
}

# ── 운영 코드 추출 (사본 재구현 금지) ─────────────────────────────────────────
# 마감 산술(Get-FreezeAdjustedDeadline = 양보 차분 + 캡처 실패 누적 차분 - ⑥e 설계 2.13)과 선택 화면 출처 판정(Test-AbyssSelectionProvenance - 2.14)은 운영 함수 그대로
foreach ($name in @('Get-YieldAdjustedDeadline', 'Invoke-UserYieldWithDeadline', 'Get-FreezeAdjustedDeadline', 'Test-AbyssSelectionProvenance')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}
$loopDef = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Return-ToAbyssSelection'))
# exit 6곳 = 안전 중지 2(완료 블록·필드 확정 뒤) + 메뉴 출처 미확인 + 던전 안 확인 + 준비 패널 지속(⑥a) + 출처 없는 선택 화면(⑥e 2.14)
Check-Equal '추출: 복귀 루프의 exit 는 6곳 (안전 중지 2 + 메뉴 출처 미확인 + 던전 안 확인 + 준비 패널 지속 - ⑥a + 출처 없는 선택 화면 - ⑥e 2.14)' ([regex]::Matches($loopDef, '(?m)^\s*exit (4|\$SafeStopExitCode)\s*$').Count) 6
$loopDef = $loopDef -replace '(?m)^(\s*)exit 4\s*$', '$1$script:exitCode = 4; $script:exitAt = (Elapsed); return'
$loopDef = $loopDef -replace '(?m)^(\s*)exit \$SafeStopExitCode\s*$', '$1$script:exitCode = $SafeStopExitCode; $script:exitAt = (Elapsed); return'
Invoke-Expression $loopDef
# 필드 확정 폭 W 와 키워드·영역은 소스 대입문에서 캡처 (숫자를 테스트에 다시 박지 않음 - 소스가 바뀌면 기대도 함께 움직임)
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
foreach ($sourceVar in @('memberFieldSettleSeconds', 'allDungeonKeywords', 'rgAbyssCards', 'rgAbyssSelect')) {
  $assign = $sourceAst.Find({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq ('$' + $sourceVar)) }, $true)
  if (-not $assign) { "FAIL 본체에서 `$$sourceVar 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $assign.Extent.Text
}
Check-True '캡처: 필드 확정 폭 W 는 소스 값 (입장 과도 4.2초 < W < 스윕 대기 30초 - 설계 ㉷)' ($memberFieldSettleSeconds -gt 4.2 -and $memberFieldSettleSeconds -lt 30) "(W=$memberFieldSettleSeconds)"

# ── 운영 상수 (값은 계약과 무관 - 마감 60초·영역 좌표만 형식을 맞춤) ──
$timeoutHud = 30; $timeoutAbyssMenu = 15; $timeoutAbyssSelect = 15
$safeStopFlagPath = 'HoneyNogi_safe_stop_test.flag'
$rgAbyssMenu = @(850, 180, 350, 520); $rgHomeEndEsc = @(1000, 40, 260, 90); $ptEscButton = @(1083, 89); $ocrEnglishEngine = 'en'
$ptNoticeClose = @(1090, 137); $rgStellaTitle = @(0, 0, 10, 10); $ocrKoreanEngine = 'ko'; $ptStellaCard = @(0, 0); $rgStellaPickBtn = @(0, 0, 10, 10)
$rgClearExit = @(430, 570, 420, 125)
$refocusEverySeconds = 0

# ── 모의: 가상 시계 ──────────────────────────────────────────────────────────────
# 판독은 가상 시간을 쓰지 않고(실패 주입의 '느린 실패' 만 흘림), Start-Sleep·양보 대기가 시계를 전진시킵니다. 케이스 시작부터 가상 20000초를
# 넘기면 '__VTIMEOUT__' 로 끝냅니다 - 마감을 못 보는 변이가 러너를 멈추지 않게 (러너에는 자식 시간 제한이 없음)
function Elapsed { return (($script:vclock - $script:startClock).Ticks / 10000000.0) }   # TotalSeconds 는 1e-7 곱이라 3.6 → 3.5999… (창 경계 오판)
function Apply-Schedule {
  # 시각표 모드(RLP8 - screenSchedule): 가상 초 → 화면. 클릭 전이보다 먼저 적용합니다 (시각이 되면 다음 판독부터 그 화면)
  while ($script:schedIdx -lt $script:schedule.Count -and (Elapsed) -ge $script:schedule[$script:schedIdx][0]) {
    $script:screen = $script:schedule[$script:schedIdx][1]; $script:schedIdx++
  }
}
function Advance { param([double]$Ms)
  $script:vclock = $script:vclock.AddMilliseconds($Ms)
  if ((Elapsed) -gt 20000) { throw '__VTIMEOUT__' }
  Apply-Schedule
}
function Get-Date { return $script:vclock }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) Advance ($Milliseconds + $Seconds * 1000) }
function Write-RunLog { param([string]$Message) [void]$script:logs.Add(('{0:N1} {1}' -f (Elapsed), $Message)) }
function Write-LifeDiagnostics { param($Game, $Context, [switch]$CaptureOnly) $script:diagCalls++; $script:diagContext = $Context }
function Focus-Game { param($Game) }
function Invoke-AutoRefocus { param($Game) return $false }
function Test-Path { param($LiteralPath, $Path) return [bool]$script:safeStopFlag }
function Remove-Item { param($LiteralPath, [switch]$Force, $ErrorAction) $script:flagRemoved++; $script:safeStopFlag = $false }

# ── 모의: 캡처 계층 (운영 Register-CaptureFailure / Register-CaptureSuccess / Get-CaptureFailTotalMs 계약) ──
# 실패 등록 = 일련번호 +1, 플래그가 거짓이었으면 실패 시작 시각. 성공 등록 = 플래그 해제 + 실패 구간 누적. 판독 모의가 모두 이 둘로 등록합니다
function Register-Fail {
  $script:captureFailSerial++
  if (-not $script:screenCaptureFailing) { $script:screenCaptureFailing = $true; $script:failSince = $script:vclock }
}
function Register-Success {
  if ($script:screenCaptureFailing) {
    $script:failTotalMs += ($script:vclock - $script:failSince).TotalMilliseconds
    $script:screenCaptureFailing = $false; $script:failSince = $null
  }
}
function Get-CaptureFailTotalMs {
  $total = [double]$script:failTotalMs
  if ($script:screenCaptureFailing -and $null -ne $script:failSince) { $total += ($script:vclock - $script:failSince).TotalMilliseconds }
  return $total
}
function In-Window { param($From, $Until) $t = Elapsed; return ($null -ne $From) -and ($t -ge $From) -and ($t -lt $Until) }
# 판독 모의 = 캡처 한 번. 실패 규칙(시간창 capfailFrom~Until / 동결 회전 수 capfailActive / 끊김 없는 실패 persistFail / 함수 이름별 계획 plan /
# N번째 호출 failOnceAt / 헬퍼 회전 예약 reservedFail - RL3)에 걸리면 실패 등록(+ 느린 실패 가상 ms) 뒤 $false, 아니면 성공 등록 뒤 값
function Read-Mock { param([string]$Name, $Value)
  $script:readCalls++
  if ($script:readCalls -gt 50000) { throw '__VTIMEOUT__' }   # 헬퍼 복구 회전은 300ms 라 가상 시간 상한만으로는 늦음 (09-30 리뷰4)
  [void]$script:captureTimes.Add((Elapsed))
  [void]$script:readNames.Add($Name)
  $fail = $false; $slowMs = 0
  if (In-Window $script:capfailFrom $script:capfailUntil) { $fail = $true }
  if ($script:capfailActive) { $fail = $true }
  if ($script:persistFail -and $Name -ne 'Test-CaptureRecovered') { $fail = $true }
  if ($script:persistFail -and $Name -eq 'Test-CaptureRecovered' -and -not (In-Window $script:capfailFrom $script:capfailUntil) -and -not $script:capfailActive) { $script:persistFail = $false }
  if ($script:planActive -and $script:plan.ContainsKey($Name) -and -not $fail) {
    $mode = $script:plan[$Name]
    if ($mode -eq 'fail') { $fail = $true; $slowMs = $script:planSlowMs }
    elseif ($mode -eq 'failPersist') { $fail = $true; $slowMs = $script:planSlowMs; $script:persistFail = $true }
  }
  if ($script:reservedFail -and $script:reservedFail -eq $Name -and -not $fail) { $script:reservedFail = ''; $fail = $true; $slowMs = 1000 }
  if ($script:failOnceAt.ContainsKey($Name)) {
    $script:failOnceCount[$Name] = [int]$script:failOnceCount[$Name] + 1
    if ($script:failOnceCount[$Name] -eq $script:failOnceAt[$Name] -and -not $fail) {
      $fail = $true; $slowMs = $script:failOnceSlowMs
      if ($script:screenOnFailOnce) { $script:screen = $script:screenOnFailOnce }
    }
  }
  if ($fail) {
    Register-Fail
    if ($slowMs -gt 0) { Advance $slowMs }
    return $false
  }
  Register-Success
  return $Value
}

# ── 모의: 조작 ────────────────────────────────────────────────────────────────
# 호출별 수열(ActiveSeq)이 있으면 그 값, 없으면 시간창 조작(activeFrom~Until). 양보 대기는 창 끝까지(또는 yieldSeconds) 가상 시계를 흘리고
# 그만큼 $script:userYieldTotalMs 를 올립니다 (운영 Wait-UserYieldEnd 계약 - 추출한 Invoke-UserYieldWithDeadline·출처 판정이 이 값을 봄)
function Next-Seq { param([string]$Name, $Default)
  $seq = Get-Variable -Name ($Name + 'Seq') -Scope Script -ValueOnly
  $idx = Get-Variable -Name ($Name + 'Idx') -Scope Script -ValueOnly
  if ($idx -lt $seq.Count) { Set-Variable -Name ($Name + 'Idx') -Scope Script -Value ($idx + 1); return $seq[$idx] }
  return $Default
}
function Test-UserRecentlyActive {
  if ($script:activeSeq.Count -gt 0 -and $script:activeIdx -lt $script:activeSeq.Count) { return [bool](Next-Seq 'active' $false) }
  return (In-Window $script:activeFrom $script:activeUntil)
}
function Wait-UserYieldEnd { param($Game, $Context)
  $script:yieldWaits++
  if (In-Window $script:activeFrom $script:activeUntil) { $ms = ($script:startClock.AddSeconds($script:activeUntil) - $script:vclock).TotalMilliseconds }
  else { $ms = $script:yieldSeconds * 1000 }
  if ($ms -lt 0) { $ms = 0 }
  [void]$script:yieldTimes.Add((Elapsed))
  if ($script:screenCaptureFailing) { $script:yieldsWhileFailing++ }
  Advance $ms
  $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $ms
  if ($script:screenAfterYield) { $script:screen = $script:screenAfterYield; $script:screenAfterYield = '' }
}
# 공통 진입점 모의: 동결 회전 수(capfailRounds)를 여기서 셉니다(서두 동결 블록이 회전마다 한 번 부름). f9After > 0 이면 연속 실패가 그 초에
# 닿는 순간 F9 경로(코드 4)의 센티널로 끝냅니다 (RL6(c′) - 끊김 없는 영구 실패)
function Test-SafeStopDuringCaptureFail {
  $script:safeStopCalls++; [void]$script:safeStopTimes.Add((Elapsed))
  $continuous = $(if ($null -ne $script:failSince) { ($script:vclock - $script:failSince).TotalSeconds } else { 0 })
  [void]$script:continuousFail.Add($continuous)
  if ($script:capfailRounds -gt 0) { $script:capfailRounds--; if ($script:capfailRounds -le 0) { $script:capfailActive = $false } }
  if ($script:f9After -gt 0 -and $script:screenCaptureFailing -and $continuous -ge $script:f9After) { throw '__F9__' }
}

# ── 모의: 화면 판독 ────────────────────────────────────────────────────────────
# $script:screen = 'field'(필드 HUD) / 'fieldMisread'(던전 안인데 HUD 참·추적기 거짓 - 판독으로는 필드와 같음, ESC 를 받으면 던전 안 메뉴 - RLP8) /
#                  'menu'(필드에서 연 ESC 메뉴) / 'menuInside'(던전 안에서 연 ESC 메뉴) / 'inside'(던전 안 HUD+추적기) / 'loading'(모든 판독 음성) /
#                  'selection'(선택 화면 - 출처와 무관한 모양) / 'detail'(어비스 클릭이 연 상세 - 09-15) / 'reward'(보상 화면) /
#                  'panel'(재매칭 패널) / 'readyPanel'(파티 준비 패널) / 'entryWaiting'(접힌 준비 패널) / 'unknown'
function Get-AbyssPanelKind { param($Game)
  $script:panelReads++   # 회전의 첫 판독 - 회전 번호 역할
  if ($script:screenAtPanelRead.ContainsKey($script:panelReads)) { $script:screen = $script:screenAtPanelRead[$script:panelReads] }
  if ($script:panelFailAfterEsc -and $script:escClicksSent -ge 1 -and -not $script:panelFailAfterEscDone) {
    # ESC 뒤 첫 패널 판독만 일시 실패 (뒤 선택 화면 판독 성공이 플래그를 풂) - 캡처 공백 중 화면이 바뀌는 반례는 screenAtPanelFail (3차 리뷰 P1)
    $script:panelFailAfterEscDone = $true
    $script:readCalls++; Register-Fail
    if ($script:screenAtPanelFail) { $script:screen = $script:screenAtPanelFail }
    return 'none'
  }
  if ($script:panelReadHook) { & $script:panelReadHook }
  if ($script:rl4Mode) { $r = Pop-Rl4 'panel'; if ($r.Fail) { return 'none' }; return [string]$r.Value }
  $isPanel = Read-Mock 'Get-AbyssPanelKind' ($script:screen -eq 'panel' -or $script:screen -eq 'readyPanel')
  if (-not $isPanel) { return 'none' }
  if ($script:screen -eq 'readyPanel') { return 'ready' }
  return 'matching'
}
function Test-AbyssEntryWaiting { param($Game)
  if ($script:rl4Mode) { $r = Pop-Rl4 'entry'; if ($r.Fail) { return $false }; return [bool]$r.Value }
  return (Read-Mock 'Test-AbyssEntryWaiting' ($script:screen -eq 'entryWaiting'))
}
function Test-AbyssSelectionScreen { param($Game)
  $script:selectionReads++
  if ($script:selSameCallFail -and $script:screen -eq 'selection') {
    # 같은 호출 안 실패 뒤 참 (카드 판독 실패 → 제목·배제 성공의 모양 - RL4(b) 순서): 실패 등록(가상 1초) → 성공 등록 → 참
    $script:readCalls++; Register-Fail; Advance 1000
    [void](Read-Mock 'Test-AbyssSelectionScreen#title' $true)
    return $true
  }
  return (Read-Mock 'Test-AbyssSelectionScreen' ($script:screen -eq 'selection'))
}
function Test-AbyssMenu { param($Game)
  $r = Read-Mock 'Test-AbyssMenu' ($script:screen -eq 'menu' -or $script:screen -eq 'menuInside'); if ($r) { $script:menuChecks++ }
  # 메뉴 판정 신호 (설계 v2 10.3 ④ · D-R - 운영 Test-AbyssMenu 는 세 반환 갈래 모두 $script:lastAbyssMenuSignal 에 대입): 참이면 사례 값 menuSignalMode
  # (기본 'exit-label' = 관측 4건의 '게임 종료' 만으로 메뉴인 모양), 거짓(캡처 실패 포함)이면 ''. 복귀 루프는 이 값이 'exit-label' 인 회전에서만 아이콘을 찾음
  $script:lastAbyssMenuSignal = $(if ($r) { $script:menuSignalMode } else { '' })
  if ($script:armMisclick -and $script:screen -eq 'detail') {
    # RL7(c) 방아쇠: '어비스' 클릭 뒤 확인 루프의 6번째 메뉴 음성 **직후** 실패 창 30초를 엶 (오클릭 판정의 첫 판독부터 실패), 창 가운데(15초) 선택 화면으로
    $script:menuNegCount++
    if ($script:menuNegCount -eq 6) {
      $script:armMisclick = $false
      $script:capfailFrom = (Elapsed); $script:capfailUntil = (Elapsed) + 30
      $script:schedule = @(, @(((Elapsed) + 15), 'selection')); $script:schedIdx = 0
      if ($script:variant -eq 'c1') { $script:activeFrom = (Elapsed); $script:activeUntil = (Elapsed) + 20 }
    }
  }
  return $r
}
function Test-HomeEndEscHud { param($Game) return (Read-Mock 'Test-HomeEndEscHud' ($script:screen -eq 'field' -or $script:screen -eq 'fieldMisread' -or $script:screen -eq 'inside')) }
function Test-InDungeonQuest { param($Game)
  # 추적기 판독문 진단 (설계 v2 10.3 ③ · 6.4 - 운영 Test-InDungeonQuest 는 판독마다 정규화 판독문을 $script:lastQuestTrackerText 에 남김, 판정에는 안 씀):
  # 유효한 필드 판독 = 'FIELDMOCK'(복귀 루프가 토큰 발급 줄에서 떠 두어 아이콘 찾음 줄 꼬리에 남기는지 RLI1 이 봄 - 변이 V18), 던전 안 = 'INSIDEMOCK',
  # 캡처 실패 = ''(운영은 빈 OCR 결과)
  $questSerialBefore = $script:captureFailSerial
  $questInside = Read-Mock 'Test-InDungeonQuest' ($script:screen -eq 'inside')
  $script:lastQuestTrackerText = $(if ($script:captureFailSerial -ne $questSerialBefore) { '' } elseif ($questInside) { 'INSIDEMOCK' } else { 'FIELDMOCK' })
  return $questInside
}
function Test-ExitButton { param($Game) return (Read-Mock 'Test-ExitButton' ($script:screen -eq 'reward')) }
function Test-NoticeBoardPopup { param($Game)
  # 필드 표본 뒤의 판독 - N번째 호출에서 일시 캡처 실패 + 그 공백 중 화면 전이를 모의 (4차 리뷰 P1 '세탁')
  $script:noticeCalls++
  if ($script:noticeCalls -eq $script:noticeFailAtCall) {
    $script:readCalls++; Register-Fail
    if ($script:screenAtNoticeFail) { $script:screen = $script:screenAtNoticeFail }
    return $false
  }
  return (Read-Mock 'Test-NoticeBoardPopup' $false)
}
function Invoke-EventSkipOrConfirm { param($Game, $LogPrefix)
  # 복구 분기의 이벤트 헬퍼 - 내부 user-active 대기가 0ms 로 끝나 누적 양보에 잡히지 않는 경우를 모의: 화면만 바뀌고 반환 $false (4차 리뷰 P1)
  $script:eventCalls++
  if ($script:eventHook) { & $script:eventHook }
  if ($script:eventYieldToScreen) { $script:screen = $script:eventYieldToScreen; $script:eventYieldToScreen = '' }
  [void](Read-Mock 'Invoke-EventSkipOrConfirm' $false)
  return $false
}
function Close-GhostRegisterPrompt { param($Game, $LogPrefix) return [bool](Read-Mock 'Close-GhostRegisterPrompt' $false) }
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine, [switch]$BinaryWhiteText)
  if ($script:rl4Mode) { $r = Pop-Rl4 'ocr'; if ($r.Fail) { return '' }; return [string]$r.Value }
  [void](Read-Mock 'Get-GameRegionOcrText' $true); return ''
}
function Find-GameTextPoint { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText, $ExactText, $Scale, $Engine)
  $ok = Read-Mock ('Find-GameTextPoint:' + $SearchText) $true
  if (-not $ok) { return $null }
  if ($SearchText -eq 'ESC') { return @{ X = 1102; Y = 74 } }
  # 메뉴 '어비스' 글자 (설계 v2 10.3 ①): textAbyssMode 'miss' = 유효 캡처에서 못 찾음(렌더 이상으로 글자가 깨진 메뉴). 캡처 실패는 기존 failOnceAt 장치
  if ($SearchText -eq '어비스') { if ($script:textAbyssMode -eq 'miss') { return $null }; return @{ X = 971; Y = 531 } }
  return $null
}
# 메뉴 '어비스' 아이콘 탐색 모의 (설계 v2 10.3 ② - 운영 Find-AbyssMenuIconPoint 계약): 캡처 실패 중이면 캡처 없이 capture-failed / 캡처 1회(판독 모의 -
# 실패 규칙에 걸리면 capture-failed) / 메뉴 화면('menu'·'menuInside')이고 iconMode 'found' 면 found + 라벨 상당점 (971,531)(Send-Mock 이 X=971 을 어비스
# 클릭으로 봄), 아니면 not-found(수치는 설계 6.1 미발견 꼬리 표본). 호출 시각·화면을 남겨 '어느 화면에서 불렀나' 를 봅니다
function Find-AbyssMenuIconPoint { param($Game)
  $script:iconCalls++; [void]$script:iconTimes.Add((Elapsed)); [void]$script:iconScreens.Add($script:screen)
  $iconResult = [pscustomobject]@{ Status = 'not-found'; Point = $null; Score = 0.612; Second = 0.590; Size = 28; CenterX = 971.0; CenterY = 503.0
    ElapsedMs = 600; FirstUse = ($script:iconCalls -eq 1); Window = '1272x717·DPI 96' }
  if ($script:screenCaptureFailing) { $iconResult.Status = 'capture-failed'; return $iconResult }
  if (-not (Read-Mock 'Find-AbyssMenuIconPoint' $true)) { $iconResult.Status = 'capture-failed'; return $iconResult }
  if ($script:iconMode -eq 'found' -and ($script:screen -eq 'menu' -or $script:screen -eq 'menuInside')) {
    $iconResult.Status = 'found'; $iconResult.Point = @{ X = 971; Y = 531 }; $iconResult.Score = 0.913; $iconResult.Second = 0.500; $iconResult.Size = 30
  }
  return $iconResult
}
# 복구 탐침 모의 (⑥e 2.13 - 동결 블록의 입력 없는 복구 캡처): 판독 모의와 같은 등록을 하고 호출 시각을 남겨 '실패 창 안 캡처 시도 최대 간격' 을 봅니다
function Test-CaptureRecovered { param($Game)
  $script:probeCalls++; [void]$script:probeTimes.Add((Elapsed))
  return [bool](Read-Mock 'Test-CaptureRecovered' $true)
}
# 나가기 헬퍼 모의 (기본): 결과·화면 지정(helperResult·screenAfterHelper). 부모 마감 인자를 기록합니다. RL3 은 이 모의 대신 운영 헬퍼를 씁니다
$mockHelperDef = @'
function Invoke-AbyssExitClick { param($Game, $LogPrefix, $Context, $ParentDeadline = $null)
  $script:helperCalls++; $script:helperParent = $ParentDeadline
  if ($script:screenAfterHelper) { $script:screen = $script:screenAfterHelper; $script:screenAfterHelper = '' }
  return @{ Result = $script:helperResult; FrozenMs = 777 }
}
'@
Invoke-Expression $mockHelperDef
# RL3 헬퍼 하단 판독 모의: 캡처 시도 1회 + 그 회전의 실패 자리 예약(판독 함수 이름 - 설계 5.2: (a)(c) 헬퍼 안 선택 화면 판독, (b) 패널 판독)
function Find-AbyssExitButtonPoint { param($Game)
  $script:helperBottomReads++
  [void](Read-Mock 'Find-AbyssExitButtonPoint' $true)
  if ($script:rl3FailName) { $script:reservedFail = $script:rl3FailName }
  if ($script:rl3WithPoint) { return @{ Text = '아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기'; Point = @{ X = 478; Y = 654 } } }
  return @{ Text = '다세하기다른던전가기'; Point = $null }
}

# ── 모의: 클릭·키 ─────────────────────────────────────────────────────────────
function Send-Mock { param([int]$X, [int]$Y)
  $r = Next-Seq 'send' 'sent'
  $script:lastClickPerformed = ($r -eq 'sent'); $script:lastClickSkipReason = $(if ($r -eq 'sent') { '' } else { $r })
  if ($r -ne 'sent') { return }
  [void]$script:clickTimes.Add((Elapsed))
  if ($X -eq 1102) {
    # ESC 버튼: 필드 → 메뉴 / 던전 안(필드 오독 포함) → 던전 안 메뉴 / 메뉴 → 닫힘. escIgnoreUntil 전의 ESC 는 전송되지만 게임이 무시(화면 불변)
    $script:escClicksSent++; [void]$script:escTimes.Add((Elapsed))
    if ($script:onFirstEsc -and $script:escClicksSent -eq 1) { & $script:onFirstEsc }
    if ($null -ne $script:escIgnoreUntil -and (Elapsed) -lt $script:escIgnoreUntil) { return }
    if ($script:escLeadsTo) { $script:screen = $script:escLeadsTo; $script:escLeadsTo = ''; return }
    switch ($script:screen) {
      'field'        { $script:screen = 'menu' }
      'fieldMisread' { $script:screen = 'menuInside' }
      'inside'       { $script:screen = 'menuInside' }
      'menu'         { $script:screen = 'field' }
      'menuInside'   { $script:screen = 'inside' }
    }
  } elseif ($X -eq 971) {
    # 메뉴 '어비스' → 필드 메뉴면 abyssLeadsTo(기본 선택 화면, 'detail'·'unknown' 가능). 던전 안 메뉴였다면 오버레이 = 원 사고 (09-20 23:25)
    $script:abyssClicksSent++; [void]$script:abyssTimes.Add((Elapsed)); $script:panelReadsAtAbyss = $script:panelReads
    if ($script:screen -eq 'menuInside') { $script:abyssClickedFromInside++; $script:screen = 'selection' }
    else { $script:screen = $script:abyssLeadsTo }
    if ($script:onAbyssClick) { & $script:onAbyssClick }
  } else { $script:otherClicksSent++ }
}
function Click-ScreenPoint { param([int]$X, [int]$Y) Send-Mock -X $X -Y $Y }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) Send-Mock -X ([int]$ReferenceX) -Y ([int]$ReferenceY) }
function Press-KeyVerified { param($Game, $VirtualKey, $Label)
  # 메뉴 닫기 ESC - 메뉴가 열려 있던 화면으로 돌아감
  $script:keyVerified++; [void]$script:clickTimes.Add((Elapsed))
  if ($script:screen -eq 'menu') { $script:screen = 'field' } elseif ($script:screen -eq 'menuInside') { $script:screen = 'inside' }
  return $true
}
function Press-KeyOnce { param($VirtualKey)
  # 오클릭 복구 ESC (09-15: '어비스' 가 상세를 열면 ESC 로 선택 화면 - escDetailLeadsTo)
  $script:keyOnce++; [void]$script:clickTimes.Add((Elapsed))
  if ($script:screen -eq 'detail') { $script:screen = $script:escDetailLeadsTo }
}
# RL4(b) 판독 순서 진리표용 호출별 결과 큐 ('FAIL' = 캡처 실패 등록 후 음성, 그 밖 = 성공 등록 후 그 값)
function Pop-Rl4 { param([string]$Queue)
  $q = $script:rl4Queues[$Queue]
  if ($null -eq $q -or $q.Count -eq 0) { throw "__RL4_QUEUE_EMPTY_${Queue}__" }
  $item = $q[0]; $script:rl4Queues[$Queue] = @($q | Select-Object -Skip 1)
  $script:readCalls++
  if ("$item" -eq 'FAIL') { Register-Fail; [void]$script:rl4Trace.Add('fail'); return @{ Fail = $true; Value = $null } }
  Register-Success; [void]$script:rl4Trace.Add('ok'); return @{ Fail = $false; Value = $item }
}

function Reset-Case {
  param([string]$Screen = 'field', $ActiveSeq = @(), $SendSeq = @())
  $script:screen = $Screen; $script:screenAfterYield = ''
  $script:activeSeq = @($ActiveSeq); $script:activeIdx = 0; $script:sendSeq = @($SendSeq); $script:sendIdx = 0
  $script:activeFrom = $null; $script:activeUntil = $null
  $script:vclock = [datetime]'2026-10-01 12:00:00'; $script:startClock = $script:vclock
  $script:logs = New-Object 'System.Collections.Generic.List[string]'
  $script:yieldWaits = 0; $script:yieldSeconds = 5; $script:userYieldTotalMs = [double]0; $script:yieldsWhileFailing = 0
  $script:yieldTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:readCalls = 0; $script:readNames = New-Object 'System.Collections.Generic.List[string]'; $script:captureTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:panelReads = 0; $script:selectionReads = 0; $script:menuChecks = 0; $script:panelReadsAtAbyss = -1
  $script:safeStopCalls = 0; $script:safeStopTimes = New-Object 'System.Collections.Generic.List[double]'; $script:continuousFail = New-Object 'System.Collections.Generic.List[double]'
  $script:diagCalls = 0; $script:diagContext = ''
  $script:escClicksSent = 0; $script:escTimes = New-Object 'System.Collections.Generic.List[double]'
  $script:abyssClicksSent = 0; $script:abyssTimes = New-Object 'System.Collections.Generic.List[double]'; $script:abyssClickedFromInside = 0; $script:otherClicksSent = 0
  $script:clickTimes = New-Object 'System.Collections.Generic.List[double]'; $script:keyVerified = 0; $script:keyOnce = 0; $script:flagRemoved = 0; $script:safeStopFlag = $false
  $script:exitCode = $null; $script:exitAt = $null; $script:threw = ''; $script:endAt = 0
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타 - 오발동 없어야 함
  $script:screenCaptureFailing = $false; $script:captureFailSerial = 0; $script:failSince = $null; $script:failTotalMs = [double]0
  $script:capfailFrom = $null; $script:capfailUntil = $null; $script:capfailActive = $false; $script:capfailRounds = 0
  $script:persistFail = $false; $script:plan = @{}; $script:planActive = $false; $script:planSlowMs = 0; $script:reservedFail = ''
  $script:failOnceAt = @{}; $script:failOnceCount = @{}; $script:screenOnFailOnce = ''; $script:failOnceSlowMs = 0
  $script:panelFailAfterEsc = $false; $script:panelFailAfterEscDone = $false; $script:screenAtPanelFail = ''
  $script:noticeCalls = 0; $script:noticeFailAtCall = -1; $script:screenAtNoticeFail = ''
  $script:eventCalls = 0; $script:eventHook = $null; $script:eventYieldToScreen = ''; $script:panelReadHook = $null
  $script:screenAtPanelRead = @{}; $script:schedule = @(); $script:schedIdx = 0
  $script:escLeadsTo = ''; $script:escIgnoreUntil = $null; $script:abyssLeadsTo = 'selection'; $script:escDetailLeadsTo = 'selection'
  $script:onFirstEsc = $null; $script:onAbyssClick = $null; $script:selSameCallFail = $false
  $script:probeCalls = 0; $script:probeTimes = New-Object 'System.Collections.Generic.List[double]'; $script:f9After = 0
  $script:helperCalls = 0; $script:helperParent = $null; $script:helperResult = 'gone'; $script:screenAfterHelper = ''
  $script:helperBottomReads = 0; $script:rl3FailName = ''; $script:rl3WithPoint = $false
  $script:armMisclick = $false; $script:menuNegCount = 0; $script:variant = ''; $script:armYieldRead = $false
  $script:rl4Mode = $false; $script:rl4Queues = @{}; $script:rl4Trace = New-Object 'System.Collections.Generic.List[string]'
  # 메뉴 '어비스' 아이콘 폴백 (설계 v2 10.3): 글자 결과 found / 아이콘 결과 found(출처 없는 메뉴 사례 전부 기본 found - not-found 면 아이콘을 잘못된 자리에서
  # 불러도 누르지 않아 '클릭 0' 이 그대로 통과함) / 메뉴 판정 신호 'exit-label'(관측 4건 모양 - 'abyss-text' 가 기본이면 아이콘 사례가 전부 호출 0 이 됨)
  $script:textAbyssMode = 'found'; $script:iconMode = 'found'; $script:menuSignalMode = 'exit-label'
  $script:lastAbyssMenuSignal = ''; $script:lastQuestTrackerText = ''
  $script:iconCalls = 0; $script:iconTimes = New-Object 'System.Collections.Generic.List[double]'; $script:iconScreens = New-Object 'System.Collections.Generic.List[string]'
}
function Run-Loop { param([int]$SafeStopExitCode = 0)
  try { Return-ToAbyssSelection -Game $null -SafeStopExitCode $SafeStopExitCode } catch { $script:threw = $_.Exception.Message }
  $script:endAt = Elapsed
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }
function Done { return (Count-Log '선택 화면 복귀 확인') }          # 출처 있는 완료 (완료 문구는 복귀 루프에 1곳)
function Unprov { return (Count-Log '출처 없음') }                  # 출처 없는 선택 화면 안내 (루프당 1회)
function ThrewTimeout { return [int]($script:threw -like '*복귀 대기 시간이 초과*') }
# (가상 경과 − 누적 캡처 실패 − 누적 양보) 초 - 조정 마감 60초가 실패·양보를 뺀 시간으로 흐르는지 봅니다
function Adj { return [math]::Round($script:endAt - ($script:failTotalMs / 1000.0) - ($script:userYieldTotalMs / 1000.0), 1) }
function MaxGap { param($Times, $From, $Until)
  $t = @($Times | Where-Object { $_ -ge $From -and $_ -lt $Until } | Sort-Object)
  if ($t.Count -lt 2) { return 999 }
  $gap = 0; for ($i = 1; $i -lt $t.Count; $i++) { if (($t[$i] - $t[$i - 1]) -gt $gap) { $gap = $t[$i] - $t[$i - 1] } }
  return [math]::Round($gap, 2)
}
function ClicksIn { param($From, $Until) return @($script:clickTimes | Where-Object { $_ -ge $From -and $_ -lt $Until }).Count }
function AllInput { return ($script:escClicksSent + $script:abyssClicksSent + $script:otherClicksSent + $script:keyVerified + $script:keyOnce) }

# ── 0. 선택 화면 출처 진리표 (⑥e 설계 2.14 - 추출한 운영 함수) ───────────────────
# 출처 = 발급됨(워커 '어비스' 클릭 전송 확인 뒤) + 발급 순간의 캡처 실패 일련번호·양보 누적이 판정 시점(판독 직전 일련번호 · 지금 양보 누적)과 같음
$prov = @(
  (Test-AbyssSelectionProvenance -Expected $false -ExpectedSerial 3 -ExpectedYieldMs 0 -ReferenceSerial 3 -YieldMs 0),
  (Test-AbyssSelectionProvenance -Expected $true -ExpectedSerial 3 -ExpectedYieldMs 0 -ReferenceSerial 3 -YieldMs 0),
  (Test-AbyssSelectionProvenance -Expected $true -ExpectedSerial 3 -ExpectedYieldMs 0 -ReferenceSerial 4 -YieldMs 0),
  (Test-AbyssSelectionProvenance -Expected $true -ExpectedSerial 3 -ExpectedYieldMs 0 -ReferenceSerial 3 -YieldMs 250),
  (Test-AbyssSelectionProvenance -Expected $true -ExpectedSerial 3 -ExpectedYieldMs 5000 -ReferenceSerial 3 -YieldMs 5000))
Check-Equal '출처 진리표: 발급 안 됨 → 거짓 / 셋 다 같음 → 참 / 발급 뒤 캡처 실패(일련번호 다름) → 거짓 / 발급 뒤 양보(누적 다름) → 거짓 / 발급 전 양보(기준값에 이미 반영) → 참' ($prov -join ',') 'False,True,False,False,True'

# ── 1. 기준: 필드 → W → ESC(토큰) → 메뉴 → 어비스(출처 발급) → 확인 루프 완료 예약 → 다음 회전 서두 완료 ─────────
Reset-Case -Screen 'field'
Run-Loop
Check-Equal '기준: ESC 1 → 어비스 1 → 복귀 확인 1 (메뉴 닫기 0, 코드 없음, 출처 재확인 로그 0, 출처 없음 0)' ("$($script:escClicksSent)/$($script:abyssClicksSent)/$(Done)/$($script:keyVerified)/$($script:exitCode)/$((Count-Log '메뉴 출처를 다시 확인'))/$(Unprov)") '1/1/1/0//0/0'
Check-Equal '기준: 던전 안 메뉴에서 누른 어비스 0, throw 없음' ("$($script:abyssClickedFromInside)/$($script:threw)") '0/'
#    ③(⑥e 2.14): 완료는 클릭 회전 바로 다음 회전 서두 - 그 회전은 판독 0 (패널 판독 수가 클릭 회전까지와 같음)
Check-Equal '기준: 완료는 어비스 클릭 다음 회전 서두 (완료 회전의 판독 0 - 패널 판독 수 = 클릭 회전까지)' ("$($script:panelReads)") "$($script:panelReadsAtAbyss)"
#    필드 확정(⑥e 2.14): 첫 ESC 는 첫 필드 표본부터 W 이상 뒤
Check-True '기준: 첫 ESC 시각 ≥ W (필드 확정 - 1표본으로 ESC 금지)' ($script:escTimes.Count -ge 1 -and $script:escTimes[0] -ge $memberFieldSettleSeconds) "(첫 ESC $($script:escTimes[0])초, W $memberFieldSettleSeconds)"
#    1b. 발급 **전** 양보는 토큰과 무관 - 기준값을 발급 시점에 찍지 않으면(변이) 이전 양보 누적 때문에 첫 메뉴에서 헛폐기 → 메뉴 닫기 1
Reset-Case -Screen 'field' -ActiveSeq @($true)
Run-Loop
Check-Equal '발급 전 양보: 양보 1 → ESC 1 → 어비스 1 → 복귀 확인 1, 메뉴 닫기 0, 출처 재확인 로그 0' ("$($script:yieldWaits)/$($script:escClicksSent)/$($script:abyssClicksSent)/$(Done)/$($script:keyVerified)/$((Count-Log '메뉴 출처를 다시 확인'))") '1/1/1/1/0/0'

# ── 2. ★ P1: 어비스 클릭 생략(조작) → 양보 중 재입장 + 던전 안 ESC 메뉴 → 옛 토큰으로 누르면 안 됨 ──
#    필드 → ESC 전송(토큰) → 메뉴 → 어비스 클릭이 user-active 로 생략 → 양보(화면: 던전 안 메뉴) → 메뉴 재감지 → 토큰 폐기 →
#    ESC 로 닫기(1회) → 던전 안(HUD+추적기) 2연속·20초 → 코드 4. 옛 코드(변이): 양보 뒤 옛 토큰으로 어비스 클릭 → 오버레이 → '복귀 확인'
Reset-Case -Screen 'field' -SendSeq @('sent', 'user-active')
$script:screenAfterYield = 'menuInside'
Run-Loop
#    (출처 재확인 로그 0 = 생략 자리의 명시 폐기가 먼저 걸려 게이트에 닿지 않음. 게이트 로그는 간접 양보·캡처 공백 전용 - 아래 3·3b)
Check-Equal 'P1 어비스 생략 뒤 양보: 어비스 전송 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, 복귀 확인 0, 출처 재확인 로그 0' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$(Done)/$((Count-Log '메뉴 출처를 다시 확인'))") '0/0/1/4/0/0'
# (주의) 큰따옴표 문자열 안의 $( ) 에 괄호가 든 따옴표 문자열을 넣으면 PS 5.1 파서가 하위식 끝을 못 찾습니다 - 패턴 개수는 변수로 미리 셉니다
$insideStopLogs = Count-Log '던전 안 상태\(HUD \+ 던전 목표\)를 확인해'
Check-Equal 'P1 어비스 생략 뒤 양보: 정지 사유 = 던전 안 확인, 진단 캡처 1(문맥)' ("$insideStopLogs/$($script:diagCalls)/$($script:diagContext)") '1/1/어비스 복귀 중 던전 안 확인'
$skipLogs = Count-Log '어비스 메뉴 클릭 건너뜀 \(사용자 조작\)'; $clickLogs = Count-Log '어비스 메뉴 클릭 \(글자'
Check-Equal 'P1 어비스 생략 뒤 양보: 양보 1회, 클릭 생략 로그 1 (거짓 클릭 로그 없음)' ("$($script:yieldWaits)/$skipLogs/$clickLogs") '1/1/0'
#    2b. ESC 클릭 생략(조작) 뒤 양보 - 앞 회전에 발급된 토큰이 남아 있어도 같은 계약 (첫 ESC 는 전송됐지만 게임이 무시 → 메뉴 안 열림)
Reset-Case -Screen 'field' -SendSeq @('sent', 'user-active')
$script:escIgnoreUntil = 20000; $script:screenAfterYield = 'menuInside'
Run-Loop
Check-Equal 'P1 ESC 생략 뒤 양보: 어비스 전송 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, ESC 전송 1, 출처 재확인 로그 0(명시 폐기)' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$($script:escClicksSent)/$((Count-Log '메뉴 출처를 다시 확인'))") '0/0/1/4/1/0'
#    2c. ★ 3차 리뷰 P1: 클릭 시점엔 조작 중이었지만 양보 대기가 즉시 끝나(Wait-UserYieldEnd 의 유휴 재검사) 누적 양보가 0 인 경계 -
#    누적값 차분만으로는 못 잡으므로 생략 자리에서 토큰을 직접 폐기해야 함 (변이: 그 폐기 줄 제거 → 옛 토큰으로 던전 안 어비스 클릭)
Reset-Case -Screen 'field' -SendSeq @('sent', 'user-active')
$script:yieldSeconds = 0; $script:screenAfterYield = 'menuInside'
Run-Loop
Check-Equal 'P1 어비스 생략 뒤 0초 양보: 어비스 전송 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, 누적 양보 0' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$([int]$script:userYieldTotalMs)") '0/0/1/4/0'

# ── 3. P1(3차): 발급 뒤 캡처 실패가 있던 회전은 토큰 폐기 - 캡처 공백 중 게임 상태는 멈추지 않으므로(재입장·던전 안 메뉴 가능) 메뉴를 닫고 필드부터 재증명 ──
#    필드 → (W) → ESC(토큰) → [ESC 뒤 첫 패널 판독만 실패(일련번호 +1, 뒤 선택 화면 판독 성공이 플래그 해제)] → 메뉴 감지 → 폐기 → ESC 닫기(1) →
#    필드 → (W) → ESC(2) → 메뉴 → 어비스 클릭 → 선택 화면. (⑥e: ESC 가 W 만큼 밀려 회전 번호 대신 'ESC 뒤 첫 패널 판독 실패' 로 다시 산정 - 설계 5.2)
Reset-Case -Screen 'field'
$script:panelFailAfterEsc = $true
Run-Loop
Check-Equal '발급 뒤 캡처 실패 회전: 토큰 폐기 → 메뉴 닫기 1 → ESC 2회 → 어비스 1 → 복귀 확인 1, 출처 재확인 로그 1, 동결 0' ("$($script:keyVerified)/$($script:escClicksSent)/$($script:abyssClicksSent)/$(Done)/$((Count-Log '메뉴 출처를 다시 확인'))/$($script:safeStopCalls)") '1/2/1/1/1/0'
#    3b. ★ 3차 리뷰 P1 반례: 캡처 공백 중 사용자가 재입장하고 던전 안에서 ESC 메뉴를 열어 둠 → 복구 뒤 보이는 것은 '메뉴' 뿐 → 옛 토큰으로 누르면 원 사고
Reset-Case -Screen 'field'
$script:panelFailAfterEsc = $true; $script:screenAtPanelFail = 'menuInside'
Run-Loop
Check-Equal '캡처 공백 중 재입장 + 던전 안 메뉴: 어비스 전송 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)") '0/0/1/4'

# ── 4. P2: 던전 안 첫 확인 뒤 캡처 실패 동결은 20초 창에서 제외 ─────────────────────
#    던전 안(1, t=0) → 회전 2 부터 캡처 실패 30회전(continue 형 동결 - 회전 0.7초, 탐침 포함) → 복구 뒤 20초 창을 다시 채워 코드 4.
#    ⑥e(09-30 리뷰5 ④ 재산출): 동결 회전이 0.7초라 15회전이면 복구가 20초 창 안에 들어와 '미룸 제거' 변이를 못 가립니다 - 30회전으로 올림.
#    정지 40~50초 (계산 약 42.4초 - 위쪽 50 은 turnStart 갱신 누락 변이의 미룸 누적을, 아래쪽 40 은 미룸 제거 변이의 복구 직후 정지를 잡음)
Reset-Case -Screen 'inside'
$script:panelReadHook = { if ($script:panelReads -eq 2) { $script:capfailActive = $true; $script:capfailRounds = 30 } }
Run-Loop
Check-Equal '던전 안 + 캡처 실패 동결 30회전: 코드 4, 안전 확인 30(동결 회전마다), 복구 탐침 30, 어비스 전송 0, 메뉴 닫기 0' ("$($script:exitCode)/$($script:safeStopCalls)/$($script:probeCalls)/$($script:abyssClicksSent)/$($script:keyVerified)") '4/30/30/0/0'
Check-True '던전 안 + 캡처 실패 동결: 정지 시각 40~50초 (동결 약 21초 제외 후 20초)' ($script:endAt -ge 40 -and $script:endAt -le 50) "(실제 $($script:endAt)초)"
#    4b. 동결 없는 기준: 던전 안 2연속·20초 → 코드 4 (t ≈ 20~24)
Reset-Case -Screen 'inside'
Run-Loop
Check-True '던전 안(동결 없음): 코드 4, 정지 시각 20~24초, 안전 확인 0' ($script:exitCode -eq 4 -and $script:endAt -ge 20 -and $script:endAt -le 24 -and $script:safeStopCalls -eq 0) "(실제 $($script:endAt)초)"

# ── 5. ★ 4차 리뷰 P1-1 '토큰 세탁': 필드 표본 뒤 공지 팝업 판독에서 캡처 실패(그 공백 중 사용자가 재입장 = 던전 안) → ESC 글자 탐색 성공이 ──
#    플래그를 풂. 옛 코드: ESC 전송(던전 안이라 던전 안 메뉴가 열림) + 실패 뒤 일련번호로 토큰 발급 → 다음 회전 메뉴 대조 통과 → 어비스
#    클릭 → 오버레이 → '복귀 확인'(원 사고). 수정: 실패 회전은 ESC 를 보내지 않고 재판독 → 다음 회전 던전 안 → 코드 4 (공지 판독은 W 뒤 첫 판독)
Reset-Case -Screen 'field'
$script:noticeFailAtCall = 1; $script:screenAtNoticeFail = 'inside'
Run-Loop
Check-Equal '발급 직전 캡처 실패(세탁 금지): ESC 전송 0, 어비스 0, 던전 안 클릭 0, 복귀 확인 0, 코드 4' ("$($script:escClicksSent)/$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$(Done)/$($script:exitCode)") '0/0/0/0/4'

# ── 6. ★ 4차 리뷰 P1-2 간접 0ms 양보: 토큰 보유 뒤 화면이 메뉴가 아닌 '알 수 없음'(전환) → 복구 분기의 이벤트 헬퍼 안 양보 중 던전 안 메뉴가 열림 ──
#    (헬퍼 대기가 즉시 끝나 누적 양보 0 → 직접 폐기 8곳도 누적 차분도 못 봄). 수정: 복구 분기 진입 = 토큰 폐기 → 다음 회전 메뉴 → 출처 미확인 →
#    ESC 닫기 → 던전 안 → 코드 4
Reset-Case -Screen 'field'
$script:escLeadsTo = 'unknown'; $script:eventYieldToScreen = 'menuInside'
Run-Loop
Check-Equal '복구 분기 진입 시 토큰 폐기: ESC 1, 어비스 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, 누적 양보 0' ("$($script:escClicksSent)/$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$([int]$script:userYieldTotalMs)") '1/0/0/1/4/0'

# ── 7. ⑥a 파티 준비 패널·접힌 준비 패널 (2026-09-26 설계 합의 4.2 - 실기 -1 L4·L5·M3·M6) ─────────────────
#    준비 패널이 마감(60초 + 양보 0)까지 이어짐 → 어떤 클릭·키도 없이(ESC 0, 어비스 0, X 후보 0, 메뉴 닫기 0) 진단 + 코드 4, throw 없음.
Reset-Case -Screen 'readyPanel'
Run-Loop
$readyStopLogs = Count-Log '파티 준비 패널이 마감까지 이어져'
Check-Equal '준비 패널 지속: 코드 4, ESC 0, 어비스 0, X 후보 0, 메뉴 닫기 0, throw 없음' ("$($script:exitCode)/$($script:escClicksSent)/$($script:abyssClicksSent)/$($script:otherClicksSent)/$($script:keyVerified)/$($script:threw)") '4/0/0/0/0/'
Check-Equal '준비 패널 지속: 진단 캡처 1(문맥), 정지 사유 로그 1, 감지 로그는 종류별 1회' ("$($script:diagCalls)/$($script:diagContext)/$readyStopLogs/$((Count-Log '복귀 중 준비 패널 감지'))") '1/어비스 복귀 중 준비 패널 지속/1/1'
#    7b. 접힌 준비 패널: 패널 영역이 비어 종류 'none' → 하단 판정(Test-AbyssEntryWaiting)으로 대기, 같은 코드 4
Reset-Case -Screen 'entryWaiting'
Run-Loop
Check-Equal '접힌 준비 패널 지속: 코드 4, 클릭·키 0, 진단 1, 감지 로그 1' ("$($script:exitCode)/$(AllInput)/$($script:diagCalls)/$((Count-Log '접힌 준비 패널'))") '4/0/1/1'
#    7c. 재매칭 패널은 기존 동작 그대로 - 마감까지 이어지면 throw (코드 4 가 아님), 클릭 0
Reset-Case -Screen 'panel'
Run-Loop
Check-Equal '재매칭 패널 지속(기존 동작): throw, 코드 없음, 클릭·키 0, 진단 0' ("$(ThrewTimeout)/$($script:exitCode)/$(AllInput)/$($script:diagCalls)") '1//0/0'
#    7d. 준비 패널 → 5번째 회전에 자동 입장(던전 안) → 기존 던전 안 판정(2연속·20초)이 코드 4 - 준비 패널 정지 사유가 아님, 클릭 0
Reset-Case -Screen 'readyPanel'
$script:screenAtPanelRead = @{ 5 = 'inside' }
Run-Loop
$insideStopAfterPanel = Count-Log '던전 안 상태\(HUD \+ 던전 목표\)를 확인해'
Check-Equal '준비 패널 → 자동 입장: 코드 4(던전 안 확인), 준비 패널 정지 로그 0, 클릭·키 0' ("$($script:exitCode)/$insideStopAfterPanel/$((Count-Log '파티 준비 패널이 마감까지'))/$(AllInput)") '4/1/0/0'
#    7e. 준비 패널이 사라지고 필드(파티장이 준비 취소) → 평소 복귀(W → ESC → 어비스 → 선택 화면), 마감 코드 4 없음
Reset-Case -Screen 'readyPanel'
$script:screenAtPanelRead = @{ 4 = 'field' }
Run-Loop
Check-Equal '준비 패널 → 필드: ESC 1 → 어비스 1 → 복귀 확인 1, 코드 없음, 진단 0' ("$($script:escClicksSent)/$($script:abyssClicksSent)/$(Done)/$($script:exitCode)/$($script:diagCalls)") '1/1/1//0'
#    7f. ★ 뒤집음 = RLP7 (⑥e 설계 2.14 - 09-30 리뷰5 ⑤): 준비 패널 → 60초에 선택 화면(워커 클릭 없음)은 출처가 없어 완료가 아님 → 코드 4(진단 문맥),
#        throw 없음, 클릭·키 0, 출처 없음 안내 1. 마감 경계의 '완료가 만료보다 먼저'(⑥a 구현 리뷰 2차 P1)는 RLP4(b) 가 출처 있는 배치로 지킵니다
Reset-Case -Screen 'readyPanel'
$script:schedule = @(, @(60, 'selection'))
Run-Loop
Check-Equal '준비 패널 → 마감 경계에서 선택 화면(RLP7 - 출처 없음): 복귀 확인 0, throw 없음, 코드 4, 진단 문맥, 클릭·키 0, 출처 없음 안내 1' ("$(Done)/$($script:threw)/$($script:exitCode)/$($script:diagContext)/$(AllInput)/$(Unprov)") '0//4/어비스 복귀 중 출처 없는 선택 화면/0/1'
#    7g. 마감 경계에서 필드로 바뀐 경우(패널 사라짐)는 성공이 아니므로 그 회전에서 일반 만료 → 기존 throw (필드 ESC 전송 없이)
Reset-Case -Screen 'readyPanel'
$script:schedule = @(, @(60, 'field'))
Run-Loop
Check-Equal '준비 패널 → 마감 경계에서 필드: 일반 만료 throw, 코드 4 없음, ESC 0' ("$(ThrewTimeout)/$($script:exitCode)/$($script:escClicksSent)") '1//0'

# ── 8. 리뷰 6차 조건: 정상 복귀 중 짧은 사용자 입력 (⑥e 설계 2.14 - 필드 확정 W·출처) ──────────────────────
#    ① W 누적 2~4초 사이 짧은 조작(3.0~3.6초): 양보 게이트가 필드 연속을 끊어 W 가 조작이 끝난 뒤 다시 시작 → 첫 ESC ≥ 조작 끝 + W → 정상 완료.
#       입력 중 자동 클릭 0, 코드 1·4 없음, 출처 있는 완료 정확히 1
Reset-Case -Screen 'field'
$script:activeFrom = 3.0; $script:activeUntil = 3.6
Run-Loop
Check-Equal '짧은 입력①(W 누적 중): 양보 1, ESC 1, 어비스 1, 출처 있는 완료 1, 코드 없음, throw 없음, 출처 없음 0' ("$($script:yieldWaits)/$($script:escClicksSent)/$($script:abyssClicksSent)/$(Done)/$($script:exitCode)/$($script:threw)/$(Unprov)") '1/1/1/1///0'
Check-Equal '짧은 입력①: 입력 중(3.0~3.6초) 자동 클릭·키 0' (ClicksIn 3.0 3.6) 0
Check-True '짧은 입력①: W 재시작 - 첫 ESC ≥ 조작 끝(3.6초) + W' ($script:escTimes.Count -ge 1 -and $script:escTimes[0] -ge (3.6 + $memberFieldSettleSeconds)) "(첫 ESC $($script:escTimes[0])초)"
#    ② 필드 ESC 뒤·메뉴 판독 전 짧은 조작(ESC + 0.3 ~ + 2.8초): 양보가 토큰을 폐기 → 옛 토큰으로 어비스를 누르지 않고 메뉴 닫기 → 필드 재확인(W) →
#       두 번째 ESC → 새 출처로 정상 완료. 입력 중 자동 클릭 0, 코드 1·4 없음, 출처 있는 완료 정확히 1
Reset-Case -Screen 'field'
$script:onFirstEsc = { $script:activeFrom = (Elapsed) + 0.3; $script:activeUntil = (Elapsed) + 2.8 }
Run-Loop
$esc1 = $(if ($script:escTimes.Count -ge 1) { $script:escTimes[0] } else { -1 })
Check-Equal '짧은 입력②(ESC 뒤·메뉴 판독 전): 양보 1, 메뉴 닫기 1, ESC 2, 어비스 1, 출처 있는 완료 1, 코드 없음, throw 없음, 출처 없음 0' ("$($script:yieldWaits)/$($script:keyVerified)/$($script:escClicksSent)/$($script:abyssClicksSent)/$(Done)/$($script:exitCode)/$($script:threw)/$(Unprov)") '1/1/2/1/1///0'
Check-Equal '짧은 입력②: 입력 중 자동 클릭·키 0' (ClicksIn ($esc1 + 0.3) ($esc1 + 2.8)) 0
Check-True '짧은 입력②: 옛 토큰 미사용 - 어비스 클릭은 필드 재확인 뒤 두 번째 ESC 다음' ($script:escTimes.Count -ge 2 -and $script:abyssTimes.Count -ge 1 -and $script:abyssTimes[0] -gt $script:escTimes[1] -and ($script:escTimes[1] - ($esc1 + 2.8)) -ge $memberFieldSettleSeconds) "(ESC $($script:escTimes -join ','), 어비스 $($script:abyssTimes -join ','))"

# ── 9. RL1~RL7 종료 보장 (⑥e 설계 2.13 - 미관측, 종료 보장 확인: 판독 도중 캡처가 끊겼다 돌아오는 모양이 이어져도 유한하게 끝남) ─────
# RL1. 같은 회전 복구 영구 (패널 판독 실패 → 같은 회전 선택 화면 판독이 복구, 실패 주입 0초): (a) 필드 (b) 준비 패널. 복구 회전은 판정·조작 없이
#      조정 마감만 → 60초에 break → 기존 throw ((b) 도 복구 회전에는 유효한 패널 표본이 없어 코드 4 가 아님). ⑥a 작업 트리는 이 회전을 두 만료 판정의
#      일련번호 조건으로 건너뛰어 끝나지 않았음(VTIMEOUT)
foreach ($rl1Screen in @('field', 'readyPanel')) {
  Reset-Case -Screen $rl1Screen
  $script:planActive = $true; $script:plan = @{ 'Get-AbyssPanelKind' = 'fail' }
  Run-Loop
  Check-Equal "RL1($rl1Screen) 같은 회전 복구 영구: ESC 0, 어비스 0, 메뉴 닫기 0, X 후보 0, throw '복귀 대기 시간이 초과', 코드 없음" ("$($script:escClicksSent)/$($script:abyssClicksSent)/$($script:keyVerified)/$($script:otherClicksSent)/$(ThrewTimeout)/$($script:exitCode)") '0/0/0/0/1/'
  Check-True "RL1($rl1Screen): 정지 가상 시각 = 한도 60 ± 1초 (누적 실패 0)" ([math]::Abs($script:endAt - 60) -le 1.01) "(실제 $($script:endAt)초)"
}
# RL2. 섞인 모양 (재매칭 패널 - 클릭 없이 기다리다 마감이면 break → throw, 동결 회전은 그 회전 판독 전부 실패 → 다음 회전 동결 블록 탐침이 복구, 실패마다 가상 3초)
#      (a) 8회전마다 동결 회전 (b) RL1 의 같은 회전 복구를 매 회전 + 20회전마다 (a) 의 동결 회전. 동결 블록이 마감을 되돌리면(HEAD·v6) 동결 회전마다 마감이
#      60초로 돌아가 끝나지 않습니다(VTIMEOUT)
foreach ($rl2 in @('a', 'b')) {
  Reset-Case -Screen 'panel'
  if ($rl2 -eq 'a') { $script:panelReadHook = { if ($script:panelReads % 8 -eq 0) { Register-Fail; Advance 3000; $script:persistFail = $true } } }
  else {
    $script:planActive = $true; $script:plan = @{ 'Get-AbyssPanelKind' = 'fail' }
    $script:panelReadHook = { if ($script:panelReads % 20 -eq 0) { Register-Fail; Advance 3000; $script:persistFail = $true } }
  }
  Run-Loop
  Check-True "RL2($rl2) 섞인 모양: throw, (가상 경과 − 누적 실패) = 60 ± 2초, 클릭·키 0, 안전 확인 1 이상, VTIMEOUT 없음" ((ThrewTimeout) -eq 1 -and [math]::Abs((Adj) - 60) -le 2 -and (AllInput) -eq 0 -and $script:safeStopCalls -ge 1) "(adj $(Adj), 안전 확인 $($script:safeStopCalls), throw '$($script:threw)')"
}
# RL3. 헬퍼 안 복구 회전 (09-30 리뷰4 P1-2): 보상 화면 → 4) 분기가 **운영 헬퍼**를 부름 (이 케이스 동안만 Invoke-AbyssExitClick·Test-AbyssEntryWaitingText 를
#      소스에서 추출해 모의 헬퍼 대신 정의 - 헬퍼 exit 4 는 '기록 뒤 반환'). 헬퍼 안 판독만 실패하도록 하단 판독 모의가 그 회전의 실패 자리를 예약합니다.
#      (a) 같은 회전 복구 영구 - 하단 위치 없음·패널 none·선택 화면 판독 실패(1초) → HUD 판독 복구 (b) 교대 영구 - 하단 위치 있음·패널 판독 실패(1초) →
#      다음 회전 하단 판독 복구 (c) (a) + 헬퍼를 부르는 복귀 루프 회전에서 일반 판정 뒤 메뉴 판독 실패(10초) → HUD 판독 복구
#      기대: 헬퍼 'expired' → break → throw, 복귀 루프의 헬퍼 호출 정확히 1, 헬퍼 하단 판독 유한((a)(c) 약 200 · (b) 약 400 - 60 / 0.3), 클릭 0,
#      재판독(미검출) 로그 0·exit 4 0, (가상 − 누적 실패) = 60 ± 1. 옛 헬퍼(부모 마감 없음)는 그 회전이 미검출 예산·20초 창을 쓰지 않아 끝나지 않았음
$exitClickReal = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-AbyssExitClick'))
$exitClickReal = $exitClickReal -replace 'function Invoke-AbyssExitClick', 'function Invoke-AbyssExitClickReal'
$exitClickReal = $exitClickReal -replace '(?m)^(\s*)exit 4\s*$', '$1$script:exitCode = 4; return @{ Result = ''stopped''; FrozenMs = $frozenMs }'
Invoke-Expression $exitClickReal
Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-AbyssEntryWaitingText')))
foreach ($rl3 in @('a', 'b', 'c')) {
  Reset-Case -Screen 'reward'
  function Invoke-AbyssExitClick { param($Game, $LogPrefix, $Context, $ParentDeadline = $null)
    $script:helperCalls++; $script:helperParent = $ParentDeadline
    return (Invoke-AbyssExitClickReal -Game $Game -LogPrefix $LogPrefix -Context $Context -ParentDeadline $ParentDeadline)
  }
  if ($rl3 -eq 'b') { $script:rl3FailName = 'Get-AbyssPanelKind'; $script:rl3WithPoint = $true } else { $script:rl3FailName = 'Test-AbyssSelectionScreen' }
  if ($rl3 -eq 'c') { $script:failOnceAt = @{ 'Test-AbyssMenu' = 1 }; $script:failOnceSlowMs = 10000 }
  Run-Loop
  $rl3Expect = $(if ($rl3 -eq 'b') { 400 } else { 200 })
  $rl3Rereads = Count-Log '재판독'
  Check-Equal "RL3($rl3) 헬퍼 안 복구 회전: throw '복귀 대기 시간이 초과', 헬퍼 호출 1, 클릭·키 0, 재판독 로그 0, 코드 없음" ("$(ThrewTimeout)/$($script:helperCalls)/$(AllInput)/$rl3Rereads/$($script:exitCode)") '1/1/0/0/'
  Check-True "RL3($rl3): 헬퍼 하단 판독 $rl3Expect ± 2 (유한), (가상 − 누적 실패) = 60 ± 1초" ([math]::Abs($script:helperBottomReads - $rl3Expect) -le 2 -and [math]::Abs((Adj) - 60) -le 1.01) "(하단 판독 $($script:helperBottomReads), adj $(Adj), throw '$($script:threw)')"
}
Invoke-Expression $mockHelperDef   # 모의 헬퍼 되살림
# RL4(b). Test-AbyssSelectionScreen 판독 순서 진리표 (09-30 리뷰4 P3-1 - 선택 화면 예외의 근거): 운영 함수를 이름을 바꿔 추출하고 카드·제목 판독·패널·
#      접힌 패널을 호출별 결과(성공 글자/실패)로 모의합니다. 참인 행에서는 마지막 세 판독(증거·패널 배제·접힌 패널 배제)이 모두 성공이고 반환 때 플래그가
#      거짓입니다 - 그래서 복귀 루프가 같은 회전 복구 회전의 선택 화면 양성을 무효 표본으로 치지 않아도 됩니다. 배제 판독 뒤 실패 검사를 지우면 넷째·다섯째 행이 참
Invoke-Expression (([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-AbyssSelectionScreen'))) -replace 'function Test-AbyssSelectionScreen', 'function Test-AbyssSelectionScreenReal')
$rl4Rows = @(
  @{ Name = '카드 성공·키워드 → 패널 none → 접힌 패널 거짓'; Ocr = @('허상의정박지'); Panel = @('none'); Entry = @($false); Expect = $true },
  @{ Name = "카드 실패('') → 제목 성공 '비스' → 패널 none → 접힌 패널 거짓 (실패 뒤 새 증거)"; Ocr = @('FAIL', '!힌어비스'); Panel = @('none'); Entry = @($false); Expect = $true },
  @{ Name = '카드 실패 → 제목 실패'; Ocr = @('FAIL', 'FAIL'); Panel = @(); Entry = @(); Expect = $false },
  @{ Name = '카드 성공 → 패널 판독 실패'; Ocr = @('허상의정박지'); Panel = @('FAIL'); Entry = @(); Expect = $false },
  @{ Name = '카드 성공 → 패널 none → 접힌 패널 판독 실패'; Ocr = @('허상의정박지'); Panel = @('none'); Entry = @('FAIL'); Expect = $false },
  @{ Name = "카드 성공 → 패널 'ready'"; Ocr = @('허상의정박지'); Panel = @('ready'); Entry = @(); Expect = $false })
foreach ($row in $rl4Rows) {
  Reset-Case -Screen 'unknown'
  $script:rl4Mode = $true; $script:rl4Queues = @{ ocr = @($row.Ocr); panel = @($row.Panel); entry = @($row.Entry) }
  $rl4Result = $null; $rl4Error = ''
  try { $rl4Result = Test-AbyssSelectionScreenReal -Game $null } catch { $rl4Error = $_.Exception.Message }
  $rl4Tail = @($script:rl4Trace | Select-Object -Last 3) -join ','
  $rl4Detail = "(결과 $rl4Result, 판독 $($script:rl4Trace -join ','), 오류 '$rl4Error')"
  if ($row.Expect) {
    Check-True "RL4(b) $($row.Name) → 참, 마지막 세 판독 성공, 반환 때 플래그 거짓" ($rl4Result -eq $true -and $rl4Tail -eq 'ok,ok,ok' -and -not $script:screenCaptureFailing -and $rl4Error -eq '') $rl4Detail
  } else {
    Check-True "RL4(b) $($row.Name) → 거짓" ($rl4Result -eq $false -and $rl4Error -eq '') $rl4Detail
  }
}
# RL5. 교대 모양 (알 수 없는 화면 - 패널 none 이라 접힌 패널·선택 화면 판정까지 가는 화면): 매 회전 첫 판독(패널)은 성공하고 다음 판독(접힌 패널)에서 실패가
#      시작돼(가상 1초) 다음 회전 첫 캡처(동결 블록의 탐침)까지 이어짐. 동결 블록마다 안전 확인, 탐침 복구 뒤 회전(표식)마다 조정 마감 + 700ms → throw
Reset-Case -Screen 'unknown'
$script:planActive = $true; $script:plan = @{ 'Test-AbyssEntryWaiting' = 'failPersist' }; $script:planSlowMs = 1000
Run-Loop
Check-True 'RL5 교대 모양: throw, (가상 경과 − 누적 실패) = 60 ± 1초, 클릭·키 0(X 후보 포함), 안전 확인 1 이상, VTIMEOUT 없음' ((ThrewTimeout) -eq 1 -and [math]::Abs((Adj) - 60) -le 1.01 -and (AllInput) -eq 0 -and $script:safeStopCalls -ge 1) "(adj $(Adj), 안전 확인 $($script:safeStopCalls), throw '$($script:threw)')"
# RL6. 판정 자리 가로지름 (반영본 검증, 09-30 리뷰4): 지정 판독이 실패를 등록(가상 1초)하고 같은 회전의 뒤 판독이 (닿으면) 복구 - 판정 자리 끝냄이 없으면
#      뒤 판독(메뉴·HUD)이 되살려 다음 회전이 동결·표식을 타지 않고 마감 판정이 한 번도 없었습니다 (가로지름 모양)
#      (a) 필드: 매 회전 선택 화면 판독 실패 (b) 알 수 없는 화면: 같은 주입 - X 후보 0 (c) 첫 판독(패널)도 실패 - 탐침이 복구
foreach ($rl6 in @('field', 'unknown')) {
  Reset-Case -Screen $rl6
  $script:planActive = $true; $script:plan = @{ 'Test-AbyssSelectionScreen' = 'fail' }; $script:planSlowMs = 1000
  Run-Loop
  Check-True "RL6($rl6) 가로지름: throw, (가상 − 누적 실패) = 60 ± 1초, ESC·어비스·X 후보·키 0, 안전 확인 1 이상, VTIMEOUT 없음" ((ThrewTimeout) -eq 1 -and [math]::Abs((Adj) - 60) -le 1.01 -and (AllInput) -eq 0 -and $script:safeStopCalls -ge 1) "(adj $(Adj), 안전 확인 $($script:safeStopCalls), X $($script:otherClicksSent), throw '$($script:threw)')"
}
Reset-Case -Screen 'field'
$script:planActive = $true; $script:plan = @{ 'Get-AbyssPanelKind' = 'fail'; 'Test-AbyssSelectionScreen' = 'fail' }; $script:planSlowMs = 1000
Run-Loop
Check-True 'RL6(c) 첫 판독·선택 화면 판독 실패, 탐침 성공: (a) 와 같은 throw, (가상 − 누적 실패) = 60 ± 1초, 클릭·키 0' ((ThrewTimeout) -eq 1 -and [math]::Abs((Adj) - 60) -le 1.01 -and (AllInput) -eq 0) "(adj $(Adj), throw '$($script:threw)')"
#      (c′) 모든 캡처(탐침 포함) 실패 영구 → 끊김 없는 실패 120초에서 F9 경로(코드 4) 센티널 1, 연속 실패 시간 단조 증가, 동결 회전의 캡처는 탐침 1회뿐, 마감 throw 0
Reset-Case -Screen 'field'
$script:capfailFrom = 0; $script:capfailUntil = 100000; $script:f9After = 120
Run-Loop
$rl6NonProbe = @($script:readNames | Where-Object { $_ -ne 'Test-CaptureRecovered' }).Count
$rl6Monotone = (@(1..([Math]::Max(1, $script:continuousFail.Count) - 1) | Where-Object { $script:continuousFail.Count -gt 1 -and $script:continuousFail[$_] -lt $script:continuousFail[$_ - 1] }).Count -eq 0)
#      (센티널은 마지막 동결 회전의 안전 확인 안에서 던지므로 그 회전의 탐침은 없습니다 - 탐침 = 안전 확인 − 1)
Check-True "RL6(c′) 끊김 없는 영구 실패: F9 센티널, 연속 실패 시간 단조 증가, 첫 회전 뒤 판독은 탐침뿐(동결 회전마다 1), 마감 throw 0" ($script:threw -eq '__F9__' -and $rl6Monotone -and $rl6NonProbe -le 3 -and $script:probeCalls -eq ($script:safeStopCalls - 1)) "(throw '$($script:threw)', 탐침 외 판독 $rl6NonProbe, 탐침 $($script:probeCalls), 안전 확인 $($script:safeStopCalls))"
#      (d) 동결 회전 모양: 실패 창 [5, 20) 동안 동결 회전마다 탐침 1·안전 확인 1 이고 다른 판독 0 (재매칭 패널 - 클릭 없음). 실패가 시작된 회전(첫 실패 판독과
#      같은 가상 시각의 판독들 - 판독은 시간을 쓰지 않음)은 동결 회전이 아니라 판정 자리에서 끝낸 회전이라 뺍니다
Reset-Case -Screen 'panel'
$script:capfailFrom = 5; $script:capfailUntil = 20
Run-Loop
$rl6dStart = @($script:captureTimes | Where-Object { $_ -ge 5 } | Select-Object -First 1)[0]
$rl6dReads = @(for ($i = 0; $i -lt $script:readNames.Count; $i++) { if ($script:captureTimes[$i] -gt $rl6dStart -and $script:captureTimes[$i] -lt 20) { $script:readNames[$i] } })
$rl6dSafe = @($script:safeStopTimes | Where-Object { $_ -gt $rl6dStart -and $_ -lt 20 }).Count
Check-True 'RL6(d) 동결 회전 모양: 실패 창 안 캡처는 탐침뿐, 탐침 수 = 안전 확인 수, 클릭·키 0' ((@($rl6dReads | Where-Object { $_ -ne 'Test-CaptureRecovered' }).Count -eq 0) -and ($rl6dReads.Count -ge 1) -and [math]::Abs($rl6dReads.Count - $rl6dSafe) -le 1 -and (AllInput) -eq 0) "(창 안 판독 $($rl6dReads.Count) - $(@($rl6dReads | Select-Object -Unique) -join ','), 안전 확인 $rl6dSafe)"
# RL7. 캡처 실패 + 유한 조작 (09-30 리뷰5 P2-1 - continue 형 동결 블록): 옛 대기형은 실패 중 게이트가 조작을 양보로 기다려 캡처 시도가 조작 끝까지 0 이었고
#      그 양보와 흐르는 실패 누적이 같은 벽시계를 두 번 더했습니다
#      (a) 재매칭 패널, 캡처 실패 [5, 35)·조작 [10, 45): 동결 회전마다 탐침(= 안전 확인), 실패 창 안 캡처 간격 ≤ 1.5초, 실패 중 양보 0, 복구 뒤 첫 회전의
#      게이트 양보 1(약 10초), throw 98~102초 (= 60 + 누적 실패 약 29.4 + 복구 뒤 양보 약 9.6 - 겹친 [10, 35) 는 실패로 한 번만)
Reset-Case -Screen 'panel'
$script:capfailFrom = 5; $script:capfailUntil = 35; $script:activeFrom = 10; $script:activeUntil = 45
Run-Loop
$rl7aGap = MaxGap $script:captureTimes 5 35
Check-True 'RL7(a) 재매칭 + 실패·조작 겹침: throw 98~102초, 탐침 = 안전 확인, 실패 창 안 캡처 간격 ≤ 1.5초, 실패 중 양보 0, 양보 1, 클릭·키 0' ((ThrewTimeout) -eq 1 -and $script:endAt -ge 98 -and $script:endAt -le 102 -and $script:probeCalls -eq $script:safeStopCalls -and $rl7aGap -le 1.5 -and $script:yieldsWhileFailing -eq 0 -and $script:yieldWaits -eq 1 -and (AllInput) -eq 0) "(정지 $($script:endAt), 탐침 $($script:probeCalls), 안전 확인 $($script:safeStopCalls), 간격 $rl7aGap, 양보 $($script:yieldWaits))"
#      (b) 필드, 캡처 실패 [0, 35)·조작 [10, 45) (실패 전에 ESC·어비스가 나가지 않게 0초부터): 복구 ≈35 → 게이트 양보(→45) → 표식 회전 → 필드 확정(W) →
#      첫 ESC ≥ 45.7 + W → 메뉴 → 어비스(출처 발급) → 확인 루프 → 다음 회전 완료 ≈57 ± 1, 실패 창 안 클릭·키 0 (발급 전에 끝난 캡처 실패 뒤 정상 복귀)
Reset-Case -Screen 'field'
$script:capfailFrom = 0; $script:capfailUntil = 35; $script:activeFrom = 10; $script:activeUntil = 45
Run-Loop
Check-True 'RL7(b) 필드 + 실패 뒤 조작: 완료 1 (≈57 ± 1초), 실패 창 안 클릭·키 0, 첫 ESC ≥ 45.7 + W, 코드·throw 없음' ((Done) -eq 1 -and (ClicksIn 0 35) -eq 0 -and $script:escTimes.Count -ge 1 -and $script:escTimes[0] -ge (45.6 + $memberFieldSettleSeconds) -and [math]::Abs($script:endAt - 57) -le 1.01 -and $null -eq $script:exitCode -and $script:threw -eq '') "(완료 $($script:endAt), ESC $($script:escTimes -join ','), 어비스 $($script:abyssTimes -join ','))"
#      (c) 확인 루프 직후 오클릭 판정 판독에서 실패 시작(30초 - 창 가운데 선택 화면으로) + (c1) 같은 순간부터 조작 20초 / (c2) 조작 없음:
#      오클릭 로그·진단·ESC 키 0, 실패 중 양보 0, 동결 회전마다 탐침(실패 창 안 캡처 간격 ≤ 1.5초), 복구 뒤 출처 없는 선택 화면(동결 블록이 출처 폐기) →
#      진단 + 코드 4, 정지 = 60 + 누적 실패 ± 2초 (겹친 조작은 더하지 않음). 가드가 없으면 (c1) 실패 중 양보, (c2) 실패한 음성으로 ESC 키
foreach ($rl7c in @('c1', 'c2')) {
  Reset-Case -Screen 'field'
  $script:abyssLeadsTo = 'detail'
  $script:onAbyssClick = { $script:armMisclick = $true; $script:menuNegCount = 0 }
  $script:variant = $rl7c
  Run-Loop
  $rl7cGap = $(if ($null -ne $script:capfailFrom) { MaxGap $script:captureTimes $script:capfailFrom $script:capfailUntil } else { 999 })
  Check-True "RL7($rl7c) 오클릭 판정 판독에서 실패 시작: 오클릭 로그·ESC 키 0, 실패 중 양보 0, 캡처 간격 ≤ 1.5초, 출처 없음 코드 4, 정지 = 60 + 누적 실패 ± 2초" ($script:keyOnce -eq 0 -and (Count-Log '어비스가 아닌 화면') -eq 0 -and $script:yieldsWhileFailing -eq 0 -and $rl7cGap -le 1.5 -and $script:exitCode -eq 4 -and $script:diagContext -eq '어비스 복귀 중 출처 없는 선택 화면' -and [math]::Abs($script:endAt - (60 + $script:failTotalMs / 1000.0 + $script:userYieldTotalMs / 1000.0)) -le 2) "(ESC 키 $($script:keyOnce), 코드 $($script:exitCode), 진단 '$($script:diagContext)', 양보 $($script:yieldWaits), 간격 $rl7cGap, 정지 $($script:endAt), 누적 실패 $([math]::Round($script:failTotalMs / 1000.0, 1)))"
}
#      (d) 알 수 없음 20초 + 5) 분기 판독에서 실패 시작: 알 수 없음 시계가 20초에 닿는 회전의 이벤트 헬퍼 판독부터 실패 [20, 50) → 실패 창 안 X 후보·양보 0,
#      첫 X 후보 ≥ 복구(≈50초 - 실패 전에 쌓인 유효 20초로 복구 뒤 순환 재개), 조정 마감(≈90초)에 throw
Reset-Case -Screen 'unknown'
$script:eventHook = { if ((Elapsed) -ge 20 -and $null -eq $script:capfailFrom) { $script:capfailFrom = 20; $script:capfailUntil = 50 } }
Run-Loop
Check-True 'RL7(d) 5) 분기 판독에서 실패 시작: 실패 창 안 X 후보·양보 0, 첫 X 후보 ≥ 50초, throw' ((ClicksIn 20 50) -eq 0 -and $script:yieldWaits -eq 0 -and (ThrewTimeout) -eq 1 -and ($script:clickTimes.Count -eq 0 -or $script:clickTimes[0] -ge 50)) "(첫 클릭 $($script:clickTimes[0]), 정지 $($script:endAt))"
#      (e) 알 수 없음 시계의 동결: 'unknown' 0~10초 → 캡처 실패 [10, 40) → 복구 뒤 'unknown' 계속 → 첫 X 후보 = 40 + (20 − 10) ≈ 50초 (± 1.5 - 미룸은 직전 회전 길이 단위)
Reset-Case -Screen 'unknown'
$script:capfailFrom = 10; $script:capfailUntil = 40
Run-Loop
Check-True 'RL7(e) 알 수 없음 시계 미룸: 첫 X 후보 ≈ 50초 (± 1.5), 실패 창 안 X 0' ($script:clickTimes.Count -ge 1 -and [math]::Abs($script:clickTimes[0] - 50) -le 1.5 -and (ClicksIn 10 40) -eq 0) "(첫 X $($script:clickTimes[0]))"

# ── 10. RLP 선택 화면 출처 (⑥e 설계 2.14 - 09-30 리뷰5 P1-1 · 사용자 결정 D7) ───────────────────────────────
# RLP1. 던전 안 오버레이로 시작(화면 'selection', 워커 클릭 없음): 완료 0, 코드 4(진단 문맥), 출처 없음 안내 1, ESC·어비스·X 후보·메뉴 닫기·오클릭 ESC 0,
#       throw 없음, 정지 60~62초. 옛 코드: 첫 회전에 '선택 화면 복귀 확인'(거짓 완료 - 09-20 실사고의 모양)
Reset-Case -Screen 'selection'
Run-Loop
Check-True 'RLP1 오버레이로 시작: 완료 0, 코드 4, 진단 문맥, 출처 없음 안내 1, 클릭·키 0, throw 없음, 정지 60~62초' ((Done) -eq 0 -and $script:exitCode -eq 4 -and $script:diagContext -eq '어비스 복귀 중 출처 없는 선택 화면' -and (Unprov) -eq 1 -and (AllInput) -eq 0 -and $script:threw -eq '' -and $script:endAt -ge 60 -and $script:endAt -le 62) "(정지 $($script:endAt))"
#   (b) 보상 → 4) 분기 헬퍼 모의가 'selection' 을 돌려주고 화면을 선택 화면으로 → 다음 회전 출처 없음 → 코드 4, 헬퍼 호출 1 (부모 마감 전달)
Reset-Case -Screen 'reward'
$script:helperResult = 'selection'; $script:screenAfterHelper = 'selection'
Run-Loop
Check-True "RLP1(b) 헬퍼 'selection' → 출처 없음 코드 4, 헬퍼 호출 1, 부모 마감 전달" ((Done) -eq 0 -and $script:exitCode -eq 4 -and $script:helperCalls -eq 1 -and $null -ne $script:helperParent) "(코드 $($script:exitCode), 헬퍼 $($script:helperCalls))"
#   (c) 선택 화면 0~20초 → 필드(오버레이 닫힘): 20초 동안 클릭 0 → 필드 → W → ESC → 메뉴 → 어비스 → 완료 1 (출처 재발급 - 제한된 재판정)
Reset-Case -Screen 'selection'
$script:schedule = @(, @(20, 'field'))
Run-Loop
Check-True 'RLP1(c) 오버레이 닫힘 → 필드 → 재발급 완료 1, 20초 동안 클릭 0, 코드 없음' ((Done) -eq 1 -and (ClicksIn 0 20) -eq 0 -and $null -eq $script:exitCode) "(완료 $($script:endAt))"
# RLP2. 양보 뒤 오버레이: 필드 → ESC(토큰) → 다음 회전 게이트 조작(양보 뒤 선택 화면) → 어비스 전송 0, 완료 0, 코드 4
Reset-Case -Screen 'field'
$script:onFirstEsc = { $script:activeSeq = @($true); $script:activeIdx = 0; $script:screenAfterYield = 'selection' }
Run-Loop
Check-True 'RLP2 ESC 뒤 양보 중 오버레이: 어비스 전송 0, 완료 0, 코드 4' ($script:abyssClicksSent -eq 0 -and (Done) -eq 0 -and $script:exitCode -eq 4) "(코드 $($script:exitCode))"
#   (b) 느린 전이: 어비스 클릭 → 화면 'unknown' 8초 이상(확인 루프가 선택 화면을 못 봄, 오클릭 ESC 는 'unknown' 에서 화면 불변) → 게이트 조작 → 양보 뒤
#       선택 화면 → 완료 0·코드 4 (엄격 규칙의 대가 기록 - 설계 8절 23 ②)
Reset-Case -Screen 'field'
$script:abyssLeadsTo = 'unknown'; $script:escDetailLeadsTo = 'unknown'
$script:onAbyssClick = { $script:activeFrom = (Elapsed) + 9; $script:activeUntil = (Elapsed) + 11; $script:screenAfterYield = 'selection' }
Run-Loop
Check-True 'RLP2(b) 느린 전이 + 양보 → 완료 0, 코드 4' ((Done) -eq 0 -and $script:exitCode -eq 4 -and $script:yieldWaits -ge 1) "(코드 $($script:exitCode), 양보 $($script:yieldWaits))"
#   (b0) 같은 느린 전이 + 0ms 양보(누적 차분 0): 게이트의 명시 폐기가 막아 완료 0·코드 4 (누적 차분만으로는 못 잡는 경계 - 3차 리뷰 P1 선례)
Reset-Case -Screen 'field'
$script:abyssLeadsTo = 'unknown'; $script:escDetailLeadsTo = 'unknown'; $script:yieldSeconds = 0
$script:onAbyssClick = { $script:activeSeq = @($false, $true); $script:activeIdx = 0; $script:screenAfterYield = 'selection' }
Run-Loop
Check-True 'RLP2(b0) 느린 전이 + 0ms 양보 → 완료 0, 코드 4 (게이트의 명시 폐기)' ((Done) -eq 0 -and $script:exitCode -eq 4 -and $script:yieldWaits -ge 1) "(코드 $($script:exitCode), 양보 $($script:yieldWaits))"
#   (c) 판독 안 양보(게이트 밖): 오클릭 경로(어비스 → 상세, ESC → 알 수 없음)의 다음 회전 패널 판독 모의가 양보 누적만 올리고 화면을 선택 화면으로 →
#       유효성의 누적 차분이 막아 완료 0·코드 4
Reset-Case -Screen 'field'
$script:abyssLeadsTo = 'detail'; $script:escDetailLeadsTo = 'unknown'
$script:onAbyssClick = { $script:armYieldRead = $true }
$script:panelReadHook = { if ($script:armYieldRead -and $script:keyOnce -ge 1) { $script:armYieldRead = $false; $script:userYieldTotalMs += 100; $script:screen = 'selection' } }
Run-Loop
Check-True 'RLP2(c) 판독 안 양보(게이트 밖) → 완료 0, 코드 4' ((Done) -eq 0 -and $script:exitCode -eq 4) "(코드 $($script:exitCode), ESC 키 $($script:keyOnce))"
# RLP3. 정상(1절 기준 + ③)과 (b) 클릭 직후 조작: 조작이 클릭 다음 회전부터 참 → 완료 1·양보 0 (완료 예약이 게이트보다 먼저 - 확인 창)
Reset-Case -Screen 'field'
$script:onAbyssClick = { $script:activeSeq = @($true, $true, $true); $script:activeIdx = 0 }
Run-Loop
Check-True 'RLP3(b) 클릭 직후 조작 → 완료 1, 양보 0, 코드 없음' ((Done) -eq 1 -and $script:yieldWaits -eq 0 -and $null -eq $script:exitCode) "(양보 $($script:yieldWaits))"
# RLP4. (a) 확인 루프의 선택 화면 판독이 '같은 호출 안 실패 뒤 참' → 완료 1 (같은 단계 실패 허용 - 기준은 그 시도의 판독 직전 일련번호)
Reset-Case -Screen 'field'
$script:selSameCallFail = $true
Run-Loop
Check-True 'RLP4(a) 확인 루프 같은 호출 실패 뒤 참 → 완료 1, 코드 없음' ((Done) -eq 1 -and $null -eq $script:exitCode) "(완료 $($script:endAt))"
#   (b) 마감 경계: ESC 가 56초 전까지 무시(재시도 간격 ≈8.3초 - 마지막 유효 ESC ≈56초) → 어비스 클릭 ≈58초 → 확인 루프가 60초 뒤 선택 화면(같은 호출 실패
#       모드 포함) → 완료 1·throw 없음·완료 시각 ≥ 60초 (완료가 만료보다 먼저 - ⑥a 구현 리뷰 2차 P1 를 출처 있는 배치로)
Reset-Case -Screen 'field'
$script:escIgnoreUntil = 56; $script:selSameCallFail = $true
Run-Loop
Check-True 'RLP4(b) 마감 경계: 완료 1, throw 없음, 완료 시각 ≥ 60초' ((Done) -eq 1 -and $script:threw -eq '' -and $script:endAt -ge 60) "(완료 $($script:endAt), 어비스 $($script:abyssTimes -join ','), ESC $($script:escTimes -join ','))"
# RLP5. 발급 뒤 캡처 실패: 어비스 클릭 뒤 [2, 5)초 시간창 캡처 실패(확인 루프 판독 실패 → 다음 회전 동결 → 탐침 복구) → 선택 화면이지만 출처 무효 →
#       완료 0·코드 4·출처 없음 안내 1 (엄격 규칙의 대가 기록)
Reset-Case -Screen 'field'
$script:onAbyssClick = { $script:capfailFrom = (Elapsed) + 2; $script:capfailUntil = (Elapsed) + 5 }
Run-Loop
Check-True 'RLP5 발급 뒤 캡처 실패 → 완료 0, 코드 4, 출처 없음 안내 1' ((Done) -eq 0 -and $script:exitCode -eq 4 -and (Unprov) -eq 1) "(코드 $($script:exitCode))"
# RLP6. 09-15 오클릭 경로: 어비스 → 상세 → 확인 6회 음성 → 오클릭 ESC 1(진단 '어비스 메뉴 오클릭') → 선택 화면 → 다음 회전 1) 에서 완료 1 (출처 유지)
Reset-Case -Screen 'field'
$script:abyssLeadsTo = 'detail'
Run-Loop
Check-True "RLP6 09-15 오클릭 경로: 오클릭 ESC 1, 진단 문맥, 완료 1" ($script:keyOnce -eq 1 -and (Done) -eq 1 -and $script:diagContext -eq '어비스 메뉴 오클릭') "(ESC 키 $($script:keyOnce), 진단 '$($script:diagContext)')"
#   (b) 같은 경로에서 1) 의 선택 화면 판독이 같은 호출 안 실패 뒤 양성 → 완료 1 (기준 = 회전 서두 일련번호 - 같은 단계 실패 허용)
Reset-Case -Screen 'field'
$script:abyssLeadsTo = 'detail'; $script:onAbyssClick = { $script:selSameCallFail = $true }
Run-Loop
Check-True 'RLP6(b) 오클릭 ESC 뒤 1) 의 같은 호출 실패 뒤 양성 → 완료 1' ((Done) -eq 1 -and $null -eq $script:exitCode) "(코드 $($script:exitCode))"
# RLP8. 필드 확정(W) - 던전 안 필드 모양으로 ESC 금지 (반영본 검증, 09-30 리뷰5 - 정합성 검증 P1). 'fieldMisread' 판독 근거는 test_abyss_party_signatures
#       entry-misread·inside-misread 재생(같은 두 판독 함수)
#   (a) 재매칭 자동 입장 뒤 입장 과도: 패널 0~10초 → 로딩 10~14초 → 필드 오독 14~17.5초(관측 과도 2.1~4.2초 안) → 던전 안 계속:
#       ESC·어비스·메뉴 닫기·X 후보 0, 완료 0, 던전 안 코드 4 (첫 던전 안 표본 ≈17.7 + 20 ≈ 37~40초), throw 없음
Reset-Case -Screen 'panel'
$script:schedule = @(@(10, 'loading'), @(14, 'fieldMisread'), @(17.5, 'inside'))
Run-Loop
Check-True 'RLP8(a) 재매칭 자동 입장 뒤 입장 과도: ESC·어비스·메뉴 닫기·X 0, 완료 0, 던전 안 코드 4 (36~41초), throw 없음' ((AllInput) -eq 0 -and (Done) -eq 0 -and $script:exitCode -eq 4 -and $script:diagContext -eq '어비스 복귀 중 던전 안 확인' -and $script:endAt -ge 36 -and $script:endAt -le 41 -and $script:threw -eq '') "(정지 $($script:endAt))"
#   (b) 보스 오독 교대: 던전 안 0~10 → 오독 10~11.4(2표본) → 던전 안 11.4~25 → 오독 25~26.4 → 던전 안: ESC 0·어비스 0·완료 0 → 던전 안 코드 4
Reset-Case -Screen 'inside'
$script:schedule = @(@(10, 'fieldMisread'), @(11.4, 'inside'), @(25, 'fieldMisread'), @(26.4, 'inside'))
Run-Loop
Check-True 'RLP8(b) 보스 오독 교대: ESC 0, 어비스 0, 완료 0, 던전 안 코드 4' ($script:escClicksSent -eq 0 -and $script:abyssClicksSent -eq 0 -and (Done) -eq 0 -and $script:exitCode -eq 4) "(정지 $($script:endAt))"
#   (c) 양보 뒤 재입장: 필드 → 2초 무렵 조작(→ 7초, 양보 뒤 로딩) → 로딩 ~11초 → 오독 11~14초 → 던전 안: 양보 전 필드 표본은 W 미달, 양보가 연속을 끊음 →
#       ESC 0·어비스 0·완료 0 → 코드 4
Reset-Case -Screen 'field'
$script:activeFrom = 2; $script:activeUntil = 7; $script:screenAfterYield = 'loading'
$script:schedule = @(@(11, 'fieldMisread'), @(14, 'inside'))
Run-Loop
Check-True 'RLP8(c) 양보 뒤 재입장: ESC 0, 어비스 0, 완료 0, 코드 4' ($script:escClicksSent -eq 0 -and $script:abyssClicksSent -eq 0 -and (Done) -eq 0 -and $script:exitCode -eq 4) "(정지 $($script:endAt))"
#   (d) 안전 중지 예약 + (a) 배치: 입장 과도 동안 예약 소비 0·안전 중지 코드 없음 → 던전 안 코드 4 (예약 파일은 GUI 가 지움)
Reset-Case -Screen 'panel'
$script:schedule = @(@(10, 'loading'), @(14, 'fieldMisread'), @(17.5, 'inside'))
$script:safeStopFlag = $true
Run-Loop
Check-True 'RLP8(d) 안전 중지 예약 + 입장 과도: 소비 0, 던전 안 코드 4' ($script:flagRemoved -eq 0 -and $script:exitCode -eq 4 -and $script:diagContext -eq '어비스 복귀 중 던전 안 확인') "(소비 $($script:flagRemoved), 코드 $($script:exitCode))"
#   안전 중지 예약은 필드 확정(W) 뒤에만 소비 → 호출부 코드(준비 실행 10)
Reset-Case -Screen 'field'
$script:safeStopFlag = $true
Run-Loop -SafeStopExitCode 10
Check-True '안전 중지: 필드 확정 뒤 소비(W 이후), 코드 10' ($script:flagRemoved -eq 1 -and $script:exitCode -eq 10 -and $script:exitAt -ge $memberFieldSettleSeconds) "(소비 시각 $($script:exitAt))"
# 4) 분기: 헬퍼가 'expired'(헬퍼 안 복구 회전만 이어져 부모 마감에 닿음)를 돌려주면 break → 기존 throw, 헬퍼 호출 1 (부모 마감 전달)
Reset-Case -Screen 'reward'
$script:helperResult = 'expired'
Run-Loop
Check-True "4) 헬퍼 'expired' → throw, 헬퍼 호출 1, 부모 마감 전달" ((ThrewTimeout) -eq 1 -and $script:helperCalls -eq 1 -and $null -ne $script:helperParent) "(헬퍼 $($script:helperCalls))"

# ── 11. RLI ESC 메뉴 '어비스' 아이콘 폴백 (2026-10-07 설계 v2 10.3 - 설계 리뷰 ①·② 합의) ─────────────────────────────
# 글자 탐색이 유효 캡처에서 못 찾은 회전에서만, 그리고 그 회전의 메뉴 판정이 2차 신호('게임 종료')만으로 참일 때만 아이콘을 찾아 같은 클릭 블록으로
# 누릅니다(사용자 결정 2026-10-02 - 글자 먼저, 못 찾으면 아이콘). 실사고 4건(09-15 타 PC '어H|스' / 10-01·10-02 콘솔 전환 뒤 '어HI스')은 한 메뉴의
# 글자가 끝까지 안 읽혀 60초 마감 → 코드 1 이었습니다. 모의(Reset-Case 기본값): 글자 결과 textAbyssMode · 아이콘 결과 iconMode · 메뉴 판정 신호
# menuSignalMode · 추적기 판독문 'FIELDMOCK'. 시각은 하니스 가상 시계(판독 0초 + 대기만 흐름)라 실제보다 짧아 코드·횟수만 단언합니다
function MissLogs { return (Count-Log "메뉴에서 '어비스' 글자를 찾지 못했습니다") }
function IconFoundLogs { return (Count-Log '아이콘으로 찾았습니다') }
function IconClickLogs { return (Count-Log '어비스 메뉴 클릭 \(아이콘 탐색 화면좌표') }
function TextClickLogs { return (Count-Log '어비스 메뉴 클릭 \(글자 탐색 화면좌표') }
function IconCallsOn { param([string]$Screen) return @($script:iconScreens | Where-Object { $_ -eq $Screen }).Count }
# RLI0 글자 성공 (회귀 기준): 지금과 같은 경로 - 아이콘 코드 0회
Reset-Case -Screen 'field'
Run-Loop
Check-Equal 'RLI0 글자 성공: 아이콘 호출 0, 글자 클릭 로그 1, 아이콘 찾음·클릭 로그 0, 어비스 1, 복귀 확인 1, 미발견 0, 코드·throw 없음' ("$($script:iconCalls)/$(TextClickLogs)/$(IconFoundLogs)/$(IconClickLogs)/$($script:abyssClicksSent)/$(Done)/$(MissLogs)/$($script:exitCode)/$($script:threw)") '0/1/0/0/1/1/0//'
# RLI1 글자 유효 실패 + 아이콘 found → 같은 클릭 블록으로 누르고 출처 있는 완료 (결말 변화: 지금은 60초 → 코드 1). 찾음 줄 꼬리에 필드 확정 때 추적기
#      판독문(토큰 발급 줄의 스냅숏 - 변이 V18)과 메뉴 판정 신호(설계 리뷰 ② P1-2)가 남고, 클릭 줄은 탐색 출처 '아이콘 탐색'(변이 V10)
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'
Run-Loop
Check-Equal 'RLI1 글자 실패 + 아이콘 found: 아이콘 호출 1, 찾음 로그 1, 아이콘 클릭 로그 1, 글자 클릭 로그 0, 어비스 1, 복귀 확인 1, 미발견 0, 던전 안 클릭 0, 코드·throw 없음' ("$($script:iconCalls)/$(IconFoundLogs)/$(IconClickLogs)/$(TextClickLogs)/$($script:abyssClicksSent)/$(Done)/$(MissLogs)/$($script:abyssClickedFromInside)/$($script:exitCode)/$($script:threw)") '1/1/1/0/1/1/0/0//'
$rli1Found = [string](@($script:logs | Where-Object { $_ -match '아이콘으로 찾았습니다' }) | Select-Object -First 1)
Check-True "RLI1 찾음 줄: 본문 바로 뒤 ' (판독: 일치도 …' 꼬리, 필드 확정 때 추적기 'FIELDMOCK', 끝이 '메뉴 판정 신호 exit-label)'" ($rli1Found -match '\[어비스\] 메뉴의 ''어비스'' 글자가 읽히지 않아 아이콘으로 찾았습니다 \(판독: 일치도 0\.913, 2등 0\.500, 크기 30, [^\r\n]*, 필드 확정 때 추적기 ''FIELDMOCK'', 메뉴 판정 신호 exit-label\)$') "($rli1Found)"
$rli1Click = [string](@($script:logs | Where-Object { $_ -match '어비스 메뉴 클릭 \(' }) | Select-Object -First 1)
Check-True "RLI1 클릭 줄 = '어비스 메뉴 클릭 (아이콘 탐색 화면좌표 971,531)' (아이콘 결과의 라벨 상당점 그대로)" ($rli1Click -match '\[어비스\] 어비스 메뉴 클릭 \(아이콘 탐색 화면좌표 971,531\)$') "($rli1Click)"
# RLI2 글자 유효 실패 + 아이콘 not-found 지속: 누르지 않음(고정 좌표 폴백 금지 - 08-08 광고 배너 실사고), 미발견 줄은 전부 아이콘 판독 꼬리이고 아이콘을
#      찾은 회전마다 한 번, 3회째 진단, 지금과 같은 마감 throw
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'; $script:iconMode = 'notfound'
Run-Loop
$rli2Untailed = @($script:logs | Where-Object { $_ -match '글자를 찾지 못했습니다' -and $_ -notmatch ' - 재시도 \(\d+\) \(판독: 아이콘 일치도 [0-9.]+, 2등 [0-9.]+, 크기 \d+ - 기준 미달, 창 [^\r\n]+\)$' }).Count
Check-Equal 'RLI2 아이콘 not-found 지속: 어비스 0, 미발견 ≥ 1 이고 전부 아이콘 판독 꼬리, 미발견 수 = 아이콘 호출 수, 진단 문맥, 마감 throw, 코드 없음' ("$($script:abyssClicksSent)/$([int]((MissLogs) -ge 1))/$rli2Untailed/$([int]((MissLogs) -eq $script:iconCalls))/$($script:diagContext)/$(ThrewTimeout)/$($script:exitCode)") '0/1/0/1/어비스 메뉴 항목 미발견/1/'
# RLI3 글자 탐색 캡처 실패 1회 (가드#1 - 규칙 15): 그 회전은 아이콘 0·미발견 0 → 다음 회전 동결(토큰 폐기) → 메뉴 닫기 → 필드 재증명 → 글자로 완료
Reset-Case -Screen 'field'
$script:failOnceAt = @{ 'Find-GameTextPoint:어비스' = 1 }
Run-Loop
Check-Equal 'RLI3 글자 캡처 실패: 아이콘 호출 0, 미발견 0, 안전 확인 1, 메뉴 닫기 1, ESC 2, 어비스 1, 복귀 확인 1' ("$($script:iconCalls)/$(MissLogs)/$($script:safeStopCalls)/$($script:keyVerified)/$($script:escClicksSent)/$($script:abyssClicksSent)/$(Done)") '0/0/1/1/2/1/1'
# RLI4 글자 유효 실패 + 아이콘 캡처 실패 1회 (가드#2): 그 회전은 클릭 0·미발견 0 → 동결 → 닫기 → 재증명 → 새 메뉴의 두 번째 아이콘으로 완료
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'; $script:failOnceAt = @{ 'Find-AbyssMenuIconPoint' = 1 }
Run-Loop
Check-Equal 'RLI4 아이콘 캡처 실패: 아이콘 호출 2, 미발견 0, 메뉴 닫기 1, ESC 2, 어비스 1, 복귀 확인 1' ("$($script:iconCalls)/$(MissLogs)/$($script:keyVerified)/$($script:escClicksSent)/$($script:abyssClicksSent)/$(Done)") '2/0/1/2/1/1'
# RLI5 아이콘 found + 클릭 생략(user-active) → 양보 중 던전 안 메뉴: 생략 자리의 토큰·출처 폐기가 그대로 막음 (2절 글자 경로 P1 과 같은 결과 - 규칙 4)
Reset-Case -Screen 'field' -SendSeq @('sent', 'user-active')
$script:textAbyssMode = 'miss'; $script:screenAfterYield = 'menuInside'
Run-Loop
$rli5SkipLogs = Count-Log '어비스 메뉴 클릭 건너뜀 \(사용자 조작\)'
Check-Equal 'RLI5 아이콘 클릭 생략 → 양보 중 던전 안 메뉴: 어비스 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, 양보 1, 던전 안 메뉴에서 아이콘 호출 0, 생략 로그 1, 아이콘 클릭 로그 0' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$($script:yieldWaits)/$(IconCallsOn 'menuInside')/$rli5SkipLogs/$(IconClickLogs)") '0/0/1/4/1/0/1/0'
# RLI6 (특성 - 설계 4.3) 아이콘 클릭 무반응 지속(메뉴 그대로): 클릭 전송 직후 토큰 소비 → 같은 메뉴를 다시 누르지 않고 닫기·필드 재증명 반복 →
#      네 번째 닫기가 필요해지는 시점에 기존 코드 4 (문구는 기존 '(던전 안일 수 있음)' - 원인과 다른 문구는 범위 밖, 사용자 결정 Q8 이슈 목록 등재)
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'; $script:abyssLeadsTo = 'menu'
Run-Loop
$rli6StopLogs = Count-Log '필드를 확인하지 못한 채 메뉴가 계속 열려 있어[^\r\n]*\(던전 안일 수 있음\)'
Check-Equal 'RLI6 아이콘 클릭 무반응 지속: 어비스 4, 메뉴 닫기 3, 코드 4, 정지 문구 1, throw 없음, 던전 안 클릭 0' ("$($script:abyssClicksSent)/$($script:keyVerified)/$($script:exitCode)/$rli6StopLogs/$($script:threw)/$($script:abyssClickedFromInside)") '4/3/4/1//0'
# RLI6b (특성) 아이콘 오클릭 지속(매번 다른 화면 → 오클릭 ESC 로 메뉴): 오클릭 ESC → 토큰 없는 메뉴 닫기 → 재증명을 되풀이하다 60초 마감 throw(코드 1)가
#       네 번째 닫기(코드 4)보다 먼저
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'; $script:abyssLeadsTo = 'detail'; $script:escDetailLeadsTo = 'menu'
Run-Loop
Check-Equal 'RLI6b 아이콘 오클릭 지속: 어비스 3, 오클릭 ESC 3, 메뉴 닫기 3, 마감 throw, 코드 없음, 던전 안 클릭 0' ("$($script:abyssClicksSent)/$($script:keyOnce)/$($script:keyVerified)/$(ThrewTimeout)/$($script:exitCode)/$($script:abyssClickedFromInside)") '3/3/3/1//0'
# RLI6c (설계 리뷰 ① P3) 아이콘 클릭 첫 회 무반응(메뉴 그대로) → 토큰 소비 → 닫기·필드 재증명 → 새 메뉴에서 다시 아이콘 → 클릭 반응 → 출처 있는 완료
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'; $script:abyssLeadsTo = 'menu'
$script:onAbyssClick = { $script:abyssLeadsTo = 'selection' }   # 첫 클릭은 메뉴 그대로, 다음 클릭부터 선택 화면
Run-Loop
Check-Equal 'RLI6c 아이콘 클릭 일시 무반응: 어비스 2, 메뉴 닫기 1, 복귀 확인 1, 코드 없음, throw 없음, 아이콘 호출 2' ("$($script:abyssClicksSent)/$($script:keyVerified)/$(Done)/$($script:exitCode)/$($script:threw)/$($script:iconCalls)") '2/1/1///2'
# RLI6d (설계 리뷰 ① P3 · 09-15 경로) 아이콘 오클릭 → 오클릭 ESC 로 선택 화면: 클릭 전송 뒤 발급한 선택 화면 출처가 살아 있어(오클릭 경로는 출처를
#       지우지 않음) 다음 회전 서두에서 완료 (호출부 코드 0/10)
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'; $script:abyssLeadsTo = 'detail'
Run-Loop
Check-Equal 'RLI6d 아이콘 오클릭 → ESC 로 선택 화면: 어비스 1, 오클릭 ESC 1, 메뉴 닫기 0, 복귀 확인 1, 코드 없음, throw 없음, 던전 안 클릭 0' ("$($script:abyssClicksSent)/$($script:keyOnce)/$($script:keyVerified)/$(Done)/$($script:exitCode)/$($script:threw)/$($script:abyssClickedFromInside)") '1/1/0/1///0'
# RLI7 (C7) 출처 없는 메뉴(시작부터 열림) + 글자 실패 + 아이콘 found: 그 메뉴에서는 아이콘 호출 0·클릭 0 - 닫고 필드를 증명한 뒤 워커가 연 메뉴에서만 아이콘
Reset-Case -Screen 'menu'
$script:textAbyssMode = 'miss'
Run-Loop
$rli7FirstIcon = $(if ($script:iconTimes.Count -ge 1) { $script:iconTimes[0] } else { -1 })
$rli7FirstEsc = $(if ($script:escTimes.Count -ge 1) { $script:escTimes[0] } else { 99999 })
Check-Equal 'RLI7 출처 없는 메뉴: 첫 아이콘 호출은 워커 ESC 뒤, 메뉴 닫기 1, 어비스 1, 복귀 확인 1' ("$([int]($rli7FirstIcon -gt $rli7FirstEsc))/$($script:keyVerified)/$($script:abyssClicksSent)/$(Done)") '1/1/1/1'
# RLI7b (C7) 출처 없는 던전 안 메뉴 + 글자 실패 + 아이콘 found: 아이콘 호출 0, 어비스 0, 던전 안 클릭 0, 닫기 1 → 던전 안 확인 코드 4
Reset-Case -Screen 'menuInside'
$script:textAbyssMode = 'miss'
Run-Loop
Check-Equal 'RLI7b 출처 없는 던전 안 메뉴: 아이콘 호출 0, 어비스 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4' ("$($script:iconCalls)/$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)") '0/0/0/1/4'
# RLI8 (C7) 토큰 발급 뒤 캡처 공백 중 던전 안 메뉴(3절 3b 장치) + 아이콘 found: 메뉴 분기 입구의 토큰 대조가 폐기 → 아이콘 호출 0·클릭 0 → 닫기 → 코드 4
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'; $script:panelFailAfterEsc = $true; $script:screenAtPanelFail = 'menuInside'
Run-Loop
Check-Equal 'RLI8 발급 뒤 캡처 공백 + 던전 안 메뉴: 아이콘 호출 0, 어비스 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4' ("$($script:iconCalls)/$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)") '0/0/0/1/4'
# RLI9 (특성 - 수용 위험 R10, 사용자 결정 Q7 (a)) 지속 필드 오독('fieldMisread' - 던전 안인데 추적기 던전명 없음이 W 를 넘게 이어짐) → ESC → 던전 안 메뉴:
#      글자 경로(정상 렌더 - 글자 성공)·아이콘 경로(렌더 이상 - 글자 실패 + 아이콘 found) 모두 던전 안 클릭 1·완료 1. 폴백은 글자 경로의 기존 잔여 위험을
#      렌더 이상 상태로 넓힐 뿐 새 경로가 아님 - 수용한 위험의 모양을 고정합니다 (동작이 바뀌면 이 사례가 알림)
Reset-Case -Screen 'fieldMisread'
Run-Loop
$rli9Text = "$($script:abyssClickedFromInside)/$(Done)/$($script:iconCalls)"
Reset-Case -Screen 'fieldMisread'
$script:textAbyssMode = 'miss'
Run-Loop
$rli9Icon = "$($script:abyssClickedFromInside)/$(Done)/$($script:iconCalls)"
Check-Equal 'RLI9 지속 필드 오독 → 던전 안 메뉴 (수용 위험 R10): 던전 안 클릭/완료/아이콘 호출 = 글자 경로 1/1/0 | 아이콘 경로 1/1/1' "$rli9Text|$rli9Icon" '1/1/0|1/1/1'
# RLI10 (D-R - 설계 리뷰 ① P2) 메뉴 판정이 1차 신호('어비스'/'비스' 조각)로 참인 회전 + 글자 유효 실패 지속: 아이콘을 찾지 않음(아이콘 일치는 '그 그림이
#       하나뿐' 만 보장 - '메뉴임' 은 '게임 종료' 로만 참인 회전이 따로 보증). 미발견 줄은 전부 '아이콘 탐색 안 함' 꼬리, 지금과 같은 마감 throw
Reset-Case -Screen 'field'
$script:textAbyssMode = 'miss'; $script:menuSignalMode = 'abyss-text'
Run-Loop
$rli10Untailed = @($script:logs | Where-Object { $_ -match '글자를 찾지 못했습니다' -and $_ -notmatch ' - 재시도 \(\d+\) \(판독: 아이콘 탐색 안 함 - [^\r\n]+\)$' }).Count
Check-Equal "RLI10 1차 신호 메뉴 + 글자 실패 지속: 아이콘 호출 0, 어비스 0, 미발견 ≥ 1 이고 전부 '아이콘 탐색 안 함' 꼬리, 마감 throw, 코드 없음" ("$($script:iconCalls)/$($script:abyssClicksSent)/$([int]((MissLogs) -ge 1))/$rli10Untailed/$(ThrewTimeout)/$($script:exitCode)") '0/0/1/0/1/'

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
