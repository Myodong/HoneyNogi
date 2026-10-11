# 어비스 handoff GUI 종료 처리 회귀 ⑯ - 구현 명세 ① 2.4·2.5·3.3 (2026-10-09 신설 - 단계 2.6~2.10 이 행을 더합니다)
#
# 지키는 것 (단계 2.4 - 공통 최종 수집 · InsideHandoff 꼬리 숨김. 설계 v10 6.1 '종료 처리 순서' · v11 R1 3.1):
#   [C] 타이머가 종료 코드를 확정한 직후·코드별 갈래 앞에서 모든 종료 코드에 한 번 공통 최종 수집(Invoke-ExitLogFinalCollect)이 돕니다.
#       통상 tail 과 HasExited 판정 사이에 워커가 쓰고 끝낸 [완료] 줄을 코드 10(거점 퇴장 판별)·코드 4(상태줄 사유)가 읽고, 코드 0·11·1·2·3 도
#       그 줄이 창에 뜹니다(시간 지정 v2 R17 해소). 코드 1·2·3 은 정지 문구가 그대로입니다(표시만 늚). 복구 로그에만 쓰인 변형도 같습니다.
#   [F] 출처별 실패(설계 v10 R7-P2-1 · dev:989 최종 수집 실패 4경우 (가)~(라)): 읽기 실패($null)는 출처마다 [경고] 1줄, 이미 잡은 사유 보존,
#       한 출처의 실패가 다른 출처를 건너뛰지 않음, 실패한 출처의 오프셋은 그대로(줄을 버리지 않음). 파일 없음은 실패가 아닙니다(경고 0).
#   [H] InsideHandoff 꼬리 숨김(사용자 결정 Q9): 화면 줄은 꼬리 0·본문 그대로, [완료] 사유에는 꼬리가 남습니다(판별은 원문) - 통상 tail 과
#       최종 수집 두 경로 모두.
# 지키는 것 (단계 2.5 - 기동. 설계 v11 R1 3.7·3.8 · v10 6.1 'Resolve-HandoffEnvForContext' · 구현 명세 ① 2.5):
#   [L] 실제 Start-NextCycle 을 돌리는 기동 행(설계 R1 5.4 L1~L7): 범위 술어 밖이면 journal 접근 0(L1) · 읽기 실패 정지 문구(L2·L3 · 꼬리 규칙) ·
#       마무리 실행 env 를 config 를 다시 읽지 않고 보류로 조립(L4 커스텀 · L5 비커스텀) · handoff env 먼저 비움(L6) · 조립 실패 정지(L7) ·
#       워커 시작 실패 정지와 그 꼬리 규칙(L8 - 설계 R1 3.8 ⑤).
#   [K] 기동 종류 $script:lastLaunchKind 5값(none / next / own / resume / finish-only)과 그때의 env · journal launched 기록 · 마커 정리.
#   [R] Resolve-HandoffEnvForContext 진리표 - 고르는 규칙 ①~④ · launched 기록(같은 mutation · 이미 launched 면 쓰기 0) · 실패 Status.
#   [S] 정적 - 기동 함수 서명 · 호출 자리(사유 초기화 뒤·try 앞) · 정지가 handoff 상태를 비움 · RUN_ID 는 시작 버튼마다 · env 무리.
# 지키는 것 (단계 2.6 - 종료 처리 코드 0·11·10·2·3. 설계 v11 R1 3.2~3.7 · R2 3.7 · 구현 명세 ① 2.6 · 5절 A5·A6·A10·B4·B12):
#   [D] 재입장 판별(설계 R1 5.1 D1~D16) - 실제 판별 래퍼(Read-AbyssExitHandoff)와 순수부를 실제 완료 기록 파일로. 범위 밖·코드 0·11 밖·커스텀
#       위치 없음은 journal 읽기 0. 읽기 실패(locked·corrupt·io-failed·예외)는 비커스텀·커스텀 모두 journal-error(D10·D11 · D10c·D11c).
#   [HX] 행동(설계 R1 5.2 H1~H21·H27~H31·H33~H39·H41·H42) - 실제 타이머 틱이 판별 → 재입장 실행부 → 실제 Start-NextCycle(실제 후보 고르기)까지 돌고,
#       마무리 실행 완주는 같은 행의 두 번째 틱(실행부가 만든 실제 보류 그대로 - 생산자 계약 P3-2 (나))이 받습니다. 판별 실패(H13·H14)는 커스텀도
#       진행 전진 0(H13c·H14c - 다음 시작이 Step 전 owner 로 이어받음), 실패 문구의 뒷부분은 부른 자리의 실제 단계(H12c·H27′·H29″·H31′).
#   [G] 코드 10 갈래(설계 R2 5.3 G1~G7) - 갈래 첫 문장의 끝 처리가 다음 기동 앞 · 넘기지 않은 항목은 닫지 않음 · done 항목 불변(저장 0).
#   [E] 끝 처리 Complete-AbyssExitJournal - 소비 범위(0·11·4·10, 커스텀 0·11 은 -ConsumeOnly 만, 코드 10 마무리 복구 기동 생략) · -Context 를 안
#       넘김 / $null 로 넘김 / 다시 읽어도 없음 · 할 일 없으면 journal 접근 0 · 실패 문구(사용 중 안내 꼬리 포함 · 마무리 실행 기동의 끝은 '완료 표시를
#       남기지 못함') · 재입장 오류 연속 0.
#   [O] 순서 주입 - 통상 tail 뒤·HasExited 전에 쓰인 재입장 완료 줄을 공통 최종 수집이 판별 앞에 잡음(복구 로그 변형 포함).
#   [B] 안전 중지 취소 처리기(명세 5절 B12) - 마무리 실행 중 취소면 그 안내 1줄(반복을 계속한다는 줄 대신) · 보류·기동 종류 그대로(그 판 완주 = 보류 사유 정지).
#   [RW] 저장소 복구 경고 - 판별 읽기·끝 처리·실행부 필수 기록이 직전본 복구 경고를 GUI 로그로 남김.
#   [S] 정적(2.6) - 새 함수 서명·호출 소유자 · 코드 2·3 갈래 원문 불변(H32a) · 커스텀 사슬의 -ConsumeOnly 자리 · 실행부 try/기동 구조 · 클로저 ·
#       '완료 기록 파일이 사용 중' 을 담은 문구마다 잠금 파일 안내(태그·어미가 붙은 문구 포함) · N/A 행(H44·H46·H47)의 근거.
#   단계 2.6 구현 검증 보강(2026-10-09 - 생존 변이 13 · 명세 대조 P3-1~3): 감시에 저장 전 갈고리(-PreUpdateHook - 다른 기록 주체가 그 사이 잠그거나
#       항목을 지운 상황을 실제 저장이 만남)와 진행 초기화 예외 주입(-ResetThrows)을 더했습니다.
#   단계 2.6 구현 리뷰 반영(2026-10-09 - P2 해당 없음 + 단언 · P3 2): 비커스텀 0·11 끝 처리의 '사용 중' 은 '기동을 보류하고 정지 (기록 보존)'(E8 비커스텀
#       행 · H33′) · 대기열 기록·반영 실패가 '사용 중' 이면 정지 문구에 잠금 파일 안내, 손상은 안내 없음(H18′·H18″·H29′·H29‴) · 필수 기록이 retry-* 를
#       reentered 로 보정한 저장의 최상위 savedBy = gui(H10′ - 작성자 표지는 GUI 원문의 스크립트 수준 대입 값을 그대로 씀).
# 지키는 것 (단계 2.7 - 종료 처리 코드 4. 설계 v10 6.1 'GUI 계상 규칙(코드 4)' · v11 R1 3.7 표 4행 · 구현 명세 ① 2.7 · 5절 A5·B1·B2·B3·B13):
#   [W]  표지 판별 Get-WorkerDoneMarkers(순수) - 사용 중·선택 화면·ESC 메뉴·클리어 뒤 표지와 재입장 nonce(코드 0·11 판별과 같은 함수).
#   [P4] 계상 결정 Get-Code4JournalPlan(순수) - 마커 경로 · 기록 규칙은 범위·읽기 성공에서만 · 유효 = 클리어 이상·owner(세대 포함)·미적용 · 진입 컨텍스트
#        없음이면 대조 0 · 사유 표지 폴백 · 계상 0. 끝 정지 계획 Get-Code4StopPlan(순수 - H32d·H32e 의 표).
#   [C4] 행동 - 실제 타이머 틱의 코드 4 갈래가 실제 Invoke-Code4Accounting(마커 경로 포함 - 명세 5절 A5 ③)을 돕니다: v10 코드 4 행(비커스텀 클리어 기록 +1
#        정확히 1 · 나가기 위치 미발견 +1 · 커스텀 마커 유효 + 기록 → 마커 경로 1 · 마커 무효·무시 중 + 기록 → 기록 경로 1 + 전진 · 전진 실패 → 기록·마커
#        보존 정지 · 클리어 전 0 · 같은 기록 두 번 → 1 · 실행 id·세대 불일치 0 · 코드 0 뒤 잔존 0 · 사유 표지 폴백) · 재전달 예외(사용 중·선택 화면·ESC 메뉴 →
#        nonce launched 유지·마커 정리 0 → 다음 기동이 같은 항목) · 커스텀 재개 보류 / 비커스텀 재개 계상 1 · 순서 주입(종료 직전 표지 줄 - 복구 로그 변형) ·
#        H32d·H32e · 완료 기록 읽기 실패(사용 중·손상·읽기 실패·예외 → 오류 정지 · 기록 규칙 0 · 마커 경로는 셈) · 끝 처리 실패(정지 1번) · 진입 컨텍스트
#        $null(명세 5절 B13 - 한 번 못 읽으면 다시 읽지 않음) · 처리 중 예외 · 결합 행(실제 기동의 RUN_ID·OWNER env → 클리어 기록 → 코드 4).
#   [E]  끝 처리 문구 - 코드 4 = '완료 표시를 남기지 못하고 정지 (기록 보존)', 일반 코드 10 = '기동을 보류하고 정지 (기록 보존)'(단계 2.6 구현 리뷰가 넘긴
#        정리 - 코드 10 은 계상하지 않고 마커도 건드리지 않음).
#   [S]  정적(2.7) - 새 함수 서명·호출 소유자 · 마커 경로 조건식이 계상 함수 안 1곳(타이머 갈래에는 계상·전진·마커 정리 0) · try/catch 모양.
# 지키는 것 (단계 2.8 - 종료 처리 코드 1. 설계 v10 6.1 'GUI 코드 1 라우팅' · v11 R1 3.7 표 마지막 행·4·5.2 · 구현 명세 ① 2.8 · 5절 A5·A6·A10·B4):
#   [C1] 행동 - 실제 타이머 틱의 코드 1 갈래가 마무리 실행 판별 → 실제 라우팅(Invoke-Code1JournalRouting) → 실제 재입장 실행부·기동(실제 후보 고르기)까지 돕니다:
#        재입장 뒤 코드 1(H22~H26·H40·H43·H45 - 대기열 단계 code1-routed) · 비커스텀 재입장 오류 상한 3회째 = 실행부 앞 정지(H48 - 행동으로) · 마무리 실행 기동의
#        코드 1·그 밖 코드(H32b·H32c - 재시작 0 · nonce launched · 대기열·마커 그대로) · 재입장 요청(retry-*) 뒤 코드 1(재개 기능 꺼짐 = 정지 · 재개 1회 뒤 정지 ·
#        켜진 빌드 진리표 - 안전 중지 / resumeAttempts +1 → 재개 기동 / 기록 실패) · 클리어 기록 → 마무리 복구 근거(명세 5절 A10 'legacy-cleared') · 읽기 실패
#        (사용 중·손상·읽기 실패·예외) · 커스텀 진행 위치를 재시도 뒤에도 못 읽음(명세 리뷰 3 P2) · 처리 중 예외 · 정지 경로의 끝 처리(소비 0 · nonce done ·
#        재기동은 nonce 유지).
#   [E]  끝 처리 문구 - 오류 종료(코드 1·그 밖) = 코드 4 와 같은 '완료 표시를 남기지 못하고 정지 (기록 보존)' (정지하기로 정한 경로에서만 부름).
#   [D]  판별 문구(단계 2.6 구현 리뷰가 넘긴 정리) - 비커스텀 읽기 실패 = '기동을 보류하고 정지 (기록 보존)', 커스텀은 그대로.
#   [S]  정적(2.8) - 라우팅 함수 서명·구조(try 밖 기동 · 클로저) · 코드 1 갈래의 끝 처리 자리(정지 두 곳 바로 앞) · A10 항의 자리.
# 지키는 것 (단계 2.9 - 앱 기동 때 stale 정리. 명세 ① 2.9 · 5절 A7 · 설계 v10 6.1 'GUI 시작 시 정리' - 시작 게이트 S0·S3 행은 test_abyss_pending_advance [SG]):
#   [ST] 실제 Invoke-AbyssJournalStaleCleanup 을 실제 완료 기록 파일로 - 비커스텀 항목 전부 · 세대가 지금 설정과 다른 커스텀 항목·대기열 원소 제거 · 설정을 못
#        읽거나 어비스 섹션이 없으면 세대 기준을 건너뜀(커스텀 기록 보존) · 항목 20건 상한(applied ∧ launched 아님 ∧ 대기열이 가리키지 않는 오래된 것부터 -
#        재입장 항목은 done 일 때만: 다음 기동의 이어받기 후보는 남김, ST3′) · applied = 남은 항목 nonce 와의 교집합 · 지울 것 없으면 쓰기 0 · 실패는 [경고]
#        한 줄(예외 0) · 저장소 복구 경고 · 정적(설정 이전 바로 다음 문장). 설정 읽기는 모의 Read-Config($script:staleConfig - $null = 읽기 실패)입니다.
#   단계 2.7~2.9 구현 검증 보강(2026-10-09 - 생존 변이 18 · 명세 대조 P3-1): 코드 4 = 재개가 아닌 기동의 사용 중 표지는 보류가 아님(C4-13″) · 클리어 뒤
#       표지는 재전달 표지가 아님(C4-14′) · 진입 컨텍스트 $null 이어도 마커 경로는 예전 그대로·경고 0(C4-18′) · 범위 밖은 경고 0(C4-18″). 코드 1 = 꺼짐 정지가
#       안전 중지보다 먼저(RT1′) · 재개 횟수 기록의 실제 -Expect(RT6′) · reentered 가 재입장 요청보다 먼저(단계 우선′) · 주인 확인 불가는 '클리어 이상' 만
#       셈(F2″). stale = 상한 정리가 S0 가 반영한 재입장을 지우지 않음(ST3′ - 정리 뒤 실제 후보 고르기가 그 항목을 next 로 고름).
#   단계 2.7·2.8 구현 리뷰 반영(2026-10-09 - P2 1 · P3 2):
#   [NC] 코드 1 라우팅 안의 정지 넷(비커스텀 재입장 오류 상한 · 재개 1회 뒤 또 오류 · 재개 기능 꺼짐 · 안전 중지)도 정지 바로 앞에서 이번 기동 nonce 를 done 으로
#        닫음(Close-AbyssLaunchNonceOnStop) - 라우팅한 항목과 다른 nonce → done(저장 1) / 같은 nonce → 열어 둠(저장 0 - 다음 기동 후보로 남음) / 넘긴 nonce 없음 →
#        journal 접근 0 · 이미 done 이면 바꾸지 않음 · 닫기 실패(사용 중·예외)는 [경고] 1줄 뒤 원래 정지 1번 · 라우팅 반환은 'handled' 하나 · 정적(S25).
#        다음 수동 시작(실제 S0·S3·첫 기동)으로 잇는 행은 test_abyss_pending_advance [C] C10·C11.
#   코드 4·1 의 읽기 손상 정지 문구 = 사용 중처럼 실제 상태·보존 범위 + 파일 위치 안내(C4-16 · C4-16″ · F1 · F1″) · 코드 4 진입 컨텍스트 $null 의 대조 건너뜀
#        [경고]는 읽기 실패 정지 앞에도(C4-18‴ - 마커 경로가 셌으면 경고 0).
#   단계 2.7·2.8 구현 리뷰 확인 라운드(2026-10-09 - 조건부 승인의 남은 두 가지):
#        코드 1 재개 횟수 기록의 손상 정지 문구 = '재개를 보류하고 정지 (보존 범위)' + 파일 위치 안내(RT6 기대값 정정 · RT6″ 실제 손상 - 비커스텀·커스텀) ·
#        타이머 예전 처리 recover 갈래의 안전 중지도 정지 바로 앞에서 이번 기동 nonce 를 닫음(-RoutedNonce 빈 값): 있음 → done · 없음 → 접근 0 · 닫기 실패 →
#        [경고] 1줄 뒤 안전 중지 1번(NC9) · retry 갈래의 안전 중지는 열어 둠(구현 리뷰 확인 - 완료 마커도 미적용 클리어 기록도 없는 판이라 열린 nonce 가 다음
#        시작의 유일한 이어받기 근거): 있음·없음 모두 저장 0 · 정지 뒤 후보 고르기가 같은 항목(NC10) · NC11 범위 밖 읽기·저장 0 · 정적 S21(갈래 안 닫기 1 ·
#        닫기 바로 뒤 안전 중지 1/전체 2 · retry 자리 = 닫기 없이 정지 1) · S25(호출 소유자 5).
# 방법:
#   - GUI 타이머의 틱 스크립트블록($timer.Add_Tick 의 인자)을 AST 로 꺼내 그대로 돌립니다 - 통상 tail → HasExited → 종료 코드 → 공통 수집 →
#     코드 갈래가 소스 순서 그대로 실행됩니다. '통상 tail 뒤·HasExited 전' 주입(dev:989 '종료 처리 순서 주입')은 모의 워커의 HasExited 속성을
#     읽는 순간(= 그 틱의 tail 이 끝난 뒤) 로그 파일에 줄을 덧붙이거나 파일을 쥐는 것으로 합니다.
#   - 로그·완료 기록(journal)·마커는 임시 폴더의 실제 파일이고 읽기·쓰기는 실제 함수(Read-NewLogLines · 저장소 묶음)입니다. 로그 읽기 실패는
#     같은 프로세스가 그 파일을 FileShare.None 으로 쥐어 Read-NewLogLines 의 실제 catch($null)를 타게 합니다(경로별 주입 - 함수를 바꿔치기하지
#     않으므로 $null 계약도 함께 지킴). journal 잠금·교체 실패도 같은 방식(.lock 을 쥠 · 본 파일을 FileShare.Read 로 쥠)입니다.
#   - 기동 후보 선택은 모의하지 않습니다 - 실제 Resolve-HandoffEnvForContext 를 다른 이름으로 한 번 더 정의하고, 같은 이름은 호출 수만 세고
#     넘기는 얇은 감시로 가립니다(설계 R1 6.3 · dev:970 '역할 판정은 픽스처로 주입하지 않는다'). 워커 기동은 Start-Process 모의(같은 이름의
#     함수가 cmdlet 보다 먼저 불림 - 설계 R1 6.3 실행 확인)가 기동 순간의 env 를 찍어 둡니다.
#   - 추출 함수는 이 파일 최상위에서 정의합니다(구현 명세 ① 2.0 체크리스트 6 - 클로저 mutator 가 부를 수 있는 함수는 최상위 정의뿐). 모의
#     (Add-GuiLog·Add-ColoredLogLine·Stop-AllRun·Invoke-NextCycleDecision·Get-CustomCurrentContext·Clear-CustomMarkerFile·Set-CustomListRandomView·
#     Move-WorkerLogToArchive)와 Resolve 감시는 GUI 실제 서명과 대조합니다(test_time_until_mode 231~236 방식). 행 하나가 함수를 잠시 바꿔 끼울
#     때는 script: 범위로 정의하고 끝에서 GUI 원문으로 되돌립니다.
#   - 타이머 행(C·F·H)의 콘텐츠 라디오는 던전(어비스 journal 범위 밖)입니다 - 그 행들은 journal 과 무관합니다.
#   - 다른 파일이 지키는 것: 호출 자리(preparedStreak 초기화 뒤·코드 0·11 갈래 앞 한 줄) = test_time_until_mode T4-e 1b, 갈래 안 수집 0·공통
#     함수의 두 출처 = test_audit_fixes, 숨김 규칙 단위 행·수집 호출 수 = test_log_tail_offset, 기동의 UNTIL 구간 [대입, if] = T4-h·
#     test_abyss_party_member §5, 사유 초기화 → 워커 기동 창 = test_audit_fixes '회차 시작 시 사유 초기화'.
#     단계 2.6 의 타이머 문장 순서(판별 → 오류 정지 → 실행부 → 완주 → 일반 끝 처리 · 코드 10 첫 문장) = test_time_until_mode T4-e 2c·2d·S6,
#     대기열 반영의 실제 config 행(전진 총 2 · 재시작 주입) = test_abyss_pending_advance.
#   - 단계 2.6 행의 진행·마커는 모형입니다: Step-CustomProgress 는 디스크 컨텍스트 모형을 한 칸 옮기고(실패 주입 가능), Clear-CustomMarkerFile·
#     Reset-CustomProgress 는 횟수·결과만(진행 초기화는 예외 주입 가능). 완료 기록 저장소는 실제 함수이고 Read-AbyssJournal·Update-AbyssJournal 은
#     호출 수를 세는 얇은 감시(주입: 예외·태그·저장 전 갈고리)로 가립니다 - '할 일 없으면 journal 접근 0' 은 파일 상태만으로 가를 수 없습니다(쓰기
#     없는 unchanged 도 접근).
#   - 단계 2.7 의 완료 마커 유효 판정은 실제 함수(Test-CustomMarkerValidForCurrent - 임시 폴더의 마커 파일 · 디스크 컨텍스트 모형)이고, 진행 위치 읽기
#     모형은 앞에서부터 정한 횟수만 $null 을 돌려줄 수 있습니다($script:contextNullReads - 설정 파일 일시 읽기 실패).
#   - 단계 2.8 의 재개 기능 플래그($script:abyssPartyRetryEnabled)는 GUI 원문의 스크립트 수준 대입 값(이 빌드 = 꺼짐)을 그대로 씁니다 - 켜진 빌드 행만
#     잠시 참으로 두고 되돌립니다(명세 3.4 '켜짐 갈래는 진리표'). 커스텀 예전 처리(recover/retry)의 오류 대응 판정은 실제 함수(Get-CustomErrorAction)입니다.
# 지키는 것 (단계 2.10 - 워커 몫과의 결합. 구현 명세 ① 2.10 · 3.3 '① 실동작 결합 행'):
#   [C4 결합] 실제 Start-NextCycle 의 env → 워커의 실제 env 읽기 문장 → 워커 본류 끝 [완료 기록 if(W3) → 나가기 헬퍼] 두 문장(AST 점소싱)과 실제 기록 함수
#        (Add-AbyssJournalClearedEntry · ConvertTo-AbyssJournalOwner) → GUI 코드 4·0 계상(비커스텀 · 커스텀 마커 없음) · 정리 전용 → 기록 0·계상 0 · 기록 저장
#        실패(사용 중) → 워커 [경고] 1 · 헬퍼 진행 · 코드 0 이면 종료 코드로 계상 1 / 코드 4 면 0. 워커 줄은 그 틱의 종료 직전 줄로 넣어 창 표시(성공 줄 숨김)까지.
#   [C4 결합 보강] (단계 2.10 구현 검증 - 생존 변이) 완료 마커를 실제로 쓰는 판(마커 성공 → 마커 경로 / 마커 쓰기 실패 → 그래도 기록 → 기록 경로) · 본류 꼬리 전체
#        (exit 를 가로챈 사본 - 저장 성공·실패·예외와 정리 전용의 복귀 코드·종료) · 클리어 결과별 기록 여부 · [설정] 새 env 줄의 자리와 env 중복 0.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing   # 갈래의 상태줄 색([System.Drawing.Color]::SteelBlue 등)
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')   # Remove-SourceComments (정적 단언은 주석 뺀 사본으로)

# ===== 상수 =====
# GUI 에서 이름으로 추출해 최상위에 정의하는 함수 (뒤 단계가 행을 더하면 여기에 이름을 더합니다)
$GUI_FUNCTION_NAMES = @(
    'Read-NewLogLines', 'Convert-WorkerLogLineForGui', 'Invoke-ExitLogFinalCollect', 'Test-CheckpointLeaveReason',
    # 단계 2.5 기동 - 실제 Start-NextCycle 과 그 의존 (Get-CustomCurrentContext·마커 정리·랜덤 표시·로그 보관은 아래 모의)
    'Start-NextCycle', 'Set-HandoffLaunchEnv', 'Resolve-HandoffEnvForContext', 'Get-FinishOnlyCustomEnv', 'Get-InsideHandoffStopReason',
    'Get-AbyssJournalCorruptGuide', 'Clear-HandoffEnv', 'Clear-CustomEnv', 'Test-AbyssHandoffRunActive', 'Test-AbyssMemberRunActive',
    'Test-WorkerTimeJudgeActive', 'Get-TimeStatusSuffix', 'Test-CustomLastRun', 'Format-CustomItemToken', 'Get-CustomFingerprint',
    'Get-CustomOrderKey', 'Get-CustomListCompact', 'New-CustomMarkerOwnerJson', 'Get-CustomCanonicalOwner', 'ConvertTo-CustomMarkerOwnerJson',
    'Read-CustomMarkerOwner',
    # 단계 2.6 종료 처리 - 판별·실행부·완주·끝 처리와 그 의존 (다음 회차 판단 순수부·시간 판단·대기열 함수는 실제 함수)
    'Get-AbyssJournalLockedGuide', 'Get-AbyssExitStopReason', 'Get-AbyssExitHandoffKind', 'Read-AbyssExitHandoff', 'Complete-AbyssExitJournal',
    'Invoke-InsideHandoffExit', 'Complete-FinishOnlyCycle', 'Get-NextCycleAction', 'Invoke-NextCycleDecision', 'Test-TimeAllowsNextCycle',
    'Get-TimeStopNotice', 'Test-CustomLapComplete', 'Get-CustomPositionText', 'Add-AbyssPendingEntry', 'Invoke-AbyssPendingAdvance',
    'Get-AbyssJournalTagText', 'Get-CustomMarkerFileForSection',
    # 단계 2.6 구현 리뷰 - 대기열 실패의 '사용 중' 안내
    'Get-AbyssPendingStopReason',
    # 단계 2.7 코드 4 - 표지 판별·계상 결정/실행·끝 정지 계획과 마커 경로의 실제 유효 판정
    'Get-WorkerDoneMarkers', 'Get-Code4JournalPlan', 'Invoke-Code4Accounting', 'Get-Code4StopPlan',
    'Test-CustomMarkerValidForCurrent', 'Test-CustomMarkerOwnerMatchesContext',
    # 단계 2.8 코드 1 - 라우팅과 커스텀 예전 처리의 오류 대응 판정(타이머 틱이 실제로 부름) · 라우팅 안 정지 경로의 이번 기동 nonce 닫기(단계 2.7·2.8
    # 구현 리뷰 P2)
    'Invoke-Code1JournalRouting', 'Get-CustomErrorAction', 'Close-AbyssLaunchNonceOnStop',
    # 단계 2.9 - 앱 기동 때 stale 정리(설정 읽기는 아래 모의 Read-Config)
    'Invoke-AbyssJournalStaleCleanup')
# 모의·감시 - 같은 이름의 GUI 실제 함수와 서명을 대조합니다
$MOCK_FUNCTION_NAMES = @('Add-GuiLog', 'Add-ColoredLogLine', 'Stop-AllRun', 'Invoke-NextCycleDecision',
    'Get-CustomCurrentContext', 'Clear-CustomMarkerFile', 'Set-CustomListRandomView', 'Move-WorkerLogToArchive', 'Resolve-HandoffEnvForContext',
    'Step-CustomProgress', 'Reset-CustomProgress', 'Read-AbyssJournal', 'Update-AbyssJournal', 'Read-Config')
$BUNDLE_HEADER_FRAGMENT = '어비스 완료 기록(handoff journal) 저장소'   # 저장소 묶음 머리 주석 (회귀 test_abyss_journal_store 와 같은 경계)
$BUNDLE_END_FRAGMENT = '어비스 완료 기록 저장소 묶음 끝'                 # 저장소 묶음 끝 표지 주석
$WARN_WORKER = '[경고] 종료 로그 최종 수집 실패(워커 로그) - 정지 사유를 놓쳤을 수 있습니다'
$WARN_RECOVERY = '[경고] 종료 로그 최종 수집 실패(복구 로그) - 정지 사유를 놓쳤을 수 있습니다'
$UTF8_BOM = New-Object System.Text.UTF8Encoding($true)
$UTF8_NO_BOM = New-Object System.Text.UTF8Encoding($false)

# 로그 줄 (워커가 실제로 쓰는 문구 - 줄 머리 'HH:mm:ss ' 는 워커 Write-RunLog 모양)
$EARLY_LINES = @(
    '12:00:00 [어비스] 클리어 문구(화면을 터치) 감지',
    '12:00:01 [어비스] 나가기 클릭 - 글자 탐색 기준좌표 (491,662)')
$EARLY_SHOWN = @('line|  12:00:00 [어비스] 클리어 문구 감지', 'line|  12:00:01 [어비스] 나가기 클릭')   # 화면 변환 뒤(꼬리·좌표 정리)
$RECOVERY_HEAD = @(
    '[2026-10-09] 자동화 로그 (시작 12:00:00)',   # 복구 로그 머리글 - 화면에서는 숨김
    '12:00:02 [경고] 기본 로그 기록 중 오류가 발생해 복구 로그(mabinogi_run_once.recovery.log)로 전환했습니다: 다른 프로세스가 파일을 사용 중입니다')
$RECOVERY_HEAD_SHOWN = @('line|  12:00:02 [경고] 기본 로그 기록 중 오류가 발생해 복구 로그(mabinogi_run_once.recovery.log)로 전환했습니다: 다른 프로세스가 파일을 사용 중입니다')
$CODE4_REASON = '게임 서버 연결이 끊어졌습니다 - 재접속 후 다시 시작해 주세요 (조건부 정지)'
# 설계 v10 의 재전달 표지(' (selection-overlay)' - 워커가 내는 단위는 ②·⑤)를 붙인 코드 4 사유 - 이 단계에서는 사유로 보존되는지만 봅니다
$OVERLAY_REASON = $CODE4_REASON + ' (selection-overlay)'
$CHECKPOINT_REASON = '거점 부활 상한으로 던전을 나왔습니다 - 선택 화면 복귀 완료 (준비 실행 - 회차로 세지 않음, 다음 회차에서 새 파티로 재입장)'
$PREPARED_REASON = '어비스 선택 화면 복귀 완료 (준비 실행 - 회차로 세지 않음)'
$CHECKPOINT_NOTICE = 'gui|[안내] 사망 화면에서 던전을 나왔습니다(거점 부활 상한 또는 부활 불가 대기 초과) - 회차로 세지 않고 새 파티로 재입장합니다'
$PREPARED_NOTICE = 'gui|[안내] 화면 복귀(준비 실행)만 수행 - 회차로 세지 않고 이어서 시작합니다'
$CODE4_FALLBACK_STOP = 'stop|조건 충족으로 정지 - 은동전 소진 등 (자세한 내용은 로그 참고)|False'
# InsideHandoff 완료 줄(설계 R1 2.2 순서 4 - 워커 문구 그대로, 꼬리의 nonce 는 GUID 'D' 형식)
$IH_BODY = "[완료] '다시 하기' 재입장 확인 - 직전 판을 회차로 계상, 다음 실행이 이 판을 이어받습니다"
$IH_NONCE_LOWER = '0f8fad5b-d9cb-469f-a165-70867728950e'
$IH_NONCE_UPPER = '7C9E6679-7425-40DE-944B-E07FC1F90AE7'

# 기동 (단계 2.5) - 정지 문구는 설계 R1 3.8 ⑤ · 3.5 꼬리 · 명세 5절 C11 의 사용자 문구 그대로 고정합니다
# '사용 중' 정지 문구 끝의 잠금 파일 안내(단계 2.4~2.5a 구현 리뷰 조건 - 단계 2.6 에서 Get-AbyssJournalLockedGuide 로 만들어 기동·종료 처리에 붙임)
$LOCKED_GUIDE = '(다른 꿀비노기·powershell 프로세스가 없는데도 계속되면 %LOCALAPPDATA%\HoneyNogi\Log 의 abyss_handoff.lock 파일을 지운 뒤 다시 시작해 주세요)'
$STOP_LOCKED = '완료 기록 파일이 사용 중 - 기동을 보류하고 정지 (기록·마커 보존) ' + $LOCKED_GUIDE
# 손상 문구 끝의 파일 위치 안내(명세 5절 C11 - Get-AbyssJournalCorruptGuide). 코드 4·1 의 읽기 손상은 사용 중처럼 '실제 상태 (보존 범위)' 뒤에 이 안내를
# 붙이고(단계 2.7·2.8 구현 리뷰 P3 - 코드 1 의 재개 횟수 기록 손상도 같은 규칙: 같은 리뷰의 확인 라운드), 그 밖 자리(기동·판별·끝 처리·실행부)는
# '파일을 보존하고 정지' 뒤에 붙입니다
$CORRUPT_GUIDE = '(%LOCALAPPDATA%\HoneyNogi\Log 의 abyss_handoff.json* 파일을 다른 폴더로 옮긴 뒤 다시 시작해 주세요)'
$STOP_CORRUPT = '완료 기록 파일 손상 - 파일을 보존하고 정지 ' + $CORRUPT_GUIDE
$STOP_ERROR = '완료 기록 파일을 읽거나 쓰지 못해 기동을 보류하고 정지'
$STOP_TAIL = " (캐릭터가 '다시 하기'로 들어간 던전 안일 수 있음 - 입장 키 미전송)"
$FINISH_PREP_FORMAT = '마무리 실행 준비 실패({0}) - 기동을 보류하고 정지'
$INJECTED_STORE_EXCEPTION = '주입: 완료 기록 저장소 예외'
$INJECTED_TOKEN_EXCEPTION = '주입: 토큰 조립 예외'
$INJECTED_START_EXCEPTION = '주입: 워커 프로세스 시작 예외'
# 워커 기동 실패(Start-Process 예외·프로세스 없음) - 실제 기동이 남기는 [경고] 줄과 정지 사유 원문(설계 R1 3.8 ⑤ '지금 문구 그대로')
$START_FAIL_WARNING = '[경고] 자동화 프로세스를 시작하지 못했습니다 - 실행 상태를 되돌립니다. 잠시 후 다시 시작해 주세요.'
$STOP_START_FAIL = '워커 시작 실패'
$STALE_VALUE = 'stale-before'      # 기동 전 env 에 미리 넣어 두는 값 - 그대로 남으면 '먼저 비움'·덮어쓰기가 안 된 것
$HANDOFF_ENV_NAMES = @('HONEYNOGI_HANDOFF_NONCE', 'HONEYNOGI_RESUME_REENTRY', 'HONEYNOGI_FINISH_ONLY')
# Clear-CustomEnv 가 지우는 커스텀 env (단계 2.5 - GENERATION 추가) + 마무리 실행이 빈 값으로 두는 ② 단위 env 2개
$CUSTOM_ENV_NAMES = @('HONEYNOGI_CUSTOM_ITEM', 'HONEYNOGI_CUSTOM_PREV', 'HONEYNOGI_CUSTOM_NEXT', 'HONEYNOGI_CUSTOM_RESTART',
    'HONEYNOGI_CUSTOM_RECOVERY', 'HONEYNOGI_CUSTOM_POSITION', 'HONEYNOGI_CUSTOM_LIST', 'HONEYNOGI_CUSTOM_MARKER', 'HONEYNOGI_CUSTOM_OWNER',
    'HONEYNOGI_CUSTOM_GENERATION', 'HONEYNOGI_LAST_RUN')
$NEXT_OWNER_ENV_NAMES = @('HONEYNOGI_CUSTOM_NEXT_OWNER', 'HONEYNOGI_CUSTOM_NEXT_BOUNDARY')
$OTHER_ENV_NAMES = @('HONEYNOGI_REPEAT_INFO', 'HONEYNOGI_UNTIL_TIME', 'HONEYNOGI_RUN_ID', 'HONEYNOGI_APP_VERSION')
$ALL_ENV_NAMES = @($HANDOFF_ENV_NAMES + $CUSTOM_ENV_NAMES + $NEXT_OWNER_ENV_NAMES + $OTHER_ENV_NAMES)
$ABYSS_SECTION = 'abyssCustomRepeat'
# 어비스 커스텀 목록 픽스처 (항목 토큰만 쓰임 - 던전 이름은 아무것이나)
$ABYSS_ITEMS = @(
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '잊혀진 성소'; matching = '우연한 만남' },
    [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '일반'; dungeon = '그림자 회랑'; matching = '' })
# 완료 기록 픽스처 nonce (GUID 'D' 형식)
$NONCE_A = 'a0000000-0000-4000-8000-00000000000a'
$NONCE_B = 'b0000000-0000-4000-8000-00000000000b'
$NONCE_C = 'c0000000-0000-4000-8000-00000000000c'
$NONCE_D = 'd0000000-0000-4000-8000-00000000000d'
$NONCE_LABELS = @{ $NONCE_A = 'NA'; $NONCE_B = 'NB'; $NONCE_C = 'NC'; $NONCE_D = 'ND' }

# 종료 처리 (단계 2.6) - 사용자 문구는 설계 v10 6.1 호출부 규칙 · v11 R1 3.2·3.5·3.7 · 명세 2.6 · 5절 B12 의 글자를 계약으로 고정합니다
$IH_TAIL_FORMAT = ' [terminal=InsideHandoff nonce={0}]'                   # 워커 재입장 완료 줄의 표지 꼬리(설계 R1 2.2 순서 4)
$IH_REASON = $IH_BODY.Substring('[완료] '.Length)                          # [완료] 뒤 사유 본문
$READY_REASON = '어비스 선택 화면 복귀 완료'                                # 선택 화면 복귀(ReadySelection) 줄
$EXIT_LOCKED_ADVANCE = '완료 기록 파일이 사용 중 - 진행 전진·기동을 보류하고 정지 (기록·마커 보존) ' + $LOCKED_GUIDE   # 코드 0·11 판별·첫 끝 처리
# 비커스텀 0·11 일반 끝 처리(단계 2.6 구현 리뷰 P3)·일반 코드 10(같은 리뷰가 2.7 로 넘김): 못 한 일은 기동뿐 - '기동을 보류하고 정지 (기록 보존)'.
# 코드 10 은 계상하지 않고 마커도 건드리지 않아 옛 글자 '계상·기동을 보류하고 정지 (기록·마커 보존)' 은 실제 상태와 달랐음
$EXIT_LOCKED_PLAIN = '완료 기록 파일이 사용 중 - 기동을 보류하고 정지 (기록 보존) ' + $LOCKED_GUIDE
$EXIT_READ_FAIL = '완료 기록 파일을 읽지 못해 진행 전진·기동을 보류하고 정지 (기록·마커 보존)'   # 커스텀 판별 읽기 실패
# 비커스텀 판별 읽기 실패(단계 2.6 구현 리뷰가 넘긴 정리 - 2.8): 계상은 공통 구간이 이미 했고 진행 전진·완료 마커가 없어 못 한 일은 기동뿐
$EXIT_READ_FAIL_PLAIN = '완료 기록 파일을 읽지 못해 기동을 보류하고 정지 (기록 보존)'
$EXIT_SAVE_FAIL = '완료 기록 저장 실패 - 기동을 보류하고 정지 (기록 보존)'
$EXIT_NO_MATCH = '재입장 완료 문구와 맞는 완료 기록이 없음 - 기동을 보류하고 정지'
$EXIT_NO_CONTEXT = '커스텀 진행 위치를 읽지 못해 완료 기록을 대조하지 못함'
$IH_RECORD_FAIL = '재입장 완료 기록 실패 - 기동을 보류하고 정지 (기록 보존)'
$IH_QUEUE_FAIL = '커스텀 진행 기록·대기열 저장 실패 - 중복 실행 방지를 위해 정지'
$IH_EXCEPTION_FORMAT = '재입장 처리 중 예외 - 기동을 보류하고 정지 ({0})'
$IH_LOG_WARNING = '[경고] 재입장 완료 기록이 없어 종료 문구로 이어받기를 확인했습니다 - 완료 기록을 보정하고 이어 갑니다'
$IH_REPLACED_WARNING = '[경고] 재입장 완료 기록의 다음 판 위치가 진행 기록과 달라 진행 기록 값으로 고쳤습니다'
$FINISH_NOTICE_FORMAT = "{0} 마무리 실행: {1} - '다시 하기'로 이미 들어간 판을 끝까지 하고 선택 화면에서 멈춥니다"
$CARRY_NOTICE_FORMAT = '[안내] 지정 시간({0}) 전에 워커가 다음 판으로 이어 가기로 정했습니다 - 다음 워커가 이어받아 마무리합니다.'
$FINISH_RECORD_FAIL = '마무리 실행 완료 기록 저장 실패 - 대기열·마커를 보존하고 정지'
$FINISH_ADVANCE_FAIL = '마무리 실행 진행 반영 실패 - 대기열·마커를 보존하고 정지'
# 대기열 기록·반영이 '사용 중' 으로 실패하면 정지 문구 끝에 잠금 파일 안내(단계 2.6 구현 리뷰 P3 - 손상 등 그 밖 실패는 문구 그대로)
$IH_QUEUE_FAIL_LOCKED = $IH_QUEUE_FAIL + ' ' + $LOCKED_GUIDE
$FINISH_RECORD_FAIL_LOCKED = $FINISH_RECORD_FAIL + ' ' + $LOCKED_GUIDE
$FINISH_ADVANCE_FAIL_LOCKED = $FINISH_ADVANCE_FAIL + ' ' + $LOCKED_GUIDE
$B12_NOTICE = '안전 중지 취소: 마무리 중인 판은 끝까지 하고 멈춥니다 (취소는 다음 시작부터)'
$B12_PLAIN = '안전 중지 취소: 반복을 계속합니다.'
$INJECTED_UPDATE_EXCEPTION = '주입: 완료 기록 저장 예외'
$INJECTED_READ_EXCEPTION = '주입: 완료 기록 읽기 예외'
$INJECTED_GUILOG_EXCEPTION = '주입: GUI 로그 줄 예외'                     # 기동 계획이 정해진 뒤의 예외(H12 (바) - catch 의 return 계약)
$H_GENERATION = 3                                                          # 커스텀 행의 진행 세대 - 0 이 아니어야 세대를 빠뜨린 보류가 드러남
# 단계 2.6 구현 검증 보강 - 실패 문구의 뒷부분은 부른 자리의 실제 단계(명세 대조 P3-2): 마무리 실행 기동의 끝 처리 실패는 기동할 다음 판이 없어
# '완료 표시를 남기지 못하고 정지' - 커스텀 0·11 완주(대기열 반영 뒤)는 '(진행은 반영됨)', 그 밖 '(기록 보존)'. 실행부 필수 기록의 사용 중은 커스텀
# 전진 뒤면 마커를 이미 정리해 '(기록 보존)'
$FINISH_END_APPLIED = '마무리 실행 완료 표시를 남기지 못하고 정지 (진행은 반영됨)'
$FINISH_END_KEPT = '마무리 실행 완료 표시를 남기지 못하고 정지 (기록 보존)'
$FINISH_LOCKED_APPLIED = '완료 기록 파일이 사용 중 - ' + $FINISH_END_APPLIED + ' ' + $LOCKED_GUIDE
$FINISH_LOCKED_KEPT = '완료 기록 파일이 사용 중 - ' + $FINISH_END_KEPT + ' ' + $LOCKED_GUIDE
$FINISH_SAVE_APPLIED = '완료 기록 저장 실패 - ' + $FINISH_END_APPLIED
$FINISH_SAVE_KEPT = '완료 기록 저장 실패 - ' + $FINISH_END_KEPT
$IH_LOCKED_ADVANCED = '완료 기록 파일이 사용 중 - 기동을 보류하고 정지 (기록 보존) ' + $LOCKED_GUIDE
$RECOVERED_WARNING = '[경고] 완료 기록 파일 손상 - 직전본으로 복구'       # 저장소 (c) 복구 경고 - 부른 쪽이 GUI 로그로 남김(저장소 계약)
$RECOVERY_DONE_LINE = '[커스텀] 마무리 복구 완료 - 다음 항목으로 진행합니다.'
$INJECTED_RESET_EXCEPTION = '주입: 진행 초기화 예외'                       # 완주 처리 안의 예외(H30′ - 완주 함수의 catch 계약)
$FINISH_EXCEPTION_FORMAT = '마무리 실행 완주 처리 중 예외 - 정지 ({0})'

# 종료 처리 코드 4 (단계 2.7) - 사용자 문구는 설계 v10 6.1 'GUI 계상 규칙(코드 4)' · v11 R1 3.7 · 명세 2.7·5절 B2·B13 의 글자를 고정합니다.
# 정지 문구의 뒷부분은 실제 상태(단계 2.6 구현 리뷰 기준): 코드 4 는 다음 기동이 없어 '기동' 을 적지 않고, 계상 앞에서 멈추면 '계상을 보류'(커스텀은
# 마커도 그대로 - 비커스텀은 마커가 없음), 마커 경로가 센 뒤 멈추면 '완료 표시를 남기지 못함 (진행은 반영됨)'
$C4_POST_CLEAR_WARNING = '[경고] 완료 기록 없이 계상(사유 표지)'
$C4_NO_CONTEXT_WARNING = '[경고] 커스텀 진행 위치를 읽지 못해 완료 기록 대조를 건너뜁니다 - 다음 시작에서 이어받습니다'
$C4_STEP_FAIL_MARKER = '조건 정지 판의 커스텀 진행 기록 저장 실패 - 완료 마커를 보존하고 정지'   # 마커 경로(예전 갈래 원문)
$C4_STEP_FAIL_JOURNAL = '조건 정지 판의 커스텀 진행 기록 저장 실패 - 완료 기록을 보존하고 정지'  # 기록 경로(명세 2.7 ③ ②)
$C4_HELD_CUSTOM = '계상을 보류하고 정지 (기록·마커 보존)'
$C4_HELD_PLAIN = '계상을 보류하고 정지 (기록 보존)'
$C4_HELD_APPLIED = '완료 표시를 남기지 못하고 정지 (진행은 반영됨)'
$C4_END_KEPT = '완료 표시를 남기지 못하고 정지 (기록 보존)'                # 끝 처리(Complete-AbyssExitJournal -ExitCode 4) 실패
$C4_END_LOCKED = '완료 기록 파일이 사용 중 - ' + $C4_END_KEPT + ' ' + $LOCKED_GUIDE
$C4_END_SAVE = '완료 기록 저장 실패 - ' + $C4_END_KEPT
$C4_EXCEPTION_FORMAT = '조건 정지 판의 완료 기록 처리 중 예외 - 정지 ({0})'
$C4_PRIOR_ERROR_FORMAT = '{0} (마무리 실행 전 오류: {1})'                # 설계 v11 R1 3.7 표 4행 · H32d
# 워커 나가기 헬퍼 미검출 정지 사유(run_once 보상 화면 '나가기' 위치 미발견 - 클리어 기록 뒤의 코드 4, 명세 0.3 ②의 출구)
$C4_EXIT_HELPER_REASON = "보상 화면에서 '나가기' 버튼 위치를 찾지 못했습니다 (재판독 5회·12초, 판독: '') - 재입장 오클릭('다시 하기' 자리)을 막기 위해 정지합니다"
$C4_STOP = "stop|조건 정지: $CODE4_REASON|False"                           # 코드 4 정상 정지(사유 그대로)
# 워커 클리어 완료 기록(단계 2.10 W3)의 줄 - 성공 줄은 GUI 가 창에서 숨기고(W7) 저장 실패 [경고] 줄은 보입니다(낱말은 설계 R2 3.6 · 문구 원문 고정은
# test_abyss_journal_store X4, 숨김 규칙 단위 행은 test_log_tail_offset W7)
$CLEARED_SUCCESS_TEXT = '[어비스] 클리어 완료 기록 저장 (결과 화면 도달)'
$CLEARED_FAIL_LOCKED = '[경고] 클리어 완료 기록을 저장하지 못했습니다 (파일 사용 중) - 정상 종료면 GUI가 종료 코드로 계상하므로 진행을 계속합니다'

# 종료 처리 코드 1 (단계 2.8) - 사용자 문구는 설계 v10 6.1 'GUI 코드 1 라우팅' · v11 R1 3.7 표 마지막 행 · 명세 2.8 의 글자(설계에 글자가 없는 것은 구현 글자)를
# 고정합니다. 읽기 실패의 '못 한 일' 은 실제 상태 - 라우팅 전이라 계상·기동(재입장 이어받기·자동 재시작·재개)을 보류, 커스텀은 마커도 그대로
$C1_FINISH_FORMAT = '마무리 실행 중 오류 종료(코드 {0}) - 자동 재시작하지 않고 정지 (진행 기록 보존, 캐릭터가 던전 안일 수 있습니다)'   # 설계 R1 3.7 · dev:892
$C1_HELD_CUSTOM = '계상·기동을 보류하고 정지 (기록·마커 보존)'
$C1_HELD_PLAIN = '계상·기동을 보류하고 정지 (기록 보존)'
$C1_NO_OWNER = '설정 파일을 읽지 못해 완료 기록의 주인을 확인할 수 없습니다 - 기록을 지우지 않고 정지 (자동 재시작 없음)'   # 명세 리뷰 3 P2
$C1_STREAK_STOP = '오류 종료(코드 1) - 재입장한 판에서 3회 연속 오류라 이어 가지 않고 정지 (로그 확인)'                      # 설계 R1 H48
$C1_RETRY_OFF = '재입장 요청 뒤 오류 종료 - 재개 기능이 꺼져 있어 완료 기록을 보존하고 정지 (캐릭터가 던전 안일 수 있습니다)' # dev:888 원문
$C1_RESUMED_AGAIN = '재입장 요청 뒤 재개한 판도 오류 종료 - 자동 재개는 한 번뿐이라 완료 기록을 보존하고 정지 (캐릭터가 던전 안일 수 있습니다)'   # dev:889
$C1_SAFE_NOTICE = '[안내] 재입장 요청 뒤 오류 종료 - 안전 중지라 재개하지 않고 정지합니다 (캐릭터가 던전 안일 수 있습니다 - 다음 시작에서 재개)'   # dev:888 원문
$C1_RESUME_NOTICE = '[경고] 오류 종료(코드 1) - 재입장 요청 뒤라 그 판을 이어받는 재개를 한 번 시작합니다'
$C1_RESUME_LOCKED_FORMAT = '완료 기록 파일이 사용 중 - 재개를 보류하고 정지 ({0}) ' + $LOCKED_GUIDE
$C1_RESUME_SAVE_FORMAT = '재개 기록 저장 실패 - 재개를 보류하고 정지 ({0})'
# 재개 횟수 기록의 손상 - 사용 중처럼 실제 상태(재개 보류 · 보존 범위) 뒤에 파일 위치 안내(단계 2.7·2.8 구현 리뷰 확인 라운드 - 예전 글자 '파일을 보존하고 정지')
$C1_RESUME_CORRUPT_FORMAT = '완료 기록 파일 손상 - 재개를 보류하고 정지 ({0}) ' + $CORRUPT_GUIDE
$C1_EXCEPTION_FORMAT = '오류 종료 판의 완료 기록 처리 중 예외 - 자동 재시작하지 않고 정지 ({0})'
$C1_STOP_THIRD = '오류 종료(코드 1) - 같은 항목 3회 연속 실패 (로그 확인)'          # 예전 커스텀 3회째 정지(글자 그대로)
$C1_STOP_PLAIN_FORMAT = '오류 종료(코드 {0}) - 로그 확인'                           # 예전 그 밖 오류 정지(글자 그대로)
$C1_RETRY_FORMAT = '[경고] 오류 종료(코드 1) - 같은 항목을 자동 재시작합니다 (재시도 {0}/2)'
$C1_RECOVER_NOTICE = '[커스텀] 이전 완료 항목의 마무리를 복구합니다.'
# 라우팅 안 정지 경로의 이번 기동 nonce 닫기가 실패했을 때의 한 줄(단계 2.7·2.8 구현 리뷰 P2 - 구현 글자를 계약으로 고정): 정지는 그대로 한 번, 괄호 = 실패 종류
# 낱말(Get-AbyssJournalTagText) 또는 '예외: <메시지>'
$C1_CLOSE_FAIL_FORMAT = '[경고] 이번 기동의 완료 표시를 남기지 못했습니다({0}) - 정지는 그대로 합니다'

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
    $guiFunctionTexts[$statement.Name] = $statement.Extent.Text
    Invoke-Expression $statement.Extent.Text
    $bundleFunctionNames += $statement.Name
}
if ($bundleFunctionNames -notcontains 'Update-AbyssJournal') { throw '완료 기록 저장소 묶음에 Update-AbyssJournal 이 없습니다' }
# 저장소가 적는 작성자 표지(savedBy)는 GUI 원문의 스크립트 수준 대입 값을 그대로 씁니다 - H10′ 이 GUI 저장의 최상위 savedBy = gui 를 단언하므로
# 테스트가 값을 다시 박으면 원문이 바뀌어도 움직이지 않습니다(단계 2.6 구현 리뷰 P2)
$savedByAssigns = @($guiAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssJournalSavedBy') })
if ($savedByAssigns.Count -ne 1) { throw ('GUI 의 작성자 표지($script:abyssJournalSavedBy) 스크립트 수준 대입이 1개가 아닙니다 ({0}개)' -f $savedByAssigns.Count) }
$script:abyssJournalSavedBy = [string]$savedByAssigns[0].Right.Expression.Value
# 재개 기능 플래그(단계 2.8)도 GUI 원문의 스크립트 수준 대입 값 그대로 - 코드 1 의 retry-* 가 '정지' 인지 '재개' 인지가 이 값으로 갈립니다
$retryFlagAssigns = @($guiAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssPartyRetryEnabled') })
if ($retryFlagAssigns.Count -ne 1) { throw ('GUI 의 재개 기능 플래그($script:abyssPartyRetryEnabled) 스크립트 수준 대입이 1개가 아닙니다 ({0}개)' -f $retryFlagAssigns.Count) }
$GUI_RETRY_FLAG = [bool](Invoke-Expression $retryFlagAssigns[0].Right.Extent.Text)
$script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
# Resolve 감시: 실제 함수를 Invoke-RealResolveHandoffEnv 로 한 번 더 정의하고, 같은 이름은 호출 수만 세고 넘깁니다 (후보 선택은 실제 함수)
Invoke-Expression ($guiFunctionTexts['Resolve-HandoffEnvForContext'] -replace '^function Resolve-HandoffEnvForContext\b', 'function Invoke-RealResolveHandoffEnv')
function Resolve-HandoffEnvForContext {
    # 감시(실제 서명 param($Context, [bool]$Restart = $false, [string]$ResumeNonce = '')) - 호출 수를 세고 실제 함수로 넘깁니다.
    # 단계 2.6 행의 기동 실패 주입: $script:resolveOverride 가 있으면 실제 함수 대신 그 결과(재입장 실행부가 부른 기동의 보류 정지 꼬리)
    param($Context, [bool]$Restart = $false, [string]$ResumeNonce = '')
    $script:resolveCalls++
    if ($null -ne $script:resolveOverride) { return $script:resolveOverride }
    return (Invoke-RealResolveHandoffEnv @PSBoundParameters)
}
# 저장소 감시(단계 2.6): 실제 잠금 읽기·저장을 다른 이름으로 한 번 더 정의하고, 같은 이름은 호출 수를 세고 넘깁니다(저장 함수 안의 재판독은
# Read-AbyssJournalHeld 라 잠금 읽기 수에 들지 않음). 주입은 행이 정합니다 - 예외($script:readThrows · $script:updateThrowAt = N 번째 저장) ·
# 태그($script:updateTagAt = @{ At = N; Tag = '…' } - N 번째 저장을 쓰지 않고 그 태그로) · 저장 전 갈고리($script:preUpdateHook 을
# $script:preUpdateAt 번째 저장 직전에 실행 - 다른 기록 주체가 그 사이에 잠그거나 항목을 지운 상황. 태그 주입과 달리 실제 저장이 그 상태를 만남)
Invoke-Expression ($guiFunctionTexts['Read-AbyssJournal'] -replace '^function Read-AbyssJournal\b', 'function Invoke-RealReadAbyssJournal')
Invoke-Expression ($guiFunctionTexts['Update-AbyssJournal'] -replace '^function Update-AbyssJournal\b', 'function Invoke-RealUpdateAbyssJournal')
function Read-AbyssJournal {
    # 감시(실제 서명 param([string]$Path)) - 잠금 읽기 수를 세고 실제 함수로
    param([string]$Path)
    $script:journalReads++
    if ($script:readThrows) { throw $INJECTED_READ_EXCEPTION }
    return (Invoke-RealReadAbyssJournal -Path $Path)
}
function Update-AbyssJournal {
    # 감시(실제 서명 param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect = $null)) - 저장 수를 세고 실제 함수로
    param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect = $null)
    $script:journalUpdates++
    if (($null -ne $script:preUpdateHook) -and ([int]$script:preUpdateAt -eq $script:journalUpdates)) { & $script:preUpdateHook }
    if ($script:updateThrowAt -eq $script:journalUpdates) { throw $INJECTED_UPDATE_EXCEPTION }
    if (($null -ne $script:updateTagAt) -and ([int]$script:updateTagAt.At -eq $script:journalUpdates)) { return @{ Tag = [string]$script:updateTagAt.Tag; Warnings = @() } }
    return (Invoke-RealUpdateAbyssJournal -Path $Path -Mutator $Mutator -Expect $Expect)
}
# 행 하나가 저장 함수를 잠시 바꿔 끼운 뒤 되돌릴 원문 = 위 감시(이 파일의 함수 정의)
$selfAstForSpies = [System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$null, [ref]$null)
$UPDATE_SPY_TEXT = @($selfAstForSpies.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq 'Update-AbyssJournal') }, $true))[0].Extent.Text
# 실제 다음 회차 판단(Invoke-NextCycleDecision)은 다른 이름으로 - 같은 이름은 아래 모의가 가리고, 연속 수 상한 행(G5)만 실제로 넘깁니다
Invoke-Expression ($guiFunctionTexts['Invoke-NextCycleDecision'] -replace '^function Invoke-NextCycleDecision\b', 'function Invoke-RealNextCycleDecision')
$script:journalReads = 0
$script:journalUpdates = 0
$script:readThrows = $false
$script:updateThrowAt = 0
$script:updateTagAt = $null
$script:preUpdateHook = $null
$script:preUpdateAt = 0
$script:resetThrows = $false
$script:resolveOverride = $null
$script:guiLogThrowMatch = ''
$script:decisionMode = 'record'
# 타이머 틱 - $timer.Add_Tick({ … }) 의 스크립트블록 본문(try { tail · 종료 처리 } catch { … })을 그대로
$tickCalls = @($guiAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
            $node.Expression.Extent.Text -eq '$timer' -and $node.Member.Extent.Text -eq 'Add_Tick'
        }, $true))
if ($tickCalls.Count -ne 1) { throw ('타이머 틱 등록($timer.Add_Tick)이 {0}개입니다(1개여야 함)' -f $tickCalls.Count) }
$timerTick = [scriptblock]::Create($tickCalls[0].Arguments[0].ScriptBlock.EndBlock.Extent.Text)
# 워커 쪽(단계 2.10 결합 행 - 구현 명세 ① 3.3 '① 실동작 결합 행') - 실제 워커 소스에서 꺼냅니다: 워커 함수 3개(완료 마커 Write-CustomClearMarker ·
# 묶음 끝 표지 뒤의 워커 전용 기록 함수 2개 - 최상위 정의, 체크리스트 6) · 기동 env 를 받는 문장 3개(커스텀 마커 경로 · 소유자 JSON · 실행 id W2) ·
# 본류 끝 문장들(AST 로 잘라 점소싱 - 순서·조건식이 소스 그대로) · 저장소 작성자 표지(워커 원문 "worker:$PID" 를 이 프로세스에서 평가).
# 완료 기록 if(W3)는 조건식 글자가 아니라 자리로 찾습니다 - 나가기 헬퍼 문장('[void](Invoke-AbyssExitClick -Game $game ') 바로 앞 문장이 기록 함수 호출을
# 품은 if 인 곳(본류 1곳 - 보상·클리어 화면 시작 분기의 헬퍼 앞은 완료 마커 블록). 조건식은 행동 행(결합 1·2·3·7·8 - 클리어 결과 · 커스텀 · 정리 전용)이,
# 본문을 감싸지 않는 것은 결합 7(저장 함수 예외)이 지키고, 글자·본문 모양은 test_abyss_screen_signatures 배선이 고정합니다(단계 2.10 구현 검증 - 조건·본문
# 변이가 행 단언이 아니라 하니스 추출 중단으로만 잡히던 것을 행으로). 잘라 쓰는 모양 셋: [완료 기록 if → 나가기 헬퍼](결합 1~4·8) / [완료 마커 if → 완료 기록 if →
# 나가기 헬퍼](결합 6 - 마커 쓰기를 실제로) / 꼬리 전체 [완료 기록 if → … → 본류 try 끝](결합 7 - 종료 문 exit 는 가로채는 함수로 바꾼 사본)
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$workerParseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$workerParseErrors)
if ($workerParseErrors.Count -gt 0) { throw ('워커 파서 오류: ' + $workerParseErrors[0].Message) }
foreach ($workerFunctionName in @('Write-CustomClearMarker', 'ConvertTo-AbyssJournalOwner', 'Add-AbyssJournalClearedEntry')) {
    $workerFunctionAsts = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($_.Name -eq $workerFunctionName) })
    if ($workerFunctionAsts.Count -ne 1) { throw ('워커 최상위 함수 정의가 1개가 아닙니다: {0} ({1}개)' -f $workerFunctionName, $workerFunctionAsts.Count) }
    Invoke-Expression $workerFunctionAsts[0].Extent.Text
}
$workerHelperStatements = @($workerAst.FindAll({ param($node)
            ($node -is [System.Management.Automation.Language.PipelineAst]) -and ($node.Parent -is [System.Management.Automation.Language.StatementBlockAst]) -and
            $node.Extent.Text.StartsWith('[void](Invoke-AbyssExitClick -Game $game ') }, $true))
$workerRecordIfs = @()
foreach ($helperStatement in $workerHelperStatements) {
    $helperSiblings = @($helperStatement.Parent.Statements)
    for ($siblingIndex = 1; $siblingIndex -lt $helperSiblings.Count; $siblingIndex++) {
        if (-not [object]::ReferenceEquals($helperSiblings[$siblingIndex], $helperStatement)) { continue }
        $helperPrevious = $helperSiblings[$siblingIndex - 1]
        if (($helperPrevious -is [System.Management.Automation.Language.IfStatementAst]) -and
            (@($helperPrevious.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Add-AbyssJournalClearedEntry') }, $true)).Count -gt 0)) {
            $workerRecordIfs += $helperPrevious
        }
    }
}
if ($workerRecordIfs.Count -ne 1) { throw ('나가기 헬퍼 바로 앞의 완료 기록 if(기록 함수 호출을 품음)가 {0}개입니다(본류 1개여야 함)' -f $workerRecordIfs.Count) }
$workerRecordSiblings = @($workerRecordIfs[0].Parent.Statements)
$workerRecordAt = -1
for ($siblingIndex = 0; $siblingIndex -lt $workerRecordSiblings.Count; $siblingIndex++) {
    if ([object]::ReferenceEquals($workerRecordSiblings[$siblingIndex], $workerRecordIfs[0])) { $workerRecordAt = $siblingIndex }
}
if (($workerRecordAt -lt 0) -or ($workerRecordAt + 1 -ge $workerRecordSiblings.Count) -or (-not $workerRecordSiblings[$workerRecordAt + 1].Extent.Text.StartsWith('[void](Invoke-AbyssExitClick '))) {
    throw '워커 본류의 완료 기록 if 바로 다음 문장이 나가기 헬퍼가 아닙니다'
}
if (($workerRecordAt -lt 1) -or (-not $workerRecordSiblings[$workerRecordAt - 1].Extent.Text.Contains('Write-CustomClearMarker'))) {
    throw '워커 본류의 완료 기록 if 바로 앞 문장이 완료 마커 블록이 아닙니다'
}
$workerTailBlock = [scriptblock]::Create($workerRecordIfs[0].Extent.Text + "`r`n" + $workerRecordSiblings[$workerRecordAt + 1].Extent.Text)
$workerMarkerTailBlock = [scriptblock]::Create(($workerRecordSiblings[$workerRecordAt - 1].Extent.Text, $workerRecordIfs[0].Extent.Text, $workerRecordSiblings[$workerRecordAt + 1].Extent.Text) -join "`r`n")
# 꼬리 전체 사본 - exit 토큰을 뒤에서부터 가로채는 함수 이름으로 바꿉니다(워커를 끝내는 대신 종료 코드를 실은 예외로 행에 돌아옴)
$WORKER_EXIT_PREFIX = 'WORKER-EXIT:'
$workerFullTailText = (@($workerRecordSiblings[$workerRecordAt..($workerRecordSiblings.Count - 1)] | ForEach-Object { $_.Extent.Text }) -join "`r`n")
$fullTailTokens = $null
$fullTailErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($workerFullTailText, [ref]$fullTailTokens, [ref]$fullTailErrors)
if (@($fullTailErrors).Count -gt 0) { throw ('워커 본류 꼬리 사본 파서 오류: ' + $fullTailErrors[0].Message) }
foreach ($exitToken in @($fullTailTokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Exit } | Sort-Object { $_.Extent.StartOffset } -Descending)) {
    $workerFullTailText = $workerFullTailText.Substring(0, $exitToken.Extent.StartOffset) + 'Stop-WorkerTailExit' + $workerFullTailText.Substring($exitToken.Extent.EndOffset)
}
$workerFullTailBlock = [scriptblock]::Create($workerFullTailText)
$workerRunIdAssigns = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssRunId') })
if ($workerRunIdAssigns.Count -ne 1) { throw ('워커의 실행 id 읽기($script:abyssRunId) 스크립트 수준 대입이 {0}개입니다(1개여야 함)' -f $workerRunIdAssigns.Count) }
$workerRunIdBlock = [scriptblock]::Create($workerRunIdAssigns[0].Extent.Text)
$workerOwnerAssigns = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$script:customOwnerJson') -and $node.Right.Extent.Text.Contains('HONEYNOGI_CUSTOM_OWNER') }, $true))
if ($workerOwnerAssigns.Count -ne 1) { throw ('워커의 소유자 JSON 읽기 대입이 {0}개입니다(1개여야 함)' -f $workerOwnerAssigns.Count) }
$workerOwnerBlock = [scriptblock]::Create($workerOwnerAssigns[0].Extent.Text)
$workerMarkerPathAssigns = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$script:customMarkerPath') -and $node.Right.Extent.Text.Contains('HONEYNOGI_CUSTOM_MARKER') }, $true))
if ($workerMarkerPathAssigns.Count -ne 1) { throw ('워커의 완료 마커 경로 읽기 대입이 {0}개입니다(1개여야 함)' -f $workerMarkerPathAssigns.Count) }
$workerMarkerPathBlock = [scriptblock]::Create($workerMarkerPathAssigns[0].Extent.Text)
$workerSavedByAssigns = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq '$script:abyssJournalSavedBy') })
if ($workerSavedByAssigns.Count -ne 1) { throw ('워커의 작성자 표지 스크립트 수준 대입이 {0}개입니다(1개여야 함)' -f $workerSavedByAssigns.Count) }
$WORKER_SAVED_BY = [string](Invoke-Expression $workerSavedByAssigns[0].Right.Extent.Text)

# ===== GUI 의존 모형 =====
$script:events = New-Object System.Collections.Generic.List[string]
# 기동마다 찍은 env (ArrayList - PS 5.1 에서 List[object] 를 @() 로 감싸면 비어 있든 아니든 '인수 형식이 일치하지 않습니다' 예외, 실행 확인)
$script:launches = New-Object System.Collections.ArrayList
function Add-ColoredLogLine {
    # 로그창 한 줄(실제 서명 param([string]$Text)) - 찍힌 순서대로 'line|<줄>'
    param([string]$Text)
    $script:events.Add('line|' + $Text)
}
function Add-GuiLog {
    # GUI 자기 줄(실제 서명 param([string]$Message) - 실제는 시각을 붙여 Add-ColoredLogLine 으로 보냄) - 'gui|<메시지>'.
    # 예외 주입($script:guiLogThrowMatch 가 메시지에 들어 있으면 줄을 남긴 뒤 던짐): 재입장 실행부가 기동 계획을 정한 뒤(마무리 실행 안내 줄)의
    # 예외에서 catch 의 return 이 기동을 막는지 보는 H12 (바) 전용 - 계획 앞 예외는 계획이 비어 return 이 없어도 기동하지 않아 못 가립니다
    param([string]$Message)
    $script:events.Add('gui|' + $Message)
    if ($script:guiLogThrowMatch -and $Message.Contains($script:guiLogThrowMatch)) { throw $INJECTED_GUILOG_EXCEPTION }
}
function Stop-AllRun {
    # 정지(실제 서명 param([string]$Reason, [switch]$IsError)) - 'stop|<사유>|<오류 여부>'. 실제처럼 실행 상태를 끕니다
    param([string]$Reason, [switch]$IsError)
    $script:events.Add(('stop|{0}|{1}' -f $Reason, [bool]$IsError))
    $script:running = $false
}
function Invoke-NextCycleDecision {
    # 비커스텀 다음 회차 판단(실제 서명 param([int]$ExitCode)) - 'decision|<코드>' (판단 자체는 test_time_until_mode T4-f 가 지킴).
    # $script:decisionMode: 'record' = 기록만 / 'start' = 이어서 실제 Start-NextCycle(다음 기동의 후보 고르기를 보는 G 행) / 'real' = 실제 판단으로
    param([int]$ExitCode)
    $script:events.Add('decision|' + $ExitCode)
    if ($script:decisionMode -eq 'start') { Start-NextCycle }
    elseif ($script:decisionMode -eq 'real') { Invoke-RealNextCycleDecision -ExitCode $ExitCode }
}
function Step-CustomProgress {
    # 진행 전진(실제 서명 param([string]$SectionName = $script:customConfigSection)) - 디스크 컨텍스트 모형을 한 칸(바퀴 끝이면 다음 바퀴 0번)
    # 옮기고 실제처럼 전진 뒤 진행 @{ lap; index } 를 돌려줍니다. 실패 주입($script:stepFailures 가 남음)·디스크 컨텍스트 없음 = $null(저장 실패)
    param([string]$SectionName = $script:customConfigSection)
    $script:stepCalls++
    $script:events.Add('step')
    $nowContext = $script:diskContext
    if (($script:stepFailures -gt 0) -or ($null -eq $nowContext)) {
        if ($script:stepFailures -gt 0) { $script:stepFailures-- }
        return $null
    }
    $nextIndex = [int]$nowContext.Index + 1
    $nextLap = [int]$nowContext.Lap
    if ($nextIndex -ge [int]$nowContext.Total) { $nextIndex = 0; $nextLap++ }
    $script:diskContext = New-AbyssContext -Index $nextIndex -Lap $nextLap -Generation ([int]$nowContext.Generation) `
        -ListRepeat ([string]$nowContext.ListRepeat) -ListRepeatCount ([int]$nowContext.ListRepeatCount)
    return [pscustomobject]@{ lap = $nextLap; index = $nextIndex }
}
function Reset-CustomProgress {
    # 진행 초기화(실제 서명 param([string]$LogMessage = '', [string]$SectionName = $script:customConfigSection)) - 사건 'reset' · 주입한 결과.
    # 예외 주입($script:resetThrows): 마무리 실행 완주 처리 안에서 예외가 난 상황(H30′ - 완주 함수의 catch 가 정지까지 하는지)
    param([string]$LogMessage = '', [string]$SectionName = $script:customConfigSection)
    $script:events.Add('reset')
    if ($script:resetThrows) { throw $INJECTED_RESET_EXCEPTION }
    return [bool]$script:resetResult
}
function Get-CustomCurrentContext {
    # 디스크 진행 컨텍스트(실제 서명 param([string]$SectionName = $script:customConfigSection)) - 부른 횟수를 셉니다(마무리 실행은 0 이어야 함).
    # 일시 읽기 실패 주입($script:contextNullReads 가 남으면 앞에서부터 그 횟수만큼 $null - 설정 파일 일시 공유 위반): 코드 4 진입 컨텍스트 $null 행(명세
    # 5절 B13)이 '한 번 못 읽으면 그 처리 안에서 다시 읽지 않음' 을 봅니다 - 다시 읽으면 두 번째부터는 진행이 읽혀 기록 규칙이 돕니다
    param([string]$SectionName = $script:customConfigSection)
    $script:contextReads++
    if ([int]$script:contextNullReads -gt 0) {
        $script:contextNullReads--
        return $null
    }
    return $script:diskContext
}
function Clear-CustomMarkerFile {
    # 마커 정리(실제 서명 param([string]$Path)) - 부른 횟수만 셉니다(마커 파일은 건드리지 않음 - 마커 그대로 단언과 함께 봄)
    param([string]$Path)
    $script:markerClears++
    return $true
}
$script:staleConfig = $null
function Read-Config {
    # 설정 읽기(실제 서명: 매개변수 없음 - 파일을 못 읽으면 $null) - 단계 2.9 stale 정리 행이 정한 설정 객체($script:staleConfig, $null = 읽기 실패)를 돌려줍니다
    return $script:staleConfig
}
function Set-CustomListRandomView {
    # 실행 중 목록 표시(실제 서명 param($Context)) - 화면 전용이라 횟수만
    param($Context)
    $script:randomViews++
}
function Move-WorkerLogToArchive {
    # 지난 회차 로그 보관(실제 서명 param([string]$Path, [string]$Suffix = '')) - 보관 없이 오프셋 0
    param([string]$Path, [string]$Suffix = '')
    return [long]0
}
# 워커 쪽 모의(단계 2.10 결합 행 - 워커 실제 서명과 대조): 워커 로그는 줄을 모으고, 나가기 헬퍼는 부른 횟수만(완료 기록이 실패해도 본류가 다음
# 문장인 헬퍼로 진행하는지)
$script:workerRunLogLines = New-Object System.Collections.Generic.List[string]
function Write-RunLog {
    # 워커 로그(워커 실제 서명 param([string]$Message))
    param([string]$Message)
    $script:workerRunLogLines.Add($Message)
}
$script:exitClickCalls = 0
function Invoke-AbyssExitClick {
    # 보상 화면 '나가기' 헬퍼(워커 실제 서명) - 횟수만 세고 'gone'
    param([System.Diagnostics.Process]$Game, [string]$LogPrefix = '[어비스]', [string]$Context = '나가기 클릭', $ParentDeadline = $null)
    $script:exitClickCalls++
    return 'gone'
}
$script:returnSelectionCodes = New-Object System.Collections.Generic.List[string]
function Return-ToAbyssSelection {
    # 선택 화면 복귀 루프(워커 실제 서명) - 넘겨받은 안전 중지 종료 코드만 적습니다(결합 7: 완료 기록 저장이 실패해도 본류가 같은 코드로 복귀하는지)
    param([System.Diagnostics.Process]$Game, [int]$SafeStopExitCode = 0)
    $script:returnSelectionCodes.Add([string]$SafeStopExitCode)
}
function Stop-WorkerTailExit {
    # 꼬리 사본의 exit 자리(결합 7) - 워커를 끝내는 대신 종료 코드를 실은 예외로 행에 돌려줍니다
    param([int]$Code = 0)
    throw ($WORKER_EXIT_PREFIX + $Code)
}
function Get-HandoffEnvSnapshot {
    # 이 프로세스의 관련 env 전부 → 해시테이블 (없음 = 빈 문자열)
    $snapshot = @{}
    foreach ($envName in $ALL_ENV_NAMES) { $snapshot[$envName] = [string][Environment]::GetEnvironmentVariable($envName, 'Process') }
    return $snapshot
}
$script:startProcessFailure = ''   # 워커 기동 실패 주입: '' = 성공 / 'throw' = 예외(실제 기동의 catch 경로) / 'null' = 프로세스 없음
function Start-Process {
    # 워커 기동 모의 - PS 5.1 은 같은 이름의 함수를 cmdlet 보다 먼저 부릅니다. 기동 순간의 env 를 찍고 끝나지 않은 프로세스 모형을 돌려줍니다.
    # 실패 주입이면 기동 기록 없이 'launch-throw|' / 'launch-null|' 사건만 남기고 예외를 던지거나 $null 을 돌려줍니다
    param([string]$FilePath, $ArgumentList, [string]$WindowStyle, [switch]$PassThru)
    if ($script:startProcessFailure -eq 'throw') {
        $script:events.Add('launch-throw|' + $FilePath)
        throw $INJECTED_START_EXCEPTION
    }
    if ($script:startProcessFailure -eq 'null') {
        $script:events.Add('launch-null|' + $FilePath)
        return $null
    }
    [void]$script:launches.Add((Get-HandoffEnvSnapshot))
    $script:events.Add('launch|' + $FilePath)
    return [pscustomobject]@{ Id = 4242; HasExited = $false }
}
$lblStatus = [pscustomobject]@{ Text = ''; ForeColor = $null }
$txtLog = [pscustomobject]@{ TextLength = 0; Text = '' }   # 통상 tail 끝의 로그창 길이 검사만 읽음
# 콘텐츠 라디오 - 전투 라디오 3그룹(콘텐츠·어비스 모드·어비스 매칭)을 그룹마다 하나만 켭니다(test_time_until_mode Set-RadioModel 과 같은 모양).
# 틱이 예외를 내면 타이머 catch 의 '[오류] 내부 타이머 …' 줄이 사건 열에 끼어 행마다의 사건 열 대조가 실패합니다(모형이 모자라도 조용히 지나가지 않음)
$rbCatAbyss = [pscustomobject]@{ Checked = $false }
$rbCatDungeon = [pscustomobject]@{ Checked = $true }
$rbCatDeep = [pscustomobject]@{ Checked = $false }          # 코드 4 상태줄 폴백 문구(은동전/마족공물)가 읽음
$rbCatHunting = [pscustomobject]@{ Checked = $false }
$rbModeSolo = [pscustomobject]@{ Checked = $true }
$rbModeParty = [pscustomobject]@{ Checked = $false }
$rbAbyssChance = [pscustomobject]@{ Checked = $true }
$rbAbyssFindParty = [pscustomobject]@{ Checked = $false }
$rbAbyssPartyLead = [pscustomobject]@{ Checked = $false }
$rbAbyssPartyMember = [pscustomobject]@{ Checked = $false }
function Set-RadioModel {
    param(
        [ValidateSet('abyss', 'dungeon', 'deep', 'hunting')][string]$Content,
        [ValidateSet('solo', 'party')][string]$Mode = 'solo',
        [ValidateSet('chance', 'find', 'lead', 'member')][string]$Matching = 'chance'
    )
    $rbCatAbyss.Checked = ($Content -eq 'abyss')
    $rbCatDungeon.Checked = ($Content -eq 'dungeon')
    $rbCatDeep.Checked = ($Content -eq 'deep')
    $rbCatHunting.Checked = ($Content -eq 'hunting')
    $rbModeSolo.Checked = ($Mode -eq 'solo')
    $rbModeParty.Checked = ($Mode -eq 'party')
    $rbAbyssChance.Checked = ($Matching -eq 'chance')
    $rbAbyssFindParty.Checked = ($Matching -eq 'find')
    $rbAbyssPartyLead.Checked = ($Matching -eq 'lead')
    $rbAbyssPartyMember.Checked = ($Matching -eq 'member')
}
$workerScript = 'C:\honeynogi-test\mabinogi_run_once.ps1'   # 기동 인자로만 쓰임 (Start-Process 모의)
$appVersion = 'v-test'
$script:hostedExePath = ''                                  # powershell.exe 기동 갈래
$script:heldStreams = New-Object System.Collections.Generic.List[System.IDisposable]
$testRootFolder = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_handoff_gui_' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRootFolder)
# 이 파일이 바꾸는 env 의 원래 값 (끝에서 되돌림)
$originalEnv = Get-HandoffEnvSnapshot

function Get-ParamSignature {
    # 함수 정의의 매개변수 서명 '타입 $이름, …' - 모의와 실제를 같은 방식으로 뽑아 비교합니다 (test_time_until_mode 와 같은 구현)
    param($Ast, [string]$Name)
    $functionAst = @($Ast.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $Name) }, $true)) | Select-Object -First 1
    if ($null -eq $functionAst) { return '(정의 없음)' }
    $paramBlock = $functionAst.Body.ParamBlock
    if ($null -eq $paramBlock) { return '(매개변수 없음)' }
    return (@($paramBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}

function Assert-Case {
    param([string]$Name, $Actual, $Expect)
    if ("$Actual" -ceq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
    else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Write-NewLogFile {
    # 워커가 회차 시작에 새로 만든 로그처럼 UTF-8 BOM + 줄마다 CRLF
    param([string]$Path, [string[]]$Lines)
    [IO.File]::WriteAllText($Path, (@($Lines | ForEach-Object { $_ + "`r`n" }) -join ''), $UTF8_BOM)
}

function Add-LogFileLines {
    # 워커가 이어 쓰는 줄 (파일이 없으면 BOM 없이 새로 생김)
    param([string]$Path, [string[]]$Lines)
    [IO.File]::AppendAllText($Path, (@($Lines | ForEach-Object { $_ + "`r`n" }) -join ''), $UTF8_NO_BOM)
}

function Unlock-LogFiles {
    foreach ($heldStream in $script:heldStreams) { $heldStream.Dispose() }
    $script:heldStreams.Clear()
}

function Invoke-ExitInjection {
    # 모의 워커의 HasExited 를 처음 읽는 순간(= 그 틱의 통상 tail 이 끝난 뒤) 실행 - 워커가 마지막 줄을 쓰고 끝난 상황을 만듭니다.
    # 먼저 그 순간의 오프셋(통상 tail 이 읽은 데까지)을 적어 두고, 줄을 덧붙인 뒤 지정한 파일을 FileShare.None 으로 쥡니다
    param([hashtable]$Plan)
    $script:offsetsAtExit = @{ Worker = [long]$script:logOffset; Recovery = [long]$script:recoveryLogOffset }
    if ($null -ne $Plan.WorkerLines) { Add-LogFileLines -Path $script:workerLog -Lines @($Plan.WorkerLines) }
    if ($null -ne $Plan.RecoveryLines) { Add-LogFileLines -Path $script:workerRecoveryLog -Lines @($Plan.RecoveryLines) }
    if ($Plan.LockWorker) {
        $script:heldStreams.Add([IO.File]::Open($script:workerLog, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None))
    }
    if ($Plan.LockRecovery) {
        $script:heldStreams.Add([IO.File]::Open($script:workerRecoveryLog, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None))
    }
}

function New-MockWorker {
    # 끝난 워커 프로세스 모형 - ExitCode · Dispose() · HasExited(처음 읽을 때 주입을 한 번 실행하고 참)
    param([int]$ExitCode, [hashtable]$Plan)
    $worker = New-Object psobject
    $worker | Add-Member -NotePropertyName 'ExitCode' -NotePropertyValue $ExitCode
    $worker | Add-Member -NotePropertyName 'Plan' -NotePropertyValue $Plan
    $worker | Add-Member -NotePropertyName 'ExitReads' -NotePropertyValue 0
    $worker | Add-Member -NotePropertyName 'Disposed' -NotePropertyValue $false
    $worker | Add-Member -MemberType ScriptProperty -Name 'HasExited' -Value {
        $this.ExitReads++
        if ($this.ExitReads -eq 1 -and $null -ne $this.Plan) { $null = Invoke-ExitInjection -Plan $this.Plan }
        $true
    }
    $worker | Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value { $this.Disposed = $true }
    return $worker
}

function Invoke-ExitRow {
    # 한 행 = 새 임시 폴더 · 처음 로그 줄 · 끝난 모의 워커 → 타이머 틱 1번(통상 tail → HasExited 순간 주입 → 종료 처리)
    param(
        [int]$ExitCode,
        [string[]]$WorkerLines = @(),
        $RecoveryLines = $null,          # $null = 복구 로그 파일 없음(평소 모양)
        [hashtable]$Plan = @{},          # WorkerLines·RecoveryLines(종료 직전에 덧붙일 줄) · LockWorker·LockRecovery(읽기 실패 주입)
        [int]$PreparedStreak = 0,
        [int]$CompletedCycles = 0,
        [bool]$CustomActive = $false     # 커스텀 실행 - 커스텀 사슬을 타지 않는 갈래(코드 2·3)에서만 씁니다(C10)
    )
    Unlock-LogFiles
    $script:events.Clear()
    $rowFolder = Join-Path $testRootFolder ([guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($rowFolder)
    $script:workerLog = Join-Path $rowFolder 'mabinogi_run_once.log'
    $script:workerRecoveryLog = Join-Path $rowFolder 'mabinogi_run_once.recovery.log'
    $script:logOffset = [long]0
    $script:recoveryLogOffset = [long]0
    $script:offsetsAtExit = $null
    $script:lastWorkerDoneReason = ''
    $script:running = $true
    $script:mainCategory = 'battle'
    $script:customActive = $CustomActive
    $script:customRecoveryPending = $false
    $script:completedCycles = $CompletedCycles
    $script:preparedStreak = $PreparedStreak
    # 기동 종류는 앞 행이 남긴 값을 쓰지 않습니다(마무리 실행 기동이 남으면 코드 0·11·10 이 완주 처리로 갑니다) · 다음 회차 판단은 기록만
    $script:lastLaunchKind = 'none'
    $script:lastLaunchNonce = ''
    $script:finishOnlyHold = $null
    $script:decisionMode = 'record'
    Set-RadioModel -Content 'dungeon'
    $lblStatus.Text = ''
    $lblStatus.ForeColor = $null
    if ($WorkerLines.Count -gt 0) { Write-NewLogFile -Path $script:workerLog -Lines $WorkerLines }
    if ($null -ne $RecoveryLines) { Write-NewLogFile -Path $script:workerRecoveryLog -Lines @($RecoveryLines) }
    $script:worker = New-MockWorker -ExitCode $ExitCode -Plan $Plan
    try {
        $null = & $timerTick
    } finally {
        Unlock-LogFiles
    }
    $colorName = $(if ($null -eq $lblStatus.ForeColor) { '색 그대로' } else { [string]$lblStatus.ForeColor.Name })
    return [pscustomobject]@{
        Events = @($script:events)
        Reason = [string]$script:lastWorkerDoneReason
        Color = $colorName
        PreparedStreak = $script:preparedStreak
        CompletedCycles = $script:completedCycles
        WorkerOffset = [long]$script:logOffset
        RecoveryOffset = [long]$script:recoveryLogOffset
        OffsetsAtExit = $script:offsetsAtExit
        WorkerLength = $(if ([IO.File]::Exists($script:workerLog)) { (New-Object IO.FileInfo $script:workerLog).Length } else { -1 })
        RecoveryLength = $(if ([IO.File]::Exists($script:workerRecoveryLog)) { (New-Object IO.FileInfo $script:workerRecoveryLog).Length } else { -1 })
    }
}

function Format-Events {
    param([string[]]$Events)
    return (@($Events) -join ' / ')
}

# ===== 기동 하니스 (단계 2.5) =====
function New-AbyssContext {
    # Get-CustomCurrentContext 반환 모양의 어비스 커스텀 컨텍스트 (순차 · 기본 무한 반복 · 목록 = $ABYSS_ITEMS)
    param([int]$Index, [int]$Lap = 1, [int]$Generation = 0, [string]$ListRepeat = 'infinite', [int]$ListRepeatCount = 1)
    return @{
        Items = $ABYSS_ITEMS; ExecutionItems = $ABYSS_ITEMS; Total = $ABYSS_ITEMS.Count; RegisteredTotal = $ABYSS_ITEMS.Count
        Lap = $Lap; Index = $Index; Item = $ABYSS_ITEMS[$Index]; RegisteredIndex = $Index
        RandomOrder = $false; Order = $null; ShuffleValid = $true
        ListRepeat = $ListRepeat; ListRepeatCount = $ListRepeatCount; SectionName = $ABYSS_SECTION
        Position = ('{0}바퀴째 {1}/{2}번' -f $Lap, ($Index + 1), $ABYSS_ITEMS.Count); Generation = $Generation
    }
}

function ConvertTo-FiveFieldOwner {
    # 완료 기록 항목의 owner·nextOwner 모양(5필드 - 진행 세대는 항목의 형제 필드)
    param($Owner)
    return [pscustomobject]@{ fingerprint = [string]$Owner.fingerprint; orderKey = [string]$Owner.orderKey; lap = [int]$Owner.lap; index = [int]$Owner.index; item = [string]$Owner.item }
}

function New-FixtureEntry {
    # 완료 기록 항목 픽스처 - 실제 New-AbyssJournalEntry 기본값 위에 필요한 필드만
    param([string]$Stage, $Owner, $NextOwner = $null, [int]$Generation = 0, [string]$LaunchState = 'pending', [string]$Section = '', [string]$Nonce)
    $entry = New-AbyssJournalEntry -Stage $Stage
    $entry.nonce = $Nonce
    $entry.owner = $Owner
    $entry.nextOwner = $NextOwner
    $entry.generation = $Generation
    $entry.launchState = $LaunchState
    $entry.section = $Section
    $entry.decision = 'exit'
    return $entry
}

function Write-FixtureJournal {
    # 완료 기록 본 파일을 실제 직렬화(ConvertTo-AbyssJournalText)로 씁니다 (UTF-8 BOM - 저장소와 같은 인코딩)
    param([string]$Path, [object[]]$Entries = @(), [object[]]$Applied = @(), [long]$Seq = 5)
    $journal = New-AbyssJournalEmpty
    $journal.seq = $Seq
    $journal.savedAt = '2026-10-09T09:00:00.0000000+09:00'
    $journal.savedBy = 'worker:1234'
    $journal.entries = [object[]]@($Entries)
    $journal.applied = [object[]]@($Applied)
    [IO.File]::WriteAllText($Path, (ConvertTo-AbyssJournalText -Journal $journal), $UTF8_BOM)
}

function Get-FolderState {
    # 폴더의 파일 이름·크기·SHA-256 목록 (파일 변경 0 단언용 - 잠금·임시·손상 증거 파일이 생겨도 드러남)
    param([string]$Folder)
    $lines = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Folder -File | Sort-Object Name)) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $lines += ('{0}:{1}:{2}' -f $file.Name, $file.Length, $hash.Substring(0, 12))
    }
    return ($lines -join ';')
}

function Read-FixtureJournal {
    # 본 파일을 그대로 읽어 객체로 (저장소 판정 없이 - 행 뒤 상태 확인용). 손상 픽스처 행은 $null
    param([string]$Path)
    if (-not [IO.File]::Exists($Path)) { return $null }
    try { return ([IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop) } catch { return $null }
}

function Get-EntryLaunchState {
    param($Journal, [string]$Nonce)
    foreach ($entry in @($Journal.entries)) { if ([string]$entry.nonce -eq $Nonce) { return [string]$entry.launchState } }
    return '(없음)'
}

function Initialize-JournalRow {
    # 기동·후보 행 공통 준비 - 새 임시 폴더(로그·마커·완료 기록 경로), 사건·횟수 초기화
    Unlock-LogFiles
    $script:events.Clear()
    $script:launches.Clear()
    $script:resolveCalls = 0
    $script:contextReads = 0
    $script:contextNullReads = 0
    $script:markerClears = 0
    $script:randomViews = 0
    # 단계 2.6 감시 횟수·주입 (앞 행 값이 새지 않게)
    $script:stepCalls = 0
    $script:journalReads = 0
    $script:journalUpdates = 0
    $script:readThrows = $false
    $script:updateThrowAt = 0
    $script:updateTagAt = $null
    $script:preUpdateHook = $null
    $script:preUpdateAt = 0
    $script:resetThrows = $false
    $script:resolveOverride = $null
    $script:guiLogThrowMatch = ''
    $script:decisionMode = 'record'
    $rowFolder = Join-Path $testRootFolder ([guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($rowFolder)
    $script:rowFolder = $rowFolder
    $script:honeyLogDir = $rowFolder
    $script:workerLog = Join-Path $rowFolder 'mabinogi_run_once.log'
    $script:workerRecoveryLog = Join-Path $rowFolder 'mabinogi_run_once.recovery.log'
    $script:abyssJournalPath = Join-Path $rowFolder 'abyss_handoff.json'
    $script:customMarkerFile = Join-Path $rowFolder 'abyss_custom_done.marker'
}

function Invoke-LaunchRow {
    # 한 기동 행 = 새 임시 폴더 · 실행 상태 · (선택) 완료 기록·마커 픽스처 · (선택) 잠금 주입 → 실제 Start-NextCycle 1번.
    # 기동 전에 handoff env 3개(와 -SeedCustom 이면 커스텀 env)에 $STALE_VALUE 를 넣어 둡니다 - 그대로 남으면 '먼저 비움'·덮어쓰기가 안 된 것
    param(
        [string]$Category = 'battle',
        [string]$Content = 'abyss',
        [string]$Mode = 'solo',
        [string]$Matching = 'chance',
        [bool]$Custom = $false,
        $DiskContext = $null,
        [object[]]$Entries = $null,           # $null = 완료 기록 파일 없음
        [object[]]$Applied = @(),
        [string]$CorruptText = '',            # 본 파일·직전본에 쓸 손상 내용 (빈 값 = 안 씀)
        [string]$MarkerText = '',             # 마커 파일 내용 (빈 값 = 마커 없음)
        [hashtable]$LaunchArgs = @{},         # Start-NextCycle 인자
        [switch]$HoldLock,                    # .lock 을 쥠 → 'locked'
        [switch]$HoldMainRead,                # 본 파일을 FileShare.Read 로 쥠 → 교체(Replace) 실패 → 'io-failed'
        [switch]$SeedCustom,                  # 커스텀 env 에도 묵은 값을 넣어 둠
        [switch]$KeepEnv,                     # env 를 미리 채우지 않음 (앞 행이 남긴 env 를 그대로 - L6)
        [int]$CompletedCycles = 0,
        $TargetTime = $null,
        [string]$RunId = 'run-test',
        [bool]$CustomRestart = $false,
        [bool]$MarkerIgnore = $false,
        [string]$PrevItem = '',
        [string]$StartFailure = ''            # 워커 기동 실패 주입 ('throw' / 'null' - Start-Process 모의)
    )
    Initialize-JournalRow
    $script:startProcessFailure = $StartFailure
    $script:mainCategory = $Category
    Set-RadioModel -Content $Content -Mode $Mode -Matching $Matching
    $script:customActive = $Custom
    $script:customConfigSection = $(if ($Custom) { $ABYSS_SECTION } else { 'customRepeat' })
    $script:diskContext = $DiskContext
    $script:customRestart = $CustomRestart
    $script:customRecoveryPending = $false
    $script:customMarkerIgnore = $MarkerIgnore
    $script:customPrevItem = $PrevItem
    $script:completedCycles = $CompletedCycles
    $script:targetTime = $TargetTime
    $script:targetCycles = 0
    $script:runId = $RunId
    $script:lastWorkerDoneReason = 'stale reason'
    $script:running = $true
    $lblStatus.Text = ''
    $lblStatus.ForeColor = $null
    if (-not $KeepEnv) {
        foreach ($envName in $HANDOFF_ENV_NAMES) { [Environment]::SetEnvironmentVariable($envName, $STALE_VALUE, 'Process') }
        if ($SeedCustom) { foreach ($envName in ($CUSTOM_ENV_NAMES + $NEXT_OWNER_ENV_NAMES)) { [Environment]::SetEnvironmentVariable($envName, $STALE_VALUE, 'Process') } }
    }
    if ($null -ne $Entries) { Write-FixtureJournal -Path $script:abyssJournalPath -Entries $Entries -Applied $Applied }
    if ($CorruptText) {
        [IO.File]::WriteAllText($script:abyssJournalPath, $CorruptText, $UTF8_BOM)
        [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $CorruptText, $UTF8_BOM)
    }
    if ($MarkerText) { [IO.File]::WriteAllText($script:customMarkerFile, $MarkerText, $UTF8_NO_BOM) }
    $stateBefore = Get-FolderState -Folder $script:rowFolder
    $markerBefore = $(if ([IO.File]::Exists($script:customMarkerFile)) { [IO.File]::ReadAllText($script:customMarkerFile) } else { '(없음)' })
    if ($HoldLock) {
        $lockPath = [IO.Path]::ChangeExtension($script:abyssJournalPath, '.lock')
        $script:heldStreams.Add((New-Object IO.FileStream($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)))
    }
    if ($HoldMainRead) {
        $script:heldStreams.Add([IO.File]::Open($script:abyssJournalPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read))
    }
    $thrown = ''
    try {
        Start-NextCycle @LaunchArgs
    } catch {
        $thrown = $_.Exception.Message
    } finally {
        Unlock-LogFiles
        $script:startProcessFailure = ''
    }
    $colorName = $(if ($null -eq $lblStatus.ForeColor) { '색 그대로' } else { [string]$lblStatus.ForeColor.Name })
    return [pscustomobject]@{
        Events = @($script:events)
        Launches = @($script:launches)
        LaunchEnv = $(if ($script:launches.Count -gt 0) { $script:launches[0] } else { @{} })
        EnvAfter = (Get-HandoffEnvSnapshot)
        Thrown = $thrown
        Kind = [string]$script:lastLaunchKind
        Nonce = [string]$script:lastLaunchNonce
        Hold = $script:finishOnlyHold
        ResolveCalls = $script:resolveCalls
        ContextReads = $script:contextReads
        MarkerClears = $script:markerClears
        RandomViews = $script:randomViews
        MarkerIgnore = [bool]$script:customMarkerIgnore
        StatusText = [string]$lblStatus.Text
        Color = $colorName
        StateBefore = $stateBefore
        StateAfter = (Get-FolderState -Folder $script:rowFolder)
        MarkerBefore = $markerBefore
        MarkerAfter = $(if ([IO.File]::Exists($script:customMarkerFile)) { [IO.File]::ReadAllText($script:customMarkerFile) } else { '(없음)' })
        Journal = (Read-FixtureJournal -Path $script:abyssJournalPath)
    }
}

function Format-HandoffEnv {
    # handoff env 3개 'NONCE|RESUME|FINISH_ONLY'
    param([hashtable]$EnvSnapshot)
    return ('{0}|{1}|{2}' -f $EnvSnapshot['HONEYNOGI_HANDOFF_NONCE'], $EnvSnapshot['HONEYNOGI_RESUME_REENTRY'], $EnvSnapshot['HONEYNOGI_FINISH_ONLY'])
}

function Format-EnvValues {
    # 지정한 env 들을 'a|b|c' 로
    param([hashtable]$EnvSnapshot, [string[]]$Names)
    return (@($Names | ForEach-Object { [string]$EnvSnapshot[$_] }) -join '|')
}

function Get-StopEvents {
    param($Row)
    return @($Row.Events | Where-Object { $_.StartsWith('stop|') })
}

function Set-ScriptFunction {
    # 행 하나가 함수를 잠시 바꿔 끼우거나 GUI 원문으로 되돌립니다 - script: 범위로 정의해야 클로저(저장소 mutator)에서도 보입니다
    param([string]$Name, [string]$Text)
    Invoke-Expression ($Text -replace ('^function ' + [regex]::Escape($Name) + '\b'), ('function script:' + $Name))
}

# ===== G 하니스 =====
function Test-CaseHarness {
    Assert-Case 'G1 추출: GUI 함수 정의가 이름마다 1개' ($extractedCounts -join ', ') ((@($GUI_FUNCTION_NAMES | ForEach-Object { '{0}=1' -f $_ })) -join ', ')
    Assert-Case 'G1 추출: 타이머 틱 등록 1개' $tickCalls.Count 1
    $selfAst = [System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$null, [ref]$null)
    foreach ($mockName in $MOCK_FUNCTION_NAMES) {
        Assert-Case "G2 모의 $mockName 서명 = GUI 실제 서명" (Get-ParamSignature $selfAst $mockName) (Get-ParamSignature $guiAst $mockName)
    }
}

# ===== C 공통 최종 수집 - 종료 처리 순서 주입 =====
function Test-CaseCollectOrder {
    # C1 코드 4: 통상 tail 뒤·HasExited 전에 쓰인 [완료] 줄이 상태줄 사유가 됨 (복구 로그 없음 = 경고 0)
    $row = Invoke-ExitRow -ExitCode 4 -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @("12:00:09 [완료] $CODE4_REASON") }
    Assert-Case 'C1 코드 4: tail 줄 → 종료 직전 [완료] 줄 → 그 사유로 정지(상태줄), 경고 0' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + @("line|  12:00:09 [완료] $CODE4_REASON", "stop|조건 정지: $CODE4_REASON|False")))
    Assert-Case 'C1 코드 4: 사유 = 종료 직전 줄 원문 · 상태줄 색 SteelBlue · 모의 워커 정리' ('{0} | {1}' -f $row.Reason, $row.Color) "$CODE4_REASON | SteelBlue"

    # C2 코드 4: 새 줄도 [완료] 사유도 없음 → 범용 폴백 문구, 경고 0 (파일 없음·새 줄 없음은 실패가 아님)
    $row = Invoke-ExitRow -ExitCode 4 -WorkerLines $EARLY_LINES
    Assert-Case 'C2 코드 4: 새 줄 없음 · 복구 로그 없음 → 경고 0 · 범용 폴백 정지' (Format-Events $row.Events) (Format-Events ($EARLY_SHOWN + @($CODE4_FALLBACK_STOP)))

    # C3 코드 10: 거점 퇴장 [완료] 줄을 종료 직전에 씀 → 갈래 판별이 그 줄을 봄 (코드 10 갈래의 잔여 수집 사본을 지운 뒤에도 - dev:989)
    $row = Invoke-ExitRow -ExitCode 10 -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @("12:00:09 [완료] $CHECKPOINT_REASON") } -PreparedStreak 2
    Assert-Case 'C3 코드 10: 종료 직전 거점 퇴장 줄 → 재입장 안내 · 다음 회차 판단(코드 10)' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + @("line|  12:00:09 [완료] $CHECKPOINT_REASON", $CHECKPOINT_NOTICE, 'decision|10')))
    Assert-Case 'C3 코드 10: 준비 실행 연속 수 2 → 0 (거점 퇴장은 상한을 소모하지 않음)' $row.PreparedStreak 0

    # C4 코드 10 대조: 같은 자리의 일반 준비 실행 줄 → 연속 수 +1 · 준비 실행 안내 (판별이 늘 참이 아님)
    $row = Invoke-ExitRow -ExitCode 10 -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @("12:00:09 [완료] $PREPARED_REASON") } -PreparedStreak 1
    Assert-Case 'C4 코드 10 대조: 종료 직전 일반 준비 실행 줄 → 준비 실행 안내 · 연속 수 1 → 2' ('{0} || {1}' -f (Format-Events $row.Events), $row.PreparedStreak) `
        ('{0} || 2' -f (Format-Events ($EARLY_SHOWN + @("line|  12:00:09 [완료] $PREPARED_REASON", $PREPARED_NOTICE, 'decision|10'))))

    # C5 코드 0: 워커의 마지막 줄이 회차 완료 줄보다 먼저 창에 뜸 (시간 지정 v2 R17 - 예전엔 코드 0 은 그 줄을 못 보고 다음 회차가 시작됨)
    $row = Invoke-ExitRow -ExitCode 0 -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @('12:00:09 [완료] 어비스 선택 화면 복귀 완료') }
    Assert-Case 'C5 코드 0: 마지막 줄 → === 1회차 완료 === → 다음 회차 판단(코드 0)' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + @('line|  12:00:09 [완료] 어비스 선택 화면 복귀 완료', 'gui|=== 1회차 완료 ===', 'decision|0')))

    # C6 코드 11: 같은 순서 + 완료 줄 꼬리
    $row = Invoke-ExitRow -ExitCode 11 -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @('12:00:09 [던전] 다시 하기 → 옵션 화면 복귀 - 회차 완료') } -CompletedCycles 2
    Assert-Case 'C6 코드 11: 마지막 줄 → === 3회차 완료 (다음 판으로 이어 감) === → 다음 회차 판단(코드 11)' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + @('line|  12:00:09 [던전] 다시 하기 → 옵션 화면 복귀 - 회차 완료', 'gui|=== 3회차 완료 (다음 판으로 이어 감) ===', 'decision|11')))

    # C7 코드 1·2·3: 마지막 줄이 창에 뜨고 정지 문구·색은 그대로 (사유를 읽지 않는 갈래 - 표시만 늚)
    $codeRows = @(
        @{ Code = 1; Line = '12:00:09 [오류] 던전 클리어 화면 감지 대기 시간이 초과됐습니다.'; Stop = 'stop|오류 종료(코드 1) - 로그 확인|True'; Color = 'Firebrick' }
        @{ Code = 2; Line = '12:00:09 [중단] 이미 다른 자동화 인스턴스가 실행 중이라 이 실행을 취소합니다.'
           Stop = 'stop|다른 자동화 인스턴스가 이미 실행 중 (중복 실행 방지) - 작업 관리자에서 powershell.exe(또는 꿀비노기)를 종료한 뒤 다시 시작해 주세요|True'; Color = 'Firebrick' }
        @{ Code = 3; Line = '12:00:09 [안내] 정박지 은(는) 상세 화면 진입까지만 구현되어 있습니다. 이후 자동화는 미개발이라 여기서 종료합니다.'
           Stop = 'stop|구현된 구간까지 완료 - 정지 (자세한 내용은 로그 참고)|False'; Color = 'SteelBlue' }
    )
    foreach ($codeRow in $codeRows) {
        $row = Invoke-ExitRow -ExitCode $codeRow.Code -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @($codeRow.Line) }
        Assert-Case ('C7 코드 {0}: 마지막 줄 표시 뒤 정지 문구·색 그대로' -f $codeRow.Code) ('{0} || {1}' -f (Format-Events $row.Events), $row.Color) `
            ('{0} || {1}' -f (Format-Events ($EARLY_SHOWN + @("line|  $($codeRow.Line)", $codeRow.Stop))), $codeRow.Color)
    }

    # C8 복구 로그 변형(코드 4): 워커가 복구 로그로 넘어가 마지막 줄을 거기에만 씀 → 두 로그 모두 수집 (dev:989 '복구 로그에만 줄이 쓰인 변형')
    $row = Invoke-ExitRow -ExitCode 4 -WorkerLines $EARLY_LINES -Plan @{ RecoveryLines = ($RECOVERY_HEAD + @("12:00:09 [완료] $OVERLAY_REASON")) }
    Assert-Case 'C8 복구 로그 변형(코드 4): 복구 로그의 전환 경고·[완료] 줄 → 그 사유로 정지 (머리글은 숨김)' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + $RECOVERY_HEAD_SHOWN + @("line|  12:00:09 [완료] $OVERLAY_REASON", "stop|조건 정지: $OVERLAY_REASON|False")))

    # C9 복구 로그 변형(코드 10): 거점 퇴장 줄이 복구 로그에만 → 같은 판별
    $row = Invoke-ExitRow -ExitCode 10 -WorkerLines $EARLY_LINES -Plan @{ RecoveryLines = ($RECOVERY_HEAD + @("12:00:09 [완료] $CHECKPOINT_REASON")) } -PreparedStreak 2
    Assert-Case 'C9 복구 로그 변형(코드 10): 복구 로그의 거점 퇴장 줄 → 재입장 안내 · 연속 수 0' ('{0} || {1}' -f (Format-Events $row.Events), $row.PreparedStreak) `
        ('{0} || 0' -f (Format-Events ($EARLY_SHOWN + $RECOVERY_HEAD_SHOWN + @("line|  12:00:09 [완료] $CHECKPOINT_REASON", $CHECKPOINT_NOTICE, 'decision|10'))))

    # C10 커스텀 실행: 종료 직전에 쓰인 커스텀 숨김 줄(회차 완료 줄 - 커스텀은 GUI 가 항목 완료 줄로 대신 알림)을 최종 수집도 통상 tail 처럼
    #     창에 띄우지 않음 = 최종 수집이 커스텀 여부를 그대로 넘김. 코드 3 은 커스텀 사슬을 타지 않는 갈래라 숨김만 봅니다. 대조: 비커스텀이면 뜸
    #     (변이 검증 보강 2026-10-09 - 숨김 행이 전부 비커스텀이라 최종 수집의 '-CustomActive $false' 변이가 살아남았음)
    $customHiddenLine = '12:00:09 [던전] 다시 하기 → 옵션 화면 복귀 - 회차 완료'
    $code3Stop = 'stop|구현된 구간까지 완료 - 정지 (자세한 내용은 로그 참고)|False'
    $customRow = Invoke-ExitRow -ExitCode 3 -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @($customHiddenLine) } -CustomActive $true
    $plainRow = Invoke-ExitRow -ExitCode 3 -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @($customHiddenLine) }
    Assert-Case 'C10 커스텀 실행 코드 3: 종료 직전 커스텀 숨김 줄 → 창에 안 뜸 || 비커스텀 대조 → 뜸' `
        ('{0} || {1}' -f (Format-Events $customRow.Events), (Format-Events $plainRow.Events)) `
        ('{0} || {1}' -f (Format-Events ($EARLY_SHOWN + @($code3Stop))), (Format-Events ($EARLY_SHOWN + @("line|  $customHiddenLine", $code3Stop))))
}

# ===== F 출처별 실패 - 최종 수집 실패 4경우 (가)~(라) (코드 4) =====
function Test-CaseSourceFailure {
    $overlayLine = "12:00:05 [완료] $OVERLAY_REASON"
    $lateOverlayLine = "12:00:09 [완료] $OVERLAY_REASON"

    # (가) 통상 tail 이 표지 사유를 잡은 뒤 두 출처 모두 읽기 실패 → 사유 보존 · 경고 2(워커 로그 → 복구 로그 순)
    $row = Invoke-ExitRow -ExitCode 4 -WorkerLines ($EARLY_LINES + @($overlayLine)) -RecoveryLines $RECOVERY_HEAD -Plan @{ LockWorker = $true; LockRecovery = $true }
    Assert-Case '(가) 두 출처 실패 + tail 이 잡은 표지 사유: 경고 2(출처별) · 사유 보존 정지' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + @("line|  $overlayLine") + $RECOVERY_HEAD_SHOWN + @("gui|$WARN_WORKER", "gui|$WARN_RECOVERY", "stop|조건 정지: $OVERLAY_REASON|False")))
    Assert-Case '(가) 사유 원문 보존 · 두 출처 오프셋 그대로(줄을 버리지 않음)' ('{0} | {1}/{2}' -f $row.Reason, [int]($row.WorkerOffset -eq $row.OffsetsAtExit.Worker), [int]($row.RecoveryOffset -eq $row.OffsetsAtExit.Recovery)) "$OVERLAY_REASON | 1/1"

    # (나) 워커 로그에 종료 직전 표지 줄 성공 + 복구 로그 실패 → 표지 채택 · 경고 1(복구 로그)
    $row = Invoke-ExitRow -ExitCode 4 -WorkerLines $EARLY_LINES -RecoveryLines $RECOVERY_HEAD -Plan @{ WorkerLines = @($lateOverlayLine); LockRecovery = $true }
    Assert-Case '(나) 워커 로그 성공 + 복구 로그 실패: 표지 줄 → 경고 1(복구 로그) → 표지 사유로 정지' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + $RECOVERY_HEAD_SHOWN + @("line|  $lateOverlayLine", "gui|$WARN_RECOVERY", "stop|조건 정지: $OVERLAY_REASON|False")))
    Assert-Case '(나) 워커 로그는 끝까지 읽음 · 복구 로그 오프셋 그대로' ('{0}/{1}' -f [int]($row.WorkerOffset -eq $row.WorkerLength), [int]($row.RecoveryOffset -eq $row.OffsetsAtExit.Recovery)) '1/1'

    # (다) 워커 로그 실패 + 복구 로그에 종료 직전 표지 줄 성공 → 표지 채택 · 경고 1(워커 로그) - 한 출처 실패가 다른 출처를 건너뛰지 않음
    $row = Invoke-ExitRow -ExitCode 4 -WorkerLines $EARLY_LINES -RecoveryLines $RECOVERY_HEAD -Plan @{ RecoveryLines = @($lateOverlayLine); LockWorker = $true }
    Assert-Case '(다) 워커 로그 실패 + 복구 로그 성공: 경고 1(워커 로그) → 복구 로그 표지 줄 → 표지 사유로 정지' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + $RECOVERY_HEAD_SHOWN + @("gui|$WARN_WORKER", "line|  $lateOverlayLine", "stop|조건 정지: $OVERLAY_REASON|False")))
    Assert-Case '(다) 워커 로그 오프셋 그대로 · 복구 로그는 끝까지 읽음' ('{0}/{1}' -f [int]($row.WorkerOffset -eq $row.OffsetsAtExit.Worker), [int]($row.RecoveryOffset -eq $row.RecoveryLength)) '1/1'

    # (라) 두 출처 실패 + 잡은 사유 없음 → 기본값(사유 없음 = 범용 폴백) 그대로 · 경고 2 - 기본값은 '사유 없음' 에만 적용
    $row = Invoke-ExitRow -ExitCode 4 -WorkerLines $EARLY_LINES -RecoveryLines $RECOVERY_HEAD -Plan @{ LockWorker = $true; LockRecovery = $true }
    Assert-Case '(라) 두 출처 실패 + 사유 없음: 경고 2 → 범용 폴백 정지 · 사유 빈 값' ('{0} || [{1}]' -f (Format-Events $row.Events), $row.Reason) `
        ('{0} || []' -f (Format-Events ($EARLY_SHOWN + $RECOVERY_HEAD_SHOWN + @("gui|$WARN_WORKER", "gui|$WARN_RECOVERY", $CODE4_FALLBACK_STOP))))
}

# ===== H InsideHandoff 꼬리 숨김 (Q9) - 통상 tail · 최종 수집 두 경로 (코드 0) =====
function Test-CaseHandoffTail {
    $tailLower = " [terminal=InsideHandoff nonce=$IH_NONCE_LOWER]"
    $tailUpper = " [terminal=InsideHandoff nonce=$IH_NONCE_UPPER]"
    $ihBodyReason = $IH_BODY.Substring('[완료] '.Length)

    # H1 통상 tail 경로: 꼬리 붙은 완료 줄이 HasExited 전에 이미 쓰여 있음
    $row = Invoke-ExitRow -ExitCode 0 -WorkerLines ($EARLY_LINES + @("12:00:05 $IH_BODY$tailLower"))
    Assert-Case 'H1 통상 tail: 화면 줄 꼬리 0·본문 그대로 → 회차 완료 줄' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + @("line|  12:00:05 $IH_BODY", 'gui|=== 1회차 완료 ===', 'decision|0')))
    Assert-Case 'H1 통상 tail: [완료] 사유에는 꼬리가 남음 (판별은 원문)' $row.Reason "$ihBodyReason$tailLower"

    # H2 최종 수집 경로: 꼬리 붙은 완료 줄을 종료 직전에 씀 (nonce 대문자 - GUID 글자 범위)
    $row = Invoke-ExitRow -ExitCode 0 -WorkerLines $EARLY_LINES -Plan @{ WorkerLines = @("12:00:09 $IH_BODY$tailUpper") }
    Assert-Case 'H2 최종 수집: 화면 줄 꼬리 0·본문 그대로 → 회차 완료 줄' (Format-Events $row.Events) `
        (Format-Events ($EARLY_SHOWN + @("line|  12:00:09 $IH_BODY", 'gui|=== 1회차 완료 ===', 'decision|0')))
    Assert-Case 'H2 최종 수집: [완료] 사유에는 꼬리가 남음 (판별은 원문)' $row.Reason "$ihBodyReason$tailUpper"
}

# ===== L 기동 - 범위 술어 · 읽기 실패 정지 (설계 R1 5.4 L1~L3 · 3.8 ①⑤) =====
function Test-CaseLaunchRange {
    # L1 범위 밖 6실행 + 완료 기록 손상(본 파일·직전본) → journal 접근 0 · 손상이어도 기동 · handoff env 빈 값 · 기동 종류 none (변이 R1-M19)
    $rangeRows = @(
        @{ N = '던전'; Category = 'battle'; Content = 'dungeon'; Mode = 'solo'; Matching = 'chance' }
        @{ N = '심층'; Category = 'battle'; Content = 'deep'; Mode = 'solo'; Matching = 'chance' }
        @{ N = '사냥터'; Category = 'battle'; Content = 'hunting'; Mode = 'solo'; Matching = 'chance' }
        @{ N = '생활(어비스 라디오 보존)'; Category = 'life'; Content = 'abyss'; Mode = 'solo'; Matching = 'chance' }
        @{ N = '기타(어비스 라디오 보존)'; Category = 'etc'; Content = 'abyss'; Mode = 'solo'; Matching = 'chance' }
        @{ N = '어비스 파티원'; Category = 'battle'; Content = 'abyss'; Mode = 'party'; Matching = 'member' }
    )
    foreach ($rangeRow in $rangeRows) {
        $row = Invoke-LaunchRow -Category $rangeRow.Category -Content $rangeRow.Content -Mode $rangeRow.Mode -Matching $rangeRow.Matching -CorruptText '{ "version": 1, "seq": '
        Assert-Case ('L1 {0} + 완료 기록 손상: Resolve 0 · 기동 1 · 정지 0 · handoff env 빈 값 · 종류 none · 파일 그대로' -f $rangeRow.N) `
            ('{0} · {1} · {2} · [{3}] · {4}/{5} · {6}' -f $row.ResolveCalls, $row.Launches.Count, (Get-StopEvents $row).Count, (Format-HandoffEnv $row.LaunchEnv), $row.Kind, $row.Nonce, [int]($row.StateBefore -ceq $row.StateAfter)) `
            '0 · 1 · 0 · [||] · none/ · 1'
    }

    # L2 어비스 비커스텀 + 'locked'(.lock 을 쥠) → 기동 0 · 오류 정지 1 · 꼬리 없음 · 빨강 · 파일 그대로
    $row = Invoke-LaunchRow -Entries @() -HoldLock
    Assert-Case "L2 어비스 비커스텀 + 'locked': 기동 0 · 정지 = 사용 중 문구(꼬리 없음)·오류 · 빨강 · 파일 그대로" `
        ('{0} · {1} · {2} · {3}' -f $row.Launches.Count, (Format-Events (Get-StopEvents $row)), $row.Color, [int]($row.StateBefore -ceq $row.StateAfter)) `
        ('0 · stop|{0}|True · Firebrick · 1' -f $STOP_LOCKED)

    # L3 재입장 실행부가 부른 기동(-FromInsideHandoff) + 'corrupt' → 기동 0 · 손상 문구 + 파일 위치 안내(명세 5절 C11) + 3.5 꼬리(끝)
    $row = Invoke-LaunchRow -CorruptText 'not json' -LaunchArgs @{ FromInsideHandoff = $true }
    Assert-Case "L3 -FromInsideHandoff + 'corrupt': 기동 0 · 정지 = 손상 문구 + 파일 위치 안내 + 재입장 꼬리 · 빨강 · 파일 그대로(손상 증거 이동 0)" `
        ('{0} · {1} · {2} · {3}' -f $row.Launches.Count, (Format-Events (Get-StopEvents $row)), $row.Color, [int]($row.StateBefore -ceq $row.StateAfter)) `
        ('0 · stop|{0}{1}|True · Firebrick · 1' -f $STOP_CORRUPT, $STOP_TAIL)
    # L3′ 일반 기동 + 'corrupt' → 같은 문구, 꼬리 없음 (꼬리는 재입장 실행부·마무리 실행 기동만 - 설계 R1 3.5)
    $row = Invoke-LaunchRow -CorruptText 'not json'
    Assert-Case "L3′ 일반 기동 + 'corrupt': 정지 = 손상 문구 + 파일 위치 안내(꼬리 없음)" (Format-Events (Get-StopEvents $row)) ('stop|{0}|True' -f $STOP_CORRUPT)
    # L3″ 마무리 실행 기동 + 읽기 실패 → 같은 문구 끝에 꼬리 (마무리 실행 기동은 늘 재입장 실행부가 부름 - 설계 R1 3.7 · 3.8 ⑤). 비커스텀 + 'corrupt' /
    #     커스텀(진행 저장 실패 보류 - 디스크 i, 보류 Owner i+1) + 'locked'. 변이 검증 보강(2026-10-09): 꼬리 조건에서 마무리 실행 항을 지운 변이가 L3
    #     (-FromInsideHandoff)만으로는 잡히지 않았음
    $plainHold = @{ Kind = 'safe-stop'; Reason = '안전 중지'; IsError = $false; Owner = @{ runId = 'run-test' }; Position = ''; Snapshot = $null }
    $row = Invoke-LaunchRow -CorruptText 'not json' -LaunchArgs @{ FinishOnlyHold = $plainHold }
    $plainFinishText = '{0} · {1}' -f $row.Launches.Count, (Format-Events (Get-StopEvents $row))
    $contextNow = New-AbyssContext -Index 0 -Generation 7
    $contextNext = New-AbyssContext -Index 1 -Generation 7
    $customHold = @{ Kind = 'step-failed'; Reason = '커스텀 진행 기록 저장 실패'; IsError = $true; Owner = (Get-CustomCanonicalOwner -Context $contextNext)
        Position = $contextNext.Position; Snapshot = $contextNow }
    $row = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @() -LaunchArgs @{ FinishOnlyHold = $customHold } -HoldLock
    Assert-Case "L3″ 마무리 실행 기동 + 읽기 실패: 비커스텀 'corrupt' || 커스텀 'locked' → 기동 0 · 정지 = 같은 문구 + 재입장 꼬리 · 오류" `
        ('{0} || {1} · {2}' -f $plainFinishText, $row.Launches.Count, (Format-Events (Get-StopEvents $row))) `
        ('0 · stop|{0}{1}|True || 0 · stop|{2}{1}|True' -f $STOP_CORRUPT, $STOP_TAIL, $STOP_LOCKED)

    # L-io 고른 항목의 launched 기록이 교체 실패(본 파일을 FileShare.Read 로 쥠)로 io-failed → 기동 0 · 읽기·쓰기 실패 문구 · 파일 그대로
    $runOwner = [pscustomobject]@{ runId = 'run-test' }
    $pendingNext = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -Nonce $NONCE_A
    $row = Invoke-LaunchRow -Entries @($pendingNext) -HoldMainRead
    Assert-Case "L-io 후보의 launched 기록 실패(io-failed): 기동 0 · 정지 = 읽기·쓰기 실패 문구 · 파일 그대로" `
        ('{0} · {1} · {2}' -f $row.Launches.Count, (Format-Events (Get-StopEvents $row)), [int]($row.StateBefore -ceq $row.StateAfter)) `
        ('0 · stop|{0}|True · 1' -f $STOP_ERROR)

    # L-ex 저장소가 예외를 전파(mutator 예외는 태그가 아니라 전파 - 저장소 계약) → Resolve 가 잡아 error · 기동 0 · 예외가 기동 밖으로 안 나감
    # (무예외 - 설계 R1 3.8 ②). 저장 함수를 throw 하는 것으로 잠시 바꿔 끼웁니다
    Set-ScriptFunction -Name 'Update-AbyssJournal' -Text ("function Update-AbyssJournal { param([string]`$Path, [scriptblock]`$Mutator, [scriptblock]`$Expect = `$null) throw '$INJECTED_STORE_EXCEPTION' }")
    try {
        $row = Invoke-LaunchRow -Entries @($pendingNext)
    } finally {
        # 되돌리는 원문은 저장소 감시(단계 2.6 - 호출 수를 세고 실제 저장으로 넘김)
        Set-ScriptFunction -Name 'Update-AbyssJournal' -Text $UPDATE_SPY_TEXT
    }
    Assert-Case 'L-ex 저장소 예외 전파: 기동 0 · 정지 = 읽기·쓰기 실패 문구 + 예외 메시지 · 예외 0 · 파일 그대로' `
        ('{0} · {1} · [{2}] · {3}' -f $row.Launches.Count, (Format-Events (Get-StopEvents $row)), $row.Thrown, [int]($row.StateBefore -ceq $row.StateAfter)) `
        ('0 · stop|{0} (예외: {1})|True · [] · 1' -f $STOP_ERROR, $INJECTED_STORE_EXCEPTION)
}

# ===== L 기동 - 마무리 실행 (설계 R1 5.4 L4~L7 · 3.7) =====
function Test-CaseLaunchFinishOnly {
    $generation = 7
    $contextNow = New-AbyssContext -Index 0 -Generation $generation        # 디스크 진행 = 끝난 판 i (진행 저장 실패 보류)
    $contextNext = New-AbyssContext -Index 1 -Generation $generation       # 보류 Owner = 다음 판 i+1 (재입장으로 들어간 판)
    $ownerNow = Get-CustomCanonicalOwner -Context $contextNow
    $ownerNext = Get-CustomCanonicalOwner -Context $contextNext
    $handoffEntry = New-FixtureEntry -Stage 'reentered' -Owner (ConvertTo-FiveFieldOwner $ownerNow) -NextOwner (ConvertTo-FiveFieldOwner $ownerNext) `
        -Generation $generation -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $markerNow = New-CustomMarkerOwnerJson -Context $contextNow           # 끝난 판 i 의 마커 (재입장 실행부의 진행 저장 실패 보류는 마커를 보존)
    $hold = @{ Kind = 'step-failed'; Reason = '커스텀 진행 기록 저장 실패'; IsError = $true; Owner = $ownerNext; Position = $contextNext.Position; Snapshot = $contextNow }
    $prevToken = Format-CustomItemToken -Item $ABYSS_ITEMS[0]

    # L4 커스텀 · 진행 저장 실패 보류(디스크 i, 보류 Owner i+1) → env 는 보류로(디스크 미사용) · 판별 항목 nonce · 마커 그대로 (변이 R1-M21)
    $row = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @($handoffEntry) -Applied @($NONCE_A) -MarkerText $markerNow `
        -LaunchArgs @{ FinishOnlyHold = $hold } -SeedCustom -PrevItem $prevToken -CompletedCycles 3
    $launchEnv = $row.LaunchEnv
    Assert-Case 'L4 기동 1 · 정지 0 · 디스크 컨텍스트 읽기 0 · 마커 정리 0 · 랜덤 표시 0 · 예외 0' `
        ('{0} · {1} · {2} · {3} · {4} · [{5}]' -f $row.Launches.Count, (Get-StopEvents $row).Count, $row.ContextReads, $row.MarkerClears, $row.RandomViews, $row.Thrown) '1 · 0 · 0 · 0 · 0 · []'
    Assert-Case 'L4 ITEM·POSITION·NEXT = i+1·i+1·i+2 (보류 Owner·Snapshot - 디스크 i 아님)' `
        (Format-EnvValues $launchEnv @('HONEYNOGI_CUSTOM_ITEM', 'HONEYNOGI_CUSTOM_POSITION', 'HONEYNOGI_CUSTOM_NEXT')) `
        ('{0}|{1}|{2}' -f (Format-CustomItemToken -Item $ABYSS_ITEMS[1]), $contextNext.Position, (Format-CustomItemToken -Item $ABYSS_ITEMS[2]))
    Assert-Case 'L4 OWNER = 다음 판 컨텍스트의 마커 소유자 JSON 과 글자까지 같음 (version 3 + 5필드 + generation - 같은 직렬화)' `
        $launchEnv['HONEYNOGI_CUSTOM_OWNER'] (New-CustomMarkerOwnerJson -Context $contextNext)
    $ownerProbePath = Join-Path $script:rowFolder 'owner_probe.marker'
    [IO.File]::WriteAllText($ownerProbePath, $launchEnv['HONEYNOGI_CUSTOM_OWNER'], $UTF8_NO_BOM)
    $ownerRead = Read-CustomMarkerOwner -Path $ownerProbePath
    Assert-Case 'L4 그 OWNER 로 워커가 쓴 마커를 실제 Read-CustomMarkerOwner 가 유효로 읽음 (index·generation)' `
        $(if ($null -eq $ownerRead) { '(무효)' } else { '{0}/{1}' -f $ownerRead.index, $ownerRead.generation }) ('1/{0}' -f $generation)
    Assert-Case 'L4 GENERATION = Owner 값 · RESTART·RECOVERY·NEXT_OWNER·NEXT_BOUNDARY 빈 값 · LAST_RUN·FINISH_ONLY 1' `
        (Format-EnvValues $launchEnv @('HONEYNOGI_CUSTOM_GENERATION', 'HONEYNOGI_CUSTOM_RESTART', 'HONEYNOGI_CUSTOM_RECOVERY', 'HONEYNOGI_CUSTOM_NEXT_OWNER',
                'HONEYNOGI_CUSTOM_NEXT_BOUNDARY', 'HONEYNOGI_LAST_RUN', 'HONEYNOGI_FINISH_ONLY')) ('{0}|||||1|1' -f $generation)
    Assert-Case 'L4 HANDOFF_NONCE = 판별 항목(Resolve 가 고른 next) · RESUME 빈 값 · PREV = 끝난 판 · MARKER 경로 있음 · 반복 정보' `
        (Format-EnvValues $launchEnv @('HONEYNOGI_HANDOFF_NONCE', 'HONEYNOGI_RESUME_REENTRY', 'HONEYNOGI_CUSTOM_PREV', 'HONEYNOGI_CUSTOM_MARKER', 'HONEYNOGI_REPEAT_INFO')) `
        ('{0}||{1}|{2}|커스텀 반복 마무리 실행({3})' -f $NONCE_A, $prevToken, $script:customMarkerFile, $contextNext.Position)
    Assert-Case 'L4 LIST = 보류 Snapshot 의 실행 목록 표기' $launchEnv['HONEYNOGI_CUSTOM_LIST'] (Get-CustomListCompact -Items $ABYSS_ITEMS)
    Assert-Case "L4 기동 종류 finish-only · nonce = 판별 항목 · 보류 = 넘긴 보류 · Resolve 1번 · 마커 파일 그대로" `
        ('{0} · {1} · {2} · {3} · {4}' -f $row.Kind, $row.Nonce, [int]([object]::ReferenceEquals($row.Hold, $hold)), $row.ResolveCalls, [int]($row.MarkerBefore -ceq $row.MarkerAfter)) `
        ('finish-only · {0} · 1 · 1 · 1' -f $NONCE_A)
    Assert-Case "L4 상태줄 '커스텀: <i+1 위치> 마무리 실행 중 …'(시간 꼬리 없음) · 초록 · 일반 시작 줄 없음(명세 5절 B11)" `
        ('{0} · {1} · {2}' -f $row.StatusText, $row.Color, (Format-Events $row.Events)) `
        ('커스텀: {0} 마무리 실행 중 - 이 판을 마치면 멈춥니다 · ForestGreen · launch|powershell.exe' -f $contextNext.Position)
    # L4′ 앞 기동이 마커 정리에 실패해 이번 실행이 마커를 무시 중(customMarkerIgnore 참) → 마무리 실행도 MARKER 빈 값 · 무시 판단 그대로 · 마커 정리 0
    #     (회차 준비와 같은 식 - 설계 R1 3.7 '커스텀 MARKER' 행. 경로를 주면 묘비 옆에 워커가 정상 마커를 써서 다음 시작 게이트가 묘비만 보고 그
    #     마커를 지움 - 2026-08-09 재점검 사고 모양). 변이 검증 보강(2026-10-09): L4 가 무시 거짓만 봐서 무시 판단을 안 보는 변이가 살아남았음
    $row = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @($handoffEntry) -Applied @($NONCE_A) -MarkerText $markerNow `
        -LaunchArgs @{ FinishOnlyHold = $hold } -MarkerIgnore $true
    Assert-Case 'L4′ 마무리 실행 + 마커 무시 중: 기동 1 · MARKER 빈 값 · 무시 판단 그대로(참) · 마커 정리 0 · 마커 파일 그대로' `
        ('{0} · [{1}] · {2} · {3} · {4}' -f $row.Launches.Count, $row.LaunchEnv['HONEYNOGI_CUSTOM_MARKER'], [int]$row.MarkerIgnore, $row.MarkerClears,
            [int]($row.MarkerBefore -ceq $row.MarkerAfter)) '1 · [] · 1 · 0 · 1'

    # L5 비커스텀 마무리 실행 → 커스텀 env 없음 · LAST_RUN·FINISH_ONLY 1 · HANDOFF_NONCE · UNTIL 은 GUI 계산 그대로(어비스 혼자하기 = 빈 값) · 상태줄
    $runOwner = [pscustomobject]@{ runId = 'run-L5' }
    $runEntry = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_B
    $plainHold = @{ Kind = 'safe-stop'; Reason = '안전 중지'; IsError = $false; Owner = @{ runId = 'run-L5' }; Position = ''; Snapshot = $null }
    $row = Invoke-LaunchRow -RunId 'run-L5' -Entries @($runEntry) -Applied @($NONCE_B) -LaunchArgs @{ FinishOnlyHold = $plainHold } -SeedCustom `
        -CompletedCycles 4 -TargetTime ([datetime]::new(2026, 10, 9, 21, 20, 0))
    $launchEnv = $row.LaunchEnv
    Assert-Case 'L5 기동 1 · 커스텀 env 빈 값(Clear-CustomEnv) · LAST_RUN·FINISH_ONLY 1 · HANDOFF_NONCE · UNTIL 빈 값' `
        ('{0} · [{1}] · {2}|{3}|{4}|[{5}]' -f $row.Launches.Count, (Format-EnvValues $launchEnv ($CUSTOM_ENV_NAMES | Where-Object { $_ -ne 'HONEYNOGI_LAST_RUN' })),
            $launchEnv['HONEYNOGI_LAST_RUN'], $launchEnv['HONEYNOGI_FINISH_ONLY'], $launchEnv['HONEYNOGI_HANDOFF_NONCE'], $launchEnv['HONEYNOGI_UNTIL_TIME']) `
        ('1 · [{0}] · 1|1|{1}|[]' -f ('|' * 9), $NONCE_B)
    Assert-Case "L5 상태줄 'N회차 마무리 실행 중 …'(시간 꼬리 없음) · 기동 종류 finish-only · 일반 시작 줄 없음" `
        ('{0} · {1}/{2} · {3}' -f $row.StatusText, $row.Kind, $row.Nonce, (Format-Events $row.Events)) `
        ('5회차 마무리 실행 중 - 이 판을 마치면 멈춥니다 · finish-only/{0} · launch|powershell.exe' -f $NONCE_B)

    # L6 마무리 실행(L4) 뒤 새 실행의 첫 기동(던전) - 앞 기동이 남긴 FINISH_ONLY·HANDOFF_NONCE 를 먼저 비움 · 커스텀 세대도 남지 않음
    $null = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @($handoffEntry) -Applied @($NONCE_A) -LaunchArgs @{ FinishOnlyHold = $hold }
    $leftEnv = Get-HandoffEnvSnapshot
    $row = Invoke-LaunchRow -Content 'dungeon' -KeepEnv
    Assert-Case 'L6 앞 기동 env(FINISH_ONLY·NONCE·GENERATION) → 새 실행 첫 기동(던전): handoff env 3 빈 값 · GENERATION 빈 값 · 종류 none · 보류 없음' `
        ('{0}/{1} → [{2}] · [{3}] · {4} · {5}' -f $leftEnv['HONEYNOGI_FINISH_ONLY'], [int]($leftEnv['HONEYNOGI_HANDOFF_NONCE'] -eq $NONCE_A),
            (Format-HandoffEnv $row.LaunchEnv), $row.LaunchEnv['HONEYNOGI_CUSTOM_GENERATION'], $row.Kind, [int]($null -eq $row.Hold)) `
        '1/1 → [||] · [] · none · 1'

    # L7 커스텀 마무리 실행 조립 실패 → 기동 0 · 커스텀 env 대입 0(묵은 값 그대로) · 오류 정지 1(준비 실패 문구 + 꼬리) · 예외 0 · 디스크 읽기 0
    # (변이 R1-M20: 조립 함수의 try 를 지우면 (다) 의 예외가 기동 밖으로 나감). (나′)·(라) 는 변이 검증 보강(2026-10-09) - 범위 검사의 음수 항과
    # Owner 없음 항을 지운 변이가 살아남았음: [int]$null 은 0 이라 Owner 가 없으면 범위 검사를 통과해 ITEM 이 빈 값인 채 기동하고(워커는 ITEM 이
    # 없으면 비커스텀 모드), 음수 위치면 OWNER 의 index 가 어떤 진행과도 맞지 않아 그 워커의 마커로는 마무리 복구를 못 하고 다음 칸(NEXT)도 엉뚱합니다
    $failRows = @(
        @{ N = '(가) 보류 Snapshot 없음'; Hold = @{ Kind = 'step-failed'; Reason = 'x'; IsError = $true; Owner = $ownerNext; Position = $contextNext.Position; Snapshot = $null }
           Reason = '보류 진행 정보 없음' }
        @{ N = '(나) Owner.index 가 Snapshot 범위 밖'
           Hold = @{ Kind = 'step-failed'; Reason = 'x'; IsError = $true; Owner = (Get-CustomCanonicalOwner -Context (New-AbyssContext -Index 2 -Generation $generation)) + @{}; Position = '1바퀴째 4/3번'; Snapshot = $contextNow }
           Reason = '보류 위치 4번이 목록 범위(3칸) 밖'; OwnerIndex = 3 }
        @{ N = '(나′) Owner.index 가 음수(범위 아래)'
           Hold = @{ Kind = 'step-failed'; Reason = 'x'; IsError = $true; Owner = (Get-CustomCanonicalOwner -Context $contextNext) + @{}; Position = '1바퀴째 0/3번'; Snapshot = $contextNow }
           Reason = '보류 위치 0번이 목록 범위(3칸) 밖'; OwnerIndex = -1 }
        @{ N = '(다) 토큰 조립 함수 예외'; Hold = $hold; Reason = ('환경 변수 조립 예외: {0}' -f $INJECTED_TOKEN_EXCEPTION); InjectToken = $true }
        @{ N = '(라) 보류 Owner 없음'; Hold = @{ Kind = 'step-failed'; Reason = 'x'; IsError = $true; Owner = $null; Position = $contextNext.Position; Snapshot = $contextNow }
           Reason = '보류 진행 정보 없음' }
    )
    foreach ($failRow in $failRows) {
        if ($failRow.ContainsKey('OwnerIndex')) { $failRow.Hold.Owner['index'] = $failRow.OwnerIndex }
        if ($failRow.InjectToken) { Set-ScriptFunction -Name 'Format-CustomItemToken' -Text ("function Format-CustomItemToken { param(`$Item) throw '$INJECTED_TOKEN_EXCEPTION' }") }
        try {
            $row = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @($handoffEntry) -Applied @($NONCE_A) -LaunchArgs @{ FinishOnlyHold = $failRow.Hold } -SeedCustom
        } finally {
            if ($failRow.InjectToken) { Set-ScriptFunction -Name 'Format-CustomItemToken' -Text $guiFunctionTexts['Format-CustomItemToken'] }
        }
        Assert-Case ('L7 {0}: 기동 0 · 정지 = 준비 실패 문구 + 재입장 꼬리 · 빨강 · 예외 0 · 디스크 읽기 0 · Resolve 0' -f $failRow.N) `
            ('{0} · {1} · {2} · [{3}] · {4} · {5}' -f $row.Launches.Count, (Format-Events (Get-StopEvents $row)), $row.Color, $row.Thrown, $row.ContextReads, $row.ResolveCalls) `
            ('0 · stop|{0}{1}|True · Firebrick · [] · 0 · 0' -f ($FINISH_PREP_FORMAT -f $failRow.Reason), $STOP_TAIL)
        $customLeft = @($CUSTOM_ENV_NAMES + $NEXT_OWNER_ENV_NAMES | Where-Object { $row.EnvAfter[$_] -cne $STALE_VALUE })
        Assert-Case ('L7 {0}: 커스텀 env 대입 0 (묵은 값이 바뀐 이름 수)' -f $failRow.N) $customLeft.Count 0
    }
}

# ===== L 기동 - 워커 시작 실패 (설계 R1 3.8 ⑤ · 3.5) =====
function Test-CaseLaunchStartFail {
    # L8 워커 프로세스 시작 실패(Start-Process 예외 → 기동의 catch / 프로세스 없음) → [경고] 1줄 + 오류 정지 '워커 시작 실패'(지금 문구 그대로) ·
    #    기동 기록 0 · 상태줄·시작 줄 없음(정지 뒤 return) · 예외 0. 재입장 실행부가 부른 기동(-FromInsideHandoff)·마무리 실행 기동만 끝에 3.5 꼬리 -
    #    그 기동은 캐릭터가 '다시 하기'로 들어간 던전 안에 입장 키 없이 서 있을 수 있습니다. 일반 기동은 범위(어비스·던전)와 무관하게 문구 그대로.
    #    (명세 대조 2026-10-09 - 기동 보류 정지·조립 실패에는 꼬리가 있는데 이 갈래만 빠져 있었음)
    $generation = 7
    $contextNow = New-AbyssContext -Index 0 -Generation $generation
    $contextNext = New-AbyssContext -Index 1 -Generation $generation
    $ownerNow = Get-CustomCanonicalOwner -Context $contextNow
    $ownerNext = Get-CustomCanonicalOwner -Context $contextNext
    $handoffEntry = New-FixtureEntry -Stage 'reentered' -Owner (ConvertTo-FiveFieldOwner $ownerNow) -NextOwner (ConvertTo-FiveFieldOwner $ownerNext) `
        -Generation $generation -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $customHold = @{ Kind = 'step-failed'; Reason = '커스텀 진행 기록 저장 실패'; IsError = $true; Owner = $ownerNext; Position = $contextNext.Position; Snapshot = $contextNow }
    $plainHold = @{ Kind = 'safe-stop'; Reason = '안전 중지'; IsError = $false; Owner = @{ runId = 'run-test' }; Position = ''; Snapshot = $null }
    $failRows = @(
        @{ N = '(가) 일반 기동(어비스 비커스텀) · 예외'; Failure = 'throw'; LaunchArgs = @{}; Content = 'abyss'; Custom = $false; Tail = $false }
        @{ N = '(나) 재입장 실행부가 부른 기동 · 프로세스 없음'; Failure = 'null'; LaunchArgs = @{ FromInsideHandoff = $true }; Content = 'abyss'; Custom = $false; Tail = $true }
        @{ N = '(다) 커스텀 마무리 실행 · 프로세스 없음'; Failure = 'null'; LaunchArgs = @{ FinishOnlyHold = $customHold }; Content = 'abyss'; Custom = $true; Tail = $true }
        @{ N = '(라) 비커스텀 마무리 실행 · 예외'; Failure = 'throw'; LaunchArgs = @{ FinishOnlyHold = $plainHold }; Content = 'abyss'; Custom = $false; Tail = $true }
        @{ N = '(마) 일반 기동(던전 - 완료 기록 범위 밖) · 프로세스 없음'; Failure = 'null'; LaunchArgs = @{}; Content = 'dungeon'; Custom = $false; Tail = $false }
    )
    foreach ($failRow in $failRows) {
        if ($failRow.Custom) {
            $row = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @($handoffEntry) -Applied @($NONCE_A) -LaunchArgs $failRow.LaunchArgs `
                -StartFailure $failRow.Failure
        } else {
            $row = Invoke-LaunchRow -Content $failRow.Content -LaunchArgs $failRow.LaunchArgs -StartFailure $failRow.Failure
        }
        $wantReason = $(if ($failRow.Tail) { $STOP_START_FAIL + $STOP_TAIL } else { $STOP_START_FAIL })
        Assert-Case ('L8 {0}: 기동 기록 0 · 사건 = 시작 시도 → [경고] → 오류 정지(재입장 꼬리 {1}) · 상태줄 그대로 · 예외 0' -f $failRow.N, $(if ($failRow.Tail) { '있음' } else { '없음' })) `
            ('{0} · {1} · [{2}] · [{3}]' -f $row.Launches.Count, (Format-Events $row.Events), $row.StatusText, $row.Thrown) `
            ('0 · {0} · [] · []' -f (Format-Events @(('launch-{0}|powershell.exe' -f $failRow.Failure), "gui|$START_FAIL_WARNING", ('stop|{0}|True' -f $wantReason))))
    }
}

# ===== K 기동 종류 5값 · 그때의 env (설계 v10 6.1 · R1 3.8 ③) =====
function Test-CaseLaunchKinds {
    $generation = 3
    $contextNow = New-AbyssContext -Index 1 -Generation $generation
    $ownerNow = Get-CustomCanonicalOwner -Context $contextNow

    # K-none 어비스 비커스텀 · 완료 기록 없음 → none · handoff env 빈 값 · 파일 생성 0 · 일반 상태줄·시작 줄
    $row = Invoke-LaunchRow -CompletedCycles 1
    Assert-Case 'K-none 어비스 비커스텀 · 후보 없음: 종류 none · Resolve 1 · env 빈 값 · 파일 생성 0 · 상태줄·시작 줄 그대로' `
        ('{0}/{1} · {2} · [{3}] · [{4}] · {5} · {6}' -f $row.Kind, $row.Nonce, $row.ResolveCalls, (Format-HandoffEnv $row.LaunchEnv), $row.StateAfter, $row.StatusText, (Format-Events $row.Events)) `
        'none/ · 1 · [||] · [] · 2회차 실행 중... · launch|powershell.exe / gui|=== 2회차 시작 ==='

    # K-next 어비스 비커스텀 · nextOwner = 이번 runId 인 reentered(pending) → next · HANDOFF_NONCE · 같은 저장에서 launched
    $runOwner = [pscustomobject]@{ runId = 'run-test' }
    $nextEntry = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -Nonce $NONCE_B
    $row = Invoke-LaunchRow -Entries @($nextEntry) -Applied @($NONCE_B)
    Assert-Case 'K-next 어비스 비커스텀 · reentered 후보: 종류 next · nonce · HANDOFF_NONCE · launched 기록 · seq +1' `
        ('{0}/{1} · [{2}] · {3} · {4}' -f $row.Kind, $row.Nonce, (Format-HandoffEnv $row.LaunchEnv), (Get-EntryLaunchState $row.Journal $NONCE_B), $row.Journal.seq) `
        ('next/{0} · [{0}||] · launched · 6' -f $NONCE_B)

    # K-own 어비스 커스텀 · 열린 자기 항목(entered, launched) → own · HANDOFF_NONCE · 쓰기 0 · 일반 커스텀 env(세대 env 포함) · 마커 정리 1
    $ownEntry = New-FixtureEntry -Stage 'entered' -Owner (ConvertTo-FiveFieldOwner $ownerNow) -Generation $generation -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_C
    $row = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @($ownEntry) -SeedCustom -MarkerIgnore $true
    Assert-Case 'K-own 어비스 커스텀 · 열린 entered: 종류 own · HANDOFF_NONCE · 이미 launched 라 쓰기 0(파일 그대로)' `
        ('{0}/{1} · [{2}] · {3}' -f $row.Kind, $row.Nonce, (Format-HandoffEnv $row.LaunchEnv), [int]($row.StateBefore -ceq $row.StateAfter)) `
        ('own/{0} · [{0}||] · 1' -f $NONCE_C)
    Assert-Case 'K-own 일반 커스텀 env: ITEM · OWNER = 마커 소유자 JSON · GENERATION = 진행 세대(명세 5절 A3) · LAST_RUN 빈 값' `
        (Format-EnvValues $row.LaunchEnv @('HONEYNOGI_CUSTOM_ITEM', 'HONEYNOGI_CUSTOM_OWNER', 'HONEYNOGI_CUSTOM_GENERATION', 'HONEYNOGI_LAST_RUN')) `
        ('{0}|{1}|{2}|' -f (Format-CustomItemToken -Item $ABYSS_ITEMS[1]), (New-CustomMarkerOwnerJson -Context $contextNow), $generation)
    Assert-Case 'K-own 일반 기동: 디스크 컨텍스트 1 · 마커 정리 1 · 무시 판단 초기화(참 → 거짓) · MARKER 경로 · 상태줄 · 시작 줄' `
        ('{0} · {1} · {2} · {3} · {4} · {5}' -f $row.ContextReads, $row.MarkerClears, [int]$row.MarkerIgnore, $row.LaunchEnv['HONEYNOGI_CUSTOM_MARKER'], $row.StatusText, ((@($row.Events) | Where-Object { $_.StartsWith('gui|') }) -join ' / ')) `
        ('1 · 1 · 0 · {0} · 커스텀: {1} 실행 중 · gui|=== 1회차 시작(2/3) ===' -f $script:customMarkerFile, $contextNow.Position)

    # K-resume 어비스 커스텀 재개(-PreserveMarker -ResumeNonce) · retry-clicked(같은 owner·미적용) → resume · RESUME 1 · 마커 정리 0 · 무시 판단 그대로
    $retryEntry = New-FixtureEntry -Stage 'retry-clicked' -Owner (ConvertTo-FiveFieldOwner $ownerNow) -Generation $generation -Section $ABYSS_SECTION -Nonce $NONCE_D
    $row = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @($ownEntry, $retryEntry) -MarkerIgnore $true `
        -LaunchArgs @{ PreserveMarker = $true; ResumeNonce = $NONCE_D }
    Assert-Case 'K-resume 재개 기동: 종류 resume · HANDOFF_NONCE·RESUME = 그 항목·1 (열린 own 이 있어도 재개만) · 그 항목 launched' `
        ('{0}/{1} · [{2}] · {3}/{4}' -f $row.Kind, $row.Nonce, (Format-HandoffEnv $row.LaunchEnv), (Get-EntryLaunchState $row.Journal $NONCE_D), (Get-EntryLaunchState $row.Journal $NONCE_C)) `
        ('resume/{0} · [{0}|1|] · launched/launched' -f $NONCE_D)
    Assert-Case 'K-resume -PreserveMarker: 마커 정리 0 · 앞 기동의 무시 판단(참) 그대로 → MARKER 빈 값 (명세 2.5 ⑤ - 8412 까지 감쌈)' `
        ('{0} · {1} · [{2}]' -f $row.MarkerClears, [int]$row.MarkerIgnore, $row.LaunchEnv['HONEYNOGI_CUSTOM_MARKER']) '0 · 1 · []'
    # 재개 요청인데 그 항목이 재개 조건이 아니면(적용됨) 후보 없음 - 다른 후보(own)로 넘어가지 않습니다 (워커의 재개 역할 술어와 같은 조건)
    $row = Invoke-LaunchRow -Custom $true -DiskContext $contextNow -Entries @($ownEntry, $retryEntry) -Applied @($NONCE_D) `
        -LaunchArgs @{ PreserveMarker = $true; ResumeNonce = $NONCE_D }
    Assert-Case 'K-resume′ 재개 대상이 이미 적용됨: 종류 none · handoff env 빈 값 · 기동 1' ('{0}/{1} · [{2}] · {3}' -f $row.Kind, $row.Nonce, (Format-HandoffEnv $row.LaunchEnv), $row.Launches.Count) 'none/ · [||] · 1'
}

# ===== R Resolve-HandoffEnvForContext 진리표 (설계 v10 6.1 규칙 ①~④ · 명세 2.5 표) =====
function Invoke-ResolveRow {
    # 완료 기록 픽스처 → 실제 Resolve 1번 → 결과 · 본 파일 상태
    param($Context, [object[]]$Entries = $null, [object[]]$Applied = @(), [bool]$Restart = $false, [string]$ResumeNonce = '')
    Initialize-JournalRow
    if ($null -ne $Entries) { Write-FixtureJournal -Path $script:abyssJournalPath -Entries $Entries -Applied $Applied }
    $stateBefore = Get-FolderState -Folder $script:rowFolder
    $result = Resolve-HandoffEnvForContext -Context $Context -Restart $Restart -ResumeNonce $ResumeNonce
    return [pscustomobject]@{
        Result = $result
        Text = ('{0}/{1}/{2}' -f $result.Status, $result.Kind, $result.Nonce)
        Journal = (Read-FixtureJournal -Path $script:abyssJournalPath)
        Unchanged = [int]($stateBefore -ceq (Get-FolderState -Folder $script:rowFolder))
        StateAfter = (Get-FolderState -Folder $script:rowFolder)
    }
}

function Test-CaseResolve {
    $generation = 4
    $contextA = New-AbyssContext -Index 0 -Generation $generation
    $contextB = New-AbyssContext -Index 1 -Generation $generation
    $ownerA = Get-CustomCanonicalOwner -Context $contextA
    $ownerB = Get-CustomCanonicalOwner -Context $contextB
    $fiveA = ConvertTo-FiveFieldOwner $ownerA
    $fiveB = ConvertTo-FiveFieldOwner $ownerB
    $runOwner = [pscustomobject]@{ runId = 'run-R' }
    $runContext = @{ runId = 'run-R' }

    # R1 커스텀: 열린 own(pending) + next 둘 다 → own(규칙 ② - 커스텀은 own 먼저) · 고른 항목만 launched · seq +1
    $own = New-FixtureEntry -Stage 'entered' -Owner $fiveB -Generation $generation -Section $ABYSS_SECTION -Nonce $NONCE_A
    $next = New-FixtureEntry -Stage 'reentered' -Owner $fiveA -NextOwner $fiveB -Generation $generation -Section $ABYSS_SECTION -Nonce $NONCE_B
    $row = Invoke-ResolveRow -Context $ownerB -Entries @($next, $own)
    Assert-Case 'R1 커스텀 own + next → own · own 만 launched · seq +1' ('{0} · {1}/{2} · {3}' -f $row.Text, (Get-EntryLaunchState $row.Journal $NONCE_A), (Get-EntryLaunchState $row.Journal $NONCE_B), $row.Journal.seq) `
        ('ok/own/{0} · launched/pending · 6' -f $NONCE_A)
    # R2 커스텀: own 없음 → next (nextOwner = 이번 owner · 같은 세대) · launched
    $row = Invoke-ResolveRow -Context $ownerB -Entries @($next)
    Assert-Case 'R2 커스텀 next 만 → next · launched' ('{0} · {1}' -f $row.Text, (Get-EntryLaunchState $row.Journal $NONCE_B)) ('ok/next/{0} · launched' -f $NONCE_B)
    # R3 비커스텀: 열린 own(entered, runId) + next → next 만 (runId 가 시작마다 새로 나 own 은 이어질 수 없음 - 규칙 ③)
    $runOwn = New-FixtureEntry -Stage 'entered' -Owner $runOwner -Nonce $NONCE_C
    $runNext = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -Nonce $NONCE_D
    $row = Invoke-ResolveRow -Context $runContext -Entries @($runOwn, $runNext)
    Assert-Case 'R3 비커스텀 own + next → next (own 무시)' $row.Text ('ok/next/{0}' -f $NONCE_D)
    # R3′ 비커스텀 + 재시작(-Restart) → own 먼저 (규칙 ② 글자 그대로 - 비커스텀 재시작은 실제로는 생기지 않음)
    $row = Invoke-ResolveRow -Context $runContext -Entries @($runOwn, $runNext) -Restart $true
    Assert-Case 'R3′ 비커스텀 + 재시작 → own (규칙 ②)' $row.Text ('ok/own/{0}' -f $NONCE_C)
    # R4 done 은 후보가 아님 → none · 쓰기 0
    $doneOwn = New-FixtureEntry -Stage 'entered' -Owner $fiveB -Generation $generation -LaunchState 'done' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $doneNext = New-FixtureEntry -Stage 'reentered' -Owner $fiveA -NextOwner $fiveB -Generation $generation -LaunchState 'done' -Section $ABYSS_SECTION -Nonce $NONCE_B
    $row = Invoke-ResolveRow -Context $ownerB -Entries @($doneOwn, $doneNext)
    Assert-Case 'R4 own·next 둘 다 done → none · 파일 그대로' ('{0} · {1}' -f $row.Text, $row.Unchanged) 'none/none/ · 1'
    # R5 같은 종류가 여럿 → 가장 최근(배열 뒤쪽)
    $olderNext = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -Nonce $NONCE_A
    $newerNext = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -Nonce $NONCE_B
    $row = Invoke-ResolveRow -Context $runContext -Entries @($olderNext, $newerNext)
    Assert-Case 'R5 next 둘 → 뒤쪽(최근) · 앞쪽은 그대로' ('{0} · {1}' -f $row.Text, (Get-EntryLaunchState $row.Journal $NONCE_A)) ('ok/next/{0} · pending' -f $NONCE_B)
    # R6 세대가 다름 → 같은 5필드여도 후보 아님 (owner 대조 = 5필드 AND 세대)
    $oldGeneration = New-FixtureEntry -Stage 'entered' -Owner $fiveB -Generation ($generation - 1) -Section $ABYSS_SECTION -Nonce $NONCE_A
    $row = Invoke-ResolveRow -Context $ownerB -Entries @($oldGeneration)
    Assert-Case 'R6 세대 불일치 → none · 쓰기 0' ('{0} · {1}' -f $row.Text, $row.Unchanged) 'none/none/ · 1'
    # R7 재개: retry-clicked · 같은 owner · 미적용 → resume · launched / R7′ 적용됨 → none / R7″ 단계가 cleared → none / R7‴ retry-attempt → resume
    $retryClicked = New-FixtureEntry -Stage 'retry-clicked' -Owner $fiveA -Generation $generation -Section $ABYSS_SECTION -Nonce $NONCE_C
    $row = Invoke-ResolveRow -Context $ownerA -Entries @($retryClicked) -ResumeNonce $NONCE_C
    Assert-Case 'R7 재개 retry-clicked → resume · launched' ('{0} · {1}' -f $row.Text, (Get-EntryLaunchState $row.Journal $NONCE_C)) ('ok/resume/{0} · launched' -f $NONCE_C)
    $row = Invoke-ResolveRow -Context $ownerA -Entries @($retryClicked) -Applied @($NONCE_C) -ResumeNonce $NONCE_C
    Assert-Case "R7′ 재개 대상이 applied → none · 쓰기 0" ('{0} · {1}' -f $row.Text, $row.Unchanged) 'none/none/ · 1'
    $clearedOnly = New-FixtureEntry -Stage 'cleared' -Owner $fiveA -Generation $generation -Section $ABYSS_SECTION -Nonce $NONCE_C
    $row = Invoke-ResolveRow -Context $ownerA -Entries @($clearedOnly) -ResumeNonce $NONCE_C
    Assert-Case "R7″ 재개 대상 단계가 cleared → none" $row.Text 'none/none/'
    $retryAttempt = New-FixtureEntry -Stage 'retry-attempt' -Owner $fiveA -Generation $generation -Section $ABYSS_SECTION -Nonce $NONCE_C
    $row = Invoke-ResolveRow -Context $ownerA -Entries @($retryAttempt) -ResumeNonce $NONCE_C
    Assert-Case "R7‴ 재개 대상 retry-attempt → resume" $row.Text ('ok/resume/{0}' -f $NONCE_C)
    # R8 고른 항목이 이미 launched(앞 기동이 넘긴 nonce 의 재전달) → ok · 쓰기 0
    $launchedNext = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_D
    $row = Invoke-ResolveRow -Context $runContext -Entries @($launchedNext)
    Assert-Case 'R8 이미 launched 인 후보 → ok/next · 쓰기 0(파일 그대로)' ('{0} · {1}' -f $row.Text, $row.Unchanged) ('ok/next/{0} · 1' -f $NONCE_D)
    # R9 완료 기록 파일 없음 → none · 파일 생성 0 (잠금 파일도 남지 않음)
    $row = Invoke-ResolveRow -Context $runContext
    Assert-Case 'R9 파일 없음 → none · 폴더 그대로 비어 있음' ('{0} · [{1}]' -f $row.Text, $row.StateAfter) 'none/none/ · []'
    # R10 본 파일 손상 + 직전본 유효 → 저장소가 잠금 아래 직전본으로 복구하고 그 경고를 돌려줌 → Resolve 가 GUI 로그에 1줄(로그는 호출부 몫 -
    #     저장소 계약) · 후보는 복구된 내용에서 고름
    Initialize-JournalRow
    Write-FixtureJournal -Path $script:abyssJournalPath -Entries @($runNext)
    [IO.File]::Copy($script:abyssJournalPath, $script:abyssJournalPath + '.bak')
    [IO.File]::WriteAllText($script:abyssJournalPath, '{ "version": 1, "seq": ', $UTF8_BOM)
    $result = Resolve-HandoffEnvForContext -Context $runContext
    Assert-Case 'R10 본 파일 손상 + 직전본 유효 → 복구 경고 1줄 · next 선택(복구된 내용) · 그 항목 launched' `
        ('{0}/{1}/{2} · {3} · {4}' -f $result.Status, $result.Kind, $result.Nonce, (Format-Events @($script:events)), (Get-EntryLaunchState (Read-FixtureJournal -Path $script:abyssJournalPath) $NONCE_D)) `
        ('ok/next/{0} · gui|[경고] 완료 기록 파일 손상 - 직전본으로 복구 · launched' -f $NONCE_D)
}

# ===== S 정적 (주석 뺀 GUI 사본) =====
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

function Test-CaseStatic {
    Assert-Case 'S1 Start-NextCycle 서명 = 명세 2.5 ④ (기존 호출은 인자 없이)' (Get-ParamSignature $guiAst 'Start-NextCycle') `
        'SwitchParameter $PreserveMarker, SwitchParameter $FromInsideHandoff, Object $FinishOnlyHold, String $ResumeNonce'
    $nextCycleCode = Remove-SourceComments -Text $guiFunctionTexts['Start-NextCycle']
    $launchCall = 'if (-not (Set-HandoffLaunchEnv -FinishOnlyHold $FinishOnlyHold -ResumeNonce $ResumeNonce -FromInsideHandoff:$FromInsideHandoff -CustomContext $customContext)) { return }'
    $sitePattern = (@("`$script:lastWorkerDoneReason = ''", $launchCall, 'try {') | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    Assert-Case 'S2 handoff env 자리 = [완료] 사유 초기화 바로 뒤 · 워커 기동 try 바로 앞 (설계 R1 3.8 ③) 1곳' ([regex]::Matches($nextCycleCode, $sitePattern).Count) 1
    Assert-Case 'S2 호출 소유자: Set-HandoffLaunchEnv = Start-NextCycle · Resolve = Set-HandoffLaunchEnv · 조립 = Start-NextCycle · handoff env 비움 = 기동·정지' `
        ('{0} / {1} / {2} / {3}' -f (Get-GuiCallOwners 'Set-HandoffLaunchEnv'), (Get-GuiCallOwners 'Resolve-HandoffEnvForContext'), (Get-GuiCallOwners 'Get-FinishOnlyCustomEnv'), (Get-GuiCallOwners 'Clear-HandoffEnv')) `
        '1|Start-NextCycle / 1|Set-HandoffLaunchEnv / 1|Start-NextCycle / 2|Set-HandoffLaunchEnv,Stop-AllRun'
    # S3 정지가 handoff 상태를 비움(커스텀 여부와 무관 - 커스텀 갈래 밖) · RUN_ID 는 지우지 않음(명세 5절 C12)
    $stopAst = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq 'Stop-AllRun') }, $true))[0]
    $stopTopLevel = @($stopAst.Body.EndBlock.Statements | ForEach-Object { ($_.Extent.Text -replace '\s+', ' ').Trim() })
    Assert-Case 'S3 Stop-AllRun 본문 최상위 문장: handoff env 비움 · 보류 $null · 기동 종류 none · nonce 빈 값 · RUN_ID 언급 0' `
        ('{0}/{1}/{2}/{3}/{4}' -f [int]($stopTopLevel -ccontains 'Clear-HandoffEnv'), [int]($stopTopLevel -ccontains '$script:finishOnlyHold = $null'),
            [int]($stopTopLevel -ccontains "`$script:lastLaunchKind = 'none'"), [int]($stopTopLevel -ccontains "`$script:lastLaunchNonce = ''"),
            ([regex]::Matches((Remove-SourceComments -Text $stopAst.Extent.Text), 'HONEYNOGI_RUN_ID').Count)) '1/1/1/1/0'
    # S4 RUN_ID = 시작 버튼마다(Invoke-StartAutomation) 새 GUID → env (설계 v10 6.1 env 목록) · GUI 의 RUN_ID env 대입은 그 1곳
    $startCode = Remove-SourceComments -Text (@(Get-SourceFunctionDefinitions -Path $guiPath -Names @('Invoke-StartAutomation'))[0])
    $runIdPattern = (@("`$script:runId = [guid]::NewGuid().ToString('D')", '$env:HONEYNOGI_RUN_ID = $script:runId') | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    # GUI 전체 개수는 AST 의 대입문으로 셉니다 (주석은 대입문이 아님 - 600KB 원문 전체의 주석 빼기를 피함)
    $runIdAssigns = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$env:HONEYNOGI_RUN_ID') }, $true))
    Assert-Case 'S4 실행 시작: 새 실행 id → HONEYNOGI_RUN_ID 1곳(시작 처리 안) · GUI 전체 RUN_ID 대입 1곳' `
        ('{0}/{1}' -f [regex]::Matches($startCode, $runIdPattern).Count, $runIdAssigns.Count) '1/1'
    # S4′ 실행 시작 초기화(명세 2.5 ③): RUN_ID 다음에 기동 종류·nonce·마무리 실행 보류·비커스텀 재입장 오류 연속을 처음으로 / 커스텀 게이트의
    #     초기화 자리(진행 복구 대기 해제 뒤)에서 재개 수동 1회 예약을 비움 - 행동 행은 기동마다 다시 정하는 값만 보므로 원문으로 고정합니다
    $startInitPattern = (@('$env:HONEYNOGI_RUN_ID = $script:runId', "`$script:lastLaunchKind = 'none'", "`$script:lastLaunchNonce = ''",
            '$script:finishOnlyHold = $null', '$script:abyssErrorStreak = 0') | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    $resumeInitPattern = (@('$script:customRecoveryPending = $false', '$script:customResumePending = $false', "`$script:customResumeNonce = ''") |
            ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    Assert-Case 'S4′ 시작 처리: RUN_ID → 기동 종류·nonce·보류·오류 연속 초기화 순서 1곳 · 커스텀 게이트의 재개 예약 비움 1곳' `
        ('{0}/{1}' -f [regex]::Matches($startCode, $startInitPattern).Count, [regex]::Matches($startCode, $resumeInitPattern).Count) '1/1'
    # S7 상태 변수 선언(명세 2.5 ②) - 스크립트 최상위에 기본값으로 한 번씩
    $declarations = @{}
    foreach ($statement in $guiAst.EndBlock.Statements) {
        if ($statement -is [System.Management.Automation.Language.AssignmentStatementAst]) { $declarations[$statement.Left.Extent.Text] = $statement.Right.Extent.Text }
    }
    $declarationText = (@('$script:lastLaunchKind', '$script:lastLaunchNonce', '$script:runId', '$script:finishOnlyHold', '$script:abyssErrorStreak',
            '$script:customResumePending', '$script:customResumeNonce', '$script:abyssPartyRetryEnabled') | ForEach-Object { '{0}={1}' -f $_, $declarations[$_] }) -join ' '
    Assert-Case 'S7 최상위 선언 8개(기본값 - 재입장 이어받기 플래그는 이 빌드에서 꺼짐)' $declarationText `
        "`$script:lastLaunchKind='none' `$script:lastLaunchNonce='' `$script:runId='' `$script:finishOnlyHold=`$null `$script:abyssErrorStreak=0 `$script:customResumePending=`$false `$script:customResumeNonce='' `$script:abyssPartyRetryEnabled=`$false"
    # S5 env 무리 행동: Clear-HandoffEnv = 3개만(RUN_ID·커스텀 env 그대로) · Clear-CustomEnv 가 진행 세대 env 도 지움(명세 5절 A3)
    foreach ($envName in $ALL_ENV_NAMES) { [Environment]::SetEnvironmentVariable($envName, $STALE_VALUE, 'Process') }
    Clear-HandoffEnv
    $afterHandoff = Get-HandoffEnvSnapshot
    Clear-CustomEnv
    $afterCustom = Get-HandoffEnvSnapshot
    Assert-Case 'S5 Clear-HandoffEnv → 3개만 빈 값 (그 밖 env 그대로) · Clear-CustomEnv → 커스텀 env(GENERATION 포함) 빈 값 · RUN_ID 그대로' `
        ('{0} · {1} · {2} · {3}' -f (Format-HandoffEnv $afterHandoff), @($ALL_ENV_NAMES | Where-Object { ($HANDOFF_ENV_NAMES -notcontains $_) -and ($afterHandoff[$_] -cne $STALE_VALUE) }).Count,
            (Format-EnvValues $afterCustom $CUSTOM_ENV_NAMES), $afterCustom['HONEYNOGI_RUN_ID']) `
        ('|| · 0 · {0} · {1}' -f ('|' * ($CUSTOM_ENV_NAMES.Count - 1)), $STALE_VALUE)
    # S6 마커 소유자 JSON 하나의 직렬화: 마커(New-CustomMarkerOwnerJson)가 owner 계산·직렬화 헬퍼를 거침 · 커스텀 기동의 OWNER 도 그 함수
    $markerJsonCode = Remove-SourceComments -Text $guiFunctionTexts['New-CustomMarkerOwnerJson']
    Assert-Case 'S6 New-CustomMarkerOwnerJson = ConvertTo-CustomMarkerOwnerJson(Get-CustomCanonicalOwner) 한 줄 · 직렬화 함수 호출 소유자 = 마커·마무리 실행 조립' `
        ('{0} · {1}' -f [int]($markerJsonCode.Contains('return (ConvertTo-CustomMarkerOwnerJson -Owner (Get-CustomCanonicalOwner -Context $Context))')), (Get-GuiCallOwners 'ConvertTo-CustomMarkerOwnerJson')) `
        '1 · 2|Get-FinishOnlyCustomEnv,New-CustomMarkerOwnerJson'
}

# ===== 단계 2.6 하니스 - 종료 처리의 완료 기록(handoff) =====
function Get-NonceLabel {
    param([string]$Nonce)
    if ($NONCE_LABELS.ContainsKey($Nonce)) { return $NONCE_LABELS[$Nonce] }
    return $Nonce
}

function Lock-JournalLock {
    # 다른 기록 주체가 저장 잠금을 쥔 상태 - abyss_handoff.lock 을 만들어 쥡니다(닫으면 지워짐 - 저장소 잠금과 같은 방식) → 'locked'
    $lockPath = [IO.Path]::ChangeExtension($script:abyssJournalPath, '.lock')
    $script:heldStreams.Add((New-Object IO.FileStream($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)))
}

function Initialize-HandoffRow {
    # 종료 처리 행 준비(구현 명세 ① 2.6) - 새 임시 폴더(로그·완료 기록·마커) · 실행 상태(기본 = 전투 · 어비스 혼자하기 · 비커스텀) · 완료 기록
    # 픽스처(실제 직렬화). 타이머 틱은 Invoke-HandoffTick, 판별 래퍼만 돌리는 행은 Invoke-JudgeRow 가 이어서 씁니다
    param(
        [bool]$Custom = $false, [string]$Category = 'battle', [string]$Content = 'abyss', [string]$Mode = 'solo', [string]$Matching = 'chance',
        $DiskContext = $null, [object[]]$Entries = $null, [object[]]$Applied = @(), [string]$CorruptText = '',
        [string]$LaunchKind = 'none', [string]$LaunchNonce = '', $FinishOnlyHold = $null,
        [bool]$StopRequested = $false, [int]$TargetCycles = 0, [int]$CompletedCycles = 0, $TargetTime = $null,
        [int]$StepFailures = 0, [bool]$RecoveryPending = $false, [string]$RunId = 'run-H', [int]$PreparedStreak = 0,
        [int]$AbyssErrorStreak = 0, [string]$DecisionMode = 'record'
    )
    Initialize-JournalRow
    $script:customAbyssMarkerFile = $script:customMarkerFile   # 대기열 반영이 섹션으로 고르는 어비스 마커 = 이 행의 마커
    $script:mainCategory = $Category
    Set-RadioModel -Content $Content -Mode $Mode -Matching $Matching
    $script:customActive = $Custom
    $script:customConfigSection = $(if ($Custom) { $ABYSS_SECTION } else { 'customRepeat' })
    $script:diskContext = $DiskContext
    $script:customRestart = $false
    $script:customRecoveryPending = $RecoveryPending
    $script:customMarkerIgnore = $false
    $script:customPrevItem = ''
    $script:customErrorStreak = 1
    $script:completedCycles = $CompletedCycles
    $script:targetCycles = $TargetCycles
    $script:targetTime = $TargetTime
    $script:stopRequested = $StopRequested
    $script:runId = $RunId
    $script:lastLaunchKind = $LaunchKind
    $script:lastLaunchNonce = $LaunchNonce
    $script:finishOnlyHold = $FinishOnlyHold
    $script:abyssErrorStreak = $AbyssErrorStreak
    $script:preparedStreak = $PreparedStreak
    $script:stepFailures = $StepFailures
    $script:resetResult = $true
    $script:decisionMode = $DecisionMode
    $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG   # 재개 기능 플래그 = GUI 원문 값(켜진 빌드 행은 이 뒤에서 잠시 참)
    $script:running = $true
    $script:lastWorkerDoneReason = ''
    $lblStatus.Text = ''
    $lblStatus.ForeColor = $null
    foreach ($envName in $ALL_ENV_NAMES) { if ($envName -ne 'HONEYNOGI_RUN_ID') { [Environment]::SetEnvironmentVariable($envName, $null, 'Process') } }
    if ($null -ne $Entries) { Write-FixtureJournal -Path $script:abyssJournalPath -Entries $Entries -Applied $Applied }
    if ($CorruptText) {
        [IO.File]::WriteAllText($script:abyssJournalPath, $CorruptText, $UTF8_BOM)
        [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $CorruptText, $UTF8_BOM)
    }
}

function Invoke-HandoffTick {
    # 타이머 틱 1번 - 워커 로그(처음 줄 + [완료] 사유 줄)를 새로 쓰고 끝난 모의 워커로 실제 종료 처리를 돌립니다. 같은 행에서 이어 부르면
    # 앞 틱이 남긴 상태(기동 종류·보류·완료 기록·디스크 컨텍스트)로 다음 틱이 돕니다(마무리 실행 완주). 감시 횟수는 틱마다 0 부터.
    # 주입은 이 틱에만 - 저장 전 갈고리(-PreUpdateHook 을 -PreUpdateAt 번째 저장 직전에) · 진행 초기화 예외(-ResetThrows)는 끝에서 되돌립니다
    param([int]$ExitCode, [string]$Reason = '', [hashtable]$Plan = @{}, [switch]$HoldLock, [switch]$HoldMainRead, [switch]$HoldMainNone,
        [int]$UpdateThrowAt = 0, $UpdateTagAt = $null, $ResolveOverride = $null, [string]$StartFailure = '', [string]$GuiLogThrowMatch = '',
        [int]$PreUpdateAt = 0, [scriptblock]$PreUpdateHook = $null, [switch]$ResetThrows)
    Unlock-LogFiles
    $script:events.Clear()
    $script:launches.Clear()
    foreach ($counterName in @('stepCalls', 'journalReads', 'journalUpdates', 'contextReads', 'markerClears', 'resolveCalls', 'randomViews')) {
        Set-Variable -Scope Script -Name $counterName -Value 0
    }
    $script:updateThrowAt = $UpdateThrowAt
    $script:updateTagAt = $UpdateTagAt
    $script:preUpdateAt = $PreUpdateAt
    $script:preUpdateHook = $PreUpdateHook
    $script:resetThrows = [bool]$ResetThrows
    $script:resolveOverride = $ResolveOverride
    $script:startProcessFailure = $StartFailure
    $script:guiLogThrowMatch = $GuiLogThrowMatch
    $tickLines = @('12:00:00 [어비스] 클리어 문구(화면을 터치) 감지')
    if ($Reason) { $tickLines += ('12:00:05 [완료] ' + $Reason) }
    Write-NewLogFile -Path $script:workerLog -Lines $tickLines
    if ([IO.File]::Exists($script:workerRecoveryLog)) { [IO.File]::Delete($script:workerRecoveryLog) }
    $script:logOffset = [long]0
    $script:recoveryLogOffset = [long]0
    $stateBefore = Get-FolderState -Folder $script:rowFolder
    if ($HoldLock) { Lock-JournalLock }
    if ($HoldMainRead) { $script:heldStreams.Add([IO.File]::Open($script:abyssJournalPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)) }
    if ($HoldMainNone) { $script:heldStreams.Add([IO.File]::Open($script:abyssJournalPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)) }
    $script:worker = New-MockWorker -ExitCode $ExitCode -Plan $Plan
    $thrown = ''
    try {
        $null = & $timerTick
    } catch {
        $thrown = $_.Exception.Message
    } finally {
        Unlock-LogFiles
        $script:updateThrowAt = 0
        $script:updateTagAt = $null
        $script:preUpdateAt = 0
        $script:preUpdateHook = $null
        $script:resetThrows = $false
        $script:resolveOverride = $null
        $script:startProcessFailure = ''
        $script:guiLogThrowMatch = ''
    }
    $colorName = $(if ($null -eq $lblStatus.ForeColor) { '색 그대로' } else { [string]$lblStatus.ForeColor.Name })
    return [pscustomobject]@{
        Events = @($script:events)
        Flow = ((@($script:events) | Where-Object { -not $_.StartsWith('line|') }) -join ' / ')
        Launches = $script:launches.Count
        LaunchEnv = $(if ($script:launches.Count -gt 0) { $script:launches[0] } else { @{} })
        Kind = [string]$script:lastLaunchKind
        Nonce = (Get-NonceLabel ([string]$script:lastLaunchNonce))
        Hold = $script:finishOnlyHold
        Thrown = $thrown
        Color = $colorName
        StatusText = [string]$lblStatus.Text
        Completed = $script:completedCycles
        PreparedStreak = $script:preparedStreak
        AbyssErrorStreak = $script:abyssErrorStreak
        CustomErrorStreak = $script:customErrorStreak
        PrevItem = [string]$script:customPrevItem
        RecoveryPending = [bool]$script:customRecoveryPending
        Steps = $script:stepCalls
        Reads = $script:journalReads
        Updates = $script:journalUpdates
        ContextReads = $script:contextReads
        MarkerClears = $script:markerClears
        Resolves = $script:resolveCalls
        Journal = (Read-FixtureJournal -Path $script:abyssJournalPath)
        StateUnchanged = [int]($stateBefore -ceq (Get-FolderState -Folder $script:rowFolder))
        Disk = $(if ($null -eq $script:diskContext) { '(없음)' } else { '{0}/{1}' -f $script:diskContext.Lap, $script:diskContext.Index })
    }
}

function Get-EntryText {
    # 완료 기록 항목 '단계/launchState/적용(1·0)' (항목 없음 '(없음)', 파일 없음·손상 '(파일 없음)')
    param($Journal, [string]$Nonce)
    if ($null -eq $Journal) { return '(파일 없음)' }
    $appliedNonces = @(@($Journal.applied) | ForEach-Object { [string]$_ })
    foreach ($entry in @($Journal.entries)) {
        if ([string]$entry.nonce -eq $Nonce) { return ('{0}/{1}/{2}' -f $entry.stage, $entry.launchState, [int]($appliedNonces -contains $Nonce)) }
    }
    return '(없음)'
}

function Get-QueueText {
    # 대기열 '단계:nonce:lap/index:g세대, …' (빈 대기열 '')
    param($Journal)
    if ($null -eq $Journal) { return '(파일 없음)' }
    return ((@($Journal.pending) | ForEach-Object { '{0}:{1}:{2}/{3}:g{4}' -f $_.stage, (Get-NonceLabel ([string]$_.nonce)), $_.owner.lap, $_.owner.index, $_.generation }) -join ',')
}

function Get-NextOwnerText {
    # 항목의 nextOwner - 비커스텀 'run:<id>' / 커스텀 'lap/index' / 없음 '(없음)'
    param($Journal, [string]$Nonce)
    foreach ($entry in @($Journal.entries)) {
        if ([string]$entry.nonce -ne $Nonce) { continue }
        if ($null -eq $entry.nextOwner) { return '(없음)' }
        if ($null -ne $entry.nextOwner.PSObject.Properties['runId']) { return ('run:' + [string]$entry.nextOwner.runId) }
        return ('{0}/{1}' -f $entry.nextOwner.lap, $entry.nextOwner.index)
    }
    return '(항목 없음)'
}

function Add-FixtureEntry {
    # 진행 중인 행에 항목 1개를 덧붙입니다(마무리 실행 워커가 남긴 클리어 기록 모형) - 실제 저장소로(seq·직전본 계약 그대로)
    param($Entry)
    $newEntry = $Entry
    $appendMutator = { param($journal, $change) $journal.entries = @(@($journal.entries) + $newEntry); $change.Changed = $true }.GetNewClosure()
    $appendResult = Invoke-RealUpdateAbyssJournal -Path $script:abyssJournalPath -Mutator $appendMutator
    if ([string]$appendResult.Tag -ne 'changed') { throw ('픽스처 항목 추가 실패: ' + [string]$appendResult.Tag) }
}

function Get-CustomFixture {
    # 커스텀 행 픽스처 - 진행 i(1바퀴 0번) · 재입장한 판 i+1 · 그 owner·5필드 (세대 $H_GENERATION)
    $contextNow = New-AbyssContext -Index 0 -Generation $H_GENERATION
    $contextNext = New-AbyssContext -Index 1 -Generation $H_GENERATION
    $ownerNow = Get-CustomCanonicalOwner -Context $contextNow
    $ownerNext = Get-CustomCanonicalOwner -Context $contextNext
    return @{
        Now = $contextNow; Next = $contextNext; OwnerNow = $ownerNow; OwnerNext = $ownerNext
        FiveNow = (ConvertTo-FiveFieldOwner $ownerNow); FiveNext = (ConvertTo-FiveFieldOwner $ownerNext)
    }
}

# ===== D 재입장 판별 (설계 R1 5.1 D1~D16 · 판별 래퍼 + 순수부, 완료 기록은 실제 파일) =====
function Invoke-JudgeRow {
    # 판별 행 - 준비(Initialize-HandoffRow) → [완료] 사유 → (주입) → 실제 Read-AbyssExitHandoff 1번 → 결과 'Kind/Source/nonce' · 정지 사유 · 잠금 읽기 수
    param([hashtable]$Setup = @{}, [int]$ExitCode = 0, [string]$Reason = '', $Context = $null, [switch]$HoldLock, [switch]$HoldMainNone, [switch]$ReadThrows)
    Initialize-HandoffRow @Setup
    $script:lastWorkerDoneReason = $Reason
    $stateBefore = Get-FolderState -Folder $script:rowFolder
    if ($HoldLock) { Lock-JournalLock }
    if ($HoldMainNone) { $script:heldStreams.Add([IO.File]::Open($script:abyssJournalPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)) }
    $script:readThrows = [bool]$ReadThrows
    try {
        $result = Read-AbyssExitHandoff -ExitCode $ExitCode -Context $Context
    } finally {
        Unlock-LogFiles
        $script:readThrows = $false
    }
    return [pscustomobject]@{
        Text = ('{0}/{1}/{2}' -f $result.Kind, $result.Source, (Get-NonceLabel ([string]$result.Nonce)))
        Reason = [string]$result.Reason
        Reads = $script:journalReads
        Unchanged = [int]($stateBefore -ceq (Get-FolderState -Folder $script:rowFolder))
    }
}

function Test-CaseExitJudge {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $otherRun = [pscustomobject]@{ runId = 'run-other' }
    $reasonA = $IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_A)
    $reasonC = $IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_C)
    $reentered = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_A

    # D1 범위 밖 5실행 · D2 어비스 파티원 - 재입장 항목·표지가 있어도 journal 읽기 0 · none (설계 R1 3.2 '대상')
    $rangeRows = @(
        @{ N = 'D1 던전'; Setup = @{ Content = 'dungeon'; Entries = @($reentered) } }
        @{ N = 'D1 심층'; Setup = @{ Content = 'deep'; Entries = @($reentered) } }
        @{ N = 'D1 사냥터'; Setup = @{ Content = 'hunting'; Entries = @($reentered) } }
        @{ N = 'D1 생활(어비스 라디오 보존)'; Setup = @{ Category = 'life'; Entries = @($reentered) } }
        @{ N = 'D1 기타(어비스 라디오 보존)'; Setup = @{ Category = 'etc'; Entries = @($reentered) } }
        @{ N = 'D2 어비스 파티원'; Setup = @{ Mode = 'party'; Matching = 'member'; Entries = @($reentered) } }
    )
    foreach ($rangeRow in $rangeRows) {
        $row = Invoke-JudgeRow -Setup $rangeRow.Setup -Reason $reasonA
        Assert-Case ('{0} + 재입장 항목·표지 → none · journal 읽기 0' -f $rangeRow.N) ('{0} · {1}' -f $row.Text, $row.Reads) 'none// · 0'
    }
    # 코드 0·11 밖(10·4·1)은 판별하지 않음 - 읽기 0
    $codeTexts = foreach ($code in @(10, 4, 1)) { $row = Invoke-JudgeRow -Setup @{ Entries = @($reentered) } -ExitCode $code -Reason $reasonA; '{0}:{1}·{2}' -f $code, $row.Text, $row.Reads }
    Assert-Case 'D 코드 10·4·1 + 재입장 항목·표지 → none · 읽기 0 (판별 대상 = 코드 0·11)' ($codeTexts -join ' / ') '10:none//·0 / 4:none//·0 / 1:none//·0'

    # D3 비커스텀 · 이 실행의 미적용 reentered → inside-handoff(journal) · 코드 11 도 같음
    $row = Invoke-JudgeRow -Setup @{ Entries = @($reentered) } -Reason $READY_REASON
    $row11 = Invoke-JudgeRow -Setup @{ Entries = @($reentered) } -ExitCode 11 -Reason $reasonA
    Assert-Case 'D3 미적용 reentered(이 실행 id) → inside-handoff/journal · 읽기 1 · 파일 그대로 || 코드 11 같음' `
        ('{0} · {1} · {2} || {3}' -f $row.Text, $row.Reads, $row.Unchanged, $row11.Text) 'inside-handoff/journal/NA · 1 · 1 || inside-handoff/journal/NA'
    # D3′ 다른 실행의 reentered → none / D3″ 적용된 reentered → none / D3‴ 둘 → 가장 최근
    $other = New-FixtureEntry -Stage 'reentered' -Owner $otherRun -Nonce $NONCE_B
    $row = Invoke-JudgeRow -Setup @{ Entries = @($other) } -Reason $READY_REASON
    $rowApplied = Invoke-JudgeRow -Setup @{ Entries = @($reentered); Applied = @($NONCE_A) } -Reason $READY_REASON
    $newer = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_B
    $rowTwo = Invoke-JudgeRow -Setup @{ Entries = @($reentered, $newer) } -Reason $READY_REASON
    Assert-Case "D3′ 다른 실행 id 의 reentered → none · D3″ 적용된 reentered → none · D3‴ 미적용 reentered 둘 → 뒤쪽(최근)" `
        ('{0} · {1} · {2}' -f $row.Text, $rowApplied.Text, $rowTwo.Text) 'none// · none// · inside-handoff/journal/NB'

    # D4·D5 retry-clicked / retry-attempt + 표지 nonce 일치 → inside-handoff(log)
    $clicked = New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -Nonce $NONCE_A
    $attempt = New-FixtureEntry -Stage 'retry-attempt' -Owner $runOwner -Nonce $NONCE_A
    $rowClicked = Invoke-JudgeRow -Setup @{ Entries = @($clicked) } -Reason $reasonA
    $rowAttempt = Invoke-JudgeRow -Setup @{ Entries = @($attempt) } -Reason $reasonA
    Assert-Case 'D4 retry-clicked + 표지 nonce 일치 → inside-handoff/log · D5 retry-attempt + 일치 → inside-handoff/log' `
        ('{0} · {1}' -f $rowClicked.Text, $rowAttempt.Text) 'inside-handoff/log/NA · inside-handoff/log/NA'
    # D6 retry-attempt + 선택 화면 복귀 문구 → none · D7 retry-clicked + 사유 없음 → none(남는 틈 - 설계 R1 9절 미결 2)
    $rowReady = Invoke-JudgeRow -Setup @{ Entries = @($attempt) } -Reason $READY_REASON
    $rowEmpty = Invoke-JudgeRow -Setup @{ Entries = @($clicked) } -Reason ''
    Assert-Case 'D6 retry-attempt + 선택 화면 복귀 문구 → none · D7 retry-clicked + 사유 없음 → none' ('{0} · {1}' -f $rowReady.Text, $rowEmpty.Text) 'none// · none//'
    # D8 표지 nonce 와 맞는 항목 없음 · D9 표지 nonce 가 적용된 항목 · D9′ 같은 owner 의 cleared · D9″ 다른 실행의 retry-clicked → journal-error + 꼬리
    $noMatchReason = $EXIT_NO_MATCH + $STOP_TAIL
    $rowNone = Invoke-JudgeRow -Setup @{ Entries = @($clicked) } -Reason $reasonC
    $rowAppliedMark = Invoke-JudgeRow -Setup @{ Entries = @($clicked); Applied = @($NONCE_A) } -Reason $reasonA
    $clearedA = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_A
    $rowCleared = Invoke-JudgeRow -Setup @{ Entries = @($clearedA) } -Reason $reasonA
    $otherClicked = New-FixtureEntry -Stage 'retry-clicked' -Owner $otherRun -Nonce $NONCE_A
    $rowOther = Invoke-JudgeRow -Setup @{ Entries = @($otherClicked) } -Reason $reasonA
    Assert-Case 'D8 nonce 다름 · D9 적용됨 · D9′ 단계 cleared · D9″ 다른 실행 → journal-error · 사유 = 일치 항목 없음 + 재입장 꼬리' `
        ((@($rowNone, $rowAppliedMark, $rowCleared, $rowOther) | ForEach-Object { '{0}|{1}' -f $_.Text, [int]($_.Reason -ceq $noMatchReason) }) -join ' · ') `
        'journal-error//|1 · journal-error//|1 · journal-error//|1 · journal-error//|1'
    # D10 locked · D11 corrupt · D11′ io-failed(본 파일을 공유 없이 쥠 - 설계 표 밖 태그, 명세와 다르게 한 곳) · 예외 → journal-error, 파일 그대로.
    #     꼬리는 사유에 표지가 있을 때만(설계 R1 3.5 ⓑ). 비커스텀 문구의 '못 한 일' 은 기동뿐 '(기록 보존)'(단계 2.6 구현 리뷰가 넘긴 정리 - 2.8:
    #     계상은 공통 구간이 이미 했고 진행 전진·완료 마커가 없음) - 커스텀(D10c·D11c)은 '진행 전진·기동 … (기록·마커 보존)' 그대로
    $rowLocked = Invoke-JudgeRow -Setup @{ Entries = @($reentered) } -Reason $READY_REASON -HoldLock
    $rowLockedMark = Invoke-JudgeRow -Setup @{ Entries = @($reentered) } -Reason $reasonA -HoldLock
    $rowCorrupt = Invoke-JudgeRow -Setup @{ CorruptText = '{ "version": 1, "seq": ' } -Reason $READY_REASON
    $rowIo = Invoke-JudgeRow -Setup @{ Entries = @($reentered) } -Reason $READY_REASON -HoldMainNone
    $rowThrow = Invoke-JudgeRow -Setup @{ Entries = @($reentered) } -Reason $reasonA -ReadThrows
    Assert-Case 'D10 비커스텀 locked → 사용 중 문구(기동 · 기록 보존) + 잠금 파일 안내 · 표지 있으면 + 꼬리 · 파일 그대로' `
        ('{0}|{1}|{2} · {3}|{4}' -f $rowLocked.Text, $rowLocked.Reason, $rowLocked.Unchanged, $rowLockedMark.Text, $rowLockedMark.Reason) `
        ('journal-error//|{0}|1 · journal-error//|{0}{1}' -f $EXIT_LOCKED_PLAIN, $STOP_TAIL)
    Assert-Case 'D11 corrupt → 손상 문구 + 파일 위치 안내 · 파일 그대로(손상 증거 이동 0) / D11′ 비커스텀 io-failed → 읽기 실패 문구(기동 · 기록 보존) / 예외 → 같은 문구 + 예외 + 꼬리' `
        ('{0}|{1}|{2} / {3}|{4} / {5}|{6}' -f $rowCorrupt.Text, $rowCorrupt.Reason, $rowCorrupt.Unchanged, $rowIo.Text, $rowIo.Reason, $rowThrow.Text, $rowThrow.Reason) `
        ('journal-error//|{0}|1 / journal-error//|{1} / journal-error//|{1} (예외: {2}){3}' -f $STOP_CORRUPT, $EXIT_READ_FAIL_PLAIN, $INJECTED_READ_EXCEPTION, $STOP_TAIL)
    # D12 cleared(decision exit·other) → none
    $clearedOther = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_B
    $clearedOther.decision = 'other'
    $row = Invoke-JudgeRow -Setup @{ Entries = @($clearedA, $clearedOther) } -Reason $READY_REASON
    Assert-Case 'D12 미적용 cleared(decision exit·other) → none (재입장이 아님 - 일반 끝 처리가 소비)' $row.Text 'none//'

    # D13 커스텀 - 항목 owner = 진행 전 컨텍스트 i → inside-handoff / 진행 뒤 컨텍스트(i+1)로 읽으면 none (변이 R1-M13)
    $fixture = Get-CustomFixture
    $customEntry = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    $rowNow = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($customEntry) } -Reason $READY_REASON -Context $fixture.Now
    $rowNext = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($customEntry) } -Reason $READY_REASON -Context $fixture.Next
    $otherGeneration = New-AbyssContext -Index 0 -Generation ($H_GENERATION + 1)
    $rowGeneration = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($customEntry) } -Reason $READY_REASON -Context $otherGeneration
    Assert-Case 'D13 커스텀 · 진행 전 컨텍스트 i → inside-handoff/journal · 진행 뒤(i+1) → none · 세대 다름 → none' `
        ('{0} · {1} · {2}' -f $rowNow.Text, $rowNext.Text, $rowGeneration.Text) 'inside-handoff/journal/NA · none// · none//'
    # D14 마무리 실행 기동의 선택 화면 복귀 - 재입장 항목은 이미 적용·launched, 마무리 실행 워커의 cleared(i+1) → none (완주 처리가 받음)
    $appliedHandoff = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $finishCleared = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_B
    $rowStepFailed = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($appliedHandoff, $finishCleared); Applied = @($NONCE_A) } -Reason $READY_REASON -Context $fixture.Now
    $rowStepped = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($appliedHandoff, $finishCleared); Applied = @($NONCE_A) } -Reason $READY_REASON -Context $fixture.Next
    Assert-Case 'D14 마무리 실행 기동의 선택 화면 복귀(진행 저장 실패 보류 - 디스크 i · 그 밖 보류 - 디스크 i+1) → none · none' `
        ('{0} · {1}' -f $rowStepFailed.Text, $rowStepped.Text) 'none// · none//'
    # D15·D16 커스텀 · 진행 위치를 못 읽음($null) - 표지 있으면 journal-error(+ 꼬리), 없으면 none. 둘 다 journal 읽기 0
    $rowMarked = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($customEntry) } -Reason $reasonA -Context $null
    $rowPlain = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($customEntry) } -Reason $READY_REASON -Context $null
    Assert-Case 'D15 커스텀 위치 없음 + 표지 → journal-error · 위치 못 읽음 문구 + 꼬리 · 읽기 0 || D16 표지 없음 → none · 읽기 0' `
        ('{0}|{1}|{2} || {3}|{4}' -f $rowMarked.Text, $rowMarked.Reason, $rowMarked.Reads, $rowPlain.Text, $rowPlain.Reads) `
        ('journal-error//|{0}{1}|0 || none//|0' -f $EXIT_NO_CONTEXT, $STOP_TAIL)
    # D10c·D11c 커스텀 변형(단계 2.6 구현 검증 - 명세 대조 P3-1 · 설계 R1 5.2 H13·H14 '둘 다'): 진행 위치를 읽은 커스텀도 읽기 실패면 journal-error.
    #     none 으로 흘리면 타이머가 진행을 먼저 전진(Step)하고 소비에서야 멈춰, Step 전 owner i 로 이어받을 근거(다음 시작의 S0·S3)를 잃습니다(설계 R1 3.3)
    $rowLockedC = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($customEntry) } -Reason $READY_REASON -Context $fixture.Now -HoldLock
    $rowCorruptC = Invoke-JudgeRow -Setup @{ Custom = $true; CorruptText = '{ "version": 1, "seq": ' } -Reason $READY_REASON -Context $fixture.Now
    $rowIoC = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($customEntry) } -Reason $READY_REASON -Context $fixture.Now -HoldMainNone
    $rowThrowC = Invoke-JudgeRow -Setup @{ Custom = $true; Entries = @($customEntry) } -Reason $reasonA -Context $fixture.Now -ReadThrows
    Assert-Case 'D10c·D11c 커스텀(진행 위치 있음) locked / corrupt / io-failed / 예외 + 표지 → journal-error · 그 문구 · 읽기 1 · 파일 그대로' `
        ((@($rowLockedC, $rowCorruptC, $rowIoC, $rowThrowC) | ForEach-Object { '{0}|{1}|{2}|{3}' -f $_.Text, $_.Reason, $_.Reads, $_.Unchanged }) -join ' / ') `
        ((@(('journal-error//|{0}|1|1' -f $EXIT_LOCKED_ADVANCE), ('journal-error//|{0}|1|1' -f $STOP_CORRUPT), ('journal-error//|{0}|1|1' -f $EXIT_READ_FAIL),
                ('journal-error//|{0} (예외: {1}){2}|1|1' -f $EXIT_READ_FAIL, $INJECTED_READ_EXCEPTION, $STOP_TAIL))) -join ' / ')
}

# ===== HX 행동 - 비커스텀 (설계 R1 5.2 H1~H15·H38·H39·H42) =====
function Test-CaseExitPlain {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $reasonA = $IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_A)
    $pastTarget = [datetime]::Now.AddHours(-1)
    $futureTarget = [datetime]::Now.AddHours(1)
    $pastText = $pastTarget.ToString('HH:mm')
    $reentered = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_A

    # H1 재입장(journal) 코드 0 · 시간 지정 아님 → 계상 1 · 필수 기록(적용·nextOwner 확정·launched) · 다음 판 기동(후보 = 이 항목) · 재입장 오류 연속 0
    Initialize-HandoffRow -Entries @($reentered) -AbyssErrorStreak 2
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H1 흐름: 완료 줄 → 다음 판 기동 → 시작 줄 · 정지 0 · 예외 0' ('{0} · [{1}]' -f $row.Flow, $row.Thrown) 'gui|=== 1회차 완료 === / launch|powershell.exe / gui|=== 2회차 시작 === · []'
    Assert-Case 'H1 기동 종류 next · HANDOFF_NONCE = 판별 항목 · RESUME·FINISH_ONLY 빈 값 · LAST_RUN 빈 값' `
        ('{0}/{1} · [{2}] · [{3}]' -f $row.Kind, $row.Nonce, (Format-HandoffEnv $row.LaunchEnv), $row.LaunchEnv['HONEYNOGI_LAST_RUN']) ('next/NA · [{0}||] · []' -f $NONCE_A)
    Assert-Case 'H1 필수 기록: 항목 reentered/launched/적용 · nextOwner = 이번 실행 id · 계상 1 · 재입장 오류 연속 2 → 0 · 읽기 1·저장 2(필수 기록 + 후보 고르기)·고르기 1' `
        ('{0} · {1} · {2} · {3} · {4}/{5}/{6}' -f (Get-EntryText $row.Journal $NONCE_A), (Get-NextOwnerText $row.Journal $NONCE_A), $row.Completed, $row.AbyssErrorStreak, $row.Reads, $row.Updates, $row.Resolves) `
        'reentered/launched/1 · run:run-H · 1 · 0 · 1/2/1'
    # H1′ 필수 기록이 일반 끝 처리를 겸함(설계 R1 3.4 순서 2) - 같은 실행의 다른 미적용 '클리어 이상' 항목도 적용, 다른 실행·entered 는 그대로
    $sameRunCleared = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_B
    $otherRunCleared = New-FixtureEntry -Stage 'cleared' -Owner ([pscustomobject]@{ runId = 'run-other' }) -Nonce $NONCE_C
    $sameRunEntered = New-FixtureEntry -Stage 'entered' -Owner $runOwner -Nonce $NONCE_D
    Initialize-HandoffRow -Entries @($sameRunCleared, $otherRunCleared, $sameRunEntered, $reentered)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case "H1′ 필수 기록 = 이 항목 + 같은 실행의 미적용 '클리어 이상'(NB) 적용 · 다른 실행(NC)·entered(ND) 그대로 · 다음 판 기동 NA" `
        (((@($NONCE_A, $NONCE_B, $NONCE_C, $NONCE_D) | ForEach-Object { Get-EntryText $row.Journal $_ }) -join ' · ') + (' · {0}/{1}' -f $row.Kind, $row.Nonce)) `
        'reentered/launched/1 · cleared/pending/1 · cleared/pending/0 · entered/pending/0 · next/NA'

    # H2 횟수 지정 미달(2회 중 1회째) → 다음 판 기동 · 그 워커의 LAST_RUN = 회차 시작 식(2회째 = 마지막 판 '1')
    Initialize-HandoffRow -Entries @($reentered) -TargetCycles 2
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H2 횟수 지정 미달 → next · 마지막 판 신호 = 회차 시작 식(1)' ('{0}/{1} · {2} · [{3}]' -f $row.Kind, $row.Nonce, $row.Launches, $row.LaunchEnv['HONEYNOGI_LAST_RUN']) 'next/NA · 1 · [1]'
    # H3 코드 11 · 지정 시각 전 → 완료 줄 꼬리 · 다음 판 기동 · 안내 없음 / H6 코드 0 · 지정 시각 전 → 다음 판 기동
    Initialize-HandoffRow -Entries @($reentered) -TargetTime $futureTarget
    $row = Invoke-HandoffTick -ExitCode 11 -Reason $reasonA
    Initialize-HandoffRow -Entries @($reentered) -TargetTime $futureTarget
    $row6 = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H3 코드 11 · 지정 시각 전 → (다음 판으로 이어 감) 완료 줄 · next · 안내 없음 || H6 코드 0 · 지정 시각 전 → next' `
        ('{0} · {1}/{2} || {3}/{4}' -f $row.Flow, $row.Kind, $row.Nonce, $row6.Kind, $row6.Nonce) `
        'gui|=== 1회차 완료 (다음 판으로 이어 감) === / launch|powershell.exe / gui|=== 2회차 시작 === · next/NA || next/NA'
    # H4 코드 11 · 지정 시각 뒤 → 이어받음(코드 11 은 시각을 안 봄) + 안내 1줄(다음 회차 판단과 같은 글자) · 다음 판 기동
    Initialize-HandoffRow -Entries @($reentered) -TargetTime $pastTarget
    $row = Invoke-HandoffTick -ExitCode 11 -Reason $reasonA
    Assert-Case 'H4 코드 11 · 지정 시각 뒤 → 안내 1줄 → 다음 판 기동 (마무리 실행 아님)' ('{0} · {1}' -f $row.Flow, $row.Kind) `
        ('gui|=== 1회차 완료 (다음 판으로 이어 감) === / gui|{0} / launch|powershell.exe / gui|=== 2회차 시작 === · next' -f ($CARRY_NOTICE_FORMAT -f $pastText))
    # H5 코드 0 · 지정 시각 뒤 → 마무리 실행(보류 '지정 시간(HH:mm) 도달') · H7 안전 중지 · H8 코드 11 + 안전 중지(시각 뒤 - 안전 중지가 이김) ·
    # H9 지정 횟수 도달 · H42 코드 11 + 지정 횟수 도달 → 각 보류 사유로 마무리 실행 기동 (정지 0 · 시작 줄 없음 · 마무리 실행 상태줄)
    $finishRows = @(
        @{ N = 'H5 코드 0 · 지정 시각 뒤'; Code = 0; Setup = @{ TargetTime = $pastTarget }; Kind = 'time'; Reason = ('지정 시간({0}) 도달' -f $pastText); Done = 1 }
        @{ N = 'H7 코드 0 · 안전 중지'; Code = 0; Setup = @{ StopRequested = $true }; Kind = 'safe-stop'; Reason = '안전 중지'; Done = 1 }
        @{ N = 'H8 코드 11 · 안전 중지 · 지정 시각 뒤'; Code = 11; Setup = @{ StopRequested = $true; TargetTime = $pastTarget }; Kind = 'safe-stop'; Reason = '안전 중지'; Done = 1 }
        @{ N = 'H9 코드 0 · 지정 횟수 도달(2회)'; Code = 0; Setup = @{ TargetCycles = 2; CompletedCycles = 1 }; Kind = 'count'; Reason = '지정 횟수 완료'; Done = 2 }
        @{ N = 'H42 코드 11 · 지정 횟수 도달(2회)'; Code = 11; Setup = @{ TargetCycles = 2; CompletedCycles = 1 }; Kind = 'count'; Reason = '지정 횟수 완료'; Done = 2 }
    )
    foreach ($finishRow in $finishRows) {
        $setup = @{ Entries = @($reentered) } + $finishRow.Setup
        Initialize-HandoffRow @setup
        $row = Invoke-HandoffTick -ExitCode $finishRow.Code -Reason $reasonA
        $doneSuffix = $(if ($finishRow.Code -eq 11) { ' (다음 판으로 이어 감)' } else { '' })
        Assert-Case ('{0} → 마무리 실행 안내 → 기동 1 · 정지 0' -f $finishRow.N) $row.Flow `
            ('gui|=== {0}회차 완료{1} === / gui|{2} / launch|powershell.exe' -f $finishRow.Done, $doneSuffix, ($FINISH_NOTICE_FORMAT -f '[안내]', $finishRow.Reason))
        Assert-Case ('{0} → 기동 종류 finish-only · 보류 Kind·사유·오류 아님·Owner = 이번 실행 id · Snapshot 없음 · env NONCE/FINISH_ONLY/LAST_RUN · 상태줄' -f $finishRow.N) `
            ('{0}/{1} · {2}|{3}|{4}|{5}|{6} · {7}|{8}|{9} · {10}' -f $row.Kind, $row.Nonce, $row.Hold.Kind, $row.Hold.Reason, $row.Hold.IsError, $row.Hold.Owner.runId, [int]($null -eq $row.Hold.Snapshot),
                $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE'], $row.LaunchEnv['HONEYNOGI_FINISH_ONLY'], $row.LaunchEnv['HONEYNOGI_LAST_RUN'], $row.StatusText) `
            ('finish-only/NA · {0}|{1}|False|run-H|1 · {2}|1|1 · {3}회차 마무리 실행 중 - 이 판을 마치면 멈춥니다' -f $finishRow.Kind, $finishRow.Reason, $NONCE_A, ($finishRow.Done + 1))
    }

    # H10 재입장(log - reentered 기록 실패) 코드 0 → stage 보정 + [경고] 1줄 → 다음 판 기동(후보 = 보정된 항목)
    $clicked = New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -Nonce $NONCE_A
    Initialize-HandoffRow -Entries @($clicked)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H10 log 출처 → [경고] 1줄 → 다음 판 기동 · 항목 reentered 로 보정·launched·적용 · HANDOFF_NONCE' `
        ('{0} · {1} · {2}/{3}' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A), $row.Kind, $row.Nonce) `
        ('gui|=== 1회차 완료 === / gui|{0} / launch|powershell.exe / gui|=== 2회차 시작 === · reentered/launched/1 · next/NA' -f $IH_LOG_WARNING)
    # H10′ 보정 저장의 작성자 표지(단계 2.6 구현 리뷰 P2 - 해당 없음 확인): 스키마(dev:858)의 savedBy 는 journal 최상위에만 있고 항목에는 없습니다.
    #      저장소가 GUI 의 모든 저장에 작성자 표지를 적으므로, 필수 기록이 retry-clicked 를 reentered 로 고친 그 저장 뒤 최상위 savedBy = gui(픽스처는
    #      워커가 쓴 worker:1234). 후보 고르기 저장(2 번째) 직전에 본 파일을 찍어 필수 기록 저장 하나의 결과로 봅니다(저장 전 갈고리)
    Initialize-HandoffRow -Entries @($clicked)
    $savedByBefore = [string](Read-FixtureJournal -Path $script:abyssJournalPath).savedBy
    $script:savedBySnapshot = $null
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -PreUpdateAt 2 -PreUpdateHook { $script:savedBySnapshot = Read-FixtureJournal -Path $script:abyssJournalPath }
    $snapshotEntry = @(@($script:savedBySnapshot.entries) | Where-Object { ($null -ne $_) -and ([string]$_.nonce -eq $NONCE_A) })[0]
    Assert-Case 'H10′ 필수 기록(retry-clicked → reentered 보정) 직후 본 파일: 최상위 savedBy worker:1234 → gui · seq 5 → 6 · 항목 단계 reentered · 항목에 savedBy 필드 없음 · 다음 판 기동 1' `
        ('{0} → {1} · {2} · {3} · {4} · {5}' -f $savedByBefore, $script:savedBySnapshot.savedBy, $script:savedBySnapshot.seq, $snapshotEntry.stage,
            [int]($null -ne $snapshotEntry.PSObject.Properties['savedBy']), $row.Launches) 'worker:1234 → gui · 6 · reentered · 0 · 1'
    # H11 log 출처 · 코드 11 + 안전 중지 → 보정·[경고] → 마무리 실행 '안전 중지'
    Initialize-HandoffRow -Entries @($clicked) -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 11 -Reason $reasonA
    Assert-Case 'H11 log 출처 · 코드 11 + 안전 중지 → [경고] → 마무리 실행 안내 → 기동 · 보정' ('{0} · {1} · {2}' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A), $row.Kind) `
        ('gui|=== 1회차 완료 (다음 판으로 이어 감) === / gui|{0} / gui|{1} / launch|powershell.exe · reentered/launched/1 · finish-only' -f $IH_LOG_WARNING, ($FINISH_NOTICE_FORMAT -f '[안내]', '안전 중지'))

    # H12 필수 기록 실패 → 기동 0 · 오류 정지 + 재입장 꼬리 · 계상 1(메모리) · 기록 그대로. 실패 종류: 교체 실패(io-failed - 본 파일을 읽기만
    # 허용하고 쥠) / 사용 중 · 손상(감시 태그 주입) / 판별한 항목이 사라짐(expect-failed 주입) / 예외(감시 예외 주입 - 변이 R1-M12·M16)
    $recordRows = @(
        @{ N = '(가) 교체 실패 io-failed'; Args = @{ HoldMainRead = $true }; Reason = $IH_RECORD_FAIL }
        @{ N = '(나) 사용 중'; Args = @{ UpdateTagAt = @{ At = 1; Tag = 'locked' } }; Reason = $STOP_LOCKED }
        @{ N = '(다) 손상'; Args = @{ UpdateTagAt = @{ At = 1; Tag = 'corrupt' } }; Reason = $STOP_CORRUPT }
        @{ N = '(라) 판별한 항목이 사라짐'; Args = @{ UpdateTagAt = @{ At = 1; Tag = 'expect-failed' } }; Reason = $IH_RECORD_FAIL }
        @{ N = '(마) 예외'; Args = @{ UpdateThrowAt = 1 }; Reason = ($IH_EXCEPTION_FORMAT -f $INJECTED_UPDATE_EXCEPTION) }
    )
    foreach ($recordRow in $recordRows) {
        Initialize-HandoffRow -Entries @($reentered)
        $tickArgs = @{ ExitCode = 0; Reason = $reasonA } + $recordRow.Args
        $row = Invoke-HandoffTick @tickArgs
        Assert-Case ('H12 필수 기록 실패 {0} → 기동 0 · 정지 = 그 문구 + 재입장 꼬리 · 빨강 · 계상 1 · 기록 그대로 · 예외 0' -f $recordRow.N) `
            ('{0} · {1} · {2} · {3} · {4} · [{5}]' -f $row.Launches, $row.Flow, $row.Color, $row.Completed, (Get-EntryText $row.Journal $NONCE_A), $row.Thrown) `
            ('0 · gui|=== 1회차 완료 === / stop|{0}{1}|True · Firebrick · 1 · reentered/pending/0 · []' -f $recordRow.Reason, $STOP_TAIL)
    }
    # H12 (바) 기동 계획이 정해진 뒤의 예외(마무리 실행 안내 줄 - 주입) → catch 의 오류 정지 + 꼬리 뒤 return → 기동 0 (변이 R1-M16 - return 이 없으면
    #     catch 뒤 try 다음 문장의 기동이 돌아 정지 뒤 워커가 뜸. 계획 앞 예외(H12 (마))는 계획이 비어 return 이 없어도 기동하지 않아 이 행이 가름)
    Initialize-HandoffRow -Entries @($reentered) -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -GuiLogThrowMatch '마무리 실행:'
    Assert-Case 'H12 (바) 계획 뒤 예외(마무리 실행 안내 줄) → 오류 정지 + 꼬리 · 빨강 · 기동 0 · 필수 기록은 됨 · 예외 0' `
        ('{0} · {1} · {2} · {3} · [{4}]' -f $row.Launches, $row.Flow, $row.Color, (Get-EntryText $row.Journal $NONCE_A), $row.Thrown) `
        ('0 · gui|=== 1회차 완료 === / gui|{0} / stop|{1}{2}|True · Firebrick · reentered/launched/1 · []' -f
            ($FINISH_NOTICE_FORMAT -f '[안내]', '안전 중지'), ($IH_EXCEPTION_FORMAT -f $INJECTED_GUILOG_EXCEPTION), $STOP_TAIL)
    # H12 (사) 판별한 항목이 필수 기록 직전에 사라짐(다른 기록 주체가 실제 저장소로 지움 - 저장 전 갈고리) → 실제 -Expect 가 거절(expect-failed) → 기동 0 ·
    #     정지 = 재입장 완료 기록 실패 + 꼬리 · 예외 0 (단계 2.6 구현 검증 - 생존 변이 IH-EXPECT: (라)는 태그를 주입해 실제 -Expect 를 거치지 않았고,
    #     -Expect 가 없으면 mutator 가 사라진 항목을 고치려다 예외 → '재입장 처리 중 예외' 로 바뀜)
    Initialize-HandoffRow -Entries @($reentered)
    $dropHook = {
        $dropMutator = { param($journal, $change) $journal.entries = @(); $change.Changed = $true }
        [void](Invoke-RealUpdateAbyssJournal -Path $script:abyssJournalPath -Mutator $dropMutator)
    }
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -PreUpdateAt 1 -PreUpdateHook $dropHook
    Assert-Case 'H12 (사) 필수 기록 직전 항목 사라짐(실제 -Expect) → 기동 0 · 정지 = 재입장 완료 기록 실패 + 꼬리 · 빨강 · 예외 0' `
        ('{0} · {1} · {2} · [{3}]' -f $row.Launches, ((Get-StopEvents $row) -join ' / '), $row.Color, $row.Thrown) ('0 · stop|{0}{1}|True · Firebrick · []' -f $IH_RECORD_FAIL, $STOP_TAIL)
    # H13 판별 읽기 'locked' → 계상 1 · 기동 보류 정지(+ 잠금 파일 안내, 표지 있으면 꼬리) · 기록 그대로 / H14 'corrupt' · 일치 항목 없음.
    #     비커스텀이라 못 한 일은 기동뿐 '(기록 보존)'(단계 2.6 구현 리뷰가 넘긴 정리 - 2.8. 커스텀은 H13c)
    Initialize-HandoffRow -Entries @($reentered)
    $rowLocked = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -HoldLock
    Initialize-HandoffRow -CorruptText 'not json'
    $rowCorrupt = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Initialize-HandoffRow -Entries @($clicked)
    $rowNoMatch = Invoke-HandoffTick -ExitCode 0 -Reason ($IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_C))
    Assert-Case "H13 판별 'locked' + 표지 → 계상 1 · 사용 중(기동 · 기록 보존) + 안내 + 꼬리 · 기동 0 · 파일 그대로" `
        ('{0} · {1} · {2} · {3}' -f $rowLocked.Flow, $rowLocked.Color, $rowLocked.Launches, $rowLocked.StateUnchanged) `
        ('gui|=== 1회차 완료 === / stop|{0}{1}|True · Firebrick · 0 · 1' -f $EXIT_LOCKED_PLAIN, $STOP_TAIL)
    Assert-Case "H14 'corrupt'(표지 없음) → 손상 문구 + 위치 안내(꼬리 없음) · 파일 그대로 || 일치 항목 없음 → 그 문구 + 꼬리" `
        ('{0} · {1} || {2}' -f $rowCorrupt.Flow, $rowCorrupt.StateUnchanged, $rowNoMatch.Flow) `
        ('gui|=== 1회차 완료 === / stop|{0}|True · 1 || gui|=== 1회차 완료 === / stop|{1}{2}|True' -f $STOP_CORRUPT, $EXIT_NO_MATCH, $STOP_TAIL)
    # H15 실행부가 부른 기동의 실패 → 기동 함수의 오류 정지 + 재입장 꼬리 (필수 기록은 이미 됨): 워커 시작 실패 / 기동 후보 고르기 'locked'(주입)
    Initialize-HandoffRow -Entries @($reentered)
    $rowStart = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -StartFailure 'null'
    Initialize-HandoffRow -Entries @($reentered)
    $rowResolve = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -ResolveOverride @{ Status = 'locked'; Nonce = ''; Kind = 'none'; Detail = '' }
    # (후보 고르기 주입 행은 실제 고르기가 파일을 안 건드리므로 항목의 launched 는 필수 기록 자체가 쓴 것 - 설계 R1 3.4 순서 2 'launchState launched')
    Assert-Case 'H15 다음 판 기동의 워커 시작 실패 → [경고] → 오류 정지(워커 시작 실패 + 꼬리) · 필수 기록은 됨 || 후보 고르기 사용 중 → 사용 중 + 안내 + 꼬리 · 기동 0 · 항목 launched(필수 기록이 씀)' `
        ('{0} · {1} || {2} · {3} · {4}' -f $rowStart.Flow, (Get-EntryText $rowStart.Journal $NONCE_A), $rowResolve.Flow, $rowResolve.Launches, (Get-EntryText $rowResolve.Journal $NONCE_A)) `
        ('gui|=== 1회차 완료 === / launch-null|powershell.exe / gui|{0} / stop|{1}{2}|True · reentered/launched/1 || gui|=== 1회차 완료 === / stop|{3}{2}|True · 0 · reentered/launched/1' -f
            $START_FAIL_WARNING, $STOP_START_FAIL, $STOP_TAIL, $STOP_LOCKED)

    # H38 재개(resume) 기동의 재입장 - 이번 기동 nonce = 이 항목 → 필수 기록이 done 으로 닫지 않음(launched 유지) → 다음 판 기동이 같은 항목 (변이 R1-M15)
    $resumed = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    Initialize-HandoffRow -Entries @($resumed) -LaunchKind 'resume' -LaunchNonce $NONCE_A
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H38 재개 기동의 재입장(넘긴 nonce = 이 항목) → 항목 launched 유지·적용 · 다음 판 기동 HANDOFF_NONCE = 같은 항목' `
        ('{0} · {1}/{2} · {3}' -f (Get-EntryText $row.Journal $NONCE_A), $row.Kind, $row.Nonce, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE']) ('reentered/launched/1 · next/NA · {0}' -f $NONCE_A)
    # H38′ 다른 nonce 를 넘긴 기동(앞 판 항목 NB)의 재입장 → 넘긴 항목은 done, 이 항목은 launched (dev:883 '다를 때만 done')
    $passed = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_B
    Initialize-HandoffRow -Entries @($passed, $reentered) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case "H38′ 넘긴 nonce(NB) ≠ 이 항목(NA) → NB done · NA launched·적용 · 다음 판 기동 = NA" `
        ('{0} · {1} · {2}/{3}' -f (Get-EntryText $row.Journal $NONCE_B), (Get-EntryText $row.Journal $NONCE_A), $row.Kind, $row.Nonce) 'reentered/done/1 · reentered/launched/1 · next/NA'
    # H39 H38 + 안전 중지 → 마무리 실행 · 같은 항목
    Initialize-HandoffRow -Entries @($resumed) -LaunchKind 'resume' -LaunchNonce $NONCE_A -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H39 재개 기동의 재입장 + 안전 중지 → 마무리 실행 · HANDOFF_NONCE = 같은 항목 · launched 유지' `
        ('{0}/{1} · {2}|{3} · {4}' -f $row.Kind, $row.Nonce, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE'], $row.LaunchEnv['HONEYNOGI_FINISH_ONLY'], (Get-EntryText $row.Journal $NONCE_A)) `
        ('finish-only/NA · {0}|1 · reentered/launched/1' -f $NONCE_A)
}

# ===== HX 행동 - 커스텀 (설계 R1 5.2 H16~H21·H41 · 생산자 계약 P3-2 (나)) =====
function Test-CaseExitCustom {
    $fixture = Get-CustomFixture
    $reasonA = $IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_A)
    $handoff = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    $tokenNow = Format-CustomItemToken -Item $ABYSS_ITEMS[0]
    $tokenNext = Format-CustomItemToken -Item $ABYSS_ITEMS[1]
    $tokenAfter = Format-CustomItemToken -Item $ABYSS_ITEMS[2]

    # H16 커스텀 재입장 코드 0 → 커스텀 사슬과 같은 단계(오류 연속 0 · 재시작 해제 · PREV · 전진 · 마커 정리) → 필수 기록 → 다음 판 기동(진행 i+1)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H16 흐름: 항목 완료 줄 → 전진 → 다음 판 기동 → 시작 줄(2/3)' $row.Flow ('gui|[커스텀] {0} 항목 완료 / step / launch|powershell.exe / gui|=== 2회차 시작(2/3) ===' -f $fixture.Now.Position)
    Assert-Case 'H16 기동: next · HANDOFF_NONCE = 판별 항목 · ITEM = i+1 · PREV = i · 진행 1/1 · 오류 연속 0 · 재시작 해제 · 마커 정리 2(실행부 + 회차 준비)' `
        ('{0}/{1} · {2} · {3} · {4} · {5} · {6} · {7}' -f $row.Kind, $row.Nonce, $row.LaunchEnv['HONEYNOGI_CUSTOM_ITEM'], $row.PrevItem, $row.Disk, $row.CustomErrorStreak,
            $row.LaunchEnv['HONEYNOGI_CUSTOM_RESTART'], $row.MarkerClears) `
        ('next/NA · {0} · {1} · 1/1 · 0 ·  · 2' -f $tokenNext, $tokenNow)
    Assert-Case 'H16 필수 기록: 항목 reentered/launched/적용 · nextOwner 그대로(전진 뒤 위치와 같음 - [경고] 0) · 전진 1' `
        ('{0} · {1} · {2} · {3}' -f (Get-EntryText $row.Journal $NONCE_A), (Get-NextOwnerText $row.Journal $NONCE_A), [int]($row.Events -contains ('gui|' + $IH_REPLACED_WARNING)), $row.Steps) `
        'reentered/launched/1 · 1/1 · 0 · 1'
    # H16′ 기록의 nextOwner 가 전진 뒤 위치와 다름 → GUI 값으로 고침 + [경고] 1줄 (dev:847 '불일치 → GUI 값 + [경고]')
    $wrongNext = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner (ConvertTo-FiveFieldOwner (Get-CustomCanonicalOwner -Context (New-AbyssContext -Index 2 -Generation $H_GENERATION))) `
        -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($wrongNext)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H16′ 기록 nextOwner(1/2) ≠ 전진 뒤 위치(1/1) → [경고] 1 · nextOwner = 1/1 · 다음 판 기동이 그 항목을 고름' `
        ('{0} · {1} · {2}/{3}' -f [int]($row.Events -contains ('gui|' + $IH_REPLACED_WARNING)), (Get-NextOwnerText $row.Journal $NONCE_A), $row.Kind, $row.Nonce) '1 · 1/1 · next/NA'
    # H21 커스텀 코드 11 → 0 과 같음
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff)
    $row = Invoke-HandoffTick -ExitCode 11 -Reason $reasonA
    Assert-Case 'H21 커스텀 코드 11 → 코드 0 과 같은 흐름·기동' ('{0} · {1}/{2}' -f $row.Flow, $row.Kind, $row.Nonce) `
        ('gui|[커스텀] {0} 항목 완료 / step / launch|powershell.exe / gui|=== 2회차 시작(2/3) === · next/NA' -f $fixture.Now.Position)

    # H17 커스텀 안전 중지 → 전진 뒤 마무리 실행 '안전 중지' · 보류 Owner = i+1 + 세대 · Position = 전진 뒤 위치 · Snapshot = 진행 전 컨텍스트
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H17 커스텀 안전 중지 → 전진 → 마무리 실행 안내 → 기동 · 마무리 실행 기동은 디스크 위치를 읽지 않음(읽기 2 = 완료 줄 + 전진 뒤 위치)' `
        ('{0} · {1}' -f $row.Flow, $row.ContextReads) ('gui|[커스텀] {0} 항목 완료 / step / gui|{1} / launch|powershell.exe · 2' -f $fixture.Now.Position, ($FINISH_NOTICE_FORMAT -f '[안내]', '안전 중지'))
    Assert-Case 'H17 보류: safe-stop · Owner = i+1 5필드 + generation · Position = 전진 뒤 위치 · Snapshot = 진행 전 컨텍스트(같은 객체)' `
        ('{0}|{1}|{2}|{3}/{4}/{5} · {6} · {7}' -f $row.Hold.Kind, $row.Hold.Reason, $row.Hold.IsError, $row.Hold.Owner.lap, $row.Hold.Owner.index, $row.Hold.Owner.generation, $row.Hold.Position,
            [int]([object]::ReferenceEquals($row.Hold.Snapshot, $fixture.Now))) `
        ('safe-stop|안전 중지|False|1/1/{0} · {1} · 1' -f $H_GENERATION, $fixture.Next.Position)

    # H18 커스텀 진행 저장 실패 → 즉시 정지 대신 대기열 inside-handoff(owner = 끝난 판 i) → 마무리 실행(보류 step-failed, 오류) · 마커 정리 0 ·
    # 생산자 계약(P3-2 (나)): 실행부가 만든 실제 보류로 기동까지 - OWNER(version 3, Read-CustomMarkerOwner 유효)·GENERATION·HANDOFF_NONCE(판별 항목)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H18 커스텀 진행 저장 실패 → [경고] 마무리 실행 안내 → 기동 · 정지 0 · 진행 1/0 그대로 · 마커 정리 0' `
        ('{0} · {1} · {2}' -f $row.Flow, $row.Disk, $row.MarkerClears) ('gui|[커스텀] {0} 항목 완료 / step / gui|{1} / launch|powershell.exe · 1/0 · 0' -f $fixture.Now.Position, ($FINISH_NOTICE_FORMAT -f '[경고]', '커스텀 진행 기록 저장 실패'))
    Assert-Case 'H18 대기열 = inside-handoff(판별 항목 nonce · owner 1/0 · 세대) · 항목 reentered/launched/적용 · 저장 3(대기열 + 필수 기록 + 후보 고르기)' `
        ('{0} · {1} · {2}' -f (Get-QueueText $row.Journal), (Get-EntryText $row.Journal $NONCE_A), $row.Updates) ('inside-handoff:NA:1/0:g{0} · reentered/launched/1 · 3' -f $H_GENERATION)
    Assert-Case 'H18 보류: step-failed · 커스텀 진행 기록 저장 실패 · 오류 · Owner = 기록 nextOwner 5필드 + 그 항목 generation · Position = 진행 전 목록 기준 i+1' `
        ('{0}|{1}|{2}|{3}|{4}/{5}|{6} · {7}' -f $row.Hold.Kind, $row.Hold.Reason, $row.Hold.IsError, ($row.Hold.Owner.fingerprint -ceq $fixture.OwnerNext.fingerprint), $row.Hold.Owner.index,
            ($row.Hold.Owner.item -ceq $tokenNext), $row.Hold.Owner.generation, $row.Hold.Position) `
        ('step-failed|커스텀 진행 기록 저장 실패|True|True|1/True|{0} · {1}' -f $H_GENERATION, $fixture.Next.Position)
    $ownerProbePath = Join-Path $script:rowFolder 'owner_probe_h18.marker'
    [IO.File]::WriteAllText($ownerProbePath, [string]$row.LaunchEnv['HONEYNOGI_CUSTOM_OWNER'], $UTF8_NO_BOM)
    $ownerRead = Read-CustomMarkerOwner -Path $ownerProbePath
    Assert-Case 'H18 생산자 계약: OWNER = version 3(실제 Read-CustomMarkerOwner 유효 · index 1 · generation 세대) · GENERATION = 세대 · HANDOFF_NONCE = 판별 항목 · ITEM·POSITION·NEXT = i+1·i+1·i+2' `
        ('{0} · {1} · {2} · {3}|{4}|{5}' -f $(if ($null -eq $ownerRead) { '(무효)' } else { '{0}/{1}/{2}' -f $ownerRead.version, $ownerRead.index, $ownerRead.generation }),
            $row.LaunchEnv['HONEYNOGI_CUSTOM_GENERATION'], (Get-NonceLabel ([string]$row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE'])),
            ($row.LaunchEnv['HONEYNOGI_CUSTOM_ITEM'] -ceq $tokenNext), $row.LaunchEnv['HONEYNOGI_CUSTOM_POSITION'], ($row.LaunchEnv['HONEYNOGI_CUSTOM_NEXT'] -ceq $tokenAfter)) `
        ('3/1/{0} · {0} · NA · True|{1}|True' -f $H_GENERATION, $fixture.Next.Position)
    # H19 안전 중지 + 진행 저장 실패 → step-failed 가 이김(오류 보류)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1 -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H19 안전 중지 + 진행 저장 실패 → 보류 step-failed(오류) · 대기열 1' ('{0}|{1} · {2}' -f $row.Hold.Kind, $row.Hold.IsError, (Get-QueueText $row.Journal)) `
        ('step-failed|True · inside-handoff:NA:1/0:g{0}' -f $H_GENERATION)
    # H18′ 대기열 기록 실패(저장 1 번째 = 대기열을 '사용 중' 으로 주입) → 기동 0 · 오류 정지(대기열 문구 + 잠금 파일 안내 + 꼬리) · 필수 기록 0
    # H18″ 같은 자리 '손상' → 대기열 문구 + 꼬리(안내 없음). 안내는 대기열 함수가 남긴 태그로 정하고 재입장 꼬리는 늘 맨 끝(단계 2.6 구현 리뷰 P3)
    $queueTrail = foreach ($queueTag in @('locked', 'corrupt')) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
        $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -UpdateTagAt @{ At = 1; Tag = $queueTag }
        '{0}: {1} · {2} · {3}' -f $queueTag, $row.Launches, ((@($row.Events) | Where-Object { $_.StartsWith('stop|') }) -join ' / '), (Get-EntryText $row.Journal $NONCE_A)
    }
    Assert-Case "H18′ 진행 저장 실패 + 대기열 기록 '사용 중' → 정지(대기열 문구 + 잠금 파일 안내 + 꼬리) || H18″ '손상' → 정지(대기열 문구 + 꼬리) · 둘 다 기동 0 · 항목 그대로(필수 기록 0)" `
        ($queueTrail -join ' || ') `
        ('locked: 0 · stop|{0}{2}|True · reentered/pending/0 || corrupt: 0 · stop|{1}{2}|True · reentered/pending/0' -f $IH_QUEUE_FAIL_LOCKED, $IH_QUEUE_FAIL, $STOP_TAIL)

    # H20 바퀴 완주(지정 1바퀴 · 마지막 칸) → 전진 뒤 마무리 실행 '지정 바퀴 완료'
    $lastNow = New-AbyssContext -Index 2 -Generation $H_GENERATION -ListRepeat 'count' -ListRepeatCount 1
    $lapNext = New-AbyssContext -Index 0 -Lap 2 -Generation $H_GENERATION -ListRepeat 'count' -ListRepeatCount 1
    $lapHandoff = New-FixtureEntry -Stage 'reentered' -Owner (ConvertTo-FiveFieldOwner (Get-CustomCanonicalOwner -Context $lastNow)) `
        -NextOwner (ConvertTo-FiveFieldOwner (Get-CustomCanonicalOwner -Context $lapNext)) -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    Initialize-HandoffRow -Custom $true -DiskContext $lastNow -Entries @($lapHandoff)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H20 바퀴 완주 → 마무리 실행 lap-complete(지정 바퀴 완료) · Owner = 2바퀴 0번 · 기동 HANDOFF_NONCE' `
        ('{0}|{1}|{2}|{3}/{4} · {5} · {6}' -f $row.Hold.Kind, $row.Hold.Reason, $row.Hold.IsError, $row.Hold.Owner.lap, $row.Hold.Owner.index, $row.Hold.Position, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE']) `
        ('lap-complete|지정 바퀴 완료|False|2/0 · {0} · {1}' -f $lapNext.Position, $NONCE_A)

    # H41 커스텀 · 진행 위치 못 읽음 + 재입장 표지 → 계상 1(완료 줄은 회차 번호) · 위치 못 읽음 정지 + 꼬리 · 전진 0 · journal 읽기 0
    Initialize-HandoffRow -Custom $true -DiskContext $null -Entries @($handoff)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H41 커스텀 위치 없음 + 표지 → 정지(위치 못 읽음 + 꼬리) · 전진 0 · 읽기 0 · 기록 그대로' ('{0} · {1} · {2} · {3}' -f $row.Flow, $row.Steps, $row.Reads, $row.StateUnchanged) `
        ('gui|=== 1회차 완료 === / stop|{0}{1}|True · 0 · 0 · 1' -f $EXIT_NO_CONTEXT, $STOP_TAIL)
    # D16 의 행동 - 위치 없음 + 표지 없음 → none → 지금 사슬(전진 실패 정지) · 읽기 0
    Initialize-HandoffRow -Custom $true -DiskContext $null -Entries @($handoff)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case 'H35/D16 커스텀 위치 없음 · 표지 없음 → 지금 사슬 그대로(전진 실패 정지) · 판별 읽기 0 · 첫 끝 처리 접근 0' ('{0} · {1}/{2}' -f $row.Flow, $row.Reads, $row.Updates) `
        'gui|=== 1회차 완료 === / step / stop|커스텀 진행 기록 저장 실패 - 중복 실행 방지를 위해 정지|True · 0/0'

    # H16″ 마무리 복구·재시작 중이던 기동의 커스텀 재입장 → 사슬과 같은 단계(설계 R1 3.4 순서 1): 복구 대기 해제 · 재시작 해제 · 마무리 복구 완료 줄 →
    #      다음 판 기동의 RESTART·RECOVERY 빈 값 (단계 2.6 구현 검증 - 생존 변이 IH-RECOV·IH-RESTART·IH-WASREC: H16 은 둘 다 거짓으로 시작해 못 가름.
    #      복구 회차라 공통 구간의 항목 완료 줄은 없음 - 사슬과 같은 규칙)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -RecoveryPending $true
    $script:customRestart = $true
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Assert-Case 'H16″ 복구·재시작 중 기동의 커스텀 재입장 → 전진 → 마무리 복구 완료 줄 → 다음 판 기동 · 복구 대기 False · RESTART·RECOVERY 빈 값' `
        ('{0} · {1} · [{2}] · [{3}]' -f $row.Flow, $row.RecoveryPending, $row.LaunchEnv['HONEYNOGI_CUSTOM_RESTART'], $row.LaunchEnv['HONEYNOGI_CUSTOM_RECOVERY']) `
        ('step / gui|{0} / launch|powershell.exe / gui|=== 2회차 시작(2/3) === · False · [] · []' -f $RECOVERY_DONE_LINE)

    # H12c 커스텀 필수 기록 '사용 중'(감시 태그) - 문구의 괄호는 실제 상태(단계 2.6 구현 검증 - 명세 대조 P3-2): 전진 성공 뒤(마커는 위 단계에서 정리됨)
    #      → '(기록 보존)' · 진행 1/1 · 마커 정리 1 / 진행 저장 실패 뒤(대기열 A1 · 마커 정리 전 - 저장 2 번째가 필수 기록) → '(기록·마커 보존)' · 1/0 ·
    #      마커 정리 0. 둘 다 기동 0 · 안내 + 꼬리 · 항목 그대로(명세 대조 P3-1 의 'H12 커스텀 행')
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff)
    $rowAdvanced = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -UpdateTagAt @{ At = 1; Tag = 'locked' }
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
    $rowStepFailed = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -UpdateTagAt @{ At = 2; Tag = 'locked' }
    Assert-Case "H12c 커스텀 필수 기록 '사용 중' · 전진 뒤 → (기록 보존) · 1/1 · 마커 정리 1 || 진행 저장 실패 뒤 → (기록·마커 보존) · 1/0 · 마커 정리 0 · 대기열 A1 · 둘 다 기동 0 · 항목 그대로" `
        ('{0} · {1} · {2} · {3} · {4} || {5} · {6} · {7} · {8} · [{9}] · {10}' -f ((Get-StopEvents $rowAdvanced) -join ' / '), $rowAdvanced.Disk, $rowAdvanced.MarkerClears, $rowAdvanced.Launches,
            (Get-EntryText $rowAdvanced.Journal $NONCE_A), ((Get-StopEvents $rowStepFailed) -join ' / '), $rowStepFailed.Disk, $rowStepFailed.MarkerClears, $rowStepFailed.Launches,
            (Get-QueueText $rowStepFailed.Journal), (Get-EntryText $rowStepFailed.Journal $NONCE_A)) `
        ('stop|{0}{1}|True · 1/1 · 1 · 0 · reentered/pending/0 || stop|{2}{1}|True · 1/0 · 0 · 0 · [inside-handoff:NA:1/0:g{3}] · reentered/pending/0' -f
            $IH_LOCKED_ADVANCED, $STOP_TAIL, $STOP_LOCKED, $H_GENERATION)

    # H13c·H14c 커스텀 판별 실패(단계 2.6 구현 검증 - 명세 대조 P3-1 · 설계 R1 5.2 H13·H14 '둘 다'): locked(+ 표지) / corrupt / io-failed → 계상 1(공통
    #      구간 완료 줄) → 오류 정지 그 문구 · 진행 전진 0 · 마커 정리 0 · 기동 0 · 진행 1/0 · 파일 그대로. 전진 0 이 핵심 - 다음 수동 시작의 S0·S3 가
    #      Step 전 owner i 로 이어받습니다(설계 R1 3.3). 판별이 none 으로 흐르면 사슬이 전진한 뒤 소비에서 멈춥니다(전진 1)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff)
    $rowLocked = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA -HoldLock
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -CorruptText 'not json'
    $rowCorrupt = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff)
    $rowIo = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON -HoldMainNone
    $doneLine = 'gui|[커스텀] {0} 항목 완료' -f $fixture.Now.Position
    Assert-Case 'H13c·H14c 커스텀 판별 locked(+ 표지) / corrupt / io-failed → 완료 줄 → 정지 그 문구 · 계상 1 · 전진/마커 정리/기동 0 · 진행 1/0 · 파일 그대로' `
        ((@($rowLocked, $rowCorrupt, $rowIo) | ForEach-Object { '{0} · {1} · {2}/{3}/{4} · {5} · {6}' -f $_.Flow, $_.Completed, $_.Steps, $_.MarkerClears, $_.Launches, $_.Disk, $_.StateUnchanged }) -join ' || ') `
        ((@(('{0} / stop|{1}{2}|True · 1 · 0/0/0 · 1/0 · 1' -f $doneLine, $EXIT_LOCKED_ADVANCE, $STOP_TAIL), ('{0} / stop|{1}|True · 1 · 0/0/0 · 1/0 · 1' -f $doneLine, $STOP_CORRUPT),
                ('{0} / stop|{1}|True · 1 · 0/0/0 · 1/0 · 1' -f $doneLine, $EXIT_READ_FAIL))) -join ' || ')
}

# ===== HX 행동 - 마무리 실행 완주 (설계 R1 5.2 H27~H31 · 명세 리뷰 3 확인 라운드 P1) =====
function Test-CaseExitFinishOnly {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $reasonA = $IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_A)
    $fixture = Get-CustomFixture

    # H27 비커스텀 마무리 실행(보류 안전 중지)의 선택 화면 복귀 → 계상 1 · 끝 처리(이 실행의 미적용 cleared 소비 · 넘긴 nonce done) → '안전 중지' 정지 ·
    # 다음 회차 판단 0 · 기동 0
    $launched = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    $finishCleared = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_B
    $safeHold = @{ Kind = 'safe-stop'; Reason = '안전 중지'; IsError = $false; Owner = @{ runId = 'run-H' }; Position = ''; Snapshot = $null }
    Initialize-HandoffRow -Entries @($launched, $finishCleared) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $safeHold -AbyssErrorStreak 2
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case 'H27 비커스텀 완주(보류 안전 중지) → 완료 줄 → 안전 중지 정지 · 판단 0 · 기동 0 · NA done · NB 소비 · 재입장 오류 연속 0' `
        ('{0} · {1} · {2} · {3} · {4}' -f $row.Flow, $row.Launches, (Get-EntryText $row.Journal $NONCE_A), (Get-EntryText $row.Journal $NONCE_B), $row.AbyssErrorStreak) `
        'gui|=== 1회차 완료 === / stop|안전 중지|False · 0 · reentered/done/1 · cleared/pending/1 · 0'
    # H28 비커스텀 보류 시간 → '지정 시간(21:20) 도달' 정지 / 보류 오류 → 오류 정지 + 빨강
    $timeHold = @{ Kind = 'time'; Reason = '지정 시간(21:20) 도달'; IsError = $false; Owner = @{ runId = 'run-H' }; Position = ''; Snapshot = $null }
    Initialize-HandoffRow -Entries @($launched) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $timeHold
    $row = Invoke-HandoffTick -ExitCode 11 -Reason $READY_REASON
    Assert-Case 'H28 비커스텀 완주(보류 시간 · 코드 11 은 0 과 같게) → 지정 시간 도달 정지 · NA done' ('{0} · {1}' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A)) `
        'gui|=== 1회차 완료 (다음 판으로 이어 감) === / stop|지정 시간(21:20) 도달|False · reentered/done/1'

    # H29 커스텀 진행 저장 실패 → 마무리 실행 → 완주: 같은 행의 두 틱(첫 틱이 만든 실제 보류·대기열 그대로). 완료 줄 위치 = 보류 위치(i+1) ·
    # 대기열 A1(i) → A2(i+1, owner = 보류 Owner) 순서 반영 = 전진 총 2 · 대기열을 비운 뒤 마커 정리 · 끝 처리 두 호출(ⓐ NA done · ⓑ cleared(i+1) 소비) ·
    # 보류 사유로 오류 정지 (설계 R1 H29 · 명세 리뷰 3 확인 라운드 P1)
    $handoff = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
    $first = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    Add-FixtureEntry -Entry (New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_B)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case 'H29 첫 틱: 마무리 실행 기동(step-failed) · 대기열 A1' ('{0}/{1} · {2}' -f $first.Kind, $first.Hold.Kind, (Get-QueueText $first.Journal)) ('finish-only/step-failed · inside-handoff:NA:1/0:g{0}' -f $H_GENERATION)
    Assert-Case 'H29 완주 흐름: 항목 완료 줄(보류 위치 i+1 - 디스크는 i) → 전진 2 → 보류 사유 오류 정지 · 빨강 · 판단 0 · 기동 0' `
        ('{0} · {1} · {2}' -f $row.Flow, $row.Color, $row.Launches) ('gui|[커스텀] {0} 항목 완료 / step / step / stop|커스텀 진행 기록 저장 실패|True · Firebrick · 0' -f $fixture.Next.Position)
    Assert-Case 'H29 완주 기록: 진행 1/0 → 1/2(전진 총 2) · 대기열 빔 · 마커 정리 1 · ⓐ 이번 기동 nonce(NA) done · ⓑ 보류 Owner 의 cleared(NB) 소비' `
        ('{0} · [{1}] · {2} · {3} · {4}' -f $row.Disk, (Get-QueueText $row.Journal), $row.MarkerClears, (Get-EntryText $row.Journal $NONCE_A), (Get-EntryText $row.Journal $NONCE_B)) `
        '1/2 · [] · 1 · reentered/done/1 · cleared/pending/1'
    # H29′ 대기열 기록(A2) '사용 중' · 반영 실패(진행 저장 실패 - 저장소 태그 없음) → 대기열·마커 보존 + 오류 정지(그 문구) · 끝 처리 0. 기록 '사용 중' 은
    #      정지 문구 끝에 잠금 파일 안내, 진행 저장 실패는 안내 없음(단계 2.6 구현 리뷰 P3 - 대기열 함수가 남긴 태그로 정함)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
    $null = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    $rowRecord = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON -UpdateTagAt @{ At = 1; Tag = 'locked' }
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
    $null = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    $script:stepFailures = 1
    $rowAdvance = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case "H29′ 완주 대기열 기록 '사용 중' → 정지(완료 기록 문구 + 잠금 파일 안내) · 대기열 A1 그대로 · NA launched || 반영 실패(전진 실패) → 정지(반영 문구 - 안내 없음) · 대기열 A1·A2 보존 · 마커 정리 0" `
        ('{0} · {1} · {2} || {3} · {4} · {5}' -f ((@($rowRecord.Events) | Where-Object { $_.StartsWith('stop|') }) -join ''), (Get-QueueText $rowRecord.Journal), (Get-EntryText $rowRecord.Journal $NONCE_A),
            ((@($rowAdvance.Events) | Where-Object { $_.StartsWith('stop|') }) -join ''), (Get-QueueText $rowAdvance.Journal), $rowAdvance.MarkerClears) `
        ('stop|{0}|True · inside-handoff:NA:1/0:g{2} · reentered/launched/1 || stop|{1}|True · inside-handoff:NA:1/0:g{2},finish-only-complete:NA:1/1:g{2} · 0' -f $FINISH_RECORD_FAIL_LOCKED, $FINISH_ADVANCE_FAIL, $H_GENERATION)
    # H29‴ 대기열 실패의 '사용 중' 안내(단계 2.6 구현 리뷰 P3): A2 기록 '손상' → 완료 기록 문구(안내 없음) / 반영의 지우기 저장(2 번째 - 첫 전진 뒤) '사용 중' →
    #      반영 문구 + 잠금 파일 안내 / '손상' → 반영 문구(안내 없음). 지우기 실패는 첫 전진 뒤라 진행 1/1 · 대기열 A1·A2 그대로 · 마커 정리 0
    $queueTrail = foreach ($failCase in @(@{ N = 'A2 손상'; At = 1; Tag = 'corrupt' }, @{ N = '지우기 사용 중'; At = 2; Tag = 'locked' }, @{ N = '지우기 손상'; At = 2; Tag = 'corrupt' })) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
        $null = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
        $failRow = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON -UpdateTagAt @{ At = $failCase.At; Tag = $failCase.Tag }
        '{0}: {1} · {2} · {3} · [{4}] · {5}' -f $failCase.N, ((Get-StopEvents $failRow) -join ' / '), $failRow.Color, $failRow.Disk, (Get-QueueText $failRow.Journal), $failRow.MarkerClears
    }
    Assert-Case "H29‴ 완주 A2 '손상' → 완료 기록 문구 || 지우기 '사용 중' → 반영 문구 + 잠금 파일 안내 || 지우기 '손상' → 반영 문구 · 셋 다 빨강 · 대기열 보존 · 마커 정리 0" `
        ($queueTrail -join ' || ') `
        (('A2 손상: stop|{0}|True · Firebrick · 1/0 · [inside-handoff:NA:1/0:g{3}] · 0 || 지우기 사용 중: stop|{1}|True · Firebrick · 1/1 · [inside-handoff:NA:1/0:g{3},finish-only-complete:NA:1/1:g{3}] · 0 || ' +
            '지우기 손상: stop|{2}|True · Firebrick · 1/1 · [inside-handoff:NA:1/0:g{3},finish-only-complete:NA:1/1:g{3}] · 0') -f $FINISH_RECORD_FAIL, $FINISH_ADVANCE_FAIL_LOCKED, $FINISH_ADVANCE_FAIL, $H_GENERATION)
    # H29″ 완주 끝 처리 ⓐ(이번 기동 nonce done - 저장 4 번째 = 대기열 A2 · 반영 제거 2 뒤) / ⓑ(-ConsumeOnly 소비 - 5 번째) '사용 중'(감시 태그) → 오류 정지 =
    #      완료 표시를 남기지 못함 (진행은 반영됨) + 안내 · 진행 1/2 · 대기열 빔 · 마커 정리 1 · ⓐ 실패면 NA launched / ⓑ 실패면 NA done · 둘 다 NB 미소비
    #      (단계 2.6 구현 검증 - 명세 대조 P3-2: 반영 뒤라 옛 문구 '진행 전진·기동을 보류 … (기록·마커 보존)' 은 사실과 달랐음)
    $finishTrail = foreach ($failAt in @(4, 5)) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
        $null = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
        Add-FixtureEntry -Entry (New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_B)
        $failRow = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON -UpdateTagAt @{ At = $failAt; Tag = 'locked' }
        '{0}: {1} · {2} · {3} · [{4}] · {5} · {6} · {7}' -f $failAt, ((Get-StopEvents $failRow) -join ' / '), $failRow.Color, $failRow.Disk, (Get-QueueText $failRow.Journal),
            $failRow.MarkerClears, (Get-EntryText $failRow.Journal $NONCE_A), (Get-EntryText $failRow.Journal $NONCE_B)
    }
    Assert-Case "H29″ 완주 끝 처리 ⓐ / ⓑ '사용 중' → 정지 = 완료 표시를 남기지 못함 (진행은 반영됨) + 안내 · 빨강 · 1/2 · 대기열 빔 · 마커 정리 1 · ⓐ 실패 NA launched / ⓑ 실패 NA done · NB 미소비" `
        ($finishTrail -join ' || ') `
        ('4: stop|{0}|True · Firebrick · 1/2 · [] · 1 · reentered/launched/1 · cleared/pending/0 || 5: stop|{0}|True · Firebrick · 1/2 · [] · 1 · reentered/done/1 · cleared/pending/0' -f $FINISH_LOCKED_APPLIED)

    # H30 커스텀 바퀴 완주 보류 → 완주: A2(owner = 2바퀴 0번) 반영 → 진행 초기화 → '지정 바퀴 완료' / 초기화 실패 → 오류 정지
    $lastNow = New-AbyssContext -Index 2 -Generation $H_GENERATION -ListRepeat 'count' -ListRepeatCount 1
    $lapNext = New-AbyssContext -Index 0 -Lap 2 -Generation $H_GENERATION -ListRepeat 'count' -ListRepeatCount 1
    $lapHandoff = New-FixtureEntry -Stage 'reentered' -Owner (ConvertTo-FiveFieldOwner (Get-CustomCanonicalOwner -Context $lastNow)) `
        -NextOwner (ConvertTo-FiveFieldOwner (Get-CustomCanonicalOwner -Context $lapNext)) -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    Initialize-HandoffRow -Custom $true -DiskContext $lastNow -Entries @($lapHandoff)
    $null = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $lastNow -Entries @($lapHandoff)
    $null = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    $script:resetResult = $false
    $rowResetFail = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case 'H30 바퀴 완주 보류의 완주 → 항목 완료 줄(2바퀴째 1/3번) → 전진 1(A2) → 진행 초기화 → 지정 바퀴 완료 || 초기화 실패 → 오류 정지 + 빨강' `
        ('{0} || {1} · {2}' -f $row.Flow, ((@($rowResetFail.Events) | Where-Object { -not $_.StartsWith('line|') -and -not $_.StartsWith('gui|') }) -join ' / '), $rowResetFail.Color) `
        ('gui|[커스텀] {0} 항목 완료 / step / reset / stop|지정 바퀴 완료|False || step / reset / stop|지정 바퀴 완료 후 진행 초기화 저장 실패|True · Firebrick' -f $lapNext.Position)
    # H30′ 완주 처리 중 예외(진행 초기화 모의가 던짐) → 완주 함수의 catch 가 오류 정지(완주 처리 중 예외 + 메시지) · 빨강 · 예외가 타이머로 나가지 않음
    #      (단계 2.6 구현 검증 - 생존 변이 FO-CATCH1·FO-CATCH2: 완주 함수 안에서 예외를 내는 행이 없었음)
    Initialize-HandoffRow -Custom $true -DiskContext $lastNow -Entries @($lapHandoff)
    $null = Invoke-HandoffTick -ExitCode 0 -Reason $reasonA
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON -ResetThrows
    Assert-Case 'H30′ 완주 처리 중 예외(진행 초기화) → 오류 정지(완주 처리 중 예외 + 메시지) · 빨강 · 타이머 오류 줄 0 · 예외 0' `
        ('{0} · {1} · {2} · [{3}]' -f ((Get-StopEvents $row) -join ' / '), $row.Color, @($row.Events | Where-Object { $_.StartsWith('gui|[오류] 내부 타이머') }).Count, $row.Thrown) `
        ('stop|{0}|True · Firebrick · 0 · []' -f ($FINISH_EXCEPTION_FORMAT -f $INJECTED_RESET_EXCEPTION))

    # H31 마무리 실행 기동의 코드 10(안전망) → 갈래 첫 문장의 끝 처리(NA done) → 보류 사유로 정지 · 계상 0 · 연속 수·재입장 안내·판단 0
    Initialize-HandoffRow -Entries @($launched) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $safeHold -PreparedStreak 1
    $row = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    $errorHold = @{ Kind = 'step-failed'; Reason = '커스텀 진행 기록 저장 실패'; IsError = $true; Owner = $fixture.OwnerNext; Position = $fixture.Next.Position; Snapshot = $fixture.Now }
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $errorHold
    $rowCustom = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    # 읽기 0·저장 1 = 갈래 첫 문장의 끝 처리 한 번뿐 - 그 뒤 추가 변경 0 (명세 리뷰 3: 마무리 실행 코드 10 은 첫 문장 끝 처리 뒤 추가 변경 없음)
    Assert-Case 'H31 마무리 실행 코드 10 → 안전 중지 정지(보류 사유) · NA done · 계상 0 · 연속 수 1 그대로 · 읽기 0·저장 1 || 커스텀 오류 보류 → 오류 정지 + 빨강 · NA done · 읽기 0·저장 1·전진 0' `
        ('{0} · {1} · {2} · {3} · {4}/{5} || {6} · {7} · {8} · {9}/{10}/{11}' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A), $row.Completed, $row.PreparedStreak, $row.Reads, $row.Updates,
            $rowCustom.Flow, $rowCustom.Color, (Get-EntryText $rowCustom.Journal $NONCE_A), $rowCustom.Reads, $rowCustom.Updates, $rowCustom.Steps) `
        'stop|안전 중지|False · reentered/done/1 · 0 · 1 · 0/1 || stop|커스텀 진행 기록 저장 실패|True · Firebrick · reentered/done/1 · 0/1/0'
    # H27′ 비커스텀 완주의 끝 처리 '사용 중' / H31′ 마무리 실행 코드 10 의 첫 문장 끝 처리 '사용 중'(감시 태그 - 저장 1 번째) → 정지 = 완료 표시를 남기지
    #      못함 (기록 보존) + 안내 · 보류 사유 정지 0 · NA launched 그대로 · 판단·기동 0 (단계 2.6 구현 검증 - 명세 대조 P3-2: 기동할 다음 판이 없어 옛
    #      문구 '진행 전진·기동을 보류'·'계상·기동을 보류' 는 사실과 달랐음)
    Initialize-HandoffRow -Entries @($launched, $finishCleared) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $safeHold
    $rowPlainEnd = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON -UpdateTagAt @{ At = 1; Tag = 'locked' }
    Initialize-HandoffRow -Entries @($launched) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $safeHold
    $rowCode10End = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON -UpdateTagAt @{ At = 1; Tag = 'locked' }
    Assert-Case "H27′ 비커스텀 완주 끝 처리 '사용 중' || H31′ 마무리 실행 코드 10 첫 문장 '사용 중' → 정지 = 완료 표시를 남기지 못함 (기록 보존) + 안내 · NA launched · NB 미소비 · 기동 0" `
        ('{0} · {1} · {2} · {3} || {4} · {5} · {6}' -f $rowPlainEnd.Flow, (Get-EntryText $rowPlainEnd.Journal $NONCE_A), (Get-EntryText $rowPlainEnd.Journal $NONCE_B), $rowPlainEnd.Launches,
            $rowCode10End.Flow, (Get-EntryText $rowCode10End.Journal $NONCE_A), $rowCode10End.Launches) `
        ('gui|=== 1회차 완료 === / stop|{0}|True · reentered/launched/1 · cleared/pending/0 · 0 || stop|{0}|True · reentered/launched/1 · 0' -f $FINISH_LOCKED_KEPT)
}

# ===== HX 행동 - 판별 none · 일반 끝 처리 (설계 R1 5.2 H33~H37 · 명세 리뷰 3 P1) =====
function Test-CaseExitNone {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    # H33 비커스텀 · 기록 없음 · 코드 0(정상 / 안전 중지) → 끝 처리(접근 1 · 쓰기 0 - 파일 생성 0) → 다음 회차 판단 그대로
    Initialize-HandoffRow
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Initialize-HandoffRow -StopRequested $true
    $rowStop = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case 'H33 비커스텀 판별 none → 다음 회차 판단(코드 0) · 읽기 1·저장 1(소비 시도 - 파일 생성 0) · 안전 중지도 같은 판단 호출' `
        ('{0} · {1}/{2} · {3} || {4}' -f $row.Flow, $row.Reads, $row.Updates, $row.StateUnchanged, $rowStop.Flow) 'gui|=== 1회차 완료 === / decision|0 · 1/1 · 1 || gui|=== 1회차 완료 === / decision|0'
    # H33′ 비커스텀 판별 none · 일반 끝 처리가 '사용 중'(판별 읽기 뒤 다른 주체가 잠금 - 저장 전 갈고리로 실제 잠금) → 정지(기동 보류 · 기록 보존 + 안내) ·
    #      다음 회차 판단 0 · 기동 0 (단계 2.6 구현 검증 - 생존 변이 W-GENRET: 실패를 무시하는 배선을 원문 패턴(T4-e 2d)만 잡았음). 비커스텀은 계상이
    #      끝났고 진행 전진·완료 마커가 없어 '진행 전진·기동 … (기록·마커 보존)' 이 아님(단계 2.6 구현 리뷰 P3)
    Initialize-HandoffRow
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON -PreUpdateAt 1 -PreUpdateHook { Lock-JournalLock }
    Assert-Case "H33′ 일반 끝 처리 '사용 중' → 정지(기동 보류 · 기록 보존 + 안내) · 판단 0 · 기동 0" ('{0} · {1}' -f $row.Flow, $row.Launches) `
        ('gui|=== 1회차 완료 === / stop|{0}|True · 0' -f $EXIT_LOCKED_PLAIN)
    # H34 범위 밖 코드 11(던전·심층·어비스 파티원) → 판단 그대로 · journal 읽기·저장 0
    $rangeTexts = foreach ($rangeRow in @(@{ Content = 'dungeon' }, @{ Content = 'deep' }, @{ Mode = 'party'; Matching = 'member' })) {
        Initialize-HandoffRow @rangeRow
        $rangeRun = Invoke-HandoffTick -ExitCode 11 -Reason $READY_REASON
        '{0} · {1}/{2}' -f ($rangeRun.Flow -replace '^gui\|=== 1회차 완료 \(다음 판으로 이어 감\) === / ', ''), $rangeRun.Reads, $rangeRun.Updates
    }
    Assert-Case 'H34 던전·심층·어비스 파티원 코드 11 → 판단(11) · 읽기·저장 0' ($rangeTexts -join ' || ') 'decision|11 · 0/0 || decision|11 · 0/0 || decision|11 · 0/0'
    # H36 비커스텀 retry-attempt + 선택 화면 복귀 + 안전 중지 → none → 끝 처리가 그 항목 소비('클리어 이상') → 판단
    $attempt = New-FixtureEntry -Stage 'retry-attempt' -Owner $runOwner -Nonce $NONCE_A
    Initialize-HandoffRow -Entries @($attempt) -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case 'H36 retry-attempt + 선택 화면 복귀 + 안전 중지 → 판단(0) · 그 항목 소비' ('{0} · {1}' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A)) 'gui|=== 1회차 완료 === / decision|0 · retry-attempt/pending/1'
    # H37 코드 10 · 마무리 실행 아님 → 첫 문장 끝 처리(넘긴 nonce done) → 지금 흐름(준비 실행 안내 · 연속 수 +1 · 판단)
    $launched = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    Initialize-HandoffRow -Entries @($launched) -Applied @($NONCE_A) -LaunchKind 'next' -LaunchNonce $NONCE_A
    $row = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    Assert-Case 'H37 코드 10(마무리 실행 아님) → 넘긴 nonce done → 준비 실행 안내 → 판단(10) · 연속 수 0 → 1' ('{0} · {1} · {2}' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A), $row.PreparedStreak) `
        ('{0} / decision|10 · reentered/done/1 · 1' -f $PREPARED_NOTICE)

    # H35 커스텀 · 판별 none · 코드 0 → 첫 끝 처리는 접근 0(넘긴 nonce 없음 · 커스텀 0 은 소비 안 함) → 사슬 그대로 전진 → 전진 성공 뒤 -ConsumeOnly 가
    # cleared(i) 소비 1 → 마커 정리 → 다음 회차 기동 (명세 리뷰 3 P1)
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case 'H35 커스텀 none → 항목 완료 줄 → 전진 → 다음 회차 기동 · cleared(i) 소비(전진 뒤) · 저장 2(소비 + 후보 고르기) · 기동 종류 none' `
        ('{0} · {1} · {2} · {3}' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_C), $row.Updates, $row.Kind) `
        ('gui|[커스텀] {0} 항목 완료 / step / launch|powershell.exe / gui|=== 2회차 시작(2/3) === · cleared/pending/1 · 2 · none' -f $fixture.Now.Position)
    # H35′ 커스텀 판별 none · 전진 성공 뒤 -ConsumeOnly 가 '사용 중'(저장 전 갈고리로 실제 잠금 - 첫 끝 처리는 접근 0 이라 저장 1 번째) → 정지(기동 보류 +
    #      안내) · 마커 정리 0 · 기동 0 · cleared(i) 미소비 · 진행 1/1 (단계 2.6 구현 검증 - 생존 변이 W-CORET: 실패를 무시하는 배선을 원문 패턴(S11)만 잡았음)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON -PreUpdateAt 1 -PreUpdateHook { Lock-JournalLock }
    Assert-Case "H35′ 전진 뒤 -ConsumeOnly '사용 중' → 정지(기동 보류 + 안내) · 마커 정리 0 · 기동 0 · cleared(i) 미소비 · 진행 1/1" `
        ('{0} · {1} · {2} · {3} · {4}' -f ((Get-StopEvents $row) -join ' / '), $row.MarkerClears, $row.Launches, (Get-EntryText $row.Journal $NONCE_C), $row.Disk) `
        ('stop|{0}|True · 0 · 0 · cleared/pending/0 · 1/1' -f $STOP_LOCKED)
    # 리뷰 3 P1 · 커스텀 코드 0 + 마커 없음 + cleared(i) + 진행 저장 실패 → 지금 사슬의 정지 · cleared(i) 미적용 보존(owner = 디스크 진행 i - 다음 시작의
    # 복구 근거) · 소비 0
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow) -StepFailures 1
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    $preserved = $null
    foreach ($entry in @($row.Journal.entries)) { if ([string]$entry.nonce -eq $NONCE_C) { $preserved = $entry } }
    Assert-Case '리뷰 3 P1 커스텀 0 + 진행 저장 실패 → 정지(지금 문구) · cleared(i) 미적용 그대로 · owner = 디스크 진행 i(세대 포함) · 복구 대기 참 · 저장 0' `
        ('{0} · {1} · {2} · {3} · {4}' -f ((@($row.Events) | Where-Object { $_.StartsWith('stop|') }) -join ''), (Get-EntryText $row.Journal $NONCE_C),
            (Test-AbyssJournalOwnerMatch -Entry $preserved -Owner (Get-CustomCanonicalOwner -Context $fixture.Now) -Generation $H_GENERATION), $row.RecoveryPending, $row.Updates) `
        'stop|커스텀 진행 기록 저장 실패 - 중복 실행 방지를 위해 정지|True · cleared/pending/0 · True · True · 0'
}

# ===== G 코드 10 갈래 (설계 R2 5.3 G1~G7) =====
function Test-CaseExitCode10 {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    # G1·G4 거점 퇴장 코드 10 + 이번 기동 nonce 항목이 이미 done(워커가 닫음 · reason·screen) → 연속 수 0 · 계상 0 · 전진 0 · 그 항목 필드 전부 그대로 ·
    #     다음 기동(판단이 실제로 기동)의 기동 종류 none · HANDOFF_NONCE 빈 값
    $closed = New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'done' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $closed.reason = 'abandoned-death-exit'
    $closed.screen = 'field'
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($closed) -LaunchKind 'own' -LaunchNonce $NONCE_A -PreparedStreak 2 -DecisionMode 'start'
    $entryBefore = ConvertTo-Json -InputObject @((Read-FixtureJournal -Path $script:abyssJournalPath).entries)[0] -Depth 10 -Compress
    $journalHashBefore = (Get-FileHash -LiteralPath $script:abyssJournalPath -Algorithm SHA256).Hash
    $row = Invoke-HandoffTick -ExitCode 10 -Reason $CHECKPOINT_REASON
    $entryAfter = ConvertTo-Json -InputObject @($row.Journal.entries)[0] -Depth 10 -Compress
    $journalHashAfter = (Get-FileHash -LiteralPath $script:abyssJournalPath -Algorithm SHA256).Hash
    Assert-Case 'G1 거점 퇴장 코드 10 → 재입장 안내 → 판단 → 다음 기동 · 연속 수 0 · 계상 0 · 전진 0 · 다음 기동 none · HANDOFF_NONCE 빈 값' `
        ('{0} · {1} · {2} · {3} · {4}/{5}' -f $row.Flow, $row.PreparedStreak, $row.Completed, $row.Steps, $row.Kind, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE']) `
        ('{0} / decision|10 / launch|powershell.exe / gui|=== 1회차 시작(1/3) === · 0 · 0 · 0 · none/' -f $CHECKPOINT_NOTICE)
    # G4 의 저장 0: 바꿀 것이 없으면 쓰지 않음(본 파일 바이트 그대로 · 직전본 생성 0) - 필드만 보면 '같은 값으로 다시 done' 하는 쓸데없는 저장(seq+1·
    #    직전본 교체 - 저장이 실패하면 거짓 정지)을 못 가름 (단계 2.6 구현 검증 - 생존 변이 R2-1b)
    Assert-Case 'G4 이미 done 인 넘긴 항목 → 종료 처리 뒤 그 항목의 필드 전부 그대로(reason·screen 포함) · 본 파일 바이트 그대로 · 직전본 생성 0' `
        ('{0} · {1} · {2}' -f [int]($entryBefore -ceq $entryAfter), [int]($journalHashBefore -ceq $journalHashAfter), [int][IO.File]::Exists($script:abyssJournalPath + '.bak')) '1 · 1 · 0'
    # G2 정리 전용(준비 실행) 코드 10 + 항목 done → 연속 수 +1 · 계상 0 · 다음 기동 nonce 없음
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($closed) -LaunchKind 'own' -LaunchNonce $NONCE_A -PreparedStreak 1 -DecisionMode 'start'
    $row = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    Assert-Case 'G2 준비 실행 코드 10 → 연속 수 1 → 2 · 계상 0 · 다음 기동 none · HANDOFF_NONCE 빈 값' `
        ('{0} · {1} · {2}/{3}' -f $row.PreparedStreak, $row.Completed, $row.Kind, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE']) '2 · 0 · none/'
    # G3 넘긴 nonce 없는 기동(Role none) + 열린 자기 항목(워커 닫기 실패) → GUI 는 닫지 않음 → 다음 기동이 own 으로 받음
    $open = New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_B
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($open) -DecisionMode 'start'
    $row = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    Assert-Case 'G3 Role none 기동 + 열린 자기 항목 → 항목 launched 그대로 · 다음 기동 own · HANDOFF_NONCE = 그 항목' `
        ('{0} · {1}/{2} · {3}' -f (Get-EntryText $row.Journal $NONCE_B), $row.Kind, $row.Nonce, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE']) ('entered/launched/0 · own/NB · {0}' -f $NONCE_B)
    # G5 'left'(거점 퇴장) 코드 10 5연속 → 연속 수 0 · 정지 0 / 준비 실행 코드 10 3연속 → 3회째 오류 정지 (실제 다음 회차 판단 - 끝 처리가 연속 수를 안 바꿈)
    $launched = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    Initialize-HandoffRow -Entries @($launched) -Applied @($NONCE_A) -LaunchKind 'next' -LaunchNonce $NONCE_A -DecisionMode 'real'
    $leftTrail = @()
    for ($leftRun = 1; $leftRun -le 5; $leftRun++) {
        $tick = Invoke-HandoffTick -ExitCode 10 -Reason $CHECKPOINT_REASON
        $leftTrail += ('{0}:{1}' -f $tick.PreparedStreak, ((@($tick.Events) | Where-Object { $_.StartsWith('stop|') }).Count))
    }
    $prepTrail = @()
    for ($prepRun = 1; $prepRun -le 3; $prepRun++) {
        $tick = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
        $prepTrail += ('{0}:{1}' -f $tick.PreparedStreak, ((@($tick.Events) | Where-Object { $_.StartsWith('stop|') }) -join ''))
    }
    Assert-Case "G5 거점 퇴장 코드 10 ×5 → 연속 수 0·정지 0 매번 || 준비 실행 ×3 → 1·2·3 · 3회째 오류 정지(준비 실행 3회 연속)" `
        ('{0} || {1}' -f ($leftTrail -join ','), ($prepTrail -join ',')) `
        '0:0,0:0,0:0,0:0,0:0 || 1:,2:,3:stop|준비 실행(화면 복귀)이 3회 연속 반복 - 게임 화면 상태를 확인해 주세요|True'
    # G6 Role next 기동 → 필드 시작 코드 10(워커 닫기 0) → 갈래 첫 문장이 그 nonce done → 다음 기동 none · HANDOFF_NONCE 빈 값 (순서 = S6 · 변이 R2)
    #     변형: Role own(커스텀) → own 닫기 실패 → 필드 시작 코드 10 → 같음
    Initialize-HandoffRow -Entries @($launched) -Applied @($NONCE_A) -LaunchKind 'next' -LaunchNonce $NONCE_A -DecisionMode 'start'
    $row = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    $ownOpen = New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_B
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($ownOpen) -LaunchKind 'own' -LaunchNonce $NONCE_B -DecisionMode 'start'
    $rowOwn = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    Assert-Case 'G6 Role next 필드 시작 코드 10 → NA done · 다음 기동 none · HANDOFF_NONCE 빈 값 || Role own 변형 → NB done · 다음 기동 none' `
        ('{0} · {1}/{2} || {3} · {4}/{5}' -f (Get-EntryText $row.Journal $NONCE_A), $row.Kind, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE'], (Get-EntryText $rowOwn.Journal $NONCE_B), $rowOwn.Kind,
            $rowOwn.LaunchEnv['HONEYNOGI_HANDOFF_NONCE']) 'reentered/done/1 · none/ || entered/done/0 · none/'
    # G7 코드 10 + 완료 기록 손상(커스텀·비커스텀) → 기동 0 · 손상 문구 + 위치 안내 오류 정지 · 파일 그대로
    Initialize-HandoffRow -CorruptText 'not json' -LaunchKind 'next' -LaunchNonce $NONCE_A -DecisionMode 'start'
    $row = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -CorruptText 'not json' -DecisionMode 'start'
    $rowCustom = Invoke-HandoffTick -ExitCode 10 -Reason $PREPARED_REASON
    Assert-Case "G7 코드 10 + 'corrupt' 비커스텀 || 커스텀 → 기동 0 · 정지 = 손상 문구 + 위치 안내 · 파일 그대로" `
        ('{0} · {1} · {2} || {3} · {4} · {5}' -f $row.Launches, $row.Flow, $row.StateUnchanged, $rowCustom.Launches, $rowCustom.Flow, $rowCustom.StateUnchanged) `
        ('0 · stop|{0}|True · 1 || 0 · stop|{0}|True · 1' -f $STOP_CORRUPT)
}

# ===== E 끝 처리 Complete-AbyssExitJournal (명세 2.6 표 · 5절 A6 · 검토 P3-7) =====
function Invoke-EndRow {
    # 끝 처리 1번을 직접 - 준비 → (주입) → 실제 Complete-AbyssExitJournal → 반환 · 정지 · 접근 수 · 디스크 컨텍스트 읽기 수
    param([hashtable]$Setup = @{}, [hashtable]$CallArgs = @{}, [string]$WorkerReason = '', [switch]$HoldLock, [switch]$HoldMainRead, [int]$UpdateThrowAt = 0)
    Initialize-HandoffRow @Setup
    $script:lastWorkerDoneReason = $WorkerReason
    $script:contextReads = 0
    $script:updateThrowAt = $UpdateThrowAt
    $stateBefore = Get-FolderState -Folder $script:rowFolder
    if ($HoldLock) { Lock-JournalLock }
    if ($HoldMainRead) { $script:heldStreams.Add([IO.File]::Open($script:abyssJournalPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)) }
    try {
        $result = @(Complete-AbyssExitJournal @CallArgs)
    } finally {
        Unlock-LogFiles
        $script:updateThrowAt = 0
    }
    $colorName = $(if ($null -eq $lblStatus.ForeColor) { '색 그대로' } else { [string]$lblStatus.ForeColor.Name })
    return [pscustomobject]@{
        Result = ($result -join ',')
        Stops = ((@($script:events) | Where-Object { $_.StartsWith('stop|') }) -join ' / ')
        Color = $colorName
        Reads = $script:journalReads
        Updates = $script:journalUpdates
        ContextReads = $script:contextReads
        Journal = (Read-FixtureJournal -Path $script:abyssJournalPath)
        StateUnchanged = [int]($stateBefore -ceq (Get-FolderState -Folder $script:rowFolder))
        AbyssErrorStreak = $script:abyssErrorStreak
    }
}

function Test-CaseExitEnd {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    $passed = New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $customSetup = @{ Custom = $true; DiskContext = $fixture.Now; Entries = @($clearedNow, $passed) }

    # E1 -Context 안 넘김(코드 10) → 지금 컨텍스트를 읽어(1) cleared(i) 소비 / E2 $null 로 넘김(코드 4 설정 읽기 실패) → 다시 읽지 않음(0) · 소비 0 ·
    #     넘긴 nonce 는 done (변이 '$null 을 안 넘김으로 다뤄 다시 읽음' → 소비 1)
    $rowOmit = Invoke-EndRow -Setup $customSetup -CallArgs @{ ExitCode = 10 }
    $rowNull = Invoke-EndRow -Setup ($customSetup + @{ LaunchNonce = $NONCE_A }) -CallArgs @{ ExitCode = 4; Context = $null }
    Assert-Case 'E1 -Context 안 넘김(코드 10) → 컨텍스트 읽기 1 · cleared(i) 소비 · 참 || E2 $null 로 넘김(코드 4) → 읽기 0 · 소비 0 · 넘긴 nonce done · 참' `
        ('{0} · {1} · {2} || {3} · {4} · {5} · {6}' -f $rowOmit.ContextReads, (Get-EntryText $rowOmit.Journal $NONCE_C), $rowOmit.Result,
            $rowNull.ContextReads, (Get-EntryText $rowNull.Journal $NONCE_C), (Get-EntryText $rowNull.Journal $NONCE_A), $rowNull.Result) `
        '1 · cleared/pending/1 · True || 0 · cleared/pending/0 · entered/done/0 · True'
    # E1′ -Context 안 넘김(코드 10) + 지금 컨텍스트도 못 읽음(설정 읽기 실패) → 소비 건너뜀 · 넘긴 nonce 는 done · 참 · 정지 0 (명세 2.6 '그래도 $null 이면
    #     소비를 건너뛴다' 의 행 - 단계 2.6 구현 검증. $null 로 소비를 시도해도 맞는 owner 가 없어 결과가 같으므로(변이 E-NULLSKIP 실질 동등) 계약만 고정)
    $rowNoContext = Invoke-EndRow -Setup @{ Custom = $true; DiskContext = $null; Entries = @($clearedNow, $passed); LaunchNonce = $NONCE_A } -CallArgs @{ ExitCode = 10 }
    Assert-Case 'E1′ -Context 안 넘김 + 지금 컨텍스트 없음 → 컨텍스트 읽기 1 · cleared(i) 소비 0 · 넘긴 nonce done · 참 · 정지 0' `
        ('{0} · {1} · {2} · {3} · [{4}]' -f $rowNoContext.ContextReads, (Get-EntryText $rowNoContext.Journal $NONCE_C), (Get-EntryText $rowNoContext.Journal $NONCE_A), $rowNoContext.Result,
            $rowNoContext.Stops) '1 · cleared/pending/0 · entered/done/0 · True · []'
    # E3 코드 10 + 마무리 복구 기동(customRecoveryPending) → 소비 생략 · 넘긴 nonce done (명세 5절 A6ⓑ (가) - 다음 시작의 복구 근거 보존)
    $rowRecovery = Invoke-EndRow -Setup ($customSetup + @{ RecoveryPending = $true; LaunchNonce = $NONCE_A }) -CallArgs @{ ExitCode = 10 }
    Assert-Case 'E3 코드 10 + 마무리 복구 기동 → cleared(i) 미소비 · 넘긴 nonce done · 참' `
        ('{0} · {1} · {2}' -f (Get-EntryText $rowRecovery.Journal $NONCE_C), (Get-EntryText $rowRecovery.Journal $NONCE_A), $rowRecovery.Result) 'cleared/pending/0 · entered/done/0 · True'
    # E4 할 일 없으면 journal 접근 0: 커스텀 0·11 첫 호출 + 넘긴 nonce 없음 / 범위 밖(던전) + nonce / 오류 종료(1·2·3·-1) + nonce 없음.
    #     오류 종료 + 넘긴 nonce → done 만(소비 0 - 명세 5절 A6ⓐ)
    $noWork = @()
    $noWork += Invoke-EndRow -Setup $customSetup -CallArgs @{ ExitCode = 0; Context = $fixture.Now }
    $noWork += Invoke-EndRow -Setup $customSetup -CallArgs @{ ExitCode = 11; Context = $fixture.Now }
    $noWork += Invoke-EndRow -Setup @{ Content = 'dungeon'; Entries = @($clearedNow, $passed); LaunchNonce = $NONCE_A } -CallArgs @{ ExitCode = 0 }
    foreach ($errorCode in @(1, 2, 3, -1)) { $noWork += Invoke-EndRow -Setup $customSetup -CallArgs @{ ExitCode = $errorCode } }
    Assert-Case 'E4 할 일 없음(커스텀 0 · 11 · 범위 밖 · 오류 종료 1·2·3·-1) → 읽기·저장 0 · 파일 그대로 · 참 (7행)' `
        ((@($noWork) | ForEach-Object { '{0}/{1}/{2}/{3}' -f $_.Reads, $_.Updates, $_.StateUnchanged, $_.Result }) -join ' ') ((@(1..7) | ForEach-Object { '0/0/1/True' }) -join ' ')
    $rowErrorNonce = Invoke-EndRow -Setup ($customSetup + @{ LaunchNonce = $NONCE_A }) -CallArgs @{ ExitCode = 1 }
    Assert-Case 'E4′ 오류 종료(1) + 넘긴 nonce → done 만 · cleared(i) 미소비' ('{0} · {1}' -f (Get-EntryText $rowErrorNonce.Journal $NONCE_A), (Get-EntryText $rowErrorNonce.Journal $NONCE_C)) 'entered/done/0 · cleared/pending/0'
    # E5 커스텀 0·11 첫 호출은 nonce done 만 · -ConsumeOnly 는 소비만(넘긴 nonce 그대로) · 4 는 둘 다 · -KeepLaunched 면 done 안 함(재전달 예외)
    $rowFirst = Invoke-EndRow -Setup ($customSetup + @{ LaunchNonce = $NONCE_A }) -CallArgs @{ ExitCode = 0; Context = $fixture.Now }
    $rowConsume = Invoke-EndRow -Setup ($customSetup + @{ LaunchNonce = $NONCE_A }) -CallArgs @{ ExitCode = 0; Context = $fixture.Now; ConsumeOnly = $true }
    $rowKeep = Invoke-EndRow -Setup ($customSetup + @{ LaunchNonce = $NONCE_A }) -CallArgs @{ ExitCode = 4; Context = $fixture.Now; KeepLaunched = $true }
    $rowFour = Invoke-EndRow -Setup ($customSetup + @{ LaunchNonce = $NONCE_A }) -CallArgs @{ ExitCode = 4; Context = $fixture.Now }
    Assert-Case 'E5 커스텀 0 첫 호출 → nonce done·소비 0 / -ConsumeOnly → 소비·nonce 그대로 / 코드 4 -KeepLaunched → 소비·launched 유지 / 코드 4 → 둘 다' `
        ((@($rowFirst, $rowConsume, $rowKeep, $rowFour) | ForEach-Object { '{0}+{1}' -f (Get-EntryText $_.Journal $NONCE_C), (Get-EntryText $_.Journal $NONCE_A) }) -join ' / ') `
        'cleared/pending/0+entered/done/0 / cleared/pending/1+entered/launched/0 / cleared/pending/1+entered/launched/0 / cleared/pending/1+entered/done/0'
    # E6 소비 owner: owner 모양(보류 Owner - 5필드 + generation)도 받음 · 다른 세대·다른 칸·적용된 항목·entered 는 소비 안 함
    $wrongGen = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation ($H_GENERATION + 1) -Section $ABYSS_SECTION -Nonce $NONCE_B
    $nextCleared = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_D
    $rowOwner = Invoke-EndRow -Setup @{ Custom = $true; DiskContext = $fixture.Now; Entries = @($clearedNow, $wrongGen, $nextCleared, $passed) } `
        -CallArgs @{ ExitCode = 0; Context = $fixture.OwnerNext; ConsumeOnly = $true }
    Assert-Case 'E6 owner 모양 -Context(i+1) → i+1 cleared 만 소비 (i·다른 세대·entered 는 그대로)' `
        ((@($NONCE_C, $NONCE_B, $NONCE_D, $NONCE_A) | ForEach-Object { Get-EntryText $rowOwner.Journal $_ }) -join ' · ') 'cleared/pending/0 · cleared/pending/0 · cleared/pending/1 · entered/launched/0'
    # E7 비커스텀은 이 실행 id 의 '클리어 이상' 만 소비 · 재입장 오류 연속: 0·11 성공 → 0 / 코드 10 → 그대로
    $plainCleared = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_C
    $otherCleared = New-FixtureEntry -Stage 'post-clear-stop' -Owner ([pscustomobject]@{ runId = 'run-other' }) -Nonce $NONCE_B
    $plainEntered = New-FixtureEntry -Stage 'entered' -Owner $runOwner -Nonce $NONCE_D
    $rowPlain = Invoke-EndRow -Setup @{ Entries = @($plainCleared, $otherCleared, $plainEntered); AbyssErrorStreak = 2 } -CallArgs @{ ExitCode = 0 }
    $rowPlain10 = Invoke-EndRow -Setup @{ Entries = @($plainCleared); AbyssErrorStreak = 2 } -CallArgs @{ ExitCode = 10 }
    Assert-Case 'E7 비커스텀 코드 0 → 이 실행의 cleared 소비 · 다른 실행·entered 그대로 · 재입장 오류 연속 2 → 0 || 코드 10 → 소비 · 연속 2 그대로' `
        ('{0} · {1} · {2} · {3} || {4} · {5}' -f (Get-EntryText $rowPlain.Journal $NONCE_C), (Get-EntryText $rowPlain.Journal $NONCE_B), (Get-EntryText $rowPlain.Journal $NONCE_D), $rowPlain.AbyssErrorStreak,
            (Get-EntryText $rowPlain10.Journal $NONCE_C), $rowPlain10.AbyssErrorStreak) 'cleared/pending/1 · post-clear-stop/pending/0 · entered/pending/0 · 0 || cleared/pending/1 · 2'
    # E8 실패 → 오류 정지 + 빨강 + 거짓 · 파일 그대로. 사용 중: 커스텀 0 첫 호출(진행 전진·기동) / 전진 뒤 -ConsumeOnly(기동) / 일반 코드 10(기동 ·
    #     기록 보존 - 단계 2.7) / 비커스텀 0·11(기동 · 기록 보존) / 코드 4(완료 표시를 남기지 못함 · 기록 보존 - 단계 2.7) · 손상 · 교체 실패 · 예외 ·
    #     사유에 재입장 표지가 있으면 꼬리 · 실패면 재입장 오류 연속 그대로 · 마무리 실행 기동의 끝은 '마무리 실행 완료 표시를 남기지 못함'
    $failRows = @(
        @{ N = '사용 중 · 커스텀 0 첫 호출'; Setup = ($customSetup + @{ LaunchNonce = $NONCE_A }); Args = @{ ExitCode = 0; Context = $fixture.Now }; Lock = $true; Want = $EXIT_LOCKED_ADVANCE }
        @{ N = '사용 중 · -ConsumeOnly'; Setup = $customSetup; Args = @{ ExitCode = 0; Context = $fixture.Now; ConsumeOnly = $true }; Lock = $true; Want = $STOP_LOCKED }
        # 일반 코드 10(단계 2.6 구현 리뷰가 2.7 로 넘긴 정리): 코드 10 은 계상하지 않고 마커도 건드리지 않아 못 한 일은 다음 기동뿐 - 옛 '계상·기동을
        # 보류 … (기록·마커 보존)' 은 실제 상태와 달랐음. 커스텀·비커스텀 같은 글자
        @{ N = '사용 중 · 코드 10'; Setup = $customSetup; Args = @{ ExitCode = 10 }; Lock = $true; Want = $EXIT_LOCKED_PLAIN }
        @{ N = '사용 중 · 코드 10 비커스텀'; Setup = @{ Entries = @($plainCleared) }; Args = @{ ExitCode = 10 }; Lock = $true; Want = $EXIT_LOCKED_PLAIN }
        @{ N = '사용 중 · 표지 있음'; Setup = $customSetup; Args = @{ ExitCode = 10 }; Lock = $true; Worker = ($IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_A)); Want = ($EXIT_LOCKED_PLAIN + $STOP_TAIL) }
        # 코드 4(단계 2.7): 계상은 이 끝 처리 앞(Invoke-Code4Accounting)에서 끝났고 코드 4 는 다음 기동이 없어 못 한 일은 완료 표시(소비·done)뿐
        @{ N = '사용 중 · 코드 4'; Setup = ($customSetup + @{ LaunchNonce = $NONCE_A }); Args = @{ ExitCode = 4; Context = $fixture.Now }; Lock = $true; Want = $C4_END_LOCKED }
        @{ N = '교체 실패 · 코드 4'; Setup = $customSetup; Args = @{ ExitCode = 4; Context = $fixture.Now }; MainRead = $true; Want = $C4_END_SAVE }
        @{ N = '예외 · 코드 4 비커스텀'; Setup = @{ Entries = @($plainCleared) }; Args = @{ ExitCode = 4 }; Throw = 1; Want = ('{0} (예외: {1})' -f $C4_END_SAVE, $INJECTED_UPDATE_EXCEPTION) }
        @{ N = '손상'; Setup = @{ Custom = $true; DiskContext = $fixture.Now; CorruptText = 'not json' }; Args = @{ ExitCode = 10 }; Want = $STOP_CORRUPT }
        @{ N = '교체 실패'; Setup = $customSetup; Args = @{ ExitCode = 10 }; MainRead = $true; Want = $EXIT_SAVE_FAIL }
        @{ N = '예외'; Setup = $customSetup; Args = @{ ExitCode = 10 }; Throw = 1; Want = ('{0} (예외: {1})' -f $EXIT_SAVE_FAIL, $INJECTED_UPDATE_EXCEPTION) }
        # 마무리 실행 기동의 끝(기동 종류 finish-only - 단계 2.6 구현 검증 · 명세 대조 P3-2): 기동할 다음 판이 없어 '완료 표시를 남기지 못하고 정지' -
        # 커스텀 0·11(완주 ⓐ·ⓑ - 대기열 반영 뒤)은 (진행은 반영됨), 비커스텀·코드 10 은 (기록 보존). 사용 중·저장 실패·예외가 같은 뒷부분
        @{ N = '사용 중 · 마무리 실행 커스텀 0 ⓐ'; Setup = ($customSetup + @{ LaunchKind = 'finish-only'; LaunchNonce = $NONCE_A }); Args = @{ ExitCode = 0; Context = $fixture.OwnerNext }; Lock = $true; Want = $FINISH_LOCKED_APPLIED }
        @{ N = '사용 중 · 마무리 실행 커스텀 11 ⓑ'; Setup = ($customSetup + @{ LaunchKind = 'finish-only' }); Args = @{ ExitCode = 11; Context = $fixture.OwnerNext; ConsumeOnly = $true }; Lock = $true; Want = $FINISH_LOCKED_APPLIED }
        @{ N = '사용 중 · 마무리 실행 비커스텀 0'; Setup = @{ Entries = @($plainCleared); LaunchKind = 'finish-only'; LaunchNonce = $NONCE_A }; Args = @{ ExitCode = 0 }; Lock = $true; Want = $FINISH_LOCKED_KEPT }
        @{ N = '사용 중 · 마무리 실행 코드 10'; Setup = ($customSetup + @{ LaunchKind = 'finish-only'; LaunchNonce = $NONCE_A }); Args = @{ ExitCode = 10 }; Lock = $true; Want = $FINISH_LOCKED_KEPT }
        @{ N = '교체 실패 · 마무리 실행 커스텀 0 ⓑ'; Setup = @{ Custom = $true; DiskContext = $fixture.Now; Entries = @($clearedNow, $passed, $nextCleared); LaunchKind = 'finish-only' }
            Args = @{ ExitCode = 0; Context = $fixture.OwnerNext; ConsumeOnly = $true }; MainRead = $true; Want = $FINISH_SAVE_APPLIED }
        @{ N = '예외 · 마무리 실행 비커스텀 0'; Setup = @{ Entries = @($plainCleared); LaunchKind = 'finish-only'; LaunchNonce = $NONCE_A }; Args = @{ ExitCode = 0 }; Throw = 1
            Want = ('{0} (예외: {1})' -f $FINISH_SAVE_KEPT, $INJECTED_UPDATE_EXCEPTION) }
        # 비커스텀 0·11 일반 끝 처리(단계 2.6 구현 리뷰 P3): 계상 +1 은 타이머가 이미 했고 진행 전진·완료 마커가 없어 사용 중도 '기동을 보류하고 정지
        # (기록 보존)' + 안내. 손상·교체 실패·예외는 원래 진행 전진·마커 표현이 없어 그 글자 그대로 - 이번 실행 id 의 cleared(소비할 것)를 두어 저장까지 감
        @{ N = '사용 중 · 비커스텀 0'; Setup = @{ Entries = @($plainCleared) }; Args = @{ ExitCode = 0 }; Lock = $true; Want = $EXIT_LOCKED_PLAIN }
        @{ N = '사용 중 · 비커스텀 11'; Setup = @{ Entries = @($plainCleared) }; Args = @{ ExitCode = 11 }; Lock = $true; Want = $EXIT_LOCKED_PLAIN }
        @{ N = '손상 · 비커스텀 0'; Setup = @{ CorruptText = 'not json' }; Args = @{ ExitCode = 0 }; Want = $STOP_CORRUPT }
        @{ N = '손상 · 비커스텀 11'; Setup = @{ CorruptText = 'not json' }; Args = @{ ExitCode = 11 }; Want = $STOP_CORRUPT }
        @{ N = '교체 실패 · 비커스텀 0'; Setup = @{ Entries = @($plainCleared) }; Args = @{ ExitCode = 0 }; MainRead = $true; Want = $EXIT_SAVE_FAIL }
        @{ N = '교체 실패 · 비커스텀 11'; Setup = @{ Entries = @($plainCleared) }; Args = @{ ExitCode = 11 }; MainRead = $true; Want = $EXIT_SAVE_FAIL }
        @{ N = '예외 · 비커스텀 0'; Setup = @{ Entries = @($plainCleared) }; Args = @{ ExitCode = 0 }; Throw = 1; Want = ('{0} (예외: {1})' -f $EXIT_SAVE_FAIL, $INJECTED_UPDATE_EXCEPTION) }
        # 오류 종료(코드 1·그 밖 - 단계 2.8): 타이머가 정지하기로 정한 경로(같은 항목 3회째 · 그 밖 오류)에서만 부르고 계상·소비가 없어 못 한 일은 넘긴 nonce 의
        # done 표시뿐 - 코드 4 와 같은 '완료 표시를 남기지 못하고 정지 (기록 보존)'. 넘긴 nonce 가 있어야 저장까지 감(소비는 안 함 - 명세 5절 A6ⓐ)
        @{ N = '사용 중 · 코드 1 커스텀'; Setup = ($customSetup + @{ LaunchNonce = $NONCE_A }); Args = @{ ExitCode = 1 }; Lock = $true; Want = $C4_END_LOCKED }
        @{ N = '교체 실패 · 코드 1 비커스텀'; Setup = @{ Entries = @($plainCleared); LaunchNonce = $NONCE_C }; Args = @{ ExitCode = 1 }; MainRead = $true; Want = $C4_END_SAVE }
        @{ N = '예외 · 코드 -1 커스텀'; Setup = ($customSetup + @{ LaunchNonce = $NONCE_A }); Args = @{ ExitCode = -1 }; Throw = 1; Want = ('{0} (예외: {1})' -f $C4_END_SAVE, $INJECTED_UPDATE_EXCEPTION) }
    )
    foreach ($failRow in $failRows) {
        $endArgs = @{ Setup = ($failRow.Setup + @{ AbyssErrorStreak = 2 }); CallArgs = $failRow.Args; WorkerReason = [string]$failRow.Worker; HoldLock = [bool]$failRow.Lock
            HoldMainRead = [bool]$failRow.MainRead; UpdateThrowAt = [int]$failRow.Throw }
        $row = Invoke-EndRow @endArgs
        Assert-Case ('E8 끝 처리 실패({0}) → 거짓 · 오류 정지 그 문구 · 빨강 · 파일 그대로 · 재입장 오류 연속 그대로' -f $failRow.N) `
            ('{0} · {1} · {2} · {3} · {4}' -f $row.Result, $row.Stops, $row.Color, $row.StateUnchanged, $row.AbyssErrorStreak) ('False · stop|{0}|True · Firebrick · 1 · 2' -f $failRow.Want)
    }
}

# ===== O 순서 주입 - 재입장 완료 줄이 통상 tail 뒤·HasExited 전에 쓰임 (R1-M14 의 행동 · dev:989 IH 폴백) =====
function Test-CaseExitOrder {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $clicked = New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -Nonce $NONCE_A
    $ihLine = '12:00:09 [완료] ' + $IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_A)
    # O1 기본 로그 - reentered 기록 실패(stage retry-clicked) + 표지 줄이 종료 직전에만 → 공통 최종 수집이 판별 앞에 잡음 → log 출처 재입장 → 보정 · 다음 판 기동
    Initialize-HandoffRow -Entries @($clicked)
    $row = Invoke-HandoffTick -ExitCode 0 -Plan @{ WorkerLines = @($ihLine) }
    # O1′ 복구 로그 변형 - 같은 줄이 복구 로그에만
    Initialize-HandoffRow -Entries @($clicked)
    $rowRecovery = Invoke-HandoffTick -ExitCode 0 -Plan @{ RecoveryLines = ($RECOVERY_HEAD + @($ihLine)) }
    Assert-Case 'O1 종료 직전 재입장 줄(기본 로그) → 판별 log → [경고] → 다음 판 기동 · 항목 보정 || O1′ 복구 로그에만 → 같음' `
        ('{0} · {1} · {2} || {3} · {4}' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A), $row.Nonce, $rowRecovery.Kind, (Get-EntryText $rowRecovery.Journal $NONCE_A)) `
        ('gui|=== 1회차 완료 === / gui|{0} / launch|powershell.exe / gui|=== 2회차 시작 === · reentered/launched/1 · NA || next · reentered/launched/1' -f $IH_LOG_WARNING)
}

# ===== B 안전 중지 취소 처리기 (명세 5절 B12 · 설계 R1 9절 미결 3 (가)) =====
function Test-CaseSafeStopCancel {
    $clicks = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Expression.Extent.Text -eq '$btnSafeStop') -and ($node.Member.Extent.Text -eq 'Add_Click') }, $true))
    Assert-Case 'B 추출: 안전 중지 버튼 처리기($btnSafeStop.Add_Click) 1개' $clicks.Count 1
    if ($clicks.Count -ne 1) { return }
    $handler = [scriptblock]::Create($clicks[0].Arguments[0].ScriptBlock.EndBlock.Extent.Text)
    $script:btnSafeStop = [pscustomobject]@{ Text = '' }
    $holdObject = @{ Kind = 'safe-stop'; Reason = '안전 중지'; IsError = $false; Owner = @{ runId = 'run-H' }; Position = ''; Snapshot = $null }
    $trail = @()
    foreach ($kind in @('finish-only', 'none')) {
        Initialize-HandoffRow -LaunchKind $kind -FinishOnlyHold $(if ($kind -eq 'finish-only') { $holdObject } else { $null })
        $script:safeStopFlag = Join-Path $script:rowFolder 'safe_stop.flag'
        [IO.File]::WriteAllText($script:safeStopFlag, 'stop')
        $script:stopRequested = $true
        $null = & $handler
        $guiLines = @(@($script:events) | Where-Object { $_.StartsWith('gui|') })
        $trail += ('{0}: {1} | B12 {2} · 계속 {3} · 예약 {4} · 보류 그대로 {5} · 플래그 {6}' -f $kind, ($guiLines -join ' / '), @($guiLines | Where-Object { $_ -ceq ('gui|' + $B12_NOTICE) }).Count,
            @($guiLines | Where-Object { $_ -ceq ('gui|' + $B12_PLAIN) }).Count, $script:stopRequested,
            [int]([object]::ReferenceEquals($script:finishOnlyHold, $(if ($kind -eq 'finish-only') { $holdObject } else { $null })) -or (($kind -ne 'finish-only') -and ($null -eq $script:finishOnlyHold))),
            [IO.File]::Exists($script:safeStopFlag))
    }
    Assert-Case 'B12 마무리 실행 중 취소 → 마무리 안내 1(반복 계속 줄 0) · 예약 해제 · 보류 그대로 || 일반 기동 → 반복 계속 1 · 마무리 안내 0' ($trail -join ' || ') `
        ('finish-only: gui|{0} | B12 1 · 계속 0 · 예약 False · 보류 그대로 1 · 플래그 False || none: gui|{1} | B12 0 · 계속 1 · 예약 False · 보류 그대로 1 · 플래그 False' -f $B12_NOTICE, $B12_PLAIN)
    # B12′ 취소 뒤 그 판의 완주(코드 0) = 보류 사유 정지 - 기동 종류 finish-only 그대로라 다음 회차 판단·기동 0 (명세 5절 B12 '보류·정지 계획은 그대로'.
    #      단계 2.6 구현 검증 - 생존 변이 B12-KIND: 위 행은 로그 줄·보류만 봐서, 취소가 기동 종류를 바꿔 완주가 일반 사슬로 가 다음 판을 띄우는 것을 못 가름)
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $launchedA = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    Initialize-HandoffRow -Entries @($launchedA) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $holdObject -StopRequested $true
    $script:safeStopFlag = Join-Path $script:rowFolder 'safe_stop.flag'
    [IO.File]::WriteAllText($script:safeStopFlag, 'stop')
    $null = & $handler
    $kindAfter = [string]$script:lastLaunchKind
    $row = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    Assert-Case "B12′ 마무리 실행 중 취소 → 기동 종류 finish-only 그대로 → 그 판 완주 = 보류 사유('안전 중지') 정지 · 판단·기동 0 · NA done" `
        ('{0} · {1} · {2} · {3}' -f $kindAfter, $row.Flow, $row.Launches, (Get-EntryText $row.Journal $NONCE_A)) 'finish-only · gui|=== 1회차 완료 === / stop|안전 중지|False · 0 · reentered/done/1'
}

# ===== RW 저장소 복구 경고 - 본 파일 손상 + 직전본 유효를 잠금 아래 재판독이 복구하면 그 경고를 부른 쪽이 GUI 로그로 남김(저장소 계약 - 로그는 호출부 몫) =====
# 단계 2.6 구현 검증 - 생존 변이 RD-WARN·E-WARN·IH-WARN: 세 호출부의 경고 줄을 지워도 잡는 행이 없었음. 판별 읽기 행(RW1)은 래퍼가 먼저 복구하므로 끝 처리
# (RW2)·실행부(RW3)는 함수를 직접 불러 그 저장이 손상을 처음 만나게 합니다
function Set-CorruptMainWithBackup {
    # 지금 행의 본 파일을 직전본으로 복사한 뒤 본 파일만 손상 - 다음 잠금 읽기·저장이 (c) 복구 경고 1줄을 돌려줌. 사건 열은 비움
    [IO.File]::Copy($script:abyssJournalPath, ($script:abyssJournalPath + '.bak'), $true)
    [IO.File]::WriteAllText($script:abyssJournalPath, '{ "version": 1, "seq": ', $UTF8_BOM)
    $script:events.Clear()
}

function Test-CaseExitRecoveryWarnings {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $reentered = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_A
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    $warningEvent = 'gui|' + $RECOVERED_WARNING
    # RW1 판별 읽기(Read-AbyssExitHandoff) → 복구 뒤 판별 inside-handoff/journal · 경고 1
    Initialize-HandoffRow -Entries @($reentered)
    Set-CorruptMainWithBackup
    $script:lastWorkerDoneReason = $READY_REASON
    $judged = Read-AbyssExitHandoff -ExitCode 0 -Context $null
    $judgeText = '{0}/{1} · {2}' -f $judged.Kind, $judged.Source, @($script:events | Where-Object { $_ -ceq $warningEvent }).Count
    # RW2 끝 처리 저장(커스텀 코드 10 - 지금 컨텍스트로 cleared(i) 소비) → 참 · 소비 · 경고 1
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    Set-CorruptMainWithBackup
    $endResult = @(Complete-AbyssExitJournal -ExitCode 10)
    $endText = '{0} · {1} · {2}' -f ($endResult -join ','), (Get-EntryText (Read-FixtureJournal -Path $script:abyssJournalPath) $NONCE_C), @($script:events | Where-Object { $_ -ceq $warningEvent }).Count
    # RW3 실행부 필수 기록 저장(비커스텀 재입장) → 경고 1 · 다음 판 기동 1 · 항목 reentered/launched/적용
    Initialize-HandoffRow -Entries @($reentered)
    Set-CorruptMainWithBackup
    Invoke-InsideHandoffExit -ExitCode 0 -Handoff @{ Kind = 'inside-handoff'; Nonce = $NONCE_A; Source = 'journal'; Reason = '' } -FinishedContext $null
    $recordText = '{0} · {1} · {2}' -f @($script:events | Where-Object { $_ -ceq $warningEvent }).Count, $script:launches.Count, (Get-EntryText (Read-FixtureJournal -Path $script:abyssJournalPath) $NONCE_A)
    Assert-Case 'RW1 판별 읽기 직전본 복구 → inside-handoff/journal · 경고 1 || RW2 끝 처리 저장 직전본 복구 → 참 · cleared(i) 소비 · 경고 1 || RW3 실행부 필수 기록 직전본 복구 → 경고 1 · 기동 1 · 항목 기록됨' `
        ('{0} || {1} || {2}' -f $judgeText, $endText, $recordText) 'inside-handoff/journal · 1 || True · cleared/pending/1 · 1 || 1 · 1 · reentered/launched/1'
}

# ===== S 정적 (단계 2.6 - 주석 뺀 GUI 사본) =====
function Get-GuiFunctionAstByName {
    param([string]$Name)
    return @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $Name) }, $true))[0]
}

function Test-CaseExitStatic {
    # S8 서명
    $signatureText = (@('Get-AbyssExitHandoffKind', 'Read-AbyssExitHandoff', 'Complete-AbyssExitJournal', 'Invoke-InsideHandoffExit', 'Complete-FinishOnlyCycle', 'Get-AbyssExitStopReason') |
            ForEach-Object { '{0}({1})' -f $_, (Get-ParamSignature $guiAst $_) }) -join ' / '
    Assert-Case 'S8 새 함수 서명 (명세 2.6 표 - 선택 인자는 형식 없이)' $signatureText `
        ('Get-AbyssExitHandoffKind(String $ReadStatus, Object $Journal, Object $Owner, Object $Generation, String $Reason) / Read-AbyssExitHandoff(Int32 $ExitCode, Object $Context) / ' +
        'Complete-AbyssExitJournal(Int32 $ExitCode, Object $Context, SwitchParameter $KeepLaunched, SwitchParameter $ConsumeOnly) / ' +
        'Invoke-InsideHandoffExit(Int32 $ExitCode, Object $Handoff, Object $FinishedContext) / Complete-FinishOnlyCycle(Int32 $ExitCode) / Get-AbyssExitStopReason(String $Reason, String $WorkerReason)')
    # S9 호출 소유자 (2.6 · 2.7 코드 4 계상이 끝 처리 1곳 · 2.8 코드 1 이 실행부 1곳(라우팅의 reentered)과 끝 처리 2곳(정지 경로 - 타이머)을 더함 ·
    #    2.9 시작 게이트 S0 가 대기열 반영 1곳을 더함 - 시작 쪽 행은 test_abyss_pending_advance)
    Assert-Case 'S9 호출 소유자: 판별 래퍼 = 타이머 · 순수부 = 래퍼 · 실행부 = 타이머 + 코드 1 라우팅 · 완주 = 타이머 · 끝 처리 = 타이머 5(0·11 · -ConsumeOnly · 코드 10 · 코드 1 정지 2) + 완주 3 + 코드 4 계상 · 대기열 = 실행부·완주 (+ 반영 = 시작 게이트 S0)' `
        ((@('Read-AbyssExitHandoff', 'Get-AbyssExitHandoffKind', 'Invoke-InsideHandoffExit', 'Complete-FinishOnlyCycle', 'Complete-AbyssExitJournal', 'Add-AbyssPendingEntry', 'Invoke-AbyssPendingAdvance') |
                ForEach-Object { Get-GuiCallOwners $_ }) -join ' / ') `
        ('1|(함수 밖) / 2|Read-AbyssExitHandoff,Read-AbyssExitHandoff / 2|(함수 밖),Invoke-Code1JournalRouting / 2|(함수 밖),(함수 밖) / ' +
        '9|(함수 밖),(함수 밖),(함수 밖),(함수 밖),(함수 밖),Complete-FinishOnlyCycle,Complete-FinishOnlyCycle,Complete-FinishOnlyCycle,Invoke-Code4Accounting / 2|Complete-FinishOnlyCycle,Invoke-InsideHandoffExit / ' +
        '2|Complete-FinishOnlyCycle,Invoke-AbyssStartJournalAdvance')
    # S10 H32a 코드 2·3 갈래 = 원문 그대로 · 완료 기록 접근 0 (마무리 실행 판별도 없음)
    $exitChains = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -ceq '($exitCode -eq 0) -or ($exitCode -eq 11)') }, $true))
    $code23 = ''
    if ($exitChains.Count -eq 1) {
        $code23 = (@($exitChains[0].Clauses | Where-Object { @('$exitCode -eq 2', '$exitCode -eq 3') -ccontains $_.Item1.Extent.Text } | ForEach-Object {
                    ((Remove-SourceComments -Text $_.Item2.Extent.Text) -replace '\s+', ' ').Trim() })) -join ' || '
    }
    Assert-Case 'S10 H32a 코드 2·3 갈래 원문(주석 뺌·공백 정규화) = 지금 그대로 · 완료 기록 접근·마무리 실행 판별 0' $code23 `
        ("{ Stop-AllRun -IsError '다른 자동화 인스턴스가 이미 실행 중 (중복 실행 방지) - 작업 관리자에서 powershell.exe(또는 꿀비노기)를 종료한 뒤 다시 시작해 주세요' `$lblStatus.ForeColor = [System.Drawing.Color]::Firebrick } || " +
        "{ Stop-AllRun '구현된 구간까지 완료 - 정지 (자세한 내용은 로그 참고)' `$lblStatus.ForeColor = [System.Drawing.Color]::SteelBlue }")
    # S11 리뷰 3 P1 자리: 커스텀 사슬에서 -ConsumeOnly 끝 처리 = 진행 저장 실패 갈래(if (-not $advanced) {…}) 뒤 · 마커 정리 앞 정확히 1
    $chainCode = $(if ($exitChains.Count -eq 1) { Remove-SourceComments -Text $exitChains[0].Clauses[0].Item2.Extent.Text } else { '' })
    $consumePattern = (@('$script:customRecoveryPending = $false', 'if (-not (Complete-AbyssExitJournal -ExitCode $exitCode -Context $finishedContext -ConsumeOnly)) { return }',
            'if (-not (Clear-CustomMarkerFile -Path $customMarkerFile)) {') | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    $failBlockAt = $chainCode.IndexOf('if (-not $advanced) {')
    $consumeAt = $chainCode.IndexOf('-ConsumeOnly)) { return }')
    Assert-Case 'S11 커스텀 사슬: 복구 대기 해제 → -ConsumeOnly 끝 처리 → 마커 정리 순서 1곳 · 진행 저장 실패 갈래 뒤 · 0·11 갈래의 -ConsumeOnly 1개' `
        ('{0} · {1} · {2}' -f [regex]::Matches($chainCode, $consumePattern).Count, [int](($failBlockAt -ge 0) -and ($consumeAt -gt $failBlockAt)), [regex]::Matches($chainCode, '-ConsumeOnly').Count) '1 · 1 · 1'
    # S12 실행부 구조(설계 R1 3.4 예외 계약): try 하나(catch 1 - 끝 문장 return) · 기동(Start-NextCycle)은 try 밖 마지막 문장 하나에만 · try 안 기동 0
    $insideAst = Get-GuiFunctionAstByName 'Invoke-InsideHandoffExit'
    $insideStatements = @($insideAst.Body.EndBlock.Statements)
    $insideTries = @($insideAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true))
    $lastStatement = $insideStatements[-1]
    $launchesInLast = @($lastStatement.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Start-NextCycle') }, $true)).Count
    $launchesInTry = $(if ($insideTries.Count -ge 1) { @($insideTries[0].Body.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Start-NextCycle') }, $true)).Count } else { -1 })
    $catchLast = $(if ($insideTries.Count -ge 1 -and $insideTries[0].CatchClauses.Count -ge 1) { (@($insideTries[0].CatchClauses[0].Body.Statements)[-1].Extent.Text) } else { '' })
    Assert-Case 'S12 실행부: try 1 · catch 1 · catch 끝 = return · try 안 기동 0 · 마지막 문장(if) 안 기동 2(마무리 실행·다음 판)' `
        ('{0} · {1} · {2} · {3} · {4}/{5}' -f $insideTries.Count, $(if ($insideTries.Count -ge 1) { $insideTries[0].CatchClauses.Count } else { 0 }), $catchLast, $launchesInTry, $lastStatement.GetType().Name, $launchesInLast) `
        '1 · 1 · return · 0 · IfStatementAst/2'
    # S13 새 함수의 클로저(-Expect·-Mutator)는 $script: 를 읽지 않음 · try 마다 catch 1개 이하(규칙 3 - 2개까지)
    $closureFacts = foreach ($functionName in @('Complete-AbyssExitJournal', 'Invoke-InsideHandoffExit', 'Invoke-Code1JournalRouting')) {
        $functionAst = Get-GuiFunctionAstByName $functionName
        $closures = @($functionAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -eq 'GetNewClosure') }, $true))
        $scriptReads = 0
        foreach ($closure in $closures) { $scriptReads += [regex]::Matches((Remove-SourceComments -Text $closure.Expression.Extent.Text), '\$script:').Count }
        '{0}:{1}/{2}' -f $functionName, $closures.Count, $scriptReads
    }
    $catchCounts = foreach ($functionName in @('Read-AbyssExitHandoff', 'Complete-AbyssExitJournal', 'Invoke-InsideHandoffExit', 'Complete-FinishOnlyCycle', 'Invoke-Code4Accounting', 'Invoke-Code1JournalRouting')) {
        '{0}:{1}' -f $functionName, ((@((Get-GuiFunctionAstByName $functionName).FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)) | ForEach-Object { $_.CatchClauses.Count }) -join ',')
    }
    # 코드 4 계상(단계 2.7)·코드 1 라우팅(단계 2.8)은 try 둘(바깥 = 처리 전체 · 안 = 완료 기록 잠금 읽기 - 읽기 예외를 읽기 실패로 받음), 각 catch 1개.
    # 코드 1 라우팅의 클로저 2개 = 재개 횟수 기록의 -Expect·-Mutator(켜진 빌드 갈래)
    Assert-Case 'S13 클로저 수/그 안 $script: 수 · 함수별 try 의 catch 수' ('{0} · {1}' -f ($closureFacts -join ' '), ($catchCounts -join ' ')) `
        ('Complete-AbyssExitJournal:1/0 Invoke-InsideHandoffExit:2/0 Invoke-Code1JournalRouting:2/0 · Read-AbyssExitHandoff:1 Complete-AbyssExitJournal:1 Invoke-InsideHandoffExit:1 ' +
        'Complete-FinishOnlyCycle:1 Invoke-Code4Accounting:1,1 Invoke-Code1JournalRouting:1,1')
    # S14 '완료 기록 파일이 사용 중' 으로 멈추는 문구는 전부 잠금 파일 안내를 붙임(단계 2.4~2.5a 구현 리뷰 조건). 글자를 '포함' 으로 셉니다 - 2.9 시작 게이트의
    #     '[오류] 완료 기록 파일이 사용 중입니다 - …' 처럼 태그·어미가 붙은 문구도 걸리게, 변수를 끼운 큰따옴표 문자열도 함께(단계 2.6 구현 검증 - 명세 대조 P3-3:
    #     '- 로 시작' 으로 세면 2.9 문구가 빠졌음). 2.7~2.9 가 문구를 더하면 개수 기대값을 그 단계가 고칩니다(2.7 - 코드 4 계상의 읽기 실패 문구 +1 ·
    #     2.8 - 코드 1 라우팅의 읽기 실패·재개 횟수 기록 실패 문구 +2. 판별 문구는 비커스텀·커스텀이 한 글자 틀을 같이 써 그대로 1 · 2.9 - 시작 게이트
    #     S0·S3 의 '사용 중입니다' 시작 거부 문구 +1: 두 자리가 거부 문구 함수 하나(Get-AbyssStartJournalRefusal)를 같이 씀)
    $lockedLiterals = @($guiAst.FindAll({ param($node) (($node -is [System.Management.Automation.Language.StringConstantExpressionAst]) -or
                    ($node -is [System.Management.Automation.Language.ExpandableStringExpressionAst])) -and $node.Value.Contains('완료 기록 파일이 사용 중') }, $true))
    $withoutGuide = @($lockedLiterals | Where-Object {
            $statement = $_.Parent
            while ($null -ne $statement -and -not ($statement -is [System.Management.Automation.Language.StatementAst] -and $statement.Parent -is [System.Management.Automation.Language.StatementBlockAst])) { $statement = $statement.Parent }
            -not ($null -ne $statement -and $statement.Extent.Text.Contains('Get-AbyssJournalLockedGuide'))
        })
    Assert-Case "S14 '완료 기록 파일이 사용 중' 을 담은 문자열(기동·판별·끝 처리·실행부·코드 4 계상·코드 1 라우팅 2·시작 게이트 S0·S3 '사용 중입니다' 1) 8개 · 잠금 파일 안내 없는 문장 0" ('{0} · {1}' -f $lockedLiterals.Count, $withoutGuide.Count) '8 · 0'
    Assert-Case 'S14 잠금 파일 안내 글자' (Get-AbyssJournalLockedGuide) $LOCKED_GUIDE
    # S15 N/A 근거(설계 R1 H44·H46·H47): 커스텀은 시작 때 지정 시각을 끄고(UNTIL 미전달) 판단 워커 판정에서 빠짐 · 어비스 혼자하기는 UNTIL 을 받지
    #     않아 워커가 시간 판단을 할 수 없음 · 이 빌드 워커는 재입장 표지를 내지 않음(코드 11 재입장 없음)
    $startCode = Remove-SourceComments -Text (@(Get-SourceFunctionDefinitions -Path $guiPath -Names @('Invoke-StartAutomation'))[0])
    $judgeCode = Remove-SourceComments -Text $guiFunctionTexts['Test-WorkerTimeJudgeActive']
    Set-RadioModel -Content 'abyss'
    $script:mainCategory = 'battle'
    $script:customActive = $false
    $soloJudge = Test-WorkerTimeJudgeActive
    $workerText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))
    Assert-Case 'S15 H46·H47 커스텀 지정 시각 해제 1 · 판단 워커에서 커스텀 제외 1 · H44 어비스 혼자하기 UNTIL 대상 아님 · 워커 재입장 표지 0' `
        ('{0} · {1} · {2} · {3}' -f [regex]::Matches($startCode, [regex]::Escape('if ($script:customActive) { $script:targetCycles = 0; $script:targetTime = $null }')).Count,
            [int]$judgeCode.Contains('(-not $script:customActive)'), $soloJudge, [regex]::Matches($workerText, 'terminal=InsideHandoff').Count) '1 · 1 · False · 0'
}

# ===== W 표지 판별 Get-WorkerDoneMarkers (명세 2.7 ① - 순수, 코드 0·11 재입장 판별과 같은 함수) =====
function Test-CaseDoneMarkers {
    # 결과 '사용 중/선택 화면/ESC 메뉴/클리어 뒤/재입장 nonce' - 사유는 워커 [완료] 원문(화면 변환 전)
    $markerRows = @(
        @{ N = 'W1 표지 없음'; Reason = $CODE4_REASON; Want = 'False/False/False/False/' }
        @{ N = 'W2 사용 중'; Reason = ($CODE4_REASON + ' (locked)'); Want = 'True/False/False/False/' }
        @{ N = 'W3 선택 화면'; Reason = ($CODE4_REASON + ' (selection-overlay)'); Want = 'False/True/False/False/' }
        @{ N = 'W4 ESC 메뉴'; Reason = ($CODE4_REASON + ' (menu-overlay)'); Want = 'False/False/True/False/' }
        @{ N = 'W5 클리어 뒤'; Reason = ($CODE4_REASON + ' (post-clear)'); Want = 'False/False/False/True/' }
        @{ N = 'W6 재입장 nonce(소문자)'; Reason = ($IH_REASON + ($IH_TAIL_FORMAT -f $IH_NONCE_LOWER)); Want = ('False/False/False/False/{0}' -f $IH_NONCE_LOWER) }
        @{ N = 'W7 재입장 nonce(대문자)'; Reason = ($IH_REASON + ($IH_TAIL_FORMAT -f $IH_NONCE_UPPER)); Want = ('False/False/False/False/{0}' -f $IH_NONCE_UPPER) }
        @{ N = 'W8 빈 사유'; Reason = ''; Want = 'False/False/False/False/' }
        # 표지 글자는 앞 공백 + 괄호 + 그 낱말 + 닫는 괄호까지 - 공백 없는 괄호·다른 낱말·더 긴 낱말은 표지가 아님
        @{ N = 'W9 비슷한 글자'; Reason = '사용자 조작(locked) 감지 (unlocked) (post-clear-stop) (selection) (menu)'; Want = 'False/False/False/False/' }
        @{ N = 'W10 nonce 꼴이 아닌 재입장 꼬리'; Reason = ($IH_REASON + ' [terminal=InsideHandoff nonce=]'); Want = 'False/False/False/False/' }
    )
    foreach ($markerRow in $markerRows) {
        $markers = Get-WorkerDoneMarkers -Reason $markerRow.Reason
        Assert-Case ('{0} → 사용 중/선택 화면/ESC 메뉴/클리어 뒤/재입장 nonce' -f $markerRow.N) `
            ('{0}/{1}/{2}/{3}/{4}' -f $markers.Locked, $markers.SelectionOverlay, $markers.MenuOverlay, $markers.PostClear, $markers.InsideHandoffNonce) $markerRow.Want
    }
}

# ===== P4 계상 결정 Get-Code4JournalPlan · 끝 정지 계획 Get-Code4StopPlan (명세 2.7 ③⑥ - 순수) =====
function New-PlanJournal {
    # 결정 진리표용 메모리 journal - 실제 빈 journal 위에 항목·applied
    param([object[]]$Entries = @(), [object[]]$Applied = @())
    $journal = New-AbyssJournalEmpty
    $journal.entries = [object[]]@($Entries)
    $journal.applied = [object[]]@($Applied)
    return $journal
}

function Test-CaseCode4Plan {
    $fixture = Get-CustomFixture
    $runOwner = [pscustomobject]@{ runId = 'run-P' }
    $runContext = @{ runId = 'run-P' }
    $runCleared = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_A
    $runClearedNewer = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_B
    $customCleared = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    $okArgs = @{ InRange = $true; ReadStatus = 'ok'; Owner = $runContext }
    $planRows = @(
        # ① 마커 경로는 범위·읽기와 무관(예전 갈래 그대로)
        @{ N = 'P1 마커 유효 · 읽기 사용 중이어도'; Args = @{ MarkerValid = $true; InRange = $true; ReadStatus = 'locked' }; Want = 'marker/' }
        @{ N = 'P1′ 마커 유효 · 범위 밖(던전 커스텀)'; Args = @{ MarkerValid = $true; InRange = $false }; Want = 'marker/' }
        # 범위 밖이면 기록 규칙 없음(사유 표지도) - 어비스 밖 실행은 완료 기록을 열지 않음
        @{ N = 'P2 범위 밖 + 클리어 뒤 표지'; Args = @{ InRange = $false; PostClear = $true }; Want = 'none/' }
        # 읽기 실패 = 기록 규칙(②③④) 셋 다 보류 - 유효 기록·표지가 있어도
        @{ N = 'P3 읽기 사용 중 + 유효 기록 + 표지'; Args = @{ InRange = $true; ReadStatus = 'locked'; Journal = (New-PlanJournal -Entries @($runCleared)); Owner = $runContext; PostClear = $true }; Want = 'held/' }
        @{ N = 'P3′ 읽기 손상'; Args = @{ InRange = $true; ReadStatus = 'corrupt'; Owner = $runContext }; Want = 'held/' }
        @{ N = 'P3″ 읽기 실패'; Args = @{ InRange = $true; ReadStatus = 'io-failed'; Owner = $runContext }; Want = 'held/' }
        @{ N = 'P3‴ 읽기 예외'; Args = @{ InRange = $true; ReadStatus = 'error'; Owner = $runContext }; Want = 'held/' }
        # ③ 비커스텀 - 이번 실행 id 의 미적용 '클리어 이상' 기록
        @{ N = 'P4 비커스텀 클리어 기록'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @($runCleared)) }); Want = 'journal/NA' }
        @{ N = 'P4′ 유효 기록 둘 → 가장 최근'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @($runCleared, $runClearedNewer)) }); Want = 'journal/NB' }
        @{ N = 'P4″ 적용된 기록 → 0'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @($runCleared) -Applied @($NONCE_A)) }); Want = 'none/' }
        @{ N = 'P4‴ 클리어 전(entered) → 0'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @(New-FixtureEntry -Stage 'entered' -Owner $runOwner -Nonce $NONCE_A)) }); Want = 'none/' }
        @{ N = 'P4⁗ 다른 실행 id → 0'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @(New-FixtureEntry -Stage 'cleared' -Owner ([pscustomobject]@{ runId = 'run-other' }) -Nonce $NONCE_A)) }); Want = 'none/' }
        # '클리어 이상' 단계(설계 v10 6.1 '유효' 정의) - 재입장 요청·재입장·클리어 뒤 정지도 클리어를 지난 판 / 모르는 단계는 아님
        @{ N = 'P4 단계 retry-clicked'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @(New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -Nonce $NONCE_A)) }); Want = 'journal/NA' }
        @{ N = 'P4 단계 reentered'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @(New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_A)) }); Want = 'journal/NA' }
        @{ N = 'P4 단계 post-clear-stop'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @(New-FixtureEntry -Stage 'post-clear-stop' -Owner $runOwner -Nonce $NONCE_A)) }); Want = 'journal/NA' }
        @{ N = 'P4 모르는 단계'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @(New-FixtureEntry -Stage 'mystery' -Owner $runOwner -Nonce $NONCE_A)) }); Want = 'none/' }
        # ② 커스텀 - 진입 컨텍스트 i 의 5필드 + 세대
        @{ N = 'P5 커스텀 같은 판·세대'; Args = @{ InRange = $true; ReadStatus = 'ok'; Journal = (New-PlanJournal -Entries @($customCleared)); Owner = $fixture.OwnerNow; Generation = $H_GENERATION }; Want = 'journal/NC' }
        @{ N = 'P5′ 커스텀 세대 다름 → 0'; Args = @{ InRange = $true; ReadStatus = 'ok'; Journal = (New-PlanJournal -Entries @($customCleared)); Owner = $fixture.OwnerNow; Generation = ($H_GENERATION + 1) }; Want = 'none/' }
        @{ N = 'P5″ 커스텀 다른 칸(i+1) → 0'; Args = @{ InRange = $true; ReadStatus = 'ok'; Journal = (New-PlanJournal -Entries @($customCleared)); Owner = $fixture.OwnerNext; Generation = $H_GENERATION }; Want = 'none/' }
        # 진입 컨텍스트 없음(명세 5절 B13) - 같은 판 기록이 있어도 대조하지 않음 · 사유 표지는 표지대로(명세 5절 B2)
        @{ N = 'P6 컨텍스트 없음 + 같은 판 기록'; Args = @{ InRange = $true; ReadStatus = 'ok'; Journal = (New-PlanJournal -Entries @($customCleared)); Owner = $null; Generation = $H_GENERATION }; Want = 'none/' }
        @{ N = 'P6′ 컨텍스트 없음 + 클리어 뒤 표지'; Args = @{ InRange = $true; ReadStatus = 'ok'; Journal = (New-PlanJournal -Entries @($customCleared)); Owner = $null; PostClear = $true }; Want = 'post-clear/' }
        # ④ 유효 기록 없음 + 표지 → 표지로 / 유효 기록이 있으면 기록이 이김(한 번만 셈) / ⑤ 둘 다 없음 → 0
        @{ N = 'P7 기록 없음 + 표지'; Args = ($okArgs + @{ Journal = (New-PlanJournal); PostClear = $true }); Want = 'post-clear/' }
        @{ N = 'P7′ 유효 기록 + 표지 → 기록'; Args = ($okArgs + @{ Journal = (New-PlanJournal -Entries @($runCleared)); PostClear = $true }); Want = 'journal/NA' }
        @{ N = 'P8 기록 없음 · 표지 없음'; Args = ($okArgs + @{ Journal = (New-PlanJournal) }); Want = 'none/' }
    )
    foreach ($planRow in $planRows) {
        $planArgs = $planRow.Args
        $plan = Get-Code4JournalPlan @planArgs
        Assert-Case ('{0} → 결정/기록 nonce' -f $planRow.N) ('{0}/{1}' -f $plan.Rule, (Get-NonceLabel ([string]$plan.Nonce))) $planRow.Want
    }
    # P9 끝 정지 계획(설계 v11 R1 3.7 표 4행 · H32d·H32e): 마무리 실행 기동 + 오류 보류일 때만 '사유 (마무리 실행 전 오류: 보류 사유)' 오류 정지
    $codeReason = '조건 정지: ' + $CODE4_REASON
    $stopRows = @(
        @{ N = '기동 종류 없음'; Kind = 'none'; Hold = $null; Want = ('{0}|False' -f $codeReason) }
        @{ N = 'H32d 마무리 실행 · 오류 보류'; Kind = 'finish-only'; Hold = @{ IsError = $true; Reason = '커스텀 진행 기록 저장 실패' }
           Want = ('{0}|True' -f ($C4_PRIOR_ERROR_FORMAT -f $codeReason, '커스텀 진행 기록 저장 실패')) }
        @{ N = 'H32e 마무리 실행 · 비오류 보류'; Kind = 'finish-only'; Hold = @{ IsError = $false; Reason = '안전 중지' }; Want = ('{0}|False' -f $codeReason) }
        @{ N = '마무리 실행 아님 · 오류 보류 객체'; Kind = 'next'; Hold = @{ IsError = $true; Reason = 'x' }; Want = ('{0}|False' -f $codeReason) }
        @{ N = '마무리 실행 · 보류 없음'; Kind = 'finish-only'; Hold = $null; Want = ('{0}|False' -f $codeReason) }
    )
    foreach ($stopRow in $stopRows) {
        $stopPlan = Get-Code4StopPlan -Code4Reason $codeReason -LaunchKind $stopRow.Kind -Hold $stopRow.Hold
        Assert-Case ('P9 끝 정지 계획 {0} → 사유|오류' -f $stopRow.N) ('{0}|{1}' -f $stopPlan.Reason, $stopPlan.IsError) $stopRow.Want
    }
}

# ===== C4 행동 - 코드 4 계상 (설계 v10 6.1 'GUI 계상 규칙(코드 4)' · dev:989 GUI 몫 · 명세 2.7 ③④) =====
function Write-ContextMarker {
    # 이 행의 완료 마커 = 그 판의 소유자 JSON(version 3 - 실제 New-CustomMarkerOwnerJson, 워커 Write-CustomClearMarker 가 쓰는 모양)
    param($Context)
    [IO.File]::WriteAllText($script:customMarkerFile, (New-CustomMarkerOwnerJson -Context $Context), $UTF8_NO_BOM)
}

function Test-CaseCode4Count {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $doneNow = 'gui|[커스텀] {0} 항목 완료' -f $fixture.Now.Position
    $tokenNow = Format-CustomItemToken -Item $ABYSS_ITEMS[0]
    $cleared = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_A
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C

    # C4-1 비커스텀 · 이번 실행의 클리어 기록 → +1 정확히 1 · 완료 줄 · 그 기록 소비 · 정상 정지(SteelBlue) · 읽기 1·저장 1
    Initialize-HandoffRow -Entries @($cleared)
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-1 비커스텀 클리어 기록 → 완료 줄 → 정상 정지 · 계상 1 · 기록 소비 · 읽기 1·저장 1 · SteelBlue' `
        ('{0} · {1} · {2} · {3}/{4} · {5}' -f $row.Flow, $row.Completed, (Get-EntryText $row.Journal $NONCE_A), $row.Reads, $row.Updates, $row.Color) `
        ('gui|=== 1회차 완료 === / {0} · 1 · cleared/pending/1 · 1/1 · SteelBlue' -f $C4_STOP)
    # C4-1′ 나가기 위치 미발견(워커 보상 화면 헬퍼의 코드 4 - 클리어 기록 뒤의 조건 정지, 재입장 기능 꺼짐) → +1 · 소비 · 정상 정지 1번
    Initialize-HandoffRow -Entries @($cleared)
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $C4_EXIT_HELPER_REASON
    Assert-Case "C4-1′ 나가기 위치 미발견 코드 4 → 계상 1 · 기록 소비 · 정상 정지 1번" `
        ('{0} · {1} · {2}' -f $row.Completed, (Get-EntryText $row.Journal $NONCE_A), ((@(Get-StopEvents $row) | ForEach-Object { $_.Substring($_.LastIndexOf('|') + 1) }) -join ',')) '1 · cleared/pending/1 · False'
    # C4-2 같은 기록으로 코드 4 를 두 번 처리 → 두 번째는 계상 0 (첫 끝 처리가 소비 - 같은 판을 두 번 세지 않음. 실행 상태만 되살려 소비의 멱등성을 봄)
    Initialize-HandoffRow -Entries @($cleared)
    $first = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    $script:running = $true
    $second = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-2 같은 기록 두 번 → 계상 1 → 1 · 두 번째 흐름 = 정지만' ('{0} → {1} · {2}' -f $first.Completed, $second.Completed, $second.Flow) ('1 → 1 · {0}' -f $C4_STOP)
    # C4-3 클리어 전(entered 만) → 0 · 기록 그대로 || 완료 기록 파일 없음 → 0 · 파일 생성 0
    Initialize-HandoffRow -Entries @(New-FixtureEntry -Stage 'entered' -Owner $runOwner -Nonce $NONCE_A)
    $rowEntered = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow
    $rowNoFile = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-3 클리어 전(entered) → 정지만 · 계상 0 · 기록 그대로 || 기록 파일 없음 → 계상 0 · 파일 생성 0' `
        ('{0} · {1} · {2} || {3} · {4} · {5}' -f $rowEntered.Flow, $rowEntered.Completed, (Get-EntryText $rowEntered.Journal $NONCE_A), $rowNoFile.Flow, $rowNoFile.Completed, $rowNoFile.StateUnchanged) `
        ('{0} · 0 · entered/pending/0 || {0} · 0 · 1' -f $C4_STOP)
    # C4-4 다른 실행 id 의 클리어 기록 → 0 · 그대로 || C4-5 커스텀 같은 칸·다른 세대 → 0 · 전진 0 · 그대로
    Initialize-HandoffRow -Entries @(New-FixtureEntry -Stage 'cleared' -Owner ([pscustomobject]@{ runId = 'run-other' }) -Nonce $NONCE_B)
    $rowRun = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @(New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation ($H_GENERATION + 1) -Section $ABYSS_SECTION -Nonce $NONCE_C)
    $rowGen = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-4 실행 id 불일치 → 계상 0 · 그대로 || C4-5 커스텀 세대 불일치 → 계상 0 · 전진 0 · 그대로' `
        ('{0} · {1} · {2} || {3} · {4} · {5} · {6}' -f $rowRun.Flow, $rowRun.Completed, (Get-EntryText $rowRun.Journal $NONCE_B), $rowGen.Flow, $rowGen.Completed, $rowGen.Steps, (Get-EntryText $rowGen.Journal $NONCE_C)) `
        ('{0} · 0 · cleared/pending/0 || {0} · 0 · 0 · cleared/pending/0' -f $C4_STOP)

    # C4-6 커스텀 + 유효 완료 마커 + 같은 판의 클리어 기록 → 마커 경로 1(완료 줄 · PREV · 전진 · 마커 정리) · 기록은 소비만(owner = 전진 전 i) · 진행 위치 읽기
    #      2 = 진입 1번 + 마커 유효 판정 1번(마커 경로는 진입 값을 씀 - 다시 읽지 않음)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    Write-ContextMarker -Context $fixture.Now
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-6 커스텀 마커 유효 + 기록 → 항목 완료 줄 → 전진 → 정지 · 계상 1 · 전진 1 · 마커 정리 1 · 기록 소비(전진 전 owner) · 진행 1/1 · PREV = 끝난 판 · 위치 읽기 2' `
        ('{0} · {1} · {2} · {3} · {4} · {5} · {6} · {7}' -f $row.Flow, $row.Completed, $row.Steps, $row.MarkerClears, (Get-EntryText $row.Journal $NONCE_C), $row.Disk, [int]($row.PrevItem -ceq $tokenNow),
            $row.ContextReads) `
        ('{0} / step / {1} · 1 · 1 · 1 · cleared/pending/1 · 1/1 · 1 · 2' -f $doneNow, $C4_STOP)
    # C4-7 커스텀 + 마커 없음(못 씀) + 같은 판의 클리어 기록 → 기록 경로 1(완료 줄 · 전진) · 마커 정리 0 · 소비 || C4-7′ 마커가 유효해도 이번 실행이 무시
    #      중이면 같은 기록 경로(무시 판단 = 앞 기동의 마커 정리 실패)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    Write-ContextMarker -Context $fixture.Now
    $script:customMarkerIgnore = $true
    $rowIgnore = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    # C4-7″ 남은 마커가 다른 칸(i+1)의 것 → 무효(파일 존재가 아니라 지금 항목의 소유자 마커인지로 판단 - 2026-08-09 6차 점검) → 같은 기록 경로 · 마커 정리 0
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    Write-ContextMarker -Context $fixture.Next
    $rowStale = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-7 마커 없음 + 기록 → 항목 완료 줄 → 전진 → 정지 · 계상 1 · 마커 정리 0 · 소비 · 1/1 || C4-7′ 마커 무시 중 · C4-7″ 다른 칸의 마커 → 같은 기록 경로' `
        ('{0} · {1} · {2} · {3} · {4} || {5} · {6} · {7} · {8} || {9} · {10} · {11} · {12}' -f $row.Flow, $row.Completed, $row.MarkerClears, (Get-EntryText $row.Journal $NONCE_C), $row.Disk,
            $rowIgnore.Flow, $rowIgnore.Completed, $rowIgnore.MarkerClears, (Get-EntryText $rowIgnore.Journal $NONCE_C),
            $rowStale.Flow, $rowStale.Completed, $rowStale.MarkerClears, (Get-EntryText $rowStale.Journal $NONCE_C)) `
        ('{0} / step / {1} · 1 · 0 · cleared/pending/1 · 1/1 || {0} / step / {1} · 1 · 0 · cleared/pending/1 || {0} / step / {1} · 1 · 0 · cleared/pending/1' -f $doneNow, $C4_STOP)
    # C4-8 기록 경로 + 진행 저장 실패 → 기록을 건드리지 않고 오류 정지(기록 보존 문구) · 끝 처리 0 || C4-8′ 마커 경로 + 저장 실패 → 예전 글자(마커 보존) · 소비 0
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow) -StepFailures 1
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow) -StepFailures 1
    Write-ContextMarker -Context $fixture.Now
    $rowMarker = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-8 기록 경로 전진 실패 → 정지(기록 보존) · 빨강 · 기록 그대로 · 저장 0 · 진행 1/0 || C4-8′ 마커 경로 전진 실패 → 정지(마커 보존) · 마커 정리 0 · 기록 그대로' `
        ('{0} · {1} · {2} · {3} · {4} || {5} · {6} · {7}' -f $row.Flow, $row.Color, (Get-EntryText $row.Journal $NONCE_C), $row.Updates, $row.Disk,
            $rowMarker.Flow, $rowMarker.MarkerClears, (Get-EntryText $rowMarker.Journal $NONCE_C)) `
        ('{0} / step / stop|{1}|True · Firebrick · cleared/pending/0 · 0 · 1/0 || {0} / step / stop|{2}|True · 0 · cleared/pending/0' -f $doneNow, $C4_STEP_FAIL_JOURNAL, $C4_STEP_FAIL_MARKER)
    # C4-9 코드 0 이 이미 소비한 기록 → 그 뒤 코드 4 는 추가 계상 0
    Initialize-HandoffRow -Entries @($cleared)
    $zero = Invoke-HandoffTick -ExitCode 0 -Reason $READY_REASON
    $script:running = $true
    $four = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-9 코드 0 뒤 남은 기록(소비됨) → 코드 4 추가 계상 0' ('{0} · {1} → {2} · {3}' -f (Get-EntryText $zero.Journal $NONCE_A), $zero.Completed, $four.Completed, $four.Flow) `
        ('cleared/pending/1 · 1 → 1 · {0}' -f $C4_STOP)
    # C4-10 사유 표지 폴백: 유효한 기록 없음 + ' (post-clear)' → +1 + [경고] (비커스텀 / 커스텀 - 전진 0, 명세 5절 B2) || 유효한 기록 + 표지 → 기록 규칙 1번(경고 0)
    $postReason = $CODE4_REASON + ' (post-clear)'
    $postStop = 'stop|조건 정지: {0}|False' -f $postReason
    Initialize-HandoffRow
    $rowPlain = Invoke-HandoffTick -ExitCode 4 -Reason $postReason
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now
    $rowCustom = Invoke-HandoffTick -ExitCode 4 -Reason $postReason
    Initialize-HandoffRow -Entries @($cleared)
    $rowBoth = Invoke-HandoffTick -ExitCode 4 -Reason $postReason
    Assert-Case 'C4-10 표지 폴백 비커스텀 → [경고] · 계상 1 || 커스텀 → [경고] · 계상 1 · 전진 0 || 기록 + 표지 → 완료 줄 · 계상 1 · 경고 0' `
        ('{0} · {1} || {2} · {3} · {4} || {5} · {6}' -f $rowPlain.Flow, $rowPlain.Completed, $rowCustom.Flow, $rowCustom.Completed, $rowCustom.Steps, $rowBoth.Flow, $rowBoth.Completed) `
        ('gui|{0} / {1} · 1 || gui|{0} / {1} · 1 · 0 || gui|=== 1회차 완료 === / {1} · 1' -f $C4_POST_CLEAR_WARNING, $postStop)
}

# ===== C4 행동 - 재전달 예외 · 재개 보류 · 순서 주입 · 끝 정지 계획 (설계 v10 6.1 · v11 R1 3.7 표 4행 · 명세 5절 B1) =====
function Test-CaseCode4Relay {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $doneNow = 'gui|[커스텀] {0} 항목 완료' -f $fixture.Now.Position
    $ownEntry = New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $nextEntry = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNext -NextOwner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_B

    # C4-11 재전달 예외 ' (locked)'(워커가 완료 기록을 못 읽어 넘겨받은 항목을 못 씀) - 커스텀 own 기동(넘긴 nonce NA): 계상 0 · 전진 0 · 마커 정리 0 ·
    #       NA launched 그대로 → 다음 기동의 후보 고르기(실제 함수)가 같은 항목(own/NA)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($ownEntry) -LaunchKind 'own' -LaunchNonce $NONCE_A
    $row = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (locked)')
    $again = Invoke-RealResolveHandoffEnv -Context $fixture.OwnerNow
    Assert-Case "C4-11 커스텀 own + ' (locked)' → 계상 0 · 전진 0 · 마커 정리 0 · NA launched 그대로 · 다음 기동 후보 = 같은 항목" `
        ('{0}/{1}/{2} · {3} · {4}/{5}/{6}' -f $row.Completed, $row.Steps, $row.MarkerClears, (Get-EntryText $row.Journal $NONCE_A), $again.Status, $again.Kind, (Get-NonceLabel ([string]$again.Nonce))) `
        '0/0/0 · entered/launched/0 · ok/own/NA'
    # C4-11′ 비커스텀 next + ' (locked)' → NA launched 그대로(같은 규칙) - 다음 수동 시작은 새 실행 id 라 그 항목을 고르지 않습니다(재전달 효과의 커스텀
    #        한정은 새 실행 id 로 저절로 성립 - 설계 v10 6.1)
    Initialize-HandoffRow -Entries @(New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A) -Applied @($NONCE_A) -LaunchKind 'next' -LaunchNonce $NONCE_A
    $row = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (locked)')
    $newRun = Invoke-RealResolveHandoffEnv -Context @{ runId = 'run-new' }
    Assert-Case "C4-11′ 비커스텀 next + ' (locked)' → NA launched 그대로 · 계상 0 || 새 실행 id 의 다음 기동 → 후보 없음" `
        ('{0} · {1} || {2}/{3}' -f (Get-EntryText $row.Journal $NONCE_A), $row.Completed, $newRun.Status, $newRun.Kind) 'reentered/launched/1 · 0 || none/none'
    # C4-12 선택 화면·ESC 메뉴 보류 표지(next·own - 안·밖을 몰라 조작 없이 멈춤) → launched 그대로 · 마커 정리 0 · 계상 0 → 다음 기동 후보가 같은 항목
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($nextEntry) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowNext = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (selection-overlay)')
    $againNext = Invoke-RealResolveHandoffEnv -Context $fixture.OwnerNow
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($ownEntry) -LaunchKind 'own' -LaunchNonce $NONCE_A
    $rowOwn = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (menu-overlay)')
    $againOwn = Invoke-RealResolveHandoffEnv -Context $fixture.OwnerNow
    Assert-Case "C4-12 next + ' (selection-overlay)' → NB launched · 마커 정리 0 · 계상 0 · 다음 후보 next/NB || own + ' (menu-overlay)' → NA launched · 다음 후보 own/NA" `
        ('{0} · {1}/{2} · {3}/{4} || {5} · {6}/{7} · {8}/{9}' -f (Get-EntryText $rowNext.Journal $NONCE_B), $rowNext.MarkerClears, $rowNext.Completed, $againNext.Kind, (Get-NonceLabel ([string]$againNext.Nonce)),
            (Get-EntryText $rowOwn.Journal $NONCE_A), $rowOwn.MarkerClears, $rowOwn.Completed, $againOwn.Kind, (Get-NonceLabel ([string]$againOwn.Nonce))) `
        'reentered/launched/1 · 0/0 · next/NB || entered/launched/0 · 0/0 · own/NA'

    # C4-13 커스텀 재개(resume) 기동 + 재전달 표지(선택 화면·ESC 메뉴·사용 중 - 명세 5절 B1) → 보류: 계상·전진·마커 정리 0 · 완료 기록 접근 0 · 진행 위치 읽기 0 ·
    #       재입장 요청 기록 그대로(미적용·launched) · 파일 그대로(마커 포함) - 다음 수동 시작의 재개가 그 판을 확정
    $retryEntry = New-FixtureEntry -Stage 'retry-clicked' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_D
    $relayTails = @(' (selection-overlay)', ' (menu-overlay)', ' (locked)')
    $holdTexts = foreach ($relayTail in $relayTails) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($retryEntry) -LaunchKind 'resume' -LaunchNonce $NONCE_D
        Write-ContextMarker -Context $fixture.Now
        $holdRow = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + $relayTail)
        '{0}: {1} · {2}/{3}/{4} · {5}/{6}/{7} · {8} · {9}' -f $relayTail.Trim(), $holdRow.Flow, $holdRow.Completed, $holdRow.Steps, $holdRow.MarkerClears, $holdRow.Reads, $holdRow.Updates,
            $holdRow.ContextReads, (Get-EntryText $holdRow.Journal $NONCE_D), $holdRow.StateUnchanged
    }
    $holdWant = foreach ($relayTail in $relayTails) {
        '{0}: stop|조건 정지: {1}{2}|False · 0/0/0 · 0/0/0 · retry-clicked/launched/0 · 1' -f $relayTail.Trim(), $CODE4_REASON, $relayTail
    }
    Assert-Case 'C4-13 커스텀 재개 + 재전달 표지 3종 → 정지만 · 계상/전진/마커 정리 0 · 읽기/저장/위치 읽기 0 · 요청 기록 그대로 · 파일 그대로' ($holdTexts -join ' || ') ($holdWant -join ' || ')
    # C4-13′ 표지 없는 재개 기동의 코드 4 → 보류 아님: 마커 경로 1 · 재입장 요청 기록(클리어 이상) 소비 · 넘긴 nonce done
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($retryEntry) -LaunchKind 'resume' -LaunchNonce $NONCE_D
    Write-ContextMarker -Context $fixture.Now
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-13′ 표지 없는 재개 기동 → 마커 경로 1 · 요청 기록 소비 · done' ('{0} · {1}/{2}/{3} · {4}' -f $row.Flow, $row.Completed, $row.Steps, $row.MarkerClears, (Get-EntryText $row.Journal $NONCE_D)) `
        ('{0} / step / {1} · 1/1/1 · retry-clicked/done/1' -f $doneNow, $C4_STOP)
    # C4-13″ 보류는 커스텀 재개 기동뿐(설계 v10 6.1 · 명세 5절 B1) - 재개가 아닌 커스텀 기동(own - 넘긴 NA)이 사용 중 표지로 끝나고 그 판의 유효 마커·클리어 기록이
    #        있으면 계상은 사실대로: 마커 경로 1(완료 줄 · 전진 · 마커 정리) · 클리어 기록 소비 · NA 는 재전달이라 launched 그대로 (단계 2.7~2.9 구현 검증 - 생존 변이 '보류를
    #        커스텀 기동 전부로' 를 가름: C4-11·C4-12 는 유효 마커·클리어 기록이 없어 결과가 같았음)
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($ownEntry, $clearedNow) -LaunchKind 'own' -LaunchNonce $NONCE_A
    Write-ContextMarker -Context $fixture.Now
    $row = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (locked)')
    Assert-Case "C4-13″ 커스텀 own + ' (locked)' + 유효 마커·클리어 기록 → 보류 아님: 완료 줄 → 전진 → 정지 · 계상/전진/마커 정리 1 · NA launched · 클리어 기록 소비" `
        ('{0} · {1}/{2}/{3} · {4} · {5}' -f $row.Flow, $row.Completed, $row.Steps, $row.MarkerClears, (Get-EntryText $row.Journal $NONCE_A), (Get-EntryText $row.Journal $NONCE_C)) `
        ('{0} / step / stop|조건 정지: {1} (locked)|False · 1/1/1 · entered/launched/0 · cleared/pending/1' -f $doneNow, $CODE4_REASON)
    # C4-14 비커스텀 재개 기동 + 선택 화면 표지 → 기록 규칙 ③ 1회(재전달 대상이 없음 - 다음 시작은 새 실행 id) · 그 기록 소비 · nonce launched 유지(표지)
    Initialize-HandoffRow -Entries @(New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -LaunchState 'launched' -Nonce $NONCE_D) -LaunchKind 'resume' -LaunchNonce $NONCE_D
    $row = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (selection-overlay)')
    Assert-Case "C4-14 비커스텀 재개 + ' (selection-overlay)' → 완료 줄 · 계상 1 · 소비 · launched 유지" ('{0} · {1} · {2}' -f $row.Flow, $row.Completed, (Get-EntryText $row.Journal $NONCE_D)) `
        ('gui|=== 1회차 완료 === / stop|조건 정지: {0} (selection-overlay)|False · 1 · retry-clicked/launched/1' -f $CODE4_REASON)
    # C4-14′ 클리어 뒤 표지(' (post-clear)')는 재전달 표지가 아닙니다(재전달은 사용 중·선택 화면·ESC 메뉴 셋 - 설계 v10 6.1): 비커스텀 next(넘긴 NA - 적용됨) → 표지로
    #        계상 1 · NA done || 커스텀 재개 + 유효 마커 → 보류 아님: 마커 경로 1 · 재입장 요청 기록 소비 · ND done (단계 2.7~2.9 구현 검증 - 생존 변이 '재전달 표지에
    #        클리어 뒤 표지도' 를 가름: 클리어 뒤 표지 행에 넘긴 nonce·재개 기동이 없었음)
    $postReason = $CODE4_REASON + ' (post-clear)'
    Initialize-HandoffRow -Entries @(New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A) -Applied @($NONCE_A) -LaunchKind 'next' -LaunchNonce $NONCE_A
    $rowPlain = Invoke-HandoffTick -ExitCode 4 -Reason $postReason
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($retryEntry) -LaunchKind 'resume' -LaunchNonce $NONCE_D
    Write-ContextMarker -Context $fixture.Now
    $rowResume = Invoke-HandoffTick -ExitCode 4 -Reason $postReason
    Assert-Case "C4-14′ ' (post-clear)' 는 재전달 아님: 비커스텀 next → [경고] 표지 계상 1 · NA done || 커스텀 재개 + 유효 마커 → 마커 경로 1 · 요청 기록 소비 · ND done" `
        ('{0} · {1} · {2} || {3}/{4}/{5} · {6}' -f $rowPlain.Flow, $rowPlain.Completed, (Get-EntryText $rowPlain.Journal $NONCE_A), $rowResume.Completed, $rowResume.Steps, $rowResume.MarkerClears,
            (Get-EntryText $rowResume.Journal $NONCE_D)) `
        ('gui|{0} / stop|조건 정지: {1}|False · 1 · reentered/done/1 || 1/1/1 · retry-clicked/done/1' -f $C4_POST_CLEAR_WARNING, $postReason)

    # C4-15 순서 주입(dev:989 '통상 tail 뒤·HasExited 전 [완료] … (selection-overlay) 추가'): 커스텀 재개 + 유효 마커인데 표지 줄이 종료 직전에만 쓰임 →
    #       갈래 앞 공통 최종 수집이 계상보다 먼저 잡아 보류가 성립(마커 경로 0) || 같은 줄이 복구 로그에만 쓰인 변형
    $overlayLine = '12:00:09 [완료] {0} (selection-overlay)' -f $CODE4_REASON
    $orderTexts = foreach ($orderPlan in @(@{ WorkerLines = @($overlayLine) }, @{ RecoveryLines = ($RECOVERY_HEAD + @($overlayLine)) })) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($retryEntry) -LaunchKind 'resume' -LaunchNonce $NONCE_D
        Write-ContextMarker -Context $fixture.Now
        $orderRow = Invoke-HandoffTick -ExitCode 4 -Plan $orderPlan
        '{0} · {1}/{2}/{3} · {4}' -f $orderRow.Flow, $orderRow.Completed, $orderRow.Steps, $orderRow.MarkerClears, (Get-EntryText $orderRow.Journal $NONCE_D)
    }
    Assert-Case 'C4-15 종료 직전 표지 줄(기본 로그 || 복구 로그) → 커스텀 재개 보류 · 계상/전진/마커 정리 0 · 요청 기록 그대로' ($orderTexts -join ' || ') `
        ((@(1, 2) | ForEach-Object { 'stop|조건 정지: {0} (selection-overlay)|False · 0/0/0 · retry-clicked/launched/0' -f $CODE4_REASON }) -join ' || ')

    # H32d 마무리 실행 기동(오류 보류 - 진행 저장 실패)의 코드 4 → '<코드 4 사유> (마무리 실행 전 오류: 커스텀 진행 기록 저장 실패)' 오류 정지 · 빨강 · 넘긴 nonce
    #      done · 마무리 실행 워커의 클리어 기록(i+1)은 디스크 i 와 owner 가 달라 계상 0(명세 5절 B7·C17 - R6 안건으로 넘긴 알려진 손실)
    $handoff = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $finishCleared = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_B
    $errorHold = @{ Kind = 'step-failed'; Reason = '커스텀 진행 기록 저장 실패'; IsError = $true; Owner = $fixture.OwnerNext; Position = $fixture.Next.Position; Snapshot = $fixture.Now }
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff, $finishCleared) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $errorHold
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'H32d 마무리 실행(오류 보류)의 코드 4 → 사유 + 마무리 실행 전 오류 · 오류 정지 · 빨강 · 계상 0 · NA done · 마무리 실행 판의 기록 그대로' `
        ('{0} · {1} · {2} · {3} · {4}' -f $row.Flow, $row.Color, $row.Completed, (Get-EntryText $row.Journal $NONCE_A), (Get-EntryText $row.Journal $NONCE_B)) `
        ('stop|{0}|True · Firebrick · 0 · reentered/done/1 · cleared/pending/0' -f ($C4_PRIOR_ERROR_FORMAT -f ('조건 정지: ' + $CODE4_REASON), '커스텀 진행 기록 저장 실패'))
    # H32e 마무리 실행 비오류 보류(비커스텀 안전 중지 / 커스텀 바퀴 완주) → 코드 4 사유 그대로 정상 정지 · SteelBlue · 넘긴 nonce done
    $safeHold = @{ Kind = 'safe-stop'; Reason = '안전 중지'; IsError = $false; Owner = @{ runId = 'run-H' }; Position = ''; Snapshot = $null }
    Initialize-HandoffRow -Entries @(New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A) -Applied @($NONCE_A) `
        -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $safeHold
    $rowPlain = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    $lapHold = @{ Kind = 'lap-complete'; Reason = '지정 바퀴 완료'; IsError = $false; Owner = $fixture.OwnerNext; Position = $fixture.Next.Position; Snapshot = $fixture.Now }
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $lapHold
    $rowCustom = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'H32e 마무리 실행 비오류 보류(비커스텀 안전 중지 || 커스텀 바퀴 완주) → 코드 4 사유 그대로 정상 정지 · SteelBlue · NA done' `
        ('{0} · {1} · {2} || {3} · {4} · {5}' -f $rowPlain.Flow, $rowPlain.Color, (Get-EntryText $rowPlain.Journal $NONCE_A), $rowCustom.Flow, $rowCustom.Color, (Get-EntryText $rowCustom.Journal $NONCE_A)) `
        ('{0} · SteelBlue · reentered/done/1 || {0} · SteelBlue · reentered/done/1' -f $C4_STOP)
}

# ===== C4 행동 - 완료 기록 읽기 실패 · 끝 처리 실패 · 진입 컨텍스트 $null · 처리 중 예외 (명세 2.7 ⑤ · 5절 B3·B13·A4) =====
function Test-CaseCode4Failure {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $doneNow = 'gui|[커스텀] {0} 항목 완료' -f $fixture.Now.Position
    $cleared = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_A
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C

    # C4-16 완료 기록 읽기 실패(비커스텀 + 이번 실행의 클리어 기록) → 기록 규칙 보류(계상 0) · 오류 정지(사용 중 + 안내 / 손상 + 위치 안내 / 읽기 실패 / 예외) ·
    #       코드 4 정상 정지 없음 · 파일 그대로 · 빨강 (명세 2.7 ⑤ · 5절 B3 - 코드 4 사유는 워커 [완료] 줄로 창에 이미 있음). 손상도 사용 중처럼 실제 상태(계상 보류 ·
    #       기록 보존) 뒤에 위치 안내(단계 2.7·2.8 구현 리뷰 P3 - 예전 글자 '파일을 보존하고 정지' 는 계상을 보류했는지 알 수 없었음)
    Initialize-HandoffRow -Entries @($cleared)
    $rowLocked = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -HoldLock
    Initialize-HandoffRow -CorruptText 'not json'
    $rowCorrupt = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow -Entries @($cleared)
    $rowIo = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -HoldMainNone
    Initialize-HandoffRow -Entries @($cleared)
    $script:readThrows = $true
    try { $rowThrow = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON } finally { $script:readThrows = $false }
    Assert-Case 'C4-16 읽기 사용 중 || 손상 || 읽기 실패 || 읽기 예외 → 정지 그 문구(계상 보류 · 기록 보존) · 계상 0 · 파일 그대로 · 빨강' `
        ((@($rowLocked, $rowCorrupt, $rowIo, $rowThrow) | ForEach-Object { '{0} · {1} · {2} · {3}' -f $_.Flow, $_.Completed, $_.StateUnchanged, $_.Color }) -join ' || ') `
        ((@(('stop|완료 기록 파일이 사용 중 - {0} {1}|True' -f $C4_HELD_PLAIN, $LOCKED_GUIDE), ('stop|완료 기록 파일 손상 - {0} {1}|True' -f $C4_HELD_PLAIN, $CORRUPT_GUIDE),
                ('stop|완료 기록 파일을 읽지 못해 {0}|True' -f $C4_HELD_PLAIN),
                ('stop|완료 기록 파일을 읽지 못해 {0} (예외: {1})|True' -f $C4_HELD_PLAIN, $INJECTED_READ_EXCEPTION)) | ForEach-Object { '{0} · 0 · 1 · Firebrick' -f $_ }) -join ' || ')
    # C4-16′ 커스텀 유효 마커 + 같은 판 기록 + 사용 중 → 마커 경로는 마커로 셈(완료 줄 · 전진 · 마커 정리) → 정지(완료 표시를 남기지 못함 · 진행은 반영됨 + 안내) ·
    #        기록 그대로(전진 뒤라 owner 가 달라 다음 시작에서 stale - 이중 계상 없음, 설계 v10 6.1) || 마커 없음 + 같은 판 기록 + 사용 중 → 계상 0 · 전진 0 ·
    #        정지(계상 보류 · 기록·마커 보존 + 안내) || 사용 중 + 클리어 뒤 표지(비커스텀·기록 없음) → 표지 폴백도 보류 · 계상 0
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    Write-ContextMarker -Context $fixture.Now
    $rowMarker = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -HoldLock
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    $rowNoMarker = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -HoldLock
    Initialize-HandoffRow
    $rowPost = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (post-clear)') -HoldLock
    Assert-Case 'C4-16′ 사용 중 + 커스텀 마커 경로 → 셈 뒤 정지(진행은 반영됨) || 마커 없음 → 계상 보류(기록·마커 보존) || 클리어 뒤 표지 → 보류' `
        ('{0} · {1}/{2}/{3} · {4} || {5} · {6}/{7} · {8} || {9} · {10}' -f $rowMarker.Flow, $rowMarker.Completed, $rowMarker.Steps, $rowMarker.MarkerClears, (Get-EntryText $rowMarker.Journal $NONCE_C),
            $rowNoMarker.Flow, $rowNoMarker.Completed, $rowNoMarker.Steps, (Get-EntryText $rowNoMarker.Journal $NONCE_C), $rowPost.Flow, $rowPost.Completed) `
        (('{0} / step / stop|완료 기록 파일이 사용 중 - {1} {2}|True · 1/1/1 · cleared/pending/0 || stop|완료 기록 파일이 사용 중 - {3} {2}|True · 0/0 · cleared/pending/0 || ' +
            'stop|완료 기록 파일이 사용 중 - {4} {2}|True · 0') -f $doneNow, $C4_HELD_APPLIED, $LOCKED_GUIDE, $C4_HELD_CUSTOM, $C4_HELD_PLAIN)
    # C4-16″ 손상(본 파일·직전본) + 커스텀 → 문구는 사용 중과 같은 실제 상태 + 파일 위치 안내(단계 2.7·2.8 구현 리뷰 P3): 유효 마커 → 마커 경로가 셈(완료 줄 · 전진 ·
    #        마커 정리) 뒤 '완료 표시를 남기지 못하고 정지 (진행은 반영됨)' || 마커 없음 → 계상 0 · 전진 0 · '계상을 보류하고 정지 (기록·마커 보존)' · 파일 그대로(손상 파일 보존)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -CorruptText 'not json'
    Write-ContextMarker -Context $fixture.Now
    $rowMarker = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -CorruptText 'not json'
    $rowNoMarker = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-16″ 손상 + 커스텀 마커 경로 → 셈 뒤 정지(진행은 반영됨 + 위치 안내) · 계상/전진/마커 정리 1 || 마커 없음 → 정지(계상 보류 · 기록·마커 보존 + 위치 안내) · 계상/전진 0 · 파일 그대로' `
        ('{0} · {1}/{2}/{3} || {4} · {5}/{6} · {7}' -f $rowMarker.Flow, $rowMarker.Completed, $rowMarker.Steps, $rowMarker.MarkerClears, $rowNoMarker.Flow, $rowNoMarker.Completed, $rowNoMarker.Steps,
            $rowNoMarker.StateUnchanged) `
        ('{0} / step / stop|완료 기록 파일 손상 - {1} {2}|True · 1/1/1 || stop|완료 기록 파일 손상 - {3} {2}|True · 0/0 · 1' -f $doneNow, $C4_HELD_APPLIED, $CORRUPT_GUIDE, $C4_HELD_CUSTOM)
    # C4-17 끝 처리(소비·done) 실패 → 그 함수의 오류 정지 하나 · 코드 4 정상 정지 없음(정지 두 번 금지 - 타이머 return) · 계상은 이미 1 · 기록 그대로
    #       (판별 읽기 뒤·끝 처리 저장 앞에 다른 기록 주체가 잠금 - 저장 전 갈고리)
    Initialize-HandoffRow -Entries @($cleared)
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -PreUpdateAt 1 -PreUpdateHook { Lock-JournalLock }
    Assert-Case 'C4-17 끝 처리 사용 중 → 완료 줄 → 정지 1번(완료 표시를 남기지 못함 · 기록 보존 + 안내) · 계상 1 · 기록 그대로 · 빨강' `
        ('{0} · {1} · {2} · {3}' -f $row.Flow, $row.Completed, (Get-EntryText $row.Journal $NONCE_A), $row.Color) ('gui|=== 1회차 완료 === / stop|{0}|True · 1 · cleared/pending/0 · Firebrick' -f $C4_END_LOCKED)
    # C4-18 진입 컨텍스트 $null(명세 5절 B13 - 설정 파일 일시 읽기 실패: 첫 읽기만 $null) → 기록 대조 건너뜀(계상 0 · 전진 0 · 소비 0 - 기록을 남겨 다음 시작이
    #       이어받음) + [경고] 1줄 · 이 처리 안에서 다시 읽지 않음(위치 읽기 1) · 넘긴 nonce 는 done || 클리어 뒤 표지면 표지로 1회(경고 둘 · 전진 0)
    $ownLaunched = New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow, $ownLaunched) -LaunchKind 'own' -LaunchNonce $NONCE_A
    $script:contextNullReads = 1
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    $script:contextNullReads = 1
    $rowPost = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (post-clear)')
    Assert-Case 'C4-18 진입 컨텍스트 $null → [경고] → 정지 · 계상/전진 0 · 위치 읽기 1 · 기록 미소비 · NA done · 읽기 1·저장 1 || 클리어 뒤 표지 → 표지 [경고] → 대조 [경고] → 정지 · 계상 1 · 전진 0' `
        ('{0} · {1}/{2} · {3} · {4} · {5} · {6}/{7} || {8} · {9}/{10}' -f $row.Flow, $row.Completed, $row.Steps, $row.ContextReads, (Get-EntryText $row.Journal $NONCE_C), (Get-EntryText $row.Journal $NONCE_A),
            $row.Reads, $row.Updates, $rowPost.Flow, $rowPost.Completed, $rowPost.Steps) `
        ('gui|{0} / {1} · 0/0 · 1 · cleared/pending/0 · entered/done/0 · 1/1 || gui|{2} / gui|{0} / stop|조건 정지: {3} (post-clear)|False · 1/0' -f $C4_NO_CONTEXT_WARNING, $C4_STOP, $C4_POST_CLEAR_WARNING, $CODE4_REASON)
    # C4-18′ 진입 컨텍스트 $null(첫 읽기만) + 유효 완료 마커 → 마커 경로는 예전 그대로(명세 5절 B13 - 마커 유효 판정은 자기 읽기로 소유자를 대조): 회차 완료 줄(진입
    #        위치를 몰라 회차 모양) → 전진 → 정지 · 계상/전진/마커 정리 1 · 대조 건너뜀 [경고] 0(마커 경로가 셈 - '다음 시작에서 이어받음' 은 틀린 안내) · 클리어 기록 미소비
    #        (-Context $null) || C4-18″ 범위 밖(던전 커스텀) + 진입 컨텍스트 $null → 정지만 · [경고] 0 · 완료 기록 읽기 0 (단계 2.7~2.9 구현 검증 - 생존 변이 '$null 이면 마커
    #        경로도 막음' · '마커 경로 뒤에도 경고' · '범위 밖에서도 경고' 를 가름)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    Write-ContextMarker -Context $fixture.Now
    $script:contextNullReads = 1
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow -Custom $true -Content 'dungeon' -DiskContext $fixture.Now
    $script:customConfigSection = 'customRepeat'
    $script:contextNullReads = 1
    $rowDungeon = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Assert-Case 'C4-18′ 진입 컨텍스트 $null + 유효 마커 → 회차 완료 줄 → 전진 → 정지(경고 0) · 계상/전진/마커 정리 1 · 클리어 기록 미소비 || C4-18″ 던전 커스텀 + $null → 정지만 · 읽기 0' `
        ('{0} · {1}/{2}/{3} · {4} || {5} · 읽기 {6}' -f $row.Flow, $row.Completed, $row.Steps, $row.MarkerClears, (Get-EntryText $row.Journal $NONCE_C), $rowDungeon.Flow, $rowDungeon.Reads) `
        ('gui|=== 1회차 완료 === / step / {0} · 1/1/1 · cleared/pending/0 || {0} · 읽기 0' -f $C4_STOP)
    # C4-18‴ 진입 컨텍스트 $null(첫 읽기만) + 완료 기록 읽기 실패 → 대조 건너뜀 [경고]가 읽기 실패 정지 앞에 1줄(단계 2.7·2.8 구현 리뷰 P3 - 예전에는 읽기 실패로 먼저
    #        멈춰 경고가 없었음): 사용 중 → [경고] → 정지(계상 보류 · 기록·마커 보존 + 안내) || 손상 → [경고] → 정지(같은 상태 + 위치 안내) || 유효 마커 + 사용 중 → 마커
    #        경로가 셈(회차 완료 줄 · 전진) → 경고 0 → 정지(진행은 반영됨) · 셋 다 위치 읽기 1(다시 읽지 않음)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    $script:contextNullReads = 1
    $rowLocked = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -HoldLock
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -CorruptText 'not json'
    $script:contextNullReads = 1
    $rowCorrupt = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    Write-ContextMarker -Context $fixture.Now
    $script:contextNullReads = 1
    $rowMarker = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -HoldLock
    Assert-Case 'C4-18‴ 진입 컨텍스트 $null + 사용 중 → [경고] → 정지 || + 손상 → [경고] → 정지 || + 유효 마커 + 사용 중 → 셈 → 경고 0 → 정지(진행은 반영됨) · 계상/전진 · 위치 읽기 1(첫 둘)' `
        ('{0} · {1}/{2} · {3} || {4} · {5}/{6} · {7} || {8} · {9}/{10}' -f $rowLocked.Flow, $rowLocked.Completed, $rowLocked.Steps, $rowLocked.ContextReads,
            $rowCorrupt.Flow, $rowCorrupt.Completed, $rowCorrupt.Steps, $rowCorrupt.ContextReads, $rowMarker.Flow, $rowMarker.Completed, $rowMarker.Steps) `
        (('gui|{0} / stop|완료 기록 파일이 사용 중 - {1} {2}|True · 0/0 · 1 || gui|{0} / stop|완료 기록 파일 손상 - {1} {3}|True · 0/0 · 1 || ' +
            'gui|=== 1회차 완료 === / step / stop|완료 기록 파일이 사용 중 - {4} {2}|True · 1/1') -f $C4_NO_CONTEXT_WARNING, $C4_HELD_CUSTOM, $LOCKED_GUIDE, $CORRUPT_GUIDE, $C4_HELD_APPLIED)
    # C4-19 처리 중 예외(사유 표지 계상 뒤 [경고] 줄에서 주입) → 계상 함수의 catch 가 오류 정지 하나 · 타이머 오류 줄 0 · 코드 4 정상 정지 없음 · 예외 0 (명세 5절 A4)
    Initialize-HandoffRow
    $row = Invoke-HandoffTick -ExitCode 4 -Reason ($CODE4_REASON + ' (post-clear)') -GuiLogThrowMatch '완료 기록 없이 계상'
    Assert-Case 'C4-19 계상 처리 중 예외 → 정지 1번(처리 중 예외 + 메시지) · 빨강 · 타이머 오류 줄 0 · 예외 0' `
        ('{0} · {1} · {2} · [{3}]' -f $row.Flow, $row.Color, @($row.Events | Where-Object { $_.StartsWith('gui|[오류] 내부 타이머') }).Count, $row.Thrown) `
        ('gui|{0} / stop|{1}|True · Firebrick · 0 · []' -f $C4_POST_CLEAR_WARNING, ($C4_EXCEPTION_FORMAT -f $INJECTED_GUILOG_EXCEPTION))
}

# ===== C4 결합 행 - 실제 기동의 env → 워커의 실제 클리어 기록 → GUI 코드 0·4 (명세 3.3 '① 실동작 결합 행' · 2.10 끝 회귀) =====
# 단계 2.10 부터 워커 쪽도 실제 소스입니다(2.7 에서는 기록 모양을 이 테스트가 흉내 냈음): 실제 Start-NextCycle 이 이 프로세스 env 에 넘긴 값을 워커의
# 실제 읽기 문장(완료 마커 경로 · 소유자 JSON · 실행 id W2)으로 받고, 본류 끝의 [완료 기록 if(W3) → 나가기 헬퍼] 두 문장을 그대로 점소싱해 실제
# Add-AbyssJournalClearedEntry·ConvertTo-AbyssJournalOwner 가 같은 저장소로 기록합니다. 그다음 그 판의 종료 코드로 GUI 타이머 틱 1번 - 워커가 남긴 줄은
# 종료 직전 줄로 덧붙여 GUI 창 표시(성공 줄 숨김 W7 · 실패 [경고] 보임)까지 봅니다. 커스텀 여부·정리 전용 표지는 워커의 시작 판정 대신 행이 정합니다(그
# 판정 Test-CustomCleanupOnly 는 test_abyss_custom_worker). 지키는 것: GUI 가 기동 env 로 넘긴 열쇠(RUN_ID·OWNER·GENERATION)로 워커가 남긴 기록을 GUI 코드 4
# 대조가 같은 판으로 셈 · 코드 0 은 종료 코드로 세고 그 기록은 소비만 · 정리 전용 판은 기록 0 → 계상 0 · 기록 저장 실패는 [경고] 뒤 진행(종료 코드 그대로)
function Invoke-WorkerClearedRecord {
    # 워커 쪽 한 판 → @{ Logs; TimedLines(시각을 붙인 워커 줄 - 틱의 종료 직전 줄로); ExitClicks; Error; Journal(기록 직후 본 파일); NewCount; Entry(새 항목);
    # ReturnCodes(복귀 루프에 넘긴 안전 중지 코드); TailExit(꼬리 사본이 만난 exit 의 코드 - 없으면 빈 값) }.
    # 기동 env 는 워커 원문 순서대로 받습니다 - 커스텀 판정 → (커스텀이면) 완료 마커 경로·소유자 JSON → 실행 id(W2 는 그 뒤. 단계 2.10 구현 검증 -
    # 순서가 다르면 커스텀 판정을 읽는 실행 id 변이를 커스텀 행이 못 봄). 저장소 작성자 표지는 워커 원문 값으로 잠시 바꿔 씁니다(저장 감시가 GUI 사본으로
    # 넘김 - 두 사본 같은 토큰, 회귀 ㉑ J14).
    # -Run: 'record' = [완료 기록 if → 나가기 헬퍼] / 'marker' = [완료 마커 if → 완료 기록 if → 나가기 헬퍼](마커 쓰기를 실제로 - 경로는 기동 env) /
    #       'tail' = 꼬리 전체 [완료 기록 if → … → 본류 try 끝](exit 는 가로챔)
    # -HoldLock = 기록하는 동안 다른 기록 주체가 잠금을 쥠(저장 실패 주입 - 기록이 끝나면 놓음) · -UpdateThrows = 저장 함수가 던짐(저장소 밖 예외 = 구현 결함
    # 주입 - 저장 감시의 첫 저장 예외). 지역 변수 이름은 워커 문장이 읽는 이름($clearOutcome·$game·$timeout*)만 쓰고 $abyssJournalPath 는 두지 않습니다(기록
    # 함수가 스크립트 수준 값을 이름 그대로 읽음 - 동적 스코프로 가려짐)
    param([bool]$Custom, [bool]$CleanupOnly = $false, [string]$ClearOutcome = 'clear', [switch]$HoldLock, [string]$Run = 'record', [switch]$UpdateThrows)
    $script:customMode = $Custom
    $script:customOwnerJson = ''
    $script:customMarkerPath = ''
    if ($Custom) {
        . $workerMarkerPathBlock
        . $workerOwnerBlock
    }
    . $workerRunIdBlock
    $script:customCleanupOnly = $CleanupOnly
    $script:workerRunLogLines.Clear()
    $script:exitClickCalls = 0
    $script:returnSelectionCodes.Clear()
    $clearOutcome = $ClearOutcome
    $game = $null
    $timeoutHud = 30
    $timeoutAbyssMenu = 30
    $timeoutAbyssSelect = 30
    $noncesBefore = @()
    $journalBefore = Read-FixtureJournal -Path $script:abyssJournalPath
    if ($null -ne $journalBefore) { $noncesBefore = @(@($journalBefore.entries) | ForEach-Object { [string]$_.nonce }) }
    $guiSavedBy = $script:abyssJournalSavedBy
    $script:abyssJournalSavedBy = $WORKER_SAVED_BY
    $script:journalUpdates = 0
    $script:updateThrowAt = $(if ($UpdateThrows) { 1 } else { 0 })
    if ($HoldLock) { Lock-JournalLock }
    $workerBlock = $workerTailBlock
    if ($Run -eq 'marker') { $workerBlock = $workerMarkerTailBlock }
    elseif ($Run -eq 'tail') { $workerBlock = $workerFullTailBlock }
    $recordError = ''
    $tailExit = ''
    try {
        . $workerBlock
    } catch {
        if ($_.Exception.Message.StartsWith($WORKER_EXIT_PREFIX)) { $tailExit = $_.Exception.Message.Substring($WORKER_EXIT_PREFIX.Length) }
        else { $recordError = $_.Exception.Message }
    } finally {
        $script:abyssJournalSavedBy = $guiSavedBy
        $script:updateThrowAt = 0
        if ($HoldLock) { Unlock-LogFiles }
    }
    $journalAfter = Read-FixtureJournal -Path $script:abyssJournalPath
    $newEntries = @()
    if ($null -ne $journalAfter) { $newEntries = @(@($journalAfter.entries) | Where-Object { $noncesBefore -notcontains [string]$_.nonce }) }
    return @{
        Logs        = @($script:workerRunLogLines)
        TimedLines  = @($script:workerRunLogLines | ForEach-Object { '12:00:03 ' + $_ })
        ExitClicks  = $script:exitClickCalls
        Error       = $recordError
        Journal     = $journalAfter
        NewCount    = $newEntries.Count
        Entry       = $(if ($newEntries.Count -gt 0) { $newEntries[0] } else { $null })
        ReturnCodes = @($script:returnSelectionCodes)
        TailExit    = $tailExit
    }
}

function Get-WindowLineCount {
    # 틱 사건 중 GUI 창 줄(line|)에 그 글자가 든 줄 수
    param($Row, [string]$Text)
    return @($Row.Events | Where-Object { $_.StartsWith('line|') -and $_.Contains($Text) }).Count
}

function Test-CaseCode4Coupling {
    # 결합 0 하니스: 워커 쪽 모의 서명 = 워커 실제 서명 (복귀 루프 모의는 결합 7 의 꼬리 사본이 부름)
    $selfAst = [System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$null, [ref]$null)
    Assert-Case '결합 0 워커 모의 Write-RunLog·Invoke-AbyssExitClick·Return-ToAbyssSelection 서명 = 워커 실제 서명' `
        ((@('Write-RunLog', 'Invoke-AbyssExitClick', 'Return-ToAbyssSelection') | ForEach-Object { '{0}({1})' -f $_, (Get-ParamSignature $selfAst $_) }) -join ' / ') `
        ((@('Write-RunLog', 'Invoke-AbyssExitClick', 'Return-ToAbyssSelection') | ForEach-Object { '{0}({1})' -f $_, (Get-ParamSignature $workerAst $_) }) -join ' / ')

    # 결합 1 비커스텀: 실행 시작(새 실행 id → HONEYNOGI_RUN_ID - Invoke-StartAutomation 의 두 문장, 원문은 S4 가 고정) → 실제 Start-NextCycle → 워커가 받은
    # 실행 id 로 실제 클리어 기록 → 나가기 위치 미발견 코드 4 → 계상 1 · 소비 / 같은 판이 정상 종료(코드 0) → 종료 코드로 계상 1 · 그 기록은 소비만(두 번 세지 않음)
    $plainRows = foreach ($exitCode in @(4, 0)) {
        Initialize-HandoffRow
        $script:runId = [guid]::NewGuid().ToString('D')
        $env:HONEYNOGI_RUN_ID = $script:runId
        Start-NextCycle
        $launchCount = $script:launches.Count
        $launchKind = [string]$script:lastLaunchKind
        $worker = Invoke-WorkerClearedRecord -Custom $false
        $entry = $worker.Entry
        $nonce = ''
        $ownerText = '(기록 없음)'
        if ($null -ne $entry) {
            $nonce = [string]$entry.nonce
            $ownerText = (@($entry.owner.PSObject.Properties | ForEach-Object { '{0}={1}' -f $_.Name, [int]([string]$_.Value -ceq $script:runId) }) -join ',')
        }
        $reason = $(if ($exitCode -eq 4) { $C4_EXIT_HELPER_REASON } else { $READY_REASON })
        $row = Invoke-HandoffTick -ExitCode $exitCode -Reason $reason -Plan @{ WorkerLines = $worker.TimedLines }
        ('코드 {0}: 기동 {1}/{2} · 워커 [{3}] · 헬퍼 {4} · 예외 [{5}] · 기록 {6} · runId {7} · owner {8} · section [{9}] · 세대 {10} · 작성자 워커 {11} || ' +
            'GUI 계상 {12} · 기록 {13} · 창 성공 줄 {14}') -f $exitCode, $launchCount, $launchKind, ($worker.Logs -join ' | '), $worker.ExitClicks, $worker.Error, $worker.NewCount,
            [int]([string]$entry.runId -ceq $script:runId), $ownerText, $entry.section, $entry.generation, [int]([string]$worker.Journal.savedBy -ceq $WORKER_SAVED_BY),
            $row.Completed, (Get-EntryText $row.Journal $nonce), (Get-WindowLineCount $row $CLEARED_SUCCESS_TEXT)
    }
    Assert-Case '결합 1 비커스텀: 실제 기동(실행 id) → 워커 실제 기록(성공 줄 · 헬퍼 진행 · owner { runId } · section '''' · 세대 0 · 작성자 워커) → 코드 4 계상 1·소비 / 코드 0 계상 1·소비 · 창 성공 줄 0' `
        ($plainRows -join ' ## ') `
        ((@(4, 0) | ForEach-Object { '코드 {0}: 기동 1/none · 워커 [{1}] · 헬퍼 1 · 예외 [] · 기록 1 · runId 1 · owner runId=1 · section [] · 세대 0 · 작성자 워커 1 || GUI 계상 1 · 기록 cleared/pending/1 · 창 성공 줄 0' -f $_, $CLEARED_SUCCESS_TEXT }) -join ' ## ')
    # 결합 2 커스텀(완료 마커를 못 쓴 판): 실제 기동의 OWNER(version 3)·GENERATION → 워커 실제 기록(owner 5필드 · 세대 = OWNER 의 세대 - GUI 대조가 지금 판으로
    # 봄) → 코드 4 → 기록 경로 계상 1 · 전진 1 · 마커 정리 0 · 소비 · 진행 1/1 / 코드 0 → 계상 1 · 전진 1 · 그 기록은 전진 뒤 소비(-ConsumeOnly) · 진행 1/1
    $fixture = Get-CustomFixture
    $customRows = foreach ($exitCode in @(4, 0)) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now
        $script:runId = [guid]::NewGuid().ToString('D')
        $env:HONEYNOGI_RUN_ID = $script:runId
        Start-NextCycle
        $launchCount = $script:launches.Count
        $launchEnv = $(if ($script:launches.Count -gt 0) { $script:launches[0] } else { @{} })
        $worker = Invoke-WorkerClearedRecord -Custom $true
        $entry = $worker.Entry
        $nonce = ''
        $ownerMatches = $false
        if ($null -ne $entry) {
            $nonce = [string]$entry.nonce
            $ownerMatches = Test-AbyssJournalOwnerMatch -Entry $entry -Owner $fixture.OwnerNow -Generation $H_GENERATION
        }
        $reason = $(if ($exitCode -eq 4) { $CODE4_REASON } else { $READY_REASON })
        $row = Invoke-HandoffTick -ExitCode $exitCode -Reason $reason -Plan @{ WorkerLines = $worker.TimedLines }
        ('코드 {0}: 기동 {1} · GENERATION env {2} · 워커 [{3}] · 헬퍼 {4} · 기록 {5} · section {6} · 세대 {7} · runId {8} · 지금 판 대조 {9} || ' +
            'GUI 계상 {10} · 전진 {11} · 기록 {12} · 진행 {13} · 창 성공 줄 {14}') -f $exitCode, $launchCount, $launchEnv['HONEYNOGI_CUSTOM_GENERATION'], ($worker.Logs -join ' | '),
            $worker.ExitClicks, $worker.NewCount, $entry.section, $entry.generation, [int]([string]$entry.runId -ceq $script:runId), $ownerMatches,
            $row.Completed, $row.Steps, (Get-EntryText $row.Journal $nonce), $row.Disk, (Get-WindowLineCount $row $CLEARED_SUCCESS_TEXT)
        if ($exitCode -eq 4) { $customCode4MarkerClears = $row.MarkerClears }
    }
    Assert-Case '결합 2 커스텀(마커 없음): 실제 기동 OWNER·GENERATION → 워커 실제 기록(세대 = env 세대 · 지금 판 대조 참) → 코드 4 기록 경로 계상 1·전진 1 / 코드 0 계상 1·전진 1 · 둘 다 소비 · 진행 1/1 · 창 성공 줄 0' `
        ($customRows -join ' ## ') `
        ((@(4, 0) | ForEach-Object { '코드 {0}: 기동 1 · GENERATION env {1} · 워커 [{2}] · 헬퍼 1 · 기록 1 · section {3} · 세대 {1} · runId 1 · 지금 판 대조 True || GUI 계상 1 · 전진 1 · 기록 cleared/pending/1 · 진행 1/1 · 창 성공 줄 0' -f $_, $H_GENERATION, $CLEARED_SUCCESS_TEXT, $ABYSS_SECTION }) -join ' ## ')
    Assert-Case '결합 2 코드 4 기록 경로 - 마커 정리 0(마커가 없던 판)' $customCode4MarkerClears 0

    # 결합 3 정리 전용(손으로 들어간 판을 같은 항목으로 정리 - 커스텀): 워커가 기록하지 않음(완료 기록 if 의 정리 전용 조건) · 헬퍼는 그대로 → 코드 4 →
    # 계상 0 · 전진 0 · 마커 정리 0 · 기록 파일 없음(정리 전용은 마커도 쓰지 않음)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now
    $script:runId = [guid]::NewGuid().ToString('D')
    $env:HONEYNOGI_RUN_ID = $script:runId
    Start-NextCycle
    $worker = Invoke-WorkerClearedRecord -Custom $true -CleanupOnly $true
    $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -Plan @{ WorkerLines = $worker.TimedLines }
    Assert-Case '결합 3 정리 전용: 워커 기록 0(줄 0) · 헬퍼 진행 1 → 코드 4 → 정지만 · 계상 0 · 전진 0 · 마커 정리 0 · 기록 파일 없음' `
        ('워커 [{0}] · 헬퍼 {1} · 기록 {2} || {3} · 계상 {4} · 전진 {5} · 마커 정리 {6} · {7}' -f ($worker.Logs -join ' | '), $worker.ExitClicks, $worker.NewCount,
            $row.Flow, $row.Completed, $row.Steps, $row.MarkerClears, $(if ($null -eq $row.Journal) { '파일 없음' } else { '파일 있음' })) `
        ('워커 [] · 헬퍼 1 · 기록 0 || {0} · 계상 0 · 전진 0 · 마커 정리 0 · 파일 없음' -f $C4_STOP)

    # 결합 4 기록 저장 실패 주입(다른 기록 주체가 잠금을 쥠 - 비커스텀): 워커 [경고] 1(파일 사용 중) · 헬퍼 진행 1 · 기록 0 · 예외 0 → 코드 0 이면 종료 코드로
    # 계상 1 / 코드 4 면 계상 0(완료 기록이 없는 클리어 뒤 조건 정지 - 명세 0.3 ② '계속 미계상') · 두 경우 모두 창에 그 [경고] 줄 1(W7 은 성공 줄만 숨김)
    $failRows = foreach ($exitCode in @(0, 4)) {
        Initialize-HandoffRow
        $script:runId = [guid]::NewGuid().ToString('D')
        $env:HONEYNOGI_RUN_ID = $script:runId
        Start-NextCycle
        $worker = Invoke-WorkerClearedRecord -Custom $false -HoldLock
        $reason = $(if ($exitCode -eq 4) { $C4_EXIT_HELPER_REASON } else { $READY_REASON })
        $row = Invoke-HandoffTick -ExitCode $exitCode -Reason $reason -Plan @{ WorkerLines = $worker.TimedLines }
        '코드 {0}: 워커 [{1}] · 헬퍼 {2} · 예외 [{3}] · 기록 {4} || GUI 계상 {5} · 창 경고 줄 {6}' -f $exitCode, ($worker.Logs -join ' | '), $worker.ExitClicks, $worker.Error,
            $worker.NewCount, $row.Completed, (Get-WindowLineCount $row $CLEARED_FAIL_LOCKED)
    }
    Assert-Case '결합 4 기록 저장 실패(사용 중): 워커 [경고] 1 · 헬퍼 진행 · 기록 0 → 코드 0 계상 1(종료 코드) / 코드 4 계상 0 · 창에 [경고] 1' ($failRows -join ' ## ') `
        ((@(@(0, 1), @(4, 0)) | ForEach-Object { '코드 {0}: 워커 [{1}] · 헬퍼 1 · 예외 [] · 기록 0 || GUI 계상 {2} · 창 경고 줄 1' -f $_[0], $CLEARED_FAIL_LOCKED, $_[1] }) -join ' ## ')

    # 결합 5 정적(명세 2.10 W6) - 워커 [설정] 스냅샷(파일 로그 전용)이 GUI 가 넘기는 완료 기록 env 를 받은 그대로 적음: 공통 줄 = 실행 id·handoff env 3개,
    # 커스텀 줄 = (이전·다음 항목 뒤에) 소유자 JSON·진행 세대 - 같은 계산의 두 값이 어긋나면 제보 로그로 드러남(설계 v10 1.7). 적는 env 마다 GUI 원문에
    # 그 env 의 대입이 있음(이름이 어긋나 늘 빈 값으로 찍히지 않게). 지정 시각·사이클 추정치 env 를 넣지 않는 것은 test_life_gather · test_abyss_party_member
    $settingsStrings = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -and $node.Value.StartsWith('[설정] ') }, $true))
    $settingsRows = foreach ($settingsHead in @('[설정] 완료 기록 env: ', '[설정] 커스텀 리스트: ')) {
        $settingsNodes = @($settingsStrings | Where-Object { $_.Value.StartsWith($settingsHead) })
        $settingsEnvNames = @($settingsNodes | ForEach-Object { $_.NestedExpressions } |
                Where-Object { ($_ -is [System.Management.Automation.Language.VariableExpressionAst]) -and ($_.VariablePath.DriveName -eq 'env') } |
                ForEach-Object { $_.VariablePath.UserPath.Substring('env:'.Length) })
        $guiAssigned = @($settingsEnvNames | ForEach-Object {
                $envAssignTarget = '$env:' + $_
                [int](@($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq $envAssignTarget) }, $true)).Count -gt 0) })
        '{0}{1}줄 · {2} · GUI 대입 {3}' -f $settingsHead, $settingsNodes.Count, ($settingsEnvNames -join ','), ($guiAssigned -join '')
    }
    Assert-Case '결합 5 정적: 워커 [설정] 완료 기록 env 줄 = 실행 id·handoff env 3개 · 커스텀 줄 끝 = 소유자 JSON·진행 세대 · 전부 GUI 가 대입하는 env' ($settingsRows -join ' || ') `
        ('[설정] 완료 기록 env: 1줄 · HONEYNOGI_RUN_ID,HONEYNOGI_HANDOFF_NONCE,HONEYNOGI_RESUME_REENTRY,HONEYNOGI_FINISH_ONLY · GUI 대입 1111 || ' +
            '[설정] 커스텀 리스트: 1줄 · HONEYNOGI_CUSTOM_PREV,HONEYNOGI_CUSTOM_NEXT,HONEYNOGI_CUSTOM_OWNER,HONEYNOGI_CUSTOM_GENERATION · GUI 대입 1111')
    # 결합 5′ 정적(단계 2.10 구현 검증 - 줄 수·env 이름만 보던 결합 5 로는 자리·중복을 못 가름): ① 새 env 줄은 기존 첫 [설정] 줄('[설정] 꿀비노기 v' - 명세 W6 의
    # run:17285) 바로 다음 문장이고 같은 블록입니다 - 커스텀 if 안으로 들어가면 비커스텀 실행의 제보 로그에 실행 id 가 남지 않습니다 ② 완료 기록 env 6개(실행 id·
    # handoff 3·소유자 JSON·진행 세대)는 [설정] 스냅샷 전체에서 한 번씩만 적히고 기존 첫 줄은 env 를 읽지 않습니다(명세 W6 '17285 원문 불변' - 첫 줄에
    # 덧붙이면 같은 값이 두 번 찍힘)
    $mainSettingsNodes = @($settingsStrings | Where-Object { $_.Value.StartsWith('[설정] 꿀비노기 v') })
    $envSettingsNodes = @($settingsStrings | Where-Object { $_.Value.StartsWith('[설정] 완료 기록 env: ') })
    $settingsAdjacent = '(첫 줄·env 줄이 1개씩이 아님)'
    if (($mainSettingsNodes.Count -eq 1) -and ($envSettingsNodes.Count -eq 1)) {
        $settingsStatements = foreach ($settingsNode in @($mainSettingsNodes[0], $envSettingsNodes[0])) {
            # 문자열을 품은 문장(블록의 직접 자식)까지 올라갑니다
            $statementNode = $settingsNode
            while (($null -ne $statementNode) -and -not (($statementNode.Parent -is [System.Management.Automation.Language.NamedBlockAst]) -or
                    ($statementNode.Parent -is [System.Management.Automation.Language.StatementBlockAst]))) { $statementNode = $statementNode.Parent }
            $statementNode
        }
        $blockStatements = @($settingsStatements[0].Parent.Statements)
        $mainStatementAt = -1
        for ($statementIndex = 0; $statementIndex -lt $blockStatements.Count; $statementIndex++) {
            if ([object]::ReferenceEquals($blockStatements[$statementIndex], $settingsStatements[0])) { $mainStatementAt = $statementIndex }
        }
        $settingsAdjacent = [int](($mainStatementAt -ge 0) -and ($mainStatementAt + 1 -lt $blockStatements.Count) -and
            [object]::ReferenceEquals($blockStatements[$mainStatementAt + 1], $settingsStatements[1]))
    }
    $settingsEnvRefs = @($settingsStrings | ForEach-Object { $_.NestedExpressions } | ForEach-Object {
            $_.FindAll({ param($node) ($node -is [System.Management.Automation.Language.VariableExpressionAst]) -and ($node.VariablePath.DriveName -eq 'env') }, $true) } |
            ForEach-Object { $_.VariablePath.UserPath.Substring('env:'.Length) })
    $completionEnvCounts = @('HONEYNOGI_RUN_ID', 'HONEYNOGI_HANDOFF_NONCE', 'HONEYNOGI_RESUME_REENTRY', 'HONEYNOGI_FINISH_ONLY', 'HONEYNOGI_CUSTOM_OWNER', 'HONEYNOGI_CUSTOM_GENERATION') |
        ForEach-Object { $completionEnvName = $_; '{0} {1}' -f $completionEnvName, @($settingsEnvRefs | Where-Object { $_ -ceq $completionEnvName }).Count }
    $mainEnvRefCount = $(if ($mainSettingsNodes.Count -eq 1) {
            @($mainSettingsNodes[0].NestedExpressions | ForEach-Object {
                    $_.FindAll({ param($node) ($node -is [System.Management.Automation.Language.VariableExpressionAst]) -and ($node.VariablePath.DriveName -eq 'env') }, $true) }).Count
        } else { -1 })
    Assert-Case '결합 5′ 정적: 새 env 줄 = 기존 첫 [설정] 줄 바로 다음 문장(같은 블록) · 완료 기록 env 6개는 [설정] 스냅샷 전체에서 한 번씩 · 기존 첫 줄의 env 0' `
        ('{0} · {1} · 첫 줄 env {2}' -f $settingsAdjacent, ($completionEnvCounts -join ','), $mainEnvRefCount) `
        '1 · HONEYNOGI_RUN_ID 1,HONEYNOGI_HANDOFF_NONCE 1,HONEYNOGI_RESUME_REENTRY 1,HONEYNOGI_FINISH_ONLY 1,HONEYNOGI_CUSTOM_OWNER 1,HONEYNOGI_CUSTOM_GENERATION 1 · 첫 줄 env 0'
}

# ===== C4 결합 행(워커 본류 문장) - 완료 마커 쓰기 · 꼬리 전체 · 클리어 결과 (단계 2.10 구현 검증 - 생존 변이 보강) =====
# 결합 1~5 는 [완료 기록 if → 나가기 헬퍼] 두 문장만 돌려 그 앞(완료 마커)과 뒤(복귀·[완료]·정리 전용 exit)를 보지 못했습니다. 여기서는 ① 완료 마커를 실제로
# 쓰는 판(결합 6 - 마커 성공/실패와 무관하게 기록되는지: 명세 2.10 W3 '마커 성공 여부와 무관하게 기록(점검 P3-8 ①)') ② 꼬리 전체를 exit 만 가로챈 사본으로
# 돌리는 판(결합 7 - 저장 실패·예외가 본류의 복귀 코드·종료를 바꾸지 않음: W3 '그대로 진행' · '감싸지 않음(R2-5)') ③ 클리어 결과별 기록 여부(결합 8 - 조건식의
# 결과 검사를 글자가 아니라 행동으로)를 봅니다
function Test-CaseCode4CouplingWorker {
    $fixture = Get-CustomFixture
    $doneNow = 'gui|[커스텀] {0} 항목 완료' -f $fixture.Now.Position
    $markerFailLine = '[경고] 완료 마커 기록에 실패했습니다 - 정상 종료면 GUI가 종료 코드로 계상하므로 진행을 계속합니다'

    # 결합 6 커스텀 판의 완료 마커를 실제로 씀(경로 = 기동 env) → 같은 판의 클리어 기록 → 그 뒤 조건 정지(코드 4):
    #   (가) 마커 성공 → 마커 경로 계상 1·전진 1·마커 정리 1 · 클리어 기록은 소비만(owner = 전진 전 i)
    #   (나) 마커 쓰기 실패(주입: 마커 경로의 폴더 없음 - 쓰기 20번 실패, 파일이 생기지 않음) → 마커 경고 뒤에도 클리어 기록 1 → 기록 경로 계상 1·전진 1·마커 정리 0
    #   두 판 모두 창에는 성공 줄(W7)·마커 성공 줄(커스텀 숨김)이 없고 마커 실패 [경고] 만 보입니다
    $markerRows = foreach ($markerCase in @('성공', '실패')) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now
        if ($markerCase -eq '실패') {
            $script:customMarkerFile = Join-Path $script:rowFolder 'no-such-folder\abyss_custom_done.marker'
            $script:customAbyssMarkerFile = $script:customMarkerFile
        }
        $script:runId = [guid]::NewGuid().ToString('D')
        $env:HONEYNOGI_RUN_ID = $script:runId
        Start-NextCycle
        $worker = Invoke-WorkerClearedRecord -Custom $true -Run 'marker'
        $nonce = $(if ($null -ne $worker.Entry) { [string]$worker.Entry.nonce } else { '' })
        $row = Invoke-HandoffTick -ExitCode 4 -Reason $CODE4_REASON -Plan @{ WorkerLines = $worker.TimedLines }
        ('마커 {0}: 워커 [{1}] · 헬퍼 {2} · 예외 [{3}] · 마커 파일 {4} · 기록 {5} · section {6} · 세대 {7} || {8} · 계상 {9} · 전진 {10} · 마커 정리 {11} · 기록 {12} · 진행 {13} · ' +
            '창 성공 줄 {14} · 창 마커 실패 줄 {15}') -f $markerCase, ($worker.Logs -join ' | '), $worker.ExitClicks, $worker.Error, [int][IO.File]::Exists($script:customMarkerFile), $worker.NewCount,
            $worker.Entry.section, $worker.Entry.generation, $row.Flow, $row.Completed, $row.Steps, $row.MarkerClears, (Get-EntryText $row.Journal $nonce), $row.Disk,
            (Get-WindowLineCount $row $CLEARED_SUCCESS_TEXT), (Get-WindowLineCount $row $markerFailLine)
    }
    Assert-Case '결합 6 커스텀 판의 완료 마커 실제 쓰기 → 클리어 기록 → 코드 4: 마커 성공 = 마커 경로 계상·전진·정리 / 마커 쓰기 실패 = 경고 뒤에도 기록 1 → 기록 경로 계상·전진 · 둘 다 소비' `
        ($markerRows -join ' ## ') `
        (('마커 성공: 워커 [[커스텀] 완료 마커 기록 (결과 화면 도달) | {0}] · 헬퍼 1 · 예외 [] · 마커 파일 1 · 기록 1 · section {1} · 세대 {2} || {3} / step / {4} · 계상 1 · 전진 1 · ' +
                '마커 정리 1 · 기록 cleared/pending/1 · 진행 1/1 · 창 성공 줄 0 · 창 마커 실패 줄 0 ## ' +
                '마커 실패: 워커 [{5} | {0}] · 헬퍼 1 · 예외 [] · 마커 파일 0 · 기록 1 · section {1} · 세대 {2} || {3} / step / {4} · 계상 1 · 전진 1 · 마커 정리 0 · ' +
                '기록 cleared/pending/1 · 진행 1/1 · 창 성공 줄 0 · 창 마커 실패 줄 1') -f $CLEARED_SUCCESS_TEXT, $ABYSS_SECTION, $H_GENERATION, $doneNow, $C4_STOP, $markerFailLine)

    # 결합 7 꼬리 전체(완료 기록 if → 나가기 헬퍼 → 복귀 루프 → [완료] → 정리 전용 exit 10 - exit 는 가로챈 사본): 기록 저장의 성공·실패는 본류의 복귀 코드·종료를
    #   바꾸지 않습니다(명세 2.10 W3 '→ 그대로 진행'). 비커스텀·커스텀 × 저장 성공·실패(사용 중) → 헬퍼 1 · 복귀 코드 [0] · exit 없음 · 마지막 줄 [완료] /
    #   정리 전용 → 기록 0 · 복귀 코드 [10] · exit 10 / 저장 함수 예외(구현 결함 주입) → 감싸지 않아 예외가 꼬리 밖으로 · 헬퍼·복귀 0(최상위 catch 의 코드 1 로 드러남 - R2-5)
    $tailCases = @(
        @{ N = '비커스텀 저장 성공'; Custom = $false; Cleanup = $false; Hold = $false; Throw = $false },
        @{ N = '비커스텀 저장 실패(사용 중)'; Custom = $false; Cleanup = $false; Hold = $true; Throw = $false },
        @{ N = '커스텀 저장 성공'; Custom = $true; Cleanup = $false; Hold = $false; Throw = $false },
        @{ N = '커스텀 저장 실패(사용 중)'; Custom = $true; Cleanup = $false; Hold = $true; Throw = $false },
        @{ N = '커스텀 정리 전용'; Custom = $true; Cleanup = $true; Hold = $false; Throw = $false },
        @{ N = '저장 함수 예외'; Custom = $false; Cleanup = $false; Hold = $false; Throw = $true })
    $tailRows = foreach ($tailCase in $tailCases) {
        Initialize-HandoffRow -Custom $tailCase.Custom -DiskContext $(if ($tailCase.Custom) { $fixture.Now } else { $null })
        $script:runId = [guid]::NewGuid().ToString('D')
        $env:HONEYNOGI_RUN_ID = $script:runId
        Start-NextCycle
        $worker = Invoke-WorkerClearedRecord -Custom $tailCase.Custom -CleanupOnly $tailCase.Cleanup -Run 'tail' -HoldLock:$tailCase.Hold -UpdateThrows:$tailCase.Throw
        $lastLine = $(if (@($worker.Logs).Count -gt 0) { @($worker.Logs)[-1] } else { '(줄 없음)' })
        '{0}: 기록 {1} · 헬퍼 {2} · 복귀 [{3}] · exit [{4}] · 예외 [{5}] · 마지막 줄 [{6}]' -f $tailCase.N, $worker.NewCount, $worker.ExitClicks, ($worker.ReturnCodes -join ','),
            $worker.TailExit, $worker.Error, $lastLine
    }
    $tailDone = '[완료] 어비스 선택 화면 복귀 완료'
    Assert-Case '결합 7 꼬리 전체(exit 가로챔): 저장 성공·실패 → 헬퍼 1 · 복귀 [0] · exit 없음 · [완료] / 정리 전용 → 기록 0 · 복귀 [10] · exit 10 / 저장 함수 예외 → 밖으로 · 헬퍼·복귀 0' `
        ($tailRows -join ' ## ') `
        ((@(
                    ('비커스텀 저장 성공: 기록 1 · 헬퍼 1 · 복귀 [0] · exit [] · 예외 [] · 마지막 줄 [{0}]' -f $tailDone),
                    ('비커스텀 저장 실패(사용 중): 기록 0 · 헬퍼 1 · 복귀 [0] · exit [] · 예외 [] · 마지막 줄 [{0}]' -f $tailDone),
                    ('커스텀 저장 성공: 기록 1 · 헬퍼 1 · 복귀 [0] · exit [] · 예외 [] · 마지막 줄 [{0}]' -f $tailDone),
                    ('커스텀 저장 실패(사용 중): 기록 0 · 헬퍼 1 · 복귀 [0] · exit [] · 예외 [] · 마지막 줄 [{0}]' -f $tailDone),
                    ('커스텀 정리 전용: 기록 0 · 헬퍼 1 · 복귀 [10] · exit [10] · 예외 [] · 마지막 줄 [{0}]' -f $tailDone),
                    ('저장 함수 예외: 기록 0 · 헬퍼 0 · 복귀 [] · exit [] · 예외 [{0}] · 마지막 줄 [(줄 없음)]' -f $INJECTED_UPDATE_EXCEPTION)) -join ' ## '))

    # 결합 8 클리어 결과별(비커스텀 · 완료 기록 if 의 조건식을 행동으로): 'reward'(보상 화면을 사용자가 넘긴 판) → 기록 1 / 'selection'·'left'(클리어 근거 없음 -
    #   'left' 는 본류가 앞에서 코드 10 으로 끝내지만 조건식도 받지 않음) → 기록 0 · 줄 0. 셋 다 헬퍼는 그대로 1
    $outcomeRows = foreach ($clearOutcomeCase in @('reward', 'selection', 'left')) {
        Initialize-HandoffRow
        $script:runId = [guid]::NewGuid().ToString('D')
        $env:HONEYNOGI_RUN_ID = $script:runId
        $worker = Invoke-WorkerClearedRecord -Custom $false -ClearOutcome $clearOutcomeCase
        '{0}: 기록 {1} · 줄 {2} · 헬퍼 {3}' -f $clearOutcomeCase, $worker.NewCount, @($worker.Logs).Count, $worker.ExitClicks
    }
    Assert-Case "결합 8 클리어 결과별: reward → 기록 1 · 성공 줄 1 / selection·left → 기록 0 · 줄 0 · 헬퍼는 셋 다 1" ($outcomeRows -join ' ## ') `
        'reward: 기록 1 · 줄 1 · 헬퍼 1 ## selection: 기록 0 · 줄 0 · 헬퍼 1 ## left: 기록 0 · 줄 0 · 헬퍼 1'
}

# ===== S 정적 (단계 2.7 - 주석 뺀 GUI 사본) =====
function Test-CaseCode4Static {
    # S16 새 함수 서명(명세 2.7 - 계상 실행은 무인자, 선택 인자는 형식 없이)
    $signatureText = (@('Get-WorkerDoneMarkers', 'Get-Code4JournalPlan', 'Invoke-Code4Accounting', 'Get-Code4StopPlan') | ForEach-Object { '{0}({1})' -f $_, (Get-ParamSignature $guiAst $_) }) -join ' / '
    Assert-Case 'S16 코드 4 함수 서명' $signatureText `
        ('Get-WorkerDoneMarkers(String $Reason) / Get-Code4JournalPlan(Boolean $MarkerValid, Boolean $InRange, String $ReadStatus, Object $Journal, Object $Owner, Object $Generation, Boolean $PostClear) / ' +
        'Invoke-Code4Accounting((매개변수 없음)) / Get-Code4StopPlan(String $Code4Reason, String $LaunchKind, Object $Hold)')
    # S17 호출 소유자: 계상·끝 정지 계획 = 타이머 1곳씩 · 결정 = 계상 함수 · 표지 판별 = 코드 0·11 재입장 판별 + 코드 4 계상(같은 함수 - 명세 2.7 ①)
    Assert-Case 'S17 호출 소유자: 계상 = 타이머 · 끝 정지 계획 = 타이머 · 결정 = 계상 · 표지 판별 = 재입장 판별·계상' `
        ((@('Invoke-Code4Accounting', 'Get-Code4StopPlan', 'Get-Code4JournalPlan', 'Get-WorkerDoneMarkers') | ForEach-Object { Get-GuiCallOwners $_ }) -join ' / ') `
        '1|(함수 밖) / 1|(함수 밖) / 1|Invoke-Code4Accounting / 2|Get-AbyssExitHandoffKind,Invoke-Code4Accounting'
    # S18 마커 경로는 계상 함수 안 1곳 - 예전 조건식 원문 1 · 항목 완료 줄 2(마커·기록 경로) · 끝 처리 호출 1(진입 컨텍스트 · 재전달 표지), 타이머 코드 4 갈래에는
    #     계상·전진·마커 정리·위치 읽기·+1 이 0(옮기다 사본이 남으면 두 번 셉니다)
    $accountingCode = Remove-SourceComments -Text $guiFunctionTexts['Invoke-Code4Accounting']
    $exitChains = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -ceq '($exitCode -eq 0) -or ($exitCode -eq 11)') }, $true))
    $code4Clause = ''
    if ($exitChains.Count -eq 1) {
        $code4Clause = (@($exitChains[0].Clauses | Where-Object { $_.Item1.Extent.Text -ceq '$exitCode -eq 4' } | ForEach-Object { Remove-SourceComments -Text $_.Item2.Extent.Text })) -join ''
    }
    $timerLeft = @('Test-CustomMarkerValidForCurrent', 'Step-CustomProgress', 'Clear-CustomMarkerFile', 'Get-CustomCurrentContext', '$script:completedCycles++') |
        ForEach-Object { [regex]::Matches($code4Clause, [regex]::Escape($_)).Count }
    Assert-Case 'S18 계상 함수 안: 마커 경로 조건식 1 · 항목 완료 줄 2 · 끝 처리 호출 1 || 타이머 코드 4 갈래(있음 1): 유효 판정·전진·마커 정리·위치 읽기·+1 = 0' `
        ('{0} · {1} · {2} || {3} · [{4}]' -f [regex]::Matches($accountingCode, [regex]::Escape('$script:customActive -and -not $script:customMarkerIgnore -and (Test-CustomMarkerValidForCurrent)')).Count,
            [regex]::Matches($accountingCode, [regex]::Escape('Add-GuiLog "[커스텀] $($finishedContext.Position) 항목 완료"')).Count,
            [regex]::Matches($accountingCode, [regex]::Escape('Complete-AbyssExitJournal -ExitCode 4 -Context $finishedContext -KeepLaunched:$relayMarker')).Count,
            [int]($code4Clause.Length -gt 0), ($timerLeft -join ',')) '1 · 2 · 1 || 1 · [0,0,0,0,0]'
    # S19 계상 함수 구조(명세 5절 A4): 본문 = try 하나(catch 1 · catch 끝 = return $false - 정지 뒤 타이머가 return)
    $accountingAst = Get-GuiFunctionAstByName 'Invoke-Code4Accounting'
    $bodyStatements = @($accountingAst.Body.EndBlock.Statements)
    $catchLast = ''
    if (($bodyStatements.Count -eq 1) -and ($bodyStatements[0] -is [System.Management.Automation.Language.TryStatementAst]) -and ($bodyStatements[0].CatchClauses.Count -ge 1)) {
        $catchLast = @($bodyStatements[0].CatchClauses[0].Body.Statements)[-1].Extent.Text
    }
    Assert-Case 'S19 계상 함수 본문 = try 하나 · catch 끝 = return $false' ('{0} · {1}' -f $bodyStatements.Count, $catchLast) '1 · return $false'
}

# ===== 단계 2.8 하니스 =====
function Get-EntryResumeAttempts {
    # 완료 기록 항목의 재개 횟수(resumeAttempts) - 항목 없음 -1
    param($Journal, [string]$Nonce)
    foreach ($entry in @($Journal.entries)) { if ([string]$entry.nonce -eq $Nonce) { return [int]$entry.resumeAttempts } }
    return -1
}

# ===== C1 행동 - 재입장(reentered) 뒤 코드 1 (설계 R1 5.2 H22~H26·H40·H43·H45·H48 · dev:887 · 명세 2.8 ②④) =====
function Test-CaseCode1Reentered {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $pastTarget = [datetime]::Now.AddHours(-1)
    $futureTarget = [datetime]::Now.AddHours(1)
    $pastText = $pastTarget.ToString('HH:mm')
    $reentered = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_A
    $handoff = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    $tokenNow = Format-CustomItemToken -Item $ABYSS_ITEMS[0]
    $tokenNext = Format-CustomItemToken -Item $ABYSS_ITEMS[1]

    # H22 비커스텀 · 재입장 뒤 코드 1 → 라우팅: 재입장 오류 연속 0 → 1 · 계상 1·완료 줄 → 재입장 실행부(필수 기록) → 다음 판 기동(후보 = 이 항목) · 코드 1 은 오류 연속을
    #     0 으로 되돌리지 않음(명세 5절 B4) || H45 지정 시각 전 → 같음(워커의 지정 시각 해석 실패는 GUI 판단 입력이 아님 - GUI 는 자기 지정 시각만 봄)
    Initialize-HandoffRow -Entries @($reentered)
    $row = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Entries @($reentered) -TargetTime $futureTarget
    $row45 = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'H22 비커스텀 재입장 뒤 코드 1 → 완료 줄 → 다음 판 기동 → 시작 줄 · next/NA · HANDOFF_NONCE · 항목 reentered/launched/적용 · 계상 1 · 재입장 오류 연속 0 → 1 · 읽기 1·저장 2 · 예외 0 || H45 지정 시각 전 → 같은 흐름' `
        ('{0} · {1}/{2} · {3} · {4} · {5} · {6} · {7}/{8} · [{9}] || {10} · {11}/{12}' -f $row.Flow, $row.Kind, $row.Nonce, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE'], (Get-EntryText $row.Journal $NONCE_A),
            $row.Completed, $row.AbyssErrorStreak, $row.Reads, $row.Updates, $row.Thrown, $row45.Flow, $row45.Kind, $row45.Nonce) `
        ('gui|=== 1회차 완료 === / launch|powershell.exe / gui|=== 2회차 시작 === · next/NA · {0} · reentered/launched/1 · 1 · 1 · 1/2 · [] || gui|=== 1회차 완료 === / launch|powershell.exe / gui|=== 2회차 시작 === · next/NA' -f $NONCE_A)
    # H23 지정 시각 뒤(코드 1 은 11 이 아니라 시간 칸이 삶) · H43 지정 횟수 도달(완결용) · H25 안전 중지 → 각 보류 사유로 마무리 실행 기동(정지 0 · 시작 줄 없음)
    $finishRows = @(
        @{ N = 'H23 지정 시각 뒤'; Setup = @{ TargetTime = $pastTarget }; Reason = ('지정 시간({0}) 도달' -f $pastText); Done = 1 }
        @{ N = 'H43 지정 횟수 도달(2회)'; Setup = @{ TargetCycles = 2; CompletedCycles = 1 }; Reason = '지정 횟수 완료'; Done = 2 }
        @{ N = 'H25 안전 중지(비커스텀)'; Setup = @{ StopRequested = $true }; Reason = '안전 중지'; Done = 1 }
    )
    foreach ($finishRow in $finishRows) {
        $setup = @{ Entries = @($reentered) } + $finishRow.Setup
        Initialize-HandoffRow @setup
        $row = Invoke-HandoffTick -ExitCode 1
        Assert-Case ('{0} · 재입장 뒤 코드 1 → 완료 줄 → 마무리 실행 안내 → 기동 · 정지 0 · 보류 사유·오류 아님 · HANDOFF_NONCE · FINISH_ONLY' -f $finishRow.N) `
            ('{0} · {1}/{2} · {3}|{4} · {5}|{6}' -f $row.Flow, $row.Kind, $row.Nonce, $row.Hold.Reason, $row.Hold.IsError, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE'], $row.LaunchEnv['HONEYNOGI_FINISH_ONLY']) `
            ('gui|=== {0}회차 완료 === / gui|{1} / launch|powershell.exe · finish-only/NA · {2}|False · {3}|1' -f $finishRow.Done, ($FINISH_NOTICE_FORMAT -f '[안내]', $finishRow.Reason), $finishRow.Reason, $NONCE_A)
    }

    # H24 커스텀 재입장 뒤 코드 1 → 계상 1·항목 완료 줄(진행 전 위치 i) → 실행부: 오류 연속 0 · PREV = i · 전진 i → i+1 · 마커 정리 → 다음 판 기동(i+1 - 후보 = 이 항목).
    #     커스텀은 비커스텀 재입장 오류 연속(세션 상한)을 세지 않음(2 그대로)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -AbyssErrorStreak 2
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'H24 커스텀 재입장 뒤 코드 1 → 항목 완료 줄 → 전진 → 다음 판 기동(2/3) · next/NA · ITEM = i+1 · PREV = i · 진행 1/1 · 오류 연속 1 → 0 · 마커 정리 2 · 재입장 오류 연속 2 그대로 · 항목 reentered/launched/적용' `
        ('{0} · {1}/{2} · {3} · {4} · {5} · {6} · {7} · {8} · {9}' -f $row.Flow, $row.Kind, $row.Nonce, [int]($row.LaunchEnv['HONEYNOGI_CUSTOM_ITEM'] -ceq $tokenNext), [int]($row.PrevItem -ceq $tokenNow), $row.Disk,
            $row.CustomErrorStreak, $row.MarkerClears, $row.AbyssErrorStreak, (Get-EntryText $row.Journal $NONCE_A)) `
        ('gui|[커스텀] {0} 항목 완료 / step / launch|powershell.exe / gui|=== 2회차 시작(2/3) === · next/NA · 1 · 1 · 1/1 · 0 · 2 · 2 · reentered/launched/1' -f $fixture.Now.Position)
    # H24′ 마무리 복구 기동(복구 대기 중)의 커스텀 재입장 뒤 코드 1 → 계상 1 · 항목 완료 줄 대신 실행부의 '마무리 복구 완료' 줄(코드 0·11 공통 구간과 같은 규칙) → 다음 판 기동 ·
    #      복구 대기 해제 · RECOVERY 빈 값
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -RecoveryPending $true
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'H24′ 복구 기동의 커스텀 재입장 뒤 코드 1 → 전진 → 마무리 복구 완료 줄 → 다음 판 기동 · 계상 1 · 복구 대기 False · RECOVERY 빈 값' `
        ('{0} · {1} · {2} · [{3}]' -f $row.Flow, $row.Completed, $row.RecoveryPending, $row.LaunchEnv['HONEYNOGI_CUSTOM_RECOVERY']) `
        ('step / gui|{0} / launch|powershell.exe / gui|=== 2회차 시작(2/3) === · 1 · False · []' -f $RECOVERY_DONE_LINE)
    # H25 커스텀 + 안전 중지 → 전진 뒤 마무리 실행 '안전 중지' · 보류 Owner = i+1 + 세대
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'H25 커스텀 재입장 뒤 코드 1 + 안전 중지 → 항목 완료 줄 → 전진 → 마무리 실행 안내 → 기동 · finish-only/NA · 보류 safe-stop · Owner 1/1 + 세대 · 진행 1/1' `
        ('{0} · {1}/{2} · {3}|{4}|{5}/{6}/{7} · {8}' -f $row.Flow, $row.Kind, $row.Nonce, $row.Hold.Kind, $row.Hold.IsError, $row.Hold.Owner.lap, $row.Hold.Owner.index, $row.Hold.Owner.generation, $row.Disk) `
        ('gui|[커스텀] {0} 항목 완료 / step / gui|{1} / launch|powershell.exe · finish-only/NA · safe-stop|False|1/1/{2} · 1/1' -f $fixture.Now.Position, ($FINISH_NOTICE_FORMAT -f '[안내]', '안전 중지'), $H_GENERATION)
    # H26 커스텀 진행 저장 실패 → 대기열 원소 단계 code1-routed(코드 1 라우팅의 같은 실패 - 명세 2.8 ④ · 5절 B7, owner = 끝난 판 i) → 마무리 실행(보류 step-failed · 오류) · 마커 정리 0
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -StepFailures 1
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'H26 커스텀 재입장 뒤 코드 1 + 진행 저장 실패 → [경고] 마무리 실행 안내 → 기동 · 정지 0 · 대기열 code1-routed(NA · 1/0 · 세대) · 진행 1/0 · 보류 step-failed/오류 · 마커 정리 0' `
        ('{0} · {1} · {2} · {3}|{4} · {5}' -f $row.Flow, (Get-QueueText $row.Journal), $row.Disk, $row.Hold.Kind, $row.Hold.IsError, $row.MarkerClears) `
        ('gui|[커스텀] {0} 항목 완료 / step / gui|{1} / launch|powershell.exe · code1-routed:NA:1/0:g{2} · 1/0 · step-failed|True · 0' -f $fixture.Now.Position, ($FINISH_NOTICE_FORMAT -f '[경고]', '커스텀 진행 기록 저장 실패'), $H_GENERATION)

    # H40 재개(resume) 워커가 reentered 를 쓴 뒤 코드 1 → 이번 기동 nonce = 이 항목이라 필수 기록이 done 으로 닫지 않음(launched 유지) → 다음 판 기동이 같은 항목
    #     (비커스텀 || 커스텀 - 진행 i → i+1)
    $resumedPlain = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    Initialize-HandoffRow -Entries @($resumedPlain) -LaunchKind 'resume' -LaunchNonce $NONCE_A
    $rowPlain = Invoke-HandoffTick -ExitCode 1
    $resumedCustom = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($resumedCustom) -LaunchKind 'resume' -LaunchNonce $NONCE_A
    $rowCustom = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'H40 재개 기동의 reentered 뒤 코드 1 → 계상 1 · 다음 판 기동 HANDOFF_NONCE = 같은 항목 · 항목 launched 유지·적용 (비커스텀 || 커스텀 - 진행 1/1)' `
        ('{0} · {1}/{2} · {3} || {4} · {5}/{6} · {7} · {8}' -f $rowPlain.Completed, $rowPlain.Kind, $rowPlain.Nonce, (Get-EntryText $rowPlain.Journal $NONCE_A),
            $rowCustom.Completed, $rowCustom.Kind, $rowCustom.Nonce, (Get-EntryText $rowCustom.Journal $NONCE_A), $rowCustom.Disk) `
        '1 · next/NA · reentered/launched/1 || 1 · next/NA · reentered/launched/1 · 1/1'

    # H48 비커스텀 재입장 오류 연속 상한(설계 v10 6.1 '상한 2 → 3회째 정지' · 설계 R1 H48 - 함수 안 순서라 원문 패턴이 아니라 행동으로, 검토 P3-16): 연속 1 → 2 는 이어 감
    #     (다음 판 기동) / 2 → 3 회째는 라우팅이 실행부 앞에서 오류 정지 + 재입장 꼬리 - 계상·완료 줄 0 · 필수 기록·기동 0(실행부 호출 0) · 항목 그대로
    Initialize-HandoffRow -Entries @($reentered) -AbyssErrorStreak 1
    $rowSecond = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Entries @($reentered) -AbyssErrorStreak 2
    $rowThird = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'H48 재입장 오류 연속 1 → 2 이어 감(기동 1 · next) || 2 → 3 회째 → 정지(상한 + 꼬리) · 빨강 · 계상 0 · 저장 0 · 기동 0 · 항목 그대로 · 연속 3' `
        ('{0}:{1}/{2} || {3} · {4} · {5} · {6} · {7} · {8} · {9}' -f $rowSecond.AbyssErrorStreak, $rowSecond.Launches, $rowSecond.Kind, $rowThird.Flow, $rowThird.Color, $rowThird.Completed, $rowThird.Updates,
            $rowThird.Launches, (Get-EntryText $rowThird.Journal $NONCE_A), $rowThird.AbyssErrorStreak) `
        ('2:1/next || stop|{0}{1}|True · Firebrick · 0 · 0 · 0 · reentered/pending/0 · 3' -f $C1_STREAK_STOP, $STOP_TAIL)
}

# ===== C1 행동 - 마무리 실행 기동의 코드 1·그 밖 코드 (설계 R1 3.7 표 마지막 행 · H32b·H32c · dev:892 · 변이 R1-M17) =====
function Test-CaseCode1FinishOnly {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    # H32b 커스텀 마무리 실행(보류 step-failed - 디스크 i · 대기열 A1 · 마무리 실행 워커의 마커 i+1)의 코드 1 → 갈래 첫 문장이 오류 정지 · 빨강 · 재시작 0 · 라우팅·끝 처리 0
    #      (journal 읽기·저장 0) · 파일 그대로(대기열·마커·launched - 다음 수동 시작이 그 판을 이어받음) · 전진 0
    $handoff = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $errorHold = @{ Kind = 'step-failed'; Reason = '커스텀 진행 기록 저장 실패'; IsError = $true; Owner = $fixture.OwnerNext; Position = $fixture.Next.Position; Snapshot = $fixture.Now }
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $errorHold
    [void](Add-AbyssPendingEntry -Stage 'inside-handoff' -Owner $fixture.OwnerNow -Generation $H_GENERATION -Nonce $NONCE_A)
    Write-ContextMarker -Context $fixture.Next
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'H32b 커스텀 마무리 실행의 코드 1 → 오류 정지(자동 재시작 없음) · 빨강 · 기동 0 · 읽기·저장 0 · 전진 0 · 파일 그대로 · 대기열 A1 · NA launched' `
        ('{0} · {1} · {2} · {3}/{4} · {5} · {6} · {7} · {8}' -f $row.Flow, $row.Color, $row.Launches, $row.Reads, $row.Updates, $row.Steps, $row.StateUnchanged, (Get-QueueText $row.Journal), (Get-EntryText $row.Journal $NONCE_A)) `
        ('stop|{0}|True · Firebrick · 0 · 0/0 · 0 · 1 · inside-handoff:NA:1/0:g{1} · reentered/launched/1' -f ($C1_FINISH_FORMAT -f 1), $H_GENERATION)
    # H32c 비커스텀 마무리 실행(보류 안전 중지)의 코드 1 · 그 밖 크래시 코드(-1) → 같은 오류 정지(코드 번호만 다름) · 기동 0 · 읽기·저장 0 · NA launched 그대로
    $launchedPlain = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    $safeHold = @{ Kind = 'safe-stop'; Reason = '안전 중지'; IsError = $false; Owner = @{ runId = 'run-H' }; Position = ''; Snapshot = $null }
    $codeTexts = foreach ($finishCode in @(1, -1)) {
        Initialize-HandoffRow -Entries @($launchedPlain) -Applied @($NONCE_A) -LaunchKind 'finish-only' -LaunchNonce $NONCE_A -FinishOnlyHold $safeHold
        $codeRow = Invoke-HandoffTick -ExitCode $finishCode
        '{0}: {1} · {2} · {3}/{4} · {5}' -f $finishCode, $codeRow.Flow, $codeRow.Launches, $codeRow.Reads, $codeRow.Updates, (Get-EntryText $codeRow.Journal $NONCE_A)
    }
    Assert-Case 'H32c 비커스텀 마무리 실행의 코드 1 || 그 밖 코드 -1 → 오류 정지(그 코드) · 기동 0 · 읽기·저장 0 · NA launched' ($codeTexts -join ' || ') `
        ('1: stop|{0}|True · 0 · 0/0 · reentered/launched/1 || -1: stop|{1}|True · 0 · 0/0 · reentered/launched/1' -f ($C1_FINISH_FORMAT -f 1), ($C1_FINISH_FORMAT -f -1))
}

# ===== C1 행동 - 재입장 요청(retry-*) 뒤 코드 1 (dev:888·889 · 명세 2.8 ② · 3.4 '켜짐 갈래는 진리표' · 5절 B10) =====
function Test-CaseCode1Retry {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $clickedPlain = New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -Nonce $NONCE_A
    $attemptCustom = New-FixtureEntry -Stage 'retry-attempt' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    # RT1 이 빌드(재개 기능 꺼짐 - GUI 원문 값) · retry-clicked(비커스텀) / retry-attempt(커스텀 · 마커 있음) → 정지(꺼짐 문구) · 빨강 · 계상·기동·저장 0 · 파일 그대로(마커 포함)
    #    (명세 3.4 '플래그 off + retry-* + 코드 1 → 기동 0·정지·보존')
    Initialize-HandoffRow -Entries @($clickedPlain)
    $rowPlain = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($attemptCustom)
    Write-ContextMarker -Context $fixture.Now
    $rowCustom = Invoke-HandoffTick -ExitCode 1
    Assert-Case ('RT1 재개 기능 꺼짐(GUI 원문 값 {0}) · 재입장 요청 뒤 코드 1 → 정지(꺼짐) · 빨강 · 계상/기동/저장 0 · 파일 그대로 (비커스텀 || 커스텀 - 전진·마커 정리 0)' -f $GUI_RETRY_FLAG) `
        ('{0} · {1} · {2}/{3}/{4} · {5} || {6} · {7}/{8}/{9} · {10} · {11}/{12}' -f $rowPlain.Flow, $rowPlain.Color, $rowPlain.Completed, $rowPlain.Launches, $rowPlain.Updates, $rowPlain.StateUnchanged,
            $rowCustom.Flow, $rowCustom.Completed, $rowCustom.Launches, $rowCustom.Updates, $rowCustom.StateUnchanged, $rowCustom.Steps, $rowCustom.MarkerClears) `
        ('stop|{0}|True · Firebrick · 0/0/0 · 1 || stop|{0}|True · 0/0/0 · 1 · 0/0' -f $C1_RETRY_OFF)
    # RT1′ 재개 기능 꺼짐(이 행은 꺼짐을 직접 둠) + 안전 중지 + retry-clicked → 꺼짐 오류 정지가 이김(명세 2.8 ② - 안전 중지 갈래는 켜진 빌드에서만): [안내] 0 ·
    #      '안전 중지' 정상 정지 아님 · 기동 0 · 파일 그대로 (단계 2.7~2.9 구현 검증 - 생존 변이 '안전 중지 검사를 꺼짐 검사 앞으로' 를 가름: RT1 에 안전 중지 조합이 없었음)
    Initialize-HandoffRow -Entries @($clickedPlain) -StopRequested $true
    $script:abyssPartyRetryEnabled = $false
    try { $row = Invoke-HandoffTick -ExitCode 1 } finally { $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG }
    Assert-Case 'RT1′ 재개 꺼짐 + 안전 중지 + retry-clicked → 꺼짐 오류 정지 · [안내] 0 · 기동 0 · 파일 그대로' ('{0} · {1} · {2}' -f $row.Flow, $row.Launches, $row.StateUnchanged) `
        ('stop|{0}|True · 0 · 1' -f $C1_RETRY_OFF)
    # RT2 재개를 한 번 한 판(재개 횟수 1)이 또 코드 1 → 꺼짐·켜짐 무관하게 정지(자동 재개는 한 번뿐 - dev:889) · 기동 0 · 파일 그대로
    $resumedOnce = New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    $resumedOnce.resumeAttempts = 1
    try {
        $againTexts = foreach ($flag in @($false, $true)) {
            Initialize-HandoffRow -Entries @($resumedOnce) -LaunchKind 'resume' -LaunchNonce $NONCE_A
            $script:abyssPartyRetryEnabled = $flag
            $againRow = Invoke-HandoffTick -ExitCode 1
            '{0}: {1} · {2} · {3}' -f $flag, $againRow.Flow, $againRow.Launches, $againRow.StateUnchanged
        }
        Assert-Case 'RT2 재개 1회 뒤 또 코드 1 → 정지(한 번뿐) · 기동 0 · 파일 그대로 (플래그 꺼짐 || 켜짐)' ($againTexts -join ' || ') `
            ('False: stop|{0}|True · 0 · 1 || True: stop|{0}|True · 0 · 1' -f $C1_RESUMED_AGAIN)

        # RT3 켜진 빌드(진리표) + 안전 중지 → [안내] 1줄 → '안전 중지' 정지 · 재개 0 · 재개 횟수 기록 0 · 파일 그대로 (dev:888 원문 · 설계 R1 9절 미결 4)
        Initialize-HandoffRow -Entries @($clickedPlain) -StopRequested $true
        $script:abyssPartyRetryEnabled = $true
        $row = Invoke-HandoffTick -ExitCode 1
        Assert-Case 'RT3 켜진 빌드 + 안전 중지 → [안내] → 안전 중지 정지 · 기동 0 · 저장 0 · 파일 그대로' ('{0} · {1} · {2} · {3}' -f $row.Flow, $row.Launches, $row.Updates, $row.StateUnchanged) `
            ('gui|{0} / stop|안전 중지|False · 0 · 0 · 1' -f $C1_SAFE_NOTICE)
        # RT4 켜진 빌드 · 비커스텀 → 재개 횟수 0 → 1 기록 → [경고] → 재개 기동(실제 후보 고르기의 재개 = 같은 항목 · RESUME_REENTRY 1 · 기동 종류 resume) → 시작 줄 · 항목 launched(미적용)
        Initialize-HandoffRow -Entries @($clickedPlain)
        $script:abyssPartyRetryEnabled = $true
        $row = Invoke-HandoffTick -ExitCode 1
        Assert-Case 'RT4 켜진 빌드 · 비커스텀 → [경고] 재개 → 기동 → 시작 줄 · resume/NA · HANDOFF_NONCE|RESUME_REENTRY · 재개 횟수 1 · 항목 retry-clicked/launched/0 · 계상 0 · 저장 2(재개 횟수 + 후보 고르기)' `
            ('{0} · {1}/{2} · {3}|{4} · {5} · {6} · {7} · {8}' -f $row.Flow, $row.Kind, $row.Nonce, $row.LaunchEnv['HONEYNOGI_HANDOFF_NONCE'], $row.LaunchEnv['HONEYNOGI_RESUME_REENTRY'],
                (Get-EntryResumeAttempts $row.Journal $NONCE_A), (Get-EntryText $row.Journal $NONCE_A), $row.Completed, $row.Updates) `
            ('gui|{0} / launch|powershell.exe / gui|=== 1회차 시작 === · resume/NA · {1}|1 · 1 · retry-clicked/launched/0 · 0 · 2' -f $C1_RESUME_NOTICE, $NONCE_A)
        # RT5 켜진 빌드 · 커스텀(마커 있음 · 재시작·복구 대기가 켜진 채) → 오류 연속 1 → 2 · 재개는 재시작·복구가 아님(RESTART·RECOVERY 빈 값) · 마커 정리 0(-PreserveMarker) ·
        #    MARKER = 마커 경로 · 마커 그대로(재개 판이 이어서 소비할 근거) · 재개 횟수 1
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($attemptCustom) -RecoveryPending $true
        $script:abyssPartyRetryEnabled = $true
        $script:customRestart = $true
        Write-ContextMarker -Context $fixture.Now
        $markerBefore = [IO.File]::ReadAllText($script:customMarkerFile)
        $row = Invoke-HandoffTick -ExitCode 1
        Assert-Case 'RT5 켜진 빌드 · 커스텀 → 재개 기동 · resume/NA · 오류 연속 1 → 2 · [RESTART|RECOVERY] 빈 값 · RESUME 1 · 마커 정리 0 · MARKER = 마커 경로 · 마커 그대로 · 재개 횟수 1 · 진행 1/0' `
            ('{0}/{1} · {2} · [{3}|{4}] · {5} · {6} · {7} · {8} · {9} · {10}' -f $row.Kind, $row.Nonce, $row.CustomErrorStreak, $row.LaunchEnv['HONEYNOGI_CUSTOM_RESTART'], $row.LaunchEnv['HONEYNOGI_CUSTOM_RECOVERY'],
                $row.LaunchEnv['HONEYNOGI_RESUME_REENTRY'], $row.MarkerClears, [int]($row.LaunchEnv['HONEYNOGI_CUSTOM_MARKER'] -ceq $script:customMarkerFile),
                [int]([IO.File]::ReadAllText($script:customMarkerFile) -ceq $markerBefore), (Get-EntryResumeAttempts $row.Journal $NONCE_A), $row.Disk) `
            'resume/NA · 2 · [|] · 1 · 0 · 1 · 1 · 1 · 1/0'
        # RT6 켜진 빌드 · 재개 횟수 기록 실패 → 재개 0 · 오류 정지: 사용 중(감시 태그 - 비커스텀 '기록 보존' / 커스텀 '기록·마커 보존' + 안내) · 손상(사용 중처럼 재개 보류 ·
        #    보존 범위 + 위치 안내 - 단계 2.7·2.8 구현 리뷰 확인 라운드) · 판별한 항목이 그 사이 사라짐(실제 -Expect - 저장 전 갈고리가 실제 저장소로 항목을 지움) → 재개 기록
        #    저장 실패. 넷 다 기동 0
        $failTexts = @()
        foreach ($failCase in @(@{ N = '사용 중 비커스텀'; Custom = $false; Tag = 'locked' }, @{ N = '사용 중 커스텀'; Custom = $true; Tag = 'locked' }, @{ N = '손상'; Custom = $false; Tag = 'corrupt' })) {
            if ($failCase.Custom) { Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($attemptCustom) } else { Initialize-HandoffRow -Entries @($clickedPlain) }
            $script:abyssPartyRetryEnabled = $true
            $failRow = Invoke-HandoffTick -ExitCode 1 -UpdateTagAt @{ At = 1; Tag = $failCase.Tag }
            $failTexts += ('{0}: {1} · {2} · {3}' -f $failCase.N, $failRow.Flow, $failRow.Launches, (Get-EntryResumeAttempts $failRow.Journal $NONCE_A))
        }
        Initialize-HandoffRow -Entries @($clickedPlain)
        $script:abyssPartyRetryEnabled = $true
        $dropHook = {
            $dropMutator = { param($journal, $change) $journal.entries = @(); $change.Changed = $true }
            [void](Invoke-RealUpdateAbyssJournal -Path $script:abyssJournalPath -Mutator $dropMutator)
        }
        $dropRow = Invoke-HandoffTick -ExitCode 1 -PreUpdateAt 1 -PreUpdateHook $dropHook
        $failTexts += ('항목 사라짐: {0} · {1}' -f $dropRow.Flow, $dropRow.Launches)
        Assert-Case "RT6 켜진 빌드 · 재개 횟수 기록 '사용 중'(비커스텀 || 커스텀) || '손상' || 항목 사라짐(실제 -Expect) → 정지 그 문구 · 기동 0 · 재개 횟수 0" ($failTexts -join ' || ') `
            (('사용 중 비커스텀: stop|{0}|True · 0 · 0 || 사용 중 커스텀: stop|{1}|True · 0 · 0 || 손상: stop|{2}|True · 0 · 0 || 항목 사라짐: stop|{3}|True · 0') -f
                ($C1_RESUME_LOCKED_FORMAT -f '기록 보존'), ($C1_RESUME_LOCKED_FORMAT -f '기록·마커 보존'), ($C1_RESUME_CORRUPT_FORMAT -f '기록 보존'), ($C1_RESUME_SAVE_FORMAT -f '기록 보존'))
        # RT6″ 켜진 빌드 · 재개 횟수 기록 직전 다른 기록 주체가 본 파일·직전본을 손상(저장 전 갈고리 - 태그 주입이 아니라 실제 저장이 손상을 만남) → 손상 정지 하나(재개 보류 ·
        #       보존 범위 + 파일 위치 안내 - 단계 2.7·2.8 구현 리뷰 확인 라운드: 예전 글자 '파일을 보존하고 정지' 는 재개를 보류했는지·마커를 남겼는지 알 수 없었음) · 빨강 ·
        #       기동 0 · 손상 파일 그대로(증거 보존) (비커스텀 '기록 보존' || 커스텀 '기록·마커 보존' - 전진·마커 정리 0 · 마커 그대로)
        $corruptHook = {
            [IO.File]::WriteAllText($script:abyssJournalPath, 'not json', $UTF8_BOM)
            [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', 'not json', $UTF8_BOM)
        }
        $corruptTexts = foreach ($corruptCase in @(@{ N = '비커스텀'; Custom = $false }, @{ N = '커스텀'; Custom = $true })) {
            if ($corruptCase.Custom) {
                Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($attemptCustom)
                Write-ContextMarker -Context $fixture.Now
            } else {
                Initialize-HandoffRow -Entries @($clickedPlain)
            }
            $script:abyssPartyRetryEnabled = $true
            $markerBefore = $(if ([IO.File]::Exists($script:customMarkerFile)) { [IO.File]::ReadAllText($script:customMarkerFile) } else { '(없음)' })
            $corruptRow = Invoke-HandoffTick -ExitCode 1 -PreUpdateAt 1 -PreUpdateHook $corruptHook
            $markerAfter = $(if ([IO.File]::Exists($script:customMarkerFile)) { [IO.File]::ReadAllText($script:customMarkerFile) } else { '(없음)' })
            $journalKept = [int](([IO.File]::ReadAllText($script:abyssJournalPath) -ceq 'not json') -and ([IO.File]::ReadAllText($script:abyssJournalPath + '.bak') -ceq 'not json'))
            '{0}: {1} · {2} · {3} · 저장 {4} · {5}/{6} · 손상 파일 {7} · 마커 {8}' -f $corruptCase.N, $corruptRow.Flow, $corruptRow.Color, $corruptRow.Launches, $corruptRow.Updates,
                $corruptRow.Steps, $corruptRow.MarkerClears, $journalKept, [int]($markerAfter -ceq $markerBefore)
        }
        Assert-Case "RT6″ 켜진 빌드 · 재개 횟수 기록 직전 실제 손상(비커스텀 || 커스텀) → 손상 정지(재개 보류 · 보존 범위 + 위치 안내) · 빨강 · 기동 0 · 저장 1 · 전진·마커 정리 0 · 손상 파일·마커 그대로" `
            ($corruptTexts -join ' || ') `
            ('비커스텀: stop|{0}|True · Firebrick · 0 · 저장 1 · 0/0 · 손상 파일 1 · 마커 1 || 커스텀: stop|{1}|True · Firebrick · 0 · 저장 1 · 0/0 · 손상 파일 1 · 마커 1' -f
                ($C1_RESUME_CORRUPT_FORMAT -f '기록 보존'), ($C1_RESUME_CORRUPT_FORMAT -f '기록·마커 보존'))
        # RT6′ 켜진 빌드 · 판별한 항목이 그 사이 재입장 요청 단계가 아니게 바뀜(다른 기록 주체 - 저장 전 갈고리가 실제 저장소로 단계만 바꿈, 항목은 남음) → 재개 횟수
        #      기록의 실제 -Expect 가 거절 → 재개 기록 저장 실패 정지 · 기동 0 · 재개 횟수 0 (단계 2.7~2.9 구현 검증 - 생존 변이 '-Expect 제거' 를 가름: RT6 '항목 사라짐' 은
        #      -Expect 가 없어도 mutator 가 항목을 못 찾아 같은 결과였음)
        Initialize-HandoffRow -Entries @($clickedPlain)
        $script:abyssPartyRetryEnabled = $true
        $stageHook = {
            $stageMutator = { param($journal, $change) foreach ($stageEntry in @($journal.entries)) { $stageEntry.stage = 'reentered' }; $change.Changed = $true }
            [void](Invoke-RealUpdateAbyssJournal -Path $script:abyssJournalPath -Mutator $stageMutator)
        }
        $stageRow = Invoke-HandoffTick -ExitCode 1 -PreUpdateAt 1 -PreUpdateHook $stageHook
        Assert-Case 'RT6′ 켜진 빌드 · 기록 직전 단계 바뀜(실제 -Expect) → 재개 기록 저장 실패 정지 · 기동 0 · 재개 횟수 0' `
            ('{0} · {1} · {2}' -f $stageRow.Flow, $stageRow.Launches, (Get-EntryResumeAttempts $stageRow.Journal $NONCE_A)) ('stop|{0}|True · 0 · 0' -f ($C1_RESUME_SAVE_FORMAT -f '기록 보존'))
    } finally {
        $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
    }
}

# ===== C1 행동 - 클리어 기록 · 없음 → 예전 처리 · 정지 경로의 끝 처리 (명세 5절 A10 'legacy-cleared' · A6ⓐ · 2.8 ③) =====
function Test-CaseCode1Legacy {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    $plainCleared = New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_C
    $tokenNow = Format-CustomItemToken -Item $ABYSS_ITEMS[0]

    # A10 커스텀 · 완료 마커 없음 · 이 판(i)의 미적용 클리어 기록 → 'legacy-cleared' → 마커처럼 마무리 복구(같은 항목 재입장 0): 복구 문구 → 기동(RECOVERY·RESTART 1 · PREV = i) ·
    #     계상 0 · 전진 0 · 클리어 기록 미소비(복구 워커의 코드 0 이 전진 뒤 소비 - 명세 5절 A6ⓐ) · 오류 연속 1 → 2 || 클리어 뒤 정지 기록(post-clear-stop - '클리어 이상')도 같은 복구
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    $row = Invoke-HandoffTick -ExitCode 1
    $postStop = New-FixtureEntry -Stage 'post-clear-stop' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($postStop)
    $rowPost = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'A10 커스텀 · 마커 없음 · 미적용 cleared(i) + 코드 1 → 복구 문구 → 기동 · RECOVERY|RESTART 1 · PREV = i · 계상/전진 0 · cleared 미소비 · 오류 연속 2 || post-clear-stop → 같은 복구 · 미소비' `
        ('{0} · {1}|{2} · {3} · {4}/{5} · {6} · {7} || {8} · {9}' -f $row.Flow, $row.LaunchEnv['HONEYNOGI_CUSTOM_RECOVERY'], $row.LaunchEnv['HONEYNOGI_CUSTOM_RESTART'], [int]($row.PrevItem -ceq $tokenNow), $row.Completed,
            $row.Steps, (Get-EntryText $row.Journal $NONCE_C), $row.CustomErrorStreak, $rowPost.Flow, (Get-EntryText $rowPost.Journal $NONCE_C)) `
        ('gui|{0} / launch|powershell.exe / gui|=== 1회차 시작(1/3) === · 1|1 · 1 · 0/0 · cleared/pending/0 · 2 || gui|{0} / launch|powershell.exe / gui|=== 1회차 시작(1/3) === · post-clear-stop/pending/0' -f $C1_RECOVER_NOTICE)
    # A10′ 이 판이 아닌 클리어 기록(다른 칸 i+1 · 적용됨 · 다른 세대) → 'legacy' → 예전처럼 같은 항목 재시작([경고] 재시도 줄 · RECOVERY 빈 값 · RESTART 1)
    $otherCases = @(
        @{ N = '다른 칸'; Entries = @(New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C); Applied = @() }
        @{ N = '적용됨'; Entries = @($clearedNow); Applied = @($NONCE_C) }
        @{ N = '다른 세대'; Entries = @(New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation ($H_GENERATION + 1) -Section $ABYSS_SECTION -Nonce $NONCE_C); Applied = @() }
    )
    $otherTexts = foreach ($otherCase in $otherCases) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries $otherCase.Entries -Applied $otherCase.Applied
        $otherRow = Invoke-HandoffTick -ExitCode 1
        '{0}: {1} · {2}|{3}' -f $otherCase.N, $otherRow.Flow, $otherRow.LaunchEnv['HONEYNOGI_CUSTOM_RECOVERY'], $otherRow.LaunchEnv['HONEYNOGI_CUSTOM_RESTART']
    }
    $retryLine = 'gui|{0} / launch|powershell.exe / gui|=== 1회차 시작(1/3) === · |1' -f ($C1_RETRY_FORMAT -f 2)
    Assert-Case "A10′ 이 판이 아닌 클리어 기록(다른 칸 || 적용됨 || 다른 세대) → 'legacy' → 같은 항목 재시작([경고] 재시도 2/2 · RECOVERY 빈 값 · RESTART 1)" ($otherTexts -join ' || ') `
        ('다른 칸: {0} || 적용됨: {0} || 다른 세대: {0}' -f $retryLine)
    # A10″ 비커스텀 · 이 실행의 클리어 기록 + 코드 1 → 'legacy-cleared' 여도 비커스텀은 예전처럼 오류 정지(자동 재시작 없음) · 클리어 기록 미소비 · 넘긴 nonce 없음 → 저장 0
    Initialize-HandoffRow -Entries @($plainCleared)
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'A10″ 비커스텀 클리어 기록 + 코드 1 → 오류 정지(예전 글자) · 빨강 · 기동 0 · 클리어 기록 미소비 · 읽기 1·저장 0' `
        ('{0} · {1} · {2} · {3} · {4}/{5}' -f $row.Flow, $row.Color, $row.Launches, (Get-EntryText $row.Journal $NONCE_C), $row.Reads, $row.Updates) `
        ('stop|{0}|True · Firebrick · 0 · cleared/pending/0 · 1/0' -f ($C1_STOP_PLAIN_FORMAT -f 1))
    # 단계 우선(여럿이면 앞선 단계): 같은 실행의 reentered(NA) + cleared(NC) → 재입장 실행부(다음 판 기동 NA) || retry-clicked(NB) + cleared(NC) → 재입장 요청(꺼진 빌드 = 정지)
    Initialize-HandoffRow -Entries @((New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_A), $plainCleared)
    $rowFirst = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Entries @((New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -Nonce $NONCE_B), $plainCleared)
    $rowSecond = Invoke-HandoffTick -ExitCode 1
    Assert-Case '단계 우선: reentered + cleared → 재입장 실행부(next/NA · 기동 1) || retry-clicked + cleared → 재개 기능 꺼짐 정지' `
        ('{0}/{1} · {2} || {3}' -f $rowFirst.Kind, $rowFirst.Nonce, $rowFirst.Launches, $rowSecond.Flow) ('next/NA · 1 || stop|{0}|True' -f $C1_RETRY_OFF)
    # 단계 우선′ 같은 실행의 reentered(NA) + retry-clicked(NB) → reentered 가 이김(재입장 실행부 · 다음 판 next/NA · 기동 1 - 재개 기능 꺼짐 정지가 아님) (단계 2.7~2.9 구현
    #        검증 - 생존 변이 '재입장 요청이 reentered 보다 먼저' 를 가름: 위 행은 클리어 기록 조합만 봄)
    Initialize-HandoffRow -Entries @((New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_A), (New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -Nonce $NONCE_B))
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case '단계 우선′ reentered + retry-clicked → 재입장 실행부(next/NA · 기동 1 · 정지 0)' `
        ('{0}/{1} · 기동 {2} · 정지 {3}' -f $row.Kind, $row.Nonce, $row.Launches, @($row.Events | Where-Object { $_.StartsWith('stop|') }).Count) 'next/NA · 기동 1 · 정지 0'

    # E-C1 정지 경로의 끝 처리(명세 2.8 ③): 커스텀 같은 항목 3회째(오류 연속 2) · 넘긴 nonce(own NA) · 이 판의 클리어 기록 → 'legacy-cleared' 라도 3회째 정지 → 넘긴 nonce done ·
    #      클리어 기록 미소비(명세 5절 A6ⓐ) || 비커스텀 그 밖 오류 정지(넘긴 next NB)도 같음 || 그 밖 크래시 코드(-1) → 라우팅 접근 0(읽기 0) · 끝 처리만(NB done)
    $ownLaunched = New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow, $ownLaunched) -LaunchKind 'own' -LaunchNonce $NONCE_A
    $script:customErrorStreak = 2
    $rowThird = Invoke-HandoffTick -ExitCode 1
    $nextLaunched = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_B
    Initialize-HandoffRow -Entries @($nextLaunched, $plainCleared) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowPlainStop = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Entries @($nextLaunched, $plainCleared) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowCrash = Invoke-HandoffTick -ExitCode -1
    Assert-Case 'E-C1 정지 경로 끝 처리: 커스텀 3회째 → 정지 · NA done · cleared(i) 미소비 · 읽기 1·저장 1 || 비커스텀 오류 정지 → NB done · cleared 미소비 || 코드 -1 → 읽기 0·저장 1 · NB done' `
        ('{0} · {1} · {2} · {3}/{4} || {5} · {6} · {7} || {8} · {9} · {10}/{11}' -f $rowThird.Flow, (Get-EntryText $rowThird.Journal $NONCE_A), (Get-EntryText $rowThird.Journal $NONCE_C), $rowThird.Reads, $rowThird.Updates,
            $rowPlainStop.Flow, (Get-EntryText $rowPlainStop.Journal $NONCE_B), (Get-EntryText $rowPlainStop.Journal $NONCE_C),
            $rowCrash.Flow, (Get-EntryText $rowCrash.Journal $NONCE_B), $rowCrash.Reads, $rowCrash.Updates) `
        ('stop|{0}|True · entered/done/0 · cleared/pending/0 · 1/1 || stop|{1}|True · reentered/done/1 · cleared/pending/0 || stop|{2}|True · reentered/done/1 · 0/1' -f
            $C1_STOP_THIRD, ($C1_STOP_PLAIN_FORMAT -f 1), ($C1_STOP_PLAIN_FORMAT -f -1))
    # E-C1′ 재기동 경로는 nonce 를 닫지 않음(같은 항목을 다시 넘김 - 설계 v10 6.1 'RESTART 재기동이면 유지'): 커스텀 own NA 기동의 코드 1 · 기록 없음 → retry → 재시작 기동이 같은
    #       항목(own/NA)을 다시 고름 · NA launched || 클리어 기록 있음 → recover(복구 문구) → 복구 기동도 own/NA · NA launched · 클리어 기록 미소비
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($ownLaunched) -LaunchKind 'own' -LaunchNonce $NONCE_A
    $rowRetry = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow, $ownLaunched) -LaunchKind 'own' -LaunchNonce $NONCE_A
    $rowRecover = Invoke-HandoffTick -ExitCode 1
    #       (열린 entered 는 클리어 전 단계라 라우팅이 보지 않음 - retry 행은 재시도 줄 1 · 복구 문구 0)
    Assert-Case 'E-C1′ 재기동은 nonce 유지: retry(재시도 줄 1 · 복구 문구 0) → own/NA · NA launched || recover(복구 문구 1) → own/NA · NA launched · cleared 미소비' `
        ('{0}/{1} · {2}/{3} · {4} || {5} · {6}/{7} · {8} · {9}' -f @($rowRetry.Events | Where-Object { $_ -ceq ('gui|' + ($C1_RETRY_FORMAT -f 2)) }).Count,
            @($rowRetry.Events | Where-Object { $_ -ceq ('gui|' + $C1_RECOVER_NOTICE) }).Count, $rowRetry.Kind, $rowRetry.Nonce, (Get-EntryText $rowRetry.Journal $NONCE_A),
            @($rowRecover.Events | Where-Object { $_ -ceq ('gui|' + $C1_RECOVER_NOTICE) }).Count, $rowRecover.Kind, $rowRecover.Nonce, (Get-EntryText $rowRecover.Journal $NONCE_A),
            (Get-EntryText $rowRecover.Journal $NONCE_C)) `
        '1/0 · own/NA · entered/launched/0 || 1 · own/NA · entered/launched/0 · cleared/pending/0'
    # E-C1″ 정지 경로의 끝 처리 실패(넘긴 nonce done 저장 직전 다른 주체가 잠금 - 저장 전 갈고리) → 끝 처리의 오류 정지 하나(완료 표시를 남기지 못함 · 기록 보존 + 안내) ·
    #       예전 오류 정지 없음(정지 두 번 금지 - 타이머 return) · NB launched 그대로
    Initialize-HandoffRow -Entries @($nextLaunched) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $row = Invoke-HandoffTick -ExitCode 1 -PreUpdateAt 1 -PreUpdateHook { Lock-JournalLock }
    Assert-Case "E-C1″ 정지 경로 끝 처리 '사용 중' → 정지 1번(완료 표시를 남기지 못함 · 기록 보존 + 안내) · 빨강 · NB launched" ('{0} · {1} · {2}' -f $row.Flow, $row.Color, (Get-EntryText $row.Journal $NONCE_B)) `
        ('stop|{0}|True · Firebrick · reentered/launched/1' -f $C4_END_LOCKED)
}

# ===== C1 행동 - 범위 · 완료 기록 읽기 실패 · 커스텀 진행 위치 없음 · 처리 중 예외 (명세 2.8 ② · 명세 리뷰 3 P2 · 5절 A4·B4) =====
function Test-CaseCode1Failure {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $reentered = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -Nonce $NONCE_A
    $handoff = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    $reasonA = $IH_REASON + ($IH_TAIL_FORMAT -f $NONCE_A)

    # J 범위·대상 밖이면 journal 을 열지 않고 'legacy'(읽기 0 - 명세 2.8 ② · 5절 B4): 던전 · 어비스 파티원 · 생활(어비스 라디오 보존) · 어비스지만 코드 1 이 아님(-1 · 2). 반환은 문자열 하나
    $rangeTexts = foreach ($rangeCase in @(
            @{ N = '던전'; Setup = @{ Content = 'dungeon' }; Code = 1 }, @{ N = '파티원'; Setup = @{ Mode = 'party'; Matching = 'member' }; Code = 1 },
            @{ N = '생활'; Setup = @{ Category = 'life' }; Code = 1 }, @{ N = '코드 -1'; Setup = @{}; Code = -1 }, @{ N = '코드 2'; Setup = @{}; Code = 2 })) {
        $setup = @{ Entries = @($reentered) } + $rangeCase.Setup
        Initialize-HandoffRow @setup
        $routeOut = @(Invoke-Code1JournalRouting -ExitCode $rangeCase.Code)
        '{0}: {1}:{2} · {3}' -f $rangeCase.N, $routeOut.Count, ($routeOut -join ','), $script:journalReads
    }
    Assert-Case "J 범위 밖(던전 · 파티원 · 생활) · 코드 1 아님(-1 · 2) → 'legacy' 하나 · 읽기 0" ($rangeTexts -join ' || ') `
        '던전: 1:legacy · 0 || 파티원: 1:legacy · 0 || 생활: 1:legacy · 0 || 코드 -1: 1:legacy · 0 || 코드 2: 1:legacy · 0'

    # F1 읽기 실패 → 계상·기동(재입장 이어받기·자동 재시작·재개) 보류 오류 정지 · 계상·기동 0 · 파일 그대로 · 빨강. 비커스텀(기록 보존): 사용 중 / 사용 중 + 재입장 표지(꼬리) / 손상 /
    #    읽기 실패 / 예외 || 커스텀(기록·마커 보존 - 마커 그대로 · 전진 0): 사용 중 / 읽기 실패. 손상도 사용 중처럼 실제 상태(계상·기동 보류 · 기록 보존) 뒤에 위치 안내
    #    (단계 2.7·2.8 구현 리뷰 P3 - 커스텀 손상은 F1″)
    $plainCases = @(
        @{ N = '사용 중'; Args = @{ HoldLock = $true }; Want = ('완료 기록 파일이 사용 중 - {0} {1}' -f $C1_HELD_PLAIN, $LOCKED_GUIDE) }
        @{ N = '사용 중 + 표지'; Args = @{ HoldLock = $true; Reason = $reasonA }; Want = ('완료 기록 파일이 사용 중 - {0} {1}{2}' -f $C1_HELD_PLAIN, $LOCKED_GUIDE, $STOP_TAIL) }
        @{ N = '손상'; Corrupt = $true; Args = @{}; Want = ('완료 기록 파일 손상 - {0} {1}' -f $C1_HELD_PLAIN, $CORRUPT_GUIDE) }
        @{ N = '읽기 실패'; Args = @{ HoldMainNone = $true }; Want = ('완료 기록 파일을 읽지 못해 {0}' -f $C1_HELD_PLAIN) }
        @{ N = '예외'; Throw = $true; Args = @{}; Want = ('완료 기록 파일을 읽지 못해 {0} (예외: {1})' -f $C1_HELD_PLAIN, $INJECTED_READ_EXCEPTION) }
    )
    $plainTexts = foreach ($plainCase in $plainCases) {
        if ($plainCase.Corrupt) { Initialize-HandoffRow -CorruptText 'not json' } else { Initialize-HandoffRow -Entries @($reentered) }
        $script:readThrows = [bool]$plainCase.Throw
        $tickArgs = @{ ExitCode = 1 } + $plainCase.Args
        try { $failRow = Invoke-HandoffTick @tickArgs } finally { $script:readThrows = $false }
        '{0}: {1} · {2} · {3}/{4} · {5}' -f $plainCase.N, $failRow.Flow, $failRow.Color, $failRow.Completed, $failRow.Launches, $failRow.StateUnchanged
    }
    $plainWant = foreach ($plainCase in $plainCases) { '{0}: stop|{1}|True · Firebrick · 0/0 · 1' -f $plainCase.N, $plainCase.Want }
    Assert-Case 'F1 비커스텀 코드 1 + 완료 기록 읽기 실패(사용 중 || 사용 중 + 표지 || 손상 || 읽기 실패 || 예외) → 오류 정지(계상·기동 보류 · 기록 보존) · 계상·기동 0 · 파일 그대로' `
        ($plainTexts -join ' || ') ($plainWant -join ' || ')
    $customCases = @(
        @{ N = '사용 중'; Args = @{ HoldLock = $true }; Want = ('완료 기록 파일이 사용 중 - {0} {1}' -f $C1_HELD_CUSTOM, $LOCKED_GUIDE) }
        @{ N = '읽기 실패'; Args = @{ HoldMainNone = $true }; Want = ('완료 기록 파일을 읽지 못해 {0}' -f $C1_HELD_CUSTOM) }
    )
    $customTexts = foreach ($customCase in $customCases) {
        Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($handoff)
        Write-ContextMarker -Context $fixture.Now
        $tickArgs = @{ ExitCode = 1 } + $customCase.Args
        $failRow = Invoke-HandoffTick @tickArgs
        '{0}: {1} · {2}/{3}/{4} · {5}' -f $customCase.N, $failRow.Flow, $failRow.Completed, $failRow.Steps, $failRow.Launches, $failRow.StateUnchanged
    }
    $customWant = foreach ($customCase in $customCases) { '{0}: stop|{1}|True · 0/0/0 · 1' -f $customCase.N, $customCase.Want }
    Assert-Case 'F1′ 커스텀 코드 1 + 읽기 실패(사용 중 || 읽기 실패) → 오류 정지(계상·기동 보류 · 기록·마커 보존) · 계상/전진/기동 0 · 파일 그대로(마커 포함)' ($customTexts -join ' || ') ($customWant -join ' || ')
    # F1″ 커스텀 코드 1 + 손상(본 파일·직전본 · 마커 있음) → 오류 정지(계상·기동 보류 · 기록·마커 보존 + 위치 안내 - 단계 2.7·2.8 구현 리뷰 P3) · 계상/전진/기동 0 · 파일 그대로(마커 포함)
    #     || + 재입장 표지 → 같은 문구 끝에 재입장 꼬리(판별 문구와 같은 규칙)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -CorruptText 'not json'
    Write-ContextMarker -Context $fixture.Now
    $failRow = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -CorruptText 'not json'
    $tailRow = Invoke-HandoffTick -ExitCode 1 -Reason $reasonA
    Assert-Case 'F1″ 커스텀 코드 1 + 손상 → 오류 정지(계상·기동 보류 · 기록·마커 보존 + 위치 안내) · 계상/전진/기동 0 · 파일 그대로 || + 재입장 표지 → 꼬리' `
        ('{0} · {1}/{2}/{3} · {4} || {5}' -f $failRow.Flow, $failRow.Completed, $failRow.Steps, $failRow.Launches, $failRow.StateUnchanged, $tailRow.Flow) `
        ('stop|완료 기록 파일 손상 - {0} {1}|True · 0/0/0 · 1 || stop|완료 기록 파일 손상 - {0} {1}{2}|True' -f $C1_HELD_CUSTOM, $CORRUPT_GUIDE, $STOP_TAIL)

    # F2 명세 리뷰 3 P2 · 커스텀 진행 위치를 재시도(200ms × 3) 뒤에도 못 읽음(위치 읽기 4번 모두 $null) + 어비스 커스텀의 미적용 '클리어 이상' 기록 → 주인을 가릴 수 없어
    #    지우지 않고 오류 정지 · 재기동 0 · 파일 그대로(마커 포함) · 위치 읽기 4 || 그런 기록 없음(적용된 기록 · 어비스 커스텀 섹션이 아닌 기록) → 'legacy' → 예전 처리(마커 없음 →
    #    같은 항목 재시작 1). 변이 '$null 을 legacy 로 흘림' 이면 앞 행도 재시작 1
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    Write-ContextMarker -Context $fixture.Now
    $script:contextNullReads = 4
    $row = Invoke-HandoffTick -ExitCode 1
    $noOwnerEntries = @($clearedNow, (New-FixtureEntry -Stage 'cleared' -Owner $runOwner -Nonce $NONCE_D))
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries $noOwnerEntries -Applied @($NONCE_C)
    $script:contextNullReads = 4
    $rowLegacy = Invoke-HandoffTick -ExitCode 1
    Assert-Case "F2 커스텀 위치 없음(재시도 뒤) + 미적용 cleared → 정지(주인 확인 불가 · 지우지 않음) · 빨강 · 기동 0 · 파일 그대로 · 위치 읽기 4 || 그런 기록 없음 → 'legacy' → 같은 항목 재시작 1" `
        ('{0} · {1} · {2} · {3} · {4} || {5} · {6}' -f $row.Flow, $row.Color, $row.Launches, $row.StateUnchanged, $row.ContextReads, $rowLegacy.Flow, $rowLegacy.Launches) `
        ('stop|{0}|True · Firebrick · 0 · 1 · 4 || gui|{1} / launch|powershell.exe / gui|=== 1회차 시작(1/3) === · 1' -f $C1_NO_OWNER, ($C1_RETRY_FORMAT -f 2))
    # F2′ 재시도 안에서 읽힘(앞 3번만 $null) → 정상 라우팅: 이 판의 클리어 기록 → 마무리 복구 (재시도를 빼면 위치 없음 → 주인 확인 불가 정지로 바뀜)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($clearedNow)
    $script:contextNullReads = 3
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'F2′ 위치 읽기 앞 3번 $null → 4번째에 읽힘 → 클리어 기록으로 마무리 복구(복구 문구 → 기동)' $row.Flow `
        ('gui|{0} / launch|powershell.exe / gui|=== 1회차 시작(1/3) ===' -f $C1_RECOVER_NOTICE)
    # F2″ 위치를 재시도 뒤에도 못 읽음 + 미적용 기록이 클리어 전(entered)뿐 → 주인 확인 불가 정지가 아님('클리어 이상' 만 셈 - 명세 리뷰 3 P2) → 'legacy' → 같은 항목
    #     재시작 1 · 정지 0 (단계 2.7~2.9 구현 검증 - 생존 변이 '주인 없는 기록 셈에 entered 도' 를 가름: F2 의 legacy 행에 미적용 entered 가 없었음)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @(New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_B)
    $script:contextNullReads = 4
    $row = Invoke-HandoffTick -ExitCode 1
    Assert-Case "F2″ 커스텀 위치 없음(재시도 뒤) + 미적용 entered 뿐 → 'legacy' → 같은 항목 재시작 1 · 정지 0" `
        ('{0} · 기동 {1} · 정지 {2}' -f $row.Flow, $row.Launches, @($row.Events | Where-Object { $_.StartsWith('stop|') }).Count) `
        ('gui|{0} / launch|powershell.exe / gui|=== 1회차 시작(1/3) === · 기동 1 · 정지 0' -f ($C1_RETRY_FORMAT -f 2))

    # F3 라우팅 처리 중 예외(재입장 계상 뒤 완료 줄에서 주입) → 라우팅 catch 가 오류 정지 하나 · 빨강 · 기동 0 · 타이머 오류 줄 0 · 예외 0 (명세 5절 A4)
    Initialize-HandoffRow -Entries @($reentered)
    $row = Invoke-HandoffTick -ExitCode 1 -GuiLogThrowMatch '회차 완료'
    Assert-Case 'F3 라우팅 처리 중 예외 → 정지 1번(처리 중 예외 + 메시지) · 빨강 · 기동 0 · 타이머 오류 줄 0 · 예외 0' `
        ('{0} · {1} · {2} · {3} · [{4}]' -f $row.Flow, $row.Color, $row.Launches, @($row.Events | Where-Object { $_.StartsWith('gui|[오류] 내부 타이머') }).Count, $row.Thrown) `
        ('gui|=== 1회차 완료 === / stop|{0}|True · Firebrick · 0 · 0 · []' -f ($C1_EXCEPTION_FORMAT -f $INJECTED_GUILOG_EXCEPTION))
}

# ===== NC 행동 - 라우팅 안 정지 경로의 이번 기동 nonce 닫기 (단계 2.7·2.8 구현 리뷰 P2 · 설계 v10 6.1 dev:883 · 명세 2.8 ③) =====
# 정지 넷(비커스텀 재입장 오류 상한 · 재개 1회 뒤 또 오류 · 재개 기능 꺼짐 · 안전 중지) × { 이번 기동 nonce 가 라우팅한 항목과 다름 → done(저장 1) · 같음 → 열어 둠(저장 0)
# · 넘긴 nonce 없음 → journal 저장 0 }. 픽스처의 '다른 nonce' = 앞 판의 재입장 항목을 다음 판(next) 기동이 받은 모양(필수 기록이 적용·launched 로 둔 채 이 워커가 기동됨)
function Test-CaseCode1StopNonce {
    $runOwner = [pscustomobject]@{ runId = 'run-H' }
    $fixture = Get-CustomFixture
    $launchedB = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_B
    $reenteredA = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -Nonce $NONCE_A
    $resumedA = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    $resumedOnceA = New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    $resumedOnceA.resumeAttempts = 1
    $clickedA = New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -Nonce $NONCE_A
    $streakStop = 'stop|{0}{1}|True' -f $C1_STREAK_STOP, $STOP_TAIL

    # NC1 비커스텀 재입장 오류 상한(3회째 - H48 정지) · 다른 nonce(next NB) → NB done · 라우팅한 NA 그대로(reentered/pending/미적용) · 읽기 1·저장 1 · 정지 문구 그대로 ||
    #     같은 nonce(재개 워커가 쓴 reentered NA - H40 모양. 비커스텀 재개 기동은 켜진 빌드의 코드 1 라우팅만 띄워 이 빌드에서는 진리표) → NA launched 유지 · 저장 0 ·
    #     파일 그대로 || 넘긴 nonce 없음 → 저장 0 · 파일 그대로.
    #     정지 뒤 후보 고르기(실제 Resolve): 같은 실행 id → next/NA 둘 다(같은 nonce 를 닫았다면 none - 열어 둔 효과) · 새 실행 id(다음 수동 시작 - 시작 버튼마다 새 id) →
    #     none(비커스텀은 다음 시작이 이어받지 않음 - C8 과 같은 수용 창, 닫든 열든 같음)
    Initialize-HandoffRow -Entries @($launchedB, $reenteredA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B -AbyssErrorStreak 2
    $rowOther = Invoke-HandoffTick -ExitCode 1
    $otherSame = Invoke-RealResolveHandoffEnv -Context @{ runId = 'run-H' }
    $otherNew = Invoke-RealResolveHandoffEnv -Context @{ runId = 'run-new' }
    Initialize-HandoffRow -Entries @($resumedA) -LaunchKind 'resume' -LaunchNonce $NONCE_A -AbyssErrorStreak 2
    $rowSame = Invoke-HandoffTick -ExitCode 1
    $sameSame = Invoke-RealResolveHandoffEnv -Context @{ runId = 'run-H' }
    $sameNew = Invoke-RealResolveHandoffEnv -Context @{ runId = 'run-new' }
    Initialize-HandoffRow -Entries @($reenteredA) -AbyssErrorStreak 2
    $rowNone = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'NC1 재입장 오류 상한 정지 · 다른 nonce → NB done · NA 그대로 · 저장 1 → 후보 next/NA · 새 실행 id none || 같은 nonce → NA launched · 저장 0 · 파일 그대로 → 후보 next/NA · 새 실행 id none || 없음 → 저장 0 · 파일 그대로' `
        ('{0} · {1} · {2} · {3}/{4} · {5}/{6} · {7} || {8} · {9} · {10}/{11} · {12} · {13}/{14} · {15} || {16} · {17}/{18} · {19}' -f $rowOther.Flow, (Get-EntryText $rowOther.Journal $NONCE_B),
            (Get-EntryText $rowOther.Journal $NONCE_A), $rowOther.Reads, $rowOther.Updates, $otherSame.Kind, (Get-NonceLabel ([string]$otherSame.Nonce)), $otherNew.Kind,
            $rowSame.Flow, (Get-EntryText $rowSame.Journal $NONCE_A), $rowSame.Reads, $rowSame.Updates, $rowSame.StateUnchanged, $sameSame.Kind, (Get-NonceLabel ([string]$sameSame.Nonce)), $sameNew.Kind,
            $rowNone.Flow, $rowNone.Reads, $rowNone.Updates, $rowNone.StateUnchanged) `
        ('{0} · reentered/done/1 · reentered/pending/0 · 1/1 · next/NA · none || {0} · reentered/launched/0 · 1/0 · 1 · next/NA · none || {0} · 1/0 · 1' -f $streakStop)

    # NC2 재개 1회 뒤 또 오류(재개 횟수 1 - dev:889 정지) · 같은 nonce(재개 기동 NA - RT2 모양) → NA 그대로 · 저장 0 · 파일 그대로 || 다른 nonce(next NB) → NB done · NA 그대로
    #     (retry-clicked/launched · 재개 횟수 1) · 저장 1 || 없음 → 저장 0 · 파일 그대로
    Initialize-HandoffRow -Entries @($resumedOnceA) -LaunchKind 'resume' -LaunchNonce $NONCE_A
    $rowSame = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Entries @($launchedB, $resumedOnceA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowOther = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Entries @($resumedOnceA)
    $rowNone = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'NC2 재개 1회 뒤 정지 · 같은 nonce → NA 그대로 · 저장 0 · 파일 그대로 || 다른 nonce → NB done · NA 그대로 · 재개 횟수 1 · 저장 1 || 없음 → 저장 0 · 파일 그대로' `
        ('{0} · {1} · {2}/{3} · {4} || {5} · {6} · {7} · {8} · {9}/{10} || {11} · {12}/{13} · {14}' -f $rowSame.Flow, (Get-EntryText $rowSame.Journal $NONCE_A), $rowSame.Reads, $rowSame.Updates, $rowSame.StateUnchanged,
            $rowOther.Flow, (Get-EntryText $rowOther.Journal $NONCE_B), (Get-EntryText $rowOther.Journal $NONCE_A), (Get-EntryResumeAttempts $rowOther.Journal $NONCE_A), $rowOther.Reads, $rowOther.Updates,
            $rowNone.Flow, $rowNone.Reads, $rowNone.Updates, $rowNone.StateUnchanged) `
        ('stop|{0}|True · retry-clicked/launched/0 · 1/0 · 1 || stop|{0}|True · reentered/done/1 · retry-clicked/launched/0 · 1 · 1/1 || stop|{0}|True · 1/0 · 1' -f $C1_RESUMED_AGAIN)

    # NC3 재개 기능 꺼짐(이 빌드의 실제 경로 - GUI 원문 값) · 다른 nonce(next NB) → NB done · NA 그대로(retry-clicked/pending) · 저장 1 || 같은 nonce(NA - 재개 기동은 재개 횟수를
    #     먼저 올려 실제로는 NC2 로 가는 조합이라 진리표) → 저장 0 · 파일 그대로 ||
    #     없음 → 저장 0 · 파일 그대로 || 커스텀(진행 i = 2번 칸 · 앞 판의 재입장 NB(nextOwner = i) 를 받아 기동 · 이 판의 재입장 요청 NA · 마커 있음) → NB done · NA 그대로 ·
    #     전진·마커 정리 0 · 마커 그대로 (다음 수동 시작 S3 의 이어받기는 test_abyss_pending_advance C11)
    Initialize-HandoffRow -Entries @($launchedB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowOther = Invoke-HandoffTick -ExitCode 1
    $clickedLaunchedA = New-FixtureEntry -Stage 'retry-clicked' -Owner $runOwner -LaunchState 'launched' -Nonce $NONCE_A
    Initialize-HandoffRow -Entries @($clickedLaunchedA) -LaunchKind 'resume' -LaunchNonce $NONCE_A
    $rowSame = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Entries @($clickedA)
    $rowNone = Invoke-HandoffTick -ExitCode 1
    $customB = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNow -NextOwner $fixture.FiveNext -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_B
    $customA = New-FixtureEntry -Stage 'retry-attempt' -Owner $fixture.FiveNext -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Next -Entries @($customB, $customA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    Write-ContextMarker -Context $fixture.Next
    $markerBefore = [IO.File]::ReadAllText($script:customMarkerFile)
    $rowCustom = Invoke-HandoffTick -ExitCode 1
    $markerSame = [int]([IO.File]::ReadAllText($script:customMarkerFile) -ceq $markerBefore)
    Assert-Case ('NC3 재개 기능 꺼짐(GUI 원문 값 {0}) · 다른 nonce → NB done · NA 그대로 · 저장 1 || 같은 nonce → 저장 0 · 파일 그대로 || 없음 → 저장 0 · 파일 그대로 || 커스텀 다른 nonce → NB done · NA 그대로 · 전진·마커 정리 0 · 마커 그대로' -f $GUI_RETRY_FLAG) `
        ('{0} · {1} · {2} · {3}/{4} || {5} · {6}/{7} · {8} || {9} · {10}/{11} · {12} || {13} · {14} · {15} · {16}/{17} · {18}' -f $rowOther.Flow, (Get-EntryText $rowOther.Journal $NONCE_B),
            (Get-EntryText $rowOther.Journal $NONCE_A), $rowOther.Reads, $rowOther.Updates, $rowSame.Flow, $rowSame.Reads, $rowSame.Updates, $rowSame.StateUnchanged,
            $rowNone.Flow, $rowNone.Reads, $rowNone.Updates, $rowNone.StateUnchanged, $rowCustom.Flow, (Get-EntryText $rowCustom.Journal $NONCE_B), (Get-EntryText $rowCustom.Journal $NONCE_A),
            $rowCustom.Steps, $rowCustom.MarkerClears, $markerSame) `
        ('stop|{0}|True · reentered/done/1 · retry-clicked/pending/0 · 1/1 || stop|{0}|True · 1/0 · 1 || stop|{0}|True · 1/0 · 1 || stop|{0}|True · reentered/done/1 · retry-attempt/pending/0 · 0/0 · 1' -f $C1_RETRY_OFF)

    # NC4 켜진 빌드 · 안전 중지(dev:888) · 다른 nonce(next NB) → [안내] → NB done → '안전 중지' 정상 정지 · NA 그대로 · 재개 0 · 저장 1 || 같은 nonce(NC3 과 같은 진리표 조합) → 저장 0 ·
    #     파일 그대로 ||
    #     없음 → 저장 0 · 파일 그대로
    try {
        Initialize-HandoffRow -Entries @($launchedB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B -StopRequested $true
        $script:abyssPartyRetryEnabled = $true
        $rowOther = Invoke-HandoffTick -ExitCode 1
        Initialize-HandoffRow -Entries @($clickedLaunchedA) -LaunchKind 'resume' -LaunchNonce $NONCE_A -StopRequested $true
        $script:abyssPartyRetryEnabled = $true
        $rowSame = Invoke-HandoffTick -ExitCode 1
        Initialize-HandoffRow -Entries @($clickedA) -StopRequested $true
        $script:abyssPartyRetryEnabled = $true
        $rowNone = Invoke-HandoffTick -ExitCode 1
    } finally {
        $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG
    }
    Assert-Case 'NC4 켜진 빌드 · 안전 중지 · 다른 nonce → [안내] → 안전 중지 · NB done · NA 그대로 · 기동 0 · 저장 1 || 같은 nonce → 저장 0 · 파일 그대로 || 없음 → 저장 0 · 파일 그대로' `
        ('{0} · {1} · {2} · {3} · {4}/{5} || {6} · {7}/{8} · {9} || {10} · {11}/{12} · {13}' -f $rowOther.Flow, (Get-EntryText $rowOther.Journal $NONCE_B), (Get-EntryText $rowOther.Journal $NONCE_A),
            $rowOther.Launches, $rowOther.Reads, $rowOther.Updates, $rowSame.Flow, $rowSame.Reads, $rowSame.Updates, $rowSame.StateUnchanged, $rowNone.Flow, $rowNone.Reads, $rowNone.Updates, $rowNone.StateUnchanged) `
        ('gui|{0} / stop|안전 중지|False · reentered/done/1 · retry-clicked/pending/0 · 0 · 1/1 || gui|{0} / stop|안전 중지|False · 1/0 · 1 || gui|{0} / stop|안전 중지|False · 1/0 · 1' -f $C1_SAFE_NOTICE)

    # NC5 이번 기동 항목이 이미 done(워커가 닫으며 reason 을 남김) → 저장 호출 1 · 바꿀 것 없음(본 파일 바이트 그대로 - 직전본 생성 0) · reason 보존 (끝 처리 ② 와 같은 mutation 모양 - G4)
    $doneB = New-FixtureEntry -Stage 'reentered' -Owner $runOwner -NextOwner $runOwner -LaunchState 'done' -Nonce $NONCE_B
    $doneB.reason = 'abandoned-pre-entry-start'
    Initialize-HandoffRow -Entries @($doneB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $row = Invoke-HandoffTick -ExitCode 1
    $reasonKept = @(@($row.Journal.entries) | Where-Object { [string]$_.nonce -eq $NONCE_B } | ForEach-Object { [string]$_.reason }) -join ','
    Assert-Case 'NC5 이번 기동 항목이 이미 done → 저장 1 · 파일 그대로 · NB done · reason 보존 · 정지 문구 그대로' `
        ('{0} · {1} · {2} · {3} · {4}' -f $row.Flow, $row.Updates, $row.StateUnchanged, (Get-EntryText $row.Journal $NONCE_B), $reasonKept) `
        ('stop|{0}|True · 1 · 1 · reentered/done/1 · abandoned-pre-entry-start' -f $C1_RETRY_OFF)

    # NC6 닫기 실패 → [경고] 1줄 뒤 원래 정지 1번(정지 사유 그대로 · 두 번 정지 없음) · 빨강 · NB launched 그대로 · 예외 0: 재개 기능 꺼짐 + 저장 직전 다른 주체가 잠금(실제 '사용 중') ||
    #     재개 기능 꺼짐 + 저장 예외 || 재입장 오류 상한 + 실제 잠금(재입장 꼬리도 그대로)
    Initialize-HandoffRow -Entries @($launchedB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowLocked = Invoke-HandoffTick -ExitCode 1 -PreUpdateAt 1 -PreUpdateHook { Lock-JournalLock }
    Initialize-HandoffRow -Entries @($launchedB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowThrow = Invoke-HandoffTick -ExitCode 1 -UpdateThrowAt 1
    Initialize-HandoffRow -Entries @($launchedB, $reenteredA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B -AbyssErrorStreak 2
    $rowStreak = Invoke-HandoffTick -ExitCode 1 -PreUpdateAt 1 -PreUpdateHook { Lock-JournalLock }
    $failTexts = foreach ($failRow in @($rowLocked, $rowThrow, $rowStreak)) {
        '{0} · {1} · {2} · [{3}]' -f $failRow.Flow, $failRow.Color, (Get-EntryText $failRow.Journal $NONCE_B), $failRow.Thrown
    }
    Assert-Case "NC6 닫기 실패('사용 중' || 저장 예외 || 재입장 오류 상한 + '사용 중') → [경고] 1줄 → 원래 정지 1번 · 빨강 · NB launched 그대로 · 예외 0" ($failTexts -join ' || ') `
        (('gui|{0} / stop|{1}|True · Firebrick · reentered/launched/1 · [] || gui|{2} / stop|{1}|True · Firebrick · reentered/launched/1 · [] || gui|{0} / {3} · Firebrick · reentered/launched/1 · []') -f
            ($C1_CLOSE_FAIL_FORMAT -f '파일 사용 중'), $C1_RETRY_OFF, ($C1_CLOSE_FAIL_FORMAT -f ('예외: ' + $INJECTED_UPDATE_EXCEPTION)), $streakStop)

    # NC7 라우팅 반환은 정지 경로에서 닫기(저장 1)·닫기 실패([경고])를 거쳐도 'handled' 하나(닫기 함수의 출력이 반환에 섞이지 않음 - 타이머는 반환을 -eq 로 봄)
    Initialize-HandoffRow -Entries @($launchedB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $closedOut = @(Invoke-Code1JournalRouting -ExitCode 1)
    $closedState = Get-EntryText (Read-FixtureJournal -Path $script:abyssJournalPath) $NONCE_B
    Initialize-HandoffRow -Entries @($launchedB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $script:updateThrowAt = 1
    try { $failedOut = @(Invoke-Code1JournalRouting -ExitCode 1) } finally { $script:updateThrowAt = 0 }
    Assert-Case "NC7 라우팅 반환: 닫기 성공 → 'handled' 하나 · NB done || 닫기 실패 → 'handled' 하나" ('{0}:{1} · {2} || {3}:{4}' -f $closedOut.Count, ($closedOut -join ','), $closedState, $failedOut.Count, ($failedOut -join ',')) `
        '1:handled · reentered/done/1 || 1:handled'

    # NC8 닫지 않는 정지(명세 2.8 ③ 예외) - 넘긴 nonce(next NB)가 있어도 저장 0 · NB 그대로 · 닫기 [경고] 0: 읽기 '사용 중'(기록 불가 - 읽기 실패와 같은 잠금) || 읽기 손상(같음 - 파일
    #     그대로) || 커스텀 주인 확인 불가(진행 위치를 재시도 뒤에도 못 읽음 + 미적용 클리어 기록 - 어느 항목이 이어받을 몫인지 몰라 파일 무변경) || 켜진 빌드 · 재개 횟수 기록 실패('사용 중'
    #     태그 - 그 저장 1번뿐) || 라우팅 처리 중 예외(완료 줄에서 주입 - F3 모양)
    Initialize-HandoffRow -Entries @($launchedB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowLocked = Invoke-HandoffTick -ExitCode 1 -HoldLock
    Initialize-HandoffRow -CorruptText 'not json' -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowCorrupt = Invoke-HandoffTick -ExitCode 1
    $customClearedA = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_A
    $customLaunchedB = New-FixtureEntry -Stage 'reentered' -Owner $fixture.FiveNext -NextOwner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_B
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries @($customLaunchedB, $customClearedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $script:contextNullReads = 4
    $rowOwnerless = Invoke-HandoffTick -ExitCode 1
    Initialize-HandoffRow -Entries @($launchedB, $clickedA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $script:abyssPartyRetryEnabled = $true
    try { $rowRecord = Invoke-HandoffTick -ExitCode 1 -UpdateTagAt @{ At = 1; Tag = 'locked' } } finally { $script:abyssPartyRetryEnabled = $GUI_RETRY_FLAG }
    Initialize-HandoffRow -Entries @($launchedB, $reenteredA) -Applied @($NONCE_B) -LaunchKind 'next' -LaunchNonce $NONCE_B
    $rowThrow = Invoke-HandoffTick -ExitCode 1 -GuiLogThrowMatch '회차 완료'
    $closeWarnings = @(@($rowLocked, $rowCorrupt, $rowOwnerless, $rowRecord, $rowThrow) | ForEach-Object { @($_.Events | Where-Object { $_.StartsWith('gui|[경고] 이번 기동의 완료 표시') }).Count }) -join ','
    Assert-Case "NC8 닫지 않는 정지(넘긴 nonce 있음): 읽기 '사용 중' || 읽기 손상 || 주인 확인 불가 || 재개 횟수 기록 실패 || 처리 중 예외 → 정지 1 · 저장 0(재개 기록만 1) · NB 그대로 · 닫기 [경고] 0" `
        ('{0} · {1}/{2} · {3} || {4} · {5} · {6} || {7} · {8} · {9} || {10} · {11} · {12} || {13} · {14} · {15} || [경고] {16}' -f
            $rowLocked.Flow, $rowLocked.Updates, $rowLocked.StateUnchanged, (Get-EntryText $rowLocked.Journal $NONCE_B), $rowCorrupt.Flow, $rowCorrupt.Updates, $rowCorrupt.StateUnchanged,
            $rowOwnerless.Flow, $rowOwnerless.Updates, $rowOwnerless.StateUnchanged, $rowRecord.Flow, $rowRecord.Updates, (Get-EntryText $rowRecord.Journal $NONCE_B),
            @(Get-StopEvents $rowThrow).Count, $rowThrow.Updates, (Get-EntryText $rowThrow.Journal $NONCE_B), $closeWarnings) `
        (('stop|완료 기록 파일이 사용 중 - {0} {1}|True · 0/1 · reentered/launched/1 || stop|완료 기록 파일 손상 - {0} {2}|True · 0 · 1 || stop|{3}|True · 0 · 1 || ' +
            'stop|{4}|True · 1 · reentered/launched/1 || 1 · 0 · reentered/launched/1 || [경고] 0,0,0,0,0') -f $C1_HELD_PLAIN, $LOCKED_GUIDE, $CORRUPT_GUIDE, $C1_NO_OWNER,
            ($C1_RESUME_LOCKED_FORMAT -f '기록 보존'))
}

# ===== NC 행동 - 예전 처리(recover/retry) 안전 중지의 이번 기동 nonce (단계 2.7·2.8 구현 리뷰 확인 라운드 · 설계 v10 6.1 dev:883·891 · 명세 2.8 ③) =====
# 라우팅이 'legacy'·'legacy-cleared' 를 돌려준 커스텀 코드 1 의 예전 처리에서 안전 중지로 멈추는 두 자리. 넘긴 nonce = 같은 항목의 열린 자기 항목(own NA - 재기동이었다면
# 다시 넘길 항목):
#  - recover 갈래(NC9 - 다음 시작의 복구 근거 = 완료 마커·미적용 클리어 기록) = 닫음 × { 넘긴 nonce 있음 → done(저장 1) · 없음 → 닫기의 journal 접근 0(저장 0 · 파일
#    그대로) · 닫기 실패('사용 중' · 예외) → [경고] 1줄 뒤 '안전 중지' 1번 }. 예전 처리는 이 owner 에 재입장·재입장 요청 항목이 없을 때만 오므로 열어 둘 라우팅 항목이
#    없음(-RoutedNonce 빈 값)
#  - retry 갈래(NC10 - 완료 마커도 미적용 클리어 기록도 없는 판) = 열어 둠(구현 리뷰 확인 - 열린 nonce 가 다음 시작의 유일한 이어받기 근거, 닫으면 후보 고르기에서
#    빠져 같은 항목을 처음부터 다시 함) × { 넘긴 nonce 있음 → 저장 0 · launched 그대로 · 정지 뒤 후보 고르기(실제 Resolve)가 같은 항목 · 없음 → 저장 0 }. 닫기가 없어
#    닫기 실패 칸은 해당 없음
# 다음 수동 시작까지 잇는 행은 test_abyss_pending_advance C12·C13. 범위 밖(던전 커스텀)은 기동이 nonce 를 정하지 않아 읽기·저장 0(NC11)
function Test-CaseCode1LegacySafeStopNonce {
    $fixture = Get-CustomFixture
    $clearedNow = New-FixtureEntry -Stage 'cleared' -Owner $fixture.FiveNow -Generation $H_GENERATION -Section $ABYSS_SECTION -Nonce $NONCE_C
    $ownLaunched = New-FixtureEntry -Stage 'entered' -Owner $fixture.FiveNow -Generation $H_GENERATION -LaunchState 'launched' -Section $ABYSS_SECTION -Nonce $NONCE_A
    $closeLocked = 'gui|' + ($C1_CLOSE_FAIL_FORMAT -f '파일 사용 중')
    $closeThrown = 'gui|' + ($C1_CLOSE_FAIL_FORMAT -f ('예외: ' + $INJECTED_UPDATE_EXCEPTION))
    # NC9 recover 자리 = 이 판(i)의 미적용 클리어 기록 → 'legacy-cleared' → 마무리 복구 갈래(복구 대기 참) - 정지라 NA done
    $recoverEntries = @($clearedNow, $ownLaunched)
    $texts = @()
    # 넘긴 nonce 있음 → NA done · 클리어 기록 미소비(코드 1 - 명세 5절 A6ⓐ) · 읽기 1(라우팅)·저장 1(닫기) · 안전 중지 1번 · 기동 0 · 예외 0
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries $recoverEntries -LaunchKind 'own' -LaunchNonce $NONCE_A -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 1
    $texts += ('있음: {0} · {1} · {2}/{3} · {4} · {5} · 복구 대기 {6} · 오류 연속 {7} · {8} · [{9}]' -f $row.Flow, $row.Launches, $row.Reads, $row.Updates,
        (Get-EntryText $row.Journal $NONCE_A), (Get-EntryText $row.Journal $NONCE_C), $row.RecoveryPending, $row.CustomErrorStreak, $row.Color, $row.Thrown)
    # 넘긴 nonce 없음 → 닫기가 journal 을 열지 않음(저장 0) · 파일 그대로 · 안전 중지 1번
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries $recoverEntries -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 1
    $texts += ('없음: {0} · {1}/{2} · {3}' -f $row.Flow, $row.Reads, $row.Updates, $row.StateUnchanged)
    # 닫기 실패 - 저장 직전 다른 기록 주체가 잠금(실제 '사용 중') || 저장 예외 → [경고] 1줄 → '안전 중지' 1번(정지 두 번 없음 · 오류 정지로 바뀌지 않음) · NA launched 그대로 · 예외 0
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries $recoverEntries -LaunchKind 'own' -LaunchNonce $NONCE_A -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 1 -PreUpdateAt 1 -PreUpdateHook { Lock-JournalLock }
    $texts += ('사용 중: {0} · {1} · [{2}]' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A), $row.Thrown)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries $recoverEntries -LaunchKind 'own' -LaunchNonce $NONCE_A -StopRequested $true
    $row = Invoke-HandoffTick -ExitCode 1 -UpdateThrowAt 1
    $texts += ('예외: {0} · {1} · [{2}]' -f $row.Flow, (Get-EntryText $row.Journal $NONCE_A), $row.Thrown)
    Assert-Case 'NC9 예전 처리 recover 갈래의 안전 중지 · 넘긴 nonce 있음 → NA done · 클리어 기록 미소비 · 저장 1 || 없음 → 저장 0 · 파일 그대로 || 닫기 실패(사용 중 || 예외) → [경고] 1줄 → 안전 중지 1번 · NA launched' `
        ($texts -join ' || ') `
        (('있음: stop|안전 중지|False · 0 · 1/1 · entered/done/0 · cleared/pending/0 · 복구 대기 True · 오류 연속 2 · 색 그대로 · [] || 없음: stop|안전 중지|False · 1/0 · 1 || ' +
            '사용 중: {0} / stop|안전 중지|False · entered/launched/0 · [] || 예외: {1} / stop|안전 중지|False · entered/launched/0 · []') -f $closeLocked, $closeThrown)
    # NC10 retry 자리 = 기록·마커 없음 → 'legacy' → 같은 항목 재시작 갈래(복구 대기 거짓)의 안전 중지 - 열어 둠(구현 리뷰 확인):
    #      넘긴 nonce 있음 → 닫기 호출 0 = 읽기 1(라우팅)·저장 0 · NA launched 그대로 · 파일 그대로 · 안전 중지 1번 · 기동 0 · 예외 0 → 정지 뒤 후보 고르기(실제 Resolve -
    #      다음 시작·재시작이 고르는 것)가 같은 항목 own/NA(닫았다면 none - 열어 둔 효과) || 없음 → 저장 0 · 파일 그대로. 닫기 실패 칸은 해당 없음(저장 0 이 그 근거)
    $retryEntries = @($ownLaunched)
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries $retryEntries -LaunchKind 'own' -LaunchNonce $NONCE_A -StopRequested $true
    $rowOpen = Invoke-HandoffTick -ExitCode 1
    $openPick = Invoke-RealResolveHandoffEnv -Context $fixture.OwnerNow
    Initialize-HandoffRow -Custom $true -DiskContext $fixture.Now -Entries $retryEntries -StopRequested $true
    $rowNone = Invoke-HandoffTick -ExitCode 1
    Assert-Case 'NC10 예전 처리 retry 갈래의 안전 중지(열어 둠) · 넘긴 nonce 있음 → 저장 0 · NA launched 그대로 · 클리어 기록 없음 · 파일 그대로 → 정지 뒤 후보 own/NA || 없음 → 저장 0 · 파일 그대로' `
        ('있음: {0} · {1} · {2}/{3} · {4} · {5} · 복구 대기 {6} · 오류 연속 {7} · {8} · [{9}] · 파일 그대로 {10} → {11}/{12}/{13} || 없음: {14} · {15}/{16} · {17}' -f
            $rowOpen.Flow, $rowOpen.Launches, $rowOpen.Reads, $rowOpen.Updates, (Get-EntryText $rowOpen.Journal $NONCE_A), (Get-EntryText $rowOpen.Journal $NONCE_C),
            $rowOpen.RecoveryPending, $rowOpen.CustomErrorStreak, $rowOpen.Color, $rowOpen.Thrown, $rowOpen.StateUnchanged, $openPick.Status, $openPick.Kind,
            (Get-NonceLabel ([string]$openPick.Nonce)), $rowNone.Flow, $rowNone.Reads, $rowNone.Updates, $rowNone.StateUnchanged) `
        '있음: stop|안전 중지|False · 0 · 1/0 · entered/launched/0 · (없음) · 복구 대기 False · 오류 연속 2 · 색 그대로 · [] · 파일 그대로 1 → ok/own/NA || 없음: stop|안전 중지|False · 1/0 · 1'
    # NC11 범위 밖(던전 커스텀 - 어비스 완료 기록 실행이 아님) 안전 중지 → 기동이 nonce 를 정하지 않음 → 라우팅·닫기 모두 journal 접근 0(읽기 0·저장 0) · 정지 1번:
    #      retry 갈래(마커 없음) || recover 갈래(마무리 복구 대기 중)
    $rangeTexts = foreach ($rangeCase in @(@{ N = 'retry'; Recovery = $false }, @{ N = 'recover'; Recovery = $true })) {
        Initialize-HandoffRow -Custom $true -Content 'dungeon' -DiskContext $fixture.Now -StopRequested $true -RecoveryPending $rangeCase.Recovery
        $script:customConfigSection = 'customRepeat'
        $rangeRow = Invoke-HandoffTick -ExitCode 1
        '{0}: {1} · {2}/{3} · {4}' -f $rangeCase.N, $rangeRow.Flow, $rangeRow.Reads, $rangeRow.Updates, $rangeRow.StateUnchanged
    }
    Assert-Case 'NC11 범위 밖(던전 커스텀) 안전 중지 → 읽기 0·저장 0 · 파일 그대로 · 정지 1번 (retry 갈래 || recover 갈래)' ($rangeTexts -join ' || ') `
        'retry: stop|안전 중지|False · 0/0 · 1 || recover: stop|안전 중지|False · 0/0 · 1'
}

# ===== S 정적 (단계 2.8 - 주석 뺀 GUI 사본) =====
function Test-CaseCode1Static {
    # S20 서명
    Assert-Case 'S20 코드 1 라우팅 서명(명세 2.8 ② - 종료 코드 하나)' (Get-ParamSignature $guiAst 'Invoke-Code1JournalRouting') 'Int32 $ExitCode'
    # S21 코드 1 을 받는 갈래(타이머 if 사슬의 마지막 else - 주석 뺌): 끝 처리 = 정지 두 곳(같은 항목 3회째 · 그 밖 오류) 바로 앞 1개씩 · 갈래 안 끝 처리 2(재기동 두 경로에는
    #     없음 - 같은 항목을 다시 넘김) · 라우팅 호출 1 (명세 2.8 ③) · 예전 처리 recover 의 안전 중지 = 이번 기동 nonce 닫기(-RoutedNonce 빈 값) 바로 뒤 '안전 중지' 정지,
    #     retry 의 안전 중지 = 닫기 없이 정지(열어 둠 - 구현 리뷰 확인) - 갈래 안 닫기 호출 1 · '안전 중지' 정지 2 중 닫기 바로 뒤 1 · retry 자리(PREV 비움 → 안전 중지 if →
    #     정지 → else - 갈래 안에서 PREV 를 빈 값으로 두는 곳은 retry 하나라 자리가 갈림) 1. 기대값 이력: '2 · 1 · 1 · 1'(단계 2.8) → '2 · 1 · 1 · 1 · 2 · 2/2'(단계 2.7·2.8
    #     구현 리뷰 확인 라운드 - 두 곳 닫음) → 지금(구현 리뷰 확인 - retry 를 열어 둠)
    $exitChains = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -ceq '($exitCode -eq 0) -or ($exitCode -eq 11)') }, $true))
    $code1Clause = ''
    if (($exitChains.Count -eq 1) -and ($null -ne $exitChains[0].ElseClause)) { $code1Clause = Remove-SourceComments -Text $exitChains[0].ElseClause.Extent.Text }
    $endCall = 'if (-not (Complete-AbyssExitJournal -ExitCode $exitCode)) { return }'
    $thirdPattern = (@($endCall, "Stop-AllRun -IsError '오류 종료(코드 1) - 같은 항목 3회 연속 실패 (로그 확인)'") | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    $plainPattern = (@($endCall, 'Stop-AllRun -IsError "오류 종료(코드 $exitCode) - 로그 확인"') | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    $safeStopPattern = (@('if ($script:stopRequested) {', "Close-AbyssLaunchNonceOnStop -RoutedNonce ''", "Stop-AllRun '안전 중지'", '} else {') | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    $openStopPattern = (@("`$script:customPrevItem = ''", 'if ($script:stopRequested) {', "Stop-AllRun '안전 중지'", '} else {') | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    Assert-Case 'S21 코드 1 갈래: 끝 처리 2 · 3회째 정지 바로 앞 1 · 그 밖 오류 정지 바로 앞 1 · 라우팅 호출 1 · 닫기 호출 1 · 안전 중지 정지 = 닫기 바로 뒤 1/전체 2 · retry 자리 = 닫기 없이 정지 1' `
        ('{0} · {1} · {2} · {3} · {4} · {5}/{6} · {7}' -f [regex]::Matches($code1Clause, [regex]::Escape('Complete-AbyssExitJournal')).Count, [regex]::Matches($code1Clause, $thirdPattern).Count,
            [regex]::Matches($code1Clause, $plainPattern).Count, [regex]::Matches($code1Clause, [regex]::Escape('Invoke-Code1JournalRouting -ExitCode $exitCode')).Count,
            [regex]::Matches($code1Clause, [regex]::Escape('Close-AbyssLaunchNonceOnStop')).Count, [regex]::Matches($code1Clause, $safeStopPattern).Count,
            [regex]::Matches($code1Clause, [regex]::Escape("Stop-AllRun '안전 중지'")).Count, [regex]::Matches($code1Clause, $openStopPattern).Count) '2 · 1 · 1 · 1 · 1 · 1/2 · 1'
    # S22 A10 항 자리(명세 2.8 ② · 5절 A10): $markerExists 대입 1곳 = 예전 조건식 원문 뒤에 라우팅 결과 항 하나(test_custom_marker_validity 의 예전 조각 단언 보존)
    $markerAssigns = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$markerExists') }, $true))
    $markerText = $(if ($markerAssigns.Count -eq 1) { ((Remove-SourceComments -Text $markerAssigns[0].Extent.Text) -replace '\s+', ' ').Trim() } else { '' })
    Assert-Case 'S22 $markerExists 대입 1곳 · 예전 원문 뒤 A10 항' ('{0} · {1}' -f $markerAssigns.Count, $markerText) `
        ("1 · `$markerExists = (`$script:customRecoveryPending -or ((-not `$script:customMarkerIgnore) -and (Test-CustomMarkerValidForCurrent)) -or (`$code1Route -eq 'legacy-cleared'))")
    # S23 라우팅 함수 구조(설계 R1 3.4 와 같은 예외 계약): 본문 = 계획 비움 → try(catch 1 · catch 끝 = return 'handled') → 기동 if → return 'handled' · 기동(실행부·Start-NextCycle)은
    #     try 안 0 · 기동 if 안 2 - 기동 뒤 예외가 방금 띄운 워커를 정지로 죽이지 않게
    $routeAst = Get-GuiFunctionAstByName 'Invoke-Code1JournalRouting'
    $routeStatements = @($routeAst.Body.EndBlock.Statements)
    $launchNames = @('Invoke-InsideHandoffExit', 'Start-NextCycle')
    $routeTry = @($routeStatements | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] })
    $launchInTry = $(if ($routeTry.Count -eq 1) { @($routeTry[0].Body.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($launchNames -contains $node.GetCommandName()) }, $true)).Count } else { -1 })
    $catchLast = $(if (($routeTry.Count -eq 1) -and ($routeTry[0].CatchClauses.Count -ge 1)) { @($routeTry[0].CatchClauses[0].Body.Statements)[-1].Extent.Text } else { '' })
    $launchInIf = $(if ($routeStatements.Count -ge 2) { @($routeStatements[-2].FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($launchNames -contains $node.GetCommandName()) }, $true)).Count } else { -1 })
    Assert-Case "S23 라우팅 본문 = 대입 · try · if · return · catch 끝 = return 'handled' · try 안 기동 0 · 기동 if 안 기동 2 · 마지막 = return 'handled'" `
        ('{0} · {1} · {2} · {3} · {4}' -f (($routeStatements | ForEach-Object { $_.GetType().Name }) -join ','), $catchLast, $launchInTry, $launchInIf, $routeStatements[-1].Extent.Text) `
        ("AssignmentStatementAst,TryStatementAst,IfStatementAst,ReturnStatementAst · return 'handled' · 0 · 2 · return 'handled'")
    # S24 재입장 실행부의 대기열 단계는 부른 자리로(명세 2.8 ④ · 5절 B7) - 코드 1(라우팅) = code1-routed · 그 밖(코드 0·11) = inside-handoff, 대기열 기록 호출은 그 값 하나
    $insideCode = Remove-SourceComments -Text $guiFunctionTexts['Invoke-InsideHandoffExit']
    Assert-Case 'S24 실행부 대기열 단계 선택 1 · 대기열 기록 -Stage $queueStage 1 · 리터럴 단계로 부르는 호출 0' `
        ('{0} · {1} · {2}' -f [regex]::Matches($insideCode, [regex]::Escape("`$queueStage = `$(if (`$ExitCode -eq 1) { 'code1-routed' } else { 'inside-handoff' })")).Count,
            [regex]::Matches($insideCode, [regex]::Escape('Add-AbyssPendingEntry -Stage $queueStage ')).Count, [regex]::Matches($insideCode, "Add-AbyssPendingEntry -Stage '").Count) '1 · 1 · 0'
    # S25 라우팅 안 정지 경로의 nonce 닫기(단계 2.7·2.8 구현 리뷰 P2): 서명 · 호출 = 라우팅 4곳(넘기는 라우팅 항목 nonce = 재입장 1 · 재입장 요청 3) · 4곳 모두 Stop-AllRun 바로 앞 ·
    #     닫기 함수 = 클로저 1(그 안 $script: 0) · try 하나 catch 1 · 정지 0 · throw 0(실패는 [경고]뿐 - 정지는 부른 쪽이 한 번). 호출 소유자에는 타이머(함수 밖)의 예전 처리
    #     recover 갈래 안전 중지 한 곳이 더해짐(그 자리·인자와 retry 갈래의 열어 둠은 S21). 기대값 이력: '4|Invoke-Code1JournalRouting ×4'(구현 리뷰 P2) →
    #     '6|(함수 밖),(함수 밖),…'(같은 리뷰의 확인 라운드 - recover·retry 두 곳) → '5|(함수 밖),…'(구현 리뷰 확인 - retry 를 열어 둠)
    $closeAst = Get-GuiFunctionAstByName 'Close-AbyssLaunchNonceOnStop'
    $closeClosures = @($closeAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -eq 'GetNewClosure') }, $true))
    $closeScriptReads = 0
    foreach ($closure in $closeClosures) { $closeScriptReads += [regex]::Matches((Remove-SourceComments -Text $closure.Expression.Extent.Text), '\$script:').Count }
    $closeCatches = (@($closeAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)) | ForEach-Object { $_.CatchClauses.Count }) -join ','
    $closeStops = @($closeAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Stop-AllRun') }, $true)).Count
    $closeThrows = @($closeAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)).Count
    $closeCalls = @($routeAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Close-AbyssLaunchNonceOnStop') }, $true))
    $closeArgs = ($closeCalls | ForEach-Object { (@($_.CommandElements) | Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text }) -join ' ' }) -join ' | '
    $routeCode = Remove-SourceComments -Text $guiFunctionTexts['Invoke-Code1JournalRouting']
    $beforeStop = [regex]::Matches($routeCode, 'Close-AbyssLaunchNonceOnStop -RoutedNonce [^\r\n]+\r?\n\s*Stop-AllRun ').Count
    Assert-Case 'S25 닫기 함수 서명 · 호출 소유자 · 넘기는 인자 · Stop-AllRun 바로 앞 수 · 클로저/그 안 $script: · catch · 정지 · throw' `
        ('{0} · {1} · {2} · {3} · {4}/{5} · {6} · {7} · {8}' -f (Get-ParamSignature $guiAst 'Close-AbyssLaunchNonceOnStop'), (Get-GuiCallOwners 'Close-AbyssLaunchNonceOnStop'), $closeArgs, $beforeStop,
            $closeClosures.Count, $closeScriptReads, $closeCatches, $closeStops, $closeThrows) `
        ('String $RoutedNonce · 5|(함수 밖),Invoke-Code1JournalRouting,Invoke-Code1JournalRouting,Invoke-Code1JournalRouting,Invoke-Code1JournalRouting · ' +
            '-RoutedNonce ([string]$reenteredEntry.nonce) | -RoutedNonce $retryNonce | -RoutedNonce $retryNonce | -RoutedNonce $retryNonce · 4 · 1/0 · 1 · 0 · 0')
}

# ===== ST 앱 기동 때 stale 정리 (단계 2.9 - 명세 5절 A7 · 설계 v10 6.1 'GUI 시작 시 정리') =====
$STALE_FAIL_FORMAT = '[경고] 지난 완료 기록 정리 실패({0}) - 기록을 그대로 두고 계속합니다'   # 실패는 경고 한 줄 뒤 앱 기동을 계속(구현 글자를 계약으로 고정)
$STALE_GENERATION = 4                                                                 # 지금 설정의 어비스 섹션 진행 세대(0 이 아니어야 '키 없음 = 0' 과 갈림)
$TRUNCATED_JOURNAL = '{ "version": 1, "seq": '                                         # 쓰다 끊긴 본 파일 모양(파싱 실패 = 손상)

function New-StaleEntry {
    # stale 정리 픽스처 항목 - 어비스 커스텀(-Section 기본) 또는 비커스텀(-Plain: 섹션 빈 값 · owner = 실행 id)
    param([string]$Nonce, [int]$Generation = $STALE_GENERATION, [string]$LaunchState = 'pending', [string]$Stage = 'cleared', [switch]$Plain)
    if ($Plain) { return (New-FixtureEntry -Stage $Stage -Owner ([pscustomobject]@{ runId = ('run-' + $Nonce.Substring(0, 4)) }) -LaunchState $LaunchState -Nonce $Nonce) }
    $fixture = Get-CustomFixture
    return (New-FixtureEntry -Stage $Stage -Owner $fixture.FiveNow -Generation $Generation -LaunchState $LaunchState -Section $ABYSS_SECTION -Nonce $Nonce)
}

function New-StalePending {
    # 대기열 원소 픽스처(owner 5필드 · 세대 · nonce · 단계 · 만든 시각)
    param([string]$Nonce, [int]$Generation)
    return [pscustomobject]@{ owner = (Get-CustomFixture).FiveNow; generation = $Generation; nonce = $Nonce; stage = 'inside-handoff'; createdAt = '2026-10-09T09:00:00.0000000+09:00' }
}

function Write-StaleJournal {
    # 본 파일 = 항목·대기열·applied 픽스처(실제 직렬화 · seq 5)
    param([object[]]$Entries = @(), [object[]]$Pending = @(), [object[]]$Applied = @(), [string]$Path = $script:abyssJournalPath, [long]$Seq = 5)
    $journal = New-AbyssJournalEmpty
    $journal.seq = $Seq
    $journal.savedAt = '2026-10-09T09:00:00.0000000+09:00'
    $journal.savedBy = 'worker:1234'
    $journal.entries = [object[]]@($Entries)
    $journal.pending = [object[]]@($Pending)
    $journal.applied = [object[]]@($Applied)
    [IO.File]::WriteAllText($Path, (ConvertTo-AbyssJournalText -Journal $journal), $UTF8_BOM)
}

function Get-StaleText {
    # 정리 뒤 본 파일 '항목 nonce 들 | 대기열 nonce 들 | applied | seq' (짧은 이름 - nonce 앞 4글자)
    $journal = Read-FixtureJournal -Path $script:abyssJournalPath
    if ($null -eq $journal) { return '(파일 없음)' }
    $short = { param($nonceList) ((@($nonceList) | ForEach-Object { ([string]$_).Substring(0, 4) }) -join ',') }
    return ('{0} | {1} | {2} | seq {3}' -f (& $short @($journal.entries | ForEach-Object { $_.nonce })), (& $short @($journal.pending | ForEach-Object { $_.nonce })),
        (& $short @($journal.applied)), $journal.seq)
}

function Invoke-StaleRow {
    # stale 정리 한 번 - 새 폴더(Initialize-JournalRow) 뒤 픽스처를 쓴 행에서 실제 Invoke-AbyssJournalStaleCleanup → 로그 · 저장 수 · 예외 · 폴더 그대로 여부
    param($Config, [switch]$HoldLock, [switch]$HoldMainRead, [int]$UpdateThrowAt = 0)
    $script:staleConfig = $Config
    $script:events.Clear()
    $script:journalReads = 0
    $script:journalUpdates = 0
    $stateBefore = Get-FolderState -Folder $script:rowFolder
    if ($HoldLock) { Lock-JournalLock }
    if ($HoldMainRead) { $script:heldStreams.Add([IO.File]::Open($script:abyssJournalPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)) }
    $script:updateThrowAt = $UpdateThrowAt
    $thrown = ''
    try {
        Invoke-AbyssJournalStaleCleanup
    } catch {
        $thrown = $_.Exception.Message
    } finally {
        Unlock-LogFiles
        $script:updateThrowAt = 0
        $script:staleConfig = $null
    }
    return [pscustomobject]@{
        Logs = ((@($script:events) | ForEach-Object { $_ -replace '^gui\|', '' }) -join ' ¶ ')
        Updates = $script:journalUpdates
        Reads = $script:journalReads
        Thrown = $thrown
        Unchanged = [int]($stateBefore -ceq (Get-FolderState -Folder $script:rowFolder))
    }
}

function Test-CaseStaleCleanup {
    $configNow = [pscustomobject]@{ abyssCustomRepeat = [pscustomobject]@{ progressGeneration = $STALE_GENERATION } }
    # 공통 픽스처 nonce - 앞 4글자가 짧은 이름: p1·p2 비커스텀 / c1 커스텀 지금 세대 미적용 / c2 커스텀 옛 세대(3) 적용 / c3 커스텀 지금 세대 reentered launched 적용 /
    # c4 커스텀 더 높은 세대(5 - 되돌린 설정) / q1 대기열 지금 세대 / q2 대기열 옛 세대 / 0rph applied 에만 있는 nonce
    $nonce = @{
        P1 = 'p1000000-0000-4000-8000-000000000001'; P2 = 'p2000000-0000-4000-8000-000000000002'; C1 = 'c1000000-0000-4000-8000-000000000003'
        C2 = 'c2000000-0000-4000-8000-000000000004'; C3 = 'c3000000-0000-4000-8000-000000000005'; C4 = 'c4000000-0000-4000-8000-000000000006'
        Q1 = 'q1000000-0000-4000-8000-000000000007'; Q2 = 'q2000000-0000-4000-8000-000000000008'; Orphan = '0rph0000-0000-4000-8000-000000000009'
    }
    $commonEntries = @(
        (New-StaleEntry -Nonce $nonce.P1 -Plain), (New-StaleEntry -Nonce $nonce.P2 -Plain -LaunchState 'launched'),
        (New-StaleEntry -Nonce $nonce.C1), (New-StaleEntry -Nonce $nonce.C2 -Generation 3),
        (New-StaleEntry -Nonce $nonce.C3 -Stage 'reentered' -LaunchState 'launched'), (New-StaleEntry -Nonce $nonce.C4 -Generation 5))
    $commonPending = @((New-StalePending -Nonce $nonce.Q1 -Generation $STALE_GENERATION), (New-StalePending -Nonce $nonce.Q2 -Generation 3))
    $commonApplied = @($nonce.P1, $nonce.C2, $nonce.C3, $nonce.Orphan)

    # ST1 명세 5절 A7 ①②④ - 비커스텀 항목 전부 제거(실행 중인 것 없음) · 커스텀 항목·대기열 중 세대 ≠ 지금 설정(옛 3 · 높은 5) 제거 · applied = 남은 항목 nonce 와의 교집합
    #     (항목을 남긴 채 nonce 만 빼지 않음) · 저장 1(changed - seq +1) · 로그 0 · 예외 0
    Initialize-JournalRow
    Write-StaleJournal -Entries $commonEntries -Pending $commonPending -Applied $commonApplied
    $row = Invoke-StaleRow -Config $configNow
    Assert-Case 'ST1 비커스텀 전부 · 세대 다른 커스텀 항목·대기열 제거 · applied = 남은 항목과의 교집합 · 저장 1 · 로그 0' `
        ('{0} · 저장 {1} · [{2}] · 예외 [{3}]' -f (Get-StaleText), $row.Updates, $row.Logs, $row.Thrown) 'c100,c300 | q100 | c300 | seq 6 · 저장 1 · [] · 예외 []'

    # ST2 명세 5절 A7 ⑤ - 설정을 못 읽음($null) / 어비스 섹션 없음 → 세대 기준(②)을 건너뜀: 커스텀 항목·대기열은 세대와 무관하게 남고 비커스텀(①)·교집합(④)만
    $st2 = foreach ($configCase in @(@{ N = '읽기 실패'; C = $null }, @{ N = '어비스 섹션 없음'; C = [pscustomobject]@{ customRepeat = [pscustomobject]@{ progressGeneration = 9 } } })) {
        Initialize-JournalRow
        Write-StaleJournal -Entries $commonEntries -Pending $commonPending -Applied $commonApplied
        $null = Invoke-StaleRow -Config $configCase.C
        '{0}: {1}' -f $configCase.N, (Get-StaleText)
    }
    Assert-Case 'ST2 설정 읽기 실패 || 어비스 섹션 없음 → 세대 기준 건너뜀(커스텀 항목·대기열 그대로) · 비커스텀만 제거 · applied 교집합' ($st2 -join ' || ') `
        '읽기 실패: c100,c200,c300,c400 | q100,q200 | c200,c300 | seq 6 || 어비스 섹션 없음: c100,c200,c300,c400 | q100,q200 | c200,c300 | seq 6'
    # ST2′ 어비스 섹션은 있는데 세대 키가 없음 → 지금 세대 0(진행 컨텍스트와 같은 규칙) → 세대 0 항목만 남음
    Initialize-JournalRow
    Write-StaleJournal -Entries @((New-StaleEntry -Nonce $nonce.C1 -Generation 0), (New-StaleEntry -Nonce $nonce.C2)) -Applied @($nonce.C1, $nonce.C2)
    $null = Invoke-StaleRow -Config ([pscustomobject]@{ abyssCustomRepeat = [pscustomobject]@{ listRepeat = 'infinite' } })
    Assert-Case 'ST2′ 어비스 섹션에 세대 키 없음 → 지금 세대 0 → 세대 0 항목만 남음 · 대기열 빔 · applied 교집합' (Get-StaleText) 'c100 |  | c100 | seq 6'

    # ST3 명세 5절 A7 ③ - 지금 세대 커스텀 항목 23건 → 20건이 될 때까지 '지워도 되는' 항목(applied ∧ launched 아님 ∧ 대기열이 가리키지 않음)을 오래된 것(배열 앞)부터:
    #     1번(적용·pending) 제거 · 2번(launched) · 3번(미적용) · 4번(대기열이 가리킴) 남김 · 5·6번(적용·done/pending) 제거 · 7번부터 남김 · applied 에서 지운 셋만 빠짐
    $capEntries = @()
    $capApplied = @()
    for ($capIndex = 1; $capIndex -le 23; $capIndex++) {
        $capNonce = ('e{0:D3}0000-0000-4000-8000-{1:D12}' -f $capIndex, $capIndex)
        $capState = $(switch ($capIndex) { 2 { 'launched' } 5 { 'done' } 6 { 'pending' } default { $(if ($capIndex -ge 7) { 'done' } else { 'pending' }) } })
        $capEntries += (New-StaleEntry -Nonce $capNonce -LaunchState $capState)
        if ($capIndex -ne 3) { $capApplied += $capNonce }
    }
    Initialize-JournalRow
    Write-StaleJournal -Entries $capEntries -Pending @(New-StalePending -Nonce ('e{0:D3}0000-0000-4000-8000-{1:D12}' -f 4, 4) -Generation $STALE_GENERATION) -Applied $capApplied
    $null = Invoke-StaleRow -Config $configNow
    $capJournal = Read-FixtureJournal -Path $script:abyssJournalPath
    $keptNumbers = @($capJournal.entries | ForEach-Object { [int]([string]$_.nonce).Substring(1, 3) })
    Assert-Case 'ST3 상한 20 - 23건 → 지워도 되는 오래된 것부터 3건(1·5·6번) 제거 · launched(2)·미적용(3)·대기열이 가리킴(4) 남김 · applied 22 → 19' `
        ('항목 {0}건 · 남은 앞 6 = {1} · 없음 {2} · applied {3}건' -f $keptNumbers.Count, (($keptNumbers | Select-Object -First 6) -join ','),
            ((@(1, 5, 6) | Where-Object { $keptNumbers -notcontains $_ }).Count), @($capJournal.applied).Count) '항목 20건 · 남은 앞 6 = 2,3,4,7,8,9 · 없음 3 · applied 19건'
    # ST3′ 단계 2.7~2.9 구현 검증(명세 대조 P3-1) - 상한 정리는 다음 기동의 이어받기 후보를 지우지 않습니다. 시작 게이트 S0 는 계상 전에 끝난 재입장을 진행에
    #      반영하며 applied 만 남기고 launchState 는 그대로 둡니다(dev:944 - 첫 기동의 후보 고르기가 next 로 그 판을 이어받게: 후보 고르기는 applied 를 보지 않음).
    #      그 기동 전에 앱이 다시 켜져도 그 항목은 남아야 합니다(지우면 다음 시작이 이어받을 기록 없이 다음 판 던전 안에서 시작 - dev:906). 22건: 1번 = S0 가 반영한
    #      재입장(applied · pending · nextOwner = 다음 칸) · 2번 = 끝난 재입장(applied · done - 지워도 됨) · 3번부터 클리어(applied · done) → 2건 제거 = 2·3번(1번 남김) ·
    #      정리 뒤 실제 후보 고르기(다음 칸 owner)가 1번을 next 로 고름. 변이 '재입장 보호 제거' 는 1번이 지워져 후보 없음, '재입장이면 done 이어도 남김' 은 2번이 남음
    $candidateNext = Get-CustomCanonicalOwner -Context (New-AbyssContext -Index 1 -Generation $STALE_GENERATION)
    $candidateEntries = @()
    $candidateApplied = @()
    for ($candidateIndex = 1; $candidateIndex -le 22; $candidateIndex++) {
        $candidateNonce = ('f{0:D3}0000-0000-4000-8000-{1:D12}' -f $candidateIndex, $candidateIndex)
        if ($candidateIndex -le 2) {
            $candidateState = $(if ($candidateIndex -eq 1) { 'pending' } else { 'done' })
            $candidateEntries += (New-FixtureEntry -Stage 'reentered' -Owner (Get-CustomFixture).FiveNow -NextOwner (ConvertTo-FiveFieldOwner $candidateNext) -Generation $STALE_GENERATION `
                    -LaunchState $candidateState -Section $ABYSS_SECTION -Nonce $candidateNonce)
        } else {
            $candidateEntries += (New-StaleEntry -Nonce $candidateNonce -LaunchState 'done')
        }
        $candidateApplied += $candidateNonce
    }
    Initialize-JournalRow
    Write-StaleJournal -Entries $candidateEntries -Applied $candidateApplied
    $null = Invoke-StaleRow -Config $configNow
    $candidateJournal = Read-FixtureJournal -Path $script:abyssJournalPath
    $candidateKept = @($candidateJournal.entries | ForEach-Object { [int]([string]$_.nonce).Substring(1, 3) })
    $candidatePick = Invoke-RealResolveHandoffEnv -Context $candidateNext
    $candidatePickText = $(if ([string]$candidatePick.Nonce) { ([string]$candidatePick.Nonce).Substring(0, 4) } else { '(없음)' })
    Assert-Case "ST3′ 상한 정리 - S0 가 반영한 재입장(applied · pending)은 남김 · 끝난 재입장(done)은 지움 → 22건 → 20건(2·3번 제거) · 정리 뒤 후보 고르기 = next/1번" `
        ('항목 {0}건 · 앞 3 = {1} · applied {2}건 · 후보 {3}/{4}/{5}' -f $candidateKept.Count, (($candidateKept | Select-Object -First 3) -join ','), @($candidateJournal.applied).Count,
            $candidatePick.Status, $candidatePick.Kind, $candidatePickText) '항목 20건 · 앞 3 = 1,4,5 · applied 20건 · 후보 ok/next/f001'

    # ST4 지울 것 없음 → 저장 1(접근) · 논리 변경 쓰기 0(unchanged - 본 파일 바이트·직전본 생성 0 · 폴더 그대로) / 파일이 하나도 없음 → 파일 생성 0
    Initialize-JournalRow
    Write-StaleJournal -Entries @((New-StaleEntry -Nonce $nonce.C1), (New-StaleEntry -Nonce $nonce.C3 -Stage 'reentered' -LaunchState 'launched')) -Pending @(New-StalePending -Nonce $nonce.Q1 -Generation $STALE_GENERATION) -Applied @($nonce.C3)
    $rowSame = Invoke-StaleRow -Config $configNow
    Initialize-JournalRow
    $rowNone = Invoke-StaleRow -Config $configNow
    Assert-Case 'ST4 지울 것 없음 → 저장 1 · 폴더 그대로(쓰기 0) · 로그 0 || 파일 없음 → 저장 1 · 파일 생성 0 · 로그 0' `
        ('{0}/{1}/[{2}] || {3}/{4}/[{5}] · 파일 {6}' -f $rowSame.Updates, $rowSame.Unchanged, $rowSame.Logs, $rowNone.Updates, $rowNone.Unchanged, $rowNone.Logs,
            @(Get-ChildItem -LiteralPath $script:rowFolder -File).Count) '1/1/[] || 1/1/[] · 파일 0'

    # ST5 실패는 [경고] 한 줄 + 계속(예외 0 · 파일 그대로): 사용 중(잠금을 쥠) · 손상(본 파일·직전본) · 기록 실패(본 파일을 읽기만 허용하고 쥠 - 교체 실패) · 저장 예외
    $st5 = foreach ($failKind in @('locked', 'corrupt', 'io-failed', 'exception')) {
        Initialize-JournalRow
        if ($failKind -eq 'corrupt') {
            [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JOURNAL, $UTF8_BOM)
            [IO.File]::WriteAllText($script:abyssJournalPath + '.bak', $TRUNCATED_JOURNAL, $UTF8_BOM)
        } else {
            Write-StaleJournal -Entries $commonEntries -Pending $commonPending -Applied $commonApplied
        }
        $failRow = Invoke-StaleRow -Config $configNow -HoldLock:($failKind -eq 'locked') -HoldMainRead:($failKind -eq 'io-failed') -UpdateThrowAt $(if ($failKind -eq 'exception') { 1 } else { 0 })
        '{0}: [{1}] · 예외 [{2}] · 파일 그대로 {3}' -f $failKind, $failRow.Logs, $failRow.Thrown, $failRow.Unchanged
    }
    Assert-Case 'ST5 사용 중 · 손상 · 기록 실패 · 저장 예외 → [경고] 정리 실패 한 줄 · 예외 0 · 파일 그대로' ($st5 -join ' || ') `
        ((@(('locked', ($STALE_FAIL_FORMAT -f '파일 사용 중')), ('corrupt', ($STALE_FAIL_FORMAT -f '파일 손상')), ('io-failed', ($STALE_FAIL_FORMAT -f '기록 실패')),
                ('exception', ($STALE_FAIL_FORMAT -f ('예외: ' + $INJECTED_UPDATE_EXCEPTION)))) | ForEach-Object { '{0}: [{1}] · 예외 [] · 파일 그대로 1' -f $_[0], $_[1] }) -join ' || ')

    # ST6 본 파일 손상 + 직전본 유효 → 저장소가 직전본으로 복구(경고 한 줄 - 로그는 호출부 몫) → 그 위에서 정리
    Initialize-JournalRow
    Write-StaleJournal -Path ($script:abyssJournalPath + '.bak') -Entries $commonEntries -Pending $commonPending -Applied $commonApplied
    [IO.File]::WriteAllText($script:abyssJournalPath, $TRUNCATED_JOURNAL, $UTF8_BOM)
    $row = Invoke-StaleRow -Config $configNow
    Assert-Case 'ST6 본 파일 손상·직전본 유효 → 복구 경고 1줄 → 정리 결과 = ST1 과 같음' ('[{0}] · {1}' -f $row.Logs, ((Get-StaleText) -replace ' \| seq \d+$', '')) `
        ('[{0}] · c100,c300 | q100 | c300' -f $RECOVERED_WARNING)

    # ST7 정적 - 앱 기동의 설정 이전 바로 다음 문장 · 호출 소유자(함수 밖 1) · 클로저 1(그 안 $script: 0 · 함수 호출 0) · try 마다 catch 1
    $topStatements = @($guiAst.EndBlock.Statements)
    $migrateAt = -1
    for ($topIndex = 0; $topIndex -lt $topStatements.Count; $topIndex++) {
        if ($topStatements[$topIndex].Extent.Text -ceq '$script:configMigrated = Update-ConfigToLatest') { $migrateAt = $topIndex }
    }
    $nextTopText = $(if (($migrateAt -ge 0) -and ($migrateAt + 1 -lt $topStatements.Count)) { $topStatements[$migrateAt + 1].Extent.Text } else { '' })
    $staleAst = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq 'Invoke-AbyssJournalStaleCleanup') }, $true))[0]
    $staleClosures = @($staleAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -eq 'GetNewClosure') }, $true))
    $closureCode = $(if ($staleClosures.Count -eq 1) { Remove-SourceComments -Text $staleClosures[0].Expression.Extent.Text } else { '' })
    $closureCommands = $(if ($staleClosures.Count -eq 1) { (@($staleClosures[0].Expression.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() }) | Sort-Object -Unique) -join ',' } else { '(클로저 수 다름)' })
    $staleCatches = (@($staleAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)) | ForEach-Object { $_.CatchClauses.Count }) -join ','
    Assert-Case 'ST7 설정 이전 다음 문장 = stale 정리 · 호출 소유자 함수 밖 1 · 클로저 1(그 안 $script: 0 · 명령은 ForEach-Object 뿐 - GUI 함수 호출 0) · try 마다 catch 1' `
        ('{0} · {1} · {2}/{3}/{4} · {5}' -f $nextTopText, (Get-GuiCallOwners 'Invoke-AbyssJournalStaleCleanup'), $staleClosures.Count, [regex]::Matches($closureCode, '\$script:').Count,
            $closureCommands, $staleCatches) 'Invoke-AbyssJournalStaleCleanup · 1|(함수 밖) · 1/0/ForEach-Object · 1,1,1,1'
}

# ===== 실행 =====
$caseFunctions = @('Test-CaseHarness', 'Test-CaseCollectOrder', 'Test-CaseSourceFailure', 'Test-CaseHandoffTail',
    'Test-CaseLaunchRange', 'Test-CaseLaunchFinishOnly', 'Test-CaseLaunchStartFail', 'Test-CaseLaunchKinds', 'Test-CaseResolve', 'Test-CaseStatic',
    'Test-CaseExitJudge', 'Test-CaseExitPlain', 'Test-CaseExitCustom', 'Test-CaseExitFinishOnly', 'Test-CaseExitNone', 'Test-CaseExitCode10',
    'Test-CaseExitEnd', 'Test-CaseExitOrder', 'Test-CaseSafeStopCancel', 'Test-CaseExitRecoveryWarnings', 'Test-CaseExitStatic',
    # 단계 2.7 코드 4
    'Test-CaseDoneMarkers', 'Test-CaseCode4Plan', 'Test-CaseCode4Count', 'Test-CaseCode4Relay', 'Test-CaseCode4Failure', 'Test-CaseCode4Coupling',
    'Test-CaseCode4CouplingWorker', 'Test-CaseCode4Static',
    # 단계 2.8 코드 1
    'Test-CaseCode1Reentered', 'Test-CaseCode1FinishOnly', 'Test-CaseCode1Retry', 'Test-CaseCode1Legacy', 'Test-CaseCode1Failure', 'Test-CaseCode1StopNonce',
    'Test-CaseCode1LegacySafeStopNonce', 'Test-CaseCode1Static',
    # 단계 2.9 앱 기동 때 stale 정리
    'Test-CaseStaleCleanup')
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
    Unlock-LogFiles
    foreach ($envName in $ALL_ENV_NAMES) { [Environment]::SetEnvironmentVariable($envName, [string]$originalEnv[$envName], 'Process') }
    try { [System.IO.Directory]::Delete($testRootFolder, $true) } catch { "참고: 임시 폴더 정리 실패 - $($_.Exception.Message)" }
}
'걸린 시간 {0:N1}초' -f ($totalWatch.ElapsedMilliseconds / 1000)
exit $fails
