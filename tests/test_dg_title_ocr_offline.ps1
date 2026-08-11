# 던전 옵션 제목 배율 사다리(s3→s4)의 오프라인 OCR 재현 검증 (2026-08-11 23:55 실사고)
# 본체: mabinogi_run_once.ps1 Read-DgTitleText - 좁은 s3 → 넓은 s3 → 넓은 s4, '구역' 채택 게이트.
# 사고: 타 PC 1908x1076 창에서 구역 2-1 전환이 실제 성공했는데(캡처 제목 '룬다 2층 1구역')
#   확인 재판독 8회 전부 실패('훈다0') → exit 4. 캡처 재현: 좁은 s3 '훈다0' / 넓은 s3
#   '로다2증1구°'('역' 깨짐) / 넓은 s4 '로다2증1구역'(정상) → s4 사다리가 수정.
# 이 테스트는 그 오류 캡처를 워커와 같은 경로(비율 크롭 → 기준크기×배율 확대 → ko OCR)로
# 재생해 "사다리 끝(s4)이 목표 스테이지 매치까지 통과"를 고정합니다. 중간 판독(s3)의 정확한
# 깨짐 문자열은 OCR 엔진 업데이트로 변할 수 있어 단언하지 않고 출력만 남깁니다.
# 캡처 폴더가 없는 PC(부분 클론 등)에서는 건너뜁니다 (스킵 = 실패 아님).
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$capturePath = Join-Path $projectRoot '던전이미지\실측기록\20260811_구역전환확인실패_1908창_옵션화면.png'
if (-not (Test-Path -LiteralPath $capturePath)) {
  "SKIP 실측 캡처가 없어 오프라인 OCR 재현을 건너뜁니다: $capturePath"
  exit 0
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
$asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
  Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } |
  Select-Object -First 1
$ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('ko')))
if (-not $ocrKoreanEngine) {
  'SKIP 한국어 OCR 엔진을 만들 수 없어 건너뜁니다 (ko 언어 팩 없음)'
  exit 0
}

. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Test-CustomTitleStageMatch', 'Read-DgTitleText')) {
  Invoke-Expression $definition
}
# $rgDgTitle 은 사본을 박지 않고 소스 대입식을 그대로 실행해 캡처합니다 (배선 원칙)
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$config = $null
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$titleRegionAssign = $sourceAst.Find({
    param($node)
    ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
    ($node.Left.Extent.Text -eq '$rgDgTitle')
  }, $true)
if (-not $titleRegionAssign) { 'FAIL 본체에서 $rgDgTitle 정의를 찾지 못했습니다'; exit 1 }
Invoke-Expression $titleRegionAssign.Extent.Text

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 워커 Get-GameRegionCapture 의 오프라인 등가: 창 비율 크롭 → 기준크기×배율 확대 → OCR ──
# (캡처는 1908x1076 창 전체 = GetWindowRect 영역. 기준 좌표계 1272x717 비율 환산 동일)
$referenceWidth = 1272; $referenceHeight = 717
$sourceBitmap = [System.Drawing.Bitmap]::FromFile($capturePath)
function Get-CaptureRegionText {
  param([int]$RefX, [int]$RefY, [int]$RefW, [int]$RefH, [int]$Scale)
  $imageW = $script:sourceBitmap.Width; $imageH = $script:sourceBitmap.Height
  $cropLeft = [int][Math]::Round($RefX * $imageW / $script:referenceWidth)
  $cropTop = [int][Math]::Round($RefY * $imageH / $script:referenceHeight)
  $cropW = [Math]::Max(1, [int][Math]::Round($RefW * $imageW / $script:referenceWidth))
  $cropH = [Math]::Max(1, [int][Math]::Round($RefH * $imageH / $script:referenceHeight))
  $crop = New-Object System.Drawing.Bitmap $cropW, $cropH
  $scaled = New-Object System.Drawing.Bitmap ($RefW * $Scale), ($RefH * $Scale)
  try {
    $cropGraphics = [System.Drawing.Graphics]::FromImage($crop)
    try {
      $cropGraphics.DrawImage($script:sourceBitmap, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)),
        (New-Object System.Drawing.Rectangle($cropLeft, $cropTop, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
    } finally { $cropGraphics.Dispose() }
    $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
    try {
      $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $scaledGraphics.DrawImage($crop, (New-Object System.Drawing.Rectangle(0, 0, ($RefW * $Scale), ($RefH * $Scale))),
        (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
    } finally { $scaledGraphics.Dispose() }
    return (([string](Invoke-OcrOnBitmap -Bitmap $scaled -Engine $ocrKoreanEngine).Text) -replace '\s', '')
  } finally {
    $crop.Dispose(); $scaled.Dispose()
  }
}

# 워커 Get-GameRegionOcrText 를 캡처 판독으로 대체 - **실제 Read-DgTitleText 를 그대로 실행**해
# 사다리 재구현 사본이 아니라 배포될 함수의 영역/배율/채택 순서를 검증합니다 (교차 리뷰 반영:
# 사본 사다리는 워커의 -Scale 배선이 고정값으로 퇴행해도 통과해 버림)
function Get-GameRegionOcrText {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale, $Engine)
  return (Get-CaptureRegionText -RefX $ReferenceX -RefY $ReferenceY -RefW $RegionWidth -RefH $RegionHeight -Scale $Scale)
}

try {
  # 제목 영역은 config ocrRegions.dgTitle(30,45,250,55) + 확장 폭 420 (워커 Read-DgTitleText 동일)
  $narrowS3 = Get-CaptureRegionText -RefX $rgDgTitle[0] -RefY $rgDgTitle[1] -RefW $rgDgTitle[2] -RefH $rgDgTitle[3] -Scale 3
  $wideS3 = Get-CaptureRegionText -RefX $rgDgTitle[0] -RefY $rgDgTitle[1] -RefW 420 -RefH $rgDgTitle[3] -Scale 3
  $wideS4 = Get-CaptureRegionText -RefX $rgDgTitle[0] -RefY $rgDgTitle[1] -RefW 420 -RefH $rgDgTitle[3] -Scale 4
  "정보: 좁은 s3='$narrowS3' / 넓은 s3='$wideS3' / 넓은 s4='$wideS4' (실측 당시 '훈다0'/'로다2증1구°'/'로다2증1구역')"

  # 배포될 함수 본체를 캡처 위에서 실행 (사다리 순서·배율 배선 그대로)
  $ladderText = Read-DgTitleText -Game $null
  Assert-Case '사다리 결과에 구역 생존(수정 전에는 8회 전부 소실)' ($ladderText.Contains('구역')) $true
  Assert-Case '사다리 결과가 목표 2-1 과 매치(전환 확인 통과)' `
    (Test-CustomTitleStageMatch -TitleText $ladderText -Stage '2-1') 'match'
  # 사다리 마지막 단(s4)은 단독으로도 매치해야 합니다 - s3 판독이 엔진 업데이트로 살아나
  # 앞 단에서 채택되더라도, 이 사고를 실제로 고친 s4 단의 효력은 따로 고정합니다.
  Assert-Case '넓은 s4 단독 매치(이 사고를 고친 단)' `
    (Test-CustomTitleStageMatch -TitleText $wideS4 -Stage '2-1') 'match'
} finally {
  $sourceBitmap.Dispose()
}

exit $fails
