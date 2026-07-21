# 커스텀 반복 - 워커 판정 진리표: 항목 파싱(6조각) / PREV 비교 / 복구 분기 / 은동전 소진 대응(계약 v2, 2026-07-20)
#                                / 마무리 갈림길·시작 분기(계약 v4, 2026-07-20 실기 검증 반영)
# 본체 순수 판정 함수는 mabinogi_run_once.ps1 에서 AST로 직접 불러옵니다 (ConvertFrom-CustomItemSpec /
#            Format-CustomItemLabel / Test-CustomSameAsPrev / Get-CustomStageFloor /
#            Get-CustomFinishAction / Test-CustomTitleStageMatch / Test-CustomTitleFloorMatch /
#            Get-CustomOptionStartAction / Test-CustomCleanupOnly / Get-CustomCoinDecision)
# 계약 v2: 소진 대응이 전역 체크(continueWithoutCoin/continueSweepOnly)에서 항목별 속성
#          (exhaustContinue/noDoubleSweep)으로 바뀌었고, 토큰이 6조각으로 확장됐습니다.
# 계약 v4 (2026-07-20 실기 검증 실측: 다시 하기로 온 옵션 화면 - '<' 없음, 같은 층 구역은
#          역방향 포함 선택 가능 / 결과 화면 '나가기'는 필드행이라 마무리에 사용 금지 /
#          1-3 결과 화면 '다음 층으로' → 2층 구역 선택 화면):
#          - 마무리 갈림길(Get-CustomFinishAction): NEXT 없음/같은 층 → 'retry'(다시 하기) /
#            X-3 → 바로 윗층 → 'next-floor'('다음 층으로' 클릭 후 코드 0) /
#            그 외 층 전환 → 'retry-warn'(방어 - GUI 리스트 검증이 사전 차단).
#            v3의 '나가기 → 선택 화면' 마무리(Test-CustomSameStage)는 폐기.
#          - 옵션 화면 시작 분기: 제목 구역(Test-CustomTitleStageMatch)·층(Test-CustomTitleFloorMatch)
#            판독 후 Get-CustomOptionStartAction 으로 retry-path/stay-adjust/stay-select/go-back 판정.
$fails = 0

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('ConvertFrom-CustomItemSpec', 'Format-CustomItemLabel', 'Test-CustomSameAsPrev',
      'Get-CustomStageFloor', 'Get-CustomFinishAction', 'Test-CustomTitleStageMatch',
      'Test-CustomTitleFloorMatch', 'Get-CustomOptionStartAction', 'Test-CustomCleanupOnly',
      'Get-CustomRecoveryReadyAction', 'Get-CustomCoinDecision')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ---------- 항목 파싱 6조각 (HONEYNOGI_CUSTOM_ITEM/PREV 공용) ----------
function Describe-Item {
  param($I)
  if ($null -eq $I) { return 'null' }
  return ('{0}/{1}/{2}/{3}/{4}/{5}' -f $I.Difficulty, $I.Stage, $I.Coin, $I.Double, $I.ExhaustContinue, $I.NoDoubleSweep)
}
Assert-Case '파싱: 어려움|1-3|1|1|1|1 (전부 켬)' (Describe-Item (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|1|1')) '어려움/1-3/True/True/True/True'
Assert-Case '파싱: 일반|2-1|0|0|0|0 ([bool]0 함정 - 문자열 비교)' (Describe-Item (ConvertFrom-CustomItemSpec '일반|2-1|0|0|0|0')) '일반/2-1/False/False/False/False'
Assert-Case '파싱: 은동전만+소진 진행 (1|0|1|0)' (Describe-Item (ConvertFrom-CustomItemSpec '일반|1-1|1|0|1|0')) '일반/1-1/True/False/True/False'
Assert-Case '파싱: 더블+소탕만 (1|1|0|1)' (Describe-Item (ConvertFrom-CustomItemSpec '어려움|2-3|1|1|0|1')) '어려움/2-3/True/True/False/True'
Assert-Case '파싱: 빈 문자열 → null' (Describe-Item (ConvertFrom-CustomItemSpec '')) 'null'
Assert-Case '파싱: 공백만 → null' (Describe-Item (ConvertFrom-CustomItemSpec '   ')) 'null'
Assert-Case '파싱: 조각 4개(구버전 v1 토큰) → null' (Describe-Item (ConvertFrom-CustomItemSpec '어려움|1-3|1|1')) 'null'
Assert-Case '파싱: 조각 5개 → null' (Describe-Item (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|0')) 'null'
Assert-Case '파싱: 조각 7개 → null' (Describe-Item (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|0|1|9')) 'null'
Assert-Case '파싱: 난이도 빈칸 → null' (Describe-Item (ConvertFrom-CustomItemSpec '|1-3|1|1|0|0')) 'null'
Assert-Case '파싱: 스테이지 공백 → null' (Describe-Item (ConvertFrom-CustomItemSpec '어려움| |1|1|0|0')) 'null'
Assert-Case '파싱: 플래그 잡음값은 false 취급' (Describe-Item (ConvertFrom-CustomItemSpec '어려움|1-3|2|x|y|z')) '어려움/1-3/False/False/False/False'

# 라벨 표기 (회차 시작/조건 정지 로그 공용 - 소진 대응 속성은 라벨에 넣지 않음)
Assert-Case '라벨: 은동전+더블' (Format-CustomItemLabel (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|1|1')) '어려움 1-3 (은동전·더블 루팅)'
Assert-Case '라벨: 은동전만' (Format-CustomItemLabel (ConvertFrom-CustomItemSpec '일반|2-1|1|0|0|0')) '일반 2-1 (은동전)'
Assert-Case '라벨: 옵션 없음' (Format-CustomItemLabel (ConvertFrom-CustomItemSpec '일반|2-1|0|0|0|0')) '일반 2-1'
Assert-Case '라벨: null 항목' (Format-CustomItemLabel $null) '(항목 없음)'

# ---------- 진리표 ⑤ PREV 비교 (다시 하기 vs 선택 화면 경유 - 여전히 난이도+스테이지만) ----------
$cur = ConvertFrom-CustomItemSpec '어려움|1-3|1|1|0|1'
Assert-Case 'PREV: 난이도+스테이지 동일 → 다시하기' (Test-CustomSameAsPrev $cur (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|0|1')) 'True'
Assert-Case 'PREV: 은동전/더블만 달라도 다시하기 (카드는 옵션 화면에서 조정)' (Test-CustomSameAsPrev $cur (ConvertFrom-CustomItemSpec '어려움|1-3|0|0|0|0')) 'True'
Assert-Case 'PREV: 소진 대응 속성만 달라도 다시하기 (경로 판정 무관)' (Test-CustomSameAsPrev $cur (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|1|0')) 'True'
Assert-Case 'PREV: 스테이지 다름 → 경유' (Test-CustomSameAsPrev $cur (ConvertFrom-CustomItemSpec '어려움|1-2|1|1|0|1')) 'False'
Assert-Case 'PREV: 난이도 다름 → 경유' (Test-CustomSameAsPrev $cur (ConvertFrom-CustomItemSpec '일반|1-3|1|1|0|1')) 'False'
Assert-Case 'PREV: 둘 다 다름 → 경유' (Test-CustomSameAsPrev $cur (ConvertFrom-CustomItemSpec '일반|2-1|0|0|0|0')) 'False'
Assert-Case 'PREV: 없음(빈 값) → 경유' (Test-CustomSameAsPrev $cur (ConvertFrom-CustomItemSpec '')) 'False'
Assert-Case 'PREV: 구버전 4조각 PREV → 파싱 null → 경유' (Test-CustomSameAsPrev $cur (ConvertFrom-CustomItemSpec '어려움|1-3|1|1')) 'False'
Assert-Case 'PREV: 현재 항목 null → 경유' (Test-CustomSameAsPrev $null (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|0|1')) 'False'

# ---------- 진리표 ⑥ 복구 분기 (RESTART x 시작 화면 → 수동 판 정리 모드) ----------
# true = 완료 미계상+화면 정리만(코드 10) / false = 정상 흐름(RESTART 복구 판은 완료 계상, 코드 0)
Assert-Case '복구: 새시작+던전내부 → 정리만' (Test-CustomCleanupOnly $true $false $true $false) 'True'
Assert-Case '복구: 새시작+결과화면 → 정리만' (Test-CustomCleanupOnly $true $false $false $true) 'True'
Assert-Case '복구: 새시작+둘 다 → 정리만' (Test-CustomCleanupOnly $true $false $true $true) 'True'
Assert-Case '복구: 새시작+선택/옵션 화면 → 정상 흐름' (Test-CustomCleanupOnly $true $false $false $false) 'False'
Assert-Case '복구: RESTART+던전내부 → 완료 계상 흐름' (Test-CustomCleanupOnly $true $true $true $false) 'False'
Assert-Case '복구: RESTART+결과화면 → 완료 계상 흐름' (Test-CustomCleanupOnly $true $true $false $true) 'False'
Assert-Case '복구: RESTART+정상 화면 → 정상 흐름' (Test-CustomCleanupOnly $true $true $false $false) 'False'
Assert-Case '복구: 비커스텀은 화면 무관 false' (Test-CustomCleanupOnly $false $false $true $true) 'False'
Assert-Case '복구: 비커스텀+RESTART 잔존 env 도 false' (Test-CustomCleanupOnly $false $true $true $false) 'False'

# 완료 마커 소유 항목의 마무리 복구: 목표 화면이면 재입장 없이 코드 0, 결과/기타면 마무리 계속.
Assert-Case '마커복구: 일반 회차는 화면 무관 continue' (Get-CustomRecoveryReadyAction $false $true $false 'retry') 'continue'
Assert-Case '마커복구: retry 후 옵션 화면 준비 = complete' (Get-CustomRecoveryReadyAction $true $true $false 'retry') 'complete'
Assert-Case '마커복구: 선택 화면 준비 = complete' (Get-CustomRecoveryReadyAction $true $false $true 'next-floor') 'complete'
Assert-Case '마커복구: next-floor인데 옵션 화면 = blocked' (Get-CustomRecoveryReadyAction $true $true $false 'next-floor') 'blocked'
Assert-Case '마커복구: 결과/기타 화면 = continue' (Get-CustomRecoveryReadyAction $true $false $false 'retry') 'continue'

# ---------- 진리표 ④ 은동전 소진 대응 (계약 v2 단계식 - 항목별 속성 전 조합) ----------
# UseCoin x DoubleLoot x 잔량 구간(<10 / 10~19 / >=20 / null) x ExhaustContinue x NoDoubleSweep
function Describe-Coin {
  param($D)
  return ('{0}/{1}/{2}' -f $D.Action, $D.Coin, $D.Loot)
}
# 은동전 미사용 항목: 잔량/속성 무관 무검사 진행
Assert-Case '소진: 미사용 잔량0 → 무검사 진행' (Describe-Coin (Get-CustomCoinDecision $false $false 0 $false $false)) 'proceed/False/False'
Assert-Case '소진: 미사용+더블 플래그 잔존 → 더블도 끔' (Describe-Coin (Get-CustomCoinDecision $false $true 0 $true $true)) 'proceed/False/False'
Assert-Case '소진: 미사용 잔량null → 진행' (Describe-Coin (Get-CustomCoinDecision $false $false $null $false $false)) 'proceed/False/False'
# 잔량 판독 실패(null): 검사 생략 진행 (OCR 순단 오정지 방지 - 속성 무관)
Assert-Case '소진: 소탕만 잔량null → 검사 생략 진행' (Describe-Coin (Get-CustomCoinDecision $true $false $null $false $false)) 'proceed/True/False'
Assert-Case '소진: 소탕+더블 잔량null → 검사 생략 진행' (Describe-Coin (Get-CustomCoinDecision $true $true $null $true $true)) 'proceed/True/True'

# 비더블 코인 항목 (Double=false): 경계 10, ExhaustContinue 만 유효 (NoDoubleSweep 무관)
# 잔량 x EC x NDS 전 조합 (16케이스)
$coinOnlyTable = @(
  # 잔량, EC, NDS, 기대
  @(0,  $false, $false, 'stop/False/False'),
  @(0,  $false, $true,  'stop/False/False'),
  @(0,  $true,  $false, 'proceed/False/False'),
  @(0,  $true,  $true,  'proceed/False/False'),
  @(9,  $false, $false, 'stop/False/False'),
  @(9,  $false, $true,  'stop/False/False'),
  @(9,  $true,  $false, 'proceed/False/False'),
  @(9,  $true,  $true,  'proceed/False/False'),
  @(10, $false, $false, 'proceed/True/False'),
  @(10, $false, $true,  'proceed/True/False'),
  @(10, $true,  $false, 'proceed/True/False'),
  @(10, $true,  $true,  'proceed/True/False'),
  @(19, $false, $false, 'proceed/True/False'),
  @(19, $true,  $true,  'proceed/True/False'),
  @(20, $false, $false, 'proceed/True/False'),
  @(20, $true,  $true,  'proceed/True/False')
)
foreach ($tc in $coinOnlyTable) {
  $caseName = '소진: 코인만 잔량{0} EC={1} NDS={2}' -f $tc[0], $tc[1], $tc[2]
  Assert-Case $caseName (Describe-Coin (Get-CustomCoinDecision $true $false ([int]$tc[0]) ([bool]$tc[1]) ([bool]$tc[2]))) $tc[3]
}

# 더블 항목 (Double=true) 범위별 판정:
#  >=20 → 코인+더블 진행 / 10~19 → NDS ? 소탕만 진행 : stop /
#  <10 → NDS와 무관하게 EC ? 미사용 진행 : stop
# 잔량 {0,5,9,10,15,19,20,25} x EC x NDS 전 조합 (32케이스)
$doubleTable = @(
  @(0,  $false, $false, 'stop/False/False'),
  @(0,  $false, $true,  'stop/False/False'),
  @(0,  $true,  $false, 'proceed/False/False'),
  @(0,  $true,  $true,  'proceed/False/False'),
  @(5,  $false, $false, 'stop/False/False'),
  @(5,  $false, $true,  'stop/False/False'),
  @(5,  $true,  $false, 'proceed/False/False'),
  @(5,  $true,  $true,  'proceed/False/False'),
  @(9,  $false, $false, 'stop/False/False'),
  @(9,  $false, $true,  'stop/False/False'),
  @(9,  $true,  $false, 'proceed/False/False'),
  @(9,  $true,  $true,  'proceed/False/False'),
  @(10, $false, $false, 'stop/True/False'),
  @(10, $false, $true,  'proceed/True/False'),   # 소탕만 진행 (경계)
  @(10, $true,  $false, 'stop/True/False'),
  @(10, $true,  $true,  'proceed/True/False'),
  @(15, $false, $false, 'stop/True/False'),
  @(15, $false, $true,  'proceed/True/False'),
  @(15, $true,  $false, 'stop/True/False'),
  @(15, $true,  $true,  'proceed/True/False'),   # 10~19 는 EC 분기 도달 안 함
  @(19, $false, $false, 'stop/True/False'),
  @(19, $false, $true,  'proceed/True/False'),   # 소탕만 진행 (경계)
  @(19, $true,  $false, 'stop/True/False'),
  @(19, $true,  $true,  'proceed/True/False'),
  @(20, $false, $false, 'proceed/True/True'),    # 그대로 진행 (경계 - 속성 무관)
  @(20, $false, $true,  'proceed/True/True'),
  @(20, $true,  $false, 'proceed/True/True'),
  @(20, $true,  $true,  'proceed/True/True'),
  @(25, $false, $false, 'proceed/True/True'),
  @(25, $false, $true,  'proceed/True/True'),
  @(25, $true,  $false, 'proceed/True/True'),
  @(25, $true,  $true,  'proceed/True/True')
)
foreach ($tc in $doubleTable) {
  $caseName = '소진: 더블 잔량{0} EC={1} NDS={2}' -f $tc[0], $tc[1], $tc[2]
  Assert-Case $caseName (Describe-Coin (Get-CustomCoinDecision $true $true ([int]$tc[0]) ([bool]$tc[1]) ([bool]$tc[2]))) $tc[3]
}

# stop/proceed 사유 문구가 항목별 속성 표현을 담는지 표본 확인 (로그 제보 분석용 문구 계약)
$d = Get-CustomCoinDecision $true $true 15 $false $false
Assert-Case '사유: 더블 불가 멈춤 문구' ($d.Reason -match "더블 루팅 불가 시.*멈춤") 'True'
$d = Get-CustomCoinDecision $true $true 15 $false $true
Assert-Case '사유: 소탕만 강등 문구' ($d.Reason -match "소탕만 진행.*더블 루팅만 끄고") 'True'
$d = Get-CustomCoinDecision $true $false 5 $true $false
Assert-Case '사유: 소진 미사용 진행 문구' ($d.Reason -match "동전 소진 시.*미사용으로 진행") 'True'
$d = Get-CustomCoinDecision $true $false 5 $false $false
Assert-Case '사유: 소진 멈춤 문구' ($d.Reason -match "동전 소진 시.*멈춤") 'True'

# ---------- 진리표 ⑦ 층 파싱·제목 층 판정 (계약 v4 - stay-select/next-floor 판정의 기반) ----------
Assert-Case '층 파싱: 1-3 → 1' (Get-CustomStageFloor '1-3') '1'
Assert-Case '층 파싱: 2-1 → 2' (Get-CustomStageFloor '2-1') '2'
Assert-Case '층 파싱: 형식 오류(x) → null' ($null -eq (Get-CustomStageFloor 'x')) 'True'
Assert-Case '층 파싱: 빈 문자열 → null' ($null -eq (Get-CustomStageFloor '')) 'True'
Assert-Case '층 파싱: 뒤 조각 공백(1- ) → null' ($null -eq (Get-CustomStageFloor '1- ')) 'True'
# Test-CustomTitleFloorMatch: 제목의 층 숫자 vs 항목 층 (파싱 기준은 구역 판정과 동일)
Assert-Case '제목층: 1층2구역 vs 1-1 → match (다른 구역, 같은 층)' (Test-CustomTitleFloorMatch '1층2구역' '1-1') 'match'
Assert-Case '제목층: 층 소실(12구역) vs 1-1 → match' (Test-CustomTitleFloorMatch '12구역' '1-1') 'match'
Assert-Case '제목층: 층 오독(1츰3구역) vs 1-2 → match' (Test-CustomTitleFloorMatch '1츰3구역' '1-2') 'match'
Assert-Case '제목층: 2층3구역 vs 1-3 → mismatch (다른 층)' (Test-CustomTitleFloorMatch '2층3구역' '1-3') 'mismatch'
Assert-Case '제목층: 1층1구역 vs 2-1 → mismatch' (Test-CustomTitleFloorMatch '1층1구역' '2-1') 'mismatch'
Assert-Case '제목층: 빈 문자열 → unclear' (Test-CustomTitleFloorMatch '' '1-1') 'unclear'
Assert-Case '제목층: 숫자 소실(구역만) → unclear' (Test-CustomTitleFloorMatch '구역' '1-1') 'unclear'
Assert-Case '제목층: 스테이지 형식 오류 → mismatch(안전측)' (Test-CustomTitleFloorMatch '1층1구역' 'x') 'mismatch'

# ---------- 진리표 ⑧ 회차 마무리 갈림길 (계약 v4 - Get-CustomFinishAction) ----------
# 'retry' = 기존 다시 하기 / 'next-floor' = '다음 층으로' 클릭 후 코드 0 /
# 'retry-warn' = 불가능한 층 전환(방어) - 경고 로그 후 다시 하기.
# v3의 '나가기 → 선택 화면' 마무리는 폐기 (결과 화면 나가기 = 필드행 - 2026-07-20 실측).
# 난이도·카드·소진 대응 속성은 비교하지 않음 - 같은 층이면 옵션 화면에서 전부 조정 가능.
$cur13 = ConvertFrom-CustomItemSpec '어려움|1-3|1|1|0|1'
$cur11 = ConvertFrom-CustomItemSpec '일반|1-1|0|0|0|0'
$cur23 = ConvertFrom-CustomItemSpec '어려움|2-3|1|1|0|1'
$cur21 = ConvertFrom-CustomItemSpec '일반|2-1|0|0|0|0'
Assert-Case '마무리: NEXT 없음(빈 값→null) → retry' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '')) 'retry'
Assert-Case '마무리: NEXT 형식 오류(4조각→null) → retry' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '어려움|2-1|1|1')) 'retry'
Assert-Case '마무리: 1항목 리스트(다음=자기 자신) → retry' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|0|1')) 'retry'
Assert-Case '마무리: 같은 구역 난이도만 다름 → retry (알약으로 변경)' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '일반|1-3|1|1|0|1')) 'retry'
Assert-Case '마무리: 같은 구역 카드/소진 속성만 다름 → retry' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '어려움|1-3|0|0|1|0')) 'retry'
Assert-Case '마무리: 같은 층 다른 구역(1-3→1-1 역방향) → retry (구역 카드로 이동)' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '일반|1-1|0|0|0|0')) 'retry'
Assert-Case '마무리: 같은 층 다른 구역(2-1→2-3) → retry' (Get-CustomFinishAction $cur21 (ConvertFrom-CustomItemSpec '어려움|2-3|1|1|0|1')) 'retry'
Assert-Case '마무리: 1-3 → 2-1 → next-floor (다음 층으로)' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '일반|2-1|0|0|0|0')) 'next-floor'
Assert-Case '마무리: 1-3 → 2-3 → next-floor' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '어려움|2-3|1|1|0|1')) 'next-floor'
Assert-Case '마무리: 2-3 → 1-1 (내려가기) → retry-warn' (Get-CustomFinishAction $cur23 (ConvertFrom-CustomItemSpec '일반|1-1|0|0|0|0')) 'retry-warn'
Assert-Case '마무리: 2-1 → 1-3 (내려가기) → retry-warn' (Get-CustomFinishAction $cur21 (ConvertFrom-CustomItemSpec '어려움|1-3|1|1|0|1')) 'retry-warn'
Assert-Case '마무리: 1-1 → 2-1 (출발이 1-3 아님) → retry-warn' (Get-CustomFinishAction $cur11 (ConvertFrom-CustomItemSpec '일반|2-1|0|0|0|0')) 'retry-warn'
Assert-Case '마무리: 1-2 → 2-3 (출발이 1-3 아님) → retry-warn' (Get-CustomFinishAction (ConvertFrom-CustomItemSpec '일반|1-2|0|0|0|0') (ConvertFrom-CustomItemSpec '어려움|2-3|1|1|0|1')) 'retry-warn'
Assert-Case '마무리: 현재 항목 null → retry' (Get-CustomFinishAction $null $cur21) 'retry'
Assert-Case '마무리: 현재 항목 스테이지 형식 오류 → retry (안전측)' (Get-CustomFinishAction (ConvertFrom-CustomItemSpec '일반|x|0|0|0|0') $cur21) 'retry'
Assert-Case '마무리: NEXT 스테이지 형식 오류 → retry (안전측)' (Get-CustomFinishAction $cur13 (ConvertFrom-CustomItemSpec '일반|x|0|0|0|0')) 'retry'

# 본체 14-2 분기 게이트 시뮬레이터: customMode -and -not customCleanupOnly 일 때만 판정식 호출
# (retry-warn 도 실제 클릭은 다시 하기 - 경고 로그만 추가. next-floor 는 버튼 탐색 실패 시 다시 하기 폴백)
function Get-CustomFinishBranch {
  param([bool]$CustomMode, [bool]$CleanupOnly, [hashtable]$Item, [hashtable]$Next)
  if ($CustomMode -and -not $CleanupOnly) { return (Get-CustomFinishAction -Item $Item -Next $Next) }
  return 'retry'
}
Assert-Case '마무리 게이트: 수동 정리 모드는 next-floor 조합도 다시 하기(코드 10 경로)' (Get-CustomFinishBranch $true $true $cur13 $cur21) 'retry'
Assert-Case '마무리 게이트: 비커스텀은 항상 다시 하기' (Get-CustomFinishBranch $false $false $cur13 $cur21) 'retry'
Assert-Case '마무리 게이트: 커스텀 정상 판은 판정식 결과 그대로' (Get-CustomFinishBranch $true $false $cur13 $cur21) 'next-floor'

# ---------- 진리표 ⑨ 옵션 화면 시작 분기 (계약 v4 - 제목 구역/층 판독 + 경로 판정) ----------
# Test-CustomTitleStageMatch: 0-1 검증과 같은 기준 ('층' 소실 대비 \D{0,2}, 숫자 명확할 때만 판정)
Assert-Case '제목: 1층1구역 vs 1-1 → match' (Test-CustomTitleStageMatch '1층1구역' '1-1') 'match'
Assert-Case '제목: 층 소실(23구역) vs 2-3 → match' (Test-CustomTitleStageMatch '23구역' '2-3') 'match'
Assert-Case '제목: 층 오독(2츰3구역) vs 2-3 → match' (Test-CustomTitleStageMatch '2츰3구역' '2-3') 'match'
Assert-Case '제목: 던전명 붙은 제목(허상의정박지1층2구역) vs 1-2 → match' (Test-CustomTitleStageMatch '허상의정박지1층2구역' '1-2') 'match'
Assert-Case '제목: 1층2구역 vs 1-1 → mismatch' (Test-CustomTitleStageMatch '1층2구역' '1-1') 'mismatch'
Assert-Case '제목: 2층3구역 vs 1-3 → mismatch' (Test-CustomTitleStageMatch '2층3구역' '1-3') 'mismatch'
Assert-Case '제목: 빈 문자열 → unclear' (Test-CustomTitleStageMatch '' '1-1') 'unclear'
Assert-Case '제목: 숫자 소실(구역만) → unclear' (Test-CustomTitleStageMatch '구역' '1-1') 'unclear'
Assert-Case '제목: 선택 화면 제목(허상의정박지던전) → unclear' (Test-CustomTitleStageMatch '허상의정박지던전' '1-1') 'unclear'
Assert-Case '제목: 스테이지 형식 오류 → mismatch(안전측)' (Test-CustomTitleStageMatch '1층1구역' 'x') 'mismatch'
# Get-CustomOptionStartAction 전 조합 (SameAsPrev 최우선 → 구역 일치 → 같은 층 → go-back)
# 파라미터: TitleStageMatches / SameAsPrev / TitleFloorMatches
Assert-Case '시작: SameAsPrev+구역 일치 → retry-path' (Get-CustomOptionStartAction $true $true $true) 'retry-path'
Assert-Case '시작: SameAsPrev+구역 불일치 → retry-path (0-1이 안전망)' (Get-CustomOptionStartAction $false $true $false) 'retry-path'
Assert-Case '시작: SameAsPrev+구역 불일치+같은 층도 retry-path' (Get-CustomOptionStartAction $false $true $true) 'retry-path'
Assert-Case '시작: 다른 항목+구역 일치 → stay-adjust (알약만 조정)' (Get-CustomOptionStartAction $true $false $false) 'stay-adjust'
Assert-Case '시작: 다른 항목+구역 일치(층 플래그 무관) → stay-adjust' (Get-CustomOptionStartAction $true $false $true) 'stay-adjust'
Assert-Case '시작: 구역 불일치+같은 층 → stay-select (구역 카드 선택)' (Get-CustomOptionStartAction $false $false $true) 'stay-select'
Assert-Case '시작: 구역 불일치+다른 층 → go-back (< 복귀 시도)' (Get-CustomOptionStartAction $false $false $false) 'go-back'

exit $fails
