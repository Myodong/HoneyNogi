# 던전 4유형 템플릿 좌표의 오프라인 재현 검증 - 확정 실측 캡처 40장 전수 대조
# (10던전 x {선택_1층포커스, 선택_2층포커스, 옵션1층, 옵션2층}, 전부 1272x717 정규 창)
# 검증: ① 템플릿 좌표가 실제 캡처의 카드 위(남색 판별 통과)에 떨어진다
#       ② 옵션 화면에서 반대 배치의 소카드 행 좌표는 빈 공간(판별 실패)이다 - 오클릭 방지 확인
# 캡처 폴더가 없는 PC(다른 개발/제보 환경)에서는 건너뜁니다 (스킵 = 실패 아님).
$ErrorActionPreference = 'Stop'
$fails = 0
# 확정 실측 캡처는 저장소 던전이미지\던전 에 보관합니다 (2026-07-28 이동 - 바탕화면 임시
# 폴더는 정리됨). 저장소 폴더가 없으면(부분 클론 등) 건너뜁니다 (스킵 = 실패 아님).
$captureDir = Join-Path (Split-Path -Parent $PSScriptRoot) '던전이미지\던전'
if (-not (Test-Path -LiteralPath $captureDir)) {
  "SKIP 확정 실측 캡처 폴더가 없어 오프라인 재현 검증을 건너뜁니다: $captureDir"
  exit 0
}
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Test-DgCardColor', 'Get-DgSelStagePoint', 'Get-DgOptStageFallbackPoint')) {
  Invoke-Expression $definition
}
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
foreach ($varName in @('dgFocusShiftY', 'dgLayoutTable', 'dgSelStagePoints', 'dgOptStagePoints')) {
  $assign = $sourceAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $varName))
    }, $true)
  if (-not $assign) { "FAIL 본체에서 `$$varName 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $assign.Extent.Text
}

# 워커의 Test-DgCardPixelAt 과 같은 5점 표본 판별을 비트맵에 적용 (화면 대신 캡처 PNG)
$cardOffsets = @(@(-28, -2), @(28, -2), @(-28, 8), @(28, 8), @(0, 13))
function Test-CardOnBitmap {
  param([System.Drawing.Bitmap]$Bitmap, [int]$X, [int]$Y)
  $hits = 0
  foreach ($offset in $cardOffsets) {
    $px = $X + $offset[0]; $py = $Y + $offset[1]
    if ($px -lt 0 -or $py -lt 0 -or $px -ge $Bitmap.Width -or $py -ge $Bitmap.Height) { continue }
    $c = $Bitmap.GetPixel($px, $py)
    if (Test-DgCardColor -R $c.R -G $c.G -B $c.B) { $hits++ }
  }
  return ($hits -ge 3)
}

$checked = 0
foreach ($dungeon in $dgLayoutTable.Keys) {
  $types = $dgLayoutTable[$dungeon]
  # ── 선택 화면 2장: 각 포커스 상태에서 6개 구역 템플릿이 전부 카드 위 ──
  foreach ($focus in 1, 2) {
    $file = Join-Path $captureDir ($dungeon + '_선택_' + $focus + '층포커스.png')
    if (-not (Test-Path -LiteralPath $file)) { "FAIL 캡처 없음: $file"; $fails++; continue }
    $bmp = [System.Drawing.Bitmap]::FromFile($file)
    try {
      foreach ($stage in @('1-1', '1-2', '1-3', '2-1', '2-2', '2-3')) {
        $floorType = $types[[int]($stage.Substring(0, 1)) - 1]
        $point = Get-DgSelStagePoint -LayoutType $floorType -Stage $stage -FocusFloor $focus
        $checked++
        if (-not (Test-CardOnBitmap -Bitmap $bmp -X $point[0] -Y $point[1])) {
          "FAIL 선택 템플릿이 카드 밖: $dungeon ${focus}층포커스 $stage ($floorType) @($($point[0]),$($point[1]))"
          $fails++
        }
      }
    } finally { $bmp.Dispose() }
  }
  # ── 옵션 화면 2장: 3개 구역 템플릿 전부 카드 위 + 반대 가로 배치 행은 빈 공간 ──
  foreach ($floor in 1, 2) {
    $file = Join-Path $captureDir ($dungeon + '_옵션' + $floor + '층.png')
    if (-not (Test-Path -LiteralPath $file)) { "FAIL 캡처 없음: $file"; $fails++; continue }
    $bmp = [System.Drawing.Bitmap]::FromFile($file)
    try {
      $floorType = $types[$floor - 1]
      foreach ($area in '1', '2', '3') {
        $point = Get-DgOptStageFallbackPoint -Stage "$floor-$area" -LayoutType $floorType
        $checked++
        if (-not (Test-CardOnBitmap -Bitmap $bmp -X $point.X -Y $point.Y)) {
          "FAIL 옵션 템플릿이 카드 밖: $dungeon ${floor}층 구역$area ($floorType) @($($point.X),$($point.Y))"
          $fails++
        }
      }
      # 반대 가로 배치의 소카드 행 = 이 화면에서는 빈 공간이어야 함 (세로형 화면은 겹침 있어 제외)
      if ($floorType -eq 'A' -or $floorType -eq 'B') {
        $antiType = if ($floorType -eq 'A') { 'B' } else { 'A' }
        foreach ($area in '1', '2') {
          $anti = Get-DgOptStageFallbackPoint -Stage "$floor-$area" -LayoutType $antiType
          $checked++
          if (Test-CardOnBitmap -Bitmap $bmp -X $anti.X -Y $anti.Y) {
            "FAIL 반대 배치 좌표가 카드로 오탐: $dungeon ${floor}층 구역$area ($antiType) @($($anti.X),$($anti.Y))"
            $fails++
          }
        }
      }
    } finally { $bmp.Dispose() }
  }
}
"검사 지점 수: $checked (기대 10던전 x (선택 12 + 옵션 6~10))"
if ($fails -eq 0) { "OK   40장 전수 대조: 템플릿 좌표 전부 카드 위, 반대 배치 오탐 0건" }
exit $fails
