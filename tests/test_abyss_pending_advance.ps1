# 어비스 완료 기록 대기열(pending-advance 큐) 회귀 ⑰ - 구현 명세 ① 2.5a·3.4 (2026-10-09 신설 - 단계 2.6·2.8·2.9 가 행을 더합니다)
#
# 지키는 것 (단계 2.5a - 대기열 함수. 설계 v10 6.1 'pending-advance 큐' · v11 R1 3.7 · 구현 명세 ① 2.5a):
#   [Q] 큐 기록 Add-AbyssPendingEntry - 원소 { owner(5필드), generation, nonce, stage, createdAt } 를 대기열 끝에 저장 1회로 덧붙임 ·
#       단계는 3종만(inside-handoff · code1-routed · finish-only-complete - 명세 5절 B7) · 반영 쪽이 대조할 수 없는 원소(owner 필드 없음·
#       세대가 정수 아님·nonce 없음)는 쓰지 않음 · 저장 실패(locked·corrupt·io-failed·예외)는 $false 와 [오류] 한 줄, 파일 무변경, 예외 0.
#   [A] 큐 반영 Invoke-AbyssPendingAdvance - 맨 앞부터 순서대로, 지금 진행의 owner 5필드 + 세대가 원소와 모두 같을 때만 전진(Step) →
#       그 원소 제거 + nonce applied(저장 1회), 다르면 전진 없이 제거 + applied(지난 원소 · 순열 변경 · 동일 토큰 중복 · 초기화 뒤 재일치 ·
#       멈춘 사이 리스트 변경 = 지문만 다름) ·
#       진행 저장 실패 → 그 원소부터 대기열·마커 보존 + $false · 완료 마커는 finish 가 대기열을 비운 뒤에만 정리(start 는 정리하지 않음 -
#       그 마커가 시작 게이트의 마무리 복구 근거, 설계 R1 3.7 · 정리 실패는 [경고] 뿐) · 반영 도중 끊김(4 지점) 뒤 다시 반영해도 전진 총 2(이중 전진·유실 0) ·
#       지울 때 맨 앞이 판단한 그 원소인지 nonce·단계·만든 시각으로 확인(같은 nonce 원소 둘이 함께 지워지지 않음 · applied 는 nonce 1번) ·
#       start 의 전진마다 [경고] 한 줄(dev:909 원문).
#   [S] 정적 - 클로저(mutator·expect)는 .GetNewClosure() 로 만들고 $script: 를 읽지 않음 · 두 함수는 정지하지 않음(정지·시작 거부는 부른
#       쪽) · try 의 catch 절은 1개(규칙 3 - 2개까지) · 호출부 = 단계 2.6 의 재입장 실행부·마무리 실행 완주(2.8·2.9 가 더하며 이 행을 고침).
# 지키는 것 (단계 2.6 - 실행부·완주 행. 설계 v11 R1 3.4·3.7 · 6.3a · 구현 명세 ① 2.6 · 3.4):
#   [P] 실제 config·journal·마커로: 재입장 실행부의 진행 저장 실패 → 대기열 inside-handoff(owner = 끝난 판) + 마무리 실행 기동(env 는 보류로 - 진행 미독 ·
#       FINISH_ONLY·LAST_RUN·HANDOFF_NONCE·GENERATION) → 완주 = finish-only-complete(owner = 보류 Owner) → 대기열 순서 반영(전진 총 2) → 마커·대기열
#       정리 → 끝 처리 두 호출 / 완주 직후 GUI 재시작 = 다음 시작 S0 의 반영 + 마커(owner = nextOwner)로 마무리 복구 → 전진 총 2 / 저장 경계 재시작
#       주입(대기열 A1 뒤 · A2 뒤) → 다음 시작 반영으로 전진 총 2(이중 전진·유실 0). 이 행들은 다음 시작의 S0·마커 게이트가 부르는 함수(반영 -Caller
#       start · Read-CustomMarkerOwner + Test-CustomMarkerOwnerMatchesContext)를 그대로 부릅니다 - 시작 처리의 실제 S0·S3·마커 게이트·첫 기동으로 같은
#       흐름을 잇는 행은 [SG] SG13(H32b)·SG14(완주 직후 재시작)입니다(단계 2.9).
# 지키는 것 (단계 2.6 구현 리뷰 - 대기열 실패의 '사용 중' 안내):
#   [T] 두 함수는 반환값을 그대로 두고 호출마다 처음에 $script:abyssPendingLastTag 를 비운 뒤 실패한 저장소 태그만 남김 - 큐 기록 = 저장 태그(locked·
#       corrupt·io-failed), 큐 반영 = 읽기 Status + 지우기 저장 태그(expect-failed 포함), 그 밖 실패(형식 오류·진행 저장 실패·진행 위치 없음·알 수
#       없는 호출·예외)·성공은 빈 값.
#   [P6·P7] 실제 잠금·손상 파일로: 실행부 A1 · 완주 A2 · 반영(읽기) 이 '사용 중' 이면 정지 문구 끝에 잠금 파일 안내(실행부는 그 뒤 재입장 꼬리),
#       손상이면 문구 그대로. [S5] 태그 변수의 선언·대입·읽는 곳과 정지 사유 함수의 호출 소유자.
# 지키는 것 (단계 2.8 - 코드 1 행. 설계 v10 6.1 'GUI 코드 1 라우팅' · dev:990 · v11 R1 6.3a · 구현 명세 ① 2.8 · 3.4 · 5절 A6·A10):
#   [C] 실제 config·journal·마커로 실제 라우팅(Invoke-Code1JournalRouting)을 돌립니다: reentered 뒤 코드 1 → 계상 1·전진 1·다음 판 기동(마무리 복구 0) → 전진 총 2 ·
#       진행 저장 실패면 대기열 code1-routed → 마무리 실행 완주로 전진 총 2 · 재입장 요청(retry-*) 뒤 코드 1 → 켜진 빌드는 재개 기동 1(-PreserveMarker - 기동 직후 마커
#       owner i 그대로) · 재개 뒤 두 번째 코드 1 → 기동 0 · 이 빌드(재개 기능 꺼짐) → 기동 0·정지·보존 · 안전 중지 → 기동 0·보존 · 마무리 실행 기동의 코드 1(타이머
#       갈래 첫 문장을 AST 로 잘라 점소싱) → 재시작 0 → 다음 수동 시작 Role next(커스텀) / 새 실행 id 라 후보 없음(비커스텀 - 수용 창 고정) · 클리어 기록 → 라우팅
#       'legacy-cleared' → 타이머의 $markerExists 대입문(AST 로 잘라 점소싱)이 참 → 마무리 복구(명세 5절 A10) · 코드 1 은 클리어 기록을 소비하지 않음(A6ⓐ).
#       타이머 갈래 전체(복구 문구·기동 env)는 test_abyss_handoff_gui 의 틱 행이 돌립니다.
#       단계 2.7·2.8 구현 리뷰 P2 - 라우팅 안 정지의 이번 기동 nonce 닫기를 다음 수동 시작(실제 S0·S3·첫 기동)까지 잇는 행: 이번 기동 nonce 가 라우팅한 항목이면 열어
#       둠 → 다음 시작이 그 항목을 재개(C10) · 다른 nonce(앞 판의 재입장 항목을 받은 next 기동)면 그것만 done → 다음 시작의 이어받기는 그대로(꺼짐 = S3 거부 · 켜짐 = 재개 - C11).
#       닫기의 진리표(정지 넷 × 같음·다름·없음 · 닫기 실패)는 test_abyss_handoff_gui [NC].
#       단계 2.7·2.8 구현 리뷰 확인 라운드 - 타이머 예전 처리 recover 갈래의 안전 중지도 이번 기동 nonce 를 닫음(-RoutedNonce 빈 값), retry 갈래의 안전 중지는 열어 둠
#       (구현 리뷰 확인): 타이머의 예전 처리 if 를 AST 로 잘라 점소싱해 실제 라우팅 뒤에 돌립니다 - recover 자리(C12: 미적용 클리어 기록 · 완료 마커 두 근거 → N2 done →
#       다음 수동 시작 마무리 복구 · 넘긴 nonce 없음 → 저장 0 · 닫기 실패 → [경고] 뒤 안전 중지 1번) · retry 자리(C13: N2 launched 그대로 · 저장 0 → 다음 수동 시작이
#       next:N2 로 이어받음 · 재입장 0 · 넘긴 nonce 없음 → 저장 0).
# 지키는 것 (단계 2.9 - 시작 게이트 S0·S3. 설계 v10 6.3 dev:941~948 · 6.1 읽기 계약 · 구현 명세 ① 2.9 · 3.4 · 5절 A6·A11·B10):
#   [SG] 실제 config·journal·마커로, 시작 처리(Invoke-StartAutomation)의 그 문장들을 AST 로 잘라 점소싱합니다 - 진행 읽기 → S0 → 진행 다시 읽기 → 지문 검사·
#       완주 판정(S1) / 묘비 소비 뒤의 S3 → 마커 게이트(바깥 if) / 첫 기동(재개 예약이면 -PreserveMarker -ResumeNonce). 그 사이의 다른 시작 처리(랜덤
#       순서·프로세스 정리·묘비)는 돌리지 않습니다:
#       S0·S3 읽기 실패(사용 중·손상·읽기 실패·예외) → 시작 거부·파일 그대로(사용 중은 잠금 파일 안내) · S0 대기열 반영(마지막 바퀴 마지막 판의 완주 원소가
#       남아도 S1 이 바뀐 진행으로 완주 판정 - 추가 회차 0) · 대기열 반영 실패 → 거부 · 계상 전에 끝난 미적용 reentered → 전진 1·applied(launchState 그대로)
#       → 첫 기동이 next 로 이어받음 · 그 진행 위치 없음·전진 실패·applied 실패(다음 시작에 이중 전진 0) / S3 컨텍스트 재시도·끝내 없음(미적용 클리어 이상이
#       있으면 거부 · 없으면 마커 게이트로) · 클리어 기록 → 마무리 복구 예약 + 마커 게이트 건너뜀(마커 있음·없음) · 재입장 요청 → 재개 기능 꺼짐 = 거부 /
#       켜진 빌드 = 재개 수동 1회(재개 횟수 +1 · 마커 정리 0) · 어비스 커스텀이 아니면 journal 접근 0. 이어받기 행: 코드 10 마무리 복구 기동(소비 생략) → 다음
#       시작 복구 · 명세 리뷰 3 P1(커스텀 코드 0 + 마커 없음 + 클리어 기록 + 진행 저장 실패 - 타이머 코드 0·11 갈래 본문을 AST 로 잘라 점소싱) → 다음 시작 복구
#       예약 1·재입장 0.
#   단계 2.7~2.9 구현 검증 보강(2026-10-09 - 생존 변이 9): S3 판정 안의 예외 → 거부(SG2′ - 진행 위치 읽기 예외 주입 $script:contextThrows) · 주인 확인 불가는
#       '클리어 이상' 만 셈(SG3″) · 적용된 cleared 는 복구 근거가 아님·post-clear-stop 은 복구(SG4′·SG4″) · 재개 횟수 기록 예외·실제 -Expect 거절 → 거부(SG5″·SG5‴) ·
#       지문 검사·완주 판정(S1)이 S0 의 전진을 봄(SG8′) · S0 처리 중 예외 → 거부 + [오류] 줄(SG9′).
# 방법:
#   - GUI 함수와 저장소 묶음(머리 주석 ~ '묶음 끝' 표지 주석 사이 최상위 함수)을 이 파일 최상위에서 정의합니다(명세 ① 2.0 체크리스트 6 -
#     클로저가 부를 수 있는 함수는 최상위 정의뿐). config·journal·마커는 케이스마다 새 임시 폴더의 실제 파일이고, 진행 전진·위치는 실제
#     Step-CustomProgress·Get-CustomCurrentContext 가 그 config 를 읽고 씁니다. 대기열 원소의 owner 도 실제 Get-CustomCurrentContext →
#     Get-CustomCanonicalOwner 로 만들고(사본 계산 없음), 픽스처 대기열은 실제 Add-AbyssPendingEntry 로 씁니다.
#   - 감시 함수: Step-CustomProgress · Update-AbyssJournal · Read-AbyssJournal · Clear-CustomMarkerFile 를 같은 이름으로 가려 호출 순서·횟수를
#     적고 실제 함수로 넘깁니다(실제 본문은 ${function:…} 로 잡아 둠 - 서명은 G2 가 대조). 끊김 주입은 그 호출 뒤 예외를 던져 뒤 단계를
#     끊습니다 - 반영 함수는 예외를 잡아 [오류] 한 줄만 남기므로 디스크에는 그때까지 쓴 것만 남아 프로세스가 죽은 것과 같습니다(㉒ 방식).
#   - 실패는 실제 파일로 일으킵니다: 잠금 = abyss_handoff.lock 을 만들어 쥠 · 손상 = 본 파일·직전본을 잘린 JSON 으로 · 기록 실패 = 본 파일을
#     FileShare.Read 로 쥠(교체 실패) · 읽기 실패 = 본 파일을 FileShare.None 으로 쥠 · 진행 저장 실패 = config.json 을 FileShare.Read 로 쥠
#     (읽기는 되고 교체만 실패 - 실제 Step-CustomProgress 의 실패 경로).
# 단계별 행(구현 명세 ① 3.4): 2.5a 큐 함수 [Q][A] · 2.6 실행부·완주 [P] · 2.8 코드 1 [C] · 2.9 시작 게이트 [SG].
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing   # 단계 2.6 행 - 실행부·기동의 상태줄 색([System.Drawing.Color]::Firebrick 등)
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')   # Remove-SourceComments (정적 단언은 주석 뺀 사본으로)

# ===== 상수 =====
# GUI 에서 이름으로 추출해 최상위에 정의하는 함수 (뒤 단계가 행을 더하면 여기에 이름을 더합니다)
$GUI_FUNCTION_NAMES = @(
    'Read-Config', 'ConvertTo-StrictBoolean', 'Write-Utf8FileAtomic', 'Save-Config',
    'Format-CustomItemToken', 'Get-CustomFingerprint', 'Get-CustomOrderKey', 'New-CustomShuffleOrder', 'Test-CustomShuffleOrder',
    'Get-CustomExecutionItems', 'Get-CustomRandomOrderEnabled', 'Get-CustomPositionText', 'Get-CustomCurrentContext', 'Get-CustomNextProgress',
    'Step-CustomProgress', 'Get-CustomCanonicalOwner', 'ConvertTo-CustomMarkerOwnerJson',
    'Get-CustomMarkerFileForSection', 'Get-CustomMarkerStaleFile', 'Clear-CustomMarkerFile',
    'Get-AbyssJournalTagText', 'Add-AbyssPendingEntry', 'Invoke-AbyssPendingAdvance',
    # 단계 2.6 - 재입장 실행부·마무리 실행 완주·끝 처리와 실제 기동(Start-NextCycle)·그 의존, 다음 시작의 마커 대조
    'Invoke-InsideHandoffExit', 'Complete-FinishOnlyCycle', 'Complete-AbyssExitJournal', 'Get-AbyssExitStopReason', 'Get-AbyssJournalLockedGuide',
    'Get-AbyssJournalCorruptGuide', 'Get-InsideHandoffStopReason', 'Test-AbyssHandoffRunActive', 'Test-AbyssMemberRunActive', 'Test-CustomLapComplete',
    'Test-TimeAllowsNextCycle', 'Get-NextCycleAction', 'Start-NextCycle', 'Set-HandoffLaunchEnv', 'Resolve-HandoffEnvForContext', 'Get-FinishOnlyCustomEnv',
    'Clear-HandoffEnv', 'Clear-CustomEnv', 'Test-WorkerTimeJudgeActive', 'Get-TimeStatusSuffix', 'Test-CustomLastRun', 'Get-CustomListCompact',
    'New-CustomMarkerOwnerJson', 'Read-CustomMarkerOwner', 'Test-CustomMarkerOwnerMatchesContext',
    # 단계 2.6 구현 리뷰 - 대기열 실패의 '사용 중' 안내
    'Get-AbyssPendingStopReason',
    # 단계 2.8 코드 1 - 라우팅 · 타이머 $markerExists 대입문이 부르는 마커 유효 판정 · 커스텀 오류 대응 판정 · 라우팅 안 정지 경로의 이번 기동 nonce 닫기
    # (단계 2.7·2.8 구현 리뷰 P2)
    'Invoke-Code1JournalRouting', 'Test-CustomMarkerValidForCurrent', 'Get-CustomErrorAction', 'Close-AbyssLaunchNonceOnStop',
    # 단계 2.9 시작 게이트 - S0·S3 와 그 공용 함수 · 이어받기 행의 타이머 코드 0·11 갈래 본문이 부르는 재입장 판별
    'Invoke-AbyssStartJournalAdvance', 'Get-AbyssStartJournalAction', 'Invoke-AbyssStartJournalAction', 'Read-AbyssStartJournal',
    'Get-AbyssStartJournalRefusal', 'Set-CustomRecoveryReservation', 'Read-AbyssExitHandoff', 'Get-AbyssExitHandoffKind', 'Get-WorkerDoneMarkers')
# 모의·감시 - 같은 이름의 GUI 실제 함수와 서명을 대조합니다
$SPY_FUNCTION_NAMES = @('Add-GuiLog', 'Step-CustomProgress', 'Update-AbyssJournal', 'Read-AbyssJournal', 'Clear-CustomMarkerFile',
    'Get-CustomCurrentContext', 'Stop-AllRun', 'Move-WorkerLogToArchive', 'Set-CustomListRandomView', 'Reset-CustomProgress')
$BUNDLE_HEADER_FRAGMENT = '어비스 완료 기록(handoff journal) 저장소'   # 저장소 묶음 머리 주석 (회귀 test_abyss_journal_store 와 같은 경계)
$BUNDLE_END_FRAGMENT = '어비스 완료 기록 저장소 묶음 끝'                 # 저장소 묶음 끝 표지 주석
$ABYSS_SECTION = 'abyssCustomRepeat'
$GENERATION = 2                                   # 픽스처 진행 세대 - 0 이 아니어야 세대를 빠뜨린 대조가 드러남
$STAGE_A1 = 'inside-handoff'                      # 재입장 실행부의 진행 저장 실패 (명세 5절 B7)
$STAGE_CODE1 = 'code1-routed'                     # 코드 1 재입장 경로의 같은 실패
$STAGE_A2 = 'finish-only-complete'                # 마무리 실행 완주
$STAGE_SHORT = @{ 'inside-handoff' = 'A1'; 'code1-routed' = 'C1'; 'finish-only-complete' = 'A2' }
# 완료 기록 nonce (GUID 'D' 형식) - 표시용 짧은 이름
$NONCE_1 = 'a1a1a1a1-0000-4000-8000-000000000001'
$NONCE_2 = 'a2a2a2a2-0000-4000-8000-000000000002'
$NONCE_3 = 'a3a3a3a3-0000-4000-8000-000000000003'
$NONCE_S = 'b5b5b5b5-0000-4000-8000-00000000000b'
$NONCE_X = 'c0c0c0c0-0000-4000-8000-00000000000c'
$NONCE_SWAP = 'd0d0d0d0-0000-4000-8000-00000000000d'
$NONCE_LABELS = @{ $NONCE_1 = 'N1'; $NONCE_2 = 'N2'; $NONCE_3 = 'N3'; $NONCE_S = 'NS'; $NONCE_X = 'NX'; $NONCE_SWAP = 'SWAP' }
$INJECTED_STORE_EXCEPTION = '주입: 완료 기록 저장소 예외'
$INJECTED_CONTEXT_EXCEPTION = '주입: 진행 위치 읽기 예외'   # 단계 2.7~2.9 구현 검증 - S3 판정 안의 예외(진행 위치 읽기에서 던짐)
$CRASH_MESSAGE = '주입: 이 지점에서 프로세스 종료'
$TRUNCATED_JSON = '{"version": 1, "seq": 3, "entries": ['   # 쓰다 끊긴 파일 모양 (파싱 실패 = 손상)
# 사용자 문구 - 구현의 글자를 계약으로 고정합니다 (실패 종류 낱말은 설계 R2 3.6, start 경고는 dev:909 원문)
$RECORD_FAIL_FORMAT = '[오류] 완료 기록 대기열 저장 실패({0})'
$SHAPE_FAIL_FORMAT = '[오류] 완료 기록 대기열 저장 실패(형식 오류: {0})'
$ADVANCE_FAIL_FORMAT = '[오류] 완료 기록 대기열 반영 실패({0}) - 대기열·마커를 보존합니다'
$START_ADVANCE_FORMAT = '[경고] 이전 세션의 미반영 완료 기록으로 진행을 전진({0})'
$SKIP_FORMAT = '[안내] 완료 기록 대기열의 지난 기록을 건너뜁니다({0}) - 지금 진행 위치와 맞지 않습니다 (이미 반영됐거나 진행 초기화·순서 변경 뒤의 기록)'
$STEP_FAIL_PREFIX = '[오류] 커스텀 진행 기록 저장 실패:'           # Step-CustomProgress 자신의 줄(뒤는 예외 메시지)
$MARKER_CLEAR_WARNING = '[경고] 완료 마커 파일을 정리하지 못했습니다 - 다음 시작 때 다시 정리합니다.'
$STORE_RECOVER_WARNING = '[경고] 완료 기록 파일 손상 - 직전본으로 복구'   # 저장소가 돌려주는 복구 경고 (구현 명세 ① 2.1 읽기 규칙 (c))
# 정지 문구 (단계 2.6 실행부·완주 - 대기열 실패가 '사용 중' 이면 끝에 잠금 파일 안내, 단계 2.6 구현 리뷰). 글자를 계약으로 고정합니다
$LOCKED_GUIDE = '(다른 꿀비노기·powershell 프로세스가 없는데도 계속되면 %LOCALAPPDATA%\HoneyNogi\Log 의 abyss_handoff.lock 파일을 지운 뒤 다시 시작해 주세요)'
$IH_TAIL = " (캐릭터가 '다시 하기'로 들어간 던전 안일 수 있음 - 입장 키 미전송)"
$QUEUE_STOP = '커스텀 진행 기록·대기열 저장 실패 - 중복 실행 방지를 위해 정지'
$FINISH_RECORD_STOP = '마무리 실행 완료 기록 저장 실패 - 대기열·마커를 보존하고 정지'
$FINISH_ADVANCE_STOP = '마무리 실행 진행 반영 실패 - 대기열·마커를 보존하고 정지'
# 코드 1 라우팅·마무리 실행 판별의 정지 문구 (단계 2.8 - 설계 v10 6.1 dev:888·889 · v11 R1 3.7 의 글자, 설계에 없는 것은 구현 글자를 계약으로 고정)
$C1_FINISH_FORMAT = '마무리 실행 중 오류 종료(코드 {0}) - 자동 재시작하지 않고 정지 (진행 기록 보존, 캐릭터가 던전 안일 수 있습니다)'
$C1_RETRY_OFF = '재입장 요청 뒤 오류 종료 - 재개 기능이 꺼져 있어 완료 기록을 보존하고 정지 (캐릭터가 던전 안일 수 있습니다)'
$C1_RESUMED_AGAIN = '재입장 요청 뒤 재개한 판도 오류 종료 - 자동 재개는 한 번뿐이라 완료 기록을 보존하고 정지 (캐릭터가 던전 안일 수 있습니다)'
$C1_SAFE_NOTICE = '[안내] 재입장 요청 뒤 오류 종료 - 안전 중지라 재개하지 않고 정지합니다 (캐릭터가 던전 안일 수 있습니다 - 다음 시작에서 재개)'
# 시작 게이트 S0·S3 의 시작 거부·안내 (단계 2.9 - 설계 v10 6.1 'S0·S3 locked → 시작 금지' · 명세 2.9 · 5절 A11·B10·C11 의 글자, 설계에 글자가 없는 것은
# 구현 글자를 계약으로 고정). 사용 중은 다른 '사용 중' 정지와 같은 잠금 파일 안내, 손상은 파일 위치 안내, 주인 확인 불가는 마커 게이트와 같은 글자
$SG_REFUSE_LOCKED = '[오류] 완료 기록 파일이 사용 중입니다 - 잠시 뒤 다시 시작해 주세요 ' + $LOCKED_GUIDE
$SG_REFUSE_CORRUPT = '[오류] 완료 기록 파일 손상 - 파일을 보존하고 시작하지 않습니다 (%LOCALAPPDATA%\HoneyNogi\Log 의 abyss_handoff.json* 파일을 다른 폴더로 옮긴 뒤 다시 시작해 주세요)'
$SG_REFUSE_READ = '[오류] 완료 기록 파일을 읽지 못해 시작하지 않습니다 - 잠시 뒤 다시 시작해 주세요'
$SG_REFUSE_NO_OWNER = '[오류] 설정 파일을 읽지 못해 이전 완료 기록의 주인을 확인할 수 없습니다 - 완료 기록을 지우지 않고 시작을 멈춥니다. 잠시 뒤 다시 시작해 주세요 (계속 반복되면 config.json 을 확인해 주세요).'
$SG_REFUSE_RETRY_OFF = '[오류] 재입장 요청 뒤 끝난 판의 기록이 남아 있지만 이 버전은 그 판을 재개할 수 없어 시작하지 않습니다 - 캐릭터가 던전 안이면 그 판을 직접 마친 뒤 어비스 커스텀 [진행 초기화](진행은 처음부터)로 기록을 지우고 시작해 주세요'
$SG_QUEUE_FAIL = '[오류] 이전 세션의 완료 기록 대기열을 반영하지 못해 시작하지 않습니다 - 대기열·마커를 보존합니다'
$SG_REENTER_STEP_FAIL = '[오류] 이전 세션의 재입장 완료 기록을 진행에 반영하지 못해 시작하지 않습니다 - 완료 기록을 보존합니다'
$SG_REENTER_MARK_FAIL_FORMAT = '[오류] 이전 세션의 재입장 완료 기록에 반영 표시를 남기지 못해 시작하지 않습니다({0}) - 진행은 반영됐습니다'
$SG_RECOVER_NOTICE = '[커스텀] 이전 완료 항목의 마무리를 복구합니다.'
$SG_RESUME_NOTICE = '[경고] 이전 세션에서 재입장 요청 뒤 끝난 판을 이어받는 재개를 한 번 시작합니다'
$SG_RESUME_SAVE_FAIL = '[오류] 재개 기록 저장 실패 - 시작하지 않습니다 (기록 보존)'
$SG_EXCEPTION_FORMAT = '[오류] 완료 기록 확인 중 예외 - 시작하지 않습니다 ({0})'
$SG_REREAD_FAIL = '[오류] 설정 파일을 다시 읽지 못해 시작하지 않습니다 - 잠시 뒤 다시 시작해 주세요'
$SG_PROGRESS_RESUME_PREFIX = '[안내] 커스텀 반복: 저장된 진행을 이어갑니다 - '      # 지문 검사·완주 판정(S1)이 진행을 이어 갈 때의 줄 머리
$SG_MARKER_DISCARD = '[안내] 현재 진행 위치와 맞지 않는 이전 완료 마커를 정리했습니다.'   # 마커 게이트의 폐기 안내
$SG_STEP_LOCK_PREFIX = '[오류] 커스텀 진행 기록 저장 실패:'                            # Step-CustomProgress 자신의 줄(뒤는 예외 메시지)
$C0_STEP_STOP = '커스텀 진행 기록 저장 실패 - 중복 실행 방지를 위해 정지'                 # 타이머 커스텀 사슬의 진행 저장 실패 정지(글자 그대로)
$UTF8_BOM = New-Object System.Text.UTF8Encoding($true)
# 어비스 커스텀 목록 픽스처 (항목 토큰만 쓰임). 중복 목록은 0번·2번이 같은 토큰(같은 던전을 두 번 등록한 리스트)
$ITEMS = @(
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '잊혀진 성소'; matching = '우연한 만남' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '일반'; dungeon = '그림자 회랑'; matching = '' })
$DUP_ITEMS = @(
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '잊혀진 성소'; matching = '우연한 만남' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '' })
# 멈춘 사이 고친 리스트 - 0·1번은 그대로, 2번 항목의 난이도만 바뀜(1번 칸의 owner 는 지문만 다름)
$EDITED_ITEMS = @(
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '잊혀진 성소'; matching = '우연한 만남' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '그림자 회랑'; matching = '' })

# ===== 소스 추출 (최상위 정의) =====
$guiTokens = $null
$parseErrors = $null
$guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ('GUI 파서 오류: ' + $parseErrors[0].Message) }
$extractedCounts = @()
$guiFunctionTexts = @{}
foreach ($functionName in $GUI_FUNCTION_NAMES) {
    $functionAsts = @($guiAst.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
            }, $true))
    $extractedCounts += ('{0}={1}' -f $functionName, $functionAsts.Count)
    if ($functionAsts.Count -ne 1) { throw ('GUI 함수 정의가 1개가 아닙니다: {0} ({1}개)' -f $functionName, $functionAsts.Count) }
    $guiFunctionTexts[$functionName] = $functionAsts[0].Extent.Text
    Invoke-Expression $functionAsts[0].Extent.Text
}
# 완료 기록 저장소 묶음 = 머리 주석 ~ '묶음 끝' 표지 주석 사이 최상위 함수 전부 (회귀 test_abyss_journal_store 와 같은 경계)
$bundleHeaders = @($guiTokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and $_.Text.Contains($BUNDLE_HEADER_FRAGMENT) })
$bundleEnds = @($guiTokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment -and $_.Text.Contains($BUNDLE_END_FRAGMENT) })
if ($bundleHeaders.Count -ne 1 -or $bundleEnds.Count -ne 1) {
    throw ('저장소 묶음 경계 주석이 1개씩이 아닙니다 (머리 {0} · 끝 {1})' -f $bundleHeaders.Count, $bundleEnds.Count)
}
$bundleFunctionNames = @()
foreach ($statement in $guiAst.EndBlock.Statements) {
    if (-not ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst])) { continue }
    if ($statement.Extent.StartOffset -lt $bundleHeaders[0].Extent.StartOffset) { continue }
    if ($statement.Extent.StartOffset -gt $bundleEnds[0].Extent.StartOffset) { break }
    Invoke-Expression $statement.Extent.Text
    $bundleFunctionNames += $statement.Name
}
if ($bundleFunctionNames -notcontains 'Update-AbyssJournal' -or $bundleFunctionNames -notcontains 'Read-AbyssJournal') {
    throw '완료 기록 저장소 묶음에서 Update-AbyssJournal · Read-AbyssJournal 을 찾지 못했습니다'
}
$script:abyssJournalSavedBy = 'gui'
$script:customConfigSection = $ABYSS_SECTION
# 단계 2.8 - 재개 기능 플래그는 GUI 원문의 스크립트 수준 대입 값 그대로(이 빌드 = 꺼짐), 켜진 빌드 행만 잠시 참(명세 3.4 '하니스에서 GUI 플래그를 참으로')
$retryFlagAssigns = @($guiAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssPartyRetryEnabled') })
if ($retryFlagAssigns.Count -ne 1) { throw ('GUI 의 재개 기능 플래그 스크립트 수준 대입이 1개가 아닙니다 ({0}개)' -f $retryFlagAssigns.Count) }
$GUI_RETRY_FLAG = [bool](Invoke-Expression $retryFlagAssigns[0].Right.Extent.Text)
$script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
# 타이머 코드 1 갈래(종료 코드 if 사슬의 마지막 else)에서 두 문장만 AST 로 잘라 둡니다(T4-e 3 방식 - 타이머 갈래 전체는 돌리지 않음, 명세 3.4 하니스):
#  ① 첫 문장 = 마무리 실행 기동 판별 if(오류 정지 · return)  ② $markerExists 대입문(예전 조건식 + 명세 5절 A10 항)
$exitChainIfs = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -ceq '($exitCode -eq 0) -or ($exitCode -eq 11)') }, $true))
if (($exitChainIfs.Count -ne 1) -or ($null -eq $exitChainIfs[0].ElseClause)) { throw '타이머 종료 코드 if 사슬(마지막 else 포함)을 찾지 못했습니다' }
$code1FirstStatement = @($exitChainIfs[0].ElseClause.Statements)[0]
if (-not (($code1FirstStatement -is [System.Management.Automation.Language.IfStatementAst]) -and ($code1FirstStatement.Clauses[0].Item1.Extent.Text -ceq "`$script:lastLaunchKind -eq 'finish-only'"))) {
    throw '코드 1 갈래의 첫 문장이 마무리 실행 판별 if 가 아닙니다'
}
$code1FinishOnlyBlock = [scriptblock]::Create($code1FirstStatement.Extent.Text)
$markerExistsAssigns = @($exitChainIfs[0].ElseClause.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$markerExists') }, $true))
if ($markerExistsAssigns.Count -ne 1) { throw ('코드 1 갈래의 $markerExists 대입문이 1개가 아닙니다 ({0}개)' -f $markerExistsAssigns.Count) }
$markerExistsBlock = [scriptblock]::Create($markerExistsAssigns[0].Extent.Text)
#  ③ 예전 처리 if 전체(커스텀 코드 1 의 recover/retry/3회째 정지 · 그 밖 오류 정지 - 갈래의 넷째 문장) - 단계 2.7·2.8 구현 리뷰 확인 라운드: 안전 중지 두 자리의 이번 기동
#     nonce 처리(recover 닫음 · retry 열어 둠 - 구현 리뷰 확인)를 실제 config·journal 로 돌리고 다음 수동 시작까지 잇는 행(C12·C13). 앞 문장(라우팅)은 행이 실제
#     Invoke-Code1JournalRouting 으로 돌려 그 반환을 넘김
$code1LegacyIfs = @($exitChainIfs[0].ElseClause.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.IfStatementAst]) -and
        ($_.Clauses[0].Item1.Extent.Text -ceq '$script:customActive -and $exitCode -eq 1') })
if ($code1LegacyIfs.Count -ne 1) { throw ('코드 1 갈래의 예전 처리 if 가 1개가 아닙니다 ({0}개)' -f $code1LegacyIfs.Count) }
$code1LegacyBlock = [scriptblock]::Create($code1LegacyIfs[0].Extent.Text)
# 단계 2.9 이어받기 행 - 타이머 코드 0·11 갈래 본문 전체(명세 리뷰 3 P1 행의 '커스텀 코드 0') · 코드 10 갈래 첫 문장(끝 처리 - 명세 5절 A6ⓑ)
function Join-StatementText {
    # 문장 AST 들의 원문을 줄바꿈으로 이어 점소싱할 스크립트 블록으로 (문장 사이 주석은 빠짐 - 동작 무관)
    param($Statements)
    return [scriptblock]::Create(((@($Statements) | ForEach-Object { $_.Extent.Text }) -join "`r`n"))
}
$code0Block = Join-StatementText -Statements $exitChainIfs[0].Clauses[0].Item2.Statements
$code10Clauses = @($exitChainIfs[0].Clauses | Where-Object { $_.Item1.Extent.Text -ceq '$exitCode -eq 10' })
if ($code10Clauses.Count -ne 1) { throw ('타이머 코드 10 갈래가 1개가 아닙니다 ({0}개)' -f $code10Clauses.Count) }
$code10FirstBlock = Join-StatementText -Statements @(@($code10Clauses[0].Item2.Statements)[0])
# 단계 2.9 시작 게이트 - 시작 처리(Invoke-StartAutomation)의 그 문장들 (T4-e 3 방식 - 시작 처리 전체는 돌리지 않음, 명세 3.4 하니스):
#  ① 커스텀 게이트 블록 안: 진행 읽기 두 문장 → S0 → 진행 다시 읽기 → 지문 검사·완주 판정(S1) 두 if (랜덤 순서 준비 문장 앞까지)
#  ② 함수 본문: S3 판정 대입 → 적용 if → 마커 게이트를 감싼 바깥 if (세 문장)
#  ③ 함수 본문의 마지막 문장 = 첫 기동
$startFunctionAsts = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq 'Invoke-StartAutomation') }, $true))
if ($startFunctionAsts.Count -ne 1) { throw '시작 처리 함수(Invoke-StartAutomation)가 1개가 아닙니다' }
$startStatements = @($startFunctionAsts[0].Body.EndBlock.Statements)
$customGateIfs = @($startStatements | Where-Object { ($_ -is [System.Management.Automation.Language.IfStatementAst]) -and ($_.Clauses[0].Item1.Extent.Text -ceq '$script:customActive') -and
        (@($_.Clauses[0].Item2.Statements | Where-Object { $_.Extent.Text -ceq '$crProgress = $null' }).Count -eq 1) })
if ($customGateIfs.Count -ne 1) { throw ('커스텀 시작 게이트 블록(진행 읽기가 든 if ($script:customActive))이 1개가 아닙니다 ({0}개)' -f $customGateIfs.Count) }
$gateStatements = @($customGateIfs[0].Clauses[0].Item2.Statements)
$progressReadAt = -1
$shuffleGateAt = -1
for ($statementIndex = 0; $statementIndex -lt $gateStatements.Count; $statementIndex++) {
    $statementText = $gateStatements[$statementIndex].Extent.Text
    if (($progressReadAt -lt 0) -and ($statementText -ceq '$crProgress = $null')) { $progressReadAt = $statementIndex }
    if (($shuffleGateAt -lt 0) -and $statementText.StartsWith('if (-not (Confirm-CustomShuffleReady))')) { $shuffleGateAt = $statementIndex }
}
if (($progressReadAt -lt 0) -or ($shuffleGateAt -le $progressReadAt)) { throw ('시작 게이트의 진행 읽기({0})·랜덤 순서 준비({1}) 문장을 찾지 못했습니다' -f $progressReadAt, $shuffleGateAt) }
$startS0Statements = @($gateStatements[$progressReadAt..($shuffleGateAt - 1)])
$startS0Block = Join-StatementText -Statements $startS0Statements
$s3At = -1
for ($statementIndex = 0; $statementIndex -lt $startStatements.Count; $statementIndex++) {
    if ($startStatements[$statementIndex].Extent.Text -ceq '$startJournal = Get-AbyssStartJournalAction') { $s3At = $statementIndex }
}
if (($s3At -lt 0) -or ($s3At + 2 -ge $startStatements.Count)) { throw '시작 게이트 S3 판정 대입문을 찾지 못했습니다' }
$startS3Statements = @($startStatements[$s3At..($s3At + 2)])
$startS3Block = Join-StatementText -Statements $startS3Statements
$firstLaunchStatement = $startStatements[-1]
$firstLaunchBlock = Join-StatementText -Statements @($firstLaunchStatement)

# ===== GUI 의존 모형·감시 =====
$script:guiLogLines = New-Object System.Collections.Generic.List[string]
$script:events = New-Object System.Collections.Generic.List[string]
$script:updateTags = New-Object System.Collections.Generic.List[string]
function Add-GuiLog {
    # GUI 로그(실제 서명 param([string]$Message)) - 찍힌 줄을 모읍니다
    param([string]$Message)
    $script:guiLogLines.Add($Message)
}
$script:realStepCustomProgress = ${function:Step-CustomProgress}
function Step-CustomProgress {
    # 진행 전진(실제 서명 param([string]$SectionName = $script:customConfigSection)) - 횟수·순서를 적고 실제 함수로. 실제 전진이 끝난 뒤 갈고리
    # (끊김·파일 쥐기 주입)를 돌립니다 - 갈고리가 예외를 던지면 전진은 디스크에 남은 채 끊깁니다
    param([string]$SectionName = $script:customConfigSection)
    $script:stepCalls++
    $script:events.Add('step')
    $stepResult = & $script:realStepCustomProgress -SectionName $SectionName
    if ($null -ne $script:afterStepHook) { & $script:afterStepHook $script:stepCalls }
    return $stepResult
}
$script:realUpdateAbyssJournal = ${function:Update-AbyssJournal}
function Update-AbyssJournal {
    # 완료 기록 저장(실제 서명 param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect = $null)) - 횟수·순서·태그를 적고 실제 함수로.
    # 예외 주입(저장 전) · 저장이 끝난 뒤 갈고리(끊김 주입)
    param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect = $null)
    $script:updateCalls++
    $script:events.Add('update')
    if ($script:updateThrows) { throw $INJECTED_STORE_EXCEPTION }
    $updateResult = & $script:realUpdateAbyssJournal -Path $Path -Mutator $Mutator -Expect $Expect
    $script:updateTags.Add([string]$updateResult.Tag)
    if ($null -ne $script:afterUpdateHook) { & $script:afterUpdateHook $script:updateCalls }
    return $updateResult
}
$script:realReadAbyssJournal = ${function:Read-AbyssJournal}
function Read-AbyssJournal {
    # 완료 기록 잠금 읽기(실제 서명 param([string]$Path)) - 횟수·순서를 적고 실제 함수로. 예외 주입 · 읽은 뒤 갈고리(단계 2.9 - 앞 읽기는 성공하고 뒤
    # 읽기·저장이 다른 기록 주체의 잠금·손상을 만나는 상황: 갈고리는 그 호출 번호를 받음)
    param([string]$Path)
    $script:readCalls++
    $script:events.Add('read')
    if ($script:readThrows) { throw $INJECTED_STORE_EXCEPTION }
    $readResult = & $script:realReadAbyssJournal -Path $Path
    if ($null -ne $script:afterReadHook) { & $script:afterReadHook $script:readCalls }
    return $readResult
}
$script:realClearCustomMarkerFile = ${function:Clear-CustomMarkerFile}
function Clear-CustomMarkerFile {
    # 마커 정리(실제 서명 param([string]$Path)) - 횟수·순서·경로 이름을 적고 실제 함수로
    param([string]$Path)
    $script:markerClears++
    $script:events.Add('marker:' + [IO.Path]::GetFileName($Path))
    return (& $script:realClearCustomMarkerFile -Path $Path)
}

# ----- 단계 2.6 - 실제 기동(Start-NextCycle)·실행부가 기대는 GUI 모형 -----
$script:realGetCustomCurrentContext = ${function:Get-CustomCurrentContext}
function Get-CustomCurrentContext {
    # 진행 컨텍스트(실제 서명 param([string]$SectionName = $script:customConfigSection)) - 읽은 횟수를 세고 실제 함수로(마무리 실행 기동은 0 이어야 함).
    # 일시 읽기 실패 주입(단계 2.9 - $script:contextNullReads 가 남으면 앞에서부터 그 횟수만큼 $null: 설정 파일 일시 공유 위반 - 시작 게이트의 재시도·'판단 불가').
    # 예외 주입($script:contextThrows - 단계 2.7~2.9 구현 검증): S3 판정 안에서 예외가 난 상황(판정의 catch 가 시작을 거부하는지 - SG2′)
    param([string]$SectionName = $script:customConfigSection)
    $script:contextReads++
    if ($script:contextThrows) { throw $INJECTED_CONTEXT_EXCEPTION }
    if ([int]$script:contextNullReads -gt 0) {
        $script:contextNullReads--
        return $null
    }
    return (& $script:realGetCustomCurrentContext -SectionName $SectionName)
}
function Stop-AllRun {
    # 정지(실제 서명 param([string]$Reason, [switch]$IsError)) - '사유|오류 여부' 를 모으고 실제처럼 실행 상태를 끕니다
    param([string]$Reason, [switch]$IsError)
    $script:stops.Add(('{0}|{1}' -f $Reason, [bool]$IsError))
    $script:running = $false
}
function Move-WorkerLogToArchive {
    # 지난 회차 로그 보관(실제 서명 param([string]$Path, [string]$Suffix = '')) - 보관 없이 오프셋 0
    param([string]$Path, [string]$Suffix = '')
    return [long]0
}
function Set-CustomListRandomView {
    # 실행 중 목록 표시(실제 서명 param($Context)) - 화면 전용
    param($Context)
}
function Reset-CustomProgress {
    # 진행 초기화(실제 서명 param([string]$LogMessage = '', [string]$SectionName = $script:customConfigSection)) - 이 파일의 행은 바퀴 완주 보류를 쓰지 않음
    param([string]$LogMessage = '', [string]$SectionName = $script:customConfigSection)
    $script:events.Add('reset')
    return $true
}
$WATCHED_ENV_NAMES = @('HONEYNOGI_HANDOFF_NONCE', 'HONEYNOGI_RESUME_REENTRY', 'HONEYNOGI_FINISH_ONLY', 'HONEYNOGI_CUSTOM_ITEM', 'HONEYNOGI_CUSTOM_PREV',
    'HONEYNOGI_CUSTOM_NEXT', 'HONEYNOGI_CUSTOM_RESTART', 'HONEYNOGI_CUSTOM_RECOVERY', 'HONEYNOGI_CUSTOM_POSITION', 'HONEYNOGI_CUSTOM_LIST',
    'HONEYNOGI_CUSTOM_MARKER', 'HONEYNOGI_CUSTOM_OWNER', 'HONEYNOGI_CUSTOM_GENERATION', 'HONEYNOGI_LAST_RUN', 'HONEYNOGI_REPEAT_INFO',
    'HONEYNOGI_UNTIL_TIME', 'HONEYNOGI_APP_VERSION')
$originalWatchedEnv = @{}
foreach ($envName in $WATCHED_ENV_NAMES) { $originalWatchedEnv[$envName] = [Environment]::GetEnvironmentVariable($envName, 'Process') }
function Start-Process {
    # 워커 기동 모의 - PS 5.1 은 같은 이름의 함수를 cmdlet 보다 먼저 부릅니다. 기동 순간의 env 를 찍고 끝나지 않은 프로세스 모형을 돌려줍니다
    param([string]$FilePath, $ArgumentList, [string]$WindowStyle, [switch]$PassThru)
    $snapshot = @{}
    foreach ($envName in $WATCHED_ENV_NAMES) { $snapshot[$envName] = [string][Environment]::GetEnvironmentVariable($envName, 'Process') }
    [void]$script:launches.Add($snapshot)
    $script:events.Add('launch')
    return [pscustomobject]@{ Id = 4242; HasExited = $false }
}
$lblStatus = [pscustomobject]@{ Text = ''; ForeColor = $null }
$rbCatAbyss = [pscustomobject]@{ Checked = $true }
$rbCatDungeon = [pscustomobject]@{ Checked = $false }
$rbCatDeep = [pscustomobject]@{ Checked = $false }
$rbModeParty = [pscustomobject]@{ Checked = $false }
$rbAbyssPartyMember = [pscustomobject]@{ Checked = $false }
$workerScript = 'C:\honeynogi-test\mabinogi_run_once.ps1'   # 기동 인자로만 쓰임 (Start-Process 모의)
$appVersion = 'v-test'
$script:hostedExePath = ''
$script:mainCategory = 'battle'
$script:launches = New-Object System.Collections.ArrayList
$script:stops = New-Object System.Collections.Generic.List[string]

function Reset-Observation {
    # 관측·주입 상태를 비웁니다 (픽스처를 쓴 뒤 행마다)
    $script:events = New-Object System.Collections.Generic.List[string]
    $script:guiLogLines = New-Object System.Collections.Generic.List[string]
    $script:updateTags = New-Object System.Collections.Generic.List[string]
    $script:stepCalls = 0
    $script:updateCalls = 0
    $script:readCalls = 0
    $script:markerClears = 0
    $script:afterStepHook = $null
    $script:afterUpdateHook = $null
    $script:updateThrows = $false
    $script:readThrows = $false
    $script:contextReads = 0
    $script:contextNullReads = 0
    $script:contextThrows = $false
    $script:afterReadHook = $null
    $script:launches.Clear()
    $script:stops.Clear()
}

$script:heldStreams = New-Object System.Collections.Generic.List[System.IDisposable]
function Lock-TestFile {
    # 같은 프로세스가 파일을 쥡니다 - Share 'Read' = 읽기만 함께 허용(교체·삭제 실패) / 'None' = 읽기도 실패
    param([string]$Path, [string]$Share)
    $script:heldStreams.Add([IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]$Share))
}
function Lock-JournalLockFile {
    # 다른 기록 주체가 저장 잠금을 쥔 상태 - abyss_handoff.lock 을 만들어 쥡니다(닫으면 지워짐 - 저장소 잠금과 같은 방식)
    $lockPath = [IO.Path]::ChangeExtension($script:abyssJournalPath, '.lock')
    $script:heldStreams.Add((New-Object IO.FileStream($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096,
                [IO.FileOptions]::DeleteOnClose)))
}
function Unlock-TestFiles {
    foreach ($heldStream in $script:heldStreams) { $heldStream.Dispose() }
    $script:heldStreams.Clear()
}

$testRootFolder = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_pending_advance_' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRootFolder)
$script:caseCounter = 0
function Use-CaseFolder {
    # 케이스마다 새 임시 폴더 - GUI 함수가 읽는 경로 변수(config·journal·마커 4개)를 전부 그 폴더로. 전역 마커(마지막으로 시작한 섹션)는
    # 던전 마커로 둡니다 - 반영이 전역이 아니라 어비스 섹션 마커를 고르는지 봅니다
    param([string]$Name)
    Unlock-TestFiles
    $script:caseCounter++
    $folder = Join-Path $testRootFolder ('{0:D2}_{1}' -f $script:caseCounter, $Name)
    [void][IO.Directory]::CreateDirectory($folder)
    $script:caseFolder = $folder
    $script:configPath = Join-Path $folder 'config.json'
    $script:abyssJournalPath = Join-Path $folder 'abyss_handoff.json'
    $script:customDungeonMarkerFile = Join-Path $folder 'custom_done.marker'
    $script:customAbyssMarkerFile = Join-Path $folder 'abyss_custom_done.marker'
    $script:customDeepMarkerFile = Join-Path $folder 'deep_custom_done.marker'
    $script:customLifeMarkerFile = Join-Path $folder 'life_custom_done.marker'
    $script:customMarkerFile = $script:customDungeonMarkerFile
    Reset-Observation
}

# ===== 단언·관측 =====
function Assert-Case {
    param([string]$Name, $Actual, $Expect)
    if ("$Actual" -ceq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
    else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Get-ResultText {
    # 함수 출력 전체를 '개수:값,…' 으로 - bool 반환에 다른 출력이 섞이면(출력 누수) 개수가 늘어 드러납니다. 호출부는 @(…) 로 받아 넘깁니다
    param($Output)
    $outputItems = @($Output)
    return ('{0}:{1}' -f $outputItems.Count, (($outputItems | ForEach-Object { [string]$_ }) -join ','))
}

function Get-ParamSignature {
    # 함수 정의의 매개변수 서명 '타입 $이름, …' - 모의와 실제를 같은 방식으로 뽑아 비교합니다 (test_time_until_mode 와 같은 구현)
    param($Ast, [string]$Name)
    $functionAst = @($Ast.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $Name) }, $true)) | Select-Object -First 1
    if ($null -eq $functionAst) { return '(정의 없음)' }
    $paramBlock = $functionAst.Body.ParamBlock
    if ($null -eq $paramBlock) { return '(매개변수 없음)' }
    return (@($paramBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}

function Format-LogLines {
    # 이 행에서 찍힌 GUI 로그 전부를 ' ¶ ' 로 이어 한 줄로 (없으면 빈 문자열)
    return ((@($script:guiLogLines) | ForEach-Object { [string]$_ }) -join ' ¶ ')
}

function Get-NonceLabel {
    param([string]$Nonce)
    if ($NONCE_LABELS.ContainsKey($Nonce)) { return $NONCE_LABELS[$Nonce] }
    return $Nonce
}

function Get-FileDigest {
    # 파일 내용 해시 앞 16자(없으면 '없음') - '바뀌지 않음' 단언용
    param([string]$Path)
    if (-not [IO.File]::Exists($Path)) { return '없음' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($Path)))).Replace('-', '').Substring(0, 16) }
    finally { $sha.Dispose() }
}

function Get-FolderListing {
    return ((@([IO.Directory]::GetFiles($script:caseFolder)) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object) -join ',')
}

function Get-JournalState {
    # journal 본 파일·직전본 내용 해시 + 폴더의 abyss_handoff* 파일 목록 - '파일 무변경' 단언용
    $journalFiles = @(@([IO.Directory]::GetFiles($script:caseFolder)) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $_ -like '*abyss_handoff*' } | Sort-Object)
    return ('{0}/{1} [{2}]' -f (Get-FileDigest $script:abyssJournalPath), (Get-FileDigest ($script:abyssJournalPath + '.bak')), ($journalFiles -join ','))
}

function Read-TestJournal {
    if (-not [IO.File]::Exists($script:abyssJournalPath)) { return $null }
    return ([IO.File]::ReadAllText($script:abyssJournalPath) | ConvertFrom-Json)
}

function Get-PendingText {
    # 대기열을 '단계:nonce:lap/index, …' 로 (A1 = inside-handoff · C1 = code1-routed · A2 = finish-only-complete)
    $journal = Read-TestJournal
    if ($null -eq $journal) { return '(파일 없음)' }
    return ((@($journal.pending) | ForEach-Object {
                $stageText = [string]$_.stage
                if ($STAGE_SHORT.ContainsKey($stageText)) { $stageText = $STAGE_SHORT[$stageText] }
                '{0}:{1}:{2}/{3}' -f $stageText, (Get-NonceLabel ([string]$_.nonce)), $_.owner.lap, $_.owner.index
            }) -join ',')
}

function Get-AppliedText {
    $journal = Read-TestJournal
    if ($null -eq $journal) { return '(파일 없음)' }
    return ((@($journal.applied) | ForEach-Object { Get-NonceLabel ([string]$_) }) -join ',')
}

function Get-ProgressText {
    # 디스크 진행 'lap/index'
    $config = [IO.File]::ReadAllText($script:configPath) | ConvertFrom-Json
    return ('{0}/{1}' -f $config.abyssCustomRepeat.progress.lap, $config.abyssCustomRepeat.progress.index)
}

function Get-EventText {
    return (@($script:events) -join ',')
}

# ===== 픽스처 =====
function Write-TestConfig {
    # 어비스 커스텀 섹션만 둔 config. -Order 를 주면 랜덤 진행(그 순열이 이번 바퀴) · -Items @() 면 항목 없음(진행 위치를 읽을 수 없음) ·
    # -ProgressItems 를 주면 진행 지문만 그 목록으로(멈춘 사이 리스트를 고쳐 진행 지문이 옛 목록인 모양 - 시작 게이트 S1 이 초기화할 상태)
    param([int]$Lap = 1, [int]$Index = 0, [int]$Generation = $GENERATION, $Items = $ITEMS, $Order = $null, [string]$Path = $script:configPath, $ProgressItems = $null,
        [string]$ListRepeat = 'infinite', [int]$ListRepeatCount = 1)
    if ($null -eq $ProgressItems) { $ProgressItems = $Items }
    $progress = [pscustomobject]@{ lap = $Lap; index = $Index; fingerprint = (Get-CustomFingerprint -Items $ProgressItems) }
    if ($null -ne $Order) { $progress | Add-Member -NotePropertyName 'shuffleOrder' -NotePropertyValue ([array]@($Order)) }
    $config = [pscustomobject]@{
        configSchemaVersion = 11
        abyssCustomRepeat   = [pscustomobject]@{
            items              = [array]@($Items)
            randomOrder        = ($null -ne $Order)
            listRepeat         = $ListRepeat
            listRepeatCount    = $ListRepeatCount
            progressGeneration = $Generation
            progress           = $progress
        }
    }
    [IO.File]::WriteAllText($Path, ($config | ConvertTo-Json -Depth 20), $UTF8_BOM)
}

function Get-TestOwner {
    # 그 위치의 owner 와 위치 문구 - 실제 Get-CustomCurrentContext → Get-CustomCanonicalOwner 로 만듭니다(사본 계산 없음). 케이스 config 를
    # 건드리지 않도록 따로 둔 임시 config 를 잠깐 가리킵니다
    param([int]$Lap = 1, [int]$Index = 0, [int]$Generation = $GENERATION, $Items = $ITEMS, $Order = $null)
    $savedConfigPath = $script:configPath
    $script:configPath = Join-Path $testRootFolder 'owner_probe_config.json'
    try {
        Write-TestConfig -Lap $Lap -Index $Index -Generation $Generation -Items $Items -Order $Order -Path $script:configPath
        $context = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
        return @{ Owner = (Get-CustomCanonicalOwner -Context $context); Position = [string]$context.Position }
    } finally {
        $script:configPath = $savedConfigPath
    }
}

function Add-TestPending {
    # 픽스처 대기열 원소 - 실제 Add-AbyssPendingEntry 로 씁니다(원소 모양을 테스트가 다시 만들지 않음)
    param([int]$Lap, [int]$Index, [string]$Stage, [string]$Nonce, [int]$Generation = $GENERATION, $Items = $ITEMS, $Order = $null)
    $ownerInfo = Get-TestOwner -Lap $Lap -Index $Index -Generation $Generation -Items $Items -Order $Order
    $added = @(Add-AbyssPendingEntry -Stage $Stage -Owner $ownerInfo.Owner -Generation $Generation -Nonce $Nonce)
    if ((Get-ResultText $added) -cne '1:True') { throw ('픽스처 대기열 기록 실패: ' + (Get-ResultText $added) + ' / ' + (Format-LogLines)) }
}

function Write-TestJournal {
    # entries·applied 를 둔 journal - 저장소 직렬화(ConvertTo-AbyssJournalText - 읽기 규칙 검사 포함) 그대로 씁니다
    param($Entries = @(), $Applied = @())
    $journal = New-AbyssJournalEmpty
    $journal.seq = 1
    $journal.entries = [object[]]@($Entries)
    $journal.applied = [object[]]@($Applied)
    [IO.File]::WriteAllText($script:abyssJournalPath, (ConvertTo-AbyssJournalText -Journal $journal), $UTF8_BOM)
}

function Write-TestMarkers {
    # 어비스 완료 마커(그 위치 owner 의 version 3 JSON - 마무리 실행 워커가 남기는 모양) + 전역 마커 자리의 던전 마커(건드리면 안 됨)
    param([int]$Lap, [int]$Index)
    $ownerInfo = Get-TestOwner -Lap $Lap -Index $Index
    [IO.File]::WriteAllText($script:customAbyssMarkerFile, (ConvertTo-CustomMarkerOwnerJson -Owner $ownerInfo.Owner))
    [IO.File]::WriteAllText($script:customDungeonMarkerFile, 'dungeon-marker')
}

function Get-MarkerState {
    # 어비스 마커 · 던전(전역) 마커 내용 해시
    return ('{0}/{1}' -f (Get-FileDigest $script:customAbyssMarkerFile), (Get-FileDigest $script:customDungeonMarkerFile))
}

function New-TwoElementQueue {
    # 흔한 대기열: 진행 i(1바퀴 0번)에서 재입장 실행부가 진행 저장에 실패해 남긴 A1(owner i) + 마무리 실행 완주 A2(owner i+1). 완주한 판의
    # 마커(owner i+1)와 던전 마커도 둡니다
    param([string]$SecondNonce = $NONCE_2)
    Write-TestConfig -Lap 1 -Index 0
    Write-TestMarkers -Lap 1 -Index 1
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
    Add-TestPending -Lap 1 -Index 1 -Stage $STAGE_A2 -Nonce $SecondNonce
}

# ===== G 하니스 =====
function Test-CaseHarness {
    Assert-Case 'G1 추출: GUI 함수 정의가 이름마다 1개' ($extractedCounts -join ', ') ((@($GUI_FUNCTION_NAMES | ForEach-Object { '{0}=1' -f $_ })) -join ', ')
    $selfAst = [System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$null, [ref]$null)
    foreach ($spyName in $SPY_FUNCTION_NAMES) {
        Assert-Case "G2 감시·모의 $spyName 서명 = GUI 실제 서명" (Get-ParamSignature $selfAst $spyName) (Get-ParamSignature $guiAst $spyName)
    }
}

# ===== Q 큐 기록 =====
function Test-CaseRecord {
    # Q1 파일이 없을 때 첫 기록 - 원소 모양·값, 다른 칸 그대로, 저장 1회, 로그 0
    Use-CaseFolder 'q1_first_record'
    Write-TestConfig
    $ownerInfo = Get-TestOwner -Lap 1 -Index 1
    Reset-Observation
    $result = @(Add-AbyssPendingEntry -Stage $STAGE_A1 -Owner $ownerInfo.Owner -Generation $GENERATION -Nonce $NONCE_1)
    $journal = Read-TestJournal
    $element = @($journal.pending)[0]
    Assert-Case 'Q1 첫 기록(파일 없음): 반환 하나 참 · 저장 1회 changed · 로그 0 · 대기열 1 · entries·applied 0' `
        ('{0} · {1}:{2} · {3} · {4} · {5}/{6}' -f (Get-ResultText $result), $script:updateCalls, ($script:updateTags -join ','), $script:guiLogLines.Count,
            @($journal.pending).Count, @($journal.entries).Count, @($journal.applied).Count) '1:True · 1:changed · 0 · 1 · 0/0'
    Assert-Case 'Q1 원소 필드 순서 = owner·generation·nonce·stage·createdAt · owner 는 5필드만(세대는 형제 필드)' `
        ('{0} | {1}' -f ((@($element.PSObject.Properties) | ForEach-Object { $_.Name }) -join ','), ((@($element.owner.PSObject.Properties) | ForEach-Object { $_.Name }) -join ',')) `
        'owner,generation,nonce,stage,createdAt | fingerprint,orderKey,lap,index,item'
    $want = $ownerInfo.Owner
    Assert-Case 'Q1 값 = 그 위치의 canonical owner 5필드 · 세대 · nonce · 단계' `
        ('{0}|{1}|{2}|{3}|{4} g{5} {6} {7}' -f $element.owner.fingerprint, $element.owner.orderKey, $element.owner.lap, $element.owner.index, $element.owner.item,
            $element.generation, $element.nonce, $element.stage) `
        ('{0}|{1}|{2}|{3}|{4} g{5} {6} {7}' -f $want.fingerprint, $want.orderKey, $want.lap, $want.index, $want.item, $GENERATION, $NONCE_1, $STAGE_A1)
    $createdAt = ConvertFrom-AbyssJournalTime -Text $element.createdAt
    Assert-Case 'Q1 숫자 칸은 JSON 정수(lap·index·generation) · 만든 시각은 저장소 시각 형식(왕복 읽기 · 지금부터 1분 안)' `
        ('{0}/{1}/{2} · {3}' -f ($element.owner.lap -is [int]), ($element.owner.index -is [int]), ($element.generation -is [int]),
            ($null -ne $createdAt -and [Math]::Abs(([DateTime]::Now - $createdAt).TotalSeconds) -lt 60)) 'True/True/True · True'

    # Q2 끝에 덧붙임 - 앞 원소·entries·applied 그대로, seq +1
    Use-CaseFolder 'q2_append'
    Write-TestConfig
    $clearedEntry = New-AbyssJournalEntry -Stage 'cleared'
    $clearedEntry.nonce = $NONCE_X
    $clearedEntry.section = $ABYSS_SECTION
    Write-TestJournal -Entries @($clearedEntry) -Applied @($NONCE_X)
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
    $before = Read-TestJournal
    $keptBefore = ConvertTo-Json -InputObject @(@($before.entries), @($before.applied), @(@($before.pending)[0])) -Depth 10 -Compress
    $owner2 = (Get-TestOwner -Lap 1 -Index 1).Owner
    Reset-Observation
    $result = @(Add-AbyssPendingEntry -Stage $STAGE_A2 -Owner $owner2 -Generation $GENERATION -Nonce $NONCE_2)
    $after = Read-TestJournal
    $keptAfter = ConvertTo-Json -InputObject @(@($after.entries), @($after.applied), @(@($after.pending)[0])) -Depth 10 -Compress
    Assert-Case 'Q2 끝에 덧붙임: 반환 참 · 대기열 = 앞 원소 + 새 원소 · seq +1 · entries·applied·앞 원소 글자 그대로' `
        ('{0} · {1} · {2} · {3}' -f (Get-ResultText $result), (Get-PendingText), ([long]$after.seq - [long]$before.seq), ($keptAfter -ceq $keptBefore)) `
        '1:True · A1:N1:1/0,A2:N2:1/1 · 1 · True'

    # Q3 owner 입력 모양 - Get-CustomCanonicalOwner 해시테이블(generation 키 포함)·journal nextOwner 모양 객체(모르는 필드 포함) 모두 5필드만
    #     옮기고, 세대는 -Generation 값입니다(owner 안의 generation 을 쓰지 않음)
    Use-CaseFolder 'q3_owner_shapes'
    Write-TestConfig
    $canonical = (Get-TestOwner -Lap 1 -Index 2).Owner
    $objectOwner = [pscustomobject]@{
        fingerprint = $canonical.fingerprint; orderKey = $canonical.orderKey; lap = $canonical.lap; index = $canonical.index; item = $canonical.item
        generation = 9; extra = 'x'
    }
    Reset-Observation
    $resultHash = @(Add-AbyssPendingEntry -Stage $STAGE_CODE1 -Owner $canonical -Generation 5 -Nonce $NONCE_1)
    $resultObject = @(Add-AbyssPendingEntry -Stage $STAGE_A2 -Owner $objectOwner -Generation $GENERATION -Nonce $NONCE_2)
    $elements = @((Read-TestJournal).pending)
    Assert-Case 'Q3 해시테이블 owner(generation 키 2) + -Generation 5 → 세대 5 · owner 5필드 / 객체 owner(generation 9·extra) → 세대 2 · owner 5필드' `
        ('{0}/{1} · g{2} {3} · g{4} {5} · 같은 값 {6}' -f (Get-ResultText $resultHash), (Get-ResultText $resultObject), $elements[0].generation,
            ((@($elements[0].owner.PSObject.Properties) | ForEach-Object { $_.Name }) -join ','), $elements[1].generation,
            ((@($elements[1].owner.PSObject.Properties) | ForEach-Object { $_.Name }) -join ','),
            ((ConvertTo-Json -InputObject $elements[0].owner -Compress) -ceq (ConvertTo-Json -InputObject $elements[1].owner -Compress))) `
        '1:True/1:True · g5 fingerprint,orderKey,lap,index,item · g2 fingerprint,orderKey,lap,index,item · 같은 값 True'
}

function Test-CaseRecordReject {
    # Q4 단계는 3종만 (명세 5절 B7) - 그 밖은 쓰지 않음(저장 0 · 파일 그대로)
    Use-CaseFolder 'q4_stages'
    Write-TestConfig
    $owner = (Get-TestOwner -Lap 1 -Index 0).Owner
    Reset-Observation
    $accepted = foreach ($stage in @($STAGE_A1, $STAGE_CODE1, $STAGE_A2)) { Get-ResultText @(Add-AbyssPendingEntry -Stage $stage -Owner $owner -Generation $GENERATION -Nonce $NONCE_1) }
    Assert-Case 'Q4 단계 3종(inside-handoff · code1-routed · finish-only-complete) → 각각 저장 · 대기열 순서 그대로 · 로그 0' `
        ('{0} · {1} · {2}' -f ($accepted -join ','), (Get-PendingText), $script:guiLogLines.Count) '1:True,1:True,1:True · A1:N1:1/0,C1:N1:1/0,A2:N1:1/0 · 0'
    $stateBefore = Get-JournalState
    Reset-Observation
    $rejected = foreach ($stage in @('post-clear-stop', 'Inside-Handoff', '')) { Get-ResultText @(Add-AbyssPendingEntry -Stage $stage -Owner $owner -Generation $GENERATION -Nonce $NONCE_1) }
    Assert-Case 'Q4 그 밖 단계(post-clear-stop · 대소문자 다름 · 빈 값) → 거짓 · 저장 0 · 파일 그대로 · [오류] 형식 줄' `
        ('{0} · {1} · {2} · {3}' -f ($rejected -join ','), $script:updateCalls, ((Get-JournalState) -ceq $stateBefore), (Format-LogLines)) `
        ('1:False,1:False,1:False · 0 · True · ' + ((@("단계 'post-clear-stop'", "단계 'Inside-Handoff'", "단계 ''") | ForEach-Object { $SHAPE_FAIL_FORMAT -f $_ }) -join ' ¶ '))

    # Q5 반영 쪽이 대조할 수 없는 원소는 쓰지 않음 - owner 없음·필드 없음 · 세대가 0 이상 정수가 아님(빠뜨림 포함) · nonce 없음
    Use-CaseFolder 'q5_shape'
    Write-TestConfig
    $owner = (Get-TestOwner -Lap 1 -Index 0).Owner
    $noLapOwner = @{} + $owner
    $noLapOwner.Remove('lap')
    $rows = @(
        @{ Owner = $null; Generation = $GENERATION; Nonce = $NONCE_1; Detail = 'owner 의 fingerprint 없음' },
        @{ Owner = $noLapOwner; Generation = $GENERATION; Nonce = $NONCE_1; Detail = 'owner 의 lap 없음' },
        @{ Owner = $owner; Generation = $null; Nonce = $NONCE_1; Detail = "세대 ''" },
        @{ Owner = $owner; Generation = -1; Nonce = $NONCE_1; Detail = "세대 '-1'" },
        @{ Owner = $owner; Generation = '1.5'; Nonce = $NONCE_1; Detail = "세대 '1.5'" },
        @{ Owner = $owner; Generation = $GENERATION; Nonce = ''; Detail = 'nonce 없음' })
    Reset-Observation
    $results = foreach ($row in $rows) { Get-ResultText @(Add-AbyssPendingEntry -Stage $STAGE_A1 -Owner $row.Owner -Generation $row.Generation -Nonce $row.Nonce) }
    Assert-Case 'Q5 owner 없음 · lap 없음 · 세대 빠뜨림·음수·소수 · nonce 없음 → 거짓 6 · 저장 0 · 파일 생성 0 · [오류] 형식 줄 6' `
        ('{0} · {1} · {2} · {3}' -f ($results -join ','), $script:updateCalls, (Get-FolderListing), (Format-LogLines)) `
        ('{0} · 0 · config.json · {1}' -f ((@(1..6) | ForEach-Object { '1:False' }) -join ','), ((@($rows) | ForEach-Object { $SHAPE_FAIL_FORMAT -f $_.Detail }) -join ' ¶ '))
}

function Test-CaseRecordStoreFail {
    # Q6 저장 실패 → 거짓 · [오류] 한 줄(실패 종류 낱말) · 파일 무변경 · 예외 0
    Use-CaseFolder 'q6_store_fail'
    Write-TestConfig
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
    $owner2 = (Get-TestOwner -Lap 1 -Index 1).Owner
    $stateBefore = Get-JournalState
    $outcomes = @()
    # (가) 다른 기록 주체가 잠금을 쥠 → locked
    Reset-Observation
    Lock-JournalLockFile
    $result = @(Add-AbyssPendingEntry -Stage $STAGE_A2 -Owner $owner2 -Generation $GENERATION -Nonce $NONCE_2)
    Unlock-TestFiles
    $outcomes += ('{0} {1} {2} {3}' -f (Get-ResultText $result), ($script:updateTags -join ','), ((Get-JournalState) -ceq $stateBefore), (Format-LogLines))
    # (나) 본 파일을 읽기만 허용하고 쥠 → 교체 실패 → io-failed
    Reset-Observation
    Lock-TestFile -Path $script:abyssJournalPath -Share 'Read'
    $result = @(Add-AbyssPendingEntry -Stage $STAGE_A2 -Owner $owner2 -Generation $GENERATION -Nonce $NONCE_2)
    Unlock-TestFiles
    $outcomes += ('{0} {1} {2} {3}' -f (Get-ResultText $result), ($script:updateTags -join ','), ((Get-JournalState) -ceq $stateBefore), (Format-LogLines))
    # (다) 저장소 예외 → 잡아서 거짓
    Reset-Observation
    $script:updateThrows = $true
    $result = @(Add-AbyssPendingEntry -Stage $STAGE_A2 -Owner $owner2 -Generation $GENERATION -Nonce $NONCE_2)
    $script:updateThrows = $false
    $outcomes += ('{0} - {1} {2}' -f (Get-ResultText $result), ((Get-JournalState) -ceq $stateBefore), (Format-LogLines))
    Assert-Case 'Q6 잠금(locked) · 교체 실패(io-failed) · 저장소 예외 → 거짓 · 파일 무변경 · [오류] 줄(파일 사용 중 / 기록 실패 / 예외)' ($outcomes -join ' || ') `
        (@(('1:False locked True ' + ($RECORD_FAIL_FORMAT -f '파일 사용 중')), ('1:False io-failed True ' + ($RECORD_FAIL_FORMAT -f '기록 실패')),
            ('1:False - True ' + ($RECORD_FAIL_FORMAT -f ('예외: ' + $INJECTED_STORE_EXCEPTION)))) -join ' || ')
    # (라) 본 파일·직전본 둘 다 손상 → corrupt (파일 보존)
    Use-CaseFolder 'q6_corrupt'
    Write-TestConfig
    [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
    [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JSON)
    $owner2 = (Get-TestOwner -Lap 1 -Index 1).Owner
    $stateBefore = Get-JournalState
    Reset-Observation
    $result = @(Add-AbyssPendingEntry -Stage $STAGE_A2 -Owner $owner2 -Generation $GENERATION -Nonce $NONCE_2)
    Assert-Case 'Q6 본 파일·직전본 손상(corrupt) → 거짓 · 파일 무변경 · [오류] 파일 손상' `
        ('{0} {1} {2} {3}' -f (Get-ResultText $result), ($script:updateTags -join ','), ((Get-JournalState) -ceq $stateBefore), (Format-LogLines)) `
        ('1:False corrupt True ' + ($RECORD_FAIL_FORMAT -f '파일 손상'))

    # Q7 저장소의 복구 경고를 남김 - 본 파일 손상 + 직전본 유효 → 저장은 성공(직전본 기준으로 덧붙임), 저장소가 돌려준 경고 1줄(로그는 호출부 몫)
    Use-CaseFolder 'q7_recover_warning'
    Write-TestConfig
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1   # seq 1 (본 파일만)
    Add-TestPending -Lap 1 -Index 1 -Stage $STAGE_A2 -Nonce $NONCE_2   # seq 2 - 직전본 = seq 1
    [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
    $owner3 = (Get-TestOwner -Lap 1 -Index 2).Owner
    Reset-Observation
    $result = @(Add-AbyssPendingEntry -Stage $STAGE_CODE1 -Owner $owner3 -Generation $GENERATION -Nonce $NONCE_3)
    Assert-Case 'Q7 본 파일 손상·직전본 유효 → 저장 참 · 저장소 복구 경고 1줄 · 대기열 = 직전본 원소 + 새 원소' `
        ('{0} · {1} · {2}' -f (Get-ResultText $result), (Format-LogLines), (Get-PendingText)) ('1:True · {0} · A1:N1:1/0,C1:N3:1/2' -f $STORE_RECOVER_WARNING)
}

# ===== A 큐 반영 =====
function Test-CaseAdvanceEmpty {
    # A1 빈 대기열 - 할 일이 없으면 읽기 1번뿐(전진·저장·마커 정리 0), 파일 그대로, 로그 0
    Use-CaseFolder 'a1_no_file'
    Write-TestConfig
    $listingBefore = Get-FolderListing
    Reset-Observation
    $result = @(Invoke-AbyssPendingAdvance -Caller 'start')
    Assert-Case 'A1 journal 파일 없음 · start → 참 · 읽기 1 · 전진·저장·마커 0 · 파일 생성 0 · 로그 0' `
        ('{0} · {1} · {2} · {3}' -f (Get-ResultText $result), (Get-EventText), ((Get-FolderListing) -ceq $listingBefore), $script:guiLogLines.Count) '1:True · read · True · 0'
    Use-CaseFolder 'a1_empty_queue'
    Write-TestConfig
    $clearedEntry = New-AbyssJournalEntry -Stage 'cleared'
    $clearedEntry.nonce = $NONCE_X
    Write-TestJournal -Entries @($clearedEntry)
    Write-TestMarkers -Lap 1 -Index 0
    $stateBefore = '{0} {1} {2}' -f (Get-JournalState), (Get-MarkerState), (Get-ProgressText)
    Reset-Observation
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Assert-Case 'A1 대기열 빈 journal · finish → 참 · 읽기 1 · 마커 정리 0(대기열을 비운 호출이 아님) · journal·마커·진행 그대로 · 로그 0' `
        ('{0} · {1} · {2} · {3}' -f (Get-ResultText $result), (Get-EventText), (('{0} {1} {2}' -f (Get-JournalState), (Get-MarkerState), (Get-ProgressText)) -ceq $stateBefore),
            $script:guiLogLines.Count) '1:True · read · True · 0'
}

function Test-CaseAdvanceOrder {
    # A2 큐 순서 반영(finish) - A1(owner i) → A2(owner i+1) 순서로 전진 총 2. 같은 판의 원소 둘이 같은 nonce 이고 재입장 처리가 이미 applied
    #     에 넣은 모양(설계 R1 3.4 순서 2 - 필수 기록이 applied). 대기열이 빈 뒤에 어비스 마커만 정리(전역 자리의 던전 마커는 그대로), 로그 0
    Use-CaseFolder 'a2_finish_order'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestMarkers -Lap 1 -Index 1
    Write-TestJournal -Applied @($NONCE_1)
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
    Add-TestPending -Lap 1 -Index 1 -Stage $STAGE_A2 -Nonce $NONCE_1
    $dungeonMarkerBefore = Get-FileDigest $script:customDungeonMarkerFile
    Reset-Observation
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Assert-Case 'A2 finish: 참 · 진행 1/0 → 1/2(전진 총 2) · 대기열 빔 · applied 의 그 nonce 1번 · 로그 0' `
        ('{0} · {1} · [{2}] · {3} · {4}' -f (Get-ResultText $result), (Get-ProgressText), (Get-PendingText), (Get-AppliedText), $script:guiLogLines.Count) '1:True · 1/2 · [] · N1 · 0'
    Assert-Case 'A2 finish 순서: 읽기 → 전진 → 제거 → 읽기 → 전진 → 제거 → 읽기(빔) → 어비스 마커 정리 1 · 던전 마커 그대로' `
        ('{0} · {1} · {2}' -f (Get-EventText), [IO.File]::Exists($script:customAbyssMarkerFile), ((Get-FileDigest $script:customDungeonMarkerFile) -ceq $dungeonMarkerBefore)) `
        'read,step,update,read,step,update,read,marker:abyss_custom_done.marker · False · True'

    # A3 start(S0) 반영 - 같은 대기열, 전진마다 [경고] 한 줄(그 판의 위치) · 마커는 정리하지 않음(시작 게이트의 마무리 복구 근거)
    Use-CaseFolder 'a3_start_order'
    New-TwoElementQueue
    $markerBefore = Get-MarkerState
    $position0 = (Get-TestOwner -Lap 1 -Index 0).Position
    $position1 = (Get-TestOwner -Lap 1 -Index 1).Position
    Reset-Observation
    $result = @(Invoke-AbyssPendingAdvance -Caller 'start')
    Assert-Case 'A3 start: 참 · 진행 1/2 · 대기열 빔 · applied 두 nonce(처리 순서) · [경고] 전진 줄 2(dev:909 원문 · 각 판 위치)' `
        ('{0} · {1} · [{2}] · {3} · {4}' -f (Get-ResultText $result), (Get-ProgressText), (Get-PendingText), (Get-AppliedText), (Format-LogLines)) `
        ('1:True · 1/2 · [] · N1,N2 · {0} ¶ {1}' -f ($START_ADVANCE_FORMAT -f $position0), ($START_ADVANCE_FORMAT -f $position1))
    Assert-Case 'A3 start 는 마커를 정리하지 않음 - 마커 정리 호출 0 · 어비스·던전 마커 그대로' ('{0} · {1}' -f $script:markerClears, ((Get-MarkerState) -ceq $markerBefore)) '0 · True'

    # A11 같은 nonce 원소 둘(아직 applied 아님) - 둘 다 반영(전진 2)되고 applied 에는 그 nonce 1번. nonce 만으로 지우면 둘이 함께 사라져
    #     완주한 판의 전진을 잃습니다(반영 ③)
    Use-CaseFolder 'a11_same_nonce'
    New-TwoElementQueue -SecondNonce $NONCE_1
    Reset-Observation
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Assert-Case 'A11 같은 nonce 원소 둘 → 참 · 전진 2 · 진행 1/2 · 대기열 빔 · applied 의 그 nonce 1번' `
        ('{0} · {1} · {2} · [{3}] · {4}' -f (Get-ResultText $result), $script:stepCalls, (Get-ProgressText), (Get-PendingText), (Get-AppliedText)) '1:True · 2 · 1/2 · [] · N1'
}

function Test-CaseAdvanceSkip {
    # A4 지난 원소 skip - 진행이 이미 다음 칸(1/1)인데 대기열 맨 앞이 1/0 원소(반영을 마친 뒤 제거 전에 끊긴 모양) → 전진 없이 제거 + applied,
    #     다음 원소는 전진. finish 라 대기열이 빈 뒤 마커 정리
    Use-CaseFolder 'a4_stale_skip'
    Write-TestConfig -Lap 1 -Index 1
    Write-TestMarkers -Lap 1 -Index 1
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_S
    Add-TestPending -Lap 1 -Index 1 -Stage $STAGE_A2 -Nonce $NONCE_2
    Reset-Observation
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Assert-Case 'A4 지난 원소: 참 · 전진 1(뒤 원소만) · 진행 1/2 · 대기열 빔 · applied = 건너뛴 nonce + 반영 nonce · [안내] 건너뜀 줄 1 · 마커 정리 1' `
        ('{0} · {1} · {2} · [{3}] · {4} · {5} · {6}' -f (Get-ResultText $result), $script:stepCalls, (Get-ProgressText), (Get-PendingText), (Get-AppliedText),
            (Format-LogLines), $script:markerClears) ('1:True · 1 · 1/2 · [] · NS,N2 · {0} · 1' -f ($SKIP_FORMAT -f $STAGE_A1))

    # A5 owner 비교 3케이스 - 원소와 지금 진행이 한 가지만 다르면 전진하지 않습니다(설계 v10 6.1 'orderKey·item·generation 까지' · dev:990).
    #     케이스마다 픽스처 owner 가 그 한 가지만 다른지 먼저 확인하고(자기 점검), 같은 자리에서 그 값만 맞춘 대조(′)는 전진합니다
    $negativeSteps = 0
    $negativeSkips = 0
    $positiveSteps = 0
    # (가) 순열 변경: 랜덤 진행 1바퀴 1번, 이번 바퀴 순열 [2,0,1] / 원소는 순열 [1,0,2] 의 같은 칸(두 순열 모두 그 칸이 0번 항목 - orderKey 만 다름)
    $ownerNow = (Get-TestOwner -Lap 1 -Index 1 -Order @(2, 0, 1)).Owner
    $ownerOld = (Get-TestOwner -Lap 1 -Index 1 -Order @(1, 0, 2)).Owner
    Assert-Case 'A5 (가) 자기 점검: 두 owner 는 orderKey 만 다름' (Compare-OwnerFields $ownerNow $ownerOld) 'orderKey'
    foreach ($variant in @(@{ Name = 'a5_order_changed'; Order = @(1, 0, 2); Positive = $false }, @{ Name = 'a5_order_same'; Order = @(2, 0, 1); Positive = $true })) {
        Use-CaseFolder $variant.Name
        Write-TestConfig -Lap 1 -Index 1 -Order @(2, 0, 1)
        Add-TestPending -Lap 1 -Index 1 -Stage $STAGE_A1 -Nonce $NONCE_1 -Order $variant.Order
        Reset-Observation
        $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
        if ($variant.Positive) { $positiveSteps += $script:stepCalls; $caseText = '(가′) 같은 순열 → 전진' } else { $negativeSteps += $script:stepCalls; $caseText = '(가) 순열 변경 → skip' }
        $negativeSkips += @($script:guiLogLines | Where-Object { $_ -ceq ($SKIP_FORMAT -f $STAGE_A1) }).Count * [int](-not $variant.Positive)
        Assert-Case "A5 $caseText · 참 · 대기열 빔" ('{0} · {1} · [{2}]' -f (Get-ResultText $result), (Get-ProgressText), (Get-PendingText)) `
            ('1:True · {0} · []' -f $(if ($variant.Positive) { '1/2' } else { '1/1' }))
    }
    # (나) 동일 토큰 중복: 리스트 0번·2번이 같은 항목, 진행 1바퀴 2번 / 원소는 0번(같은 토큰 - index 만 다름)
    $ownerNow = (Get-TestOwner -Lap 1 -Index 2 -Items $DUP_ITEMS).Owner
    $ownerOld = (Get-TestOwner -Lap 1 -Index 0 -Items $DUP_ITEMS).Owner
    Assert-Case 'A5 (나) 자기 점검: 두 owner 는 index 만 다름(항목 토큰 같음)' (Compare-OwnerFields $ownerNow $ownerOld) 'index'
    foreach ($variant in @(@{ Name = 'a5_dup_token'; Index = 0; Positive = $false }, @{ Name = 'a5_dup_same'; Index = 2; Positive = $true })) {
        Use-CaseFolder $variant.Name
        Write-TestConfig -Lap 1 -Index 2 -Items $DUP_ITEMS
        Add-TestPending -Lap 1 -Index $variant.Index -Stage $STAGE_A1 -Nonce $NONCE_1 -Items $DUP_ITEMS
        Reset-Observation
        $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
        if ($variant.Positive) { $positiveSteps += $script:stepCalls; $caseText = '(나′) 같은 칸 → 전진(바퀴 넘김)' } else { $negativeSteps += $script:stepCalls; $caseText = '(나) 같은 토큰 다른 칸 → skip' }
        $negativeSkips += @($script:guiLogLines | Where-Object { $_ -ceq ($SKIP_FORMAT -f $STAGE_A1) }).Count * [int](-not $variant.Positive)
        Assert-Case "A5 $caseText · 참 · 대기열 빔" ('{0} · {1} · [{2}]' -f (Get-ResultText $result), (Get-ProgressText), (Get-PendingText)) `
            ('1:True · {0} · []' -f $(if ($variant.Positive) { '2/0' } else { '1/2' }))
    }
    # (다) 초기화 뒤 재일치: 진행 초기화로 세대가 3, 진행은 다시 1바퀴 0번 / 원소는 세대 2 의 1바퀴 0번(5필드 그대로 - 세대만 다름)
    $ownerNow = (Get-TestOwner -Lap 1 -Index 0 -Generation 3).Owner
    $ownerOld = (Get-TestOwner -Lap 1 -Index 0 -Generation 2).Owner
    Assert-Case 'A5 (다) 자기 점검: 두 owner 의 5필드는 같음(세대만 다름 - 세대는 형제 필드)' (Compare-OwnerFields $ownerNow $ownerOld) '(같음)'
    foreach ($variant in @(@{ Name = 'a5_reset_regen'; Generation = 2; Positive = $false }, @{ Name = 'a5_reset_same'; Generation = 3; Positive = $true })) {
        Use-CaseFolder $variant.Name
        Write-TestConfig -Lap 1 -Index 0 -Generation 3
        Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1 -Generation $variant.Generation
        Reset-Observation
        $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
        if ($variant.Positive) { $positiveSteps += $script:stepCalls; $caseText = '(다′) 같은 세대 → 전진' } else { $negativeSteps += $script:stepCalls; $caseText = '(다) 초기화 뒤 재일치 → skip' }
        $negativeSkips += @($script:guiLogLines | Where-Object { $_ -ceq ($SKIP_FORMAT -f $STAGE_A1) }).Count * [int](-not $variant.Positive)
        Assert-Case "A5 $caseText · 참 · 대기열 빔" ('{0} · {1} · [{2}]' -f (Get-ResultText $result), (Get-ProgressText), (Get-PendingText)) `
            ('1:True · {0} · []' -f $(if ($variant.Positive) { '1/1' } else { '1/0' }))
    }
    # (라) 멈춘 사이 리스트를 고침: 진행 지문은 옛 목록, 1번 칸 항목·순서·세대는 그대로 / 원소는 옛 목록의 1번 칸(지문만 다름). 대조가 지문까지
    #     봐야 합니다 - S0 는 지문 불일치 초기화(S1)보다 앞이라, 칸만 맞는 원소로 전진하면 Step 이 새 지문을 진행에 적어 S1 이 바뀐 리스트를
    #     알아채지 못합니다(설계 v10 0.5 '유효 비교 = 5필드 AND generation'). 건너뛴 뒤 진행 지문은 옛 목록 그대로여야 합니다
    $ownerNow = (Get-TestOwner -Lap 1 -Index 1 -Items $EDITED_ITEMS).Owner
    $ownerOld = (Get-TestOwner -Lap 1 -Index 1 -Items $ITEMS).Owner
    Assert-Case 'A5 (라) 자기 점검: 두 owner 는 fingerprint 만 다름' (Compare-OwnerFields $ownerNow $ownerOld) 'fingerprint'
    foreach ($variant in @(@{ Name = 'a5_list_edited'; Items = $ITEMS; Positive = $false }, @{ Name = 'a5_list_same'; Items = $EDITED_ITEMS; Positive = $true })) {
        Use-CaseFolder $variant.Name
        Write-TestConfig -Lap 1 -Index 1 -Items $EDITED_ITEMS -ProgressItems $ITEMS
        Add-TestPending -Lap 1 -Index 1 -Stage $STAGE_A1 -Nonce $NONCE_1 -Items $variant.Items
        Reset-Observation
        $result = @(Invoke-AbyssPendingAdvance -Caller 'start')
        $fingerprintAfter = [string](([IO.File]::ReadAllText($script:configPath) | ConvertFrom-Json).abyssCustomRepeat.progress.fingerprint)
        if ($variant.Positive) { $positiveSteps += $script:stepCalls; $caseText = '(라′) 지금 목록의 같은 칸 → 전진(진행 지문 = 지금 목록)' } else { $negativeSteps += $script:stepCalls; $caseText = '(라) 지문만 다름 → skip(진행 지문 = 옛 목록 그대로)' }
        $negativeSkips += @($script:guiLogLines | Where-Object { $_ -ceq ($SKIP_FORMAT -f $STAGE_A1) }).Count * [int](-not $variant.Positive)
        Assert-Case "A5 $caseText · 참 · 대기열 빔" ('{0} · {1} · {2} · [{3}]' -f (Get-ResultText $result), (Get-ProgressText), ($fingerprintAfter -ceq (Get-CustomFingerprint -Items $variant.Items)), (Get-PendingText)) `
            ('1:True · {0} · True · []' -f $(if ($variant.Positive) { '1/2' } else { '1/1' }))
    }
    Assert-Case 'A5 합계: 한 가지만 다른 4케이스 전진 0 · 건너뜀 줄 4 / 대조 4케이스 전진 4' ('{0} · {1} / {2}' -f $negativeSteps, $negativeSkips, $positiveSteps) '0 · 4 / 4'
}

function Compare-OwnerFields {
    # 두 owner 의 5필드 중 값이 다른 이름들(같으면 '(같음)')
    param($Left, $Right)
    $different = @(@('fingerprint', 'orderKey', 'lap', 'index', 'item') | Where-Object { [string]$Left[$_] -cne [string]$Right[$_] })
    if ($different.Count -eq 0) { return '(같음)' }
    return ($different -join ',')
}

function Test-CaseAdvanceStepFail {
    # A6 진행 저장 실패 → 그 원소부터 대기열·마커 보존 + 거짓 (설계 v10 6.1 '반영 실패 → 큐·마커 보존 + 오류 정지' - 정지는 부른 쪽)
    #   (가) 첫 원소에서 실패: config 를 읽기만 허용하고 쥠(Step-CustomProgress 의 실제 실패 경로) → 진행·대기열·applied·마커 그대로
    Use-CaseFolder 'a6_first_step_fails'
    New-TwoElementQueue
    $stateBefore = '{0} {1} {2}' -f (Get-JournalState), (Get-MarkerState), (Get-ProgressText)
    Reset-Observation
    Lock-TestFile -Path $script:configPath -Share 'Read'
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Unlock-TestFiles
    $logLines = @($script:guiLogLines)
    Assert-Case 'A6 (가) 첫 원소 진행 저장 실패 → 거짓 · 전진 시도 1(뒤 원소 미시도) · 저장 0 · 마커 정리 0 · journal·마커·진행 그대로' `
        ('{0} · {1} · {2} · {3} · {4}' -f (Get-ResultText $result), $script:stepCalls, $script:updateCalls, $script:markerClears,
            (('{0} {1} {2}' -f (Get-JournalState), (Get-MarkerState), (Get-ProgressText)) -ceq $stateBefore)) '1:False · 1 · 0 · 0 · True'
    Assert-Case 'A6 (가) 로그: 진행 저장 실패 [오류](Step 자신) → 반영 실패 [오류] 한 줄(대기열·마커 보존)' `
        ('{0} · {1} · {2}' -f $logLines.Count, ($logLines.Count -ge 1 -and ([string]$logLines[0]).StartsWith($STEP_FAIL_PREFIX)), [string]$logLines[-1]) `
        ('2 · True · ' + ($ADVANCE_FAIL_FORMAT -f '진행 기록 저장 실패'))
    #   (나) 둘째 원소에서 실패: 첫 원소 전진 뒤 config 를 쥠 → 첫 원소만 반영(제거·applied), 둘째 원소·마커 그대로
    Use-CaseFolder 'a6_second_step_fails'
    New-TwoElementQueue
    $markerBefore = Get-MarkerState
    $configToHold = $script:configPath
    Reset-Observation
    $script:afterStepHook = { param($callNumber) if ($callNumber -eq 1) { Lock-TestFile -Path $configToHold -Share 'Read' } }.GetNewClosure()
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Unlock-TestFiles
    Assert-Case 'A6 (나) 둘째 원소 진행 저장 실패 → 거짓 · 진행 1/1 · 대기열 = 둘째 원소 · applied = 첫 nonce · 마커 정리 0 · 마커 그대로 · 마지막 줄' `
        ('{0} · {1} · [{2}] · {3} · {4} · {5} · {6}' -f (Get-ResultText $result), (Get-ProgressText), (Get-PendingText), (Get-AppliedText), $script:markerClears,
            ((Get-MarkerState) -ceq $markerBefore), [string]@($script:guiLogLines)[-1]) `
        ('1:False · 1/1 · [A2:N2:1/1] · N1 · 0 · True · ' + ($ADVANCE_FAIL_FORMAT -f '진행 기록 저장 실패'))

    # A7 지우기(제거·applied 저장) 실패 → 거짓 · 마커 정리 0 - 첫 원소 전진 뒤 본 파일을 읽기만 허용하고 쥠(교체 실패 io-failed). 전진은 디스크에
    #     남고 원소도 남습니다 - 다음 반영이 진행이 이미 다음 칸이라 그 원소를 건너뜁니다(A8 (가) 와 같은 모양)
    Use-CaseFolder 'a7_removal_fails'
    New-TwoElementQueue
    $journalStateBefore = Get-JournalState
    $markerBefore = Get-MarkerState
    $journalToHold = $script:abyssJournalPath
    Reset-Observation
    $script:afterStepHook = { param($callNumber) if ($callNumber -eq 1) { Lock-TestFile -Path $journalToHold -Share 'Read' } }.GetNewClosure()
    # 실패한 저장이 돌아오면 쥔 파일을 놓습니다 - 실패를 성공으로 넘기는 결함이면 다음 원소를 실제로 처리해 거짓 대신 참이 나와 드러납니다(놓지 않으면
    # 같은 원소를 1초씩 끝없이 다시 시도해 이 행이 멈춤)
    $script:afterUpdateHook = { param($callNumber) Unlock-TestFiles }
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Unlock-TestFiles
    Assert-Case 'A7 첫 원소 지우기 교체 실패 → 거짓 · 저장 태그 io-failed · 진행 1/1 · journal 그대로 · 마커 정리 0 · 마커 그대로 · 마지막 줄 기록 실패' `
        ('{0} · {1} · {2} · {3} · {4} · {5} · {6}' -f (Get-ResultText $result), ($script:updateTags -join ','), (Get-ProgressText), ((Get-JournalState) -ceq $journalStateBefore),
            $script:markerClears, ((Get-MarkerState) -ceq $markerBefore), [string]@($script:guiLogLines)[-1]) `
        ('1:False · io-failed · 1/1 · True · 0 · True · ' + ($ADVANCE_FAIL_FORMAT -f '기록 실패'))

    # A14 마커 정리 실패는 반영 실패가 아님 - finish 가 대기열을 비운 뒤 어비스 마커를 지우지 못하면(파일을 쥠) [경고] 한 줄 · 반영은 참. 진행은
    #     이미 마커의 판을 지나 다음 시작 게이트가 그 마커를 진행과 맞지 않는 것으로 폐기합니다(묘비는 Clear-CustomMarkerFile 계약)
    Use-CaseFolder 'a14_marker_clear_fails'
    New-TwoElementQueue
    Reset-Observation
    Lock-TestFile -Path $script:customAbyssMarkerFile -Share 'None'
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Unlock-TestFiles
    Assert-Case 'A14 finish 의 마커 정리 실패 → 참 · 진행 1/2 · 대기열 빔 · 마커 정리 1 · 묘비 남음 · [경고] 한 줄' `
        ('{0} · {1} · [{2}] · {3} · {4} · {5}' -f (Get-ResultText $result), (Get-ProgressText), (Get-PendingText), $script:markerClears,
            [IO.File]::Exists($script:customAbyssMarkerFile + '.stale'), (Format-LogLines)) `
        ('1:True · 1/2 · [] · 1 · True · ' + $MARKER_CLEAR_WARNING)
}

function Test-CaseAdvanceRestart {
    # A8 반영 도중 재시작 주입 - finish 반영이 4 지점(첫 전진 뒤 · 첫 제거 뒤 · 둘째 전진 뒤 · 둘째 제거 뒤 = 마커 정리 전)에서 끊긴 뒤 다음
    #     시작(start)이 다시 반영해도 전진 총 2(이중 전진 0 · 유실 0), 대기열 빔, applied 두 nonce. 끊긴 쪽 마지막 줄은 [오류] 반영 실패(예외).
    #     두 파일 순서(config → journal → 마커)와 원소별 owner 대조가 이 성질을 만듭니다(명세 2.5a ②). start 는 마커를 지우지 않으므로 마커는 남고
    #     시작 게이트가 진행과 맞지 않는 마커로 폐기합니다(2.9 몫)
    $position1 = (Get-TestOwner -Lap 1 -Index 1).Position
    $crashRows = @(
        @{ Name = 'a8_after_first_step'; Hook = 'step'; At = 1; Mid = '1/1 [A1:N1:1/0,A2:N2:1/1]'; Restart = (($SKIP_FORMAT -f $STAGE_A1) + ' ¶ ' + ($START_ADVANCE_FORMAT -f $position1)) },
        @{ Name = 'a8_after_first_removal'; Hook = 'update'; At = 1; Mid = '1/1 [A2:N2:1/1]'; Restart = ($START_ADVANCE_FORMAT -f $position1) },
        @{ Name = 'a8_after_second_step'; Hook = 'step'; At = 2; Mid = '1/2 [A2:N2:1/1]'; Restart = ($SKIP_FORMAT -f $STAGE_A2) },
        @{ Name = 'a8_after_second_removal'; Hook = 'update'; At = 2; Mid = '1/2 []'; Restart = '' })
    foreach ($crashRow in $crashRows) {
        Use-CaseFolder $crashRow.Name
        New-TwoElementQueue
        $markerBefore = Get-MarkerState
        Reset-Observation
        $crashAt = [int]$crashRow.At
        $crashMessage = $CRASH_MESSAGE
        $crashHook = { param($callNumber) if ($callNumber -eq $crashAt) { throw $crashMessage } }.GetNewClosure()
        if ($crashRow.Hook -eq 'step') { $script:afterStepHook = $crashHook } else { $script:afterUpdateHook = $crashHook }
        $firstResult = @(Invoke-AbyssPendingAdvance -Caller 'finish')
        $firstSteps = $script:stepCalls
        $firstLast = [string]@($script:guiLogLines)[-1]
        $midState = '{0} [{1}]' -f (Get-ProgressText), (Get-PendingText)
        Reset-Observation
        $restartResult = @(Invoke-AbyssPendingAdvance -Caller 'start')
        Assert-Case ("A8 끊김 {0} {1}번째 뒤: 끊긴 반영 거짓·마지막 줄 / 끊긴 뒤 진행·대기열 / 다시 반영 참 · 전진 합계 2 · 진행 1/2 · 대기열 빔 · applied · 마커 그대로 · 다시 반영 로그" -f $crashRow.Hook, $crashAt) `
            ('{0} {1} / {2} / {3} · {4} · {5} · [{6}] · {7} · {8} · {9}' -f (Get-ResultText $firstResult), $firstLast, $midState, (Get-ResultText $restartResult),
                ($firstSteps + $script:stepCalls), (Get-ProgressText), (Get-PendingText), (Get-AppliedText), ((Get-MarkerState) -ceq $markerBefore), (Format-LogLines)) `
            ('1:False {0} / {1} / 1:True · 2 · 1/2 · [] · N1,N2 · True · {2}' -f ($ADVANCE_FAIL_FORMAT -f ('예외: ' + $CRASH_MESSAGE)), $crashRow.Mid, $crashRow.Restart)
    }
}

function Test-CaseAdvanceFail {
    # A9 반영 실패 - 읽기 locked · corrupt · io-failed, 진행 위치를 못 읽음, 저장소 예외 → 거짓 · 전진 0 · 파일 그대로 · [오류] 한 줄 · 예외 0
    $failRows = @(
        @{ Name = 'a9_read_locked'; Word = '파일 사용 중' },
        @{ Name = 'a9_read_corrupt'; Word = '파일 손상' },
        @{ Name = 'a9_read_io'; Word = '기록 실패' },
        @{ Name = 'a9_no_context'; Word = '커스텀 진행 위치를 읽지 못함' },
        @{ Name = 'a9_read_throws'; Word = ('예외: ' + $INJECTED_STORE_EXCEPTION) })
    foreach ($failRow in $failRows) {
        Use-CaseFolder $failRow.Name
        Write-TestConfig -Lap 1 -Index 0
        Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1   # 원소 1개 - 쓰기 1번이라 직전본 없음
        if ($failRow.Name -eq 'a9_read_corrupt') {
            [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
            [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JSON)
        }
        if ($failRow.Name -eq 'a9_no_context') { Write-TestConfig -Lap 1 -Index 0 -Items @() }
        $stateBefore = '{0} {1}' -f (Get-JournalState), (Get-ProgressText)
        Reset-Observation
        if ($failRow.Name -eq 'a9_read_locked') { Lock-JournalLockFile }
        if ($failRow.Name -eq 'a9_read_io') { Lock-TestFile -Path $script:abyssJournalPath -Share 'None' }
        if ($failRow.Name -eq 'a9_read_throws') { $script:readThrows = $true }
        $result = @(Invoke-AbyssPendingAdvance -Caller 'start')
        Unlock-TestFiles
        Assert-Case ('A9 {0} → 거짓 · 전진 0 · 저장 0 · journal·진행 그대로 · [오류] 반영 실패 한 줄' -f $failRow.Name) `
            ('{0} · {1} · {2} · {3} · {4}' -f (Get-ResultText $result), $script:stepCalls, $script:updateCalls,
                (('{0} {1}' -f (Get-JournalState), (Get-ProgressText)) -ceq $stateBefore), (Format-LogLines)) `
            ('1:False · 0 · 0 · True · ' + ($ADVANCE_FAIL_FORMAT -f $failRow.Word))
    }

    # A12 알 수 없는 호출 - start · finish 밖의 값(대소문자 다름 포함)은 거짓 · journal 접근 0
    Use-CaseFolder 'a12_bad_caller'
    Write-TestConfig
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
    $stateBefore = Get-JournalState
    Reset-Observation
    $results = foreach ($caller in @('resume', '', 'Finish')) { Get-ResultText @(Invoke-AbyssPendingAdvance -Caller $caller) }
    Assert-Case 'A12 호출 resume · 빈 값 · Finish → 거짓 3 · 읽기 0 · 파일 그대로 · [오류] 줄 3' `
        ('{0} · {1} · {2} · {3}' -f ($results -join ','), $script:readCalls, ((Get-JournalState) -ceq $stateBefore), (Format-LogLines)) `
        ('1:False,1:False,1:False · 0 · True · ' + ((@('resume', '', 'Finish') | ForEach-Object { $ADVANCE_FAIL_FORMAT -f ("알 수 없는 호출 '{0}'" -f $_) }) -join ' ¶ '))

    # A13 저장소 복구 경고를 남김 - 본 파일 손상 + 직전본 유효(원소 1개) → 읽기가 직전본으로 복구하고 경고를 돌려줌 → 그 원소 반영
    Use-CaseFolder 'a13_recover_warning'
    Write-TestConfig -Lap 1 -Index 0
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1   # seq 1
    Add-TestPending -Lap 1 -Index 1 -Stage $STAGE_A2 -Nonce $NONCE_2   # seq 2 - 직전본 = seq 1(원소 1개)
    [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
    Reset-Observation
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Assert-Case 'A13 본 파일 손상·직전본 유효 → 참 · 복구 경고 1줄(첫 읽기) · 직전본 원소 반영(전진 1) · 대기열 빔' `
        ('{0} · {1} · {2} · {3} · [{4}]' -f (Get-ResultText $result), (Format-LogLines), $script:stepCalls, (Get-ProgressText), (Get-PendingText)) `
        ('1:True · {0} · 1 · 1/1 · []' -f $STORE_RECOVER_WARNING)
}

function Test-CaseAdvanceHeadCheck {
    # A10 지울 때 맨 앞 확인(nonce 검사) - 판단한 뒤 지우기 전에 맨 앞 원소의 nonce 가 바뀌면(같은 단계·같은 만든 시각) 지우지 않고 실패.
    #     맨 앞이 판단한 그 원소일 때만 지운다는 계약(반영 ③)의 nonce 부분입니다 - 확인이 빠지면 판단하지 않은 원소를 지우고 그 nonce 대신
    #     판단한 원소의 nonce 를 applied 에 넣습니다. 갈고리가 실제 저장소로 맨 앞의 nonce 만 바꿉니다(감시를 거치지 않음)
    Use-CaseFolder 'a10_head_swapped'
    New-TwoElementQueue
    $markerBefore = Get-MarkerState
    # 바꿀 mutator 는 여기서 클로저로 만들어 갈고리가 변수로 잡게 합니다 - 갈고리 클로저 안에서 다시 .GetNewClosure() 를 부르면 갈고리가 잡은
    # 값(바꿀 nonce)이 안쪽 클로저로 넘어가지 않습니다(실행 확인: 빈 값으로 바뀜)
    $swapNonce = $NONCE_SWAP
    $swapMutator = { param($journal, $change) (@($journal.pending)[0]).nonce = $swapNonce; $change.Changed = $true }.GetNewClosure()
    $journalPath = $script:abyssJournalPath
    $realUpdate = $script:realUpdateAbyssJournal
    Reset-Observation
    $script:afterStepHook = {
        param($callNumber)
        if ($callNumber -ne 1) { return }
        $swapOutcome = & $realUpdate -Path $journalPath -Mutator $swapMutator
        if ([string]$swapOutcome.Tag -ne 'changed') { throw ('갈고리 저장 실패: ' + [string]$swapOutcome.Tag) }
    }.GetNewClosure()
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Assert-Case 'A10 판단 뒤 맨 앞 nonce 바뀜 → 거짓 · 저장 태그 expect-failed · 대기열 = 바뀐 맨 앞 + 둘째 그대로 · applied 0 · 진행 1/1 · 마커 정리 0 · 마커 그대로 · 마지막 줄' `
        ('{0} · {1} · [{2}] · [{3}] · {4} · {5} · {6} · {7}' -f (Get-ResultText $result), ($script:updateTags -join ','), (Get-PendingText), (Get-AppliedText),
            (Get-ProgressText), $script:markerClears, ((Get-MarkerState) -ceq $markerBefore), [string]@($script:guiLogLines)[-1]) `
        ('1:False · expect-failed · [A1:SWAP:1/0,A2:N2:1/1] · [] · 1/1 · 0 · True · ' + ($ADVANCE_FAIL_FORMAT -f '대기열이 바뀜'))

    # A10′ 맨 앞 확인의 단계·만든 시각 부분 - 같은 판의 원소 둘(재입장 A1 · 완주 A2)이 같은 nonce 일 때, 판단 뒤 지우기 전에 A1 이 사라져 같은 nonce 의
    #     A2 가 맨 앞이 되면 지우지 않고 실패합니다. nonce 만 보면 판단하지 않은 A2 를 지우고 참을 돌려줘 A2 판의 전진(1/1 → 1/2)을 잃고 마커까지
    #     정리합니다. 갈고리가 실제 저장소로 맨 앞 원소를 뺍니다(감시를 거치지 않음). 변이 검증 보강(2026-10-09): A10 은 nonce 만 바꿔 '지우기 확인을
    #     nonce 만으로' 변이가 살아남았음
    Use-CaseFolder 'a10b_same_nonce_head_dropped'
    New-TwoElementQueue -SecondNonce $NONCE_1
    $markerBefore = Get-MarkerState
    $dropHeadMutator = { param($journal, $change) $journal.pending = @(@($journal.pending) | Select-Object -Skip 1); $change.Changed = $true }.GetNewClosure()
    $journalPath = $script:abyssJournalPath
    $realUpdate = $script:realUpdateAbyssJournal
    Reset-Observation
    $script:afterStepHook = {
        param($callNumber)
        if ($callNumber -ne 1) { return }
        $dropOutcome = & $realUpdate -Path $journalPath -Mutator $dropHeadMutator
        if ([string]$dropOutcome.Tag -ne 'changed') { throw ('갈고리 저장 실패: ' + [string]$dropOutcome.Tag) }
    }.GetNewClosure()
    $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
    Assert-Case 'A10′ 판단 뒤 맨 앞이 같은 nonce 의 다른 원소(A2)로 바뀜 → 거짓 · expect-failed · 대기열 = A2 그대로 · applied 0 · 진행 1/1 · 마커 정리 0 · 마커 그대로 · 마지막 줄' `
        ('{0} · {1} · [{2}] · [{3}] · {4} · {5} · {6} · {7}' -f (Get-ResultText $result), ($script:updateTags -join ','), (Get-PendingText), (Get-AppliedText),
            (Get-ProgressText), $script:markerClears, ((Get-MarkerState) -ceq $markerBefore), [string]@($script:guiLogLines)[-1]) `
        ('1:False · expect-failed · [A2:N1:1/1] · [] · 1/1 · 0 · True · ' + ($ADVANCE_FAIL_FORMAT -f '대기열이 바뀜'))
}

# ===== T 대기열 실패 태그 (단계 2.6 구현 리뷰 - 반환값은 그대로, 실패한 저장소 태그를 $script:abyssPendingLastTag 에) =====
function Test-CasePendingTag {
    # T1 큐 기록 - 호출마다 처음에 비우고 저장소 실패 태그만 남김: 앞 호출이 남긴 'locked' + 저장 성공 → 참 · 빈 값 / 잠금 → locked / 교체 실패 → io-failed /
    #    앞 'locked' + 형식 오류 · 저장소 예외 → 거짓 · 빈 값(저장소 태그 없는 실패 - 정지 문구에 안내가 붙지 않음) / 본 파일·직전본 손상 → corrupt
    $outcomes = @()
    Use-CaseFolder 't1_record_tags'
    Write-TestConfig
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
    $owner2 = (Get-TestOwner -Lap 1 -Index 1).Owner
    $recordRows = @(
        @{ N = '성공'; Before = 'locked'; Stage = $STAGE_A2 },
        @{ N = '잠금'; Before = ''; Stage = $STAGE_A2; Hold = 'journal-lock' },
        @{ N = '교체 실패'; Before = ''; Stage = $STAGE_A2; Hold = 'main-read' },
        @{ N = '형식 오류'; Before = 'locked'; Stage = 'post-clear-stop' },
        @{ N = '예외'; Before = 'locked'; Stage = $STAGE_A2; Throw = $true })
    foreach ($recordRow in $recordRows) {
        Reset-Observation
        $script:abyssPendingLastTag = $recordRow.Before
        if ($recordRow.Hold -eq 'journal-lock') { Lock-JournalLockFile }
        if ($recordRow.Hold -eq 'main-read') { Lock-TestFile -Path $script:abyssJournalPath -Share 'Read' }
        $script:updateThrows = [bool]$recordRow.Throw
        try {
            $result = @(Add-AbyssPendingEntry -Stage $recordRow.Stage -Owner $owner2 -Generation $GENERATION -Nonce $NONCE_2)
        } finally {
            $script:updateThrows = $false
            Unlock-TestFiles
        }
        $outcomes += ('{0} {1} [{2}]' -f $recordRow.N, (Get-ResultText $result), $script:abyssPendingLastTag)
    }
    Use-CaseFolder 't1_record_corrupt'
    Write-TestConfig
    [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
    [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JSON)
    $owner2 = (Get-TestOwner -Lap 1 -Index 1).Owner
    Reset-Observation
    $result = @(Add-AbyssPendingEntry -Stage $STAGE_A2 -Owner $owner2 -Generation $GENERATION -Nonce $NONCE_2)
    $outcomes += ('손상 {0} [{1}]' -f (Get-ResultText $result), $script:abyssPendingLastTag)
    Assert-Case 'T1 큐 기록 실패 태그(반환값 그대로): 앞 locked + 성공 → 참·빈 값 / 잠금 → locked / 교체 실패 → io-failed / 앞 locked + 형식 오류 · 예외 → 빈 값 / 손상 → corrupt' `
        ($outcomes -join ' || ') '성공 1:True [] || 잠금 1:False [locked] || 교체 실패 1:False [io-failed] || 형식 오류 1:False [] || 예외 1:False [] || 손상 1:False [corrupt]'

    # T2 큐 반영 - 같은 계약. 태그를 남기는 실패: 읽기 잠금(locked) · 읽기 손상(corrupt) · 읽기 실패(io-failed - 본 파일을 공유 없이 쥠) · 지우기 저장 교체
    #    실패(io-failed - 첫 전진 뒤 본 파일을 읽기만 허용하고 쥠) · 지우기 저장 잠금(locked - 첫 전진 뒤 다른 주체가 잠금) · 맨 앞이 바뀜(expect-failed).
    #    읽기 태그도 남기는 이유: 반영의 '사용 중' 은 대개 원소마다 먼저 하는 잠금 읽기에서 납니다
    $advanceOutcomes = @()
    foreach ($advanceRow in @('read-locked', 'read-corrupt', 'read-io', 'removal-io', 'removal-locked', 'head-swapped')) {
        Use-CaseFolder ('t2_' + $advanceRow)
        New-TwoElementQueue
        $journalToHold = $script:abyssJournalPath
        Reset-Observation
        $script:abyssPendingLastTag = ''
        switch ($advanceRow) {
            'read-locked' { Lock-JournalLockFile }
            'read-corrupt' {
                [IO.File]::WriteAllText($journalToHold, $TRUNCATED_JSON)
                [IO.File]::WriteAllText($journalToHold + '.bak', $TRUNCATED_JSON)
            }
            'read-io' { Lock-TestFile -Path $journalToHold -Share 'None' }
            'removal-io' {
                # 실패한 저장이 돌아오면 쥔 파일을 놓습니다(A7 과 같은 이유 - 실패를 성공으로 넘기는 결함이면 멈추지 않고 드러나게)
                $script:afterStepHook = { param($callNumber) if ($callNumber -eq 1) { Lock-TestFile -Path $journalToHold -Share 'Read' } }.GetNewClosure()
                $script:afterUpdateHook = { param($callNumber) Unlock-TestFiles }
            }
            'removal-locked' {
                $script:afterStepHook = { param($callNumber) if ($callNumber -eq 1) { Lock-JournalLockFile } }
                $script:afterUpdateHook = { param($callNumber) Unlock-TestFiles }
            }
            'head-swapped' {
                # A10 과 같은 갈고리 - 실제 저장소로 맨 앞 원소의 nonce 만 바꿈(바꿀 mutator 는 여기서 클로저로 만들어 갈고리가 변수로 잡게 함)
                $swapNonce = $NONCE_SWAP
                $swapMutator = { param($journal, $change) (@($journal.pending)[0]).nonce = $swapNonce; $change.Changed = $true }.GetNewClosure()
                $realUpdate = $script:realUpdateAbyssJournal
                $script:afterStepHook = {
                    param($callNumber)
                    if ($callNumber -ne 1) { return }
                    $swapOutcome = & $realUpdate -Path $journalToHold -Mutator $swapMutator
                    if ([string]$swapOutcome.Tag -ne 'changed') { throw ('갈고리 저장 실패: ' + [string]$swapOutcome.Tag) }
                }.GetNewClosure()
            }
        }
        try {
            $result = @(Invoke-AbyssPendingAdvance -Caller 'finish')
        } finally {
            Unlock-TestFiles
        }
        $advanceOutcomes += ('{0} {1} [{2}]' -f $advanceRow, (Get-ResultText $result), $script:abyssPendingLastTag)
    }
    Assert-Case 'T2 큐 반영 실패 태그(반환값 그대로): 읽기 locked · corrupt · io-failed / 지우기 저장 io-failed · locked / 맨 앞 바뀜 expect-failed' `
        ($advanceOutcomes -join ' || ') `
        'read-locked 1:False [locked] || read-corrupt 1:False [corrupt] || read-io 1:False [io-failed] || removal-io 1:False [io-failed] || removal-locked 1:False [locked] || head-swapped 1:False [expect-failed]'

    # T2′ 저장소 태그 없는 실패·성공은 빈 값 - 앞 호출이 남긴 'locked' 를 지움: 성공(대기열 비움) · 진행 저장 실패(config 를 읽기만 허용하고 쥠) · 진행 위치
    #     없음 · 알 수 없는 호출 · 읽기 예외 → 반환 그대로 · 빈 값
    $emptyOutcomes = @()
    foreach ($emptyRow in @('success', 'step-fails', 'no-context', 'bad-caller', 'read-throws')) {
        Use-CaseFolder ('t2b_' + $emptyRow)
        New-TwoElementQueue
        if ($emptyRow -eq 'no-context') { Write-TestConfig -Lap 1 -Index 0 -Items @() }
        Reset-Observation
        $script:abyssPendingLastTag = 'locked'
        if ($emptyRow -eq 'step-fails') { Lock-TestFile -Path $script:configPath -Share 'Read' }
        $script:readThrows = ($emptyRow -eq 'read-throws')
        $caller = $(if ($emptyRow -eq 'bad-caller') { 'resume' } else { 'finish' })
        try {
            $result = @(Invoke-AbyssPendingAdvance -Caller $caller)
        } finally {
            $script:readThrows = $false
            Unlock-TestFiles
        }
        $emptyOutcomes += ('{0} {1} [{2}]' -f $emptyRow, (Get-ResultText $result), $script:abyssPendingLastTag)
    }
    Assert-Case "T2′ 앞 locked + 성공 · 진행 저장 실패 · 진행 위치 없음 · 알 수 없는 호출 · 읽기 예외 → 반환 그대로 · 빈 값" ($emptyOutcomes -join ' || ') `
        'success 1:True [] || step-fails 1:False [] || no-context 1:False [] || bad-caller 1:False [] || read-throws 1:False []'
}

# ===== P 재입장 실행부·마무리 실행 완주 (단계 2.6 - 설계 v11 R1 3.4·3.7 · 6.3a · dev:990) =====
function Initialize-HandoffCase {
    # 실행부·완주 행 준비 - 새 폴더 · config 진행 1바퀴 0번(세대 $GENERATION) · 재입장 항목 N1(owner i = 1/0 · nextOwner i+1 = 1/1 · reentered · pending) ·
    # 끝난 판 i 의 완료 마커(그 판의 워커가 남김) · 어비스 커스텀 실행 상태(기동 종류 none). 기동·정지 모형의 경로도 이 폴더로
    param([string]$Name)
    Use-CaseFolder $Name
    Write-TestConfig -Lap 1 -Index 0
    $ownerI = (Get-TestOwner -Lap 1 -Index 0).Owner
    $ownerNext = (Get-TestOwner -Lap 1 -Index 1).Owner
    $handoffEntry = New-AbyssJournalEntry -Stage 'reentered'
    $handoffEntry.nonce = $NONCE_1
    $handoffEntry.section = $ABYSS_SECTION
    $handoffEntry.generation = $GENERATION
    $handoffEntry.owner = [pscustomobject]@{ fingerprint = $ownerI.fingerprint; orderKey = $ownerI.orderKey; lap = $ownerI.lap; index = $ownerI.index; item = $ownerI.item }
    $handoffEntry.nextOwner = [pscustomobject]@{ fingerprint = $ownerNext.fingerprint; orderKey = $ownerNext.orderKey; lap = $ownerNext.lap; index = $ownerNext.index; item = $ownerNext.item }
    $handoffEntry.decision = 'retry'
    Write-TestJournal -Entries @($handoffEntry)
    [IO.File]::WriteAllText($script:customAbyssMarkerFile, (ConvertTo-CustomMarkerOwnerJson -Owner $ownerI))
    $script:customMarkerFile = $script:customAbyssMarkerFile   # 이번 실행 = 어비스 커스텀 (시작이 정한 전역 마커)
    $script:honeyLogDir = $script:caseFolder
    $script:workerLog = Join-Path $script:caseFolder 'mabinogi_run_once.log'
    $script:workerRecoveryLog = Join-Path $script:caseFolder 'mabinogi_run_once.recovery.log'
    $script:customActive = $true
    $script:customConfigSection = $ABYSS_SECTION
    $script:customRestart = $false
    $script:customRecoveryPending = $false
    $script:customMarkerIgnore = $false
    $script:customPrevItem = ''
    $script:customErrorStreak = 0
    $script:stopRequested = $false
    $script:completedCycles = 1
    $script:targetCycles = 0
    $script:targetTime = $null
    $script:lastLaunchKind = 'none'
    $script:lastLaunchNonce = ''
    $script:finishOnlyHold = $null
    $script:abyssErrorStreak = 0
    $script:runId = 'run-P'
    $script:running = $true
    $script:lastWorkerDoneReason = ''
    $lblStatus.ForeColor = $null
    Reset-Observation
    return @{ OwnerI = $ownerI; OwnerNext = $ownerNext; PositionNext = (Get-TestOwner -Lap 1 -Index 1).Position }
}

function Invoke-InsideHandoffExitRow {
    # 재입장 실행부 1번(판별 결과 = 재입장 항목 N1 · 진행 전 컨텍스트 = 디스크 i) - config 를 읽기만 허용하고 쥐면 진행 저장이 실패합니다(실제 실패 경로)
    param([switch]$StepFails)
    $finishedContext = Get-CustomCurrentContext -SectionName $ABYSS_SECTION
    $script:contextReads = 0
    if ($StepFails) { Lock-TestFile -Path $script:configPath -Share 'Read' }
    try {
        Invoke-InsideHandoffExit -ExitCode 0 -Handoff @{ Kind = 'inside-handoff'; Nonce = $NONCE_1; Source = 'journal'; Reason = '' } -FinishedContext $finishedContext
    } finally {
        Unlock-TestFiles
    }
}

function Add-FinishWorkerResult {
    # 마무리 실행 워커가 그 판(i+1)을 마친 모양 - 완료 마커(owner i+1)와 cleared 항목(owner i+1)을 남깁니다(워커의 실제 기록 단위는 2.10·⑤ 몫)
    param($OwnerNext)
    [IO.File]::WriteAllText($script:customAbyssMarkerFile, (ConvertTo-CustomMarkerOwnerJson -Owner $OwnerNext))
    $clearedEntry = New-AbyssJournalEntry -Stage 'cleared'
    $clearedEntry.nonce = $NONCE_S
    $clearedEntry.section = $ABYSS_SECTION
    $clearedEntry.generation = $GENERATION
    $clearedEntry.owner = [pscustomobject]@{ fingerprint = $OwnerNext.fingerprint; orderKey = $OwnerNext.orderKey; lap = $OwnerNext.lap; index = $OwnerNext.index; item = $OwnerNext.item }
    $appendMutator = { param($journal, $change) $journal.entries = @(@($journal.entries) + $clearedEntry); $change.Changed = $true }.GetNewClosure()
    $appendResult = & $script:realUpdateAbyssJournal -Path $script:abyssJournalPath -Mutator $appendMutator
    if ([string]$appendResult.Tag -ne 'changed') { throw ('픽스처 cleared 기록 실패: ' + [string]$appendResult.Tag) }
}

function Get-JournalEntryText {
    # 항목 '단계/launchState/적용(1·0)'
    param([string]$Nonce)
    $journal = Read-TestJournal
    $appliedNonces = @(@($journal.applied) | ForEach-Object { [string]$_ })
    foreach ($entry in @($journal.entries)) { if ([string]$entry.nonce -eq $Nonce) { return ('{0}/{1}/{2}' -f $entry.stage, $entry.launchState, [int]($appliedNonces -contains $Nonce)) } }
    return '(없음)'
}

function Test-MarkerRecoveryAtStart {
    # 다음 시작의 마커 게이트가 마무리 복구를 예약하는가 - 시작 게이트가 쓰는 두 함수(마커 소유자 읽기 · 지금 진행과 대조)를 그대로(시작 처리의 배선 자체는 [SG])
    $markerOwner = Read-CustomMarkerOwner
    if ($null -eq $markerOwner) { return $false }
    return [bool](Test-CustomMarkerOwnerMatchesContext -Owner $markerOwner -Context (Get-CustomCurrentContext -SectionName $ABYSS_SECTION))
}

function Test-CaseHandoffExecution {
    # P1 재입장 실행부 · 진행 저장 실패 → 즉시 정지 대신 대기열 inside-handoff(owner = 끝난 판 1/0 · 판별 항목 nonce) + 마무리 실행 기동. 기동 env 는 보류로
    #    (진행 미독 - 컨텍스트 읽기 0): ITEM·POSITION = i+1 · OWNER = i+1 의 version 3(세대) · GENERATION · FINISH_ONLY·LAST_RUN 1 · HANDOFF_NONCE = 판별 항목 ·
    #    RESTART·RECOVERY 빈 값 · MARKER 경로(정리 0 - 완주 직후 재시작의 복구 근거). 진행 1/0 그대로 · 정지 0
    $info = Initialize-HandoffCase 'p1_exec_step_fails'
    $markerBefore = Get-FileDigest $script:customAbyssMarkerFile
    Invoke-InsideHandoffExitRow -StepFails
    $launchEnv = $(if ($script:launches.Count -gt 0) { $script:launches[0] } else { @{} })
    Assert-Case 'P1 진행 저장 실패 → 대기열 A1(1/0 · 판별 nonce) · 진행 1/0 · 기동 1 · 정지 0 · 마커 정리 0 · 마커 그대로 · 기동 종류 finish-only/보류 step-failed' `
        ('{0} · {1} · {2} · {3} · {4} · {5} · {6}/{7}' -f (Get-PendingText), (Get-ProgressText), $script:launches.Count, $script:stops.Count, $script:markerClears,
            ((Get-FileDigest $script:customAbyssMarkerFile) -ceq $markerBefore), $script:lastLaunchKind, $script:finishOnlyHold.Kind) 'A1:N1:1/0 · 1/0 · 1 · 0 · 0 · True · finish-only/step-failed'
    $ownerProbe = Join-Path $script:caseFolder 'owner_probe.marker'
    [IO.File]::WriteAllText($ownerProbe, [string]$launchEnv['HONEYNOGI_CUSTOM_OWNER'])
    $probeOwner = Read-CustomMarkerOwner -Path $ownerProbe
    Assert-Case 'P1 마무리 실행 env: ITEM = i+1 토큰 · POSITION = i+1 · OWNER version 3(index 1 · 세대) · GENERATION · FINISH_ONLY·LAST_RUN 1 · HANDOFF_NONCE = 판별 항목 · RESTART·RECOVERY 빈 값 · MARKER = 어비스 마커 · 진행 읽기 0' `
        ('{0} · {1} · {2} · {3} · {4}|{5} · {6} · [{7}|{8}] · {9} · {10}' -f ($launchEnv['HONEYNOGI_CUSTOM_ITEM'] -ceq [string]$info.OwnerNext.item), $launchEnv['HONEYNOGI_CUSTOM_POSITION'],
            $(if ($null -eq $probeOwner) { '(무효)' } else { '{0}/{1}/{2}' -f $probeOwner.version, $probeOwner.index, $probeOwner.generation }), $launchEnv['HONEYNOGI_CUSTOM_GENERATION'],
            $launchEnv['HONEYNOGI_FINISH_ONLY'], $launchEnv['HONEYNOGI_LAST_RUN'], (Get-NonceLabel ([string]$launchEnv['HONEYNOGI_HANDOFF_NONCE'])), $launchEnv['HONEYNOGI_CUSTOM_RESTART'],
            $launchEnv['HONEYNOGI_CUSTOM_RECOVERY'], ($launchEnv['HONEYNOGI_CUSTOM_MARKER'] -ceq $script:customAbyssMarkerFile), $script:contextReads) `
        ('True · {0} · 3/1/{1} · {1} · 1|1 · N1 · [|] · True · 0' -f $info.PositionNext, $GENERATION)
    Assert-Case 'P1 필수 기록: 재입장 항목 reentered/launched/적용 · 로그에 [경고] 마무리 실행 안내 1줄(진행 저장 실패)' `
        ('{0} · {1}' -f (Get-JournalEntryText $NONCE_1), @($script:guiLogLines | Where-Object { $_ -like '`[경고`] 마무리 실행: 커스텀 진행 기록 저장 실패 - *' }).Count) 'reentered/launched/1 · 1'

    # P2 마무리 실행 완주(코드 0) → finish-only-complete(owner = 보류 Owner i+1) → 대기열 순서 반영 = 전진 총 2(1/0 → 1/2) → 대기열 빔 → 어비스 마커 정리 →
    #    끝 처리 ⓐ 판별 항목 done ⓑ 보류 Owner 의 cleared 소비 → 보류 사유 오류 정지 (설계 R1 6.3a · 명세 리뷰 3 확인 라운드 P1)
    Add-FinishWorkerResult -OwnerNext $info.OwnerNext
    Reset-Observation
    Complete-FinishOnlyCycle -ExitCode 0
    Assert-Case 'P2 완주 → 진행 1/2(전진 총 2) · 대기열 빔 · 마커 정리 1(어비스 마커 삭제) · N1 done·적용 · 완주 cleared(NS) 소비 · 정지 = 진행 저장 실패(오류)' `
        ('{0} · [{1}] · {2}/{3} · {4} · {5} · {6}' -f (Get-ProgressText), (Get-PendingText), $script:markerClears, [IO.File]::Exists($script:customAbyssMarkerFile), (Get-JournalEntryText $NONCE_1),
            (Get-JournalEntryText $NONCE_S), ($script:stops -join ' / ')) '1/2 · [] · 1/False · reentered/done/1 · cleared/pending/1 · 커스텀 진행 기록 저장 실패|True'

    # P3 완주 직후 GUI 재시작(완주 처리 전에 꺼짐) → 다음 시작: 대기열 반영(-Caller start - 마커는 지우지 않음) 1/0 → 1/1 → 마커(owner = nextOwner i+1)가
    #    지금 진행과 맞아 마무리 복구 예약 → 복구 워커 코드 0 의 전진 → 1/2 (전진 총 2 - dev:990)
    $info = Initialize-HandoffCase 'p3_restart_after_finish'
    Invoke-InsideHandoffExitRow -StepFails
    Add-FinishWorkerResult -OwnerNext $info.OwnerNext
    Reset-Observation
    $advanced = @(Invoke-AbyssPendingAdvance -Caller 'start')
    $afterStart = '{0} · [{1}] · {2}' -f (Get-ProgressText), (Get-PendingText), [IO.File]::Exists($script:customAbyssMarkerFile)
    $recovery = Test-MarkerRecoveryAtStart
    $null = Step-CustomProgress -SectionName $ABYSS_SECTION
    Assert-Case 'P3 완주 직후 재시작 → 시작 반영 참 · 1/1 · 대기열 빔 · 마커 남음 → 마무리 복구 예약 참 → 복구 판 전진 → 1/2 (전진 총 2)' `
        ('{0} · {1} · {2} → {3}' -f (Get-ResultText $advanced), $afterStart, $recovery, (Get-ProgressText)) '1:True · 1/1 · [] · True · True → 1/2'

    # P4 저장 경계 재시작 주입 - 대기열 A1 저장 직후에 끊김(필수 기록 전. 저장 뒤 예외는 대기열 기록 함수가 잡아 실패로 돌려주고 실행부는 정지만 남김 =
    #    프로세스 종료와 같은 디스크 상태) → 다음 시작: 반영 1/0 → 1/1(N1 적용) → 마커(끝난 판 i)는 진행과 맞지 않아 복구 아님 → 다음 기동의 후보 = 재입장
    #    항목(next - 그 판 i+1 을 이어받음) → 그 판 완료 전진 → 1/2 (전진 총 2 · 이중 전진 0)
    $info = Initialize-HandoffCase 'p4_restart_after_a1'
    $script:afterUpdateHook = { param($callNumber) if ($callNumber -eq 1) { throw $CRASH_MESSAGE } }
    Invoke-InsideHandoffExitRow -StepFails
    $crashState = '{0} · [{1}] · {2} · {3} · {4}' -f (Get-ProgressText), (Get-PendingText), (Get-JournalEntryText $NONCE_1), $script:launches.Count, (@($script:stops) -join '')
    Reset-Observation
    $advanced = @(Invoke-AbyssPendingAdvance -Caller 'start')
    $recovery = Test-MarkerRecoveryAtStart
    $resolved = Resolve-HandoffEnvForContext -Context (Get-CustomCanonicalOwner -Context (Get-CustomCurrentContext -SectionName $ABYSS_SECTION))
    $null = Step-CustomProgress -SectionName $ABYSS_SECTION
    Assert-Case 'P4 A1 뒤 끊김 → (1/0 · 대기열 A1 · 항목 미기록 · 기동 0 · 대기열 기록 실패 정지 + 꼬리) → 시작 반영 참 → 복구 아님 → 다음 기동 후보 next N1 → 그 판 전진 → 1/2' `
        ('{0} → {1} · {2} · {3}/{4}/{5} → {6}' -f $crashState, (Get-ResultText $advanced), $recovery, $resolved.Status, $resolved.Kind, (Get-NonceLabel ([string]$resolved.Nonce)), (Get-ProgressText)) `
        ("1/0 · [A1:N1:1/0] · reentered/pending/0 · 0 · 커스텀 진행 기록·대기열 저장 실패 - 중복 실행 방지를 위해 정지 (캐릭터가 '다시 하기'로 들어간 던전 안일 수 있음 - 입장 키 미전송)|True → 1:True · False · ok/next/N1 → 1/2")

    # P5 저장 경계 재시작 주입 - 완주의 finish-only-complete 저장 직후에 끊김(반영 전 - 완주 처리는 기록 실패 정지만 남김) → 다음 시작: 대기열 A1·A2 순서
    #    반영 → 1/2 · 마커(i+1)는 진행과 맞지 않아 복구 아님(다시 돌지 않음) - 전진 총 2
    $info = Initialize-HandoffCase 'p5_restart_after_a2'
    Invoke-InsideHandoffExitRow -StepFails
    Add-FinishWorkerResult -OwnerNext $info.OwnerNext
    Reset-Observation
    $script:afterUpdateHook = { param($callNumber) if ($callNumber -eq 1) { throw $CRASH_MESSAGE } }
    Complete-FinishOnlyCycle -ExitCode 0
    $crashState = '{0} · [{1}] · {2}' -f (Get-ProgressText), (Get-PendingText), (@($script:stops) -join '')
    Reset-Observation
    $advanced = @(Invoke-AbyssPendingAdvance -Caller 'start')
    Assert-Case 'P5 A2 뒤 끊김 → (1/0 · 대기열 A1·A2 · 완료 기록 저장 실패 정지) → 시작 반영 참 → 1/2 · 대기열 빔 · 마커(i+1) 복구 아님' `
        ('{0} → {1} · {2} · [{3}] · {4}' -f $crashState, (Get-ResultText $advanced), (Get-ProgressText), (Get-PendingText), (Test-MarkerRecoveryAtStart)) `
        '1/0 · [A1:N1:1/0,A2:N1:1/1] · 마무리 실행 완료 기록 저장 실패 - 대기열·마커를 보존하고 정지|True → 1:True · 1/2 · [] · False'
}

function Test-CaseHandoffQueueGuide {
    # P6 재입장 실행부 · 진행 저장 실패 + 대기열 A1 '사용 중'(다른 기록 주체가 잠금을 쥠) → 정지 = 대기열 문구 + 잠금 파일 안내 + 재입장 꼬리 · 기동 0 ·
    #    진행 1/0 / 대기열 '손상'(본 파일·직전본) → 대기열 문구 + 꼬리(안내 없음). 안내는 대기열 함수가 남긴 태그로 정하고 꼬리는 늘 맨 끝(단계 2.6 구현 리뷰 P3)
    $p6 = foreach ($failKind in @('locked', 'corrupt')) {
        $null = Initialize-HandoffCase ('p6_queue_' + $failKind)
        if ($failKind -eq 'locked') {
            Lock-JournalLockFile
        } else {
            [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
            [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JSON)
        }
        $null = Invoke-InsideHandoffExitRow -StepFails
        '{0}: {1} · 기동 {2} · 진행 {3}' -f $failKind, (@($script:stops) -join ' / '), $script:launches.Count, (Get-ProgressText)
    }
    Assert-Case "P6 실행부 대기열 A1 '사용 중' → 대기열 문구 + 잠금 파일 안내 + 꼬리 || '손상' → 대기열 문구 + 꼬리 · 둘 다 기동 0 · 진행 1/0" ($p6 -join ' || ') `
        ('locked: {0} {1}{2}|True · 기동 0 · 진행 1/0 || corrupt: {0}{2}|True · 기동 0 · 진행 1/0' -f $QUEUE_STOP, $LOCKED_GUIDE, $IH_TAIL)

    # P7 마무리 실행 완주의 대기열 실패 → 대기열·마커 보존 + 오류 정지: A2 기록 '사용 중'(잠금을 쥠) → 완료 기록 문구 + 잠금 파일 안내 / A2 '손상' → 완료 기록
    #    문구 / A2 저장 직후 다른 주체가 잠금 → 반영의 읽기 '사용 중' → 반영 문구 + 잠금 파일 안내 / A2 저장 직후 손상 → 반영 문구. 넷 다 전진 0(진행 1/0),
    #    손상 파일은 그대로(증거 보존)
    $p7 = foreach ($failKind in @('record-locked', 'record-corrupt', 'advance-locked', 'advance-corrupt')) {
        $info = Initialize-HandoffCase ('p7_' + $failKind)
        $null = Invoke-InsideHandoffExitRow -StepFails
        Add-FinishWorkerResult -OwnerNext $info.OwnerNext
        Reset-Observation
        switch ($failKind) {
            'record-locked' { Lock-JournalLockFile }
            'record-corrupt' {
                [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
                [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JSON)
            }
            'advance-locked' { $script:afterUpdateHook = { param($callNumber) if ($callNumber -eq 1) { Lock-JournalLockFile } } }
            'advance-corrupt' {
                $script:afterUpdateHook = {
                    param($callNumber)
                    if ($callNumber -ne 1) { return }
                    [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
                    [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JSON)
                }
            }
        }
        try {
            $null = Complete-FinishOnlyCycle -ExitCode 0
        } finally {
            Unlock-TestFiles
        }
        $queueText = $(if ($failKind -like '*corrupt') { '손상 보존 {0}' -f ([IO.File]::ReadAllText($script:abyssJournalPath) -ceq $TRUNCATED_JSON) } else { Get-PendingText })
        '{0}: {1} · [{2}] · 진행 {3}' -f $failKind, (@($script:stops) -join ' / '), $queueText, (Get-ProgressText)
    }
    Assert-Case "P7 완주 A2 '사용 중' → 완료 기록 문구 + 안내 || A2 '손상' → 완료 기록 문구 || 반영 읽기 '사용 중' → 반영 문구 + 안내 || 반영 읽기 '손상' → 반영 문구 · 넷 다 진행 1/0" `
        ($p7 -join ' || ') `
        (('record-locked: {0} {2}|True · [A1:N1:1/0] · 진행 1/0 || record-corrupt: {0}|True · [손상 보존 True] · 진행 1/0 || ' +
            'advance-locked: {1} {2}|True · [A1:N1:1/0,A2:N1:1/1] · 진행 1/0 || advance-corrupt: {1}|True · [손상 보존 True] · 진행 1/0') -f $FINISH_RECORD_STOP, $FINISH_ADVANCE_STOP, $LOCKED_GUIDE)
}

# ===== C 코드 1 라우팅 (단계 2.8 - 설계 v10 6.1 'GUI 코드 1 라우팅' · dev:990 · v11 R1 6.3a · 명세 2.8 · 3.4 · 5절 A6·A10) =====
function Initialize-Code1Case {
    # 코드 1 행 준비 - 실행부 행과 같은 폴더·config(1/0 · 세대)·어비스 커스텀 실행 상태·마커(owner i)에서 완료 기록을 항목 1개(N1 · 그 단계 · owner = 끝난 판 i)로 바꿉니다.
    # reentered 는 nextOwner = i+1(워커가 적는 모양). -NoMarker 면 마커를 지웁니다(완료 마커를 못 쓴 판). 재개 기능 플래그는 GUI 원문 값으로
    param([string]$Name, [string]$Stage = 'reentered', [int]$ResumeAttempts = 0, [switch]$NoMarker)
    $info = Initialize-HandoffCase $Name
    $entry = New-AbyssJournalEntry -Stage $Stage
    $entry.nonce = $NONCE_1
    $entry.section = $ABYSS_SECTION
    $entry.generation = $GENERATION
    $entry.owner = [pscustomobject]@{ fingerprint = $info.OwnerI.fingerprint; orderKey = $info.OwnerI.orderKey; lap = $info.OwnerI.lap; index = $info.OwnerI.index; item = $info.OwnerI.item }
    if ($Stage -eq 'reentered') {
        $entry.nextOwner = [pscustomobject]@{ fingerprint = $info.OwnerNext.fingerprint; orderKey = $info.OwnerNext.orderKey; lap = $info.OwnerNext.lap; index = $info.OwnerNext.index; item = $info.OwnerNext.item }
    }
    $entry.decision = $(if ($Stage -eq 'cleared') { 'exit' } else { 'retry' })
    $entry.resumeAttempts = $ResumeAttempts
    Write-TestJournal -Entries @($entry)
    if ($NoMarker) { [IO.File]::Delete($script:customAbyssMarkerFile) }
    $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
    Reset-Observation
    return $info
}

function Invoke-Code1FinishOnlyCheck {
    # 타이머 코드 1 갈래 첫 문장(마무리 실행 판별 if)을 소스 그대로 점소싱 - $exitCode 는 이 함수의 매개변수로 보입니다(규칙 3 · T4-e 3 방식)
    param([int]$exitCode)
    . $code1FinishOnlyBlock
}

function Get-Code1MarkerExists {
    # 타이머 코드 1 갈래의 $markerExists 대입문을 소스 그대로 점소싱해 그 값을 돌려줍니다 - $code1Route 는 이 함수의 매개변수(라우팅 반환값)
    param([string]$code1Route)
    . $markerExistsBlock
    return [bool]$markerExists
}

function Invoke-Code1LegacyBlock {
    # 타이머 코드 1 갈래의 예전 처리 if 를 소스 그대로 점소싱 - $exitCode·$code1Route 는 이 함수의 매개변수(라우팅 반환값)로 보입니다(규칙 3 · T4-e 3 방식)
    param([int]$exitCode, [string]$code1Route)
    . $code1LegacyBlock
}

function Get-JournalResumeAttempts {
    # 완료 기록 항목의 재개 횟수(resumeAttempts) - 항목 없음 -1
    param([string]$Nonce)
    foreach ($entry in @((Read-TestJournal).entries)) { if ([string]$entry.nonce -eq $Nonce) { return [int]$entry.resumeAttempts } }
    return -1
}

function Get-CaseFileState {
    # journal(본 파일·직전본·목록) · 어비스 마커 · config 내용 해시 - '파일 그대로' 단언용
    return ('{0} · {1} · {2}' -f (Get-JournalState), (Get-FileDigest $script:customAbyssMarkerFile), (Get-FileDigest $script:configPath))
}

function Test-CaseCode1Routing {
    # C1 reentered 뒤 코드 1 → 라우팅 'handled' · 계상 1(1 → 2) · 전진 1(1/0 → 1/1) · 다음 판 기동 1(HANDOFF_NONCE = N1 · RECOVERY·RESTART 빈 값 - 마무리 복구 0) · N1 reentered/
    #    launched/적용 · 정지 0 → 그 판(i+1) 완료 전진 → 1/2 (dev:990 'reentered 뒤 코드 1 → 계상 1·Step 1·next-owner(recover 0) → 전진 총 2')
    $null = Initialize-Code1Case 'c1_reentered'
    $route = @(Invoke-Code1JournalRouting -ExitCode 1)
    $launchEnv = $(if ($script:launches.Count -gt 0) { $script:launches[0] } else { @{} })
    $afterRoute = '{0} · {1} · {2} · {3} · {4}|{5}|{6} · {7} · {8}' -f (Get-ResultText $route), $script:completedCycles, (Get-ProgressText), $script:launches.Count,
        (Get-NonceLabel ([string]$launchEnv['HONEYNOGI_HANDOFF_NONCE'])), $launchEnv['HONEYNOGI_CUSTOM_RECOVERY'], $launchEnv['HONEYNOGI_CUSTOM_RESTART'], (Get-JournalEntryText $NONCE_1), $script:stops.Count
    $null = Step-CustomProgress -SectionName $ABYSS_SECTION
    Assert-Case 'C1 reentered 뒤 코드 1 → handled · 계상 2 · 진행 1/1 · 기동 1(HANDOFF_NONCE N1 · RECOVERY·RESTART 빈 값) · N1 reentered/launched/적용 · 정지 0 → 그 판 완료 전진 → 1/2 (전진 총 2)' `
        ('{0} → {1}' -f $afterRoute, (Get-ProgressText)) '1:handled · 2 · 1/1 · 1 · N1|| · reentered/launched/1 · 0 → 1/2'

    # C2 진행 저장 실패(config 를 읽기만 허용하고 쥠) → 대기열 원소 code1-routed(N1 · owner 1/0 - 명세 2.8 ④ · 5절 B7) + 마무리 실행 기동 → 완주(코드 0) → finish-only-complete →
    #    대기열 순서 반영 = 전진 총 2(1/0 → 1/2) · 대기열 빔 · 보류 사유 오류 정지
    $info = Initialize-Code1Case 'c2_code1_routed'
    Lock-TestFile -Path $script:configPath -Share 'Read'
    try { $route = @(Invoke-Code1JournalRouting -ExitCode 1) } finally { Unlock-TestFiles }
    $afterRoute = '{0} · [{1}] · {2} · {3}/{4}' -f (Get-ResultText $route), (Get-PendingText), (Get-ProgressText), $script:lastLaunchKind, $script:finishOnlyHold.Kind
    Add-FinishWorkerResult -OwnerNext $info.OwnerNext
    Reset-Observation
    Complete-FinishOnlyCycle -ExitCode 0
    Assert-Case 'C2 reentered 뒤 코드 1 + 진행 저장 실패 → 대기열 C1(code1-routed · N1 · 1/0) · 마무리 실행 기동 → 완주 → 대기열 순서 반영 1/2(전진 총 2) · 대기열 빔 · 보류 사유 오류 정지' `
        ('{0} → {1} · [{2}] · {3}' -f $afterRoute, (Get-ProgressText), (Get-PendingText), ($script:stops -join ' / ')) '1:handled · [C1:N1:1/0] · 1/0 · finish-only/step-failed → 1/2 · [] · 커스텀 진행 기록 저장 실패|True'

    # C3 retry-clicked / retry-attempt 뒤 코드 1 · 켜진 빌드(진리표 - 명세 3.4 '하니스가 GUI 플래그를 참으로') → handled · 재개 기동 1(RESUME_REENTRY 1 · HANDOFF_NONCE N1 · RESTART·
    #    RECOVERY 빈 값) · 마커 정리 0(-PreserveMarker) → 기동 직후 마커 owner = i 그대로(재개 판이 이어서 소비할 근거 - 시작 게이트 대조 참) · 재개 횟수 1 · 진행 1/0 · 계상 0
    $resumeTexts = foreach ($stage in @('retry-clicked', 'retry-attempt')) {
        $null = Initialize-Code1Case ('c3_resume_' + $stage) -Stage $stage
        $script:abyssPartyRetryEnabled = $true
        try { $route = @(Invoke-Code1JournalRouting -ExitCode 1) } finally { $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG }
        $launchEnv = $(if ($script:launches.Count -gt 0) { $script:launches[0] } else { @{} })
        '{0}: {1} · {2} · {3}|{4} · [{5}|{6}] · {7} · {8} · {9} · {10} · {11} · {12}' -f $stage, (Get-ResultText $route), $script:launches.Count, $launchEnv['HONEYNOGI_RESUME_REENTRY'],
            (Get-NonceLabel ([string]$launchEnv['HONEYNOGI_HANDOFF_NONCE'])), $launchEnv['HONEYNOGI_CUSTOM_RESTART'], $launchEnv['HONEYNOGI_CUSTOM_RECOVERY'], $script:markerClears,
            (Test-MarkerRecoveryAtStart), (Get-JournalResumeAttempts $NONCE_1), (Get-ProgressText), $script:completedCycles, $script:lastLaunchKind
    }
    Assert-Case 'C3 켜진 빌드 · retry-clicked || retry-attempt 뒤 코드 1 → handled · 재개 기동 1(RESUME 1 · N1 · RESTART·RECOVERY 빈 값) · 마커 정리 0 · 마커 owner i 그대로 · 재개 횟수 1 · 진행 1/0 · 계상 0 · resume' `
        ($resumeTexts -join ' || ') 'retry-clicked: 1:handled · 1 · 1|N1 · [|] · 0 · True · 1 · 1/0 · 1 · resume || retry-attempt: 1:handled · 1 · 1|N1 · [|] · 0 · True · 1 · 1/0 · 1 · resume'
    # C4 재개 뒤 두 번째 코드 1(같은 항목 · 재개 횟수 1 - 첫 코드 1 의 결과 그대로 · 켜진 빌드) → handled · 기동 0 · 정지(자동 재개는 한 번뿐) · 파일 그대로(재개 횟수 1 · 마커)
    #    (다음 수동 시작의 S3 재개 수동 1회는 [SG] SG5 - 재개 횟수 1 이어도 수동은 한 번 더)
    $null = Initialize-Code1Case 'c4_resume_again' -Stage 'retry-clicked'
    $script:abyssPartyRetryEnabled = $true
    try {
        $null = @(Invoke-Code1JournalRouting -ExitCode 1)
        Reset-Observation
        $stateBefore = Get-CaseFileState
        $route = @(Invoke-Code1JournalRouting -ExitCode 1)
    } finally {
        $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
    }
    Assert-Case 'C4 재개 뒤 두 번째 코드 1 → handled · 기동 0 · 정지(한 번뿐) · 재개 횟수 1 · 파일 그대로' `
        ('{0} · {1} · {2} · {3} · {4}' -f (Get-ResultText $route), $script:launches.Count, ($script:stops -join ' / '), (Get-JournalResumeAttempts $NONCE_1), ((Get-CaseFileState) -ceq $stateBefore)) `
        ('1:handled · 0 · {0}|True · 1 · True' -f $C1_RESUMED_AGAIN)
    # C5 이 빌드(재개 기능 꺼짐 - GUI 원문 값) + retry-clicked + 코드 1 → handled · 기동 0 · 정지(꺼짐) · journal·마커·config 그대로 (명세 3.4 '플래그 off + retry-* + 코드 1 → 기동 0·
    #    정지·보존') || C6 켜진 빌드 + 안전 중지 → handled · 기동 0 · [안내] 1줄 · '안전 중지' 정지 · 파일 그대로 (dev:888)
    $null = Initialize-Code1Case 'c5_retry_off' -Stage 'retry-clicked'
    $stateBefore = Get-CaseFileState
    $route = @(Invoke-Code1JournalRouting -ExitCode 1)
    $offText = '{0} · {1} · {2} · {3}' -f (Get-ResultText $route), $script:launches.Count, ($script:stops -join ' / '), ((Get-CaseFileState) -ceq $stateBefore)
    $null = Initialize-Code1Case 'c6_retry_safe_stop' -Stage 'retry-clicked'
    $script:stopRequested = $true
    $script:abyssPartyRetryEnabled = $true
    $stateBefore = Get-CaseFileState
    try { $route = @(Invoke-Code1JournalRouting -ExitCode 1) } finally { $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG }
    $safeText = '{0} · {1} · {2} · {3} · {4}' -f (Get-ResultText $route), $script:launches.Count, (Format-LogLines), ($script:stops -join ' / '), ((Get-CaseFileState) -ceq $stateBefore)
    Assert-Case ('C5 재개 기능 꺼짐(GUI 원문 값 {0}) + retry-clicked → handled · 기동 0 · 정지(꺼짐) · 파일 그대로 || C6 켜진 빌드 + 안전 중지 → handled · 기동 0 · [안내] · 안전 중지 · 파일 그대로' -f $GUI_RETRY_FLAG) `
        ('{0} || {1}' -f $offText, $safeText) ('1:handled · 0 · {0}|True · True || 1:handled · 0 · {1} · 안전 중지|False · True' -f $C1_RETRY_OFF, $C1_SAFE_NOTICE)

    # C7 마무리 실행 기동(H32b 커스텀 - 재입장 실행부의 진행 저장 실패 → 대기열 A1 + 마무리 실행)의 코드 1 → 타이머 코드 1 갈래 첫 문장(AST 로 잘라 점소싱)이 오류 정지 · 재시작 0 ·
    #    대기열·마커·launched 그대로 → 다음 수동 시작: 대기열 반영(시작 게이트 S0 가 부르는 함수 - 시작 처리 그대로 잇는 행은 [SG] SG13) 1/0 → 1/1 → 후보 고르기 =
    #    next/N1(같은 nonce 를 이어받음 - 재전송 0)
    #    (설계 R1 6.3a H32b · dev:892)
    $null = Initialize-HandoffCase 'c7_finish_code1_custom'
    Invoke-InsideHandoffExitRow -StepFails
    $kindBefore = [string]$script:lastLaunchKind
    Reset-Observation
    $markerBefore = Get-FileDigest $script:customAbyssMarkerFile
    $null = Invoke-Code1FinishOnlyCheck -exitCode 1
    $afterStop = '{0} · {1} · [{2}] · {3} · {4} · {5}' -f ($script:stops -join ' / '), $script:launches.Count, (Get-PendingText), (Get-JournalEntryText $NONCE_1),
        ((Get-FileDigest $script:customAbyssMarkerFile) -ceq $markerBefore), (Get-ProgressText)
    Reset-Observation
    $advanced = @(Invoke-AbyssPendingAdvance -Caller 'start')
    $resolved = Resolve-HandoffEnvForContext -Context (Get-CustomCanonicalOwner -Context (Get-CustomCurrentContext -SectionName $ABYSS_SECTION))
    Assert-Case 'C7 커스텀 마무리 실행(진행 저장 실패 보류)의 코드 1 → 오류 정지 · 재시작 0 · 대기열 A1 · N1 launched · 마커 그대로 · 1/0 → 다음 시작 반영 1/1 → 후보 next/N1(같은 nonce)' `
        ('{0} → {1} → {2} · {3} · {4}/{5}/{6}' -f $kindBefore, $afterStop, (Get-ResultText $advanced), (Get-ProgressText), $resolved.Status, $resolved.Kind, (Get-NonceLabel ([string]$resolved.Nonce))) `
        ('finish-only → {0}|True · 0 · [A1:N1:1/0] · reentered/launched/1 · True · 1/0 → 1:True · 1/1 · ok/next/N1' -f ($C1_FINISH_FORMAT -f 1))
    # C8 마무리 실행 기동(H32c 비커스텀 - 보류 안전 중지)의 코드 1 → 같은 오류 정지 · 재시작 0 · N1 launched · journal 그대로 → 다음 수동 시작은 새 실행 id → 후보 없음(Role none - 설계
    #    v10 6.1 [V4-P3-3] 수용 창을 고정, 'B 재전송 0' 은 단언하지 않음 - 설계 R1 11절 리뷰 1차 P1)
    Use-CaseFolder 'c8_finish_code1_plain'
    $plainEntry = New-AbyssJournalEntry -Stage 'reentered'
    $plainEntry.nonce = $NONCE_1
    $plainEntry.runId = 'run-P'
    $plainEntry.owner = [pscustomobject]@{ runId = 'run-P' }
    $plainEntry.nextOwner = [pscustomobject]@{ runId = 'run-P' }
    $plainEntry.launchState = 'launched'
    Write-TestJournal -Entries @($plainEntry) -Applied @($NONCE_1)
    $script:customActive = $false
    $script:runId = 'run-P'
    $script:lastLaunchKind = 'finish-only'
    $script:lastLaunchNonce = $NONCE_1
    $script:finishOnlyHold = @{ Kind = 'safe-stop'; Reason = '안전 중지'; IsError = $false; Owner = @{ runId = 'run-P' }; Position = ''; Snapshot = $null }
    $script:running = $true
    Reset-Observation
    $journalBefore = Get-JournalState
    $null = Invoke-Code1FinishOnlyCheck -exitCode 1
    $afterStop = '{0} · {1} · {2} · {3}' -f ($script:stops -join ' / '), $script:launches.Count, (Get-JournalEntryText $NONCE_1), ((Get-JournalState) -ceq $journalBefore)
    $resolved = Resolve-HandoffEnvForContext -Context @{ runId = 'run-new' }
    Assert-Case 'C8 비커스텀 마무리 실행(보류 안전 중지)의 코드 1 → 오류 정지 · 재시작 0 · N1 launched · journal 그대로 → 새 실행 id 의 다음 시작 → 후보 없음(none)' `
        ('{0} → {1}/{2}' -f $afterStop, $resolved.Status, $resolved.Kind) ('{0}|True · 0 · reentered/launched/1 · True → none/none' -f ($C1_FINISH_FORMAT -f 1))

    # C9 명세 5절 A10 · 완료 마커 없음 + 이 판(i)의 미적용 cleared + 코드 1 → 라우팅 'legacy-cleared'(journal 그대로 - 코드 1 은 소비 0, 명세 5절 A6ⓐ · 기동·정지 0) → 타이머의
    #    $markerExists 대입문(AST 로 잘라 점소싱)이 참 → Get-CustomErrorAction 'recover'(마무리 복구 - 같은 항목 재입장 0) || 대조: 마커 없음 + 기록 없음 → 'legacy' → 대입 거짓 → 'retry'
    $null = Initialize-Code1Case 'c9_a10_cleared' -Stage 'cleared' -NoMarker
    $journalBefore = Get-JournalState
    $route = @(Invoke-Code1JournalRouting -ExitCode 1)
    $routeText = '{0} · {1} · {2} · {3}' -f (Get-ResultText $route), ((Get-JournalState) -ceq $journalBefore), $script:launches.Count, $script:stops.Count
    $markerExists = Get-Code1MarkerExists -code1Route ([string]$route[0])
    $action = Get-CustomErrorAction -MarkerExists $markerExists -ErrorStreak 0
    $null = Initialize-Code1Case 'c9_a10_none' -Stage 'cleared' -NoMarker
    Write-TestJournal -Entries @()
    $routeNone = @(Invoke-Code1JournalRouting -ExitCode 1)
    $markerExistsNone = Get-Code1MarkerExists -code1Route ([string]$routeNone[0])
    Assert-Case 'C9 A10 마커 없음 + 미적용 cleared(i) + 코드 1 → legacy-cleared · journal 그대로 · 기동·정지 0 → $markerExists 참 → recover || 기록 없음 → legacy → 거짓 → retry' `
        ('{0} · {1} · {2} || {3} · {4} · {5}' -f $routeText, $markerExists, $action, (Get-ResultText $routeNone), $markerExistsNone, (Get-CustomErrorAction -MarkerExists $markerExistsNone -ErrorStreak 0)) `
        '1:legacy-cleared · True · 0 · 0 · True · recover || 1:legacy · False · retry'

    # C10 단계 2.7·2.8 구현 리뷰 P2 · 같은 nonce → 다음 수동 시작이 이어받음: 켜진 빌드 · 재입장 요청(N1) 뒤 코드 1 → 재개 기동(이번 기동 = resume/N1) → 그 재개 판도 코드 1 →
    #     정지(한 번뿐) · 이번 기동 nonce = 라우팅한 N1 이라 닫지 않음(그 정지의 저장 0 · N1 retry-clicked/launched) → 다음 수동 시작(실제 S0·S3·첫 기동 · 켜진 빌드) → S3 재개
    #     수동 1회 → 첫 기동 resume:N1 1번 · 재개 횟수 2 (dev:889 '다음 수동 시작은 resume 을 수동 1회 더')
    $null = Initialize-Code1Case 'c10_same_nonce_next_start' -Stage 'retry-clicked'
    $script:abyssPartyRetryEnabled = $true
    try {
        $null = @(Invoke-Code1JournalRouting -ExitCode 1)
        $launchBefore = '{0}/{1}' -f $script:lastLaunchKind, (Get-NonceLabel ([string]$script:lastLaunchNonce))
        Reset-Observation
        $route = @(Invoke-Code1JournalRouting -ExitCode 1)
        $stopText = '{0} · {1} · {2} · 저장 {3} · {4}' -f $launchBefore, (Get-ResultText $route), ($script:stops -join ' / '), $script:updateCalls, (Get-JournalEntryText $NONCE_1)
        Initialize-StartCase -KeepFolder
        $script:abyssPartyRetryEnabled = $true
        $outcome = Invoke-ManualStart
    } finally {
        $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
    }
    Assert-Case 'C10 같은 nonce · 재개 판의 코드 1 → 정지(한 번뿐) · 저장 0 · N1 launched 그대로 → 다음 수동 시작(켜진 빌드) → 재개 수동 1회 · 첫 기동 resume:N1 · 재개 횟수 2' `
        ('{0} → {1} · {2} · 재개 횟수 {3}' -f $stopText, $outcome, (Get-LaunchText), (Get-JournalResumeAttempts $NONCE_1)) `
        ('resume/N1 · 1:handled · {0}|True · 저장 0 · retry-clicked/launched/0 → launched · 기동 resume:N1 1번 · RESTART [] · 재입장 0 · 재개 횟수 2' -f $C1_RESUMED_AGAIN)

    # C11 단계 2.7·2.8 구현 리뷰 P2 · 다른 nonce → 그것만 닫음 · 다음 시작의 이어받기는 그대로: 진행 i = 2번 칸(1/1) · 앞 판(1/0)의 재입장 N2(nextOwner = i · 적용 · launched - 이번
    #     기동이 next 로 받은 항목) · 이 판의 재입장 요청 N1(owner i) · 마커 i. (가) 이 빌드(재개 기능 꺼짐) → 정지(꺼짐) · N2 done · N1 그대로 · 저장 1 → 다음 수동 시작 → S3 거부
    #     (재개 꺼짐 안내 - SG5 와 같음) · 기동 0 || (나) 켜진 빌드 + 안전 중지 → [안내] → N2 done → 안전 중지 → 다음 수동 시작(켜진 빌드) → 재개 수동 1회 · 첫 기동 resume:N1 2번 ·
    #     재개 횟수 1
    $c11Texts = foreach ($c11Case in @(@{ N = '꺼짐'; RetryOn = $false; SafeStop = $false }, @{ N = '켜짐 + 안전 중지'; RetryOn = $true; SafeStop = $true })) {
        Initialize-StartCase ('c11_other_nonce_' + [int]$c11Case.RetryOn)
        Write-TestConfig -Lap 1 -Index 1
        Write-TestJournal -Entries @((New-StartEntry -Stage 'reentered' -Nonce $NONCE_2 -Lap 1 -Index 0 -LaunchState 'launched' -Next),
            (New-StartEntry -Stage 'retry-clicked' -Nonce $NONCE_1 -Lap 1 -Index 1)) -Applied @($NONCE_2)
        Write-TestMarkers -Lap 1 -Index 1
        $script:lastLaunchKind = 'next'
        $script:lastLaunchNonce = $NONCE_2
        $script:stopRequested = [bool]$c11Case.SafeStop
        Reset-Observation
        $script:abyssPartyRetryEnabled = [bool]$c11Case.RetryOn
        try {
            $route = @(Invoke-Code1JournalRouting -ExitCode 1)
            $routeText = '{0} · [{1}] · {2} · 저장 {3} · {4} · {5}' -f (Get-ResultText $route), (Format-LogLines), ($script:stops -join ' / '), $script:updateCalls,
                (Get-JournalEntryText $NONCE_2), (Get-JournalEntryText $NONCE_1)
            Initialize-StartCase -KeepFolder
            $script:abyssPartyRetryEnabled = [bool]$c11Case.RetryOn
            $outcome = Invoke-ManualStart
        } finally {
            $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
        }
        '{0}: {1} → {2} · {3} · {4} · 재개 횟수 {5}' -f $c11Case.N, $routeText, $outcome, (Format-GateLogLines), (Get-LaunchText), (Get-JournalResumeAttempts $NONCE_1)
    }
    Assert-Case ('C11 다른 nonce(next N2) · 꺼짐(GUI 원문 값 {0}) → 정지 · N2 done · N1 그대로 · 저장 1 → 다음 시작 S3 거부 || 켜짐 + 안전 중지 → N2 done → 다음 시작 재개 resume:N1 2번' -f $GUI_RETRY_FLAG) `
        ($c11Texts -join ' || ') `
        (('꺼짐: 1:handled · [] · {0}|True · 저장 1 · reentered/done/1 · retry-clicked/pending/0 → refused@S3 · {1} · 기동 0 · 재개 횟수 0 || ' +
            '켜짐 + 안전 중지: 1:handled · [{2}] · 안전 중지|False · 저장 1 · reentered/done/1 · retry-clicked/pending/0 → launched · {3} · 기동 resume:N1 2번 · RESTART [] · 재입장 0 · 재개 횟수 1') -f
            $C1_RETRY_OFF, $SG_REFUSE_RETRY_OFF, $C1_SAFE_NOTICE, $SG_RESUME_NOTICE)
}

# ===== C 코드 1 예전 처리(recover/retry)의 안전 중지 - 이번 기동 nonce (recover 닫음 · retry 열어 둠) (단계 2.7·2.8 구현 리뷰 확인 라운드 · 설계 v10 6.1 dev:883·891 · 명세 2.8 ③) =====
function Invoke-LegacySafeStopRow {
    # C12·C13 한 칸 - 진행 i = 2번 칸(1/1) · 앞 판(1/0)의 재입장 N2(nextOwner = i · 적용 · launched - 이번 기동이 next 로 받은 항목) + (선택) 이 판의 미적용 클리어 기록 N1
    # (owner i) · (선택) 완료 마커(owner i)에서 안전 중지 + 코드 1 → 실제 라우팅 → 타이머 예전 처리(AST 로 잘라 점소싱). -LaunchNonce 빈 값 = 넘긴 nonce 없음(기동 종류 none).
    # -LockAfterRead = 라우팅의 읽기 뒤 다른 기록 주체가 잠금(닫기 저장이 실제 '사용 중' 을 만남 - 잠금은 행 끝에 풂).
    # 반환 = '라우팅 반환 · 복구 대기 · [로그] · 정지 · 읽기/저장 · N2 · N1 · journal 그대로 · 기동 수'
    param([string]$Name, [switch]$Cleared, [switch]$Marker, [string]$LaunchNonce = $NONCE_2, [switch]$LockAfterRead)
    Initialize-StartCase $Name
    Write-TestConfig -Lap 1 -Index 1
    $entries = @(New-StartEntry -Stage 'reentered' -Nonce $NONCE_2 -Lap 1 -Index 0 -LaunchState 'launched' -Next)
    if ($Cleared) { $entries += (New-StartEntry -Stage 'cleared' -Nonce $NONCE_1 -Lap 1 -Index 1) }
    Write-TestJournal -Entries $entries -Applied @($NONCE_2)
    if ($Marker) { Write-TestMarkers -Lap 1 -Index 1 }
    $script:lastLaunchKind = $(if ($LaunchNonce) { 'next' } else { 'none' })
    $script:lastLaunchNonce = $LaunchNonce
    $script:stopRequested = $true
    Reset-Observation
    if ($LockAfterRead) { $script:afterReadHook = { param($readNumber) if ($readNumber -eq 1) { Lock-JournalLockFile } } }
    $journalBefore = Get-JournalState
    try {
        $route = @(Invoke-Code1JournalRouting -ExitCode 1)
        $null = Invoke-Code1LegacyBlock -exitCode 1 -code1Route ([string]$route[0])
    } finally {
        Unlock-TestFiles
        $script:afterReadHook = $null
    }
    return ('{0} · 복구 대기 {1} · [{2}] · {3} · 읽기 {4}/저장 {5} · N2 {6} · N1 {7} · journal 그대로 {8} · 기동 {9}' -f (Get-ResultText $route), $script:customRecoveryPending,
        (Format-LogLines), ($script:stops -join ' / '), $script:readCalls, $script:updateCalls, (Get-JournalEntryText $NONCE_2), (Get-JournalEntryText $NONCE_1),
        [int]((Get-JournalState) -ceq $journalBefore), $script:launches.Count)
}

function Test-CaseCode1LegacySafeStop {
    $closeLocked = '[경고] 이번 기동의 완료 표시를 남기지 못했습니다(파일 사용 중) - 정지는 그대로 합니다'   # 닫기 실패 한 줄(구현 글자 - ⑯ NC6·NC9 와 같음)
    # C12 예전 처리 recover 갈래(마무리 복구)의 안전 중지 → 이번 기동 nonce(next N2) done → 다음 시작의 복구 근거는 그대로(코드 1 은 소비하지 않음 - 명세 5절 A6ⓐ):
    #     (가) 이 판의 미적용 클리어 기록 N1 · 마커 없음 → 'legacy-cleared' → recover(복구 대기 참) → 로그 0 · '안전 중지' 1번 · 읽기 1/저장 1 · N2 done · N1 미적용 그대로 · 기동 0
    #          → 다음 수동 시작(실제 S0·S3·마커 게이트·첫 기동) → S3 의 N1 마무리 복구 → 첫 기동 recover 2번(재입장 0)
    #     (나) 완료 마커(owner i)만 → 'legacy' → 마커 유효 → recover → N2 done → 다음 수동 시작 → 마커 게이트의 마무리 복구 → recover 2번(재입장 0)
    #     (다) 넘긴 nonce 없음(N1 있음) → 닫기의 journal 접근 0(저장 0) · journal 그대로 · '안전 중지' 1번
    #     (라) 닫기 실패 - 라우팅 읽기 뒤 다른 기록 주체가 잠금(실제 '사용 중') → [경고] 1줄 → '안전 중지' 1번 · N2 launched 그대로 · journal 그대로
    $c12Texts = @()
    foreach ($c12Case in @(@{ N = '클리어 기록'; Cleared = $true; Marker = $false }, @{ N = '마커'; Cleared = $false; Marker = $true })) {
        $stopText = Invoke-LegacySafeStopRow ('c12_recover_' + [int]$c12Case.Marker) -Cleared:$c12Case.Cleared -Marker:$c12Case.Marker
        Initialize-StartCase -KeepFolder
        $outcome = Invoke-ManualStart
        $c12Texts += ('{0}: {1} → {2} · [{3}] · {4}' -f $c12Case.N, $stopText, $outcome, (Format-GateLogLines), (Get-LaunchText))
    }
    $c12Texts += ('없음: ' + (Invoke-LegacySafeStopRow 'c12_recover_none' -Cleared -LaunchNonce ''))
    $c12Texts += ('사용 중: ' + (Invoke-LegacySafeStopRow 'c12_recover_locked' -Cleared -LockAfterRead))
    Assert-Case 'C12 예전 처리 recover 갈래 안전 중지: 클리어 기록 || 마커 → N2 done · 저장 1 → 다음 시작 마무리 복구 recover 2번 || 넘긴 nonce 없음 → 저장 0 · journal 그대로 || 닫기 실패 → [경고] → 안전 중지 1번 · N2 launched' `
        ($c12Texts -join ' || ') `
        (('클리어 기록: 1:legacy-cleared · 복구 대기 True · [] · 안전 중지|False · 읽기 1/저장 1 · N2 reentered/done/1 · N1 cleared/pending/0 · journal 그대로 0 · 기동 0 → launched · [{0}] · ' +
            '기동 recover 2번 · RESTART [1] · 재입장 0 || ' +
            '마커: 1:legacy · 복구 대기 True · [] · 안전 중지|False · 읽기 1/저장 1 · N2 reentered/done/1 · N1 (없음) · journal 그대로 0 · 기동 0 → launched · [{0}] · 기동 recover 2번 · RESTART [1] · 재입장 0 || ' +
            '없음: 1:legacy-cleared · 복구 대기 True · [] · 안전 중지|False · 읽기 1/저장 0 · N2 reentered/launched/1 · N1 cleared/pending/0 · journal 그대로 1 · 기동 0 || ' +
            '사용 중: 1:legacy-cleared · 복구 대기 True · [{1}] · 안전 중지|False · 읽기 1/저장 1 · N2 reentered/launched/1 · N1 cleared/pending/0 · journal 그대로 1 · 기동 0') -f
            $SG_RECOVER_NOTICE, $closeLocked)
    # C13 예전 처리 retry 갈래(같은 항목 재시작)의 안전 중지 - 이 판의 기록·마커 없음 → 'legacy' → retry(복구 대기 거짓) → 이번 기동 nonce 를 열어 둠(구현 리뷰 확인 -
    #     완료 마커도 미적용 클리어 기록도 없는 판이라 열린 nonce 가 다음 시작의 유일한 이어받기 근거, 설계 v10 6.1 dev:891):
    #     (가) 넘긴 nonce N2 → 닫기 호출 0 = 저장 0 · N2 launched 그대로 · journal 그대로 · '안전 중지' 1번 · 기동 0 → 다음 수동 시작 → 후보 고르기 next 가 열린 N2 를 다시 고름
    #          → 첫 기동 next:N2 2번(던전 안 이어받기 - 재입장 0. 닫았다면 후보 없음 → 새 입장 fresh 2번 · 재입장 1 = 같은 항목을 처음부터 한 번 더)
    #     (나) 넘긴 nonce 없음 → 저장 0 · journal 그대로 · '안전 중지' 1번
    #     닫기 실패 칸은 해당 없음(닫기 호출이 없음 - 저장 0 이 그 근거)
    $c13Texts = @()
    $stopText = Invoke-LegacySafeStopRow 'c13_retry_open'
    Initialize-StartCase -KeepFolder
    $outcome = Invoke-ManualStart
    $c13Texts += ('있음: {0} → {1} · [{2}] · {3}' -f $stopText, $outcome, (Format-GateLogLines), (Get-LaunchText))
    $c13Texts += ('없음: ' + (Invoke-LegacySafeStopRow 'c13_retry_none' -LaunchNonce ''))
    Assert-Case 'C13 예전 처리 retry 갈래 안전 중지(열어 둠): 넘긴 nonce N2 → 저장 0 · N2 launched 그대로 → 다음 시작 next:N2 2번 이어받기 · 재입장 0 || 없음 → 저장 0 · journal 그대로' `
        ($c13Texts -join ' || ') `
        ('있음: 1:legacy · 복구 대기 False · [] · 안전 중지|False · 읽기 1/저장 0 · N2 reentered/launched/1 · N1 (없음) · journal 그대로 1 · 기동 0 → launched · [] · 기동 next:N2 2번 · RESTART [] · 재입장 0 || ' +
            '없음: 1:legacy · 복구 대기 False · [] · 안전 중지|False · 읽기 1/저장 0 · N2 reentered/launched/1 · N1 (없음) · journal 그대로 1 · 기동 0')
}

# ===== SG 시작 게이트 S0·S3 (단계 2.9 - 설계 v10 6.3 dev:941~948 · 6.1 읽기 계약 · 명세 2.9 · 3.4 · 5절 A6·A11·B10) =====
function Initialize-StartCase {
    # 다음 수동 시작 준비 - 새 폴더(-KeepFolder 면 앞 행이 남긴 파일 그대로) · 시작 게이트가 처음부터로 두는 실행 상태(복구·재시작·재개 예약 해제 ·
    # 기동 종류 none) · 전역 마커 = 어비스 마커(시작 처리가 섹션으로 고름) · 기동 모형의 경로도 이 폴더로. 재개 기능 플래그는 GUI 원문 값
    param([string]$Name, [switch]$KeepFolder)
    if ($KeepFolder) { Reset-Observation } else { Use-CaseFolder $Name }
    $script:customMarkerFile = $script:customAbyssMarkerFile
    $script:honeyLogDir = $script:caseFolder
    $script:workerLog = Join-Path $script:caseFolder 'mabinogi_run_once.log'
    $script:workerRecoveryLog = Join-Path $script:caseFolder 'mabinogi_run_once.recovery.log'
    $script:customActive = $true
    $script:customConfigSection = $ABYSS_SECTION
    $script:customErrorStreak = 0
    $script:customPrevItem = ''
    $script:customRestart = $false
    $script:customRecoveryPending = $false
    $script:customMarkerIgnore = $false
    $script:customResumePending = $false
    $script:customResumeNonce = ''
    $script:stopRequested = $false
    $script:completedCycles = 0
    $script:targetCycles = 0
    $script:targetTime = $null
    $script:lastLaunchKind = 'none'
    $script:lastLaunchNonce = ''
    $script:finishOnlyHold = $null
    $script:abyssErrorStreak = 0
    $script:runId = 'run-SG'
    $script:running = $true
    $script:lastWorkerDoneReason = ''
    $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
    $lblStatus.ForeColor = $null
}

function New-StartEntry {
    # 완료 기록 항목 픽스처 - 그 위치(디스크 진행과 같은 계산의 owner)의 어비스 커스텀 항목. -Next 면 nextOwner = 다음 칸(워커가 재입장 때 적는 모양)
    param([string]$Stage, [string]$Nonce, [int]$Lap = 1, [int]$Index = 0, [int]$Generation = $GENERATION, [string]$LaunchState = 'pending', [int]$ResumeAttempts = 0, [switch]$Next)
    $ownerNow = (Get-TestOwner -Lap $Lap -Index $Index -Generation $Generation).Owner
    $entry = New-AbyssJournalEntry -Stage $Stage
    $entry.nonce = $Nonce
    $entry.section = $ABYSS_SECTION
    $entry.generation = $Generation
    $entry.owner = [pscustomobject]@{ fingerprint = $ownerNow.fingerprint; orderKey = $ownerNow.orderKey; lap = $ownerNow.lap; index = $ownerNow.index; item = $ownerNow.item }
    if ($Next) {
        $ownerNext = (Get-TestOwner -Lap $Lap -Index ($Index + 1) -Generation $Generation).Owner
        $entry.nextOwner = [pscustomobject]@{ fingerprint = $ownerNext.fingerprint; orderKey = $ownerNext.orderKey; lap = $ownerNext.lap; index = $ownerNext.index; item = $ownerNext.item }
    }
    $entry.decision = $(if ($Stage -eq 'cleared') { 'exit' } else { 'retry' })
    $entry.launchState = $LaunchState
    $entry.resumeAttempts = $ResumeAttempts
    return $entry
}

function Invoke-StartGateS0 {
    # 시작 게이트의 진행 읽기 → S0 → 진행 다시 읽기 → 지문 검사·완주 판정(S1)을 소스 그대로 점소싱. 그 앞의 설정 읽기 세 문장($crCfg·$crNode·$crItems)은
    # 시작 처리와 같은 식으로 여기서 만듭니다(그 사이의 빈 목록·전환·매칭 거부는 이 행들과 무관)
    $crCfg = Read-Config
    $crNode = $null
    if ($crCfg -and $crCfg.PSObject.Properties[$script:customConfigSection]) { $crNode = $crCfg.$script:customConfigSection }
    $crItems = @()
    if ($crNode -and $crNode.PSObject.Properties['items']) { $crItems = @($crNode.items) }
    . $startS0Block
}

function Invoke-StartGateS3 {
    # 묘비 소비 뒤의 S3 판정·적용 → 마커 게이트(바깥 if)를 소스 그대로 점소싱. -MarkerStaleBlocked = 그 앞 묘비 소비의 결과
    param([bool]$MarkerStaleBlocked = $false)
    $markerStaleBlocked = $MarkerStaleBlocked
    . $startS3Block
}

function Invoke-ManualStart {
    # 다음 수동 시작 한 번 - S0(+S1) → S3 → 마커 게이트 → 첫 기동. 시작 거부(커스텀 실행이 꺼짐)면 그 자리에서 멈춥니다 → 'refused@S0' / 'refused@S3' / 'launched'
    param([bool]$MarkerStaleBlocked = $false)
    Invoke-StartGateS0
    if (-not $script:customActive) { return 'refused@S0' }
    Invoke-StartGateS3 -MarkerStaleBlocked $MarkerStaleBlocked
    if (-not $script:customActive) { return 'refused@S3' }
    . $firstLaunchBlock
    return 'launched'
}

function Format-GateLogLines {
    # 시작 게이트 행의 GUI 로그 - 지문 검사(S1)가 진행을 이어 갈 때의 줄과 기동의 회차 시작 줄(행마다 같은 줄)은 빼고 ' ¶ ' 로 이어 한 줄로
    return ((@($script:guiLogLines) | Where-Object { -not ($_.StartsWith($SG_PROGRESS_RESUME_PREFIX) -or $_.StartsWith('=== ')) } | ForEach-Object { [string]$_ }) -join ' ¶ ')
}

function Get-LaunchText {
    # 첫 기동 방식 - recover(마무리 복구 RECOVERY 1 - 그 항목에 다시 입장하지 않음) / resume:<nonce>(재개 RESUME 1) / next:<nonce>(다음 판 던전 안 이어받기) /
    # fresh(그 항목에 새로 입장 = 재입장) + 기동한 칸(목록 번호) · RESTART. 기동이 없으면 '기동 0'
    if ($script:launches.Count -eq 0) { return '기동 0' }
    $launchEnv = $script:launches[0]
    $mode = 'fresh'
    if ([string]$launchEnv['HONEYNOGI_CUSTOM_RECOVERY'] -eq '1') { $mode = 'recover' }
    elseif ([string]$launchEnv['HONEYNOGI_RESUME_REENTRY'] -eq '1') { $mode = 'resume:' + (Get-NonceLabel ([string]$launchEnv['HONEYNOGI_HANDOFF_NONCE'])) }
    elseif ([string]$launchEnv['HONEYNOGI_HANDOFF_NONCE']) { $mode = 'next:' + (Get-NonceLabel ([string]$launchEnv['HONEYNOGI_HANDOFF_NONCE'])) }
    $itemTokens = @($ITEMS | ForEach-Object { Format-CustomItemToken -Item $_ })
    return ('기동 {0} {1}번 · RESTART [{2}] · 재입장 {3}' -f $mode, ([array]::IndexOf($itemTokens, [string]$launchEnv['HONEYNOGI_CUSTOM_ITEM']) + 1),
        [string]$launchEnv['HONEYNOGI_CUSTOM_RESTART'], [int]($mode -eq 'fresh'))
}

function Test-CaseStartReadFailure {
    # SG1 S0 읽기 실패 - 사용 중(다른 기록 주체가 잠금) · 손상(본 파일·직전본) · 읽기 실패(본 파일을 FileShare.None 으로 쥠) · 읽기 예외 → 시작 거부(그 문구 -
    #     사용 중은 잠금 파일 안내, 손상은 파일 위치 안내) · 대기열 반영 0 · 전진 0 · journal·마커·config 그대로 · 기동 0 (설계 v10 6.1 'S0 locked → 시작 금지')
    $sg1 = foreach ($failKind in @('locked', 'corrupt', 'io-failed', 'exception')) {
        Initialize-StartCase ('sg1_s0_' + $failKind)
        Write-TestConfig -Lap 1 -Index 0
        Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
        Write-TestMarkers -Lap 1 -Index 0
        if ($failKind -eq 'corrupt') {
            [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
            [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JSON)
        }
        $stateBefore = Get-CaseFileState
        Reset-Observation
        switch ($failKind) {
            'locked' { Lock-JournalLockFile }
            'io-failed' { Lock-TestFile -Path $script:abyssJournalPath -Share 'None' }
            'exception' { $script:readThrows = $true }
        }
        try { $outcome = Invoke-ManualStart } finally { Unlock-TestFiles; $script:readThrows = $false }
        '{0}: {1} · {2} · 전진 {3} · 파일 그대로 {4} · {5}' -f $failKind, $outcome, (Format-GateLogLines), $script:stepCalls, ((Get-CaseFileState) -ceq $stateBefore), (Get-LaunchText)
    }
    Assert-Case 'SG1 S0 읽기 실패: 사용 중 · 손상 · 읽기 실패 · 읽기 예외 → S0 에서 시작 거부(그 문구) · 전진 0 · 파일 그대로 · 기동 0' ($sg1 -join ' || ') `
        ((@(('locked', $SG_REFUSE_LOCKED), ('corrupt', $SG_REFUSE_CORRUPT), ('io-failed', $SG_REFUSE_READ), ('exception', ('{0} (예외: {1})' -f $SG_REFUSE_READ, $INJECTED_STORE_EXCEPTION))) |
                ForEach-Object { '{0}: refused@S0 · {1} · 전진 0 · 파일 그대로 True · 기동 0' -f $_[0], $_[1] }) -join ' || ')

    # SG2 S3 읽기 실패 - S0 를 지난 뒤(S3 블록만) 사용 중 · 손상 · 읽기 실패 · 읽기 예외 → 시작 거부 · 마커 게이트 미실행(지금 진행과 맞는 마커가 있어도 복구 예약 0 ·
    #     마커 정리 0) · 파일 그대로 (설계 v10 6.1 'S3 locked → 시작 금지' · 명세 5절 A11 - 변이 'S3 locked 를 없음으로' 는 이 행에서 마커 복구로 갈라짐)
    $sg2 = foreach ($failKind in @('locked', 'corrupt', 'io-failed', 'exception')) {
        Initialize-StartCase ('sg2_s3_' + $failKind)
        Write-TestConfig -Lap 1 -Index 0
        Write-TestJournal -Entries @(New-StartEntry -Stage 'cleared' -Nonce $NONCE_1)
        Write-TestMarkers -Lap 1 -Index 0
        if ($failKind -eq 'corrupt') {
            [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JSON)
            [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JSON)
        }
        $stateBefore = Get-CaseFileState
        Reset-Observation
        switch ($failKind) {
            'locked' { Lock-JournalLockFile }
            'io-failed' { Lock-TestFile -Path $script:abyssJournalPath -Share 'None' }
            'exception' { $script:readThrows = $true }
        }
        try { Invoke-StartGateS3 } finally { Unlock-TestFiles; $script:readThrows = $false }
        '{0}: 실행 {1} · {2} · 복구 예약 {3} · 마커 정리 {4} · 파일 그대로 {5}' -f $failKind, $script:customActive, (Format-LogLines), $script:customRecoveryPending, $script:markerClears,
            ((Get-CaseFileState) -ceq $stateBefore)
    }
    Assert-Case 'SG2 S3 읽기 실패: 사용 중 · 손상 · 읽기 실패 · 읽기 예외 → 시작 거부(S0 와 같은 문구) · 마커 게이트 미실행(복구 예약 0 · 마커 정리 0) · 파일 그대로' ($sg2 -join ' || ') `
        ((@(('locked', $SG_REFUSE_LOCKED), ('corrupt', $SG_REFUSE_CORRUPT), ('io-failed', $SG_REFUSE_READ), ('exception', ('{0} (예외: {1})' -f $SG_REFUSE_READ, $INJECTED_STORE_EXCEPTION))) |
                ForEach-Object { '{0}: 실행 False · {1} · 복구 예약 False · 마커 정리 0 · 파일 그대로 True' -f $_[0], $_[1] }) -join ' || ')

    # SG2′ S3 판정 안의 예외(읽기는 됐고 진행 위치 읽기에서 던짐) → 판정의 catch 가 시작 거부 + [오류] 예외 줄 · 마커 게이트 미실행(맞는 마커가 있어도 복구 예약 0 · 마커
    #      정리 0) · 파일 그대로 (명세 5절 A4 - 예외는 '판단 불가' 라 흘리지 않음. 단계 2.7~2.9 구현 검증 - 생존 변이 '판정 catch 가 없음(none)' 을 가름: 예외 주입점이 없었음)
    Initialize-StartCase 'sg2_s3_decision_exception'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'cleared' -Nonce $NONCE_1)
    Write-TestMarkers -Lap 1 -Index 0
    $stateBefore = Get-CaseFileState
    Reset-Observation
    $script:contextThrows = $true
    # 시작 처리 밖으로 새는 예외도 결과에 적습니다(명세 5절 A4 - 시작 버튼 처리기에는 try 가 없어 예외가 나가면 모달 오류 창): 판정이 예외를 흘리면 마커 게이트의 위치 읽기가
    # 같은 예외를 밖으로 냅니다
    $escapedError = ''
    try { Invoke-StartGateS3 } catch { $escapedError = $_.Exception.Message } finally { $script:contextThrows = $false }
    Assert-Case 'SG2′ S3 판정 예외 → 시작 거부 · [오류] 예외 줄 · 복구 예약 0 · 마커 정리 0 · 파일 그대로 · 새는 예외 0' `
        ('실행 {0} · {1} · 복구 예약 {2} · 마커 정리 {3} · 파일 그대로 {4} · 예외 [{5}]' -f $script:customActive, (Format-LogLines), $script:customRecoveryPending, $script:markerClears,
            ((Get-CaseFileState) -ceq $stateBefore), $escapedError) `
        ('실행 False · {0} · 복구 예약 False · 마커 정리 0 · 파일 그대로 True · 예외 []' -f ($SG_EXCEPTION_FORMAT -f $INJECTED_CONTEXT_EXCEPTION))
}

function Test-CaseStartS3 {
    # SG3 S3 진행 위치를 못 읽음(명세 5절 A11) - (가) 재시도까지 4번 다 $null + 미적용 cleared(i) → 시작 거부(주인 확인 불가 - 마커 게이트와 같은 글자) · 위치
    #     읽기 4(처음 + 재시도 3) · 파일 그대로 / (나) 4번 다 $null + 미적용 '클리어 이상' 없음(적용된 cleared · 비커스텀 항목만) → none → 마커 게이트가 자기 재시도로
    #     판단(다음 읽기는 됨 - 마커 owner i = 진행 i → 마커로 복구 예약) / (다) 앞 2번만 $null + 미적용 cleared(i) → 세 번째 읽기로 복구 예약(재시도가 일시 실패를
    #     흡수 - 변이 '재시도 제거' 는 여기서 시작 거부)
    Initialize-StartCase 'sg3_null_cleared'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'cleared' -Nonce $NONCE_1)
    $stateBefore = Get-CaseFileState
    Reset-Observation
    $script:contextNullReads = 4
    Invoke-StartGateS3
    $nullCleared = '실행 {0} · {1} · 위치 읽기 {2} · 복구 예약 {3} · 파일 그대로 {4}' -f $script:customActive, (Format-LogLines), $script:contextReads, $script:customRecoveryPending,
        ((Get-CaseFileState) -ceq $stateBefore)
    Initialize-StartCase 'sg3_null_none'
    Write-TestConfig -Lap 1 -Index 0
    $plainEntry = New-AbyssJournalEntry -Stage 'cleared'
    $plainEntry.nonce = $NONCE_X
    $plainEntry.owner = [pscustomobject]@{ runId = 'run-old' }
    Write-TestJournal -Entries @((New-StartEntry -Stage 'cleared' -Nonce $NONCE_2), $plainEntry) -Applied @($NONCE_2)
    Write-TestMarkers -Lap 1 -Index 0
    Reset-Observation
    $script:contextNullReads = 4
    Invoke-StartGateS3
    $nullNone = '실행 {0} · {1} · 위치 읽기 {2} · 복구 예약 {3}' -f $script:customActive, (Format-LogLines), $script:contextReads, $script:customRecoveryPending
    Initialize-StartCase 'sg3_retry_cleared'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'cleared' -Nonce $NONCE_1)
    Reset-Observation
    $script:contextNullReads = 2
    Invoke-StartGateS3
    $retryCleared = '실행 {0} · {1} · 위치 읽기 {2} · 복구 예약 {3}' -f $script:customActive, (Format-LogLines), $script:contextReads, $script:customRecoveryPending
    Assert-Case 'SG3 S3 위치 4번 $null + 미적용 cleared → 거부 · 읽기 4 · 파일 그대로 || 4번 $null + 미적용 없음 → 마커 게이트(다음 읽기로 마커 복구) || 2번만 $null → 재시도로 복구 예약' `
        ('{0} || {1} || {2}' -f $nullCleared, $nullNone, $retryCleared) `
        ('실행 False · {0} · 위치 읽기 4 · 복구 예약 False · 파일 그대로 True || 실행 True · {1} · 위치 읽기 5 · 복구 예약 True || 실행 True · {1} · 위치 읽기 3 · 복구 예약 True' -f
            $SG_REFUSE_NO_OWNER, $SG_RECOVER_NOTICE)
    # SG3′ S3 는 지금 owner(5필드 + 진행 세대)의 기록만 봅니다 - 미적용 cleared 가 다른 칸(2번 칸)·옛 세대(진행 초기화 전 1번 칸)뿐이면 none → 마커 게이트(마커 없음 - 건너뜀)
    #      → 첫 기동은 그 항목 새 입장(복구 예약 0 - 남의 판으로 복구하지 않음)
    Initialize-StartCase 'sg3_other_owner'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @((New-StartEntry -Stage 'cleared' -Nonce $NONCE_1 -Index 1), (New-StartEntry -Stage 'cleared' -Nonce $NONCE_2 -Generation ($GENERATION - 1)))
    Reset-Observation
    $otherOutcome = Invoke-ManualStart
    Assert-Case 'SG3′ 미적용 cleared 가 다른 칸 · 옛 세대뿐 → S3 none · 복구 예약 0 · 첫 기동 fresh 1번(지금 칸 새 입장) · 두 기록 그대로 미적용' `
        ('{0} · 복구 안내 {1} · {2} · {3} / {4}' -f $otherOutcome, @($script:guiLogLines | Where-Object { $_ -ceq $SG_RECOVER_NOTICE }).Count, (Get-LaunchText),
            (Get-JournalEntryText $NONCE_1), (Get-JournalEntryText $NONCE_2)) `
        'launched · 복구 안내 0 · 기동 fresh 1번 · RESTART [] · 재입장 1 · cleared/pending/0 / cleared/pending/0'
    # SG3″ S3 위치를 재시도까지 4번 다 못 읽음 + 미적용 기록이 클리어 전(entered)뿐 → 거부가 아님('클리어 이상' 만 셈 - 명세 5절 A11) → none → 마커 게이트(마커 없음 -
    #      건너뜀) · 시작 계속 · 로그 0 (단계 2.7~2.9 구현 검증 - 생존 변이 '주인 없는 기록 셈에 entered 도' 를 가름: SG3 의 none 행에 미적용 entered 가 없었음)
    Initialize-StartCase 'sg3_null_entered'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'entered' -Nonce $NONCE_1)
    Reset-Observation
    $script:contextNullReads = 4
    Invoke-StartGateS3
    Assert-Case 'SG3″ S3 위치 4번 $null + 미적용 entered 뿐 → 시작 계속 · 로그 0 · 위치 읽기 4 · 복구 예약 0' `
        ('실행 {0} · [{1}] · 위치 읽기 {2} · 복구 예약 {3}' -f $script:customActive, (Format-LogLines), $script:contextReads, $script:customRecoveryPending) '실행 True · [] · 위치 읽기 4 · 복구 예약 False'

    # SG4 S3 cleared(i)(재입장 요청 전) → 마무리 복구 예약 + 마커 게이트 건너뜀 - 마커 없음 / 지금 진행과 맞는 마커 있음 두 변형(dev:947 '마커 등가'): 전체 시작
    #     (S0 → S3 → 첫 기동) → 복구 안내 정확히 1 · 마커 정리 0 · 마커 그대로 · 첫 기동 = 마무리 복구(RECOVERY 1 · RESTART 1 · 그 항목 - 재입장 0) · PREV = 그 항목 ·
    #     cleared(i) 는 미적용 그대로(소비는 복구 워커의 코드 0 이 함)
    $sg4 = foreach ($withMarker in @($false, $true)) {
        Initialize-StartCase ('sg4_cleared_marker_' + $withMarker)
        Write-TestConfig -Lap 1 -Index 0
        Write-TestJournal -Entries @(New-StartEntry -Stage 'cleared' -Nonce $NONCE_1)
        if ($withMarker) { Write-TestMarkers -Lap 1 -Index 0 }
        $markerBefore = Get-MarkerState
        Reset-Observation
        $outcome = Invoke-ManualStart
        $recoverLines = @($script:guiLogLines | Where-Object { $_ -ceq $SG_RECOVER_NOTICE }).Count
        '마커 {0}: {1} · 복구 안내 {2} · 마커 정리 {3} · 마커 그대로 {4} · {5} · PREV 그 항목 {6} · {7}' -f $withMarker, $outcome, $recoverLines, $script:markerClears,
            ((Get-MarkerState) -ceq $markerBefore), (Get-LaunchText), ([string]$script:launches[0]['HONEYNOGI_CUSTOM_PREV'] -ceq (Format-CustomItemToken -Item $ITEMS[0])),
            (Get-JournalEntryText $NONCE_1)
    }
    Assert-Case 'SG4 S3 cleared(i) → 마무리 복구 예약 + 마커 게이트 건너뜀(마커 없음 || 맞는 마커 있음) → 복구 안내 1 · 마커 정리 0 · 첫 기동 recover 1번(재입장 0) · PREV · cleared 미적용' `
        ($sg4 -join ' || ') `
        ('마커 False: launched · 복구 안내 1 · 마커 정리 0 · 마커 그대로 True · 기동 recover 1번 · RESTART [1] · 재입장 0 · PREV 그 항목 True · cleared/pending/0 || ' +
            '마커 True: launched · 복구 안내 1 · 마커 정리 0 · 마커 그대로 True · 기동 recover 1번 · RESTART [1] · 재입장 0 · PREV 그 항목 True · cleared/pending/0')
    # SG4′ 지금 칸의 cleared 가 이미 적용됨(그 판은 계상됨 - 예: 일반 코드 10 의 소비) → S3 none(미적용만 근거 - dev:947) → 마커 없음 → 복구 안내 0 · 첫 기동 새 입장 ||
    #      SG4″ 지금 칸의 post-clear-stop(클리어 이상 - 재입장 요청 전) → cleared 와 같은 마무리 복구(코드 1 라우팅의 'legacy-cleared' 와 같은 분류) (단계 2.7~2.9 구현 검증 -
    #      생존 변이 'S3 가 applied 를 보지 않음' · 'post-clear-stop 을 복구로 보지 않음' 을 가름)
    $sg4More = foreach ($moreCase in @(@{ N = '적용된 cleared'; Stage = 'cleared'; Applied = @($NONCE_1) }, @{ N = 'post-clear-stop'; Stage = 'post-clear-stop'; Applied = @() })) {
        Initialize-StartCase ('sg4_more_' + $moreCase.Stage)
        Write-TestConfig -Lap 1 -Index 0
        Write-TestJournal -Entries @(New-StartEntry -Stage $moreCase.Stage -Nonce $NONCE_1) -Applied $moreCase.Applied
        Reset-Observation
        $moreOutcome = Invoke-ManualStart
        '{0}: {1} · 복구 안내 {2} · {3}' -f $moreCase.N, $moreOutcome, @($script:guiLogLines | Where-Object { $_ -ceq $SG_RECOVER_NOTICE }).Count, (Get-LaunchText)
    }
    Assert-Case 'SG4′ 지금 칸의 적용된 cleared → 복구 안내 0 · 첫 기동 fresh(새 입장) || SG4″ post-clear-stop → 마무리 복구(복구 안내 1 · recover)' ($sg4More -join ' || ') `
        ('적용된 cleared: launched · 복구 안내 0 · 기동 fresh 1번 · RESTART [] · 재입장 1 || post-clear-stop: launched · 복구 안내 1 · 기동 recover 1번 · RESTART [1] · 재입장 0')

    # SG5 S3 재입장 요청(retry-clicked) - 재개 기능 꺼짐(GUI 원문 값) → 시작 거부(해제 방법 안내 - 명세 5절 B10) · 파일 그대로 · 기동 0 / 켜진 빌드(진리표 - 명세 3.4)
    #     → 재개 수동 1회: 재개 횟수 0 → 1 · [경고] 안내 · 첫 기동 = 재개(RESUME 1 · HANDOFF_NONCE = 그 항목 · RESTART·RECOVERY 빈 값) · 마커 정리 0(-PreserveMarker) ·
    #     예약은 기동 뒤 비움 / 재개 횟수 1(자동 재개 뒤 두 번째 오류로 멈춘 판) → 다음 수동 시작이 한 번 더 허용(dev:889) → 2
    Initialize-StartCase 'sg5_retry_off'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'retry-clicked' -Nonce $NONCE_1)
    Write-TestMarkers -Lap 1 -Index 0
    $stateBefore = Get-CaseFileState
    Reset-Observation
    $offOutcome = Invoke-ManualStart
    $offText = '{0} · {1} · 파일 그대로 {2} · {3}' -f $offOutcome, (Format-GateLogLines), ((Get-CaseFileState) -ceq $stateBefore), (Get-LaunchText)
    $onTexts = foreach ($priorAttempts in @(0, 1)) {
        Initialize-StartCase ('sg5_retry_on_' + $priorAttempts)
        Write-TestConfig -Lap 1 -Index 0
        Write-TestJournal -Entries @(New-StartEntry -Stage 'retry-clicked' -Nonce $NONCE_1 -ResumeAttempts $priorAttempts)
        Write-TestMarkers -Lap 1 -Index 0
        $markerBefore = Get-MarkerState
        Reset-Observation
        $script:abyssPartyRetryEnabled = $true
        try { $onOutcome = Invoke-ManualStart } finally { $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG }
        $resumeEnv = $(if ($script:launches.Count -gt 0) { $script:launches[0] } else { @{} })
        '재개 횟수 {0}: {1} · 안내 {2} · {3} · RECOVERY [{4}] · 마커 정리 {5} · 마커 그대로 {6} · 재개 횟수 {7} · 예약 {8}/[{9}]' -f $priorAttempts, $onOutcome,
            @($script:guiLogLines | Where-Object { $_ -ceq $SG_RESUME_NOTICE }).Count, (Get-LaunchText), [string]$resumeEnv['HONEYNOGI_CUSTOM_RECOVERY'], $script:markerClears,
            ((Get-MarkerState) -ceq $markerBefore), (Get-JournalResumeAttempts $NONCE_1), $script:customResumePending, $script:customResumeNonce
    }
    Assert-Case ('SG5 S3 retry-clicked · 재개 기능 꺼짐(GUI 원문 값 {0}) → 시작 거부(해제 방법) · 파일 그대로 || 켜진 빌드 → 재개 수동 1회(재개 횟수 +1 · RESUME · 마커 정리 0 · 예약 비움) · 재개 횟수 1 이어도 수동은 한 번 더' -f $GUI_RETRY_FLAG) `
        ('{0} || {1}' -f $offText, ($onTexts -join ' || ')) `
        (('refused@S3 · {0} · 파일 그대로 True · 기동 0 || ' -f $SG_REFUSE_RETRY_OFF) +
            '재개 횟수 0: launched · 안내 1 · 기동 resume:N1 1번 · RESTART [] · 재입장 0 · RECOVERY [] · 마커 정리 0 · 마커 그대로 True · 재개 횟수 1 · 예약 False/[] || ' +
            '재개 횟수 1: launched · 안내 1 · 기동 resume:N1 1번 · RESTART [] · 재입장 0 · RECOVERY [] · 마커 정리 0 · 마커 그대로 True · 재개 횟수 2 · 예약 False/[]')

    # SG5′ 켜진 빌드의 재개 횟수 기록 실패 - S3 읽기 뒤 다른 기록 주체가 잠금(읽은 뒤 갈고리) → 시작 거부(사용 중 문구 + 안내) · 예약 0 · 재개 횟수 그대로 · 기동 0
    Initialize-StartCase 'sg5_record_locked'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'retry-clicked' -Nonce $NONCE_1)
    Reset-Observation
    $script:abyssPartyRetryEnabled = $true
    $script:afterReadHook = { param($callNumber) if ($callNumber -eq 1) { Lock-JournalLockFile } }
    try { Invoke-StartGateS3 } finally { Unlock-TestFiles; $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG }
    Assert-Case "SG5′ 켜진 빌드 · 재개 횟수 기록 '사용 중' → 시작 거부(사용 중 문구 + 안내) · 예약 0 · 재개 횟수 0" `
        ('실행 {0} · {1} · 예약 {2} · 재개 횟수 {3}' -f $script:customActive, (Format-LogLines), $script:customResumePending, (Get-JournalResumeAttempts $NONCE_1)) `
        ('실행 False · {0} · 예약 False · 재개 횟수 0' -f $SG_REFUSE_LOCKED)
    # SG5″ 켜진 빌드 · 재개 횟수 기록 중 예외(저장 예외 주입) → 적용의 catch 가 시작 거부 + [오류] 예외 줄 · 예약 0 · 재개 횟수 0 || SG5‴ 켜진 빌드 · S3 가 읽은 뒤 그 항목이
    #      재입장 요청 단계가 아니게 바뀜(다른 기록 주체 - 읽은 뒤 갈고리가 실제 저장소로 단계만 바꿈) → 재개 횟수 기록의 실제 -Expect 거절 → 시작 거부(재개 기록 저장 실패) ·
    #      예약 0 (명세 5절 A4·B10 - 기록 실패·예외 = 시작 금지. 단계 2.7~2.9 구현 검증 - 생존 변이 '적용 catch 가 시작 계속' · '사용 중·손상 밖 실패가 시작 계속' 을 가름:
    #      SG5′ 는 사용 중 갈래만 봄)
    Initialize-StartCase 'sg5_record_exception'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'retry-clicked' -Nonce $NONCE_1)
    Reset-Observation
    $script:abyssPartyRetryEnabled = $true
    $script:updateThrows = $true
    try { $throwOutcome = Invoke-ManualStart } finally { $script:updateThrows = $false; $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG }
    $throwText = '{0} · {1} · 예약 {2} · 재개 횟수 {3} · {4}' -f $throwOutcome, (Format-GateLogLines), $script:customResumePending, (Get-JournalResumeAttempts $NONCE_1), (Get-LaunchText)
    Initialize-StartCase 'sg5_record_expect'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'retry-clicked' -Nonce $NONCE_1)
    Reset-Observation
    $script:abyssPartyRetryEnabled = $true
    $script:afterReadHook = {
        param($callNumber)
        if ($callNumber -eq 1) {
            $stageMutator = { param($journal, $change) foreach ($stageEntry in @($journal.entries)) { $stageEntry.stage = 'reentered' }; $change.Changed = $true }
            [void](& $script:realUpdateAbyssJournal -Path $script:abyssJournalPath -Mutator $stageMutator)
        }
    }
    try { Invoke-StartGateS3 } finally { $script:afterReadHook = $null; $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG }
    $expectText = '실행 {0} · {1} · 예약 {2} · 재개 횟수 {3}' -f $script:customActive, (Format-LogLines), $script:customResumePending, (Get-JournalResumeAttempts $NONCE_1)
    Assert-Case 'SG5″ 켜진 빌드 · 재개 횟수 기록 예외 → refused@S3 · [오류] 예외 줄 · 예약 0 · 재개 횟수 0 · 기동 0 || SG5‴ 읽은 뒤 단계 바뀜(실제 -Expect) → 거부(재개 기록 저장 실패) · 예약 0' `
        ('{0} || {1}' -f $throwText, $expectText) `
        ('refused@S3 · {0} · 예약 False · 재개 횟수 0 · 기동 0 || 실행 False · {1} · 예약 False · 재개 횟수 0' -f ($SG_EXCEPTION_FORMAT -f $INJECTED_STORE_EXCEPTION), $SG_RESUME_SAVE_FAIL)

    # SG6 범위 - 어비스 커스텀 시작이 아니면(던전 커스텀 섹션) S0·S3 둘 다 journal 접근 0(읽기 0) · 거부 0 · 그 기록은 그대로(명세 2.9 '어비스 커스텀만')
    Initialize-StartCase 'sg6_dungeon_custom'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'cleared' -Nonce $NONCE_1)
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_2
    $stateBefore = Get-CaseFileState
    Reset-Observation
    $script:customConfigSection = 'customRepeat'
    $s0Result = Invoke-AbyssStartJournalAdvance
    $s3Result = Get-AbyssStartJournalAction
    $script:customConfigSection = $ABYSS_SECTION
    Assert-Case 'SG6 던전 커스텀 시작 → S0 Ok·변경 없음 · S3 none · journal 읽기 0 · 파일 그대로 · 로그 0' `
        ('{0}/{1} · {2} · 읽기 {3} · 파일 그대로 {4} · 로그 {5}' -f $s0Result.Ok, $s0Result.ConfigChanged, $s3Result.Action, $script:readCalls, ((Get-CaseFileState) -ceq $stateBefore), $script:guiLogLines.Count) `
        'True/False · none · 읽기 0 · 파일 그대로 True · 로그 0'
}

function Test-CaseStartS0 {
    # SG7 마지막 바퀴 마지막 항목의 완주 원소(A2) 잔존 + 재시작(dev:990 · dev:945): 1바퀴 지정·진행 1바퀴째 3/3번 · 대기열 A2(owner 3번 칸) → S0 반영이 진행을
    #     2바퀴째 1번으로 → 진행을 다시 읽은 S1 이 완주로 판정해 진행 초기화(새 1바퀴) · '이어갑니다'(같은 항목 다시 = 추가 회차) 줄 0 (변이 '진행 다시 읽기 제거'·'큐
    #     반영을 S1 뒤로' 는 여기서 이어가기 줄이 생김)
    Initialize-StartCase 'sg7_a2_left'
    Write-TestConfig -Lap 1 -Index 2 -ListRepeat 'count' -ListRepeatCount 1
    Write-TestMarkers -Lap 1 -Index 2
    Add-TestPending -Lap 1 -Index 2 -Stage $STAGE_A2 -Nonce $NONCE_2
    $position2 = (Get-TestOwner -Lap 1 -Index 2).Position
    Reset-Observation
    Invoke-StartGateS0
    Assert-Case 'SG7 마지막 판 A2 잔존 → S0 전진(진행 2/0 · 대기열 빔 · [경고] 전진 줄) → S1 완주 판정 → 진행 초기화 1 · 이어가기 줄 0 · 시작 계속' `
        ('{0} · [{1}] · {2} · 전진 {3} · 초기화 {4} · 이어가기 {5} · 실행 {6}' -f (Get-ProgressText), (Get-PendingText),
            (@($script:guiLogLines | Where-Object { $_.StartsWith('[경고] 이전 세션의') }) -join ''), $script:stepCalls, @($script:events | Where-Object { $_ -ceq 'reset' }).Count,
            @($script:guiLogLines | Where-Object { $_.StartsWith($SG_PROGRESS_RESUME_PREFIX) }).Count, $script:customActive) `
        ('2/0 · [] · {0} · 전진 1 · 초기화 1 · 이어가기 0 · 실행 True' -f ($START_ADVANCE_FORMAT -f $position2))
    # SG7′ S0 가 진행을 바꾼 뒤 설정을 다시 못 읽음(대기열 반영의 마지막 읽기 뒤 config.json 을 FileShare.None 으로 쥠 - 일시 공유 위반) → 시작 거부 · 지문 검사·완주
    #      판정(S1) 미실행(진행을 모른 채 건너뛰지 않음) · 반영한 전진은 디스크에 남음(2/0 - 다음 시작은 대기열이 비어 같은 진행으로 판정)
    Initialize-StartCase 'sg7_reread_fails'
    Write-TestConfig -Lap 1 -Index 2 -ListRepeat 'count' -ListRepeatCount 1
    Add-TestPending -Lap 1 -Index 2 -Stage $STAGE_A2 -Nonce $NONCE_2
    Reset-Observation
    $script:afterReadHook = { param($callNumber) if ($callNumber -eq 3) { Lock-TestFile -Path $script:configPath -Share 'None' } }
    try { Invoke-StartGateS0 } finally { Unlock-TestFiles }
    Assert-Case 'SG7′ S0 뒤 설정 다시 읽기 실패 → 시작 거부(그 문구) · 초기화·이어가기 0 · 전진 1 · 대기열 빔 · 2/0' `
        ('실행 {0} · {1} · 초기화 {2} · 전진 {3} · [{4}] · {5}' -f $script:customActive, (@($script:guiLogLines | Where-Object { $_.StartsWith('[오류]') }) -join ''),
            @($script:events | Where-Object { $_ -ceq 'reset' }).Count, $script:stepCalls, (Get-PendingText), (Get-ProgressText)) `
        ('실행 False · {0} · 초기화 0 · 전진 1 · [] · 2/0' -f $SG_REREAD_FAIL)

    # SG8 계상 전에 끝난 미적용 reentered(재입장 실행부 전에 GUI 가 꺼짐 - dev:944 ②): 진행 1/0 · N1 reentered(owner 1번 칸 · nextOwner 2번 칸 · launchState pending) ·
    #     워커가 남긴 마커(owner 1번 칸) → 전체 시작: S0 전진 1(1/1) · N1 applied · launchState 그대로 · [경고] 전진 줄 → S3 none → 마커 게이트가 맞지 않는 마커 폐기 →
    #     첫 기동 = next:N1 2번 칸(다음 판 던전 안을 이어받음 - 재입장 0) · N1 launched (변이 'S0 ② 없음' 은 마커로 1번 칸 복구 = 들어간 판을 잃음)
    Initialize-StartCase 'sg8_reentered'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'reentered' -Nonce $NONCE_1 -Next)
    Write-TestMarkers -Lap 1 -Index 0
    $position0 = (Get-TestOwner -Lap 1 -Index 0).Position
    Reset-Observation
    $sg8Outcome = Invoke-ManualStart
    Assert-Case 'SG8 미적용 reentered → S0 전진 1 · 진행 1/1 · [경고] 전진 줄 · 마커 폐기 → 첫 기동 next:N1 2번(재입장 0) · N1 reentered/launched/적용' `
        ('{0} · {1} · 전진 {2} · {3} · 폐기 {4} · {5} · {6}' -f $sg8Outcome, (Get-ProgressText), $script:stepCalls,
            (@($script:guiLogLines | Where-Object { $_.StartsWith('[경고] 이전 세션의') }) -join ''), @($script:guiLogLines | Where-Object { $_ -ceq $SG_MARKER_DISCARD }).Count,
            (Get-LaunchText), (Get-JournalEntryText $NONCE_1)) `
        ('launched · 1/1 · 전진 1 · {0} · 폐기 1 · 기동 next:N1 2번 · RESTART [] · 재입장 0 · reentered/launched/1' -f ($START_ADVANCE_FORMAT -f $position0))
    # SG8′ S0 가 reentered 로 진행을 전진하면 지문 검사·완주 판정(S1)은 진행을 다시 읽어 전진한 위치로 판정합니다(dev:945 · 명세 0.5 J6) - 이어가기 줄 = 1바퀴 2번
    #      (단계 2.7~2.9 구현 검증 - 생존 변이 'reentered 전진 뒤 다시 읽기 안 함' 을 가름: SG8 은 이어가기 줄을 걸러 봄)
    Initialize-StartCase 'sg8_reentered_s1'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'reentered' -Nonce $NONCE_1 -Next)
    Reset-Observation
    Invoke-StartGateS0
    Assert-Case 'SG8′ S0 reentered 전진 → S1 이어가기 줄 = 전진한 위치(1바퀴 2번)' `
        ((@($script:guiLogLines | Where-Object { $_.StartsWith($SG_PROGRESS_RESUME_PREFIX) })) -join ' ¶ ') `
        ('{0}{1}부터 시작합니다.' -f $SG_PROGRESS_RESUME_PREFIX, (Get-CustomPositionText -Lap 1 -Index 1 -Total $ITEMS.Count))

    # SG9 S0 의 reentered 처리 실패 - (가) 진행 위치를 재시도까지 4번 다 못 읽음 → 시작 거부(주인 확인 불가) · 전진 0 · 파일 그대로 / (나) 진행 저장 실패(config 를 읽기만
    #     허용하고 쥠) → Step 자신의 [오류] 줄 + 거부 · 전진 저장 0(1/0) · N1 미적용 / (다) applied 저장 '사용 중'(전진 뒤 다른 주체가 잠금) → 거부(사용 중 + 안내 - 진행은
    #     반영됨) · 1/1 · N1 미적용 → 잠금을 놓고 다시 시작 → 진행이 이미 다음 칸이라 다시 전진 0(이중 전진 0) · 첫 기동 next:N1 2번
    Initialize-StartCase 'sg9_no_context'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'reentered' -Nonce $NONCE_1 -Next)
    $stateBefore = Get-CaseFileState
    Reset-Observation
    $script:contextNullReads = 4
    $noContextOutcome = Invoke-ManualStart
    $noContextText = '{0} · {1} · 위치 읽기 {2} · 전진 {3} · 파일 그대로 {4}' -f $noContextOutcome, (Format-GateLogLines), $script:contextReads, $script:stepCalls, ((Get-CaseFileState) -ceq $stateBefore)
    Initialize-StartCase 'sg9_step_fails'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'reentered' -Nonce $NONCE_1 -Next)
    Reset-Observation
    Lock-TestFile -Path $script:configPath -Share 'Read'
    try { $stepFailOutcome = Invoke-ManualStart } finally { Unlock-TestFiles }
    $stepFailText = '{0} · Step 줄 {1} · {2} · {3} · {4}' -f $stepFailOutcome, @($script:guiLogLines | Where-Object { $_.StartsWith($SG_STEP_LOCK_PREFIX) }).Count,
        (@($script:guiLogLines | Where-Object { -not $_.StartsWith($SG_STEP_LOCK_PREFIX) }) -join ' ¶ '), (Get-ProgressText), (Get-JournalEntryText $NONCE_1)
    Initialize-StartCase 'sg9_mark_locked'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'reentered' -Nonce $NONCE_1 -Next)
    Reset-Observation
    $script:afterStepHook = { param($callNumber) if ($callNumber -eq 1) { Lock-JournalLockFile } }
    try { $markOutcome = Invoke-ManualStart } finally { Unlock-TestFiles }
    $markText = '{0} · {1} · {2} · {3}' -f $markOutcome, (@($script:guiLogLines | Where-Object { $_.StartsWith('[오류]') }) -join ''), (Get-ProgressText), (Get-JournalEntryText $NONCE_1)
    Initialize-StartCase -KeepFolder
    $againOutcome = Invoke-ManualStart
    $againText = '{0} · 전진 {1} · {2} · {3}' -f $againOutcome, $script:stepCalls, (Get-ProgressText), (Get-LaunchText)
    Assert-Case 'SG9 S0 reentered · 위치 없음 → 거부 · 읽기 4 · 전진 0 · 파일 그대로 || 진행 저장 실패 → 거부 · 1/0 · 미적용 || applied 사용 중 → 거부(+ 안내) · 1/1 → 다시 시작: 전진 0 · next:N1 2번' `
        ('{0} || {1} || {2} → {3}' -f $noContextText, $stepFailText, $markText, $againText) `
        (('refused@S0 · {0} · 위치 읽기 4 · 전진 0 · 파일 그대로 True || refused@S0 · Step 줄 1 · {1} · 1/0 · reentered/pending/0 || ' +
            'refused@S0 · {2} {3} · 1/1 · reentered/pending/0 → launched · 전진 0 · 1/1 · 기동 next:N1 2번 · RESTART [] · 재입장 0') -f $SG_REFUSE_NO_OWNER, $SG_REENTER_STEP_FAIL,
            ($SG_REENTER_MARK_FAIL_FORMAT -f '파일 사용 중'), $LOCKED_GUIDE)
    # SG9′ S0 처리 중 예외(전진 뒤 applied 저장에서 예외 주입) → S0 의 catch 가 시작 거부 + [오류] 예외 줄(명세 5절 A4) · 전진은 디스크에 남음(1/1) · N1 미적용 (단계 2.7~2.9
    #      구현 검증 - 생존 변이 'S0 catch 가 시작 계속' · '[오류] 줄 없이 거부' 를 가름: S0 예외 주입 행이 없었음)
    Initialize-StartCase 'sg9_s0_exception'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'reentered' -Nonce $NONCE_1 -Next)
    Reset-Observation
    $script:updateThrows = $true
    try { $s0ThrowOutcome = Invoke-ManualStart } finally { $script:updateThrows = $false }
    Assert-Case 'SG9′ S0 예외 → refused@S0 · [오류] 예외 줄 · 진행 1/1 · N1 미적용 · 기동 0' `
        ('{0} · {1} · {2} · {3} · {4}' -f $s0ThrowOutcome, (@($script:guiLogLines | Where-Object { $_.StartsWith('[오류]') }) -join ' ¶ '), (Get-ProgressText), (Get-JournalEntryText $NONCE_1),
            (Get-LaunchText)) `
        ('refused@S0 · {0} · 1/1 · reentered/pending/0 · 기동 0' -f ($SG_EXCEPTION_FORMAT -f $INJECTED_STORE_EXCEPTION))

    # SG10 S0 대기열 반영 실패 → 시작 거부 · 대기열 그대로: (가) 대기열 원소의 진행 저장 실패 → 반영 함수의 [오류] 줄 + 거부(안내 없음) / (나) 첫 읽기 뒤 다른 주체가
    #     잠금 → 반영 읽기 '사용 중' → 반영 함수의 [오류] 줄 + 거부 + 잠금 파일 안내(대기열 함수가 남긴 태그 - Get-AbyssPendingStopReason)
    Initialize-StartCase 'sg10_queue_step'
    Write-TestConfig -Lap 1 -Index 0
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
    Reset-Observation
    Lock-TestFile -Path $script:configPath -Share 'Read'
    try { $queueStepOutcome = Invoke-ManualStart } finally { Unlock-TestFiles }
    $queueStepText = '{0} · {1} · [{2}] · {3}' -f $queueStepOutcome, (@($script:guiLogLines | Where-Object { -not $_.StartsWith($SG_STEP_LOCK_PREFIX) }) -join ' ¶ '), (Get-PendingText), (Get-ProgressText)
    Initialize-StartCase 'sg10_queue_locked'
    Write-TestConfig -Lap 1 -Index 0
    Add-TestPending -Lap 1 -Index 0 -Stage $STAGE_A1 -Nonce $NONCE_1
    Reset-Observation
    $script:afterReadHook = { param($callNumber) if ($callNumber -eq 1) { Lock-JournalLockFile } }
    try { $queueLockOutcome = Invoke-ManualStart } finally { Unlock-TestFiles }
    $queueLockText = '{0} · {1} · [{2}] · {3}' -f $queueLockOutcome, (Format-GateLogLines), (Get-PendingText), (Get-ProgressText)
    Assert-Case "SG10 S0 대기열 반영 실패: 진행 저장 실패 → 반영 [오류] + 거부 · 대기열 그대로 · 1/0 || 반영 읽기 '사용 중' → 반영 [오류] + 거부 + 잠금 파일 안내 · 대기열 그대로" `
        ('{0} || {1}' -f $queueStepText, $queueLockText) `
        (('refused@S0 · {0} ¶ {1} · [A1:N1:1/0] · 1/0 || refused@S0 · {2} ¶ {3} {4} · [A1:N1:1/0] · 1/0') -f ($ADVANCE_FAIL_FORMAT -f '진행 기록 저장 실패'), $SG_QUEUE_FAIL,
            ($ADVANCE_FAIL_FORMAT -f '파일 사용 중'), $SG_QUEUE_FAIL, $LOCKED_GUIDE)

    # SG13 마무리 실행 기동의 코드 1(설계 R1 6.3a H32b 커스텀 - 실행부의 진행 저장 실패 → 대기열 A1 + 마무리 실행) 뒤 다음 수동 시작을 시작 처리 그대로(C7 이 함수로 나눠
    #      본 것): S0 대기열 반영 1/0 → 1/1 → S3 none(진행 2번 칸의 기록 없음) → 마커 게이트가 끝난 판의 마커(1번 칸) 폐기 → 첫 기동 next:N1 2번(같은 nonce 로 이어받음 -
    #      재입장 0 · 재전송 0)
    $null = Initialize-HandoffCase 'sg13_h32b_start'
    Invoke-InsideHandoffExitRow -StepFails
    $null = Invoke-Code1FinishOnlyCheck -exitCode 1
    Initialize-StartCase -KeepFolder
    $h32bOutcome = Invoke-ManualStart
    Assert-Case 'SG13 H32b 커스텀 → 다음 수동 시작(실제 S0·S3·마커 게이트·첫 기동) → S0 반영 1/1 · 대기열 빔 · 마커 폐기 → 첫 기동 next:N1 2번(재입장 0)' `
        ('{0} · {1} · 전진 {2} · [{3}] · 폐기 {4} · {5}' -f $h32bOutcome, (Get-ProgressText), $script:stepCalls, (Get-PendingText),
            @($script:guiLogLines | Where-Object { $_ -ceq $SG_MARKER_DISCARD }).Count, (Get-LaunchText)) `
        'launched · 1/1 · 전진 1 · [] · 폐기 1 · 기동 next:N1 2번 · RESTART [] · 재입장 0'

    # SG14 마무리 실행 완주 직후 GUI 재시작(P3 픽스처 - 완주 처리 전에 꺼짐: 대기열 A1 · 완주 판(2번 칸)의 cleared(NS) · 마커 owner 2번 칸)을 시작 처리 그대로: S0 대기열 반영
    #      1/0 → 1/1 → S3 가 2번 칸의 미적용 cleared 로 마무리 복구 예약(마커 게이트 건너뜀 - 마커와 같은 결론) → 첫 기동 recover 2번 → 그 복구 워커의 코드 0(타이머 코드
    #      0·11 갈래 본문 점소싱) → 1/2 · NS 소비 · 마무리 복구 완료 줄 (전진 총 2 - dev:990 '완주 직후 GUI 재시작 → 마무리 복구 → 전진 총 2')
    $info = Initialize-HandoffCase 'sg14_finish_restart'
    Invoke-InsideHandoffExitRow -StepFails
    Add-FinishWorkerResult -OwnerNext $info.OwnerNext
    Initialize-StartCase -KeepFolder
    $p3Outcome = Invoke-ManualStart
    $p3Start = '{0} · {1} · 전진 {2} · 복구 안내 {3} · {4}' -f $p3Outcome, (Get-ProgressText), $script:stepCalls, @($script:guiLogLines | Where-Object { $_ -ceq $SG_RECOVER_NOTICE }).Count,
        (Get-LaunchText)
    Reset-Observation
    $exitCode = 0
    . $code0Block
    Assert-Case 'SG14 완주 직후 재시작 → S0 1/1 → S3 cleared(NS) 마무리 복구 → 첫 기동 recover 2번 → 그 워커 코드 0 → 1/2(전진 총 2) · NS 소비 · 마무리 복구 완료 줄 1' `
        ('{0} → {1} · {2} · 복구 완료 줄 {3}' -f $p3Start, (Get-ProgressText), (Get-JournalEntryText $NONCE_S),
            @($script:guiLogLines | Where-Object { $_ -ceq '[커스텀] 마무리 복구 완료 - 다음 항목으로 진행합니다.' }).Count) `
        'launched · 1/1 · 전진 1 · 복구 안내 1 · 기동 recover 2번 · RESTART [1] · 재입장 0 → 1/2 · cleared/pending/1 · 복구 완료 줄 1'
}

function Test-CaseStartContinuation {
    # SG11 명세 5절 A6 코드 10 행 (가) - 마무리 복구 기동(RECOVERY - 마커 없이 클리어 기록으로 띄운 복구)이 복귀 중 안전 중지로 코드 10: 타이머 코드 10 갈래 첫 문장(끝 처리 -
    #     AST 로 잘라 점소싱)은 cleared(i) 를 소비하지 않음(journal 접근 0) → 다음 수동 시작 S3 가 다시 마무리 복구(재입장 0) (변이 '마무리 복구 기동에서도 소비' 는
    #     다음 시작 근거 0 → 그 항목 새 입장 = 재입장 1)
    Initialize-StartCase 'sg11_code10_recovery'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'cleared' -Nonce $NONCE_1)
    $null = Invoke-ManualStart
    $firstLaunch = Get-LaunchText
    Reset-Observation
    $exitCode = 10
    . $code10FirstBlock
    $code10Text = '{0} · 읽기·저장 {1}/{2} · {3}' -f $firstLaunch, $script:readCalls, $script:updateCalls, (Get-JournalEntryText $NONCE_1)
    Initialize-StartCase -KeepFolder
    $nextOutcome = Invoke-ManualStart
    Assert-Case 'SG11 cleared(i) → 복구 기동 → 코드 10(복귀 중 안전 중지) 첫 문장 끝 처리 = 소비 0(접근 0) → 다음 수동 시작 S3 복구(재입장 0)' `
        ('{0} → {1} · {2}' -f $code10Text, $nextOutcome, (Get-LaunchText)) `
        '기동 recover 1번 · RESTART [1] · 재입장 0 · 읽기·저장 0/0 · cleared/pending/0 → launched · 기동 recover 1번 · RESTART [1] · 재입장 0'

    # SG12 명세 리뷰 3 P1 행의 이어받기(⑯ '리뷰 3 P1' 행과 같은 픽스처: 커스텀 코드 0 + 마커 없음 + 미적용 cleared(i) + 진행 저장 실패) - 타이머 코드 0·11 갈래 본문을
    #     AST 로 잘라 점소싱: 판별 none → 일반 끝 처리(커스텀 0 이라 소비 없음) → 진행 저장 실패(config 를 읽기만 허용하고 쥠) → 지금 문구로 정지 · cleared(i) 미적용 ·
    #     owner = 디스크 i → 다음 수동 시작 S3 가 복구 예약 1 · 첫 기동 = 마무리 복구(같은 항목 재입장 0) (변이 RV3-c '소비를 진행 전진 앞 첫 호출로' 는 cleared(i) 를
    #     먼저 소비해 다음 시작이 근거 없이 그 항목에 새로 입장 = 재입장 1)
    Initialize-StartCase 'sg12_review3_p1'
    Write-TestConfig -Lap 1 -Index 0
    Write-TestJournal -Entries @(New-StartEntry -Stage 'cleared' -Nonce $NONCE_1)
    $script:completedCycles = 1
    Reset-Observation
    Lock-TestFile -Path $script:configPath -Share 'Read'
    try {
        $exitCode = 0
        . $code0Block
    } finally {
        Unlock-TestFiles
    }
    $code0Text = '{0} · {1} · 복구 대기 {2} · 기동 {3}' -f ($script:stops -join ' / '), (Get-JournalEntryText $NONCE_1), $script:customRecoveryPending, $script:launches.Count
    Initialize-StartCase -KeepFolder
    $nextOutcome = Invoke-ManualStart
    Assert-Case '리뷰 3 P1 이어받기: 커스텀 코드 0 + 마커 없음 + cleared(i) + 진행 저장 실패 → 정지 · cleared(i) 미적용 → 다음 수동 시작 S3 복구 예약 1 · 첫 기동 recover(재입장 0)' `
        ('{0} → {1} · 복구 안내 {2} · {3}' -f $code0Text, $nextOutcome, @($script:guiLogLines | Where-Object { $_ -ceq $SG_RECOVER_NOTICE }).Count, (Get-LaunchText)) `
        ('{0}|True · cleared/pending/0 · 복구 대기 True · 기동 0 → launched · 복구 안내 1 · 기동 recover 1번 · RESTART [1] · 재입장 0' -f $C0_STEP_STOP)
}

function Test-CaseStartStatic {
    # S6 새 함수 서명(명세 2.9 - S3 판정·S0 는 무인자, 적용·복구 예약·거부 문구는 인자 하나·둘)
    $signatureText = (@('Invoke-AbyssStartJournalAdvance', 'Get-AbyssStartJournalAction', 'Invoke-AbyssStartJournalAction', 'Set-CustomRecoveryReservation',
            'Get-AbyssStartJournalRefusal', 'Read-AbyssStartJournal') | ForEach-Object { '{0}({1})' -f $_, (Get-ParamSignature $guiAst $_) }) -join ' / '
    Assert-Case 'S6 시작 게이트 함수 서명' $signatureText `
        ('Invoke-AbyssStartJournalAdvance((매개변수 없음)) / Get-AbyssStartJournalAction((매개변수 없음)) / Invoke-AbyssStartJournalAction(Object $Plan) / ' +
            'Set-CustomRecoveryReservation(Object $Context) / Get-AbyssStartJournalRefusal(String $Status, String $Detail) / Read-AbyssStartJournal((매개변수 없음))')
    # S7 호출 소유자 - S0·S3 판정·적용 = 시작 처리 1곳씩 · 복구 예약 = S3 적용 + 마커 게이트(시작 처리) · 거부 문구 = S0 3(첫 읽기·다시 읽기·주인 확인 불가) + S3 판정 3(읽기·주인
    #    확인 불가·재개 꺼짐) + 적용 1(재개 기록 사용 중·손상) · 공용 읽기 = S0 2 + S3 판정 1
    Assert-Case 'S7 호출 소유자: S0·S3 판정·적용 = 시작 처리 · 복구 예약 = S3 적용·마커 게이트 · 거부 문구 = S0 3 + S3 판정 3 + 적용 1 · 공용 읽기 = S0 2 + S3 판정 1' `
        ((@('Invoke-AbyssStartJournalAdvance', 'Get-AbyssStartJournalAction', 'Invoke-AbyssStartJournalAction', 'Set-CustomRecoveryReservation', 'Get-AbyssStartJournalRefusal',
                'Read-AbyssStartJournal') | ForEach-Object { Get-GuiCallOwners $_ }) -join ' / ') `
        ('1|Invoke-StartAutomation / 1|Invoke-StartAutomation / 1|Invoke-StartAutomation / 2|Invoke-AbyssStartJournalAction,Invoke-StartAutomation / ' +
            '7|Get-AbyssStartJournalAction,Get-AbyssStartJournalAction,Get-AbyssStartJournalAction,Invoke-AbyssStartJournalAction,Invoke-AbyssStartJournalAdvance,Invoke-AbyssStartJournalAdvance,Invoke-AbyssStartJournalAdvance / ' +
            '3|Get-AbyssStartJournalAction,Invoke-AbyssStartJournalAdvance,Invoke-AbyssStartJournalAdvance')
    # S8 S0 자리(명세 2.9 · 0.5 J6): 커스텀 게이트 블록에서 진행 읽기 두 문장 → S0 → 거부 return → 진행 다시 읽기(바뀌었을 수 있을 때 - 못 읽으면 거부) → 지문
    #    검사(S1)의 if - 문장 원문(주석 뺌·공백 정규화). S1 이 S0 가 바꾼 진행으로 판정하는지는 SG7 이 행동으로 봅니다
    $s0Texts = @($startS0Statements | Select-Object -First 5 | ForEach-Object { ((Remove-SourceComments -Text $_.Extent.Text) -replace '\s+', ' ').Trim() })
    $s0Texts += [string]$startS0Statements[5].Extent.Text.Substring(0, [Math]::Min(18, $startS0Statements[5].Extent.Text.Length))
    Assert-Case 'S8 S0 자리: 진행 읽기 → S0 호출 → 실패면 커스텀 끄고 return → 바뀌었으면 설정·진행 다시 읽기(못 읽으면 거부) → S1 지문 검사 if' ($s0Texts -join ' ¶ ') `
        ('$crProgress = $null ¶ if ($crNode.PSObject.Properties[''progress''] -and $crNode.progress) { $crProgress = $crNode.progress } ¶ $startAdvance = Invoke-AbyssStartJournalAdvance ¶ ' +
            'if (-not $startAdvance.Ok) { $script:customActive = $false return } ¶ ' +
            'if ($startAdvance.ConfigChanged) { $crCfg = Read-Config $crNode = $null if ($crCfg -and $crCfg.PSObject.Properties[$script:customConfigSection]) { $crNode = $crCfg.$script:customConfigSection } ' +
            'if (-not $crNode) { Add-GuiLog ''[오류] 설정 파일을 다시 읽지 못해 시작하지 않습니다 - 잠시 뒤 다시 시작해 주세요'' $script:customActive = $false return } $crProgress = $null ' +
            'if ($crNode.PSObject.Properties[''progress''] -and $crNode.progress) { $crProgress = $crNode.progress } } ¶ if ($crProgress) {')
    # S9 S3 자리(명세 2.9): 묘비 소비 if 바로 뒤 S3 판정 → 적용(실패면 커스텀 끄고 return) → 바깥 if(none 일 때만) 안에 마커 게이트 if 하나(조건식 원문 그대로) · 그 뒤는
    #    안전 중지 신호 제거 - 원문
    $tombstoneIf = $startStatements[$s3At - 1]
    $outerIf = $startStatements[$s3At + 2]
    $outerBody = @($outerIf.Clauses[0].Item2.Statements)
    $s3Shape = '{0} ¶ {1} ¶ {2} ¶ {3} · {4} · {5} ¶ {6} ¶ {7}' -f [int]$tombstoneIf.Extent.Text.StartsWith('if ($script:customActive -and (Test-CustomMarkerStale -Path $customMarkerFile))'),
        $startS3Statements[0].Extent.Text, $startS3Statements[1].Extent.Text, $outerIf.Clauses[0].Item1.Extent.Text, $outerBody.Count,
        $(if ($outerBody.Count -eq 1) { $outerBody[0].Clauses[0].Item1.Extent.Text } else { '' }), [int]($null -eq $outerIf.ElseClause), $startStatements[$s3At + 3].Extent.Text
    Assert-Case 'S9 S3 자리: 묘비 소비 if 뒤 · S3 판정 대입 → 적용 if → 바깥 if(none) 안 문장 = 마커 게이트 if 하나 · 바깥 if 의 else 없음 · 다음 문장 = 안전 중지 신호 제거' $s3Shape `
        ('1 ¶ $startJournal = Get-AbyssStartJournalAction ¶ if (-not (Invoke-AbyssStartJournalAction -Plan $startJournal)) { $script:customActive = $false; return } ¶ ' +
            '$startJournal.Action -eq ''none'' · 1 · $script:customActive -and -not $markerStaleBlocked -and (Test-Path -LiteralPath $customMarkerFile) ¶ 1 ¶ ' +
            'Remove-Item -LiteralPath $safeStopFlag -Force -ErrorAction SilentlyContinue')
    # S10 첫 기동(명세 2.9 '첫 기동') = 시작 처리의 마지막 문장: 재개 예약이면 -PreserveMarker -ResumeNonce 기동 뒤 예약 비움, 아니면 인자 없는 기동 - 원문(주석 뺌·공백 정규화)
    Assert-Case 'S10 첫 기동: if (재개 예약) { 재개 기동 → 예약 비움 } else { 기동 }' (((Remove-SourceComments -Text $firstLaunchStatement.Extent.Text) -replace '\s+', ' ').Trim()) `
        ('if ($script:customResumePending) { Start-NextCycle -PreserveMarker -ResumeNonce $script:customResumeNonce $script:customResumePending = $false ' +
            '$script:customResumeNonce = '''' } else { Start-NextCycle }')
    # S11 클로저(-Expect·-Mutator)는 $script: 를 읽지 않음 · try 마다 catch 1개(규칙 3 - 2개까지) · 정지(Stop-AllRun) 0 · throw 0 - 시작 게이트는 실행 전이라 거부만
    Assert-Case 'S11 S0: 클로저 1(applied) · 그 안 $script: 0 · try 1개 catch 1 · Stop-AllRun 0 · throw 0' (Get-FunctionFacts 'Invoke-AbyssStartJournalAdvance') 'closure 1 · script 0 · catch 1 · stop 0 · throw 0'
    Assert-Case 'S11 S3 판정: 클로저 0 · try 1개 catch 1 · Stop-AllRun 0 · throw 0' (Get-FunctionFacts 'Get-AbyssStartJournalAction') 'closure 0 · script 0 · catch 1 · stop 0 · throw 0'
    Assert-Case 'S11 S3 적용: 클로저 2(재개 횟수 -Expect·-Mutator) · 그 안 $script: 0 · try 1개 catch 1 · Stop-AllRun 0 · throw 0' (Get-FunctionFacts 'Invoke-AbyssStartJournalAction') `
        'closure 2 · script 0 · catch 1 · stop 0 · throw 0'
    Assert-Case 'S11 공용 읽기: try 1개 catch 1 · 거부 문구 함수: try 0' ('{0} / {1}' -f (Get-FunctionFacts 'Read-AbyssStartJournal'), (Get-FunctionFacts 'Get-AbyssStartJournalRefusal')) `
        'closure 0 · script 0 · catch 1 · stop 0 · throw 0 / closure 0 · script 0 · catch  · stop 0 · throw 0'
}

# ===== S 정적 =====
function Get-GuiCallOwners {
    # 그 명령을 부르는 곳(감싼 함수 이름, 함수 밖 = '(함수 밖)')을 '개수|이름,이름' 으로 - 서수 정렬 (test_time_until_mode 와 같은 구현)
    param([string]$Name)
    $calls = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq $Name) }, $true))
    [string[]]$owners = @($calls | ForEach-Object {
            $parent = $_.Parent
            $ownerName = '(함수 밖)'
            while ($null -ne $parent) {
                if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $ownerName = $parent.Name; break }
                $parent = $parent.Parent
            }
            $ownerName
        })
    [Array]::Sort($owners, [StringComparer]::Ordinal)
    return ('{0}|{1}' -f $calls.Count, ($owners -join ','))
}

function Get-AstOwnerName {
    # 노드를 감싼 함수 이름 (함수 밖 = '(함수 밖)')
    param($Node)
    $parent = $Node.Parent
    while ($null -ne $parent) {
        if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $parent.Name }
        $parent = $parent.Parent
    }
    return '(함수 밖)'
}

function Get-FunctionFacts {
    # 함수 하나의 정적 사실 - 클로저 수 · 클로저 안 $script: 수 · try 마다 catch 절 수 · Stop-AllRun 호출 수 · throw 문 수 (주석 뺀 사본 기준)
    param([string]$Name)
    $functionAst = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $Name) }, $true))[0]
    $closureCalls = @($functionAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -eq 'GetNewClosure') }, $true))
    $scriptReads = 0
    foreach ($closureCall in $closureCalls) { $scriptReads += [regex]::Matches((Remove-SourceComments -Text $closureCall.Expression.Extent.Text), '\$script:').Count }
    $catchCounts = (@($functionAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)) | ForEach-Object { $_.CatchClauses.Count }) -join ','
    $stopCalls = @($functionAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Stop-AllRun') }, $true)).Count
    $throws = @($functionAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)).Count
    return ('closure {0} · script {1} · catch {2} · stop {3} · throw {4}' -f $closureCalls.Count, $scriptReads, $catchCounts, $stopCalls, $throws)
}

function Test-CaseStatic {
    Assert-Case 'S1 Add-AbyssPendingEntry: 클로저 1(mutator) · 그 안 $script: 0 · try 1개 catch 1 · Stop-AllRun 0 · throw 0' (Get-FunctionFacts 'Add-AbyssPendingEntry') `
        'closure 1 · script 0 · catch 1 · stop 0 · throw 0'
    Assert-Case 'S1 Invoke-AbyssPendingAdvance: 클로저 2(expect·mutator) · 그 안 $script: 0 · try 1개 catch 1 · Stop-AllRun 0 · throw 0' (Get-FunctionFacts 'Invoke-AbyssPendingAdvance') `
        'closure 2 · script 0 · catch 1 · stop 0 · throw 0'
    Assert-Case 'S2 서명: Add-AbyssPendingEntry(세대는 형식 없이 - 빠뜨림이 0 으로 바뀌지 않게) · Invoke-AbyssPendingAdvance' `
        ('{0} / {1}' -f (Get-ParamSignature $guiAst 'Add-AbyssPendingEntry'), (Get-ParamSignature $guiAst 'Invoke-AbyssPendingAdvance')) `
        'String $Stage, Object $Owner, Object $Generation, String $Nonce / String $Caller'
    Assert-Case 'S3 실패 종류 낱말(설계 R2 3.6 + 대기열 확인): locked · corrupt · io-failed · expect-failed · 모르는 태그' `
        ((@('locked', 'corrupt', 'io-failed', 'expect-failed', 'other-tag') | ForEach-Object { Get-AbyssJournalTagText -Tag $_ }) -join ' / ') `
        '파일 사용 중 / 파일 손상 / 기록 실패 / 대기열이 바뀜 / other-tag'
    # S4 호출부 - 단계 2.5a 는 함수만(호출부 0)이었고, 단계 2.6 이 재입장 실행부(진행 저장 실패 → inside-handoff)·마무리 실행 완주(finish-only-complete →
    #    반영)를 더했습니다. 2.8(코드 1)은 호출부를 더하지 않습니다 - 코드 1 reentered 의 진행 저장 실패도 같은 실행부 호출이 단계만 code1-routed 로 적습니다(C2).
    #    2.9 가 시작 게이트 S0(Invoke-AbyssStartJournalAdvance)의 반영 -Caller start 를 더했습니다([SG] 행)
    Assert-Case 'S4 호출부(단계 2.9): 큐 기록 = 완주·실행부 · 큐 반영 = 완주·시작 게이트 S0' ('{0} / {1}' -f (Get-GuiCallOwners 'Add-AbyssPendingEntry'), (Get-GuiCallOwners 'Invoke-AbyssPendingAdvance')) `
        '2|Complete-FinishOnlyCycle,Invoke-InsideHandoffExit / 2|Complete-FinishOnlyCycle,Invoke-AbyssStartJournalAdvance'
    # S5 대기열 실패 태그 배선(단계 2.6 구현 리뷰): 최상위 선언 1곳(빈 값) · 두 함수의 첫 문장 = 비움 · 대입 = 선언 + 큐 기록 2(비움·저장 태그) + 큐 반영
    #    3(비움·읽기 태그·지우기 태그) · 읽는 곳 = 정지 사유 함수 하나 · 정지 사유 함수 호출 = 완주 2 + 실행부 1 + 시작 게이트 S0 1(2.9 - 대기열 반영
    #    실패로 시작을 거부하는 자리. 2.8 코드 1 은 대기열 실패로 멈추는 자리를 더하지 않음 - 실행부를 그대로 부름)
    $tagNodes = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.VariableExpressionAst]) -and ($node.VariablePath.UserPath -eq 'script:abyssPendingLastTag') }, $true))
    [string[]]$tagWriters = @($tagNodes | Where-Object { ($_.Parent -is [System.Management.Automation.Language.AssignmentStatementAst]) -and [object]::ReferenceEquals($_.Parent.Left, $_) } |
            ForEach-Object { Get-AstOwnerName $_ })
    [string[]]$tagReaders = @($tagNodes | Where-Object { -not (($_.Parent -is [System.Management.Automation.Language.AssignmentStatementAst]) -and [object]::ReferenceEquals($_.Parent.Left, $_)) } |
            ForEach-Object { Get-AstOwnerName $_ })
    [Array]::Sort($tagWriters, [StringComparer]::Ordinal)
    [Array]::Sort($tagReaders, [StringComparer]::Ordinal)
    $tagDeclarations = @($guiAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssPendingLastTag') } |
            ForEach-Object { $_.Right.Extent.Text })
    $firstStatements = foreach ($queueFunction in @('Add-AbyssPendingEntry', 'Invoke-AbyssPendingAdvance')) {
        $queueFunctionAst = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $queueFunction) }, $true))[0]
        @($queueFunctionAst.Body.EndBlock.Statements)[0].Extent.Text
    }
    Assert-Case 'S5 대기열 실패 태그: 최상위 선언 1(빈 값) · 두 함수 첫 문장 = 비움 · 대입 = 선언 + 큐 기록 2 + 큐 반영 3 · 읽는 곳 = 정지 사유 함수 · 정지 사유 호출 = 완주 2 + 실행부 1 + 시작 게이트 S0 1' `
        ('{0} · {1} · {2}|{3} · {4}|{5} · {6}' -f ($tagDeclarations -join ','), ($firstStatements -join ' / '), $tagWriters.Count, ($tagWriters -join ','), $tagReaders.Count,
            ($tagReaders -join ','), (Get-GuiCallOwners 'Get-AbyssPendingStopReason')) `
        ("'' · `$script:abyssPendingLastTag = '' / `$script:abyssPendingLastTag = '' · 6|(함수 밖),Add-AbyssPendingEntry,Add-AbyssPendingEntry,Invoke-AbyssPendingAdvance,Invoke-AbyssPendingAdvance,Invoke-AbyssPendingAdvance · " +
            '1|Get-AbyssPendingStopReason · 4|Complete-FinishOnlyCycle,Complete-FinishOnlyCycle,Invoke-AbyssStartJournalAdvance,Invoke-InsideHandoffExit')
}

# ===== 실행 =====
$caseFunctions = @('Test-CaseHarness', 'Test-CaseRecord', 'Test-CaseRecordReject', 'Test-CaseRecordStoreFail', 'Test-CaseAdvanceEmpty',
    'Test-CaseAdvanceOrder', 'Test-CaseAdvanceSkip', 'Test-CaseAdvanceStepFail', 'Test-CaseAdvanceRestart', 'Test-CaseAdvanceFail',
    'Test-CaseAdvanceHeadCheck', 'Test-CasePendingTag', 'Test-CaseHandoffExecution', 'Test-CaseHandoffQueueGuide', 'Test-CaseCode1Routing', 'Test-CaseCode1LegacySafeStop',
    'Test-CaseStartReadFailure', 'Test-CaseStartS3', 'Test-CaseStartS0', 'Test-CaseStartContinuation', 'Test-CaseStartStatic', 'Test-CaseStatic')
$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    foreach ($caseFunction in $caseFunctions) {
        try {
            & $caseFunction
        } catch {
            "FAIL {0}: 예외 {1} (줄 {2})" -f $caseFunction, $_.Exception.Message, $_.InvocationInfo.ScriptLineNumber
            $script:fails++
        }
    }
} finally {
    Unlock-TestFiles
    # 단계 2.6 행의 실제 기동이 바꾼 env 를 원래 값으로
    foreach ($envName in $WATCHED_ENV_NAMES) { [Environment]::SetEnvironmentVariable($envName, $originalWatchedEnv[$envName], 'Process') }
    try { [IO.Directory]::Delete($testRootFolder, $true) } catch { "참고: 임시 폴더 정리 실패 - $($_.Exception.Message)" }
}
'걸린 시간 {0:N1}초' -f ($totalWatch.ElapsedMilliseconds / 1000)
exit $fails
