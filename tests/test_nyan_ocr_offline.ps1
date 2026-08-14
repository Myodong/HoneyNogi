# 냥코인 뽑기 오프라인 OCR 재현 (2026-08-15 신설)
# 보존 캡처 4장(1272×1 + 네이티브 1908×3)을 실제 영역·배율·파서로 판독해
# '두 기하 겸용' 계약을 실측 그대로 고정합니다 (규칙 9 - 판독 경로 재현).
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
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Get-NyanNumberValue', 'Test-NyanMerchantTitle', 'Get-NyanPriceTags')) {
  Invoke-Expression $definition
}
# 워커 영역 값을 소스에서 캡처합니다 (사본 진리표 금지 규칙)
$nyanAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'mabinogi_run_once.ps1'), [ref]$null, [ref]$null)
foreach ($nyanVar in @('rgNyanTitle', 'rgNyanCoin', 'rgNyanGold', 'rgNyanCards', 'rgNyanReroll')) {
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
function Read-CaptureRegion {
  # 워커 Get-GameRegionCapture 와 같은 규칙: 기준 비율 크롭 → 기준크기×배율 확대 → ko OCR
  param([System.Drawing.Bitmap]$Src, [int[]]$Region, [int]$Scale, [switch]$AsWords)
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
    if ($AsWords) {
      $words = @()
      foreach ($line in $ocr.Lines) {
        foreach ($word in $line.Words) {
          $words += , @{ Text = [string]$word.Text
            X = [int]($Region[0] + ($word.BoundingRect.X / $Scale))
            Y = [int]($Region[1] + ($word.BoundingRect.Y / $Scale)) }
        }
      }
      return $words
    }
    return [string]$ocr.Text
  } finally { $crop.Dispose(); $scaled.Dispose() }
}

$capDir = Join-Path $projectRoot '던전이미지\고양이상인'
$cap1272 = [System.Drawing.Bitmap]::FromFile((Join-Path $capDir '20260815_뽑기화면_1272_다시뽑기상태.png'))
$cap1908 = [System.Drawing.Bitmap]::FromFile((Join-Path $capDir '20260815_뽑기화면_1908_가격표7개.png'))
$capDone = [System.Drawing.Bitmap]::FromFile((Join-Path $capDir '20260815_판종료_1908_도둑고양이검거_현상금.png'))
try {
  foreach ($capPair in @(@('1272', $cap1272), @('1908', $cap1908))) {
    $capName = $capPair[0]; $capSrc = $capPair[1]
    Assert-Case "제목 게이트 ($capName)" (Test-NyanMerchantTitle -Text (Read-CaptureRegion -Src $capSrc -Region $rgNyanTitle -Scale 3)) 'True'
    $capTags = @(Get-NyanPriceTags -Words (Read-CaptureRegion -Src $capSrc -Region $rgNyanCards -Scale 3 -AsWords))
    Assert-Case "가격표 존재 ($capName - 새 판 = 클릭 가능 상태)" (@($capTags).Count -ge 4) 'True'
    $capReroll = @(Read-CaptureRegion -Src $capSrc -Region $rgNyanReroll -Scale 4 -AsWords | Where-Object { ([string]$_.Text) -replace '\s', '' -eq '뽑기' })
    Assert-Case "다시 뽑기 '뽑기' 앵커 ($capName)" (@($capReroll).Count -ge 1) 'True'
  }
  Assert-Case '냥코인 잔량 (1272 실측 401,217)' (Get-NyanNumberValue -Text (Read-CaptureRegion -Src $cap1272 -Region $rgNyanCoin -Scale 4)) 401217
  Assert-Case '냥코인 잔량 (1908 실측 8,181,217)' (Get-NyanNumberValue -Text (Read-CaptureRegion -Src $cap1908 -Region $rgNyanCoin -Scale 4)) 8181217
  Assert-Case '골드 잔량 (1272 실측 21,830,510)' (Get-NyanNumberValue -Text (Read-CaptureRegion -Src $cap1272 -Region $rgNyanGold -Scale 4)) 21830510
  Assert-Case '골드 잔량 (1908 실측 21,788,110)' (Get-NyanNumberValue -Text (Read-CaptureRegion -Src $cap1908 -Region $rgNyanGold -Scale 4)) 21788110
  # 판 종료 화면: 가격표 0개 = 다시 뽑기 판정의 실측 근거
  $doneTags = @(Get-NyanPriceTags -Words (Read-CaptureRegion -Src $capDone -Region $rgNyanCards -Scale 3 -AsWords))
  Assert-Case '판 종료 화면 가격표 0개 (1908)' (@($doneTags).Count) 0
} finally {
  $cap1272.Dispose(); $cap1908.Dispose(); $capDone.Dispose()
}

exit $fails
