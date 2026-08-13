# 클리어 문구('화면을 터치해 주세요') 감지 판정 진리표
# 본체: mabinogi_run_once.ps1 Test-DungeonClearPrompt (조각 조합 - 실측 깨짐 사례 기반)
#
# ★ 2026-08-10 9차 점검: 아래 진리표는 판정식을 **테스트 안에 사본으로 다시 박아 둔 것**이라,
#   본체에서 조각 조합을 지워도 그대로 통과했습니다(실사고 대응 조각 2개를 지우고 확인).
#   진리표는 '어떤 깨짐을 잡아야 하는가'를 문서로 남기는 값이 있으므로 유지하되, **본체가
#   그 조합을 실제로 갖고 있는지**를 소스에서 함께 확인합니다. 둘 중 하나만 있으면
#   '통과하지만 아무것도 지키지 않는' 상태가 됩니다.
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$promptBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-DungeonClearPrompt'))
$promptCode = (($promptBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
# 변수 이름은 홑따옴표 + 이어붙이기로 씁니다 - 겹따옴표 안에서 이스케이프하려다 백슬래시가
# 문자열에 그대로 남아 5종이 통째로 '누락'으로 나온 적이 있습니다(작성 중 실제로 밟음).
$nv = '$normalized.Contains'
$requiredCombos = @(
  "Contains('화면을') -and $nv('터')",
  "Contains('화면을') -and $nv('주세요')",
  "Contains('치해') -and $nv('면')",
  "Contains('화면') -and $nv('치')",
  "Contains('터치해') -or $nv('터치하')",
  # v10 계열 (2026-08-13 네이티브 1908 실사고 - 문구 골격 순서 정규식, 교차 리뷰 채택)
  "-match '[화호].{0,8}을.{0,8}치.{0,8}주세요'"
)
$missingCombos = @()
foreach ($combo in $requiredCombos) {
  if (-not $promptCode.Contains($combo)) { $missingCombos += $combo }
}
if ($missingCombos.Count -gt 0) { $missingCombos | ForEach-Object { "     └ 본체에 없음: $_" } }
if ($missingCombos.Count -eq 0) { "OK   본체: 실측 깨짐 대응 조각 조합 5종 전부 존재" }
else { "FAIL 본체: 실측 깨짐 대응 조각 조합 누락 $($missingCombos.Count)종"; $fails++ }
$sv = '$scoreText.Contains'
if ($promptCode.Contains("Contains('처치') -and ($sv('완벽') -or $sv('보너스'))")) {
  "OK   본체: 보조 신호(점수표) 조합 존재"
} else { "FAIL 본체: 보조 신호(점수표) 조합이 없습니다"; $fails++ }
$cases = @(
  @{ T = '화면을터치해주세요'; E = $true },   # 정상
  @{ T = '화면을터夫6주'; E = $true },        # 2026-07-16: '치' 깨짐
  @{ T = '화n을터치해주l요'; E = $true },     # 2026-07-17: '면' 깨짐
  @{ T = '화면을치해주세요'; E = $true },     # 2026-07-18: '터' 통째 소실
  @{ T = '면百치해'; E = $true },             # 2026-07-19: '화'·'터'·'주세요' 소실 (캐릭터 겹침, 진단 판독)
  @{ T = '화면치6H天서j“'; E = $true },       # 2026-07-19: 같은 화면의 다른 깨짐 (재현 판독)
  @{ T = '화면을지해주세요'; E = $true },     # 2026-07-19: '터'→'지' (수동 검증 캡처, 던전 소탕)
  @{ T = '면을터치해주세요'; E = $true },     # 2026-07-19: '화' 소실 (수동 검증 캡처, 어비스)
  # 2026-08-13 19:16·19:26 네이티브 1908 실사고 ×2 (클리어 대기 600초 전멸 - 정규식 골격이 잡음)
  @{ T = '화D을1치ö주세요'; E = $true },      # s3 실측 ('면'→'D', '터'→'1')
  @{ T = '호을4치6주세요'; E = $true },       # s2 실측 ('화'→'호', '면' 소실)
  @{ T = '호十D을터치ö주세요'; E = $true },   # s4 실측
  @{ T = '나가기'; E = $false },
  @{ T = '보상을확인해주세요'; E = $false },
  @{ T = '잠시만기다려주세요'; E = $false },
  @{ T = '경험치고二'; E = $false },          # 비대상 실측 판독 (00:21 하단 문구)
  # 정규식 오탐 면 가드 (교차 리뷰 - '치'+'주세요' 낱글자 조합을 기각한 근거 문구들.
  # 순서 골격이 있어 안 걸려야 함. '보상을 터치해 주세요'류는 기존 조합 5('터치해')의
  # 의도된 매치라 비대상 케이스로 넣지 않음)
  @{ T = '위치를확인해주세요'; E = $false },
  @{ T = '장치를선택해주세요'; E = $false },
  @{ T = '경험치를확인해주세요'; E = $false },
  @{ T = ''; E = $false }
)
foreach ($c in $cases) {
  $n = $c.T
  $hit = ($n.Contains('화면을') -and $n.Contains('터')) -or
         ($n.Contains('화면을') -and $n.Contains('주세요')) -or
         ($n.Contains('치해') -and $n.Contains('면')) -or
         ($n.Contains('화면') -and $n.Contains('치')) -or
         $n.Contains('터치해') -or $n.Contains('터치하') -or
         ($n -match '[화호].{0,8}을.{0,8}치.{0,8}주세요')
  if ($hit -eq $c.E) { "OK  '{0}' -> {1}" -f $c.T, $hit }
  else { "FAIL '{0}' -> {1} (기대 {2})" -f $c.T, $hit, $c.E; $fails++ }
}
# 점수표 보조 신호 영역 (2026-08-13: 네이티브 1908에서 '처치' 행이 위로 밀려 상단 300→265.
# 하드코딩 값이라 소스 대입식으로 배선을 고정합니다 - 되돌리면 실패)
$workerRaw = [System.IO.File]::ReadAllText($workerPath)
if ($workerRaw.Contains('$rgClearScore  = @(185, 265, 230, 200)')) {
  "OK   본체: 점수표 영역 (185,265,230,200) - 네이티브 1908 '처치' 행 수용"
} else { "FAIL 본체: 점수표 영역이 (185,265,230,200)이 아닙니다"; $fails++ }

# 보조 신호: 좌측 점수표 판독의 '처치' + ('완벽' 또는 '보너스') 조합 (2026-07-19 실측 기반)
$scoreCases = @(
  @{ T = '처치완벽한전주권장전투력재도전보너스협동보너스11050201010'; E = $true }  # 클리어(타 PC) 실측
  @{ T = '처치완벽한전루재도전보너스협동보너스110501010'; E = $true }              # 클리어(User) 실측
  @{ T = '처치완벽한전투'; E = $true }                                             # 보너스 항목 없는 판 대비
  @{ T = '*42EI임무전리품이두배가됩니다'; E = $false }                             # 옵션 화면 실측
  @{ T = '과긴!견습쌍검사'; E = $false }                                           # 전투 중 실측
  @{ T = '처치'; E = $false }                                                      # 단독 조각은 불충분
  @{ T = ''; E = $false }
)
foreach ($c in $scoreCases) {
  $s = $c.T
  $hit = ($s.Contains('처치') -and ($s.Contains('완벽') -or $s.Contains('보너스')))
  if ($hit -eq $c.E) { "OK  점수표 '{0}' -> {1}" -f $c.T, $hit }
  else { "FAIL 점수표 '{0}' -> {1} (기대 {2})" -f $c.T, $hit, $c.E; $fails++ }
}
exit $fails
