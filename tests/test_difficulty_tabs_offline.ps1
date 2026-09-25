# 어비스 상세 화면 난이도 알약 영역 오프라인 진리표 (v2.1.12 - 2026-09-20 신설, coordsVersion 16)
# 타 PC 제보(2026-09-15, 1272x717 창): 상세 화면의 난이도 알약이 y136~162 에 놓여 옛 영역 difficultyTabs (30,150,500,60) 의
# 상단 150 이 글자 한가운데를 지나 판독이 빈 문자열 → '매우 어려움' 미탐 → 일반 반복은 '현재 선택된 난이도로 진행' 경고
# (제보 로그 9회차 중 3회차 관측), 커스텀은 코드 4 정지(코드 확정, 관측 아님). 개발 PC 배치는 y163~195. 여기서 고정하는 것:
#   ① 고치기 전 재현: 제보 캡처를 옛 영역으로 읽으면 Find-GameTextPoint('매우'/'매우어려움') 가 $null
#   ② 고친 후 통과: 소스의 현행 영역(대입식에서 캡처 - 사본 금지)으로 읽으면 알약 띠(y136~162) 안의 점을 돌려줌
#   ③ 기존 배치 보존: 개발 PC 캡처 3장(탭별)은 옛·새 영역 모두 '매우' 를 찾고, 새 영역의 점이 알약 띠(y163~195) 안
#   ④ 새 경로 검증(규칙 8): 확장으로 위쪽 띠가 먼저 읽히는데, Contains 폴백은 읽기 순서 첫 단어를 고르므로 '매우'/'입문' 을
#      담은 단어가 알약 말고는 없어야 함 (있으면 그 글자가 클릭 표적이 되는 새 경로)
#   ⑤ 단어 목록 수준 모의 진리표: '매우어려움' 은 OCR 이 두 단어로 쪼개 ExactText 가 늘 실패하고 PARTIAL '매우' 만 탄다 -
#      정확 일치 우선·읽기 순서·제목 조각 무시·알려진 한계(위쪽 띠에 '매우' 조각이 오면 그 단어가 표적)를 그대로 고정
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
[Console]::OutputEncoding = [Text.Encoding]::UTF8
function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$reportDir = Join-Path $projectRoot '던전이미지\어비스\20260915_타PC_어비스_입장미감지_트래커상단잘림'
$devDir = Join-Path $projectRoot '던전이미지\어비스\20260916_어비스상세_제목판독_탭별'
$captures = [ordered]@{
  Report = Join-Path $reportDir 'error_20260915_h02m48s43.png'   # 제보: 상세 화면, 알약 y136~162 ('매우 어려움' 이미 선택)
  Dev1   = Join-Path $devDir '1_함께하기_토글끔.png'              # 개발 PC 배치: 알약 y163~195
  Dev2   = Join-Path $devDir '2_함께하기_토글켬.png'
  Dev3   = Join-Path $devDir '3_혼자하기.png'                     # 지옥1 알약 없음
}
foreach ($key in $captures.Keys) {
  if (-not (Test-Path -LiteralPath $captures[$key])) { "SKIP 보존 캡처가 없어 진리표를 건너뜁니다: $($captures[$key])"; exit $fails }
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
if (-not $ocrKoreanEngine) { 'SKIP 한국어 OCR 엔진을 만들 수 없어 진리표를 건너뜁니다 (ko 언어 팩 없음)'; exit $fails }

. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
# 본체 함수는 소스에서 그대로 (OCR 브리지 2 + 글자 위치 탐색 - 워커 $selectDungeonDifficulty 가 쓰는 바로 그 함수)
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Find-GameTextPoint')) {
  Invoke-Expression $definition
}
# 영역은 소스 대입식에서 캡처 (config 미정의 → 기본값)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$workerAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$regionAssign = $workerAst.Find({
    param($node)
    ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$rgDifficultyTabs')
  }, $true)
if (-not $regionAssign) { 'FAIL 본체에서 $rgDifficultyTabs 정의를 찾지 못했습니다'; exit 1 }
Invoke-Expression $regionAssign.Extent.Text
$currentRegion = @($rgDifficultyTabs)
$v15Region = @(30, 150, 500, 60)   # 고치기 전 영역 (재현용 - 소스가 아니라 사고 당시 값이라 리터럴)

# 게임 창 캡처를 PNG 재생으로 대체 (워커 Get-GameRegionCapture 와 같은 수식 - 창 = 이미지 전체, 자르기 → 확대 2단계)
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
  $scaledW = $RegionWidth * $Scale; $scaledH = $RegionHeight * $Scale
  $scaled = New-Object System.Drawing.Bitmap $scaledW, $scaledH
  $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
  try {
    $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $scaledGraphics.DrawImage($crop, (New-Object System.Drawing.Rectangle(0, 0, $scaledW, $scaledH)),
      (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
  } finally { $scaledGraphics.Dispose(); $crop.Dispose() }
  return [pscustomobject]@{ Bitmap = $scaled; CropLeft = $cropLeft; CropTop = $cropTop; CropWidth = $cropW; CropHeight = $cropH
    ScaledWidth = $scaledW; ScaledHeight = $scaledH }
}
function Use-Capture { param([string]$Path) if ($script:sourceBitmap) { $script:sourceBitmap.Dispose() }; $script:sourceBitmap = [System.Drawing.Bitmap]::FromFile($Path) }
function Find-Difficulty {
  # 워커 $selectDungeonDifficulty 와 같은 호출 규칙: 앞 2글자 부분 일치 + 전체 정확 일치, 기본 배율 3
  param([int[]]$Region, [string]$Key)
  $search = $Key.Substring(0, [Math]::Min(2, $Key.Length))
  return Find-GameTextPoint -Game $null -ReferenceX $Region[0] -ReferenceY $Region[1] `
    -RegionWidth $Region[2] -RegionHeight $Region[3] -SearchText $search -ExactText $Key
}
function Read-Words {
  # 기록·새 경로 검증용: 영역의 단어 목록 (공백 제거, 읽기 순서)
  param([int[]]$Region)
  $capture = Get-GameRegionCapture -Game $null -ReferenceX $Region[0] -ReferenceY $Region[1] -RegionWidth $Region[2] -RegionHeight $Region[3] -Scale 3
  try {
    $result = Invoke-OcrOnBitmap -Bitmap $capture.Bitmap -Engine $ocrKoreanEngine
    return @($result.Lines | ForEach-Object { $_.Words } | ForEach-Object { ($_.Text -replace '\s', '') })
  } finally { $capture.Bitmap.Dispose() }
}
function Format-Point { param($Point) if ($null -eq $Point) { 'null' } else { "($($Point.X),$($Point.Y))" } }

# ── 0. 영역 계약 ──
Assert-Case '영역: 상단이 제보 알약 띠(y136)보다 위 (≤ 130)' ([int]$currentRegion[1] -le 130) $true
Assert-Case '영역: 하단 경계 210 유지 (옛 영역이 부분집합 - 소비처 보존)' ([int]$currentRegion[1] + [int]$currentRegion[3]) 210
Assert-Case '영역: x·폭 불변 (30, 500)' ("$($currentRegion[0]),$($currentRegion[2])") '30,500'

# ── 1. 제보 캡처: 고치기 전 재현 → 고친 후 통과 ──
Use-Capture $captures.Report
Assert-Case '제보 캡처 크기 1272x717 (권장 창 크기 그대로)' ("$($script:sourceBitmap.Width)x$($script:sourceBitmap.Height)") '1272x717'
$oldPoint = Find-Difficulty $v15Region '매우어려움'
$oldWords = @(Read-Words $v15Region)
"  (옛 영역 '매우' 탐색: $(Format-Point $oldPoint), 단어: '$($oldWords -join ' | ')')"
Assert-Case '재현(옛 영역): 제보 캡처에서 매우 어려움 미탐 (null)' ($null -eq $oldPoint) $true
$newPoint = Find-Difficulty $currentRegion '매우어려움'
$newWords = @(Read-Words $currentRegion)
"  (현행 영역 '매우' 탐색: $(Format-Point $newPoint), 단어: '$($newWords -join ' | ')')"
Assert-Case '통과(현행 영역): 매우 어려움 탐색 성공' ($null -ne $newPoint) $true
Assert-Case '통과(현행 영역): 점이 제보 알약 띠(y136~162) 안' (($null -ne $newPoint) -and ($newPoint.Y -ge 136) -and ($newPoint.Y -le 162)) $true
$easyPoint = Find-Difficulty $currentRegion '입문'
$hardPoint = Find-Difficulty $currentRegion '어려움'
"  (입문 $(Format-Point $easyPoint) / 어려움 $(Format-Point $hardPoint))"
Assert-Case '통과(현행 영역): 입문·어려움도 같은 줄 (y 차 ≤ 6)' (($null -ne $easyPoint) -and ($null -ne $hardPoint) -and ($null -ne $newPoint) -and
  ([Math]::Abs($easyPoint.Y - $newPoint.Y) -le 6) -and ([Math]::Abs($hardPoint.Y - $newPoint.Y) -le 6)) $true
Assert-Case '통과(현행 영역): 왼쪽부터 입문 < 어려움 < 매우 (알약 순서 - 어려움 은 정확 일치가 둘째 알약을 고름)' `
  (($null -ne $easyPoint) -and ($null -ne $hardPoint) -and ($null -ne $newPoint) -and ($easyPoint.X -lt $hardPoint.X) -and ($hardPoint.X -lt $newPoint.X)) $true
Assert-Case '새 경로(제보): 매우 를 담은 단어가 알약 하나뿐 (위쪽 띠 유입 없음)' (@($newWords | Where-Object { $_.Contains('매우') }).Count) 1
Assert-Case '새 경로(제보): 입문 을 담은 단어가 알약 하나뿐' (@($newWords | Where-Object { $_.Contains('입문') }).Count) 1

# ── 2. 개발 PC 배치 보존 (탭별 캡처 3장) ──
foreach ($devKey in @('Dev1', 'Dev2', 'Dev3')) {
  Use-Capture $captures[$devKey]
  $devOld = Find-Difficulty $v15Region '매우어려움'
  $devNew = Find-Difficulty $currentRegion '매우어려움'
  $devWords = @(Read-Words $currentRegion)
  "  ($devKey 옛 $(Format-Point $devOld) / 현행 $(Format-Point $devNew), 단어: '$($devWords -join ' | ')')"
  Assert-Case "보존($devKey): 옛 영역에서도 매우 어려움 탐색 (개발 PC 배치는 원래 정상)" ($null -ne $devOld) $true
  Assert-Case "보존($devKey): 현행 영역 점이 개발 PC 알약 띠(y163~195) 안" (($null -ne $devNew) -and ($devNew.Y -ge 163) -and ($devNew.Y -le 195)) $true
  Assert-Case "보존($devKey): 옛·현행 점의 x 차 ≤ 6 (같은 알약)" (($null -ne $devOld) -and ($null -ne $devNew) -and ([Math]::Abs($devOld.X - $devNew.X) -le 6)) $true
  Assert-Case "새 경로($devKey): 매우 를 담은 단어가 알약 하나뿐" (@($devWords | Where-Object { $_.Contains('매우') }).Count) 1
  Assert-Case "새 경로($devKey): 입문 을 담은 단어가 알약 하나뿐" (@($devWords | Where-Object { $_.Contains('입문') }).Count) 1
}
if ($script:sourceBitmap) { $script:sourceBitmap.Dispose(); $script:sourceBitmap = $null }

# ── 3. 단어 목록 수준 모의 진리표: Find-GameTextPoint 의 선택 규칙 (OCR 결과를 값으로 줌) ──
# 좌표 환산: 화면 x = CropLeft + round(중심x × CropWidth / ScaledWidth) = 30 + round(중심x / 3), y = 120 + round(중심y / 3)
function Get-GameRegionCapture {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3,
    [switch]$BinaryWhiteText, [switch]$ThrowOnWindowRectFailure)
  return [pscustomobject]@{ Bitmap = (New-Object System.Drawing.Bitmap 1, 1); CropLeft = $ReferenceX; CropTop = $ReferenceY
    CropWidth = $RegionWidth; CropHeight = $RegionHeight; ScaledWidth = ($RegionWidth * $Scale); ScaledHeight = ($RegionHeight * $Scale) }
}
function Invoke-OcrOnBitmap { param($Bitmap, $Engine) return [pscustomobject]@{ Lines = @($script:mockLines) } }
function New-MockWord { param([string]$Text, [int]$X, [int]$Y, [int]$W = 60, [int]$H = 30)
  [pscustomobject]@{ Text = $Text; BoundingRect = [pscustomobject]@{ X = $X; Y = $Y; Width = $W; Height = $H } } }
function New-MockLine { param([object[]]$Words) [pscustomobject]@{ Words = @($Words) } }
$mockRegion = @(30, 120, 500, 90)
# 알약 줄 (확대 좌표): 입문@60 / 어려움@210 / 매우@420 / 어려움@500, y120 → '매우' 중심 (450,135) → 화면 (180,165)
$pillLine = New-MockLine @((New-MockWord '입문' 60 120), (New-MockWord '어려움' 210 120), (New-MockWord '매우' 420 120), (New-MockWord '어려움' 500 120))
$script:mockLines = @($pillLine)
Assert-Case '모의: 쪼개진 매우+어려움 은 정확 일치 실패 → PARTIAL 매우 (셋째 알약 앞단어)' (Format-Point (Find-Difficulty $mockRegion '매우어려움')) '(180,165)'
Assert-Case '모의: 어려움 키는 정확 일치 우선 → 둘째 알약 (셋째 알약 뒷단어 아님)' (Format-Point (Find-Difficulty $mockRegion '어려움')) '(110,165)'
Assert-Case '모의: 입문 키' (Format-Point (Find-Difficulty $mockRegion '입문')) '(60,165)'
$script:mockLines = @((New-MockLine @((New-MockWord '61상의징박지' 40 10 200 30))), $pillLine)
Assert-Case '모의: 위쪽 띠의 제목 조각(09-18 재현 문자열)은 무시하고 알약을 고름' (Format-Point (Find-Difficulty $mockRegion '매우어려움')) '(180,165)'
$script:mockLines = @((New-MockLine @((New-MockWord '매우x' 40 10), (New-MockWord '매우어려움' 400 120 150 30))))
Assert-Case '모의: 한 단어로 읽힌 매우어려움 은 앞선 부분 일치보다 우선 (정확 일치 우선)' (Format-Point (Find-Difficulty $mockRegion '매우어려움')) '(188,165)'
$script:mockLines = @((New-MockLine @((New-MockWord '매우한이름' 40 10))), $pillLine)
Assert-Case '모의: 알려진 한계 - 위쪽 띠에 매우 조각이 오면 그 단어가 표적 (실측 던전명엔 없음 - 위 캡처 단언이 지킴)' (Format-Point (Find-Difficulty $mockRegion '매우어려움')) '(53,128)'
$script:mockLines = @()
Assert-Case '모의: 단어 없음 → null (고정 좌표 폴백 없음)' (Format-Point (Find-Difficulty $mockRegion '매우어려움')) 'null'

exit $fails