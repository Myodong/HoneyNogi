# 냥코인 골드 잔량 판독 오프라인 진리표 (v2.1.10 - 2026-09-15 신설)
# 시작 골드가 앞자리를 떨어뜨리던 문제(09-13 20:25 '9,782,324', 실제 29,782,324)의 재현과 통과를 감시 프레임으로 고정합니다.
#   기전: 골드 숫자는 오른쪽 정렬이라 글자 왼쪽 끝이 x 933~949 사이에서 움직이고, 옛 영역(왼쪽 935)은 여유가 0~1px 라
#         끝이 934~936 이면 첫 글자가 잘려 '?9,782,324' → 9,782,324. 같은 값에서 결정적으로 반복 - 2연속 확정으로 못 거름.
#   ① 고치기 전 재현: 옛 영역(935,40,150,45)으로 읽으면 앞자리가 빠진 7자리 값
#   ② 고친 후 통과: 소스의 현행 영역(910~)으로 읽으면 HUD 정수값 그대로 (아이콘 융합 회귀 캡처 포함)
#   ③ 파서 강화: 중간 글자 '2,'가 '기'로 읽히는 프레임은 틀린 값 대신 -1 (호출부 재시도 경로)
# 기대값은 HUD 전체 정수(프레임 육안·전수 비교 3영역 일치)로 고정 - 자료 던전이미지\실측기록\20260915_냥코인_골드_앞자리잘림_프레임\
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
[Console]::OutputEncoding = [Text.Encoding]::UTF8
function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$frameDir = Join-Path $projectRoot '던전이미지\실측기록\20260915_냥코인_골드_앞자리잘림_프레임'
if (-not (Test-Path -LiteralPath $frameDir)) { "SKIP 보존 프레임 폴더가 없어 진리표를 건너뜁니다: $frameDir"; exit $fails }

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
if (-not $ocrKoreanEngine) { 'SKIP 한국어 OCR 엔진을 만들 수 없어 진리표를 건너뜁니다 (ko 언어 팩 없음)'; exit $fails }

. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
# 본체 함수는 소스에서 그대로 (OCR 브리지 2 + 영역 판독 + 파서 + 재화 판독)
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Get-GameRegionOcrText', 'Get-NyanNumberValue', 'Read-NyanAmount')) {
  Invoke-Expression $definition
}
# 영역은 소스 대입식에서 캡처 (사본 진리표 금지)
$goldAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$goldAssign = $goldAst.Find({
    param($node)
    ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$rgNyanGold')
  }, $true)
if (-not $goldAssign) { 'FAIL 본체에서 $rgNyanGold 정의를 찾지 못했습니다'; exit 1 }
Invoke-Expression $goldAssign.Extent.Text
$currentRegion = @($rgNyanGold)
$oldRegion = @(935, 40, 150, 45)   # 고치기 전 영역 (재현용 - 소스가 아니라 사고 당시 값이라 리터럴)

# 게임 창 캡처를 PNG/JPG 재생으로 대체 (워커 Get-GameRegionCapture 와 같은 수식 - 창 = 이미지 전체)
$script:referenceWidth = 1272; $script:referenceHeight = 717
function Get-GameRegionCapture {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3,
    [switch]$BinaryWhiteText, [switch]$ThrowOnWindowRectFailure)
  $imageW = $script:sourceBitmap.Width; $imageH = $script:sourceBitmap.Height
  $cropLeft = [int][Math]::Round($ReferenceX * $imageW / $script:referenceWidth)
  $cropTop = [int][Math]::Round($ReferenceY * $imageH / $script:referenceHeight)
  $cropW = [Math]::Max(1, [int][Math]::Round($RegionWidth * $imageW / $script:referenceWidth))
  $cropH = [Math]::Max(1, [int][Math]::Round($RegionHeight * $imageH / $script:referenceHeight))
  $crop = New-Object System.Drawing.Bitmap $cropW, $cropH
  $cropGraphics = [System.Drawing.Graphics]::FromImage($crop)
  try {
    $cropGraphics.DrawImage($script:sourceBitmap, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)),
      (New-Object System.Drawing.Rectangle($cropLeft, $cropTop, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
  } finally { $cropGraphics.Dispose() }
  $scaled = New-Object System.Drawing.Bitmap ($RegionWidth * $Scale), ($RegionHeight * $Scale)
  $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
  try {
    $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $scaledGraphics.DrawImage($crop, (New-Object System.Drawing.Rectangle(0, 0, ($RegionWidth * $Scale), ($RegionHeight * $Scale))),
      (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
  } finally { $scaledGraphics.Dispose(); $crop.Dispose() }
  return [pscustomobject]@{ Bitmap = $scaled }
}
function Read-GoldWith { param([int[]]$Region) return (Read-NyanAmount -Game $null -Region $Region) }   # 워커 경로 그대로(배율 4 + 파서)
function Read-RawWith { param([int[]]$Region) return ((Get-GameRegionOcrText -Game $null -ReferenceX $Region[0] -ReferenceY $Region[1] -RegionWidth $Region[2] -RegionHeight $Region[3] -Scale 4 -Engine $ocrKoreanEngine) -replace '\s', '') }
function Use-Frame { param([string]$Name) if ($script:sourceBitmap) { $script:sourceBitmap.Dispose() }; $script:sourceBitmap = [System.Drawing.Bitmap]::FromFile((Join-Path $frameDir $Name)) }

# ── 0. 영역 계약 ──
Assert-Case '영역: 왼쪽 경계가 글자 최소 경계(933)에서 20px 이상 여유 (≤ 913)' ([int]$currentRegion[0] -le 913) $true
Assert-Case '영역: 아이콘을 반쪽만 자르지 않도록 아이콘 왼쪽(≈915)보다 왼쪽에서 시작' ([int]$currentRegion[0] -lt 915) $true
Assert-Case '영역: 오른쪽 경계 1085 불변 (냥코인 영역과 맞닿음)' ([int]$currentRegion[0] + [int]$currentRegion[2]) 1085
Assert-Case '영역: 세로 불변 (40, 45)' ("$($currentRegion[1]),$($currentRegion[3])") '40,45'

# ── 1. 앞자리 잘림 프레임 4장: 옛 영역 재현 → 현행 영역 통과 ──
$cutCases = @(
  @{ Frame = '2차_f00000_000081_tick.jpg'; Hud = 29782324; OldRead = 9782324;  Note = '시작 골드 사고 프레임 (경계 936)' },
  @{ Frame = '2차_f02000_407297_tick.jpg'; Hud = 29782324; OldRead = 9782324;  Note = '같은 값 407초 뒤 (결정적 반복)' },
  @{ Frame = '2차_f02711_566579_lclick.jpg'; Hud = 29780524; OldRead = 9780524; Note = '경계 935' },
  @{ Frame = '1차_f00631_206449_lclick.jpg'; Hud = 29962924; OldRead = 9962924; Note = '1차 실기 경계 935' }
)
foreach ($case in $cutCases) {
  Use-Frame $case.Frame
  Assert-Case ("재현(옛 영역) {0}: 앞자리 잘림 {1} - {2}" -f $case.Frame, $case.OldRead, $case.Note) (Read-GoldWith $oldRegion) $case.OldRead
  Assert-Case ("통과(현행 영역) {0}: HUD 값 {1}" -f $case.Frame, $case.Hud) (Read-GoldWith $currentRegion) $case.Hud
}

# ── 2. 정상·경계 프레임: 현행 영역이 HUD 값 그대로 (아이콘 융합 회귀 캡처 포함) ──
$okCases = @(
  @{ Frame = '1차_f00000_083016_tick.jpg'; Hud = 30062324; Note = '1차 시작 골드 (경계 939)' },
  @{ Frame = '1차_f00192_120637_tick.jpg'; Hud = 30031124; Note = '아이콘 반쪽 융합 회귀 (930 영역이면 230031124)' },
  @{ Frame = '1차_f00642_208699_tick.jpg'; Hud = 29961124; Note = '경계 941' },
  @{ Frame = '2차_f02712_566766_tick.jpg'; Hud = 29778724; Note = '전환점 (경계 937)' },
  @{ Frame = '2차_f03000_622203_tick.jpg'; Hud = 29724124; Note = '경계 942' },
  @{ Frame = '2차_f04371_886454_tick.jpg'; Hud = 29458924; Note = '경계 934 (@ 접두 + 마침표 구분)' }
)
foreach ($case in $okCases) {
  Use-Frame $case.Frame
  Assert-Case ("보존 {0}: HUD 값 {1} - {2}" -f $case.Frame, $case.Hud, $case.Note) (Read-GoldWith $currentRegion) $case.Hud
}

# ── 3. 내부 잡음('기') 프레임: 틀린 값 대신 -1 (호출부 재시도), 원문에 '기'가 실제로 있음 ──
$junkCases = @(
  @{ Frame = '2차_f03401_699641_tick.jpg'; Hud = 29652124 },
  @{ Frame = '2차_f03715_760016_lclick.jpg'; Hud = 29592524 },
  @{ Frame = '1차_f00187_119730_tick.jpg'; Hud = 30032924; OldOnly = $true }   # 옛 영역에서 '3003기924' - 현행 영역은 정상
)
foreach ($case in $junkCases) {
  Use-Frame $case.Frame
  $region = $(if ($case.OldOnly) { $oldRegion } else { $currentRegion })
  $raw = Read-RawWith $region
  "  ({0} 원문: '{1}')" -f $case.Frame, $raw
  Assert-Case ("잡음 {0}: 원문에 '기' 오독이 있음 (재현 자료)" -f $case.Frame) ($raw.Contains('기')) $true
  Assert-Case ("잡음 {0}: 파서가 틀린 7자리 대신 -1" -f $case.Frame) (Get-NyanNumberValue -Text $raw) (-1)
  if ($case.OldOnly) {
    Assert-Case ("잡음 {0}: 현행 영역은 HUD 값 {1}" -f $case.Frame, $case.Hud) (Read-GoldWith $currentRegion) $case.Hud
  }
}
if ($script:sourceBitmap) { $script:sourceBitmap.Dispose() }

exit $fails
