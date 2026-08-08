# 생활(채집) 판정 상수의 오프라인 OCR 재현 검증 - 흐름캡처 9장 전수 (2026-08-05 실측)
# 캡처가 기준 좌표계(1272x717)와 1:1 이라 워커의 크롭→확대→OCR 을 그대로 재현합니다.
# 검증: ① 내정보 신호 '생활력'은 1번 캡처에서만 (오탐 0건) ② 스킬 시그니처/대상 행 탐색
#       ③ 상세 팝업 '채집물' ④ 퀘스트 present 5장 / 소멸 1장 ⑤ 카운트 추출(보조)
# 캡처 폴더가 없는 PC(부분 클론 등)에서는 건너뜁니다 (스킵 = 실패 아님).
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$captureDir = Join-Path $projectRoot '던전이미지\생활\흐름캡처'
if (-not (Test-Path -LiteralPath $captureDir)) {
  "SKIP 흐름캡처 폴더가 없어 오프라인 OCR 재현을 건너뜁니다: $captureDir"
  exit 0
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
$asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
  Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } |
  Select-Object -First 1
$ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('ko')))
if (-not $ocrKoreanEngine) {
  'SKIP 한국어 OCR 엔진을 만들 수 없어 건너뜁니다 (ko 언어 팩 없음)'
  exit 0
}

# ── 워커에서 함수/데이터 추출 (배포될 코드 그대로 검증) ──
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Get-LifeNormalizedName', 'Test-LifeNameMatches', 'Test-LifeBodyNameAmbiguous', 'Get-LifeDetailVerdict', 'Get-LifeDetailTitleFromWords', 'Test-LifeTitleNameMatches', 'Get-LifeTitleVerdict', 'Test-LifeWindowClosePixels')) {
  Invoke-Expression $definition
}
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$config = $null
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
foreach ($varName in @('lifeSkillMenuTable', 'lifeTargetVariants', 'lifeTitleVariants', 'lifeNameRepairPairs', 'rgLifeStats', 'rgLifeTargetList', 'rgLifeDetail', 'rgLifeFindLink', 'rgQuestTracker')) {
  $assign = $sourceAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $varName))
    }, $true)
  if (-not $assign) { "FAIL 본체에서 `$$varName 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $assign.Extent.Text
}

# ── 캡처(기준 좌표계 1:1) 크롭 → 확대 → OCR (워커 Get-GameRegionCapture 의 오프라인 등가) ──
function Get-BitmapRegionOcr {
  param([System.Drawing.Bitmap]$Source, [int[]]$Region, [int]$Scale)
  $crop = New-Object System.Drawing.Bitmap($Region[2], $Region[3])
  $scaled = $null
  try {
    $g = [System.Drawing.Graphics]::FromImage($crop)
    try {
      $g.DrawImage($Source, (New-Object System.Drawing.Rectangle(0, 0, $Region[2], $Region[3])),
        $Region[0], $Region[1], $Region[2], $Region[3], [System.Drawing.GraphicsUnit]::Pixel)
    } finally { $g.Dispose() }
    $scaled = New-Object System.Drawing.Bitmap($crop, ($Region[2] * $Scale), ($Region[3] * $Scale))
    $g2 = [System.Drawing.Graphics]::FromImage($scaled)
    try {
      $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g2.DrawImage($crop, 0, 0, ($Region[2] * $Scale), ($Region[3] * $Scale))
    } finally { $g2.Dispose() }
    return (Invoke-OcrOnBitmap -Bitmap $scaled -Engine $ocrKoreanEngine)
  } finally {
    $crop.Dispose()
    if ($scaled) { $scaled.Dispose() }
  }
}

function Get-RegionText {
  param([System.Drawing.Bitmap]$Source, [int[]]$Region, [int]$Scale = 3)
  return ((Get-BitmapRegionOcr -Source $Source -Region $Region -Scale $Scale).Text -replace '\s', '')
}

# 워커 Get-LifeTargetRows 와 같은 행 조합 규칙 (기준 좌표 환산 + Lv 열 제외 + Y ±14 그룹)
function Get-RegionRows {
  param([System.Drawing.Bitmap]$Source, [int[]]$Region, [int]$Scale)
  $result = Get-BitmapRegionOcr -Source $Source -Region $Region -Scale $Scale
  $words = @()
  foreach ($line in $result.Lines) {
    foreach ($word in $line.Words) {
      $words += , @{
        Text = ($word.Text -replace '\s', '')
        X = $Region[0] + [int][Math]::Round(($word.BoundingRect.X + $word.BoundingRect.Width / 2) / $Scale)
        Y = $Region[1] + [int][Math]::Round(($word.BoundingRect.Y + $word.BoundingRect.Height / 2) / $Scale)
      }
    }
  }
  $rows = @()
  foreach ($listWord in ($words | Where-Object { [int]$_.X -lt 1100 } | Sort-Object { [int]$_.Y }, { [int]$_.X })) {
    $matched = $false
    foreach ($row in $rows) {
      if ([Math]::Abs([int]$listWord.Y - [int]$row.Y) -le 14) {
        $row.Words += , $listWord
        $matched = $true
        break
      }
    }
    if (-not $matched) { $rows += , @{ Words = @(, $listWord); Y = [int]$listWord.Y } }
  }
  # 행 내 X 재정렬 결합 (워커 Get-LifeTargetRows 와 같은 규칙 - Y 어긋남 순서 뒤집힘 방지)
  foreach ($row in $rows) {
    $row.Text = (($row.Words | Sort-Object { [int]$_.X } | ForEach-Object { [string]$_.Text }) -join '')
  }
  return $rows
}

function Assert {
  param([bool]$Condition, [string]$Label)
  if ($Condition) { "OK   $Label" } else { "FAIL $Label"; $script:fails++ }
}

$bitmaps = @{}
foreach ($file in Get-ChildItem (Join-Path $captureDir '*.jpg')) {
  $bitmaps[$file.BaseName] = [System.Drawing.Bitmap]::FromFile($file.FullName)
}
if ($bitmaps.Count -lt 9) { "FAIL 흐름캡처가 9장이 아닙니다 ($($bitmaps.Count)장)"; $fails++ }
try {
  # ── ① 내 정보 판정: 1번 캡처만 true, 나머지 8장 전부 false (오탐 방지) ──
  foreach ($name in $bitmaps.Keys | Sort-Object) {
    $statsText = Get-RegionText -Source $bitmaps[$name] -Region $rgLifeStats
    $expected = ($name -eq '1_내정보_C키')
    Assert (($statsText.Contains('생활력')) -eq $expected) "내정보 판정 [$name] 기대=$expected (판독='$statsText')"
  }

  # ── ② 스킬창: daily 시그니처 + '사과나무' 행 탐색 - 워커 탐색 스케일(s4/s5) '각각 단독'
  #    으로 성공해야 함 (2026-08-06 속도 개선에서 s3 제거 - 합산 검증은 s3 의존을 숨김, Codex)
  $skillBmp = $bitmaps['2_생활스킬창_스킬그리드_대상목록']
  foreach ($listScale in @(4, 5)) {
    $rows = @(Get-RegionRows -Source $skillBmp -Region $rgLifeTargetList -Scale $listScale)
    $joined = (($rows | ForEach-Object { [string]$_.Text }) -join '')
    $sigHit = $false
    foreach ($sigPiece in @($lifeSkillMenuTable['daily'].Sig)) {
      if ($joined.Contains([string]$sigPiece)) { $sigHit = $true }
    }
    $foundY = $null
    foreach ($row in $rows) {
      if (Test-LifeNameMatches -RowText ([string]$row.Text) -TargetName '사과나무') { $foundY = [int]$row.Y; break }
    }
    Assert $sigHit "스킬창 daily 시그니처 검출 [s$listScale 단독]"
    Assert ($null -ne $foundY -and $foundY -ge 150 -and $foundY -le 660) "대상 '사과나무' 행 탐색 [s$listScale 단독] (Y=$foundY)"
  }

  # ── ③ 상세 팝업: Get-LifeDetailVerdict (워커와 같은 판정식) - 시연 JPG + 실기 PNG.
  #    실기 PNG 는 '채집물'이 '자|집물'로 깨지는 실측 사례 (2차 실기 22:51 - 조각 매칭 근거)
  $detailText = Get-RegionText -Source $bitmaps['3_대상상세_가까운위치찾기'] -Region $rgLifeDetail
  Assert ((Get-LifeDetailVerdict -DetailText $detailText -TargetName '사과 나무') -eq 'match') "상세 판정 [시연 JPG] match (판독='$detailText')"
  Assert ((Get-LifeDetailVerdict -DetailText $detailText -TargetName '차나무') -eq 'wrong-target') "상세 판정 [시연 JPG] 다른 대상 거부"
  $fieldPngPath = Join-Path $captureDir '3b_대상상세_실기PNG_채깨짐.png'
  if (Test-Path -LiteralPath $fieldPngPath) {
    $fieldBmp = [System.Drawing.Bitmap]::FromFile($fieldPngPath)
    try {
      $fieldDetailText = Get-RegionText -Source $fieldBmp -Region $rgLifeDetail
      Assert ((Get-LifeDetailVerdict -DetailText $fieldDetailText -TargetName '사과 나무') -eq 'match') "상세 판정 [실기 PNG - 깨짐] match (판독='$fieldDetailText')"
      Assert ((Get-LifeDetailVerdict -DetailText $fieldDetailText -TargetName '차나무') -eq 'wrong-target') "상세 판정 [실기 PNG] 다른 대상 거부"
    } finally { $fieldBmp.Dispose() }
  } else {
    "SKIP 실기 PNG 자산 없음: $fieldPngPath"
  }

  # ── ③c 클릭 직전 같은 프레임 제목 재확인 (2026-08-07 사용자 제안) ──
  # 링크를 찾는 판독($rgLifeFindLink)에서 제목 줄을 뽑아 대상을 다시 확인합니다.
  # 제목 Y 는 고정이 아닙니다 - 팝업이 세로 중앙 정렬이라 위치 줄 유무로 움직입니다
  # (실측: 사과 나무 y191 / 나무 y213). 그래서 '최상단 행' 규칙이 실제로 맞는지 확인합니다.
  function Get-RegionWordList {
    param([System.Drawing.Bitmap]$Source, [int[]]$Region, [int]$Scale)
    $result = Get-BitmapRegionOcr -Source $Source -Region $Region -Scale $Scale
    $words = @()
    foreach ($line in $result.Lines) {
      foreach ($word in $line.Words) {
        $words += , @{
          Text = ($word.Text -replace '\s', '')
          X    = $Region[0] + [int][Math]::Round(($word.BoundingRect.X + $word.BoundingRect.Width / 2) / $Scale)
          Y    = $Region[1] + [int][Math]::Round(($word.BoundingRect.Y + $word.BoundingRect.Height / 2) / $Scale)
        }
      }
    }
    return $words
  }
  $linkWordsDemo = @(Get-RegionWordList -Source $bitmaps['3_대상상세_가까운위치찾기'] -Region $rgLifeFindLink -Scale 3)
  $linkTitleDemo = Get-LifeDetailTitleFromWords -Words $linkWordsDemo
  Assert ((Get-LifeTitleVerdict -Title $linkTitleDemo -TargetName '사과 나무' -Order @($lifeSkillMenuTable['daily'].Order)) -eq 'mine') `
    "클릭직전 제목 재확인 [시연 JPG] mine (제목='$linkTitleDemo')"
  Assert ((Get-LifeTitleVerdict -Title $linkTitleDemo -TargetName '차나무' -Order @($lifeSkillMenuTable['daily'].Order)) -eq 'other') `
    "클릭직전 제목 재확인 [시연 JPG] 다른 대상 차단"
  if (Test-Path -LiteralPath $fieldPngPath) {
    $fieldBmp2 = [System.Drawing.Bitmap]::FromFile($fieldPngPath)
    try {
      $linkWordsField = @(Get-RegionWordList -Source $fieldBmp2 -Region $rgLifeFindLink -Scale 3)
      $linkTitleField = Get-LifeDetailTitleFromWords -Words $linkWordsField
      Assert ((Get-LifeTitleVerdict -Title $linkTitleField -TargetName '사과 나무' -Order @($lifeSkillMenuTable['daily'].Order)) -ne 'other') `
        "클릭직전 제목 재확인 [실기 PNG] 자기 대상을 막지 않음 (제목='$linkTitleField')"
    } finally { $fieldBmp2.Dispose() }
  }

  # ── ③b 생활 창 X 픽셀 판별: 창 화면 3장 = 열림, 필드 3장 = 닫힘 (실측 픽셀 직접 대조) ──
  $windowTruth = @{
    '1_내정보_C키' = $true
    '2_생활스킬창_스킬그리드_대상목록' = $true
    '3_대상상세_가까운위치찾기' = $true
    '4_자동이동_퀘스트트래커' = $false
    '5_채집중_게이지_획득' = $false
    '6_채집종료후_퀘스트소멸' = $false
  }
  foreach ($name in $windowTruth.Keys | Sort-Object) {
    $bmp = $bitmaps[$name]
    $verdict = Test-LifeWindowClosePixels `
      -CrossA $bmp.GetPixel(1227, 65) -CrossB $bmp.GetPixel(1228, 67) `
      -SideA $bmp.GetPixel(1210, 65) -SideB $bmp.GetPixel(1245, 65)
    Assert ($verdict -eq $windowTruth[$name]) "창 픽셀 판별 [$name] 기대=$($windowTruth[$name])"
  }
  # 실기 PNG 자산 (2차 실기 - 반투명 배경 오판/팝업 깨짐 사례): 둘 다 '창 열림'이어야 함
  foreach ($pngName in @('2b_생활스킬창_미선택_전체폭', '3b_대상상세_실기PNG_채깨짐')) {
    $pngPath = Join-Path $captureDir ($pngName + '.png')
    if (-not (Test-Path -LiteralPath $pngPath)) { "SKIP 실기 PNG 자산 없음: $pngPath"; continue }
    $pngBmp = [System.Drawing.Bitmap]::FromFile($pngPath)
    try {
      $verdict = Test-LifeWindowClosePixels `
        -CrossA $pngBmp.GetPixel(1227, 65) -CrossB $pngBmp.GetPixel(1228, 67) `
        -SideA $pngBmp.GetPixel(1210, 65) -SideB $pngBmp.GetPixel(1245, 65)
      Assert ($verdict -eq $true) "창 픽셀 판별 [실기 $pngName] 기대=True"
    } finally { $pngBmp.Dispose() }
  }

  # ── ④ 퀘스트 존재 판정: 채집 중 5장 = present 조각, 종료 후 = 조각 없음 ──
  foreach ($name in @('4_자동이동_퀘스트트래커', '4b_자동이동_몬스터지역통과', '5_채집중_게이지_획득', '5b_채집반복_카운트_경험치배지', '5c_채집_게이지낮음')) {
    $questText = Get-RegionText -Source $bitmaps[$name] -Region $rgQuestTracker
    Assert ($questText.Contains('채집') -and $questText.Contains('장소')) "퀘스트 present [$name] (판독='$questText')"
  }
  $endText = Get-RegionText -Source $bitmaps['6_채집종료후_퀘스트소멸'] -Region $rgQuestTracker
  Assert (-not ($endText.Contains('채집') -and $endText.Contains('장소'))) "퀘스트 소멸 [6_채집종료후] (판독='$endText')"

  # ── ⑤ 카운트(로그 보조): 5b 에서 N/M 추출 ──
  $countRaw = (Get-BitmapRegionOcr -Source $bitmaps['5b_채집반복_카운트_경험치배지'] -Region $rgQuestTracker -Scale 3).Text
  Assert ([regex]::Match([string]$countRaw, '(\d+)\s*/\s*(\d+)').Success) "카운트 추출 [5b]"
} finally {
  foreach ($bmp in $bitmaps.Values) { $bmp.Dispose() }
}

exit $fails
