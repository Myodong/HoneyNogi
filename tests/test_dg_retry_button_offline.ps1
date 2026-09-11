# 던전 결과 화면 '다시 하기' 탐색 - 이진화 폴백 진리표 (2026-09-11 실사고: 하루 4회 정지)
# 게임이 DPI 미인식이라 150% 디스플레이에서는 1272 렌더를 Windows 가 1.5배 늘린 1908 창이 캡처되고,
# 광택 그라데이션 위 흰 글자 '다시 하기'가 일반 판독에서 '담k`6\기' 같은 한 덩어리로 깨졌다.
# 보존한 오류 캡처 10장으로 '고치기 전(일반 s5)' 재현과 '고친 후(이진화 폴백)' 통과를
# **실제 탐색 함수(Find-DgRetryButtonPoint → Find-GameTextPoint)를 돌려** 확인하고, 반환 좌표가
# '다시 하기' 버튼 안인지까지 본다. 캡처 폴더가 없는 PC 는 진리표만 건너뛴다(배선 가드는 항상 실행).
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}
function Get-CodeWithoutComments([string]$Text) {
  # 소스 문자열 단언은 주석을 뺀 사본으로 (Get-SourceFunctionDefinitions 는 주석 포함)
  return (($Text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
}

# ── 1. 배선 가드 (캡처 없이도 실행) ─────────────────────────────────────────────
$textPointCode = Get-CodeWithoutComments ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Find-GameTextPoint')))
$retryCode = Get-CodeWithoutComments ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Find-DgRetryButtonPoint')))
$nextFloorCode = Get-CodeWithoutComments ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Find-DgNextFloorButtonPoint')))
Assert-Case '가드: Find-GameTextPoint 에 BinaryWhiteText 스위치 선언' ($textPointCode -match '\[switch\]\$BinaryWhiteText') $true
Assert-Case '가드: Find-GameTextPoint 가 스위치를 캡처 함수로 통과' ([regex]::Matches($textPointCode, '-BinaryWhiteText:\$BinaryWhiteText').Count) 1
Assert-Case '가드: 다시 하기 탐색 - 같은 어휘 루프 2회(일반 + 이진화)' ([regex]::Matches($retryCode, "@\('다시', '다셔', '하기'\)").Count) 2
Assert-Case '가드: 다시 하기 탐색 - 이진화 호출은 정확히 1곳, 배율 5' ([regex]::Matches($retryCode, '-Scale 5 -BinaryWhiteText').Count) 1
Assert-Case '가드: 다시 하기 탐색 - 일반 호출(스위치 없음) 1곳 유지' ([regex]::Matches($retryCode, '-Scale 5\s*$', 'Multiline').Count) 1
# 주석 제거 사본은 LF 로 결합돼 있다 - 두 호출 위치가 모두 존재하고(≥0) 일반이 앞서야 한다
# (리뷰 지적: -or 로 CRLF 검색을 붙이면 그쪽이 항상 -1 이라 역순도 통과하는 헛단언이었다)
$normalCallIndex = $retryCode.IndexOf('-Scale 5' + "`n")
$binaryCallIndex = $retryCode.IndexOf('-Scale 5 -BinaryWhiteText')
Assert-Case '가드: 다시 하기 탐색 - 일반 판독이 이진화보다 먼저' (($normalCallIndex -ge 0) -and ($binaryCallIndex -ge 0) -and ($normalCallIndex -lt $binaryCallIndex)) $true
Assert-Case '가드: 다음 층 탐색은 이진화를 쓰지 않음(변경 근거 없음)' ($nextFloorCode -match 'BinaryWhiteText') $false

# ── 2. 캡처 진리표 ──────────────────────────────────────────────────────────────
$captureDir = Join-Path $projectRoot '던전이미지\실측기록\20260911_심층결과화면_다시하기_미탐지_1908'
if (-not (Test-Path -LiteralPath $captureDir)) {
  "SKIP 실측 캡처 폴더가 없어 오프라인 진리표를 건너뜁니다: $captureDir"
  exit $fails
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
  'SKIP 한국어 OCR 엔진을 만들 수 없어 진리표를 건너뜁니다 (ko 언어 팩 없음)'
  exit $fails
}

# 본체 함수는 사본이 아니라 소스에서 그대로 불러온다 (탐색 함수 2개 + OCR 브리지 2개)
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Find-GameTextPoint', 'Find-DgRetryButtonPoint', 'Find-DgNextFloorButtonPoint')) {
  Invoke-Expression $definition
}
# 영역 변수도 소스 대입식을 그대로 실행 (config 미정의 → 기본값)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
# 폴백 구제 로그(회차당 1회)는 기록만 모은다 - 첫 구제 캡처에서 정확히 1번 나와야 한다
$script:fallbackLogs = New-Object 'System.Collections.Generic.List[string]'
function Write-RunLog { param([string]$Message) $script:fallbackLogs.Add($Message) }
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$regionAssign = $sourceAst.Find({
    param($node)
    ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
    ($node.Left.Extent.Text -eq '$rgDgRetryBtn')
  }, $false)
if (-not $regionAssign) { 'FAIL 본체에서 $rgDgRetryBtn 정의를 찾지 못했습니다'; $fails++; exit $fails }
Invoke-Expression $regionAssign.Extent.Text

# 게임 창 캡처를 PNG 재생으로 대체 - 워커 Get-GameRegionCapture 와 같은 수식(창 = 이미지 전체),
# 같은 이진화(R,G,B>175 → 검정, 아니면 흰색 + NearestNeighbor), 같은 반환 형태. 호출 모드를 기록해
# '일반 실패 시에만 이진화' 계약을 단언한다.
$script:referenceWidth = 1272
$script:referenceHeight = 717
$script:captureModes = New-Object 'System.Collections.Generic.List[string]'
function Get-GameRegionCapture {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3,
    [switch]$BinaryWhiteText, [switch]$ThrowOnWindowRectFailure)
  $script:captureModes.Add($(if ($BinaryWhiteText) { 'bin' } else { 'normal' }))
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
    if ($BinaryWhiteText) {
      for ($y = 0; $y -lt $cropH; $y++) {
        for ($x = 0; $x -lt $cropW; $x++) {
          $color = $crop.GetPixel($x, $y)
          if ($color.R -gt 175 -and $color.G -gt 175 -and $color.B -gt 175) { $crop.SetPixel($x, $y, [System.Drawing.Color]::Black) }
          else { $crop.SetPixel($x, $y, [System.Drawing.Color]::White) }
        }
      }
      $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    } else {
      $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    }
    $scaledGraphics.DrawImage($crop, (New-Object System.Drawing.Rectangle(0, 0, ($RegionWidth * $Scale), ($RegionHeight * $Scale))),
      (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
  } finally { $scaledGraphics.Dispose(); $crop.Dispose() }
  return [pscustomobject]@{
    Bitmap = $scaled; CropLeft = $cropLeft; CropTop = $cropTop; CropWidth = $cropW; CropHeight = $cropH
    ScaledWidth = ($RegionWidth * $Scale); ScaledHeight = ($RegionHeight * $Scale); Scale = $Scale
  }
}

# 이 PC 실측 (2026-09-11, 1908x1076 캡처): 일반 s5 가 읽어낸 2장. OCR 엔진 판이 다른 PC 는 다를 수 있다.
$expectNormalHit = @('error_20260911_h11m56s56', 'error_20260911_h12m18s01')
# '다시 하기' 버튼 안쪽 상자(캡처 픽셀, 버튼 실측 x 965~1305 / y 940~1025 의 안쪽) - 반환 좌표가 이 안이어야
# 클릭이 그 버튼에 떨어진다. 좌측 '나가기' 버튼(x ≤ 945)은 필드로 나가는 최악 경로.
$retryBox = @{ Left = 990; Top = 950; Right = 1290; Bottom = 1020 }
$files = @(Get-ChildItem -LiteralPath $captureDir -Filter 'error_20260911_*.png' | Sort-Object Name)
Assert-Case '진리표: 보존 캡처 10장' $files.Count 10
$normalHits = 0; $binRescued = 0; $maxElapsedMs = 0
foreach ($file in $files) {
  $script:sourceBitmap = [System.Drawing.Bitmap]::FromFile($file.FullName)
  try {
    # 고치기 전 재현: 기존 함수의 첫 루프(일반 s5, 3어휘)만 — 실패가 재현돼야 수정에 근거가 있다
    $script:captureModes.Clear()
    $normalPoint = $null
    foreach ($searchWord in @('다시', '다셔', '하기')) {
      $normalPoint = Find-GameTextPoint -Game $null -ReferenceX $rgDgRetryBtn[0] -ReferenceY $rgDgRetryBtn[1] `
        -RegionWidth $rgDgRetryBtn[2] -RegionHeight $rgDgRetryBtn[3] -SearchText $searchWord -Scale 5
      if ($normalPoint) { break }
    }
    $expectedHit = ($expectNormalHit -contains $file.BaseName)
    Assert-Case ("고치기 전(일반 s5) {0}" -f $file.BaseName) ([bool]$normalPoint) $expectedHit
    if ($normalPoint) { $normalHits++ }

    # 고친 후: 실제 탐색 함수 - 반환 좌표가 '다시 하기' 버튼 안
    $script:captureModes.Clear()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $point = Find-DgRetryButtonPoint -Game $null
    $stopwatch.Stop()
    if ($stopwatch.ElapsedMilliseconds -gt $maxElapsedMs) { $maxElapsedMs = $stopwatch.ElapsedMilliseconds }
    $pointText = if ($point) { "({0},{1})" -f $point.X, $point.Y } else { 'null' }
    $inside = ($null -ne $point) -and ($point.X -ge $retryBox.Left) -and ($point.X -le $retryBox.Right) -and
      ($point.Y -ge $retryBox.Top) -and ($point.Y -le $retryBox.Bottom)
    Assert-Case ("고친 후 {0}: 반환 좌표 {1} 가 '다시 하기' 버튼 안" -f $file.BaseName, $pointText) $inside $true

    # 폴백 계약: 일반이 읽으면 이진화를 부르지 않고, 못 읽었을 때만 일반 3회 뒤 이진화
    $usedBin = ($script:captureModes -contains 'bin')
    Assert-Case ("폴백 {0}: 일반 실패 시에만 이진화 호출" -f $file.BaseName) $usedBin (-not $expectedHit)
    if ($usedBin) {
      $binRescued++
      $firstBin = $script:captureModes.IndexOf('bin')
      $normalAfterBin = @($script:captureModes | Select-Object -Skip $firstBin | Where-Object { $_ -eq 'normal' }).Count
      Assert-Case ("폴백 순서 {0}: 일반 3회 → 이진화 (일반이 뒤에 다시 오지 않음)" -f $file.BaseName) (($firstBin -eq 3) -and ($normalAfterBin -eq 0)) $true
    }
    # 같은 영역을 읽는 다음 층 탐색은 2버튼 배치에서 null 이어야 한다 (폴백이 새 오탐 경로를 열지 않음)
    Assert-Case ("다음 층 탐색 {0}: 2버튼 배치라 null" -f $file.BaseName) ($null -eq (Find-DgNextFloorButtonPoint -Game $null)) $true
  } finally {
    $script:sourceBitmap.Dispose()
  }
}
Assert-Case '집계: 일반 s5 만으로는 2/10 (고치기 전 재현)' $normalHits 2
Assert-Case '집계: 이진화 폴백이 나머지 8장을 구제' $binRescued 8
# 구제 로그는 프로세스(회차)당 첫 1회만 - 8장을 구제해도 1줄, 내용은 이진화 구제 문구
Assert-Case '집계: 폴백 구제 로그는 회차당 1줄' $script:fallbackLogs.Count 1
Assert-Case '집계: 구제 로그 문구' ($script:fallbackLogs[0] -match "흰 글자 이진화로 찾음") $true
"INFO 탐색 1회 최대 소요 {0}ms (폴백 포함 OCR 최대 6회 - 폴링 주기는 이 시간 + 2초)" -f $maxElapsedMs

# ── 3. 3버튼 배치(나가기 / 다시 하기 / 다음 구역으로) - 2026-09-11 실기 수집 프레임 ────────────
# 리뷰 조건: 일반 우선이 보존하는 것은 일반 성공 경로뿐이라, 3버튼 배치에서도 일반이 실패했을 때
# 새 경로(이진화)가 **가운데** '다시 하기'를 고르는지 확인해야 한다. 수정 exe 실기(15:10~15:16,
# 2-1/2-2 결과 화면) 중 자동 수집한 프레임 7장 — r3 는 실제로 일반 s5 가 MISS 였던 살아있는 프레임.
$threeButtonDir = Join-Path $projectRoot '던전이미지\실측기록\20260911_심층결과화면_3버튼_다시하기_1908'
if (-not (Test-Path -LiteralPath $threeButtonDir)) {
  "SKIP 3버튼 프레임 폴더가 없어 건너뜁니다: $threeButtonDir"
} else {
  # 3버튼 배치 버튼 실측(캡처 픽셀): 나가기 605~825 / 다시 하기 845~1065 / 다음 구역으로 1085~1305, y 940~1025
  $centerBox = @{ Left = 870; Top = 950; Right = 1040; Bottom = 1015 }
  $frames = @(Get-ChildItem -LiteralPath $threeButtonDir -Filter '*.png' | Sort-Object Name)
  Assert-Case '3버튼: 수집 프레임 7장' $frames.Count 7
  foreach ($frame in $frames) {
    $script:sourceBitmap = [System.Drawing.Bitmap]::FromFile($frame.FullName)
    try {
      # 일반 단계를 강제로 건너뛴 이진화 경로만 - 폴백이 실제로 실행될 때 고르는 지점
      $forced = $null
      foreach ($searchWord in @('다시', '다셔', '하기')) {
        $forced = Find-GameTextPoint -Game $null -ReferenceX $rgDgRetryBtn[0] -ReferenceY $rgDgRetryBtn[1] `
          -RegionWidth $rgDgRetryBtn[2] -RegionHeight $rgDgRetryBtn[3] -SearchText $searchWord -Scale 5 -BinaryWhiteText
        if ($forced) { break }
      }
      $forcedText = if ($forced) { "({0},{1})" -f $forced.X, $forced.Y } else { 'null' }
      $forcedInside = ($null -ne $forced) -and ($forced.X -ge $centerBox.Left) -and ($forced.X -le $centerBox.Right) -and
        ($forced.Y -ge $centerBox.Top) -and ($forced.Y -le $centerBox.Bottom)
      Assert-Case ("3버튼 강제 이진화 {0}: 반환 좌표 {1} 가 가운데 '다시 하기' 안" -f $frame.BaseName, $forcedText) $forcedInside $true
      # 실제 탐색 함수(일반 → 이진화)도 같은 버튼
      $point = Find-DgRetryButtonPoint -Game $null
      $pointText = if ($point) { "({0},{1})" -f $point.X, $point.Y } else { 'null' }
      $inside = ($null -ne $point) -and ($point.X -ge $centerBox.Left) -and ($point.X -le $centerBox.Right) -and
        ($point.Y -ge $centerBox.Top) -and ($point.Y -le $centerBox.Bottom)
      Assert-Case ("3버튼 탐색 {0}: 반환 좌표 {1} 가 가운데 '다시 하기' 안" -f $frame.BaseName, $pointText) $inside $true
    } finally {
      $script:sourceBitmap.Dispose()
    }
  }
}

exit $fails
