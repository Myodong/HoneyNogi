# 회귀 테스트 일괄 실행기 - Windows PowerShell 5.1 로 실행하세요:
#   powershell -ExecutionPolicy Bypass -File tests\run_all_tests.ps1
# 각 test_*.ps1 은 판정 로직의 진리표 테스트로, FAIL 줄이 있거나 종료 코드가 0이 아니면 실패.
# 운영 판정 함수는 source_test_helpers.ps1로 본체 AST에서 직접 추출해 같은 구현을 검사합니다.
#
# ★ 2026-08-10 9차 점검에서 이 러너 자체의 구멍 두 개를 고쳤습니다:
#   ① 자식이 stderr 로 무언가를 뱉으면 `2>&1` 이 그것을 ErrorRecord 로 바꾸고,
#      $ErrorActionPreference='Stop' 이 그것을 **종료 오류**로 승격시켜 **러너가 통째로
#      중단**됐습니다. 그러면 남은 테스트는 '실행조차 안 된 채' 사라지는데 출력에는
#      그 사실이 남지 않습니다 - 회귀 스위트가 조용히 반쪽이 되는 최악의 형태입니다.
#      → 자식 실행 구간만 Continue 로 낮추고 try/catch 로 감싸, 죽은 테스트도 **실패로
#        계상하고 나머지를 계속** 돌립니다.
#   ② 총 개수를 고정하지 않아 **파일이 사라져도 '전부 통과'** 로 끝났습니다.
#      → 기대 개수를 못 박습니다. 테스트를 추가/삭제하면 이 숫자도 함께 고쳐야 합니다.
$ErrorActionPreference = 'Stop'
$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tests = @(Get-ChildItem -Path $testDir -Filter 'test_*.ps1' | Sort-Object Name)

# ★ 2026-09-26 BOM 검사 (파티 모드 설계 v2 8절 관례): 한글 리터럴이 든 .ps1 은 UTF-8 BOM 이 없으면 Windows PowerShell 5.1 이
#   cp949 로 읽어 판독문 픽스처의 조각이 깨진 채 비교되고, 그 결과가 '거짓 통과' 로 끝날 수 있습니다(규칙 2 — Write 도구는 BOM 없이
#   저장). 테스트 파일과 공용 헬퍼의 첫 3바이트를 확인해 하나라도 EF BB BF 가 아니면 경고를 찍고 실패로 끝냅니다.
$bomMissing = @()
foreach ($f in (@($tests) + @(Get-ChildItem -Path $testDir -Filter 'source_test_helpers.ps1'))) {
  $head = @()
  try {
    $fs = [IO.File]::OpenRead($f.FullName)
    try { $buf = New-Object byte[] 3; $n = $fs.Read($buf, 0, 3); if ($n -eq 3) { $head = @($buf[0], $buf[1], $buf[2]) } } finally { $fs.Dispose() }
  } catch { $head = @() }
  if (-not ($head.Count -eq 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)) { $bomMissing += $f.Name }
}
if ($bomMissing.Count -gt 0) {
  "[경고] UTF-8 BOM 이 없는 테스트 파일 $($bomMissing.Count)개 - $($bomMissing -join ', ')"
  '        (한글 픽스처가 깨진 채 비교돼 거짓 통과할 수 있습니다. 규칙 2 의 한 줄로 BOM 을 다시 입혀 주세요:'
  '         [IO.File]::WriteAllText($p, [IO.File]::ReadAllText($p), [Text.UTF8Encoding]::new($true)))'
}

# 기대 테스트 개수 (추가/삭제 시 함께 갱신). 숫자가 어긋나면 실패로 끝냅니다.
$expectedTestCount = 101   # 10-18 +1: test_abyss_party_leader (④ 어비스 재입장 대기 - 결론 우선순위 순수 진리표·대기 골격(동결·양보·스윕 굶김·판독 도중 실패·탐침 복구 뒤)·던전 안 2연속·패널 관측·무변화 창·resume 유예(조작 양보 되돌림·되돌림 뒤 창 포함)·창 좌표 throw 제한 catch(판독·클릭 경로 두 문구)·배선 0 정적) / 10-16 +1: test_abyss_reward_pair_finder (③ 보상 화면 짝 찾기 - '다시 하기'·'다른 던전 가기' 글자 짝 순수 진리표(보관 프레임 판독 단어 목록)·대역·dY·붙은 단어·화면 함수 계약(캡처 실패 = 호출부 플래그)·배선 0 정적) / 10-13 +1: test_after_entry_at_most_once (② 자기 항목·키 인덱스 at-most-once · 코드 10 자기 항목 닫기 · 정리 전용 표지) / 10-12 +1: test_abyss_handoff_start (② 이어받기 시작 경로 - Consume-Handoff 역할·선분기 분류·필드 확정·결론 대입·own 닫기·ownFreshEntry·정지 표지, 본류 시작 구간 하니스) / 10-09 +1: test_abyss_pending_advance (① 완료 기록 대기열 - 큐 기록 형식·단계 3종·저장 실패, 순서 반영·owner 대조 skip·진행 저장 실패 보존·대기열이 빈 뒤에만 마커 정리·반영 도중 끊김 뒤 전진 총 2, 실행부·완주·코드 1·시작 게이트 S0~S3·앱 기동 stale 정리 행) / 10-09 +1: test_abyss_handoff_gui (① GUI 종료 처리 - 공통 최종 수집의 순서·출처별 실패·InsideHandoff 꼬리 숨김을 타이머 틱 그대로 실행, 기동 env·판별·코드 0·11·10·4·1 처리·시작 게이트, 워커 cleared 기록 → GUI 계상 결합 행) / 10-08 +1: test_abyss_custom_owner_generation (① 진행 세대 - owner 5필드 + generation 대조, 진행 초기화 3경로 ②①③·완료 기록 폐기, 세대 +1 섹션 제한, 10→11 구버전 마커, 노드 재작성 세대 이월) / 10-08 +1: test_abyss_journal_store (① handoff journal 저장소 GUI·워커 두 사본 - 원자 교체·잠금·중간 상태 복구·반환 태그·예외 전파·합산 예산, 사본 토큰 동일) / 10-07 +2: test_icon_assets, test_abyss_menu_icon (v2.1.12 어비스 ESC 메뉴 '어비스' 아이콘 폴백 - 아이콘 자산 원본·워커 사본 일치, 매칭 상수 계약·수락 진리표·배선, 저장 캡처 재생) / 10-02 +1: test_time_until_mode (시간 지정 '그 판까지' - GUI 다음 회차 판단·실행 진리표, 타이머·시작 게이트·UNTIL 배선, 문구, 문화권 왕복 - 설계 리뷰 1차 P2) / 10-01 +1: test_abyss_party_member (⑥e 파티원 관측 루프 D·퇴장 절차 P - 순수 진리표·가상 시계 행동·배선) / 09-26 +1: test_abyss_party_signatures (⑥a 파티 준비 패널·파티원 보상·접힌 패널·권장 인원 팝업 서명 - 실기 -1·09-21 캡처 재생, 고치기 전 오판 재현) / 09-25 +1: test_revive_state_machine (부활 상태 머신 - 성공 확인 계상·에피소드 전송 예산·상한 즉시 정지·생략 3갈래, 목록 1절 1번) / 09-21 +1: test_abyss_return_loop (v2.1.12 구현 리뷰 2차 P1 - 복귀 루프 필드 토큰의 양보·캡처 실패 대조, 던전 안 시계 동결 - 행동 진리표) / 09-21 +1: test_abyss_screen_signatures (v2.1.12 던전 안 선택 화면 오판 핫픽스 - 보상 서명·재매칭 패널·fail-closed 배선) / 09-20 +1: test_difficulty_tabs_offline (v2.1.12 어비스 상세 난이도 알약 상단 확장 - 09-15 타 PC 제보 재현) / 09-18 +1: test_abyss_exit_button (v2.1.11 어비스 보상 화면 3버튼 - 나가기 글자 위치 클릭) / 09-16 +1: test_dg_card_console_offline (v2.1.10 콘솔 카드 '태되' 조각 재현) / 09-16 +1: test_abyss_chance_toggle_yield (v2.1.10 우연한 만남 켜기 양보·팝업 복구) / 09-15 +1: test_nyan_gold_offline (v2.1.10 골드 앞자리 소실 재현) / 09-15 +1: test_quest_tracker_offline (v2.1.9 타 PC 트래커 상단 잘림 재현) / 09-14 +1: test_nyan_cards_scale_offline (v2.1.9 카드 존 배율 라벨 재현) / 08-20 +1: test_dg_pill_highlight (v2.1.2) / 09-01 +1: test_embedded_host (v2.1.4) / 09-07 +1: test_dg_card_console (v2.1.6) / 09-08 +1: test_yield_batch (v2.1.7) / 09-09 +1: test_life_cycle_deadline (v2.1.8) / 09-09 +1: test_life_scroll_yield (v2.1.8 실기 실측) / 09-10 +1: test_party_find_yield (v2.1.8) / 09-10 +1: test_abyss_detail_back (v2.1.8) / 09-11 +1: test_event_overlay_yield (v2.1.8) / 09-11 +1: test_dg_retry_button_offline (v2.1.8 실사고 - 이진화 폴백) / 09-13 +1: test_life_close_yield (v2.1.9) / 09-13 +2: test_last_run_exit_yield, test_popup_helper_yield (v2.1.9) / 09-13 +1: test_entry_popup_yield (v2.1.9)

# ★ 2026-10-07 SKIP 표시 (ESC 메뉴 아이콘 폴백 설계 v2 10.6 - 설계 리뷰 ② P2): 통과한 테스트의 출력을 버려 와서 자식 테스트가 건너뛴 단
#   (보존 캡처 폴더·OCR 언어 팩이 없는 PC 의 'SKIP …' 줄)이 사라지고 결과가 '전부 통과' 로만 남았습니다. 통과한 테스트라도 줄 머리 'SKIP'
#   (앞 공백 허용) 줄이 있으면 '== 이름: 통과 (SKIP n) ==' 와 그 줄들을 찍고, 마지막 결과 줄 끝에 SKIP 합계(모든 테스트의 SKIP 줄 수와 그 줄이
#   있는 파일 수 - 실패한 테스트는 출력 전체가 이미 위에 찍힘)를 붙입니다. **종료 코드는 바꾸지 않습니다** - 다른 PC 의 정상 SKIP 을 실패로
#   만들지 않기 위해서입니다. 그래서 테스트 안에서 있어야 할 파일이 빠진 경우는 SKIP 이 아니라 FAIL 로 내야 합니다
$skipLineTotal = 0
$skipFileCount = 0
$failedTests = @()
$erroredTests = @()
foreach ($t in $tests) {
  $out = $null
  $exit = 0
  $runError = ''
  try {
    # 자식 프로세스의 stderr 가 ErrorRecord 로 올라와도 러너를 죽이지 않게 이 구간만 낮춥니다
    $prevPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $t.FullName 2>&1
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevPreference
  } catch {
    $ErrorActionPreference = 'Stop'
    $runError = $_.Exception.Message
    $exit = -1
  }
  $hasFail = (@($out) | Where-Object { $_ -match '^FAIL' }).Count -gt 0
  $skipLines = @(@($out) | Where-Object { "$_" -match '^\s*SKIP' })
  if ($skipLines.Count -gt 0) { $skipLineTotal += $skipLines.Count; $skipFileCount++ }
  if ($runError) {
    $erroredTests += $t.Name
    "== $($t.Name): 실행 실패 =="
    "  $runError"
    @($out) | ForEach-Object { "  $_" }
  } elseif ($exit -ne 0 -or $hasFail) {
    $failedTests += $t.Name
    "== $($t.Name): 실패 (exit $exit) =="
    @($out) | ForEach-Object { "  $_" }
  } elseif ($skipLines.Count -gt 0) {
    # 통과지만 건너뛴 단이 있음 - 조용히 '통과' 로만 남기지 않고 그 줄들을 보여 줍니다 (위 ★ 2026-10-07)
    "== $($t.Name): 통과 (SKIP $($skipLines.Count)) =="
    $skipLines | ForEach-Object { "  $_" }
  } else {
    "== $($t.Name): 통과 =="
  }
}
# ${} 필수 - '$skipLineTotal개' 는 그 이름의 변수로 읽힙니다 (규칙 3)
$skipSummary = " - SKIP 줄 ${skipLineTotal}개(파일 ${skipFileCount}개)"
''
$countMismatch = ($tests.Count -ne $expectedTestCount)
if ($countMismatch) {
  # ${} 필수 - PS 5.1 은 '$expectedTestCount개' 를 그 이름의 변수로 읽어 빈 값이 됩니다
  # (이 프로젝트의 대표 함정. 실증 중에 그대로 밟았습니다 - 2026-08-10 9차 점검)
  "[경고] 테스트 파일 개수가 기대와 다릅니다: 발견 $($tests.Count)개 / 기대 ${expectedTestCount}개"
  '        (테스트를 추가·삭제했다면 run_all_tests.ps1 의 $expectedTestCount 를 함께 고쳐 주세요.'
  '         고치지 않으면 파일이 사라져도 전부 통과로 끝납니다 - 9차 점검에서 막은 구멍입니다.)'
}
$badCount = $failedTests.Count + $erroredTests.Count + $bomMissing.Count
if ($badCount -gt 0 -or $countMismatch) {
  $parts = @()
  if ($failedTests.Count -gt 0) { $parts += "실패 $($failedTests.Count)개 - $($failedTests -join ', ')" }
  if ($erroredTests.Count -gt 0) { $parts += "실행 실패 $($erroredTests.Count)개 - $($erroredTests -join ', ')" }
  if ($countMismatch) { $parts += "개수 불일치($($tests.Count)/$expectedTestCount)" }
  if ($bomMissing.Count -gt 0) { $parts += "BOM 없음 $($bomMissing.Count)개 - $($bomMissing -join ', ')" }
  "결과: $($tests.Count)개 중 $($parts -join ' / ')$skipSummary"
  exit 1
}
"결과: $($tests.Count)개 전부 통과$skipSummary"
exit 0
