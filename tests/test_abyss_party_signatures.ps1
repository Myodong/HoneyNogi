# 어비스 파티 준비 패널·파티원 화면 서명 진리표 (⑥a 판정 핫픽스 - 2026-09-26 설계 합의 8절 ①, 실기 -1 + 09-21 실측)
#
# 배경: v2.1.12 보상 화면 3버튼 서명 교체 뒤 파티원 보상 화면('[ESC] 나가기' + '파티장 선택 대기' 2버튼)을 아무 판정도 알아보지 못해
# 옛 파티원 사이클이 매 판 코드 1 이었고(설계 0.3), 파티 준비 패널은 카드 영역이 '…허상의정박지/입문' 으로 읽혀 선택 화면으로 오판됐다
# (실기 -1 2/4 준비 패널 29/29 + 09-21 4/4 6/6). 패널 밖을 누르면 패널이 접혀 '나가기 / 입장 대기 중' 이 남는데, 그 '나가기' 는 던전 퇴장이다.
# 여기서 고정하는 계약:
#   ① 순수 판정 진리표 (판독문 = 오프라인 판독문표의 실측 문자열 그대로 - 캡처 없이도 항상 실행)
#      준비 패널 '완료되면'+'바로입장' / 버튼 상태 ready-available·ready-done·none / 파티원 보상 '나가기'+'파티장'+'선택' /
#      접힌 준비 패널 '나가기'+'대기중' ('대기' 단독 금지) / 권장 인원 팝업 '취소'+'도전하' ('도' 탈락 프레임은 거짓)
#      하단 서명 넷(3버튼·파티원 보상·접힌 패널·팝업)은 실측 판독문 전부에서 동시에 둘 이상 참이 되지 않는다
#   ② 캡처 재생 (보존 캡처·OCR 엔진이 없으면 SKIP): 운영 판독 함수를 그대로 써서
#      준비 패널 23프레임 → 패널 종류 ready · 선택 화면 거짓(고치기 전 판정은 참 = 오판 재현) · 알려진 화면 참 · 헬퍼 ready-panel 클릭 0
#      접힌 패널 10프레임 → entry-waiting · 헬퍼 클릭 0 / 파티원 보상 8프레임 → 헬퍼가 '나가기'@(515,654) 클릭
#      권장 인원 팝업 5프레임 → 알려진 화면 참 (등록 전 판정은 거짓 = 이벤트 정리 헛클릭 재현) / 기존 화면(3버튼·재매칭·선택 오버레이·
#      던전 안·필드·클리어 S) 판정 불변
#   ③ ⑥e (2026-09-30 설계 5.3): 파티원 분류(Resolve-AbyssMemberScreen)·보상 위 판별·재펼침 앵커·나가기 단어·퇴장 전이 표를 09-29 실기 1 프레임과
#      09-21 프레임으로 재생 - 퇴장 로딩·필드 도착·입장 로딩·던전 도착·컷신은 unknown, 던전 안 추적기 오독·입장 과도는 field(필드의 증거가 아님),
#      재매칭은 HUD 가 보여도 matching. 전이 열 재생(가~자)은 '끊김 없이 관측된 퇴장 전이' 로만 'left' 가 나옴을 실제 판독문으로 확인하고,
#      선택 화면 오버레이 두 장에서 나가기 헬퍼는 'selection'(누르지 않음 - 워커가 연 화면인지는 복귀 루프의 출처가 판정)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

# ── 1. 순수 판정 진리표 ─────────────────────────────────────────────────────────
foreach ($name in @('Test-AbyssReadyPanelText', 'Test-AbyssMatchingPanelText', 'Get-AbyssReadyButtonState', 'Get-AbyssPartyEnterButtonState', 'Test-AbyssMemberRewardText',
    'Test-AbyssEntryWaitingText', 'Test-AbyssFewMembersPopupText', 'Test-AbyssRewardText')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}
# abyssMenu 영역 (850,180,350,520) 배율 4 판독
$menuLeaderL1 = '박지/입문파티홍보패널100요동•X104,4385044화염술klülEl원이준비완료되면바로입장합니다.준비취소'   # 실기 -1 L1 (파티장 2/4, 필드 위)
$menuMemberM2 = '!t지/입문100부꼼/`97,8554,428사제파EI원이준비완료되면바로입장합LI다.준비완료'                    # 실기 -1 M2 (파티원, 보상 위 - '니'→'LI')
$menuMemberB1 = '25@5,268빙결술kl빙꿈•/`115,079@7,508빙결술人l표IE|원이준비완료되면바로입장합니다.준비완료'        # 09-21 B1 (4/4 파티원)
$menuMatching = '빻지/입문근든플레이어가모이면자동입장합니다.00:00'                                                  # 09-18 재매칭 패널
$menuOverlay = '4'                                                                                                  # 09-18 선택 화면 오버레이
$menuField = '추천주말에는兮1일6.법황청의특별수신중하게H4린[•目랫[CI人1간1[긴급의'                                   # 실기 -1 L6+1 필드
Check-Equal '준비 패널: 파티장 L1 → 참' (Test-AbyssReadyPanelText -Text $menuLeaderL1) $true
Check-Equal "준비 패널: 파티원 M2('입장합LI다' 깨짐) → 참" (Test-AbyssReadyPanelText -Text $menuMemberM2) $true
Check-Equal '준비 패널: 09-21 B1 → 참' (Test-AbyssReadyPanelText -Text $menuMemberB1) $true
Check-Equal '준비 패널: 재매칭 패널 → 거짓 (두 패널 상호 배타)' (Test-AbyssReadyPanelText -Text $menuMatching) $false
Check-Equal '재매칭 패널: 준비 패널 판독 → 거짓 (상호 배타 반대 방향)' ((@($menuLeaderL1, $menuMemberM2) | ForEach-Object { Test-AbyssMatchingPanelText -Text $_ }) -join '/') 'False/False'
Check-Equal '준비 패널: 선택 화면 오버레이·필드·빈 판독 → 거짓' ((@($menuOverlay, $menuField, '', $null) | ForEach-Object { Test-AbyssReadyPanelText -Text $_ }) -join '/') 'False/False/False/False'
Check-Equal "준비 패널: '완료되면' 만 / '바로입장' 만 → 거짓 (두 조각 요구)" ((@('준비완료되면', '바로입장합니다') | ForEach-Object { Test-AbyssReadyPanelText -Text $_ }) -join '/') 'False/False'
# partyEnterButton (900,630,260,48) 배율 4 판독
Check-Equal "버튼: '준비완료'(파티원 17/17) → ready-available" (Get-AbyssReadyButtonState -Text '준비완료') 'ready-available'
Check-Equal "버튼: '준비취소'(파티장·누른 뒤 12/12) → ready-done (누르면 준비가 풀림 - 클릭 금지)" (Get-AbyssReadyButtonState -Text '준비취소') 'ready-done'
Check-Equal "버튼: '준비 완료 취소' 같이 둘 다 → ready-done ('취소' 가 이김)" (Get-AbyssReadyButtonState -Text '준비완료취소') 'ready-done'
Check-Equal "버튼: 상세 'space입장하기'·재매칭 '피어가모이면자동입장합니다.'·'(표가'(B3')·'' → none" ((@('space입장하기', '피어가모이면자동입장합니다.', '(표가', '') | ForEach-Object { Get-AbyssReadyButtonState -Text $_ }) -join '/') 'none/none/none/none'
Check-Equal "버튼: '완료' 만('협동미션완료') → none ('준비' 조각 요구 - 2026-08-01 전수 점검)" (Get-AbyssReadyButtonState -Text '협동미션완료') 'none'
# 파티장 첫 입장 버튼 (같은 영역 - 설계 4.1 C-F7, 배선은 ⑥d): 순서 고정 ①준비+취소 → ready-done ②준비+완료 → ready-available ③그 외 취소 → cancel ④입장하기·장하기 → enter ⑤ none
Check-Equal "첫 입장 버튼: 상세 'space입장하기'(E2x)·'입장하기'(E3x) → enter / '입장취소'(07-17 실사고) → cancel / '' → none" ((@('space입장하기', '입장하기', '입장취소', '') | ForEach-Object { Get-AbyssPartyEnterButtonState -Text $_ }) -join '/') 'enter/enter/cancel/none'
Check-Equal "첫 입장 버튼: 패널 버튼 '준비취소' → ready-done (cancel 아님 - 순서 ①) / '준비완료' → ready-available / '장하기' 깨짐 → enter" ((@('준비취소', '준비완료', '장하기') | ForEach-Object { Get-AbyssPartyEnterButtonState -Text $_ }) -join '/') 'ready-done/ready-available/enter'
Check-Equal "첫 입장 버튼: '입장하기'+'취소' 가 함께 → cancel (취소가 이김 - 이미 누른 입장을 다시 누르지 않음)" (Get-AbyssPartyEnterButtonState -Text '입장하기취소') 'cancel'
# clearAndExitText (430,570,420,125) 배율 3 판독
$bottom = [ordered]@{
  member   = '아이템을누르면상세정보를수있습니다나가기파티장선택대기'             # A1·A2·F3·M5·M5r
  entry    = '아이템을누르면상세정보를수있습니다나가기입장대기중'               # L5f·M3 계열
  entryCur = '아이템을누르면상세정보를수있습니다나가기자대기중'                 # M4-pre (커서가 '입장' 을 가림)
  popup    = '㉬취소Space도전하기'                                             # G4·G5·L2
  popupL5  = '(3이취소Space도전하기'                                           # L5
  popupOut = '아이템을누르면상세저曰曇한수있습니다3다취소나가기도전하기'       # L5+1 (소멸 중)
  popupDrop = '㉬취소Space전하기'                                              # L2+1 ('도' 탈락)
  reward3  = '아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기' # L4+1·D2 계열
  reward3b = '나가기아이템을누르면상세정보를수있습니다Space다세하기던전가기'   # L4 ('다른' 탈락 첫 프레임)
  readyB1  = '아이템을누르면상세정보를7Space나가기'                           # B1 (보상 위 준비 패널)
  readyM5x = '아이템을누르면상세정보를긴나가기모든Space'                      # M5-1 (패널 소멸 혼합 1초)
  readyD1b = '아이템을누르면상세정보를모든나가기'                              # D1b
  prompt   = '화면을터치해주세요'                                              # S4
  field    = '골든리트년1'                                                     # L1'
  # ⑥e 설계 5.3: 09-29 실기 1 판독문 7종 (서명 조각 '나가기'·'대기'·'확인' 이 든 새 변형 - 한 판독이 둘 이상의 서명에 걸리지 않아야 알려진 화면·분류가 성립)
  ready29x  = '아이템을누르면상세정보를모든Space나가기'                          # 0929-211944·211945 (보상 위 준비 패널, 패널 밖 '나가기'@492)
  ready29y  = '아이템을누르면상세정보를나가기모든Space(0'                        # 0929-212032
  entry29   = '아이템을누르면상세정보를를수있습니다나가기입장대기중'             # 0929-212005·212937 ('를' 이 끼는 접힌 패널)
  member29  = '아이템을누르면상세정보를를수있습니다나가기파티장선택대기'         # 0929-212401·211928·212031
  entryCur29a = '아이템을누르면상세정보를수있습니다나가기입장대가축'           # 0929-211946 (커서가 가린 접힘 - 서명 거짓)
  entryCur29b = '아이템을누르면상세정보를수있습니다나가기입장[중'               # 0929-212938 (커서가 가린 접힘 - 서명 거짓)
  itemPopup29 = '아이템을누르면상)`引정보를수있습니다Space확인'                  # 0929-211927 (아이템 확인 팝업 - 서명 거짓)
}
Check-Equal '파티원 보상: 실측 판독 → 참' (Test-AbyssMemberRewardText -Text $bottom.member) $true
Check-Equal '파티원 보상: 3버튼·접힌 패널·준비 패널(B1·M5-1)·팝업·S·필드 → 전부 거짓' ((@('reward3', 'entry', 'readyB1', 'readyM5x', 'popup', 'prompt', 'field') | ForEach-Object { Test-AbyssMemberRewardText -Text $bottom[$_] }) -join ',') 'False,False,False,False,False,False,False'
Check-Equal "파티원 보상: '나가기'+'파티장' 만('선택' 없음) → 거짓 (세 조각 요구)" (Test-AbyssMemberRewardText -Text '나가기파티장') $false
Check-Equal '3버튼 보상: 파티원 보상 판독 → 거짓 (옛 파티원 사이클이 매 판 코드 1 이던 원인 - 0.3)' (Test-AbyssRewardText -Text $bottom.member) $false
Check-Equal '접힌 패널: L5f·M3 → 참 / 커서 가림 M4-pre → 참' ((@($bottom.entry, $bottom.entryCur) | ForEach-Object { Test-AbyssEntryWaitingText -Text $_ }) -join '/') 'True/True'
Check-Equal "접힌 패널: 파티원 보상('…선택대기' - '대기' 는 있지만 '대기중' 없음) → 거짓 ('대기' 단독 금지)" (Test-AbyssEntryWaitingText -Text $bottom.member) $false
Check-Equal "접힌 패널: '입장대기중' 만('나가기' 없음) → 거짓 (두 조각 요구)" (Test-AbyssEntryWaitingText -Text '입장대기중') $false
Check-Equal '접힌 패널: 3버튼·준비 패널·팝업(소멸 중 포함)·S·빈 판독 → 전부 거짓' ((@('reward3', 'readyB1', 'readyD1b', 'popup', 'popupOut', 'prompt') | ForEach-Object { Test-AbyssEntryWaitingText -Text $bottom[$_] }) -join ',') 'False,False,False,False,False,False'
Check-Equal '권장 인원 팝업: G4·L5·소멸 중 L5+1 → 참' ((@($bottom.popup, $bottom.popupL5, $bottom.popupOut) | ForEach-Object { Test-AbyssFewMembersPopupText -Text $_ }) -join '/') 'True/True/True'
Check-Equal "권장 인원 팝업: '도' 탈락 전환 프레임(L2+1) → 거짓 (다음 판독에 맡김)" (Test-AbyssFewMembersPopupText -Text $bottom.popupDrop) $false
Check-Equal '권장 인원 팝업: 3버튼·파티원 보상·접힌 패널·S·빈 판독 → 전부 거짓' ((@('reward3', 'member', 'entry', 'prompt') | ForEach-Object { Test-AbyssFewMembersPopupText -Text $bottom[$_] }) -join ',') 'False,False,False,False'
#    1-x. 하단 서명 넷의 상호 배타: 실측 판독문 전부에서 동시에 둘 이상 참이 아님 (알려진 화면 등록이 한 판독으로 넷을 함께 보는 전제)
$multiHits = @()
foreach ($key in $bottom.Keys) {
  $hits = @((Test-AbyssRewardText -Text $bottom[$key]), (Test-AbyssMemberRewardText -Text $bottom[$key]), (Test-AbyssEntryWaitingText -Text $bottom[$key]), (Test-AbyssFewMembersPopupText -Text $bottom[$key])) | Where-Object { $_ }
  if (@($hits).Count -gt 1) { $multiHits += $key }
}
Check-Equal "하단 서명 넷 상호 배타 (실측 판독문 $($bottom.Count)종 - 09-29 7종 포함)" ($multiHits -join ',') ''

# ── 2. 캡처 재생 (운영 판독 함수 그대로 - 오프라인) ─────────────────────────────
$abyssDir = Join-Path $projectRoot '던전이미지\어비스'
$live = '20260926_준비패널4인_준비취소_나가기_수동실측'
$p4m = '20260921_파티원4인_준비완료버튼_필드_보상화면_파티장나가기뒤_나가기수동_실측'
$p4l = '20260921_파티장4인_토글ON풀파티_다시하기_팝업없음_보상화면대기_준비패널_실측'
$p4o = '20260921_파티장4인_토글OFF_입장하기_파티패널준비취소_다른던전가기2회_실측'
$p2m = '20260921_파티원2인_자동준비패널_보상화면_파티장선택대기_필드이동_실측'
$p2l = '20260921_파티장2인_다시하기_인원부족팝업_다른던전가기_상세2버튼_실측'
$inc = '20260921_파티원_파티장다시하기뒤_자동입장_나가기대기초과'
$f29 = '20260929_⑥a_실기1_파티원2인\frames'        # ⑥a 실기 1 (09-29 파티원 2인) 1초 간격 프레임
$w29 = '20260929_⑥a_실기1_파티원2인\worker_logs'   # 같은 실기의 워커 오류 캡처 (던전 안 추적기 오독)
# 라벨|종류|경로 (라벨은 설계 4.3·실기 -1 판독문표의 라벨 그대로, 09-29 프레임은 '0929-시각'). 한 줄에 범주 하나 (⑥e 설계 5.3).
# 종류: ready / ready-field / entry / member / entry-occluded / item-popup / popup / popup-drop / reward3 / matching / member-matching / overlay /
#       inside / inside-misread / inside-cutscene / field / field-arrival / leave-loading / entry-loading / dungeon-arrival / entry-misread / prompt
$frames = @(
  "L1|ready|$live\cap_225515_580_1272x717.png", "L3|ready|$live\cap_230059_611_1272x717.png", "L3c|ready|$live\cap_230435_362_1272x717.png",
  "L5p|ready|$live\cap_230533_423_1272x717.png", "M1|ready|$live\cap_230954_767_1272x717.png", "M2|ready|$live\cap_231452_829_1272x717.png",
  "M2+1|ready|$live\cap_231453_893_1272x717.png", "M4-pre2|ready|$live\cap_231727_206_1272x717.png", "M5-1|ready|$live\cap_231827_080_1272x717.png",
  "B1|ready|$p4m\cap_212550_642_1272x717.png", "B2|ready|$p4m\cap_212556_892_1272x717.png", "B3|ready|$p4m\cap_212249_924_1272x717.png",
  "C1|ready|$p4l\cap_211722_423_1272x717.png", "D1b|ready|$p4l\cap_211721_362_1272x717.png", "E1|ready|$p4o\cap_203551_455_1272x717.png",
  "0929-211602|ready|$f29\cap_211602_650_1272x717.png", "0929-212407|ready|$f29\cap_212407_087_1272x717.png", "0929-212408|ready|$f29\cap_212408_150_1272x717.png", "0929-211944|ready|$f29\cap_211944_558_1272x717.png", "0929-211945|ready|$f29\cap_211945_619_1272x717.png", "0929-211947|ready|$f29\cap_211947_743_1272x717.png", "0929-212032|ready|$f29\cap_212032_275_1272x717.png", "0929-212939|ready|$f29\cap_212939_493_1272x717.png",
  "M1|ready-field|$live\cap_230954_767_1272x717.png", "B3|ready-field|$p4m\cap_212249_924_1272x717.png", "0929-210545|ready-field|$f29\cap_210545_900_1272x717.png", "0929-210547|ready-field|$f29\cap_210547_992_1272x717.png",
  "L5f|entry|$live\cap_230558_237_1272x717.png", "M3|entry|$live\cap_231636_456_1272x717.png", "M4-pre|entry|$live\cap_231726_143_1272x717.png",
  "0929-212409|entry|$f29\cap_212409_212_1272x717.png", "0929-211959|entry|$f29\cap_211959_307_1272x717.png", "0929-212005|entry|$f29\cap_212005_683_1272x717.png", "0929-212937|entry|$f29\cap_212937_369_1272x717.png", "0929-212410|entry|$f29\cap_212410_275_1272x717.png", "0929-212411|entry|$f29\cap_212411_338_1272x717.png", "0929-212414|entry|$f29\cap_212414_464_1272x717.png",
  "A1|member|$p4m\cap_212549_580_1272x717.png", "A2|member|$p4m\cap_212906_581_1272x717.png", "F3|member|$p2m\cap_185738_142_1272x717.png",
  "M5|member|$live\cap_231828_143_1272x717.png", "M5r|member|$live\cap_231856_237_1272x717.png",
  "0929-212401|member|$f29\cap_212401_776_1272x717.png", "0929-211928|member|$f29\cap_211928_495_1272x717.png", "0929-212031|member|$f29\cap_212031_213_1272x717.png",
  "0929-211946|entry-occluded|$f29\cap_211946_682_1272x717.png", "0929-212938|entry-occluded|$f29\cap_212938_431_1272x717.png",
  "0929-211927|item-popup|$f29\cap_211927_433_1272x717.png",
  "G4|popup|$p2l\cap_182613_955_1272x717.png", "G5|popup|$p2l\cap_182623_331_1272x717.png", "L2|popup|$live\cap_230057_487_1272x717.png",
  "L5|popup|$live\cap_230531_299_1272x717.png", "L5+1|popup|$live\cap_230532_362_1272x717.png",
  "L2+1|popup-drop|$live\cap_230058_549_1272x717.png",
  "D2|reward3|$p4l\cap_211713_987_1272x717.png", "L4|reward3|$live\cap_230444_675_1272x717.png", "L4+1|reward3|$live\cap_230445_737_1272x717.png",
  "F1|matching|$p2m\cap_185218_142_1272x717.png", "F2|matching|$p2m\cap_184351_237_1272x717.png",
  "0921-184830|member-matching|$p2m\cap_184830_364_1272x717.png", "0921-184832|member-matching|$p2m\cap_184832_455_1272x717.png", "0921-184833|member-matching|$p2m\cap_184833_518_1272x717.png", "0921-184835|member-matching|$p2m\cap_184835_642_1272x717.png", "0921-184837|member-matching|$p2m\cap_184837_767_1272x717.png", "0921-184838|member-matching|$p2m\cap_184838_830_1272x717.png", "0921-184841|member-matching|$p2m\cap_184841_956_1272x717.png", "0921-185218|member-matching|$p2m\cap_185218_142_1272x717.png", "0921-185219|member-matching|$p2m\cap_185219_205_1272x717.png", "0921-185220|member-matching|$p2m\cap_185220_267_1272x717.png", "0921-185221|member-matching|$p2m\cap_185221_331_1272x717.png", "0921-185222|member-matching|$p2m\cap_185222_392_1272x717.png", "0921-185223|member-matching|$p2m\cap_185223_456_1272x717.png", "0921-185224|member-matching|$p2m\cap_185224_519_1272x717.png", "0921-185225|member-matching|$p2m\cap_185225_581_1272x717.png", "0921-185226|member-matching|$p2m\cap_185226_643_1272x717.png", "0921-185227|member-matching|$p2m\cap_185227_706_1272x717.png", "0921-185230|member-matching|$p2m\cap_185230_831_1272x717.png", "0921-185231|member-matching|$p2m\cap_185231_893_1272x717.png", "0921-185232|member-matching|$p2m\cap_185232_956_1272x717.png", "0921-185234|member-matching|$p2m\cap_185234_018_1272x717.png", "0921-185235|member-matching|$p2m\cap_185235_081_1272x717.png",
  "S1|overlay|20260918_다른던전가기_01_어비스선택오버레이_3카드_X_1272x717.png", "O3|overlay|$p2l\cap_183211_892_1272x717.png",
  "X1|inside|$inc\error_20260921_h15m56s42.png", "X2|inside|$inc\error_20260921_h16m09s49.png",
  "0929-h21m06s37|inside-misread|$w29\error_20260929_h21m06s37.png", "0929-h21m17s34|inside-misread|$w29\error_20260929_h21m17s34.png", "0929-210634|inside-misread|$f29\cap_210634_932_1272x717.png", "0929-210637|inside-misread|$f29\cap_210637_089_1272x717.png", "0929-211732|inside-misread|$f29\cap_211732_557_1272x717.png",
  "0929-210853|inside-cutscene|$f29\cap_210853_776_1272x717.png", "0929-210854|inside-cutscene|$f29\cap_210854_839_1272x717.png", "0929-210855|inside-cutscene|$f29\cap_210855_902_1272x717.png", "0929-210856|inside-cutscene|$f29\cap_210856_963_1272x717.png", "0929-210858|inside-cutscene|$f29\cap_210858_026_1272x717.png",
  "L1'|field|$live\cap_225650_551_1272x717.png", "L6+1|field|$live\cap_230715_862_1272x717.png", "M6|field|$live\cap_232213_486_1272x717.png",
  "0929-210525|field|$f29\cap_210525_840_1272x717.png", "0929-211010|field|$f29\cap_211010_963_1272x717.png", "0929-213317|field|$f29\cap_213317_997_1272x717.png",
  "0929-211009|field-arrival|$f29\cap_211009_900_1272x717.png", "0929-213316|field-arrival|$f29\cap_213316_932_1272x717.png",
  "0929-210521|leave-loading|$f29\cap_210521_682_1272x717.png", "0929-210522|leave-loading|$f29\cap_210522_744_1272x717.png", "0929-210523|leave-loading|$f29\cap_210523_776_1272x717.png", "0929-211005|leave-loading|$f29\cap_211005_652_1272x717.png", "0929-211006|leave-loading|$f29\cap_211006_743_1272x717.png", "0929-211008|leave-loading|$f29\cap_211008_838_1272x717.png", "0929-213312|leave-loading|$f29\cap_213312_745_1272x717.png", "0929-213313|leave-loading|$f29\cap_213313_806_1272x717.png",
  "0929-210549|entry-loading|$f29\cap_210549_055_1272x717.png", "0929-210550|entry-loading|$f29\cap_210550_087_1272x717.png", "0929-210551|entry-loading|$f29\cap_210551_119_1272x717.png", "0929-211239|entry-loading|$f29\cap_211239_838_1272x717.png", "0929-211240|entry-loading|$f29\cap_211240_867_1272x717.png", "0929-211241|entry-loading|$f29\cap_211241_933_1272x717.png", "0929-211605|entry-loading|$f29\cap_211605_774_1272x717.png", "0929-211606|entry-loading|$f29\cap_211606_805_1272x717.png", "0929-211607|entry-loading|$f29\cap_211607_838_1272x717.png", "0929-212038|entry-loading|$f29\cap_212038_525_1272x717.png", "0929-212039|entry-loading|$f29\cap_212039_588_1272x717.png", "0929-212040|entry-loading|$f29\cap_212040_618_1272x717.png", "0929-212947|entry-loading|$f29\cap_212947_775_1272x717.png", "0929-212948|entry-loading|$f29\cap_212948_806_1272x717.png", "0929-212949|entry-loading|$f29\cap_212949_839_1272x717.png", "0921-184843|entry-loading|$p2m\cap_184843_018_1272x717.png", "0921-185237|entry-loading|$p2m\cap_185237_205_1272x717.png",
  "0929-210552|dungeon-arrival|$f29\cap_210552_151_1272x717.png", "0929-211608|dungeon-arrival|$f29\cap_211608_902_1272x717.png", "0929-212950|dungeon-arrival|$f29\cap_212950_869_1272x717.png",
  "0921-185241|entry-misread|$p2m\cap_185241_363_1272x717.png", "0921-185242|entry-misread|$p2m\cap_185242_423_1272x717.png", "0921-185243|entry-misread|$p2m\cap_185243_493_1272x717.png", "0929-211242|entry-misread|$f29\cap_211242_966_1272x717.png",
  "S4|prompt|$p2m\cap_185217_080_1272x717.png", "S7|prompt|$p4m\cap_212537_925_1272x717.png"
)
# 전이 열 재생(아래 2b)이 쓰는 프레임 중 범주 목록 밖의 것 - 보존 캡처가 모두 있어야 재생합니다
$transitionOnly = @("$f29\cap_210519_527_1272x717.png", "$f29\cap_210526_902_1272x717.png", "$f29\cap_210635_996_1272x717.png", "$f29\cap_210638_152_1272x717.png",
  "$f29\cap_211244_025_1272x717.png", "$f29\cap_213319_058_1272x717.png", "$p2m\cap_185245_580_1272x717.png")
foreach ($relPath in @(@($frames | ForEach-Object { $_.Split('|')[2] }) + $transitionOnly)) {
  $framePath = Join-Path $abyssDir $relPath
  if (-not (Test-Path -LiteralPath $framePath)) { "SKIP 보존 캡처가 없어 캡처 재생을 건너뜁니다: $framePath"; if ($fails -gt 0) { exit 1 }; exit 0 }
}
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
$asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
  Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } | Select-Object -First 1
$ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('ko')))
$ocrEnglishEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('en-US')))
if (-not $ocrKoreanEngine -or -not $ocrEnglishEngine) { 'SKIP ko/en-US OCR 엔진을 만들 수 없어 캡처 재생을 건너뜁니다'; if ($fails -gt 0) { exit 1 }; exit 0 }

# 운영 함수는 소스에서 그대로 (OCR 브리지 + 영역 판독 + 판정 + 알려진 화면 + 나가기 헬퍼 + 글자 좌표 탐색 + 퀘스트 보상 닫기)
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Get-GameRegionOcrText',
    'Get-GameOcrText', 'Get-GameRegionOcrWords', 'Test-HomeEndEscHud', 'Test-InDungeonQuest', 'Test-DungeonClearPrompt', 'Get-AbyssPanelKind',
    'Test-AbyssEntryWaiting', 'Test-AbyssMemberReward', 'Test-AbyssSelectionScreen', 'Test-KnownScreen', 'Select-AbyssExitWord',
    'Find-AbyssExitButtonPoint', 'Invoke-AbyssExitClick', 'Find-GameTextPoint', 'Close-QuestRewardScreen')) {
  Invoke-Expression $definition
}
# ⑥e 파티원 순수 판정 (분류·보상 위 판별·재펼침 앵커·나가기 단어·퇴장 전이 표 - 설계 2.1) - 운영 함수 그대로
foreach ($name in @('Resolve-AbyssMemberScreen', 'Test-AbyssPanelOverRewardText', 'Select-AbyssEntryWaitingAnchor', 'Select-AbyssMemberLeaveWord',
    'New-AbyssMemberLeaveTransition', 'Update-AbyssMemberLeaveTransition')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}
# 영역·키워드·좌표·상수는 소스 대입식에서 캡처 (config 미정의 → 기본값)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
foreach ($sourceVar in @('rgClearExit', 'rgAbyssMenu', 'rgPartyEnterBtn', 'rgHomeEndEsc', 'rgQuestTracker', 'rgAbyssCards', 'rgAbyssSelect',
    'rgClearScore', 'rgDgEnterBtn', 'allDungeonKeywords', 'ptMemberPanelCollapse', 'memberFieldSettleSeconds')) {
  $assign = $sourceAst.Find({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq ('$' + $sourceVar)) }, $true)
  if (-not $assign) { "FAIL 본체에서 `$$sourceVar 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $assign.Extent.Text
}
# 게임 창 캡처를 PNG 재생으로 대체 (워커 Get-GameRegionCapture 와 같은 수식 - 창 = 이미지 전체(원점 0,0 = 이미지 픽셀), 확대 HighQualityBicubic).
# ⑥e 설계 5.3 (리뷰 C8): 워커와 같은 모양의 결과(CropLeft/CropTop/CropWidth/CropHeight/ScaledWidth/ScaledHeight/Scale)를 돌려줍니다 - 없으면 Find-GameTextPoint 가
# 좌표 환산에서 NaN 변환 예외. -BinaryWhiteText 도 워커와 같은 이진화(세 채널 모두 175 초과 = 검정, 그 외 흰색 → NearestNeighbor 확대)로 재현합니다 - HUD 판정의
# 두 번째 판독이 이 경로입니다. 이진화는 워커의 GetPixel/SetPixel 루프와 같은 결과를 LockBits 로 빠르게 만듭니다(픽셀 값 판정은 동일)
$script:referenceWidth = 1272; $script:referenceHeight = 717
function Get-GameRegionCapture {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3,
    [switch]$BinaryWhiteText, [switch]$ThrowOnWindowRectFailure)
  $imageW = $script:sourceBitmap.Width; $imageH = $script:sourceBitmap.Height
  $cropLeft = [int][Math]::Round($ReferenceX * $imageW / $script:referenceWidth)
  $cropTop = [int][Math]::Round($ReferenceY * $imageH / $script:referenceHeight)
  $cropW = [Math]::Max(1, [int][Math]::Round($RegionWidth * $imageW / $script:referenceWidth))
  $cropH = [Math]::Max(1, [int][Math]::Round($RegionHeight * $imageH / $script:referenceHeight))
  $crop = New-Object System.Drawing.Bitmap $cropW, $cropH
  $cropGraphics = [System.Drawing.Graphics]::FromImage($crop)
  try {
    $cropGraphics.DrawImage($script:sourceBitmap, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)),
      (New-Object System.Drawing.Rectangle($cropLeft, $cropTop, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
  } finally { $cropGraphics.Dispose() }
  if ($BinaryWhiteText) {
    $lockRect = New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)
    $lockData = $crop.LockBits($lockRect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $pixelBytes = New-Object byte[] ($lockData.Stride * $cropH)
      [System.Runtime.InteropServices.Marshal]::Copy($lockData.Scan0, $pixelBytes, 0, $pixelBytes.Length)
      for ($y = 0; $y -lt $cropH; $y++) {
        $rowStart = $y * $lockData.Stride
        for ($x = 0; $x -lt $cropW; $x++) {
          $i = $rowStart + $x * 4   # BGRA
          $value = $(if ($pixelBytes[$i + 2] -gt 175 -and $pixelBytes[$i + 1] -gt 175 -and $pixelBytes[$i] -gt 175) { 0 } else { 255 })
          $pixelBytes[$i] = $value; $pixelBytes[$i + 1] = $value; $pixelBytes[$i + 2] = $value; $pixelBytes[$i + 3] = 255
        }
      }
      [System.Runtime.InteropServices.Marshal]::Copy($pixelBytes, 0, $lockData.Scan0, $pixelBytes.Length)
    } finally { $crop.UnlockBits($lockData) }
  }
  $scaled = New-Object System.Drawing.Bitmap ($RegionWidth * $Scale), ($RegionHeight * $Scale)
  $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
  try {
    $scaledGraphics.InterpolationMode = $(if ($BinaryWhiteText) { [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor } else { [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic })
    $scaledGraphics.DrawImage($crop, (New-Object System.Drawing.Rectangle(0, 0, ($RegionWidth * $Scale), ($RegionHeight * $Scale))),
      (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
  } finally { $scaledGraphics.Dispose(); $crop.Dispose() }
  return [pscustomobject]@{ Bitmap = $scaled; CropLeft = $cropLeft; CropTop = $cropTop; CropWidth = $cropW; CropHeight = $cropH
    ScaledWidth = ($RegionWidth * $Scale); ScaledHeight = ($RegionHeight * $Scale); Scale = $Scale }
}
# 알려진 화면의 나머지 판정(ESC 메뉴·던전 상세/선택·사냥터)은 이 캡처들과 무관 - 거짓으로 격리해 어비스 등록 줄만 판정하게 함
function Test-AbyssMenu { param($Game) return $false }
function Get-DetailTitleText { param($Game) return '' }
function Read-DgTitleText { param($Game) return '' }
function Test-DgSelectionTitle { param($TitleText) return $false }
function Find-DgRetryButtonPoint { param($Game) return $null }
function Find-HtEntryButtonPoint { param($Game) return $null }
function Find-HtNewMissionPoint { param($Game) return $null }
# 나가기 헬퍼·퀘스트 보상 닫기 주변 모의 (첫 회전에서 끝나는 프레임만 재생 - 클릭은 기록만, 대기는 흘리지 않음)
function Write-RunLog { param($Message) $script:logs += $Message }
function Write-LifeDiagnostics { param($Game, $Context, [switch]$CaptureOnly) $script:diagCalls++ }
function Test-UserRecentlyActive { return $false }
function Focus-Game { param($Game) }
function Test-SafeStopDuringCaptureFail { }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) $script:clicks += "$ReferenceX,$ReferenceY"; $script:lastClickPerformed = $true; $script:lastClickSkipReason = '' }
function Click-ScreenPoint { param($X, $Y) $script:clicks += "screen:$X,$Y"; $script:lastClickPerformed = $true; $script:lastClickSkipReason = '' }
$script:screenCaptureFailing = $false; $script:captureFailSerial = 0; $script:userYieldTotalMs = [double]0; $script:diagCalls = 0
# '고치기 전' 판정 (재현용): 선택 화면 배제는 재매칭 패널만, 알려진 화면은 3버튼 + 재매칭 패널만 - 운영 소스를 텍스트 치환해 만듭니다
$selectionBefore = ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-AbyssSelectionScreen'))) -replace 'function Test-AbyssSelectionScreen', 'function Test-AbyssSelectionScreenBefore' `
  -replace "if \(\`$panelKindNow -ne 'none'\) \{ return \`$false \}", "if (`$panelKindNow -eq 'matching') { return `$false }" -replace 'if \(\$entryWaitingNow\) \{ return \$false \}', ''
$knownBefore = ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-KnownScreen'))) -replace 'function Test-KnownScreen', 'function Test-KnownScreenBefore' `
  -replace 'Test-AbyssSelectionScreen -Game', 'Test-AbyssSelectionScreenBefore -Game' `
  -replace '\(Test-AbyssMemberRewardText -Text \$bottomText\) -or', '' -replace '\(Test-AbyssEntryWaitingText -Text \$bottomText\) -or \(Test-AbyssFewMembersPopupText -Text \$bottomText\)', '$false' `
  -replace "\(Get-AbyssPanelKind -Game \`$Game\) -ne 'none'", "(Get-AbyssPanelKind -Game `$Game) -eq 'matching'"
Check-Equal '재현 준비: 고치기 전 판정 두 개를 소스 치환으로 만들었음 (치환이 빠지면 재현이 무의미)' (($selectionBefore -match "-eq 'matching'\) \{ return") -and ($knownBefore -notmatch 'Test-AbyssMemberRewardText') -and ($knownBefore -match "-eq 'matching'\) \{ return")) $true
Invoke-Expression $selectionBefore
Invoke-Expression $knownBefore

# 한 프레임의 파티원 분류 입력 (D·P 의 ④ 판독 순서 그대로: S → 하단(스태시) → 패널 → HUD → 추적기(HUD 참일 때만) → 버튼(준비 패널일 때만)) → Resolve-AbyssMemberScreen
function Get-MemberSample {
  $promptNow = Test-DungeonClearPrompt -Game $null
  $bottomText = ([string]$script:lastClearPromptText) -replace '\s', ''
  $panelNow = Get-AbyssPanelKind -Game $null
  $hudNow = Test-HomeEndEscHud -Game $null
  $questNow = $(if ($hudNow) { Test-InDungeonQuest -Game $null } else { $false })
  $buttonNow = 'none'
  if ($panelNow -eq 'ready') {
    $buttonText = (Get-GameRegionOcrText -Game $null -ReferenceX $rgPartyEnterBtn[0] -ReferenceY $rgPartyEnterBtn[1] -RegionWidth $rgPartyEnterBtn[2] -RegionHeight $rgPartyEnterBtn[3] -Scale 4 -Engine $ocrKoreanEngine) -replace '\s', ''
    $buttonNow = Get-AbyssReadyButtonState -Text $buttonText
  }
  $screenNow = Resolve-AbyssMemberScreen -PromptVisible $promptNow -BottomText $bottomText -PanelKind $panelNow -HudVisible $hudNow -InDungeonQuest $questNow -ButtonState $buttonNow
  return @{ Prompt = $promptNow; Bottom = $bottomText; Panel = $panelNow; Hud = $hudNow; Quest = $questNow; Button = $buttonNow; Screen = $screenNow }
}
function Load-Frame { param([string]$RelPath)
  if ($script:sourceBitmap) { $script:sourceBitmap.Dispose() }
  $script:sourceBitmap = [System.Drawing.Bitmap]::FromFile((Join-Path $abyssDir $RelPath))
}
$sampleCache = @{}
$stats = @{}
$kindCounts = @{}
function Add-Stat { param([string]$Key, [bool]$Ok) if (-not $stats.ContainsKey($Key)) { $stats[$Key] = @{ Ok = 0; All = 0; Bad = @() } }; $stats[$Key].All++; if ($Ok) { $stats[$Key].Ok++ } else { $stats[$Key].Bad += $script:frameLabel } }
# 기존 범주(⑥a)와 헬퍼·알려진 화면을 보는 범주만 무거운 판정 묶음(접힌 패널·파티원 보상 게임 상태·선택 화면·알려진 화면)을 돌립니다 (재생 시간)
$legacyKinds = @('ready', 'entry', 'member', 'popup', 'popup-drop', 'reward3', 'matching', 'overlay', 'inside', 'field', 'prompt', 'entry-occluded', 'item-popup')
$fieldOverReward = @('L1', 'M1', 'B3', 'E1')   # 기존 준비 패널 15장 중 필드·상세 위 4장 (나머지 11장은 보상 위 - ⑥e 설계 5.3)
foreach ($entryLine in $frames) {
  $parts = $entryLine.Split('|'); $script:frameLabel = $parts[0]; $kind = $parts[1]
  $kindCounts[$kind] = [int]$kindCounts[$kind] + 1
  Load-Frame $parts[2]
  $sample = Get-MemberSample
  $sampleCache[$parts[2]] = $sample
  $panelKind = $sample.Panel
  $bottomNow = $sample.Bottom
  $sigHits = @((Test-AbyssRewardText -Text $bottomNow), (Test-AbyssMemberRewardText -Text $bottomNow), (Test-AbyssEntryWaitingText -Text $bottomNow), (Test-AbyssFewMembersPopupText -Text $bottomNow)) | Where-Object { $_ }
  $sigNone = (@($sigHits).Count -eq 0)
  $overNow = Test-AbyssPanelOverRewardText -Text $bottomNow
  if ($legacyKinds -contains $kind) {
    $entryNow = Test-AbyssEntryWaiting -Game $null
    $memberNow = Test-AbyssMemberRewardText -Text $bottomNow   # 하단 서명만 (알려진 화면 등록과 같은 판정)
    $memberScreenNow = Test-AbyssMemberReward -Game $null     # 게임 상태 판정 (서명 + 패널 없음 + HUD 없음 - 파티원 분류의 member-reward 조건, 설계 4.1)
    $popupNow = Test-AbyssFewMembersPopupText -Text $bottomNow
    $selectionNow = Test-AbyssSelectionScreen -Game $null
    $knownNow = Test-KnownScreen -Game $null
  }
  switch ($kind) {
    'ready' {
      Add-Stat '준비 패널 → 패널 종류 ready' ($panelKind -eq 'ready')
      Add-Stat '준비 패널 → 선택 화면 거짓 (배제)' (-not $selectionNow)
      Add-Stat '준비 패널 → 고치기 전 선택 화면 참 (오판 재현)' (Test-AbyssSelectionScreenBefore -Game $null)
      Add-Stat '준비 패널 → 알려진 화면 참' $knownNow
      Add-Stat '준비 패널 → 접힌 패널·파티원 보상(서명·게임 상태)·팝업 거짓' (-not ($entryNow -or $memberNow -or $memberScreenNow -or $popupNow))
      $btnExpect = $(if (@('M1', 'M2', 'M2+1', 'M4-pre2', 'M5-1', 'B1', 'B3', '0929-211602', '0929-212407', '0929-212408', '0929-211944', '0929-211945', '0929-211947', '0929-212032', '0929-212939') -contains $script:frameLabel) { 'ready-available' } else { 'ready-done' })   # 파티원 미준비 = 준비 완료 / 파티장·누른 뒤 = 준비 취소
      Add-Stat '준비 패널 → 버튼 상태 (파티원 미준비 ready-available / 파티장·누른 뒤 ready-done)' ($sample.Button -eq $btnExpect)
      # ⑥e 설계 ㉵: 보상 위 판별(하단 안내문 '누르면'·'정보를') - P 의 접기 클릭은 참일 때만. 보상 위 19장 참, 필드·상세 위 4장 거짓
      Add-Stat '준비 패널 → 보상 위 판별 (보상 위 참 · 필드·상세 위 거짓)' ($overNow -eq (-not ($fieldOverReward -contains $script:frameLabel)))
      if (@('0929-211944', '0929-211945', '0929-212032', '0929-212939') -contains $script:frameLabel) {
        # 보상 위 펼친 패널의 패널 밖 '나가기'@(492,654) = P 의 접기 좌표 ($ptMemberPanelCollapse - 소스 값)
        $collapseWord = Select-AbyssExitWord -Words @(Get-GameRegionOcrWords -Game $null -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -Scale 3 -Engine $ocrKoreanEngine)
        Add-Stat "준비 패널(09-29 '나가기' 공존 4장) → '나가기' 위치 = 접기 좌표 ptMemberPanelCollapse" (($null -ne $collapseWord) -and ("$($collapseWord.X),$($collapseWord.Y)" -eq ($ptMemberPanelCollapse -join ',')))
      }
      $script:clicks = @(); $script:logs = @()
      $helper = Invoke-AbyssExitClick -Game $null -LogPrefix '[재생]' -Context '나가기 클릭'
      Add-Stat "준비 패널 → 나가기 헬퍼 ready-panel, 클릭 0" (($helper.Result -eq 'ready-panel') -and ($script:clicks.Count -eq 0))
    }
    'ready-field' {
      # 필드 위 준비 패널 (⑥e 설계 5.3): 보상 위 판별 거짓이라 P 는 접지 않음(필드 위 그 자리 클릭은 미관측 - 규칙 8). 210545 는 버튼 '주년`완료' 로 준비 상태 미확인
      Add-Stat '필드 위 준비 패널 → 패널 ready, HUD 거짓, 보상 위 거짓' (($panelKind -eq 'ready') -and (-not $sample.Hud) -and (-not $overNow))
      $classExpect = $(if ($script:frameLabel -eq '0929-210545') { 'ready-other' } else { 'ready-available' })
      Add-Stat '필드 위 준비 패널 → 분류 ready-available 3 · ready-other 1(0929-210545)' ($sample.Screen -eq $classExpect)
    }
    'entry' {
      Add-Stat '접힌 패널 → 판정 참, 패널 종류 none' ($entryNow -and $panelKind -eq 'none')
      Add-Stat '접힌 패널 → 선택 화면 거짓·알려진 화면 참' ((-not $selectionNow) -and $knownNow)
      Add-Stat '접힌 패널 → 고치기 전 알려진 화면 거짓 (이벤트 정리 헛클릭 재현)' (-not (Test-KnownScreenBefore -Game $null))
      Add-Stat '접힌 패널 → 분류 entry-waiting' ($sample.Screen -eq 'entry-waiting')
      if ($script:frameLabel -like '0929-*') {
        # 재펼침 앵커 (⑥e 설계 2.7 - 결정 ⑵): '입장 대기 중' 의 '대기' 단어 (743,654) 7/7 - 고정 좌표 폴백 없음
        $anchorNow = Select-AbyssEntryWaitingAnchor -Words @(Get-GameRegionOcrWords -Game $null -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -Scale 3 -Engine $ocrKoreanEngine)
        Add-Stat '접힌 패널(09-29) → 재펼침 앵커 (743,654)' (($null -ne $anchorNow) -and ("$($anchorNow.X),$($anchorNow.Y)" -eq '743,654'))
      }
      $script:clicks = @(); $script:logs = @()
      $helper = Invoke-AbyssExitClick -Game $null -LogPrefix '[재생]' -Context '나가기 클릭'
      Add-Stat "접힌 패널 → 나가기 헬퍼 entry-waiting, 클릭 0 ('나가기' = 던전 퇴장)" (($helper.Result -eq 'entry-waiting') -and ($script:clicks.Count -eq 0))
    }
    'member' {
      Add-Stat '파티원 보상 → 판정 참, 3버튼 거짓, 패널 none, 접힌 패널 거짓' ($memberNow -and (-not (Test-AbyssRewardText -Text $bottomNow)) -and $panelKind -eq 'none' -and (-not $entryNow))
      Add-Stat '파티원 보상 → 게임 상태 판정(서명+패널 없음+HUD 없음) 참, 분류 member-reward' ($memberScreenNow -and $sample.Screen -eq 'member-reward')
      Add-Stat '파티원 보상 → 알려진 화면 참 / 고치기 전 거짓 (재현)' ($knownNow -and (-not (Test-KnownScreenBefore -Game $null)))
      # 재펼침 앵커 선택자는 보상 '파티장 선택 대기' 의 '대기'@808 를 고르지 않음 (파티원 보상 서명이면 null - 설계 2.7)
      $anchorNow = Select-AbyssEntryWaitingAnchor -Words @(Get-GameRegionOcrWords -Game $null -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -Scale 3 -Engine $ocrKoreanEngine)
      Add-Stat '파티원 보상 → 재펼침 앵커 선택자 null' ($null -eq $anchorNow)
      $script:clicks = @(); $script:logs = @()
      $helper = Invoke-AbyssExitClick -Game $null -LogPrefix '[재생]' -Context '나가기 클릭'
      Add-Stat "파티원 보상 → 나가기 헬퍼 clicked @(515,654)" (($helper.Result -eq 'clicked') -and (($script:clicks -join ';') -eq '515,654'))
    }
    'entry-occluded' {
      # 커서가 '입장' 을 가린 접힌 패널 (09-29 '…입장대가축' / '…입장[중'): 서명 넷 거짓 → 분류 unknown, 앵커·나가기 선택자 null. 현행 나가기 헬퍼는
      # 이 프레임에서 (492,654) = 던전 퇴장을 누릅니다(기록 단언 - D·P 가 그 헬퍼를 쓰지 않는 이유, 설계 2.7)
      $wordsNow = @(Get-GameRegionOcrWords -Game $null -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -Scale 3 -Engine $ocrKoreanEngine)
      Add-Stat '가린 접힌 패널 → 서명 넷 거짓, 알려진 화면 거짓, 분류 unknown' ($sigNone -and (-not $knownNow) -and $sample.Screen -eq 'unknown')
      Add-Stat '가린 접힌 패널 → 재펼침 앵커·나가기 단어(보상·접힘 기대) 선택자 모두 null' (($null -eq (Select-AbyssEntryWaitingAnchor -Words $wordsNow)) -and ($null -eq (Select-AbyssMemberLeaveWord -Words $wordsNow -Expect 'member-reward')) -and ($null -eq (Select-AbyssMemberLeaveWord -Words $wordsNow -Expect 'entry-waiting')))
      $script:clicks = @(); $script:logs = @()
      $helper = Invoke-AbyssExitClick -Game $null -LogPrefix '[재생]' -Context '나가기 클릭'
      Add-Stat "가린 접힌 패널 → (기록) 현행 나가기 헬퍼는 (492,654) 던전 퇴장을 누름" (($helper.Result -eq 'clicked') -and (($script:clicks -join ';') -eq '492,654'))
    }
    'item-popup' {
      # 아이템 획득 확인 팝업 (09-29 '…Space확인'): 서명 넷 거짓, 퀘스트 보상 닫기가 '확인'(634,642) 클릭. 나가기 헬퍼는 돌리지 않음(미검출 20초 exit 4)
      $script:clicks = @(); $script:logs = @()
      $rewardClosed = Close-QuestRewardScreen -Game $null -LogPrefix '[재생] '
      Add-Stat "아이템 확인 팝업 → 서명 넷 거짓, 퀘스트 보상 닫기 참 → '확인' (634,642)" ($sigNone -and $rewardClosed -and (($script:clicks -join ';') -eq 'screen:634,642'))
    }
    'popup' {
      Add-Stat '권장 인원 팝업 → 판정 참, 3버튼 거짓' ($popupNow -and (-not (Test-AbyssRewardText -Text $bottomNow)))
      Add-Stat '권장 인원 팝업 → 알려진 화면 참 / 고치기 전 거짓 (재현 - V4-P2-3)' ($knownNow -and (-not (Test-KnownScreenBefore -Game $null)))
    }
    'popup-drop' { Add-Stat "팝업 '도' 탈락 프레임 → 팝업 판정 거짓 (설계 대로 - 다음 판독에 맡김)" (-not $popupNow) }
    'reward3' {
      Add-Stat '3버튼 보상 → 3버튼 참, 파티원·접힌·팝업 거짓, 패널 none (불변)' ((Test-AbyssRewardText -Text $bottomNow) -and (-not ($memberNow -or $entryNow -or $popupNow)) -and $panelKind -eq 'none')
      $script:clicks = @(); $script:logs = @()
      $helper = Invoke-AbyssExitClick -Game $null -LogPrefix '[재생]' -Context '나가기 클릭'
      Add-Stat "3버튼 보상 → 나가기 헬퍼 clicked @(475,654) (불변)" (($helper.Result -eq 'clicked') -and (($script:clicks -join ';') -eq '475,654'))
    }
    'matching' {
      Add-Stat '재매칭 패널 → 패널 종류 matching (불변), 선택 화면 거짓' ($panelKind -eq 'matching' -and (-not $selectionNow))
      $script:clicks = @(); $script:logs = @()
      $helper = Invoke-AbyssExitClick -Game $null -LogPrefix '[재생]' -Context '나가기 클릭'
      Add-Stat '재매칭 패널 → 나가기 헬퍼 matching, 클릭 0 (불변)' (($helper.Result -eq 'matching') -and ($script:clicks.Count -eq 0))
    }
    'member-matching' {
      # 파티원 쪽 재매칭 패널 (09-21 22장): 토글 ON 자동 입장은 커밋 화면(재매칭)을 드러낸다는 연속 조건 전제의 근거 - HUD 가 보여도 순위 3 이 field 보다 먼저
      Add-Stat '파티원 재매칭 패널 → 패널 matching, 분류 matching (HUD 참 184838·184841 포함)' (($panelKind -eq 'matching') -and $sample.Screen -eq 'matching')
    }
    'overlay' {
      Add-Stat '선택 화면 오버레이 → 선택 화면 참 (배제 확장 뒤에도 불변), 패널 none' ($selectionNow -and $panelKind -eq 'none' -and (-not $entryNow))
      # ⑥e 설계 2.14 (09-30 리뷰5 P1-1): 던전 안 오버레이 두 장에서 헬퍼는 'selection' - 선택 화면 양성은 던전 밖의 증명이 아니라 누르지 않고 넘김
      # (고치기 전 헬퍼는 두 장 모두 하단 '' · 선택 화면 참 · HUD 거짓으로 'gone' = 복귀 완료 쪽으로 넘겼음)
      $script:clicks = @(); $script:logs = @()
      $helper = Invoke-AbyssExitClick -Game $null -LogPrefix '[재생]' -Context '나가기 클릭'
      $selectionLogs = @($script:logs | Where-Object { $_ -match '워커가 연 화면인지 알 수 없어' }).Count
      Add-Stat "선택 화면 오버레이 → 나가기 헬퍼 selection, 클릭 0, 안내 로그 1 (gone 아님)" (($helper.Result -eq 'selection') -and ($script:clicks.Count -eq 0) -and ($selectionLogs -eq 1))
    }
    'inside' { Add-Stat '던전 안(실사고 X1·X2) → HUD 참 + 추적기 참, 패널·보상 서명 거짓' ((Test-HomeEndEscHud -Game $null) -and (Test-InDungeonQuest -Game $null) -and $panelKind -eq 'none' -and (-not ($memberNow -or $entryNow))) }
    'inside-misread' {
      # 던전 안인데 추적기가 '정박' 을 놓친 오독(09-29 - 보스 이펙트): HUD 참·추적기 거짓 → 분류 field (관측 5 재현 - 'left' 근거가 되면 안 되는 입력).
      # 이 단언이 깨지면(엔진이 '정박' 을 읽게 됨) 재현이 사라진 것이므로 기록만 고칩니다 - 퇴장 전이의 방어는 모의 판독문으로 계속 지킵니다
      Add-Stat '던전 안 추적기 오독 → HUD 참, 추적기 거짓, 분류 field (오독 재현)' ($sample.Hud -and (-not $sample.Quest) -and $sample.Screen -eq 'field')
    }
    'inside-cutscene' { Add-Stat '던전 안 컷신 → 하단 ""·패널 none·HUD 거짓, 분류 unknown' (($bottomNow -eq '') -and $panelKind -eq 'none' -and (-not $sample.Hud) -and $sample.Screen -eq 'unknown') }
    'field' {
      Add-Stat '필드 → HUD 참 + 추적기 거짓, 패널·보상 서명·파티원 보상 게임 상태 거짓' ((Test-HomeEndEscHud -Game $null) -and (-not (Test-InDungeonQuest -Game $null)) -and $panelKind -eq 'none' -and (-not ($memberNow -or $memberScreenNow -or $entryNow -or $popupNow)))
      Add-Stat '필드 → 분류 field' ($sample.Screen -eq 'field')
    }
    'field-arrival' { Add-Stat '필드 도착 직후(HUD 글자 미표시) → HUD 거짓, 분류 unknown (도착 프레임은 떠남 쪽)' ((-not $sample.Hud) -and $sample.Screen -eq 'unknown') }
    'leave-loading' { Add-Stat '퇴장 로딩 → HUD 거짓, 하단 "", 패널 none, 서명 넷 거짓, 분류 unknown (떠남 표본)' ((-not $sample.Hud) -and ($bottomNow -eq '') -and $panelKind -eq 'none' -and $sigNone -and $sample.Screen -eq 'unknown') }
    'entry-loading' { Add-Stat '입장 로딩 → HUD 거짓, 패널 none, 분류 unknown (무장 없이는 떠남이 아님)' ((-not $sample.Hud) -and $panelKind -eq 'none' -and $sample.Screen -eq 'unknown') }
    'dungeon-arrival' { Add-Stat '던전 도착 → HUD 거짓, 분류 unknown' ((-not $sample.Hud) -and $sample.Screen -eq 'unknown') }
    'entry-misread' {
      # 입장 직후 추적기 제목 반짝임(09-21 3프레임·09-29 1프레임): HUD 참·추적기 거짓 → 분류 field (입장 과도 - W 안에 'stayed-field' 가 나오면 안 되는 입력.
      # 복귀 루프 필드 확정(W)의 판독 근거이기도 함 - test_abyss_return_loop RLP8 의 'fieldMisread')
      Add-Stat '입장 과도 추적기 오독 → HUD 참, 추적기 거짓, 분류 field' ($sample.Hud -and (-not $sample.Quest) -and $sample.Screen -eq 'field')
    }
    'prompt' { Add-Stat "클리어 S → 클리어 판정 참, HUD·추적기 '' (거짓), 알려진 화면 참" ((Test-DungeonClearPrompt -Game $null) -and (-not (Test-HomeEndEscHud -Game $null)) -and (-not (Test-InDungeonQuest -Game $null)) -and $knownNow) }
  }
}

# ── 2b. 전이 열 재생 (⑥e 설계 5.3 - 리뷰 의견 '캡처·배선 통합 테스트 병행 필수') ─────────────────────────────
# 운영 판독 → Resolve-AbyssMemberScreen → P 본문과 같은 거름(⑨ 커밋 화면 ready-done·matching·inside 면 'committed', ⑩ 즉시 반환 prompt·reward3 면 그 결과) →
# Update-AbyssMemberLeaveTransition. -Now 는 파일 이름의 시각(09-21·09-29 날짜). 'left'(필드 확인)는 끊김 없이 관측된 퇴장 전이로만 나와야 합니다 -
# 던전 안 추적기 오독·입장 과도도 HUD + 추적기 없음이라 필드의 증거가 못 됩니다 (리뷰1 P1-1)
function Get-FrameTime { param([string]$RelPath)
  $day = $(if ($RelPath -like '20260921*') { '2026-09-21' } else { '2026-09-29' })
  $m = [regex]::Match($RelPath, 'cap_(\d{2})(\d{2})(\d{2})_(\d{3})')
  return [datetime]::ParseExact(('{0} {1}:{2}:{3}.{4}' -f $day, $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value, $m.Groups[4].Value), 'yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture)
}
function Invoke-TransitionReplay { param([object[]]$Steps)
  $transition = New-AbyssMemberLeaveTransition
  $verdicts = @(); $result = ''; $now = Get-FrameTime ([string]@($Steps | Where-Object { $_ -notlike 'event:*' })[0])
  foreach ($step in $Steps) {
    if ($step -like 'event:*') {
      [void](Update-AbyssMemberLeaveTransition -Transition $transition -Event $step.Substring(6) -Now $now -SettleSeconds $memberFieldSettleSeconds)
      continue
    }
    if (-not $sampleCache.ContainsKey($step)) { Load-Frame $step; $sampleCache[$step] = Get-MemberSample }
    $screen = [string]$sampleCache[$step].Screen; $now = Get-FrameTime $step
    if ($screen -eq 'ready-done' -or $screen -eq 'matching' -or $screen -eq 'inside') { $result = 'committed'; break }   # P ⑨ 커밋
    if ($screen -eq 'prompt' -or $screen -eq 'reward3') { $result = $screen; break }                                       # P ⑩ 즉시 반환
    $verdict = Update-AbyssMemberLeaveTransition -Transition $transition -Event 'sample' -Screen $screen -Now $now -SettleSeconds $memberFieldSettleSeconds
    $verdicts += $(if ($verdict) { $verdict } else { '-' })
    if ($verdict -eq 'left' -or $verdict -eq 'stayed-field') { $result = $verdict; break }                                  # P ⑪ 성공 판정
  }
  return @{ Result = $result; Verdicts = ($verdicts -join ','); Stage = [string]$transition.Stage; DepartSamples = [int]$transition.DepartSamples }
}
function F29 { param([string]$Id) "$f29\cap_${Id}_1272x717.png" }
function F21 { param([string]$Id) "$p2m\cap_${Id}_1272x717.png" }
$entry0921 = @((F21 '185237_205'), (F21 '185241_363'), (F21 '185242_423'), (F21 '185243_493'), (F21 '185245_580'))   # 09-21 입장: 로딩 → 입장 과도(필드 오독 3) → 던전 안
# (가) 1판: 보상 → 나가기 전송 → 퇴장 로딩 3장 → 필드 2장 = 'left' (떠남 표본 3)
$rA = Invoke-TransitionReplay @((F29 '210519_527'), 'event:leave-sent', (F29 '210521_682'), (F29 '210522_744'), (F29 '210523_776'), (F29 '210525_840'), (F29 '210526_902'))
Check-Equal "전이 재생(가) 1판: 보상 → 나가기 → 로딩 3 → 필드 2 = left, 떠남 표본 3" ("$($rA.Result)/$($rA.DepartSamples)") 'left/3'
# (나) 전송 없이 던전 안 오독 교대: 필드 모양 → 던전 안 = committed ('stayed-field'·'left' 아님 - W 미달에서 inside), 같은 모양 두 번
$rB1 = Invoke-TransitionReplay @((F29 '210634_932'), (F29 '210635_996'))
$rB2 = Invoke-TransitionReplay @((F29 '210637_089'), (F29 '210638_152'))
Check-Equal "전이 재생(나) 전송 없는 던전 안 오독 교대 ×2: committed, 판정 표본에 left·stayed-field 없음" ("$($rB1.Result)/$($rB2.Result)/$([int](($rB1.Verdicts + $rB2.Verdicts) -match 'left|stayed'))") 'committed/committed/0'
# (다) 나가기 전송 → 오독 2장(로딩 없음): 판정 없음, 무장 유지(Stage sent) - 떠남 없는 필드 모양은 세지 않음
$rC = Invoke-TransitionReplay @('event:leave-sent', (F29 '210634_932'), (F29 '210637_089'))
Check-Equal "전이 재생(다) 나가기 → 오독 2장(로딩 없음): 판정 없음, Stage sent" ("$($rC.Result)|$($rC.Stage)") '|sent'
# (라) 6판: 나가기 → 로딩 2장 → 필드 도착(HUD 미표시 - 떠남 쪽) → 필드 2장 = 'left' (떠남 표본 3)
$rD = Invoke-TransitionReplay @('event:leave-sent', (F29 '213312_745'), (F29 '213313_806'), (F29 '213316_932'), (F29 '213317_997'), (F29 '213319_058'))
Check-Equal "전이 재생(라) 6판: 나가기 → 로딩 2 → 도착 → 필드 2 = left, 떠남 표본 3" ("$($rD.Result)/$($rD.DepartSamples)") 'left/3'
# (마)(아)(자) 무장·떠남 뒤 끊김(양보·동결 'interrupt' / 스윕 참 회전 'sweep' / 재펼침 탐침 전송 'probe-sent')이 무장을 풀어, 그 사이의 입장(로딩 → 입장 과도 →
# 던전 안)은 'left' 가 되지 않고 committed (리뷰1 P1-1 반례 · 리뷰2 P1-1 · 리뷰3 P1-1 - 과도 3프레임이라 옛 계약이면 185242_423 에서 left)
$rE = Invoke-TransitionReplay (@('event:leave-sent', (F29 '210521_682'), 'event:interrupt') + $entry0921)
$rH = Invoke-TransitionReplay (@('event:leave-sent', (F29 '210521_682'), 'event:sweep') + $entry0921)
$rI = Invoke-TransitionReplay (@('event:leave-sent', (F29 '212409_212'), 'event:probe-sent') + $entry0921)
Check-Equal "전이 재생(마) 나가기 → 로딩 → 끊김(interrupt) → 09-21 입장: committed, 그 사이 left 0" ("$($rE.Result)/$([int]($rE.Verdicts -match 'left'))") 'committed/0'
Check-Equal "전이 재생(아) 나가기 → 로딩 → 스윕 참 회전(sweep) → 09-21 입장: committed, 그 사이 left 0" ("$($rH.Result)/$([int]($rH.Verdicts -match 'left'))") 'committed/0'
Check-Equal "전이 재생(자) 나가기 → 접힌 패널(무장 유지) → 재펼침 탐침 전송(probe-sent) → 09-21 입장: committed, 그 사이 left 0" ("$($rI.Result)/$([int]($rI.Verdicts -match 'left'))") 'committed/0'
# (바)(사) 전송 없이 입장 (09-21 · 09-29 3판): 입장 과도 2.1초 < W - 'stayed-field' 없이 committed
$rF = Invoke-TransitionReplay $entry0921
$rG = Invoke-TransitionReplay @((F29 '211239_838'), (F29 '211240_867'), (F29 '211241_933'), (F29 '211242_966'), (F29 '211244_025'))
Check-Equal "전이 재생(바)(사) 전송 없는 입장 09-21·09-29: committed, stayed-field 0" ("$($rF.Result)/$($rG.Result)/$([int](($rF.Verdicts + $rG.Verdicts) -match 'stayed'))") 'committed/committed/0'
if ($script:sourceBitmap) { $script:sourceBitmap.Dispose() }

foreach ($key in ($stats.Keys | Sort-Object)) {
  $s = $stats[$key]
  $badNote = $(if ($s.Bad.Count -gt 0) { ' / 불일치: ' + ($s.Bad -join ',') } else { '' })
  Check-Equal ("$key ($($s.Ok)/$($s.All)$badNote)") $s.Ok $s.All
}
$coverage = @('준비 패널 → 패널 종류 ready', '접힌 패널 → 판정 참, 패널 종류 none', '파티원 보상 → 판정 참, 3버튼 거짓, 패널 none, 접힌 패널 거짓', '권장 인원 팝업 → 판정 참, 3버튼 거짓') |
  ForEach-Object { if ($stats.ContainsKey($_)) { $stats[$_].All } else { 0 } }
# ⑥e 설계 5.3: 준비 패널 15+8 · 접힌 패널 3+7 · 파티원 보상 5+3 · 팝업 5
Check-Equal '재생 범위: 준비 패널 23 · 접힌 패널 10 · 파티원 보상 8 · 팝업 5 프레임을 모두 거침' ($coverage -join '/') '23/10/8/5'
$newKinds = @('ready-field', 'entry-occluded', 'item-popup', 'leave-loading', 'field-arrival', 'inside-misread', 'field', 'entry-loading', 'dungeon-arrival', 'entry-misread', 'inside-cutscene', 'member-matching')
Check-Equal '재생 범위(⑥e 새 범주): 필드 위 준비 4 · 가린 접힘 2 · 아이템 확인 1 · 퇴장 로딩 8 · 필드 도착 2 · 던전 안 오독 5 · 필드 6 · 입장 로딩 17 · 던전 도착 3 · 입장 과도 4 · 컷신 5 · 파티원 재매칭 22' (($newKinds | ForEach-Object { [int]$kindCounts[$_] }) -join '/') '4/2/1/8/2/5/6/17/3/4/5/22'
Check-Equal '재생 중 나가기 헬퍼 진단 캡처(미검출 정지) 0회' $script:diagCalls 0

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
