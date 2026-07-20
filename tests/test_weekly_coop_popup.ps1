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
exit $fails
