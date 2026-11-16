# 컨트롤 패널 다크 모드 회귀 테스트 (2026-11-12 다크 모드 - 설계 v3 3.1: 하네스 준비 · T1~T16 · G1~G11 / 11-13 잠긴 글자 덧그리기: T17 · G12 /
#   11-14 다크 입력 칸 통일: T18 · G13 / 11-14 장치가 사이의 서브클래스를 건너뛰는 문제(설계 7.14): T18g · 문지기 사슬 행 · G13 갱신)
# 본체: mabinogi_gui.ps1 - 팔레트 두 벌(Get-HoneyPaletteTable · Set-HoneyPalette) · 저장값 읽기(ConvertTo-UiTheme) · 해/달 아이콘(생성 · 배치 · 그리기 · 단장) ·
#   전환 트랜잭션(Invoke-ThemeSwitch) · 공용 갱신(Invoke-HoneyThemeRefresh) · 복원 상태(Get-ThemeRestoreState · Restore-ThemeState) · 상태줄 색 층 ·
#   배지 시작 잔상 · 제목줄(DWM 속성 20 래퍼) · ui.theme 저장(Save-UiThemeState) · 리스트 행 색 · 대분류 아이콘 키 ·
#   대기 중 잠긴 평면 버튼의 글자 덧그리기(Test-LockedTextOverdraw · Invoke-LockedTextPaint · Update-LockedTextRepaint - 사용자 결정 '흐린 회색 글자로') ·
#   다크 입력 칸 통일(장치 HoneyInputRecolor 의 C# 원문 Get-InputRecolorTypeSource · 대상 찾기 · 색 대응 · 장치 만들기 · 켜고 끄기 Update-InputRecolor(갱신 8a) ·
#   보관된 경고 기록 Write-InputRecolorWarning(갱신 12) · 그리기 고장 알림 - 사용자 결정 '숫자 · 시간 · 목록 칸을 같은 색으로, 잠겨도 같은 색').
# 기대값은 고정 리터럴입니다(설계 H11): 소스에서 캡처하면 라이트 값이 바뀌어도 기대가 따라가 '라이트는 지금과 픽셀까지 같다'(계약 L)를 지키지 못합니다.
#   예외는 T8 f6 하나 - 같은 소스의 두 함수(Update-LogTabBadge · Get-LogBadgeTextColor)가 같은 색을 내는지 실행으로 대조합니다.
# 실행 경계: 함수는 소스에서 그대로 꺼내 정의하고(source_test_helpers.ps1), 최상위 문장은 AST 로 잘라 점소싱합니다(규칙 3). 원문 단언은 주석 뺀 사본으로 합니다.
# 스텁은 그것을 쓰는 도우미 함수의 지역에 둡니다 - PowerShell 은 동적 범위라 그 도우미 안에서 부르는 제품 함수와 이벤트 처리기가 지역 스텁을 찾습니다
#   (11-12 실측: 함수 안에서 일으킨 ForeColorChanged 처리기도 그 함수의 지역 스텁을 봄). 그래서 한 행의 스텁이 다른 행으로 새지 않습니다.
# 11-13 리뷰 반영(통과만 하고 지키지 못하던 곳): 하네스 준비 자식의 그리기 직전 표지 · T7 표 4개(서로 다른 객체) · T11 대분류 Paint 배선 실행 ·
#   T14 해/달 모양(가운데 · 광선 끝 화소) · G7 패널 갱신 → 기타 카드 선택 모양 배선. 각 행은 그 계약을 깬 변이로 실패하는 것을 확인했습니다.
# 11-13 추가(잠긴 글자 + 내부 검토가 찾은 공백 넷): T17 판정 진리표 · 처리기 예외 경계 · 실제 컨트롤 여섯의 그림 · 다시 그리기, G12 그 배선(목록 · 등록 · Set-UiRunning) /
#   T8 '그림'(폼 그림이 자식 컨트롤까지 담는지) · T8 i(다크에서 누른 토글) · T8 j(랜덤 토글 넷의 의미가 서로 다를 때) · T14 해/달 Paint 첫 예외 계약.
#   이 행들도 그 계약을 깬 변이(판정의 세 항 · 덧그리는 색 · 목록 · Set-UiRunning 호출 · 첫 예외 조건 · 원인 대입 · 눌린 글자 리터럴 · 복원 상태의 토글 ·
#   하네스 핸들 만들기)로 실패하는 것을 확인했고, 공백 넷의 변이는 추가 전 테스트에서 통과하던 것도 확인했습니다.
# 11-13 잠긴 글자 행 리뷰 반영(통과만 하고 지키지 못하던 곳 넷 · 근거 없이 고정하던 곳 하나): T17 하네스의 여섯 컨트롤을 제품의 생성 문장 · 속성 대입문 그대로 만듦
#   (손으로 만든 복제본이라 '랜덤' 의 글자 배치 대입을 바꿔도 통과했음) · T17 다시 그리기를 잠긴 채 실행 중 · 대기 두 상태로(실행 중에는 다시 그리지 않게 바꿔도 통과했음) ·
#   G12 덧그리기의 인자 여섯과 정렬 플래그(그리는 사각형을 Paint 의 다시 그릴 사각형으로 바꿔도 통과했음) · G12 순서에서 해/달 아이콘 항을 빼고(블록을 아이콘 앞으로
#   옮기는 동작이 같은 정리가 실패했음) '등록 < 창 띄우기' 를 더함(블록을 창 띄우기 뒤로 옮겨 기능이 죽어도 통과했음) · 하네스 준비 실패 문구에 T17 하네스 행.
#   네 변이는 고치기 전 테스트에서 통과하고 고친 뒤 실패하는 것을 확인했습니다.
# 11-13 테스트 파일 리뷰 반영(통과만 하고 지키지 못하던 곳 셋 · 유지 하나): ① 대분류 · 생활 갱신(Update-MainCategoryVisual · Update-LifeSliders)을 빈 스텁에서 실함수로 -
#   하네스가 대분류 버튼 셋 · 생활 카드 여섯 · 화살표 넷 · 위치점 둘을 제품의 생성 문장 그대로 만들어 모든 T8 · T13 장면의 스냅샷 · 그림에 들어오고, T8 k · l 이 그 값을
#   다크 · 라이트 리터럴로 고정하며 T13 (g)(h) 가 되돌림을 봅니다(스텁일 때는 두 함수 안의 색 대입을 깨도 통과했음) ② G1 · G12 의 창 띄우기 찾기를 try 본문 글자의
#   정규식에서 실제 호출 노드로(호출을 지우고 주석만 남겨도 통과했음) ③ 하네스에 RadioButton · NumericUpDown · ComboBox · 폼 자식 RichTextBox 대표와 스냅샷의
#   RichTextBox 테두리 모양(T8 m - 일괄 적용의 그 네 분기를 실행으로 봄). G7 의 Apply-HoneyTheme 전체 일치는 유지합니다(근거는 G7 주석).
#   ① 의 두 함수 안 색 대입을 깬 변이와 ② 의 변이는 고치기 전 테스트에서 통과하고 고친 뒤 실패하는 것을, ③ 의 분기 변이는 원문 가드(G7)와 함께 실행 행(T8 m)도
#   잡는 것을 확인했습니다.
# 11-13 내부 검토 반영(위 리뷰 반영분에 남아 있던 공백 셋): ① T8 n - 다크에서 대분류 · 생활 쪽을 바꾸는 전이 장면. k · l 은 상태를 시작 갱신 앞에서 정해 두 함수가 늘
#   일괄 적용 직후의 컨트롤 위에서만 돌았고, 강조를 일반 모양으로 되돌리는 대입(대분류 비활성 분기 · 생활 카드의 그 밖 · 빈 칸 분기) 14줄을 한꺼번에 지워도 통과했습니다
#   ② T8 m 에 일반 형식 다섯(Label · CheckBox · GroupBox · Panel · Button)의 다크 · 라이트 리터럴 행. 그 분기는 값을 읽는 실행 행이 없어 G7 의 원문 일치 1행만 지켰고,
#   G7 주석의 근거 문장('형식별 동작은 실행 행도 본다')이 사실보다 넓었습니다 - 행을 더하고 문장을 고쳤습니다 ③ T13 (h) 의 던지는 순간에 생활 카드 · 위치점이
#   '아직 칠하기 전' 인 것도 리터럴로. 대분류 값만 맞대, 주입 감싸개가 생활 슬라이더를 먼저 돌리고 던지게 바뀌어도 통과했습니다.
#   세 곳 모두 그 변이가 고치기 전 테스트에서 통과(② 는 G7 1행만 실패)하고 고친 뒤 실패하는 것을 확인했습니다. ① 의 14줄 가운데 대분류 비활성 분기의 테두리 색
#   한 줄은 고친 뒤에도 통과합니다 - 그 값을 대입하는 다른 한 곳(일괄 적용)이 늘 같은 값을 먼저 칠하는 동치 변이입니다.
# 11-14 다크 입력 칸 통일(T18 · G13 - 설계 v3 7.13)과 하단 줄 여백(설계 7.12 - 하네스 폼 높이 사본 세 곳 872 → 881):
#   T18 첫 행(T1 앞 - 라이트에서는 장치도 형식도 안 생김: 이 프로세스에서 형식을 올리기 전에 돌아야 함) · T18d(제품 함수: 대상 수집 · 색 대응 표 · 켜고 끄기 · 실패와 경고 보관 ·
#   그리기 고장 알림) · T18a(두 점 대응) · T18 장치 사전 확인(하네스 행의 문지기) · T18b(여섯 칸의 그림) · T18c(끄면 원래대로) · T18e(핸들) · T18f(창 프로시저의 예외 경계) ·
#   T18 하네스 전환(실제 전환에서의 장치 · 실패했을 때의 배지) · G13(부르는 곳 · 형식 올리기 · 장치 목록 · 장치 원문의 받기).
#   하네스: 테마 하네스 폼에 시간 칸(dtpUntil)을 제품의 생성 문장 그대로 더하고 셀 편집 콤보도 그렇게 만들어, 모든 T8 · T13 장면의 왕복 · 되돌림 그림이 장치가 얹힌 칸을 담습니다
#   (라이트로 돌아와 장치가 꺼지지 않으면 그 장면들의 '폼 화소 = 기준' 이 갈림). 장치 상태 셋은 폼 하나에 한 벌이라 행의 출발점에서 소스의 초기값으로 되돌립니다.
#   변이 스물아홉 개(색 대응 · 테두리 · 켜고 끄기 · 부르는 자리 · 장치 원문의 받기 · 끄기 · 구독 · 대상 찾기 · 장치 만들기의 뒷정리 등)가 겨냥한 행에서 실패하는 것을
#   확인했습니다. 그 가운데 셋은 한 행만 지킵니다(그 행이 유일한 보호): '형식이 있어도 다시 올림' 은 행동이 같아 원문 가드(G13 형식 올리기)만 잡고(PowerShell 5.1 의 Add-Type 은
#   같은 원문을 다시 주면 다시 컴파일하지 않음), '다크에서 다시 그리기 요청을 하지 않음' 은 T18d '다시 그리기 요청' 행만, '끄기를 한 반복으로 합치고 하나의 try 로 감쌈' 은
#   T18d '끄는 도중 다시 그리기 요청 하나가 던짐' 행만 잡습니다. '정상 경로의 예외가 창 프로시저 밖으로 샘' 은 문지기(T18 장치 사전 확인) 1행이 잡고 하네스 행을 부르지 않습니다.
#   '목록 칸의 잠김 대응을 안 잠김 것으로' 는 T18d 색 대응 표와 T18b 바탕이 잡습니다(닫힌 목록 칸의 글자가 헤드리스 그림에 없어 글자 행으로는 안 드러남).
#   변이를 돌리다 찾은 것(11-14): 장치의 알림 본문이 대리자의 예외를 받지 않게 한 변이에서, 던지는 대리자를 메시지 루프로 돌리자 처리기 예외 대화 상자(모달)가 떠
#   이 테스트가 멈췄습니다 - 장치가 얹힌 창에서는 컨트롤의 창 프로시저가 '잡아서 대화 상자로 돌리는' 쪽으로 불려, 이 테스트의 예외 모드가 그 아래에는 닿지 않습니다.
#   그래서 던질 수 있는 것은 메시지 루프에 올리기 전에 직접 호출(관리 코드 경로)로 먼저 확인합니다(T18 장치 사전 확인 · T18f ① ②).
#   그림은 그림 받기 길(DrawToBitmap)이라 화면에 실제로 그려지는 화소 · 닫힌 목록 칸의 글자 · 임베디드 호스트에서의 동작은 실기 몫입니다(T18 하네스 행 머리 주석).
# 11-14 내부 검토 반영(통과만 하고 지키지 못하던 곳 넷 · 확인하지 않던 경로 하나):
#   ① G13 '그리기' - 화면 그리기에서 자식 창(시간 칸의 ▲▼) 자리를 그리는 영역에서 빼는 블록. 보이지 않는 폼에서는 그 블록의 안쪽까지 가지 않아 원문으로 고정합니다
#      (화면의 화소는 실기 몫). T18b 화소 분류의 '▲▼ 그대로' 는 그림 받기 길에서 자식 창이 제 그림을 덧찍은 것이라 이 블록과 무관했습니다
#   ② T18b '그릴 대상(DC)이 실려 온 WM_PAINT' + G13 창 프로시저의 '맡는 메시지' 정의 - 그때까지 보낸 WM_PAINT 는 모두 그릴 대상이 없는 보통의 것이었습니다
#   ③ T18b 바탕 - 잠근 채 만든 시간 · 목록 칸도 정확히 입력 바탕(8 이내로만 보면 잠긴 칸의 종이색 리터럴 254 · 250 을 1 바꿔도 통과)
#   ④ T18d 고장 알림 - 원인을 찾다가 난 예외(알림 함수의 본문 전체를 감싼 받기)와 '원인을 읽지 못함' 1줄
#   ⑤ T18b 부모에서 온 잠금 - 실행 중 잠금은 '반복' 묶음의 잠금입니다(그때까지 행의 잠금은 모두 칸 자신의 것)
#   변이 열 개(자식 창 빼기 블록 삭제 · 그 안의 좌표 변환 삭제 · 블록을 그림 옮기기 뒤로 · 맡는 메시지 조건 삭제 · 잠긴 시간 칸 종이색 254 → 255 · 잠긴 목록 칸 250 → 251 ·
#   알림의 바깥 받기 삭제 · 못 읽은 원인 글자 변경 / ⑤ 는 '잠금을 읽지 않음' · '숫자 칸도 안 잠긴 동안 대응')가 그 행에서 실패하는 것을 확인했고, 앞의 여덟은 고치기 전
#   테스트에서 통과하던 것도 확인했습니다. ⑤ 의 두 변이는 다른 행도 함께 잡습니다 - 부모 잠금만 따로 깨는 제품 변이는 만들지 못했습니다(주인의 Enabled 가 조상까지 반영)
# 11-14 장치가 사이의 서브클래스(말풍선 중계)를 건너뛰는 문제(설계 v3 7.14 - 장치가 맡지 않는 메시지와 제 그림 받기를 붙기 직전의 창 프로시저로 직접 넘김(Pass) ·
#   떼기는 맨 위일 때만(ReleaseIfTop) · Detach 는 참/거짓 · 붙은 채 남은 장치는 장치 형식의 정적 목록에 붙잡아 둠):
#   ① 창 프로시저 사슬 도구(테스트 전용 C# - 창 프로시저 읽기 · 바꾸기 · 보내기 · 모듈 이름 · 셀 수 있는 서브클래스 둘: 원시 SetWindowLongPtr · comctl32 SetWindowSubclass)
#   ② T18 장치 사전 확인에 사슬 행(메시지를 보내기 전): 이 테스트에서 붙은 장치가 메시지를 처음 받는 곳이 문지기의 직접 호출이라, 붙기 직전 창 프로시저를 AssignHandle 뒤에
#      읽는 결함(넘기기가 자신을 부름)은 여기서 잡지 않으면 그 호출이 스택을 넘쳐 프로세스가 출력 없이 끝납니다. 잡으면 그 창들의 창 프로시저를 장치 밖으로 되돌려 정리 때도
#      죽지 않게 하고 하네스 행(T18g 포함)을 부르지 않습니다 - 그래서 그 변이는 T18g X 의 '메시지 전' 행이 아니라 이 행에서 잡힙니다(T18g X 의 행은 문지기 뒤의 안전장치)
#   ③ T18g(X 핸들 뒤 장치 · Y 핸들 전 장치 · Z 말풍선 등록을 모두 지움 · Z 계수기 장치 아래 마스터의 마지막 등록 제거 · R 핸들 재생성 · 떼기의 맨 위 확인 -
#      헤드리스 탐침과 같은 방법. 넘기기가 아래 창 프로시저의 결과를 그대로 돌려주는지도 글자 수 결과(WM_GETTEXTLENGTH)로 봄) ④ G13 의 붙이기 · 창 프로시저 행을 글자 그대로에서 계약(순서 · 갈래 · 개수)으로 + 새 가드 다섯(넘기기 ·
#      그리기 안의 그림 받기 · 맨 위일 때만 떼기 · 떼기 · 제품의 떼기 호출) ⑤ Detach 의 반환값을 받는 행(T18c · T18e 는 참을 단언 · T18f 정리는 [void] · T18d '장치 만들기가
#      도중에 실패' 는 갱신 함수의 출력 0) - 반환값을 받지 않던 세 곳에서 'True' 줄 열넷이 테스트 출력으로 새고 있었습니다.
#   제품 변이 열여섯이 모두 겨냥한 행에서 실패하는 것을 확인했습니다(사본 폴더 · 원본은 그대로): 창 프로시저 끝의 넘기기를 base.WndProc 로(T18g X 꺼진 · 켠 · 떼기 · Z · R · 떼기의
#   맨 위 확인 + G13 넘기기 · 창 프로시저) · 그리기 안의 그림 받기를 DefWndProc 로(T18g X 그림 받기 · Z · R + G13 넘기기 · 그림 받기) · 놓은 뒤 다시 잇기 삭제(T18g X 떼기 + G13 맨 위)
#   · 맨 위 확인 삭제(T18g 떼기의 맨 위 확인 + G13 맨 위) · 붙기 직전 창 프로시저를 AssignHandle 뒤에 읽기(문지기 사슬 행 - 하네스 행을 부르지 않고 프로세스는 정상 종료 + G13 붙이기)
#   · 자기 창 프로시저를 AssignHandle 앞에서 읽기(같음) · 떼기의 [void] 삭제(T18d 출력 7 + G13 떼기 호출) · 떼기의 'Active = false' 삭제(T18e · T18g X 떼기 · 떼기의 맨 위 확인 + G13 떼기)
#   · 맨 위가 아니어도 참(T18g 떼기의 맨 위 확인 + G13 떼기) · 맨 위라 떼어도 거짓(T18c · T18e · T18g X 떼기 + G13 떼기) · 넘기기가 결과를 버림(T8 왕복 · T13 · T18 하네스 전환의
#   스냅샷 - 시간 칸 글자가 빔 · T18g X · Y 글자 수 + G13 넘기기) · 생성자의 핸들 생성 구독 삭제(T18e · T18g Y · R + G13 생성자).
#   그때 넷은 원문 가드 한 행만 지켰습니다(행동이 같거나 헤드리스에서 관측할 수 없음): '창 프로시저를 못 읽으면(0) 붙지 않음' 삭제 · retained 넣기 삭제 · 다시 이은 뒤 다시 읽기 삭제 ·
#   앞 핸들 놓기를 옛 꼴(맨 위 확인 없이 ReleaseHandle)로 - 모두 G13 붙이기 · 떼기 · 맨 위 행만 실패했습니다(retained 넣기는 아래 구현 리뷰 반영으로 행동 행도 잡음)
# 11-14 구현 리뷰 반영(지적 일곱 - 제품은 주석만: 장치 원문의 retained · busy · 앞 핸들 놓기 · 떼기, 장치 만들기의 머리 · 실패 정리 / 테스트 넷):
#   ① T18g Z - 숫자 칸의 말풍선만 지우던 꼴(SetToolTip(숫자 칸, 없음))은 안쪽 글자 칸 · 위아래 단추의 등록을 남겨 장치 아래의 중계가 지우기 전 그대로였습니다(헤드리스
#      확인: 도구 3 → 2 · 글자 칸의 말풍선 글자 그대로 - 지운 뒤 단언이 지우기 전 사슬에서 통과). 모두 지우고(RemoveAll) '도구 0 · 글자 칸 말풍선 글자 없음' 을 함께 보고,
#      'Z 계수기' 를 더했습니다 - 셀 수 있는 comctl32 서브클래스를 장치 아래 마스터의 유일한 등록으로 두고 RemoveWindowSubclass: 장치가 없으면 마스터가 스스로 빠지고(대조),
#      장치가 위에 있으면 마스터가 통과 역할로 남아 계수기에는 더 안 닿고 원시에는 닿습니다(설계 리뷰 P2 를 셈으로 확인)
#   ② T18e - 붙기 직전 창 프로시저 = 그 컨트롤 자신의 창 프로시저(관리 창의 windowProcPtr - 리플렉션)를 처음 붙을 때 · 핸들을 다시 만든 직후(끈 채 · 켠 채)에 봅니다.
#      R 은 옛 창 · 새 창 모두 아래가 comctl32 마스터(주소가 같음)라 '새로 읽음' 을 구별하지 못했습니다. R 둘째 행에 '계수기를 얹은 뒤 맨 위 = 장치' 를 더함
#   ③ G13 - 맨 위일 때만 떼기의 죽은 창 갈래(창 살아 있음 읽기 · 그 값으로 시작하는 맨 위 확인 · 다시 잇기)
#   ④ T18g X 떼기(참) = retained 에 안 들어감 · '떼기의 맨 위 확인'(거짓) = 들어감(리플렉션)
#   변이 열둘이 모두 겨냥한 행에서 실패하고 모든 실행이 'FAIL 합계' 와 종료 코드 1 로 끝났습니다(사본 폴더 · 원본은 그대로): 붙기 직전 창 프로시저 대입을 조건부로(0 일 때만 -
#   T18e 끈 채 · 켠 채의 '새로 읽음' 행) · retained 넣기 삭제(T18g 떼기의 맨 위 확인 + G13 떼기) · retained 넣기를 늘 거짓인 조건 안으로(T18g 떼기의 맨 위 확인만) · 맨 위라
#   떼어도 retained 에 넣음(T18g X 떼기 + G13 떼기) · 죽은 창 갈래의 조건 셋(맨 위 확인 · 다시 잇기의 'alive &&' 삭제 · 살아 있음을 늘 참 - 셋 다 G13 죽은 창 갈래만) ·
#   넘기기를 base.WndProc 로 · 그리기 안의 그림 받기를 DefWndProc 로(둘 다 새 Z · Z 계수기 행도) / 테스트 변이 셋: Z 를 옛 지우기로(Z 의 '도구 0' 칸만) · Z 계수기에서
#   지우지 않음 · R 둘째 행에서 장치 위에 서브클래스를 하나 더 얹음. 고치기 전 테스트로는 retained 조건 변이와 죽은 창 조건 셋이 통과했고, 조건부 대입 변이는 수거된 옛
#   대리자를 불러 T18e 도중 프로세스가 죽었습니다(접근 위반) - 이제는 다시 만든 직후에 잡고 그 창에서 장치를 빼 둬 죽지 않습니다(Get-T18StaleChains).
#   지금 원문 가드 한 행만 지키는 것: '창 프로시저를 못 읽으면(0) 붙지 않음' 삭제 · 다시 이은 뒤 다시 읽기 삭제 · 앞 핸들 놓기를 옛 꼴로 · 죽은 창 갈래의 조건 셋
$ErrorActionPreference = 'Stop'
$fails = 0

# ── 하네스 모드 (설계 3.1 V5) ─────────────────────────────────────────────────────────────
# 처리기 예외가 WinForms 기본 경로로 가면 모달 오류 창이 떠 무인 러너(run_all_tests.ps1 - 자식을 시간 상한 없이 기다림)가 멈춥니다.
# 그래서 어떤 컨트롤도 만들기 전에 ThrowException 모드를 1회 정합니다 - 컨트롤이 하나라도 생긴 뒤에는 이 호출이 예외를 냅니다
# (11-12 실측: 핸들 없는 Button 하나만 만들어도 InvalidOperationException). 실패하면 아무것도 돌리지 않고 끝냅니다.
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::SetUnhandledExceptionMode('ThrowException')
  [System.Windows.Forms.Application]::EnableVisualStyles()
} catch {
  "FAIL 하네스 준비: 처리기 예외 모드를 정하지 못했습니다 - $($_.Exception.Message)"
  exit 1
}

function Assert-Case {
  # 결과 한 줄 (러너 규약: 줄 머리 'FAIL' 이 있거나 종료 코드가 0 이 아니면 실패). 대소문자까지 같아야 통과합니다 - 'Title' 과 'title' 을 같게 보면 의미 기록 오류를 놓칩니다
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -ceq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Assert-SectionError {
  # 구역 실행 중 예외 - 실패 1줄(구역 · 줄 번호 · 원인)로 남기고 다음 구역으로 갑니다. 한 구역의 예외가 뒤 구역을 가리지 않게 구역마다 따로 받습니다
  param([string]$Section, $ErrorRecord)
  Assert-Case ('{0} 실행 예외 0 (줄 {1})' -f $Section, $ErrorRecord.InvocationInfo.ScriptLineNumber) $ErrorRecord.Exception.Message ''
}

function Get-RgbText {
  # 색 → 'R,G,B' (기대 리터럴과 맞대는 형식)
  param($Color)
  return ('{0},{1},{2}' -f $Color.R, $Color.G, $Color.B)
}

function Get-ArgbText {
  # 색 → 'A,R,G,B' (팔레트 표 대조용 - 투명도까지 봅니다)
  param($Color)
  return ('{0},{1},{2},{3}' -f $Color.A, $Color.R, $Color.G, $Color.B)
}

# ── 하네스 준비 (설계 3.1 '하네스 준비 행') ─────────────────────────────────────────────────
# ① 모드가 실제로 걸렸는가: WndProc 경로의 처리기 예외를 잡아 대화 상자로 돌리는 콜백 대신 잡지 않는 콜백이 쓰이는지(내부 속성).
#    모드 호출이 빠지면 이 값이 거짓이라, '호출이 예외 없이 끝났다' 만으로는 못 잡는 누락을 여기서 잡습니다
$harnessModeText = '읽지 못함'
try {
  $debuggableProperty = [System.Windows.Forms.NativeWindow].GetProperty('WndProcShouldBeDebuggable', [System.Reflection.BindingFlags]'NonPublic, Static')
  if ($debuggableProperty) { $harnessModeText = [string]$debuggableProperty.GetValue($null, $null) }
} catch { $harnessModeText = '읽지 못함: ' + $_.Exception.Message }
# ② 던지는 Paint 처리기의 DrawToBitmap. 11-12 실측: 이 모드에서 그 예외는 잡을 수 있는 예외로 올라오지 않고 네이티브 메시지 경로를 건너며
#    프로세스를 끝냅니다(종료 코드 2 - 같은 프로세스에서 하면 이 테스트가 통째로 죽음). 그래서 같은 준비를 한 자식 프로세스에서 일으켜
#    '모달 창으로 멈추지 않고 끝나는지'(시간 안 종료 · 그리기 뒤 줄에 닿지 않음)를 봅니다. 잡을 수 있는 예외로 올라와도 안전 쪽이라 통과입니다
#    자식은 그리기 바로 앞에서 'PROBE-START' 를 찍고, 그 표지가 있어야 안전으로 봅니다(11-13 리뷰 지적) - 표지 없이 비0 종료만 보면 자식이 그 앞
#    (어셈블리 · 모드 · 버튼 생성)에서 실패해도 아무것도 확인하지 않은 채 안전이 됩니다. 비0 종료 코드 값(실측 2)은 고정하지 않습니다 - 계약은
#    '그리기에서 모달 창 없이 끝났다' 이고, 다른 환경의 값은 관측하지 않았습니다
$probeScript = @'
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::SetUnhandledExceptionMode('ThrowException')
[System.Windows.Forms.Application]::EnableVisualStyles()
$probeButton = New-Object System.Windows.Forms.Button
$probeButton.Size = New-Object System.Drawing.Size(28, 28)
$probeButton.Add_Paint({ throw 'harness-probe' })
$probeBitmap = New-Object System.Drawing.Bitmap(28, 28)
[Console]::Out.WriteLine('PROBE-START')
[Console]::Out.Flush()
try {
  $probeButton.DrawToBitmap($probeBitmap, (New-Object System.Drawing.Rectangle(0, 0, 28, 28)))
  [Console]::Out.WriteLine('PROBE-RETURNED')
} catch { [Console]::Out.WriteLine('PROBE-CAUGHT') }
[Console]::Out.Flush()
exit 0
'@
$probeEnded = $false
$probeExit = $null
$probeOutput = ''
try {
  $probeStart = New-Object System.Diagnostics.ProcessStartInfo
  $probeStart.FileName = Join-Path $PSHOME 'powershell.exe'
  $probeStart.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ' + [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($probeScript))
  $probeStart.UseShellExecute = $false
  $probeStart.RedirectStandardOutput = $true
  $probeStart.RedirectStandardError = $true
  $probeStart.CreateNoWindow = $true
  $probeProcess = [System.Diagnostics.Process]::Start($probeStart)
  $probeStdout = $probeProcess.StandardOutput.ReadToEndAsync()
  $probeStderr = $probeProcess.StandardError.ReadToEndAsync()
  $probeEnded = $probeProcess.WaitForExit(60000)
  if (-not $probeEnded) { try { $probeProcess.Kill() } catch { } }
  [void]$probeProcess.WaitForExit(5000)
  if ($probeEnded) { $probeExit = $probeProcess.ExitCode }
  if ($probeStdout.Wait(5000)) { $probeOutput = [string]$probeStdout.Result }
  [void]$probeStderr.Wait(5000)
} catch { $probeOutput = '자식 실행 실패: ' + $_.Exception.Message }
$probeSafe = $probeEnded -and ($probeOutput -match 'PROBE-START') -and ($probeOutput -notmatch 'PROBE-RETURNED') -and (($probeExit -ne 0) -or ($probeOutput -match 'PROBE-CAUGHT'))
"INFO 준비: 메시지 콜백 '잡지 않음' = {0} · 던지는 Paint 처리기의 자식 = 종료 {1} · 종료 코드 {2} · 출력 [{3}]" -f $harnessModeText, $probeEnded, $probeExit, $probeOutput.Trim()
$harnessReady = ($harnessModeText -eq 'True') -and $probeSafe
if ($harnessReady) {
  'OK   준비 하네스 모드 - 모드 설정 예외 0 · 잡지 않는 메시지 콜백 · 던지는 Paint 처리기가 그리기에 닿은 뒤 모달 창 없이 끝남'
} else {
  # 설계: 1줄만 남기고 처리기를 실제로 돌리는 행(T8 · T13 · T14 · T16 · T17 · T18 하네스 행)을 부르지 않습니다 - 모달 창이 뜨면 러너가 멈춥니다.
  # 하네스 블록 밖의 T16 · T17 · T18 행(반환값 주입 · 판정 진리표 · 처리기 예외 경계 · 핸들 없는 폼에서의 제품 함수)은 그대로 돕니다
  "FAIL 하네스 준비: 메시지 콜백 '잡지 않음' [$harnessModeText] · 던지는 Paint 처리기 안전 [$probeSafe] - T8 · T13 · T14 · T16 · T17 · T18 하네스 행을 부르지 않습니다"
  $fails++
}

# ── 소스 준비 ───────────────────────────────────────────────────────────────────────────
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$repoConfigPath = Join-Path $projectRoot 'config.json'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
# 실제로 정의해 돌리는 함수 (제품 원문 그대로 - Invoke-MainCatButtonPaint 는 이번 변경 전부터 있던 함수로 T11 배선 행이 실행하고,
# 그 뒤 셋은 11-13 잠긴 글자 덧그리기로 T17 이 실행합니다. 그다음 둘(대분류 · 생활 갱신)도 이번 변경 전부터 있던 함수지만 팔레트 변수로 칠하는 곳이라
# 11-13 리뷰 반영으로 실함수를 돌립니다 - 공용 갱신이 부르는 그대로 T8 · T13 · T14 · T16 하네스 행이 실행합니다.
# 끝의 여덟은 11-14 다크 입력 칸 통일입니다 - 공용 갱신의 전체 모드가 8a · 12 로 부르므로 다크로 가는 모든 하네스 행이 실행하고, T18 이 따로 봅니다)
$realFunctionNames = @(
  'Get-HoneyPaletteTable', 'Set-HoneyPalette', 'ConvertTo-UiTheme', 'Get-NextUiTheme', 'Get-MainCatPaintIconKey',
  'Get-ThemeIconSpec', 'Get-ThemeIconLeft', 'Update-ThemeIconPlacement', 'Invoke-ThemeIconPaint', 'Invoke-ThemeToggleClick',
  'Update-ThemeIconStyle', 'Initialize-ThemeToggleButton', 'Update-LogTabBadge', 'Get-LogBadgeTextColor', 'Update-TabToggleStyle',
  'Reset-LogTabBadge', 'Save-UiThemeState', 'Update-CustomRandomToggleStyle', 'Get-CustomActiveListView', 'Set-CustomListRandomView',
  'Restore-CustomListRegisteredView', 'Update-ListThemeColors', 'Update-EtcNyanCardStyle', 'Apply-HoneyTheme', 'Get-StatusDisplayColor',
  'Invoke-StatusColorChanged', 'Get-StatusColorMeaning', 'Restore-StatusColorMeaning', 'Get-ToggleColorMeaning', 'Resolve-ToggleColorMeaning',
  'Get-ThemeRestoreState', 'Restore-ThemeState', 'Set-TitleBarTheme', 'Invoke-HoneyThemeRefresh', 'Invoke-ThemeSwitch',
  'Set-StartButtonPending', 'Add-ColoredLogLine', 'Read-Config', 'Write-Utf8FileAtomic', 'Save-Config', 'Load-SettingsToUi',
  'Invoke-MainCatButtonPaint', 'Test-LockedTextOverdraw', 'Invoke-LockedTextPaint', 'Update-LockedTextRepaint', 'Update-MainCategoryVisual', 'Update-LifeSliders',
  'Get-InputRecolorTypeSource', 'Get-InputRecolorTargets', 'Get-InputRecolorBorderColor', 'Get-InputRecolorPlan', 'Initialize-InputRecolor',
  'Invoke-InputRecolorFaultNotice', 'Update-InputRecolor', 'Write-InputRecolorWarning')
# 원문만 보는 함수 - 래퍼는 운영체제 함수(P/Invoke)를 불러 이 테스트에서 돌리지 않고 스텁으로 바꿉니다(T16)
$staticOnlyFunctionNames = @('Set-UiRunning', 'Invoke-DwmTitleBarAttribute')
# 이번 변경의 새 함수 28개 (G3 · G8 범위 - 파일 전체에는 옛 GetNewClosure · catch 2절이 있어 범위를 한정. 11-13 잠긴 글자 함수 셋은 G12 가,
# 11-14 다크 입력 칸 통일의 함수 여덟은 G13 이 같은 두 가지를 따로 봅니다)
$newFunctionNames = @(
  'Get-HoneyPaletteTable', 'Set-HoneyPalette', 'ConvertTo-UiTheme', 'Get-NextUiTheme', 'Get-MainCatPaintIconKey', 'Get-ThemeIconSpec',
  'Get-ThemeIconLeft', 'Update-ThemeIconPlacement', 'Invoke-ThemeIconPaint', 'Invoke-ThemeToggleClick', 'Update-ThemeIconStyle',
  'Initialize-ThemeToggleButton', 'Get-LogBadgeTextColor', 'Save-UiThemeState', 'Update-ListThemeColors', 'Update-EtcNyanCardStyle',
  'Get-StatusDisplayColor', 'Invoke-StatusColorChanged', 'Get-StatusColorMeaning', 'Restore-StatusColorMeaning', 'Get-ToggleColorMeaning',
  'Resolve-ToggleColorMeaning', 'Get-ThemeRestoreState', 'Restore-ThemeState', 'Invoke-DwmTitleBarAttribute', 'Set-TitleBarTheme',
  'Invoke-HoneyThemeRefresh', 'Invoke-ThemeSwitch')
try {
  $guiSource = [IO.File]::ReadAllText($guiPath)
  $guiTokens = $null
  $guiParseErrors = $null
  $guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$guiParseErrors)
  if (@($guiParseErrors).Count -gt 0) { throw ('소스 파서 오류: ' + $guiParseErrors[0].Message) }
  $guiCode = Remove-SourceComments -Text $guiSource
  $topStatements = @($guiAst.EndBlock.Statements)
  $allFunctionNames = @($realFunctionNames + $staticOnlyFunctionNames)
  $extractedTexts = @(Get-SourceFunctionDefinitions -Path $guiPath -Names $allFunctionNames)
  $functionTexts = @{}
  for ($nameIndex = 0; $nameIndex -lt $allFunctionNames.Count; $nameIndex++) { $functionTexts[$allFunctionNames[$nameIndex]] = [string]$extractedTexts[$nameIndex] }
} catch {
  "FAIL 소스 준비: $($_.Exception.Message)"
  exit 1
}
foreach ($realFunctionName in $realFunctionNames) { Invoke-Expression $functionTexts[$realFunctionName] }
# 고장 주입(T13)이 '다크일 때만 던지고 그 밖은 진짜를 부르는' 감싸개에서 쓰는 진짜 본문
$realBlocks = @{}
foreach ($realFunctionName in $realFunctionNames) { $realBlocks[$realFunctionName] = (Get-Item -LiteralPath ('function:' + $realFunctionName)).ScriptBlock }

# 공통 스텁 (테스트 전체). 로그는 받은 줄을 모으고, 슬라이드 정리는 표시만 내리며(애니메이션 · 오버레이는 이 테스트의 범위 밖), 제목줄 래퍼는
# 운영체제 함수를 부르지 않게 0(성공)을 돌려줍니다. 대분류 · 슬라이더 재적용(Update-MainCategoryVisual · Update-LifeSliders)은 스텁이 아닙니다 -
# 설계 3.1 의 스텁 목록에 있었지만 11-13 리뷰 반영으로 뺐습니다: 빈 함수면 그 안의 색 · 글꼴 · 테두리 · Enabled 대입을 깨도 어느 행도 실패하지 않아,
# 하네스가 그 컨트롤(대분류 버튼 · 생활 카드 · 화살표 · 위치점)을 만들고 실함수를 돌립니다
$logLines = New-Object System.Collections.Generic.List[string]
function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message) }
function Stop-LifeSlideNow { $script:lifeSlideActive = $false }
function Invoke-DwmTitleBarAttribute { param([IntPtr]$Handle, [int]$Value) return 0 }

$assignType = [System.Management.Automation.Language.AssignmentStatementAst]
$functionType = [System.Management.Automation.Language.FunctionDefinitionAst]
$commandType = [System.Management.Automation.Language.CommandAst]
$tryType = [System.Management.Automation.Language.TryStatementAst]
$ifType = [System.Management.Automation.Language.IfStatementAst]

function Get-TopIndexWhere {
  # 조건에 맞는 최상위 문장의 위치들 (열거용 - 호출부가 @() 로 받음)
  param([scriptblock]$Predicate)
  $matchedIndexes = New-Object System.Collections.Generic.List[int]
  for ($statementIndex = 0; $statementIndex -lt $script:topStatements.Count; $statementIndex++) {
    if (& $Predicate $script:topStatements[$statementIndex]) { $matchedIndexes.Add($statementIndex) }
  }
  return $matchedIndexes.ToArray()
}

function Get-NormalizedText {
  # 주석을 빼고 공백 덩어리를 하나로 줄인 코드 글자 (원문 단언용 - 줄바꿈 · 들여쓰기 차이에 흔들리지 않고 주석에만 걸리는 단언을 막습니다)
  param([string]$Text)
  return (((Remove-SourceComments -Text $Text) -replace '\s+', ' ').Trim())
}

function Get-FunctionCode {
  # 함수 원문의 주석 뺀 사본 (위치 보존)
  param([string]$Name)
  return (Remove-SourceComments -Text $script:functionTexts[$Name])
}

function Get-FunctionAstOf {
  # 함수 원문을 다시 파싱한 정의 노드 (함수 안 구조 단언용 - 위치는 함수 원문 기준)
  param([string]$Name)
  $parsedTokens = $null
  $parsedErrors = $null
  $parsed = [System.Management.Automation.Language.Parser]::ParseInput($script:functionTexts[$Name], [ref]$parsedTokens, [ref]$parsedErrors)
  return $parsed.EndBlock.Statements[0]
}

function Get-AstOwnerName {
  # 노드를 감싼 함수 이름 (최상위면 '(함수 밖)')
  param($Ast)
  $node = $Ast.Parent
  while ($node) {
    if ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $node.Name }
    $node = $node.Parent
  }
  return '(함수 밖)'
}

# 최상위 상태 문장 - 소스 그대로 점소싱해 초기값이 바뀌면 테스트도 그 값을 씁니다(층 기록 · 가드 · 원인 · 아이콘 원인 · 잔상 표시 · 배지 수 · 굵은 카드 글꼴 ·
# 잠긴 글자 덧그리기 원인 / 11-13 리뷰 반영으로 실함수가 된 대분류 · 생활 갱신이 읽는 여섯: 대분류 · 고른 스킬/대상 순번 · 보이는 쪽 둘 · 보통 카드 글꼴 /
# 11-14 다크 입력 칸 통일의 셋: 장치 목록 · 첫 실패 원인 · 보관된 경고. 이 셋은 '폼 하나에 한 벌' 입니다 - 제품은 폼이 하나라 한 번 만든 장치 목록을 끝까지 쓰지만
# 하네스는 행마다 폼을 새로 만들므로, 행의 출발점에서 소스의 초기값($null = 만든 적 없음)으로 되돌려야 새 폼의 컨트롤에 장치가 다시 만들어집니다
# (되돌리지 않으면 앞 행의 폼에 붙었던 장치 목록이 남아 새 폼의 칸에는 아무것도 붙지 않음)
$stateLeftTexts = @('$script:statusColorMeaning', '$script:statusLayerBusy', '$script:statusLayerError', '$script:themeIconPaintError',
  '$script:logBadgeStartAfterimage', '$script:hiddenLogErrors', '$script:hiddenLogWarns', '$script:lifeCardFontBold', '$script:lockedTextPaintError',
  '$script:mainCategory', '$script:lifeSkillIndex', '$script:lifeSkillPage', '$script:lifeTargetIndex', '$script:lifeTargetPage', '$script:lifeCardFontNormal',
  '$script:inputRecolorPainters', '$script:inputRecolorError', '$script:inputRecolorPendingWarning')
$stateStatementTexts = New-Object System.Collections.Generic.List[string]
$stateStatementMissing = @()
foreach ($stateLeft in $stateLeftTexts) {
  $stateHits = @($topStatements | Where-Object { ($_ -is $assignType) -and ($_.Left.Extent.Text -ceq $stateLeft) })
  if ($stateHits.Count -eq 1) { $stateStatementTexts.Add($stateHits[0].Extent.Text) } else { $stateStatementMissing += ('{0}({1})' -f $stateLeft, $stateHits.Count) }
}
Assert-Case '준비 최상위 상태 문장 18개가 각 1개' ($stateStatementMissing -join ',') ''
# [시작] 버튼의 평소 글자 (Set-StartButtonPending 이 되돌릴 때 씀)
$startButtonHits = @($topStatements | Where-Object { ($_ -is $assignType) -and ($_.Left.Extent.Text -ceq '$startButtonText') })
Assert-Case '준비 최상위 [시작] 평소 글자 문장 1개' $startButtonHits.Count 1
if ($startButtonHits.Count -eq 1) { . ([scriptblock]::Create($startButtonHits[0].Extent.Text)) }
# 상태줄 층 등록 문장 - 소스에 없으면 빈 글자(층 없이 돌아 T5 · T8 e 가 실패로 드러냄)
$layerRegistrationHits = @($topStatements | Where-Object { $_.Extent.Text -match '^\$lblStatus\.Add_ForeColorChanged\(' })
$layerRegistrationText = $(if ($layerRegistrationHits.Count -eq 1) { $layerRegistrationHits[0].Extent.Text } else { '' })
# 생활 스킬 · 대상 표 (Update-LifeSliders 가 읽는 자료 - 소스 문장 그대로 1회 점소싱). 하네스의 생활 '끝 쪽' 장면(T8 l · n · T13 (g)(h))은 이 표의 크기에 기댑니다:
# 스킬 9종 = 3쪽, 첫 스킬의 대상 10개 = 4쪽 · 끝 쪽은 1칸 + 빈 칸 둘. 표가 바뀌면 아래 크기 행이 먼저 실패합니다 - 그때는 장면의 쪽 번호
# (스킬 쪽 2 · 대상 순번 9 · 대상 쪽 3)와 기대 리터럴을 새 표에 맞춰 함께 고칩니다
$lifeSkillsHits = @($topStatements | Where-Object { ($_ -is $assignType) -and ($_.Left.Extent.Text -ceq '$script:lifeSkills') })
Assert-Case '준비 최상위 생활 스킬 · 대상 표 문장 1개' $lifeSkillsHits.Count 1
if ($lifeSkillsHits.Count -eq 1) { . ([scriptblock]::Create($lifeSkillsHits[0].Extent.Text)) }
Assert-Case '준비 생활 표 크기(하네스의 끝 쪽 장면이 기대는 값) - 스킬 9종 · 첫 스킬의 대상 10개' `
  $(if ($lifeSkillsHits.Count -eq 1) { '{0}/{1}' -f @($script:lifeSkills).Count, @($script:lifeSkills[0].Targets).Count } else { '표 없음' }) '9/10'
# 하네스가 제품의 생성 문장 그대로 만드는 컨트롤 18개 (11-13 리뷰 반영 - 대분류 버튼 셋 · 생활 묶음 · 화살표 넷 · 위치점 둘 · 반복 묶음 · 라디오 둘 · 숫자 칸 · 콤보 · 로그 창 /
# 11-14 다크 입력 칸 통일 - 시간 칸(시간 지정) · 셀 편집 콤보. 셀 편집 콤보는 그때까지 손으로 만든 편집형 콤보였는데, 제품은 닫힌 채 고르는 목록형이고
# 장치의 대상 찾기가 그 모양으로 가릅니다).
# 최상위 생성 문장('$이름 = New-Object …' - 정확히 1개)과 속성 대입문('$이름.속성 = …' - 소스에 있는 것 모두 · 그 순서)을 한 번 훑어 실행 블록으로 잡아 둡니다
# (T17 하네스와 같은 꼴 - 손으로 만든 복제본이면 제품의 생성 대입(크기 · 글자 · 글자 배치 등)이 바뀌어도 하네스는 옛 값으로 남습니다). 대입문이 아닌 문장
# (부모에 붙이기 · 이벤트 등록 · 말풍선)은 잡지 않습니다. 이름은 대소문자까지 맞댑니다(T17 과 같음)
$harnessSourceNames = @('btnCatBattle', 'btnCatLife', 'btnCatEtc', 'grpContentDetail', 'btnLifeSkillPrev', 'btnLifeSkillNext', 'btnLifeTargetPrev', 'btnLifeTargetNext',
  'lblLifeSkillDots', 'lblLifeTargetDots', 'grpRepeat', 'rbCustomRepeat', 'numCount', 'rbLifeGather', 'cboDifficulty', 'txtLog', 'dtpUntil', 'script:cellEditCombo')
$harnessSourceTable = New-Object 'System.Collections.Generic.Dictionary[string,object]'
foreach ($harnessSourceName in $harnessSourceNames) {
  $harnessSourceTable['$' + $harnessSourceName] = @{ CreationCount = 0; Blocks = (New-Object System.Collections.Generic.List[scriptblock]) }
}
foreach ($topStatement in $topStatements) {
  if (-not ($topStatement -is $assignType)) { continue }
  # 대입문 왼쪽의 머리('$이름' - 첫 마침표 앞)가 하네스 컨트롤이면 잡습니다: 마침표가 없으면 생성 문장, 있으면 속성 대입문
  $leftText = $topStatement.Left.Extent.Text
  $leftDot = $leftText.IndexOf('.')
  $leftHead = $(if ($leftDot -lt 0) { $leftText } else { $leftText.Substring(0, $leftDot) })
  if (-not $harnessSourceTable.ContainsKey($leftHead)) { continue }
  if ($leftDot -lt 0) { $harnessSourceTable[$leftHead].CreationCount++ }
  $harnessSourceTable[$leftHead].Blocks.Add([scriptblock]::Create($topStatement.Extent.Text))
}
$harnessSourceMissing = @($harnessSourceNames | Where-Object { $harnessSourceTable['$' + $_].CreationCount -ne 1 } | ForEach-Object { '{0}({1})' -f $_, $harnessSourceTable['$' + $_].CreationCount })
Assert-Case '준비 하네스 컨트롤 18개 - 최상위 생성 문장이 각 1개' ($harnessSourceMissing -join ',') ''
# 생활 카드 여섯 = 최상위 목록 대입문('$script:lifeSkillCards = @()' 꼴)과, 카드를 만들어 그 목록에 담는 foreach 문 - 줄마다(스킬 · 대상) 1개씩 소스 그대로 실행합니다
$lifeCardBlocks = New-Object System.Collections.Generic.List[scriptblock]
$lifeCardStatementCounts = foreach ($lifeCardListText in @('$script:lifeSkillCards', '$script:lifeTargetCards')) {
  $lifeCardListHits = @($topStatements | Where-Object { ($_ -is $assignType) -and ($_.Left.Extent.Text -ceq $lifeCardListText) })
  $lifeCardLoopHits = @($topStatements | Where-Object { ($_ -is [System.Management.Automation.Language.ForEachStatementAst]) -and
      (@($_.Body.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -ceq $lifeCardListText) }, $true)).Count -eq 1) })
  if (($lifeCardListHits.Count -eq 1) -and ($lifeCardLoopHits.Count -eq 1)) {
    $lifeCardBlocks.Add([scriptblock]::Create($lifeCardListHits[0].Extent.Text))
    $lifeCardBlocks.Add([scriptblock]::Create($lifeCardLoopHits[0].Extent.Text))
  }
  '{0}/{1}' -f $lifeCardListHits.Count, $lifeCardLoopHits.Count
}
Assert-Case '준비 하네스 생활 카드 문장 - 줄마다(스킬 · 대상) 목록 대입문 1 · 카드를 만들어 그 목록에 담는 foreach 문 1' ((@($lifeCardStatementCounts)) -join ' ') '1/1 1/1'

function Reset-ThemeTestState {
  # 행마다 같은 출발점: 소스의 최상위 상태 문장 + 테스트가 정하는 실행 상태 · 기록
  foreach ($stateText in $script:stateStatementTexts) { . ([scriptblock]::Create($stateText)) }
  $script:approvalPendingStart = $false
  $script:running = $false
  $script:lifeSlideActive = $false
  $script:uiReady = $true
  $script:customViewShuffled = $false
  $script:crLoading = $false
  # 생활 스킬 아이콘 표는 비워 둡니다 - 빈 표면 Update-LifeSliders 가 카드에 넣는 그림이 없음($null)입니다(아이콘은 색과 무관하고, 대분류 아이콘 그리기는
  # T11 배선이 따로 봄). T11 배선이 이 변수를 $null 로 돌려놓는데, $null 이면 Update-LifeSliders 의 아이콘 찾기(표[키])가 예외를 내므로 행마다 다시 정합니다
  $script:lifeSkillIcons = @{}
  $script:logLines.Clear()
  $script:t8SaveCount = 0
  $script:t8TitleCalls.Clear()
}
$t8TitleCalls = New-Object System.Collections.Generic.List[int]
$t8SaveCount = 0

# ── 하네스 (설계 3.1 T8 · T13 하네스) ───────────────────────────────────────────────────────
function New-HarnessControl {
  # 컨트롤 하나를 만들어 이름 · 위치 · 크기를 정하고 부모에 붙입니다 (스냅샷이 이름으로 줄을 가리킴)
  param([string]$TypeName, [string]$Name, [int]$X, [int]$Y, [int]$Width, [int]$Height, $Parent)
  $control = New-Object ('System.Windows.Forms.' + $TypeName)
  $control.Name = $Name
  $control.Location = New-Object System.Drawing.Point($X, $Y)
  $control.Size = New-Object System.Drawing.Size($Width, $Height)
  $Parent.Controls.Add($control)
  return $control
}

function New-HarnessToggle {
  # 버튼 모양 토글 - 생성 때 대입(gui 탭 토글 · 랜덤 4개)과 같은 값
  param([string]$Name, [string]$Text, [int]$X, [int]$Y)
  $toggle = New-HarnessControl -TypeName 'CheckBox' -Name $Name -X $X -Y $Y -Width 100 -Height 32 -Parent $script:form
  $toggle.Appearance = 'Button'
  $toggle.Text = $Text
  $toggle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
  $toggle.FlatStyle = 'Flat'
  $toggle.FlatAppearance.BorderColor = $script:themeBorder
  $toggle.FlatAppearance.BorderSize = 1
  $toggle.UseVisualStyleBackColor = $false
  $toggle.BackColor = $script:themeControl
  return $toggle
}

function New-SourceControl {
  # 제품의 생성 문장과 속성 대입문을 소스 그대로 실행해 컨트롤 하나를 만들고 부모에 붙입니다(11-13 리뷰 반영 - 소스 준비에서 잡아 둔 실행 블록 · T17 하네스와 같은 꼴).
  # 문장은 이 함수의 지역 변수로 실행돼 같은 이름의 하네스 변수(폼 밖 $script:txtLog 등)를 건드리지 않습니다. 하네스가 정하는 것은 다섯뿐입니다:
  # 이름표(제품이 이름을 주지 않은 컨트롤 - 스냅샷이 이름으로 줄을 가리킴) · 자리(-X · -Y: 준 쪽만 바꿈) · 크기(-Width · -Height) ·
  # 보이기(제품은 그 화면이 열릴 때까지 숨겨 둠 - T17 하네스처럼 보이는 채로 두어 그림 비교에 들어오게 함) · 부모
  param([string]$SourceName, $Parent, [string]$Name = '', [int]$X = -1, [int]$Y = -1, [int]$Width = -1, [int]$Height = -1)
  $sourceEntry = $null
  if (-not $script:harnessSourceTable.TryGetValue(('$' + $SourceName), [ref]$sourceEntry)) { throw ('하네스 컨트롤 목록에 없는 이름입니다: $' + $SourceName) }
  if ($sourceEntry.CreationCount -ne 1) { throw ('하네스 컨트롤의 최상위 생성 문장이 소스에 정확히 1개가 아닙니다: ${0} ({1}개)' -f $SourceName, $sourceEntry.CreationCount) }
  foreach ($sourceBlock in $sourceEntry.Blocks) { . $sourceBlock }
  $sourceControl = Get-Variable -Name $SourceName -ValueOnly
  if ($Name -ne '') { $sourceControl.Name = $Name } elseif ([string]::IsNullOrEmpty($sourceControl.Name)) { $sourceControl.Name = $SourceName }
  if (($X -ge 0) -or ($Y -ge 0)) {
    $sourceControl.Location = New-Object System.Drawing.Point($(if ($X -ge 0) { $X } else { $sourceControl.Left }), $(if ($Y -ge 0) { $Y } else { $sourceControl.Top }))
  }
  if (($Width -ge 0) -and ($Height -ge 0)) { $sourceControl.Size = New-Object System.Drawing.Size($Width, $Height) }
  $sourceControl.Visible = $true
  $Parent.Controls.Add($sourceControl)
  return $sourceControl
}

function New-SourceCellEditCombo {
  # 셀 편집 콤보를 제품의 생성 문장 · 속성 대입문 그대로 만듭니다(11-14 다크 입력 칸 통일 - 닫힌 채 고르는 목록형 · 숨김). 그 문장들이 $script:cellEditCombo 에
  # 바로 대입하므로 돌려주는 값은 없습니다. 제품처럼 어느 부모에도 붙이지 않습니다(편집할 때만 표 안에 붙음) - 장치의 대상 찾기가 폼 아래에서 못 찾아 따로 더하는 길을 탑니다.
  # 하네스는 이름표만 더합니다(제품은 이름을 주지 않음 - 행이 장치의 주인을 이름으로 가리킴)
  $sourceEntry = $null
  if (-not $script:harnessSourceTable.TryGetValue('$script:cellEditCombo', [ref]$sourceEntry)) { throw '하네스 컨트롤 목록에 셀 편집 콤보가 없습니다' }
  if ($sourceEntry.CreationCount -ne 1) { throw ('셀 편집 콤보의 최상위 생성 문장이 소스에 정확히 1개가 아닙니다 ({0}개)' -f $sourceEntry.CreationCount) }
  foreach ($sourceBlock in $sourceEntry.Blocks) { . $sourceBlock }
  $script:cellEditCombo.Name = 'cellEditCombo'
}

function New-ThemeHarness {
  # 헤드리스 폼에 제품 이름의 컨트롤을 생성 때 대입과 같은 값으로 만듭니다. 팔레트는 호출부가 먼저 라이트로 정합니다.
  # 컨트롤은 $script: 로 둡니다 - 제품 함수가 이름($lblStatus 등)으로 찾고, 도우미의 지역 변수가 그 이름을 가리지 않게 합니다.
  # 실행 중에만 보이는 중지 버튼 둘도 그림 비교에 들어오게 보이는 채 다른 자리에 둡니다(색 대입은 같음)
  param([switch]$WithFooter)
  if ($script:form) { try { $script:form.Dispose() } catch { } }
  if ($script:txtLog) { try { $script:txtLog.Dispose() } catch { } }
  if ($script:cellEditCombo) { try { $script:cellEditCombo.Dispose() } catch { } }
  $script:form = New-Object System.Windows.Forms.Form
  $script:form.Size = New-Object System.Drawing.Size(560, 881)
  $script:form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  # 상태줄 (gui lblStatus 생성 - Segoe UI 12 굵게 · 생성 색 DimGray)
  $script:lblStatus = New-HarnessControl -TypeName 'Label' -Name 'lblStatus' -X 15 -Y 12 -Width 514 -Height 26 -Parent $script:form
  $script:lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
  $script:lblStatus.Text = '대기 중'
  $script:lblStatus.ForeColor = [System.Drawing.Color]::DimGray
  # [시작] · 안전 중지 · 즉시 중지 (gui btnStart · btnSafeStop · btnKill 생성)
  $script:btnStart = New-HarnessControl -TypeName 'Button' -Name 'btnStart' -X 15 -Y 50 -Width 150 -Height 38 -Parent $script:form
  $script:btnStart.Text = $startButtonText
  $script:btnStart.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
  $script:btnStart.BackColor = [System.Drawing.Color]::FromArgb(70, 160, 90)
  $script:btnStart.ForeColor = [System.Drawing.Color]::White
  $script:btnStart.FlatStyle = 'Flat'
  $script:btnSafeStop = New-HarnessControl -TypeName 'Button' -Name 'btnSafeStop' -X 175 -Y 50 -Width 210 -Height 38 -Parent $script:form
  $script:btnSafeStop.Text = ('안전 중지(F9)' + [Environment]::NewLine + '(회차 완료 후)')
  $script:btnSafeStop.Enabled = $false
  $script:btnKill = New-HarnessControl -TypeName 'Button' -Name 'btnKill' -X 395 -Y 50 -Width 134 -Height 38 -Parent $script:form
  $script:btnKill.Text = '즉시 중지(F10)'
  $script:btnKill.Enabled = $false
  # '?' 도움 버튼 (gui btnClearHelp 생성 - 원형 Region 은 색과 무관해 생략)
  $script:btnClearHelp = New-HarnessControl -TypeName 'Button' -Name 'btnClearHelp' -X 15 -Y 100 -Width 18 -Height 18 -Parent $script:form
  $script:btnClearHelp.Text = '?'
  $script:btnClearHelp.FlatStyle = 'Flat'
  $script:btnClearHelp.FlatAppearance.BorderSize = 0
  $script:btnClearHelp.BackColor = [System.Drawing.Color]::SteelBlue
  $script:btnClearHelp.ForeColor = [System.Drawing.Color]::White
  $script:btnClearHelp.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
  # 냥코인 카드 (gui btnEtcNyanCard 생성 - 선택 모양은 패널 갱신이 칠함)
  $script:btnEtcNyanCard = New-HarnessControl -TypeName 'Button' -Name 'btnEtcNyanCard' -X 45 -Y 96 -Width 158 -Height 34 -Parent $script:form
  $script:btnEtcNyanCard.Text = '냥코인 뽑기'
  $script:btnEtcNyanCard.TabStop = $false
  # 설정 · 로그 탭 토글 + 접힘 미리보기 (gui 탭 토글 생성)
  $script:chkTabSettings = New-HarnessToggle -Name 'chkTabSettings' -Text '설정' -X 15 -Y 140
  $script:chkTabLog = New-HarnessToggle -Name 'chkTabLog' -Text '로그' -X 120 -Y 140
  $script:lblLogPreview = New-HarnessControl -TypeName 'Label' -Name 'lblLogPreview' -X 225 -Y 146 -Width 299 -Height 20 -Parent $script:form
  $script:lblLogPreview.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
  $script:lblLogPreview.AutoEllipsis = $true
  $script:lblLogPreview.Text = ''
  # 랜덤 토글 4개 (gui chkCrRandom 등 생성 - 같은 대입)
  $script:chkCrRandom = New-HarnessToggle -Name 'chkCrRandom' -Text '랜덤' -X 15 -Y 180
  $script:chkAcrRandom = New-HarnessToggle -Name 'chkAcrRandom' -Text '랜덤' -X 120 -Y 180
  $script:chkDcrRandom = New-HarnessToggle -Name 'chkDcrRandom' -Text '랜덤' -X 225 -Y 180
  $script:chkLcrRandom = New-HarnessToggle -Name 'chkLcrRandom' -Text '랜덤' -X 330 -Y 180
  # 커스텀 리스트 (gui lvCrList 생성 - 4개 표를 하나로 대신함) + 셀 편집 콤보(표 안에 붙기 전이라 폼 밖 - 제품의 생성 문장 그대로)
  $script:lvCrList = New-HarnessControl -TypeName 'ListView' -Name 'lvCrList' -X 15 -Y 220 -Width 300 -Height 100 -Parent $script:form
  $script:lvCrList.View = [System.Windows.Forms.View]::Details
  $script:lvCrList.GridLines = $true
  $script:lvCrList.CheckBoxes = $true
  $script:lvCrList.FullRowSelect = $true
  [void]$script:lvCrList.Columns.Add('', 24)
  [void]$script:lvCrList.Columns.Add('#', 32)
  [void]$script:lvCrList.Columns.Add('내용', 120)
  foreach ($rowNumber in 1..3) {
    $listRow = New-Object System.Windows.Forms.ListViewItem('')
    [void]$listRow.SubItems.Add([string]$rowNumber)
    [void]$listRow.SubItems.Add('항목' + $rowNumber)
    [void]$script:lvCrList.Items.Add($listRow)
  }
  $script:lvAcrList = $script:lvCrList
  $script:lvDcrList = $script:lvCrList
  $script:lvLcrList = $script:lvCrList
  New-SourceCellEditCombo
  # 일반 Label · Button · CheckBox · GroupBox(안에 Panel · 그 안에 Label) 각 1 - 테마 일괄 적용의 분기 · 재귀. 일괄 적용 뒤에 아무것도 덮지 않는 컨트롤이라
  # 그 분기가 칠한 값이 그대로 남습니다 - T8 m 이 이름으로 읽어 다크 · 라이트 리터럴과 맞댑니다(11-13 내부 검토 반영 - 그래서 $script: 에 둠)
  $script:plainLabel = New-HarnessControl -TypeName 'Label' -Name 'plainLabel' -X 330 -Y 225 -Width 100 -Height 20 -Parent $script:form
  $script:plainLabel.Text = '일반 글자'
  $script:plainButton = New-HarnessControl -TypeName 'Button' -Name 'plainButton' -X 330 -Y 250 -Width 100 -Height 28 -Parent $script:form
  $script:plainButton.Text = '일반 버튼'
  $script:plainCheck = New-HarnessControl -TypeName 'CheckBox' -Name 'plainCheck' -X 330 -Y 285 -Width 120 -Height 24 -Parent $script:form
  $script:plainCheck.Text = '일반 체크'
  $script:plainGroup = New-HarnessControl -TypeName 'GroupBox' -Name 'plainGroup' -X 15 -Y 330 -Width 300 -Height 90 -Parent $script:form
  $script:plainGroup.Text = '일반 묶음'
  $script:plainPanel = New-HarnessControl -TypeName 'Panel' -Name 'plainPanel' -X 10 -Y 20 -Width 280 -Height 60 -Parent $script:plainGroup
  $script:innerLabel = New-HarnessControl -TypeName 'Label' -Name 'innerLabel' -X 5 -Y 5 -Width 200 -Height 20 -Parent $script:plainPanel
  $script:innerLabel.Text = '안쪽 글자'
  # 새 버전 링크 (gui lnkUpdate 생성 - 평소 숨김)
  $script:lnkUpdate = New-HarnessControl -TypeName 'LinkLabel' -Name 'lnkUpdate' -X 369 -Y 812 -Width 160 -Height 20 -Parent $script:form
  $script:lnkUpdate.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
  $script:lnkUpdate.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
  $script:lnkUpdate.Visible = $false
  if ($WithFooter) {
    # 하단 줄 (T14 - gui btnOpenLog · btnClearLog · lblVersion 생성 + 말풍선). 링크는 위에서 이미 같은 자리에 만듦
    $script:btnOpenLog = New-HarnessControl -TypeName 'Button' -Name 'btnOpenLog' -X 15 -Y 806 -Width 100 -Height 28 -Parent $script:form
    $script:btnOpenLog.Text = 'Log 폴더 열기'
    $script:btnOpenLog.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    $script:btnClearLog = New-HarnessControl -TypeName 'Button' -Name 'btnClearLog' -X 280 -Y 806 -Width 80 -Height 28 -Parent $script:form
    $script:btnClearLog.Text = '로그 지우기'
    $script:btnClearLog.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
    $script:lblVersion = New-HarnessControl -TypeName 'Label' -Name 'lblVersion' -X 369 -Y 812 -Width 160 -Height 20 -Parent $script:form
    $script:lblVersion.Text = 'v2.1.12'
    $script:lblVersion.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $script:lblVersion.ForeColor = [System.Drawing.Color]::DimGray
    $script:lblVersion.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    if ($script:toolTip) { try { $script:toolTip.Dispose() } catch { } }
    $script:toolTip = New-Object System.Windows.Forms.ToolTip
  }
  # ── 대분류 · 생활 갱신이 칠하는 컨트롤 (11-13 리뷰 반영 - 공용 갱신이 실함수 Update-MainCategoryVisual · Update-LifeSliders 를 부름) ──
  # 제품의 생성 문장 · 속성 대입문 그대로 만듭니다(New-SourceControl). 폼 아래에 붙어 있어 모든 T8 · T13 장면의 스냅샷 · 그림 비교에 들어옵니다.
  # 대분류 버튼 셋 (gui btnCatBattle · btnCatLife · btnCatEtc - 제품 자리는 [시작] 줄과 겹쳐 세로만 옮김. 아이콘을 그리는 Paint 처리기는 달지 않습니다 - T11 배선이 따로 봄)
  $script:btnCatBattle = New-SourceControl -SourceName 'btnCatBattle' -Parent $script:form -Y 430
  $script:btnCatLife = New-SourceControl -SourceName 'btnCatLife' -Parent $script:form -Y 430
  $script:btnCatEtc = New-SourceControl -SourceName 'btnCatEtc' -Parent $script:form -Y 430
  # 생활 묶음 (gui grpContentDetail - 제품은 패널 갱신이 화면마다 높이를 바꿉니다: 여기서는 슬라이더 두 줄이 다 들어가는 높이). 안의 화살표 · 위치점 · 카드는 제품 자리 그대로
  $script:grpContentDetail = New-SourceControl -SourceName 'grpContentDetail' -Parent $script:form -Y 468 -Width 514 -Height 216
  $script:btnLifeSkillPrev = New-SourceControl -SourceName 'btnLifeSkillPrev' -Parent $script:grpContentDetail
  $script:btnLifeSkillNext = New-SourceControl -SourceName 'btnLifeSkillNext' -Parent $script:grpContentDetail
  $script:btnLifeTargetPrev = New-SourceControl -SourceName 'btnLifeTargetPrev' -Parent $script:grpContentDetail
  $script:btnLifeTargetNext = New-SourceControl -SourceName 'btnLifeTargetNext' -Parent $script:grpContentDetail
  $script:lblLifeSkillDots = New-SourceControl -SourceName 'lblLifeSkillDots' -Parent $script:grpContentDetail
  $script:lblLifeTargetDots = New-SourceControl -SourceName 'lblLifeTargetDots' -Parent $script:grpContentDetail
  # 생활 카드 여섯 - 소스의 목록 대입문 · foreach 문 그대로 실행합니다: 카드를 만들어 $grpContentDetail(위에서 만든 하네스 묶음)에 붙이고
  # $script:lifeSkillCards · $script:lifeTargetCards 에 담습니다(클릭 처리기도 달리지만 이 테스트는 누르지 않음). 하네스는 이름표와 보이기만 더합니다
  if ($script:lifeCardBlocks.Count -ne 4) { throw '하네스 생활 카드 문장(목록 대입문 · foreach 문 각 둘)이 소스에 없습니다' }
  foreach ($lifeCardBlock in $script:lifeCardBlocks) { . $lifeCardBlock }
  foreach ($cardSlot in 0..2) {
    $script:lifeSkillCards[$cardSlot].Name = 'lifeSkillCard' + $cardSlot
    $script:lifeSkillCards[$cardSlot].Visible = $true
    $script:lifeTargetCards[$cardSlot].Name = 'lifeTargetCard' + $cardSlot
    $script:lifeTargetCards[$cardSlot].Visible = $true
  }
  # ── 일괄 적용의 나머지 형식 넷 (11-13 리뷰 반영 - Apply-HoneyTheme 의 RadioButton · NumericUpDown · ComboBox · RichTextBox 분기가 실제로 지나가게 대표를 둠) ──
  # 반복 묶음(gui grpRepeat) 안의 '커스텀 반복' 라디오와 횟수 숫자 칸 - 묶음 안 자리는 제품 그대로. '커스텀 반복' 은 Update-LifeSliders 가 읽는 라디오이기도 합니다
  # (꺼진 채 - 커스텀 화면의 '아이콘 없는 카드' 분기는 타지 않음)
  $script:grpRepeat = New-SourceControl -SourceName 'grpRepeat' -Parent $script:form -Y 688
  $script:rbCustomRepeat = New-SourceControl -SourceName 'rbCustomRepeat' -Parent $script:grpRepeat
  $script:numCount = New-SourceControl -SourceName 'numCount' -Parent $script:grpRepeat
  # '시간 지정' 시간 칸(gui dtpUntil - 반복 묶음 안 제품 자리 그대로 · 11-14 다크 입력 칸 통일): 테마 일괄 적용은 이 형식을 다루지 않고, 다크에서는 장치(HoneyInputRecolor)가
  # 다시 칠합니다. 폼 아래에 있어 모든 T8 · T13 장면의 왕복 · 되돌림 그림 비교에 들어옵니다(다크에서 켜졌던 장치가 라이트로 돌아와 꺼지지 않으면 폼 화소가 갈림).
  # 값은 하네스가 고정합니다 - 제품은 만든 순간의 시각을 보여 줘, 기준 그림과 왕복 그림을 서로 다른 하네스에서 찍는 장면(T8 f3 · i · n 등)이 분이 넘어갈 때 갈립니다
  $script:dtpUntil = New-SourceControl -SourceName 'dtpUntil' -Parent $script:grpRepeat
  $script:dtpUntil.Value = [datetime]'2026-01-02 12:34:00'
  # '채집' 라디오(gui rbLifeGather - 제품은 콘텐츠 선택 패널 안 · Update-LifeSliders 가 읽음 · 켜져 있고 잠기지 않아 글자색이 그림에 나타남)와
  # 난이도 콤보(gui cboDifficulty - 제품은 난이도 패널 안 · 항목은 실행 때 채워 여기서는 비어 있음)는 폼에 바로 둡니다
  $script:rbLifeGather = New-SourceControl -SourceName 'rbLifeGather' -Parent $script:form -X 15 -Y 746
  $script:cboDifficulty = New-SourceControl -SourceName 'cboDifficulty' -Parent $script:form -X 110 -Y 745
  # 로그 창 대표 (gui txtLog 의 생성 문장 그대로 - 폼 자식 · 자리와 크기만 줄임). 바로 아래의 폼 밖 $script:txtLog 와는 다른 컨트롤입니다
  $script:logChild = New-SourceControl -SourceName 'txtLog' -Parent $script:form -Name 'logChild' -X 275 -Y 746 -Width 254 -Height 54
  # 로그 본문 (Add-ColoredLogLine 이 쓰는 로그 창 - 폼에는 붙이지 않음: 접힘 장면이라 화면에 없고, 그림 비교 대상도 아님)
  $script:txtLog = New-Object System.Windows.Forms.RichTextBox
}

function Initialize-AllHandles {
  # 모든 컨트롤 핸들을 만듭니다 - 보이지 않은 폼의 DrawToBitmap 은 핸들이 있는 자식만 찍어, 만들지 않으면 그림 비교가 '빈 그림끼리' 가 됩니다
  # (구현 단계 스모크 관측: 핸들 없이 찍은 시작 그림에는 아이콘이 없었음)
  param($Parent)
  [void]$Parent.Handle
  foreach ($child in @($Parent.Controls)) { Initialize-AllHandles -Parent $child }
}

function Start-ThemeHarness {
  # 제품 시작 순서 흉내(설계 3.1): 팔레트 light → 생성 대입 → Checked → 토글 스타일 → (기타) 냥코인 카드 → (배지) 시작 전 경고 · 오류 줄 →
  # 층 등록(소스 문장 그대로) → 시작 갱신(인자 없음 - 6a 포함) → 모든 핸들. 탭 토글은 열린 저장값일 때만 CheckedChanged 가 스타일을 부르고,
  # 랜덤 4개는 설정 읽기가 늘 부릅니다(gui Load-SettingsToUi). 배지 줄은 실함수 Add-ColoredLogLine 의 접힘 분기(수 +1 · 미리보기 · 배지)를 탑니다.
  # 대분류와 생활 슬라이더의 쪽 · 고른 대상(-Category · -SkillPage · -TargetIndex · -TargetPage)은 시작 갱신 앞에서 정합니다 - 제품도 설정 읽기가 먼저 정하고
  # 시작 갱신의 대분류 · 생활 갱신(실함수)이 그 상태로 칠합니다. 기본값은 소스의 최상위 초기값 그대로(전투 · 첫 쪽 · 첫 칸)
  param([switch]$SettingsOpen, [switch]$RandomOn, [switch]$NyanSelected, [int]$Warns = 0, [int]$Errors = 0, [switch]$WithFooter,
    [string]$Category = '', [int]$SkillPage = -1, [int]$TargetIndex = -1, [int]$TargetPage = -1)
  Reset-ThemeTestState
  Set-HoneyPalette -Theme 'light'
  New-ThemeHarness -WithFooter:$WithFooter
  if ($Category -ne '') { $script:mainCategory = $Category }
  if ($SkillPage -ge 0) { $script:lifeSkillPage = $SkillPage }
  if ($TargetIndex -ge 0) { $script:lifeTargetIndex = $TargetIndex }
  if ($TargetPage -ge 0) { $script:lifeTargetPage = $TargetPage }
  if ($SettingsOpen) {
    $script:chkTabSettings.Checked = $true
    Update-TabToggleStyle
  }
  $script:chkCrRandom.Checked = [bool]$RandomOn
  foreach ($randomToggle in @($script:chkCrRandom, $script:chkAcrRandom, $script:chkDcrRandom, $script:chkLcrRandom)) { Update-CustomRandomToggleStyle -Toggle $randomToggle }
  if ($NyanSelected) { Update-EtcNyanCardStyle }
  for ($warnIndex = 0; $warnIndex -lt $Warns; $warnIndex++) { Add-ColoredLogLine ('12:00:0{0} [경고] 시작 전 경고 {0}' -f $warnIndex) }
  for ($errorIndex = 0; $errorIndex -lt $Errors; $errorIndex++) { Add-ColoredLogLine ('12:00:1{0} [오류] 시작 전 오류 {0}' -f $errorIndex) }
  if ($script:layerRegistrationText) { . ([scriptblock]::Create($script:layerRegistrationText)) }
  Invoke-HoneyThemeRefresh
  Initialize-AllHandles -Parent $script:form
}

function Get-HarnessControls {
  # 폼 아래 모든 컨트롤 (열거용)
  param($Parent)
  foreach ($child in @($Parent.Controls)) {
    $child
    if ($child.Controls.Count -gt 0) { Get-HarnessControls -Parent $child }
  }
}

function Format-StatusMeaning {
  # 상태줄 의미 기록 → 글자 ('Title' 또는 '이름/ARGB')
  param($Meaning)
  if ($Meaning -is [string]) { return $Meaning }
  return ('{0}/{1}' -f $Meaning.Name, $Meaning.ToArgb())
}

function Get-HarnessSnapshot {
  # 스냅샷(설계 3.1): 모든 컨트롤의 바탕 · 글자 ARGB(상태줄은 이름도) · 평면 모양(테두리 색 · 두께 · 눌린 바탕 · 올림 · 누름) · 굵게 · 글자 · Enabled ·
  # 리스트 행 ARGB · 표 바탕 · 글자가 시스템 색인지 · 링크 색 · 콤보 · 폼 바탕 · 잔상 표시 · 층 의미 · 지금 테마 · RichTextBox 의 테두리 모양
  # (11-13 리뷰 반영 - 일괄 적용이 만지는 속성 가운데 스냅샷에 없던 하나. 그 밖의 대입 - 평면 모양 · 바탕 · 글자색 - 은 이미 위 항목에 있음)
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('theme=' + $script:uiTheme)
  $lines.Add('form B=' + $script:form.BackColor.ToArgb())
  foreach ($control in @(Get-HarnessControls -Parent $script:form)) {
    $line = '{0}|T={1}|B={2}|F={3}|E={4}|Bold={5}' -f $control.Name, $control.Text, $control.BackColor.ToArgb(), $control.ForeColor.ToArgb(), $control.Enabled, $control.Font.Bold
    if ($control -is [System.Windows.Forms.ButtonBase]) {
      $line += ('|FS={0}|BC={1}|BS={2}|CB={3}|MO={4}|MD={5}' -f $control.FlatStyle, $control.FlatAppearance.BorderColor.ToArgb(), $control.FlatAppearance.BorderSize,
        $control.FlatAppearance.CheckedBackColor.ToArgb(), $control.FlatAppearance.MouseOverBackColor.ToArgb(), $control.FlatAppearance.MouseDownBackColor.ToArgb())
    }
    if ($control -is [System.Windows.Forms.LinkLabel]) { $line += ('|L=' + $control.LinkColor.ToArgb()) }
    if ($control -is [System.Windows.Forms.RichTextBox]) { $line += ('|RB=' + $control.BorderStyle) }
    if ($control -is [System.Windows.Forms.ListView]) {
      $line += ('|SB={0}|SF={1}|rows={2}' -f $control.BackColor.IsSystemColor, $control.ForeColor.IsSystemColor, ((@($control.Items) | ForEach-Object { $_.BackColor.ToArgb() }) -join ','))
    }
    if ($control.Name -eq 'lblStatus') { $line += ('|N=' + $control.ForeColor.Name) }
    $lines.Add($line)
  }
  $lines.Add(('combo B={0} F={1} SB={2} SF={3}' -f $script:cellEditCombo.BackColor.ToArgb(), $script:cellEditCombo.ForeColor.ToArgb(),
      $script:cellEditCombo.BackColor.IsSystemColor, $script:cellEditCombo.ForeColor.IsSystemColor))
  $lines.Add('afterimage=' + [bool]$script:logBadgeStartAfterimage)
  $lines.Add('meaning=' + (Format-StatusMeaning -Meaning $script:statusColorMeaning))
  return ($lines -join "`n")
}

function Get-FormPixelHash {
  # 폼 전체 DrawToBitmap 화소의 SHA256 - 화소가 하나라도 다르면 값이 달라집니다(GetPixel 비교보다 수백 배 빠름)
  $bitmap = New-Object System.Drawing.Bitmap($script:form.Width, $script:form.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $script:form.DrawToBitmap($bitmap, (New-Object System.Drawing.Rectangle(0, 0, $script:form.Width, $script:form.Height)))
    $bitmapData = $bitmap.LockBits((New-Object System.Drawing.Rectangle(0, 0, $bitmap.Width, $bitmap.Height)), [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
      [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $pixelBytes = New-Object byte[] ($bitmapData.Stride * $bitmapData.Height)
      [System.Runtime.InteropServices.Marshal]::Copy($bitmapData.Scan0, $pixelBytes, 0, $pixelBytes.Length)
    } finally { $bitmap.UnlockBits($bitmapData) }
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($pixelBytes)) -replace '-', '') } finally { $hasher.Dispose() }
  } finally { $bitmap.Dispose() }
}

function Get-HarnessState {
  # 지금 하네스 상태 (스냅샷 + 화소 해시)
  return @{ Snapshot = (Get-HarnessSnapshot); Pixels = (Get-FormPixelHash) }
}

function Compare-HarnessSnapshot {
  # 두 스냅샷이 같으면 '같음', 다르면 처음 다른 줄 둘(전 → 뒤)
  param([string]$Before, [string]$After)
  if ($Before -ceq $After) { return '같음' }
  $beforeLines = $Before -split "`n"
  $afterLines = $After -split "`n"
  $differences = @()
  for ($lineIndex = 0; $lineIndex -lt [Math]::Max($beforeLines.Count, $afterLines.Count); $lineIndex++) {
    if ($beforeLines[$lineIndex] -cne $afterLines[$lineIndex]) { $differences += ('전 [{0}] 뒤 [{1}]' -f $beforeLines[$lineIndex], $afterLines[$lineIndex]) }
    if ($differences.Count -ge 2) { break }
  }
  return ($differences -join ' / ')
}

function Invoke-T8RoundTrip {
  # 라이트 → 다크 → 라이트 (아이콘 클릭 경로 - 실함수 Invoke-ThemeToggleClick). 다크가 된 뒤 -DarkPreProbe 로 읽고, -DarkAction 으로 다크 중 조작을 한 뒤
  # -DarkProbe 로 다시 읽습니다. 라이트로 돌아온 상태 · 경고 줄 수 · 저장 횟수를 돌려줍니다(스텁은 호출부 Invoke-T8Scene 지역)
  param([scriptblock]$DarkPreProbe, [scriptblock]$DarkAction, [scriptblock]$DarkProbe)
  Invoke-ThemeToggleClick
  # 읽은 값은 매개변수와 다른 이름에 둡니다 - PowerShell 변수 이름은 대소문자를 가리지 않아 $darkProbe 는 [scriptblock]$DarkProbe 와 같은 변수입니다
  $preProbeValue = $(if ($DarkPreProbe) { & $DarkPreProbe } else { '' })
  if ($DarkAction) { & $DarkAction }
  $darkProbeValue = $(if ($DarkProbe) { & $DarkProbe } else { '' })
  $themeAfterDark = $script:uiTheme
  $darkPixels = Get-FormPixelHash
  Invoke-ThemeToggleClick
  $lightState = Get-HarnessState
  return @{ Pre = $preProbeValue; Dark = $darkProbeValue; DarkTheme = $themeAfterDark; DarkPixels = $darkPixels; State = $lightState; Logs = ($script:logLines -join ' / '); Saves = $script:t8SaveCount; Theme = $script:uiTheme }
}

function Assert-RoundTrip {
  # 왕복 뒤 = 기준(왕복 전 또는 라이트에서 같은 조작을 한 기준) - 스냅샷 · 폼 화소. 왕복이 깨끗했는지(경고 0줄 · 저장 2 · 다크 → 라이트)도 함께 봅니다
  param([string]$Name, $Reference, $Trip)
  Assert-Case ($Name + ' - 왕복 뒤 스냅샷 = 기준') (Compare-HarnessSnapshot -Before $Reference.Snapshot -After $Trip.State.Snapshot) '같음'
  # 다크 그림이 기준과 달라야 그림 비교가 색을 담고 있다는 뜻입니다. 다만 이 조건은 폼 바탕 하나만 찍혀도 참이라(11-13 내부 검토 - 핸들 없이 찍으면
  # 자식이 빠진 그림끼리 같아짐), 그림이 자식 컨트롤까지 담는지는 T8 '그림' 장면이 따로 봅니다
  Assert-Case ($Name + ' - 왕복 뒤 폼 화소 = 기준 · 다크 화소는 기준과 다름(그림이 색을 담음)') ('{0}/{1}' -f ($Reference.Pixels -ceq $Trip.State.Pixels), ($Reference.Pixels -cne $Trip.DarkPixels)) 'True/True'
  Assert-Case ($Name + ' - 다크 → 라이트 · 경고 0줄 · 저장 2') ('{0}>{1} · [{2}] · {3}' -f $Trip.DarkTheme, $Trip.Theme, $Trip.Logs, $Trip.Saves) 'dark>light · [] · 2'
}

function Invoke-T8Scene {
  # T8 한 장면 (설계 T8 스텁: 단장 · 제목줄 · 저장(셈) - 이 함수 지역이라 장면 안에서만 보임). 장면이 던지면 실패 1줄로 남기고 다음 장면으로 갑니다
  param([string]$Name, [scriptblock]$Scene)
  function Save-UiThemeState { $script:t8SaveCount++ }
  function Update-ThemeIconStyle { }
  function Set-TitleBarTheme { param([bool]$Dark) $script:t8TitleCalls.Add([int]$Dark) }
  try { & $Scene } catch { Assert-SectionError -Section ('T8 {0} 장면' -f $Name) -ErrorRecord $_ }
}

function Get-BadgeText {
  # 로그 탭 토글(배지) 바탕/글자/잔상 표시
  return ('{0}/{1}/{2}' -f (Get-RgbText $script:chkTabLog.BackColor), (Get-RgbText $script:chkTabLog.ForeColor), [bool]$script:logBadgeStartAfterimage)
}

function Get-CardText {
  # 냥코인 카드 바탕/테두리 색/두께/굵게
  return ('{0}/{1}/{2}/{3}' -f (Get-RgbText $script:btnEtcNyanCard.BackColor), (Get-RgbText $script:btnEtcNyanCard.FlatAppearance.BorderColor),
      $script:btnEtcNyanCard.FlatAppearance.BorderSize, $script:btnEtcNyanCard.Font.Bold)
}

function Get-LifeSceneText {
  # 대분류 · 생활 갱신(Update-MainCategoryVisual · Update-LifeSliders)이 칠하는 것 전부 - hashtable 1개(11-13 리뷰 반영):
  #   Cat    = 대분류 버튼 셋 '이름=바탕/글자색/테두리 색(두께 0 이면 -)/두께/굵게'
  #   Cards  = 생활 카드 두 줄(스킬 · 대상) - 칸마다 '글자 또는 빈 칸/Enabled/바탕/글자색/테두리 색/두께/굵게' (카드 글자 자체는 생활 표의 내용이라 있음 · 없음만 봄)
  #   Paging = 위치점 둘 '글자/글자색'(스킬 | 대상) · 화살표 넷 Enabled '◀/▶'(스킬 | 대상)
  $catText = (@($script:btnCatBattle, $script:btnCatLife, $script:btnCatEtc) | ForEach-Object {
      '{0}={1}/{2}/{3}/{4}/{5}' -f $_.Name, (Get-RgbText $_.BackColor), (Get-RgbText $_.ForeColor),
        $(if ($_.FlatAppearance.BorderSize -gt 0) { Get-RgbText $_.FlatAppearance.BorderColor } else { '-' }), $_.FlatAppearance.BorderSize, $_.Font.Bold }) -join ' '
  $cardRowTexts = foreach ($cardRow in @(@{ Label = '스킬'; Cards = $script:lifeSkillCards }, @{ Label = '대상'; Cards = $script:lifeTargetCards })) {
    '{0} {1}' -f $cardRow.Label, ((@($cardRow.Cards) | ForEach-Object {
          '{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $(if ($_.Text -ne '') { '글자' } else { '빈 칸' }), $_.Enabled, (Get-RgbText $_.BackColor), (Get-RgbText $_.ForeColor),
            (Get-RgbText $_.FlatAppearance.BorderColor), $_.FlatAppearance.BorderSize, $_.Font.Bold }) -join ' | ')
  }
  $pagingText = '점 {0}/{1} | {2}/{3} · 화살표 {4}/{5} | {6}/{7}' -f $script:lblLifeSkillDots.Text, (Get-RgbText $script:lblLifeSkillDots.ForeColor),
    $script:lblLifeTargetDots.Text, (Get-RgbText $script:lblLifeTargetDots.ForeColor),
    $script:btnLifeSkillPrev.Enabled, $script:btnLifeSkillNext.Enabled, $script:btnLifeTargetPrev.Enabled, $script:btnLifeTargetNext.Enabled
  return @{ Cat = $catText; Cards = ((@($cardRowTexts)) -join ' || '); Paging = $pagingText }
}

function Format-LifeScene {
  # 장면 글자 셋(Get-LifeSceneText · Get-LifeExpect)을 한 줄로 - '대분류 ;; 생활 카드 ;; 위치점 · 화살표'
  param($Scene)
  return ('{0} ;; {1} ;; {2}' -f $Scene.Cat, $Scene.Cards, $Scene.Paging)
}

# 대분류 · 생활 장면의 기대 조각 (T8 k · l · n · T13 (g)(h) 가 함께 씀). 색은 T2 의 팔레트 리터럴과 같은 숫자를 직접 적습니다(H11 - 제품 변수로 계산하지 않음):
#   다크   = Control 44,44,48 · Text 232,230,227 · Border 62,62,68 · Muted 154,154,160 · 고른 카드 바탕 58,56,50 · HoneyInk 42,28,0
#   라이트 = Control 255,253,247 · Text 66,50,22 · Border 226,205,160 · Muted 158,138,104 · 고른 카드 바탕 250,240,218 · HoneyInk 66,45,0   (Honey 는 두 테마 247,181,0)
# 카드 한 칸 = '글자 또는 빈 칸/Enabled/바탕/글자색/테두리 색/두께/굵게' · 대분류 버튼 = '바탕/글자색/테두리 색(두께 0 이면 -)/두께/굵게'
$lifeExpectPieces = @{
  dark  = @{ On = '글자/True/58,56,50/232,230,227/247,181,0/2/True'; Off = '글자/True/44,44,48/232,230,227/62,62,68/1/False'; Blank = '빈 칸/False/44,44,48/232,230,227/62,62,68/1/False'
    CatOn = '247,181,0/42,28,0/-/0/True'; CatOff = '44,44,48/232,230,227/62,62,68/1/False'; Dot = '154,154,160' }
  light = @{ On = '글자/True/250,240,218/66,50,22/247,181,0/2/True'; Off = '글자/True/255,253,247/66,50,22/226,205,160/1/False'; Blank = '빈 칸/False/255,253,247/66,50,22/226,205,160/1/False'
    CatOn = '247,181,0/66,45,0/-/0/True'; CatOff = '255,253,247/66,50,22/226,205,160/1/False'; Dot = '158,138,104' }
}
function Get-LifeExpect {
  # 한 장면 × 한 테마의 기대 글자 - hashtable 1개(Get-LifeSceneText 와 같은 꼴). 장면은 셋입니다:
  #   첫 쪽(기본)  = 대분류 전투 · 스킬 줄과 대상 줄 모두 첫 쪽 · 첫 칸을 고름 → 줄마다 '고른 칸 | 그 밖 | 그 밖', ◀ 잠김 · ▶ 풀림
  #   끝 쪽(-Last) = 대분류 생활 · 스킬 줄은 끝 쪽(고른 스킬은 첫 쪽에 있어 보이는 세 칸이 모두 '그 밖'), 대상 줄은 끝 쪽의 첫 칸을 고름 + 빈 칸 둘 → ◀ 풀림 · ▶ 잠김
  #   첫 쪽 · 대상 둘째 칸(-SecondTarget) = 첫 쪽과 같되 대상 줄만 둘째 칸을 고름 → '그 밖 | 고른 칸 | 그 밖' (T8 n 이 끝 쪽으로 바꾸기 전의 출발 상태)
  param([string]$Theme, [switch]$Last, [switch]$SecondTarget)
  $piece = $script:lifeExpectPieces[$Theme]
  if ($Last) {
    return @{
      Cat    = ('btnCatBattle={0} btnCatLife={1} btnCatEtc={0}' -f $piece.CatOff, $piece.CatOn)
      Cards  = ('스킬 {1} | {1} | {1} || 대상 {0} | {2} | {2}' -f $piece.On, $piece.Off, $piece.Blank)
      Paging = ('점 ○  ○  ●/{0} | ○  ○  ○  ●/{0} · 화살표 True/False | True/False' -f $piece.Dot)
    }
  }
  if ($SecondTarget) {
    return @{
      Cat    = ('btnCatBattle={1} btnCatLife={0} btnCatEtc={0}' -f $piece.CatOff, $piece.CatOn)
      Cards  = ('스킬 {0} | {1} | {1} || 대상 {1} | {0} | {1}' -f $piece.On, $piece.Off)
      Paging = ('점 ●  ○  ○/{0} | ●  ○  ○  ○/{0} · 화살표 False/True | False/True' -f $piece.Dot)
    }
  }
  return @{
    Cat    = ('btnCatBattle={1} btnCatLife={0} btnCatEtc={0}' -f $piece.CatOff, $piece.CatOn)
    Cards  = ('스킬 {0} | {1} | {1} || 대상 {0} | {1} | {1}' -f $piece.On, $piece.Off)
    Paging = ('점 ●  ○  ○/{0} | ●  ○  ○  ○/{0} · 화살표 False/True | False/True' -f $piece.Dot)
  }
}

function Get-FormKindText {
  # 일괄 적용(Apply-HoneyTheme)의 나머지 형식 넷의 대표 - 라디오 둘 글자색 · 숫자 칸 바탕/글자색 · 콤보 바탕/글자색 · 로그 창 바탕/테두리 모양(11-13 리뷰 반영)
  return ('rbLifeGather={0} rbCustomRepeat={1} numCount={2}/{3} cboDifficulty={4}/{5} logChild={6}/{7}' -f (Get-RgbText $script:rbLifeGather.ForeColor), (Get-RgbText $script:rbCustomRepeat.ForeColor),
      (Get-RgbText $script:numCount.BackColor), (Get-RgbText $script:numCount.ForeColor), (Get-RgbText $script:cboDifficulty.BackColor), (Get-RgbText $script:cboDifficulty.ForeColor),
      (Get-RgbText $script:logChild.BackColor), $script:logChild.BorderStyle)
}

function Get-PlainKindText {
  # 일괄 적용(Apply-HoneyTheme)의 나머지 다섯 분기의 대표 - 일괄 적용 뒤에 아무것도 덮지 않는 일반 컨트롤(11-13 내부 검토 반영): Label 둘(폼 자식 · 묶음 안 패널 안 = 재귀 3단)
  # 글자색 · CheckBox 글자색 · GroupBox 글자색/바탕 · Panel 바탕 · Button 평면 모양/바탕/글자색/테두리 색/두께
  return ('plainLabel={0} innerLabel={1} plainCheck={2} plainGroup={3}/{4} plainPanel={5} plainButton={6}/{7}/{8}/{9}/{10}' -f (Get-RgbText $script:plainLabel.ForeColor),
      (Get-RgbText $script:innerLabel.ForeColor), (Get-RgbText $script:plainCheck.ForeColor), (Get-RgbText $script:plainGroup.ForeColor), (Get-RgbText $script:plainGroup.BackColor),
      (Get-RgbText $script:plainPanel.BackColor), $script:plainButton.FlatStyle, (Get-RgbText $script:plainButton.BackColor), (Get-RgbText $script:plainButton.ForeColor),
      (Get-RgbText $script:plainButton.FlatAppearance.BorderColor), $script:plainButton.FlatAppearance.BorderSize)
}

# ── T18 첫 행 (11-14 다크 입력 칸 통일 · 설계 7.13 T18d - 라이트에서는 장치도 형식도 생기지 않는다) ─────────────────────────
# 이 행은 이 프로세스에서 장치 형식(HoneyInputRecolor)을 올리기 전에 돌아야 합니다 - 한 번 올라온 형식은 내릴 수 없어, 뒤에서 돌면 '라이트만 쓰는 실행은 장치를
# 만들지도 형식을 컴파일하지도 않는다'(계약 L - 라이트 시작 화면 무변화)를 볼 수 없습니다. 형식은 뒤의 'T18d 다크 첫 호출' 이 제품 함수로 처음 올리고, T8 이후의
# 다크 전환은 이미 올라온 형식을 씁니다. 그래서 T1 보다 앞에 둡니다 - 이 자리 앞에 다크로 전체 갱신을 돌리는 행을 두면 이 행이 '전 = True' 로 실패합니다.
# 하네스 폼에서 라이트 팔레트로 시작 갱신(인자 없음) 1회 → 전체 갱신(-Full) 1회 → 두 함수를 한 번씩 직접 부릅니다(장치가 없는 라이트라 처리기는 돌지 않음)
function Invoke-T18LightOnly {
  # 스텁은 T8 장면과 같은 둘(해/달 단장 · 제목줄 - 이 함수 지역). 돌려주는 글자 = 형식 유무(전 > 뒤) | 장치 목록 · 원인 · 보관된 경고 · 로그 줄 수 | 예외
  function Update-ThemeIconStyle { }
  function Set-TitleBarTheme { param([bool]$Dark) }
  Reset-ThemeTestState
  Set-HoneyPalette -Theme 'light'
  New-ThemeHarness
  $typeBefore = [bool]('HoneyInputRecolor' -as [type])
  $lightThrown = ''
  try {
    Invoke-HoneyThemeRefresh
    Invoke-HoneyThemeRefresh -Full -RestoreState (Get-ThemeRestoreState)
    Update-InputRecolor
    Write-InputRecolorWarning
  } catch { $lightThrown = $_.Exception.Message }
  return ('{0}>{1} | 목록 없음 {2} · 원인 없음 {3} · 보관된 경고 없음 {4} · 로그 {5} | 예외 [{6}]' -f $typeBefore, [bool]('HoneyInputRecolor' -as [type]), ($null -eq $script:inputRecolorPainters),
      ($null -eq $script:inputRecolorError), ($null -eq $script:inputRecolorPendingWarning), $script:logLines.Count, $lightThrown)
}
try {
  Assert-Case 'T18 첫 행 - 라이트에서 시작 갱신 · 전체 갱신 · 두 함수 직접 호출: 장치 형식이 올라오지 않음(전 > 뒤) · 장치 목록 없음 · 원인 · 경고 · 로그 0 · 예외 0' (Invoke-T18LightOnly) `
    'False>False | 목록 없음 True · 원인 없음 True · 보관된 경고 없음 True · 로그 0 | 예외 []'
} catch { Assert-SectionError -Section 'T18 첫 행' -ErrorRecord $_ }

# ── T1 저장값 → 테마 · 다음 테마 (설계 1.4 '읽기') ───────────────────────────────────────────
try {
  $t1DarkValues = @('dark', 'Dark', 'DARK')
  $t1LightValues = @('light', $null, '', ' dark', 'dark ', $true, 1, @('dark'), [pscustomobject]@{})
  Assert-Case "T1 'dark' · 'Dark' · 'DARK' → dark" ((@($t1DarkValues | ForEach-Object { ConvertTo-UiTheme -Value $_ })) -join ',') 'dark,dark,dark'
  $t1LightResults = foreach ($t1Value in $t1LightValues) { ConvertTo-UiTheme -Value $t1Value }
  Assert-Case "T1 'light' · null · '' · 앞뒤 공백 · 참 · 1 · 배열 · 객체 → light" ((@($t1LightResults)) -join ',') 'light,light,light,light,light,light,light,light,light'
  $t1NoConfig = $null
  $t1NoUi = [pscustomobject]@{ other = 1 }
  $t1NoTheme = [pscustomobject]@{ ui = [pscustomobject]@{ logFontSize = 9 } }
  $t1DarkConfig = [pscustomobject]@{ ui = [pscustomobject]@{ theme = 'dark' } }
  Assert-Case 'T1 설정 null · ui 없음 · theme 없음 → light / theme dark → dark ($cfg.ui.theme 읽기)' ('{0},{1},{2}/{3}' -f (ConvertTo-UiTheme $t1NoConfig.ui.theme),
      (ConvertTo-UiTheme $t1NoUi.ui.theme), (ConvertTo-UiTheme $t1NoTheme.ui.theme), (ConvertTo-UiTheme $t1DarkConfig.ui.theme)) 'light,light,light/dark'
  Assert-Case "T1 Get-NextUiTheme - light→dark · dark→light · 'banana'→dark" ('{0},{1},{2}' -f (Get-NextUiTheme -Theme 'light'), (Get-NextUiTheme -Theme 'dark'), (Get-NextUiTheme -Theme 'banana')) 'dark,light,dark'
} catch { Assert-SectionError -Section 'T1' -ErrorRecord $_ }

# ── T2 팔레트 표 (설계 2.1 · H9 · H11 - 고정 리터럴) ─────────────────────────────────────────
try {
  $expectedPalette = @{
    light = [ordered]@{
      themeBack = '255,253,248,238'; themeControl = '255,255,253,247'; themeInput = '255,255,255,255'; themeLogBack = '255,40,34,24'
      themeText = '255,66,50,22'; themeMuted = '255,158,138,104'; themeBorder = '255,226,205,160'; themeTitle = '255,191,128,7'
      themeHoney = '255,247,181,0'; themeHoneyInk = '255,66,45,0'; themeDanger = '255,222,105,92'; themeSafeStop = '255,250,240,218'
      themeTabOn = '255,244,213,141'; themeTabOnText = '255,91,62,6'; themeHover = '255,250,240,218'; lifeCardSelectedBack = '255,250,240,218'
      themeListRow = '255,255,255,255'; themeListCurrent = '255,245,231,201'; themePendingBack = '255,226,205,160'
    }
    dark  = [ordered]@{
      themeBack = '255,30,30,33'; themeControl = '255,44,44,48'; themeInput = '255,23,23,26'; themeLogBack = '255,19,19,21'
      themeText = '255,232,230,227'; themeMuted = '255,154,154,160'; themeBorder = '255,62,62,68'; themeTitle = '255,242,179,61'
      themeHoney = '255,247,181,0'; themeHoneyInk = '255,42,28,0'; themeDanger = '255,224,112,95'; themeSafeStop = '255,58,56,50'
      themeTabOn = '255,104,82,34'; themeTabOnText = '255,255,240,205'; themeHover = '255,58,58,63'; lifeCardSelectedBack = '255,58,56,50'
      themeListRow = '255,23,23,26'; themeListCurrent = '255,104,82,34'; themePendingBack = '255,154,154,160'
    }
  }
  $paletteTable = Get-HoneyPaletteTable
  $paletteLightKeys = @($paletteTable['light'].Keys | Sort-Object)
  $paletteDarkKeys = @($paletteTable['dark'].Keys | Sort-Object)
  Assert-Case 'T2 표 형식 - hashtable 1개 · 바깥 키 {dark, light} · 안쪽 19/19 · 두 열 키 집합 같음' ('{0}/{1}/{2}/{3}/{4}/{5}' -f ($paletteTable -is [hashtable]), @($paletteTable).Count,
      ((@($paletteTable.Keys) | Sort-Object) -join ','), $paletteLightKeys.Count, $paletteDarkKeys.Count, (($paletteLightKeys -join ',') -ceq ($paletteDarkKeys -join ','))) 'True/1/dark,light/19/19/True'
  foreach ($paletteTheme in @('light', 'dark')) {
    $valueMismatches = @()
    foreach ($paletteKey in $expectedPalette[$paletteTheme].Keys) {
      $actualColorText = $(if ($paletteTable[$paletteTheme].ContainsKey($paletteKey)) { Get-ArgbText $paletteTable[$paletteTheme][$paletteKey] } else { '없음' })
      if ($actualColorText -cne $expectedPalette[$paletteTheme][$paletteKey]) { $valueMismatches += ('{0}={1}' -f $paletteKey, $actualColorText) }
    }
    $extraKeys = @($paletteTable[$paletteTheme].Keys | Where-Object { -not $expectedPalette[$paletteTheme].Contains($_) })
    Assert-Case ("T2 표 값 = 설계 2.1 고정 리터럴 + D7 조회 중 바탕 ({0} 19키 · 다른 키 없음)" -f $paletteTheme) (($valueMismatches + $extraKeys) -join ',') ''
    Set-HoneyPalette -Theme $paletteTheme
    $variableMismatches = @()
    foreach ($paletteKey in $expectedPalette[$paletteTheme].Keys) {
      $variableColorText = Get-ArgbText (Get-Variable -Name $paletteKey -Scope Script -ValueOnly)
      if ($variableColorText -cne $expectedPalette[$paletteTheme][$paletteKey]) { $variableMismatches += ('{0}={1}' -f $paletteKey, $variableColorText) }
    }
    Assert-Case ("T2 Set-HoneyPalette '{0}' 뒤 19 변수 = 리터럴 · uiTheme" -f $paletteTheme) ('{0}|{1}' -f ($variableMismatches -join ','), $script:uiTheme) ('|' + $paletteTheme)
  }
  $bananaRejected = $false
  try { Set-HoneyPalette -Theme 'banana' } catch { $bananaRejected = $true }
  Assert-Case "T2 Set-HoneyPalette 'banana' = 예외(ValidateSet) · 팔레트 그대로" ('{0}/{1}' -f $bananaRejected, $script:uiTheme) 'True/dark'
} catch { Assert-SectionError -Section 'T2' -ErrorRecord $_ }

# ── T3 아이콘 모양 · 색 (설계 2.5) ─────────────────────────────────────────────────────────
try {
  $t3Results = foreach ($t3Case in @(@('light', $true), @('light', $false), @('dark', $true), @('dark', $false))) {
    Set-HoneyPalette -Theme $t3Case[0]
    $iconSpec = Get-ThemeIconSpec -Theme $t3Case[0] -Enabled $t3Case[1]
    '{0}:{1}/{2}' -f ($iconSpec -is [hashtable]), $iconSpec.Shape, (Get-RgbText $iconSpec.Color)
  }
  Assert-Case 'T3 라이트 = 달/섹션 제목색 · 잠김 흐린 글자색 · 다크 = 해/꿀색 · 잠김 흐린 글자색' ((@($t3Results)) -join ' | ') 'True:moon/191,128,7 | True:moon/158,138,104 | True:sun/247,181,0 | True:sun/154,154,160'
} catch { Assert-SectionError -Section 'T3' -ErrorRecord $_ }

# ── T4 아이콘 Left 식 (설계 2.5 - Right - 폭 - 2 - 28) ──────────────────────────────────────
try {
  Assert-Case 'T4 Right 529 · 629 × 폭 40 · 139' ('{0},{1},{2},{3}' -f (Get-ThemeIconLeft -LabelRight 529 -TextWidth 40), (Get-ThemeIconLeft -LabelRight 529 -TextWidth 139),
      (Get-ThemeIconLeft -LabelRight 629 -TextWidth 40), (Get-ThemeIconLeft -LabelRight 629 -TextWidth 139)) '459,360,559,460'
} catch { Assert-SectionError -Section 'T4' -ErrorRecord $_ }

# ── T5 상태줄 의미 기록 · 되살리기 (설계 2.4 ① - 헤드리스 Label + 등록 문장 점소싱) ──────────────────────────
function New-StatusLabel {
  # 상태줄 Label 하나 + 소스 등록 문장 (생성 색 DimGray 는 등록 전이라 기록되지 않음 - gui 생성 순서)
  Reset-ThemeTestState
  Set-HoneyPalette -Theme 'light'
  if ($script:lblStatus) { try { $script:lblStatus.Dispose() } catch { } }
  $script:lblStatus = New-Object System.Windows.Forms.Label
  $script:lblStatus.ForeColor = [System.Drawing.Color]::DimGray
  if ($script:layerRegistrationText) { . ([scriptblock]::Create($script:layerRegistrationText)) }
}
try {
  New-StatusLabel
  $t5Records = foreach ($t5Name in @('Firebrick', 'ForestGreen', 'SteelBlue', 'DimGray', 'DarkOrange')) {
    $script:lblStatus.ForeColor = [System.Drawing.Color]::FromName($t5Name)
    '{0}={1}' -f $t5Name, (Format-StatusMeaning -Meaning (Get-StatusColorMeaning))
  }
  $script:lblStatus.ForeColor = $script:themeTitle
  $t5TitleRecord = Format-StatusMeaning -Meaning (Get-StatusColorMeaning)
  $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(10, 20, 30)
  $t5OtherRecord = Format-StatusMeaning -Meaning (Get-StatusColorMeaning)
  Assert-Case 'T5 기록 - 이름 색 5개 = 그 색(이름 유지)' ((@($t5Records)) -join ' ') 'Firebrick=Firebrick/-5103070 ForestGreen=ForestGreen/-14513374 SteelBlue=SteelBlue/-12156236 DimGray=DimGray/-9868951 DarkOrange=DarkOrange/-29696'
  Assert-Case "T5 기록 - 지금 섹션 제목색 = 'Title' · 그 밖 = 그 색 · Get-StatusColorMeaning = 기록" ('{0}/{1}/{2}' -f $t5TitleRecord, $t5OtherRecord,
      ((Format-StatusMeaning -Meaning (Get-StatusColorMeaning)) -ceq (Format-StatusMeaning -Meaning $script:statusColorMeaning))) ('Title/ff0a141e/{0}/True' -f ([System.Drawing.Color]::FromArgb(10, 20, 30).ToArgb()))
  # Apply 처럼 기본 글자색으로 덮은 뒤 잡아 둔 의미로 되살림 - 이름 색은 이름 유지, Title 은 새 팔레트의 Title
  $script:lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
  $t5Held = Get-StatusColorMeaning
  $script:lblStatus.ForeColor = $script:themeText
  Set-HoneyPalette -Theme 'dark'
  Restore-StatusColorMeaning -Meaning $t5Held
  $t5DarkFirebrick = '{0}/{1}' -f (Get-RgbText $script:lblStatus.ForeColor), (Format-StatusMeaning -Meaning $script:statusColorMeaning)
  Set-HoneyPalette -Theme 'light'
  Restore-StatusColorMeaning -Meaning $t5Held
  $t5LightFirebrick = $script:lblStatus.ForeColor.Name
  Assert-Case 'T5 되살리기 - Firebrick 의미: 다크 표시 255,110,110 · 의미 유지 / 라이트 이름 Firebrick' ('{0} | {1}' -f $t5DarkFirebrick, $t5LightFirebrick) ('255,110,110/Firebrick/{0} | Firebrick' -f [System.Drawing.Color]::Firebrick.ToArgb())
  $script:lblStatus.ForeColor = $script:themeTitle
  $t5HeldTitle = Get-StatusColorMeaning
  $script:lblStatus.ForeColor = $script:themeText
  Set-HoneyPalette -Theme 'dark'
  Restore-StatusColorMeaning -Meaning $t5HeldTitle
  Assert-Case "T5 되살리기 - 'Title' 의미: 다크 Title 242,179,61 · 의미 'Title'" ('{0}/{1}' -f (Get-RgbText $script:lblStatus.ForeColor), (Format-StatusMeaning -Meaning $script:statusColorMeaning)) '242,179,61/Title'
} catch { Assert-SectionError -Section 'T5' -ErrorRecord $_ }

# ── T5b 층 처리기 (설계 2.4 ② · V6) ─────────────────────────────────────────────────────────
function Invoke-T5bCounted {
  # 대응 함수 호출 수를 세며 상태줄에 색 1회 대입 - 처리기 재진입이 있으면 대응 함수가 두 번 불립니다(가드 없이 다시 칠하면 같은 이벤트가 또 옴)
  param($Color)
  $script:t5bDisplayCalls = 0
  function Get-StatusDisplayColor {
    param([System.Drawing.Color]$Color, [string]$Theme)
    $script:t5bDisplayCalls++
    return (& $script:realBlocks['Get-StatusDisplayColor'] -Color $Color -Theme $Theme)
  }
  $script:lblStatus.ForeColor = $Color
  return $script:t5bDisplayCalls
}
function Invoke-T5bFault {
  # 처리기 안에서 예외 1회 (대응 함수가 던짐) - 바깥으로 새면 모달 창이므로 처리기가 받아야 하고, 가드는 finally 로 풀려야 합니다
  param($Color)
  function Get-StatusDisplayColor { param([System.Drawing.Color]$Color, [string]$Theme) throw '층 주입 예외' }
  $faultThrown = ''
  try { $script:lblStatus.ForeColor = $Color } catch { $faultThrown = $_.Exception.Message }
  return $faultThrown
}
try {
  New-StatusLabel
  $t5bNames = @('Firebrick', 'ForestGreen', 'SteelBlue', 'DimGray', 'DarkOrange')
  $t5bLight = foreach ($t5bName in $t5bNames) {
    $script:lblStatus.ForeColor = [System.Drawing.Color]::FromName($t5bName)
    '{0}={1}' -f $t5bName, ($script:lblStatus.ForeColor.Name -ceq $t5bName)
  }
  $script:lblStatus.ForeColor = $script:themeTitle
  Assert-Case 'T5b 라이트 항등 - 이름 색 5개 · Title 은 칠한 그대로' ('{0} Title={1}' -f ((@($t5bLight)) -join ' '), (Get-RgbText $script:lblStatus.ForeColor)) 'Firebrick=True ForestGreen=True SteelBlue=True DimGray=True DarkOrange=True Title=191,128,7'
  Set-HoneyPalette -Theme 'dark'
  $t5bDark = foreach ($t5bName in $t5bNames) {
    $script:lblStatus.ForeColor = [System.Drawing.Color]::FromName($t5bName)
    '{0}={1}' -f $t5bName, (Get-RgbText $script:lblStatus.ForeColor)
  }
  $script:lblStatus.ForeColor = $script:themeTitle
  $t5bDarkTitle = Get-RgbText $script:lblStatus.ForeColor
  $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(10, 20, 30)
  $t5bDarkOther = Get-RgbText $script:lblStatus.ForeColor
  Assert-Case 'T5b 다크 대응 - 2.4 표(Firebrick · ForestGreen · SteelBlue · DimGray 만 바꿈) · Title · 그 밖 통과' ('{0} Title={1} 그밖={2}' -f ((@($t5bDark)) -join ' '), $t5bDarkTitle, $t5bDarkOther) `
    'Firebrick=255,110,110 ForestGreen=144,238,144 SteelBlue=135,206,235 DimGray=154,154,160 DarkOrange=255,140,0 Title=242,179,61 그밖=10,20,30'
  $script:lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
  $t5bFirst = '{0}/{1}' -f (Get-RgbText $script:lblStatus.ForeColor), (Format-StatusMeaning -Meaning $script:statusColorMeaning)
  $script:lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
  $t5bSecond = '{0}/{1}' -f (Get-RgbText $script:lblStatus.ForeColor), (Format-StatusMeaning -Meaning $script:statusColorMeaning)
  Assert-Case 'T5b 멱등 - 같은 색 두 번 = 같은 표시 · 같은 의미' ('{0} = {1}' -f $t5bFirst, $t5bSecond) ('255,110,110/Firebrick/{0} = 255,110,110/Firebrick/{0}' -f [System.Drawing.Color]::Firebrick.ToArgb())
  $script:lblStatus.ForeColor = [System.Drawing.Color]::DimGray
  $t5bCalls = Invoke-T5bCounted -Color ([System.Drawing.Color]::ForestGreen)
  Assert-Case 'T5b 재진입 0 - 다크 대입 1회에 대응 함수 1회 · 의미 ForestGreen' ('{0}/{1}' -f $t5bCalls, $script:statusColorMeaning.Name) '1/ForestGreen'
  $script:logLines.Clear()
  $t5bFaultThrown = Invoke-T5bFault -Color ([System.Drawing.Color]::SteelBlue)
  $t5bAfterFault = '{0}|{1}|{2}' -f $t5bFaultThrown, $script:logLines.Count, ([string]$script:statusLayerError)
  $script:lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
  $t5bRecovered = Get-RgbText $script:lblStatus.ForeColor
  $t5bSecondFault = Invoke-T5bFault -Color ([System.Drawing.Color]::DimGray)
  Assert-Case 'T5b 처리기 예외 - 밖으로 0 · 첫 예외 [경고] 1줄 · 원인 보관 / 뒤 대입은 다시 대응(가드 풀림) / 둘째 예외 로그 0줄' `
    ('{0} / {1} / [{2}] {3}' -f $t5bAfterFault, $t5bRecovered, $t5bSecondFault, $script:logLines.Count) '|1|층 주입 예외 / 255,110,110 / [] 1'
  Assert-Case 'T5b 첫 예외 [경고] 줄 - 원인 포함' (($script:logLines.Count -ge 1) -and $script:logLines[0].StartsWith('[경고]') -and $script:logLines[0].Contains('층 주입 예외')) $true
} catch { Assert-SectionError -Section 'T5b' -ErrorRecord $_ }

# ── T6 ui.theme 저장 (설계 1.4 · H5 · K1 - 실제 Read-Config · Save-Config, 임시 config) ─────────────────
$t6Root = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ('honeynogi_theme_test_' + [guid]::NewGuid().ToString('N')))
[void][System.IO.Directory]::CreateDirectory($t6Root)
$configPath = [System.IO.Path]::Combine($t6Root, 'config.json')
$t6Bom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true
function Invoke-T6Save {
  # Save-UiThemeState 1회 - 남긴 줄 · 밖으로 나온 예외. -ThrowingLog 면 로그가 받은 줄을 남기고 던집니다(K1 꼴 - 기록 실패가 밖으로 새면 안 됨)
  param([switch]$ThrowingLog)
  if ($ThrowingLog) { function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message); throw '기록 주입 예외' } }
  $script:logLines.Clear()
  $saveThrown = ''
  try { Save-UiThemeState } catch { $saveThrown = $_.Exception.Message }
  return @{ Lines = @($script:logLines); Thrown = $saveThrown }
}
function Set-T6Config {
  # 임시 config 를 글자 그대로 씁니다 (BOM)
  param([string]$Text)
  [System.IO.File]::WriteAllText($script:configPath, $Text, $script:t6Bom)
}
function Get-T6Bytes { return [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($script:configPath)) }
try {
  Reset-ThemeTestState
  # uiReady 거짓(시작 로딩 중) → 쓰기 0
  Set-T6Config '{ "ui": { "theme": "light" } }'
  $t6BytesBefore = Get-T6Bytes
  $script:uiReady = $false
  $script:uiTheme = 'dark'
  $t6Row = Invoke-T6Save
  Assert-Case 'T6 uiReady 거짓 → 쓰기 0 · 줄 0 · 예외 0' ('{0}/{1}/[{2}]' -f ((Get-T6Bytes) -ceq $t6BytesBefore), $t6Row.Lines.Count, $t6Row.Thrown) 'True/0/[]'
  $script:uiReady = $true
  # ui 없음 → 만듦 · 다른 키 보존 · 값은 문자열
  Set-T6Config '{ "a": 1 }'
  $t6Row = Invoke-T6Save
  $t6Saved = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case 'T6 ui 없음 → ui 만듦 · theme dark(문자열) · 다른 키 보존 · 줄 0' ('{0}/{1}/{2}/{3}' -f [string]$t6Saved.ui.theme, ($t6Saved.ui.theme -is [string]), $t6Saved.a, $t6Row.Lines.Count) 'dark/True/1/0'
  # 다른 ui 키 보존 (theme 이 이미 있으면 그 값만 바꿈)
  Set-T6Config '{ "ui": { "logFontSize": 17, "settingsOpen": true, "logOpen": false, "theme": "light" } }'
  $t6Row = Invoke-T6Save
  $t6Saved = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case 'T6 다른 ui 키 보존 · theme 만 바뀜' ('{0}/{1}/{2}/{3}/{4}' -f $t6Saved.ui.logFontSize, $t6Saved.ui.settingsOpen, $t6Saved.ui.logOpen, [string]$t6Saved.ui.theme, $t6Row.Lines.Count) '17/True/False/dark/0'
  $script:uiTheme = 'light'
  $t6Row = Invoke-T6Save
  $t6Saved = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case 'T6 라이트로 다시 저장 → light(문자열)' ('{0}/{1}' -f [string]$t6Saved.ui.theme, ($t6Saved.ui.theme -is [string])) 'light/True'
  # Save-Config 실패(대상 잠김) → [경고] 1줄(원인 포함) · 예외 0 · 파일 그대로
  $script:uiTheme = 'dark'
  $t6BytesBefore = Get-T6Bytes
  $t6Lock = [System.IO.File]::Open($configPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  try {
    $t6ReferenceCause = ''
    try { Save-Config (Read-Config) } catch { $t6ReferenceCause = $_.Exception.Message }
    $t6Row = Invoke-T6Save
    $t6RowThrowing = Invoke-T6Save -ThrowingLog
  } finally { $t6Lock.Dispose() }
  $t6WriteLine = $(if ($t6Row.Lines.Count -ge 1) { [string]$t6Row.Lines[0] } else { '' })
  Assert-Case 'T6 쓰기 실패 → [경고] 1줄 · 원인 포함 · 예외 0 · 파일 그대로' ('{0}/{1}/{2}/[{3}]/{4}' -f $t6Row.Lines.Count, $t6WriteLine.StartsWith('[경고]'),
      (($t6ReferenceCause -ne '') -and $t6WriteLine.Contains($t6ReferenceCause)), $t6Row.Thrown, ((Get-T6Bytes) -ceq $t6BytesBefore)) '1/True/True/[]/True'
  Assert-Case 'T6 쓰기 실패 + 로그 기록도 던짐 → 예외 0(시도 1줄)' ('[{0}]/{1}' -f $t6RowThrowing.Thrown, $t6RowThrowing.Lines.Count) '[]/1'
  # 파일 없음 → [경고] 1줄('파일이 없습니다' 포함) · 파일 계속 없음 · 예외 0
  [System.IO.File]::Delete($configPath)
  $t6Row = Invoke-T6Save
  $t6MissingLine = $(if ($t6Row.Lines.Count -ge 1) { [string]$t6Row.Lines[0] } else { '' })
  Assert-Case "T6 파일 없음 → [경고] 1줄('파일이 없습니다') · 파일 계속 없음 · 예외 0" ('{0}/{1}/{2}/{3}/[{4}]' -f $t6Row.Lines.Count, $t6MissingLine.StartsWith('[경고]'),
      $t6MissingLine.Contains('파일이 없습니다'), [System.IO.File]::Exists($configPath), $t6Row.Thrown) '1/True/True/False/[]'
  $t6RowThrowing = Invoke-T6Save -ThrowingLog
  Assert-Case 'T6 파일 없음 + 로그 기록도 던짐 → 예외 0(시도 1줄)' ('[{0}]/{1}' -f $t6RowThrowing.Thrown, $t6RowThrowing.Lines.Count) '[]/1'
  # JSON 손상 → [경고] 1줄(파싱 원인 포함) · 바이트 그대로 · 예외 0
  Set-T6Config '{잘못된 JSON'
  $t6BytesBefore = Get-T6Bytes
  $t6Row = Invoke-T6Save
  $t6CorruptLine = $(if ($t6Row.Lines.Count -ge 1) { [string]$t6Row.Lines[0] } else { '' })
  Assert-Case 'T6 JSON 손상 → [경고] 1줄(파싱 원인 포함) · 바이트 그대로 · 예외 0' ('{0}/{1}/{2}/{3}/[{4}]' -f $t6Row.Lines.Count, $t6CorruptLine.StartsWith('[경고]'),
      ((-not [string]::IsNullOrEmpty($script:configReadError)) -and $t6CorruptLine.Contains([string]$script:configReadError)), ((Get-T6Bytes) -ceq $t6BytesBefore), $t6Row.Thrown) '1/True/True/True/[]'
} catch { Assert-SectionError -Section 'T6' -ErrorRecord $_ }

# ── T7 라이트 = 지금 (설계 2.2 #4 · #5 · #8 - 토글 · 리스트 · 콤보) ─────────────────────────────────
function Get-T7ListText {
  # 표 하나 → '이름:바탕/글자/행 바탕들'. -SystemCheck 면 바탕 · 글자가 시스템 기본(Window · WindowText)인지를 적습니다(라이트는 칠하지 않고 되돌리는 계약)
  param($List, [switch]$SystemCheck)
  $rowsText = (@($List.Items) | ForEach-Object { Get-RgbText $_.BackColor }) -join ';'
  if ($SystemCheck) { return ('{0}:{1}/{2}/{3}' -f $List.Name, ($List.BackColor -eq [System.Drawing.SystemColors]::Window), ($List.ForeColor -eq [System.Drawing.SystemColors]::WindowText), $rowsText) }
  return ('{0}:{1}/{2}/{3}' -f $List.Name, (Get-RgbText $List.BackColor), (Get-RgbText $List.ForeColor), $rowsText)
}
try {
  Reset-ThemeTestState
  Set-HoneyPalette -Theme 'light'
  New-ThemeHarness
  $script:chkTabSettings.Checked = $true
  Update-TabToggleStyle
  $script:chkCrRandom.Checked = $true
  Update-CustomRandomToggleStyle -Toggle $script:chkCrRandom
  Update-CustomRandomToggleStyle -Toggle $script:chkAcrRandom
  $t7Toggles = foreach ($t7Toggle in @($script:chkTabSettings, $script:chkTabLog, $script:chkCrRandom, $script:chkAcrRandom)) {
    '{0}:{1}/{2}/{3}/{4}' -f $t7Toggle.Name, $t7Toggle.FlatAppearance.CheckedBackColor.IsEmpty, (Get-RgbText $t7Toggle.FlatAppearance.BorderColor), (Get-RgbText $t7Toggle.BackColor), (Get-RgbText $t7Toggle.ForeColor)
  }
  Assert-Case 'T7 라이트 토글 - 눌린 바탕 빈 값 · 테두리 226,205,160 · 눌림 244,213,141/91,62,6 · 안 눌림 255,253,247/66,50,22' ((@($t7Toggles)) -join ' | ') `
    'chkTabSettings:True/226,205,160/244,213,141/91,62,6 | chkTabLog:True/226,205,160/255,253,247/66,50,22 | chkCrRandom:True/226,205,160/244,213,141/91,62,6 | chkAcrRandom:True/226,205,160/255,253,247/66,50,22'
  Update-ListThemeColors
  $t7ListLight = '{0}/{1}/{2}/{3}/{4}' -f ($script:lvCrList.BackColor -eq [System.Drawing.SystemColors]::Window), ($script:lvCrList.ForeColor -eq [System.Drawing.SystemColors]::WindowText),
    ($script:cellEditCombo.BackColor -eq [System.Drawing.SystemColors]::Window), ($script:cellEditCombo.ForeColor -eq [System.Drawing.SystemColors]::WindowText),
    ((@($script:lvCrList.Items) | ForEach-Object { Get-ArgbText $_.BackColor }) -join ',')
  Assert-Case 'T7 라이트 리스트 · 콤보 = 시스템 기본(Window · WindowText) · 행 흰색' $t7ListLight 'True/True/True/True/255,255,255,255,255,255,255,255,255,255,255,255'
  Set-HoneyPalette -Theme 'dark'
  Update-ListThemeColors
  Set-HoneyPalette -Theme 'light'
  Update-ListThemeColors
  $t7ListBack = '{0}/{1}/{2}/{3}' -f ($script:lvCrList.BackColor -eq [System.Drawing.SystemColors]::Window), ($script:lvCrList.ForeColor -eq [System.Drawing.SystemColors]::WindowText),
    ($script:cellEditCombo.BackColor -eq [System.Drawing.SystemColors]::Window), ($script:cellEditCombo.ForeColor -eq [System.Drawing.SystemColors]::WindowText)
  Assert-Case 'T7 다크 → 라이트 뒤 리스트 · 콤보 = 시스템 기본으로 되돌림(Reset - 칠한 흰색이 아님)' $t7ListBack 'True/True/True/True'
  # 표 4개를 서로 다른 객체로(11-13 리뷰 지적): 하네스는 표 하나를 네 이름에 걸어 두어, 갱신 함수의 목록에서 표 하나가 빠져도 위 행과 T8 · T13 은
  # 같은 객체를 칠해 통과합니다(빠지면 실사용에서 그 콘텐츠의 커스텀 리스트만 다크에서 흰 표로 남음). 그래서 나머지 세 이름에 각자의 표를 걸고,
  # 모든 행에 다른 색(1,2,3)을 먼저 칠해 '행 칠하기' 목록에서 빠진 표도 드러나게 한 뒤 다크 → 라이트를 봅니다. 콤보는 다크 값까지 봅니다(위 행은 되돌린 값만 봄)
  $t7ExtraLists = @()
  try {
    foreach ($t7ListName in @('lvAcrList', 'lvDcrList', 'lvLcrList')) {
      $t7ExtraList = New-Object System.Windows.Forms.ListView
      $t7ExtraList.Name = $t7ListName
      foreach ($rowNumber in 1..3) { [void]$t7ExtraList.Items.Add((New-Object System.Windows.Forms.ListViewItem(('항목' + $rowNumber)))) }
      Set-Variable -Name $t7ListName -Scope Script -Value $t7ExtraList
      $t7ExtraLists += $t7ExtraList
    }
    $t7AllLists = @($script:lvCrList) + $t7ExtraLists
    foreach ($t7List in $t7AllLists) { foreach ($t7Item in $t7List.Items) { $t7Item.BackColor = [System.Drawing.Color]::FromArgb(1, 2, 3) } }
    Set-HoneyPalette -Theme 'dark'
    Update-ListThemeColors
    $t7FourDark = '{0} | combo:{1}/{2}' -f ((@($t7AllLists | ForEach-Object { Get-T7ListText -List $_ })) -join ' | '), (Get-RgbText $script:cellEditCombo.BackColor),
      (Get-RgbText $script:cellEditCombo.ForeColor)
    Set-HoneyPalette -Theme 'light'
    Update-ListThemeColors
    $t7FourLight = '{0} | combo:{1}/{2}' -f ((@($t7AllLists | ForEach-Object { Get-T7ListText -List $_ -SystemCheck })) -join ' | '),
      ($script:cellEditCombo.BackColor -eq [System.Drawing.SystemColors]::Window), ($script:cellEditCombo.ForeColor -eq [System.Drawing.SystemColors]::WindowText)
    $t7ListNames = @('lvCrList', 'lvAcrList', 'lvDcrList', 'lvLcrList')
    Assert-Case 'T7 표 4개(서로 다른 객체) · 콤보 - 다크: 바탕 23,23,26 · 글자 232,230,227 · 행 23,23,26 (목록에서 하나라도 빠지면 그 표가 갈림)' $t7FourDark `
      (((@($t7ListNames | ForEach-Object { '{0}:23,23,26/232,230,227/23,23,26;23,23,26;23,23,26' -f $_ })) -join ' | ') + ' | combo:23,23,26/232,230,227')
    Assert-Case 'T7 표 4개 · 콤보 - 다시 라이트: 시스템 기본(Window · WindowText) · 행 흰색' $t7FourLight `
      (((@($t7ListNames | ForEach-Object { '{0}:True/True/255,255,255;255,255,255;255,255,255' -f $_ })) -join ' | ') + ' | combo:True/True')
  } finally {
    foreach ($t7ExtraList in $t7ExtraLists) { try { $t7ExtraList.Dispose() } catch { } }
    $script:lvAcrList = $script:lvCrList
    $script:lvDcrList = $script:lvCrList
    $script:lvLcrList = $script:lvCrList
  }
} catch { Assert-SectionError -Section 'T7' -ErrorRecord $_ }

# ── T9 리스트 행(안 B - 다크 팔레트로 실행 중 표시 · 정지 복원) ──────────────────────────────────────
try {
  Reset-ThemeTestState
  Set-HoneyPalette -Theme 'dark'
  New-ThemeHarness
  Set-CustomListRandomView -Context @{ RandomOrder = $false; RegisteredTotal = 3; Index = 1; SectionName = 'customRepeat' }
  $t9Plain = (@($script:lvCrList.Items) | ForEach-Object { Get-RgbText $_.BackColor }) -join ' | '
  Set-CustomListRandomView -Context @{ RandomOrder = $true; Order = @(2, 0, 1); Total = 3; Index = 0; SectionName = 'customRepeat' }
  $t9Random = (@($script:lvCrList.Items) | ForEach-Object { '{0}={1}' -f $_.SubItems[2].Text, (Get-RgbText $_.BackColor) }) -join ' | '
  Restore-CustomListRegisteredView
  $t9Restored = (@($script:lvCrList.Items) | ForEach-Object { '{0}={1}' -f $_.SubItems[2].Text, (Get-RgbText $_.BackColor) }) -join ' | '
  Assert-Case 'T9 다크 비랜덤 - 평소 행 23,23,26 · 지금 판 104,82,34' $t9Plain '23,23,26 | 104,82,34 | 23,23,26'
  Assert-Case 'T9 다크 랜덤 - 순열 순서 · 첫 행 지금 판' $t9Random '항목3=104,82,34 | 항목1=23,23,26 | 항목2=23,23,26'
  Assert-Case 'T9 다크 정지 복원 - 등록 순서 · 강조 0' $t9Restored '항목1=23,23,26 | 항목2=23,23,26 | 항목3=23,23,26'
} catch { Assert-SectionError -Section 'T9' -ErrorRecord $_ }

# ── T10 아이콘 기하 (설계 1.6 H7 - 글자는 소스의 대입식 그대로) ─────────────────────────────────────
$linkTextAssignments = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -ceq '$lnkUpdate.Text') }, $true))
$versionTextAssignments = @($topStatements | Where-Object { ($_ -is $assignType) -and ($_.Left.Extent.Text -ceq '$lblVersion.Text') })
function Get-SourceText {
  # 소스의 글자 대입식을 그 변수 값으로 펼칩니다 (예: "v$remoteVersion 다운로드") - 지역 변수를 보도록 이 함수 안에서 점소싱
  param([string]$Expression, [string]$VariableName, $Value)
  Set-Variable -Name $VariableName -Value $Value
  return [string](. ([scriptblock]::Create($Expression)))
}
try {
  Assert-Case 'T10 준비 - 링크 글자 대입 1 · 버전 글자 대입(최상위) 1' ('{0}/{1}' -f $linkTextAssignments.Count, $versionTextAssignments.Count) '1/1'
  if (($linkTextAssignments.Count -eq 1) -and ($versionTextAssignments.Count -eq 1)) {
    $t10Form = New-Object System.Windows.Forms.Form
    $t10Form.Size = New-Object System.Drawing.Size(560, 881)
    $t10Form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $t10ClearLog = New-HarnessControl -TypeName 'Button' -Name 'btnClearLog' -X 280 -Y 806 -Width 80 -Height 28 -Parent $t10Form
    $t10Version = New-HarnessControl -TypeName 'Label' -Name 'lblVersion' -X 369 -Y 812 -Width 160 -Height 20 -Parent $t10Form
    $t10Version.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $t10Link = New-HarnessControl -TypeName 'LinkLabel' -Name 'lnkUpdate' -X 369 -Y 812 -Width 160 -Height 20 -Parent $t10Form
    $t10Link.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $t10Icon = New-HarnessControl -TypeName 'Button' -Name 'icon' -X 0 -Y 806 -Width 28 -Height 28 -Parent $t10Form
    $t10Version.Text = Get-SourceText -Expression $versionTextAssignments[0].Right.Extent.Text -VariableName 'appVersion' -Value '2.1.12'
    Update-ThemeIconPlacement -Button $t10Icon -Label $t10Version
    $t10VersionWidth = [System.Windows.Forms.TextRenderer]::MeasureText($t10Version.Text, $t10Version.Font).Width
    Assert-Case "T10 버전 글자 'v2.1.12' → Left = Right - 폭 - 30" ('{0}/{1}' -f $t10Version.Text, ($t10Icon.Left -eq ($t10Version.Right - $t10VersionWidth - 30))) 'v2.1.12/True'
    "INFO T10 버전 글자 폭 {0} → Left {1} (설계 실측 100% 456)" -f $t10VersionWidth, $t10Icon.Left
    foreach ($t10RemoteVersion in @('2.1.13', '2.10.10')) {
      $t10Link.Text = Get-SourceText -Expression $linkTextAssignments[0].Right.Extent.Text -VariableName 'remoteVersion' -Value ([System.Version]$t10RemoteVersion)
      Update-ThemeIconPlacement -Button $t10Icon -Label $t10Link
      Assert-Case ("T10 링크 '{0}' → 아이콘 Left ≥ '로그 지우기' 오른쪽 끝 + 4" -f $t10Link.Text) ($t10Icon.Left -ge ($t10ClearLog.Right + 4)) $true
      "INFO T10 링크 '{0}' 폭 {1} → Left {2} (설계 실측 405 · 399)" -f $t10Link.Text, [System.Windows.Forms.TextRenderer]::MeasureText($t10Link.Text, $t10Link.Font).Width, $t10Icon.Left
    }
    $t10Form.Dispose()
  }
} catch { Assert-SectionError -Section 'T10' -ErrorRecord $_ }

# ── T11 대분류 아이콘 키 (설계 2.2 #3) ─────────────────────────────────────────────────────────
try {
  $t11Icons = @{ catBattle = 1; catBattleDark = 2; catLife = 3 }
  Assert-Case "T11 light×활성 → 원본 · light×비활성 → 'Dark' 사본 · dark×활성/비활성 → 원본 · 사본 없음 → 원본" ('{0},{1},{2},{3},{4}' -f
      (Get-MainCatPaintIconKey -IconKey 'catBattle' -Active $true -Theme 'light' -Icons $t11Icons), (Get-MainCatPaintIconKey -IconKey 'catBattle' -Active $false -Theme 'light' -Icons $t11Icons),
      (Get-MainCatPaintIconKey -IconKey 'catBattle' -Active $true -Theme 'dark' -Icons $t11Icons), (Get-MainCatPaintIconKey -IconKey 'catBattle' -Active $false -Theme 'dark' -Icons $t11Icons),
      (Get-MainCatPaintIconKey -IconKey 'catLife' -Active $false -Theme 'light' -Icons $t11Icons)) 'catBattle,catBattleDark,catBattle,catBattle,catLife'
} catch { Assert-SectionError -Section 'T11' -ErrorRecord $_ }

# T11 배선(11-13 리뷰 지적): 위 진리표는 순수 함수만 봅니다. 대분류 Paint(Invoke-MainCatButtonPaint)가 그 함수를 지금 테마 · 활성 상태로 부르는 배선은,
# 원래 가드(test_audit_fixes 의 틴트 문자열)가 순수 함수 안으로 옮겨 가며 아무도 지키지 않게 됐습니다. 호출 줄이 빠지거나 인자가 바뀌면(-Active $true ·
# -Theme 'dark' 등) 라이트 비활성 버튼에 흰 원본이 크림 바탕 위에 그려져 아이콘이 사실상 사라집니다(계약 L). 그래서 실함수를 제품과 같은 크기 · 글자의
# 버튼과 그림판에 단색 가짜 아이콘(원본 = 흰색 · 'Dark' 사본 = 진갈색, 12x12)으로 돌려 그려진 색을 셉니다(11-13 실측: 그린 쪽 144화소 · 다른 쪽 0)
function New-SolidTestIcon {
  # 단색 12x12 가짜 아이콘
  param([int]$Red, [int]$Green, [int]$Blue)
  $solidIcon = New-Object System.Drawing.Bitmap(12, 12)
  $solidGraphics = [System.Drawing.Graphics]::FromImage($solidIcon)
  try { $solidGraphics.Clear([System.Drawing.Color]::FromArgb(255, $Red, $Green, $Blue)) } finally { $solidGraphics.Dispose() }
  return $solidIcon
}
function Get-MainCatPaintedIcon {
  # 대분류 버튼 Paint 1회 → 그려진 아이콘('Dark' 사본 / 원본 / 둘 다 아님 - 화소 수). Paint 함수는 예외를 삼키므로 아무것도 안 그리면 '둘 다 아님' 으로 드러납니다
  param([string]$Theme, [string]$Category)
  $script:uiTheme = $Theme
  $script:mainCategory = $Category
  $canvas = New-Object System.Drawing.Bitmap(168, 32)
  try {
    $canvasGraphics = [System.Drawing.Graphics]::FromImage($canvas)
    try {
      $canvasGraphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 255))
      Invoke-MainCatButtonPaint -Sender $script:t11Sender -PaintArgs ([System.Windows.Forms.PaintEventArgs]::new($canvasGraphics, [System.Drawing.Rectangle]::new(0, 0, 168, 32)))
    } finally { $canvasGraphics.Dispose() }
    $whiteCount = 0
    $brownCount = 0
    for ($pixelY = 0; $pixelY -lt 32; $pixelY++) {
      for ($pixelX = 0; $pixelX -lt 168; $pixelX++) {
        $pixel = $canvas.GetPixel($pixelX, $pixelY)
        if (([Math]::Abs($pixel.R - 255) + [Math]::Abs($pixel.G - 255) + [Math]::Abs($pixel.B - 255)) -le 10) { $whiteCount++ }
        elseif (([Math]::Abs($pixel.R - 66) + [Math]::Abs($pixel.G - 50) + [Math]::Abs($pixel.B - 22)) -le 10) { $brownCount++ }
      }
    }
  } finally { $canvas.Dispose() }
  if (($brownCount -ge 100) -and ($whiteCount -eq 0)) { return 'Dark' }
  if (($whiteCount -ge 100) -and ($brownCount -eq 0)) { return '원본' }
  return ('둘 다 아님(흰 {0} · 진갈 {1})' -f $whiteCount, $brownCount)
}
try {
  $script:lifeSkillIcons = @{ catBattle = (New-SolidTestIcon -Red 255 -Green 255 -Blue 255); catBattleDark = (New-SolidTestIcon -Red 66 -Green 50 -Blue 22) }
  $script:t11Sender = New-Object System.Windows.Forms.Button
  $script:t11Sender.Name = 'btnCatBattle'
  $script:t11Sender.Size = New-Object System.Drawing.Size(168, 32)
  $script:t11Sender.Text = '전투'
  try {
    $t11Painted = foreach ($t11Case in @(@('light', 'life', '비활성'), @('light', 'battle', '활성'), @('dark', 'life', '비활성'), @('dark', 'battle', '활성'))) {
      '{0}×{1}={2}' -f $t11Case[0], $t11Case[2], (Get-MainCatPaintedIcon -Theme $t11Case[0] -Category $t11Case[1])
    }
    Assert-Case "T11 배선 - 실함수 Invoke-MainCatButtonPaint 가 그린 아이콘: light×비활성 = 'Dark' 사본 · 그 밖 = 흰 원본" ((@($t11Painted)) -join ' ') 'light×비활성=Dark light×활성=원본 dark×비활성=원본 dark×활성=원본'
  } finally {
    foreach ($t11Icon in @($script:lifeSkillIcons.Values)) { try { $t11Icon.Dispose() } catch { } }
    try { $script:t11Sender.Dispose() } catch { }
    $script:lifeSkillIcons = $null
    $script:mainCategory = $null
  }
} catch { Assert-SectionError -Section 'T11 배선' -ErrorRecord $_ }

# ── T12 Invoke-ThemeSwitch 분기 (설계 1.2 · H2 · H3 · K1 - 호출 기록 스텁) ─────────────────────────────
function Invoke-T12Switch {
  # 전환 1회를 호출 기록 스텁으로 돌립니다. -Plan: StateThrow · SetThrowTheme · RefreshThrow('dark' 등 테마 / 'always') · LogThrow.
  # 상태 잡기마다 번호를 매긴 객체를 돌려주고, 갱신은 받은 객체 번호를 적어 '두 갱신이 (1) 의 같은 객체' 인지 봅니다(되돌림에서 다시 잡으면 #2 가 됨)
  param([hashtable]$Plan, [string]$From, [string]$To, [switch]$Save)
  $script:t12Events = New-Object System.Collections.Generic.List[string]
  $script:t12Lines = New-Object System.Collections.Generic.List[string]
  $script:t12StateCount = 0
  $script:t12Plan = $Plan
  function Get-ThemeRestoreState {
    $script:t12Events.Add('state')
    if ($script:t12Plan.StateThrow) { throw '상태 실패' }
    $script:t12StateCount++
    return @{ Marker = $script:t12StateCount }
  }
  function Set-HoneyPalette {
    param([string]$Theme)
    $script:t12Events.Add('set:' + $Theme)
    if ($script:t12Plan.SetThrowTheme -eq $Theme) { throw ('팔레트 실패 ' + $Theme) }
    $script:uiTheme = $Theme
  }
  function Invoke-HoneyThemeRefresh {
    param([switch]$Full, $RestoreState = $null)
    $receivedMarker = $(if (($RestoreState -is [hashtable]) -and $RestoreState.ContainsKey('Marker')) { '#' + $RestoreState.Marker } else { 'none' })
    $script:t12Events.Add(('refresh:{0}:{1}' -f $(if ($Full) { 'full' } else { 'start' }), $receivedMarker))
    if (($script:t12Plan.RefreshThrow -eq 'always') -or (($null -ne $script:t12Plan.RefreshThrow) -and ($script:t12Plan.RefreshThrow -eq $script:uiTheme))) { throw ('갱신 실패 ' + $script:uiTheme) }
  }
  function Save-UiThemeState { $script:t12Events.Add('save') }
  function Add-GuiLog {
    param([string]$Message)
    $script:t12Lines.Add($Message)
    $script:t12Events.Add('log')
    if ($script:t12Plan.LogThrow) { throw '기록 실패' }
  }
  $script:uiTheme = $From
  $switchThrown = ''
  try { Invoke-ThemeSwitch -From $From -To $To -Save:$Save } catch { $switchThrown = $_.Exception.Message }
  return @{ Events = (@($script:t12Events) -join ' > '); Lines = (@($script:t12Lines) -join ' / '); LineCount = $script:t12Lines.Count; Thrown = $switchThrown }
}
function Format-T12Row {
  # 행 결과 → '호출 순서 | 시도한 줄 | 예외'
  param($Row)
  return ('{0} | [{1}] | 예외 [{2}]' -f $Row.Events, $Row.Lines, $Row.Thrown)
}
function Invoke-T12Click {
  # 아이콘 클릭 처리기 1회 - 슬라이드 정리 · 전환은 기록 스텁
  param([bool]$Running, [bool]$Sliding, [string]$Theme)
  $script:t12Events = New-Object System.Collections.Generic.List[string]
  function Stop-LifeSlideNow { $script:t12Events.Add('stop-slide'); $script:lifeSlideActive = $false }
  function Invoke-ThemeSwitch { param([string]$From, [string]$To, [switch]$Save) $script:t12Events.Add(('switch:{0}>{1}:{2}' -f $From, $To, [bool]$Save)) }
  $script:running = $Running
  $script:lifeSlideActive = $Sliding
  $script:uiTheme = $Theme
  $clickThrown = ''
  try { Invoke-ThemeToggleClick } catch { $clickThrown = $_.Exception.Message }
  return ('{0} | 예외 [{1}]' -f (@($script:t12Events) -join ' > '), $clickThrown)
}
function Invoke-T12ClickSaveThrow {
  # 실 Invoke-ThemeSwitch + 저장 함수가 던짐 (E4 - -Save 경로의 관측 밖 예외는 클릭 바깥 catch 가 [경고] 1줄로 받음)
  $script:t12Events = New-Object System.Collections.Generic.List[string]
  $script:t12Lines = New-Object System.Collections.Generic.List[string]
  function Get-ThemeRestoreState { $script:t12Events.Add('state'); return @{ Marker = 1 } }
  function Set-HoneyPalette { param([string]$Theme) $script:t12Events.Add('set:' + $Theme); $script:uiTheme = $Theme }
  function Invoke-HoneyThemeRefresh { param([switch]$Full, $RestoreState = $null) $script:t12Events.Add('refresh') }
  function Save-UiThemeState { $script:t12Events.Add('save'); throw '저장 주입 예외' }
  function Add-GuiLog { param([string]$Message) $script:t12Lines.Add($Message); $script:t12Events.Add('log') }
  $script:running = $false
  $script:lifeSlideActive = $false
  $script:uiTheme = 'light'
  $clickThrown = ''
  try { Invoke-ThemeToggleClick } catch { $clickThrown = $_.Exception.Message }
  return ('{0} | [{1}] | 예외 [{2}]' -f (@($script:t12Events) -join ' > '), (@($script:t12Lines) -join ' / '), $clickThrown)
}
try {
  Reset-ThemeTestState
  Assert-Case 'T12 S1 정상 -Save → 상태 1 · 팔레트(To) · 갱신(-Full, 같은 상태) · 저장 1 · 기록 0' (Format-T12Row (Invoke-T12Switch -Plan @{} -From 'light' -To 'dark' -Save)) `
    'state > set:dark > refresh:full:#1 > save | [] | 예외 []'
  Assert-Case 'T12 S2 정상(시작 - -Save 없음) → 같은 순서 · 저장 0' (Format-T12Row (Invoke-T12Switch -Plan @{} -From 'light' -To 'dark')) `
    'state > set:dark > refresh:full:#1 | [] | 예외 []'
  Assert-Case 'T12 S3 적용(갱신) 실패 → 같은 상태로 되돌림 · 기록 1(마지막 갱신 뒤) · 저장 0' (Format-T12Row (Invoke-T12Switch -Plan @{ RefreshThrow = 'dark' } -From 'light' -To 'dark' -Save)) `
    'state > set:dark > refresh:full:#1 > set:light > refresh:full:#1 > log | [[경고] 다크 화면을 적용하지 못해 되돌렸습니다: 갱신 실패 dark] | 예외 []'
  Assert-Case "T12 S3' 다크 → 라이트 적용 실패 → 기록 이름 '라이트'" (Format-T12Row (Invoke-T12Switch -Plan @{ RefreshThrow = 'light' } -From 'dark' -To 'light' -Save)) `
    'state > set:light > refresh:full:#1 > set:dark > refresh:full:#1 > log | [[경고] 라이트 화면을 적용하지 못해 되돌렸습니다: 갱신 실패 light] | 예외 []'
  Assert-Case 'T12 S4 팔레트(To) 실패 → 팔레트(From) · 갱신 1 · 기록 1 · 저장 0' (Format-T12Row (Invoke-T12Switch -Plan @{ SetThrowTheme = 'dark' } -From 'light' -To 'dark' -Save)) `
    'state > set:dark > set:light > refresh:full:#1 > log | [[경고] 다크 화면을 적용하지 못해 되돌렸습니다: 팔레트 실패 dark] | 예외 []'
  Assert-Case 'T12 S5 되돌림도 실패 → 두 원인 1줄 · 예외 0 · 저장 0' (Format-T12Row (Invoke-T12Switch -Plan @{ RefreshThrow = 'always' } -From 'light' -To 'dark' -Save)) `
    'state > set:dark > refresh:full:#1 > set:light > refresh:full:#1 > log | [[경고] 화면 색을 되돌리지도 못했습니다: 갱신 실패 dark / 갱신 실패 light] | 예외 []'
  Assert-Case 'T12 S6 상태 읽기 실패 → 팔레트 0 · 갱신 0 · 기록 1 · 저장 0' (Format-T12Row (Invoke-T12Switch -Plan @{ StateThrow = $true } -From 'light' -To 'dark' -Save)) `
    'state > log | [[경고] 화면 색 상태를 읽지 못해 바꾸지 않았습니다: 상태 실패] | 예외 []'
  Assert-Case "T12 S7 S3 + 기록 실패(K1 가) → S3 과 같음 · 시도 1줄 = '되돌렸습니다' 꼴 · 예외 0" (Format-T12Row (Invoke-T12Switch -Plan @{ RefreshThrow = 'dark'; LogThrow = $true } -From 'light' -To 'dark' -Save)) `
    'state > set:dark > refresh:full:#1 > set:light > refresh:full:#1 > log | [[경고] 다크 화면을 적용하지 못해 되돌렸습니다: 갱신 실패 dark] | 예외 []'
  Assert-Case 'T12 S8 S5 + 기록 실패(K1 나) → S5 와 같음 · 시도 1줄 = 두 원인 · 예외 0' (Format-T12Row (Invoke-T12Switch -Plan @{ RefreshThrow = 'always'; LogThrow = $true } -From 'light' -To 'dark' -Save)) `
    'state > set:dark > refresh:full:#1 > set:light > refresh:full:#1 > log | [[경고] 화면 색을 되돌리지도 못했습니다: 갱신 실패 dark / 갱신 실패 light] | 예외 []'
  Assert-Case 'T12 S9 S6 + 기록 실패 → S6 과 같음 · 시도 1줄 · 예외 0' (Format-T12Row (Invoke-T12Switch -Plan @{ StateThrow = $true; LogThrow = $true } -From 'light' -To 'dark' -Save)) `
    'state > log | [[경고] 화면 색 상태를 읽지 못해 바꾸지 않았습니다: 상태 실패] | 예외 []'
  Assert-Case 'T12 C1 클릭 · 실행 중 → 전환 0' (Invoke-T12Click -Running $true -Sliding $false -Theme 'light') ' | 예외 []'
  Assert-Case 'T12 C2 클릭 · 슬라이드 중 → 슬라이드 정리가 전환 앞' (Invoke-T12Click -Running $false -Sliding $true -Theme 'light') 'stop-slide > switch:light>dark:True | 예외 []'
  Assert-Case 'T12 C3 클릭 · 보통 → From = 지금 · To = 다음 · -Save 1회 (라이트 · 다크)' ('{0} || {1}' -f (Invoke-T12Click -Running $false -Sliding $false -Theme 'light'),
      (Invoke-T12Click -Running $false -Sliding $false -Theme 'dark')) 'switch:light>dark:True | 예외 [] || switch:dark>light:True | 예외 []'
  Assert-Case 'T12 C4 클릭 · 저장 예외(E4) → 상태 · 팔레트 · 갱신 · 저장 시도 · 되돌림 0 · 클릭 경고 1줄 · 클릭 밖 예외 0' (Invoke-T12ClickSaveThrow) `
    'state > set:dark > refresh > save > log | [[경고] 화면 색 전환 처리 중 예외: 저장 주입 예외] | 예외 []'
} catch { Assert-SectionError -Section 'T12' -ErrorRecord $_ }

# ── T15 시작 저장값 (설계 1.1-3 · H3 가 - 최상위 기본값 + 설정 읽기 조기 return) ───────────────────────────
function Invoke-T15Load {
  # 설정을 못 읽은 시작(파일 없음) - Load-SettingsToUi 가 일찍 끝나 최상위 기본값이 남아야 합니다
  function Read-Config { $script:configReadError = '파일이 없습니다'; return $null }
  $script:logLines.Clear()
  $loadThrown = ''
  try { Load-SettingsToUi } catch { $loadThrown = $_.Exception.Message }
  return @{ Theme = $script:uiThemeAtStart; Lines = @($script:logLines); Thrown = $loadThrown }
}
try {
  $t15Defaults = @($topStatements | Where-Object { ($_ -is $assignType) -and ($_.Left.Extent.Text -ceq '$script:uiThemeAtStart') })
  Assert-Case 'T15 최상위 시작 기본값 대입문 정확히 1개' $t15Defaults.Count 1
  if ($t15Defaults.Count -eq 1) {
    $script:uiThemeAtStart = 'unset'
    . ([scriptblock]::Create($t15Defaults[0].Extent.Text))
    $t15Row = Invoke-T15Load
    $t15Line = $(if ($t15Row.Lines.Count -ge 1) { [string]$t15Row.Lines[0] } else { '' })
    Assert-Case "T15 설정 못 읽음 → 'light' · '기본값으로 표시' 1줄 · 예외 0" ('{0}/{1}/{2}/[{3}]' -f $t15Row.Theme, $t15Row.Lines.Count, $t15Line.Contains('config.json 을 읽지 못해 기본값으로 표시합니다'), $t15Row.Thrown) 'light/1/True/[]'
  }
} catch { Assert-SectionError -Section 'T15' -ErrorRecord $_ }

# ── T16 제목줄 HRESULT (설계 2.6 · K4 - 래퍼를 스텁으로 바꿔 반환값 주입) ───────────────────────────────
function Invoke-T16Title {
  # Set-TitleBarTheme 1회 - 래퍼가 받은 인자(핸들이 폼 핸들인지 | 값)와 남긴 줄 · 예외
  param([bool]$Dark, [int]$Result, [switch]$ThrowingLog)
  $script:t16Calls = New-Object System.Collections.Generic.List[string]
  $script:t16Result = $Result
  function Invoke-DwmTitleBarAttribute {
    param([IntPtr]$Handle, [int]$Value)
    $script:t16Calls.Add(('{0}|{1}' -f ($Handle -eq $script:form.Handle), $Value))
    return $script:t16Result
  }
  if ($ThrowingLog) { function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message); throw '기록 주입 예외' } }
  $script:logLines.Clear()
  $titleThrown = ''
  try { Set-TitleBarTheme -Dark $Dark } catch { $titleThrown = $_.Exception.Message }
  return ('{0} | [{1}] | 예외 [{2}]' -f (@($script:t16Calls) -join ','), (@($script:logLines) -join ' / '), $titleThrown)
}
try {
  Reset-ThemeTestState
  if ($script:form) { try { $script:form.Dispose() } catch { } }
  $script:form = New-Object System.Windows.Forms.Form
  Assert-Case 'T16 반환 0 → 로그 0 · 받은 값 -Dark 참 1 · 거짓 0 · 폼 핸들' ('{0} || {1}' -f (Invoke-T16Title -Dark $true -Result 0), (Invoke-T16Title -Dark $false -Result 0)) 'True|1 | [] | 예외 [] || True|0 | [] | 예외 []'
  Assert-Case 'T16 반환 -2147024809 → [경고] 정확히 1줄(0x80070057)' (Invoke-T16Title -Dark $true -Result -2147024809) 'True|1 | [[경고] 제목줄 색을 바꾸지 못했습니다 (0x80070057)] | 예외 []'
  Assert-Case 'T16 반환 ≠ 0 + 로그 기록도 던짐 → 예외 0' (Invoke-T16Title -Dark $true -Result -2147024809 -ThrowingLog) 'True|1 | [[경고] 제목줄 색을 바꾸지 못했습니다 (0x80070057)] | 예외 []'
} catch { Assert-SectionError -Section 'T16' -ErrorRecord $_ }

# ── T17 잠긴 글자 덧그리기 (11-13 사용자 결정 '흐린 회색 글자로' - 판정 진리표 · 처리기 예외 경계) ─────────────────────────
# 잠긴 평면 버튼은 WinForms 가 글자를 바탕을 어둡게 만든 색으로 그려(글자색을 쓰지 않음) 다크 바탕 44,44,48 에서는 14,14,16 으로 묻힙니다.
# 그래서 다크 · 대기 중 · 잠긴 동안에만 Paint 처리기가 같은 글자를 흐린 글자색 154,154,160 으로 덧그립니다. 라이트 · 실행 중 · 잠기지 않은 상태에서는
# 아무것도 그리지 않습니다(계약 L · 사용자 결정 ④ '실행 중 잠긴 글자는 그대로'). 실제 컨트롤 그림과 다시 그리기는 아래 'T17 하네스 행' 이 봅니다
function Invoke-T17Fault {
  # 덧그리기 본체에서 예외 1회 - 본체를 직접 부릅니다(그리기 경로로 일으키면 처리기 밖으로 샌 예외가 프로세스를 끝냄 - 하네스 준비 ②).
  # 기본은 판정 함수가 던지고, -RealJudge 면 판정은 진짜를 쓰고 그림판 없이 불러 그리기 문장이 던지게 합니다. 밖으로 새면 실사용에서는 모달 오류 창이라
  # 본체가 받아야 합니다. -ThrowingLog 면 로그가 받은 줄을 남기고 던집니다(기록 실패도 밖으로 새면 안 됨)
  param($Sender, [switch]$RealJudge, [switch]$ThrowingLog)
  if (-not $RealJudge) { function Test-LockedTextOverdraw { param([string]$Theme, [bool]$Running, [bool]$Enabled) throw '잠긴 글자 주입 예외' } }
  if ($ThrowingLog) { function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message); throw '기록 주입 예외' } }
  $faultThrown = ''
  try { Invoke-LockedTextPaint -Sender $Sender -PaintArgs $null } catch { $faultThrown = $_.Exception.Message }
  return $faultThrown
}
try {
  $t17Truth = foreach ($t17Case in @(@('light', $false, $false), @('light', $false, $true), @('light', $true, $false), @('light', $true, $true),
      @('dark', $false, $false), @('dark', $false, $true), @('dark', $true, $false), @('dark', $true, $true))) {
    $t17Verdict = Test-LockedTextOverdraw -Theme $t17Case[0] -Running $t17Case[1] -Enabled $t17Case[2]
    '{0}/{1}/{2}={3}' -f $t17Case[0], $(if ($t17Case[1]) { '실행' } else { '대기' }), $(if ($t17Case[2]) { '사용' } else { '잠김' }), $(if ($t17Verdict -is [bool]) { $t17Verdict } else { 'bool 아님' })
  }
  Assert-Case 'T17 판정 진리표 8칸(테마 × 실행 × 잠금) - 참은 다크 · 대기 · 잠김 하나뿐' ((@($t17Truth)) -join ' ') `
    'light/대기/잠김=False light/대기/사용=False light/실행/잠김=False light/실행/사용=False dark/대기/잠김=True dark/대기/사용=False dark/실행/잠김=False dark/실행/사용=False'
  Reset-ThemeTestState
  Set-HoneyPalette -Theme 'dark'
  $t17Sender = New-Object System.Windows.Forms.Button
  try {
    $t17Sender.Text = '◀'
    $t17Sender.Enabled = $false
    $t17First = Invoke-T17Fault -Sender $t17Sender
    $t17AfterFirst = '{0}|{1}|{2}' -f $t17First, $script:logLines.Count, ([string]$script:lockedTextPaintError)
    $t17Second = Invoke-T17Fault -Sender $t17Sender
    Assert-Case 'T17 처리기 예외(판정 함수가 던짐) - 밖으로 0 · 첫 예외 [경고] 1줄 · 원인 보관 / 둘째 예외 로그 0줄' ('{0} / [{1}] {2}' -f $t17AfterFirst, $t17Second, $script:logLines.Count) '|1|잠긴 글자 주입 예외 / [] 1'
    Assert-Case 'T17 첫 예외 [경고] 줄 - 원인 포함' (($script:logLines.Count -ge 1) -and $script:logLines[0].StartsWith('[경고]') -and $script:logLines[0].Contains('잠긴 글자 주입 예외')) $true
    $script:lockedTextPaintError = $null
    $script:logLines.Clear()
    $t17LogThrown = Invoke-T17Fault -Sender $t17Sender -ThrowingLog
    Assert-Case 'T17 처리기 예외 + 로그 기록도 던짐 → 예외 0(시도 1줄) · 원인 보관' ('[{0}]/{1}/{2}' -f $t17LogThrown, $script:logLines.Count, ([string]$script:lockedTextPaintError)) '[]/1/잠긴 글자 주입 예외'
    # 그리기 문장 자체의 예외: 판정은 진짜(다크 · 대기 · 잠김 = 참)라 그리기까지 가고, 그림판이 없어 그리기 문장이 던집니다(원인 글자는 환경마다 달라 '있음' 만 봄)
    $script:lockedTextPaintError = $null
    $script:logLines.Clear()
    $t17DrawThrown = Invoke-T17Fault -Sender $t17Sender -RealJudge
    $t17DrawLine = $(if ($script:logLines.Count -ge 1) { [string]$script:logLines[0] } else { '' })
    Assert-Case 'T17 그리기 문장의 예외(그림판 없음) - 밖으로 0 · [경고] 1줄 · 원인 보관 · 줄에 그 원인' ('[{0}]/{1}/{2}/{3}' -f $t17DrawThrown, $script:logLines.Count, (-not [string]::IsNullOrEmpty($script:lockedTextPaintError)),
        ((-not [string]::IsNullOrEmpty($script:lockedTextPaintError)) -and $t17DrawLine.StartsWith('[경고]') -and $t17DrawLine.Contains([string]$script:lockedTextPaintError))) '[]/1/True/True'
  } finally {
    try { $t17Sender.Dispose() } catch { }
    $script:lockedTextPaintError = $null
    Set-HoneyPalette -Theme 'light'
  }
} catch { Assert-SectionError -Section 'T17' -ErrorRecord $_ }

# ── T18 다크 입력 칸 통일 (11-14 사용자 요청 '숫자 · 시간 · 목록 칸을 같은 색으로, 잠겨도 같은 색' · 설계 7.13) ───────────────────────────
# 다크에서 시간 칸(DateTimePicker) · 닫힌 채 고르는 목록 칸(ComboBox - DropDownList) · 잠긴 숫자 칸의 글자는 색 속성으로 바뀌지 않습니다(색 속성을 받지 않음 ·
# 닫힌 칸을 윈도우 테마가 그림 · 잠긴 글자를 윈도우가 회색으로 그림). 그래서 그 칸의 창에 장치(HoneyInputRecolor - C# NativeWindow)를 얹어, 컨트롤이 스스로 그린 그림을
# 받아 색만 바꿔 다시 그립니다(윈도우 종이색 → 입력 바탕 · 잉크색 → 기본 글자 · 시간 · 목록 칸은 숫자 칸과 같은 색의 테두리 1px).
# 장치는 처음 다크로 갈 때 만들고 라이트에서는 꺼 둡니다 - 꺼진 장치는 모든 메시지를 붙기 직전의 창 프로시저로 그대로 넘깁니다(계약 L · 설계 7.14 - 사이의 서브클래스를
# 건너뛰지 않음: 아래 T18g).
# 여기(하네스 블록 밖)의 행은 핸들 없는 폼에서 제품 함수만 돌립니다 - 장치는 핸들이 생길 때 붙으므로 창 프로시저는 돌지 않습니다.
# 실제 그림 · 핸들 · 창 프로시저의 예외 경계는 아래 'T18 하네스 행' 이 봅니다.
# 다크 팔레트의 입력 바탕 · 기본 글자는 T2 의 리터럴과 같은 숫자를 직접 적습니다(H11 - 제품 변수로 계산하지 않음)
$t18DarkInput = [System.Drawing.Color]::FromArgb(23, 23, 26)
$t18DarkText = [System.Drawing.Color]::FromArgb(232, 230, 227)

function Get-T18NumericEdit {
  # 숫자 칸 안쪽의 글자 칸(TextBox) - 잠긴 글자를 그리는 창이라 장치가 붙는 곳입니다(위아래 단추는 그대로 둠)
  param($Numeric)
  return (@($Numeric.Controls) | Where-Object { $_ -is [System.Windows.Forms.TextBox] } | Select-Object -First 1)
}

function New-T18Form {
  # 다크 입력 칸 통일의 시험 폼(헤드리스 - 화면에 띄우지 않음). 여섯 칸 = 시간 · 목록 · 숫자 × 안 잠김 · 잠김을 제품의 생성 문장 · 속성 대입문 그대로 만듭니다
  # (시간 지정 dtpUntil · 난이도 cboDifficulty · 횟수 numCount - New-SourceControl. 하네스가 정하는 것은 이름표 · 자리 · 값 · 목록 항목 · 잠금).
  # 잠금은 핸들이 생기기 전에 정합니다 - 시간 칸은 핸들이 생긴 뒤에 잠그면 글자만 회색이 되고 바탕 · 테두리는 안 잠긴 모양으로 남습니다
  # (11-14 이 PC 관측: 잠긴 채 만든 칸 바탕 254 · 테두리 200 / 만든 뒤에 잠근 칸 255 · 141 - 그 경우는 '잠금을 뒤집은 뒤' 행이 따로 봄).
  # 시간 칸의 값은 고정합니다(제품은 만든 순간의 시각 - 그림 비교가 분이 넘어갈 때 갈림).
  # 대상 찾기가 가려야 하는 것도 함께 둡니다: 묶음 → 패널 안의 목록 칸(재귀 3단) · 글자 칸(폼 자식 TextBox) · 편집형 목록 칸(DropDown) · 표(ListView).
  # 셀 편집 콤보는 제품처럼 폼 밖입니다(제품의 생성 문장 그대로 · 이름표만 더함). 제품 함수가 이름으로 찾는 $form · $script:cellEditCombo 를 이 폼의 것으로 바꿔 두고,
  # 칸은 $script:t18Cells(이름 → 컨트롤)에 둡니다. -Handles 면 모든 핸들을 만듭니다(보이지 않는 폼의 그림은 핸들이 있는 컨트롤만 찍음)
  param([switch]$Handles)
  if ($script:form) { try { $script:form.Dispose() } catch { } }
  if ($script:cellEditCombo) { try { $script:cellEditCombo.Dispose() } catch { } }
  $script:form = New-Object System.Windows.Forms.Form
  $script:form.Size = New-Object System.Drawing.Size(560, 320)
  $script:form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
  $script:t18Cells = @{}
  $script:t18Cells['pickerOn'] = New-SourceControl -SourceName 'dtpUntil' -Parent $script:form -Name 'pickerOn' -X 20 -Y 20
  $script:t18Cells['pickerOff'] = New-SourceControl -SourceName 'dtpUntil' -Parent $script:form -Name 'pickerOff' -X 110 -Y 20
  $script:t18Cells['comboOn'] = New-SourceControl -SourceName 'cboDifficulty' -Parent $script:form -Name 'comboOn' -X 20 -Y 60
  $script:t18Cells['comboOff'] = New-SourceControl -SourceName 'cboDifficulty' -Parent $script:form -Name 'comboOff' -X 200 -Y 60
  $script:t18Cells['numericOn'] = New-SourceControl -SourceName 'numCount' -Parent $script:form -Name 'numericOn' -X 20 -Y 100
  $script:t18Cells['numericOff'] = New-SourceControl -SourceName 'numCount' -Parent $script:form -Name 'numericOff' -X 110 -Y 100
  $script:t18Cells['nestGroup'] = New-HarnessControl -TypeName 'GroupBox' -Name 'nestGroup' -X 20 -Y 140 -Width 300 -Height 70 -Parent $script:form
  $nestPanel = New-HarnessControl -TypeName 'Panel' -Name 'nestPanel' -X 10 -Y 20 -Width 270 -Height 40 -Parent $script:t18Cells['nestGroup']
  $script:t18Cells['comboNested'] = New-SourceControl -SourceName 'cboDifficulty' -Parent $nestPanel -Name 'comboNested' -X 5 -Y 5
  $script:t18Cells['plainText'] = New-HarnessControl -TypeName 'TextBox' -Name 'plainText' -X 360 -Y 20 -Width 100 -Height 23 -Parent $script:form
  $script:t18Cells['editCombo'] = New-HarnessControl -TypeName 'ComboBox' -Name 'editCombo' -X 360 -Y 60 -Width 120 -Height 23 -Parent $script:form
  $script:t18Cells['listHost'] = New-HarnessControl -TypeName 'ListView' -Name 'listHost' -X 360 -Y 100 -Width 150 -Height 60 -Parent $script:form
  foreach ($pickerName in @('pickerOn', 'pickerOff')) { $script:t18Cells[$pickerName].Value = [datetime]'2026-01-02 12:34:00' }
  foreach ($comboName in @('comboOn', 'comboOff', 'comboNested')) {
    [void]$script:t18Cells[$comboName].Items.Add('게임 그대로')
    [void]$script:t18Cells[$comboName].Items.Add('어려움')
    $script:t18Cells[$comboName].SelectedIndex = 0
  }
  foreach ($lockedName in @('pickerOff', 'comboOff', 'numericOff')) { $script:t18Cells[$lockedName].Enabled = $false }
  New-SourceCellEditCombo
  if ($Handles) { Initialize-AllHandles -Parent $script:form }
}

function Set-T18Theme {
  # 팔레트를 정하고 제품이 이 칸들을 칠하는 길 그대로 칠합니다(폼 바탕 → 테마 일괄 적용 - 숫자 · 목록 칸의 바탕 · 글자색. 시간 칸은 일괄 적용의 대상이 아님).
  # 장치는 건드리지 않습니다 - 켜고 끄기는 행이 제품 함수(Update-InputRecolor)로 따로 부릅니다
  param([string]$Theme)
  Set-HoneyPalette -Theme $Theme
  $script:form.BackColor = $script:themeBack
  Apply-HoneyTheme -Root $script:form
}

function Get-T18Entries {
  # 제품의 장치 목록(@{ Kind; Painter } 들) - 만든 적이 없으면($null) 아무것도 내지 않습니다 (열거용 - 호출부가 @() 로 받음)
  if ($null -eq $script:inputRecolorPainters) { return }
  return $script:inputRecolorPainters
}

function Get-T18Painter {
  # 제품의 장치 목록에서 그 컨트롤을 주인으로 하는 장치 (없으면 $null)
  param($Owner)
  foreach ($recolorEntry in @(Get-T18Entries)) {
    if ([object]::ReferenceEquals($recolorEntry.Painter.Owner, $Owner)) { return $recolorEntry.Painter }
  }
  return $null
}

function Test-T18Near {
  # 'R,G,B' 글자가 그 색과 채널마다 허용 차이 안인가
  param([string]$RgbText, $Color, [int]$Tolerance)
  $nearChannels = @($RgbText -split ',' | ForEach-Object { [int]$_ })
  if ($nearChannels.Count -ne 3) { return $false }
  return (([Math]::Abs($nearChannels[0] - $Color.R) -le $Tolerance) -and ([Math]::Abs($nearChannels[1] - $Color.G) -le $Tolerance) -and ([Math]::Abs($nearChannels[2] - $Color.B) -le $Tolerance))
}

function Convert-T18Colors {
  # 색 대응(ColorMatrix)에 색들을 넣었을 때 나오는 색 - 장치가 그릴 때와 같은 길(GDI+ DrawImage + ImageAttributes)로 1화소씩 그려 읽습니다.
  # 배율 · 오프셋을 테스트가 손으로 다시 계산하지 않습니다 - 그 계산을 따라 하면 같은 착각(오프셋 단위 · 반올림)을 함께 합니다.
  # 열거용 반환('R,G,B' 글자들 - 호출부가 @() 로 받음)
  param($Matrix, [object[]]$Colors)
  $sourceBitmap = New-Object System.Drawing.Bitmap($Colors.Count, 1, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
  $resultBitmap = New-Object System.Drawing.Bitmap($Colors.Count, 1, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
  try {
    for ($colorIndex = 0; $colorIndex -lt $Colors.Count; $colorIndex++) { $sourceBitmap.SetPixel($colorIndex, 0, $Colors[$colorIndex]) }
    $resultGraphics = [System.Drawing.Graphics]::FromImage($resultBitmap)
    $colorAttributes = New-Object System.Drawing.Imaging.ImageAttributes
    try {
      $colorAttributes.SetColorMatrix($Matrix)
      $resultGraphics.DrawImage($sourceBitmap, (New-Object System.Drawing.Rectangle(0, 0, $Colors.Count, 1)), 0, 0, $Colors.Count, 1, [System.Drawing.GraphicsUnit]::Pixel, $colorAttributes)
    } finally {
      $colorAttributes.Dispose()
      $resultGraphics.Dispose()
    }
    $resultTexts = for ($colorIndex = 0; $colorIndex -lt $Colors.Count; $colorIndex++) { Get-RgbText $resultBitmap.GetPixel($colorIndex, 0) }
    return $resultTexts
  } finally {
    $sourceBitmap.Dispose()
    $resultBitmap.Dispose()
  }
}

function Get-T18PlanText {
  # 장치 하나에 들어 있는 색 대응을 설계 7.13 의 표와 맞댄 글자 - '<종류> 안 잠김 <종이색이 입력 바탕으로>/<잉크색이 기본 글자로> · 잠김 …/… · 테두리 <…>'.
  # 표: 시간 칸 = 안 잠김 Window · WindowText / 잠김 254 · GrayText, 목록 칸 = 안 잠김 253 · WindowText / 잠김 250 · GrayText,
  #     숫자 칸 = 안 잠김 대응 없음(이미 패널 색 - 그대로 통과) / 잠김 입력 바탕(제자리) · GrayText. 254 · 253 · 250 은 설계가 적은 윈도우 11 테마 실측값입니다.
  # 색은 장치가 그릴 때와 같은 길로 보내 보고(Convert-T18Colors), 목표 색과 채널마다 1 이내면 True 입니다(반올림). 대응이 없으면 '통과'.
  # 테두리는 시간 · 목록 칸 = 윈도우 테마의 글자 칸 테두리색(숫자 칸의 테두리와 같은 색이 되게)과 같은지, 숫자 칸 = 비어 있는지(윈도우가 그린 테두리 그대로)
  param($Entry)
  $planPapers = @{
    picker  = @{ Enabled = [System.Drawing.SystemColors]::Window; Locked = [System.Drawing.Color]::FromArgb(254, 254, 254) }
    combo   = @{ Enabled = [System.Drawing.Color]::FromArgb(253, 253, 253); Locked = [System.Drawing.Color]::FromArgb(250, 250, 250) }
    numeric = @{ Enabled = $null; Locked = $script:t18DarkInput }
  }
  $planPaper = $planPapers[[string]$Entry.Kind]
  if ($null -eq $planPaper) { return ('모르는 종류 ' + $Entry.Kind) }
  $planStateTexts = foreach ($planState in @(
      @{ Matrix = $Entry.Painter.EnabledMatrix; Paper = $planPaper.Enabled; Ink = [System.Drawing.SystemColors]::WindowText },
      @{ Matrix = $Entry.Painter.DisabledMatrix; Paper = $planPaper.Locked; Ink = [System.Drawing.SystemColors]::GrayText })) {
    if ($null -eq $planState.Matrix) { '통과'; continue }
    if ($null -eq $planState.Paper) { '대응 있음(표에는 없음)'; continue }
    $planResult = @(Convert-T18Colors -Matrix $planState.Matrix -Colors @($planState.Paper, $planState.Ink))
    '{0}/{1}' -f (Test-T18Near -RgbText $planResult[0] -Color $script:t18DarkInput -Tolerance 1), (Test-T18Near -RgbText $planResult[1] -Color $script:t18DarkText -Tolerance 1)
  }
  $planBorderText = $(if ($Entry.Painter.BorderColor.IsEmpty) { '없음' } else {
      [string]((Get-RgbText $Entry.Painter.BorderColor) -ceq (Get-RgbText ([System.Windows.Forms.VisualStyles.VisualStyleInformation]::TextControlBorder))) })
  return ('{0} 안 잠김 {1} · 잠김 {2} · 테두리 {3}' -f $Entry.Kind, @($planStateTexts)[0], @($planStateTexts)[1], $planBorderText)
}

function Invoke-T18ApplyFault {
  # 다크 적용 실패 1회: 장치 만들기(Initialize-InputRecolor)를 던지는 스텁으로 바꿔(이 함수 지역) 8a(Update-InputRecolor)를 부르고, 그 직후의 상태를 잡은 뒤
  # 12(Write-InputRecolorWarning)를 부릅니다. -ThrowingLog 면 로그가 받은 줄을 남기고 던집니다 - 공용 갱신은 안에서 예외를 받지 않아, 12 가 새면 이미 끝난 전환이 되돌려집니다.
  # 돌려주는 값 = hashtable 1개: 밖으로 나온 예외 · 8a 직후('로그 줄 수|목록 없음|원인|보관된 경고') · 12 뒤 보관된 경고가 비었는지
  param([switch]$ThrowingLog)
  function Initialize-InputRecolor { throw '입력 칸 주입 예외' }
  if ($ThrowingLog) { function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message); throw '기록 주입 예외' } }
  $applyThrown = ''
  try { Update-InputRecolor } catch { $applyThrown += ('8a: ' + $_.Exception.Message) }
  $afterUpdate = '{0}|{1}|{2}|{3}' -f $script:logLines.Count, ($null -eq $script:inputRecolorPainters), [string]$script:inputRecolorError, [string]$script:inputRecolorPendingWarning
  try { Write-InputRecolorWarning } catch { $applyThrown += (' 12: ' + $_.Exception.Message) }
  return @{ Thrown = $applyThrown; AfterUpdate = $afterUpdate; PendingCleared = ($null -eq $script:inputRecolorPendingWarning) }
}

function Invoke-T18PlanFault {
  # 다크 적용이 도중에 실패: 색 대응 함수가 셋째 호출에서 던지는 감싸개(이 함수 지역 - 앞의 둘은 진짜를 불러 그 두 장치는 이미 켜진 뒤).
  # 던지는 순간 켜져 있던 장치 수를 잡아 둡니다('끌 것이 실제로 있었는지'). 밖으로 나온 예외 글자를 돌려줍니다
  function Get-InputRecolorPlan {
    param([string]$Kind)
    $script:t18PlanCalls++
    if ($script:t18PlanCalls -ge 3) {
      $script:t18ActiveAtFault = @(@(Get-T18Entries) | Where-Object { $_.Painter.Active }).Count
      throw '색 대응 주입 예외'
    }
    return (& $script:realBlocks['Get-InputRecolorPlan'] -Kind $Kind)
  }
  $script:t18PlanCalls = 0
  $script:t18ActiveAtFault = -1
  $planThrown = ''
  try { Update-InputRecolor } catch { $planThrown = $_.Exception.Message }
  return $planThrown
}

function Invoke-T18Notice {
  # 그리기 고장 알림(Invoke-InputRecolorFaultNotice) 1회 - 제품에서는 고장 난 장치가 메시지 루프에 예약해 부릅니다(밖으로 새면 모달 오류 창).
  # -ThrowingLog 면 로그가 받은 줄을 남기고 던집니다. 밖으로 나온 예외 글자를 돌려줍니다
  param([switch]$ThrowingLog)
  if ($ThrowingLog) { function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message); throw '기록 주입 예외' } }
  $noticeThrown = ''
  try { Invoke-InputRecolorFaultNotice } catch { $noticeThrown = $_.Exception.Message }
  return $noticeThrown
}

$t18ApplyWarning = '[경고] 다크 입력 칸 통일을 적용하지 못했습니다 - 시간 · 목록 칸은 윈도우 기본 모양으로 둡니다 (이후 예외는 기록하지 않음): '
$t18PaintWarning = '[경고] 다크 입력 칸을 다시 칠하지 못했습니다 - 그 칸은 윈도우 기본 모양으로 둡니다 (이후 예외는 기록하지 않음): '
try {
  # (1) 다크 첫 호출 - 이 프로세스에서 장치 형식을 처음 올리는 곳입니다(위 'T18 첫 행' 이 그 앞에서 '형식 없음' 을 봤음). 이 행이 '전 = True' 면 앞에서 누가 먼저 올린 것입니다
  Reset-ThemeTestState
  New-T18Form
  Set-T18Theme -Theme 'dark'
  $t18TypeBefore = [bool]('HoneyInputRecolor' -as [type])
  $t18Thrown = ''
  try {
    Update-InputRecolor
    Write-InputRecolorWarning
  } catch { $t18Thrown = $_.Exception.Message }
  $t18Entries = @(Get-T18Entries)
  Assert-Case 'T18d 다크 첫 호출 - 장치 형식이 없다가 올라옴(이 프로세스의 첫 컴파일을 제품 함수가 함) · 예외 0 · 원인 없음 · 보관된 경고 없음 · 로그 0' `
    ('{0}>{1} | [{2}] · {3} · {4} · {5}' -f $t18TypeBefore, [bool]('HoneyInputRecolor' -as [type]), $t18Thrown, ($null -eq $script:inputRecolorError), ($null -eq $script:inputRecolorPendingWarning), $script:logLines.Count) `
    'False>True | [] · True · True · 0'
  Assert-Case 'T18d 다크 - 장치 목록이 생김 · 장치 8개(폼 아래 일곱 + 표 밖 셀 편집 콤보) 모두 켜짐' ('{0}/{1}' -f $t18Entries.Count, @($t18Entries | Where-Object { $_.Painter.Active }).Count) '8/8'
  # 대상 = '종류:주인>붙는 컨트롤'. 시간 · 목록 칸은 자신에 붙고, 숫자 칸은 주인(Enabled 를 읽는 곳)이 숫자 칸 · 붙는 곳이 그 안쪽 글자 칸(TextBox · 부모가 그 숫자 칸)입니다.
  # 순서 = 폼 나무 순서(묶음 → 패널 안의 목록 칸까지 내려감) → 셀 편집 콤보. 글자 칸(폼 자식) · 편집형 목록 칸 · 표는 대상이 아닙니다
  $t18TargetText = (@($t18Entries | ForEach-Object {
        '{0}:{1}>{2}' -f $_.Kind, $_.Painter.Owner.Name, $(if ([object]::ReferenceEquals($_.Painter.Target, $_.Painter.Owner)) { '자신' } else {
            '{0}/{1}' -f $(if ($_.Painter.Target -is [System.Windows.Forms.TextBox]) { 'TextBox' } else { $_.Painter.Target.GetType().Name }), [object]::ReferenceEquals($_.Painter.Target.Parent, $_.Painter.Owner) }) })) -join ' '
  Assert-Case 'T18d 대상 수집 - 시간 2 · 목록 2 · 숫자 2(안쪽 TextBox 에 붙음) · 묶음 안 패널 안 목록 1 · 표 밖 셀 편집 콤보 1 / 글자 칸 · 편집형 목록 칸 · 표는 빠짐' $t18TargetText `
    'picker:pickerOn>자신 picker:pickerOff>자신 combo:comboOn>자신 combo:comboOff>자신 numeric:numericOn>TextBox/True numeric:numericOff>TextBox/True combo:comboNested>자신 combo:cellEditCombo>자신'
  $t18HandleCount = @(@(Get-HarnessControls -Parent $script:form) | Where-Object { $_.IsHandleCreated }).Count
  Assert-Case 'T18d 다크 호출이 핸들을 만들지 않음 - 폼 · 그 아래 모든 컨트롤(숫자 칸 안쪽 포함) · 셀 편집 콤보에 핸들 0 → 붙은 장치 0(핸들이 생길 때 붙음 - 창을 띄우기 전의 다크 시작)' `
    ('{0}/{1}/{2}/{3}' -f $script:form.IsHandleCreated, $t18HandleCount, $script:cellEditCombo.IsHandleCreated, @($t18Entries | Where-Object { $_.Painter.IsAttached }).Count) 'False/0/False/0'
  # 대상 찾기의 반환 꼴(규칙 3 - 열거용): 대상이 하나인 뿌리도 @() 로 받으면 hashtable 1개, 없는 뿌리는 0개여야 합니다(쉼표 반환이면 1개짜리 배열이 한 겹 더 싸임)
  $t18Direct = @(Get-InputRecolorTargets -Root $script:form)
  $t18Single = @(Get-InputRecolorTargets -Root $script:t18Cells['nestGroup'])
  $t18None = @(Get-InputRecolorTargets -Root $script:t18Cells['listHost'])
  Assert-Case 'T18d 대상 찾기의 반환 꼴 - 폼 7개 · 묶음 1개(그 하나가 hashtable · 키 Kind · Owner · Target) · 표 0개' ('{0}/{1}/{2}/{3}/{4}' -f $t18Direct.Count, $t18Single.Count,
      (($t18Single.Count -eq 1) -and ($t18Single[0] -is [hashtable])), $(if (($t18Single.Count -eq 1) -and ($t18Single[0] -is [hashtable])) { (@($t18Single[0].Keys) | Sort-Object) -join ',' } else { '' }), $t18None.Count) `
    '7/1/True/Kind,Owner,Target/0'
  # 색 대응 표(설계 7.13 의 표 - 종류 × 상태). 켜고 끄기가 장치마다 넣은 값을 읽습니다(색 대응 함수의 반환이 장치에 실제로 실렸는지까지)
  Assert-Case 'T18d 색 대응 표 - 시간 · 목록 칸: 종이색 → 입력 바탕 23,23,26 · 잉크색 → 기본 글자 232,230,227(안 잠김 · 잠김 따로) · 테두리 = 윈도우 글자 칸 테두리색 / 숫자 칸: 안 잠김 통과 · 잠김만 · 테두리 없음' `
    ((@($t18Entries | ForEach-Object { Get-T18PlanText -Entry $_ })) -join ' | ') `
    ('picker 안 잠김 True/True · 잠김 True/True · 테두리 True | picker 안 잠김 True/True · 잠김 True/True · 테두리 True | combo 안 잠김 True/True · 잠김 True/True · 테두리 True | ' +
      'combo 안 잠김 True/True · 잠김 True/True · 테두리 True | numeric 안 잠김 통과 · 잠김 True/True · 테두리 없음 | numeric 안 잠김 통과 · 잠김 True/True · 테두리 없음 | ' +
      'combo 안 잠김 True/True · 잠김 True/True · 테두리 True | combo 안 잠김 True/True · 잠김 True/True · 테두리 True')
  # (2) 다시 라이트 = 전부 끔(목록은 그대로 둠) → 다시 다크 = 같은 장치를 다시 켬(새로 만들지 않음 - 새로 만들면 같은 컨트롤에 장치가 둘 붙음)
  $t18FirstPainters = @($t18Entries | ForEach-Object { $_.Painter })
  Set-T18Theme -Theme 'light'
  Update-InputRecolor
  Write-InputRecolorWarning
  Assert-Case 'T18d 다시 라이트 - 장치 8개 그대로 · 켜진 장치 0 · 로그 0' ('{0}/{1}/{2}' -f @(Get-T18Entries).Count, @(@(Get-T18Entries) | Where-Object { $_.Painter.Active }).Count, $script:logLines.Count) '8/0/0'
  Set-T18Theme -Theme 'dark'
  Update-InputRecolor
  $t18SecondEntries = @(Get-T18Entries)
  $t18SamePainters = 0
  for ($entryIndex = 0; $entryIndex -lt [Math]::Min($t18FirstPainters.Count, $t18SecondEntries.Count); $entryIndex++) {
    if ([object]::ReferenceEquals($t18FirstPainters[$entryIndex], $t18SecondEntries[$entryIndex].Painter)) { $t18SamePainters++ }
  }
  Assert-Case 'T18d 다시 다크 - 처음 만든 장치 8개를 그대로 다시 켬(새로 만들지 않음)' ('{0}/{1}/{2}' -f $t18SecondEntries.Count, $t18SamePainters, @($t18SecondEntries | Where-Object { $_.Painter.Active }).Count) '8/8/8'
  # (3) 다크 적용이 도중에 실패 - 앞의 둘은 켜진 뒤 셋째에서 던짐 → 전부 끈 상태로 맞추고 · 예외는 밖으로 내지 않고 · 경고는 보관만(여기서 로그를 쓰지 않음)
  Set-T18Theme -Theme 'light'
  Update-InputRecolor
  Set-T18Theme -Theme 'dark'
  $t18PlanThrown = Invoke-T18PlanFault
  Assert-Case 'T18d 다크 적용이 도중에 실패(셋째 장치의 색 대응이 던짐) - 던지는 순간 켜진 장치 2 → 뒤에는 0(전부 끔) · 예외 0 · 로그 0 · 원인 · 보관된 경고(적용 실패 문구 + 원인)' `
    ('{0}>{1} | [{2}] · {3} · {4} · {5}' -f $script:t18ActiveAtFault, @(@(Get-T18Entries) | Where-Object { $_.Painter.Active }).Count, $t18PlanThrown, $script:logLines.Count, [string]$script:inputRecolorError,
      ([string]$script:inputRecolorPendingWarning -ceq ($t18ApplyWarning + '색 대응 주입 예외'))) '2>0 | [] · 0 · 색 대응 주입 예외 · True'
  # (4) 셀 편집 콤보가 편집 중이라 표 안에 붙어 있을 때 - 폼 아래에서 이미 잡히므로 따로 더하지 않습니다(같은 컨트롤에 장치가 둘 붙지 않게)
  Reset-ThemeTestState
  New-T18Form
  $script:t18Cells['listHost'].Controls.Add($script:cellEditCombo)
  Set-T18Theme -Theme 'dark'
  Update-InputRecolor
  Assert-Case 'T18d 셀 편집 콤보가 표 안에 붙어 있을 때 - 장치 8개 그대로 · 그 콤보의 장치는 1개(둘 붙지 않음) · 원인 없음' ('{0}/{1}/{2}' -f @(Get-T18Entries).Count,
      @(@(Get-T18Entries) | Where-Object { [object]::ReferenceEquals($_.Painter.Target, $script:cellEditCombo) }).Count, ($null -eq $script:inputRecolorError)) '8/1/True'
  # 고장 알림 배선: 장치 만들기가 장치마다 단 알림 대리자를 부르면 제품의 알림 함수가 돕니다(대리자가 빠지면 그리다 고장 난 장치는 조용히 꺼지기만 하고 [경고] 가 남지 않음).
  # 고장 원인은 한 장치에 직접 적어 두고(공개 필드), 다른 장치의 대리자를 부릅니다 - 알림 함수는 목록에서 오류가 적힌 첫 장치를 찾습니다
  $t18WiredEntries = @(Get-T18Entries)
  $t18WiredEntries[2].Painter.LastError = '직접 적은 고장 원인'
  $t18WiredThrown = ''
  try { $t18WiredEntries[0].Painter.FaultCallback.Invoke() } catch { $t18WiredThrown = $_.Exception.GetBaseException().Message }
  Assert-Case 'T18d 고장 알림 배선 - 여덟 장치 모두 알림 대리자가 있음 · 그 대리자를 부르면 [경고] 1줄(다시 칠하지 못함 문구 + 오류가 적힌 장치의 원인) · 예외 0' `
    ('{0}/[{1}]/[{2}]' -f @($t18WiredEntries | Where-Object { $null -ne $_.Painter.FaultCallback }).Count, ($script:logLines -join ' / '), $t18WiredThrown) ('8/[' + $t18PaintWarning + '직접 적은 고장 원인]/[]')
  # (5) 장치 만들기가 던질 때(스텁) - 8a 는 예외를 밖으로 내지 않고 로그도 쓰지 않으며 원인과 경고 글자를 보관만 합니다 → 12 가 [경고] 1줄로 기록하고 비움.
  #     8a 에서 바로 쓰면 로그를 접은 화면에서 생긴 배지를 10번(잡아 둔 의미 되살리기)이 덮습니다(그 화면은 아래 하네스 행이 봄). 둘째 실패는 적지 않습니다(첫 1회)
  Reset-ThemeTestState
  New-T18Form
  Set-T18Theme -Theme 'dark'
  $t18Fault = Invoke-T18ApplyFault
  Assert-Case 'T18d 장치 만들기가 던짐 - 8a 직후: 예외 0 · 로그 0줄 · 목록 없음 그대로 · 원인 보관 · 경고 글자 보관(적용 실패 문구 + 원인)' ('[{0}] {1}' -f $t18Fault.Thrown, $t18Fault.AfterUpdate) `
    ('[] 0|True|입력 칸 주입 예외|' + $t18ApplyWarning + '입력 칸 주입 예외')
  Assert-Case 'T18d 장치 만들기가 던짐 - 12 뒤: [경고] 정확히 1줄(보관해 둔 글자 그대로) · 보관 비움' ('{0}/[{1}]/{2}' -f $script:logLines.Count, ($script:logLines -join ' / '), $t18Fault.PendingCleared) `
    ('1/[' + $t18ApplyWarning + '입력 칸 주입 예외]/True')
  $t18FaultAgain = Invoke-T18ApplyFault
  Assert-Case 'T18d 한 번 더 던짐 - 예외 0 · 새로 보관하지 않음 · [경고] 는 1줄 그대로(첫 1회)' ('[{0}] {1} / {2}' -f $t18FaultAgain.Thrown, $t18FaultAgain.AfterUpdate, $script:logLines.Count) '[] 1|True|입력 칸 주입 예외| / 1'
  Reset-ThemeTestState
  $t18FaultLog = Invoke-T18ApplyFault -ThrowingLog
  Assert-Case 'T18d 장치 만들기가 던짐 + 로그 기록도 던짐 - 8a · 12 밖으로 예외 0(시도 1줄) · 보관 비움(다음 갱신이 같은 줄을 다시 쓰지 않음)' ('[{0}]/{1}/{2}' -f $t18FaultLog.Thrown, $script:logLines.Count, $t18FaultLog.PendingCleared) '[]/1/True'
  # (6) 그리기 고장 알림 - 첫 고장 장치(오류가 적힌 첫 장치)의 원인을 [경고] 1줄로 · 원인 변수는 적용 실패와 함께 써서 어느 쪽이든 먼저 난 하나만 기록
  Reset-ThemeTestState
  $script:inputRecolorPainters = @(
    @{ Kind = 'picker'; Painter = (New-Object psobject -Property @{ LastError = '' }) },
    @{ Kind = 'combo'; Painter = (New-Object psobject -Property @{ LastError = '둘째 장치 원인' }) },
    @{ Kind = 'numeric'; Painter = (New-Object psobject -Property @{ LastError = '셋째 장치 원인' }) })
  $t18NoticeFirst = Invoke-T18Notice
  $t18NoticeAfterFirst = '[{0}]/{1}/[{2}]/{3}' -f $t18NoticeFirst, $script:logLines.Count, ($script:logLines -join ' / '), [string]$script:inputRecolorError
  $t18NoticeSecond = Invoke-T18Notice
  Assert-Case 'T18d 그리기 고장 알림 - 예외 0 · [경고] 1줄(다시 칠하지 못함 문구 + 오류가 적힌 첫 장치의 원인) · 원인 보관 / 둘째 알림 로그 0줄' ('{0} / [{1}] {2}' -f $t18NoticeAfterFirst, $t18NoticeSecond, $script:logLines.Count) `
    ('[]/1/[' + $t18PaintWarning + '둘째 장치 원인]/둘째 장치 원인 / [] 1')
  Reset-ThemeTestState
  $script:inputRecolorPainters = @(@{ Kind = 'picker'; Painter = (New-Object psobject -Property @{ LastError = '고장 원인' }) })
  $script:inputRecolorError = '앞선 적용 실패 원인'
  $t18NoticeAfterApply = Invoke-T18Notice
  Assert-Case 'T18d 그리기 고장 알림 - 적용 실패가 먼저 기록돼 있으면 적지 않음(먼저 난 하나만) · 원인 그대로' ('[{0}]/{1}/{2}' -f $t18NoticeAfterApply, $script:logLines.Count, [string]$script:inputRecolorError) '[]/0/앞선 적용 실패 원인'
  Reset-ThemeTestState
  $script:inputRecolorPainters = @(@{ Kind = 'picker'; Painter = (New-Object psobject -Property @{ LastError = '고장 원인' }) })
  $t18NoticeLog = Invoke-T18Notice -ThrowingLog
  $t18NoticeLogText = '[{0}]/{1}/{2}' -f $t18NoticeLog, $script:logLines.Count, [string]$script:inputRecolorError
  # 목록이 이상해도(만든 적 없음 · 장치가 없는 항목) 알림 밖으로 예외가 나가지 않습니다 - 메시지 루프에서 불리므로 새면 모달 오류 창입니다.
  # 이 두 입력은 던지지 않고 '오류가 적힌 장치 없음' 으로 읽힙니다(엄격 모드가 아니라 없는 속성은 빈 값) - 그래서 [경고] 가 '원인을 읽지 못함' 으로 1줄씩 남습니다
  Reset-ThemeTestState
  $t18NoticeNoList = Invoke-T18Notice
  $t18NoticeNoListText = '[{0}]/[{1}]/{2}' -f $t18NoticeNoList, ($script:logLines -join ' / '), [string]$script:inputRecolorError
  Reset-ThemeTestState
  $script:inputRecolorPainters = @(@{ Kind = 'picker' }, 'hashtable 이 아닌 항목')
  $t18NoticeBadList = Invoke-T18Notice
  $t18NoticeBadListText = '[{0}]/[{1}]/{2}' -f $t18NoticeBadList, ($script:logLines -join ' / '), [string]$script:inputRecolorError
  Assert-Case 'T18d 그리기 고장 알림 + 로그 기록도 던짐 → 예외 0(시도 1줄) · 원인 보관 / 목록이 없거나 이상함 → 예외 0 · [경고] 1줄(원인을 읽지 못함) · 원인 보관' `
    ('{0} / {1} / {2}' -f $t18NoticeLogText, $t18NoticeNoListText, $t18NoticeBadListText) `
    ('[]/1/고장 원인 / []/[' + $t18PaintWarning + '원인을 읽지 못함]/원인을 읽지 못함 / []/[' + $t18PaintWarning + '원인을 읽지 못함]/원인을 읽지 못함')
  # 바깥 받기(11-14 내부 검토 - 위 두 입력은 던지지 않아, 알림 함수의 본문 전체를 감싼 받기를 지워도 통과했음): 원인을 찾는 도중의 예외도 알림 밖으로 나가지 않고,
  # 그 예외의 글자가 원인으로 남습니다(로그까지는 가지 못해 0줄 - 원인이 차 있으니 뒤의 알림 · 적용 실패도 적지 않음: 첫 1회).
  # 던지게 하는 법: 오류 글자의 길이가 '0 과 견줄 수 없는 값'(빈 hashtable)인 가짜 장치 - 알림 함수의 길이 비교가 던집니다. 속성 읽기가 던지는 가짜로는 안 됩니다 -
  # PowerShell 은 속성을 읽다 난 예외를 삼켜 빈 값으로 읽습니다(11-14 실측: 던지는 ScriptProperty 를 넣자 예외 없이 '원인을 읽지 못함' 1줄이 남았음).
  # 기대하는 원인 글자는 같은 비교를 여기서 일으켜 얻습니다(메시지가 윈도우 표시 언어를 따름)
  Reset-ThemeTestState
  $t18BadLength = @{}
  $t18CompareMessage = ''
  try { [void]($t18BadLength -gt 0) } catch { $t18CompareMessage = $_.Exception.Message }
  $script:inputRecolorPainters = @(@{ Kind = 'picker'; Painter = (New-Object psobject -Property @{ LastError = (New-Object psobject -Property @{ Length = $t18BadLength }) }) })
  $t18NoticeReadFault = Invoke-T18Notice
  Assert-Case 'T18d 그리기 고장 알림 - 원인을 찾다가 예외(오류 글자의 길이 비교가 던짐) → 알림 밖으로 예외 0 · 로그 0줄 · 원인 변수 = 그 예외의 글자(비어 있지 않음)' `
    ('[{0}]/{1}/{2}/{3}' -f $t18NoticeReadFault, $script:logLines.Count, ($t18CompareMessage -ne ''), ([string]$script:inputRecolorError -ceq $t18CompareMessage)) '[]/0/True/True'
} catch { Assert-SectionError -Section 'T18d' -ErrorRecord $_ } finally {
  $script:inputRecolorPainters = $null
  $script:inputRecolorError = $null
  $script:inputRecolorPendingWarning = $null
  Set-HoneyPalette -Theme 'light'
}

# ── T18a 색 대응 계산 (설계 7.13 - 장치의 정적 순수 함수 TwoPoint: 원본 A → 목표 A · 원본 B → 목표 B 가 되는 채널별 1차식) ─────────────────────
try {
  $t18Type = 'HoneyInputRecolor' -as [type]
  Assert-Case 'T18a 준비 - 장치 형식이 올라와 있음(위 T18d 다크 첫 호출이 올림)' ([bool]$t18Type) $true
  if ($t18Type) {
    $t18White = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $t18Black = [System.Drawing.Color]::FromArgb(0, 0, 0)
    # 흰 종이 → 입력 바탕 · 검은 잉크 → 기본 글자 (안 잠긴 시간 칸의 대응과 같은 꼴). 두 원본 색 · 회색 셋(64 · 128 · 200) · 채널이 서로 다른 색 둘을 함께 보냅니다
    $t18Matrix = $t18Type::TwoPoint($t18White, $t18DarkInput, $t18Black, $t18DarkText)
    $t18Mapped = @(Convert-T18Colors -Matrix $t18Matrix -Colors @($t18White, $t18Black, [System.Drawing.Color]::FromArgb(64, 64, 64), [System.Drawing.Color]::FromArgb(128, 128, 128),
        [System.Drawing.Color]::FromArgb(200, 200, 200), [System.Drawing.Color]::FromArgb(255, 0, 0), [System.Drawing.Color]::FromArgb(0, 255, 255)))
    "INFO T18a 흰 종이 · 검은 잉크 대응: 255 → {0} · 0 → {1} · 64 → {2} · 128 → {3} · 200 → {4} · 빨강(255,0,0) → {5} · 청록(0,255,255) → {6}" -f $t18Mapped
    Assert-Case 'T18a 두 원본 색 → 목표 색(채널마다 1 이내 - 반올림): 255,255,255 → 입력 바탕 23,23,26 · 0,0,0 → 기본 글자 232,230,227' `
      ('{0}/{1}' -f (Test-T18Near -RgbText $t18Mapped[0] -Color $t18DarkInput -Tolerance 1), (Test-T18Near -RgbText $t18Mapped[1] -Color $t18DarkText -Tolerance 1)) 'True/True'
    # 중간색은 두 목표 사이에 있고, 원본이 밝을수록 결과는 어둡습니다(종이가 어두워지고 잉크가 밝아지는 뒤집힌 대응 - 순서가 유지돼야 글자 가장자리의 번짐이 자연스러움)
    $t18Between = @($t18Mapped[2], $t18Mapped[3], $t18Mapped[4] | ForEach-Object {
        $betweenChannels = @($_ -split ',' | ForEach-Object { [int]$_ })
        (($betweenChannels[0] -gt 23) -and ($betweenChannels[0] -lt 232) -and ($betweenChannels[1] -gt 23) -and ($betweenChannels[1] -lt 230) -and ($betweenChannels[2] -gt 26) -and ($betweenChannels[2] -lt 227)) })
    $t18Reds = @($t18Mapped[2], $t18Mapped[3], $t18Mapped[4] | ForEach-Object { [int]($_ -split ',')[0] })
    Assert-Case 'T18a 중간색(64 · 128 · 200) - 채널마다 두 목표 사이 · 원본이 밝을수록 결과가 어두움' ('{0}/{1}' -f ($t18Between -join ','), (($t18Reds[0] -gt $t18Reds[1]) -and ($t18Reds[1] -gt $t18Reds[2]))) 'True,True,True/True'
    # 채널끼리 섞지 않습니다: 빨강만 255 인 색은 빨강 채널만 '종이' 값으로, 나머지는 '잉크' 값으로 갑니다(회색만 넣어 보면 채널이 섞여도 드러나지 않음)
    Assert-Case 'T18a 채널마다 따로 - 빨강(255,0,0) → 23,230,227 · 청록(0,255,255) → 232,23,26 (채널마다 1 이내)' `
      ('{0}/{1}' -f (Test-T18Near -RgbText $t18Mapped[5] -Color ([System.Drawing.Color]::FromArgb(23, 230, 227)) -Tolerance 1), (Test-T18Near -RgbText $t18Mapped[6] -Color ([System.Drawing.Color]::FromArgb(232, 23, 26)) -Tolerance 1)) 'True/True'
    # 잠긴 칸의 꼴: 종이 254 · 잉크는 윈도우 회색 109
    $t18LockedMatrix = $t18Type::TwoPoint([System.Drawing.Color]::FromArgb(254, 254, 254), $t18DarkInput, [System.Drawing.Color]::FromArgb(109, 109, 109), $t18DarkText)
    $t18LockedMapped = @(Convert-T18Colors -Matrix $t18LockedMatrix -Colors @([System.Drawing.Color]::FromArgb(254, 254, 254), [System.Drawing.Color]::FromArgb(109, 109, 109)))
    Assert-Case 'T18a 잠긴 칸의 꼴 - 254,254,254 → 입력 바탕 · 109,109,109 → 기본 글자(채널마다 1 이내)' `
      ('{0}/{1}' -f (Test-T18Near -RgbText $t18LockedMapped[0] -Color $t18DarkInput -Tolerance 1), (Test-T18Near -RgbText $t18LockedMapped[1] -Color $t18DarkText -Tolerance 1)) 'True/True'
    # 두 원본의 채널 값이 같으면(0 으로 나누게 되는 채널) 그 채널은 평행 이동입니다: 빨강 100 = 100 → +10, 파랑 200 = 200 → -10, 초록 50 → 70 · 80 → 100 은 보통의 대응(+20)
    $t18ShiftMatrix = $t18Type::TwoPoint([System.Drawing.Color]::FromArgb(100, 50, 200), [System.Drawing.Color]::FromArgb(110, 70, 190), [System.Drawing.Color]::FromArgb(100, 80, 200), [System.Drawing.Color]::FromArgb(30, 100, 40))
    $t18ShiftMapped = @(Convert-T18Colors -Matrix $t18ShiftMatrix -Colors @([System.Drawing.Color]::FromArgb(100, 50, 200), [System.Drawing.Color]::FromArgb(0, 65, 255), [System.Drawing.Color]::FromArgb(200, 80, 60)))
    Assert-Case 'T18a 두 원본의 채널 값이 같은 채널(빨강 · 파랑) = 평행 이동(+10 · -10) · 다른 채널(초록)은 두 점 대응 - 세 색: 원본 A · (0,65,255) · (200,80,60)' ($t18ShiftMapped -join ' ') '110,70,190 10,85,245 210,100,50'
  }
} catch { Assert-SectionError -Section 'T18a' -ErrorRecord $_ }

# ── T18 장치 사전 확인 (하네스 행의 문지기 - 11-14) ─────────────────────────────────────────────────────────────
# 아래 하네스 행은 다크로 바꾼 폼을 실제로 그립니다(DrawToBitmap). 이제 그 폼의 시간 · 목록 · 숫자 칸에는 장치가 얹혀 있어, 그 그리기가 장치의 창 프로시저를
# 네이티브 메시지 경로로 지나갑니다. 장치의 창 프로시저가 예외를 밖으로 내면 잡을 수 있는 예외로 올라오지 않고 이 프로세스가 출력 없이 끝납니다
# (11-14 실측: 종료 코드 2 - 하네스 준비 ② 와 같은 경로). 그래서 먼저 제품 함수로 켠 장치의 창 프로시저를 직접 불러 보고(관리 코드 경로 - 새는 예외가 잡힘),
# 통과했을 때만 하네스 행을 돕니다(T14 · T17 이 OnPaint 를 직접 부른 뒤에만 DrawToBitmap 하는 것과 같은 꼴)
function Invoke-T18WndProc {
  # 장치의 창 프로시저를 직접 부릅니다(관리 코드 경로). -PrintClient 면 유효한 메모리 비트맵 DC 를 그릴 대상으로 주는 그림 받기(WM_PRINTCLIENT),
  # -PaintToDc 면 같은 DC 를 그릴 대상으로 실어 보낸 화면 그리기(WM_PAINT 의 wParam - '이 DC 에 그려 달라' 는 호출), 둘 다 아니면 보통의 화면 그리기
  # (WM_PAINT - 그릴 대상을 받지 않음). 밖으로 나온 예외를 '형식 이름: 메시지' 로 돌려줍니다(없으면 '')
  param($Painter, [switch]$PrintClient, [switch]$PaintToDc)
  $procMethod = $Painter.GetType().GetMethod('WndProc', [System.Reflection.BindingFlags]'NonPublic, Instance')
  if (-not $procMethod) { return '창 프로시저(WndProc)를 찾지 못함' }
  $procArguments = New-Object object[] 1
  $procThrown = ''
  if ($PrintClient -or $PaintToDc) {
    $procBitmap = New-Object System.Drawing.Bitmap($Painter.Target.Width, $Painter.Target.Height)
    $procGraphics = [System.Drawing.Graphics]::FromImage($procBitmap)
    try {
      $procDc = $procGraphics.GetHdc()
      try {
        if ($PrintClient) { $procArguments[0] = [System.Windows.Forms.Message]::Create($Painter.Target.Handle, 0x0318, $procDc, [IntPtr]4) }
        else { $procArguments[0] = [System.Windows.Forms.Message]::Create($Painter.Target.Handle, 0x000F, $procDc, [IntPtr]::Zero) }
        try { [void]$procMethod.Invoke($Painter, $procArguments) } catch { $procThrown = '{0}: {1}' -f $_.Exception.GetBaseException().GetType().Name, $_.Exception.GetBaseException().Message }
      } finally { $procGraphics.ReleaseHdc($procDc) }
    } finally {
      $procGraphics.Dispose()
      $procBitmap.Dispose()
    }
  } else {
    $procArguments[0] = [System.Windows.Forms.Message]::Create($Painter.Target.Handle, 0x000F, [IntPtr]::Zero, [IntPtr]::Zero)
    try { [void]$procMethod.Invoke($Painter, $procArguments) } catch { $procThrown = '{0}: {1}' -f $_.Exception.GetBaseException().GetType().Name, $_.Exception.GetBaseException().Message }
  }
  return $procThrown
}
# ── T18 창 프로시저 사슬 도구 (11-14 설계 7.14 - 테스트 전용 C#) ─────────────────────────────────────────────────────────────
# 장치는 맡지 않는 메시지와 제 그림 받기를 '붙기 직전의 창 프로시저'(ChainProc)로 직접 넘깁니다(Pass). NativeWindow 의 기본 넘기기(base.WndProc)는 같은 핸들에
# 먼저 붙은 관리 창(컨트롤 자신)을 바로 불러, 그 사이에 얹힌 서브클래스(숫자 칸 글자 자리의 말풍선 중계)를 건너뜁니다. 그것을 창 쪽에서 보는 도구입니다:
# 창 프로시저 읽기 · 바꾸기 · 메시지 보내기 · 주소가 든 모듈의 이름, 그리고 셀 수 있는 서브클래스 둘 - 원시(SetWindowLongPtr 로 창 프로시저를 바꿔 얹음)와
# comctl32(SetWindowSubclass - 말풍선이 도구 창의 마우스를 중계받을 때 쓰는 것과 같은 마스터 창 프로시저에 얹힘 · RemoveWindowSubclass 로 지울 수도 있음 -
# T18g Z 계수기). 둘 다 지켜보는 메시지(아무도 처리하지 않는 WM_APP + 0x123)와 그림 받기(WM_PRINTCLIENT)를 센 뒤 다음 창 프로시저로 넘깁니다.
# 셀 수 있는 서브클래스는 그 창이 없어질 때까지 불리므로 객체를 테스트 끝까지 잡아 둡니다($t18ChainKeep - 수거되면 그 창의 다음 메시지에서 프로세스가 죽음)
$t18ChainKeep = New-Object System.Collections.Generic.List[object]
$t18ChainReady = $false
try {
  if (-not ('HoneyThemeTest.ChainNative' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace HoneyThemeTest {
    public static class ChainNative {
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int index);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] public static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int index, IntPtr value);
        [DllImport("user32.dll", EntryPoint = "CallWindowProcW")] public static extern IntPtr CallWindowProc(IntPtr proc, IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
        [DllImport("user32.dll", EntryPoint = "SendMessageW")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
        [DllImport("kernel32.dll")] static extern bool GetModuleHandleExW(uint flags, IntPtr address, out IntPtr module);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern uint GetModuleFileNameW(IntPtr module, StringBuilder name, uint size);
        [DllImport("kernel32.dll", CharSet = CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr module, string name);
        // 그 창의 맨 위 창 프로시저 (GWLP_WNDPROC)
        public static IntPtr WindowProcOf(IntPtr hWnd) { return GetWindowLongPtr(hWnd, -4); }
        // 주소가 든 모듈 (주소로 찾기 · 참조 수 그대로) - 없으면 0 (관리 코드 대리자의 주소 등)
        public static IntPtr ModuleOf(IntPtr address) {
            IntPtr module;
            if (!GetModuleHandleExW(4 | 2, address, out module)) { return IntPtr.Zero; }
            return module;
        }
        public static string ModuleNameOf(IntPtr address) {
            IntPtr module = ModuleOf(address);
            if (module == IntPtr.Zero) { return "(모듈 없음)"; }
            StringBuilder name = new StringBuilder(520);
            GetModuleFileNameW(module, name, 520);
            return System.IO.Path.GetFileName(name.ToString());
        }
    }

    // 원시 서브클래스: 창 프로시저를 바꿔 얹고, 지켜보는 메시지와 그림 받기를 센 뒤 바로 아래 창 프로시저로 넘깁니다
    public sealed class RawCounter {
        delegate IntPtr WindowProcedure(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
        readonly WindowProcedure procedure;
        readonly IntPtr below;
        readonly int watch;
        public readonly IntPtr Proc;
        public int Count;
        public int PrintCount;
        public RawCounter(IntPtr hWnd, int watchMessage) {
            watch = watchMessage;
            procedure = new WindowProcedure(Callback);
            Proc = Marshal.GetFunctionPointerForDelegate(procedure);
            below = ChainNative.SetWindowLongPtr(hWnd, -4, Proc);
        }
        IntPtr Callback(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam) {
            if (msg == watch) { Count++; }
            if (msg == 0x0318) { PrintCount++; }
            return ChainNative.CallWindowProc(below, hWnd, msg, wParam, lParam);
        }
    }

    // comctl32 서브클래스: 주어진 comctl32 모듈의 SetWindowSubclass 로 얹고, 지켜보는 메시지와 그림 받기를 센 뒤 DefSubclassProc 로 넘깁니다.
    // Remove 는 같은 모듈의 RemoveWindowSubclass 로 이 등록을 지웁니다(그 창 마스터의 마지막 등록이면 마스터가 맨 위일 때 스스로 빠지고, 맨 위가 아니면 통과 역할로 남음)
    public sealed class ComctlCounter {
        delegate IntPtr SubclassProcedure(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam, UIntPtr id, UIntPtr refData);
        delegate bool SetSubclass(IntPtr hWnd, IntPtr procedure, UIntPtr id, UIntPtr refData);
        delegate bool RemoveSubclass(IntPtr hWnd, IntPtr procedure, UIntPtr id);
        delegate IntPtr DefSubclass(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
        readonly SubclassProcedure procedure;
        readonly DefSubclass next;
        readonly RemoveSubclass remove;
        readonly IntPtr window;
        readonly int watch;
        public readonly bool Installed;
        public int Count;
        public int PrintCount;
        public ComctlCounter(IntPtr comctlModule, IntPtr hWnd, int watchMessage) {
            watch = watchMessage;
            window = hWnd;
            procedure = new SubclassProcedure(Callback);
            IntPtr setAddress = ChainNative.GetProcAddress(comctlModule, "SetWindowSubclass");
            IntPtr defAddress = ChainNative.GetProcAddress(comctlModule, "DefSubclassProc");
            IntPtr removeAddress = ChainNative.GetProcAddress(comctlModule, "RemoveWindowSubclass");
            if (setAddress == IntPtr.Zero || defAddress == IntPtr.Zero || removeAddress == IntPtr.Zero) { return; }
            next = (DefSubclass)Marshal.GetDelegateForFunctionPointer(defAddress, typeof(DefSubclass));
            remove = (RemoveSubclass)Marshal.GetDelegateForFunctionPointer(removeAddress, typeof(RemoveSubclass));
            SetSubclass install = (SetSubclass)Marshal.GetDelegateForFunctionPointer(setAddress, typeof(SetSubclass));
            Installed = install(hWnd, Marshal.GetFunctionPointerForDelegate(procedure), (UIntPtr)0x5151, UIntPtr.Zero);
        }
        // 이 등록을 지웁니다 - 지웠으면 참(얹지 못했으면 거짓)
        public bool Remove() {
            if (!Installed || remove == null) { return false; }
            return remove(window, Marshal.GetFunctionPointerForDelegate(procedure), (UIntPtr)0x5151);
        }
        IntPtr Callback(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam, UIntPtr id, UIntPtr refData) {
            if (msg == watch) { Count++; }
            if (msg == 0x0318) { PrintCount++; }
            return next(hWnd, msg, wParam, lParam);
        }
    }
}
'@
  }
  $t18ChainReady = $true
} catch { Assert-SectionError -Section 'T18 창 프로시저 사슬 도구' -ErrorRecord $_ }

$t18DeviceReady = $false
if ($harnessReady) {
  try {
    Reset-ThemeTestState
    New-T18Form -Handles
    Set-T18Theme -Theme 'dark'
    # 사슬(11-14 설계 7.14): 장치를 만들기 전에 창마다 맨 위 창 프로시저를 읽어 둡니다 - 장치는 붙기 직전에 같은 값을 읽어 넘기기(Pass)에 써야 합니다
    $t18ProcBefore = @{}
    if ($t18ChainReady) {
      foreach ($t18ProcControl in @(Get-HarnessControls -Parent $script:form)) { $t18ProcBefore[[string]$t18ProcControl.Handle] = [HoneyThemeTest.ChainNative]::WindowProcOf($t18ProcControl.Handle) }
    }
    Update-InputRecolor
    $t18ProbeEntries = @(@(Get-T18Entries) | Where-Object { $_.Painter.IsAttached })
    # 사슬 행(메시지를 보내기 전 - 11-14 설계 7.14 · 설계 리뷰 조건): 이 테스트에서 붙은 장치가 메시지를 처음 받는 곳이 아래 직접 호출입니다. 붙기 직전 창 프로시저를
    # AssignHandle 뒤에 읽으면(장치 자신) 넘기기가 끝없이 자신을 불러 그 호출 하나로 프로세스가 출력 없이 끝납니다(스택 넘침은 잡을 수 없음 - 직접 호출도 같음).
    # 그래서 직접 호출보다 먼저 장치마다 봅니다: 붙기 직전 창 프로시저 = 장치를 만들기 전 그 창의 맨 위 · 0 아님 · 자기 창 프로시저 = 지금 맨 위(장치가 맨 위에 얹힘) · 둘이 다름.
    # 어긋난 장치는 그 창의 창 프로시저를 장치를 만들기 전 값으로 되돌려 장치를 빼 둡니다 - 그대로 두면 이 폼을 정리할 때 오는 메시지로도 프로세스가 죽습니다
    $t18ChainFaults = @(foreach ($t18ProbeEntry in $t18ProbeEntries) {
        $t18ProbeTarget = $t18ProbeEntry.Painter.Target
        $t18ProcFront = $(if ($t18ChainReady) { [HoneyThemeTest.ChainNative]::WindowProcOf($t18ProbeTarget.Handle) } else { [IntPtr]::Zero })
        $t18ProcExpected = $t18ProcBefore[[string]$t18ProbeTarget.Handle]
        $t18ChainSound = ($null -ne $t18ProcExpected) -and ($t18ProbeEntry.Painter.ChainProc -ne [IntPtr]::Zero) -and ($t18ProbeEntry.Painter.ChainProc -eq $t18ProcExpected) -and
          ($t18ProbeEntry.Painter.SelfProc -eq $t18ProcFront) -and ($t18ProbeEntry.Painter.SelfProc -ne $t18ProbeEntry.Painter.ChainProc)
        if (-not $t18ChainSound) {
          '{0}: 붙기 직전 = 만들기 전 맨 위 {1} · 0 아님 {2} · 자기 = 지금 맨 위 {3} · 둘이 다름 {4}' -f $t18ProbeEntry.Painter.Owner.Name, ($t18ProbeEntry.Painter.ChainProc -eq $t18ProcExpected),
            ($t18ProbeEntry.Painter.ChainProc -ne [IntPtr]::Zero), ($t18ProbeEntry.Painter.SelfProc -eq $t18ProcFront), ($t18ProbeEntry.Painter.SelfProc -ne $t18ProbeEntry.Painter.ChainProc)
          if ($t18ChainReady -and ($null -ne $t18ProcExpected) -and ($t18ProcExpected -ne [IntPtr]::Zero)) { [void][HoneyThemeTest.ChainNative]::SetWindowLongPtr($t18ProbeTarget.Handle, -4, $t18ProcExpected) }
        }
      })
    Assert-Case 'T18 장치 사전 확인 - 사슬(메시지를 보내기 전): 도구 준비 · 붙은 장치 일곱 모두 붙기 직전 창 프로시저 = 장치를 만들기 전 그 창의 맨 위 · 0 아님 · 자기 창 프로시저 = 지금 맨 위 · 둘이 다름' `
      ('{0}/{1}/[{2}]' -f $t18ChainReady, $t18ProbeEntries.Count, ($t18ChainFaults -join ' / ')) 'True/7/[]'
    if ($t18ChainReady -and ($t18ChainFaults.Count -eq 0)) {
      # 핸들이 있는 일곱 장치(표 밖 셀 편집 콤보는 핸들이 없어 붙지 않음)에 그림 받기 → 화면 그리기를 한 번씩 직접. 잠긴 칸과 안 잠긴 칸이 섞여 있어 두 대응을 모두 지나갑니다
      $t18ProbeLeaks = foreach ($t18ProbeEntry in $t18ProbeEntries) {
        foreach ($t18ProbePrint in @($true, $false)) {
          $t18ProbeThrown = Invoke-T18WndProc -Painter $t18ProbeEntry.Painter -PrintClient:$t18ProbePrint
          if ($t18ProbeThrown -ne '') { '{0} {1}: {2}' -f $t18ProbeEntry.Painter.Owner.Name, $(if ($t18ProbePrint) { '그림 받기' } else { '화면 그리기' }), $t18ProbeThrown }
        }
      }
      $t18ProbeErrors = (@($t18ProbeEntries | ForEach-Object { $_.Painter.LastError })) -join ''
      Assert-Case 'T18 장치 사전 확인 - 제품 함수로 켠 장치 일곱의 창 프로시저를 직접 호출(그림 받기 · 화면 그리기 각 1번): 밖으로 나온 예외 0 · 장치 오류 없음 · 모두 켜진 채' `
        ('{0}/[{1}]/[{2}]/{3}' -f $t18ProbeEntries.Count, ((@($t18ProbeLeaks)) -join ' / '), $t18ProbeErrors, @($t18ProbeEntries | Where-Object { $_.Painter.Active }).Count) '7/[]/[]/7'
      # 문지기의 조건은 '사슬이 맞고 직접 호출이 새지 않았다' 입니다 - 장치 수가 일곱보다 많은 것(대상 찾기가 넓어짐)은 위 행이 실패로 알리되 하네스 행을 막지는 않습니다.
      # 일곱보다 적으면 확인하지 못한 종류가 있다는 뜻이라 막습니다
      $t18DeviceReady = ($t18ProbeEntries.Count -ge 7) -and (@($t18ProbeLeaks).Count -eq 0) -and ($t18ProbeErrors -eq '')
    }
  } catch { Assert-SectionError -Section 'T18 장치 사전 확인' -ErrorRecord $_ } finally {
    $script:inputRecolorPainters = $null
    $script:inputRecolorError = $null
    $script:inputRecolorPendingWarning = $null
    Set-HoneyPalette -Theme 'light'
  }
  if (-not $t18DeviceReady) {
    # 하네스 준비 실패와 같은 꼴: 1줄만 남기고 처리기를 실제로 돌리는 행을 부르지 않습니다(위 사전 확인 행이 이미 실패로 셌으므로 여기서는 세지 않음)
    'INFO T18 장치 사전 확인이 통과하지 못해 하네스 행(T8 · T13 · T14 · T16 · T17 · T18 하네스 행)을 부르지 않습니다'
  }
}

# ===== 하네스 행 (처리기를 실제로 돌림 - 하네스 준비와 장치 사전 확인이 통과했을 때만) =====
if ($harnessReady -and $t18DeviceReady) {
  # ── T8 왕복 동일성 (설계 1.2 H1 · 계약 L - 라이트 → 다크 → 라이트) ──────────────────────────────
  Invoke-T8Scene -Name '그림' -Scene {
    # 그림 비교가 자식 컨트롤까지 담는가(11-13 내부 검토): 아래 장면들의 '폼 화소 = 기준' 과 '다크 화소는 기준과 다름' 은 폼 바탕만 찍혀도 둘 다 참입니다 -
    # 보이지 않는 폼의 DrawToBitmap 은 핸들이 있는 자식만 찍으므로, 하네스의 핸들 만들기(Initialize-AllHandles)가 빠져도 아무 행도 실패하지 않았습니다.
    # 그래서 하네스가 만든 컨트롤이 모두 핸들을 가졌는지와, 자식 하나([시작])의 바탕만 바꿔도 폼 화소 해시가 달라지는지를 봅니다(핸들이 없으면 둘 다 갈림)
    Start-ThemeHarness
    $handleMissing = @(Get-HarnessControls -Parent $form | Where-Object { -not $_.IsHandleCreated } | ForEach-Object { $_.Name })
    $pixelsBefore = Get-FormPixelHash
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(1, 2, 3)
    $pixelsAfter = Get-FormPixelHash
    Assert-Case 'T8 그림 - 하네스 컨트롤 핸들 모두 있음 · 자식([시작]) 바탕만 바꿔도 폼 화소가 달라짐(그림이 자식을 담음)' ('[{0}]/{1}' -f ($handleMissing -join ','), ($pixelsBefore -cne $pixelsAfter)) '[]/True'
  }
  Invoke-T8Scene -Name '형식' -Scene {
    Start-ThemeHarness -SettingsOpen -NyanSelected -Warns 1
    $restoreShape = Get-ThemeRestoreState
    Assert-Case 'T8 복원 상태 형식(V8 · K3) - hashtable 1개 · 키 4 · 토글 키 6 · 잔상 표시 bool' ('{0}/{1}/{2}/{3}/{4}' -f ($restoreShape -is [hashtable]), @($restoreShape).Count,
        ((@($restoreShape.Keys) | Sort-Object) -join ','), ((@($restoreShape.Toggles.Keys) | Sort-Object) -join ','), ($restoreShape.BadgeAfterimage -is [bool])) `
      'True/1/BadgeAfterimage,NyanCard,Status,Toggles/chkAcrRandom,chkCrRandom,chkDcrRandom,chkLcrRandom,chkTabLog,chkTabSettings/True'
    Assert-Case "T8 복원 상태 값 - 시작 잔상 3개: 상태줄 'Title' · 설정 토글 'Text' · 카드 'General' · 배지 잔상 참" ('{0}/{1}/{2}/{3}' -f (Format-StatusMeaning -Meaning $restoreShape.Status),
        $restoreShape.Toggles['chkTabSettings'], $restoreShape.NyanCard, $restoreShape.BadgeAfterimage) 'Title/Text/General/True'
  }
  Invoke-T8Scene -Name 'a' -Scene {
    Start-ThemeHarness -SettingsOpen
    $sceneBefore = Get-HarnessState
    $sceneLight = '{0}/{1}' -f (Get-RgbText $chkTabSettings.ForeColor), $chkTabSettings.FlatAppearance.CheckedBackColor.IsEmpty
    # 다크가 된 직후 토글 6개(설정 · 로그 · 랜덤 4)의 테두리 · 눌린 바탕 - 생성 때 한 번만 칠한 값이라 갱신 7번이 하나라도 빠뜨리면 라이트 값이 남습니다
    $sceneTrip = Invoke-T8RoundTrip -DarkPreProbe { (@($chkTabSettings, $chkTabLog, $chkCrRandom, $chkAcrRandom, $chkDcrRandom, $chkLcrRandom) | ForEach-Object {
          '{0}={1}/{2}' -f $_.Name, (Get-RgbText $_.FlatAppearance.BorderColor), (Get-RgbText $_.FlatAppearance.CheckedBackColor) }) -join ' ' } `
      -DarkProbe { '{0}/{1}' -f (Get-RgbText $chkTabSettings.ForeColor), (Get-RgbText $chkTabSettings.FlatAppearance.CheckedBackColor) }
    Assert-Case 'T8 a 시작 직후 - 라이트 눌린 글자 66,50,22(잔상 ①) · 다크 = 다크 Text · 눌린 바탕 다크 TabOn' ('{0} → {1}' -f $sceneLight, $sceneTrip.Dark) '66,50,22/True → 232,230,227/104,82,34'
    Assert-Case 'T8 a 다크 - 토글 6개 테두리 다크 Border 62,62,68 · 눌린 바탕 다크 TabOn 104,82,34(7번이 모두 다시 칠함)' $sceneTrip.Pre `
      'chkTabSettings=62,62,68/104,82,34 chkTabLog=62,62,68/104,82,34 chkCrRandom=62,62,68/104,82,34 chkAcrRandom=62,62,68/104,82,34 chkDcrRandom=62,62,68/104,82,34 chkLcrRandom=62,62,68/104,82,34'
    Assert-RoundTrip -Name 'T8 a 시작 직후' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'b' -Scene {
    Start-ThemeHarness -SettingsOpen
    $chkTabSettings.Checked = $false
    Update-TabToggleStyle
    $chkTabSettings.Checked = $true
    Update-TabToggleStyle
    $sceneBefore = Get-HarnessState
    $sceneLight = Get-RgbText $chkTabSettings.ForeColor
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { Get-RgbText $chkTabSettings.ForeColor }
    Assert-Case 'T8 b 토글을 끄고 켬 - 라이트 91,62,6 · 다크 TabOnText 255,240,205' ('{0} → {1}' -f $sceneLight, $sceneTrip.Dark) '91,62,6 → 255,240,205'
    Assert-RoundTrip -Name 'T8 b 끄고 켬' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'c' -Scene {
    Start-ThemeHarness -NyanSelected
    $sceneBefore = Get-HarnessState
    $sceneLight = Get-CardText
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { Get-CardText }
    Assert-Case "T8 c 기타 카드 General(시작 잔상 ②) - 라이트 일반 모양 + 굵게 · 다크 Control 44,44,48 · Border 62,62,68 · 두께 1 · 굵게" ('{0} → {1}' -f $sceneLight, $sceneTrip.Dark) '255,253,247/226,205,160/1/True → 44,44,48/62,62,68/1/True'
    Assert-RoundTrip -Name 'T8 c 카드 General' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'd' -Scene {
    Start-ThemeHarness
    Update-EtcNyanCardStyle
    $sceneBefore = Get-HarnessState
    $sceneLight = Get-CardText
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { Get-CardText }
    Assert-Case 'T8 d 시작 뒤 선택 모양(Selected) - 라이트 250,240,218 · 다크 58,56,50 · Honey · 2' ('{0} → {1}' -f $sceneLight, $sceneTrip.Dark) '250,240,218/247,181,0/2/True → 58,56,50/247,181,0/2/True'
    Assert-RoundTrip -Name 'T8 d 카드 Selected' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'e' -Scene {
    Start-ThemeHarness
    foreach ($statusCase in @(@('Title', '242,179,61'), @('Firebrick', '255,110,110'), @('ForestGreen', '144,238,144'), @('SteelBlue', '135,206,235'), @('DimGray', '154,154,160'), @('DarkOrange', '255,140,0'))) {
      $lblStatus.ForeColor = $(if ($statusCase[0] -eq 'Title') { $script:themeTitle } else { [System.Drawing.Color]::FromName($statusCase[0]) })
      $script:logLines.Clear()
      $script:t8SaveCount = 0
      $sceneBefore = Get-HarnessState
      $sceneTrip = Invoke-T8RoundTrip -DarkProbe { '{0}/{1}' -f (Get-RgbText $lblStatus.ForeColor), $(if ($script:statusColorMeaning -is [string]) { $script:statusColorMeaning } else { $script:statusColorMeaning.Name }) }
      Assert-Case ("T8 e 상태줄 {0} - 다크 표시 = 2.4 표 · 기록된 의미는 원래 색" -f $statusCase[0]) $sceneTrip.Dark ('{0}/{1}' -f $statusCase[1], $statusCase[0])
      Assert-RoundTrip -Name ('T8 e 상태줄 ' + $statusCase[0]) -Reference $sceneBefore -Trip $sceneTrip
    }
  }
  Invoke-T8Scene -Name 'f1' -Scene {
    Start-ThemeHarness -Warns 1
    $sceneBefore = Get-HarnessState
    $sceneLight = Get-BadgeText
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { Get-BadgeText }
    Assert-Case 'T8 f1 시작 전 경고 잔상(K3) - 라이트 Gold 위 66,50,22 · 표시 참 / 다크 Gold 위 HoneyInk 42,28,0 · 표시 참' ('{0} → {1}' -f $sceneLight, $sceneTrip.Dark) '255,215,0/66,50,22/True → 255,215,0/42,28,0/True'
    Assert-RoundTrip -Name 'T8 f1 경고 잔상' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'f2' -Scene {
    Start-ThemeHarness -Warns 1 -Errors 1
    $sceneBefore = Get-HarnessState
    $sceneLight = Get-BadgeText
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { Get-BadgeText }
    Assert-Case 'T8 f2 시작 전 오류 잔상(오류 우선) - 라이트 222,105,92 위 66,50,22 / 다크 224,112,95 위 White · 표시 참' ('{0} → {1}' -f $sceneLight, $sceneTrip.Dark) '222,105,92/66,50,22/True → 224,112,95/255,255,255/True'
    Assert-RoundTrip -Name 'T8 f2 오류 잔상' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'f3' -Scene {
    # 기준 = 같은 시작 상태(f1)에서 라이트로 같은 줄을 받았을 때 (E3 - 표시 참에서 시작해야 Update-LogTabBadge 의 표시 거짓이 행동으로 잡힘)
    Start-ThemeHarness -Warns 1
    Add-ColoredLogLine '12:01:00 [경고] 다크 중 새 경고'
    $sceneReference = Get-HarnessState
    $sceneReferenceBadge = Get-BadgeText
    Start-ThemeHarness -Warns 1
    $sceneTrip = Invoke-T8RoundTrip -DarkPreProbe { [string][bool]$script:logBadgeStartAfterimage } -DarkAction { Add-ColoredLogLine '12:01:00 [경고] 다크 중 새 경고' } -DarkProbe { Get-BadgeText }
    Assert-Case "T8 f3 f1(표시 참) → 다크 중 새 경고 1줄 - 표시 거짓 · Gold · 42,28,0 / 라이트로 오면 66,45,0('HoneyInk') · 표시 거짓" ('{0} → {1} → {2}' -f $sceneTrip.Pre, $sceneTrip.Dark, $sceneReferenceBadge) 'True → 255,215,0/42,28,0/False → 255,215,0/66,45,0/False'
    Assert-RoundTrip -Name 'T8 f3 다크 중 새 경고' -Reference $sceneReference -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'f4' -Scene {
    Start-ThemeHarness -Warns 1 -Errors 1
    Add-ColoredLogLine '12:01:00 [오류] 다크 중 새 오류'
    $sceneReference = Get-HarnessState
    $sceneReferenceBadge = Get-BadgeText
    Start-ThemeHarness -Warns 1 -Errors 1
    $sceneTrip = Invoke-T8RoundTrip -DarkPreProbe { [string][bool]$script:logBadgeStartAfterimage } -DarkAction { Add-ColoredLogLine '12:01:00 [오류] 다크 중 새 오류' } -DarkProbe { Get-BadgeText }
    Assert-Case 'T8 f4 f2(표시 참) → 다크 중 새 오류 1줄 - 표시 거짓 · 224,112,95 · White / 라이트로 오면 222,105,92 · White · 표시 거짓' ('{0} → {1} → {2}' -f $sceneTrip.Pre, $sceneTrip.Dark, $sceneReferenceBadge) 'True → 224,112,95/255,255,255/False → 222,105,92/255,255,255/False'
    Assert-RoundTrip -Name 'T8 f4 다크 중 새 오류' -Reference $sceneReference -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'f5' -Scene {
    Start-ThemeHarness -Warns 1
    Reset-LogTabBadge
    $sceneReference = Get-HarnessState
    $sceneReferenceBadge = '{0}/{1}' -f $chkTabLog.Text, (Get-BadgeText)
    Start-ThemeHarness -Warns 1
    $sceneTrip = Invoke-T8RoundTrip -DarkPreProbe { [string][bool]$script:logBadgeStartAfterimage } -DarkAction { Reset-LogTabBadge } -DarkProbe { '{0}/{1}' -f $chkTabLog.Text, (Get-BadgeText) }
    Assert-Case 'T8 f5 f1(표시 참) → 다크 중 배지 지움 - 표시 거짓 · 배지 없음 · 다크 Text / 라이트로 오면 66,50,22 · 표시 거짓' ('{0} → {1} → {2}' -f $sceneTrip.Pre, $sceneTrip.Dark, $sceneReferenceBadge) 'True → 로그/44,44,48/232,230,227/False → 로그/255,253,247/66,50,22/False'
    Assert-RoundTrip -Name 'T8 f5 다크 중 배지 지움' -Reference $sceneReference -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'f6' -Scene {
    # 교차(실행): 잔상 다크 글자 = 같은 배지 수로 실제 배지 함수가 칠한 글자 - 두 함수의 값 · 우선순위가 어긋나면 여기서 갈림 (H11 의 유일한 예외)
    foreach ($badgeCase in @(@(1, 0, '오류만'), @(0, 1, '경고만'), @(1, 1, '둘 다'))) {
      Start-ThemeHarness -Errors $badgeCase[0] -Warns $badgeCase[1]
      Invoke-ThemeToggleClick
      $afterimageFlag = [bool]$script:logBadgeStartAfterimage
      $afterimageColor = Get-RgbText $chkTabLog.ForeColor
      Update-LogTabBadge
      $badgeColor = Get-RgbText $chkTabLog.ForeColor
      Assert-Case ("T8 f6 교차({0}) - 다크 잔상 글자 = 같은 배지 수의 Update-LogTabBadge 글자" -f $badgeCase[2]) ('{0}/{1}/{2}' -f $script:uiTheme, $afterimageFlag, ($afterimageColor -ceq $badgeColor)) 'dark/True/True'
      "INFO T8 f6 {0}: 잔상 {1} · 배지 {2}" -f $badgeCase[2], $afterimageColor, $badgeColor
    }
  }
  Invoke-T8Scene -Name 'g' -Scene {
    Start-ThemeHarness
    $sceneBefore = Get-HarnessState
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { '{0}|{1}' -f (Get-RgbText $lvCrList.BackColor), ((@($lvCrList.Items) | ForEach-Object { Get-RgbText $_.BackColor }) -join ',') }
    Assert-Case 'T8 g1 실행 전 기본 행 - 다크 표 바탕 23,23,26 · 행 23,23,26' $sceneTrip.Dark '23,23,26|23,23,26,23,23,26,23,23,26'
    Assert-RoundTrip -Name 'T8 g1 기본 행(명시 White 가 됨 - ARGB 같음)' -Reference $sceneBefore -Trip $sceneTrip
    Start-ThemeHarness
    Set-CustomListRandomView -Context @{ RandomOrder = $false; RegisteredTotal = 3; Index = 1; SectionName = 'customRepeat' }
    Restore-CustomListRegisteredView
    $sceneBefore = Get-HarnessState
    $sceneTrip = Invoke-T8RoundTrip
    Assert-RoundTrip -Name 'T8 g2 정지 뒤 흰 행' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'h' -Scene {
    Start-ThemeHarness
    $script:approvalPendingStart = $true
    $btnStart.Enabled = $false
    Set-StartButtonPending -Pending $true
    $sceneBefore = Get-HarnessState
    $sceneLight = '{0}/{1}/{2}' -f $btnStart.Text, (Get-RgbText $btnStart.BackColor), $btnStart.Enabled
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { '{0}/{1}/{2}' -f $btnStart.Text, (Get-RgbText $btnStart.BackColor), $btnStart.Enabled }
    Assert-Case "T8 h 승인 조회 중(V7 · D7) - 라이트 '시작 중…' · 226,205,160 · 잠김 / 다크 '시작 중…' · 회색 154,154,160 · 잠김" ('{0} → {1}' -f $sceneLight, $sceneTrip.Dark) '시작 중…/226,205,160/False → 시작 중…/154,154,160/False'
    Assert-RoundTrip -Name 'T8 h 승인 조회 중' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'i' -Scene {
    # 다크에서 누른 토글(11-13 내부 검토): 위 장면들은 다크로 간 뒤 토글을 누르지 않아, 다크 화면의 토글 글자는 늘 복원(Restore-ThemeState)이 칠한 값입니다 -
    # 스타일 함수가 눌린 글자를 팔레트 대신 라이트 값 91,62,6 으로 칠해도 통과했습니다. 그래서 다크에서 토글을 켜는 장면('설정' 을 끄고 켜고 · '로그' · '랜덤' 을 켬)과
    # 끄는 장면('설정' · '랜덤' 을 끔)을 두어, 스타일 함수 둘(Update-TabToggleStyle · Update-CustomRandomToggleStyle)이 다크 팔레트로 칠한 값을 그대로 봅니다.
    # 기준 = 같은 시작 상태에서 라이트로 같은 조작을 한 화면
    $toggleLightProbe = { (@($chkTabSettings, $chkTabLog, $chkCrRandom) | ForEach-Object { '{0}={1}/{2}' -f $_.Name, (Get-RgbText $_.ForeColor), (Get-RgbText $_.BackColor) }) -join ' ' }
    $toggleDarkProbe = { (@($chkTabSettings, $chkTabLog, $chkCrRandom) | ForEach-Object {
          '{0}={1}/{2}/{3}' -f $_.Name, (Get-RgbText $_.ForeColor), (Get-RgbText $_.FlatAppearance.CheckedBackColor), (Get-RgbText $_.BackColor) }) -join ' ' }
    foreach ($pressCase in @(
        @{ Label = '켬'; RandomOn = $false
          Operation = {
            $chkTabSettings.Checked = $false
            Update-TabToggleStyle
            $chkTabSettings.Checked = $true
            Update-TabToggleStyle
            $chkTabLog.Checked = $true
            Update-TabToggleStyle
            $chkCrRandom.Checked = $true
            Update-CustomRandomToggleStyle -Toggle $chkCrRandom
          }
          Light = 'chkTabSettings=91,62,6/244,213,141 chkTabLog=91,62,6/244,213,141 chkCrRandom=91,62,6/244,213,141'
          Dark = 'chkTabSettings=255,240,205/104,82,34/104,82,34 chkTabLog=255,240,205/104,82,34/104,82,34 chkCrRandom=255,240,205/104,82,34/104,82,34' },
        @{ Label = '끔'; RandomOn = $true
          Operation = {
            $chkTabSettings.Checked = $false
            Update-TabToggleStyle
            $chkCrRandom.Checked = $false
            Update-CustomRandomToggleStyle -Toggle $chkCrRandom
          }
          Light = 'chkTabSettings=66,50,22/255,253,247 chkTabLog=66,50,22/255,253,247 chkCrRandom=66,50,22/255,253,247'
          Dark = 'chkTabSettings=232,230,227/104,82,34/44,44,48 chkTabLog=232,230,227/104,82,34/44,44,48 chkCrRandom=232,230,227/104,82,34/44,44,48' })) {
      $pressRandomOn = [bool]$pressCase.RandomOn
      Start-ThemeHarness -SettingsOpen -RandomOn:$pressRandomOn
      & $pressCase.Operation
      $sceneReference = Get-HarnessState
      $sceneLight = & $toggleLightProbe
      Start-ThemeHarness -SettingsOpen -RandomOn:$pressRandomOn
      $sceneTrip = Invoke-T8RoundTrip -DarkAction $pressCase.Operation -DarkProbe $toggleDarkProbe
      Assert-Case ('T8 i 다크에서 토글을 {0}(설정 · 로그 · 랜덤 = 글자/바탕 → 다크 글자/눌린 바탕/바탕) - 켠 토글 TabOnText · TabOn, 끈 토글 Text · Control' -f $pressCase.Label) `
        ('{0} → {1}' -f $sceneLight, $sceneTrip.Dark) ('{0} → {1}' -f $pressCase.Light, $pressCase.Dark)
      Assert-RoundTrip -Name ('T8 i 다크에서 토글을 ' + $pressCase.Label) -Reference $sceneReference -Trip $sceneTrip
    }
  }
  Invoke-T8Scene -Name 'j' -Scene {
    # 랜덤 토글 넷의 의미가 서로 다를 때(11-13 내부 검토): 시작 갱신이 넷 모두 기본 글자색으로 덮어 두므로, 복원 상태가 한 토글의 의미를 다른 토글에서 읽어도
    # 위 장면들은 통과했습니다. 시작 갱신 '뒤'에 둘만 켜서 의미를 갈라 놓고 왕복합니다 - 두 조합이면 어느 두 토글이든 한 번은 서로 다른 의미가 됩니다
    foreach ($randomCase in @(
        @{ Label = 'Cr · Dcr 켬'; On = @('chkCrRandom', 'chkDcrRandom'); Dark = 'chkCrRandom=255,240,205 chkAcrRandom=232,230,227 chkDcrRandom=255,240,205 chkLcrRandom=232,230,227' },
        @{ Label = 'Cr · Acr 켬'; On = @('chkCrRandom', 'chkAcrRandom'); Dark = 'chkCrRandom=255,240,205 chkAcrRandom=255,240,205 chkDcrRandom=232,230,227 chkLcrRandom=232,230,227' })) {
      Start-ThemeHarness
      foreach ($randomToggle in @($chkCrRandom, $chkAcrRandom, $chkDcrRandom, $chkLcrRandom)) {
        if ($randomCase.On -contains $randomToggle.Name) {
          $randomToggle.Checked = $true
          Update-CustomRandomToggleStyle -Toggle $randomToggle
        }
      }
      $sceneBefore = Get-HarnessState
      $sceneTrip = Invoke-T8RoundTrip -DarkProbe { (@($chkCrRandom, $chkAcrRandom, $chkDcrRandom, $chkLcrRandom) | ForEach-Object { '{0}={1}' -f $_.Name, (Get-RgbText $_.ForeColor) }) -join ' ' }
      Assert-Case ('T8 j 랜덤 토글 넷({0}) - 다크 글자: 켠 토글만 TabOnText 255,240,205 · 끈 토글은 Text 232,230,227' -f $randomCase.Label) $sceneTrip.Dark $randomCase.Dark
      Assert-RoundTrip -Name ('T8 j 랜덤 토글 넷(' + $randomCase.Label + ')') -Reference $sceneBefore -Trip $sceneTrip
    }
  }
  # T8 k · l - 대분류 · 생활 갱신(11-13 리뷰 반영): 위 장면들은 Update-MainCategoryVisual · Update-LifeSliders 가 빈 스텁이던 때 만든 것이라, 두 함수가 칠하는
  # 색 · 글꼴 · 테두리 · Enabled 를 어느 행도 보지 않았습니다(비활성 대분류 바탕을 라이트 리터럴로 바꿔도 통과). 이제 하네스가 그 컨트롤을 만들고 공용 갱신이
  # 실함수를 불러 모든 장면의 스냅샷 · 그림에 들어오며, 여기서는 그 값을 다크 · 라이트 리터럴로 고정합니다(기대 조각 = Get-LifeExpect). 왕복 비교만으로는
  # '다크에서만 틀린 값'(다크인데 라이트 리터럴로 칠한 바탕 등)을 놓칩니다 - 라이트로 돌아오면 같은 값이 되기 때문입니다.
  # 두 함수는 서로 읽는 상태가 달라(대분류 = 활성 버튼 하나 / 생활 = 줄마다 쪽 · 고른 칸) 장면 둘이면 활성 · 비활성 · 고른 칸 · 그 밖 · 빈 칸 · 쪽 끝이 모두 나옵니다.
  # 다만 k · l 에 나오는 것은 상태이지 전이가 아닙니다(11-13 내부 검토) - 두 함수가 늘 일괄 적용 직후의 컨트롤 위에서 돌아, 강조를 일반 모양으로 되돌리는 쪽 대입
  # (비활성 · 그 밖 · 빈 칸 분기)이 있는지는 이 두 장면이 지키지 않습니다(일괄 적용이 같은 값을 먼저 칠함). 그 대입은 T8 n(다크에서 대분류 · 생활 쪽을 바꿈)이 봅니다
  Invoke-T8Scene -Name 'k' -Scene {
    # 대분류 = 전투 · 생활 첫 쪽(시작 기본값 - 고른 스킬 · 대상이 각 줄의 첫 칸): ◀ 둘은 잠기고 ▶ 둘은 풀려 있습니다
    Start-ThemeHarness
    $sceneBefore = Get-HarnessState
    $sceneLight = Get-LifeSceneText
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { Get-LifeSceneText }
    $sceneDarkExpect = Get-LifeExpect -Theme 'dark'
    Assert-Case 'T8 k 대분류(전투 활성) - 다크: 활성 = Honey 247,181,0 · HoneyInk 42,28,0 · 테두리 0 · 굵게 / 비활성 = Control 44,44,48 · Text 232,230,227 · Border 62,62,68 · 두께 1 · 보통' `
      $sceneTrip.Dark.Cat $sceneDarkExpect.Cat
    Assert-Case 'T8 k 생활 카드(첫 쪽) - 다크: 고른 칸 = 58,56,50 · Honey 테두리 2 · 굵게 / 그 밖 = Control 44,44,48 · Border 62,62,68 · 두께 1 · 보통 (글자색은 모두 Text 232,230,227)' `
      $sceneTrip.Dark.Cards $sceneDarkExpect.Cards
    Assert-Case 'T8 k 위치점 · 화살표(첫 쪽) - 다크: 점 글자색 Muted 154,154,160 · 첫 점이 지금 쪽 / ◀ 잠김 · ▶ 풀림(스킬 | 대상)' $sceneTrip.Dark.Paging $sceneDarkExpect.Paging
    Assert-Case 'T8 k 라이트(전환 전) - 대분류 ;; 생활 카드 ;; 위치점 · 화살표 = 라이트 팔레트 값(활성 247,181,0 · 66,45,0 / 고른 칸 250,240,218 / 점 158,138,104)' `
      (Format-LifeScene $sceneLight) (Format-LifeScene (Get-LifeExpect -Theme 'light'))
    # 스냅샷이 이 컨트롤들을 담는가: 폼 아래에 붙어 있어야 열거됩니다 - 붙이기가 빠지면 위 리터럴 행은 통과하고 왕복 · 되돌림 비교에서만 조용히 빠집니다.
    # 이름마다 줄이 있는지와, 카드 줄에 평면 모양(|BS=) · 로그 창 줄에 테두리 모양(|RB=)이 실려 있는지를 봅니다
    $snapshotLines = @($sceneBefore.Snapshot -split "`n")
    $snapshotNames = @($snapshotLines | ForEach-Object { ($_ -split '\|')[0] })
    $snapshotMissing = @(@('btnCatBattle', 'btnCatLife', 'btnCatEtc', 'lifeSkillCard0', 'lifeSkillCard1', 'lifeSkillCard2', 'lifeTargetCard0', 'lifeTargetCard1', 'lifeTargetCard2',
        'btnLifeSkillPrev', 'btnLifeSkillNext', 'btnLifeTargetPrev', 'btnLifeTargetNext', 'lblLifeSkillDots', 'lblLifeTargetDots', 'rbLifeGather', 'rbCustomRepeat', 'numCount',
        'cboDifficulty', 'logChild') | Where-Object { $snapshotNames -cnotcontains $_ })
    Assert-Case 'T8 k 스냅샷 범위 - 대분류 셋 · 생활 카드 여섯 · 화살표 넷 · 위치점 둘 · 라디오 둘 · 숫자 칸 · 콤보 · 로그 창의 줄이 있음(빠진 이름 없음) · 카드 줄에 평면 모양 · 로그 창 줄에 테두리 모양' `
      ('[{0}]/{1}/{2}' -f ($snapshotMissing -join ','), (@($snapshotLines | Where-Object { $_.StartsWith('lifeTargetCard0|') -and $_.Contains('|BC=') -and $_.Contains('|BS=') }).Count),
        (@($snapshotLines | Where-Object { $_.StartsWith('logChild|') -and $_.Contains('|RB=None') }).Count)) '[]/1/1'
    Assert-RoundTrip -Name 'T8 k 대분류 전투 · 생활 첫 쪽' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'l' -Scene {
    # 대분류 = 생활 · 생활 끝 쪽: 스킬 줄은 끝 쪽(3쪽째 - 고른 스킬은 첫 쪽에 있어 보이는 세 칸이 모두 '그 밖'), 대상 줄은 끝 쪽(4쪽째)의 첫 칸을 고름 + 빈 칸 둘.
    # ▶ 둘이 잠기고 ◀ 둘이 풀립니다. 빈 칸은 글자 없음 · 잠김과 함께 바탕 · 테두리도 리터럴로 봅니다(빈 칸 분기의 색 대입은 다른 분기와 따로 있음)
    Start-ThemeHarness -Category 'life' -SkillPage 2 -TargetIndex 9 -TargetPage 3
    $sceneBefore = Get-HarnessState
    $sceneLight = Get-LifeSceneText
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe { Get-LifeSceneText }
    $sceneDarkExpect = Get-LifeExpect -Theme 'dark' -Last
    Assert-Case 'T8 l 대분류(생활 활성) - 다크: 활성(생활) = Honey 247,181,0 · HoneyInk 42,28,0 · 테두리 0 · 굵게 / 비활성(전투 · 기타) = Control 44,44,48 · Text 232,230,227 · Border 62,62,68 · 두께 1 · 보통' `
      $sceneTrip.Dark.Cat $sceneDarkExpect.Cat
    Assert-Case 'T8 l 생활 카드(끝 쪽) - 다크: 스킬 줄 세 칸 모두 그 밖 / 대상 줄 = 고른 칸 58,56,50 · Honey 2 · 굵게 + 빈 칸 둘(글자 없음 · 잠김 · Control 44,44,48 · Border 62,62,68 · 두께 1)' `
      $sceneTrip.Dark.Cards $sceneDarkExpect.Cards
    Assert-Case 'T8 l 위치점 · 화살표(끝 쪽) - 다크: 점 글자색 Muted 154,154,160 · 끝 점이 지금 쪽 / ◀ 풀림 · ▶ 잠김(스킬 | 대상)' $sceneTrip.Dark.Paging $sceneDarkExpect.Paging
    Assert-Case 'T8 l 라이트(전환 전) - 대분류 ;; 생활 카드 ;; 위치점 · 화살표 = 라이트 팔레트 값(빈 칸 255,253,247 · 226,205,160 · 두께 1)' `
      (Format-LifeScene $sceneLight) (Format-LifeScene (Get-LifeExpect -Theme 'light' -Last))
    Assert-RoundTrip -Name 'T8 l 대분류 생활 · 생활 끝 쪽' -Reference $sceneBefore -Trip $sceneTrip
  }
  Invoke-T8Scene -Name 'm' -Scene {
    # 일괄 적용(Apply-HoneyTheme)의 RadioButton · NumericUpDown · ComboBox · RichTextBox 분기(11-13 리뷰 반영): 하네스에 이 네 형식이 없어(셀 편집 콤보와 로그 본문은
    # 폼 밖) 그 분기의 대입을 실행으로 보는 행이 없었고, G7 의 원문 일치만 지켰습니다. 대표 = '채집' · '커스텀 반복' 라디오 · 횟수 숫자 칸 · 난이도 콤보 · 로그 창(폼 자식).
    # 이 형식들은 값이 두 테마에서 대칭이라(라이트 → 다크 → 라이트면 같은 값) 왕복 비교가 아니라 아래 리터럴 두 행이 분기의 대입을 지킵니다.
    # 나머지 다섯 분기(Label · CheckBox · GroupBox · Panel · Button)도 같은 이유로 리터럴 두 행을 둡니다(11-13 내부 검토 반영): 하네스에 그 형식의 일반 컨트롤이 있었지만
    # 어느 행도 그 값을 읽지 않았습니다 - 상태줄 · 위치점(Label)은 뒤 단계가 덮은 값이고, 토글(CheckBox)은 라이트 값만 T8 a 가 읽고 다크 값은 복원이 덮으며, 묶음 · 패널은
    # 읽는 행이 없었습니다. 그래서 Panel 바탕을 Control 로, Label · CheckBox 글자색을 라이트 리터럴로, GroupBox 글자색 · 바탕을 다른 팔레트 값으로 바꾸거나 패널 안으로
    # 재귀하지 않게 해도 G7 의 원문 일치 1행만 실패했습니다. 대표 = 일괄 적용 뒤에 아무것도 덮지 않는 일반 Label 둘(폼 자식 · 묶음 안 패널 안 - 재귀 3단) · CheckBox ·
    # GroupBox · Panel · Button. 이로써 아홉 분기 모두 이 장면에 실행 리터럴이 있습니다
    Start-ThemeHarness
    $sceneBefore = Get-HarnessState
    $sceneLight = Get-FormKindText
    $sceneLightPlain = Get-PlainKindText
    # 숫자 칸 · 콤보 · 로그 창은 운영체제가 그리는 부분이 있어 그림이 환경을 탈 수 있습니다 - 같은 장면을 한 번 더 찍어 화소가 흔들리지 않는지부터 봅니다
    # (11-13 실측: 같은 장면 세 번 · 다크 두 번 · 왕복 뒤 모두 같음). 흔들리면 모든 장면의 '폼 화소 = 기준' 이 이유 없이 갈리므로 여기서 먼저 드러냅니다
    $sceneRepeatPixels = Get-FormPixelHash
    $sceneTrip = Invoke-T8RoundTrip -DarkPreProbe { Get-PlainKindText } -DarkProbe { Get-FormKindText }
    Assert-Case 'T8 m 형식 넷 - 다크: 라디오 글자 Text 232,230,227 · 숫자 칸/콤보 바탕 Input 23,23,26 · 글자 232,230,227 · 로그 창 바탕 LogBack 19,19,21 · 테두리 모양 None' $sceneTrip.Dark `
      'rbLifeGather=232,230,227 rbCustomRepeat=232,230,227 numCount=23,23,26/232,230,227 cboDifficulty=23,23,26/232,230,227 logChild=19,19,21/None'
    Assert-Case 'T8 m 형식 넷 - 라이트(전환 전): 라디오 글자 66,50,22 · 숫자 칸/콤보 바탕 255,255,255 · 글자 66,50,22 · 로그 창 바탕 40,34,24 · 테두리 모양 None' $sceneLight `
      'rbLifeGather=66,50,22 rbCustomRepeat=66,50,22 numCount=255,255,255/66,50,22 cboDifficulty=255,255,255/66,50,22 logChild=40,34,24/None'
    Assert-Case 'T8 m 일반 형식 다섯 - 다크: Label · CheckBox 글자 Text 232,230,227(묶음 안 패널 안 Label 도 - 재귀 3단) · GroupBox 글자 Title 242,179,61 / 바탕 Back 30,30,33 · Panel 바탕 Back 30,30,33 · Button 평면 / Control 44,44,48 / Text / Border 62,62,68 / 두께 1' $sceneTrip.Pre `
      'plainLabel=232,230,227 innerLabel=232,230,227 plainCheck=232,230,227 plainGroup=242,179,61/30,30,33 plainPanel=30,30,33 plainButton=Flat/44,44,48/232,230,227/62,62,68/1'
    Assert-Case 'T8 m 일반 형식 다섯 - 라이트(전환 전): Label · CheckBox 글자 66,50,22 · GroupBox 글자 191,128,7 / 바탕 253,248,238 · Panel 바탕 253,248,238 · Button 평면 / 255,253,247 / 66,50,22 / 226,205,160 / 두께 1' $sceneLightPlain `
      'plainLabel=66,50,22 innerLabel=66,50,22 plainCheck=66,50,22 plainGroup=191,128,7/253,248,238 plainPanel=253,248,238 plainButton=Flat/255,253,247/66,50,22/226,205,160/1'
    Assert-Case 'T8 m 그림 - 같은 장면을 두 번 찍은 폼 화소가 같음(네 형식이 붙은 채 그림이 흔들리지 않음)' ($sceneRepeatPixels -ceq $sceneBefore.Pixels) $true
    Assert-RoundTrip -Name 'T8 m 형식 넷' -Reference $sceneBefore -Trip $sceneTrip
    # 관측만(단언하지 않음): 이 그림(보이지 않는 폼의 DrawToBitmap)이 네 형식의 색을 담는지는 형식마다 다릅니다. 11-13 실측 - 켜진 라디오의 글자 · 숫자 칸의 바탕 ·
    # 로그 창의 테두리 모양은 화소에 나타나고, 목록형 콤보의 바탕과 로그 창의 바탕은 나타나지 않습니다(원인은 재지 않았음 - 닫힌 목록형 콤보는 운영체제 테마가 그리고
    # RichTextBox 는 이 그리기 경로에 본문을 그리지 않는다고 알려져 있음). 그래서 콤보 · 로그 창의 색은 그림이 아니라 위 리터럴 행과 스냅샷(속성 값)이 지킵니다.
    # 운영체제 테마에 따라 달라질 수 있어 값은 고정하지 않습니다
    $kindPixels = Get-FormPixelHash
    $kindSeen = foreach ($kindCase in @(
        @{ Label = '켜진 라디오 글자'; Change = { $rbLifeGather.ForeColor = [System.Drawing.Color]::FromArgb(1, 2, 3) } },
        @{ Label = '숫자 칸 바탕'; Change = { $numCount.BackColor = [System.Drawing.Color]::FromArgb(1, 2, 3) } },
        @{ Label = '콤보 바탕'; Change = { $cboDifficulty.BackColor = [System.Drawing.Color]::FromArgb(1, 2, 3) } },
        @{ Label = '로그 창 바탕'; Change = { $logChild.BackColor = [System.Drawing.Color]::FromArgb(1, 2, 3) } },
        @{ Label = '로그 창 테두리 모양'; Change = { $logChild.BorderStyle = 'Fixed3D' } })) {
      & $kindCase.Change
      $kindPixelsNow = Get-FormPixelHash
      '{0} {1}' -f $kindCase.Label, ($kindPixelsNow -cne $kindPixels)
      $kindPixels = $kindPixelsNow
    }
    'INFO T8 m 그림에 담기는가(값 하나를 바꾸면 폼 화소가 달라지는가): {0}' -f ((@($kindSeen)) -join ' · ')
  }
  Invoke-T8Scene -Name 'n' -Scene {
    # 다크에서 대분류 · 생활 쪽을 바꿈 - 강조를 일반 모양으로 되돌리는 대입(11-13 내부 검토 반영): k · l 은 대분류 · 쪽 · 고른 칸을 시작 갱신 앞에서 정하고 그 뒤 바꾸지 않아,
    # 두 함수가 늘 일괄 적용 직후에만 돌고 강조돼 있던 컨트롤이 일반 모양으로 바뀌어야 하는 일이 없습니다. 그래서 대분류의 비활성 분기와 생활 카드의 그 밖 · 빈 칸 분기에 있는
    # '일반 모양으로 되돌리는' 대입(바탕 · 글자색 · 테두리 색 · 두께 · 보통 글꼴 · 빈 글자) 14줄을 한꺼번에 지워도 모든 행이 통과했습니다 - 일괄 적용이 같은 값을 먼저 칠해 두기 때문입니다.
    # 제품에서는 대분류 버튼(Set-MainCategory)과 카드 클릭 · 쪽 넘기기가 일괄 적용 없이 두 함수를 바로 불러, 그 대입이 없으면 이전 활성 버튼 · 이전 고른 칸이 강조된 채
    # 남습니다(비활성 글자색이 빠지면 라이트는 66,45,0 과 66,50,22 라 거의 안 보이고, 다크에서만 42,28,0 글자가 44,44,48 바탕에 묻힘).
    # 장면: 전투 활성 · 스킬 첫 칸 · 대상 둘째 칸을 고른 채 시작 → 다크에서 l 의 상태(생활 활성 · 생활 끝 쪽)로 바꾸고 두 함수를 바로 부릅니다(일괄 적용 없음).
    # 전투 버튼 = 활성 → 비활성, 스킬 첫 칸 = 고른 칸 → 그 밖, 대상 둘째 칸 = 고른 칸 → 빈 칸이라, 되돌리는 대입이 있어야만 l 과 같은 값이 됩니다.
    # 기준 = 같은 시작 상태에서 라이트로 같은 조작을 한 화면. 지워도 여전히 통과하는 것은 대분류 비활성 분기의 테두리 색 한 줄뿐입니다(동치) - 활성 분기는 테두리 색을
    # 바꾸지 않고(두께만 0), 대분류 버튼의 테두리 색을 대입하는 곳은 일괄 적용과 그 줄 둘뿐인데 둘 다 같은 팔레트 값이라 그 줄이 없어도 값이 같습니다
    $lifeMoveOperation = {
      $script:mainCategory = 'life'
      Update-MainCategoryVisual
      $script:lifeSkillPage = 2
      $script:lifeTargetIndex = 9
      $script:lifeTargetPage = 3
      Update-LifeSliders
    }
    Start-ThemeHarness -TargetIndex 1
    & $lifeMoveOperation
    $sceneReference = Get-HarnessState
    $sceneLight = Get-LifeSceneText
    Start-ThemeHarness -TargetIndex 1
    $sceneTrip = Invoke-T8RoundTrip -DarkPreProbe { Get-LifeSceneText } -DarkAction $lifeMoveOperation -DarkProbe { Get-LifeSceneText }
    $sceneDarkExpect = Get-LifeExpect -Theme 'dark' -Last
    Assert-Case 'T8 n 바꾸기 전(다크) - 전투 활성 · 스킬 첫 칸 · 대상 둘째 칸이 강조돼 있음(되돌릴 것이 있음)' (Format-LifeScene $sceneTrip.Pre) (Format-LifeScene (Get-LifeExpect -Theme 'dark' -SecondTarget))
    Assert-Case 'T8 n 다크에서 대분류를 생활로 - 활성이던 전투 버튼이 비활성 모양으로(Control 44,44,48 · Text 232,230,227 · Border 62,62,68 · 두께 1 · 보통) · 생활 버튼이 활성' `
      $sceneTrip.Dark.Cat $sceneDarkExpect.Cat
    Assert-Case 'T8 n 다크에서 생활 끝 쪽으로 - 고른 칸이던 스킬 첫 칸 = 그 밖 · 대상 둘째 칸 = 빈 칸(글자 없음 · 잠김 · Control 44,44,48 · Border 62,62,68 · 두께 1 · 보통) / 대상 첫 칸이 고른 칸' `
      $sceneTrip.Dark.Cards $sceneDarkExpect.Cards
    Assert-Case 'T8 n 다크에서 생활 끝 쪽으로 - 위치점 끝 점이 지금 쪽 · ◀ 풀림 · ▶ 잠김(스킬 | 대상)' $sceneTrip.Dark.Paging $sceneDarkExpect.Paging
    Assert-Case 'T8 n 라이트에서 같은 조작(기준) - 대분류 ;; 생활 카드 ;; 위치점 · 화살표 = 라이트 값(l 과 같은 화면 - 전투 버튼 255,253,247 · 66,50,22 · 보통 / 빈 칸 255,253,247 · 226,205,160 · 두께 1)' `
      (Format-LifeScene $sceneLight) (Format-LifeScene (Get-LifeExpect -Theme 'light' -Last))
    Assert-RoundTrip -Name 'T8 n 다크에서 대분류 · 생활 쪽을 바꿈' -Reference $sceneReference -Trip $sceneTrip
  }

  # ── T13 고장 주입 (설계 1.2 H2 · K1 - T8 하네스 실함수, 단계 하나만 바꿔 끼움) ────────────────────────
  function Invoke-T13Fault {
    # 주입 지점의 공통 판단: 'dark' 면 다크 적용 중에만, 'always' 면 되돌림에서도 던집니다 (원인에 지금 테마를 붙여 두 원인을 가름)
    param([string]$Label)
    if (($script:t13When -eq 'always') -or ($script:uiTheme -eq 'dark')) {
      # 다크 적용 중 처음 던지는 순간의 대분류 · 생활 모양을 잡아 둡니다 - (g)(h) 가 '되돌릴 것이 실제로 있었는지'(그 순간 다크로 칠해져 있었는지)를 봅니다
      if (($script:uiTheme -eq 'dark') -and ($null -eq $script:t13LifeAtFault)) { $script:t13LifeAtFault = Get-LifeSceneText }
      throw ('주입 {0} {1}' -f $Label, $script:uiTheme)
    }
  }
  function Invoke-T13Injection {
    # 고장 주입 1행: 시작 상태(설정 토글 잔상 · 경고 배지 잔상 · 상태줄 Firebrick) → 라이트 → 다크(-Save) 1회를 Invoke-ThemeSwitch 로 직접 부릅니다
    # (클릭 처리기의 바깥 catch 가 새는 예외를 가리지 않게). 바꿔 끼운 함수는 이 함수 지역 - 동적 범위라 안에서 부르는 전환 · 갱신이 찾습니다.
    # -LifeLastPage 면 대분류 = 생활 · 생활 끝 쪽(T8 l 과 같은 상태)에서 시작합니다. 'LifeSliders' 단계는 공용 갱신 5번의 한가운데 -
    # 대분류 갱신이 다크로 칠한 뒤 · 생활 슬라이더가 칠하기 직전 - 에서 던집니다(11-13 리뷰 반영)
    param([string]$Step, [string]$When, [switch]$ThrowingLog, [switch]$LifeLastPage)
    function Save-UiThemeState { $script:t8SaveCount++ }
    function Update-ThemeIconStyle { }
    function Set-TitleBarTheme { param([bool]$Dark) }
    $script:t13When = $When
    $script:t13LifeAtFault = $null
    if ($Step -eq 'TabToggle') { function Update-TabToggleStyle { Invoke-T13Fault -Label '토글 스타일'; & $script:realBlocks['Update-TabToggleStyle'] } }
    if ($Step -eq 'List') { function Update-ListThemeColors { Invoke-T13Fault -Label '리스트'; & $script:realBlocks['Update-ListThemeColors'] } }
    if ($Step -eq 'Restore') { function Restore-ThemeState { param($State) Invoke-T13Fault -Label '복원'; & $script:realBlocks['Restore-ThemeState'] -State $State } }
    if ($Step -eq 'LifeSliders') { function Update-LifeSliders { Invoke-T13Fault -Label '생활 슬라이더'; & $script:realBlocks['Update-LifeSliders'] } }
    if ($LifeLastPage) { Start-ThemeHarness -SettingsOpen -Warns 1 -Category 'life' -SkillPage 2 -TargetIndex 9 -TargetPage 3 } else { Start-ThemeHarness -SettingsOpen -Warns 1 }
    $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
    if ($ThrowingLog) { function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message); throw '기록 주입 예외' } }
    $injectBefore = Get-HarnessState
    $script:logLines.Clear()
    $script:t8SaveCount = 0
    $injectThrown = ''
    try { Invoke-ThemeSwitch -From 'light' -To 'dark' -Save } catch { $injectThrown = $_.Exception.Message }
    $injectAfter = Get-HarnessState
    return @{ Before = $injectBefore; After = $injectAfter; Theme = $script:uiTheme; Lines = (@($script:logLines) -join ' / '); LineCount = $script:logLines.Count; Saves = $script:t8SaveCount; Thrown = $injectThrown
      LifeAtFault = $script:t13LifeAtFault; LifeAfter = (Get-LifeSceneText) }
  }
  try {
    foreach ($injectCase in @(@('TabToggle', '(a) 토글 스타일', '토글 스타일'), @('List', '(b) 리스트', '리스트'), @('Restore', '(c) 복원', '복원'))) {
      $injectRow = Invoke-T13Injection -Step $injectCase[0] -When 'dark'
      Assert-Case ("T13 {0} 다크에서만 던짐 → 라이트 · 되돌림 경고 1줄(주입 원인) · 저장 0 · 예외 0" -f $injectCase[1]) ('{0} | [{1}] | {2} | [{3}]' -f $injectRow.Theme, $injectRow.Lines, $injectRow.Saves, $injectRow.Thrown) `
        ('light | [[경고] 다크 화면을 적용하지 못해 되돌렸습니다: 주입 {0} dark] | 0 | []' -f $injectCase[2])
      Assert-Case ("T13 {0} - 스냅샷 = 전환 전(상태줄 표시 · 기록 · 토글 · 카드 · 배지 표시 · 폼)" -f $injectCase[1]) (Compare-HarnessSnapshot -Before $injectRow.Before.Snapshot -After $injectRow.After.Snapshot) '같음'
      Assert-Case ("T13 {0} - 폼 화소 = 전환 전" -f $injectCase[1]) ($injectRow.Before.Pixels -ceq $injectRow.After.Pixels) $true
    }
    $injectD = Invoke-T13Injection -Step 'List' -When 'always'
    Assert-Case 'T13 (d) 리스트 단계가 늘 던짐 → 두 원인 1줄 · 예외 0 · 저장 0' ('{0} | [{1}] | {2} | [{3}]' -f $injectD.Theme, $injectD.Lines, $injectD.Saves, $injectD.Thrown) `
      'light | [[경고] 화면 색을 되돌리지도 못했습니다: 주입 리스트 dark / 주입 리스트 light] | 0 | []'
    $injectE = Invoke-T13Injection -Step 'TabToggle' -When 'dark' -ThrowingLog
    Assert-Case "T13 (e) (a) + 기록 실패(K1 가) → 라이트 · 시도 1줄 = 되돌림 꼴 · 저장 0 · 예외 0 · 스냅샷 = 전환 전" ('{0} | {1} [{2}] | {3} | [{4}] | {5}' -f $injectE.Theme, $injectE.LineCount, $injectE.Lines, $injectE.Saves, $injectE.Thrown,
        (Compare-HarnessSnapshot -Before $injectE.Before.Snapshot -After $injectE.After.Snapshot)) 'light | 1 [[경고] 다크 화면을 적용하지 못해 되돌렸습니다: 주입 토글 스타일 dark] | 0 | [] | 같음'
    $injectF = Invoke-T13Injection -Step 'List' -When 'always' -ThrowingLog
    Assert-Case 'T13 (f) (d) + 기록 실패(K1 나) → 예외 0 · 저장 0 · 시도 1줄 · 스냅샷 · 테마 = (d) 의 결과' ('[{0}] | {1} | {2} | {3} | {4}' -f $injectF.Thrown, $injectF.Saves, $injectF.LineCount,
        (Compare-HarnessSnapshot -Before $injectD.After.Snapshot -After $injectF.After.Snapshot), ($injectF.Theme -ceq $injectD.Theme)) '[] | 0 | 1 | 같음 | True'
    # (g)(h) 대분류 · 생활 갱신의 되돌림(11-13 리뷰 반영): 위 (a)~(f) 도 이제 그 컨트롤을 스냅샷에 담지만 대분류 전투 · 첫 쪽뿐이라, 대분류 = 생활 · 생활 끝 쪽(빈 칸 포함)에서
    # 다크 적용 도중 던지는 두 행을 둡니다. (g) 는 두 갱신이 다크로 다 칠한 뒤(토글 스타일 단계), (h) 는 대분류만 다크로 칠하고 생활 슬라이더가 칠하기 직전입니다.
    # 되돌림이 두 갱신을 라이트로 다시 돌리지 않으면 꿀색 활성 버튼 · 고른 칸 · 흐린 위치점이 일괄 적용의 일반 모양으로 남습니다. 던지는 순간의 값으로
    # '되돌릴 것이 실제로 있었는지' 도 봅니다 - 적용이 그 컨트롤을 칠하지 않았다면 되돌림 비교는 아무것도 확인하지 않은 채 같음이 됩니다
    $lifeLastDark = Get-LifeExpect -Theme 'dark' -Last
    # (h) 의 던지는 순간 = 일괄 적용이 다크 일반 모양으로 덮고 대분류 갱신만 다크로 칠한 중간 상태입니다. 대분류 값만 맞대면(11-13 내부 검토 - 고치기 전) 주입 감싸개가
    # 생활 슬라이더를 먼저 돌리고 던지게 바뀌어 (g) 와 같은 '다 칠한 뒤' 주입이 돼도 네 행이 모두 통과했습니다. 그래서 생활 카드 · 위치점이 '아직 칠하기 전' 인 것도
    # 리터럴로 봅니다: 스킬 줄과 빈 칸은 일괄 적용의 일반 모양(= 그 밖 · 빈 칸 조각과 같은 값), 고른 대상 칸은 일반 모양(Control 44,44,48 · Border 62,62,68 · 두께 1)에
    # 굵은 글꼴만 남아 있고(일괄 적용은 글꼴을 만지지 않음), 위치점 글자색은 흐린 색 154,154,160 이 아니라 일괄 적용의 Label 값 232,230,227 입니다
    $lifeLastDarkMid = @{
      Cat    = $lifeLastDark.Cat
      Cards  = ('스킬 {0} | {0} | {0} || 대상 글자/True/44,44,48/232,230,227/62,62,68/1/True | {1} | {1}' -f $lifeExpectPieces.dark.Off, $lifeExpectPieces.dark.Blank)
      Paging = '점 ○  ○  ●/232,230,227 | ○  ○  ○  ●/232,230,227 · 화살표 True/False | True/False'
    }
    foreach ($lifeInjectCase in @(
        @{ Step = 'TabToggle'; Name = '(g) 생활 끝 쪽 · 토글 스타일'; Cause = '토글 스타일'; AtFaultName = '대분류 ;; 생활 카드 ;; 위치점 · 화살표가 모두 다크 값'; AtFaultExpect = (Format-LifeScene $lifeLastDark) },
        @{ Step = 'LifeSliders'; Name = '(h) 생활 끝 쪽 · 생활 슬라이더'; Cause = '생활 슬라이더'; AtFaultName = '대분류만 다크 값 · 생활 카드와 위치점은 아직 일괄 적용의 일반 모양(생활 슬라이더가 칠하기 전)'; AtFaultExpect = (Format-LifeScene $lifeLastDarkMid) })) {
      $injectRow = Invoke-T13Injection -Step $lifeInjectCase.Step -When 'dark' -LifeLastPage
      Assert-Case ('T13 {0} 단계가 다크에서만 던짐 → 라이트 · 되돌림 경고 1줄(주입 원인) · 저장 0 · 예외 0' -f $lifeInjectCase.Name) ('{0} | [{1}] | {2} | [{3}]' -f $injectRow.Theme, $injectRow.Lines, $injectRow.Saves, $injectRow.Thrown) `
        ('light | [[경고] 다크 화면을 적용하지 못해 되돌렸습니다: 주입 {0} dark] | 0 | []' -f $lifeInjectCase.Cause)
      $lifeAtFaultText = $(if ($null -eq $injectRow.LifeAtFault) { '던지지 않음' } else { Format-LifeScene $injectRow.LifeAtFault })
      Assert-Case ('T13 {0} - 던지는 순간: {1}(되돌릴 것이 있었음)' -f $lifeInjectCase.Name, $lifeInjectCase.AtFaultName) $lifeAtFaultText $lifeInjectCase.AtFaultExpect
      Assert-Case ('T13 {0} - 스냅샷 = 전환 전 · 폼 화소 = 전환 전' -f $lifeInjectCase.Name) ('{0}/{1}' -f (Compare-HarnessSnapshot -Before $injectRow.Before.Snapshot -After $injectRow.After.Snapshot),
          ($injectRow.Before.Pixels -ceq $injectRow.After.Pixels)) '같음/True'
      Assert-Case ('T13 {0} - 되돌린 뒤 대분류 ;; 생활 카드 ;; 위치점 · 화살표 = 라이트 값(생활 활성 · 끝 쪽)' -f $lifeInjectCase.Name) (Format-LifeScene $injectRow.LifeAfter) `
        (Format-LifeScene (Get-LifeExpect -Theme 'light' -Last))
    }
  } catch { Assert-SectionError -Section 'T13' -ErrorRecord $_ }

  # ── T16 하네스 행: 라이트 → 다크(실함수 Set-TitleBarTheme · 반환 ≠ 0 · -Save) ──────────────────────────
  function Invoke-T16Harness {
    # 제목줄 실패는 전환 성공으로 칩니다(되돌리지 않음) - 경고 1줄만 남고 저장은 그대로 됩니다
    function Save-UiThemeState { $script:t8SaveCount++ }
    function Update-ThemeIconStyle { }
    function Invoke-DwmTitleBarAttribute { param([IntPtr]$Handle, [int]$Value) return -2147024809 }
    Start-ThemeHarness
    $script:logLines.Clear()
    $script:t8SaveCount = 0
    $harnessThrown = ''
    try { Invoke-ThemeSwitch -From 'light' -To 'dark' -Save } catch { $harnessThrown = $_.Exception.Message }
    $revertLines = @($script:logLines | Where-Object { $_ -match '되돌' }).Count
    $titleLines = @($script:logLines | Where-Object { $_ -ceq '[경고] 제목줄 색을 바꾸지 못했습니다 (0x80070057)' }).Count
    return ('{0} | 되돌림 경고 {1} · 제목줄 경고 {2} · 전체 {3} | 저장 {4} | 예외 [{5}]' -f $script:uiTheme, $revertLines, $titleLines, $script:logLines.Count, $script:t8SaveCount, $harnessThrown)
  }
  try {
    Assert-Case 'T16 하네스 라이트 → 다크(제목줄 반환 ≠ 0 · -Save) → 다크 · 되돌림 경고 0 · 제목줄 경고 1 · 저장 1' (Invoke-T16Harness) 'dark | 되돌림 경고 0 · 제목줄 경고 1 · 전체 1 | 저장 1 | 예외 []'
  } catch { Assert-SectionError -Section 'T16 하네스' -ErrorRecord $_ }

  # ── T14 시작 smoke (설계 H4 · V4 · K5 · K6 - 최상위 생성 대입문을 그대로 실행) ──────────────────────────
  function Invoke-T14Click {
    # 아이콘 클릭 1회 - 헤드리스 폼은 CanSelect 가 거짓이라 PerformClick 이 무시되므로 OnClick 을 리플렉션으로 부릅니다(11-12 실측: PerformClick 0회).
    # 클릭 처리기는 이 함수 지역의 셈 스텁을 찾습니다
    function Invoke-ThemeToggleClick { $script:t14ClickCount++ }
    $clickMethod = [System.Windows.Forms.Button].GetMethod('OnClick', [System.Reflection.BindingFlags]'NonPublic, Instance')
    [void]$clickMethod.Invoke($btnThemeToggle, @([System.EventArgs]::Empty))
  }
  function Get-IconColorCount {
    # 28x28 로 찍어 기대 색과 가까운(|dR|+|dG|+|dB| ≤ 10) 화소를 셉니다 - 테두리 2px 안쪽만(테두리 색이 섞여 '아무것도 안 그림' 을 놓치지 않게)
    param($Control, [int[]]$Expect)
    $iconBitmap = New-Object System.Drawing.Bitmap(28, 28)
    try {
      $Control.DrawToBitmap($iconBitmap, (New-Object System.Drawing.Rectangle(0, 0, 28, 28)))
      $nearCount = 0
      for ($pixelY = 2; $pixelY -lt 26; $pixelY++) {
        for ($pixelX = 2; $pixelX -lt 26; $pixelX++) {
          $pixel = $iconBitmap.GetPixel($pixelX, $pixelY)
          if (([Math]::Abs($pixel.R - $Expect[0]) + [Math]::Abs($pixel.G - $Expect[1]) + [Math]::Abs($pixel.B - $Expect[2])) -le 10) { $nearCount++ }
        }
      }
      return $nearCount
    } finally { $iconBitmap.Dispose() }
  }
  function Get-IconShapeText {
    # 해/달 모양 가르기(11-13 리뷰 지적 - 위 화소 수만으로는 Paint 가 Shape 를 무시하거나 두 갈래를 맞바꿔 그려도 4경우가 모두 통과합니다).
    # 11-13 실측 지도(제품 Paint · 28x28 · 기대 색 화소): 해 = 가운데 원 x 11~17 · y 11~17 + 축 광선 끝 (22·23, 14) (5·6, 14) (14, 5·6) (14, 22·23),
    # 달 = 왼쪽 아래 초승달 x 8~18 · y 9~20 뿐이라 가운데의 오른쪽 위(깎는 원 안)와 광선 끝이 비어 있습니다. 그래서 가운데 9칸(x 14~16 · y 12~14)과
    # 광선 끝 8칸의 기대 색 수로 가릅니다: 해 = 가운데 ≥ 5 · 광선 ≥ 4 / 달 = 둘 다 0 (실측 해 9 · 8, 달 0 · 0). 광선 펜을 1.75 로 줄여도(펜 굵기는
    # 사용자 확인 대기) 축 광선의 가운데 줄은 다 덮여 그대로 셉니다
    param($Control, [int[]]$Expect)
    $shapeBitmap = New-Object System.Drawing.Bitmap(28, 28)
    try {
      $Control.DrawToBitmap($shapeBitmap, (New-Object System.Drawing.Rectangle(0, 0, 28, 28)))
      $centerCount = 0
      for ($pixelY = 12; $pixelY -le 14; $pixelY++) {
        for ($pixelX = 14; $pixelX -le 16; $pixelX++) {
          $pixel = $shapeBitmap.GetPixel($pixelX, $pixelY)
          if (([Math]::Abs($pixel.R - $Expect[0]) + [Math]::Abs($pixel.G - $Expect[1]) + [Math]::Abs($pixel.B - $Expect[2])) -le 10) { $centerCount++ }
        }
      }
      $rayCount = 0
      foreach ($rayPoint in @(@(22, 14), @(23, 14), @(5, 14), @(6, 14), @(14, 5), @(14, 6), @(14, 22), @(14, 23))) {
        $pixel = $shapeBitmap.GetPixel($rayPoint[0], $rayPoint[1])
        if (([Math]::Abs($pixel.R - $Expect[0]) + [Math]::Abs($pixel.G - $Expect[1]) + [Math]::Abs($pixel.B - $Expect[2])) -le 10) { $rayCount++ }
      }
    } finally { $shapeBitmap.Dispose() }
    if (($centerCount -ge 5) -and ($rayCount -ge 4)) { return 'sun' }
    if (($centerCount -eq 0) -and ($rayCount -eq 0)) { return 'moon' }
    return ('모름(가운데 {0} · 광선 {1})' -f $centerCount, $rayCount)
  }
  function Invoke-T14PaintFault {
    # 해/달 그리기 본체에서 예외 1회 (모양 함수가 던짐) - 본체를 직접 부릅니다(DrawToBitmap 경로로 일으키면 처리기 밖으로 샌 예외가 프로세스를 끝냄 - 하네스 준비 ②).
    # 밖으로 새면 실사용에서는 모달 오류 창이라 본체가 받아야 합니다. -ThrowingLog 면 로그가 받은 줄을 남기고 던집니다(기록 실패도 밖으로 새면 안 됨)
    param($Sender, [switch]$ThrowingLog)
    function Get-ThemeIconSpec { param([string]$Theme, [bool]$Enabled) throw '아이콘 주입 예외' }
    if ($ThrowingLog) { function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message); throw '기록 주입 예외' } }
    $faultThrown = ''
    try { Invoke-ThemeIconPaint -Sender $Sender -PaintArgs $null } catch { $faultThrown = $_.Exception.Message }
    return $faultThrown
  }
  try {
    Reset-ThemeTestState
    Set-HoneyPalette -Theme 'light'
    New-ThemeHarness -WithFooter
    $t14Statements = @($topStatements | Where-Object { ($_ -is $assignType) -and ($_.Left.Extent.Text -ceq '$btnThemeToggle') })
    Assert-Case 'T14 최상위 아이콘 생성 대입문 정확히 1개' $t14Statements.Count 1
    if ($t14Statements.Count -eq 1) {
      $btnThemeToggle = $null
      . ([scriptblock]::Create($t14Statements[0].Extent.Text))
      $t14Width = [System.Windows.Forms.TextRenderer]::MeasureText($lblVersion.Text, $lblVersion.Font).Width
      Assert-Case 'T14 생성 - Button 1개 · 이름 btnThemeToggle(K6) · 맨 앞 · 28x28 · Top 806 · 앵커 아래/오른쪽 · 글자 없음' ('{0}/{1}/{2}/{3}x{4}/{5}/{6}/[{7}]' -f ($btnThemeToggle -is [System.Windows.Forms.Button]),
          $btnThemeToggle.Name, $form.Controls.GetChildIndex($btnThemeToggle), $btnThemeToggle.Width, $btnThemeToggle.Height, $btnThemeToggle.Top, $btnThemeToggle.Anchor, $btnThemeToggle.Text) `
        'True/btnThemeToggle/0/28x28/806/Bottom, Right/[]'
      Assert-Case 'T14 생성 - Left = 버전 글자 Right - MeasureText 폭 - 30' ($btnThemeToggle.Left -eq ($lblVersion.Right - $t14Width - 30)) $true
      "INFO T14 버전 글자 폭 {0} → 아이콘 Left {1} (설계 100% 실측 456)" -f $t14Width, $btnThemeToggle.Left
      $script:t14ClickCount = 0
      $t14ClickThrown = ''
      try { Invoke-T14Click } catch { $t14ClickThrown = $_.Exception.Message }
      Assert-Case 'T14 클릭 - OnClick → 처리기(명명 함수) 1회 · 예외 0' ('{0}/[{1}]' -f $script:t14ClickCount, $t14ClickThrown) '1/[]'
      # 시작 모드 실행(K5): 실함수 단장을 시작 갱신이 직접 부름 - 단장 안 오타는 여기서 예외로 드러납니다(감싸지 않음)
      $t14StartThrown = ''
      try { Invoke-HoneyThemeRefresh } catch { $t14StartThrown = $_.Exception.Message }
      Assert-Case 'T14 시작 모드(인자 없음) 실함수 단장 - 예외 0' $t14StartThrown ''
      Assert-Case 'T14 라이트 단장 - 접근성 이름 · 말풍선 같은 문구 · 올림/누름 250,240,218 · 손 커서' ('{0}/{1}/{2}/{3}/{4}' -f $btnThemeToggle.AccessibleName, $toolTip.GetToolTip($btnThemeToggle),
          (Get-RgbText $btnThemeToggle.FlatAppearance.MouseOverBackColor), (Get-RgbText $btnThemeToggle.FlatAppearance.MouseDownBackColor), ($btnThemeToggle.Cursor -eq [System.Windows.Forms.Cursors]::Hand)) `
        '다크 모드로 바꾸기/다크 모드로 바꾸기/250,240,218/250,240,218/True'
      Set-HoneyPalette -Theme 'dark'
      Update-ThemeIconStyle
      Assert-Case 'T14 다크 단장 - 접근성 이름 · 말풍선 같은 문구 · 올림/누름 58,58,63' ('{0}/{1}/{2}/{3}' -f $btnThemeToggle.AccessibleName, $toolTip.GetToolTip($btnThemeToggle),
          (Get-RgbText $btnThemeToggle.FlatAppearance.MouseOverBackColor), (Get-RgbText $btnThemeToggle.FlatAppearance.MouseDownBackColor)) '라이트 모드로 바꾸기/라이트 모드로 바꾸기/58,58,63/58,58,63'
      # 그리기 4경우: ① OnPaint 를 직접 불러(관리 코드 경로 - 예외가 잡힘) 처리기 배선을 확인한 뒤에만 ② DrawToBitmap(네이티브 경로 - 처리기 예외면 프로세스가 끝남)
      $paintMethod = [System.Windows.Forms.Control].GetMethod('OnPaint', [System.Reflection.BindingFlags]'NonPublic, Instance')
      $t14Plain = New-Object System.Windows.Forms.Button
      $t14Plain.Size = New-Object System.Drawing.Size(28, 28)
      $t14Plain.FlatStyle = 'Flat'
      foreach ($paintCase in @(
          @{ Theme = 'light'; Enabled = $true; Expect = @(191, 128, 7); Shape = 'moon'; Label = '라이트 · 사용(달 · 섹션 제목색)' },
          @{ Theme = 'light'; Enabled = $false; Expect = @(158, 138, 104); Shape = 'moon'; Label = '라이트 · 잠김(달 · 흐린 글자색)' },
          @{ Theme = 'dark'; Enabled = $true; Expect = @(247, 181, 0); Shape = 'sun'; Label = '다크 · 사용(해 · 꿀색)' },
          @{ Theme = 'dark'; Enabled = $false; Expect = @(154, 154, 160); Shape = 'sun'; Label = '다크 · 잠김(해 · 흐린 글자색)' })) {
        Set-HoneyPalette -Theme $paintCase.Theme
        $btnThemeToggle.Enabled = $paintCase.Enabled
        Update-ThemeIconStyle
        $script:themeIconPaintError = $null
        $preflightError = ''
        $preflightBitmap = New-Object System.Drawing.Bitmap(28, 28)
        $preflightGraphics = [System.Drawing.Graphics]::FromImage($preflightBitmap)
        try {
          # ::new 로 만들어 object[] 에 직접 담습니다 - New-Object 결과는 PSObject 로 감싸져 리플렉션이 PaintEventArgs 로 받지 못합니다(11-12 실측)
          $paintInvokeArgs = New-Object object[] 1
          $paintInvokeArgs[0] = [System.Windows.Forms.PaintEventArgs]::new($preflightGraphics, [System.Drawing.Rectangle]::new(0, 0, 28, 28))
          [void]$paintMethod.Invoke($btnThemeToggle, $paintInvokeArgs)
        } catch {
          $preflightError = $(if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message })
        } finally {
          $preflightGraphics.Dispose()
          $preflightBitmap.Dispose()
        }
        Assert-Case ('T14 그리기 {0} - Paint 처리기 배선(OnPaint 직접) 예외 0' -f $paintCase.Label) $preflightError ''
        if ($preflightError -eq '') {
          $t14Plain.BackColor = $btnThemeToggle.BackColor
          $t14Plain.FlatAppearance.BorderColor = $btnThemeToggle.FlatAppearance.BorderColor
          $t14Plain.Enabled = $paintCase.Enabled
          $iconCount = Get-IconColorCount -Control $btnThemeToggle -Expect $paintCase.Expect
          $plainCount = Get-IconColorCount -Control $t14Plain -Expect $paintCase.Expect
          Assert-Case ('T14 그리기 {0} - DrawToBitmap 예외 0 · 그리기 원인 없음 · 기대 색 화소 ≥ 15 · 처리기 없는 같은 버튼 < 15' -f $paintCase.Label) ('[{0}]/{1}/{2}' -f [string]$script:themeIconPaintError, ($iconCount -ge 15), ($plainCount -lt 15)) '[]/True/True'
          "INFO T14 그리기 {0}: 기대 색 화소 {1} (처리기 없는 버튼 {2})" -f $paintCase.Label, $iconCount, $plainCount
          Assert-Case ('T14 그리기 {0} - 모양 = {1} (가운데 9칸 · 광선 끝 8칸의 기대 색 화소)' -f $paintCase.Label, $paintCase.Shape) (Get-IconShapeText -Control $btnThemeToggle -Expect $paintCase.Expect) $paintCase.Shape
        }
      }
      $t14Plain.Dispose()
      # 그리기 첫 예외 계약(11-13 내부 검토): 위 4경우는 예외가 없는 길만 지나, '첫 1회만 [경고] · 원인 보관' 을 깨도(매번 기록 · 원인 대입 누락) 통과했습니다.
      # Paint 는 창이 다시 그려질 때마다 불리므로 매번 기록하면 로그가 넘칩니다. 본체를 직접 2회 부릅니다(DrawToBitmap 은 쓰지 않음)
      $script:themeIconPaintError = $null
      $script:logLines.Clear()
      $t14FaultFirst = Invoke-T14PaintFault -Sender $btnThemeToggle
      $t14AfterFirst = '{0}|{1}|{2}' -f $t14FaultFirst, $script:logLines.Count, ([string]$script:themeIconPaintError)
      $t14FaultSecond = Invoke-T14PaintFault -Sender $btnThemeToggle
      Assert-Case 'T14 그리기 예외(모양 함수가 던짐) - 밖으로 0 · 첫 예외 [경고] 1줄 · 원인 보관 / 둘째 예외 로그 0줄' ('{0} / [{1}] {2}' -f $t14AfterFirst, $t14FaultSecond, $script:logLines.Count) '|1|아이콘 주입 예외 / [] 1'
      Assert-Case 'T14 그리기 첫 예외 [경고] 줄 - 원인 포함' (($script:logLines.Count -ge 1) -and $script:logLines[0].StartsWith('[경고]') -and $script:logLines[0].Contains('아이콘 주입 예외')) $true
      $script:themeIconPaintError = $null
      $script:logLines.Clear()
      $t14FaultLog = Invoke-T14PaintFault -Sender $btnThemeToggle -ThrowingLog
      Assert-Case 'T14 그리기 예외 + 로그 기록도 던짐 → 예외 0(시도 1줄) · 원인 보관' ('[{0}]/{1}/{2}' -f $t14FaultLog, $script:logLines.Count, ([string]$script:themeIconPaintError)) '[]/1/아이콘 주입 예외'
      $script:themeIconPaintError = $null
    }
  } catch { Assert-SectionError -Section 'T14' -ErrorRecord $_ }

  # ── T17 하네스 행: 잠긴 평면 버튼 여섯의 실제 그림 · 다시 그리기 (소스의 생성 문장 · 속성 대입문 · 목록 대입문 · 등록 문장을 그대로 실행) ────────────
  function Get-PixelCenter {
    # 화소 번호들(줄 × 폭 + 칸)을 감싼 사각형의 가운데 - hashtable 1개(가로 X · 세로 Y). 화소가 없으면 $null
    param($Indexes, [int]$Width)
    if ($Indexes.Count -eq 0) { return $null }
    $columnRange = @($Indexes | ForEach-Object { $_ % $Width }) | Measure-Object -Minimum -Maximum
    $rowRange = @($Indexes | ForEach-Object { [Math]::Floor($_ / $Width) }) | Measure-Object -Minimum -Maximum
    return @{ X = (($columnRange.Minimum + $columnRange.Maximum) / 2.0); Y = (($rowRange.Minimum + $rowRange.Maximum) / 2.0) }
  }
  function Get-ControlPicture {
    # 컨트롤 하나를 DrawToBitmap 으로 찍어 화소 해시(같은 그림인지)와 세 색의 화소 수(정확히 그 색)를 돌려줍니다: 흐린 글자색 154,154,160(덧그린 글자) ·
    # 기본 글자색 232,230,227(잠기지 않은 글자) · 14,14,16(잠긴 평면 버튼이 스스로 그린 글자 = 바탕 44,44,48 을 어둡게 만든 색). 글자 가장자리의 번진 화소는
    # 이 세 색이 아니라 세지 않습니다(11-13 실측: '랜덤' 38 · '◀' 28 · '▶' 24 화소가 정확히 흐린 글자색). 흐린 글자색 · 14,14,16 화소는 그 덩어리의
    # 가운데도 돌려줍니다(덧그린 글자가 스스로 그린 글자와 같은 자리인지 맞대는 데 씀)
    param($Control)
    $pictureBitmap = New-Object System.Drawing.Bitmap($Control.Width, $Control.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $pictureArea = New-Object System.Drawing.Rectangle(0, 0, $Control.Width, $Control.Height)
      $Control.DrawToBitmap($pictureBitmap, $pictureArea)
      $pictureData = $pictureBitmap.LockBits($pictureArea, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
      try {
        $pictureBytes = New-Object byte[] ($pictureData.Stride * $pictureData.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($pictureData.Scan0, $pictureBytes, 0, $pictureBytes.Length)
      } finally { $pictureBitmap.UnlockBits($pictureData) }
    } finally { $pictureBitmap.Dispose() }
    $mutedPixels = New-Object System.Collections.Generic.List[int]
    $buriedPixels = New-Object System.Collections.Generic.List[int]
    $textCount = 0
    # 화소 하나 = 파랑 · 초록 · 빨강 · 알파 4바이트 (화소 번호 = 바이트 위치 / 4)
    for ($byteIndex = 0; $byteIndex -lt $pictureBytes.Length; $byteIndex += 4) {
      $pixelBlue = $pictureBytes[$byteIndex]
      $pixelGreen = $pictureBytes[$byteIndex + 1]
      $pixelRed = $pictureBytes[$byteIndex + 2]
      if (($pixelRed -eq 154) -and ($pixelGreen -eq 154) -and ($pixelBlue -eq 160)) { $mutedPixels.Add($byteIndex -shr 2) }
      elseif (($pixelRed -eq 232) -and ($pixelGreen -eq 230) -and ($pixelBlue -eq 227)) { $textCount++ }
      elseif (($pixelRed -eq 14) -and ($pixelGreen -eq 14) -and ($pixelBlue -eq 16)) { $buriedPixels.Add($byteIndex -shr 2) }
    }
    $pictureHasher = [System.Security.Cryptography.SHA256]::Create()
    try { $pictureHash = ([BitConverter]::ToString($pictureHasher.ComputeHash($pictureBytes)) -replace '-', '') } finally { $pictureHasher.Dispose() }
    return @{ Hash = $pictureHash; Muted = $mutedPixels.Count; Text = $textCount; Buried = $buriedPixels.Count
      MutedCenter = (Get-PixelCenter -Indexes $mutedPixels -Width $Control.Width); BuriedCenter = (Get-PixelCenter -Indexes $buriedPixels -Width $Control.Width) }
  }
  function Set-T17Scene {
    # 한 장면 = 팔레트 · 실행 상태 · 잠금. 색은 제품이 이 컨트롤들을 칠하는 길 그대로입니다: 화살표 = 테마 일괄 적용의 Button 분기, '랜덤' 토글 = 랜덤 토글 스타일
    param($Form, [object[]]$Controls, [string]$Theme, [bool]$Running, [bool]$Enabled)
    Set-HoneyPalette -Theme $Theme
    $script:running = $Running
    $Form.BackColor = $script:themeBack
    Apply-HoneyTheme -Root $Form
    foreach ($sceneControl in $Controls) {
      if ($sceneControl -is [System.Windows.Forms.CheckBox]) { Update-CustomRandomToggleStyle -Toggle $sceneControl }
      $sceneControl.Enabled = $Enabled
    }
  }
  function Invoke-T17Harness {
    # 여섯 컨트롤을 제품의 생성 문장 · 속성 대입문 그대로 이 함수의 지역 변수로 만들고, 소스의 목록 대입문 · 등록 문장도 이 함수 안에서 점소싱합니다 - 그 문장들이
    # 지역 변수 여섯을 읽어 script 범위 목록에 담고 Paint 처리기를 붙입니다(하네스의 같은 이름 토글은 건드리지 않음). 그림은 같은 컨트롤을 처리기를 붙이기 전 · 뒤에
    # 네 장면씩 찍어 맞댑니다. 이 행에서는 예외를 주입하지 않습니다 - DrawToBitmap 중 처리기 밖으로 샌 예외는 프로세스를 끝냅니다(하네스 준비 ②)
    $listStatements = @($script:topStatements | Where-Object { ($_ -is $script:assignType) -and ($_.Left.Extent.Text -ceq '$script:lockedTextControls') })
    $registerStatements = @($script:topStatements | Where-Object { ($_ -is [System.Management.Automation.Language.ForEachStatementAst]) -and ($_.Condition.Extent.Text -ceq '$script:lockedTextControls') })
    # 여섯 컨트롤의 최상위 생성 문장('$이름 = …')과 속성 대입문('$이름.속성 = …' - 글자 · 글자 배치 · 크기 · 평면 모양 등 소스에 있는 것 모두 · 그 순서)
    $t17Names = @('chkCrRandom', 'chkDcrRandom', 'btnLifeSkillPrev', 'btnLifeSkillNext', 'btnLifeTargetPrev', 'btnLifeTargetNext')
    $t17Creations = @{}
    $t17Properties = @{}
    foreach ($t17Name in $t17Names) {
      $t17Creations[$t17Name] = @($script:topStatements | Where-Object { ($_ -is $script:assignType) -and ($_.Left.Extent.Text -ceq ('$' + $t17Name)) })
      $t17Properties[$t17Name] = @($script:topStatements | Where-Object { ($_ -is $script:assignType) -and $_.Left.Extent.Text.StartsWith(('$' + $t17Name + '.'), [System.StringComparison]::Ordinal) })
    }
    $t17CreationMissing = @($t17Names | Where-Object { $t17Creations[$_].Count -ne 1 })
    Assert-Case 'T17 하네스 준비 - 최상위 목록 대입문 1 · 등록 foreach 문 1 · 여섯 컨트롤의 생성 문장 각 1' ('{0}/{1}/[{2}]' -f $listStatements.Count, $registerStatements.Count, ($t17CreationMissing -join ',')) '1/1/[]'
    if (($listStatements.Count -ne 1) -or ($registerStatements.Count -ne 1) -or ($t17CreationMissing.Count -gt 0)) { return }
    Reset-ThemeTestState
    Set-HoneyPalette -Theme 'light'
    $t17Form = New-Object System.Windows.Forms.Form
    $t17Form.Size = New-Object System.Drawing.Size(560, 881)
    $t17Form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    try {
      # 제품의 생성 문장과 속성 대입문을 소스 그대로 실행해 만듭니다(11-13 리뷰 지적: 손으로 만든 복제본이면 제품의 생성 대입 - 글자 배치 등 - 이 바뀌어도 아래 '자리' ·
      # 그림 행이 복제본의 자리만 보증합니다. T14 가 아이콘 생성 대입문을 그대로 실행하는 것과 같은 꼴). 대입문이 아닌 문장(부모에 붙이기 · 이벤트 등록 · 말풍선)은
      # 실행하지 않습니다. 하네스가 정하는 것은 넷뿐입니다: 이름(행의 이름표 - 제품은 이름을 주지 않음) · 자리(제품은 두 '랜덤' 을 같은 자리에 두고 화면에 따라 하나만 보임) ·
      # 보이기(제품은 숨긴 채 만들고 그 화면이 열릴 때 보임) · 폼에 붙이기. 색과 화살표의 평면 모양은 장면 도우미(Set-T17Scene)가 제품의 길 그대로 입힙니다
      $t17Controls = @()
      $t17Left = 15
      foreach ($t17Name in $t17Names) {
        # 이 함수의 지역 변수 $chkCrRandom 등이 생깁니다 - 아래에서 점소싱하는 목록 대입문이 이 이름으로 읽습니다
        . ([scriptblock]::Create($t17Creations[$t17Name][0].Extent.Text))
        foreach ($t17PropertyStatement in $t17Properties[$t17Name]) { . ([scriptblock]::Create($t17PropertyStatement.Extent.Text)) }
        $t17Control = Get-Variable -Name $t17Name -ValueOnly
        $t17Control.Name = $t17Name
        $t17Control.Location = New-Object System.Drawing.Point($t17Left, 20)
        $t17Control.Visible = $true
        $t17Form.Controls.Add($t17Control)
        $t17Left += $t17Control.Width + 10
        $t17Controls += $t17Control
      }
      Assert-Case 'T17 하네스 컨트롤 - 제품의 생성 문장 · 속성 대입문 그대로 만든 여섯에 글자가 있음(글자 없는 컨트롤 0)' ((@($t17Controls | Where-Object { [string]::IsNullOrEmpty($_.Text) } | ForEach-Object { $_.Name })) -join ',') ''
      'INFO T17 하네스 컨트롤(제품의 생성 문장 · 속성 대입문 그대로): {0}' -f ((@($t17Controls | ForEach-Object {
              '{0} {1} ''{2}'' {3}x{4} {5} · 속성 대입 {6}' -f $_.Name, $_.GetType().Name, $_.Text, $_.Width, $_.Height, $_.TextAlign, $t17Properties[$_.Name].Count })) -join ' / ')
      $t17Scenes = @(
        @{ Key = '다크 · 대기 · 잠김'; Theme = 'dark'; Running = $false; Enabled = $false },
        @{ Key = '라이트 · 대기 · 잠김'; Theme = 'light'; Running = $false; Enabled = $false },
        @{ Key = '다크 · 실행 중 · 잠김'; Theme = 'dark'; Running = $true; Enabled = $false },
        @{ Key = '다크 · 대기 · 잠기지 않음'; Theme = 'dark'; Running = $false; Enabled = $true })
      # ① 처리기를 붙이기 전의 그림 (기준 - 같은 컨트롤 · 같은 장면)
      $t17Plain = @{}
      foreach ($t17Scene in $t17Scenes) {
        Set-T17Scene -Form $t17Form -Controls $t17Controls -Theme $t17Scene.Theme -Running $t17Scene.Running -Enabled $t17Scene.Enabled
        foreach ($t17Control in $t17Controls) { $t17Plain[('{0}/{1}' -f $t17Scene.Key, $t17Control.Name)] = Get-ControlPicture -Control $t17Control }
      }
      # ② 소스의 목록 대입문 · 등록 문장 그대로 (지역 변수 여섯을 읽어 script 범위 목록에 담고, 그 목록을 돌며 Paint 처리기를 붙임)
      . ([scriptblock]::Create($listStatements[0].Extent.Text))
      . ([scriptblock]::Create($registerStatements[0].Extent.Text))
      Assert-Case 'T17 등록 - 목록 = 여섯 컨트롤(이름 · 순서)' ((@($script:lockedTextControls | ForEach-Object { $_.Name })) -join ',') 'chkCrRandom,chkDcrRandom,btnLifeSkillPrev,btnLifeSkillNext,btnLifeTargetPrev,btnLifeTargetNext'
      # ③ 처리기 배선 확인: OnPaint 를 직접 부릅니다(관리 코드 경로 - 처리기 밖으로 샌 예외가 잡힘). 통과한 뒤에만 DrawToBitmap(네이티브 경로 - 새면 프로세스가 끝남)
      Set-T17Scene -Form $t17Form -Controls $t17Controls -Theme 'dark' -Running $false -Enabled $false
      $paintMethod = [System.Windows.Forms.Control].GetMethod('OnPaint', [System.Reflection.BindingFlags]'NonPublic, Instance')
      $preflightErrors = @()
      foreach ($t17Control in $t17Controls) {
        $preflightBitmap = New-Object System.Drawing.Bitmap($t17Control.Width, $t17Control.Height)
        $preflightGraphics = [System.Drawing.Graphics]::FromImage($preflightBitmap)
        try {
          # ::new 로 만들어 object[] 에 직접 담습니다 - New-Object 결과는 PSObject 로 감싸져 리플렉션이 PaintEventArgs 로 받지 못합니다(T14 와 같은 꼴)
          $paintInvokeArgs = New-Object object[] 1
          $paintInvokeArgs[0] = [System.Windows.Forms.PaintEventArgs]::new($preflightGraphics, [System.Drawing.Rectangle]::new(0, 0, $t17Control.Width, $t17Control.Height))
          [void]$paintMethod.Invoke($t17Control, $paintInvokeArgs)
        } catch {
          $preflightErrors += ('{0}: {1}' -f $t17Control.Name, $(if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }))
        } finally {
          $preflightGraphics.Dispose()
          $preflightBitmap.Dispose()
        }
      }
      Assert-Case 'T17 그리기 - Paint 처리기 배선(OnPaint 직접 · 여섯 컨트롤) 예외 0' ($preflightErrors -join ' / ') ''
      if ($preflightErrors.Count -gt 0) { return }
      # ④ 처리기가 붙은 그림 네 장면 - 같은 컨트롤 · 같은 장면의 기준 그림과 맞댑니다
      $t17Facts = @{}
      foreach ($t17Scene in $t17Scenes) {
        Set-T17Scene -Form $t17Form -Controls $t17Controls -Theme $t17Scene.Theme -Running $t17Scene.Running -Enabled $t17Scene.Enabled
        $t17Facts[$t17Scene.Key] = @(foreach ($t17Control in $t17Controls) {
            $t17Before = $t17Plain[('{0}/{1}' -f $t17Scene.Key, $t17Control.Name)]
            $t17After = Get-ControlPicture -Control $t17Control
            # 덧그린 글자 덩어리(흐린 글자색)와 스스로 그린 글자 덩어리(처리기 전 그림의 14,14,16)의 가운데 차이 '가로/세로' - 어느 쪽이든 없으면 '없음'
            $t17Shift = '없음'
            $t17Placed = $false
            if (($null -ne $t17After.MutedCenter) -and ($null -ne $t17Before.BuriedCenter)) {
              $t17ShiftX = [Math]::Abs($t17After.MutedCenter.X - $t17Before.BuriedCenter.X)
              $t17ShiftY = [Math]::Abs($t17After.MutedCenter.Y - $t17Before.BuriedCenter.Y)
              $t17Shift = '{0}/{1}' -f $t17ShiftX, $t17ShiftY
              $t17Placed = (($t17ShiftX -le 3) -and ($t17ShiftY -le 3))
            }
            @{ Name = $t17Control.Name; Back = (Get-RgbText $t17Control.BackColor); Same = ($t17Before.Hash -ceq $t17After.Hash); PlainMuted = $t17Before.Muted
              Muted = $t17After.Muted; Text = $t17After.Text; Buried = $t17After.Buried; Shift = $t17Shift; Placed = $t17Placed }
          })
      }
      Assert-Case 'T17 다크 · 대기 · 잠김 - 바탕 44,44,48 · 처리기 전 흐린 글자색 화소 0 → 덧그린 뒤 154,154,160 화소 있음 · 기본 글자색 232,230,227 화소 0 (여섯 컨트롤)' `
        ((@($t17Facts['다크 · 대기 · 잠김'] | ForEach-Object { '{0}:{1}/{2}→{3}/{4}' -f $_.Name, $_.Back, $_.PlainMuted, ($_.Muted -gt 0), $_.Text })) -join ' ') `
        'chkCrRandom:44,44,48/0→True/0 chkDcrRandom:44,44,48/0→True/0 btnLifeSkillPrev:44,44,48/0→True/0 btnLifeSkillNext:44,44,48/0→True/0 btnLifeTargetPrev:44,44,48/0→True/0 btnLifeTargetNext:44,44,48/0→True/0'
      # 자리: 덧그리기는 컨트롤 안쪽 사각형의 가운데 한 줄이고 컨트롤은 제 글자를 제 배치로 그립니다 - 두 글자 덩어리의 가운데가 3화소 안에 있어야 같은 자리로 봅니다
      # (11-13 실측 차이: '랜덤' 가로 1 · '◀' 가로 0.5 · '▶' 가로 1 · 세로 1.5 / 덧그리기를 왼쪽 정렬로 바꾸면 '랜덤' 가로 32 · 화살표 3.5 · 4, 위 정렬이면
      #  '랜덤' 세로 7 · 화살표 20 · 21.5). 컨트롤은 제 글자를 GDI+ 로, 덧그리기는 GDI 로 그려 글자 모양 · 자리가 1화소쯤 다릅니다 - 그래서 화소 일치가 아니라 가운데 차이로 봅니다
      Assert-Case 'T17 다크 · 대기 · 잠김 - 덧그린 글자의 자리 = 스스로 그린 글자의 자리(두 글자 덩어리 가운데의 차이가 가로 · 세로 3화소 이내 - 여섯 컨트롤)' `
        ((@($t17Facts['다크 · 대기 · 잠김'] | ForEach-Object { '{0}:{1}' -f $_.Name, $_.Placed })) -join ' ') `
        'chkCrRandom:True chkDcrRandom:True btnLifeSkillPrev:True btnLifeSkillNext:True btnLifeTargetPrev:True btnLifeTargetNext:True'
      'INFO T17 다크 · 대기 · 잠김: {0}' -f ((@($t17Facts['다크 · 대기 · 잠김'] | ForEach-Object {
              '{0} 흐린 글자색 {1} · 덮이지 않은 원래 글자색(14,14,16) {2} · 자리 차이 가로/세로 {3}' -f $_.Name, $_.Muted, $_.Buried, $_.Shift })) -join ' / ')
      Assert-Case 'T17 라이트 · 대기 · 잠김 - 바탕 255,253,247 · 처리기 없는 같은 컨트롤의 그림과 화소가 같음(계약 L)' `
        ((@($t17Facts['라이트 · 대기 · 잠김'] | ForEach-Object { '{0}:{1}/{2}' -f $_.Name, $_.Back, $_.Same })) -join ' ') `
        'chkCrRandom:255,253,247/True chkDcrRandom:255,253,247/True btnLifeSkillPrev:255,253,247/True btnLifeSkillNext:255,253,247/True btnLifeTargetPrev:255,253,247/True btnLifeTargetNext:255,253,247/True'
      Assert-Case 'T17 다크 · 실행 중 · 잠김 - 처리기 없는 그림과 같음 · 스스로 그린 잠긴 글자(14,14,16) 그대로(사용자 결정 ④)' `
        ((@($t17Facts['다크 · 실행 중 · 잠김'] | ForEach-Object { '{0}:{1}/{2}' -f $_.Name, $_.Same, ($_.Buried -gt 0) })) -join ' ') `
        'chkCrRandom:True/True chkDcrRandom:True/True btnLifeSkillPrev:True/True btnLifeSkillNext:True/True btnLifeTargetPrev:True/True btnLifeTargetNext:True/True'
      Assert-Case 'T17 다크 · 대기 · 잠기지 않음 - 처리기 없는 그림과 같음 · 기본 글자색 232,230,227 글자 그대로' `
        ((@($t17Facts['다크 · 대기 · 잠기지 않음'] | ForEach-Object { '{0}:{1}/{2}' -f $_.Name, $_.Same, ($_.Text -gt 0) })) -join ' ') `
        'chkCrRandom:True/True chkDcrRandom:True/True btnLifeSkillPrev:True/True btnLifeSkillNext:True/True btnLifeTargetPrev:True/True btnLifeTargetNext:True/True'
      Assert-Case 'T17 그리기 - 덧그리기 예외 원인 없음 · 경고 0줄' ('[{0}]/{1}' -f [string]$script:lockedTextPaintError, $script:logLines.Count) '[]/0'
      # ⑤ 다시 그리기(Set-UiRunning 끝에서 부르는 함수): 대기 중에 이미 잠겨 있던 컨트롤은 실행이 시작돼도 Enabled 가 거짓 그대로라 스스로 다시 그리지 않습니다 -
      #    그래서 실행을 시작할 때도 멈출 때도 여섯 컨트롤을 모두 Invalidate 해야 합니다. 여섯을 잠근 채로 두고 실행 중 · 대기 두 상태에서 각 1회 부릅니다
      #    (11-13 리뷰 지적: 대기 상태에서만 1회 부르면 '실행 중이면 다시 그리지 않음' 변이가 통과합니다 - 그 변이는 [시작] 뒤에도 대기 중에 덧그린 흐린 글자가 남아
      #     사용자 결정 ④ 를 어깁니다). Invalidated 이벤트는 핸들이 있을 때만 나는데 위 그리기가 여섯 모두의 핸들을 만들었습니다. 목록에서 하나라도 빠지면 그 컨트롤이 0 으로 남습니다
      Set-T17Scene -Form $t17Form -Controls $t17Controls -Theme 'dark' -Running $false -Enabled $false
      $script:t17Invalidations = @{}
      foreach ($t17Control in $t17Controls) { $t17Control.Add_Invalidated({ $script:t17Invalidations[$this.Name] = 1 + [int]$script:t17Invalidations[$this.Name] }) }
      foreach ($t17RepaintCase in @(@{ Label = '실행 시작(잠긴 채 실행 중)'; Running = $true }, @{ Label = '정지(잠긴 채 대기)'; Running = $false })) {
        $script:running = $t17RepaintCase.Running
        $script:t17Invalidations.Clear()
        Update-LockedTextRepaint
        Assert-Case ('T17 다시 그리기 {0} - Update-LockedTextRepaint 1회에 여섯 컨트롤 Invalidate 각 1회 (핸들 없는 컨트롤 0)' -f $t17RepaintCase.Label) ('{0} | {1}' -f @($t17Controls | Where-Object { -not $_.IsHandleCreated }).Count,
            ((@($t17Controls | ForEach-Object { '{0}={1}' -f $_.Name, [int]$script:t17Invalidations[$_.Name] })) -join ' ')) `
          '0 | chkCrRandom=1 chkDcrRandom=1 btnLifeSkillPrev=1 btnLifeSkillNext=1 btnLifeTargetPrev=1 btnLifeTargetNext=1'
      }
    } finally {
      try { $t17Form.Dispose() } catch { }
      $script:lockedTextControls = $null
      $script:running = $false
      Set-HoneyPalette -Theme 'light'
    }
  }
  try { Invoke-T17Harness } catch { Assert-SectionError -Section 'T17 하네스' -ErrorRecord $_ }

  # ── T18 하네스 행: 다크 입력 칸 통일 - 여섯 칸의 실제 그림 · 끄면 원래대로 · 핸들 · 창 프로시저의 예외 경계 · 실제 전환 (설계 7.13 T18b · T18c · T18d · T18e · T18f) ─────
  # 그림은 컨트롤의 DrawToBitmap(그림 받기 길 - WM_PRINT → WM_PRINTCLIENT)으로 찍습니다. 화면에 실제로 그려지는 길(WM_PAINT)과 같은 길이 아니라, 여기서는
  # '화면 그리기 메시지를 직접 받았을 때 장치가 그 길을 타고 오류가 없는지' 까지만 보고 화소의 최종 판정은 실기에 둡니다(설계 7.13 - 설계 리뷰 반영).
  # 헤드리스 그림의 성질(11-14 이 PC 관측 - 제품과 무관): 보이지 않는 폼의 닫힌 목록 칸은 고른 항목의 글자를 그리지 않습니다(손대지 않은 칸의 그림에도 글자 화소 0).
  # 그래서 목록 칸의 '글자가 기본 글자색' 은 그림으로 볼 수 없고, ▼ 를 포함한 모든 화소가 '스스로 그린 그림을 그 장치의 색 대응으로 보낸 값' 인지(화소 분류 행)와
  # 그 색 대응이 잉크색을 기본 글자로 보내는지(T18d 색 대응 표)로 나눠 봅니다. 닫힌 목록 칸의 글자 화소는 실기 몫입니다
  function Get-T18Picture {
    # 컨트롤 하나를 DrawToBitmap 으로 찍은 화소 - hashtable 1개(폭 · 높이 · 바이트: 화소마다 파랑 · 초록 · 빨강 · 알파)
    param($Control)
    $pictureBitmap = New-Object System.Drawing.Bitmap($Control.Width, $Control.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $pictureArea = New-Object System.Drawing.Rectangle(0, 0, $Control.Width, $Control.Height)
      $Control.DrawToBitmap($pictureBitmap, $pictureArea)
      $pictureData = $pictureBitmap.LockBits($pictureArea, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
      try {
        $pictureBytes = New-Object byte[] ($pictureData.Stride * $pictureData.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($pictureData.Scan0, $pictureBytes, 0, $pictureBytes.Length)
      } finally { $pictureBitmap.UnlockBits($pictureData) }
    } finally { $pictureBitmap.Dispose() }
    return @{ Width = $Control.Width; Height = $Control.Height; Bytes = $pictureBytes }
  }
  function Compare-T18Picture {
    # 두 그림이 화소까지 같으면 '같음', 아니면 크기 차이 또는 다른 화소 수와 처음 다른 자리(가로,세로)
    param($Left, $Right)
    if (($Left.Width -ne $Right.Width) -or ($Left.Height -ne $Right.Height)) { return ('크기 다름({0}x{1} · {2}x{3})' -f $Left.Width, $Left.Height, $Right.Width, $Right.Height) }
    $leftBytes = $Left.Bytes
    $rightBytes = $Right.Bytes
    $differentCount = 0
    $firstDifferent = ''
    for ($byteIndex = 0; $byteIndex -lt $leftBytes.Length; $byteIndex += 4) {
      if (($leftBytes[$byteIndex] -ne $rightBytes[$byteIndex]) -or ($leftBytes[$byteIndex + 1] -ne $rightBytes[$byteIndex + 1]) -or ($leftBytes[$byteIndex + 2] -ne $rightBytes[$byteIndex + 2]) -or
        ($leftBytes[$byteIndex + 3] -ne $rightBytes[$byteIndex + 3])) {
        $differentCount++
        if ($firstDifferent -eq '') { $firstDifferent = '{0},{1}' -f (($byteIndex -shr 2) % $Left.Width), [Math]::Floor(($byteIndex -shr 2) / $Left.Width) }
      }
    }
    if ($differentCount -eq 0) { return '같음' }
    return ('{0}화소 다름(첫 {1})' -f $differentCount, $firstDifferent)
  }
  function Compare-T18PictureSet {
    # 두 그림 묶음(이름 → 그림)에서 서로 다른 그림의 이름과 차이 - 모두 같으면 ''
    param($Left, $Right)
    $setDifferences = foreach ($pictureName in @($Left.Keys | Sort-Object)) {
      $pictureDifference = Compare-T18Picture -Left $Left[$pictureName] -Right $Right[$pictureName]
      if ($pictureDifference -cne '같음') { '{0}: {1}' -f $pictureName, $pictureDifference }
    }
    return ((@($setDifferences)) -join ' / ')
  }
  function Get-T18ColorCount {
    # 그 색과 정확히 같은 화소 수
    param($Picture, $Color)
    $countBytes = $Picture.Bytes
    $colorCount = 0
    for ($byteIndex = 0; $byteIndex -lt $countBytes.Length; $byteIndex += 4) {
      if (($countBytes[$byteIndex + 2] -eq $Color.R) -and ($countBytes[$byteIndex + 1] -eq $Color.G) -and ($countBytes[$byteIndex] -eq $Color.B)) { $colorCount++ }
    }
    return $colorCount
  }
  function Get-T18PixelText {
    # 한 화소의 색 'R,G,B'
    param($Picture, [int]$X, [int]$Y)
    $pixelIndex = ($Y * $Picture.Width + $X) * 4
    return ('{0},{1},{2}' -f $Picture.Bytes[$pixelIndex + 2], $Picture.Bytes[$pixelIndex + 1], $Picture.Bytes[$pixelIndex])
  }
  function Get-T18PaperText {
    # 안쪽(가장자리 2화소 제외)에서 가장 많은 색 'R,G,B' - 그 칸의 바탕
    param($Picture)
    $paperBytes = $Picture.Bytes
    $paperCounts = @{}
    for ($pixelY = 2; $pixelY -lt ($Picture.Height - 2); $pixelY++) {
      for ($pixelX = 2; $pixelX -lt ($Picture.Width - 2); $pixelX++) {
        $pixelIndex = ($pixelY * $Picture.Width + $pixelX) * 4
        $paperKey = '{0},{1},{2}' -f $paperBytes[$pixelIndex + 2], $paperBytes[$pixelIndex + 1], $paperBytes[$pixelIndex]
        $paperCounts[$paperKey] = 1 + [int]$paperCounts[$paperKey]
      }
    }
    return [string](@($paperCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1)[0].Key)
  }
  function Convert-T18Picture {
    # 그림 전체를 색 대응으로 보낸 그림(같은 꼴의 hashtable) - 장치가 그릴 때와 같은 길(GDI+ DrawImage + ImageAttributes · Convert-T18Colors 의 그림 크기판)
    param($Picture, $Matrix)
    $convertArea = New-Object System.Drawing.Rectangle(0, 0, $Picture.Width, $Picture.Height)
    $convertSource = New-Object System.Drawing.Bitmap($Picture.Width, $Picture.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
    $convertResult = New-Object System.Drawing.Bitmap($Picture.Width, $Picture.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
    try {
      $sourceData = $convertSource.LockBits($convertArea, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
      try { [System.Runtime.InteropServices.Marshal]::Copy($Picture.Bytes, 0, $sourceData.Scan0, $Picture.Bytes.Length) } finally { $convertSource.UnlockBits($sourceData) }
      $convertGraphics = [System.Drawing.Graphics]::FromImage($convertResult)
      $convertAttributes = New-Object System.Drawing.Imaging.ImageAttributes
      try {
        $convertAttributes.SetColorMatrix($Matrix)
        $convertGraphics.DrawImage($convertSource, $convertArea, 0, 0, $Picture.Width, $Picture.Height, [System.Drawing.GraphicsUnit]::Pixel, $convertAttributes)
      } finally {
        $convertAttributes.Dispose()
        $convertGraphics.Dispose()
      }
      $resultData = $convertResult.LockBits($convertArea, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
      try {
        $convertBytes = New-Object byte[] ($resultData.Stride * $resultData.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($resultData.Scan0, $convertBytes, 0, $convertBytes.Length)
      } finally { $convertResult.UnlockBits($resultData) }
    } finally {
      $convertSource.Dispose()
      $convertResult.Dispose()
    }
    return @{ Width = $Picture.Width; Height = $Picture.Height; Bytes = $convertBytes }
  }
  function Get-T18PixelClasses {
    # 다시 칠한 그림(-Painted)의 화소를 넷으로 가른 수 - hashtable 1개:
    #   Border = 바깥 한 줄이 테두리색(-BorderText 'R,G,B' - '' 이면 테두리를 덧그리지 않는 칸이라 바깥 줄도 아래 셋으로 가름) ·
    #   Mapped = 스스로 그린 그림(-Plain)을 색 대응으로 보낸 그림(-Mapped)과 채널마다 1 이내 · Kept = 스스로 그린 그림 그대로(자식 창 자리 - 시간 칸의 ▲▼.
    #   이 그림은 그림 받기 길이라 장치는 칸 전체를 칠하고, 그 뒤에 자식 창이 제 그림을 덧찍어 남는 자리입니다 - 화면 길에서 장치가 그 자리를 빼는 것과는 다른 경로) ·
    #   Other = 어느 것도 아님(있으면 안 됨)
    param($Painted, $Plain, $Mapped, [string]$BorderText)
    $classCounts = @{ Border = 0; Mapped = 0; Kept = 0; Other = 0 }
    $paintedBytes = $Painted.Bytes
    $plainBytes = $Plain.Bytes
    $mappedBytes = $Mapped.Bytes
    $borderChannels = $(if ($BorderText -ne '') { @($BorderText -split ',' | ForEach-Object { [int]$_ }) } else { $null })
    $lastColumn = $Painted.Width - 1
    $lastRow = $Painted.Height - 1
    for ($pixelY = 0; $pixelY -le $lastRow; $pixelY++) {
      for ($pixelX = 0; $pixelX -le $lastColumn; $pixelX++) {
        $pixelIndex = ($pixelY * $Painted.Width + $pixelX) * 4
        $pixelBlue = $paintedBytes[$pixelIndex]
        $pixelGreen = $paintedBytes[$pixelIndex + 1]
        $pixelRed = $paintedBytes[$pixelIndex + 2]
        if ($borderChannels -and (($pixelX -eq 0) -or ($pixelY -eq 0) -or ($pixelX -eq $lastColumn) -or ($pixelY -eq $lastRow))) {
          if (($pixelRed -eq $borderChannels[0]) -and ($pixelGreen -eq $borderChannels[1]) -and ($pixelBlue -eq $borderChannels[2])) { $classCounts.Border++ } else { $classCounts.Other++ }
        } elseif (([Math]::Abs($pixelRed - $mappedBytes[$pixelIndex + 2]) -le 1) -and ([Math]::Abs($pixelGreen - $mappedBytes[$pixelIndex + 1]) -le 1) -and ([Math]::Abs($pixelBlue - $mappedBytes[$pixelIndex]) -le 1)) {
          $classCounts.Mapped++
        } elseif (($pixelRed -eq $plainBytes[$pixelIndex + 2]) -and ($pixelGreen -eq $plainBytes[$pixelIndex + 1]) -and ($pixelBlue -eq $plainBytes[$pixelIndex])) {
          $classCounts.Kept++
        } else {
          $classCounts.Other++
        }
      }
    }
    return $classCounts
  }
  $t18CellNames = @('pickerOn', 'pickerOff', 'comboOn', 'comboOff', 'numericOn', 'numericOff')
  function Get-T18CellPictures {
    # 여섯 칸의 그림(이름 → 그림). 숫자 칸은 장치가 붙는 안쪽 글자 칸도 따로 찍습니다(이름 + 'Edit' - 모두 여덟 장)
    $cellPictures = @{}
    foreach ($cellName in $script:t18CellNames) {
      $cellPictures[$cellName] = Get-T18Picture -Control $script:t18Cells[$cellName]
      if ($cellName -like 'numeric*') { $cellPictures[$cellName + 'Edit'] = Get-T18Picture -Control (Get-T18NumericEdit -Numeric $script:t18Cells[$cellName]) }
    }
    return $cellPictures
  }
  function Get-T18CountText {
    # 여섯 장치가 다시 칠한 횟수 '이름=화면 그리기(WM_PAINT)/그림 받기(WM_PRINTCLIENT)'
    param($Painters)
    return ((@($script:t18CellNames | ForEach-Object { '{0}={1}/{2}' -f $_, $Painters[$_].PaintCount, $Painters[$_].PrintCount })) -join ' ')
  }
  # 창 메시지 보내기 (화면 그리기 메시지를 컨트롤 창에 직접 보내는 데만 씀 - 화면에 창을 띄우지 않음)
  if (-not ('HoneyThemeTest.NativeMethods' -as [type])) {
    Add-Type -Namespace HoneyThemeTest -Name NativeMethods -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);'
  }
  $t18NativeType = 'HoneyThemeTest.NativeMethods' -as [type]
  function Send-T18Paint {
    # 컨트롤 창에 화면 그리기 메시지(WM_PAINT)를 직접 보냅니다 - 네이티브 경로라 위 직접 호출(Invoke-T18WndProc)이 통과한 뒤에만 부릅니다
    param($Painter)
    $nativeType = $script:t18NativeType
    [void]$nativeType::SendMessage($Painter.Target.Handle, 0x000F, [IntPtr]::Zero, [IntPtr]::Zero)
  }
  function Invoke-T18RecreateHandle {
    # 컨트롤의 창 핸들을 다시 만듭니다(RecreateHandle 은 보호 메서드라 리플렉션). 핸들이 바뀌었는지를 돌려줍니다
    param($Control)
    $handleBefore = $Control.Handle
    $recreateMethod = [System.Windows.Forms.Control].GetMethod('RecreateHandle', [System.Reflection.BindingFlags]'NonPublic, Instance')
    [void]$recreateMethod.Invoke($Control, $null)
    return ($handleBefore -ne $Control.Handle)
  }
  function Test-T18FrontWindow {
    # 그 컨트롤 창의 맨 앞 창 프로시저(가장 나중에 얹힌 것)가 그 장치인가 - 장치가 창에 실제로 얹혀 있는지를 장치의 말(IsAttached)이 아니라 창 쪽에서 봅니다
    param($Control, $Painter)
    return [object]::ReferenceEquals([System.Windows.Forms.NativeWindow]::FromHandle($Control.Handle), $Painter)
  }
  function Get-T18ControlProc {
    # 그 컨트롤 자신의 창 프로시저(컨트롤의 관리 창 window 필드의 windowProcPtr - 리플렉션). 관리 창은 핸들마다 창 프로시저 대리자를 새로 만들어
    # 핸들을 다시 만들면 이 값도 바뀝니다. 말풍선 같은 서브클래스가 없는 칸에서는 장치가 붙기 직전의 창 프로시저(ChainProc)가 이 값이어야 합니다.
    # 필드를 찾지 못하면 0 (단언이 실패로 알림)
    param($Control)
    $controlWindowField = [System.Windows.Forms.Control].GetField('window', [System.Reflection.BindingFlags]'NonPublic, Instance')
    $windowProcField = [System.Windows.Forms.NativeWindow].GetField('windowProcPtr', [System.Reflection.BindingFlags]'NonPublic, Instance')
    if (($null -eq $controlWindowField) -or ($null -eq $windowProcField)) { return [IntPtr]::Zero }
    $controlWindow = $controlWindowField.GetValue($Control)
    if ($null -eq $controlWindow) { return [IntPtr]::Zero }
    return [IntPtr]$windowProcField.GetValue($controlWindow)
  }
  function Get-T18StaleChains {
    # 붙기 직전의 창 프로시저(ChainProc)가 그 컨트롤 자신의 창 프로시저가 아닌 종류들(열거용 - 호출부가 @() 로 받음). 핸들을 다시 만든 직후에 봅니다.
    # 어긋난 창은 맨 위 창 프로시저를 컨트롤 자신의 것으로 되돌려 장치를 사슬에서 뺍니다 - 옛 핸들의 창 프로시저(수거될 수 있는 대리자)로 넘기는 장치를
    # 그대로 두면 다음 메시지들에서 프로세스가 죽을 수 있습니다(실패 갈래에서만 · 정상이면 아무것도 바꾸지 않음)
    param([string[]]$Kinds, $Devices, $Targets)
    foreach ($staleKind in $Kinds) {
      $staleControlProc = Get-T18ControlProc -Control $Targets[$staleKind]
      if ($Devices[$staleKind].ChainProc -ne $staleControlProc) {
        $staleKind
        if ($t18ChainReady -and ($staleControlProc -ne [IntPtr]::Zero)) { [void][HoneyThemeTest.ChainNative]::SetWindowLongPtr($Targets[$staleKind].Handle, -4, $staleControlProc) }
      }
    }
  }

  # ── T18b · T18c: 여섯 칸의 그림 ──
  try {
    $t18RecolorType = 'HoneyInputRecolor' -as [type]
    Reset-ThemeTestState
    New-T18Form -Handles
    # ① 장치가 없을 때의 그림(기준) - 라이트 색 · 다크 색 (제품이 칠하는 길 그대로: 숫자 · 목록 칸은 일괄 적용이 바탕 · 글자색을 주고 시간 칸은 손대지 않음)
    Set-T18Theme -Theme 'light'
    $t18PlainLight = Get-T18CellPictures
    Set-T18Theme -Theme 'dark'
    $t18PlainDark = Get-T18CellPictures
    Assert-Case 'T18 그림 준비 - 장치가 없는 여섯 칸(숫자 칸은 안쪽 글자 칸도 - 여덟 장)을 다시 찍어도 화소까지 같음(헤드리스 그림이 흔들리지 않음)' (Compare-T18PictureSet -Left $t18PlainDark -Right (Get-T18CellPictures)) ''
    # 고칠 것이 그림에 실제로 있는가(사용자가 본 다크 패널 그림 그대로): 시간 · 목록 칸의 바탕이 입력 바탕이 아니고, 잠긴 시간 칸과 잠긴 숫자 칸의 글자가 윈도우 회색입니다.
    # 이것이 거짓이면 아래 '바탕 = 입력 바탕' · '회색 0' 행은 아무것도 확인하지 않은 채 통과합니다
    $t18Gray = [System.Drawing.SystemColors]::GrayText
    Assert-Case 'T18 그림 준비 - 장치가 없는 다크 화면: 시간 · 목록 칸의 바탕이 입력 바탕 23,23,26 이 아님 · 잠긴 시간 칸과 잠긴 숫자 칸(글자 칸)에 윈도우 회색 글자 화소가 있음' `
      ('{0}/{1}/{2}/{3}' -f ((Get-T18PaperText -Picture $t18PlainDark['pickerOn']) -cne '23,23,26'), ((Get-T18PaperText -Picture $t18PlainDark['comboOn']) -cne '23,23,26'),
        ((Get-T18ColorCount -Picture $t18PlainDark['pickerOff'] -Color $t18Gray) -gt 0), ((Get-T18ColorCount -Picture $t18PlainDark['numericOffEdit'] -Color $t18Gray) -gt 0)) 'True/True/True/True'
    # ② 붙이기만 하고 켜지 않은 장치(직접 만듦 - 켜짐은 기본이 거짓): 창에 얹혀 있어도 모든 메시지를 그대로 넘겨 그림이 그대로여야 합니다 → 뗌
    $t18Manual = @{}
    foreach ($cellName in $t18CellNames) {
      $t18Cell = $script:t18Cells[$cellName]
      $t18CellTarget = $(if ($cellName -like 'numeric*') { Get-T18NumericEdit -Numeric $t18Cell } else { $t18Cell })
      $t18Manual[$cellName] = New-Object -TypeName HoneyInputRecolor -ArgumentList $t18Cell, $t18CellTarget
    }
    Assert-Case 'T18c 붙이기만 하고 켜지 않은 장치(여섯 칸) - 창의 맨 앞에 얹힘 · 꺼져 있음 · 그림이 장치 없는 그림과 화소까지 같음 · 다시 칠한 횟수 0' `
      ('{0}/{1}/[{2}]/{3}' -f @($t18CellNames | Where-Object { $t18Manual[$_].IsAttached -and (Test-T18FrontWindow -Control $t18Manual[$_].Target -Painter $t18Manual[$_]) }).Count,
        @($t18CellNames | Where-Object { $t18Manual[$_].Active }).Count, (Compare-T18PictureSet -Left $t18PlainDark -Right (Get-T18CellPictures)), (Get-T18CountText -Painters $t18Manual)) `
      '6/0/[]/pickerOn=0/0 pickerOff=0/0 comboOn=0/0 comboOff=0/0 numericOn=0/0 numericOff=0/0'
    # 떼기는 참/거짓을 돌려줍니다(11-14 설계 7.14 - 장치가 그 창의 맨 위일 때만 떼고 참, 아니면 붙은 채 남고 거짓). 여기의 장치는 모두 맨 위라 참이어야 합니다
    $t18ManualDetached = @($t18CellNames | ForEach-Object { $t18Manual[$_].Detach() })
    Assert-Case 'T18c 장치를 뗌(Detach - 여섯 칸) - 떼기가 참 여섯(장치가 맨 위) · 붙어 있는 장치 0 · 그 창의 맨 앞 창 프로시저가 장치가 아님 · 그림 그대로' `
      ('{0}/{1}/{2}/[{3}]' -f @($t18ManualDetached | Where-Object { ($_ -is [bool]) -and $_ }).Count, @($t18CellNames | Where-Object { $t18Manual[$_].IsAttached }).Count,
        @($t18CellNames | Where-Object { [System.Windows.Forms.NativeWindow]::FromHandle($t18Manual[$_].Target.Handle) -is $t18RecolorType }).Count, (Compare-T18PictureSet -Left $t18PlainDark -Right (Get-T18CellPictures))) '6/0/0/[]'
    # ③ 제품 함수로 다크(8a → 12) - 장치를 만들고(핸들이 이미 있어 바로 붙음) 색 대응을 넣고 켭니다
    $script:logLines.Clear()
    Update-InputRecolor
    Write-InputRecolorWarning
    $t18Painters = @{}
    foreach ($cellName in $t18CellNames) { $t18Painters[$cellName] = Get-T18Painter -Owner $script:t18Cells[$cellName] }
    $t18MissingPainters = @($t18CellNames | Where-Object { $null -eq $t18Painters[$_] })
    Assert-Case 'T18b 준비 - 제품 함수로 다크: 여섯 칸에 장치가 있음 · 그 창의 맨 앞에 얹힘 · 켜짐 · 오류 없음 · 원인 없음 · 로그 0' `
      ('[{0}]/{1}/{2}/[{3}]/{4}/{5}' -f ($t18MissingPainters -join ','), @($t18CellNames | Where-Object { $t18Painters[$_] -and (Test-T18FrontWindow -Control $t18Painters[$_].Target -Painter $t18Painters[$_]) }).Count,
        @($t18CellNames | Where-Object { $t18Painters[$_] -and $t18Painters[$_].Active }).Count, ((@($t18CellNames | ForEach-Object { if ($t18Painters[$_]) { $t18Painters[$_].LastError } })) -join ''),
        ($null -eq $script:inputRecolorError), $script:logLines.Count) '[]/6/6/[]/True/0'
    if ($t18MissingPainters.Count -eq 0) {
      # 어느 길을 탔는지: DrawToBitmap 은 그림 받기(WM_PRINTCLIENT) 횟수만 올립니다. 안 잠긴 숫자 칸은 대응이 없어 장치가 그리지 않고(0/0),
      # 잠긴 숫자 칸은 칸 전체를 찍을 때 1(자식 창인 글자 칸도 함께 찍힘) + 글자 칸을 따로 찍을 때 1 = 2 입니다
      $t18CountsBefore = Get-T18CountText -Painters $t18Painters
      $t18Painted = Get-T18CellPictures
      Assert-Case 'T18b 어느 길 - 여섯 칸을 한 번씩 찍음: 그림 받기 횟수만 오름(화면 그리기 0) · 안 잠긴 숫자 칸은 장치가 그리지 않음(0/0) · 잠긴 숫자 칸 2(칸 전체 + 글자 칸)' `
        ('{0} → {1}' -f $t18CountsBefore, (Get-T18CountText -Painters $t18Painters)) `
        'pickerOn=0/0 pickerOff=0/0 comboOn=0/0 comboOff=0/0 numericOn=0/0 numericOff=0/0 → pickerOn=0/1 pickerOff=0/1 comboOn=0/1 comboOff=0/1 numericOn=0/0 numericOff=0/2'
      # 바탕: 사용자 결정 '숫자 · 시간 · 목록 칸을 같은 색으로, 잠겨도 같은 색'. 여섯 칸 모두 입력 바탕과 정확히 같아야 합니다(11-14 내부 검토 - 잠긴 두 칸을 8 이내로만 보면
      # 제품이 상태별 종이색을 따로 둔 까닭을 지키지 못했음: 잠긴 시간 칸의 종이색 254 를 255 로 바꿔도 24,24,27 이라 통과). 윈도우가 잠긴 칸에 쓰는 종이색(시간 254 · 목록 250 -
      # 윈도우 11 테마 실측)은 흰색(255 · 253)과 달라, 흰색 기준 대응을 잠긴 칸에 쓰면 24,24,27 · 27,27,30 이 됩니다(설계 7.13).
      # 여기의 잠긴 두 칸은 잠근 채 만든 칸입니다(New-T18Form) - 시간 칸은 만든 뒤에 잠그면 종이색이 255 그대로라 한 단계 어긋나고, 그 경우는 아래 '잠금을 뒤집은 뒤' 행이 봅니다.
      # 다른 윈도우 테마에서 이 행이 갈리면 그 테마의 종이색이 실측 리터럴과 다른 것입니다(안 잠긴 목록 칸의 253 도 같은 종류의 가정)
      $t18Papers = @{}
      foreach ($pictureName in @($t18Painted.Keys)) { $t18Papers[$pictureName] = Get-T18PaperText -Picture $t18Painted[$pictureName] }
      'INFO T18b 다크 + 장치 - 안쪽에서 가장 많은 색: {0}' -f ((@($t18CellNames | ForEach-Object { '{0} {1}' -f $_, $t18Papers[$_] })) -join ' · ')
      Assert-Case 'T18b 바탕(안쪽에서 가장 많은 색) - 여섯 칸 모두 입력 바탕 23,23,26 (잠근 채 만든 시간 · 목록 칸 포함 - 잠겨도 같은 색)' `
        ('pickerOn={0} comboOn={1} numericOn={2} numericOff={3} pickerOff={4} comboOff={5}' -f $t18Papers['pickerOn'], $t18Papers['comboOn'], $t18Papers['numericOn'], $t18Papers['numericOff'],
          $t18Papers['pickerOff'], $t18Papers['comboOff']) `
        'pickerOn=23,23,26 comboOn=23,23,26 numericOn=23,23,26 numericOff=23,23,26 pickerOff=23,23,26 comboOff=23,23,26'
      # 테두리: 시간 · 목록 칸의 왼쪽 가운데 화소가 숫자 칸의 왼쪽 가운데 화소(윈도우가 그린 숫자 칸 테두리)와 같아야 세 칸의 테두리가 같습니다. 장치 전에는 그 색이 아니었는지,
      # 그리고 장치의 테두리색 함수가 그 숫자 칸 테두리와 같은 값을 내는지도 함께 봅니다(다른 윈도우 테마에서 둘이 갈리면 여기서 드러남)
      $t18NumericBorder = Get-T18PixelText -Picture $t18Painted['numericOn'] -X 0 -Y ([int][Math]::Floor($t18Painted['numericOn'].Height / 2))
      'INFO T18b 테두리 - 숫자 칸의 왼쪽 가운데 화소 {0} · 장치의 테두리색 {1}' -f $t18NumericBorder, (Get-RgbText (Get-InputRecolorBorderColor))
      $t18BorderFacts = foreach ($cellName in @('pickerOn', 'pickerOff', 'comboOn', 'comboOff')) {
        $middleRow = [int][Math]::Floor($t18Painted[$cellName].Height / 2)
        '{0}={1}/{2}' -f $cellName, ((Get-T18PixelText -Picture $t18Painted[$cellName] -X 0 -Y $middleRow) -ceq $t18NumericBorder), ((Get-T18PixelText -Picture $t18PlainDark[$cellName] -X 0 -Y $middleRow) -cne $t18NumericBorder)
      }
      Assert-Case 'T18b 테두리 - 시간 · 목록 칸(안 잠김 · 잠김)의 왼쪽 가운데 화소 = 숫자 칸의 테두리 화소 · 장치 전에는 다른 색(덧그린 것) / 장치의 테두리색 = 그 숫자 칸 테두리' `
        ('{0} / {1}' -f ((@($t18BorderFacts)) -join ' '), ($t18NumericBorder -ceq (Get-RgbText (Get-InputRecolorBorderColor)))) 'pickerOn=True/True pickerOff=True/True comboOn=True/True comboOff=True/True / True'
      # 글자: 기본 글자색 232,230,227 과 정확히 같은 화소(글자 가장자리의 번진 화소는 세지 않음). 잠긴 칸에 윈도우 회색 화소가 남으면 '잠겨도 같은 색' 이 아닙니다
      Assert-Case 'T18b 글자 - 기본 글자색 화소: 안 잠긴 시간 칸 있음(장치 전 0) · 잠긴 시간 칸 있음 + 윈도우 회색 0 · 잠긴 숫자 칸의 글자 칸 있음 + 윈도우 회색 0 · 안 잠긴 숫자 칸의 글자 칸 있음' `
        ('pickerOn={0}/{1} pickerOff={2}/{3} numericOffEdit={4}/{5} numericOnEdit={6}' -f
          ((Get-T18ColorCount -Picture $t18Painted['pickerOn'] -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18PlainDark['pickerOn'] -Color $t18DarkText),
          ((Get-T18ColorCount -Picture $t18Painted['pickerOff'] -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18Painted['pickerOff'] -Color $t18Gray),
          ((Get-T18ColorCount -Picture $t18Painted['numericOffEdit'] -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18Painted['numericOffEdit'] -Color $t18Gray),
          ((Get-T18ColorCount -Picture $t18Painted['numericOnEdit'] -Color $t18DarkText) -gt 0)) `
        'pickerOn=True/0 pickerOff=True/0 numericOffEdit=True/0 numericOnEdit=True'
      # 화소 분류: 다시 칠한 그림의 모든 화소가 ① 바깥 한 줄 = 테두리색 ② 스스로 그린 그림을 그 장치의 지금 색 대응으로 보낸 값 ③ 스스로 그린 그림 그대로(자식 창 자리)
      # 셋 중 하나여야 합니다. 시간 칸은 ▲▼(자식 창)가 그대로 남고, 목록 칸은 한 창 전체를 다시 칠해 ▼ 까지 ② 입니다(사용자가 고른 시험 창 그림의 모양).
      # 목록 칸의 글자를 그림으로 볼 수 없는 자리를 이 행이 메웁니다 - ▼ 와 번진 가장자리까지 '잉크' 쪽 화소가 색 대응대로 갔는지를 봅니다.
      # ③ 은 이 그림 길(그림 받기)에서의 모양입니다(11-14 내부 검토): 장치는 칸 전체를 칠하고(자식 창을 빼지 않는 호출) 그 뒤에 자식 창이 제 그림을 덧찍어 ▲▼ 가 남습니다.
      # 화면에 그릴 때 장치가 자식 창 자리를 그리는 영역에서 빼는 블록은 이 행과 무관합니다 - 보이지 않는 폼에서는 그 블록의 안쪽까지 가지 않아 G13 이 원문으로 고정하고,
      # 화면에서 ▲▼ 가 밝은 채 남는지는 실기가 봅니다
      $t18ClassFacts = foreach ($classCase in @(@('pickerOn', 'pickerOn'), @('pickerOff', 'pickerOff'), @('comboOn', 'comboOn'), @('comboOff', 'comboOff'), @('numericOff', 'numericOffEdit'))) {
        $classPainter = $t18Painters[$classCase[0]]
        $classMatrix = $(if ($classPainter.Owner.Enabled) { $classPainter.EnabledMatrix } else { $classPainter.DisabledMatrix })
        $classCounts = Get-T18PixelClasses -Painted $t18Painted[$classCase[1]] -Plain $t18PlainDark[$classCase[1]] -Mapped (Convert-T18Picture -Picture $t18PlainDark[$classCase[1]] -Matrix $classMatrix) `
          -BorderText $(if ($classPainter.BorderColor.IsEmpty) { '' } else { Get-RgbText $classPainter.BorderColor })
        @{ Name = $classCase[1]; Counts = $classCounts; Half = ($t18Painted[$classCase[1]].Width * $t18Painted[$classCase[1]].Height / 2) }
      }
      'INFO T18b 화소 분류(테두리/대응/그대로/그 밖): {0}' -f ((@($t18ClassFacts | ForEach-Object { '{0} {1}/{2}/{3}/{4}' -f $_.Name, $_.Counts.Border, $_.Counts.Mapped, $_.Counts.Kept, $_.Counts.Other })) -join ' · ')
      Assert-Case 'T18b 화소 분류 - 그 밖 0 · 절반 넘게 색 대응으로 간 화소 · 시간 칸만 그대로인 화소가 있음(▲▼ - 이 그림 길에서는 자식 창이 제 그림을 덧찍음) · 목록 칸과 잠긴 숫자 칸의 글자 칸은 전부 다시 칠함' `
        ((@($t18ClassFacts | ForEach-Object { '{0}: 그 밖 {1} · 대응 {2} · 그대로 {3}' -f $_.Name, $_.Counts.Other, ($_.Counts.Mapped -gt $_.Half), ($_.Counts.Kept -gt 0) })) -join ' | ') `
        ('pickerOn: 그 밖 0 · 대응 True · 그대로 True | pickerOff: 그 밖 0 · 대응 True · 그대로 True | comboOn: 그 밖 0 · 대응 True · 그대로 False | comboOff: 그 밖 0 · 대응 True · 그대로 False | ' +
          'numericOffEdit: 그 밖 0 · 대응 True · 그대로 False')
      Assert-Case 'T18b 안 잠긴 숫자 칸 - 장치가 그리지 않아 그림이 장치 없는 그림과 화소까지 같음(칸 전체 · 글자 칸)' `
        ('{0}/{1}' -f (Compare-T18Picture -Left $t18PlainDark['numericOn'] -Right $t18Painted['numericOn']), (Compare-T18Picture -Left $t18PlainDark['numericOnEdit'] -Right $t18Painted['numericOnEdit'])) '같음/같음'
      # 잠긴 숫자 칸은 안쪽 글자 칸만 다시 칠합니다(사용자 결정 '위아래 단추는 그대로'): 칸 전체 그림에서 장치 전과 달라진 화소가 있고, 그 화소가 모두 글자 칸 자리 안에 있어야 합니다
      $t18LockedEdit = Get-T18NumericEdit -Numeric $script:t18Cells['numericOff']
      $t18ChangedTotal = 0
      $t18ChangedOutside = 0
      for ($pixelY = 0; $pixelY -lt $t18Painted['numericOff'].Height; $pixelY++) {
        for ($pixelX = 0; $pixelX -lt $t18Painted['numericOff'].Width; $pixelX++) {
          if ((Get-T18PixelText -Picture $t18Painted['numericOff'] -X $pixelX -Y $pixelY) -cne (Get-T18PixelText -Picture $t18PlainDark['numericOff'] -X $pixelX -Y $pixelY)) {
            $t18ChangedTotal++
            if (($pixelX -lt $t18LockedEdit.Left) -or ($pixelX -ge $t18LockedEdit.Right) -or ($pixelY -lt $t18LockedEdit.Top) -or ($pixelY -ge $t18LockedEdit.Bottom)) { $t18ChangedOutside++ }
          }
        }
      }
      Assert-Case 'T18b 잠긴 숫자 칸 - 칸 전체 그림에서 달라진 화소가 있고(글자) 모두 안쪽 글자 칸 자리 안(위아래 단추 · 테두리는 그대로)' ('{0}/{1}' -f ($t18ChangedTotal -gt 0), $t18ChangedOutside) 'True/0'
      # 화면 그리기 길(WM_PAINT): 창 프로시저 직접 호출(관리 코드 경로)이 예외 없이 끝난 뒤에만 창 메시지를 실제로 보냅니다. 보이지 않는 창이라 화소는 볼 수 없고,
      # 장치가 그 길을 탔는지(화면 그리기 횟수)와 오류가 없는지만 봅니다 - 화면 화소의 판정은 실기 몫입니다
      $t18CountsPrinted = Get-T18CountText -Painters $t18Painters
      $t18PaintPreflight = @($t18CellNames | ForEach-Object {
          $paintThrown = Invoke-T18WndProc -Painter $t18Painters[$_]
          if ($paintThrown -ne '') { '{0}: {1}' -f $_, $paintThrown } })
      Assert-Case 'T18b 화면 그리기 길 - 여섯 장치의 창 프로시저에 WM_PAINT 를 직접(관리 코드 경로): 밖으로 나온 예외 0' ($t18PaintPreflight -join ' / ') ''
      if ($t18PaintPreflight.Count -eq 0) { foreach ($cellName in $t18CellNames) { Send-T18Paint -Painter $t18Painters[$cellName] } }
      Assert-Case 'T18b 화면 그리기 길 - 직접 호출 1번 + 컨트롤 창에 WM_PAINT 보내기 1번: 화면 그리기 횟수 +2(안 잠긴 숫자 칸은 통과라 0) · 그림 받기 횟수 그대로 · 오류 없음 · 켜진 채' `
        ('{0} → {1} | [{2}] | 켜짐 {3}' -f $t18CountsPrinted, (Get-T18CountText -Painters $t18Painters), ((@($t18CellNames | ForEach-Object { $t18Painters[$_].LastError })) -join ''),
          @($t18CellNames | Where-Object { $t18Painters[$_].Active }).Count) `
        ('pickerOn=0/1 pickerOff=0/1 comboOn=0/1 comboOff=0/1 numericOn=0/0 numericOff=0/2 → pickerOn=2/1 pickerOff=2/1 comboOn=2/1 comboOff=2/1 numericOn=0/0 numericOff=2/2 | [] | 켜짐 6')
      # 그릴 대상(DC)이 실려 온 WM_PAINT 는 장치가 맡지 않습니다(설계 7.13 - 그 DC 에 그려 달라는 호출이라 넘기기(Pass)로 그대로 넘김. 11-14 내부 검토 - 위의
      # WM_PAINT 는 모두 그릴 대상이 없는 보통의 것이라, 창 프로시저에서 그 조건을 지워도 어느 행도 실패하지 않았음). 맡으면 받은 DC 가 아니라 제 BeginPaint 의 DC 에 그립니다.
      # 창 프로시저를 직접 불러(관리 코드 경로) 유효한 비트맵 DC 를 실어 보내고, 장치가 화면 그리기로 세지 않았는지(화면 그리기 횟수 그대로)를 봅니다
      $t18CountsBeforeDc = Get-T18CountText -Painters $t18Painters
      $t18PaintDcLeaks = @($t18CellNames | ForEach-Object {
          $paintDcThrown = Invoke-T18WndProc -Painter $t18Painters[$_] -PaintToDc
          if ($paintDcThrown -ne '') { '{0}: {1}' -f $_, $paintDcThrown } })
      $t18CountsAfterDc = Get-T18CountText -Painters $t18Painters
      "INFO T18b 그릴 대상(DC)이 실려 온 WM_PAINT - 다시 칠한 횟수(화면 그리기/그림 받기): 전 {0} → 뒤 {1}" -f $t18CountsBeforeDc, $t18CountsAfterDc
      Assert-Case 'T18b 그릴 대상(DC)이 실려 온 WM_PAINT - 여섯 장치의 창 프로시저에 직접(유효한 비트맵 DC): 밖으로 나온 예외 0 · 장치가 맡지 않고 넘김(화면 그리기 · 그림 받기 횟수가 보내기 전과 같음) · 오류 없음 · 켜진 채' `
        ('[{0}] | {1} | [{2}] | 켜짐 {3}' -f ($t18PaintDcLeaks -join ' / '), ($t18CountsAfterDc -ceq $t18CountsBeforeDc), ((@($t18CellNames | ForEach-Object { $t18Painters[$_].LastError })) -join ''),
          @($t18CellNames | Where-Object { $t18Painters[$_].Active }).Count) '[] | True | [] | 켜짐 6'
      # ④ 제품 함수로 라이트(끔) - 다크로 켰다가 끈 뒤의 그림 = 장치가 없을 때의 그림(계약 L: 다크를 거쳐 돌아온 라이트 화면이 전환 전과 같아야 함)
      Set-T18Theme -Theme 'light'
      Update-InputRecolor
      Write-InputRecolorWarning
      $t18CountsOff = Get-T18CountText -Painters $t18Painters
      $t18OffLight = Get-T18CellPictures
      Assert-Case 'T18c 다크로 켰다가 라이트로 끔(제품 함수) - 켜진 장치 0 · 여섯 칸의 그림이 장치가 없을 때의 라이트 그림과 화소까지 같음 · 꺼진 장치는 다시 칠하지 않음(횟수 그대로) · 로그 0' `
        ('{0}/[{1}]/{2}/{3}' -f @($t18CellNames | Where-Object { $t18Painters[$_].Active }).Count, (Compare-T18PictureSet -Left $t18PlainLight -Right $t18OffLight),
          ((Get-T18CountText -Painters $t18Painters) -ceq $t18CountsOff), $script:logLines.Count) '0/[]/True/0'
      # 같은 색끼리도 맞댑니다: 장치를 끈 채 다크 색만 다시 칠한 그림 = 장치가 없을 때의 다크 그림
      Set-T18Theme -Theme 'dark'
      Assert-Case 'T18c 꺼진 장치 + 다크 색 - 장치가 없을 때의 다크 그림과 화소까지 같음(여섯 칸)' (Compare-T18PictureSet -Left $t18PlainDark -Right (Get-T18CellPictures)) ''
      # ⑤ 다시 켠 뒤 잠금을 뒤집고 값을 바꿉니다 - 장치는 그릴 때마다 주인의 잠금을 읽어 대응을 고르므로 실행 중 잠금 · 커스텀 반복 선택처럼 떠 있는 채 잠겨도 글자가 기본 글자색이어야 합니다.
      #    핸들이 생긴 뒤에 잠금이 바뀐 시간 칸은 윈도우가 바탕(종이색)을 그 칸의 핸들이 만들어질 때의 모양으로 둔 채 글자만 지금 잠금대로 그립니다(11-14 관측) -
      #    그래서 시간 칸 바탕은 채널마다 1 어긋날 수 있어(22,22,25 · 24,24,27 - 설계 7.13 의 알려진 예외) 1 이내로 보고, 목록 칸은 지금 잠금의 종이색을 따르므로 정확히 봅니다
      #    (11-14 구현 리뷰 P3 - 예전의 8 은 관측된 1 보다 넓어 목록 칸의 종이색 어긋남까지 통과시켰음)
      Update-InputRecolor
      foreach ($cellName in $t18CellNames) { $script:t18Cells[$cellName].Enabled = -not $script:t18Cells[$cellName].Enabled }
      $script:t18Cells['pickerOn'].Value = [datetime]'2026-01-02 21:07:00'
      $script:t18Cells['numericOn'].Value = 7
      $t18Flipped = Get-T18CellPictures
      'INFO T18b 잠금을 뒤집은 뒤 - 안쪽에서 가장 많은 색: {0}' -f ((@(@('pickerOn', 'pickerOff', 'comboOn', 'comboOff') | ForEach-Object { '{0} {1}' -f $_, (Get-T18PaperText -Picture $t18Flipped[$_]) })) -join ' · ')
      Assert-Case 'T18b 잠금을 뒤집은 뒤(풀려 있던 칸을 잠그고 값을 바꿈 · 잠겨 있던 칸을 풂) - 시간 칸 둘: 바탕이 입력 바탕과 1 이내 · 기본 글자색 화소 있음 · 윈도우 회색 0 / 목록 칸 둘: 바탕 = 입력 바탕 / 숫자 칸 둘의 글자 칸: 기본 글자색 있음 · 회색 0' `
        ('pickerOn={0}/{1}/{2} pickerOff={3}/{4}/{5} comboOn={6} comboOff={7} numericOnEdit={8}/{9} numericOffEdit={10}/{11}' -f
          (Test-T18Near -RgbText (Get-T18PaperText -Picture $t18Flipped['pickerOn']) -Color $t18DarkInput -Tolerance 1), ((Get-T18ColorCount -Picture $t18Flipped['pickerOn'] -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18Flipped['pickerOn'] -Color $t18Gray),
          (Test-T18Near -RgbText (Get-T18PaperText -Picture $t18Flipped['pickerOff']) -Color $t18DarkInput -Tolerance 1), ((Get-T18ColorCount -Picture $t18Flipped['pickerOff'] -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18Flipped['pickerOff'] -Color $t18Gray),
          (Test-T18Near -RgbText (Get-T18PaperText -Picture $t18Flipped['comboOn']) -Color $t18DarkInput -Tolerance 0), (Test-T18Near -RgbText (Get-T18PaperText -Picture $t18Flipped['comboOff']) -Color $t18DarkInput -Tolerance 0),
          ((Get-T18ColorCount -Picture $t18Flipped['numericOnEdit'] -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18Flipped['numericOnEdit'] -Color $t18Gray),
          ((Get-T18ColorCount -Picture $t18Flipped['numericOffEdit'] -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18Flipped['numericOffEdit'] -Color $t18Gray)) `
        'pickerOn=True/True/0 pickerOff=True/True/0 comboOn=True comboOff=True numericOnEdit=True/0 numericOffEdit=True/0'
      Assert-Case 'T18b 그림 행 전체 - 장치 오류 없음 · 원인 없음 · 로그 0' ('[{0}]/{1}/{2}' -f ((@($t18CellNames | ForEach-Object { $t18Painters[$_].LastError })) -join ''), ($null -eq $script:inputRecolorError), $script:logLines.Count) '[]/True/0'
    }
  } catch { Assert-SectionError -Section 'T18b · T18c' -ErrorRecord $_ }

  # ── T18b 부모에서 온 잠금 (11-14 내부 검토 - 위 행의 잠금은 모두 칸 자신의 Enabled 였음) ──
  # 제품의 실행 중 잠금은 칸 자신이 아니라 부모에서 옵니다: '반복' 묶음을 통째로 잠그고(Set-UiRunning 의 $grpRepeat.Enabled 대입) 그 안의 횟수 숫자 칸 · 시간 칸은
  # 자신의 잠금을 건드리지 않습니다. 사용자가 본 '실행 중 잠긴 칸의 어두운 글자' 가 이 경로입니다. 장치는 주인의 Enabled 를 읽고 그 값은 조상의 잠금을 반영하므로
  # 같은 색이 되어야 합니다 - 묶음 · 숫자 칸 · 시간 칸을 제품의 생성 문장 그대로(묶음 안 제품 자리) 만들고, 풀린 채 핸들을 만든 뒤(제품의 실행 전 상태) 묶음만 잠급니다
  function New-T18RunLockForm {
    # '반복' 묶음 안에 횟수 숫자 칸과 시간 칸(제품의 생성 문장 · 속성 대입문 그대로 - 하네스는 이름표 · 묶음의 세로 자리 · 시간 값만 정함). 칸 자신은 잠그지 않습니다 · 핸들 있음
    if ($script:form) { try { $script:form.Dispose() } catch { } }
    if ($script:cellEditCombo) { try { $script:cellEditCombo.Dispose() } catch { } }
    $script:form = New-Object System.Windows.Forms.Form
    $script:form.Size = New-Object System.Drawing.Size(560, 320)
    $script:form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $script:t18Cells = @{}
    $script:t18Cells['runGroup'] = New-SourceControl -SourceName 'grpRepeat' -Parent $script:form -Name 'runGroup' -Y 20
    $script:t18Cells['runNumeric'] = New-SourceControl -SourceName 'numCount' -Parent $script:t18Cells['runGroup'] -Name 'runNumeric'
    $script:t18Cells['runPicker'] = New-SourceControl -SourceName 'dtpUntil' -Parent $script:t18Cells['runGroup'] -Name 'runPicker'
    $script:t18Cells['runPicker'].Value = [datetime]'2026-01-02 12:34:00'
    New-SourceCellEditCombo
    Initialize-AllHandles -Parent $script:form
  }
  try {
    Reset-ThemeTestState
    New-T18RunLockForm
    Set-T18Theme -Theme 'dark'
    Update-InputRecolor
    $t18RunGray = [System.Drawing.SystemColors]::GrayText
    $t18RunGroup = $script:t18Cells['runGroup']
    $t18RunPicker = $script:t18Cells['runPicker']
    $t18RunNumeric = $script:t18Cells['runNumeric']
    $t18RunEdit = Get-T18NumericEdit -Numeric $t18RunNumeric
    $t18RunPickerPainter = Get-T18Painter -Owner $t18RunPicker
    $t18RunNumericPainter = Get-T18Painter -Owner $t18RunNumeric
    Assert-Case 'T18b 부모 잠금 준비 - 묶음 안 시간 칸 · 숫자 칸에 장치가 있음 · 창에 붙음 · 켜짐 / 묶음도 두 칸도 풀려 있음' `
      ('{0}/{1}/{2} | {3}/{4}/{5}' -f (($null -ne $t18RunPickerPainter) -and ($null -ne $t18RunNumericPainter)),
        (($null -ne $t18RunPickerPainter) -and $t18RunPickerPainter.IsAttached -and ($null -ne $t18RunNumericPainter) -and $t18RunNumericPainter.IsAttached),
        (($null -ne $t18RunPickerPainter) -and $t18RunPickerPainter.Active -and ($null -ne $t18RunNumericPainter) -and $t18RunNumericPainter.Active),
        $t18RunGroup.Enabled, $t18RunPicker.Enabled, $t18RunNumeric.Enabled) 'True/True/True | True/True/True'
    if (($null -ne $t18RunPickerPainter) -and ($null -ne $t18RunNumericPainter)) {
      # 묶음만 잠급니다(실행 시작). 고칠 것이 그림에 실제로 있는지부터: 장치를 잠깐 끄면 두 칸의 글자가 윈도우 회색입니다(이것이 거짓이면 아래 '회색 0' 은 빈 확인)
      $t18RunGroup.Enabled = $false
      $t18RunPickerPainter.Active = $false
      $t18RunNumericPainter.Active = $false
      $t18RunGrayOff = '{0}/{1}' -f ((Get-T18ColorCount -Picture (Get-T18Picture -Control $t18RunPicker) -Color $t18RunGray) -gt 0), ((Get-T18ColorCount -Picture (Get-T18Picture -Control $t18RunEdit) -Color $t18RunGray) -gt 0)
      $t18RunPickerPainter.Active = $true
      $t18RunNumericPainter.Active = $true
      $t18RunPickerPrints = $t18RunPickerPainter.PrintCount
      $t18RunNumericPrints = $t18RunNumericPainter.PrintCount
      $t18RunLockedPicker = Get-T18Picture -Control $t18RunPicker
      $t18RunLockedEdit = Get-T18Picture -Control $t18RunEdit
      'INFO T18b 부모 잠금 - 시간 칸의 안쪽에서 가장 많은 색: {0} (풀린 채 만든 뒤 잠긴 칸 - 종이색 255 그대로라 한 단계 어긋남)' -f (Get-T18PaperText -Picture $t18RunLockedPicker)
      Assert-Case 'T18b 부모 묶음을 잠금(실행 중 잠금과 같은 꼴) - 두 칸이 잠긴 것으로 읽힘 · 장치를 끄면 두 칸에 윈도우 회색 글자 / 켜면: 시간 칸 기본 글자색 있음 · 회색 0 · 바탕 8 이내 · 다시 칠함(그림 받기 +1) / 숫자 칸의 글자 칸 기본 글자색 있음 · 회색 0 · 잠긴 대응으로 다시 칠함(+1)' `
        ('{0}/{1} | {2} | picker={3}/{4}/{5}/+{6} numericEdit={7}/{8}/+{9}' -f $t18RunPicker.Enabled, $t18RunNumeric.Enabled, $t18RunGrayOff,
          ((Get-T18ColorCount -Picture $t18RunLockedPicker -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18RunLockedPicker -Color $t18RunGray),
          (Test-T18Near -RgbText (Get-T18PaperText -Picture $t18RunLockedPicker) -Color $t18DarkInput -Tolerance 8), ($t18RunPickerPainter.PrintCount - $t18RunPickerPrints),
          ((Get-T18ColorCount -Picture $t18RunLockedEdit -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18RunLockedEdit -Color $t18RunGray), ($t18RunNumericPainter.PrintCount - $t18RunNumericPrints)) `
        'False/False | True/True | picker=True/0/True/+1 numericEdit=True/0/+1'
      # 묶음을 다시 풉니다(정지) - 시간 칸은 안 잠긴 대응으로 다시 칠하고, 숫자 칸은 대응이 없어 장치가 그리지 않습니다(그림 받기 횟수 그대로 · 글자는 일괄 적용이 준 기본 글자색)
      $t18RunGroup.Enabled = $true
      $t18RunPickerPrints = $t18RunPickerPainter.PrintCount
      $t18RunNumericPrints = $t18RunNumericPainter.PrintCount
      $t18RunFreePicker = Get-T18Picture -Control $t18RunPicker
      $t18RunFreeEdit = Get-T18Picture -Control $t18RunEdit
      Assert-Case 'T18b 부모 묶음을 다시 풂(정지) - 두 칸이 풀린 것으로 읽힘 · 시간 칸: 기본 글자색 있음 · 회색 0 · 바탕 = 입력 바탕 · 다시 칠함(그림 받기 +1) / 숫자 칸의 글자 칸: 기본 글자색 있음 · 회색 0 · 장치가 그리지 않음(+0) / 장치 오류 없음 · 로그 0' `
        ('{0}/{1} | picker={2}/{3}/{4}/+{5} numericEdit={6}/{7}/+{8} | [{9}]/{10}' -f $t18RunPicker.Enabled, $t18RunNumeric.Enabled,
          ((Get-T18ColorCount -Picture $t18RunFreePicker -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18RunFreePicker -Color $t18RunGray), (Get-T18PaperText -Picture $t18RunFreePicker),
          ($t18RunPickerPainter.PrintCount - $t18RunPickerPrints),
          ((Get-T18ColorCount -Picture $t18RunFreeEdit -Color $t18DarkText) -gt 0), (Get-T18ColorCount -Picture $t18RunFreeEdit -Color $t18RunGray), ($t18RunNumericPainter.PrintCount - $t18RunNumericPrints),
          ($t18RunPickerPainter.LastError + $t18RunNumericPainter.LastError), $script:logLines.Count) `
        'True/True | picker=True/0/23,23,26/+1 numericEdit=True/0/+0 | []/0'
    }
  } catch { Assert-SectionError -Section 'T18b 부모 잠금' -ErrorRecord $_ }

  # ── T18d(핸들 있는 폼): 다시 그리기 요청 · 끄는 도중의 실패 · 장치 만들기가 도중에 실패 ──
  try {
    Reset-ThemeTestState
    New-T18Form -Handles
    Set-T18Theme -Theme 'dark'
    # 다시 그리기 요청: 켜거나 끈 뒤 대상마다 Invalidate 를 요청해야 떠 있는 창의 칸이 바로 다시 그려집니다(요청이 없으면 다른 일로 다시 그려질 때까지 옛 모양).
    # Invalidated 이벤트는 핸들이 있을 때만 납니다 - 셀 편집 콤보는 표 밖이라 핸들이 없어 0 입니다(붙는 컨트롤의 이름으로 셈 - 숫자 칸의 글자 칸은 이름표를 달아 둠)
    $script:t18Invalidations = @{}
    foreach ($numericName in @('numericOn', 'numericOff')) { (Get-T18NumericEdit -Numeric $script:t18Cells[$numericName]).Name = $numericName + 'Edit' }
    Update-InputRecolor
    $t18Entries = @(Get-T18Entries)
    foreach ($t18Entry in $t18Entries) { $t18Entry.Painter.Target.Add_Invalidated({ $script:t18Invalidations[$this.Name] = 1 + [int]$script:t18Invalidations[$this.Name] }) }
    $t18TargetNames = @($t18Entries | ForEach-Object { $_.Painter.Target.Name })
    $script:t18Invalidations.Clear()
    Update-InputRecolor
    $t18DarkInvalidations = (@($t18TargetNames | ForEach-Object { '{0}={1}' -f $_, [int]$script:t18Invalidations[$_] })) -join ' '
    # 팔레트를 바꿔 색을 다시 칠하는 것도 그 컨트롤을 다시 그리게 하므로(바탕색 대입), 세는 것은 색을 칠한 뒤 · 켜고 끄기 직전부터입니다
    Set-T18Theme -Theme 'light'
    $script:t18Invalidations.Clear()
    Update-InputRecolor
    $t18LightInvalidations = (@($t18TargetNames | ForEach-Object { '{0}={1}' -f $_, [int]$script:t18Invalidations[$_] })) -join ' '
    Assert-Case 'T18d 다시 그리기 요청 - 다크로 켤 때 · 라이트로 끌 때 붙는 컨트롤마다 1회(숫자 칸은 안쪽 글자 칸 · 핸들 없는 셀 편집 콤보는 0)' ('{0} / {1}' -f $t18DarkInvalidations, $t18LightInvalidations) `
      ('pickerOn=1 pickerOff=1 comboOn=1 comboOff=1 numericOnEdit=1 numericOffEdit=1 comboNested=1 cellEditCombo=0 / ' +
        'pickerOn=1 pickerOff=1 comboOn=1 comboOff=1 numericOnEdit=1 numericOffEdit=1 comboNested=1 cellEditCombo=0')
    # 끄는 도중 다시 그리기 요청 하나가 던질 때(목록 맨 앞에 요청이 던지는 가짜 장치를 끼움) - 끄기는 두 번에 나눠 하므로(먼저 전부 끔 → 그다음 요청) 나머지가 켜진 채 남지 않고,
    # 요청도 나머지에 계속 갑니다. 폐기된 컨트롤의 요청은 던지지 않아(핸들이 없으면 아무 일도 안 함) 던지는 메서드를 가진 객체로 일으킵니다
    Set-T18Theme -Theme 'dark'
    Update-InputRecolor
    $t18FakeTarget = New-Object psobject
    $t18FakeTarget | Add-Member -MemberType ScriptMethod -Name Invalidate -Value { throw '다시 그리기 주입 예외' }
    $t18FakePainter = New-Object psobject -Property @{ Active = $true; Target = $t18FakeTarget }
    $script:inputRecolorPainters = @(@{ Kind = 'combo'; Painter = $t18FakePainter }) + $t18Entries
    $t18ActiveBeforeOff = @($t18Entries | Where-Object { $_.Painter.Active }).Count
    Set-T18Theme -Theme 'light'
    $script:t18Invalidations.Clear()
    $t18OffThrown = ''
    try { Update-InputRecolor } catch { $t18OffThrown = $_.Exception.Message }
    Assert-Case 'T18d 끄는 도중 다시 그리기 요청 하나가 던짐 - 예외 0 · 켜져 있던 8개가 모두 꺼짐(가짜 장치도) · 나머지 일곱의 요청은 그대로 감' `
      ('[{0}] | {1}>{2} · {3} | {4}' -f $t18OffThrown, $t18ActiveBeforeOff, @($t18Entries | Where-Object { $_.Painter.Active }).Count, $t18FakePainter.Active,
        ((@($t18TargetNames | ForEach-Object { '{0}={1}' -f $_, [int]$script:t18Invalidations[$_] })) -join ' ')) `
      '[] | 8>0 · False | pickerOn=1 pickerOff=1 comboOn=1 comboOff=1 numericOnEdit=1 numericOffEdit=1 comboNested=1 cellEditCombo=0'
    # 장치 만들기가 도중에 실패(마지막 대상인 셀 편집 콤보가 없어 그 장치의 생성자가 던짐 - 앞의 일곱은 이미 만들어져 창에 붙은 뒤): 만든 장치를 모두 떼고 던져야 합니다.
    # 목록은 없음 그대로라 다음 다크 전환이 처음부터 다시 만드는데, 떼지 않았으면 같은 창에 장치가 둘 얹힙니다. 뗀 것은 창 쪽에서 봅니다(맨 앞 창 프로시저가 장치가 아님) -
    # 핸들을 다시 만들어도 붙지 않아야 합니다(핸들 생성 구독까지 끊김)
    Reset-ThemeTestState
    New-T18Form -Handles
    Set-T18Theme -Theme 'dark'
    $t18RecolorType = 'HoneyInputRecolor' -as [type]
    $t18FormTargets = @(@('pickerOn', 'pickerOff', 'comboOn', 'comboOff', 'comboNested') | ForEach-Object { $script:t18Cells[$_] }) +
      @(@('numericOn', 'numericOff') | ForEach-Object { Get-T18NumericEdit -Numeric $script:t18Cells[$_] })
    $t18KeptCombo = $script:cellEditCombo
    $script:cellEditCombo = $null
    $t18InitThrown = ''
    # 갱신 함수의 출력도 받습니다(11-14 설계 7.14): 장치 만들기의 실패 정리가 부르는 떼기는 참/거짓을 돌려줘, 받지 않으면 그 값(여기서는 참 일곱)이 출력으로 새어
    # 공용 갱신 · 전환 함수의 출력이 됩니다 - 출력은 비어 있어야 합니다
    $t18InitOutput = @()
    try { $t18InitOutput = @(Update-InputRecolor) } catch { $t18InitThrown = $_.Exception.Message }
    $t18StillFront = @($t18FormTargets | Where-Object { [System.Windows.Forms.NativeWindow]::FromHandle($_.Handle) -is $t18RecolorType }).Count
    $t18Recreated = @($t18FormTargets | Where-Object { Invoke-T18RecreateHandle -Control $_ }).Count
    $t18FrontAfterRecreate = @($t18FormTargets | Where-Object { [System.Windows.Forms.NativeWindow]::FromHandle($_.Handle) -is $t18RecolorType }).Count
    Assert-Case 'T18d 장치 만들기가 도중에 실패(여덟째 대상이 없음) - 예외 0 · 갱신 함수의 출력 0(떼기의 반환값이 새지 않음) · 목록 없음 그대로 · 원인과 경고 보관 · 앞의 일곱 창에 장치가 남아 있지 않음 · 핸들을 다시 만들어도(일곱) 붙지 않음' `
      ('[{0}] 출력 {1} | {2} · {3} · {4} | {5} | {6}>{7}' -f $t18InitThrown, $t18InitOutput.Count, ($null -eq $script:inputRecolorPainters), (-not [string]::IsNullOrEmpty($script:inputRecolorError)),
        ([string]$script:inputRecolorPendingWarning).StartsWith($t18ApplyWarning), $t18StillFront, $t18Recreated, $t18FrontAfterRecreate) '[] 출력 0 | True · True · True | 0 | 7>0'
    # 다음 다크 호출은 처음부터 다시 만듭니다 - 창마다 맨 앞 창 프로시저가 목록의 그 장치이고(뗀 옛 장치가 아님) 모두 켜집니다
    $script:cellEditCombo = $t18KeptCombo
    Update-InputRecolor
    $t18Entries = @(Get-T18Entries)
    Assert-Case 'T18d 실패 뒤 다시 다크 - 처음부터 다시 만듦: 장치 8개 · 모두 켜짐 · 폼 아래 일곱 창의 맨 앞 창 프로시저 = 목록의 그 장치' `
      ('{0}/{1}/{2}' -f $t18Entries.Count, @($t18Entries | Where-Object { $_.Painter.Active }).Count,
        @($t18Entries | Where-Object { $_.Painter.Target.IsHandleCreated -and (Test-T18FrontWindow -Control $_.Painter.Target -Painter $_.Painter) }).Count) '8/8/7'
  } catch { Assert-SectionError -Section 'T18d 핸들' -ErrorRecord $_ }

  # ── T18e 핸들: 만들 때 핸들을 만들지 않음 · 핸들이 생기면 붙음 · 다시 만들면 다시 붙음 · 끈 채 다시 만든 뒤에도 장치 없는 짝과 같음 ──
  function New-T18TwinForm {
    # 종류마다 같은 칸 둘(장치를 붙일 칸 · 손대지 않는 짝)을 제품의 생성 문장 그대로 만든 폼 - 전부 안 잠김 · 같은 값. 핸들은 만들지 않습니다(행이 순서대로 만듦)
    if ($script:form) { try { $script:form.Dispose() } catch { } }
    if ($script:cellEditCombo) { try { $script:cellEditCombo.Dispose() } catch { } }
    $script:form = New-Object System.Windows.Forms.Form
    $script:form.Size = New-Object System.Drawing.Size(560, 320)
    $script:form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $script:t18Cells = @{}
    $twinTop = 20
    foreach ($twinCase in @(@('picker', 'dtpUntil'), @('combo', 'cboDifficulty'), @('numeric', 'numCount'))) {
      $script:t18Cells[$twinCase[0] + 'Subject'] = New-SourceControl -SourceName $twinCase[1] -Parent $script:form -Name ($twinCase[0] + 'Subject') -X 20 -Y $twinTop
      $script:t18Cells[$twinCase[0] + 'Twin'] = New-SourceControl -SourceName $twinCase[1] -Parent $script:form -Name ($twinCase[0] + 'Twin') -X 220 -Y $twinTop
      $twinTop += 40
    }
    foreach ($pickerName in @('pickerSubject', 'pickerTwin')) { $script:t18Cells[$pickerName].Value = [datetime]'2026-01-02 12:34:00' }
    foreach ($comboName in @('comboSubject', 'comboTwin')) {
      [void]$script:t18Cells[$comboName].Items.Add('게임 그대로')
      [void]$script:t18Cells[$comboName].Items.Add('어려움')
      $script:t18Cells[$comboName].SelectedIndex = 0
    }
    New-SourceCellEditCombo
  }
  function Get-T18TwinDifference {
    # 장치를 붙인 칸과 손대지 않은 짝의 그림 차이(시간 · 목록 · 숫자 칸 + 숫자 칸의 글자 칸) - 모두 같으면 ''
    $twinDifferences = foreach ($twinKind in @('picker', 'combo', 'numeric')) {
      $twinDifference = Compare-T18Picture -Left (Get-T18Picture -Control $script:t18Cells[$twinKind + 'Twin']) -Right (Get-T18Picture -Control $script:t18Cells[$twinKind + 'Subject'])
      if ($twinDifference -cne '같음') { '{0}: {1}' -f $twinKind, $twinDifference }
    }
    $editDifference = Compare-T18Picture -Left (Get-T18Picture -Control (Get-T18NumericEdit -Numeric $script:t18Cells['numericTwin'])) -Right (Get-T18Picture -Control (Get-T18NumericEdit -Numeric $script:t18Cells['numericSubject']))
    if ($editDifference -cne '같음') { $twinDifferences = @($twinDifferences) + ('numericEdit: ' + $editDifference) }
    return ((@($twinDifferences)) -join ' / ')
  }
  try {
    Reset-ThemeTestState
    New-T18TwinForm
    Set-T18Theme -Theme 'dark'
    $t18RecolorType = 'HoneyInputRecolor' -as [type]
    $t18Kinds = @('picker', 'combo', 'numeric')
    $t18Subjects = @{}
    $t18Targets = @{}
    $t18Devices = @{}
    foreach ($t18Kind in $t18Kinds) {
      $t18Subjects[$t18Kind] = $script:t18Cells[$t18Kind + 'Subject']
      $t18Targets[$t18Kind] = $(if ($t18Kind -eq 'numeric') { Get-T18NumericEdit -Numeric $t18Subjects[$t18Kind] } else { $t18Subjects[$t18Kind] })
      $t18Devices[$t18Kind] = New-Object -TypeName HoneyInputRecolor -ArgumentList $t18Subjects[$t18Kind], $t18Targets[$t18Kind]
    }
    Assert-Case 'T18e 핸들 없는 컨트롤에 장치를 만듦 - 핸들이 생기지 않음(폼 · 주인 셋 · 붙는 컨트롤 셋) · 붙지 않음 · 꺼져 있음' `
      ('{0}/{1}/{2}/{3}/{4}' -f $script:form.IsHandleCreated, @($t18Kinds | Where-Object { $t18Subjects[$_].IsHandleCreated }).Count, @($t18Kinds | Where-Object { $t18Targets[$_].IsHandleCreated }).Count,
        @($t18Kinds | Where-Object { $t18Devices[$_].IsAttached }).Count, @($t18Kinds | Where-Object { $t18Devices[$_].Active }).Count) 'False/0/0/0/0'
    Initialize-AllHandles -Parent $script:form
    Assert-Case 'T18e 핸들이 생김 - 세 장치가 붙음 · 붙은 핸들 = 붙는 컨트롤의 핸들 · 그 창의 맨 앞 창 프로시저 = 그 장치 · 붙기 직전 창 프로시저 = 그 컨트롤 자신의 창 프로시저(서브클래스 없는 칸) / 꺼진 채라 그림은 손대지 않은 짝과 같음' `
      ('{0}/{1}/{2}/{3}/[{4}]' -f @($t18Kinds | Where-Object { $t18Devices[$_].IsAttached }).Count, @($t18Kinds | Where-Object { $t18Devices[$_].Handle -eq $t18Targets[$_].Handle }).Count,
        @($t18Kinds | Where-Object { Test-T18FrontWindow -Control $t18Targets[$_] -Painter $t18Devices[$_] }).Count,
        @($t18Kinds | Where-Object { $t18Devices[$_].ChainProc -eq (Get-T18ControlProc -Control $t18Targets[$_]) }).Count, (Get-T18TwinDifference)) '3/3/3/3/[]'
    # 끈 채로 붙는 컨트롤의 핸들을 다시 만듭니다 - 장치는 새 핸들에 다시 붙고(옛 핸들에 붙은 채 남지 않음), 꺼져 있으니 그림은 여전히 짝과 같아야 합니다.
    # 붙기 직전 창 프로시저도 새 핸들에서 새로 읽어야 합니다(설계 7.14 고침 4 - 11-14 구현 리뷰): 컨트롤의 관리 창은 핸들마다 창 프로시저 대리자를 새로 만들어, 옛 값을
    # 그대로 쓰면 수거될 수 있는 옛 대리자로 넘깁니다(수거 전에는 같은 처리기가 불려 그림 · 값 · 떼기가 그대로라 다른 행으로는 안 드러남 · 아래 R 행은 아래 창 프로시저가
    # 핸들과 무관한 comctl32 마스터라 구별하지 못함). 다시 만든 직후 · 메시지를 더 보내기 전에 봅니다. 앞 칸 = 재생성으로 컨트롤 자신의 창 프로시저가 실제로 바뀐 종류 수
    # (이것이 셋이어야 '같음' 이 옛 값과 구별됨), 뒤 칸 = 붙기 직전 창 프로시저가 새 핸들의 그 값과 다른 종류(어긋나면 그 창에서 장치를 빼 둠 - Get-T18StaleChains)
    $t18ChainBefore = @{}
    foreach ($t18Kind in $t18Kinds) { $t18ChainBefore[$t18Kind] = $t18Devices[$t18Kind].ChainProc }
    $t18RecreatedOff = @($t18Kinds | Where-Object { Invoke-T18RecreateHandle -Control $t18Targets[$_] }).Count
    $t18ControlProcChangedOff = @($t18Kinds | Where-Object { (Get-T18ControlProc -Control $t18Targets[$_]) -ne $t18ChainBefore[$_] }).Count
    $t18StaleOff = @(Get-T18StaleChains -Kinds $t18Kinds -Devices $t18Devices -Targets $t18Targets)
    Assert-Case 'T18e 끈 채로 핸들을 다시 만듦 - 붙기 직전 창 프로시저를 새로 읽음: 재생성으로 컨트롤 자신의 창 프로시저가 바뀐 종류 셋 / 장치의 붙기 직전 창 프로시저가 새 핸들의 그 값과 다른 종류 없음' `
      ('{0}/[{1}]' -f $t18ControlProcChangedOff, ($t18StaleOff -join ',')) '3/[]'
    Assert-Case 'T18e 끈 채로 핸들을 다시 만듦(붙는 컨트롤 셋) - 핸들이 바뀜 · 새 핸들에 다시 붙음(붙은 핸들 = 새 핸들 · 맨 앞 창 프로시저 = 그 장치) · 그림이 손대지 않은 짝과 화소까지 같음' `
      ('{0}/{1}/{2}/[{3}]' -f $t18RecreatedOff, @($t18Kinds | Where-Object { $t18Devices[$_].IsAttached -and ($t18Devices[$_].Handle -eq $t18Targets[$_].Handle) }).Count,
        @($t18Kinds | Where-Object { Test-T18FrontWindow -Control $t18Targets[$_] -Painter $t18Devices[$_] }).Count, (Get-T18TwinDifference)) '3/3/3/[]'
    # 값 바꾸기(시간 · 숫자 값 · 목록 고르기)가 그림에 그대로 반영되는지 - 짝과 같은 값을 주고 다시 맞댑니다. 시간 · 숫자 칸은 그림이 바뀌었는지도 봅니다
    # (닫힌 목록 칸의 글자는 헤드리스 그림에 없어 '바뀜' 을 볼 수 없음 - 짝과 같은지만)
    $t18PickerBefore = Get-T18Picture -Control $t18Subjects['picker']
    $t18NumericBefore = Get-T18Picture -Control $t18Subjects['numeric']
    foreach ($pickerName in @('pickerSubject', 'pickerTwin')) { $script:t18Cells[$pickerName].Value = [datetime]'2026-01-02 21:07:00' }
    foreach ($comboName in @('comboSubject', 'comboTwin')) { $script:t18Cells[$comboName].SelectedIndex = 1 }
    foreach ($numericName in @('numericSubject', 'numericTwin')) { $script:t18Cells[$numericName].Value = 7 }
    Assert-Case 'T18e 끈 채 값 바꾸기 - 그림이 손대지 않은 짝과 화소까지 같음 · 시간 · 숫자 칸의 그림이 값 따라 바뀜' `
      ('[{0}]/{1}/{2}' -f (Get-T18TwinDifference), ((Compare-T18Picture -Left $t18PickerBefore -Right (Get-T18Picture -Control $t18Subjects['picker'])) -cne '같음'),
        ((Compare-T18Picture -Left $t18NumericBefore -Right (Get-T18Picture -Control $t18Subjects['numeric'])) -cne '같음')) '[]/True/True'
    # 켠 채로 핸들을 다시 만듭니다(색 대응은 제품의 색 대응 함수 그대로) - 새 핸들에서도 다시 칠해야 합니다. 안 잠긴 숫자 칸은 대응이 없어 통과(횟수 0)
    foreach ($t18Kind in $t18Kinds) {
      $t18KindPlan = Get-InputRecolorPlan -Kind $t18Kind
      $t18Devices[$t18Kind].EnabledMatrix = $t18KindPlan.EnabledMatrix
      $t18Devices[$t18Kind].DisabledMatrix = $t18KindPlan.DisabledMatrix
      $t18Devices[$t18Kind].BorderColor = $t18KindPlan.BorderColor
      $t18Devices[$t18Kind].Active = $true
    }
    foreach ($t18Kind in $t18Kinds) { $t18ChainBefore[$t18Kind] = $t18Devices[$t18Kind].ChainProc }
    $t18RecreatedOn = @($t18Kinds | Where-Object { Invoke-T18RecreateHandle -Control $t18Targets[$_] }).Count
    $t18ControlProcChangedOn = @($t18Kinds | Where-Object { (Get-T18ControlProc -Control $t18Targets[$_]) -ne $t18ChainBefore[$_] }).Count
    $t18StaleOn = @(Get-T18StaleChains -Kinds $t18Kinds -Devices $t18Devices -Targets $t18Targets)
    Assert-Case 'T18e 켠 채로 핸들을 다시 만듦 - 붙기 직전 창 프로시저를 새로 읽음: 재생성으로 컨트롤 자신의 창 프로시저가 바뀐 종류 셋 / 장치의 붙기 직전 창 프로시저가 새 핸들의 그 값과 다른 종류 없음' `
      ('{0}/[{1}]' -f $t18ControlProcChangedOn, ($t18StaleOn -join ',')) '3/[]'
    $t18OnFacts = foreach ($t18Kind in $t18Kinds) {
      $t18PrintBefore = $t18Devices[$t18Kind].PrintCount
      $t18OnPicture = Get-T18Picture -Control $t18Targets[$t18Kind]
      '{0}={1}/{2}/{3}' -f $t18Kind, ($t18Devices[$t18Kind].IsAttached -and ($t18Devices[$t18Kind].Handle -eq $t18Targets[$t18Kind].Handle)), ($t18Devices[$t18Kind].PrintCount - $t18PrintBefore), (Get-T18PaperText -Picture $t18OnPicture)
    }
    Assert-Case 'T18e 켠 채로 핸들을 다시 만듦 - 새 핸들에 붙음 · 찍으면 다시 칠함(그림 받기 +1 · 바탕 = 입력 바탕) · 안 잠긴 숫자 칸은 통과(+0) · 시간 칸에 기본 글자색 화소' `
      ('{0} | {1} | {2}' -f $t18RecreatedOn, ((@($t18OnFacts)) -join ' '), ((Get-T18ColorCount -Picture (Get-T18Picture -Control $t18Subjects['picker']) -Color $t18DarkText) -gt 0)) `
      '3 | picker=True/1/23,23,26 combo=True/1/23,23,26 numeric=True/0/23,23,26 | True'
    # 뗀 뒤에는 핸들을 다시 만들어도 붙지 않습니다(핸들 생성 구독이 끊김) - 그림은 다시 손대지 않은 짝과 같습니다. 떼기는 켜진 장치도 끄고, 맨 위라 참을 돌려줍니다
    $t18DevicesDetached = @($t18Kinds | ForEach-Object { $t18Devices[$_].Detach() })
    $t18RecreatedDetached = @($t18Kinds | Where-Object { Invoke-T18RecreateHandle -Control $t18Targets[$_] }).Count
    Assert-Case 'T18e 뗀 뒤 핸들을 다시 만듦 - 떼기가 참 셋(맨 위) · 다시 붙지 않음 · 꺼짐 · 그 창의 맨 앞 창 프로시저가 장치가 아님 · 그림이 손대지 않은 짝과 같음' `
      ('{0}/{1}/{2}/{3}/{4}/[{5}]' -f @($t18DevicesDetached | Where-Object { ($_ -is [bool]) -and $_ }).Count, $t18RecreatedDetached, @($t18Kinds | Where-Object { $t18Devices[$_].IsAttached }).Count,
        @($t18Kinds | Where-Object { $t18Devices[$_].Active }).Count, @($t18Kinds | Where-Object { [System.Windows.Forms.NativeWindow]::FromHandle($t18Targets[$_].Handle) -is $t18RecolorType }).Count,
        (Get-T18TwinDifference)) '3/3/0/0/0/[]'
    Assert-Case 'T18e 행 전체 - 장치 오류 없음' ((@($t18Kinds | ForEach-Object { $t18Devices[$_].LastError })) -join '') ''
  } catch { Assert-SectionError -Section 'T18e' -ErrorRecord $_ }

  # ── T18f 창 프로시저의 예외 경계 (설계 7.13 - 그리는 도중의 예외는 창 프로시저 밖으로 나가지 않고 그 장치만 꺼짐) ──
  # 새면 어떻게 되는지는 경로와 예외 모드마다 다릅니다(11-14 내부 검토 - 이 PC 의 System.Windows.Forms 에서 확인): 제품(기본 예외 모드)에서 장치의 창 프로시저 밖으로 샌
  # 예외는 조용히 삼켜져(NativeWindow 의 예외 처리 기본 구현이 비어 있음) 그 칸이 못 그려진 채 남고, 알림 본문 · 핸들 생성 처리기에서 새면 그 컨트롤의 창 프로시저가 받아
  # 모달 오류 창을 띄웁니다. 이 테스트('잡지 않음' 모드)에서는 장치의 창 프로시저에서 샌 예외가 네이티브 경로를 건너며 프로세스를 끝냅니다 - 제품과 경계가 다릅니다.
  # 제품 원문(Get-InputRecolorTypeSource)에서 형식 이름만 바꾸고 그리는 자리 한 곳(색 대응을 그림에 거는 문장 바로 앞)에 예외를 넣은 사본을 컴파일합니다 -
  # 컨트롤이 제 그림을 메모리 비트맵에 그린 뒤 · 화면(또는 받은 DC)에 옮기기 직전에 늘 던집니다. 빈 DC 를 넘겨 일으키는 예외는 안전한 주입이 아닙니다(설계 리뷰):
  # 유효한 비트맵 DC 를 주고 사본이 스스로 던지게 합니다. 사본은 제품 원문의 나머지를 그대로 가지므로, 제품의 받기(catch) · 끄기 · 알림 예약이 깨지면 여기서 드러납니다.
  # 순서: ① 창 프로시저 직접 호출 · ② 알림 본문 직접 호출(둘 다 관리 코드 경로 - 새는 예외가 잡힘) → 통과했을 때만 ③ 실제 그림 받기(DrawToBitmap) · 창 메시지 ·
  #       알림 예약(메시지 루프 · 네이티브 경로 - 창 프로시저에서 새면 프로세스가 끝나고, 알림 본문에서 새면 모달 대화 상자에서 멈춤)
  function New-T18FaultForm {
    # 사본 장치를 붙일 시간 칸 다섯과 손대지 않는 짝 하나(제품의 생성 문장 그대로 · 같은 값 · 핸들 있음)
    if ($script:form) { try { $script:form.Dispose() } catch { } }
    if ($script:cellEditCombo) { try { $script:cellEditCombo.Dispose() } catch { } }
    $script:form = New-Object System.Windows.Forms.Form
    $script:form.Size = New-Object System.Drawing.Size(560, 320)
    $script:form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $script:t18Cells = @{}
    $faultLeft = 20
    foreach ($faultName in @('faultDirectPrint', 'faultDirectPaint', 'faultPrint', 'faultPaint', 'faultNotice', 'faultTwin')) {
      $script:t18Cells[$faultName] = New-SourceControl -SourceName 'dtpUntil' -Parent $script:form -Name $faultName -X $faultLeft -Y 20
      $script:t18Cells[$faultName].Value = [datetime]'2026-01-02 12:34:00'
      $faultLeft += 72
    }
    New-SourceCellEditCombo
    Initialize-AllHandles -Parent $script:form
  }
  function New-T18FaultPainter {
    # 그리는 자리에서 늘 던지는 사본 장치를 그 시간 칸에 붙이고 켭니다(색 대응 · 테두리는 제품의 시간 칸 것 · 알림은 호출부가 준 대리자)
    param($Control, [Action]$Callback)
    $faultPainter = New-Object -TypeName HoneyInputRecolorFaultCopy -ArgumentList $Control, $Control
    $faultPainter.EnabledMatrix = $script:t18FaultPlan.EnabledMatrix
    $faultPainter.DisabledMatrix = $script:t18FaultPlan.DisabledMatrix
    $faultPainter.BorderColor = $script:t18FaultPlan.BorderColor
    $faultPainter.FaultCallback = $Callback
    $faultPainter.Active = $true
    return $faultPainter
  }
  try {
    $t18Source = Get-InputRecolorTypeSource
    $t18DrawSite = 'attributes.SetColorMatrix(matrix);'
    $t18DrawSiteCount = [regex]::Matches($t18Source, [regex]::Escape($t18DrawSite)).Count
    $t18NameCount = [regex]::Matches($t18Source, '\bHoneyInputRecolor\b').Count
    # 원문에 그 자리가 없거나 둘 이상이면 사본을 만들 수 없습니다 - 조용히 건너뛰지 않고 이 행이 실패합니다(원문이 바뀌면 주입 자리를 다시 정해야 함)
    Assert-Case 'T18f 준비 - 장치 원문에 그리는 자리(색 대응을 그림에 거는 문장)가 정확히 1곳 · 형식 이름이 있음(예외를 넣은 사본을 만들 수 있음)' ('{0}/{1}' -f $t18DrawSiteCount, ($t18NameCount -ge 2)) '1/True'
    if (($t18DrawSiteCount -eq 1) -and ($t18NameCount -ge 2)) {
      if (-not ('HoneyInputRecolorFaultCopy' -as [type])) {
        $t18FaultSource = $t18Source.Replace('HoneyInputRecolor', 'HoneyInputRecolorFaultCopy').Replace($t18DrawSite, ('if (width > 0) { throw new InvalidOperationException("그리기 주입 예외"); } ' + $t18DrawSite))
        Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $t18FaultSource
      }
      Reset-ThemeTestState
      Set-HoneyPalette -Theme 'dark'
      New-T18FaultForm
      $script:t18FaultPlan = Get-InputRecolorPlan -Kind 'picker'
      $t18FaultError = 'InvalidOperationException: 그리기 주입 예외'
      $script:t18NoticeCount = 0
      $t18CountCallback = [Action] { $script:t18NoticeCount++ }
      # ① 직접 호출(관리 코드 경로 · 메시지를 돌리지 않음) - 그림 받기(유효한 비트맵 DC) · 화면 그리기. 고장은 한 곳으로 모입니다: 첫 오류를 적고 그 장치를 끕니다.
      #    알림 대리자는 달지 않은 채 일으킵니다 - 대리자가 없으면 알림을 예약하지 않으므로, 아래 ② 가 통과하기 전에는 메시지 루프에 아무것도 올라가지 않습니다
      $t18DirectPrint = New-T18FaultPainter -Control $script:t18Cells['faultDirectPrint'] -Callback $null
      $t18DirectPrintThrown = Invoke-T18WndProc -Painter $t18DirectPrint -PrintClient
      Assert-Case 'T18f 그림 받기(창 프로시저 직접 호출 · 유효한 비트맵 DC) - 그리는 자리의 예외가 밖으로 나오지 않음 · 장치가 꺼짐 · 첫 오류(형식 이름: 메시지) · 다시 칠한 횟수 0' `
        ('[{0}]/{1}/{2}/{3}/{4}' -f $t18DirectPrintThrown, $t18DirectPrint.Active, $t18DirectPrint.LastError, $t18DirectPrint.PaintCount, $t18DirectPrint.PrintCount) ('[]/False/' + $t18FaultError + '/0/0')
      $t18DirectPaint = New-T18FaultPainter -Control $script:t18Cells['faultDirectPaint'] -Callback $null
      $t18DirectPaintThrown = Invoke-T18WndProc -Painter $t18DirectPaint
      Assert-Case 'T18f 화면 그리기(창 프로시저 직접 호출 · WM_PAINT) - 예외가 밖으로 나오지 않음 · 장치가 꺼짐 · 첫 오류 · 다시 칠한 횟수 0' `
        ('[{0}]/{1}/{2}/{3}/{4}' -f $t18DirectPaintThrown, $t18DirectPaint.Active, $t18DirectPaint.LastError, $t18DirectPaint.PaintCount, $t18DirectPaint.PrintCount) ('[]/False/' + $t18FaultError + '/0/0')
      # ② 알림 본문 직접 호출(관리 코드 경로): 고장 난 장치에 대리자를 달고 본문을 직접 부릅니다 - 세기만 하는 대리자 1번, 던지는 대리자 1번. 대리자 안의 예외는 본문이 받아야 합니다.
      #    이 확인은 메시지를 돌리기 전에 해야 합니다: 본문의 받기가 없으면 메시지 루프에서 난 그 예외를 그 컨트롤의 창 프로시저가 받아 처리기 예외 대화 상자(모달)를 띄웁니다 -
      #    장치가 얹힌 창에서는 컨트롤의 창 프로시저가 '잡아서 대화 상자로 돌리는' 쪽으로 불려, 이 테스트의 예외 모드(잡지 않음)가 그 아래에는 닿지 않습니다
      #    (11-14 실측: 본문의 받기를 없앤 변이에서 던지는 대리자를 메시지 루프로 돌리자 이 테스트가 그 대화 상자에서 멈췄음). 본문이 원문에 없으면 그 사실이 실패로 드러납니다
      $t18NotifyMethod = $t18DirectPrint.GetType().GetMethod('NotifyFault', [System.Reflection.BindingFlags]'NonPublic, Instance')
      $t18NotifyThrown = '알림 본문(NotifyFault)을 찾지 못함'
      if ($t18NotifyMethod) {
        $t18NotifyThrown = ''
        $t18DirectPrint.FaultCallback = $t18CountCallback
        try { [void]$t18NotifyMethod.Invoke($t18DirectPrint, $null) } catch { $t18NotifyThrown += ('세는 대리자: ' + $_.Exception.GetBaseException().Message) }
        $t18DirectPrint.FaultCallback = [Action] { $script:t18NoticeCount++; throw '알림 주입 예외' }
        try { [void]$t18NotifyMethod.Invoke($t18DirectPrint, $null) } catch { $t18NotifyThrown += ('던지는 대리자: ' + $_.Exception.GetBaseException().Message) }
        $t18DirectPrint.FaultCallback = $null
      }
      Assert-Case 'T18f 알림 본문(직접 호출) - 대리자를 부름(세는 대리자 1번 + 던지는 대리자 1번 = 2) · 대리자 안의 예외가 밖으로 나오지 않음' ('[{0}]/{1}' -f $t18NotifyThrown, $script:t18NoticeCount) '[]/2'
      $t18FaultSafe = ($t18DirectPrintThrown -eq '') -and (-not $t18DirectPrint.Active) -and ($t18DirectPaintThrown -eq '') -and (-not $t18DirectPaint.Active) -and ($t18NotifyThrown -eq '')
      if (-not $t18FaultSafe) {
        # 직접 호출에서 예외가 샜거나 장치가 꺼지지 않았으면 메시지 루프 · 네이티브 경로를 부르지 않습니다 - 창 프로시저에서 새면 이 테스트 프로세스가 출력 없이 끝나고,
        # 알림 본문에서 새면 모달 대화 상자에서 멈춥니다
        Assert-Case 'T18f 메시지 루프 · 네이티브 경로(실제 그림 받기 · 창 메시지 · 알림 예약) - 직접 호출이 통과하지 못해 부르지 않음' '부르지 않음' '부름'
      } else {
        # ③ 실제 그림 받기(DrawToBitmap): 고장 뒤 그 메시지는 받은 DC 그대로 넘기기(Pass)로 붙기 직전의 창 프로시저에 넘어가(설계 7.14 - 여기서는 컨트롤 자신)
        #    그림이 손대지 않은 짝과 같아야 합니다.
        #    알림은 그리는 도중이 아니라 메시지를 돌린 뒤 정확히 1번 - 꺼진 채 다시 찍어도, 다시 켜서 또 고장 나도 늘지 않습니다(장치마다 한 번 · 첫 오류 유지)
        $script:t18NoticeCount = 0
        $t18TwinPicture = Get-T18Picture -Control $script:t18Cells['faultTwin']
        $t18Print = New-T18FaultPainter -Control $script:t18Cells['faultPrint'] -Callback $t18CountCallback
        $t18FirstPicture = Get-T18Picture -Control $script:t18Cells['faultPrint']
        $t18AfterFirst = '{0}/{1}/{2}' -f $t18Print.Active, $t18Print.LastError, $script:t18NoticeCount
        [System.Windows.Forms.Application]::DoEvents()
        Assert-Case 'T18f 그림 받기(DrawToBitmap) - 예외가 테스트로 올라오지 않음 · 꺼짐 · 첫 오류 · 그리는 도중 알림 0 → 메시지를 돌린 뒤 정확히 1번 · 그 그림 = 손대지 않은 짝의 그림(원래 창 프로시저가 그림)' `
          ('{0}>{1}/{2}' -f $t18AfterFirst, $script:t18NoticeCount, (Compare-T18Picture -Left $t18TwinPicture -Right $t18FirstPicture)) ('False/' + $t18FaultError + '/0>1/같음')
        $t18SecondPicture = Get-T18Picture -Control $script:t18Cells['faultPrint']
        [System.Windows.Forms.Application]::DoEvents()
        $t18NoticeAfterSecond = $script:t18NoticeCount
        $t18Print.Active = $true
        $t18ThirdPicture = Get-T18Picture -Control $script:t18Cells['faultPrint']
        [System.Windows.Forms.Application]::DoEvents()
        Assert-Case 'T18f 한 번 더 - 꺼진 채 다시 찍음: 알림 1번 그대로 / 다시 켜서 또 고장: 다시 꺼짐 · 첫 오류 그대로 · 알림 1번 그대로 · 두 그림 모두 짝과 같음' `
          ('{0} / {1}/{2}/{3} · {4}/{5}' -f $t18NoticeAfterSecond, $t18Print.Active, $t18Print.LastError, $script:t18NoticeCount, (Compare-T18Picture -Left $t18TwinPicture -Right $t18SecondPicture),
            (Compare-T18Picture -Left $t18TwinPicture -Right $t18ThirdPicture)) ('1 / False/' + $t18FaultError + '/1 · 같음/같음')
        # 화면 그리기 메시지를 컨트롤 창에 직접 보냄: 실패한 화면 그리기는 그 메시지를 거기서 끝내고 다시 그리기를 요청합니다(다음 WM_PAINT 는 꺼진 장치의 넘기기(Pass)로 붙기 직전의 창 프로시저가 그림 -
        # 보이지 않는 창이라 그 다음 그리기는 여기서 볼 수 없음: 요청 문장은 G13 이 원문으로 봄)
        $script:t18NoticeCount = 0
        $t18Paint = New-T18FaultPainter -Control $script:t18Cells['faultPaint'] -Callback $t18CountCallback
        Send-T18Paint -Painter $t18Paint
        [System.Windows.Forms.Application]::DoEvents()
        Assert-Case 'T18f 화면 그리기(컨트롤 창에 WM_PAINT 를 직접 보냄) - 예외가 올라오지 않음 · 꺼짐 · 첫 오류 · 다시 칠한 횟수 0 · 메시지를 돌린 뒤 알림 1번' `
          ('{0}/{1}/{2}/{3}/{4}' -f $t18Paint.Active, $t18Paint.LastError, $t18Paint.PaintCount, $t18Paint.PrintCount, $script:t18NoticeCount) ('False/' + $t18FaultError + '/0/0/1')
        # 제품의 고장 알림까지 끝에서 끝으로: 사본 장치의 알림 대리자 = 제품이 다는 것과 같은 한 줄 · 제품의 장치 목록에 그 장치 → 메시지 루프에서 알림 함수가 첫 오류를 [경고] 1줄로
        $script:inputRecolorError = $null
        $script:logLines.Clear()
        $t18Notice = New-T18FaultPainter -Control $script:t18Cells['faultNotice'] -Callback ([Action] { Invoke-InputRecolorFaultNotice })
        $script:inputRecolorPainters = @(@{ Kind = 'picker'; Painter = $t18Notice })
        [void](Get-T18Picture -Control $script:t18Cells['faultNotice'])
        $t18LinesBeforePump = $script:logLines.Count
        [System.Windows.Forms.Application]::DoEvents()
        $t18LinesAfterPump = $script:logLines.Count
        $t18Notice.Active = $true
        [void](Get-T18Picture -Control $script:t18Cells['faultNotice'])
        [System.Windows.Forms.Application]::DoEvents()
        Assert-Case 'T18f 제품의 고장 알림까지(사본 장치 → 메시지 루프 → 알림 함수) - 그리는 도중 로그 0 → 메시지를 돌린 뒤 [경고] 1줄(다시 칠하지 못함 문구 + 장치의 첫 오류) · 원인 보관 · 다시 고장 나도 1줄 그대로' `
          ('{0}>{1}>{2}/[{3}]/{4}' -f $t18LinesBeforePump, $t18LinesAfterPump, $script:logLines.Count, ($script:logLines -join ' / '), [string]$script:inputRecolorError) `
          ('0>1>1/[' + $t18PaintWarning + $t18FaultError + ']/' + $t18FaultError)
      }
      # 정리 - 떼기의 반환값(참/거짓)은 이 정리에서 보지 않습니다(맨 위일 때의 참은 T18c · T18e, 맨 위가 아닐 때의 거짓은 T18g 가 봄)
      foreach ($t18FaultPainter in @($t18DirectPrint, $t18DirectPaint, $t18Print, $t18Paint, $t18Notice)) { if ($t18FaultPainter) { [void]$t18FaultPainter.Detach() } }
    }
  } catch { Assert-SectionError -Section 'T18f' -ErrorRecord $_ } finally {
    $script:inputRecolorPainters = $null
    $script:inputRecolorError = $null
    $script:inputRecolorPendingWarning = $null
    Set-HoneyPalette -Theme 'light'
  }

  # ── T18g 사이의 서브클래스 보존 (11-14 설계 7.14 '테스트' + 설계 리뷰 조건 - 헤드리스 탐침과 같은 방법) ──
  # 말풍선(ToolTip)을 숫자 칸에 걸면 안쪽 글자 칸이 도구로 등록되고, comctl32 가 그 창을 서브클래스해(마스터 창 프로시저) 마우스를 중계받습니다. 장치가 그 위에 붙으면
  # (핸들이 있는 칸에 나중에 붙음 - 라이트로 시작해 설정 그룹을 펼친 뒤 아이콘으로 처음 다크) 장치가 맡지 않는 메시지와 제 그림 받기는 붙기 직전의 창 프로시저(그 마스터)로
  # 가야 하고, 떼면 그 마스터로 다시 이어져야 합니다(기본 넘기기 · NativeWindow 의 되돌림은 컨트롤 자신으로 바로 가 그 사이를 건너뜀 - 설계 7.14 원인).
  # 행마다 헤드리스 폼(화면에 띄우지 않음)에 숫자 칸 하나(Z 계수기는 셋 - 제품 횟수 칸 numCount 의 생성 문장 그대로)를 만들고, 셀 수 있는 서브클래스(위 '창 프로시저 사슬 도구')를 얹고,
  # 장치는 이 테스트가 이미 올린 제품 형식(HoneyInputRecolor - 제품 원문 그대로)을 직접 만듭니다. 켤 때는 두 상태 모두 단위 색 대응(그대로)을 넣습니다 - 색이 아니라 넘기기를 봅니다.
  # 메시지는 창에 직접 보냅니다(SendMessage - 맨 위 창 프로시저부터). 메시지를 보내기 전에 장치의 사슬을 먼저 봅니다 - 넘기기가 자신을 가리키면 메시지 하나로 프로세스가
  # 죽습니다(같은 변이는 앞의 문지기 사슬 행이 하네스 행보다 먼저 잡음). 맨 위 창 프로시저가 comctl32 가 아니면(이 PC 의 comctl32 가 말풍선 중계를 그 자리에 얹지 않음)
  # 그 행은 건너뛰지 않고 실패로 알립니다 - 대역을 얹을 마스터가 없습니다
  $t18WatchMessage = 0x8123
  function New-T18ChainForm {
    # 헤드리스 폼 + 숫자 칸 하나(제품 numCount 의 생성 문장 · 속성 대입문 그대로) + 말풍선 객체. -Tip 이면 말풍선을 핸들 전에 걸고, -Handles 면 핸들을 만듭니다.
    # hashtable 1개 = Form · Numeric · Edit(안쪽 글자 칸 - 장치가 붙는 창) · Tip
    param([switch]$Tip, [switch]$Handles)
    $chainForm = New-Object System.Windows.Forms.Form
    $chainForm.Size = New-Object System.Drawing.Size(300, 200)
    $chainNumeric = New-SourceControl -SourceName 'numCount' -Parent $chainForm -Name 'chainNumeric' -X 20 -Y 20
    $chainTip = New-Object System.Windows.Forms.ToolTip
    if ($Tip) { $chainTip.SetToolTip($chainNumeric, '사슬 시험 말풍선') }
    if ($Handles) { Initialize-AllHandles -Parent $chainForm }
    return @{ Form = $chainForm; Numeric = $chainNumeric; Edit = (Get-T18NumericEdit -Numeric $chainNumeric); Tip = $chainTip }
  }
  function Remove-T18ChainForm {
    # 행의 폼과 말풍선을 정리합니다(창이 없어지는 메시지가 장치 · 셀 수 있는 서브클래스를 지나감 - 그 객체들은 $t18ChainKeep 에 잡혀 있음)
    param($Chain)
    if ($null -eq $Chain) { return }
    try { $Chain.Form.Dispose() } catch { }
    try { $Chain.Tip.Dispose() } catch { }
  }
  function Send-T18Watch {
    # 아무도 처리하지 않는 메시지 하나를 그 창에 직접 보냅니다(맨 위 창 프로시저부터)
    param($Control)
    [void][HoneyThemeTest.ChainNative]::SendMessage($Control.Handle, $script:t18WatchMessage, [IntPtr]::Zero, [IntPtr]::Zero)
  }
  function Send-T18PrintClient {
    # 유효한 메모리 비트맵 DC 를 실은 그림 받기(WM_PRINTCLIENT · PRF_CLIENT | PRF_ERASEBKGND)를 그 창에 직접 보냅니다
    param($Control)
    $printBitmap = New-Object System.Drawing.Bitmap([Math]::Max(1, $Control.Width), [Math]::Max(1, $Control.Height))
    $printGraphics = [System.Drawing.Graphics]::FromImage($printBitmap)
    try {
      $printDc = $printGraphics.GetHdc()
      try { [void][HoneyThemeTest.ChainNative]::SendMessage($Control.Handle, 0x0318, $printDc, [IntPtr]12) } finally { $printGraphics.ReleaseHdc($printDc) }
    } finally {
      $printGraphics.Dispose()
      $printBitmap.Dispose()
    }
  }
  function Get-T18TextLength {
    # 글자 칸에 WM_GETTEXTLENGTH 를 직접 보내 받은 결과(글자 수) - 넘기기가 아래 창 프로시저의 결과를 그대로 돌려주는지 봅니다(결과를 버리면 0)
    param($Control)
    return ([HoneyThemeTest.ChainNative]::SendMessage($Control.Handle, 0x000E, [IntPtr]::Zero, [IntPtr]::Zero)).ToInt64()
  }
  function Get-T18FrontProc {
    # 그 창의 맨 위 창 프로시저
    param($Control)
    return [HoneyThemeTest.ChainNative]::WindowProcOf($Control.Handle)
  }
  function Get-T18ProcModule {
    # 창 프로시저 주소가 든 모듈의 파일 이름('comctl32.dll' 등 - 관리 코드 대리자의 주소는 '(모듈 없음)')
    param([IntPtr]$Proc)
    return [HoneyThemeTest.ChainNative]::ModuleNameOf($Proc)
  }
  function Get-T18TipToolCount {
    # 말풍선 창에 등록된 도구 수(TTM_GETTOOLCOUNT 0x040D - 말풍선 객체의 창 window 필드는 리플렉션). 말풍선 창이 없으면 -1
    param($Tip)
    $tipWindowField = [System.Windows.Forms.ToolTip].GetField('window', [System.Reflection.BindingFlags]'NonPublic, Instance')
    if ($null -eq $tipWindowField) { return -1 }
    $tipWindow = $tipWindowField.GetValue($Tip)
    if (($null -eq $tipWindow) -or ($tipWindow.Handle -eq [IntPtr]::Zero)) { return -1 }
    return ([HoneyThemeTest.ChainNative]::SendMessage($tipWindow.Handle, 0x040D, [IntPtr]::Zero, [IntPtr]::Zero)).ToInt64()
  }
  function Test-T18Retained {
    # 그 장치가 제품 장치 형식의 정적 목록(retained - 떼지 못하고 붙은 채 남은 장치를 붙잡아 두는 곳)에 들어 있는가(리플렉션). 필드를 찾지 못하면 그 글자
    param($Device)
    $retainedType = 'HoneyInputRecolor' -as [type]
    if ($null -eq $retainedType) { return '장치 형식 없음' }
    $retainedField = $retainedType.GetField('retained', [System.Reflection.BindingFlags]'NonPublic, Static')
    if ($null -eq $retainedField) { return 'retained 필드 없음' }
    return $retainedField.GetValue($null).Contains($Device)
  }
  function Set-T18ChainOn {
    # 장치를 켭니다 - 두 상태 모두 단위 색 대응(그대로) · 테두리 없음
    param($Device)
    $Device.EnabledMatrix = New-Object System.Drawing.Imaging.ColorMatrix
    $Device.DisabledMatrix = New-Object System.Drawing.Imaging.ColorMatrix
    $Device.Active = $true
  }
  function Test-T18ChainSound {
    # 메시지를 보내기 전의 문지기: 붙음 · 붙기 직전 창 프로시저가 0 도 자신도 아님. 거짓이면 그 행은 메시지를 보내지 않습니다
    param($Device)
    return ($Device.IsAttached -and ($Device.ChainProc -ne [IntPtr]::Zero) -and ($Device.ChainProc -ne $Device.SelfProc))
  }
  function Restore-T18FrontProc {
    # 사슬이 어긋난 장치를 창 프로시저에서 뺍니다(장치를 붙이기 전에 읽어 둔 맨 위로 되돌림 - 실패 갈래에서만). 그대로 두면 폼을 정리할 때 오는 메시지로 프로세스가 죽을 수 있습니다
    param($Control, [IntPtr]$Proc)
    if ($Proc -ne [IntPtr]::Zero) { [void][HoneyThemeTest.ChainNative]::SetWindowLongPtr($Control.Handle, -4, $Proc) }
  }

  # X - 핸들이 있는 칸에 나중에 붙음(라이트 시작 뒤 아이콘으로 처음 다크): 말풍선 중계 위에 장치. 셀 수 있는 comctl32 서브클래스는 그 중계와 같은 마스터에 들어가
  # 장치 아래에 있습니다 - 기본 넘기기(base.WndProc)면 메시지가 컨트롤로 바로 가 셈이 오르지 않습니다
  $t18X = $null
  try {
    $t18X = New-T18ChainForm -Tip -Handles
    $t18XEdit = $t18X.Edit
    $t18XFrontBefore = Get-T18FrontProc -Control $t18XEdit
    $t18XModule = Get-T18ProcModule -Proc $t18XFrontBefore
    Assert-Case 'T18g X 준비 - 말풍선이 걸린 숫자 칸(핸들 있음)의 글자 칸: 맨 위 창 프로시저 = comctl32(말풍선 중계의 마스터)' $t18XModule 'comctl32.dll'
    if ($t18XModule -eq 'comctl32.dll') {
      $t18XCounter = New-Object -TypeName HoneyThemeTest.ComctlCounter -ArgumentList ([HoneyThemeTest.ChainNative]::ModuleOf($t18XFrontBefore)), $t18XEdit.Handle, $t18WatchMessage
      $script:t18ChainKeep.Add($t18XCounter)
      Send-T18Watch -Control $t18XEdit
      # 장치 전의 기준(대역 확인): 셀 수 있는 서브클래스가 메시지를 받고, 글자 수 결과가 0 이 아님 - 거짓이면 아래 셈 · 결과 행은 장치와 무관하게 갈립니다
      $t18XLength = Get-T18TextLength -Control $t18XEdit
      Assert-Case 'T18g X 셀 수 있는 서브클래스(같은 comctl32 의 SetWindowSubclass) - 얹힘 · 맨 위 창 프로시저 그대로(이미 있는 마스터에 들어감) · 장치 전 메시지 1 → 셈 1 · 장치 전 글자 수 결과가 0 아님' `
        ('{0}/{1}/{2}/{3}' -f $t18XCounter.Installed, ((Get-T18FrontProc -Control $t18XEdit) -eq $t18XFrontBefore), $t18XCounter.Count, ($t18XLength -gt 0)) 'True/True/1/True'
      $t18XDevice = New-Object -TypeName HoneyInputRecolor -ArgumentList $t18X.Numeric, $t18XEdit
      $t18XFrontAfter = Get-T18FrontProc -Control $t18XEdit
      # 메시지를 보내기 전(설계 리뷰 조건): 붙기 직전 창 프로시저를 AssignHandle 뒤에 읽으면 장치 자신이라 첫 메시지에서 넘기기가 끝없이 자신을 부릅니다
      Assert-Case 'T18g X 장치를 붙임(메시지를 보내기 전) - 붙음 · 붙기 직전 창 프로시저(ChainProc) = 장치 전 맨 위 · 그 모듈 comctl32 · 자기 창 프로시저(SelfProc) = 지금 맨 위 · 둘이 다름 · 오류 없음' `
        ('{0}/{1}/{2}/{3}/{4}/[{5}]' -f $t18XDevice.IsAttached, ($t18XDevice.ChainProc -eq $t18XFrontBefore), (Get-T18ProcModule -Proc $t18XDevice.ChainProc),
          ($t18XDevice.SelfProc -eq $t18XFrontAfter), ($t18XDevice.SelfProc -ne $t18XDevice.ChainProc), $t18XDevice.LastError) 'True/True/comctl32.dll/True/True/[]'
      if (Test-T18ChainSound -Device $t18XDevice) {
        Send-T18Watch -Control $t18XEdit
        Assert-Case 'T18g X 꺼진 장치 - 아무도 처리하지 않는 메시지가 장치 아래의 comctl32 서브클래스에 닿음(셈 1 → 2) · 글자 수 결과 = 장치 전(넘기기가 결과를 그대로 돌려줌)' `
          ('{0}/{1}' -f $t18XCounter.Count, ((Get-T18TextLength -Control $t18XEdit) -eq $t18XLength)) '2/True'
        Set-T18ChainOn -Device $t18XDevice
        Send-T18Watch -Control $t18XEdit
        Assert-Case 'T18g X 켠 장치 - 그림이 아닌 메시지도 넘김(셈 2 → 3) · 글자 수 결과 = 장치 전' ('{0}/{1}' -f $t18XCounter.Count, ((Get-T18TextLength -Control $t18XEdit) -eq $t18XLength)) '3/True'
        $t18XPrintsBefore = $t18XCounter.PrintCount
        Send-T18PrintClient -Control $t18XEdit
        Assert-Case 'T18g X 켠 장치 + 그림 받기(유효한 비트맵 DC) - 장치가 다시 칠함(그림 받기 1) · 장치 안에서 컨트롤에 보낸 그림 받기가 comctl32 서브클래스에 닿음(+1) · 오류 없음' `
          ('{0}/+{1}/[{2}]' -f $t18XDevice.PrintCount, ($t18XCounter.PrintCount - $t18XPrintsBefore), $t18XDevice.LastError) '1/+1/[]'
        $t18XDetached = $t18XDevice.Detach()
        $t18XFrontDetached = Get-T18FrontProc -Control $t18XEdit
        Send-T18Watch -Control $t18XEdit
        Assert-Case 'T18g X 떼기(장치가 맨 위) - 참 · 맨 위 창 프로시저 = 장치 전 맨 위(comctl32 중계로 다시 이어짐) · 붙어 있지 않음 · 꺼짐 · 메시지가 comctl32 서브클래스에 닿음(셈 3 → 4) · 정적 목록(retained)에 안 들어감' `
          ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $t18XDetached, ($t18XFrontDetached -eq $t18XFrontBefore), (Get-T18ProcModule -Proc $t18XFrontDetached), $t18XDevice.IsAttached, $t18XDevice.Active, $t18XCounter.Count,
            (Test-T18Retained -Device $t18XDevice)) 'True/True/comctl32.dll/False/False/4/False'
      } else { Restore-T18FrontProc -Control $t18XEdit -Proc $t18XFrontBefore }
    }
  } catch { Assert-SectionError -Section 'T18g X' -ErrorRecord $_ } finally { Remove-T18ChainForm -Chain $t18X }

  # Y - 핸들이 생기기 전에 붙음(다크 시작 · 그 칸을 아직 그린 적 없음): 핸들이 생길 때 붙고, 말풍선 중계는 그 뒤에 장치 위로 얹힙니다(중계가 먼저 받음 - 영향 없음).
  # 붙기가 핸들 만들기 안(핸들 생성 처리기)에서 일어나 그 뒤의 만들기 메시지가 이미 장치를 지나므로, 이 행에서는 '메시지 전' 사슬 확인을 할 수 없습니다(앞의 문지기가 먼저 봄).
  # 셀 수 있는 서브클래스는 장치 위(같은 마스터)라 장치가 메시지를 아래로 넘기는지는 셈으로 볼 수 없어, 글자 수 결과(아래의 컨트롤이 답함)로 봅니다 - 기대값은 숫자 칸의 값 글자 수
  # (핸들 전에 값에서 읽음 - 창에 묻지 않음)
  $t18Y = $null
  try {
    $t18Y = New-T18ChainForm -Tip
    $t18YLength = [long]([string]$t18Y.Numeric.Value).Length
    $t18YDevice = New-Object -TypeName HoneyInputRecolor -ArgumentList $t18Y.Numeric, $t18Y.Edit
    $t18YBeforeHandles = '{0}/{1}' -f $t18YDevice.IsAttached, $t18Y.Edit.IsHandleCreated
    Initialize-AllHandles -Parent $t18Y.Form
    $t18YFront = Get-T18FrontProc -Control $t18Y.Edit
    $t18YModule = Get-T18ProcModule -Proc $t18YFront
    Assert-Case 'T18g Y 핸들 전 장치 - 만들 때 붙지 않음 · 핸들 없음 / 핸들이 생기면 붙음 · 붙기 직전 창 프로시저가 0 도 자신도 아님 · 맨 위 = comctl32(중계가 장치 위) · 장치는 맨 위 아님 · 오류 없음' `
      ('{0} | {1}/{2}/{3}/{4}/{5}/[{6}]' -f $t18YBeforeHandles, $t18YDevice.IsAttached, ($t18YDevice.ChainProc -ne [IntPtr]::Zero), ($t18YDevice.ChainProc -ne $t18YDevice.SelfProc), $t18YModule,
        ($t18YFront -ne $t18YDevice.SelfProc), $t18YDevice.LastError) 'False/False | True/True/True/comctl32.dll/True/[]'
    if ((Test-T18ChainSound -Device $t18YDevice) -and ($t18YModule -eq 'comctl32.dll')) {
      $t18YCounter = New-Object -TypeName HoneyThemeTest.ComctlCounter -ArgumentList ([HoneyThemeTest.ChainNative]::ModuleOf($t18YFront)), $t18Y.Edit.Handle, $t18WatchMessage
      $script:t18ChainKeep.Add($t18YCounter)
      Send-T18Watch -Control $t18Y.Edit
      $t18YOffCount = $t18YCounter.Count
      $t18YOffLength = Get-T18TextLength -Control $t18Y.Edit
      Set-T18ChainOn -Device $t18YDevice
      Send-T18Watch -Control $t18Y.Edit
      $t18YOnLength = Get-T18TextLength -Control $t18Y.Edit
      Assert-Case 'T18g Y 셀 수 있는 서브클래스(장치 위의 comctl32 마스터) - 얹힘 · 꺼진 장치에서 메시지 1 → 셈 1 · 켠 장치에서 1 더 → 2 / 글자 수 결과(장치를 지나 아래 컨트롤이 답함) = 값의 글자 수(0 아님) - 꺼진 · 켠 장치 / 장치 오류 없음' `
        ('{0}/{1}/{2} | {3}/{4}/{5} | [{6}]' -f $t18YCounter.Installed, $t18YOffCount, $t18YCounter.Count, ($t18YLength -gt 0), ($t18YOffLength -eq $t18YLength), ($t18YOnLength -eq $t18YLength), $t18YDevice.LastError) `
        'True/1/2 | True/True/True | []'
    }
  } catch { Assert-SectionError -Section 'T18g Y' -ErrorRecord $_ } finally { Remove-T18ChainForm -Chain $t18Y }

  # Z - 장치 아래의 중계가 마지막으로 빠짐(설계 리뷰 P2): 핸들 → 원시 서브클래스 → 말풍선 등록(중계가 원시 위) → 장치 → 켬 → 말풍선 등록을 모두 지움.
  # 숫자 칸에 건 말풍선은 안쪽 글자 칸 · 위아래 단추도 도구로 따로 등록합니다(도구 셋). 숫자 칸만 지우면(SetToolTip(숫자 칸, 없음)) 그 칸의 도구만 빠지고 글자 칸의 중계
  # 등록은 그대로 남습니다(11-14 구현 리뷰 · 헤드리스 확인: 도구 3 → 2 · 글자 칸의 말풍선 글자 그대로 - 예전 이 행은 그렇게 지워 지우기 전과 같은 사슬에서 통과했음).
  # 그래서 모두 지우고(RemoveAll) 지운 것이 실제로 빠졌는지(도구 0 · 글자 칸의 말풍선 글자 없음)를 함께 봅니다. 지운 뒤에도 장치가 맨 위에 남고(comctl32 마스터는
  # 맨 위가 아니라 빠지지 못하고 통과 역할) 메시지와 장치 안의 그림 받기가 원시까지 닿아야 합니다. 마스터의 등록이 실제로 비는 것은 아래 'Z 계수기' 가 셈으로 봅니다
  $t18Z = $null
  try {
    $t18Z = New-T18ChainForm -Handles
    $t18ZEdit = $t18Z.Edit
    $t18ZRaw = New-Object -TypeName HoneyThemeTest.RawCounter -ArgumentList $t18ZEdit.Handle, $t18WatchMessage
    $script:t18ChainKeep.Add($t18ZRaw)
    $t18Z.Tip.SetToolTip($t18Z.Numeric, '사슬 시험 말풍선')
    $t18ZFrontBefore = Get-T18FrontProc -Control $t18ZEdit
    $t18ZModule = Get-T18ProcModule -Proc $t18ZFrontBefore
    Assert-Case 'T18g Z 준비 - 핸들 있는 칸에 원시 서브클래스를 얹은 뒤 말풍선 등록: 맨 위 = comctl32(중계가 원시 위) · 말풍선 도구 3(숫자 칸 · 글자 칸 · 위아래 단추) · 글자 칸에도 말풍선 글자' `
      ('{0}/{1}/{2}' -f $t18ZModule, (Get-T18TipToolCount -Tip $t18Z.Tip), ($t18Z.Tip.GetToolTip($t18ZEdit) -ceq '사슬 시험 말풍선')) 'comctl32.dll/3/True'
    if ($t18ZModule -eq 'comctl32.dll') {
      $t18ZDevice = New-Object -TypeName HoneyInputRecolor -ArgumentList $t18Z.Numeric, $t18ZEdit
      $t18ZSound = (Test-T18ChainSound -Device $t18ZDevice) -and ($t18ZDevice.ChainProc -eq $t18ZFrontBefore)
      if ($t18ZSound) {
        Set-T18ChainOn -Device $t18ZDevice
        Send-T18Watch -Control $t18ZEdit
        $t18ZBeforeRemoval = $t18ZRaw.Count
        $t18Z.Tip.RemoveAll()
        $t18ZRemoved = '{0}/{1}' -f (Get-T18TipToolCount -Tip $t18Z.Tip), ($t18Z.Tip.GetToolTip($t18ZEdit) -ceq '')
        $t18ZFrontRemoved = Get-T18FrontProc -Control $t18ZEdit
        Send-T18Watch -Control $t18ZEdit
        Send-T18Watch -Control $t18ZEdit
        $t18ZRawPrints = $t18ZRaw.PrintCount
        $t18ZDevicePrints = $t18ZDevice.PrintCount
        Send-T18PrintClient -Control $t18ZEdit
        $t18ZText = '{0} | {1} | {2}/{3}/{4} | +{5}/+{6}/[{7}]' -f $t18ZBeforeRemoval, $t18ZRemoved, ($t18ZFrontRemoved -eq $t18ZDevice.SelfProc), $t18ZDevice.IsAttached, $t18ZRaw.Count,
          ($t18ZDevice.PrintCount - $t18ZDevicePrints), ($t18ZRaw.PrintCount - $t18ZRawPrints), $t18ZDevice.LastError
      } else {
        $t18ZText = '사슬 어긋남(메시지를 보내지 않음): 붙음 {0} · 붙기 직전 = 장치 전 맨 위 {1} · 자기와 다름 {2}' -f $t18ZDevice.IsAttached, ($t18ZDevice.ChainProc -eq $t18ZFrontBefore), ($t18ZDevice.ChainProc -ne $t18ZDevice.SelfProc)
        Restore-T18FrontProc -Control $t18ZEdit -Proc $t18ZFrontBefore
      }
      Assert-Case 'T18g Z 말풍선 등록을 모두 지움(RemoveAll · 켠 장치가 중계 위 · 사슬은 메시지 전에 확인) - 지우기 전 메시지가 원시에 닿음(1) | 지운 것이 실제로 빠짐: 도구 0 · 글자 칸의 말풍선 글자 없음 | 지운 뒤 장치가 맨 위 그대로 · 붙음 · 메시지 둘이 원시에 닿음(3) | 그림 받기: 장치가 다시 칠함(+1) · 장치 안의 그림 받기가 원시에 닿음(+1) · 오류 없음' `
        $t18ZText '1 | 0/True | True/True/3 | +1/+1/[]'
    }
  } catch { Assert-SectionError -Section 'T18g Z' -ErrorRecord $_ } finally { Remove-T18ChainForm -Chain $t18Z }

  # Z 계수기 - 장치 아래 마스터의 마지막 등록이 실제로 빠지는 것을 셈으로(설계 리뷰 P2 를 결정적으로 - 11-14 구현 리뷰): 셀 수 있는 comctl32 서브클래스를 원시 위에
  # 얹으면 그것이 그 창 마스터의 유일한 등록입니다(말풍선 중계와 같은 마스터에 들어가는 대역). comctl32 모듈은 같은 폼에서 말풍선을 건 숫자 칸의 중계 마스터에서 얻고,
  # 시험하는 두 칸(제품 횟수 칸의 생성 문장 그대로)에는 말풍선을 걸지 않습니다. 대조(장치 없음): 지우면 마스터가 스스로 빠집니다(맨 위 = 원시 - comctl32 는
  # 맨 위일 때만 빠짐). 장치 위: 지운 뒤 마스터가 통과 역할로 남아 장치가 맨 위 그대로이고, 계수기에는 더 안 닿고(사슬에서 빠짐 - 지우기 전과 다름) 메시지와
  # 장치 안의 그림 받기는 원시까지 닿아야 합니다
  $t18W = $null
  try {
    $t18W = New-T18ChainForm -Tip -Handles
    $t18WRelay = Get-T18FrontProc -Control $t18W.Edit
    $t18WPlainEdit = Get-T18NumericEdit -Numeric (New-SourceControl -SourceName 'numCount' -Parent $t18W.Form -Name 'chainPlain' -X 20 -Y 60)
    $t18WNumeric = New-SourceControl -SourceName 'numCount' -Parent $t18W.Form -Name 'chainSubject' -X 20 -Y 100
    $t18WEdit = Get-T18NumericEdit -Numeric $t18WNumeric
    Initialize-AllHandles -Parent $t18W.Form
    $t18WModule = Get-T18ProcModule -Proc $t18WRelay
    Assert-Case 'T18g Z 계수기 준비 - 말풍선을 건 칸의 글자 칸 맨 위 = comctl32(모듈을 얻는 곳) · 말풍선 없는 두 칸의 글자 칸 맨 위는 comctl32 아님(마스터 없음)' `
      ('{0}/{1}/{2}' -f $t18WModule, ((Get-T18ProcModule -Proc (Get-T18FrontProc -Control $t18WPlainEdit)) -ne 'comctl32.dll'),
        ((Get-T18ProcModule -Proc (Get-T18FrontProc -Control $t18WEdit)) -ne 'comctl32.dll')) 'comctl32.dll/True/True'
    if ($t18WModule -eq 'comctl32.dll') {
      $t18WComctl = [HoneyThemeTest.ChainNative]::ModuleOf($t18WRelay)
      # 대조 - 장치 없음: 원시 → 계수기(마스터의 유일한 등록) → 지움
      $t18WPlainRaw = New-Object -TypeName HoneyThemeTest.RawCounter -ArgumentList $t18WPlainEdit.Handle, $t18WatchMessage
      $script:t18ChainKeep.Add($t18WPlainRaw)
      $t18WPlainCounter = New-Object -TypeName HoneyThemeTest.ComctlCounter -ArgumentList $t18WComctl, $t18WPlainEdit.Handle, $t18WatchMessage
      $script:t18ChainKeep.Add($t18WPlainCounter)
      $t18WPlainMaster = Get-T18ProcModule -Proc (Get-T18FrontProc -Control $t18WPlainEdit)
      Send-T18Watch -Control $t18WPlainEdit
      $t18WPlainBefore = '{0}/{1}' -f $t18WPlainCounter.Count, $t18WPlainRaw.Count
      $t18WPlainRemoved = $t18WPlainCounter.Remove()
      $t18WPlainTopRaw = ((Get-T18FrontProc -Control $t18WPlainEdit) -eq $t18WPlainRaw.Proc)
      Send-T18Watch -Control $t18WPlainEdit
      Assert-Case 'T18g Z 계수기 대조(장치 없음) - 원시 위에 계수기를 얹음(얹힘 · 맨 위 = comctl32 마스터) · 메시지 1 → 계수기 1 · 원시 1 | 지움(참) · 마스터가 스스로 빠짐(맨 위 = 원시) · 메시지 1 더 → 계수기 1 그대로 · 원시 2' `
        ('{0}/{1}/{2} | {3}/{4}/{5}/{6}' -f $t18WPlainCounter.Installed, $t18WPlainMaster, $t18WPlainBefore, $t18WPlainRemoved, $t18WPlainTopRaw, $t18WPlainCounter.Count, $t18WPlainRaw.Count) `
        'True/comctl32.dll/1/1 | True/True/1/2'
      # 장치 위: 원시 → 계수기(마스터의 유일한 등록) → 장치(켬) → 지움
      $t18WRaw = New-Object -TypeName HoneyThemeTest.RawCounter -ArgumentList $t18WEdit.Handle, $t18WatchMessage
      $script:t18ChainKeep.Add($t18WRaw)
      $t18WCounter = New-Object -TypeName HoneyThemeTest.ComctlCounter -ArgumentList $t18WComctl, $t18WEdit.Handle, $t18WatchMessage
      $script:t18ChainKeep.Add($t18WCounter)
      $t18WMaster = Get-T18FrontProc -Control $t18WEdit
      $t18WDevice = New-Object -TypeName HoneyInputRecolor -ArgumentList $t18WNumeric, $t18WEdit
      if ($t18WCounter.Installed -and (Test-T18ChainSound -Device $t18WDevice) -and ($t18WDevice.ChainProc -eq $t18WMaster)) {
        Set-T18ChainOn -Device $t18WDevice
        Send-T18Watch -Control $t18WEdit
        $t18WBefore = '{0}/{1}' -f $t18WCounter.Count, $t18WRaw.Count
        $t18WRemoved = $t18WCounter.Remove()
        $t18WFrontRemoved = Get-T18FrontProc -Control $t18WEdit
        Send-T18Watch -Control $t18WEdit
        Send-T18Watch -Control $t18WEdit
        $t18WCounterPrints = $t18WCounter.PrintCount
        $t18WRawPrints = $t18WRaw.PrintCount
        $t18WDevicePrints = $t18WDevice.PrintCount
        Send-T18PrintClient -Control $t18WEdit
        $t18WText = '{0} | {1}/{2}/{3} | {4}/{5} | +{6}/+{7}/+{8}/[{9}]' -f $t18WBefore, $t18WRemoved, ($t18WFrontRemoved -eq $t18WDevice.SelfProc), $t18WDevice.IsAttached,
          $t18WCounter.Count, $t18WRaw.Count, ($t18WDevice.PrintCount - $t18WDevicePrints), ($t18WRaw.PrintCount - $t18WRawPrints), ($t18WCounter.PrintCount - $t18WCounterPrints), $t18WDevice.LastError
      } else {
        $t18WText = '사슬 어긋남(메시지를 보내지 않음): 계수기 얹힘 {0} · 붙음 {1} · 붙기 직전 = 계수기의 마스터 {2} · 자기와 다름 {3}' -f $t18WCounter.Installed, $t18WDevice.IsAttached,
          ($t18WDevice.ChainProc -eq $t18WMaster), ($t18WDevice.ChainProc -ne $t18WDevice.SelfProc)
        Restore-T18FrontProc -Control $t18WEdit -Proc $t18WMaster
      }
      Assert-Case 'T18g Z 계수기(장치 아래 마스터의 마지막 등록을 지움 · 켠 장치 · 사슬은 메시지 전에 확인) - 지우기 전 계수기 · 원시 모두 닿음(1/1) | 지움(참) · 장치가 맨 위 그대로 · 붙음 | 메시지 둘 뒤 계수기 1 그대로(사슬에서 빠짐) · 원시 3 | 그림 받기: 장치가 다시 칠함(+1) · 원시에 닿음(+1) · 계수기 +0 · 오류 없음' `
        $t18WText '1/1 | True/True/True | 1/3 | +1/+1/+0/[]'
    }
  } catch { Assert-SectionError -Section 'T18g Z 계수기' -ErrorRecord $_ } finally { Remove-T18ChainForm -Chain $t18W }

  # R - 핸들 재생성(설계 리뷰 P3): 다시 만들어진 창에 다시 붙고(새 창에 다시 등록된 중계 마스터 위), 메시지와 장치 안의 그림 받기가 그 아래로 닿아야 합니다.
  # 핸들을 다시 만드는 동안의 메시지는 옛 창에 붙은 장치를 지나므로 그 전에 옛 창의 사슬을 봅니다. 붙기 직전 창 프로시저를 새로 읽는지는 이 행으로 구별되지 않습니다 -
  # 옛 창 · 새 창 모두 장치 바로 아래가 comctl32 마스터 창 프로시저라 주소가 같습니다(창마다 따로 있지 않음 - 11-14 구현 리뷰). 그 확인은 아래 창 프로시저가 핸들마다
  # 다른 T18e(말풍선 없는 칸 - 컨트롤 자신의 창 프로시저)의 재생성 행이 합니다. 둘째 행은 계수기를 얹은 뒤에도 맨 위가 장치인지 봅니다(계수기가 장치 아래 마스터에 들어감)
  $t18R = $null
  try {
    $t18R = New-T18ChainForm -Tip -Handles
    $t18REdit = $t18R.Edit
    $t18RFrontOld = Get-T18FrontProc -Control $t18REdit
    $t18RDevice = New-Object -TypeName HoneyInputRecolor -ArgumentList $t18R.Numeric, $t18REdit
    $t18ROldSound = Test-T18ChainSound -Device $t18RDevice
    $t18RRecreated = $false
    if ($t18ROldSound) { $t18RRecreated = Invoke-T18RecreateHandle -Control $t18REdit } else { Restore-T18FrontProc -Control $t18REdit -Proc $t18RFrontOld }
    $t18RFront = Get-T18FrontProc -Control $t18REdit
    $t18RModule = Get-T18ProcModule -Proc $t18RDevice.ChainProc
    Assert-Case 'T18g R 핸들 재생성 - 옛 창의 사슬 정상(다시 만들기 전) | 핸들이 바뀜 · 새 핸들에 다시 붙음 · 붙기 직전 창 프로시저가 0 도 자신도 아님 · 그 모듈 comctl32(새 창에 다시 등록된 중계) · 자기 창 프로시저 = 새 창의 맨 위 · 오류 없음' `
      ('{0} | {1}/{2}/{3}/{4}/{5}/{6}/[{7}]' -f $t18ROldSound, $t18RRecreated, ($t18RDevice.IsAttached -and ($t18RDevice.Handle -eq $t18REdit.Handle)), ($t18RDevice.ChainProc -ne [IntPtr]::Zero),
        ($t18RDevice.ChainProc -ne $t18RDevice.SelfProc), $t18RModule, ($t18RDevice.SelfProc -eq $t18RFront), $t18RDevice.LastError) 'True | True/True/True/True/comctl32.dll/True/[]'
    if ($t18RRecreated -and (Test-T18ChainSound -Device $t18RDevice) -and ($t18RModule -eq 'comctl32.dll')) {
      $t18RCounter = New-Object -TypeName HoneyThemeTest.ComctlCounter -ArgumentList ([HoneyThemeTest.ChainNative]::ModuleOf($t18RDevice.ChainProc)), $t18REdit.Handle, $t18WatchMessage
      $script:t18ChainKeep.Add($t18RCounter)
      $t18RFrontCounted = Get-T18FrontProc -Control $t18REdit
      Set-T18ChainOn -Device $t18RDevice
      Send-T18Watch -Control $t18REdit
      Send-T18PrintClient -Control $t18REdit
      Assert-Case 'T18g R 재생성 뒤 켠 장치 - 셀 수 있는 서브클래스 얹힘 · 맨 위 창 프로시저 = 장치 그대로(장치 아래의 comctl32 마스터에 들어감) · 메시지 1 → 셈 1 · 그림 받기: 장치가 다시 칠함(1) · 장치 안의 그림 받기가 닿음(1) · 오류 없음' `
        ('{0}/{1}/{2}/{3}/{4}/[{5}]' -f $t18RCounter.Installed, ($t18RFrontCounted -eq $t18RDevice.SelfProc), $t18RCounter.Count, $t18RDevice.PrintCount, $t18RCounter.PrintCount, $t18RDevice.LastError) 'True/True/1/1/1/[]'
    }
  } catch { Assert-SectionError -Section 'T18g R' -ErrorRecord $_ } finally { Remove-T18ChainForm -Chain $t18R }

  # 떼기의 맨 위 확인(설계 리뷰 P2 - ReleaseIfTop): 장치 위에 원시 서브클래스를 하나 더 얹은 뒤 떼면, 장치는 창 프로시저를 건드리지 않고 붙은 채 꺼져 남습니다(거짓).
  # NativeWindow 의 되돌림은 맨 위가 아닐 때 창 프로시저를 DefWindowProc 로 끊어, 위의 서브클래스가 사슬에서 떨어져 나갑니다.
  # 붙은 채 남은 장치는 제품 장치 형식의 정적 목록(retained - 빼는 곳 없이 프로세스가 끝날 때까지 붙잡아 둠)에 들어가야 합니다 - 그 목록은 리플렉션으로 읽습니다
  # (11-14 구현 리뷰: 예전에는 원문 가드만 지켜 넣는 줄을 늘 거짓인 조건 안으로 옮겨도 통과했음). 이 행이 그 목록에 장치 하나를 더하는 것은 이 테스트 프로세스 안의 일이라 괜찮습니다
  $t18T = $null
  try {
    $t18T = New-T18ChainForm -Handles
    $t18TEdit = $t18T.Edit
    $t18TBelow = New-Object -TypeName HoneyThemeTest.RawCounter -ArgumentList $t18TEdit.Handle, $t18WatchMessage
    $script:t18ChainKeep.Add($t18TBelow)
    $t18TDevice = New-Object -TypeName HoneyInputRecolor -ArgumentList $t18T.Numeric, $t18TEdit
    $t18TSound = (Test-T18ChainSound -Device $t18TDevice) -and ($t18TDevice.ChainProc -eq $t18TBelow.Proc)
    if ($t18TSound) {
      Set-T18ChainOn -Device $t18TDevice
      $t18TAbove = New-Object -TypeName HoneyThemeTest.RawCounter -ArgumentList $t18TEdit.Handle, $t18WatchMessage
      $script:t18ChainKeep.Add($t18TAbove)
      $t18TDetached = $t18TDevice.Detach()
      $t18TFront = Get-T18FrontProc -Control $t18TEdit
      Send-T18Watch -Control $t18TEdit
      $t18TText = '{0}/{1}/{2}/{3}/{4}/[{5}] | {6}/{7}' -f $t18TDetached, ($t18TFront -eq $t18TAbove.Proc), $t18TDevice.IsAttached, $t18TDevice.Active, (Test-T18Retained -Device $t18TDevice),
        $t18TDevice.LastError, $t18TAbove.Count, $t18TBelow.Count
    } else {
      $t18TText = '사슬 어긋남(메시지를 보내지 않음): 붙음 {0} · 붙기 직전 = 아래 원시 {1} · 자기와 다름 {2}' -f $t18TDevice.IsAttached, ($t18TDevice.ChainProc -eq $t18TBelow.Proc), ($t18TDevice.ChainProc -ne $t18TDevice.SelfProc)
      Restore-T18FrontProc -Control $t18TEdit -Proc $t18TBelow.Proc
    }
    Assert-Case 'T18g 떼기의 맨 위 확인 - 아래 원시 위에 붙은 장치(켬) 위에 원시 하나를 더 얹고 떼기: 거짓 · 창 프로시저 그대로(맨 위 = 위의 원시) · 장치는 붙은 채 · 꺼짐 · 정적 목록(retained)에 들어감 · 오류 없음 | 메시지 하나가 위의 원시 → 장치 → 아래의 원시까지(각 1)' `
      $t18TText 'False/True/True/False/True/[] | 1/1'
  } catch { Assert-SectionError -Section 'T18g 떼기의 맨 위 확인' -ErrorRecord $_ } finally { Remove-T18ChainForm -Chain $t18T }

  # ── T18 하네스 전환: 실제 전환(아이콘 클릭 · 전환 트랜잭션)에서의 장치 - 테마 하네스의 숫자 칸 · 시간 칸 · 목록 칸 + 표 밖 셀 편집 콤보 ──
  Invoke-T8Scene -Name 'T18 전환' -Scene {
    # 다크가 된 순간의 장치와, 폼 그림이 장치의 다시 칠하기를 담는지를 봅니다: 장치를 직접 끄면 폼 화소가 달라져야 합니다. 이것이 참이어야 모든 T8 장면의
    # '왕복 뒤 폼 화소 = 기준' 이 '라이트로 돌아와 장치가 꺼졌다' 를 실제로 지킵니다(장치가 켜진 채 남으면 그 칸이 어둡게 남아 화소가 갈림)
    Start-ThemeHarness
    $sceneBefore = Get-HarnessState
    $sceneTrip = Invoke-T8RoundTrip -DarkProbe {
      $darkEntries = @(Get-T18Entries)
      $darkPixelsOn = Get-FormPixelHash
      foreach ($darkEntry in $darkEntries) { $darkEntry.Painter.Active = $false }
      $darkPixelsOff = Get-FormPixelHash
      foreach ($darkEntry in $darkEntries) { $darkEntry.Painter.Active = $true }
      '{0} | 켜짐 {1} · 붙음 {2} | 장치를 끄면 폼 화소가 달라짐 {3} · 다시 켜면 돌아옴 {4}' -f ((@($darkEntries | ForEach-Object { '{0}:{1}' -f $_.Kind, $_.Painter.Owner.Name })) -join ' '),
        @($darkEntries | Where-Object { $_.Painter.Active }).Count, @($darkEntries | Where-Object { $_.Painter.IsAttached }).Count, ($darkPixelsOn -cne $darkPixelsOff), ($darkPixelsOn -ceq (Get-FormPixelHash))
    }
    Assert-Case 'T18 하네스 전환 - 아이콘 클릭으로 다크: 숫자 칸 · 시간 칸 · 목록 칸 + 셀 편집 콤보에 장치 · 모두 켜짐 · 폼 아래 셋은 창에 붙음 / 폼 그림이 장치의 다시 칠하기를 담음' $sceneTrip.Dark `
      'numeric:numCount picker:dtpUntil combo:cboDifficulty combo:cellEditCombo | 켜짐 4 · 붙음 3 | 장치를 끄면 폼 화소가 달라짐 True · 다시 켜면 돌아옴 True'
    Assert-Case 'T18 하네스 전환 - 다시 눌러 라이트: 장치 4개 그대로 · 켜진 장치 0' ('{0}/{1}' -f @(Get-T18Entries).Count, @(@(Get-T18Entries) | Where-Object { $_.Painter.Active }).Count) '4/0'
    Assert-RoundTrip -Name 'T18 하네스 전환' -Reference $sceneBefore -Trip $sceneTrip
  }
  function Invoke-T18SwitchFault {
    # 실제 전환(라이트 → 다크 · -Save)에서 장치 만들기가 던질 때: 전환은 계속되고(되돌리지 않음 - 그 칸들만 윈도우 기본 모양) 경고는 갱신의 맨 끝(12)에서 1줄입니다.
    # 하네스의 로그는 접혀 있어(기본) 그 줄이 로그 탭 배지를 만듭니다 - 이 함수 지역의 로그 스텁이 받은 줄을 실함수 Add-ColoredLogLine 에도 넘깁니다.
    # 8a 에서 바로 기록하면 그 뒤의 10번(잡아 둔 의미 되살리기)이 배지 글자를 전환 전 의미(기본 글자색)로 덮습니다 - 꿀색 배지 위에 밝은 글자.
    # 이어서 라이트 → 다시 다크로 한 번 더 던지게 해 [경고] 가 늘지 않는지 봅니다. 돌려주는 값 = hashtable 1개(첫 전환 글자 · 다시 전환 글자)
    function Save-UiThemeState { $script:t8SaveCount++ }
    function Update-ThemeIconStyle { }
    function Set-TitleBarTheme { param([bool]$Dark) }
    function Initialize-InputRecolor { throw '입력 칸 주입 예외' }
    function Add-GuiLog { param([string]$Message) $script:logLines.Add($Message); Add-ColoredLogLine ('12:00:00 ' + $Message) }
    Start-ThemeHarness
    $script:logLines.Clear()
    $script:t8SaveCount = 0
    $switchThrown = ''
    try { Invoke-ThemeSwitch -From 'light' -To 'dark' -Save } catch { $switchThrown = $_.Exception.Message }
    $firstText = '{0} | [{1}] | 저장 {2} | 배지 {3} · {4} | 예외 [{5}]' -f $script:uiTheme, ($script:logLines -join ' / '), $script:t8SaveCount, $chkTabLog.Text, (Get-BadgeText), $switchThrown
    try {
      Invoke-ThemeSwitch -From 'dark' -To 'light' -Save
      Invoke-ThemeSwitch -From 'light' -To 'dark' -Save
    } catch { $switchThrown = $_.Exception.Message }
    return @{ First = $firstText; Again = ('{0} | 경고 {1}줄 | 예외 [{2}]' -f $script:uiTheme, $script:logLines.Count, $switchThrown) }
  }
  Invoke-T8Scene -Name 'T18 실패' -Scene {
    $faultRow = Invoke-T18SwitchFault
    Assert-Case 'T18 하네스 전환 실패 - 장치 만들기가 던져도 다크로 바뀜(되돌림 0) · [경고] 1줄(적용 실패 문구 + 원인) · 저장 1 · 로그 탭 배지 = 경고 1 · 꿀색 바탕 위 꿀색용 글자 42,28,0(10번 뒤에 기록돼 덮이지 않음)' $faultRow.First `
      ('dark | [' + $t18ApplyWarning + '입력 칸 주입 예외] | 저장 1 | 배지 로그 ● 경고 1 · 255,215,0/42,28,0/False | 예외 []')
    Assert-Case 'T18 하네스 전환 실패 - 라이트로 갔다가 다시 다크에서 또 던짐: 다크 · [경고] 는 1줄 그대로(첫 1회) · 예외 0' $faultRow.Again 'dark | 경고 1줄 | 예외 []'
    # 실패한 뒤에도 다음 다크 전환은 처음부터 다시 만듭니다(이번에는 진짜 장치 만들기) - 목록이 없음 그대로 남아 있었기 때문입니다
    $script:logLines.Clear()
    Invoke-ThemeToggleClick
    Invoke-ThemeToggleClick
    Assert-Case 'T18 하네스 전환 실패 뒤 - 라이트 → 다크를 다시(진짜 장치 만들기): 다크 · 장치 4개 모두 켜짐 · 새 [경고] 0' ('{0}/{1}/{2}/{3}' -f $script:uiTheme, @(Get-T18Entries).Count,
        @(@(Get-T18Entries) | Where-Object { $_.Painter.Active }).Count, @($script:logLines | Where-Object { $_ -match '입력 칸' }).Count) 'dark/4/4/0'
  }
}

# ===== G 가드 (주석 뺀 원문 · AST) =====
$commandSites = @{}
foreach ($commandAst in @($guiAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))) {
  $siteName = $commandAst.GetCommandName()
  if ([string]::IsNullOrEmpty($siteName)) { continue }
  if (-not $commandSites.ContainsKey($siteName)) { $commandSites[$siteName] = New-Object System.Collections.Generic.List[object] }
  $commandSites[$siteName].Add($commandAst)
}
# 목록을 배열로 바꿔 둡니다 - PS 5.1 은 AST 노드가 든 List[object] 를 @() 로 감싸면 결합기 안에서 ArgumentException('인수 형식이 일치하지 않습니다')을 냅니다(11-12 실측)
foreach ($siteKey in @($commandSites.Keys)) { $commandSites[$siteKey] = $commandSites[$siteKey].ToArray() }
function Get-CommandOwnerText {
  # 명령을 부르는 곳의 주인(감싼 함수 이름, 최상위면 '(함수 밖)')을 '이름×횟수' 로 정렬해 이음
  param([string]$CommandName)
  if (-not $script:commandSites.ContainsKey($CommandName)) { return '' }
  $owners = @{}
  foreach ($site in $script:commandSites[$CommandName]) {
    $ownerName = Get-AstOwnerName -Ast $site
    $owners[$ownerName] = 1 + [int]$owners[$ownerName]
  }
  return ((@($owners.Keys) | Sort-Object | ForEach-Object { '{0}×{1}' -f $_, $owners[$_] }) -join ',')
}
function Test-LogWrapperTry {
  # 'try { Add-GuiLog … } catch { }' 꼴인가 - 본문이 Add-GuiLog 한 문장이고 catch 1절의 본문이 비어 있으며 finally 없음
  param($TryAst)
  if (($TryAst.CatchClauses.Count -ne 1) -or $TryAst.Finally) { return $false }
  if (@($TryAst.CatchClauses[0].Body.Statements).Count -ne 0) { return $false }
  $tryBodyStatements = @($TryAst.Body.Statements)
  if ($tryBodyStatements.Count -ne 1) { return $false }
  $firstCommand = @($tryBodyStatements[0].FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) | Select-Object -First 1
  return ($null -ne $firstCommand) -and ($firstCommand.GetCommandName() -eq 'Add-GuiLog')
}
function Test-AddGuiLogWrapped {
  # Add-GuiLog 호출이 감싼 로그(try 본문의 유일한 문장 · 빈 catch 1절)인가 - 기록 실패가 판정을 바꾸거나 처리기 밖으로 새지 않게(K1 · V6)
  param($CommandAst)
  $pipeline = $CommandAst.Parent
  if (-not ($pipeline -is [System.Management.Automation.Language.PipelineAst])) { return $false }
  $block = $pipeline.Parent
  if (-not ($block -is [System.Management.Automation.Language.StatementBlockAst])) { return $false }
  $tryNode = $block.Parent
  if (-not ($tryNode -is [System.Management.Automation.Language.TryStatementAst])) { return $false }
  if (-not ($tryNode.Body -eq $block)) { return $false }
  return (Test-LogWrapperTry -TryAst $tryNode)
}
function Get-AddGuiLogWrapText {
  # 함수 안 Add-GuiLog 호출 수 / 그중 감싼 로그 수
  param([string]$Name)
  $logCalls = @((Get-FunctionAstOf -Name $Name).FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Add-GuiLog') }, $true))
  $wrappedCalls = @($logCalls | Where-Object { Test-AddGuiLogWrapped -CommandAst $_ })
  return ('{0}/{1}' -f $logCalls.Count, $wrappedCalls.Count)
}
function Get-ShowDialogSite {
  # 창 띄우기 찾기 (G1 · G12 의 순서 가드가 함께 씀 - 11-13 리뷰 반영). 파일 전체에서 실제 호출 '$form.ShowDialog()' - 주석이 아니라 멤버 호출 식 노드 - 를 세고,
  # 그 호출을 본문에 품은 최상위 try 문의 번호를 돌려줍니다: hashtable 1개 @{ CallCount; TryIndexes }.
  # 예전에는 최상위 try 본문의 글자를 정규식으로 봐서, 실제 호출을 지우고 '# [void]$form.ShowDialog()' 주석만 남겨도(창이 뜨지 않음) 두 순서 가드가 통과했습니다 -
  # try 본문의 원문에는 블록 안 주석도 들어 있기 때문입니다. 호출이 정확히 1개가 아니거나, 그 호출이 최상위 try 의 본문(catch · finally 가 아닌) 안이 아니면
  # 번호가 비어 호출부의 순서 행이 실패합니다
  $showCalls = @($script:guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and
        ($node.Expression.Extent.Text -ceq '$form') -and ($node.Member.Extent.Text -ceq 'ShowDialog') }, $true))
  $tryIndexes = New-Object System.Collections.Generic.List[int]
  if ($showCalls.Count -eq 1) {
    # 호출에서 부모로 올라가며 지나온 노드를 모으고, 스크립트 본문 바로 아래 문장(= 최상위 문장)에서 멈춥니다
    $passedNodes = New-Object System.Collections.Generic.List[object]
    $topNode = $showCalls[0]
    while ($topNode.Parent -and -not ($topNode.Parent -eq $script:guiAst.EndBlock)) {
      $passedNodes.Add($topNode)
      $topNode = $topNode.Parent
    }
    if (($topNode -is $script:tryType) -and ($topNode.Parent -eq $script:guiAst.EndBlock)) {
      $insideTryBody = $false
      foreach ($passedNode in $passedNodes) { if ($passedNode -eq $topNode.Body) { $insideTryBody = $true } }
      if ($insideTryBody) {
        for ($statementIndex = 0; $statementIndex -lt $script:topStatements.Count; $statementIndex++) {
          if ($script:topStatements[$statementIndex] -eq $topNode) { $tryIndexes.Add($statementIndex) }
        }
      }
    }
  }
  return @{ CallCount = $showCalls.Count; TryIndexes = $tryIndexes.ToArray() }
}

try {
  # ── G1 시작 순서 ──
  $g1Palette = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -ceq "Set-HoneyPalette -Theme 'light'" })
  $g1Default = @(Get-TopIndexWhere { param($statement) ($statement -is $assignType) -and ($statement.Extent.Text -ceq '$script:uiThemeAtStart = ''light''') })
  $g1FormText = @(Get-TopIndexWhere { param($statement) ($statement -is $assignType) -and ($statement.Left.Extent.Text -ceq '$form.Text') -and $statement.Right.Extent.Text.StartsWith('"꿀비노기') })
  Assert-Case "G1 팔레트 라이트 호출 · 시작 기본값 'light'(각 최상위 1) < 폼 제목 대입" ('{0}/{1}/{2}' -f $g1Palette.Count, $g1Default.Count,
      (($g1Palette.Count -eq 1) -and ($g1Default.Count -eq 1) -and ($g1FormText.Count -eq 1) -and ($g1Palette[0] -lt $g1FormText[0]) -and ($g1Default[0] -lt $g1FormText[0]))) '1/1/True'
  $g1Link = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -ceq '$form.Controls.Add($lnkUpdate)' })
  $g1Icon = @(Get-TopIndexWhere { param($statement) ($statement -is $assignType) -and ($statement.Left.Extent.Text -ceq '$btnThemeToggle') })
  $g1TabSettings = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -ceq '$chkTabSettings = New-Object System.Windows.Forms.CheckBox' })
  Assert-Case "G1 아이콘 생성(최상위 1)은 링크 추가 뒤 · '설정' 토글 생성 앞" ('{0}/{1}/{2}/{3}' -f $g1Link.Count, $g1Icon.Count, $g1TabSettings.Count,
      (($g1Link.Count -eq 1) -and ($g1Icon.Count -eq 1) -and ($g1TabSettings.Count -eq 1) -and ($g1Link[0] -lt $g1Icon[0]) -and ($g1Icon[0] -lt $g1TabSettings[0]))) '1/1/1/True'
  $g1Migrate = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -ceq '$script:configMigrated = Update-ConfigToLatest' })
  $g1AfterMigrate = $(if (($g1Migrate.Count -eq 1) -and (($g1Migrate[0] + 1) -lt $topStatements.Count)) { $topStatements[$g1Migrate[0] + 1].Extent.Text } else { '' })
  Assert-Case 'G1 설정 이전 바로 다음 문장 = stale 정리(ST7 - 사이에 새 문장 없음)' $g1AfterMigrate 'Invoke-AbyssJournalStaleCleanup'
  $g1LoadLast = (@((Get-FunctionAstOf -Name 'Load-SettingsToUi').Body.EndBlock.Statements) | Select-Object -Last 1).Extent.Text
  Assert-Case 'G1 Load-SettingsToUi 의 마지막 문장 = 저장값 읽기' $g1LoadLast '$script:uiThemeAtStart = ConvertTo-UiTheme $cfg.ui.theme'
  $g1LayerDefinition = @(Get-TopIndexWhere { param($statement) ($statement -is $functionType) -and ($statement.Name -eq 'Invoke-StatusColorChanged') })
  $g1Registration = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -match '^\$lblStatus\.Add_ForeColorChanged\(' })
  $g1Refresh = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -ceq 'Invoke-HoneyThemeRefresh' })
  $g1Load = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -ceq 'Load-SettingsToUi' })
  $g1Panels = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -ceq '& $updateCategoryPanels' })
  Assert-Case 'G1 층 - 처리기 정의 < 등록 문장(최상위 1) < 시작 갱신(인자 없음 · 최상위 1) · 설정 읽기 · 패널 갱신 뒤' ('{0}/{1}/{2}/{3}/{4}/{5}' -f $g1LayerDefinition.Count, $g1Registration.Count, $g1Refresh.Count, $g1Load.Count, $g1Panels.Count,
      ((@($g1LayerDefinition, $g1Registration, $g1Refresh, $g1Load, $g1Panels) | Where-Object { $_.Count -ne 1 }).Count -eq 0 -and ($g1LayerDefinition[0] -lt $g1Registration[0]) -and
        ($g1Registration[0] -lt $g1Refresh[0]) -and ($g1Load[0] -lt $g1Refresh[0]) -and ($g1Panels[0] -lt $g1Refresh[0]))) '1/1/1/1/1/True'
  $g1DarkStart = @(Get-TopIndexWhere { param($statement) ($statement -is $ifType) -and ($statement.Clauses[0].Item1.Extent.Text -ceq '$script:uiThemeAtStart -eq ''dark''') })
  # 창 띄우기 = 실제 호출 노드와 그것을 본문에 품은 최상위 try (Get-ShowDialogSite - 주석은 세지 않음). 아래 다크 시작 순서 행과 G12 의 등록 순서 행이 이 번호를 씁니다
  $g1ShowSite = Get-ShowDialogSite
  $g1ShowDialog = @($g1ShowSite.TryIndexes)
  Assert-Case 'G1 창 띄우기 - 실제 호출 $form.ShowDialog() 이 파일 전체에 1곳(주석은 세지 않음) · 그 호출을 본문에 품은 최상위 try 1개' ('{0}/{1}' -f $g1ShowSite.CallCount, $g1ShowDialog.Count) '1/1'
  $g1DarkBody = $(if ($g1DarkStart.Count -eq 1) { '{0} 절 · else {1} · {2}' -f $topStatements[$g1DarkStart[0]].Clauses.Count, ($null -ne $topStatements[$g1DarkStart[0]].ElseClause),
      (Get-NormalizedText -Text $topStatements[$g1DarkStart[0]].Clauses[0].Item2.Extent.Text) } else { '' })
  Assert-Case 'G1 다크 시작 if 1개 · 본문 = 전환 1문장(-Save 없음) · 시작 갱신 뒤 · ShowDialog try 앞' ('{0}/{1}/{2}' -f $g1DarkStart.Count, $g1DarkBody,
      (($g1DarkStart.Count -eq 1) -and ($g1ShowDialog.Count -eq 1) -and ($g1Refresh.Count -eq 1) -and ($g1Refresh[0] -lt $g1DarkStart[0]) -and ($g1DarkStart[0] -lt $g1ShowDialog[0]))) `
    '1/1 절 · else False · { Invoke-ThemeSwitch -From ''light'' -To ''dark'' }/True'
  Assert-Case 'G1 저장 호출(Save-UiThemeState) = 전환 함수 안 1곳뿐(최상위 · 시작 경로 0)' (Get-CommandOwnerText -CommandName 'Save-UiThemeState') 'Invoke-ThemeSwitch×1'

} catch { Assert-SectionError -Section 'G1' -ErrorRecord $_ }
try {
  # ── G2 전환 · 갱신 ──
  $clickAst = Get-FunctionAstOf -Name 'Invoke-ThemeToggleClick'
  $clickTrys = @($clickAst.Body.EndBlock.Statements | Where-Object { $_ -is $tryType })
  $clickFirstTwo = $(if ($clickTrys.Count -eq 1) { (@($clickTrys[0].Body.Statements) | Select-Object -First 2 | ForEach-Object { Get-NormalizedText -Text $_.Extent.Text }) -join ' | ' } else { '' })
  Assert-Case 'G2 클릭 - try 본문 첫 두 문장 = 슬라이드 정리(인자 없음) → 실행 중 가드' $clickFirstTwo 'if ($script:lifeSlideActive) { Stop-LifeSlideNow } | if ($script:running) { return }'
  $clickSwitchCalls = @($clickAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Invoke-ThemeSwitch') }, $true))
  $clickSwitchWithSave = @($clickSwitchCalls | Where-Object { @($_.CommandElements | Where-Object { ($_ -is [System.Management.Automation.Language.CommandParameterAst]) -and ($_.ParameterName -eq 'Save') }).Count -eq 1 })
  Assert-Case 'G2 클릭 - 전환 호출 1회 · -Save' ('{0}/{1}' -f $clickSwitchCalls.Count, $clickSwitchWithSave.Count) '1/1'
  $refreshStatements = @((Get-FunctionAstOf -Name 'Invoke-HoneyThemeRefresh').Body.EndBlock.Statements | ForEach-Object { Get-NormalizedText -Text $_.Extent.Text })
  $refreshStartPart = @(
    '$form.BackColor = $script:themeBack', 'Apply-HoneyTheme -Root $form', '$btnStart.BackColor = $script:themeHoney', '$btnStart.ForeColor = $script:themeHoneyInk',
    '$btnStart.FlatAppearance.BorderSize = 0', '$btnKill.BackColor = $script:themeDanger', '$btnKill.ForeColor = [System.Drawing.Color]::White', '$btnKill.FlatAppearance.BorderSize = 0',
    '$btnSafeStop.BackColor = $script:themeSafeStop', '$btnClearHelp.BackColor = $script:themeHoney', '$btnClearHelp.ForeColor = $script:themeHoneyInk',
    'if (-not $Full) { $lblStatus.ForeColor = $script:themeTitle }', '$lnkUpdate.LinkColor = $script:themeTitle', 'Update-MainCategoryVisual', 'Update-LifeSliders', 'Update-ThemeIconStyle',
    'if (-not $Full) { $script:logBadgeStartAfterimage = (($script:hiddenLogErrors -gt 0) -or ($script:hiddenLogWarns -gt 0)) return }')
  # 11-14 다크 입력 칸 통일(설계 7.13): 8a = 리스트(8) 바로 다음 · 승인 조회 중 재칠(9) 앞, 12 = 제목줄(11) 뒤 맨 끝. 둘 다 시작 모드의 return 뒤라 전체 모드에서만 돕니다
  $refreshFullPart = @(
    'Update-TabToggleStyle', 'Update-CustomRandomToggleStyle -Toggle $chkCrRandom', 'Update-CustomRandomToggleStyle -Toggle $chkAcrRandom', 'Update-CustomRandomToggleStyle -Toggle $chkDcrRandom',
    'Update-CustomRandomToggleStyle -Toggle $chkLcrRandom', 'Update-ListThemeColors', 'Update-InputRecolor', 'if ($script:approvalPendingStart) { Set-StartButtonPending -Pending $true }',
    'Restore-ThemeState -State $RestoreState', 'Set-TitleBarTheme -Dark ($script:uiTheme -eq ''dark'')', 'Write-InputRecolorWarning')
  Assert-Case 'G2 갱신 - 1~6a 문장 순서(2.3 표 - 강조 · 3번 조건 · 링크 · 대분류 · 슬라이더 · 단장 · 잔상 표시 뒤 return)' ((@($refreshStatements) | Select-Object -First $refreshStartPart.Count) -join ' ;; ') ($refreshStartPart -join ' ;; ')
  Assert-Case 'G2 갱신 - -Full 뒷단계 = 7~12(토글 · 랜덤 4 · 리스트 · 8a 입력 칸 장치 · 9번(2번 뒤) · 복원(7·8·9 뒤) · 제목줄 · 12 보관된 경고 기록이 맨 끝)' ((@($refreshStatements) | Select-Object -Skip $refreshStartPart.Count) -join ' ;; ') ($refreshFullPart -join ' ;; ')
  $refreshCode = Get-FunctionCode -Name 'Invoke-HoneyThemeRefresh'
  Assert-Case "G2 'Apply-HoneyTheme -Root `$form' 파일 전체 1곳 · 갱신 안 상태 잡기(Get-ThemeRestoreState · Get-StatusColorMeaning) 0" ('{0}/{1}/{2}' -f [regex]::Matches($guiCode, [regex]::Escape('Apply-HoneyTheme -Root $form')).Count,
      [regex]::Matches($refreshCode, 'Get-ThemeRestoreState').Count, [regex]::Matches($refreshCode, 'Get-StatusColorMeaning').Count) '1/0/0'
  $refreshSites = @($commandSites['Invoke-HoneyThemeRefresh'])
  $fullSites = @($refreshSites | Where-Object { @($_.CommandElements | Where-Object { ($_ -is [System.Management.Automation.Language.CommandParameterAst]) -and ($_.ParameterName -eq 'Full') }).Count -gt 0 })
  $plainSites = @($refreshSites | Where-Object { $_.CommandElements.Count -eq 1 })
  Assert-Case 'G2 -Full 호출 = 전환 함수 안 2곳 · 둘 다 -RestoreState $restoreState · 인자 없는 호출은 최상위 1 · 그 밖 0' ('{0}|{1}|{2}|{3}|{4}' -f $refreshSites.Count,
      ((@($fullSites | ForEach-Object { Get-AstOwnerName -Ast $_ })) -join ','), @($fullSites | Where-Object { (Get-NormalizedText -Text $_.Extent.Text) -ceq 'Invoke-HoneyThemeRefresh -Full -RestoreState $restoreState' }).Count,
      ((@($plainSites | ForEach-Object { Get-AstOwnerName -Ast $_ })) -join ','), ($refreshSites.Count - $fullSites.Count - $plainSites.Count)) '3|Invoke-ThemeSwitch,Invoke-ThemeSwitch|2|(함수 밖)|0'

} catch { Assert-SectionError -Section 'G2' -ErrorRecord $_ }
try {
  # ── G3 잠금 · 배선 ──
  Assert-Case 'G3 Set-UiRunning 에 아이콘 잠금 1줄' ([regex]::Matches((Get-FunctionCode -Name 'Set-UiRunning'), [regex]::Escape('$btnThemeToggle.Enabled = -not $IsRunning')).Count) 1
  $initializeCode = Get-FunctionCode -Name 'Initialize-ThemeToggleButton'
  Assert-Case 'G3 클릭 · Paint 등록 = 명명 함수 한 줄 · 층 등록 = 명명 함수 한 줄(최상위 문장 그대로)' ('{0}/{1}/{2}' -f [regex]::Matches($initializeCode, [regex]::Escape('$themeButton.Add_Click({ Invoke-ThemeToggleClick })')).Count,
      [regex]::Matches($initializeCode, [regex]::Escape('$themeButton.Add_Paint({ Invoke-ThemeIconPaint -Sender $this -PaintArgs $_ })')).Count, ($layerRegistrationText -ceq '$lblStatus.Add_ForeColorChanged({ Invoke-StatusColorChanged })')) '1/1/True'
  $closureHits = @($newFunctionNames | Where-Object { [regex]::Matches((Get-FunctionCode -Name $_), 'GetNewClosure').Count -gt 0 })
  Assert-Case 'G3 새 함수 28개 본문 · 층 등록 문장 안 GetNewClosure 0' ('{0}/{1}' -f ($closureHits -join ','), [regex]::Matches($layerRegistrationText, 'GetNewClosure').Count) '/0'

} catch { Assert-SectionError -Section 'G3' -ErrorRecord $_ }
try {
  # ── G4 키 ──
  $saveThemeCode = Get-FunctionCode -Name 'Save-UiThemeState'
  Assert-Case "G4 저장 키 'theme' - 있는지 확인 · 대입 · 추가가 각 1 (같은 이름)" ('{0}/{1}/{2}' -f [regex]::Matches($saveThemeCode, [regex]::Escape("`$cfg.ui.PSObject.Properties['theme']")).Count,
      [regex]::Matches($saveThemeCode, [regex]::Escape('$cfg.ui.theme = [string]$script:uiTheme')).Count, [regex]::Matches($saveThemeCode, [regex]::Escape("-NotePropertyName 'theme'")).Count) '1/1/1'
  $repoConfig = Get-Content -LiteralPath $repoConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Case "G4 config.json ui.theme = 'light'(문자열) · ui._theme 있음 · 읽기도 같은 키" ('{0}/{1}/{2}/{3}' -f [string]$repoConfig.ui.theme, ($repoConfig.ui.theme -is [string]),
      (-not [string]::IsNullOrWhiteSpace([string]$repoConfig.ui._theme)), $g1LoadLast.Contains('$cfg.ui.theme')) 'light/True/True/True'

} catch { Assert-SectionError -Section 'G4' -ErrorRecord $_ }
try {
  # ── G5 비공식 API · 제목줄 ──
  $g5Forbidden = @('SetWindowTheme', 'DarkMode_', 'uxtheme', 'AllowDarkModeForWindow', 'SetPreferredAppMode', 'SetWindowPos')
  Assert-Case 'G5 비공식 테마 API · SetWindowPos 0' ((@($g5Forbidden | ForEach-Object { '{0}={1}' -f $_, [regex]::Matches($guiCode, [regex]::Escape($_), 'IgnoreCase').Count })) -join ' ') `
    'SetWindowTheme=0 DarkMode_=0 uxtheme=0 AllowDarkModeForWindow=0 SetPreferredAppMode=0 SetWindowPos=0'
  $wrapperCode = Get-FunctionCode -Name 'Invoke-DwmTitleBarAttribute'
  Assert-Case 'G5 DwmSetWindowAttribute - 선언 1 · 파일 전체 이름 2(선언 + 래퍼 호출) · 래퍼 안 호출 1(속성 20 · 크기 4) · 속성 19 0 · 래퍼를 부르는 곳 = 제목줄 함수뿐' ('{0}/{1}/{2}/{3}/{4}' -f
      [regex]::Matches($guiCode, [regex]::Escape('public static extern int DwmSetWindowAttribute(IntPtr hwnd, int dwAttribute, ref int pvAttribute, int cbAttribute);')).Count,
      [regex]::Matches($guiCode, 'DwmSetWindowAttribute').Count, [regex]::Matches($wrapperCode, [regex]::Escape('[Win32.WindowProbe]::DwmSetWindowAttribute($Handle, 20, [ref]$attributeValue, 4)')).Count,
      [regex]::Matches($guiCode, 'DwmSetWindowAttribute\([^)]*,\s*19\s*,').Count, (Get-CommandOwnerText -CommandName 'Invoke-DwmTitleBarAttribute')) '1/2/1/0/Set-TitleBarTheme×1'
  $titleCode = Get-NormalizedText -Text $functionTexts['Set-TitleBarTheme']
  Assert-Case 'G5 제목줄 함수 - 래퍼 반환값을 변수로 받음 · -ne 0 분기 안 감싼 [경고] 1' ('{0}/{1}' -f $titleCode.Contains('$titleBarResult = Invoke-DwmTitleBarAttribute -Handle $form.Handle -Value ([int]$Dark)'),
      $titleCode.Contains("if (`$titleBarResult -ne 0) { try { Add-GuiLog ('[경고] 제목줄 색을 바꾸지 못했습니다 (0x{0:X8})' -f `$titleBarResult) } catch { } }")) 'True/True'

} catch { Assert-SectionError -Section 'G5' -ErrorRecord $_ }
try {
  # ── G6 아이콘 ──
  $initializeStatements = @((Get-FunctionAstOf -Name 'Initialize-ThemeToggleButton').Body.EndBlock.Statements | ForEach-Object { Get-NormalizedText -Text $_.Extent.Text })
  $g6Required = @('$themeButton.Name = ''btnThemeToggle''', '$themeButton.Text = ''''', '$themeButton.Size = New-Object System.Drawing.Size(28, 28)',
    '$themeButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right')
  $g6RequiredCounts = (@($g6Required | ForEach-Object { $requiredLine = $_; @($initializeStatements | Where-Object { $_ -ceq $requiredLine }).Count })) -join ','
  $g6AddIndex = [array]::IndexOf([string[]]$initializeStatements, '$Form.Controls.Add($themeButton)')
  $g6FrontIndex = [array]::IndexOf([string[]]$initializeStatements, '$themeButton.BringToFront()')
  $g6PlaceIndex = [array]::IndexOf([string[]]$initializeStatements, 'Update-ThemeIconPlacement -Button $themeButton -Label $AnchorLabel')
  Assert-Case "G6 생성 함수 - 이름 'btnThemeToggle' · 글자 '' · 28x28 · 앵커 아래/오른쪽 각 1 · 폼 추가 → 맨 앞 → 첫 배치 순서" ('{0}/{1}' -f $g6RequiredCounts,
      (($g6AddIndex -ge 0) -and ($g6AddIndex -lt $g6FrontIndex) -and ($g6FrontIndex -lt $g6PlaceIndex))) '1,1,1,1/True'
  $paintCode = Get-FunctionCode -Name 'Invoke-ThemeIconPaint'
  Assert-Case 'G6 단장 접근성 이름 대입 1 · 배치 함수 try 0(H8) · Paint 함수 DrawString 0 · 이모지 0' ('{0}/{1}/{2}/{3}' -f [regex]::Matches((Get-FunctionCode -Name 'Update-ThemeIconStyle'), [regex]::Escape('$btnThemeToggle.AccessibleName = ')).Count,
      @((Get-FunctionAstOf -Name 'Update-ThemeIconPlacement').FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)).Count,
      [regex]::Matches($paintCode, 'DrawString').Count, [regex]::Matches($paintCode, '[\u2600-\u27BF]|[\uD83C-\uD83E][\uDC00-\uDFFF]').Count) '1/0/0/0'
  $tickPlacements = @(@($commandSites['Update-ThemeIconPlacement']) | Where-Object { (Get-NormalizedText -Text $_.Extent.Text) -ceq 'Update-ThemeIconPlacement -Button $btnThemeToggle -Label $lnkUpdate' })
  $g6TickText = '없음'
  if ($tickPlacements.Count -eq 1) {
    $tickStatement = $tickPlacements[0].Parent
    $tickBlockStatements = @($tickStatement.Parent.Statements)
    $tickIndex = -1
    for ($blockIndex = 0; $blockIndex -lt $tickBlockStatements.Count; $blockIndex++) { if ($tickBlockStatements[$blockIndex] -eq $tickStatement) { $tickIndex = $blockIndex } }
    $tickPrevious = $(if ($tickIndex -ge 1) { $tickBlockStatements[$tickIndex - 1].Extent.Text } else { '' })
    $tickMessageBoxAfter = @($tickBlockStatements | Select-Object -Skip ($tickIndex + 1) | Where-Object { $_.Extent.Text.Contains('[System.Windows.Forms.MessageBox]::Show(') }).Count
    $g6TickText = '{0} 다음 · 뒤에 MessageBox 문장 {1} · 감싼 함수 {2}' -f $tickPrevious, $tickMessageBoxAfter, (Get-AstOwnerName -Ast $tickPlacements[0])
  }
  Assert-Case 'G6 업데이트 틱 재배치 = 링크 표시 바로 다음 · 같은 블록의 MessageBox 앞(팝업 조건 밖) · 최상위 처리기' ('{0} · {1}' -f $tickPlacements.Count, $g6TickText) '1 · $lnkUpdate.Visible = $true 다음 · 뒤에 MessageBox 문장 1 · 감싼 함수 (함수 밖)'

} catch { Assert-SectionError -Section 'G6' -ErrorRecord $_ }
try {
  # ── G7 라이트 경로 보존 ──
  # Apply-HoneyTheme 는 함수 전체를 글자까지 맞댑니다(11-13 리뷰가 '지나치게 강하다 - 동작이 같은 정리도 실패한다' 고 지적했고, 유지합니다): 이 함수는 라이트 화소
  # (계약 L - 라이트 시작 화면이 바꾸기 전과 픽셀까지 같다)를 정하는데, L 은 회귀 테스트가 아니라 실기 1회로만 판정됩니다. 그래서 이 함수의 글자가 바뀌면 -
  # 동작이 같아 보이는 정리라도 - 사람이 L 을 다시 확인하고 아래 기대 문자열을 고치게 하는 방아쇠로 둡니다(G1 의 시작 · 생성 문장 원문 고정과 같은 꼴).
  # 형식별 동작(분기마다 어떤 속성에 어떤 팔레트 값이 들어가는지)은 실행 행도 봅니다 - 아홉 분기 모두 T8 m 의 다크 · 라이트 리터럴 행에 대표 컨트롤이 있고
  # (일반 형식 다섯 = Label · CheckBox · GroupBox · Panel · Button / 형식 넷 = RadioButton · NumericUpDown · ComboBox · RichTextBox), 재귀는 묶음 안 패널 안 Label 이 봅니다.
  # 이 문장을 처음 적을 때는 사실과 달랐습니다(11-13 내부 검토): GroupBox · Label · Panel 분기와 CheckBox 의 다크 값은 리터럴 실행 행이 없어 이 원문 일치가 유일한
  # 가드였고, 그 분기를 바꾼 변이는 이 1행만 실패했습니다 - 그래서 T8 m 에 일반 형식 다섯 행을 더했습니다.
  # 그래도 실행 행이 보는 것은 하네스의 대표 컨트롤뿐입니다 - 분기를 더하는 변경(하네스에 없는 형식 - 제품의 승인 코드 입력 칸 같은 TextBox 등)이 라이트 화면에 닿는지는
  # 이 원문 일치만 알립니다
  $applyNormalized = Get-NormalizedText -Text $functionTexts['Apply-HoneyTheme']
  $applyExpected = "function Apply-HoneyTheme { param([System.Windows.Forms.Control]`$Root) foreach (`$ctl in @(`$Root.Controls)) { switch (`$ctl.GetType().Name) { 'Button' { `$ctl.FlatStyle = 'Flat' `$ctl.FlatAppearance.BorderColor = `$script:themeBorder `$ctl.FlatAppearance.BorderSize = 1 `$ctl.BackColor = `$script:themeControl `$ctl.ForeColor = `$script:themeText } 'GroupBox' { `$ctl.ForeColor = `$script:themeTitle; `$ctl.BackColor = `$script:themeBack } 'Label' { `$ctl.ForeColor = `$script:themeText } 'CheckBox' { `$ctl.ForeColor = `$script:themeText } 'RadioButton' { `$ctl.ForeColor = `$script:themeText } 'Panel' { `$ctl.BackColor = `$script:themeBack } 'NumericUpDown' { `$ctl.BackColor = `$script:themeInput; `$ctl.ForeColor = `$script:themeText } 'ComboBox' { `$ctl.BackColor = `$script:themeInput; `$ctl.ForeColor = `$script:themeText } 'RichTextBox' { `$ctl.BackColor = `$script:themeLogBack; `$ctl.BorderStyle = 'None' } } if (`$ctl.Controls.Count -gt 0) { Apply-HoneyTheme -Root `$ctl } } }"
  Assert-Case 'G7 Apply-HoneyTheme 본문 그대로(분기 9종 · 분기 본문 · 재귀)' ($applyNormalized -ceq $applyExpected) $true
  Assert-Case "G7 갱신 함수 안 'Apply-HoneyTheme -Root `$form' 뒤 1200자 안에 대분류 → 슬라이더(test_audit_fixes 와 같은 식)" ([regex]::IsMatch($refreshCode, 'Apply-HoneyTheme -Root \$form[\s\S]{0,1200}?Update-MainCategoryVisual\s+Update-LifeSliders')) $true
  # 패널 갱신 → 기타 카드 선택 모양 배선(11-13 리뷰 지적): 다섯 문장을 Update-EtcNyanCardStyle 한 줄로 옮기면서 그 호출을 지키는 단언이 없었습니다.
  # 빠지면 기타 카드의 선택 모양이 다시는 칠해지지 않아 라이트 화면이 바뀝니다. 패널 갱신은 컨트롤 수십 개를 만지는 블록이라 실행 대신 구조를 봅니다:
  # 최상위 대입문 1개 · 블록 안 호출 정확히 1(인자 없음) · 그 호출을 감싼 if 절의 조건이 정확히 $isEtc · 그 if 는 블록 바로 아래 문장(다른 조건 밖)
  $g7PanelIndexes = @(Get-TopIndexWhere { param($statement) ($statement -is $assignType) -and ($statement.Left.Extent.Text -ceq '$updateCategoryPanels') })
  $g7PanelText = '대입문 {0}' -f $g7PanelIndexes.Count
  if ($g7PanelIndexes.Count -eq 1) {
    $g7PanelBlock = @($topStatements[$g7PanelIndexes[0]].Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.ScriptBlockAst] }, $true)) | Select-Object -First 1
    $g7NyanCalls = @($g7PanelBlock.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Update-EtcNyanCardStyle') }, $true))
    $g7Condition = '조건 없음'
    $g7IfAtTop = $false
    if ($g7NyanCalls.Count -eq 1) {
      $g7CallBody = $g7NyanCalls[0].Parent.Parent
      $g7CallIf = $g7CallBody.Parent
      if ($g7CallIf -is [System.Management.Automation.Language.IfStatementAst]) {
        foreach ($g7Clause in $g7CallIf.Clauses) { if ($g7Clause.Item2 -eq $g7CallBody) { $g7Condition = $g7Clause.Item1.Extent.Text } }
        $g7IfAtTop = ($g7CallIf.Parent -eq $g7PanelBlock.EndBlock)
      }
    }
    $g7PanelText = '{0}/{1}/{2}/{3}' -f $g7NyanCalls.Count, $g7Condition, $g7IfAtTop, $(if ($g7NyanCalls.Count -eq 1) { $g7NyanCalls[0].Extent.Text } else { '' })
  }
  Assert-Case 'G7 패널 갱신 → 기타 카드 선택 모양: 호출 1(인자 없음) · if ($isEtc) 절 안 · 그 if 는 블록 바로 아래 문장' $g7PanelText '1/$isEtc/True/Update-EtcNyanCardStyle'

} catch { Assert-SectionError -Section 'G7' -ErrorRecord $_ }
try {
  # ── G8 트랜잭션 · 처리기 경계 ──
  $switchAst = Get-FunctionAstOf -Name 'Invoke-ThemeSwitch'
  $switchTrys = @($switchAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true))
  $switchWrappers = @($switchTrys | Where-Object { Test-LogWrapperTry -TryAst $_ })
  $switchTransactions = @($switchTrys | Where-Object { -not (Test-LogWrapperTry -TryAst $_) })
  # FindAll 은 문서 순서라 이 줄의 순서가 곧 상태 < 적용 < 되돌림 입니다
  $transactionText = (@($switchTransactions | ForEach-Object {
        'catch {0} 로그 {1}: {2} => {3}' -f $_.CatchClauses.Count,
          @($_.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Add-GuiLog') }, $true)).Count,
          (Get-NormalizedText -Text $_.Body.Extent.Text), $(if ($_.CatchClauses.Count -ge 1) { Get-NormalizedText -Text $_.CatchClauses[0].Body.Extent.Text } else { '' })
      })) -join ' ;; '
  Assert-Case 'G8 전환 - 상태 < 적용 < 되돌림 try 3개 · 각 catch 1절 · 본문 · catch 에 상태 변경과 원인 대입만(로그 0)' $transactionText `
    ('catch 1 로그 0: { $restoreState = Get-ThemeRestoreState } => { $stateError = $_.Exception.Message } ;; catch 1 로그 0: { Set-HoneyPalette -Theme $To Invoke-HoneyThemeRefresh -Full -RestoreState $restoreState } => { $applyError = $_.Exception.Message } ;; ' +
      'catch 1 로그 0: { Set-HoneyPalette -Theme $From Invoke-HoneyThemeRefresh -Full -RestoreState $restoreState } => { $restoreError = $_.Exception.Message }')
  $switchResultAfterRevert = (($switchTransactions.Count -eq 3) -and ($switchWrappers.Count -eq 2) -and (@($switchWrappers | Where-Object { $_.Extent.StartOffset -gt $switchTransactions[2].Extent.EndOffset }).Count -eq 1))
  Assert-Case 'G8 전환 - 로그는 감싼 로그 2곳뿐(세 try 밖) · 결과 줄은 되돌림 try 뒤' ('{0}/{1}' -f (Get-AddGuiLogWrapText -Name 'Invoke-ThemeSwitch'), $switchResultAfterRevert) '2/2/True'
  $saveCalls = @($switchAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Save-UiThemeState') }, $true))
  $saveContext = '없음'
  if ($saveCalls.Count -eq 1) {
    $saveAncestors = @()
    $ancestor = $saveCalls[0].Parent
    while ($ancestor -and -not ($ancestor -is [System.Management.Automation.Language.FunctionDefinitionAst])) { $saveAncestors += $ancestor; $ancestor = $ancestor.Parent }
    $saveContext = '{0}|{1}' -f @($saveAncestors | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] }).Count,
      ((@($saveAncestors | Where-Object { $_ -is [System.Management.Automation.Language.IfStatementAst] } | ForEach-Object { $_.Clauses[0].Item1.Extent.Text })) -join ' < ')
  }
  Assert-Case 'G8 전환 - 저장은 try 밖 1곳(적용 오류 없음 · -Save 일 때만)' ('{0}/{1}' -f $saveCalls.Count, $saveContext) '1/0|$Save < $null -eq $applyError'
  Assert-Case 'G8 팔레트 호출 = 최상위 라이트 1 · 전환 함수 2 (다크 시작은 직접 부르지 않음)' (Get-CommandOwnerText -CommandName 'Set-HoneyPalette') '(함수 밖)×1,Invoke-ThemeSwitch×2'
  Assert-Case 'G8 갱신 · 단장 본문 try 0(K5)' ('{0}/{1}' -f @((Get-FunctionAstOf -Name 'Invoke-HoneyThemeRefresh').FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)).Count,
      @((Get-FunctionAstOf -Name 'Update-ThemeIconStyle').FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)).Count) '0/0'
  $multiCatch = @($newFunctionNames | Where-Object { @((Get-FunctionAstOf -Name $_).FindAll({ param($node) ($node -is [System.Management.Automation.Language.TryStatementAst]) -and ($node.CatchClauses.Count -gt 1) }, $true)).Count -gt 0 })
  Assert-Case 'G8 새 함수 28개의 try 마다 catch 1절 이하' ($multiCatch -join ',') ''
  Assert-Case 'G8 감싼 로그 - 클릭 · Paint · 층 처리기 각 1 · 저장 함수 2 · 제목줄 1 (호출 수/감싼 수)' ('{0} {1} {2} {3} {4}' -f (Get-AddGuiLogWrapText -Name 'Invoke-ThemeToggleClick'), (Get-AddGuiLogWrapText -Name 'Invoke-ThemeIconPaint'),
      (Get-AddGuiLogWrapText -Name 'Invoke-StatusColorChanged'), (Get-AddGuiLogWrapText -Name 'Save-UiThemeState'), (Get-AddGuiLogWrapText -Name 'Set-TitleBarTheme')) '1/1 1/1 1/1 2/2 1/1'

} catch { Assert-SectionError -Section 'G8' -ErrorRecord $_ }
try {
  # ── G9 정의 순서 · 인자 ──
  $g9Late = @()
  foreach ($g9Name in @('Invoke-ThemeIconPaint', 'Invoke-ThemeToggleClick', 'Update-ThemeIconPlacement', 'Get-ThemeIconLeft', 'Get-ThemeIconSpec', 'Update-ThemeIconStyle', 'Initialize-ThemeToggleButton')) {
    $g9Definition = @(Get-TopIndexWhere { param($statement) ($statement -is $functionType) -and ($statement.Name -eq $g9Name) })
    if (($g9Definition.Count -ne 1) -or ($g1Icon.Count -ne 1) -or ($g9Definition[0] -ge $g1Icon[0])) { $g9Late += $g9Name }
  }
  Assert-Case 'G9 아이콘 함수 7개 최상위 정의 < 생성 호출 문장' ($g9Late -join ',') ''
  $g9Unknown = '호출 없음'
  if ($g1Icon.Count -eq 1) {
    $g9Call = @($topStatements[$g1Icon[0]].Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) | Select-Object -First 1
    $g9ParamNames = @((Get-FunctionAstOf -Name 'Initialize-ThemeToggleButton').Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    $g9CallNames = @($g9Call.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } | ForEach-Object { $_.ParameterName })
    $g9Unknown = '{0} | 모르는 인자 [{1}]' -f $g9Call.GetCommandName(), ((@($g9CallNames | Where-Object { $g9ParamNames -notcontains $_ })) -join ',')
  }
  Assert-Case 'G9 생성 호출의 이름 있는 인자 ⊆ 함수 param' $g9Unknown 'Initialize-ThemeToggleButton | 모르는 인자 []'

} catch { Assert-SectionError -Section 'G9' -ErrorRecord $_ }
try {
  # ── G10 링크 글자 ──
  Assert-Case "G10 링크 글자 대입 'v<번호> 다운로드' 1 · 안내 창 'v<번호> 다운로드' 링크 · 옛 '새 버전 다운로드' 0" ('{0}/{1}/{2}' -f
      @($linkTextAssignments | Where-Object { $_.Extent.Text -ceq '$lnkUpdate.Text = "v$remoteVersion 다운로드"' }).Count,
      [regex]::Matches($guiCode, [regex]::Escape("우측 하단의 'v`$remoteVersion 다운로드' 링크를 누르면")).Count, [regex]::Matches($guiCode, [regex]::Escape("'새 버전 다운로드'")).Count) '1/1/0'

} catch { Assert-SectionError -Section 'G10' -ErrorRecord $_ }
try {
  # ── G11 배지 잔상 ──
  $g11Assignments = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -ceq '$script:logBadgeStartAfterimage') }, $true))
  Assert-Case 'G11 잔상 표시 대입 정확히 5곳(주인=값)' ((@($g11Assignments | ForEach-Object { '{0}={1}' -f (Get-AstOwnerName -Ast $_), (Get-NormalizedText -Text $_.Right.Extent.Text) })) -join ' | ') `
    '(함수 밖)=$false | Update-LogTabBadge=$false | Reset-LogTabBadge=$false | Restore-ThemeState=[bool]$State.BadgeAfterimage | Invoke-HoneyThemeRefresh=(($script:hiddenLogErrors -gt 0) -or ($script:hiddenLogWarns -gt 0))'
  Assert-Case 'G11 배지 칠하기 · 지우기 함수의 첫 문장 = 표시 거짓' ('{0} | {1}' -f (@((Get-FunctionAstOf -Name 'Update-LogTabBadge').Body.EndBlock.Statements)[0].Extent.Text),
      (@((Get-FunctionAstOf -Name 'Reset-LogTabBadge').Body.EndBlock.Statements)[0].Extent.Text)) '$script:logBadgeStartAfterimage = $false | $script:logBadgeStartAfterimage = $false'
  $badgeCode = Get-FunctionCode -Name 'Update-LogTabBadge'
  Assert-Case 'G11 배지 바탕 · 글자 대입 4문장 원문 그대로' ((@('$chkTabLog.BackColor = $script:themeDanger', '$chkTabLog.ForeColor = [System.Drawing.Color]::White', '$chkTabLog.BackColor = [System.Drawing.Color]::Gold',
          '$chkTabLog.ForeColor = $script:themeHoneyInk') | ForEach-Object { [regex]::Matches($badgeCode, [regex]::Escape($_)).Count }) -join ',') '1,1,1,1'
  $restoreStatements = @((Get-FunctionAstOf -Name 'Restore-ThemeState').Body.EndBlock.Statements | ForEach-Object { Get-NormalizedText -Text $_.Extent.Text })
  $restoreExpected = @('Restore-StatusColorMeaning -Meaning $State.Status',
    '$chkTabSettings.ForeColor = Resolve-ToggleColorMeaning -Meaning $State.Toggles[''chkTabSettings'']', '$chkTabLog.ForeColor = Resolve-ToggleColorMeaning -Meaning $State.Toggles[''chkTabLog'']',
    '$chkCrRandom.ForeColor = Resolve-ToggleColorMeaning -Meaning $State.Toggles[''chkCrRandom'']', '$chkAcrRandom.ForeColor = Resolve-ToggleColorMeaning -Meaning $State.Toggles[''chkAcrRandom'']',
    '$chkDcrRandom.ForeColor = Resolve-ToggleColorMeaning -Meaning $State.Toggles[''chkDcrRandom'']', '$chkLcrRandom.ForeColor = Resolve-ToggleColorMeaning -Meaning $State.Toggles[''chkLcrRandom'']',
    'if ($State.NyanCard -eq ''Selected'') { Update-EtcNyanCardStyle }', '$script:logBadgeStartAfterimage = [bool]$State.BadgeAfterimage',
    'if ($script:logBadgeStartAfterimage) { $chkTabLog.ForeColor = $(if ($script:uiTheme -eq ''dark'') { Get-LogBadgeTextColor } else { $script:themeText }) }')
  Assert-Case 'G11 복원 순서 = 상태줄 → 토글 6 → 카드(Selected 만) → 잔상 표시 → 잔상 글자(토글 되살리기 뒤)' ($restoreStatements -join ' ;; ') ($restoreExpected -join ' ;; ')
  Assert-Case 'G11 복원 상태 반환에 BadgeAfterimage · 배지 글자색 함수를 부르는 곳 = 복원 함수뿐' ('{0}/{1}' -f [regex]::Matches((Get-FunctionCode -Name 'Get-ThemeRestoreState'), [regex]::Escape('BadgeAfterimage = [bool]$script:logBadgeStartAfterimage')).Count,
      (Get-CommandOwnerText -CommandName 'Get-LogBadgeTextColor')) '1/Restore-ThemeState×1'
} catch { Assert-SectionError -Section 'G11' -ErrorRecord $_ }
try {
  # ── G12 잠긴 글자 덧그리기 배선 (11-13 - 목록 · 등록 · 실행 시작/정지의 다시 그리기 · 처리기 경계) ──
  # 일괄 적용(Apply-HoneyTheme)과 공용 갱신(Invoke-HoneyThemeRefresh)은 이 기능으로 바뀌지 않았습니다 - 위 G2 · G7 의 원문 단언이 그대로 지킵니다
  $g12ListEverywhere = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -ceq '$script:lockedTextControls') }, $true))
  $g12List = @(Get-TopIndexWhere { param($statement) ($statement -is $assignType) -and ($statement.Left.Extent.Text -ceq '$script:lockedTextControls') })
  $g12ListRight = $(if ($g12List.Count -eq 1) { Get-NormalizedText -Text $topStatements[$g12List[0]].Right.Extent.Text } else { '' })
  Assert-Case 'G12 목록 대입 = 파일 전체 1곳 · 최상위 · 여섯 컨트롤 이름 그대로 · 그 순서' ('{0}/{1}/{2}' -f $g12ListEverywhere.Count, $g12List.Count, $g12ListRight) `
    '1/1/@($chkCrRandom, $chkDcrRandom, $btnLifeSkillPrev, $btnLifeSkillNext, $btnLifeTargetPrev, $btnLifeTargetNext)'
  $g12Register = @(Get-TopIndexWhere { param($statement) ($statement -is [System.Management.Automation.Language.ForEachStatementAst]) -and ($statement.Condition.Extent.Text -ceq '$script:lockedTextControls') })
  $g12RegisterText = $(if ($g12Register.Count -eq 1) { Get-NormalizedText -Text $topStatements[$g12Register[0]].Extent.Text } else { '' })
  Assert-Case 'G12 등록 = 최상위 foreach 1곳 · 그 목록을 돌며 Add_Paint 에 명명 함수 한 줄 · 그 처리기를 부르는 곳은 여기뿐' ('{0}/{1}/{2}' -f $g12Register.Count, $g12RegisterText, (Get-CommandOwnerText -CommandName 'Invoke-LockedTextPaint')) `
    '1/foreach ($lockedTextControl in $script:lockedTextControls) { $lockedTextControl.Add_Paint({ Invoke-LockedTextPaint -Sender $this -PaintArgs $_ }) }/(함수 밖)×1'
  $g12Late = @()
  foreach ($g12Creation in @('$chkCrRandom = New-Object System.Windows.Forms.CheckBox', '$chkDcrRandom = New-Object System.Windows.Forms.CheckBox', '$btnLifeSkillPrev = New-Object System.Windows.Forms.Button',
      '$btnLifeSkillNext = New-Object System.Windows.Forms.Button', '$btnLifeTargetPrev = New-Object System.Windows.Forms.Button', '$btnLifeTargetNext = New-Object System.Windows.Forms.Button')) {
    $g12CreationIndex = @(Get-TopIndexWhere { param($statement) $statement.Extent.Text -ceq $g12Creation })
    if (($g12CreationIndex.Count -ne 1) -or ($g12List.Count -ne 1) -or ($g12CreationIndex[0] -ge $g12List[0])) { $g12Late += $g12Creation }
  }
  # 해/달 아이콘 생성과의 앞뒤는 고정하지 않습니다(11-13 리뷰 지적 - 계약 근거 없는 고정): 이 블록은 아이콘과 탭 순서 · 배치 · 처리기 어느 쪽으로도 엮이지 않고,
  # 처리기는 창이 뜬 뒤 메시지 루프에서만 불려 블록을 아이콘 앞으로 옮겨도 동작이 같습니다. 지켜야 하는 순서는 셋입니다 - 목록 대입이 여섯 생성 문장보다 앞이면
  # 없는 컨트롤($null)을 담고, 등록이 목록 대입보다 앞이면 빈 목록을 돌아 처리기가 붙지 않고, 등록이 창 띄우기(ShowDialog - 창이 닫힐 때까지 돌아오지 않음) 뒤면
  # 창이 닫힌 뒤에야 처리기가 붙습니다(이 셋째는 리뷰 반영 중에 찾음 - 블록을 파일 끝으로 옮긴 변이가 모든 행을 통과했음).
  # 창 띄우기는 try 본문의 글자가 아니라 실제 호출 노드로 찾습니다(Get-ShowDialogSite - 11-13 리뷰 반영: 호출을 지우고 주석만 남기면 번호가 비어 이 행이 실패함)
  $g12Show = @((Get-ShowDialogSite).TryIndexes)
  Assert-Case 'G12 순서 - 여섯 컨트롤 생성 문장(각 최상위 1) < 목록 대입 < 등록 < 창 띄우기(ShowDialog try 1)' ('[{0}]/{1}/{2}' -f ($g12Late -join ','), $g12Show.Count,
      (($g12List.Count -eq 1) -and ($g12Register.Count -eq 1) -and ($g12Show.Count -eq 1) -and ($g12List[0] -lt $g12Register[0]) -and ($g12Register[0] -lt $g12Show[0]))) '[]/1/True'
  $g12RunningAst = Get-FunctionAstOf -Name 'Set-UiRunning'
  $g12RunningLast = Get-NormalizedText -Text (@($g12RunningAst.Body.EndBlock.Statements) | Select-Object -Last 1).Extent.Text
  $g12RunningReturns = @($g12RunningAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.ReturnStatementAst] }, $true)).Count
  Assert-Case 'G12 Set-UiRunning 의 마지막 문장 = 다시 그리기(앞에서 일찍 끝내는 return 0) · 다시 그리기를 부르는 곳 = Set-UiRunning 1곳뿐' ('{0}/{1}/{2}' -f $g12RunningLast, $g12RunningReturns,
      (Get-CommandOwnerText -CommandName 'Update-LockedTextRepaint')) 'Update-LockedTextRepaint/0/Set-UiRunning×1'
  $g12PaintAst = Get-FunctionAstOf -Name 'Invoke-LockedTextPaint'
  $g12PaintStatements = @($g12PaintAst.Body.EndBlock.Statements)
  $g12PaintTrys = @($g12PaintAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true))
  $g12PaintOuter = @($g12PaintTrys | Where-Object { -not (Test-LogWrapperTry -TryAst $_) })
  $g12PaintShape = '{0}/{1}/{2}' -f $g12PaintStatements.Count, $g12PaintTrys.Count, $g12PaintOuter.Count
  if (($g12PaintStatements.Count -eq 1) -and ($g12PaintOuter.Count -eq 1)) {
    $g12PaintShape += ('/{0}/catch {1}/finally {2}' -f ($g12PaintStatements[0] -eq $g12PaintOuter[0]), $g12PaintOuter[0].CatchClauses.Count, ($null -ne $g12PaintOuter[0].Finally))
  }
  Assert-Case 'G12 처리기 본체 - 함수 본문 = try 1문장(그 밖의 문장 0) · catch 1절 · finally 없음 · 그 밖의 try 는 감싼 로그 1곳뿐(호출 수/감싼 수 1/1)' ('{0} · {1}' -f $g12PaintShape,
      (Get-AddGuiLogWrapText -Name 'Invoke-LockedTextPaint')) '1/2/1/True/catch 1/finally False · 1/1'
  $g12DrawCalls = @($g12PaintAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -ceq 'DrawText') }, $true))
  $g12DrawText = '호출 {0}' -f $g12DrawCalls.Count
  if (($g12DrawCalls.Count -eq 1) -and ($g12PaintOuter.Count -eq 1)) {
    $g12DrawInTry = $false
    $g12Ancestor = $g12DrawCalls[0].Parent
    while ($g12Ancestor) {
      if ($g12Ancestor -eq $g12PaintOuter[0].Body) { $g12DrawInTry = $true }
      $g12Ancestor = $g12Ancestor.Parent
    }
    $g12DrawArguments = @($g12DrawCalls[0].Arguments | ForEach-Object { $_.Extent.Text })
    $g12DrawText = '{0}/{1}/{2}/{3}' -f $g12DrawCalls.Count, $g12DrawInTry, $g12DrawArguments.Count, ($g12DrawArguments -join ' · ')
  }
  # 인자 여섯을 모두 원문으로 맞댑니다(11-13 리뷰 지적): 글자 · 글꼴 · 색만 보면 그리는 사각형을 Paint 의 다시 그릴 사각형(ClipRectangle)으로 바꿔도 통과합니다 -
  # 실행 행의 두 그리기(OnPaint 직접 · DrawToBitmap)는 늘 컨트롤 전체 사각형을 넘겨 그림이 같고, 화면에서는 컨트롤 일부만 다시 그려질 때 글자가 그 조각의 가운데로 갑니다
  Assert-Case 'G12 덧그리기 - DrawText 1곳(try 본문 안) · 인자 6개 = Paint 의 그림판 · 그 컨트롤의 글자 · 글꼴 · 안쪽 사각형 · 흐린 글자색 변수 · 정렬 플래그 변수' $g12DrawText `
    '1/True/6/$PaintArgs.Graphics · [string]$Sender.Text · $Sender.Font · $Sender.ClientRectangle · $script:themeMuted · $lockedTextFlags'
  # 정렬 플래그 = 가운데 정렬 한 줄(설계 7.2 - 여섯 컨트롤의 글자 배치). 실행 행의 '자리' 는 이 PC 의 글자 렌더링 실측에 기대므로(허용 3화소 - 왼쪽 정렬 변이의
  # 화살표 차이는 3.5) 그 대입문을 원문으로도 고정합니다
  $g12Flags = @($g12PaintAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -ceq '$lockedTextFlags') }, $true))
  Assert-Case 'G12 덧그리기 정렬 - 플래그 대입 1곳 = 가로 가운데 · 세로 가운데 · 한 줄' ('{0}/{1}' -f $g12Flags.Count, $(if ($g12Flags.Count -eq 1) { Get-NormalizedText -Text $g12Flags[0].Right.Extent.Text } else { '' })) `
    '1/[System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::SingleLine'
  $g12Functions = @('Test-LockedTextOverdraw', 'Invoke-LockedTextPaint', 'Update-LockedTextRepaint')
  $g12DefinitionCounts = (@($g12Functions | ForEach-Object { $g12Name = $_; @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $g12Name) }, $true)).Count })) -join ','
  $g12Closures = @($g12Functions | Where-Object { [regex]::Matches((Get-FunctionCode -Name $_), 'GetNewClosure').Count -gt 0 })
  $g12MultiCatch = @($g12Functions | Where-Object { @((Get-FunctionAstOf -Name $_).FindAll({ param($node) ($node -is [System.Management.Automation.Language.TryStatementAst]) -and ($node.CatchClauses.Count -gt 1) }, $true)).Count -gt 0 })
  Assert-Case 'G12 함수 셋 - 파일 전체 정의 각 1 · 본문 · 등록 문장 안 GetNewClosure 0 · try 마다 catch 1절 이하 · 판정 함수를 부르는 곳 = 처리기 본체 1곳' ('{0}/[{1}]/{2}/[{3}]/{4}' -f $g12DefinitionCounts, ($g12Closures -join ','),
      [regex]::Matches($g12RegisterText, 'GetNewClosure').Count, ($g12MultiCatch -join ','), (Get-CommandOwnerText -CommandName 'Test-LockedTextOverdraw')) '1,1,1/[]/0/[]/Invoke-LockedTextPaint×1'
} catch { Assert-SectionError -Section 'G12' -ErrorRecord $_ }
function Get-CSharpMethodCode {
  # 장치 원문(C#)에서 머리글로 시작하는 블록 하나(머리글부터 짝이 맞는 닫는 중괄호까지)를, 줄 주석을 빼고 공백 덩어리를 하나로 줄여 돌려줍니다.
  # 머리글이 없거나 둘 이상이면 '' - 원문 단언이 주석 속 낱말에 걸리지 않게 하고, 줄바꿈 · 들여쓰기 차이에는 흔들리지 않게 합니다.
  # 원문의 주석은 줄 주석(//)뿐이고 문자열 리터럴에는 '//' 와 중괄호가 없습니다(있게 되면 이 도우미부터 고칠 것 - 아래 준비 행이 블록 수로 드러냄)
  param([string]$Source, [string]$Header)
  $methodCode = ((($Source -split "`r?`n") | ForEach-Object { $_ -replace '//.*$', '' }) -join ' ') -replace '\s+', ' '
  $headerHits = [regex]::Matches($methodCode, [regex]::Escape($Header))
  if ($headerHits.Count -ne 1) { return '' }
  $openIndex = $methodCode.IndexOf('{', $headerHits[0].Index)
  if ($openIndex -lt 0) { return '' }
  $braceDepth = 0
  for ($charIndex = $openIndex; $charIndex -lt $methodCode.Length; $charIndex++) {
    if ($methodCode[$charIndex] -eq '{') { $braceDepth++ }
    elseif ($methodCode[$charIndex] -eq '}') {
      $braceDepth--
      if ($braceDepth -eq 0) { return $methodCode.Substring($headerHits[0].Index, $charIndex - $headerHits[0].Index + 1) }
    }
  }
  return ''
}
try {
  # ── G13 다크 입력 칸 통일 배선 (11-14 - 부르는 곳 · 형식 올리기 · 장치 목록 · 경고 보관 · 장치 원문의 예외 경계 / 설계 7.14 - 넘기기 · 맨 위일 때만 떼기 · 떼기의 반환과 호출) ──
  # 일괄 적용(Apply-HoneyTheme)은 이 기능으로 바뀌지 않았습니다 - 위 G7 의 원문 일치가 그대로 지킵니다. 공용 갱신의 문장 순서(8a · 12 가 끼어든 자리)는 G2 가 봅니다
  # 부르는 곳: 켜고 끄기(8a)와 경고 기록(12)은 공용 갱신 안 각 1곳뿐이고(파일 최상위의 시작 경로 · 다른 함수에 없음), 공용 갱신 본문의 바로 아래 문장으로 -
  # 조건 안이 아니라 - 시작 모드의 return 뒤에 있습니다. 시작 모드에서 부르면 라이트만 쓰는 실행의 시작 경로가 이 기능을 지나갑니다(계약 L)
  $g13RefreshStatements = @((Get-FunctionAstOf -Name 'Invoke-HoneyThemeRefresh').Body.EndBlock.Statements)
  $g13StartReturn = @()
  $g13Update = @()
  $g13Warning = @()
  $g13Restore = @()
  $g13Title = @()
  for ($statementIndex = 0; $statementIndex -lt $g13RefreshStatements.Count; $statementIndex++) {
    $g13Statement = $g13RefreshStatements[$statementIndex]
    $g13StatementText = Get-NormalizedText -Text $g13Statement.Extent.Text
    if (($g13Statement -is $ifType) -and ($g13Statement.Clauses[0].Item1.Extent.Text -ceq '-not $Full') -and
      (@($g13Statement.FindAll({ param($node) $node -is [System.Management.Automation.Language.ReturnStatementAst] }, $true)).Count -ge 1)) { $g13StartReturn += $statementIndex }
    if ($g13StatementText -ceq 'Update-InputRecolor') { $g13Update += $statementIndex }
    if ($g13StatementText -ceq 'Write-InputRecolorWarning') { $g13Warning += $statementIndex }
    if ($g13StatementText.StartsWith('Restore-ThemeState ', [System.StringComparison]::Ordinal)) { $g13Restore += $statementIndex }
    if ($g13StatementText.StartsWith('Set-TitleBarTheme ', [System.StringComparison]::Ordinal)) { $g13Title += $statementIndex }
  }
  $g13Placed = ((@($g13StartReturn, $g13Update, $g13Warning, $g13Restore, $g13Title) | Where-Object { $_.Count -ne 1 }).Count -eq 0)
  Assert-Case 'G13 부르는 곳 - 켜고 끄기(8a) · 경고 기록(12) = 공용 갱신 안 각 1곳뿐(파일 최상위 · 다른 함수 0) · 공용 갱신 본문의 바로 아래 문장(인자 없음) · 8a 는 시작 모드의 return 뒤 · 12 는 복원(10) · 제목줄(11) 뒤 맨 끝' `
    ('{0} | {1} | {2}/{3}/{4}/{5}/{6} | {7}' -f (Get-CommandOwnerText -CommandName 'Update-InputRecolor'), (Get-CommandOwnerText -CommandName 'Write-InputRecolorWarning'),
      $g13StartReturn.Count, $g13Update.Count, $g13Warning.Count, $g13Restore.Count, $g13Title.Count,
      ($g13Placed -and ($g13Update[0] -gt $g13StartReturn[0]) -and ($g13Warning[0] -gt $g13Restore[0]) -and ($g13Warning[0] -gt $g13Title[0]) -and ($g13Warning[0] -eq ($g13RefreshStatements.Count - 1)))) `
    'Invoke-HoneyThemeRefresh×1 | Invoke-HoneyThemeRefresh×1 | 1/1/1/1/1 | True'
  Assert-Case 'G13 부르는 곳 - 장치 만들기 = 켜고 끄기 안 1곳 · 색 대응 = 켜고 끄기 안 1곳 · 대상 찾기 = 장치 만들기 1곳 + 제 안의 재귀 1곳 · 고장 알림 = 장치 만들기 안 1곳(알림 대리자) · 테두리색 = 색 대응 안 2곳' `
    ('{0} | {1} | {2} | {3} | {4}' -f (Get-CommandOwnerText -CommandName 'Initialize-InputRecolor'), (Get-CommandOwnerText -CommandName 'Get-InputRecolorPlan'), (Get-CommandOwnerText -CommandName 'Get-InputRecolorTargets'),
      (Get-CommandOwnerText -CommandName 'Invoke-InputRecolorFaultNotice'), (Get-CommandOwnerText -CommandName 'Get-InputRecolorBorderColor')) `
    'Update-InputRecolor×1 | Update-InputRecolor×1 | Get-InputRecolorTargets×1,Initialize-InputRecolor×1 | Initialize-InputRecolor×1 | Get-InputRecolorPlan×2'
  # 로그: 켜고 끄기(8a)는 로그를 쓰지 않습니다(경고는 보관만 - 8a 에서 쓰면 로그를 접은 화면에서 생긴 배지를 10번이 덮음). 기록은 12 와 고장 알림의 감싼 1줄뿐입니다.
  # 공용 갱신은 안에서 예외를 받지 않으므로(위 G8 '갱신 본문 try 0') 12 의 로그가 감싸여 있지 않으면 기록 실패가 이미 끝난 전환을 되돌립니다
  Assert-Case 'G13 로그 - 켜고 끄기 0 · 장치 만들기 0 · 경고 기록 1(감쌈) · 고장 알림 1(감쌈) (호출 수/감싼 수) · 켜고 끄기 본문(주석 뺀 원문)에 Add-GuiLog 낱말 0' `
    ('{0} {1} {2} {3} · {4}' -f (Get-AddGuiLogWrapText -Name 'Update-InputRecolor'), (Get-AddGuiLogWrapText -Name 'Initialize-InputRecolor'), (Get-AddGuiLogWrapText -Name 'Write-InputRecolorWarning'),
      (Get-AddGuiLogWrapText -Name 'Invoke-InputRecolorFaultNotice'), [regex]::Matches((Get-FunctionCode -Name 'Update-InputRecolor'), 'Add-GuiLog').Count) '0/0 0/0 1/1 1/1 · 0'
  # 형식 올리기: 장치 원문으로 Add-Type 하는 곳은 장치 만들기 안 1곳이고, 형식이 이미 있으면 건너뜁니다(같은 이름의 형식을 두 번 올리면 실패 - 라이트 → 다크를 여러 번 오가도 한 번만)
  $g13AddTypes = @(@($commandSites['Add-Type']) | Where-Object { $_.Extent.Text.Contains('Get-InputRecolorTypeSource') })
  $g13AddTypeText = '곳 {0}' -f $g13AddTypes.Count
  if ($g13AddTypes.Count -eq 1) {
    $g13AddTypeBlock = $g13AddTypes[0].Parent.Parent
    $g13AddTypeIf = $g13AddTypeBlock.Parent
    $g13AddTypeCondition = '조건 없음'
    if ($g13AddTypeIf -is $ifType) {
      foreach ($g13Clause in $g13AddTypeIf.Clauses) { if ($g13Clause.Item2 -eq $g13AddTypeBlock) { $g13AddTypeCondition = Get-NormalizedText -Text $g13Clause.Item1.Extent.Text } }
    }
    $g13AddTypeText = '{0}/{1}/{2}/{3}' -f $g13AddTypes.Count, (Get-AstOwnerName -Ast $g13AddTypes[0]), $g13AddTypeCondition, (Get-NormalizedText -Text $g13AddTypes[0].Extent.Text)
  }
  Assert-Case 'G13 형식 올리기 - 장치 원문으로 Add-Type 하는 곳 1 · 장치 만들기 안 · 형식이 없을 때만(이름으로 찾음) · 원문 함수를 부르는 곳도 그 1곳' ('{0} | {1}' -f $g13AddTypeText, (Get-CommandOwnerText -CommandName 'Get-InputRecolorTypeSource')) `
    ("1/Initialize-InputRecolor/-not ('HoneyInputRecolor' -as [type])/Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition (Get-InputRecolorTypeSource) | Initialize-InputRecolor×1")
  # 장치 목록: 스크립트 범위 변수에 잡아 둡니다(지역 변수면 함수가 끝난 뒤 수거돼 장치가 사라짐). 대입은 최상위 초기화($null = 만든 적 없음)와 장치 만들기의 마지막 문장뿐 -
  # 전부 만든 뒤 한 번에 대입해야 도중에 실패했을 때 목록이 없음 그대로 남습니다. 원인 · 보관된 경고도 $null 로 시작합니다('비어 있을 때만' 을 $null 비교로 가름)
  $g13ListAssignments = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -ceq '$script:inputRecolorPainters') }, $true))
  $g13InitializeAst = Get-FunctionAstOf -Name 'Initialize-InputRecolor'
  $g13InitializeLast = Get-NormalizedText -Text (@($g13InitializeAst.Body.EndBlock.Statements) | Select-Object -Last 1).Extent.Text
  $g13StateInitials = (@('$script:inputRecolorPainters', '$script:inputRecolorError', '$script:inputRecolorPendingWarning') | ForEach-Object {
      $g13StateLeft = $_
      (@($topStatements | Where-Object { ($_ -is $assignType) -and ($_.Left.Extent.Text -ceq $g13StateLeft) } | ForEach-Object { Get-NormalizedText -Text $_.Right.Extent.Text })) -join '+' }) -join ','
  Assert-Case 'G13 장치 목록 - 대입 = 최상위 초기화 1 + 장치 만들기 1(그 함수의 마지막 문장) · 최상위 상태 셋의 초기값 $null' `
    ('{0} | {1} | {2}' -f ((@($g13ListAssignments | ForEach-Object { Get-AstOwnerName -Ast $_ })) -join ','), $g13InitializeLast.StartsWith('$script:inputRecolorPainters = ', [System.StringComparison]::Ordinal), $g13StateInitials) `
    '(함수 밖),Initialize-InputRecolor | True | $null,$null,$null'
  # 장치 만들기의 뒷정리: 만드는 반복은 try 안이고, catch 가 만든 장치를 떼고(Detach) 다시 던집니다(행동은 T18d '장치 만들기가 도중에 실패' 행이 봄)
  $g13InitializeTrys = @($g13InitializeAst.FindAll({ param($node) $node -is $tryType }, $true))
  $g13CleanupText = 'try {0}' -f $g13InitializeTrys.Count
  if ($g13InitializeTrys.Count -eq 1) {
    $g13CleanupText = '{0}/{1}/{2}/{3}/{4}' -f $g13InitializeTrys.Count, $g13InitializeTrys[0].CatchClauses.Count,
      @($g13InitializeTrys[0].Body.FindAll({ param($node) ($node -is $commandType) -and ($node.GetCommandName() -eq 'New-Object') -and $node.Extent.Text.Contains('HoneyInputRecolor') }, $true)).Count,
      @($g13InitializeTrys[0].CatchClauses[0].Body.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -ceq 'Detach') }, $true)).Count,
      @($g13InitializeTrys[0].CatchClauses[0].Body.FindAll({ param($node) $node -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)).Count
  }
  Assert-Case 'G13 장치 만들기의 뒷정리 - try 1 · catch 1절 · 장치 생성(New-Object)이 try 본문 안 1곳 · catch 에 떼기(Detach) 1 · 다시 던지기 1' $g13CleanupText '1/1/1/1/1'
  # 함수 여덟: 파일 전체에 정의 각 1 · GetNewClosure 0(함수 안 클로저는 $script: 변수를 못 읽음 - 규칙 3) · try 마다 catch 1절 이하(규칙 3)
  $g13Functions = @('Get-InputRecolorTypeSource', 'Get-InputRecolorTargets', 'Get-InputRecolorBorderColor', 'Get-InputRecolorPlan', 'Initialize-InputRecolor', 'Invoke-InputRecolorFaultNotice',
    'Update-InputRecolor', 'Write-InputRecolorWarning')
  $g13DefinitionCounts = (@($g13Functions | ForEach-Object { $g13Name = $_; @($guiAst.FindAll({ param($node) ($node -is $functionType) -and ($node.Name -eq $g13Name) }, $true)).Count })) -join ','
  $g13Closures = @($g13Functions | Where-Object { [regex]::Matches((Get-FunctionCode -Name $_), 'GetNewClosure').Count -gt 0 })
  $g13MultiCatch = @($g13Functions | Where-Object { @((Get-FunctionAstOf -Name $_).FindAll({ param($node) ($node -is $tryType) -and ($node.CatchClauses.Count -gt 1) }, $true)).Count -gt 0 })
  Assert-Case 'G13 함수 여덟 - 파일 전체 정의 각 1 · 본문 안 GetNewClosure 0 · try 마다 catch 1절 이하' ('{0}/[{1}]/[{2}]' -f $g13DefinitionCounts, ($g13Closures -join ','), ($g13MultiCatch -join ',')) '1,1,1,1,1,1,1,1/[]/[]'
  # 장치 원문(C#)의 예외 경계 - 핸들 생성 처리기 · 알림 본문 밖으로 예외가 새면 모달 오류 창이 떠 무인 운용이 멈추고, 장치의 창 프로시저 밖으로 새면 조용히 삼켜져
  # 그 칸이 못 그려진 채 남습니다(제품의 기본 예외 모드 - T18f 머리 주석). 네 경로(창 프로시저의 그리기 둘 · 핸들 생성 처리기의 붙이기 ·
  # 알림 예약 · 알림 본문)가 모두 받고, 고장은 한 곳(Fault)이 첫 오류를 적고 그 장치를 끕니다. 행동은 T18f 가 사본으로 보고(창 프로시저의 받기 · 끄기 · 알림 본문),
  # 여기서는 헤드리스에서 일으킬 수 없는 자리까지 원문으로 봅니다: 붙이기의 받기 · 앞 핸들 놓기(맨 위일 때만) · 창 프로시저를 못 읽으면 붙지 않음 · 알림 예약의 받기 ·
  # 화면 그리기 실패 뒤의 다시 그리기 요청. 11-14 설계 7.14 의 넘기기 · 떼기도 여기서 계약으로 봅니다(글자 그대로가 아니라 순서 · 갈래 · 개수 - 행동은 T18g ·
  # 문지기 사슬 행): 맡지 않는 메시지와 그림 받기는 붙기 직전의 창 프로시저로(Pass) · 떼기는 맨 위일 때만(ReleaseIfTop) · Detach 는 참/거짓 · 붙은 채 남은 장치는 붙잡아 둠.
  # 장치 원문 전체의 개수 단언은 줄 주석을 뺀 사본($g13SourceCode)으로 합니다 - 원문의 주석이 base.WndProc · DefWndProc 를 낱말로 적고 있습니다
  $g13Source = Get-InputRecolorTypeSource
  $g13SourceCode = ((($g13Source -split "`r?`n") | ForEach-Object { $_ -replace '//.*$', '' }) -join ' ') -replace '\s+', ' '
  $g13Constructor = Get-CSharpMethodCode -Source $g13Source -Header 'public HoneyInputRecolor(Control owner, Control target)'
  $g13Attach = Get-CSharpMethodCode -Source $g13Source -Header 'void Attach()'
  $g13Pass = Get-CSharpMethodCode -Source $g13Source -Header 'void Pass(ref Message m)'
  $g13ReleaseIfTop = Get-CSharpMethodCode -Source $g13Source -Header 'bool ReleaseIfTop()'
  $g13Detach = Get-CSharpMethodCode -Source $g13Source -Header 'public bool Detach()'
  $g13Fault = Get-CSharpMethodCode -Source $g13Source -Header 'void Fault(Exception ex)'
  $g13Notify = Get-CSharpMethodCode -Source $g13Source -Header 'void NotifyFault()'
  $g13WndProc = Get-CSharpMethodCode -Source $g13Source -Header 'protected override void WndProc(ref Message m)'
  $g13Render = Get-CSharpMethodCode -Source $g13Source -Header 'void Render(IntPtr targetDc, ColorMatrix matrix, bool excludeChildren)'
  Assert-Case 'G13 장치 원문 준비 - 형식 선언(NativeWindow 를 물려받은 sealed 형식) 1 · 생성자 · 붙이기 · 넘기기 · 맨 위일 때만 떼기 · 떼기(bool) · 고장 처리 · 알림 본문 · 창 프로시저 · 그리기 블록을 각각 찾음' `
    ('{0}/{1}' -f [regex]::Matches($g13Source, 'public sealed class HoneyInputRecolor : NativeWindow \{').Count,
      ((@($g13Constructor, $g13Attach, $g13Pass, $g13ReleaseIfTop, $g13Detach, $g13Fault, $g13Notify, $g13WndProc, $g13Render) | ForEach-Object { $_ -ne '' }) -join ',')) `
    '1/True,True,True,True,True,True,True,True,True'
  Assert-Case 'G13 장치 원문 - 생성자: 핸들 생성 구독 · 핸들이 이미 있을 때만 바로 붙임 · 핸들을 읽지 않음(억지로 만들지 않음)' `
    ('{0}/{1}/{2}' -f $g13Constructor.Contains('target.HandleCreated += OnTargetHandleCreated;'), $g13Constructor.Contains('if (target.IsHandleCreated) { Attach(); }'), [regex]::Matches($g13Constructor, '\.Handle\b(?!Created)').Count) 'True/True/0'
  # 붙이기(11-14 설계 7.14 - 글자 그대로 대신 계약): ① 본문 전체가 try 한 덩어리(try · catch 각 1 · 처음과 끝)이고 예외는 고장 처리로 ② 앞 핸들 놓기는 맨 위 확인(ReleaseIfTop)을
  # 지나고 맨 위가 아니면 던져 붙지 않음(AssignHandle 앞) ③ 직접 놓기(ReleaseHandle) 0 ④ 붙기 직전 창 프로시저 읽기가 AssignHandle 앞이고 0 이면 바로 던져 붙지 않음
  # ⑤ 읽은 값이 chainProc 로(AssignHandle 앞 · 대입 1곳) ⑥ selfProc 는 AssignHandle 뒤에 같은 창에서 읽음(대입 1곳). 뒤에 읽으면 넘기기가 자신을 가리켜 메시지 하나로
  # 프로세스가 죽고(행동 쪽은 문지기 사슬 행이 메시지 전에 잡음), 0 을 그대로 쓰면 넘기기가 기본 넘기기로 떨어져 사이의 서브클래스를 건너뜁니다(관측 불가 - 원문으로만 지킴)
  $g13AssignHits = [regex]::Matches($g13Attach, '\bAssignHandle\((\w+)\);')
  $g13AttachText = 'AssignHandle {0}곳' -f $g13AssignHits.Count
  if ($g13AssignHits.Count -eq 1) {
    $g13AssignIndex = $g13AssignHits[0].Index
    $g13HandleName = [regex]::Escape($g13AssignHits[0].Groups[1].Value)
    $g13Gate = [regex]::Match($g13Attach, 'if \(!ReleaseIfTop\(\)\) \{ throw ')
    $g13ChainRead = [regex]::Match($g13Attach, ('IntPtr (\w+) = GetWindowLongPtr\(' + $g13HandleName + ', GWLP_WNDPROC\); if \(\1 == IntPtr\.Zero\) \{ throw '))
    $g13ChainSet = $(if ($g13ChainRead.Success) { [regex]::Match($g13Attach, ('\bchainProc = ' + [regex]::Escape($g13ChainRead.Groups[1].Value) + ';')) } else { $null })
    $g13SelfRead = [regex]::Match($g13Attach, ('\bselfProc = GetWindowLongPtr\(' + $g13HandleName + ', GWLP_WNDPROC\);'))
    $g13AttachText = '{0}/{1}/{2}/{3}/{4}/{5}' -f
      ($g13Attach.StartsWith('void Attach() { try { ', [System.StringComparison]::Ordinal) -and $g13Attach.EndsWith(' } catch (Exception ex) { Fault(ex); } }', [System.StringComparison]::Ordinal) -and
        ([regex]::Matches($g13Attach, '\btry \{').Count -eq 1) -and ([regex]::Matches($g13Attach, '\bcatch \(').Count -eq 1)),
      ($g13Gate.Success -and ($g13Gate.Index -lt $g13AssignIndex)),
      [regex]::Matches($g13Attach, '\bReleaseHandle\(').Count,
      ($g13ChainRead.Success -and ($g13ChainRead.Index -lt $g13AssignIndex)),
      (($null -ne $g13ChainSet) -and $g13ChainSet.Success -and ($g13ChainSet.Index -lt $g13AssignIndex) -and ([regex]::Matches($g13Attach, '\bchainProc = ').Count -eq 1)),
      ($g13SelfRead.Success -and ($g13SelfRead.Index -gt $g13AssignIndex) -and ([regex]::Matches($g13Attach, '\bselfProc = ').Count -eq 1))
  }
  Assert-Case 'G13 장치 원문 - 붙이기: 본문 전체가 try 한 덩어리 · 예외는 고장 처리로 / 앞 핸들 놓기는 맨 위 확인(ReleaseIfTop)을 지나고 맨 위가 아니면 던져 붙지 않음 / 직접 놓기 0 / 붙기 직전 창 프로시저 읽기가 AssignHandle 앞 · 0 이면 던져 붙지 않음 / 그 값이 chainProc 로 / selfProc 는 AssignHandle 뒤에 읽음' `
    $g13AttachText 'True/True/0/True/True/True'
  # 넘기기(11-14 설계 7.14): 붙기 직전의 창 프로시저(chainProc)로 CallWindowProc 하고 그 결과를 메시지 결과로. 기본 넘기기(base.WndProc)는 chainProc 이 없을 때(0)만이고
  # 장치 원문 전체에서 그 한 곳뿐 · DefWndProc 직접 호출 0 - 기본 넘기기는 같은 핸들에 먼저 붙은 관리 창(컨트롤 자신)을 바로 불러 그 사이의 서브클래스(말풍선 중계)를 건너뜁니다
  Assert-Case 'G13 장치 원문 - 넘기기(Pass): chainProc 이 0 이면 기본 넘기기 후 끝 · 아니면 결과 = CallWindowProc(chainProc, 받은 메시지 그대로) / 장치 원문 전체의 base.WndProc 1곳(그 갈래뿐) · DefWndProc 0' `
    ('{0}/{1}/{2}/{3}' -f $g13Pass.Contains('if (chainProc == IntPtr.Zero) { base.WndProc(ref m); return; }'), $g13Pass.Contains('m.Result = CallWindowProc(chainProc, m.HWnd, m.Msg, m.WParam, m.LParam);'),
      [regex]::Matches($g13SourceCode, '\bbase\.WndProc\(').Count, [regex]::Matches($g13SourceCode, '\bDefWndProc\(').Count) 'True/True/1/0'
  # 그리기 안의 그림 받기(11-14 설계 7.14): 장치가 컨트롤에 제 모양을 그리게 보내는 WM_PRINTCLIENT 도 넘기기(Pass)로 - 그 그림 받기도 사이의 서브클래스를 지납니다
  # (행동은 T18g X · Z · R 의 '장치 안의 그림 받기' 셈). 기본 넘기기 · DefWndProc · CallWindowProc 를 그리기에서 직접 부르지 않습니다
  $g13RenderPrint = [regex]::Match($g13Render, 'Message (\w+) = Message\.Create\(Handle, WM_PRINTCLIENT, [^;]*\); Pass\(ref \1\);')
  Assert-Case 'G13 장치 원문 - 그리기 안의 그림 받기: WM_PRINTCLIENT 메시지를 만들어 넘기기(Pass)로 보냄 · 그리기 안의 넘기기 1곳 · 기본 넘기기 · DefWndProc · CallWindowProc 직접 호출 0' `
    ('{0}/{1}/{2}' -f $g13RenderPrint.Success, [regex]::Matches($g13Render, '\bPass\(').Count, [regex]::Matches($g13Render, '\bbase\.WndProc\(|\bDefWndProc\(|\bCallWindowProc\(').Count) 'True/1/0'
  # 맨 위일 때만 떼기(11-14 설계 7.14 · 설계 리뷰 P2 · P3): 놓기(ReleaseHandle) 앞에서 지금 창 프로시저가 자기 창 프로시저(selfProc)와 다르면 거짓으로 끝냅니다(건드리지 않음 -
  # NativeWindow 의 되돌림은 맨 위가 아닐 때 창 프로시저를 DefWindowProc 로 끊음). 맨 위면 붙기 직전 창 프로시저를 잡아 두고 놓은 뒤 그 값으로 다시 잇고(사이의 서브클래스를
  # 되살림 - 놓기만 하면 컨트롤 자신으로 돌아가 중계가 끊김), 이은 뒤 다시 읽어 다르면 던집니다. 행동은 T18g X 떼기 · '떼기의 맨 위 확인' 행
  $g13ReleaseHits = [regex]::Matches($g13ReleaseIfTop, '\bReleaseHandle\(\);')
  $g13ReleaseText = '놓기 {0}곳' -f $g13ReleaseHits.Count
  if ($g13ReleaseHits.Count -eq 1) {
    $g13ReleaseIndex = $g13ReleaseHits[0].Index
    $g13TopCheck = [regex]::Match($g13ReleaseIfTop, 'GetWindowLongPtr\((\w+), GWLP_WNDPROC\) != selfProc\) \{ return false; \}')
    $g13BelowSave = [regex]::Match($g13ReleaseIfTop, 'IntPtr (\w+) = chainProc;')
    $g13Relink = $null
    $g13Reread = $null
    if ($g13BelowSave.Success) {
      $g13BelowName = [regex]::Escape($g13BelowSave.Groups[1].Value)
      $g13Relink = [regex]::Match($g13ReleaseIfTop, ('SetWindowLongPtr\(\w+, GWLP_WNDPROC, ' + $g13BelowName + '\);'))
      $g13Reread = [regex]::Match($g13ReleaseIfTop, ('if \(GetWindowLongPtr\(\w+, GWLP_WNDPROC\) != ' + $g13BelowName + '\) \{ throw '))
    }
    $g13ReleaseText = '{0}/{1}/{2}/{3}/{4}/{5}' -f $g13ReleaseHits.Count, ($g13TopCheck.Success -and ($g13TopCheck.Index -lt $g13ReleaseIndex)),
      ($g13BelowSave.Success -and ($g13BelowSave.Index -lt $g13ReleaseIndex)), (($null -ne $g13Relink) -and $g13Relink.Success -and ($g13Relink.Index -gt $g13ReleaseIndex)),
      (($null -ne $g13Reread) -and $g13Reread.Success -and ($null -ne $g13Relink) -and $g13Relink.Success -and ($g13Reread.Index -gt $g13Relink.Index)),
      $g13ReleaseIfTop.EndsWith(' return true; }', [System.StringComparison]::Ordinal)
  }
  Assert-Case 'G13 장치 원문 - 맨 위일 때만 떼기(ReleaseIfTop): 놓기(ReleaseHandle) 1곳 · 그 앞에 맨 위 확인(지금 창 프로시저 ≠ selfProc 면 거짓으로 끝) · 그 앞에 붙기 직전 창 프로시저를 잡아 둠 · 놓은 뒤 그 값으로 다시 이음(SetWindowLongPtr) · 이은 뒤 다시 읽어 다르면 던짐 · 끝은 참' `
    $g13ReleaseText '1/True/True/True/True/True'
  # 맨 위일 때만 떼기의 죽은 창 갈래(11-14 구현 리뷰 - 위 행은 이 조건을 보지 않아 지워도 통과했음): 창이 이미 없어진 핸들(WM_NCDESTROY 를 못 받고 남은 장치)은 맨 위 확인
  # 없이 놓고 다시 잇지 않습니다. 이 조건이 빠지면 죽은 창의 창 프로시저 읽기(0)로 맨 위 확인이 거짓이 되어 새 핸들에 붙지 못하고(고장 처리), 다시 잇기는 실패해 던집니다.
  # 그래서 창이 살아 있는지(IsWindow - 그 핸들로 한 번)를 맨 위 확인 앞에서 읽고, 맨 위 확인과 다시 잇기가 둘 다 그 값으로 시작하는지 봅니다. 죽은 창에 붙은 채 남은 장치는
  # 관측된 적이 없고 헤드리스에서 만들려면 창이 없어지는 메시지를 가로채야 해 행동 행을 두지 않았습니다(원문 가드로만 지킴 - 머리 주석의 목록)
  $g13AliveText = '핸들 읽기를 찾지 못함'
  $g13AliveHandleRead = [regex]::Match($g13ReleaseIfTop, '^bool ReleaseIfTop\(\) \{ IntPtr (\w+) = Handle; if \(\1 == IntPtr\.Zero\) \{ return true; \} ')
  if ($g13AliveHandleRead.Success) {
    $g13AliveHandle = [regex]::Escape($g13AliveHandleRead.Groups[1].Value)
    $g13AliveRead = [regex]::Match($g13ReleaseIfTop, ('bool (\w+) = IsWindow\(' + $g13AliveHandle + '\);'))
    $g13AliveBelow = [regex]::Match($g13ReleaseIfTop, 'IntPtr (\w+) = chainProc;')
    $g13AliveTop = $null
    $g13AliveRelink = $null
    if ($g13AliveRead.Success -and $g13AliveBelow.Success) {
      $g13AliveName = [regex]::Escape($g13AliveRead.Groups[1].Value)
      $g13AliveBelowName = [regex]::Escape($g13AliveBelow.Groups[1].Value)
      $g13AliveTop = [regex]::Match($g13ReleaseIfTop, ('if \(' + $g13AliveName + ' && GetWindowLongPtr\(' + $g13AliveHandle + ', GWLP_WNDPROC\) != selfProc\) \{ return false; \}'))
      $g13AliveRelink = [regex]::Match($g13ReleaseIfTop, ('if \(' + $g13AliveName + ' && ' + $g13AliveBelowName + ' != IntPtr\.Zero && GetWindowLongPtr\(' + $g13AliveHandle +
          ', GWLP_WNDPROC\) != ' + $g13AliveBelowName + '\) \{ SetWindowLongPtr\('))
    }
    $g13AliveText = '{0}/{1}/{2}/{3}' -f ($g13AliveRead.Success -and ($null -ne $g13AliveTop) -and $g13AliveTop.Success -and ($g13AliveRead.Index -lt $g13AliveTop.Index)),
      (($null -ne $g13AliveTop) -and $g13AliveTop.Success), (($null -ne $g13AliveRelink) -and $g13AliveRelink.Success), [regex]::Matches($g13ReleaseIfTop, '\bIsWindow\(').Count
  }
  Assert-Case 'G13 장치 원문 - 맨 위일 때만 떼기의 죽은 창 갈래: 창이 살아 있는지(IsWindow - 그 핸들로)를 맨 위 확인 앞에서 읽음 · 맨 위 확인이 그 값으로 시작 · 다시 잇기도 그 값으로 시작 · IsWindow 읽기 1곳' `
    $g13AliveText 'True/True/True/1'
  # 떼기(11-14 설계 7.14 · 설계 리뷰 P2): 참/거짓을 돌려줍니다 - 먼저 끄고 · 핸들 생성 구독을 끊고 · 맨 위일 때만 떼어 참(ReleaseIfTop - 받기 안), 아니면 장치 형식의 정적 목록
  # (retained)에 붙잡아 둔 뒤 거짓(수거되면 창 프로시저에 걸린 대리자가 사라짐). 직접 놓기(ReleaseHandle) 0. 목록에 넣는 것(넣음 · 안 넣음)은 리플렉션으로 읽어 행동 행이
  # 봅니다(T18g '떼기의 맨 위 확인' = 들어감 · T18g X 떼기 = 안 들어감 - 11-14 구현 리뷰: 예전에는 이 원문 행만 지켜 넣는 줄을 늘 거짓인 조건 안으로 옮겨도 통과했음).
  # 그 목록이 실제로 수거를 막는지는 헤드리스에서 관측할 수 없어(그 장치는 컨트롤의 관리 창 연결로도 붙잡혀 있음) 정적 필드 선언을 원문으로 봅니다.
  # 거짓 · 창 프로시저 그대로 · 붙은 채 꺼짐도 T18g '떼기의 맨 위 확인' 행이 행동으로 봄
  $g13DetachTop = $g13Detach.IndexOf('try { if (ReleaseIfTop()) { return true; } } catch (Exception ex) {', [System.StringComparison]::Ordinal)
  $g13DetachRetain = $g13Detach.IndexOf('retained.Add(this);', [System.StringComparison]::Ordinal)
  Assert-Case 'G13 장치 원문 - 떼기(Detach): bool 을 돌려줌 · 먼저 끔 · 핸들 생성 구독 끊기 · 맨 위일 때만 떼고 참(받기 안) · 아니면 정적 목록(retained)에 넣은 뒤 끝에서 거짓 · 직접 놓기 0 · 목록은 장치 형식의 정적 필드 1개' `
    ('{0}/{1}/{2}/{3}/{4}/{5}/{6}' -f $g13Detach.StartsWith('public bool Detach() { Active = false; ', [System.StringComparison]::Ordinal), $g13Detach.Contains('target.HandleCreated -= OnTargetHandleCreated;'),
      ($g13DetachTop -ge 0), (($g13DetachTop -ge 0) -and ($g13DetachRetain -gt $g13DetachTop)), $g13Detach.EndsWith(' return false; }', [System.StringComparison]::Ordinal),
      [regex]::Matches($g13Detach, '\bReleaseHandle\(').Count, [regex]::Matches($g13SourceCode, '\bstatic (?:readonly )?List<HoneyInputRecolor> retained = new List<HoneyInputRecolor>\(\);').Count) 'True/True/True/True/True/0/1'
  # 제품의 떼기 호출(11-14 설계 7.14): Detach 는 참/거짓을 돌려줘 받지 않으면 그 값이 장치 만들기의 출력으로 새어 갱신 함수(8a) · 공용 갱신 · 전환 함수의 출력이 됩니다.
  # 부르는 곳은 파일 전체에서 장치 만들기의 실패 정리 한 곳이고 [void] 로 받습니다(행동은 T18d '장치 만들기가 도중에 실패' 행의 출력 0)
  $g13DetachCalls = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -ceq 'Detach') }, $true))
  Assert-Case 'G13 제품의 떼기 호출 - 파일 전체 1곳 · 장치 만들기 안 · [void] 로 받음' ('{0}/{1}/{2}' -f $g13DetachCalls.Count, ((@($g13DetachCalls | ForEach-Object { Get-AstOwnerName -Ast $_ })) -join ','),
      @($g13DetachCalls | Where-Object { ($_.Parent -is [System.Management.Automation.Language.ConvertExpressionAst]) -and ($_.Parent.Type.TypeName.FullName -eq 'void') }).Count) '1/Initialize-InputRecolor/1'
  Assert-Case 'G13 장치 원문 - 고장 처리: 첫 오류만 적음 · 장치를 끔 · 알림은 한 번만(표시를 먼저 세움) · 예약은 주인에 핸들이 있을 때만 · 예약의 예외를 받음' `
    ('{0}/{1}/{2}/{3}' -f $g13Fault.Contains('if (LastError.Length == 0) { LastError = ex.GetType().Name + ": " + ex.Message; }'), $g13Fault.Contains('Active = false;'),
      $g13Fault.Contains('if (faultNotified || FaultCallback == null) { return; } faultNotified = true;'),
      $g13Fault.Contains('try { if (owner.IsHandleCreated) { owner.BeginInvoke(new Action(NotifyFault)); } } catch (Exception) { }')) 'True/True/True/True'
  Assert-Case 'G13 장치 원문 - 알림 본문: 대리자 호출이 try 안 · 예외를 받음' `
    $g13Notify 'void NotifyFault() { try { Action callback = FaultCallback; if (callback != null) { callback(); } } catch (Exception) { } }'
  # 맡는 메시지의 정의도 원문으로 봅니다(11-14 내부 검토): 화면 그리기는 그릴 대상(DC)이 실려 오지 않은 WM_PAINT 뿐입니다 - 행동은 T18b 'DC 가 실려 온 WM_PAINT' 행이 봄.
  # 맡지 않은 메시지(그리기에 실패한 그림 받기 포함)는 끝의 넘기기(Pass) 한 곳으로 갑니다(11-14 설계 7.14 - 그전에는 base.WndProc: 사이의 서브클래스를 건너뜀. 행동은 T18g X 의 꺼진 · 켠 장치)
  Assert-Case 'G13 장치 원문 - 창 프로시저: 화면 그리기 = 그릴 대상이 실려 오지 않은 WM_PAINT 만 · 켜져 있고 재진입이 아닐 때만 맡음 · 잠금 읽기도 받음 · 그리기(Render) 호출은 둘뿐이고 둘 다 받아 고장 처리로 · 화면 그리기가 실패하면 다시 그리기 요청 · 맡지 않은 메시지는 끝의 넘기기(Pass) 1곳으로 · 기본 넘기기(base.WndProc) · DefWndProc 직접 호출 0' `
    ('{0}/{1}/{2}/{3}/{4}/{5}/{6}/{7}/{8}/{9}' -f $g13WndProc.Contains('bool screenPaint = (m.Msg == WM_PAINT && m.WParam == IntPtr.Zero);'), $g13WndProc.Contains('if (Active && !busy && (screenPaint || printPaint))'),
      $g13WndProc.Contains('try { matrix = owner.Enabled ? EnabledMatrix : DisabledMatrix; } catch (Exception ex) { Fault(ex); }'), [regex]::Matches($g13WndProc, '\bRender\(').Count,
      $g13WndProc.Contains('try { Render(hdc, matrix, true); painted = true; } finally { EndPaint(Handle, ref ps); } } catch (Exception ex) { Fault(ex); } finally { busy = false; }'),
      $g13WndProc.Contains('try { Render(m.WParam, matrix, false); printed = true; } catch (Exception ex) { Fault(ex); } finally { busy = false; }'),
      $g13WndProc.Contains('else { try { InvalidateRect(Handle, IntPtr.Zero, true); } catch (Exception) { } }'), $g13WndProc.EndsWith(' Pass(ref m); }', [System.StringComparison]::Ordinal),
      [regex]::Matches($g13WndProc, '\bPass\(').Count, [regex]::Matches($g13WndProc, '\bbase\.WndProc\(|\bDefWndProc\(').Count) `
    'True/True/True/2/True/True/True/True/1/0'
  # 그리기(Render)의 자식 창 빼기(11-14 내부 검토 - 이 블록을 지키는 행이 없었음): 화면 그리기는 보이는 자식 창(시간 칸의 ▲▼)의 자리를 그리는 영역에서 뺀 뒤에 그림을 옮깁니다
  # (사용자 결정 '▲▼ 는 그대로' 의 화면 쪽 - 위 행의 Render(hdc, matrix, true)). 헤드리스에서는 일으킬 수 없는 자리입니다: 보이지 않는 폼의 자식 창은 '보임' 이 아니라
  # 블록의 안쪽까지 가지 않고, 그림 받기 길(Render(m.WParam, matrix, false))은 이 블록을 타지 않습니다(그 길의 ▲▼ 는 자식 창이 제 그림을 덧찍어 남음 - T18b 화소 분류).
  # 그래서 블록 전체(자식 창 순회 · 보임 확인 · 화면 좌표 → 이 창 좌표 · 그리는 영역에서 빼기)와 그 자리(그림을 옮기는 문장보다 앞)를 원문으로 고정합니다. 화면의 화소는 실기 몫
  $g13ExcludeBlock = 'if (excludeChildren) { IntPtr child = GetWindow(Handle, GW_CHILD); while (child != IntPtr.Zero) { if (IsWindowVisible(child)) { RECT childRect; GetWindowRect(child, out childRect); ' +
    'MapWindowPoints(IntPtr.Zero, Handle, ref childRect, 2); ExcludeClipRect(targetDc, childRect.Left, childRect.Top, childRect.Right, childRect.Bottom); } child = GetWindow(child, GW_HWNDNEXT); } }'
  $g13ExcludeIndex = $g13Render.IndexOf($g13ExcludeBlock, [System.StringComparison]::Ordinal)
  $g13DrawIndex = $g13Render.IndexOf('canvas.DrawImage(', [System.StringComparison]::Ordinal)
  Assert-Case 'G13 장치 원문 - 그리기: 자식 창 빼기 블록 1곳(보이는 자식 창마다 화면 좌표를 이 창 좌표로 바꿔 그리는 영역에서 뺌) · 그림을 옮기는 문장(DrawImage) 1곳보다 앞 · 자식 창 순회 상수(첫 자식 5 · 다음 형제 2)' `
    ('{0}/{1}/{2}/{3}' -f [regex]::Matches($g13Render, [regex]::Escape($g13ExcludeBlock)).Count, [regex]::Matches($g13Render, [regex]::Escape('canvas.DrawImage(')).Count,
      (($g13ExcludeIndex -ge 0) -and ($g13DrawIndex -gt $g13ExcludeIndex)), $g13Source.Contains('const uint GW_CHILD = 5, GW_HWNDNEXT = 2;')) '1/1/True/True'
} catch { Assert-SectionError -Section 'G13' -ErrorRecord $_ }

# ── 정리 ──
try { if ($script:form) { $script:form.Dispose() } } catch { }
try { if ($script:cellEditCombo) { $script:cellEditCombo.Dispose() } } catch { }
try { if ($script:lblStatus) { $script:lblStatus.Dispose() } } catch { }
try {
  foreach ($t6File in @([System.IO.Directory]::GetFiles($t6Root))) { [System.IO.File]::Delete($t6File) }
  [System.IO.Directory]::Delete($t6Root, $false)
} catch { "INFO 임시 폴더를 지우지 못했습니다: $t6Root" }

if ($fails -gt 0) { "FAIL 합계 $fails"; exit 1 }
'전부 통과'
exit 0
