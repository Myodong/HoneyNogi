# 어비스 완료 기록(handoff journal) 저장소 회귀 ㉑ - 구현 명세 ① 2.1·3.1 (2026-10-08 신설)
#
# 지키는 것: GUI(mabinogi_gui.ps1)와 워커(mabinogi_run_once.ps1)에 같은 본문으로 든 저장소 함수 묶음(Update-/Read-AbyssJournal
#   과 헬퍼)의 계약 - 원자 교체(File.Replace + .bak 직전본)·잠금(.lock DeleteOnClose)·교체 중간 상태와 손상 복구(분기 a~e)·
#   'corrupt'/'locked' fail-closed·반환 태그 6종·mutator/Expect 예외 전파·합산 재시도 예산(20회 × 50ms)·JSON 왕복·
#   UTF-8 BOM·Flush·두 사본 토큰 동일. 동작 케이스는 GUI 사본·워커 사본을 각각 같은 케이스로 돌립니다.
# 방법:
#   - 두 소스를 Parser 로 읽어 묶음을 잘라 냅니다. 경계 = 머리 주석 '어비스 완료 기록(handoff journal) 저장소' 뒤 첫 최상위
#     함수부터 '어비스 완료 기록 저장소 묶음 끝' 표지 주석 앞까지(두 표지는 소스마다 1개). 한쪽 사본 전용 journal 함수(단계 2.10
#     의 워커 기록 함수 등)는 끝 표지 뒤에 두면 이름과 무관하게 두 사본 비교(J14·J15)에서 빠집니다(명세 대조 P3-3 - 2026-10-08,
#     전에는 '이름에 AbyssJournal 이 없는 첫 함수' 가 끝이라 묶음 바로 뒤의 같은 이름 꼴 함수가 묶음으로 잡혔음).
#   - 사본마다 그 함수들을 이 파일 **최상위**에서 정의(Invoke-Expression)하고 케이스를 임시 폴더의 **실제 파일**로 돌립니다.
#     클로저 mutator 가 부르는 묶음 함수는 최상위 정의만 보입니다 - 함수 안 Invoke-Expression 이면 CommandNotFoundException
#     (구현 명세 ① 2.0 체크리스트 6). 같은 이유로 케이스 함수 안의 클로저는 그 함수의 지역 변수만 읽게 씁니다.
#   - 경합·Kill·동시 실행은 자식 powershell(실행 중 이 테스트가 UTF-8 BOM 으로 쓰는 스크립트 - 묶음도 최상위 점소싱)로 만듭니다.
#   - 예산 관측: 묶음의 재시도 대기는 Start-Sleep -Milliseconds 50 입니다. 이 파일은 Start-Sleep 을 같은 이름 함수로 가려
#     횟수를 세고 실제로도 잡니다(자식 프로세스와 실제로 겨루므로 가짜 시계를 쓰지 않음). 20회 예산 = 실패 20번 사이 대기 19번.
# 경합을 없애려고 정한 절차(명세 3.1 X8·J10 행이 이 절차로 맞춰져 있음 - 명세 대조 P3-4):
#   - X8: 본 파일은 부모가 저장 함수에서 돌아온 뒤 놓습니다('잠금 해제 600ms 뒤 600ms 더' 로 두면 묶음 예산 끝(실측 약 1.19초)과
#     1.2초가 겹쳐 결과가 흔들림). 합산 여부는 대기 횟수(19번 = 한 번의 예산)와 걸린 시간 ≤ 2초로 가립니다.
#   - J10-1: '약 300ms' 를 쓰는 쪽 임시 파일이 생긴 뒤부터 셉니다 - 교체가 적어도 한 번 막혔다가 풀리게.
#   - X5 의 HResult 고정은 J09(다른 프로세스 보유)·J20(같은 프로세스 보유)·X5(폴더 없음·.lock 자리가 폴더·교체 실패 두 종류)에서 봅니다.
# 변이 검증 생존 보강(2026-10-08 - 같은 계약을 다른 모양으로 깬 변이가 살아남은 자리): J19 (a) 상태 · X8 복구판(잠금 대기 +
#   Held 복구 재시도 합산) · X10(Held 복구 IO 실패 - 명세 5절 C3) · X11(본 파일 읽기 IO 실패는 손상이 아님 - 저장소를 여러 번
#   쓴 뒤 + 정적 catch 절 2개까지) · X9 정적 쓰기 자리. X11 은 같은 검증에서 찾은 구현 결함(catch 절 4개 → 컴파일 뒤 공유 위반이
#   '폴더 없음' 절로 감)을 고친 뒤 넣었습니다 - 고치기 전 코드에서는 FAIL 이 맞는 결과입니다. J19 폴더 없음은 그 고침으로 IOException
#   절 안의 -is 로 옮긴 갈래(임시 목록의 '폴더 없음' = 임시 파일 없음)를 지킵니다.
# 구현 리뷰 2.1 반영(2026-10-08): 읽기 (b) 는 유효 .bak ∧ .tmp seq = .bak + 1 일 때만 올리고, (d) 는 본 파일·.bak 이 둘 다 없으면
#   남은 .tmp(유효·무효)와 무관하게 빈 journal(Held 가 청소)입니다 - X2 기대를 corrupt → d 로 바꾸고 P1a(실패라고 알린 첫 저장의
#   임시본이 나중에 커밋되지 않음 - 자식이 임시본을 쥐는 경합)·P1b(유효 .tmp 단독 → d)를 더했습니다. (a) 의 .bak 읽기 실패·임시본
#   목록 실패는 판정에 쓰지 않고 경고만(P2a · P2a 정적), unchanged·expect-failed 의 '쓰기 0' 은 그 호출의 논리 변경 기준이고 재판독의
#   복구 쓰기는 별개(P2b). (b) 를 쓰는 기존 케이스(J04·J05·J16~J20·X10)는 셋업에 이미 유효 .bak 이 있어 기대가 그대로입니다.
# 구현 리뷰 2.1 확인 라운드(2026-10-08): 저장 io-failed 직전 임시본이 남았는지를 File.Exists 가 아니라 잡힌 삭제 예외로 가립니다 -
#   P1a 가 공유 위반(IOException) 갈래, P1c 가 접근 거부(UnauthorizedAccessException - 자식이 임시본에 읽기 전용 속성) 갈래입니다.
#   두 픽스처 모두 남은 임시본에 File.Exists 가 참이라 예전 판정(조용한 삭제 뒤 File.Exists)으로 되돌려도 통과합니다 - File.Exists 가
#   접근 오류로 거짓을 주는 상태 자체는 재현하지 않았습니다(변이 검증 2026-10-08).
# 단계 2.10(2026-10-09 - 구현 명세 ① 2.10 W3·W4 · 3.1 X4): 워커 전용 함수 Add-AbyssJournalClearedEntry(클리어 완료 기록)·ConvertTo-AbyssJournalOwner
#   (GUI 소유자 JSON → owner·세대)는 묶음 끝 표지 뒤에 있어 두 사본 비교(J14·J15) 밖입니다(정적 W-ONLY - 워커에만 · 표지 뒤 · 기록 함수는 예외를
#   감싸지 않고 mutator 는 클로저 · 그 안 $script:·명령 0). X4 는 워커 사본 묶음 위에서 그 기록 함수를 실제 파일로 돌려 항목 필드 전부(owner·
#   generation·section·decision·launchState·afterEntry·at)와 로그 줄(성공 1 · 실패 [경고] 1 - 낱말은 설계 R2 3.6 · 소유자 JSON 해석 실패 [경고] 1)·
#   예외 전파를 봅니다. Write-RunLog 는 줄을 모으는 모의이고, 기록 함수가 이름 그대로 읽는 스크립트 수준 $abyssJournalPath 를 케이스 경로로 둡니다.
#   단계 2.10 구현 검증(2026-10-10 - 생존 변이 보강): W-ONLY ④ 두 함수 안 exit 문 0(같은 프로세스 동작 행이 단언 없이 끝나지 않게 - 동작보다 먼저) ·
#   X4 전 호출의 앞뒤 워커 상태 비교(스크립트 변수 이름 집합 + 정리 전용 등 본류가 기록 뒤에 읽는 값 - 저장 실패가 종료 코드를 바꾸지 않음) ·
#   X4-h 워커 단독 실행(RUN_ID 없음 → 실행 id 읽기 원문 문장 그대로 → 빈 값 그대로 기록).
#   그 반영의 검토(2026-10-10): X4-h 정적 ①② - 워커 전체(모든 깊이)에서 실행 id 변수 대입 = 스크립트 최상위 W2 하나 · RUN_ID env 대입 0(W2 는 두고
#   그 앞뒤에 더한 빈 값 분기가 W2 문장 하나만 돌리는 X4-h 를 통과하던 것 - 정적이라 동작보다 먼저).
# 구현 명세 ② 2.1(2026-10-12 - 3.3 ㉑ W-ONLY 표): 워커 전용 목록에 이어받기 시작 함수 Consume-Handoff(시작 때 journal 1회 읽기 → 역할)를 더했습니다 -
#   자리(워커 1 · 표지 뒤 · GUI 0)·exit 0 은 기존 W-ONLY 단언이 함께 보고, 모양은 try 0(예외 비포장 - 설계 R2-5) · 잠금 읽기 1 · 저장 0(쓰기 0) 입니다(W-ONLY ⑤).
#   동작 행은 test_abyss_handoff_start(⑱′) CH·L 입니다. X4 는 자기가 돌리는 두 함수(소유자 해석 · 클리어 기록)만 갖춰지면 돕니다 - ② 의 뒤 단계가 이 목록에
#   함수를 더해도 X4 가 그 함수의 유무에 묶이지 않게(빠진 함수는 W-ONLY 자리 단언이 FAIL 로 드러냄).
# 구현 명세 ② 2.2·2.3(2026-10-13 - 3.3 ㉑ W-ONLY 표 · 3.4): 워커 전용 목록에 자기 항목 생성 Add-AbyssJournalEnteredEntry · 입장 직후 키 인덱스 기록
#   Set-AbyssAfterEntryIndex · 코드 10 출구의 열쇠 닫기 Close-AbyssKeyEntryOnLeave 를 더했습니다 - 자리·exit 0 은 기존 W-ONLY 단언이 함께 보고, 모양(W-ONLY ⑥)은
#   명세 표의 칸만 함수마다 봅니다(생성: try 0 · 저장 1 · 클로저 1 · 그 안 $script: 0 · 그 안 명령 = 소유자 대조만 / 인덱스: try 0 · 저장 1 · 클로저 2 · 그 안
#   $script:·명령 0 / 닫기: try·trap·throw 0 · 저장 1 · 클로저 1 · 그 안 $script: 0 · 그 안 명령 = 필드 쓰기만). W-ONLY ⑦ 은 mutator 변경 표식
#   ($change.Changed = $true - 저장 계약은 표식이 선 저장만 쓰고 없으면 unchanged, 명세 2.0-10)의 자리입니다: 덧붙이는 둘(클리어 기록 · 생성)은 클로저 최상위
#   마지막 문장이고 바로 앞 = entries 덧붙임, 항목을 찾아 고치는 둘(인덱스 · 닫기)은 foreach 안 그 갈래의 마지막 문장이고 바로 앞 = index 대입 / 필드 쓰기 명령,
#   무변경 갈래에는 두지 않습니다(닫기의 무변경 갈래는 continue 뿐). own 던전 밖 시작의 기존 항목 닫기는 아래 2.5 문단입니다.
#   X4-i~l 은 클리어 기록의 열쇠 항목 닫기입니다(명세 2.2 · J4 - 같은 저장에서 열쇠 항목 done + applied: 있음 / 없음 / 이미 done / 항목 없음).
# 구현 명세 ② 2.5(2026-10-13 - 3.3 ㉑ W-ONLY 표): 워커 전용 목록에 own 던전 밖 시작의 기존 항목 닫기 Close-AbyssOwnEntryBeforeEntry(이어받기 시작 선분기가
#   필드 확정·패널류 첫 표본에서 받은 own 항목을 abandoned-pre-entry-start 로 닫음)를 더했습니다 - 자리·exit 0 은 기존 W-ONLY 단언이 함께 보고, 모양(W-ONLY ⑧)은
#   표의 칸(try 0 · 저장 1 · 클로저 2(Expect·Mutator) · 그 안 $script: 0 · 그 안 명령 = 필드 쓰기만), 변경 표식(⑦)은 열쇠 닫기와 같은 모양(Mutator 에만 1 -
#   찾은 항목 갈래 안 마지막 · 바로 앞 = 필드 쓰기 명령 · Expect 0 · Mutator 의 무변경 갈래는 continue 뿐)입니다. 동작 행은 test_abyss_handoff_start O·N 과
#   test_after_entry_at_most_once OK3~OK5·R2-E4 입니다.
# 구현 명세 ⑤b2(2026-10-23 - 3.3·3.4): 클리어 기록이 -Decision·-NextOwner 를 받고 @{ Tag; Nonce } 를 돌려줘 X4 의 출력 단언이 0 → 1(+ 반환 글자 X4-a·d·e)로
#   바뀌었습니다. 워커 전용 목록에 '다시 하기' 단계 기록 셋(Set-AbyssJournalRetryAttempt · RetryClicked · Reentered)을 더했습니다 - 자리·exit 0 은 기존 W-ONLY
#   단언이 함께 보고, 모양(W-ONLY ⑨)은 표의 칸(try·trap·throw 0 · 저장 1 · 클로저 2(Expect·Mutator) · 그 안 $script: 0 · 그 안 명령 = 필드 쓰기만 · Mutator 의
#   무변경 갈래는 continue 뿐), 변경 표식(⑦)은 own 닫기와 같은 모양입니다. X12~X14 는 셋을 실제 파일로 봅니다(바뀜 + JSON 대조 · 막힘(다른 nonce 의 허용 단계
#   항목 동반) · 저장 실패 3종 · 복구 경고 전달 · 출력 개수 - 바뀜 행은 대상 항목을 가운데 둠). X15 는 클리어 기록의 결정·다음 판 owner·반환과 원 워커 사슬
#   (cleared → retry-attempt → retry-clicked → reentered)입니다.
# J14 토큰 비교: 주석 토큰만 빼고 줄바꿈(NewLine) 토큰과 문자열 원문은 그대로 비교합니다(명세 리뷰 1·확인 라운드). 주석만 있는
#   줄도 줄바꿈 토큰은 남으므로 두 사본은 주석까지 같은 글자로 유지합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')   # Remove-SourceComments (J15 주석 뺀 사본)

# ===== 상수 =====
$BUNDLE_HEADER_FRAGMENT = '어비스 완료 기록(handoff journal) 저장소'   # 묶음 머리 주석 - 두 사본 같은 글자
$BUNDLE_END_FRAGMENT = '어비스 완료 기록 저장소 묶음 끝'                 # 묶음 끝 표지 주석 - 두 사본 같은 글자
# 명세 2.1 함수 표의 공개 4개 + 제안 헬퍼 7개 - 경계 판정이 묶음을 잘라 먹지 않았는지 확인용
$REQUIRED_FUNCTION_NAMES = @(
    'Update-AbyssJournal', 'Read-AbyssJournal', 'Read-AbyssJournalHeld', 'Read-AbyssJournalUnlocked',
    'Open-AbyssJournalLock', 'New-AbyssJournalEmpty', 'ConvertTo-AbyssJournalNormalized', 'ConvertTo-AbyssJournalText',
    'New-AbyssJournalEntry', 'Get-AbyssJournalStageRank', 'Test-AbyssJournalOwnerMatch')
$BUDGET_SLEEP_COUNT = 19      # 예산 20회 = 실패 20번 사이 대기 19번(마지막 실패 뒤에는 쉬지 않고 태그를 돌려줌)
$BUDGET_SLEEP_MS = 50
# J15 '바깥 변수 0' 에서 정의 없이 써도 되는 자동 변수
$AUTOMATIC_VARIABLE_NAMES = @('_', 'PSItem', 'null', 'true', 'false', 'PID', 'args', 'input', 'this', 'Matches')
$WARNING_TEMP_COMPLETE = '[경고] 완료 기록 교체 중 종료 - 임시본으로 완료'   # 명세 2.1 읽기 규칙 (b) 원문
$WARNING_BAK_RESTORE = '[경고] 완료 기록 파일 손상 - 직전본으로 복구'        # 명세 2.1 읽기 규칙 (c) 원문
# 구현 리뷰 2.1 에서 생긴 경고 - 문구 전체가 아니라 판별 조각으로 셉니다(뒤의 설명 괄호가 바뀌어도 같은 경고로 보게)
$WARNING_TEMP_DELETE_FRAGMENT = '임시본을 지우지 못했습니다'         # 저장 io-failed 직전 임시본 삭제 실패(P1a 공유 위반 · P1c 접근 거부)
$WARNING_BAK_UNREADABLE_FRAGMENT = '직전본을 읽지 못했습니다'        # (a) 의 .bak 읽기 IO 실패(P2a)
$WARNING_TEMP_LIST_FRAGMENT = '임시본 목록을 읽지 못했습니다'        # (a) 의 임시본 목록 읽기 실패(P2a 정적)
# 단계 2.10 워커 전용 함수(묶음 끝 표지 뒤)와 그 로그 문구(구현 명세 ① 2.10 W3 - 실패 낱말은 설계 R2 3.6: locked 파일 사용 중 / corrupt 파일 손상 /
# io-failed 기록 실패). 성공 줄은 GUI 가 화면에서 숨기는 글자와 같아야 합니다(test_log_tail_offset W7 가 소스에서 잡아 대조)
# 구현 명세 ② 2.1: 이어받기 시작 함수 Consume-Handoff 를 더함(3.3 ㉑ 표 - 표지 뒤 · GUI 0 · try 0 · 잠금 읽기 1 · 저장 0 · exit 0). ② 의 뒤 단계가 함수를 더합니다
# 구현 명세 ② 2.2·2.3: 자기 항목 생성 · 키 인덱스 기록 · 코드 10 출구의 열쇠 닫기를 더함(3.3 ㉑ 표 - 모양 W-ONLY ⑥ · 변경 표식 ⑦)
# 구현 명세 ② 2.5: own 던전 밖 시작의 기존 항목 닫기를 더함(3.3 ㉑ 표 - 모양 W-ONLY ⑧ · 변경 표식 ⑦)
# 구현 명세 ⑤b2: '다시 하기' 단계 기록 셋을 더함(3.4 ㉑ W-ONLY - 모양 W-ONLY ⑨ · 변경 표식 ⑦)
$WORKER_ONLY_FUNCTION_NAMES = @('ConvertTo-AbyssJournalOwner', 'Add-AbyssJournalClearedEntry', 'Consume-Handoff',
    'Add-AbyssJournalEnteredEntry', 'Set-AbyssAfterEntryIndex', 'Close-AbyssKeyEntryOnLeave', 'Close-AbyssOwnEntryBeforeEntry',
    'Set-AbyssJournalRetryAttempt', 'Set-AbyssJournalRetryClicked', 'Set-AbyssJournalReentered')
# X4(클리어 기록 동작)가 실제로 돌리는 워커 전용 함수 - 이 둘이 있으면 X4 를 돌립니다
$X4_FUNCTION_NAMES = @('ConvertTo-AbyssJournalOwner', 'Add-AbyssJournalClearedEntry')
$CLEARED_SUCCESS_LINE = '[어비스] 클리어 완료 기록 저장 (결과 화면 도달)'
$CLEARED_OWNER_WARNING = '[경고] 커스텀 항목 소유자 정보를 읽지 못해 클리어 완료 기록을 남기지 않습니다 - GUI/워커 버전을 확인해 주세요'
$CLEARED_FAIL_FORMAT = '[경고] 클리어 완료 기록을 저장하지 못했습니다 ({0}) - 정상 종료면 GUI가 종료 코드로 계상하므로 진행을 계속합니다'
$INJECTED_STORE_THROW = '주입: 저장 함수 예외'
# 구현 명세 ⑤b2: '다시 하기' 단계 기록 셋(묶음 끝 표지 뒤 워커 전용)과 그 실패 줄(설계 R2 3.6 낱말 - 클릭·재입장 완료 기록만 줄을 남기고 retry-attempt 실패 줄은 부르는 쪽 몫)
$RETRY_CLICKED_FAIL_FORMAT = '[경고] 재입장 클릭 기록을 저장하지 못했습니다 ({0}) - 재입장 확인을 계속합니다'
$REENTERED_FAIL_FORMAT = '[경고] 재입장 완료 기록을 저장하지 못했습니다 ({0}) - 재입장 완료 줄을 남기고 이어 갑니다'
$STAGE_WRITER_NAMES = @('Set-AbyssJournalRetryAttempt', 'Set-AbyssJournalRetryClicked', 'Set-AbyssJournalReentered')

# 자식 프로세스 스크립트 - 실행할 때마다 임시 폴더에 UTF-8 BOM 으로 씁니다(한글 문구가 있어 BOM 없으면 5.1 이 cp949 로 읽음)
$CHILD_SCRIPT_TEXT = @'
param(
    [string]$Mode,
    [string]$Name,
    [string]$BundlePath,
    [string]$MainPath,
    [string]$SignalDir,
    [int]$Count = 0,
    [int]$HoldAfterTempMs = 0,
    [int]$LockHoldMs = 0,
    [string]$CompleteTemp = '',
    [switch]$Barrier
)
# test_abyss_journal_store 의 자식 프로세스 - 부모 테스트가 실행할 때마다 새로 씁니다.
# 묶음(부모가 소스에서 잘라 낸 사본 하나)은 이 파일 **최상위**에서 점소싱합니다 - 클로저 mutator 가 부르는 묶음 함수는
# 최상위 정의만 보입니다(구현 명세 ① 2.0 체크리스트 6).
$ErrorActionPreference = 'Stop'
$signalBase = Join-Path $SignalDir $Name
$resultLines = New-Object System.Collections.Generic.List[string]
trap {
    # 예상 밖 실패도 결과 파일로 남겨 부모 단언에 보이게 합니다(숨김 창이라 콘솔 출력은 볼 수 없음)
    $resultLines.Add('ERROR=' + $_.Exception.Message)
    [IO.File]::WriteAllLines(($signalBase + '.result'), $resultLines.ToArray(), (New-Object System.Text.UTF8Encoding($true)))
    exit 9
}
. $BundlePath
$script:abyssJournalSavedBy = "child:$PID"

function Send-Signal {
    param([string]$Suffix)
    [IO.File]::WriteAllText(($signalBase + '.' + $Suffix), 'ok')
}

function Wait-Signal {
    # 부모 신호 파일을 기다립니다 - 60초 상한(부모가 먼저 끝나도 자식이 남지 않게)
    param([string]$Suffix)
    $signalPath = $signalBase + '.' + $Suffix
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not [IO.File]::Exists($signalPath)) {
        if ($watch.ElapsedMilliseconds -gt 60000) { throw ('신호 대기 시간 초과: ' + $Suffix) }
        [System.Threading.Thread]::Sleep(10)
    }
}

if ($Mode -eq 'lock') {
    # 묶음의 잠금 함수로 .lock 을 쥡니다 - DeleteOnClose 까지 운영과 같은 코드(J08·J17 Kill)
    $lock = Open-AbyssJournalLock -Path $MainPath -Budget @{ Left = 20 }
    if ($null -eq $lock.Stream) { throw ('잠금 획득 실패: ' + $lock.Tag) }
    Send-Signal 'ready'
    Wait-Signal 'release'
    if ($CompleteTemp) {
        # 쓰는 쪽 재개(J16) - File.Replace 의 두 번째 이름 바꾸기(임시 → 본 파일)를 마칩니다
        [IO.File]::Move($CompleteTemp, $MainPath)
    }
    $lock.Stream.Dispose()
    $resultLines.Add('DONE=1')
} elseif ($Mode -eq 'hold-main') {
    # 본 파일을 FileShare.Read 로 쥠 - 삭제 공유가 없어 쓰는 쪽 File.Replace 가 IOException(J10·X5)
    $stream = [IO.File]::Open($MainPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    Send-Signal 'ready'
    if ($HoldAfterTempMs -gt 0) {
        # 쓰는 쪽 임시 파일이 생길 때까지(= 교체 직전) 기다렸다가 HoldAfterTempMs 더 쥠 - 교체가 적어도 한 번 막힘(J10-1).
        # 저장이 교체 전에 끝나 버리면(임시 파일이 잠깐만 있었던 경우) 부모가 release 를 보내므로 그 신호에도 멈춥니다.
        $folder = [IO.Path]::GetDirectoryName($MainPath)
        $pattern = '.' + [IO.Path]::GetFileName($MainPath) + '.*.tmp'
        $sawTemp = $true
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        while (@([IO.Directory]::GetFiles($folder, $pattern)).Count -eq 0) {
            if ([IO.File]::Exists($signalBase + '.release')) { $sawTemp = $false; break }
            if ($watch.ElapsedMilliseconds -gt 30000) { throw '쓰는 쪽 임시 파일 대기 시간 초과' }
            [System.Threading.Thread]::Sleep(5)
        }
        $resultLines.Add('SAW_TEMP=' + [int]$sawTemp)
        if ($sawTemp) { [System.Threading.Thread]::Sleep($HoldAfterTempMs) }
    } else {
        Wait-Signal 'release'
    }
    $stream.Dispose()
    $resultLines.Add('DONE=1')
} elseif ($Mode -eq 'lock-then-main') {
    # X8 순서 고정 - 잠금을 쥔 채 본 파일을 먼저 FileShare.Read 로 열고 신호 → LockHoldMs 뒤 잠금만 놓음 → 부모 신호에 본 파일
    $lock = Open-AbyssJournalLock -Path $MainPath -Budget @{ Left = 20 }
    if ($null -eq $lock.Stream) { throw ('잠금 획득 실패: ' + $lock.Tag) }
    $stream = [IO.File]::Open($MainPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    Send-Signal 'ready'
    [System.Threading.Thread]::Sleep($LockHoldMs)
    $lock.Stream.Dispose()
    $resultLines.Add('LOCK_RELEASED=' + [DateTime]::UtcNow.Ticks)
    Wait-Signal 'release'
    $stream.Dispose()
    $resultLines.Add('DONE=1')
} elseif ($Mode -eq 'hold-new-temp') {
    # P1a - 쓰는 쪽(부모 저장 함수)이 새로 만든 임시 파일을 Delete 공유 없이(FileShare.Read) 쥡니다. 임시 파일 이름(pid·guid)은 미리
    # 알 수 없어 생길 때까지 폴더를 훑고, 쓰는 쪽이 아직 쓰는 중(FileShare.None)이면 열릴 때까지 다시 시도합니다. 쥐었으면 'held'
    # 신호 → 부모 release 신호에 놓습니다. 끝내 못 쥔 채 release 가 오면(쓰는 쪽이 먼저 지움) SAW_TEMP=0 으로 끝냅니다.
    $folder = [IO.Path]::GetDirectoryName($MainPath)
    $pattern = '.' + [IO.Path]::GetFileName($MainPath) + '.*.tmp'
    Send-Signal 'ready'
    $stream = $null
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($null -eq $stream) {
        if ([IO.File]::Exists($signalBase + '.release')) { break }
        if ($watch.ElapsedMilliseconds -gt 30000) { throw '쓰는 쪽 임시 파일 대기 시간 초과' }
        foreach ($candidatePath in @([IO.Directory]::GetFiles($folder, $pattern))) {
            try {
                $stream = [IO.File]::Open($candidatePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
                $resultLines.Add('HELD=' + [IO.Path]::GetFileName($candidatePath))
                break
            } catch [System.IO.IOException] {
                # 쓰는 중(공유 위반)이거나 그사이 사라짐 - 다시 훑습니다
            } catch [System.UnauthorizedAccessException] {
            }
        }
        if ($null -eq $stream) { [System.Threading.Thread]::Sleep(2) }
    }
    $resultLines.Add('SAW_TEMP=' + [int]($null -ne $stream))
    if ($null -ne $stream) {
        Send-Signal 'held'
        Wait-Signal 'release'
        $stream.Dispose()
    }
    $resultLines.Add('DONE=1')
} elseif ($Mode -eq 'readonly-new-temp') {
    # P1c - 쓰는 쪽(부모 저장 함수)이 새로 만든 임시 파일에 읽기 전용 속성만 겁니다(쥐지 않음 - 삭제가 공유 위반이 아니라 접근 거부로
    # 실패하게). 속성 변경은 공유 모드를 보지 않아 쓰는 쪽이 아직 FileShare.None 으로 쓰는 중이어도 걸리고, 이미 열린 쓰기 핸들은
    # 그대로 씁니다(2026-10-08 실측). 이름(pid·guid)은 미리 알 수 없어 생길 때까지 폴더를 훑습니다. 걸었으면 'marked' 신호 뒤
    # 끝냅니다. 못 건 채 release 가 오면(쓰는 쪽이 먼저 지움) SAW_TEMP=0 으로 끝냅니다.
    $folder = [IO.Path]::GetDirectoryName($MainPath)
    $pattern = '.' + [IO.Path]::GetFileName($MainPath) + '.*.tmp'
    Send-Signal 'ready'
    $markedName = ''
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $markedName) {
        if ([IO.File]::Exists($signalBase + '.release')) { break }
        if ($watch.ElapsedMilliseconds -gt 30000) { throw '쓰는 쪽 임시 파일 대기 시간 초과' }
        foreach ($candidatePath in @([IO.Directory]::GetFiles($folder, $pattern))) {
            try {
                [IO.File]::SetAttributes($candidatePath, ([IO.File]::GetAttributes($candidatePath) -bor [IO.FileAttributes]::ReadOnly))
                $markedName = [IO.Path]::GetFileName($candidatePath)
                break
            } catch [System.IO.IOException] {
                # 그사이 사라짐 - 다시 훑습니다
            } catch [System.UnauthorizedAccessException] {
            }
        }
        if (-not $markedName) { [System.Threading.Thread]::Sleep(2) }
    }
    $resultLines.Add('MARKED=' + $markedName)
    $resultLines.Add('SAW_TEMP=' + [int]($markedName -ne ''))
    if ($markedName) { Send-Signal 'marked' }
    $resultLines.Add('DONE=1')
} elseif ($Mode -eq 'update-loop') {
    # J06 - 출발 신호 뒤 항목 Count 건을 하나씩 저장(reason = 이름-번호). mutator 는 클로저(체크리스트 6)
    Send-Signal 'ready'
    Wait-Signal 'go'
    for ($index = 1; $index -le $Count; $index++) {
        $entryReason = '{0}-{1}' -f $Name, $index
        $mutator = { param($journal, $change)
            $entry = New-AbyssJournalEntry -Stage 'cleared'
            $entry.reason = $entryReason
            $journal.entries = @($journal.entries) + $entry
            $change.Changed = $true
        }.GetNewClosure()
        $outcome = Update-AbyssJournal -Path $MainPath -Mutator $mutator
        $resultLines.Add('TAG=' + $outcome.Tag)
    }
} elseif ($Mode -eq 'wrapper') {
    # J16~J18 - 잠금 래퍼 1회(Barrier 면 출발 신호에 맞춰 다른 래퍼와 동시에)
    Send-Signal 'ready'
    if ($Barrier) { Wait-Signal 'go' }
    $read = Read-AbyssJournal -Path $MainPath
    $resultLines.Add('STATUS=' + $read.Status)
    $resultLines.Add('BRANCH=' + $read.Branch)
    $resultLines.Add('WARN=' + @($read.Warnings).Count)
    foreach ($warning in @($read.Warnings)) { $resultLines.Add('WARNING=' + $warning) }
} else {
    throw ('모르는 모드: ' + $Mode)
}
[IO.File]::WriteAllLines(($signalBase + '.result'), $resultLines.ToArray(), (New-Object System.Text.UTF8Encoding($true)))
exit 0
'@

# ===== 공통 단언·관측 =====

function Assert-Case {
    param([string]$Name, $Actual, $Expect)
    if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
    else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Get-ErrorText {
    # 예외 개체 → 메시지(없으면 빈 문자열) - 'throw 0' 을 한 칸으로 단언하기 위함
    param($ErrorObject)
    if ($null -eq $ErrorObject) { return '' }
    return [string]$ErrorObject.Message
}

function Get-TypeNameText {
    # 값의 형식 이름(null 이면 'null') - 왕복 형식 단언이 null 에서 예외로 멈춰 같은 케이스의 뒤 단언을 잃지 않게
    param($Value)
    if ($null -eq $Value) { return 'null' }
    return $Value.GetType().Name
}

$script:sleepSpyCount = 0
$script:sleepSpyMilliseconds = 0
function Start-Sleep {
    # 예산 관측용 가림 함수(이 저장소 테스트 관례) - 묶음의 재시도 대기를 세고, 자식 프로세스와 실제로 겨루므로 실제로도 잡니다
    param([int]$Seconds = 0, [int]$Milliseconds = 0)
    $waitMilliseconds = $Milliseconds + ($Seconds * 1000)
    $script:sleepSpyCount++
    $script:sleepSpyMilliseconds += $waitMilliseconds
    Microsoft.PowerShell.Utility\Start-Sleep -Milliseconds $waitMilliseconds
}

function Measure-JournalCall {
    # 저장소 호출 1회 → @{ Result; Error; Sleeps; SleepMs; ElapsedMs }. 예외도 값으로 돌려줘 같은 케이스의 단언이 이어집니다.
    # 지역 변수 이름은 measure 접두 - 넘겨받은 블록은 동적 스코프로 호출부 변수를 읽으므로 같은 이름으로 가리지 않게.
    param([scriptblock]$Call)
    $script:sleepSpyCount = 0
    $script:sleepSpyMilliseconds = 0
    $measureWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $measureResult = $null
    $measureError = $null
    try {
        $measureResult = & $Call
    } catch {
        $measureError = $_.Exception
    }
    return @{
        Result    = $measureResult
        Error     = $measureError
        Sleeps    = $script:sleepSpyCount
        SleepMs   = $script:sleepSpyMilliseconds
        ElapsedMs = [long]$measureWatch.ElapsedMilliseconds
    }
}

function Format-ExceptionKind {
    # 예외 → '형식/0xHResult'. New-Object 처럼 MethodInvocationException 에 감싸여 오면 안쪽 IOException·UnauthorizedAccessException
    # 까지 풉니다(체크리스트 10 - 묶음도 같은 규칙으로 HResult 를 읽음).
    param($Exception)
    $current = $Exception
    while ($null -ne $current.InnerException -and
        -not ($current -is [System.IO.IOException] -or $current -is [System.UnauthorizedAccessException])) {
        $current = $current.InnerException
    }
    return ('{0}/0x{1:X8}' -f $current.GetType().Name, $current.HResult)
}

function Get-CreateNewFailure {
    # 저장 계약 ① 과 같은 모양(CreateNew + FileShare.None + DeleteOnClose)으로 .lock 을 열어 보고 실패 예외를 돌려줍니다(X5 고정용)
    param([string]$LockPath)
    try {
        $probeStream = New-Object System.IO.FileStream($LockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)
        $probeStream.Dispose()
        return 'success'
    } catch {
        return (Format-ExceptionKind $_.Exception)
    }
}

function Get-ReplaceFailureKind {
    # File.Replace 실패의 예외 형식·HResult 를 따로 만든 대상 파일로 실측합니다(X5 분류 고정 - 픽스처를 건드리지 않게 별도 파일).
    # Mode 'held' = 대상을 FileShare.Read 로 쥠(삭제 공유 없음) / 'read-only' = 대상에 읽기 전용 속성
    param([string]$Folder, [string]$Mode)
    $target = Join-Path $Folder ('replace_probe_' + $Mode + '.json')
    $source = $target + '.new'
    $backup = $target + '.old'
    [IO.File]::WriteAllText($target, 'target')
    [IO.File]::WriteAllText($source, 'source')
    $holder = $null
    try {
        if ($Mode -eq 'held') {
            $holder = [IO.File]::Open($target, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        } else {
            [IO.File]::SetAttributes($target, [IO.FileAttributes]::ReadOnly)
        }
        try {
            [IO.File]::Replace($source, $target, $backup, $true)
            return 'success'
        } catch {
            return (Format-ExceptionKind $_.Exception)
        }
    } finally {
        if ($null -ne $holder) { $holder.Dispose() }
        foreach ($leftover in @($target, $source, $backup)) {
            if ([IO.File]::Exists($leftover)) {
                [IO.File]::SetAttributes($leftover, [IO.FileAttributes]::Normal)
                [IO.File]::Delete($leftover)
            }
        }
    }
}

# ===== 묶음 추출·토큰 비교 =====

function Get-TokenSequence {
    # 토큰 배열(시작 위치 순)의 [StartOffset, EndOffset) 안에서 주석·입력 끝을 뺀 'Kind<탭>Text' 열.
    # 토큰 사이 공백·탭은 토큰이 아니라 자연히 빠지고, NewLine 토큰과 문자열·here-string 토큰 원문은 그대로 남습니다.
    param($Tokens, [int]$StartOffset, [int]$EndOffset)
    $low = 0
    $high = $Tokens.Count
    while ($low -lt $high) {
        # 이진 탐색 - 큰 소스(워커 1.9만 줄)에서 함수마다 처음부터 훑지 않게
        $middle = [int][Math]::Floor(($low + $high) / 2)
        if ($Tokens[$middle].Extent.StartOffset -lt $StartOffset) { $low = $middle + 1 } else { $high = $middle }
    }
    $sequence = New-Object System.Collections.Generic.List[string]
    for ($index = $low; $index -lt $Tokens.Count; $index++) {
        $token = $Tokens[$index]
        if ($token.Extent.EndOffset -gt $EndOffset) { break }
        if ($token.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment) { continue }
        if ($token.Kind -eq [System.Management.Automation.Language.TokenKind]::EndOfInput) { continue }
        $sequence.Add(([string]$token.Kind) + "`t" + $token.Text)
    }
    return $sequence.ToArray()
}

function Get-TextTokenSequence {
    # 함수 원문 하나를 따로 파싱한 토큰 열(J14 비교기 대조용 - 같은 규칙)
    param([string]$Text)
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$parseErrors)
    return (Get-TokenSequence -Tokens $tokens -StartOffset 0 -EndOffset $Text.Length)
}

function Get-FirstDifference {
    # 두 토큰 열의 첫 차이 위치(같으면 -1). 대소문자까지 비교합니다('locked' 와 'Locked' 는 다른 값).
    param([string[]]$Left, [string[]]$Right)
    $leftCount = @($Left).Count
    $rightCount = @($Right).Count
    $count = [Math]::Min($leftCount, $rightCount)
    for ($index = 0; $index -lt $count; $index++) {
        if ($Left[$index] -cne $Right[$index]) { return $index }
    }
    if ($leftCount -ne $rightCount) { return $count }
    return -1
}

function Get-JournalBundle {
    # 소스 하나에서 저장소 묶음을 잘라 냅니다 → @{ Path; Names(소스 순서); Texts(이름 → 함수 원문); Tokens(이름 → 비주석 토큰 열);
    #   Functions(이름 → 함수 AST) }. 경계는 파일 머리 주석 참고.
    param([string]$SourcePath)
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($SourcePath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw ('소스 파서 오류({0}): {1}' -f $SourcePath, $parseErrors[0].Message) }
    $headers = New-Object System.Collections.Generic.List[object]
    $endMarkers = New-Object System.Collections.Generic.List[object]
    foreach ($token in $tokens) {
        if ($token.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment) { continue }
        if ($token.Text.Contains($BUNDLE_HEADER_FRAGMENT)) { $headers.Add($token) }
        if ($token.Text.Contains($BUNDLE_END_FRAGMENT)) { $endMarkers.Add($token) }
    }
    if ($headers.Count -ne 1) { throw ('묶음 머리 주석이 {0}개입니다(1개여야 함): {1}' -f $headers.Count, $SourcePath) }
    if ($endMarkers.Count -ne 1) { throw ('묶음 끝 표지 주석이 {0}개입니다(1개여야 함): {1}' -f $endMarkers.Count, $SourcePath) }
    $headerOffset = $headers[0].Extent.StartOffset
    $endOffset = $endMarkers[0].Extent.StartOffset
    if ($endOffset -le $headerOffset) { throw ('묶음 끝 표지가 머리 주석보다 앞에 있습니다: {0}' -f $SourcePath) }
    $bundle = @{ Path = $SourcePath; Ast = $ast; Names = @(); Texts = @{}; Tokens = @{}; Functions = @{}; EndOffset = $endOffset }
    foreach ($statement in $ast.EndBlock.Statements) {
        if (-not ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst])) { continue }
        if ($statement.Extent.StartOffset -lt $headerOffset) { continue }
        if ($statement.Extent.StartOffset -gt $endOffset) { break }
        $bundle.Names += $statement.Name
        $bundle.Texts[$statement.Name] = $statement.Extent.Text
        $bundle.Functions[$statement.Name] = $statement
        $bundle.Tokens[$statement.Name] = @(Get-TokenSequence -Tokens $tokens -StartOffset $statement.Extent.StartOffset -EndOffset $statement.Extent.EndOffset)
    }
    if ($bundle.Names.Count -eq 0) { throw ('묶음 함수를 찾지 못했습니다: {0}' -f $SourcePath) }
    return $bundle
}

function Get-AssignedVariableNames {
    # 함수 본문에서 대입 대상이 되는 지역 변수 이름(정렬·중복 제거) - X3 이 '저장 함수 지역 변수와 같은 이름' 을 소스에서 고릅니다
    param($FunctionAst)
    $names = @{}
    foreach ($assignment in $FunctionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        if ($assignment.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $assignment.Left.VariablePath.IsUnqualified) {
            $names[$assignment.Left.VariablePath.UserPath] = $true
        }
    }
    return @($names.Keys | Sort-Object)
}

function Get-ReadShareText {
    # 묶음의 후보 읽기(Read-AbyssJournalCandidate)가 [IO.File]::Open 에 넘기는 공유 인자 원문 - X1 이 그 값 그대로 본 파일을 엽니다
    param([hashtable]$Bundle)
    $functionAst = $Bundle.Functions['Read-AbyssJournalCandidate']
    if ($null -eq $functionAst) { return '' }
    $openCalls = @($functionAst.FindAll({ param($candidate)
                $candidate -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $candidate.Static -and
                $candidate.Member.Extent.Text -eq 'Open' -and @($candidate.Arguments).Count -eq 4 }, $true))
    if ($openCalls.Count -ne 1) { return '' }
    return $openCalls[0].Arguments[3].Extent.Text
}

# ===== 정적 단언(J14 · J15 · X9 정적) =====

function Test-BundleTokensEqual {
    # J14 두 사본 본문 동일 - 묶음 함수 이름 집합이 같고, 함수마다 주석을 뺀 토큰 열(Kind+Text · NewLine 포함 · 문자열 원문)이 같음.
    # 대조 넷으로 비교기 자체를 확인합니다: 문자열 안 공백 1개 삭제 = 다름(공백을 지우고 견주는 방식은 같다고 봄 - 명세 리뷰 1) /
    # 문자열 안 글자 1개 변경 = 다름 / 토큰 사이 공백 추가 = 같음 / 빈 줄 1개 추가 = 다름(NewLine 토큰 보존).
    param([hashtable]$GuiBundle, [hashtable]$WorkerBundle)
    $prefix = '[두 사본]'
    $guiNames = @($GuiBundle.Names | Sort-Object)
    $workerNames = @($WorkerBundle.Names | Sort-Object)
    $onlyGui = @($guiNames | Where-Object { $workerNames -cnotcontains $_ })
    $onlyWorker = @($workerNames | Where-Object { $guiNames -cnotcontains $_ })
    Assert-Case "$prefix J14 묶음 함수 이름 집합 동일(GUI $($guiNames.Count)개 · 워커 $($workerNames.Count)개)" ('GUI만[{0}] 워커만[{1}]' -f ($onlyGui -join ','), ($onlyWorker -join ',')) 'GUI만[] 워커만[]'
    $missing = @($REQUIRED_FUNCTION_NAMES | Where-Object { $guiNames -cnotcontains $_ -or $workerNames -cnotcontains $_ })
    Assert-Case "$prefix J14 묶음에 명세 2.1 함수 전부(공개 4 + 제안 헬퍼 7)" ($missing -join ',') ''
    $differences = @()
    foreach ($functionName in $guiNames) {
        if ($workerNames -cnotcontains $functionName) { continue }
        $at = Get-FirstDifference -Left $GuiBundle.Tokens[$functionName] -Right $WorkerBundle.Tokens[$functionName]
        if ($at -ge 0) { $differences += ('{0}@토큰{1}' -f $functionName, $at) }
    }
    Assert-Case "$prefix J14 함수마다 비주석 토큰 열 동일(Kind+Text · NewLine 포함 · 문자열 원문 그대로)" ($differences -join ',') ''

    # 비교기 대조 - GUI 사본 Update-AbyssJournal 원문을 메모리에서만 바꿔 같은 규칙으로 견줍니다
    $sampleName = 'Update-AbyssJournal'
    $sampleText = $GuiBundle.Texts[$sampleName]
    $baseline = @(Get-TextTokenSequence -Text $sampleText)
    Assert-Case "$prefix J14 대조 - 함수만 따로 파싱한 토큰 열 = 파일 파싱 토큰 열" (Get-FirstDifference -Left $baseline -Right $GuiBundle.Tokens[$sampleName]) -1
    $sampleTokens = $null
    $sampleErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($sampleText, [ref]$sampleTokens, [ref]$sampleErrors)
    $stringKinds = @([System.Management.Automation.Language.TokenKind]::StringLiteral, [System.Management.Automation.Language.TokenKind]::StringExpandable)
    $spacedString = @($sampleTokens | Where-Object { $stringKinds -contains $_.Kind -and $_.Text.Length -gt 2 -and $_.Text.Substring(1, $_.Text.Length - 2).Contains(' ') }) | Select-Object -First 1
    $anyString = @($sampleTokens | Where-Object { $stringKinds -contains $_.Kind -and $_.Text.Length -gt 2 }) | Select-Object -First 1
    $equalsToken = @($sampleTokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Equals }) | Select-Object -First 1
    $firstNewLine = @($sampleTokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::NewLine }) | Select-Object -First 1
    if ($null -eq $spacedString -or $null -eq $anyString -or $null -eq $equalsToken -or $null -eq $firstNewLine) {
        Assert-Case "$prefix J14 대조 재료(공백 든 문자열·문자열·대입·줄바꿈 토큰)" 'missing' 'found'
        return
    }
    # ① 문자열 안 공백 1개 삭제
    $spaceAt = $spacedString.Extent.StartOffset + 1 + $spacedString.Text.Substring(1).IndexOf(' ')
    $spaceRemoved = $sampleText.Remove($spaceAt, 1)
    $naiveSame = (($sampleText -replace '\s', '') -ceq ($spaceRemoved -replace '\s', ''))
    Assert-Case "$prefix J14 대조 - 문자열 안 공백 1개 삭제 = 다름 (공백 제거 비교는 같다고 봄)" ('{0}/{1}' -f ((Get-FirstDifference -Left $baseline -Right @(Get-TextTokenSequence -Text $spaceRemoved)) -ge 0), $naiveSame) 'True/True'
    # ② 문자열 안 글자 1개 변경
    $charAt = $anyString.Extent.StartOffset + 1
    $replacement = $(if ($sampleText[$charAt] -ceq 'x') { 'y' } else { 'x' })
    $charChanged = $sampleText.Remove($charAt, 1).Insert($charAt, $replacement)
    Assert-Case "$prefix J14 대조 - 문자열 안 글자 1개 변경 = 다름" ((Get-FirstDifference -Left $baseline -Right @(Get-TextTokenSequence -Text $charChanged)) -ge 0) 'True'
    # ③ 토큰 사이 공백 추가
    $spacesAdded = $sampleText.Insert($equalsToken.Extent.StartOffset, '   ')
    Assert-Case "$prefix J14 대조 - 토큰 사이 공백 추가 = 같음" (Get-FirstDifference -Left $baseline -Right @(Get-TextTokenSequence -Text $spacesAdded)) -1
    # ④ 빈 줄 1개 추가
    $blankLineAdded = $sampleText.Insert($firstNewLine.Extent.EndOffset, "`r`n")
    Assert-Case "$prefix J14 대조 - 빈 줄 1개 추가 = 다름(NewLine 토큰 보존)" ((Get-FirstDifference -Left $baseline -Right @(Get-TextTokenSequence -Text $blankLineAdded)) -ge 0) 'True'
}

function Test-BundleOutsideNames {
    # J15 묶음 본문 금지어·바깥 이름 0 - 비원자 쓰기(Set-Content · Move-Item -Force 등)와 한쪽 사본에만 있는 이름(설정 저장·로그
    # 함수, 바깥 변수)을 쓰지 않음(두 사본 동일의 전제 - 명세 2.1 '본문은 바깥 이름을 직접 쓰지 않는다'). 주석을 뺀 본문·AST 로 봅니다.
    param([hashtable]$Bundle, [string]$Prefix)
    $codeText = Remove-SourceComments -Text (@($Bundle.Names | ForEach-Object { $Bundle.Texts[$_] }) -join "`r`n")
    $forbidden = @([regex]::Matches($codeText, '(?i)\b(Set-Content|Move-Item|Out-File|Add-Content|Write-Utf8FileAtomic|Save-Config|Add-GuiLog|Write-RunLog)\b') | ForEach-Object { $_.Value })
    Assert-Case "$Prefix J15 금지어 0 - Set-Content · Move-Item(-Force) · Out-File · Add-Content · 설정 저장·로그 함수" ($forbidden -join ',') ''
    $outsideCommands = @()
    $qualifiedVariables = @()
    $undefinedVariables = @()
    foreach ($functionName in $Bundle.Names) {
        $functionAst = $Bundle.Functions[$functionName]
        foreach ($commandAst in $functionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $commandName = $commandAst.GetCommandName()
            if ([string]::IsNullOrEmpty($commandName)) { continue }   # & $Mutator 처럼 변수로 부르는 호출
            if ($Bundle.Names -contains $commandName) { continue }
            if ($null -ne (Get-Command -Name $commandName -CommandType Cmdlet -ErrorAction SilentlyContinue)) { continue }
            $outsideCommands += ('{0}>{1}' -f $functionName, $commandName)
        }
        $defined = @{}
        foreach ($parameterAst in $functionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.ParameterAst] }, $true)) {
            $defined[$parameterAst.Name.VariablePath.UserPath] = $true
        }
        foreach ($assignment in $functionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
            $left = $assignment.Left
            if ($left -is [System.Management.Automation.Language.ConvertExpressionAst]) { $left = $left.Child }
            if ($left -is [System.Management.Automation.Language.VariableExpressionAst]) { $defined[$left.VariablePath.UserPath] = $true }
        }
        foreach ($loop in $functionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.ForEachStatementAst] }, $true)) {
            $defined[$loop.Variable.VariablePath.UserPath] = $true
        }
        foreach ($variableAst in $functionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
            $variablePath = $variableAst.VariablePath
            if (-not $variablePath.IsUnqualified) {
                if ($variablePath.UserPath -ne 'script:abyssJournalSavedBy') { $qualifiedVariables += ('{0}>{1}' -f $functionName, $variablePath.UserPath) }
                continue
            }
            if ($defined.ContainsKey($variablePath.UserPath)) { continue }
            if ($AUTOMATIC_VARIABLE_NAMES -contains $variablePath.UserPath) { continue }
            $undefinedVariables += ('{0}>{1}' -f $functionName, $variablePath.UserPath)
        }
    }
    Assert-Case "$Prefix J15 바깥 함수 호출 0(묶음 함수·기본 cmdlet 만)" (@($outsideCommands | Sort-Object -Unique) -join ',') ''
    Assert-Case "$Prefix J15 범위 지정 변수는 `$script:abyssJournalSavedBy 하나뿐" (@($qualifiedVariables | Sort-Object -Unique) -join ',') ''
    Assert-Case "$Prefix J15 바깥 변수 0(매개변수·대입·foreach 변수·자동 변수만)" (@($undefinedVariables | Sort-Object -Unique) -join ',') ''
}

function Test-SourceJournalNames {
    # J15(바깥 이름 계약의 짝) - 묶음이 읽는 유일한 바깥 이름 $script:abyssJournalSavedBy 와 호출부가 넘길 경로 $abyssJournalPath 를
    # 그 소스가 함수 밖(스크립트 수준)에서 한 번 정의(명세 2.1 '바꿀 곳' - 두 스크립트 같은 이름). 정의가 빠지면 그 사본은 savedBy 를
    # 빈 값으로 쓰는데, 동작 케이스는 테스트가 그 변수를 직접 두므로 이 정적 단언만 그 누락을 봅니다.
    param([hashtable]$Bundle, [string]$Prefix, [string]$SavedByText, [string]$PathText)
    $savedByValues = @()
    $pathValues = @()
    foreach ($assignment in $Bundle.Ast.FindAll({ param($candidate)
                $candidate -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $candidate.Left -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
        $parent = $assignment.Parent
        $insideFunction = $false
        while ($null -ne $parent) {
            if ($parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $insideFunction = $true; break }
            $parent = $parent.Parent
        }
        if ($insideFunction) { continue }
        $variableName = $assignment.Left.VariablePath.UserPath
        if ($variableName -eq 'script:abyssJournalSavedBy') { $savedByValues += $assignment.Right.Extent.Text }
        if ($variableName -eq 'abyssJournalPath') { $pathValues += $assignment.Right.Extent.Text }
    }
    Assert-Case "$Prefix J15 작성자 표지 `$script:abyssJournalSavedBy 스크립트 수준 정의 1곳(명세 2.1)" ($savedByValues -join ' | ') $SavedByText
    Assert-Case "$Prefix J15 경로 `$abyssJournalPath 스크립트 수준 정의 1곳 - 같은 Log 폴더의 abyss_handoff.json(명세 2.1)" ($pathValues -join ' | ') $PathText
}

function Test-BundleFlushStatic {
    # X9(정적) 임시 파일 Flush($true) 가 묶음에 정확히 1곳 · 그 함수가 CreateNew 로 연 스트림 · 같은 스트림을 닫기(Dispose/Close) 전.
    # 교체 직전에 전원이 나가도 교체될 내용이 디스크에 남게 하는 계약입니다(설계 v10 6.1 ⑤).
    param([hashtable]$Bundle, [string]$Prefix)
    $flushCalls = @()
    foreach ($functionName in $Bundle.Names) {
        foreach ($node in $Bundle.Functions[$functionName].FindAll({ param($candidate)
                    $candidate -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $candidate.Member.Extent.Text -eq 'Flush' }, $true)) {
            $flushCalls += @{ Function = $functionName; Node = $node }
        }
    }
    $flushArguments = @($flushCalls | ForEach-Object { '(' + (@($_.Node.Arguments | ForEach-Object { $_.Extent.Text }) -join ',') + ')' })
    Assert-Case "$Prefix X9 Flush 호출은 묶음에 정확히 1곳 · 인자 `$true" ('{0}/{1}' -f $flushCalls.Count, ($flushArguments -join ' ')) '1/($true)'
    if ($flushCalls.Count -ne 1) { return }
    $flushNode = $flushCalls[0].Node
    $ownerFunction = $Bundle.Functions[$flushCalls[0].Function]
    $streamText = $flushNode.Expression.Extent.Text
    $closeCalls = @($ownerFunction.FindAll({ param($candidate)
                $candidate -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                @('Dispose', 'Close') -contains $candidate.Member.Extent.Text -and $candidate.Expression.Extent.Text -eq $streamText }, $true))
    $closeAfter = @($closeCalls | Where-Object { $_.Extent.StartOffset -gt $flushNode.Extent.StartOffset })
    $ownerCode = Remove-SourceComments -Text $ownerFunction.Extent.Text
    Assert-Case "$Prefix X9 Flush(`$true) 는 CreateNew 로 연 임시 파일 스트림을 닫기 전" ('{0}/{1}/{2}' -f ($closeCalls.Count -gt 0), ($closeAfter.Count -eq $closeCalls.Count), $ownerCode.Contains('[IO.FileMode]::CreateNew')) 'True/True/True'
}

function Test-BundleWriteSites {
    # X9(정적) 쓰기 자리 - 파일 내용을 쓰는 API(정적 WriteAll*·AppendAll*·AppendText·Create·CreateText·OpenWrite, FileStream·
    # StreamWriter 생성)는 임시 파일 쓰기(Write-AbyssJournalTempFile)와 잠금(Open-AbyssJournalLock) 안에만 있고, 저장·복원 경로는 그
    # 헬퍼를 한 번씩 부릅니다(Update-AbyssJournal · Read-AbyssJournalHeld). 다른 쓰기 경로가 생기면 CreateNew·Flush(true) 계약을
    # 우회하는데, BOM 만 맞추면 동작 단언은 같은 결과라 이 정적 단언만 봅니다(변이 검증 생존 보강 - 임시 쓰기를 WriteAllBytes 로).
    param([hashtable]$Bundle, [string]$Prefix)
    $writeApiNames = @('WriteAllBytes', 'WriteAllText', 'WriteAllLines', 'AppendAllText', 'AppendAllLines', 'AppendText', 'Create', 'CreateText', 'OpenWrite')
    $writeSites = @()
    $tempWriterCalls = @{}
    foreach ($functionName in $Bundle.Names) {
        $functionAst = $Bundle.Functions[$functionName]
        foreach ($node in $functionAst.FindAll({ param($candidate)
                    $candidate -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $candidate.Static -and
                    $writeApiNames -contains $candidate.Member.Extent.Text }, $true)) {
            $writeSites += ('{0}>{1}' -f $functionName, $node.Member.Extent.Text)
        }
        foreach ($node in $functionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $commandName = $node.GetCommandName()
            if ($commandName -eq 'New-Object' -and $node.Extent.Text -match 'FileStream|StreamWriter') { $writeSites += ('{0}>New-Object' -f $functionName) }
            if ($commandName -eq 'Write-AbyssJournalTempFile') { $tempWriterCalls[$functionName] = 1 + [int]$tempWriterCalls[$functionName] }
        }
    }
    Assert-Case "$Prefix X9 정적 쓰기 자리 - 내용을 쓰는 API 는 Write-AbyssJournalTempFile·Open-AbyssJournalLock 안에만" (@($writeSites | Sort-Object) -join ',') 'Open-AbyssJournalLock>New-Object,Write-AbyssJournalTempFile>New-Object'
    $callText = @($tempWriterCalls.Keys | Sort-Object | ForEach-Object { '{0}:{1}' -f $_, $tempWriterCalls[$_] }) -join ','
    Assert-Case "$Prefix X9 정적 쓰기 자리 - 저장·복원 경로가 Write-AbyssJournalTempFile 을 한 번씩 부름" $callText 'Read-AbyssJournalHeld:1,Update-AbyssJournal:1'
}

function Test-BundleCatchClauses {
    # X11(정적) 묶음의 try 문은 catch 절 2개까지 - PS 5.1 은 함수를 컴파일한 뒤(호출 수십 번 뒤 백그라운드) catch 절이 3개 이상인
    # try 에서 세 번째부터의 절에 걸릴 예외를 한 칸 앞 절로 보냅니다(묶음 머리 주석 - 실측). 동작 단언 X11 은 그 결과(본 파일 읽기
    # 막힘을 '없음' 으로 읽음)를 보지만 컴파일 시점에 기대므로, 원인 모양 자체를 여기서 막습니다.
    param([hashtable]$Bundle, [string]$Prefix)
    $wideTries = @()
    $tryCount = 0
    foreach ($functionName in $Bundle.Names) {
        foreach ($tryAst in $Bundle.Functions[$functionName].FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.TryStatementAst] }, $true)) {
            $tryCount++
            if ($tryAst.CatchClauses.Count -gt 2) { $wideTries += ('{0}:{1}절' -f $functionName, $tryAst.CatchClauses.Count) }
        }
    }
    Assert-Case "$Prefix X11 정적 - 묶음의 try 문($tryCount 개)은 catch 절 2개까지" ($wideTries -join ',') ''
}

function Get-IfGuardTexts {
    # 노드에서 Stop(그 노드를 품은 catch 절 등)까지 올라가며 노드를 감싼 if 갈래의 조건 원문 목록(else 갈래는 'else') - P2a 정적
    param($Node, $Stop)
    $guards = @()
    $current = $Node
    while ($null -ne $current -and -not [object]::ReferenceEquals($current, $Stop)) {
        $parent = $current.Parent
        if ($parent -is [System.Management.Automation.Language.IfStatementAst]) {
            foreach ($ifClause in $parent.Clauses) {
                if ([object]::ReferenceEquals($ifClause.Item2, $current)) { $guards += $ifClause.Item1.Extent.Text }
            }
            if ([object]::ReferenceEquals($parent.ElseClause, $current)) { $guards += 'else' }
        }
        $current = $parent
    }
    return $guards
}

function Test-BundleTempListWarning {
    # P2a(정적) 임시본 목록 읽기 실패(구현 리뷰 2.1) - 본 파일이 있으면 판정에 쓰지 않고 경고 1줄, io-failed 는 본 파일이 없을 때만.
    # 동작 케이스로 두지 않은 이유(2026-10-08 실측): 목록 읽기(GetFiles)를 막으려고 폴더에 ListDirectory 거부 ACE 를 둬도, 이 PC 의
    #   테스트 실행 토큰은 SeBackupPrivilege 가 켜져 있어 GetFiles 가 그대로 성공했습니다(FindFirstFile 이 백업 의도로 엶). 실행 권한에
    #   따라 결과가 갈리는 픽스처는 두지 않고, GetFiles 를 감싼 try 의 catch 절마다 봅니다: 경고 대입($result.Warnings += '…임시본
    #   목록을 읽지 못했습니다…') 정확히 1개 · 그 문장이 '본 파일 없음(-not $main.Exists)'·'폴더 없음(DirectoryNotFoundException)'
    #   갈래 안에 있지 않음(= 본 파일이 있을 때 닿음) · io-failed 대입은 전부 '본 파일 없음' 갈래 안.
    param([hashtable]$Bundle, [string]$Prefix)
    $functionAst = $Bundle.Functions['Read-AbyssJournalUnlocked']
    $listTries = @()
    if ($null -ne $functionAst) {
        $listTries = @($functionAst.FindAll({ param($candidate)
                    $candidate -is [System.Management.Automation.Language.TryStatementAst] -and
                    @($candidate.Body.FindAll({ param($inner)
                                $inner -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $inner.Member.Extent.Text -eq 'GetFiles' }, $true)).Count -gt 0 }, $true))
    }
    if ($listTries.Count -ne 1) {
        Assert-Case "$Prefix P2a 정적 - 임시본 목록(GetFiles)을 감싼 try 1개" $listTries.Count 1
        return
    }
    $clauseSummaries = foreach ($clause in $listTries[0].CatchClauses) {
        $typeText = (@($clause.CatchTypes | ForEach-Object { $_.TypeName.Name.Split('.')[-1] }) -join '+')
        $warningAssignments = @($clause.Body.FindAll({ param($candidate)
                    $candidate -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $candidate.Operator -eq [System.Management.Automation.Language.TokenKind]::PlusEquals -and
                    $candidate.Left.Extent.Text -eq '$result.Warnings' -and $candidate.Right.Extent.Text.Contains($WARNING_TEMP_LIST_FRAGMENT) }, $true))
        $blockedWarnings = @($warningAssignments | Where-Object {
                @(Get-IfGuardTexts -Node $_ -Stop $clause | Where-Object { $_ -match '^-not\s+\$main\.Exists$' -or $_.Contains('DirectoryNotFoundException') }).Count -gt 0 })
        $failedAssignments = @($clause.Body.FindAll({ param($candidate)
                    $candidate -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $candidate.Left.Extent.Text -eq '$result.Status' -and $candidate.Right.Extent.Text.Contains('io-failed') }, $true))
        $ungatedFailures = @($failedAssignments | Where-Object {
                @(Get-IfGuardTexts -Node $_ -Stop $clause | Where-Object { $_ -match '^-not\s+\$main\.Exists$' }).Count -eq 0 })
        '{0}:{1}/{2}/{3}' -f $typeText, $warningAssignments.Count, ($warningAssignments.Count -gt 0 -and $blockedWarnings.Count -eq 0), ($failedAssignments.Count -gt 0 -and $ungatedFailures.Count -eq 0)
    }
    Assert-Case "$Prefix P2a 정적 - 임시본 목록 catch 절마다 경고 1 · 본 파일이 있을 때 닿음 · io-failed 는 본 파일 없음 갈래에만(절:경고 수/닿음/io-failed 제한)" (@($clauseSummaries) -join ',') 'IOException:1/True/True,UnauthorizedAccessException:1/True/True'
}

function Get-WorkerOnlyFunctions {
    # 단계 2.10 워커 전용 함수(구현 명세 ① 2.10 W3·W4) - 워커 소스의 최상위 정의 → @{ Names; Texts(이름 → 원문); Functions(이름 → AST);
    # Offsets(이름 → 시작 위치) }. 묶음 밖이라 묶음 정의(Get-JournalBundle)에 들지 않습니다
    param([hashtable]$WorkerBundle)
    $found = @{ Names = @(); Texts = @{}; Functions = @{}; Offsets = @{} }
    foreach ($statement in $WorkerBundle.Ast.EndBlock.Statements) {
        if (-not ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst])) { continue }
        if ($WORKER_ONLY_FUNCTION_NAMES -cnotcontains $statement.Name) { continue }
        $found.Names += $statement.Name
        $found.Texts[$statement.Name] = $statement.Extent.Text
        $found.Functions[$statement.Name] = $statement
        $found.Offsets[$statement.Name] = $statement.Extent.StartOffset
    }
    return $found
}

function Get-FunctionClosures {
    # 함수 안의 클로저({ … }.GetNewClosure()) - 저장 계약의 -Mutator·-Expect 는 클로저로 만듭니다(저장 함수 머리 주석). 열거용이라 풀어서 돌려주고
    # 호출부가 @() 로 받습니다(절대 규칙 3)
    param($FunctionAst)
    return $FunctionAst.FindAll({ param($candidate)
            $candidate -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $candidate.Member.Extent.Text -eq 'GetNewClosure' -and
            $candidate.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true)
}

function Get-WorkerOnlyFunctionFacts {
    # 워커 전용 함수 하나의 모양 재료(구현 명세 ② 3.3 ㉑ 표의 칸) → @{ Tries; Traps; Throws; Updates(저장 호출 수); Closures(클로저 수);
    # ClosureScriptVariables(클로저 안 $script: 참조 수); ClosureCommands(클로저 안 명령 이름 - 중복 제거·정렬, ',' 구분 - 없으면 빈 값) }
    param($FunctionAst)
    $commandNames = @($FunctionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { [string]$_.GetCommandName() })
    $closures = @(Get-FunctionClosures -FunctionAst $FunctionAst)
    $closureScriptVariables = 0
    $closureCommandNames = @()
    foreach ($closure in $closures) {
        $closureScriptVariables += @($closure.Expression.FindAll({ param($candidate)
                    $candidate -is [System.Management.Automation.Language.VariableExpressionAst] -and $candidate.VariablePath.UserPath -like 'script:*' }, $true)).Count
        $closureCommandNames += @($closure.Expression.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { [string]$_.GetCommandName() })
    }
    return @{
        Tries                  = @($FunctionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.TryStatementAst] }, $true)).Count
        Traps                  = @($FunctionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.TrapStatementAst] }, $true)).Count
        Throws                 = @($FunctionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)).Count
        Updates                = @($commandNames | Where-Object { $_ -eq 'Update-AbyssJournal' }).Count
        Closures               = $closures.Count
        ClosureScriptVariables = $closureScriptVariables
        ClosureCommands        = (@($closureCommandNames | Sort-Object -Unique) -join ',')
    }
}

function Get-StatementChangeKind {
    # 문장 종류(㉑ 'Changed' 칸의 '바로 앞 형제' - 구현 명세 ② 3.3): 멤버 대입(복합 대입 포함) '멤버 대입 <멤버>' · 명령 하나만 든 문장 '<명령 이름>' ·
    # 그 밖은 AST 형식 이름
    param($Statement)
    if (($Statement -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($Statement.Left -is [System.Management.Automation.Language.MemberExpressionAst])) {
        return ('멤버 대입 ' + $Statement.Left.Member.Extent.Text)
    }
    if (($Statement -is [System.Management.Automation.Language.PipelineAst]) -and (@($Statement.PipelineElements).Count -eq 1) -and
        ($Statement.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst])) {
        return [string]$Statement.PipelineElements[0].GetCommandName()
    }
    return $Statement.GetType().Name
}

function Get-ChangedMarkerShapeText {
    # mutator 변경 표식의 자리(구현 명세 ② 2.0-10 · 3.3 ㉑ 'Changed' 칸 - 주석이 없는 AST 로 봄) → 클로저마다 '<역할>: Changed <수> [<자리> / …]' 를 역할 순으로
    # ' | ' 로 잇습니다. 역할은 저장 계약의 모양으로 가릅니다(-Mutator 는 param($journal, $change) 둘 · -Expect 는 param($journal) 하나 - 저장 함수 머리 주석).
    # 표식 = '<무엇>.Changed = $true' 대입문. 자리 = 최상위(클로저 본문에 바로 든 문장) · 마지막(든 블록의 마지막 문장) · foreach 안(클로저 안 foreach 본문 안) ·
    # 앞 형제(같은 블록 바로 앞 문장의 종류 - Get-StatementChangeKind, 첫 문장이면 '(없음)')
    param($FunctionAst)
    $closureTexts = foreach ($closure in @(Get-FunctionClosures -FunctionAst $FunctionAst)) {
        $closureBody = $closure.Expression.ScriptBlock
        $parameterCount = 0
        if ($null -ne $closureBody.ParamBlock) { $parameterCount = @($closureBody.ParamBlock.Parameters).Count }
        $role = '매개변수 {0}개' -f $parameterCount
        if ($parameterCount -eq 2) { $role = 'Mutator' } elseif ($parameterCount -eq 1) { $role = 'Expect' }
        $markers = @($closureBody.FindAll({ param($candidate)
                    ($candidate -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
                    ($candidate.Left -is [System.Management.Automation.Language.MemberExpressionAst]) -and
                    ($candidate.Left.Member.Extent.Text -eq 'Changed') -and ($candidate.Right.Extent.Text -eq '$true') }, $true))
        $markerPlaces = foreach ($marker in $markers) {
            $siblings = @($marker.Parent.Statements)
            $markerAt = -1
            for ($siblingIndex = 0; $siblingIndex -lt $siblings.Count; $siblingIndex++) {
                if ([object]::ReferenceEquals($siblings[$siblingIndex], $marker)) { $markerAt = $siblingIndex }
            }
            $inForeach = $false
            for ($ancestor = $marker.Parent; ($null -ne $ancestor) -and (-not [object]::ReferenceEquals($ancestor, $closureBody)); $ancestor = $ancestor.Parent) {
                if ($ancestor -is [System.Management.Automation.Language.ForEachStatementAst]) { $inForeach = $true }
            }
            $previousKind = '(없음)'
            if ($markerAt -gt 0) { $previousKind = Get-StatementChangeKind -Statement $siblings[$markerAt - 1] }
            '최상위 {0} · 마지막 {1} · foreach 안 {2} · 앞 형제 {3}' -f ([object]::ReferenceEquals($marker.Parent, $closureBody.EndBlock)),
                (($markerAt -ge 0) -and ($markerAt -eq ($siblings.Count - 1))), $inForeach, $previousKind
        }
        $placeText = ''
        if ($markers.Count -gt 0) { $placeText = ' [' + (@($markerPlaces) -join ' / ') + ']' }
        '{0}: Changed {1}{2}' -f $role, $markers.Count, $placeText
    }
    return ((@($closureTexts) | Sort-Object) -join ' | ')
}

function Get-NoChangeBranchStatementCount {
    # 무변경 갈래의 continue 아닌 문장 수(㉑ 'Changed' 칸 - 닫기 함수 '무변경 갈래(항목 없음·이미 done)는 continue 뿐', 구현 명세 ② 3.3): 클로저 안 if 의
    # 갈래(else 포함) 가운데 변경 표식을 품지 않은 갈래의 문장만 셉니다 - 0 이어야 합니다. 표식을 품은 갈래(찾은 항목 쪽)는 표식 자리 단언이 봅니다.
    # -MutatorOnly 면 Mutator 클로저(param 둘 - 저장 함수 머리 주석)만 봅니다 - -Expect 클로저는 판정 값을 담는 갈래(표식 없음)가 정상이라 세면 안 됩니다
    # (구현 명세 ② 2.5 own 닫기 - Expect·Mutator 두 클로저)
    param($FunctionAst, [switch]$MutatorOnly)
    $count = 0
    foreach ($closure in @(Get-FunctionClosures -FunctionAst $FunctionAst)) {
        if ($MutatorOnly) {
            $closureParams = $closure.Expression.ScriptBlock.ParamBlock
            if (($null -eq $closureParams) -or (@($closureParams.Parameters).Count -ne 2)) { continue }
        }
        foreach ($ifStatement in @($closure.Expression.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.IfStatementAst] }, $true))) {
            $branches = @($ifStatement.Clauses | ForEach-Object { $_.Item2 })
            if ($null -ne $ifStatement.ElseClause) { $branches += $ifStatement.ElseClause }
            foreach ($branch in $branches) {
                $branchMarkers = @($branch.FindAll({ param($candidate)
                            ($candidate -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
                            ($candidate.Left -is [System.Management.Automation.Language.MemberExpressionAst]) -and ($candidate.Left.Member.Extent.Text -eq 'Changed') }, $true))
                if ($branchMarkers.Count -gt 0) { continue }
                $count += @($branch.Statements | Where-Object { -not ($_ -is [System.Management.Automation.Language.ContinueStatementAst]) }).Count
            }
        }
    }
    return $count
}

function Test-WorkerOnlyStatic {
    # W-ONLY(정적) 워커 전용 함수의 자리·모양 - ① 워커에 1번씩 · 묶음 끝 표지 뒤(표지 안이면 J14 이름 집합이 갈라짐 - 명세 2.1 '두 사본' 규칙) ·
    # GUI 에 0 ② 기록 함수: 예외를 감싸지 않음(try 0 - 설계 R2-5: 남는 예외는 구현 결함이라 최상위 catch 의 코드 1 로 드러나야 함) · 저장 1번 ·
    # 잠금 읽기 0 · mutator 는 클로저 1개이고 그 안에서 $script: 를 읽지 않고(클로저는 빈 값으로 읽음) 명령도 부르지 않음(체크리스트 5·6)
    # ③ 해석 함수: $script: 0(순수) · try 1개에 catch 1절 ④ 목록 함수 안 exit 문 0(단계 2.10 구현 검증 - 없는 함수는 '(없음)' 으로 적어 FAIL)
    # ⑤ 이어받기 시작 함수 Consume-Handoff(구현 명세 ② 2.1 · 3.3 ㉑ 표): try 0 · 잠금 읽기 1 · 저장 0
    # ⑥ 자기 항목 생성 · 키 인덱스 기록 · 열쇠 닫기(구현 명세 ② 2.2·2.3 · 3.3 ㉑ 표의 칸만) ⑦ 클리어 기록과 ②·⑧·⑨ 의 mutator 변경 표식 자리(명세 ② 2.0-10)
    # ⑧ own 던전 밖 시작의 기존 항목 닫기(구현 명세 ② 2.5 · 3.3 ㉑ 표의 칸만)
    # ⑨ '다시 하기' 단계 기록 셋(구현 명세 ⑤b2 1.3 · 3.4 - 표의 칸만): try·trap·throw 0 · 저장 1 · 클로저 2(Expect·Mutator) · 그 안 $script: 0 · 그 안 명령 = 필드 쓰기만 ·
    #    Mutator 의 무변경 갈래는 continue 뿐
    param([hashtable]$WorkerOnly, [hashtable]$WorkerBundle, [hashtable]$GuiBundle)
    $prefix = '[워커 전용]'
    $placement = foreach ($functionName in $WORKER_ONLY_FUNCTION_NAMES) {
        $workerCount = @($WorkerOnly.Names | Where-Object { $_ -ceq $functionName }).Count
        $guiCount = @($GuiBundle.Ast.FindAll({ param($candidate)
                    $candidate -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $candidate.Name -eq $functionName }, $true)).Count
        $afterEnd = ($workerCount -eq 1) -and ([int]$WorkerOnly.Offsets[$functionName] -gt [int]$WorkerBundle.EndOffset)
        '{0}:워커 {1}·표지 뒤 {2}·GUI {3}' -f $functionName, $workerCount, $afterEnd, $guiCount
    }
    Assert-Case "$prefix W-ONLY 자리 - 워커에 1번 · 묶음 끝 표지 뒤 · GUI 0" ($placement -join ' | ') `
        (($WORKER_ONLY_FUNCTION_NAMES | ForEach-Object { '{0}:워커 1·표지 뒤 True·GUI 0' -f $_ }) -join ' | ')
    # ⑤ Consume-Handoff - 시작 때 journal 을 한 번 읽어 역할만 정합니다: try 0(남는 예외는 구현 결함이라 최상위 catch 의 코드 1 로 - 설계 R2-5) · 잠금 읽기 1
    #    (nonce 유무와 무관하게 1회 - 명세 ② J1) · 저장 0(쓰기 0 - 명세 ② 2.1). exit 0 은 아래 ④ 가 함께 봅니다. 함수가 없으면 위 자리 단언이 FAIL 입니다
    $consumeAst = $WorkerOnly.Functions['Consume-Handoff']
    if ($null -ne $consumeAst) {
        $consumeTries = @($consumeAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.TryStatementAst] }, $true)).Count
        $consumeCommands = @($consumeAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
        Assert-Case "$prefix W-ONLY 이어받기 시작 함수 Consume-Handoff - try 0 · 잠금 읽기 1 · 저장 0" `
            ('{0}/{1}/{2}' -f $consumeTries, @($consumeCommands | Where-Object { $_ -eq 'Read-AbyssJournal' }).Count,
                @($consumeCommands | Where-Object { $_ -eq 'Update-AbyssJournal' }).Count) '0/1/0'
    }
    # ⑥ 구현 명세 ② 2.2·2.3 의 세 함수 - 3.3 ㉑ 표의 칸만 봅니다(exit 0 은 아래 ④ · 함수가 없으면 위 자리 단언이 FAIL). 셋 다 예외를 감싸지 않고(try 0 - 설계 R2-5:
    #    저장소가 잠금·IO 실패를 태그로 바꾸므로 남는 예외는 최상위 catch 의 코드 1) 저장을 1번 하며, mutator·Expect 는 클로저이고 그 안에서 $script: 를 읽지
    #    않습니다(클로저는 빈 값으로 읽음 - 값은 클로저 밖 지역 사본으로, 명세 ② 2.0-1). 클로저가 부르는 명령은 표의 것만(클로저는 최상위 함수만 부름):
    #    생성 = 클로저 1 · 그 안 명령은 소유자 대조만(같은 owner 의 남은 열린 항목을 같은 저장에서 닫음 - 명세 2.2) / 인덱스 = 클로저 2(Expect·Mutator) · 그 안
    #    명령 0 / 닫기 = trap·throw 도 0(설계 R2 S4) · 클로저 1 · 그 안 명령은 필드 쓰기 Set-AbyssJournalProperty 만(없는 필드는 더하고 있는 필드는 자리 유지 - 명세 J5)
    $enteredAst = $WorkerOnly.Functions['Add-AbyssJournalEnteredEntry']
    if ($null -ne $enteredAst) {
        $enteredFacts = Get-WorkerOnlyFunctionFacts -FunctionAst $enteredAst
        Assert-Case "$prefix W-ONLY 자기 항목 생성 Add-AbyssJournalEnteredEntry - try 0 · 저장 1 · 클로저 1 · 그 안 `$script: 0 · 그 안 명령 = 소유자 대조만" `
            ('{0}/{1}/{2}/{3}/[{4}]' -f $enteredFacts.Tries, $enteredFacts.Updates, $enteredFacts.Closures, $enteredFacts.ClosureScriptVariables, $enteredFacts.ClosureCommands) `
            '0/1/1/0/[Test-AbyssJournalOwnerMatch]'
    }
    $indexAst = $WorkerOnly.Functions['Set-AbyssAfterEntryIndex']
    if ($null -ne $indexAst) {
        $indexFacts = Get-WorkerOnlyFunctionFacts -FunctionAst $indexAst
        Assert-Case "$prefix W-ONLY 키 인덱스 기록 Set-AbyssAfterEntryIndex - try 0 · 저장 1 · 클로저 2(Expect·Mutator) · 그 안 `$script: 0 · 그 안 명령 0" `
            ('{0}/{1}/{2}/{3}/[{4}]' -f $indexFacts.Tries, $indexFacts.Updates, $indexFacts.Closures, $indexFacts.ClosureScriptVariables, $indexFacts.ClosureCommands) '0/1/2/0/[]'
    }
    $leaveAst = $WorkerOnly.Functions['Close-AbyssKeyEntryOnLeave']
    if ($null -ne $leaveAst) {
        $leaveFacts = Get-WorkerOnlyFunctionFacts -FunctionAst $leaveAst
        Assert-Case "$prefix W-ONLY 열쇠 닫기 Close-AbyssKeyEntryOnLeave - try·trap·throw 0 · 저장 1 · 클로저 1 · 그 안 `$script: 0 · 그 안 명령 = 필드 쓰기만" `
            ('{0}/{1}/{2}/{3}/{4}/{5}/[{6}]' -f $leaveFacts.Tries, $leaveFacts.Traps, $leaveFacts.Throws, $leaveFacts.Updates, $leaveFacts.Closures,
                $leaveFacts.ClosureScriptVariables, $leaveFacts.ClosureCommands) '0/0/0/1/1/0/[Set-AbyssJournalProperty]'
    }
    # ⑧ 구현 명세 ② 2.5 의 own 닫기 - 이어받기 시작 선분기가 필드 확정·패널류 첫 표본에서 받은 own 항목을 닫습니다(launchState done · reason
    #    abandoned-pre-entry-start · screen = 그 화면). 3.3 ㉑ 표의 칸만 봅니다(exit 0 은 아래 ④ · 함수가 없으면 위 자리 단언이 FAIL): 예외를 감싸지 않고(try 0 -
    #    설계 R2-5) 저장 1번, 클로저 2(-Expect '받은 own 항목이 있고 entered ∧ done 아님' · -Mutator)이고 그 안에서 $script: 를 읽지 않으며(지역 사본 - 명세 ② 2.0-1)
    #    부르는 명령은 필드 쓰기 Set-AbyssJournalProperty 만(없는 필드는 더하고 있는 필드는 자리 유지 - 명세 J5)
    $ownCloseAst = $WorkerOnly.Functions['Close-AbyssOwnEntryBeforeEntry']
    if ($null -ne $ownCloseAst) {
        $ownCloseFacts = Get-WorkerOnlyFunctionFacts -FunctionAst $ownCloseAst
        Assert-Case "$prefix W-ONLY own 닫기 Close-AbyssOwnEntryBeforeEntry - try 0 · 저장 1 · 클로저 2(Expect·Mutator) · 그 안 `$script: 0 · 그 안 명령 = 필드 쓰기만" `
            ('{0}/{1}/{2}/{3}/[{4}]' -f $ownCloseFacts.Tries, $ownCloseFacts.Updates, $ownCloseFacts.Closures, $ownCloseFacts.ClosureScriptVariables, $ownCloseFacts.ClosureCommands) `
            '0/1/2/0/[Set-AbyssJournalProperty]'
    }
    # ⑨ 구현 명세 ⑤b2 1.3 의 '다시 하기' 단계 기록 셋 - 표의 칸만(exit 0 은 아래 ④ · 함수가 없으면 위 자리 단언이 FAIL): try·trap·throw 0 · 저장 1 ·
    #    클로저 2(Expect·Mutator) · 그 안 $script: 0 · 그 안 명령 = 필드 쓰기만 · Mutator 의 무변경 갈래는 continue 뿐
    foreach ($stageWriterName in $STAGE_WRITER_NAMES) {
        $stageWriterAst = $WorkerOnly.Functions[$stageWriterName]
        if ($null -eq $stageWriterAst) { continue }
        $stageWriterFacts = Get-WorkerOnlyFunctionFacts -FunctionAst $stageWriterAst
        Assert-Case ("$prefix W-ONLY 단계 기록 {0} - try·trap·throw 0 · 저장 1 · 클로저 2(Expect·Mutator) · 그 안 `$script: 0 · 그 안 명령 = 필드 쓰기만" -f $stageWriterName) `
            ('{0}/{1}/{2}/{3}/{4}/{5}/[{6}]' -f $stageWriterFacts.Tries, $stageWriterFacts.Traps, $stageWriterFacts.Throws, $stageWriterFacts.Updates, $stageWriterFacts.Closures,
                $stageWriterFacts.ClosureScriptVariables, $stageWriterFacts.ClosureCommands) '0/0/0/1/2/0/[Set-AbyssJournalProperty]'
        Assert-Case ("$prefix W-ONLY 변경 표식 - 단계 기록 {0} Mutator 의 무변경 갈래(받은 항목이 아님)는 continue 뿐" -f $stageWriterName) `
            (Get-NoChangeBranchStatementCount -FunctionAst $stageWriterAst -MutatorOnly) 0
    }
    # ⑦ mutator 변경 표식의 자리(구현 명세 ② 2.0-10 · 3.3 ㉑ 'Changed' 칸 - 명세 리뷰 2 P1-1): 저장 계약은 mutator 가 '$change.Changed = $true' 를 둔 저장만
    #    씁니다(없으면 unchanged = 임시 파일·Replace 0 - 호출부는 실패로 처리해 키 지점이 늘 코드 4, 닫기는 저장되지 않음). 표식은 실제 필드 변경 바로 뒤 1번이고
    #    무변경 갈래에는 없습니다 - 덧붙이는 둘(클리어 기록 · 생성)은 클로저 최상위 마지막 문장 · 바로 앞 = entries 덧붙임(덧붙임은 늘 변경 - 클리어 기록의 열쇠 닫기
    #    갈래 · 생성의 동반 닫기 foreach 안에는 0), 항목을 찾아 고치는 둘(인덱스 · 닫기)은 foreach 안 그 갈래의 마지막 문장 · 바로 앞 = index 대입 / 필드 쓰기 명령 ·
    #    클로저 최상위 0(최상위의 무조건 표식이면 무변경 갈래에서도 쓰기가 생김 - 그 동작은 test_after_entry_at_most_once R2-N1·N2). 인덱스의 Expect 에는 0,
    #    닫기의 무변경 갈래(항목 없음·이미 done)는 continue 뿐. 함수가 없으면 건너뜁니다(위 자리 단언이 FAIL)
    #    구현 명세 ② 2.5: own 닫기(⑧)도 항목을 찾아 고치는 쪽이라 열쇠 닫기와 같은 모양입니다 - Mutator 에만 1(찾은 항목 갈래 안 마지막 · 바로 앞 = 필드 쓰기
    #    명령) · Expect 0 · Mutator 의 무변경 갈래(받은 항목이 아닌 항목 - 정상 흐름에서는 Expect 가 막음)는 continue 뿐. 표식이 빠지면 저장이 unchanged 라 늘
    #    own 닫기 [경고] 갈래로 가고 받은 항목이 열린 채 남습니다(명세 2.0-10 · 3.5 ⓐ)
    $appendMarkerPlace = 'Mutator: Changed 1 [최상위 True · 마지막 True · foreach 안 False · 앞 형제 멤버 대입 entries]'
    $markerSpecs = @(
        @{ Name = 'Add-AbyssJournalClearedEntry'; Place = $appendMarkerPlace },
        @{ Name = 'Add-AbyssJournalEnteredEntry'; Place = $appendMarkerPlace },
        @{ Name = 'Set-AbyssAfterEntryIndex'; Place = 'Expect: Changed 0 | Mutator: Changed 1 [최상위 False · 마지막 True · foreach 안 True · 앞 형제 멤버 대입 index]' },
        @{ Name = 'Close-AbyssKeyEntryOnLeave'; Place = 'Mutator: Changed 1 [최상위 False · 마지막 True · foreach 안 True · 앞 형제 Set-AbyssJournalProperty]' },
        @{ Name = 'Close-AbyssOwnEntryBeforeEntry'; Place = 'Expect: Changed 0 | Mutator: Changed 1 [최상위 False · 마지막 True · foreach 안 True · 앞 형제 Set-AbyssJournalProperty]' },
        @{ Name = 'Set-AbyssJournalRetryAttempt'; Place = 'Expect: Changed 0 | Mutator: Changed 1 [최상위 False · 마지막 True · foreach 안 True · 앞 형제 Set-AbyssJournalProperty]' },
        @{ Name = 'Set-AbyssJournalRetryClicked'; Place = 'Expect: Changed 0 | Mutator: Changed 1 [최상위 False · 마지막 True · foreach 안 True · 앞 형제 Set-AbyssJournalProperty]' },
        @{ Name = 'Set-AbyssJournalReentered'; Place = 'Expect: Changed 0 | Mutator: Changed 1 [최상위 False · 마지막 True · foreach 안 True · 앞 형제 Set-AbyssJournalProperty]' })
    foreach ($markerSpec in $markerSpecs) {
        $markerFunctionAst = $WorkerOnly.Functions[$markerSpec.Name]
        if ($null -eq $markerFunctionAst) { continue }
        Assert-Case ('{0} W-ONLY 변경 표식 자리 - {1}' -f $prefix, $markerSpec.Name) (Get-ChangedMarkerShapeText -FunctionAst $markerFunctionAst) $markerSpec.Place
    }
    if ($null -ne $leaveAst) {
        Assert-Case "$prefix W-ONLY 변경 표식 - 열쇠 닫기의 무변경 갈래(항목 없음·이미 done)는 continue 뿐(표식을 품지 않은 if 갈래의 continue 아닌 문장 0)" `
            (Get-NoChangeBranchStatementCount -FunctionAst $leaveAst) 0
    }
    if ($null -ne $ownCloseAst) {
        Assert-Case "$prefix W-ONLY 변경 표식 - own 닫기 Mutator 의 무변경 갈래(받은 항목이 아님)는 continue 뿐(표식을 품지 않은 if 갈래의 continue 아닌 문장 0)" `
            (Get-NoChangeBranchStatementCount -FunctionAst $ownCloseAst -MutatorOnly) 0
    }
    $recordAst = $WorkerOnly.Functions['Add-AbyssJournalClearedEntry']
    $ownerAst = $WorkerOnly.Functions['ConvertTo-AbyssJournalOwner']
    if ($null -eq $recordAst -or $null -eq $ownerAst) { return }
    $recordTries = @($recordAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.TryStatementAst] }, $true)).Count
    $recordCommands = @($recordAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
    $closures = @($recordAst.FindAll({ param($candidate)
                $candidate -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $candidate.Member.Extent.Text -eq 'GetNewClosure' -and
                $candidate.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true))
    $closureScriptVariables = 0
    $closureCommandCount = 0
    foreach ($closure in $closures) {
        $closureScriptVariables += @($closure.Expression.FindAll({ param($candidate)
                    $candidate -is [System.Management.Automation.Language.VariableExpressionAst] -and $candidate.VariablePath.UserPath -like 'script:*' }, $true)).Count
        $closureCommandCount += @($closure.Expression.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.CommandAst] }, $true)).Count
    }
    Assert-Case "$prefix W-ONLY 기록 함수 - try 0 · 저장 1 · 잠금 읽기 0 · 클로저 mutator 1 · 그 안 `$script: 0 · 명령 0" `
        ('{0}/{1}/{2}/{3}/{4}/{5}' -f $recordTries, @($recordCommands | Where-Object { $_ -eq 'Update-AbyssJournal' }).Count,
            @($recordCommands | Where-Object { $_ -eq 'Read-AbyssJournal' }).Count, $closures.Count, $closureScriptVariables, $closureCommandCount) '0/1/0/1/0/0'
    $ownerScriptVariables = @($ownerAst.FindAll({ param($candidate)
                $candidate -is [System.Management.Automation.Language.VariableExpressionAst] -and $candidate.VariablePath.UserPath -like 'script:*' }, $true)).Count
    $ownerCatchClauses = @($ownerAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.TryStatementAst] }, $true) | ForEach-Object { $_.CatchClauses.Count })
    Assert-Case "$prefix W-ONLY 해석 함수 - `$script: 0(순수) · try 마다 catch 절 수" ('{0}/{1}' -f $ownerScriptVariables, ($ownerCatchClauses -join ',')) '0/1'
    # ④ 두 함수 안 exit 문 0 - 기록·해석이 실패해도 본류는 같은 판의 나가기·복귀로 이어져야 합니다(명세 2.10 W3 '→ 그대로 진행' · 저장소 밖 예외는 throw 로
    # 최상위 catch 의 코드 1). 이 회귀는 함수를 같은 프로세스에서 부르므로 exit 가 들면 아래 동작 행(X4)이 단언 없이 조용히 끝나 통과로 보입니다(단계 2.10
    # 변이 검증 - 생존 e1·e2: exit 0) - 그래서 동작보다 먼저 정적으로 봅니다
    $exitCounts = foreach ($functionName in $WORKER_ONLY_FUNCTION_NAMES) {
        $exitFunctionAst = $WorkerOnly.Functions[$functionName]
        if ($null -eq $exitFunctionAst) { '{0}:(없음)' -f $functionName; continue }
        '{0}:{1}' -f $functionName, @($exitFunctionAst.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count
    }
    Assert-Case "$prefix W-ONLY 워커 전용 함수 안 exit 문 0(동작 행보다 먼저 - 같은 프로세스에서 exit 가 테스트를 끝내지 않게)" ($exitCounts -join ' | ') `
        (($WORKER_ONLY_FUNCTION_NAMES | ForEach-Object { '{0}:0' -f $_ }) -join ' | ')
}

function Get-AssignmentTargetPaths {
    # 대입 문장 왼쪽이 다시 정하는 변수 이름(VariablePath.UserPath)들 - '$x = …'(+= 같은 복합 대입 포함) · '[형식]$x = …' · '$a, $b = …' 모양.
    # 멤버·첨자 대입('$x.y = …' · '$x[0] = …')은 변수 자체를 바꾸지 않아 뺍니다. 한 개면 문자열 하나로 풀려 나오므로 호출부가 @() 로 받습니다(절대 규칙 3)
    param($Target)
    if ($Target -is [System.Management.Automation.Language.VariableExpressionAst]) { return $Target.VariablePath.UserPath }
    if ($Target -is [System.Management.Automation.Language.AttributedExpressionAst]) { return (Get-AssignmentTargetPaths -Target $Target.Child) }
    if ($Target -is [System.Management.Automation.Language.ArrayLiteralAst]) { return ($Target.Elements | ForEach-Object { Get-AssignmentTargetPaths -Target $_ }) }
}

function Test-InNestedScope {
    # 노드가 함수·스크립트블록 안(새 범위)인지 - 바깥 파일 블록이 아닌 ScriptBlockAst 조상이 있으면 참. 그 안에서 이름만 쓴 대입('$x = …')은 지역 변수라
    # 스크립트 변수를 바꾸지 않습니다(같은 이름의 지역 사본을 계약 위반으로 세지 않게). if·try 블록은 범위를 만들지 않아 거짓
    param($Node)
    for ($ancestor = $Node.Parent; $null -ne $ancestor; $ancestor = $ancestor.Parent) {
        if (($ancestor -is [System.Management.Automation.Language.ScriptBlockAst]) -and ($null -ne $ancestor.Parent)) { return $true }
    }
    return $false
}

function Test-WorkerRunIdStatic {
    # X4-h 정적(단계 2.10 구현 검증 반영의 검토 - 명세 2.10 W2 '빈 값(워커 단독 실행)도 그대로 · 분기 없음'): 동작 행 X4-h 는 워커의 실행 id 읽기 문장(W2) 하나만
    # 점소싱합니다. 그래서 W2 는 원문 그대로 두고 그 앞뒤에 빈 값 분기를 더한 모양 - W2 뒤 'if (빈 값) { $script:abyssRunId = … }'(검토 변이 w2b) · W2 앞
    # 'if (빈 값) { $env:HONEYNOGI_RUN_ID = … }'(w2c) - 은 X4-h 를 통과하고, ⑯ 결합 행은 늘 RUN_ID 를 넣고 돌아 회귀 97종 어디에서도 드러나지 않았습니다
    # (대조군과 결과가 같음). 그래서 워커 전체(함수·조건 안까지 모든 깊이)에서 ① 실행 id 변수 대입 = 스크립트 최상위의 W2 하나 ② RUN_ID env 대입 0 을
    # 봅니다. 대입문만 셉니다 - 이 워커는 스크립트 변수를 Set-Variable 로 바꾸지 않고 env 를 쓰는 곳도 없으며, env 를 쓰는 GUI 는 '$env:이름 = …' 모양입니다.
    # 실행 id 변수 = '$script:abyssRunId'(어디서든) + 이름만 쓴 '$abyssRunId'(함수·스크립트블록 밖 - 워커 최상위는 이름만 쓴 대입도 스크립트 변수)
    param([hashtable]$WorkerBundle)
    $prefix = '[워커 사본]'
    $runIdAssignments = New-Object System.Collections.Generic.List[object]
    $envAssignments = New-Object System.Collections.Generic.List[object]
    foreach ($assignment in $WorkerBundle.Ast.FindAll({ param($candidate) $candidate -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        $targetPaths = @(Get-AssignmentTargetPaths -Target $assignment.Left)
        # 이름만 쓴 대입의 범위는 그 이름일 때만 거슬러 올라가 봅니다(-and 가 앞이 거짓이면 뒤를 부르지 않음 - 대입문 수천 개마다 조상을 훑지 않게)
        if (@($targetPaths | Where-Object { ($_ -match '^script:abyssRunId$') -or (($_ -match '^abyssRunId$') -and -not (Test-InNestedScope -Node $assignment)) }).Count -gt 0) {
            $runIdAssignments.Add($assignment)
        }
        if (@($targetPaths | Where-Object { $_ -match '^env:HONEYNOGI_RUN_ID$' }).Count -gt 0) { $envAssignments.Add($assignment) }
    }
    # 최상위 = 스크립트 끝 블록에 바로 든 문장(W2 자리). 그 밖은 함수·if·try 같은 안쪽 - 줄 번호를 실제 값에 실어 FAIL 때 자리가 바로 보이게
    $topLevelLines = @($runIdAssignments | Where-Object { [object]::ReferenceEquals($_.Parent, $WorkerBundle.Ast.EndBlock) } | ForEach-Object { $_.Extent.StartLineNumber })
    $nestedLines = @($runIdAssignments | Where-Object { -not [object]::ReferenceEquals($_.Parent, $WorkerBundle.Ast.EndBlock) } | ForEach-Object { $_.Extent.StartLineNumber })
    Assert-Case "$prefix X4-h 정적 ① 실행 id 변수 대입 = 스크립트 최상위 W2 하나 · 함수·조건 안 대입 0(빈 값 분기 없음)" `
        ('최상위 {0} · 안쪽 {1} [{2}]' -f $topLevelLines.Count, $nestedLines.Count, ($nestedLines -join ',')) '최상위 1 · 안쪽 0 []'
    Assert-Case "$prefix X4-h 정적 ② RUN_ID env 대입 0(워커는 읽기만 - W2 앞에서 빈 값을 채우지 않음)" `
        ('{0} [{1}]' -f $envAssignments.Count, (@($envAssignments | ForEach-Object { $_.Extent.StartLineNumber }) -join ',')) '0 []'
}

# ===== 파일·픽스처 =====

function New-CaseFolder {
    param([hashtable]$Context, [string]$Name)
    $folder = Join-Path $Context.Root $Name
    [void][IO.Directory]::CreateDirectory($folder)
    return $folder
}

function Get-JournalPath { param([string]$Folder) return (Join-Path $Folder 'abyss_handoff.json') }

function Get-LockPath { param([string]$Folder) return (Join-Path $Folder 'abyss_handoff.lock') }

function Get-FileDigest {
    # 파일 내용 SHA-256 앞 16자(없으면 'none') - '파일 불변' 단언용
    param([string]$FilePath)
    if (-not [IO.File]::Exists($FilePath)) { return 'none' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($FilePath))).Replace('-', '').Substring(0, 16))
    } finally {
        $sha.Dispose()
    }
}

function Get-FolderListing {
    # 폴더 안 이름 목록('|' 구분, 정렬)
    param([string]$Folder)
    return ((@([IO.Directory]::GetFileSystemEntries($Folder)) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object) -join '|')
}

function Get-FolderState {
    # 폴더 상태 지문 - 잠금 파일을 뺀 이름·내용 해시 목록(쥐고 있는 잠금은 읽을 수 없고 journal 상태의 일부도 아님)
    param([string]$Folder)
    $parts = foreach ($entryPath in @([IO.Directory]::GetFileSystemEntries($Folder) | Sort-Object)) {
        $entryName = [IO.Path]::GetFileName($entryPath)
        if ($entryName -like '*.lock') { continue }
        if ([IO.Directory]::Exists($entryPath)) { $entryName + '/' } else { '{0}:{1}' -f $entryName, (Get-FileDigest $entryPath) }
    }
    return (@($parts) -join '|')
}

function Get-LeftoverCount {
    # 남은 임시(.tmp)·잠금(.lock) 개수 - 저장소 호출이 끝난 뒤에는 늘 0 이어야 합니다
    param([string]$Folder)
    return @([IO.Directory]::GetFileSystemEntries($Folder) | Where-Object { $_ -like '*.tmp' -or $_ -like '*.lock' }).Count
}

function Write-Fixture {
    # 픽스처 파일 - UTF-8 BOM(저장소가 쓰는 형식과 같게)
    param([string]$FilePath, [string]$Text)
    [IO.File]::WriteAllText($FilePath, $Text, (New-Object System.Text.UTF8Encoding($true)))
}

function Read-JournalFile {
    # 디스크의 JSON 을 저장소를 거치지 않고 그대로 읽습니다(저장소가 실제로 쓴 내용 확인용)
    param([string]$FilePath)
    return (ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($FilePath)))
}

function Get-JournalSeqText {
    # 디스크 파일의 seq(없으면 'none', 못 읽으면 'unreadable') - 앞 단언이 실패한 상태에서도 같은 케이스의 다음 단계(J10-2)가
    # 돌게 예외 대신 값으로 돌려줍니다
    param([string]$FilePath)
    if (-not [IO.File]::Exists($FilePath)) { return 'none' }
    try {
        return [string](Read-JournalFile $FilePath).seq
    } catch {
        return 'unreadable'
    }
}

function New-FixtureTempPath {
    # 저장소 임시 파일 명명 규칙(.abyss_handoff.json.<pid>.<guid>.tmp)을 따른 픽스처 경로
    param([string]$Folder, [string]$Tag)
    return (Join-Path $Folder ('.abyss_handoff.json.{0}.{1}.tmp' -f $Tag, [guid]::NewGuid().ToString('N')))
}

function New-JournalJson {
    # 유효한 journal 픽스처 JSON(version 1 + 필수 필드)
    param([long]$Seq, [string]$EntriesJson = '[]', [string]$AppliedJson = '[]', [string]$PendingJson = '[]', [string]$SavedBy = 'fixture')
    return ('{{"version":1,"seq":{0},"savedAt":"","savedBy":"{1}","entries":{2},"applied":{3},"pending":{4}}}' -f $Seq, $SavedBy, $EntriesJson, $AppliedJson, $PendingJson)
}

function Add-TestEntry {
    # 항목 1건(stage cleared · reason = 표지)을 더하는 표준 mutator 로 저장 → 저장 함수 반환값. mutator 는 클로저(체크리스트 6).
    param([string]$Path, [string]$Reason)
    $entryReason = $Reason
    $addMutator = { param($journal, $change)
        $entry = New-AbyssJournalEntry -Stage 'cleared'
        $entry.reason = $entryReason
        $journal.entries = @($journal.entries) + $entry
        $change.Changed = $true
    }.GetNewClosure()
    return (Update-AbyssJournal -Path $Path -Mutator $addMutator)
}

function New-CloseEntryMutator {
    # 단계 ② 닫기 함수(설계 R2 3.2)와 같은 모양의 mutator - 그 nonce 항목이 없거나 이미 launchState done 이면 바꾸지 않음(=unchanged),
    # 아니면 done + reason·screen 을 Add-Member -Force 로(ConvertFrom-Json 결과에 없는 속성 대입은 예외 - 체크리스트 7).
    param([string]$Nonce, [string]$Reason, [string]$Screen)
    $closeNonce = $Nonce
    $closeReason = $Reason
    $closeScreen = $Screen
    return ({ param($journal, $change)
            foreach ($entry in @($journal.entries)) {
                if ([string]$entry.nonce -ne $closeNonce) { continue }
                if ([string]$entry.launchState -eq 'done') { return }
                $entry.launchState = 'done'
                Add-Member -InputObject $entry -NotePropertyName 'reason' -NotePropertyValue $closeReason -Force
                Add-Member -InputObject $entry -NotePropertyName 'screen' -NotePropertyValue $closeScreen -Force
                $change.Changed = $true
                return
            }
        }.GetNewClosure())
}

# ===== 자식 프로세스 =====

function Start-JournalChild {
    # 자식 powershell 1개를 숨김 창으로 띄웁니다. Extra = 추가 인자(값이 $true 인 키는 스위치). 경로는 따옴표로 감쌉니다(규칙 3).
    param([string]$Name, [string]$Mode, [string]$BundleFile, [string]$MainPath, [hashtable]$Extra = @{})
    $argumentParts = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $script:childScriptPath + '"'),
        '-Mode', $Mode, '-Name', $Name,
        '-BundlePath', ('"' + $BundleFile + '"'),
        '-MainPath', ('"' + $MainPath + '"'),
        '-SignalDir', ('"' + $script:signalFolder + '"'))
    foreach ($key in @($Extra.Keys)) {
        $value = $Extra[$key]
        if ($value -is [bool]) {
            if ($value) { $argumentParts += ('-' + $key) }
        } else {
            $argumentParts += @(('-' + $key), ('"' + [string]$value + '"'))
        }
    }
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList ($argumentParts -join ' ') -WindowStyle Hidden -PassThru
    [void]$script:childProcesses.Add($process)
    return $process
}

function Wait-ChildSignal {
    # 자식이 만든 신호 파일을 기다립니다(최대 TimeoutMs). 못 보면 $false - 호출부가 FAIL 로 적고 다음으로 넘어갑니다.
    param([string]$Name, [string]$Suffix, [int]$TimeoutMs = 30000)
    $signalPath = Join-Path $script:signalFolder ($Name + '.' + $Suffix)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not [IO.File]::Exists($signalPath)) {
        if ($watch.ElapsedMilliseconds -gt $TimeoutMs) { return $false }
        [System.Threading.Thread]::Sleep(15)
    }
    return $true
}

function Send-ChildSignal {
    param([string]$Name, [string]$Suffix)
    [IO.File]::WriteAllText((Join-Path $script:signalFolder ($Name + '.' + $Suffix)), 'go')
}

function Wait-ChildExit {
    # 자식 종료를 기다립니다(최대 TimeoutMs) - 넘기면 강제 종료하고 $false
    param($Process, [int]$TimeoutMs = 30000)
    if ($Process.WaitForExit($TimeoutMs)) { return $true }
    Stop-ChildQuietly -Process $Process
    return $false
}

function Stop-ChildQuietly {
    # 자식 강제 종료(최선 시도) - 끝나는 중인 프로세스의 Kill 은 InvalidOperationException 이나 Win32Exception('액세스 거부')을
    # 내므로(변이 검증 중 실측) 종류를 가리지 않고 넘깁니다. 정리 단계가 케이스 판정을 가로채지 않게 하기 위함입니다.
    param($Process)
    try {
        if (-not $Process.HasExited) {
            $Process.Kill()
            [void]$Process.WaitForExit(5000)
        }
    } catch {
        # 이미 끝났거나 끝나는 중 - 남은 정리는 테스트 끝의 폴더 정리가 확인합니다
    }
}

function Read-ChildResult {
    # 자식 결과 파일(KEY=VALUE 줄) → 해시테이블(같은 키는 마지막 값) + Lines(전체 줄)
    param([string]$Name)
    $resultPath = Join-Path $script:signalFolder ($Name + '.result')
    $result = @{ Lines = @() }
    if (-not [IO.File]::Exists($resultPath)) { return $result }
    $lines = @([IO.File]::ReadAllLines($resultPath) | Where-Object { $_ -ne '' })
    $result.Lines = $lines
    foreach ($line in $lines) {
        $at = $line.IndexOf('=')
        if ($at -gt 0) { $result[$line.Substring(0, $at)] = $line.Substring($at + 1) }
    }
    return $result
}

function Get-ChildDiagnostic {
    # 신호를 못 보낸 자식의 상태 한 줄(종료 여부·결과 파일) - 실패 단언의 '실제' 칸에 씁니다
    param([string]$Name, $Process)
    $result = Read-ChildResult $Name
    $exitText = $(if ($Process.HasExited) { 'exit ' + $Process.ExitCode } else { '실행 중' })
    return ('신호 없음({0}) {1}' -f $exitText, ($result.Lines -join ' / '))
}

# ===== 동작 케이스(사본마다) =====

function Test-CaseJ01 {
    # J01 정상 RMW - 첫 저장은 Move(.bak 없음), 두 번째부터 File.Replace 가 .bak 을 직전본으로 덮어씀(실측). seq 는 1씩.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j01'
    $path = Get-JournalPath $folder
    $first = Add-TestEntry -Path $path -Reason 'j01-a'
    Assert-Case "$prefix J01 첫 저장 changed · seq 1 · .bak 없음" ('{0}/{1}/{2}' -f $first.Tag, (Read-JournalFile $path).seq, [IO.File]::Exists($path + '.bak')) 'changed/1/False'
    $second = Add-TestEntry -Path $path -Reason 'j01-b'
    $main = Read-JournalFile $path
    $bak = Read-JournalFile ($path + '.bak')
    Assert-Case "$prefix J01 두 번째 저장 seq 2 · .bak = 첫 저장본(seq 1 · 항목 1)" ('{0}/{1}/{2}/{3}' -f $second.Tag, $main.seq, $bak.seq, @($bak.entries).Count) 'changed/2/1/1'
    $third = Add-TestEntry -Path $path -Reason 'j01-c'
    $main = Read-JournalFile $path
    $bak = Read-JournalFile ($path + '.bak')
    Assert-Case "$prefix J01 세 번째 저장 - .bak 을 두 번째 저장본으로 덮어씀" ('{0}/{1}/{2}/{3}' -f $third.Tag, $main.seq, $bak.seq, (@($main.entries | ForEach-Object { $_.reason }) -join ',')) 'changed/3/2/j01-a,j01-b,j01-c'
    $savedAtText = [string]$main.savedAt
    $savedAt = ConvertFrom-AbyssJournalTime -Text $savedAtText
    $savedAtFresh = ($null -ne $savedAt) -and ([Math]::Abs(((Get-Date) - $savedAt).TotalMinutes) -lt 10)
    Assert-Case "$prefix J01 savedBy = 이 사본 표지 · savedAt = 왕복 'o' 형식(방금)" ('{0}/{1}/{2}' -f $main.savedBy, ($savedAtText -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$'), $savedAtFresh) ('{0}/True/True' -f $Context.SavedBy)
    Assert-Case "$prefix J01 폴더 = 본 파일 + .bak (잠금·임시 0)" (Get-FolderListing $folder) 'abyss_handoff.json|abyss_handoff.json.bak'
    $bytes = [IO.File]::ReadAllBytes($path)
    Assert-Case "$prefix X9 저장한 본 파일 첫 3바이트 = UTF-8 BOM" ('{0:X2}{1:X2}{2:X2}' -f $bytes[0], $bytes[1], $bytes[2]) 'EFBBBF'
}

function Test-CaseJ02 {
    # J02 잘린 본 파일(절반) - (c) .bak 채택: 손상본은 .corrupt.<yyyyMMdd_HHmmss> 로 보존, .bak 은 그대로, 본 파일은 .bak 내용 +
    #     seq = 아는 최대(.bak) + 1 로 복원, 경고 1. .bak 은 실제 저장 3번으로 만듭니다(교체가 Set-Content 로 바뀌면 .bak 이
    #     생기지 않아 여기서 실패 - 명세 변이 'Replace → Set-Content').
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j02'
    $path = Get-JournalPath $folder
    foreach ($reason in @('j02-a', 'j02-b', 'j02-c')) { [void](Add-TestEntry -Path $path -Reason $reason) }
    $bytes = [IO.File]::ReadAllBytes($path)
    $half = New-Object byte[] ([int][Math]::Floor($bytes.Length / 2))
    [Array]::Copy($bytes, $half, $half.Length)
    [IO.File]::WriteAllBytes($path, $half)
    $truncatedDigest = Get-FileDigest $path
    $bakDigest = Get-FileDigest ($path + '.bak')
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    $warnings = @($read.Result.Warnings)
    Assert-Case "$prefix J02 래퍼 ok · 분기 c · 경고 1(직전본 복구 문구) · throw 0" ('{0}/{1}/{2}/{3}/{4}' -f $read.Result.Status, $read.Result.Branch, $warnings.Count, ($warnings -join ' '), (Get-ErrorText $read.Error)) ('ok/c/1/{0}/' -f $WARNING_BAK_RESTORE)
    $restored = Read-JournalFile $path
    Assert-Case "$prefix J02 본 파일 복원 - seq = 아는 최대(.bak 2) + 1 · 항목 = 직전본" ('{0}/{1}' -f $restored.seq, (@($restored.entries | ForEach-Object { $_.reason }) -join ',')) '3/j02-a,j02-b'
    Assert-Case "$prefix J02 .bak 불변" ((Get-FileDigest ($path + '.bak')) -eq $bakDigest) 'True'
    $evidence = @([IO.Directory]::GetFiles($folder, 'abyss_handoff.json.corrupt.*'))
    $evidenceName = $(if ($evidence.Count -gt 0) { [IO.Path]::GetFileName($evidence[0]) } else { '' })
    $evidenceSame = ($evidence.Count -gt 0) -and ((Get-FileDigest $evidence[0]) -eq $truncatedDigest)
    Assert-Case "$prefix J02 손상 증거 1개 · 이름 .corrupt.<yyyyMMdd_HHmmss> · 내용 = 잘린 본 파일" ('{0}/{1}/{2}' -f $evidence.Count, ($evidenceName -match '^abyss_handoff\.json\.corrupt\.\d{8}_\d{6}$'), $evidenceSame) '1/True/True'
    Assert-Case "$prefix J02 임시·잠금 0" (Get-LeftoverCount $folder) 0
    $bytes = [IO.File]::ReadAllBytes($path)
    Assert-Case "$prefix X9 복원한 본 파일도 UTF-8 BOM" ('{0:X2}{1:X2}{2:X2}' -f $bytes[0], $bytes[1], $bytes[2]) 'EFBBBF'
    $after = Add-TestEntry -Path $path -Reason 'j02-d'
    Assert-Case "$prefix J02 복구 뒤 저장 이어짐(seq 4 · .bak = 복원본 seq 3)" ('{0}/{1}/{2}' -f $after.Tag, (Read-JournalFile $path).seq, (Read-JournalFile ($path + '.bak')).seq) 'changed/4/3'
}

function Test-CaseJ03 {
    # J03 교체 직전 종료 - 본 파일 유효 + 남은 .tmp(더 큰 seq): (a) 본 파일 그대로(본 파일이 있으면 .tmp 는 후보가 아님) · .tmp 청소.
    #     덧붙여 (a) 에서 .bak 의 seq 가 더 크면 본 파일을 쓰되 경고(구현 명세 0.5 J10 판정).
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j03'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'j03-a')
    $mainDigest = Get-FileDigest $path
    $strayTemp = New-FixtureTempPath $folder '3030'
    Write-Fixture $strayTemp (New-JournalJson -Seq 9)
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    Assert-Case "$prefix J03 분기 a · 경고 0 · 본 파일 불변 · 남은 .tmp 청소" ('{0}/{1}/{2}/{3}/{4}' -f $read.Result.Status, $read.Result.Branch, @($read.Result.Warnings).Count, ((Get-FileDigest $path) -eq $mainDigest), [IO.File]::Exists($strayTemp)) 'ok/a/0/True/False'
    $folder = New-CaseFolder $Context 'j03-bak-ahead'
    $path = Get-JournalPath $folder
    Write-Fixture $path (New-JournalJson -Seq 2 -AppliedJson '["main"]')
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 5 -AppliedJson '["bak"]')
    $stateBefore = Get-FolderState $folder
    $read = Read-AbyssJournal -Path $path
    $warnings = @($read.Warnings)
    Assert-Case "$prefix J03 (a) .bak seq 가 더 커도 본 파일 채택 + 경고 1 · 파일 불변" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $read.Status, $read.Branch, (@($read.Journal.applied) -join ','), $warnings.Count, ([string]($warnings -join '')).StartsWith('[경고]'), ((Get-FolderState $folder) -eq $stateBefore)) 'ok/a/main/1/True/True'
}

function Test-CaseJ04 {
    # J04 File.Replace 중간 상태(본 파일 → .bak 이름 바꾼 뒤, 임시 → 본 파일 전에 종료)
    #   J04-1 본 파일 없음 + .bak(4) + .tmp(5 = .bak + 1) → (b) 그 .tmp 를 Move 로 올림(바이트 그대로) · 나머지 .tmp 청소 · 경고
    #   J04-2 본 파일 없음 + .bak 만 → (c) .bak 내용으로 복원(seq 5) · .bak 불변 · 손상 증거 없음(본 파일이 없었음)
    #   J04-3 본 파일 없음 + .bak(4) + .tmp(9 - .bak + 1 아님) → (c), 복원 seq = 아는 최대(9) + 1 · .tmp 청소
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j04-tmp'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4 -EntriesJson '[{"nonce":"old"}]')
    $chosenTemp = New-FixtureTempPath $folder '4141'
    Write-Fixture $chosenTemp (New-JournalJson -Seq 5 -EntriesJson '[{"nonce":"old"},{"nonce":"new"}]' -AppliedJson '["x"]')
    $otherTemp = New-FixtureTempPath $folder '4242'
    Write-Fixture $otherTemp (New-JournalJson -Seq 3)
    $chosenDigest = Get-FileDigest $chosenTemp
    $bakDigest = Get-FileDigest ($path + '.bak')
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    Assert-Case "$prefix J04-1 (b) 임시본 채택 · 경고 = 교체 중 종료" ('{0}/{1}/{2}' -f $read.Result.Status, $read.Result.Branch, (@($read.Result.Warnings) -join ' ')) ('ok/b/{0}' -f $WARNING_TEMP_COMPLETE)
    Assert-Case "$prefix J04-1 본 파일 = 고른 .tmp(Move - 바이트 그대로) · 나머지 .tmp 청소 · .bak 불변" ('{0}/{1}/{2}' -f ((Get-FileDigest $path) -eq $chosenDigest), (Get-LeftoverCount $folder), ((Get-FileDigest ($path + '.bak')) -eq $bakDigest)) 'True/0/True'

    $folder = New-CaseFolder $Context 'j04-bak'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4 -EntriesJson '[{"nonce":"old"}]' -AppliedJson '["k"]')
    $bakDigest = Get-FileDigest ($path + '.bak')
    $read = Read-AbyssJournal -Path $path
    $main = Read-JournalFile $path
    Assert-Case "$prefix J04-2 .bak 만 → (c) 복원 seq 5 · applied 보존 · 경고 = 직전본 복구" ('{0}/{1}/{2}/{3}/{4}' -f $read.Status, $read.Branch, $main.seq, (@($main.applied) -join ','), (@($read.Warnings) -join ' ')) ('ok/c/5/k/{0}' -f $WARNING_BAK_RESTORE)
    Assert-Case "$prefix J04-2 .bak 불변 · 손상 증거 0 · 임시·잠금 0" ('{0}/{1}/{2}' -f ((Get-FileDigest ($path + '.bak')) -eq $bakDigest), @([IO.Directory]::GetFiles($folder, '*.corrupt.*')).Count, (Get-LeftoverCount $folder)) 'True/0/0'

    $folder = New-CaseFolder $Context 'j04-stale-tmp'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4)
    Write-Fixture (New-FixtureTempPath $folder '4343') (New-JournalJson -Seq 9)
    $read = Read-AbyssJournal -Path $path
    Assert-Case "$prefix J04-3 seq 가 .bak + 1 이 아닌 .tmp → (c) · 복원 seq = 아는 최대(9) + 1 · .tmp 청소" ('{0}/{1}/{2}/{3}' -f $read.Status, $read.Branch, (Read-JournalFile $path).seq, (Get-LeftoverCount $folder)) 'ok/c/10/0'
}

function Test-CaseJ05 {
    # J05 본 파일 없음에서 저장 - base 는 복구한 사본(.bak 또는 .tmp)이고 빈 journal 로 시작하지 않습니다(applied·pending 보존 -
    #     빈 journal 로 시작하면 완료 기록 소비 표시가 사라져 이중 계상).
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j05-bak'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 7 -EntriesJson '[{"nonce":"e-old","stage":"cleared"}]' -AppliedJson '["a1"]' -PendingJson '[{"nonce":"p1","stage":"inside-handoff"}]')
    $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'j05-new' }
    Assert-Case "$prefix J05 저장 changed · 복구 경고 1 · throw 0" ('{0}/{1}/{2}' -f $update.Result.Tag, (@($update.Result.Warnings) -join ' '), (Get-ErrorText $update.Error)) ('changed/{0}/' -f $WARNING_BAK_RESTORE)
    $main = Read-JournalFile $path
    $bak = Read-JournalFile ($path + '.bak')
    Assert-Case "$prefix J05 base = .bak - applied·pending·기존 항목 보존 · seq 9(복원 8 + 1) · .bak = 복원본 8" ('{0}/{1}/{2}/{3}/{4}' -f (@($main.applied) -join ','), (@($main.pending | ForEach-Object { $_.nonce }) -join ','), (@($main.entries | ForEach-Object { if ($_.nonce -eq 'e-old') { 'e-old' } else { $_.reason } }) -join ','), $main.seq, $bak.seq) 'a1/p1/e-old,j05-new/9/8'

    $folder = New-CaseFolder $Context 'j05-tmp'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 3 -AppliedJson '["old"]')
    Write-Fixture (New-FixtureTempPath $folder '5050') (New-JournalJson -Seq 4 -AppliedJson '["old","from-tmp"]')
    $update = Add-TestEntry -Path $path -Reason 'j05-after-tmp'
    $main = Read-JournalFile $path
    Assert-Case "$prefix J05 본 파일 없음 + .tmp(.bak + 1) → base = 임시본 · seq 5 · .bak = 임시본 4 · 경고 = 교체 중 종료" ('{0}/{1}/{2}/{3}/{4}' -f $update.Tag, (@($main.applied) -join ','), $main.seq, (Read-JournalFile ($path + '.bak')).seq, (@($update.Warnings) -join ' ')) ('changed/old,from-tmp/5/4/{0}' -f $WARNING_TEMP_COMPLETE)
}

function Test-CaseJ06 {
    # J06 두 프로세스 동시 저장 20회씩(이 사본 + 다른 사본 - 출발 신호로 맞춤): 잠금 아래 RMW 라 40건 전부 반영 · 중복·유실 0 ·
    #     각자의 순서 보존 · seq 연속(마지막 40 · .bak 39) · 임시·잠금 0
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j06'
    $path = Get-JournalPath $folder
    $names = @(($Context.Key + '-j06-a'), ($Context.Key + '-j06-b'))
    $bundleFiles = @($Context.ThisBundle, $Context.OtherBundle)
    $children = @()
    for ($index = 0; $index -lt 2; $index++) {
        $children += Start-JournalChild -Name $names[$index] -Mode 'update-loop' -BundleFile $bundleFiles[$index] -MainPath $path -Extra @{ Count = 20 }
    }
    $readyA = Wait-ChildSignal -Name $names[0] -Suffix 'ready'
    $readyB = Wait-ChildSignal -Name $names[1] -Suffix 'ready'
    if (-not ($readyA -and $readyB)) {
        Assert-Case "$prefix J06 자식 둘 준비" ('{0} | {1}' -f (Get-ChildDiagnostic $names[0] $children[0]), (Get-ChildDiagnostic $names[1] $children[1])) 'ready'
        return
    }
    foreach ($childName in $names) { Send-ChildSignal -Name $childName -Suffix 'go' }
    $exited = @($children | ForEach-Object { Wait-ChildExit -Process $_ -TimeoutMs 90000 })
    $tagSummary = @()
    foreach ($childName in $names) {
        $result = Read-ChildResult $childName
        $tags = @($result.Lines | Where-Object { $_ -like 'TAG=*' })
        $changedCount = @($tags | Where-Object { $_ -eq 'TAG=changed' }).Count
        $tagSummary += ('{0}/{1}{2}' -f $tags.Count, $changedCount, [string]$result['ERROR'])
    }
    Assert-Case "$prefix J06 두 자식(이 사본·다른 사본) 모두 20회 저장 changed" ('{0}|{1}' -f ($exited -join ','), ($tagSummary -join ',')) 'True,True|20/20,20/20'
    $main = Read-JournalFile $path
    $reasons = @($main.entries | ForEach-Object { [string]$_.reason })
    $orderKept = $true
    $missingCount = 0
    foreach ($childName in $names) {
        $expectedOwn = @(for ($number = 1; $number -le 20; $number++) { '{0}-{1}' -f $childName, $number })
        $actualOwn = @($reasons | Where-Object { $_.StartsWith($childName + '-') })
        $missingCount += @($expectedOwn | Where-Object { $actualOwn -notcontains $_ }).Count
        if (($actualOwn -join ',') -cne ($expectedOwn -join ',')) { $orderKept = $false }
    }
    Assert-Case "$prefix J06 둘 다 반영 - 40건 · 중복 0 · 유실 0 · 각자 순서 보존" ('{0}/{1}/{2}/{3}' -f $reasons.Count, @($reasons | Sort-Object -Unique).Count, $missingCount, $orderKept) '40/40/0/True'
    Assert-Case "$prefix J06 seq 연속(본 파일 40 · .bak 39) · 임시·잠금 0" ('{0}/{1}/{2}' -f $main.seq, (Read-JournalFile ($path + '.bak')).seq, (Get-LeftoverCount $folder)) '40/39/0'
}

function Test-CaseJ07 {
    # J07 -Expect 불일치 → expect-failed(정식 태그 - 명세 리뷰 1): mutator 를 부르지 않고 쓰기 0(파일 불변), 재시도 대기도 없음
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j07'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'j07-a')
    [void](Add-TestEntry -Path $path -Reason 'j07-b')
    $stateBefore = Get-FolderState $folder
    $calls = @{ Mutator = 0 }
    $falseExpect = { param($journal) return $false }.GetNewClosure()
    $countingMutator = { param($journal, $change) $calls.Mutator++; $change.Changed = $true }.GetNewClosure()
    $outcome = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $countingMutator -Expect $falseExpect }
    Assert-Case "$prefix J07 expect-failed · mutator 0회 · throw 0 · 대기 0" ('{0}/{1}/{2}/{3}' -f $outcome.Result.Tag, $calls.Mutator, (Get-ErrorText $outcome.Error), $outcome.Sleeps) 'expect-failed/0//0'
    Assert-Case "$prefix J07 파일 불변(본 파일·.bak·목록) · 임시·잠금 0" ('{0}/{1}' -f ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/0'
}

function Test-CaseJ08 {
    # J08 잠금 쥔 프로세스 Kill - OS 가 핸들을 닫으며 DeleteOnClose 로 .lock 이 지워져(실측) 다음 저장이 기다림 없이 성공.
    #     잠금은 자식이 묶음의 Open-AbyssJournalLock 으로 쥡니다(DeleteOnClose 를 빼는 변이가 여기서 드러나게).
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j08'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'j08-a')
    $childName = $Context.Key + '-j08-holder'
    $holder = Start-JournalChild -Name $childName -Mode 'lock' -BundleFile $Context.ThisBundle -MainPath $path
    if (-not (Wait-ChildSignal -Name $childName -Suffix 'ready')) {
        Assert-Case "$prefix J08 잠금 쥔 자식 준비" (Get-ChildDiagnostic $childName $holder) 'ready'
        return
    }
    $lockWhileHeld = [IO.File]::Exists((Get-LockPath $folder))
    $holder.Kill()
    $exited = Wait-ChildExit -Process $holder
    Assert-Case "$prefix J08 잠금 보유 중 .lock 있음 → Kill 뒤 사라짐(DeleteOnClose)" ('{0}/{1}/{2}' -f $lockWhileHeld, $exited, [IO.File]::Exists((Get-LockPath $folder))) 'True/True/False'
    $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'j08-after-kill' }
    Assert-Case "$prefix J08 Kill 뒤 다음 저장 즉시 성공(changed · 대기 0)" ('{0}/{1}/{2}' -f $update.Result.Tag, $update.Sleeps, (Read-JournalFile $path).seq) 'changed/0/2'
}

function Test-CaseJ09 {
    # J09 잠금 점유 중 - 다른 프로세스가 묶음의 Open-AbyssJournalLock 으로 잠금을 쥔 동안 저장·래퍼 둘 다 20회 × 50ms 뒤 locked ·
    #     throw 0 · 파일 불변. X5 HResult 고정: 그 .lock 에 CreateNew = IOException 0x80070050(파일 있음 - 실측. 공유 위반 0x80070020
    #     이 아님) - 저장소는 이 값을 경합(locked)으로 봅니다.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j09'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'j09-a')
    $childName = $Context.Key + '-j09-holder'
    $holder = Start-JournalChild -Name $childName -Mode 'lock' -BundleFile $Context.ThisBundle -MainPath $path
    try {
        if (-not (Wait-ChildSignal -Name $childName -Suffix 'ready')) {
            Assert-Case "$prefix J09 잠금 쥔 자식 준비" (Get-ChildDiagnostic $childName $holder) 'ready'
            return
        }
        $stateBefore = Get-FolderState $folder
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'j09-blocked' }
        Assert-Case "$prefix J09 저장 = locked · throw 0 · 대기 19번 × 50ms" ('{0}/{1}/{2}/{3}' -f $update.Result.Tag, (Get-ErrorText $update.Error), $update.Sleeps, $update.SleepMs) ('locked//{0}/{1}' -f $BUDGET_SLEEP_COUNT, ($BUDGET_SLEEP_COUNT * $BUDGET_SLEEP_MS))
        $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
        Assert-Case "$prefix J09 래퍼 = locked · throw 0 · 대기 19번" ('{0}/{1}/{2}' -f $read.Result.Status, (Get-ErrorText $read.Error), $read.Sleeps) ('locked//{0}' -f $BUDGET_SLEEP_COUNT)
        Assert-Case "$prefix J09 예산만큼 실제로 기다림(≥ 900ms · 실제 $($update.ElapsedMs)ms)" ($update.ElapsedMs -ge 900) 'True'
        Assert-Case "$prefix J09 파일 불변" ((Get-FolderState $folder) -eq $stateBefore) 'True'
        Assert-Case "$prefix X5 HResult 고정 - 다른 프로세스가 쥔 .lock 의 CreateNew" (Get-CreateNewFailure (Get-LockPath $folder)) 'IOException/0x80070050'
    } finally {
        Send-ChildSignal -Name $childName -Suffix 'release'
        [void](Wait-ChildExit -Process $holder)
    }
}

function Test-CaseJ10 {
    # J10 Replace IOException 주입 - 자식이 본 파일을 FileShare.Read(삭제 공유 없음)로 쥐면 File.Replace 가 IOException.
    #   J10-1 쓰는 쪽 임시 파일이 생긴 뒤 300ms 더 쥐었다 놓음 → 같은 예산 안 재시도로 성공(대기 1~18번)
    #   J10-2 = X5-1 예산보다 오래 쥠(부모가 돌아온 뒤 놓음) → 20회 뒤 io-failed · throw 0 · 본 파일·.bak 불변 · 임시·잠금 0
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j10'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'j10-a')
    $shortName = $Context.Key + '-j10-short'
    $shortHolder = Start-JournalChild -Name $shortName -Mode 'hold-main' -BundleFile $Context.ThisBundle -MainPath $path -Extra @{ HoldAfterTempMs = 300 }
    if (Wait-ChildSignal -Name $shortName -Suffix 'ready') {
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'j10-b' }
        # 저장이 교체 전에 끝났으면 자식이 임시 파일을 못 봤을 수 있어 놓으라고 알립니다(정상이면 이미 놓고 끝나는 중)
        Send-ChildSignal -Name $shortName -Suffix 'release'
        $exited = Wait-ChildExit -Process $shortHolder
        $shortResult = Read-ChildResult $shortName
        Assert-Case "$prefix J10-1 교체가 막혔다 풀림(자식이 임시 파일을 봄) → 같은 예산 안 재시도 성공(대기 $($update.Sleeps)번) · throw 0" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $update.Result.Tag, ($update.Sleeps -ge 1 -and $update.Sleeps -lt $BUDGET_SLEEP_COUNT), (Get-ErrorText $update.Error), $exited, $shortResult['SAW_TEMP'], [string]$shortResult['ERROR']) 'changed/True//True/1/'
        Assert-Case "$prefix J10-1 결과 seq 2 · .bak = 직전본 1 · 임시·잠금 0" ('{0}/{1}/{2}' -f (Get-JournalSeqText $path), (Get-JournalSeqText ($path + '.bak')), (Get-LeftoverCount $folder)) '2/1/0'
    } else {
        Assert-Case "$prefix J10-1 본 파일 쥔 자식 준비" (Get-ChildDiagnostic $shortName $shortHolder) 'ready'
    }
    $longName = $Context.Key + '-j10-long'
    $longHolder = Start-JournalChild -Name $longName -Mode 'hold-main' -BundleFile $Context.ThisBundle -MainPath $path
    try {
        if (-not (Wait-ChildSignal -Name $longName -Suffix 'ready')) {
            Assert-Case "$prefix J10-2 본 파일 쥔 자식 준비" (Get-ChildDiagnostic $longName $longHolder) 'ready'
            return
        }
        $stateBefore = Get-FolderState $folder
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'j10-c' }
        Assert-Case "$prefix J10-2·X5-1 예산보다 오래 쥠(IOException) → io-failed · throw 0 · 대기 19번" ('{0}/{1}/{2}' -f $update.Result.Tag, (Get-ErrorText $update.Error), $update.Sleeps) ('io-failed//{0}' -f $BUDGET_SLEEP_COUNT)
        Assert-Case "$prefix J10-2·X5-1 본 파일·.bak 불변 · 임시·잠금 0(잠금 해제)" ('{0}/{1}' -f ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/0'
    } finally {
        Send-ChildSignal -Name $longName -Suffix 'release'
        [void](Wait-ChildExit -Process $longHolder)
    }
}

function Test-CaseJ11 {
    # J11 version 불일치 = 손상(유효 = 파싱 ∧ version 1 ∧ seq·entries·applied·pending 존재) - 단독이면 corrupt(파일 불변),
    #     유효한 .bak 이 있으면 (c) 직전본 복구(손상본은 증거로). 필수 필드가 빠진 본 파일도 같은 취급.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $futureJson = '{"version":2,"seq":5,"savedAt":"","savedBy":"future","entries":[],"applied":[],"pending":[]}'
    $folder = New-CaseFolder $Context 'j11-alone'
    $path = Get-JournalPath $folder
    Write-Fixture $path $futureJson
    $stateBefore = Get-FolderState $folder
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    Assert-Case "$prefix J11 version 2 단독 → corrupt(분기 e) · throw 0 · 파일 불변" ('{0}/{1}/{2}/{3}' -f $read.Result.Status, $read.Result.Branch, (Get-ErrorText $read.Error), ((Get-FolderState $folder) -eq $stateBefore)) 'corrupt/e//True'
    $folder = New-CaseFolder $Context 'j11-with-bak'
    $path = Get-JournalPath $folder
    Write-Fixture $path $futureJson
    $futureDigest = Get-FileDigest $path
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 3 -AppliedJson '["j11"]')
    $read = Read-AbyssJournal -Path $path
    $evidence = @([IO.Directory]::GetFiles($folder, 'abyss_handoff.json.corrupt.*'))
    $evidenceSame = ($evidence.Count -eq 1) -and ((Get-FileDigest $evidence[0]) -eq $futureDigest)
    $main = Read-JournalFile $path
    Assert-Case "$prefix J11 version 2 + 유효 .bak → (c) 복구 · 손상 증거 = version 2 본 파일 · version 1 · seq 4" ('{0}/{1}/{2}/{3}/{4}' -f $read.Status, $read.Branch, $evidenceSame, $main.version, $main.seq) 'ok/c/True/1/4'
    $folder = New-CaseFolder $Context 'j11-missing-field'
    $path = Get-JournalPath $folder
    Write-Fixture $path '{"version":1,"seq":2,"savedAt":"","savedBy":"x","entries":[],"applied":[]}'
    $read = Read-AbyssJournal -Path $path
    Assert-Case "$prefix J11 필수 필드(pending) 없음 → corrupt" ('{0}/{1}' -f $read.Status, $read.Branch) 'corrupt/e'
}

function Test-CaseJ12 {
    # J12 본 파일·.bak 둘 다 손상 → corrupt(분기 e): 저장도 래퍼도 corrupt · 재시도 없음(대기 0) · throw 0 · 파일 불변(지우지도
    #     옮기지도 않음 - 사용자가 옮긴 뒤 시작). GUI 행동은 ⑯, 워커 클릭·키 0 은 단계 ②.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j12'
    $path = Get-JournalPath $folder
    Write-Fixture $path '{"version":1,"seq":'
    Write-Fixture ($path + '.bak') 'not json at all'
    $stateBefore = Get-FolderState $folder
    $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'j12' }
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    Assert-Case "$prefix J12 저장 corrupt · 래퍼 corrupt · throw 0 · 대기 0" ('{0}/{1}/{2}/{3}/{4}' -f $update.Result.Tag, $read.Result.Status, (Get-ErrorText $update.Error), (Get-ErrorText $read.Error), ($update.Sleeps + $read.Sleeps)) 'corrupt/corrupt///0'
    Assert-Case "$prefix J12 파일 불변(목록·내용) · 임시·잠금 0" ('{0}/{1}' -f ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/0'
}

function Test-CaseJ13 {
    # J13 JSON 왕복 - 항목 1·0개, owner 5필드 + 형제 generation(-Depth 10 - 기본 2 면 owner 가 문자열로 무너짐 - 실측), 빈 applied 의
    #     .Count 0, 모르는 필드(항목·중첩·최상위) 보존, 스키마 기본값 screen ''·cleanupOnly false 보존(C04), "pending": null → 빈 배열,
    #     Where-Object 1건·0건을 @() 없이 대입한 mutator 뒤에도 배열, 한글 원문 보존. 헬퍼 진리표(owner 비교·단계 순위·시각) 포함.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j13'
    $path = Get-JournalPath $folder
    $entryJson = '{"nonce":"n-13","runId":"","section":"abyssCustomRepeat","generation":4,' +
        '"owner":{"fingerprint":"지문-13","orderKey":"순서-13","lap":2,"index":1,"item":"룬다 어려움 1-1"},"nextOwner":null,' +
        '"stage":"cleared","launchState":"pending","reason":"","screen":"","cleanupOnly":false,' +
        '"futureNote":"보존할 값","extra":{"flag":true,"depth":{"inner":[1,2]}}}'
    Write-Fixture $path ('{"version":1,"seq":3,"savedAt":"","savedBy":"fixture","entries":[' + $entryJson + '],"applied":[],"pending":null,"topFuture":{"note":"상위 모르는 필드"}}')
    $read = Read-AbyssJournal -Path $path
    $journal = $read.Journal
    Assert-Case "$prefix J13 읽기 정규화 - 항목 1개 배열 · 빈 applied .Count 0 · pending null → 빈 배열" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $read.Status, ($journal.entries -is [array]), $journal.entries.Count, $journal.applied.Count, ($journal.pending -is [array]), $journal.pending.Count) 'ok/True/1/0/True/0'

    $appliedMutator = { param($journal, $change)
        $journal.applied = @($journal.applied) + 'n-0'
        $change.Changed = $true
    }.GetNewClosure()
    $outcome = Update-AbyssJournal -Path $path -Mutator $appliedMutator
    $rawText = [IO.File]::ReadAllText($path)
    $raw = ConvertFrom-Json -InputObject $rawText
    $entry = @($raw.entries)[0]
    Assert-Case "$prefix J13 저장 changed · 항목 1개도 배열([) · pending 은 [] · applied 반영" ('{0}/{1}/{2}/{3}' -f $outcome.Tag, ($rawText -match '"entries":\s*\['), ($rawText -match '"pending":\s*\[\s*\]'), (@($raw.applied) -join ',')) 'changed/True/True/n-0'
    Assert-Case "$prefix J13 owner = 5필드 객체 + 형제 generation" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f ($entry.owner -is [System.Management.Automation.PSCustomObject]), $entry.owner.fingerprint, $entry.owner.orderKey, $entry.owner.lap, $entry.owner.index, $entry.owner.item, $entry.generation) 'True/지문-13/순서-13/2/1/룬다 어려움 1-1/4'
    Assert-Case "$prefix J13 owner lap·index·generation 은 정수로 왕복" ('{0}/{1}/{2}' -f (Get-TypeNameText $entry.owner.lap), (Get-TypeNameText $entry.owner.index), (Get-TypeNameText $entry.generation)) 'Int32/Int32/Int32'
    Assert-Case "$prefix J13 모르는 필드 보존(항목 futureNote · 중첩 extra.flag·extra.depth.inner · 최상위 topFuture)" ('{0}/{1}/{2}/{3}' -f $entry.futureNote, $entry.extra.flag, (@($entry.extra.depth.inner) -join '+'), $raw.topFuture.note) '보존할 값/True/1+2/상위 모르는 필드'
    Assert-Case "$prefix J13 스키마 기본값 왕복 - screen '' (문자열) · cleanupOnly false (bool)" ('{0}/{1}/{2}/{3}' -f ($null -ne $entry.PSObject.Properties['screen']), ($entry.screen -is [string] -and $entry.screen -eq ''), ($entry.cleanupOnly -is [bool]), $entry.cleanupOnly) 'True/True/True/False'
    Assert-Case "$prefix J13 한글 원문 그대로(이스케이프 복원 - 사람이 읽게)" ($rawText.Contains('룬다 어려움 1-1') -and $rawText.Contains('보존할 값')) 'True'

    $filterOneMutator = { param($journal, $change)
        $journal.entries = $journal.entries | Where-Object { $_.nonce -eq 'n-13' }
        $change.Changed = $true
    }.GetNewClosure()
    $outcome = Update-AbyssJournal -Path $path -Mutator $filterOneMutator
    $rawText = [IO.File]::ReadAllText($path)
    Assert-Case "$prefix J13 Where-Object 1건을 @() 없이 대입한 mutator 뒤에도 배열로 저장" ('{0}/{1}/{2}' -f $outcome.Tag, ($rawText -match '"entries":\s*\['), @((ConvertFrom-Json -InputObject $rawText).entries).Count) 'changed/True/1'
    $filterNoneMutator = { param($journal, $change)
        $journal.entries = $journal.entries | Where-Object { $_.nonce -eq 'no-such-nonce' }
        $change.Changed = $true
    }.GetNewClosure()
    $outcome = Update-AbyssJournal -Path $path -Mutator $filterNoneMutator
    $rawText = [IO.File]::ReadAllText($path)
    $reread = Read-AbyssJournal -Path $path
    Assert-Case "$prefix J13 Where-Object 0건 → 항목 0개 [] · 다시 읽어도 .Count 0" ('{0}/{1}/{2}' -f $outcome.Tag, ($rawText -match '"entries":\s*\[\s*\]'), $reread.Journal.entries.Count) 'changed/True/0'

    $newEntryMutator = { param($journal, $change)
        $created = New-AbyssJournalEntry -Stage 'cleared'
        $created.owner = [pscustomobject]@{ fingerprint = 'f-13'; orderKey = ''; lap = 0; index = 3; item = '항목' }
        $created.generation = 2
        $journal.entries = @($journal.entries) + $created
        $change.Changed = $true
    }.GetNewClosure()
    $outcome = Update-AbyssJournal -Path $path -Mutator $newEntryMutator
    $rawText = [IO.File]::ReadAllText($path)
    $created = @((ConvertFrom-Json -InputObject $rawText).entries)[0]
    Assert-Case "$prefix J13 새 항목 기본값 왕복 - nonce GUID(D) · stage · launchState pending · decision null · 횟수 0" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $outcome.Tag, ([string]$created.nonce -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'), $created.stage, $created.launchState, ($null -eq $created.decision), ($created.attempts + $created.retryClicks + $created.resumeAttempts)) 'changed/True/cleared/pending/True/0'
    Assert-Case "$prefix J13 새 항목 기본값 왕복 - afterEntry {0, null, null} · at.* null · screen '' · cleanupOnly false" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $created.afterEntry.index, ($null -eq $created.afterEntry.total -and $null -eq $created.afterEntry.keys), ($null -eq $created.at.entered -and $null -eq $created.at.cleared -and $null -eq $created.at.reentered), ($rawText -match '"screen":\s*""'), ($rawText -match '"cleanupOnly":\s*false'), ($created.cleanupOnly -is [bool])) '0/True/True/True/True/True'

    # owner 비교 진리표 - 디스크에서 다시 읽은 항목(PSCustomObject)과 메모리 owner(해시테이블). 세대는 지금이 높은 쪽(3)과 낮은 쪽(1 -
    # 항목 세대 2 가 지금보다 높은 역행) 둘 다 불일치입니다(계약은 '같음' - 2026-10-09 변이 검증 보강: 높은 쪽만 있으면 '-ge' 로 바꿔도 같은 답)
    $ownerRows = @(
        @(@{ fingerprint = 'f-13'; orderKey = ''; lap = 0; index = 3; item = '항목' }, 2),
        @(@{ fingerprint = 'f-13'; lap = 0; index = 3; item = '항목' }, 2),
        @(@{ fingerprint = 'f-13'; orderKey = ''; lap = 0; index = 3; item = '항목' }, 3),
        @(@{ fingerprint = 'f-13'; orderKey = ''; lap = 0; index = 3; item = '항목' }, 1),
        @(@{ fingerprint = 'f-13'; orderKey = ''; lap = 0; index = 4; item = '항목' }, 2),
        @(@{ fingerprint = 'f-13'; orderKey = ''; lap = 0; index = 3; item = '다른 항목' }, 2),
        @(@{ fingerprint = 'f-13'; orderKey = ''; lap = 1; index = 3; item = '항목' }, 2),
        @(@{ fingerprint = 'f-xx'; orderKey = ''; lap = 0; index = 3; item = '항목' }, 2),
        @(@{ fingerprint = 'f-13'; orderKey = 'k'; lap = 0; index = 3; item = '항목' }, 2),
        @(@{ fingerprint = 'f-13'; orderKey = ''; lap = '0'; index = '3'; item = '항목' }, 2))
    $ownerResults = @($ownerRows | ForEach-Object { Test-AbyssJournalOwnerMatch -Entry $created -Owner $_[0] -Generation $_[1] })
    Assert-Case "$prefix J13 owner 비교(같음 / orderKey 없음 = '' / generation 다름(지금이 높음·낮음)·index·item·lap·fingerprint·orderKey 다름 / 문자열 숫자)" ($ownerResults -join ',') 'True,True,False,False,False,False,False,False,False,True'
    $runEntry = [pscustomobject]@{ owner = [pscustomobject]@{ runId = 'r-1' }; nextOwner = [pscustomobject]@{ runId = 'r-9' } }
    $noGenerationEntry = [pscustomobject]@{ owner = [pscustomobject]@{ fingerprint = 'f'; orderKey = ''; lap = 0; index = 0; item = 'i' } }
    $runResults = @(
        (Test-AbyssJournalOwnerMatch -Entry $runEntry -Owner @{ runId = 'r-1' }),
        (Test-AbyssJournalOwnerMatch -Entry $runEntry -Owner @{ runId = 'r-2' }),
        (Test-AbyssJournalOwnerMatch -Entry $runEntry -Owner @{ runId = 'r-9' } -Field 'nextOwner'),
        (Test-AbyssJournalOwnerMatch -Entry $noGenerationEntry -Owner @{ fingerprint = 'f'; orderKey = ''; lap = 0; index = 0; item = 'i' } -Generation 0),
        (Test-AbyssJournalOwnerMatch -Entry $runEntry -Owner $null))
    Assert-Case "$prefix J13 owner 비교(runId 같음 / 다름 / nextOwner / 항목 generation 없음 / owner 없음)" ($runResults -join ',') 'True,False,True,False,False'
    $ranks = @(@('entered', 'cleared', 'retry-attempt', 'retry-clicked', 'reentered', 'post-clear-stop', '', 'unknown') | ForEach-Object { Get-AbyssJournalStageRank -Stage $_ })
    Assert-Case "$prefix J13 단계 순위(entered 0 < cleared 1 < retry-attempt 2 < retry-clicked 3 < reentered 4 · post-clear-stop = cleared · 모름 -1)" ($ranks -join ',') '0,1,2,3,4,1,-1,-1'
    $parsed = ConvertFrom-AbyssJournalTime -Text '2026-10-08T18:28:21.0934628+09:00'
    $timeResults = @(($null -eq (ConvertFrom-AbyssJournalTime -Text '')), ($null -eq (ConvertFrom-AbyssJournalTime -Text 'not-a-time')),
        $parsed.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffff'), (ConvertFrom-AbyssJournalTime -Text (Get-AbyssJournalTimeText)).GetType().Name)
    Assert-Case "$prefix J13 시각 - 빈 값·형식 오류 null · 왕복 형식은 오프셋 반영 · 쓰기 형식을 다시 읽음" ($timeResults -join '/') 'True/True/2026-10-08T09:28:21.0934628/DateTime'
}

function Test-CaseJ16 {
    # J16 쓰는 쪽 정지 - 다른 프로세스가 잠금을 쥔 채 교체 중간 상태(본 파일 없음 + .bak + .tmp)에서 멈춤. 별도 프로세스의 **워커
    #     사본** 래퍼는 locked 이고 파일을 건드리지 않음(.tmp 를 먼저 올리지 않음) → 쓰는 쪽이 재개해 교체를 마치면 다음 읽기 정상 ·
    #     seq 연속(10 → 11 → 12). 원문의 Consume-Handoff 쪽 행동(클릭·키 0·코드 4)은 단계 ②.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j16'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 10 -EntriesJson '[{"nonce":"w-10"}]')
    $writerTemp = New-FixtureTempPath $folder '1616'
    Write-Fixture $writerTemp (New-JournalJson -Seq 11 -EntriesJson '[{"nonce":"w-10"},{"nonce":"w-11"}]')
    $writerName = $Context.Key + '-j16-writer'
    $writer = Start-JournalChild -Name $writerName -Mode 'lock' -BundleFile $Context.ThisBundle -MainPath $path -Extra @{ CompleteTemp = $writerTemp }
    try {
        if (-not (Wait-ChildSignal -Name $writerName -Suffix 'ready')) {
            Assert-Case "$prefix J16 쓰는 쪽 자식 준비" (Get-ChildDiagnostic $writerName $writer) 'ready'
            return
        }
        $stateBefore = Get-FolderState $folder
        $wrapperName = $Context.Key + '-j16-wrapper'
        $wrapper = Start-JournalChild -Name $wrapperName -Mode 'wrapper' -BundleFile $Context.WorkerBundle -MainPath $path
        $wrapperExited = Wait-ChildExit -Process $wrapper
        $wrapperResult = Read-ChildResult $wrapperName
        Assert-Case "$prefix J16 별도 프로세스의 워커 사본 래퍼 = locked · throw 0" ('{0}/{1}/{2}/{3}' -f $wrapperExited, $wrapperResult['STATUS'], $wrapperResult['WARN'], $wrapperResult['ERROR']) 'True/locked/0/'
        Assert-Case "$prefix J16 래퍼가 파일을 바꾸지 않음(.tmp 이동 0 · .bak 불변 · 본 파일 없음)" ('{0}/{1}' -f ((Get-FolderState $folder) -eq $stateBefore), [IO.File]::Exists($path)) 'True/False'
    } finally {
        Send-ChildSignal -Name $writerName -Suffix 'release'
        $writerExited = Wait-ChildExit -Process $writer
    }
    $writerResult = Read-ChildResult $writerName
    $read = Read-AbyssJournal -Path $path
    Assert-Case "$prefix J16 쓰는 쪽 재개·완료 → 다음 읽기 정상(분기 a · 경고 0 · seq 11)" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $writerExited, $writerResult['DONE'], $read.Status, $read.Branch, @($read.Warnings).Count, $read.Journal.seq) 'True/1/ok/a/0/11'
    $update = Add-TestEntry -Path $path -Reason 'j16-next'
    Assert-Case "$prefix J16 seq 연속(.bak 10 → 교체 완료 11 → 다음 저장 12 · .bak 11) · 임시·잠금 0" ('{0}/{1}/{2}/{3}' -f $update.Tag, (Read-JournalFile $path).seq, (Read-JournalFile ($path + '.bak')).seq, (Get-LeftoverCount $folder)) 'changed/12/11/0'
}

function Test-CaseJ17 {
    # J17 쓰는 쪽 Kill 뒤 래퍼 1회 - DeleteOnClose 로 잠금이 풀리고 (b) 복구 1회: 쓰는 쪽 .tmp(seq = .bak + 1)를 Move 로 본 파일에
    #     올림(바이트 그대로) · 나머지 .tmp(무효 찌꺼기) 청소 · 경고 1
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j17'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 10)
    $writerTemp = New-FixtureTempPath $folder '1717'
    Write-Fixture $writerTemp (New-JournalJson -Seq 11 -EntriesJson '[{"nonce":"w-11"}]')
    Write-Fixture (New-FixtureTempPath $folder '9999') '{"version":1,"seq":'
    $writerDigest = Get-FileDigest $writerTemp
    $bakDigest = Get-FileDigest ($path + '.bak')
    $writerName = $Context.Key + '-j17-writer'
    $writer = Start-JournalChild -Name $writerName -Mode 'lock' -BundleFile $Context.ThisBundle -MainPath $path
    if (-not (Wait-ChildSignal -Name $writerName -Suffix 'ready')) {
        Assert-Case "$prefix J17 쓰는 쪽 자식 준비" (Get-ChildDiagnostic $writerName $writer) 'ready'
        return
    }
    $writer.Kill()
    $writerExited = Wait-ChildExit -Process $writer
    $wrapperName = $Context.Key + '-j17-wrapper'
    $wrapper = Start-JournalChild -Name $wrapperName -Mode 'wrapper' -BundleFile $Context.ThisBundle -MainPath $path
    $wrapperExited = Wait-ChildExit -Process $wrapper
    $wrapperResult = Read-ChildResult $wrapperName
    Assert-Case "$prefix J17 Kill 뒤 래퍼 1회 → (b) 복구 · 경고 1(교체 중 종료)" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $writerExited, $wrapperExited, $wrapperResult['STATUS'], $wrapperResult['BRANCH'], $wrapperResult['WARN'], $wrapperResult['WARNING']) ('True/True/ok/b/1/{0}' -f $WARNING_TEMP_COMPLETE)
    Assert-Case "$prefix J17 본 파일 = 쓰는 쪽 임시본(바이트 그대로) · .bak 불변 · .tmp 전부 청소 · 잠금 0" ('{0}/{1}/{2}' -f ((Get-FileDigest $path) -eq $writerDigest), ((Get-FileDigest ($path + '.bak')) -eq $bakDigest), (Get-LeftoverCount $folder)) 'True/True/0'
}

function Test-CaseJ18 {
    # J18 래퍼 둘이 동시에(이 사본 + 다른 사본, 출발 신호로 맞춤) 같은 중간 상태를 읽음 - 잠금 아래에서 다시 읽으므로 복구는 1번:
    #     하나는 (b) 복구 + 경고, 다른 하나는 복구된 본 파일 (a). seq·파일 수 불변(11 · 본 파일 + .bak)
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j18'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 10)
    Write-Fixture (New-FixtureTempPath $folder '1818') (New-JournalJson -Seq 11)
    $bakDigest = Get-FileDigest ($path + '.bak')
    $names = @(($Context.Key + '-j18-a'), ($Context.Key + '-j18-b'))
    $bundleFiles = @($Context.ThisBundle, $Context.OtherBundle)
    $wrappers = @()
    for ($index = 0; $index -lt 2; $index++) {
        $wrappers += Start-JournalChild -Name $names[$index] -Mode 'wrapper' -BundleFile $bundleFiles[$index] -MainPath $path -Extra @{ Barrier = $true }
    }
    $readyA = Wait-ChildSignal -Name $names[0] -Suffix 'ready'
    $readyB = Wait-ChildSignal -Name $names[1] -Suffix 'ready'
    if (-not ($readyA -and $readyB)) {
        Assert-Case "$prefix J18 래퍼 둘 준비" ('{0} | {1}' -f (Get-ChildDiagnostic $names[0] $wrappers[0]), (Get-ChildDiagnostic $names[1] $wrappers[1])) 'ready'
        return
    }
    foreach ($childName in $names) { Send-ChildSignal -Name $childName -Suffix 'go' }
    $exited = @($wrappers | ForEach-Object { Wait-ChildExit -Process $_ })
    $results = @($names | ForEach-Object { Read-ChildResult $_ })
    $branches = @($results | ForEach-Object { '{0}{1}:{2}' -f $_['STATUS'], $_['BRANCH'], $_['WARN'] } | Sort-Object)
    Assert-Case "$prefix J18 동시 래퍼 → 복구 1번(b + 경고 1) · 나머지 a" ('{0}|{1}' -f ($exited -join ','), ($branches -join ',')) 'True,True|oka:0,okb:1'
    Assert-Case "$prefix J18 seq 11 그대로 · 파일 = 본 파일 + .bak · .bak 불변" ('{0}/{1}/{2}' -f (Read-JournalFile $path).seq, (Get-FolderListing $folder), ((Get-FileDigest ($path + '.bak')) -eq $bakDigest)) '11/abyss_handoff.json|abyss_handoff.json.bak/True'
}

function Test-CaseJ19 {
    # J19 Unlocked 는 순수 읽기 - 교체 중간 상태(b)·손상 본 파일 + .bak(c)·본 파일 유효 + 남은 .tmp(a) 에서도 고르기만 하고 파일
    #     변경 0(이동·청소·손상 증거 0). 진단·표시 전용이고 결정은 잠금 래퍼 결과로만 합니다. (a) 행은 변이 검증 생존 보강 - Unlocked
    #     (a) 에 .tmp 청소를 넣는 변이가 (b)·(c) 행만으로는 살아남았습니다(래퍼의 (a) 청소는 J03).
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j19-a'
    $path = Get-JournalPath $folder
    Write-Fixture $path (New-JournalJson -Seq 3)
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 5)
    Write-Fixture (New-FixtureTempPath $folder '1918') (New-JournalJson -Seq 9)
    $stateBefore = Get-FolderState $folder
    $read = Read-AbyssJournalUnlocked -Path $path
    Assert-Case "$prefix J19 (a) 상태(본 파일 유효 + 남은 .tmp · 더 큰 .bak) Unlocked → 분기 a · 경고 1 · 파일 변경 0(.tmp 청소 0)" ('{0}/{1}/{2}/{3}' -f $read.Status, $read.Branch, @($read.Warnings).Count, ((Get-FolderState $folder) -eq $stateBefore)) 'ok/a/1/True'
    $folder = New-CaseFolder $Context 'j19-b'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 1)
    Write-Fixture (New-FixtureTempPath $folder '1919') (New-JournalJson -Seq 2)
    $stateBefore = Get-FolderState $folder
    $read = Read-AbyssJournalUnlocked -Path $path
    Assert-Case "$prefix J19 (b) 상태 Unlocked → 분기 b · seq 2 · 파일 변경 0" ('{0}/{1}/{2}/{3}' -f $read.Status, $read.Branch, $read.Journal.seq, ((Get-FolderState $folder) -eq $stateBefore)) 'ok/b/2/True'
    $folder = New-CaseFolder $Context 'j19-c'
    $path = Get-JournalPath $folder
    Write-Fixture $path '{"version":1,"seq":'
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 1)
    $stateBefore = Get-FolderState $folder
    $read = Read-AbyssJournalUnlocked -Path $path
    Assert-Case "$prefix J19 (c) 상태 Unlocked → 분기 c · 파일 변경 0(손상본 이동·복원 0)" ('{0}/{1}/{2}/{3}' -f $read.Status, $read.Branch, $read.Journal.seq, ((Get-FolderState $folder) -eq $stateBefore)) 'ok/c/1/True'
    # 폴더 없음 - 임시 파일 목록의 '폴더 없음'(IOException 하위)은 임시 파일 없음으로 → 파일이 하나도 없음(d). catch 절을 2개로 줄이며
    # IOException 절 안의 -is 로 옮긴 갈래를 지킵니다(래퍼·저장은 잠금 단계에서 먼저 io-failed - X5-4).
    $missingFolder = Join-Path $Context.Root 'j19-missing-folder'
    $read = Measure-JournalCall { Read-AbyssJournalUnlocked -Path (Get-JournalPath $missingFolder) }
    Assert-Case "$prefix J19 폴더 없음 Unlocked → 분기 d(빈 journal) · throw 0 · 폴더를 만들지 않음" ('{0}/{1}/{2}/{3}/{4}' -f $read.Result.Status, $read.Result.Branch, $read.Result.Journal.seq, (Get-ErrorText $read.Error), [IO.Directory]::Exists($missingFolder)) 'ok/d/0//False'
}

function Test-CaseJ20 {
    # J20 잠금을 쥔 채 Held - Update 는 래퍼가 아니라 Held 를 부릅니다: 같은 프로세스는 자기가 쥔 .lock 을 다시 열 수 없어(실측 -
    #     X5 HResult 고정) 래퍼라면 locked 가 됩니다. Held 는 다시 잠그지 않고(대기 0) (b) 복구까지 하고, Update 도 자기 잠금
    #     아래에서 같은 복구를 거쳐 저장합니다.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'j20'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 1)
    $temp = New-FixtureTempPath $folder '2020'
    Write-Fixture $temp (New-JournalJson -Seq 2 -EntriesJson '[{"nonce":"j20"}]')
    $held = Open-AbyssJournalLock -Path $path -Budget @{ Left = 20 }
    try {
        Assert-Case "$prefix J20 잠금 획득" ($null -ne $held.Stream) 'True'
        if ($null -eq $held.Stream) { return }
        Assert-Case "$prefix X5 HResult 고정 - 같은 프로세스가 쥔 .lock 의 CreateNew" (Get-CreateNewFailure (Get-LockPath $folder)) 'IOException/0x80070050'
        $wrapper = Measure-JournalCall { Read-AbyssJournal -Path $path }
        Assert-Case "$prefix J20 대조 - 같은 프로세스의 래퍼는 재잠금 불가로 locked(파일 변경 0)" ('{0}/{1}/{2}' -f $wrapper.Result.Status, $wrapper.Sleeps, [IO.File]::Exists($temp)) ('locked/{0}/True' -f $BUDGET_SLEEP_COUNT)
        $heldRead = Measure-JournalCall { Read-AbyssJournalHeld -Path $path }
        Assert-Case "$prefix J20 잠금 보유 중 Held → 재잠금 없이(대기 0) (b) 복구 · 경고 1" ('{0}/{1}/{2}/{3}' -f $heldRead.Result.Status, $heldRead.Result.Branch, $heldRead.Sleeps, @($heldRead.Result.Warnings).Count) 'ok/b/0/1'
    } finally {
        if ($null -ne $held.Stream) { $held.Stream.Dispose() }
    }
    Assert-Case "$prefix J20 복구 결과 - 본 파일 seq 2 · .tmp 0 · 잠금 해제" ('{0}/{1}' -f (Read-JournalFile $path).seq, (Get-LeftoverCount $folder)) '2/0'
    $folder = New-CaseFolder $Context 'j20-update'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 1)
    Write-Fixture (New-FixtureTempPath $folder '2021') (New-JournalJson -Seq 2)
    $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'j20-update' }
    Assert-Case "$prefix J20 Update 안 Held - 자기 잠금 아래 (b) 복구 후 저장(changed · 경고 1 · 대기 0 · seq 3 · .bak 2)" ('{0}/{1}/{2}/{3}/{4}' -f $update.Result.Tag, @($update.Result.Warnings).Count, $update.Sleeps, (Read-JournalFile $path).seq, (Read-JournalFile ($path + '.bak')).seq) 'changed/1/0/3/2'
}

function Test-CaseN1s {
    # N1s mutator 가 바꾸지 않음(닫을 항목이 journal 에 없음 - stale 정리 뒤) → unchanged · 쓰기 0. 같은 내용을 다시 Replace 하면
    #     본 파일 바이트 비교로는 못 잡으므로 .bak 에 본 파일과 다른 표지 내용을 미리 두고 그대로인지 봅니다(설계 R2 11.1) +
    #     폴더 목록 + 본 파일 바이트.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'n1s'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'n1-a')
    [void](Add-TestEntry -Path $path -Reason 'n1-b')
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 1 -AppliedJson '["bak-marker"]' -SavedBy 'bak-marker')
    $mainDigest = Get-FileDigest $path
    $bakDigest = Get-FileDigest ($path + '.bak')
    $listing = Get-FolderListing $folder
    $closeMutator = New-CloseEntryMutator -Nonce 'no-such-nonce' -Reason 'abandoned-death-exit' -Screen 'field'
    $outcome = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $closeMutator }
    Assert-Case "$prefix N1s 닫을 항목 없음 → unchanged · throw 0 · 대기 0" ('{0}/{1}/{2}' -f $outcome.Result.Tag, (Get-ErrorText $outcome.Error), $outcome.Sleeps) 'unchanged//0'
    Assert-Case "$prefix N1s 쓰기 0 - .bak 표지 내용 그대로 · 본 파일 바이트 불변 · 폴더 목록 불변" ('{0}/{1}/{2}' -f ((Get-FileDigest ($path + '.bak')) -eq $bakDigest), ((Get-FileDigest $path) -eq $mainDigest), ((Get-FolderListing $folder) -eq $listing)) 'True/True/True'
}

function Test-CaseN2s {
    # N2s 이미 done 인 항목에 다시 done → unchanged · 기존 reason·screen 불변 · 쓰기 0. 대조: 아직 안 닫힌 항목(screen 필드 없음)은
    #     닫힘(changed - 없는 필드는 Add-Member -Force) - mutator 가 실제로 동작하는데도 무변경이었음을 보입니다.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'n2s'
    $path = Get-JournalPath $folder
    $entriesJson = '[{"nonce":"n2-done","stage":"cleared","launchState":"done","reason":"first-reason","screen":"field"},' +
        '{"nonce":"n2-open","stage":"cleared","launchState":"launched","reason":""}]'
    Write-Fixture $path (New-JournalJson -Seq 5 -EntriesJson $entriesJson)
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4 -AppliedJson '["bak-marker"]' -SavedBy 'bak-marker')
    $mainDigest = Get-FileDigest $path
    $bakDigest = Get-FileDigest ($path + '.bak')
    $closeDone = New-CloseEntryMutator -Nonce 'n2-done' -Reason 'cleanup-only' -Screen 'selection-proven'
    $outcome = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $closeDone }
    $doneEntry = @((Read-JournalFile $path).entries | Where-Object { $_.nonce -eq 'n2-done' })[0]
    Assert-Case "$prefix N2s 이미 done → unchanged · reason·screen 불변 · 본 파일·.bak 바이트 불변" ('{0}/{1}/{2}/{3}/{4}' -f $outcome.Result.Tag, $doneEntry.reason, $doneEntry.screen, ((Get-FileDigest $path) -eq $mainDigest), ((Get-FileDigest ($path + '.bak')) -eq $bakDigest)) 'unchanged/first-reason/field/True/True'
    $closeOpen = New-CloseEntryMutator -Nonce 'n2-open' -Reason 'cleanup-only' -Screen 'selection-proven'
    $outcome = Update-AbyssJournal -Path $path -Mutator $closeOpen
    $entries = @((Read-JournalFile $path).entries)
    $openEntry = @($entries | Where-Object { $_.nonce -eq 'n2-open' })[0]
    $doneEntry = @($entries | Where-Object { $_.nonce -eq 'n2-done' })[0]
    Assert-Case "$prefix N2s 대조 - 안 닫힌 항목은 닫힘(changed · done · reason·screen 기록) · 닫힌 항목은 그대로" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $outcome.Tag, $openEntry.launchState, $openEntry.reason, $openEntry.screen, $doneEntry.reason, $doneEntry.screen) 'changed/done/cleanup-only/selection-proven/first-reason/field'
}

function Test-CaseE7s {
    # E7s mutator throw → 예외가 저장 함수 밖으로(태그 아님 - 구현 결함은 워커 최상위 catch 의 코드 1 + 오류 세트로 드러나야 함) ·
    #     본 파일·.bak 불변 · 임시 0 · 바로 다음 저장 성공(바깥 try/finally 가 잠금을 풀었음 - 대기 0)
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'e7s'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'e7-a')
    [void](Add-TestEntry -Path $path -Reason 'e7-b')
    $stateBefore = Get-FolderState $folder
    $throwingMutator = { param($journal, $change)
        $change.Changed = $true
        throw 'mutator 결함 주입'
    }.GetNewClosure()
    $outcome = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $throwingMutator }
    Assert-Case "$prefix E7s mutator 예외는 저장 함수 밖으로(반환값 없음 · 같은 메시지)" ('{0}/{1}' -f ($null -eq $outcome.Result), (Get-ErrorText $outcome.Error)) 'True/mutator 결함 주입'
    Assert-Case "$prefix E7s 본 파일·.bak·목록 불변 · 임시·잠금 0" ('{0}/{1}' -f ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/0'
    $next = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'e7-next' }
    Assert-Case "$prefix E7s 바로 다음 저장 성공(잠금 해제 - 대기 0 · seq 3)" ('{0}/{1}/{2}' -f $next.Result.Tag, $next.Sleeps, (Read-JournalFile $path).seq) 'changed/0/3'
}

function Test-CaseX1 {
    # X1 읽는 쪽 공유 모드 - 묶음의 후보 읽기가 [IO.File]::Open 에 넘기는 공유 값(소스에서 그대로 꺼냄)으로 본 파일을 연 채 저장 →
    #     File.Replace 성공. 그 공유 값에 Delete 가 빠지면 읽는 동안 교체가 실패합니다(실측 - 명세 변이 '읽기 공유에서 Delete 제거').
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $shareText = $Context.ReadShareText
    $shareValue = $null
    if ($shareText) { $shareValue = [IO.FileShare](Invoke-Expression $shareText) }
    Assert-Case "$prefix X1 읽기 공유 값에 Delete 포함(원문 $shareText)" (($null -ne $shareValue) -and (($shareValue -band [IO.FileShare]::Delete) -ne 0)) 'True'
    if ($null -eq $shareValue) { return }
    $folder = New-CaseFolder $Context 'x1'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'x1-a')
    [void](Add-TestEntry -Path $path -Reason 'x1-b')
    $reader = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, $shareValue)
    try {
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'x1-while-open' }
    } finally {
        $reader.Dispose()
    }
    Assert-Case "$prefix X1 읽는 쪽이 본 파일을 연 채 저장 → changed · 재시도 0 · seq 3" ('{0}/{1}/{2}' -f $update.Result.Tag, $update.Sleeps, (Read-JournalFile $path).seq) 'changed/0/3'
}

function Test-CaseX2 {
    # X2 본 파일·.bak 없이 무효 .tmp 만(첫 쓰기 도중 종료 - 명세 5절 C2). 구현 리뷰 2.1 로 (d) 가 '본 파일·.bak 둘 다 없음' 이 되어
    #     corrupt 가 아니라 빈 journal(d)입니다 - 남은 .tmp 는 유효하든 아니든 확정되지 않은 첫 쓰기라 올리지 않고 잠금 아래에서 청소
    #     (2.1 전 기대: 래퍼·저장 corrupt · .tmp 보존). 래퍼와 저장은 폴더를 따로 둡니다 - 래퍼가 먼저 청소하면 저장 행이 같은 상태를 못 봄.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'x2-read'
    $path = Get-JournalPath $folder
    $strayTemp = New-FixtureTempPath $folder '2222'
    Write-Fixture $strayTemp '{"version":1,"seq":'
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    Assert-Case "$prefix X2 무효 .tmp 단독 → 래퍼 ok/d(빈 journal - seq 0 · 항목 0) · 경고 0 · throw 0 · .tmp 청소 · 본 파일 안 만듦" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}/{7}' -f $read.Result.Status, $read.Result.Branch, $read.Result.Journal.seq, @($read.Result.Journal.entries).Count, @($read.Result.Warnings).Count, (Get-ErrorText $read.Error), [IO.File]::Exists($strayTemp), [IO.File]::Exists($path)) 'ok/d/0/0/0//False/False'
    $folder = New-CaseFolder $Context 'x2-update'
    $path = Get-JournalPath $folder
    $strayTemp = New-FixtureTempPath $folder '2223'
    Write-Fixture $strayTemp '{"version":1,"seq":'
    $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'x2' }
    $main = $null
    if ([IO.File]::Exists($path)) { $main = Read-JournalFile $path }
    Assert-Case "$prefix X2 무효 .tmp 단독 → 저장 changed(빈 journal 에서 - seq 1 · 항목 = 새 저장 1건) · 경고 0 · throw 0 · .tmp 청소 · .bak 없음" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $update.Result.Tag, @($update.Result.Warnings).Count, (Get-ErrorText $update.Error), $main.seq, (@($main.entries | ForEach-Object { $_.reason }) -join ','), (Get-LeftoverCount $folder), [IO.File]::Exists($path + '.bak')) 'changed/0//1/x2/0/False'
}

function Test-CaseP1a {
    # P1a 구현 리뷰 2.1 P1 회귀 - '실패라고 알린 저장' 이 나중에 커밋되지 않음. 본 파일·.bak 없음에서 첫 저장의 Move 가 예산 끝까지
    #     실패(본 파일 자리에 같은 이름 폴더)하고, 그 저장이 만든 임시본을 자식이 Delete 공유 없이(FileShare.Read) 쥐어 실패 직전 삭제도
    #     실패 → io-failed + 경고 '임시본을 지우지 못했습니다' 1. 자식이 놓고 폴더를 지운 뒤 다음 읽기는 (d) 빈 journal 이고 그 임시본을
    #     청소합니다(2.1 전에는 (b) 가 .bak 없이도 올려 실패한 저장이 본 파일이 됐음) · 다음 저장도 빈 journal 에서 시작.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'p1a'
    $path = Get-JournalPath $folder
    [void][IO.Directory]::CreateDirectory($path)
    $childName = $Context.Key + '-p1a-temp-holder'
    $holder = Start-JournalChild -Name $childName -Mode 'hold-new-temp' -BundleFile $Context.ThisBundle -MainPath $path
    $update = $null
    $held = $false
    $leftoverNames = @()
    $folderKept = $false
    $lockLeft = $true
    try {
        if (-not (Wait-ChildSignal -Name $childName -Suffix 'ready')) {
            Assert-Case "$prefix P1a 임시본 쥘 자식 준비" (Get-ChildDiagnostic $childName $holder) 'ready'
            return
        }
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'p1a-failed' }
        $held = Wait-ChildSignal -Name $childName -Suffix 'held' -TimeoutMs 2000
        $leftoverNames = @([IO.Directory]::GetFiles($folder, '*.tmp') | ForEach-Object { [IO.Path]::GetFileName($_) })
        $folderKept = [IO.Directory]::Exists($path)
        $lockLeft = [IO.File]::Exists((Get-LockPath $folder))
    } finally {
        # 자식부터 놓게 합니다(폴더 제거가 예외로 멈춰도 자식이 60초 대기에 남지 않게) → 본 파일 자리의 폴더 제거
        Send-ChildSignal -Name $childName -Suffix 'release'
        $exited = Wait-ChildExit -Process $holder
        if ([IO.Directory]::Exists($path)) { [IO.Directory]::Delete($path) }
    }
    $childResult = Read-ChildResult $childName
    $warnings = @($update.Result.Warnings)
    $matching = @($warnings | Where-Object { ([string]$_).Contains($WARNING_TEMP_DELETE_FRAGMENT) }).Count
    Assert-Case "$prefix P1a 첫 저장 Move 가 예산 끝까지 실패(본 파일 자리 = 폴더) → io-failed · throw 0 · 대기 19번 · 경고 1(임시본을 지우지 못했습니다)" ('{0}/{1}/{2}/{3}/{4}' -f $update.Result.Tag, (Get-ErrorText $update.Error), $update.Sleeps, $warnings.Count, $matching) ('io-failed//{0}/1/1' -f $BUDGET_SLEEP_COUNT)
    $heldSame = ($leftoverNames.Count -eq 1) -and ([string]$childResult['HELD'] -ceq $leftoverNames[0])
    Assert-Case "$prefix P1a 실패 직후 - 자식이 쥔 새 임시본 1개가 남음(삭제 실패) · 본 파일 자리 폴더 그대로 · 잠금 해제 · 자식 정상 종료" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $held, $leftoverNames.Count, $heldSame, $folderKept, $lockLeft, $exited, [string]$childResult['ERROR']) 'True/1/True/True/False/True/'
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    Assert-Case "$prefix P1a 폴더 제거·자식 해제 뒤 읽기 → ok/d · 빈 journal(seq 0 · 항목 0) · 경고 0 · 그 임시본 청소 · 본 파일 안 만듦(실패한 저장이 커밋되지 않음)" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $read.Result.Status, $read.Result.Branch, $read.Result.Journal.seq, @($read.Result.Journal.entries).Count, @($read.Result.Warnings).Count, (Get-LeftoverCount $folder), [IO.File]::Exists($path)) 'ok/d/0/0/0/0/False'
    $next = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'p1a-next' }
    $main = $null
    if ([IO.File]::Exists($path)) { $main = Read-JournalFile $path }
    Assert-Case "$prefix P1a 다음 저장도 빈 journal 에서(changed · seq 1 · 항목 = 새 저장만 - p1a-failed 없음 · .bak 없음)" ('{0}/{1}/{2}/{3}' -f $next.Result.Tag, $main.seq, (@($main.entries | ForEach-Object { $_.reason }) -join ','), [IO.File]::Exists($path + '.bak')) 'changed/1/p1a-next/False'
}

function Test-CaseP1c {
    # P1c 구현 리뷰 2.1 확인 라운드 - io-failed 직전 임시본 삭제가 접근 거부(UnauthorizedAccessException)로 실패해도 '남음' 으로 판정.
    #     P1a 와 같은 셋업(본 파일 자리에 같은 이름 폴더 → 첫 저장의 Move 가 예산 끝까지 실패)인데, 자식이 그 저장이 만든 임시본을 쥐지
    #     않고 읽기 전용 속성만 겁니다 - 삭제는 공유 위반(P1a 의 IOException)이 아니라 접근 거부로 실패합니다(2026-10-08 실측: 삭제
    #     0x80070005 · Move 는 대상이 폴더라 0x800700B7 · 남은 읽기 전용 임시본에 File.Exists 참). → io-failed + 경고 '임시본을 지우지
    #     못했습니다' 1 · 임시본이 읽기 전용으로 남음. 정리(읽기 전용 해제 · 폴더 제거) 뒤 읽기는 (d) 빈 journal 이고 그 임시본을 청소합니다.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'p1c'
    $path = Get-JournalPath $folder
    [void][IO.Directory]::CreateDirectory($path)
    $childName = $Context.Key + '-p1c-temp-marker'
    $marker = Start-JournalChild -Name $childName -Mode 'readonly-new-temp' -BundleFile $Context.ThisBundle -MainPath $path
    $update = $null
    $marked = $false
    $leftoverNames = @()
    $readOnlyLeft = $false
    $folderKept = $false
    $lockLeft = $true
    try {
        if (-not (Wait-ChildSignal -Name $childName -Suffix 'ready')) {
            Assert-Case "$prefix P1c 읽기 전용 걸 자식 준비" (Get-ChildDiagnostic $childName $marker) 'ready'
            return
        }
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'p1c-failed' }
        $marked = Wait-ChildSignal -Name $childName -Suffix 'marked' -TimeoutMs 2000
        $leftoverPaths = @([IO.Directory]::GetFiles($folder, '*.tmp'))
        $leftoverNames = @($leftoverPaths | ForEach-Object { [IO.Path]::GetFileName($_) })
        $readOnlyLeft = ($leftoverPaths.Count -eq 1) -and ([IO.File]::GetAttributes($leftoverPaths[0])).HasFlag([IO.FileAttributes]::ReadOnly)
        $folderKept = [IO.Directory]::Exists($path)
        $lockLeft = [IO.File]::Exists((Get-LockPath $folder))
    } finally {
        # 자식을 먼저 끝내고(더 걸지 않게) → 남은 임시본의 읽기 전용 해제 → 본 파일 자리의 폴더 제거. 단언이 실패하거나 예외로 멈춰도
        # 읽기 전용 파일이 남아 다음 읽기의 청소·테스트 끝 정리를 막지 않게 여기서 풉니다.
        Send-ChildSignal -Name $childName -Suffix 'release'
        $exited = Wait-ChildExit -Process $marker
        foreach ($leftoverPath in @([IO.Directory]::GetFiles($folder, '*.tmp'))) {
            [IO.File]::SetAttributes($leftoverPath, [IO.FileAttributes]::Normal)
        }
        if ([IO.Directory]::Exists($path)) { [IO.Directory]::Delete($path) }
    }
    $childResult = Read-ChildResult $childName
    $warnings = @($update.Result.Warnings)
    $matching = @($warnings | Where-Object { ([string]$_).Contains($WARNING_TEMP_DELETE_FRAGMENT) }).Count
    Assert-Case "$prefix P1c 첫 저장 Move 가 예산 끝까지 실패(본 파일 자리 = 폴더) · 임시본 읽기 전용 → io-failed · throw 0 · 대기 19번 · 경고 1(임시본을 지우지 못했습니다 - 접근 거부 갈래)" ('{0}/{1}/{2}/{3}/{4}' -f $update.Result.Tag, (Get-ErrorText $update.Error), $update.Sleeps, $warnings.Count, $matching) ('io-failed//{0}/1/1' -f $BUDGET_SLEEP_COUNT)
    $markedSame = ($leftoverNames.Count -eq 1) -and ([string]$childResult['MARKED'] -ceq $leftoverNames[0])
    Assert-Case "$prefix P1c 실패 직후 - 자식이 읽기 전용을 건 새 임시본 1개가 읽기 전용 그대로 남음(삭제 실패) · 본 파일 자리 폴더 그대로 · 잠금 해제 · 자식 정상 종료" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}/{7}' -f $marked, $leftoverNames.Count, $markedSame, $readOnlyLeft, $folderKept, $lockLeft, $exited, [string]$childResult['ERROR']) 'True/1/True/True/True/False/True/'
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    Assert-Case "$prefix P1c 읽기 전용 해제·폴더 제거 뒤 읽기 → ok/d · 빈 journal(seq 0 · 항목 0) · 경고 0 · 그 임시본 청소 · 본 파일 안 만듦(실패한 저장이 커밋되지 않음)" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $read.Result.Status, $read.Result.Branch, $read.Result.Journal.seq, @($read.Result.Journal.entries).Count, @($read.Result.Warnings).Count, (Get-LeftoverCount $folder), [IO.File]::Exists($path)) 'ok/d/0/0/0/0/False'
}

function Test-CaseP1b {
    # P1b 본 파일·.bak 없음 + 유효 .tmp 단독(첫 저장이 Move 전에 끝난 모양) → 분기 d(빈 journal) · .tmp 청소 · 본 파일을 만들지 않음.
    #     구현 리뷰 2.1 P1: (b) 는 유효 .bak 이 있고 seq = .bak + 1 일 때만 올립니다 - '.bak 없음' 을 허용하면 확정되지 않은 첫 쓰기
    #     (P1a 처럼 실패라고 알린 저장일 수 있음)가 본 파일로 올라갑니다.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'p1b'
    $path = Get-JournalPath $folder
    $strayTemp = New-FixtureTempPath $folder '1b1b'
    Write-Fixture $strayTemp (New-JournalJson -Seq 1 -EntriesJson '[{"nonce":"p1b"}]' -AppliedJson '["p1b"]')
    $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    $journal = $read.Result.Journal
    Assert-Case "$prefix P1b 유효 .tmp 단독 → 래퍼 ok/d · 빈 journal(seq 0 · 항목·applied 0) · 경고 0 · throw 0" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $read.Result.Status, $read.Result.Branch, $journal.seq, @($journal.entries).Count, @($journal.applied).Count, @($read.Result.Warnings).Count, (Get-ErrorText $read.Error)) 'ok/d/0/0/0/0/'
    Assert-Case "$prefix P1b .tmp 청소 · 본 파일 안 만듦 · .bak 없음 · 잠금 0" ('{0}/{1}/{2}/{3}' -f [IO.File]::Exists($strayTemp), [IO.File]::Exists($path), [IO.File]::Exists($path + '.bak'), (Get-LeftoverCount $folder)) 'False/False/False/0'
}

function Test-CaseP2a {
    # P2a (a) 의 .bak 읽기 IO 실패(구현 리뷰 2.1) - 본 파일이 유효하면 .bak 을 못 읽어도 판정에 쓰지 않고 경고 1줄('직전본을 읽지
    #     못했습니다') · ok/a · 파일 변경 0. .bak 은 이 프로세스가 FileShare.None 으로 쥡니다(X10·X11 과 같은 방식). 대조: 놓은 뒤 다음
    #     읽기는 경고 0. 임시본 목록 읽기 실패 쪽은 P2a 정적(Test-BundleTempListWarning - 동작으로 재현하지 못한 이유는 그 함수 주석).
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'p2a'
    $path = Get-JournalPath $folder
    Write-Fixture $path (New-JournalJson -Seq 3 -AppliedJson '["main"]')
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 2 -AppliedJson '["bak"]')
    $stateBefore = Get-FolderState $folder
    $holder = [IO.File]::Open(($path + '.bak'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    try {
        $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    } finally {
        $holder.Dispose()
    }
    $warnings = @($read.Result.Warnings)
    $matching = @($warnings | Where-Object { ([string]$_).Contains($WARNING_BAK_UNREADABLE_FRAGMENT) }).Count
    Assert-Case "$prefix P2a 본 파일 유효 + .bak 읽기 막힘(FileShare.None) → ok/a · 본 파일 채택 · 경고 1(직전본을 읽지 못했습니다) · throw 0 · 대기 0" ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $read.Result.Status, $read.Result.Branch, (@($read.Result.Journal.applied) -join ','), $warnings.Count, $matching, (Get-ErrorText $read.Error), $read.Sleeps) 'ok/a/main/1/1//0'
    Assert-Case "$prefix P2a 파일 변경 0(본 파일·.bak 바이트·목록) · 임시·잠금 0" ('{0}/{1}' -f ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/0'
    $after = Read-AbyssJournal -Path $path
    Assert-Case "$prefix P2a 대조 - .bak 을 놓은 뒤 다음 읽기는 ok/a · 경고 0" ('{0}/{1}/{2}' -f $after.Status, $after.Branch, @($after.Warnings).Count) 'ok/a/0'
}

function Test-CaseP2b {
    # P2b unchanged·expect-failed 의 '쓰기 0' 은 그 호출의 논리 변경 기준(구현 리뷰 2.1 P2 계약): 교체 중간 상태(본 파일 없음 + 유효
    #     .bak + .tmp(seq = .bak + 1))에서 바꾸지 않는 저장이어도 잠금 아래 재판독의 (b) 복구 쓰기(고른 .tmp → 본 파일 Move)는 따로
    #     일어나고 Warnings 에 복구 경고가 실림 · 그 뒤 같은 저장은 진짜 쓰기 0(본 파일·.bak 바이트·목록 불변). 두 태그를 같은 셋업으로.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    foreach ($via in @('unchanged', 'expect-failed')) {
        $folder = New-CaseFolder $Context ('p2b-' + $via)
        $path = Get-JournalPath $folder
        Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4 -EntriesJson '[{"nonce":"p2b-old"}]')
        $chosenTemp = New-FixtureTempPath $folder '2b2b'
        Write-Fixture $chosenTemp (New-JournalJson -Seq 5 -EntriesJson '[{"nonce":"p2b-old"},{"nonce":"p2b-new"}]' -AppliedJson '["p2b"]')
        $chosenDigest = Get-FileDigest $chosenTemp
        $bakDigest = Get-FileDigest ($path + '.bak')
        $calls = @{ Mutator = 0 }
        $countingMutator = { param($journal, $change) $calls.Mutator++; $change.Changed = $true }.GetNewClosure()
        $falseExpect = { param($journal) return $false }.GetNewClosure()
        $keepMutator = New-CloseEntryMutator -Nonce 'no-such-nonce' -Reason 'p2b' -Screen 'field'
        if ($via -eq 'unchanged') {
            $first = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $keepMutator }
        } else {
            $first = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $countingMutator -Expect $falseExpect }
        }
        Assert-Case "$prefix P2b $via - 교체 중간 상태에서 바꾸지 않는 저장 → $via · 경고 = 교체 중 종료(복구 경고) · throw 0 · 대기 0 · mutator 쓰기 0" ('{0}/{1}/{2}/{3}/{4}' -f $first.Result.Tag, (@($first.Result.Warnings) -join ' '), (Get-ErrorText $first.Error), $first.Sleeps, $calls.Mutator) ('{0}/{1}//0/0' -f $via, $WARNING_TEMP_COMPLETE)
        Assert-Case "$prefix P2b $via - 복구 쓰기는 별개: 본 파일이 생김 = 고른 .tmp(Move - 바이트 그대로) · .bak 불변 · 임시·잠금 0" ('{0}/{1}/{2}/{3}' -f [IO.File]::Exists($path), ((Get-FileDigest $path) -eq $chosenDigest), ((Get-FileDigest ($path + '.bak')) -eq $bakDigest), (Get-LeftoverCount $folder)) 'True/True/True/0'
        $stateAfterRecovery = Get-FolderState $folder
        if ($via -eq 'unchanged') {
            $second = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $keepMutator }
        } else {
            $second = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $countingMutator -Expect $falseExpect }
        }
        Assert-Case "$prefix P2b $via - 두 번째 같은 저장 → $via · 경고 0 · 쓰기 0(본 파일·.bak 바이트·목록 불변)" ('{0}/{1}/{2}/{3}' -f $second.Result.Tag, @($second.Result.Warnings).Count, ((Get-FolderState $folder) -eq $stateAfterRecovery), $calls.Mutator) ('{0}/0/True/0' -f $via)
    }
}

function Test-CaseX3 {
    # X3 클로저 mutator · X6 클로저 Expect - 저장 함수(Update-AbyssJournal)의 지역 변수와 같은 이름(소스의 대입 대상에서 고름)의
    #     호출부 변수를 읽어도 호출부 값(계약 고정). 대조: 클로저가 아닌 블록은 동적 스코프라 저장 함수 지역 변수에 가려짐(실측 근거).
    #     이 함수는 그 이름들을 지역 변수로 두므로 다른 케이스와 따로 두고, 자기 변수는 x3 접두로 이름이 겹치지 않게 합니다.
    param([hashtable]$Context)
    $x3Prefix = $Context.Prefix
    $x3Folder = New-CaseFolder $Context 'x3'
    $x3Path = Get-JournalPath $x3Folder
    [void](Add-TestEntry -Path $x3Path -Reason 'x3-a')
    $x3Names = @($Context.UpdateLocalNames | Where-Object { -not $_.StartsWith('x3') })
    foreach ($x3Name in $x3Names) { Set-Variable -Name $x3Name -Value ('CALLER-' + $x3Name) }
    $x3ClosureSeen = @{}
    $x3ClosureMutator = { param($j, $c)
        foreach ($x3ProbeName in $x3Names) { $x3ClosureSeen[$x3ProbeName] = [string](Get-Variable -Name $x3ProbeName -ValueOnly -ErrorAction SilentlyContinue) }
        $c.Changed = $true
    }.GetNewClosure()
    $x3Outcome = Update-AbyssJournal -Path $x3Path -Mutator $x3ClosureMutator
    $x3Mismatch = @($x3Names | Where-Object { $x3ClosureSeen[$_] -cne ('CALLER-' + $_) })
    Assert-Case "$x3Prefix X3 클로저 mutator 는 저장 함수 지역 이름 $($x3Names.Count)개의 호출부 값을 읽음" ('{0}/[{1}]' -f $x3Outcome.Tag, ($x3Mismatch -join ',')) 'changed/[]'
    $x3DynamicSeen = @{}
    $x3DynamicMutator = { param($j, $c)
        foreach ($x3ProbeName in $x3Names) { $x3DynamicSeen[$x3ProbeName] = [string](Get-Variable -Name $x3ProbeName -ValueOnly -ErrorAction SilentlyContinue) }
    }
    $x3Outcome = Update-AbyssJournal -Path $x3Path -Mutator $x3DynamicMutator
    $x3Shadowed = @($x3Names | Where-Object { $x3DynamicSeen[$_] -cne ('CALLER-' + $_) })
    Assert-Case "$x3Prefix X3 대조 - 클로저가 아니면 저장 함수 지역 변수에 가려짐(동적 스코프)" ('{0}/{1}' -f $x3Outcome.Tag, ($x3Shadowed.Count -gt 0)) 'unchanged/True'
    $x3ExpectClosure = { param($j)
        $x3AllCaller = $true
        foreach ($x3ProbeName in $x3Names) {
            if ([string](Get-Variable -Name $x3ProbeName -ValueOnly -ErrorAction SilentlyContinue) -cne ('CALLER-' + $x3ProbeName)) { $x3AllCaller = $false }
        }
        return $x3AllCaller
    }.GetNewClosure()
    $x3Outcome = Update-AbyssJournal -Path $x3Path -Expect $x3ExpectClosure -Mutator ({ param($j, $c) $c.Changed = $true }.GetNewClosure())
    Assert-Case "$x3Prefix X6 클로저 Expect 도 호출부 값으로 판정(같은 이름 지역 변수에 안 가려짐) → changed" $x3Outcome.Tag 'changed'
    $x3Gate = $x3Names[0]
    Set-Variable -Name $x3Gate -Value 'STOP'
    $x3StopExpect = { param($j) return ([string](Get-Variable -Name $x3Gate -ValueOnly) -cne 'STOP') }.GetNewClosure()
    $x3Outcome = Update-AbyssJournal -Path $x3Path -Expect $x3StopExpect -Mutator ({ param($j, $c) $c.Changed = $true }.GetNewClosure())
    Assert-Case "$x3Prefix X6 클로저 Expect - 호출부 값(`$$x3Gate = STOP)이 거짓을 가리키면 expect-failed" $x3Outcome.Tag 'expect-failed'
}

function Test-CaseX5 {
    # X5 IO 예외 분류(구현 명세 ① 5절 A2 ⑩). X5-1(교체 대상 본 파일을 예산보다 오래 쥠 → io-failed)은 J10-2 에서 함께 봅니다.
    #   고정: 교체 실패 두 종류의 예외 형식(공유 위반 IOException / 읽기 전용 UnauthorizedAccessException - IOException 하위 아님)
    #   X5-2 본 파일 읽기 전용 → 같은 예산 재시도 뒤 io-failed(저장소 실패지 구현 결함이 아님)
    #   X5-3 mutator 가 던진 IOException → 태그가 아니라 전파(IO typed catch 는 IO 호출 지점에만) · 잠금 해제 · 임시 0
    #   X5-4 잠금 단계의 경합 아닌 실패(폴더 없음 0x80070003 · .lock 자리가 폴더 0x80070005) → locked 가 아니라 io-failed
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $probeFolder = New-CaseFolder $Context 'x5-probe'
    Assert-Case "$prefix X5 고정 - 대상을 FileShare.Read 로 쥔 File.Replace = IOException(공유 위반)" (Get-ReplaceFailureKind -Folder $probeFolder -Mode 'held') 'IOException/0x80070020'
    Assert-Case "$prefix X5 고정 - 읽기 전용 대상의 File.Replace = UnauthorizedAccessException" (Get-ReplaceFailureKind -Folder $probeFolder -Mode 'read-only') 'UnauthorizedAccessException/0x80070005'

    $folder = New-CaseFolder $Context 'x5-readonly'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'x5-a')
    [void](Add-TestEntry -Path $path -Reason 'x5-b')
    $stateBefore = Get-FolderState $folder
    [IO.File]::SetAttributes($path, [IO.FileAttributes]::ReadOnly)
    try {
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'x5-readonly' }
    } finally {
        [IO.File]::SetAttributes($path, [IO.FileAttributes]::Normal)
    }
    Assert-Case "$prefix X5-2 읽기 전용 본 파일 → 같은 예산 재시도 뒤 io-failed · throw 0 · 대기 19번" ('{0}/{1}/{2}' -f $update.Result.Tag, (Get-ErrorText $update.Error), $update.Sleeps) ('io-failed//{0}' -f $BUDGET_SLEEP_COUNT)
    Assert-Case "$prefix X5-2 파일 불변 · 임시·잠금 0" ('{0}/{1}' -f ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/0'

    $folder = New-CaseFolder $Context 'x5-mutator-io'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'x5-c')
    [void](Add-TestEntry -Path $path -Reason 'x5-d')
    $stateBefore = Get-FolderState $folder
    $ioMutator = { param($journal, $change)
        $change.Changed = $true
        throw (New-Object System.IO.IOException('mutator IO 결함 주입'))
    }.GetNewClosure()
    $outcome = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $ioMutator }
    Assert-Case "$prefix X5-3 mutator 의 IOException 은 태그가 아니라 전파" ('{0}/{1}/{2}' -f ($null -eq $outcome.Result), ($outcome.Error -is [System.IO.IOException]), (Get-ErrorText $outcome.Error)) 'True/True/mutator IO 결함 주입'
    Assert-Case "$prefix X5-3 잠금 해제 · 임시 0 · 파일 불변" ('{0}/{1}' -f (Get-LeftoverCount $folder), ((Get-FolderState $folder) -eq $stateBefore)) '0/True'
    $next = Add-TestEntry -Path $path -Reason 'x5-next'
    Assert-Case "$prefix X5-3 다음 저장 성공" $next.Tag 'changed'

    $missingFolder = Join-Path $Context.Root 'x5-missing-folder'
    $missingPath = Get-JournalPath $missingFolder
    Assert-Case "$prefix X5 고정 - 폴더 없음의 .lock CreateNew" (Get-CreateNewFailure (Get-LockPath $missingFolder)) 'DirectoryNotFoundException/0x80070003'
    $update = Measure-JournalCall { Add-TestEntry -Path $missingPath -Reason 'x5-missing' }
    Assert-Case "$prefix X5-4 폴더 없음 → 예산 뒤 io-failed(locked 아님) · throw 0 · 폴더를 만들지 않음" ('{0}/{1}/{2}/{3}' -f $update.Result.Tag, (Get-ErrorText $update.Error), $update.Sleeps, [IO.Directory]::Exists($missingFolder)) ('io-failed//{0}/False' -f $BUDGET_SLEEP_COUNT)

    $folder = New-CaseFolder $Context 'x5-lock-is-folder'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'x5-e')
    $lockFolder = Get-LockPath $folder
    [void][IO.Directory]::CreateDirectory($lockFolder)
    try {
        Assert-Case "$prefix X5 고정 - .lock 자리가 폴더인 CreateNew" (Get-CreateNewFailure $lockFolder) 'UnauthorizedAccessException/0x80070005'
        $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
        Assert-Case "$prefix X5-4 .lock 자리가 폴더 → 래퍼도 io-failed(locked 아님) · throw 0" ('{0}/{1}/{2}' -f $read.Result.Status, (Get-ErrorText $read.Error), $read.Sleeps) ('io-failed//{0}' -f $BUDGET_SLEEP_COUNT)
    } finally {
        [IO.Directory]::Delete($lockFolder)
    }
}

function Test-CaseX6 {
    # X6 Expect 계약(명세 리뷰 1·확인 라운드) - throw · IOException throw 는 그 예외 그대로 전파(태그 아님), 출력 없음·$true 둘·
    #     bool 아님(문자열 'true'·숫자 1)은 계약 위반 예외로 전파. 어느 경우든 mutator 0회 · 파일 불변 · 잠금·임시 0.
    #     (클로저 Expect 가 호출부 값으로 판정하는 행은 Test-CaseX3)
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'x6'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'x6-a')
    [void](Add-TestEntry -Path $path -Reason 'x6-b')
    $stateBefore = Get-FolderState $folder
    $calls = @{ Mutator = 0 }
    $countingMutator = { param($journal, $change) $calls.Mutator++; $change.Changed = $true }.GetNewClosure()
    $expectRows = @(
        @('throw', { param($journal) throw 'Expect 결함 주입' }, 'Expect 결함 주입'),
        @('IOException throw', { param($journal) throw (New-Object System.IO.IOException('Expect IO 결함 주입')) }, 'Expect IO 결함 주입'),
        @('출력 없음', { param($journal) }, ''),
        @('$true 둘', { param($journal) $true; $true }, ''),
        @("문자열 'true'", { param($journal) 'true' }, ''),
        @('숫자 1', { param($journal) 1 }, ''))
    foreach ($row in $expectRows) {
        $calls.Mutator = 0
        $expectBlock = $row[1].GetNewClosure()
        $outcome = Measure-JournalCall { Update-AbyssJournal -Path $path -Mutator $countingMutator -Expect $expectBlock }
        $message = Get-ErrorText $outcome.Error
        $messageOk = $(if ($row[2]) { $message -ceq $row[2] } else { $message.Contains('-Expect') })
        $typeOk = $(if ($row[0] -eq 'IOException throw') { $outcome.Error -is [System.IO.IOException] } else { $null -ne $outcome.Error })
        Assert-Case "$prefix X6 Expect $($row[0]) → 예외 전파(태그 아님) · mutator 0회 · 파일 불변 · 잠금·임시 0" ('{0}/{1}/{2}/{3}/{4}/{5}' -f ($null -eq $outcome.Result), $typeOk, $messageOk, $calls.Mutator, ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/True/True/0/True/0'
    }
}

function Test-CaseX7 {
    # X7 mutator 출력 누수(명세 리뷰 1) - mutator 가 문자열·숫자를 흘려도 저장소는 그 출력을 버리고([void]) 반환은 해시테이블 1개
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'x7'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'x7-a')
    $leakingMutator = { param($journal, $change)
        'leak'
        42
        $change.Changed = $true
    }.GetNewClosure()
    $outcome = Update-AbyssJournal -Path $path -Mutator $leakingMutator
    Assert-Case "$prefix X7 mutator 출력 누수에도 반환은 해시테이블 1개 · changed" ('{0}/{1}/{2}' -f ($outcome -is [hashtable]), @($outcome).Count, $outcome.Tag) 'True/1/changed'
}

function Test-CaseX8 {
    # X8 합산 재시도 예산(명세 리뷰 1·확인 라운드) - 자식이 잠금을 쥔 채 본 파일을 FileShare.Read 로 먼저 열고 신호 → 600ms 뒤 잠금만
    #     놓음(본 파일은 부모가 돌아온 뒤 놓음 - 파일 머리 주석). 잠금 대기(약 10번)와 교체 재시도가 한 예산(대기 19번)을 나눠 쓰고
    #     io-failed. 따로 세면 대기가 19번을 넘고 시간도 0.6초 넘게 더 걸립니다(명세 변이 '잠금·Replace 예산을 따로 셈').
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'x8'
    $path = Get-JournalPath $folder
    [void](Add-TestEntry -Path $path -Reason 'x8-a')
    $childName = $Context.Key + '-x8-holder'
    $holder = Start-JournalChild -Name $childName -Mode 'lock-then-main' -BundleFile $Context.ThisBundle -MainPath $path -Extra @{ LockHoldMs = 600 }
    $startTicks = 0
    try {
        if (-not (Wait-ChildSignal -Name $childName -Suffix 'ready')) {
            Assert-Case "$prefix X8 잠금·본 파일 쥔 자식 준비" (Get-ChildDiagnostic $childName $holder) 'ready'
            return
        }
        $stateBefore = Get-FolderState $folder
        $startTicks = [DateTime]::UtcNow.Ticks
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'x8-blocked' }
    } finally {
        Send-ChildSignal -Name $childName -Suffix 'release'
        $exited = Wait-ChildExit -Process $holder
    }
    $result = Read-ChildResult $childName
    $lockReleasedTicks = [long]0
    [void][long]::TryParse([string]$result['LOCK_RELEASED'], [ref]$lockReleasedTicks)
    Assert-Case "$prefix X8 잠금 대기 + 교체 재시도 합산 → io-failed · throw 0 · 대기 19번(한 번의 예산)" ('{0}/{1}/{2}' -f $update.Result.Tag, (Get-ErrorText $update.Error), $update.Sleeps) ('io-failed//{0}' -f $BUDGET_SLEEP_COUNT)
    Assert-Case "$prefix X8 저장이 잠금 해제 전에 시작(잠금 대기를 실제로 거침) · 자식 정상 종료" ('{0}/{1}/{2}' -f ($startTicks -gt 0 -and $lockReleasedTicks -gt $startTicks), $exited, [string]$result['ERROR']) 'True/True/'
    Assert-Case "$prefix X8 걸린 시간 ≤ 2000ms(20회 × 50ms 한 번 - 실제 $($update.ElapsedMs)ms)" ($update.ElapsedMs -le 2000) 'True'
    Assert-Case "$prefix X8 본 파일·.bak 불변 · 임시·잠금 0" ('{0}/{1}' -f ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/0'
}

function Test-CaseX8Recovery {
    # X8 복구판(변이 검증 생존 보강) - 잠금 대기와 Held 복구 재시도도 한 예산입니다(저장·래퍼 각각). X8 과 같은 자식(잠금을 쥔 채 본
    #     파일을 FileShare.Read 로 먼저 열고 신호 → 600ms 뒤 잠금만 놓음 · 본 파일은 부모가 돌아온 뒤)인데 본 파일이 손상이고 .bak 이
    #     유효 - 잠금을 얻은 뒤 (c) 의 손상본 이동(삭제 공유 없음)이 막혀 남은 예산을 다 씀 → io-failed · 대기 19번. Held 에 예산을
    #     새로 주면(잠금 예산과 따로 셈) 대기가 19번을 넘습니다. X8 은 교체 재시도 쪽만 봅니다.
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    foreach ($via in @('update', 'wrapper')) {
        $label = $(if ($via -eq 'update') { '저장' } else { '래퍼' })
        $folder = New-CaseFolder $Context ('x8-recovery-' + $via)
        $path = Get-JournalPath $folder
        Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4 -AppliedJson '["x8r"]')
        Write-Fixture $path '{"version":1,"seq":'
        $childName = $Context.Key + '-x8r-' + $via
        $holder = Start-JournalChild -Name $childName -Mode 'lock-then-main' -BundleFile $Context.ThisBundle -MainPath $path -Extra @{ LockHoldMs = 600 }
        $startTicks = 0
        $recoveryOutcome = $null
        $stateBefore = ''
        try {
            if (-not (Wait-ChildSignal -Name $childName -Suffix 'ready')) {
                Assert-Case "$prefix X8-복구 $label 잠금·본 파일 쥔 자식 준비" (Get-ChildDiagnostic $childName $holder) 'ready'
                continue
            }
            $stateBefore = Get-FolderState $folder
            $startTicks = [DateTime]::UtcNow.Ticks
            if ($via -eq 'update') {
                $recoveryOutcome = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'x8-recovery' }
                $tag = $recoveryOutcome.Result.Tag
            } else {
                $recoveryOutcome = Measure-JournalCall { Read-AbyssJournal -Path $path }
                $tag = $recoveryOutcome.Result.Status
            }
        } finally {
            Send-ChildSignal -Name $childName -Suffix 'release'
            $exited = Wait-ChildExit -Process $holder
        }
        if ($null -eq $recoveryOutcome) { continue }
        $result = Read-ChildResult $childName
        $lockReleasedTicks = [long]0
        [void][long]::TryParse([string]$result['LOCK_RELEASED'], [ref]$lockReleasedTicks)
        Assert-Case "$prefix X8-복구 $label - 잠금 대기 + 복구 재시도 합산 → io-failed · throw 0 · 대기 19번(한 번의 예산 - 실제 $($recoveryOutcome.ElapsedMs)ms)" ('{0}/{1}/{2}' -f $tag, (Get-ErrorText $recoveryOutcome.Error), $recoveryOutcome.Sleeps) ('io-failed//{0}' -f $BUDGET_SLEEP_COUNT)
        Assert-Case "$prefix X8-복구 $label - 잠금 해제 전에 시작 · 자식 정상 종료 · 파일 불변 · 임시·잠금 0" ('{0}/{1}/{2}/{3}/{4}' -f ($startTicks -gt 0 -and $lockReleasedTicks -gt $startTicks), $exited, [string]$result['ERROR'], ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) 'True/True//True/0'
    }
}

function Test-CaseX10 {
    # X10 Held 복구 중 IO 실패(명세 5절 C3 - 변이 검증 생존 보강): 다른 프로그램이 복구로 옮길 파일을 삭제 공유 없이(FileShare.Read)
    #     쥐면 잠금 아래 이동이 IOException → 같은 예산 안 재시도 뒤 io-failed · throw 0 · 파일 불변(부분 상태 0) · 잠금 해제.
    #     복구 지점의 catch 를 일반 catch + -is 로 바꾸면 감싼 예외라 전파돼(체크리스트 10) 여기서 throw 로 드러납니다.
    #   X10-c 손상 본 파일 + 유효 .bak, 본 파일을 쥠 → 손상본 이동(.corrupt) 실패 → io-failed → 놓은 뒤 다음 읽기 = (c) 복구
    #   X10-b 본 파일 없음 + .bak + 고른 .tmp(seq = .bak + 1), 그 .tmp 를 쥠 → 올리기(Move) 실패 → io-failed → 놓은 뒤 (b) 올림
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $folder = New-CaseFolder $Context 'x10-c'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4 -AppliedJson '["x10"]')
    Write-Fixture $path '{"version":1,"seq":'
    $stateBefore = Get-FolderState $folder
    $holder = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    } finally {
        $holder.Dispose()
    }
    Assert-Case "$prefix X10-c 손상본 이동이 막힘(본 파일 FileShare.Read) → io-failed · throw 0 · 대기 19번 · 파일 불변 · 임시·잠금 0" ('{0}/{1}/{2}/{3}/{4}' -f $read.Result.Status, (Get-ErrorText $read.Error), $read.Sleeps, ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)) ('io-failed//{0}/True/0' -f $BUDGET_SLEEP_COUNT)
    $after = Read-AbyssJournal -Path $path
    Assert-Case "$prefix X10-c 놓은 뒤 다음 읽기 = (c) 복구(seq 5 · 손상 증거 1)" ('{0}/{1}/{2}/{3}' -f $after.Status, $after.Branch, (Get-JournalSeqText $path), @([IO.Directory]::GetFiles($folder, 'abyss_handoff.json.corrupt.*')).Count) 'ok/c/5/1'

    $folder = New-CaseFolder $Context 'x10-b'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4)
    $chosenTemp = New-FixtureTempPath $folder '1010'
    Write-Fixture $chosenTemp (New-JournalJson -Seq 5 -AppliedJson '["x10-tmp"]')
    $stateBefore = Get-FolderState $folder
    $holder = [IO.File]::Open($chosenTemp, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    } finally {
        $holder.Dispose()
    }
    Assert-Case "$prefix X10-b 임시본 올리기가 막힘(.tmp FileShare.Read) → io-failed · throw 0 · 대기 19번 · 파일 불변 · 잠금 0" ('{0}/{1}/{2}/{3}/{4}' -f $read.Result.Status, (Get-ErrorText $read.Error), $read.Sleeps, ((Get-FolderState $folder) -eq $stateBefore), [IO.File]::Exists((Get-LockPath $folder))) ('io-failed//{0}/True/False' -f $BUDGET_SLEEP_COUNT)
    $after = Read-AbyssJournal -Path $path
    Assert-Case "$prefix X10-b 놓은 뒤 다음 읽기 = (b) 올림(seq 5 · 임시·잠금 0)" ('{0}/{1}/{2}/{3}' -f $after.Status, $after.Branch, (Get-JournalSeqText $path), (Get-LeftoverCount $folder)) 'ok/b/5/0'
}

function Test-CaseX11 {
    # X11 본 파일 읽기 IO 실패는 손상이 아님(변이 검증 생존 보강 + 같은 검증에서 찾은 구현 결함 2026-10-08): 다른 프로그램이 본 파일을
    #     읽기 공유 없이 쥔 동안 후보 읽기는 IoFailed → 래퍼·저장 io-failed(corrupt·빈 journal 아님) · 파일 불변. 결함은 저장소를 여러 번
    #     쓴 뒤에만 났습니다 - PS 5.1 은 함수를 수십 번 부른 뒤 백그라운드에서 컴파일하고, catch 절이 3개 이상인 try 는 그 뒤에만 절을
    #     잘못 고릅니다(묶음 머리 주석). 그래서 후보 읽기를 먼저 충분히 불러 컴파일을 끝낸 뒤 확인합니다(원인 모양은 X11 정적).
    #   X11-a FileShare.None · .bak 없음 → 래퍼 io-failed · throw 0 · 대기 19번 · 파일 불변(고치기 전: ok/d 빈 journal)
    #   X11-b FileShare.Delete(읽기 공유 없음) · .bak 있음 → 래퍼 io-failed · 직전본으로 되돌림 0(손상 취급 변이: (c) 복구로 되돌림)
    #   X11-c FileShare.Delete · .bak 없음 → 저장 io-failed · 덮어쓰기 0(고치기 전: 빈 journal 에서 저장해 applied·항목 유실)
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $warmFolder = New-CaseFolder $Context 'x11-warm'
    $warmPath = Get-JournalPath $warmFolder
    Write-Fixture $warmPath (New-JournalJson -Seq 1)
    for ($round = 0; $round -lt 80; $round++) { [void](Read-AbyssJournalUnlocked -Path $warmPath) }
    [System.Threading.Thread]::Sleep(1000)
    for ($round = 0; $round -lt 40; $round++) { [void](Read-AbyssJournalUnlocked -Path $warmPath) }

    $folder = New-CaseFolder $Context 'x11-a'
    $path = Get-JournalPath $folder
    Write-Fixture $path (New-JournalJson -Seq 3 -EntriesJson '[{"nonce":"x11"}]' -AppliedJson '["latest"]')
    $stateBefore = Get-FolderState $folder
    $holder = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    try {
        $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    } finally {
        $holder.Dispose()
    }
    Assert-Case "$prefix X11-a 본 파일 읽기 막힘(FileShare.None · .bak 없음) → 래퍼 io-failed(corrupt·빈 journal 아님) · throw 0 · 대기 19번 · 파일 불변" ('{0}/{1}/{2}/{3}/{4}' -f $read.Result.Status, $read.Result.Branch, (Get-ErrorText $read.Error), $read.Sleeps, ((Get-FolderState $folder) -eq $stateBefore)) ('io-failed///{0}/True' -f $BUDGET_SLEEP_COUNT)

    $folder = New-CaseFolder $Context 'x11-b'
    $path = Get-JournalPath $folder
    Write-Fixture $path (New-JournalJson -Seq 3 -AppliedJson '["latest"]')
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 2 -AppliedJson '["older"]')
    $stateBefore = Get-FolderState $folder
    $holder = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Delete)
    try {
        $read = Measure-JournalCall { Read-AbyssJournal -Path $path }
    } finally {
        $holder.Dispose()
    }
    Assert-Case "$prefix X11-b 본 파일 읽기 막힘(FileShare.Delete · .bak 있음) → 래퍼 io-failed · throw 0 · 파일 불변 · 직전본으로 되돌림 0" ('{0}/{1}/{2}/{3}' -f $read.Result.Status, (Get-ErrorText $read.Error), ((Get-FolderState $folder) -eq $stateBefore), (@((Read-JournalFile $path).applied) -join ',')) 'io-failed//True/latest'

    $folder = New-CaseFolder $Context 'x11-c'
    $path = Get-JournalPath $folder
    Write-Fixture $path (New-JournalJson -Seq 3 -EntriesJson '[{"nonce":"x11"}]' -AppliedJson '["latest"]')
    $stateBefore = Get-FolderState $folder
    $holder = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Delete)
    try {
        $update = Measure-JournalCall { Add-TestEntry -Path $path -Reason 'x11-blocked' }
    } finally {
        $holder.Dispose()
    }
    $main = Read-JournalFile $path
    Assert-Case "$prefix X11-c 본 파일 읽기 막힘(FileShare.Delete · .bak 없음) → 저장 io-failed · throw 0 · 대기 19번 · 덮어쓰기 0(applied·항목 그대로)" ('{0}/{1}/{2}/{3}/{4}/{5}' -f $update.Result.Tag, (Get-ErrorText $update.Error), $update.Sleeps, ((Get-FolderState $folder) -eq $stateBefore), (@($main.applied) -join ','), (@($main.entries | ForEach-Object { $_.nonce }) -join ',')) ('io-failed//{0}/True/latest/x11' -f $BUDGET_SLEEP_COUNT)
}

$script:workerRunLogLines = New-Object System.Collections.Generic.List[string]
function Write-RunLog {
    # 워커 로그 모의(실제 서명 param([string]$Message)) - X4 가 워커 기록 함수의 줄을 모읍니다
    param([string]$Message)
    $script:workerRunLogLines.Add($Message)
}

# X4 호출마다 앞뒤로 비교하는 워커 상태(단계 2.10 구현 검증 - 생존 변이 t5·t6): 본류가 기록 뒤에 읽는 값(정리 전용 · 재시작 · 마무리 복구 · 소유자 JSON ·
# 마커 경로 · 실행 id · 마지막 판). 기록 함수는 결과를 줄로만 알리고 워커 상태를 바꾸지 않습니다 - 저장 실패에 정리 전용 표지를 세우면 커스텀 판이 코드 10
# (미계상 · 같은 항목 재실행)으로, 새 표지를 남겨 본류 끝에서 읽으면 종료 코드가 바뀝니다(명세 2.10 W3 '저장 실패 → [경고] 1 → 그대로 진행')
$WORKER_STATE_NAMES = @('customMode', 'customCleanupOnly', 'customRestart', 'customRecoveryOnly', 'customOwnerJson', 'customMarkerPath', 'abyssRunId', 'dgLastRun')
$script:x4StateChanges = New-Object System.Collections.Generic.List[string]

function Get-WorkerStateSnapshot {
    # 스크립트 변수 이름 집합(새 표지 변수가 생기면 드러남) + 위 워커 상태 값 → @{ Names; Values }
    return @{
        Names  = @(Get-Variable -Scope Script | ForEach-Object { $_.Name } | Sort-Object)
        Values = @($WORKER_STATE_NAMES | ForEach-Object { '{0}={1}' -f $_, [string](Get-Variable -Scope Script -Name $_ -ValueOnly -ErrorAction SilentlyContinue) })
    }
}

function Invoke-ClearedEntryCall {
    # X4 한 호출 - 워커 상태($script:abyssRunId · customMode · customOwnerJson)와 경로를 두고 실제 Add-AbyssJournalClearedEntry 1번 →
    # @{ Error(메시지 - 없으면 빈 값); Outputs(출력 개수 - 반환 해시 하나 계약, 구현 명세 ⑤b2 1.2); Returned(출력 배열); ReturnText('Tag|Nonce' - 해시 하나가
    # 아니면 '(출력 n개)'); Logs; Before; After(호출 앞뒤 시각) }. 경로는 그 함수가 이름 그대로 읽는
    # 스크립트 수준 $abyssJournalPath 에 둡니다(워커와 같은 모양 - 이 함수 안에 같은 이름의 지역 변수를 두지 않음: 동적 스코프로 가려짐).
    # 나머지 워커 상태는 보통 판의 값으로 두고 호출 앞뒤를 비교해, 달라진 것을 $script:x4StateChanges 에 '실행 id: 내용' 으로 적습니다(Test-CaseX4 끝 단언)
    # 열쇠(구현 명세 ② 2.2 - X4-i~l): -HandoffNonce 를 $script:handoff.Nonce 로 둡니다(기록 함수가 클로저 밖 지역 사본으로 읽는 열쇠 - 빈 값 = 열쇠 없음. 기록
    # 함수가 읽는 이어받기 상태는 이 필드 하나). -NoHandoff 면 $script:handoff 를 지운 채 부릅니다(⑯ 결합 행처럼 이어받기 상태가 없는 실행). -EnvHandoffNonce 는
    # 그 호출 동안만 HONEYNOGI_HANDOFF_NONCE 로 둡니다(Role none 기동이 받은 nonce - 열쇠가 아님, 설계 R2 3.3 ⑥) - 그 밖의 호출은 그 env 를 비운 채 부릅니다
    param([string]$JournalPath, [string]$RunId, [bool]$Custom, [string]$OwnerJson = '', [string]$HandoffNonce = '', [switch]$NoHandoff, [string]$EnvHandoffNonce = '',
        [string]$Decision = 'exit', $NextOwner = $null, [switch]$UseArgs)
    $script:abyssJournalPath = $JournalPath
    $script:abyssRunId = $RunId
    $script:customMode = $Custom
    $script:customOwnerJson = $OwnerJson
    $script:customCleanupOnly = $false
    $script:customRestart = $false
    $script:customRecoveryOnly = $false
    $script:customMarkerPath = ''
    $script:dgLastRun = $false
    if ($NoHandoff) {
        Remove-Variable -Name 'handoff' -Scope Script -ErrorAction SilentlyContinue
    } else {
        $script:handoff = @{ Nonce = $HandoffNonce }
    }
    $savedHandoffEnv = [Environment]::GetEnvironmentVariable('HONEYNOGI_HANDOFF_NONCE', 'Process')
    $callHandoffEnv = $null
    if ($EnvHandoffNonce) { $callHandoffEnv = $EnvHandoffNonce }
    [Environment]::SetEnvironmentVariable('HONEYNOGI_HANDOFF_NONCE', $callHandoffEnv, 'Process')
    $script:workerRunLogLines.Clear()
    $callError = ''
    $callOutputs = @()
    $stateBefore = Get-WorkerStateSnapshot
    $callBefore = Get-Date
    try {
        if ($UseArgs) { $callOutputs = @(Add-AbyssJournalClearedEntry -Decision $Decision -NextOwner $NextOwner) } else { $callOutputs = @(Add-AbyssJournalClearedEntry) }
    } catch {
        $callError = $_.Exception.Message
    } finally {
        [Environment]::SetEnvironmentVariable('HONEYNOGI_HANDOFF_NONCE', $savedHandoffEnv, 'Process')
    }
    $callAfter = Get-Date
    $stateAfter = Get-WorkerStateSnapshot
    $stateDiffs = @(@(Compare-Object -ReferenceObject $stateBefore.Names -DifferenceObject $stateAfter.Names) | ForEach-Object { '변수 {0}{1}' -f $_.SideIndicator, $_.InputObject })
    for ($stateIndex = 0; $stateIndex -lt $WORKER_STATE_NAMES.Count; $stateIndex++) {
        if ($stateBefore.Values[$stateIndex] -cne $stateAfter.Values[$stateIndex]) { $stateDiffs += ('{0} → {1}' -f $stateBefore.Values[$stateIndex], $stateAfter.Values[$stateIndex]) }
    }
    if ($stateDiffs.Count -gt 0) { $script:x4StateChanges.Add(('{0}: {1}' -f $RunId, ($stateDiffs -join ', '))) }
    # 반환(구현 명세 ⑤b2 1.2) - 해시 하나면 'Tag|Nonce', 아니면 '(출력 n개)'
    $returnText = $(if (($callOutputs.Count -eq 1) -and ($callOutputs[0] -is [hashtable])) { '{0}|{1}' -f $callOutputs[0].Tag, $callOutputs[0].Nonce } else { '(출력 {0}개)' -f $callOutputs.Count })
    return @{ Error = $callError; Outputs = $callOutputs.Count; Returned = $callOutputs; ReturnText = $returnText; Logs = @($script:workerRunLogLines); Before = $callBefore; After = $callAfter }
}

function New-KeyEntryJson {
    # X4-i~l 픽스처 항목 한 건(JSON) - 워커 사본의 항목 기본값(New-AbyssJournalEntry) 위에 입장 기록 모양(stage entered · owner { runId } · afterEntry
    # {2, 2, [32,66]} · at.entered)과 그 launchState
    param([string]$Nonce, [string]$RunId, [string]$LaunchState)
    $fixtureEntry = New-AbyssJournalEntry -Stage 'entered'
    $fixtureEntry.nonce = $Nonce
    $fixtureEntry.runId = $RunId
    $fixtureEntry.owner = [pscustomobject]@{ runId = $RunId }
    $fixtureEntry.launchState = $LaunchState
    $fixtureEntry.afterEntry = [pscustomobject]@{ index = 2; total = 2; keys = @(32, 66) }
    $fixtureEntry.at.entered = '2026-10-13T09:00:00.0000000+09:00'
    return (ConvertTo-Json -InputObject $fixtureEntry -Depth 10 -Compress)
}

function Get-KeyEntryText {
    # X4-i~l 항목 대조 글자 - 필드 이름 순서 | nonce/stage/launchState/afterEntry index·total·keys/reason/screen/cleanupOnly/at.entered (항목이 없으면 '(없음)')
    param($Entry)
    if ($null -eq $Entry) { return '(없음)' }
    return ('{0} | {1}/{2}/{3}/{4}/{5}/[{6}]/[{7}]/[{8}]/{9}/{10}' -f (@($Entry.PSObject.Properties | ForEach-Object { $_.Name }) -join ','), $Entry.nonce, $Entry.stage,
        $Entry.launchState, $Entry.afterEntry.index, $Entry.afterEntry.total, (@($Entry.afterEntry.keys) -join ','), $Entry.reason, $Entry.screen, $Entry.cleanupOnly, $Entry.at.entered)
}

function Test-CaseX4 {
    # X4 워커 사본 cleared 기록(구현 명세 ① 2.10 W3·W4 · 3.1 X4) - 실제 Add-AbyssJournalClearedEntry 가 워커 사본 저장소로 쓴 항목의 필드 전부
    #     (owner·generation·section·decision·launchState·afterEntry·at)와 로그 줄. GUI 가 이 항목을 지금 판으로 대조하는지는 같은 묶음의
    #     Test-AbyssJournalOwnerMatch 로 봅니다(GUI 사본과 토큰이 같음 - J14).
    #   X4-a 비커스텀 · 파일 없음 → 새 파일(seq 1) · 항목 1 · owner { runId } · generation 0 · section '' · 기본값 필드 그대로 · 성공 줄 1
    #   X4-b 커스텀 · GUI 소유자 JSON(version 3) → section abyssCustomRepeat · owner 5필드(lap·index 정수) · generation = JSON 의 세대 · runId 도 기록
    #   X4-c 기존 기록(모르는 필드 포함)·applied·pending 보존 · seq +1 · 직전본 = 앞 내용
    #   X4-d 커스텀인데 소유자 JSON 을 해석하지 못함(빈 값 · JSON 아님 · 객체 아님 · 세대가 정수 아님) → [경고] 1 · 기록 0(파일 생성 0)
    #   X4-e 저장 실패 사용 중·손상·기록 실패 → [경고] 1(설계 R2 3.6 낱말) · 예외 0 · 파일 그대로 · 임시·잠금 0
    #   X4-f 저장소 밖 예외(구현 결함)는 감싸지 않고 밖으로 - 경고·성공 줄 0 (설계 R2-5)
    #   X4-g 본 파일 손상 + 직전본 유효 → 저장소의 복구 경고를 로그로 남기고(호출부 몫) 기록 성공
    #   X4-i~l 열쇠 항목 닫기(구현 명세 ② 2.2) - 있음 → done + applied / 없음(이어받기 상태 없음 · 빈 열쇠 + 받은 env nonce) → 그대로 / 이미 done → applied 에
    #          1번(중복 0) / 항목 없음 → applied 그대로. 넷 다 같은 저장 1번 · 그 밖 필드·순서·다른 항목 그대로 · cleared 1 · 성공 줄 1
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $guidPattern = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    $roundTripPattern = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$'
    $defaultNames = (@((New-AbyssJournalEntry -Stage 'cleared').PSObject.Properties | ForEach-Object { $_.Name }) -join ',')

    # X4-a 비커스텀
    $folder = New-CaseFolder $Context 'x4-plain'
    $path = Get-JournalPath $folder
    $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x4a' -Custom $false
    $raw = Read-JournalFile $path
    $entry = @($raw.entries)[0]
    Assert-Case "$prefix X4-a 비커스텀 - 새 파일 seq 1 · 항목 1 · applied·pending 0 · 작성자 = 워커 표지 · 줄 = 성공 1 · 예외 0 · 출력 1(반환 해시) · 임시·잠금 0" `
        ('{0}/{1}/{2}/{3}/{4}/[{5}]/{6}/{7}/{8}' -f $raw.seq, @($raw.entries).Count, @($raw.applied).Count, @($raw.pending).Count, $raw.savedBy,
            ($call.Logs -join ' | '), $call.Error, $call.Outputs, (Get-LeftoverCount $folder)) ('1/1/0/0/{0}/[{1}]//1/0' -f $Context.SavedBy, $CLEARED_SUCCESS_LINE)
    Assert-Case "$prefix X4-a 필드 목록 = 기본값 항목과 같은 이름·순서(빠짐·덧붙임 0)" ((@($entry.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -ceq $defaultNames) 'True'
    Assert-Case "$prefix X4-a 반환 = 해시 하나 @{ Tag changed; Nonce = 새 항목 nonce } (구현 명세 ⑤b2 1.2)" $call.ReturnText ('changed|' + $entry.nonce)
    Assert-Case "$prefix X4-a 값 - nonce GUID(D) · runId · section '' · generation 0(Int32) · owner = { runId } 하나 · nextOwner null · stage · decision · launchState" `
        ('{0}/{1}/[{2}]/{3}/{4}/{5}/{6}/{7}/{8}/{9}' -f ([string]$entry.nonce -cmatch $guidPattern), $entry.runId, $entry.section, $entry.generation, (Get-TypeNameText $entry.generation),
            ((@($entry.owner.PSObject.Properties | ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }) -join ',')), ($null -eq $entry.nextOwner), $entry.stage, $entry.decision, $entry.launchState) `
        'True/run-x4a/[]/0/Int32/runId=run-x4a/True/cleared/exit/pending'
    $clearedAt = ConvertFrom-AbyssJournalTime -Text $entry.at.cleared
    $clearedInCall = ($null -ne $clearedAt) -and ($clearedAt -ge $call.Before.AddMilliseconds(-1)) -and ($clearedAt -le $call.After.AddMilliseconds(1))
    Assert-Case "$prefix X4-a 값 - 횟수 0 · afterEntry {0, null, null} · reason·screen '' · cleanupOnly false · at.cleared = 호출 중 시각(왕복 형식) · 나머지 at null" `
        ('{0}/{1}/{2}/{3}/[{4}][{5}]/{6}/{7}/{8}/{9}' -f ($entry.attempts + $entry.retryClicks + $entry.resumeAttempts), $entry.afterEntry.index, ($null -eq $entry.afterEntry.total),
            ($null -eq $entry.afterEntry.keys), $entry.reason, $entry.screen, ($entry.cleanupOnly -is [bool] -and -not $entry.cleanupOnly),
            ([string]$entry.at.cleared -cmatch $roundTripPattern), $clearedInCall,
            ($null -eq $entry.at.entered -and $null -eq $entry.at.retryAttempt -and $null -eq $entry.at.retryClicked -and $null -eq $entry.at.reentered)) `
        '0/0/True/True/[][]/True/True/True/True'
    Assert-Case "$prefix X4-a GUI 대조 - 같은 실행 id 참 · 다른 실행 id 거짓 · 빈 실행 id 거짓" `
        ('{0}/{1}/{2}' -f (Test-AbyssJournalOwnerMatch -Entry $entry -Owner @{ runId = 'run-x4a' }), (Test-AbyssJournalOwnerMatch -Entry $entry -Owner @{ runId = 'run-other' }),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner @{ runId = '' })) 'True/False/False'

    # X4-b 커스텀 - GUI 가 넘기는 소유자 JSON 모양(version 3 · 필드 순서 고정 · 순차 목록은 orderKey '')
    $folder = New-CaseFolder $Context 'x4-custom'
    $path = Get-JournalPath $folder
    $customFingerprint = 'A|solo|어려움|허상의 정박지|없음;A|party|어려움|잊혀진 성소|우연한 만남'
    $customItem = 'A|party|어려움|잊혀진 성소|우연한 만남'
    $ownerJson = '{{"version":3,"fingerprint":"{0}","orderKey":"","lap":2,"index":1,"item":"{1}","generation":4}}' -f $customFingerprint, $customItem
    $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x4b' -Custom $true -OwnerJson $ownerJson
    $raw = Read-JournalFile $path
    $entry = @($raw.entries)[0]
    Assert-Case "$prefix X4-b 커스텀 - 항목 1 · 줄 = 성공 1 · 예외 0 · 출력 1" ('{0}/[{1}]/{2}/{3}' -f @($raw.entries).Count, ($call.Logs -join ' | '), $call.Error, $call.Outputs) ('1/[{0}]//1' -f $CLEARED_SUCCESS_LINE)
    Assert-Case "$prefix X4-b 값 - section abyssCustomRepeat · generation 4(Int32) · owner 5필드(이름·순서) · lap·index Int32 · runId · stage · decision · launchState · nextOwner null" `
        ('{0}/{1}/{2}/{3}/{4}/{5}/{6}/{7}/{8}/{9}/{10}' -f $entry.section, $entry.generation, (Get-TypeNameText $entry.generation),
            (@($entry.owner.PSObject.Properties | ForEach-Object { $_.Name }) -join ','), (Get-TypeNameText $entry.owner.lap), (Get-TypeNameText $entry.owner.index),
            $entry.runId, $entry.stage, $entry.decision, $entry.launchState, ($null -eq $entry.nextOwner)) `
        'abyssCustomRepeat/4/Int32/fingerprint,orderKey,lap,index,item/Int32/Int32/run-x4b/cleared/exit/pending/True'
    Assert-Case "$prefix X4-b owner 값 = 소유자 JSON 그대로(지문·orderKey ''·lap 2·index 1·항목)" `
        ('{0}|[{1}]|{2}|{3}|{4}' -f $entry.owner.fingerprint, $entry.owner.orderKey, $entry.owner.lap, $entry.owner.index, $entry.owner.item) ('{0}|[]|2|1|{1}' -f $customFingerprint, $customItem)
    $nowOwner = @{ fingerprint = $customFingerprint; orderKey = ''; lap = 2; index = 1; item = $customItem }
    $otherIndexOwner = @{ fingerprint = $customFingerprint; orderKey = ''; lap = 2; index = 0; item = $customItem }
    Assert-Case "$prefix X4-b GUI 대조 - 같은 판·세대 참 · 세대 다름(3·5) 거짓 · 칸 다름 거짓 · 실행 id 로는 거짓" `
        ('{0}/{1}/{2}/{3}/{4}' -f (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $nowOwner -Generation 4), (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $nowOwner -Generation 3),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $nowOwner -Generation 5), (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $otherIndexOwner -Generation 4),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner @{ runId = 'run-x4b' })) 'True/False/False/False/False'

    # X4-c 기존 기록 보존
    $folder = New-CaseFolder $Context 'x4-keep'
    $path = Get-JournalPath $folder
    $oldEntryJson = '[{"nonce":"old-1","stage":"cleared","launchState":"done","futureNote":"보존할 값"}]'
    Write-Fixture $path (New-JournalJson -Seq 7 -EntriesJson $oldEntryJson -AppliedJson '["old-1"]' -PendingJson '[{"nonce":"p-1","stage":"inside-handoff"}]')
    $beforeDigest = Get-FileDigest $path
    $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x4c' -Custom $false
    $raw = Read-JournalFile $path
    Assert-Case "$prefix X4-c 기존 기록 보존 - seq 8 · 항목 2(앞 = 옛 항목·모르는 필드 그대로, 뒤 = 새 cleared) · applied·pending 그대로 · 직전본 = 앞 내용 · 줄 = 성공 1" `
        ('{0}/{1}/{2}:{3}/{4}:{5}/{6}/{7}/{8}/[{9}]' -f $raw.seq, @($raw.entries).Count, @($raw.entries)[0].nonce, @($raw.entries)[0].futureNote, @($raw.entries)[1].stage,
            @($raw.entries)[1].runId, (@($raw.applied) -join ','), @($raw.pending)[0].nonce, ((Get-FileDigest ($path + '.bak')) -eq $beforeDigest), ($call.Logs -join ' | ')) `
        ('8/2/old-1:보존할 값/cleared:run-x4c/old-1/p-1/True/[{0}]' -f $CLEARED_SUCCESS_LINE)

    # X4-d 커스텀인데 소유자 JSON 해석 실패 → 기록 0
    $ownerFailures = foreach ($badOwner in @('', 'not json', '[1,2]', 'null', '{"version":3,"fingerprint":"f","orderKey":"","lap":1,"index":0,"item":"i","generation":"abc"}')) {
        $folder = New-CaseFolder $Context ('x4-owner-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $path = Get-JournalPath $folder
        $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x4d' -Custom $true -OwnerJson $badOwner
        '[{0}]/{1}/{2}/{3}/{4}' -f ($call.Logs -join ' | '), (Get-FolderListing $folder), $call.Error, $call.Outputs, $call.ReturnText
    }
    Assert-Case "$prefix X4-d 소유자 JSON 해석 실패 5모양(빈 값·JSON 아님·배열·null·세대 정수 아님) → [경고] 1 · 파일 생성 0 · 예외 0 · 반환 owner-unreadable(nonce 빈 값)" ($ownerFailures -join ' || ') `
        (@(1..5 | ForEach-Object { '[{0}]///1/owner-unreadable|' -f $CLEARED_OWNER_WARNING }) -join ' || ')

    # X4-e 저장 실패 3종 - 같은 프로세스가 잠금을 쥠(locked) / 본 파일·직전본 손상(corrupt) / 본 파일을 FileShare.Read 로 쥐어 교체 실패(io-failed)
    $storeFailures = foreach ($failKind in @('locked', 'corrupt', 'io-failed')) {
        $folder = New-CaseFolder $Context ('x4-fail-' + $failKind)
        $path = Get-JournalPath $folder
        if ($failKind -eq 'corrupt') {
            Write-Fixture $path '{"version":1,"seq":'
            Write-Fixture ($path + '.bak') 'not json'
        } else {
            Write-Fixture $path (New-JournalJson -Seq 3 -AppliedJson '["keep"]')
        }
        $stateBefore = Get-FolderState $folder
        $holder = $null
        if ($failKind -eq 'locked') {
            $holder = New-Object System.IO.FileStream((Get-LockPath $folder), [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)
        } elseif ($failKind -eq 'io-failed') {
            $holder = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        }
        try {
            $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x4e' -Custom $false
        } finally {
            if ($null -ne $holder) { $holder.Dispose() }
        }
        '{0}: [{1}]/{2}/{3}/{4}/{5}/{6}' -f $failKind, ($call.Logs -join ' | '), $call.Error, $call.Outputs, ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder), $call.ReturnText
    }
    Assert-Case "$prefix X4-e 저장 실패 사용 중·손상·기록 실패 → [경고] 1(설계 R2 3.6 낱말) · 예외 0 · 반환 태그(nonce 빈 값) · 파일 그대로 · 임시·잠금 0" ($storeFailures -join ' || ') `
        ((@(@('locked', '파일 사용 중'), @('corrupt', '파일 손상'), @('io-failed', '기록 실패')) | ForEach-Object {
                    '{0}: [{1}]//1/True/0/{0}|' -f $_[0], ($CLEARED_FAIL_FORMAT -f $_[1]) }) -join ' || ')

    # X4-f 저장소 밖 예외(구현 결함 - 저장 함수가 던짐)는 감싸지 않고 밖으로 - 경고·성공 줄 0. 저장 함수는 이 케이스 동안만 바꿔 끼우고 워커 사본 원문으로 되돌립니다
    $folder = New-CaseFolder $Context 'x4-throw'
    $path = Get-JournalPath $folder
    Invoke-Expression ('function script:Update-AbyssJournal { param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect = $null) throw ''' + $INJECTED_STORE_THROW + ''' }')
    try {
        $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x4f' -Custom $false
    } finally {
        Invoke-Expression ($Context.UpdateText -replace '^function Update-AbyssJournal\b', 'function script:Update-AbyssJournal')
    }
    Assert-Case "$prefix X4-f 저장소 밖 예외 → 감싸지 않음(같은 메시지가 밖으로) · 경고·성공 줄 0 · 파일 0" ('{0}/[{1}]/{2}' -f $call.Error, ($call.Logs -join ' | '), (Get-FolderListing $folder)) `
        ('{0}/[]/' -f $INJECTED_STORE_THROW)

    # X4-g 본 파일 손상 + 직전본 유효 → 저장소가 잠금 아래 (c) 복구 → 그 경고를 호출부가 로그로 남김(저장소 계약) → 기록 성공
    $folder = New-CaseFolder $Context 'x4-recover'
    $path = Get-JournalPath $folder
    Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4 -AppliedJson '["bak-kept"]')
    Write-Fixture $path '{"version":1,"seq":'
    $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x4g' -Custom $false
    $raw = Read-JournalFile $path
    Assert-Case "$prefix X4-g 본 파일 손상·직전본 유효 → 줄 = 복구 경고 → 성공 · 항목 1 · applied = 직전본 값 · 예외 0" `
        ('[{0}]/{1}/{2}/{3}' -f ($call.Logs -join ' | '), @($raw.entries).Count, (@($raw.applied) -join ','), $call.Error) ('[{0} | {1}]/1/bak-kept/' -f $WARNING_BAK_RESTORE, $CLEARED_SUCCESS_LINE)

    # X4-h 워커 단독 실행(GUI 없이 - HONEYNOGI_RUN_ID 없음, 단계 2.10 구현 검증 - 생존 변이 n1·n3): 실행 id 읽기(W2 - 워커 원문 문장을 그대로 점소싱)가 빈 값을
    #       그대로 두고(분기 없음 - 규칙 8) 기록도 그대로 남김(runId '' · owner { runId '' } - 다음 GUI 시작의 지난 기록 정리가 지우는 대상, 명세 2.10 W2).
    #       W2 문장 하나만 돌리므로 그 앞뒤에 더한 빈 값 분기는 여기서 안 보입니다 - 워커 전체의 대입은 정적 X4-h ①②(Test-WorkerRunIdStatic)가 봅니다
    $folder = New-CaseFolder $Context 'x4-standalone'
    $path = Get-JournalPath $folder
    if ([string]::IsNullOrEmpty($Context.RunIdStatement)) {
        "FAIL $prefix X4-h 워커의 실행 id 읽기(`$script:abyssRunId 최상위 대입) 문장이 1개가 아닙니다"
        $script:fails++
    } else {
        $savedRunIdEnv = [Environment]::GetEnvironmentVariable('HONEYNOGI_RUN_ID', 'Process')
        [Environment]::SetEnvironmentVariable('HONEYNOGI_RUN_ID', $null, 'Process')
        $script:abyssRunId = '(앞 값)'
        try {
            . ([scriptblock]::Create($Context.RunIdStatement))
        } finally {
            [Environment]::SetEnvironmentVariable('HONEYNOGI_RUN_ID', $savedRunIdEnv, 'Process')
        }
        $standaloneRunId = $script:abyssRunId
        $call = Invoke-ClearedEntryCall -JournalPath $path -RunId $standaloneRunId -Custom $false
        # 기록이 생략되면 파일이 없습니다 - 읽기 예외가 아니라 아래 단언 차이(기록 0)로 드러나게 먼저 확인
        $raw = $(if ([IO.File]::Exists($path)) { Read-JournalFile $path } else { $null })
        $entry = $(if ($null -ne $raw) { @($raw.entries)[0] } else { $null })
        Assert-Case "$prefix X4-h 워커 단독 실행(RUN_ID 없음) → 실행 id = 빈 값 그대로 · 기록 1 · runId '' · owner { runId '' } · 줄 = 성공 1 · 예외 0" `
            ('[{0}]({1})/{2}/[{3}]/[{4}]/[{5}]/{6}' -f $standaloneRunId, (Get-TypeNameText $standaloneRunId), $(if ($null -ne $raw) { @($raw.entries).Count } else { 0 }), $entry.runId,
                ((@($entry.owner.PSObject.Properties | ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }) -join ',')), ($call.Logs -join ' | '), $call.Error) `
            ('[](String)/1/[]/[runId=]/[{0}]/' -f $CLEARED_SUCCESS_LINE)
    }

    # X4-i~l 열쇠 항목 닫기(구현 명세 ② 2.2 · J4 · 설계 v10 '같은 mutation 에서 이 판의 entered 항목 applied·done'): 클리어 기록과 같은 저장(seq +1 한 번 ·
    #       직전본 = 앞 내용)에서 열쇠 항목($script:handoff.Nonce)을 launchState done 으로, 그 nonce 를 applied 에(이미 있으면 그대로) - 그 항목이 있을 때만(지난 기록
    #       정리 ③ 이 applied 를 보고 지움). 그 항목의 다른 필드·필드 순서(직접 대입 - 명세 J5)·다른 항목·기존 applied 는 그대로이고 cleared 1건·성공 줄 1 은 기존
    #       그대로입니다. 기대 항목 글자 = 호출 전 디스크 항목에 행의 기대 launchState 만 덮은 것(바뀌는 것만 행이 정하고 나머지는 픽스처에서 가져옴).
    #       X4-j2 의 env nonce 는 Role none 기동이 받은 값이라 열쇠가 아닙니다(설계 R2 3.3 ⑥ - 기록 함수는 env 를 읽지 않음)
    $keyCases = @(
        @{ N = 'X4-i 있음(열린 항목 · applied 에 없음)'; Folder = 'x4-key-open'; Key = 'key-x4i'; Entries = @('key-x4i:launched', 'other-x4i:launched'); Applied = '["old-a"]'
            States = 'done,launched'; ExpectApplied = 'old-a,key-x4i' },
        @{ N = 'X4-j1 없음($script:handoff 자체가 없음 - ⑯ 결합 행 모양)'; Folder = 'x4-key-none'; Key = ''; NoHandoff = $true; Entries = @('open-x4j1:launched')
            Applied = '[]'; States = 'launched'; ExpectApplied = '' },
        @{ N = 'X4-j2 없음(열쇠 빈 값 + 받은 env nonce 가 열린 항목)'; Folder = 'x4-key-env'; Key = ''; EnvNonce = 'open-x4j2'; Entries = @('open-x4j2:launched')
            Applied = '[]'; States = 'launched'; ExpectApplied = '' },
        @{ N = 'X4-k1 이미 done(applied 에 없음)'; Folder = 'x4-key-done'; Key = 'key-x4k1'; Entries = @('key-x4k1:done'); Applied = '["old-a"]'
            States = 'done'; ExpectApplied = 'old-a,key-x4k1' },
        @{ N = 'X4-k2 이미 done(applied 에 이미 있음)'; Folder = 'x4-key-applied'; Key = 'key-x4k2'; Entries = @('key-x4k2:done'); Applied = '["key-x4k2"]'
            States = 'done'; ExpectApplied = 'key-x4k2' },
        @{ N = 'X4-l 항목 없음(지난 기록 정리 뒤)'; Folder = 'x4-key-gone'; Key = 'gone-x4l'; Entries = @('other-x4l:launched'); Applied = '["old-a"]'
            States = 'launched'; ExpectApplied = 'old-a' })
    foreach ($keyCase in $keyCases) {
        $folder = New-CaseFolder $Context $keyCase.Folder
        $path = Get-JournalPath $folder
        $keyRunId = 'run-' + $keyCase.Folder
        $entriesJson = '[' + ((@($keyCase.Entries) | ForEach-Object { $entryParts = $_.Split(':'); New-KeyEntryJson -Nonce $entryParts[0] -RunId $keyRunId -LaunchState $entryParts[1] }) -join ',') + ']'
        Write-Fixture $path (New-JournalJson -Seq 5 -EntriesJson $entriesJson -AppliedJson $keyCase.Applied)
        $beforeDigest = Get-FileDigest $path
        $beforeEntries = @((Read-JournalFile $path).entries)
        $call = Invoke-ClearedEntryCall -JournalPath $path -RunId $keyRunId -Custom $false -HandoffNonce $keyCase.Key -NoHandoff:([bool]$keyCase.NoHandoff) -EnvHandoffNonce ([string]$keyCase.EnvNonce)
        $raw = Read-JournalFile $path
        $afterEntries = @($raw.entries)
        $expectedStates = @($keyCase.States.Split(','))
        $actualTexts = @()
        $expectedTexts = @()
        for ($entryIndex = 0; $entryIndex -lt $beforeEntries.Count; $entryIndex++) {
            $actualTexts += (Get-KeyEntryText $afterEntries[$entryIndex])
            $beforeEntries[$entryIndex].launchState = $expectedStates[$entryIndex]
            $expectedTexts += (Get-KeyEntryText $beforeEntries[$entryIndex])
        }
        $lastEntry = $afterEntries[$afterEntries.Count - 1]
        Assert-Case ('{0} {1} - 같은 저장 1번(seq 6 · 직전본 = 앞 내용) · 항목 상태 [{2}] · applied [{3}] · 그 밖 필드·순서·다른 항목 그대로 · cleared 1 · 성공 줄 1 · 예외 0 · 출력 1(반환 해시)' -f
                $prefix, $keyCase.N, $keyCase.States, $keyCase.ExpectApplied) `
            ('{0} · 항목 {1} · [{2}] · 끝 {3}/{4} · applied [{5}] · 직전본 {6} · 줄 [{7}] · 예외 [{8}] · 출력 {9} · 임시·잠금 {10}' -f $raw.seq, $afterEntries.Count,
                ($actualTexts -join ' ## '), $lastEntry.stage, $lastEntry.runId, (@($raw.applied) -join ','), ((Get-FileDigest ($path + '.bak')) -eq $beforeDigest),
                ($call.Logs -join ' | '), $call.Error, $call.Outputs, (Get-LeftoverCount $folder)) `
            ('6 · 항목 {0} · [{1}] · 끝 cleared/{2} · applied [{3}] · 직전본 True · 줄 [{4}] · 예외 [] · 출력 1 · 임시·잠금 0' -f ($beforeEntries.Count + 1),
                ($expectedTexts -join ' ## '), $keyRunId, $keyCase.ExpectApplied, $CLEARED_SUCCESS_LINE)
    }

    # 전 호출 공통(단계 2.10 구현 검증 - 생존 변이 t5·t6): 기록 함수는 성공·실패·예외 어느 경우에도 스크립트 변수를 새로 만들거나 워커 상태 값을 바꾸지 않음
    Assert-Case "$prefix X4 전 호출 - 기록 함수가 스크립트 변수 이름 집합·워커 상태 값(정리 전용·재시작·마무리 복구·소유자·마커 경로·실행 id·마지막 판)을 바꾸지 않음" `
        ('{0}건 [{1}]' -f $script:x4StateChanges.Count, ($script:x4StateChanges -join ' || ')) '0건 []'
}

function Invoke-StageWriterCall {
    # X12~X14 한 호출 - 워커 상태와 경로를 두고 실제 단계 기록 함수 1번 → @{ Error; Outputs(출력 배열); Logs; Before; After } (X4 의 Invoke-ClearedEntryCall 과 같은 모양 - 구현 명세 ⑤b2 3.1)
    param([string]$Name, [string]$JournalPath, [string]$Nonce)
    $script:abyssJournalPath = $JournalPath
    $script:abyssRunId = 'run-x12'
    $script:customMode = $false
    $script:customOwnerJson = ''
    $script:customCleanupOnly = $false
    $script:customRestart = $false
    $script:customRecoveryOnly = $false
    $script:customMarkerPath = ''
    $script:dgLastRun = $false
    $script:handoff = @{ Nonce = '' }
    $script:workerRunLogLines.Clear()
    $callError = ''
    $callOutputs = @()
    $stateBefore = Get-WorkerStateSnapshot
    $callBefore = Get-Date
    try {
        $callOutputs = @(& $Name -Nonce $Nonce)
    } catch {
        $callError = $_.Exception.Message
    }
    $callAfter = Get-Date
    $stateAfter = Get-WorkerStateSnapshot
    $stateDiffs = @(@(Compare-Object -ReferenceObject $stateBefore.Names -DifferenceObject $stateAfter.Names) | ForEach-Object { '변수 {0}{1}' -f $_.SideIndicator, $_.InputObject })
    for ($stateIndex = 0; $stateIndex -lt $WORKER_STATE_NAMES.Count; $stateIndex++) {
        if ($stateBefore.Values[$stateIndex] -cne $stateAfter.Values[$stateIndex]) { $stateDiffs += ('{0} → {1}' -f $stateBefore.Values[$stateIndex], $stateAfter.Values[$stateIndex]) }
    }
    if ($stateDiffs.Count -gt 0) { $script:x4StateChanges.Add(('{0}/{1}: {2}' -f $Name, $Nonce, ($stateDiffs -join ', '))) }
    return @{ Error = $callError; Outputs = $callOutputs; Logs = @($script:workerRunLogLines); Before = $callBefore; After = $callAfter }
}

function New-StageEntryJson {
    # X12~X14 픽스처 항목 한 건(JSON) - 워커 사본 기본값(New-AbyssJournalEntry) 위에 그 단계까지 온 비커스텀 retry 판의 클리어 기록 모양(owner { runId } ·
    # nextOwner { runId } · decision retry · at.cleared · 단계에 맞는 attempts·retryClicks·at.* - 구현 명세 ⑤b2 1.2 값 표)
    param([string]$Nonce, [string]$Stage)
    $fixtureEntry = New-AbyssJournalEntry -Stage $Stage
    $fixtureEntry.nonce = $Nonce
    $fixtureEntry.runId = 'run-x12'
    $fixtureEntry.owner = [pscustomobject]@{ runId = 'run-x12' }
    $fixtureEntry.nextOwner = [pscustomobject]@{ runId = 'run-x12' }
    $fixtureEntry.decision = 'retry'
    $fixtureEntry.at.cleared = '2026-10-22T09:00:00.0000000+09:00'
    if (@('retry-attempt', 'retry-clicked', 'reentered') -contains $Stage) { $fixtureEntry.attempts = 1; $fixtureEntry.at.retryAttempt = '2026-10-22T09:00:01.0000000+09:00' }
    if (@('retry-clicked', 'reentered') -contains $Stage) { $fixtureEntry.retryClicks = 1; $fixtureEntry.at.retryClicked = '2026-10-22T09:00:02.0000000+09:00' }
    if ($Stage -eq 'reentered') { $fixtureEntry.at.reentered = '2026-10-22T09:00:09.0000000+09:00' }
    return (ConvertTo-Json -InputObject $fixtureEntry -Depth 10 -Compress)
}

function Get-StageEntryText {
    # X12~X14 항목 대조 글자 - 필드 이름 순서 | at 필드 순서 | nonce/stage/attempts/retryClicks/decision/launchState/at.cleared/at.retryAttempt/at.retryClicked/at.reentered
    # (시각은 'call' = 이 호출 동안의 왕복 형식 시각 · 'old' = 픽스처 값 그대로 · 'null' · 그 밖은 글자 그대로)
    param($Entry, $Call = $null, [hashtable]$OldTimes = @{})
    if ($null -eq $Entry) { return '(없음)' }
    $timeTexts = foreach ($timeName in @('cleared', 'retryAttempt', 'retryClicked', 'reentered')) {
        $timeValue = [string]$Entry.at.$timeName
        if ([string]::IsNullOrEmpty($timeValue)) { 'null'; continue }
        if ($OldTimes.ContainsKey($timeName) -and ($timeValue -ceq [string]$OldTimes[$timeName])) { 'old'; continue }
        $parsedTime = ConvertFrom-AbyssJournalTime -Text $timeValue
        if (($null -ne $Call) -and ($null -ne $parsedTime) -and ($timeValue -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$') -and
            ($parsedTime -ge $Call.Before.AddMilliseconds(-1)) -and ($parsedTime -le $Call.After.AddMilliseconds(1))) { 'call'; continue }
        $timeValue
    }
    return ('{0} | {1} | {2}/{3}/{4}/{5}/{6}/{7}/{8}' -f (@($Entry.PSObject.Properties | ForEach-Object { $_.Name }) -join ','), (@($Entry.at.PSObject.Properties | ForEach-Object { $_.Name }) -join ','),
        $Entry.nonce, $Entry.stage, $Entry.attempts, $Entry.retryClicks, $Entry.decision, $Entry.launchState, ($timeTexts -join '/'))
}

function Format-StageOutputs {
    # 출력 글자 - '개수:[값,…]' (빈 문자열·$null 한 개도 1 로 셉니다 - '[]' 만으로는 출력 0 과 갈리지 않음, 명세 리뷰 2 P3)
    param($Outputs)
    return ('{0}:[{1}]' -f @($Outputs).Count, (@($Outputs) -join ','))
}

function Test-CaseStageWriters {
    # X12~X15 '다시 하기' 단계 기록 셋 + 클리어 기록의 결정·다음 판 owner (구현 명세 ⑤b2 3.3 · 설계 v10 6.1 기록 시점 표·저장 계약 ③ · v11 R5 4.3 ⑤⑥ · R1 2.2)
    #   (X12~X14 바뀜 행은 '바꾸는 필드 밖은 그대로' 를 JSON 으로 함께 봅니다 - 대상 항목 = 앞 원문 + 바꾸는 필드만 · 다른 항목 = 앞 원문 전체)
    #   (출력은 개수까지 봅니다 - X12 는 태그 1개, X13·X14 는 모든 결과에서 0개(반환값 없음). 막힘 행에는 다른 nonce 의 허용 단계 항목을 함께 둡니다 -
    #    -Expect 가 nonce 를 안 보면 그 항목 때문에 참이 되어 대상 항목을 바꾸게 되는 꼴을 이 행이 잡습니다(명세 리뷰 2 P3))
    #   X12 retry-attempt: cleared → retry-attempt · attempts 1 · at.retryAttempt(이 호출) · 다른 필드·순서·다른 항목 그대로 / 같은 워커 두 번째 · 항목 없음 · retry-clicked
    #      (재개 갱신은 ⑤c 몫) · reentered · entered → expect-failed · 파일 그대로 / 저장 실패 3종 → 태그 · 파일 그대로 · 줄 0(실패 줄은 부르는 쪽 몫) /
    #      본 파일 손상·직전본 유효 → 복구 경고 전달 1줄 · changed
    #   X13 retry-clicked: retry-attempt → retry-clicked · retryClicks 1 · at.retryClicked / 두 번째 전송 → retryClicks 2 · at.retryClicked 이번 시각(마지막 전송 기준) /
    #      cleared · reentered · entered → [경고] 기록 실패 · 파일 그대로 / 저장 실패 3종 → [경고](설계 R2 3.6 낱말) / 복구 → 복구 경고 1줄 · 반환값 없음
    #   X14 reentered: retry-attempt · retry-clicked → reentered · at.reentered / cleared · reentered · entered → [경고] 기록 실패 / 저장 실패 3종 → [경고] / 복구 → 복구 경고 1줄
    #   X15 클리어 기록 -Decision·-NextOwner · 반환 @{ Tag; Nonce } 와 원 워커 사슬(cleared → retry-attempt → retry-clicked → reentered)
    param([hashtable]$Context)
    $prefix = $Context.Prefix
    $stateChangeBase = $script:x4StateChanges.Count   # 앞 케이스(X4)가 남긴 상태 변화 수 - 끝 단언은 X12~X15 가 더한 것만 셉니다
    $oldTimes = @{ cleared = '2026-10-22T09:00:00.0000000+09:00'; retryAttempt = '2026-10-22T09:00:01.0000000+09:00'; retryClicked = '2026-10-22T09:00:02.0000000+09:00'; reentered = '2026-10-22T09:00:09.0000000+09:00' }
    $defaultNames = (@((New-AbyssJournalEntry -Stage 'cleared').PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
    $atNames = (@((New-AbyssJournalEntry -Stage 'cleared').at.PSObject.Properties | ForEach-Object { $_.Name }) -join ',')
    $writerSpecs = @(
        @{ Name = 'Set-AbyssJournalRetryAttempt'; Key = 'X12'; Ok = @('cleared'); Bad = @('retry-attempt', 'retry-clicked', 'reentered', 'entered'); Warn = ''; Fields = @('stage', 'attempts', 'at.retryAttempt') },
        @{ Name = 'Set-AbyssJournalRetryClicked'; Key = 'X13'; Ok = @('retry-attempt', 'retry-clicked'); Bad = @('cleared', 'reentered', 'entered'); Warn = $RETRY_CLICKED_FAIL_FORMAT; Fields = @('stage', 'retryClicks', 'at.retryClicked') },
        @{ Name = 'Set-AbyssJournalReentered'; Key = 'X14'; Ok = @('retry-attempt', 'retry-clicked'); Bad = @('cleared', 'reentered', 'entered'); Warn = $REENTERED_FAIL_FORMAT; Fields = @('stage', 'at.reentered') })
    $okExpect = @{
        'Set-AbyssJournalRetryAttempt|cleared'       = 'retry-attempt/1/0/retry/pending/old/call/null/null'
        'Set-AbyssJournalRetryClicked|retry-attempt' = 'retry-clicked/1/1/retry/pending/old/old/call/null'
        'Set-AbyssJournalRetryClicked|retry-clicked' = 'retry-clicked/1/2/retry/pending/old/old/call/null'
        'Set-AbyssJournalReentered|retry-attempt'    = 'reentered/1/0/retry/pending/old/old/null/call'
        'Set-AbyssJournalReentered|retry-clicked'    = 'reentered/1/1/retry/pending/old/old/old/call'
    }
    foreach ($spec in $writerSpecs) {
        # 바뀌는 갈래 - 대상 항목 하나만 바뀜 · 같은 저장 1번(seq +1 · 직전본 = 앞 내용) · 다른 항목 그대로
        # 대상을 가운데 둡니다(앞 · 대상 · 뒤 - 셋 다 같은 허용 단계): Mutator 가 nonce 대신 위치(첫·마지막)나 단계(첫 허용 단계 항목)로 고르면 앞·뒤 항목이
        # 바뀌어 걸립니다 - 운영에서는 클리어 기록이 entries 끝에 붙고 지난 판 항목이 앞에 남을 수 있습니다(⑤b2 구현 검토 - 생존 변이 MW31 · MW32)
        foreach ($okStage in $spec.Ok) {
            $folder = New-CaseFolder $Context ('{0}-ok-{1}' -f $spec.Key.ToLower(), $okStage)
            $path = Get-JournalPath $folder
            Write-Fixture $path (New-JournalJson -Seq 5 -EntriesJson ('[' + (New-StageEntryJson -Nonce 'n-before' -Stage $okStage) + ',' + (New-StageEntryJson -Nonce 'n-target' -Stage $okStage) + ',' + (New-StageEntryJson -Nonce 'n-other' -Stage $okStage) + ']') -AppliedJson '["old-a"]')
            $beforeDigest = Get-FileDigest $path
            $beforeOther = (@(@((Read-JournalFile $path).entries)[0, 2] | ForEach-Object { Get-StageEntryText -Entry $_ -OldTimes $oldTimes }) -join ' ## ')
            $beforeEntries = @((Read-JournalFile $path).entries)
            $beforeTargetJson = ConvertTo-Json -InputObject $beforeEntries[1] -Depth 10 -Compress
            $beforeOtherJson = (@($beforeEntries[0], $beforeEntries[2]) | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth 10 -Compress }) -join ' ## '
            $call = Invoke-StageWriterCall -Name $spec.Name -JournalPath $path -Nonce 'n-target'
            $raw = Read-JournalFile $path
            $target = @($raw.entries)[1]
            $outputText = $(if ($spec.Key -eq 'X12') { '1:[changed]' } else { '0:[]' })
            Assert-Case ('{0} {1} {2} {3} → 바뀜 - seq 6 · 직전본 = 앞 내용 · 필드·at 이름 순서 그대로 · 다른 항목 그대로 · applied 그대로 · 줄 0 · 예외 0 · 출력 {4} · 임시·잠금 0' -f $prefix, $spec.Key, $spec.Name, $okStage, $outputText) `
                ('{0}/{1}/{2}/{3}/{4}/{5}/[{6}]/[{7}]/{8}/{9}' -f $raw.seq, ((Get-FileDigest ($path + '.bak')) -eq $beforeDigest), ((@($target.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -ceq $defaultNames),
                    ((@($target.at.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -ceq $atNames), ((@(@($raw.entries)[0, 2] | ForEach-Object { Get-StageEntryText -Entry $_ -OldTimes $oldTimes }) -join ' ## ') -ceq $beforeOther), (@($raw.applied) -join ','),
                    ($call.Logs -join ' | '), $call.Error, (Format-StageOutputs $call.Outputs), (Get-LeftoverCount $folder)) `
                ('6/True/True/True/True/old-a/[]/[]/{0}/0' -f $outputText)
            $targetText = Get-StageEntryText -Entry $target -Call $call -OldTimes $oldTimes
            Assert-Case ('{0} {1} {2} {3} → 단계·횟수·시각(stage/attempts/retryClicks/decision/launchState/at.cleared·retryAttempt·retryClicked·reentered)' -f $prefix, $spec.Key, $spec.Name, $okStage) `
                ($targetText.Split('|')[2].Trim().Substring('n-target/'.Length)) $okExpect[('{0}|{1}' -f $spec.Name, $okStage)]
            # 바꾸는 필드 밖은 그대로(구현 명세 ⑤b2 3.3) - 위 단언은 고른 필드만 보므로 owner · nextOwner · runId · generation · section · afterEntry · reason · screen ·
            # cleanupOnly 를 바꾸는 쓰기는 여기서 걸립니다: 대상 항목 = 앞 원문에 이 함수가 바꾸는 필드(stage · 횟수 · 해당 at)만 지금 값으로 옮긴 것 · 다른 항목 = 앞 원문 전체
            $expectTarget = ConvertFrom-Json -InputObject $beforeTargetJson
            foreach ($changedField in $spec.Fields) {
                $fieldPath = $changedField.Split('.')
                if ($fieldPath.Count -eq 2) { $expectTarget.($fieldPath[0]).($fieldPath[1]) = $target.($fieldPath[0]).($fieldPath[1]) } else { $expectTarget.($changedField) = $target.($changedField) }
            }
            Assert-Case ('{0} {1} {2} {3} → 바꾸는 필드({4}) 밖은 그대로 - 대상 항목 = 앞 원문 + 그 필드만 · 다른 항목 원문 전체 같음(JSON 비교)' -f $prefix, $spec.Key, $spec.Name, $okStage, ($spec.Fields -join '·')) `
                ('{0}/{1}' -f ((ConvertTo-Json -InputObject $target -Depth 10 -Compress) -ceq (ConvertTo-Json -InputObject $expectTarget -Depth 10 -Compress)),
                    (((@(@($raw.entries)[0, 2]) | ForEach-Object { ConvertTo-Json -InputObject $_ -Depth 10 -Compress }) -join ' ## ') -ceq $beforeOtherJson)) 'True/True'
        }
        # 안 바뀌는 갈래 - expect-failed · 파일 그대로(쓰기 0). 대상 항목(n-target · 맞지 않는 단계) 옆에 다른 nonce 의 허용 단계 항목(n-other · 이 함수의 첫 허용
        # 단계)을 함께 둡니다 - -Expect 의 nonce 조건이 빠지면 그 항목 때문에 참이 되어 Mutator 가 대상 항목을 바꿉니다(명세 리뷰 2 P3 - 변이 MW20~MW22)
        $badTexts = foreach ($badStage in $spec.Bad) {
            $folder = New-CaseFolder $Context ('{0}-bad-{1}' -f $spec.Key.ToLower(), $badStage)
            $path = Get-JournalPath $folder
            Write-Fixture $path (New-JournalJson -Seq 5 -EntriesJson ('[' + (New-StageEntryJson -Nonce 'n-target' -Stage $badStage) + ',' + (New-StageEntryJson -Nonce 'n-other' -Stage $spec.Ok[0]) + ']'))
            $stateBefore = Get-FolderState $folder
            $call = Invoke-StageWriterCall -Name $spec.Name -JournalPath $path -Nonce 'n-target'
            '{0}: [{1}]/{2}/{3}/{4}/{5}' -f $badStage, ($call.Logs -join ' | '), $call.Error, (Format-StageOutputs $call.Outputs), ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)
        }
        $missingFolder = New-CaseFolder $Context ('{0}-missing' -f $spec.Key.ToLower())
        $missingPath = Get-JournalPath $missingFolder
        Write-Fixture $missingPath (New-JournalJson -Seq 5 -EntriesJson ('[' + (New-StageEntryJson -Nonce 'n-other' -Stage $spec.Ok[0]) + ']'))
        $missingBefore = Get-FolderState $missingFolder
        $missingCall = Invoke-StageWriterCall -Name $spec.Name -JournalPath $missingPath -Nonce 'n-target'
        $badTexts += ('(항목 없음): [{0}]/{1}/{2}/{3}/{4}' -f ($missingCall.Logs -join ' | '), $missingCall.Error, (Format-StageOutputs $missingCall.Outputs), ((Get-FolderState $missingFolder) -eq $missingBefore), (Get-LeftoverCount $missingFolder))
        $badWant = foreach ($badStage in @($spec.Bad + @('(항목 없음)'))) {
            if ($spec.Key -eq 'X12') { '{0}: []//1:[expect-failed]/True/0' -f $badStage } else { '{0}: [{1}]//0:[]/True/0' -f $badStage, ($spec.Warn -f '기록 실패') }
        }
        Assert-Case ('{0} {1} {2} 단계가 맞지 않음({3}) · 항목 없음 - 다른 nonce 의 허용 단계 항목이 함께 있어도 → expect-failed · 파일 그대로 · {4}' -f $prefix, $spec.Key, $spec.Name,
                ($spec.Bad -join '·'), $(if ($spec.Key -eq 'X12') { '줄 0(실패 줄은 부르는 쪽) · 출력 1(태그)' } else { '[경고] 기록 실패 1 · 출력 0' })) `
            ($badTexts -join ' || ') ($badWant -join ' || ')
        # 저장 실패 3종
        $failTexts = foreach ($failKind in @('locked', 'corrupt', 'io-failed')) {
            $folder = New-CaseFolder $Context ('{0}-fail-{1}' -f $spec.Key.ToLower(), $failKind)
            $path = Get-JournalPath $folder
            if ($failKind -eq 'corrupt') {
                Write-Fixture $path '{"version":1,"seq":'
                Write-Fixture ($path + '.bak') 'not json'
            } else {
                Write-Fixture $path (New-JournalJson -Seq 5 -EntriesJson ('[' + (New-StageEntryJson -Nonce 'n-target' -Stage $spec.Ok[0]) + ']'))
            }
            $stateBefore = Get-FolderState $folder
            $holder = $null
            if ($failKind -eq 'locked') {
                $holder = New-Object System.IO.FileStream((Get-LockPath $folder), [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)
            } elseif ($failKind -eq 'io-failed') {
                $holder = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            }
            try {
                $call = Invoke-StageWriterCall -Name $spec.Name -JournalPath $path -Nonce 'n-target'
            } finally {
                if ($null -ne $holder) { $holder.Dispose() }
            }
            '{0}: [{1}]/{2}/{3}/{4}/{5}' -f $failKind, ($call.Logs -join ' | '), $call.Error, (Format-StageOutputs $call.Outputs), ((Get-FolderState $folder) -eq $stateBefore), (Get-LeftoverCount $folder)
        }
        $failWant = foreach ($failPair in @(@('locked', '파일 사용 중'), @('corrupt', '파일 손상'), @('io-failed', '기록 실패'))) {
            if ($spec.Key -eq 'X12') { '{0}: []//1:[{0}]/True/0' -f $failPair[0] } else { '{0}: [{1}]//0:[]/True/0' -f $failPair[0], ($spec.Warn -f $failPair[1]) }
        }
        Assert-Case ('{0} {1} {2} 저장 실패 사용 중·손상·기록 실패 → {3} · 예외 0 · 파일 그대로 · 임시·잠금 0' -f $prefix, $spec.Key, $spec.Name, $(if ($spec.Key -eq 'X12') { '태그 반환(출력 1) · 줄 0' } else { '[경고] 1(설계 R2 3.6 낱말) · 출력 0' })) `
            ($failTexts -join ' || ') ($failWant -join ' || ')
        # 복구 경고 전달 - 본 파일 손상 · 직전본 유효(대상 항목 = 첫 허용 단계)면 저장소가 잠금 아래 (c) 복구 뒤 저장하고 그 경고를 돌려줍니다 - 로그는 호출부 몫(저장소
        # 계약 · X4-g 선례). 줄 = 복구 경고 1 · 그 밖 0(X13·X14 는 changed 라 실패 [경고] 없음) · 대상 항목만 다음 단계 · seq 6(복원이 아는 최대 4 + 1 = 5 를 쓰고
        # 이 저장이 + 1 - 저장소 (c) 복원 규칙) (명세 리뷰 2 P3 - 변이 MW25~MW27)
        $folder = New-CaseFolder $Context ('{0}-recover' -f $spec.Key.ToLower())
        $path = Get-JournalPath $folder
        Write-Fixture ($path + '.bak') (New-JournalJson -Seq 4 -EntriesJson ('[' + (New-StageEntryJson -Nonce 'n-target' -Stage $spec.Ok[0]) + ',' + (New-StageEntryJson -Nonce 'n-other' -Stage $spec.Ok[0]) + ']'))
        Write-Fixture $path '{"version":1,"seq":'
        $call = Invoke-StageWriterCall -Name $spec.Name -JournalPath $path -Nonce 'n-target'
        $raw = Read-JournalFile $path
        $recoverStage = @{ X12 = 'retry-attempt'; X13 = 'retry-clicked'; X14 = 'reentered' }[$spec.Key]
        Assert-Case ('{0} {1} {2} 본 파일 손상·직전본 유효 → 줄 = 복구 경고 1 · 예외 0 · 출력 {3} · 대상 {4} · 다른 항목 {5} 그대로 · seq 6 · 임시·잠금 0' -f $prefix, $spec.Key, $spec.Name,
                $(if ($spec.Key -eq 'X12') { '1:[changed]' } else { '0:[]' }), $recoverStage, $spec.Ok[0]) `
            ('[{0}]/{1}/{2}/{3}/{4}/{5}/{6}' -f ($call.Logs -join ' | '), $call.Error, (Format-StageOutputs $call.Outputs), @($raw.entries)[0].stage, @($raw.entries)[1].stage, $raw.seq, (Get-LeftoverCount $folder)) `
            ('[{0}]//{1}/{2}/{3}/6/0' -f $WARNING_BAK_RESTORE, $(if ($spec.Key -eq 'X12') { '1:[changed]' } else { '0:[]' }), $recoverStage, $spec.Ok[0])
    }

    # X15 클리어 기록의 -Decision · -NextOwner · 반환 @{ Tag; Nonce }
    $customFingerprint = 'A|solo|어려움|허상의 정박지|없음;A|solo|어려움|허상의 정박지|없음'
    $customItem = 'A|solo|어려움|허상의 정박지|없음'
    $ownerJson = '{{"version":3,"fingerprint":"{0}","orderKey":"","lap":1,"index":0,"item":"{1}","generation":2}}' -f $customFingerprint, $customItem
    $nextOwner = [pscustomobject]@{ fingerprint = $customFingerprint; orderKey = ''; lap = 1; index = 1; item = $customItem }
    $folder = New-CaseFolder $Context 'x15-custom-retry'
    $path = Get-JournalPath $folder
    $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x15a' -Custom $true -OwnerJson $ownerJson -Decision 'retry' -NextOwner $nextOwner -UseArgs
    $raw = Read-JournalFile $path
    $entry = @($raw.entries)[0]
    Assert-Case "$prefix X15-a 커스텀 retry - decision retry · nextOwner 5필드(이름·순서·값) · owner 그대로 · 반환 changed + 그 항목 nonce · 줄 = 성공 1" `
        ('{0}/{1}/{2}/{3}/[{4}]' -f $entry.decision, ((@($entry.nextOwner.PSObject.Properties | ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }) -join ',')), $entry.owner.index,
            ($call.ReturnText -ceq ('changed|' + $entry.nonce)), ($call.Logs -join ' | ')) `
        ('retry/fingerprint={0},orderKey=,lap=1,index=1,item={1}/0/True/[{2}]' -f $customFingerprint, $customItem, $CLEARED_SUCCESS_LINE)
    $nextNow = @{ fingerprint = $customFingerprint; orderKey = ''; lap = 1; index = 1; item = $customItem }
    $ownerNow = @{ fingerprint = $customFingerprint; orderKey = ''; lap = 1; index = 0; item = $customItem }
    Assert-Case "$prefix X15-a GUI 대조(-Field nextOwner) - 다음 칸·같은 세대 참 · 세대 다름 거짓 · 지금 칸 거짓" `
        ('{0}/{1}/{2}' -f (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $nextNow -Generation 2 -Field 'nextOwner'), (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $nextNow -Generation 3 -Field 'nextOwner'),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $ownerNow -Generation 2 -Field 'nextOwner')) 'True/False/False'
    # 원 워커 사슬 - 반환 nonce 로 retry-attempt → retry-clicked → reentered (다음 판 기동 후보 = nextOwner == 다음 칸 · stage reentered - GUI 의 같은 대조 함수)
    $chainNonce = [string]$call.Returned[0].Nonce
    $chainCalls = foreach ($chainName in @('Set-AbyssJournalRetryAttempt', 'Set-AbyssJournalRetryClicked', 'Set-AbyssJournalReentered')) {
        $chainCall = Invoke-StageWriterCall -Name $chainName -JournalPath $path -Nonce $chainNonce
        '{0}{1}' -f (Format-StageOutputs $chainCall.Outputs), $chainCall.Error
    }
    $raw = Read-JournalFile $path
    $entry = @($raw.entries)[0]
    Assert-Case "$prefix X15-b 원 워커 사슬 cleared → retry-attempt → retry-clicked → reentered - 출력 1:[changed] 0:[] 0:[] · seq 4 · 순위 4 · attempts 1 · retryClicks 1 · at 넷 채움 · 다음 칸 대조 참" `
        ('{0} · {1} · {2} · {3}/{4} · {5} · {6}' -f ($chainCalls -join ' '), $raw.seq, (Get-AbyssJournalStageRank -Stage ([string]$entry.stage)), $entry.attempts, $entry.retryClicks,
            (@(@('cleared', 'retryAttempt', 'retryClicked', 'reentered') | Where-Object { -not [string]::IsNullOrEmpty([string]$entry.at.$_) }).Count),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner $nextNow -Generation 2 -Field 'nextOwner')) `
        '1:[changed] 0:[] 0:[] · 4 · 4 · 1/1 · 4 · True'
    # 비커스텀 retry - nextOwner { runId }(GUI 재입장 실행부가 확정하는 값과 같은 모양 - 설계 v11 R1 3.4 순서 2)
    $folder = New-CaseFolder $Context 'x15-plain-retry'
    $path = Get-JournalPath $folder
    $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x15c' -Custom $false -Decision 'retry' -NextOwner ([pscustomobject]@{ runId = 'run-x15c' }) -UseArgs
    $entry = @((Read-JournalFile $path).entries)[0]
    Assert-Case "$prefix X15-c 비커스텀 retry - decision retry · nextOwner { runId } · GUI 대조(-Field nextOwner) 같은 실행 id 참 · 다른 실행 id 거짓 · 반환 changed + nonce" `
        ('{0}/{1}/{2}/{3}/{4}' -f $entry.decision, ((@($entry.nextOwner.PSObject.Properties | ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }) -join ',')),
            (Test-AbyssJournalOwnerMatch -Entry $entry -Owner @{ runId = 'run-x15c' } -Field 'nextOwner'), (Test-AbyssJournalOwnerMatch -Entry $entry -Owner @{ runId = 'run-other' } -Field 'nextOwner'),
            ($call.ReturnText -ceq ('changed|' + $entry.nonce))) 'retry/runId=run-x15c/True/False/True'
    # other - nextOwner 없음
    $folder = New-CaseFolder $Context 'x15-other'
    $path = Get-JournalPath $folder
    $call = Invoke-ClearedEntryCall -JournalPath $path -RunId 'run-x15d' -Custom $false -Decision 'other' -UseArgs
    $entry = @((Read-JournalFile $path).entries)[0]
    Assert-Case "$prefix X15-d other - decision other · nextOwner null · stage cleared · 반환 changed + nonce" `
        ('{0}/{1}/{2}/{3}' -f $entry.decision, ($null -eq $entry.nextOwner), $entry.stage, ($call.ReturnText -ceq ('changed|' + $entry.nonce))) 'other/True/cleared/True'
    $stageStateChanges = @($script:x4StateChanges | Select-Object -Skip $stateChangeBase)
    Assert-Case "$prefix X12~X15 전 호출 - 기록 함수가 스크립트 변수 이름 집합·워커 상태 값을 바꾸지 않음" ('{0}건 [{1}]' -f $stageStateChanges.Count, ($stageStateChanges -join ' || ')) '0건 []'
}

function Invoke-JournalStorePass {
    # 사본 하나의 동작 케이스 전부 - 케이스 하나가 예상 밖 예외로 멈춰도 FAIL 로 적고 다음 케이스로 넘어갑니다.
    # X11 은 마지막 - 저장소를 여러 번 쓴 뒤의 동작을 봅니다(케이스 안에서도 후보 읽기를 먼저 충분히 부름).
    param([hashtable]$Context)
    $caseNames = @('J01', 'J02', 'J03', 'J04', 'J05', 'J07', 'J11', 'J12', 'J13', 'J19', 'J20', 'N1s', 'N2s', 'E7s',
        'X1', 'X2', 'P1b', 'P2a', 'P2b', 'X3', 'X6', 'X7', 'X5', 'X10', 'P1a', 'P1c', 'J08', 'J09', 'J10', 'X8', 'X8Recovery', 'J06', 'J16', 'J17', 'J18', 'X11')
    foreach ($caseName in $caseNames) {
        try {
            & ('Test-Case' + $caseName) -Context $Context
        } catch {
            "FAIL {0} {1} 실행 중 예상 밖 예외: {2}" -f $Context.Prefix, $caseName, $_.Exception.Message
            $script:fails++
        }
    }
}

# ===== 실행 =====

$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
try {
    $bundles = @{
        gui    = (Get-JournalBundle -SourcePath $guiPath)
        worker = (Get-JournalBundle -SourcePath $workerPath)
    }
} catch {
    "FAIL 묶음 추출: $($_.Exception.Message)"
    exit 1
}
$copyPrefixes = @{ gui = '[GUI 사본]'; worker = '[워커 사본]' }

# 정적 단언 - J14 는 두 사본을 한 번, J15·X9·X11·P2a 정적은 사본마다
try {
    Test-BundleTokensEqual -GuiBundle $bundles.gui -WorkerBundle $bundles.worker
    foreach ($bundleKey in @('gui', 'worker')) {
        Test-BundleOutsideNames -Bundle $bundles[$bundleKey] -Prefix $copyPrefixes[$bundleKey]
        Test-BundleFlushStatic -Bundle $bundles[$bundleKey] -Prefix $copyPrefixes[$bundleKey]
        Test-BundleWriteSites -Bundle $bundles[$bundleKey] -Prefix $copyPrefixes[$bundleKey]
        Test-BundleCatchClauses -Bundle $bundles[$bundleKey] -Prefix $copyPrefixes[$bundleKey]
        Test-BundleTempListWarning -Bundle $bundles[$bundleKey] -Prefix $copyPrefixes[$bundleKey]
    }
    # 명세 2.1 표 그대로 - GUI 는 $honeyLogDir, 워커는 $logDir(같은 Log 폴더·같은 폴백)
    Test-SourceJournalNames -Bundle $bundles.gui -Prefix $copyPrefixes.gui -SavedByText "'gui'" -PathText "Join-Path `$honeyLogDir 'abyss_handoff.json'"
    Test-SourceJournalNames -Bundle $bundles.worker -Prefix $copyPrefixes.worker -SavedByText '"worker:$PID"' -PathText "Join-Path `$logDir 'abyss_handoff.json'"
    # 단계 2.10 워커 전용 함수(묶음 끝 표지 뒤) - 자리·모양(W-ONLY). 동작(X4)은 아래 워커 사본 묶음 위에서
    $workerOnly = Get-WorkerOnlyFunctions -WorkerBundle $bundles.worker
    Test-WorkerOnlyStatic -WorkerOnly $workerOnly -WorkerBundle $bundles.worker -GuiBundle $bundles.gui
    # 실행 id 읽기(W2)의 '빈 값 그대로 · 분기 없음' 을 워커 전체에서(X4-h 정적 ①② - 동작 행 X4-h 는 W2 문장 하나만 돌림, 단계 2.10 구현 검증 반영의 검토)
    Test-WorkerRunIdStatic -WorkerBundle $bundles.worker
} catch {
    "FAIL 정적 단언 실행 중 예상 밖 예외: $($_.Exception.Message)"
    $fails++
}

# 동작 케이스 - 임시 폴더(이 테스트 전용, 끝에 통째로 정리)
$testRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(), ('honeynogi_journal_test_' + [guid]::NewGuid().ToString('N')))
[void][IO.Directory]::CreateDirectory($testRoot)
$script:signalFolder = Join-Path $testRoot 'signals'
[void][IO.Directory]::CreateDirectory($script:signalFolder)
$script:childScriptPath = Join-Path $testRoot 'journal_child.ps1'
$script:childProcesses = New-Object System.Collections.ArrayList
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
try {
    [IO.File]::WriteAllText($script:childScriptPath, $CHILD_SCRIPT_TEXT, $utf8Bom)
    $bundleFiles = @{}
    foreach ($bundleKey in @('gui', 'worker')) {
        $bundleFiles[$bundleKey] = Join-Path $testRoot ('journal_bundle_' + $bundleKey + '.ps1')
        $bundleText = (@($bundles[$bundleKey].Names | ForEach-Object { $bundles[$bundleKey].Texts[$_] }) -join "`r`n`r`n") + "`r`n"
        [IO.File]::WriteAllText($bundleFiles[$bundleKey], $bundleText, $utf8Bom)
    }

    # GUI 사본 - 묶음 함수를 이 파일 최상위에서 정의합니다(체크리스트 6)
    foreach ($functionName in $bundles.gui.Names) { Invoke-Expression $bundles.gui.Texts[$functionName] }
    $script:abyssJournalSavedBy = 'test-gui'
    Invoke-JournalStorePass -Context @{
        Key = 'gui'; Prefix = $copyPrefixes.gui; Root = (Join-Path $testRoot 'gui'); SavedBy = 'test-gui'
        ThisBundle = $bundleFiles.gui; OtherBundle = $bundleFiles.worker; WorkerBundle = $bundleFiles.worker
        UpdateLocalNames = @(Get-AssignedVariableNames $bundles.gui.Functions['Update-AbyssJournal'])
        ReadShareText = (Get-ReadShareText -Bundle $bundles.gui)
    }

    # 워커 사본 - 같은 이름으로 다시 정의해 GUI 사본을 덮습니다
    foreach ($functionName in $bundles.worker.Names) { Invoke-Expression $bundles.worker.Texts[$functionName] }
    $script:abyssJournalSavedBy = 'test-worker'
    Invoke-JournalStorePass -Context @{
        Key = 'worker'; Prefix = $copyPrefixes.worker; Root = (Join-Path $testRoot 'worker'); SavedBy = 'test-worker'
        ThisBundle = $bundleFiles.worker; OtherBundle = $bundleFiles.gui; WorkerBundle = $bundleFiles.worker
        UpdateLocalNames = @(Get-AssignedVariableNames $bundles.worker.Functions['Update-AbyssJournal'])
        ReadShareText = (Get-ReadShareText -Bundle $bundles.worker)
    }

    # 워커 전용 함수(단계 2.10 W3·W4) - 묶음 밖이라 위 정의에 없습니다. 같은 최상위에서 정의하고(기록 함수의 클로저 mutator 는 함수를 부르지
    # 않지만 기록 함수 자신이 부르는 묶음 함수는 최상위 정의 - 체크리스트 6) 워커 사본 묶음 위에서만 돌립니다(X4)
    foreach ($functionName in @($workerOnly.Names)) { Invoke-Expression $workerOnly.Texts[$functionName] }
    # X4-h 가 점소싱하는 워커의 실행 id 읽기(W2 - 최상위 대입 1개, 원문 그대로). 1개가 아니면 빈 값 → X4-h 가 FAIL 로 적음
    $workerRunIdAssigns = @($bundles.worker.Ast.EndBlock.Statements | Where-Object {
            ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssRunId') })
    $workerRunIdStatement = $(if ($workerRunIdAssigns.Count -eq 1) { $workerRunIdAssigns[0].Extent.Text } else { '' })
    # X4 는 자기가 돌리는 두 함수가 있으면 돕니다(구현 명세 ② 2.1 - 목록에 더한 함수의 유무와 무관. 빠진 함수는 W-ONLY 자리 단언이 FAIL)
    if (@($X4_FUNCTION_NAMES | Where-Object { @($workerOnly.Names) -ccontains $_ }).Count -eq $X4_FUNCTION_NAMES.Count) {
        try {
            Test-CaseX4 -Context @{
                Key = 'worker'; Prefix = $copyPrefixes.worker; Root = (Join-Path $testRoot 'worker-only'); SavedBy = 'test-worker'
                UpdateText = $bundles.worker.Texts['Update-AbyssJournal']; RunIdStatement = $workerRunIdStatement
            }
        } catch {
            "FAIL {0} X4 실행 중 예상 밖 예외: {1}" -f $copyPrefixes.worker, $_.Exception.Message
            $fails++
        }
    } else {
        "FAIL {0} X4 워커 전용 함수를 찾지 못했습니다({1})" -f $copyPrefixes.worker, (@($workerOnly.Names) -join ',')
        $fails++
    }
    # 구현 명세 ⑤b2 단계 기록 셋(X12~X15) - 셋과 클리어 기록 함수가 있으면 돕니다(빠진 함수는 W-ONLY 자리 단언이 FAIL)
    if (@(@($STAGE_WRITER_NAMES + $X4_FUNCTION_NAMES) | Where-Object { @($workerOnly.Names) -ccontains $_ }).Count -eq ($STAGE_WRITER_NAMES.Count + $X4_FUNCTION_NAMES.Count)) {
        try {
            Test-CaseStageWriters -Context @{ Key = 'worker'; Prefix = $copyPrefixes.worker; Root = (Join-Path $testRoot 'worker-stage'); SavedBy = 'test-worker' }
        } catch {
            "FAIL {0} X12~X15 실행 중 예상 밖 예외: {1}" -f $copyPrefixes.worker, $_.Exception.Message
            $fails++
        }
    } else {
        "FAIL {0} X12~X15 단계 기록 함수를 찾지 못했습니다({1})" -f $copyPrefixes.worker, (@($workerOnly.Names) -join ',')
        $fails++
    }
} catch {
    "FAIL 동작 케이스 실행 중 예상 밖 예외: $($_.Exception.Message)"
    $fails++
} finally {
    # 남은 자식(실패로 신호를 못 받은 것)을 끝내고 임시 폴더를 통째로 지웁니다 - 잠금이 남아 지우지 못하면 핸들 누수 신호라 FAIL
    foreach ($childProcess in @($script:childProcesses)) {
        Stop-ChildQuietly -Process $childProcess
        $childProcess.Dispose()
    }
    $cleaned = $false
    for ($attempt = 0; $attempt -lt 10 -and -not $cleaned; $attempt++) {
        try {
            if ([IO.Directory]::Exists($testRoot)) {
                foreach ($leftFile in [IO.Directory]::GetFiles($testRoot, '*', [IO.SearchOption]::AllDirectories)) {
                    [IO.File]::SetAttributes($leftFile, [IO.FileAttributes]::Normal)
                }
                [IO.Directory]::Delete($testRoot, $true)
            }
            $cleaned = $true
        } catch {
            [System.Threading.Thread]::Sleep(200)
        }
    }
    if (-not $cleaned) {
        "FAIL 임시 폴더 정리 실패(잡힌 핸들이 남았을 수 있음): $testRoot"
        $fails++
    }
}

'참고 전체 실행 시간 {0:N1}초' -f $totalWatch.Elapsed.TotalSeconds
exit $fails
