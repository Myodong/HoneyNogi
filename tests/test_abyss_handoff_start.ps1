# 어비스 이어받기 시작 경로 회귀 ⑱′ - 구현 명세 ② 2.1·3.2 (2026-10-12 신설 - 단계 2.4~2.6 이 아래 '뒤 단계 자리' 에 행을 더합니다)
#
# 지키는 것 (단계 2.1 - 워커 상태 · Consume-Handoff. 명세 ② 2.1 표 ①~⑬ · 0.6 J1~J3·J12~J14 · 5절 A-2 R-7 · C15 · 설계 v10 dev:587·590~595):
#   [CH] 실제 Consume-Handoff(워커 원문 - 저장소 묶음 끝 표지 뒤 워커 전용 구역)를 임시 폴더의 실제 완료 기록 파일과 실제 저장소(워커 사본)로 돌립니다.
#        RECOVERY=1 은 읽기 0 · [안내] 1줄(CH1 - J13·J14) / 그 밖은 nonce 유무와 무관하게 1회 읽기(J1 · R-7): 사용 중(locked)·읽기 실패(io-failed) =
#        누르기 전 코드 4 ' (locked)'(CH3·CH3′·CH4 - 본류 시작 구간 층) · 손상 = Role none · JournalState corrupt · [경고] 1(CH5 · J2) · 항목 없음·done
#        (CH6·CH7) · 모드 불일치 [경고](CH8·CH9) · own(CH10·CH11 - 정리 전용 표지 · 키 인덱스 시작값 · cleanupOnly 없는 옛 항목) · stale 3종(CH12) ·
#        next(applied 무관 - CH13) · resume(applied 밖만 - CH14) · 커스텀 소유자 JSON 해석 실패(CH15) · 던전·심층·사냥터 = 호출 0 · 기본값 Role none ·
#        $roleNone 참(CH16 - 본류 시작 구간 층). 공통: 반환 'ok'/'stop' 하나 · Role none 의 Nonce 는 빈 값(받은 env nonce 는 판정에만 - 설계 R2 3.3 ⑥) ·
#        쓰기 0(저장 호출 0 · 파일 불변 - 명세 2.1 'Consume-Handoff … 쓰기 0').
#   [CH 짝] 표에서 바로 나오는 짝 행(이름 끝 ′·w·f): 저장소 경고를 그대로 한 줄씩(CH2w - 표 ②) · nonce 없는 RECOVERY 도 안내 1(CH1′ - J13) · 손상은 nonce 가
#        없어도 corrupt(CH5′ - 설계 R2 E5(a)) · done 판정이 모드 불일치보다 앞(CH7′ - 표 ⑧ < ⑨) · FINISH_ONLY 는 역할 판정에 쓰지 않음(CH13f) · nonce 가
#        비면 소유자 해석 0(CH15′ - C15 · 표 ⑥ < ⑦) · stale 의 대조(일치하면 own - 표 ⑪) · 어비스는 호출 1 · customSpecInvalid 면 0(CH16 대조).
#   [CH 보강] 단계 2.1 변이 검증(2026-10-13)에서 살아남은 변이를 잡는 행 - 표 ⑬ 의 나머지 갈래: next 의 nextOwner 불일치(5필드·세대 - CH12n) · resume 의
#        owner 불일치(5필드·세대 - CH12r) · 다른 stage(cleared 의 owner 일치 / nextOwner 일치 - CH12s) · 열쇠 항목의 키 시작값은 afterEntry.index 그대로
#        (CH10i - total 아님) · own·next·resume 뒤 FreshEntry·StartScreen 은 기본값 그대로(CH10s·CH13s·CH14s - 두 필드는 선분기 몫) · 손상은 소유자 해석보다
#        앞(CH5″ - 표 ⑤ < ⑦) · 소유자 해석은 항목 찾기보다 앞(CH15″ - 표 ⑦ < ⑧) · 본류 시작 구간이 own 역할을 그대로 넘김($roleNone 거짓 - CH16o).
#        살아남았던 변이: 순서 ⑦↔⑧ · own/next 의 stage 조건 제거 · next 의 nextOwner 대조 제거 · resume 의 owner 대조 제거 · own 이 FreshEntry 를 씀 · 키
#        시작값을 total 로 · 손상 뒤 반환 없음 · 블록이 Consume-Handoff 뒤 역할을 none 으로 덮어씀.
#   [CH 보강 2] 단계 2.1 검증 지적(2026-10-13): 세대 출처 = 소유자 JSON(명세 ② J3) - 세대 env(HONEYNOGI_CUSTOM_GENERATION)를 JSON 과 어긋나게 둬도
#        역할은 JSON 세대대로(CH10g. 그 env 를 비운 행만으로는 '세대를 env 에서 읽음' 변이가 env 가 빌 때만 잡혔음). 하니스는 행마다 그 env 를 지우고
#        (행이 값을 줄 때만 둠) 끝에 되돌립니다.
#   [L]  기동 → 역할(설계 v11 R4 5.6 L1·L2·L3·L6·L7 - 이 파일 행 이름 R4-L*): GUI 원문의 기동 env 함수(Set-HandoffLaunchEnv - 안에서 GUI 원문
#        Resolve-HandoffEnvForContext 가 후보를 고르고 launched 를 적음)가 만든 env → 워커 원문의 env 읽기 문장 → 실제 Consume-Handoff.
#        L4a~L4c·L5 는 ⑯ test_abyss_handoff_gui 의 (GUI 틱) 몫입니다(명세 ② 3.2).
#   [P]  정적(주석 뺀 사본 · AST - 명세 ② 3.2 정적 표): R4-P1(2.1 블록 자리 = 파티원 디스패치 if 뒤 · 이벤트 정리 if 앞 · 조건에 -not customSpecInvalid) ·
#        R4-P13(기본값 통째 대입 = 워커 전체 1곳(함수 안 포함 - 단계 2.1 검증 지적) · 스크립트 최상위 · 호출보다 앞 / $roleNone 대입 1곳 - 블록 밖·뒤 ·
#        이벤트 정리 if 앞) · P21(호출 = 2.1 블록 1곳 · 조건 원문 · 첫 문장 · 블록 안 UNTIL 대입 0). 기본값·finishOnly·$roleNone 대입은 문장을 실제로
#        돌려 명세 2.1 표의 값도 봅니다.
# 지키는 것 (단계 2.4~2.6 - 명세 ② 2.4·2.5·2.6 · 3.2 행 표 · 설계 v11 R4 3절·4.3~4.5·5.0~5.3 · 명세 5절 A-2 R-1~R-3):
#   [K]  분류 순위 - 실제 Resolve-AbyssHandoffStartScreen(순수)에 인접 순위 두 신호가 함께 참인 판독값(R4-K2~K12 · K13~K13″)과 순위 표의 단독 신호(K0)를
#        넣습니다. 판독문은 보관 프레임 재생값(test_abyss_party_member §1(a) 와 같은 문자열). 매개변수 이름은 명세가 정하지 않아(제안) 이름의 뜻으로
#        대응하고, 대응하지 못하면 FAIL 입니다(조용히 통과하지 않게). R4-K1(스윕 참 회전은 판독·분류 0)은 루프 행.
#   [F]  필드 확정 - 실제 Step-AbyssFieldSettle(명세 2.4 의 이름 -State -IsFieldSample -TurnStart -SettleSeconds)을 표본 순서대로(R4-F1~F6 · F8 W 범위).
#        R4-F7(같은 회전 선택 화면)은 분류가 끼어 루프 행으로 돕니다.
#   [FL·N·O·RS0·EV1·V18] 층 ① = 본류 형제 문장 '2.1 블록 ~ $roleNone 대입'(실제 Consume-Handoff → 실제 선분기 Invoke-AbyssHandoffStart) / 층 ② = '2.1 블록 ~
#        run:18527 의 $startInsideDetected if 앞' (결론 대입·run:18244 가드·run:18382 인자·run:18409 메뉴 갈래·own 시작 분기 cleared). 화면은 판독 스텁이
#        가상 시각의 시각표(또는 판독 회전 순환)로 답하고, 가상 시계(Get-Date·Start-Sleep 덮기 - test_abyss_return_loop 방식)에 양보·캡처 실패·스윕 참·
#        판독 도중 실패(일련번호 변화)를 시각 창으로 주입합니다(test_abyss_party_member 방식). 선분기 단계와 본류 단계의 판독 수는 선분기 반환 직후
#        스냅숏으로 가릅니다(명세 3.2 층 ② - '(본류) 판독 … 0' 은 스냅숏 뒤 증가분). 문구는 명세 2.5 의 S1~S20 글자 그대로, 회전 박자(700ms)에 기대는
#        숫자(계측 줄의 표본 수·초)는 하니스가 기록한 판독 회전에서 다시 셉니다.
#   [LG·P] 정지 문구(주석 뺀 사본의 문자열) · 정적 R4-P2~P12·P14~P18 · P19·P20·P22 (P10·P19 의 이벤트 정리 문장은 원문에도).
#   하니스 단언: Role≠none 의 층 ② 행은 전부 run:18527 앞에서 exit 하거나 $startInsideDetected 참으로 나옵니다(카드 클릭 도달 불가 - R4 4.3).
#   (GUI 틱) 결과(N3·N6·N9′·N12·O3·O4‴·O4⁗·O10~O12·O17 의 GUI 부분)는 ⑯ test_abyss_handoff_gui 의 타이머 틱 하니스 몫입니다(명세 5절 B16) - 이 파일은
#   그 입력이 되는 워커 쪽 결과(사유 문구·exit·journal 파일)까지입니다. 키 합계(Space·B)는 ⑳ 몫이라 여기서는 열쇠 항목·인덱스 시작값까지(명세 3.2 O 행).
#   [보강 2.5] 단계 2.4~2.6 변이 검증(2026-10-13)에서 살아남은 변이를 잡는 행 - 명세 ② 2.5 회전 골격(5절 A-2 R-1)과 2.0-2 의 규칙 4·15 문장 중 행이 없던
#        자리: 스윕 참 회전 = 던전 안 연속 0(R4-N15s - Q-R4-16) · 판독 도중 실패 회전 = 연속 유지(R4-N14r) · 회전 서두 게이트가 못 보는 간접 양보(스윕의
#        커서 대피 양보 - 스윕 거짓) = 연속 0(R4-N15i - 골격 ⑥) · 스윕 클릭의 조작 생략(user-active · 위임 길 - 다음 회전 게이트가 양보)은 굶김 예산 미소모 ·
#        생략 회전에서 마감 확정 0(R4-N16u - 규칙 4) · 스윕 참 연속이 마감을 넘기면 굶김 회전이 마감을 확정 · 굶김 회전 판독 0(R4-N16s - 골격 ④) · 판독마다
#        실패하고 탐침은 복구하는 교대 모양에서 탐침 복구 뒤 회전이 마감을 확정(R4-N6r - 골격 ③) · 앞 분류가 양성이면 선택 화면·메뉴·상세 판독 0(R4-K1o -
#        골격 ⑤) · 회전 서두의 클릭 생략 사유 비움(R4-P12s - 정적, 규칙 4) · Role none × ESC 메뉴 시작은 HEAD 그대로(V18 - 정적
#        P14 만 지키던 Role none 항). 살아남았던 변이: 스윕 참 회전의 연속 비움 제거 · 복구 회전이 연속을 비움 · 골격 ⑥ 제거 · 스윕 생략 사유를 넘기지 않음 ·
#        'yield' 를 continue 집합에서 뺌 · 굶김 한도 무한 · 굶김 회전도 판독 · 탐침 복구 뒤 회전이 판독 · 세 신호를 늘 판독 · 서두 비움 제거 · 메뉴 갈래의
#        Role none 항 제거. 스텁 엔진에 시각 창 셋을 더했습니다 - SweepSkip(스윕이 '닫기' 를 조작으로 생략 · 참) · SweepYield(커서 대피 양보 · 스윕 거짓) ·
#        ReadFail(판독만 실패 · 복구 탐침은 성공)
#   [보강 2.6 검증] 단계 2.4~2.6 검증 지적(2026-10-13)의 두 구멍: ① 이벤트 정리 모의가 본류에서 늘 거짓이라 run:18222 재판독의 Role none 가드를 지워도
#        '(본류) 판독 run:18222 0' 이 늘 참(정적 R4-P4 만 지킴) → 시나리오 키 MainOverlay(본류 정리 참 · 정리 뒤 시각표)와 R4-N1e·O1e(Role≠none - 재판독 0) ·
#        V18 정리 뒤 3버튼(Role none - HEAD 그대로 재판독이 보상 분기를 엶) ② R4-P14 가 메뉴 갈래의 앞뒤 두 조각만 봐 복구 회차의 exit 0 을 지운 변이가
#        살아남음 → 갈래 문장 목록 전체 = HEAD 원문 다섯 · V18 복구 메뉴(RECOVERY=1·RESTART=1 × ESC 메뉴 → exit 0)
# 방법:
#   - 하니스 세 층(명세 ② 3.2): ① 함수 층 - Consume-Handoff 와 그 의존(저장소 워커 사본 묶음 · 소유자 해석 · 그 밖에 부르는 워커 최상위 함수)을 이 파일
#     최상위에서 정의(체크리스트 6 - 클로저 mutator 가 부르는 함수는 최상위 정의만 보임) ② 본류 시작 구간 - 워커 최상위 try 의 형제 문장(이 단계 = 2.1 블록 ~
#     $roleNone 대입. 2.5·2.6 이 run:18527 '$startInsideDetected' if 앞까지 넓힘)을 AST 로 잘라 행 함수 범위에 점소싱 ③ GUI 틱은 ⑯ 에 둡니다(명세 5절 B16).
#   - 같은 프로세스에서 돌리는 추출 함수·구간은 exit 토큰을 뒤에서부터 Stop-WorkerTailExit('WORKER-EXIT:N' 예외 - ⑯ :597~601 과 같은 모양)로 바꾸고
#     '원본 Exit 토큰 수 = 원본 ExitStatementAst 수 = 치환 수 · 치환 뒤 0' 을 동작 행보다 먼저 단언합니다(명세 ② 2.0-8 · J8).
#   - 역할은 주입하지 않습니다(설계 dev:970) - 실제 journal 파일 + 실제 Consume-Handoff. 사용 중은 같은 프로세스가 .lock 을 쥐어, 읽기 실패는 .lock 자리에
#     폴더를 둬(저장소 Open-AbyssJournalLock 의 접근 거부 = io-failed 갈래 - test_abyss_journal_store X5 와 같은 상태) 만듭니다.
#   - Consume-Handoff · Read-AbyssJournal · Update-AbyssJournal · Resolve-HandoffEnvForContext 는 실제 함수를 다른 이름으로 한 번 더 정의하고 같은 이름은
#     호출 수만 세고 넘기는 얇은 감시로 가립니다(⑯ 와 같은 방식 - 모의·감시는 실제 서명과 대조). 저장소 재시도 대기(Start-Sleep)는 횟수 예산이라 자지 않고 셉니다.
#   - 문구는 명세 ② 2.1 표의 글자 그대로입니다('제안' 표시 문구는 구현이 바꾸면 이 상수도 함께 - 명세 머리말). 소스에서 캡처하는 것: 저장소·워커·GUI 함수 원문 ·
#     기본값·finishOnly·$roleNone 대입과 워커 env 읽기 문장(그대로 점소싱) · 표 ② 의 저장소 경고(감시가 받은 Warnings 그대로).
#   - 큰 소스의 주석 뺀 사본은 토큰으로 한 번에 만듭니다(Remove-SourceComments 와 같은 규칙 - 주석을 같은 길이 공백으로, 위치·줄 구조 그대로).
# 다른 파일이 지키는 것: Consume-Handoff 의 자리·모양(워커 1 · 표지 뒤 · GUI 0 · exit 0 · try 0 · 잠금 읽기 1 · 저장 0) = test_abyss_journal_store W-ONLY.
using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing   # GUI 기동 env 함수의 정지 갈래가 상태줄 색을 씁니다 - L 행이 그 갈래로 새면 예외가 아니라 FAIL 로 보이게
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$UTF8_BOM = New-Object System.Text.UTF8Encoding($true)

# ===== 상수 =====
$BUNDLE_HEADER_FRAGMENT = '어비스 완료 기록(handoff journal) 저장소'   # 저장소 묶음 머리 주석 (test_abyss_journal_store 와 같은 경계)
$BUNDLE_END_FRAGMENT = '어비스 완료 기록 저장소 묶음 끝'                 # 저장소 묶음 끝 표지 주석
$WORKER_EXIT_PREFIX = 'WORKER-EXIT:'                                     # 종료 흉내 예외 접두 (⑯ Stop-WorkerTailExit 와 같은 모양 - 명세 ② 2.0-8)
# 이 파일이 워커에서 꺼내 돌리는 함수. 이 함수들(과 본류 시작 구간 층 ②)이 부르는 다른 워커 최상위 함수는 아래 의존 추출이 따라 붙입니다
$WORKER_FUNCTION_NAMES = @('ConvertTo-AbyssJournalOwner', 'Consume-Handoff',
    # 단계 2.4~2.6 (명세 ② 5절 B1 이름) - 순수 함수 둘 · 선분기 · 정지 함수 · own 닫기 · 자기 항목 생성 · 키 인덱스 기록(O4″ 의 '키 뒤' 모양) ·
    # 본류가 부르는 클리어 기록·정리 전용 술어 · K 행과 판독 스텁이 같은 판독문으로 다시 계산하는 서명 판정 셋(3버튼·권장 인원 팝업·접힌 패널)
    'Resolve-AbyssHandoffStartScreen', 'Step-AbyssFieldSettle', 'Invoke-AbyssHandoffStart', 'Stop-AbyssHandoffOverlay',
    'Close-AbyssOwnEntryBeforeEntry', 'Add-AbyssJournalEnteredEntry', 'Set-AbyssAfterEntryIndex', 'Add-AbyssJournalClearedEntry',
    'Test-CustomCleanupOnly', 'Test-AbyssRewardText', 'Test-AbyssFewMembersPopupText', 'Test-AbyssEntryWaitingText')
# 감시가 넘길 실제 함수 이름 - 같은 이름은 아래 감시가 차지합니다(호출 수·인자를 적고 실제 함수로 넘김)
$WORKER_SPY_RENAMES = @{
    'Consume-Handoff'                 = 'Invoke-RealConsumeHandoff'
    'Invoke-AbyssHandoffStart'        = 'Invoke-RealAbyssHandoffStart'                 # 반환 직후 판독 계수 스냅숏(명세 3.2 층 ②)
    'Resolve-AbyssHandoffStartScreen' = 'Invoke-RealResolveAbyssHandoffStartScreen'    # 회전마다 분류 호출 기록(R4-K1)
    'Test-CustomCleanupOnly'          = 'Invoke-RealTestCustomCleanupOnly'             # 정리 전용 판정 인자(R4-O1·O7 · V18)
    'Add-AbyssJournalClearedEntry'    = 'Invoke-RealAddAbyssJournalClearedEntry'       # 마커 → 기록 → 헬퍼 순서(P16 · R4-O9)
}
# GUI 원문에서 꺼내는 함수 - L 행의 기동 env(Set-HandoffLaunchEnv)와 그 의존(범위 술어 · 커스텀 owner 계산 · 소유자 JSON · 정지 문구)
$GUI_FUNCTION_NAMES = @(
    'Set-HandoffLaunchEnv', 'Resolve-HandoffEnvForContext', 'Clear-HandoffEnv', 'Test-AbyssHandoffRunActive', 'Test-AbyssMemberRunActive',
    'Get-CustomCanonicalOwner', 'Get-CustomFingerprint', 'Get-CustomOrderKey', 'Format-CustomItemToken', 'ConvertTo-CustomMarkerOwnerJson',
    'New-CustomMarkerOwnerJson', 'Get-AbyssJournalLockedGuide', 'Get-AbyssJournalCorruptGuide', 'Get-InsideHandoffStopReason')
# 모의(실제 함수와 서명 대조 - 워커 / GUI) · 감시(실제 함수를 다른 이름으로 두고 같은 이름은 호출 수를 셈 - 서명 대조)
$WORKER_MOCK_NAMES = @('Write-RunLog', 'Clear-EventOverlay', 'Click-ScreenPoint', 'Press-KeyVerified')
$WORKER_SPY_NAMES = @('Read-AbyssJournal', 'Update-AbyssJournal')
$GUI_MOCK_NAMES = @('Add-GuiLog', 'Stop-AllRun')
$GUI_SPY_NAMES = @('Resolve-HandoffEnvForContext')
# 단계 2.4~2.6 의 화면·입력·대기 모의 - 몸통은 아래 스텁 엔진이고 매개변수는 워커 원문의 param 블록을 그대로 씁니다(서명이 늘 같음 - 아래 '서명 대조').
#   판독 스텁(Test-*·Get-AbyssPanelKind)은 회전마다 가상 시각의 화면으로 답하고, 판독 원시 함수(Get-Game*Ocr*·Get-GameRegionCapture)도 같은 화면 모형으로
#   답해 구현이 다른 판독 경로를 써도 실제 화면을 읽지 않습니다. 입력 원시 함수는 기록만 합니다
$FLOW_MOCK_NAMES = @(
    'Write-LifeDiagnostics', 'Return-ToAbyssSelection', 'Invoke-AbyssExitClick', 'Invoke-ClickUntil', 'Write-CustomClearMarker',
    'Test-UserRecentlyActive', 'Wait-UserYieldEnd', 'Invoke-PurchasePopupSweep', 'Test-CaptureRecovered', 'Test-SafeStopDuringCaptureFail', 'Get-CaptureFailTotalMs',
    'Test-DungeonClearPrompt', 'Get-AbyssPanelKind', 'Test-HomeEndEscHud', 'Test-DungeonEntered', 'Test-InDungeonQuest', 'Test-AbyssSelectionScreen', 'Test-AbyssMenu',
    'Test-AbyssKnownDetailScreen', 'Test-AbyssEntryWaiting', 'Test-ExitButton', 'Get-GameOcrText', 'Get-GameRegionOcrText', 'Get-GameRegionOcrWords',
    'Get-GameRegionCapture', 'Get-DetailTitleText', 'Invoke-AutoRefocus', 'Focus-Game', 'Click-GamePoint', 'Press-KeyOnce', 'Move-CursorOutsideGame')
# 층 ② 구간이 원문에 품지만 어비스 행에서는 닿지 않아야 하는 함수 - 부르면 그 자리에서 예외(던전·사냥터 분기 · 복구 상세 갈래의 스크립트블록 안)
$UNREACHABLE_NAMES = @('Invoke-NormalDungeonCycle', 'Invoke-HuntingGroundCycle', 'Invoke-AbyssBackRefocus', 'Test-DetailTitleMatches')
# 의존 추출이 따라가지 않는 이름 - 이 파일이 직접 정의하는 모의·감시·종료 흉내·대기·설정 읽기(소스 값 캡처용)
$TEST_DEFINED_NAMES = @($WORKER_MOCK_NAMES + $WORKER_SPY_NAMES + $FLOW_MOCK_NAMES + $UNREACHABLE_NAMES +
    @('Start-Sleep', 'Get-Date', 'Stop-WorkerTailExit', 'Get-ConfigInteger', 'Get-ConfigValue'))

# Consume-Handoff 의 로그 줄 - 명세 ② 2.1 표 글자 그대로('제안' = 원천에 문구가 없어 명세가 붙인 것 - 구현이 바꾸면 여기도 함께, 명세 머리말 · 5절 B19)
$LINE_RECOVERY = '[안내] 복구 기동 - 이어받을 항목 없이 현행 복구 계약으로 진행합니다'                                                   # 표 ① (dev:593)
$LINE_LOCKED = '[완료] 완료 기록 파일이 사용 중이라 이어받을 역할을 확인하지 못해 정지합니다 (잠시 뒤 다시 시작해 주세요) (locked)'           # 표 ③ (dev:852·870)
$LINE_IO_FAILED = '[완료] 완료 기록 파일을 읽지 못해 이어받을 역할을 확인하지 못해 정지합니다 (잠시 뒤 다시 시작해 주세요) (locked)'         # 표 ④ (제안 - E02)
$LINE_CORRUPT = '[경고] 완료 기록 파일이 손상돼 이어받을 기록을 확인하지 못했습니다 - 이번 판은 입장 직후 키를 보내지 않습니다'             # 표 ⑤ (제안 - dev:870)
$LINE_OWNER_UNREADABLE = '[경고] 커스텀 항목 소유자 정보를 읽지 못해 이어받을 기록을 확인하지 않습니다 - GUI/워커 버전을 확인해 주세요'     # 표 ⑦ (제안 - E15)
$LINE_MISMATCH_FORMAT = '[경고] 넘겨받은 완료 기록이 이번 기동과 맞지 않아 이어받지 않고 진행합니다 ({0})'                                 # 표 ⑨ (제안 - 괄호 = 항목 stage)

# 명세 ② 2.1 표의 기본값과 정적 단언의 원문(공백 정규화 뒤 비교)
$HANDOFF_DEFAULT_TEXT = 'Role=none · Nonce= · CleanupOnly=False(bool) · FreshEntry=False(bool) · StartScreen= · AfterEntry=null · JournalState=ok'
$BLOCK_CONDITION_TEXT = "(`$contentCategory -eq 'abyss') -and (-not `$script:customSpecInvalid)"   # P21 - 이 블록의 if 줄 = R3 S4·R4 P1 의 '선분기 첫 문장'
$BLOCK_FIRST_STATEMENT_TEXT = "if ((Consume-Handoff) -eq 'stop') { exit 4 }"                       # P21 · 명세 2.1 표
$MEMBER_IF_TEXT = 'if ($abyssPartyMemberRun) {'                                                     # R4-P1 앞 앵커(파티원 디스패치)
$CLEAR_IF_TEXT = 'if (Clear-EventOverlay -Game $game) {'                                            # R4-P1·P13 뒤 앵커(run:18221 원문 그대로 - 다른 회귀의 IndexOf 앵커)

# 완료 기록 픽스처
$ABYSS_SECTION = 'abyssCustomRepeat'
$NONCE_A = 'a0000000-0000-4000-8000-00000000000a'
$NONCE_B = 'b0000000-0000-4000-8000-00000000000b'
$NONCE_C = 'c0000000-0000-4000-8000-00000000000c'
$NONCE_D = 'd0000000-0000-4000-8000-00000000000d'
$NONCE_LABELS = @{ $NONCE_A = 'NA'; $NONCE_B = 'NB'; $NONCE_C = 'NC'; $NONCE_D = 'ND' }
$CORRUPT_MAIN_TEXT = '{"version":1,"seq":'   # 본 파일 손상 픽스처
$CORRUPT_BAK_TEXT = 'not json'               # 직전본 손상 픽스처
# CH 행의 커스텀 owner (워커 쪽만 도는 행 - GUI 함수 없이 같은 모양의 토큰·소유자 JSON 을 만듭니다)
$CH_ITEM_TOKENS = @('A|solo|어려움|허상의 정박지|없음', 'A|party|어려움|잊혀진 성소|우연한 만남', 'A|solo|일반|그림자 회랑|없음')
$CH_FINGERPRINT = $CH_ITEM_TOKENS -join ';'
$CH_GENERATION = 3     # 0 이 아니어야 세대를 빠뜨린 대조가 드러남 (⑯ $H_GENERATION 과 같은 이유)
$CH_RUN_ID = 'run-ch'
$CH_KEYS = @(32, 66)   # 입장 직후 키 목록(자동출발 Space · 음식 B - 워커 기본 키)
# L 행의 커스텀 목록 (GUI 원문 함수가 토큰·지문을 만듭니다 - ⑯ 픽스처와 같은 모양)
$ABYSS_ITEMS = @(
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '잊혀진 성소'; matching = '우연한 만남' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '일반'; dungeon = '그림자 회랑'; matching = '' })
$L_GENERATION = 3
$L_RUN_ID = 'run-launch'
$STALE_VALUE = 'stale-before'   # 기동 전 handoff env 에 미리 넣는 값 - 그대로 남으면 GUI '먼저 비움' 이 안 된 것
$HANDOFF_ENV_NAMES = @('HONEYNOGI_HANDOFF_NONCE', 'HONEYNOGI_RESUME_REENTRY', 'HONEYNOGI_FINISH_ONLY')
# 세대 env(HONEYNOGI_CUSTOM_GENERATION)는 워커가 [설정] 줄에만 씁니다(명세 ② J3 - 세대 출처는 소유자 JSON). 행마다 지우고 CH10g 만 어긋난 값을 둡니다
$TOUCHED_ENV_NAMES = @($HANDOFF_ENV_NAMES + @('HONEYNOGI_CUSTOM_OWNER', 'HONEYNOGI_CUSTOM_RECOVERY', 'HONEYNOGI_RUN_ID', 'HONEYNOGI_CUSTOM_GENERATION',
    'HONEYNOGI_CUSTOM_RESTART'))   # 재시작 env - 단계 2.6 행(R4-O9 의 RESTART · V18 복구 기동)이 둡니다

# ===== 단계 2.4~2.6 상수 =====
# 선분기 로그·정지 문구 - 명세 ② 2.5 '선분기 로그 줄' S1~S20 글자 그대로('제안' 문구는 구현이 바꾸면 여기도 함께 - 명세 머리말 · 5절 B19). 숫자 자리
#   (W · 30 · Tpm)는 아래 소스 값 캡처로 채웁니다
$S9_NEXT_SELECTION = '[완료] 이어받은 판의 시작 화면이 어비스 선택 화면입니다 - 던전 안 오버레이일 수 있어 안·밖을 확인하지 못해 조작 없이 정지합니다. 오버레이를 닫은 뒤 판을 수동으로 마치지 말고 던전 안에서 즉시 다시 시작해 주세요 (던전 밖이면 선택 화면을 닫아 필드(HUD 가 보이는 곳)에서 다시 시작해 주세요) (selection-overlay)'
$S10_OWN_SELECTION = '[완료] 이어받은 판의 시작 화면이 어비스 선택 화면입니다 - 던전 안 오버레이일 수 있어 안·밖을 확인하지 못해 조작 없이 정지합니다. 화면을 확인하고(오버레이면 닫고, 던전 안이면 그 판을 마친 뒤) 다시 시작해 주세요. 던전 밖이면 선택 화면을 닫아 필드(HUD 가 보이는 곳)에서 다시 시작해 주세요 (selection-overlay)'
$S11_NEXT_MENU = '[완료] 이어받은 판의 시작 화면이 ESC 메뉴입니다 - 메뉴가 화면을 가려 안·밖을 확인하지 못해 조작 없이 정지합니다. 메뉴를 닫은 뒤 판을 수동으로 마치지 말고 던전 안에서 즉시 다시 시작해 주세요 (던전 밖이면 필드에서) (menu-overlay)'
$S12_OWN_MENU = '[완료] 이어받은 판의 시작 화면이 ESC 메뉴입니다 - 메뉴가 화면을 가려 안·밖을 확인하지 못해 조작 없이 정지합니다. 메뉴를 닫고(던전 안이면 그 판을 마친 뒤, 던전 밖이면 필드에서) 다시 시작해 주세요 (menu-overlay)'
$S13_NEXT_DETAIL = '[완료] 이어받은 판의 시작 화면이 어비스 던전 상세 화면입니다 - 던전 안에 겹친 화면일 수 있어 안·밖을 확인하지 못해 조작 없이 정지합니다. 화면을 닫고 필드(HUD 가 보이는 곳)에서 다시 시작해 주세요 (던전 안이었다면 판을 수동으로 마치지 말고 닫은 뒤 즉시 다시 시작해 주세요) (selection-overlay)'
$S14_OWN_DETAIL = '[완료] 이어받은 판의 시작 화면이 어비스 던전 상세 화면입니다 - 던전 안에 겹친 화면일 수 있어 안·밖을 확인하지 못해 조작 없이 정지합니다. 화면을 닫고 필드(HUD 가 보이는 곳)에서 다시 시작해 주세요 (던전 안이었다면 닫은 뒤 그 자리에서 다시 시작해도 됩니다) (selection-overlay)'
$S15_NEXT_UNKNOWN_FORMAT = '[완료] 이어받은 판의 시작 화면을 {0}초 안에 확인하지 못해 조작 없이 정지합니다 - 판을 수동으로 마치지 말고 던전 안에서 즉시 다시 시작해 주세요 (던전 밖이면 필드에서) (start-unknown)'
$S16_OWN_UNKNOWN_FORMAT = '[완료] 이어받은 판의 시작 화면을 {0}초 안에 확인하지 못해 조작 없이 정지합니다 - 던전 안이면 그 판을 마친 뒤, 던전 밖이면 필드(HUD 가 보이는 곳)에서 다시 시작해 주세요 (start-unknown)'
$S17_BASE = '[완료] 이어받은 판의 시작 화면이 보상 화면입니다 - 재입장 확인이 틀렸을 수 있어 계상 없이 정지합니다'
$S17_CUSTOM_TAIL = ' (이 판은 계상되지 않으며, 다음 시작은 정리 전용(코드 10) 뒤 같은 항목을 다시 돕니다)'
$S17_PLAIN_TAIL = ' (다음 시작이 이 보상 화면을 마무리하며 그때 1회 계상합니다)'
$RELEASE_TAIL = ' (release)'                                                 # 놓아줌 표지(J22) - S17 두 변형 · S18 · S20 끝에만
$S18_B2_TIMEOUT_FORMAT = '[완료] {0} 에서 시작해 {1}초 안에 입장을 확인하지 못했습니다 - 취소·나가기 없이 정지합니다. 화면을 확인하고 다시 시작해 주세요. (release)'
$S19_RESUME = '[완료] 재입장 재개 기능이 꺼져 있어 기록을 보존하고 정지합니다 (post-clear)'
$S20_CREATE_FAIL = '[완료] 입장 기록 실패 - 재화 중복 소모를 막기 위해 입장 직후 키를 보내지 않고 정지합니다 (캐릭터는 던전 안) (release)'
$KEYPOINT_CREATE_FAIL = '[완료] 입장 기록 실패 - 재화 중복 소모를 막기 위해 입장 직후 키를 보내지 않고 정지합니다 (캐릭터는 던전 안)'   # 본류 키 지점(Role none) - 꼬리 0
$S4_CLOSE_FORMAT = '[어비스] 시작 화면이 던전 밖이라 이어받던 판의 기록을 닫았습니다 - 새 판으로 들어갑니다 (abandoned-pre-entry-start · {0})'
$S5_CLOSE_FAIL_FORMAT = '[경고] 이어받던 판의 기록을 닫지 못했습니다 ({0}) - 새 판의 기록이 남은 기록을 함께 닫습니다'
$S6_FRESH_ENTRY = '[어비스] 이어받은 항목 없이 새 입장 확인 - 새 판으로 진행합니다 (ownFreshEntry)'
$S7_B2_START_FORMAT = '[어비스] 이어받기 시작: {0} 감지 - 입장을 기다립니다 (최대 {1}초)'
$S8_OVERLAY_FORMAT = '[안내] 이어받기 시작: 알 수 없는 화면이 {0}초 이어져 이벤트 화면 정리를 한 번 시도합니다'
$ENTRY_SAVED_LINE = '[어비스] 입장 기록 저장 (입장 직후 키 전)'               # 자기 항목 생성 성공 줄(단계 2.2 · H11)
# 계측·결과 줄은 숫자 자리가 있어 정규식으로 읽고 숫자를 하니스 기록과 견줍니다 (S1 · S2 · S3 - 명세 2.5 표의 틀 그대로)
$S1_PATTERN = '^\[어비스\] 이어받기 시작 계측 - 던전 안 2연속 앞 알 수 없음 (?<u>\d+)표본, 필드 모양 (?<f>\d+)표본(?<part>, 첫 필드 모양 표본부터 던전 안 (?<s>-?[0-9.]+)초)?, 관측 끊김 (?<b>\d+)회 \(판정에 쓰지 않음\)$'
$S2_PATTERN = '^\[어비스\] 입장 계측 - 던전 안 2연속 앞 로딩\(알 수 없음\) (?<u>\d+)표본, 필드 모양 (?<f>\d+)표본(?<part>, 첫 필드 모양 표본부터 던전 안 (?<s>-?[0-9.]+)초)?, 관측 끊김 (?<b>\d+)회 \(필드 확정 폭 (?<w>[0-9.]+)초 계측 - 판정에 쓰지 않음\)$'
$S3_PATTERN = '^\[어비스\] 이어받기 시작: 던전 밖\(HUD\) 확인 - 필드 모양이 (?<w>[0-9.]+)초 이어졌습니다 \(첫 표본부터 (?<span>[0-9.]+)초, (?<count>\d+)표본\)$'
# 정지 진단 이름 (명세 2.5 Stop-AbyssHandoffOverlay · 결론 표 - 상세는 P20 의 '이어받기 시작 상세 화면') · 양보 문맥 (회전 골격 ②)
$DIAG_SELECTION = '이어받기 시작 선택 화면'
$DIAG_MENU = '이어받기 시작 ESC 메뉴'
$DIAG_DETAIL = '이어받기 시작 상세 화면'
$DIAG_UNKNOWN = '이어받기 시작 화면 미확인'
$DIAG_B2 = '이어받기 시작 입장 대기 초과'
$YIELD_CONTEXT = '이어받기 시작'
# B2 단계 라벨(S7·S18 - run:18285 의 셋 + '권장 인원 팝업') · own 닫기의 screen 값(= 분류 키 - 명세 2.5 결론 표 '그 종류')
$B2_LABELS = @{ ready = '준비 패널'; matching = '재매칭 패널'; entry = '접힌 준비 패널'; popup = '권장 인원 팝업' }
$CLOSE_SCREENS = @{ ready = 'ready'; matching = 'matching'; entry = 'entry-waiting'; popup = 'popup' }
$CLOSE_REASON = 'abandoned-pre-entry-start'
# HEAD 본류 원문의 줄 조각 (결론 '필드' 의 본류 복귀 · 메뉴 복귀 · 시작 패널 입장 대기 - 원문 보존 자리, run:18410·18482·18291)
$MAIN_MENU_RETURN_FRAGMENT = 'ESC 메뉴 감지 - 선택 화면으로 복귀부터 진행'
$MAIN_FIELD_FRAGMENT = '필드 상태 감지 - ESC → 어비스로 선택 화면 이동'
$MAIN_PANEL_WAIT_FRAGMENT = '감지 - 취소·나가기 없이 입장을 기다립니다'
$MAIN_REWARD_FRAGMENT = '보상 화면(나가기) 감지 - 마무리부터 진행'               # 본류 보상 분기 시작 줄(run:18421 원문 그대로)
$MAIN_MENU_DONE_LINE = '[완료] 어비스 선택 화면 복귀 완료 (준비 실행 - 회차로 세지 않음)'   # 본류 메뉴 복귀 완료 줄(run:18412 원문 그대로)
$V18_FORBIDDEN_FRAGMENT = '이전 보상 화면을 새 항목 완료로 기록'                 # V18 next × 3버튼·S - 이 기록 문장 0
# run:18409 메뉴 분기의 Role none·결론 필드 갈래 = HEAD 원문 run:18410~18417 의 문장 다섯 (주석 뺀 사본 · 공백 정규화 한 줄씩 - R4-P14 가 문장 목록 전체를 견줌)
$MENU_HEAD_STATEMENTS = @(
    "Write-RunLog '[어비스] 시작: ESC 메뉴 감지 - 선택 화면으로 복귀부터 진행'",
    'Return-ToAbyssSelection -Game $game -SafeStopExitCode 10',
    "Write-RunLog '$MAIN_MENU_DONE_LINE'",
    'if ($script:customMode -and $script:customRecoveryOnly) { exit 0 }',
    'exit 10')
# 하단(clearAndExitText 배율 3) 판독문 - 보관 프레임 재생값 (test_abyss_party_member §1(a) · 워커 서명 판정 함수 주석의 실측과 같은 문자열)
$BOTTOM_TEXTS = @{
    popup    = '㉬취소Space도전하기'                                                  # 권장 인원 팝업 G4·G5·L2
    entry    = '아이템을누르면상세정보를수있습니다나가기입장대기중'                    # 접힌 준비 패널 cap_212409_212
    reward3  = '아이템을누르면상세정보테볼수있습니다나가기Space다세하기다른던전가기'   # 09-18 3버튼 보상
    prompt   = '화면을터치해주세요'                                                    # 09-21 S4
    matching = '사제아이템을누르면상세정보를7나가기'                                  # 09-18 재매칭 패널
}
# 화면 모형 - 판독 스텁이 돌려줄 신호 묶음. 키 = 시각표에 쓰는 이름 (분류 키와 다름 - 'F' 는 필드 모양 표본, 'I' 는 던전 안 표본)
$SCREEN_CATALOG = @{
    'U'        = @{}                                                        # 로딩·검은 화면·알 수 없는 오버레이 (모든 판독 음성)
    'F'        = @{ Hud = $true }                                           # 필드 모양 - HUD · 추적기 던전명 없음
    'I'        = @{ Hud = $true; Quest = $true }                            # 던전 안 표본 - HUD · 추적기 던전명
    'ready'    = @{ Panel = 'ready' }                                       # 파티 준비 패널(HUD 가림)
    'matching' = @{ Panel = 'matching'; Bottom = $BOTTOM_TEXTS.matching }   # 재매칭 패널
    'entry'    = @{ Bottom = $BOTTOM_TEXTS.entry }                          # 접힌 준비 패널(패널 판독 none · HUD 없음)
    'popup'    = @{ Bottom = $BOTTOM_TEXTS.popup }                          # 권장 인원 팝업
    'S'        = @{ Prompt = $true; Bottom = $BOTTOM_TEXTS.prompt }         # 클리어 '화면을 터치'
    'R3'       = @{ Bottom = $BOTTOM_TEXTS.reward3 }                        # 3버튼 보상(HUD 없음)
    'SEL'      = @{ Selection = $true }                                     # 어비스 선택 화면(오버레이일 수 있음)
    'SELF'     = @{ Selection = $true; Hud = $true }                        # 같은 회전에 선택 화면 + 필드 모양(R4-F7)
    'MENU'     = @{ Menu = $true; Hud = $true }                             # ESC 메뉴(필드 모양 위 - R4-N8 · K11)
    'DET'      = @{ Detail = $true }                                        # 어비스 던전 상세 화면(등록 던전 제목 · HUD 없음)
}
# 분류 함수 매개변수의 뜻 대응 규칙 (위가 먼저 - 이름에 이 낱말이 들면 그 뜻). 명세 2.4 의 입력 = 하단 판독문 · 패널 종류 · HUD · 추적기 · 3버튼 서명 ·
#   선택 화면 · 메뉴 · 상세 (+ S). 3버튼·팝업·접힌 패널은 하단 판독문에서 계산하거나 서명(참/거짓)으로 받을 수 있어 둘 다 받습니다
$CLASSIFIER_RULES = @(
    @{ Semantic = 'Reward3'; Pattern = 'reward|three|exit' },
    @{ Semantic = 'Popup'; Pattern = 'popup|fewmember' },
    @{ Semantic = 'EntryWaiting'; Pattern = 'entry|waiting|folded|collapse' },
    @{ Semantic = 'Prompt'; Pattern = 'prompt|clear|touch' },
    @{ Semantic = 'Bottom'; Pattern = 'bottom|text|ocr' },
    @{ Semantic = 'Panel'; Pattern = 'panel' },
    @{ Semantic = 'Hud'; Pattern = 'hud' },
    @{ Semantic = 'Quest'; Pattern = 'quest|tracker' },
    @{ Semantic = 'Selection'; Pattern = 'selection|select' },
    @{ Semantic = 'Menu'; Pattern = 'menu' },
    @{ Semantic = 'Detail'; Pattern = 'detail' })
$CLASSIFIER_REQUIRED = @('Prompt', 'Panel', 'Hud', 'Quest', 'Selection', 'Menu', 'Detail')
# 가상 시계 (test_abyss_return_loop 방식 - 판독은 시간을 쓰지 않고 Start-Sleep·양보 대기·스윕이 시계를 전진)
$VIRTUAL_BASE = [datetime]'2026-10-13T09:00:00'
$VIRTUAL_TIME_LIMIT = 3000      # 가상 초 상한 - 마감을 못 보는 변이가 행을 끝없이 돌리지 않게 (가장 긴 행 = 조정 Tpm + 양보 + 캡처 실패 약 335초)
$READ_CALL_LIMIT = 60000        # 판독 스텁 호출 상한 - 시간이 흐르지 않는 회전이 이어지는 변이 대비
$SWEEP_STUB_MS = 1000           # 스윕이 참일 때 스윕 자신이 쓰는 시간(구매 '닫기' 클릭·확인) - 0 이면 시간이 흐르지 않는 회전이 생김
$SKIP_YIELD_MS = 3000           # 스윕 클릭이 조작으로 생략된 뒤(위임 길) 다음 회전 게이트가 기다리는 양보 시간 (test_abyss_party_member 의 위임 길 양보 3초와 같은 값)
$TIME_EPSILON = 0.001           # 가상 초 비교 여유 (틱 정밀도는 정확하지만 경계 표기를 위해)
# 본류 단계에서 세는 판독 (선분기 반환 뒤 증가분 - '(본류) 판독 … 0' 의 자리: run:18222·18235·18242~18283·18380·18468~18469 + 메뉴 run:18409 · 복구 선택 화면)
$POST_READ_NAMES = @('Test-ExitButton', 'Test-DungeonClearPrompt', 'Get-AbyssPanelKind', 'Test-AbyssEntryWaiting', 'Test-DungeonEntered', 'Test-HomeEndEscHud',
    'Test-InDungeonQuest', 'Test-AbyssSelectionScreen', 'Test-AbyssMenu')
# 입장 직후 키 목록 픽스처 - 워커 기본 키(run:1850~1855 의 config 없음 기본값 · 키 루프가 읽는 모양 @{ Key; Label })
$afterEntryActions = @(@{ Key = 32; Label = '자동출발' }, @{ Key = 66; Label = '음식 자동 먹기' })

# ===== 공통 단언 · 표시 =====
function Assert-Case {
    # 단언 한 줄 - 대소문자까지 비교합니다('locked' 와 'Locked' 는 다른 값)
    param([string]$Name, $Actual, $Expect)
    if ("$Actual" -ceq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
    else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function J {
    # 여러 값을 한 단언 값으로 - ' | ' 로 잇습니다($null = 빈 칸)
    param([object[]]$Parts)
    return (@($Parts | ForEach-Object { if ($null -eq $_) { '' } else { [string]$_ } }) -join ' | ')
}

function Format-Logs {
    # 로그 줄 목록 → '[줄 || 줄]' (없으면 '[]')
    param([object[]]$Lines = @())
    return ('[' + (@($Lines) -join ' || ') + ']')
}

function Format-Outputs {
    # 함수 출력 개체 전부 → '값(개수)' - 반환 'ok'/'stop' 하나 계약(여분 출력이 섞이면 개수로 드러남)
    param([object[]]$Outputs = @())
    return ('{0}({1})' -f ((@($Outputs) | ForEach-Object { [string]$_ }) -join ','), @($Outputs).Count)
}

function Get-NonceLabel {
    # nonce → 픽스처 이름(NA~ND) · 빈 값 '(빈 값)' · 그 밖 원문
    param([string]$Nonce)
    if ([string]::IsNullOrEmpty($Nonce)) { return '(빈 값)' }
    if ($NONCE_LABELS.ContainsKey($Nonce)) { return [string]$NONCE_LABELS[$Nonce] }
    # 워커가 만든 새 항목(자기 항목 · ownFreshEntry)의 nonce - 완료 기록 보기(Get-JournalView)가 파일 순서대로 NEW1, NEW2 … 로 붙인 이름
    if (($null -ne $script:dynamicNonceLabels) -and $script:dynamicNonceLabels.ContainsKey($Nonce)) { return [string]$script:dynamicNonceLabels[$Nonce] }
    return $Nonce
}

# ===== 소스 도구 =====
function Remove-CommentsByTokens {
    # 주석 토큰을 같은 길이의 공백으로(줄바꿈 보존) - 위치가 원문과 같아 AST 오프셋으로 사본을 잘라 쓸 수 있습니다(test_abyss_party_member 와 같은 구현)
    param([string]$Text, $Tokens)
    $builder = New-Object System.Text.StringBuilder ($Text.Length)
    $position = 0
    foreach ($token in $Tokens) {
        if ($token.Kind -ne [TokenKind]::Comment) { continue }
        [void]$builder.Append($Text, $position, $token.Extent.StartOffset - $position)
        [void]$builder.Append(($token.Text -replace '[^\r\n]', ' '))
        $position = $token.Extent.EndOffset
    }
    [void]$builder.Append($Text, $position, $Text.Length - $position)
    return $builder.ToString()
}

function Convert-ExitTokens {
    # 원문의 exit 토큰을 뒤에서부터 Stop-WorkerTailExit 로 바꿉니다(⑯ :462~472 선례 · 명세 ② J8 - 한 줄 '{ exit N }' 도 바꿈. 줄 단독 정규식은 못 바꿈).
    # 반환 @{ Text; Tokens(원본 Exit 토큰 수); Statements(원본 ExitStatementAst 수); Inserted(새로 생긴 Stop-WorkerTailExit 호출 수);
    #        Remaining(치환 뒤 ExitStatementAst + Exit 토큰 수); Errors(원본·치환 뒤 파서 오류 수) }
    param([string]$Text)
    $originalTokens = $null
    $originalErrors = $null
    $originalAst = [Parser]::ParseInput($Text, [ref]$originalTokens, [ref]$originalErrors)
    $exitTokens = @($originalTokens | Where-Object { $_.Kind -eq [TokenKind]::Exit } | Sort-Object { $_.Extent.StartOffset } -Descending)
    $converted = $Text
    foreach ($exitToken in $exitTokens) {
        $converted = $converted.Substring(0, $exitToken.Extent.StartOffset) + 'Stop-WorkerTailExit' + $converted.Substring($exitToken.Extent.EndOffset)
    }
    $convertedTokens = $null
    $convertedErrors = $null
    $convertedAst = [Parser]::ParseInput($converted, [ref]$convertedTokens, [ref]$convertedErrors)
    $sentinelBefore = @($originalAst.FindAll({ param($node) ($node -is [CommandAst]) -and ($node.GetCommandName() -eq 'Stop-WorkerTailExit') }, $true)).Count
    $sentinelAfter = @($convertedAst.FindAll({ param($node) ($node -is [CommandAst]) -and ($node.GetCommandName() -eq 'Stop-WorkerTailExit') }, $true)).Count
    return @{
        Text       = $converted
        Tokens     = $exitTokens.Count
        Statements = @($originalAst.FindAll({ param($node) $node -is [ExitStatementAst] }, $true)).Count
        Inserted   = $sentinelAfter - $sentinelBefore
        Remaining  = @($convertedAst.FindAll({ param($node) $node -is [ExitStatementAst] }, $true)).Count +
            @($convertedTokens | Where-Object { $_.Kind -eq [TokenKind]::Exit }).Count
        Errors     = @($originalErrors).Count + @($convertedErrors).Count
    }
}

function New-ExitTally { return @{ Tokens = 0; Statements = 0; Inserted = 0; Remaining = 0; Errors = 0; Units = 0 } }

function Add-ExitTally {
    # 치환 결과를 묶음별 합계에 더합니다
    param([hashtable]$Tally, [hashtable]$Conversion)
    foreach ($key in @('Tokens', 'Statements', 'Inserted', 'Remaining', 'Errors')) { $Tally[$key] = [int]$Tally[$key] + [int]$Conversion[$key] }
    $Tally.Units = [int]$Tally.Units + 1
}

function Format-ExitTally {
    param([hashtable]$Tally)
    return ('원본 Exit 토큰 {0} · 원본 ExitStatementAst {1} · 치환 {2} · 치환 뒤 {3} · 파서 오류 {4}' -f $Tally.Tokens, $Tally.Statements, $Tally.Inserted, $Tally.Remaining, $Tally.Errors)
}

function Assert-ExitTally {
    # '원본 Exit 토큰 수 = 원본 ExitStatementAst 수 = 치환 수 · 치환 뒤 0 · 파서 오류 0' (명세 ② 2.0-8 - 동작 행보다 먼저)
    param([string]$Label, [hashtable]$Tally)
    $expected = @{ Tokens = $Tally.Tokens; Statements = $Tally.Tokens; Inserted = $Tally.Tokens; Remaining = 0; Errors = 0 }
    Assert-Case ('exit 치환({0} - {1}개 단위)' -f $Label, $Tally.Units) (Format-ExitTally $Tally) (Format-ExitTally $expected)
}

function Test-AstInsideFunction {
    # 노드가 함수 정의 안에 있는지 (같은 이름의 지역 대입을 최상위 대입으로 잘못 세지 않게)
    param($Node)
    for ($parent = $Node.Parent; $null -ne $parent; $parent = $parent.Parent) {
        if ($parent -is [FunctionDefinitionAst]) { return $true }
    }
    return $false
}

function Test-AstWithin {
    # 노드가 Ancestor 안(자손)인지
    param($Node, $Ancestor)
    if ($null -eq $Ancestor) { return $false }
    for ($parent = $Node.Parent; $null -ne $parent; $parent = $parent.Parent) {
        if ([object]::ReferenceEquals($parent, $Ancestor)) { return $true }
    }
    return $false
}

function Get-NormalizedCode {
    # 노드의 주석 뺀 원문(워커 사본 - 위치가 원문과 같음)을 공백 정규화한 한 줄
    param($Node)
    if ($null -eq $Node) { return '(없음)' }
    $codeText = $workerCode.Substring($Node.Extent.StartOffset, $Node.Extent.EndOffset - $Node.Extent.StartOffset)
    return (($codeText -replace '\s+', ' ').Trim())
}

function Find-StatementIndexes {
    # 문장 목록에서 조건(문장 하나를 받는 스크립트블록)을 만족하는 자리들 → 정수 배열(열거용 - 호출부 @())
    param([object[]]$Statements, [scriptblock]$Match)
    $found = @()
    for ($statementIndex = 0; $statementIndex -lt $Statements.Count; $statementIndex++) {
        if (& $Match $Statements[$statementIndex]) { $found += $statementIndex }
    }
    return $found
}

function Get-ParamSignature {
    # 소스 AST 의 함수 정의 → 매개변수 서명 '타입 $이름, …' (⑯ 와 같은 구현)
    param($Ast, [string]$Name)
    $functionAst = @($Ast.FindAll({ param($node) ($node -is [FunctionDefinitionAst]) -and ($node.Name -eq $Name) }, $true)) | Select-Object -First 1
    if ($null -eq $functionAst) { return '(정의 없음)' }
    $paramBlock = $functionAst.Body.ParamBlock
    if ($null -eq $paramBlock) { return '(매개변수 없음)' }
    return (@($paramBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}

function Get-LiveParamSignature {
    # 이 파일에 지금 정의된 함수(모의·감시)의 매개변수 서명 - 같은 형식
    param([string]$Name)
    $command = Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue
    if ($null -eq $command) { return '(정의 없음)' }
    $functionAst = $command.ScriptBlock.Ast
    $paramBlock = $(if ($functionAst -is [FunctionDefinitionAst]) { $functionAst.Body.ParamBlock } else { $functionAst.ParamBlock })
    if ($null -eq $paramBlock) { return '(매개변수 없음)' }
    return (@($paramBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}

# ===== 소스 추출 (최상위 정의 - 체크리스트 6) =====
# 문제가 있으면 줄을 모아 두고 아래 '추출 확인' 에서 FAIL 로 찍습니다 - 그 문제에 기대는 행 묶음은 건너뜁니다(조용히 통과하지 않게)
$extractionProblems = New-Object System.Collections.Generic.List[string]
$workerTokens = $null
$workerErrors = $null
$workerAst = [Parser]::ParseFile($workerPath, [ref]$workerTokens, [ref]$workerErrors)
if (@($workerErrors).Count -gt 0) {
    "FAIL 워커 파서 오류: $($workerErrors[0].Message)"
    exit 1
}
$workerCode = Remove-CommentsByTokens -Text $workerAst.Extent.Text -Tokens $workerTokens

# 저장소 묶음(워커 사본) - 머리 주석 ~ '묶음 끝' 표지 사이 최상위 함수 전부(test_abyss_journal_store 와 같은 경계). GUI 사본과 토큰이 같다는 것은 그 파일
# J14 가 지키므로, GUI 원문 Resolve 도 이 사본 위에서 돕니다(명세 ② 3.3 저장소 층 '실제 Update-AbyssJournal 워커 사본 + GUI 사본 Resolve' 와 같은 짜임)
$bundleHeaders = @($workerTokens | Where-Object { ($_.Kind -eq [TokenKind]::Comment) -and $_.Text.Contains($BUNDLE_HEADER_FRAGMENT) })
$bundleEnds = @($workerTokens | Where-Object { ($_.Kind -eq [TokenKind]::Comment) -and $_.Text.Contains($BUNDLE_END_FRAGMENT) })
if ($bundleHeaders.Count -ne 1 -or $bundleEnds.Count -ne 1) {
    "FAIL 저장소 묶음 경계 주석이 1개씩이 아닙니다 (머리 $($bundleHeaders.Count) · 끝 $($bundleEnds.Count))"
    exit 1
}
$bundleEndOffset = $bundleEnds[0].Extent.StartOffset
$bundleNames = @()
$bundleExit = New-ExitTally
foreach ($statement in $workerAst.EndBlock.Statements) {
    if (-not ($statement -is [FunctionDefinitionAst])) { continue }
    if ($statement.Extent.StartOffset -lt $bundleHeaders[0].Extent.StartOffset) { continue }
    if ($statement.Extent.StartOffset -gt $bundleEndOffset) { break }
    $bundleNames += $statement.Name
    $conversion = Convert-ExitTokens -Text $statement.Extent.Text
    Add-ExitTally -Tally $bundleExit -Conversion $conversion
    Invoke-Expression $conversion.Text
    if ($WORKER_SPY_NAMES -contains $statement.Name) {
        # 감시가 넘길 실제 함수 - Invoke-RealReadAbyssJournal · Invoke-RealUpdateAbyssJournal
        Invoke-Expression ($conversion.Text -replace ('^function ' + [regex]::Escape($statement.Name) + '\b'), ('function Invoke-Real' + ($statement.Name -replace '-', '')))
    }
}
foreach ($spyName in $WORKER_SPY_NAMES) { if ($bundleNames -notcontains $spyName) { $extractionProblems.Add("저장소 묶음에 $spyName 이(가) 없습니다") } }

# 워커 함수 - $WORKER_FUNCTION_NAMES 와 그 함수들이 부르는 워커 최상위 함수(저장소 묶음·모의·감시 이름은 빼고). 구현이 작은 도움 함수를 더해도 같이 돕니다.
# 본류 시작 구간(층 ②)의 형제 문장이 부르는 워커 함수도 같은 의존 추출로 올립니다 - 그 문장을 운영 원문 그대로 점소싱하기 때문입니다
$workerTopFunctions = @{}
foreach ($statement in $workerAst.EndBlock.Statements) {
    if ($statement -is [FunctionDefinitionAst]) { $workerTopFunctions[$statement.Name] = $statement }
}
# 본류 시작 구간의 형제 문장 목록 - 파티원 디스패치 if 의 부모 = 워커 최상위 try 본문. 층 ①(2.1 블록 ~ $roleNone 대입)·층 ②(2.1 블록 ~ run:18527 의
# '$startInsideDetected' if 앞 - 명세 3.2)가 이 목록에서 자릅니다
$mainStatements = @()
$memberIfNodes = @($workerAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq '$abyssPartyMemberRun') }, $true))
if ($memberIfNodes.Count -eq 1) { $mainStatements = @($memberIfNodes[0].Parent.Statements) } else { $extractionProblems.Add("파티원 디스패치 if 가 $($memberIfNodes.Count)개입니다(1개여야 함)") }
$memberIfIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement) ($statement -is [IfStatementAst]) -and ($statement.Clauses[0].Item1.Extent.Text -eq '$abyssPartyMemberRun') })
$blockIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement)
        ($statement -is [IfStatementAst]) -and (@($statement.FindAll({ param($node) ($node -is [CommandAst]) -and ($node.GetCommandName() -eq 'Consume-Handoff') }, $true)).Count -gt 0) })
$roleNoneIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement) ($statement -is [AssignmentStatementAst]) -and ($statement.Left.Extent.Text -eq '$roleNone') })
$clearIfIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement) ($statement -is [IfStatementAst]) -and ($statement.Clauses[0].Item1.Extent.Text -eq 'Clear-EventOverlay -Game $game') })
# run:18527 '$startInsideDetected' if - 2.1 블록 뒤 첫 자리 (층 ② 의 끝 = 그 앞 형제 문장)
$insideIfIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement) ($statement -is [IfStatementAst]) -and ($statement.Clauses[0].Item1.Extent.Text -eq '$startInsideDetected') })
$flowEndIndex = -1
if ($blockIndexes.Count -eq 1) {
    $insideAfterBlock = @($insideIfIndexes | Where-Object { $_ -gt $blockIndexes[0] })
    if ($insideAfterBlock.Count -ge 1) { $flowEndIndex = $insideAfterBlock[0] - 1 }
}
# 운영에서 2.1 블록 앞에 이미 대입된 시작 판독 - 시작 팝업 스윕 뒤 첫 '$startExitDetected = Test-ExitButton -Game $game'(run:18181). 층 ② 행이 같은 문장을 먼저 돌립니다
$preExitIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement)
        ($statement -is [AssignmentStatementAst]) -and ($statement.Left.Extent.Text -eq '$startExitDetected') -and $statement.Right.Extent.Text.Contains('Test-ExitButton') })
$flowCalleeNames = @()
if (($blockIndexes.Count -eq 1) -and ($flowEndIndex -ge $blockIndexes[0])) {
    foreach ($flowStatement in $mainStatements[$blockIndexes[0]..$flowEndIndex]) {
        foreach ($commandAst in $flowStatement.FindAll({ param($node) $node -is [CommandAst] }, $true)) {
            $commandName = $commandAst.GetCommandName()
            if ((-not [string]::IsNullOrEmpty($commandName)) -and ($flowCalleeNames -notcontains $commandName)) { $flowCalleeNames += $commandName }
        }
    }
}
$workerQueue = New-Object System.Collections.Generic.Queue[string]
foreach ($functionName in $WORKER_FUNCTION_NAMES) { $workerQueue.Enqueue($functionName) }
foreach ($functionName in $flowCalleeNames) {
    if (($bundleNames -contains $functionName) -or ($TEST_DEFINED_NAMES -contains $functionName)) { continue }
    if ($workerTopFunctions.ContainsKey($functionName)) { $workerQueue.Enqueue($functionName) }
}
$workerExtracted = New-Object System.Collections.Generic.List[string]
while ($workerQueue.Count -gt 0) {
    $functionName = $workerQueue.Dequeue()
    if ($workerExtracted.Contains($functionName)) { continue }
    if (-not $workerTopFunctions.ContainsKey($functionName)) {
        $extractionProblems.Add("워커 최상위 함수 $functionName 을(를) 찾지 못했습니다")
        continue
    }
    $workerExtracted.Add($functionName)
    foreach ($commandAst in $workerTopFunctions[$functionName].FindAll({ param($node) $node -is [CommandAst] }, $true)) {
        $commandName = $commandAst.GetCommandName()
        if ([string]::IsNullOrEmpty($commandName)) { continue }
        if (($bundleNames -contains $commandName) -or ($TEST_DEFINED_NAMES -contains $commandName) -or $workerExtracted.Contains($commandName)) { continue }
        if ($workerTopFunctions.ContainsKey($commandName)) { $workerQueue.Enqueue($commandName) }
    }
}
$workerExit = New-ExitTally
foreach ($functionName in $workerExtracted) {
    $conversion = Convert-ExitTokens -Text $workerTopFunctions[$functionName].Extent.Text
    Add-ExitTally -Tally $workerExit -Conversion $conversion
    $definitionText = $conversion.Text
    if ($WORKER_SPY_RENAMES.ContainsKey($functionName)) {
        # 감시가 넘길 실제 함수 - 같은 이름은 아래 감시가 차지합니다 (Consume-Handoff → Invoke-RealConsumeHandoff 등)
        $definitionText = $definitionText -replace ('^function ' + [regex]::Escape($functionName) + '\b'), ('function ' + $WORKER_SPY_RENAMES[$functionName])
    }
    Invoke-Expression $definitionText
}
$consumeAvailable = $workerExtracted.Contains('Consume-Handoff')
"INFO 워커 추출: $(@($workerExtracted) -join ', ') (저장소 묶음 $($bundleNames.Count)개 별도)"

# 단계 2.4~2.6 의 화면·입력·대기 모의 - 워커 원문의 param 블록 + 아래 스텁 엔진 몸통 (스크립트 범위 정의 - 추출 함수와 같은 자리)
$FLOW_MOCK_BODIES = @{
    'Write-LifeDiagnostics'          = '$script:diagLog.Add([pscustomobject]@{ Context = [string]$Context; Phase = $script:readPhase; T = (Get-VirtualElapsed) }); Add-StubEvent ("diag:" + $Context)'
    'Return-ToAbyssSelection'        = '$script:returnLog.Add([pscustomobject]@{ Code = [int]$SafeStopExitCode; Reason = [string]$LeaveEntryReason; Phase = $script:readPhase; T = (Get-VirtualElapsed) }); Add-StubEvent ("return:" + [string]$SafeStopExitCode + ":" + [string]$LeaveEntryReason); if ($script:returnLoopMode -eq "exit4") { Stop-WorkerTailExit 4 }'
    'Invoke-AbyssExitClick'          = '$script:exitClickCalls++; Add-StubEvent "exitclick"; return @{ Result = "clicked"; FrozenMs = 0 }'
    'Invoke-ClickUntil'              = '$script:clickUntilCalls++; Add-StubEvent ("clickuntil:" + [string]$Description)'
    'Write-CustomClearMarker'        = '$script:markerCalls++; Add-StubEvent "marker"; return $true'
    'Test-UserRecentlyActive'        = 'Enter-StubTurn; if ([int]$script:stubYieldQueue -gt 0) { return $true }; return ($null -ne (Find-StubWindow -Windows $script:scenarioActive -Time (Get-VirtualElapsed)))'
    'Wait-UserYieldEnd'              = 'Invoke-StubYieldWait -Context ([string]$Context)'
    'Invoke-PurchasePopupSweep'      = 'return (Invoke-StubSweep)'
    'Test-CaptureRecovered'          = 'return (Invoke-StubProbe)'
    'Test-SafeStopDuringCaptureFail' = 'Enter-StubTurn; $script:safeStopCalls++'
    'Get-CaptureFailTotalMs'         = 'return (Get-StubFailTotalMs)'
    'Test-DungeonClearPrompt'        = '$stubScreen = Invoke-StubRead -Name "Test-DungeonClearPrompt"; if ($null -eq $stubScreen) { $script:lastClearPromptText = ""; return $false }; $script:lastClearPromptText = [string]$stubScreen.Bottom; return [bool]$stubScreen.Prompt'
    'Get-AbyssPanelKind'             = '$stubScreen = Invoke-StubRead -Name "Get-AbyssPanelKind"; if ($null -eq $stubScreen) { return "none" }; return [string]$stubScreen.Panel'
    'Test-HomeEndEscHud'             = 'return (Invoke-StubFlagRead -Name "Test-HomeEndEscHud" -Field "Hud")'
    'Test-DungeonEntered'            = 'return (Invoke-StubFlagRead -Name "Test-DungeonEntered" -Field "Hud")'
    'Test-InDungeonQuest'            = 'return (Invoke-StubFlagRead -Name "Test-InDungeonQuest" -Field "Quest")'
    'Test-AbyssSelectionScreen'      = 'return (Invoke-StubFlagRead -Name "Test-AbyssSelectionScreen" -Field "Selection")'
    'Test-AbyssMenu'                 = 'return (Invoke-StubFlagRead -Name "Test-AbyssMenu" -Field "Menu")'
    'Test-AbyssKnownDetailScreen'    = 'return (Invoke-StubFlagRead -Name "Test-AbyssKnownDetailScreen" -Field "Detail")'
    'Test-AbyssEntryWaiting'         = '$stubScreen = Invoke-StubRead -Name "Test-AbyssEntryWaiting"; if ($null -eq $stubScreen) { return $false }; return [bool](Test-AbyssEntryWaitingText -Text ([string]$stubScreen.Bottom))'
    'Test-ExitButton'                = '$stubScreen = Invoke-StubRead -Name "Test-ExitButton"; if ($null -eq $stubScreen) { return $false }; return [bool](Test-AbyssRewardText -Text ([string]$stubScreen.Bottom))'
    'Get-GameOcrText'                = '$stubScreen = Invoke-StubRead -Name "Get-GameOcrText"; if ($null -eq $stubScreen) { return "" }; return [string]$stubScreen.Bottom'
    'Get-GameRegionOcrText'          = '$script:rawRegionReads++; return ""'
    'Get-GameRegionOcrWords'         = '$script:rawRegionReads++; return @()'
    'Get-GameRegionCapture'          = '$script:rawRegionReads++; return $null'
    'Get-DetailTitleText'            = '$script:rawRegionReads++; return ""'
    'Invoke-AutoRefocus'             = '$script:inputCalls.Add("Invoke-AutoRefocus"); return $false'
    'Focus-Game'                     = '$script:inputCalls.Add("Focus-Game")'
    'Click-GamePoint'                = '$script:inputCalls.Add(("Click-GamePoint {0},{1}" -f $ReferenceX, $ReferenceY)); $script:lastClickPerformed = $true; $script:lastClickSkipReason = ""'
    'Press-KeyOnce'                  = '$script:inputCalls.Add(("Press-KeyOnce {0}" -f $VirtualKey))'
    'Move-CursorOutsideGame'         = '$script:inputCalls.Add("Move-CursorOutsideGame")'
}
foreach ($mockName in @($FLOW_MOCK_NAMES + $UNREACHABLE_NAMES)) {
    if (-not $workerTopFunctions.ContainsKey($mockName)) {
        $extractionProblems.Add("모의 대상 워커 함수 $mockName 을(를) 찾지 못했습니다(서명을 원문에서 가져옴)")
        continue
    }
    $mockParamBlock = $workerTopFunctions[$mockName].Body.ParamBlock
    $mockParamText = $(if ($null -ne $mockParamBlock) { $mockParamBlock.Extent.Text } else { '' })
    $mockBody = $(if ($FLOW_MOCK_BODIES.ContainsKey($mockName)) { $FLOW_MOCK_BODIES[$mockName] } else { "throw 'TEST-UNREACHABLE: $mockName'" })
    Invoke-Expression ("function $mockName {`r`n$mockParamText`r`n$mockBody`r`n}")
}
# 분류 함수 감시 - 원문 param 블록 그대로 받아 회전 기록 뒤 실제 함수로 (R4-K1 '스윕 참 회전의 분류 호출 0')
$script:classifierMapping = @()
$classifierProblem = ''
if ($workerTopFunctions.ContainsKey('Resolve-AbyssHandoffStartScreen')) {
    $classifierParamBlock = $workerTopFunctions['Resolve-AbyssHandoffStartScreen'].Body.ParamBlock
    if ($null -eq $classifierParamBlock) {
        $classifierProblem = '분류 함수에 param 블록이 없습니다'
        Invoke-Expression ("function Resolve-AbyssHandoffStartScreen {`r`n`$script:classifyLog.Add([pscustomobject]@{ Turn = `$script:turnId; T = (Get-VirtualElapsed) }); return (Invoke-RealResolveAbyssHandoffStartScreen @args)`r`n}")
    } else {
        Invoke-Expression ("function Resolve-AbyssHandoffStartScreen {`r`n" + $classifierParamBlock.Extent.Text +
            "`r`n`$script:classifyLog.Add([pscustomobject]@{ Turn = `$script:turnId; T = (Get-VirtualElapsed) }); return (Invoke-RealResolveAbyssHandoffStartScreen @PSBoundParameters)`r`n}")
        # K 행 - 매개변수 이름의 뜻 대응 (명세가 이름을 정하지 않음 - 대응하지 못하면 FAIL, 조용히 통과하지 않게)
        $mappedSemantics = @()
        foreach ($classifierParameter in $classifierParamBlock.Parameters) {
            $parameterName = [string]$classifierParameter.Name.VariablePath.UserPath
            $parameterSemantic = ''
            foreach ($classifierRule in $CLASSIFIER_RULES) { if ($parameterName -match $classifierRule.Pattern) { $parameterSemantic = $classifierRule.Semantic; break } }
            if (-not $parameterSemantic) { $classifierProblem += "뜻을 모르는 매개변수 -$parameterName; " ; continue }
            if ($mappedSemantics -contains $parameterSemantic) { $classifierProblem += "같은 뜻($parameterSemantic) 매개변수 둘 -$parameterName; "; continue }
            $mappedSemantics += $parameterSemantic
            $script:classifierMapping += [pscustomobject]@{ Parameter = $parameterName; Semantic = $parameterSemantic }
        }
        foreach ($requiredSemantic in $CLASSIFIER_REQUIRED) { if ($mappedSemantics -notcontains $requiredSemantic) { $classifierProblem += "입력 $requiredSemantic 을(를) 받는 매개변수가 없습니다; " } }
        $hasSignatures = ($mappedSemantics -contains 'Reward3') -and ($mappedSemantics -contains 'Popup') -and ($mappedSemantics -contains 'EntryWaiting')
        if (($mappedSemantics -notcontains 'Bottom') -and (-not $hasSignatures)) { $classifierProblem += '하단 판독문(또는 3버튼·팝업·접힌 패널 서명 셋)을 받는 매개변수가 없습니다; ' }
    }
} else {
    $classifierProblem = '분류 함수가 없습니다'
}
"INFO 분류 함수 매개변수 대응: $(@($script:classifierMapping | ForEach-Object { '{0}={1}' -f $_.Parameter, $_.Semantic }) -join ', ')"

# 워커 env 읽기·상태 문장 - 행이 그대로 점소싱합니다(운영 대입과 같은 식)
function Find-WorkerAssignments {
    # 워커 대입문(깊이 무관) - 왼쪽 원문이 같고 오른쪽에 조각이 든 것 → 목록(열거용 - 호출부 @())
    param([string]$Left, [string]$RightFragment = '')
    return @($workerAst.FindAll({ param($node)
                ($node -is [AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq $Left) -and $node.Right.Extent.Text.Contains($RightFragment) }, $true))
}
$ownerReads = @(Find-WorkerAssignments -Left '$script:customOwnerJson' -RightFragment 'HONEYNOGI_CUSTOM_OWNER')
$recoveryReads = @(Find-WorkerAssignments -Left '$script:customRecoveryOnly' -RightFragment 'HONEYNOGI_CUSTOM_RECOVERY')
$restartReads = @(Find-WorkerAssignments -Left '$script:customRestart' -RightFragment 'HONEYNOGI_CUSTOM_RESTART')   # 단계 2.6 행(재시작 · 정리 전용 판정의 -Restart)
$runIdReads = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssRunId') })
$handoffAssigns = @(Find-WorkerAssignments -Left '$script:handoff')
$handoffOutside = @($handoffAssigns | Where-Object { -not (Test-AstInsideFunction $_) })
$handoffTop = @($handoffOutside | Where-Object { [object]::ReferenceEquals($_.Parent, $workerAst.EndBlock) })
$finishOnlyAssigns = @(Find-WorkerAssignments -Left '$script:finishOnly')
$finishOnlyOutside = @($finishOnlyAssigns | Where-Object { -not (Test-AstInsideFunction $_) })
$finishOnlyTop = @($finishOnlyOutside | Where-Object { [object]::ReferenceEquals($_.Parent, $workerAst.EndBlock) })
$script:workerOwnerReadBlock = $null
$script:workerRecoveryReadBlock = $null
$script:workerRestartReadBlock = $null
$script:workerRunIdReadBlock = $null
$script:workerHandoffDefaultBlock = $null
$script:workerFinishOnlyReadBlock = $null
if ($ownerReads.Count -eq 1) { $script:workerOwnerReadBlock = [scriptblock]::Create($ownerReads[0].Extent.Text) } else { $extractionProblems.Add("워커 소유자 JSON 읽기 대입이 $($ownerReads.Count)개입니다(1개여야 함)") }
if ($recoveryReads.Count -eq 1) { $script:workerRecoveryReadBlock = [scriptblock]::Create($recoveryReads[0].Extent.Text) } else { $extractionProblems.Add("워커 복구 기동 읽기 대입이 $($recoveryReads.Count)개입니다(1개여야 함)") }
if ($restartReads.Count -eq 1) { $script:workerRestartReadBlock = [scriptblock]::Create($restartReads[0].Extent.Text) } else { $extractionProblems.Add("워커 재시작 읽기 대입이 $($restartReads.Count)개입니다(1개여야 함)") }
if ($runIdReads.Count -eq 1) { $script:workerRunIdReadBlock = [scriptblock]::Create($runIdReads[0].Extent.Text) } else { $extractionProblems.Add("워커 실행 id 최상위 대입이 $($runIdReads.Count)개입니다(1개여야 함)") }
if ($handoffTop.Count -eq 1) { $script:workerHandoffDefaultBlock = [scriptblock]::Create($handoffTop[0].Extent.Text) } else { $extractionProblems.Add("워커 `$script:handoff 기본값 최상위 대입이 $($handoffTop.Count)개입니다(1개여야 함 - 명세 2.1 표 run:855 뒤)") }
if ($finishOnlyTop.Count -eq 1) { $script:workerFinishOnlyReadBlock = [scriptblock]::Create($finishOnlyTop[0].Extent.Text) }

# 본류 시작 구간 - 층 ①: 2.1 블록(Consume-Handoff 호출과 선분기 호출을 품은 if) ~ $roleNone 대입까지의 형제 문장 (형제 문장 목록·자리는 위 의존 추출 앞에서 찾음)
$startBlock = $(if ($blockIndexes.Count -eq 1) { $mainStatements[$blockIndexes[0]] } else { $null })
$roleNoneStatement = $(if ($roleNoneIndexes.Count -eq 1) { $mainStatements[$roleNoneIndexes[0]] } else { $null })
if ($null -eq $startBlock) { $extractionProblems.Add("본류 형제 문장에서 Consume-Handoff 호출을 품은 if 가 $($blockIndexes.Count)개입니다(1개여야 함 - 명세 2.1 블록)") }
if ($null -eq $roleNoneStatement) { $extractionProblems.Add("본류 형제 문장에서 `$roleNone 대입이 $($roleNoneIndexes.Count)개입니다(1개여야 함)") }
$script:mainSegmentBlock = $null
$segmentExit = New-ExitTally
if (($null -ne $startBlock) -and ($null -ne $roleNoneStatement) -and ($roleNoneIndexes[0] -gt $blockIndexes[0])) {
    # 층 ① (2.1 CH 행 · 단계 2.5 의 선분기 행): 블록이 선분기 호출(Role≠none)을 품으므로 이 구간이 곧 '실제 Consume-Handoff → 실제 선분기' 입니다
    $segmentText = (@($mainStatements[$blockIndexes[0]..$roleNoneIndexes[0]] | ForEach-Object { $_.Extent.Text }) -join "`r`n")
    $conversion = Convert-ExitTokens -Text $segmentText
    Add-ExitTally -Tally $segmentExit -Conversion $conversion
    $script:mainSegmentBlock = [scriptblock]::Create($conversion.Text)
    "INFO 본류 시작 구간: 워커 $($startBlock.Extent.StartLineNumber)~$($roleNoneStatement.Extent.EndLineNumber)줄 형제 문장 $($roleNoneIndexes[0] - $blockIndexes[0] + 1)개"
} elseif (($null -ne $startBlock) -and ($null -ne $roleNoneStatement)) {
    $extractionProblems.Add('$roleNone 대입이 2.1 블록보다 앞에 있어 본류 시작 구간을 자를 수 없습니다(명세 2.1 표 - 블록 밖·뒤)')
}
# 층 ② (단계 2.6 - 명세 3.2 · J8): 2.1 블록 ~ run:18527 '$startInsideDetected' if 바로 앞 형제 문장. Exit 토큰은 뒤에서부터 Stop-WorkerTailExit 로
#   ('원본 Exit 토큰 수 = ExitStatementAst 수 = 치환 수 · 치환 뒤 0' 은 동작 행보다 먼저 단언). 앞 문장 = 운영에서 이미 대입된 시작 판독(run:18181)
$script:mainFlowBlock = $null
$script:preFlowBlock = $null
$flowExit = New-ExitTally
if (($null -ne $startBlock) -and ($flowEndIndex -gt $blockIndexes[0])) {
    $flowText = (@($mainStatements[$blockIndexes[0]..$flowEndIndex] | ForEach-Object { $_.Extent.Text }) -join "`r`n")
    $conversion = Convert-ExitTokens -Text $flowText
    Add-ExitTally -Tally $flowExit -Conversion $conversion
    $script:mainFlowBlock = [scriptblock]::Create($conversion.Text)
    "INFO 본류 시작 구간(층 ②): 워커 $($startBlock.Extent.StartLineNumber)~$($mainStatements[$flowEndIndex].Extent.EndLineNumber)줄 형제 문장 $($flowEndIndex - $blockIndexes[0] + 1)개"
} else {
    $extractionProblems.Add("층 ② 의 끝('`$startInsideDetected' if - run:18527)을 2.1 블록 뒤에서 찾지 못했습니다 (if 자리 $(@($insideIfIndexes) -join ','))")
}
$preExitBefore = @($preExitIndexes | Where-Object { ($blockIndexes.Count -eq 1) -and ($_ -lt $blockIndexes[0]) })
if ($preExitBefore.Count -ge 1) { $script:preFlowBlock = [scriptblock]::Create($mainStatements[$preExitBefore[0]].Extent.Text) }
else { $extractionProblems.Add('2.1 블록 앞의 첫 시작 판독 ''$startExitDetected = Test-ExitButton -Game $game''(run:18181)을 찾지 못했습니다') }

# 소스 값 캡처 (명세 3.1 - test_abyss_party_member §0 와 같은 방식): 워커 최상위 대입문의 우변을 설정 읽기 '기본값 반환' 모의로 평가합니다.
#   W(run:655) · 알 수 없음 30초(run:654) · 스윕 연속 한도(run:656) · 매칭 대기 Tpm(run:744) · 본류 구간이 쓰는 대기 한도·좌표·던전 키워드
function Get-ConfigInteger { param([object]$Root, [string[]]$Path, [int]$Default, [int]$Minimum, [int]$Maximum) return $Default }
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$config = $null
function Get-SourceAssignmentValue {
    # 최상위(함수 밖) 첫 대입문의 우변 값 - 없으면 $null 과 함께 추출 문제로 남깁니다(상수가 사라진 것 자체가 결함)
    param([string]$Name)
    $assignNode = @($workerAst.FindAll({ param($node) ($node -is [AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq ('$' + $Name)) }, $true) |
            Where-Object { -not (Test-AstInsideFunction $_) } | Sort-Object { $_.Extent.StartOffset }) | Select-Object -First 1
    if ($null -eq $assignNode) {
        $extractionProblems.Add("소스 상수 대입문을 찾지 못했습니다: `$$Name")
        return $null
    }
    return (Invoke-Expression $assignNode.Right.Extent.Text)
}
$memberFieldSettleSeconds = Get-SourceAssignmentValue 'memberFieldSettleSeconds'
$memberUnknownOverlaySeconds = Get-SourceAssignmentValue 'memberUnknownOverlaySeconds'
$memberSweepStreakLimit = Get-SourceAssignmentValue 'memberSweepStreakLimit'
$timeoutPartyMatch = Get-SourceAssignmentValue 'timeoutPartyMatch'
$timeoutHud = Get-SourceAssignmentValue 'timeoutHud'
$timeoutAbyssMenu = Get-SourceAssignmentValue 'timeoutAbyssMenu'
$timeoutAbyssSelect = Get-SourceAssignmentValue 'timeoutAbyssSelect'
$timeoutExit = Get-SourceAssignmentValue 'timeoutExit'
$ptClearCenter = @(Get-SourceAssignmentValue 'ptClearCenter')
$ptDetailBack = @(Get-SourceAssignmentValue 'ptDetailBack')
$allDungeonKeywords = @(Get-SourceAssignmentValue 'allDungeonKeywords')
$capturedTimeoutPartyMatch = $timeoutPartyMatch
$safeStopFlagPath = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_handoff_start_no_flag_' + [guid]::NewGuid().ToString('N') + '.flag')   # 선분기는 보지 않음 - 있어도 없는 경로
"INFO 캡처: W $memberFieldSettleSeconds / 알 수 없음 $memberUnknownOverlaySeconds / 스윕 한도 $memberSweepStreakLimit / Tpm $timeoutPartyMatch"

# GUI 원문 함수 (L 행) - 이름으로 1개씩. Resolve 는 다른 이름으로 두고 같은 이름은 아래 감시가 차지합니다
$guiTokens = $null
$guiErrors = $null
$guiAst = [Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$guiErrors)
$guiExit = New-ExitTally
$guiAvailable = $true
if (@($guiErrors).Count -gt 0) {
    $extractionProblems.Add("GUI 파서 오류: $($guiErrors[0].Message)")
    $guiAvailable = $false
} else {
    foreach ($functionName in $GUI_FUNCTION_NAMES) {
        $functionAsts = @($guiAst.FindAll({ param($node) ($node -is [FunctionDefinitionAst]) -and ($node.Name -eq $functionName) }, $true))
        if ($functionAsts.Count -ne 1) {
            $extractionProblems.Add("GUI 함수 정의가 1개가 아닙니다: $functionName ($($functionAsts.Count)개)")
            $guiAvailable = $false
            continue
        }
        $conversion = Convert-ExitTokens -Text $functionAsts[0].Extent.Text
        Add-ExitTally -Tally $guiExit -Conversion $conversion
        $definitionText = $conversion.Text
        if ($functionName -eq 'Resolve-HandoffEnvForContext') {
            $definitionText = $definitionText -replace '^function Resolve-HandoffEnvForContext\b', 'function Invoke-RealResolveHandoffEnv'
        }
        Invoke-Expression $definitionText
    }
}

# ===== 모의 · 감시 (실제 서명 그대로 - 아래 '서명 대조') =====
$script:workerLogLines = New-Object System.Collections.Generic.List[string]
$script:inputCalls = New-Object System.Collections.Generic.List[string]
$script:guiEvents = New-Object System.Collections.Generic.List[string]
$script:resolveResults = New-Object System.Collections.Generic.List[string]
$script:heldStreams = New-Object System.Collections.Generic.List[System.IDisposable]
$script:journalReads = 0
$script:journalUpdates = 0
$script:consumeCalls = 0
$script:consumeOutputs = @()
$script:lastReadStatus = '(읽기 없음)'
$script:lastReadWarnings = @()
$script:sleepCalls = 0
# 단계 2.4~2.6 기록 (행마다 Reset-RowCounters → Reset-FlowState 가 비움)
# 기록 목록은 List[psobject] - PS 5.1 에서 New-Object 로 만든 List[object] 를 @() 로 감싸면 비어 있든 아니든 '인수 형식이 일치하지 않습니다'
# 예외(실행 확인 - test_abyss_handoff_gui 의 같은 주석). 넣는 항목은 전부 [pscustomobject] 라 변환 없음
$script:workerLogTimes = New-Object System.Collections.Generic.List[double]
$script:eventLog = New-Object System.Collections.Generic.List[string]
$script:readLog = New-Object System.Collections.Generic.List[psobject]
$script:overlayLog = New-Object System.Collections.Generic.List[psobject]
$script:diagLog = New-Object System.Collections.Generic.List[psobject]
$script:returnLog = New-Object System.Collections.Generic.List[psobject]
$script:classifyLog = New-Object System.Collections.Generic.List[psobject]
$script:cleanupCalls = New-Object System.Collections.Generic.List[string]
$script:yieldContexts = New-Object System.Collections.Generic.List[string]
$script:updateTags = New-Object System.Collections.Generic.List[string]
$script:dynamicNonceLabels = @{}
$script:vclock = $VIRTUAL_BASE
$script:rowStartClock = $VIRTUAL_BASE
$script:readPhase = 'main'
$script:inStoreCall = 0

function Write-RunLog {
    # 워커 로그(워커 실제 서명 param([string]$Message)) - 줄을 모읍니다(가상 시각·사건 순서도 함께 - 단계 2.5 의 줄 순서·시각 단언)
    param([string]$Message)
    $script:workerLogLines.Add($Message)
    $script:workerLogTimes.Add((Get-VirtualElapsed))
    Add-StubEvent ('log:' + $Message)
}
function Clear-EventOverlay {
    # 이벤트 화면 정리(워커 실제 서명) - 부른 단계·시각·회전을 적고 기본은 '정리할 것 없음'(거짓). 선분기 단계에서 행이 정리 뒤 화면(AfterOverlay -
    # 'N번째 정리가 오버레이를 닫음')을 주면 그 시각부터 그 시각표로 바꿉니다(R4-N5·O6 '스텁이 오버레이를 닫음'). 본류 단계에서 행이 MainOverlay(정리 뒤
    # 시각표)를 주면 첫 정리 한 번만 그 시각표로 바꾸고 참 - 본류 run:18221 의 '정리함' 갈래(run:18222 재판독 자리)를 엽니다. 늘 거짓이면 그 갈래 안의
    # Role none 가드를 지워도 '(본류) 판독 run:18222 0' 이 늘 참이었습니다(2026-10-13 검증 지적 - 정적 R4-P4 만 지킴)
    param([System.Diagnostics.Process]$Game)
    $script:overlayLog.Add([pscustomobject]@{ Phase = $script:readPhase; T = (Get-VirtualElapsed); Turn = $script:turnId })
    Add-StubEvent 'overlay'
    if ($script:readPhase -eq 'selector') {
        $script:selectorOverlayCount++
        if (($null -ne $script:scenarioAfterOverlay) -and ($script:selectorOverlayCount -eq $script:scenarioAfterOverlayAt)) {
            $overlayAt = Get-VirtualElapsed
            $script:scenarioTimeline = @(foreach ($afterEntry in @($script:scenarioAfterOverlay)) { [pscustomobject]@{ T = $overlayAt + [double]$afterEntry.T; S = [string]$afterEntry.S } })
            $script:scenarioCycle = $null
        }
    }
    if (($script:readPhase -eq 'main') -and ($null -ne $script:scenarioMainOverlay) -and (-not $script:mainOverlayClosed)) {
        $script:mainOverlayClosed = $true
        $overlayAt = Get-VirtualElapsed
        $script:scenarioTimeline = @(foreach ($afterEntry in @($script:scenarioMainOverlay)) { [pscustomobject]@{ T = $overlayAt + [double]$afterEntry.T; S = [string]$afterEntry.S } })
        $script:scenarioCycle = $null
        Add-StubEvent 'main-overlay-closed'
        return $true
    }
    return $false
}
function Click-ScreenPoint {
    # 클릭 전송(워커 실제 서명) - 기록만
    param([int]$X, [int]$Y)
    $script:inputCalls.Add(('Click-ScreenPoint {0},{1}' -f $X, $Y))
}
function Press-KeyVerified {
    # 키 전송(워커 실제 서명) - 기록만
    param([System.Diagnostics.Process]$Game, [byte]$VirtualKey, [string]$Label = '')
    $script:inputCalls.Add(('Press-KeyVerified {0}' -f $VirtualKey))
    return $true
}
function Stop-WorkerTailExit {
    # 추출 함수·구간의 exit 자리 - 워커를 끝내는 대신 종료 코드를 실은 예외로 행에 돌려줍니다(⑯ :597~601 과 같은 모양)
    param([int]$Code = 0)
    throw ($WORKER_EXIT_PREFIX + $Code)
}
function Start-Sleep {
    # 대기 = 가상 시계 전진(test_abyss_return_loop 방식). 저장소 재시도(Step-AbyssJournalBudget 의 50ms)는 횟수 예산이라 저장소 안에서는 시계를 움직이지
    # 않고 셉니다. 행이 SleepMap(요청 ms → 가상 ms)을 주면 그 값으로 전진합니다(R4-N5″ 의 정각 회전 - 회전 대기 700ms 를 100ms 로)
    param([int]$Seconds = 0, [int]$Milliseconds = 0)
    $script:sleepCalls++
    if ($script:inStoreCall -gt 0) { return }
    $sleepMs = [double]($Seconds * 1000 + $Milliseconds)
    if (($null -ne $script:sleepMap) -and $script:sleepMap.ContainsKey([int]$sleepMs)) {
        $script:sleepMapHits++
        $sleepMs = [double]$script:sleepMap[[int]$sleepMs]
    }
    Step-VirtualClock -Milliseconds $sleepMs
}
function Get-Date {
    # 가상 시계 - 워커·저장소·GUI 함수의 지금 시각(-Format 은 그 시각의 문자열, -Date 는 그 값)
    param([string]$Format = '', $Date = $null)
    $clockValue = $script:vclock
    if ($null -ne $Date) { $clockValue = [datetime]$Date }
    if ($Format) { return $clockValue.ToString($Format) }
    return $clockValue
}
function Open-StubJournalLock {
    # 완료 기록 .lock 을 이 프로세스가 쥡니다(CH3 과 같은 방식 - 저장소 Open-AbyssJournalLock 의 CreateNew 가 실패해 'locked')
    param([string]$Path)
    $lockPath = [IO.Path]::ChangeExtension($Path, '.lock')
    return (New-Object System.IO.FileStream($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose))
}
function Read-AbyssJournal {
    # 감시(실제 서명 param([string]$Path)) - 잠금 읽기 수를 세고 실제 함수로. 받은 상태·경고를 적어 둡니다(표 ② 의 기대값 · 픽스처 확인)
    param([string]$Path)
    $script:journalReads++
    $script:inStoreCall++
    try {
        $readResult = Invoke-RealReadAbyssJournal -Path $Path
    } finally {
        $script:inStoreCall--
    }
    $script:lastReadStatus = [string]$readResult.Status
    $script:lastReadWarnings = @($readResult.Warnings)
    return $readResult
}
function Update-AbyssJournal {
    # 감시(실제 서명 param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect = $null)) - 저장 수를 세고 실제 함수로. 행의 잠금 계획(LockPlan -
    # 단계·단계 안 순번·'once'(그 저장 한 번만) / 'hold'(행 끝까지))에 맞는 저장이면 .lock 을 쥔 채 부릅니다(R4-O7″·O12 · O4‴·O4⁗ 의 'locked' 주입).
    # 결과 태그를 '단계#순번:태그' 로 적어 둡니다
    param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect = $null)
    $script:journalUpdates++
    $updatePhase = [string]$script:readPhase
    $script:updateOrdinals[$updatePhase] = [int]$script:updateOrdinals[$updatePhase] + 1
    $updateOrdinal = [int]$script:updateOrdinals[$updatePhase]
    $onceStream = $null
    foreach ($lockStep in @($script:lockPlan)) {
        if (($null -eq $lockStep) -or ([string]$lockStep.Phase -ne $updatePhase) -or ([int]$lockStep.Ordinal -ne $updateOrdinal)) { continue }
        $lockStream = Open-StubJournalLock -Path $Path
        if ([string]$lockStep.Mode -eq 'hold') { $script:heldStreams.Add($lockStream) } else { $onceStream = $lockStream }
    }
    $script:inStoreCall++
    try {
        $updateResult = Invoke-RealUpdateAbyssJournal -Path $Path -Mutator $Mutator -Expect $Expect
    } finally {
        $script:inStoreCall--
        if ($null -ne $onceStream) { $onceStream.Dispose() }
    }
    $script:updateTags.Add(('{0}#{1}:{2}' -f $updatePhase, $updateOrdinal, [string]$updateResult.Tag))
    return $updateResult
}
function Invoke-AbyssHandoffStart {
    # 감시 - 선분기 단계 표시(판독 스텁이 단계별로 셈) → 실제 선분기 → 반환 직후 본류 단계로 넘기고 판독 계수 스냅숏(명세 3.2 층 ② '선분기와 본류의 판독
    # 계수 분리'). 선분기 안에서 exit 로 끝나면 종료 흉내 예외가 이 감시를 그대로 지나가 스냅숏이 없습니다
    param([System.Diagnostics.Process]$Game)
    $script:selectorCalls++
    $script:readPhase = 'selector'
    Add-StubEvent 'selector-enter'
    $selectorOutput = @(Invoke-RealAbyssHandoffStart -Game $Game)
    $script:readPhase = 'main'
    $script:selectorReturned = $true
    $script:selectorReturnReadIndex = $script:readLog.Count
    $script:selectorOutputs = $selectorOutput
    Add-StubEvent 'selector-return'
    return $selectorOutput
}
function Test-CustomCleanupOnly {
    # 감시(워커 실제 서명) - 본류 정리 전용 판정(run:18382)이 받은 두 화면 인자를 적고 실제 술어로 (술어 run:353~361 무변경 - J6)
    param([bool]$CustomMode, [bool]$Restart, [bool]$InsideAlready, [bool]$OnResultScreen)
    $script:cleanupCalls.Add(('Inside={0} Result={1}' -f $InsideAlready, $OnResultScreen))
    return (Invoke-RealTestCustomCleanupOnly -CustomMode $CustomMode -Restart $Restart -InsideAlready $InsideAlready -OnResultScreen $OnResultScreen)
}
function Add-AbyssJournalClearedEntry {
    # 감시(워커 실제 서명 - 매개변수 없음) - 부른 순서를 사건 기록에 남기고 실제 기록 함수로(임시 폴더의 실제 완료 기록 파일)
    $script:clearedCalls++
    Add-StubEvent 'cleared'
    Invoke-RealAddAbyssJournalClearedEntry
}
function Consume-Handoff {
    # 감시 - 호출 수를 세고 실제 함수(워커 원문)로 넘깁니다. 실제 함수의 출력 개체를 그대로 돌려주고 따로 적어 둡니다(반환 'ok'/'stop' 하나 계약)
    $script:consumeCalls++
    $consumeOutput = @(Invoke-RealConsumeHandoff @args)
    $script:consumeOutputs = $consumeOutput
    return $consumeOutput
}
function Resolve-HandoffEnvForContext {
    # 감시(GUI 실제 서명 param($Context, [bool]$Restart = $false, [string]$ResumeNonce = '')) - 실제 함수로 넘기고 'Status/Kind' 를 적어 둡니다
    param($Context, [bool]$Restart = $false, [string]$ResumeNonce = '')
    $resolved = Invoke-RealResolveHandoffEnv @PSBoundParameters
    $script:resolveResults.Add(('{0}/{1}' -f $resolved.Status, $resolved.Kind))
    return $resolved
}
function Add-GuiLog {
    # GUI 자기 줄(GUI 실제 서명 param([string]$Message)) - 'gui|<메시지>'
    param([string]$Message)
    $script:guiEvents.Add('gui|' + $Message)
}
function Stop-AllRun {
    # 정지(GUI 실제 서명 param([string]$Reason, [switch]$IsError)) - 'stop|<사유>|<오류 여부>'
    param([string]$Reason, [switch]$IsError)
    $script:guiEvents.Add(('stop|{0}|{1}' -f $Reason, [bool]$IsError))
}
# GUI 컨트롤 모형 - 범위 술어(Test-AbyssHandoffRunActive · Test-AbyssMemberRunActive)가 읽는 라디오와 정지 갈래의 상태줄
$lblStatus = [pscustomobject]@{ Text = ''; ForeColor = $null }
$rbCatAbyss = [pscustomobject]@{ Checked = $true }
$rbModeParty = [pscustomobject]@{ Checked = $false }
$rbAbyssPartyMember = [pscustomobject]@{ Checked = $false }

# ===== 가상 시계 · 화면 모형 · 스텁 엔진 (단계 2.4~2.6 - 명세 ② 3.2 층 ① '화면 스텁 시퀀스 · 가상 시계 · 시각 창 주입') =====
# 회전 = 회전 머리 스텁(조작 양보 게이트 Test-UserRecentlyActive · 동결 블록의 Test-SafeStopDuringCaptureFail)이 불린 뒤의 구간. 판독 스텁은 시간을 쓰지 않고,
# Start-Sleep·양보 대기·스윕이 시계를 전진합니다. 판독 기록(회전 · 가상 초 · 함수 · 단계 · 화면 키 · 실패)은 계측 줄 숫자의 기대값을 다시 셀 때 씁니다
function Get-VirtualElapsed {
    # 행 시작부터 가상 초 (틱 나눗셈 - TotalSeconds 의 1e-7 곱은 경계에서 어긋남, test_abyss_return_loop 와 같은 이유)
    return (($script:vclock - $script:rowStartClock).Ticks / 10000000.0)
}
function Step-VirtualClock {
    # 가상 시계 전진 - 상한을 넘으면 예외(마감을 못 보는 변이가 행을 끝없이 돌리지 않게)
    param([double]$Milliseconds)
    if ($Milliseconds -le 0) { return }
    $script:vclock = $script:vclock.AddTicks([long][Math]::Round($Milliseconds * 10000))
    if ((Get-VirtualElapsed) -gt $VIRTUAL_TIME_LIMIT) { throw ('TEST-VTIMEOUT: 가상 시간 상한 {0}초를 넘었습니다' -f $VIRTUAL_TIME_LIMIT) }
}
function Add-StubEvent {
    # 사건 순서 기록 '단계|사건' (마커 → 기록 → 헬퍼 같은 순서 단언용)
    param([string]$Text)
    $script:eventLog.Add(('{0}|{1}' -f $script:readPhase, $Text))
}
function Enter-StubTurn {
    # 회전 머리 - 새 회전 번호와 그 시작 가상 초
    $script:turnId++
    $script:turnStartTimes[[string]$script:turnId] = Get-VirtualElapsed
}
function New-Timeline {
    # 평평한 (가상 초, 화면 키) 쌍 → 시각표 (그 시각부터 그 화면 - 시각 오름차순으로 적습니다). 열거용 반환 - 호출부 @()
    param([object[]]$Pairs)
    $timeline = @()
    for ($pairIndex = 0; $pairIndex -lt $Pairs.Count; $pairIndex += 2) { $timeline += [pscustomobject]@{ T = [double]$Pairs[$pairIndex]; S = [string]$Pairs[$pairIndex + 1] } }
    return $timeline
}
function New-Windows {
    # 평평한 (시작 초, 끝 초) 쌍 → 시각 창 목록 [시작, 끝). 열거용 반환 - 호출부 @()
    param([object[]]$Pairs)
    $windows = @()
    for ($pairIndex = 0; $pairIndex -lt $Pairs.Count; $pairIndex += 2) { $windows += [pscustomobject]@{ From = [double]$Pairs[$pairIndex]; Until = [double]$Pairs[$pairIndex + 1] } }
    return $windows
}
function Find-StubWindow {
    # 시각이 든 창 (없으면 $null)
    param([object[]]$Windows, [double]$Time)
    foreach ($window in @($Windows)) {
        if (($null -ne $window) -and ($Time -ge $window.From) -and ($Time -lt $window.Until)) { return $window }
    }
    return $null
}
function Get-ScreenSpec {
    # 화면 키 → 신호 묶음(해시) - 기본은 모든 판독 음성, 그 위에 화면 모형, 그 위에 덮어쓰기(본류 단계의 행 Main)
    param([string]$Key, $Overrides = $null)
    $spec = @{ Prompt = $false; Bottom = ''; Panel = 'none'; Hud = $false; Quest = $false; Selection = $false; Menu = $false; Detail = $false }
    if (-not $SCREEN_CATALOG.ContainsKey($Key)) { throw "TEST-SCREEN: 모르는 화면 키 [$Key]" }
    foreach ($catalogEntry in $SCREEN_CATALOG[$Key].GetEnumerator()) { $spec[$catalogEntry.Key] = $catalogEntry.Value }
    if ($null -ne $Overrides) { foreach ($overrideEntry in $Overrides.GetEnumerator()) { $spec[$overrideEntry.Key] = $overrideEntry.Value } }
    return $spec
}
function Get-StubScreenKey {
    # 지금 화면 키 - 순환(Cycle)이면 판독 회전 순번으로, 아니면 시각표의 '지금 이하 마지막 시각' 화면
    if ($null -ne $script:scenarioCycle) {
        $cycleIndex = [Math]::Max(0, [int]$script:readTurnIndex)
        return [string]$script:scenarioCycle[$cycleIndex % @($script:scenarioCycle).Count]
    }
    $nowSeconds = Get-VirtualElapsed
    $screenKey = 'U'
    foreach ($timelineEntry in @($script:scenarioTimeline)) { if ($nowSeconds -ge [double]$timelineEntry.T) { $screenKey = [string]$timelineEntry.S } }
    return $screenKey
}
function Register-StubCaptureFail {
    # 캡처 실패 등록 - 운영 Register-CaptureFailure 의 계약(일련번호 +1 · 플래그가 거짓이었으면 실패 시작 시각)
    $script:captureFailSerial++
    if (-not $script:screenCaptureFailing) {
        $script:screenCaptureFailing = $true
        $script:stubFailSince = $script:vclock
    }
}
function Register-StubCaptureSuccess {
    # 캡처 성공 등록 - 운영 Register-CaptureSuccess 의 계약(플래그 해제 · 실패 구간 누적)
    if ($script:screenCaptureFailing) {
        $script:stubFailTotalMs = [double]$script:stubFailTotalMs + ($script:vclock - $script:stubFailSince).TotalMilliseconds
        $script:screenCaptureFailing = $false
        $script:stubFailSince = $null
    }
}
function Get-StubFailTotalMs {
    # 캡처 실패 누적 ms = 끝난 구간 합 + 진행 중 구간 (운영 Get-CaptureFailTotalMs 계약)
    $failTotal = [double]$script:stubFailTotalMs
    if ($script:screenCaptureFailing -and ($null -ne $script:stubFailSince)) { $failTotal += ($script:vclock - $script:stubFailSince).TotalMilliseconds }
    return $failTotal
}
function Invoke-StubRead {
    # 판독 스텁 한 번 = 캡처 한 번. 캡처 실패 창 안이거나(CapFail) 판독 도중 실패 창 안 회전의 첫 판독이면(SerialFail - 그 회전의 뒤 판독은 성공 =
    # 일련번호만 바뀐 복구 회전) 실패 등록 뒤 $null, 아니면 성공 등록 뒤 화면 신호 묶음. 선분기 단계의 ReadFail 창 안이면 판독만 실패합니다(복구 탐침은
    # 성공 - 운영의 교대 모양 '판독에서 실패 시작 → 다음 회전 동결 탐침 복구', R4-N6r)
    param([string]$Name)
    $script:stubReadCalls++
    if ($script:stubReadCalls -gt $READ_CALL_LIMIT) { throw ('TEST-VTIMEOUT: 판독 스텁 호출 상한 {0}회를 넘었습니다' -f $READ_CALL_LIMIT) }
    if (($script:readPhase -eq 'selector') -and ($script:turnId -ne $script:lastReadTurnId)) {
        $script:lastReadTurnId = $script:turnId
        $script:readTurnIndex++
    }
    $nowSeconds = Get-VirtualElapsed
    $readFailed = ($null -ne (Find-StubWindow -Windows $script:scenarioCapFail -Time $nowSeconds))
    if ((-not $readFailed) -and ($script:readPhase -eq 'selector') -and ($null -ne (Find-StubWindow -Windows $script:scenarioReadFail -Time $nowSeconds))) { $readFailed = $true }
    if ((-not $readFailed) -and ($script:readPhase -eq 'selector') -and ($script:serialFailTurn -ne $script:turnId) -and
        ($null -ne (Find-StubWindow -Windows $script:scenarioSerialFail -Time $nowSeconds))) {
        $script:serialFailTurn = $script:turnId
        $readFailed = $true
    }
    $screenKey = Get-StubScreenKey
    $script:readLog.Add([pscustomobject]@{ Index = $script:readLog.Count; Turn = $script:turnId; T = $nowSeconds; Name = $Name; Phase = $script:readPhase; Key = $screenKey; Failed = $readFailed })
    if ($readFailed) {
        Register-StubCaptureFail
        return $null
    }
    Register-StubCaptureSuccess
    $screenOverrides = $null
    if ($script:readPhase -eq 'main') { $screenOverrides = $script:scenarioMain }
    return (Get-ScreenSpec -Key $screenKey -Overrides $screenOverrides)
}
function Invoke-StubFlagRead {
    # 참/거짓 판독 스텁 - 실패면 거짓(운영 판정 함수의 캡처 실패 반환과 같음)
    param([string]$Name, [string]$Field)
    $stubScreen = Invoke-StubRead -Name $Name
    if ($null -eq $stubScreen) { return $false }
    return [bool]$stubScreen[$Field]
}
function Invoke-StubProbe {
    # 복구 탐침(Test-CaptureRecovered) - 캡처 실패 창 안이면 실패 등록·거짓, 밖이면 성공 등록·참
    $script:probeCalls++
    Add-StubEvent 'probe'
    if ($null -ne (Find-StubWindow -Windows $script:scenarioCapFail -Time (Get-VirtualElapsed))) {
        Register-StubCaptureFail
        return $false
    }
    Register-StubCaptureSuccess
    return $true
}
function Invoke-StubSweep {
    # 팝업 스윕 - 스윕 창 안이면 '닫기 전송'(클릭 메타: 전송함 · 생략 사유 없음)으로 참, 스윕 자신의 시간만큼 시계를 전진. 그 회전을 '스윕 참 회전' 으로 적음(R4-K1).
    #   SweepSkip 창 안이면 '닫기' 를 사용자 조작으로 생략(클릭 메타: 전송 안 함 · 'user-active')한 참 - 양보는 다음 회전 게이트가 받습니다(위임 길: 양보 대기 1회를
    #   걸어 둠 - test_abyss_party_member 의 'ua-deleg' 와 같은 모양, R4-N16u). SweepYield 창 안이면 커서 대피가 조작을 만나 양보(양보 누적 +)한 뒤 팝업 없음 = 거짓
    #   (회전 서두 게이트가 못 보는 간접 양보 - 골격 ⑥, R4-N15i)
    $script:sweepCalls++
    if ($null -ne (Find-StubWindow -Windows $script:scenarioSweepSkip -Time (Get-VirtualElapsed))) {
        $script:sweepTrueTurns[[string]$script:turnId] = $true
        $script:lastClickPerformed = $false
        $script:lastClickSkipReason = 'user-active'
        $script:stubYieldQueue = [int]$script:stubYieldQueue + 1
        Add-StubEvent 'sweep-skip'
        Step-VirtualClock -Milliseconds $SWEEP_STUB_MS
        return $true
    }
    if ($null -ne (Find-StubWindow -Windows $script:scenarioSweepYield -Time (Get-VirtualElapsed))) {
        Add-StubEvent 'sweep-yield'
        Step-VirtualClock -Milliseconds $SWEEP_STUB_MS
        $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $SWEEP_STUB_MS
        return $false
    }
    if ($null -ne (Find-StubWindow -Windows $script:scenarioSweep -Time (Get-VirtualElapsed))) {
        $script:sweepTrueTurns[[string]$script:turnId] = $true
        $script:lastClickPerformed = $true
        $script:lastClickSkipReason = ''
        Add-StubEvent 'sweep-true'
        Step-VirtualClock -Milliseconds $SWEEP_STUB_MS
        return $true
    }
    return $false
}
function Invoke-StubYieldWait {
    # 조작 양보 대기 - 조작 창 끝까지 시계를 전진하고 그만큼 양보 누적($script:userYieldTotalMs - 운영 Wait-UserYieldEnd 계약)을 늘림. 문맥을 적어 둠
    param([string]$Context)
    $script:yieldContexts.Add($Context)
    if ([int]$script:stubYieldQueue -gt 0) {
        # 위임 길의 양보(스윕 클릭이 조작으로 생략된 뒤 다음 회전 게이트가 받는 대기) - 고정 시간만큼 기다리고 누적
        $script:stubYieldQueue = [int]$script:stubYieldQueue - 1
        Step-VirtualClock -Milliseconds $SKIP_YIELD_MS
        $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $SKIP_YIELD_MS
        return
    }
    $activeWindow = Find-StubWindow -Windows $script:scenarioActive -Time (Get-VirtualElapsed)
    if ($null -eq $activeWindow) { return }
    $waitMs = ([double]$activeWindow.Until - (Get-VirtualElapsed)) * 1000
    Step-VirtualClock -Milliseconds $waitMs
    $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $waitMs
}
function Reset-FlowState {
    # 단계 2.4~2.6 기록·가상 시계·캡처·양보 상태를 비웁니다(행마다 - 연쇄 행의 다음 기동도 같은 워커 새 실행이라 비움)
    $script:workerLogTimes.Clear()
    $script:eventLog.Clear()
    $script:readLog.Clear()
    $script:overlayLog.Clear()
    $script:diagLog.Clear()
    $script:returnLog.Clear()
    $script:classifyLog.Clear()
    $script:cleanupCalls.Clear()
    $script:yieldContexts.Clear()
    $script:updateTags.Clear()
    $script:updateOrdinals = @{}
    $script:turnStartTimes = @{}
    $script:sweepTrueTurns = @{}
    $script:vclock = $VIRTUAL_BASE
    $script:rowStartClock = $VIRTUAL_BASE
    $script:readPhase = 'main'
    $script:inStoreCall = 0
    $script:turnId = 0
    $script:lastReadTurnId = -1
    $script:readTurnIndex = -1
    $script:serialFailTurn = -1
    $script:stubReadCalls = 0
    $script:rawRegionReads = 0
    $script:sweepCalls = 0
    $script:probeCalls = 0
    $script:safeStopCalls = 0
    $script:selectorCalls = 0
    $script:selectorReturned = $false
    $script:selectorReturnReadIndex = -1
    $script:selectorOutputs = @()
    $script:selectorOverlayCount = 0
    $script:exitClickCalls = 0
    $script:clickUntilCalls = 0
    $script:markerCalls = 0
    $script:clearedCalls = 0
    $script:sleepMapHits = 0
    $script:stubYieldQueue = 0
    # 운영 공용 상태(캡처 계층 · 양보 누적 · 클릭 메타 · 하단 스태시)
    $script:screenCaptureFailing = $false
    $script:captureFailSerial = 0
    $script:stubFailTotalMs = [double]0
    $script:stubFailSince = $null
    $script:userYieldTotalMs = [double]0
    $script:lastClickPerformed = $true
    $script:lastClickSkipReason = ''
    $script:lastClearPromptText = ''
    $script:lastQuestTrackerText = ''
    Set-Scenario -Scenario @{}
}
function Set-Scenario {
    # 행 화면 시나리오 - Timeline(New-Timeline) / Cycle(판독 회전마다 순환할 화면 키) · CapFail · Active · Sweep · SerialFail(New-Windows) · AfterOverlay(정리 뒤
    # 시각표 - 상대 초) + AfterOverlayAt(몇 번째 정리에서) · Main(본류 단계 덮어쓰기) · MainOverlay(본류 run:18221 의 정리가 참 - 정리 뒤 시각표, 상대 초) ·
    # ReturnLoop('return' / 'exit4' - 복귀 루프가 던전 안 2연속 + 20초로 코드 4 인 모양) · LockPlan(@{ Phase; Ordinal; Mode }) · SleepMap(요청 ms → 가상 ms) ·
    # SweepSkip · SweepYield · ReadFail(New-Windows - 위 스텁 주석)
    param([hashtable]$Scenario)
    # 배열 값은 '$(if …)' 로 받지 않습니다 - 원소 하나짜리 배열이 풀려 스칼라가 됩니다(순환 화면 키를 글자로 색인하게 됨 - 규칙 3 의 배열 함정)
    $script:scenarioTimeline = @(New-Timeline -Pairs @(0, 'U'))
    if ($Scenario.ContainsKey('Timeline')) { $script:scenarioTimeline = @($Scenario.Timeline) }
    $script:scenarioCycle = $null
    if ($Scenario.ContainsKey('Cycle')) { $script:scenarioCycle = @($Scenario.Cycle) }
    $script:scenarioCapFail = @()
    if ($Scenario.ContainsKey('CapFail')) { $script:scenarioCapFail = @($Scenario.CapFail) }
    $script:scenarioActive = @()
    if ($Scenario.ContainsKey('Active')) { $script:scenarioActive = @($Scenario.Active) }
    $script:scenarioSweep = @()
    if ($Scenario.ContainsKey('Sweep')) { $script:scenarioSweep = @($Scenario.Sweep) }
    $script:scenarioSerialFail = @()
    if ($Scenario.ContainsKey('SerialFail')) { $script:scenarioSerialFail = @($Scenario.SerialFail) }
    $script:scenarioSweepSkip = @()
    if ($Scenario.ContainsKey('SweepSkip')) { $script:scenarioSweepSkip = @($Scenario.SweepSkip) }
    $script:scenarioSweepYield = @()
    if ($Scenario.ContainsKey('SweepYield')) { $script:scenarioSweepYield = @($Scenario.SweepYield) }
    $script:scenarioReadFail = @()
    if ($Scenario.ContainsKey('ReadFail')) { $script:scenarioReadFail = @($Scenario.ReadFail) }
    $script:scenarioAfterOverlay = $null
    if ($Scenario.ContainsKey('AfterOverlay')) { $script:scenarioAfterOverlay = @($Scenario.AfterOverlay) }
    $script:scenarioAfterOverlayAt = 1
    if ($Scenario.ContainsKey('AfterOverlayAt')) { $script:scenarioAfterOverlayAt = [int]$Scenario.AfterOverlayAt }
    $script:scenarioMain = $null
    if ($Scenario.ContainsKey('Main')) { $script:scenarioMain = $Scenario.Main }
    $script:scenarioMainOverlay = $null
    if ($Scenario.ContainsKey('MainOverlay')) { $script:scenarioMainOverlay = @($Scenario.MainOverlay) }
    $script:mainOverlayClosed = $false
    $script:returnLoopMode = 'return'
    if ($Scenario.ContainsKey('ReturnLoop')) { $script:returnLoopMode = [string]$Scenario.ReturnLoop }
    $script:lockPlan = @()
    if ($Scenario.ContainsKey('LockPlan')) { $script:lockPlan = @($Scenario.LockPlan) }
    $script:sleepMap = $null
    if ($Scenario.ContainsKey('SleepMap')) { $script:sleepMap = $Scenario.SleepMap }
}

# ===== 픽스처 · 행 하니스 =====
$testRootFolder = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_handoff_start_' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRootFolder)
$originalEnv = @{}
foreach ($envName in $TOUCHED_ENV_NAMES) { $originalEnv[$envName] = [Environment]::GetEnvironmentVariable($envName, 'Process') }

function Set-ProcessEnv {
    # 이 프로세스의 env 하나 - 빈 값이면 지웁니다(워커는 없음과 빈 값을 같게 읽음)
    param([string]$Name, [string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { [Environment]::SetEnvironmentVariable($Name, $null, 'Process') }
    else { [Environment]::SetEnvironmentVariable($Name, $Value, 'Process') }
}

function New-RowFolder {
    # 행마다 새 임시 폴더 - 완료 기록 경로를 스크립트 수준 $abyssJournalPath 에 둡니다(워커·GUI 함수가 그 이름을 그대로 읽음 - 행 함수에 같은 이름 지역 변수 금지)
    $rowFolder = Join-Path $testRootFolder ([guid]::NewGuid().ToString('N').Substring(0, 12))
    [void][IO.Directory]::CreateDirectory($rowFolder)
    $script:rowFolder = $rowFolder
    $script:abyssJournalPath = Join-Path $rowFolder 'abyss_handoff.json'
    return $rowFolder
}

function Get-FolderState {
    # 폴더의 파일 이름·SHA-256 앞 12자 목록 ('파일 불변' 단언용 - 잠금·임시·손상 증거 파일이 생겨도 드러남. 폴더는 빼고 봄)
    param([string]$Folder)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $parts = foreach ($filePath in @([IO.Directory]::GetFiles($Folder) | Sort-Object)) {
            '{0}:{1}' -f [IO.Path]::GetFileName($filePath), ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($filePath))).Replace('-', '').Substring(0, 12))
        }
    } finally {
        $sha.Dispose()
    }
    return (@($parts) -join ';')
}

function Close-HeldStreams {
    foreach ($heldStream in $script:heldStreams) { $heldStream.Dispose() }
    $script:heldStreams.Clear()
}

function Write-FixtureJournal {
    # 완료 기록 파일을 실제 직렬화(ConvertTo-AbyssJournalText)로 씁니다 (UTF-8 BOM - 저장소와 같은 인코딩)
    param([string]$Path, [object[]]$Entries = @(), [object[]]$Applied = @(), [long]$Seq = 5)
    $journal = New-AbyssJournalEmpty
    $journal.seq = $Seq
    $journal.savedAt = '2026-10-12T09:00:00.0000000+09:00'
    $journal.savedBy = 'worker:1234'
    $journal.entries = [object[]]@($Entries)
    $journal.applied = [object[]]@($Applied)
    [IO.File]::WriteAllText($Path, (ConvertTo-AbyssJournalText -Journal $journal), $UTF8_BOM)
}

function New-FixtureEntry {
    # 완료 기록 항목 픽스처 - 실제 New-AbyssJournalEntry 기본값 위에 필요한 필드만. -WithoutCleanupOnly = 그 필드가 없는 옛 항목(설계 R2 C8)
    param([string]$Stage, [string]$Nonce, $Owner, $NextOwner = $null, [int]$Generation = 0, [string]$LaunchState = 'launched',
        [string]$Section = '', [string]$RunId = '', $Decision = $null, [int]$AfterIndex = 0, $AfterTotal = $null, $AfterKeys = $null,
        [bool]$CleanupOnly = $false, [switch]$WithoutCleanupOnly)
    $entry = New-AbyssJournalEntry -Stage $Stage
    $entry.nonce = $Nonce
    $entry.runId = $RunId
    $entry.section = $Section
    $entry.generation = $Generation
    $entry.owner = $Owner
    $entry.nextOwner = $NextOwner
    $entry.decision = $Decision
    $entry.launchState = $LaunchState
    $entry.afterEntry.index = $AfterIndex
    $entry.afterEntry.total = $AfterTotal
    $entry.afterEntry.keys = $AfterKeys
    $entry.cleanupOnly = $CleanupOnly
    if ($WithoutCleanupOnly) { $entry.PSObject.Properties.Remove('cleanupOnly') }
    return $entry
}

function New-ChOwner {
    # CH 행의 커스텀 owner(5필드 - 진행 세대는 항목의 형제 필드)
    param([int]$Index = 0, [int]$Lap = 1)
    return [pscustomobject]@{ fingerprint = $CH_FINGERPRINT; orderKey = ''; lap = $Lap; index = $Index; item = $CH_ITEM_TOKENS[$Index] }
}

function ConvertTo-ChOwnerJson {
    # 커스텀 소유자 JSON - GUI ConvertTo-CustomMarkerOwnerJson 과 같은 version 3 모양(필드 순서 고정 · 세대 포함)
    param($Owner, [int]$Generation)
    return ([pscustomobject]@{ version = 3; fingerprint = [string]$Owner.fingerprint; orderKey = [string]$Owner.orderKey; lap = [int]$Owner.lap
            index = [int]$Owner.index; item = [string]$Owner.item; generation = $Generation } | ConvertTo-Json -Compress)
}
$CH_OWNER_JSON = ConvertTo-ChOwnerJson -Owner (New-ChOwner -Index 0) -Generation $CH_GENERATION

function New-ChOwnEntry {
    # CH 행의 커스텀 항목 - 기본은 열린 자기 항목(stage entered · owner = 이번 owner · 세대 일치 · 워커가 입장 때 쓰는 모양 launched · afterEntry {2, 2, [32,66]})
    param([string]$Nonce = $NONCE_A, [string]$Stage = 'entered', [int]$OwnerIndex = 0, [int]$Generation = $CH_GENERATION,
        [string]$LaunchState = 'launched', [bool]$CleanupOnly = $false, [switch]$WithoutCleanupOnly)
    return (New-FixtureEntry -Stage $Stage -Nonce $Nonce -Owner (New-ChOwner -Index $OwnerIndex) -Generation $Generation -Section $ABYSS_SECTION -RunId 'run-before' `
            -LaunchState $LaunchState -AfterIndex 2 -AfterTotal 2 -AfterKeys $CH_KEYS -CleanupOnly $CleanupOnly -WithoutCleanupOnly:$WithoutCleanupOnly)
}

function New-PlainEntry {
    # CH 행의 비커스텀 열린 자기 항목(owner { runId } · section '' · 세대 0)
    param([string]$Nonce = $NONCE_A, [string]$RunId = $CH_RUN_ID)
    return (New-FixtureEntry -Stage 'entered' -Nonce $Nonce -Owner ([pscustomobject]@{ runId = $RunId }) -RunId $RunId -LaunchState 'launched' -AfterIndex 2 -AfterTotal 2 -AfterKeys $CH_KEYS)
}

function Set-WorkerRowState {
    # 워커 상태 - 운영과 같은 순서: 커스텀 상태 초기값(run:781~793 의 해당 값) → env → 워커 원문 env 읽기 문장(커스텀이면 복구·소유자 JSON, 늘 실행 id) →
    # 기본값 대입(모든 실행) → finishOnly 대입. customMode 는 토큰 해석 결과라 행이 정합니다. -KeepHandoffEnv 면 handoff env 는 앞(GUI 기동)이 둔 그대로.
    # 세대 env 는 행이 준 값만 둡니다(빈 값 = 지움 - 실행 환경에 남은 값이 행에 섞이지 않게. 역할 판정은 소유자 JSON 의 세대만 봐야 함 - CH10g)
    param([bool]$Custom, [bool]$Recovery = $false, [string]$OwnerJson = '', [string]$RunId = '', [string]$Nonce = '', [string]$Resume = '',
        [string]$FinishOnly = '', [string]$GenerationEnv = '', [switch]$KeepHandoffEnv, [bool]$Restart = $false)
    $script:customMode = $Custom
    $script:customSpecInvalid = $false
    $script:customRecoveryOnly = $false
    $script:customRestart = $false          # 단계 2.6 - 재시작 env(커스텀이면 아래 원문 읽기 문장이 다시 정함 - run:838)
    $script:customCleanupOnly = $false      # run:789 초기값 - 본류 정리 전용 판정(run:18382)이 정함
    $script:customItem = $null              # 본류 시작 줄의 항목 라벨(Format-AbyssCustomItemLabel 은 $null 이면 '(항목 없음)')
    $script:customMarkerPath = ''
    $script:customOwnerJson = ''
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_RECOVERY' -Value $(if ($Recovery) { '1' } else { '' })
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_RESTART' -Value $(if ($Restart) { '1' } else { '' })
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_OWNER' -Value $OwnerJson
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_GENERATION' -Value $GenerationEnv
    Set-ProcessEnv -Name 'HONEYNOGI_RUN_ID' -Value $RunId
    if (-not $KeepHandoffEnv) {
        Set-ProcessEnv -Name 'HONEYNOGI_HANDOFF_NONCE' -Value $Nonce
        Set-ProcessEnv -Name 'HONEYNOGI_RESUME_REENTRY' -Value $Resume
        Set-ProcessEnv -Name 'HONEYNOGI_FINISH_ONLY' -Value $FinishOnly
    }
    if ($Custom) {
        . $script:workerRecoveryReadBlock
        if ($null -ne $script:workerRestartReadBlock) { . $script:workerRestartReadBlock }
        . $script:workerOwnerReadBlock
    }
    . $script:workerRunIdReadBlock
    . $script:workerHandoffDefaultBlock
    if ($null -ne $script:workerFinishOnlyReadBlock) { . $script:workerFinishOnlyReadBlock }
}

function Reset-RowCounters {
    $script:workerLogLines.Clear()
    $script:inputCalls.Clear()
    $script:guiEvents.Clear()
    $script:resolveResults.Clear()
    $script:journalReads = 0
    $script:journalUpdates = 0
    $script:consumeCalls = 0
    $script:consumeOutputs = @()
    $script:lastReadStatus = '(읽기 없음)'
    $script:lastReadWarnings = @()
    $script:sleepCalls = 0
    Reset-FlowState
}

function Initialize-HandoffRow {
    # 행 공통 준비 - 새 임시 폴더 · 완료 기록 픽스처(Entries 없음 = 파일 없음 · 원문 손상 · 직전본) · .lock 자리 폴더 · 워커 상태 · 감시 횟수 비움 ·
    # 파일 상태 지문 · (선택) 잠금 쥐기. 키: Custom Recovery Restart OwnerJson RunId Nonce Resume FinishOnly GenerationEnv Entries Applied MainText BakEntries BakText
    # HoldLock LockFolder KeepFolder(연쇄 행의 다음 기동 - 폴더·완료 기록은 앞 기동이 남긴 그대로, env·워커 상태만 다시)
    param([hashtable]$Row)
    if (-not $Row.KeepFolder) {
        [void](New-RowFolder)
        $script:dynamicNonceLabels = @{}
    }
    $journalFile = $script:abyssJournalPath
    if (-not $Row.KeepFolder) {
        $appliedNonces = @()
        if ($Row.ContainsKey('Applied')) { $appliedNonces = @($Row.Applied) }
        if ($Row.ContainsKey('Entries')) { Write-FixtureJournal -Path $journalFile -Entries @($Row.Entries) -Applied $appliedNonces }
        if ($Row.MainText) { [IO.File]::WriteAllText($journalFile, [string]$Row.MainText, $UTF8_BOM) }
        if ($Row.ContainsKey('BakEntries')) { Write-FixtureJournal -Path ($journalFile + '.bak') -Entries @($Row.BakEntries) -Applied $appliedNonces -Seq 4 }
        if ($Row.BakText) { [IO.File]::WriteAllText(($journalFile + '.bak'), [string]$Row.BakText, $UTF8_BOM) }
    }
    $lockPath = [IO.Path]::ChangeExtension($journalFile, '.lock')
    if ($Row.LockFolder) { [void][IO.Directory]::CreateDirectory($lockPath) }
    $ownerJson = $CH_OWNER_JSON
    if ($Row.ContainsKey('OwnerJson')) { $ownerJson = [string]$Row.OwnerJson }
    $runIdValue = $CH_RUN_ID
    if ($Row.ContainsKey('RunId')) { $runIdValue = [string]$Row.RunId }
    Set-WorkerRowState -Custom ([bool]$Row.Custom) -Recovery ([bool]$Row.Recovery) -OwnerJson $ownerJson -RunId $runIdValue -Nonce ([string]$Row.Nonce) `
        -Resume ([string]$Row.Resume) -FinishOnly ([string]$Row.FinishOnly) -GenerationEnv ([string]$Row.GenerationEnv) -Restart ([bool]$Row.Restart)
    Reset-RowCounters
    $script:rowStateBefore = Get-FolderState -Folder $script:rowFolder
    if ($Row.HoldLock) {
        $script:heldStreams.Add((New-Object System.IO.FileStream($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)))
    }
}

function Format-AfterEntry {
    # AfterEntry → '인덱스/키들'(값 없음 'null'). 해시테이블의 'Keys' 항목은 같은 이름 속성(KeyCollection)과 겹치므로 저장소의 공용 필드 읽기
    # (Get-AbyssJournalField - 해시테이블·객체 공용 · 항목이 있을 때만 그 값)로 읽습니다
    param($AfterEntry)
    if ($null -eq $AfterEntry) { return 'null' }
    $indexField = Get-AbyssJournalField -Object $AfterEntry -Name 'Index'
    $keysField = Get-AbyssJournalField -Object $AfterEntry -Name 'Keys'
    $indexText = '(없음)'
    if ($indexField.Has) { $indexText = [string]$indexField.Value }
    $keysText = '(없음)'
    if ($keysField.Has) {
        if ($null -eq $keysField.Value) { $keysText = 'null' } else { $keysText = (@($keysField.Value) | ForEach-Object { [string]$_ }) -join ',' }
    }
    return ('{0}/{1}' -f $indexText, $keysText)
}

function Get-HandoffSnapshot {
    # $script:handoff → 단언용 값 (해시테이블·객체 공용 읽기 - 필드가 없으면 '(필드 없음)')
    $handoffState = $script:handoff
    $fields = @{}
    foreach ($fieldName in @('Role', 'Nonce', 'CleanupOnly', 'JournalState', 'AfterEntry', 'FreshEntry', 'StartScreen')) { $fields[$fieldName] = Get-AbyssJournalField -Object $handoffState -Name $fieldName }
    $missing = '(필드 없음)'
    return [pscustomobject]@{
        Role         = $(if ($fields.Role.Has) { [string]$fields.Role.Value } else { $missing })
        Nonce        = $(if ($fields.Nonce.Has) { Get-NonceLabel ([string]$fields.Nonce.Value) } else { $missing })
        CleanupOnly  = $(if ($fields.CleanupOnly.Has) { [string][bool]$fields.CleanupOnly.Value } else { $missing })
        JournalState = $(if ($fields.JournalState.Has) { [string]$fields.JournalState.Value } else { $missing })
        AfterEntry   = $(if ($fields.AfterEntry.Has) { Format-AfterEntry $fields.AfterEntry.Value } else { $missing })
        # 두 필드는 선분기(단계 2.5)가 씁니다 - Consume-Handoff 뒤에는 기본값 그대로여야 합니다(CH10s·CH13s·CH14s)
        FreshEntry   = $(if ($fields.FreshEntry.Has) { [string][bool]$fields.FreshEntry.Value } else { $missing })
        StartScreen  = $(if ($fields.StartScreen.Has) { [string]$fields.StartScreen.Value } else { $missing })
    }
}

function New-RowResult {
    # 행 결과 - 반환 · 예외 · exit · $roleNone · handoff 필드 · 로그 · 읽기/쓰기 · 입력 · 저장소 상태 · 파일 불변
    param([object[]]$Outputs = @(), [string]$Thrown = '', [string]$ExitCode = '', [string]$RoleNone = '')
    $snapshot = Get-HandoffSnapshot
    return [pscustomobject]@{
        Returned     = (Format-Outputs -Outputs $Outputs)
        Thrown       = $Thrown
        ExitCode     = $ExitCode
        RoleNone     = $RoleNone
        Role         = $snapshot.Role
        Nonce        = $snapshot.Nonce
        CleanupOnly  = $snapshot.CleanupOnly
        AfterEntry   = $snapshot.AfterEntry
        JournalState = $snapshot.JournalState
        FreshEntry   = $snapshot.FreshEntry
        StartScreen  = $snapshot.StartScreen
        Logs         = (Format-Logs -Lines @($script:workerLogLines))
        Reads        = $script:journalReads
        Updates      = $script:journalUpdates
        ConsumeCalls = $script:consumeCalls
        Inputs       = $script:inputCalls.Count
        ReadStatus   = $script:lastReadStatus
        ReadWarnings = @($script:lastReadWarnings)
        Unchanged    = [string]((Get-FolderState -Folder $script:rowFolder) -ceq $script:rowStateBefore)
    }
}

function Invoke-ConsumeRow {
    # 함수 층 한 행 - 준비 → 실제 Consume-Handoff 1번(감시 경유) → 결과
    param([hashtable]$Row)
    Initialize-HandoffRow -Row $Row
    $consumeThrown = ''
    $consumeResult = @()
    try {
        $consumeResult = @(Consume-Handoff)
    } catch {
        $consumeThrown = [string]$_.Exception.Message
    } finally {
        Close-HeldStreams
    }
    return (New-RowResult -Outputs $consumeResult -Thrown $consumeThrown -RoleNone '(층 ① - 해당 없음)')
}

function Invoke-MainSegmentRow {
    # 본류 시작 구간 층 한 행 - 준비 → 워커 최상위 try 의 형제 문장 사본(exit → Stop-WorkerTailExit)을 이 함수 범위에 점소싱 → 결과.
    # 앞 변수는 운영 대입과 같은 값: $contentCategory(config 값) · $script:customSpecInvalid(커스텀 토큰 해석) · $game(이 단계 구간은 화면을 보지 않음 - $null).
    # 지역 변수 이름은 segment 접두 - 점소싱한 워커 문장이 같은 이름을 쓰면 섞이므로
    param([hashtable]$SegmentRow)
    Initialize-HandoffRow -Row $SegmentRow
    $script:customSpecInvalid = [bool]$SegmentRow.SpecInvalid
    $contentCategory = [string]$SegmentRow.ContentCategory
    $game = $null
    $roleNone = '(미대입)'
    $segmentExitCode = ''
    $segmentThrown = ''
    try {
        . $script:mainSegmentBlock
    } catch {
        $segmentMessage = [string]$_.Exception.Message
        if ($segmentMessage.StartsWith($WORKER_EXIT_PREFIX)) { $segmentExitCode = $segmentMessage.Substring($WORKER_EXIT_PREFIX.Length) } else { $segmentThrown = $segmentMessage }
    } finally {
        Close-HeldStreams
    }
    return (New-RowResult -Outputs @($script:consumeOutputs) -Thrown $segmentThrown -ExitCode $segmentExitCode -RoleNone ([string]$roleNone))
}

function New-AbyssContext {
    # Get-CustomCurrentContext 반환 모양의 어비스 커스텀 컨텍스트 (순차 · 목록 = $ABYSS_ITEMS - ⑯ 와 같은 모양)
    param([int]$Index, [int]$Lap = 1, [int]$Generation = 0)
    return @{
        Items = $ABYSS_ITEMS; ExecutionItems = $ABYSS_ITEMS; Total = $ABYSS_ITEMS.Count; RegisteredTotal = $ABYSS_ITEMS.Count
        Lap = $Lap; Index = $Index; Item = $ABYSS_ITEMS[$Index]; RegisteredIndex = $Index
        RandomOrder = $false; Order = $null; ShuffleValid = $true
        ListRepeat = 'infinite'; ListRepeatCount = 1; SectionName = $ABYSS_SECTION
        Position = ('{0}바퀴째 {1}/{2}번' -f $Lap, ($Index + 1), $ABYSS_ITEMS.Count); Generation = $Generation
    }
}

function ConvertTo-FiveFieldOwner {
    # 완료 기록 항목의 owner 모양(5필드 - 진행 세대는 항목의 형제 필드)
    param($Owner)
    return [pscustomobject]@{ fingerprint = [string]$Owner.fingerprint; orderKey = [string]$Owner.orderKey; lap = [int]$Owner.lap; index = [int]$Owner.index; item = [string]$Owner.item }
}

function Get-DiskLaunchState {
    # 디스크의 완료 기록에서 그 nonce 항목의 launchState (저장소를 거치지 않고 그대로 읽음)
    param([string]$Path, [string]$Nonce)
    if (-not [IO.File]::Exists($Path)) { return '(파일 없음)' }
    try {
        $journal = [IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return '(읽기 실패)'
    }
    foreach ($entry in @($journal.entries)) { if ([string]$entry.nonce -eq $Nonce) { return [string]$entry.launchState } }
    return '(항목 없음)'
}

function Invoke-LaunchRoleRow {
    # L 행 - GUI 원문 기동 env(Set-HandoffLaunchEnv → Resolve-HandoffEnvForContext) → Start-NextCycle 이 넣는 값과 같은 출처의 워커 env(OWNER = GUI
    # New-CustomMarkerOwnerJson · RUN_ID = 실행 id · RECOVERY 빈 값 - 일반 시작) → 워커 원문 env 읽기 → 실제 Consume-Handoff. GUI 상태는 전투 · 어비스 혼자하기
    # (범위 술어 참) · 재시작 아님. 기동 전 handoff env 에 묵은 값을 넣어 둡니다(GUI '먼저 비움' 을 함께 지남)
    param([bool]$Custom, $Context = $null, [object[]]$Entries = @(), [object[]]$Applied = @(), [string]$WatchNonce = $NONCE_A)
    [void](New-RowFolder)
    Write-FixtureJournal -Path $script:abyssJournalPath -Entries $Entries -Applied $Applied
    $script:mainCategory = 'battle'
    $rbCatAbyss.Checked = $true
    $rbModeParty.Checked = $false
    $rbAbyssPartyMember.Checked = $false
    $script:customActive = $Custom
    $script:runId = $L_RUN_ID
    $script:customRestart = $false
    $script:lastLaunchKind = $STALE_VALUE
    $script:lastLaunchNonce = $STALE_VALUE
    foreach ($envName in $HANDOFF_ENV_NAMES) { Set-ProcessEnv -Name $envName -Value $STALE_VALUE }
    Reset-RowCounters
    $stateBefore = Get-FolderState -Folder $script:rowFolder
    $launchThrown = ''
    $launchOk = '(호출 실패)'
    try {
        $launchOk = [string](Set-HandoffLaunchEnv -CustomContext $Context)
    } catch {
        $launchThrown = [string]$_.Exception.Message
    }
    $launchKind = [string]$script:lastLaunchKind
    $nonceEnv = Get-NonceLabel ([string][Environment]::GetEnvironmentVariable('HONEYNOGI_HANDOFF_NONCE', 'Process'))
    $resumeEnv = [string][Environment]::GetEnvironmentVariable('HONEYNOGI_RESUME_REENTRY', 'Process')
    $launchState = Get-DiskLaunchState -Path $script:abyssJournalPath -Nonce $WatchNonce
    $ownerJson = ''
    if ($Custom) { $ownerJson = [string](New-CustomMarkerOwnerJson -Context $Context) }
    Set-WorkerRowState -Custom $Custom -OwnerJson $ownerJson -RunId $L_RUN_ID -KeepHandoffEnv
    $script:workerLogLines.Clear()
    $script:journalReads = 0
    $script:journalUpdates = 0
    $workerThrown = ''
    $workerResult = @()
    try {
        $workerResult = @(Consume-Handoff)
    } catch {
        $workerThrown = [string]$_.Exception.Message
    }
    $snapshot = Get-HandoffSnapshot
    return [pscustomobject]@{
        Resolve      = (@($script:resolveResults) -join ',')
        LaunchOk     = $launchOk
        Kind         = $launchKind
        NonceEnv     = $nonceEnv
        ResumeEnv    = $resumeEnv
        LaunchState  = $launchState
        GuiEvents    = (@($script:guiEvents) -join ' || ')
        GuiThrown    = $launchThrown
        Returned     = (Format-Outputs -Outputs $workerResult)
        Role         = $snapshot.Role
        Nonce        = $snapshot.Nonce
        Logs         = (Format-Logs -Lines @($script:workerLogLines))
        Reads        = $script:journalReads
        Updates      = $script:journalUpdates
        WorkerThrown = $workerThrown
        Unchanged    = [string]((Get-FolderState -Folder $script:rowFolder) -ceq $stateBefore)
    }
}

# ===== 단계 2.4~2.6 행 하니스 (층 ① 선분기 · 층 ② 본류 시작 구간) =====
$script:roleFlowOutcomes = New-Object System.Collections.Generic.List[psobject]   # 하니스 단언 - 층 ② 의 Role≠none 행 결과(행 이름 · exit · $startInsideDetected)

function Get-JournalView {
    # 완료 기록 본 파일을 저장소를 거치지 않고 그대로 읽은 항목 요약 - 워커가 만든 새 nonce 는 파일 순서대로 NEW1, NEW2 … 이름을 붙입니다
    param([string]$Path)
    $view = [pscustomobject]@{ Entries = @(); Applied = @(); Error = '' }
    if (-not [IO.File]::Exists($Path)) {
        $view.Error = '(파일 없음)'
        return $view
    }
    try {
        $journal = [IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $view.Error = '(읽기 실패)'
        return $view
    }
    $viewEntries = @()
    foreach ($journalEntry in @($journal.entries)) {
        if ($null -eq $journalEntry) { continue }
        $entryNonce = [string]$journalEntry.nonce
        if ((-not $NONCE_LABELS.ContainsKey($entryNonce)) -and (-not $script:dynamicNonceLabels.ContainsKey($entryNonce))) {
            $script:dynamicNonceLabels[$entryNonce] = 'NEW' + ($script:dynamicNonceLabels.Count + 1)
        }
        $afterKeysText = 'null'
        if ($null -ne $journalEntry.afterEntry.keys) { $afterKeysText = (@($journalEntry.afterEntry.keys) | ForEach-Object { [string]$_ }) -join ',' }
        $ownerIndexText = ''
        if (($null -ne $journalEntry.owner) -and ($null -ne $journalEntry.owner.PSObject.Properties['index'])) { $ownerIndexText = [string]$journalEntry.owner.index }
        $viewEntries += [pscustomobject]@{
            Label       = (Get-NonceLabel $entryNonce)
            Nonce       = $entryNonce
            Stage       = [string]$journalEntry.stage
            LaunchState = [string]$journalEntry.launchState
            Reason      = $(if ($null -ne $journalEntry.PSObject.Properties['reason']) { [string]$journalEntry.reason } else { '' })
            Screen      = $(if ($null -ne $journalEntry.PSObject.Properties['screen']) { [string]$journalEntry.screen } else { '' })
            CleanupOnly = $(if ($null -ne $journalEntry.PSObject.Properties['cleanupOnly']) { [string][bool]$journalEntry.cleanupOnly } else { '(없음)' })
            Index       = [string]$journalEntry.afterEntry.index
            Total       = [string]$journalEntry.afterEntry.total
            Keys        = $afterKeysText
            Section     = [string]$journalEntry.section
            Generation  = [string]$journalEntry.generation
            Decision    = [string]$journalEntry.decision
            OwnerIndex  = $ownerIndexText
            RunId       = [string]$journalEntry.runId
        }
    }
    $view.Entries = $viewEntries
    $appliedLabels = @()
    foreach ($appliedNonce in @($journal.applied)) { if ($null -ne $appliedNonce) { $appliedLabels += (Get-NonceLabel ([string]$appliedNonce)) } }
    $view.Applied = $appliedLabels
    return $view
}

function Format-JournalEntry {
    # 항목 요약 → '이름:stage/launchState/reason/screen' (없으면 '(항목 없음)')
    param($Entry)
    if ($null -eq $Entry) { return '(항목 없음)' }
    return ('{0}:{1}/{2}/{3}/{4}' -f $Entry.Label, $Entry.Stage, $Entry.LaunchState, $Entry.Reason, $Entry.Screen)
}

function Find-JournalEntry {
    # 이름(NA~ND · NEWn)으로 항목 요약 하나 (없으면 $null)
    param($View, [string]$Label)
    foreach ($viewEntry in @($View.Entries)) { if ($viewEntry.Label -eq $Label) { return $viewEntry } }
    return $null
}

function Get-OpenEntryLabels {
    # 열린(stage entered · done 아님) 항목 이름들 - ','
    param($View)
    return (@(@($View.Entries) | Where-Object { ($_.Stage -eq 'entered') -and ($_.LaunchState -ne 'done') } | ForEach-Object { $_.Label }) -join ',')
}

function Get-NewEntryLabels {
    # 워커가 만든 새 항목 이름들 - ','
    param($View)
    return (@(@($View.Entries) | Where-Object { $_.Label -like 'NEW*' } | ForEach-Object { $_.Label }) -join ',')
}

function New-FlowResult {
    # 층 ①·② 한 행의 결과 - exit · 예외 · $roleNone · $startInsideDetected · handoff 필드 · 로그(가상 시각) · 진단 · 이벤트 정리 · 복귀 루프 · 입력 ·
    # 완료 기록 보기 · 파일 불변 · 선분기 판독 회전 · 본류 단계 판독 증가분 · 양보·캡처 실패 누적
    param([string]$ExitCode, [string]$Thrown, [string]$RoleNone, [string]$StartInside, [string]$Layer)
    $journalView = Get-JournalView -Path $script:abyssJournalPath
    $snapshot = Get-HandoffSnapshot
    $turnMap = [ordered]@{}
    foreach ($readRecord in $script:readLog) {
        if ($readRecord.Phase -ne 'selector') { continue }
        $turnKey = [string]$readRecord.Turn
        if (-not $turnMap.Contains($turnKey)) { $turnMap[$turnKey] = [pscustomobject]@{ Turn = $readRecord.Turn; T = [double]$readRecord.T; Key = [string]$readRecord.Key; Valid = $true } }
        if ($readRecord.Failed) { $turnMap[$turnKey].Valid = $false }
    }
    $postCounts = @{}
    foreach ($postName in $POST_READ_NAMES) { $postCounts[$postName] = 0 }
    $postText = '(선분기 반환 없음)'
    if ($script:selectorReturned) {
        for ($readIndex = [int]$script:selectorReturnReadIndex; $readIndex -lt $script:readLog.Count; $readIndex++) {
            $postName = [string]$script:readLog[$readIndex].Name
            if ($postCounts.ContainsKey($postName)) { $postCounts[$postName] = [int]$postCounts[$postName] + 1 }
        }
        $postText = (@($POST_READ_NAMES | ForEach-Object { '{0}={1}' -f $_, $postCounts[$_] }) -join ' · ')
    }
    return [pscustomobject]@{
        Layer = $Layer; ExitCode = $ExitCode; Thrown = $Thrown; RoleNone = $RoleNone; StartInside = $StartInside
        CustomCleanupOnly = [string][bool]$script:customCleanupOnly
        Role = $snapshot.Role; Nonce = $snapshot.Nonce; CleanupOnly = $snapshot.CleanupOnly; FreshEntry = $snapshot.FreshEntry
        StartScreen = $snapshot.StartScreen; AfterEntry = $snapshot.AfterEntry; JournalState = $snapshot.JournalState
        ConsumeCalls = $script:consumeCalls; Returned = (Format-Outputs -Outputs @($script:consumeOutputs))
        Lines = @($script:workerLogLines); LineTimes = @($script:workerLogTimes)
        Diags = @($script:diagLog); Overlays = @($script:overlayLog); Returns = @($script:returnLog)
        ExitClicks = $script:exitClickCalls; ClickUntils = $script:clickUntilCalls; Markers = $script:markerCalls; ClearedCalls = $script:clearedCalls
        Inputs = $script:inputCalls.Count; InputList = (@($script:inputCalls) -join ' / '); CleanupCalls = (@($script:cleanupCalls) -join ' / ')
        Events = @($script:eventLog); Journal = $journalView
        Unchanged = [string]((Get-FolderState -Folder $script:rowFolder) -ceq $script:rowStateBefore)
        SelectorCalls = $script:selectorCalls; SelectorReturned = [string]$script:selectorReturned; PostReads = $postText
        Turns = @($turnMap.Values); EndT = (Get-VirtualElapsed); YieldContexts = (@($script:yieldContexts) -join ' / ')
        SafeStopCalls = $script:safeStopCalls; ProbeCalls = $script:probeCalls; SweepCalls = $script:sweepCalls
        Updates = $script:journalUpdates; UpdateTags = (@($script:updateTags) -join ' '); SleepMapHits = $script:sleepMapHits; RawRegionReads = $script:rawRegionReads
        ClassifyLog = @($script:classifyLog); SweepTrueTurns = @($script:sweepTrueTurns.Keys); ReadLog = @($script:readLog)
        FailTotalMs = (Get-StubFailTotalMs); YieldTotalMs = [double]$script:userYieldTotalMs
    }
}

function Invoke-FlowRow {
    # 층 ①('selector' = 2.1 블록 ~ $roleNone 대입) · 층 ②('main' = 2.1 블록 ~ run:18527 앞) 한 행 - 준비 → 행 함수 범위에서 구간 점소싱 → 결과.
    # 앞 변수는 운영 대입과 같은 값: $contentCategory(config 'abyss') · $game($null - 화면은 스텁) · $deepMode(어비스 거짓) · $timeoutPartyMatch(소스 캡처값,
    # 행이 Tpm 을 주면 그 값 - R4-N6‴). 층 ② 는 2.1 블록 앞의 첫 시작 판독(run:18181 원문)부터 돌립니다. 지역 변수 이름은 flow 접두 - 점소싱한 워커 문장과
    # 섞이지 않게(점소싱한 문장이 만든 $roleNone · $startInsideDetected 는 이 범위에 남아 결과로 읽음)
    param([hashtable]$FlowRow, [string]$FlowLayer)
    Initialize-HandoffRow -Row $FlowRow
    if ($FlowRow.ContainsKey('Scenario')) { Set-Scenario -Scenario $FlowRow.Scenario }
    $contentCategory = 'abyss'
    $game = $null
    $deepMode = $false
    $timeoutPartyMatch = $capturedTimeoutPartyMatch
    if ($FlowRow.ContainsKey('Tpm')) { $timeoutPartyMatch = [int]$FlowRow.Tpm }
    $roleNone = '(미대입)'
    $startInsideDetected = '(미대입)'
    $flowExitCode = ''
    $flowThrown = ''
    try {
        if ($FlowLayer -eq 'main') {
            . $script:preFlowBlock
            [void]@(. $script:mainFlowBlock)
        } else {
            [void]@(. $script:mainSegmentBlock)
        }
    } catch {
        $flowMessage = [string]$_.Exception.Message
        if ($flowMessage.StartsWith($WORKER_EXIT_PREFIX)) { $flowExitCode = $flowMessage.Substring($WORKER_EXIT_PREFIX.Length) } else { $flowThrown = $flowMessage }
    } finally {
        Close-HeldStreams
    }
    $flowInsideText = '(층 ① - 해당 없음)'
    if ($FlowLayer -eq 'main') { $flowInsideText = [string]$startInsideDetected }
    $flowResult = New-FlowResult -ExitCode $flowExitCode -Thrown $flowThrown -RoleNone ([string]$roleNone) -StartInside $flowInsideText -Layer $FlowLayer
    if (($FlowLayer -eq 'main') -and ($flowResult.Role -ne 'none')) {
        $script:roleFlowOutcomes.Add([pscustomobject]@{ Name = [string]$FlowRow.Name; Role = $flowResult.Role; ExitCode = $flowExitCode; StartInside = $flowInsideText; Thrown = $flowThrown })
    }
    return $flowResult
}

function New-OwnFlowRow {
    # own 기동 픽스처 - 열린 자기 항목 NA(entered · owner·세대 일치 · launched · afterEntry {2, 2, [32,66]} · 정리 전용 표지 = -CleanupOnly) + 받은 nonce NA
    # (설계 v11 R4 5.3 머리). 키: Name · Scenario · Extra(행 키 덧붙임 - Restart · FinishOnly · Tpm 등)
    param([string]$Name, [hashtable]$Scenario, [bool]$CleanupOnly = $false, [hashtable]$Extra = @{})
    $flowRow = @{ Name = $Name; Custom = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry -CleanupOnly $CleanupOnly)); Scenario = $Scenario }
    foreach ($extraEntry in $Extra.GetEnumerator()) { $flowRow[$extraEntry.Key] = $extraEntry.Value }
    return $flowRow
}

function New-NextEntry {
    # next 픽스처 항목 - reentered NB · nextOwner = 이번 컨텍스트(커스텀: 5필드 index 0 · 세대 3 / 비커스텀: { runId }) · 첫 키 기록 전(index 0 · keys null)
    # (설계 v11 R4 5.2 머리)
    param([bool]$Custom = $true)
    if ($Custom) {
        return (New-FixtureEntry -Stage 'reentered' -Nonce $NONCE_B -Owner (New-ChOwner -Index 2) -NextOwner (New-ChOwner -Index 0) -Generation $CH_GENERATION `
                -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'launched' -AfterIndex 0)
    }
    return (New-FixtureEntry -Stage 'reentered' -Nonce $NONCE_B -Owner ([pscustomobject]@{ runId = $CH_RUN_ID }) -NextOwner ([pscustomobject]@{ runId = $CH_RUN_ID }) `
            -RunId $CH_RUN_ID -LaunchState 'launched' -AfterIndex 0)
}

function New-NextFlowRow {
    # next 기동 픽스처 - 위 항목 + 받은 nonce NB
    param([string]$Name, [hashtable]$Scenario, [bool]$Custom = $true, [hashtable]$Extra = @{})
    $flowRow = @{ Name = $Name; Custom = $Custom; Nonce = $NONCE_B; Entries = @((New-NextEntry -Custom $Custom)); Scenario = $Scenario }
    foreach ($extraEntry in $Extra.GetEnumerator()) { $flowRow[$extraEntry.Key] = $extraEntry.Value }
    return $flowRow
}

function Assert-True {
    # 조건 단언 - 실패 줄에 실제 값(Detail)을 함께
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { "OK   {0}" -f $Name }
    else { "FAIL {0}: {1}" -f $Name, $Detail; $script:fails++ }
}

function Format-Seconds {
    # 가상 초 표기 (소수 셋째 자리 · 문화권 무관)
    param([double]$Value)
    return [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $Value)
}

function Get-LineCount {
    # 정확히 같은 로그 줄 수
    param($Result, [string]$Line)
    return @(@($Result.Lines) | Where-Object { $_ -ceq $Line }).Count
}

function Get-LineIndex {
    # 정확히 같은 첫 로그 줄의 자리 (없으면 -1)
    param($Result, [string]$Line)
    $resultLines = @($Result.Lines)
    for ($lineIndex = 0; $lineIndex -lt $resultLines.Count; $lineIndex++) { if ($resultLines[$lineIndex] -ceq $Line) { return $lineIndex } }
    return -1
}

function Get-PatternIndex {
    # 정규식에 맞는 첫 로그 줄의 자리 (없으면 -1)
    param($Result, [string]$Pattern)
    $resultLines = @($Result.Lines)
    for ($lineIndex = 0; $lineIndex -lt $resultLines.Count; $lineIndex++) { if ($resultLines[$lineIndex] -cmatch $Pattern) { return $lineIndex } }
    return -1
}

function Get-PatternLines {
    # 정규식에 맞는 로그 줄들
    param($Result, [string]$Pattern)
    return @(@($Result.Lines) | Where-Object { $_ -cmatch $Pattern })
}

function Get-StopLines {
    # [완료] 정지 줄들 - ' || '
    param($Result)
    return (@(@($Result.Lines) | Where-Object { $_.StartsWith('[완료]') }) -join ' || ')
}

function Get-DiagText {
    # 진단 캡처 이름들(단계 지정 시 그 단계만) - ','
    param($Result, [string]$Phase = '')
    return (@(@($Result.Diags) | Where-Object { (-not $Phase) -or ($_.Phase -eq $Phase) } | ForEach-Object { $_.Context }) -join ',')
}

function Get-OverlayTimes {
    # 그 단계의 이벤트 정리 호출 가상 초들
    param($Result, [string]$Phase = 'selector')
    return @(@($Result.Overlays) | Where-Object { $_.Phase -eq $Phase } | ForEach-Object { [double]$_.T })
}

function Get-ReturnText {
    # 복귀 루프 호출들 '코드/사유' - ','
    param($Result)
    return (@(@($Result.Returns) | ForEach-Object { '{0}/{1}' -f $_.Code, $_.Reason }) -join ',')
}

function Get-ValidTurns {
    # 선분기 단계의 유효 판독 회전(화면 키 지정 시 그 키만)
    param($Result, [string]$Key = '')
    return @(@($Result.Turns) | Where-Object { $_.Valid -and ((-not $Key) -or ($_.Key -eq $Key)) })
}

function Get-EventPosition {
    # 사건 기록에서 그 사건 이름(접두)이 처음 나온 자리 (없으면 -1)
    param($Result, [string]$Name)
    $resultEvents = @($Result.Events)
    for ($eventIndex = 0; $eventIndex -lt $resultEvents.Count; $eventIndex++) {
        $eventText = ([string]$resultEvents[$eventIndex] -split '\|', 2)[1]
        if ($eventText.StartsWith($Name)) { return $eventIndex }
    }
    return -1
}

function Get-PostReadsExpected {
    # 본류 단계 판독 증가분의 기대 문자열 - 메뉴 판독(run:18409 - 모든 Role)만 $Menu 회, 그 밖 0
    param([int]$Menu = 1)
    return (@($POST_READ_NAMES | ForEach-Object { '{0}={1}' -f $_, $(if ($_ -eq 'Test-AbyssMenu') { $Menu } else { 0 }) }) -join ' · ')
}

function Get-StartMeasureExpected {
    # 시작 직후 계측 줄(S1)의 기대 숫자 - 유효 회전 기록에서: 마지막 두 회전 = 던전 안 2연속, 그 앞 유효 회전의 U·F 수 · 첫 F 부터 2연속 첫 표본까지 초
    # (끊김 없는 행 전용 - 관측 끊김 0). 반환 @{ U; F; Seconds(F 없으면 $null) }
    param($Result)
    $validTurns = @(Get-ValidTurns -Result $Result)
    $expected = @{ U = 0; F = 0; Seconds = $null }
    if ($validTurns.Count -lt 2) { return $expected }
    $streakStart = $validTurns[$validTurns.Count - 2]
    $firstFieldT = $null
    for ($turnIndex = 0; $turnIndex -lt ($validTurns.Count - 2); $turnIndex++) {
        if ($validTurns[$turnIndex].Key -eq 'U') { $expected.U++ }
        if ($validTurns[$turnIndex].Key -eq 'F') {
            $expected.F++
            if ($null -eq $firstFieldT) { $firstFieldT = [double]$validTurns[$turnIndex].T }
        }
    }
    if ($null -ne $firstFieldT) { $expected.Seconds = [Math]::Round([double]$streakStart.T - $firstFieldT, 1) }
    return $expected
}

function Test-MeasureLine {
    # 계측 줄(S1 · S2) 하나를 틀(정규식)로 읽어 숫자를 기대와 견줍니다 - 반환 '' (일치) / 다름 설명
    param([string]$Line, [string]$Pattern, [int]$ExpectU, [int]$ExpectF, $ExpectSeconds, [int]$ExpectBreaks)
    $lineMatch = [regex]::Match($Line, $Pattern)
    if (-not $lineMatch.Success) { return ('틀 불일치 [' + $Line + ']') }
    $problems = @()
    if ([int]$lineMatch.Groups['u'].Value -ne $ExpectU) { $problems += ('알 수 없음 {0} ≠ {1}' -f $lineMatch.Groups['u'].Value, $ExpectU) }
    if ([int]$lineMatch.Groups['f'].Value -ne $ExpectF) { $problems += ('필드 모양 {0} ≠ {1}' -f $lineMatch.Groups['f'].Value, $ExpectF) }
    if ([int]$lineMatch.Groups['b'].Value -ne $ExpectBreaks) { $problems += ('끊김 {0} ≠ {1}' -f $lineMatch.Groups['b'].Value, $ExpectBreaks) }
    if ($null -eq $ExpectSeconds) {
        if ($lineMatch.Groups['part'].Success) { $problems += '필드 모양 0 인데 첫 표본 초 조각이 있음' }
    } else {
        if (-not $lineMatch.Groups['part'].Success) { $problems += '첫 필드 모양 표본부터 초 조각 없음' }
        elseif ([Math]::Abs([double]::Parse($lineMatch.Groups['s'].Value, [Globalization.CultureInfo]::InvariantCulture) - [double]$ExpectSeconds) -gt 0.051) {
            $problems += ('초 {0} ≠ {1}' -f $lineMatch.Groups['s'].Value, (Format-Seconds $ExpectSeconds))
        }
    }
    return ($problems -join '; ')
}

function Get-SettleLineInfo {
    # 필드 확정 줄(S3) - 틀이 맞으면 @{ Found; W; Span; Count; T(가상 초) }, 없으면 Found 거짓
    param($Result)
    $settleIndex = Get-PatternIndex -Result $Result -Pattern $S3_PATTERN
    if ($settleIndex -lt 0) { return @{ Found = $false; W = -1; Span = -1; Count = -1; T = -1; Lines = @(Get-PatternLines -Result $Result -Pattern $S3_PATTERN).Count } }
    $settleMatch = [regex]::Match([string]$Result.Lines[$settleIndex], $S3_PATTERN)
    return @{
        Found = $true
        W     = [double]::Parse($settleMatch.Groups['w'].Value, [Globalization.CultureInfo]::InvariantCulture)
        Span  = [double]::Parse($settleMatch.Groups['span'].Value, [Globalization.CultureInfo]::InvariantCulture)
        Count = [int]$settleMatch.Groups['count'].Value
        T     = [double]$Result.LineTimes[$settleIndex]
        Lines = @(Get-PatternLines -Result $Result -Pattern $S3_PATTERN).Count
    }
}

# ===== CH 행 (함수 층 · 본류 시작 구간 층 - 명세 ② 3.2 CH1~CH16) =====
function Test-RowCH01 {
    # CH1 · CH1′ - 마무리 복구 기동(RECOVERY=1)은 journal 을 읽지 않습니다(표 ① · J14 - 잠금을 쥐어 두면 읽기가 곧 'stop' 으로 드러남: 변이 'RECOVERY 에서도 읽음').
    #   안내 줄은 nonce 와 무관하게 늘 1줄입니다(J13 - 'nonce 있을 때만' 은 기각)
    $expected = J @('ok(1)', 'none', '(빈 값)', 0, 0, (Format-Logs @($LINE_RECOVERY)), 'True', '')
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Recovery = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry)); HoldLock = $true }
    Assert-Case 'CH1 RECOVERY=1 + own nonce + 잠금 점유 → 반환 · Role none · Nonce 빈 값 · 읽기 0(잠금이어도 정지 0) · 쓰기 0 · [안내] 1 · 파일 불변 · 예외 0' `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.Reads, $row.Updates, $row.Logs, $row.Unchanged, $row.Thrown)) $expected
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Recovery = $true; Nonce = ''; Entries = @((New-ChOwnEntry)); HoldLock = $true }
    Assert-Case 'CH1′ RECOVERY=1 + nonce 빈 값 + 잠금 점유 → 같음 (J13 - 안내는 늘 1줄)' `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.Reads, $row.Updates, $row.Logs, $row.Unchanged, $row.Thrown)) $expected
}

function Test-RowCH02 {
    # CH2 - nonce 빈 값(넘겨받은 항목 없음 - 보통의 시작). 읽기는 그래도 1회(J1 · R-7 - 잠금·손상을 누르기 전에 봄), 열린 자기 항목이 있어도 Role none(표 ⑥)
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = ''; Entries = @((New-ChOwnEntry)) }
    Assert-Case 'CH2 nonce 빈 값 + 정상 journal(열린 자기 항목 있음) → 반환 · Role none · Nonce 빈 값 · JournalState ok · 읽기 1 · 쓰기 0 · 로그 0 · 파일 불변 · 예외 0' `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.JournalState, $row.Reads, $row.Updates, $row.Logs, $row.Unchanged, $row.Thrown)) `
        (J @('ok(1)', 'none', '(빈 값)', 'ok', 1, 0, '[]', 'True', ''))
    # CH2w(표 ② - 저장소 Warnings 를 그대로 한 줄씩): 본 파일 손상 + 직전본 유효(열린 자기 항목) → 잠금 아래 직전본 복구 → 그 경고 1줄 → 복구된 기록으로 own.
    #   기대 줄은 감시가 받은 저장소 Warnings 그대로(소스 캡처). 복구 쓰기는 저장소 몫이라 '파일 불변' 대신 저장 호출 0 을 봅니다
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; MainText = $CORRUPT_MAIN_TEXT; BakEntries = @((New-ChOwnEntry)) }
    Assert-Case 'CH2w 본 파일 손상 + 직전본 유효 → 저장소 경고(받은 Warnings 1줄) 그대로 · Role own · Nonce NA · 읽기 1 · 쓰기 0 · 반환 · 예외 0' `
        (J @($row.ReadWarnings.Count, $row.Logs, $row.Role, $row.Nonce, $row.Reads, $row.Updates, $row.Returned, $row.Thrown)) `
        (J @(1, (Format-Logs -Lines @($row.ReadWarnings)), 'own', 'NA', 1, 0, 'ok(1)', ''))
}

function Test-RowCH03 {
    # CH3 · CH3′ - 완료 기록 파일이 사용 중(같은 프로세스가 .lock 을 쥠) → 누르기 전 코드 4 ' (locked)'(표 ③ · J1 - Role·nonce 와 무관, 변이 'locked 를 Role none 에서
    #   통과' 는 CH3′ 이 잡음). 본류 시작 구간 층: 블록의 exit 4 가 기록되고 그 뒤 문장($roleNone 대입)·입력이 없습니다
    $expected = J @('4', 'stop(1)', (Format-Logs @($LINE_LOCKED)), 1, 'locked', 0, 'True', 0, '(미대입)', '')
    $names = 'exit · 반환 · (locked) 줄 1 · 읽기 1 · 저장소 상태 · 쓰기 0 · 파일 불변 · 입력 0 · $roleNone · 예외'
    $row = Invoke-MainSegmentRow -SegmentRow @{ ContentCategory = 'abyss'; Custom = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry)); HoldLock = $true }
    Assert-Case ('CH3 잠금 점유 + own nonce → (본류) exit 4 · ' + $names) `
        (J @($row.ExitCode, $row.Returned, $row.Logs, $row.Reads, $row.ReadStatus, $row.Updates, $row.Unchanged, $row.Inputs, $row.RoleNone, $row.Thrown)) $expected
    $row = Invoke-MainSegmentRow -SegmentRow @{ ContentCategory = 'abyss'; Custom = $true; Nonce = ''; Entries = @((New-ChOwnEntry)); HoldLock = $true }
    Assert-Case ('CH3′ 잠금 점유 + nonce 없음(커스텀) → 같음 · ' + $names) `
        (J @($row.ExitCode, $row.Returned, $row.Logs, $row.Reads, $row.ReadStatus, $row.Updates, $row.Unchanged, $row.Inputs, $row.RoleNone, $row.Thrown)) $expected
    $row = Invoke-MainSegmentRow -SegmentRow @{ ContentCategory = 'abyss'; Custom = $false; Nonce = ''; Entries = @((New-PlainEntry)); HoldLock = $true }
    Assert-Case ('CH3′ 잠금 점유 + nonce 없음(비커스텀 - 가장 흔한 시작) → 같음 · ' + $names) `
        (J @($row.ExitCode, $row.Returned, $row.Logs, $row.Reads, $row.ReadStatus, $row.Updates, $row.Unchanged, $row.Inputs, $row.RoleNone, $row.Thrown)) $expected
}

function Test-RowCH04 {
    # CH4 - 읽기 실패(io-failed - .lock 자리가 폴더라 잠금 파일을 만들 수 없음) → 'locked' 와 같은 정지, 문구는 '읽지 못해'(표 ④ · E02)
    $row = Invoke-MainSegmentRow -SegmentRow @{ ContentCategory = 'abyss'; Custom = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry)); LockFolder = $true }
    Assert-Case 'CH4 읽기 실패(io-failed) + own nonce → (본류) exit 4 · 반환 stop · 읽지 못해 … (locked) 줄 1 · 읽기 1 · 저장소 상태 · 쓰기 0 · 파일 불변 · 입력 0 · $roleNone · 예외' `
        (J @($row.ExitCode, $row.Returned, $row.Logs, $row.Reads, $row.ReadStatus, $row.Updates, $row.Unchanged, $row.Inputs, $row.RoleNone, $row.Thrown)) `
        (J @('4', 'stop(1)', (Format-Logs @($LINE_IO_FAILED)), 1, 'io-failed', 0, 'True', 0, '(미대입)', ''))
}

function Test-RowCH05 {
    # CH5 · CH5′ - 본 파일·직전본 둘 다 손상(corrupt) → Role none · JournalState corrupt · [경고] 1 · 'ok'(판 계속 - 표 ⑤ · J2: 키 지점이 생성·키 0 으로 받음).
    #   nonce 가 없어도 같습니다(설계 R2 E5(a) - nonce 없는 시작의 '손상 → 키 0 · 자기 항목 0' 은 이 시작 읽기를 전제)
    $expected = J @('ok(1)', 'none', '(빈 값)', 'corrupt', 'corrupt', (Format-Logs @($LINE_CORRUPT)), 1, 0, 'True', '')
    $names = '반환 · Role none · Nonce 빈 값 · JournalState corrupt · 저장소 상태 · [경고] 1 · 읽기 1 · 쓰기 0 · 파일 불변 · 예외 0'
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; MainText = $CORRUPT_MAIN_TEXT; BakText = $CORRUPT_BAK_TEXT }
    Assert-Case ('CH5 본 파일·직전본 손상 + own nonce → ' + $names) `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.JournalState, $row.ReadStatus, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown)) $expected
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = ''; MainText = $CORRUPT_MAIN_TEXT; BakText = $CORRUPT_BAK_TEXT }
    Assert-Case ('CH5′ 같은 손상 + nonce 빈 값 → 같음 · ' + $names) `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.JournalState, $row.ReadStatus, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown)) $expected
    # CH5″ - 손상(⑤)은 그 자리에서 반환합니다: 소유자 JSON 까지 깨진 기동도 손상 경고 1줄뿐(표 ⑤ < ⑦ - 변이 '손상 뒤 반환 없음' 이면 소유자 경고가 1줄 더 붙음)
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; OwnerJson = 'not json'; MainText = $CORRUPT_MAIN_TEXT; BakText = $CORRUPT_BAK_TEXT }
    Assert-Case ('CH5″ 같은 손상 + own nonce + 커스텀 소유자 JSON 손상 → 손상 경고 1줄만(⑤ 가 ⑦ 보다 앞) · ' + $names) `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.JournalState, $row.ReadStatus, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown)) $expected
}

function Test-RowCH06 {
    # CH6 · CH7 · CH7′ - 넘겨받은 nonce 의 항목이 없거나 이미 done → Role none · 로그 0(표 ⑧ - dev:593·594). CH6 의 픽스처에는 다른 nonce 의 열린 자기 항목이
    #   있습니다(넘겨받은 nonce 로만 찾는지). done 판정이 모드 불일치(⑨)보다 앞이라 RESUME=1 이어도 경고 0(CH7′)
    $expected = J @('ok(1)', 'none', '(빈 값)', '[]', 1, 0, 'True', '')
    $names = '반환 · Role none · Nonce 빈 값 · 로그 0 · 읽기 1 · 쓰기 0 · 파일 불변 · 예외 0'
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_D; Entries = @((New-ChOwnEntry -Nonce $NONCE_B)) }
    Assert-Case ('CH6 넘겨받은 nonce 의 항목 없음(다른 nonce 의 열린 자기 항목만) → ' + $names) `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown)) $expected
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry -LaunchState 'done')) }
    Assert-Case ('CH7 넘겨받은 항목 launchState done(소유자 일치 entered) → ' + $names) `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown)) $expected
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; Resume = '1'; Entries = @((New-ChOwnEntry -LaunchState 'done')) }
    Assert-Case ('CH7′ 같은 done 항목 + RESUME=1 → 같음(⑧ 이 ⑨ 보다 앞 - 경고 0) · ' + $names) `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown)) $expected
}

function Test-RowCH08 {
    # CH8 · CH9 - 모드 불일치(표 ⑨): RESUME=1 인데 stage 가 재입장 요청 단계가 아님 / RESUME 없는데 재입장 요청 단계 → Role none · [경고] 1(괄호 = 항목 stage).
    #   두 픽스처 모두 소유자가 일치합니다(불일치 판정이 빠지면 CH8 은 경고 없이 none, CH9 는 경고 없이 none 으로 드러남)
    $names = '반환 · Role none · Nonce 빈 값 · 모드 불일치 [경고] 1 · 읽기 1 · 쓰기 0 · 파일 불변 · 예외 0'
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; Resume = '1'; Entries = @((New-ChOwnEntry)) }
    Assert-Case ('CH8 RESUME=1 + stage entered(소유자 일치 · 열림) → ' + $names) `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown)) `
        (J @('ok(1)', 'none', '(빈 값)', (Format-Logs @(($LINE_MISMATCH_FORMAT -f 'entered'))), 1, 0, 'True', ''))
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_C; Entries = @((New-ChOwnEntry -Nonce $NONCE_C -Stage 'retry-clicked')) }
    Assert-Case ('CH9 RESUME 없음 + stage retry-clicked(소유자 일치 · 열림) → ' + $names) `
        (J @($row.Returned, $row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown)) `
        (J @('ok(1)', 'none', '(빈 값)', (Format-Logs @(($LINE_MISMATCH_FORMAT -f 'retry-clicked'))), 1, 0, 'True', ''))
}

function Test-RowCH10 {
    # CH10 · CH11 - own(표 ⑪ - RESUME 없음 ∧ stage entered ∧ owner 5필드 + 세대 일치 ∧ done 아님): Nonce = 받은 값 · CleanupOnly = 항목 cleanupOnly(없으면 거짓 -
    #   설계 R2 3.3a · C8) · AfterEntry = 항목의 index·keys(명세 2.1 표 아래 - 키 계약의 시작값)
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry -CleanupOnly $true)) }
    Assert-Case 'CH10 own(entered · owner·세대 일치 · launched · index 2 · cleanupOnly 참) → Role own · Nonce NA · CleanupOnly 참 · AfterEntry 2/32,66 · 로그 0 · 읽기 1 · 쓰기 0 · 파일 불변 · 반환 · 예외 0' `
        (J @($row.Role, $row.Nonce, $row.CleanupOnly, $row.AfterEntry, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Returned, $row.Thrown)) `
        (J @('own', 'NA', 'True', '2/32,66', '[]', 1, 0, 'True', 'ok(1)', ''))
    # CH10s - own 은 표 ⑪ 의 필드(Nonce · CleanupOnly · AfterEntry)만 씁니다. FreshEntry·StartScreen 은 선분기(단계 2.5)가 쓰는 자리라 기본값 그대로
    Assert-Case 'CH10s 같은 own → FreshEntry 거짓 · StartScreen 빈 값 그대로(두 필드는 선분기 몫 - Consume-Handoff 는 쓰지 않음)' `
        (J @($row.FreshEntry, $row.StartScreen)) (J @('False', ''))
    $oldEntry = New-ChOwnEntry -WithoutCleanupOnly
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; Entries = @($oldEntry) }
    Assert-Case 'CH11 own + cleanupOnly 필드 없는 옛 항목(픽스처에 필드 없음 확인) → Role own · Nonce NA · CleanupOnly 거짓 · AfterEntry 2/32,66 · 로그 0 · 반환 · 예외 0(설계 R2 C8)' `
        (J @(($null -eq $oldEntry.PSObject.Properties['cleanupOnly']), $row.Role, $row.Nonce, $row.CleanupOnly, $row.AfterEntry, $row.Logs, $row.Returned, $row.Thrown)) `
        (J @('True', 'own', 'NA', 'False', '2/32,66', '[]', 'ok(1)', ''))
    # CH10i - 키 시작값은 열쇠 항목의 afterEntry.index 그대로입니다(명세 2.1 표 아래 - total 이 아님). 위 픽스처는 index = total = 2 라 둘을 가르지 못해
    #   키를 하나만 보내고 끊긴 항목(index 1 · total 2)을 따로 둡니다
    $partialEntry = New-FixtureEntry -Stage 'entered' -Nonce $NONCE_A -Owner (New-ChOwner -Index 0) -Generation $CH_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' `
        -LaunchState 'launched' -AfterIndex 1 -AfterTotal 2 -AfterKeys $CH_KEYS
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; Entries = @($partialEntry) }
    Assert-Case 'CH10i own + 키 하나만 보낸 열쇠 항목(index 1 · total 2) → Role own · Nonce NA · AfterEntry 1/32,66(index 그대로 - total 아님) · 로그 0 · 반환 · 예외 0' `
        (J @($row.Role, $row.Nonce, $row.AfterEntry, $row.Logs, $row.Returned, $row.Thrown)) (J @('own', 'NA', '1/32,66', '[]', 'ok(1)', ''))
    # CH10g - 세대 출처는 소유자 JSON 입니다(명세 ② J3 - Consume-Handoff·자기 항목 생성·클리어 기록이 같은 출처, 세대 env 는 [설정] 대조용. 두 출처가 어긋나면
    #   own 대조가 깨짐). 세대 env 를 JSON 과 어긋나게 둬도 역할은 JSON 세대대로: env = JSON +1 · 항목 = JSON 이면 own / env = 항목 = JSON +1 이면 none(stale).
    #   다른 행은 그 env 를 비워 돌아 '세대를 env 에서 읽음' 변이가 env 가 빌 때만 드러났습니다(단계 2.1 검증 지적). 둘째 경우는 'JSON 이나 env 중 하나만
    #   맞으면 일치' 변이를 잡습니다. 행이 실제로 그 env 를 둔 채 돌았는지도 같이 봅니다(하니스가 env 를 빠뜨리면 이 행은 아무것도 가르지 못함)
    $generationEnvValue = [string]($CH_GENERATION + 1)
    $generationCases = @(
        @{ Label = '세대 env JSON+1 · 항목 세대 = JSON'; Entry = (New-ChOwnEntry); Expect = 'own' },
        @{ Label = '세대 env = 항목 세대 = JSON+1'; Entry = (New-ChOwnEntry -Generation ($CH_GENERATION + 1)); Expect = 'none' })
    $actual = foreach ($generationCase in $generationCases) {
        $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; GenerationEnv = $generationEnvValue; Entries = @($generationCase.Entry) }
        $generationEnvSeen = [string][Environment]::GetEnvironmentVariable('HONEYNOGI_CUSTOM_GENERATION', 'Process')
        '{0}: {1}' -f $generationCase.Label, (J @($generationEnvSeen, $row.Role, $row.Nonce, $row.Logs, $row.Unchanged, $row.Returned, $row.Thrown))
    }
    $expected = foreach ($generationCase in $generationCases) {
        $expectNonce = '(빈 값)'
        if ($generationCase.Expect -eq 'own') { $expectNonce = 'NA' }
        '{0}: {1}' -f $generationCase.Label, (J @($generationEnvValue, $generationCase.Expect, $expectNonce, '[]', 'True', 'ok(1)', ''))
    }
    Assert-Case 'CH10g 세대 출처 = 소유자 JSON(J3) - 세대 env 를 JSON 과 어긋나게 둠 → env · Role(항목 = JSON 이면 own / 항목 = env ≠ JSON 이면 none) · Nonce · 로그 0 · 파일 불변 · 반환 · 예외 0' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowCH12 {
    # CH12 - stale 3종(표 ⑬ - dev:593 'stale'): owner 5필드 불일치(진행 위치) · 세대 불일치(진행 초기화) · 비커스텀 runId 불일치(다른 실행) → Role none · 로그 0.
    #   대조(표 ⑪ - 같은 픽스처에서 그 필드만 맞추면 own): 커스텀 일치 · 비커스텀 runId 일치
    $cases = @(
        @{ Label = 'owner 5필드 불일치(index 1)'; Custom = $true; Entry = (New-ChOwnEntry -OwnerIndex 1); Expect = 'none' },
        @{ Label = '세대 불일치(항목 2 · 지금 3)'; Custom = $true; Entry = (New-ChOwnEntry -Generation ($CH_GENERATION - 1)); Expect = 'none' },
        @{ Label = '비커스텀 runId 불일치'; Custom = $false; Entry = (New-PlainEntry -RunId 'run-old'); Expect = 'none' },
        @{ Label = '대조 커스텀 일치'; Custom = $true; Entry = (New-ChOwnEntry); Expect = 'own' },
        @{ Label = '대조 비커스텀 runId 일치'; Custom = $false; Entry = (New-PlainEntry -RunId $CH_RUN_ID); Expect = 'own' })
    $actual = foreach ($case in $cases) {
        $row = Invoke-ConsumeRow -Row @{ Custom = $case.Custom; Nonce = $NONCE_A; Entries = @($case.Entry) }
        '{0}: {1}' -f $case.Label, (J @($row.Role, $row.Nonce, $row.Logs, $row.Unchanged, $row.Thrown))
    }
    $expected = foreach ($case in $cases) {
        $expectNonce = '(빈 값)'
        if ($case.Expect -eq 'own') { $expectNonce = 'NA' }
        '{0}: {1}' -f $case.Label, (J @($case.Expect, $expectNonce, '[]', 'True', ''))
    }
    Assert-Case 'CH12 stale 3종(owner·세대·runId 불일치) → Role none · Nonce 빈 값 · 로그 0 · 파일 불변 / 대조(일치) → own · Nonce NA' (@($actual) -join ' || ') (@($expected) -join ' || ')

    # CH12n · CH12r · CH12s - 표 ⑬ 의 나머지 갈래(위 CH12 는 own 의 owner 대조만 봄): next 의 nextOwner 불일치(5필드 · 세대) · resume 의 owner 불일치(5필드 ·
    #   세대) · 다른 stage(cleared - owner 일치 / nextOwner 일치) → Role none · 로그 0. 대조: 같은 모양에서 그 필드만 맞추면 next / resume
    $otherCases = @(
        @{ Label = 'next nextOwner 5필드 불일치(index 1)'; Nonce = $NONCE_B; Resume = ''; Expect = 'none'
            Entry = (New-FixtureEntry -Stage 'reentered' -Nonce $NONCE_B -Owner (New-ChOwner -Index 2) -NextOwner (New-ChOwner -Index 1) -Generation $CH_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'launched')
        },
        @{ Label = 'next 세대 불일치(항목 2 · 지금 3)'; Nonce = $NONCE_B; Resume = ''; Expect = 'none'
            Entry = (New-FixtureEntry -Stage 'reentered' -Nonce $NONCE_B -Owner (New-ChOwner -Index 2) -NextOwner (New-ChOwner -Index 0) -Generation ($CH_GENERATION - 1) -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'launched')
        },
        @{ Label = '대조 next nextOwner·세대 일치'; Nonce = $NONCE_B; Resume = ''; Expect = 'next'
            Entry = (New-FixtureEntry -Stage 'reentered' -Nonce $NONCE_B -Owner (New-ChOwner -Index 2) -NextOwner (New-ChOwner -Index 0) -Generation $CH_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'launched')
        },
        @{ Label = 'resume owner 5필드 불일치(index 1)'; Nonce = $NONCE_C; Resume = '1'; Expect = 'none'
            Entry = (New-ChOwnEntry -Nonce $NONCE_C -Stage 'retry-attempt' -OwnerIndex 1)
        },
        @{ Label = 'resume 세대 불일치(항목 2 · 지금 3)'; Nonce = $NONCE_C; Resume = '1'; Expect = 'none'
            Entry = (New-ChOwnEntry -Nonce $NONCE_C -Stage 'retry-attempt' -Generation ($CH_GENERATION - 1))
        },
        @{ Label = '대조 resume owner·세대 일치'; Nonce = $NONCE_C; Resume = '1'; Expect = 'resume'
            Entry = (New-ChOwnEntry -Nonce $NONCE_C -Stage 'retry-attempt')
        },
        @{ Label = '다른 stage cleared(owner·세대 일치 · 열림)'; Nonce = $NONCE_D; Resume = ''; Expect = 'none'
            Entry = (New-FixtureEntry -Stage 'cleared' -Nonce $NONCE_D -Owner (New-ChOwner -Index 0) -Generation $CH_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'pending' -Decision 'exit')
        },
        @{ Label = '다른 stage cleared(nextOwner·세대 일치 · owner 불일치 · 열림)'; Nonce = $NONCE_D; Resume = ''; Expect = 'none'
            Entry = (New-FixtureEntry -Stage 'cleared' -Nonce $NONCE_D -Owner (New-ChOwner -Index 2) -NextOwner (New-ChOwner -Index 0) -Generation $CH_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'pending' -Decision 'exit')
        })
    $actual = foreach ($case in $otherCases) {
        $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $case.Nonce; Resume = $case.Resume; Entries = @($case.Entry) }
        '{0}: {1}' -f $case.Label, (J @($row.Role, $row.Nonce, $row.Logs, $row.Unchanged, $row.Thrown))
    }
    $expected = foreach ($case in $otherCases) {
        $expectNonce = '(빈 값)'
        if ($case.Expect -ne 'none') { $expectNonce = Get-NonceLabel $case.Nonce }
        '{0}: {1}' -f $case.Label, (J @($case.Expect, $expectNonce, '[]', 'True', ''))
    }
    Assert-Case 'CH12n·CH12r·CH12s 표 ⑬ 나머지(next nextOwner 불일치 5필드·세대 · resume owner 불일치 5필드·세대 · 다른 stage cleared) → Role none · Nonce 빈 값 · 로그 0 · 파일 불변 / 대조(일치) → next · resume' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowCH13 {
    # CH13 · CH13f - next(표 ⑩ - RESUME 없음 ∧ stage reentered ∧ nextOwner == 내 owner(세대 포함) ∧ done 아님, applied 무관): Nonce = 받은 값 · AfterEntry = 항목의
    #   index·keys(첫 기록 전이라 keys null). FINISH_ONLY 는 역할 판정에 쓰지 않습니다(명세 2.1 표 아래 - 마무리 실행 기동도 next, dev:908)
    $nextEntry = New-FixtureEntry -Stage 'reentered' -Nonce $NONCE_B -Owner (New-ChOwner -Index 2) -NextOwner (New-ChOwner -Index 0) -Generation $CH_GENERATION `
        -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'launched' -AfterIndex 0
    $expected = J @('next', 'NB', '0/null', '[]', 1, 0, 'True', 'ok(1)', '')
    $names = 'Role next · Nonce NB · AfterEntry 0/null · 로그 0 · 읽기 1 · 쓰기 0 · 파일 불변 · 반환 · 예외 0'
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_B; Entries = @($nextEntry); Applied = @($NONCE_B) }
    Assert-Case ('CH13 next(reentered · nextOwner 일치 · applied 에 nonce 있음) → applied 무관 · ' + $names) `
        (J @($row.Role, $row.Nonce, $row.AfterEntry, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Returned, $row.Thrown)) $expected
    Assert-Case 'CH13s 같은 next → CleanupOnly 거짓 · FreshEntry 거짓 · StartScreen 빈 값 그대로(next 는 표 ⑩ 의 Nonce·AfterEntry 만 씀)' `
        (J @($row.CleanupOnly, $row.FreshEntry, $row.StartScreen)) (J @('False', 'False', ''))
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_B; FinishOnly = '1'; Entries = @($nextEntry); Applied = @($NONCE_B) }
    Assert-Case ('CH13f 같은 next + FINISH_ONLY=1 → 같음(역할 판정에 FINISH_ONLY 0) · ' + $names) `
        (J @($row.Role, $row.Nonce, $row.AfterEntry, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Returned, $row.Thrown)) $expected
}

function Test-RowCH14 {
    # CH14 - resume(표 ⑫ - RESUME=1 ∧ stage ∈ {retry-attempt, retry-clicked} ∧ owner 일치 ∧ nonce ∉ applied): applied 밖 → resume · Nonce = 받은 값 /
    #   applied 안 → 그 밖(⑬) none · 로그 0(모드는 맞아 경고 없음)
    $resumeEntry = New-ChOwnEntry -Nonce $NONCE_C -Stage 'retry-attempt'
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_C; Resume = '1'; Entries = @($resumeEntry); Applied = @() }
    Assert-Case 'CH14 resume(RESUME=1 · retry-attempt · owner 일치) - applied 밖 → Role resume · Nonce NC · 로그 0 · 읽기 1 · 쓰기 0 · 파일 불변 · 반환 · 예외 0' `
        (J @($row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Returned, $row.Thrown)) `
        (J @('resume', 'NC', '[]', 1, 0, 'True', 'ok(1)', ''))
    Assert-Case 'CH14s 같은 resume → CleanupOnly 거짓 · AfterEntry null · FreshEntry 거짓 · StartScreen 빈 값 그대로(resume 은 표 ⑫ 의 Nonce 만 씀)' `
        (J @($row.CleanupOnly, $row.AfterEntry, $row.FreshEntry, $row.StartScreen)) (J @('False', 'null', 'False', ''))
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_C; Resume = '1'; Entries = @($resumeEntry); Applied = @($NONCE_C) }
    Assert-Case 'CH14 같은 항목 - applied 안 → Role none · Nonce 빈 값 · 로그 0 · 읽기 1 · 쓰기 0 · 파일 불변 · 반환 · 예외 0' `
        (J @($row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Returned, $row.Thrown)) `
        (J @('none', '(빈 값)', '[]', 1, 0, 'True', 'ok(1)', ''))
}

function Test-RowCH15 {
    # CH15 · CH15′ - 커스텀 소유자 JSON 해석 실패(표 ⑦ · E15): nonce 가 있으면 Role none · [경고] 1(읽기는 그 앞 ② 라 1). nonce 가 비면 ⑥ 이 ⑦ 보다 앞이라
    #   해석하지 않습니다 - 경고 0(C15 - 해석 실패는 입장 뒤 자기 항목 생성에서 드러남, E16)
    $actual = foreach ($badOwner in @('', 'not json')) {
        $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; OwnerJson = $badOwner; Entries = @((New-ChOwnEntry)) }
        '[{0}]: {1}' -f $badOwner, (J @($row.Returned, $row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown))
    }
    $expected = foreach ($badOwner in @('', 'not json')) {
        '[{0}]: {1}' -f $badOwner, (J @('ok(1)', 'none', '(빈 값)', (Format-Logs @($LINE_OWNER_UNREADABLE)), 1, 0, 'True', ''))
    }
    Assert-Case 'CH15 커스텀 소유자 JSON 해석 실패(빈 값 · JSON 아님) + own nonce → 반환 · Role none · Nonce 빈 값 · [경고] 1 · 읽기 1 · 쓰기 0 · 파일 불변 · 예외 0' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
    $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = ''; OwnerJson = 'not json'; Entries = @((New-ChOwnEntry)) }
    Assert-Case 'CH15′ 해석 실패 + nonce 빈 값 → 반환 · Role none · 로그 0(해석 0 - C15) · 읽기 1 · 예외 0' `
        (J @($row.Returned, $row.Role, $row.Logs, $row.Reads, $row.Thrown)) (J @('ok(1)', 'none', '[]', 1, ''))
    # CH15″ - 소유자 해석(⑦)은 넘겨받은 항목 찾기(⑧)보다 앞입니다: 항목이 없거나 이미 done 이어도 해석 실패 경고 1줄(표 순서 ⑦ < ⑧)
    $lookupCases = @(
        @{ Label = '넘겨받은 nonce 의 항목 없음'; Entries = @((New-ChOwnEntry -Nonce $NONCE_B)) },
        @{ Label = '넘겨받은 항목 done'; Entries = @((New-ChOwnEntry -LaunchState 'done')) })
    $actual = foreach ($lookupCase in $lookupCases) {
        $row = Invoke-ConsumeRow -Row @{ Custom = $true; Nonce = $NONCE_A; OwnerJson = 'not json'; Entries = $lookupCase.Entries }
        '{0}: {1}' -f $lookupCase.Label, (J @($row.Returned, $row.Role, $row.Nonce, $row.Logs, $row.Reads, $row.Updates, $row.Unchanged, $row.Thrown))
    }
    $expected = foreach ($lookupCase in $lookupCases) {
        '{0}: {1}' -f $lookupCase.Label, (J @('ok(1)', 'none', '(빈 값)', (Format-Logs @($LINE_OWNER_UNREADABLE)), 1, 0, 'True', ''))
    }
    Assert-Case 'CH15″ 해석 실패 + own nonce + 항목 없음 / done → [경고] 1(⑦ 이 ⑧ 보다 앞) · 반환 · Role none · Nonce 빈 값 · 읽기 1 · 쓰기 0 · 파일 불변 · 예외 0' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowCH16 {
    # CH16 - 본류 시작 구간 층: 던전·심층·사냥터는 2.1 블록을 지나지 않음 → Consume-Handoff 호출 0 · Role none(기본값 - 모든 실행) · $roleNone 참(R4 4.3 '기본값이
    #   없으면 던전 실행이 결론 대입 갈래로 감' · P13). 픽스처는 묵은 nonce env + 열린 자기 항목(블록 조건이 빠지면 own 이 됨). 대조: 어비스는 호출 1(Role none 이면
    #   $roleNone 참) · 커스텀 토큰 손상(customSpecInvalid)이면 호출 0
    $actual = foreach ($category in @('dungeon', 'deepdungeon', 'hunting')) {
        $row = Invoke-MainSegmentRow -SegmentRow @{ ContentCategory = $category; Custom = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry)) }
        '{0}: {1}' -f $category, (J @($row.ConsumeCalls, $row.Role, $row.RoleNone, $row.ExitCode, $row.Reads, $row.Inputs, $row.Logs, $row.Thrown))
    }
    $expected = foreach ($category in @('dungeon', 'deepdungeon', 'hunting')) { '{0}: {1}' -f $category, (J @(0, 'none', 'True', '', 0, 0, '[]', '')) }
    Assert-Case 'CH16 contentCategory 던전·심층·사냥터 → Consume-Handoff 호출 0 · Role none · $roleNone 참 · exit 0건 · 읽기 0 · 입력 0 · 로그 0 · 예외 0' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
    $row = Invoke-MainSegmentRow -SegmentRow @{ ContentCategory = 'abyss'; SpecInvalid = $true; Custom = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry)) }
    Assert-Case 'CH16 대조 - 어비스 + 커스텀 토큰 손상(customSpecInvalid) → 호출 0 · Role none · $roleNone 참 · exit 0건 · 예외 0' `
        (J @($row.ConsumeCalls, $row.Role, $row.RoleNone, $row.ExitCode, $row.Thrown)) (J @(0, 'none', 'True', '', ''))
    $row = Invoke-MainSegmentRow -SegmentRow @{ ContentCategory = 'abyss'; Custom = $false; Nonce = ''; Entries = @() }
    Assert-Case 'CH16 대조 - 어비스 비커스텀 nonce 없음 → 호출 1 · 반환 ok · Role none · $roleNone 참 · exit 0건 · 입력 0 · 예외 0' `
        (J @($row.ConsumeCalls, $row.Returned, $row.Role, $row.RoleNone, $row.ExitCode, $row.Inputs, $row.Thrown)) (J @(1, 'ok(1)', 'none', 'True', '', 0, ''))
    # CH16o(본류 시작 구간이 Consume-Handoff 가 정한 역할을 그대로 넘김 - Role own · $roleNone 거짓)는 단계 2.5 에서 블록이 선분기를 부르게 되어 화면 스텁과
    #   함께 R4-O1 의 층 ① 행으로 옮겼습니다(아래 Test-RowOwnSelector 'O1(CH16o)')
}

# ===== L 행 (설계 v11 R4 5.6 - GUI 사본 Resolve + 실제 Consume-Handoff) =====
function Test-RowR4L {
    # R4-L1 ① 형 journal(① 빌드가 쓰는 cleared · decision exit 만 - 커스텀은 같은 owner·세대, 비커스텀은 같은 실행 id) → 후보 없음 · 기동 종류 none · nonce env 빈 값 ·
    #   워커 Role none · 쓰기 0(GUI 후보 고르기는 unchanged · 워커는 읽기만)
    $context = New-AbyssContext -Index 0 -Generation $L_GENERATION
    $owner = ConvertTo-FiveFieldOwner (Get-CustomCanonicalOwner -Context $context)
    $clearedCustom = New-FixtureEntry -Stage 'cleared' -Nonce $NONCE_A -Owner $owner -Generation $L_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'pending' -Decision 'exit'
    $clearedPlain = New-FixtureEntry -Stage 'cleared' -Nonce $NONCE_B -Owner ([pscustomobject]@{ runId = $L_RUN_ID }) -RunId $L_RUN_ID -LaunchState 'pending' -Decision 'exit'
    $names = '후보 · 기동 종류 · nonce env · 워커 Role · 워커 Nonce · 워커 로그 · 쓰기 0(파일 불변) · GUI 줄·정지 0 · 예외 0'
    $row = Invoke-LaunchRoleRow -Custom $true -Context $context -Entries @($clearedCustom) -Applied @($NONCE_A)
    Assert-Case ('R4-L1 커스텀 일반 시작 + ① 형 journal(cleared 만) → ' + $names) `
        (J @($row.Resolve, $row.Kind, $row.NonceEnv, $row.Role, $row.Nonce, $row.Logs, $row.Unchanged, $row.GuiEvents, $row.GuiThrown, $row.WorkerThrown)) `
        (J @('none/none', 'none', '(빈 값)', 'none', '(빈 값)', '[]', 'True', '', '', ''))
    $row = Invoke-LaunchRoleRow -Custom $false -Entries @($clearedPlain) -Applied @($NONCE_B) -WatchNonce $NONCE_B
    Assert-Case ('R4-L1 비커스텀 + ① 형 journal(cleared 만) → ' + $names) `
        (J @($row.Resolve, $row.Kind, $row.NonceEnv, $row.Role, $row.Nonce, $row.Logs, $row.Unchanged, $row.GuiEvents, $row.GuiThrown, $row.WorkerThrown)) `
        (J @('none/none', 'none', '(빈 값)', 'none', '(빈 값)', '[]', 'True', '', '', ''))

    # R4-L2 커스텀 일반 시작 + 열린 entered(owner i · generation g) → 후보 own · 기동 종류 own · nonce env = 그 항목 · 항목 launched · 워커 Role own(같은 nonce).
    #   픽스처 두 모양: 워커가 입장 때 쓰는 launched(후보 고르기는 쓰기 없이 고름) / pending(후보 고르기가 launched 로 적음)
    foreach ($fixtureState in @('launched', 'pending')) {
        $openEntry = New-FixtureEntry -Stage 'entered' -Nonce $NONCE_A -Owner $owner -Generation $L_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' `
            -LaunchState $fixtureState -AfterIndex 2 -AfterTotal 2 -AfterKeys $CH_KEYS
        $row = Invoke-LaunchRoleRow -Custom $true -Context $context -Entries @($openEntry)
        Assert-Case ('R4-L2 커스텀 일반 시작 + 열린 entered(owner·세대 일치 · 픽스처 ' + $fixtureState + ') → 후보 own · 기동 종류 own · nonce env NA · RESUME 빈 값 · 항목 launched · 워커 Role own · Nonce NA · 로그 0 · 정지 0 · 예외 0') `
            (J @($row.Resolve, $row.Kind, $row.NonceEnv, $row.ResumeEnv, $row.LaunchState, $row.Role, $row.Nonce, $row.Logs, $row.GuiEvents, $row.GuiThrown, $row.WorkerThrown)) `
            (J @('ok/own', 'own', 'NA', '', 'launched', 'own', 'NA', '[]', '', '', ''))
    }

    # R4-L3 비커스텀 + 같은 실행 id 의 열린 entered → 후보 없음(GUI $ownFirst 거짓 - gui:9511: 비커스텀 일반 시작은 next 만 봄) · 워커 Role none · 항목 그대로
    $plainOpen = New-FixtureEntry -Stage 'entered' -Nonce $NONCE_A -Owner ([pscustomobject]@{ runId = $L_RUN_ID }) -RunId $L_RUN_ID -LaunchState 'launched' -AfterIndex 2 -AfterTotal 2 -AfterKeys $CH_KEYS
    $row = Invoke-LaunchRoleRow -Custom $false -Entries @($plainOpen)
    Assert-Case 'R4-L3 비커스텀 + 같은 실행 id 의 열린 entered → 후보 none · 기동 종류 none · nonce env 빈 값 · 워커 Role none · Nonce 빈 값 · 항목 launched 그대로 · 쓰기 0 · 예외 0' `
        (J @($row.Resolve, $row.Kind, $row.NonceEnv, $row.Role, $row.Nonce, $row.LaunchState, $row.Unchanged, $row.GuiThrown, $row.WorkerThrown)) `
        (J @('none/none', 'none', '(빈 값)', 'none', '(빈 값)', 'launched', 'True', '', ''))

    # R4-L6 진행 초기화로 세대가 바뀐 뒤(항목 세대 3 · 지금 4) → 옛 항목 stale · 후보 none · 워커 Role none
    $staleEntry = New-FixtureEntry -Stage 'entered' -Nonce $NONCE_A -Owner $owner -Generation $L_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' -LaunchState 'launched' -AfterIndex 2 -AfterTotal 2 -AfterKeys $CH_KEYS
    $row = Invoke-LaunchRoleRow -Custom $true -Context (New-AbyssContext -Index 0 -Generation ($L_GENERATION + 1)) -Entries @($staleEntry)
    Assert-Case 'R4-L6 진행 초기화 뒤(세대 +1) + 옛 열린 entered → 후보 none · 기동 종류 none · nonce env 빈 값 · 워커 Role none · 쓰기 0 · 예외 0' `
        (J @($row.Resolve, $row.Kind, $row.NonceEnv, $row.Role, $row.Nonce, $row.Unchanged, $row.GuiThrown, $row.WorkerThrown)) `
        (J @('none/none', 'none', '(빈 값)', 'none', '(빈 값)', 'True', '', ''))

    # R4-L7 진행 위치가 바뀐 뒤(항목 owner index 0 · 지금 index 1 - owner 5필드 불일치) → 후보 none · 워커 Role none
    $row = Invoke-LaunchRoleRow -Custom $true -Context (New-AbyssContext -Index 1 -Generation $L_GENERATION) -Entries @($staleEntry)
    Assert-Case 'R4-L7 진행 위치 이동 뒤(owner 5필드 불일치) + 열린 entered → 후보 none · 기동 종류 none · nonce env 빈 값 · 워커 Role none · 쓰기 0 · 예외 0' `
        (J @($row.Resolve, $row.Kind, $row.NonceEnv, $row.Role, $row.Nonce, $row.Unchanged, $row.GuiThrown, $row.WorkerThrown)) `
        (J @('none/none', 'none', '(빈 값)', 'none', '(빈 값)', 'True', '', ''))
}

# ===== 단계 2.4 - 분류 순위(K) · 필드 확정(F) 순수 진리표 =====
function Invoke-ClassifierCase {
    # 분류 함수 한 번 - 판독값(뜻 이름 해시) → 실제 Resolve-AbyssHandoffStartScreen 의 키. 3버튼·팝업·접힌 패널 서명은 같은 하단 판독문으로 실제 판정 함수가
    # 계산해 서명 매개변수가 있으면 그 값으로 넘깁니다. 예외는 '(예외: …)' 로 돌려 그 행만 FAIL
    param([hashtable]$Inputs)
    $caseValues = @{ Prompt = $false; Bottom = ''; Panel = 'none'; Hud = $false; Quest = $false; Selection = $false; Menu = $false; Detail = $false }
    foreach ($inputEntry in $Inputs.GetEnumerator()) { $caseValues[$inputEntry.Key] = $inputEntry.Value }
    $caseValues['Reward3'] = [bool](Test-AbyssRewardText -Text ([string]$caseValues['Bottom']))
    $caseValues['Popup'] = [bool](Test-AbyssFewMembersPopupText -Text ([string]$caseValues['Bottom']))
    $caseValues['EntryWaiting'] = [bool](Test-AbyssEntryWaitingText -Text ([string]$caseValues['Bottom']))
    $classifierArguments = @{}
    foreach ($classifierMappingEntry in $script:classifierMapping) { $classifierArguments[$classifierMappingEntry.Parameter] = $caseValues[$classifierMappingEntry.Semantic] }
    try {
        return [string](Invoke-RealResolveAbyssHandoffStartScreen @classifierArguments)
    } catch {
        return ('(예외: ' + $_.Exception.Message + ')')
    }
}

function Test-RowK {
    # 분류 순위 - 명세 ② 2.4 '분류 순위' 표(한 회전 · 위가 이김) · 설계 v11 R4 5.0 K2~K12(인접 순위 두 신호가 함께 참) · 명세 3.2 K13~K13″(U2 상세 화면 -
    #   5절 A-2 R-3: 상세 신호 ∧ HUD 없음, 순위 7 = 선택 화면·메뉴 다음 · 필드보다 먼저). K0 = 순위 표의 단독 신호(대응이 맞는지부터). 판독문 = 보관 프레임 재생값
    #   K13 계열은 판독문이 아니라 상세 신호(Test-AbyssKnownDetailScreen 의 참/거짓)를 넣습니다 - 그 신호 값의 근거는 명세 5절 B18 재생(2026-10-13, 보관 프레임
    #   6,320장을 같은 판독 조건 - 제목 영역·배율 3·한국어 엔진·등록 던전 키워드 - 으로 재생): 상세 신호 참 92장이 전부 HUD 없음이고 실제 상세 화면 88(그중 카드가
    #   보이는 선택 화면 3 = K13′) + 보상 화면 4(보관 캡처가 게임 창보다 커서 생긴 기하 착시 - 워커는 창 사각형으로 잘라 제목 영역 밖) · 필드·던전 안·로딩·S·
    #   3버튼 프레임에서는 0장
    $cases = @(
        @{ Name = 'K0 단독 - 권장 인원 팝업 하단문 → popup'; In = @{ Bottom = $BOTTOM_TEXTS.popup }; Expect = 'popup' },
        @{ Name = 'K0 단독 - 패널 ready → ready'; In = @{ Panel = 'ready' }; Expect = 'ready' },
        @{ Name = 'K0 단독 - 패널 matching(재매칭 하단문) → matching'; In = @{ Panel = 'matching'; Bottom = $BOTTOM_TEXTS.matching }; Expect = 'matching' },
        @{ Name = 'K0 단독 - 접힌 패널 하단문 · 패널 none · HUD 없음 → entry-waiting'; In = @{ Bottom = $BOTTOM_TEXTS.entry }; Expect = 'entry-waiting' },
        @{ Name = "K0 단독 - S('화면을 터치') → prompt"; In = @{ Prompt = $true; Bottom = $BOTTOM_TEXTS.prompt }; Expect = 'prompt' },
        @{ Name = 'K0 단독 - HUD + 추적기 던전명 → inside'; In = @{ Hud = $true; Quest = $true }; Expect = 'inside' },
        @{ Name = 'K0 단독 - 3버튼 하단문 · HUD 없음 → reward3'; In = @{ Bottom = $BOTTOM_TEXTS.reward3 }; Expect = 'reward3' },
        @{ Name = 'K0 단독 - 선택 화면 → selection'; In = @{ Selection = $true }; Expect = 'selection' },
        @{ Name = 'K0 단독 - ESC 메뉴 → menu'; In = @{ Menu = $true }; Expect = 'menu' },
        @{ Name = 'K0 단독 - HUD · 추적기 던전명 없음 → field (필드 모양 표본)'; In = @{ Hud = $true }; Expect = 'field' },
        @{ Name = 'R4-K2 권장 인원 팝업 하단문 + 패널 ready → popup (popup > ready)'; In = @{ Bottom = $BOTTOM_TEXTS.popup; Panel = 'ready' }; Expect = 'popup' },
        @{ Name = 'R4-K3 패널 ready + S → ready (패널 > S - 파티원 §1(a) 경합 ready + prompt 와 같음)'; In = @{ Panel = 'ready'; Prompt = $true; Bottom = $BOTTOM_TEXTS.prompt }; Expect = 'ready' },
        @{ Name = 'R4-K4 패널 matching + HUD + 추적기 던전명 → matching (matching > inside)'; In = @{ Panel = 'matching'; Bottom = $BOTTOM_TEXTS.matching; Hud = $true; Quest = $true }; Expect = 'matching' },
        @{ Name = "R4-K5 접힌 패널 하단문 + HUD + 추적기 없음 → field ('entry-waiting' 의 HUD 없음 조건)"; In = @{ Bottom = $BOTTOM_TEXTS.entry; Hud = $true }; Expect = 'field' },
        @{ Name = 'R4-K6 S + HUD + 추적기 던전명 → prompt (prompt > inside - next 의 pre-clear 코드 4 ↔ 이어받기 뒤 계상)'; In = @{ Prompt = $true; Bottom = $BOTTOM_TEXTS.prompt; Hud = $true; Quest = $true }; Expect = 'prompt' },
        @{ Name = "R4-K7 HUD + 추적기 던전명 + 3버튼 하단문 → inside (inside > reward3 - reward3 는 'HUD 없음' 조건)"; In = @{ Hud = $true; Quest = $true; Bottom = $BOTTOM_TEXTS.reward3 }; Expect = 'inside' },
        @{ Name = 'R4-K8 3버튼 하단문 + HUD 없음 + 선택 화면 → reward3 (reward3 > selection - nonce done ↔ 보존)'; In = @{ Bottom = $BOTTOM_TEXTS.reward3; Selection = $true }; Expect = 'reward3' },
        @{ Name = "R4-K9 3버튼 하단문 + HUD + 추적기 없음 → field ('reward3' 의 HUD 없음 조건)"; In = @{ Bottom = $BOTTOM_TEXTS.reward3; Hud = $true }; Expect = 'field' },
        @{ Name = 'R4-K10 선택 화면 + HUD + 추적기 없음 → selection (selection > field)'; In = @{ Selection = $true; Hud = $true }; Expect = 'selection' },
        @{ Name = 'R4-K11 ESC 메뉴 + HUD + 추적기 없음 → menu (menu > field)'; In = @{ Menu = $true; Hud = $true }; Expect = 'menu' },
        @{ Name = "R4-K12 전 영역 ''(로딩) → unknown"; In = @{}; Expect = 'unknown' },
        @{ Name = 'K13 상세 신호 ∧ HUD 없음 → detail'; In = @{ Detail = $true }; Expect = 'detail' },
        @{ Name = 'K13′ 상세 ∧ 선택 화면 → selection (순위 7 안 선택 화면 먼저)'; In = @{ Detail = $true; Selection = $true }; Expect = 'selection' },
        @{ Name = 'K13″ 상세 ∧ HUD ∧ 추적기 던전명 → inside'; In = @{ Detail = $true; Hud = $true; Quest = $true }; Expect = 'inside' },
        @{ Name = "K13 대조 - 상세 ∧ HUD ∧ 추적기 없음 → field (상세 신호는 'HUD 없음' 일 때만 - 명세 2.4 순위 7 · 5절 A-2 R-3 (가))"; In = @{ Detail = $true; Hud = $true }; Expect = 'field' })
    foreach ($case in $cases) { Assert-Case $case.Name (Invoke-ClassifierCase -Inputs $case.In) $case.Expect }
}

function Invoke-SettleSequence {
    # 실제 Step-AbyssFieldSettle 를 표본 순서대로 - 시각(가상 초) · 종류('F' 필드 모양 표본 / 'X' 그 밖 회전 = -IsFieldSample 거짓). 첫 상태 $null(상태 없음 -
    # 명세 2.4 는 시작값을 정하지 않음), 그 뒤는 앞 반환값. 반환 = 표본마다 '확정(T/F) Count @Since 상대 초' 를 ' ' 로 ('X' 표본은 Since 를 적지 않음 -
    # 끊긴 뒤의 시작 시각은 다음 'F' 가 정함)
    param([double[]]$Times, [string[]]$Kinds)
    $settleState = $null
    $settleOutputs = @()
    for ($sampleIndex = 0; $sampleIndex -lt $Times.Count; $sampleIndex++) {
        $turnStart = $VIRTUAL_BASE.AddTicks([long][Math]::Round($Times[$sampleIndex] * 10000000))
        $settleState = Step-AbyssFieldSettle -State $settleState -IsFieldSample ($Kinds[$sampleIndex] -eq 'F') -TurnStart $turnStart -SettleSeconds $memberFieldSettleSeconds
        $confirmedText = 'F'
        $countText = '0'
        $sinceText = '-'
        if ($null -ne $settleState) {
            $confirmedField = Get-AbyssJournalField -Object $settleState -Name 'Confirmed'
            $countField = Get-AbyssJournalField -Object $settleState -Name 'Count'
            $sinceField = Get-AbyssJournalField -Object $settleState -Name 'Since'
            if ($confirmedField.Has -and [bool]$confirmedField.Value) { $confirmedText = 'T' }
            if ($countField.Has -and ($null -ne $countField.Value)) { $countText = [string][int]$countField.Value }
            if ($sinceField.Has -and ($null -ne $sinceField.Value)) { $sinceText = Format-Seconds ((([datetime]$sinceField.Value) - $VIRTUAL_BASE).Ticks / 10000000.0) }
        }
        if ($Kinds[$sampleIndex] -eq 'F') { $settleOutputs += ('{0}{1}@{2}' -f $confirmedText, $countText, $sinceText) }
        else { $settleOutputs += ('{0}{1}' -f $confirmedText, $countText) }
    }
    return ($settleOutputs -join ' ')
}

function Test-RowF {
    # 필드 확정 순수 진리표 - 설계 v11 R4 5.1 F1~F6 · F8 (W = 소스 캡처 $memberFieldSettleSeconds, 시각은 W 기준 상대 초 - W 가 바뀌어도 행이 그대로 맞게).
    #   식 = 복귀 루프 run:14216~14218 의 'Count -lt 2 -or (TurnStart − Since) -lt W' 의 부정(명세 2.4). R4-F7 은 분류가 끼는 루프 행(Test-RowOwnSelector)
    $W = [double]$memberFieldSettleSeconds
    $wText = Format-Seconds $W
    $cases = @(
        @{ Name = 'F0 첫 표본 하나 → 미확정 · Count 1 · Since = 그 표본'; Times = @(0); Kinds = @('F'); Expect = 'F1@0' },
        @{ Name = 'R4-F1 F@0 · F@(W−0.1) → 미확정 (Δ < W)'; Times = @(0, ($W - 0.1)); Kinds = @('F', 'F'); Expect = 'F1@0 F2@0' },
        @{ Name = 'R4-F2 F@0 · F@W → @W 확정 (Δ = W - 식이 -lt 라 경계에서 확정 · -le 변이 R4-M20 은 미확정)'; Times = @(0, $W); Kinds = @('F', 'F'); Expect = 'F1@0 T2@0' },
        @{ Name = 'R4-F3 F@0 · F@(W/2) · F@(W−0.1) · F@(W+0.1) → @(W+0.1) 확정 · @(W−0.1) 미확정 · Since 첫 표본 그대로(R4-M6)'; Times = @(0, ($W / 2), ($W - 0.1), ($W + 0.1)); Kinds = @('F', 'F', 'F', 'F'); Expect = 'F1@0 F2@0 F3@0 T4@0' },
        @{ Name = 'R4-F4 F@0 · F@(W+3)(긴 회전) → @(W+3) 확정 (표본 2 · Δ ≥ W)'; Times = @(0, ($W + 3)); Kinds = @('F', 'F'); Expect = 'F1@0 T2@0' },
        @{ Name = 'R4-F5 F@0 · U@1 · F@2 · F@(2+W−0.1) · F@(2+W) → @2 새 첫 표본 → @(2+W) 확정 · @(2+W−0.1) 미확정'; Times = @(0, 1, 2, (2 + $W - 0.1), (2 + $W)); Kinds = @('F', 'X', 'F', 'F', 'F'); Expect = 'F1@0 F0 F1@2 F2@2 T3@2' },
        @{ Name = 'R4-F6 F@0 · I@1 · F@2 · F@(2+W) → @2 새 첫 표본 → @(2+W) 확정'; Times = @(0, 1, 2, (2 + $W)); Kinds = @('F', 'X', 'F', 'F'); Expect = 'F1@0 F0 F1@2 T2@2' })
    foreach ($case in $cases) { Assert-Case ($case.Name + " [W=$wText]") (Invoke-SettleSequence -Times $case.Times -Kinds $case.Kinds) $case.Expect }
    Assert-True 'R4-F8 W 캡처 4.2 < W < 30 (test_abyss_party_member:113 · test_abyss_return_loop:67 과 같은 범위)' (($W -gt 4.2) -and ($W -lt 30)) "W=$wText"
}

# ===== 단계 2.5 - 선분기 루프 행 (층 ① - 실제 Consume-Handoff → 실제 Invoke-AbyssHandoffStart) =====
$script:observedStops = @{}   # LG 의 실행 쪽 - 행이 본 정지 줄(S9~S20)을 문구 이름으로 모아 둡니다

function Save-ObservedStop {
    # 결과의 마지막 [완료] 줄을 문구 이름으로 모아 둡니다 (LG 가 정지 문구 성질을 한곳에서 봄)
    param([string]$Key, $Result)
    $stopLines = @(@($Result.Lines) | Where-Object { $_.StartsWith('[완료]') })
    if ($stopLines.Count -gt 0) { $script:observedStops[$Key] = [string]$stopLines[$stopLines.Count - 1] }
}

function Test-RowK1 {
    # R4-K1 스윕 참 + 패널 ready → 그 회전은 판독·분류 함수 호출 0 (루프 행 - 회전 골격 ④: 스윕 참 회전은 판독하지 않음). own · 층 ①. 그 뒤 회전이
    #   ready 를 판독해 B2 단계로 가고 입장 2연속이면 새 항목 → 결론 inside 로 끝납니다(행이 끝나게 하는 화면)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'ready', 3.0, 'I')); Sweep = @(New-Windows -Pairs @(0, 0.5)) }
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-K1' -Scenario $scenario) -FlowLayer 'selector'
    $sweepTurnKeys = @($result.SweepTrueTurns)
    $readsInSweepTurns = @(@($result.ReadLog) | Where-Object { ($_.Phase -eq 'selector') -and ($sweepTurnKeys -contains [string]$_.Turn) }).Count
    $classifyInSweepTurns = @(@($result.ClassifyLog) | Where-Object { $sweepTurnKeys -contains [string]$_.Turn }).Count
    Assert-Case 'R4-K1 스윕 참 + 패널 ready → 스윕 참 회전 1 이상 · 그 회전들의 판독 0 · 분류 호출 0 (그 뒤 ready → B2 → 입장 2연속 → 결론 inside · 예외 0)' `
        (J @(($sweepTurnKeys.Count -ge 1), $readsInSweepTurns, $classifyInSweepTurns, $result.StartScreen, $result.Thrown)) (J @('True', 0, 0, 'inside', ''))
}

function Test-RowFL {
    # 필드 확정 끊김 - 설계 v11 R4 5.1 FL1~FL5: 선분기 루프(own · 층 ①)에 양보·캡처 실패·스윕 참·판독 도중 실패(일련번호 변화)를 시각 창으로 주입. 확정 시각 =
    #   필드 확정 줄(S3)의 가상 초. 끊김이 있으면 끊김 뒤 첫 표본부터 W 를 다시 세므로 확정 ≥ 끊김 끝 + W 이고, 다시 센 폭(줄의 '첫 표본부터 s초')은 W 이상
    #   한 박자 안입니다. 대조(FL5)는 끼는 회전 없이 첫 박자 안 - 회전 서두 이어받기 줄 제거 변이(R4-M16)에서는 FL1~FL4 도 대조처럼 확정이 앞당겨집니다
    $W = [double]$memberFieldSettleSeconds
    $fieldTimeline = @(New-Timeline -Pairs @(0, 'F'))
    $breakCases = @(
        @{ Name = 'R4-FL1 F 연속 + 양보 회전(@3~4)'; BreakEnd = 4.0; Scenario = @{ Timeline = $fieldTimeline; Active = @(New-Windows -Pairs @(3.0, 4.0)) } },
        @{ Name = 'R4-FL2 F 연속 + 캡처 실패 동결 회전(@3~5)'; BreakEnd = 5.0; Scenario = @{ Timeline = $fieldTimeline; CapFail = @(New-Windows -Pairs @(3.0, 5.0)) } },
        @{ Name = 'R4-FL3 F 연속 + 스윕 참 회전(@2.8~4)'; BreakEnd = 4.0; Scenario = @{ Timeline = $fieldTimeline; Sweep = @(New-Windows -Pairs @(2.8, 4.0)) } },
        @{ Name = 'R4-FL4 F 연속 + 판독 도중 실패(일련번호 변화 - @3.4~3.8 회전의 첫 판독만 실패)'; BreakEnd = 3.4; Scenario = @{ Timeline = $fieldTimeline; SerialFail = @(New-Windows -Pairs @(3.4, 3.8)) } })
    $breakResults = @{}
    foreach ($case in $breakCases) {
        $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name $case.Name -Scenario $case.Scenario) -FlowLayer 'selector'
        $breakResults[$case.Name] = $result
        $settle = Get-SettleLineInfo -Result $result
        $lowerBound = [double]$case.BreakEnd + $W
        Assert-True ($case.Name + ' → 끊김이 연속을 끊음: 필드 확정 줄 1 · 확정 ≥ 끊김 끝 + W · 다시 센 폭 W 이상 한 박자 안 · 결론 field · 예외 0') `
            ($settle.Found -and ($settle.Lines -eq 1) -and ($settle.T -ge ($lowerBound - $TIME_EPSILON)) -and ($settle.T -le ($lowerBound + 5)) -and
                ($settle.Span -ge ($W - $TIME_EPSILON)) -and ($settle.Span -lt ($W + 1.5)) -and ($result.StartScreen -eq 'field') -and (-not $result.Thrown)) `
            ('확정 {0}초(하한 {1}) · 폭 {2} · 줄 {3} · 결론 [{4}] · exit [{5}] · 예외 [{6}]' -f (Format-Seconds $settle.T), (Format-Seconds $lowerBound), (Format-Seconds $settle.Span), $settle.Lines, $result.StartScreen, $result.ExitCode, $result.Thrown)
    }
    # 끊김을 실제로 만들었는지(하니스 자기 검사) - 양보 문맥(회전 골격 ② '이어받기 시작') · 동결 블록의 안전 확인·이번 회전 탐침 · 스윕 참 회전 · 판독 실패 회전
    $fl1 = $breakResults['R4-FL1 F 연속 + 양보 회전(@3~4)']
    $fl2 = $breakResults['R4-FL2 F 연속 + 캡처 실패 동결 회전(@3~5)']
    $fl3 = $breakResults['R4-FL3 F 연속 + 스윕 참 회전(@2.8~4)']
    $fl4 = $breakResults['R4-FL4 F 연속 + 판독 도중 실패(일련번호 변화 - @3.4~3.8 회전의 첫 판독만 실패)']
    Assert-Case "R4-FL1~FL4 주입 확인 - 양보 문맥 '$YIELD_CONTEXT' · 동결의 안전 확인·탐침 1 이상 · 스윕 참 회전 1 이상 · 실패 판독이 든 회전 1 이상" `
        (J @(($fl1.YieldContexts -split ' / ' | Where-Object { $_ -eq $YIELD_CONTEXT } | Select-Object -First 1), (($fl2.SafeStopCalls -ge 1) -and ($fl2.ProbeCalls -ge 1)),
            (@($fl3.SweepTrueTurns).Count -ge 1), (@(@($fl4.Turns) | Where-Object { -not $_.Valid }).Count -ge 1))) (J @($YIELD_CONTEXT, 'True', 'True', 'True'))
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-FL5' -Scenario @{ Timeline = $fieldTimeline }) -FlowLayer 'selector'
    $settle = Get-SettleLineInfo -Result $result
    Assert-True 'R4-FL5 대조 - 같은 시각표에 끼는 회전 없이 F 만 → 확정 W 이상 W+1.5 미만 · 폭 = 확정 시각(0초 첫 표본부터) · 결론 field' `
        ($settle.Found -and ($settle.T -ge ($W - $TIME_EPSILON)) -and ($settle.T -lt ($W + 1.5)) -and ([Math]::Abs($settle.Span - $settle.T) -lt 0.051) -and ($result.StartScreen -eq 'field')) `
        ('확정 {0}초 · 폭 {1} · 결론 [{2}] · 예외 [{3}]' -f (Format-Seconds $settle.T), (Format-Seconds $settle.Span), $result.StartScreen, $result.Thrown)
}

function Test-RowNextSelector {
    # next 선분기 (설계 v11 R4 5.2 - 픽스처: reentered NB · nextOwner = 이번 컨텍스트 · 실제 Consume-Handoff · 층 ①). ② 빌드에서 next 는 생기지 않지만(명세 0.5
    #   '숨음') 코드는 own 과 같은 선분기를 지납니다. B2 단계는 ② 의 선분기 B2 단계(5절 A-2 R-2 - next 는 닫기·새 항목 0, 마감은 HEAD 문구 + 놓아줌 표지)
    $W = [double]$memberFieldSettleSeconds
    $U30 = [double]$memberUnknownOverlaySeconds
    $Tpm = [int]$capturedTimeoutPartyMatch
    $insideAfterOverlay = @(New-Timeline -Pairs @(0, 'I'))

    # R4-N2 - 확정 전 필드 모양은 증거가 아님(점검:226 핵심 행): 닫기·통과·기록 0, 던전 안 2연속이 결론
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N2' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F', ($W - 0.5), 'I')) }) -FlowLayer 'selector'
    $measure = Get-StartMeasureExpected -Result $result
    $measureLines = @(Get-PatternLines -Result $result -Pattern $S1_PATTERN)
    $measureProblem = "시작 직후 계측 줄 $($measureLines.Count)개"
    if ($measureLines.Count -eq 1) { $measureProblem = Test-MeasureLine -Line $measureLines[0] -Pattern $S1_PATTERN -ExpectU $measure.U -ExpectF $measure.F -ExpectSeconds $measure.Seconds -ExpectBreaks 0 }
    Assert-Case 'R4-N2 F@0~(W−0.5) 뒤 I · I (점검:226 핵심 행) → 결론 inside · 필드 확정 줄 0 · 복귀 루프 0 · 기록 0(파일 불변) · 시작 직후 계측 줄 1(필드 모양 표본 수·첫 표본부터 던전 안 초 = 하니스 기록, 2표본 이상) · exit 0건 · 입력 0 · 예외 0' `
        (J @($result.StartScreen, (Get-SettleLineInfo -Result $result).Lines, (Get-ReturnText $result), $result.Unchanged, $measureProblem, ($measure.F -ge 2), $result.ExitCode, $result.Inputs, $result.Thrown)) `
        (J @('inside', 0, '', 'True', '', 'True', '', 0, ''))

    # R4-N4 - 30초 미만 알 수 없음은 정리하지 않음
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N4' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'U', 11.5, 'I')) }) -FlowLayer 'selector'
    Assert-Case 'R4-N4 U@0~11 · I · I → 결론 inside · 선분기 이벤트 정리 0 · 기록 0 · 예외 0' `
        (J @($result.StartScreen, @(Get-OverlayTimes -Result $result).Count, $result.Unchanged, $result.Thrown)) (J @('inside', 0, 'True', ''))

    # R4-N5 · EV1 - 끊김 없는 알 수 없음 30초(조정) → 이벤트 정리 1회(스텁이 오버레이를 닫음 → I · I)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N5' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'U')); AfterOverlay = $insideAfterOverlay }) -FlowLayer 'selector'
    $overlayTimes = @(Get-OverlayTimes -Result $result)
    $firstUnknown = @(Get-ValidTurns -Result $result -Key 'U') | Select-Object -First 1
    $firstUnknownT = $(if ($null -ne $firstUnknown) { [double]$firstUnknown.T } else { -1 })
    Assert-True 'R4-N5 U 연속 조정 30초 → 이벤트 정리 1 (첫 U 표본 + 30초 이상 한 박자 안) → 정리가 닫은 뒤 I · I → 결론 inside · 기록 0' `
        (($overlayTimes.Count -eq 1) -and ($firstUnknownT -ge 0) -and ($overlayTimes[0] -ge ($firstUnknownT + $U30 - $TIME_EPSILON)) -and ($overlayTimes[0] -lt ($firstUnknownT + $U30 + 1.5)) -and
            ($result.StartScreen -eq 'inside') -and ($result.Unchanged -eq 'True')) `
        ('정리 {0}회 @{1} · 첫 U {2} · 결론 [{3}] · 예외 [{4}]' -f $overlayTimes.Count, (@($overlayTimes | ForEach-Object { Format-Seconds $_ }) -join ','), (Format-Seconds $firstUnknownT), $result.StartScreen, $result.Thrown)
    Assert-Case 'EV1 N5 와 같은 입력 → 이벤트 정리 안내 줄(S8) 1 · Clear-EventOverlay 1 (선분기 단계)' `
        (J @((Get-LineCount -Result $result -Line ($S8_OVERLAY_FORMAT -f $memberUnknownOverlaySeconds)), $overlayTimes.Count)) (J @(1, 1))

    # R4-N5 둘째 구간 - 'unknown' 이 아닌 유효 회전(F 한 표본)이 끼면 다시 1회 (D 순위 9 의 규칙 그대로 - R4 3.3)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U', 40.0, 'F', 41.5, 'U')); AfterOverlay = $insideAfterOverlay; AfterOverlayAt = 2 }
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N5b' -Scenario $scenario) -FlowLayer 'selector'
    $overlayTimes = @(Get-OverlayTimes -Result $result)
    Assert-True 'R4-N5 둘째 U 구간 - U@0~40 · F(1.5초) · U@41.5~ → 정리 2 (첫째 약 30초 · 둘째 41.5 + 30초 이상 한 박자 안) → 결론 inside' `
        (($overlayTimes.Count -eq 2) -and ($overlayTimes[0] -lt 32) -and ($overlayTimes[1] -ge (41.5 + $U30 - $TIME_EPSILON)) -and ($overlayTimes[1] -lt (41.5 + $U30 + 2.2)) -and ($result.StartScreen -eq 'inside')) `
        ('정리 {0}회 @{1} · 결론 [{2}] · 예외 [{3}]' -f $overlayTimes.Count, (@($overlayTimes | ForEach-Object { Format-Seconds $_ }) -join ','), $result.StartScreen, $result.Thrown)

    # R4-N5′ - 캡처 실패 60초는 30초 시계에서 빠지고(조정), 동결 회전에서는 부르지 않음
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U')); CapFail = @(New-Windows -Pairs @(20.0, 80.0)); AfterOverlay = $insideAfterOverlay }
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N5′' -Scenario $scenario) -FlowLayer 'selector'
    $overlayTimes = @(Get-OverlayTimes -Result $result)
    Assert-True 'R4-N5′ U@0~20 · 캡처 실패 @20~80 · U@80~ → 정리 1 = 벽시계 약 90초(조정 30초 - 실패 60초는 빠짐) · 동결 회전(@20~80)에서 0 · 결론 inside' `
        (($overlayTimes.Count -eq 1) -and ($overlayTimes[0] -ge (90 - $TIME_EPSILON)) -and ($overlayTimes[0] -lt 93) -and ($result.StartScreen -eq 'inside')) `
        ('정리 {0}회 @{1} · 캡처 실패 누적 {2}초 · 결론 [{3}] · 예외 [{4}]' -f $overlayTimes.Count, (@($overlayTimes | ForEach-Object { Format-Seconds $_ }) -join ','), (Format-Seconds ($result.FailTotalMs / 1000)), $result.StartScreen, $result.Thrown)

    # R4-N5″ - 경계는 -ge (run:12665): 조정 30−0.1초 회전 0 · 30초 정각 회전 1. 회전 대기 700ms 를 가상 100ms 로(SleepMap) 두어 0.1초 박자에 정각 회전을 만듦
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U')); AfterOverlay = $insideAfterOverlay; SleepMap = @{ 700 = 100 } }
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N5″' -Scenario $scenario) -FlowLayer 'selector'
    $overlayTimes = @(Get-OverlayTimes -Result $result)
    $firstUnknown = @(Get-ValidTurns -Result $result -Key 'U') | Select-Object -First 1
    $firstUnknownT = $(if ($null -ne $firstUnknown) { [double]$firstUnknown.T } else { -1 })
    $edgeTurns = @(@($result.Turns) | Where-Object { [Math]::Abs([double]$_.T - ($firstUnknownT + $U30 - 0.1)) -lt $TIME_EPSILON })
    Assert-True 'R4-N5″ U 연속 0.1초 박자 → 조정 30−0.1초 회전(있음) 정리 0 · 30초 정각 회전 정리 1 (-ge) · 회전 대기 700ms 가 박자 바꿈에 걸림' `
        (($result.SleepMapHits -gt 0) -and ($edgeTurns.Count -ge 1) -and ($overlayTimes.Count -eq 1) -and ([Math]::Abs($overlayTimes[0] - ($firstUnknownT + $U30)) -lt $TIME_EPSILON)) `
        ('박자 바꿈 {0}회 · 30−0.1 회전 {1} · 정리 {2}회 @{3} · 첫 U {4} · 예외 [{5}]' -f $result.SleepMapHits, $edgeTurns.Count, $overlayTimes.Count, (@($overlayTimes | ForEach-Object { Format-Seconds $_ }) -join ','), (Format-Seconds $firstUnknownT), $result.Thrown)

    # R4-N6 - F·U 교대(각 F 구간 < W, 각 U 구간 < 30초)로 조정 Tpm 초 → 미결 마감 (start-unknown) 코드 4 (next 문구 S15)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N6' -Scenario @{ Cycle = @('U', 'U', 'U', 'F') }) -FlowLayer 'selector'
    Save-ObservedStop -Key 'S15' -Result $result
    Assert-Case "R4-N6 F·U 교대 조정 Tpm($Tpm)초 → 진단 '$DIAG_UNKNOWN' 1 · S15(초 = `${timeoutPartyMatch}) · exit 4 · 이벤트 정리 0 · 클릭 0 · 기록 0 · 예외 0" `
        (J @($result.ExitCode, (Get-StopLines $result), (Get-DiagText $result 'selector'), @(Get-OverlayTimes -Result $result).Count, $result.Inputs, $result.Unchanged, $result.Thrown)) `
        (J @('4', ($S15_NEXT_UNKNOWN_FORMAT -f $Tpm), $DIAG_UNKNOWN, 0, 0, 'True', ''))
    Assert-True 'R4-N6 미결 마감 시각 = 선분기 시작부터 조정 Tpm (그 이상 한 박자 안)' (($result.EndT -ge ($Tpm - $TIME_EPSILON)) -and ($result.EndT -lt ($Tpm + 1.5))) ('끝 {0}초' -f (Format-Seconds $result.EndT))

    # R4-N6″ - 조작 20초(@100~120)만큼 마감이 늦고, 마감에 닿는 회전이 캡처 실패(@318~330)면 동결 중 확정 0 → 복구 뒤 첫 유효 회전에서 코드 4 (마감 되돌림 0)
    $scenario = @{ Cycle = @('U', 'U', 'U', 'F'); Active = @(New-Windows -Pairs @(100.0, 120.0)); CapFail = @(New-Windows -Pairs @(318.0, 330.0)) }
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N6″' -Scenario $scenario) -FlowLayer 'selector'
    $adjustedDeadline = $Tpm + ($result.YieldTotalMs / 1000) + ($result.FailTotalMs / 1000)
    Assert-True 'R4-N6″ U 연속 + 조작 20초 + 마감 자리 캡처 실패 → 마감 = Tpm + 양보 + 캡처 실패(조정 · 되돌림 0) · 실패 창 끝(330) 뒤 · S15 · exit 4' `
        (($result.ExitCode -eq '4') -and ((Get-StopLines $result) -ceq ($S15_NEXT_UNKNOWN_FORMAT -f $Tpm)) -and ($result.EndT -ge ($adjustedDeadline - $TIME_EPSILON)) -and
            ($result.EndT -lt ($adjustedDeadline + 3)) -and ($result.EndT -ge 330) -and ($result.YieldTotalMs -ge 19000) -and ($result.FailTotalMs -ge 11000)) `
        ('끝 {0}초 · 조정 마감 {1} · 양보 {2} · 실패 {3} · exit [{4}] · 정지 [{5}] · 예외 [{6}]' -f (Format-Seconds $result.EndT), (Format-Seconds $adjustedDeadline), (Format-Seconds ($result.YieldTotalMs / 1000)), (Format-Seconds ($result.FailTotalMs / 1000)), $result.ExitCode, (Get-StopLines $result), $result.Thrown)

    # R4-N6‴ - 한도가 30초 이하면 정리보다 마감이 먼저 (그대로 수용 - R4 3.3). Tpm 캡처값 대신 20
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N6‴' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'U')) } -Extra @{ Tpm = 20 }) -FlowLayer 'selector'
    Assert-Case 'R4-N6‴ Tpm 20 + U 연속 → 이벤트 정리 0 · (start-unknown) 1(S15 의 초 = 20 - 문구의 초가 변수) · exit 4 · 예외 0' `
        (J @(@(Get-OverlayTimes -Result $result).Count, (Get-StopLines $result), $result.ExitCode, $result.Thrown)) (J @(0, ($S15_NEXT_UNKNOWN_FORMAT -f 20), '4', ''))
    Save-ObservedStop -Key 'S15-20' -Result $result

    # R4-N7 - 각 필드 모양 구간이 W 미만이면 확정 0 (U 가 연속을 끊음)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'F', 3.5, 'U', 5.0, 'F', 10.5, 'I')) }
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N7' -Scenario $scenario) -FlowLayer 'selector'
    Assert-Case 'R4-N7 F@0~3.5 · U · F@5~10.5(< W) · I · I → 필드 확정 줄 0 · 결론 inside · 기록 0 · 예외 0' `
        (J @((Get-SettleLineInfo -Result $result).Lines, $result.StartScreen, $result.Unchanged, $result.Thrown)) (J @(0, 'inside', 'True', ''))

    # R4-N8 - 같은 회전 메뉴 참 → (menu-overlay) 정지 · 필드 연속 폐기 · 복귀 루프 0 (S11)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N8' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F', 1.5, 'MENU')) }) -FlowLayer 'selector'
    Save-ObservedStop -Key 'S11' -Result $result
    Assert-Case "R4-N8 F@0 · F ∧ 같은 회전 ESC 메뉴 → exit 4 · S11 · 진단 '$DIAG_MENU' · 필드 확정 줄 0 · 복귀 루프 0 · 입력 0(ESC 전송 0) · 기록 0 · 예외 0" `
        (J @($result.ExitCode, (Get-StopLines $result), (Get-DiagText $result 'selector'), (Get-SettleLineInfo -Result $result).Lines, (Get-ReturnText $result), $result.Inputs, $result.Unchanged, $result.Thrown)) `
        (J @('4', $S11_NEXT_MENU, $DIAG_MENU, 0, '', 0, 'True', ''))

    # 선택 화면 - next (S9 경로 · 명세 2.5 결론 표 'selection' next 문구 - 제안 행: R4 5.2 에 next 선택 화면 행이 없어 LG 의 S9 를 실행으로도 봄)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'N8s' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'SEL')) }) -FlowLayer 'selector'
    Save-ObservedStop -Key 'S9' -Result $result
    Assert-Case "N8s(S9 경로) next + 선택 화면 → exit 4 · S9 · 진단 '$DIAG_SELECTION' · 복귀 루프 0 · 입력 0(X·ESC 전송 0) · 기록 0 · 예외 0" `
        (J @($result.ExitCode, (Get-StopLines $result), (Get-DiagText $result 'selector'), (Get-ReturnText $result), $result.Inputs, $result.Unchanged, $result.Thrown)) `
        (J @('4', $S9_NEXT_SELECTION, $DIAG_SELECTION, '', 0, 'True', ''))

    # R4-N9 - next 3버튼(커스텀) → pre-clear 코드 4 · 마커·cleared 0 (S17 커스텀 변형 + 놓아줌 표지 - J22)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N9' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'R3')) }) -FlowLayer 'selector'
    Save-ObservedStop -Key 'S17-custom' -Result $result
    Assert-Case 'R4-N9 next(커스텀) + 3버튼 → exit 4 · S17(커스텀 꼬리 + (release)) · 진단 1 · 마커 0 · cleared 0 · 기록 0 · 입력 0 · 예외 0' `
        (J @($result.ExitCode, (Get-StopLines $result), @($result.Diags).Count, $result.Markers, $result.ClearedCalls, $result.Unchanged, $result.Inputs, $result.Thrown)) `
        (J @('4', ($S17_BASE + $S17_CUSTOM_TAIL + $RELEASE_TAIL), 1, 0, 0, 'True', 0, ''))

    # R4-N10 - next + ready → B2 단계 'entered' → 결론 inside(같은 항목 열쇠 · 새 항목 0 · 닫기 0)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N10' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'ready', 2.5, 'I')) }) -FlowLayer 'selector'
    $entryLines = @(Get-PatternLines -Result $result -Pattern $S2_PATTERN)
    $entryProblem = "입장 계측 줄 $($entryLines.Count)개"
    if ($entryLines.Count -eq 1) {
        $entryProblem = Test-MeasureLine -Line $entryLines[0] -Pattern $S2_PATTERN -ExpectU 0 -ExpectF 0 -ExpectSeconds $null -ExpectBreaks 0
        if ([double]::Parse([regex]::Match($entryLines[0], $S2_PATTERN).Groups['w'].Value, [Globalization.CultureInfo]::InvariantCulture) -ne $W) { $entryProblem += ' · W 다름' }
    }
    Assert-Case 'R4-N10 next + ready → B2 시작 줄(S7 준비 패널 · Tpm) · B2 입장 계측 줄 1(로딩 0 · 필드 0 · 끊김 0 · W) → 결론 inside · FreshEntry 거짓 · 열쇠 NB 그대로 · 닫기·새 항목 0(파일 불변) · ownFreshEntry 줄 0 · 예외 0' `
        (J @((Get-LineCount -Result $result -Line ($S7_B2_START_FORMAT -f $B2_LABELS.ready, $Tpm)), $entryProblem, $result.StartScreen, $result.FreshEntry, $result.Nonce, $result.Unchanged,
            (Get-LineCount -Result $result -Line $S6_FRESH_ENTRY), $result.Thrown)) `
        (J @(1, '', 'inside', 'False', 'NB', 'True', 0, ''))

    # R4-N10 마감 - next B2 단계 마감 → HEAD 문구 + 놓아줌 표지 코드 4 (재전달 표지 없음 - J22). 첫 패널 표본(10초 뒤)부터 조정 Tpm - 미결 마감(선분기 시작부터)은
    #   B2 단계에서 멈춰야 합니다(R4-M21: 멈추지 않으면 300초에 (start-unknown))
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N10b' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'U', 10.0, 'ready')) }) -FlowLayer 'selector'
    Save-ObservedStop -Key 'S18' -Result $result
    Assert-Case "R4-N10 B2 마감(next) - U 10초 뒤 ready 지속 → 진단 '$DIAG_B2' · S18(준비 패널 · Tpm · 끝 (release)) · exit 4 · (start-unknown) 0 · 기록 0 · 예외 0" `
        (J @((Get-DiagText $result 'selector'), (Get-StopLines $result), $result.ExitCode, ((Get-StopLines $result).Contains('(start-unknown)')), $result.Unchanged, $result.Thrown)) `
        (J @($DIAG_B2, ($S18_B2_TIMEOUT_FORMAT -f $B2_LABELS.ready, $Tpm), '4', 'False', 'True', ''))
    Assert-True 'R4-N10 B2 마감 시각 = 첫 패널 표본(10초 뒤)부터 조정 Tpm' (($result.EndT -ge (10 + $Tpm - $TIME_EPSILON)) -and ($result.EndT -lt (10 + $Tpm + 2))) ('끝 {0}초' -f (Format-Seconds $result.EndT))

    # R4-N14 - 던전 안 2연속은 동결 회전을 넘어 이어짐(유지)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N14' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')); CapFail = @(New-Windows -Pairs @(0.5, 4.0)) }) -FlowLayer 'selector'
    Assert-Case 'R4-N14 I@0 · 캡처 실패(동결) · I → 결론 inside · 결론까지 유효 I 표본 2(동결은 연속 유지 - R4-M25 면 3) · 동결 블록 안전 확인·탐침 1 이상 · 예외 0' `
        (J @($result.StartScreen, @(Get-ValidTurns -Result $result -Key 'I').Count, (($result.SafeStopCalls -ge 1) -and ($result.ProbeCalls -ge 1)), $result.Thrown)) (J @('inside', 2, 'True', ''))

    # R4-N15 - 양보 회전은 던전 안 연속을 0 으로
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N15' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')); Active = @(New-Windows -Pairs @(0.5, 1.5)) }) -FlowLayer 'selector'
    Assert-Case "R4-N15 I@0 · 양보 회전 · I · I → 결론 inside · 결론까지 유효 I 표본 3(양보 뒤 1 부터) · 양보 문맥 '$YIELD_CONTEXT' · 예외 0" `
        (J @($result.StartScreen, @(Get-ValidTurns -Result $result -Key 'I').Count, $result.YieldContexts, $result.Thrown)) (J @('inside', 3, $YIELD_CONTEXT, ''))

    # R4-N16 - 스윕 굶김 회전·판독 도중 실패 회전(복구 회전)이 30초를 넘겨 이어져도 그 회전들에서 정리 0 → 첫 유효 U 회전에서 1
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U')); Sweep = @(New-Windows -Pairs @(25.0, 40.0)); AfterOverlay = $insideAfterOverlay }
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N16 굶김' -Scenario $scenario) -FlowLayer 'selector'
    $overlayTimes = @(Get-OverlayTimes -Result $result)
    Assert-True "R4-N16 U 구간 안 스윕 참 연속(@25~40 - 한도 $memberSweepStreakLimit 회째부터 굶김 회전) → 그 회전들 정리 0 → 스윕이 그친 뒤 첫 유효 U 회전에서 1 · 결론 inside" `
        (($overlayTimes.Count -eq 1) -and ($overlayTimes[0] -ge (40 - $TIME_EPSILON)) -and ($overlayTimes[0] -lt 43) -and (@($result.SweepTrueTurns).Count -ge $memberSweepStreakLimit) -and ($result.StartScreen -eq 'inside')) `
        ('정리 {0}회 @{1} · 스윕 참 회전 {2} · 결론 [{3}] · 예외 [{4}]' -f $overlayTimes.Count, (@($overlayTimes | ForEach-Object { Format-Seconds $_ }) -join ','), @($result.SweepTrueTurns).Count, $result.StartScreen, $result.Thrown)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U')); SerialFail = @(New-Windows -Pairs @(25.0, 40.0)); AfterOverlay = $insideAfterOverlay }
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N16 복구' -Scenario $scenario) -FlowLayer 'selector'
    $overlayTimes = @(Get-OverlayTimes -Result $result)
    Assert-True 'R4-N16 U 구간 안 판독 도중 실패 회전(@25~40 - 회전마다 첫 판독 실패 = 복구 회전) → 그 회전들 정리 0 → 첫 유효 U 회전에서 1 · 결론 inside' `
        (($overlayTimes.Count -eq 1) -and ($overlayTimes[0] -ge (40 - $TIME_EPSILON)) -and ($overlayTimes[0] -lt 43) -and ($result.StartScreen -eq 'inside')) `
        ('정리 {0}회 @{1} · 결론 [{2}] · 예외 [{3}]' -f $overlayTimes.Count, (@($overlayTimes | ForEach-Object { Format-Seconds $_ }) -join ','), $result.StartScreen, $result.Thrown)

    # N19 - next + 상세 화면 → S13 · (selection-overlay) 코드 4 · 클릭·기록 0 (U2 - 5절 A-2 R-3)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'N19' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'DET')) }) -FlowLayer 'selector'
    Save-ObservedStop -Key 'S13' -Result $result
    Assert-Case "N19 next + 상세 화면 → exit 4 · S13 · 진단 '$DIAG_DETAIL' · 복귀 루프 0 · 이벤트 정리 0 · 입력 0 · 기록 0 · 예외 0" `
        (J @($result.ExitCode, (Get-StopLines $result), (Get-DiagText $result 'selector'), (Get-ReturnText $result), @(Get-OverlayTimes -Result $result).Count, $result.Inputs, $result.Unchanged, $result.Thrown)) `
        (J @('4', $S13_NEXT_DETAIL, $DIAG_DETAIL, '', 0, 0, 'True', ''))

    # V18 팝업 시작 × next - B2 단계는 정리하지 않음(B2 안 알 수 없음 45초에도 Clear-EventOverlay 0 - P17)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'V18 팝업×next' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'popup', 5.0, 'U', 50.0, 'I')) }) -FlowLayer 'selector'
    Assert-Case 'V18 팝업 시작 × next → B2 시작 줄(권장 인원 팝업) · B2 안 U 45초에도 Clear-EventOverlay 0 · (start-unknown) 0 · 입장 2연속 → 결론 inside · 닫기 0 · 예외 0' `
        (J @((Get-LineCount -Result $result -Line ($S7_B2_START_FORMAT -f $B2_LABELS.popup, $Tpm)), @(Get-OverlayTimes -Result $result).Count, ((Get-StopLines $result).Contains('(start-unknown)')),
            $result.StartScreen, $result.Unchanged, $result.Thrown)) `
        (J @(1, 0, 'False', 'inside', 'True', ''))
}

function Test-RowOwnSelector {
    # own 선분기 (설계 v11 R4 5.3 - 픽스처: 열린 entered NA · owner·세대 일치 · afterEntry.index 2 · 실제 Consume-Handoff · 층 ①). 키 합계는 ⑳ 몫 - 여기서는
    #   열쇠 항목·인덱스 시작값까지(명세 3.2 O 행). 닫기 = launchState done · reason 'abandoned-pre-entry-start' · screen = 그 종류(명세 2.5 Close-AbyssOwnEntryBeforeEntry)
    $W = [double]$memberFieldSettleSeconds
    $Tpm = [int]$capturedTimeoutPartyMatch

    # O1(CH16o) - 본류 시작 구간이 Consume-Handoff 가 정한 역할을 그대로 넘김(블록이 역할을 덮어쓰지 않음 · $roleNone 은 그 결과) + 선분기 결론 inside
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'O1(CH16o)' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')) }) -FlowLayer 'selector'
    Assert-Case 'R4-O1(CH16o 이동) 어비스 커스텀 + own nonce + 열린 자기 항목 + I · I → Consume 호출 1 · 반환 ok · Role own · Nonce NA · $roleNone 거짓 · 선분기 1 · 결론 inside · exit 0건 · 입력 0 · 예외 0' `
        (J @($result.ConsumeCalls, $result.Returned, $result.Role, $result.Nonce, $result.RoleNone, $result.SelectorCalls, $result.StartScreen, $result.ExitCode, $result.Inputs, $result.Thrown)) `
        (J @(1, 'ok(1)', 'own', 'NA', 'False', 1, 'inside', '', 0, ''))

    # R4-O2 - 점검:226 핵심 행(own): 확정 전 필드 모양 → 닫기 0 · 이어받기
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O2' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F', ($W - 0.5), 'I')) }) -FlowLayer 'selector'
    $measure = Get-StartMeasureExpected -Result $result
    $measureLines = @(Get-PatternLines -Result $result -Pattern $S1_PATTERN)
    $measureProblem = "시작 직후 계측 줄 $($measureLines.Count)개"
    if ($measureLines.Count -eq 1) { $measureProblem = Test-MeasureLine -Line $measureLines[0] -Pattern $S1_PATTERN -ExpectU $measure.U -ExpectF $measure.F -ExpectSeconds $measure.Seconds -ExpectBreaks 0 }
    Assert-Case 'R4-O2 F@0~(W−0.5) 뒤 I · I (점검:226 핵심 행) → 결론 inside · 선분기 닫기 0(파일 불변 - NA launched) · 복귀 루프 0 · 열쇠 NA · 키 시작값 2/32,66 · 시작 직후 계측 줄 1(하니스 기록) · 예외 0' `
        (J @($result.StartScreen, $result.Unchanged, (Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), (Get-ReturnText $result), $result.Nonce, $result.AfterEntry, $measureProblem, $result.Thrown)) `
        (J @('inside', 'True', 'NA:entered/launched//', '', 'NA', '2/32,66', '', ''))

    # R4-O4′ - ready → 입장 없이 B2 마감 → 닫기 1 · S18(+ (release)) 코드 4 · (start-unknown) 0 · 클릭 0. U 20초 뒤 ready(B2 시작) → 미결 마감은 B2 에서 멈춤(R4-M21) ·
    #   B2 안 알 수 없음에도 이벤트 정리 0(P17)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U', 20.0, 'ready', 25.0, 'U')) }
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O4′' -Scenario $scenario) -FlowLayer 'selector'
    Assert-Case "R4-O4′ U@0~20 · ready · B2 안 U 지속 → 닫기 1(NA done · $CLOSE_REASON · ready) · own 닫기 성공 줄(S4) · B2 시작 줄 · 진단 '$DIAG_B2' · S18(준비 패널 · Tpm · (release)) · exit 4 · (start-unknown) 0 · 이벤트 정리 0 · 입력 0 · 예외 0" `
        (J @((Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), (Get-LineCount -Result $result -Line ($S4_CLOSE_FORMAT -f 'ready')), (Get-LineCount -Result $result -Line ($S7_B2_START_FORMAT -f $B2_LABELS.ready, $Tpm)),
            (Get-DiagText $result 'selector'), (Get-StopLines $result), $result.ExitCode, ((Get-StopLines $result).Contains('(start-unknown)')), @(Get-OverlayTimes -Result $result).Count, $result.Inputs, $result.Thrown)) `
        (J @("NA:entered/done/$CLOSE_REASON/ready", 1, 1, $DIAG_B2, ($S18_B2_TIMEOUT_FORMAT -f $B2_LABELS.ready, $Tpm), '4', 'False', 0, 0, ''))
    Assert-True 'R4-O4′ B2 마감 시각 = 첫 패널 표본(20초 뒤)부터 조정 Tpm (선분기 시작부터의 미결 마감 300초가 아님)' (($result.EndT -ge (20 + $Tpm - $TIME_EPSILON)) -and ($result.EndT -lt (20 + $Tpm + 2))) ('끝 {0}초' -f (Format-Seconds $result.EndT))

    # O4‴ - O4′ + 닫기 저장 1회 'locked'(닫기 실패) → [경고] 1 · B2 마감 (release) 코드 4 · NA 열린 채(GUI 틱의 done 은 ⑯ 몫 - J22)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'ready')); LockPlan = @(@{ Phase = 'selector'; Ordinal = 1; Mode = 'once' }) }
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'O4‴' -Scenario $scenario) -FlowLayer 'selector'
    Assert-Case 'O4‴ ready(닫기 저장 locked) → own 닫기 실패 [경고](파일 사용 중) 1 · 닫기 성공 줄 0 · CleanupOnly 거짓 · S18((release)) · exit 4 · NA launched 그대로 · 새 항목 0 · 예외 0' `
        (J @((Get-LineCount -Result $result -Line ($S5_CLOSE_FAIL_FORMAT -f '파일 사용 중')), (Get-LineCount -Result $result -Line ($S4_CLOSE_FORMAT -f 'ready')), $result.CleanupOnly, (Get-StopLines $result), $result.ExitCode,
            (Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), (Get-NewEntryLabels $result.Journal), $result.Thrown)) `
        (J @(1, 0, 'False', ($S18_B2_TIMEOUT_FORMAT -f $B2_LABELS.ready, $Tpm), '4', 'NA:entered/launched//', '', ''))

    # O4⁗ - ready → B2 'entered' → 자기 항목 생성 'locked' → 키 0 · S20 코드 4 (닫기 성공 / 닫기 실패 두 변형)
    foreach ($variant in @(
            @{ Name = '닫기 성공'; LockPlan = @(@{ Phase = 'selector'; Ordinal = 2; Mode = 'once' }); Expect = "NA:entered/done/$CLOSE_REASON/ready"; Warn = 0 },
            @{ Name = '닫기 실패'; LockPlan = @(@{ Phase = 'selector'; Ordinal = 1; Mode = 'once' }, @{ Phase = 'selector'; Ordinal = 2; Mode = 'once' }); Expect = 'NA:entered/launched//'; Warn = 1 })) {
        $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'ready', 2.5, 'I')); LockPlan = $variant.LockPlan }
        $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name ('O4⁗ ' + $variant.Name) -Scenario $scenario) -FlowLayer 'selector'
        Save-ObservedStop -Key 'S20' -Result $result
        Assert-Case ('O4⁗ ready → B2 entered → 생성 locked (' + $variant.Name + ') → 닫기 실패 [경고] 수 · S20((release)) · exit 4 · 키 0(입력 0) · NA 상태 · 새 항목 0 · FreshEntry 거짓 · ownFreshEntry 줄 0 · 예외 0') `
            (J @((Get-LineCount -Result $result -Line ($S5_CLOSE_FAIL_FORMAT -f '파일 사용 중')), (Get-StopLines $result), $result.ExitCode, $result.Inputs, (Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')),
                (Get-NewEntryLabels $result.Journal), $result.FreshEntry, (Get-LineCount -Result $result -Line $S6_FRESH_ENTRY), $result.Thrown)) `
            (J @($variant.Warn, $S20_CREATE_FAIL, '4', 0, $variant.Expect, '', 'False', 0, ''))
    }

    # R4-O6 - 오버레이 밑 패널: 알 수 없음 30초 → 이벤트 정리 1 → (스텁이 오버레이를 닫음) ready → O4 와 같음(선분기 안에서 닫힘)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U')); AfterOverlay = @(New-Timeline -Pairs @(0, 'ready', 3.0, 'I')) }
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O6' -Scenario $scenario) -FlowLayer 'selector'
    $newLabel = Get-NewEntryLabels $result.Journal
    Assert-Case 'R4-O6 U 30초 → 이벤트 정리 1 → ready → 닫기(ready) · B2 → 입장 2연속 → 새 항목 1 · ownFreshEntry 줄 1 · FreshEntry 참 · 열쇠 = 새 항목 · 결론 inside · 예외 0' `
        (J @(@(Get-OverlayTimes -Result $result).Count, (Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), @($newLabel -split ',' | Where-Object { $_ }).Count,
            (Get-LineCount -Result $result -Line $S6_FRESH_ENTRY), $result.FreshEntry, ($result.Nonce -eq $newLabel), $result.StartScreen, $result.Thrown)) `
        (J @(1, "NA:entered/done/$CLOSE_REASON/ready", 1, 1, 'True', 'True', 'inside', ''))

    # R4-O10 · R4-O15 - 미결 마감(own 문구 S16) · 닫기 0 · 기록 0
    foreach ($case in @(
            @{ Name = 'R4-O10 F·U 교대 조정 Tpm 초'; Cycle = @('U', 'U', 'U', 'F') },
            @{ Name = 'R4-O15 I·F 교대(매 회전 - 던전 안 2연속 없음 · 각 F 구간 < W) 조정 Tpm 초 (수용)'; Cycle = @('I', 'F') })) {
        $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name $case.Name -Scenario @{ Cycle = $case.Cycle }) -FlowLayer 'selector'
        Save-ObservedStop -Key 'S16' -Result $result
        Assert-Case ($case.Name + " → 진단 '$DIAG_UNKNOWN' · S16(초 = Tpm) · exit 4 · 닫기 0 · 기록 0(파일 불변) · 입력 0 · 예외 0") `
            (J @((Get-DiagText $result 'selector'), (Get-StopLines $result), $result.ExitCode, $result.Unchanged, $result.Inputs, $result.Thrown)) `
            (J @($DIAG_UNKNOWN, ($S16_OWN_UNKNOWN_FORMAT -f $Tpm), '4', 'True', 0, ''))
    }

    # R4-O13 · ESC 메뉴(own - S12 경로, 제안 행) · R4-F7 - 오버레이 1회 정지(own 문구) · 닫기·클릭·기록 0 · 항목 launched 유지
    foreach ($case in @(
            @{ Name = 'R4-O13 own + 선택 화면 1회'; Timeline = @(New-Timeline -Pairs @(0, 'SEL')); Stop = $S10_OWN_SELECTION; Diag = $DIAG_SELECTION; Key = 'S10' },
            @{ Name = 'O13m(S12 경로) own + ESC 메뉴'; Timeline = @(New-Timeline -Pairs @(0, 'MENU')); Stop = $S12_OWN_MENU; Diag = $DIAG_MENU; Key = 'S12' },
            @{ Name = 'R4-F7 F@0 · F@W ∧ 같은 회전 선택 화면 (정지 회전 - 필드 표본 아님)'; Timeline = @(New-Timeline -Pairs @(0, 'F', $W, 'SELF')); Stop = $S10_OWN_SELECTION; Diag = $DIAG_SELECTION; Key = 'S10' })) {
        $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name $case.Name -Scenario @{ Timeline = $case.Timeline }) -FlowLayer 'selector'
        Save-ObservedStop -Key $case.Key -Result $result
        Assert-Case ($case.Name + ' → exit 4 · 정지 문구(own) · 진단 · 필드 확정 줄 0 · 닫기 0(NA launched · 파일 불변) · 복귀 루프 0 · 입력 0 · 예외 0') `
            (J @($result.ExitCode, (Get-StopLines $result), (Get-DiagText $result 'selector'), (Get-SettleLineInfo -Result $result).Lines, $result.Unchanged, (Get-ReturnText $result), $result.Inputs, $result.Thrown)) `
            (J @('4', $case.Stop, $case.Diag, 0, 'True', '', 0, ''))
    }

    # R4-O14 - '다시 하기' 직후 로딩에서 시작한 모형(U@0~40 · I · I) → 옛 index 2 로 이어받기(수용 - 화면으로 새 판과 가를 수 없음, Q-R4-8 ②)
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O14' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'U', 40.0, 'I')) }) -FlowLayer 'selector'
    Assert-Case 'R4-O14 U@0~40 · I · I (수용) → 결론 inside · 이벤트 정리 1(30초) · 닫기 0 · 열쇠 NA · 키 시작값 2/32,66(옛 index) · 예외 0' `
        (J @($result.StartScreen, @(Get-OverlayTimes -Result $result).Count, $result.Unchanged, $result.Nonce, $result.AfterEntry, $result.Thrown)) (J @('inside', 1, 'True', 'NA', '2/32,66', ''))

    # O17 - own(index 2) + 상세 화면 → S14 · (selection-overlay) · 닫기·키 0 · 항목 launched → (GUI 틱 재전달은 ⑯) 같은 nonce 다음 기동 I · I → 이어받기
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'O17' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'DET')) }) -FlowLayer 'selector'
    Save-ObservedStop -Key 'S14' -Result $result
    Assert-Case "O17 own + 상세 화면 → exit 4 · S14 · 진단 '$DIAG_DETAIL' · 닫기 0(NA launched · 파일 불변) · 입력 0 · 예외 0" `
        (J @($result.ExitCode, (Get-StopLines $result), (Get-DiagText $result 'selector'), $result.Unchanged, $result.Inputs, $result.Thrown)) (J @('4', $S14_OWN_DETAIL, $DIAG_DETAIL, 'True', 0, ''))
    $chainRow = New-OwnFlowRow -Name 'O17 다음 기동' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')) } -Extra @{ KeepFolder = $true }
    $result = Invoke-FlowRow -FlowRow $chainRow -FlowLayer 'selector'
    Assert-Case 'O17 다음 기동(같은 nonce - 재전달) 던전 안 I · I → Role own · 결론 inside · 열쇠 NA · 키 시작값 2/32,66 · 닫기 0 · 예외 0' `
        (J @($result.Role, $result.StartScreen, $result.Nonce, $result.AfterEntry, $result.Unchanged, $result.Thrown)) (J @('own', 'inside', 'NA', '2/32,66', 'True', ''))

    # O17′ - 상세 2회 연속(정지 2회 · 기록 0) → 필드 확정 → 닫기 1(해제 경로)
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'O17′ 1' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'DET')) }) -FlowLayer 'selector'
    $firstStop = $result.ExitCode
    $secondRow = New-OwnFlowRow -Name 'O17′ 2' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'DET')) } -Extra @{ KeepFolder = $true }
    $result = Invoke-FlowRow -FlowRow $secondRow -FlowLayer 'selector'
    $secondStop = $result.ExitCode
    $secondJournal = Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')
    $thirdRow = New-OwnFlowRow -Name 'O17′ 3' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F')) } -Extra @{ KeepFolder = $true }
    $result = Invoke-FlowRow -FlowRow $thirdRow -FlowLayer 'selector'
    Assert-Case 'O17′ own + 상세 2회 연속 → 정지 2회(exit 4 · NA launched) → 필드 시작 → 필드 확정 → 닫기 1(NA done · field) · 결론 field · 예외 0' `
        (J @($firstStop, $secondStop, $secondJournal, (Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), $result.StartScreen, $result.Thrown)) `
        (J @('4', '4', 'NA:entered/launched//', "NA:entered/done/$CLOSE_REASON/field", 'field', ''))
}

function Test-RowLoopSkeleton {
    # [보강 2.5] 회전 골격(명세 ② 2.5 표 · 5절 A-2 R-1)과 2.0-2 의 규칙 4·15 문장 중 행이 없던 자리 (next · 층 ① - 실제 Consume-Handoff → 실제 선분기).
    #   단계 2.4~2.6 변이 검증(2026-10-13)에서 살아남은 변이를 잡습니다 - 각 행 주석의 '변이' 가 그 행이 FAIL 로 드러내는 것
    $Tpm20 = 20
    $insideTimeline = @(New-Timeline -Pairs @(0, 'I'))
    $unknownTimeline = @(New-Timeline -Pairs @(0, 'U'))

    # R4-N15s - 스윕 참 회전은 던전 안 연속을 0 으로(명세 2.5 '양보·스윕 참 회전 = 0' · Q-R4-16 - N15 의 스윕 짝). 변이: 스윕 참 회전의 연속 비움 제거(2표본에 결론)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N15s' -Scenario @{ Timeline = $insideTimeline; Sweep = @(New-Windows -Pairs @(0.5, 1.0)) }) -FlowLayer 'selector'
    Assert-Case 'R4-N15s I@0 · 스윕 참 회전 · I · I → 결론 inside · 결론까지 유효 I 표본 3(스윕 참 회전 뒤 1 부터) · 스윕 참 회전 1 이상 · 예외 0' `
        (J @($result.StartScreen, @(Get-ValidTurns -Result $result -Key 'I').Count, (@($result.SweepTrueTurns).Count -ge 1), $result.Thrown)) (J @('inside', 3, 'True', ''))

    # R4-N14r - 판독 도중 실패 회전(일련번호 변화 · 이미 복구 = 복구 회전)은 던전 안 연속을 유지(명세 2.5 '동결·판독 도중 실패 회전 = 연속 유지' - N14 의 짝).
    #   변이: 복구 회전이 연속을 비움(3표본에 결론)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N14r' -Scenario @{ Timeline = $insideTimeline; SerialFail = @(New-Windows -Pairs @(0.5, 1.0)) }) -FlowLayer 'selector'
    Assert-Case 'R4-N14r I@0 · 판독 도중 실패 회전 · I → 결론 inside · 결론까지 유효 I 표본 2(복구 회전은 연속 유지) · 실패 판독이 든 회전 1 · 예외 0' `
        (J @($result.StartScreen, @(Get-ValidTurns -Result $result -Key 'I').Count, @(@($result.Turns) | Where-Object { -not $_.Valid }).Count, $result.Thrown)) (J @('inside', 2, 1, ''))

    # R4-N15i - 회전 서두 게이트가 못 보는 간접 양보(스윕의 커서 대피가 조작을 만나 기다림 · 스윕 거짓)는 그 회전의 던전 안 연속을 0 으로(골격 ⑥).
    #   변이: 골격 ⑥ 제거(2표본에 결론)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N15i' -Scenario @{ Timeline = $insideTimeline; SweepYield = @(New-Windows -Pairs @(0.5, 1.0)) }) -FlowLayer 'selector'
    Assert-Case "R4-N15i I@0 · 간접 양보 회전(스윕 거짓) · I · I → 결론 inside · 결론까지 유효 I 표본 3(간접 양보 회전의 표본부터 1) · 양보 누적 $SWEEP_STUB_MS ms · 게이트 양보 0 · 예외 0" `
        (J @($result.StartScreen, @(Get-ValidTurns -Result $result -Key 'I').Count, $result.YieldTotalMs, $result.YieldContexts, $result.Thrown)) (J @('inside', 3, $SWEEP_STUB_MS, '', ''))

    # R4-N16u - 스윕 클릭이 조작으로 생략된 참(user-active · 위임 길 - 다음 회전 게이트가 양보)은 굶김 예산을 쓰지 않고, 생략 회전·양보 회전에서는 마감을 확정하지
    #   않습니다(규칙 4 'user-active 생략은 예산·격상 문턱 미소모' · Resolve-AbyssMemberSweepTurn 의 'yield' - 조작 중 마감 확정 0). Tpm 20 + U 연속 + 생략 3회(@18.5~30).
    #   마감은 생략이 그친 뒤 첫 유효 회전에서 양보만큼 늦게 옵니다. 변이: 스윕 생략 사유를 넘기지 않음(생략 3회째가 굶김 회전 → 양보 전 마감) · 'yield' 를
    #   continue 집합에서 뺌(생략 회전이 그 자리에서 판독·마감)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N16u' -Scenario @{ Timeline = $unknownTimeline; SweepSkip = @(New-Windows -Pairs @(18.5, 30.0)) } -Extra @{ Tpm = $Tpm20 }) -FlowLayer 'selector'
    $yieldCount = @(@($result.YieldContexts -split ' / ') | Where-Object { $_ -eq $YIELD_CONTEXT }).Count
    Assert-True "R4-N16u Tpm $Tpm20 · U 연속 · 스윕 조작 생략 3회(위임 길) → 생략마다 다음 회전 양보(문맥 '$YIELD_CONTEXT' 3 · 누적 3×$SKIP_YIELD_MS ms) · 생략 구간(@18.5~30)에서 마감 확정 0 → 구간 뒤 첫 유효 회전에서 S15 · exit 4" `
        (($result.ExitCode -eq '4') -and ((Get-StopLines $result) -ceq ($S15_NEXT_UNKNOWN_FORMAT -f $Tpm20)) -and ($yieldCount -eq 3) -and ([Math]::Abs($result.YieldTotalMs - (3 * $SKIP_YIELD_MS)) -lt 1) -and
            ($result.EndT -ge (30 - $TIME_EPSILON)) -and ($result.EndT -lt 33) -and (@($result.SweepTrueTurns).Count -eq 3)) `
        ('끝 {0}초 · 양보 문맥 {1} · 양보 누적 {2}ms · 생략 회전 {3} · exit [{4}] · 정지 [{5}] · 예외 [{6}]' -f (Format-Seconds $result.EndT), $yieldCount, $result.YieldTotalMs, @($result.SweepTrueTurns).Count, $result.ExitCode, (Get-StopLines $result), $result.Thrown)

    # R4-N16s - 스윕 참이 한도($memberSweepStreakLimit)를 넘겨 이어지면 굶김 회전(판독·분류 없이 마감만)이 미결 마감을 확정합니다(골격 ④ - 스윕이 끝없이 참이어도
    #   루프가 끝남). Tpm 20 + U · 스윕 참 @5~200. 변이: 굶김이 영영 일어나지 않음(스윕이 그칠 때까지 마감 0) · 굶김 회전도 판독
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N16s' -Scenario @{ Timeline = $unknownTimeline; Sweep = @(New-Windows -Pairs @(5.0, 200.0)) } -Extra @{ Tpm = $Tpm20 }) -FlowLayer 'selector'
    $sweepTurnKeys = @($result.SweepTrueTurns)
    $readsInSweepTurns = @(@($result.ReadLog) | Where-Object { ($_.Phase -eq 'selector') -and ($sweepTurnKeys -contains [string]$_.Turn) }).Count
    $classifyInSweepTurns = @(@($result.ClassifyLog) | Where-Object { $sweepTurnKeys -contains [string]$_.Turn }).Count
    Assert-True "R4-N16s Tpm $Tpm20 · U · 스윕 참 연속(@5~200) → 굶김 회전이 조정 Tpm 에 마감 확정(S15 · exit 4 · 스윕이 그치기 전) · 스윕 참 회전 $memberSweepStreakLimit 이상 · 그 회전들의 판독 0 · 분류 호출 0" `
        (($result.ExitCode -eq '4') -and ((Get-StopLines $result) -ceq ($S15_NEXT_UNKNOWN_FORMAT -f $Tpm20)) -and ($result.EndT -ge ($Tpm20 - $TIME_EPSILON)) -and ($result.EndT -lt ($Tpm20 + 2)) -and
            ($sweepTurnKeys.Count -ge $memberSweepStreakLimit) -and ($readsInSweepTurns -eq 0) -and ($classifyInSweepTurns -eq 0)) `
        ('끝 {0}초 · 스윕 참 회전 {1} · 그 회전 판독 {2} · 분류 {3} · exit [{4}] · 정지 [{5}] · 예외 [{6}]' -f (Format-Seconds $result.EndT), $sweepTurnKeys.Count, $readsInSweepTurns, $classifyInSweepTurns, $result.ExitCode, (Get-StopLines $result), $result.Thrown)

    # R4-N6r - 교대 모양(판독할 때마다 캡처 실패가 시작되고 다음 회전 동결의 탐침은 복구)에서도 미결 마감이 옵니다: 탐침 복구 뒤 회전은 스윕·판독 없이 마감만
    #   보고 2초(골격 ③ - 탐침 뒤 곧바로 판독하면 '판독에서 실패 → 동결 탐침 복구' 만 되풀이되어 마감에 닿지 않음). Tpm 20 · U · 판독 실패 @3~120(탐침은 성공).
    #   마감은 캡처 실패 시간을 뺀 조정 Tpm. 변이: 탐침 복구 뒤 회전이 판독(판독 실패 구간이 끝날 때까지 마감 0)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N6r' -Scenario @{ Timeline = $unknownTimeline; ReadFail = @(New-Windows -Pairs @(3.0, 120.0)) } -Extra @{ Tpm = $Tpm20 }) -FlowLayer 'selector'
    $adjustedEnd = $result.EndT - ($result.FailTotalMs / 1000)
    Assert-True "R4-N6r Tpm $Tpm20 · U · 판독 실패 @3~120(탐침 성공 - 교대 모양) → 탐침 복구 뒤 회전이 조정 Tpm 에 마감 확정(S15 · exit 4 · 판독 실패 구간 안) · 탐침 5 이상" `
        (($result.ExitCode -eq '4') -and ((Get-StopLines $result) -ceq ($S15_NEXT_UNKNOWN_FORMAT -f $Tpm20)) -and ($result.EndT -lt 100) -and ($adjustedEnd -ge ($Tpm20 - $TIME_EPSILON)) -and
            ($adjustedEnd -lt ($Tpm20 + 3)) -and ($result.ProbeCalls -ge 5)) `
        ('끝 {0}초 · 조정 끝 {1}초 · 캡처 실패 {2}초 · 탐침 {3} · exit [{4}] · 정지 [{5}] · 예외 [{6}]' -f (Format-Seconds $result.EndT), (Format-Seconds $adjustedEnd), (Format-Seconds ($result.FailTotalMs / 1000)), $result.ProbeCalls, $result.ExitCode, (Get-StopLines $result), $result.Thrown)

    # R4-K1o - 판독 순서(골격 ⑤ '앞 분류가 음성일 때만 … 선택 화면 · 메뉴 · 상세'): 선택 화면·ESC 메뉴·상세는 앞 분류(팝업·패널·접힌 패널·S·던전 안·3버튼)가
    #   모두 음성인 회전에만 읽습니다. 던전 안 시작(I · I)은 세 판독 0 · 필드 모양 시작(F 연속 → 확정)은 선택 화면·메뉴 판독이 필드 회전마다(앞 분류 음성 =
    #   읽는 자리가 살아 있음 - 대조). 상세를 HUD 가 보일 때 읽지 않는 것은 구현의 판독 절약이라(분류는 상세 신호를 'HUD 없음' 일 때만 씀 - 결과 동등) 단언하지
    #   않습니다. 변이: 세 신호를 늘 판독
    $insideResult = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-K1o 던전 안' -Scenario @{ Timeline = $insideTimeline }) -FlowLayer 'selector'
    $fieldResult = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-K1o 필드' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F')) }) -FlowLayer 'selector'
    $insideReads = @(@($insideResult.ReadLog) | Where-Object { $_.Phase -eq 'selector' })
    $fieldReads = @(@($fieldResult.ReadLog) | Where-Object { $_.Phase -eq 'selector' })
    $insideText = '{0}/{1}/{2}' -f @($insideReads | Where-Object { $_.Name -eq 'Test-AbyssSelectionScreen' }).Count, @($insideReads | Where-Object { $_.Name -eq 'Test-AbyssMenu' }).Count,
        @($insideReads | Where-Object { $_.Name -eq 'Test-AbyssKnownDetailScreen' }).Count
    $fieldText = '{0}/{1}' -f @($fieldReads | Where-Object { $_.Name -eq 'Test-AbyssSelectionScreen' }).Count, @($fieldReads | Where-Object { $_.Name -eq 'Test-AbyssMenu' }).Count
    $fieldTurnCount = @(Get-ValidTurns -Result $fieldResult -Key 'F').Count
    Assert-Case 'R4-K1o 판독 순서 - 던전 안 시작: 선택 화면/메뉴/상세 판독 0/0/0 · 필드 모양 시작(대조): 선택 화면/메뉴 판독 = 필드 회전 수 · 두 결론 inside/field' `
        (J @($insideText, $fieldText, $insideResult.StartScreen, $fieldResult.StartScreen)) (J @('0/0/0', ('{0}/{0}' -f $fieldTurnCount), 'inside', 'field'))
}

# ===== 단계 2.6 - 본류 시작 구간 행 (층 ② - 결론 대입 · run:18244 가드 · run:18382 인자 · run:18409 메뉴 갈래 · own 시작 분기 cleared) =====
function Test-RowNextMain {
    # next 의 본류 행 - 선분기 결론 뒤 본류는 시작 판독을 다시 하지 않습니다((본류) 판독 = 선분기 반환 뒤 증가분 · 메뉴 run:18409 만 모든 Role - R4 4.3)
    $W = [double]$memberFieldSettleSeconds

    # R4-N1
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N1' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')) }) -FlowLayer 'main'
    $measureLines = @(Get-PatternLines -Result $result -Pattern $S1_PATTERN)
    $measureProblem = "시작 직후 계측 줄 $($measureLines.Count)개"
    if ($measureLines.Count -eq 1) { $measureProblem = Test-MeasureLine -Line $measureLines[0] -Pattern $S1_PATTERN -ExpectU 0 -ExpectF 0 -ExpectSeconds $null -ExpectBreaks 0 }
    Assert-Case 'R4-N1 I@0 · I → 결론 inside · (본류) 판독 18222·18235·18242~18283·18380·18468~18469 0(메뉴 1) · $startInsideDetected 참 · 필드 분기·복귀 루프 0 · 열쇠 = handoff 항목 NB · 시작 직후 계측 줄 1(필드 모양 0표본) · exit 0건 · 기록 0 · 예외 0' `
        (J @($result.StartScreen, $result.PostReads, $result.StartInside, (Get-ReturnText $result), $result.Nonce, $measureProblem, $result.ExitCode, $result.Unchanged, $result.Thrown)) `
        (J @('inside', (Get-PostReadsExpected -Menu 1), 'True', '', 'NB', '', '', 'True', ''))

    # R4-N1e [보강 2.6 검증] - N1 + 본류 run:18221 의 이벤트 정리가 참(무언가를 닫음): 정리 자체는 모든 Role 이 거치지만 run:18222 재판독은 Role none 만이라
    #   (본류) 판독 Test-ExitButton 0 · 결론 그대로. 이벤트 정리 모의가 늘 거짓이던 동안은 그 갈래가 한 번도 돌지 않아 N1 의 'run:18222 0' 이 늘 참이었습니다
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N1e' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')); MainOverlay = @(New-Timeline -Pairs @(0, 'I')) }) -FlowLayer 'main'
    Assert-Case 'R4-N1e N1 + (본류) run:18221 이벤트 정리 참 → 본류 정리 1 · 정리 참 1 · 결론 inside · (본류) 판독 run:18222 포함 0(메뉴 1) · $startInsideDetected 참 · 열쇠 NB · exit 0건 · 기록 0 · 예외 0' `
        (J @(@(Get-OverlayTimes -Result $result -Phase 'main').Count, @(@($result.Events) | Where-Object { $_ -ceq 'main|main-overlay-closed' }).Count, $result.StartScreen, $result.PostReads,
            $result.StartInside, $result.Nonce, $result.ExitCode, $result.Unchanged, $result.Thrown)) `
        (J @(1, 1, 'inside', (Get-PostReadsExpected -Menu 1), 'True', 'NB', '', 'True', ''))

    # R4-N3 (+ 필드 확정 줄의 숫자 - 끊김 없는 행이라 첫 F 표본부터 확정 회전까지)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N3' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F')) }) -FlowLayer 'main'
    $settle = Get-SettleLineInfo -Result $result
    $fieldTurns = @(Get-ValidTurns -Result $result -Key 'F')
    $expectedSpan = $(if ($fieldTurns.Count -ge 1) { [double]$fieldTurns[$fieldTurns.Count - 1].T - [double]$fieldTurns[0].T } else { -1 })
    Assert-Case 'R4-N3 F 연속 Δ ≥ W → 결론 field · 기록 0 · 필드 확정 줄 1(W · 표본 수·폭 = 하니스 기록) · (본류) 판독 0(메뉴 1) · 필드 분기 시작 줄 1 · Return-ToAbyssSelection -SafeStopExitCode 10 1(닫기 사유 없음) · exit 10 · 예외 0' `
        (J @($result.StartScreen, $result.Unchanged, $settle.Lines, $settle.W, ($settle.Count -eq $fieldTurns.Count), ([Math]::Abs($settle.Span - $expectedSpan) -lt 0.051), $result.PostReads,
            @(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_FIELD_FRAGMENT))).Count, (Get-ReturnText $result), $result.ExitCode, $result.Thrown)) `
        (J @('field', 'True', 1, $W, 'True', 'True', (Get-PostReadsExpected -Menu 1), 1, '10/', '10', ''))

    # R4-N11 - 결론 대입 핵심 행(V6-P3-4 확장): N1 뒤 본류 run:18468 자리가 필드 모양이어도 필드 분기 0
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N11' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')); Main = @{ Hud = $true; Quest = $false } }) -FlowLayer 'main'
    Assert-Case 'R4-N11 N1 뒤 (본류) run:18468 자리 스텁이 필드 모양 → 필드 분기 0 · Return-ToAbyssSelection 0 · (본류) 판독 0(메뉴 1) · $startInsideDetected 참 · exit 0건 · 예외 0' `
        (J @(@(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_FIELD_FRAGMENT))).Count, (Get-ReturnText $result), $result.PostReads, $result.StartInside, $result.ExitCode, $result.Thrown)) `
        (J @(0, '', (Get-PostReadsExpected -Menu 1), 'True', '', ''))

    # R4-N12 (워커 쪽) - FINISH_ONLY=1 + N3 → exit 10 (GUI 안전망 정지는 ⑯ (GUI 틱) 몫 - R1 H31)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N12' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F')) } -Extra @{ FinishOnly = '1' }) -FlowLayer 'main'
    Assert-Case 'R4-N12 FINISH_ONLY=1 + next 필드 확정 → Role next(FINISH_ONLY 는 역할 판정 밖) · 결론 field · 정리 전용 거짓 · Return 10/ · exit 10 · 예외 0' `
        (J @($result.Role, $result.StartScreen, $result.CustomCleanupOnly, (Get-ReturnText $result), $result.ExitCode, $result.Thrown)) (J @('next', 'field', 'False', '10/', '10', ''))

    # R4-N13 - N1 뒤 본류 run:18244 자리가 ready 여도 시작 패널 판정·입장 대기 0 (Role none 전용 가드)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N13' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')); Main = @{ Panel = 'ready'; Hud = $false; Quest = $false } }) -FlowLayer 'main'
    Assert-Case 'R4-N13 N1 뒤 (본류) run:18244 자리 스텁이 ready → 시작 패널 판정 0 · 입장 대기 0(시작 줄 0) · (본류) 판독 0(메뉴 1) · $startInsideDetected 참 · exit 0건 · 예외 0' `
        (J @($result.PostReads, @(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_PANEL_WAIT_FRAGMENT))).Count, $result.StartInside, $result.ExitCode, $result.Thrown)) `
        (J @((Get-PostReadsExpected -Menu 1), 0, 'True', '', ''))

    # R4-N17 - N1 뒤 본류 메뉴 참 → (menu-overlay) 정지 (결론 inside - 결론 뒤 틈에 열린 메뉴)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N17' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'I')); Main = @{ Menu = $true } }) -FlowLayer 'main'
    Assert-Case "R4-N17 N1 뒤 (본류) run:18409 메뉴 참 → exit 4 · S11(next) · 진단(본류 단계) '$DIAG_MENU' · Return-ToAbyssSelection 0 · 입력 0 · 예외 0" `
        (J @($result.ExitCode, (Get-StopLines $result), (Get-DiagText $result 'main'), (Get-ReturnText $result), $result.Inputs, $result.Thrown)) (J @('4', $S11_NEXT_MENU, $DIAG_MENU, '', 0, ''))

    # R4-N18 - N3 뒤 본류 메뉴 참 → Role none 과 같은 복귀(결론 field - W 로 던전 밖을 쥠)
    $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name 'R4-N18' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F')); Main = @{ Menu = $true } }) -FlowLayer 'main'
    Assert-Case 'R4-N18 N3 뒤 (본류) run:18409 메뉴 참 → 메뉴 복귀 시작 줄 1 · Return-ToAbyssSelection -SafeStopExitCode 10 1 · exit 10 · (menu-overlay) 0 · 예외 0' `
        (J @(@(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_MENU_RETURN_FRAGMENT))).Count, (Get-ReturnText $result), $result.ExitCode, ((Get-StopLines $result).Contains('(menu-overlay)')), $result.Thrown)) `
        (J @(1, '10/', '10', 'False', ''))
}

function Test-RowOwnMain {
    # own 의 본류 행 (설계 v11 R4 5.3 · 4.5 인자 표 · 명세 2.6) - 결론 inside 는 run:18527 참 갈래로(열쇠 = 받은 own 항목, 기존 index 부터 - ownFreshEntry 면 새
    #   항목 index 0) / 결론 field 는 필드 분기 exit 10 / reward3·prompt 는 마커 + cleared(own 항목 applied·done - J4) + exit 0
    $W = [double]$memberFieldSettleSeconds
    $Tpm = [int]$capturedTimeoutPartyMatch
    $insideTimeline = @(New-Timeline -Pairs @(0, 'I'))

    # R4-O1
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O1' -Scenario @{ Timeline = $insideTimeline }) -FlowLayer 'main'
    Assert-Case 'R4-O1 own + I · I(수동) → 결론 inside · 닫기 0(파일 불변) · Test-CustomCleanupOnly 인자 둘 다 거짓 · 정리 전용 거짓 · 열쇠 NA · 키 시작값 2/32,66 · (본류) 판독 0(메뉴 1) · $startInsideDetected 참 · exit 0건 · 예외 0' `
        (J @($result.StartScreen, $result.Unchanged, $result.CleanupCalls, $result.CustomCleanupOnly, $result.Nonce, $result.AfterEntry, $result.PostReads, $result.StartInside, $result.ExitCode, $result.Thrown)) `
        (J @('inside', 'True', 'Inside=False Result=False', 'False', 'NA', '2/32,66', (Get-PostReadsExpected -Menu 1), 'True', '', ''))

    # R4-O1e [보강 2.6 검증] - O1 + 본류 run:18221 의 이벤트 정리가 참: own(② 빌드에서 실제로 나는 역할)도 run:18222 재판독 0 · 결론·인자 그대로(R4-N1e 와 같은 이유)
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O1e' -Scenario @{ Timeline = $insideTimeline; MainOverlay = @(New-Timeline -Pairs @(0, 'I')) }) -FlowLayer 'main'
    Assert-Case 'R4-O1e O1 + (본류) run:18221 이벤트 정리 참 → 본류 정리 1 · 정리 참 1 · 결론 inside · (본류) 판독 run:18222 포함 0(메뉴 1) · Test-CustomCleanupOnly 인자 둘 다 거짓 · 열쇠 NA · 키 시작값 2/32,66 · $startInsideDetected 참 · exit 0건 · 예외 0' `
        (J @(@(Get-OverlayTimes -Result $result -Phase 'main').Count, @(@($result.Events) | Where-Object { $_ -ceq 'main|main-overlay-closed' }).Count, $result.StartScreen, $result.PostReads,
            $result.CleanupCalls, $result.Nonce, $result.AfterEntry, $result.StartInside, $result.ExitCode, $result.Thrown)) `
        (J @(1, 1, 'inside', (Get-PostReadsExpected -Menu 1), 'Inside=False Result=False', 'NA', '2/32,66', 'True', '', ''))

    # R4-O3 - 필드 확정 → 닫기 → CleanupOnly 비움 → 필드 확정 줄 → 결론 field (줄 순서 J7) → 본류 필드 분기 exit 10
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O3' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F')) }) -FlowLayer 'main'
    $closeIndex = Get-LineIndex -Result $result -Line ($S4_CLOSE_FORMAT -f 'field')
    $settleIndex = Get-PatternIndex -Result $result -Pattern $S3_PATTERN
    Assert-Case "R4-O3 F 연속 Δ ≥ W → 닫기 1(NA done · $CLOSE_REASON · field) · own 닫기 성공 줄 1 → 필드 확정 줄(순서 J7) · CleanupOnly 거짓 · 결론 field · (본류) 판독 0(메뉴 1) · Return 10/ · exit 10 · 예외 0" `
        (J @((Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), (Get-LineCount -Result $result -Line ($S4_CLOSE_FORMAT -f 'field')), (($closeIndex -ge 0) -and ($settleIndex -gt $closeIndex)),
            $result.CleanupOnly, $result.StartScreen, $result.PostReads, (Get-ReturnText $result), $result.ExitCode, $result.Thrown)) `
        (J @("NA:entered/done/$CLOSE_REASON/field", 1, 'True', 'False', 'field', (Get-PostReadsExpected -Menu 1), '10/', '10', ''))

    # R4-O4 - ready → 닫기(ready) → B2 단계 entered → B2 입장 계측 → 새 항목(index 0 · 새 nonce = 열쇠 · cleanupOnly 거짓) · FreshEntry → 결론 inside →
    #   (본류) 시작 패널 판정 0 · 정리 전용 거짓. 줄 순서: 닫기 성공 → B2 시작 → B2 입장 계측 → 자기 항목 저장 → ownFreshEntry (명세 2.5 결론 표)
    $o4Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'ready', 2.5, 'U', 4.5, 'I')) }
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O4' -Scenario $o4Scenario) -FlowLayer 'main'
    $validTurns = @(Get-ValidTurns -Result $result)
    $lastPanel = -1
    for ($turnIndex = 0; $turnIndex -lt $validTurns.Count; $turnIndex++) { if ($validTurns[$turnIndex].Key -eq 'ready') { $lastPanel = $turnIndex } }
    $b2Unknown = 0
    for ($turnIndex = ($lastPanel + 1); $turnIndex -lt ($validTurns.Count - 2); $turnIndex++) { if ($validTurns[$turnIndex].Key -eq 'U') { $b2Unknown++ } }
    $entryLines = @(Get-PatternLines -Result $result -Pattern $S2_PATTERN)
    $entryProblem = "입장 계측 줄 $($entryLines.Count)개"
    if ($entryLines.Count -eq 1) { $entryProblem = Test-MeasureLine -Line $entryLines[0] -Pattern $S2_PATTERN -ExpectU $b2Unknown -ExpectF 0 -ExpectSeconds $null -ExpectBreaks 0 }
    $orderIndexes = @((Get-LineIndex -Result $result -Line ($S4_CLOSE_FORMAT -f 'ready')), (Get-LineIndex -Result $result -Line ($S7_B2_START_FORMAT -f $B2_LABELS.ready, $Tpm)),
        (Get-PatternIndex -Result $result -Pattern $S2_PATTERN), (Get-LineIndex -Result $result -Line $ENTRY_SAVED_LINE), (Get-LineIndex -Result $result -Line $S6_FRESH_ENTRY))
    $ordered = ($orderIndexes[0] -ge 0) -and (@(0..($orderIndexes.Count - 2) | Where-Object { $orderIndexes[$_] -ge $orderIndexes[$_ + 1] }).Count -eq 0)
    $newEntry = Find-JournalEntry $result.Journal 'NEW1'
    $newEntryText = '(새 항목 없음)'
    if ($null -ne $newEntry) {
        $newEntryText = '{0}/{1}/ix{2}/{3}/total{4}/cleanupOnly {5}/{6}/gen{7}/owner{8}/{9}' -f $newEntry.Stage, $newEntry.LaunchState, $newEntry.Index, $newEntry.Keys, $newEntry.Total,
            $newEntry.CleanupOnly, $newEntry.Section, $newEntry.Generation, $newEntry.OwnerIndex, $newEntry.RunId
    }
    Assert-Case "R4-O4 ready → B2 → 입장 2연속 → 닫기(NA done · ready) · 줄 순서(닫기 성공 → B2 시작 → B2 입장 계측 → 자기 항목 저장 → ownFreshEntry) · B2 입장 계측 숫자(로딩 = B2 안 U 표본) · 새 항목 1(entered · launched · index 0 · keys 32,66 · total 2 · cleanupOnly 거짓 · 커스텀 섹션 · 세대 $CH_GENERATION · owner index 0 · 실행 id)" `
        (J @((Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), $ordered, $entryProblem, (Get-NewEntryLabels $result.Journal), $newEntryText)) `
        (J @("NA:entered/done/$CLOSE_REASON/ready", 'True', '', 'NEW1', ('entered/launched/ix0/32,66/total2/cleanupOnly False/{0}/gen{1}/owner0/{2}' -f $ABYSS_SECTION, $CH_GENERATION, $CH_RUN_ID)))
    Assert-Case 'R4-O4 (계속) 열쇠 = 새 항목 NEW1 · FreshEntry 참 · 키 시작값 0/32,66 · 결론 inside · (본류) 시작 패널 판정 0(판독 0 · 메뉴 1) · Test-CustomCleanupOnly 인자 둘 다 거짓 · 정리 전용 거짓 · $startInsideDetected 참 · exit 0건 · 예외 0' `
        (J @($result.Nonce, $result.FreshEntry, $result.AfterEntry, $result.StartScreen, $result.PostReads, $result.CleanupCalls, $result.CustomCleanupOnly, $result.StartInside, $result.ExitCode, $result.Thrown)) `
        (J @('NEW1', 'True', '0/32,66', 'inside', (Get-PostReadsExpected -Menu 1), 'Inside=False Result=False', 'False', 'True', '', ''))

    # R4-O4″ - O4 의 판에서 키 뒤 즉시 중지(종료 처리 없음 - 키 둘을 보낸 기록 = 실제 Set-AbyssAfterEntryIndex 두 번) → 그 던전 안 수동 시작 → Role own(새 항목) ·
    #   CleanupOnly 거짓 · 정리 전용 거짓 · index 이어받음 (R4-M8 - 새 항목 cleanupOnly 참이면 정리 전용 참)
    $o4NewNonce = $(if ($null -ne $newEntry) { [string]$newEntry.Nonce } else { '' })
    $indexTags = @()
    if ($o4NewNonce) {
        foreach ($sentIndex in @(0, 1)) { $indexTags += [string](Set-AbyssAfterEntryIndex -Nonce $o4NewNonce -Index $sentIndex -Keys $CH_KEYS -Total $CH_KEYS.Count) }
    }
    $chainRow = New-OwnFlowRow -Name 'R4-O4″' -Scenario @{ Timeline = $insideTimeline } -Extra @{ KeepFolder = $true; Nonce = $o4NewNonce }
    $result = Invoke-FlowRow -FlowRow $chainRow -FlowLayer 'main'
    Assert-Case 'R4-O4″ O4 새 항목의 키 둘 기록(changed 2) 뒤 즉시 중지 → 같은 던전 안 수동 시작 → Role own · 열쇠 NEW1 · CleanupOnly 거짓 · 정리 전용 거짓 · 키 시작값 2/32,66 · $startInsideDetected 참 · 예외 0' `
        (J @(($indexTags -join ','), $result.Role, $result.Nonce, $result.CleanupOnly, $result.CustomCleanupOnly, $result.AfterEntry, $result.StartInside, $result.Thrown)) `
        (J @('changed,changed', 'own', 'NEW1', 'False', 'False', '2/32,66', 'True', ''))

    # R4-O5 - P2-3 핵심 행: O1 뒤 본류 run:18244 자리가 ready 여도 시작 패널 판정·입장 대기 0 · 키 index 2 그대로
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O5' -Scenario @{ Timeline = $insideTimeline; Main = @{ Panel = 'ready'; Hud = $false; Quest = $false } }) -FlowLayer 'main'
    Assert-Case 'R4-O5 O1 뒤 (본류) run:18244 자리 스텁이 ready → 시작 패널 판정 0 · 입장 대기 0(시작 줄 0) · (본류) 판독 0(메뉴 1) · 키 시작값 2/32,66 그대로 · $startInsideDetected 참 · exit 0건 · 예외 0' `
        (J @($result.PostReads, @(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_PANEL_WAIT_FRAGMENT))).Count, $result.AfterEntry, $result.StartInside, $result.ExitCode, $result.Thrown)) `
        (J @((Get-PostReadsExpected -Menu 1), 0, '2/32,66', 'True', '', ''))

    # R4-O7 - 정리 전용 표지 항목 + I · I(수동) → 정리 전용 참(R2 C4 - 인자 = 결론 대입값) · index 2 이어받음
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O7' -Scenario @{ Timeline = $insideTimeline } -CleanupOnly $true) -FlowLayer 'main'
    Assert-Case 'R4-O7 표지 항목(cleanupOnly 참) + I · I(수동) → CleanupOnly 참 그대로(닫기 시도 0) · Test-CustomCleanupOnly -InsideAlready 참(결론 대입값) · 정리 전용 참 · 열쇠 NA · 키 시작값 2/32,66 · $startInsideDetected 참 · 예외 0' `
        (J @($result.CleanupOnly, $result.CleanupCalls, $result.CustomCleanupOnly, $result.Nonce, $result.AfterEntry, $result.StartInside, $result.Thrown)) `
        (J @('True', 'Inside=True Result=False', 'True', 'NA', '2/32,66', 'True', ''))

    # R4-O7′ · R4-O7″ - 표지 항목 + ready → 닫기 시도 뒤 CleanupOnly 비움(성공·실패 무관) → B2 → 새 항목(cleanupOnly 거짓) → 정리 전용 거짓
    foreach ($variant in @(
            @{ Name = 'R4-O7′ 표지 항목 + ready'; LockPlan = @(); Na = "NA:entered/done/$CLOSE_REASON/ready"; Warn = 0 },
            @{ Name = 'R4-O7″ O7′ + 닫기 저장 1회 locked'; LockPlan = @(@{ Phase = 'selector'; Ordinal = 1; Mode = 'once' }); Na = 'NA:entered/done//'; Warn = 1 })) {
        $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'ready', 2.5, 'I')); LockPlan = $variant.LockPlan }
        $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name $variant.Name -Scenario $scenario -CleanupOnly $true) -FlowLayer 'main'
        $newEntry = Find-JournalEntry $result.Journal 'NEW1'
        Assert-Case ($variant.Name + ' → 닫기 실패 [경고] 수 · CleanupOnly 거짓 · NA 상태(실패 변형은 새 항목 생성 mutation 이 함께 닫음 - dev:881) · 새 항목 cleanupOnly 거짓 · 열린 항목 = 새 항목만 · FreshEntry 참 · 인자 둘 다 거짓 · 정리 전용 거짓 · 예외 0') `
            (J @((Get-LineCount -Result $result -Line ($S5_CLOSE_FAIL_FORMAT -f '파일 사용 중')), $result.CleanupOnly, (Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')),
                $(if ($null -ne $newEntry) { $newEntry.CleanupOnly } else { '(새 항목 없음)' }), (Get-OpenEntryLabels $result.Journal), $result.FreshEntry, $result.CleanupCalls, $result.CustomCleanupOnly, $result.Thrown)) `
            (J @($variant.Warn, 'False', $variant.Na, 'False', 'NEW1', 'True', 'Inside=False Result=False', 'False', ''))
    }

    # R4-O8 - 표지 항목 + 필드 확정 → O3 과 같음(던전 밖 = v10 own 규격)
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O8' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F')) } -CleanupOnly $true) -FlowLayer 'main'
    Assert-Case "R4-O8 표지 항목 + F 확정 → 닫기 1(NA done · $CLOSE_REASON · field) · CleanupOnly 거짓 · 정리 전용 거짓 · 결론 field · Return 10/ · exit 10 · 예외 0" `
        (J @((Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), $result.CleanupOnly, $result.CustomCleanupOnly, $result.StartScreen, (Get-ReturnText $result), $result.ExitCode, $result.Thrown)) `
        (J @("NA:entered/done/$CLOSE_REASON/field", 'False', 'False', 'field', '10/', '10', ''))

    # R4-O9 - 3버튼(수동·RESTART 같음) · S → 본류 보상·S 분기: 마커 → cleared(own 항목 applied·done - J4) → 헬퍼 → exit 0 (P16 · Q-R4-17 (가) '마커 → 기록 → 헬퍼')
    foreach ($variant in @(
            @{ Name = 'R4-O9 own + 3버튼(수동)'; Timeline = @(New-Timeline -Pairs @(0, 'R3')); Extra = @{}; Screen = 'reward3'; First = 'marker' },
            @{ Name = 'R4-O9 own + 3버튼(RESTART)'; Timeline = @(New-Timeline -Pairs @(0, 'R3')); Extra = @{ Restart = $true }; Screen = 'reward3'; First = 'marker' },
            @{ Name = 'R4-O9 own + S(수동)'; Timeline = @(New-Timeline -Pairs @(0, 'S')); Extra = @{}; Screen = 'prompt'; First = 'clickuntil' })) {
        $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name $variant.Name -Scenario @{ Timeline = $variant.Timeline } -Extra $variant.Extra) -FlowLayer 'main'
        $orderNames = @($variant.First, 'marker', 'cleared', 'exitclick', 'return:')
        if ($variant.First -eq 'marker') { $orderNames = @('marker', 'cleared', 'exitclick', 'return:') }
        $orderIndexes = @($orderNames | ForEach-Object { Get-EventPosition -Result $result -Name $_ })
        $ordered = ($orderIndexes[0] -ge 0) -and (@(0..($orderIndexes.Count - 2) | Where-Object { $orderIndexes[$_] -ge $orderIndexes[$_ + 1] }).Count -eq 0)
        $clearedEntries = @(@($result.Journal.Entries) | Where-Object { $_.Stage -eq 'cleared' })
        Assert-Case ($variant.Name + ' → 결론 ' + $variant.Screen + ' · 마커 1 · cleared 1(decision exit) · 순서 마커 → 기록 → 나가기 헬퍼 → 복귀 · NA done · applied 에 NA · Return 0/ · exit 0 · 정리 전용 거짓 · 예외 0') `
            (J @($result.StartScreen, $result.Markers, $result.ClearedCalls, @($clearedEntries | Where-Object { $_.Decision -eq 'exit' }).Count, $ordered,
                (Find-JournalEntry $result.Journal 'NA').LaunchState, (@($result.Journal.Applied) -contains 'NA'), (Get-ReturnText $result), $result.ExitCode, $result.CustomCleanupOnly, $result.Thrown)) `
            (J @($variant.Screen, 1, 1, 1, 'True', 'done', 'True', '0/', '0', 'False', ''))
    }

    # R4-O11 - W 를 넘는 던전 안 필드 모양 오독(수용 경로): 닫기 1 → 필드 분기 → (복귀 루프 스텁) 던전 안 2연속 + 20초 → 코드 4 → 다음 수동 시작(GUI 가 nonce 를
    #   이미 done 으로 봄 - nonce 없음) Role none → 던전 안 정리 전용 (그 판 B 합계 2 는 ⑳ OK6 몫)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'F', ($W + 1), 'I')); ReturnLoop = 'exit4' }
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O11' -Scenario $scenario) -FlowLayer 'main'
    $firstText = J @((Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')), $result.StartScreen, (Get-ReturnText $result), $result.ExitCode)
    $chainRow = New-OwnFlowRow -Name 'R4-O11 다음 기동' -Scenario @{ Timeline = $insideTimeline } -Extra @{ KeepFolder = $true; Nonce = '' }
    $result = Invoke-FlowRow -FlowRow $chainRow -FlowLayer 'main'
    Assert-Case "R4-O11 F (W+1)초 뒤 I · I (수용) → 닫기 1(NA done · field) · 결론 field · Return 10/ · (복귀 루프) exit 4 → 다음 수동 시작 Role none · 정리 전용 참 · `$startInsideDetected 참 · 예외 0" `
        (J @($firstText, $result.Role, $result.CustomCleanupOnly, $result.StartInside, $result.Thrown)) `
        (J @((J @("NA:entered/done/$CLOSE_REASON/field", 'field', '10/', '4')), 'none', 'True', 'True', ''))

    # R4-O12 - O3 + 닫기 잠금(워커 끝까지 쥠) → [경고] 1 · 결론 field · exit 10 (GUI 코드 10 첫 문장의 done 은 ⑯ 몫)
    $scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'F')); LockPlan = @(@{ Phase = 'selector'; Ordinal = 1; Mode = 'hold' }) }
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O12' -Scenario $scenario) -FlowLayer 'main'
    Assert-Case 'R4-O12 F 확정 + 닫기 잠금 → own 닫기 실패 [경고](파일 사용 중) 1 · CleanupOnly 거짓 · 필드 확정 줄 1 · NA launched 그대로 · 결론 field · Return 10/ · exit 10 · 예외 0' `
        (J @((Get-LineCount -Result $result -Line ($S5_CLOSE_FAIL_FORMAT -f '파일 사용 중')), $result.CleanupOnly, (Get-SettleLineInfo -Result $result).Lines, (Format-JournalEntry (Find-JournalEntry $result.Journal 'NA')),
            $result.StartScreen, (Get-ReturnText $result), $result.ExitCode, $result.Thrown)) `
        (J @(1, 'False', 1, 'NA:entered/launched//', 'field', '10/', '10', ''))

    # R4-O16 - O3 뒤 본류 메뉴 참 → Role none 과 같은 복귀 · (menu-overlay) 0 (닫힌 항목에 재전달 표지 0)
    $result = Invoke-FlowRow -FlowRow (New-OwnFlowRow -Name 'R4-O16' -Scenario @{ Timeline = @(New-Timeline -Pairs @(0, 'F')); Main = @{ Menu = $true } }) -FlowLayer 'main'
    Assert-Case 'R4-O16 O3 뒤 (본류) run:18409 메뉴 참 → 메뉴 복귀 시작 줄 1 · Return 10/ · exit 10 · (menu-overlay) 0 · NA done · 예외 0' `
        (J @(@(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_MENU_RETURN_FRAGMENT))).Count, (Get-ReturnText $result), $result.ExitCode, ((Get-StopLines $result).Contains('(menu-overlay)')),
            (Find-JournalEntry $result.Journal 'NA').LaunchState, $result.Thrown)) `
        (J @(1, '10/', '10', 'False', 'done', ''))
}

function Test-RowV18 {
    # V18 (설계 v10 ⑱ 의 나머지 - dev:991 · 명세 3.2 V18 표) - 시작 화면 × 기동 매트릭스의 본류 쪽 (층 ②)
    $insideTimeline = @(New-Timeline -Pairs @(0, 'I'))
    foreach ($screen in @(@{ Key = 'R3'; Label = '3버튼' }, @{ Key = 'S'; Label = 'S' })) {
        $timeline = @(New-Timeline -Pairs @(0, $screen.Key))
        # Role none × 3버튼·S - HEAD 그대로(정리 전용 exit 10 / 재시작 마커 + exit 0 / 비커스텀 exit 0) · cleared 0(P16 - 시작 분기 기록은 own 만)
        $cases = @(
            @{ Name = ('V18 Role none(커스텀 수동) × ' + $screen.Label); Row = @{ Name = 'V18 none 수동'; Custom = $true; Nonce = ''; Entries = @(); Scenario = @{ Timeline = $timeline } }; Expect = @('10', 0, 0, '10/cleanup-only', 'True') },
            @{ Name = ('V18 Role none(커스텀 RESTART) × ' + $screen.Label); Row = @{ Name = 'V18 none 재시작'; Custom = $true; Restart = $true; Nonce = ''; Entries = @(); Scenario = @{ Timeline = $timeline } }; Expect = @('0', 1, 0, '0/', 'False') },
            @{ Name = ('V18 Role none(비커스텀) × ' + $screen.Label); Row = @{ Name = 'V18 none 비커스텀'; Custom = $false; Nonce = ''; Entries = @(); Scenario = @{ Timeline = $timeline } }; Expect = @('0', 0, 0, '0/', 'False') })
        foreach ($case in $cases) {
            $result = Invoke-FlowRow -FlowRow $case.Row -FlowLayer 'main'
            Assert-Case ($case.Name + ' → exit · 마커 · cleared · 복귀 루프(코드/사유) · 정리 전용 (HEAD 그대로) · 선분기 0 · 예외 0') `
                (J @($result.ExitCode, $result.Markers, $result.ClearedCalls, (Get-ReturnText $result), $result.CustomCleanupOnly, $result.SelectorCalls, $result.Thrown)) `
                (J @($case.Expect + @(0, '')))
        }
        # next × 3버튼·S - 마커 0 · cleared 0 · 코드 4 · S17 + 꼬리 2변형(+ (release)) · '이전 보상 화면을 새 항목 완료로 기록' 0
        foreach ($custom in @($true, $false)) {
            $tail = $(if ($custom) { $S17_CUSTOM_TAIL } else { $S17_PLAIN_TAIL })
            $result = Invoke-FlowRow -FlowRow (New-NextFlowRow -Name ('V18 next × ' + $screen.Label) -Scenario @{ Timeline = $timeline } -Custom $custom) -FlowLayer 'main'
            Save-ObservedStop -Key $(if ($custom) { 'S17-custom' } else { 'S17-plain' }) -Result $result
            Assert-Case ('V18 next(' + $(if ($custom) { '커스텀' } else { '비커스텀' }) + ') × ' + $screen.Label + ' → exit 4 · S17 + 꼬리 + (release) · 마커 0 · cleared 0 · 기록 문장 0 · 기록 0(파일 불변) · 예외 0') `
                (J @($result.ExitCode, (Get-StopLines $result), $result.Markers, $result.ClearedCalls, @(Get-PatternLines -Result $result -Pattern ([regex]::Escape($V18_FORBIDDEN_FRAGMENT))).Count, $result.Unchanged, $result.Thrown)) `
                (J @('4', ($S17_BASE + $tail + $RELEASE_TAIL), 0, 0, 0, 'True', ''))
        }
    }
    # FINISH_ONLY=1 + stale nonce + 첫 판독 던전 안 → 정리 전용 거짓 · exit 10 0 (재판독 갈래는 5절 C2) / 대조: FINISH_ONLY 없으면 정리 전용 참(Role none 수동)
    foreach ($finishOnly in @('1', '')) {
        $staleRow = @{ Name = 'V18 FINISH_ONLY'; Custom = $true; Nonce = $NONCE_A; FinishOnly = $finishOnly; Entries = @((New-ChOwnEntry -OwnerIndex 1)); Scenario = @{ Timeline = $insideTimeline } }
        $result = Invoke-FlowRow -FlowRow $staleRow -FlowLayer 'main'
        $expectCleanup = $(if ($finishOnly) { 'False' } else { 'True' })
        Assert-Case ('V18 FINISH_ONLY=' + $(if ($finishOnly) { '1' } else { '(없음 - 대조)' }) + ' + stale nonce(owner 불일치) + 첫 판독 던전 안 → Role none · 정리 전용 ' + $expectCleanup + ' · exit 0건 · $startInsideDetected 참 · 예외 0') `
            (J @($result.Role, $result.CustomCleanupOnly, $result.ExitCode, $result.StartInside, $result.Thrown)) (J @('none', $expectCleanup, '', 'True', ''))
    }
    # [보강 2.6] Role none × ESC 메뉴 시작 → HEAD 그대로(run:18410~18417 - 선택 화면 복귀 → 준비 실행 exit 10 · (menu-overlay) 0). 메뉴 갈래 안쪽 if 의 '$roleNone -or'
    #   항을 실행으로 지킵니다(그 항을 지우면 Role none 의 메뉴 시작이 오버레이 정지 코드 4 - 정적 R4-P14 만 잡던 변이, 2026-10-13 변이 검증)
    $result = Invoke-FlowRow -FlowRow @{ Name = 'V18 none 메뉴'; Custom = $true; Nonce = ''; Entries = @(); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'MENU')) } } -FlowLayer 'main'
    Assert-Case 'V18 Role none(커스텀 수동) × ESC 메뉴 → 메뉴 복귀 시작 줄 1 · Return 10/ · exit 10 · (menu-overlay) 0 · 선분기 0 · 예외 0 (HEAD 그대로)' `
        (J @(@(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_MENU_RETURN_FRAGMENT))).Count, (Get-ReturnText $result), $result.ExitCode, ((Get-StopLines $result).Contains('(menu-overlay)')),
            $result.SelectorCalls, $result.Thrown)) `
        (J @(1, '10/', '10', 'False', 0, ''))
    # [보강 2.6 검증] Role none × 이벤트 정리가 오버레이를 닫은 뒤 3버튼 → HEAD 그대로 run:18222 재판독이 보상 화면을 잡아 보상 분기(커스텀 수동 = 정리 전용 exit 10).
    #   첫 시작 판독(run:18181 - 정리 전)은 오버레이에 가려 보상 화면을 못 봅니다(U). 재판독 가드를 뒤집거나 재판독을 지우면 보상 분기 0 · 시작 판독 1회(R4-N1e·O1e 의 짝)
    $result = Invoke-FlowRow -FlowRow @{ Name = 'V18 none 정리 뒤 3버튼'; Custom = $true; Nonce = ''; Entries = @(); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U')); MainOverlay = @(New-Timeline -Pairs @(0, 'R3')) } } -FlowLayer 'main'
    Assert-Case 'V18 Role none(커스텀 수동) × U → (본류) 이벤트 정리 참 → 3버튼 → 정리 참 1 · 본류 Test-ExitButton 2(run:18181 · run:18222 재판독) · 보상 분기 시작 줄 1 · exit 10 · 마커 0 · cleared 0 · Return 10/cleanup-only · 정리 전용 참 · 선분기 0 · 예외 0 (HEAD 그대로)' `
        (J @(@(@($result.Events) | Where-Object { $_ -ceq 'main|main-overlay-closed' }).Count, @(@($result.ReadLog) | Where-Object { ($_.Phase -eq 'main') -and ($_.Name -eq 'Test-ExitButton') }).Count,
            @(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_REWARD_FRAGMENT))).Count, $result.ExitCode, $result.Markers, $result.ClearedCalls, (Get-ReturnText $result),
            $result.CustomCleanupOnly, $result.SelectorCalls, $result.Thrown)) `
        (J @(1, 2, 1, '10', 0, 0, '10/cleanup-only', 'True', 0, ''))
    # [보강 2.6 검증] 마커(owner i) + 열린 entered(owner i) + RECOVERY=1·RESTART=1 · ESC 메뉴 → Role none(선행 조건) → HEAD 그대로 메뉴 복귀 뒤 복구 회차의 exit 0
    #   (run:18416 - 코드 10 이 아님). 정적 R4-P14 의 문장 목록과 짝 - 앞뒤 두 조각만 보던 동안은 이 exit 0 을 지운 변이가 살아남았습니다
    $result = Invoke-FlowRow -FlowRow @{ Name = 'V18 복구 메뉴'; Custom = $true; Recovery = $true; Restart = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry)); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'MENU')) } } -FlowLayer 'main'
    Assert-Case 'V18 RECOVERY=1·RESTART=1 + 열린 entered(owner i) · ESC 메뉴 → Role none · 선분기 0 · 메뉴 복귀 시작 줄 1 · Return 10/ · 복귀 완료 줄 1 · exit 0 · (menu-overlay) 0 · NA launched 그대로 · 예외 0 (HEAD 그대로)' `
        (J @($result.Role, $result.SelectorCalls, @(Get-PatternLines -Result $result -Pattern ([regex]::Escape($MAIN_MENU_RETURN_FRAGMENT))).Count, (Get-ReturnText $result),
            (Get-LineCount -Result $result -Line $MAIN_MENU_DONE_LINE), $result.ExitCode, ((Get-StopLines $result).Contains('(menu-overlay)')), (Find-JournalEntry $result.Journal 'NA').LaunchState, $result.Thrown)) `
        (J @('none', 0, 1, '10/', 1, '0', 'False', 'launched', ''))
    # 마커(owner i) + 열린 entered(owner i) + RECOVERY=1·RESTART=1 · 던전 안 / 3버튼 → Role none(선행 조건) → throw(run:18384~18386) · 키 0 / 마커 · exit 0 · own 이어받기 0
    $result = Invoke-FlowRow -FlowRow @{ Name = 'V18 복구 던전 안'; Custom = $true; Recovery = $true; Restart = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry)); Scenario = @{ Timeline = $insideTimeline } } -FlowLayer 'main'
    Assert-Case "V18 RECOVERY=1·RESTART=1 + 열린 entered(owner i) · 던전 안 → Role none · 선분기 0 · throw('완료 항목 마무리 복구 중 어비스 내부 화면' - run:18384~18386) · exit 0건 · 입력 0 · 쓰기 0" `
        (J @($result.Role, $result.SelectorCalls, ([string]$result.Thrown).Contains('완료 항목 마무리 복구 중 어비스 내부 화면이 감지됐습니다'), $result.ExitCode, $result.Inputs, $result.Updates)) `
        (J @('none', 0, 'True', '', 0, 0))
    $result = Invoke-FlowRow -FlowRow @{ Name = 'V18 복구 3버튼'; Custom = $true; Recovery = $true; Restart = $true; Nonce = $NONCE_A; Entries = @((New-ChOwnEntry)); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'R3')) } } -FlowLayer 'main'
    Assert-Case 'V18 RECOVERY=1·RESTART=1 + 열린 entered(owner i) · 3버튼 → Role none · 선분기 0 · 마커 1 · cleared 0 · Return 0/ · exit 0 · NA launched 그대로(own 이어받기 0) · 예외 0' `
        (J @($result.Role, $result.SelectorCalls, $result.Markers, $result.ClearedCalls, (Get-ReturnText $result), $result.ExitCode, (Find-JournalEntry $result.Journal 'NA').LaunchState, $result.Thrown)) `
        (J @('none', 0, 1, 0, '0/', '0', 'launched', ''))
}

function Test-RowRS0 {
    # RS0 - RESUME=1 + retry-clicked 항목 → Role resume → S19 · exit 4 · 판독·클릭·키 0 (J12 - ② 워커는 dev:904 1행만, resume 표는 ⑤). 층 ②
    $resumeRow = @{ Name = 'RS0'; Custom = $true; Nonce = $NONCE_C; Resume = '1'; Entries = @((New-ChOwnEntry -Nonce $NONCE_C -Stage 'retry-clicked')); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'I')) } }
    $result = Invoke-FlowRow -FlowRow $resumeRow -FlowLayer 'main'
    Save-ObservedStop -Key 'S19' -Result $result
    $selectorReads = @(@($result.ReadLog) | Where-Object { $_.Phase -eq 'selector' }).Count
    Assert-Case 'RS0 RESUME=1 + retry-clicked(owner 일치) → Role resume · 선분기 1 · S19 · exit 4 · 선분기 판독 0 · 입력 0 · 기록 0(파일 불변) · 예외 0' `
        (J @($result.Role, $result.SelectorCalls, (Get-StopLines $result), $result.ExitCode, $selectorReads, $result.Inputs, $result.Unchanged, $result.Thrown)) `
        (J @('resume', 1, $S19_RESUME, '4', 0, 0, 'True', ''))
}

function Test-RowRoleHarness {
    # 하니스 단언 (명세 2.6 · R4 4.3 '두지 않는 것' 의 근거): 층 ② 의 Role≠none 행은 전부 run:18527 앞에서 exit 하거나 $startInsideDetected 참으로 나옵니다 -
    #   카드 클릭(run:18558)의 Role 정지가 필요 없는 이유(결론 넷이 모두 앞에서 끝남). 예외로 끝난 행(V18 복구 throw 는 Role none 이라 밖)도 실패로 셉니다
    $outcomes = @($script:roleFlowOutcomes)
    $bad = @($outcomes | Where-Object { [string]::IsNullOrEmpty($_.ExitCode) -and ($_.StartInside -ne 'True') -or $_.Thrown })
    Assert-True ("하니스 단언 - 층 ② Role≠none 행 $($outcomes.Count)개 전부 run:18527 앞 exit 또는 `$startInsideDetected 참 (예외 0)") `
        (($outcomes.Count -ge 10) -and ($bad.Count -eq 0)) `
        ((@($bad | ForEach-Object { '{0}(Role {1} · exit [{2}] · 안 [{3}] · 예외 [{4}])' -f $_.Name, $_.Role, $_.ExitCode, $_.StartInside, $_.Thrown }) -join ' / ') + (' · 행 수 {0}' -f $outcomes.Count))
}

# ===== 정적 도구 (주석 뺀 사본 · AST - 단계 2.4~2.6 의 P 행 · LG) =====
function Get-FlowFunctionNode {
    # 워커 최상위 함수 정의 노드 (없으면 $null)
    param([string]$Name)
    if ($workerTopFunctions.ContainsKey($Name)) { return $workerTopFunctions[$Name] }
    return $null
}

function Get-StrippedText {
    # 노드의 주석 뺀 원문(워커 사본 - 위치가 원문과 같음)
    param($Node)
    if ($null -eq $Node) { return '' }
    return $workerCode.Substring($Node.Extent.StartOffset, $Node.Extent.EndOffset - $Node.Extent.StartOffset)
}

function Get-StringNodes {
    # 노드 안 문자열 노드 전부(작은따옴표·큰따옴표·확장 - 명령 이름 같은 맨 낱말은 뺌). 주석은 AST 노드가 아니라 저절로 빠짐 = 주석 뺀 사본과 같음
    param($Node)
    if ($null -eq $Node) { return @() }
    return @($Node.FindAll({ param($node) (($node -is [StringConstantExpressionAst]) -and ($node.StringConstantType -ne [StringConstantType]::BareWord)) -or ($node -is [ExpandableStringExpressionAst]) }, $true))
}

function Get-CommandNodes {
    # 노드 안 그 이름의 명령 호출 전부
    param($Node, [string]$Name)
    if ($null -eq $Node) { return @() }
    return @($Node.FindAll({ param($node) ($node -is [CommandAst]) -and ($node.GetCommandName() -eq $Name) }, $true))
}

function Get-OwningStatement {
    # 노드를 품은 문장(부모가 문장 블록·이름 블록인 자리)
    param($Node)
    $current = $Node
    while (($null -ne $current.Parent) -and (-not (($current.Parent -is [StatementBlockAst]) -or ($current.Parent -is [NamedBlockAst])))) { $current = $current.Parent }
    return $current
}

function Get-NextStatement {
    # 같은 문장 블록의 바로 다음 문장 (없으면 $null)
    param($Statement)
    if (($null -eq $Statement) -or ($null -eq $Statement.Parent)) { return $null }
    $siblings = @($Statement.Parent.Statements)
    for ($siblingIndex = 0; $siblingIndex -lt $siblings.Count; $siblingIndex++) {
        if ([object]::ReferenceEquals($siblings[$siblingIndex], $Statement)) {
            if (($siblingIndex + 1) -lt $siblings.Count) { return $siblings[$siblingIndex + 1] }
            return $null
        }
    }
    return $null
}

function Get-EnclosingConditions {
    # 노드를 품은 if 갈래 조건들(가까운 것부터 · 주석 뺀 사본 공백 정규화). else 갈래면 'else:' + 그 if 의 첫 조건
    param($Node)
    $conditions = @()
    for ($parent = $Node.Parent; $null -ne $parent; $parent = $parent.Parent) {
        if ($parent -isnot [IfStatementAst]) { continue }
        $clauseMatched = $false
        foreach ($clause in $parent.Clauses) {
            if (Test-AstWithin -Node $Node -Ancestor $clause.Item2) {
                $conditions += (Get-NormalizedCode -Node $clause.Item1)
                $clauseMatched = $true
                break
            }
        }
        if ((-not $clauseMatched) -and ($null -ne $parent.ElseClause) -and (Test-AstWithin -Node $Node -Ancestor $parent.ElseClause)) {
            $conditions += ('else:' + (Get-NormalizedCode -Node $parent.Clauses[0].Item1))
        }
    }
    return $conditions
}

function Get-RoleNoneBranch {
    # 노드를 품은 가장 가까운 'if ($roleNone)' 의 갈래 - 'then' / 'else' / ''(그 if 안이 아님)
    param($Node)
    foreach ($condition in @(Get-EnclosingConditions -Node $Node)) {
        if ($condition -eq '$roleNone') { return 'then' }
        if ($condition -eq 'else:$roleNone') { return 'else' }
    }
    return ''
}

function Get-CommandArgumentText {
    # 명령의 '-이름 값' 인자 원문(공백 정규화 · 없으면 '(없음)')
    param($Command, [string]$Parameter)
    $elements = @($Command.CommandElements)
    for ($elementIndex = 0; $elementIndex -lt $elements.Count; $elementIndex++) {
        $element = $elements[$elementIndex]
        if (($element -is [CommandParameterAst]) -and ($element.ParameterName -eq $Parameter)) {
            if ($null -ne $element.Argument) { return (Get-NormalizedCode -Node $element.Argument) }
            if (($elementIndex + 1) -lt $elements.Count) { return (Get-NormalizedCode -Node $elements[$elementIndex + 1]) }
        }
    }
    return '(없음)'
}

function Test-InsideScriptBlockExpression {
    # 노드가 스크립트블록 리터럴({ … } - mutator 클로저 등) 안에 있는지
    param($Node)
    for ($parent = $Node.Parent; $null -ne $parent; $parent = $parent.Parent) { if ($parent -is [ScriptBlockExpressionAst]) { return $true } }
    return $false
}

function Test-RowLG {
    # LG - 정지 문구 단언 (명세 3.2 LG · 2.5 S9~S20 · J22): ① 실행 쪽 = 행들이 실제로 낸 정지 줄의 성질 ② 정적 쪽 = 주석 뺀 워커 사본의 문자열
    $Tpm = [int]$capturedTimeoutPartyMatch
    $stops = $script:observedStops
    $needKeys = @('S9', 'S10', 'S11', 'S12', 'S13', 'S14', 'S15', 'S16', 'S17-custom', 'S17-plain', 'S18', 'S19', 'S20', 'S15-20')
    $missingKeys = @($needKeys | Where-Object { -not $stops.ContainsKey($_) })
    Assert-True 'LG 실행 쪽 - 정지 문구 14종을 행들이 모두 냄(S9~S20 · S17 두 변형 · Tpm 20 의 S15)' ($missingKeys.Count -eq 0) ('없음: ' + ($missingKeys -join ','))
    $properties = @(
        @{ Name = "next·상세(next)·미결(next) 문구에 '수동으로 마치지 말고'"; Keys = @('S9', 'S11', 'S13', 'S15'); Fragment = '수동으로 마치지 말고'; Want = $true },
        @{ Name = "own 문구(선택 화면·메뉴·미결)에 '그 판을 마친 뒤'"; Keys = @('S10', 'S12', 'S16'); Fragment = '그 판을 마친 뒤'; Want = $true },
        @{ Name = "상세 own 문구에 '그 자리에서 다시 시작해도'"; Keys = @('S14'); Fragment = '그 자리에서 다시 시작해도'; Want = $true },
        @{ Name = "next 3버튼·S 커스텀 꼬리에 '정리 전용(코드 10)'"; Keys = @('S17-custom'); Fragment = '정리 전용(코드 10)'; Want = $true },
        @{ Name = "next 3버튼·S 비커스텀 꼬리에 '1회 계상'"; Keys = @('S17-plain'); Fragment = '1회 계상'; Want = $true },
        @{ Name = "상세 두 문구에 '화면을 닫고 필드'"; Keys = @('S13', 'S14'); Fragment = '화면을 닫고 필드'; Want = $true },
        @{ Name = "미결 마감 초 = `${timeoutPartyMatch}(캡처값 $Tpm)"; Keys = @('S15', 'S16'); Fragment = ('{0}초 안에 확인하지 못해' -f $Tpm); Want = $true },
        @{ Name = '미결 마감 초 = ${timeoutPartyMatch}(Tpm 20 행)'; Keys = @('S15-20'); Fragment = '20초 안에 확인하지 못해'; Want = $true },
        @{ Name = '오버레이·상세·미결·resume 정지 문구에 (release) 0'; Keys = @('S9', 'S10', 'S11', 'S12', 'S13', 'S14', 'S15', 'S16', 'S19'); Fragment = '(release)'; Want = $false })
    foreach ($property in $properties) {
        $badKeys = @($property.Keys | Where-Object { $stops.ContainsKey($_) -and (([string]$stops[$_]).Contains($property.Fragment) -ne $property.Want) })
        Assert-True ('LG 실행 쪽 - ' + $property.Name) ($badKeys.Count -eq 0) ('어긋난 문구: ' + (@($badKeys | ForEach-Object { '{0}=[{1}]' -f $_, $stops[$_] }) -join ' / '))
    }
    $releaseKeys = @('S17-custom', 'S17-plain', 'S18', 'S20')
    $badRelease = @($releaseKeys | Where-Object { $stops.ContainsKey($_) -and (-not ([string]$stops[$_]).EndsWith($RELEASE_TAIL)) })
    Assert-True 'LG 실행 쪽 - next 3버튼·S 두 변형 · B2 마감 · 선분기 생성 실패(S20) 문구 끝 (release)' ($badRelease.Count -eq 0) ('어긋난 문구: ' + ($badRelease -join ','))
    # 정적 쪽 - 선분기·정지 함수의 문자열에 각 성질의 조각이 있고, 미결 마감 문구 틀의 초는 변수, 본류 키 지점의 생성 실패 줄은 꼬리 0
    $flowNodes = @((Get-FlowFunctionNode 'Invoke-AbyssHandoffStart'), (Get-FlowFunctionNode 'Stop-AbyssHandoffOverlay'))
    $flowStrings = @(foreach ($flowNode in $flowNodes) { foreach ($stringNode in (Get-StringNodes -Node $flowNode)) { [string]$stringNode.Value } })
    $staticMissing = @(@('수동으로 마치지 말고', '그 판을 마친 뒤', '그 자리에서 다시 시작해도', '정리 전용(코드 10)', '1회 계상', '화면을 닫고 필드') |
            Where-Object { $fragment = $_; @($flowStrings | Where-Object { $_.Contains($fragment) }).Count -eq 0 })
    Assert-True 'LG 정적 쪽 - 선분기·정지 함수 문자열(주석 뺀 사본)에 next·own·상세·S17 꼬리 조각이 모두 있음' ($staticMissing.Count -eq 0) ('없는 조각: ' + ($staticMissing -join ','))
    $selectorNode = Get-FlowFunctionNode 'Invoke-AbyssHandoffStart'
    $unknownTemplates = @(@(Get-StringNodes -Node $selectorNode) | Where-Object {
            ($_ -is [ExpandableStringExpressionAst]) -and ([string]$_.Value).Contains('초 안에 확인하지 못해 조작 없이 정지합니다') -and
            (@($_.NestedExpressions | Where-Object { ($_ -is [VariableExpressionAst]) -and ($_.VariablePath.UserPath -eq 'timeoutPartyMatch') }).Count -ge 1) })
    Assert-True 'LG 정적 쪽 - 미결 마감 문구 틀의 초 = ${timeoutPartyMatch} 변수(확장 문자열 1 이상 - 숫자 박기 0)' ($unknownTemplates.Count -ge 1) ('틀 {0}개' -f $unknownTemplates.Count)
    $keyPointStrings = @(@(Get-StringNodes -Node $workerAst) | Where-Object { ([string]$_.Value).Contains('[완료] 입장 기록 실패') -and (-not (Test-AstWithin -Node $_ -Ancestor $selectorNode)) })
    Assert-True '본류 키 지점의 생성 실패 줄 끝 꼬리 0 (선분기 밖 [완료] 입장 기록 실패 문자열 = dev:874 문구 그대로 - 놓아줄 이어받은 항목이 없음)' `
        (($keyPointStrings.Count -ge 1) -and (@($keyPointStrings | Where-Object { [string]$_.Value -cne $KEYPOINT_CREATE_FAIL }).Count -eq 0)) `
        ('문자열: ' + (@($keyPointStrings | ForEach-Object { '[' + $_.Value + ']' }) -join ' '))
}

function Test-StaticFlow {
    # 정적 단언 (주석 뺀 사본 · AST - 설계 v11 R4 6.4 P2~P12·P14~P18 · 명세 3.2 P19·P20·P22 · 3.3 R2-S7(개정)). P1·P13·P21 은 단계 2.1 정적(아래 실행 ②)
    $selectorNode = Get-FlowFunctionNode 'Invoke-AbyssHandoffStart'
    $overlayNode = Get-FlowFunctionNode 'Stop-AbyssHandoffOverlay'
    $stepNode = Get-FlowFunctionNode 'Step-AbyssFieldSettle'
    $classifierNode = Get-FlowFunctionNode 'Resolve-AbyssHandoffStartScreen'
    $closeNode = Get-FlowFunctionNode 'Close-AbyssOwnEntryBeforeEntry'
    $enteredNode = Get-FlowFunctionNode 'Add-AbyssJournalEnteredEntry'
    $consumeNode = Get-FlowFunctionNode 'Consume-Handoff'
    $topAssigns = {
        # (내부) 함수 밖 대입문 중 왼쪽 원문이 같고 오른쪽에 조각이 든 것
        param([string]$Left, [string]$RightFragment)
        return @(Find-WorkerAssignments -Left $Left -RightFragment $RightFragment | Where-Object { -not (Test-AstInsideFunction $_) })
    }

    # R4-P2 - run:18244 자리 조건식 = 원문 + Role none 항 1 (옛 조건식 0)
    $p2New = @($workerAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and (-not (Test-AstInsideFunction $node)) -and
                ((Get-NormalizedCode -Node $node.Clauses[0].Item1) -eq '(-not $startExitDetected) -and (-not $startClearDetected) -and $roleNone') }, $true)).Count
    $p2Old = @($workerAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and (-not (Test-AstInsideFunction $node)) -and
                ((Get-NormalizedCode -Node $node.Clauses[0].Item1) -eq '(-not $startExitDetected) -and (-not $startClearDetected)') }, $true)).Count
    Assert-Case 'R4-P2 run:18244 자리 조건식 if ((-not $startExitDetected) -and (-not $startClearDetected) -and $roleNone) 정확히 1 · 옛 조건식(Role 항 없음) 0' (J @($p2New, $p2Old)) (J @(1, 0))

    # R4-P3 - $startInsideDetected 대입 = Role none 판독 1(then) · 결론 대입 1(else) · 재판독 정정(run:18471) 1
    $insideAssigns = @(& $topAssigns '$startInsideDetected' '')
    $insideRead = @($insideAssigns | Where-Object { $_.Right.Extent.Text.Contains('Test-DungeonEntered') })
    $insideConclusion = @($insideAssigns | Where-Object { $_.Right.Extent.Text.Contains('StartScreen') })
    $insideReread = @($insideAssigns | Where-Object { (Get-NormalizedCode -Node $_.Right) -eq '$true' })
    Assert-Case 'R4-P3 $startInsideDetected 대입 = 함수 밖 3 · Role none 판독 1($roleNone 참 갈래) · 결론 대입 1($roleNone 거짓 갈래) · 재판독 정정 1' `
        (J @($insideAssigns.Count, $insideRead.Count, (@($insideRead | ForEach-Object { Get-RoleNoneBranch -Node $_ }) -join ','), $insideConclusion.Count, (@($insideConclusion | ForEach-Object { Get-RoleNoneBranch -Node $_ }) -join ','), $insideReread.Count)) `
        (J @(3, 1, 'then', 1, 'else', 1))

    # R4-P4 - 본류 시작 판독(run:18222·18235·18468~18469)은 $roleNone 참 갈래 안에만, 같은 변수의 결론 대입은 거짓 갈래
    $p4Rows = @()
    foreach ($p4Spec in @(
            @{ Left = '$fieldHudNow'; Read = 'Test-HomeEndEscHud' }, @{ Left = '$fieldQuestNow'; Read = 'Test-InDungeonQuest' },
            @{ Left = '$startClearDetected'; Read = 'Test-DungeonClearPrompt' })) {
        $readAssigns = @(& $topAssigns $p4Spec.Left $p4Spec.Read)
        $conclusionAssigns = @(& $topAssigns $p4Spec.Left 'StartScreen')
        $p4Rows += ('{0} 판독 {1}({2}) 결론 {3}({4})' -f $p4Spec.Left, $readAssigns.Count, (@($readAssigns | ForEach-Object { Get-RoleNoneBranch -Node $_ }) -join ','),
            $conclusionAssigns.Count, (@($conclusionAssigns | ForEach-Object { Get-RoleNoneBranch -Node $_ }) -join ','))
    }
    $clearIfStatement = $(if (@($clearIfIndexes).Count -eq 1) { $mainStatements[$clearIfIndexes[0]] } else { $null })
    $exitRereads = @(& $topAssigns '$startExitDetected' 'Test-ExitButton' | Where-Object { Test-AstWithin -Node $_ -Ancestor $clearIfStatement })
    $exitConclusions = @(& $topAssigns '$startExitDetected' 'StartScreen')
    $p4Rows += ('$startExitDetected 재판독(이벤트 정리 if 안) {0}({1}) 결론 {2}({3})' -f $exitRereads.Count, (@($exitRereads | ForEach-Object { Get-RoleNoneBranch -Node $_ }) -join ','),
        $exitConclusions.Count, (@($exitConclusions | ForEach-Object { Get-RoleNoneBranch -Node $_ }) -join ','))
    Assert-Case 'R4-P4 run:18222·18235·18468~18469 판독은 $roleNone 참 갈래 안에만 · 같은 변수의 결론 대입은 거짓 갈래' ($p4Rows -join ' || ') `
        (@('$fieldHudNow 판독 1(then) 결론 1(else)', '$fieldQuestNow 판독 1(then) 결론 1(else)', '$startClearDetected 판독 1(then) 결론 1(else)', '$startExitDetected 재판독(이벤트 정리 if 안) 1(then) 결론 1(else)') -join ' || ')

    # R4-P5 - 필드 확정 식 1(순수 함수) · 호출 인자 전부 -SettleSeconds $memberFieldSettleSeconds · 복귀 루프 식 그대로 1 · W 상수 하나(새 상수 0)
    $stepText = Get-StrippedText $stepNode
    $stepCalls = @(Get-CommandNodes -Node $workerAst -Name 'Step-AbyssFieldSettle')
    $stepArgs = @($stepCalls | ForEach-Object { Get-CommandArgumentText -Command $_ -Parameter 'SettleSeconds' } | Select-Object -Unique)
    $returnLoopText = Get-StrippedText (Get-FlowFunctionNode 'Return-ToAbyssSelection')
    $returnLoopExpression = 'if ($fieldSettleCount -lt 2 -or ($turnNow - $fieldSettleSince).TotalSeconds -lt $memberFieldSettleSeconds) {'
    $wAssigns = @(& $topAssigns '$memberFieldSettleSeconds' '')
    $magicValues = @([int]$memberFieldSettleSeconds, [int]$memberUnknownOverlaySeconds, [int]$capturedTimeoutPartyMatch)
    # 숫자 박기 = W·30·Tpm 과 같은 정수 상수(대기 ms 인자 Start-Sleep -Milliseconds 는 시간 한도가 아니라 뺌 - 회전 대기 700 등)
    $magicHits = @(foreach ($constantNode in @($selectorNode, $stepNode | Where-Object { $null -ne $_ } | ForEach-Object { $_.FindAll({ param($node) $node -is [ConstantExpressionAst] }, $true) })) {
            $sleepArgument = ($constantNode.Parent -is [CommandAst]) -and ($constantNode.Parent.GetCommandName() -eq 'Start-Sleep')
            if (($constantNode -isnot [StringConstantExpressionAst]) -and (-not $sleepArgument) -and ($constantNode.Value -is [int]) -and ($magicValues -contains [int]$constantNode.Value)) { $constantNode.Extent.Text }
        })
    Assert-Case 'R4-P5 필드 확정 함수 식 -lt 2 -or 1 · -lt $SettleSeconds 1 · 호출 1 이상 · 인자 전부 $memberFieldSettleSeconds · 복귀 루프 식 원문 1 · W 최상위 대입 1 · 선분기·필드 확정 함수의 W·30·Tpm 숫자 박기 0' `
        (J @([regex]::Matches($stepText, '-lt\s+2\s+-or').Count, [regex]::Matches($stepText, '-lt\s+\$SettleSeconds').Count, ($stepCalls.Count -ge 1), ($stepArgs -join ','),
            [regex]::Matches($returnLoopText, [regex]::Escape($returnLoopExpression)).Count, $wAssigns.Count, ($magicHits -join ','))) `
        (J @(1, 1, 'True', '$memberFieldSettleSeconds', 1, 1, ''))

    # R4-P6 - 선분기(·정지 함수) 안 Return-ToAbyssSelection 호출 0 (필드 확정은 본류 필드 분기로만)
    Assert-Case 'R4-P6 선분기·정지 함수 안 Return-ToAbyssSelection 호출 0' (@(Get-CommandNodes -Node $selectorNode -Name 'Return-ToAbyssSelection').Count + @(Get-CommandNodes -Node $overlayNode -Name 'Return-ToAbyssSelection').Count) 0

    # R4-P7 - own 닫기 시도 자리 2(필드 확정 갈래 · 패널류 갈래) · 각 자리 바로 다음 문장 = CleanupOnly 비움(닫기 결과 갈래 밖) · 비움 대입 2
    $closeCalls = @(Get-CommandNodes -Node $selectorNode -Name 'Close-AbyssOwnEntryBeforeEntry')
    $closeNext = @($closeCalls | ForEach-Object { Get-NormalizedCode -Node (Get-NextStatement -Statement (Get-OwningStatement -Node $_)) })
    $clearAssigns = @($selectorNode.FindAll({ param($node) ($node -is [AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$script:handoff.CleanupOnly') -and ((Get-NormalizedCode -Node $node.Right) -eq '$false') }, $true))
    $closeScreens = @($closeCalls | ForEach-Object { Get-CommandArgumentText -Command $_ -Parameter 'Screen' })
    Assert-Case 'R4-P7 own 닫기 호출 2 · 각 호출 바로 다음 문장 = $script:handoff.CleanupOnly = $false(닫기 결과 조건 밖 - 성공·실패 무관) · 비움 대입 2 · 한 자리 -Screen ''field''' `
        (J @($closeCalls.Count, (@($closeNext | Select-Object -Unique) -join ','), $clearAssigns.Count, ($closeScreens -contains "'field'"))) (J @(2, '$script:handoff.CleanupOnly = $false', 2, 'True'))

    # R4-P8 - 계측 줄 2(B2 입장 계측 · 시작 직후 계측) · 결과 줄 2(필드 확정 · own 닫기 성공) - 넷 다 Write-RunLog 의 확장 문자열 인자(-f 식 0) · 계측 변수는 조건 안 0
    $p8Scope = @($selectorNode, $closeNode | Where-Object { $null -ne $_ })
    $p8Rows = @()
    $measureVariables = @()
    foreach ($p8Spec in @(
            @{ Name = 'B2 입장 계측'; Fragment = '[어비스] 입장 계측 - 던전 안 2연속 앞 로딩(알 수 없음)'; Measure = $true },
            @{ Name = '시작 직후 계측'; Fragment = '[어비스] 이어받기 시작 계측 - 던전 안 2연속 앞 알 수 없음'; Measure = $true },
            @{ Name = '필드 확정'; Fragment = '[어비스] 이어받기 시작: 던전 밖(HUD) 확인 - 필드 모양이 '; Measure = $false },
            @{ Name = 'own 닫기 성공'; Fragment = '[어비스] 시작 화면이 던전 밖이라 이어받던 판의 기록을 닫았습니다'; Measure = $false })) {
        $expandableCalls = 0
        $formatCalls = 0
        foreach ($scopeNode in $p8Scope) {
            foreach ($logCall in (Get-CommandNodes -Node $scopeNode -Name 'Write-RunLog')) {
                $logArgument = $(if (@($logCall.CommandElements).Count -ge 2) { $logCall.CommandElements[1] } else { $null })
                if ($null -eq $logArgument) { continue }
                if (($logArgument -is [ExpandableStringExpressionAst]) -and ([string]$logArgument.Value).Contains($p8Spec.Fragment)) {
                    $expandableCalls++
                    if ($p8Spec.Measure) { $measureVariables += @($logArgument.NestedExpressions | Where-Object { $_ -is [VariableExpressionAst] } | ForEach-Object { $_.VariablePath.UserPath }) }
                } elseif ($logArgument.Extent.Text.Contains($p8Spec.Fragment)) { $formatCalls++ }
            }
        }
        $p8Rows += ('{0} 확장 {1} · 그 밖 {2}' -f $p8Spec.Name, $expandableCalls, $formatCalls)
    }
    $conditionTexts = @(foreach ($conditionNode in $selectorNode.FindAll({ param($node) ($node -is [IfStatementAst]) -or ($node -is [LoopStatementAst]) }, $true)) {
            if ($conditionNode -is [IfStatementAst]) { foreach ($clause in $conditionNode.Clauses) { Get-NormalizedCode -Node $clause.Item1 } }
            elseif ($null -ne $conditionNode.Condition) { Get-NormalizedCode -Node $conditionNode.Condition }
        })
    $measureInConditions = @(@($measureVariables | Where-Object { $_ -ne 'memberFieldSettleSeconds' } | Select-Object -Unique) |
            Where-Object { $measureName = $_; @($conditionTexts | Where-Object { $_ -match ('\$\{?' + [regex]::Escape($measureName) + '\b') }).Count -gt 0 })
    Assert-Case 'R4-P8 계측 줄 2 · 결과 줄 2 = Write-RunLog 확장 문자열 인자 1씩(-f 식 등 그 밖 0) · 계측 줄 변수가 조건문 안 0' `
        (J @(($p8Rows -join ' / '), ($measureInConditions -join ','))) (J @('B2 입장 계측 확장 1 · 그 밖 0 / 시작 직후 계측 확장 1 · 그 밖 0 / 필드 확정 확장 1 · 그 밖 0 / own 닫기 성공 확장 1 · 그 밖 0', ''))

    # R4-P9 · R2-S7(개정) - 자기 항목 생성 2자리(ownFreshEntry -CleanupOnly $false 1 · 본류 키 지점 ([bool]$script:customCleanupOnly) 1) · 값은 mutator 밖에서 항목에 ·
    #   mutator 안 $script: 0 · $cleanupByScreen 식 1
    $enteredCalls = @(Get-CommandNodes -Node $workerAst -Name 'Add-AbyssJournalEnteredEntry')
    $selectorEntered = @($enteredCalls | Where-Object { Test-AstWithin -Node $_ -Ancestor $selectorNode })
    $mainEntered = @($enteredCalls | Where-Object { -not (Test-AstInsideFunction $_) })
    $cleanupFieldAssigns = @($(if ($null -ne $enteredNode) { $enteredNode.FindAll({ param($node) ($node -is [AssignmentStatementAst]) -and $node.Left.Extent.Text.EndsWith('.cleanupOnly') }, $true) }))
    $mutatorScriptVariables = @($(if ($null -ne $enteredNode) {
                foreach ($scriptBlockNode in $enteredNode.FindAll({ param($node) $node -is [ScriptBlockExpressionAst] }, $true)) {
                    @($scriptBlockNode.FindAll({ param($node) ($node -is [VariableExpressionAst]) -and $node.VariablePath.IsScript }, $true))
                }
            }))
    $cleanupByScreenAssigns = @(& $topAssigns '$cleanupByScreen' '' | Where-Object { (Get-NormalizedCode -Node $_.Right) -eq '(($roleNone -and -not $script:finishOnly) -or $script:handoff.CleanupOnly)' })
    Assert-Case 'R4-P9 · R2-S7(개정) 생성 호출 2 = 선분기 1(-CleanupOnly $false) · 본류 1(-CleanupOnly ([bool]$script:customCleanupOnly)) · 생성 함수의 cleanupOnly 대입은 mutator 밖 · mutator 안 $script: 0 · $cleanupByScreen 식 1' `
        (J @($enteredCalls.Count, (@($selectorEntered | ForEach-Object { Get-CommandArgumentText -Command $_ -Parameter 'CleanupOnly' }) -join ','),
            (@($mainEntered | ForEach-Object { Get-CommandArgumentText -Command $_ -Parameter 'CleanupOnly' }) -join ','), ($cleanupFieldAssigns.Count -ge 1),
            @($cleanupFieldAssigns | Where-Object { Test-InsideScriptBlockExpression -Node $_ }).Count, $mutatorScriptVariables.Count, $cleanupByScreenAssigns.Count)) `
        (J @(2, '$false', '([bool]$script:customCleanupOnly)', 'True', 0, 0, 1))

    # R4-P10 · P19 - 선분기·새 함수에 $abyssPartyMemberRun 0 · `$startMatchingDetected = ` 0 · HEAD 입장 대기 성공 줄 0(주석 뺀 사본) · 'if (Clear-EventOverlay -Game $game)' 0(원문·사본)
    $p19Rows = @()
    foreach ($newNode in @($selectorNode, $overlayNode, $stepNode, $classifierNode, $closeNode, $consumeNode)) {
        if ($null -eq $newNode) { $p19Rows += '(정의 없음)'; continue }
        $strippedNewText = Get-StrippedText $newNode
        $p19Rows += ('{0}:{1}/{2}/{3}/{4}/{5}' -f $newNode.Name, ([regex]::Matches($strippedNewText, [regex]::Escape('$abyssPartyMemberRun')).Count),
            ([regex]::Matches($strippedNewText, [regex]::Escape('$startMatchingDetected = ')).Count), ([regex]::Matches($strippedNewText, [regex]::Escape('뒤 입장 완료 감지 - 이 판의 클리어 대기부터')).Count),
            ([regex]::Matches($newNode.Extent.Text, [regex]::Escape($CLEAR_IF_TEXT.TrimEnd(' {'))).Count), ([regex]::Matches($strippedNewText, [regex]::Escape($CLEAR_IF_TEXT.TrimEnd(' {'))).Count))
    }
    Assert-Case 'R4-P10 · P19 새 함수(선분기·정지·필드 확정·분류·own 닫기·Consume-Handoff) - $abyssPartyMemberRun / $startMatchingDetected = / HEAD 입장 완료 줄 / 원문 이벤트 정리 if / 사본 이벤트 정리 if 모두 0' `
        ($p19Rows -join ' ') ((@('Invoke-AbyssHandoffStart', 'Stop-AbyssHandoffOverlay', 'Step-AbyssFieldSettle', 'Resolve-AbyssHandoffStartScreen', 'Close-AbyssOwnEntryBeforeEntry', 'Consume-Handoff') | ForEach-Object { '{0}:0/0/0/0/0' -f $_ }) -join ' ')

    # R4-P11(워커 쪽) - (start-unknown) 문자열은 선분기 안에만 · 끝 ' (start-unknown)' (초 변수는 LG 정적 쪽 · GUI 쪽 - 판별 항 · 재전달 집합 · 재개 보류 ·
    #   숨김 2곳 - 은 단계 2.7 의 ⑯ test_abyss_handoff_gui Test-CaseCode4Static 'R4-P11(GUI) · P22(GUI)' 행)
    $startUnknownStrings = @(@(Get-StringNodes -Node $workerAst) | Where-Object { ([string]$_.Value).Contains('(start-unknown)') })
    Assert-Case 'R4-P11(워커) (start-unknown) 문자열 1 이상 · 전부 선분기 안 · 전부 끝 '' (start-unknown)''' `
        (J @(($startUnknownStrings.Count -ge 1), @($startUnknownStrings | Where-Object { -not (Test-AstWithin -Node $_ -Ancestor $selectorNode) }).Count,
            @($startUnknownStrings | Where-Object { -not ([string]$_.Value).EndsWith(' (start-unknown)') }).Count)) (J @('True', 0, 0))

    # R4-P12 - 선분기 루프 회전 서두의 필드 연속 이어받기 한 줄('$…Alive = $…Next; $…Next = $false' - 동결 블록보다 앞) 1 · Step-AbyssFieldSettle 호출은 'field' 갈래 안에만
    $carryPairs = @()
    foreach ($loopNode in @($(if ($null -ne $selectorNode) { $selectorNode.FindAll({ param($node) $node -is [LoopStatementAst] }, $true) }))) {
        $loopStatements = @($loopNode.Body.Statements)
        $freezeIndex = -1
        for ($statementIndex = 0; $statementIndex -lt $loopStatements.Count; $statementIndex++) {
            if (($loopStatements[$statementIndex] -is [IfStatementAst]) -and ((Get-NormalizedCode -Node $loopStatements[$statementIndex].Clauses[0].Item1) -eq '$script:screenCaptureFailing') -and ($freezeIndex -lt 0)) { $freezeIndex = $statementIndex }
        }
        for ($statementIndex = 0; $statementIndex -lt ($loopStatements.Count - 1); $statementIndex++) {
            $first = $loopStatements[$statementIndex]
            $second = $loopStatements[$statementIndex + 1]
            if (($first -isnot [AssignmentStatementAst]) -or ($second -isnot [AssignmentStatementAst])) { continue }
            $firstRight = Get-NormalizedCode -Node $first.Right
            if (($first.Left.Extent.Text -match '^\$\w+$') -and ($firstRight -match '^\$\w+$') -and ($second.Left.Extent.Text -eq $firstRight) -and ((Get-NormalizedCode -Node $second.Right) -eq '$false')) {
                $carryPairs += [pscustomobject]@{ Text = ('{0} = {1}; {1} = $false' -f $first.Left.Extent.Text, $firstRight); BeforeFreeze = (($freezeIndex -lt 0) -or ($statementIndex -lt $freezeIndex)); FreezeFound = ($freezeIndex -ge 0) }
            }
        }
    }
    $stepInSelector = @(Get-CommandNodes -Node $selectorNode -Name 'Step-AbyssFieldSettle')
    $stepOutsideField = @($stepInSelector | Where-Object { @(Get-EnclosingConditions -Node $_ | Where-Object { $_.Contains("'field'") }).Count -eq 0 })
    Assert-Case "R4-P12 선분기 루프 서두 이어받기 한 줄 1(동결 블록 앞 · 동결 블록 있음) · Step-AbyssFieldSettle 호출 1 이상 · 'field' 갈래 밖 호출 0" `
        (J @($carryPairs.Count, (@($carryPairs | ForEach-Object { $_.BeforeFreeze -and $_.FreezeFound }) -join ','), ($stepInSelector.Count -ge 1), $stepOutsideField.Count)) (J @(1, 'True', 'True', 0))

    # R4-P12s [보강 2.5] - 회전 서두의 클릭 생략 사유 비움(명세 ② 2.0-2 · 2.5 골격 서두 · 규칙 4 '회전 서두에서 비운다 - 직전 회전의 메타가 남아 오발동'): 동결
    #   블록보다 앞의 루프 최상위 문장에 $script:lastClickSkipReason = '' 대입 정확히 1. 지금 스윕의 참은 늘 클릭 시도 뒤라 실행으로는 드러나지 않아(남은 메타를 읽을
    #   자리가 없음) 정적으로 고정합니다 - test_abyss_screen_signatures 가 시작 패널 입장 대기의 같은 서두를 원문으로 지키는 것과 같은 자리(2026-10-13 변이 검증)
    $headResets = @()
    $headLoops = 0
    foreach ($loopNode in @($(if ($null -ne $selectorNode) { $selectorNode.FindAll({ param($node) $node -is [LoopStatementAst] }, $true) }))) {
        $loopStatements = @($loopNode.Body.Statements)
        $freezeIndex = -1
        for ($statementIndex = 0; $statementIndex -lt $loopStatements.Count; $statementIndex++) {
            if (($loopStatements[$statementIndex] -is [IfStatementAst]) -and ((Get-NormalizedCode -Node $loopStatements[$statementIndex].Clauses[0].Item1) -eq '$script:screenCaptureFailing') -and ($freezeIndex -lt 0)) { $freezeIndex = $statementIndex }
        }
        if ($freezeIndex -lt 0) { continue }
        $headLoops++
        for ($statementIndex = 0; $statementIndex -lt $freezeIndex; $statementIndex++) {
            $headStatement = $loopStatements[$statementIndex]
            if (($headStatement -is [AssignmentStatementAst]) -and ($headStatement.Left.Extent.Text -eq '$script:lastClickSkipReason') -and ((Get-NormalizedCode -Node $headStatement.Right) -eq "''")) { $headResets += $headStatement }
        }
    }
    Assert-Case "R4-P12s 선분기 루프(동결 블록 있음) 1 · 동결 블록 앞 서두에 `$script:lastClickSkipReason = '' 정확히 1" (J @($headLoops, $headResets.Count)) (J @(1, 1))

    # R4-P14 - run:18409 메뉴 분기: '$roleNone -or …StartScreen -eq ''field''' 갈래 = HEAD 원문(run:18410~18417 의 문장 다섯 - 문장 목록 전체를 주석 뺀 사본 ·
    #   공백 정규화로 견줌) · 그 밖 갈래 = 오버레이 정지 함수 1 · 복귀 0. 앞뒤 두 조각(복귀 호출 · exit 10)만 보던 동안은 가운데 문장(복구 회차의 exit 0)을 지운
    #   변이가 이 파일과 관련 회귀(⑳ · test_abyss_screen_signatures · test_abyss_custom_worker · test_custom_worker · test_custom_exitcodes · test_audit_fixes)를
    #   모두 통과했습니다(2026-10-13 검증 지적 · 변이 확인 - 행동 짝은 V18 복구 메뉴 행)
    $menuIfs = @($workerAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and (-not (Test-AstInsideFunction $node)) -and
                ((Get-NormalizedCode -Node $node.Clauses[0].Item1) -eq '-not $startExitDetected -and (Test-AbyssMenu -Game $game)') }, $true))
    $menuInner = @($(if ($menuIfs.Count -eq 1) { @($menuIfs[0].Clauses[0].Item2.Statements) | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-NormalizedCode -Node $_.Clauses[0].Item1) -eq "`$roleNone -or `$script:handoff.StartScreen -eq 'field'") } }))
    $menuThenStatements = @($(if ($menuInner.Count -eq 1) { @($menuInner[0].Clauses[0].Item2.Statements) | ForEach-Object { Get-NormalizedCode -Node $_ } }))
    $menuElse = $(if (($menuInner.Count -eq 1) -and ($null -ne $menuInner[0].ElseClause)) { $menuInner[0].ElseClause } else { $null })
    $menuElseStops = @(Get-CommandNodes -Node $menuElse -Name 'Stop-AbyssHandoffOverlay')
    Assert-Case "R4-P14 메뉴 분기 1 · 안쪽 if(`$roleNone -or …StartScreen -eq 'field') 1 · 그 갈래 문장 = HEAD 원문 다섯(복귀 시작 줄 → 복귀 -SafeStopExitCode 10 → 복귀 완료 줄 → 복구 회차 exit 0 → exit 10) · 그 밖 갈래 = Stop-AbyssHandoffOverlay -Kind 'menu' 1 · 복귀 0" `
        (J @($menuIfs.Count, $menuInner.Count, ($menuThenStatements -join ' || '), $menuElseStops.Count,
            (@($menuElseStops | ForEach-Object { Get-CommandArgumentText -Command $_ -Parameter 'Kind' }) -join ','), @(Get-CommandNodes -Node $menuElse -Name 'Return-ToAbyssSelection').Count)) `
        (J @(1, 1, ($MENU_HEAD_STATEMENTS -join ' || '), 1, "'menu'", 0))

    # R4-P15 - $roleNoneOrOwn 0 · 카드 클릭(run:18558) 자리의 Role 조건 0 · 보상·S 분기(run:18420·18434)의 next 가드 0(조건 원문 그대로)
    $cardLogs = @(Get-CommandNodes -Node $workerAst -Name 'Write-RunLog' | Where-Object { (-not (Test-AstInsideFunction $_)) -and (@($_.CommandElements).Count -ge 2) -and $_.CommandElements[1].Extent.Text.Contains('카드 클릭') })
    $cardRoleConditions = @($cardLogs | ForEach-Object { Get-EnclosingConditions -Node $_ } | Where-Object { $_.Contains('handoff') -or $_.Contains('roleNone') })
    $rewardIfs = @($mainStatements | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-NormalizedCode -Node $_.Clauses[0].Item1) -eq '$startExitDetected') -and $_.Extent.Text.Contains('보상 화면(나가기) 감지') })
    $promptIfs = @($mainStatements | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-NormalizedCode -Node $_.Clauses[0].Item1) -eq '$startClearDetected') -and $_.Extent.Text.Contains('클리어 화면 감지 - 마무리부터 진행') })
    Assert-Case 'R4-P15 $roleNoneOrOwn 0 · 카드 클릭 줄 1 · 그 자리 Role 조건 0 · 보상 분기 if ($startExitDetected) 1 · S 분기 if ($startClearDetected) 1 (next 가드 0)' `
        (J @([regex]::Matches($workerCode, [regex]::Escape('$roleNoneOrOwn')).Count, $cardLogs.Count, $cardRoleConditions.Count, $rewardIfs.Count, $promptIfs.Count)) (J @(0, 1, 0, 1, 1))

    # R4-P16 - 클리어 기록 호출 = 본류 1 + own 시작 분기(보상 · S) 2 - 시작 분기 호출은 own 조건 안 · 마커 문장 뒤 · 나가기 헬퍼 앞 (Role none·next 갈래 0)
    $clearedCalls = @(Get-CommandNodes -Node $workerAst -Name 'Add-AbyssJournalClearedEntry')
    $branchRows = @()
    foreach ($branchIf in @($rewardIfs + $promptIfs)) {
        $branchStatements = @($branchIf.Clauses[0].Item2.Statements)
        $markerAt = -1; $clearedAt = -1; $helperAt = -1; $clearedCondition = '(없음)'
        for ($statementIndex = 0; $statementIndex -lt $branchStatements.Count; $statementIndex++) {
            $branchStatement = $branchStatements[$statementIndex]
            if (($markerAt -lt 0) -and (@(Get-CommandNodes -Node $branchStatement -Name 'Write-CustomClearMarker').Count -gt 0)) { $markerAt = $statementIndex }
            if (($clearedAt -lt 0) -and (@(Get-CommandNodes -Node $branchStatement -Name 'Add-AbyssJournalClearedEntry').Count -gt 0)) {
                $clearedAt = $statementIndex
                if ($branchStatement -is [IfStatementAst]) { $clearedCondition = Get-NormalizedCode -Node $branchStatement.Clauses[0].Item1 }
            }
            if (($helperAt -lt 0) -and (@(Get-CommandNodes -Node $branchStatement -Name 'Invoke-AbyssExitClick').Count -gt 0)) { $helperAt = $statementIndex }
        }
        $branchRows += ('{0}<{1}<{2}:{3}' -f [int]($markerAt -ge 0), [int](($clearedAt -gt $markerAt) -and ($markerAt -ge 0)), [int](($helperAt -gt $clearedAt) -and ($clearedAt -ge 0)), $clearedCondition)
    }
    $ownCondition = "(`$script:handoff.Role -eq 'own') -and -not (`$script:customMode -and `$script:customCleanupOnly)"
    Assert-Case 'R4-P16 클리어 기록 호출 = 워커 3(본류 1 + 시작 분기 2) · 보상·S 분기 각각 마커 < 기록 < 나가기 헬퍼 · 기록 조건 = own ∧ 정리 전용 아님' `
        (J @($clearedCalls.Count, ($branchRows -join ' / '))) (J @(3, ((@(1, 2) | ForEach-Object { '1<1<1:' + $ownCondition }) -join ' / ')))

    # R4-P17 (정적 몫) - 선분기의 클릭·키 명령 0 (B2 단계의 미결 마감 0 · 이벤트 정리 0 은 행동 행 R4-O4′ · V18 팝업×next 가 실행으로 봄)
    $clickNames = @('Click-GamePoint', 'Click-ScreenPoint', 'Press-KeyVerified', 'Press-KeyOnce', 'Invoke-ClickUntil', 'Invoke-AbyssExitClick')
    Assert-Case 'R4-P17(정적) 선분기 안 클릭·키 명령 0 (Click-GamePoint · Click-ScreenPoint · Press-KeyVerified · Press-KeyOnce · Invoke-ClickUntil · Invoke-AbyssExitClick)' `
        (@($clickNames | ForEach-Object { @(Get-CommandNodes -Node $selectorNode -Name $_).Count } | Measure-Object -Sum).Sum) 0

    # R4-P18 - 선분기의 이벤트 정리 호출 1 · [void](Clear-EventOverlay -Game $Game) 모양 · 그 조건에 굶김·복구 제외 항(D 의 (-not $sweepStarved) -and (-not $turnRecovered) 모양)
    $overlayCalls = @(Get-CommandNodes -Node $selectorNode -Name 'Clear-EventOverlay')
    $overlayStatement = $(if ($overlayCalls.Count -eq 1) { Get-NormalizedCode -Node (Get-OwningStatement -Node $overlayCalls[0]) } else { '' })
    $overlayConditions = $(if ($overlayCalls.Count -eq 1) { (@(Get-EnclosingConditions -Node $overlayCalls[0]) -join ' && ') } else { '' })
    Assert-Case 'R4-P18 선분기 Clear-EventOverlay 호출 1 · 문장 [void](Clear-EventOverlay -Game $Game) · 조건에 (-not $…Starved…) · (-not $…Recovered…)' `
        (J @($overlayCalls.Count, $overlayStatement, ($overlayConditions -match '\(-not \$\w*[Ss]tarved\w*\)'), ($overlayConditions -match '\(-not \$\w*[Rr]ecovered\w*\)'))) `
        (J @(1, '[void](Clear-EventOverlay -Game $Game)', 'True', 'True'))

    # P20 - 상세 갈래: 정지 문구 2(S13·S14) · 꼬리 (selection-overlay) · 진단 이름 '이어받기 시작 상세 화면' 1 (닫기·클릭·키 0 은 N19·O17 행동)
    $detailStrings = @(@(Get-StringNodes -Node $workerAst) | Where-Object { ([string]$_.Value).Contains('어비스 던전 상세 화면입니다') })
    $detailDiagStrings = @(@(Get-StringNodes -Node $workerAst) | Where-Object { ([string]$_.Value).Contains($DIAG_DETAIL) })
    Assert-Case "P20 상세 정지 문구 문자열 2 · 전부 끝 (selection-overlay) · 진단 이름 '$DIAG_DETAIL' 문자열 1" `
        (J @($detailStrings.Count, @($detailStrings | Where-Object { -not ([string]$_.Value).EndsWith('(selection-overlay)') }).Count, $detailDiagStrings.Count)) (J @(2, 0, 1))

    # P22 - ' (release)' 를 담은 워커 문자열은 선분기 안에만 (그 밖 0 - 본류 키 지점의 생성 실패 줄에도 0). 갈래별 꼬리 유무는 LG 실행 쪽 · GUI 쪽(판별 항 1 ·
    #   재전달 집합 0 · 꼬리 목록 1)은 ⑯ test_abyss_handoff_gui 의 같은 행
    $releaseStrings = @(@(Get-StringNodes -Node $workerAst) | Where-Object { ([string]$_.Value).Contains('(release)') })
    Assert-Case 'P22 (release) 문자열 1 이상 · 선분기 밖 0' (J @(($releaseStrings.Count -ge 1), @($releaseStrings | Where-Object { -not (Test-AstWithin -Node $_ -Ancestor $selectorNode) }).Count)) (J @('True', 0))
}

# ===== 실행 =====
try {
    # ① 추출 확인 · exit 치환(동작 행보다 먼저 - 명세 ② 2.0-8) · 서명 대조
    foreach ($problem in $extractionProblems) { "FAIL 추출: $problem"; $fails++ }
    Assert-ExitTally -Label '저장소 묶음 워커 사본' -Tally $bundleExit
    Assert-ExitTally -Label ('워커 함수 ' + (@($workerExtracted) -join '·')) -Tally $workerExit
    if ($null -ne $script:mainSegmentBlock) { Assert-ExitTally -Label '본류 시작 구간(2.1 블록 ~ $roleNone 대입)' -Tally $segmentExit }
    if ($null -ne $script:mainFlowBlock) { Assert-ExitTally -Label '본류 시작 구간 층 ②(2.1 블록 ~ run:18527 앞)' -Tally $flowExit }
    if ($guiAvailable) { Assert-ExitTally -Label 'GUI 함수' -Tally $guiExit }
    $signatureRows = @()
    foreach ($mockName in @($WORKER_MOCK_NAMES + $WORKER_SPY_NAMES)) { $signatureRows += ('{0}:{1}' -f $mockName, ((Get-ParamSignature -Ast $workerAst -Name $mockName) -ceq (Get-LiveParamSignature -Name $mockName))) }
    foreach ($mockName in @($GUI_MOCK_NAMES + $GUI_SPY_NAMES)) { $signatureRows += ('{0}:{1}' -f $mockName, ((Get-ParamSignature -Ast $guiAst -Name $mockName) -ceq (Get-LiveParamSignature -Name $mockName))) }
    Assert-Case '모의·감시 서명 = 실제 함수 서명(워커 4 · 저장소 2 · GUI 3)' ($signatureRows -join ' ') (@(@($WORKER_MOCK_NAMES + $WORKER_SPY_NAMES + $GUI_MOCK_NAMES + $GUI_SPY_NAMES) | ForEach-Object { '{0}:True' -f $_ }) -join ' ')
    # 단계 2.4~2.6 의 모의(원문 param 블록 그대로 만듦 - 정의가 원문에 있는지) · 감시(선분기 · 분류 · 정리 전용 술어 · 클리어 기록 - 손으로 쓴 서명이 원문과 같은지)
    $flowSignatureNames = @($FLOW_MOCK_NAMES + @('Invoke-AbyssHandoffStart', 'Resolve-AbyssHandoffStartScreen', 'Test-CustomCleanupOnly', 'Add-AbyssJournalClearedEntry'))
    $flowSignatureRows = @(foreach ($mockName in $flowSignatureNames) { '{0}:{1}' -f $mockName, ((Get-ParamSignature -Ast $workerAst -Name $mockName) -ceq (Get-LiveParamSignature -Name $mockName)) })
    Assert-Case ('단계 2.4~2.6 모의·감시 서명 = 실제 함수 서명(' + $flowSignatureNames.Count + '개)') ($flowSignatureRows -join ' ') (@($flowSignatureNames | ForEach-Object { '{0}:True' -f $_ }) -join ' ')
    Assert-Case 'K 분류 함수(Resolve-AbyssHandoffStartScreen) 매개변수를 뜻으로 대응함 (명세 2.4 입력 - 하단 판독문 · 패널 · HUD · 추적기 · 3버튼 · 선택 화면 · 메뉴 · 상세 + S)' $classifierProblem ''

    # ② 정적 (주석 뺀 사본 · AST - 명세 ② 3.2 정적 표)
    $memberAt = $workerCode.IndexOf($MEMBER_IF_TEXT, [StringComparison]::Ordinal)
    $clearAt = $workerCode.IndexOf($CLEAR_IF_TEXT, [StringComparison]::Ordinal)
    $blockAt = -1
    $blockConditionText = '(없음)'
    if ($null -ne $startBlock) {
        $blockAt = $startBlock.Extent.StartOffset
        $blockConditionText = Get-NormalizedCode -Node $startBlock.Clauses[0].Item1
    }
    Assert-Case 'R4-P1 2.1 블록 자리 = 파티원 디스패치 if 뒤 · 이벤트 정리 if 앞(IndexOf · 주석 뺀 사본) · 조건에 -not $script:customSpecInvalid' `
        (J @((($memberAt -ge 0) -and ($blockAt -gt $memberAt)), (($blockAt -ge 0) -and ($clearAt -gt $blockAt)), $blockConditionText.Contains('-not $script:customSpecInvalid'))) `
        (J @('True', 'True', 'True'))
    $memberSibling = (@($memberIfIndexes).Count -eq 1) -and (@($blockIndexes).Count -eq 1) -and ($memberIfIndexes[0] -lt $blockIndexes[0])
    $clearSibling = (@($clearIfIndexes).Count -eq 1) -and (@($blockIndexes).Count -eq 1) -and ($clearIfIndexes[0] -gt $blockIndexes[0])
    Assert-Case 'R4-P1 같은 문장 목록(최상위 try 본문)의 형제 순서 - 파티원 디스패치 if < 2.1 블록 < 이벤트 정리 if' (J @($memberSibling, $clearSibling)) (J @('True', 'True'))

    $consumeCallNodes = @($workerAst.FindAll({ param($node) ($node -is [CommandAst]) -and ($node.GetCommandName() -eq 'Consume-Handoff') }, $true))
    $consumeInBlock = @($consumeCallNodes | Where-Object { Test-AstWithin -Node $_ -Ancestor $startBlock })
    Assert-Case 'P21 ① Consume-Handoff 호출 = 워커 전체 1곳 · 그 1곳이 2.1 블록 안' (J @($consumeCallNodes.Count, $consumeInBlock.Count)) (J @(1, 1))
    $clauseCount = 0
    $hasElse = '(없음)'
    $firstStatementText = '(없음)'
    $untilInBlock = -1
    if ($null -ne $startBlock) {
        $clauseCount = $startBlock.Clauses.Count
        $hasElse = [string]($null -ne $startBlock.ElseClause)
        $blockBodyStatements = @($startBlock.Clauses[0].Item2.Statements)
        if ($blockBodyStatements.Count -gt 0) { $firstStatementText = Get-NormalizedCode -Node $blockBodyStatements[0] }
        $untilInBlock = @($startBlock.FindAll({ param($node) ($node -is [AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$script:abyssUntil') }, $true)).Count
    }
    Assert-Case 'P21 ② 2.1 블록 조건 원문(공백 정규화) · 갈래 1 · else 없음' (J @($blockConditionText, $clauseCount, $hasElse)) (J @($BLOCK_CONDITION_TEXT, 1, 'False'))
    Assert-Case 'P21 ③ 2.1 블록 첫 문장(공백 정규화) - 잠금·읽기 실패면 누르기 전 코드 4' $firstStatementText $BLOCK_FIRST_STATEMENT_TEXT
    Assert-Case 'P21 ④ 2.1 블록 안 $script:abyssUntil 대입 0 (⑤ 의 UNTIL 읽기는 블록 앞 최상위 - R3 S4)' $untilInBlock 0

    $firstCallAt = -1
    if ($consumeCallNodes.Count -gt 0) { $firstCallAt = (@($consumeCallNodes | ForEach-Object { $_.Extent.StartOffset }) | Measure-Object -Minimum).Minimum }
    $defaultBeforeCall = ($handoffTop.Count -eq 1) -and ($firstCallAt -gt $handoffTop[0].Extent.StartOffset)
    # 통째 대입은 워커 전체(함수 안 포함)에서 이 기본값 하나뿐입니다(R4 P13 '기본값 대입 1곳' - 함수 안에서 @{ Role = 'none' … } 로 통째 되돌리는 대입은
    #   함수 밖 개수만으로는 보이지 않음, 단계 2.1 검증 지적). 뒤 단계도 필드만 고칩니다(명세 ② 2.2·2.5 의 Nonce·AfterEntry·CleanupOnly·StartScreen 대입)
    Assert-Case 'R4-P13 ① $script:handoff 통째 대입 = 워커 전체(함수 안 포함) 1곳 · 함수 밖 1곳 · 그 자리 스크립트 최상위 · Consume-Handoff 호출보다 앞' `
        (J @($handoffAssigns.Count, $handoffOutside.Count, $handoffTop.Count, $defaultBeforeCall)) (J @(1, 1, 1, 'True'))
    $defaultText = '(대입 없음)'
    if ($handoffTop.Count -eq 1) {
        $defaultValue = Invoke-Expression $handoffTop[0].Right.Extent.Text
        $defaultParts = foreach ($fieldName in @('Role', 'Nonce', 'CleanupOnly', 'FreshEntry', 'StartScreen', 'AfterEntry', 'JournalState')) {
            $field = Get-AbyssJournalField -Object $defaultValue -Name $fieldName
            if (-not $field.Has) { '{0}=(필드 없음)' -f $fieldName }
            elseif ($null -eq $field.Value) { '{0}=null' -f $fieldName }
            elseif ($field.Value -is [bool]) { '{0}={1}(bool)' -f $fieldName, $field.Value }
            else { '{0}={1}' -f $fieldName, [string]$field.Value }
        }
        $defaultText = @($defaultParts) -join ' · '
    }
    Assert-Case 'R4-P13 ② 기본값(명세 2.1 표) - Role none · Nonce 빈 값 · CleanupOnly·FreshEntry 거짓 · StartScreen 빈 값 · AfterEntry null · JournalState ok' $defaultText $HANDOFF_DEFAULT_TEXT
    $roleNoneAssigns = @(Find-WorkerAssignments -Left '$roleNone')
    $roleNoneAt = -1
    if ($null -ne $roleNoneStatement) { $roleNoneAt = $roleNoneStatement.Extent.StartOffset }
    $roleNoneAfterBlock = ($null -ne $roleNoneStatement) -and ($null -ne $startBlock) -and ($roleNoneIndexes[0] -gt $blockIndexes[0]) -and ($roleNoneAt -ge $startBlock.Extent.EndOffset)
    Assert-Case 'R4-P13 ③ $roleNone 대입 = 워커 전체 1곳 · 2.1 블록과 같은 문장 목록(블록 밖 - 모든 실행) · 블록 뒤 · 이벤트 정리 if 앞' `
        (J @($roleNoneAssigns.Count, ($null -ne $roleNoneStatement), $roleNoneAfterBlock, (($roleNoneAt -ge 0) -and ($clearAt -gt $roleNoneAt)))) (J @(1, 'True', 'True', 'True'))
    $roleNoneValues = '(대입 없음)'
    if ($null -ne $roleNoneStatement) {
        $roleNoneBlock = [scriptblock]::Create($roleNoneStatement.Extent.Text)
        $roleNoneValues = (@(foreach ($roleName in @('none', 'own', 'next', 'resume')) {
                    $script:handoff = @{ Role = $roleName }
                    $roleNone = '(미대입)'
                    . $roleNoneBlock
                    '{0}={1}' -f $roleName, $roleNone
                }) -join ' · ')
    }
    Assert-Case 'R4-P13 ④ $roleNone 대입 실행 - Role none 만 참(own·next·resume 거짓)' $roleNoneValues 'none=True · own=False · next=False · resume=False'
    $finishOnlyValues = '(대입 없음)'
    if ($finishOnlyTop.Count -eq 1) {
        $finishOnlyValues = (@(foreach ($finishValue in @('1', '', '0')) {
                    Set-ProcessEnv -Name 'HONEYNOGI_FINISH_ONLY' -Value $finishValue
                    $script:finishOnly = '(미대입)'
                    . $script:workerFinishOnlyReadBlock
                    '[{0}]={1}' -f $finishValue, $script:finishOnly
                }) -join ' · ')
        Set-ProcessEnv -Name 'HONEYNOGI_FINISH_ONLY' -Value ''
    }
    Assert-Case 'R4-P13 보조(명세 2.1 표 run:855 뒤) $script:finishOnly 대입 = 함수 밖 1곳 · 스크립트 최상위 · env 1 만 참' `
        (J @($finishOnlyOutside.Count, $finishOnlyTop.Count, $finishOnlyValues)) (J @(1, 1, '[1]=True · []=False · [0]=False'))

    # ③ 동작 행 - 앞 조건이 갖춰졌을 때만(빠졌으면 위 추출 FAIL 이 이미 찍힘 - 조용히 통과하지 않음)
    $consumeReady = $consumeAvailable -and ($null -ne $script:workerHandoffDefaultBlock) -and ($null -ne $script:workerOwnerReadBlock) -and
        ($null -ne $script:workerRecoveryReadBlock) -and ($null -ne $script:workerRunIdReadBlock)
    $segmentReady = $consumeReady -and ($null -ne $script:mainSegmentBlock)
    $CH_ROW_GROUPS = @(
        @{ Name = 'CH01'; Needs = $consumeReady }, @{ Name = 'CH02'; Needs = $consumeReady }, @{ Name = 'CH03'; Needs = $segmentReady },
        @{ Name = 'CH04'; Needs = $segmentReady }, @{ Name = 'CH05'; Needs = $consumeReady }, @{ Name = 'CH06'; Needs = $consumeReady },
        @{ Name = 'CH08'; Needs = $consumeReady }, @{ Name = 'CH10'; Needs = $consumeReady }, @{ Name = 'CH12'; Needs = $consumeReady },
        @{ Name = 'CH13'; Needs = $consumeReady }, @{ Name = 'CH14'; Needs = $consumeReady }, @{ Name = 'CH15'; Needs = $consumeReady },
        @{ Name = 'CH16'; Needs = $segmentReady }, @{ Name = 'R4L'; Needs = ($consumeReady -and $guiAvailable) })
    foreach ($rowGroup in $CH_ROW_GROUPS) {
        if (-not $rowGroup.Needs) {
            "FAIL 행 묶음 {0} 건너뜀 - 추출 조건이 갖춰지지 않음(위 '추출' FAIL 참고)" -f $rowGroup.Name
            $fails++
            continue
        }
        try {
            & ('Test-Row' + $rowGroup.Name)
        } catch {
            "FAIL 행 묶음 {0} 실행 중 예상 밖 예외: {1}" -f $rowGroup.Name, $_.Exception.Message
            $fails++
        } finally {
            Close-HeldStreams
        }
    }

    # ④ 단계 2.4~2.6 - 정적(P) · 순수 진리표(K·F) · 선분기 루프(층 ①) · 본류 시작 구간(층 ②) · 하니스 단언 · LG(앞 행이 낸 정지 줄을 씀 - 맨 끝)
    $classifierReady = $workerExtracted.Contains('Resolve-AbyssHandoffStartScreen') -and (-not $classifierProblem)
    $stepReady = $workerExtracted.Contains('Step-AbyssFieldSettle') -and ($null -ne $memberFieldSettleSeconds)
    $selectorReady = $segmentReady -and $workerExtracted.Contains('Invoke-AbyssHandoffStart') -and $workerExtracted.Contains('Stop-AbyssHandoffOverlay') -and
        $workerExtracted.Contains('Close-AbyssOwnEntryBeforeEntry') -and $workerExtracted.Contains('Add-AbyssJournalEnteredEntry') -and
        $workerExtracted.Contains('Resolve-AbyssHandoffStartScreen') -and $workerExtracted.Contains('Step-AbyssFieldSettle') -and
        ($null -ne $memberFieldSettleSeconds) -and ($null -ne $memberUnknownOverlaySeconds) -and ($null -ne $capturedTimeoutPartyMatch)
    $flowReady = $selectorReady -and ($null -ne $script:mainFlowBlock) -and ($null -ne $script:preFlowBlock) -and ($null -ne $script:workerRestartReadBlock) -and
        $workerExtracted.Contains('Add-AbyssJournalClearedEntry') -and $workerExtracted.Contains('Test-CustomCleanupOnly') -and $workerExtracted.Contains('Set-AbyssAfterEntryIndex')
    $staticReady = ($null -ne (Get-FlowFunctionNode 'Invoke-AbyssHandoffStart')) -and ($null -ne $memberFieldSettleSeconds)
    $FLOW_ROW_GROUPS = @(
        @{ Name = 'StaticFlow'; Function = 'Test-StaticFlow'; Needs = $staticReady },
        @{ Name = 'K'; Function = 'Test-RowK'; Needs = $classifierReady },
        @{ Name = 'F'; Function = 'Test-RowF'; Needs = $stepReady },
        @{ Name = 'K1'; Function = 'Test-RowK1'; Needs = $selectorReady },
        @{ Name = 'FL'; Function = 'Test-RowFL'; Needs = $selectorReady },
        @{ Name = 'NextSelector'; Function = 'Test-RowNextSelector'; Needs = $selectorReady },
        @{ Name = 'OwnSelector'; Function = 'Test-RowOwnSelector'; Needs = $selectorReady },
        @{ Name = 'LoopSkeleton'; Function = 'Test-RowLoopSkeleton'; Needs = $selectorReady },
        @{ Name = 'NextMain'; Function = 'Test-RowNextMain'; Needs = $flowReady },
        @{ Name = 'OwnMain'; Function = 'Test-RowOwnMain'; Needs = $flowReady },
        @{ Name = 'V18'; Function = 'Test-RowV18'; Needs = $flowReady },
        @{ Name = 'RS0'; Function = 'Test-RowRS0'; Needs = $flowReady },
        @{ Name = 'RoleHarness'; Function = 'Test-RowRoleHarness'; Needs = $flowReady },
        @{ Name = 'LG'; Function = 'Test-RowLG'; Needs = ($staticReady -and $flowReady) })
    foreach ($rowGroup in $FLOW_ROW_GROUPS) {
        if (-not $rowGroup.Needs) {
            "FAIL 행 묶음 {0} 건너뜀 - 추출 조건이 갖춰지지 않음(위 '추출' FAIL 참고)" -f $rowGroup.Name
            $fails++
            continue
        }
        try {
            & $rowGroup.Function
        } catch {
            "FAIL 행 묶음 {0} 실행 중 예상 밖 예외: {1}" -f $rowGroup.Name, $_.Exception.Message
            $fails++
        } finally {
            Close-HeldStreams
        }
    }
} finally {
    # env 되돌림 · 잡은 잠금 정리 · 임시 폴더 통째 삭제(잠금이 남아 못 지우면 핸들 누수라 FAIL)
    Close-HeldStreams
    foreach ($envName in $TOUCHED_ENV_NAMES) { [Environment]::SetEnvironmentVariable($envName, $originalEnv[$envName], 'Process') }
    $cleaned = $false
    for ($attempt = 0; ($attempt -lt 10) -and (-not $cleaned); $attempt++) {
        try {
            if ([IO.Directory]::Exists($testRootFolder)) {
                foreach ($leftFile in [IO.Directory]::GetFiles($testRootFolder, '*', [IO.SearchOption]::AllDirectories)) { [IO.File]::SetAttributes($leftFile, [IO.FileAttributes]::Normal) }
                [IO.Directory]::Delete($testRootFolder, $true)
            }
            $cleaned = $true
        } catch {
            [System.Threading.Thread]::Sleep(200)
        }
    }
    if (-not $cleaned) {
        "FAIL 임시 폴더 정리 실패(잡힌 핸들이 남았을 수 있음): $testRootFolder"
        $fails++
    }
}
exit $fails
