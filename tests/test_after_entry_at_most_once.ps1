# 입장 직후 키 at-most-once 회귀 ⑳ - 구현 명세 ② 2.2·2.3·2.5·2.6·2.7·3.3 (2026-10-13 신설 · 같은 날 2.5·2.6 행 · 2026-10-14 단계 2.7 의 OK13)
#
# 지키는 것 (명세 ② 2.2 · 2.3 '회귀(이 단계)' 의 ⑳ 몫. 기대값은 명세 ② 2.2·2.3 표 · 3.3 행 표 · 설계 v11 R2 3.2~3.6·5.2 표의 글자 그대로 - '제안' 문구는
# 구현이 바꾸면 이 파일의 상수도 함께, 명세 머리말):
#   [AE] 키 인덱스 계약(2.2 ⓐⓑⓒ · dev:926~929): AE0 정상 판 Space·B 정확히 1 · AE1 crash 6지점 × 워커 2대(본류 층) · AE2 인덱스 기록 locked · AE3 keys 불일치 ·
#        AE4 전면 확인 실패 · AE5 expect-failed · AE6 열쇠 항목 없음 · AE7 빈 키 목록(본류 층) · AE8 계약 없는 호출 · AE9 저장 예외 전파.
#        키 행은 전부 '판당 B ≤ 1 · Space ≤ 1' 을 함께 봅니다(행 합계 = 그 판을 돈 워커 전부의 누른 키).
#   [SE] 자기 항목 entered · cleared 의 열쇠 닫기(2.2 표 · 0.6 J2·J4 · dev:874·875·930): SE1~SE12
#   [R2] 코드 10 출구의 열쇠 닫기(2.3 표 · 설계 R2 3.2~3.6·5.2): R2-L1~L4 · C1~C3 · F1·F2 · E1·E2·E5~E9 · N1·N2
#        + 단계 2.5·2.6(정리 전용 표지를 받은 own · own 이어받기 뒤 닫기 - 설계 R2 5.2 · 3.3a): R2-C4~C8 · E3 · E4 · L2·C2 의 다음 기동(own · 선택 화면 → 1회 정지)
#   [OK] 이어받기 시작 경로의 키 사슬(명세 3.3 OK 표 · 단계 2.5·2.6 - 선분기 Invoke-AbyssHandoffStart · 본류 결론 대입 · own 시작 분기 cleared): OK1~OK12 ·
#        단계 2.7(5절 A-2 R-6 (나) - own 기동의 클리어 전 정지는 넘긴 nonce 를 열어 둠): OK13. OK2~OK7 은 설계 R4 6.2 의 키 변형(O2 · O3 · O4·O4″ · O7′·O7″ ·
#        O11 · O14 - 앞의 둘은 수용 고정), OK11~OK13 의 GUI 끝 처리는 ⑯ (GUI 틱) KP1~KP3 이 단언하는 결과(넘긴 nonce launched 유지)를 같은 journal 모양으로
#        둡니다(명세 3.3 - GUI 판정 자체는 ⑯ 몫. OK13 의 재시도·정지 갈래는 GUI 원문 Get-CustomErrorAction 으로 고릅니다)
#   [TC] 결합 층(명세 3.3 - 본류 조각 + 실제 최상위 catch 본문. 코드 1 · 오류 세트는 이 층에서만 봅니다): TC0~TC3
#   [S]  정적(주석 뺀 사본 · AST): 설계 R2 5.4 S1~S5 · 명세 3.3 S8 · S10 · 본류 층·결합 층 추출 단언(exit 치환 수 · run:18527 if 참 갈래 문장 1개)
#   [보강] 위 표 문장에서 바로 나오는 짝 행(이름 끝 n·m·′·s): AE0n(next 열쇠의 첫 기록 - 2.2 표 'keys 가 null 이면 keys·total 먼저') · AE2m·AE3m(같은 주입을
#        본류 층에서 - 키 지점의 'stop' → exit 4 / 'skipped' → 판 계속) · AE7′(키 1개 배열의 JSON 왕복 - 명세 5절 B3) · R2-L1s(screen·reason 이 없는 옛 항목의
#        닫기 - 설계 R2 5.2 L1 둘째 문장) · AE3′(2.2 ⓐ '개수·순서·값' 의 순서만 다름 · 개수 같고 값 다름 · 빈 기록 목록 - AE3 은 개수 차이만) · R2-L2s(2.3 표 닫기 실패
#        문구의 나머지 두 종류 - io-failed '기록 실패' · corrupt '파일 손상' 안내 꼬리 없음, L2·C2 는 locked 만)
# 하니스 다섯 층(명세 3.3):
#   ① 키 층    실제 Invoke-AfterEntryKeys(-KeyContract) · 실제 자기 항목 생성·인덱스 기록 · 저장소 워커 사본 · 임시 폴더 파일. 키 목록은 워커 원문의 해석 문장
#              (run:1846~1870)을 픽스처 config(config.json 과 같은 두 키)로 그대로 돌린 $afterEntryActions. 열쇠는 실제 생성 또는 실제 Consume-Handoff 가 채웁니다
#   ② 루프 층  실제 Return-ToAbyssSelection(exit 7곳 → 'WORKER-EXIT:' 예외) · 화면 모형 · 가상 시계 · 닫기 함수 기록 스텁(호출·인자·Remove-Item/exit 순서).
#              부르는 문장은 본류 'left' 블록의 원문 호출 문장 그대로입니다(그 문장의 -LeaveEntryReason 을 함께 지남)
#   ③ 저장소 층 실제 Close-AbyssKeyEntryOnLeave · Add-AbyssJournalEnteredEntry · Add-AbyssJournalClearedEntry 직접 호출 + 실제 저장소 + 임시 폴더 파일
#   ④ 본류 층  워커 최상위 try 의 형제 문장 [2.1 블록 ~ run:18527 if 앞](시작 구간 A)과 [키 지점 블록 ~ try 끝](조각 B)을 AST 로 잘라 exit 토큰을 뒤에서부터
#              Stop-WorkerTailExit('WORKER-EXIT:N' 예외)로 바꿔 점소싱합니다. 사이의 run:18527 if 는 건너뜁니다 - 참 갈래 = 로그 1줄(정적 단언으로 모양 고정),
#              거짓 갈래 = 카드 클릭·입장 흐름(이 하니스는 '선택 화면 시작 → 카드 → 입장' 을 일어난 것으로 봄). 앞 변수는 운영 대입과 같은 식(env 읽기 · 기본값 ·
#              $startExitDetected 문장을 원문 그대로). 다음 기동은 GUI 원문 기동 env(Set-HandoffLaunchEnv → Resolve) + 실제 Consume-Handoff, 코드 10·4 뒤의 GUI
#              끝 처리는 GUI 원문 Complete-AbyssExitJournal(명세 3.3 저장소 층 '다음 기동'), 수동 시작의 시작 게이트는 GUI 원문 S3(Get-AbyssStartJournalAction - OK1·OK11).
#              Role≠none 기동은 시작 구간 A 안에서 실제 선분기(Invoke-AbyssHandoffStart - 분류 순수 함수·필드 확정·정지 함수·own 닫기·ownFreshEntry 생성 전부 실제)를
#              지납니다 - 화면은 아래 화면 모형(+ 행이 정하는 시간표: 가상 시계 초 → 화면, 대기 모의가 시계를 밀 때 적용)이고 판독 모의는 그 화면의 하단 판독문
#              (실측 모양)을 S 판정의 스태시에 둡니다(선분기의 순수 서명 함수 Test-AbyssRewardText·Test-AbyssEntryWaitingText·Test-AbyssFewMembersPopupText 는 실제)
#   ⑤ 결합 층  ④ 의 두 조각을 실제 최상위 catch 본문(중괄호 안쪽 원문)과 'try { <조각> } catch { <하니스 문장 1> <catch 본문> }' 한 블록으로 점소싱. 하니스 문장
#              (WORKER-EXIT 예외만 다시 던짐)이 조각 안 exit 4·10 이 catch 를 지나 코드 1 로 바뀌는 것을 막습니다(명세 2.0-8). 가상 시계는 -Format 을 처리합니다
# 공통: 같은 프로세스에서 도는 추출 함수·조각은 exit 를 치환하고 '원본 Exit 토큰 수 = ExitStatementAst 수 = 치환 수 · 치환 뒤 0' 을 동작 행보다 먼저 단언합니다.
#   클로저 mutator 가 부르는 함수는 최상위 정의만 보이므로 추출·감시·모의는 전부 이 파일 최상위에서 정의합니다(test_abyss_journal_store:12~14). 주입은 'N번째 호출
#   throw' 갈고리를 그 저장에만 겁니다(생성 = Test-AbyssJournalOwnerMatch · R2 닫기 = Set-AbyssJournalProperty(launchState·reason·screen) · 인덱스 = 직렬화
#   ConvertTo-AbyssJournalText - 명세 3.3). 감시는 실제 함수를 Invoke-Real<이름> 으로 두고, 같은 이름은 실제 매개변수 블록을 그대로 복사한 얇은 감시입니다.
#   첫 기동의 handoff env 는 GUI 기동 함수 없이 직접 둡니다(후보 없는 기동 · 일부 행은 일부러 stale nonce) - GUI 가 고르는 다음 기동만 GUI 원문으로 지납니다.
# 단계 2.5·2.6 에서 더한 것(명세 3.3): 선분기를 지나는 화면 모형(준비·재매칭 패널 · 권장 인원 팝업 · 접힌 패널 · 상세 화면 · 로딩 = 알 수 없음 · 시간표) ·
#   AE1·AE3m·AE7·SE1·R2-E1 의 두 번째 기동(own · 던전 안)은 행 그대로 선분기 결론 '던전 안' 을 지납니다 · R2-L2·C2 에 다음 기동의 선택 화면 1회 정지 ·
#   OK1~OK12 · R2-C4~C8 · R2-E3 · R2-E4. S7(개정 - 생성 자리 2 · $cleanupByScreen 식)은 R4 P9 와 한 단언이라 test_abyss_handoff_start P9 에만 둡니다(같은 단언 두 곳 금지).
# 단계 2.7 에서 더한 것(명세 3.3 OK13 · 2.7 G5 · 5절 A-2 R-6 (나)): OK13 - 클리어 대기 모의 'error'(코드 1 흉내 예외 - 본류 조각 밖으로 전파) · GUI 원문
#   Get-CustomErrorAction(오류 대응 판정 - 재시도 2회 → 3회째 정지). 명세 3.3 의 ⑳ 행은 이것으로 전부입니다.
# 구현 명세 ⑤b5 에서 더한 것(3.1 ⑳ · 3.4): 'left' 추출이 [완료] 쓰기 둘(if 밖 준비 실행 줄 · 마무리 실행 if 안 줄)을 각각 캡처 · R2-S2 의 'left' 안전 중지 코드 식 ·
#   R2-F3(구현 단위 복귀 연장 - 마감 뒤 안전 중지: 닫기 0 · 호출부 코드 · 갈래 줄 · 루프 층) · R2-D1(같은 단위 - 실제 Write-LifeDiagnostics 의 로그 사본) ·
#   R2-L5(마무리 실행 'left' → 코드 4 · 본류+루프 층) · R2-L6(같은 판 두 출구(W 확정 뒤 · 출처 완료 시점) F9 → 코드 4 · 거점 퇴장 문구(명세 리뷰 2 RV-9) · 루프 층) · R6-RC1 워커 쪽(워커 2대 - 'other' 끝 안 끊김 → 복구 워커의 완료 기록
#   읽기 0 · 선택 화면 진단 + 코드 4). 본류 꼬리의 두 끝 함수는 모의입니다(R6-RC1 만 'other' 끝에 닿음 - 다른 행은 모드 입력이 없어 경로 거짓 = 옛 나가기).
# 구현 명세 ⑤b6 에서 고친 것(3.4 ⑳ - 다음 항목의 입장 방식이 다르거나 다음 항목이 없으면 결정 'entry-change' → 옛 나가기): R6-RC1 의 결정 사유 switch 캡처를 대입 대상
#   $otherCause 로 고름('exit' 갈래에 원인 조각 switch 둘이 더해짐) · R6-RC1 의 다음 항목 입력 두 줄(env HONEYNOGI_CUSTOM_NEXT = 픽스처 1번 토큰 · 워커 $script:customNext = 그 토큰 해석 -
#   비우면 'entry-change' 라 'other' 끝에 닿지 않음) · 픽스처 1번을 같은 입장 방식(혼자하기)의 다른 던전으로(⑯ 과 같음).
# 다른 파일이 지키는 것: 새 워커 journal 함수의 자리·모양(묶음 끝 표지 뒤 · exit·try 0 · 클로저 수 · 'Changed' 모양 - S9) = test_abyss_journal_store W-ONLY ·
#   Invoke-AfterEntryKeys 원문 제약(함수 이름 두 개 · 첫 숫자 대기 1200) = test_after_entry_popup · test_guard_constants · 고정 단언 갱신(명세 3.4) = 각 파일.
using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing   # GUI 함수의 정지 갈래가 상태줄 색을 씁니다 - 그 갈래로 새면 예외가 아니라 FAIL 로 보이게
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$UTF8_BOM = New-Object System.Text.UTF8Encoding($true)
$UTF8_PLAIN = New-Object System.Text.UTF8Encoding($false)

# ===== 상수 =====
$BUNDLE_HEADER_FRAGMENT = '어비스 완료 기록(handoff journal) 저장소'   # 저장소 묶음 머리 주석 (test_abyss_journal_store 와 같은 경계)
$BUNDLE_END_FRAGMENT = '어비스 완료 기록 저장소 묶음 끝'                 # 저장소 묶음 끝 표지 주석
$WORKER_EXIT_PREFIX = 'WORKER-EXIT:'                                     # 종료 흉내 예외 접두 (⑯ Stop-WorkerTailExit 와 같은 모양 - 명세 2.0-8)
$HARNESS_RETHROW_TEXT = "if ([string]`$_.Exception.Message -like '${WORKER_EXIT_PREFIX}*') { throw }"   # 결합 층 catch 머리의 하니스 문장 (명세 3.3)
$HARNESS_RETHROW_CONDITION = "[string]`$_.Exception.Message -like '${WORKER_EXIT_PREFIX}*'"
$HALT_MESSAGE = 'ROW-HALT'      # 클리어 대기 모의가 '이 행의 관심 구간 끝' 에서 던지는 표지 - 본류 층 전용(결합 층 행은 쓰지 않음)

# 워커에서 꺼내 실제로 돌리는 함수. 이 함수들과 본류 두 조각·최상위 catch 본문이 부르는 워커 최상위 함수는 아래 의존 추출이 따라 붙입니다
$WORKER_FUNCTION_NAMES = @(
    'ConvertTo-AbyssJournalOwner', 'Add-AbyssJournalClearedEntry', 'Consume-Handoff', 'Add-AbyssJournalEnteredEntry', 'Set-AbyssAfterEntryIndex',
    'Close-AbyssKeyEntryOnLeave', 'Invoke-AfterEntryKeys', 'Get-KeyDisplayName', 'Return-ToAbyssSelection', 'Write-CustomClearMarker',
    'Test-CustomCleanupOnly', 'Format-AbyssCustomItemLabel', 'ConvertFrom-AbyssCustomItemSpec', 'Get-ConfigInteger', 'Get-ConfigValue',
    'Resolve-ConfigInteger', 'Resolve-ConfigBoolean', 'Get-CaptureFailTotalMs', 'Test-SafeStopDuringCaptureFail',
    # 단계 2.4·2.5 (명세 2.4·2.5 - 선분기 루프 · 정지 함수 · own 닫기 · 순수 함수 둘). 2.1 블록이 Role≠none 에서 선분기를 부르므로 의존 추출도 따라가지만,
    # 빠졌을 때 '추출' FAIL 로 드러나게 이름으로도 둡니다
    'Invoke-AbyssHandoffStart', 'Stop-AbyssHandoffOverlay', 'Close-AbyssOwnEntryBeforeEntry', 'Resolve-AbyssHandoffStartScreen', 'Step-AbyssFieldSettle')
# 감시 - 실제 함수는 Invoke-Real<이름>, 같은 이름은 실제 매개변수 블록을 복사한 얇은 감시(호출 기록 · 갈고리 · 스텁)
$WORKER_SPY_NAMES = @('Consume-Handoff', 'Add-AbyssJournalEnteredEntry', 'Set-AbyssAfterEntryIndex', 'Close-AbyssKeyEntryOnLeave',
    'Invoke-AfterEntryKeys', 'Add-AbyssJournalClearedEntry', 'Return-ToAbyssSelection')
# 단계 2.5 의 감시(own 닫기 화면 · 정지 종류) - 따로 둡니다: 빠지면 그 행 묶음(선분기 행)만 건너뛰고 2.2·2.3 행은 그대로 돕니다
$HANDOFF_SPY_NAMES = @('Close-AbyssOwnEntryBeforeEntry', 'Stop-AbyssHandoffOverlay')
$BUNDLE_SPY_NAMES = @('Read-AbyssJournal', 'Update-AbyssJournal', 'Write-AbyssJournalTempFile', 'ConvertTo-AbyssJournalText',
    'Set-AbyssJournalProperty', 'Test-AbyssJournalOwnerMatch')
# 모의(화면·입력·대기·클리어 대기 - 아래 '서명 대조' 로 실제 서명과 맞춤)
$WORKER_MOCK_NAMES = @(
    'Write-RunLog', 'Press-KeyVerified', 'Move-CursorOutsideGame', 'Find-GameTextPoint', 'Focus-Game', 'Click-ScreenPoint', 'Click-GamePoint',
    'Press-KeyOnce', 'Wait-UserYieldEnd', 'Test-UserRecentlyActive', 'Test-CaptureRecovered', 'Write-LifeDiagnostics', 'Get-AbyssPanelKind',
    'Test-AbyssEntryWaiting', 'Test-AbyssSelectionScreen', 'Test-AbyssMenu', 'Test-HomeEndEscHud', 'Test-InDungeonQuest', 'Test-ExitButton',
    'Test-NoticeBoardPopup', 'Invoke-EventSkipOrConfirm', 'Get-GameRegionOcrText', 'Close-GhostRegisterPrompt', 'Find-AbyssMenuIconPoint',
    'Invoke-AutoRefocus', 'Invoke-AbyssExitClick', 'Wait-ForDungeonClearScreen', 'Invoke-ClickUntil', 'Test-DungeonClearPrompt',
    'Clear-EventOverlay', 'Test-DungeonEntered', 'Invoke-PurchasePopupSweep', 'Test-AbyssKnownDetailScreen',
    # 구현 명세 ⑤b5 - 본류 보상 화면 꼬리의 두 끝(R6-RC1 의 'confirmed' 뒤 끊김 · 그 밖 닿지 않음 - 아래 모의 머리 주석)
    'Complete-AbyssOtherSelection', 'Complete-AbyssRetrySelection')
$CMDLET_OVERRIDE_NAMES = @('Start-Sleep', 'Get-Date', 'Test-Path', 'Remove-Item')
# 이 하니스의 모형으로는 닿지 않는 갈래의 함수(던전·사냥터 흐름 · 마무리 복구 상세 · 창 진단) - 의존 추출이 따라가지 않습니다. 행이 이 갈래로 새면
# '인식되지 않는 명령' 예외가 행 FAIL 로 드러납니다(조용히 통과하지 않음)
$NOT_REACHED_NAMES = @('Invoke-NormalDungeonCycle', 'Invoke-HuntingGroundCycle', 'Get-DetailTitleText', 'Invoke-AbyssBackRefocus',
    'Get-DgStageEnterButtonText', 'Get-GameOcrText')
$TEST_DEFINED_NAMES = @($WORKER_MOCK_NAMES + $CMDLET_OVERRIDE_NAMES + @('Stop-WorkerTailExit'))
# GUI 원문 함수 - 다음 기동 env(Set-HandoffLaunchEnv · Resolve) · 코드 10·4 끝 처리(Complete-AbyssExitJournal)와 그 의존
$GUI_FUNCTION_NAMES = @(
    'Set-HandoffLaunchEnv', 'Resolve-HandoffEnvForContext', 'Clear-HandoffEnv', 'Test-AbyssHandoffRunActive', 'Test-AbyssMemberRunActive',
    'Get-CustomCanonicalOwner', 'Get-CustomFingerprint', 'Get-CustomOrderKey', 'Format-CustomItemToken', 'ConvertTo-CustomMarkerOwnerJson',
    'New-CustomMarkerOwnerJson', 'Get-AbyssJournalLockedGuide', 'Get-AbyssJournalCorruptGuide', 'Get-InsideHandoffStopReason',
    'Complete-AbyssExitJournal', 'Get-AbyssExitStopReason',
    # 수동 시작의 시작 게이트 S3(OK1·OK11 - 이어받을 클리어·재개 기록이 없으면 none: 마무리 복구·재개 예약 없이 일반 기동으로)
    'Get-AbyssStartJournalAction', 'Read-AbyssStartJournal', 'Get-AbyssStartJournalRefusal',
    # 커스텀 코드 1 의 오류 대응 판정(OK13 - 마커 없으면 같은 항목 재시도 2회 → 3회째 정지, gui:11161~11211 의 Get-CustomErrorAction)
    'Get-CustomErrorAction')
$GUI_SPY_NAMES = @('Resolve-HandoffEnvForContext')
$GUI_MOCK_NAMES = @('Add-GuiLog', 'Stop-AllRun', 'Get-CustomCurrentContext')

# 로그 줄 - 명세 ② 2.2·2.3 표 글자 그대로('제안' = 원천에 문구가 없어 명세가 붙인 것 - 구현이 바꾸면 여기도 함께, 명세 머리말 · 5절 B19)
$LINE_ENTERED_SAVED = '[어비스] 입장 기록 저장 (입장 직후 키 전)'                                                                       # 2.2 표 생성 성공 줄 (제안 - 파일 전용 H11)
$LINE_ENTERED_FAILED = '[완료] 입장 기록 실패 - 재화 중복 소모를 막기 위해 입장 직후 키를 보내지 않고 정지합니다 (캐릭터는 던전 안)'       # 2.2 표 키 지점 (dev:874 - 꼬리 0)
$LINE_KEYS_MISMATCH = '[경고] 입장 직후 키 목록이 기록과 달라 키를 보내지 않습니다'                                                     # 2.2 ⓐ (dev:927)
$FORMAT_KEY_RECORD_FAILED = '[완료] 입장 직후 키 입력 기록 실패 - 재화 중복 소모를 막기 위해 남은 키를 보내지 않고 정지합니다 ({0}/{1}, 캐릭터는 던전 안)'   # 2.2 ⓑ (dev:879)
$FORMAT_KEY_ALREADY_SENT = '{0} {1} - 이전 실행이 이미 보낸 키라 다시 보내지 않습니다 ({2})'                                            # 2.2 ⓑ (제안 - 창에 보임)
$FORMAT_KEY_SENT = '{0} {1} ({2} 키 입력완료)'                                                # 2.2 ⓑ '로그 run:7699/7701 그대로' - HEAD 형식
$FORMAT_KEY_SKIPPED = '{0} {1} - 게임 전면을 확인하지 못해 키 입력을 건너뜀 ({2})'             # 같은 이유(HEAD run:7701)
$FORMAT_CLOSE_DONE = '[어비스] 던전을 나온 판의 기록을 닫았습니다 - 다음 시작은 새 판으로 들어갑니다 ({0})'                              # 2.3 표 (설계 R2 3.6 - GUI 숨김 H6)
$FORMAT_CLOSE_FAILED = '[경고] 던전을 나온 판의 기록을 닫지 못했습니다 ({0}) - 다음 시작이 선택 화면에서 멈추면 필드에서 다시 시작해 주세요'  # 2.3 표 locked·io-failed
$LINE_CLOSE_CORRUPT = '[경고] 던전을 나온 판의 기록을 닫지 못했습니다 (파일 손상)'   # 2.3 표 corrupt - 안내 꼬리 없음(설계 R2 3.6)
$CLOSE_SUCCESS_FRAGMENT = '던전을 나온 판의 기록을 닫았습니다'   # S3 - 닫기 성공 줄을 쓰는 문장
$CLOSE_LINE_FRAGMENT = '던전을 나온 판의 기록을'                 # 닫기 줄(성공·실패) 공통 조각 - '닫기 로그 0' 단언
$LINE_CONSUME_CORRUPT = '[경고] 완료 기록 파일이 손상돼 이어받을 기록을 확인하지 못했습니다 - 이번 판은 입장 직후 키를 보내지 않습니다'    # 2.1 표 ⑤
$LINE_CLEARED_SAVED = '[어비스] 클리어 완료 기록 저장 (결과 화면 도달)'                                       # 2.2 표 '새 로그 줄 0 유지' - HEAD 원문
$FORMAT_CLEARED_FAILED = '[경고] 클리어 완료 기록을 저장하지 못했습니다 ({0}) - 정상 종료면 GUI가 종료 코드로 계상하므로 진행을 계속합니다'
# 이어받기 시작 선분기의 줄 - 명세 ② 2.5 '선분기 로그 줄' 표(S1~S20) 글자 그대로(원천: S3·S4 설계 R4 3.7 · S6 dev:595 · S10·S12 dev:907 / 제안: S5·S8·S14 -
# 구현이 바꾸면 여기도 함께). 계측 줄(S1·S2)은 표본 수가 시각 따라 달라 머리만 셉니다. 정지 문구 전체·꼬리 규칙은 test_abyss_handoff_start LG·P22 가 봅니다
$LINE_START_MEASURE_PREFIX = '[어비스] 이어받기 시작 계측 - 던전 안 2연속 앞 알 수 없음 '                                                 # S1 (R4 3.7 - GUI 숨김 H9)
$LINE_ENTRY_MEASURE_PREFIX = '[어비스] 입장 계측 - 던전 안 2연속 앞 로딩(알 수 없음) '                                                     # S2 (R4 3.7 - GUI 숨김 H8)
$FORMAT_FIELD_SETTLED_PREFIX = '[어비스] 이어받기 시작: 던전 밖(HUD) 확인 - 필드 모양이 {0}초 이어졌습니다 (첫 표본부터 '                     # S3 (R4 3.7 - 뒤 '초, 표본' 은 시각 따라)
$FORMAT_OWN_CLOSE_DONE = '[어비스] 시작 화면이 던전 밖이라 이어받던 판의 기록을 닫았습니다 - 새 판으로 들어갑니다 (abandoned-pre-entry-start · {0})'   # S4 (R4 3.7 - GUI 숨김 H7)
$FORMAT_OWN_CLOSE_FAILED = '[경고] 이어받던 판의 기록을 닫지 못했습니다 ({0}) - 새 판의 기록이 남은 기록을 함께 닫습니다'                        # S5 (제안 - 낱말 설계 R2 3.6 · 명세 B9)
$LINE_OWN_FRESH_ENTRY = '[어비스] 이어받은 항목 없이 새 입장 확인 - 새 판으로 진행합니다 (ownFreshEntry)'                                     # S6 (dev:595 - 꼬리 숨김 H5)
$FORMAT_EVENT_CLEANUP = '[안내] 이어받기 시작: 알 수 없는 화면이 {0}초 이어져 이벤트 화면 정리를 한 번 시도합니다'                               # S8 (제안 - {0} = 소스의 30초 상수)
$LINE_OVERLAY_SELECTION_OWN = '[완료] 이어받은 판의 시작 화면이 어비스 선택 화면입니다 - 던전 안 오버레이일 수 있어 안·밖을 확인하지 못해 조작 없이 정지합니다. 화면을 확인하고(오버레이면 닫고, 던전 안이면 그 판을 마친 뒤) 다시 시작해 주세요. 던전 밖이면 선택 화면을 닫아 필드(HUD 가 보이는 곳)에서 다시 시작해 주세요 (selection-overlay)'   # S10 (dev:907)
$LINE_OVERLAY_MENU_OWN = '[완료] 이어받은 판의 시작 화면이 ESC 메뉴입니다 - 메뉴가 화면을 가려 안·밖을 확인하지 못해 조작 없이 정지합니다. 메뉴를 닫고(던전 안이면 그 판을 마친 뒤, 던전 밖이면 필드에서) 다시 시작해 주세요 (menu-overlay)'   # S12 (dev:907)
$LINE_OVERLAY_DETAIL_OWN = '[완료] 이어받은 판의 시작 화면이 어비스 던전 상세 화면입니다 - 던전 안에 겹친 화면일 수 있어 안·밖을 확인하지 못해 조작 없이 정지합니다. 화면을 닫고 필드(HUD 가 보이는 곳)에서 다시 시작해 주세요 (던전 안이었다면 닫은 뒤 그 자리에서 다시 시작해도 됩니다) (selection-overlay)'   # S14 (제안 - 사용자 결정 U2 · 5절 A-2 R-3)
# 클리어 대기 불명 마감의 [완료] 줄(OK11 - 표지 없는 클리어 전 코드 4) - 워커 원문(Wait-ForDungeonClearScreen 의 '필드 상태 확인' 문구)에서 캡처합니다(아래 추출)
$CLEAR_WAIT_UNKNOWN_FRAGMENT = '[완료] 클리어 대기 한도 안에 클리어를 확인하지 못했습니다 (필드 상태 확인'
# 2.2·2.3 이 바꾸지 않는 HEAD 원문 줄(복귀 루프·본류 끝·최상위 catch)
$LOOP_SAFE_STOP_FIELD_LINE = '[완료] 안전 중지 예약 확인 - 준비/정리 실행 중이라 회차로 세지 않고 마칩니다'
$LOOP_SAFE_STOP_SELECTION_LINE = '[완료] 안전 중지 예약 확인 - 선택 화면 복귀 완료, 준비/정리 실행이라 회차로 세지 않고 마칩니다'
# 구현 명세 ⑤b5 명세 리뷰 2 RV-9 - 마무리 실행 'left'(거점 퇴장 - 코드 4)의 복귀 루프 안전 중지 두 출구 줄(리뷰 문안 그대로 - 계약) · 그 갈래 전 옛 줄(HEAD 원문 - 그 판에서 0)
$LOOP_SAFE_STOP_LEFT_FIELD_LINE = '[완료] 안전 중지 예약 확인 - 거점 퇴장한 판은 회차로 세지 않고 던전 밖(HUD) 확인 시점에서 마칩니다'
$LOOP_SAFE_STOP_LEFT_SELECTION_LINE = '[완료] 안전 중지 예약 확인 - 거점 퇴장한 판은 회차로 세지 않고 선택 화면 복귀 완료 시점에서 마칩니다'
$LOOP_SAFE_STOP_ROUND_FIELD_LINE = '[완료] 안전 중지 예약 확인 - 던전 밖(HUD) 확인 시점에서 회차를 마칩니다'
$LOOP_SAFE_STOP_ROUND_SELECTION_LINE = '[완료] 안전 중지 예약 확인 - 선택 화면 복귀 완료 시점에서 회차를 마칩니다'
# 구현 단위 복귀 연장 1.5 - 마감 뒤 안전 중지 세 갈래 줄(명세 문안 그대로 - 계약. 소스 갈래 글자와 같은지는 R2-L6 이 봅니다)
$LOOP_SAFE_STOP_EXPIRED_LINE = '[완료] 안전 중지 예약 확인 - 복귀 대기 시간 안에 화면 복귀를 확인하지 못해 이 시점에서 회차를 마칩니다. 게임 화면을 확인해 주세요'
$LOOP_SAFE_STOP_EXPIRED_READY_LINE = '[완료] 안전 중지 예약 확인 - 복귀 대기 시간 안에 화면 복귀를 확인하지 못했고 준비/정리 실행이라 회차로 세지 않고 마칩니다. 게임 화면을 확인해 주세요'
$LOOP_SAFE_STOP_EXPIRED_LEFT_LINE = '[완료] 안전 중지 예약 확인 - 복귀 대기 시간 안에 화면 복귀를 확인하지 못했고 거점 퇴장한 판은 회차로 세지 않고 마칩니다. 게임 화면을 확인해 주세요'
$LOOP_EXPIRED_DIAG = '어비스 복귀 마감 안전 중지|True|True'
$LOOP_MENU_UNPROVEN_LINE = '[완료] 선택 화면 복귀 중 필드를 확인하지 못한 채 메뉴가 계속 열려 있어 자동 조작을 중단합니다 (던전 안일 수 있음). 화면을 확인하고 다시 시작해 주세요.'
$LOOP_INSIDE_STOP_PREFIX = '[완료] 선택 화면 복귀 중 던전 안 상태(HUD + 던전 목표)를 확인해 자동 조작을 중단합니다'
$LOOP_FIELD_CONFIRM_PREFIX = '[어비스] 던전 밖(HUD) 확인'
$CAPTURE_F9_LINE = '[완료] 화면 캡처 실패가 2분 이상 지속 - 안전 중지 예약을 확인해 자동화를 마칩니다 (회차 미완료)'
$MAIN_RETURN_DONE_LINE = '[완료] 어비스 선택 화면 복귀 완료'
$READY_RETURN_DONE_LINE = '[완료] 어비스 선택 화면 복귀 완료 (준비 실행 - 회차로 세지 않음)'   # 본류 필드 분기·ESC 메뉴 분기 끝(HEAD 원문)
$CLEAR_WAIT_START_LINE = '[어비스] 클리어 화면 감지 대기 시작'
$LEFT_LINE_FRAGMENT = '던전을 나왔습니다'
$ERROR_LINE_PREFIX = '[오류] '
$DIAG_COPY_PREFIX = '[진단] 오류 로그 사본 저장: '
# 주입 메시지(최상위 catch 의 '[오류] <메시지>' 로 그대로 나옵니다)
$INJECTED_OWNER_MATCH = 'INJECTED-OWNER-MATCH 생성 mutator 예외 주입'
$INJECTED_PROPERTY = 'INJECTED-SET-PROPERTY 닫기 mutator 예외 주입'
$INJECTED_SERIALIZE = 'INJECTED-SERIALIZE 인덱스 기록 저장 예외 주입'

# 픽스처
$ABYSS_SECTION = 'abyssCustomRepeat'
$CONTEXT_GENERATION = 3     # 0 이 아니어야 세대를 빠뜨린 대조가 드러남 (⑱′ 와 같은 이유)
$ROW_RUN_ID = 'run-at-most-once'
$FIXTURE_KEYS = @(@{ Key = 32; Label = '자동출발' }, @{ Key = 66; Label = '음식 자동 먹기' })   # config.json afterEntry.keys 와 같은 두 키
$NONCE_A = 'a0000000-0000-4000-8000-00000000000a'
$NONCE_B = 'b0000000-0000-4000-8000-00000000000b'
$NONCE_C = 'c0000000-0000-4000-8000-00000000000c'
$NONCE_D = 'd0000000-0000-4000-8000-00000000000d'
$NONCE_S = 'e0000000-0000-4000-8000-00000000000e'
$FIXTURE_NONCE_LABELS = @{ $NONCE_A = 'NA'; $NONCE_B = 'NB'; $NONCE_C = 'NC'; $NONCE_D = 'ND'; $NONCE_S = 'NS' }
$CORRUPT_MAIN_TEXT = '{"version":1,"seq":'   # 본 파일 손상 픽스처
$CORRUPT_BAK_TEXT = 'not json'               # 직전본 손상 픽스처
$BAK_MARKER_SAVED_BY = 'bak-marker'          # N1·N2 - 쓰기가 일어나면 직전본이 본 파일 내용으로 바뀌어 이 표지가 사라짐(설계 R2 5.2 N1)
# 커스텀 목록 (GUI 원문 함수가 토큰·지문·소유자 JSON 을 만듭니다 - 0번 · 1번 항목은 워커 토큰 해석이 받는 던전·난이도). 구현 명세 ⑤b6(3.4 ⑳): 1번은 0번과 같은 입장 방식
# (혼자하기)의 다른 던전 - R6-RC1 의 '다른 던전 가기'(item-change) 꼴입니다(입장 방식이 다르면 'entry-change' → 옛 나가기 - ⑯ 과 같은 픽스처)
$ABYSS_ITEMS = @(
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '입문'; dungeon = '흩어진 물길'; matching = '' })
$TOUCHED_ENV_NAMES = @('HONEYNOGI_HANDOFF_NONCE', 'HONEYNOGI_RESUME_REENTRY', 'HONEYNOGI_FINISH_ONLY', 'HONEYNOGI_CUSTOM_ITEM', 'HONEYNOGI_CUSTOM_OWNER',
    'HONEYNOGI_CUSTOM_RESTART', 'HONEYNOGI_CUSTOM_RECOVERY', 'HONEYNOGI_CUSTOM_MARKER', 'HONEYNOGI_CUSTOM_GENERATION', 'HONEYNOGI_RUN_ID',
    # 구현 명세 ⑤b5 - 본류 보상 결정이 읽는 env(R6-RC1 이 다음 항목 NEXT 만 픽스처 1번 토큰으로 두고 나머지는 빈 값 - 구현 명세 ⑤b6 3.4 ⑳)
    'HONEYNOGI_CUSTOM_NEXT', 'HONEYNOGI_CUSTOM_NEXT_OWNER', 'HONEYNOGI_CUSTOM_NEXT_BOUNDARY', 'HONEYNOGI_LAST_RUN', 'HONEYNOGI_UNTIL_TIME')
# R6-RC1 워커 1 의 '다른 던전 가기' 끝 모의가 던지는 끊김 표지('confirmed' 뒤 exit 전 - 구현 명세 ⑤b5 3.1 ⑳)
$OTHER_END_CRASH_MESSAGE = 'CRASH-AFTER-OTHER-CONFIRMED'
# 패널 시작 시간표(OK4·OK5·R2-E4) - 준비 패널 10초 뒤 던전 안(입장 - 파티원 준비·매칭이 끝난 모양). 선분기는 첫 패널 표본에서 own 닫기 → B2 단계 → 입장 2연속
$PANEL_TIMELINE = @(@{ At = 0; Screen = 'ready' }, @{ At = 10; Screen = 'inside' })
# 화면 모형의 글자 위치 - Find-GameTextPoint 모의가 돌려주고 클릭 모의가 그 자리로 화면 전이를 정합니다(test_abyss_return_loop 와 같은 좌표)
$MOCK_ESC_POINT = @{ X = 1102; Y = 74 }
$MOCK_ABYSS_POINT = @{ X = 971; Y = 531 }

# ===== 공통 단언 · 표시 =====
function Assert-Case {
    # 단언 한 줄 - 대소문자까지 비교합니다
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
    # 함수 출력 개체 전부 → '값(개수)' - 반환 하나 계약(여분 출력이 섞이면 개수로 드러남)
    param([object[]]$Outputs = @())
    return ('{0}({1})' -f ((@($Outputs) | ForEach-Object { [string]$_ }) -join ','), @($Outputs).Count)
}

function Format-OutputValues {
    # 함수 출력 개체 → 값(여럿이면 ',' · 없으면 '(출력 없음)') - 저장 태그 기록용
    param([object[]]$Outputs = @())
    if (@($Outputs).Count -eq 0) { return '(출력 없음)' }
    return ((@($Outputs) | ForEach-Object { [string]$_ }) -join ',')
}

function Get-LinesWithPrefix {
    # 줄 목록에서 머리가 맞는 줄 → 목록(열거용 - 호출부 @())
    param([object[]]$Lines = @(), [string[]]$Prefixes)
    $found = @()
    foreach ($line in @($Lines)) {
        $lineText = [string]$line
        foreach ($prefix in $Prefixes) {
            if ($lineText.StartsWith($prefix)) { $found += $lineText; break }
        }
    }
    return $found
}

function Get-LineCount {
    # 줄 목록에서 같은 줄(-Exact) · 머리(-Prefix) · 조각(-Fragment) 수
    param([object[]]$Lines = @(), [string]$Exact = '', [string]$Prefix = '', [string]$Fragment = '')
    $count = 0
    foreach ($line in @($Lines)) {
        $lineText = [string]$line
        if ($Exact -and ($lineText -ceq $Exact)) { $count++; continue }
        if ($Prefix -and $lineText.StartsWith($Prefix)) { $count++; continue }
        if ($Fragment -and $lineText.Contains($Fragment)) { $count++ }
    }
    return $count
}

function Get-LastLine {
    # 줄 목록에서 머리가 맞는 마지막 줄 (없으면 '(없음)')
    param([object[]]$Lines = @(), [string]$Prefix)
    $found = '(없음)'
    foreach ($line in @($Lines)) { if (([string]$line).StartsWith($Prefix)) { $found = [string]$line } }
    return $found
}

function Format-KeyCounts {
    # 누른 키 목록 → 'Space n · B n'
    param([object[]]$Keys = @())
    $spaceCount = @(@($Keys) | Where-Object { ($null -ne $_) -and ([int]$_ -eq 32) }).Count
    $foodCount = @(@($Keys) | Where-Object { ($null -ne $_) -and ([int]$_ -eq 66) }).Count
    return ('Space {0} · B {1}' -f $spaceCount, $foodCount)
}

# nonce 표시 - 픽스처 nonce 는 NA~NS, 워커가 새로 만든 nonce 는 처음 본 순서대로 W1·W2…(행마다 새로)
$script:nonceLabels = @{}
$script:nonceSerial = 0
function Get-NonceLabel {
    param([string]$Nonce)
    if ([string]::IsNullOrEmpty($Nonce)) { return '(빈 값)' }
    if ($FIXTURE_NONCE_LABELS.ContainsKey($Nonce)) { return [string]$FIXTURE_NONCE_LABELS[$Nonce] }
    if (-not $script:nonceLabels.ContainsKey($Nonce)) {
        $script:nonceSerial++
        $script:nonceLabels[$Nonce] = ('W{0}' -f $script:nonceSerial)
    }
    return [string]$script:nonceLabels[$Nonce]
}

# ===== 소스 도구 =====
function Remove-CommentsByTokens {
    # 주석 토큰을 같은 길이의 공백으로(줄바꿈 보존) - 위치가 원문과 같아 AST 오프셋으로 사본을 잘라 쓸 수 있습니다(⑱′ 와 같은 구현)
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
    # 원문의 exit 토큰을 뒤에서부터 Stop-WorkerTailExit 로 바꿉니다(⑯ :462~472 선례 · 명세 J8 - 한 줄 '{ exit N }' 도 바꿈).
    # 반환 @{ Text; Tokens; Statements; Inserted; Remaining; Errors } (⑱′ 와 같은 구현)
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
    # '원본 Exit 토큰 수 = 원본 ExitStatementAst 수 = 치환 수 · 치환 뒤 0 · 파서 오류 0' (명세 2.0-8 - 동작 행보다 먼저)
    param([string]$Label, [hashtable]$Tally)
    $expected = @{ Tokens = $Tally.Tokens; Statements = $Tally.Tokens; Inserted = $Tally.Tokens; Remaining = 0; Errors = 0 }
    Assert-Case ('exit 치환({0} - {1}개 단위)' -f $Label, $Tally.Units) (Format-ExitTally $Tally) (Format-ExitTally $expected)
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

function Get-CommandAsts {
    # 노드 아래(자신 포함) 이름이 같은 명령 AST → 목록(열거용 - 호출부 @())
    param($Root, [string]$Name)
    if ($null -eq $Root) { return @() }
    return @($Root.FindAll({ param($node) ($node -is [CommandAst]) -and ($node.GetCommandName() -eq $Name) }, $true))
}

function Get-CommandArgumentAst {
    # 명령의 '-이름 값'(또는 '-이름:값') 인자 AST (없으면 $null)
    param($CommandAst, [string]$ParameterName)
    $elements = @($CommandAst.CommandElements)
    for ($elementIndex = 0; $elementIndex -lt $elements.Count; $elementIndex++) {
        $element = $elements[$elementIndex]
        if (($element -is [CommandParameterAst]) -and ($element.ParameterName -eq $ParameterName)) {
            if ($null -ne $element.Argument) { return $element.Argument }
            if ($elementIndex + 1 -lt $elements.Count) { return $elements[$elementIndex + 1] }
            return $null
        }
    }
    return $null
}

function Test-CommandHasParameter {
    param($CommandAst, [string]$ParameterName)
    foreach ($element in @($CommandAst.CommandElements)) {
        if (($element -is [CommandParameterAst]) -and ($element.ParameterName -eq $ParameterName)) { return $true }
    }
    return $false
}

function Get-ParamSignature {
    # 소스 AST 의 함수 정의 → 매개변수 서명 '타입 $이름, …' (⑱′ 와 같은 구현)
    param($Ast, [string]$Name)
    $functionAst = @($Ast.FindAll({ param($node) ($node -is [FunctionDefinitionAst]) -and ($node.Name -eq $Name) }, $true)) | Select-Object -First 1
    if ($null -eq $functionAst) { return '(정의 없음)' }
    $paramBlock = $functionAst.Body.ParamBlock
    if ($null -eq $paramBlock) { return '(매개변수 없음)' }
    return (@($paramBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}

function Get-LiveParamSignature {
    # 이 파일에 지금 정의된 함수(모의)의 매개변수 서명 - 같은 형식
    param([string]$Name)
    $command = Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue
    if ($null -eq $command) { return '(정의 없음)' }
    $functionAst = $command.ScriptBlock.Ast
    $paramBlock = $(if ($functionAst -is [FunctionDefinitionAst]) { $functionAst.Body.ParamBlock } else { $functionAst.ParamBlock })
    if ($null -eq $paramBlock) { return '(매개변수 없음)' }
    return (@($paramBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}

function Get-RealFunctionName {
    # 감시가 넘길 실제 함수 이름 - Invoke-Real<이름에서 '-' 를 뺀 것>
    param([string]$Name)
    return ('Invoke-Real' + ($Name -replace '-', ''))
}

function Rename-FunctionText {
    # 함수 정의 원문의 이름을 실제 함수 이름(Invoke-Real…)으로
    param([string]$Text, [string]$Name)
    return ($Text -replace ('^function ' + [regex]::Escape($Name) + '(?=[\s{])'), ('function ' + (Get-RealFunctionName -Name $Name)))
}

function New-SpyText {
    # 감시 정의 원문 - 실제 함수의 매개변수 블록을 그대로 복사하고(서명이 같아짐) 호출을 적은 뒤 실제 함수로 @PSBoundParameters 를 넘깁니다.
    # 출력 개체는 그대로 돌려줍니다(반환 개수 계약이 감시를 지나도 같게)
    param([string]$Name, $FunctionAst)
    $paramText = ''
    if ($null -ne $FunctionAst.Body.ParamBlock) {
        $paramText = [string]$FunctionAst.Body.ParamBlock.Extent.Text
    } elseif (@($FunctionAst.Parameters).Count -gt 0) {
        $paramText = 'param(' + ((@($FunctionAst.Parameters) | ForEach-Object { $_.Extent.Text }) -join ', ') + ')'
    }
    $spyLines = @(
        ('function {0} {{' -f $Name),
        $paramText,
        ("    `$spySkip = Enter-SpyCall -Name '{0}' -Bound `$PSBoundParameters" -f $Name),
        '    if ($spySkip) { return }',
        ('    $spyOutput = @({0} @PSBoundParameters)' -f (Get-RealFunctionName -Name $Name)),
        ("    Exit-SpyCall -Name '{0}' -Bound `$PSBoundParameters -Output `$spyOutput" -f $Name),
        '    return $spyOutput',
        '}')
    return ($spyLines -join "`r`n")
}

function Find-WorkerAssignments {
    # 워커 대입문(깊이 무관) - 왼쪽 원문이 같고 오른쪽에 조각이 든 것 → 목록(열거용 - 호출부 @())
    param([string]$Left, [string]$RightFragment = '')
    return @($workerAst.FindAll({ param($node)
                ($node -is [AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq $Left) -and $node.Right.Extent.Text.Contains($RightFragment) }, $true))
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
$workerText = $workerAst.Extent.Text
$workerCode = Remove-CommentsByTokens -Text $workerText -Tokens $workerTokens

# 저장소 묶음(워커 사본) - 머리 주석 ~ '묶음 끝' 표지 사이 최상위 함수 전부(test_abyss_journal_store 와 같은 경계)
$bundleHeaders = @($workerTokens | Where-Object { ($_.Kind -eq [TokenKind]::Comment) -and $_.Text.Contains($BUNDLE_HEADER_FRAGMENT) })
$bundleEnds = @($workerTokens | Where-Object { ($_.Kind -eq [TokenKind]::Comment) -and $_.Text.Contains($BUNDLE_END_FRAGMENT) })
if ($bundleHeaders.Count -ne 1 -or $bundleEnds.Count -ne 1) {
    "FAIL 저장소 묶음 경계 주석이 1개씩이 아닙니다 (머리 $($bundleHeaders.Count) · 끝 $($bundleEnds.Count))"
    exit 1
}
$bundleEndOffset = $bundleEnds[0].Extent.StartOffset
$bundleNames = @()
$bundleFunctions = @{}
$bundleExit = New-ExitTally
foreach ($statement in $workerAst.EndBlock.Statements) {
    if (-not ($statement -is [FunctionDefinitionAst])) { continue }
    if ($statement.Extent.StartOffset -lt $bundleHeaders[0].Extent.StartOffset) { continue }
    if ($statement.Extent.StartOffset -gt $bundleEndOffset) { break }
    $bundleNames += $statement.Name
    $bundleFunctions[$statement.Name] = $statement
    $conversion = Convert-ExitTokens -Text $statement.Extent.Text
    Add-ExitTally -Tally $bundleExit -Conversion $conversion
    Invoke-Expression $conversion.Text
    if ($BUNDLE_SPY_NAMES -contains $statement.Name) { Invoke-Expression (Rename-FunctionText -Text $conversion.Text -Name $statement.Name) }
}
foreach ($spyName in $BUNDLE_SPY_NAMES) { if ($bundleNames -notcontains $spyName) { $extractionProblems.Add("저장소 묶음에 $spyName 이(가) 없습니다") } }

$workerTopFunctions = @{}
foreach ($statement in $workerAst.EndBlock.Statements) {
    if ($statement -is [FunctionDefinitionAst]) { $workerTopFunctions[$statement.Name] = $statement }
}

# 본류(워커 최상위 try) - 파티원 디스패치 if 의 부모 = try 본문(⑱′ 와 같은 앵커). 시작 구간 A = [2.1 블록 ~ run:18527 if 앞] · 조각 B = [키 지점 블록 ~ try 끝]
$mainStatements = @()
$mainTry = $null
$memberIfNodes = @($workerAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq '$abyssPartyMemberRun') }, $true))
if ($memberIfNodes.Count -eq 1) {
    $mainStatements = @($memberIfNodes[0].Parent.Statements)
    $mainTry = $memberIfNodes[0].Parent.Parent
} else {
    $extractionProblems.Add("파티원 디스패치 if 가 $($memberIfNodes.Count)개입니다(1개여야 함)")
}
if (($null -ne $mainTry) -and -not ($mainTry -is [TryStatementAst])) {
    $extractionProblems.Add('파티원 디스패치 if 의 바깥이 최상위 try 가 아닙니다')
    $mainTry = $null
}
$blockIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement)
        ($statement -is [IfStatementAst]) -and (@(Get-CommandAsts -Root $statement -Name 'Consume-Handoff').Count -gt 0) })
$insideIfIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement)
        ($statement -is [IfStatementAst]) -and ($statement.Clauses[0].Item1.Extent.Text -eq '$startInsideDetected') })
$keyPointIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement) @(Get-CommandAsts -Root $statement -Name 'Invoke-AfterEntryKeys').Count -gt 0 })
$startExitIndexes = @(Find-StatementIndexes -Statements $mainStatements -Match { param($statement)
        ($statement -is [AssignmentStatementAst]) -and ($statement.Left.Extent.Text -eq '$startExitDetected') })
$segmentAStatements = @()
$segmentBStatements = @()
$insideIf = $null
$startExitStatement = $null
$keyPointStatement = $null
if (($blockIndexes.Count -eq 1) -and ($insideIfIndexes.Count -eq 1) -and ($keyPointIndexes.Count -eq 1) -and
    ($blockIndexes[0] -lt $insideIfIndexes[0]) -and ($keyPointIndexes[0] -eq ($insideIfIndexes[0] + 1))) {
    $segmentAStatements = @($mainStatements[$blockIndexes[0]..($insideIfIndexes[0] - 1)])
    $segmentBStatements = @($mainStatements[$keyPointIndexes[0]..($mainStatements.Count - 1)])
    $insideIf = $mainStatements[$insideIfIndexes[0]]
    $keyPointStatement = $mainStatements[$keyPointIndexes[0]]
} else {
    $extractionProblems.Add(('본류 형제 문장 자리가 맞지 않습니다 - 2.1 블록 {0}개 · run:18527 if {1}개 · 키 지점 {2}개(셋 다 1개 · 2.1 블록 < run:18527 if · 키 지점 = 그 if 바로 다음이어야 함)' -f `
                $blockIndexes.Count, $insideIfIndexes.Count, $keyPointIndexes.Count))
}
$startExitBefore = @($startExitIndexes | Where-Object { ($blockIndexes.Count -eq 1) -and ($_ -lt $blockIndexes[0]) })
if ($startExitBefore.Count -ge 1) { $startExitStatement = $mainStatements[$startExitBefore[-1]] } else { $extractionProblems.Add('2.1 블록 앞의 $startExitDetected 대입(시작 판독 원문)을 찾지 못했습니다') }

$segmentAExit = New-ExitTally
$segmentBExit = New-ExitTally
$catchExit = New-ExitTally
$script:segmentABlock = $null
$script:segmentBBlock = $null
$script:combinedBlock = $null
$script:startExitBlock = $null
$segmentAConverted = ''
$segmentBConverted = ''
$catchConverted = ''
$catchStatements = @()
$combinedText = ''
if ($segmentAStatements.Count -gt 0) {
    $conversion = Convert-ExitTokens -Text (@($segmentAStatements | ForEach-Object { $_.Extent.Text }) -join "`r`n")
    Add-ExitTally -Tally $segmentAExit -Conversion $conversion
    $segmentAConverted = $conversion.Text
    $script:segmentABlock = [scriptblock]::Create($segmentAConverted)
    "INFO 시작 구간 A: 워커 $($segmentAStatements[0].Extent.StartLineNumber)~$($segmentAStatements[-1].Extent.EndLineNumber)줄 형제 문장 $($segmentAStatements.Count)개"
}
if ($segmentBStatements.Count -gt 0) {
    $conversion = Convert-ExitTokens -Text (@($segmentBStatements | ForEach-Object { $_.Extent.Text }) -join "`r`n")
    Add-ExitTally -Tally $segmentBExit -Conversion $conversion
    $segmentBConverted = $conversion.Text
    $script:segmentBBlock = [scriptblock]::Create($segmentBConverted)
    "INFO 조각 B: 워커 $($segmentBStatements[0].Extent.StartLineNumber)~$($segmentBStatements[-1].Extent.EndLineNumber)줄 형제 문장 $($segmentBStatements.Count)개"
}
if ($null -ne $startExitStatement) { $script:startExitBlock = [scriptblock]::Create($startExitStatement.Extent.Text) }
if (($null -ne $mainTry) -and ($mainTry.CatchClauses.Count -ge 1) -and (@($mainTry.CatchClauses[0].Body.Statements).Count -gt 0)) {
    # 최상위 catch 본문 - CatchClauses[0].Body 의 중괄호 안쪽(첫 문장 시작 ~ 마지막 문장 끝 원문). Body.Extent 를 그대로 넣으면 스크립트 블록 리터럴(값)이 되어
    # 실행되지 않음(명세 3.3)
    $catchStatements = @($mainTry.CatchClauses[0].Body.Statements)
    $catchText = $workerText.Substring($catchStatements[0].Extent.StartOffset, $catchStatements[-1].Extent.EndOffset - $catchStatements[0].Extent.StartOffset)
    $conversion = Convert-ExitTokens -Text $catchText
    Add-ExitTally -Tally $catchExit -Conversion $conversion
    $catchConverted = $conversion.Text
} else {
    $extractionProblems.Add('최상위 try 의 catch 본문을 찾지 못했습니다')
}
$combinedErrors = $null
if ($segmentAConverted -and $segmentBConverted -and $catchConverted) {
    $combinedText = "try {`r`n" + $segmentAConverted + "`r`n" + $segmentBConverted + "`r`n} catch {`r`n" + $HARNESS_RETHROW_TEXT + "`r`n" + $catchConverted + "`r`n}"
    $combinedTokens = $null
    [void][Parser]::ParseInput($combinedText, [ref]$combinedTokens, [ref]$combinedErrors)
    if (@($combinedErrors).Count -eq 0) { $script:combinedBlock = [scriptblock]::Create($combinedText) } else { $extractionProblems.Add("결합 블록 파서 오류: $($combinedErrors[0].Message)") }
}

# 'left' 블록 - 루프 층이 부르는 원문 호출 문장 · 마지막 [완료] 문구(소스 값 캡처)
# 구현 명세 ⑤b5 W3 (3.4): 'left' 본문에 마무리 실행 갈래 if ($script:finishOnly) { [완료] 마무리 줄 ; exit 4 } 가 들어가 [완료] 쓰기가 둘입니다 - if 밖 쓰기 1(준비 실행 줄 =
#   $LEFT_DONE_LINE) + 마무리 실행 if 안 쓰기 1(= $LEFT_FINISH_DONE_LINE · R2-L5)을 각각 소스에서 캡처합니다(둘 다 같은 원인 대입을 지남)
$leftIfNodes = @($segmentBStatements | Where-Object { ($_ -is [IfStatementAst]) -and ($_.Clauses[0].Item1.Extent.Text -eq "`$clearOutcome -eq 'left'") })
$script:leftCallBlock = $null
$LEFT_DONE_LINE = '(소스에서 찾지 못함)'
$LEFT_FINISH_DONE_LINE = '(소스에서 찾지 못함)'
if ($leftIfNodes.Count -eq 1) {
    $leftBody = @($leftIfNodes[0].Clauses[0].Item2.Statements)
    $leftCalls = @($leftBody | Where-Object { @(Get-CommandAsts -Root $_ -Name 'Return-ToAbyssSelection').Count -gt 0 })
    $leftCauseAssigns = @($leftBody | Where-Object { ($_ -is [AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$leaveCause') })
    $leftDoneWrites = @($leftBody | Where-Object { (-not ($_ -is [IfStatementAst])) -and (@(Get-CommandAsts -Root $_ -Name 'Write-RunLog').Count -gt 0) -and $_.Extent.Text.Contains('[완료]') })
    $leftFinishIfs = @($leftBody | Where-Object { ($_ -is [IfStatementAst]) -and ($_.Clauses[0].Item1.Extent.Text -eq '$script:finishOnly') })
    $leftFinishWrites = @(foreach ($leftFinishIf in $leftFinishIfs) {
            @($leftFinishIf.Clauses[0].Item2.Statements | Where-Object { (@(Get-CommandAsts -Root $_ -Name 'Write-RunLog').Count -gt 0) -and $_.Extent.Text.Contains('[완료]') })
        })
    if ($leftCalls.Count -eq 1) {
        $script:leftCallBlock = [scriptblock]::Create((Convert-ExitTokens -Text $leftCalls[0].Extent.Text).Text)
    } else {
        $extractionProblems.Add("'left' 블록의 복귀 호출이 $($leftCalls.Count)개입니다(1개여야 함)")
    }
    if (($leftCauseAssigns.Count -eq 1) -and ($leftDoneWrites.Count -eq 1) -and ($leftFinishIfs.Count -eq 1) -and ($leftFinishWrites.Count -eq 1)) {
        $script:abyssLeaveCause = ''
        foreach ($leftCapture in @(@{ Write = $leftDoneWrites[0]; Name = 'LEFT_DONE_LINE' }, @{ Write = $leftFinishWrites[0]; Name = 'LEFT_FINISH_DONE_LINE' })) {
            $leftWriteCommand = @(Get-CommandAsts -Root $leftCapture.Write -Name 'Write-RunLog')[0]
            $leftWriteArgument = @($leftWriteCommand.CommandElements)[1]
            Set-Variable -Name $leftCapture.Name -Value ([string](Invoke-Expression ($leftCauseAssigns[0].Extent.Text + "`r`n" + $leftWriteArgument.Extent.Text)))
        }
    } else {
        $extractionProblems.Add("'left' 블록의 원인 대입·[완료] 줄(if 밖 1 · 마무리 실행 if 안 1)을 찾지 못했습니다 (원인 대입 $($leftCauseAssigns.Count) · if 밖 [완료] $($leftDoneWrites.Count) · 마무리 실행 if $($leftFinishIfs.Count) · 그 안 [완료] $($leftFinishWrites.Count))")
    }
} else {
    $extractionProblems.Add("조각 B 의 'left' if 가 $($leftIfNodes.Count)개입니다(1개여야 함)")
}
# 클리어 대기 불명 마감의 [완료] 줄 - 워커 Wait-ForDungeonClearScreen 원문의 문자열 하나(OK11 의 클리어 대기 모의가 그 글자 그대로 냅니다 - 명세 3.3 'run:4678 모양 스텁')
$CLEAR_WAIT_UNKNOWN_LINE = ''
$clearWaitUnknownStrings = @()
if ($workerTopFunctions.ContainsKey('Wait-ForDungeonClearScreen')) {
    $clearWaitUnknownStrings = @($workerTopFunctions['Wait-ForDungeonClearScreen'].FindAll({ param($node)
                ($node -is [StringConstantExpressionAst]) -and ([string]$node.Value).StartsWith($CLEAR_WAIT_UNKNOWN_FRAGMENT) }, $true))
}
if ($clearWaitUnknownStrings.Count -eq 1) { $CLEAR_WAIT_UNKNOWN_LINE = [string]$clearWaitUnknownStrings[0].Value }
else { $extractionProblems.Add("클리어 대기 불명 마감 문구('$CLEAR_WAIT_UNKNOWN_FRAGMENT …')가 워커 Wait-ForDungeonClearScreen 에 $($clearWaitUnknownStrings.Count)개입니다(1개여야 함)") }

# 워커 최상위 함수 - 이름 목록 + 두 조각·catch 본문이 부르는 워커 함수 → 그 함수들이 부르는 워커 함수(저장소 묶음·모의·닿지 않는 갈래는 빼고)
$followQueue = New-Object System.Collections.Generic.Queue[string]
foreach ($functionName in $WORKER_FUNCTION_NAMES) { $followQueue.Enqueue($functionName) }
foreach ($statement in @($segmentAStatements + $segmentBStatements + $catchStatements)) {
    foreach ($commandAst in $statement.FindAll({ param($node) $node -is [CommandAst] }, $true)) {
        $commandName = $commandAst.GetCommandName()
        if ($commandName -and $workerTopFunctions.ContainsKey($commandName)) { $followQueue.Enqueue($commandName) }
    }
}
$workerExtracted = New-Object System.Collections.Generic.List[string]
while ($followQueue.Count -gt 0) {
    $functionName = $followQueue.Dequeue()
    if ($workerExtracted.Contains($functionName)) { continue }
    if (($bundleNames -contains $functionName) -or ($TEST_DEFINED_NAMES -contains $functionName) -or ($NOT_REACHED_NAMES -contains $functionName)) { continue }
    if (-not $workerTopFunctions.ContainsKey($functionName)) {
        $extractionProblems.Add("워커 최상위 함수 $functionName 을(를) 찾지 못했습니다")
        continue
    }
    $workerExtracted.Add($functionName)
    foreach ($commandAst in $workerTopFunctions[$functionName].FindAll({ param($node) $node -is [CommandAst] }, $true)) {
        $commandName = $commandAst.GetCommandName()
        if ($commandName -and $workerTopFunctions.ContainsKey($commandName) -and -not $workerExtracted.Contains($commandName)) { $followQueue.Enqueue($commandName) }
    }
}
$workerExit = New-ExitTally
foreach ($functionName in $workerExtracted) {
    $conversion = Convert-ExitTokens -Text $workerTopFunctions[$functionName].Extent.Text
    Add-ExitTally -Tally $workerExit -Conversion $conversion
    Invoke-Expression $conversion.Text
    if (@($WORKER_SPY_NAMES + $HANDOFF_SPY_NAMES) -contains $functionName) { Invoke-Expression (Rename-FunctionText -Text $conversion.Text -Name $functionName) }
}
"INFO 워커 추출: $(@($workerExtracted) -join ', ') (저장소 묶음 $($bundleNames.Count)개 별도)"
function Test-WorkerExtracted {
    param([string[]]$Names)
    foreach ($name in $Names) { if (-not $workerExtracted.Contains($name)) { return $false } }
    return $true
}

# 워커 상태 문장 - 행이 원문 그대로 점소싱합니다(운영 대입과 같은 식)
$script:configValidationWarnings = @()
$script:configCoordinateWidth = 1272
$script:configCoordinateHeight = 717
$INITIAL_STATE_LEFTS = @('$script:customCleanupOnly', '$script:customRestart', '$script:customRecoveryOnly', '$script:customMarkerPath',
    '$script:customOwnerJson', '$script:customItem', '$script:customPositionText', '$script:customListText', '$script:abyssLeaveCause')
$initialTexts = @()
foreach ($leftText in $INITIAL_STATE_LEFTS) {
    $firstAssign = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq $leftText) }) | Select-Object -First 1
    if ($null -eq $firstAssign) { $extractionProblems.Add("워커 최상위 초기값 대입 $leftText 을(를) 찾지 못했습니다") } else { $initialTexts += $firstAssign.Extent.Text }
}
$script:workerInitialBlock = [scriptblock]::Create(($initialTexts -join "`r`n"))
$customEnvIfs = @($workerAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq '$script:customMode') -and
            (@($node.FindAll({ param($inner) ($inner -is [AssignmentStatementAst]) -and ($inner.Left.Extent.Text -eq '$script:customRestart') }, $true)).Count -gt 0) }, $true))
$script:workerCustomEnvBlock = $null
if ($customEnvIfs.Count -eq 1) { $script:workerCustomEnvBlock = [scriptblock]::Create($customEnvIfs[0].Extent.Text) } else { $extractionProblems.Add("커스텀 env 읽기 if(`$script:customMode - RESTART·RECOVERY·MARKER·OWNER)가 $($customEnvIfs.Count)개입니다(1개여야 함)") }
$runIdReads = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssRunId') })
$handoffDefaults = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:handoff') })
$finishOnlyReads = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:finishOnly') })
$savedByAssigns = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssJournalSavedBy') })
$script:workerRunIdReadBlock = $null
$script:workerHandoffDefaultBlock = $null
$script:workerFinishOnlyReadBlock = $null
if ($runIdReads.Count -eq 1) { $script:workerRunIdReadBlock = [scriptblock]::Create($runIdReads[0].Extent.Text) } else { $extractionProblems.Add("워커 실행 id 최상위 대입이 $($runIdReads.Count)개입니다(1개여야 함)") }
if ($handoffDefaults.Count -eq 1) { $script:workerHandoffDefaultBlock = [scriptblock]::Create($handoffDefaults[0].Extent.Text) } else { $extractionProblems.Add("워커 `$script:handoff 기본값 최상위 대입이 $($handoffDefaults.Count)개입니다(1개여야 함 - 명세 2.1)") }
if ($finishOnlyReads.Count -eq 1) { $script:workerFinishOnlyReadBlock = [scriptblock]::Create($finishOnlyReads[0].Extent.Text) }
if ($savedByAssigns.Count -eq 1) { Invoke-Expression $savedByAssigns[0].Extent.Text } else { $extractionProblems.Add('워커 작성자 표지 대입을 찾지 못했습니다'); $script:abyssJournalSavedBy = 'worker:test' }
# 키 목록 해석 문장(run:1846~1870 - $rawAfterEntryKeys 대입 ~ $afterEntryActions 를 채우는 for)
$endStatements = @($workerAst.EndBlock.Statements)
$rawKeysIndexes = @(Find-StatementIndexes -Statements $endStatements -Match { param($statement) ($statement -is [AssignmentStatementAst]) -and ($statement.Left.Extent.Text -eq '$rawAfterEntryKeys') })
$actionsForIndexes = @(Find-StatementIndexes -Statements $endStatements -Match { param($statement) ($statement -is [ForStatementAst]) -and $statement.Extent.Text.Contains('$afterEntryActions +=') })
$script:afterEntryActionsBlock = $null
if (($rawKeysIndexes.Count -eq 1) -and ($actionsForIndexes.Count -eq 1) -and ($rawKeysIndexes[0] -lt $actionsForIndexes[0])) {
    $script:afterEntryActionsBlock = [scriptblock]::Create((@($endStatements[$rawKeysIndexes[0]..$actionsForIndexes[0]] | ForEach-Object { $_.Extent.Text }) -join "`r`n"))
} else {
    $extractionProblems.Add("키 목록 해석 문장을 찾지 못했습니다 (대입 $($rawKeysIndexes.Count)개 · for $($actionsForIndexes.Count)개)")
}
# 시간·좌표 값 - 소스 대입문 그대로(픽스처 config 에 timeoutsSeconds·clickPoints 가 없어 소스 기본값)
$config = ([pscustomobject]@{ afterEntry = [pscustomobject]@{ keyDelayMs = 500 } } | ConvertTo-Json -Depth 5) | ConvertFrom-Json
# 선분기가 빌려 쓰는 파티원 상수 셋(W · 알 수 없음 30초 · 스윕 연속 한도 - 명세 2.5 ④·⑩ · B20 '새 상수 0')도 소스 대입 그대로 - 빠지면 시계가 0초로 돌아
# 첫 알 수 없음 회전에서 이벤트 정리를 부르는 등 모형이 소스와 달라집니다. 재입장 대기의 무변화 창($abyssReclickQuietSeconds - 구현 단위 ⑤a 부터 선분기 B2 단계가
# 그 함수를 부름)도 같은 이유로 소스 대입 그대로입니다(보고 끔 호출이라 결과는 같음 - 구현 명세 ④ C3). 복귀 전체 상한($abyssReturnTotalLimitSeconds - 구현 단위 복귀 연장)이 빠지면
# 연장 예산이 음수라 복귀 루프가 조용히 연장 0 으로 돕니다
foreach ($settingLeft in @('$timeoutClear', '$timeoutExit', '$timeoutHud', '$timeoutAbyssMenu', '$timeoutAbyssSelect', '$timeoutPartyMatch',
        '$memberFieldSettleSeconds', '$memberUnknownOverlaySeconds', '$memberSweepStreakLimit', '$ptClearCenter', '$afterEntryDelayMs', '$abyssReclickQuietSeconds',
        '$abyssReturnTotalLimitSeconds')) {
    $settingAssign = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq $settingLeft) }) | Select-Object -First 1
    if ($null -eq $settingAssign) { $extractionProblems.Add("워커 최상위 값 대입 $settingLeft 을(를) 찾지 못했습니다"); continue }
    try { Invoke-Expression $settingAssign.Extent.Text } catch { $extractionProblems.Add("워커 값 대입 $settingLeft 실행 실패: $($_.Exception.Message)") }
}
# 화면 모의에 넘기기만 하는 영역·좌표(값은 판정과 무관 - 형식만)
$contentCategory = 'abyss'
$deepMode = $false
$mainCategory = 'battle'
$rgPopupClose = @(380, 590, 320, 60)
$rgAbyssMenu = @(850, 180, 350, 520)
$rgHomeEndEsc = @(875, 60, 265, 55)
$ptEscButton = @(1083, 89)
$noticeCloseTryLimit = 2
function Click-NoticeBoardClose { param($Game) Click-GamePoint -Game $Game -ReferenceX 1078 -ReferenceY 149 }
$rgStellaTitle = @(50, 45, 230, 45)
$rgStellaPickBtn = @(740, 632, 450, 50)
$ptStellaCard = @(640, 420)
$rgEnterButton = @(880, 630, 280, 48)
$ocrKoreanEngine = 'ko'
$ocrEnglishEngine = 'en'
$refocusEverySeconds = 0

# GUI 원문 함수 - 이름으로 1개씩. 감시 대상(Resolve)은 Invoke-Real… 로 한 번 더 정의
$guiTokens = $null
$guiErrors = $null
$guiAst = [Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$guiErrors)
$guiExit = New-ExitTally
$guiAvailable = $true
$guiFunctions = @{}
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
        $guiFunctions[$functionName] = $functionAsts[0]
        $conversion = Convert-ExitTokens -Text $functionAsts[0].Extent.Text
        Add-ExitTally -Tally $guiExit -Conversion $conversion
        Invoke-Expression $conversion.Text
        if ($GUI_SPY_NAMES -contains $functionName) { Invoke-Expression (Rename-FunctionText -Text $conversion.Text -Name $functionName) }
    }
}

# ===== 모의 · 감시 상태 =====
$script:workerLogLines = New-Object System.Collections.Generic.List[string]
$script:keyPresses = New-Object System.Collections.Generic.List[int]
$script:rowPresses = New-Object System.Collections.Generic.List[int]
$script:keyPressTrace = New-Object System.Collections.Generic.List[string]
$script:events = New-Object System.Collections.Generic.List[string]
$script:exitRecords = New-Object System.Collections.Generic.List[int]
$script:setCalls = New-Object System.Collections.Generic.List[string]
$script:enteredTags = New-Object System.Collections.Generic.List[string]
$script:keyCalls = New-Object System.Collections.Generic.List[string]
$script:keyOutcomes = New-Object System.Collections.Generic.List[string]
$script:closeCalls = New-Object System.Collections.Generic.List[string]
$script:closeUpdateTags = New-Object System.Collections.Generic.List[string]
$script:returnCalls = New-Object System.Collections.Generic.List[string]
$script:ownCloseCalls = New-Object System.Collections.Generic.List[string]        # 단계 2.5 own 닫기 호출(-Screen)
$script:ownCloseUpdateTags = New-Object System.Collections.Generic.List[string]   # 그 저장 태그
$script:overlayStops = New-Object System.Collections.Generic.List[string]         # 선분기 1회 정지(-Kind)
$script:screenTimeline = New-Object System.Collections.Generic.List[object]       # 행이 정하는 화면 시간표(@{ At = 기동 뒤 초; Screen })
$script:timelineStart = [datetime]'2026-10-13 12:00:00'
$script:inOwnClose = $false
$script:updateTags = New-Object System.Collections.Generic.List[string]
$script:diagRecords = New-Object System.Collections.Generic.List[string]
$script:resolveResults = New-Object System.Collections.Generic.List[string]
$script:guiEvents = New-Object System.Collections.Generic.List[string]
$script:activeQueue = New-Object System.Collections.Generic.List[bool]
$script:heldStreams = New-Object System.Collections.Generic.List[System.IDisposable]
$script:spyCounts = @{}
$script:spyStub = @{}
$script:spyPre = @{}
$script:spyPost = @{}
$script:throwHook = $null
$script:throwFired = 0
$script:inClose = $false
$script:pressResults = @{}
$script:crashAfterPress = -1
$script:createdSnapshot = $null
$script:stateAfterConsume = ''
$script:stateAtGeneration = ''
$script:seqBeforeCleared = ''
$script:seqAfterCleared = ''
$script:tempWrites = 0
$script:vclock = [datetime]'2026-10-13 12:00:00'
$script:rowClockStart = $script:vclock
$script:screen = 'selection'
$script:safeStopFlag = $false
$script:runLogTargetPath = ''
$script:abyssJournalPath = ''
$script:plainKeyPrefixes = @()

# ===== 모의: 가상 시계 · 캡처 계층 · 화면 =====
function Get-Date {
    # 가상 시계(명세 3.3 결합 층 - -Format 을 처리하는 모양): 인자 없음 = 지금 가상 시각 / -Format = 그 형식 문자열(최상위 catch 의 오류 세트 이름)
    param([string]$Format)
    if ($Format) { return $script:vclock.ToString($Format) }
    return $script:vclock
}
function Start-Sleep {
    # 대기 = 가상 시계 전진. 행 시작부터 가상 20000초를 넘기면 '__VTIMEOUT__' (마감을 못 보는 변이가 러너를 멈추지 않게 - test_abyss_return_loop 와 같은 이유).
    # 시계가 밀리면 화면 시간표의 지난 칸을 적용합니다(선분기 행 - 화면이 시간 따라 바뀌는 모형)
    param([int]$Seconds = 0, [int]$Milliseconds = 0)
    $script:vclock = $script:vclock.AddMilliseconds(($Seconds * 1000) + $Milliseconds)
    if (($script:vclock - $script:rowClockStart).TotalSeconds -gt 20000) { throw '__VTIMEOUT__' }
    Update-MockScreenTimeline
}
function Update-MockScreenTimeline {
    # 화면 시간표(행이 정함 - 기동 시각부터의 초 → 화면) 가운데 지난 칸을 차례로 적용하고 지웁니다. 다 쓰면 화면 모형은 클릭·클리어 대기 모의가 바꾸는 대로 갑니다
    if ($script:screenTimeline.Count -eq 0) { return }
    $elapsedSeconds = ($script:vclock - $script:timelineStart).TotalSeconds
    while (($script:screenTimeline.Count -gt 0) -and ($elapsedSeconds -ge [double]$script:screenTimeline[0].At)) {
        $script:screen = [string]$script:screenTimeline[0].Screen
        $script:screenTimeline.RemoveAt(0)
    }
}
function Test-Path {
    # 안전 중지 플래그 경로만 가로채고(화면 모형의 플래그 값) 그 밖은 실제 cmdlet 으로 (설계 R2 5.2 '플래그 경로만 가로챔' - test_abyss_party_member:943~955 선례)
    param([string]$LiteralPath, [string]$Path)
    $target = $(if ($LiteralPath) { $LiteralPath } else { $Path })
    if ($target -eq $safeStopFlagPath) { return [bool]$script:safeStopFlag }
    if ($LiteralPath) { return (Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath) }
    return (Microsoft.PowerShell.Management\Test-Path -Path $Path)
}
function Remove-Item {
    # 안전 중지 플래그 소비만 가로채(순서 기록 'remove-flag') 그 밖은 실제 cmdlet 으로 (GUI Clear-HandoffEnv 의 Env: 지우기 · 최상위 catch 의 오래된 사본 정리)
    param([string]$LiteralPath, [string]$Path, [switch]$Force, [switch]$Recurse, $ErrorAction = $null)
    $target = $(if ($LiteralPath) { $LiteralPath } else { $Path })
    if ($target -eq $safeStopFlagPath) {
        $script:safeStopFlag = $false
        $script:events.Add('remove-flag')
        return
    }
    $forward = @{}
    if ($LiteralPath) { $forward.LiteralPath = $LiteralPath } else { $forward.Path = $Path }
    if ($Force) { $forward.Force = $true }
    if ($Recurse) { $forward.Recurse = $true }
    if ($null -ne $ErrorAction) { $forward.ErrorAction = $ErrorAction }
    Microsoft.PowerShell.Management\Remove-Item @forward
}
function Stop-WorkerTailExit {
    # 추출 함수·조각의 exit 자리 - 워커를 끝내는 대신 종료 코드를 적고 그 코드를 실은 예외로 행에 돌려줍니다(⑯ :597~601 과 같은 모양)
    param([int]$Code = 0)
    $script:exitRecords.Add($Code)
    $script:events.Add('exit:' + $Code)
    throw ($WORKER_EXIT_PREFIX + $Code)
}
function Register-MockCaptureFail {
    # 캡처 실패 등록 - 일련번호 +1, 플래그가 거짓이었으면 실패 시작 시각(운영 Register-CaptureFailure 계약 - 실제 Get-CaptureFailTotalMs 가 이 값을 읽음)
    $script:captureFailSerial++
    if (-not $script:screenCaptureFailing) {
        $script:screenCaptureFailing = $true
        $script:captureFailingSince = $script:vclock
    }
}
function Register-MockCaptureSuccess {
    # 캡처 성공 등록 - 플래그 해제 + 실패 구간 누적(운영 Register-CaptureSuccess 계약)
    if ($script:screenCaptureFailing) {
        $script:captureFailTotalMs = [double]$script:captureFailTotalMs + ($script:vclock - $script:captureFailingSince).TotalMilliseconds
        $script:screenCaptureFailing = $false
        $script:captureFailingSince = $null
    }
}
function Read-MockScreen {
    # 판독 모의 = 캡처 한 번 - 끊김 없는 캡처 실패(capfailPersist)면 실패 등록 뒤 실패 값, 아니면 성공 등록 뒤 값
    param([string]$Name, $Value, $FailValue = $false)
    $script:screenReads++
    if ($script:screenReads -gt 200000) { throw '__VTIMEOUT__' }
    if ($script:capfailPersist) {
        Register-MockCaptureFail
        return $FailValue
    }
    Register-MockCaptureSuccess
    return $Value
}
function Test-MockHudScreen {
    # 화면 모형의 HUD(Home/End/ESC) - 필드·던전 안에서 보임
    return (($script:screen -eq 'field') -or ($script:screen -eq 'inside'))
}
# 화면 모형 $script:screen: selection(어비스 선택 화면 - 시작 판독 전부 음성) · inside(던전 안 HUD + 추적기) · field(필드 HUD) · menu(필드에서 연 ESC 메뉴) ·
#   prompt(클리어 문구) · reward(보상 화면 나가기). 클릭 모의가 ESC·'어비스' 자리로 전이를 정합니다(test_abyss_return_loop 와 같은 좌표·전이)
#   단계 2.5 (선분기 행): ready(파티 준비 패널 - HUD 가림) · matching(재매칭 패널) · popup(권장 인원 팝업) · entry-waiting(접힌 준비 패널) · detail(등록 던전 상세
#   화면 - 제목이 읽힘) · loading(알 수 없음 - 판독 전부 음성). 하단(clearAndExitText) 판독문은 S 판정이 스태시에 두는 실측 모양(아래 Get-MockBottomText)이고,
#   선분기의 순수 서명 함수(실제)가 그 글자로 보상 3버튼·접힌 패널·팝업을 가립니다
function Get-MockBottomText {
    # 화면 모형의 하단 판독문 - 실측 모양(보상 3버튼·접힌 패널·팝업은 워커 서명 함수 주석의 실측 판독 · 클리어 문구는 S 판정의 조합). 그 밖 화면은 빈 판독
    switch ([string]$script:screen) {
        'prompt' { return '화면을터치해주세요' }
        'reward' { return '아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기' }
        'entry-waiting' { return '아이템을누르면상세정보를수있습니다나가기입장대기중' }
        'popup' { return '㉬취소Space도전하기' }
    }
    return ''
}
function Test-DungeonClearPrompt {
    # S 판정(실제 서명) - 판독문 스태시(실제 함수처럼 모든 반환 전에 - 캡처 실패면 빈 값)
    param([System.Diagnostics.Process]$Game)
    $bottomText = Get-MockBottomText
    $promptNow = [bool](Read-MockScreen 'Test-DungeonClearPrompt' ($script:screen -eq 'prompt'))
    $script:lastClearPromptText = $(if ($script:capfailPersist) { '' } else { $bottomText })
    return $promptNow
}
function Test-ExitButton {
    param([System.Diagnostics.Process]$Game)
    return [bool](Read-MockScreen 'Test-ExitButton' ($script:screen -eq 'reward'))
}
function Get-AbyssPanelKind {
    # 패널 종류(준비 > 재매칭 - 실제 함수와 같은 순서). 캡처 실패면 'none'
    param([System.Diagnostics.Process]$Game)
    $panelKind = 'none'
    if ($script:screen -eq 'ready') { $panelKind = 'ready' } elseif ($script:screen -eq 'matching') { $panelKind = 'matching' }
    return [string](Read-MockScreen 'Get-AbyssPanelKind' $panelKind 'none')
}
function Test-AbyssEntryWaiting {
    param([System.Diagnostics.Process]$Game)
    return [bool](Read-MockScreen 'Test-AbyssEntryWaiting' ($script:screen -eq 'entry-waiting'))
}
function Test-AbyssKnownDetailScreen {
    # 등록 던전 상세 화면(제목 판독 - 실제 함수는 판독 뒤 캡처 실패면 거짓)
    param([System.Diagnostics.Process]$Game)
    return [bool](Read-MockScreen 'Test-AbyssKnownDetailScreen' ($script:screen -eq 'detail'))
}
function Test-DungeonEntered {
    param([System.Diagnostics.Process]$Game)
    return [bool](Read-MockScreen 'Test-DungeonEntered' (Test-MockHudScreen))
}
function Test-HomeEndEscHud {
    param([System.Diagnostics.Process]$Game)
    return [bool](Read-MockScreen 'Test-HomeEndEscHud' (Test-MockHudScreen))
}
function Test-InDungeonQuest {
    param([System.Diagnostics.Process]$Game)
    $questInside = [bool](Read-MockScreen 'Test-InDungeonQuest' ($script:screen -eq 'inside'))
    $script:lastQuestTrackerText = $(if ($questInside) { 'INSIDEMOCK' } else { 'FIELDMOCK' })
    return $questInside
}
function Test-AbyssMenu {
    param([System.Diagnostics.Process]$Game)
    $menuOpen = [bool](Read-MockScreen 'Test-AbyssMenu' ($script:screen -eq 'menu'))
    $script:lastAbyssMenuSignal = $(if ($menuOpen) { 'abyss-text' } else { '' })
    return $menuOpen
}
function Test-AbyssSelectionScreen {
    param([System.Diagnostics.Process]$Game)
    return [bool](Read-MockScreen 'Test-AbyssSelectionScreen' ($script:screen -eq 'selection'))
}
function Test-NoticeBoardPopup {
    param([System.Diagnostics.Process]$Game)
    return [bool](Read-MockScreen 'Test-NoticeBoardPopup' $false)
}
function Test-CaptureRecovered {
    # 복구 탐침(입력 없는 캡처 1회)
    param([System.Diagnostics.Process]$Game)
    $script:probeCalls++
    return [bool](Read-MockScreen 'Test-CaptureRecovered' $true)
}
function Clear-EventOverlay {
    # 이벤트 화면 정리 - 정리할 것 없음(부른 수만)
    param([System.Diagnostics.Process]$Game)
    $script:eventOverlayCalls++
    return $false
}
function Invoke-PurchasePopupSweep {
    param([System.Diagnostics.Process]$Game)
    return $false
}
function Invoke-EventSkipOrConfirm {
    param([System.Diagnostics.Process]$Game, [string]$LogPrefix = '', $Outcome = $null)
    [void](Read-MockScreen 'Invoke-EventSkipOrConfirm' $false)
    return $false
}
function Close-GhostRegisterPrompt {
    param([System.Diagnostics.Process]$Game, [string]$LogPrefix = '')
    return $false
}
function Get-GameRegionOcrText {
    param([System.Diagnostics.Process]$Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3, $Engine = $null, [switch]$BinaryWhiteText)
    [void](Read-MockScreen 'Get-GameRegionOcrText' $true)
    return ''
}
function Find-AbyssMenuIconPoint {
    # 메뉴 '어비스' 아이콘 탐색 - 이 화면 모형은 메뉴 글자를 늘 읽으므로 부르지 않습니다(불렸다면 미발견)
    param([System.Diagnostics.Process]$Game)
    $script:iconCalls++
    return [pscustomobject]@{ Status = 'not-found'; Point = $null; Score = 0.5; Second = 0.5; Size = 28; CenterX = 0.0; CenterY = 0.0; ElapsedMs = 0; FirstUse = $false; Window = 'mock' }
}
function Invoke-AutoRefocus {
    param([System.Diagnostics.Process]$Game)
    return $false
}
function Write-LifeDiagnostics {
    param([System.Diagnostics.Process]$Game, [string]$Context, [switch]$CaptureOnly, [switch]$WithLogCopy)
    $script:diagCalls++
    $script:diagRecords.Add(('{0}|{1}|{2}' -f $Context, [bool]$CaptureOnly, [bool]$WithLogCopy))   # 문맥 · 두 스위치 (구현 단위 복귀 연장 R2-F3)
}
function Focus-Game {
    param([System.Diagnostics.Process]$Game)
}
function Move-CursorOutsideGame {
    param([System.Diagnostics.Process]$Game)
}
function Find-GameTextPoint {
    # 글자 위치 - 입장 직후 구매 팝업 '닫기' 는 없음('' 판독), 'ESC' 는 HUD 화면, '어비스' 는 메뉴 화면에서 고정 자리
    param([System.Diagnostics.Process]$Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [string]$SearchText,
        [string]$ExactText = '', [int]$Scale = 3, $Engine = $null, [switch]$BinaryWhiteText, [string[]]$ExcludeText = @())
    if ($SearchText -eq 'ESC') {
        if ([bool](Read-MockScreen 'Find-GameTextPoint:ESC' (Test-MockHudScreen))) { return @{ X = $MOCK_ESC_POINT.X; Y = $MOCK_ESC_POINT.Y } }
        return $null
    }
    if ($SearchText -eq '어비스') {
        if ([bool](Read-MockScreen 'Find-GameTextPoint:어비스' ($script:screen -eq 'menu'))) { return @{ X = $MOCK_ABYSS_POINT.X; Y = $MOCK_ABYSS_POINT.Y } }
        return $null
    }
    [void](Read-MockScreen ('Find-GameTextPoint:' + $SearchText) $true)
    return $null
}
function Send-MockClick {
    # 클릭 전송(늘 보냄) - ESC 자리: 필드 → 메뉴(양보 주입이 예약돼 있으면 그만큼 '조작 중' 을 이어 붙임) / '어비스' 자리: 메뉴 → 선택 화면(안전 중지 예약 주입 - F2)
    param([int]$X, [int]$Y)
    $script:lastClickPerformed = $true
    $script:lastClickSkipReason = ''
    if (($X -eq $MOCK_ESC_POINT.X) -and ($Y -eq $MOCK_ESC_POINT.Y)) {
        $script:escClicks++
        $script:events.Add('esc-click')
        if ($script:screen -eq 'field') { $script:screen = 'menu' }
        for ($yieldIndex = 0; $yieldIndex -lt [int]$script:yieldAfterEsc; $yieldIndex++) { $script:activeQueue.Add($true) }
        $script:yieldAfterEsc = 0
    } elseif (($X -eq $MOCK_ABYSS_POINT.X) -and ($Y -eq $MOCK_ABYSS_POINT.Y)) {
        $script:abyssClicks++
        $script:events.Add('abyss-click')
        if ($script:screen -eq 'menu') { $script:screen = 'selection' }
        if ($script:flagOnAbyssClick) { $script:safeStopFlag = $true }
    } else {
        $script:otherClicks++
    }
}
function Click-ScreenPoint {
    param([int]$X, [int]$Y)
    Send-MockClick -X $X -Y $Y
}
function Click-GamePoint {
    param([System.Diagnostics.Process]$Game, [int]$ReferenceX, [int]$ReferenceY)
    Send-MockClick -X $ReferenceX -Y $ReferenceY
}
function Press-KeyOnce {
    param([byte]$VirtualKey)
    $script:keyOnceCalls++
}
function Test-UserRecentlyActive {
    # 조작 - 예약된 순서(앞에서부터 하나씩), 없으면 조작 없음
    param([int]$IdleMs = 2500)
    if ($script:activeQueue.Count -gt 0) {
        $activeNow = [bool]$script:activeQueue[0]
        $script:activeQueue.RemoveAt(0)
        return $activeNow
    }
    return $false
}
function Wait-UserYieldEnd {
    # 양보 대기 - 가상 3초 흘리고 양보 누적(운영 Wait-UserYieldEnd 계약 - 복귀 루프의 출처·마감 대조가 이 값을 봄)
    param([System.Diagnostics.Process]$Game, [string]$Context = '')
    $script:yieldWaits++
    $script:vclock = $script:vclock.AddMilliseconds(3000)
    $script:userYieldTotalMs = [double]$script:userYieldTotalMs + 3000
    Update-MockScreenTimeline
}
function Press-KeyVerified {
    # 키 전송(실제 서명) - ESC(0x1B) 는 복귀 루프의 메뉴 닫기(화면 모형 - menuSticky 면 게임이 무시), 그 밖은 입장 직후 키 스파이:
    # 누른 키 · 그 순간 열쇠 항목의 디스크 index · 결과 계획(기본 참) · '전송 직후' crash 주입(AE1)
    param([System.Diagnostics.Process]$Game, [byte]$VirtualKey, [string]$Label = '')
    if ([int]$VirtualKey -eq 27) {
        $script:menuCloseKeys++
        if (($script:screen -eq 'menu') -and (-not $script:menuSticky)) { $script:screen = 'field' }
        return $true
    }
    $pressedKey = [int]$VirtualKey
    $script:keyPresses.Add($pressedKey)
    $script:rowPresses.Add($pressedKey)
    $script:keyPressTrace.Add(('{0}@{1}' -f $pressedKey, (Get-DiskIndexText -Nonce ([string]$script:handoff.Nonce))))
    $script:events.Add('press:' + $pressedKey)
    $pressResult = $true
    if ($script:pressResults.ContainsKey($pressedKey)) { $pressResult = [bool]$script:pressResults[$pressedKey] }
    if ($script:crashAfterPress -eq $pressedKey) {
        $script:crashAfterPress = -1
        throw ('CRASH-AFTER-SEND-' + $pressedKey)
    }
    return $pressResult
}
function Wait-ForDungeonClearScreen {
    # 클리어 대기 - 행이 정한 결과: clear(클리어 문구) · reward(보상 화면) · left(사망 화면 퇴장 - 필드·던전 안 지정) · crash(끊김 흉내 예외) ·
    # unknown-deadline(클리어 대기 불명 마감 - 워커 원문의 표지 없는 [완료] 줄 그대로 + 코드 4, OK11) · error(코드 1 흉내 예외 - 클리어 대기 마감 throw 모양,
    # 본류 조각 밖으로 전파 · OK13) · halt(관심 구간 끝 - 행이 키 지점까지만 볼 때)
    param([System.Diagnostics.Process]$Game, [int]$TimeoutSeconds = 300, [switch]$DungeonMode, [scriptblock]$FindResultButton, [switch]$MemberMode)
    $script:events.Add('clearwait:' + $script:clearPlan)
    switch ($script:clearPlan) {
        'clear' { $script:screen = 'prompt'; return 'clear' }
        'reward' { $script:screen = 'reward'; return 'reward' }
        'left' {
            $script:screen = $script:leftScreen
            return 'left'
        }
        'crash' { throw 'CRASH-CLEAR-WAIT' }
        'error' { throw 'ERROR-CLEAR-WAIT' }
        'unknown-deadline' {
            Write-RunLog $CLEAR_WAIT_UNKNOWN_LINE
            Stop-WorkerTailExit 4
        }
        default { throw $HALT_MESSAGE }
    }
}
function Invoke-ClickUntil {
    # 상태 기반 재클릭 헬퍼 - 클리어 화면 터치 뒤 보상 화면
    param([System.Diagnostics.Process]$Game, [int[]]$Point, [scriptblock]$Condition, [scriptblock]$SourceCondition, [string]$Description,
        [int]$TimeoutSeconds = 20, [int]$ReclickEverySeconds = 5, [int[]]$FallbackPoint, [scriptblock]$FallbackCondition)
    $script:events.Add('click-until')
    if ($script:screen -eq 'prompt') { $script:screen = 'reward' }
}
function Invoke-AbyssExitClick {
    # 보상 화면 '나가기' 헬퍼 - 기본은 나가기 → 필드. 'missing' 은 헬퍼 안의 '나가기 위치 미발견' 코드 4(run:6164)를 같은 종료 흉내로
    param([System.Diagnostics.Process]$Game, [string]$LogPrefix = '[어비스]', [string]$Context = '나가기 클릭', $ParentDeadline = $null)
    $script:exitClickCalls++
    $script:events.Add('exit-click')
    if ($script:exitClickMode -eq 'missing') {
        Write-RunLog "[완료] (모의) 보상 화면 '나가기' 위치 미발견 - 정지"
        Stop-WorkerTailExit 4
    }
    if ($script:screen -eq 'reward') { $script:screen = 'field' }
    return @{ Result = 'clicked'; FrozenMs = 0 }
}
function Complete-AbyssOtherSelection {
    # '다른 던전 가기' 끝(구현 명세 ⑤b5 - 본류 보상 화면 꼬리의 'other' 갈래가 부름). 이 하니스는 그 안(대기 · 확인 · 폴백)을 모형하지 않습니다 - 행이
    # $script:otherEndCrash 를 세우면 'confirmed' 뒤 exit 전 끊김을 흉내 내는 예외(R6-RC1 의 워커 1), 아니면 닿으면 안 됨(다른 행은 모드 입력이 없어 경로 거짓 - 옛 나가기)
    param(
        [System.Diagnostics.Process]$Game,
        [ValidateSet('ready', 'rematch-cancelled')][string]$Ending = 'ready',
        [string]$Nonce = ''
    )
    $script:events.Add('other-end:' + $Ending)
    if ($script:otherEndCrash) { throw $OTHER_END_CRASH_MESSAGE }
    throw 'TEST-UNREACHABLE: Complete-AbyssOtherSelection'
}
function Complete-AbyssRetrySelection {
    # '다시 하기' 끝(구현 명세 ⑤b5) - 이 파일의 행은 '다시 하기' 결정에 닿지 않습니다(닿으면 행 예외로 드러남)
    param(
        [System.Diagnostics.Process]$Game,
        [string]$Nonce
    )
    throw 'TEST-UNREACHABLE: Complete-AbyssRetrySelection'
}
function Write-RunLog {
    # 워커 로그(실제 서명 param([string]$Message)) - 줄을 모으고, 결합 층이면 임시 로그 파일에도 덧붙입니다(최상위 catch 의 오류 로그 사본 원본 - 명세 3.3)
    param([string]$Message)
    $script:workerLogLines.Add($Message)
    if ($script:runLogTargetPath) {
        [IO.File]::AppendAllText($script:runLogTargetPath, (('{0} {1}' -f $script:vclock.ToString('HH:mm:ss'), $Message) + "`r`n"), $UTF8_PLAIN)
    }
}
# GUI 모의 · 컨트롤 모형
function Add-GuiLog {
    param([string]$Message)
    $script:guiEvents.Add('gui|' + $Message)
}
function Stop-AllRun {
    param([string]$Reason, [switch]$IsError)
    $script:guiEvents.Add(('stop|{0}|{1}' -f $Reason, [bool]$IsError))
}
function Get-CustomCurrentContext {
    # 디스크 진행 컨텍스트 - 행의 컨텍스트(코드 10 끝 처리의 소비 owner)
    param([string]$SectionName = '')
    return $script:diskContext
}
$lblStatus = [pscustomobject]@{ Text = ''; ForeColor = $null }
$script:customConfigSection = $ABYSS_SECTION   # 시작 게이트 S3 가 어비스 커스텀 시작으로 보는 섹션(GUI 원문 변수)
$script:abyssPartyRetryEnabled = $false        # 재입장 재개 기능 - ② 빌드는 꺼짐(GUI 사본 gui:2332)
$rbCatAbyss = [pscustomobject]@{ Checked = $true }
$rbModeParty = [pscustomobject]@{ Checked = $false }
$rbAbyssPartyMember = [pscustomobject]@{ Checked = $false }

# ===== 감시 =====
function Enter-SpyCall {
    # 감시 머리 - 호출 기록(이름별) · 'N번째 호출 throw' 갈고리(그 저장에만) · 행의 앞 갈고리 · 스텁이면 $true(실제 함수를 부르지 않음)
    param([string]$Name, $Bound)
    $script:spyCounts[$Name] = [int]$script:spyCounts[$Name] + 1
    switch ($Name) {
        'Close-AbyssKeyEntryOnLeave' {
            $closeText = ('{0}|{1}' -f [string]$Bound['Reason'], [string]$Bound['Screen'])
            $script:closeCalls.Add($closeText)
            $script:events.Add('close:' + $closeText)
        }
        'Return-ToAbyssSelection' {
            $leaveText = '(인자 없음)'
            if ($Bound.ContainsKey('LeaveEntryReason')) { $leaveText = [string]$Bound['LeaveEntryReason'] }
            $script:returnCalls.Add(('{0}|{1}' -f [string]$Bound['SafeStopExitCode'], $leaveText))
        }
        'Invoke-AfterEntryKeys' { $script:keyCalls.Add($(if ($Bound.ContainsKey('KeyContract')) { 'contract' } else { 'plain' })) }
        'Write-AbyssJournalTempFile' { $script:tempWrites++ }
        'Add-AbyssJournalClearedEntry' { $script:seqBeforeCleared = Get-DiskSeq }
        'Close-AbyssOwnEntryBeforeEntry' {
            $script:ownCloseCalls.Add([string]$Bound['Screen'])
            $script:events.Add('own-close:' + [string]$Bound['Screen'])
        }
        'Stop-AbyssHandoffOverlay' { $script:overlayStops.Add([string]$Bound['Kind']) }
    }
    $hook = $script:throwHook
    if (($null -ne $hook) -and ([string]$hook.Name -eq $Name) -and [bool](& $hook.Match $Bound)) {
        $script:throwHook = $null
        $script:throwFired++
        throw ([string]$hook.Message)
    }
    if ($script:spyPre.ContainsKey($Name)) { [void](& $script:spyPre[$Name] $Bound) }
    $isStub = [bool]$script:spyStub[$Name]
    if (($Name -eq 'Close-AbyssKeyEntryOnLeave') -and (-not $isStub)) { $script:inClose = $true }
    if (($Name -eq 'Close-AbyssOwnEntryBeforeEntry') -and (-not $isStub)) { $script:inOwnClose = $true }
    return $isStub
}
function Exit-SpyCall {
    # 감시 꼬리 - 결과 기록(저장 태그 · 인덱스 기록 · 생성 · 키 결과 · Consume-Handoff 뒤 파일 상태) · 행의 뒤 갈고리
    param([string]$Name, $Bound, [object[]]$Output)
    switch ($Name) {
        'Update-AbyssJournal' {
            $tagText = '(출력 없음)'
            if ((@($Output).Count -gt 0) -and ($null -ne $Output[0])) { $tagText = [string]$Output[0].Tag }
            $script:updateTags.Add($tagText)
            if ($script:inClose) { $script:closeUpdateTags.Add($tagText) }
            if ($script:inOwnClose) { $script:ownCloseUpdateTags.Add($tagText) }
        }
        'Set-AbyssAfterEntryIndex' {
            $setText = ('{0}:{1}' -f [string]$Bound['Index'], (Format-OutputValues -Outputs $Output))
            $script:setCalls.Add($setText)
            $script:events.Add('set:' + $setText)
        }
        'Add-AbyssJournalEnteredEntry' {
            $enteredText = Format-OutputValues -Outputs $Output
            $script:enteredTags.Add($enteredText)
            $script:events.Add('entered:' + $enteredText)
            if ($enteredText -eq 'changed') {
                $createdNonce = [string]$script:handoff.Nonce
                [void](Get-NonceLabel -Nonce $createdNonce)
                $script:createdSnapshot = Get-DiskEntry -Nonce $createdNonce
            }
        }
        'Invoke-AfterEntryKeys' { $script:keyOutcomes.Add((Format-Outputs -Outputs $Output)) }
        'Consume-Handoff' { $script:stateAfterConsume = Get-FolderState -Folder $script:journalFolder }
        'Close-AbyssKeyEntryOnLeave' { $script:inClose = $false }
        'Close-AbyssOwnEntryBeforeEntry' { $script:inOwnClose = $false }
        'Add-AbyssJournalClearedEntry' { $script:seqAfterCleared = Get-DiskSeq }
        'Resolve-HandoffEnvForContext' {
            if ((@($Output).Count -gt 0) -and ($null -ne $Output[0])) { $script:resolveResults.Add(('{0}/{1}' -f [string]$Output[0].Status, [string]$Output[0].Kind)) }
        }
    }
    if ($script:spyPost.ContainsKey($Name)) { [void](& $script:spyPost[$Name] $Bound $Output) }
}
# 감시 정의 - 실제 함수의 매개변수 블록을 복사합니다(정의가 없으면 추출 FAIL - 그 감시를 쓰는 행 묶음은 건너뜀)
foreach ($spyName in @($BUNDLE_SPY_NAMES + $WORKER_SPY_NAMES + $HANDOFF_SPY_NAMES)) {
    $spySource = $null
    if ($bundleFunctions.ContainsKey($spyName)) { $spySource = $bundleFunctions[$spyName] }
    elseif ($workerExtracted.Contains($spyName)) { $spySource = $workerTopFunctions[$spyName] }
    if ($null -eq $spySource) { $extractionProblems.Add("감시 대상 $spyName 의 실제 정의가 없습니다"); continue }
    Invoke-Expression (New-SpyText -Name $spyName -FunctionAst $spySource)
}
foreach ($spyName in $GUI_SPY_NAMES) {
    if ($guiFunctions.ContainsKey($spyName)) { Invoke-Expression (New-SpyText -Name $spyName -FunctionAst $guiFunctions[$spyName]) }
}

# ===== 픽스처 =====
$testRootFolder = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_after_entry_' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRootFolder)
$safeStopFlagPath = Join-Path $testRootFolder 'safe_stop.flag'   # 파일을 만들지 않습니다 - Test-Path·Remove-Item 가로채기가 이 경로만 봅니다
$originalEnv = @{}
foreach ($envName in $TOUCHED_ENV_NAMES) { $originalEnv[$envName] = [Environment]::GetEnvironmentVariable($envName, 'Process') }

function Set-ProcessEnv {
    # 이 프로세스의 env 하나 - 빈 값이면 지웁니다(워커는 없음과 빈 값을 같게 읽음)
    param([string]$Name, [string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { [Environment]::SetEnvironmentVariable($Name, $null, 'Process') }
    else { [Environment]::SetEnvironmentVariable($Name, $Value, 'Process') }
}

function Get-FolderState {
    # 폴더의 파일 이름·SHA-256 앞 12자 목록 ('파일 불변' 단언용 - 잠금·임시·손상 증거 파일이 생겨도 드러남. 폴더는 빼고 봄)
    param([string]$Folder)
    if ([string]::IsNullOrEmpty($Folder) -or -not [IO.Directory]::Exists($Folder)) { return '(폴더 없음)' }
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

function Get-FileHashText {
    # 파일 하나의 SHA-256 앞 12자 (없으면 '(없음)')
    param([string]$Path)
    if (-not [IO.File]::Exists($Path)) { return '(없음)' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($Path))).Replace('-', '').Substring(0, 12)) } finally { $sha.Dispose() }
}

function Close-HeldStreams {
    foreach ($heldStream in $script:heldStreams) { $heldStream.Dispose() }
    $script:heldStreams.Clear()
}

function Lock-Journal {
    # 완료 기록 잠금 점유 - 같은 프로세스가 .lock 을 쥡니다(⑱′ CH3 와 같은 상태 - 저장소는 합산 예산 뒤 'locked')
    $lockPath = [IO.Path]::ChangeExtension($script:abyssJournalPath, '.lock')
    $script:heldStreams.Add((New-Object System.IO.FileStream($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)))
}

function New-LockFolder {
    # 읽기·쓰기 실패(io-failed) - .lock 자리에 폴더를 둬 잠금 파일을 만들 수 없게 합니다(⑱′ CH4 와 같은 상태)
    [void][IO.Directory]::CreateDirectory(([IO.Path]::ChangeExtension($script:abyssJournalPath, '.lock')))
}

function Remove-LockFolder {
    if ([string]::IsNullOrEmpty($script:abyssJournalPath)) { return }
    $lockPath = [IO.Path]::ChangeExtension($script:abyssJournalPath, '.lock')
    if ([IO.Directory]::Exists($lockPath)) { [IO.Directory]::Delete($lockPath, $true) }
}

function Write-CorruptJournal {
    # 본 파일·직전본 둘 다 손상(저장소 읽기 'corrupt')
    [IO.File]::WriteAllText($script:abyssJournalPath, $CORRUPT_MAIN_TEXT, $UTF8_BOM)
    [IO.File]::WriteAllText(($script:abyssJournalPath + '.bak'), $CORRUPT_BAK_TEXT, $UTF8_BOM)
}

function Write-FixtureJournal {
    # 완료 기록 파일을 실제 직렬화(ConvertTo-AbyssJournalText)로 씁니다 (UTF-8 BOM - 저장소와 같은 인코딩)
    param([object[]]$Entries = @(), [object[]]$Applied = @(), [long]$Seq = 5, [string]$Path = '', [string]$SavedBy = 'worker:1234')
    if (-not $Path) { $Path = $script:abyssJournalPath }
    $journal = New-AbyssJournalEmpty
    $journal.seq = $Seq
    $journal.savedAt = '2026-10-13T09:00:00.0000000+09:00'
    $journal.savedBy = $SavedBy
    $journal.entries = [object[]]@($Entries)
    $journal.applied = [object[]]@($Applied)
    [IO.File]::WriteAllText($Path, (ConvertTo-AbyssJournalText -Journal $journal), $UTF8_BOM)
}

function Edit-DiskJournal {
    # 디스크 완료 기록을 직접 고칩니다(잠금 없이 - 주입 전용, 같은 프로세스 한 스레드): 읽기 → 고치기 → 정규화 → 실제 직렬화 → 쓰기(seq 그대로)
    param([scriptblock]$Edit)
    $journal = [IO.File]::ReadAllText($script:abyssJournalPath) | ConvertFrom-Json
    [void](& $Edit $journal)
    $journal = ConvertTo-AbyssJournalNormalized -Journal $journal
    [IO.File]::WriteAllText($script:abyssJournalPath, (ConvertTo-AbyssJournalText -Journal $journal), $UTF8_BOM)
}

function Set-DiskAfterIndex {
    # AE5 - 그 nonce 항목의 afterEntry.index 를 바꿔 둡니다(다른 기동이 먼저 기록한 모양)
    param([string]$Nonce, [int]$Index)
    $script:editNonce = $Nonce
    $script:editIndex = $Index
    Edit-DiskJournal -Edit { param($journal) foreach ($entry in @($journal.entries)) { if ([string]$entry.nonce -eq $script:editNonce) { $entry.afterEntry.index = $script:editIndex } } }
}

function Remove-DiskEntry {
    # AE6 · N1 - 그 nonce 항목을 지웁니다(stale 정리 뒤 모양)
    param([string]$Nonce)
    $script:editNonce = $Nonce
    Edit-DiskJournal -Edit { param($journal) $journal.entries = [object[]]@(@($journal.entries) | Where-Object { [string]$_.nonce -ne $script:editNonce }) }
}

function Set-DiskEntryClosed {
    # N2 - 그 nonce 항목을 이미 닫힌 모양으로(launchState done · reason · screen)
    param([string]$Nonce, [string]$Reason, [string]$Screen)
    $script:editNonce = $Nonce
    $script:editReason = $Reason
    $script:editScreen = $Screen
    Edit-DiskJournal -Edit { param($journal)
        foreach ($entry in @($journal.entries)) {
            if ([string]$entry.nonce -ne $script:editNonce) { continue }
            $entry.launchState = 'done'
            $entry.reason = $script:editReason
            $entry.screen = $script:editScreen
        }
    }
}

function Write-BakMarker {
    # N1·N2 - 직전본(.bak)을 본 파일과 다른 표지 내용(유효 journal · 작성자 표지 · seq 0)으로 둡니다. 쓰기(Replace)가 일어나면 직전본이 본 파일 내용으로 바뀝니다
    Write-FixtureJournal -Path ($script:abyssJournalPath + '.bak') -Seq 0 -SavedBy $BAK_MARKER_SAVED_BY
}

function New-FixtureEntry {
    # 완료 기록 항목 픽스처 - 실제 New-AbyssJournalEntry 기본값 위에 필요한 필드만 (⑱′ 와 같은 모양)
    param([string]$Stage, [string]$Nonce, $Owner, $NextOwner = $null, [int]$Generation = 0, [string]$LaunchState = 'launched',
        [string]$Section = '', [string]$RunId = '', $Decision = $null, [int]$AfterIndex = 0, $AfterTotal = $null, $AfterKeys = $null,
        [bool]$CleanupOnly = $false)
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
    return $entry
}

function New-AbyssContext {
    # Get-CustomCurrentContext 반환 모양의 어비스 커스텀 컨텍스트 (순차 · 목록 = $ABYSS_ITEMS - ⑱′ 와 같은 모양)
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

function Get-RowCanonicalOwner {
    # 이 행 owner(커스텀 = GUI 원문 Get-CustomCanonicalOwner 의 6필드 · 비커스텀 = { runId })
    param([int]$OwnerIndex = 0)
    if ($script:rowCustom) { return (Get-CustomCanonicalOwner -Context (New-AbyssContext -Index $OwnerIndex -Generation $CONTEXT_GENERATION)) }
    return @{ runId = [string]$script:rowRunId }
}

function New-RowOwnEntry {
    # 이 행 owner 의 자기 항목 픽스처(워커가 입장 때 쓰는 모양: entered · launched · afterEntry {index, 2, [32,66]}). -OwnerIndex 1 = 다른 항목 owner(stale)
    param([string]$Nonce, [int]$AfterIndex = 2, [int]$OwnerIndex = 0, [string]$LaunchState = 'launched', [string]$Stage = 'entered',
        [string]$Reason = '', [string]$Screen = '', [switch]$WithoutScreen)
    if ($script:rowCustom) {
        $ownerFields = ConvertTo-FiveFieldOwner (Get-RowCanonicalOwner -OwnerIndex $OwnerIndex)
        $entry = New-FixtureEntry -Stage $Stage -Nonce $Nonce -Owner $ownerFields -Generation $CONTEXT_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' `
            -LaunchState $LaunchState -AfterIndex $AfterIndex -AfterTotal 2 -AfterKeys @(32, 66)
    } else {
        $ownerRunId = $(if ($OwnerIndex -eq 0) { [string]$script:rowRunId } else { 'run-old' })
        $entry = New-FixtureEntry -Stage $Stage -Nonce $Nonce -Owner ([pscustomobject]@{ runId = $ownerRunId }) -RunId $ownerRunId -LaunchState $LaunchState `
            -AfterIndex $AfterIndex -AfterTotal 2 -AfterKeys @(32, 66)
    }
    $entry.reason = $Reason
    $entry.screen = $Screen
    if ($WithoutScreen) {
        $entry.PSObject.Properties.Remove('screen')
        $entry.PSObject.Properties.Remove('reason')
    }
    return $entry
}

# ===== 디스크 읽기 · 표시 =====
function Read-DiskJournal {
    # 디스크의 완료 기록(본 파일)을 저장소를 거치지 않고 그대로 읽음 - 없음 $null / 손상 'corrupt'
    if ([string]::IsNullOrEmpty($script:abyssJournalPath) -or -not [IO.File]::Exists($script:abyssJournalPath)) { return $null }
    try { return ([IO.File]::ReadAllText($script:abyssJournalPath) | ConvertFrom-Json -ErrorAction Stop) } catch { return 'corrupt' }
}

function Get-DiskEntry {
    param([string]$Nonce)
    $journal = Read-DiskJournal
    if (($null -eq $journal) -or ($journal -is [string])) { return $null }
    foreach ($entry in @($journal.entries)) { if ([string]$entry.nonce -eq $Nonce) { return $entry } }
    return $null
}

function Get-DiskIndexText {
    param([string]$Nonce)
    $entry = Get-DiskEntry -Nonce $Nonce
    if ($null -eq $entry) { return '(항목 없음)' }
    return [string]$entry.afterEntry.index
}

function Get-DiskSeq {
    $journal = Read-DiskJournal
    if (($null -eq $journal) -or ($journal -is [string])) { return '(없음)' }
    return [string]$journal.seq
}

function Get-DiskAppliedText {
    $journal = Read-DiskJournal
    if (($null -eq $journal) -or ($journal -is [string])) { return '(없음)' }
    return ((@($journal.applied) | ForEach-Object { Get-NonceLabel ([string]$_) }) -join ',')
}

function Get-DiskStageCount {
    param([string]$Stage)
    $journal = Read-DiskJournal
    if (($null -eq $journal) -or ($journal -is [string])) { return -1 }
    return @(@($journal.entries) | Where-Object { [string]$_.stage -eq $Stage }).Count
}

function Get-DiskKeysShape {
    # 항목 afterEntry.keys 의 JSON 왕복 모양 - 'array(n)=값들' / 'scalar=값' / 'null' (명세 5절 B3 - 1개·0개 배열이 배열로 남는가)
    param([string]$Nonce)
    $entry = Get-DiskEntry -Nonce $Nonce
    if ($null -eq $entry) { return '(항목 없음)' }
    $keysValue = $entry.afterEntry.keys
    if ($null -eq $keysValue) { return 'null' }
    if ($keysValue -is [array]) { return ('array({0})={1}' -f $keysValue.Count, ((@($keysValue) | ForEach-Object { [string]$_ }) -join ',')) }
    return ('scalar=' + [string]$keysValue)
}

function Format-DiskEntry {
    # 항목 → 'stage/launchState/index/total/keys/cleanupOnly/reason/screen' (필드 없음 = '(없음)')
    param($Entry)
    if ($null -eq $Entry) { return '(항목 없음)' }
    $keysValue = $Entry.afterEntry.keys
    $keysText = $(if ($null -eq $keysValue) { 'null' } else { '[' + ((@($keysValue) | ForEach-Object { [string]$_ }) -join ',') + ']' })
    $totalText = $(if ($null -eq $Entry.afterEntry.total) { 'null' } else { [string]$Entry.afterEntry.total })
    $cleanupText = $(if ($null -eq $Entry.PSObject.Properties['cleanupOnly']) { '(없음)' } else { [string][bool]$Entry.cleanupOnly })
    $reasonText = $(if ($null -eq $Entry.PSObject.Properties['reason']) { '(없음)' } else { [string]$Entry.reason })
    $screenText = $(if ($null -eq $Entry.PSObject.Properties['screen']) { '(없음)' } else { [string]$Entry.screen })
    return ('{0}/{1}/{2}/{3}/{4}/{5}/{6}/{7}' -f $Entry.stage, $Entry.launchState, $Entry.afterEntry.index, $totalText, $keysText, $cleanupText, $reasonText, $screenText)
}

function Get-EntryJson {
    # 항목 필드 전부(한 줄 JSON) - '필드 전부 불변' 단언
    param($Entry)
    if ($null -eq $Entry) { return '(항목 없음)' }
    return ($Entry | ConvertTo-Json -Compress -Depth 10)
}

function Get-OpenEnteredText {
    # 이 행 owner 의 열린 entered(launchState ≠ done) nonce 표시 목록 - 'owner 당 열린 항목 ≤ 1' 단언
    $journal = Read-DiskJournal
    if (($null -eq $journal) -or ($journal -is [string])) { return '(없음)' }
    $owner = Get-RowCanonicalOwner -OwnerIndex 0
    $generation = $(if ($script:rowCustom) { $CONTEXT_GENERATION } else { 0 })
    $labels = foreach ($entry in @($journal.entries)) {
        if (([string]$entry.stage -ne 'entered') -or ([string]$entry.launchState -eq 'done')) { continue }
        if (Invoke-RealTestAbyssJournalOwnerMatch -Entry $entry -Owner $owner -Generation $generation) { Get-NonceLabel ([string]$entry.nonce) }
    }
    return (@($labels) -join ',')
}

function Test-EntryOwnerEquals {
    # 항목의 owner 5필드·세대가 이 행 owner 와 같은가(커스텀) / runId 가 같은가(비커스텀)
    param($Entry)
    if ($null -eq $Entry) { return $false }
    $owner = Get-RowCanonicalOwner -OwnerIndex 0
    if (-not $script:rowCustom) { return ([string]$Entry.owner.runId -eq [string]$owner.runId) }
    return (([string]$Entry.owner.fingerprint -eq [string]$owner.fingerprint) -and ([string]$Entry.owner.orderKey -eq [string]$owner.orderKey) -and
        ([int]$Entry.owner.lap -eq [int]$owner.lap) -and ([int]$Entry.owner.index -eq [int]$owner.index) -and ([string]$Entry.owner.item -eq [string]$owner.item) -and
        ([int]$Entry.generation -eq [int]$owner.generation))
}

function Format-AfterEntry {
    # AfterEntry → '인덱스/키들'(값 없음 'null'). 해시테이블의 'Keys' 항목은 같은 이름 속성과 겹치므로 저장소의 공용 필드 읽기로 읽습니다(⑱′ 와 같음)
    param($AfterEntry)
    if ($null -eq $AfterEntry) { return 'null' }
    $indexField = Get-AbyssJournalField -Object $AfterEntry -Name 'Index'
    $keysField = Get-AbyssJournalField -Object $AfterEntry -Name 'Keys'
    $indexText = $(if ($indexField.Has) { [string]$indexField.Value } else { '(없음)' })
    $keysText = '(없음)'
    if ($keysField.Has) {
        if ($null -eq $keysField.Value) { $keysText = 'null' } else { $keysText = (@($keysField.Value) | ForEach-Object { [string]$_ }) -join ',' }
    }
    return ('{0}/{1}' -f $indexText, $keysText)
}

function Get-HandoffField {
    param([string]$Name)
    $field = Get-AbyssJournalField -Object $script:handoff -Name $Name
    if (-not $field.Has) { return $null }
    return $field.Value
}

function Get-HandoffSummary {
    # $script:handoff → 'Role|Nonce|AfterEntry'
    return ('{0}|{1}|{2}' -f [string](Get-HandoffField 'Role'), (Get-NonceLabel ([string](Get-HandoffField 'Nonce'))), (Format-AfterEntry (Get-HandoffField 'AfterEntry')))
}

function Get-AlertLines {
    # 이 기동 로그의 [완료]·[경고] 줄(열거용 - 호출부 @())
    return @(Get-LinesWithPrefix -Lines @($script:workerLogLines) -Prefixes @('[완료]', '[경고]'))
}

function Get-RowKeyTotals { return (Format-KeyCounts -Keys @($script:rowPresses)) }
function Get-PressTrace { return (@($script:keyPressTrace) -join ',') }
function Get-SetCallsText { return (@($script:setCalls) -join ',') }

function Get-FixtureLabel {
    param([int]$Key)
    foreach ($fixtureKey in $FIXTURE_KEYS) { if ([int]$fixtureKey.Key -eq $Key) { return [string]$fixtureKey.Label } }
    return '(모르는 키)'
}

function Get-KeyLine {
    # 키 줄 기대값 - 형식 문자열에 접두 · 픽스처 라벨 · 실제 Get-KeyDisplayName(소스)의 키 이름
    param([string]$Format, [string]$Prefix, [int]$Key)
    return ($Format -f $Prefix, (Get-FixtureLabel -Key $Key), (Get-KeyDisplayName -VirtualKey $Key))
}

function Get-ErrorLogFiles {
    if ([string]::IsNullOrEmpty($script:logDir) -or -not [IO.Directory]::Exists($script:logDir)) { return @() }
    return @([IO.Directory]::GetFiles($script:logDir, 'error_*.log'))
}

# ===== 행 하니스 =====
function Initialize-Row {
    # 행 공통 준비 - 새 임시 폴더(journal · 로그) · 행 owner(커스텀 컨텍스트 / 비커스텀 실행 id) · 가상 시계 · 행 합계 · GUI 쪽 상태
    param([bool]$Custom = $true)
    Close-HeldStreams
    $rowFolder = Join-Path $testRootFolder ([guid]::NewGuid().ToString('N').Substring(0, 12))
    $script:rowFolder = $rowFolder
    $script:journalFolder = Join-Path $rowFolder 'journal'
    $script:logDir = Join-Path $rowFolder 'log'
    [void][IO.Directory]::CreateDirectory($script:journalFolder)
    [void][IO.Directory]::CreateDirectory($script:logDir)
    $script:abyssJournalPath = Join-Path $script:journalFolder 'abyss_handoff.json'
    $script:markerFilePath = Join-Path $rowFolder 'custom_clear_marker.json'
    $script:runLogTargetPath = ''
    $script:rowCustom = $Custom
    $script:rowRunId = $ROW_RUN_ID
    $script:rowContext = $null
    if ($Custom) { $script:rowContext = New-AbyssContext -Index 0 -Generation $CONTEXT_GENERATION }
    $script:vclock = [datetime]'2026-10-13 12:00:00'
    $script:rowClockStart = $script:vclock
    $script:rowPresses.Clear()
    $script:nonceLabels = @{}
    $script:nonceSerial = 0
    # GUI 쪽 상태 - 첫 기동은 GUI 기동 함수 없이 env 를 직접 둡니다(후보 없는 기동 모양). 다음 기동은 Invoke-GuiLaunch 가 GUI 원문으로
    $script:mainCategory = 'battle'
    $script:customActive = $Custom
    $script:runId = $ROW_RUN_ID
    $script:lastLaunchKind = 'none'
    $script:lastLaunchNonce = ''
    $script:customRecoveryPending = $false
    $script:lastWorkerDoneReason = ''
    $script:diskContext = $script:rowContext
    $script:abyssErrorStreak = 0
    $rbCatAbyss.Checked = $true
    $rbModeParty.Checked = $false
    $rbAbyssPartyMember.Checked = $false
}

function Set-AfterEntryConfig {
    # 픽스처 config(afterEntry.keys = config.json 과 같은 두 키 · 켠 키만 enabled) → 워커 원문 키 목록 해석 문장을 그대로 돌려 $afterEntryActions(스크립트 수준)
    param([int[]]$EnabledKeys = @(32, 66))
    $keyObjects = foreach ($fixtureKey in $FIXTURE_KEYS) { [pscustomobject]@{ key = [int]$fixtureKey.Key; label = [string]$fixtureKey.Label; enabled = ($EnabledKeys -contains [int]$fixtureKey.Key) } }
    $configJson = ([pscustomobject]@{ afterEntry = [pscustomobject]@{ keys = @($keyObjects); keyDelayMs = 500 } } | ConvertTo-Json -Depth 5)
    $script:config = $configJson | ConvertFrom-Json
    $null = . $script:afterEntryActionsBlock
    $script:afterEntryActions = $afterEntryActions
}

function Set-WorkerLaunchState {
    # 워커 기동 상태 - 운영과 같은 순서: 커스텀 초기값(소스 원문) → env → 커스텀 env 읽기 if(원문) → 실행 id 읽기 → handoff 기본값 → finishOnly.
    # customMode·customItem 은 토큰 해석 결과라 이 함수가 정합니다(커스텀 = 0번 항목 토큰). -KeepHandoffEnv 면 handoff env 는 앞(GUI 기동)이 둔 그대로.
    # -WorkerRecovery = 완료 항목 마무리 복구 기동(HONEYNOGI_CUSTOM_RECOVERY=1 - 커스텀만 · 구현 명세 ⑤b5 R6-RC1 의 워커 2)
    param([bool]$WorkerRestart = $false, [string]$WorkerNonce = '', [switch]$KeepHandoffEnv, [string]$WorkerOwnerJson = '', [switch]$WorkerRecovery)
    $script:customMode = [bool]$script:rowCustom
    $script:customSpecInvalid = $false
    . $script:workerInitialBlock
    $itemToken = ''
    $ownerJson = ''
    if ($script:rowCustom) {
        $itemToken = [string](Format-CustomItemToken -Item $script:rowContext.Item)
        $ownerJson = [string](New-CustomMarkerOwnerJson -Context $script:rowContext)
        if ($WorkerOwnerJson) { $ownerJson = $WorkerOwnerJson }
    }
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_ITEM' -Value $itemToken
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_OWNER' -Value $ownerJson
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_RESTART' -Value $(if ($WorkerRestart -and $script:rowCustom) { '1' } else { '' })
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_RECOVERY' -Value $(if ($WorkerRecovery -and $script:rowCustom) { '1' } else { '' })
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_MARKER' -Value $(if ($script:rowCustom) { $script:markerFilePath } else { '' })
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_GENERATION' -Value $(if ($script:rowCustom) { [string]$CONTEXT_GENERATION } else { '' })
    Set-ProcessEnv -Name 'HONEYNOGI_RUN_ID' -Value $script:rowRunId
    if (-not $KeepHandoffEnv) {
        Set-ProcessEnv -Name 'HONEYNOGI_HANDOFF_NONCE' -Value $WorkerNonce
        Set-ProcessEnv -Name 'HONEYNOGI_RESUME_REENTRY' -Value ''
        Set-ProcessEnv -Name 'HONEYNOGI_FINISH_ONLY' -Value ''
    }
    if ($script:rowCustom) {
        $script:customItem = ConvertFrom-AbyssCustomItemSpec -Spec $itemToken
        . $script:workerCustomEnvBlock
    }
    . $script:workerRunIdReadBlock
    . $script:workerHandoffDefaultBlock
    if ($null -ne $script:workerFinishOnlyReadBlock) { . $script:workerFinishOnlyReadBlock }
}

function Reset-WorkerRunState {
    # 워커 한 대분 상태 - 화면 모형 · 캡처 계층 · 양보 · 클릭 메타 · 행 갈고리 · 감시 기록
    param([string]$StartScreen = 'selection')
    $script:screen = $StartScreen
    $script:screenCaptureFailing = $false
    $script:captureFailSerial = 0
    $script:captureFailingSince = $null
    $script:captureFailTotalMs = [double]0
    $script:capfailPersist = $false
    $script:screenReads = 0
    $script:userYieldTotalMs = [double]0
    $script:lastClickPerformed = $false
    $script:lastClickSkipReason = ''
    $script:lastAbyssMenuSignal = ''
    $script:lastQuestTrackerText = ''
    $script:lastClearPromptText = ''
    $script:gameProcess = $null
    $script:gameWindowMissingSince = $null
    $script:staleCoordsIgnored = $false
    $script:safeStopFlag = $false
    $script:activeQueue.Clear()
    $script:yieldAfterEsc = 0
    $script:menuSticky = $false
    $script:flagOnAbyssClick = $false
    $script:exitClickMode = 'clicked'
    $script:otherEndCrash = $false
    $script:clearPlan = 'halt'
    $script:leftScreen = 'field'
    $script:pressResults = @{}
    $script:crashAfterPress = -1
    $script:throwHook = $null
    $script:throwFired = 0
    $script:inClose = $false
    $script:createdSnapshot = $null
    $script:stateAfterConsume = '(Consume-Handoff 없음)'
    $script:seqBeforeCleared = ''
    $script:seqAfterCleared = ''
    $script:tempWrites = 0
    foreach ($counterName in @('escClicks', 'abyssClicks', 'otherClicks', 'menuCloseKeys', 'keyOnceCalls', 'yieldWaits', 'probeCalls', 'diagCalls',
            'eventOverlayCalls', 'iconCalls', 'exitClickCalls')) { Set-Variable -Name $counterName -Scope Script -Value 0 }
    foreach ($list in @($script:workerLogLines, $script:keyPresses, $script:keyPressTrace, $script:events, $script:exitRecords, $script:setCalls,
            $script:enteredTags, $script:keyCalls, $script:keyOutcomes, $script:closeCalls, $script:closeUpdateTags, $script:returnCalls, $script:updateTags,
            $script:ownCloseCalls, $script:ownCloseUpdateTags, $script:overlayStops, $script:screenTimeline, $script:diagRecords)) { $list.Clear() }
    $script:inOwnClose = $false
    $script:timelineStart = $script:vclock
    $script:spyCounts = @{}
    $script:spyStub = @{}
    $script:spyPre = @{}
    $script:spyPost = @{}
}

function New-WorkerResult {
    # 워커 한 대 결과 - 종료 · 예외 · 시작 판독 · handoff · 로그 · 키 · 감시 기록
    param([string]$ExitCode, [string]$Thrown, [bool]$Halted, [string]$StartInside)
    $afterEntryValue = Get-HandoffField 'AfterEntry'
    $afterIndexText = '(없음)'
    if ($null -ne $afterEntryValue) {
        $indexField = Get-AbyssJournalField -Object $afterEntryValue -Name 'Index'
        if ($indexField.Has) { $afterIndexText = [string]$indexField.Value }
    }
    return [pscustomobject]@{
        ExitCode          = $ExitCode
        Exits             = (@($script:exitRecords) -join ',')
        Thrown            = $Thrown
        Halted            = [string]$Halted
        StartInside       = $StartInside
        Role              = [string](Get-HandoffField 'Role')
        NonceRaw          = [string](Get-HandoffField 'Nonce')
        NonceLabel        = (Get-NonceLabel ([string](Get-HandoffField 'Nonce')))
        AfterEntryIndex   = $afterIndexText
        JournalState      = [string](Get-HandoffField 'JournalState')
        CleanupOnly       = [string][bool]$script:customCleanupOnly
        Logs              = @($script:workerLogLines)
        PressList         = @($script:keyPresses)
        Presses           = (@($script:keyPresses) -join ',')
        PressTrace        = (Get-PressTrace)
        KeyCalls          = (@($script:keyCalls) -join ',')
        KeyOutcomes       = (@($script:keyOutcomes) -join ',')
        EnteredTags       = (@($script:enteredTags) -join ',')
        SetCalls          = (Get-SetCallsText)
        CloseCalls        = (@($script:closeCalls) -join ',')
        CloseUpdateTags   = (@($script:closeUpdateTags) -join ',')
        ReturnCalls       = (@($script:returnCalls) -join ',')
        UpdateCount       = $script:updateTags.Count
        ConsumeCalls      = [int]$script:spyCounts['Consume-Handoff']
        EnteredCalls      = [int]$script:spyCounts['Add-AbyssJournalEnteredEntry']
        ClearedCalls      = [int]$script:spyCounts['Add-AbyssJournalClearedEntry']
        Events            = (@($script:events) -join ' > ')
        CreatedEntry      = $script:createdSnapshot
        StateAfterConsume = $script:stateAfterConsume
        SeqBeforeCleared  = $script:seqBeforeCleared
        SeqAfterCleared   = $script:seqAfterCleared
        EscClicks         = $script:escClicks
        ThrowFired        = $script:throwFired
        # 단계 2.5·2.6 - 선분기 결론·표지 · own 닫기 · 정지 · 조작 수 · 완료 마커 · 마지막 [완료]
        HandoffCleanupOnly = [string][bool](Get-HandoffField 'CleanupOnly')
        FreshEntry        = [string][bool](Get-HandoffField 'FreshEntry')
        StartScreen       = [string](Get-HandoffField 'StartScreen')
        OwnCloseCalls     = (@($script:ownCloseCalls) -join ',')
        OwnCloseTags      = (@($script:ownCloseUpdateTags) -join ',')
        OverlayStops      = (@($script:overlayStops) -join ',')
        Clicks            = ([int]$script:escClicks + [int]$script:abyssClicks + [int]$script:otherClicks + [int]$script:keyOnceCalls)
        MenuCloses        = $script:menuCloseKeys
        DiagCalls         = $script:diagCalls
        MarkerExists      = [string][IO.File]::Exists($script:markerFilePath)
        LastDone          = (Get-LastLine -Lines @($script:workerLogLines) -Prefix '[완료]')
    }
}

function Get-RunEndText {
    # 워커 한 대의 판 끝 → '<끝> · 마커 <bool> · cleared <n>'. 끝 = 'exit <코드>' / '0(끝까지)'(본류 try 끝까지 - 워커 exit 0) / '(관심 구간 끝)' / '(예외) <메시지>'.
    #   계상 1 = '0(끝까지) · 마커 True · cleared 1' 또는 'exit 0 · 마커 True · cleared 1'(커스텀 - GUI 코드 0 계상의 입력, 계상 자체는 ⑯) / 계상 0 = exit 10·4 + 마커 0
    param($Run)
    $endText = '0(끝까지)'
    if ($Run.ExitCode) { $endText = 'exit ' + [string]$Run.ExitCode }
    elseif ($Run.Halted -eq 'True') { $endText = '(관심 구간 끝)' }
    elseif ($Run.Thrown) { $endText = '(예외) ' + [string]$Run.Thrown }
    return ('{0} · 마커 {1} · cleared {2}' -f $endText, $Run.MarkerExists, $Run.ClearedCalls)
}

function Format-RunKeys {
    # 한 판을 돈 워커들의 누른 키 → '<판 이름> 판 Space n · B n' (판당 B ≤ 1 · Space ≤ 1 단언 - 행 합계는 판이 둘인 행에서 판을 가르지 못함)
    param([string]$Label, [object[]]$Keys = @())
    return ('{0} 판 {1}' -f $Label, (Format-KeyCounts -Keys @($Keys)))
}

function Invoke-Worker {
    # 본류 층 한 기동 - 기동 상태 → 화면 모형 → (행 갈고리) → 시작 판독 원문($startExitDetected) → 시작 구간 A → (run:18527 if 건너뜀) → 조각 B.
    # -WorkerCombined 면 A·B 를 실제 최상위 catch 본문과 이은 결합 블록. 지역 변수 이름은 worker 접두 - 점소싱한 워커 문장의 이름과 섞이지 않게
    param([bool]$WorkerRestart = $false, [string]$WorkerStart = 'selection', [string]$WorkerClear = 'halt', [string]$WorkerNonce = '', [switch]$KeepHandoffEnv,
        [string]$WorkerOwnerJson = '', [scriptblock]$Configure = $null, [switch]$WorkerCombined, [string]$WorkerLeftScreen = 'field', [string]$WorkerReturnMode = 'real',
        [object[]]$WorkerTimeline = @(), [switch]$WorkerRecovery)
    # 워커 문장·상태 준비가 흘린 출력은 버립니다 - 운영 워커는 스크립트 최상위라 흘린 값이 어디에도 섞이지 않지만, 여기서는 이 함수의 반환에 섞여
    # 결과 개체가 배열이 됩니다(아래 점소싱도 같은 이유로 '$null = . 블록' - 점소싱이라 대입은 이 함수 범위에 그대로 남음)
    $null = Set-WorkerLaunchState -WorkerRestart $WorkerRestart -WorkerNonce $WorkerNonce -KeepHandoffEnv:$KeepHandoffEnv -WorkerOwnerJson $WorkerOwnerJson -WorkerRecovery:$WorkerRecovery
    $null = Reset-WorkerRunState -StartScreen $WorkerStart
    # 화면 시간표(-WorkerTimeline: @{ At = 기동 뒤 초; Screen } 를 시각 순으로 - 선분기 행). 0초 칸은 첫 판독 전에 적용합니다
    foreach ($timelineEntry in @($WorkerTimeline)) { $script:screenTimeline.Add($timelineEntry) }
    Update-MockScreenTimeline
    # 완료 마커는 기동마다 새로 봅니다 - GUI 는 재개·마무리 복구 기동이 아니면 기동 전에 마커를 정리합니다(Start-NextCycle 의 Clear-CustomMarkerFile). 앞 기동이
    # 남긴 마커가 이 기동의 '마커 있음' 으로 섞이지 않게
    if ($script:markerFilePath -and [IO.File]::Exists($script:markerFilePath)) { [IO.File]::Delete($script:markerFilePath) }
    $script:clearPlan = $WorkerClear
    $script:leftScreen = $WorkerLeftScreen
    $script:spyStub['Return-ToAbyssSelection'] = ($WorkerReturnMode -eq 'stub')
    if ($null -ne $Configure) { [void](& $Configure) }
    if ($WorkerCombined) {
        $script:runLogTargetPath = Join-Path $script:logDir 'mabinogi_run_once.log'
        [IO.File]::WriteAllText($script:runLogTargetPath, '', $UTF8_PLAIN)
    } else {
        $script:runLogTargetPath = ''
    }
    $game = $null
    $startInsideDetected = '(미대입)'
    $workerExitCode = ''
    $workerThrown = ''
    $workerHalted = $false
    $workerStartInside = '(시작 구간 미완)'
    try {
        $null = . $script:startExitBlock
        if ($WorkerCombined) {
            $null = . $script:combinedBlock
        } else {
            $null = . $script:segmentABlock
            $workerStartInside = [string]$startInsideDetected
            $null = . $script:segmentBBlock
        }
    } catch {
        $workerMessage = [string]$_.Exception.Message
        if ($workerMessage.StartsWith($WORKER_EXIT_PREFIX)) { $workerExitCode = $workerMessage.Substring($WORKER_EXIT_PREFIX.Length) }
        elseif ($workerMessage -eq $HALT_MESSAGE) { $workerHalted = $true }
        else { $workerThrown = $workerMessage }
    }
    return (New-WorkerResult -ExitCode $workerExitCode -Thrown $workerThrown -Halted $workerHalted -StartInside $workerStartInside)
}

function Invoke-GuiLaunch {
    # 다음 기동 env - GUI 원문 Set-HandoffLaunchEnv(먼저 비움 → 범위 술어 → Resolve 가 후보를 고르고 launched 로 적음). 커스텀 = 행 컨텍스트, 비커스텀 = 같은 실행 id.
    # -LaunchRestart = 오류 뒤 같은 항목 재시작($script:customRestart - 코드 1 자동 재시작은 끝 처리 없이 곧바로 기동, gui:11185~11202)
    param([bool]$LaunchRestart = $false)
    $script:mainCategory = 'battle'
    $rbCatAbyss.Checked = $true
    $script:customActive = [bool]$script:rowCustom
    $script:runId = $script:rowRunId
    $script:customRestart = $LaunchRestart
    $script:resolveResults.Clear()
    $script:guiEvents.Clear()
    $launchThrown = ''
    $launchOk = '(호출 실패)'
    try {
        $launchOk = [string](Set-HandoffLaunchEnv -CustomContext $script:rowContext)
    } catch {
        $launchThrown = [string]$_.Exception.Message
    }
    return [pscustomobject]@{
        Ok        = $launchOk
        Kind      = [string]$script:lastLaunchKind
        NonceEnv  = (Get-NonceLabel ([string][Environment]::GetEnvironmentVariable('HONEYNOGI_HANDOFF_NONCE', 'Process')))
        Resolve   = (@($script:resolveResults) -join ',')
        GuiEvents = (@($script:guiEvents) -join ' || ')
        Thrown    = $launchThrown
    }
}

function Invoke-GuiExitJournal {
    # 워커 종료 뒤 GUI 원문 끝 처리 - 코드 10 은 그 갈래 첫 문장의 Complete-AbyssExitJournal(인자 없음 - gui:11084), 코드 4 는 계상 뒤의 -Context 호출 모양.
    # 이번 기동 종류·nonce 는 앞 Invoke-GuiLaunch(또는 행 시작의 none)가 둔 그대로.
    # -KeepLaunched = 넘긴 nonce 를 열어 두는 끝 처리 결과(코드 4 의 재전달 표지 ' (selection-overlay)'·' (menu-overlay)' - gui:10560 · own 의 클리어 전 정지 - 명세
    # 2.7 G5 R-6 (나)). 그 판정(표지·술어 → 인자)은 실제 타이머 틱을 지나는 ⑯(C4-11′~C4-13 · KP1~KP3)이 보고, 이 파일은 그 결과의 journal 모양을 둡니다(명세 3.3
    # OK11~OK13). 코드 1(OK13 - 3회째 정지의 끝 처리 gui:11208)도 같은 -Context 호출 모양을 지나지만 코드 1 은 소비하지 않아(gui:10165) -Context 와 결과가 무관합니다
    param([int]$ExitCode, [string]$WorkerReason = '', [switch]$KeepLaunched)
    $script:lastWorkerDoneReason = $WorkerReason
    $script:customRecoveryPending = $false
    $script:diskContext = $script:rowContext
    $script:guiEvents.Clear()
    $exitOk = '(호출 실패)'
    try {
        if ($ExitCode -eq 10) { $exitOk = [string](Complete-AbyssExitJournal -ExitCode 10) }
        else { $exitOk = [string](Complete-AbyssExitJournal -ExitCode $ExitCode -Context $script:rowContext -KeepLaunched:$KeepLaunched) }
    } catch {
        $exitOk = '(예외) ' + $_.Exception.Message
    }
    return [pscustomobject]@{ Ok = $exitOk; GuiEvents = (@($script:guiEvents) -join ' || ') }
}

function Invoke-GuiStartGate {
    # 수동 시작의 시작 게이트 S3(GUI 원문 Get-AbyssStartJournalAction - 명세 ① 2.9 · OK1 '수동 시작(S0~S3)') → '<Action>/<nonce 표시>'. 어비스 커스텀 시작이라 journal
    # 을 한 번 읽습니다(쓰기 0). none = 이어받을 클리어·재개 기록이 없어 마무리 복구·재개 예약 없이 일반 기동(그다음 기동 env 의 Resolve 가 own 을 고름).
    # S0(진행 반영 - reentered 를 진행에 반영)는 이 하니스 밖입니다 - 이 행들의 journal 에는 reentered 가 없어 할 일이 없습니다
    $script:customActive = [bool]$script:rowCustom
    $script:diskContext = $script:rowContext
    $script:guiEvents.Clear()
    $gateThrown = ''
    $gateAction = $null
    try { $gateAction = Get-AbyssStartJournalAction } catch { $gateThrown = [string]$_.Exception.Message }
    if ($null -eq $gateAction) { return ('(예외) ' + $gateThrown) }
    return ('{0}/{1}' -f [string]$gateAction.Action, (Get-NonceLabel ([string]$gateAction.Nonce)))
}

function Initialize-KeyLayer {
    # 키 층 한 행 준비 - 새 행 · 픽스처 config 키 목록 · 워커 기동 상태(일반 시작 - nonce 없음) · 화면 모형(던전 안 - 키 함수의 팝업 사전 처리는 '' 판독)
    param([int[]]$EnabledKeys = @(32, 66), [bool]$Custom = $true)
    Initialize-Row -Custom $Custom
    Set-AfterEntryConfig -EnabledKeys $EnabledKeys
    $null = Set-WorkerLaunchState -WorkerRestart $false
    $null = Reset-WorkerRunState -StartScreen 'inside'
}

function Invoke-FreshEntry {
    # 자기 항목 생성 1회(실제 Add-AbyssJournalEnteredEntry - 본류 키 지점과 같은 인자 모양) - 열쇠(Nonce · AfterEntry 시작값)는 생성이 채웁니다(역할·열쇠 주입 없음)
    $freshThrown = ''
    $freshOutput = @()
    try { $freshOutput = @(Add-AbyssJournalEnteredEntry -CleanupOnly $false) } catch { $freshThrown = [string]$_.Exception.Message }
    return [pscustomobject]@{ Tag = (Format-OutputValues -Outputs $freshOutput); Thrown = $freshThrown; NonceRaw = [string]$script:handoff.Nonce }
}

function Invoke-KeyCall {
    # 실제 Invoke-AfterEntryKeys 1회(감시 경유 - 본류 키 지점과 같은 인자 모양) - 출력 개체 전부 · 예외
    param([switch]$WithContract, [string]$LogPrefix = '[어비스]')
    $keyThrown = ''
    $keyOutput = @()
    try {
        if ($WithContract) { $keyOutput = @(Invoke-AfterEntryKeys -Game $null -LogPrefix $LogPrefix -KeyContract $script:handoff) }
        else { $keyOutput = @(Invoke-AfterEntryKeys -Game $null -LogPrefix $LogPrefix) }
    } catch {
        $keyThrown = [string]$_.Exception.Message
    }
    return [pscustomobject]@{ Outputs = (Format-Outputs -Outputs $keyOutput); Thrown = $keyThrown }
}

function Start-NextWorkerConsume {
    # 키 층·저장소 층의 다음 기동 - 같은 journal · env nonce = 넘긴 항목(GUI 가 고르는 항목 - 고르기 자체는 본류 층 행이 GUI 원문으로 봄) · 운영과 같은 기동 상태
    # 대입 → 실제 Consume-Handoff 1회. 감시 기록·화면 모형은 새로(행 합계는 유지)
    param([string]$Nonce, [bool]$WorkerRestart = $true)
    $null = Set-WorkerLaunchState -WorkerRestart $WorkerRestart -WorkerNonce $Nonce
    $null = Reset-WorkerRunState -StartScreen 'inside'
    $consumeOutput = @(Consume-Handoff)
    return (Format-Outputs -Outputs $consumeOutput)
}

function Invoke-LoopRow {
    # 루프 층 한 행 - 실제 Return-ToAbyssSelection 을 본류 'left' 블록의 원문 호출 문장으로(-SafeStopExitCode 10 -LeaveEntryReason 'abandoned-death-exit') ·
    # 닫기 함수는 기록 스텁(journal 0 - 설계 R2 5.2 루프 층) · 화면 모형 · 가상 시계
    param([string]$StartScreen = 'field', [scriptblock]$Configure = $null)
    Initialize-Row -Custom $true
    $null = Set-WorkerLaunchState -WorkerRestart $false
    $null = Reset-WorkerRunState -StartScreen $StartScreen
    $script:spyStub['Close-AbyssKeyEntryOnLeave'] = $true
    if ($null -ne $Configure) { [void](& $Configure) }
    $game = $null
    $loopExitCode = ''
    $loopThrown = ''
    try {
        $null = . $script:leftCallBlock   # 흘린 출력은 버림(Invoke-Worker 와 같은 이유)
    } catch {
        $loopMessage = [string]$_.Exception.Message
        if ($loopMessage.StartsWith($WORKER_EXIT_PREFIX)) { $loopExitCode = $loopMessage.Substring($WORKER_EXIT_PREFIX.Length) } else { $loopThrown = $loopMessage }
    }
    return [pscustomobject]@{
        ExitCode   = $loopExitCode
        Thrown     = $loopThrown
        CloseCalls = (@($script:closeCalls) -join ',')
        Events     = (@($script:events) -join ' > ')
        Logs       = @($script:workerLogLines)
        EscClicks  = $script:escClicks
        MenuCloses = $script:menuCloseKeys
        ExitClicks = $script:exitClickCalls
        Probes     = $script:probeCalls
        Diags      = (@($script:diagRecords) -join ';')
    }
}

function Get-CloseOrderText {
    # 사건 열에서 닫기·플래그 소비·종료의 순서만 → 'close:… > remove-flag > exit:N'
    param([string]$Events)
    return ((@($Events -split ' > ') | Where-Object { $_.StartsWith('close:') -or ($_ -eq 'remove-flag') -or $_.StartsWith('exit:') }) -join ' > ')
}

# ===== AE 키 층 =====
function Test-RowAE0 {
    # AE0 정상 판(끊김 없음 · 키 [32,66] · 시작값 0) - Space·B 정확히 1 · 인덱스 기록 2(키마다 1, Expect 0·1) · 디스크 index 0 → 1 → 2(명세 3.3 · dev:926~928).
    #   '누를 때 디스크 index' 1·2 = 키마다 기록이 전송보다 앞(2.2 ⓑ). 건너뜀 조건을 '-ge k' 로 바꾸는 변이 · 인덱스 Changed 표식 누락이면 Space 0(명세 3.5)
    Initialize-KeyLayer
    $fresh = Invoke-FreshEntry
    $createdIndex = Get-DiskIndexText -Nonce $fresh.NonceRaw
    $keys = Invoke-KeyCall -WithContract
    Assert-Case 'AE0 [키 층] 정상 판 → 생성 태그 · 생성 직후 디스크 index · 키 결과 · 누른 키@그 순간 디스크 index · 인덱스 기록(-Index:태그) · 끝 디스크 index · [완료]·[경고] 줄 · 예외 · 판 합계' `
        (J @($fresh.Tag, $createdIndex, $keys.Outputs, (Get-PressTrace), (Get-SetCallsText), (Get-DiskIndexText -Nonce $fresh.NonceRaw), (Format-Logs @(Get-AlertLines)), $keys.Thrown, (Get-RowKeyTotals))) `
        (J @('changed', '0', 'ok(1)', '32@1,66@2', '0:changed,1:changed', '2', '[]', '', 'Space 1 · B 1'))
    Assert-Case 'AE0 [키 층] 로그(파일) - 생성 성공 줄 → 키마다 전송 줄(HEAD run:7699 형식 그대로 - 2.2 ⓑ)' (Format-Logs @($script:workerLogLines)) `
        (Format-Logs @($LINE_ENTERED_SAVED, (Get-KeyLine -Format $FORMAT_KEY_SENT -Prefix '[어비스]' -Key 32), (Get-KeyLine -Format $FORMAT_KEY_SENT -Prefix '[어비스]' -Key 66)))
}

function Test-RowAE0n {
    # AE0n(보강 - 2.2 표 'keys 가 null 이면 keys·total 먼저(next 의 첫 기록 - dev:879)'): next 열쇠(reentered · keys null)의 첫 키 기록이 keys·total 을 먼저 적고
    #   index 를 올립니다. 열쇠는 실제 Consume-Handoff 가 next 로 채웁니다(② 빌드에서 next 기동은 숨지만 이 갈래는 2.2 표의 것)
    Initialize-KeyLayer
    $nextEntry = New-FixtureEntry -Stage 'reentered' -Nonce $NONCE_A -Owner (ConvertTo-FiveFieldOwner (Get-RowCanonicalOwner -OwnerIndex 2)) `
        -NextOwner (ConvertTo-FiveFieldOwner (Get-RowCanonicalOwner -OwnerIndex 0)) -Generation $CONTEXT_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' `
        -LaunchState 'launched' -AfterIndex 0 -AfterTotal $null -AfterKeys $null
    Write-FixtureJournal -Entries @($nextEntry)
    $consumed = Start-NextWorkerConsume -Nonce $NONCE_A -WorkerRestart $false
    $handoffText = Get-HandoffSummary
    $keys = Invoke-KeyCall -WithContract
    Assert-Case 'AE0n [키 층] next 열쇠(reentered · keys null · 실제 Consume-Handoff) → 반환 · 역할|열쇠|시작값 · 키 결과 · 누른 키@index · 인덱스 기록 · 끝 항목 · [완료]·[경고] 0 · 판 합계' `
        (J @($consumed, $handoffText, $keys.Outputs, (Get-PressTrace), (Get-SetCallsText), (Format-DiskEntry (Get-DiskEntry -Nonce $NONCE_A)), (Format-Logs @(Get-AlertLines)), $keys.Thrown, (Get-RowKeyTotals))) `
        (J @('ok(1)', 'next|NA|0/null', 'ok(1)', '32@1,66@2', '0:changed,1:changed', 'reentered/launched/2/2/[32,66]/False//', '[]', '', 'Space 1 · B 1'))
}

function Test-RowAE2 {
    # AE2 인덱스 기록 'locked'(그 키 기록 때 잠금 점유 주입) - 그 키부터 0 · '[완료] … (k/N, 캐릭터는 던전 안)' · 'stop'(호출부 exit 4 - AE2m 이 본류 층에서 봄)
    #   (dev:879 · 명세 5절 B4 '기록 성공 = changed 만'). 변이 '기록 실패에 전송' 이면 그 키가 나감(명세 3.5)
    foreach ($lockAt in @(0, 1)) {
        Initialize-KeyLayer
        $fresh = Invoke-FreshEntry
        $script:lockAtIndex = $lockAt
        $script:spyPre['Set-AbyssAfterEntryIndex'] = { param($Bound) if ([int]$Bound['Index'] -eq [int]$script:lockAtIndex) { Lock-Journal } }
        $script:spyPost['Set-AbyssAfterEntryIndex'] = { param($Bound, $Output) Close-HeldStreams }
        $keys = Invoke-KeyCall -WithContract
        Close-HeldStreams
        $expectTrace = $(if ($lockAt -eq 0) { '' } else { '32@1' })
        $expectSet = $(if ($lockAt -eq 0) { '0:locked' } else { '0:changed,1:locked' })
        $expectTotals = $(if ($lockAt -eq 0) { 'Space 0 · B 0' } else { 'Space 1 · B 0' })
        Assert-Case ('AE2 [키 층] 키 {0} 의 인덱스 기록 때 잠금 점유 → 키 결과 · 누른 키@index · 인덱스 기록 · [완료]·[경고] 줄 · 끝 디스크 index · 예외 · 판 합계' -f $lockAt) `
            (J @($keys.Outputs, (Get-PressTrace), (Get-SetCallsText), (Format-Logs @(Get-AlertLines)), (Get-DiskIndexText -Nonce $fresh.NonceRaw), $keys.Thrown, (Get-RowKeyTotals))) `
            (J @('stop(1)', $expectTrace, $expectSet, (Format-Logs @(($FORMAT_KEY_RECORD_FAILED -f $lockAt, 2))), [string]$lockAt, '', $expectTotals))
    }
}

function Test-RowAE3 {
    # AE3 keys 불일치(열쇠 keys [32] · 지금 [32,66]) - 키 0 + [경고] 1 · 'skipped'(호출부 exit 4 0 - 판 계속, AE3m 이 본류 층에서 봄) (2.2 ⓐ · dev:927).
    #   첫 기동은 키 [32] 설정으로 생성·Space 를 보낸 판, 두 번째 기동은 B 를 켠 뒤 같은 항목(실제 Consume-Handoff own). 변이 'keys 검사 제거'·'불일치를 exit 4 로'
    Initialize-KeyLayer -EnabledKeys @(32)
    $fresh = Invoke-FreshEntry
    $first = Invoke-KeyCall -WithContract
    Set-AfterEntryConfig -EnabledKeys @(32, 66)
    $consumed = Start-NextWorkerConsume -Nonce $fresh.NonceRaw
    $handoffText = Get-HandoffSummary
    $stateBefore = Get-FolderState -Folder $script:journalFolder
    $keys = Invoke-KeyCall -WithContract
    Assert-Case 'AE3 [키 층] 열쇠 keys [32] · 지금 [32,66] → 첫 기동 결과 · 두 번째 기동 반환·역할|열쇠|시작값 · 키 결과(판 계속) · 누른 키 0 · 인덱스 기록 0 · [완료]·[경고] 줄 · 파일 불변 · 예외 · 판 합계' `
        (J @($first.Outputs, $consumed, $handoffText, $keys.Outputs, (@($script:keyPresses) -join ','), (Get-SetCallsText), (Format-Logs @(Get-AlertLines)),
                [string]((Get-FolderState -Folder $script:journalFolder) -ceq $stateBefore), $keys.Thrown, (Get-RowKeyTotals))) `
        (J @('ok(1)', 'ok(1)', ('own|{0}|1/32' -f (Get-NonceLabel $fresh.NonceRaw)), 'skipped(1)', '', '', (Format-Logs @($LINE_KEYS_MISMATCH)), 'True', '', 'Space 1 · B 0'))
}

function Test-RowAE3Prime {
    # AE3′(보강 - 2.2 ⓐ '@() 정규화 뒤 개수·순서·값' 의 나머지 갈래 · dev:927): 열쇠 항목에 기록된 keys 가 지금 켠 키 [32,66] 과 순서만 다름 [66,32] / 개수가 같고
    #   값이 다름 [32,70] / 빈 목록 [](키를 모두 끈 판의 생성 기록 - null 이 아니라 비교 대상) → 셋 다 키 0 + [경고] 1 · 'skipped'(판 계속) · 인덱스 기록 0 · 파일 불변.
    #   AE3 은 개수 차이([32] → [32,66])만 봐서 순서를 무시하는 비교 · 개수만 보는 비교 · 빈 기록을 null 처럼 건너뛰는 비교가 살아남았습니다(변이 검증). 시작값은 0 이라
    #   비교가 빠지면 키가 실제로 나갑니다. 열쇠는 실제 Consume-Handoff 가 own 으로 채웁니다(픽스처 키 이름 RecordedKeys - 해시테이블의 Keys 속성과 겹치지 않게)
    $keyCases = @(
        @{ Label = '순서만 다름'; RecordedKeys = @(66, 32); Shape = '66,32' },
        @{ Label = '개수 같고 값 다름'; RecordedKeys = @(32, 70); Shape = '32,70' },
        @{ Label = '빈 기록 목록'; RecordedKeys = @(); Shape = '' })
    $actual = foreach ($keyCase in $keyCases) {
        Initialize-KeyLayer
        $ownEntry = New-RowOwnEntry -Nonce $NONCE_A -AfterIndex 0
        $ownEntry.afterEntry.keys = [object[]]@($keyCase.RecordedKeys)
        $ownEntry.afterEntry.total = @($keyCase.RecordedKeys).Count
        Write-FixtureJournal -Entries @($ownEntry)
        $consumed = Start-NextWorkerConsume -Nonce $NONCE_A -WorkerRestart $false
        $handoffText = Get-HandoffSummary
        $stateBefore = Get-FolderState -Folder $script:journalFolder
        $keys = Invoke-KeyCall -WithContract
        '{0}: {1}' -f $keyCase.Label, (J @($consumed, $handoffText, $keys.Outputs, (@($script:keyPresses) -join ','), (Get-SetCallsText), (Format-Logs @(Get-AlertLines)),
                [string]((Get-FolderState -Folder $script:journalFolder) -ceq $stateBefore), $keys.Thrown, (Get-RowKeyTotals)))
    }
    $expected = foreach ($keyCase in $keyCases) {
        '{0}: {1}' -f $keyCase.Label, (J @('ok(1)', ('own|NA|0/{0}' -f $keyCase.Shape), 'skipped(1)', '', '', (Format-Logs @($LINE_KEYS_MISMATCH)), 'True', '', 'Space 0 · B 0'))
    }
    Assert-Case 'AE3′ [키 층] 기록 keys 가 지금 [32,66] 과 순서만·값만 다름 / 빈 기록 목록 → 시작 반환 · 역할|열쇠|시작값 · 키 결과(판 계속) · 누른 키 0 · 인덱스 기록 0 · [완료]·[경고] 줄 · 파일 불변 · 예외 · 판 합계' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowAE4 {
    # AE4 Press-KeyVerified 거짓(Space 의 전면 확인 실패) - index 는 이미 올라 있음 · 재전송 0(같은 호출의 재시도 0 + 다음 기동이 건너뜀) (dev:928)
    Initialize-KeyLayer
    $fresh = Invoke-FreshEntry
    $script:pressResults[32] = $false
    $first = Invoke-KeyCall -WithContract
    $firstTrace = Get-PressTrace
    $firstIndex = Get-DiskIndexText -Nonce $fresh.NonceRaw
    $firstKeyLines = @(Get-LinesWithPrefix -Lines @($script:workerLogLines) -Prefixes @('[어비스] '))
    $consumed = Start-NextWorkerConsume -Nonce $fresh.NonceRaw
    $second = Invoke-KeyCall -WithContract
    Assert-Case 'AE4 [키 층] Space 전면 확인 실패 → 첫 기동 결과 · 누른 키@index(시도 1회씩) · 끝 index(둘 다 기록) · 키 줄(생성 · Space 건너뜀 · B 입력완료)' `
        (J @($first.Outputs, $firstTrace, $firstIndex, (Format-Logs $firstKeyLines))) `
        (J @('ok(1)', '32@1,66@2', '2', (Format-Logs @($LINE_ENTERED_SAVED, (Get-KeyLine -Format $FORMAT_KEY_SKIPPED -Prefix '[어비스]' -Key 32), (Get-KeyLine -Format $FORMAT_KEY_SENT -Prefix '[어비스]' -Key 66)))))
    Assert-Case 'AE4 [키 층] 다음 기동(같은 항목 · 실제 Consume-Handoff own) → 반환 · 시작값 · 키 결과 · 누른 키 0 · 인덱스 기록 0 · 이미 보낸 키 줄 2 · 판 합계(재전송 0)' `
        (J @($consumed, (Get-HandoffSummary), $second.Outputs, (@($script:keyPresses) -join ','), (Get-SetCallsText), (Format-Logs @($script:workerLogLines)), (Get-RowKeyTotals))) `
        (J @('ok(1)', ('own|{0}|2/32,66' -f (Get-NonceLabel $fresh.NonceRaw)), 'ok(1)', '', '',
                (Format-Logs @((Get-KeyLine -Format $FORMAT_KEY_ALREADY_SENT -Prefix '[어비스]' -Key 32), (Get-KeyLine -Format $FORMAT_KEY_ALREADY_SENT -Prefix '[어비스]' -Key 66))), 'Space 1 · B 1'))
}

function Test-RowAE5 {
    # AE5 expect-failed(디스크 index ≠ k 주입 - 다른 기동이 먼저 기록한 모양) - 그 키부터 0 · '[완료] … (k/N …)' · 'stop' (명세 5절 B4 - expect-failed 도 실패)
    foreach ($case in @(@{ At = 0; Inject = 1 }, @{ At = 1; Inject = 2 })) {
        Initialize-KeyLayer
        $fresh = Invoke-FreshEntry
        $script:injectAt = [int]$case.At
        $script:injectIndex = [int]$case.Inject
        $script:injectNonce = $fresh.NonceRaw
        $script:spyPre['Set-AbyssAfterEntryIndex'] = { param($Bound) if ([int]$Bound['Index'] -eq $script:injectAt) { Set-DiskAfterIndex -Nonce $script:injectNonce -Index $script:injectIndex } }
        $keys = Invoke-KeyCall -WithContract
        $expectTrace = $(if ($case.At -eq 0) { '' } else { '32@1' })
        $expectSet = $(if ($case.At -eq 0) { '0:expect-failed' } else { '0:changed,1:expect-failed' })
        $expectTotals = $(if ($case.At -eq 0) { 'Space 0 · B 0' } else { 'Space 1 · B 0' })
        Assert-Case ('AE5 [키 층] 키 {0} 기록 직전 디스크 index 를 {1} 로 → 키 결과 · 누른 키@index · 인덱스 기록 · [완료]·[경고] 줄 · 끝 디스크 index(주입값 그대로) · 예외 · 판 합계' -f $case.At, $case.Inject) `
            (J @($keys.Outputs, (Get-PressTrace), (Get-SetCallsText), (Format-Logs @(Get-AlertLines)), (Get-DiskIndexText -Nonce $fresh.NonceRaw), $keys.Thrown, (Get-RowKeyTotals))) `
            (J @('stop(1)', $expectTrace, $expectSet, (Format-Logs @(($FORMAT_KEY_RECORD_FAILED -f $case.At, 2))), [string]$case.Inject, '', $expectTotals))
    }
}

function Test-RowAE6 {
    # AE6 열쇠 항목 없음(stale 정리 뒤 - 생성한 항목이 journal 에서 지워짐) - 그 키부터 0 · '[완료] … (0/2 …)' · 'stop' (명세 5절 B4)
    Initialize-KeyLayer
    $fresh = Invoke-FreshEntry
    Remove-DiskEntry -Nonce $fresh.NonceRaw
    $keys = Invoke-KeyCall -WithContract
    Assert-Case 'AE6 [키 층] 열쇠 항목이 journal 에 없음 → 키 결과 · 누른 키 · 인덱스 기록 · [완료]·[경고] 줄 · 항목 · 예외 · 판 합계' `
        (J @($keys.Outputs, (Get-PressTrace), (Get-SetCallsText), (Format-Logs @(Get-AlertLines)), (Format-DiskEntry (Get-DiskEntry -Nonce $fresh.NonceRaw)), $keys.Thrown, (Get-RowKeyTotals))) `
        (J @('stop(1)', '', '0:expect-failed', (Format-Logs @(($FORMAT_KEY_RECORD_FAILED -f 0, 2))), '(항목 없음)', '', 'Space 0 · B 0'))
}

function Test-RowAE7Prime {
    # AE7′(보강 - 명세 5절 B3 '1개·0개 배열의 JSON 왕복을 ⑳ 에서 확인'): 키 1개 설정의 생성 → 디스크 keys 가 1개 배열 → 다음 기동(실제 Consume-Handoff)의 시작값
    #   keys 도 1개 → 같은 설정이면 불일치 경고 0 · 이미 보낸 키 1 (0개 배열은 본류 층 AE7 이 봄)
    Initialize-KeyLayer -EnabledKeys @(32)
    $fresh = Invoke-FreshEntry
    $diskShape = Get-DiskKeysShape -Nonce $fresh.NonceRaw
    $first = Invoke-KeyCall -WithContract
    $firstPresses = @($script:keyPresses) -join ','
    $consumed = Start-NextWorkerConsume -Nonce $fresh.NonceRaw
    $handoffText = Get-HandoffSummary
    $second = Invoke-KeyCall -WithContract
    Assert-Case 'AE7′ [키 층] 키 [32] 하나 → 디스크 keys 모양 · 첫 기동 결과·누른 키 · 다음 기동 반환·역할|열쇠|시작값 · 결과 · 로그(이미 보낸 키 1 · 불일치 경고 0) · 판 합계' `
        (J @($diskShape, $first.Outputs, $firstPresses, $consumed, $handoffText, $second.Outputs, (Format-Logs @($script:workerLogLines)), (Get-RowKeyTotals))) `
        (J @('array(1)=32', 'ok(1)', '32', 'ok(1)', ('own|{0}|1/32' -f (Get-NonceLabel $fresh.NonceRaw)), 'ok(1)', (Format-Logs @((Get-KeyLine -Format $FORMAT_KEY_ALREADY_SENT -Prefix '[어비스]' -Key 32))), 'Space 1 · B 0'))
}

function Test-RowAE8 {
    # AE8 계약 없는 호출(던전·사냥터·파티원 경로 - 접두는 소스의 계약 없는 호출 원문에서) - journal 접근 0(읽기·쓰기·인덱스 기록 0) · 키 순서·로그 HEAD 그대로 ·
    #   출력 0(명세 5절 B7). 열쇠처럼 보이는 상태(own · 시작값 2)를 두어도 계약 인자가 없으면 보지 않습니다. 변이 '인덱스 계약을 던전 호출부에도' 는 S8 이 봄
    foreach ($prefix in $script:plainKeyPrefixes) {
        Initialize-KeyLayer
        Write-FixtureJournal -Entries @((New-RowOwnEntry -Nonce $NONCE_A -AfterIndex 2))
        [void](Start-NextWorkerConsume -Nonce $NONCE_A -WorkerRestart $false)
        $handoffText = Get-HandoffSummary
        $script:spyCounts = @{}
        $keys = Invoke-KeyCall -LogPrefix $prefix
        $journalTouches = ('읽기 {0} · 저장 {1} · 인덱스 기록 {2} · 임시 파일 {3}' -f [int]$script:spyCounts['Read-AbyssJournal'], [int]$script:spyCounts['Update-AbyssJournal'],
            [int]$script:spyCounts['Set-AbyssAfterEntryIndex'], $script:tempWrites)
        Assert-Case ('AE8 [키 층] 계약 없는 호출(접두 {0} · 열쇠 모양 상태) → 상태 · 출력 · journal 접근 · 누른 키 순서 · 로그(전송 줄 HEAD 형식) · 예외' -f $prefix) `
            (J @($handoffText, $keys.Outputs, $journalTouches, (@($script:keyPresses) -join ','), (Format-Logs @($script:workerLogLines)), $keys.Thrown)) `
            (J @('own|NA|2/32,66', '(0)', '읽기 0 · 저장 0 · 인덱스 기록 0 · 임시 파일 0', '32,66',
                    (Format-Logs @((Get-KeyLine -Format $FORMAT_KEY_SENT -Prefix $prefix -Key 32), (Get-KeyLine -Format $FORMAT_KEY_SENT -Prefix $prefix -Key 66))), ''))
    }
}

function Test-RowAE9 {
    # AE9 키 0 의 인덱스 기록에서 저장 예외 주입(직렬화 throw - TC3 과 같은 주입) - 예외가 Invoke-AfterEntryKeys 밖으로 전파 · Press-KeyVerified 0 · 디스크 index 0 ·
    #   [완료]·[경고] 0. 코드 1·오류 세트는 결합 층 TC3(명세 3.3 예외 행의 층 규칙). 변이 '인덱스 기록 함수가 예외를 잡아 stop 으로' 면 전파 0
    Initialize-KeyLayer
    $fresh = Invoke-FreshEntry
    $script:spyPre['Set-AbyssAfterEntryIndex'] = { param($Bound)
        if ([int]$Bound['Index'] -eq 0) { $script:throwHook = @{ Name = 'ConvertTo-AbyssJournalText'; Match = { param($HookBound) $true }; Message = $INJECTED_SERIALIZE } }
    }
    $keys = Invoke-KeyCall -WithContract
    Assert-Case 'AE9 [키 층] 키 0 인덱스 기록 저장 예외 → 전파된 예외 · 출력 · 갈고리 발사 · 누른 키 · 디스크 index · [완료]·[경고] 줄 · 판 합계' `
        (J @($keys.Thrown, $keys.Outputs, $script:throwFired, (@($script:keyPresses) -join ','), (Get-DiskIndexText -Nonce $fresh.NonceRaw), (Format-Logs @(Get-AlertLines)), (Get-RowKeyTotals))) `
        (J @($INJECTED_SERIALIZE, '(0)', 1, '', '0', '[]', 'Space 0 · B 0'))
}

# ===== AE 본류 층 =====
function Set-CrashHooks {
    # AE1 crash 주입 - 키 k 의 '기록 전'(인덱스 기록 앞 갈고리) · '기록 직후'(그 저장이 끝난 뒤 갈고리 = 기록 뒤·전송 전) · '전송 직후'(키 스파이) - 예외로 중단(끊김)
    switch ([string]$script:crashPlan.Hook) {
        'set-pre' { $script:spyPre['Set-AbyssAfterEntryIndex'] = { param($Bound) if ([int]$Bound['Index'] -eq [int]$script:crashPlan.At) { throw ('CRASH-' + $script:crashPlan.Label) } } }
        'set-post' { $script:spyPost['Set-AbyssAfterEntryIndex'] = { param($Bound, $Output) if ([int]$Bound['Index'] -eq [int]$script:crashPlan.At) { throw ('CRASH-' + $script:crashPlan.Label) } } }
        'press-post' { $script:crashAfterPress = [int]$script:crashPlan.At }
    }
}

function Test-RowAE1 {
    # AE1 키 [32,66] × crash 6지점 × 워커 2대 순차(커스텀 RESTART own) - 판당 B ≤ 1 · Space ≤ 1 · '기록 뒤·전송 전' crash 는 그 키 0 (dev:929·993 · 명세 3.3).
    #   [본류 층] 첫 기동 = 선택 화면 시작(카드 → 입장) → 키 지점 생성 → 키 중 crash / GUI 코드 1 자동 재시작(끝 처리 없이 곧바로 기동 - GUI 원문 기동 env 가 own 을
    #   고름) → 두 번째 기동 = 던전 안 시작 · RESTART → 실제 Consume-Handoff own → 키 지점(생성 0 · 열쇠 시작값부터) → 클리어 대기에서 끝.
    #   변이 '인덱스를 전송 뒤에 기록' 이면 '전송 직후' crash 행이 그 키 2
    $crashCases = @(
        @{ Label = 'Space 기록 전'; Hook = 'set-pre'; At = 0; Totals = 'Space 1 · B 1'; StartIndex = '0' },
        @{ Label = 'Space 기록 직후(전송 전)'; Hook = 'set-post'; At = 0; Totals = 'Space 0 · B 1'; StartIndex = '1' },
        @{ Label = 'Space 전송 직후'; Hook = 'press-post'; At = 32; Totals = 'Space 1 · B 1'; StartIndex = '1' },
        @{ Label = 'B 기록 전'; Hook = 'set-pre'; At = 1; Totals = 'Space 1 · B 1'; StartIndex = '1' },
        @{ Label = 'B 기록 직후(전송 전)'; Hook = 'set-post'; At = 1; Totals = 'Space 1 · B 0'; StartIndex = '2' },
        @{ Label = 'B 전송 직후'; Hook = 'press-post'; At = 66; Totals = 'Space 1 · B 1'; StartIndex = '2' })
    $actual = foreach ($crash in $crashCases) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        $script:crashPlan = $crash
        $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -Configure { Set-CrashHooks }
        $launch = Invoke-GuiLaunch -LaunchRestart $true
        $second = Invoke-Worker -WorkerRestart $true -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
        '{0}: {1}' -f $crash.Label, (J @($first.Thrown.StartsWith('CRASH'), $first.NonceLabel, $launch.Kind, $launch.NonceEnv, $second.Role, $second.NonceLabel,
                $second.AfterEntryIndex, $second.EnteredCalls, $second.Halted, (Get-RowKeyTotals)))
    }
    $expected = foreach ($crash in $crashCases) {
        '{0}: {1}' -f $crash.Label, (J @('True', 'W1', 'own', 'W1', 'own', 'W1', $crash.StartIndex, 0, 'True', $crash.Totals))
    }
    Assert-Case 'AE1 [본류 층] crash 6지점 × 워커 2대(커스텀 RESTART own) → 첫 기동 끊김 · 첫 항목 · 다음 기동 종류·nonce env · 두 번째 Role·열쇠·시작값·생성 0·클리어 대기 도달 · 판 합계(B ≤ 1 · Space ≤ 1, 기록 뒤·전송 전은 그 키 0)' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowAE2m {
    # AE2m(보강 - AE2 의 'exit 4' 를 본류 층에서): 키 1 의 인덱스 기록 locked → 키 지점의 'stop' → exit 4 · 클리어 대기 0 · 그 줄 (1/2, 캐릭터는 던전 안)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -Configure {
        $script:spyPre['Set-AbyssAfterEntryIndex'] = { param($Bound) if ([int]$Bound['Index'] -eq 1) { Lock-Journal } }
        $script:spyPost['Set-AbyssAfterEntryIndex'] = { param($Bound, $Output) Close-HeldStreams }
    }
    Close-HeldStreams
    Assert-Case 'AE2m [본류 층] 키 1 인덱스 기록 locked → exit · 키 결과 · 누른 키 · [완료]·[경고] 줄 · 클리어 대기 시작 줄 0 · 클리어 대기 도달 0 · 예외 · 판 합계' `
        (J @($run.ExitCode, $run.KeyOutcomes, $run.Presses, (Format-Logs @(Get-LinesWithPrefix -Lines $run.Logs -Prefixes @('[완료]', '[경고]'))), (Get-LineCount -Lines $run.Logs -Exact $CLEAR_WAIT_START_LINE), $run.Halted, $run.Thrown, (Get-RowKeyTotals))) `
        (J @('4', 'stop(1)', '32', (Format-Logs @(($FORMAT_KEY_RECORD_FAILED -f 1, 2))), 0, 'False', '', 'Space 1 · B 0'))
}

function Test-RowAE3m {
    # AE3m(보강 - AE3 의 'exit 4 0(판 계속)' 를 본류 층에서): 키 [32] 설정의 첫 기동이 Space 뒤 끊김 → B 를 켬 → GUI 재시작(own) → 두 번째 기동 키 지점 'skipped' →
    #   exit 없이 클리어 대기로 계속
    Initialize-Row -Custom $true
    Set-AfterEntryConfig -EnabledKeys @(32)
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    Set-AfterEntryConfig -EnabledKeys @(32, 66)
    $launch = Invoke-GuiLaunch -LaunchRestart $true
    $second = Invoke-Worker -WorkerRestart $true -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'AE3m [본류 층] 열쇠 keys [32] · 지금 [32,66] → 첫 기동 키 · 다음 기동 종류 · 두 번째 Role · 키 결과 · 누른 키 · [완료]·[경고] 줄 · exit · 클리어 대기 도달(판 계속) · 판 합계' `
        (J @($first.Presses, $launch.Kind, $second.Role, $second.KeyOutcomes, $second.Presses, (Format-Logs @(Get-LinesWithPrefix -Lines $second.Logs -Prefixes @('[완료]', '[경고]'))), $second.ExitCode, $second.Halted, (Get-RowKeyTotals))) `
        (J @('32', 'own', 'own', 'skipped(1)', '', (Format-Logs @($LINE_KEYS_MISMATCH)), '', 'True', 'Space 1 · B 0'))
}

function Test-RowAE7 {
    # AE7 빈 키 목록(enabled 0) - 생성 1(total 0) · 인덱스 기록 0 · 키 0 · 'ok' (명세 5절 B2·B3 - 키가 전부 꺼져도 생성은 함: own 계상·코드 10 닫기에 항목이 필요).
    #   [본류 층] + 0개 배열의 JSON 왕복: 디스크 keys = 빈 배열(null 이 아님) → 다음 기동(GUI 재시작 own)의 시작값 keys 도 빈 배열 → 불일치 경고 0
    Initialize-Row -Custom $true
    Set-AfterEntryConfig -EnabledKeys @()
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt'
    $diskShape = Get-DiskKeysShape -Nonce $first.NonceRaw
    Assert-Case 'AE7 [본류 층] 키 전부 꺼짐 → 생성 태그 · 생성 직후 항목 · 디스크 keys 모양 · 인덱스 기록 · 누른 키 · 키 결과 · 클리어 대기 도달 · exit · [완료]·[경고] 0' `
        (J @($first.EnteredTags, (Format-DiskEntry $first.CreatedEntry), $diskShape, $first.SetCalls, $first.Presses, $first.KeyOutcomes, $first.Halted, $first.ExitCode,
                (Format-Logs @(Get-LinesWithPrefix -Lines $first.Logs -Prefixes @('[완료]', '[경고]'))))) `
        (J @('changed', 'entered/launched/0/0/[]/False//', 'array(0)=', '', '', 'ok(1)', 'True', '', '[]'))
    $launch = Invoke-GuiLaunch -LaunchRestart $true
    $second = Invoke-Worker -WorkerRestart $true -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'AE7 [본류 층] 0개 배열 왕복 → 다음 기동 종류 · 두 번째 Role|열쇠|시작값(keys 빈 배열) · 키 결과 · 누른 키 · [경고] 0 · 판 합계' `
        (J @($launch.Kind, (Get-HandoffSummary), $second.KeyOutcomes, $second.Presses, (Get-LineCount -Lines $second.Logs -Prefix '[경고]'), (Get-RowKeyTotals))) `
        (J @('own', 'own|W1|0/', 'ok(1)', '', 0, 'Space 0 · B 0'))
}

# ===== SE 자기 항목 =====
function Test-RowSE1 {
    # SE1 첫 판(handoff 없음) - 키 지점 앞 entered 1(owner = OWNER 5필드·generation / 비커스텀 {runId} · section · launched · afterEntry {0, N, keys} · cleanupOnly 거짓 ·
    #   at.entered) → 키 1회씩 → 그 판 RESTART(실제 Consume-Handoff) → own → 재전송 0 (dev:874·993). 변이 '첫 판 생성 제거' · '키 지점 Nonce 게이트 제거(늘 생성)' 면
    #   재전송 · '생성 Changed 표식 누락' 이면 [완료] 입장 기록 실패 exit 4(명세 3.5)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $created = $first.CreatedEntry
    $eventsText = [string]$first.Events
    $enteredAt = $eventsText.IndexOf('entered:changed')
    $enteredBeforeKey = ($enteredAt -ge 0) -and ($enteredAt -lt $eventsText.IndexOf('press:32'))
    $createdSection = '(항목 없음)'
    $createdRunId = '(항목 없음)'
    $createdAt = $false
    if ($null -ne $created) {
        $createdSection = [string]$created.section
        $createdRunId = [string]$created.runId
        $createdAt = -not [string]::IsNullOrEmpty([string]$created.at.entered)
    }
    Assert-Case 'SE1 [본류 층] 커스텀 첫 판 → 생성 태그 · 생성 직후 항목 · owner 5필드+세대 = GUI 컨텍스트 · section · runId · at.entered 있음 · 생성이 첫 키보다 앞 · 첫 기동 키 · 생성 성공 줄' `
        (J @($first.EnteredTags, (Format-DiskEntry $created), (Test-EntryOwnerEquals $created), $createdSection, $createdRunId, $createdAt, $enteredBeforeKey, $first.Presses,
                (Get-LineCount -Lines $first.Logs -Exact $LINE_ENTERED_SAVED))) `
        (J @('changed', 'entered/launched/0/2/[32,66]/False//', 'True', $ABYSS_SECTION, $ROW_RUN_ID, 'True', 'True', '32,66', 1))
    $launch = Invoke-GuiLaunch -LaunchRestart $true
    $second = Invoke-Worker -WorkerRestart $true -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'SE1 [본류 층] → 그 판 RESTART(GUI 원문 기동 env · 실제 Consume-Handoff) → 후보 · 기동 종류 · Role · 같은 nonce · 시작값 2 · 생성 0 · 누른 키 0 · 이미 보낸 키 줄 2 · 판 합계(재전송 0)' `
        (J @($launch.Resolve, $launch.Kind, $second.Role, $second.NonceLabel, $second.AfterEntryIndex, $second.EnteredCalls, $second.Presses,
                (Get-LineCount -Lines $second.Logs -Fragment '이전 실행이 이미 보낸 키라'), (Get-RowKeyTotals))) `
        (J @('ok/own', 'own', 'own', 'W1', '2', 0, '', 2, 'Space 1 · B 1'))
    # 비커스텀 - owner { runId } · section 빈 값 · generation 0 (재시작 사슬은 커스텀만 - 비커스텀 코드 1 은 GUI 오류 정지)
    Initialize-Row -Custom $false
    Set-AfterEntryConfig
    $plain = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt'
    $plainCreated = $plain.CreatedEntry
    $plainSection = '(항목 없음)'
    $plainGeneration = '(항목 없음)'
    if ($null -ne $plainCreated) {
        $plainSection = [string]$plainCreated.section
        $plainGeneration = [string]$plainCreated.generation
    }
    Assert-Case 'SE1 [본류 층] 비커스텀 첫 판 → 생성 태그 · 생성 직후 항목 · owner {runId} = 이번 실행 id · section · generation · 키 1회씩' `
        (J @($plain.EnteredTags, (Format-DiskEntry $plainCreated), (Test-EntryOwnerEquals $plainCreated), $plainSection, $plainGeneration, $plain.Presses)) `
        (J @('changed', 'entered/launched/0/2/[32,66]/False//', 'True', '', '0', '32,66'))
}

function Set-GenerationFailureHooks {
    # SE2·TC0 - 생성 저장에만 실패 주입: locked(잠금 점유) · corrupt(본 파일·직전본 손상 - 시작 읽기 뒤라 생성 시점에만) · io-failed(.lock 자리 폴더)
    param([string]$Variant)
    $script:generationVariant = $Variant
    $script:spyPre['Add-AbyssJournalEnteredEntry'] = { param($Bound)
        switch ([string]$script:generationVariant) {
            'locked' { Lock-Journal }
            'corrupt' { Write-CorruptJournal }
            'io-failed' { New-LockFolder }
        }
    }
    $script:spyPost['Add-AbyssJournalEnteredEntry'] = { param($Bound, $Output) Close-HeldStreams; Remove-LockFolder }
}

function Test-RowSE2 {
    # SE2 생성 'locked'·'corrupt'·'io-failed' 각각 - 키 0 · '[완료] 입장 기록 실패 …' · exit 4 (dev:874 · J2 - 생성 시점의 실패는 태그 무관 코드 4)
    $variants = @('locked', 'corrupt', 'io-failed')
    $actual = foreach ($variant in $variants) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        $script:se2Variant = $variant
        $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -Configure { Set-GenerationFailureHooks -Variant $script:se2Variant }
        Close-HeldStreams
        Remove-LockFolder
        '{0}: {1}' -f $variant, (J @($run.EnteredTags, $run.ExitCode, $run.KeyCalls, $run.Presses, (Format-Logs @(Get-LinesWithPrefix -Lines $run.Logs -Prefixes @('[완료]'))),
                (Get-LineCount -Lines $run.Logs -Exact $CLEAR_WAIT_START_LINE), $run.Thrown))
    }
    $expected = foreach ($variant in $variants) { '{0}: {1}' -f $variant, (J @($variant, '4', '', '', (Format-Logs @($LINE_ENTERED_FAILED)), 0, '')) }
    Assert-Case 'SE2 [본류 층] 생성 저장 실패 3종 → 생성 태그 · exit · 키 함수 호출 0 · 누른 키 0 · [완료] 줄(꼬리 0) · 클리어 대기 시작 줄 0 · 예외 0' (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Set-OwnerMatchThrowHook {
    # SE3·TC1 - 생성 저장의 mutator 가 부르는 최상위 함수(Test-AbyssJournalOwnerMatch)를 그 저장에만 throw 로(생성 앞 갈고리에서 무장 - 앞선 Consume-Handoff 는 실제 그대로)
    $script:spyPre['Add-AbyssJournalEnteredEntry'] = { param($Bound)
        $script:stateAtGeneration = Get-FolderState -Folder $script:journalFolder
        $script:throwHook = @{ Name = 'Test-AbyssJournalOwnerMatch'; Match = { param($HookBound) $true }; Message = $INJECTED_OWNER_MATCH }
    }
}

function Test-RowSE3 {
    # SE3 생성 mutator 예외 주입 - 예외가 본류 조각 밖으로 전파(조각 안 exit 기록 0) · 키 0 · [경고] 0 · journal 무변경. 코드 1·오류 세트는 TC1(명세 3.3).
    #   픽스처 = 앞 항목(owner index 1)의 열린 entered - mutator 가 owner 대조를 부르는 항목(이번 owner 의 후보가 아니라 시작은 Role none). 변이 '생성 함수가 mutator
    #   예외를 잡아 태그로' 면 전파 0
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    Write-FixtureJournal -Entries @((New-RowOwnEntry -Nonce $NONCE_B -OwnerIndex 1))
    $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -Configure { Set-OwnerMatchThrowHook }
    Assert-Case 'SE3 [본류 층] 생성 mutator 예외 → 전파된 예외 · 갈고리 발사 · exit 기록 · 시작 Role · 키 함수 호출 · 누른 키 · [경고] 줄 · journal 무변경(생성 직전 대비)' `
        (J @($run.Thrown, $run.ThrowFired, $run.Exits, $run.Role, $run.KeyCalls, $run.Presses, (Get-LineCount -Lines $run.Logs -Prefix '[경고]'),
                [string]((Get-FolderState -Folder $script:journalFolder) -ceq $script:stateAtGeneration))) `
        (J @($INJECTED_OWNER_MATCH, 1, '', 'none', '', '', 0, 'True'))
}

function Test-RowSE4 {
    # SE4 같은 owner 의 남은 열린 entered + 받은 nonce(ownFreshEntry) - 같은 저장에서 done · owner 당 열린 항목 ≤ 1 (dev:595·930 · 2.2 표 mutator ①).
    #   [저장소 층 직접 호출] 받은 own nonce(NA - GUI 가 고르는 가장 최근 own) · 남은 같은 owner 열린 NB · 다른 owner 열린 NC(그대로) · 같은 owner cleared ND(그대로).
    #   변이 '생성 동반 닫기 제거' 면 열린 2(명세 3.5)
    Initialize-KeyLayer
    $entryB = New-RowOwnEntry -Nonce $NONCE_B -AfterIndex 2
    $entryC = New-RowOwnEntry -Nonce $NONCE_C -AfterIndex 2 -OwnerIndex 1
    $entryD = New-RowOwnEntry -Nonce $NONCE_D -AfterIndex 0 -Stage 'cleared' -LaunchState 'pending'
    $entryA = New-RowOwnEntry -Nonce $NONCE_A -AfterIndex 2
    Write-FixtureJournal -Entries @($entryB, $entryC, $entryD, $entryA)
    $consumed = Start-NextWorkerConsume -Nonce $NONCE_A -WorkerRestart $false
    $handoffBefore = Get-HandoffSummary
    $seqBefore = Get-DiskSeq
    $jsonC = Get-EntryJson (Get-DiskEntry -Nonce $NONCE_C)
    $jsonD = Get-EntryJson (Get-DiskEntry -Nonce $NONCE_D)
    $updatesBefore = $script:updateTags.Count
    $tagOutput = @(Add-AbyssJournalEnteredEntry -CleanupOnly $false)
    $newNonce = [string]$script:handoff.Nonce
    $seqDelta = $(if (((Get-DiskSeq) -match '^\d+$') -and ($seqBefore -match '^\d+$')) { [long](Get-DiskSeq) - [long]$seqBefore } else { '(없음)' })
    Assert-Case 'SE4 [저장소 층] 받은 own NA + 같은 owner 열린 NB → Consume 반환·역할 · 생성 태그 · 저장 횟수(같은 저장) · NA·NB · 다른 owner NC 불변 · cleared ND 불변 · 새 항목 · owner 의 열린 항목 · 열쇠 · seq 증가' `
        (J @($consumed, $handoffBefore, (Format-OutputValues -Outputs $tagOutput), ($script:updateTags.Count - $updatesBefore),
                (Format-DiskEntry (Get-DiskEntry -Nonce $NONCE_A)), (Format-DiskEntry (Get-DiskEntry -Nonce $NONCE_B)),
                [string]((Get-EntryJson (Get-DiskEntry -Nonce $NONCE_C)) -ceq $jsonC), [string]((Get-EntryJson (Get-DiskEntry -Nonce $NONCE_D)) -ceq $jsonD),
                (Format-DiskEntry (Get-DiskEntry -Nonce $newNonce)), (Get-OpenEnteredText), (Get-HandoffSummary), $seqDelta)) `
        (J @('ok(1)', 'own|NA|2/32,66', 'changed', 1, 'entered/done/2/2/[32,66]/False//', 'entered/done/2/2/[32,66]/False//', 'True', 'True',
                'entered/launched/0/2/[32,66]/False//', (Get-NonceLabel $newNonce), ('own|{0}|0/32,66' -f (Get-NonceLabel $newNonce)), 1))
}

function Test-RowSE5 {
    # SE5 Role none + env HANDOFF_NONCE(stale 항목) - 그 항목 필드 전부 불변(설계 R2 E9 · 3.3 ⑥ 'Role none 은 받은 env nonce 를 열쇠로 쓰지 않음').
    #   stale 두 모양: 다른 owner 의 열린 entered(이번 owner 후보 아님) · 이미 done 인 같은 owner 항목. 변이 '생성이 Role none 의 env nonce 항목을 닫음' 이면 첫 모양이 done
    $staleCases = @(
        @{ Label = '다른 owner 열린 entered'; OwnerIndex = 1; LaunchState = 'launched'; Reason = ''; Screen = '' },
        @{ Label = '같은 owner done'; OwnerIndex = 0; LaunchState = 'done'; Reason = 'abandoned-death-exit'; Screen = 'field' })
    $actual = foreach ($staleCase in $staleCases) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        Write-FixtureJournal -Entries @((New-RowOwnEntry -Nonce $NONCE_S -OwnerIndex $staleCase.OwnerIndex -LaunchState $staleCase.LaunchState -Reason $staleCase.Reason -Screen $staleCase.Screen))
        $staleBefore = Get-EntryJson (Get-DiskEntry -Nonce $NONCE_S)
        $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -WorkerNonce $NONCE_S
        '{0}: {1}' -f $staleCase.Label, (J @($run.Role, $run.NonceLabel, $run.EnteredTags, [string]((Get-EntryJson (Get-DiskEntry -Nonce $NONCE_S)) -ceq $staleBefore), $run.Presses))
    }
    $expected = foreach ($staleCase in $staleCases) { '{0}: {1}' -f $staleCase.Label, (J @('none', 'W1', 'changed', 'True', '32,66')) }
    Assert-Case 'SE5 [본류 층] Role none + env nonce = stale 항목 → Role · 열쇠 = 새 자기 항목 · 생성 태그 · stale 항목 필드 전부 불변 · 키 1회씩' (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowSE6 {
    # SE6 시작 손상(JournalState corrupt) → 'left' - 생성 시도 0 · 키 0 · 닫기 기록·로그 0 · exit 10 (J2 · 설계 R2 E5(a)). 닫기 함수는 불려도 열쇠가 빈 값이라 기록 0.
    #   nonce 없는 기동 / env nonce 가 있는 기동(E5(b) 모양) 둘 다
    $nonceCases = @('', $NONCE_A)
    $actual = foreach ($nonceCase in $nonceCases) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        Write-CorruptJournal
        $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left' -WorkerNonce $nonceCase
        $label = $(if ($nonceCase) { 'env nonce 있음' } else { 'nonce 없음' })
        '{0}: {1}' -f $label, (J @($run.JournalState, $run.Role, $run.NonceLabel, $run.EnteredCalls, $run.KeyCalls, $run.Presses, $run.CloseCalls, $run.UpdateCount,
                (Get-LineCount -Lines $run.Logs -Fragment $CLOSE_LINE_FRAGMENT), $run.ExitCode, [string]((Get-FolderState -Folder $script:journalFolder) -ceq $run.StateAfterConsume),
                (Format-Logs @(Get-LinesWithPrefix -Lines $run.Logs -Prefixes @('[경고]')))))
    }
    $expected = foreach ($nonceCase in $nonceCases) {
        $label = $(if ($nonceCase) { 'env nonce 있음' } else { 'nonce 없음' })
        '{0}: {1}' -f $label, (J @('corrupt', 'none', '(빈 값)', 0, '', '', 'abandoned-death-exit|selection-proven', 0, 0, '10', 'True', (Format-Logs @($LINE_CONSUME_CORRUPT))))
    }
    Assert-Case "SE6 [본류 층] 시작 손상 → 'left' → JournalState · Role · 열쇠 · 생성 호출 · 키 함수 호출 · 누른 키 · 닫기 호출(불림) · 저장 0 · 닫기 줄 0 · exit · 시작 읽기 뒤 파일 불변 · [경고] 줄" `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowSE7 {
    # SE7 커스텀 OWNER 해석 실패 - 키 0 · exit 4 (E16 · 명세 5절 B5 - 생성 실패와 같게, 실패 반환은 로그 없이 호출부가 [완료]). 시작은 nonce 가 없어 해석하지 않음(C15)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -WorkerOwnerJson 'not json'
    Assert-Case 'SE7 [본류 층] 커스텀 소유자 JSON 해석 실패 → Role · 생성 반환 · 저장 0 · exit · 키 함수 호출 · 누른 키 · [완료]·[경고] 줄' `
        (J @($run.Role, $run.EnteredTags, $run.UpdateCount, $run.ExitCode, $run.KeyCalls, $run.Presses, (Format-Logs @(Get-LinesWithPrefix -Lines $run.Logs -Prefixes @('[완료]', '[경고]'))))) `
        (J @('none', 'owner-unreadable', 0, '4', '', '', (Format-Logs @($LINE_ENTERED_FAILED))))
}

function Test-RowSE8 {
    # SE8 정상 판 cleared - cleared 1 + 열쇠 항목 applied·done · seq +1(한 저장) · 열린 항목 0 (J4 · dev:875). 커스텀 · 비커스텀. 복귀 루프는 볼 필요가 없어 기록 스텁.
    #   변이 'cleared 가 열쇠 항목을 닫지 않음' · 'cleared Changed 표식 누락' 이면 열린 1 / cleared 0(명세 3.5)
    $customCases = @($true, $false)
    $actual = foreach ($customCase in $customCases) {
        Initialize-Row -Custom $customCase
        Set-AfterEntryConfig
        $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'clear' -WorkerReturnMode 'stub'
        $keyEntry = Get-DiskEntry -Nonce $run.NonceRaw
        $label = $(if ($customCase) { '커스텀' } else { '비커스텀' })
        $seqDelta = $(if (($run.SeqBeforeCleared -match '^\d+$') -and ($run.SeqAfterCleared -match '^\d+$')) { [long]$run.SeqAfterCleared - [long]$run.SeqBeforeCleared } else { '(없음)' })
        '{0}: {1}' -f $label, (J @($run.ClearedCalls, (Get-DiskStageCount -Stage 'cleared'), (Format-DiskEntry $keyEntry), (((Get-DiskAppliedText) -split ',') -contains $run.NonceLabel),
                $seqDelta, (Get-OpenEnteredText), (Get-LineCount -Lines $run.Logs -Exact $LINE_CLEARED_SAVED), $run.Exits))
    }
    $expected = foreach ($customCase in $customCases) {
        $label = $(if ($customCase) { '커스텀' } else { '비커스텀' })
        '{0}: {1}' -f $label, (J @(1, 1, 'entered/done/2/2/[32,66]/False//', 'True', 1, '', 1, ''))
    }
    Assert-Case 'SE8 [본류 층] 정상 판 클리어 → cleared 기록 호출 · cleared 항목 수 · 열쇠 항목(done) · applied 에 열쇠 nonce · cleared 저장의 seq 증가 · owner 의 열린 항목 · 성공 줄 · exit 기록 0' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowSE9 {
    # SE9 cleared 저장 실패 - [경고] · 열쇠 항목 열린 채(수용 - 명세 5절 C6). [저장소 층 직접 호출] 실제 생성 → 잠금 점유 → 실제 Add-AbyssJournalClearedEntry
    Initialize-KeyLayer
    $fresh = Invoke-FreshEntry
    $script:workerLogLines.Clear()
    Lock-Journal
    $clearedThrown = ''
    $clearedReturn = '(호출 안 됨)'
    # 반환(구현 명세 ⑤b2 1.2 - @{ Tag; Nonce })은 받아서 봅니다 - 그냥 부르면 해시가 이 함수의 출력으로 흘러 테스트 출력에 표가 찍힙니다
    try {
        $clearedOutputs = @(Add-AbyssJournalClearedEntry)
        $clearedReturn = (@($clearedOutputs | ForEach-Object { '{0}|{1}' -f $_.Tag, $_.Nonce }) -join ',')
    } catch { $clearedThrown = [string]$_.Exception.Message } finally { Close-HeldStreams }
    Assert-Case 'SE9 [저장소 층] cleared 저장 잠금 → 반환 해시 하나 @{ Tag locked; Nonce 빈 값 } (구현 명세 ⑤b2 1.2)' $clearedReturn 'locked|'
    Assert-Case 'SE9 [저장소 층] cleared 저장 잠금 → [완료]·[경고] 줄 · 열쇠 항목 · cleared 항목 수 · applied · 예외' `
        (J @((Format-Logs @(Get-AlertLines)), (Format-DiskEntry (Get-DiskEntry -Nonce $fresh.NonceRaw)), (Get-DiskStageCount -Stage 'cleared'), (Get-DiskAppliedText), $clearedThrown)) `
        (J @((Format-Logs @(($FORMAT_CLEARED_FAILED -f '파일 사용 중'))), 'entered/launched/0/2/[32,66]/False//', 0, '', ''))
}

function Test-RowSE12 {
    # SE12 비커스텀 생성 → 같은 실행 다음 기동 - Resolve own 0(gui:9511 $ownFirst - 비커스텀 일반 시작은 next 만 봄) (dev:910 ③). 첫 기동은 키 뒤 끊김(항목 열림)
    Initialize-Row -Custom $false
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    Assert-Case 'SE12 [본류 층] 비커스텀 생성 → 같은 실행 다음 기동 → 첫 항목 · 후보 · 기동 종류 · nonce env · 항목 그대로(launched)' `
        (J @($first.EnteredTags, $launch.Resolve, $launch.Kind, $launch.NonceEnv, (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)))) `
        (J @('changed', 'none/none', 'none', '(빈 값)', 'entered/launched/2/2/[32,66]/False//'))
}

# ===== R2 본류 층 =====
function Test-RowR2Left {
    # R2-L1 · R2-L2 · SE11(가) - 커스텀 'left' → 실제 복귀 루프 → 출처 완료 → 닫기 → exit 10 → GUI 사본 코드 10 끝 처리 → 다음 기동(GUI 원문 기동 env → 실제 Consume-Handoff)
    # L1 - 닫기 성공 (변이: 출처 완료 블록의 닫기 제거 · 닫기 Changed 표식 누락 → done 0 · 닫기 줄 0 → 다음 기동 own / 자기 항목 생성 뒤 Nonce 갱신 안 함 → 닫기 0)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left'
    $lastDone = Get-LastLine -Lines $first.Logs -Prefix '[완료]'
    Assert-Case 'R2-L1 [본류+루프 층] 커스텀 left → 출처 완료 → exit · 복귀 호출(안전 중지 코드|사유) · 닫기 호출(사유|화면) · 닫기 저장 태그 · 닫기 성공 줄(파일) · [경고] 0 · 마지막 [완료] = 거점 퇴장 문구' `
        (J @($first.ExitCode, $first.ReturnCalls, $first.CloseCalls, $first.CloseUpdateTags, (Get-LineCount -Lines $first.Logs -Exact ($FORMAT_CLOSE_DONE -f 'abandoned-death-exit')),
                (Get-LineCount -Lines $first.Logs -Prefix '[경고]'), $lastDone)) `
        (J @('10', '10|abandoned-death-exit', 'abandoned-death-exit|selection-proven', 'changed', 1, 0, $LEFT_DONE_LINE))
    Assert-Case 'R2-L1 [본류+루프 층] 그 판의 자기 항목 → stage/launchState/index/total/keys/cleanupOnly/reason/screen · applied 추가 0' `
        (J @((Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), (Get-DiskAppliedText))) `
        (J @('entered/done/2/2/[32,66]/False/abandoned-death-exit/selection-proven', ''))
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason $lastDone
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'R2-L1 · SE11(가) [본류 층] → GUI 코드 10 끝 처리 · 다음 기동 후보·종류·nonce env → 다음 워커 Role · 카드 갈래(던전 안 아님) · 새 항목(다른 nonce) · 키(Space 1·B 1)' `
        (J @($exitJournal.Ok, $launch.Resolve, $launch.Kind, $launch.NonceEnv, $second.Role, $second.StartInside, $second.NonceLabel, $second.EnteredTags, (Format-KeyCounts -Keys $second.PressList))) `
        (J @('True', 'none/none', 'none', '(빈 값)', 'none', 'False', 'W2', 'changed', 'Space 1 · B 1'))
    # L2 - 닫기 실패(잠금 점유 - 워커 종료 뒤 해제 → GUI 사본 종료 처리. 잠금이 남으면 GUI 가 locked 오류 정지 - 설계 R2 5.2)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left' -Configure { $script:spyPre['Close-AbyssKeyEntryOnLeave'] = { param($Bound) Lock-Journal } }
    Close-HeldStreams
    Assert-Case 'R2-L2 [본류+루프 층] 커스텀 left → 닫기 실패(잠금) → exit 10 그대로 · 닫기 호출 · 닫기 저장 태그 · [경고] 줄 1 · 항목 열림' `
        (J @($first.ExitCode, $first.CloseCalls, $first.CloseUpdateTags, (Format-Logs @(Get-LinesWithPrefix -Lines $first.Logs -Prefixes @('[경고]'))), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)))) `
        (J @('10', 'abandoned-death-exit|selection-proven', 'locked', (Format-Logs @(($FORMAT_CLOSE_FAILED -f '파일 사용 중'))), 'entered/launched/2/2/[32,66]/False//'))
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason (Get-LastLine -Lines $first.Logs -Prefix '[완료]')
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    Assert-Case 'R2-L2 [본류 층] → GUI 코드 10 끝 처리(넘긴 nonce 없는 기동 - 그 항목을 닫지 않음) → 다음 기동 후보 · 종류 · 같은 항목 (그 기동의 정지는 아래 행)' `
        (J @($exitJournal.Ok, $launch.Resolve, $launch.Kind, $launch.NonceEnv)) `
        (J @('True', 'ok/own', 'own', $first.NonceLabel))
    # 단계 2.5(설계 R2 5.2 L2 끝 - 2.3 에서는 'own 후보' 까지만): 그 다음 기동은 직전 워커가 끝낸 선택 화면에서 시작 → 선분기 1회 정지(own 선택 화면 문구 S10 · 코드 4) ·
    #   클릭 0 · 키 0 · 기록 0(항목은 열린 그대로 - 안내대로 필드에서 다시 시작하면 own 필드 확정으로 닫힘)
    $next = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'R2-L2 [본류 층] → 다음 기동(own · 선택 화면 시작) → Role · 열쇠 · exit · 마지막 [완료] · 진단 · 조작 · 누른 키 · 생성 · 닫기 · 항목 그대로' `
        (J @($next.Role, $next.NonceLabel, $next.ExitCode, $next.LastDone, $next.DiagCalls, $next.Clicks, $next.Presses, $next.EnteredCalls, $next.CloseCalls, $next.OwnCloseCalls,
                (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)))) `
        (J @('own', $first.NonceLabel, '4', $LINE_OVERLAY_SELECTION_OWN, 1, 0, '', 0, '', '', 'entered/launched/2/2/[32,66]/False//'))
}

function Test-RowR2LeftPlain {
    # R2-L3 · R2-L4 - 비커스텀 'left'. L3 닫기 성공 → 항목 done → 다음 기동 Role none / L4 닫기 실패 → [경고] 1 → 다음 기동 Role none(③ 비커스텀) → 새 항목 생성
    #   mutation 이 남은 항목을 닫아 열린 항목 ≤ 1
    Initialize-Row -Custom $false
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left'
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason (Get-LastLine -Lines $first.Logs -Prefix '[완료]')
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'R2-L3 [본류+루프 층] 비커스텀 left 닫기 성공 → exit · 닫기 호출 · 저장 태그 · 항목 · GUI 끝 처리 · 다음 기동 종류 · 다음 워커 Role' `
        (J @($first.ExitCode, $first.CloseCalls, $first.CloseUpdateTags, (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), $exitJournal.Ok, $launch.Kind, $second.Role)) `
        (J @('10', 'abandoned-death-exit|selection-proven', 'changed', 'entered/done/2/2/[32,66]/False/abandoned-death-exit/selection-proven', 'True', 'none', 'none'))
    Initialize-Row -Custom $false
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left' -Configure { $script:spyPre['Close-AbyssKeyEntryOnLeave'] = { param($Bound) Lock-Journal } }
    Close-HeldStreams
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason (Get-LastLine -Lines $first.Logs -Prefix '[완료]')
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'R2-L4 [본류+루프 층] 비커스텀 left 닫기 실패 → [경고] 줄 · exit · GUI 끝 처리 · 다음 기동 종류 · 다음 워커 Role · 새 항목 생성 → 남은 항목 done · owner 의 열린 항목(새 항목 1)' `
        (J @((Format-Logs @(Get-LinesWithPrefix -Lines $first.Logs -Prefixes @('[경고]'))), $first.ExitCode, $exitJournal.Ok, $launch.Kind, $second.Role, $second.EnteredTags,
                (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), (Get-OpenEnteredText))) `
        (J @((Format-Logs @(($FORMAT_CLOSE_FAILED -f '파일 사용 중'))), '10', 'True', 'none', 'none', 'changed', 'entered/done/2/2/[32,66]/False//', $second.NonceLabel))
}

function Test-RowR2Cleanup {
    # R2-C1 · R2-C2 · SE10 · SE11(나) - 커스텀 정리 전용(Role none 수동 던전 안 시작 - HEAD 의 정리 전용 판정) → 클리어 → 본류 끝 -LeaveEntryReason 'cleanup-only' →
    #   실제 복귀 루프 → 출처 완료 → 닫기 → exit 10. C2 = 닫기 실패. 변이 '생성 mutation 이 cleanupOnly 를 늘 거짓' 은 SE10 이 봄
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'clear'
    Assert-Case 'SE10 [본류 층] 정리 전용 판(Role none · 수동 · 던전 안 시작) → Role · 던전 안 판독 · 정리 전용 · 생성 직후 항목(cleanupOnly 참) · 키 1회씩(HEAD 와 같음)' `
        (J @($first.Role, $first.StartInside, $first.CleanupOnly, (Format-DiskEntry $first.CreatedEntry), $first.Presses)) `
        (J @('none', 'True', 'True', 'entered/launched/0/2/[32,66]/True//', '32,66'))
    Assert-Case 'R2-C1 [본류+루프 층] 정리 전용 → 출처 완료 → exit · 복귀 호출 · 닫기 호출 · 닫기 저장 태그 · 닫기 성공 줄 · [경고] 0 · 완료 마커 파일 · cleared 호출 · 그 항목' `
        (J @($first.ExitCode, $first.ReturnCalls, $first.CloseCalls, $first.CloseUpdateTags, (Get-LineCount -Lines $first.Logs -Exact ($FORMAT_CLOSE_DONE -f 'cleanup-only')),
                (Get-LineCount -Lines $first.Logs -Prefix '[경고]'), [IO.File]::Exists($script:markerFilePath), $first.ClearedCalls, (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)))) `
        (J @('10', '10|cleanup-only', 'cleanup-only|selection-proven', 'changed', 1, 0, 'False', 0, 'entered/done/2/2/[32,66]/True/cleanup-only/selection-proven'))
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason (Get-LastLine -Lines $first.Logs -Prefix '[완료]')
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'R2-C1 · SE11(나) [본류 층] → GUI 코드 10 끝 처리 · 다음 기동 후보·종류·nonce env → 다음 워커 Role · 카드 갈래 · 새 항목 · 키(Space 1·B 1)' `
        (J @($exitJournal.Ok, $launch.Resolve, $launch.Kind, $launch.NonceEnv, $second.Role, $second.StartInside, $second.NonceLabel, $second.EnteredTags, (Format-KeyCounts -Keys $second.PressList))) `
        (J @('True', 'none/none', 'none', '(빈 값)', 'none', 'False', 'W2', 'changed', 'Space 1 · B 1'))
    # C2 - 닫기 실패(잠금 - 워커 종료 뒤 해제)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'clear' -Configure { $script:spyPre['Close-AbyssKeyEntryOnLeave'] = { param($Bound) Lock-Journal } }
    Close-HeldStreams
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason (Get-LastLine -Lines $first.Logs -Prefix '[완료]')
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    Assert-Case 'R2-C2 [본류+루프 층] 정리 전용 닫기 실패 → exit · [경고] 줄 · 항목 열림 · GUI 끝 처리 · 다음 기동 종류 · 같은 항목 (그 기동의 정지는 아래 행)' `
        (J @($first.ExitCode, (Format-Logs @(Get-LinesWithPrefix -Lines $first.Logs -Prefixes @('[경고]'))), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), $exitJournal.Ok, $launch.Kind, $launch.NonceEnv)) `
        (J @('10', (Format-Logs @(($FORMAT_CLOSE_FAILED -f '파일 사용 중'))), 'entered/launched/2/2/[32,66]/True//', 'True', 'own', $first.NonceLabel))
    # 단계 2.5(설계 R2 5.2 C2 끝): 다음 기동 own(정리 전용 표지 항목 - CleanupOnly 참) → 선택 화면 시작 → 선분기 1회 정지(S10 · 코드 4) · 클릭 0 · 키 0 · 기록 0
    $next = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'R2-C2 [본류 층] → 다음 기동(own · 표지 항목 · 선택 화면 시작) → Role · 표지 · exit · 마지막 [완료] · 조작 · 누른 키 · 생성 · 닫기 · 항목 그대로' `
        (J @($next.Role, $next.HandoffCleanupOnly, $next.ExitCode, $next.LastDone, $next.Clicks, $next.Presses, $next.EnteredCalls, $next.CloseCalls, $next.OwnCloseCalls,
                (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)))) `
        (J @('own', 'True', '4', $LINE_OVERLAY_SELECTION_OWN, 0, '', 0, '', '', 'entered/launched/2/2/[32,66]/True//'))
}

function Test-RowR2C3 {
    # R2-C3 정리 전용 · 비커스텀 - 해당 없음 단언: 비커스텀 던전 안 시작은 정리 전용 거짓(Test-CustomCleanupOnly 조건 - 커스텀만) → 본류 끝 exit 10 0건
    Initialize-Row -Custom $false
    Set-AfterEntryConfig
    $run = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'clear'
    Assert-Case 'R2-C3 [본류+루프 층] 비커스텀 던전 안 시작 → 던전 안 판독 · 정리 전용 · 복귀 호출 · 닫기 호출 0 · exit 기록 0 · 마지막 [완료]' `
        (J @($run.StartInside, $run.CleanupOnly, $run.ReturnCalls, $run.CloseCalls, $run.Exits, (Get-LastLine -Lines $run.Logs -Prefix '[완료]'))) `
        (J @('True', 'False', '0|', '', '', $MAIN_RETURN_DONE_LINE))
}

function Test-RowR2E1 {
    # R2-E1 'left' → 복귀 중 던전 안 20초 코드 4 - 닫기 0 · 항목 열림 → 다음 수동 시작 own 던전 안 → 이어받기 → Space 0·B 0 (설계 R2 5.2 · R2-3).
    #   변이 '닫기를 left 판정 직후(복귀 루프 앞)로 이동' 이면 항목 done → 다음 시작 Role none → 판 B 2
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left' -WorkerLeftScreen 'inside'
    Assert-Case 'R2-E1 [본류+루프 층] 커스텀 left → 복귀 중 던전 안 → exit · 닫기 호출 0 · 던전 안 정지 줄 · 항목 열림' `
        (J @($first.ExitCode, $first.CloseCalls, (Get-LineCount -Lines $first.Logs -Prefix $LOOP_INSIDE_STOP_PREFIX), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)))) `
        (J @('4', '', 1, 'entered/launched/2/2/[32,66]/False//'))
    $exitJournal = Invoke-GuiExitJournal -ExitCode 4 -WorkerReason (Get-LastLine -Lines $first.Logs -Prefix '[완료]')
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'R2-E1 [본류 층] → GUI 코드 4 끝 처리(넘긴 nonce 없는 기동 - 그 항목을 닫지 않음) → 다음 수동 시작 종류 · Role · 같은 nonce · 시작값 2 · 생성 0 · 이 기동 키 · 판 합계' `
        (J @($exitJournal.Ok, $launch.Kind, $second.Role, $second.NonceLabel, $second.AfterEntryIndex, $second.EnteredCalls, (Format-KeyCounts -Keys $second.PressList), (Get-RowKeyTotals))) `
        (J @('True', 'own', 'own', $first.NonceLabel, '2', 0, 'Space 0 · B 0', 'Space 1 · B 1'))
}

function Test-RowR2E6 {
    # R2-E6 정상 판(정리 전용 아님) 본류 끝 - 닫기 호출 0(매개변수 빈 값) · 그 판 항목은 cleared mutation 이 닫음. 변이 '정상 판에도 -LeaveEntryReason 전달' 이면 닫기 1
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'clear'
    Assert-Case 'R2-E6 [본류+루프 층] 정상 판 본류 끝 → 복귀 호출(안전 중지 0|사유 빈 값) · 닫기 호출 0 · exit 기록 0 · 열쇠 항목(cleared 가 done) · applied 에 열쇠 nonce · 마지막 [완료]' `
        (J @($run.ReturnCalls, $run.CloseCalls, $run.Exits, (Format-DiskEntry (Get-DiskEntry -Nonce $run.NonceRaw)), (((Get-DiskAppliedText) -split ',') -contains $run.NonceLabel),
                (Get-LastLine -Lines $run.Logs -Prefix '[완료]'))) `
        (J @('0|', '', '', 'entered/done/2/2/[32,66]/False//', 'True', $MAIN_RETURN_DONE_LINE))
}

function Test-RowR2E9 {
    # R2-E9 env HANDOFF_NONCE 가 stale 항목(launchState done 또는 owner 불일치)을 가리키는 Role none 기동 → 새 입장 → 'left' - 닫는 대상 = 새 자기 항목 · stale 필드 전부 불변.
    #   변이 'Role none 이 받은 env nonce 를 Nonce 에 남김' 이면 stale 을 닫으려 함 / '생성 뒤 Nonce 갱신 안 함' 이면 새 항목 열림(설계 R2 5.5)
    $staleCases = @(
        @{ Label = '같은 owner done'; OwnerIndex = 0; LaunchState = 'done'; Reason = 'abandoned-pre-entry-start'; Screen = 'field' },
        @{ Label = '다른 owner 열린 entered'; OwnerIndex = 1; LaunchState = 'launched'; Reason = ''; Screen = '' })
    $actual = foreach ($staleCase in $staleCases) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        Write-FixtureJournal -Entries @((New-RowOwnEntry -Nonce $NONCE_S -OwnerIndex $staleCase.OwnerIndex -LaunchState $staleCase.LaunchState -Reason $staleCase.Reason -Screen $staleCase.Screen))
        $staleBefore = Get-EntryJson (Get-DiskEntry -Nonce $NONCE_S)
        $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left' -WorkerNonce $NONCE_S
        '{0}: {1}' -f $staleCase.Label, (J @($run.Role, $run.ExitCode, $run.CloseCalls, $run.CloseUpdateTags, (Format-DiskEntry (Get-DiskEntry -Nonce $run.NonceRaw)),
                [string]((Get-EntryJson (Get-DiskEntry -Nonce $NONCE_S)) -ceq $staleBefore)))
    }
    $expected = foreach ($staleCase in $staleCases) {
        '{0}: {1}' -f $staleCase.Label, (J @('none', '10', 'abandoned-death-exit|selection-proven', 'changed', 'entered/done/2/2/[32,66]/False/abandoned-death-exit/selection-proven', 'True'))
    }
    Assert-Case 'R2-E9 [본류+루프 층] env nonce = stale → Role · exit · 닫기 호출 · 닫기 저장 태그 · 새 자기 항목(닫힘) · stale 항목 필드 전부 불변' (@($actual) -join ' || ') (@($expected) -join ' || ')
}

# ===== R2 루프 층 =====
function Test-RowR2LoopExits {
    # R2-F1 · F2 · E2 · E8 - 실제 복귀 루프(본류 'left' 호출 원문)의 출구별 닫기: 던전 밖 확정으로 끝나는 출구(F1·F2)에서만 1회, 그 밖의 코드 4 출구(E2·E8)는 0 (설계 R2-2·R2-3)
    # F1 - W 확정 뒤 안전 중지: 닫기 1회가 Remove-Item·exit 보다 먼저 · screen field · exit 10 (변이: W 뒤 안전 중지 블록의 닫기 제거 → 닫기 0)
    $loop = Invoke-LoopRow -StartScreen 'field' -Configure { $script:safeStopFlag = $true }
    Assert-Case 'R2-F1 [루프 층] left + W 확정 뒤 안전 중지 → 닫기·플래그 소비·종료 순서 · 닫기 호출 · exit · 안전 중지 줄 · 예외' `
        (J @((Get-CloseOrderText -Events $loop.Events), $loop.CloseCalls, $loop.ExitCode, (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_FIELD_LINE), $loop.Thrown)) `
        (J @('close:abandoned-death-exit|field > remove-flag > exit:10', 'abandoned-death-exit|field', '10', 1, ''))
    # F2 - 출처 완료 시점 안전 중지('어비스' 클릭 순간 예약): 닫기 1회 selection-proven · exit 10(완료 블록 자리)
    $loop = Invoke-LoopRow -StartScreen 'field' -Configure { $script:flagOnAbyssClick = $true }
    Assert-Case 'R2-F2 [루프 층] left + 출처 완료 시점 안전 중지 → 닫기·플래그 소비·종료 순서 · 닫기 호출 · exit · 안전 중지 줄(선택 화면 복귀 완료) · 예외' `
        (J @((Get-CloseOrderText -Events $loop.Events), $loop.CloseCalls, $loop.ExitCode, (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_SELECTION_LINE), $loop.Thrown)) `
        (J @('close:abandoned-death-exit|selection-proven > remove-flag > exit:10', 'abandoned-death-exit|selection-proven', '10', 1, ''))
    # F3 - 마감 만료 + 안전 중지 (구현 단위 복귀 연장 M1): 복귀 루프가 마감까지 화면을 못 찾으면 화면을 모르는 채 끝납니다 - 던전 밖 확정 출구가 아니라 닫기 0 · 플래그 소비 → 호출부 코드 10.
    #      줄은 코드 10 갈래 하나 · 진단은 문맥과 두 스위치 (변이: 새 출구에서 열쇠 닫기 → 닫기 1 / 갈래 바꿔치기 → 그 줄 0). 열쇠 항목은 다음 시작의 own 선분기가 받습니다
    $loop = Invoke-LoopRow -StartScreen 'loading' -Configure { $script:safeStopFlag = $true }
    Assert-Case 'R2-F3 [루프 층] left + 로딩이 마감까지 + 안전 중지 → 소비·종료 순서 · 닫기 호출 0 · exit · 코드 10 갈래 줄 · 다른 두 갈래 줄 0 · W 뒤 출구 줄 0 · 진단(문맥|두 스위치) · 예외' `
        (J @((Get-CloseOrderText -Events $loop.Events), $loop.CloseCalls, $loop.ExitCode, (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_EXPIRED_READY_LINE),
                (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_EXPIRED_LEFT_LINE), (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_EXPIRED_LINE),
                (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_FIELD_LINE), $loop.Diags, $loop.Thrown)) `
        (J @('remove-flag > exit:10', '', '10', 1, 0, 0, 0, $LOOP_EXPIRED_DIAG, ''))
    #      마무리 실행의 'left' 는 같은 자리에서 코드 4 · 'left' 갈래 줄 하나 (클리어하지 않은 판이라 회차로 세지 않음 - 명세 리뷰 2 RV-9 와 같은 이유)
    $loop = Invoke-LoopRow -StartScreen 'loading' -Configure { $script:finishOnly = $true; $script:safeStopFlag = $true }
    $script:finishOnly = $false
    Assert-Case "R2-F3 [루프 층] 마무리 실행 left + 로딩이 마감까지 + 안전 중지 → 소비·종료 순서 · 닫기 호출 0 · exit · 'left' 갈래 줄 · 다른 두 갈래 줄 0 · 진단(문맥|두 스위치) · 예외" `
        (J @((Get-CloseOrderText -Events $loop.Events), $loop.CloseCalls, $loop.ExitCode, (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_EXPIRED_LEFT_LINE),
                (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_EXPIRED_READY_LINE), (Get-LineCount -Lines $loop.Logs -Exact $LOOP_SAFE_STOP_EXPIRED_LINE), $loop.Diags, $loop.Thrown)) `
        (J @('remove-flag > exit:4', '', '4', 1, 0, 0, $LOOP_EXPIRED_DIAG, ''))
    # E2 - W 뒤 메뉴 출처 미확인 코드 4: W 확정 → ESC(토큰) → 양보로 토큰 폐기 → 열린 메뉴를 3회 닫아도(게임이 무시) 남음 → 코드 4 · 닫기 0 (변이: 닫기를 첫 W 확정으로 이동)
    $loop = Invoke-LoopRow -StartScreen 'field' -Configure { $script:yieldAfterEsc = 1; $script:menuSticky = $true }
    Assert-Case 'R2-E2 [루프 층] left → W 확정 · ESC 1 · 메뉴 닫기 3 → exit · 닫기 호출 0 · 메뉴 출처 미확인 줄 · 예외' `
        (J @((Get-LineCount -Lines $loop.Logs -Prefix $LOOP_FIELD_CONFIRM_PREFIX), $loop.EscClicks, $loop.MenuCloses, $loop.ExitCode, $loop.CloseCalls, (Get-LineCount -Lines $loop.Logs -Exact $LOOP_MENU_UNPROVEN_LINE), $loop.Thrown)) `
        (J @(1, 1, 3, '4', '', 1, ''))
    # E8 (가) - 캡처 실패 중 정지(동결 블록 → 실제 Test-SafeStopDuringCaptureFail - 실패 120초 뒤 F9) · (나) 루프 안 나가기 헬퍼 미검출(헬퍼 안 코드 4) → 닫기 0 · 코드 4
    $loop = Invoke-LoopRow -StartScreen 'field' -Configure { $script:capfailPersist = $true; $script:safeStopFlag = $true }
    Assert-Case 'R2-E8(가) [루프 층] left → 끊김 없는 캡처 실패 + 안전 중지 예약 → exit · 닫기 호출 0 · F9 정지 줄 · 복구 탐침 있음 · 예외' `
        (J @($loop.ExitCode, $loop.CloseCalls, (Get-LineCount -Lines $loop.Logs -Exact $CAPTURE_F9_LINE), ($loop.Probes -gt 0), $loop.Thrown)) `
        (J @('4', '', 1, 'True', ''))
    $loop = Invoke-LoopRow -StartScreen 'reward' -Configure { $script:exitClickMode = 'missing' }
    Assert-Case 'R2-E8(나) [루프 층] left → 보상 화면 나가기 헬퍼 미검출 → 헬퍼 호출 · exit · 닫기 호출 0 · 예외' `
        (J @($loop.ExitClicks, $loop.ExitCode, $loop.CloseCalls, $loop.Thrown)) `
        (J @(1, '4', '', ''))
}

function Test-RowR2DiagCopy {
    # R2-D1 (구현 단위 복귀 연장 1.3 · 2.4): 실제 Write-LifeDiagnostics 의 -WithLogCopy. 코드 1 이 아닌 출구는 최상위 catch 의 사본을 타지 않아 run 로그가 회전되면 조사 재료가 0 이 됩니다
    #   (11-03 08:45 은 png 가 회전으로 사라지고 error_*.log 사본으로 조사했습니다). 루프 층의 진단은 모의라 복사 · 회전 · 실패 갈래는 여기서 실제 본문으로 돕니다 (같은 임시 폴더 · 가상 시계 이름)
    Initialize-Row -Custom $false
    Invoke-Expression ($workerTopFunctions['Write-LifeDiagnostics'].Extent.Text -replace '^function Write-LifeDiagnostics', 'function Write-LifeDiagnosticsReal')
    $config = $null
    $script:runLogTargetPath = Join-Path $script:logDir 'mabinogi_run_once.log'
    [IO.File]::WriteAllText($script:runLogTargetPath, '', $UTF8_PLAIN)
    $diagContext = '어비스 복귀 마감 안전 중지'
    $copyLinePrefix = "[진단] $diagContext - 로그 사본 저장: "
    # (가) -CaptureOnly 반환을 지나도 사본 1 · 이름은 오류 세트 규칙 · 앞서 찍은 [완료] 줄이 사본 안 · 사본 줄은 복사 뒤라 사본 밖 · 최상위 catch 의 사본 줄 0
    Write-RunLog $LOOP_SAFE_STOP_EXPIRED_LINE
    Write-LifeDiagnosticsReal -Game $null -Context $diagContext -CaptureOnly -WithLogCopy
    $copies = @(Get-ErrorLogFiles)
    $copyText = $(if ($copies.Count -eq 1) { [IO.File]::ReadAllText($copies[0]) } else { '' })
    $copyName = $(if ($copies.Count -eq 1) { [IO.Path]::GetFileName($copies[0]) } else { '' })
    Assert-Case 'R2-D1 (가) 실제 진단 -CaptureOnly -WithLogCopy → 사본 수 · 이름 · 그 안의 [완료] 줄 · 사본 줄 1(사본 밖) · 오류 사본 줄 0 · 저장 실패 줄 0' `
        (J @($copies.Count, $copyName, $copyText.Contains($LOOP_SAFE_STOP_EXPIRED_LINE), (Get-LineCount -Lines @($script:workerLogLines) -Prefix $copyLinePrefix), $copyText.Contains($copyLinePrefix),
                (Get-LineCount -Lines @($script:workerLogLines) -Prefix $DIAG_COPY_PREFIX), (Get-LineCount -Lines @($script:workerLogLines) -Prefix '[진단] 로그 사본 저장 실패'))) `
        (J @(1, ('error_{0}.log' -f $script:vclock.ToString('yyyyMMdd_\hHH\mmm\sss')), 'True', 1, 'False', 0, 0))
    # (나) 스위치가 없으면 사본 0 - 다른 진단의 동작은 그대로입니다
    Start-Sleep -Seconds 1
    Write-LifeDiagnosticsReal -Game $null -Context '어비스 메뉴 항목 미발견' -CaptureOnly
    Assert-Case 'R2-D1 (나) 실제 진단 스위치 없음 → 사본 수 그대로' (@(Get-ErrorLogFiles).Count) 1
    # (다) 캡처가 던져도(이 하니스에는 창 좌표 형식이 없음) catch 가 받고 finally 가 사본을 남깁니다 - png 실패가 로그 사본을 막지 않습니다 (설계 리뷰 1/2 ④)
    Start-Sleep -Seconds 1
    $diagThrown = ''
    try { Write-LifeDiagnosticsReal -Game (Get-Process -Id $PID) -Context $diagContext -CaptureOnly -WithLogCopy } catch { $diagThrown = [string]$_.Exception.Message }
    Assert-Case 'R2-D1 (다) 캡처 실패 → 예외 밖으로 0 · 진단 수집 실패 줄 1 · 사본 2' `
        (J @($diagThrown, (Get-LineCount -Lines @($script:workerLogLines) -Prefix '[진단] 진단 수집 실패'), @(Get-ErrorLogFiles).Count)) (J @('', 1, 2))
    # (라) 회전: 오래된 사본 12개를 두고 새 사본을 남기면 최신 10개만 (최상위 catch 의 사본과 같은 규칙)
    foreach ($oldIndex in 0..11) {
        $oldPath = Join-Path $script:logDir ('error_19990101_h00m00s{0:00}.log' -f $oldIndex)
        [IO.File]::WriteAllText($oldPath, 'old', $UTF8_PLAIN)
        [IO.File]::SetLastWriteTime($oldPath, ([datetime]'2000-01-01').AddMinutes($oldIndex))
    }
    Start-Sleep -Seconds 1
    Write-LifeDiagnosticsReal -Game $null -Context $diagContext -CaptureOnly -WithLogCopy
    $rotated = @(Get-ErrorLogFiles | ForEach-Object { [IO.Path]::GetFileName($_) })
    Assert-Case 'R2-D1 (라) 회전 → 사본 10 · 새 사본 셋 남음 · 가장 오래된 표본 지워짐' `
        (J @($rotated.Count, @($rotated | Where-Object { $_ -like 'error_2026*' }).Count, @($rotated | Where-Object { $_ -eq 'error_19990101_h00m00s00.log' }).Count)) (J @(10, 3, 0))
    # (마) 복사 실패(로그 파일 없음)는 안쪽 try 가 받아 [진단] 줄만 남고 출구를 막지 않습니다 - 사본 줄 0
    Start-Sleep -Seconds 1
    $script:runLogTargetPath = Join-Path $script:logDir 'does_not_exist.log'
    $linesBefore = $script:workerLogLines.Count
    $diagThrown = ''
    try { Write-LifeDiagnosticsReal -Game $null -Context $diagContext -CaptureOnly -WithLogCopy } catch { $diagThrown = [string]$_.Exception.Message }
    $newLines = @($script:workerLogLines | Select-Object -Skip $linesBefore)
    $script:runLogTargetPath = ''
    Assert-Case 'R2-D1 (마) 복사 실패 → 예외 밖으로 0 · 새 줄 1(저장 실패) · 사본 줄 0' `
        (J @($diagThrown, $newLines.Count, (Get-LineCount -Lines $newLines -Prefix '[진단] 로그 사본 저장 실패'), (Get-LineCount -Lines $newLines -Prefix $copyLinePrefix))) (J @('', 1, 1, 0))
}

# ===== R2 저장소 층 =====
function Test-RowR2Storage {
    # R2-L1s · E5 · E7 · N1 · N2 - 실제 Close-AbyssKeyEntryOnLeave 직접 호출(실제 저장소 + 임시 폴더 파일)
    # L1s(보강 - 설계 R2 5.2 L1 '픽스처 항목에 screen 속성이 없어도 성공'): screen·reason 이 없는 옛 항목을 받은 own(실제 Consume-Handoff) → 닫기 성공 · 필드 추가 ·
    #   [경고] 0 · 예외 0 (변이 'Set-AbyssJournalProperty 대신 대입문' 이면 없는 속성 대입 예외)
    Initialize-KeyLayer
    Write-FixtureJournal -Entries @((New-RowOwnEntry -Nonce $NONCE_A -AfterIndex 2 -WithoutScreen))
    $consumed = Start-NextWorkerConsume -Nonce $NONCE_A -WorkerRestart $false
    $fieldsBefore = Format-DiskEntry (Get-DiskEntry -Nonce $NONCE_A)
    $closeThrown = ''
    $closeOutput = @()
    try { $closeOutput = @(Close-AbyssKeyEntryOnLeave -Reason 'abandoned-death-exit' -Screen 'selection-proven') } catch { $closeThrown = [string]$_.Exception.Message }
    Assert-Case 'R2-L1s [저장소 층] screen·reason 없는 옛 열쇠 항목(own) → 시작 반환 · 닫기 전 항목 · 닫기 출력 · 저장 태그 · 닫은 항목 · 로그 · 예외' `
        (J @($consumed, $fieldsBefore, (Format-Outputs -Outputs $closeOutput), (@($script:closeUpdateTags) -join ','), (Format-DiskEntry (Get-DiskEntry -Nonce $NONCE_A)), (Format-Logs @($script:workerLogLines)), $closeThrown)) `
        (J @('ok(1)', 'entered/launched/2/2/[32,66]/False/(없음)/(없음)', '(0)', 'changed', 'entered/done/2/2/[32,66]/False/abandoned-death-exit/selection-proven',
                (Format-Logs @(($FORMAT_CLOSE_DONE -f 'abandoned-death-exit'))), ''))
    # E5 - 열쇠 nonce 없음: (가) journal 'corrupt' 로 시작(Role none · 키 0 · 자기 항목 0) (나) 그 기동에 env HANDOFF_NONCE 가 있음 → 닫기 기록·로그 0 · 파일 불변
    #   (exit 10 은 본류 층 SE6) - 변이 'Role none 이 받은 env nonce 를 Nonce 에 남김' 이면 (나) 가 기록을 시도
    $nonceCases = @('', $NONCE_A)
    $actual = foreach ($nonceCase in $nonceCases) {
        Initialize-KeyLayer
        Write-CorruptJournal
        $consumed = Start-NextWorkerConsume -Nonce $nonceCase -WorkerRestart $false
        $stateBefore = Get-FolderState -Folder $script:journalFolder
        $script:workerLogLines.Clear()
        $updatesBefore = $script:updateTags.Count
        $closeThrown = ''
        $closeOutput = @()
        try { $closeOutput = @(Close-AbyssKeyEntryOnLeave -Reason 'abandoned-death-exit' -Screen 'selection-proven') } catch { $closeThrown = [string]$_.Exception.Message }
        $label = $(if ($nonceCase) { '(나) env nonce 있음' } else { '(가) nonce 없음' })
        '{0}: {1}' -f $label, (J @($consumed, [string](Get-HandoffField 'JournalState'), (Get-NonceLabel ([string](Get-HandoffField 'Nonce'))), (Format-Outputs -Outputs $closeOutput),
                ($script:updateTags.Count - $updatesBefore), (Format-Logs @($script:workerLogLines)), [string]((Get-FolderState -Folder $script:journalFolder) -ceq $stateBefore), $closeThrown))
    }
    $expected = foreach ($nonceCase in $nonceCases) {
        $label = $(if ($nonceCase) { '(나) env nonce 있음' } else { '(가) nonce 없음' })
        '{0}: {1}' -f $label, (J @('ok(1)', 'corrupt', '(빈 값)', '(0)', 0, '[]', 'True', ''))
    }
    Assert-Case 'R2-E5 [저장소 층] 열쇠 nonce 없음(손상 시작) → 시작 반환 · JournalState · 열쇠 · 닫기 출력 · 저장 0 · 로그 0 · 파일 불변 · 예외' (@($actual) -join ' || ') (@($expected) -join ' || ')
    # E7 - 닫기 mutator 예외(Set-AbyssJournalProperty 의 launchState·reason·screen 쓰기 throw) → 예외가 닫기 함수 밖으로 전파 · 닫기 [경고] 0 · 파일 무변경.
    #   코드 1·오류 세트는 결합 층 TC2 - 변이 '닫기 함수를 try/catch 로 감싸 삼킴'·'예외를 [경고] 로' 는 이 행(전파 0)과 TC2 가 함께 잡음
    Initialize-KeyLayer
    $fresh = Invoke-FreshEntry
    $stateBefore = Get-FolderState -Folder $script:journalFolder
    $script:workerLogLines.Clear()
    $script:throwHook = @{ Name = 'Set-AbyssJournalProperty'; Match = { param($HookBound) @('launchState', 'reason', 'screen') -contains [string]$HookBound['Name'] }; Message = $INJECTED_PROPERTY }
    $closeThrown = ''
    try { [void](Close-AbyssKeyEntryOnLeave -Reason 'abandoned-death-exit' -Screen 'selection-proven') } catch { $closeThrown = [string]$_.Exception.Message }
    Assert-Case 'R2-E7 [저장소 층] 닫기 mutator 예외 → 전파된 예외 · 갈고리 발사 · [경고] 줄 · 로그 · 파일 무변경 · 열쇠 항목' `
        (J @($closeThrown, $script:throwFired, (Get-LineCount -Lines @($script:workerLogLines) -Prefix '[경고]'), (Format-Logs @($script:workerLogLines)),
                [string]((Get-FolderState -Folder $script:journalFolder) -ceq $stateBefore), (Format-DiskEntry (Get-DiskEntry -Nonce $fresh.NonceRaw)))) `
        (J @($INJECTED_PROPERTY, 1, 0, '[]', 'True', 'entered/launched/0/2/[32,66]/False//'))
    # N1 · N2 - 무변경(unchanged): 열쇠 항목이 journal 에 없음(stale 정리 뒤) / 이미 done(GUI 가 먼저 닫음) → 쓰기 생략 - 임시 파일 쓰기 0 · 직전본 표지 그대로(Replace 0) ·
    #   본 파일 바이트 불변 · 로그 0 (설계 R2 5.2 N1). 변이 '이미 done 갈래에도 Changed' · '무변경에도 성공 줄' 이 여기서 드러남
    $caseNames = @('N1', 'N2')
    $actual = foreach ($caseName in $caseNames) {
        Initialize-KeyLayer
        $fresh = Invoke-FreshEntry
        if ($caseName -eq 'N1') { Remove-DiskEntry -Nonce $fresh.NonceRaw } else { Set-DiskEntryClosed -Nonce $fresh.NonceRaw -Reason 'abandoned-pre-entry-start' -Screen 'field' }
        Write-BakMarker
        $entryBefore = Get-EntryJson (Get-DiskEntry -Nonce $fresh.NonceRaw)
        $mainHash = Get-FileHashText -Path $script:abyssJournalPath
        $bakHash = Get-FileHashText -Path ($script:abyssJournalPath + '.bak')
        $script:workerLogLines.Clear()
        $script:closeUpdateTags.Clear()
        $script:tempWrites = 0
        $closeThrown = ''
        $closeOutput = @()
        try { $closeOutput = @(Close-AbyssKeyEntryOnLeave -Reason 'abandoned-death-exit' -Screen 'selection-proven') } catch { $closeThrown = [string]$_.Exception.Message }
        $bakText = [IO.File]::ReadAllText($script:abyssJournalPath + '.bak')
        '{0}: {1}' -f $caseName, (J @((@($script:closeUpdateTags) -join ','), $script:tempWrites, [string]($mainHash -ceq (Get-FileHashText -Path $script:abyssJournalPath)),
                [string]($bakHash -ceq (Get-FileHashText -Path ($script:abyssJournalPath + '.bak'))), $bakText.Contains($BAK_MARKER_SAVED_BY),
                [string]((Get-EntryJson (Get-DiskEntry -Nonce $fresh.NonceRaw)) -ceq $entryBefore), (Format-Logs @($script:workerLogLines)), (Format-Outputs -Outputs $closeOutput), $closeThrown))
    }
    $expected = foreach ($caseName in $caseNames) { '{0}: {1}' -f $caseName, (J @('unchanged', 0, 'True', 'True', 'True', 'True', '[]', '(0)', '')) }
    Assert-Case 'R2-N1 · N2 [저장소 층] 항목 없음 / 이미 done → 저장 태그 · 임시 파일 쓰기 · 본 파일 불변 · 직전본 불변 · 직전본 표지 · 항목 필드 불변 · 로그 · 출력 · 예외' (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowR2L2s {
    # R2-L2s(보강 - 2.3 표 · 설계 R2 3.6 '실패 종류별 문구'): 닫기 저장 실패의 나머지 두 종류 - io-failed(.lock 자리 폴더 - SE2 와 같은 주입) → '[경고] … (기록 실패)
    #   - 안내 꼬리' / corrupt(본 파일·직전본 손상) → '[경고] … (파일 손상)' 안내 꼬리 없음(GUI 가 다음 기동 전에 손상 정지 문구로 안내). 둘 다 [경고] 1 · 출력 0 ·
    #   예외 0 · 파일 불변. L2·C2 는 locked 만 봐서 두 종류의 낱말 바꿈 · corrupt 에 안내 꼬리 붙임이 살아남았습니다(변이 검증). [저장소 층 직접 호출] 실제 생성으로
    #   열쇠를 채운 뒤 주입
    $failureCases = @(
        @{ Label = 'io-failed'; Line = ($FORMAT_CLOSE_FAILED -f '기록 실패') },
        @{ Label = 'corrupt'; Line = $LINE_CLOSE_CORRUPT })
    $actual = foreach ($failureCase in $failureCases) {
        Initialize-KeyLayer
        $fresh = Invoke-FreshEntry
        if ($failureCase.Label -eq 'io-failed') { New-LockFolder } else { Write-CorruptJournal }
        $stateBefore = Get-FolderState -Folder $script:journalFolder
        $script:workerLogLines.Clear()
        $script:closeUpdateTags.Clear()
        $closeThrown = ''
        $closeOutput = @()
        try { $closeOutput = @(Close-AbyssKeyEntryOnLeave -Reason 'abandoned-death-exit' -Screen 'selection-proven') } catch { $closeThrown = [string]$_.Exception.Message }
        $stateAfter = Get-FolderState -Folder $script:journalFolder
        Remove-LockFolder
        '{0}: {1}' -f $failureCase.Label, (J @($fresh.Tag, (@($script:closeUpdateTags) -join ','), (Format-Logs @($script:workerLogLines)), (Format-Outputs -Outputs $closeOutput),
                $closeThrown, [string]($stateAfter -ceq $stateBefore)))
    }
    $expected = foreach ($failureCase in $failureCases) { '{0}: {1}' -f $failureCase.Label, (J @('changed', $failureCase.Label, (Format-Logs @($failureCase.Line)), '(0)', '', 'True')) }
    Assert-Case 'R2-L2s [저장소 층] 닫기 저장 io-failed / corrupt → 생성 태그 · 닫기 저장 태그 · 로그(종류별 낱말 - corrupt 는 안내 꼬리 없음) · 출력 · 예외 · 파일 불변' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

# ===== 단계 2.5·2.6 - 이어받기 시작 경로의 키 사슬 (OK) =====
# 공통 모양(명세 3.3 OK 표 · 실행 층 규칙 - 전부 본류 층): 첫 기동 = 선택 화면 시작(카드 → 입장) → 키 지점 자기 항목 W1 → Space·B → 클리어 대기 중 끊김(즉시 중지·
#   GUI 종료·PC 종료 - GUI 종료 처리 없음, 행 owner 의 열린 entered index 2) → 다음 수동 시작의 기동 env(GUI 원문 - Resolve 가 own 을 고름) → 둘째 기동(실제
#   Consume-Handoff → 실제 선분기 → 본류 결론 대입 → 키 지점 · 꼬리). 키 행은 판마다 'B ≤ 1 · Space ≤ 1' 을 함께 봅니다(판이 둘인 행은 판별 합계)
function Test-RowOK1 {
    # OK1 · R2-C7 (명세 3.3 OK1 · 설계 R2 5.2 C7 · dev:993 [V6-P1-1]) - 첫 판 Space·B 뒤 끊김 → 수동 시작(시작 게이트 S3 none · 일반 시작 own · 실제 Consume-Handoff) →
    #   던전 안 → 선분기 결론 '던전 안'(이어받기 - 시작 직후 계측 줄 1) → 표지 없는 own 이라 정리 전용 거짓(본류 결론 대입 - 인자 $cleanupByScreen 거짓) → 키 지점 생성 0 ·
    #   index 2 부터라 Space 0·B 0 → 완주 = 마커 + cleared(열쇠 항목 applied·done - J4) · exit 10 0 → 계상 1. 변이 'own 던전 안 수동에 InsideAlready'(정리 전용 참 → 계상 0) ·
    #   'Resolve own 후보 제거'(Role none → 새 항목 → B 2) · '결론 대입 제거'(본류가 다시 판독) 가 여기서 드러남(명세 3.5)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $gate = Invoke-GuiStartGate
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'clear' -KeepHandoffEnv
    Assert-Case 'OK1 · R2-C7 [본류+루프 층] 첫 판 Space·B 뒤 끊김 → 수동 시작 S3 · 기동 종류·nonce env → Role · 같은 nonce · 시작값 · 선분기 결론 · 시작 직후 계측 줄 · 정리 전용 · 생성 0 · 이 기동 키 · 판 끝 · 열쇠 항목 · applied · 판 합계' `
        (J @($first.Thrown, $gate, $launch.Kind, $launch.NonceEnv, $second.Role, $second.NonceLabel, $second.AfterEntryIndex, $second.StartScreen,
                (Get-LineCount -Lines $second.Logs -Prefix $LINE_START_MEASURE_PREFIX), $second.CleanupOnly, $second.EnteredCalls, (Format-KeyCounts -Keys $second.PressList),
                (Get-RunEndText $second), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), (((Get-DiskAppliedText) -split ',') -contains $first.NonceLabel), (Get-RowKeyTotals))) `
        (J @('CRASH-CLEAR-WAIT', 'none/(빈 값)', 'own', 'W1', 'own', 'W1', '2', 'inside', 1, 'False', 0, 'Space 0 · B 0', '0(끝까지) · 마커 True · cleared 1',
                'entered/done/2/2/[32,66]/False//', 'True', 'Space 1 · B 1'))
}

function Test-RowOK2 {
    # OK2 = 설계 R4 O2 키 변형(명세 3.3 · R4 6.2 · 점검:226 핵심 행) - 첫 판 Space·B 뒤 GUI 종료 → 그 던전 안에서 필드 모양 표본(첫 표본부터 W 미만 - 입장 과도·추적기
    #   오독 모형) 뒤 던전 안 → 수동 시작 → Role own · 선분기 결론 '던전 안' · own 닫기 0 · 필드 확정 줄 0 · 복귀 루프 0 → Space 0·B 0(그 판 B 합계 1). v10 '필드 2연속' 이면
    #   닫기 1 → 다음 시작 B 재전송(변이 R4-M1 · M7)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'field' -WorkerClear 'halt' -KeepHandoffEnv -WorkerTimeline @(@{ At = 0; Screen = 'field' }, @{ At = ($memberFieldSettleSeconds - 1); Screen = 'inside' })
    Assert-Case 'OK2 [본류 층] 던전 안 필드 모양(W 미만) 뒤 던전 안 수동 시작 → 기동 종류 · Role · 선분기 결론 · own 닫기 · 필드 확정 줄 · 복귀 루프 호출 · 이 기동 키 · 클리어 대기 도달 · 열쇠 항목 · 판 합계' `
        (J @($launch.Kind, $second.Role, $second.StartScreen, $second.OwnCloseCalls, (Get-LineCount -Lines $second.Logs -Prefix ($FORMAT_FIELD_SETTLED_PREFIX -f $memberFieldSettleSeconds)),
                $second.ReturnCalls, (Format-KeyCounts -Keys $second.PressList), $second.Halted, (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), (Get-RowKeyTotals))) `
        (J @('own', 'own', 'inside', '', 0, '', 'Space 0 · B 0', 'True', 'entered/launched/2/2/[32,66]/False//', 'Space 1 · B 1'))
}

function Test-RowOK3 {
    # OK3 = 설계 R4 O3 키 변형(명세 3.3 · R4 6.2) - 첫 판 Space·B 뒤 끊김 → 손으로 나와 필드에서 수동 시작 → 선분기 필드 확정(W) → own 닫기(abandoned-pre-entry-start · field ·
    #   성공 줄 1) → 필드 확정 줄 1 → 결론 '필드' → 본류 필드 분기의 복귀 루프(W 를 다시 셈) → exit 10 → GUI 코드 10 끝 처리(이미 done 이라 불변) → 다음 기동 Role none →
    #   카드 → 입장 → 새 자기 항목 → Space 1·B 1. 판당 B 1(끊긴 판 W1 = 첫 기동의 1 · 새 판 W2 = 셋째 기동의 1). 변이 '필드 시작에 handoff index' 면 새 판 키 0(명세 3.5)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'field' -WorkerClear 'halt' -KeepHandoffEnv
    $entryAfterWorker = Get-EntryJson (Get-DiskEntry -Nonce $first.NonceRaw)
    Assert-Case 'OK3 [본류+루프 층] 필드 수동 시작 → 기동 종류 · Role · own 닫기(화면) · 그 저장 태그 · 닫기 성공 줄 · 필드 확정 줄 · 선분기 결론 · 복귀 호출 · exit · 마지막 [완료] · 이 기동 키 · 끊긴 판 항목' `
        (J @($launch.Kind, $second.Role, $second.OwnCloseCalls, $second.OwnCloseTags, (Get-LineCount -Lines $second.Logs -Exact ($FORMAT_OWN_CLOSE_DONE -f 'field')),
                (Get-LineCount -Lines $second.Logs -Prefix ($FORMAT_FIELD_SETTLED_PREFIX -f $memberFieldSettleSeconds)), $second.StartScreen, $second.ReturnCalls, $second.ExitCode,
                $second.LastDone, (Format-KeyCounts -Keys $second.PressList), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)))) `
        (J @('own', 'own', 'field', 'changed', 1, 1, 'field', '10|(인자 없음)', '10', $READY_RETURN_DONE_LINE, 'Space 0 · B 0', 'entered/done/2/2/[32,66]/False/abandoned-pre-entry-start/field'))
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason $second.LastDone
    $entryAfterGui = Get-EntryJson (Get-DiskEntry -Nonce $first.NonceRaw)
    $nextLaunch = Invoke-GuiLaunch -LaunchRestart $false
    $third = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'OK3 [본류 층] → GUI 코드 10 끝 처리 · 끊긴 판 항목 필드 불변(이미 done) · 다음 기동 종류·nonce env → 셋째 Role · 새 열쇠 · 생성 · 판별 키(판당 B ≤ 1 · Space ≤ 1)' `
        (J @($exitJournal.Ok, [string]($entryAfterGui -ceq $entryAfterWorker), $nextLaunch.Kind, $nextLaunch.NonceEnv, $third.Role, $third.NonceLabel, $third.EnteredTags,
                (Format-RunKeys -Label 'W1' -Keys @($first.PressList + $second.PressList)), (Format-RunKeys -Label 'W2' -Keys $third.PressList))) `
        (J @('True', 'True', 'none', '(빈 값)', 'none', 'W2', 'changed', 'W1 판 Space 1 · B 1', 'W2 판 Space 1 · B 1'))
}

function Test-RowOK4 {
    # OK4 = 설계 R4 O4·O4″ 키 변형(명세 3.3 · R4 6.2) - 첫 판 Space·B 뒤 끊김 → 손으로 클리어·다시 하기 뒤 준비 패널에서 수동 시작 → own 닫기(ready) → 선분기 B2 단계 →
    #   입장 2연속(입장 계측 줄 1) → 새 자기 항목(ownFreshEntry - index 0 · 새 nonce = 열쇠 · cleanupOnly 거짓 · (ownFreshEntry) 줄 1) → 결론 '던전 안' → 정리 전용 거짓 →
    #   새 판 Space 1·B 1. O4: 그 판 완주 → 새 항목 cleared(applied·done) · 계상 1 · 열린 항목 0 / O4″: 그 판 키 뒤 끊김 → 그 던전 안 수동 시작 → Role own(새 항목) ·
    #   표지 거짓 · 정리 전용 거짓 · index 이어받음(B 0 - 그 판 B 합계 1) → 완주 → 계상 1. 변이 R4-M8(새 항목 cleanupOnly 참 → O4″ 정리 전용 참·계상 0) · 'own 패널에 옛
    #   index'(새 판 키 0) 가 여기서 드러남
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'ready' -WorkerClear 'clear' -KeepHandoffEnv -WorkerTimeline $PANEL_TIMELINE
    Assert-Case 'OK4(O4) [본류+루프 층] 준비 패널 수동 시작 → 기동 종류 · Role · own 닫기(화면)·태그 · 끊긴 판 항목 · 입장 계측 줄 · (ownFreshEntry) 줄 · 생성 태그 · 생성 직후 새 항목 · FreshEntry · 새 열쇠 · 결론 · 정리 전용 · 이 기동 키 · 판 끝 · 새 항목 · 열린 항목' `
        (J @($launch.Kind, $second.Role, $second.OwnCloseCalls, $second.OwnCloseTags, (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)),
                (Get-LineCount -Lines $second.Logs -Prefix $LINE_ENTRY_MEASURE_PREFIX), (Get-LineCount -Lines $second.Logs -Exact $LINE_OWN_FRESH_ENTRY), $second.EnteredTags,
                (Format-DiskEntry $second.CreatedEntry), $second.FreshEntry, $second.NonceLabel, $second.StartScreen, $second.CleanupOnly, (Format-KeyCounts -Keys $second.PressList),
                (Get-RunEndText $second), (Format-DiskEntry (Get-DiskEntry -Nonce $second.NonceRaw)), (Get-OpenEnteredText))) `
        (J @('own', 'own', 'ready', 'changed', 'entered/done/2/2/[32,66]/False/abandoned-pre-entry-start/ready', 1, 1, 'changed', 'entered/launched/0/2/[32,66]/False//', 'True',
                'W2', 'inside', 'False', 'Space 1 · B 1', '0(끝까지) · 마커 True · cleared 1', 'entered/done/2/2/[32,66]/False//', ''))
    # O4″ - ownFreshEntry 판의 키 뒤 끊김 → 그 던전 안 수동 시작
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'ready' -WorkerClear 'crash' -KeepHandoffEnv -WorkerTimeline $PANEL_TIMELINE
    $relaunch = Invoke-GuiLaunch -LaunchRestart $false
    $third = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'clear' -KeepHandoffEnv
    Assert-Case 'OK4(O4″) [본류+루프 층] → ownFreshEntry 판 키 뒤 끊김 → 생성 태그 · 새 열쇠 · 끊김 → 다음 기동 종류·nonce env → 셋째 Role · 열쇠 · 표지 · 정리 전용 · 시작값 · 생성 0 · 이 기동 키 · 판 끝 · 새 항목 · 새 판 키(판당)' `
        (J @($second.EnteredTags, $second.NonceLabel, $second.Thrown, $relaunch.Kind, $relaunch.NonceEnv, $third.Role, $third.NonceLabel, $third.HandoffCleanupOnly, $third.CleanupOnly,
                $third.AfterEntryIndex, $third.EnteredCalls, (Format-KeyCounts -Keys $third.PressList), (Get-RunEndText $third), (Format-DiskEntry (Get-DiskEntry -Nonce $second.NonceRaw)),
                (Format-RunKeys -Label 'W2' -Keys @($second.PressList + $third.PressList)))) `
        (J @('changed', 'W2', 'CRASH-CLEAR-WAIT', 'own', 'W2', 'own', 'W2', 'False', 'False', '2', 0, 'Space 0 · B 0', '0(끝까지) · 마커 True · cleared 1', 'entered/done/2/2/[32,66]/False//',
                'W2 판 Space 1 · B 1'))
}

function Test-RowOK5 {
    # OK5 = 설계 R4 O7′·O7″ 키 변형(명세 3.3 · R4 6.2 · 4.5) - 정리 전용 표지 항목(손으로 들어간 판 = Role none 수동 던전 안 시작의 자기 항목 cleanupOnly 참)을 받은 own 이
    #   준비 패널에서 시작 → own 닫기 시도 → 표지(CleanupOnly) 비움(닫기 결과와 무관 - 결과 갈래 밖) → B2 → 새 자기 항목(cleanupOnly 거짓) → 정리 전용 거짓 → 새 판 Space 1·B 1 ·
    #   계상 1 · 열린 항목 0. O7″ = 닫기 저장 1회만 locked → own 닫기 실패 [경고] 1 · 그래도 표지 거짓 → 새 항목 생성 mutation 이 남은 열린 표지 항목을 함께 닫음(launchState
    #   만 - 명세 B6). 변이 '닫기 뒤 CleanupOnly 비움 제거'(R4-M9 - 정리 전용 참 · 계상 0 · exit 10) · '비움을 닫기 성공 갈래에만'(R4-M24 - O7″ 에서 같은 결과)
    $variants = @('O7′', 'O7″')
    $actual = foreach ($variant in $variants) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        $first = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'crash'
        $launch = Invoke-GuiLaunch -LaunchRestart $false
        $configure = $null
        if ($variant -eq 'O7″') {
            $configure = {
                $script:spyPre['Close-AbyssOwnEntryBeforeEntry'] = { param($Bound) Lock-Journal }
                $script:spyPost['Close-AbyssOwnEntryBeforeEntry'] = { param($Bound, $Output) Close-HeldStreams }
            }
        }
        $second = Invoke-Worker -WorkerStart 'ready' -WorkerClear 'clear' -KeepHandoffEnv -WorkerTimeline $PANEL_TIMELINE -Configure $configure
        Close-HeldStreams
        '{0}: {1}' -f $variant, (J @($first.CleanupOnly, (Format-DiskEntry $first.CreatedEntry), $launch.Kind, $second.Role, $second.OwnCloseCalls, $second.OwnCloseTags,
                (Format-Logs @(Get-LinesWithPrefix -Lines $second.Logs -Prefixes @('[경고]'))), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)),
                (Get-LineCount -Lines $second.Logs -Exact $LINE_OWN_FRESH_ENTRY), (Format-DiskEntry $second.CreatedEntry), $second.HandoffCleanupOnly, $second.CleanupOnly,
                (Format-KeyCounts -Keys $second.PressList), (Get-RunEndText $second), (Get-OpenEnteredText)))
    }
    $expected = foreach ($variant in $variants) {
        $closeTag = $(if ($variant -eq 'O7″') { 'locked' } else { 'changed' })
        $warnings = $(if ($variant -eq 'O7″') { Format-Logs @(($FORMAT_OWN_CLOSE_FAILED -f '파일 사용 중')) } else { Format-Logs @() })
        $oldEntry = $(if ($variant -eq 'O7″') { 'entered/done/2/2/[32,66]/True//' } else { 'entered/done/2/2/[32,66]/True/abandoned-pre-entry-start/ready' })
        '{0}: {1}' -f $variant, (J @('True', 'entered/launched/0/2/[32,66]/True//', 'own', 'own', 'ready', $closeTag, $warnings, $oldEntry, 1, 'entered/launched/0/2/[32,66]/False//',
                'False', 'False', 'Space 1 · B 1', '0(끝까지) · 마커 True · cleared 1', ''))
    }
    Assert-Case 'OK5(O7′·O7″) [본류+루프 층] 표지 항목 + 준비 패널 → 첫 판 정리 전용·표지 항목 · 기동 종류 · Role · own 닫기·태그 · [경고] 줄 · 표지 항목 · (ownFreshEntry) 줄 · 새 항목 · 표지 · 정리 전용 · 새 판 키 · 판 끝 · 열린 항목' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowOK6 {
    # OK6 = 설계 R4 O11 키 변형(명세 3.3 · R4 6.2 · Q-R4-8 ① - 수용 고정): 던전 안에서 필드 모양이 W 를 넘어 이어진 오독(W+1초) 뒤 던전 안 → 선분기 필드 확정 → own 닫기 →
    #   결론 '필드' → 본류 필드 분기의 복귀 루프가 던전 안(HUD + 던전 목표) 2연속·20초로 코드 4 → GUI 끝 처리(이미 done - 불변) → 다음 수동 시작 Role none → 던전 안 정리
    #   전용 → 새 항목(cleanupOnly 참) → 키 1회 → 그 판 B 합계 2(Space 도 2). 수용한 창(W 승인 조건 ㉷ 과 같은 위험)을 고정하는 행 - 값이 바뀌면 수용 범위가 바뀐 것
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'field' -WorkerClear 'halt' -KeepHandoffEnv -WorkerTimeline @(@{ At = 0; Screen = 'field' }, @{ At = ($memberFieldSettleSeconds + 1); Screen = 'inside' })
    $exitJournal = Invoke-GuiExitJournal -ExitCode 4 -WorkerReason $second.LastDone
    $nextLaunch = Invoke-GuiLaunch -LaunchRestart $false
    $third = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'OK6(O11 - 수용) [본류+루프 층] W 넘는 필드 모양 뒤 던전 안 → own 닫기 · 결론 · 복귀 호출 · exit · 복귀 중 던전 안 정지 줄 · 끊긴 판 항목 · GUI 끝 처리 · 다음 기동 종류 → 셋째 Role · 정리 전용 · 생성 · 새 항목 · 이 기동 키 · 그 판 합계' `
        (J @($second.OwnCloseCalls, $second.StartScreen, $second.ReturnCalls, $second.ExitCode, (Get-LineCount -Lines $second.Logs -Prefix $LOOP_INSIDE_STOP_PREFIX),
                (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), $exitJournal.Ok, $nextLaunch.Kind, $third.Role, $third.CleanupOnly, $third.EnteredTags,
                (Format-DiskEntry $third.CreatedEntry), (Format-KeyCounts -Keys $third.PressList), (Get-RowKeyTotals))) `
        (J @('field', 'field', '10|(인자 없음)', '4', 1, 'entered/done/2/2/[32,66]/False/abandoned-pre-entry-start/field', 'True', 'none', 'none', 'True', 'changed',
                'entered/launched/0/2/[32,66]/True//', 'Space 1 · B 1', 'Space 2 · B 2'))
}

function Test-RowOK7 {
    # OK7 = 설계 R4 O14 키 변형(명세 3.3 · R4 6.2 · Q-R4-8 ② - 수용 고정): 혼자하기 수동 '다시 하기' 직후 로딩에서 시작한 모형 - 열린 own(옛 index 2)이 남은 채 알 수 없는
    #   화면(로딩) 40초 뒤 던전 안 → 선분기는 화면으로 새 판과 가를 수 없어 이어받기 → Space 0·B 0(새 판의 키가 빠짐 - 자동 출발은 게임의 스마트 마법 나침반·자동사냥
    #   꺼짐 감시가 잇는 길, 명세 5절 C16 ② · C17 '수용'). 알 수 없음 조정 30초에 이벤트 화면 정리 1회(안내 줄 1). 값이 바뀌면 수용 범위가 바뀐 것
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'loading' -WorkerClear 'halt' -KeepHandoffEnv -WorkerTimeline @(@{ At = 0; Screen = 'loading' }, @{ At = 40; Screen = 'inside' })
    Assert-Case 'OK7(O14 - 수용) [본류 층] 로딩 40초 뒤 던전 안 수동 시작 → 기동 종류 · Role · 결론 · 시작값 · 생성 · own 닫기 · 이벤트 정리 안내 줄 · 이 기동 키 · 클리어 대기 도달 · 행 합계' `
        (J @($launch.Kind, $second.Role, $second.StartScreen, $second.AfterEntryIndex, $second.EnteredCalls, $second.OwnCloseCalls,
                (Get-LineCount -Lines $second.Logs -Exact ($FORMAT_EVENT_CLEANUP -f $memberUnknownOverlaySeconds)), (Format-KeyCounts -Keys $second.PressList), $second.Halted, (Get-RowKeyTotals))) `
        (J @('own', 'own', 'inside', '2', 0, '', 1, 'Space 0 · B 0', 'True', 'Space 1 · B 1'))
}

function Test-RowOK8 {
    # OK8 (명세 3.3 · dev:993 · 사용자 결정 U2) - 열린 own(index 2)이 남은 채 선택 화면 / ESC 메뉴 / 던전 상세 화면에서 수동 시작 → 선분기 1회 정지(진단 1 · own 문구 S10·S12·S14 ·
    #   코드 4 · 조작·닫기·기록·새 항목·키 0) → GUI 끝 처리(재전달 표지 → 넘긴 nonce launched 유지) → 열린 항목 1 → 다음 기동(같은 own) 던전 안 → 이어받기 → Space 0·B 0.
    #   변이 '선택 화면을 field 와 합침' · 'ESC 메뉴를 그 외로 통과' · '상세를 unknown 으로'(U2 미반영) 면 정지 0 · 다음 판 B 2(명세 3.5)
    $overlayCases = @(
        @{ Kind = 'selection'; Line = $LINE_OVERLAY_SELECTION_OWN },
        @{ Kind = 'menu'; Line = $LINE_OVERLAY_MENU_OWN },
        @{ Kind = 'detail'; Line = $LINE_OVERLAY_DETAIL_OWN })
    $actual = foreach ($overlayCase in $overlayCases) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
        $launch = Invoke-GuiLaunch -LaunchRestart $false
        $second = Invoke-Worker -WorkerStart ([string]$overlayCase.Kind) -WorkerClear 'halt' -KeepHandoffEnv
        $entryAfterStop = Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)
        $exitJournal = Invoke-GuiExitJournal -ExitCode 4 -WorkerReason $second.LastDone -KeepLaunched
        $openAfterGui = Get-OpenEnteredText
        $relaunch = Invoke-GuiLaunch -LaunchRestart $false
        $third = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
        '{0}: {1}' -f $overlayCase.Kind, (J @($launch.Kind, $second.Role, $second.ExitCode, $second.LastDone, $second.OverlayStops, $second.DiagCalls, $second.Clicks, $second.MenuCloses,
                $second.OwnCloseCalls, $second.CloseCalls, $second.EnteredCalls, $second.Presses, $entryAfterStop, $exitJournal.Ok, $openAfterGui, $relaunch.Kind, $relaunch.NonceEnv,
                $third.Role, $third.StartScreen, (Format-KeyCounts -Keys $third.PressList), (Get-RowKeyTotals)))
    }
    $expected = foreach ($overlayCase in $overlayCases) {
        '{0}: {1}' -f $overlayCase.Kind, (J @('own', 'own', '4', $overlayCase.Line, $overlayCase.Kind, 1, 0, 0, '', '', 0, '', 'entered/launched/2/2/[32,66]/False//', 'True', 'W1', 'own', 'W1',
                'own', 'inside', 'Space 0 · B 0', 'Space 1 · B 1'))
    }
    Assert-Case 'OK8 [본류 층] own + 선택 화면 / ESC 메뉴 / 상세 화면 시작 → 기동 종류 · Role · exit · 마지막 [완료] · 정지 종류 · 진단 · 조작 · ESC · own 닫기 · 닫기 · 생성 · 누른 키 · 항목 · GUI 끝 처리 · 열린 항목 · 다음 기동 → 셋째 Role · 결론 · 키 · 판 합계' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowOK9 {
    # OK9 (명세 3.3 · dev:993 · 설계 R4 O9 · P16 · Q-R4-17 (가)) - 열린 own 이 남은 채 손으로 클리어 → 보상 화면(3버튼)에서 수동 시작 → 선분기 결론 '3버튼' → 본류 보상 분기:
    #   완료 마커 + own 의 cleared(같은 저장에서 own 항목 applied·done - J4) + exit 0 → 계상 1 → 다음 기동은 이어받을 항목 없음(Role none) → 새 판 키 1. 변이 'own 3버튼을
    #   exit 10'(계상 0) · 'own 시작 분기 cleared 제거'(R4-M23 - 항목 열림 → 다음 기동 own → 새 판 키 0) 가 여기서 드러남
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'reward' -WorkerClear 'halt' -KeepHandoffEnv
    $keyEntryText = Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)
    $appliedNow = ((Get-DiskAppliedText) -split ',') -contains $first.NonceLabel
    $clearedCount = Get-DiskStageCount -Stage 'cleared'
    $exitJournal = Invoke-GuiExitJournal -ExitCode 0 -WorkerReason $second.LastDone
    $nextLaunch = Invoke-GuiLaunch -LaunchRestart $false
    $third = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'OK9 [본류+루프 층] own + 3버튼 수동 시작 → 기동 종류 · Role · 결론 · 정리 전용 · 판 끝 · 마지막 [완료] · 복귀 호출 · 닫기 · 열쇠 항목 · applied · cleared 항목 수 · 이 기동 키 · GUI 끝 처리 · 다음 기동 → 셋째 Role · 생성 · 새 판 키' `
        (J @($launch.Kind, $second.Role, $second.StartScreen, $second.CleanupOnly, (Get-RunEndText $second), $second.LastDone, $second.ReturnCalls, $second.CloseCalls, $keyEntryText,
                $appliedNow, $clearedCount, (Format-KeyCounts -Keys $second.PressList), $exitJournal.Ok, $nextLaunch.Kind, $nextLaunch.NonceEnv, $third.Role, $third.EnteredTags,
                (Format-KeyCounts -Keys $third.PressList))) `
        (J @('own', 'own', 'reward3', 'False', 'exit 0 · 마커 True · cleared 1', $MAIN_RETURN_DONE_LINE, '0|', '', 'entered/done/2/2/[32,66]/False//', 'True', 1, 'Space 0 · B 0',
                'True', 'none', '(빈 값)', 'none', 'changed', 'Space 1 · B 1'))
}

function Test-RowOK10 {
    # OK10 (명세 3.3 · 설계 R4 1절 · N3 의 키 쪽) - 재입장 기록(reentered · 이 owner 가 nextOwner · keys 미기록)을 넘겨받은 next 가 필드에서 시작 → 선분기 필드 확정(next 는
    #   기록 0 - own 닫기 0) → 결론 '필드' → 본류 필드 분기 → exit 10 → GUI 코드 10 끝 처리가 넘긴 nonce 를 done → 다음 기동 Role none → 새 자기 항목 → 키 1회씩(next 항목의
    #   index 는 쓰지 않음 - 진리표). next 는 ② 빌드에서 숨는 갈래(재입장 기록은 ⑤ 가 씀)라 그 기록은 픽스처입니다
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $nextEntry = New-FixtureEntry -Stage 'reentered' -Nonce $NONCE_A -Owner (ConvertTo-FiveFieldOwner (Get-RowCanonicalOwner -OwnerIndex 2)) `
        -NextOwner (ConvertTo-FiveFieldOwner (Get-RowCanonicalOwner -OwnerIndex 0)) -Generation $CONTEXT_GENERATION -Section $ABYSS_SECTION -RunId 'run-before' `
        -LaunchState 'pending' -AfterIndex 0 -AfterTotal $null -AfterKeys $null
    Write-FixtureJournal -Entries @($nextEntry)
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'field' -WorkerClear 'halt' -KeepHandoffEnv
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason $second.LastDone
    $nextAfterGui = Format-DiskEntry (Get-DiskEntry -Nonce $NONCE_A)
    $nextLaunch = Invoke-GuiLaunch -LaunchRestart $false
    $third = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'OK10 [본류+루프 층] next + 필드 시작 → 기동 종류·nonce env · Role · 결론 · own 닫기 · 필드 확정 줄 · exit · 이 기동 키 · GUI 코드 10 끝 처리 · 재입장 항목 · 다음 기동 → 셋째 Role · 생성 · 새 항목 · 새 판 키' `
        (J @($launch.Kind, $launch.NonceEnv, $second.Role, $second.StartScreen, $second.OwnCloseCalls, (Get-LineCount -Lines $second.Logs -Prefix ($FORMAT_FIELD_SETTLED_PREFIX -f $memberFieldSettleSeconds)),
                $second.ExitCode, (Format-KeyCounts -Keys $second.PressList), $exitJournal.Ok, $nextAfterGui, $nextLaunch.Kind, $third.Role, $third.EnteredTags, (Format-DiskEntry $third.CreatedEntry),
                (Format-KeyCounts -Keys $third.PressList))) `
        (J @('next', 'NA', 'next', 'field', '', 1, '10', 'Space 0 · B 0', 'True', 'reentered/done/0/null/null/False//', 'none', 'none', 'changed', 'entered/launched/0/2/[32,66]/False//',
                'Space 1 · B 1'))
}

function Test-RowOK11 {
    # OK11 (명세 3.3 · J22 · 5절 A-2 R-6 (나) · 갈래 B A4) - own 이 이어받은 판(index 2)이 클리어 전 표지 없는 코드 4(클리어 대기 불명 마감 - 워커 원문 문구 그대로 낸 모형)로
    #   멈춤 → GUI 끝 처리 = ⑯ (GUI 틱) KP1 이 단언하는 결과(넘긴 nonce launched 유지 - 같은 journal 모양으로) → 같은 던전 안 수동 시작(S3 none · 실제 Consume-Handoff) →
    #   Role own · 같은 nonce · 시작값 2 → Space 0·B 0(각 키 ≤ 1 - 그 판 B 합계 1) → 완주 → 계상 1. GUI 쪽 판정(own 의 클리어 전 정지면 열어 둠)은 단계 2.7 의 ⑯ KP1 몫
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'unknown-deadline' -KeepHandoffEnv
    $exitJournal = Invoke-GuiExitJournal -ExitCode 4 -WorkerReason $second.LastDone -KeepLaunched
    $entryAfterGui = Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)
    $gate = Invoke-GuiStartGate
    $relaunch = Invoke-GuiLaunch -LaunchRestart $false
    $third = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'clear' -KeepHandoffEnv
    Assert-Case 'OK11 [본류+루프 층] own 이어받은 판의 표지 없는 클리어 전 코드 4 → Role · 이 기동 키 · exit · 마지막 [완료] · GUI 끝 처리(launched 유지) · 항목 → S3 · 다음 기동 → 셋째 Role · 같은 nonce · 시작값 · 키 · 판 끝 · 항목 · 판 합계' `
        (J @($second.Role, (Format-KeyCounts -Keys $second.PressList), $second.ExitCode, $second.LastDone, $exitJournal.Ok, $entryAfterGui, $gate, $relaunch.Kind, $relaunch.NonceEnv,
                $third.Role, $third.NonceLabel, $third.AfterEntryIndex, (Format-KeyCounts -Keys $third.PressList), (Get-RunEndText $third), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)),
                (Get-RowKeyTotals))) `
        (J @('own', 'Space 0 · B 0', '4', $CLEAR_WAIT_UNKNOWN_LINE, 'True', 'entered/launched/2/2/[32,66]/False//', 'none/(빈 값)', 'own', 'W1', 'own', 'W1', '2', 'Space 0 · B 0',
                '0(끝까지) · 마커 True · cleared 1', 'entered/done/2/2/[32,66]/False//', 'Space 1 · B 1'))
}

function Test-RowOK12 {
    # OK12 (명세 3.3 · J22 · 갈래 D D6) - 생성 직후(첫 키 기록 전) 끊긴 판(열쇠 index 0)을 own 이 이어받아 Space 기록·전송 → B 의 인덱스 기록 locked → [완료] 입장 직후 키 입력
    #   기록 실패 … (1/2, 캐릭터는 던전 안) 코드 4(표지 없음) → GUI 끝 처리 = ⑯ KP2 의 결과(launched 유지) → 다음 수동 시작(실제 Consume-Handoff) → Role own · 같은 nonce ·
    #   시작값 1 → Space 0 · B 1 → 판당 Space 1·B 1(각 키 ≤ 1)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -Configure {
        $script:spyPre['Set-AbyssAfterEntryIndex'] = { param($Bound) if ([int]$Bound['Index'] -eq 0) { throw 'CRASH-BEFORE-FIRST-KEY' } }
    }
    $entryAfterFirst = Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv -Configure {
        $script:spyPre['Set-AbyssAfterEntryIndex'] = { param($Bound) if ([int]$Bound['Index'] -eq 1) { Lock-Journal } }
        $script:spyPost['Set-AbyssAfterEntryIndex'] = { param($Bound, $Output) Close-HeldStreams }
    }
    Close-HeldStreams
    $entryAfterStop = Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)
    $exitJournal = Invoke-GuiExitJournal -ExitCode 4 -WorkerReason $second.LastDone -KeepLaunched
    $relaunch = Invoke-GuiLaunch -LaunchRestart $false
    $third = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
    Assert-Case 'OK12 [본류 층] 생성 직후 끊긴 판 → 첫 기동 끊김 · 키 · 항목 → own 이어받기 → Role · 시작값 · 키 · 키 결과 · exit · 마지막 [완료] · 항목 · GUI 끝 처리 → 다음 기동 → 셋째 Role · 같은 nonce · 시작값 · 키 · 이미 보낸 키 줄 · 판 합계' `
        (J @($first.Thrown, $first.Presses, $entryAfterFirst, $launch.Kind, $second.Role, $second.AfterEntryIndex, $second.Presses, $second.KeyOutcomes, $second.ExitCode, $second.LastDone,
                $entryAfterStop, $exitJournal.Ok, $relaunch.Kind, $relaunch.NonceEnv, $third.Role, $third.NonceLabel, $third.AfterEntryIndex, $third.Presses,
                (Get-LineCount -Lines $third.Logs -Exact (Get-KeyLine -Format $FORMAT_KEY_ALREADY_SENT -Prefix '[어비스]' -Key 32)), (Get-RowKeyTotals))) `
        (J @('CRASH-BEFORE-FIRST-KEY', '', 'entered/launched/0/2/[32,66]/False//', 'own', 'own', '0', '32', 'stop(1)', '4', ($FORMAT_KEY_RECORD_FAILED -f 1, 2),
                'entered/launched/1/2/[32,66]/False//', 'True', 'own', 'W1', 'own', 'W1', '1', '66', 1, 'Space 1 · B 1'))
}

function Test-RowOK13 {
    # OK13 (명세 3.3 · J22 · 5절 A-2 R-6 (나) · 명세 리뷰 2 P1-2 · gui:11165~11166·11208) - own 이 이어받은 판(index 2)의 클리어 대기가 세 번 예외로 끝남(코드 1 흉내 -
    #   클리어 대기 모의 'error' 의 예외가 본류 조각 밖으로 전파. 최상위 catch 를 지나는 코드 1 · 오류 세트는 결합 층 몫 - 명세 3.3 예외 행의 층 규칙). 그 판은 마커·
    #   클리어 기록이 없어(아래 칸이 확인) GUI 원문 Get-CustomErrorAction 이 재시도 2회(같은 항목 RESTART=1 - 끝 처리 없이 곧바로 기동, gui:11185~11202 → Resolve 가
    #   같은 own 을 다시 고름) 뒤 3회째 정지를 정함 → GUI 끝 처리 = ⑯ (GUI 틱) KP3 이 단언하는 결과(넘긴 nonce launched 유지 · 저장 0 - 같은 journal 모양으로) → 같은
    #   던전 안 수동 시작(S3 none · RESTART 없음 · 실제 Consume-Handoff) → 워커 네 번(오류 셋 + 수동 하나) 모두 Role own · 같은 nonce · 시작값 2 · Space 0·B 0(각 키 ≤ 1 -
    #   그 판 B 합계 1). GUI 쪽 판정(own 기동의 클리어 전 정지면 열어 둠 - Test-AbyssKeepLaunchOnStop)은 ⑯ KP3 몫이고, 변이 ⓓ(gui:11208 을 옛 모양으로)는 KP3 · ⑯ S21
    #   이 잡습니다(명세 3.5). 이 행은 그 결과 위에서 워커 쪽 사슬(이어받기 · 키 재전송 0)이 넷 다 서는지를 봅니다
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $errorRunTexts = @()
    $errorRunPresses = @()
    $errorActions = @()
    $restartLaunches = @()
    $workerRestart = $false
    $errorStreak = 0
    for ($errorAttempt = 1; $errorAttempt -le 3; $errorAttempt++) {
        $errorRun = Invoke-Worker -WorkerRestart $workerRestart -WorkerStart 'inside' -WorkerClear 'error' -KeepHandoffEnv
        # 이 기동 워커가 읽은 RESTART(커스텀 env 읽기 원문의 결과) - 다음 GUI 기동이 같은 변수를 덮기 전에 읽습니다
        $restartSeen = [string][bool]$script:customRestart
        $errorRunPresses += @($errorRun.PressList)
        $errorRunTexts += (J @($errorRun.Role, $errorRun.NonceLabel, $errorRun.AfterEntryIndex, (Format-KeyCounts -Keys $errorRun.PressList), $errorRun.Thrown, $errorRun.ExitCode,
                $errorRun.MarkerExists, $errorRun.ClearedCalls, $restartSeen))
        # GUI 오류 대응 - 마커 있음 판정(gui:11165~11166 = 복구 대기 · 유효 마커 · 'legacy-cleared')은 거짓: 이 행에는 복구 대기가 없고 위 칸이 마커 0 · cleared 0 을
        # 단언합니다(코드 1 라우팅은 클리어 기록이 없어 'legacy')
        $errorAction = [string](Get-CustomErrorAction -MarkerExists $false -ErrorStreak $errorStreak)
        $errorActions += $errorAction
        if ($errorAction -ne 'retry') { break }
        $errorStreak++
        $workerRestart = $true
        $restartLaunch = Invoke-GuiLaunch -LaunchRestart $true
        $restartLaunches += ('{0}/{1}' -f $restartLaunch.Kind, $restartLaunch.NonceEnv)
    }
    $exitJournal = Invoke-GuiExitJournal -ExitCode 1 -KeepLaunched
    $entryAfterGui = Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)
    $gate = Invoke-GuiStartGate
    $relaunch = Invoke-GuiLaunch -LaunchRestart $false
    $manual = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'halt' -KeepHandoffEnv
    $errorRunWant = @(
        (J @('own', 'W1', '2', 'Space 0 · B 0', 'ERROR-CLEAR-WAIT', '', 'False', 0, 'False')),
        (J @('own', 'W1', '2', 'Space 0 · B 0', 'ERROR-CLEAR-WAIT', '', 'False', 0, 'True')),
        (J @('own', 'W1', '2', 'Space 0 · B 0', 'ERROR-CLEAR-WAIT', '', 'False', 0, 'True')))
    Assert-Case 'OK13 [본류 층] own 이어받은 판의 클리어 대기 예외 × 3 → 첫 판 끊김 · 키 · 기동 종류·nonce env → 오류 기동 셋(Role · 같은 nonce · 시작값 · 이 기동 키 · 예외 · exit · 마커 · cleared · RESTART) · GUI 오류 대응 · 재시작 기동 · GUI 끝 처리(launched 유지) · 항목 → S3 · 수동 기동 → 넷째 Role · 같은 nonce · 시작값 · 키 · 클리어 대기 도달 · 그 판 키 · 행 합계' `
        (J @($first.Thrown, (Format-KeyCounts -Keys $first.PressList), $launch.Kind, $launch.NonceEnv, (@($errorRunTexts) -join ' ;; '), (@($errorActions) -join ','),
                (@($restartLaunches) -join ','), $exitJournal.Ok, $entryAfterGui, $gate, $relaunch.Kind, $relaunch.NonceEnv, $manual.Role, $manual.NonceLabel,
                $manual.AfterEntryIndex, (Format-KeyCounts -Keys $manual.PressList), $manual.Halted,
                (Format-RunKeys -Label 'W1' -Keys @(@($first.PressList) + @($errorRunPresses) + @($manual.PressList))), (Get-RowKeyTotals))) `
        (J @('CRASH-CLEAR-WAIT', 'Space 1 · B 1', 'own', 'W1', (@($errorRunWant) -join ' ;; '), 'retry,retry,stop', 'own/W1,own/W1', 'True',
                'entered/launched/2/2/[32,66]/False//', 'none/(빈 값)', 'own', 'W1', 'own', 'W1', '2', 'Space 0 · B 0', 'True', 'W1 판 Space 1 · B 1', 'Space 1 · B 1'))
}

# ===== 단계 2.5·2.6 - 정리 전용 표지를 받은 own · own 이어받기 뒤 닫기 (R2 C4~C8 · E3 · E4) =====
function Test-RowR2C4 {
    # R2-C4 · R2-C5 (설계 R2 5.2 · 3.3a · 명세 2.6 '$cleanupByScreen') - 정리 전용 판(Role none 수동 던전 안 시작 = 손으로 들어간 판)의 키 뒤 즉시 중지(Kill - GUI 종료 처리
    #   없음) → 자기 항목 cleanupOnly 참이 열린 채 → 그 던전 안 시작:
    #   C4 수동 → Role own · 표지 참 → 정리 전용 참(Role none 과 같은 인자) → 키 인덱스 이어받음(Space 0·B 0 - 판 B 합계 1) → 마커 0 · cleared 0 → 본류 끝 'cleanup-only'
    #      닫기 → exit 10(계상 0). v10 그대로(표지 무시)면 own ① → 마커·계상 1(이 케이스가 막는 것)
    #   C5 RESTART(코드 1 뒤 자동) → 정리 전용 거짓(Restart=1 - HEAD 의 '오류 후 자동 재시작은 계상') → 마커 · cleared(열쇠 항목 applied·done) → 계상 1 · 키 재전송 0 · 닫기 0.
    #   변이 'own 의 정리 전용 판정에서 표지 무시' · '표지 항목을 받은 own 이 키 인덱스를 0 부터' · '표지가 있어도 RESTART 를 정리 전용으로' · R4-M27(본류 키 지점 클로저
    #   안에서 $script:customCleanupOnly - 표지가 거짓으로 남음) 이 여기서 드러남
    $restartCases = @($false, $true)
    $actual = foreach ($restartCase in $restartCases) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        $first = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'crash'
        $launch = Invoke-GuiLaunch -LaunchRestart $restartCase
        $second = Invoke-Worker -WorkerRestart $restartCase -WorkerStart 'inside' -WorkerClear 'clear' -KeepHandoffEnv
        $label = $(if ($restartCase) { 'C5 RESTART' } else { 'C4 수동' })
        '{0}: {1}' -f $label, (J @($first.Role, $first.CleanupOnly, (Format-DiskEntry $first.CreatedEntry), $first.Presses, $launch.Kind, $second.Role, $second.NonceLabel,
                $second.HandoffCleanupOnly, $second.StartScreen, $second.CleanupOnly, $second.EnteredCalls, $second.Presses, (Get-RunEndText $second), $second.ReturnCalls,
                $second.CloseCalls, $second.CloseUpdateTags, (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), (((Get-DiskAppliedText) -split ',') -contains $first.NonceLabel),
                (Get-RowKeyTotals)))
    }
    $expected = foreach ($restartCase in $restartCases) {
        $label = $(if ($restartCase) { 'C5 RESTART' } else { 'C4 수동' })
        if ($restartCase) {
            $tail = @('False', 0, '', '0(끝까지) · 마커 True · cleared 1', '0|', '', '', 'entered/done/2/2/[32,66]/True//', 'True', 'Space 1 · B 1')
        } else {
            $tail = @('True', 0, '', 'exit 10 · 마커 False · cleared 0', '10|cleanup-only', 'cleanup-only|selection-proven', 'changed',
                'entered/done/2/2/[32,66]/True/cleanup-only/selection-proven', 'False', 'Space 1 · B 1')
        }
        '{0}: {1}' -f $label, (J @(@('none', 'True', 'entered/launched/0/2/[32,66]/True//', '32,66', 'own', 'own', 'W1', 'True', 'inside') + $tail))
    }
    Assert-Case 'R2-C4 · C5 [본류+루프 층] 정리 전용 판 키 뒤 끊김 → 던전 안 수동 / RESTART → 첫 판 Role·정리 전용·항목·키 · 기동 종류 · Role · 열쇠 · 표지 · 결론 · 정리 전용 · 생성 0 · 이 기동 키 · 판 끝 · 복귀 호출 · 닫기 · 그 태그 · 항목 · applied · 판 합계' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowR2C6 {
    # R2-C6 (설계 R2 5.2 · 3.3a · 명세 2.6 own 시작 분기) - C4 의 표지 항목을 받은 own 이 보상 화면(나가기)·클리어 화면(S)에서 시작:
    #   수동 → 정리 전용 참 → 마커 0 · cleared 0 · 보상·S 시작 자리의 'cleanup-only' 닫기(selection-proven) → exit 10 · 계상 0 / RESTART → 정리 전용 거짓 → v10 own 그대로
    #   마커 · cleared(열쇠 항목 applied·done) · exit 0 · 계상 1. 변이 '보상·S 시작 호출부에 -LeaveEntryReason 누락'(항목 열림 → 다음 기동 own 반복) · 'own 시작 분기 cleared 에
    #   정리 전용 조건 없음'(수동인데 cleared 1) 이 여기서 드러남
    $startCases = @(
        @{ Start = 'reward'; Conclusion = 'reward3'; Restart = $false }, @{ Start = 'reward'; Conclusion = 'reward3'; Restart = $true },
        @{ Start = 'prompt'; Conclusion = 'prompt'; Restart = $false }, @{ Start = 'prompt'; Conclusion = 'prompt'; Restart = $true })
    $actual = foreach ($startCase in $startCases) {
        Initialize-Row -Custom $true
        Set-AfterEntryConfig
        $first = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'crash'
        $launch = Invoke-GuiLaunch -LaunchRestart ([bool]$startCase.Restart)
        $second = Invoke-Worker -WorkerRestart ([bool]$startCase.Restart) -WorkerStart ([string]$startCase.Start) -WorkerClear 'halt' -KeepHandoffEnv
        $label = '{0} {1}' -f $startCase.Start, $(if ($startCase.Restart) { 'RESTART' } else { '수동' })
        '{0}: {1}' -f $label, (J @($launch.Kind, $second.Role, $second.HandoffCleanupOnly, $second.StartScreen, $second.CleanupOnly, $second.Presses, (Get-RunEndText $second),
                $second.ReturnCalls, $second.CloseCalls, (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), (((Get-DiskAppliedText) -split ',') -contains $first.NonceLabel)))
    }
    $expected = foreach ($startCase in $startCases) {
        $label = '{0} {1}' -f $startCase.Start, $(if ($startCase.Restart) { 'RESTART' } else { '수동' })
        if ($startCase.Restart) {
            $tail = @('False', '', 'exit 0 · 마커 True · cleared 1', '0|', '', 'entered/done/2/2/[32,66]/True//', 'True')
        } else {
            $tail = @('True', '', 'exit 10 · 마커 False · cleared 0', '10|cleanup-only', 'cleanup-only|selection-proven', 'entered/done/2/2/[32,66]/True/cleanup-only/selection-proven', 'False')
        }
        '{0}: {1}' -f $label, (J @(@('own', 'own', 'True', [string]$startCase.Conclusion) + $tail))
    }
    Assert-Case 'R2-C6 [본류+루프 층] 표지 항목 + 보상·S 시작(수동 / RESTART) → 기동 종류 · Role · 표지 · 결론 · 정리 전용 · 누른 키 · 판 끝 · 복귀 호출 · 닫기 · 항목 · applied' `
        (@($actual) -join ' || ') (@($expected) -join ' || ')
}

function Test-RowR2C8 {
    # R2-C8 (설계 R2 5.2 · 3.3a '필드가 없는 옛 항목 = $false') - cleanupOnly 필드가 없는 옛 own 항목(index 2)을 받은 own 던전 안 수동 시작 → 표지 거짓으로 읽음 → C7(= OK1)과
    #   같음: 정리 전용 거짓 · 키 이어받음(Space 0·B 0) · 마커 · cleared · 계상 1 · 예외 0 (필드는 끝까지 없는 채 - 생성 뒤 쓰지 않는 표지, 설계 R2 3.3a)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $oldEntry = New-RowOwnEntry -Nonce $NONCE_A -AfterIndex 2
    $oldEntry.PSObject.Properties.Remove('cleanupOnly')
    Write-FixtureJournal -Entries @($oldEntry)
    $entryBefore = Format-DiskEntry (Get-DiskEntry -Nonce $NONCE_A)
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'clear' -KeepHandoffEnv
    Assert-Case 'R2-C8 [본류+루프 층] cleanupOnly 없는 옛 own 항목 → 픽스처 항목 · 기동 종류·nonce env · Role · 표지 · 정리 전용 · 시작값 · 이 기동 키 · 판 끝 · 예외 · 항목 · applied' `
        (J @($entryBefore, $launch.Kind, $launch.NonceEnv, $second.Role, $second.HandoffCleanupOnly, $second.CleanupOnly, $second.AfterEntryIndex, $second.Presses, (Get-RunEndText $second),
                $second.Thrown, (Format-DiskEntry (Get-DiskEntry -Nonce $NONCE_A)), (((Get-DiskAppliedText) -split ',') -contains 'NA'))) `
        (J @('entered/launched/2/2/[32,66]/(없음)//', 'own', 'NA', 'own', 'False', 'False', '2', '', '0(끝까지) · 마커 True · cleared 1', '', 'entered/done/2/2/[32,66]/(없음)//', 'True'))
}

function Test-RowR2E3 {
    # R2-E3 (설계 R2 5.2 E3 · 3.7) - own 던전 안 이어받기 → 'left'(거점 퇴장) → 복귀 루프 출처 완료 블록의 닫기가 이번 기동이 받은 nonce 항목(열쇠 = 받은 own nonce)을 done ·
    #   reason · screen 으로 → exit 10 → GUI 사본 코드 10 끝 처리(이번 기동 nonce done - 이미 done 이면 아무것도 바꾸지 않음) 뒤에도 reason·screen 그대로 → 다음 기동 nonce 없음.
    #   변이 'GUI 이번 기동 nonce done 이 reason 을 덮음' · '닫기를 left 판정 직후로' 가 여기서 드러남
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'inside' -WorkerClear 'left' -KeepHandoffEnv
    $entryAfterWorker = Get-EntryJson (Get-DiskEntry -Nonce $first.NonceRaw)
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason $second.LastDone
    $entryAfterGui = Get-EntryJson (Get-DiskEntry -Nonce $first.NonceRaw)
    $nextLaunch = Invoke-GuiLaunch -LaunchRestart $false
    Assert-Case "R2-E3 [본류+루프 층] own 던전 안 이어받기 → 'left' → Role · 열쇠 · 이 기동 키 · exit · 마지막 [완료] · 복귀 호출 · 닫기 · 그 태그 · 닫기 성공 줄 · 항목 · GUI 코드 10 끝 처리 · 항목 필드 불변 · 다음 기동" `
        (J @($second.Role, $second.NonceLabel, $second.Presses, $second.ExitCode, $second.LastDone, $second.ReturnCalls, $second.CloseCalls, $second.CloseUpdateTags,
                (Get-LineCount -Lines $second.Logs -Exact ($FORMAT_CLOSE_DONE -f 'abandoned-death-exit')), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), $exitJournal.Ok,
                [string]($entryAfterGui -ceq $entryAfterWorker), $nextLaunch.Kind, $nextLaunch.NonceEnv)) `
        (J @('own', 'W1', '', '10', $LEFT_DONE_LINE, '10|abandoned-death-exit', 'abandoned-death-exit|selection-proven', 'changed', 1,
                'entered/done/2/2/[32,66]/False/abandoned-death-exit/selection-proven', 'True', 'True', 'none', '(빈 값)'))
}

function Test-RowR2E4 {
    # R2-E4 (설계 R2 5.2 E4 · R4 O4) - ownFreshEntry → 'left': 준비 패널에서 시작한 own 이 옛 항목을 선분기에서 닫고(ready) B2 입장 뒤 새 자기 항목을 열쇠로 → Space·B →
    #   거점 퇴장 → 복귀 루프 닫기 대상 = 새 항목(done · abandoned-death-exit · selection-proven - 옛 항목은 선분기에서 이미 done) → exit 10 → GUI 코드 10 끝 처리 → 다음 기동
    #   nonce 없음. 변이 '자기 항목 생성 뒤 Nonce 갱신 안 함'(닫기 대상이 옛 항목 → 새 항목 열림 → 다음 기동 own) 이 여기서 드러남
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'crash'
    $launch = Invoke-GuiLaunch -LaunchRestart $false
    $second = Invoke-Worker -WorkerStart 'ready' -WorkerClear 'left' -KeepHandoffEnv -WorkerTimeline $PANEL_TIMELINE
    $exitJournal = Invoke-GuiExitJournal -ExitCode 10 -WorkerReason $second.LastDone
    $nextLaunch = Invoke-GuiLaunch -LaunchRestart $false
    Assert-Case "R2-E4 [본류+루프 층] ownFreshEntry → 'left' → own 닫기 · (ownFreshEntry) 줄 · 새 열쇠 · exit · 닫기 · 그 태그 · 옛 항목 · 새 항목 · GUI 끝 처리 · 다음 기동 · 판별 키" `
        (J @($second.OwnCloseCalls, (Get-LineCount -Lines $second.Logs -Exact $LINE_OWN_FRESH_ENTRY), $second.NonceLabel, $second.ExitCode, $second.CloseCalls, $second.CloseUpdateTags,
                (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)), (Format-DiskEntry (Get-DiskEntry -Nonce $second.NonceRaw)), $exitJournal.Ok, $nextLaunch.Kind, $nextLaunch.NonceEnv,
                (Format-RunKeys -Label 'W1' -Keys $first.PressList), (Format-RunKeys -Label 'W2' -Keys $second.PressList))) `
        (J @('ready', 1, 'W2', '10', 'abandoned-death-exit|selection-proven', 'changed', 'entered/done/2/2/[32,66]/False/abandoned-pre-entry-start/ready',
                'entered/done/2/2/[32,66]/False/abandoned-death-exit/selection-proven', 'True', 'none', '(빈 값)', 'W1 판 Space 1 · B 1', 'W2 판 Space 1 · B 1'))
}

# ===== TC 결합 층 =====
function Get-CombinedSummary {
    # 결합 층 행 공통 값 - exit 기록 · [오류] 줄(주입 메시지 그대로) · 사본 저장 줄 · error_*.log 수 · 그 사본에 [오류] 줄 · [경고] · [완료] 줄 수
    param($Run, [string]$Message)
    $errorFiles = @(Get-ErrorLogFiles)
    $copyHasError = $false
    if ($errorFiles.Count -eq 1) { $copyHasError = ([IO.File]::ReadAllText($errorFiles[0])).Contains($ERROR_LINE_PREFIX + $Message) }
    return (J @($Run.Exits, (Get-LineCount -Lines $Run.Logs -Exact ($ERROR_LINE_PREFIX + $Message)), (Get-LineCount -Lines $Run.Logs -Prefix $DIAG_COPY_PREFIX), $errorFiles.Count,
            $copyHasError, (Get-LineCount -Lines $Run.Logs -Prefix '[경고]'), (Get-LineCount -Lines $Run.Logs -Prefix '[완료]')))
}

function Test-RowTC {
    # TC0~TC3 - 본류 조각(시작 구간 A + 조각 B) + 실제 최상위 catch 본문(명세 3.3 결합 층). 기대 '코드 1 · 오류 세트' = exit 기록 1 · [오류] <메시지> 1 · 사본 저장 줄 1 ·
    #   error_*.log 1(그 [오류] 줄 포함) · [경고] 0 · [완료] 0
    $codeOneSet = J @('1', 1, 1, 1, 'True', 0, 0)
    # TC0 - 하니스 자기 검사: SE2 의 생성 locked(예외 아님) → exit 4 그대로(catch 미경유) · [완료] 입장 기록 실패 1 · [오류] 0 · error_*.log 0 (변이 '하니스 재던짐 문장 제거' 면 exit 1)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -WorkerCombined -Configure { Set-GenerationFailureHooks -Variant 'locked' }
    Close-HeldStreams
    Assert-Case 'TC0 [결합 층] 생성 locked(예외 아님) → exit 기록 · [완료] 입장 기록 실패 줄 · [오류] 줄 · error_*.log · 누른 키 · 행 밖 예외' `
        (J @($run.Exits, (Get-LineCount -Lines $run.Logs -Exact $LINE_ENTERED_FAILED), (Get-LineCount -Lines $run.Logs -Prefix $ERROR_LINE_PREFIX), @(Get-ErrorLogFiles).Count, $run.Presses, $run.Thrown)) `
        (J @('4', 1, 0, 0, '', ''))
    # TC1 = SE3 의 주입(생성 mutator 예외) - 코드 1 · 오류 세트 · 키 0 · journal 무변경 (변이 'catch 본문 exit 1 → exit 4' · '생성 함수가 예외를 잡아 태그로' 면 exit 4)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    Write-FixtureJournal -Entries @((New-RowOwnEntry -Nonce $NONCE_B -OwnerIndex 1))
    $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -WorkerCombined -Configure { Set-OwnerMatchThrowHook }
    Assert-Case 'TC1 [결합 층] 생성 mutator 예외 → exit 기록 · [오류] 주입 메시지 · 사본 저장 줄 · error_*.log · 사본의 [오류] 줄 · [경고] · [완료] / 누른 키 · journal 무변경 · 행 밖 예외' `
        (J @((Get-CombinedSummary -Run $run -Message $INJECTED_OWNER_MATCH), $run.Presses, [string]((Get-FolderState -Folder $script:journalFolder) -ceq $script:stateAtGeneration), $run.Thrown)) `
        (J @($codeOneSet, '', 'True', ''))
    # TC2 = R2-E7 의 주입('left' → 실제 복귀 루프 → 출처 완료 블록의 닫기 mutator 예외) - TC1 과 같은 단언 + exit 10 0 · 닫기 [경고] 0 · '[완료] … 던전을 나왔습니다' 0 ·
    #   열쇠 항목 launched 그대로 (루프를 잇는 행이라 가상 시계가 catch 의 Get-Date -Format 을 받음)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left' -WorkerCombined -Configure {
        $script:spyPre['Close-AbyssKeyEntryOnLeave'] = { param($Bound)
            $script:throwHook = @{ Name = 'Set-AbyssJournalProperty'; Match = { param($HookBound) @('launchState', 'reason', 'screen') -contains [string]$HookBound['Name'] }; Message = $INJECTED_PROPERTY }
        }
    }
    Assert-Case "TC2 [결합 층] left → 복귀 루프 → 닫기 mutator 예외 → 코드 1 · 오류 세트 / 닫기 호출 · 닫기 줄 0 · '던전을 나왔습니다' 줄 0 · 열쇠 항목 · 판 합계 · 행 밖 예외" `
        (J @((Get-CombinedSummary -Run $run -Message $INJECTED_PROPERTY), $run.CloseCalls, (Get-LineCount -Lines $run.Logs -Fragment $CLOSE_LINE_FRAGMENT),
                (Get-LineCount -Lines $run.Logs -Fragment $LEFT_LINE_FRAGMENT), (Format-DiskEntry (Get-DiskEntry -Nonce $run.NonceRaw)), (Get-RowKeyTotals), $run.Thrown)) `
        (J @($codeOneSet, 'abandoned-death-exit|selection-proven', 0, 0, 'entered/launched/2/2/[32,66]/False//', 'Space 1 · B 1', ''))
    # TC3 = AE9 의 주입(키 0 의 인덱스 기록 저장 예외) - Space 0·B 0 · 디스크 index 0 · 코드 1 · 오류 세트 (변이 '인덱스 기록 함수가 예외를 잡아 stop 으로' 면 exit 4)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    $run = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -WorkerCombined -Configure {
        $script:spyPre['Set-AbyssAfterEntryIndex'] = { param($Bound)
            if ([int]$Bound['Index'] -eq 0) { $script:throwHook = @{ Name = 'ConvertTo-AbyssJournalText'; Match = { param($HookBound) $true }; Message = $INJECTED_SERIALIZE } }
        }
    }
    Assert-Case 'TC3 [결합 층] 키 0 인덱스 기록 저장 예외 → 코드 1 · 오류 세트 / 판 합계 · 디스크 index · 행 밖 예외' `
        (J @((Get-CombinedSummary -Run $run -Message $INJECTED_SERIALIZE), (Get-RowKeyTotals), (Get-DiskIndexText -Nonce $run.NonceRaw), $run.Thrown)) `
        (J @($codeOneSet, 'Space 0 · B 0', '0', ''))
}

# ===== 정적 (주석 뺀 사본 · AST) =====
function Test-InChangedBranch {
    # 노드가 'changed' 를 조건으로 보는 if 갈래(또는 switch 의 'changed' 절) 안인가 - S3
    param($Node)
    for ($parent = $Node.Parent; $null -ne $parent; $parent = $parent.Parent) {
        if ($parent -is [IfStatementAst]) {
            foreach ($clause in $parent.Clauses) {
                if ((Test-AstWithin -Node $Node -Ancestor $clause.Item2) -and $clause.Item1.Extent.Text.Contains("'changed'")) { return $true }
            }
        }
        if ($parent -is [SwitchStatementAst]) {
            foreach ($clause in $parent.Clauses) {
                if ((Test-AstWithin -Node $Node -Ancestor $clause.Item2) -and $clause.Item1.Extent.Text.Contains('changed')) { return $true }
            }
        }
    }
    return $false
}

function Test-StaticRows {
    $loopAst = $workerTopFunctions['Return-ToAbyssSelection']
    $closeAst = $workerTopFunctions['Close-AbyssKeyEntryOnLeave']
    # S1 - 닫기 호출 = 워커 전체 2 · 둘 다 복귀 루프 안 · 출처 완료 블록 첫 문장(selection-proven) · W 뒤 안전 중지 블록 첫 문장(field) · 매개변수 [string]$LeaveEntryReason = ''.
    #   구현 단위 복귀 연장: while 뒤 마감 만료 출구도 같은 조건식의 if 입니다 - 그 자리는 화면을 몰라 닫기가 없으므로(R2-F3 · test_abyss_screen_signatures 3c) W 뒤 블록은 최상위 while 안에서만 찾습니다
    $closeCallNodes = @(Get-CommandAsts -Root $workerAst -Name 'Close-AbyssKeyEntryOnLeave')
    $closeInLoop = @($closeCallNodes | Where-Object { Test-AstWithin -Node $_ -Ancestor $loopAst })
    $selectionFirst = '(복귀 루프 없음)'
    $fieldFirst = '(복귀 루프 없음)'
    $leaveParam = '(복귀 루프 없음)'
    if ($null -ne $loopAst) {
        $selectionIfs = @($loopAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq '$selectionConfirmed') -and
                    (@(Get-CommandAsts -Root $node.Clauses[0].Item2 -Name 'Test-Path').Count -gt 0) }, $true))
        $selectionFirst = $(if ($selectionIfs.Count -eq 1) { Get-NormalizedCode -Node @($selectionIfs[0].Clauses[0].Item2.Statements)[0] } else { '(완료 블록 {0}개)' -f $selectionIfs.Count })
        $loopWhile = @($loopAst.Body.EndBlock.Statements | Where-Object { ($_ -is [WhileStatementAst]) -and ($_.Condition.Extent.Text -eq '$true') }) | Select-Object -First 1
        $fieldStopIfs = @($loopAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and ((Get-NormalizedCode -Node $node.Clauses[0].Item1) -eq 'Test-Path -LiteralPath $safeStopFlagPath') }, $true) |
                Where-Object { ($selectionIfs.Count -eq 1) -and -not (Test-AstWithin -Node $_ -Ancestor $selectionIfs[0]) -and (Test-AstWithin -Node $_ -Ancestor $loopWhile) })
        $fieldFirst = $(if ($fieldStopIfs.Count -eq 1) { Get-NormalizedCode -Node @($fieldStopIfs[0].Clauses[0].Item2.Statements)[0] } else { '(W 뒤 안전 중지 블록 {0}개)' -f $fieldStopIfs.Count })
        $leaveParams = @($loopAst.Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'LeaveEntryReason' })
        $leaveParam = $(if ($leaveParams.Count -eq 1) { '{0} = {1}' -f $leaveParams[0].StaticType.Name, [string]$leaveParams[0].DefaultValue.Extent.Text } else { '(매개변수 {0}개)' -f $leaveParams.Count })
    }
    Assert-Case 'R2-S1 닫기 호출 수(워커 전체 · 복귀 루프 안) · 출처 완료 블록 첫 문장 · W 뒤 안전 중지 블록 첫 문장 · 복귀 루프 매개변수' `
        (J @($closeCallNodes.Count, $closeInLoop.Count, $selectionFirst, $fieldFirst, $leaveParam)) `
        (J @(2, 2, "if (`$LeaveEntryReason) { Close-AbyssKeyEntryOnLeave -Reason `$LeaveEntryReason -Screen 'selection-proven' }",
                "if (`$LeaveEntryReason) { Close-AbyssKeyEntryOnLeave -Reason `$LeaveEntryReason -Screen 'field' }", "String = ''"))
    # S2 - -LeaveEntryReason 을 넘기는 호출부 = 정확히 4 ('left' · 본류 끝 · 보상 시작 · S 시작) - 'left' 는 'abandoned-death-exit', 뒤 셋은 같은 정리 전용 식 / 넘기지 않는
    #   호출 3(ESC 메뉴 · 필드 시작 - 입장 전 · '다른 던전 가기' 끝 함수의 폴백 ② - 구현 명세 ⑤b3 3.4: 정상 판은 cleared 가 열쇠 항목을 이미 닫아 빈 값 ·
    #   기록 실패 판의 열린 항목은 ⑤b2 어-46 '수용')
    $returnCallNodes = @(Get-CommandAsts -Root $workerAst -Name 'Return-ToAbyssSelection')
    $withLeave = @($returnCallNodes | Where-Object { Test-CommandHasParameter -CommandAst $_ -ParameterName 'LeaveEntryReason' })
    $withoutLeave = @($returnCallNodes | Where-Object { -not (Test-CommandHasParameter -CommandAst $_ -ParameterName 'LeaveEntryReason') })
    $rewardIfs = @($mainStatements | Where-Object { ($_ -is [IfStatementAst]) -and ($_.Clauses[0].Item1.Extent.Text -eq '$startExitDetected') })
    $promptIfs = @($mainStatements | Where-Object { ($_ -is [IfStatementAst]) -and ($_.Clauses[0].Item1.Extent.Text -eq '$startClearDetected') })
    $placeTexts = foreach ($callNode in $withLeave) {
        $place = '(다른 자리)'
        if (($leftIfNodes.Count -eq 1) -and (Test-AstWithin -Node $callNode -Ancestor $leftIfNodes[0])) { $place = 'left' }
        elseif (@($segmentBStatements | Where-Object { [object]::ReferenceEquals($_, $callNode.Parent) }).Count -eq 1) { $place = '본류 끝' }
        elseif (($rewardIfs.Count -eq 1) -and (Test-AstWithin -Node $callNode -Ancestor $rewardIfs[0])) { $place = '보상 시작' }
        elseif (($promptIfs.Count -eq 1) -and (Test-AstWithin -Node $callNode -Ancestor $promptIfs[0])) { $place = 'S 시작' }
        '{0}={1}' -f $place, (Get-NormalizedCode -Node $callNode)
    }
    $cleanupCall = "Return-ToAbyssSelection -Game `$game -SafeStopExitCode `$(if (`$script:customMode -and `$script:customCleanupOnly) { 10 } else { 0 }) -LeaveEntryReason `$(if (`$script:customMode -and `$script:customCleanupOnly) { 'cleanup-only' } else { '' })"
    # 'left' 의 안전 중지 코드 = 마무리 실행이면 4 · 아니면 10(구현 명세 ⑤b5 W3 · 설계 v11 R2 M4)
    $expectedPlaces = @(
        ("left=Return-ToAbyssSelection -Game `$game -SafeStopExitCode `$(if (`$script:finishOnly) { 4 } else { 10 }) -LeaveEntryReason 'abandoned-death-exit'"),
        ('본류 끝=' + $cleanupCall), ('보상 시작=' + $cleanupCall), ('S 시작=' + $cleanupCall))
    Assert-Case 'R2-S2 -LeaveEntryReason 호출부(자리=원문 - 정렬) · 넘기지 않는 호출 원문' `
        (J @((@($placeTexts | Sort-Object) -join ' || '), (@($withoutLeave | ForEach-Object { Get-NormalizedCode -Node $_ } | Sort-Object) -join ' || '))) `
        (J @((@($expectedPlaces | Sort-Object) -join ' || '), ((@('Return-ToAbyssSelection -Game $game -SafeStopExitCode 10', 'Return-ToAbyssSelection -Game $game -SafeStopExitCode 10',
                    'Return-ToAbyssSelection -Game $Game -SafeStopExitCode $returnExitCode') | Sort-Object) -join ' || ')))
    # S3 - 닫기 함수 문자열에 [완료]·'선택 화면 복귀 확인' 0 · 성공 줄 문자열 1 · 그것이 'changed' 갈래 안
    $closeStrings = @()
    if ($null -ne $closeAst) { $closeStrings = @($closeAst.FindAll({ param($node) ($node -is [StringConstantExpressionAst]) -or ($node -is [ExpandableStringExpressionAst]) }, $true)) }
    $bannedCount = @($closeStrings | Where-Object { ([string]$_.Value).Contains('[완료]') -or ([string]$_.Value).Contains('선택 화면 복귀 확인') }).Count
    $successStrings = @($closeStrings | Where-Object { ([string]$_.Value).Contains($CLOSE_SUCCESS_FRAGMENT) })
    $successInChanged = ($successStrings.Count -eq 1) -and (Test-InChangedBranch -Node $successStrings[0])
    Assert-Case "R2-S3 닫기 함수 - [완료]·'선택 화면 복귀 확인' 문자열 · 성공 줄 문자열 수 · 그 줄이 'changed' 갈래 안" (J @($bannedCount, $successStrings.Count, $successInChanged)) (J @(0, 1, 'True'))
    # S4 - 닫기 함수 본문: exit·throw 0 · try·catch·trap 0 (예외는 감싸지 않음 - R2-5)
    $statementCounts = '(닫기 함수 없음)'
    if ($null -ne $closeAst) {
        $statementCounts = ('exit {0} · throw {1} · try {2} · trap {3}' -f @($closeAst.FindAll({ param($node) $node -is [ExitStatementAst] }, $true)).Count,
            @($closeAst.FindAll({ param($node) $node -is [ThrowStatementAst] }, $true)).Count, @($closeAst.FindAll({ param($node) $node -is [TryStatementAst] }, $true)).Count,
            @($closeAst.FindAll({ param($node) $node -is [TrapStatementAst] }, $true)).Count)
    }
    Assert-Case 'R2-S4 닫기 함수 본문 - exit · throw · try · trap' $statementCounts 'exit 0 · throw 0 · try 0 · trap 0'
    # S5 - 닫기 mutator(클로저)가 쓰는 필드 = launchState·reason·screen 셋뿐(Set-AbyssJournalProperty - J5) · 그 밖의 멤버 대입은 $change.Changed 뿐 · 안 $script: 0
    $mutatorText = '(닫기 함수 없음)'
    if ($null -ne $closeAst) {
        $closureNodes = @($closeAst.FindAll({ param($node) ($node -is [InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -eq 'GetNewClosure') -and ($node.Expression -is [ScriptBlockExpressionAst]) }, $true))
        if ($closureNodes.Count -eq 1) {
            $mutatorAst = $closureNodes[0].Expression
            $propertyNames = @(Get-CommandAsts -Root $mutatorAst -Name 'Set-AbyssJournalProperty' | ForEach-Object {
                    $nameArgument = Get-CommandArgumentAst -CommandAst $_ -ParameterName 'Name'
                    if ($null -eq $nameArgument) { '(이름 인자 없음)' } elseif ($nameArgument -is [StringConstantExpressionAst]) { $nameArgument.Value } else { '(식) ' + $nameArgument.Extent.Text } } | Sort-Object -Unique)
            $memberAssigns = @($mutatorAst.FindAll({ param($node) ($node -is [AssignmentStatementAst]) -and ($node.Left -is [MemberExpressionAst]) }, $true) | ForEach-Object { $_.Left.Extent.Text } | Sort-Object -Unique)
            $scriptRefs = @($mutatorAst.FindAll({ param($node) ($node -is [VariableExpressionAst]) -and $node.VariablePath.IsScript }, $true)).Count
            $mutatorText = ('필드 {0} · 멤버 대입 {1} · $script: {2}' -f ($propertyNames -join ','), ($memberAssigns -join ','), $scriptRefs)
        } else {
            $mutatorText = ('(클로저 {0}개)' -f $closureNodes.Count)
        }
    }
    Assert-Case 'R2-S5 닫기 mutator - Set-AbyssJournalProperty 필드 · 그 밖의 멤버 대입 · $script: 참조' $mutatorText '필드 launchState,reason,screen · 멤버 대입 $change.Changed · $script: 0'
    # S8 - 인덱스 계약 인자는 본류 키 지점 1곳(-KeyContract $script:handoff · 키 지점 블록 안) · 다른 호출부 4곳 원문 불변(HEAD run:11189·11687·12234·13417)
    $keyCallNodes = @(Get-CommandAsts -Root $workerAst -Name 'Invoke-AfterEntryKeys')
    $contractCalls = @($keyCallNodes | Where-Object { Test-CommandHasParameter -CommandAst $_ -ParameterName 'KeyContract' })
    $plainCalls = @($keyCallNodes | Where-Object { -not (Test-CommandHasParameter -CommandAst $_ -ParameterName 'KeyContract') })
    $contractText = '(계약 호출 {0}개)' -f $contractCalls.Count
    if ($contractCalls.Count -eq 1) {
        $contractArgument = Get-CommandArgumentAst -CommandAst $contractCalls[0] -ParameterName 'KeyContract'
        $prefixArgument = Get-CommandArgumentAst -CommandAst $contractCalls[0] -ParameterName 'LogPrefix'
        $contractText = ('-KeyContract {0} · -LogPrefix {1} · 키 지점 블록 안 {2}' -f $(if ($contractArgument) { $contractArgument.Extent.Text } else { '(없음)' }),
            $(if ($prefixArgument) { $prefixArgument.Extent.Text } else { '(없음)' }), (Test-AstWithin -Node $contractCalls[0] -Ancestor $keyPointStatement))
    }
    $headPlainCalls = @('Invoke-AfterEntryKeys -Game $Game -LogPrefix $script:contentTag', 'Invoke-AfterEntryKeys -Game $Game -LogPrefix $script:contentTag',
        "Invoke-AfterEntryKeys -Game `$Game -LogPrefix '[사냥터]'", "Invoke-AfterEntryKeys -Game `$Game -LogPrefix '[파티원]'")
    Assert-Case 'S8 인덱스 계약 호출(인자 · 키 지점 블록 안) · 계약 없는 호출 원문(HEAD 4곳 - 정렬)' `
        (J @($contractText, (@($plainCalls | ForEach-Object { Get-NormalizedCode -Node $_ } | Sort-Object) -join ' || '))) `
        (J @("-KeyContract `$script:handoff · -LogPrefix '[어비스]' · 키 지점 블록 안 True", (@($headPlainCalls | Sort-Object) -join ' || ')))
    # 본류 층 추출 - 시작 구간 A 첫 문장 = 2.1 블록 · run:18527 if 참 갈래 문장 1개(Write-RunLog)·else 있음 · 조각 B 첫 문장 = 키 지점(계약 호출 1)
    $insideShape = '(run:18527 if 없음)'
    if ($null -ne $insideIf) {
        $insideBody = @($insideIf.Clauses[0].Item2.Statements)
        $insideShape = ('참 갈래 문장 {0} · 그 문장 Write-RunLog {1} · else {2}' -f $insideBody.Count, (($insideBody.Count -eq 1) -and (@(Get-CommandAsts -Root $insideBody[0] -Name 'Write-RunLog').Count -eq 1)), ($null -ne $insideIf.ElseClause))
    }
    $segmentAFirst = $(if ($segmentAStatements.Count -gt 0) { @(Get-CommandAsts -Root $segmentAStatements[0] -Name 'Consume-Handoff').Count } else { -1 })
    $segmentBFirst = $(if ($null -ne $keyPointStatement) { @(Get-CommandAsts -Root $keyPointStatement -Name 'Invoke-AfterEntryKeys' | Where-Object { Test-CommandHasParameter -CommandAst $_ -ParameterName 'KeyContract' }).Count } else { -1 })
    Assert-Case '본류 층 추출 - 시작 구간 A 첫 문장의 Consume-Handoff · run:18527 if 모양(건너뛰는 이유) · 조각 B 첫 문장의 계약 호출' `
        (J @($segmentAFirst, $insideShape, $segmentBFirst)) (J @(1, '참 갈래 문장 1 · 그 문장 Write-RunLog True · else True', 1))
    # S10 - 결합 층 추출: 최상위 try 의 catch 절 1 · catch 본문 마지막 문장 원문 exit 1 · 결합 블록의 하니스 재던짐 문장 1(catch 첫 문장)
    $catchClauseCount = $(if ($null -ne $mainTry) { $mainTry.CatchClauses.Count } else { -1 })
    $catchLast = $(if ($catchStatements.Count -gt 0) { Get-NormalizedCode -Node $catchStatements[-1] } else { '(없음)' })
    $rethrowCount = -1
    $rethrowFirst = '(결합 블록 없음)'
    if ($null -ne $script:combinedBlock) {
        $combinedAst = $script:combinedBlock.Ast
        $rethrowCount = @($combinedAst.FindAll({ param($node) ($node -is [IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq $HARNESS_RETHROW_CONDITION) }, $true)).Count
        $outerTry = @($combinedAst.EndBlock.Statements)[0]
        if (($outerTry -is [TryStatementAst]) -and ($outerTry.CatchClauses.Count -eq 1)) { $rethrowFirst = [string](@($outerTry.CatchClauses[0].Body.Statements)[0].Extent.Text -ceq $HARNESS_RETHROW_TEXT) }
    }
    Assert-Case 'S10 결합 층 추출 - 최상위 try catch 절 · catch 본문 마지막 문장 원문 · 하니스 재던짐 문장 수 · 그 문장이 결합 catch 첫 문장' `
        (J @($catchClauseCount, $catchLast, $rethrowCount, $rethrowFirst)) (J @(1, 'exit 1', 1, 'True'))
}

# ===== ⑤b5 - 마무리 실행 'left' · 복구 워커 (구현 명세 ⑤b5 3.1 ⑳ · 설계 v11 R2 5.7 · M4 · R6 7.5 RC1) =====
function Test-RowR2LeftFinish {
    # R2-L5 · R2-L6 (구현 명세 ⑤b5 W3 · 설계 v11 R2 5.7 · M4) - 마무리 실행(finish-only) 워커의 'left' 는 같은 닫기 뒤 코드 4: 마무리 실행은 exit 10 을 내지 않고 다음 기동도
    #   없습니다. 명세 어-68 - R2 5.7 은 ⑰ 이라 적었지만 'left' 하니스(본류+루프 층 R2-L1 · E3)가 이 파일에 있어 여기서 봅니다
    # L5 [본류+루프 층] - FINISH_ONLY=1(env → 워커 원문 읽기 문장) + 'left' → 실제 복귀 루프(안전 중지 코드 4) → 출처 완료 → 닫기 1(abandoned-death-exit) → 마무리 [완료] · exit 4
    #   (변이: 'left' 의 마무리 실행 갈래 제거 → 준비 실행 줄 · exit 10 / 복귀 호출 안전 중지 코드를 10 고정 → 복귀 호출 10)
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    Set-ProcessEnv -Name 'HONEYNOGI_HANDOFF_NONCE' -Value ''
    Set-ProcessEnv -Name 'HONEYNOGI_RESUME_REENTRY' -Value ''
    Set-ProcessEnv -Name 'HONEYNOGI_FINISH_ONLY' -Value '1'
    try {
        $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'left' -KeepHandoffEnv
        $finishRead = [string][bool]$script:finishOnly
    } finally {
        Set-ProcessEnv -Name 'HONEYNOGI_FINISH_ONLY' -Value ''
        $script:finishOnly = $false
    }
    Assert-Case 'R2-L5 [본류+루프 층] 마무리 실행 + left → 워커의 finishOnly 읽기 · exit · 복귀 호출(안전 중지 코드|사유) · 닫기 호출(사유|화면) · 닫기 저장 태그 · 닫기 성공 줄 · 마지막 [완료] = 마무리 문구 · 준비 실행 줄 0 · 그 판의 자기 항목' `
        (J @($finishRead, $first.ExitCode, $first.ReturnCalls, $first.CloseCalls, $first.CloseUpdateTags, (Get-LineCount -Lines $first.Logs -Exact ($FORMAT_CLOSE_DONE -f 'abandoned-death-exit')),
                $first.LastDone, (Get-LineCount -Lines $first.Logs -Exact $LEFT_DONE_LINE), (Format-DiskEntry (Get-DiskEntry -Nonce $first.NonceRaw)))) `
        (J @('True', '4', '4|abandoned-death-exit', 'abandoned-death-exit|selection-proven', 'changed', 1, $LEFT_FINISH_DONE_LINE, 0,
                'entered/done/2/2/[32,66]/False/abandoned-death-exit/selection-proven'))
    # L6 [루프 층] - 같은 판(마무리 실행 'left' 의 원문 복귀 호출)이 던전 밖 확정으로 끝나는 두 출구에서 F9 → 닫기 1 → 플래그 소비 → exit 4 (설계 v11 R2 5.7 · 복귀 루프 안 안전 중지
    #   출구도 같은 코드 4): (가) W 확정 뒤(필드 출구 - field) (나) 출처 완료 시점('어비스' 클릭 순간 예약 - 선택 화면 출구 selection-proven, R2-F2 의 마무리 실행 짝).
    #   두 출구의 줄 = 거점 퇴장 문구(구현 명세 ⑤b5 명세 리뷰 2 RV-9 - 'abandoned-death-exit' 이고 코드 10 이 아닌 갈래: 클리어하지 않은 판이라 회차로 세지 않음 · GUI 계상 0) - 리뷰 문안을
    #   계약으로 고정하고 복귀 루프 원문의 그 갈래 문자열(소스 캡처 - 출구마다 1)과 같은지 함께 봅니다. 옛 '회차를 마칩니다' 줄 · 준비/정리 실행 줄은 0
    #   (변이: 그 갈래 제거 → 옛 '회차를 마칩니다' 줄 1 · 새 줄 0 / 두 출구 문구 바꿔치기 → 각 출구 새 줄 0).
    #   구현 단위 복귀 연장: 소스 갈래는 while 뒤 마감 만료 출구까지 셋입니다 (그 출구의 동작은 R2-F3)
    $leftStopLines = @()
    if ($workerTopFunctions.ContainsKey('Return-ToAbyssSelection')) {
        $leftStopIfs = @($workerTopFunctions['Return-ToAbyssSelection'].FindAll({ param($node) ($node -is [IfStatementAst]) -and ($node.Clauses.Count -eq 2) -and ($node.Clauses[0].Item1.Extent.Text -eq '$SafeStopExitCode -eq 10') -and
                    ($node.Clauses[1].Item1.Extent.Text -eq "`$LeaveEntryReason -eq 'abandoned-death-exit'") }, $true))
        $leftStopLines = @($leftStopIfs | ForEach-Object { @($_.Clauses[1].Item2.FindAll({ param($node) ($node -is [StringConstantExpressionAst]) -and ([string]$node.Value).StartsWith('[완료] ', [StringComparison]::Ordinal) }, $true)) } |
                ForEach-Object { [string]$_.Value })
    }
    $loopField = Invoke-LoopRow -StartScreen 'field' -Configure { $script:finishOnly = $true; $script:safeStopFlag = $true }
    $script:finishOnly = $false
    $loopSelection = Invoke-LoopRow -StartScreen 'field' -Configure { $script:finishOnly = $true; $script:flagOnAbyssClick = $true }
    $script:finishOnly = $false
    Assert-Case 'R2-L6 [루프 층] 마무리 실행 left + 두 출구 안전 중지 → (가) W 확정 뒤 · (나) 출처 완료 시점: 닫기·플래그 소비·종료 순서 · 닫기 호출 · exit · 거점 퇴장 줄(리뷰 문안) · 옛 회차 줄 0 · 준비/정리 실행 줄 0 · 예외 || 소스: 그 갈래 문자열(필드 · 선택 화면 · 마감 만료 각 1 · 합 3)' `
        (J @((Get-CloseOrderText -Events $loopField.Events), $loopField.CloseCalls, $loopField.ExitCode, (Get-LineCount -Lines $loopField.Logs -Exact $LOOP_SAFE_STOP_LEFT_FIELD_LINE),
                (Get-LineCount -Lines $loopField.Logs -Exact $LOOP_SAFE_STOP_ROUND_FIELD_LINE), (Get-LineCount -Lines $loopField.Logs -Exact $LOOP_SAFE_STOP_FIELD_LINE), $loopField.Thrown,
                (Get-CloseOrderText -Events $loopSelection.Events), $loopSelection.CloseCalls, $loopSelection.ExitCode, (Get-LineCount -Lines $loopSelection.Logs -Exact $LOOP_SAFE_STOP_LEFT_SELECTION_LINE),
                (Get-LineCount -Lines $loopSelection.Logs -Exact $LOOP_SAFE_STOP_ROUND_SELECTION_LINE), (Get-LineCount -Lines $loopSelection.Logs -Exact $LOOP_SAFE_STOP_SELECTION_LINE), $loopSelection.Thrown,
                @($leftStopLines | Where-Object { $_ -ceq $LOOP_SAFE_STOP_LEFT_FIELD_LINE }).Count, @($leftStopLines | Where-Object { $_ -ceq $LOOP_SAFE_STOP_LEFT_SELECTION_LINE }).Count,
                @($leftStopLines | Where-Object { $_ -ceq $LOOP_SAFE_STOP_EXPIRED_LEFT_LINE }).Count, $leftStopLines.Count)) `
        (J @('close:abandoned-death-exit|field > remove-flag > exit:4', 'abandoned-death-exit|field', '4', 1, 0, 0, '',
                'close:abandoned-death-exit|selection-proven > remove-flag > exit:4', 'abandoned-death-exit|selection-proven', '4', 1, 0, 0, '',
                1, 1, 1, 3))
}

function Test-RowR6RC1 {
    # R6-RC1 워커 쪽 (구현 명세 ⑤b5 3.1 ⑳ · 설계 v11 R6 7.5 RC1 · 사용자 결정 U-R6-1 (가) · 변이 R6-M23). 워커 2대 순차(AE1 꼴):
    #   워커 1 - 커스텀 혼자하기 판(모드 입력 = 본류가 읽는 $dungeonMode · $abyssMatching - 이 행만 둠)이 클리어 → 본류 꼬리의 실제 경로 술어 · 보상 결정('다른 던전 가기' -
    #     NEXT = 픽스처 1번(같은 입장 방식의 다른 던전) = item-change) · 실제 완료 마커 · 실제 클리어 기록(decision other) · 기록 확인 → 사유 줄 → '다른 던전 가기' 끝 안 'confirmed'
    #     뒤 exit 전 끊김(끝 모의의 예외). 구현 명세 ⑤b6 3.4 ⑳: 다음 항목이 없으면(NEXT 빈 값) 결정이 'entry-change' → 옛 나가기라 'other' 끝에 닿지 않아 NEXT 입력 두 줄(env ·
    #     워커 $script:customNext = 같은 토큰 해석)을 둡니다
    #   워커 2 - GUI 코드 1 'legacy-cleared' 의 복구 기동(RECOVERY=1 - 그 GUI 틱은 ⑯ R6-RC1)이 워커가 연 선택 화면에서 시작 → 완료 기록 읽기 0 · 쓰기 0(Consume-Handoff 의 복구
    #     갈래 - R6-M23) · 출처 없는 선택 화면 진단 1 + 코드 4(⑥e 2.14 - 그 [완료] 줄은 워커 원문 캡처) · 조작 0 · 키 0 · 자기 항목 생성 0
    Initialize-Row -Custom $true
    Set-AfterEntryConfig
    foreach ($emptyName in @('HONEYNOGI_CUSTOM_NEXT', 'HONEYNOGI_CUSTOM_NEXT_OWNER', 'HONEYNOGI_CUSTOM_NEXT_BOUNDARY', 'HONEYNOGI_LAST_RUN', 'HONEYNOGI_UNTIL_TIME')) { Set-ProcessEnv -Name $emptyName -Value '' }
    # 다음 항목 = 픽스처 1번(같은 입장 방식의 다른 던전 - GUI 원문 토큰). 워커 1 의 $script:customNext 는 아래 -Configure 가 이 env 의 같은 토큰을 원문 해석 함수로 받습니다
    Set-ProcessEnv -Name 'HONEYNOGI_CUSTOM_NEXT' -Value ([string](Format-CustomItemToken -Item $ABYSS_ITEMS[1]))
    $recoveryDoneLines = @($workerAst.FindAll({ param($node) ($node -is [StringConstantExpressionAst]) -and ([string]$node.Value).StartsWith('[완료] 커스텀 마무리 복구 중 어비스 선택 화면이', [StringComparison]::Ordinal) }, $true) |
            ForEach-Object { [string]$_.Value })
    $itemChangeLines = @()
    # 결정 사유 switch = 대입 대상 $otherCause(구현 명세 ⑤b6 3.4 ⑳ - 'exit' 갈래의 $exitCause · $moveCause 도 같은 조건식이라 조건식만으로는 셋)
    $causeSwitches = @($workerAst.FindAll({ param($node) ($node -is [SwitchStatementAst]) -and ($node.Condition.Extent.Text -eq '[string]$rewardDecision.Reason') -and ($node.Parent -is [AssignmentStatementAst]) -and ($node.Parent.Left.Extent.Text -ceq '$otherCause') }, $true))
    $causeFormats = @($workerAst.FindAll({ param($node) ($node -is [ExpandableStringExpressionAst]) -and ([string]$node.Value).Contains('${otherCause}') }, $true))
    if (($causeSwitches.Count -eq 1) -and ($causeFormats.Count -eq 1)) {
        foreach ($causeClause in $causeSwitches[0].Clauses) {
            if ([string]$causeClause.Item1.Value -eq 'item-change') {
                $itemChangeLines += ([string]$causeFormats[0].Value).Replace('${otherCause}', [string]@($causeClause.Item2.FindAll({ param($node) $node -is [StringConstantExpressionAst] }, $true))[0].Value)
            }
        }
    }
    $script:dungeonMode = 'solo'
    $script:abyssMatching = '없음'
    try {
        $first = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'clear' -Configure { $script:otherEndCrash = $true; $script:customNext = ConvertFrom-AbyssCustomItemSpec -Spec ([string]$env:HONEYNOGI_CUSTOM_NEXT) }
        $clearedEntries = @(@((Read-DiskJournal).entries) | Where-Object { [string]$_.stage -eq 'cleared' })
        $clearedText = $(if ($clearedEntries.Count -eq 1) { '{0}/{1}' -f [string]$clearedEntries[0].decision, $(if ($null -eq $clearedEntries[0].nextOwner) { '(없음)' } else { 'owner' }) } else { "(cleared $($clearedEntries.Count)개)" })
        $second = Invoke-Worker -WorkerStart 'selection' -WorkerClear 'halt' -WorkerRecovery
        $secondReads = [int]$script:spyCounts['Read-AbyssJournal']
        $secondWrites = [int]$script:spyCounts['Update-AbyssJournal']
    } finally {
        $script:dungeonMode = $null
        $script:abyssMatching = $null
    }
    Assert-Case 'R6-RC1 워커 1 [본류 층] 커스텀 클리어 → other 결정 사유 줄(item-change - 소스 캡처) · 끝 호출 · 끝 안 끊김 · 완료 마커 · 클리어 기록 1(decision/nextOwner)' `
        (J @($itemChangeLines.Count, (Get-LineCount -Lines $first.Logs -Exact (@($itemChangeLines) + @('(캡처 실패)'))[0]), (($first.Events -split ' > ') -ccontains 'other-end:ready'), $first.Thrown, $first.MarkerExists,
                $first.ClearedCalls, $clearedText)) `
        (J @(1, 1, 'True', $OTHER_END_CRASH_MESSAGE, 'True', 1, 'other/(없음)'))
    Assert-Case 'R6-RC1 워커 2 [본류 층] 복구 기동(RECOVERY=1) · 워커가 연 선택 화면 시작 → Role · exit · 마지막 [완료] = 복구 시작 선택 화면 문구(소스 캡처 1) · 진단 · 완료 기록 읽기/쓰기 · 조작 · 누른 키 · 자기 항목 생성' `
        (J @($second.Role, $second.ExitCode, $recoveryDoneLines.Count, ($second.LastDone -ceq (@($recoveryDoneLines) + @('(캡처 실패)'))[0]), $second.DiagCalls, $secondReads, $secondWrites, $second.Clicks, $second.Presses,
                $second.EnteredCalls)) `
        (J @('none', '4', 1, 'True', 1, 0, 0, 0, '', 0))
}

# ===== 실행 =====
try {
    # ① 추출 확인 · exit 치환(동작 행보다 먼저 - 명세 2.0-8) · 서명 대조
    foreach ($problem in $extractionProblems) { "FAIL 추출: $problem"; $fails++ }
    Assert-ExitTally -Label '저장소 묶음 워커 사본' -Tally $bundleExit
    Assert-ExitTally -Label ('워커 함수 ' + (@($workerExtracted) -join '·')) -Tally $workerExit
    if ($null -ne $script:segmentABlock) { Assert-ExitTally -Label '본류 층 시작 구간 A(2.1 블록 ~ run:18527 if 앞)' -Tally $segmentAExit }
    if ($null -ne $script:segmentBBlock) { Assert-ExitTally -Label '본류 층 조각 B(키 지점 ~ try 끝)' -Tally $segmentBExit }
    $combinedTally = New-ExitTally
    foreach ($partTally in @($segmentAExit, $segmentBExit, $catchExit)) {
        foreach ($key in @('Tokens', 'Statements', 'Inserted', 'Remaining', 'Errors', 'Units')) { $combinedTally[$key] = [int]$combinedTally[$key] + [int]$partTally[$key] }
    }
    Assert-ExitTally -Label '결합 층 두 조각(본류 조각 A+B · 최상위 catch 본문 - S10)' -Tally $combinedTally
    if ($guiAvailable) { Assert-ExitTally -Label 'GUI 함수' -Tally $guiExit }
    $signatureRows = @()
    foreach ($mockName in $WORKER_MOCK_NAMES) { $signatureRows += ('{0}:{1}' -f $mockName, ((Get-ParamSignature -Ast $workerAst -Name $mockName) -ceq (Get-LiveParamSignature -Name $mockName))) }
    foreach ($mockName in $GUI_MOCK_NAMES) { $signatureRows += ('{0}:{1}' -f $mockName, ((Get-ParamSignature -Ast $guiAst -Name $mockName) -ceq (Get-LiveParamSignature -Name $mockName))) }
    Assert-Case ('모의 서명 = 실제 함수 서명(워커 {0} · GUI {1})' -f $WORKER_MOCK_NAMES.Count, $GUI_MOCK_NAMES.Count) ($signatureRows -join ' ') (@(@($WORKER_MOCK_NAMES + $GUI_MOCK_NAMES) | ForEach-Object { '{0}:True' -f $_ }) -join ' ')
    # 계약 없는 키 호출의 접두(AE8) - 소스의 계약 없는 호출 중 문자열 접두를 쓰는 곳(사냥터 · 파티원)
    $script:plainKeyPrefixes = @(@(Get-CommandAsts -Root $workerAst -Name 'Invoke-AfterEntryKeys') | Where-Object { -not (Test-CommandHasParameter -CommandAst $_ -ParameterName 'KeyContract') } |
            ForEach-Object { Get-CommandArgumentAst -CommandAst $_ -ParameterName 'LogPrefix' } | Where-Object { $_ -is [StringConstantExpressionAst] } | ForEach-Object { $_.Value } | Sort-Object -Unique)
    Assert-Case 'AE8 준비 - 계약 없는 호출의 문자열 접두(소스 캡처)' (@($script:plainKeyPrefixes) -join ',') '[사냥터],[파티원]'

    # ② 정적
    try { Test-StaticRows } catch { "FAIL 정적 행 실행 중 예상 밖 예외: $($_.Exception.Message)"; $fails++ }

    # ③ 동작 행 - 앞 조건이 갖춰졌을 때만(빠졌으면 위 추출 FAIL 이 이미 찍힘 - 조용히 통과하지 않음)
    $spyReady = (@($BUNDLE_SPY_NAMES + $WORKER_SPY_NAMES) | Where-Object { $null -eq (Get-Command -Name (Get-RealFunctionName -Name $_) -CommandType Function -ErrorAction SilentlyContinue) }).Count -eq 0
    $stateReady = ($null -ne $script:workerCustomEnvBlock) -and ($null -ne $script:workerRunIdReadBlock) -and ($null -ne $script:workerHandoffDefaultBlock) -and ($null -ne $script:afterEntryActionsBlock)
    $keyReady = $guiAvailable -and $spyReady -and $stateReady -and (Test-WorkerExtracted -Names @('Invoke-AfterEntryKeys', 'Set-AbyssAfterEntryIndex', 'Add-AbyssJournalEnteredEntry', 'Consume-Handoff', 'Get-KeyDisplayName'))
    $storageReady = $keyReady -and (Test-WorkerExtracted -Names @('Close-AbyssKeyEntryOnLeave', 'Add-AbyssJournalClearedEntry'))
    $loopReady = $keyReady -and ($null -ne $script:leftCallBlock) -and (Test-WorkerExtracted -Names @('Return-ToAbyssSelection', 'Close-AbyssKeyEntryOnLeave', 'Test-SafeStopDuringCaptureFail'))
    $mainReady = $storageReady -and $loopReady -and ($null -ne $script:segmentABlock) -and ($null -ne $script:segmentBBlock) -and ($null -ne $script:startExitBlock)
    $combinedReady = $mainReady -and ($null -ne $script:combinedBlock)
    # 단계 2.5·2.6 행 - 선분기 함수들 · 그 감시(own 닫기 · 정지) · 클리어 대기 불명 마감 문구(OK11) 가 갖춰졌을 때만
    $handoffSpyReady = (@($HANDOFF_SPY_NAMES) | Where-Object { $null -eq (Get-Command -Name (Get-RealFunctionName -Name $_) -CommandType Function -ErrorAction SilentlyContinue) }).Count -eq 0
    $handoffReady = $mainReady -and $handoffSpyReady -and (-not [string]::IsNullOrEmpty($CLEAR_WAIT_UNKNOWN_LINE)) -and
        (Test-WorkerExtracted -Names @('Invoke-AbyssHandoffStart', 'Stop-AbyssHandoffOverlay', 'Close-AbyssOwnEntryBeforeEntry', 'Resolve-AbyssHandoffStartScreen', 'Step-AbyssFieldSettle'))
    $ROW_GROUPS = @(
        @{ Name = 'AE0'; Needs = $keyReady }, @{ Name = 'AE0n'; Needs = $keyReady }, @{ Name = 'AE2'; Needs = $keyReady }, @{ Name = 'AE3'; Needs = $keyReady },
        @{ Name = 'AE3Prime'; Needs = $keyReady },
        @{ Name = 'AE4'; Needs = $keyReady }, @{ Name = 'AE5'; Needs = $keyReady }, @{ Name = 'AE6'; Needs = $keyReady }, @{ Name = 'AE7Prime'; Needs = $keyReady },
        @{ Name = 'AE8'; Needs = $keyReady }, @{ Name = 'AE9'; Needs = $keyReady },
        @{ Name = 'AE1'; Needs = $mainReady }, @{ Name = 'AE2m'; Needs = $mainReady }, @{ Name = 'AE3m'; Needs = $mainReady }, @{ Name = 'AE7'; Needs = $mainReady },
        @{ Name = 'SE1'; Needs = $mainReady }, @{ Name = 'SE2'; Needs = $mainReady }, @{ Name = 'SE3'; Needs = $mainReady }, @{ Name = 'SE4'; Needs = $storageReady },
        @{ Name = 'SE5'; Needs = $mainReady }, @{ Name = 'SE6'; Needs = $mainReady }, @{ Name = 'SE7'; Needs = $mainReady }, @{ Name = 'SE8'; Needs = $mainReady },
        @{ Name = 'SE9'; Needs = $storageReady }, @{ Name = 'SE12'; Needs = $mainReady },
        @{ Name = 'R2Left'; Needs = $mainReady }, @{ Name = 'R2LeftPlain'; Needs = $mainReady }, @{ Name = 'R2Cleanup'; Needs = $mainReady }, @{ Name = 'R2C3'; Needs = $mainReady },
        @{ Name = 'R2E1'; Needs = $mainReady }, @{ Name = 'R2E6'; Needs = $mainReady }, @{ Name = 'R2E9'; Needs = $mainReady },
        @{ Name = 'R2LoopExits'; Needs = $loopReady }, @{ Name = 'R2DiagCopy'; Needs = $loopReady }, @{ Name = 'R2Storage'; Needs = $storageReady }, @{ Name = 'R2L2s'; Needs = $storageReady },
        @{ Name = 'OK1'; Needs = $handoffReady }, @{ Name = 'OK2'; Needs = $handoffReady }, @{ Name = 'OK3'; Needs = $handoffReady }, @{ Name = 'OK4'; Needs = $handoffReady },
        @{ Name = 'OK5'; Needs = $handoffReady }, @{ Name = 'OK6'; Needs = $handoffReady }, @{ Name = 'OK7'; Needs = $handoffReady }, @{ Name = 'OK8'; Needs = $handoffReady },
        @{ Name = 'OK9'; Needs = $handoffReady }, @{ Name = 'OK10'; Needs = $handoffReady }, @{ Name = 'OK11'; Needs = $handoffReady }, @{ Name = 'OK12'; Needs = $handoffReady },
        @{ Name = 'OK13'; Needs = $handoffReady },
        @{ Name = 'R2C4'; Needs = $handoffReady }, @{ Name = 'R2C6'; Needs = $handoffReady }, @{ Name = 'R2C8'; Needs = $handoffReady },
        @{ Name = 'R2E3'; Needs = $handoffReady }, @{ Name = 'R2E4'; Needs = $handoffReady },
        @{ Name = 'R2LeftFinish'; Needs = $mainReady }, @{ Name = 'R6RC1'; Needs = $mainReady },
        @{ Name = 'TC'; Needs = $combinedReady })
    foreach ($rowGroup in $ROW_GROUPS) {
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
            Remove-LockFolder
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
