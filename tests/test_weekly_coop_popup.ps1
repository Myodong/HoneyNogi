# 주간 협동 미션 리셋 팝업 감지 진리표 ('협동' + '참여' 조합)
# 본체: mabinogi_run_once.ps1 Invoke-EventSkipOrConfirm 의 주간 팝업 분기 (2026-07-20 실측)
$fails = 0
$cases = @(
  @{ T = '닫기협동미션참여하기'; E = $true }   # 2026-07-20 실측 판독 (1272/1908 두 창 동일)
  @{ T = '협동미션참여하기'; E = $true }       # '닫기'가 깨져도 감지
  @{ T = '닫기'; E = $false }                  # 구매 팝업 등 다른 닫기와 구분
  @{ T = '협동보너스'; E = $false }            # 클리어 점수표의 '협동'과 구분 ('참여' 없음)
  @{ T = '화면을터치해주세요'; E = $false }    # 클리어 문구
  @{ T = '나가기'; E = $false }
  @{ T = ''; E = $false }
)
foreach ($c in $cases) {
  $t = $c.T
  $hit = ($t.Contains('협동') -and $t.Contains('참여'))
  if ($hit -eq $c.E) { "OK  '{0}' -> {1}" -f $c.T, $hit }
  else { "FAIL '{0}' -> {1} (기대 {2})" -f $c.T, $hit, $c.E; $fails++ }
}

# ── 친구 창 '협동 미션' 전체 화면 제목 진리표 (Test-CoopMissionBoardTitle 사본) ──────
# 본체: mabinogi_run_once.ps1 - '협동' AND ('미션' OR '미선'). 2026-08-03 실사고 2건
# (주간 리셋이 이 창을 자동으로 띄움). '미선' = 1810x1020 창 s3 실측 깨짐 (KJM PC).
$boardCases = @(
  @{ T = '해* 협동 미션 0'; E = $true }    # 1272 창 s3/s4 실측 (개발 PC 06:02 캡처)
  @{ T = ',는 협동 미선 0'; E = $true }    # 1810 창 s3 실측 깨짐 (KJM PC 06:02 캡처)
  @{ T = '협동미션'; E = $true }           # 공백 없이 붙어도 인정
  @{ T = '협동 미상'; E = $false }         # 미등록 이형은 불인정 ('미.' 광범위 완화 금지)
  @{ T = '미션'; E = $false }              # '협동' 없음 - 다른 화면의 '미션' 단어와 구분
  @{ T = '협동 보너스'; E = $false }       # 클리어 점수표의 '협동'과 구분
  @{ T = '닫기 협동 미션 참여하기'; E = $true }  # 주간 리셋 팝업 버튼 줄 - 이 ROI(좌상단)에선 실제로 안 보이지만 판정식 자체는 참(전용 ROI가 오탐 방어)
  @{ T = ''; E = $false }
)
foreach ($c in $boardCases) {
  $t = ([string]$c.T) -replace '\s', ''
  $hit = [bool]($t.Contains('협동') -and ($t.Contains('미션') -or $t.Contains('미선')))
  if ($hit -eq $c.E) { "OK  보드 '{0}' -> {1}" -f $c.T, $hit }
  else { "FAIL 보드 '{0}' -> {1} (기대 {2})" -f $c.T, $hit, $c.E; $fails++ }
}

# ── 네트워크 불안정 팝업 제목 진리표 (Close-NetworkUnstablePopup 판정 사본) ──────────
# 본체: '네트워크' AND '불안정' 엄격 ('연결' 완화는 다른 연결 오류 팝업 오포섭 위험 - Codex).
# 실측: 2026-08-01 KJM 캡처 3장 s3 '불안정합니다' / s4 '불안정합LI다' - 조각 생존.
$netTitleCases = @(
  @{ T = '네트워크 연결이 불안정합니다'; E = $true }    # s3 실측
  @{ T = '네트워크 연결이 불안정합LI다'; E = $true }    # s4 실측 깨짐
  @{ T = '네트워크 오류'; E = $false }                  # '불안정' 없음 - 다른 팝업 오포섭 금지
  @{ T = '연결이 불안정합니다'; E = $false }            # '네트워크' 없음
  @{ T = ''; E = $false }
)
foreach ($c in $netTitleCases) {
  $t = ([string]$c.T) -replace '\s', ''
  $hit = [bool]($t.Contains('네트워크') -and $t.Contains('불안정'))
  if ($hit -eq $c.E) { "OK  넷제목 '{0}' -> {1}" -f $c.T, $hit }
  else { "FAIL 넷제목 '{0}' -> {1} (기대 {2})" -f $c.T, $hit, $c.E; $fails++ }
}

# ── '다시 시도하기' 버튼 선택 진리표 (Select-NetworkRetryWord 사본) ─────────────────
# '도하기' 조각 + X>=640 + Y 585~655. 좌측 '시작 화면으로'(타이틀 이탈)는 절대 선택 금지.
$netBtnCases = @(
  @{ T = 'kl도하기'; X = 764; Y = 619; E = $true }    # s3 실측 깨짐
  @{ T = '人I도하기'; X = 764; Y = 619; E = $true }   # s4 실측 깨짐
  @{ T = '도하기'; X = 630; Y = 619; E = $false }     # X 게이트 - 좌측 침범 거부
  @{ T = '시작'; X = 488; Y = 619; E = $false }       # 좌측 버튼 텍스트 거부
  @{ T = '화면으로'; X = 550; Y = 619; E = $false }   # 좌측 버튼 텍스트 거부
  @{ T = 'Space'; X = 655; Y = 594; E = $false }      # 배지 텍스트 거부
  @{ T = '도하기'; X = 764; Y = 700; E = $false }     # Y 게이트 - 줄 밖 거부
)
foreach ($c in $netBtnCases) {
  $picked = $false
  if (([string]$c.T).Contains('도하기')) {
    if ([int]$c.X -ge 640 -and [int]$c.Y -ge 585 -and [int]$c.Y -le 655) { $picked = $true }
  }
  if ($picked -eq $c.E) { "OK  넷버튼 '{0}'({1},{2}) -> {3}" -f $c.T, $c.X, $c.Y, $picked }
  else { "FAIL 넷버튼 '{0}'({1},{2}) -> {3} (기대 {4})" -f $c.T, $c.X, $c.Y, $picked, $c.E; $fails++ }
}
exit $fails
