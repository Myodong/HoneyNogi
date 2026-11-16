# tests\test_abyss_resume_reentry.ps1 (⑲) - 구현 단계 ⑤c 재입장 재개(Role resume)의 워커 행 (구현 명세 ⑤c 3.3 · 3.5 · 3.7 ⑲ · 0.6 의 5c-2 · 5c-3 몫)
#   재개 워커(RESUME=1 + 이어받은 retry-* 항목)가 이어받기 선분기(Invoke-AbyssHandoffStart 의 Role resume 열)에서 시작해 끝 exit 까지 가는 행을 실제 Consume-Handoff ·
#   실제 선분기 · 실제 재입장 대기 · 실제 끝 함수로 돌립니다. 화면 · 시계는 test_abyss_handoff_start.ps1(⑱′) 층 ① 스텁 엔진(가상 시계 · 판독 기록 · 시각 창 주입)과
#   그 행 하니스를 복사해 씁니다 - 고치지 않은 복사본이 ⑱′ 의 같은 이름 함수 · 같은 이름 변수 대입과 같은 글자인지는 맨 앞 HS0 이 주석 뺀 사본으로 봅니다(넓힌 함수 넷
#   Step-VirtualClock · Set-Scenario · Reset-FlowState · Invoke-StubSweep 는 뺌).
#   ⑲ 가 더하는 것:
#   - 감시 다섯(실제 함수로 넘김 - ⑱′ $WORKER_SPY_RENAMES 꼴): Wait-AbyssReentry(호출마다 결과 · 인자) · Update-AbyssRetryTimeVerdict · Get-DgTimeVerdict(재판단 수 · 첫 재판단 시각) ·
#     New-AbyssResumeClock(반환 객체 - 호출 C 의 -Clock 대조) · Complete-AbyssOtherSelection(-Ending · -Nonce)
#   - 모의 넷(④ §10 꼴 - 원문 param 블록 그대로): Find-AbyssRewardButtonPair(짝 판독 - R3 이면 두 점, PairMiss 차례면 그 점만 없음) · Click-GamePoint(⑱′ 몸통 + 부른 함수로
#     retry / other 를 가른 전송 뒤 화면 전이) · Invoke-AbyssExitClick(헬퍼 결과) · Return-ToAbyssSelection(호출 기록 · 예약 파일이 있으면 넘긴 코드로 출구)
#   - 시나리오 키 FlagAt · SweepYieldMs · RetrySend · OtherSend · PairMiss · HelperResult 와 행 값($dungeonMode · 지정 시각 두 길 · 마지막 판 · 마무리 실행 · 재개 워커의 세 표식 $null 시작)
#   행 묶음(구현 명세 ⑤c 3.5): A 시계 · 유예(WA-D) · A 'reclick' 칸(WA-D4 (나)(다) · WA-D6 · WA-D9) · A′ 선분기 유예 변형(GR - test_abyss_party_leader 대기 함수 N4-L 꼴을 선분기로) ·
#   B 필드(WA-F · S) · C 시작 화면(ST) · D 승계의 입장 끝 행(RS · RE) · D 재평가 · 판단값(RS3~RS9′ · WA-X9 · RE-3 · RE-5 · DV - 경계 T 는 같은 입력을 지정 시각 없이 돌려 잰 첫 재판단
#   가상 초에서 정함) · E 패널 뒤 취소 · 필드 취소(RS10 · RS11 · WA-X11 · RF) · F 재클릭 · 상한 · 폴백 · 기록 실패(RCK · RE-4 · FB · OW) · 정적 5C-S1~S13 · exit 이름별 수 · HS0.
#   5c-2 의 'reclick' 미처리 중간 행 RC0 과 5C-S2 접두부는 5c-3 에서 RCK 행 · 5C-S2 전체 꼴로 바꿨습니다(재개 끝이 'reclick' 을 받아 재평가 · 재클릭 · 멈춤 끝으로 가고 돌아오지 않음)
# 모든 행의 공통 단언(구현 명세 ⑤c 3.0): 'post-clear-stop' 0 · ' (post-clear)' 0 · ' (start-unknown)' 0 · 이벤트 정리 0 · 키 0 · 예외 0 · StartScreen 빈 값 · exit 있음.
# 시간 값은 전부 소스 캡처(W · Q · Tpm · T45 · 선분기 회전 대기)이고, 소스 상수와의 대소 관계에만 뜻이 있는 행 입력은 행 앞 전제 단언으로 둡니다(값이 바뀌면 공허 통과가 아니라 FAIL).
# 코드와 진리표는 같은 모델이라 함께 틀릴 수 있습니다 - 통과는 실기를 대신하지 않습니다(규칙 9).
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
    'Test-CustomCleanupOnly', 'Test-AbyssRewardText', 'Test-AbyssFewMembersPopupText', 'Test-AbyssEntryWaitingText',
    # ⑲ (구현 명세 ⑤c 3.3) - 지정 시각 읽기 문장(env 길 행이 점소싱 - 2.1 블록 밖이라 의존 추출이 따라가지 않음)과 감시 둘(재판단 · 시각 판정)이 넘길 실제 함수
    'Get-AbyssUntilTime', 'Update-AbyssRetryTimeVerdict', 'Get-DgTimeVerdict')
# 감시가 넘길 실제 함수 이름 - 같은 이름은 아래 감시가 차지합니다(호출 수·인자를 적고 실제 함수로 넘김)
$WORKER_SPY_RENAMES = @{
    'Consume-Handoff'                 = 'Invoke-RealConsumeHandoff'
    'Invoke-AbyssHandoffStart'        = 'Invoke-RealAbyssHandoffStart'                 # 반환 직후 판독 계수 스냅숏(명세 3.2 층 ②)
    'Resolve-AbyssHandoffStartScreen' = 'Invoke-RealResolveAbyssHandoffStartScreen'    # 회전마다 분류 호출 기록(R4-K1)
    'Test-CustomCleanupOnly'          = 'Invoke-RealTestCustomCleanupOnly'             # 정리 전용 판정 인자(R4-O1·O7 · V18)
    'Add-AbyssJournalClearedEntry'    = 'Invoke-RealAddAbyssJournalClearedEntry'       # 마커 → 기록 → 헬퍼 순서(P16 · R4-O9)
    # ⑲ 감시 다섯 (구현 명세 ⑤c 3.3 - 호출마다 결과 · 인자 / 재판단 수 / 시각 판정 수 / 반환 시계 객체 / 끝(other) 인자)
    'Wait-AbyssReentry'               = 'Invoke-RealWaitAbyssReentry'
    'Update-AbyssRetryTimeVerdict'    = 'Invoke-RealUpdateAbyssRetryTimeVerdict'
    'Get-DgTimeVerdict'               = 'Invoke-RealGetDgTimeVerdict'
    'New-AbyssResumeClock'            = 'Invoke-RealNewAbyssResumeClock'
    'Complete-AbyssOtherSelection'    = 'Invoke-RealCompleteAbyssOtherSelection'
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
    @('Start-Sleep', 'Get-Date', 'Stop-WorkerTailExit', 'Get-ConfigInteger', 'Get-ConfigValue', 'Find-AbyssRewardButtonPair'))   # ⑲ - 짝 판독은 아래 모의(추출 제외)

# Consume-Handoff 의 로그 줄 - 명세 ② 2.1 표 글자 그대로('제안' = 원천에 문구가 없어 명세가 붙인 것 - 구현이 바꾸면 여기도 함께, 명세 머리말 · 5절 B19)
$LINE_RECOVERY = '[안내] 복구 기동 - 이어받을 항목 없이 현행 복구 계약으로 진행합니다'                                                   # 표 ① (dev:593)
$LINE_LOCKED = '[완료] 완료 기록 파일이 사용 중이라 이어받을 역할을 확인하지 못해 정지합니다 (잠시 뒤 다시 시작해 주세요) (locked)'           # 표 ③ (dev:852·870)
$LINE_IO_FAILED = '[완료] 완료 기록 파일을 읽지 못해 이어받을 역할을 확인하지 못해 정지합니다 (잠시 뒤 다시 시작해 주세요) (locked)'         # 표 ④ (제안 - E02)
$LINE_CORRUPT = '[경고] 완료 기록 파일이 손상돼 이어받을 기록을 확인하지 못했습니다 - 이번 판은 입장 직후 키를 보내지 않습니다'             # 표 ⑤ (제안 - dev:870)
$LINE_OWNER_UNREADABLE = '[경고] 커스텀 항목 소유자 정보를 읽지 못해 이어받을 기록을 확인하지 않습니다 - GUI/워커 버전을 확인해 주세요'     # 표 ⑦ (제안 - E15)
$LINE_MISMATCH_FORMAT = '[경고] 넘겨받은 완료 기록이 이번 기동과 맞지 않아 이어받지 않고 진행합니다 ({0})'                                 # 표 ⑨ (제안 - 괄호 = 항목 stage)

# 명세 ② 2.1 표의 기본값과 정적 단언의 원문(공백 정규화 뒤 비교)
$HANDOFF_DEFAULT_TEXT = 'Role=none · Nonce= · CleanupOnly=False(bool) · FreshEntry=False(bool) · StartScreen= · AfterEntry=null · JournalState=ok · Stage= · At=null · RetryClicks=0'
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
$S20_CREATE_FAIL = '[완료] 입장 기록 실패 - 재화 중복 소모를 막기 위해 입장 직후 키를 보내지 않고 정지합니다 (캐릭터는 던전 안) (release)'
$KEYPOINT_CREATE_FAIL = '[완료] 입장 기록 실패 - 재화 중복 소모를 막기 위해 입장 직후 키를 보내지 않고 정지합니다 (캐릭터는 던전 안)'   # 본류 키 지점(Role none) - 꼬리 0
$S4_CLOSE_FORMAT = '[어비스] 시작 화면이 던전 밖이라 이어받던 판의 기록을 닫았습니다 - 새 판으로 들어갑니다 (abandoned-pre-entry-start · {0})'
$S5_CLOSE_FAIL_FORMAT = '[경고] 이어받던 판의 기록을 닫지 못했습니다 ({0}) - 새 판의 기록이 남은 기록을 함께 닫습니다'
$S6_FRESH_ENTRY = '[어비스] 이어받은 항목 없이 새 입장 확인 - 새 판으로 진행합니다 (ownFreshEntry)'
$S7_B2_START_FORMAT = '[어비스] 이어받기 시작: {0} 감지 - 입장을 기다립니다 (최대 {1}초)'
$S8_OVERLAY_FORMAT = '[안내] 이어받기 시작: 알 수 없는 화면이 {0}초 이어져 이벤트 화면 정리를 한 번 시도합니다'
$POPUP_NOTICE_LINE = '[안내] 권장 인원 팝업 관측(클릭 없음)'   # 재입장 대기의 보고 켬 호출만 쓰는 안내(구현 명세 ④ 1.10) - 선분기 B2 는 보고 끔이라 0(⑤a · V18)
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
$V18_FORBIDDEN_FRAGMENT = '이전 보상 화면을 새 항목 완료로 기록'                 # V18 next × 3버튼 - 이 기록 문장 0 (next × S 는 ⑤d 부터 그 판의 클리어 기록 - V18 next × S)
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
# 재입장 대기의 무변화 창(⑤a 부터 선분기 B2 단계가 그 함수를 부름) - 보고 끔 호출은 무변화 시계를 결론에 쓰지 않아 결과는 같지만 모형을 소스와 맞춥니다(구현 명세 ④ C3)
$abyssReclickQuietSeconds = Get-SourceAssignmentValue 'abyssReclickQuietSeconds'
$capturedTimeoutPartyMatch = $timeoutPartyMatch

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
    # 감시(워커 실제 서명 param([string]$Decision = 'exit', $NextOwner = $null) - 구현 명세 ⑤b2 1.2) - 부른 순서를 사건 기록에 남기고 실제 기록 함수로(임시 폴더의
    # 실제 완료 기록 파일). 받은 인자를 그대로 넘기고 실제 반환(@{ Tag; Nonce })을 돌려줍니다 - 워커의 세 호출(본류 1 · 시작 분기 2 - 보상 화면 own · 클리어 화면 own·next(⑤d))은 [void] 로 버립니다
    param([string]$Decision = 'exit', $NextOwner = $null)
    $script:clearedCalls++
    Add-StubEvent 'cleared'
    return (Invoke-RealAddAbyssJournalClearedEntry @PSBoundParameters)
}
function Consume-Handoff {
    # 감시 - 호출 수를 세고 실제 함수(워커 원문)로 넘깁니다. 실제 함수의 출력 개체를 그대로 돌려주고 따로 적어 둡니다(반환 'ok'/'stop' 하나 계약)
    $script:consumeCalls++
    $consumeOutput = @(Invoke-RealConsumeHandoff @args)
    $script:consumeOutputs = $consumeOutput
    return $consumeOutput
}
# ===== ⑲ 감시 다섯 · 모의 넷 (구현 명세 ⑤c 3.3 '추출' · '클릭 · 짝 · 헬퍼 모의' - 원문 param 블록 그대로 + 몸통, 아래 '서명 대조') =====
# 감시는 실제 함수(위 의존 추출이 Invoke-Real* 이름으로 올림)로 넘깁니다. 모의 넷 중 Click-GamePoint · Invoke-AbyssExitClick · Return-ToAbyssSelection 은 위 ⑱′ 모의 몸통 표가
#   만든 같은 이름을 이 정의로 바꾸고, Find-AbyssRewardButtonPair 는 새로 둡니다(추출 제외 - $TEST_DEFINED_NAMES)
$RESUME_SPY_BODIES = [ordered]@{}
$RESUME_SPY_BODIES['Wait-AbyssReentry'] = @'
    # 감시 - 호출마다 인자(재개 시계와 같은 객체인지 · 보고 · 필드 결과 · 패널 초기값 · 유예)와 그 순간 재개 항목 stage(호출 D 는 전송 기록 직후 - RCK2 의 'Stage retry-clicked'
    #   를 행 끝 reentered 에 덮이기 전에 봄 · 구현 사전 대조 지적)를 적고 실제 대기 함수로 넘깁니다(결과 · 반환 시각은 돌아온 뒤 채움)
    $reentryCall = [pscustomobject]@{ T = (Get-VirtualElapsed); ReturnT = $null; Result = '(돌아오지 않음)'; ClockResume = (($null -ne $Clock) -and [object]::ReferenceEquals($Clock, $script:resumeClockReturned))
        HasClock = ($null -ne $Clock); LimitSeconds = [int]$LimitSeconds; Context = [string]$Context; Report = [bool]$ReportRewardReturn; Field = [bool]$ReportFieldReturn
        PanelSeen = [bool]$PanelSeen; Grace = [bool]$ResumeGrace; StageAtCall = [string](Get-ResumeEntryState).Stage }
    $script:resumeReentryCalls.Add($reentryCall)
    $reentryReturn = Invoke-RealWaitAbyssReentry @PSBoundParameters
    $reentryCall.ReturnT = Get-VirtualElapsed
    $reentryCall.Result = [string]$reentryReturn.Result
    return $reentryReturn
'@
$RESUME_SPY_BODIES['Update-AbyssRetryTimeVerdict'] = @'
    # 감시 - 재판단 수 · 첫 재판단 가상 초
    $script:resumeUpdateCalls++
    if ($null -eq $script:resumeVerdictAt) { $script:resumeVerdictAt = Get-VirtualElapsed }
    return (Invoke-RealUpdateAbyssRetryTimeVerdict)
'@
$RESUME_SPY_BODIES['Get-DgTimeVerdict'] = @'
    # 감시 - 시각 판정 수
    $script:resumeDgCalls++
    return (Invoke-RealGetDgTimeVerdict @PSBoundParameters)
'@
$RESUME_SPY_BODIES['New-AbyssResumeClock'] = @'
    # 감시 - 반환 객체를 남깁니다(호출 C 의 -Clock 이 같은 객체인지 - ST12)
    $script:resumeClockCalls++
    $resumeClockReturn = Invoke-RealNewAbyssResumeClock
    $script:resumeClockReturned = $resumeClockReturn
    return $resumeClockReturn
'@
$RESUME_SPY_BODIES['Complete-AbyssOtherSelection'] = @'
    # 감시 - 끝(other) 호출마다 -Ending · -Nonce (끝-취소의 nonce)
    $script:resumeOtherEnds.Add([pscustomobject]@{ T = (Get-VirtualElapsed); Ending = [string]$Ending; Nonce = [string]$Nonce })
    Invoke-RealCompleteAbyssOtherSelection @PSBoundParameters
'@
$RESUME_MOCK_BODIES = [ordered]@{}
$RESUME_MOCK_BODIES['Find-AbyssRewardButtonPair'] = @'
    return (Invoke-ResumePairStub)
'@
$RESUME_MOCK_BODIES['Click-GamePoint'] = @'
    $script:inputCalls.Add(("Click-GamePoint {0},{1}" -f $ReferenceX, $ReferenceY)); $script:lastClickPerformed = $true; $script:lastClickSkipReason = ""
    Invoke-ResumeClickTransition -ReferenceX $ReferenceX -ReferenceY $ReferenceY
'@
$RESUME_MOCK_BODIES['Invoke-AbyssExitClick'] = @'
    $script:exitClickCalls++; Add-StubEvent "exitclick"
    $script:resumeHelperTimes.Add([double](Get-VirtualElapsed))
    return @{ Result = [string]$script:scenarioHelperResult; FrozenMs = 0 }
'@
$RESUME_MOCK_BODIES['Return-ToAbyssSelection'] = @'
    $returnFlag = Test-Path -LiteralPath $safeStopFlagPath
    $script:resumeReturnCalls.Add([pscustomobject]@{ T = (Get-VirtualElapsed); Code = [int]$SafeStopExitCode; Reason = [string]$LeaveEntryReason; Flag = [bool]$returnFlag })
    Add-StubEvent ('return:' + [string]$SafeStopExitCode + ':' + [string]$LeaveEntryReason)
    if ($returnFlag) { Stop-WorkerTailExit $SafeStopExitCode }
'@
foreach ($resumeDefinition in @(@($RESUME_SPY_BODIES.GetEnumerator()) + @($RESUME_MOCK_BODIES.GetEnumerator()))) {
    $resumeDefinitionName = [string]$resumeDefinition.Key
    if (-not $workerTopFunctions.ContainsKey($resumeDefinitionName)) {
        $extractionProblems.Add("⑲ 감시·모의 대상 워커 함수 $resumeDefinitionName 을(를) 찾지 못했습니다(서명을 원문에서 가져옴)")
        continue
    }
    $resumeParamBlock = $workerTopFunctions[$resumeDefinitionName].Body.ParamBlock
    $resumeParamText = $(if ($null -ne $resumeParamBlock) { $resumeParamBlock.Extent.Text } else { '' })
    Invoke-Expression ("function $resumeDefinitionName {`r`n$resumeParamText`r`n$([string]$resumeDefinition.Value)`r`n}")
}

$RESUME_RETRY_POINT = @(636, 654)                  # '다시 하기' 기준 좌표 (④ §10 의 3버튼 점 - 09-18 보관 프레임)
$RESUME_OTHER_POINT = @(778, 654)                  # '다른 던전 가기' 기준 좌표
$RESUME_OTHER_SEND_DEFAULT = @(,@(1.0, 'SEL'))     # '다른 던전 가기' 전송 뒤 1초에 선택 화면 (④ 의 기본 전이와 같은 뜻 - 키는 ⑱′ 카탈로그의 'SEL')

function Invoke-ResumePairStub {
    # 짝 판독 - 판독 스텁 한 번. 실패면 Text '' · 두 점 $null(원문 반환 꼴), 성공이면 Text = 그 화면 하단 · 화면 키 R3 이면 두 점. PairMiss 의 차례 n(행 전체 짝 판독 차례 ·
    #   실패 판독도 셈)이 성공하면 그 점만 $null - Text 는 그대로 둡니다(3버튼 서명이 남아야 결측 1초 재판독이 돎)
    $script:resumePairCount++
    $pairScreen = Invoke-StubRead -Name 'Find-AbyssRewardButtonPair'
    if ($null -eq $pairScreen) { return @{ Text = ''; Retry = $null; Other = $null } }
    $pairKey = [string]$script:readLog[$script:readLog.Count - 1].Key
    $pairRetry = $null
    $pairOther = $null
    if ($pairKey -eq 'R3') {
        $pairRetry = @{ X = $RESUME_RETRY_POINT[0]; Y = $RESUME_RETRY_POINT[1] }
        $pairOther = @{ X = $RESUME_OTHER_POINT[0]; Y = $RESUME_OTHER_POINT[1] }
    }
    if ($script:scenarioPairMiss.ContainsKey([int]$script:resumePairCount)) {
        if ([string]$script:scenarioPairMiss[[int]$script:resumePairCount] -eq 'Retry') { $pairRetry = $null } else { $pairOther = $null }
    }
    return @{ Text = [string]$pairScreen.Bottom; Retry = $pairRetry; Other = $pairOther }
}

function Add-ResumeTimelineStep {
    # 시각표에 (가상 초, 화면 키) 한 단계 - 시각 차례를 지키고 같은 시각은 뒤에 둡니다(Get-StubScreenKey 가 '지금 이하 마지막' 을 고름)
    param([double]$At, [string]$Screen)
    if (-not $SCREEN_CATALOG.ContainsKey($Screen)) { throw "TEST-SCREEN: 모르는 화면 키 [$Screen]" }
    $newStep = [pscustomobject]@{ T = $At; S = $Screen }
    $mergedSteps = New-Object System.Collections.Generic.List[object]
    $stepInserted = $false
    foreach ($oldStep in @($script:scenarioTimeline)) {
        if ((-not $stepInserted) -and ([double]$oldStep.T -gt $At)) {
            $mergedSteps.Add($newStep)
            $stepInserted = $true
        }
        $mergedSteps.Add($oldStep)
    }
    if (-not $stepInserted) { $mergedSteps.Add($newStep) }
    $script:scenarioTimeline = $mergedSteps.ToArray()
}

function Invoke-ResumeClickTransition {
    # 전송 뒤 화면 전이 - 종류 = 부른 함수(호출 스택: 클릭 루프 Invoke-AbyssRetryClick → retry · '다른 던전 가기' 대기 → other · 그 밖은 전이 없음). 전송 번호 = 이 행에서
    #   그 종류가 보낸 차례(1부터 - 그 판의 retryClicks 시작값을 더하지 않음). RetrySend · OtherSend 표에 그 번호 칸이 있으면 그 칸만(빈 목록 = 전이 없음), 없으면 retry 는
    #   전이 없음 · other 는 1초에 선택 화면. 클릭 모의는 시간을 쓰지 않아 전송 시각 = 그 순간 가상 초
    param([int]$ReferenceX, [int]$ReferenceY)
    $callerNames = @(Get-PSCallStack | ForEach-Object { [string]$_.FunctionName })
    $clickKind = ''
    if ($callerNames -contains 'Invoke-AbyssRetryClick') { $clickKind = 'retry' } elseif ($callerNames -contains 'Wait-AbyssOtherSelection') { $clickKind = 'other' }
    if (-not $clickKind) { return }
    $sendAt = [double](Get-VirtualElapsed)
    $script:resumeSends.Add([pscustomobject]@{ Kind = $clickKind; T = $sendAt; X = $ReferenceX; Y = $ReferenceY })
    $sendIndex = @($script:resumeSends | Where-Object { $_.Kind -eq $clickKind }).Count
    $sendTable = $script:scenarioRetrySend
    if ($clickKind -eq 'other') { $sendTable = $script:scenarioOtherSend }
    $sendSteps = $null
    if ($sendTable.ContainsKey($sendIndex)) { $sendSteps = $sendTable[$sendIndex] } elseif ($clickKind -eq 'other') { $sendSteps = $RESUME_OTHER_SEND_DEFAULT }
    foreach ($sendStep in @($sendSteps)) {
        if ($null -ne $sendStep) { Add-ResumeTimelineStep -At ($sendAt + [double]$sendStep[0]) -Screen ([string]$sendStep[1]) }
    }
}

# ===== 가상 시계 · 화면 모형 · 스텁 엔진 (단계 2.4~2.6 - 명세 ② 3.2 층 ① '화면 스텁 시퀀스 · 가상 시계 · 시각 창 주입') =====
# 회전 = 회전 머리 스텁(조작 양보 게이트 Test-UserRecentlyActive · 동결 블록의 Test-SafeStopDuringCaptureFail)이 불린 뒤의 구간. 판독 스텁은 시간을 쓰지 않고,
# Start-Sleep·양보 대기·스윕이 시계를 전진합니다. 판독 기록(회전 · 가상 초 · 함수 · 단계 · 화면 키 · 실패)은 계측 줄 숫자의 기대값을 다시 셀 때 씁니다
function Get-VirtualElapsed {
    # 행 시작부터 가상 초 (틱 나눗셈 - TotalSeconds 의 1e-7 곱은 경계에서 어긋남, test_abyss_return_loop 와 같은 이유)
    return (($script:vclock - $script:rowStartClock).Ticks / 10000000.0)
}
function Step-VirtualClock {
    # 가상 시계 전진 - 상한을 넘으면 예외(마감을 못 보는 변이가 행을 끝없이 돌리지 않게). ⑲ 가 넓힘(구현 명세 ⑤c 3.3): 전진 뒤 시나리오 FlagAt 초를 지났고 아직 안
    #   만들었으면 안전 중지 예약 파일을 만듭니다(Test-Path 를 모의하지 않음 - FlagAt 0 은 첫 전진에 생김)
    param([double]$Milliseconds)
    if ($Milliseconds -le 0) { return }
    $script:vclock = $script:vclock.AddTicks([long][Math]::Round($Milliseconds * 10000))
    if ((Get-VirtualElapsed) -gt $VIRTUAL_TIME_LIMIT) { throw ('TEST-VTIMEOUT: 가상 시간 상한 {0}초를 넘었습니다' -f $VIRTUAL_TIME_LIMIT) }
    if (($null -ne $script:scenarioFlagAt) -and (-not $script:resumeFlagCreated) -and ((Get-VirtualElapsed) -ge [double]$script:scenarioFlagAt)) {
        [IO.File]::WriteAllText($safeStopFlagPath, '')
        $script:resumeFlagCreated = $true
    }
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
    # 캡처 성공 등록 - 운영 Register-CaptureSuccess 의 계약(플래그 해제 · 실패 구간 누적 · 실패 원인 비움 - 원인은 RectThrow 만 세움, 구현 명세 ⑤a 2.2-1)
    if ($script:screenCaptureFailing) {
        $script:stubFailTotalMs = [double]$script:stubFailTotalMs + ($script:vclock - $script:stubFailSince).TotalMilliseconds
        $script:screenCaptureFailing = $false
        $script:stubFailSince = $null
        $script:captureFailCause = $null
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
    # 성공 - 운영의 교대 모양 '판독에서 실패 시작 → 다음 회전 동결 탐침 복구', R4-N6r). 선분기 단계의 RectThrow 창 안이면 판독 기록(Key 'RECT') → 실패
    # 등록 → 원인 = 소스 캡처 원인 → 소스 캡처 문구로 throw 합니다(운영 공용 판독의 창 좌표 실패 = 실패 등록 뒤 throw · 구현 명세 ⑤a 2.2-1). CapFail 확인보다
    # 앞이라 같은 창의 CapFail 로 복구 탐침도 실패시킵니다
    param([string]$Name)
    $script:stubReadCalls++
    if ($script:stubReadCalls -gt $READ_CALL_LIMIT) { throw ('TEST-VTIMEOUT: 판독 스텁 호출 상한 {0}회를 넘었습니다' -f $READ_CALL_LIMIT) }
    if (($script:readPhase -eq 'selector') -and ($script:turnId -ne $script:lastReadTurnId)) {
        $script:lastReadTurnId = $script:turnId
        $script:readTurnIndex++
    }
    $nowSeconds = Get-VirtualElapsed
    if (($script:readPhase -eq 'selector') -and ($null -ne (Find-StubWindow -Windows $script:scenarioRectThrow -Time $nowSeconds))) {
        $script:readLog.Add([pscustomobject]@{ Index = $script:readLog.Count; Turn = $script:turnId; T = $nowSeconds; Name = $Name; Phase = $script:readPhase; Key = 'RECT'; Failed = $true })
        Register-StubCaptureFail
        $script:captureFailCause = $RECT_FAIL_CAUSE
        throw $RECT_THROW_MESSAGE
    }
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
    #   (회전 서두 게이트가 못 보는 간접 양보 - 골격 ⑥, R4-N15i). ⑲ 가 넓힘(구현 명세 ⑤c 3.3): SweepYield 창의 시계 전진 · 양보 누적이 행 값 SweepYieldMs(기본 = ⑱′ 값)
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
        Step-VirtualClock -Milliseconds $script:scenarioSweepYieldMs
        $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $script:scenarioSweepYieldMs
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
    $script:captureFailCause = $null
    $script:stubFailTotalMs = [double]0
    $script:stubFailSince = $null
    $script:userYieldTotalMs = [double]0
    $script:lastClickPerformed = $true
    $script:lastClickSkipReason = ''
    $script:lastClearPromptText = ''
    $script:lastQuestTrackerText = ''
    # ⑲ 가 넓힘(구현 명세 ⑤c 3.3 '행 준비') - 안전 중지 예약 파일과 '만들었음' 표식 · 재개 워커의 세 표식(운영에서 본류 ⓪ 를 지나지 않아 미정의로 시작 - 앞 행의 commit ·
    #   첫 시도 표식 · 'continue' 가 다음 행으로 새지 않게 $null) · 지정 시각 · 마지막 판 · 감시 다섯과 새 모의 넷의 기록. 기록 목록은 List[psobject] 입니다 - PS 5.1 에서
    #   New-Object 로 만든 List[object] 를 @() 로 감싸면 '인수 형식이 일치하지 않습니다' 예외(⑱′ 기록 목록 주석과 같은 함정 - 첫 실행에서 행 묶음 여섯이 모두 이 예외로 멈춤)
    if ([IO.File]::Exists($safeStopFlagPath)) { [IO.File]::Delete($safeStopFlagPath) }
    $script:resumeFlagCreated = $false
    $script:abyssRetryTimeVerdict = $null
    $script:abyssRetryCommitted = $null
    $script:abyssRetryAttemptRecorded = $null
    $script:abyssUntil = $null
    $script:dgLastRun = $false
    $script:resumeReentryCalls = New-Object System.Collections.Generic.List[psobject]
    $script:resumeUpdateCalls = 0
    $script:resumeDgCalls = 0
    $script:resumeVerdictAt = $null
    $script:resumeClockReturned = $null
    $script:resumeClockCalls = 0
    $script:resumeOtherEnds = New-Object System.Collections.Generic.List[psobject]
    $script:resumePairCount = 0
    $script:resumeSends = New-Object System.Collections.Generic.List[psobject]
    $script:resumeReturnCalls = New-Object System.Collections.Generic.List[psobject]
    $script:resumeHelperTimes = New-Object System.Collections.Generic.List[double]
    Set-Scenario -Scenario @{}
}
function Set-Scenario {
    # 행 화면 시나리오 - Timeline(New-Timeline) / Cycle(판독 회전마다 순환할 화면 키) · CapFail · Active · Sweep · SerialFail(New-Windows) · AfterOverlay(정리 뒤
    # 시각표 - 상대 초) + AfterOverlayAt(몇 번째 정리에서) · Main(본류 단계 덮어쓰기) · MainOverlay(본류 run:18221 의 정리가 참 - 정리 뒤 시각표, 상대 초) ·
    # ReturnLoop('return' / 'exit4' - 복귀 루프가 던전 안 2연속 + 20초로 코드 4 인 모양) · LockPlan(@{ Phase; Ordinal; Mode }) · SleepMap(요청 ms → 가상 ms) ·
    # SweepSkip · SweepYield · ReadFail · RectThrow(New-Windows - 위 스텁 주석)
    # ⑲ 가 넓힘(구현 명세 ⑤c 3.3): FlagAt(안전 중지 예약 파일을 만드는 가상 초 - 없으면 없음) · SweepYieldMs(SweepYield 창의 시계 전진 · 양보 누적 ms - 없으면 ⑱′ 값) ·
    #   RetrySend · OtherSend(전송 번호 → 전이 목록 @(@(전송 뒤 초, 키), …)) · PairMiss(짝 판독 차례 → 'Retry' | 'Other') · HelperResult(나가기 헬퍼 결과 - 없으면 'clicked')
    param([hashtable]$Scenario)
    # 배열 값은 '$(if …)' 로 받지 않습니다 - 원소 하나짜리 배열이 풀려 스칼라가 됩니다(순환 화면 키를 글자로 색인하게 됨 - 규칙 3 의 배열 함정)
    $script:scenarioTimeline = @(New-Timeline -Pairs @(0, 'U'))
    if ($Scenario.ContainsKey('Timeline')) { $script:scenarioTimeline = @($Scenario.Timeline) }
    $script:scenarioCycle = $null
    if ($Scenario.ContainsKey('Cycle')) { $script:scenarioCycle = @($Scenario.Cycle) }
    $script:scenarioCapFail = @()
    if ($Scenario.ContainsKey('CapFail')) { $script:scenarioCapFail = @($Scenario.CapFail) }
    $script:scenarioRectThrow = @()
    if ($Scenario.ContainsKey('RectThrow')) { $script:scenarioRectThrow = @($Scenario.RectThrow) }
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
    # ⑲ 키 (해시 값은 대입으로만 받습니다 - 위와 같은 이유)
    $script:scenarioFlagAt = $null
    if ($Scenario.ContainsKey('FlagAt')) { $script:scenarioFlagAt = [double]$Scenario.FlagAt }
    $script:scenarioSweepYieldMs = [double]$SWEEP_STUB_MS
    if ($Scenario.ContainsKey('SweepYieldMs')) { $script:scenarioSweepYieldMs = [double]$Scenario.SweepYieldMs }
    $script:scenarioRetrySend = @{}
    if ($Scenario.ContainsKey('RetrySend')) { $script:scenarioRetrySend = $Scenario.RetrySend }
    $script:scenarioOtherSend = @{}
    if ($Scenario.ContainsKey('OtherSend')) { $script:scenarioOtherSend = $Scenario.OtherSend }
    $script:scenarioPairMiss = @{}
    if ($Scenario.ContainsKey('PairMiss')) { $script:scenarioPairMiss = $Scenario.PairMiss }
    $script:scenarioHelperResult = 'clicked'
    if ($Scenario.ContainsKey('HelperResult')) { $script:scenarioHelperResult = [string]$Scenario.HelperResult }
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

$safeStopFlagPath = Join-Path $testRootFolder 'safe_stop.flag'   # ⑲ - 안전 중지 예약 파일(FlagAt 행이 만들고 행 준비가 지움 - DV · RE-3 · RE-4). 워커 함수와 모의가 같은 이름을 읽음

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

function Format-HandoffAt {
    # 재개 재료 At(그 항목의 at 객체) → 'retryAttempt=…,retryClicked=…'(재개 시계가 읽는 두 칸 - 값 없음 'null' · 객체 없음 'null', 구현 명세 ⑤c 2.1 · 2.3)
    param($At)
    if ($null -eq $At) { return 'null' }
    $atParts = foreach ($atName in @('retryAttempt', 'retryClicked')) {
        $atField = Get-AbyssJournalField -Object $At -Name $atName
        $atValue = $(if (-not $atField.Has) { '(필드 없음)' } elseif ($null -eq $atField.Value) { 'null' } else { [string]$atField.Value })
        '{0}={1}' -f $atName, $atValue
    }
    return (@($atParts) -join ',')
}

function Get-HandoffSnapshot {
    # $script:handoff → 단언용 값 (해시테이블·객체 공용 읽기 - 필드가 없으면 '(필드 없음)')
    $handoffState = $script:handoff
    $fields = @{}
    foreach ($fieldName in @('Role', 'Nonce', 'CleanupOnly', 'JournalState', 'AfterEntry', 'FreshEntry', 'StartScreen', 'Stage', 'At', 'RetryClicks')) { $fields[$fieldName] = Get-AbyssJournalField -Object $handoffState -Name $fieldName }
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
        # 재개 재료 셋(구현 명세 ⑤c 2.1) - resume 만 그 항목 값으로 채우고 own·next 는 기본값 그대로(CH10s·CH13s·CH14s·CH14c)
        Stage        = $(if ($fields.Stage.Has) { [string]$fields.Stage.Value } else { $missing })
        At           = $(if ($fields.At.Has) { Format-HandoffAt $fields.At.Value } else { $missing })
        RetryClicks  = $(if ($fields.RetryClicks.Has) { [string][int]$fields.RetryClicks.Value } else { $missing })
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

# ===== ⑲ 소스 캡처 · 행 하니스 (구현 명세 ⑤c 3.3) =====
$timeoutEntry = Get-SourceAssignmentValue 'timeoutEntry'   # 혼자하기 모드 예산(T45) - ⑱′ 캡처에 없어 더함
$RESUME_COMMON_WANT = 'post-clear-stop 0 · post-clear 0 · start-unknown 0 · 이벤트 정리 0 · 키 0 · 예외 [] · StartScreen [] · exit 있음 True'
$RESUME_NEVER = 2900   # 행 끝까지 이어지는 창의 끝(가상 시간 상한 $VIRTUAL_TIME_LIMIT 안)
$RESUME_WAITING_STRINGS = @('ready', 'matching', 'popup', 'entry-waiting', 'unknown', 'prompt', 'field')   # 기다리는 상태 분류 문자열(유예 창이 아님 - 구현 명세 ⑤c 1.5)
$RESUME_UNTIL_TOKEN = '$($script:abyssUntil.ToString(''HH:mm''))'   # 지정 시각 HH:mm 자리(재개 판단 'time' 사유 · 직전 판단 시간 줄의 원문 글자) - 기대 줄은 행 지정 시각으로 채움
$RESUME_RETRY_MISS_PREFIX = "[어비스] 보상 화면에서 '다시 하기' 글자를 찾지 못했습니다 - 1초 뒤 다시 읽습니다"   # 클릭 루프 짝 결측 첫 줄(뒤에 판독 글자가 붙음 - 캡처가 원문 하나를 확인)
$RESUME_OTHER_MISS_PREFIX = "[어비스] 보상 화면에서 '다른 던전 가기' 글자를 찾지 못했습니다 - 1초 뒤 다시 읽습니다"   # '다른 던전 가기' 대기 짝 결측 첫 줄(같음)
$RESUME_CLICK_PREFIX = "[어비스] '다시 하기' 직전 판단: "   # 클릭 자리 재검사 줄 접두(캡처가 원문 둘을 확인)

function Get-WorkerStringValues {
    # 워커 함수 안 문자열 원문 중 -Prefix 로 시작하는 것(확장 문자열은 변수 자리 그대로) - 열거용
    param([string]$FunctionName, [string]$Prefix)
    return @(Get-StringNodes -Node (Get-FlowFunctionNode $FunctionName) | Where-Object { ([string]$_.Value).StartsWith($Prefix, [StringComparison]::Ordinal) } | ForEach-Object { [string]$_.Value })
}

function Get-DiagnosticContexts {
    # 워커 함수 안 Write-LifeDiagnostics 의 -Context 값들(문자열 상수) - 열거용
    param([string]$FunctionName)
    return @(Get-CommandNodes -Node (Get-FlowFunctionNode $FunctionName) -Name 'Write-LifeDiagnostics' | ForEach-Object {
            $diagElements = @($_.CommandElements)
            for ($diagIndex = 1; $diagIndex -lt ($diagElements.Count - 1); $diagIndex++) {
                if (($diagElements[$diagIndex] -is [CommandParameterAst]) -and ($diagElements[$diagIndex].ParameterName -eq 'Context') -and ($diagElements[$diagIndex + 1] -is [StringConstantExpressionAst])) {
                    [string]$diagElements[$diagIndex + 1].Value
                }
            }
        })
}

function Initialize-ResumeCaptures {
    # 끝 문구 · 진단 문맥 · 패턴 · 지정 시각 문장 · 선분기 회전 대기를 워커 원문에서 캡처합니다(사본을 박지 않음 - 규칙 9). 하나가 아니면 추출 문제(FAIL)로 남깁니다
    $insideDone = @(Get-WorkerStringValues 'Complete-AbyssInsideHandoff' '[완료] ' | Where-Object { $_.Contains('[terminal=InsideHandoff nonce=$Nonce]') })
    if ($insideDone.Count -eq 1) { $script:rzIhLine = $insideDone[0].Replace('$Nonce', $NONCE_C) } else { $script:rzIhLine = '(없음)'; $extractionProblems.Add("재입장 완료 줄이 $($insideDone.Count)개") }
    $continueLines = @(Get-WorkerStringValues 'Complete-AbyssInsideHandoff' '[어비스] 지정 시간 ')
    if ($continueLines.Count -eq 1) { $script:rzContinuePrefix = '[어비스] 지정 시간 ' } else { $script:rzContinuePrefix = '(없음)'; $extractionProblems.Add("이어 감 안내 줄이 $($continueLines.Count)개") }
    $noneLines = @(Get-WorkerStringValues 'Stop-AbyssReentryTimeout' '[완료] ')
    $noneSolo = @($noneLines | Where-Object { $_.Contains('${timeoutEntry}') })
    $noneParty = @($noneLines | Where-Object { $_.Contains('${timeoutPartyMatch}') })
    if (($noneSolo.Count -eq 1) -and ($noneParty.Count -eq 1)) {
        $script:rzNoneSolo = $noneSolo[0].Replace('${timeoutEntry}', [string]$timeoutEntry)
        $script:rzNoneParty = $noneParty[0].Replace('${timeoutPartyMatch}', [string]$capturedTimeoutPartyMatch)
    } else { $script:rzNoneSolo = '(없음)'; $script:rzNoneParty = '(없음)'; $extractionProblems.Add("시간 초과 정지 줄 모드별 1개씩이 아님(solo $($noneSolo.Count) · party $($noneParty.Count))") }
    $noneDiags = @(Get-DiagnosticContexts 'Stop-AbyssReentryTimeout')
    if ($noneDiags.Count -eq 1) { $script:rzNoneDiag = $noneDiags[0] } else { $script:rzNoneDiag = '(없음)'; $extractionProblems.Add("시간 초과 진단 문맥 $($noneDiags.Count)개") }
    $fieldCancelLines = @(Get-WorkerStringValues 'Stop-AbyssReentryFieldCancelled' '[완료] ')
    if ($fieldCancelLines.Count -eq 1) { $script:rzFieldCancel = $fieldCancelLines[0] } else { $script:rzFieldCancel = '(없음)'; $extractionProblems.Add("필드 취소 정지 줄 $($fieldCancelLines.Count)개") }
    $fieldStopLines = @(Get-WorkerStringValues 'Invoke-AbyssHandoffStart' '[완료] 재입장 재개 - ')
    if ($fieldStopLines.Count -eq 1) { $script:rzFieldStop = $fieldStopLines[0] } else { $script:rzFieldStop = '(없음)'; $extractionProblems.Add("재개 필드 정지 줄 $($fieldStopLines.Count)개") }
    $fieldDiags = @(Get-DiagnosticContexts 'Invoke-AbyssHandoffStart' | Where-Object { $_.StartsWith('재입장 재개', [StringComparison]::Ordinal) })
    if ($fieldDiags.Count -eq 1) { $script:rzFieldDiag = $fieldDiags[0] } else { $script:rzFieldDiag = '(없음)'; $extractionProblems.Add("재개 필드 진단 문맥 $($fieldDiags.Count)개") }
    $overlayNext = @(Get-WorkerStringValues 'Stop-AbyssHandoffOverlay' '[완료] ' | Where-Object { $_.Contains('수동으로 마치지 말고') })
    $script:rzOverlayNext = @{
        menu      = @($overlayNext | Where-Object { $_.Contains('(menu-overlay)') }) -join ''
        detail    = @($overlayNext | Where-Object { $_.Contains('상세 화면') }) -join ''
        selection = @($overlayNext | Where-Object { $_.Contains('어비스 선택 화면입니다') }) -join ''
    }
    if (($overlayNext.Count -ne 3) -or (@($script:rzOverlayNext.Values | Where-Object { -not $_ }).Count -gt 0)) { $extractionProblems.Add("오버레이 정지 next 문구가 셋(선택 화면 · 메뉴 · 상세)이 아님 - $($overlayNext.Count)개") }
    $cancelLines = @(Get-WorkerStringValues 'Complete-AbyssOtherSelection' '[완료] ' | Where-Object { $_.Contains('재매칭이 취소돼') } | Sort-Object -Unique)
    if ($cancelLines.Count -eq 1) { $script:rzCancelStop = $cancelLines[0] } else { $script:rzCancelStop = '(없음)'; $extractionProblems.Add("재매칭 취소 끝 문구 $($cancelLines.Count)종") }
    $waiterFieldLines = @(Get-WorkerStringValues 'Wait-AbyssReentry' '[어비스] 던전 밖(HUD) 확인 - ')
    if ($waiterFieldLines.Count -eq 1) { $script:rzWaiterFieldPrefix = '[어비스] 던전 밖(HUD) 확인 - ' } else { $script:rzWaiterFieldPrefix = '(없음)'; $extractionProblems.Add("재입장 대기 필드 확정 줄 $($waiterFieldLines.Count)개") }
    $panelNotices = @(Get-WorkerStringValues 'Wait-AbyssReentry' '[어비스] 재매칭 패널 확인')
    if ($panelNotices.Count -eq 1) { $script:rzPanelNotice = $panelNotices[0] } else { $script:rzPanelNotice = '(없음)'; $extractionProblems.Add("재매칭 패널 확인 안내 $($panelNotices.Count)개") }
    $startLines = @(Get-WorkerStringValues 'Invoke-AbyssHandoffStart' '[어비스] 재입장 재개 시작 - ')
    if ($startLines.Count -eq 1) {
        $script:rzStartPattern = '^' + ([regex]::Escape($startLines[0]) -replace '\\\$\\\{resumeBudget}', '(?<budget>\d+)' -replace '\\\$\\\{resumeLeft}', '(?<left>[0-9.]+)' -replace '\\\$\\\{resumeStage}', '(?<stage>[a-z-]+)') + '$'
    } else { $script:rzStartPattern = '(없음)'; $extractionProblems.Add("재개 시작 줄 $($startLines.Count)개") }
    # ----- 5c-3 끝 문구 (재평가 · 재클릭 · 멈춤 끝 · 폴백 - 함수별로 잡아 본류의 같은 글자와 섞이지 않게) -----
    # 재개 판단 줄(사유 자리 품음) · 사유 글자(재개 끝 switch 절마다 키 → 첫 문자열 - 'time' 은 HH:mm 자리 원문 그대로)
    $judgeLines = @(Get-WorkerStringValues 'Complete-AbyssResumeWait' '[어비스] 재개 판단: ')
    if (($judgeLines.Count -eq 1) -and $judgeLines[0].Contains('${resumeCause}')) { $script:rzJudgeFormat = $judgeLines[0] } else { $script:rzJudgeFormat = '(없음)'; $extractionProblems.Add("재개 판단 줄이 사유 자리를 품은 하나가 아님 - $($judgeLines.Count)개") }
    $script:rzJudgeCauses = @{}
    $judgeWaitNode = Get-FlowFunctionNode 'Complete-AbyssResumeWait'
    $judgeSwitches = @($(if ($null -ne $judgeWaitNode) { $judgeWaitNode.FindAll({ param($node) $node -is [SwitchStatementAst] }, $true) }))
    if ($judgeSwitches.Count -eq 1) {
        foreach ($judgeClause in $judgeSwitches[0].Clauses) {
            $judgeValue = @(Get-StringNodes -Node $judgeClause.Item2) | Select-Object -First 1
            if ($null -ne $judgeValue) { $script:rzJudgeCauses[[string]$judgeClause.Item1.Value] = [string]$judgeValue.Value }
        }
    }
    if (($script:rzJudgeCauses.Count -ne 4) -or (-not ([string]$script:rzJudgeCauses['time']).Contains($RESUME_UNTIL_TOKEN))) {
        $extractionProblems.Add("재개 판단 사유 글자가 넷(time 은 HH:mm 자리 품음)이 아님 - switch $($judgeSwitches.Count)개 · 사유 $($script:rzJudgeCauses.Count)개")
    }
    # 클릭 자리 재검사 줄 둘(안전 중지 / 지정 시간 - 시간 줄만 HH:mm 자리)
    $clickLines = @(Get-WorkerStringValues 'Invoke-AbyssRetryClick' $RESUME_CLICK_PREFIX)
    $clickSafeLines = @($clickLines | Where-Object { -not $_.Contains($RESUME_UNTIL_TOKEN) })
    $clickTimeLines = @($clickLines | Where-Object { $_.Contains($RESUME_UNTIL_TOKEN) })
    if (($clickLines.Count -eq 2) -and ($clickSafeLines.Count -eq 1) -and ($clickTimeLines.Count -eq 1)) { $script:rzClickSafe = $clickSafeLines[0]; $script:rzClickTimeFormat = $clickTimeLines[0] }
    else { $script:rzClickSafe = '(없음)'; $script:rzClickTimeFormat = '(없음)'; $extractionProblems.Add("직전 판단 줄이 안전 중지 1 · 시간 1 이 아님 - $($clickLines.Count)개") }
    # 멈춤 끝 완료 줄
    $resumeStopLines = @(Get-WorkerStringValues 'Complete-AbyssResumeStop' '[완료] ')
    if ($resumeStopLines.Count -eq 1) { $script:rzResumeStopDone = $resumeStopLines[0] } else { $script:rzResumeStopDone = '(없음)'; $extractionProblems.Add("멈춤 끝 완료 줄 $($resumeStopLines.Count)개") }
    # 끝(retry) '두 번' · '한 번 더' 줄
    $retryEndLines = @(Get-WorkerStringValues 'Complete-AbyssRetrySelection' "[어비스] '다시 하기' ")
    $twiceLines = @($retryEndLines | Where-Object { $_.Contains('두 번') })
    $onceMoreLines = @($retryEndLines | Where-Object { $_.Contains('한 번 더') })
    if (($twiceLines.Count -eq 1) -and ($onceMoreLines.Count -eq 1)) { $script:rzTwiceLine = $twiceLines[0]; $script:rzOnceMoreLine = $onceMoreLines[0] }
    else { $script:rzTwiceLine = '(없음)'; $script:rzOnceMoreLine = '(없음)'; $extractionProblems.Add("끝(retry) '두 번' $($twiceLines.Count) · '한 번 더' $($onceMoreLines.Count) - 1씩이 아님") }
    # 끝(other) 완료 줄 둘(예약 없음 - 'confirmed' · 폴백 ② 두 곳이 같은 글자 / 예약 소비)
    $otherDoneLines = @(Get-WorkerStringValues 'Complete-AbyssOtherSelection' '[완료] ')
    $readyDoneLines = @($otherDoneLines | Where-Object { $_.Contains('선택 화면 복귀 완료') -and (-not $_.Contains('안전 중지')) } | Sort-Object -Unique)
    $readySafeLines = @($otherDoneLines | Where-Object { $_.Contains('안전 중지 예약 확인') })
    if (($readyDoneLines.Count -eq 1) -and ($readySafeLines.Count -eq 1)) { $script:rzReadyDone = $readyDoneLines[0]; $script:rzReadySafeDone = $readySafeLines[0] }
    else { $script:rzReadyDone = '(없음)'; $script:rzReadySafeDone = '(없음)'; $extractionProblems.Add("끝(other) 복귀 완료 줄 $($readyDoneLines.Count)종 · 예약 소비 줄 $($readySafeLines.Count)개 - 1씩이 아님") }
    # 'inside' 정지 줄(전송 있음 - 오클릭 의심) · 그 진단 문맥
    $otherInsideLines = @($otherDoneLines | Where-Object { $_.Contains('오클릭이 의심돼') })
    $otherInsideDiags = @(Get-DiagnosticContexts 'Complete-AbyssOtherSelection' | Where-Object { $_.Contains('대기 중 던전 안') })
    if (($otherInsideLines.Count -eq 1) -and ($otherInsideDiags.Count -eq 1)) { $script:rzOtherInsideStop = $otherInsideLines[0]; $script:rzOtherInsideDiag = $otherInsideDiags[0] }
    else { $script:rzOtherInsideStop = '(없음)'; $script:rzOtherInsideDiag = '(없음)'; $extractionProblems.Add("'다른 던전 가기' 대기 중 던전 안 정지 줄 $($otherInsideLines.Count) · 진단 $($otherInsideDiags.Count) - 1씩이 아님") }
    # 폴백 ② 사유 줄(사유 자리 품음) · 'no-pair' 사유 글자
    $fallbackLines = @(Get-WorkerStringValues 'Complete-AbyssOtherSelection' '[어비스] ${fallbackCause} ')
    $noPairCauses = @(Get-WorkerStringValues 'Complete-AbyssOtherSelection' "'다른 던전 가기' 글자를 찾지 못해")
    if (($fallbackLines.Count -eq 1) -and ($noPairCauses.Count -eq 1)) {
        $fallbackParts = $fallbackLines[0] -split [regex]::Escape('${fallbackCause}'), 2
        $script:rzFallbackPrefix = $fallbackParts[0]
        $script:rzFallbackSuffix = $fallbackParts[1]
        $script:rzFallbackNoPair = $fallbackLines[0].Replace('${fallbackCause}', $noPairCauses[0])
    } else { $script:rzFallbackPrefix = '(없음)'; $script:rzFallbackSuffix = '(없음)'; $script:rzFallbackNoPair = '(없음)'; $extractionProblems.Add("폴백 ② 사유 줄 $($fallbackLines.Count) · no-pair 사유 $($noPairCauses.Count) - 1씩이 아님") }
    # 기록 실패 [경고] · 짝 결측 첫 줄 둘(클릭 루프 · '다른 던전 가기' 대기 - 접두 원문 하나씩)
    $recordFailLines = @(Get-WorkerStringValues 'Complete-AbyssResumeWait' '[경고] 재입장 요청 기록을 저장하지 못해')
    if ($recordFailLines.Count -eq 1) { $script:rzRecordFailWarn = $recordFailLines[0] } else { $script:rzRecordFailWarn = '(없음)'; $extractionProblems.Add("재개 기록 실패 [경고] 줄 $($recordFailLines.Count)개") }
    $retryMissLines = @(Get-WorkerStringValues 'Invoke-AbyssRetryClick' $RESUME_RETRY_MISS_PREFIX)
    if ($retryMissLines.Count -ne 1) { $extractionProblems.Add("클릭 루프 짝 결측 첫 줄 $($retryMissLines.Count)개") }
    $otherMissLines = @(Get-WorkerStringValues 'Wait-AbyssOtherSelection' $RESUME_OTHER_MISS_PREFIX)
    if ($otherMissLines.Count -ne 1) { $extractionProblems.Add("'다른 던전 가기' 대기 짝 결측 첫 줄 $($otherMissLines.Count)개") }
    # 지정 시각 문장(2.1 블록 앞 최상위 하나 - env 길 행이 점소싱)
    $untilStatements = @($mainStatements | Where-Object { ($_ -is [IfStatementAst]) -and (@($_.FindAll({ param($node) ($node -is [AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$script:abyssUntil') }, $true)).Count -gt 0) })
    if ($untilStatements.Count -eq 1) { $script:untilBlock = [scriptblock]::Create($untilStatements[0].Extent.Text) } else { $script:untilBlock = $null; $extractionProblems.Add("지정 시각 읽기 문장 $($untilStatements.Count)개") }
    # 선분기 회전 대기 - 첫 while 끝 문장 Start-Sleep -Milliseconds 인자(④ 의 기본 대기 캡처와 같은 AST 자리)
    $script:selectorWaitMs = $null
    $selectorFirstWhile = @((Get-FlowFunctionNode 'Invoke-AbyssHandoffStart').Body.EndBlock.Statements | Where-Object { $_ -is [WhileStatementAst] }) | Select-Object -First 1
    if ($null -ne $selectorFirstWhile) {
        $selectorLastSleep = @(@($selectorFirstWhile.Body.Statements)[-1].FindAll({ param($node) ($node -is [CommandAst]) -and ($node.GetCommandName() -eq 'Start-Sleep') }, $true)) | Select-Object -First 1
        if ($null -ne $selectorLastSleep) {
            $sleepElements = @($selectorLastSleep.CommandElements)
            for ($sleepIndex = 1; $sleepIndex -lt ($sleepElements.Count - 1); $sleepIndex++) {
                if (($sleepElements[$sleepIndex] -is [CommandParameterAst]) -and ($sleepElements[$sleepIndex].ParameterName -eq 'Milliseconds') -and ($sleepElements[$sleepIndex + 1] -is [ConstantExpressionAst])) {
                    $script:selectorWaitMs = [int]$sleepElements[$sleepIndex + 1].Value
                }
            }
        }
    }
    if ($null -eq $script:selectorWaitMs) { $extractionProblems.Add('선분기 첫 while 끝 문장의 Start-Sleep -Milliseconds 값을 찾지 못했습니다') }
}

function New-ResumeFixtureEntry {
    # 재개 항목 NC - stage · retryClicks · at.retryClicked · at.retryAttempt(행 시작 가상 시각 기준 '초 전' - 빈 값이면 null 그대로). 커스텀 = 이번 owner(5필드 index 0 · 세대 3 -
    #   New-ChOwnEntry) / 비커스텀 = { runId } (⑱′ next 비커스텀 꼴). 시각 글자는 저장소와 같은 'o' 꼴
    param([bool]$Custom, [string]$Stage, [int]$RetryClicks, $AtClicked, $AtAttempt, [int]$Attempts = 0)
    if ($Custom) { $fixtureEntry = New-ChOwnEntry -Nonce $NONCE_C -Stage $Stage }
    else { $fixtureEntry = New-FixtureEntry -Stage $Stage -Nonce $NONCE_C -Owner ([pscustomobject]@{ runId = $CH_RUN_ID }) -RunId $CH_RUN_ID -LaunchState 'launched' }
    $fixtureEntry.retryClicks = $RetryClicks
    $fixtureEntry.attempts = $Attempts   # 첫 시도 수 시작값(기본 0 - 운영의 retry-* 항목은 1 이상이라 '+1' 을 가르는 RCK1 · RCK2 는 1 로 시작 · 구현 사전 대조 지적)
    if ($null -ne $AtClicked) { $fixtureEntry.at.retryClicked = $VIRTUAL_BASE.AddSeconds(-[double]$AtClicked).ToString('o') }
    if ($null -ne $AtAttempt) { $fixtureEntry.at.retryAttempt = $VIRTUAL_BASE.AddSeconds(-[double]$AtAttempt).ToString('o') }
    return $fixtureEntry
}

function Get-ResumeEntryState {
    # 행 끝 재개 항목 NC 의 stage · attempts · retryClicks · at.retryClicked (파일 · 항목이 없으면 '(없음)')
    $entryState = @{ Stage = '(없음)'; Attempts = -1; RetryClicks = -1; AtRetryClicked = '(없음)' }
    if (-not [IO.File]::Exists($script:abyssJournalPath)) { return $entryState }
    try {
        $journalDoc = [IO.File]::ReadAllText($script:abyssJournalPath) | ConvertFrom-Json
        foreach ($journalEntry in @($journalDoc.entries)) {
            if ([string]$journalEntry.nonce -ne $NONCE_C) { continue }
            $entryState.Stage = [string]$journalEntry.stage
            $entryState.Attempts = [int]$journalEntry.attempts
            $entryState.RetryClicks = [int]$journalEntry.retryClicks
            $entryState.AtRetryClicked = [string]$journalEntry.at.retryClicked
        }
    } catch {
        $entryState.Stage = '(읽기 실패: ' + $_.Exception.Message + ')'
    }
    return $entryState
}

function Invoke-ResumeRow {
    # 재개 워커 한 행 (구현 명세 ⑤c 3.3 '행 준비' - ⑱′ Invoke-FlowRow 'selector' 꼴): 행 폴더 · 재개 항목 NC 픽스처 · RESUME=1 → 시나리오 → 행 값 → 층 ①(2.1 블록 ~
    #   $roleNone 대입) 점소싱 → 결과. 행 값은 이 함수 범위 지역 변수 · 스크립트 상태로 둡니다(점소싱한 구간이 부른 워커 함수에 동적 범위로 보임 - Tpm 덮기와 같은 방식).
    #   키: Name · Mode('solo' | 'party' - 기본 우연한 만남 party) · Custom · Stage(기본 retry-clicked) · RetryClicks · Attempts(첫 시도 수 시작값 - 기본 0) · AtClicked · AtAttempt(초 전) ·
    #   Until(숫자 = 행 시작 가상 시각 + 초를 $script:abyssUntil 에 / 글자 = HONEYNOGI_UNTIL_TIME 값으로 실제 지정 시각 읽기 문장을 점소싱) · LastRun ·
    #   FinishOnly(마무리 실행 표지 env 값 - 행 준비가 워커 읽기 문장으로 $script:finishOnly 를 정함 · 빈 값이면 env 를 지워 앞 행 값이 새지 않음 - DV7) · Scenario.
    #   매개변수 이름은 resume 접두 - 점소싱한 워커 문장이 같은 이름($row 등)을 쓰면 섞이므로(⑱′ Invoke-FlowRow 의 flow 접두와 같은 이유)
    param([hashtable]$ResumeRow)
    $rowStage = 'retry-clicked'
    if ($ResumeRow.ContainsKey('Stage')) { $rowStage = [string]$ResumeRow.Stage }
    $rowEntry = New-ResumeFixtureEntry -Custom ([bool]$ResumeRow.Custom) -Stage $rowStage -RetryClicks ([int]$ResumeRow.RetryClicks) -AtClicked $ResumeRow.AtClicked -AtAttempt $ResumeRow.AtAttempt `
        -Attempts ([int]$ResumeRow.Attempts)
    Initialize-HandoffRow -Row @{ Name = [string]$ResumeRow.Name; Custom = [bool]$ResumeRow.Custom; Nonce = $NONCE_C; Resume = '1'; Entries = @($rowEntry); FinishOnly = [string]$ResumeRow.FinishOnly }
    $rowScenario = @{}
    if ($ResumeRow.ContainsKey('Scenario')) { $rowScenario = $ResumeRow.Scenario }
    Set-Scenario -Scenario $rowScenario
    $contentCategory = 'abyss'
    $game = $null
    $deepMode = $false
    $timeoutPartyMatch = $capturedTimeoutPartyMatch
    $dungeonMode = 'party'
    if ($ResumeRow.ContainsKey('Mode')) { $dungeonMode = [string]$ResumeRow.Mode }
    $script:dgLastRun = [bool]$ResumeRow.LastRun
    Set-ProcessEnv -Name 'HONEYNOGI_UNTIL_TIME' -Value ''
    if ($ResumeRow.ContainsKey('Until')) {
        if ($ResumeRow.Until -is [string]) {
            Set-ProcessEnv -Name 'HONEYNOGI_UNTIL_TIME' -Value ([string]$ResumeRow.Until)
            . $script:untilBlock
        } else {
            $script:abyssUntil = $VIRTUAL_BASE.AddSeconds([double]$ResumeRow.Until)
        }
    }
    $roleNone = '(미대입)'
    $flowExitCode = ''
    $flowThrown = ''
    try {
        [void]@(. $script:mainSegmentBlock)
    } catch {
        $flowMessage = [string]$_.Exception.Message
        if ($flowMessage.StartsWith($WORKER_EXIT_PREFIX)) { $flowExitCode = $flowMessage.Substring($WORKER_EXIT_PREFIX.Length) } else { $flowThrown = $flowMessage }
    } finally {
        Close-HeldStreams
    }
    $resumeResult = New-FlowResult -ExitCode $flowExitCode -Thrown $flowThrown -RoleNone ([string]$roleNone) -StartInside '(층 ① - 해당 없음)' -Layer 'selector'
    $entryState = Get-ResumeEntryState
    $resumeResult | Add-Member -NotePropertyName ReentryResults -NotePropertyValue @($script:resumeReentryCalls)
    $resumeResult | Add-Member -NotePropertyName VerdictCalls -NotePropertyValue ('{0}/{1}' -f $script:resumeUpdateCalls, $script:resumeDgCalls)
    $resumeResult | Add-Member -NotePropertyName VerdictAt -NotePropertyValue $script:resumeVerdictAt
    $resumeResult | Add-Member -NotePropertyName ClockCalls -NotePropertyValue $script:resumeClockCalls
    $resumeResult | Add-Member -NotePropertyName OtherEnds -NotePropertyValue ((@($script:resumeOtherEnds | ForEach-Object { '{0}/{1}' -f $_.Ending, (Get-NonceLabel $_.Nonce) })) -join ',')
    $resumeResult | Add-Member -NotePropertyName RetrySends -NotePropertyValue @($script:resumeSends | Where-Object { $_.Kind -eq 'retry' }).Count
    $resumeResult | Add-Member -NotePropertyName OtherSends -NotePropertyValue @($script:resumeSends | Where-Object { $_.Kind -eq 'other' }).Count
    $resumeResult | Add-Member -NotePropertyName ReturnCalls -NotePropertyValue ((@($script:resumeReturnCalls | ForEach-Object { '{0}|{1}|{2}' -f $_.Code, $_.Reason, $_.Flag })) -join ',')
    $resumeResult | Add-Member -NotePropertyName HelperTimes -NotePropertyValue @($script:resumeHelperTimes)
    $resumeResult | Add-Member -NotePropertyName Stage -NotePropertyValue $entryState.Stage
    $resumeResult | Add-Member -NotePropertyName Attempts -NotePropertyValue $entryState.Attempts
    $resumeResult | Add-Member -NotePropertyName RetryClicks -NotePropertyValue $entryState.RetryClicks
    $resumeResult | Add-Member -NotePropertyName AtRetryClicked -NotePropertyValue $entryState.AtRetryClicked
    # 5c-3 - 행 끝 판단값(TimeVerdict - $null 은 '(null)' 로 '' 와 가름: RS8 · RS9 · RS9′ · RE-5) · commit 표지(Committed - $null 은 '(null)': RS3 · RS9 · WA-D4 (다-2)) ·
    #   retry 전송 가상 초들(RCK1 '갱신' · WA-D6 둘째 마감 기준)
    $resumeResult | Add-Member -NotePropertyName TimeVerdict -NotePropertyValue $(if ($null -eq $script:abyssRetryTimeVerdict) { '(null)' } else { [string]$script:abyssRetryTimeVerdict })
    $resumeResult | Add-Member -NotePropertyName Committed -NotePropertyValue $(if ($null -eq $script:abyssRetryCommitted) { '(null)' } else { [string][bool]$script:abyssRetryCommitted })
    $resumeResult | Add-Member -NotePropertyName RetrySendTimes -NotePropertyValue @($script:resumeSends | Where-Object { $_.Kind -eq 'retry' } | ForEach-Object { [double]$_.T })
    return $resumeResult
}

function Get-ResumeCommonText {
    # 공통 단언 값(구현 명세 ⑤c 3.0): 'post-clear-stop' 0(로그 · 항목 stage) · ' (post-clear)' 0 · ' (start-unknown)' 0 · 이벤트 정리 0 · 키 입력 0 · 예외 · StartScreen · exit 있음
    param($Result)
    $allLines = @($Result.Lines)
    $postClearStop = @($allLines | Where-Object { $_.Contains('post-clear-stop') }).Count + [int]([string]$Result.Stage -eq 'post-clear-stop')
    $postClearTail = @($allLines | Where-Object { $_.Contains(' (post-clear)') }).Count
    $startUnknown = @($allLines | Where-Object { $_.Contains(' (start-unknown)') }).Count
    $keyInputs = @(@(([string]$Result.InputList) -split ' / ') | Where-Object { $_.StartsWith('Press-Key') }).Count
    return ('post-clear-stop {0} · post-clear {1} · start-unknown {2} · 이벤트 정리 {3} · 키 {4} · 예외 [{5}] · StartScreen [{6}] · exit 있음 {7}' -f $postClearStop, $postClearTail,
        $startUnknown, @($Result.Overlays).Count, $keyInputs, $Result.Thrown, $Result.StartScreen, ([string]$Result.ExitCode -ne ''))
}

function Assert-ResumeCommon {
    param([string]$Name, $Result)
    Assert-Case ($Name + ' 공통(구현 명세 ⑤c 3.0)') (Get-ResumeCommonText $Result) $RESUME_COMMON_WANT
}

function Get-ReentryText {
    # 재입장 대기 호출 결과들 - ','
    param($Result)
    return ((@($Result.ReentryResults | ForEach-Object { [string]$_.Result })) -join ',')
}

function Test-NearTime {
    # 끝 시각이 마감 무렵인지(마감 이상 · 한 박자 + 판독 여유 안) - 'True' / 'False'
    param([double]$Actual, [double]$Deadline, [double]$Slack = 1.5)
    return [string](($Actual -ge ($Deadline - $TIME_EPSILON)) -and ($Actual -lt ($Deadline + $Slack)))
}

function Get-ResumeEndIH {
    # 끝-IH 관측: 재개 항목 stage · 재입장 완료 줄(nonce = 받은 NC) 수 · [완료] 줄 수 · exit
    param($Result)
    return ('stage {0} · 재입장 완료 줄 {1} · [완료] 줄 {2} · exit {3}' -f $Result.Stage, (Get-LineCount -Result $Result -Line $script:rzIhLine),
        @(@($Result.Lines) | Where-Object { $_.StartsWith('[완료]') }).Count, $Result.ExitCode)
}
function Get-ResumeEndIHWant { param([string]$Code) return ('stage reentered · 재입장 완료 줄 1 · [완료] 줄 1 · exit {0}' -f $Code) }

function Get-ResumeEndNone {
    # 끝-none 관측: 정지 줄 · 진단 · 입력 · exit
    param($Result)
    return ('정지 줄 [{0}] · 진단 [{1}] · 입력 {2} · exit {3}' -f (Get-StopLines $Result), (Get-DiagText $Result), $Result.Inputs, $Result.ExitCode)
}
function Get-ResumeEndNoneWant {
    # -Inputs = 그 행 입력 수(재클릭 뒤 시간 초과 행 WA-D6 은 재클릭 회전의 Focus-Game · Click-GamePoint 둘 - 그 밖은 0)
    param([string]$Mode = 'party', [int]$Inputs = 0)
    $noneLine = $(if ($Mode -eq 'solo') { $script:rzNoneSolo } else { $script:rzNoneParty })
    return ('정지 줄 [{0}] · 진단 [{1}] · 입력 {2} · exit 4' -f $noneLine, $script:rzNoneDiag, $Inputs)
}

function Get-ResumeEndField {
    # 끝-필드 관측: 선분기 필드 확정 줄 수 · 정지 줄 · 진단 · 입력 · exit
    param($Result)
    return ('필드 확정 줄 {0} · 정지 줄 [{1}] · 진단 [{2}] · 입력 {3} · exit {4}' -f @(Get-PatternLines -Result $Result -Pattern $S3_PATTERN).Count, (Get-StopLines $Result),
        (Get-DiagText $Result), $Result.Inputs, $Result.ExitCode)
}
function Get-ResumeEndFieldWant { return ('필드 확정 줄 1 · 정지 줄 [{0}] · 진단 [{1}] · 입력 0 · exit 4' -f $script:rzFieldStop, $script:rzFieldDiag) }

function Get-ResumeEndHold {
    # 끝-보류 관측: 정지 줄 · 진단 · 입력 · 파일 불변 · exit
    param($Result)
    return ('정지 줄 [{0}] · 진단 [{1}] · 입력 {2} · 파일 불변 {3} · exit {4}' -f (Get-StopLines $Result), (Get-DiagText $Result), $Result.Inputs, $Result.Unchanged, $Result.ExitCode)
}
function Get-ResumeEndHoldWant {
    param([string]$Kind)
    $holdDiag = $(if ($Kind -eq 'menu') { $DIAG_MENU } elseif ($Kind -eq 'detail') { $DIAG_DETAIL } else { $DIAG_SELECTION })
    return ('정지 줄 [{0}] · 진단 [{1}] · 입력 0 · 파일 불변 True · exit 4' -f $script:rzOverlayNext[$Kind], $holdDiag)
}

function Get-ResumeEndCancel {
    # 끝-취소 관측: 끝(other) -Ending · -Nonce · 재클릭 0 · 정지 줄 · exit
    param($Result)
    return ('끝(other) [{0}] · retry 전송 {1} · 정지 줄 [{2}] · exit {3}' -f $Result.OtherEnds, $Result.RetrySends, (Get-StopLines $Result), $Result.ExitCode)
}
function Get-ResumeEndCancelWant { return ('끝(other) [rematch-cancelled/NC] · retry 전송 0 · 정지 줄 [{0}] · exit 4' -f $script:rzCancelStop) }

function Get-ResumeEndFieldCancel {
    # 끝-필드취소 관측: 대기 함수 필드 확정 줄 수 · 정지 줄 · 입력 · exit
    param($Result)
    $waiterFieldCount = @(@($Result.Lines) | Where-Object { $_.StartsWith($script:rzWaiterFieldPrefix, [StringComparison]::Ordinal) }).Count
    return ('대기 필드 확정 줄 {0} · 정지 줄 [{1}] · 입력 {2} · exit {3}' -f $waiterFieldCount, (Get-StopLines $Result), $Result.Inputs, $Result.ExitCode)
}
function Get-ResumeEndFieldCancelWant {
    # -Inputs = 그 행 입력 수(호출 D 의 필드 취소 RF4 는 재클릭 회전의 둘 - 그 밖은 0)
    param([int]$Inputs = 0)
    return ('대기 필드 확정 줄 1 · 정지 줄 [{0}] · 입력 {1} · exit 4' -f $script:rzFieldCancel, $Inputs)
}

function Get-ResumeJudgeLine {
    # 재개 판단 줄 기대 - 사유 키(safe-stop · finish-only · last-run · time)의 소스 사유 글자를 사유 자리에. time 은 HH:mm 자리를 행 지정 시각(행 시작 + 초)으로 채움
    param([string]$Reason, [double]$UntilSeconds = 0)
    $causeText = [string]$script:rzJudgeCauses[$Reason]
    if ($Reason -eq 'time') { $causeText = $causeText.Replace($RESUME_UNTIL_TOKEN, $VIRTUAL_BASE.AddSeconds($UntilSeconds).ToString('HH:mm')) }
    return $script:rzJudgeFormat.Replace('${resumeCause}', $causeText)
}

function Get-ResumeClickLine {
    # 직전 판단 줄 기대 - 'safe' = 안전 중지 줄 그대로 / 'time' = 시간 줄의 HH:mm 자리를 행 지정 시각으로
    param([string]$Kind, [double]$UntilSeconds = 0)
    if ($Kind -eq 'safe') { return $script:rzClickSafe }
    return $script:rzClickTimeFormat.Replace($RESUME_UNTIL_TOKEN, $VIRTUAL_BASE.AddSeconds($UntilSeconds).ToString('HH:mm'))
}

function Get-ResumeEndStop {
    # 끝-멈춤 관측(구현 명세 ⑤c 2.11 - 헬퍼 → 복귀(코드 0) → 완료 줄 → exit 0): 재개 판단 줄 · 직전 판단 줄(각 ' || ') · 전송 retry/other · 끝(other) 호출 · 헬퍼 · 복귀 호출 · 정지 줄 · exit.
    #   끝(other) 칸 - 멈춤 끝은 끝(other) 를 부르지 않습니다. 이 칸이 없으면 '끝(other) -ExitOnly + 헬퍼 clicked'(맥락 A)가 대기 0 · 사유 줄 0 · 헬퍼 1 · 복귀 코드 0 ·
    #   같은 완료 줄 · exit 0 으로 모든 칸이 같아 행이 가르지 못합니다(구현 사전 대조 지적)
    param($Result)
    $judgePrefix = ($script:rzJudgeFormat -split [regex]::Escape('${resumeCause}'), 2)[0]
    $judgeText = (@(@($Result.Lines) | Where-Object { $_.StartsWith($judgePrefix, [StringComparison]::Ordinal) }) -join ' || ')
    $clickText = (@(@($Result.Lines) | Where-Object { $_.StartsWith($RESUME_CLICK_PREFIX, [StringComparison]::Ordinal) }) -join ' || ')
    return ('재개 판단 [{0}] · 직전 판단 [{1}] · 전송 {2}/{3} · 끝(other) [{4}] · 헬퍼 {5} · 복귀 [{6}] · 정지 줄 [{7}] · exit {8}' -f $judgeText, $clickText, $Result.RetrySends, $Result.OtherSends,
        $Result.OtherEnds, $Result.ExitClicks, $Result.ReturnCalls, (Get-StopLines $Result), $Result.ExitCode)
}
function Get-ResumeEndStopWant {
    # -Flag = 복귀 호출 순간 안전 중지 예약 파일 있음(복귀 모의가 넘긴 코드 0 으로 exit - 완료 줄 없음) / 없음(돌아와 완료 줄)
    param([string]$JudgeLine = '', [string]$ClickLine = '', [bool]$Flag = $false)
    return ('재개 판단 [{0}] · 직전 판단 [{1}] · 전송 0/0 · 끝(other) [] · 헬퍼 1 · 복귀 [0||{2}] · 정지 줄 [{3}] · exit 0' -f $JudgeLine, $ClickLine, $Flag, $(if ($Flag) { '' } else { $script:rzResumeStopDone }))
}

function Get-ResumeEndReady {
    # 끝-확인 관측(폴백 ① 'confirmed'): '두 번' 줄 수 · 끝(other) · 다른 던전 전송 · 헬퍼 · 복귀 호출 · 정지 줄 · exit
    param($Result)
    return ('두 번 줄 {0} · 끝(other) [{1}] · 다른 던전 전송 {2} · 헬퍼 {3} · 복귀 [{4}] · 정지 줄 [{5}] · exit {6}' -f (Get-LineCount -Result $Result -Line $script:rzTwiceLine),
        $Result.OtherEnds, $Result.OtherSends, $Result.ExitClicks, $Result.ReturnCalls, (Get-StopLines $Result), $Result.ExitCode)
}
function Get-ResumeEndReadyWant {
    # -Flag = 안전 중지 예약을 'confirmed' 가 소비(예약 소비 완료 줄) / 없음(복귀 완료 줄)
    param([bool]$Flag = $false)
    return ('두 번 줄 1 · 끝(other) [ready/NC] · 다른 던전 전송 1 · 헬퍼 0 · 복귀 [] · 정지 줄 [{0}] · exit 0' -f $(if ($Flag) { $script:rzReadySafeDone } else { $script:rzReadyDone }))
}

function Get-ResumeFallbackLines {
    # 폴백 ② 사유 줄(사유 무관 - 접두 · 끝 조각으로) 수
    param($Result)
    return @(@($Result.Lines) | Where-Object { $_.StartsWith($script:rzFallbackPrefix, [StringComparison]::Ordinal) -and $_.EndsWith($script:rzFallbackSuffix, [StringComparison]::Ordinal) }).Count
}

function Get-ResumePrefixCount {
    # 접두로 시작하는 로그 줄 수
    param($Result, [string]$Prefix)
    return @(@($Result.Lines) | Where-Object { $_.StartsWith($Prefix, [StringComparison]::Ordinal) }).Count
}

function Get-ResumeVerdictAt {
    # 경계 T 보정(구현 명세 ⑤c 3.3 - 같은 입력을 지정 시각 · 예약 없이 한 번 돌려 잰 첫 재판단 가상 초 - 재평가 시각을 숫자로 박지 않음). 행 해시를 얕게 복제해
    #   Until 과 Scenario 의 FlagAt 만 뺍니다(시각표 배열은 Set-Scenario · 전이 삽입이 새 배열을 만들어 원본이 바뀌지 않음). 보정 행 자체는 단언하지 않습니다
    param([hashtable]$ResumeRow)
    $calibrationRow = @{}
    foreach ($rowKey in @($ResumeRow.Keys)) { if ($rowKey -ne 'Until') { $calibrationRow[$rowKey] = $ResumeRow[$rowKey] } }
    $calibrationRow['Name'] = [string]$ResumeRow.Name + ' 보정'
    if ($ResumeRow.ContainsKey('Scenario')) {
        $calibrationScenario = @{}
        foreach ($scenarioKey in @($ResumeRow.Scenario.Keys)) { if ($scenarioKey -ne 'FlagAt') { $calibrationScenario[$scenarioKey] = $ResumeRow.Scenario[$scenarioKey] } }
        $calibrationRow['Scenario'] = $calibrationScenario
    }
    return (Invoke-ResumeRow $calibrationRow).VerdictAt
}

function Get-StartBudget {
    # 재개 시작 줄의 '입장 대기 B초' (없으면 -1)
    param($Result)
    foreach ($startLine in @($Result.Lines)) {
        $startMatch = [regex]::Match($startLine, $script:rzStartPattern)
        if ($startMatch.Success) { return [int]$startMatch.Groups['budget'].Value }
    }
    return -1
}

# ----- A. 시계 · 유예 ('reclick' 칸은 아래 A 'reclick' 묶음) -----
function Test-ResumeRowsA {
    $Tpm = [int]$capturedTimeoutPartyMatch
    $T45 = [int]$timeoutEntry
    $PAST = $Tpm + 60
    $W = [double]$memberFieldSettleSeconds
    $waitSeconds = [double]$script:selectorWaitMs / 1000
    $mTimeline = @(New-Timeline -Pairs @(0, 'matching'))

    # WA-D1 - retry-clicked · 40초 전 · M 지속 → 호출 C(재개 시계 그 객체 · 유예 켬) · 'timeout' @(Tpm−40) · 끝-none
    $r = Invoke-ResumeRow @{ Name = 'WA-D1'; AtClicked = 40; Scenario = @{ Timeline = $mTimeline } }
    Assert-ResumeCommon 'WA-D1' $r
    Assert-Case 'WA-D1 retry-clicked · 40초 전 · M 지속 → 호출 C 1(재개 시계 같은 객체) · timeout · 끝-none · 끝 = Tpm−40 무렵' `
        (J @((Get-ReentryText $r), (@($r.ReentryResults | ForEach-Object { $_.ClockResume }) -join ','), (Get-ResumeEndNone $r), (Test-NearTime $r.EndT ($Tpm - 40)))) `
        (J @('timeout', 'True', (Get-ResumeEndNoneWant 'party'), 'True'))

    # WA-D2 - retryClicked 빈 값 · retryAttempt 10초 전 → 기준 = retryAttempt · @(Tpm−10)
    $r = Invoke-ResumeRow @{ Name = 'WA-D2'; Stage = 'retry-attempt'; AtAttempt = 10; Scenario = @{ Timeline = $mTimeline } }
    Assert-ResumeCommon 'WA-D2' $r
    Assert-Case 'WA-D2 retryClicked 빈 값 · retryAttempt 10초 전 · M 지속 → timeout · 끝-none · 끝 = Tpm−10 무렵' `
        (J @((Get-ReentryText $r), (Get-ResumeEndNone $r), (Test-NearTime $r.EndT ($Tpm - 10)))) (J @('timeout', (Get-ResumeEndNoneWant 'party'), 'True'))

    # WA-D3 - 둘 다 빈 값 → 기준 = 지금 · @Tpm · 새 [경고] 0
    $r = Invoke-ResumeRow @{ Name = 'WA-D3'; Stage = 'retry-attempt'; Scenario = @{ Timeline = $mTimeline } }
    Assert-ResumeCommon 'WA-D3' $r
    Assert-Case 'WA-D3 at 두 칸 빈 값 · M 지속 → timeout · 끝-none · 끝 = Tpm 무렵 · [경고] 줄 0' `
        (J @((Get-ReentryText $r), (Get-ResumeEndNone $r), (Test-NearTime $r.EndT $Tpm), @(@($r.Lines) | Where-Object { $_.StartsWith('[경고]') }).Count)) (J @('timeout', (Get-ResumeEndNoneWant 'party'), 'True', 0))

    # WA-D4 (가) - 지난 시계 · I 지속 → 던전 안 첫 유예로 2연속 · 끝-IH · 재입장 대기 0
    $r = Invoke-ResumeRow @{ Name = 'WA-D4 (가)'; AtClicked = $PAST; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'I')) } }
    Assert-ResumeCommon 'WA-D4 (가)' $r
    Assert-Case 'WA-D4 (가) 지난 시계 · I 지속 → 끝-IH(코드 0 - 지정 시각 없음) · 재입장 대기 0' (J @((Get-ResumeEndIH $r), (Get-ReentryText $r))) (J @((Get-ResumeEndIHWant '0'), ''))

    # WA-D4 (라) - 지난 시계 · F 지속 → 첫 유효 회전 'timeout' · 끝-none · 필드 확정 줄 0 · 끝 < W
    $r = Invoke-ResumeRow @{ Name = 'WA-D4 (라)'; AtClicked = $PAST; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'F')) } }
    Assert-ResumeCommon 'WA-D4 (라)' $r
    Assert-Case 'WA-D4 (라) 지난 시계 · F 지속 → 첫 유효 회전 timeout(끝 < 선분기 회전 대기) · 끝-none · 선분기 필드 확정 줄 0 · 끝 < W' `
        (J @((Get-ResumeEndNone $r), @(Get-PatternLines -Result $r -Pattern $S3_PATTERN).Count, ($r.EndT -lt $W), ($r.EndT -lt $waitSeconds))) (J @((Get-ResumeEndNoneWant 'party'), 0, 'True', 'True'))

    # WA-D4 (마) - 지난 시계 · Sel → 끝-보류 (selection-overlay) · 재입장 대기 0
    $r = Invoke-ResumeRow @{ Name = 'WA-D4 (마)'; AtClicked = $PAST; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'SEL')) } }
    Assert-ResumeCommon 'WA-D4 (마)' $r
    Assert-Case 'WA-D4 (마) 지난 시계 · 선택 화면 → 끝-보류(선택 화면 next 문구) · 재입장 대기 0' (J @((Get-ResumeEndHold $r), (Get-ReentryText $r))) (J @((Get-ResumeEndHoldWant 'selection'), ''))

    # WA-D4 (바) - 지난 시계 · M → 호출 C 첫 유효 회전 'timeout' · 끝-none
    $r = Invoke-ResumeRow @{ Name = 'WA-D4 (바)'; AtClicked = $PAST; Scenario = @{ Timeline = $mTimeline } }
    Assert-ResumeCommon 'WA-D4 (바)' $r
    Assert-Case 'WA-D4 (바) 지난 시계 · M → 호출 C 의 첫 유효 회전에 timeout · 끝-none · 끝 < 선분기 회전 대기' `
        (J @((Get-ReentryText $r), (Get-ResumeEndNone $r), ($r.EndT -lt $waitSeconds))) (J @('timeout', (Get-ResumeEndNoneWant 'party'), 'True'))

    # WA-D5 - 혼자하기 / 우연한 만남 · 같은 입력(WA-D1) → B = T45 / Tpm (시작 줄 예산 · 마감 · 모드 문구)
    foreach ($d5Mode in @('solo', 'party')) {
        $d5Budget = $(if ($d5Mode -eq 'solo') { $T45 } else { $Tpm })
        $r = Invoke-ResumeRow @{ Name = "WA-D5 $d5Mode"; Mode = $d5Mode; AtClicked = 40; Scenario = @{ Timeline = $mTimeline } }
        Assert-ResumeCommon "WA-D5 $d5Mode" $r
        Assert-Case "WA-D5 $d5Mode · 40초 전 · M 지속 → 재개 시작 줄 예산 = 모드 예산($d5Budget) · 끝 = 예산−40 무렵 · 끝-none(모드 문구)" `
            (J @((Get-StartBudget $r), (Test-NearTime $r.EndT ($d5Budget - 40)), (Get-ResumeEndNone $r))) (J @($d5Budget, 'True', (Get-ResumeEndNoneWant $d5Mode)))
    }

    # WA-D7 - 조작 20 + 캡처 실패 30 → 마감 = Tpm−40 + 양보 + 실패(조정 - 재개 시계가 이 워커의 차분을 더함)
    $r = Invoke-ResumeRow @{ Name = 'WA-D7'; AtClicked = 40; Scenario = @{ Timeline = $mTimeline; Active = @(New-Windows -Pairs @(50.0, 70.0)); CapFail = @(New-Windows -Pairs @(100.0, 130.0)) } }
    Assert-ResumeCommon 'WA-D7' $r
    $d7Deadline = ($Tpm - 40) + ($r.YieldTotalMs / 1000) + ($r.FailTotalMs / 1000)
    Assert-True 'WA-D7 40초 전 · M · 조작 @50~70 · 캡처 실패 @100~130 → timeout · 끝-none · 끝 = Tpm−40 + 양보 + 실패 무렵 · 양보 ≥ 19초 · 실패 ≥ 29초' `
        (((Get-ReentryText $r) -ceq 'timeout') -and ((Get-ResumeEndNone $r) -ceq (Get-ResumeEndNoneWant 'party')) -and ((Test-NearTime $r.EndT $d7Deadline 3) -eq 'True') -and
            ($r.YieldTotalMs -ge 19000) -and ($r.FailTotalMs -ge 29000)) `
        ('결과 [{0}] · 끝 {1} · 조정 마감 {2} · 양보 {3} · 실패 {4} · [{5}]' -f (Get-ReentryText $r), (Format-Seconds $r.EndT), (Format-Seconds $d7Deadline), $r.YieldTotalMs, $r.FailTotalMs, (Get-ResumeEndNone $r))
}

# ----- A 'reclick' 칸 (5c-3 - 호출 C 가 Q 무변화 뒤 'reclick' 을 낸 뒤의 승계 재클릭 · 재평가 · 멈춤 끝 · 둘째 마감) -----
function Test-ResumeRowsAReclick {
    $Tpm = [int]$capturedTimeoutPartyMatch
    $T45 = [int]$timeoutEntry
    $PAST = $Tpm + 60
    $Q = [double]$abyssReclickQuietSeconds
    $r3Timeline = @(New-Timeline -Pairs @(0, 'R3'))
    $reenterSend = @{ 1 = @(@(1, 'U'), @(4, 'I')) }   # 재클릭 뒤 재입장(구현 명세 ⑤c 3.5 클릭 입력 표 - ④ $RETRY_ENTER 꼴)
    $continueCount = { param($Result) @(@($Result.Lines) | Where-Object { $_.StartsWith($script:rzContinuePrefix, [StringComparison]::Ordinal) }).Count }
    $quietText = { param($Call, [double]$Quiet) if ($null -eq $Call) { '(호출 없음)' } else { [string](([double]$Call.ReturnT - [double]$Call.T) -ge ($Quiet - $TIME_EPSILON)) } }

    # WA-D4 (나) - 지난 시계 · R3 지속 · retry-clicked · 시작값 1 → Q 뒤 'reclick'(그 전 회전은 3버튼 유예) → 승계(재판단 0) → 재클릭 1(판당 상한 2) → 호출 D 'reclick' → 폴백 ① 'confirmed'
    $r = Invoke-ResumeRow @{ Name = 'WA-D4 (나)'; AtClicked = $PAST; RetryClicks = 1; Scenario = @{ Timeline = $r3Timeline } }
    Assert-ResumeCommon 'WA-D4 (나)' $r
    Assert-Case 'WA-D4 (나) 지난 시계 · R3 지속 · retry-clicked · 시작값 1 → 호출 C reclick(호출 안 Q 이상) · 재판단 0/0 · 재클릭 1 · 호출 D reclick · 한 번 더 0 · 끝-확인 · 기록 attempts 1 · retryClicks 2' `
        (J @((Get-ReentryText $r), (& $quietText (@($r.ReentryResults) | Select-Object -First 1) $Q), $r.VerdictCalls, $r.RetrySends, (Get-LineCount -Result $r -Line $script:rzOnceMoreLine),
            (Get-ResumeEndReady $r), $r.Stage, $r.Attempts, $r.RetryClicks)) `
        (J @('reclick,reclick', 'True', '0/0', 1, 0, (Get-ResumeEndReadyWant), 'retry-clicked', 1, 2))

    # WA-D4 (다-1) - 지난 시계(retry-attempt 항목이라 at.retryAttempt 로 둠 - 같은 시계) · R3 · 지정 시각 30초 전(지남) → Q 뒤 'reclick' → 재평가(첫 재판단 = 호출 C 반환 시각) → 끝-멈춤(결정 1)
    $r = Invoke-ResumeRow @{ Name = 'WA-D4 (다-1)'; Stage = 'retry-attempt'; AtAttempt = $PAST; Until = -30; Scenario = @{ Timeline = $r3Timeline } }
    Assert-ResumeCommon 'WA-D4 (다-1)' $r
    $d4c1First = @($r.ReentryResults) | Select-Object -First 1
    Assert-Case 'WA-D4 (다-1) 지난 시계 · R3 · retry-attempt · 지정 시각 지남 → Q 뒤 reclick · 재평가 1/1(첫 재판단 = 호출 C 반환 시각 ≥ Q) · 끝-멈춤(재개 판단 time 1 · 직전 판단 0) · 기록 무변경' `
        (J @((Get-ReentryText $r), (& $quietText $d4c1First $Q), $(if (($null -ne $d4c1First) -and ($null -ne $r.VerdictAt)) { [string]([Math]::Abs([double]$r.VerdictAt - [double]$d4c1First.ReturnT) -lt $TIME_EPSILON) } else { '(없음)' }),
            $r.VerdictCalls, (Get-ResumeEndStop $r), $r.Stage, $r.Attempts, $r.Unchanged)) `
        (J @('reclick', 'True', 'True', '1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'time' -30)), 'retry-attempt', 0, 'True'))

    # WA-D4 (다-2) - 같은 앞 · 지정 시각 600초 뒤(T 전) → 재평가 통과 → 재클릭 1(첫 시도 기록 → 재검사 → 전송 = 이 워커 commit) → 재입장 → 끝-IH 11
    $r = Invoke-ResumeRow @{ Name = 'WA-D4 (다-2)'; Stage = 'retry-attempt'; AtAttempt = $PAST; Until = 600; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'WA-D4 (다-2)' $r
    $d4c2Send = @($r.RetrySendTimes) | Select-Object -First 1
    Assert-Case 'WA-D4 (다-2) 같은 앞 · 지정 시각 전 → 재판단 2/2(재평가 + 클릭 자리) · 재클릭 1(전송 ≥ Q · 이 워커 commit = True) · 호출 D entered · 끝-IH 11 · 이어 감 안내 1 · attempts 1 · retryClicks 1' `
        (J @((Get-ReentryText $r), $r.VerdictCalls, $r.RetrySends, $(if ($null -ne $d4c2Send) { [string]([double]$d4c2Send -ge ($Q - $TIME_EPSILON)) } else { '(전송 없음)' }), $r.Committed,
            (Get-ResumeEndIH $r), (& $continueCount $r), $r.Attempts, $r.RetryClicks)) `
        (J @('reclick,entered', '2/2', 1, 'True', 'True', (Get-ResumeEndIHWant '11'), 1, 1, 1))

    # WA-D6 - 40초 전 · 시작값 1 · 'reclick' → 재클릭 → 1초 뒤 재매칭 패널 지속 → 호출 D 는 새 시계(둘째 전송부터 B = Tpm) → 시간 초과 끝-none. 둘째 전송 시각 = at.retryClicked
    $r = Invoke-ResumeRow @{ Name = 'WA-D6'; AtClicked = 40; RetryClicks = 1; Scenario = @{ Timeline = $r3Timeline; RetrySend = @{ 1 = @(, @(1, 'matching')) } } }
    Assert-ResumeCommon 'WA-D6' $r
    $d6Call = @($r.ReentryResults) | Select-Object -Skip 1 -First 1
    $d6Send = @($r.RetrySendTimes) | Select-Object -First 1
    $d6SendText = $(if ($null -ne $d6Send) { $VIRTUAL_BASE.AddTicks([long][Math]::Round([double]$d6Send * 1e7)).ToString('o') } else { '(전송 없음)' })
    Assert-Case 'WA-D6 40초 전 · 시작값 1 · reclick → 재클릭 → M 지속 → 호출 D(시계 없음 · 한도 Tpm · 유예 끔 · 패널 초기값 거짓 · 필드 켬 · 보고 켬) timeout · 재판단 0/0 · 끝-none(입력 = 재클릭 회전 둘)' `
        (J @((Get-ReentryText $r), $(if ($null -ne $d6Call) { 'HasClock={0} · Limit={1} · Grace={2} · Panel={3} · Field={4} · Report={5}' -f $d6Call.HasClock, $d6Call.LimitSeconds, $d6Call.Grace, $d6Call.PanelSeen, $d6Call.Field, $d6Call.Report } else { '(호출 D 없음)' }),
            $r.RetrySends, $r.VerdictCalls, $r.InputList, (Get-ResumeEndNone $r))) `
        (J @('reclick,timeout', ('HasClock=False · Limit={0} · Grace=False · Panel=False · Field=True · Report=True' -f $Tpm), 1, '0/0', 'Focus-Game / Click-GamePoint 636,654', (Get-ResumeEndNoneWant 'party' 2)))
    Assert-Case 'WA-D6 → 끝 = 둘째 전송 + Tpm 무렵(재개 시계 마감 Tpm−40 이 아님) · at.retryClicked = 둘째 전송 가상 시각 · retryClicks 2' `
        (J @($(if ($null -ne $d6Send) { Test-NearTime $r.EndT ([double]$d6Send + $Tpm) } else { '(전송 없음)' }), $r.AtRetryClicked, $r.RetryClicks)) (J @('True', $d6SendText, 2))

    # WA-D9 - 혼자하기 · 40초 전(남은 T45−40 < Q) · R3 지속 → 재개 시계가 먼저 지나도 3버튼 유예로 Q 까지 미룸 → 'reclick'('timeout' 0) → 재클릭 2 → 폴백 ①
    Assert-True ('WA-D9 전제 - 남은 T45−40({0}) < Q({1})' -f ($T45 - 40), $Q) (($T45 - 40) -lt $Q) ''
    $r = Invoke-ResumeRow @{ Name = 'WA-D9'; Mode = 'solo'; AtClicked = 40; Scenario = @{ Timeline = $r3Timeline } }
    Assert-ResumeCommon 'WA-D9' $r
    $d9First = @($r.ReentryResults) | Select-Object -First 1
    Assert-Case "WA-D9 혼자하기 · 남은 T45−40 · R3 지속 → 호출 C reclick(호출 안 Q 이상 · 재개 시계 · 필드 끔) · 'timeout' 0 · 혼자하기 시간 초과 줄 0 · 재클릭 2 · 한 번 더 1 · 끝-확인 · 재판단 0/0" `
        (J @((Get-ReentryText $r), (& $quietText $d9First $Q), $(if ($null -ne $d9First) { 'Clock={0} · Field={1}' -f $d9First.ClockResume, $d9First.Field } else { '(호출 C 없음)' }),
            (Get-LineCount -Result $r -Line $script:rzNoneSolo), $r.RetrySends, (Get-LineCount -Result $r -Line $script:rzOnceMoreLine), (Get-ResumeEndReady $r), $r.VerdictCalls)) `
        (J @('reclick,reclick,reclick', 'True', 'Clock=True · Field=False', 0, 2, 1, (Get-ResumeEndReadyWant), '0/0'))
}

# ----- A′. 선분기 유예 변형 GR (test_abyss_party_leader 대기 함수 N4-L 꼴을 선분기로 - 시각 창은 이 엔진 간격(회전 대기 · 판독 비용 0)에 맞춤) -----
function Test-ResumeRowsGR {
    $Tpm = [int]$capturedTimeoutPartyMatch
    $PAST = $Tpm + 60
    $Q = [double]$abyssReclickQuietSeconds
    $waitSeconds = [double]$script:selectorWaitMs / 1000
    $iTimeline = @(New-Timeline -Pairs @(0, 'I'))
    $r3Timeline = @(New-Timeline -Pairs @(0, 'R3'))
    $ihWant = Get-ResumeEndIHWant '0'
    $noneWant = Get-ResumeEndNoneWant 'party'

    # GR-a - 지난 시계 · I 1표본 · 동결 · I → 끝-IH (동결 회전은 연속을 유지 · 탐침 복구 뒤 회전이 'inside-extend')
    $r = Invoke-ResumeRow @{ Name = 'GR-a'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; CapFail = @(New-Windows -Pairs @(0.5, 3.0)) } }
    Assert-ResumeCommon 'GR-a' $r
    Assert-Case 'GR-a 지난 시계 · I · 동결 @0.5~3 · I → 끝-IH · 동결(안전 확인 ≥ 1)' (J @((Get-ResumeEndIH $r), ($r.SafeStopCalls -ge 1))) (J @($ihWant, 'True'))

    # GR-b (N4-L1) - 지난 시계 · I 뒤 판독 실패 ↔ 탐침 복구 교대 → 유한(유예 시계) · 끝-none
    $r = Invoke-ResumeRow @{ Name = 'GR-b'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; ReadFail = @(New-Windows -Pairs @(0.5, $RESUME_NEVER)) } }
    Assert-ResumeCommon 'GR-b' $r
    Assert-Case 'GR-b 지난 시계 · I · 판독 실패 ↔ 탐침 복구 교대 @0.5~ → 끝-none · 탐침 ≥ 2 · 실패 합 > 0 · 끝 < 100(유한)' `
        (J @((Get-ResumeEndNone $r), ($r.ProbeCalls -ge 2), ($r.FailTotalMs -gt 0), ($r.EndT -lt 100))) (J @($noneWant, 'True', 'True', 'True'))

    # GR-c (N4-L10) - 지난 시계 · 호출 C 안 R3 교대 → 3버튼 창(대기 함수 몫)은 조정 Q 까지 → 유한 timeout · 끝-none
    $r = Invoke-ResumeRow @{ Name = 'GR-c'; AtClicked = $PAST; Scenario = @{ Timeline = $r3Timeline; ReadFail = @(New-Windows -Pairs @(0.5, $RESUME_NEVER)) } }
    Assert-ResumeCommon 'GR-c' $r
    Assert-Case 'GR-c 지난 시계 · R3@0 · 교대 @0.5~ → 호출 C timeout · 끝-none · 실패 합 > 0 · 끝 < 100(유한)' `
        (J @((Get-ReentryText $r), (Get-ResumeEndNone $r), ($r.FailTotalMs -gt 0), ($r.EndT -lt 100))) (J @('timeout', $noneWant, 'True', 'True'))

    # GR-d (N4-L11) - 지난 시계 · 첫 유효 회전 전 교대 → 첫 유효 회전 전 창은 조정 Q 까지 → 유한 · 끝-none · 호출 C 0
    $r = Invoke-ResumeRow @{ Name = 'GR-d'; AtClicked = $PAST; Scenario = @{ Timeline = $r3Timeline; ReadFail = @(New-Windows -Pairs @(0.0, $RESUME_NEVER)) } }
    Assert-ResumeCommon 'GR-d' $r
    Assert-Case 'GR-d 지난 시계 · R3 · 교대 @0~(유효 회전 0) → 끝-none · 재입장 대기 0 · 유효 회전 0 · 실패 합 > 0 · 끝 < 100' `
        (J @((Get-ResumeEndNone $r), (Get-ReentryText $r), @(Get-ValidTurns -Result $r).Count, ($r.FailTotalMs -gt 0), ($r.EndT -lt 100))) (J @($noneWant, '', 0, 'True', 'True'))

    # GR-e - 지난 시계 · 첫 회전 캡처 실패 → 복구 → I · I → 끝-IH (첫 유효 회전 전 창 'unread' → 던전 안 첫 유예)
    $r = Invoke-ResumeRow @{ Name = 'GR-e'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; CapFail = @(New-Windows -Pairs @(0.0, 3.0)) } }
    Assert-ResumeCommon 'GR-e' $r
    Assert-Case 'GR-e 지난 시계 · 캡처 실패 @0~3 → 복구 → I · I → 끝-IH' (Get-ResumeEndIH $r) $ihWant

    # GR-f (N4-L8) - 지난 시계 · I · 게이트 조작 · I · I → 게이트가 쓴 유예를 되돌려 새 연속이 다시 첫 유예 → 끝-IH
    $r = Invoke-ResumeRow @{ Name = 'GR-f'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; Active = @(New-Windows -Pairs @(0.5, 3.0)) } }
    Assert-ResumeCommon 'GR-f' $r
    Assert-Case "GR-f 지난 시계 · I · 조작 @0.5~3(② 게이트) · I · I → 끝-IH · 양보 문맥 '$YIELD_CONTEXT'" (J @((Get-ResumeEndIH $r), $r.YieldContexts)) (J @($ihWant, $YIELD_CONTEXT))

    # GR-g (N4-L13 · L13′) - 지난 시계 · I · 스윕 'yield'(조작 생략 - 위임 양보) · I · I → ④ 분류가 연속 0 앞이어야 되돌림 → 끝-IH
    $r = Invoke-ResumeRow @{ Name = 'GR-g'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; SweepSkip = @(New-Windows -Pairs @(0.5, 1.0)) } }
    Assert-ResumeCommon 'GR-g' $r
    Assert-Case 'GR-g 지난 시계 · I · 스윕 조작 생략 @0.5~1 · I · I → 끝-IH · 스윕 참 회전 1' (J @((Get-ResumeEndIH $r), @($r.SweepTrueTurns).Count)) (J @($ihWant, 1))

    # GR-h (N4-L14) - 지난 시계 · I · 간접 양보(⑥) · I · I → ⑥ 이 되돌리고 그 회전 I 가 새 연속 → 끝-IH · 게이트 양보 0
    $r = Invoke-ResumeRow @{ Name = 'GR-h'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; SweepYield = @(New-Windows -Pairs @(0.5, 1.0)) } }
    Assert-ResumeCommon 'GR-h' $r
    Assert-Case 'GR-h 지난 시계 · I · 간접 양보 @0.5~1 · I · I → 끝-IH · 게이트 양보 문맥 0 · 양보 누적 > 0' (J @((Get-ResumeEndIH $r), $r.YieldContexts, ($r.YieldTotalMs -gt 0))) (J @($ihWant, '', 'True'))

    # GR-i (N4-L15) - 지난 시계 · I · 스윕 전송(연속을 끊어도 유예는 그대로 한 번) 뒤 조작(끊을 연속 없음) → 끝-none
    $r = Invoke-ResumeRow @{ Name = 'GR-i'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; Sweep = @(New-Windows -Pairs @(0.5, 1.0)); Active = @(New-Windows -Pairs @(1.6, 3.0)) } }
    Assert-ResumeCommon 'GR-i' $r
    Assert-Case 'GR-i 지난 시계 · I · 스윕 전송 @0.5~1 · 조작 @1.6~3 · I → 끝-none · 스윕 참 회전 1 · 양보 1' `
        (J @((Get-ResumeEndNone $r), @($r.SweepTrueTurns).Count, @(([string]$r.YieldContexts) -split ' / ' | Where-Object { $_ }).Count)) (J @($noneWant, 1, 1))

    # GR-j (N4-L17 · N4-L18) - 지난 시계 · 조작 뒤 첫 결정 회전이 ① 탐침 복구 뒤 회전 / ② 판독 도중 실패 뒤 복구 회전 → 되돌림 뒤 창이 미룸 → 끝-IH
    $r = Invoke-ResumeRow @{ Name = 'GR-j 탐침 복구 뒤'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; CapFail = @(New-Windows -Pairs @(0.5, 3.0)); Active = @(New-Windows -Pairs @(4.6, 6.0)) } }
    Assert-ResumeCommon 'GR-j 탐침 복구 뒤' $r
    Assert-Case 'GR-j ① 지난 시계 · I · 실패 @0.5~3 · 조작 @4.6~6(탐침이 되살린 직후) → 끝-IH · 양보 1 · 안전 확인 ≥ 1' `
        (J @((Get-ResumeEndIH $r), @(([string]$r.YieldContexts) -split ' / ' | Where-Object { $_ }).Count, ($r.SafeStopCalls -ge 1))) (J @($ihWant, 1, 'True'))
    $r = Invoke-ResumeRow @{ Name = 'GR-j 복구 회전'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; Active = @(New-Windows -Pairs @(0.5, 3.0)); SerialFail = @(New-Windows -Pairs @(3.0, 3.1)) } }
    Assert-ResumeCommon 'GR-j 복구 회전' $r
    Assert-Case 'GR-j ② 지난 시계 · I · 조작 @0.5~3 · 양보 뒤 첫 회전 판독 도중 실패(같은 회전 복구) → 끝-IH · 안전 확인 0 · 실패 판독 회전 1' `
        (J @((Get-ResumeEndIH $r), $r.SafeStopCalls, @(@($r.Turns) | Where-Object { -not $_.Valid }).Count)) (J @($ihWant, 0, 1))

    # GR-k (N4-L22) - 지난 시계 · 같은 앞(조작) · 캡처 교대 → 되돌림 뒤 창은 유예 시계까지 → 유한 · 끝-none
    $r = Invoke-ResumeRow @{ Name = 'GR-k'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; Active = @(New-Windows -Pairs @(0.5, 3.0)); ReadFail = @(New-Windows -Pairs @(3.0, $RESUME_NEVER)) } }
    Assert-ResumeCommon 'GR-k' $r
    Assert-Case 'GR-k 지난 시계 · I · 조작 @0.5~3 · 교대 @3~ → 끝-none · 실패 합 > 0 · 끝 < 100(유한)' (J @((Get-ResumeEndNone $r), ($r.FailTotalMs -gt 0), ($r.EndT -lt 100))) (J @($noneWant, 'True', 'True'))

    # GR-l (N4-L24~L26) - 남은 0.5(첫 I 는 시계 안 - 유예를 쓰지 않은 연속) · 그 연속을 조작이 끊은 뒤 판독 없는 회전에서 시계가 지남 → 되돌림 뒤 창 → 끝-IH (세 꼴)
    Assert-True ('GR-l · GR-m 전제 - 남은 0.5 < 선분기 회전 대기({0}초)' -f (Format-Seconds $waitSeconds)) (0.5 -lt $waitSeconds) ''
    $glCases = @(
        @{ Name = 'GR-l 게이트'; Scenario = @{ Timeline = $iTimeline; CapFail = @(New-Windows -Pairs @(0.5, 3.0)); Active = @(New-Windows -Pairs @(4.6, 6.0)) } },
        @{ Name = 'GR-l 스윕 yield'; Scenario = @{ Timeline = $iTimeline; SweepSkip = @(New-Windows -Pairs @(0.5, 1.0)); CapFail = @(New-Windows -Pairs @(4.6, 6.0)) } },
        @{ Name = 'GR-l 간접 양보'; Scenario = @{ Timeline = $iTimeline; SweepYield = @(New-Windows -Pairs @(0.5, 1.0)); CapFail = @(New-Windows -Pairs @(1.6, 3.0)) } })
    foreach ($glCase in $glCases) {
        $r = Invoke-ResumeRow @{ Name = $glCase.Name; AtClicked = ($Tpm - 0.5); Scenario = $glCase.Scenario }
        Assert-ResumeCommon $glCase.Name $r
        Assert-Case ($glCase.Name + ' 남은 0.5 · I · 끊음 → 판독 없는 회전에서 시계 지남 → 끝-IH · 동결(안전 확인 ≥ 1)') (J @((Get-ResumeEndIH $r), ($r.SafeStopCalls -ge 1))) (J @($ihWant, 'True'))
    }

    # GR-m (N4-L27) - 남은 0.5 · I@0 · 조작 뒤 캡처 교대 → 되돌림 갈래가 처음 미룬 회전에 정지 유예 시계를 진행 → 유한 · 끝-none · 가상 시간 초과 0
    $r = Invoke-ResumeRow @{ Name = 'GR-m'; AtClicked = ($Tpm - 0.5); Scenario = @{ Timeline = $iTimeline; Active = @(New-Windows -Pairs @(0.5, 3.0)); ReadFail = @(New-Windows -Pairs @(3.0, $RESUME_NEVER)) } }
    Assert-ResumeCommon 'GR-m' $r
    Assert-Case 'GR-m 남은 0.5 · I · 조작 @0.5~3 · 교대 @3~ → 끝-none · 실패 합 > 0 · 끝 < 100(유한 - 가상 시간 초과 0)' (J @((Get-ResumeEndNone $r), ($r.FailTotalMs -gt 0), ($r.EndT -lt 100))) (J @($noneWant, 'True', 'True'))

    # GR-n (N4-L28) - 남은 15 · I@0 · 조작 · U(되돌림 뒤 창을 닫음) · 시계가 지난 뒤 I(첫 유예) → 동결 → I → 끝-IH (조작 순간에는 유예 시계를 진행하지 않음)
    Assert-True ('GR-n 전제 - 남은 15 > Q({0}) + 선분기 회전 대기({1}초)' -f $Q, (Format-Seconds $waitSeconds)) (15 -gt ($Q + $waitSeconds)) ''
    $r = Invoke-ResumeRow @{ Name = 'GR-n'; AtClicked = ($Tpm - 15); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'I', 3.0, 'U', 17.5, 'I')); Active = @(New-Windows -Pairs @(0.5, 3.0)); CapFail = @(New-Windows -Pairs @(18.0, 20.0)) } }
    Assert-ResumeCommon 'GR-n' $r
    Assert-Case 'GR-n 남은 15 · I · 조작 @0.5~3 · U@3 · I@17.5 · 실패 @18~20 → 끝-IH · 양보 1 · 안전 확인 ≥ 1' `
        (J @((Get-ResumeEndIH $r), @(([string]$r.YieldContexts) -split ' / ' | Where-Object { $_ }).Count, ($r.SafeStopCalls -ge 1))) (J @($ihWant, 1, 'True'))

    # GR-o (N4-L23) - 지난 시계 · 되돌림 뒤 새 연속을 스윕 전송이 끊음 → '한 번' → 끝-none
    $r = Invoke-ResumeRow @{ Name = 'GR-o'; AtClicked = $PAST; Scenario = @{ Timeline = $iTimeline; Active = @(New-Windows -Pairs @(0.5, 3.0)); Sweep = @(New-Windows -Pairs @(3.6, 4.0)) } }
    Assert-ResumeCommon 'GR-o' $r
    Assert-Case 'GR-o 지난 시계 · I · 조작 @0.5~3 · I · 스윕 전송 @3.6~4 · I → 끝-none · 스윕 참 회전 1' (J @((Get-ResumeEndNone $r), @($r.SweepTrueTurns).Count)) (J @($noneWant, 1))

    # GR-p (N4-L16 · WA-L33 (나)) - 지난 시계 · I 1표본 · U 지속 → 'inside' 아닌 유효 분류가 연속을 끊음 → 첫 U 유효 회전에 'timeout' · 끝-none (결말 회전 = 그 회전)
    $r = Invoke-ResumeRow @{ Name = 'GR-p'; AtClicked = $PAST; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'I', 0.5, 'U')) } }
    Assert-ResumeCommon 'GR-p' $r
    $gpFirstU = @(Get-ValidTurns -Result $r -Key 'U') | Select-Object -First 1
    Assert-Case 'GR-p 지난 시계 · I@0 · U@0.5 지속 → 끝-none · 결말 = 첫 U 유효 회전(끝 시각 = 그 회전 판독 시각)' `
        (J @((Get-ResumeEndNone $r), $(if ($null -ne $gpFirstU) { [string]([Math]::Abs($r.EndT - [double]$gpFirstU.T) -lt $TIME_EPSILON) } else { '(U 유효 회전 없음)' }))) (J @($noneWant, 'True'))
}

# ----- B. 필드 (시계 넉넉 - 재입장 대기 0) -----
function Test-ResumeRowsB {
    $W = [double]$memberFieldSettleSeconds
    $fieldTimeline = @(New-Timeline -Pairs @(0, 'F'))
    $fieldWant = Get-ResumeEndFieldWant
    # WA-F1~F4 (R4 FL1~FL4 꼴) - F 연속에 양보 · 동결 · 스윕 참 · 판독 도중 실패 → 확정 ≥ 끊김 끝 + W · 끝-필드
    $wfCases = @(
        @{ Name = 'WA-F1 양보(@3~4)'; BreakEnd = 4.0; Scenario = @{ Timeline = $fieldTimeline; Active = @(New-Windows -Pairs @(3.0, 4.0)) } },
        @{ Name = 'WA-F2 동결(@3~5)'; BreakEnd = 5.0; Scenario = @{ Timeline = $fieldTimeline; CapFail = @(New-Windows -Pairs @(3.0, 5.0)) } },
        @{ Name = 'WA-F3 스윕 참(@2.8~4)'; BreakEnd = 4.0; Scenario = @{ Timeline = $fieldTimeline; Sweep = @(New-Windows -Pairs @(2.8, 4.0)) } },
        @{ Name = 'WA-F4 판독 도중 실패(@3.4~3.8)'; BreakEnd = 3.4; Scenario = @{ Timeline = $fieldTimeline; SerialFail = @(New-Windows -Pairs @(3.4, 3.8)) } })
    foreach ($wfCase in $wfCases) {
        $r = Invoke-ResumeRow @{ Name = $wfCase.Name; Scenario = $wfCase.Scenario }
        Assert-ResumeCommon $wfCase.Name $r
        $settle = Get-SettleLineInfo -Result $r
        $lowerBound = [double]$wfCase.BreakEnd + $W
        Assert-True ($wfCase.Name + ' → 끝-필드 · 확정 ≥ 끊김 끝 + W · 다시 센 폭 W 이상 한 박자 안 · 재입장 대기 0') `
            (((Get-ResumeEndField $r) -ceq $fieldWant) -and $settle.Found -and ($settle.T -ge ($lowerBound - $TIME_EPSILON)) -and ($settle.T -le ($lowerBound + 5)) -and
                ($settle.Span -ge ($W - $TIME_EPSILON)) -and ($settle.Span -lt ($W + 1.5)) -and ((Get-ReentryText $r) -ceq '')) `
            ('확정 {0}초(하한 {1}) · 폭 {2} · [{3}] · 대기 [{4}]' -f (Format-Seconds $settle.T), (Format-Seconds $lowerBound), (Format-Seconds $settle.Span), (Get-ResumeEndField $r), (Get-ReentryText $r))
    }
    # WA-F5 (FL5 대조) - 끼는 회전 없이 F 만 → 확정 W 이상 W+1.5 미만 · 폭 = 확정 시각
    $r = Invoke-ResumeRow @{ Name = 'WA-F5'; Scenario = @{ Timeline = $fieldTimeline } }
    Assert-ResumeCommon 'WA-F5' $r
    $settle = Get-SettleLineInfo -Result $r
    Assert-True 'WA-F5 대조 - F 만 → 끝-필드 · 확정 W 이상 W+1.5 미만 · 폭 = 확정 시각(0초 첫 표본부터)' `
        (((Get-ResumeEndField $r) -ceq $fieldWant) -and $settle.Found -and ($settle.T -ge ($W - $TIME_EPSILON)) -and ($settle.T -lt ($W + 1.5)) -and ([Math]::Abs($settle.Span - $settle.T) -lt 0.051)) `
        ('확정 {0}초 · 폭 {1} · [{2}]' -f (Format-Seconds $settle.T), (Format-Seconds $settle.Span), (Get-ResumeEndField $r))

    # WA-F6 (가) - F 지속 · @1.4 간접 양보(SweepYield 창 · SweepYieldMs 3000) → 이 회전의 필드 표본이 양보 뒤 새 첫 표본(= 1.4 + 양보 길이 - 행 입력에서 계산) · 확정은 그 뒤 W
    $f6YieldStart = 1.4
    $f6YieldMs = 3000
    $f6NewFirst = $f6YieldStart + ($f6YieldMs / 1000)
    $f6Scenario = @{ Timeline = $fieldTimeline; SweepYield = @(New-Windows -Pairs @($f6YieldStart, ($f6YieldStart + 0.5))); SweepYieldMs = $f6YieldMs }
    $r = Invoke-ResumeRow @{ Name = 'WA-F6 (가)'; Scenario = $f6Scenario }
    Assert-ResumeCommon 'WA-F6 (가)' $r
    $settle = Get-SettleLineInfo -Result $r
    $f6Observed = $(if ($settle.Found) { $settle.T - $settle.Span } else { -1 })
    Assert-True ('WA-F6 (가) F 지속 · @{0} 간접 양보 {1}ms → 새 첫 표본 = {2}(확정 시각 − 확정 줄 폭) · 확정 = 새 첫 표본 + W 이상 첫 F 회전 · 확정 줄 1 · 끝-필드' -f $f6YieldStart, $f6YieldMs, $f6NewFirst) `
        (((Get-ResumeEndField $r) -ceq $fieldWant) -and $settle.Found -and ([Math]::Abs($f6Observed - $f6NewFirst) -lt 0.051) -and ($settle.T -ge ($f6NewFirst + $W - $TIME_EPSILON)) -and
            ($settle.T -lt ($f6NewFirst + $W + [double]$script:selectorWaitMs / 1000 + $TIME_EPSILON))) `
        ('확정 {0}초 · 폭 {1} · 관측 새 첫 표본 {2} · [{3}]' -f (Format-Seconds $settle.T), (Format-Seconds $settle.Span), (Format-Seconds $f6Observed), (Get-ResumeEndField $r))
    # WA-F6 (나) - 간접 양보 없음(대조) → @W 확정
    $r = Invoke-ResumeRow @{ Name = 'WA-F6 (나)'; Scenario = @{ Timeline = $fieldTimeline } }
    Assert-ResumeCommon 'WA-F6 (나)' $r
    $settle = Get-SettleLineInfo -Result $r
    Assert-True 'WA-F6 (나) 대조 - 간접 양보 없음 → 확정 W 이상 W+1.5 미만 · 끝-필드' (((Get-ResumeEndField $r) -ceq $fieldWant) -and $settle.Found -and ($settle.T -ge ($W - $TIME_EPSILON)) -and ($settle.T -lt ($W + 1.5))) `
        ('확정 {0}초 · [{1}]' -f (Format-Seconds $settle.T), (Get-ResumeEndField $r))
    # WA-F6 (다) - 간접 양보 회전 다음 무양보 회전의 표본 시각 = 그 회전 시작(서두가 다시 둠) → 확정 줄 표본 수 = 양보 회전 ~ 확정 회전의 유효 F 회전 수 · 폭 = 확정 − 양보 회전 판독 시각
    $r = Invoke-ResumeRow @{ Name = 'WA-F6 (다)'; Scenario = $f6Scenario }
    Assert-ResumeCommon 'WA-F6 (다)' $r
    $settle = Get-SettleLineInfo -Result $r
    $f6YieldTurn = @(@($r.Turns) | Where-Object { $_.Valid -and ($_.Key -eq 'F') -and ([double]$_.T -ge ($f6NewFirst - $TIME_EPSILON)) }) | Select-Object -First 1
    $f6Counted = $(if (($null -ne $f6YieldTurn) -and $settle.Found) { @(@($r.Turns) | Where-Object { $_.Valid -and ($_.Key -eq 'F') -and ([double]$_.T -ge ([double]$f6YieldTurn.T - $TIME_EPSILON)) -and ([double]$_.T -le ($settle.T + $TIME_EPSILON)) }).Count } else { -1 })
    Assert-True 'WA-F6 (다) 양보 회전 뒤 무양보 회전 → 확정 줄 표본 수 = 양보 회전 ~ 확정 회전의 유효 F 회전 수 · 폭 = 확정 − 양보 회전 판독 시각' `
        ($settle.Found -and ($null -ne $f6YieldTurn) -and ($settle.Count -eq $f6Counted) -and ([Math]::Abs($settle.Span - ($settle.T - [double]$f6YieldTurn.T)) -lt 0.051)) `
        ('표본 {0} · 회전 수 {1} · 폭 {2} · 양보 회전 {3}' -f $settle.Count, $f6Counted, (Format-Seconds $settle.Span), $(if ($null -ne $f6YieldTurn) { Format-Seconds $f6YieldTurn.T } else { '(없음)' }))

    # S1 - F · F(< W) · I · I → 끝-IH · 코드 4 0 (확정 전 필드 모양은 증거가 아님)
    $r = Invoke-ResumeRow @{ Name = 'S1'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'F', ($W - 2), 'I')) } }
    Assert-ResumeCommon 'S1' $r
    Assert-Case 'S1 F@0~(W−2) · I · I → 끝-IH(코드 0) · 선분기 필드 확정 줄 0' (J @((Get-ResumeEndIH $r), @(Get-PatternLines -Result $r -Pattern $S3_PATTERN).Count)) (J @((Get-ResumeEndIHWant '0'), 0))
    # S2 - F 연속 ≥ W → 끝-필드 · 꼬리 없음(정지 줄 = 소스 글자 그대로)
    $r = Invoke-ResumeRow @{ Name = 'S2'; Scenario = @{ Timeline = $fieldTimeline } }
    Assert-ResumeCommon 'S2' $r
    Assert-Case 'S2 F 지속 → 끝-필드(꼬리 없음 - 정지 줄 = 재개 필드 정지 줄 원문)' (Get-ResumeEndField $r) $fieldWant
    # S3 - F · U 교대(각 F 구간 < W) → 끝-none · 이벤트 정리 0
    $r = Invoke-ResumeRow @{ Name = 'S3'; AtClicked = ([int]$capturedTimeoutPartyMatch - 60); Scenario = @{ Cycle = @('U', 'U', 'U', 'F') } }
    Assert-ResumeCommon 'S3' $r
    Assert-Case 'S3 F·U 교대(남은 60초) → 끝-none · 선분기 필드 확정 줄 0 · 끝 = 60 무렵' (J @((Get-ResumeEndNone $r), @(Get-PatternLines -Result $r -Pattern $S3_PATTERN).Count, (Test-NearTime $r.EndT 60))) (J @((Get-ResumeEndNoneWant 'party'), 0, 'True'))
}

# ----- C. 시작 화면 열 ST -----
function Test-ResumeRowsC {
    $Tpm = [int]$capturedTimeoutPartyMatch
    $U30 = [double]$memberUnknownOverlaySeconds
    $ihWant = Get-ResumeEndIHWant '0'
    # ST1 (5c-3) - R3 + 시작값 1 → Q 뒤 reclick → 승계 → 재클릭 1(판당 상한) → 1초 뒤 재매칭 패널 → I · I → 끝-IH. 시작값은 여기서 갈리지 않음(FB14 가 봄)
    $r = Invoke-ResumeRow @{ Name = 'ST1'; RetryClicks = 1; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'R3')); RetrySend = @{ 1 = @(@(1, 'matching'), @(4, 'I')) } } }
    Assert-ResumeCommon 'ST1' $r
    Assert-Case 'ST1 R3 · 시작값 1 → 호출 C reclick · 재클릭 1 · 호출 D(재매칭 패널 확인 1) entered · 끝-IH · 재판단 0/0 · 입력 = 재클릭 회전 둘 · 다른 던전 전송 0' `
        (J @((Get-ReentryText $r), $r.RetrySends, $r.OtherSends, (Get-LineCount -Result $r -Line $script:rzPanelNotice), $r.VerdictCalls, $r.InputList, (Get-ResumeEndIH $r))) `
        (J @('reclick,entered', 1, 0, 1, '0/0', 'Focus-Game / Click-GamePoint 636,654', $ihWant))
    # ST2 - 준비 패널 · 접힌 패널 · 재매칭 패널 각각 → I · I → 클릭 0 · 끝-IH (호출 C 'entered')
    foreach ($st2Key in @('ready', 'entry', 'matching')) {
        $r = Invoke-ResumeRow @{ Name = "ST2 $st2Key"; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, $st2Key, 2.0, 'I')) } }
        Assert-ResumeCommon "ST2 $st2Key" $r
        Assert-Case "ST2 $st2Key@0 · I@2 → 호출 C entered · 입력 0 · 끝-IH" (J @((Get-ReentryText $r), $r.Inputs, (Get-ResumeEndIH $r))) (J @('entered', 0, $ihWant))
    }
    # ST3 - I · I → 키 0 · 입력 0 · 끝-IH · 완료 줄 nonce = 받은 nonce (재입장 완료 줄 대조에 NC 가 들어 있음)
    $r = Invoke-ResumeRow @{ Name = 'ST3'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'I')) } }
    Assert-ResumeCommon 'ST3' $r
    Assert-Case 'ST3 I · I → 입력 0 · 끝-IH(완료 줄 nonce = NC) · 재입장 대기 0' (J @($r.Inputs, (Get-ResumeEndIH $r), (Get-ReentryText $r))) (J @(0, $ihWant, ''))
    # ST4 - 알 수 없음 · 클리어 S 는 관측 지속(클릭 0 · ' (release)' 0 · $memberUnknownOverlaySeconds 지나도 이벤트 정리 0)
    $st4Panel = $U30 + 5
    $st4Cases = @(
        @{ Name = 'ST4 (가) U → M → I · I'; Timeline = @(New-Timeline -Pairs @(0, 'U', $st4Panel, 'matching', ($st4Panel + 3), 'I')); End = 'IH' },
        @{ Name = 'ST4 (나) S → M → I · I'; Timeline = @(New-Timeline -Pairs @(0, 'S', $st4Panel, 'matching', ($st4Panel + 3), 'I')); End = 'IH' })
    foreach ($st4Case in $st4Cases) {
        $r = Invoke-ResumeRow @{ Name = $st4Case.Name; Scenario = @{ Timeline = $st4Case.Timeline } }
        Assert-ResumeCommon $st4Case.Name $r
        Assert-Case ($st4Case.Name + ' → 입력 0 · release 0 · 끝-IH') (J @($r.Inputs, @(@($r.Lines) | Where-Object { $_.Contains($RELEASE_TAIL) }).Count, (Get-ResumeEndIH $r))) (J @(0, 0, $ihWant))
    }
    $r = Invoke-ResumeRow @{ Name = 'ST4 (다)'; AtClicked = ($Tpm - ($U30 + 10)); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'S')) } }
    Assert-ResumeCommon 'ST4 (다)' $r
    Assert-Case 'ST4 (다) S 지속(남은 U30+10) → release 0 · 끝-none' (J @(@(@($r.Lines) | Where-Object { $_.Contains($RELEASE_TAIL) }).Count, (Get-ResumeEndNone $r))) (J @(0, (Get-ResumeEndNoneWant 'party')))
    # ST5 - retryClicked 200초 전 · M 지속 → @(Tpm−200) 끝-none
    Assert-True ('ST5 · ST10 전제 - Tpm − 200 > 알 수 없음 정리 초({0})' -f $U30) (($Tpm - 200) -gt $U30) ''
    $r = Invoke-ResumeRow @{ Name = 'ST5'; AtClicked = 200; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching')) } }
    Assert-ResumeCommon 'ST5' $r
    Assert-Case 'ST5 200초 전 · M 지속 → timeout · 끝-none · 끝 = Tpm−200 무렵' (J @((Get-ReentryText $r), (Get-ResumeEndNone $r), (Test-NearTime $r.EndT ($Tpm - 200)))) (J @('timeout', (Get-ResumeEndNoneWant 'party'), 'True'))
    # ST6 - 권장 인원 팝업 → I · I → 클릭 0 · 관측 안내 1 · 끝-IH
    $r = Invoke-ResumeRow @{ Name = 'ST6'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'popup', 2.0, 'I')) } }
    Assert-ResumeCommon 'ST6' $r
    Assert-Case 'ST6 P@0 · I@2 → 입력 0 · 권장 인원 팝업 관측 안내 1 · 끝-IH' (J @($r.Inputs, (Get-LineCount -Result $r -Line $POPUP_NOTICE_LINE), (Get-ResumeEndIH $r))) (J @(0, 1, $ihWant))
    # ST7 · ST8 · ST9 - 선택 화면 · ESC 메뉴 · 상세 화면 1표본 → 끝-보류(next 문구 · 꼬리 selection / menu / selection) · 재입장 대기 0
    $holdCases = @(@{ Name = 'ST7'; Key = 'SEL'; Kind = 'selection' }, @{ Name = 'ST8'; Key = 'MENU'; Kind = 'menu' }, @{ Name = 'ST9'; Key = 'DET'; Kind = 'detail' })
    foreach ($holdCase in $holdCases) {
        $r = Invoke-ResumeRow @{ Name = $holdCase.Name; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, $holdCase.Key)) } }
        Assert-ResumeCommon $holdCase.Name $r
        Assert-Case ('{0} {1} 1표본 → 끝-보류(next 문구) · 재입장 대기 0' -f $holdCase.Name, $holdCase.Key) (J @((Get-ResumeEndHold $r), (Get-ReentryText $r))) (J @((Get-ResumeEndHoldWant $holdCase.Kind), ''))
        # ST11 - 같은 입력 × 커스텀 → '수동으로 마치지 말고' 1 · '그 판을 마친 뒤' 0 · next 문구와 같은 글자 (사용자 결정 글자 조각은 고정 사본)
        $r = Invoke-ResumeRow @{ Name = ('ST11 ' + $holdCase.Name); Custom = $true; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, $holdCase.Key)) } }
        Assert-ResumeCommon ('ST11 ' + $holdCase.Name) $r
        Assert-Case ('ST11 커스텀 · {0} → 끝-보류(next 문구 같은 글자) · 수동으로 마치지 말고 1 · 그 판을 마친 뒤 0' -f $holdCase.Key) `
            (J @((Get-ResumeEndHold $r), @(@($r.Lines) | Where-Object { $_.Contains('수동으로 마치지 말고') }).Count, @(@($r.Lines) | Where-Object { $_.Contains('그 판을 마친 뒤') }).Count)) `
            (J @((Get-ResumeEndHoldWant $holdCase.Kind), 1, 0))
    }
    # ST10 - retryClicked 200초 전 · U 지속 → 이벤트 정리 0(공통) · @(Tpm−200) 끝-none (미결 마감이면 끝이 Tpm 이라 갈림)
    $r = Invoke-ResumeRow @{ Name = 'ST10'; AtClicked = 200; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'U')) } }
    Assert-ResumeCommon 'ST10' $r
    Assert-Case 'ST10 200초 전 · U 지속 → 끝-none · 끝 = Tpm−200 무렵(미결 마감 아님)' (J @((Get-ResumeEndNone $r), (Test-NearTime $r.EndT ($Tpm - 200)))) (J @((Get-ResumeEndNoneWant 'party'), 'True'))
    # ST12 - 호출 C 인자: 준비 · 재매칭 · 팝업 · 3버튼 × 혼자하기 · 우연한 만남 → -Clock = 재개 시계 그 객체 · 패널 초기값 참 셋 / 거짓 하나 · 필드 결과 solo 거짓 · party 참 · 보고 · 유예 켬
    foreach ($st12Mode in @('solo', 'party')) {
        foreach ($st12Key in @('ready', 'matching', 'popup', 'R3')) {
            $r = Invoke-ResumeRow @{ Name = "ST12 $st12Mode $st12Key"; Mode = $st12Mode; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, $st12Key, 1.0, 'I')) } }
            Assert-ResumeCommon "ST12 $st12Mode $st12Key" $r
            $st12Call = @($r.ReentryResults) | Select-Object -First 1
            $st12Text = $(if ($null -ne $st12Call) { 'Clock={0} · Panel={1} · Field={2} · Report={3} · Grace={4} · 결과 {5}' -f $st12Call.ClockResume, $st12Call.PanelSeen, $st12Call.Field, $st12Call.Report, $st12Call.Grace, $st12Call.Result } else { '(호출 C 없음)' })
            Assert-Case "ST12 $st12Mode · $st12Key → 호출 C 인자" $st12Text ('Clock=True · Panel={0} · Field={1} · Report=True · Grace=True · 결과 entered' -f ($st12Key -ne 'R3'), ($st12Mode -ne 'solo'))
        }
    }
}

# ----- D. 승계 - 입장 끝 행 (재평가 · 재클릭 행은 아래 D 재평가 묶음) -----
function Test-ResumeRowsD {
    $Q = [double]$abyssReclickQuietSeconds
    $iTimeline = @(New-Timeline -Pairs @(0, 'I'))
    $continueCount = { param($Result) @(@($Result.Lines) | Where-Object { $_.StartsWith($script:rzContinuePrefix, [StringComparison]::Ordinal) }).Count }
    # RS1 (=R1-W7) - retry-clicked · 지정 시각(시작 T−30) · I · I → 승계 'continue' · 안내 줄 1 · 코드 11 · 재판단 0
    $r = Invoke-ResumeRow @{ Name = 'RS1'; Until = 30; Scenario = @{ Timeline = $iTimeline } }
    Assert-ResumeCommon 'RS1' $r
    Assert-Case 'RS1 retry-clicked · 지정 시각 30초 뒤 · I · I → 끝-IH 코드 11 · 이어 감 안내 1 · 재판단/시각 판정 0/0' (J @((Get-ResumeEndIH $r), (& $continueCount $r), $r.VerdictCalls)) (J @((Get-ResumeEndIHWant '11'), 1, '0/0'))
    # RS1′ - env 꼴(분 단위 표본): HONEYNOGI_UNTIL_TIME = 가상 시작 + 1분 · 실제 지정 시각 읽기 → RS1 과 같음
    $rs1Until = $VIRTUAL_BASE.AddMinutes(1).ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
    $r = Invoke-ResumeRow @{ Name = 'RS1′'; Until = $rs1Until; Scenario = @{ Timeline = $iTimeline } }
    Assert-ResumeCommon 'RS1′' $r
    Assert-Case "RS1′ env 지정 시각 '$rs1Until' · I · I → 끝-IH 코드 11 · 이어 감 안내 1 · 재판단 0/0" (J @((Get-ResumeEndIH $r), (& $continueCount $r), $r.VerdictCalls)) (J @((Get-ResumeEndIHWant '11'), 1, '0/0'))
    # RS2 (=R1-W8) - 지정 시각 없음 / 해석 실패('bad') → 판단값 '' · 코드 0. 둘 다 env 길(명세 3.3 - HONEYNOGI_UNTIL_TIME 에 빈 값 · 'bad' 를 두고 실제 지정 시각 읽기 문장을 점소싱)
    $r = Invoke-ResumeRow @{ Name = 'RS2 없음'; Until = ''; Scenario = @{ Timeline = $iTimeline } }
    Assert-ResumeCommon 'RS2 없음' $r
    Assert-Case 'RS2 지정 시각 없음(env 빈 값) · I · I → 끝-IH 코드 0 · 이어 감 안내 0' (J @((Get-ResumeEndIH $r), (& $continueCount $r))) (J @((Get-ResumeEndIHWant '0'), 0))
    $r = Invoke-ResumeRow @{ Name = 'RS2 bad'; Until = 'bad'; Scenario = @{ Timeline = $iTimeline } }
    Assert-ResumeCommon 'RS2 bad' $r
    Assert-Case "RS2 env 'bad' · I · I → 끝-IH 코드 0 · 이어 감 안내 0 · 해석 실패 [경고] 1" `
        (J @((Get-ResumeEndIH $r), (& $continueCount $r), @(@($r.Lines) | Where-Object { $_.StartsWith('[경고] 지정 시간 값을 해석하지 못했습니다') }).Count)) (J @((Get-ResumeEndIHWant '0'), 0, 1))
    # RS5 (=R1-W11 · WA-X10) - retry-attempt · Q 안 M · 지정 시각 · I · I → 재평가 0 · 패널 항으로 승계 · 코드 11
    $r = Invoke-ResumeRow @{ Name = 'RS5'; Stage = 'retry-attempt'; Until = 60; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching', 3.0, 'I')) } }
    Assert-ResumeCommon 'RS5' $r
    Assert-Case 'RS5 retry-attempt · M@0 · I@3 · 지정 시각 → 호출 C entered · 끝-IH 코드 11 · 재판단 0/0' (J @((Get-ReentryText $r), (Get-ResumeEndIH $r), $r.VerdictCalls)) (J @('entered', (Get-ResumeEndIHWant '11'), '0/0'))
    # RS6 - retry-clicked(commit T−5) · 시작 T+30 · I · I → 승계는 시각을 다시 보지 않음 → 재판단 0 · 코드 11
    $r = Invoke-ResumeRow @{ Name = 'RS6'; AtClicked = 35; Until = -30; Scenario = @{ Timeline = $iTimeline } }
    Assert-ResumeCommon 'RS6' $r
    Assert-Case 'RS6 retry-clicked 35초 전 · 지정 시각 30초 전(지남) · I · I → 끝-IH 코드 11 · 재판단 0/0' (J @((Get-ResumeEndIH $r), $r.VerdictCalls)) (J @((Get-ResumeEndIHWant '11'), '0/0'))
    # RE-1 - 혼자하기 · 지정 시각 · retry-attempt · R3 → U → I · I → 'entered' 항으로 승계(패널 0) → 11
    Assert-True ('RE-1 전제 - R3 → U 간격 2초 < Q({0})' -f $Q) (2.0 -lt $Q) ''
    $r = Invoke-ResumeRow @{ Name = 'RE-1'; Mode = 'solo'; Stage = 'retry-attempt'; Until = 60; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'R3', 2.0, 'U', 4.0, 'I')) } }
    Assert-ResumeCommon 'RE-1' $r
    $re1Call = @($r.ReentryResults) | Select-Object -First 1
    Assert-Case 'RE-1 혼자하기 · retry-attempt · R3 → U → I · I → 호출 C(패널 초기값 거짓) entered · 끝-IH 코드 11' `
        (J @((Get-ReentryText $r), $(if ($null -ne $re1Call) { [string]$re1Call.PanelSeen } else { '(없음)' }), (Get-ResumeEndIH $r))) (J @('entered', 'False', (Get-ResumeEndIHWant '11')))
    # RE-2 - 지정 시각 · retry-attempt · M → 취소 → R3 · '다른 던전 가기' 짝 없음 둘 → 헬퍼 'matching' → 호출 E 'entered' → 재클릭 0 · 패널 항 승계 → 끝-IH 11 (M3 의 근거 행)
    $re2InsideAt = 30.0
    $re2Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching', 2.0, 'R3', $re2InsideAt, 'I')); PairMiss = @{ 1 = 'Other'; 2 = 'Other' }; HelperResult = 'matching' }
    $r = Invoke-ResumeRow @{ Name = 'RE-2'; Stage = 'retry-attempt'; Until = 60; Scenario = $re2Scenario }
    Assert-ResumeCommon 'RE-2' $r
    $re2Helper = @($r.HelperTimes) | Select-Object -First 1
    Assert-True ('RE-2 전제 - I 시각({0}) > 헬퍼 호출 시각' -f $re2InsideAt) (($null -ne $re2Helper) -and ($re2InsideAt -gt [double]$re2Helper)) ('헬퍼 [{0}]' -f (@($r.HelperTimes | ForEach-Object { Format-Seconds $_ }) -join ','))
    Assert-Case "RE-2 retry-attempt · M → R3(취소) · 짝 없음 2 · 헬퍼 'matching' → 호출 C cancelled · 호출 E entered · 끝(other) rematch-cancelled/NC · 전송 0/0 · 헬퍼 1 · 끝-IH 11" `
        (J @((Get-ReentryText $r), $r.OtherEnds, ('{0}/{1}' -f $r.RetrySends, $r.OtherSends), $r.ExitClicks, (Get-ResumeEndIH $r))) (J @('cancelled,entered', 'rematch-cancelled/NC', '0/0', 1, (Get-ResumeEndIHWant '11')))
}

# ----- D 재평가 · 판단값 (5c-3 - T 는 소스 경계 그대로 -ge, 경계 T 는 같은 입력을 지정 시각 없이 돌려 잰 첫 재판단 가상 초에서 정함) -----
function Test-ResumeRowsDJudge {
    $Tpm = [int]$capturedTimeoutPartyMatch
    $PAST = $Tpm + 60
    $Q = [double]$abyssReclickQuietSeconds
    $r3Timeline = @(New-Timeline -Pairs @(0, 'R3'))
    $reenterSend = @{ 1 = @(@(1, 'U'), @(4, 'I')) }
    $continueCount = { param($Result) @(@($Result.Lines) | Where-Object { $_.StartsWith($script:rzContinuePrefix, [StringComparison]::Ordinal) }).Count }
    $atText = { param($Result, [double]$At) if ($null -eq $Result.VerdictAt) { '(재판단 없음)' } else { [string]([Math]::Abs([double]$Result.VerdictAt - $At) -lt $TIME_EPSILON) } }
    $judgePrefix = ($script:rzJudgeFormat -split [regex]::Escape('${resumeCause}'), 2)[0]

    # 경계 보정 - RS3 · RS4 · RS7 과 같은 입력(retry-attempt · R3 지속)을 지정 시각 없이
    $judgeAtRaw = Get-ResumeVerdictAt @{ Name = 'RS'; Stage = 'retry-attempt'; Scenario = @{ Timeline = $r3Timeline } }
    Assert-True ('RS3 · RS4 · RS7 전제 - 보정 첫 재판단 가상 초가 있고 Q 이상 ({0})' -f $(if ($null -ne $judgeAtRaw) { Format-Seconds $judgeAtRaw } else { '없음' })) (($null -ne $judgeAtRaw) -and ([double]$judgeAtRaw -ge ($Q - $TIME_EPSILON))) ''
    $judgeAt = [double]$judgeAtRaw

    # RS3 (=R1-W9) - 재평가 = T+1 → 'last' → 끝-멈춤(재개 판단 time 1 · 직전 판단 0)
    $r = Invoke-ResumeRow @{ Name = 'RS3'; Stage = 'retry-attempt'; Until = ($judgeAt - 1); Scenario = @{ Timeline = $r3Timeline } }
    Assert-ResumeCommon 'RS3' $r
    Assert-Case 'RS3 retry-attempt · R3 Q 무변화 · 재평가 = T+1 → 첫 재판단 = 보정 값 · 재판단 1/1 · 끝-멈춤(재개 판단 time 1 · 직전 판단 0) · commit 표지 미정 · 기록 무변경' `
        (J @((Get-ReentryText $r), (& $atText $r $judgeAt), $r.VerdictCalls, (Get-ResumeEndStop $r), $r.Committed, $r.Stage, $r.Attempts, $r.Unchanged)) `
        (J @('reclick', 'True', '1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'time' ($judgeAt - 1))), '(null)', 'retry-attempt', 0, 'True'))
    # RS7 - 재평가 = T 정각(-ge) → RS3 과 같음
    $r = Invoke-ResumeRow @{ Name = 'RS7'; Stage = 'retry-attempt'; Until = $judgeAt; Scenario = @{ Timeline = $r3Timeline } }
    Assert-ResumeCommon 'RS7' $r
    Assert-Case 'RS7 재평가 = T 정각 → RS3 과 같음(경계 -ge)' (J @((Get-ReentryText $r), (& $atText $r $judgeAt), $r.VerdictCalls, (Get-ResumeEndStop $r))) `
        (J @('reclick', 'True', '1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'time' $judgeAt))))
    # RS4 (=R1-W10) - 재평가 = T−1 → 통과 → 첫 시도 기록 → 클릭 자리 재검사(같은 가상 초 - 통과) → 전송 → 재입장 → 끝-IH 11
    $r = Invoke-ResumeRow @{ Name = 'RS4'; Stage = 'retry-attempt'; Until = ($judgeAt + 1); Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'RS4' $r
    Assert-Case 'RS4 재평가 = T−1 → 재판단 2/2 · attempts 1(갱신 1) · 재클릭 1 · 호출 D entered · 끝-IH 11 · 이어 감 안내 1 · 재개 판단 0 · 직전 판단 0' `
        (J @((Get-ReentryText $r), $r.VerdictCalls, $r.Attempts, $r.RetrySends, (Get-ResumeEndIH $r), (& $continueCount $r), (Get-ResumePrefixCount $r $judgePrefix), (Get-ResumePrefixCount $r $RESUME_CLICK_PREFIX))) `
        (J @('reclick,entered', '2/2', 1, 1, (Get-ResumeEndIHWant '11'), 1, 0, 0))

    # RS8 - env 'bad'(해석 실패 → 지정 시각 없음) · retry-attempt · R3 → 재판단 '' · 재클릭(전이 없음이라 둘) → 폴백 ① 코드 0
    $r = Invoke-ResumeRow @{ Name = 'RS8'; Stage = 'retry-attempt'; Until = 'bad'; Scenario = @{ Timeline = $r3Timeline } }
    Assert-ResumeCommon 'RS8' $r
    Assert-Case "RS8 env 'bad' · retry-attempt · R3 → 해석 실패 [경고] 1 · 판단값 '' · 재판단 2/2 · 재개 판단 0 · 직전 판단 0 · 재클릭 2 · 한 번 더 1 · 끝-확인(코드 0)" `
        (J @(@(@($r.Lines) | Where-Object { $_.StartsWith('[경고] 지정 시간 값을 해석하지 못했습니다') }).Count, $r.TimeVerdict, $r.VerdictCalls, (Get-ResumePrefixCount $r $judgePrefix),
            (Get-ResumePrefixCount $r $RESUME_CLICK_PREFIX), $r.RetrySends, (Get-LineCount -Result $r -Line $script:rzOnceMoreLine), (Get-ResumeEndReady $r), (Get-ReentryText $r))) `
        (J @(1, '', '2/2', 0, 0, 2, 1, (Get-ResumeEndReadyWant), 'reclick,reclick,reclick'))

    # RS9 (=WA-X7) - retry-clicked · R3 · 지정 시각 20초 전(시작 T+20) → 승계 'continue'(시각을 다시 보지 않음) · 재판단 0 · 재클릭 1 → 재입장 → 끝-IH 11
    $r = Invoke-ResumeRow @{ Name = 'RS9'; Until = -20; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'RS9' $r
    Assert-Case "RS9 retry-clicked · R3 · 시작 T+20 → 재판단 0/0(Get-DgTimeVerdict 0) · 판단값 'continue' · commit 표지 True(승계) · attempts 1 · 재클릭 1 · 끝-IH 11 · 이어 감 안내 1 (stage 는 ㉑ X12 몫)" `
        (J @((Get-ReentryText $r), $r.VerdictCalls, $r.TimeVerdict, $r.Committed, $r.Attempts, $r.RetrySends, (Get-ResumeEndIH $r), (& $continueCount $r))) `
        (J @('reclick,entered', '0/0', 'continue', 'True', 1, 1, (Get-ResumeEndIHWant '11'), 1))
    # RS11 (=WA-X8) 의 '시작 R3' 변형 = 이 RS9 행(구현 명세 ⑤c 3.5 E 'RS9 와 같음' - 같은 입력의 행은 하나로). 그 뜻(패널 없이 시작 → 'cancelled' 가 아니라 'reclick' · 재매칭 취소 끝 0)을 이 행에서 봅니다
    $rs11Call = @($r.ReentryResults) | Select-Object -First 1
    Assert-Case "RS11 (R3 시작 = RS9 행) → 호출 C 패널 초기값 거짓 · 첫 결과 reclick(cancelled 아님) · 끝(other) 0 · 재매칭 취소 끝 0" `
        (J @($(if ($null -ne $rs11Call) { '{0}/{1}' -f $rs11Call.PanelSeen, $rs11Call.Result } else { '(호출 C 없음)' }), $r.OtherEnds, (Get-LineCount -Result $r -Line $script:rzCancelStop))) (J @('False/reclick', '', 0))
    # RS9′ - 지정 시각 없음(env 빈 값) · 같은 클릭 입력 → 승계 '' → 끝-IH 0 (앞 env 행 값이 새면 'continue' 로 11)
    $r = Invoke-ResumeRow @{ Name = 'RS9′'; Until = ''; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'RS9′' $r
    Assert-Case "RS9′ 지정 시각 없음 · retry-clicked · R3 → 재판단 0/0 · 판단값 '' · 재클릭 1 · 끝-IH 0 · 이어 감 안내 0" `
        (J @($r.VerdictCalls, $r.TimeVerdict, $r.RetrySends, (Get-ResumeEndIH $r), (& $continueCount $r))) (J @('0/0', '', 1, (Get-ResumeEndIHWant '0'), 0))

    # WA-X9 - retry-attempt · R3 Q · 지정 시각 (T 지남) → 재판단 1(재평가 자리) · 끝-멈춤 / (T 전) → 재판단 2(재평가 + 클릭 자리 재검사) · 재클릭 1
    $r = Invoke-ResumeRow @{ Name = 'WA-X9 T 지남'; Stage = 'retry-attempt'; Until = -30; Scenario = @{ Timeline = $r3Timeline } }
    Assert-ResumeCommon 'WA-X9 T 지남' $r
    $x9First = @($r.ReentryResults) | Select-Object -First 1
    Assert-Case 'WA-X9 T 지남 → Q 뒤 reclick · 첫 재판단 = 호출 C 반환 시각(재평가 자리 · Q 이상) · 재판단 1/1 · 끝-멈춤(재개 판단 time 1)' `
        (J @((Get-ReentryText $r), $(if ($null -ne $x9First) { & $atText $r ([double]$x9First.ReturnT) } else { '(호출 C 없음)' }), ([double]$r.VerdictAt -ge ($Q - $TIME_EPSILON)), $r.VerdictCalls, (Get-ResumeEndStop $r))) `
        (J @('reclick', 'True', 'True', '1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'time' -30))))
    $r = Invoke-ResumeRow @{ Name = 'WA-X9 T 전'; Stage = 'retry-attempt'; Until = 600; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'WA-X9 T 전' $r
    Assert-Case 'WA-X9 T 전 → 재판단 2/2 · 재클릭 1 · 호출 D entered · 끝-IH 11' (J @((Get-ReentryText $r), $r.VerdictCalls, $r.RetrySends, (Get-ResumeEndIH $r))) `
        (J @('reclick,entered', '2/2', 1, (Get-ResumeEndIHWant '11')))

    # RE-3 - 재평가 통과(T 전 · 예약 없음) 뒤 클릭 루프 첫 회전 짝 결측 1회(1초 재판독 - 재평가와 클릭 자리 재검사 사이의 유일한 틈) 안에 T(→ 'last') / FlagAt(→ 'safe-stop')
    $re3Scenario = @{ Timeline = $r3Timeline; PairMiss = @{ 1 = 'Retry' } }
    $re3AtRaw = Get-ResumeVerdictAt @{ Name = 'RE-3'; Stage = 'retry-attempt'; Scenario = $re3Scenario }
    Assert-True ('RE-3 전제 - 보정 첫 재판단 가상 초가 있음 ({0})' -f $(if ($null -ne $re3AtRaw) { Format-Seconds $re3AtRaw } else { '없음' })) ($null -ne $re3AtRaw) ''
    $re3At = [double]$re3AtRaw
    $r = Invoke-ResumeRow @{ Name = 'RE-3 T'; Stage = 'retry-attempt'; Until = ($re3At + 0.5); Scenario = $re3Scenario }
    Assert-ResumeCommon 'RE-3 T' $r
    Assert-True 'RE-3 T 전제 - 짝 결측 첫 줄 1(틈이 실제로 생김)' ((Get-ResumePrefixCount $r $RESUME_RETRY_MISS_PREFIX) -eq 1) ('짝 결측 줄 {0}' -f (Get-ResumePrefixCount $r $RESUME_RETRY_MISS_PREFIX))
    Assert-Case 'RE-3 T 재평가 통과 · 짝 결측 1초 안에 T → 직전 판단 time 1 · 재개 판단 0 · 재판단 2/2 · 끝-멈춤 · 입력 = Focus-Game 하나(첫 시도 기록 앞) · attempts 1 · retryClicks 0' `
        (J @((Get-ResumeEndStop $r), $r.VerdictCalls, $r.InputList, $r.Stage, $r.Attempts, $r.RetryClicks)) `
        (J @((Get-ResumeEndStopWant -ClickLine (Get-ResumeClickLine 'time' ($re3At + 0.5))), '2/2', 'Focus-Game', 'retry-attempt', 1, 0))
    $re3FlagScenario = @{ Timeline = $r3Timeline; PairMiss = @{ 1 = 'Retry' }; FlagAt = ($re3At + 0.5) }
    $r = Invoke-ResumeRow @{ Name = 'RE-3 예약'; Stage = 'retry-attempt'; Scenario = $re3FlagScenario }
    Assert-ResumeCommon 'RE-3 예약' $r
    Assert-True 'RE-3 예약 전제 - 짝 결측 첫 줄 1' ((Get-ResumePrefixCount $r $RESUME_RETRY_MISS_PREFIX) -eq 1) ('짝 결측 줄 {0}' -f (Get-ResumePrefixCount $r $RESUME_RETRY_MISS_PREFIX))
    Assert-Case 'RE-3 예약 재평가 통과 · 짝 결측 1초 안에 예약 → 직전 판단 안전 중지 1 · 재개 판단 0 · 재판단 1/1(클릭 자리는 예약에서 멈춤) · 끝-멈춤(복귀 순간 예약 있음) · attempts 1' `
        (J @((Get-ResumeEndStop $r), $r.VerdictCalls, $r.Attempts)) (J @((Get-ResumeEndStopWant -ClickLine (Get-ResumeClickLine 'safe') -Flag $true), '1/1', 1))

    # RE-5 - 커스텀 · retry-attempt · R3 Q 무변화 · 지정 시각 없음 → 재평가는 커스텀 순위를 안 봄(-CustomMode $false) → 재판단 '' 통과 · 재클릭 1 → 재입장 → 끝-IH 0
    $r = Invoke-ResumeRow @{ Name = 'RE-5'; Custom = $true; Stage = 'retry-attempt'; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'RE-5' $r
    Assert-Case "RE-5 커스텀 · retry-attempt · R3 → 판단값 '' · 재판단 2/2 · 재개 판단 0 · 재클릭 1 · 호출 D entered · 끝-IH 0" `
        (J @($r.TimeVerdict, $r.VerdictCalls, (Get-ResumePrefixCount $r $judgePrefix), $r.RetrySends, (Get-ReentryText $r), (Get-ResumeEndIH $r))) (J @('', '2/2', 0, 1, 'reclick,entered', (Get-ResumeEndIHWant '0')))

    # DV1 - retry-attempt · 시작부터 안전 중지 예약(FlagAt 0 - 첫 전진에 생김. 재개 경로가 예약을 처음 읽는 곳은 재평가) · R3 → 끝-멈춤 · 복귀 출구 코드 0 · 복귀 순간 예약 있음
    $r = Invoke-ResumeRow @{ Name = 'DV1'; Stage = 'retry-attempt'; Scenario = @{ Timeline = $r3Timeline; FlagAt = 0 } }
    Assert-ResumeCommon 'DV1' $r
    Assert-Case 'DV1 retry-attempt · 시작부터 예약 · R3 → 재개 판단 안전 중지 1 · 직전 판단 0 · 재판단 1/1 · 끝-멈춤(복귀 출구 코드 0 · 복귀 순간 예약 있음) · 기록 무변경' `
        (J @((Get-ReentryText $r), $r.VerdictCalls, (Get-ResumeEndStop $r), $r.Stage, $r.Attempts)) `
        (J @('reclick', '1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'safe-stop') -Flag $true), 'retry-attempt', 0))
    # DV2 - DV1 입력 + retry-clicked · 시작값 1 → 재평가 0(승계) · 클릭 자리도 commit 이라 예약을 보지 않음 · 재클릭 1 → 폴백 ① 'confirmed' 가 예약 소비
    $r = Invoke-ResumeRow @{ Name = 'DV2'; RetryClicks = 1; Scenario = @{ Timeline = $r3Timeline; FlagAt = 0 } }
    Assert-ResumeCommon 'DV2' $r
    $dv2FlagLeft = [IO.File]::Exists($safeStopFlagPath)
    Assert-Case 'DV2 retry-clicked · 시작값 1 · 예약 → 재판단 0/0 · 재클릭 1 · 호출 D reclick · 끝-확인(예약 소비 줄) · 행 뒤 예약 파일 없음 · attempts 1 · retryClicks 2' `
        (J @((Get-ReentryText $r), $r.VerdictCalls, $r.RetrySends, (Get-ResumeEndReady $r), $dv2FlagLeft, $r.Attempts, $r.RetryClicks)) `
        (J @('reclick,reclick', '0/0', 1, (Get-ResumeEndReadyWant -Flag $true), 'False', 1, 2))
    # DV3 - DV1 과 같은 시나리오(retry-attempt · 시작부터 안전 중지 예약 - 개발사항 DV '같은 시나리오 … 10초 안에 패널 출현 → 재평가 없이 B2') · Q 안 재매칭 패널(5초) → 호출 C 가
    #   패널을 보고 I · I 로 entered → 재평가 0(예약이 있어도 패널 = commit 증거라 다시 판단하지 않음) · 승계 → 끝-IH 0. 예약이 있어 재평가가 일찍 돌면 멈춤으로 드러남
    Assert-True ('DV3 전제 - 패널 시각 5초 < Q({0})' -f $Q) (5.0 -lt $Q) ''
    $r = Invoke-ResumeRow @{ Name = 'DV3'; Stage = 'retry-attempt'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'R3', 5.0, 'matching', 8.0, 'I')); FlagAt = 0 } }
    Assert-ResumeCommon 'DV3' $r
    Assert-Case 'DV3 retry-attempt · 시작부터 예약 · R3 → Q 안 패널 → I · I → 호출 C entered · 재판단 0/0 · 입력 0 · 재매칭 패널 확인 1 · 끝-IH 0 · attempts 0' `
        (J @((Get-ReentryText $r), $r.VerdictCalls, $r.Inputs, (Get-LineCount -Result $r -Line $script:rzPanelNotice), (Get-ResumeEndIH $r), $r.Attempts)) (J @('entered', '0/0', 0, 1, (Get-ResumeEndIHWant '0'), 0))
    # DV4 - 마지막 판 + retry-attempt → 재개 판단 마지막 판 1 · 끝-멈춤
    $r = Invoke-ResumeRow @{ Name = 'DV4'; Stage = 'retry-attempt'; LastRun = $true; Scenario = @{ Timeline = $r3Timeline } }
    Assert-ResumeCommon 'DV4' $r
    Assert-Case 'DV4 마지막 판 · retry-attempt · R3 → 재판단 1/1 · 끝-멈춤(재개 판단 마지막 판 1)' (J @($r.VerdictCalls, (Get-ResumeEndStop $r))) (J @('1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'last-run'))))
    # DV5 - R3 관측 중 5초에 예약 생성 → Q 뒤 재평가가 안전 중지 → 끝-멈춤 · 재판단 뒤 클릭 자리 0 · 복귀 순간 예약 있음
    Assert-True ('DV5 전제 - 예약 시각 5초 < Q({0})' -f $Q) (5 -lt $Q) ''
    $r = Invoke-ResumeRow @{ Name = 'DV5'; Stage = 'retry-attempt'; Scenario = @{ Timeline = $r3Timeline; FlagAt = 5 } }
    Assert-ResumeCommon 'DV5' $r
    Assert-Case 'DV5 retry-attempt · R3 · 5초 예약 → 첫 재판단 Q 이상 · 재판단 1/1 · 끝-멈춤(재개 판단 안전 중지 1 · 재클릭 0 · 복귀 순간 예약 있음)' `
        (J @(([double]$r.VerdictAt -ge ($Q - $TIME_EPSILON)), $r.VerdictCalls, (Get-ResumeEndStop $r))) (J @('True', '1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'safe-stop') -Flag $true)))
    # DV6 (가) - 손으로 클리어 뒤 재개(커스텀 · 지난 시계 - 수동 재개는 시계가 늘 지나 있음) · retry-clicked · R3 → 재평가 0 · 재클릭 1 · 재입장
    $r = Invoke-ResumeRow @{ Name = 'DV6 (가)'; Custom = $true; AtClicked = $PAST; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'DV6 (가)' $r
    Assert-Case 'DV6 (가) 커스텀 · 지난 시계 · retry-clicked · R3 → 재판단 0/0 · 재클릭 1 · 호출 D entered · 끝-IH 0' (J @($r.VerdictCalls, $r.RetrySends, (Get-ReentryText $r), (Get-ResumeEndIH $r))) `
        (J @('0/0', 1, 'reclick,entered', (Get-ResumeEndIHWant '0')))
    # DV6 (나) - 같음 · retry-attempt → Q 뒤 재평가 통과 · 재클릭 1 / 마지막 판이면 끝-멈춤
    $r = Invoke-ResumeRow @{ Name = 'DV6 (나)'; Custom = $true; Stage = 'retry-attempt'; AtAttempt = $PAST; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'DV6 (나)' $r
    Assert-Case 'DV6 (나) 커스텀 · 지난 시계 · retry-attempt · R3 → 첫 재판단 Q 이상 · 재판단 2/2 · 재클릭 1 · 끝-IH 0' (J @(([double]$r.VerdictAt -ge ($Q - $TIME_EPSILON)), $r.VerdictCalls, $r.RetrySends, (Get-ResumeEndIH $r))) `
        (J @('True', '2/2', 1, (Get-ResumeEndIHWant '0')))
    $r = Invoke-ResumeRow @{ Name = 'DV6 (나) 마지막 판'; Custom = $true; Stage = 'retry-attempt'; AtAttempt = $PAST; LastRun = $true; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'DV6 (나) 마지막 판' $r
    Assert-Case 'DV6 (나) 마지막 판 → 재판단 1/1 · 끝-멈춤(재개 판단 마지막 판 1 · 재클릭 0)' (J @($r.VerdictCalls, (Get-ResumeEndStop $r))) (J @('1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'last-run'))))
    # DV7 - 마무리 실행 + retry-attempt → 끝-멈춤(게이트 키의 행 - GUI 는 재개로 띄우지 않음)
    $r = Invoke-ResumeRow @{ Name = 'DV7'; Stage = 'retry-attempt'; FinishOnly = '1'; Scenario = @{ Timeline = $r3Timeline } }
    Assert-True 'DV7 전제 - 마무리 실행 표지 참(워커 읽기 문장이 env 를 읽음)' ([bool]$script:finishOnly) ''
    Assert-ResumeCommon 'DV7' $r
    Assert-Case 'DV7 마무리 실행 · retry-attempt · R3 → 재판단 1/1 · 끝-멈춤(재개 판단 마무리 실행 1)' (J @($r.VerdictCalls, (Get-ResumeEndStop $r))) (J @('1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'finish-only'))))
    # DV8 - 예약 + 마지막 판 + T 지남 → 사유 줄 = 안전 중지 1개만(순위)
    $r = Invoke-ResumeRow @{ Name = 'DV8'; Stage = 'retry-attempt'; LastRun = $true; Until = -30; Scenario = @{ Timeline = $r3Timeline; FlagAt = 0 } }
    Assert-ResumeCommon 'DV8' $r
    Assert-Case 'DV8 예약 + 마지막 판 + T 지남 → 재판단 1/1 · 끝-멈춤(재개 판단 = 안전 중지 1개만)' (J @($r.VerdictCalls, (Get-ResumeEndStop $r))) `
        (J @('1/1', (Get-ResumeEndStopWant -JudgeLine (Get-ResumeJudgeLine 'safe-stop') -Flag $true)))
}

# ----- E. 패널 뒤 취소 · 필드 취소 (RS11 의 '시작 R3' 변형은 같은 입력인 D 재평가 묶음 RS9 행이 봄 - 같은 입력의 행은 하나로) -----
function Test-ResumeRowsE {
    $T45 = [int]$timeoutEntry
    $Tpm = [int]$capturedTimeoutPartyMatch
    $W = [double]$memberFieldSettleSeconds
    $Q = [double]$abyssReclickQuietSeconds
    $waitSeconds = [double]$script:selectorWaitMs / 1000
    # RS10 (=WA-X6) - 시작 M → 취소 → R3 10초+ → 'cancelled' · 끝-취소 · 코드 11 0
    $r = Invoke-ResumeRow @{ Name = 'RS10'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching', 2.0, 'R3')) } }
    Assert-ResumeCommon 'RS10' $r
    Assert-Case "RS10 M@0 · R3@2~ → 호출 C cancelled · 끝-취소('다른 던전 가기' 1 · 재클릭 0)" (J @((Get-ReentryText $r), (Get-ResumeEndCancel $r), $r.OtherSends)) (J @('cancelled', (Get-ResumeEndCancelWant), 1))
    # RS11 (=WA-X8) M → R3 변형 - RS10 과 같음
    $r = Invoke-ResumeRow @{ Name = 'RS11'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching', 1.0, 'R3')) } }
    Assert-ResumeCommon 'RS11' $r
    Assert-Case 'RS11 M@0 · R3@1 → RS10 과 같음' (J @((Get-ReentryText $r), (Get-ResumeEndCancel $r), $r.OtherSends)) (J @('cancelled', (Get-ResumeEndCancelWant), 1))
    # WA-X11 - 선분기 M 표본 회전의 간접 양보 틈에 조작 시작 → 호출 C 첫 회전 게이트가 양보 → 양보 동안 M → R3(취소). 호출 C 자신의 패널 표본 0 이라 -PanelSeen 이 'cancelled' 를 냄
    $x11Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching', 2.5, 'R3')); SweepYield = @(New-Windows -Pairs @(0.0, 0.5)); Active = @(New-Windows -Pairs @(0.5, 3.0)) }
    $r = Invoke-ResumeRow @{ Name = 'WA-X11'; Scenario = $x11Scenario }
    Assert-ResumeCommon 'WA-X11' $r
    Assert-Case 'WA-X11 전제 - 호출 C 자신의 패널 표본 0(재매칭 패널 확인 안내 0 · 권장 인원 안내 0) · 호출 C 패널 초기값 참' `
        (J @((Get-LineCount -Result $r -Line $script:rzPanelNotice), (Get-LineCount -Result $r -Line $POPUP_NOTICE_LINE), (@($r.ReentryResults | ForEach-Object { $_.PanelSeen }) -join ','))) (J @(0, 0, 'True'))
    Assert-Case 'WA-X11 → 호출 C cancelled · 끝-취소 · 재클릭 0' (J @((Get-ReentryText $r), (Get-ResumeEndCancel $r))) (J @('cancelled', (Get-ResumeEndCancelWant)))
    # RF1 - 우연한 만남 · 호출 C(M) → U → F 지속 · 시계 안 → 'field-cancelled' · 끝-필드취소 · 시간 초과 문구 0 · 재개 필드 문구 0
    $r = Invoke-ResumeRow @{ Name = 'RF1'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching', 2.0, 'U', 4.0, 'F')) } }
    Assert-ResumeCommon 'RF1' $r
    Assert-Case 'RF1 우연한 만남 · M → U → F 지속 → 호출 C field-cancelled · 끝-필드취소 · 시간 초과 줄 0 · 재개 필드 줄 0' `
        (J @((Get-ReentryText $r), (Get-ResumeEndFieldCancel $r), (Get-LineCount -Result $r -Line $script:rzNoneParty), (Get-LineCount -Result $r -Line $script:rzFieldStop))) `
        (J @('field-cancelled', (Get-ResumeEndFieldCancelWant), 0, 0))
    # RF2 - 혼자하기 · 호출 C(R3) → F 지속 → 'field-cancelled' 0 · B(T45) 에 끝-none (콜론 꼴을 지키는 행 - 공백 꼴이면 혼자하기에도 필드 결과가 켜짐)
    Assert-True ('RF2 전제 - R3 → F 간격 2초 < Q({0})' -f $Q) (2.0 -lt $Q) ''
    $r = Invoke-ResumeRow @{ Name = 'RF2'; Mode = 'solo'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'R3', 2.0, 'F')) } }
    Assert-ResumeCommon 'RF2' $r
    Assert-Case 'RF2 혼자하기 · R3 → F 지속 → 호출 C timeout(필드 취소 0) · 끝-none(혼자하기 문구) · 끝 = T45 무렵' `
        (J @((Get-ReentryText $r), (Get-ResumeEndNone $r), (Test-NearTime $r.EndT $T45))) (J @('timeout', (Get-ResumeEndNoneWant 'solo'), 'True'))
    # RF3 - 우연한 만남 · (가) 남은 3초 < W · 호출 C → F 지속 → W 전 'timeout' · 끝-none / (나) 지난 시계 → 첫 유효 회전 'timeout'
    Assert-True ('RF3 전제 - 남은 3초 < W({0})' -f $W) (3 -lt $W) ''
    $r = Invoke-ResumeRow @{ Name = 'RF3 (가)'; AtClicked = ($Tpm - 3); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching', 0.5, 'F')) } }
    Assert-ResumeCommon 'RF3 (가)' $r
    Assert-Case 'RF3 (가) 남은 3초 · M → F 지속 → 호출 C timeout · 끝-none · 끝 < W' (J @((Get-ReentryText $r), (Get-ResumeEndNone $r), ($r.EndT -lt $W))) (J @('timeout', (Get-ResumeEndNoneWant 'party'), 'True'))
    $r = Invoke-ResumeRow @{ Name = 'RF3 (나)'; AtClicked = ($Tpm + 60); Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'matching', 0.5, 'F')) } }
    Assert-ResumeCommon 'RF3 (나)' $r
    Assert-Case 'RF3 (나) 지난 시계 · M → F → 호출 C 첫 유효 회전 timeout · 끝-none · 끝 < 선분기 회전 대기' (J @((Get-ReentryText $r), (Get-ResumeEndNone $r), ($r.EndT -lt $waitSeconds))) (J @('timeout', (Get-ResumeEndNoneWant 'party'), 'True'))
    # RF4 (5c-3) - 호출 D(재클릭 뒤 M → F 지속 · W 이상) → 'field-cancelled' → 끝-필드취소(입력 0 대신 재클릭 회전의 Focus-Game · Click-GamePoint) · 전송 1
    $r = Invoke-ResumeRow @{ Name = 'RF4'; Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'R3')); RetrySend = @{ 1 = @(@(1, 'matching'), @(3, 'F')) } } }
    Assert-ResumeCommon 'RF4' $r
    Assert-True 'RF4 전제 - F 는 호출 D 의 M 표본 뒤(재매칭 패널 확인 1)' ((Get-LineCount -Result $r -Line $script:rzPanelNotice) -eq 1) ('패널 확인 {0}' -f (Get-LineCount -Result $r -Line $script:rzPanelNotice))
    Assert-Case 'RF4 R3 → reclick → 재클릭 1 → M → F 지속 → 호출 D field-cancelled · 끝-필드취소(입력 = 재클릭 회전 둘) · 시간 초과 줄 0 · 재개 필드 줄 0 · 선분기 필드 확정 줄 0' `
        (J @((Get-ReentryText $r), $r.RetrySends, $r.InputList, (Get-ResumeEndFieldCancel $r), (Get-LineCount -Result $r -Line $script:rzNoneParty), (Get-LineCount -Result $r -Line $script:rzFieldStop),
            @(Get-PatternLines -Result $r -Pattern $S3_PATTERN).Count)) `
        (J @('reclick,field-cancelled', 1, 'Focus-Game / Click-GamePoint 636,654', (Get-ResumeEndFieldCancelWant 2), 0, 0, 0))
}

# ----- F. 재클릭 · 상한 · 폴백 · 기록 실패 (5c-3 - 5c-2 의 'reclick' 미처리 중간 행 RC0 을 이 묶음이 대신함: 호출 C 'reclick' = RCK1 첫 칸, 재클릭은 RCK1 · RCK2) -----
function Test-ResumeRowsF {
    $r3Timeline = @(New-Timeline -Pairs @(0, 'R3'))
    $reenterSend = @{ 1 = @(@(1, 'U'), @(4, 'I')) }
    $ihWant = Get-ResumeEndIHWant '0'
    $insideAt = 30.0   # 호출 E 행의 던전 안 시각 - 헬퍼를 부른 가상 초보다 뒤(행 앞 전제 단언). 그 앞에 두면 클릭 루프 · 짝 판독이 읽어 흐름이 바뀜

    # RCK1 - retry-clicked · 시작값 0 · 첫 시도 수 1 · 40초 전 → 재클릭 1: 첫 시도 기록(attempts 1 → 2) → 전송 → 전송 기록(retryClicks +1 · at.retryClicked = 전송 가상 시각 - 옛 값 40초 전에서
    #   갱신) → 재입장. 첫 시도 수를 1 로 시작해야 '+1' 과 '= 1' 이 갈림(운영의 retry-* 항목도 1 이상)
    $r = Invoke-ResumeRow @{ Name = 'RCK1'; AtClicked = 40; Attempts = 1; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'RCK1' $r
    $rck1Send = @($r.RetrySendTimes) | Select-Object -First 1
    $rck1Want = $(if ($null -ne $rck1Send) { $VIRTUAL_BASE.AddTicks([long][Math]::Round([double]$rck1Send * 1e7)).ToString('o') } else { '(전송 없음)' })
    $rck1Old = $VIRTUAL_BASE.AddSeconds(-40).ToString('o')
    Assert-Case 'RCK1 retry-clicked · 시작값 0 · 첫 시도 수 1 · 40초 전 · R3 → 호출 C reclick · 재판단 0/0 · 재클릭 1 · attempts 2(+1) · retryClicks 1 · at.retryClicked = 전송 가상 시각(옛 값과 다름) · 저장 셋(첫 시도 · 전송 · 재입장) · 끝-IH 0' `
        (J @((Get-ReentryText $r), $r.VerdictCalls, $r.RetrySends, $r.Attempts, $r.RetryClicks, $r.AtRetryClicked, ($r.AtRetryClicked -cne $rck1Old), $r.UpdateTags, (Get-ResumeEndIH $r))) `
        (J @('reclick,entered', '0/0', 1, 2, 1, $rck1Want, 'True', 'selector#1:changed selector#2:changed selector#3:changed', $ihWant))

    # RCK2 - retry-attempt · 첫 시도 수 1 → 재판단 2(재평가 + 클릭 자리) · attempts 1 → 2 · 전송 1 · 전송 기록이 stage 를 retry-clicked 로 · retryClicks 1. 행 끝 stage 는 재입장 기록이 덮어
    #   reentered 라 명세 칸의 'Stage retry-clicked' 는 호출 D 를 시작하는 순간(전송 기록 직후)의 stage 로 봄(감시 StageAtCall - 호출 C 순간은 retry-attempt). 네 사건의 차례는 ④ RC6 · 5C-S2 가 고정
    $r = Invoke-ResumeRow @{ Name = 'RCK2'; Stage = 'retry-attempt'; Attempts = 1; Scenario = @{ Timeline = $r3Timeline; RetrySend = $reenterSend } }
    Assert-ResumeCommon 'RCK2' $r
    Assert-Case 'RCK2 retry-attempt · 첫 시도 수 1 · R3 → 재판단 2/2 · attempts 2(+1) · 재클릭 1 · retryClicks 1 · 호출 C · D 순간 stage = retry-attempt · retry-clicked(전송 기록) · 저장 셋 changed · 끝-IH 0' `
        (J @((Get-ReentryText $r), $r.VerdictCalls, $r.Attempts, $r.RetrySends, $r.RetryClicks, (@($r.ReentryResults | ForEach-Object { $_.StageAtCall }) -join ','), $r.UpdateTags, (Get-ResumeEndIH $r))) `
        (J @('reclick,entered', '2/2', 2, 1, 1, 'retry-attempt,retry-clicked', 'selector#1:changed selector#2:changed selector#3:changed', $ihWant))

    # RCK3 - 재클릭 앞 첫 시도 기록 실패(선분기 단계 저장 #1 에 잠금 한 번) · 헬퍼 'matching' → [경고] · 클릭 0 · '다른 던전 가기' 대기 없이(-ExitOnly) 폴백 ② → 호출 E(보고 끔) entered → 끝-IH
    $rck3Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'R3', $insideAt, 'I')); HelperResult = 'matching'; LockPlan = @(@{ Phase = 'selector'; Ordinal = 1; Mode = 'once' }) }
    $r = Invoke-ResumeRow @{ Name = 'RCK3'; Scenario = $rck3Scenario }
    Assert-ResumeCommon 'RCK3' $r
    $rck3Helper = @($r.HelperTimes) | Select-Object -First 1
    Assert-True ('RCK3 전제 - I 시각({0}) > 헬퍼 호출 시각' -f $insideAt) (($null -ne $rck3Helper) -and ($insideAt -gt [double]$rck3Helper)) ('헬퍼 [{0}]' -f (@($r.HelperTimes | ForEach-Object { Format-Seconds $_ }) -join ','))
    $rck3CallE = @($r.ReentryResults) | Select-Object -Skip 1 -First 1
    Assert-Case "RCK3 기록 실패 → [경고] 1 · 클릭 0(입력 = Focus-Game 하나 - 기록 앞) · 다른 던전 대기 0(전송 0 · 짝 결측 줄 0 · 폴백 ② 사유 줄 0) · 끝(other) ready/NC · 헬퍼 1 · 호출 E(보고 끔) entered · 끝-IH 0" `
        (J @((Get-LineCount -Result $r -Line $script:rzRecordFailWarn), $r.RetrySends, $r.InputList, $r.OtherSends, (Get-ResumePrefixCount $r $RESUME_OTHER_MISS_PREFIX), (Get-ResumeFallbackLines $r),
            $r.OtherEnds, $r.ExitClicks, (Get-ReentryText $r), $(if ($null -ne $rck3CallE) { [string]$rck3CallE.Report } else { '(호출 E 없음)' }), (Get-ResumeEndIH $r))) `
        (J @(1, 0, 'Focus-Game', 0, 0, 0, 'ready/NC', 1, 'reclick,entered', 'False', $ihWant))
    Assert-Case 'RCK3 → 저장 = 잠김 · 재입장 기록 changed · attempts 0(첫 시도 기록 실패)' (J @($r.UpdateTags, $r.Attempts)) (J @('selector#1:locked selector#2:changed', 0))

    # RCK4 - 같음 · 헬퍼 'clicked'(패널 아님) → 호출 E 0 · 복귀 루프(코드 0 · 예약 없음이라 돌아옴) · 복귀 완료 줄 · 코드 0
    $r = Invoke-ResumeRow @{ Name = 'RCK4'; Scenario = @{ Timeline = $r3Timeline; LockPlan = @(@{ Phase = 'selector'; Ordinal = 1; Mode = 'once' }) } }
    Assert-ResumeCommon 'RCK4' $r
    Assert-Case "RCK4 기록 실패 · 헬퍼 'clicked' → [경고] 1 · 호출 E 0 · 복귀 [0||False] · 정지 줄 = 복귀 완료 · exit 0 · 클릭 0 · 다른 던전 전송 0 · 끝(other) ready/NC · stage 그대로 · attempts 0" `
        (J @((Get-LineCount -Result $r -Line $script:rzRecordFailWarn), (Get-ReentryText $r), $r.ReturnCalls, (Get-StopLines $r), $r.ExitCode, $r.RetrySends, $r.OtherSends, $r.ExitClicks, $r.OtherEnds, $r.Stage, $r.Attempts)) `
        (J @(1, 'reclick', '0||False', $script:rzReadyDone, '0', 0, 0, 1, 'ready/NC', 'retry-clicked', 0))

    # RE-4 - RE-3 꼴(짝 결측 1회의 1초 안에 T / FlagAt) + 헬퍼 'matching' → 클릭 자리 'last' · 'safe-stop' 은 멈춤 끝(맥락 C - 헬퍼 결과를 버림) → 호출 E 0 · 복귀 1
    $re4Scenario = @{ Timeline = $r3Timeline; PairMiss = @{ 1 = 'Retry' }; HelperResult = 'matching' }
    $re4AtRaw = Get-ResumeVerdictAt @{ Name = 'RE-4'; Stage = 'retry-attempt'; Scenario = $re4Scenario }
    Assert-True ('RE-4 전제 - 보정 첫 재판단 가상 초가 있음 ({0})' -f $(if ($null -ne $re4AtRaw) { Format-Seconds $re4AtRaw } else { '없음' })) ($null -ne $re4AtRaw) ''
    $re4At = [double]$re4AtRaw
    $r = Invoke-ResumeRow @{ Name = 'RE-4 T'; Stage = 'retry-attempt'; Until = ($re4At + 0.5); Scenario = $re4Scenario }
    Assert-ResumeCommon 'RE-4 T' $r
    Assert-Case "RE-4 T 클릭 자리 'last' · 헬퍼 'matching' → 호출 E 0 · 복귀 1(예약 없음) · 끝-멈춤(직전 판단 time 1) · [경고] 0 · 끝(other) 0" `
        (J @((Get-ReentryText $r), (Get-ResumeEndStop $r), (Get-ResumePrefixCount $r '[경고]'), $r.OtherEnds)) (J @('reclick', (Get-ResumeEndStopWant -ClickLine (Get-ResumeClickLine 'time' ($re4At + 0.5))), 0, ''))
    $re4FlagScenario = @{ Timeline = $r3Timeline; PairMiss = @{ 1 = 'Retry' }; HelperResult = 'matching'; FlagAt = ($re4At + 0.5) }
    $r = Invoke-ResumeRow @{ Name = 'RE-4 예약'; Stage = 'retry-attempt'; Scenario = $re4FlagScenario }
    Assert-ResumeCommon 'RE-4 예약' $r
    Assert-Case "RE-4 예약 클릭 자리 'safe-stop' · 헬퍼 'matching' → 호출 E 0 · 복귀 1(복귀 순간 예약 있음) · 끝-멈춤(직전 판단 안전 중지 1) · 끝(other) 0" `
        (J @((Get-ReentryText $r), (Get-ResumeEndStop $r), $r.OtherEnds)) (J @('reclick', (Get-ResumeEndStopWant -ClickLine (Get-ResumeClickLine 'safe') -Flag $true), ''))

    # FB14 - 시작값 2 / 1 / 0 · R3 지속 → 전송 0 / 1 / 2 · '두 번' 줄 · 폴백 ① 'confirmed' · 코드 0. 명세 '$safeStopFlagPath 지금대로' 는 예약 없는 'confirmed' 갈래로 읽음 - 그 계약은
    #   끝-확인의 정지 줄이 복귀 완료 줄(예약 소비 줄이 아님)인 칸입니다(예약을 소비하는 갈래는 DV2)
    foreach ($fbStart in @(2, 1, 0)) {
        $r = Invoke-ResumeRow @{ Name = "FB14 $fbStart"; RetryClicks = $fbStart; Scenario = @{ Timeline = $r3Timeline } }
        Assert-ResumeCommon "FB14 $fbStart" $r
        $fbReentryWant = (@(1..(3 - $fbStart) | ForEach-Object { 'reclick' })) -join ','
        Assert-Case ("FB14 시작값 {0} · R3 지속 → 재클릭 {1} · 한 번 더 {2} · 재입장 대기 [{3}] · 끝-확인(정지 줄 = 복귀 완료 줄 - 예약 소비 줄 아님) · retryClicks 2" -f $fbStart, (2 - $fbStart), [int]($fbStart -eq 0), $fbReentryWant) `
            (J @($r.RetrySends, (Get-LineCount -Result $r -Line $script:rzOnceMoreLine), (Get-ReentryText $r), (Get-ResumeEndReady $r), $r.RetryClicks)) `
            (J @((2 - $fbStart), [int]($fbStart -eq 0), $fbReentryWant, (Get-ResumeEndReadyWant), 2))
    }

    # FB18 - 상한(시작값 2) → 폴백 ① 'no-pair'(다른 던전 짝 결측 둘) → 폴백 ② 헬퍼 'matching' → 재개라 호출 E → entered → 끝-IH(완료 줄 nonce = 받은 값 - 끝(retry) 의 -Nonce 가 끝(other) 을 거쳐 옴)
    $fb18Scenario = @{ Timeline = @(New-Timeline -Pairs @(0, 'R3', $insideAt, 'I')); PairMiss = @{ 1 = 'Other'; 2 = 'Other' }; HelperResult = 'matching' }
    $r = Invoke-ResumeRow @{ Name = 'FB18'; RetryClicks = 2; Scenario = $fb18Scenario }
    Assert-ResumeCommon 'FB18' $r
    $fb18Helper = @($r.HelperTimes) | Select-Object -First 1
    Assert-True ('FB18 전제 - I 시각({0}) > 헬퍼 호출 시각' -f $insideAt) (($null -ne $fb18Helper) -and ($insideAt -gt [double]$fb18Helper)) ('헬퍼 [{0}]' -f (@($r.HelperTimes | ForEach-Object { Format-Seconds $_ }) -join ','))
    $fb18CallE = @($r.ReentryResults) | Select-Object -Skip 1 -First 1
    Assert-Case "FB18 상한 → 'no-pair'(짝 결측 줄 1 · 폴백 ② no-pair 사유 줄 1) → 헬퍼 'matching' → 호출 E(보고 끔) entered · 끝(other) ready/NC · 전송 0/0 · 헬퍼 1 · 끝-IH 0(완료 줄 nonce NC)" `
        (J @((Get-ResumePrefixCount $r $RESUME_OTHER_MISS_PREFIX), (Get-LineCount -Result $r -Line $script:rzFallbackNoPair), (Get-ReentryText $r), $(if ($null -ne $fb18CallE) { [string]$fb18CallE.Report } else { '(호출 E 없음)' }),
            $r.OtherEnds, ('{0}/{1}' -f $r.RetrySends, $r.OtherSends), $r.ExitClicks, (Get-ResumeEndIH $r))) `
        (J @(1, 1, 'reclick,entered', 'False', 'ready/NC', '0/0', 1, $ihWant))

    # OW1r - 상한 · '다른 던전 가기' 전송 → 3초에 선택 화면 → 'confirmed'(출처 발급 1 = confirmed ∧ 전송 1 - 발급은 전송 확인 갈래 한 곳) · 전송 1
    $r = Invoke-ResumeRow @{ Name = 'OW1r'; RetryClicks = 2; Scenario = @{ Timeline = $r3Timeline; OtherSend = @{ 1 = @(, @(3, 'SEL')) } } }
    Assert-ResumeCommon 'OW1r' $r
    Assert-Case "OW1r 상한 · 전송 → 3초에 선택 화면 → 끝-확인('confirmed' · 다른 던전 전송 1 = 발급 1) · 재클릭 0" (J @((Get-ResumeEndReady $r), $r.RetrySends)) (J @((Get-ResumeEndReadyWant), 0))

    # OW10r - 상한 · Other 없음 2회 → 'no-pair' · 전송 0 → 폴백 ② 헬퍼 'clicked' → 복귀 · 코드 0
    $r = Invoke-ResumeRow @{ Name = 'OW10r'; RetryClicks = 2; Scenario = @{ Timeline = $r3Timeline; PairMiss = @{ 1 = 'Other'; 2 = 'Other' } } }
    Assert-ResumeCommon 'OW10r' $r
    Assert-Case "OW10r 상한 · 짝 결측 둘 → 'no-pair'(폴백 ② no-pair 사유 줄 1 · 짝 결측 줄 1) · 다른 던전 전송 0 · 헬퍼 1 · 복귀 [0||False] · 정지 줄 = 복귀 완료 · exit 0 · 재입장 대기는 호출 C 하나" `
        (J @((Get-LineCount -Result $r -Line $script:rzFallbackNoPair), (Get-ResumePrefixCount $r $RESUME_OTHER_MISS_PREFIX), $r.OtherSends, $r.ExitClicks, $r.ReturnCalls, (Get-StopLines $r), $r.ExitCode, (Get-ReentryText $r))) `
        (J @(1, 1, 0, 1, '0||False', $script:rzReadyDone, '0', 'reclick'))

    # OW14r - 상한 · 전송 뒤 1초에 던전 안 2연속 → 'inside'(전송 있음 - 오클릭 의심 정지) · 진단 · 코드 4 · 클릭 추가 0
    $r = Invoke-ResumeRow @{ Name = 'OW14r'; RetryClicks = 2; Scenario = @{ Timeline = $r3Timeline; OtherSend = @{ 1 = @(, @(1, 'I')) } } }
    Assert-ResumeCommon 'OW14r' $r
    Assert-Case "OW14r 상한 · 전송 뒤 I 2연속 → 'inside' 정지 줄 · 진단 · exit 4 · 다른 던전 전송 1 · 재클릭 0 · 헬퍼 0 · 복귀 0" `
        (J @((Get-StopLines $r), (Get-DiagText $r), $r.ExitCode, $r.OtherSends, $r.RetrySends, $r.ExitClicks, $r.ReturnCalls)) `
        (J @($script:rzOtherInsideStop, $script:rzOtherInsideDiag, '4', 1, 0, 0, ''))
}

# ===== ⑲ 정적 (주석 뺀 사본 · AST - 구현 명세 ⑤c 3.7 의 ⑲ 몫) · HS0 · exit 이름별 수 =====
function Get-TopLevelTexts {
    # 파일의 최상위 함수 · 이름 지정 변수 대입 → 이름 → 주석 뺀 사본 공백 정규화 글자 (HS0)
    param([string]$Path, [string[]]$VariableNames)
    $levelTokens = $null
    $levelErrors = $null
    $levelAst = [Parser]::ParseFile($Path, [ref]$levelTokens, [ref]$levelErrors)
    $levelCode = Remove-CommentsByTokens -Text $levelAst.Extent.Text -Tokens $levelTokens
    $levelMap = @{}
    foreach ($levelStatement in $levelAst.EndBlock.Statements) {
        $levelKey = ''
        if ($levelStatement -is [FunctionDefinitionAst]) { $levelKey = 'function:' + $levelStatement.Name }
        elseif (($levelStatement -is [AssignmentStatementAst]) -and ($VariableNames -contains $levelStatement.Left.Extent.Text)) { $levelKey = 'variable:' + $levelStatement.Left.Extent.Text }
        if (-not $levelKey) { continue }
        $levelMap[$levelKey] = (($levelCode.Substring($levelStatement.Extent.StartOffset, $levelStatement.Extent.EndOffset - $levelStatement.Extent.StartOffset)) -replace '\s+', ' ').Trim()
    }
    return $levelMap
}

function Test-ResumeHs0 {
    # HS0 (구현 명세 ⑤c 3.3) - 고치지 않은 복사본 = ⑱′ 같은 이름(주석 뺀 사본). 넓힌 넷은 뺌. 명세가 적은 이름(엔진 함수 · 덮기 · 감시 · 모의 · 몸통 표 · 카탈로그)은 모두 견준 쪽에 있어야 함
    $hsVariables = @('$FLOW_MOCK_BODIES', '$SCREEN_CATALOG', '$BOTTOM_TEXTS')
    $hsWidened = @('function:Step-VirtualClock', 'function:Set-Scenario', 'function:Reset-FlowState', 'function:Invoke-StubSweep')
    $hsRequired = @('Get-VirtualElapsed', 'Add-StubEvent', 'Enter-StubTurn', 'New-Timeline', 'New-Windows', 'Find-StubWindow', 'Get-ScreenSpec', 'Get-StubScreenKey', 'Register-StubCaptureFail',
        'Register-StubCaptureSuccess', 'Get-StubFailTotalMs', 'Invoke-StubRead', 'Invoke-StubFlagRead', 'Invoke-StubProbe', 'Invoke-StubYieldWait', 'Start-Sleep', 'Get-Date',
        'Invoke-AbyssHandoffStart', 'Open-StubJournalLock', 'Read-AbyssJournal', 'Update-AbyssJournal', 'Write-RunLog', 'Stop-WorkerTailExit' | ForEach-Object { 'function:' + $_ }) +
        @($hsVariables | ForEach-Object { 'variable:' + $_ })
    $hsMine = Get-TopLevelTexts -Path $PSCommandPath -VariableNames $hsVariables
    $hsTheirs = Get-TopLevelTexts -Path (Join-Path $PSScriptRoot 'test_abyss_handoff_start.ps1') -VariableNames $hsVariables
    $hsCompared = @($hsMine.Keys | Where-Object { $hsTheirs.ContainsKey($_) -and ($hsWidened -notcontains $_) } | Sort-Object)
    $hsDiffer = @($hsCompared | Where-Object { $hsMine[$_] -cne $hsTheirs[$_] })
    $hsMissing = @($hsRequired | Where-Object { $hsCompared -notcontains $_ })
    Assert-Case ('HS0 복사본 = ⑱′ 같은 이름(주석 뺀 사본 · 견준 것 {0}개 · 넓힌 넷 뺌) - 다른 것 · 명세 대상 중 빠진 것' -f $hsCompared.Count) (J @(($hsDiffer -join ','), ($hsMissing -join ','))) (J @('', ''))
    Assert-Case 'HS0 넓힌 넷은 ⑱′ 와 다름(넓힘이 실제로 들어감)' (@($hsWidened | Where-Object { $hsMine.ContainsKey($_) -and $hsTheirs.ContainsKey($_) -and ($hsMine[$_] -cne $hsTheirs[$_]) }).Count) 4
}

function Test-ResumeExitCounts {
    # exit 이름별 수 (구현 명세 ⑤c 3.3 'exit' 5c-3 열) - 워커 원문 AST 에서 함수 이름으로 셈(추출 폐쇄 아님 · 합 아님 · 기대 리터럴)
    $exitWant = [ordered]@{ 'Invoke-AbyssHandoffStart' = '5'; 'Stop-AbyssHandoffOverlay' = '1'; 'Complete-AbyssOtherSelection' = '7'; 'Complete-AbyssRetrySelection' = '1';
        'Complete-AbyssInsideHandoff' = '2'; 'Stop-AbyssReentryTimeout' = '2'; 'Stop-AbyssReentryFieldCancelled' = '1'; 'Complete-AbyssResumeStop' = '1'; 'Complete-AbyssResumeWait' = '0' }
    $exitActual = @(foreach ($exitName in $exitWant.Keys) {
            $exitNode = Get-FlowFunctionNode $exitName
            '{0}={1}' -f $exitName, $(if ($null -eq $exitNode) { '(없음)' } else { [string]@($exitNode.FindAll({ param($node) $node -is [ExitStatementAst] }, $true)).Count })
        })
    Assert-Case 'exit 이름별 수(5c-3 끝 - 끝(retry) 1 · 재개 끝 0 은 ④ FC-S16 · 5C-S8 과 같은 값 · 멈춤 끝 1)' ($exitActual -join ' · ') ((@($exitWant.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value })) -join ' · ')
}

function Get-ResumeStatementShape {
    # 5C-S2 렌더 - if 문은 '라벨[본문]'(라벨 = 첫 절 조건 · "$reentryResult -eq '낱말'" 꼴이면 낱말 / 본문 = 첫 절 문장마다 ' ; ' - if 면 같은 규칙으로 재귀, 아니면 첫 명령 이름 · 명령이
    #   없으면 '(명령 아님)'). 최상위의 if 가 아닌 문장은 주석 뺀 사본 공백 정규화
    param($Statement, [bool]$Nested = $false)
    if ($Statement -is [IfStatementAst]) {
        $shapeCondition = Get-NormalizedCode -Node $Statement.Clauses[0].Item1
        $shapeLabel = $shapeCondition
        if ($shapeCondition -cmatch "^\`$reentryResult -eq '([a-z-]+)'$") { $shapeLabel = $Matches[1] }
        $shapeBody = (@($Statement.Clauses[0].Item2.Statements | ForEach-Object { Get-ResumeStatementShape -Statement $_ -Nested $true })) -join ' ; '
        return ('{0}[{1}]' -f $shapeLabel, $shapeBody)
    }
    if ($Nested) {
        $shapeCommand = @($Statement.FindAll({ param($node) $node -is [CommandAst] }, $true)) | Select-Object -First 1
        if ($null -ne $shapeCommand) { return $shapeCommand.GetCommandName() }
        return '(명령 아님)'
    }
    return (Get-NormalizedCode -Node $Statement)
}

function Get-ResumeWorkerLine {
    # 노드 시작 자리가 든 줄 전체(주석 뺀 사본 - 위치가 원문과 같음)를 Trim - 5C-S8 '줄 단독' (④ Get-LineCode 꼴)
    param($Node)
    if ($null -eq $Node) { return '(없음)' }
    $lineFrom = $workerCode.LastIndexOf([char]10, [Math]::Max(0, $Node.Extent.StartOffset - 1)) + 1
    $lineTo = $workerCode.IndexOf([char]10, $Node.Extent.StartOffset)
    if ($lineTo -lt 0) { $lineTo = $workerCode.Length }
    return $workerCode.Substring($lineFrom, $lineTo - $lineFrom).Trim()
}

function Test-ResumeStatic {
    $selectorNode = Get-FlowFunctionNode 'Invoke-AbyssHandoffStart'
    # 5C-S1 - Set-AbyssResumeCommit 본문 = 두 대입 원문 · 명령 0
    $commitNode = Get-FlowFunctionNode 'Set-AbyssResumeCommit'
    $commitText = $(if ($null -ne $commitNode) { (@($commitNode.Body.EndBlock.Statements | ForEach-Object { Get-NormalizedCode -Node $_ })) -join ' ; ' } else { '(없음)' })
    $commitCommands = $(if ($null -ne $commitNode) { @($commitNode.FindAll({ param($node) $node -is [CommandAst] }, $true)).Count } else { -1 })
    Assert-Case '5C-S1 Set-AbyssResumeCommit 본문 = 판단값 대입 · commit 표지 대입(원문) · 명령 0' (J @($commitText, $commitCommands)) `
        (J @("`$script:abyssRetryTimeVerdict = `$(if (`$null -ne `$script:abyssUntil) { 'continue' } else { '' }) ; `$script:abyssRetryCommitted = `$true", 0))
    # 5C-S2 (전체 - 구현 명세 ⑤c 3.7) - 재개 끝 최상위 문장 차례 = nonce · 결과 대입 < 승계 if < entered < cancelled < field-cancelled < timeout < 재평가 if < 끝(retry) 호출 < record-failed if <
    #   마지막 문장 Complete-AbyssResumeStop. if 는 '조건[본문]'(본문의 if 는 같은 규칙으로 재귀 - 재평가 exit 갈래 끝의 멈춤 끝까지 보여 5C-M10 을 잡음), if 가 아닌 본문 문장은 첫 명령 이름.
    #   'reclick' 문자열 0 은 5c-2 접두부 단언을 이어 둔 항 - 'reclick' 은 갈래 조건이 아니라 끝(retry) 로 흐르는 나머지 길입니다
    $waitNode = Get-FlowFunctionNode 'Complete-AbyssResumeWait'
    $waitShape = '(없음)'
    $waitReclick = -1
    if ($null -ne $waitNode) {
        $waitShape = (@($waitNode.Body.EndBlock.Statements | ForEach-Object { Get-ResumeStatementShape -Statement $_ })) -join ' < '
        $waitReclick = @(Get-StringNodes -Node $waitNode | Where-Object { ([string]$_.Value).Contains('reclick') }).Count
    }
    Assert-Case "5C-S2 (전체) 재개 끝 문장 차례 = nonce · 결과 대입 < 승계 if < entered < cancelled < field-cancelled < timeout < 재평가 if < 끝(retry) 호출 < record-failed if < 마지막 문장 Complete-AbyssResumeStop · 'reclick' 문자열 0" `
        (J @($waitShape, $waitReclick)) `
        (J @(("`$resumeNonce = [string]`$script:handoff.Nonce < `$reentryResult = [string]`$Reentry.Result < ([string]`$script:handoff.Stage -eq 'retry-clicked') -or [bool]`$Reentry.PanelSeen -or " +
                "(`$reentryResult -eq 'entered')[Set-AbyssResumeCommit] < entered[Complete-AbyssInsideHandoff] < cancelled[Complete-AbyssOtherSelection] < field-cancelled[Stop-AbyssReentryFieldCancelled] < " +
                "timeout[Stop-AbyssReentryTimeout] < -not `$script:abyssRetryCommitted[Resolve-AbyssRewardDecision ; [string]`$resumeGate.Action -eq 'exit'[(명령 아님) ; Write-RunLog ; Complete-AbyssResumeStop]] < " +
                "`$retryEnd = Complete-AbyssRetrySelection -Game `$Game -Nonce `$resumeNonce -PriorSends ([int]`$script:handoff.RetryClicks) < " +
                "`$retryEnd -eq 'record-failed'[Write-RunLog ; Complete-AbyssOtherSelection] < Complete-AbyssResumeStop -Game `$Game"), 0))
    # 5C-S3 - 재평가: 결정 호출 1 · 감싼 조건 원문 · 인자 다섯(-CustomMode $false 상수 · Next* 0 · CurrentItem 0 - 이름 목록 자체가 고정) · switch 1 · 사유 키 = 결정 함수 순위 ① 값(소스 캡처 -
    #   첫 '-not $CustomMode' if 앞 if 들의 반환 해시 Reason) · 재판단은 이 자리 1(-TimeVerdict 인자 - W-M7)
    $decisionCalls = @(Get-CommandNodes -Node $waitNode -Name 'Resolve-AbyssRewardDecision')
    $s3Condition = '(결정 호출 {0}개)' -f $decisionCalls.Count
    $s3Arguments = ''
    if ($decisionCalls.Count -eq 1) {
        $s3Condition = @(Get-EnclosingConditions -Node $decisionCalls[0]) -join ' < '
        $s3Arguments = (@($decisionCalls[0].CommandElements | Where-Object { $_ -is [CommandParameterAst] } | ForEach-Object { '{0}={1}' -f $_.ParameterName, (Get-CommandArgumentText -Command $decisionCalls[0] -Parameter $_.ParameterName) })) -join ','
    }
    $s3Switches = @($(if ($null -ne $waitNode) { $waitNode.FindAll({ param($node) $node -is [SwitchStatementAst] }, $true) }))
    $s3Keys = $(if ($s3Switches.Count -eq 1) { (@($s3Switches[0].Clauses | ForEach-Object { [string]$_.Item1.Value })) -join ',' } else { '' })
    $s3Updates = @(Get-CommandNodes -Node $waitNode -Name 'Update-AbyssRetryTimeVerdict').Count
    $rankReasons = @()
    $decisionNode = Get-FlowFunctionNode 'Resolve-AbyssRewardDecision'
    if ($null -ne $decisionNode) {
        foreach ($rankStatement in @($decisionNode.Body.EndBlock.Statements)) {
            if ($rankStatement -isnot [IfStatementAst]) { continue }
            if ((Get-NormalizedCode -Node $rankStatement.Clauses[0].Item1) -ceq '-not $CustomMode') { break }
            foreach ($rankTable in @($rankStatement.Clauses[0].Item2.FindAll({ param($node) $node -is [HashtableAst] }, $true))) {
                foreach ($rankPair in @($rankTable.KeyValuePairs)) {
                    if ([string]$rankPair.Item1.Value -cne 'Reason') { continue }
                    $rankValue = @($rankPair.Item2.FindAll({ param($node) $node -is [StringConstantExpressionAst] }, $true)) | Select-Object -First 1
                    if ($null -ne $rankValue) { $rankReasons += [string]$rankValue.Value }
                }
            }
        }
    }
    Assert-True ('5C-S3 전제 - 결정 함수 순위 ① 사유 캡처 넷 ({0})' -f ($rankReasons -join ',')) ($rankReasons.Count -eq 4) ''
    Assert-Case '5C-S3 재평가 - 결정 호출 1 · 감싼 조건 · 인자 다섯(-CustomMode $false · Next* · CurrentItem 없음) · switch 1 · 사유 키 = 결정 순위 ① · 재판단 1(-TimeVerdict 자리)' `
        (J @($decisionCalls.Count, $s3Condition, $s3Arguments, $s3Switches.Count, $s3Keys, $s3Updates)) `
        (J @(1, '-not $script:abyssRetryCommitted', 'SafeStopRequested=(Test-Path -LiteralPath $safeStopFlagPath),FinishOnly=([bool]$script:finishOnly),LastRun=([bool]$script:dgLastRun),TimeVerdict=(Update-AbyssRetryTimeVerdict),CustomMode=$false',
            1, ($rankReasons -join ','), 1))
    # 5C-S4 - 재개 끝 -Nonce 네 자리 = $resumeNonce(FindAll 차례) · 그 대입 1 · 우변 원문 · 선분기 던전 안 2연속의 재입장 완료 호출 1 · 감싼 조건 앞 둘 · 그 -Nonce 원문
    $s4Nonces = (@(@($(if ($null -ne $waitNode) { $waitNode.FindAll({ param($node) $node -is [CommandAst] }, $true) })) |
                Where-Object { @($_.CommandElements | Where-Object { ($_ -is [CommandParameterAst]) -and ($_.ParameterName -eq 'Nonce') }).Count -gt 0 } |
                ForEach-Object { '{0}={1}' -f $_.GetCommandName(), (Get-CommandArgumentText -Command $_ -Parameter 'Nonce') })) -join ','
    $s4Assigns = @($(if ($null -ne $waitNode) { $waitNode.FindAll({ param($node) ($node -is [AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$resumeNonce') }, $true) }))
    $s4Selector = @(Get-CommandNodes -Node $selectorNode -Name 'Complete-AbyssInsideHandoff')
    Assert-Case '5C-S4 재개 끝 -Nonce 네 자리 · $resumeNonce 대입 1 · 우변 · 선분기 재입장 완료 호출 1 · 감싼 조건 앞 둘 · 그 -Nonce' `
        (J @($s4Nonces, $s4Assigns.Count, $(if ($s4Assigns.Count -eq 1) { Get-NormalizedCode -Node $s4Assigns[0].Right } else { '' }), $s4Selector.Count,
            $(if ($s4Selector.Count -eq 1) { (@(Get-EnclosingConditions -Node $s4Selector[0]) | Select-Object -First 2) -join ' < ' } else { '' }),
            $(if ($s4Selector.Count -eq 1) { Get-CommandArgumentText -Command $s4Selector[0] -Parameter 'Nonce' } else { '' }))) `
        (J @('Complete-AbyssInsideHandoff=$resumeNonce,Complete-AbyssOtherSelection=$resumeNonce,Complete-AbyssRetrySelection=$resumeNonce,Complete-AbyssOtherSelection=$resumeNonce', 1,
            '[string]$script:handoff.Nonce', 1, "`$resumeRole < (`$screen -eq 'inside') -and (`$insideStreak -ge 2)", '([string]$script:handoff.Nonce)'))
    # 5C-S5 - 멈춤 끝 차례: 헬퍼 → 복귀(-SafeStopExitCode 0 상수 · -LeaveEntryReason 없음) → 완료 줄 → exit 0 (헬퍼의 부모 마감 식은 test_abyss_exit_button 이 고정)
    $stopNode = Get-FlowFunctionNode 'Complete-AbyssResumeStop'
    $s5Text = '(멈춤 끝 없음)'
    if ($null -ne $stopNode) {
        $s5Statements = @($stopNode.Body.EndBlock.Statements)
        $s5Commands = @($s5Statements | ForEach-Object { @($_.FindAll({ param($node) $node -is [CommandAst] }, $true)) | Select-Object -First 1 })
        $s5Return = $(if ($s5Commands.Count -ge 2) { $s5Commands[1] } else { $null })
        $s5Text = J @($s5Statements.Count, $(if ($s5Commands.Count -ge 1) { $s5Commands[0].GetCommandName() } else { '' }), $(if ($null -ne $s5Return) { $s5Return.GetCommandName() } else { '' }),
            $(if ($null -ne $s5Return) { Get-CommandArgumentText -Command $s5Return -Parameter 'SafeStopExitCode' } else { '' }),
            $(if ($null -ne $s5Return) { Get-CommandArgumentText -Command $s5Return -Parameter 'LeaveEntryReason' } else { '' }),
            $(if ($s5Statements.Count -ge 3) { Get-NormalizedCode -Node $s5Statements[2] } else { '' }), $(if ($s5Statements.Count -ge 4) { Get-NormalizedCode -Node $s5Statements[3] } else { '' }))
    }
    Assert-Case '5C-S5 멈춤 끝 - 문장 4 · 헬퍼 → 복귀(-SafeStopExitCode 0 · -LeaveEntryReason 없음) → 완료 줄 → exit 0' $s5Text `
        (J @(4, 'Invoke-AbyssExitClick', 'Return-ToAbyssSelection', '0', '(없음)', "Write-RunLog '[완료] 어비스 선택 화면 복귀 완료'", 'exit 0'))
    # 5C-S6 - 이름 있는 인자 ⊆ 피호출 param(끝(retry) · 끝(other) · 재개 끝 · 멈춤 끝 - 단순 함수라 오타가 $args 로 사라짐, ④ FC-S14 꼴). PS 바인딩처럼 대소문자 무시(줄임 이름은 모르는 이름으로 잡힘 - 지금 0)
    $s6Defined = 0
    $s6Unknown = @()
    $s6Counts = @()
    foreach ($s6Name in @('Complete-AbyssRetrySelection', 'Complete-AbyssOtherSelection', 'Complete-AbyssResumeWait', 'Complete-AbyssResumeStop')) {
        $s6Node = Get-FlowFunctionNode $s6Name
        if ($null -eq $s6Node) { $s6Counts += ('{0} (정의 없음)' -f $s6Name); continue }
        $s6Defined++
        $s6Params = @($(if ($null -ne $s6Node.Body.ParamBlock) { $s6Node.Body.ParamBlock.Parameters | ForEach-Object { [string]$_.Name.VariablePath.UserPath } }))
        $s6Calls = @(Get-CommandNodes -Node $workerAst -Name $s6Name)
        $s6Counts += ('{0} {1}' -f $s6Name, $s6Calls.Count)
        foreach ($s6Call in $s6Calls) {
            foreach ($s6Parameter in @($s6Call.CommandElements | Where-Object { $_ -is [CommandParameterAst] })) {
                if ($s6Params -notcontains $s6Parameter.ParameterName) { $s6Unknown += ('{0}@{1}: -{2}' -f $s6Name, $s6Call.Extent.StartLineNumber, $s6Parameter.ParameterName) }
            }
        }
    }
    Assert-Case ('5C-S6 이름 있는 인자 ⊆ 피호출 param({0}) - 정의 수 · 모르는 이름' -f ($s6Counts -join ' · ')) (J @($s6Defined, ($s6Unknown -join ','))) (J @(4, ''))
    # 5C-S6 (덧 - 구현 사전 대조) - 재개 끝 · 멈춤 끝 안에서 Game 매개변수가 있는 워커 함수를 부르는 자리는 모두 -Game $Game (⑲ 행은 $game = $null 로 돌아 빠뜨려도 행이 가르지 못함 -
    #   ④ N4-P12 꼴). 자리 수 8 = 재개 끝 6(끝(other) 2 · 시간 초과 끝 · 멈춤 끝 2 · 끝(retry)) + 멈춤 끝 2(헬퍼 · 복귀)
    $s6GameSites = @(foreach ($s6Owner in @('Complete-AbyssResumeWait', 'Complete-AbyssResumeStop')) {
            $s6OwnerNode = Get-FlowFunctionNode $s6Owner
            if ($null -eq $s6OwnerNode) { '{0}:(정의 없음)' -f $s6Owner; continue }
            foreach ($s6GameCall in @($s6OwnerNode.FindAll({ param($node) $node -is [CommandAst] }, $true))) {
                $s6CalleeNode = Get-FlowFunctionNode ([string]$s6GameCall.GetCommandName())
                if (($null -eq $s6CalleeNode) -or ($null -eq $s6CalleeNode.Body.ParamBlock)) { continue }
                if (@($s6CalleeNode.Body.ParamBlock.Parameters | Where-Object { [string]$_.Name.VariablePath.UserPath -eq 'Game' }).Count -eq 0) { continue }
                '{0}:{1}={2}' -f $s6Owner, $s6GameCall.GetCommandName(), (Get-CommandArgumentText -Command $s6GameCall -Parameter 'Game')
            }
        })
    Assert-Case ('5C-S6 (덧) 재개 끝 · 멈춤 끝의 Game 매개변수 자리 = 모두 -Game $Game ({0})' -f ($s6GameSites -join ' · ')) `
        (J @($s6GameSites.Count, (@($s6GameSites | Where-Object { -not $_.EndsWith('=$Game', [StringComparison]::Ordinal) }) -join ','))) (J @(8, ''))
    # 5C-S7 (호출 C 칸) - 인자 지도 · -Clock $resumeClock · -LimitSeconds 0 · 필드 결과 콜론 꼴 · 모드 식(호출 D 와 같은 글자 칸은 바로 아래)
    $callC = @(Get-CommandNodes -Node $selectorNode -Name 'Wait-AbyssReentry' | Where-Object { @(Get-EnclosingConditions -Node $_ | Where-Object { $_ -cmatch '^\$resumeRole( -and |$)' }).Count -gt 0 })
    $callCText = '(호출 C {0}개)' -f $callC.Count
    if ($callC.Count -eq 1) {
        $callCParams = @($callC[0].CommandElements | Where-Object { $_ -is [CommandParameterAst] })
        $fieldParam = @($callCParams | Where-Object { $_.ParameterName -eq 'ReportFieldReturn' }) | Select-Object -First 1
        $callCText = '인자 [{0}] · Clock [{1}] · LimitSeconds [{2}] · 필드 결과 [{3}]' -f (($callCParams | ForEach-Object { $_.ParameterName }) -join ','), (Get-CommandArgumentText -Command $callC[0] -Parameter 'Clock'),
            (Get-CommandArgumentText -Command $callC[0] -Parameter 'LimitSeconds'), $(if (($null -ne $fieldParam) -and ($null -ne $fieldParam.Argument)) { 'colon:' + (Get-NormalizedCode -Node $fieldParam.Argument) } else { '(콜론 아님)' })
    }
    Assert-Case '5C-S7 호출 C 칸 - 인자 지도 · -Clock $resumeClock · -LimitSeconds 없음 · 필드 결과 콜론 꼴 · 모드 식' $callCText `
        "인자 [Game,Clock,Context,ReportRewardReturn,ReportFieldReturn,PanelSeen,ResumeGrace] · Clock [`$resumeClock] · LimitSeconds [(없음)] · 필드 결과 [colon:(`$dungeonMode -ne 'solo')]"
    # 5C-S7 (호출 D 칸) - 끝(retry) 안 Wait-AbyssReentry 1 · 필드 결과 콜론 꼴 · 모드 식이 호출 C 와 같은 글자
    $callCField = $(if (($callC.Count -eq 1) -and ($null -ne $fieldParam) -and ($null -ne $fieldParam.Argument)) { 'colon:' + (Get-NormalizedCode -Node $fieldParam.Argument) } else { '(콜론 아님)' })
    $callD = @(Get-CommandNodes -Node (Get-FlowFunctionNode 'Complete-AbyssRetrySelection') -Name 'Wait-AbyssReentry')
    $callDField = '(호출 D {0}개)' -f $callD.Count
    if ($callD.Count -eq 1) {
        $callDFieldParam = @($callD[0].CommandElements | Where-Object { ($_ -is [CommandParameterAst]) -and ($_.ParameterName -eq 'ReportFieldReturn') }) | Select-Object -First 1
        $callDField = $(if (($null -ne $callDFieldParam) -and ($null -ne $callDFieldParam.Argument)) { 'colon:' + (Get-NormalizedCode -Node $callDFieldParam.Argument) } else { '(콜론 아님)' })
    }
    Assert-Case '5C-S7 호출 D 칸 - 호출 D 1 · 필드 결과 콜론 꼴 · 호출 C 와 같은 글자' (J @($callD.Count, $callDField, ($callDField -ceq $callCField))) (J @(1, "colon:(`$dungeonMode -ne 'solo')", 'True'))
    # 5C-S9 - New-AbyssResumeClock: 모드 예산 1 · 시각 해석 2(retryClicked → retryAttempt) · Set-AbyssMemberClock -Milliseconds 1 · [Math]::Max 첫 인자 [double]0
    $clockNode = Get-FlowFunctionNode 'New-AbyssResumeClock'
    $clockText = '(없음)'
    if ($null -ne $clockNode) {
        $clockParses = @(Get-CommandNodes -Node $clockNode -Name 'ConvertFrom-AbyssJournalTime' | ForEach-Object { Get-NormalizedCode -Node $_.CommandElements[1] })
        $clockSets = @(Get-CommandNodes -Node $clockNode -Name 'Set-AbyssMemberClock' | Where-Object { @($_.CommandElements | Where-Object { ($_ -is [CommandParameterAst]) -and ($_.ParameterName -eq 'Milliseconds') }).Count -eq 1 })
        $clockMax = @($clockNode.FindAll({ param($node) ($node -is [InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -eq 'Max') -and ($node.Expression.Extent.Text -eq '[Math]') }, $true))
        $clockText = '모드 예산 {0} · 시각 해석 [{1}] · 남은 ms 대입 {2} · Max 첫 인자 [{3}]' -f @(Get-CommandNodes -Node $clockNode -Name 'Get-AbyssReentryLimitSeconds').Count, ($clockParses -join ' → '), $clockSets.Count,
            $(if ($clockMax.Count -eq 1) { Get-NormalizedCode -Node $clockMax[0].Arguments[0] } else { '(Max {0}개)' -f $clockMax.Count })
    }
    Assert-Case '5C-S9 New-AbyssResumeClock - 모드 예산 1 · 시각 해석 retryClicked → retryAttempt · Set-AbyssMemberClock -Milliseconds 1 · [Math]::Max 첫 인자 [double]0' $clockText `
        '모드 예산 1 · 시각 해석 [$script:handoff.At.retryClicked → $script:handoff.At.retryAttempt] · 남은 ms 대입 1 · Max 첫 인자 [[double]0]'
    # 5C-S10 - 선분기 ⑩ 의 재개 갈래: Resolve-AbyssResumeGrace 호출 1 · -ReportRewardReturn $false 상수 · 그 갈래 안 기다리는 화면 문자열 0
    $graceCalls = @(Get-CommandNodes -Node $selectorNode -Name 'Resolve-AbyssResumeGrace')
    $graceBranch = $(if ($graceCalls.Count -eq 1) { @(Get-EnclosingConditions -Node $graceCalls[0]) -join ' < ' } else { '' })
    $graceStrings = $(if ($graceCalls.Count -eq 1) {
            $graceIf = $graceCalls[0].Parent
            while (($null -ne $graceIf) -and -not (($graceIf -is [IfStatementAst]) -and ((Get-NormalizedCode -Node $graceIf.Clauses[0].Item1) -ceq '$resumeRole'))) { $graceIf = $graceIf.Parent }
            if ($null -ne $graceIf) { @(Get-StringNodes -Node $graceIf.Clauses[0].Item2 | Where-Object { $RESUME_WAITING_STRINGS -contains [string]$_.Value }).Count } else { -1 }
        } else { -1 })
    Assert-Case '5C-S10 선분기 ⑩ 재개 갈래 - Resolve-AbyssResumeGrace 호출 1 · -ReportRewardReturn $false · 갈래 = 재개 시계 만료 < $resumeRole · 기다리는 화면 문자열 0' `
        (J @($graceCalls.Count, $(if ($graceCalls.Count -eq 1) { Get-CommandArgumentText -Command $graceCalls[0] -Parameter 'ReportRewardReturn' } else { '' }), $graceBranch, $graceStrings)) `
        (J @(1, '$false', 'Test-AbyssMemberClockExpired -Clock $resumeClock < $resumeRole', 0))
    # 5C-S11 - Role resume 은 본류로 돌아가지 않음: '$resumeRole' 항 조건 갈래 안 return 0 · StartScreen 대입 0
    $resumeClauses = @($selectorNode.FindAll({ param($node) $node -is [IfStatementAst] }, $true) | ForEach-Object { $_.Clauses } | Where-Object { (Get-NormalizedCode -Node $_.Item1) -cmatch '^\$resumeRole( -and |$)' })
    $resumeReturns = @($resumeClauses | ForEach-Object { $_.Item2.FindAll({ param($node) $node -is [ReturnStatementAst] }, $true) }).Count
    $resumeStartScreens = @($resumeClauses | ForEach-Object { $_.Item2.FindAll({ param($node) ($node -is [AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$script:handoff.StartScreen') }, $true) }).Count
    Assert-Case "5C-S11 '`$resumeRole' 항 갈래 - 갈래 수 · 안 return 0 · StartScreen 대입 0" (J @(($resumeClauses.Count -ge 8), $resumeReturns, $resumeStartScreens)) (J @('True', 0, 0))
    # 5C-S12 - 재개 끝 문구에 ' (post-clear)' · 'post-clear-stop' 0
    $waitEndStrings = @(Get-StringNodes -Node (Get-FlowFunctionNode 'Complete-AbyssResumeWait') | Where-Object { ([string]$_.Value).Contains(' (post-clear)') -or ([string]$_.Value).Contains('post-clear-stop') }).Count
    Assert-Case "5C-S12 재개 끝 문자열에 ' (post-clear)' · 'post-clear-stop' 0 (정의 있음)" (J @(($null -ne (Get-FlowFunctionNode 'Complete-AbyssResumeWait')), $waitEndStrings)) (J @('True', 0))
    # 5C-S8 - 재개 끝 exit 0 · 새 함수 둘(공유 정지 함수 · 멈춤 끝)의 exit 은 줄 단독(줄 글자 = 그 exit 문 - ④ §10 센티널이 줄 정규식으로 치환하고 명세 1.13 '새 exit 는 줄 단독')
    $s8WaitExits = $(if ($null -ne $waitNode) { @($waitNode.FindAll({ param($node) $node -is [ExitStatementAst] }, $true)).Count } else { -1 })
    $s8Lines = @(foreach ($s8Name in @('Stop-AbyssReentryFieldCancelled', 'Complete-AbyssResumeStop')) {
            $s8Node = Get-FlowFunctionNode $s8Name
            $(if ($null -eq $s8Node) { '(없음)' } else { (@($s8Node.FindAll({ param($node) $node -is [ExitStatementAst] }, $true) | ForEach-Object { Get-ResumeWorkerLine -Node $_ })) -join ',' })
        })
    Assert-Case '5C-S8 재개 끝 exit 0 · 공유 정지 함수 · 멈춤 끝의 exit 줄 = 그 문장 하나' (J (@($s8WaitExits) + $s8Lines)) (J @(0, 'exit 4', 'exit 0'))
    # 5C-S13 - 재개 끝 Test-Path 1(재평가 결정 인자 - 감싼 조건 '-not $script:abyssRetryCommitted') · 재개 끝 · 멈춤 끝 안 Remove-Item 0(재평가는 안전 중지 예약을 소비하지 않음 - ④ P5d-4 꼴)
    $s13TestPaths = @(Get-CommandNodes -Node $waitNode -Name 'Test-Path')
    $s13InGate = @($s13TestPaths | Where-Object { (@(Get-EnclosingConditions -Node $_) -contains '-not $script:abyssRetryCommitted') -and ((Get-NormalizedCode -Node $_) -ceq 'Test-Path -LiteralPath $safeStopFlagPath') }).Count
    Assert-Case '5C-S13 재개 끝 Test-Path 1 · 그중 재평가 자리 1 · 재개 끝 Remove-Item 0 · 멈춤 끝 Remove-Item 0' `
        (J @($s13TestPaths.Count, $s13InGate, @(Get-CommandNodes -Node $waitNode -Name 'Remove-Item').Count, @(Get-CommandNodes -Node $stopNode -Name 'Remove-Item').Count)) (J @(1, 1, 0, 0))
}

# ===== 실행 =====
$RESUME_ROW_GROUPS = @(
    @{ Name = 'A 시계·유예'; Function = { Test-ResumeRowsA } },
    @{ Name = "A 'reclick' 칸"; Function = { Test-ResumeRowsAReclick } },
    @{ Name = "A′ 선분기 유예 GR"; Function = { Test-ResumeRowsGR } },
    @{ Name = 'B 필드'; Function = { Test-ResumeRowsB } },
    @{ Name = 'C 시작 화면'; Function = { Test-ResumeRowsC } },
    @{ Name = 'D 승계 입장 끝'; Function = { Test-ResumeRowsD } },
    @{ Name = 'D 재평가·판단값'; Function = { Test-ResumeRowsDJudge } },
    @{ Name = 'E 패널 뒤 취소·필드 취소'; Function = { Test-ResumeRowsE } },
    @{ Name = 'F 재클릭·상한·폴백·기록 실패'; Function = { Test-ResumeRowsF } })
$originalUntilEnv = [Environment]::GetEnvironmentVariable('HONEYNOGI_UNTIL_TIME', 'Process')   # 행이 바꾸는 지정 시각 env - 끝에서 되돌림
try {
    # ① 캡처 · 추출 확인 · exit 치환(동작 행보다 먼저) · 서명 대조 · HS0 · exit 이름별 수 · 정적
    Initialize-ResumeCaptures
    "INFO ⑲ 캡처: W $memberFieldSettleSeconds / Q $abyssReclickQuietSeconds / Tpm $capturedTimeoutPartyMatch / T45 $timeoutEntry / 알 수 없음 $memberUnknownOverlaySeconds / 선분기 회전 대기 $($script:selectorWaitMs)ms"
    foreach ($problem in $extractionProblems) { "FAIL 추출: $problem"; $fails++ }
    Assert-ExitTally -Label '저장소 묶음 워커 사본' -Tally $bundleExit
    Assert-ExitTally -Label ('워커 함수 ' + (@($workerExtracted) -join '·')) -Tally $workerExit
    if ($null -ne $script:mainSegmentBlock) { Assert-ExitTally -Label '본류 시작 구간(2.1 블록 ~ $roleNone 대입)' -Tally $segmentExit }
    $resumeSignatureNames = @($WORKER_MOCK_NAMES + $WORKER_SPY_NAMES + $FLOW_MOCK_NAMES + @('Invoke-AbyssHandoffStart', 'Resolve-AbyssHandoffStartScreen', 'Test-CustomCleanupOnly', 'Add-AbyssJournalClearedEntry') +
        @($RESUME_SPY_BODIES.Keys) + @($RESUME_MOCK_BODIES.Keys) | Select-Object -Unique)
    $resumeSignatureRows = @(foreach ($signatureName in $resumeSignatureNames) { '{0}:{1}' -f $signatureName, ((Get-ParamSignature -Ast $workerAst -Name $signatureName) -ceq (Get-LiveParamSignature -Name $signatureName)) })
    Assert-Case ('모의·감시 서명 = 실제 함수 서명(⑱′ 몫 + ⑲ 감시 다섯 · 모의 넷 - {0}개)' -f $resumeSignatureNames.Count) ($resumeSignatureRows -join ' ') (@($resumeSignatureNames | ForEach-Object { '{0}:True' -f $_ }) -join ' ')
    $resumeRealNames = @('Invoke-RealWaitAbyssReentry', 'Invoke-RealUpdateAbyssRetryTimeVerdict', 'Invoke-RealGetDgTimeVerdict', 'Invoke-RealNewAbyssResumeClock', 'Invoke-RealCompleteAbyssOtherSelection')
    Assert-Case '⑲ 감시 다섯이 넘길 실제 함수 정의 있음(재판단 · 시각 판정은 재평가 · 클릭 자리 재검사 행이 부름 - 지정 시각 읽기와 함께 추출 목록에 둠)' `
        (J @($resumeRealNames | ForEach-Object { [string]($null -ne (Get-Command -Name $_ -CommandType Function -ErrorAction SilentlyContinue)) })) (J @('True', 'True', 'True', 'True', 'True'))
    Test-ResumeHs0
    Test-ResumeExitCounts
    Test-ResumeStatic

    # ② 행 (한 프로세스에서 행을 잇습니다 - 행 준비가 상태를 비움)
    $resumeReady = ($consumeAvailable -and ($null -ne $script:mainSegmentBlock) -and ($null -ne $script:untilBlock) -and ($null -ne $script:selectorWaitMs))
    foreach ($rowGroup in $RESUME_ROW_GROUPS) {
        if (-not $resumeReady) {
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
    # env 되돌림(⑱′ 의 이름들 + 지정 시각) · 잡은 잠금 정리 · 임시 폴더 통째 삭제(잠금이 남아 못 지우면 핸들 누수라 FAIL)
    Close-HeldStreams
    foreach ($envName in $TOUCHED_ENV_NAMES) { [Environment]::SetEnvironmentVariable($envName, $originalEnv[$envName], 'Process') }
    [Environment]::SetEnvironmentVariable('HONEYNOGI_UNTIL_TIME', $originalUntilEnv, 'Process')
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
