# 전리품 공개 화면 라벨('발견한 전리품') 감지 조각 진리표
# 본체: mabinogi_run_once.ps1 Wait-ForResultScreen 의 전리품 공개 분기 (SearchText '발견')
# 사고(2026-07-19 08:26): 라벨 지점을 클릭한 게임 커서가 라벨을 가려 '발견한전'으로 판독
# → 옛 탐색어 '전리품'이 빗나가 진행 클릭 중단. '발견' 조각은 가림 상태에서도 매칭.
$fails = 0
$cases = @(
  @{ T = '발견한전리품'; E = $true }   # 정상 판독
  @{ T = '발견한전'; E = $true }       # 커서가 '리품'을 가림 (실측)
  @{ T = '발견한'; E = $true }         # 더 넓게 가려진 경우
  @{ T = '다시하기'; E = $false }
  @{ T = '나가기'; E = $false }
  @{ T = ''; E = $false }
)
foreach ($c in $cases) {
  $hit = $c.T.Contains('발견')
  if ($hit -eq $c.E) { "OK  '{0}' -> {1}" -f $c.T, $hit }
  else { "FAIL '{0}' -> {1} (기대 {2})" -f $c.T, $hit, $c.E; $fails++ }
}
exit $fails
