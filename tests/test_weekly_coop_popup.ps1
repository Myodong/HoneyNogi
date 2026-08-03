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
exit $fails
