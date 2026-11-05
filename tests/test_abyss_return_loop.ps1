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
#      패널 닫기·던전 퇴장, 판정이 없으면 '알 수 없는 화면 20초' 폴백이 X 후보를 누름), 마감까지 이어지면 진단 + 코드 4 (재매칭 패널은 안전 중지가 없으면 throw, 있으면 ⑬ 의 마감 출구)
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
#   ⑫ ESC 클릭 자리 탐색 (2026-11-04 구현 명세 ESC탐색 1절 · 3.2 - RLE0~RLE10): 일반 판독이 유효하게 못 찾으면 같은 회전에 이진화/한국어 판독을 한 번 더 하고, 둘 다 유효하게 못 찾으면
#      번갈아 누르지 않고 커서를 치운 뒤 다시 읽거나(E5) 실제 창 너비로 고른 고정점을 누름(E6 - 큰 창은 새 점 · 옛 점 번갈아). 캡처 실패 회전은 세지도 누르지도 않고, 끝내 안 열리면
#      지금처럼 복귀 마감 코드 1
#   ⑬ 복귀 마감 연장과 마감 뒤 안전 중지 (2026-11-04 구현 명세 복귀연장 1절 · 3절 - RLX0~RLX8): 아는 창에 입력을 실제로 보낸 회전에서만 마감을 그 시점에 기본 예산이 남게 늘리고(전체 상한은 양보 · 캡처 실패를 뺀 시간),
#      X 후보 · '확인' 낱말 · 복귀 본 동작은 사유가 아닙니다. 마감이 끝났을 때 안전 중지가 걸려 있으면 오류가 아니라 호출부 코드로 끝내고(신호 소비 → [완료] 세 갈래 → 진단 캡처 · 로그 사본 → exit, 열쇠 항목은 닫지 않음), 없으면 지금처럼 throw.
#      추가 건 (RLX1l~r): 공지 게시판이 HUD 까지 가리면 '알 수 없는 화면' 쪽에서 탭 글자로 알아봐 바로 닫습니다 - 판독은 앞 경로 뒤 · 캡처 실패 가드 앞, 소비는 가드 뒤 · X 후보 앞
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
# ESC 글자 탐색 · 고정점 고르기(구현 명세 ESC탐색 3.2)도 운영 함수 그대로입니다 - 창 너비를 읽는 Get-AbyssEscFallbackPoint 만 아래 모의가 맡습니다
# 복귀 마감 연장의 판정 · 마감 갱신(구현 명세 복귀연장 2.2)도 운영 함수 그대로입니다
foreach ($name in @('Get-YieldAdjustedDeadline', 'Invoke-UserYieldWithDeadline', 'Get-FreezeAdjustedDeadline', 'Test-AbyssSelectionProvenance', 'Find-AbyssEscButtonPoint', 'Select-AbyssEscFallbackPoint', 'Get-AbyssReturnGrantMs', 'Update-AbyssReturnDeadlineOnSend', 'Get-NoticeCloseReferenceFromClient')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}
$loopDef = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Return-ToAbyssSelection'))
# exit 7곳 = 안전 중지 3(완료 블록·필드 확정 뒤·while 뒤 마감 만료 - 구현 단위 복귀 연장 M1) + 메뉴 출처 미확인 + 던전 안 확인 + 준비 패널 지속(⑥a) + 출처 없는 선택 화면(⑥e 2.14)
$loopExitPattern = '(?m)^\s*exit (4|\$SafeStopExitCode)\s*$'
Check-Equal '추출: 복귀 루프의 exit 는 7곳 (안전 중지 3 + 메뉴 출처 미확인 + 던전 안 확인 + 준비 패널 지속 - ⑥a + 출처 없는 선택 화면 - ⑥e 2.14)' ([regex]::Matches($loopDef, $loopExitPattern).Count) 7
# 구현 단위 복귀 연장 3.1: exit 문 수(AST) = 치환 수 - 모양이 다른 exit 가 치환되지 않으면 진짜 exit 로 이 테스트가 끝나고, 코드 0 이면 러너가 통과로 칩니다 (run_all_tests 는 FAIL 줄과 종료 코드만 봄)
function Get-ExitStatementCount { param([string]$Text)
  return @([System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$null, [ref]$null).FindAll({ param($node) $node -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count
}
Check-Equal '추출: 복귀 루프의 exit 문 수(AST) = 치환 대상 수' (Get-ExitStatementCount -Text $loopDef) ([regex]::Matches($loopDef, $loopExitPattern).Count)
$loopDef = $loopDef -replace '(?m)^(\s*)exit 4\s*$', '$1$script:exitCode = 4; $script:exitAt = (Elapsed); return'
$loopDef = $loopDef -replace '(?m)^(\s*)exit \$SafeStopExitCode\s*$', '$1$script:exitCode = $SafeStopExitCode; $script:exitAt = (Elapsed); [void]$script:exitOrder.Add(''종료''); return'
Check-Equal '추출: 치환 뒤 복귀 루프에 남은 exit 문 0' (Get-ExitStatementCount -Text $loopDef) 0
Invoke-Expression $loopDef
# 필드 확정 폭 W 와 키워드·영역 · 복귀 전체 상한은 소스 대입문에서 캡처 (숫자를 테스트에 다시 박지 않음 - 소스가 바뀌면 기대도 함께 움직임)
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
foreach ($sourceVar in @('memberFieldSettleSeconds', 'allDungeonKeywords', 'rgAbyssCards', 'rgAbyssSelect', 'ptEscButton', 'ptEscButtonLarge', 'escLargeWindowMinWidth', 'abyssReturnTotalLimitSeconds', 'rgEventSkip', 'rgEventReward', 'rgEventConfirm', 'noticeCloseCenterRatio', 'noticeCloseTopRatio', 'noticeCloseTryLimit')) {
  $assign = $sourceAst.Find({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq ('$' + $sourceVar)) }, $true)
  if (-not $assign) { "FAIL 본체에서 `$$sourceVar 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $assign.Extent.Text
}
Check-True '캡처: 필드 확정 폭 W 는 소스 값 (입장 과도 4.2초 < W < 스윕 대기 30초 - 설계 ㉷)' ($memberFieldSettleSeconds -gt 4.2 -and $memberFieldSettleSeconds -lt 30) "(W=$memberFieldSettleSeconds)"

# ── 운영 상수 (값은 계약과 무관 - 마감 60초·영역 좌표만 형식을 맞춤) ──
$timeoutHud = 30; $timeoutAbyssMenu = 15; $timeoutAbyssSelect = 15
$safeStopFlagPath = 'HoneyNogi_safe_stop_test.flag'
$rgAbyssMenu = @(850, 180, 350, 520); $rgHomeEndEsc = @(1000, 40, 260, 90); $ocrEnglishEngine = 'en'
$rgStellaTitle = @(0, 0, 10, 10); $ocrKoreanEngine = 'ko'; $ptStellaCard = @(0, 0); $rgStellaPickBtn = @(0, 0, 10, 10)
$rgClearExit = @(430, 570, 420, 125)
$refocusEverySeconds = 0
# 복귀 전체 상한 C 는 소스 값, 기본 예산 B 는 위 하니스 값입니다 (소스 대입은 Get-ConfigInteger 라 캡처되지 않음). 새 상수가 캡처에서 빠지면 연장 예산이 음수라 조용히 연장 0 입니다 - 여기서 먼저 막습니다
$rlxBase = $timeoutHud + $timeoutAbyssMenu + $timeoutAbyssSelect
$rlxLimit = $abyssReturnTotalLimitSeconds
Check-True '캡처: 복귀 전체 상한 C 는 기본 예산 B 보다 큼 (없으면 조용히 연장 0)' ($rlxLimit -gt $rlxBase) "(C=$rlxLimit, B=$rlxBase)"
# 아는 창 (구현 단위 복귀 연장 3.1): 그 창을 닫는 점과 그 창에서만 읽히는 글자입니다. 판독 모의는 판독만 하고 메타는 클릭(Send-Mock)이 세웁니다 - 판독 모의가 메타를 직접 세우면 헛모형입니다.
# 같은 좌표라도 다른 화면이면 그 밖의 클릭입니다. 'stella1' 의 점은 운영 $ptStellaCard, 고스트는 '나중에' 실측 자리, 세 헬퍼의 점은 운영 본문의 좌표 · 표본입니다
$windowPoints = @{
  'ghost' = '713,652'; 'stella1' = "$($ptStellaCard[0]),$($ptStellaCard[1])"; 'stella2' = '5,5'
  'skipBook' = '1187,67'; 'confirmWord' = '640,652'; 'coopBoard' = '1228,67'; 'network' = '764,619'; 'weekly' = '495,654'
}
# 공지 게시판의 X 만 점이 아니라 버튼 크기입니다. 이 모형은 1272 · 창 DPI 144 창입니다 (그림 던전이미지\어비스\20261104_복귀연장_실기\공지게시판_1272_클릭전.png). 그 그림의 글자는 x 1072~1084 · y 143~154 이고, 상자는 글자에 여유 2px 입니다.
# 이 창의 관측은 셋입니다 (11-05): (1092,135) 는 42번 눌러도 안 닫혔고, X 후보 둘째 (1090,137) 도 한 번 눌러 안 닫혔고(공지_1272_1090_137_*.png), 계산 자리 (1078,149) 는 한 번에 닫혔습니다.
# X 후보 둘째가 닫은 11-04 기준선은 **다른 창**(창 DPI 96, 클라이언트 1256x678 - 그 창에서는 그 점이 글자 위)입니다. 사례 값 noticeSecondXCloses 가 그 창의 모양입니다. 두 창의 관측을 섞어 만든 앞 모형은 코드와 같이 틀렸습니다 (규칙 9)
$noticeCloseBox = @{ Left = 1070; Top = 141; Right = 1086; Bottom = 156 }
function Test-NoticeCloseHit { param([int]$X, [int]$Y)
  if ($script:noticeSecondXCloses -and $X -eq 1090 -and $Y -eq 137) { return $true }
  return ($X -ge $noticeCloseBox.Left -and $X -le $noticeCloseBox.Right -and $Y -ge $noticeCloseBox.Top -and $Y -le $noticeCloseBox.Bottom)
}
# 계산 자리는 운영 식으로 구합니다 (창 정보는 11-05 실기 로그). 5) 분기 · HUD 분기의 자리 함수 모의가 이 값을 돌려주고, 빗나감 행(RLX1s)만 옛 고정점을 돌려줍니다
$referenceWidth = 1272; $referenceHeight = 717
$rlxNoticePoint = @(Get-NoticeCloseReferenceFromClient -WindowLeft 972 -WindowTop 10 -WindowWidth 1272 -WindowHeight 717 -ClientLeft 983 -ClientTop 55 -ClientWidth 1250 -ClientHeight 661)
$rlxNoticeOldPoint = @(1092, 135)
Check-True '캡처: 공지 X 버튼 모형은 계산 자리를 품고, 11-05 에 42번 빗나간 옛 고정점과 사례 값 없는 X 후보 셋은 품지 않음' ((Test-NoticeCloseHit -X $rlxNoticePoint[0] -Y $rlxNoticePoint[1]) -and (-not (Test-NoticeCloseHit -X 1090 -Y 137)) -and (-not (Test-NoticeCloseHit -X $rlxNoticeOldPoint[0] -Y $rlxNoticeOldPoint[1])) -and (-not (Test-NoticeCloseHit -X 1229 -Y 67)) -and (-not (Test-NoticeCloseHit -X 959 -Y 180))) "(계산 $($rlxNoticePoint -join ','))"
$screenTexts = @{
  'stella1'    = @{ X = $rgStellaTitle[0]; Y = $rgStellaTitle[1]; Text = '오늘의스텔라픽' }
  'attendDone' = @{ X = $rgEventReward[0]; Y = $rgEventReward[1]; Text = '출석완료우편으로지원품이지급되었습니다' }
  'coopBoard'  = @{ X = 120; Y = 45; Text = '협동미션' }
  'network'    = @{ X = 420; Y = 355; Text = '네트워크연결이불안정합니다' }
  'weekly'     = @{ X = $rgClearExit[0]; Y = $rgClearExit[1]; Text = '닫기협동미션참여하기' }
}

# ── 모의: 가상 시계 ──────────────────────────────────────────────────────────────
# 판독은 가상 시간을 쓰지 않고(실패 주입의 '느린 실패' 만 흘림), Start-Sleep·양보 대기가 시계를 전진시킵니다. 케이스 시작부터 가상 20000초를
# 넘기면 '__VTIMEOUT__' 로 끝냅니다 - 마감을 못 보는 변이가 러너를 멈추지 않게 (러너에는 자식 시간 제한이 없음)
function Elapsed { return (($script:vclock - $script:startClock).Ticks / 10000000.0) }   # TotalSeconds 는 1e-7 곱이라 3.6 → 3.5999… (창 경계 오판)
function Apply-Schedule {
  # 시각표 모드(RLP8 - screenSchedule): 가상 초 → 화면. 클릭 전이보다 먼저 적용합니다 (시각이 되면 다음 판독부터 그 화면)
  while ($script:schedIdx -lt $script:schedule.Count -and (Elapsed) -ge $script:schedule[$script:schedIdx][0]) {
    $script:screen = $script:schedule[$script:schedIdx][1]; $script:schedIdx++
  }
  # 안전 중지 신호 시각표 (구현 단위 복귀 연장 RLX8): 가상 초 → 켬/끔 (GUI 의 예약 파일 생성 · 취소 자리)
  while ($script:flagSchedIdx -lt $script:flagSchedule.Count -and (Elapsed) -ge $script:flagSchedule[$script:flagSchedIdx][0]) {
    $script:safeStopFlag = [bool]$script:flagSchedule[$script:flagSchedIdx][1]; $script:flagSchedIdx++
  }
}
function Advance { param([double]$Ms)
  $script:vclock = $script:vclock.AddMilliseconds($Ms)
  if ((Elapsed) -gt 20000) { throw '__VTIMEOUT__' }
  Apply-Schedule
}
function Get-Date { return $script:vclock }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) Advance ($Milliseconds + $Seconds * 1000) }
function Write-RunLog { param([string]$Message)
  [void]$script:logs.Add(('{0:N1} {1}' -f (Elapsed), $Message))
  if ($Message.StartsWith('[완료]')) { [void]$script:exitOrder.Add('완료줄') }   # 소비 · [완료] 줄 · 진단 · 종료의 순서 (구현 단위 복귀 연장 M1)
}
function Write-LifeDiagnostics { param($Game, $Context, [switch]$CaptureOnly, [switch]$WithLogCopy)
  $script:diagCalls++; $script:diagContext = $Context
  [void]$script:diagLog.Add(('{0}|{1}' -f $Context, [bool]$CaptureOnly)); [void]$script:events.Add('진단')   # -CaptureOnly 까지 남깁니다 (ESC 미발견 진단은 캡처만 - 명세 3.2)
  # 문맥과 두 스위치를 함께 남깁니다 (구현 단위 복귀 연장 3.1): 이 모의는 CmdletBinding 없는 단순 함수라 서명에 없는 이름 인자도 $args 로 조용히 받습니다 - 스위치 값은 행이 직접 단언합니다
  [void]$script:diagFull.Add(('{0}|{1}|{2}' -f $Context, [bool]$CaptureOnly, [bool]$WithLogCopy)); [void]$script:exitOrder.Add('진단')
}
function Focus-Game { param($Game) }
function Invoke-AutoRefocus { param($Game) return $false }
function Test-Path { param($LiteralPath, $Path) return [bool]$script:safeStopFlag }
function Remove-Item { param($LiteralPath, [switch]$Force, $ErrorAction) $script:flagRemoved++; $script:safeStopFlag = $false; [void]$script:exitOrder.Add('소비') }
# 열쇠 항목 닫기 모의: 던전 밖 확정 출구 전용입니다 - 만료 출구(M1)는 화면을 모르므로 부르지 않습니다 (구현 단위 복귀 연장 1.3)
function Close-AbyssKeyEntryOnLeave { param($Reason, $Screen) $script:keyCloseCalls++ }

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
#                  'panel'(재매칭 패널) / 'readyPanel'(파티 준비 패널) / 'entryWaiting'(접힌 준비 패널) / 'unknown' /
#                  구현 단위 복귀 연장 3.1 의 아는 창 - 'notice'(공지 게시판 - 07-19 타 PC 모양: 가장자리 HUD 가 읽혀 HUD 분기가 받음) / 'notice-covered'(공지 게시판 - 11-04 기준선 1272 모양: HUD 판독 거짓 · 탭 줄 판독 참이라 5) 분기가 받음) /
#                  'ghost' / 'stella1'(카드) / 'stella2'(확정 버튼) /
#                  운영 헬퍼 본문이 읽는 'skipBook'(출석부 건너뛰기) / 'attendDone'(출석 완료 지원품) / 'confirmWord'('확인' 낱말) / 'coopBoard'(협동 전체 창) / 'network' / 'weekly'
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
function Test-HomeEndEscHud { param($Game) return (Read-Mock 'Test-HomeEndEscHud' ($script:screen -eq 'field' -or $script:screen -eq 'fieldMisread' -or $script:screen -eq 'inside' -or $script:screen -eq 'notice')) }
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
  # 필드 표본 뒤의 판독 - N번째 호출에서 일시 캡처 실패 + 그 공백 중 화면 전이를 모의 (4차 리뷰 P1 '세탁'). noticeFailFrom 은 그 시각 뒤 첫 호출 한 번입니다 (RLX1r)
  # 탭 줄이 읽히는 화면은 사례 값 noticeScreens 입니다 - 비우면 공지가 떠 있어도 못 읽는 모양(RLX1o), 'ghost' 를 넣으면 고스트 창과 함께 참인 모양(RLX1p)
  $script:noticeCalls++
  [void]$script:noticeReadTimes.Add((Elapsed))
  if (($script:noticeCalls -eq $script:noticeFailAtCall) -or (($null -ne $script:noticeFailFrom) -and ((Elapsed) -ge $script:noticeFailFrom))) {
    $script:noticeFailFrom = $null
    [void]$script:noticeFailTimes.Add((Elapsed))   # 실패시킨 판독의 실제 시각 - '문턱 뒤 첫 판독' 으로 뽑으면 실패가 더 일찍 나도 전제가 참으로 보입니다 (RLX1r ①)
    $script:readCalls++; Register-Fail
    if ($script:screenAtNoticeFail) { $script:screen = $script:screenAtNoticeFail }
    return $false
  }
  $noticeRead = Read-Mock 'Test-NoticeBoardPopup' ($script:noticeScreens -contains $script:screen)
  if ($noticeRead) { [void]$script:noticeTrueTimes.Add((Elapsed)) }
  return $noticeRead
}
function Invoke-EventSkipOrConfirm { param($Game, $LogPrefix, $Outcome = $null)
  # 복구 분기의 이벤트 헬퍼 - 내부 user-active 대기가 0ms 로 끝나 누적 양보에 잡히지 않는 경우를 모의: 화면만 바뀌고 반환 $false (4차 리뷰 P1)
  # 구현 단위 복귀 연장 3.1: 시각표 eventPlan(At 이 지난 첫 호출에 Kind 하나 - YieldMs 면 그 앞에 헬퍼 안 양보) · eventEvery(매 호출 그 Kind)로 운영 헬퍼의 갈래를 모의합니다.
  #   Kind       메타   Outcome         반환  헬퍼 안 대기
  #   click      참     ''              참    2000   (협동 X · '건너' · 주간 '닫기' 꼴)
  #   click-confirm 참  'confirm-word'  참    2000
  #   click-network 참  ''              참    3000
  #   space      불변   'sent'          참    2000
  #   click-user · click-cursor 거짓 '' 참    2000   (클릭 생략)
  #   deferred   불변   ''              참    0      (주간 팝업 캡처 실패 미룸 - 캡처 실패 등록. 운영 본문은 RLX4f′)
  #   yield-false —     'user-active'   거짓  0
  # 참 갈래는 복귀 루프 쪽 대기 없이 continue 하므로 운영 헬퍼 안의 대기를 여기서 밀어 줍니다 (안 그러면 '매 회전 click' 행이 시계를 못 밀고 __VTIMEOUT__ 으로 끝남).
  # eventReal 이면 운영 본문을 그대로 돕니다 (RLX1g - 모의만 쓰면 코드와 테스트가 같은 가정으로 함께 틀립니다, 규칙 9). eventResults = 결과|메타|사유|Outcome 기록
  $script:eventCalls++
  if ($Outcome -is [ref]) { $script:eventOutcomeRefs++ }   # 단순 함수는 서명에 없는 이름 인자도 조용히 받습니다 - 호출부가 -Outcome 을 넘겼는지는 이 수로 봅니다
  if ($script:eventHook) { & $script:eventHook }
  if ($script:eventYieldToScreen) { $script:screen = $script:eventYieldToScreen; $script:eventYieldToScreen = '' }
  if ($script:eventReal) {
    $realResult = Invoke-EventSkipOrConfirmReal -Game $Game -LogPrefix $LogPrefix -Outcome $Outcome
    [void]$script:eventResults.Add(('real|{0}|{1}|{2}|{3}' -f $realResult, $script:lastClickPerformed, $script:lastClickSkipReason, $(if ($Outcome -is [ref]) { $Outcome.Value } else { '(ref 없음)' })))
    return $realResult
  }
  if ($Outcome -is [ref]) { $Outcome.Value = '' }   # 운영 헬퍼의 첫 문장
  $eventSerial = $script:captureFailSerial
  [void](Read-Mock 'Invoke-EventSkipOrConfirm' $false)
  if ($script:captureFailSerial -ne $eventSerial) { return $false }   # 판독 실패 회전은 어떤 갈래에도 닿지 않습니다
  $eventStep = $null
  if ($script:eventEvery) { $eventStep = @{ Kind = $script:eventEvery } }
  elseif ($script:eventPlan.Count -gt 0 -and (Elapsed) -ge $script:eventPlan[0].At) { $eventStep = $script:eventPlan[0]; $script:eventPlan = @($script:eventPlan | Select-Object -Skip 1) }
  if ($null -eq $eventStep) { return $false }
  if ($eventStep.YieldMs) { Advance $eventStep.YieldMs; $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $eventStep.YieldMs }   # 헬퍼 안 양보 - 시계와 누적만 올립니다 (RLX1i)
  $eventKind = [string]$eventStep.Kind; $eventWaitMs = 2000; $eventReturn = $true
  switch ($eventKind) {
    'click'         { Send-Mock -X 1187 -Y 67 }
    'click-confirm' { $script:confirmClicks++; Send-Mock -X 640 -Y 652; if ($script:lastClickPerformed -and ($Outcome -is [ref])) { $Outcome.Value = 'confirm-word' } }
    'click-network' { Send-Mock -X 764 -Y 619; $eventWaitMs = 3000 }
    'space'         { if ($Outcome -is [ref]) { $Outcome.Value = 'sent' } }
    'click-user'    { Send-Mock -X 1187 -Y 67 -Force 'user-active' }
    'click-cursor'  { Send-Mock -X 1187 -Y 67 -Force 'cursor-not-ready' }
    'deferred'      { Register-Fail; $eventWaitMs = 0 }
    'yield-false'   { if ($Outcome -is [ref]) { $Outcome.Value = 'user-active' }; $eventWaitMs = 0; $eventReturn = $false }
    default         { throw "__EVENT_KIND_${eventKind}__" }
  }
  [void]$script:eventResults.Add(('{0}|{1}|{2}|{3}' -f $eventKind, $script:lastClickPerformed, $script:lastClickSkipReason, $(if ($Outcome -is [ref]) { $Outcome.Value } else { '(ref 없음)' })))
  if ($eventWaitMs -gt 0) { Start-Sleep -Milliseconds $eventWaitMs }
  return $eventReturn
}
# 고스트 헬퍼는 닫기를 소유합니다 (구현 단위 복귀 연장 3.1 - 운영 함수처럼 'ghost' 화면이면 '나중에' 를 누르고 대기 2000 뒤 참, 클릭이 생략돼도 참). ghostResults = 메타|사유 기록
# ghostReal 이면 운영 본문을 그대로 돕니다 (RLX4c - '생략해도 참 · 메타 거짓' 은 그 행이 확인할 대상이라 모의가 미리 세우면 헛행입니다, 규칙 9)
function Close-GhostRegisterPrompt { param($Game, $LogPrefix)
  if ($script:ghostReal) {
    $ghostReturn = Close-GhostRegisterPromptReal -Game $Game -LogPrefix $LogPrefix
    if ($ghostReturn) { [void]$script:ghostResults.Add(('{0}|{1}' -f $script:lastClickPerformed, $script:lastClickSkipReason)) }
    return $ghostReturn
  }
  if (-not (Read-Mock 'Close-GhostRegisterPrompt' ($script:screen -eq 'ghost'))) { return $false }
  Send-Mock -X 713 -Y 652
  [void]$script:ghostResults.Add(('{0}|{1}' -f $script:lastClickPerformed, $script:lastClickSkipReason))
  Start-Sleep -Milliseconds 2000
  return $true
}
# 운영 Invoke-EventSkipOrConfirm 본문(RLX1g)이 부르는 세 헬퍼 - 기본은 없음(거짓), eventRealHelpers 면 운영 본문 그대로입니다 (RLX1g-x 는 성공 경로를 실제 본문으로 돕니다)
function Close-CoopMissionBoardScreen { param($Game, $LogPrefix) if ($script:eventRealHelpers) { return (Close-CoopMissionBoardScreenReal -Game $Game -LogPrefix $LogPrefix) }; return $false }
function Close-NetworkUnstablePopup { param($Game, $LogPrefix) if ($script:eventRealHelpers) { return (Close-NetworkUnstablePopupReal -Game $Game -LogPrefix $LogPrefix) }; return $false }
function Close-WeeklyCoopResetPopup { param($Game, $LogPrefix) if ($script:eventRealHelpers) { return (Close-WeeklyCoopResetPopupReal -Game $Game -LogPrefix $LogPrefix) }; return $false }
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine, [switch]$BinaryWhiteText)
  if ($script:rl4Mode) { $r = Pop-Rl4 'ocr'; if ($r.Fail) { return '' }; return [string]$r.Value }
  if ($script:screen -eq 'stella1' -and $ReferenceX -eq $rgStellaTitle[0] -and $ReferenceY -eq $rgStellaTitle[1]) { $script:stellaTitleReads++ }   # 스텔라 창이 떠 있는 동안의 제목 판독 수 (RLX1k)
  if (-not (Read-Mock 'Get-GameRegionOcrText' $true)) { return '' }
  # 그 창이 떠 있고 그 영역일 때만 글자가 읽힙니다 (구현 단위 복귀 연장 3.1 - 위 $screenTexts)
  $screenText = $screenTexts[$script:screen]
  if (($null -ne $screenText) -and ($ReferenceX -eq $screenText.X) -and ($ReferenceY -eq $screenText.Y)) { return [string]$screenText.Text }
  return ''
}
# 네트워크 팝업 '다시 시도하기' 단어 판독 (운영 Close-NetworkUnstablePopup 본문 - RLX1g-x): 2026-08-01 타 PC 실측 표본 그대로입니다
# 고스트 안내 두 버튼 (운영 Close-GhostRegisterPrompt 본문 - RLX4c): 영역은 운영 호출의 (500,620), '나중에' 는 2026-08-13 실측 자리입니다 ('고스트' 글자의 자리는 판정에 쓰이지 않습니다). 캡처 실패면 운영처럼 단어 없음입니다
function Get-GameRegionOcrWords { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine)
  if (-not (Read-Mock 'Get-GameRegionOcrWords' $true)) { return @() }
  if ($script:screen -eq 'network') { return @(@{ Text = 'kl도하기'; X = 764; Y = 619 }) }
  if ($script:screen -eq 'ghost' -and $ReferenceX -eq 500 -and $ReferenceY -eq 620) { return @(@{ Text = '고스트'; X = 590; Y = 652 }, @{ Text = '나중에'; X = 713; Y = 652 }) }
  return @()
}
# ESC 글자 탐색 모의 (구현 명세 ESC탐색 3.2): 일반 · 이진화는 판독 이름이 따로이고(Find-GameTextPoint:ESC · :ESC#bin - 실패 주입 failOnceAt 의 열쇠) 결과도 따로 지정합니다.
# 유효한 판독마다 escNormalSeq · escBinSeq 앞에서 'found' / 'miss' 를 하나씩, 다 쓰면 escNormalDefault · escBinDefault. 판독 모드와 엔진은 캡처 실패 판독까지 순서대로 escReads 에 남습니다.
# 두 판독의 점이 달라 어느 판독의 점을 눌렀는지 사건 · 로그로 갈립니다 (일반 점은 1908 실측 글자 중심의 기준 좌표)
$escTextPoint = @{ X = 1102; Y = 74 }; $escBinPoint = @{ X = 1103; Y = 76 }
function Find-GameTextPoint { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText, $ExactText, $Scale, $Engine, [switch]$BinaryWhiteText)
  if ($SearchText -eq 'ESC') { [void]$script:escReads.Add(('{0}:{1}' -f $(if ($BinaryWhiteText) { '이진화' } else { '일반' }), $Engine)) }
  $ok = Read-Mock ('Find-GameTextPoint:' + $SearchText + $(if ($BinaryWhiteText) { '#bin' } else { '' })) $true
  if (-not $ok) { return $null }
  if ($SearchText -eq 'ESC') {
    if ($BinaryWhiteText) {
      if ((Next-Seq 'escBin' $script:escBinDefault) -eq 'found') { return $escBinPoint }
      return $null
    }
    if ((Next-Seq 'escNormal' $script:escNormalDefault) -eq 'found') { return $escTextPoint }
    return $null
  }
  # 메뉴 '어비스' 글자 (설계 v2 10.3 ①): textAbyssMode 'miss' = 유효 캡처에서 못 찾음(렌더 이상으로 글자가 깨진 메뉴). 캡처 실패는 기존 failOnceAt 장치
  if ($SearchText -eq '어비스') { if ($script:textAbyssMode -eq 'miss') { return $null }; return @{ X = 971; Y = 531 } }
  # 아는 창의 글자 (구현 단위 복귀 연장 3.1): 그 창이 떠 있을 때만 점을 돌려줍니다 - 점은 위 $windowPoints 와 같습니다
  $windowWords = @{ 'stella2' = '스텔라'; 'skipBook' = '건너'; 'confirmWord' = '확인'; 'weekly' = '닫기' }
  if ($windowWords[$script:screen] -ceq $SearchText) {
    $windowXY = ([string]$windowPoints[$script:screen]) -split ','
    return @{ X = [int]$windowXY[0]; Y = [int]$windowXY[1] }
  }
  return $null
}
# 커서 모의 (구현 명세 ESC탐색 3.2): 사례 값 cursorOverGame 에서 시작해 대피하면 창 밖, 클릭이 나가면 게임 위입니다 (운영 Click-ScreenPoint 는 커서를 되돌리지 않음).
# 대피 안의 양보는 운영 계약대로 가상 시계 · 양보 누적만 올리고(parkYieldMs - 한 번 쓰면 0, 게이트를 지나지 않음), 그 양보 뒤 화면을 screenAfterPark 로 바꿉니다
function Test-CursorOverGame { param($Game) return [bool]$script:cursorOverGame }
function Move-CursorOutsideGame { param($Game)
  $script:parkCalls++; [void]$script:parkTimes.Add((Elapsed)); [void]$script:events.Add('대피')
  if ($script:parkYieldMs -gt 0) {
    $parkYield = $script:parkYieldMs; $script:parkYieldMs = 0
    Advance $parkYield
    $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $parkYield
  }
  if ($script:screenAfterPark) { $script:screen = $script:screenAfterPark; $script:screenAfterPark = '' }
  $script:cursorOverGame = $false
}
# 창 너비 모의 (구현 명세 ESC탐색 3.2): 운영 함수는 클릭 직전에 GetWindowRect 로 읽습니다 - 여기서는 고정점 회전마다 widthSeq 앞에서 하나씩, 다 쓰면 windowWidth. 고르기는 추출한 운영 함수
function Get-AbyssEscFallbackPoint { param($Game, [int]$LargeTurn)
  return (Select-AbyssEscFallbackPoint -WindowWidth ([int](Next-Seq 'width' $script:windowWidth)) -LargeTurn $LargeTurn)
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
function Invoke-EscButtonTransition {
  # ESC 버튼이 눌린 화면 전이: 필드 → 메뉴 / 던전 안(필드 오독 포함) → 던전 안 메뉴 / 메뉴 → 닫힘
  switch ($script:screen) {
    'field'        { $script:screen = 'menu' }
    'fieldMisread' { $script:screen = 'menuInside' }
    'inside'       { $script:screen = 'menuInside' }
    'menu'         { $script:screen = 'field' }
    'menuInside'   { $script:screen = 'inside' }
  }
}
function Send-Mock { param([int]$X, [int]$Y, [string]$Force = '')
  $r = $(if ($Force) { $Force } else { Next-Seq 'send' 'sent' })   # -Force = 이벤트 헬퍼 모의의 클릭 생략 갈래 (구현 단위 복귀 연장 3.1)
  $script:lastClickPerformed = ($r -eq 'sent'); $script:lastClickSkipReason = $(if ($r -eq 'sent') { '' } else { $r })
  # ESC 판별은 좌표 쌍입니다 (구현 명세 ESC탐색 3.2): 큰 창 고정점의 X 가 글자 점의 X 와 같아 X 하나로는 글자 클릭과 고정점 클릭이 갈리지 않습니다
  $isEscText = (($X -eq $escTextPoint.X -and $Y -eq $escTextPoint.Y) -or ($X -eq $escBinPoint.X -and $Y -eq $escBinPoint.Y))
  $isEscFixed = (($X -eq $ptEscButtonLarge[0] -and $Y -eq $ptEscButtonLarge[1]) -or ($X -eq $ptEscButton[0] -and $Y -eq $ptEscButton[1]))
  $isWindowPoint = $(if ($script:screen -eq 'notice' -or $script:screen -eq 'notice-covered') { Test-NoticeCloseHit -X $X -Y $Y } else { $windowPoints[$script:screen] -ceq "$X,$Y" })   # 그 창이 떠 있고 그 창의 점 (구현 단위 복귀 연장 3.1)
  if ($r -ne 'sent') {
    if ($isEscFixed) { [void]$script:events.Add("고정점 생략($r) $X,$Y") }
    if ($isWindowPoint) { [void]$script:windowSkips.Add("$($script:screen) $r") }
    return
  }
  $script:cursorOverGame = $true
  [void]$script:clickTimes.Add((Elapsed))
  if ($isWindowPoint) {
    # 아는 창의 전송: 창이 닫힙니다. 스텔라는 'stella1' → stellaCardLeadsTo(기본 'stella2'), 공지는 noticeLeadsTo(기본 'field'), 그 밖은 windowLeadsTo(기본 'unknown')
    $script:otherClicksSent++
    [void]$script:windowClicks.Add("$($script:screen) $X,$Y"); [void]$script:windowTimes.Add((Elapsed))
    $script:screen = $(if ($script:screen -eq 'stella1') { $script:stellaCardLeadsTo } elseif ($script:screen -eq 'notice' -or $script:screen -eq 'notice-covered') { $script:noticeLeadsTo } else { $script:windowLeadsTo })
    return
  }
  if ($isEscText) {
    # ESC 글자 클릭. escIgnoreUntil 전의 ESC 는 전송되지만 게임이 무시(화면 불변)
    $script:escClicksSent++; [void]$script:escTimes.Add((Elapsed)); [void]$script:events.Add("글자 $X,$Y")
    if ($script:onFirstEsc -and $script:escClicksSent -eq 1) { & $script:onFirstEsc }
    if ($null -ne $script:escIgnoreUntil -and (Elapsed) -lt $script:escIgnoreUntil) { return }
    if ($script:escLeadsTo) { $script:screen = $script:escLeadsTo; $script:escLeadsTo = ''; return }
    Invoke-EscButtonTransition
  } elseif ($X -eq 971) {
    # 메뉴 '어비스' → 필드 메뉴면 abyssLeadsTo(기본 선택 화면, 'detail'·'unknown' 가능). 던전 안 메뉴였다면 오버레이 = 원 사고 (09-20 23:25)
    $script:abyssClicksSent++; [void]$script:abyssTimes.Add((Elapsed)); $script:panelReadsAtAbyss = $script:panelReads
    if ($script:screen -eq 'menuInside') { $script:abyssClickedFromInside++; $script:screen = 'selection' }
    else { $script:screen = $script:abyssLeadsTo }
    if ($script:onAbyssClick) { & $script:onAbyssClick }
  } else {
    # 고정점도 '그 밖의 클릭' 으로 세어 AllInput 합과 X 후보 0 단언들이 옛날처럼 이 클릭을 봅니다 - 게임 반응은 fallbackOpensMenu(기본 무시: 단추 밖 또는 눌러도 안 열리는 자리), 사건 목록에는 따로 남깁니다
    $script:otherClicksSent++
    if ($isEscFixed) {
      [void]$script:fixedClicks.Add("$X,$Y"); [void]$script:fixedTimes.Add((Elapsed)); [void]$script:events.Add("고정점 $X,$Y")
      if ($script:fallbackOpensMenu) { Invoke-EscButtonTransition }
    }
  }
}
function Click-ScreenPoint { param([int]$X, [int]$Y) Send-Mock -X $X -Y $Y }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) Send-Mock -X ([int]$ReferenceX) -Y ([int]$ReferenceY) }
# 공지 X 입구는 모의입니다 - 자리 계산과 환산은 test_notice_close_point 가 운영 본문으로 끝까지 봅니다. 여기서는 자리 값(계산 자리 / 빗나감 행의 옛 고정점)만 클릭 모의로 보냅니다
function Click-NoticeBoardClose { param($Game) Click-GamePoint -Game $Game -ReferenceX $script:noticeClosePoint[0] -ReferenceY $script:noticeClosePoint[1] }
function Press-KeyVerified { param($Game, $VirtualKey, $Label)
  # 메뉴 닫기 ESC - 메뉴가 열려 있던 화면으로 돌아감
  $script:keyVerified++; [void]$script:clickTimes.Add((Elapsed))
  if ($script:screen -eq 'menu') { $script:screen = 'field' } elseif ($script:screen -eq 'menuInside') { $script:screen = 'inside' }
  return $true
}
function Press-KeyOnce { param($VirtualKey)
  # 오클릭 복구 ESC (09-15: '어비스' 가 상세를 열면 ESC 로 선택 화면 - escDetailLeadsTo) · 출석 완료 화면의 Space (운영 Invoke-EventSkipOrConfirm 본문 - RLX1g)
  $script:keyOnce++; [void]$script:clickTimes.Add((Elapsed))
  if ($script:screen -eq 'detail') { $script:screen = $script:escDetailLeadsTo }
  elseif ($VirtualKey -eq 32 -and $script:screen -eq 'attendDone') { $script:spaceSent++; $script:screen = $script:windowLeadsTo }
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
  $script:noticeCalls = 0; $script:noticeFailAtCall = -1; $script:screenAtNoticeFail = ''; $script:noticeFailFrom = $null; $script:noticeScreens = @('notice', 'notice-covered'); $script:noticeClosePoint = $rlxNoticePoint; $script:noticeSecondXCloses = $false
  $script:noticeReadTimes = New-Object 'System.Collections.Generic.List[double]'; $script:noticeTrueTimes = New-Object 'System.Collections.Generic.List[double]'; $script:noticeFailTimes = New-Object 'System.Collections.Generic.List[double]'
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
  # ESC 클릭 자리 탐색 (구현 명세 ESC탐색 3.2): 기본은 일반 판독이 찾는 평상시 - 기존 사례가 그대로 지납니다. events = 대피 · 진단 · 글자 · 고정점 사건 순서열
  $script:escNormalSeq = @(); $script:escNormalIdx = 0; $script:escNormalDefault = 'found'
  $script:escBinSeq = @(); $script:escBinIdx = 0; $script:escBinDefault = 'miss'
  $script:escReads = New-Object 'System.Collections.Generic.List[string]'; $script:events = New-Object 'System.Collections.Generic.List[string]'
  $script:fixedClicks = New-Object 'System.Collections.Generic.List[string]'; $script:fixedTimes = New-Object 'System.Collections.Generic.List[double]'; $script:fallbackOpensMenu = $false
  $script:windowWidth = 1272; $script:widthSeq = @(); $script:widthIdx = 0
  $script:cursorOverGame = $true; $script:parkCalls = 0; $script:parkTimes = New-Object 'System.Collections.Generic.List[double]'; $script:parkYieldMs = 0; $script:screenAfterPark = ''
  $script:diagLog = New-Object 'System.Collections.Generic.List[string]'
  # 복귀 마감 연장 (구현 명세 복귀연장 3.1): 이벤트 헬퍼 시각표 · 운영 본문 스위치 · 아는 창 전이 · 안전 중지 신호 시각표 · 진단 스위치 · 출구 순서 기록
  $script:eventPlan = @(); $script:eventEvery = ''; $script:eventReal = $false; $script:eventRealHelpers = $false
  $script:eventResults = New-Object 'System.Collections.Generic.List[string]'; $script:eventOutcomeRefs = 0; $script:confirmClicks = 0; $script:spaceSent = 0
  $script:ghostResults = New-Object 'System.Collections.Generic.List[string]'; $script:ghostReal = $false; $script:stellaTitleReads = 0
  $script:stellaCardLeadsTo = 'stella2'; $script:noticeLeadsTo = 'field'; $script:windowLeadsTo = 'unknown'
  $script:windowClicks = New-Object 'System.Collections.Generic.List[string]'; $script:windowTimes = New-Object 'System.Collections.Generic.List[double]'; $script:windowSkips = New-Object 'System.Collections.Generic.List[string]'
  $script:flagSchedule = @(); $script:flagSchedIdx = 0
  $script:diagFull = New-Object 'System.Collections.Generic.List[string]'; $script:exitOrder = New-Object 'System.Collections.Generic.List[string]'; $script:keyCloseCalls = 0
}
function Run-Loop { param([int]$SafeStopExitCode = 0, [string]$LeaveEntryReason = '')
  try { Return-ToAbyssSelection -Game $null -SafeStopExitCode $SafeStopExitCode -LeaveEntryReason $LeaveEntryReason } catch { $script:threw = $_.Exception.Message }
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
#    클릭 → 오버레이 → '복귀 확인'(원 사고). 수정: 실패 회전은 ESC 를 보내지 않고 재판독 → 다음 회전 던전 안 → 코드 4 (HUD 분기의 공지 판독은 W 뒤 첫 판독)
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
#    7g. 마감 경계에서 필드로 바뀐 경우(패널 사라짐)는 성공이 아니므로 그 회전에서 일반 만료 → throw (안전 중지 없음 - 있으면 RLX6, 필드 ESC 전송 없이)
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
#      조정 마감만 → 60초에 break → throw (안전 중지가 없을 때 - 있으면 RLX6g) ((b) 도 복구 회전에는 유효한 패널 표본이 없어 코드 4 가 아님). ⑥a 작업 트리는 이 회전을 두 만료 판정의
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
# 4) 분기: 헬퍼가 'expired'(헬퍼 안 복구 회전만 이어져 부모 마감에 닿음)를 돌려주면 break → 안전 중지가 없으면 throw, 있으면 while 뒤 M1 (RLX6f), 헬퍼 호출 1 (부모 마감 전달)
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

# ── 12. RLE 복귀 루프의 ESC 클릭 자리 탐색 (2026-11-04 구현 명세 ESC탐색 1절 · 3.2 - 사용자 결정 U-E-1~U-E-7) ─────────────────────────
# 10-28 실기 1-D′a: 판독 영역의 다른 플레이어 이름표 하나로 일반 판독이 '' 인데 HUD 판정은 이진화로 통과해, 필드는 확인되고 클릭 자리만 못 찾아 1908 에서 단추 밖 고정점을 눌렀습니다
# (ESC 다섯 번에 메뉴 0 → 복귀 대기 초과 코드 1). 기대 좌표는 소스 캡처($ptEscButton · $ptEscButtonLarge)와 모의 글자 점이고, 실패 계수는 지역 변수라 다음 E5 줄의 '(N회, …)' 로 봅니다.
# 모의(Reset-Case 기본값): 일반 found · 이진화 miss · 고정점 클릭은 게임이 무시 · 창 너비 1272 · 커서 게임 위. 시각은 하니스 가상 시계(판독 0초)라 실제보다 짧아 - 60초에 고정점이 네 번 들어갑니다
# (실제는 두 번 안팎 - 명세 1절) - 코드 · 횟수 · 순서만 단언합니다
$escSmallXY = "$($ptEscButton[0]),$($ptEscButton[1])"
$escLargeXY = "$($ptEscButtonLarge[0]),$($ptEscButtonLarge[1])"
$escTextXY = "$($escTextPoint.X),$($escTextPoint.Y)"
$escBinXY = "$($escBinPoint.X),$($escBinPoint.Y)"
function EscClickTails { return @($script:logs | ForEach-Object { if ($_ -match '\[어비스\] ESC 클릭 \((.+)\)$') { $Matches[1] } }) }
function E5Tails { return @($script:logs | ForEach-Object { if ($_ -match '\[어비스\] ESC 글자를 못 읽어 누르지 않고 다시 읽습니다 \((.+)\)$') { $Matches[1] } }) }
function FirstE5Tails { param([int]$Count) return (@(E5Tails | Select-Object -First $Count) -join ' | ') }
function FirstEvents { param([int]$Count) return (@($script:events | Select-Object -First $Count) -join ', ') }
function FirstFixedClicks { param([int]$Count) return (@($script:fixedClicks | Select-Object -First $Count) -join ' → ') }
function FirstFixedLogs { param([int]$Count) return (@(EscClickTails | Where-Object { $_ -like '글자 탐색 실패 고정점 *' } | Select-Object -First $Count | ForEach-Object { $_ -replace '^글자 탐색 실패 고정점 ', '' }) -join ' → ') }
function FirstEscReads { param([int]$Count) return (@($script:escReads | Select-Object -First $Count) -join ',') }

# RLE0 (E1) 일반 성공: 둘째 판독 · 대피 없이 그 점을 누르고, 줄에 분기와 좌표가 남습니다
Reset-Case -Screen 'field'
Run-Loop
Check-Equal 'RLE0 일반 성공: 판독은 일반/영어 1번(둘째 판독 0), 대피 0, ESC 1, 고정점 0, 어비스 1, 복귀 확인 1, 코드·throw 없음' ("$(FirstEscReads 9)/$($script:parkCalls)/$($script:escClicksSent)/$($script:fixedClicks.Count)/$($script:abyssClicksSent)/$(Done)/$($script:exitCode)/$($script:threw)") '일반:en/0/1/0/1/1//'
Check-Equal "RLE0 클릭 줄 = '[어비스] ESC 클릭 (글자 탐색 화면좌표 $escTextXY)' 1줄" (@(EscClickTails) -join ' | ') "글자 탐색 화면좌표 $escTextXY"
# RLE1 (E2) 일반 유효 실패 + 이진화 성공: 같은 회전에 이진화/한국어(판독 표 37장 - 한국어만 읽은 그림 9 · 영어만 읽은 그림 0)가 찾은 점을 눌러 출처 있는 완료
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'; $script:escBinDefault = 'found'
Run-Loop
Check-Equal 'RLE1 일반 실패 + 이진화 성공: 판독 순서 일반/영어 → 이진화/한국어, 대피 0, ESC 1, 고정점 0, 복귀 확인 1, 코드·throw 없음' ("$(FirstEscReads 9)/$($script:parkCalls)/$($script:escClicksSent)/$($script:fixedClicks.Count)/$(Done)/$($script:exitCode)/$($script:threw)") '일반:en,이진화:ko/0/1/0/1//'
Check-Equal "RLE1 클릭 줄 = '[어비스] ESC 클릭 (글자 탐색 이진화 화면좌표 $escBinXY)' 1줄 - 사건도 이진화 점" ("$(@(EscClickTails) -join ' | ')/$(FirstEvents 9)") "글자 탐색 이진화 화면좌표 $escBinXY/글자 $escBinXY"
# RLE2 (E3) 일반 판독의 캡처 실패 1회 뒤 둘 다 실패: 그 회전은 둘째 판독 0 · 클릭 0 · 계수 불변 → 동결 → 복구 뒤 첫 E5 가 (1회) (규칙 15 - 캡처 실패 표본을 '못 찾음' 으로 세지 않음)
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'; $script:failOnceAt = @{ 'Find-GameTextPoint:ESC' = 1 }
Run-Loop
Check-Equal 'RLE2 일반 캡처 실패: 그 회전 둘째 판독 0 (다음 판독이 다시 일반)' (FirstEscReads 3) '일반:en,일반:en,이진화:ko'
Check-True "RLE2 그 회전 클릭 0 · 동결 1회 뒤 첫 E5 줄 '(1회, 커서 게임 위)', 첫 사건 대피" ($script:safeStopCalls -eq 1 -and $script:parkTimes.Count -ge 1 -and $script:parkTimes[0] -gt $script:safeStopTimes[0] -and (ClicksIn 0 $script:parkTimes[0]) -eq 0 -and (FirstE5Tails 1) -eq '1회, 커서 게임 위' -and (FirstEvents 1) -eq '대피') "(동결 $($script:safeStopTimes -join ','), 대피 $($script:parkTimes -join ','), E5 '$(FirstE5Tails 1)', 사건 '$(FirstEvents 1)')"
# RLE3 (E4) 일반 유효 실패 + 둘째 판독 캡처 실패 1회 뒤 둘 다 실패: 그 회전 클릭 0 · 계수 불변 → 복구 뒤 첫 E5 가 (1회)
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'; $script:failOnceAt = @{ 'Find-GameTextPoint:ESC#bin' = 1 }
Run-Loop
Check-Equal 'RLE3 둘째 판독 캡처 실패: 그 회전을 끝내고 다음 회전에 두 판독을 다시 함' (FirstEscReads 4) '일반:en,이진화:ko,일반:en,이진화:ko'
Check-True "RLE3 그 회전 클릭 0 · 동결 1회 뒤 첫 E5 줄 '(1회, 커서 게임 위)', 첫 사건 대피" ($script:safeStopCalls -eq 1 -and $script:parkTimes.Count -ge 1 -and $script:parkTimes[0] -gt $script:safeStopTimes[0] -and (ClicksIn 0 $script:parkTimes[0]) -eq 0 -and (FirstE5Tails 1) -eq '1회, 커서 게임 위' -and (FirstEvents 1) -eq '대피') "(동결 $($script:safeStopTimes -join ','), 대피 $($script:parkTimes -join ','), E5 '$(FirstE5Tails 1)', 사건 '$(FirstEvents 1)')"
# RLE4 (E5 · E6) 둘 다 실패 지속 · 작은 창 · 커서 게임 위: 대피와 고정점을 번갈아 하고, 3회째 실패의 대피 뒤에 진단 캡처 1장, 메뉴가 끝내 안 열려 복귀 마감 코드 1 (U-E-2 ~ U-E-4)
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'
Run-Loop
Check-Equal "RLE4 둘 다 실패 지속: 사건 순서열 '대피, 고정점 $escSmallXY, 대피, 진단, 고정점 $escSmallXY'" (FirstEvents 5) "대피, 고정점 $escSmallXY, 대피, 진단, 고정점 $escSmallXY"
$rle4Moves = @($script:events | Where-Object { $_ -ne '진단' })
$rle4Off = @(for ($i = 0; $i -lt $rle4Moves.Count; $i++) { if ($rle4Moves[$i] -ne $(if ($i % 2 -eq 0) { '대피' } else { "고정점 $escSmallXY" })) { $rle4Moves[$i] } })
Check-True 'RLE4 끝까지 대피 · 고정점이 번갈아 나오고 고정점 2번 이상, 대피 → 다음 고정점 간격 ≥ W (다음 회전이 필드 확정을 다시 셈)' ($rle4Off.Count -eq 0 -and $script:fixedClicks.Count -ge 2 -and ($script:fixedTimes[0] - $script:parkTimes[0]) -ge $memberFieldSettleSeconds) "(어긋남 $($rle4Off.Count), 사건 $($script:events -join ' / '), 고정점 $($script:fixedTimes -join ','), 대피 $($script:parkTimes -join ','))"
Check-Equal "RLE4 E5 줄 '(1회, 커서 게임 위)' → '(3회, 커서 게임 위)'" (FirstE5Tails 2) '1회, 커서 게임 위 | 3회, 커서 게임 위'
Check-Equal "RLE4 클릭 줄은 고정점 수만큼 전부 '(글자 탐색 실패 고정점 $escSmallXY)'" ("$(@(EscClickTails | Select-Object -Unique) -join ' | ')/$(@(EscClickTails).Count)") "글자 탐색 실패 고정점 $escSmallXY/$($script:fixedClicks.Count)"
Check-Equal 'RLE4 진단 1회 = 문맥 어비스 ESC 글자 미발견 · -CaptureOnly' ($script:diagLog -join ' | ') '어비스 ESC 글자 미발견|True'
Check-True 'RLE4 마감 코드 1 경로: throw, 코드 없음, (가상 − 누적 실패 − 양보) = 60 ± 1초, 복귀 확인 0' ((ThrewTimeout) -eq 1 -and $null -eq $script:exitCode -and [math]::Abs((Adj) - 60) -le 1.01 -and (Done) -eq 0) "(adj $(Adj), throw '$($script:threw)')"
Check-True 'RLE4 고정점 클릭은 AllInput 합에 듦 (입력 = 고정점뿐), 글자 ESC 0, 어비스 0' ((AllInput) -eq $script:fixedClicks.Count -and $script:escClicksSent -eq 0 -and $script:abyssClicksSent -eq 0) "(AllInput $(AllInput), 고정점 $($script:fixedClicks.Count), ESC $($script:escClicksSent))"
# RLE4b 같은 조건 · 커서 게임 밖: 줄만 달라지고 대피는 그대로 합니다 (커서 자리는 로그로 가르기 위한 사실 기록 - 대피 여부를 정하지 않음)
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'; $script:cursorOverGame = $false
Run-Loop
Check-Equal "RLE4b 커서 게임 밖: 첫 E5 줄 '(1회, 커서 게임 밖)', 고정점 전 대피 호출 1, 대피 수 = E5 줄 수" ("$(FirstE5Tails 1)/$(FirstEvents 2)/$([int]($script:parkCalls -eq @(E5Tails).Count))") "1회, 커서 게임 밖/대피, 고정점 $escSmallXY/1"
# RLE5 같은 조건 · 큰 창: 새 점과 옛 점을 번갈아 누릅니다 (U-E-7 - 1908 너비에는 1272 화면을 늘린 배치가 있어 그때는 옛 점이 글자 위) - 클릭 사건과 로그 원문 좌표가 같은 순서
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'; $script:windowWidth = 1908
Run-Loop
Check-Equal "RLE5 큰 창: 클릭 사건 = 로그 원문 좌표 = $escLargeXY → $escSmallXY → $escLargeXY" "$(FirstFixedClicks 3) / $(FirstFixedLogs 3)" "$escLargeXY → $escSmallXY → $escLargeXY / $escLargeXY → $escSmallXY → $escLargeXY"
# RLE5b 회전 사이 창이 1908 → 1276 → 1908 으로 변함 (RDP 축소 · 복원): 그 순간의 실제 너비로 고르고, 작은 창 고정점은 큰 창 순번을 쓰지 않습니다
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'; $script:widthSeq = @(1908, 1276, 1908)
Run-Loop
Check-Equal "RLE5b 창 1908 → 1276 → 1908: $escLargeXY → $escSmallXY(작은 창 · 순번 불변) → $escSmallXY(큰 창 순번 1)" (FirstFixedClicks 3) "$escLargeXY → $escSmallXY → $escSmallXY"
# RLE5c 큰 창 고정점 뒤 글자 클릭이 끼고(게임 무시) 다시 실패: 글자 발견은 대피 계수만 되돌리고 큰 창 순번은 건드리지 않습니다
Reset-Case -Screen 'field'
$script:escNormalSeq = @('miss', 'miss', 'found'); $script:escNormalDefault = 'miss'; $script:windowWidth = 1908; $script:escIgnoreUntil = 20000
Run-Loop
Check-Equal "RLE5c 글자 클릭이 끼어도: 사건 '대피, 고정점 $escLargeXY, 글자 $escTextXY, 대피, 고정점 $escSmallXY'" (FirstEvents 5) "대피, 고정점 $escLargeXY, 글자 $escTextXY, 대피, 고정점 $escSmallXY"
# RLE6 1회 실패 뒤 다음 회전 일반 성공 (이름표가 지나감): 고정점 없이 글자를 눌러 완료, 3회에 닿지 않아 진단 0
Reset-Case -Screen 'field'
$script:escNormalSeq = @('miss')
Run-Loop
Check-Equal 'RLE6 1회 실패 뒤 일반 성공: E5 1줄, 대피 1, 고정점 0, ESC 1, 진단 0, 복귀 확인 1, 코드·throw 없음' ("$(@(E5Tails).Count)/$($script:parkCalls)/$($script:fixedClicks.Count)/$($script:escClicksSent)/$($script:diagCalls)/$(Done)/$($script:exitCode)/$($script:threw)") '1/1/0/1/0/1//'
# RLE6b 실패(E5) → 글자 찾음 · 전송 · 게임 무시 → 실패: 글자 발견이 계수를 0 으로 되돌려 둘째 E5 도 (1회) · 고정점 0
Reset-Case -Screen 'field'
$script:escNormalSeq = @('miss', 'found', 'miss')
$script:onFirstEsc = { $script:escIgnoreUntil = (Elapsed) + 1 }   # 첫 글자 클릭만 게임이 무시 (09-15 타 PC 1272 ESC 세 번째 성공의 추정 모양)
Run-Loop
Check-Equal "RLE6b 글자 발견이 계수를 되돌림: E5 줄 '(1회, …)' 둘, 고정점 0, ESC 2, 복귀 확인 1" ("$(FirstE5Tails 9)/$($script:fixedClicks.Count)/$($script:escClicksSent)/$(Done)") '1회, 커서 게임 위 | 1회, 커서 게임 위/0/2/1'
# RLE7 고정점 클릭이 메뉴를 엶 (글자는 끝내 안 읽히지만 단추는 눌림): 전송 확인된 고정점이 토큰을 발급해 메뉴 → 어비스 → 선택 화면 완료
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'; $script:fallbackOpensMenu = $true
Run-Loop
Check-Equal 'RLE7 고정점이 메뉴를 엶: 고정점 1번 뒤 어비스 1, 복귀 확인 1, 메뉴 닫기 0, 진단 0, 코드·throw 없음' ("$(FirstFixedClicks 9)/$($script:abyssClicksSent)/$(Done)/$($script:keyVerified)/$($script:diagCalls)/$($script:exitCode)/$($script:threw)") "$escSmallXY/1/1/0/0//"
# RLE8 큰 창 고정점 클릭 user-active 생략 (규칙 4): 보내지 않은 클릭은 고정점 차례 · 큰 창 순번을 쓰지 않습니다 - 양보 뒤 다음 실패가 E5 없이 같은 점이고, 그 뒤로는 평소 순서
Reset-Case -Screen 'field' -SendSeq @('user-active')
$script:escNormalDefault = 'miss'; $script:windowWidth = 1908
Run-Loop
$rle8SkipLogs = Count-Log 'ESC 클릭 건너뜀 \(사용자 조작\)'
Check-Equal "RLE8 user-active 생략: 사건 '대피, 고정점 생략(user-active) $escLargeXY, 고정점 $escLargeXY, 대피, 진단, 고정점 $escSmallXY'" (FirstEvents 6) "대피, 고정점 생략(user-active) $escLargeXY, 고정점 $escLargeXY, 대피, 진단, 고정점 $escSmallXY"
Check-Equal 'RLE8 양보 1, 건너뜀 줄 1, 생략과 재시도 사이 E5 줄 없음 (1회 다음이 3회)' ("$($script:yieldWaits)/$rle8SkipLogs/$(FirstE5Tails 2)") '1/1/1회, 커서 게임 위 | 3회, 커서 게임 위'
#      토큰 폐기: 옛 토큰 보유 → E5 → 고정점 생략 + 0ms 양보(누적 차분 0 - 2c 와 같은 경계) 중 던전 안 메뉴 → 생략 자리의 명시 폐기가 막아 어비스를 누르지 않고 닫습니다
Reset-Case -Screen 'field' -SendSeq @('sent', 'user-active')
$script:escNormalSeq = @('found', 'miss', 'miss'); $script:escNormalDefault = 'miss'; $script:windowWidth = 1908; $script:escIgnoreUntil = 20000
$script:yieldSeconds = 0; $script:screenAfterYield = 'menuInside'
Run-Loop
$rle8TokenRecheck = Count-Log '메뉴 출처를 다시 확인'
Check-Equal 'RLE8 토큰 폐기 - 고정점 생략 뒤 0초 양보 중 던전 안 메뉴: 어비스 0, 던전 안 클릭 0, 메뉴 닫기 1, 코드 4, 출처 재확인 로그 0(명시 폐기), 누적 양보 0' ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$($script:exitCode)/$rle8TokenRecheck/$([int]$script:userYieldTotalMs)") '0/0/1/4/0/0'
# RLE8b 큰 창 고정점 클릭 cursor-not-ready 생략: 자동화 자신의 실패라 그대로 소모합니다 (둘을 뭉쳐 되돌리면 커서가 계속 안 잡힐 때 예산이 안 줄어듦 - 규칙 4) - 양보 없음, 다음 실패는 E5, 그다음 고정점은 옛 점
Reset-Case -Screen 'field' -SendSeq @('cursor-not-ready')
$script:escNormalDefault = 'miss'; $script:windowWidth = 1908
Run-Loop
$rle8bSkipLogs = Count-Log 'ESC 클릭 건너뜀 \(커서 미확인\)'
Check-Equal "RLE8b cursor-not-ready 생략: 사건 '대피, 고정점 생략(cursor-not-ready) $escLargeXY, 대피, 진단, 고정점 $escSmallXY'" (FirstEvents 5) "대피, 고정점 생략(cursor-not-ready) $escLargeXY, 대피, 진단, 고정점 $escSmallXY"
# 둘째 E5 의 커서 자리는 계약이 아닙니다 - cursor-not-ready 는 클릭을 보내지 않았다는 뜻뿐이고, 커서가 어디 남았는지는 모의가 만든 값입니다 (구현 명세 ESC탐색 3.2 '(3회, …)')
Check-Equal "RLE8b 양보 0, 건너뜀 줄 1, 다음 실패가 E5 '(3회, …)'" ("$($script:yieldWaits)/$rle8bSkipLogs/$((FirstE5Tails 2) -replace '3회, 커서 게임 (위|밖)$', '3회, 커서 …')") '0/1/1회, 커서 게임 위 | 3회, 커서 …'
# RLE9 클릭 메타를 참으로 둔 뒤 첫 E5, 다음 회전 화면이 메뉴: E5 는 클릭이 없으므로 메타를 읽기 전에 끝나야 합니다 - 앞 클릭의 참을 읽으면 보내지 않은 ESC 로 토큰이 나가 '어비스' 를 누릅니다 (규칙 4)
Reset-Case -Screen 'field'
$script:escNormalDefault = 'miss'; $script:lastClickPerformed = $true; $script:screenAfterPark = 'menu'
Run-Loop
Check-Equal 'RLE9 첫 E5 뒤 메뉴 (앞 클릭 메타 참): 어비스 0, 메뉴 닫기 1 (토큰 미발급)' ("$($script:abyssClicksSent)/$($script:keyVerified)") '0/1'
# RLE10 옛 토큰 보유 → E5 → 대피 안 양보 중 던전 안 메뉴: 메뉴 분기의 기준값 대조가 폐기합니다 (대피 안 양보는 게이트를 지나지 않음 - 명세 2.3)
Reset-Case -Screen 'field'
$script:escNormalSeq = @('found'); $script:escNormalDefault = 'miss'; $script:escIgnoreUntil = 20000
$script:parkYieldMs = 3000; $script:screenAfterPark = 'menuInside'
Run-Loop
$rle10Recheck = Count-Log '메뉴 출처를 다시 확인'
Check-Equal "RLE10 대피 안 양보 중 던전 안 메뉴: 어비스 0, 던전 안 클릭 0, 메뉴 닫기 1, '메뉴 출처를 다시 확인' 줄 1, 코드 4" ("$($script:abyssClicksSent)/$($script:abyssClickedFromInside)/$($script:keyVerified)/$rle10Recheck/$($script:exitCode)") '0/0/1/1/4'

# ── 13. RLX 복귀 마감 연장 · 마감 뒤 안전 중지 (2026-11-04 구현 명세 복귀연장 1절 · 3.2 - 사용자 결정 U-R-1~7) ─────────────────────────
# 11-03 08:45 (1908 · 비커스텀 우연한 만남 · 안전 중지 예약): 복귀 중 리셋 팝업 체인의 창을 닫는 사이 60초 마감이 끝나 '나가기' 뒤 코드 1 오류 정지 · 클리어한 판 미계상이었습니다.
# 연장: 아는 창에 입력을 실제로 보낸 회전에서만, 그 시점에 기본 예산 B 가 남게 늘립니다 (전체 상한 C 는 양보 · 캡처 실패를 뺀 시간). 눌러 보는 X 후보 · '확인' 낱말 · 복귀 본 동작은 사유가 아닙니다.
# 출구 M1: 마감이 끝난 때 안전 중지가 걸려 있으면 신호 소비 → [완료] 세 갈래 → 진단 캡처 · 로그 사본 → 호출부 코드로 끝냅니다. 없으면 지금처럼 throw (U-R-5).
# C 는 소스 값, B 는 이 하니스 값이고, T = 마지막 실제 전송 회전의 연장 줄 시각, E(T) = min(T + B, C) 입니다. 시각은 ±3초로 봅니다 (회전 길이가 0.7~2초).
# 명세의 시각은 손 계산이고 이 값들은 실행으로 확정했습니다. 손 계산과 달랐던 자리: RLX1f 의 공지 X 는 40초가 아니라 48초쯤입니다 - HUD 분기의 공지 판독은 필드 확정(W) 뒤 회전에만 있고, ESC 가 무시되는 동안 '확정 → ESC → 2초 → W 다시 세기' 가 W + 2초 남짓마다 돕니다
# 공지 · 스텔라는 <연장> 뒤에 기존 대기를 하고 이벤트 헬퍼 · 고스트는 안에서 2~3초를 잔 뒤 돌아와 <연장> 을 부르므로 T 는 자리마다 2초 안팎 다릅니다 (명세 0.3 - 'T' 를 연장 줄 시각으로 잡는 이유)
$rlxDiag = '어비스 복귀 마감 안전 중지|True|True'
$rlxDoneElse = '[완료] 안전 중지 예약 확인 - 복귀 대기 시간 안에 화면 복귀를 확인하지 못해 이 시점에서 회차를 마칩니다. 게임 화면을 확인해 주세요'
$rlxDoneReady = '[완료] 안전 중지 예약 확인 - 복귀 대기 시간 안에 화면 복귀를 확인하지 못했고 준비/정리 실행이라 회차로 세지 않고 마칩니다. 게임 화면을 확인해 주세요'
$rlxDoneLeft = '[완료] 안전 중지 예약 확인 - 복귀 대기 시간 안에 화면 복귀를 확인하지 못했고 거점 퇴장한 판은 회차로 세지 않고 마칩니다. 게임 화면을 확인해 주세요'
$rlxDoneAny = '복귀 대기 시간 안에 화면 복귀를 확인하지 못'
$rlxExtPattern = '\[안내\] 복귀 중 아는 창을 눌러 복귀 대기 시간을 늘립니다 \(판독: 연장 \d+초, 남은 연장 \d+초\)$'
$rlxXPattern = '복귀 중 알 수 없는 화면 20초 지속 - 닫기\(X\) 후보\((\d+,\d+)\) 클릭$'
$rlxNoticeHudLine = '[어비스] 공지 게시판 팝업 감지 - X로 닫기'                 # HUD 분기 블록의 줄
$rlxCoveredLine = '[어비스] 공지 게시판 팝업 감지 - X로 닫기 (HUD 가려짐)'      # '알 수 없는 화면' 쪽 블록의 줄 - 꼬리로 어느 블록을 탔는지 가립니다
$rlxHandPattern = 'X 를 \d+ 번 시도해도 남아 있어 X 후보로 넘깁니다$'   # 공지를 X 후보로 넘기는 줄 (U-R-10)
$rlxNoticeLinePattern = '공지 게시판 팝업 감지 - X로 닫기$'   # HUD 분기 줄만 (꼬리 없음)
$rlxCoveredAny = '공지 게시판 팝업 감지 - X로 닫기'                             # 두 블록 다 찾는 조각
$rlxNoticeSkipAny = '공지 게시판 X 닫기 건너뜀'
# 알 수 없는 화면이 이 초만큼 이어져야 X 후보를 누릅니다 - 함수 안 조건식의 리터럴이라 대입 캡처가 안 되어 조건식에서 읽습니다 (숫자를 테스트에 다시 박지 않음)
$rlxUnknownSeconds = $(if ($loopDef -match '\(\(Get-Date\) - \$unknownSince\)\.TotalSeconds -ge (\d+)\)') { [int]$Matches[1] } else { 0 })
Check-True '캡처: 알 수 없는 화면 문턱은 소스 값 (명세 0.3 - 창을 닫은 뒤 X 까지 이만큼 더 걸려 남길 시간의 계산에 듭니다)' ($rlxUnknownSeconds -gt 0) "(문턱 $rlxUnknownSeconds)"
function ExtLines { return (Count-Log $rlxExtPattern) }
function NewDoneLines { return (Count-Log $rlxDoneAny) }
function CountLine { param([string]$Line) return @($script:logs | Where-Object { ($_ -replace '^\S+ ', '') -ceq $Line }).Count }
function LogTimes { param([string]$Pattern) return @(@($script:logs | Where-Object { $_ -match $Pattern }) | ForEach-Object { [double](($_ -split ' ')[0]) }) }
function LastExt { $extTimes = @(LogTimes $rlxExtPattern); if ($extTimes.Count -eq 0) { return [double]-1 }; return [double]$extTimes[$extTimes.Count - 1] }
function XPoints { return @($script:logs | ForEach-Object { if ($_ -match $rlxXPattern) { $Matches[1] } }) }
function FirstXAfter { param([double]$T) $xTimes = @(@(LogTimes $rlxXPattern) | Where-Object { $_ -gt $T }); if ($xTimes.Count -eq 0) { return [double]-1 }; return [double]$xTimes[0] }
function EndOf { param([double]$T) return [math]::Min($T + $rlxBase, $rlxLimit) }
function Near { param($Actual, $Expected, [double]$Tolerance = 3) return ([math]::Abs([double]$Actual - [double]$Expected) -le $Tolerance) }
# 시간 초과 throw 로 끝난 행: 예기치 않은 예외(모의 호출 오류 등)는 문구로 갈립니다. 연장 줄 수를 정하지 않는 행은 -1
function Check-Throw { param([string]$Name, $ExpectedEnd, [int]$ExtCount)
  $extOk = (($ExtCount -lt 0) -or ((ExtLines) -eq $ExtCount))
  Check-True $Name ((ThrewTimeout) -eq 1 -and $null -eq $script:exitCode -and (Near $script:endAt $ExpectedEnd) -and $extOk -and $script:flagRemoved -eq 0 -and (NewDoneLines) -eq 0 -and @($script:diagFull | Where-Object { $_ -eq $rlxDiag }).Count -eq 0) "(end $($script:endAt), 기대 $ExpectedEnd, 연장 줄 $(ExtLines), 코드 '$($script:exitCode)', throw '$($script:threw)')"
}
# 마감 뒤 안전 중지(M1) 결말: 코드 · 소비 1 · 진단 1(문맥 · 두 스위치) · 그 갈래 [완료] 줄 1 · 새 줄 합 1 · throw 없음 · 소비 → 줄 → 진단 → 종료 순서 · 열쇠 닫기 0 · 캡처 실패 중이 아님
function Check-M1 { param([string]$Name, [int]$Code = 0, [string]$Line = $rlxDoneElse)
  $orderNow = $script:exitOrder -join ' > '
  Check-True $Name ($script:exitCode -eq $Code -and $script:threw -eq '' -and $script:flagRemoved -eq 1 -and $script:diagFull.Count -eq 1 -and $script:diagFull[0] -eq $rlxDiag -and (CountLine $Line) -eq 1 -and (NewDoneLines) -eq 1 -and $orderNow -eq '소비 > 완료줄 > 진단 > 종료' -and $script:keyCloseCalls -eq 0 -and (-not $script:screenCaptureFailing)) "(코드 '$($script:exitCode)', 소비 $($script:flagRemoved), 진단 '$($script:diagFull -join ' ; ')', 새 줄 $(NewDoneLines), 순서 '$orderNow', 열쇠 닫기 $($script:keyCloseCalls), throw '$($script:threw)', end $($script:endAt))"
}
# 운영 헬퍼 본문 추출 (RL3 선례 - 이름을 바꿔 정의하고 위 모의가 사례 값으로 부릅니다). 세 헬퍼가 부르는 순수 · 판독 함수는 운영 함수 그대로입니다
foreach ($realName in @('Invoke-EventSkipOrConfirm', 'Close-CoopMissionBoardScreen', 'Close-NetworkUnstablePopup', 'Close-WeeklyCoopResetPopup', 'Close-GhostRegisterPrompt')) {
  Invoke-Expression (([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($realName))) -replace ('function ' + $realName), ('function ' + $realName + 'Real'))
}
foreach ($name in @('Test-CoopMissionBoardVisible', 'Test-CoopMissionBoardTitle', 'Select-NetworkRetryWord')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}

# RLX0 Get-AbyssReturnGrantMs 판정 표 (추출한 운영 함수): 충분 → 0 / 딱 남음 → 0 / 부족 → 차이 / 예산 초과 → 예산 / 예산 0 → 0 / 예산 음수(기본 예산 ≥ 상한) → 0 / 남은 시간 음수 → 지금 + 남길 시간
$rlx0 = @(
  (Get-AbyssReturnGrantMs -RemainingMs 70000 -KeepMs 60000 -BudgetLeftMs 120000),
  (Get-AbyssReturnGrantMs -RemainingMs 60000 -KeepMs 60000 -BudgetLeftMs 120000),
  (Get-AbyssReturnGrantMs -RemainingMs 20000 -KeepMs 60000 -BudgetLeftMs 120000),
  (Get-AbyssReturnGrantMs -RemainingMs 0 -KeepMs 60000 -BudgetLeftMs 30000),
  (Get-AbyssReturnGrantMs -RemainingMs 20000 -KeepMs 60000 -BudgetLeftMs 0),
  (Get-AbyssReturnGrantMs -RemainingMs 20000 -KeepMs 60000 -BudgetLeftMs -5000),
  (Get-AbyssReturnGrantMs -RemainingMs -5000 -KeepMs 60000 -BudgetLeftMs 120000))
Check-Equal 'RLX0 연장 판정: 충분 → 0 / 딱 남음 → 0 / 부족 → 차이 / 예산 초과 → 예산 / 예산 0 → 0 / 예산 음수 → 0 / 남은 시간 음수 → 지금 + 남길 시간' ($rlx0 -join ',') '0,0,40000,30000,0,0,65000'

# RLX1a~c (X1 · X2 · X7): 알 수 없는 화면 + 30초쯤 전송 1회 → 전송 회전이 끝난 때부터 B 뒤 throw, 연장 줄 1. 호출부가 -Outcome 을 넘겨야 Space 가 보입니다
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 30; Kind = 'click' })
Run-Loop
$rlxT = LastExt
Check-Throw 'RLX1a 30초쯤 이벤트 클릭: throw · end ≈ E(T) · 연장 줄 1' (EndOf $rlxT) 1
Check-Equal 'RLX1a 갈래: 호출마다 -Outcome 전달, 그 회전의 메타 참 · Outcome 빈 값, T ≈ 32초 (헬퍼 안 2초 뒤)' "$([int]($script:eventOutcomeRefs -eq $script:eventCalls))/$($script:eventResults -join ';')/$(Near $rlxT 32)" '1/click|True||/True'
#      같은 X1 의 네트워크 꼴: 헬퍼 안 대기가 3초라 T 가 1초 늦습니다 (운영 본문은 RLX1g-x)
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 30; Kind = 'click-network' })
Run-Loop
$rlxT = LastExt
Check-Throw "RLX1a′ 30초쯤 네트워크 '다시 시도하기': throw · end ≈ E(T) · 연장 줄 1" (EndOf $rlxT) 1
Check-Equal 'RLX1a′ 갈래: 메타 참 · Outcome 빈 값, T ≈ 33초 (헬퍼 안 3초 뒤)' "$($script:eventResults -join ';')/$(Near $rlxT 33 0.5)" 'click-network|True||/True'
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 30; Kind = 'space' })
Run-Loop
$rlxT = LastExt
Check-Throw 'RLX1b 30초쯤 출석 완료 Space: throw · end ≈ E(T) · 연장 줄 1 (메타를 안 쓰는 전송 - Outcome 으로 봄)' (EndOf $rlxT) 1
Check-Equal "RLX1b 갈래: 호출부 비움으로 메타 거짓 · Outcome 'sent', T ≈ 32초" "$($script:eventResults -join ';')/$(Near $rlxT 32)" 'space|False||sent/True'
Reset-Case -Screen 'unknown'
$script:schedule = @(, @(30, 'ghost'))
Run-Loop
$rlxT = LastExt
Check-Throw "RLX1c 30초쯤 고스트 '나중에': throw · end ≈ E(T) · 연장 줄 1" (EndOf $rlxT) 1
Check-Equal "RLX1c 갈래: 헬퍼가 '나중에' 를 눌러 참(메타 참), T ≈ 32초" "$($script:windowClicks -join ';')/$($script:ghostResults -join ';')/$(Near $rlxT 32)" 'ghost 713,652/True|/True'
#      알 수 없음 시계 (명세 0.3 - 남길 시간의 계산이 기대는 동작): 창을 닫은 회전이 시계를 지워 X 는 전송 뒤 문턱만큼 지나야 나옵니다. 안 지우면 창이 닫힌 직후 화면을 X 후보가 곧바로 누릅니다
Check-True 'RLX1c 고스트 전송 뒤 첫 X 는 T + 문턱 뒤' ((FirstXAfter $rlxT) -ge ($rlxT + $rlxUnknownSeconds)) "(T $rlxT, 첫 X $(FirstXAfter $rlxT))"
# RLX1d·e (X6): 스텔라 1 · 2단계 - 판독은 모의, 클릭은 복귀 루프 호출부(메타는 Send-Mock 이 세움). 연장 뒤에 기존 2초 대기라 T 가 전송 시각입니다.
#      T ≈ 30 의 ±3 으로는 연장이 대기 뒤로 2초 밀려도 통과하고 end 기대도 T 를 따라 함께 밀립니다 - 그래서 연장 시각을 전송 시각과 직접 맞춥니다
Reset-Case -Screen 'unknown'
$script:schedule = @(, @(30, 'stella1')); $script:stellaCardLeadsTo = 'unknown'
Run-Loop
$rlxT = LastExt
$rlxStella = Count-Log '복귀 중 스텔라 픽 감지 - 가운데 카드 선택'
Check-Throw 'RLX1d 스텔라 1단계 카드: throw · end ≈ E(T) · 연장 줄 1' (EndOf $rlxT) 1
Check-Equal 'RLX1d 갈래: 카드 전송 1, 스텔라 로그 줄 1, T ≈ 30초, 연장은 전송 회전 안 (기존 2초 대기 앞)' "$($script:windowClicks -join ';')/$rlxStella/$(Near $rlxT 30)/$(Near $rlxT $script:windowTimes[0] 0.5)" 'stella1 0,0/1/True/True'
Check-True 'RLX1d 카드 전송 뒤 첫 X 는 T + 문턱 뒤' ((FirstXAfter $rlxT) -ge ($rlxT + $rlxUnknownSeconds)) "(T $rlxT, 첫 X $(FirstXAfter $rlxT))"
Reset-Case -Screen 'unknown'
$script:schedule = @(, @(30, 'stella2'))
Run-Loop
$rlxT = LastExt
$rlxStella = Count-Log '복귀 중 스텔라 픽 2단계 - 확정 버튼 클릭'
Check-Throw 'RLX1e 스텔라 2단계 확정: throw · end ≈ E(T) · 연장 줄 1' (EndOf $rlxT) 1
Check-Equal 'RLX1e 갈래: 확정 전송 1, 스텔라 로그 줄 1, T ≈ 30초, 연장은 전송 회전 안 (기존 2초 대기 앞)' "$($script:windowClicks -join ';')/$rlxStella/$(Near $rlxT 30)/$(Near $rlxT $script:windowTimes[0] 0.5)" 'stella2 5,5/1/True/True'
Check-True 'RLX1e 확정 전송 뒤 첫 X 는 T + 문턱 뒤' ((FirstXAfter $rlxT) -ge ($rlxT + $rlxUnknownSeconds)) "(T $rlxT, 첫 X $(FirstXAfter $rlxT))"
#      이어서 두 단계: 카드 클릭 뒤 화면이 'stella1' → 'stella2' 로 바뀌어 둘째 전송 기준입니다
Reset-Case -Screen 'unknown'
$script:schedule = @(, @(30, 'stella1'))
Run-Loop
$rlxT = LastExt
Check-Throw 'RLX1e′ 스텔라 두 단계 연속: throw · end ≈ 둘째 전송 + B · 연장 줄 2' (EndOf $rlxT) 2
Check-Equal 'RLX1e′ 갈래: 카드 → 확정 순서' ($script:windowClicks -join ';') 'stella1 0,0;stella2 5,5'
# RLX1f (X8): 필드 + 40초쯤 공지 게시판 - 판독은 모의, X 클릭은 복귀 루프 호출부. ESC 를 게임이 무시해 필드에 남습니다. 'notice' 는 HUD 가 읽히는 모양이라 HUD 분기가 받고, 그 판독은 필드 확정(W) 뒤 회전에만 있어 전송은 40초가 아니라 그 뒤 첫 확정 회전입니다
Reset-Case -Screen 'field'
$script:escIgnoreUntil = 20000; $script:schedule = @(, @(40, 'notice'))
Run-Loop
$rlxT = LastExt
$rlxNotice = @(LogTimes '공지 게시판 팝업 감지 - X로 닫기')
Check-Throw 'RLX1f 공지 게시판 X: throw · end ≈ E(T) · 연장 줄 1' (EndOf $rlxT) 1
Check-True 'RLX1f 갈래: X 전송 1 · 감지 줄 1, 그 시각이 곧 T 이고 40초 뒤 W + 3초 안쪽 (확정 주기 안)' (($script:windowClicks -join ';') -ceq "notice $($rlxNoticePoint -join ',')" -and $rlxNotice.Count -eq 1 -and $rlxNotice[0] -eq $rlxT -and $rlxT -ge 40 -and $rlxT -le (40 + $memberFieldSettleSeconds + 3)) "(창 '$($script:windowClicks -join ';')', 감지 $($rlxNotice -join ','), T $rlxT)"
Check-Equal "RLX1f 갈래: 가장자리 HUD 가 읽히는 모양은 기존 블록의 줄이고 꼬리 '(HUD 가려짐)' 이 없음" "$(CountLine $rlxNoticeHudLine)/$(CountLine $rlxCoveredLine)" '1/0'
# RLX1g 운영 헬퍼 본문 (RL3 선례): 건너뛰기 · 출석 완료 Space - 전송 판단이 운영 본문의 메타 · Outcome 쓰기와 맞는지 봅니다 (모의 표만이면 코드와 테스트가 같은 가정으로 함께 틀림 - 규칙 9)
foreach ($rlxReal in @(
    @{ Id = '건너뛰기'; Screen = 'skipBook'; Line = '복귀 중 출석부 건너뛰기 클릭'; Want = 'real|True|True||'; Window = 'skipBook 1187,67'; Space = 0 },
    @{ Id = 'Space'; Screen = 'attendDone'; Line = '복귀 중 출석 완료\(지원품 지급\) 화면 - Space로 확인'; Want = 'real|True|False||sent'; Window = ''; Space = 1 })) {
  Reset-Case -Screen 'unknown'
  $script:eventReal = $true; $script:schedule = @(, @(30, $rlxReal.Screen))
  Run-Loop
  $rlxT = LastExt
  $rlxLine = Count-Log $rlxReal.Line
  $rlxTrue = @($script:eventResults | Where-Object { $_ -like 'real|True*' })
  Check-Throw "RLX1g 운영 헬퍼 본문 - $($rlxReal.Id): throw · end ≈ E(T) · 연장 줄 1" (EndOf $rlxT) 1
  Check-Equal "RLX1g 운영 헬퍼 본문 - $($rlxReal.Id): 참 1번의 결과|메타|사유|Outcome, 창 클릭, Space 전송, 헬퍼 줄 1" "$($rlxTrue -join ';')/$($script:windowClicks -join ';')/$($script:spaceSent)/$rlxLine" "$($rlxReal.Want)/$($rlxReal.Window)/$($rlxReal.Space)/1"
}
# RLX1g-c (X1b) 운영 헬퍼 본문 - '확인' 낱말: 전송되고 참이지만 Outcome 'confirm-word' 라 연장 사유가 아닙니다. 클릭이 생략되면 Outcome 을 세우지 않습니다 (실제 전송 뒤에 세움)
Reset-Case -Screen 'unknown'
$script:eventReal = $true; $script:schedule = @(, @(30, 'confirmWord'))
Run-Loop
$rlxTrue = @($script:eventResults | Where-Object { $_ -like 'real|True*' })
$rlxLine = Count-Log '복귀 중 보상 확인 클릭'
Check-Throw "RLX1g-c 운영 헬퍼 본문 - '확인': throw · 연장 줄 0 · end ≈ B" $rlxBase 0
Check-Equal "RLX1g-c 운영 헬퍼 본문 - '확인': 참 1번 · 메타 참 · Outcome 'confirm-word' · 확인 클릭 전송 · 헬퍼 줄 1" "$($rlxTrue -join ';')/$($script:windowClicks -join ';')/$rlxLine" 'real|True|True||confirm-word/confirmWord 640,652/1'
Reset-Case -Screen 'unknown' -SendSeq @('cursor-not-ready')
$script:eventReal = $true; $script:schedule = @(, @(10, 'confirmWord'))
Run-Loop
$rlxTrue = @($script:eventResults | Where-Object { $_ -like 'real|True*' })
Check-Equal "RLX1g-c′ 운영 헬퍼 본문 - '확인' 클릭 생략: 생략 회전의 Outcome 은 비어 있고 다음 회전의 전송만 'confirm-word', 연장 줄 0" "$($rlxTrue -join ';')/$(ExtLines)" 'real|True|False|cursor-not-ready|;real|True|True||confirm-word/0'
# RLX1g-x 운영 본문 세 헬퍼 (X1): 협동 전체 창 X · 네트워크 '다시 시도하기' · 주간 '닫기' - 성공 경로를 모의가 아니라 실제 본문으로 돕니다. 대기는 전송 뒤 헬퍼 안 2 · 3 · 2초
foreach ($rlxWin in @(
    @{ Id = '협동 X'; Screen = 'coopBoard'; Point = '1228,67'; Wait = 2.0; Line = '복귀 중 협동 미션 전체 창 감지\(주간 리셋 추정\) - 닫기\(X\) 클릭' },
    @{ Id = '네트워크'; Screen = 'network'; Point = '764,619'; Wait = 3.0; Line = "복귀 중 네트워크 불안정 팝업 감지 - '다시 시도하기' 클릭 \(재접속 시도\)" },
    @{ Id = "주간 '닫기'"; Screen = 'weekly'; Point = '495,654'; Wait = 2.0; Line = '복귀 중 주간 협동 미션 팝업 감지 - 닫기 클릭' })) {
  Reset-Case -Screen 'unknown'
  $script:eventReal = $true; $script:eventRealHelpers = $true; $script:schedule = @(, @(30, $rlxWin.Screen))
  Run-Loop
  $rlxT = LastExt
  $rlxLine = Count-Log $rlxWin.Line
  $rlxTrue = @($script:eventResults | Where-Object { $_ -like 'real|True*' })
  $rlxWait = $(if ($script:windowTimes.Count -eq 1) { [math]::Round($rlxT - $script:windowTimes[0], 1) } else { -1 })
  Check-Throw "RLX1g-x 운영 본문 - $($rlxWin.Id): throw · end ≈ E(T) · 연장 줄 1" (EndOf $rlxT) 1
  Check-Equal "RLX1g-x 운영 본문 - $($rlxWin.Id): 참 1번 · 메타 참 · Outcome 빈 값, 창 클릭, 헬퍼 안 대기, 헬퍼 줄 1" "$($rlxTrue -join ';')/$($script:windowClicks -join ';')/$rlxWait/$rlxLine" "real|True|True||/$($rlxWin.Screen) $($rlxWin.Point)/$($rlxWin.Wait)/1"
}
# RLX1h 창 둘 연속: 둘째 전송 기준 (두 번째 전송이 남은 시간을 다시 B 로 채움)
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 30; Kind = 'click' }, @{ At = 50; Kind = 'click' })
Run-Loop
$rlxT = LastExt
Check-Throw 'RLX1h 창 둘 연속: throw · end ≈ 둘째 전송 + B · 연장 줄 2' (EndOf $rlxT) 2
Check-True 'RLX1h 둘째 전송 T ≈ 52초' (Near $rlxT 52) "(T $rlxT)"
#      연장 줄의 값 (명세 1.5): '연장 N초' 는 더한 값, '남은 연장 M초' 는 줄인 뒤의 예산입니다. 첫 전송은 남은 시간이 B − T1 이라 T1 을 더하고 둘째는 앞 전송부터 지난 T2 − T1 을 더합니다 (값은 [int] 반올림이라 ±1)
$rlxExtTimes = @(LogTimes $rlxExtPattern)
$rlxExtValues = @(@($script:logs | Where-Object { $_ -match $rlxExtPattern }) | ForEach-Object { $null = $_ -match '연장 (\d+)초, 남은 연장 (\d+)초'; [int]$Matches[1]; [int]$Matches[2] })
$rlxBudget = $rlxLimit - $rlxBase
Check-True 'RLX1h 연장 줄의 값: 첫 줄 연장 ≈ T1 · 남은 연장 ≈ (C − B) − T1, 둘째 줄 연장 ≈ T2 − T1 · 남은 연장 ≈ (C − B) − T2' ($rlxExtValues.Count -eq 4 -and (Near $rlxExtValues[0] $rlxExtTimes[0] 1) -and (Near $rlxExtValues[1] ($rlxBudget - $rlxExtTimes[0]) 1) -and (Near $rlxExtValues[2] ($rlxExtTimes[1] - $rlxExtTimes[0]) 1) -and (Near $rlxExtValues[3] ($rlxBudget - $rlxExtTimes[1]) 1)) "(시각 $($rlxExtTimes -join ','), 값 $($rlxExtValues -join ','))"
# RLX1i 헬퍼 안 양보 10초 + 전송: 연장 앞 조정이 없으면 곧 더해질 양보를 남은 시간에서 빠뜨려 연장을 과하게 씁니다 (end 가 +10)
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 30; Kind = 'click'; YieldMs = 10000 })
Run-Loop
$rlxT = LastExt
Check-Throw 'RLX1i 헬퍼 안 양보 10초 + click: throw · end ≈ T + B · 연장 줄 1' ($rlxT + $rlxBase) 1
Check-True 'RLX1i 양보 10초가 시계를 밀고 T ≈ 42초, Adj ≈ end − 10' ((Near $rlxT 42) -and (Near (Adj) ($script:endAt - 10) 0.1)) "(T $rlxT, Adj $(Adj))"
# RLX1j (X1b) '확인' 오인 반복: 낱말 하나로 매 회전 누르면 헬퍼 참 갈래가 continue 라 X 블록에 닿지 않는 것은 지금과 같고, 연장에서 뺐으므로 B 를 넘지 않습니다 - 지금과 같은 결말 고정
Reset-Case -Screen 'unknown'
$script:eventEvery = 'click-confirm'
Run-Loop
$rlxX = @(XPoints).Count
Check-Throw "RLX1j '확인' 오인 반복: throw · 연장 줄 0 · end ≈ B" $rlxBase 0
#      마지막 회전은 일반 만료 판정에서 끝나 헬퍼에 닿지 않습니다 - 패널 판독 수(회전 수)가 하나 더 많습니다
Check-Equal "RLX1j 헬퍼 호출 수 = 확인 클릭 수 = 회전 수(만료 회전 뺌), X 0회" "$([int]($script:eventCalls -eq $script:confirmClicks))/$([int]($script:eventCalls -eq ($script:panelReads - 1)))/$([int]($script:eventCalls -ge 20))/$rlxX" '1/1/1/0'
# RLX1k 스텔라 6회째: 전송 5회 뒤에도 스텔라 화면이면 블록을 건너뛰어 판독 없이 X 폴백으로 갑니다 (자체 상한 그대로 - 연장 줄도 5 이하)
Reset-Case -Screen 'unknown'
$script:schedule = @(, @(10, 'stella1')); $script:stellaCardLeadsTo = 'stella1'
Run-Loop
$rlxT = LastExt
$rlxStella = Count-Log '복귀 중 스텔라 픽 감지 - 가운데 카드 선택'
$rlxX = @(XPoints).Count
Check-Throw 'RLX1k 스텔라 6회째: throw · end ≈ 다섯째 전송 + B' (EndOf $rlxT) -1
Check-True 'RLX1k 스텔라 로그 줄 5 · 제목 판독 5(6회째 블록 건너뜀) · X 폴백 1 이상 · 연장 줄 1~5' ($rlxStella -eq 5 -and $script:stellaTitleReads -eq 5 -and $rlxX -ge 1 -and (ExtLines) -ge 1 -and (ExtLines) -le 5) "(스텔라 줄 $rlxStella, 제목 판독 $($script:stellaTitleReads), X $rlxX, 연장 줄 $(ExtLines))"

# RLX1l~r (복귀 연장 추가 - '알 수 없는 화면' 쪽 공지 게시판, 사용자 결정 U-R-8): 11-04 기준선(1272)에서 공지 게시판이 뜬 동안 HUD 글자가 읽히지 않아 HUD 분기의 공지 블록에 닿지 못하고 X 후보로 닫혔습니다.
#      'notice-covered' 가 그 모양입니다 (HUD 거짓 · 탭 줄 참). 판독은 5) 분기 고스트 블록 뒤 · 캡처 실패 가드 앞, 소비는 가드 뒤 · X 후보 앞이고 줄 꼬리 '(HUD 가려짐)' 으로 HUD 분기 블록과 가립니다
$rlxCoveredPoint = "$($rlxNoticePoint[0]),$($rlxNoticePoint[1])"
$rlxSkipWord = @{ 'user-active' = '사용자 조작'; 'cursor-not-ready' = '커서 미확인' }
# RLX1l 필드 → 공지가 HUD 까지 가림 → X 전송 → 닫힘 → 복귀: 필드 확정 전에 뜨는 손 시험 모양입니다. 20초를 기다리지 않고 공지가 뜬 뒤 첫 회전에 닫습니다
Reset-Case -Screen 'field'
$script:schedule = @(, @(3, 'notice-covered'))
Run-Loop
$rlxT = LastExt
$rlxX = @(XPoints).Count
$rlxNoticeSent = Count-Log $rlxCoveredAny
$rlxNoticeSkip = Count-Log $rlxNoticeSkipAny
Check-Equal "RLX1l 필드 → HUD 까지 가린 공지 → 닫힘 → 복귀: 복귀 확인 1, 코드 없음, throw 없음, 창 전송 1, 공지 줄 1 · 그 줄이 '(HUD 가려짐)', 연장 줄 1, X 후보 줄 0, 건너뜀 줄 0" "$(Done)/$($script:exitCode)/$($script:threw)/$($script:windowClicks -join ';')/$rlxNoticeSent/$(CountLine $rlxCoveredLine)/$(ExtLines)/$rlxX/$rlxNoticeSkip" "1///notice-covered $rlxCoveredPoint/1/1/1/0/0"
$rlxNoticeTimes = @(LogTimes $rlxCoveredAny)
Check-True 'RLX1l 20초를 기다리지 않음: 공지 줄 시각이 곧 T 이고 공지가 뜬 3초 뒤 첫 회전' ($rlxNoticeTimes.Count -eq 1 -and $rlxNoticeTimes[0] -eq $rlxT -and $rlxT -ge 3 -and $rlxT -lt 4) "(공지 $($rlxNoticeTimes -join ','), T $rlxT)"
# RLX1l′ 같은 전송의 마감: 알 수 없는 화면 + 30초쯤 공지 → 전송 회전에서 B 가 남게 늘고, 뒤 X 후보는 T + 문턱 뒤입니다 (RLX1d 와 같은 모양 - 연장 호출 인자가 HUD 분기와 글자 그대로 같은지는 test_abyss_screen_signatures)
Reset-Case -Screen 'unknown'
$script:schedule = @(, @(30, 'notice-covered')); $script:noticeLeadsTo = 'unknown'
Run-Loop
$rlxT = LastExt
$rlxNoticeSent = Count-Log $rlxCoveredAny
Check-Throw 'RLX1l′ 30초쯤 HUD 까지 가린 공지: throw · end ≈ E(T) · 연장 줄 1' (EndOf $rlxT) 1
Check-Equal 'RLX1l′ 갈래: 창 전송 1, 공지 줄 1, T ≈ 30초' "$($script:windowClicks -join ';')/$rlxNoticeSent/$(Near $rlxT 30 1)" "notice-covered $rlxCoveredPoint/1/True"
Check-True 'RLX1l′ 공지 전송 뒤 첫 X 는 T + 문턱 뒤' ((FirstXAfter $rlxT) -ge ($rlxT + $rlxUnknownSeconds)) "(T $rlxT, 첫 X $(FirstXAfter $rlxT))"
# RLX1m (규칙 4) 같은 화면에서 클릭 생략 'user-active': 연장 없이 건너뜀 줄 · 양보뿐이고 양보 뒤에는 새 판독입니다. 마감이 B 보다 적게 남은 회전이어야 전송과 무관한 연장이 연장 줄로 드러납니다
#      ① 양보 중 창이 닫힘: 창 전송 0 · 연장 0, 그대로 복귀
Reset-Case -Screen 'loading' -SendSeq @('user-active')
$script:schedule = @(, @(10, 'notice-covered')); $script:screenAfterYield = 'field'
Run-Loop
$rlxYieldUntil = $(if ($script:yieldTimes.Count -ge 1) { $script:yieldTimes[0] + $script:yieldSeconds } else { [double]-1 })
$rlxFirstRead = @($script:captureTimes | Where-Object { $_ -ge $rlxYieldUntil } | Select-Object -First 1)[0]
$rlxFirstClick = @($script:clickTimes | Where-Object { $_ -ge $rlxYieldUntil } | Select-Object -First 1)[0]
$rlxNoticeSent = Count-Log $rlxCoveredAny
$rlxX = @(XPoints).Count
Check-Equal "RLX1m ① 'user-active' 뒤 창이 닫힘: 연장 줄 0, 그 사유의 건너뜀 줄 1, 공지 줄 0, 양보 1, 창 전송 0, 생략 1, X 후보 0, 복귀 확인 1, throw 없음" "$(ExtLines)/$(CountLine "[어비스] 공지 게시판 X 닫기 건너뜀 ($($rlxSkipWord['user-active'])) - 다음 회전에서 재시도")/$rlxNoticeSent/$($script:yieldWaits)/$($script:windowClicks.Count)/$($script:windowSkips -join ';')/$rlxX/$(Done)/$($script:threw)" '0/1/0/1/0/notice-covered user-active/0/1/'
Check-True "RLX1m ① 생략 회전은 10초 넘은 뒤(연장이 나올 수 있는 회전), 양보가 끝날 때까지 클릭 0, 양보 뒤 첫 클릭은 새 판독 뒤" ($script:noticeTrueTimes.Count -eq 1 -and $script:noticeTrueTimes[0] -ge 10 -and (ClicksIn 0 $rlxYieldUntil) -eq 0 -and $null -ne $rlxFirstRead -and $null -ne $rlxFirstClick -and $rlxFirstRead -lt $rlxFirstClick) "(공지 $($script:noticeTrueTimes -join ','), 양보 끝 $rlxYieldUntil, 판독 $rlxFirstRead, 클릭 $rlxFirstClick)"
#      ② 창이 남음: 양보 뒤 새 판독이 참일 때만 누릅니다 - 연장은 그 전송 회전 한 번입니다
Reset-Case -Screen 'loading' -SendSeq @('user-active')
$script:schedule = @(, @(10, 'notice-covered'))
Run-Loop
$rlxYieldUntil = $(if ($script:yieldTimes.Count -ge 1) { $script:yieldTimes[0] + $script:yieldSeconds } else { [double]-1 })
$rlxNoticeSkip = Count-Log $rlxNoticeSkipAny
Check-True "RLX1m ② 'user-active' 뒤 창이 남음: 판독 참 2번, 둘째는 양보 끝 뒤, 전송은 그 둘째 회전 1번, 양보 끝까지 클릭 0, 건너뜀 줄 1, 연장 줄 1, 복귀 확인 1" ($script:yieldWaits -eq 1 -and $script:noticeTrueTimes.Count -eq 2 -and $script:noticeTrueTimes[1] -ge $rlxYieldUntil -and $script:windowClicks.Count -eq 1 -and $script:windowTimes[0] -eq $script:noticeTrueTimes[1] -and (ClicksIn 0 $rlxYieldUntil) -eq 0 -and $rlxNoticeSkip -eq 1 -and (ExtLines) -eq 1 -and (Done) -eq 1) "(참 $($script:noticeTrueTimes -join ','), 양보 끝 $rlxYieldUntil, 전송 $($script:windowTimes -join ','), 건너뜀 $rlxNoticeSkip, 연장 줄 $(ExtLines))"
#      ③ 끝내 못 보냄: 매 회전 조작이면 연장 없이 양보만큼만 밀립니다 (HUD 분기의 RLX4e 와 같은 결말)
Reset-Case -Screen 'loading' -SendSeq (@('user-active') * 60)
$script:schedule = @(, @(10, 'notice-covered'))
Run-Loop
$rlxNoticeSkip = Count-Log $rlxNoticeSkipAny
Check-Throw "RLX1m ③ 'user-active' 반복: throw · 연장 줄 0 · end ≈ B + 양보" ($rlxBase + $script:userYieldTotalMs / 1000.0) 0
Check-Equal "RLX1m ③ 건너뜀 줄 = 양보 수 = 생략 수(횟수 상한보다 많음 - 조작 생략은 횟수를 안 씀), 창 전송 0, Adj ≈ B" "$([int]($rlxNoticeSkip -eq $script:yieldWaits))/$([int]($rlxNoticeSkip -eq $script:windowSkips.Count))/$([int]($rlxNoticeSkip -gt $noticeCloseTryLimit))/$($script:windowClicks.Count)/$(Near (Adj) $rlxBase)" '1/1/1/0/True'
# RLX1n (규칙 4) 'cursor-not-ready': 연장도 양보도 없고 시간과 횟수를 씁니다. 상한만큼 생략되면 X 후보로 넘깁니다 - 안 쓰면 커서가 안 잡히는 동안 X 후보에 영영 못 갑니다
Reset-Case -Screen 'loading' -SendSeq (@('cursor-not-ready') * 60)
$script:schedule = @(, @(10, 'notice-covered'))
Run-Loop
$rlxNoticeSkip = CountLine "[어비스] 공지 게시판 X 닫기 건너뜀 ($($rlxSkipWord['cursor-not-ready'])) - 다음 회전에서 재시도"
$rlxNoticeSent = Count-Log $rlxCoveredAny
$rlxHandTimes = @(LogTimes $rlxHandPattern)
$rlxXSkipTimes = @(LogTimes '복귀 중 닫기\(X\) 후보\(.*클릭을 건너뜀 \(커서 미확인\)')
Check-Throw "RLX1n 'cursor-not-ready' 반복: throw · 연장 줄 0 · end ≈ B" $rlxBase 0
Check-Equal "RLX1n 양보 0, 그 사유의 건너뜀 줄 = 횟수 상한, 창 전송 0, 공지 줄 0, 넘김 줄 1, Adj ≈ B" "$($script:yieldWaits)/$rlxNoticeSkip/$($script:windowClicks.Count)/$rlxNoticeSent/$($rlxHandTimes.Count)/$(Near (Adj) $rlxBase)" "0/$noticeCloseTryLimit/0/0/1/True"
Check-True 'RLX1n X 후보는 넘김 줄에서 문턱 뒤에 돌기 시작함 (생략되어도 다음 후보로 감)' ($rlxXSkipTimes.Count -ge 2 -and (Near $rlxXSkipTimes[0] ($rlxHandTimes[0] + $rlxUnknownSeconds) 1)) "(넘김 $($rlxHandTimes -join ','), X 생략 $($rlxXSkipTimes -join ','))"
# RLX1o 공지 판독이 거짓이면 지금 흐름 그대로입니다 - 11-04 기준선을 재생합니다 (로그 순서를 모의로 옮긴 것): 문턱 뒤 X 후보 (1229,67) → (1090,137) 에서 닫히고 공지 줄 0 · 연장 줄 0 · 복귀
Reset-Case -Screen 'field'
$script:schedule = @(, @(3, 'notice-covered')); $script:noticeScreens = @(); $script:noticeSecondXCloses = $true   # 11-04 의 창 DPI 96 창입니다
Run-Loop
$rlxXOrder = @(XPoints) -join ' → '
$rlxXTimes = @(LogTimes $rlxXPattern)
$rlxNoticeSent = Count-Log $rlxCoveredAny
Check-Equal "RLX1o 탭 줄을 못 읽는 공지: 복귀 확인 1, throw 없음, 공지 줄 0, 연장 줄 0, X 후보 순서 그대로, 둘째 후보가 창을 닫음" "$(Done)/$($script:threw)/$rlxNoticeSent/$(ExtLines)/$rlxXOrder/$($script:windowClicks -join ';')" "1//0/0/1229,67 → 1090,137/notice-covered 1090,137"
$rlxOFirstRead = @($script:noticeReadTimes | Where-Object { $_ -ge 3 } | Select-Object -First 1)[0]
Check-True 'RLX1o 첫 X 는 공지가 뜬 뒤 첫 탭 판독에서 문턱이 지난 바로 다음 회전 (늦어도 통과하지 않음)' ($null -ne $rlxOFirstRead -and $rlxXTimes.Count -ge 1 -and $rlxXTimes[0] -ge ($rlxOFirstRead + $rlxUnknownSeconds) -and (Near $rlxXTimes[0] ($rlxOFirstRead + $rlxUnknownSeconds) 1)) "(첫 탭 판독 $rlxOFirstRead, X $($rlxXTimes -join ','))"
#      안 닫히는 공지 창 (사용자 결정 U-R-10): 공지 전송은 횟수 상한에서 멈추고 연장도 거기까지입니다. 그 뒤는 X 후보가 돌다가 마지막 연장에서 B 뒤에 끝납니다 - 11-05 처럼 상한 C 까지 헛클릭하지 않습니다
Reset-Case -Screen 'loading'
$script:schedule = @(, @(30, 'notice-covered')); $script:noticeLeadsTo = 'notice-covered'
Run-Loop
$rlxNoticeTimes = @(LogTimes $rlxCoveredAny)
$rlxHandTimes = @(LogTimes $rlxHandPattern)
$rlxXTimes = @(LogTimes $rlxXPattern)
Check-Throw 'RLX1o 안 닫히는 공지 창: throw · end ≈ E(둘째 전송) · 연장 줄 = 횟수 상한' (EndOf $rlxNoticeTimes[$noticeCloseTryLimit - 1]) $noticeCloseTryLimit
Check-Equal 'RLX1o 안 닫히는 공지 창: 공지 줄 = 횟수 상한, 넘김 줄 1, 넘김은 마지막 공지 뒤' "$($rlxNoticeTimes.Count)/$($rlxHandTimes.Count)/$([int]($rlxHandTimes[0] -gt $rlxNoticeTimes[-1]))" "$noticeCloseTryLimit/1/1"
$rlxXAfterHand = @($rlxXTimes | Where-Object { $_ -gt $rlxHandTimes[0] })
$rlxFirstNotice = $rlxNoticeTimes[0]
Check-True 'RLX1o 안 닫히는 공지 창: 공지가 뜬 뒤 첫 X 는 넘김 + 문턱 뒤, 공지가 뜬 뒤 공지 회전 사이에는 X 0, 그 뒤 X 후보가 세 번 넘게 돎' ($rlxXAfterHand.Count -ge 3 -and (Near $rlxXAfterHand[0] ($rlxHandTimes[0] + $rlxUnknownSeconds) 1) -and @($rlxXTimes | Where-Object { $_ -ge $rlxFirstNotice -and $_ -le $rlxHandTimes[0] }).Count -eq 0) "(넘김 $($rlxHandTimes -join ','), X $($rlxXTimes -join ','))"
# RLX1s (11-05 14:42 실패 재현): 자리 함수가 옛 고정점을 돌려주면 공지 X 가 빗나갑니다. 공지 줄은 횟수 상한까지이고 그 뒤는 X 후보입니다 - 고치기 전에는 42번 헛클릭으로 상한 C 까지 갔습니다.
#       둘째가 닫는 갈래는 창 DPI 96 모양, 안 닫는 갈래는 11-05 에 눌러 본 1272 · 창 DPI 144 모양입니다 - 그 창의 안전망은 닫지 못하고 마감에서 코드 1 입니다
foreach ($rlxSecondCloses in @($true, $false)) {
  Reset-Case -Screen 'field'
  $script:noticeClosePoint = $rlxNoticeOldPoint; $script:noticeSecondXCloses = $rlxSecondCloses
  $script:schedule = @(, @(3, 'notice-covered'))
  Run-Loop
  $rlxNoticeTimes = @(LogTimes $rlxCoveredAny)
  $rlxHandTimes = @(LogTimes $rlxHandPattern)
  Check-Equal "RLX1s 빗나가는 공지 X (둘째가 닫음 $rlxSecondCloses): 공지 줄 = 횟수 상한, 넘김 줄 1" "$($rlxNoticeTimes.Count)/$($rlxHandTimes.Count)" "$noticeCloseTryLimit/1"
  Check-True "RLX1s 첫 X 는 넘김 + 문턱 뒤 (둘째가 닫음 $rlxSecondCloses)" ((FirstXAfter $rlxHandTimes[0]) -ge ($rlxHandTimes[0] + $rlxUnknownSeconds) -and (Near (FirstXAfter $rlxHandTimes[0]) ($rlxHandTimes[0] + $rlxUnknownSeconds) 1)) "(넘김 $($rlxHandTimes -join ','), 첫 X $(FirstXAfter $rlxHandTimes[0]))"
  if ($rlxSecondCloses) {
    Check-Equal 'RLX1s 둘째가 닫으면: 복귀 확인 1, throw 없음, X 후보 첫째 → 둘째, 둘째가 창을 닫음' "$(Done)/$($script:threw)/$(@(XPoints) -join ' → ')/$($script:windowClicks -join ';')" "1//1229,67 → 1090,137/notice-covered 1090,137"
  } else {
    Check-Throw 'RLX1s 둘째도 안 닫으면: throw · end ≈ 마지막 연장 + B · 상한 C 까지 가지 않음' (EndOf (LastExt)) (ExtLines)
    Check-True 'RLX1s 둘째도 안 닫으면: 복귀 확인 0, 연장 줄은 횟수 상한 이하' ((Done) -eq 0 -and (ExtLines) -le $noticeCloseTryLimit) "(연장 $(ExtLines))"
  }
}
# RLX1t HUD 가 읽히는 쪽 (U-R-10): X 후보 경로가 없어 클릭은 막지 않고 연장만 횟수 상한까지입니다
Reset-Case -Screen 'loading'
$script:schedule = @(, @(40, 'notice')); $script:noticeLeadsTo = 'notice'
Run-Loop
$rlxNoticeTimes = @(LogTimes $rlxNoticeLinePattern)
Check-Throw 'RLX1t 안 닫히는 공지 (HUD 읽힘): throw · end ≈ E(둘째 전송) · 연장 줄 = 횟수 상한' (EndOf $rlxNoticeTimes[$noticeCloseTryLimit - 1]) $noticeCloseTryLimit
Check-True 'RLX1t 클릭은 상한 뒤에도 이어짐, 넘김 줄 0, 공지가 뜬 뒤 X 후보 0' ($rlxNoticeTimes.Count -gt ($noticeCloseTryLimit + 1) -and (Count-Log $rlxHandPattern) -eq 0 -and (FirstXAfter $rlxNoticeTimes[0]) -lt 0) "(공지 $($rlxNoticeTimes.Count), 첫 X $(FirstXAfter $rlxNoticeTimes[0]))"
# RLX1u HUD 쪽 'cursor-not-ready' 도 같은 횟수를 씁니다 (설계 리뷰 P2): 그 뒤 HUD 가 가려져 5) 분기로 오면 공지 클릭 없이 넘깁니다
Reset-Case -Screen 'field' -SendSeq (@('cursor-not-ready') * $noticeCloseTryLimit)
$script:schedule = @(@(1, 'notice'), @(16, 'notice-covered')); $script:noticeSecondXCloses = $true   # 이 행은 넘김까지가 대상입니다
Run-Loop
$rlxHudSkip = CountLine "[어비스] 공지 게시판 X 닫기 건너뜀 ($($rlxSkipWord['cursor-not-ready'])) - 다음 회전에서 재시도"
$rlxHandTimes = @(LogTimes $rlxHandPattern)
Check-Equal "RLX1u HUD 쪽 'cursor-not-ready' 뒤 5) 분기: 건너뜀 줄 = 횟수 상한, 공지 줄 0, 넘김 줄 1, 복귀 확인 1, 둘째 X 후보가 닫음" "$rlxHudSkip/$(Count-Log $rlxCoveredAny)/$($rlxHandTimes.Count)/$(Done)/$($script:windowClicks -join ';')" "$noticeCloseTryLimit/0/1/1/notice-covered 1090,137"
# RLX1v HUD 쪽 'user-active' 는 횟수를 쓰지 않습니다 (규칙 4): 상한만큼 생략돼도 ① 5) 분기로 오면 공지 X 를 누르고 ② HUD 에 머물면 첫 전송이 연장을 받습니다
$rlxHudCycle = $memberFieldSettleSeconds + 5 + 3   # 필드 모양 W + 양보 5초 + 대기 2초에 여유 1초
Reset-Case -Screen 'field' -SendSeq (@('user-active') * $noticeCloseTryLimit)
$script:schedule = @(@(1, 'notice'), @((1 + $noticeCloseTryLimit * $rlxHudCycle), 'notice-covered'))
Run-Loop
$rlxHudSkip = CountLine "[어비스] 공지 게시판 X 닫기 건너뜀 ($($rlxSkipWord['user-active'])) - 다음 회전에서 재시도"
Check-Equal "RLX1v ① HUD 쪽 'user-active' 뒤 5) 분기: 건너뜀 줄 = 횟수 상한, 넘김 줄 0, 가려짐 공지 줄 1, 복귀 확인 1, 전송은 계산 자리" "$rlxHudSkip/$(Count-Log $rlxHandPattern)/$(Count-Log '공지 게시판 팝업 감지 - X로 닫기 \(HUD 가려짐\)$')/$(Done)/$($script:windowClicks -join ';')" "$noticeCloseTryLimit/0/1/1/notice-covered $rlxCoveredPoint"
Reset-Case -Screen 'field' -SendSeq (@('user-active') * $noticeCloseTryLimit)
$script:schedule = @(, @(1, 'notice'))
Run-Loop
$rlxHudSkip = CountLine "[어비스] 공지 게시판 X 닫기 건너뜀 ($($rlxSkipWord['user-active'])) - 다음 회전에서 재시도"
Check-Equal "RLX1v ② HUD 쪽 'user-active' 뒤 HUD 에 머묾: 건너뜀 줄 = 횟수 상한, 공지 줄 1, 그 전송의 연장 줄 1, 복귀 확인 1" "$rlxHudSkip/$(Count-Log $rlxNoticeLinePattern)/$(ExtLines)/$(Done)" "$noticeCloseTryLimit/1/1/1"
# RLX1p 앞 경로가 참이면 그 회전은 공지를 읽지 않습니다 (기존 경로가 그대로): 탭 줄이 함께 참이어도 이벤트 헬퍼 · 고스트가 먼저 받습니다. 판독을 앞으로 옮기면 탭 줄 판독이 세어지고 공지 X 가 먼저 나갑니다
Reset-Case -Screen 'notice-covered'
$script:eventEvery = 'click'
Run-Loop
$rlxNoticeSent = Count-Log $rlxCoveredAny
Check-Equal 'RLX1p 이벤트 헬퍼가 매 회전 참 (탭 줄도 참): 탭 줄 판독 0, 공지 줄 0, 창 전송 0, 헬퍼 호출 20 이상' "$($script:noticeCalls)/$rlxNoticeSent/$($script:windowClicks.Count)/$([int]($script:eventCalls -ge 20))" '0/0/0/1'
Reset-Case -Screen 'ghost'
$script:noticeScreens = @('ghost'); $script:windowLeadsTo = 'ghost'
Run-Loop
$rlxNoticeSent = Count-Log $rlxCoveredAny
Check-Equal "RLX1p 고스트가 매 회전 참 (탭 줄도 참): 탭 줄 판독 0, 공지 줄 0, '나중에' 전송 20 이상" "$($script:noticeCalls)/$rlxNoticeSent/$([int]($script:windowClicks.Count -ge 20))" '0/0/1'
#      회전 단위: 참인 그 회전만 빠지고 앞 경로가 거짓인 회전은 회전마다 한 번 읽습니다 (0 만 보면 판독이 통째로 사라져도 통과합니다)
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 10; Kind = 'click' })
Run-Loop
Check-Equal 'RLX1p 이벤트 헬퍼가 한 회전 참: 탭 줄 판독 = 헬퍼 호출 − 1 (10 이상)' "$([int]($script:noticeCalls -eq ($script:eventCalls - 1)))/$([int]($script:noticeCalls -ge 10))" '1/1'
Reset-Case -Screen 'unknown'
$script:schedule = @(, @(10, 'ghost'))
Run-Loop
$rlxGhostReads = @($script:readNames | Where-Object { $_ -ceq 'Close-GhostRegisterPrompt' }).Count
Check-Equal 'RLX1p 고스트가 한 회전 참: 탭 줄 판독 = 고스트 판독 − 1 (10 이상)' "$([int]($script:noticeCalls -eq ($rlxGhostReads - 1)))/$($script:ghostResults.Count)/$([int]($script:noticeCalls -ge 10))" '1/1/1'
# RLX1q 공지가 '알 수 없음' 구간을 끊습니다 (생략 회전에도 시계를 지움): 시계가 19초쯤 간 뒤 공지가 한 회전만 참이고 클릭은 생략, 다음 회전부터 로딩입니다.
#      전제를 행 안에서 단언합니다 - 공지 회전은 옛 시계 문턱 전이고, 그 뒤 첫 판독 회전은 옛 시계로 문턱을 넘고 새 시계로는 문턱 미만입니다 (전제가 빠지면 X 0 은 헛단언입니다). 시계는 양보를 뺍니다.
#      옛 시계는 시각으로 계산한 값이라 그 계산의 전제도 단언합니다 - 시계 기점인 첫 판독이 0초이고 공지 회전까지 회전마다 판독했습니다. 필드로 시작하거나 앞 경로 · 동결이 끼면 시계가 늦게 시작하거나 지워지는데 계산값은 그대로라, 이 둘이 없으면 전제 행이 그런 모양에서도 통과합니다 (변이 검증에서 드러남)
#      양성: 공지 회전부터 새 문턱이 지나면 X 후보가 실제로 나옵니다
foreach ($rlxSkip in @('user-active', 'cursor-not-ready')) {
  Reset-Case -Screen 'loading' -SendSeq @($rlxSkip)
  $script:schedule = @(@(19, 'notice-covered'), @(20, 'loading'))
  Run-Loop
  $rlxQNotice = $(if ($script:noticeTrueTimes.Count -ge 1) { $script:noticeTrueTimes[0] } else { [double]-1 })
  $rlxQAfter = @($script:noticeReadTimes | Where-Object { $_ -gt $rlxQNotice } | Select-Object -First 1)[0]
  $rlxQYield = $script:userYieldTotalMs / 1000.0
  $rlxQOldClock = $rlxQAfter - $rlxQYield
  $rlxQNewClock = $rlxQAfter - $rlxQNotice - $rlxQYield
  $rlxQGap = MaxGap $script:noticeReadTimes 0 ($rlxQNotice + 0.1)
  Check-True "RLX1q 전제 ($rlxSkip): 시계 기점인 첫 판독 0초 · 공지 회전까지 회전마다 판독, 공지 참 1회전 · 그 시각 18초 이상 문턱 미만, 생략 1 · 전송 0, 그 뒤 첫 판독 회전의 옛 시계 ≥ 문턱 · 새 시계 < 문턱 · 공지 뒤 2초 이상" ($script:noticeReadTimes[0] -eq 0 -and $rlxQGap -le 0.7 -and $script:noticeTrueTimes.Count -eq 1 -and $rlxQNotice -ge 18 -and $rlxQNotice -lt $rlxUnknownSeconds -and ($script:windowSkips -join ';') -eq "notice-covered $rlxSkip" -and $script:windowClicks.Count -eq 0 -and $null -ne $rlxQAfter -and $rlxQOldClock -ge $rlxUnknownSeconds -and $rlxQNewClock -lt $rlxUnknownSeconds -and $rlxQNewClock -ge 2) "(첫 판독 $($script:noticeReadTimes[0]), 판독 간격 $rlxQGap, 공지 $rlxQNotice, 다음 판독 $rlxQAfter, 양보 $rlxQYield, 옛 시계 $rlxQOldClock, 새 시계 $rlxQNewClock)"
  $rlxFirstX = FirstXAfter 0
  Check-True "RLX1q $rlxSkip`: 옛 시계로 문턱을 넘긴 그 회전에 X 후보 0, 첫 X 는 다음 판독 + 문턱 뒤 실제로 나옴, 연장 줄 0" ($rlxFirstX -ge ($rlxQAfter + $rlxUnknownSeconds - 0.1) -and (Near $rlxFirstX ($rlxQAfter + $rlxUnknownSeconds)) -and (ExtLines) -eq 0) "(다음 판독 $rlxQAfter, 첫 X $rlxFirstX, 연장 줄 $(ExtLines))"
}
# RLX1r 캡처 실패 (규칙 15): 판독 · 기존 가드 · 소비 순서가 지킵니다
#      ① 알 수 없음 시계가 이미 문턱을 넘긴 회전의 공지 판독이 캡처 실패로 거짓: 그 거짓이 X 후보로 새지 않습니다. 전제는 시각으로 단언합니다 - 시계는 첫 회전 0초부터이고 실패 회전까지 회전마다 판독했고 양보 · 동결이 없어 실패 시각이 곧 시계이며, 복구 뒤 X 후보가 실제로 나옵니다.
#      실패 시각은 모의가 실패시킨 그 판독의 시각입니다 - '문턱 뒤 첫 판독' 으로 뽑으면 '실패 시각 ≥ 문턱' 은 늘 참이라 실패가 5초에 나도 전제 조건들이 통과했습니다 (변이 검증에서 드러남)
Reset-Case -Screen 'loading'
$script:noticeFailFrom = $rlxUnknownSeconds
Run-Loop
$rlxFailAt = @($script:noticeFailTimes)[0]
$rlxFailGap = $(if ($null -ne $rlxFailAt) { MaxGap $script:noticeReadTimes 0 ($rlxFailAt + 0.1) } else { [double]999 })
$rlxXTimes = @(LogTimes $rlxXPattern)
Check-True 'RLX1r ① 시계가 문턱을 넘긴 회전의 공지 판독 실패: 시계 기점인 첫 판독 0초 · 실패시킨 판독의 시각 ≥ 문턱 · 그 회전까지 회전마다 판독 · 실패 1번 · 그 앞 양보 0, 실패 회전까지 클릭 0, 첫 X 는 실패 회전 뒤 복구 회전들을 지나 나옴' ($script:noticeReadTimes[0] -eq 0 -and $null -ne $rlxFailAt -and $rlxFailAt -ge $rlxUnknownSeconds -and $rlxFailGap -le 0.7 -and $script:captureFailSerial -eq 1 -and $script:yieldWaits -eq 0 -and (ClicksIn 0 ($rlxFailAt + 0.7)) -eq 0 -and $rlxXTimes.Count -ge 1 -and $rlxXTimes[0] -gt ($rlxFailAt + 0.7) -and (Near $rlxXTimes[0] ($rlxFailAt + 2.1) 1)) "(실패 $rlxFailAt, 판독 간격 $rlxFailGap, 실패 수 $($script:captureFailSerial), 클릭 $(ClicksIn 0 ($rlxFailAt + 0.7)), X $($rlxXTimes -join ','))"
#      ② 같은 회전 앞 판독(고스트)이 실패했다가 뒤 판독에서 복구 · 공지 참: 플래그는 풀렸어도 일련번호가 달라 그 회전은 누르지 않고 다음 회전의 새 판독으로 전송합니다
Reset-Case -Screen 'notice-covered'
$script:failOnceAt = @{ 'Close-GhostRegisterPrompt' = 1 }
Run-Loop
$rlxNoticeSent = Count-Log $rlxCoveredAny
Check-True 'RLX1r ② 앞 판독 실패 · 복구 · 공지 참: 판독 참 2번, 첫 회전은 클릭 0, 전송은 둘째 판독 회전 1번, 실패 1번, 동결 0(플래그는 풀림), 공지 줄 1, 복귀 확인 1' ($script:noticeTrueTimes.Count -eq 2 -and (ClicksIn 0 $script:noticeTrueTimes[1]) -eq 0 -and $script:windowClicks.Count -eq 1 -and $script:windowTimes[0] -eq $script:noticeTrueTimes[1] -and $script:captureFailSerial -eq 1 -and $script:safeStopCalls -eq 0 -and $rlxNoticeSent -eq 1 -and (Done) -eq 1) "(참 $($script:noticeTrueTimes -join ','), 전송 $($script:windowTimes -join ','), 실패 $($script:captureFailSerial), 동결 $($script:safeStopCalls), 공지 줄 $rlxNoticeSent)"
# 소스 단언 (주석 뺀 사본): 판독은 고스트 블록 바로 뒤 · 가드 앞, 소비 if 는 가드 바로 뒤 · X 후보 앞입니다. '5.5' 는 주석이라 사본에 없어 그 자리의 첫 코드 줄(알 수 없음 시계)로 봅니다
$rlxSource = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Return-ToAbyssSelection')))
$rlxGhostAt = $rlxSource.IndexOf('if (Close-GhostRegisterPrompt -Game $Game')
$rlxReadAt = $rlxSource.IndexOf('$noticeCovered = Test-NoticeBoardPopup -Game $Game')
$rlxGuardLine = 'if ($script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial) { Start-Sleep -Milliseconds 700; continue }'
$rlxGuardAt = $rlxSource.IndexOf($rlxGuardLine, [Math]::Max(0, $rlxReadAt))
$rlxUseLine = 'if ($noticeCovered -and $noticeCloseTries -lt $noticeCloseTryLimit) {'
$rlxUseAt = $rlxSource.IndexOf($rlxUseLine)
$rlxHandAt = $rlxSource.IndexOf('if ($noticeCovered -and -not $noticeHandedToX) {')
$rlxClockAt = $rlxSource.IndexOf('if ($null -eq $unknownSince)')
$rlxOrdered = ($rlxGhostAt -gt 0 -and $rlxReadAt -gt $rlxGhostAt -and $rlxGuardAt -gt $rlxReadAt -and $rlxUseAt -gt $rlxGuardAt -and $rlxHandAt -gt $rlxUseAt -and $rlxClockAt -gt $rlxHandAt)
Check-True '소스(주석 뺀 사본): 고스트 < 판독 < 가드 < 소비 if < 넘김 if < 알 수 없음 시계' $rlxOrdered "(고스트 $rlxGhostAt, 판독 $rlxReadAt, 가드 $rlxGuardAt, 소비 $rlxUseAt, 넘김 $rlxHandAt, 시계 $rlxClockAt)"
if ($rlxOrdered) {
  $rlxBetweenGhost = $rlxSource.Substring($rlxGhostAt, $rlxReadAt - $rlxGhostAt)
  $rlxBetweenRead = $rlxSource.Substring($rlxReadAt, $rlxGuardAt - $rlxReadAt)
  $rlxBetweenGuard = $rlxSource.Substring($rlxGuardAt + $rlxGuardLine.Length, $rlxUseAt - $rlxGuardAt - $rlxGuardLine.Length)
  $rlxUseBlock = $rlxSource.Substring($rlxUseAt, $rlxHandAt - $rlxUseAt)
  Check-Equal '소스(주석 뺀 사본): 판독은 고스트 블록의 닫는 괄호 바로 뒤 · 판독과 가드 사이 다른 문장 0 · 가드와 소비 if 사이 다른 문장 0 · 소비 if 는 continue 로 닫힘, 소비 if · 판독 대입 각 1곳' (
    "$([int]($rlxBetweenGhost -match 'continue\s*\}\s*$'))/" + "$([int]($rlxBetweenRead -match '^\$noticeCovered = Test-NoticeBoardPopup -Game \$Game\s*$'))/" + "$([int]($rlxBetweenGuard -match '^\s*$'))/" + "$([int]($rlxUseBlock -match 'continue\s*\}\s*$'))/" +
    "$([regex]::Matches($rlxSource, [regex]::Escape($rlxUseLine)).Count)/$([regex]::Matches($rlxSource, '\$noticeCovered = ').Count)") '1/1/1/1/1/1'
}

# RLX2a 아는 창 없음: 지금과 같은 마감 (X 후보는 연장 사유가 아님 - U-R-2)
Reset-Case -Screen 'unknown'
Run-Loop
$rlxX = @(XPoints).Count
Check-Throw 'RLX2a 알 수 없는 화면만: throw · end ≈ B · 연장 줄 0' $rlxBase 0
Check-True 'RLX2a X 후보 전송 1 이상' ($rlxX -ge 1) "(X $rlxX)"
# RLX2b click 1 뒤 X 만: 전송 뒤에 눌린 X 후보들이 마감을 옮기지 않습니다
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 21; Kind = 'click' })
Run-Loop
$rlxT = LastExt
$rlxXAfter = @(LogTimes $rlxXPattern | Where-Object { $_ -gt $rlxT }).Count
Check-Throw 'RLX2b click 1 뒤 X 만: throw · end ≈ E(T) · 연장 줄 1' (EndOf $rlxT) 1
Check-True 'RLX2b T 뒤에 X 후보 전송 3 이상' ($rlxXAfter -ge 3) "(T $rlxT, 뒤 X $rlxXAfter)"
Check-True 'RLX2b 이벤트 전송 뒤 첫 X 는 T + 문턱 뒤' ((FirstXAfter $rlxT) -ge ($rlxT + $rlxUnknownSeconds)) "(T $rlxT, 첫 X $(FirstXAfter $rlxT))"
# RLX2c (X10) 복귀 본 동작 대표: 각 입력은 전송되지만 연장 사유가 아니고 마감은 B 그대로입니다
Reset-Case -Screen 'field'
$script:escIgnoreUntil = 20000
Run-Loop
Check-Throw 'RLX2c ESC 글자 클릭 반복: throw · 연장 줄 0 · end ≈ B' $rlxBase 0
Check-True 'RLX2c ESC 글자 전송 2 이상' ($script:escClicksSent -ge 2) "(ESC $($script:escClicksSent))"
Reset-Case -Screen 'field'
$script:abyssLeadsTo = 'detail'; $script:escDetailLeadsTo = 'menu'
Run-Loop
Check-Throw "RLX2c 메뉴 '어비스' · 오클릭 ESC · 메뉴 닫기 ESC 반복: throw · 연장 줄 0 · end ≈ B" $rlxBase 0
Check-True "RLX2c 메뉴 '어비스' · 오클릭 ESC · 메뉴 닫기 ESC 전송 각 1 이상" ($script:abyssClicksSent -ge 1 -and $script:keyOnce -ge 1 -and $script:keyVerified -ge 1) "(어비스 $($script:abyssClicksSent), 오클릭 ESC $($script:keyOnce), 메뉴 닫기 $($script:keyVerified))"
Reset-Case -Screen 'reward'
Run-Loop
Check-Throw 'RLX2c 나가기 복구 재시도 반복: throw · 연장 줄 0 · end ≈ B' $rlxBase 0
Check-True 'RLX2c 나가기 헬퍼 호출 2 이상' ($script:helperCalls -ge 2) "(헬퍼 $($script:helperCalls))"

# RLX3a 상한 (U-R-3): 매 회전 전송이어도 C 에서 끝납니다 (연장 예산이 끝나면 더 늘지 않음). __VTIMEOUT__ 이면 throw 문구가 달라 Check-Throw 가 잡습니다
Reset-Case -Screen 'unknown'
$script:eventEvery = 'click'
Run-Loop
$rlxLastExt = [string](@($script:logs | Where-Object { $_ -match $rlxExtPattern }) | Select-Object -Last 1)
Check-Throw 'RLX3a 매 회전 click: throw · end ≈ C' $rlxLimit -1
Check-True "RLX3a 마지막 연장 줄 꼬리 '남은 연장 0초', 연장 뒤에도 전송이 이어짐" ($rlxLastExt -match '남은 연장 0초\)$' -and $script:eventResults.Count -gt (ExtLines)) "($rlxLastExt, 전송 $($script:eventResults.Count), 연장 줄 $(ExtLines))"
# RLX3b·c 상한은 유효 시간: 조작 [50,90) · 캡처 실패 [50,110) 시간은 상한에 들지 않습니다 (벽시계 상한이면 양보가 끝나는 즉시 만료 - 규칙 4 · 15)
Reset-Case -Screen 'unknown'
$script:eventEvery = 'click'; $script:activeFrom = 50; $script:activeUntil = 90
Run-Loop
Check-Throw 'RLX3b 매 회전 click + 조작 [50,90): throw · end ≈ C + 40' ($rlxLimit + 40) -1
Check-True 'RLX3b Adj ≈ C, 조작 창 안 클릭 0' ((Near (Adj) $rlxLimit) -and (ClicksIn 50 90) -eq 0) "(Adj $(Adj), 창 안 $(ClicksIn 50 90))"
Reset-Case -Screen 'unknown'
$script:eventEvery = 'click'; $script:capfailFrom = 50; $script:capfailUntil = 110
Run-Loop
Check-Throw 'RLX3c 매 회전 click + 캡처 실패 [50,110): throw · end ≈ C + 60' ($rlxLimit + 60) -1
Check-True 'RLX3c Adj ≈ C, 실패 창 안 클릭 0' ((Near (Adj) $rlxLimit) -and (ClicksIn 50 110) -eq 0) "(Adj $(Adj), 창 안 $(ClicksIn 50 110))"
# RLX3d 기본 예산 ≥ C: 기본 예산은 줄이지 않고 연장도 없습니다 (타임아웃 값을 바꾼 사용자 - 상한이 조기 종료로 바뀌면 안 됨)
foreach ($rlxTimeouts in @(@(100, 50, 50), @(90, 45, 45))) {
  $timeoutHud = $rlxTimeouts[0]; $timeoutAbyssMenu = $rlxTimeouts[1]; $timeoutAbyssSelect = $rlxTimeouts[2]
  $rlxBig = $timeoutHud + $timeoutAbyssMenu + $timeoutAbyssSelect
  Reset-Case -Screen 'unknown'
  $script:eventEvery = 'click'
  Run-Loop
  Check-Throw "RLX3d 기본 예산 $rlxBig (≥ C) + 매 회전 click: throw · 연장 줄 0 · 그 시각에 끝남 (C 에서 조기 종료 없음)" $rlxBig 0
}
$timeoutHud = 30; $timeoutAbyssMenu = 15; $timeoutAbyssSelect = 15

# RLX4 전송되지 않은 입력은 연장 사유가 아닙니다 (규칙 4) - 공통 단언: 그 분기 호출 수 · 클릭 시도와 생략 사유 · 메타 · Outcome · 연장 줄 0 (Adj ≈ B 만 보면 분기가 사라져도 통과합니다)
# RLX4a·b 이벤트 헬퍼 안 클릭 생략 (X3): 참이지만 메타 거짓
foreach ($rlxSkip in @(@{ Kind = 'click-user'; Reason = 'user-active' }, @{ Kind = 'click-cursor'; Reason = 'cursor-not-ready' })) {
  Reset-Case -Screen 'unknown'
  $script:eventPlan = @(@{ At = 30; Kind = $rlxSkip.Kind })
  Run-Loop
  Check-Throw "RLX4a·b $($rlxSkip.Kind): throw · 연장 줄 0 · end ≈ B" $rlxBase 0
  Check-Equal "RLX4a·b $($rlxSkip.Kind): 분기 1번 · 메타 거짓 · 사유 · Outcome 빈 값, Adj ≈ B" "$($script:eventResults -join ';')/$(Near (Adj) $rlxBase)" "$($rlxSkip.Kind)|False|$($rlxSkip.Reason)|/True"
}
# RLX4c 고스트 생략 둘 (X7): 참은 전송이 아닙니다 - 화면이 남아 매 회전 시도합니다. 운영 Close-GhostRegisterPrompt 본문을 돕니다 (참 · 메타 거짓을 모의가 정해 두면 이 행이 볼 것이 없습니다)
#       RLX4c′ 생략 1번 뒤 다음 회전이 전송하면 연장은 그 회전 한 번이고, 헬퍼 안 2초 뒤입니다
$rlxGhostSkipLine = @{ 'user-active' = '고스트 등록 안내 감지 - 사용자 조작으로 클릭을 건너뜀'; 'cursor-not-ready' = '고스트 등록 안내 감지 - 커서 확인이 안 돼 클릭을 건너뜀' }
foreach ($rlxSkip in @('user-active', 'cursor-not-ready')) {
  Reset-Case -Screen 'unknown' -SendSeq (@($rlxSkip) * 60)
  $script:ghostReal = $true; $script:schedule = @(, @(10, 'ghost'))
  Run-Loop
  $rlxGhost = @($script:ghostResults | Select-Object -Unique) -join ';'
  $rlxGhostLines = Count-Log $rlxGhostSkipLine[$rlxSkip]
  Check-Throw "RLX4c 고스트 $rlxSkip 생략: throw · 연장 줄 0 · end ≈ B" $rlxBase 0
  Check-Equal "RLX4c 고스트 $rlxSkip 생략: 분기 2번 이상 · 전부 메타 거짓 · 사유, 창 전송 0, 시도 수 = 생략 수 = 그 사유 줄 수, Adj ≈ B" "$([int]($script:ghostResults.Count -ge 2))/$rlxGhost/$($script:windowClicks.Count)/$([int]($script:windowSkips.Count -eq $script:ghostResults.Count))/$([int]($rlxGhostLines -eq $script:ghostResults.Count))/$(Near (Adj) $rlxBase)" "1/False|$rlxSkip/0/1/1/True"
  Reset-Case -Screen 'unknown' -SendSeq @($rlxSkip)
  $script:ghostReal = $true; $script:schedule = @(, @(10, 'ghost'))
  Run-Loop
  $rlxT = LastExt
  Check-Throw "RLX4c′ 고스트 $rlxSkip 생략 뒤 전송: throw · end ≈ E(T) · 연장 줄 1" (EndOf $rlxT) 1
  Check-Equal "RLX4c′ 고스트 $rlxSkip 생략 뒤 전송: 생략 회전 메타 거짓 · 그 사유, 전송 회전 메타 참, 창 생략 1, 전송 1, 전송 줄 1, T = 전송 + 헬퍼 안 2초" "$($script:ghostResults -join ';')/$($script:windowSkips.Count)/$($script:windowClicks -join ';')/$(Count-Log "고스트 등록 안내 - '나중에' 클릭")/$(Near $rlxT ($script:windowTimes[0] + 2) 0.5)" "False|$rlxSkip;True|/1/ghost 713,652/1/True"
}
# RLX4d 스텔라 user-active: 양보만큼만 밀리고 카운터 · 로그 · 연장 없음 (양보 뒤 사용자가 닫음)
Reset-Case -Screen 'unknown' -SendSeq @('user-active')
$script:schedule = @(, @(10, 'stella1')); $script:screenAfterYield = 'unknown'
Run-Loop
$rlxStella = Count-Log '복귀 중 스텔라 픽 감지 - 가운데 카드 선택'
Check-Throw 'RLX4d 스텔라 user-active: throw · 연장 줄 0 · end ≈ B + 양보' ($rlxBase + $script:yieldSeconds) 0
Check-Equal 'RLX4d 분기: 생략 1 · 창 전송 0 · 스텔라 로그 줄 0 · 양보 1, Adj ≈ B' "$($script:windowSkips -join ';')/$($script:windowClicks.Count)/$rlxStella/$($script:yieldWaits)/$(Near (Adj) $rlxBase)" 'stella1 user-active/0/0/1/True'
# RLX4e 공지 X 생략 둘 (X8): 메타 거짓이면 건너뜀 줄만
foreach ($rlxSkip in @('user-active', 'cursor-not-ready')) {
  Reset-Case -Screen 'notice' -SendSeq (@($rlxSkip) * 60)
  Run-Loop
  $rlxNoticeSkip = Count-Log '공지 게시판 X 닫기 건너뜀'
  $rlxNoticeSent = Count-Log '공지 게시판 팝업 감지 - X로 닫기'
  Check-Equal "RLX4e 공지 X $rlxSkip 생략: throw, 연장 줄 0, 시도 수 = 건너뜀 줄 수(1 이상), 창 전송 0, 감지 줄 0, 전부 그 사유, Adj ≈ B" "$(ThrewTimeout)/$(ExtLines)/$([int]($script:windowSkips.Count -eq $rlxNoticeSkip))/$([int]($rlxNoticeSkip -ge 1))/$($script:windowClicks.Count)/$rlxNoticeSent/$(@($script:windowSkips | Select-Object -Unique) -join ';')/$(Near (Adj) $rlxBase)" "1/0/1/1/0/0/notice $rlxSkip/True"
}
# RLX4f (X4) X 전송(메타 참) 바로 다음 회전의 주간 팝업 캡처 실패 미룸: 헬퍼는 참이고 메타를 쓰지 않습니다 - 호출 전 비움이 없으면 앞 회전 X 의 참을 읽어 연장됩니다
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 21; Kind = 'deferred' })
Run-Loop
$rlxX = @(LogTimes $rlxXPattern)
Check-Throw 'RLX4f X 전송 뒤 deferred: throw · 연장 줄 0 · end ≈ B' $rlxBase 0
Check-True "RLX4f 분기: deferred 1번(메타 거짓 · Outcome 빈 값), 바로 앞 회전이 X 전송, 캡처 실패 등록 1, Adj ≈ B" (($script:eventResults -join ';') -eq 'deferred|False||' -and $rlxX.Count -ge 1 -and $rlxX[0] -le 21 -and $script:captureFailSerial -eq 1 -and (Near (Adj) $rlxBase)) "(분기 '$($script:eventResults -join ';')', X $($rlxX -join ','), 실패 $($script:captureFailSerial), Adj $(Adj))"
# RLX4f′ (X4) 운영 본문의 캡처 실패 미룸: 위 'deferred' 는 '참 · 메타 불변 · 캡처 실패 등록' 을 모의가 정해 둔 행입니다 - 여기서는 운영 Invoke-EventSkipOrConfirm → Close-WeeklyCoopResetPopup 본문이 그 모양을 스스로 만듭니다.
#        주간 글자는 읽혔고 '닫기' 자리 판독이 실패한 회전입니다. 창이 사라지면 전송이 없어 연장 0, 창이 남으면 복구 뒤 전송 회전 한 번만 연장입니다
foreach ($rlxWeekly in @(@{ Id = '창이 사라짐'; After = 'unknown'; Ext = 0; Results = 'real|True|False||'; Clicks = '' }, @{ Id = '창이 남음'; After = ''; Ext = 1; Results = 'real|True|False||;real|True|True||'; Clicks = 'weekly 495,654' })) {
  Reset-Case -Screen 'unknown'
  $script:eventReal = $true; $script:eventRealHelpers = $true; $script:schedule = @(, @(21, 'weekly'))
  $script:failOnceAt = @{ 'Find-GameTextPoint:닫기' = 1 }; $script:screenOnFailOnce = $rlxWeekly.After
  Run-Loop
  $rlxX = @(LogTimes $rlxXPattern)
  $rlxDefer = @(LogTimes '주간 협동 미션 팝업 감지 - 화면 캡처 실패로 닫기 클릭을 미룸')
  $rlxTrue = @($script:eventResults | Where-Object { $_ -like 'real|True*' })
  Check-Throw "RLX4f′ 운영 본문 - $($rlxWeekly.Id): throw · 연장 줄 $($rlxWeekly.Ext) · end ≈ $(if ($rlxWeekly.Ext) { 'E(T)' } else { 'B' })" $(if ($rlxWeekly.Ext) { EndOf (LastExt) } else { $rlxBase }) $rlxWeekly.Ext
  Check-Equal "RLX4f′ 운영 본문 - $($rlxWeekly.Id): 미룸 회전은 참 · 메타 거짓 · 사유 없음 · Outcome 빈 값, 미룸 줄 1, 창 전송, 캡처 실패 등록 1" "$($rlxTrue -join ';')/$($rlxDefer.Count)/$($script:windowClicks -join ';')/$($script:captureFailSerial)" "$($rlxWeekly.Results)/1/$($rlxWeekly.Clicks)/1"
  Check-True "RLX4f′ 운영 본문 - $($rlxWeekly.Id): 바로 앞 회전이 X 전송 (메타 참이 남아 있는 회전 - 호출 전 비움이 없으면 여기서 연장됩니다)" ($rlxX.Count -ge 1 -and $rlxDefer.Count -eq 1 -and $rlxX[0] -lt $rlxDefer[0] -and (Near $rlxDefer[0] $rlxX[0] 3)) "(X $($rlxX -join ','), 미룸 $($rlxDefer -join ','))"
}
# RLX4g (X5) 이벤트 헬퍼 거짓(Outcome 'user-active') + 다음 회전의 실제 조작: 양보만큼만 밀리고 그 회전 · 양보 중 클릭 0, 양보 뒤 첫 입력은 새 판독 다음입니다
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 10; Kind = 'yield-false' })
$script:eventHook = { if (((Elapsed) -ge 10) -and ($null -eq $script:activeFrom)) { $script:activeFrom = (Elapsed) + 0.1; $script:activeUntil = (Elapsed) + 10 } }
Run-Loop
$rlxYieldFrom = $script:activeFrom - 0.1; $rlxYieldUntil = $script:activeUntil
$rlxFirstRead = @($script:captureTimes | Where-Object { $_ -ge $rlxYieldUntil } | Select-Object -First 1)[0]
$rlxFirstClick = @($script:clickTimes | Where-Object { $_ -ge $rlxYieldUntil } | Select-Object -First 1)[0]
Check-Throw 'RLX4g yield-false + 실제 조작: throw · 연장 줄 0 · end ≈ B + 양보' ($rlxBase + $script:userYieldTotalMs / 1000.0) 0
Check-True "RLX4g 분기: yield-false 1번(Outcome 'user-active'), 양보 1, 그 회전 · 양보 중 클릭 0, 양보 뒤 첫 클릭은 새 판독 뒤, Adj ≈ B" (($script:eventResults -join ';') -eq 'yield-false|False||user-active' -and $script:yieldWaits -eq 1 -and (ClicksIn $rlxYieldFrom $rlxYieldUntil) -eq 0 -and $null -ne $rlxFirstRead -and $null -ne $rlxFirstClick -and $rlxFirstRead -lt $rlxFirstClick -and (Near (Adj) $rlxBase)) "(분기 '$($script:eventResults -join ';')', 양보 $($script:yieldWaits), 창 안 $(ClicksIn $rlxYieldFrom $rlxYieldUntil), 판독 $rlxFirstRead, 클릭 $rlxFirstClick, Adj $(Adj))"
# RLX4h (X3) 운영 본문의 클릭 생략: 위 RLX4a·b 의 모의는 운영 본문을 지나지 않습니다 - 생략 회전이 운영 본문에서도 전송으로 읽히지 않는지 실제 본문으로 봅니다 (모의만이면 코드와 테스트가 같은 가정으로 함께 틀림 - 규칙 9).
#       생략 1번 뒤 다음 회전이 전송합니다 - 연장은 그 회전 한 번입니다. X 후보가 생략 차례를 먼저 쓰지 않게 창은 문턱 전에 띄웁니다. 세 헬퍼는 Outcome 을 받지 않아 메타만 봅니다
foreach ($rlxWin in @(@{ Id = '건너뛰기'; Screen = 'skipBook' }, @{ Id = '협동 X'; Screen = 'coopBoard' }, @{ Id = '네트워크'; Screen = 'network' }, @{ Id = "주간 '닫기'"; Screen = 'weekly' })) {
  foreach ($rlxSkip in @('user-active', 'cursor-not-ready')) {
    Reset-Case -Screen 'unknown' -SendSeq @($rlxSkip)
    $script:eventReal = $true; $script:eventRealHelpers = $true; $script:schedule = @(, @(10, $rlxWin.Screen))
    Run-Loop
    $rlxT = LastExt
    $rlxTrue = @($script:eventResults | Where-Object { $_ -like 'real|True*' })
    Check-Throw "RLX4h 운영 본문 - $($rlxWin.Id) $rlxSkip 생략 뒤 전송: throw · end ≈ E(T) · 연장 줄 1" (EndOf $rlxT) 1
    Check-Equal "RLX4h 운영 본문 - $($rlxWin.Id) $rlxSkip 생략 뒤 전송: 생략 회전은 메타 거짓 · 그 사유 · Outcome 빈 값, 전송 회전은 메타 참, 창 생략 1 · 전송 1" "$($rlxTrue -join ';')/$($script:windowSkips.Count)/$($script:windowClicks.Count)" "real|True|False|$rlxSkip|;real|True|True||/1/1"
  }
}

# RLX5 캡처 실패와 연장 (규칙 15): 연장은 전송 회전에서만이고 동결 회전에는 전송이 없습니다. 같은 기준값이라 이중 가산이 없습니다
# RLX5a 전송 예정 30초 · 실패 [30,50): 실패 창 안 클릭 0, 복구 뒤 1회
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 30; Kind = 'click' }); $script:capfailFrom = 30; $script:capfailUntil = 50
Run-Loop
$rlxT = LastExt
Check-Throw 'RLX5a 전송 예정 시각에 캡처 실패: throw · 연장 줄 1 · end ≈ T + B' ($rlxT + $rlxBase) 1
Check-True 'RLX5a 실패 창 안 클릭 0, 복구 뒤 전송 1회 (T ≥ 50)' ((ClicksIn 30 50) -eq 0 -and $script:eventResults.Count -eq 1 -and $rlxT -ge 50) "(창 안 $(ClicksIn 30 50), 전송 $($script:eventResults.Count), T $rlxT)"
# RLX5b 32초쯤 연장 · 실패 [35,55): 연장 뒤 실패 시간은 마감에 한 번만 더해집니다
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 30; Kind = 'click' }); $script:capfailFrom = 35; $script:capfailUntil = 55
Run-Loop
$rlxT = LastExt
Check-Throw 'RLX5b 32초쯤 연장 · 실패 [35,55): throw · end ≈ T + B + 20 · 연장 줄 1' ($rlxT + $rlxBase + 20) 1
Check-True 'RLX5b Adj ≈ T + B, T ≈ 32초' ((Near (Adj) ($rlxT + $rlxBase)) -and (Near $rlxT 32)) "(Adj $(Adj), T $rlxT)"
# RLX5c 끊김 없는 실패 + 안전 중지: 지금처럼 F9 경로(코드 4 센티널) - 새 출구가 실패 중에 닿지 않습니다
Reset-Case -Screen 'unknown'
$script:capfailFrom = 0; $script:capfailUntil = 100000; $script:f9After = 120; $script:safeStopFlag = $true
Run-Loop
Check-Equal 'RLX5c 끊김 없는 실패 + 안전 중지: F9 센티널, 코드 없음, 소비 0, 진단 0, 새 줄 0' "$($script:threw)/$($script:exitCode)/$($script:flagRemoved)/$($script:diagFull.Count)/$(NewDoneLines)" '__F9__//0/0/0'
# RLX5d 마감을 넘는 실패 창 [50,200) + 안전 중지: 실패 중 exit 0, 복구 뒤 조정 마감(60 + 150)에서만 판정합니다
Reset-Case -Screen 'unknown'
$script:capfailFrom = 50; $script:capfailUntil = 200; $script:safeStopFlag = $true
Run-Loop
Check-M1 'RLX5d 마감 넘는 실패 창 + 안전 중지: M1 결말'
Check-True 'RLX5d 복구 뒤 조정 마감에서만 판정: exit 시각 ≥ 200 · ≈ B + 150, Adj ≈ B' ($script:exitAt -ge 200 -and (Near $script:exitAt ($rlxBase + 150)) -and (Near (Adj) $rlxBase)) "(exit $($script:exitAt), Adj $(Adj))"
# RLX5e 같은 회전 느린 실패 10초 + 전송: 연장 앞 조정이 캡처 실패까지 봐야 합니다 (양보 조정만이면 그 10초가 남은 시간에서 빠져 end 가 +10)
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 0; Kind = 'click' }); $script:failOnceAt = @{ 'Test-HomeEndEscHud' = 1 }; $script:failOnceSlowMs = 10000
Run-Loop
$rlxT = LastExt
Check-Throw 'RLX5e 같은 회전 느린 실패 10초 + click: throw · end ≈ T + B · 연장 줄 1' ($rlxT + $rlxBase) 1
Check-True 'RLX5e T ≈ 12초, 실패 누적 10초, Adj ≈ T + B − 10' ((Near $rlxT 12) -and (Near ($script:failTotalMs / 1000.0) 10 0.1) -and (Near (Adj) ($rlxT + $rlxBase - 10))) "(T $rlxT, 실패 $($script:failTotalMs), Adj $(Adj))"

# RLX6a 11-03 재생 (로그 순서를 모의로 옮긴 것 - 그림 재현이 아님): 안전 중지 · 조작 [3,39) · 59초 click(출석부 건너뛰기) · 61초 Space(출석 완료) · 뒤 알 수 없음.
#       코드 0 · 소비 · 새 줄은 연장을 빼도 참이므로 연장이 지키는 것은 연장 줄 2 · end ≈ T + B 이고 출구가 지키는 것은 코드 0 입니다 (변이 V-EXT · V-EXIT)
Reset-Case -Screen 'unknown'
$script:safeStopFlag = $true; $script:activeFrom = 3; $script:activeUntil = 39
$script:eventPlan = @(@{ At = 59; Kind = 'click' }, @{ At = 61; Kind = 'space' })
Run-Loop
$rlxT = LastExt
$rlxHudLines = Count-Log '던전 밖\(HUD\)'
$rlxXOrder = @(XPoints | Select-Object -First 3) -join ' → '
Check-M1 'RLX6a 11-03 재생: 코드 0 · 소비 1 · 진단 1(문맥 · -CaptureOnly · -WithLogCopy) · 새 줄 1 · throw 없음'
Check-Equal "RLX6a 11-03 재생: '던전 밖(HUD)' 줄 0, X 첫 셋 순서, 연장 줄 2, end ≈ T + B, 분기 순서" "$rlxHudLines/$rlxXOrder/$(ExtLines)/$(Near $script:endAt ($rlxT + $rlxBase))/$($script:eventResults -join ';')" '0/1229,67 → 1090,137 → 959,180/2/True/click|True||;space|False||sent'
# RLX6b 연장 없는 일반 만료 + 안전 중지 (U-R-6): 3분을 채우지 않고 마감이 끝나는 때입니다
Reset-Case -Screen 'unknown'
$script:safeStopFlag = $true
Run-Loop
Check-M1 'RLX6b 일반 만료 + 안전 중지: M1 결말'
Check-True 'RLX6b end ≈ B, 연장 줄 0' ((Near $script:endAt $rlxBase) -and (ExtLines) -eq 0) "(end $($script:endAt), 연장 줄 $(ExtLines))"
# RLX6c 상한까지 + 안전 중지
Reset-Case -Screen 'unknown'
$script:eventEvery = 'click'; $script:safeStopFlag = $true
Run-Loop
Check-M1 'RLX6c 매 회전 click + 안전 중지: M1 결말'
Check-True 'RLX6c end ≈ C' (Near $script:endAt $rlxLimit) "(end $($script:endAt))"
# RLX6d 호출부 코드 · 갈래: 코드 10 = 준비/정리 갈래 · 그 밖 = 일반 갈래 · 코드 10 이 아닌 'left' = 거점 퇴장 갈래 · 코드 10 이 먼저 (열쇠 항목은 어느 갈래도 닫지 않음 - 던전 밖 확정 출구 전용)
Reset-Case -Screen 'unknown'
$script:safeStopFlag = $true
Run-Loop -SafeStopExitCode 10
Check-M1 'RLX6d 코드 10: 코드 10 · 준비/정리 갈래' 10 $rlxDoneReady
Reset-Case -Screen 'unknown'
$script:safeStopFlag = $true
Run-Loop -SafeStopExitCode 4
Check-M1 'RLX6d 코드 4: 코드 4 · 그 밖 갈래' 4 $rlxDoneElse
Reset-Case -Screen 'unknown'
$script:safeStopFlag = $true
Run-Loop -SafeStopExitCode 4 -LeaveEntryReason 'abandoned-death-exit'
Check-M1 "RLX6d 코드 4 + 'left': 코드 4 · 거점 퇴장 갈래 · 열쇠 닫기 0" 4 $rlxDoneLeft
Reset-Case -Screen 'unknown'
$script:safeStopFlag = $true
Run-Loop -SafeStopExitCode 10 -LeaveEntryReason 'abandoned-death-exit'
Check-M1 "RLX6d 코드 10 + 'left': 코드 10 · 준비/정리 갈래가 먼저 · 열쇠 닫기 0" 10 $rlxDoneReady
# RLX6e 재매칭 패널 + 안전 중지: 패널 분기의 break 도 while 뒤 한 자리가 받습니다 (누르는 것 0)
Reset-Case -Screen 'panel'
$script:safeStopFlag = $true
Run-Loop
Check-M1 'RLX6e 재매칭 패널 + 안전 중지: M1 결말'
Check-True 'RLX6e end ≈ B, 클릭 · 키 0' ((Near $script:endAt $rlxBase) -and (AllInput) -eq 0) "(end $($script:endAt), 입력 $(AllInput))"
# RLX6g RL1 · RL5 배치 + 안전 중지: 복구 회전 · 표식 회전의 break 도 같습니다 (캡처 실패 시간을 뺀 Adj 로 봄)
foreach ($rlxScreen in @('field', 'readyPanel')) {
  Reset-Case -Screen $rlxScreen
  $script:planActive = $true; $script:plan = @{ 'Get-AbyssPanelKind' = 'fail' }; $script:safeStopFlag = $true
  Run-Loop
  Check-M1 "RLX6g RL1($rlxScreen) 같은 회전 복구 영구 + 안전 중지: M1 결말"
  Check-True "RLX6g RL1($rlxScreen) Adj ≈ B, 클릭 · 키 0" ((Near (Adj) $rlxBase) -and (AllInput) -eq 0) "(Adj $(Adj), 입력 $(AllInput))"
}
Reset-Case -Screen 'unknown'
$script:planActive = $true; $script:plan = @{ 'Test-AbyssEntryWaiting' = 'failPersist' }; $script:planSlowMs = 1000; $script:safeStopFlag = $true
Run-Loop
Check-M1 'RLX6g RL5 교대 모양 + 안전 중지: M1 결말'
Check-True 'RLX6g RL5 Adj ≈ B, 클릭 · 키 0, 안전 확인 1 이상' ((Near (Adj) $rlxBase) -and (AllInput) -eq 0 -and $script:safeStopCalls -ge 1) "(Adj $(Adj), 입력 $(AllInput), 안전 확인 $($script:safeStopCalls))"
# RLX6f 헬퍼 'expired' + 안전 중지: 기본 모의는 즉시 'expired' 라 end 를 보지 않습니다. 운영 헬퍼 배치(RL3 (a))는 헬퍼 안 복구 회전이 부모 마감에 닿습니다
Reset-Case -Screen 'reward'
$script:helperResult = 'expired'; $script:safeStopFlag = $true
Run-Loop
Check-M1 "RLX6f 헬퍼 'expired'(기본 모의) + 안전 중지: M1 결말"
Reset-Case -Screen 'reward'
function Invoke-AbyssExitClick { param($Game, $LogPrefix, $Context, $ParentDeadline = $null)
  $script:helperCalls++; $script:helperParent = $ParentDeadline
  return (Invoke-AbyssExitClickReal -Game $Game -LogPrefix $LogPrefix -Context $Context -ParentDeadline $ParentDeadline)
}
$script:rl3FailName = 'Test-AbyssSelectionScreen'; $script:safeStopFlag = $true
Run-Loop
Invoke-Expression $mockHelperDef   # 모의 헬퍼 되살림
Check-M1 "RLX6f 헬퍼 'expired'(운영 헬퍼 RL3 배치) + 안전 중지: M1 결말"
Check-True 'RLX6f 운영 헬퍼: 헬퍼 호출 1, 클릭 · 키 0' ($script:helperCalls -eq 1 -and (AllInput) -eq 0) "(헬퍼 $($script:helperCalls), 입력 $(AllInput))"
# RLX6h 코드 4 출구 셋은 그대로 (M3): 소비 0, 복귀 마감 진단 문맥 0, 새 줄 0 (재시작 없이 GUI 가 신호를 지움)
foreach ($rlxKeep in @(@{ Screen = 'readyPanel'; Context = '어비스 복귀 중 준비 패널 지속' }, @{ Screen = 'entryWaiting'; Context = '어비스 복귀 중 준비 패널 지속' }, @{ Screen = 'selection'; Context = '어비스 복귀 중 출처 없는 선택 화면' })) {
  Reset-Case -Screen $rlxKeep.Screen
  $script:safeStopFlag = $true
  Run-Loop
  Check-Equal "RLX6h $($rlxKeep.Screen) + 안전 중지: 코드 4, 소비 0, 진단 문맥 · 스위치 그대로, 새 줄 0, throw 없음" "$($script:exitCode)/$($script:flagRemoved)/$($script:diagFull -join ';')/$(NewDoneLines)/$($script:threw)" "4/0/$($rlxKeep.Context)|True|False/0/"
}
# RLX6i (Q-R-11 고정) RLP8(d) 배치를 뒤로 민 것: 패널 ~45초 · 로딩 · 오독 49초 · 던전 안 52.5초 + 안전 중지 - 던전 안 표본이 쌓이는 중 마감이 먼저 끝나 M1 입니다 (던전 안 코드 4 는 첫 확인부터 20초).
#       판독 시각 계산: 패널 2초 주기로 46초 로딩 · 0.7초 주기로 49.5초 오독 · 53.0초 던전 안 첫 표본 뒤 2초 주기 53 · 55 · 57 · 59 = 표본 4, 61초 회전은 일반 만료 판정이 HUD 판독보다 앞이라 판독 없이 끝납니다
Reset-Case -Screen 'panel'
$script:schedule = @(@(45, 'loading'), @(49, 'fieldMisread'), @(52.5, 'inside'))
$script:safeStopFlag = $true
Run-Loop
$rlxInsideReads = @(for ($i = 0; $i -lt $script:readNames.Count; $i++) { if ($script:readNames[$i] -eq 'Test-InDungeonQuest' -and $script:captureTimes[$i] -ge 52.5) { $script:captureTimes[$i] } })
$rlxInsideStop = Count-Log '던전 안 상태\(HUD \+ 던전 목표\)를 확인해'
Check-M1 'RLX6i 던전 안 표본이 쌓이는 중 만료 + 안전 중지: M1 결말 (호출부 코드 · 진단 문맥 · 두 스위치 · 소비 1 · 새 줄 1)'
Check-Equal 'RLX6i end ≈ B, 던전 안 판독 표본 4, 던전 안 코드 4 줄 0, ESC · 어비스 0' "$(Near $script:endAt $rlxBase)/$($rlxInsideReads.Count)/$rlxInsideStop/$($script:escClicksSent)/$($script:abyssClicksSent)" 'True/4/0/0/0'

# RLX7a·b 안전 중지 없음 (U-R-5): 지금처럼 코드 1 쪽 throw 입니다 (문구 · 오류 세트 그대로) - 상한까지 늦어질 뿐
Reset-Case -Screen 'unknown'
Run-Loop
Check-Throw 'RLX7a 일반 만료 · 안전 중지 없음: throw 1 · 코드 없음 · 소비 0 · 새 줄 0 · 복귀 마감 진단 0' $rlxBase 0
Check-Equal 'RLX7a throw 문구 그대로, 진단 0' "$($script:threw)/$($script:diagCalls)" '어비스 선택 화면 복귀 대기 시간이 초과됐습니다./0'
Reset-Case -Screen 'unknown'
$script:eventEvery = 'click'
Run-Loop
Check-Throw 'RLX7b 상한 도달 · 안전 중지 없음: throw 1 · 코드 없음 · 소비 0 · 새 줄 0 · 복귀 마감 진단 0' $rlxLimit -1
Check-Equal 'RLX7b throw 문구 그대로, 진단 0' "$($script:threw)/$($script:diagCalls)" '어비스 선택 화면 복귀 대기 시간이 초과됐습니다./0'

# RLX8 신호는 while 뒤에서 읽습니다: 연장 중에 누른 F9 도 받고 도중에 취소한 F9 는 안 받습니다
Reset-Case -Screen 'unknown'
$script:flagSchedule = @(, @(30, $true))
Run-Loop
Check-M1 'RLX8a 30초에 안전 중지 ON: M1 결말'
Check-True 'RLX8a end ≈ B' (Near $script:endAt $rlxBase) "(end $($script:endAt))"
Reset-Case -Screen 'unknown'
$script:flagSchedule = @(, @(59.5, $true))
Run-Loop
Check-M1 'RLX8b 만료 직전 안전 중지 ON: M1 결말'
Check-True 'RLX8b end ≈ B' (Near $script:endAt $rlxBase) "(end $($script:endAt))"
Reset-Case -Screen 'unknown'
$script:flagSchedule = @(@(10, $true), @(40, $false))
Run-Loop
Check-Throw 'RLX8c 10초 ON → 40초 OFF: throw · 소비 0 · 새 줄 0' $rlxBase 0
Reset-Case -Screen 'unknown'
$script:eventPlan = @(@{ At = 30; Kind = 'click' }); $script:flagSchedule = @(, @(70, $true))
Run-Loop
$rlxT = LastExt
Check-M1 'RLX8d 연장 뒤 안전 중지 ON: M1 결말'
Check-True 'RLX8d 만료 시각 E(T), 연장 줄 1' ((Near $script:endAt (EndOf $rlxT)) -and (ExtLines) -eq 1) "(end $($script:endAt), T $rlxT)"
Reset-Case -Screen 'unknown'
$script:flagSchedule = @(, @(30, $true)); $script:schedule = @(, @(35, 'field'))
Run-Loop
$rlxFieldDone = CountLine '[완료] 안전 중지 예약 확인 - 던전 밖(HUD) 확인 시점에서 회차를 마칩니다'
Check-Equal 'RLX8e 30초 ON 뒤 필드: 기존 W 출구 - 코드 0, 소비 1, 기존 줄 1, 새 줄 0, 진단 0, throw 없음' "$($script:exitCode)/$($script:flagRemoved)/$rlxFieldDone/$(NewDoneLines)/$($script:diagFull.Count)/$($script:threw)" '0/1/1/0/0/'
Check-True 'RLX8e 소비는 필드 표본부터 W 뒤' ($script:exitAt -ge (35 + $memberFieldSettleSeconds)) "(소비 $($script:exitAt))"

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
