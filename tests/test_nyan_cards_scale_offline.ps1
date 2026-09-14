# 냥코인 카드 존 판독 배율 - 라벨 프레임 오프라인 재현 (2026-09-14 신설)
# 워커 실기 프레임 24장(라벨 = 로그의 구매 순서로 계산한 '이 시점에 존재해야 하는 가격표 슬롯')을 워커와 같은
# 영역·파서·중심 좌표 변환으로 판독해, 소스의 배율($nyanCardsScale)에서 슬롯별 검출률 ≥ 90% 를 단언하고
# 배율 3 의 하단 좌우 검출률 < 70% 를 '고치기 전 재현'으로 함께 고정합니다 (규칙 9). 검출 = 슬롯 중심 ±30px.
# 실측 근거: 던전이미지\실측기록\20260913_냥코인_카드존_배율실험\ (311장 실험 - 배율 3: 하좌 50%/하우 53%, 배율 5: 95~100%)
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
$asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
  Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } |
  Select-Object -First 1
$ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('ko')))
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Get-NyanPriceTags')) {
  Invoke-Expression $definition
}
$nyanAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'mabinogi_run_once.ps1'), [ref]$null, [ref]$null)
foreach ($nyanVar in @('rgNyanCards', 'nyanCardsScale')) {
  $nyanAssign = $nyanAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $nyanVar))
    }, $true)
  if (-not $nyanAssign) { "FAIL 본체에서 `$$nyanVar 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $nyanAssign.Extent.Text
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$refW = 1272; $refH = 717
function Read-CardWords {
  # 워커 Get-GameRegionCapture + Get-GameRegionOcrWords 와 같은 규칙: 기준 비율 크롭 → 기준크기×배율(HighQualityBicubic)
  # → ko OCR → 단어 중심점을 기준 좌표로 (반올림, 공백 제거)
  param([System.Drawing.Bitmap]$Src, [int[]]$Region, [int]$Scale)
  $W = $Src.Width; $H = $Src.Height
  $cropLeft = [int][Math]::Round($Region[0] * $W / $refW); $cropTop = [int][Math]::Round($Region[1] * $H / $refH)
  $cropW = [Math]::Max(1, [int][Math]::Round($Region[2] * $W / $refW)); $cropH = [Math]::Max(1, [int][Math]::Round($Region[3] * $H / $refH))
  $crop = New-Object System.Drawing.Bitmap $cropW, $cropH
  $scaled = New-Object System.Drawing.Bitmap ($Region[2] * $Scale), ($Region[3] * $Scale)
  try {
    $g = [System.Drawing.Graphics]::FromImage($crop)
    $g.DrawImage($Src, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)),
      (New-Object System.Drawing.Rectangle($cropLeft, $cropTop, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $g2 = [System.Drawing.Graphics]::FromImage($scaled)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($crop, (New-Object System.Drawing.Rectangle(0, 0, ($Region[2] * $Scale), ($Region[3] * $Scale))),
      (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
    $g2.Dispose()
    $ocr = Invoke-OcrOnBitmap -Bitmap $scaled -Engine $ocrKoreanEngine
    $words = @()
    foreach ($line in $ocr.Lines) {
      foreach ($word in $line.Words) {
        $centerXScaled = $word.BoundingRect.X + ($word.BoundingRect.Width / 2)
        $centerYScaled = $word.BoundingRect.Y + ($word.BoundingRect.Height / 2)
        $words += , @{ Text = ([string]$word.Text -replace '\s', '')
          X = $Region[0] + [int][Math]::Round($centerXScaled / $Scale)
          Y = $Region[1] + [int][Math]::Round($centerYScaled / $Scale) }
      }
    }
    return $words
  } finally { $crop.Dispose(); $scaled.Dispose() }
}

# 슬롯 중심 (실기 프레임 군집 - 실측기록 세트의 make_labels 와 동일)
$slotCenters = [ordered]@{
  TL = @(587, 366); TR = @(694, 366); ML = @(480, 414); MR = @(793, 414); LL = @(474, 584); LR = @(798, 584); BT = @(636, 632)
}
$sampleDir = Join-Path $projectRoot '던전이미지\실측기록\20260913_냥코인_카드존_배율실험\frames'
$labels = @(Import-Csv (Join-Path $sampleDir 'labels.csv'))
Assert-Case '라벨 프레임 24장' $labels.Count 24

function Measure-Recall {
  param([int]$Scale)
  $hit = @{}; $tot = @{}
  foreach ($slot in $slotCenters.Keys) { $hit[$slot] = 0; $tot[$slot] = 0 }
  foreach ($lab in $labels) {
    $bmp = [System.Drawing.Bitmap]::FromFile((Join-Path $sampleDir $lab.frame))
    try {
      $tags = @(Get-NyanPriceTags -Words (Read-CardWords -Src $bmp -Region $rgNyanCards -Scale $Scale))
    } finally { $bmp.Dispose() }
    foreach ($slot in ($lab.present -split ';')) {
      if (-not $slot) { continue }
      $c = $slotCenters[$slot]; $tot[$slot]++
      foreach ($tag in $tags) {
        if ([Math]::Abs([int]$tag.X - $c[0]) -le 30 -and [Math]::Abs([int]$tag.Y - $c[1]) -le 30) { $hit[$slot]++; break }
      }
    }
  }
  return @{ Hit = $hit; Tot = $tot }
}

$atSource = Measure-Recall -Scale $nyanCardsScale
$atThree = Measure-Recall -Scale 3
foreach ($slot in @('ML', 'MR', 'LL', 'LR', 'BT')) {
  $n = $atSource.Tot[$slot]; $h = $atSource.Hit[$slot]
  "     └ 슬롯 $slot 배율 $nyanCardsScale : $h/$n  (배율 3: $($atThree.Hit[$slot])/$($atThree.Tot[$slot]))"
  if ($n -lt 5) { "     └ 슬롯 $slot 표본 $n 장 - 5장 미만이라 검출률 단언 생략"; continue }
  Assert-Case "검출률: 슬롯 $slot 워커 배율($nyanCardsScale) ≥ 90% (표본 $n)" ($h -ge [Math]::Ceiling($n * 0.9)) 'True'
}
# 고치기 전 재현: 배율 3 은 하단 좌우를 70% 미만으로만 읽음 (이 단언이 깨지면 라벨·영역이 바뀐 것 - 원인 확인)
foreach ($slot in @('LL', 'LR')) {
  $n = $atThree.Tot[$slot]; $h = $atThree.Hit[$slot]
  Assert-Case "재현: 슬롯 $slot 배율 3 < 70% (표본 $n)" ($h -lt ($n * 0.7)) 'True'
}
exit $fails
