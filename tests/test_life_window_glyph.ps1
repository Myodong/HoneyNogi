# 생활 창 우상단 X '글리프 서명' 판정 진리표 + 실측 캡처 재현 (2026-08-08 hyodong 제보)
#
# 왜 이 테스트가 필요한가:
#   기준 좌표계(1272x717)는 **제목줄을 포함**하는데 제목줄 높이는 창 크기에 비례하지 않는다
#   (실측: 개발/제보 PC 31px, 다른 제보 PC 38px). 그래서 창 크기가 기준과 다르면 화면
#   최상단일수록 세로 오차가 커지고, 고정 좌표 1점 판정은 즉사한다. 1908 창에서 옛 4점은
#   X 글리프 경계 '안'이지만 두 획 사이의 검은 틈에 떨어져 항상 false 였다.
#   → 판정을 '어디를 보느냐'에서 '무엇이 보이느냐(X 두 대각선 교차)'로 바꿨다.
#
# **개발 PC 는 이 사고를 실기로 재현할 수 없다** (작업 영역 1920x1032 < 1076 이라 1908x1076
# 창을 물리적으로 만들 수 없음). 그래서 제보 캡처를 저장소로 이관해 자산으로 고정했다.
$fails = 0

$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
Add-Type -AssemblyName System.Drawing

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Find-LifeCloseGlyph')) {
  Invoke-Expression $definition
}
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$config = $null
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
$roiAssign = $sourceAst.Find({
    param($node)
    ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
    ($node.Left.Extent.Text -eq '$rgLifeCloseGlyph')
  }, $true)
if (-not $roiAssign) { 'FAIL 본체에서 $rgLifeCloseGlyph 정의를 찾지 못했습니다'; $fails++ }
else { Invoke-Expression $roiAssign.Extent.Text }

# ── ① 순수 진리표: 어떤 형태를 X 로 인정하고 무엇을 거부하는가 ──
function New-LumaMap {
  # 테스트용 밝기 격자 생성 ($Painter 가 (x,y) -> 밝기)
  param([int]$Width, [int]$Height, [scriptblock]$Painter)
  $map = New-Object 'int[][]' $Height
  for ($y = 0; $y -lt $Height; $y++) {
    $row = New-Object 'int[]' $Width
    for ($x = 0; $x -lt $Width; $x++) { $row[$x] = [int](& $Painter $x $y) }
    $map[$y] = $row
  }
  return $map
}
$size = 41
$mid = 20
# X 자: 두 대각선만 밝음
$xShape = New-LumaMap $size $size { param($x, $y) if ([Math]::Abs(($x - 20) - ($y - 20)) -le 1 -or [Math]::Abs(($x - 20) + ($y - 20)) -le 1) { 255 } else { 5 } }
# 배경이 밝아도(생활 스킬 창의 파란 바탕 = 밝기 약 136) 인정해야 합니다. 처음엔 축의 어두움을
# **절대 임계(110)** 로 봤다가 이 화면에서 창을 통째로 못 봤습니다 (2026-08-09 제보) -
# 어제와 같은 고착(창 열림 미감지 → C 무시 → 재시도 소진)으로 이어지는 경로였습니다.
$xOnBlue = New-LumaMap $size $size { param($x, $y) if ([Math]::Abs(($x - 20) - ($y - 20)) -le 1 -or [Math]::Abs(($x - 20) + ($y - 20)) -le 1) { 255 } else { 136 } }
Assert-Case '형태: 밝은(파란) 배경 위의 X 도 인정 - 상대 대비' ([bool](Find-LifeCloseGlyph -Luma $xOnBlue).Found) 'True'
# 반대로 대비가 없으면(중심과 축이 비슷하게 밝음) 거부해야 합니다
$xNoContrast = New-LumaMap $size $size { param($x, $y) if ([Math]::Abs(($x - 20) - ($y - 20)) -le 1 -or [Math]::Abs(($x - 20) + ($y - 20)) -le 1) { 255 } else { 200 } }
Assert-Case '형태: 대비가 부족하면 거부 (중심-축 90 미만)' ([bool](Find-LifeCloseGlyph -Luma $xNoContrast).Found) 'False'
Assert-Case '형태: X 자는 인정' ([bool](Find-LifeCloseGlyph -Luma $xShape).Found) 'True'
# 획에 폭이 있으면 교차 근처 여러 점이 서명을 만족하므로 '정확히 한 점'이 아니라
# '교차점에서 2px 이내'로 고정합니다 (클릭에 쓰기엔 이 정밀도면 충분 - 실측 캡처에서는
# 1272 ref(1227,65) / 1908 ref(1229,56) 로 정확히 나옵니다)
$xHit = Find-LifeCloseGlyph -Luma $xShape
Assert-Case '형태: X 자 중심이 교차점 2px 이내' `
  ([bool]([Math]::Abs($xHit.X - $mid) -le 2 -and [Math]::Abs($xHit.Y - $mid) -le 2)) 'True'
# 십자(+): 축이 밝아 탈락해야 함 (X 와 가장 헷갈리는 형태)
$plusShape = New-LumaMap $size $size { param($x, $y) if ([Math]::Abs($x - 20) -le 1 -or [Math]::Abs($y - 20) -le 1) { 255 } else { 5 } }
Assert-Case '형태: 십자(+)는 거부' ([bool](Find-LifeCloseGlyph -Luma $plusShape).Found) 'False'
# 가로막대 / 세로막대
$hBar = New-LumaMap $size $size { param($x, $y) if ([Math]::Abs($y - 20) -le 2) { 255 } else { 5 } }
Assert-Case '형태: 가로막대는 거부' ([bool](Find-LifeCloseGlyph -Luma $hBar).Found) 'False'
$vBar = New-LumaMap $size $size { param($x, $y) if ([Math]::Abs($x - 20) -le 2) { 255 } else { 5 } }
Assert-Case '형태: 세로막대는 거부' ([bool](Find-LifeCloseGlyph -Luma $vBar).Found) 'False'
# 균일하게 밝은 면 (필드의 밝은 하늘 등)
$flat = New-LumaMap $size $size { param($x, $y) 240 }
Assert-Case '형태: 균일한 밝은 면은 거부' ([bool](Find-LifeCloseGlyph -Luma $flat).Found) 'False'
# 전부 어두움
$dark = New-LumaMap $size $size { param($x, $y) 3 }
Assert-Case '형태: 전부 어두우면 거부' ([bool](Find-LifeCloseGlyph -Luma $dark).Found) 'False'
# 대비 경계 (밝음/어두움 반반)
$edge = New-LumaMap $size $size { param($x, $y) if ($x -lt 20) { 250 } else { 5 } }
Assert-Case '형태: 대비 경계는 거부' ([bool](Find-LifeCloseGlyph -Luma $edge).Found) 'False'
# 너무 작은 격자 (팔 길이보다 작음) - 예외 없이 조용히 미검출
$tiny = New-LumaMap 8 8 { param($x, $y) 255 }
Assert-Case '경계: 격자가 너무 작으면 미검출' ([bool](Find-LifeCloseGlyph -Luma $tiny).Found) 'False'
Assert-Case '경계: 빈 배열도 예외 없이 미검출' ([bool](Find-LifeCloseGlyph -Luma @()).Found) 'False'

# ── ② 실측 캡처 재현 (고치기 전 재현 → 고친 후 통과) ──
$refWidth = 1272.0; $refHeight = 717.0
function Get-CaptureGlyphHit {
  # 워커의 Get-GameRegionCapture -Scale 1 과 같은 크롭·리샘플을 재현합니다
  param([string]$Path)
  $bmp = [System.Drawing.Bitmap]::FromFile($Path)
  try {
    $cropLeft = [int][Math]::Round($rgLifeCloseGlyph[0] * $bmp.Width / $refWidth)
    $cropTop = [int][Math]::Round($rgLifeCloseGlyph[1] * $bmp.Height / $refHeight)
    $cropWidth = [Math]::Max(1, [int][Math]::Round($rgLifeCloseGlyph[2] * $bmp.Width / $refWidth))
    $cropHeight = [Math]::Max(1, [int][Math]::Round($rgLifeCloseGlyph[3] * $bmp.Height / $refHeight))
    $src = New-Object System.Drawing.Bitmap $cropWidth, $cropHeight
    $g1 = [System.Drawing.Graphics]::FromImage($src)
    $g1.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $cropWidth, $cropHeight),
      (New-Object System.Drawing.Rectangle $cropLeft, $cropTop, $cropWidth, $cropHeight),
      [System.Drawing.GraphicsUnit]::Pixel)
    $g1.Dispose()
    $scaled = New-Object System.Drawing.Bitmap $rgLifeCloseGlyph[2], $rgLifeCloseGlyph[3]
    $g2 = [System.Drawing.Graphics]::FromImage($scaled)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $rgLifeCloseGlyph[2], $rgLifeCloseGlyph[3]),
      (New-Object System.Drawing.Rectangle 0, 0, $cropWidth, $cropHeight), [System.Drawing.GraphicsUnit]::Pixel)
    $g2.Dispose(); $src.Dispose()
    $luma = New-Object 'int[][]' $scaled.Height
    for ($y = 0; $y -lt $scaled.Height; $y++) {
      $row = New-Object 'int[]' $scaled.Width
      for ($x = 0; $x -lt $scaled.Width; $x++) {
        $c = $scaled.GetPixel($x, $y)
        $row[$x] = [int](([int]$c.R + [int]$c.G + [int]$c.B) / 3)
      }
      $luma[$y] = $row
    }
    $scaled.Dispose()
    return (Find-LifeCloseGlyph -Luma $luma)
  } finally { $bmp.Dispose() }
}

# 제보 1908 캡처 (이 사고의 원본. 옛 4점 판정은 3장 모두 false 였다).
# 던전이미지\ 는 .gitignore 대상이라 저장소에 들어가지 않습니다 - 캡처가 없는 PC(클론 등)
# 에서는 **건너뜁니다**(스킵 = 실패 아님. test_life_ocr_offline.ps1 과 같은 규약).
# 위 ① 형태 진리표와 아래 ③ 배선 가드는 자산 없이도 항상 돕니다.
$reportDir = Join-Path $projectRoot '던전이미지\생활\1908캡처'
$reportShots = @(Get-ChildItem $reportDir -Filter 'hyodong_1908_error_*.png' -ErrorAction SilentlyContinue)
if ($reportShots.Count -lt 1) {
  "SKIP 제보 1908 캡처가 없어 재현 검증을 건너뜁니다: $reportDir"
}
foreach ($shot in $reportShots) {
  $hit = Get-CaptureGlyphHit -Path $shot.FullName
  Assert-Case "1908 '$($shot.Name)' 창 열림 감지" ([bool]$hit.Found) 'True'
}
# 1908 에서 찾은 중심이 기준 좌표 상수(1228,67)보다 **위**여야 한다 (제목줄 비비례의 증거).
# 이 관계가 뒤집히면 모델이 틀린 것이므로 수치가 아니라 부등호로 고정한다.
if ($reportShots.Count -gt 0) {
  $reportHit = Get-CaptureGlyphHit -Path $reportShots[0].FullName
  $reportRefY = $rgLifeCloseGlyph[1] + [int]$reportHit.Y
  Assert-Case '1908 글리프 중심은 기준 상수(67)보다 위' ([bool]($reportRefY -lt 67)) 'True'
  Assert-Case '1908 글리프 중심이 옛 4점과 어긋난 폭 5px 이상' ([bool]((67 - $reportRefY) -ge 5)) 'True'
}

# chyui 제보 1273x718 (2026-08-09). 02:32:49 는 **생활 스킬 그리드(파란 배경)** 라
# 절대 임계 방식이 여기서 깨졌습니다 - 상대 대비로 바꾼 뒤의 회귀 자산입니다.
$blueDir = Join-Path $projectRoot '던전이미지\생활\1273캡처'
$blueShots = @(Get-ChildItem $blueDir -Filter 'chyui_1273_error_*.png' -ErrorAction SilentlyContinue)
if ($blueShots.Count -lt 1) { "SKIP chyui 1273 캡처가 없어 재현 검증을 건너뜁니다: $blueDir" }
foreach ($shot in $blueShots) {
  Assert-Case "1273 '$($shot.Name)' 창 열림 감지" ([bool](Get-CaptureGlyphHit -Path $shot.FullName).Found) 'True'
}
# 같은 세션의 필드 프레임은 반드시 미검출이어야 합니다 (오탐 0 확인)
$blueField = @(Get-ChildItem $blueDir -Filter 'chyui_1273_field_*.png' -ErrorAction SilentlyContinue)
foreach ($shot in $blueField) {
  Assert-Case "1273 '$($shot.Name)' 필드는 미검출" ([bool](Get-CaptureGlyphHit -Path $shot.FullName).Found) 'False'
}

# ── ②b ROI 여유 폭 (2026-08-09 감사) ──
# '검출되는가'만 보면 여유가 3px 남았는지 30px 남았는지 알 수 없습니다. 실제로 그 상태였고
# (제목줄 39px = 125% 배율 PC 에서 위 여유 3px), 150% 배율이면 밴드를 벗어나 08-08 고착이
# 재발할 뻔했습니다. ROI 를 위아래로 밀어 **몇 px 까지 견디는지**를 직접 잽니다.
function Test-GlyphWithShift {
  param([string]$Path, [int]$ShiftY)
  $bmp = [System.Drawing.Bitmap]::FromFile($Path)
  try {
    $roiY = $rgLifeCloseGlyph[1] + $ShiftY
    $cl = [int][Math]::Round($rgLifeCloseGlyph[0] * $bmp.Width / $refWidth)
    $ct = [int][Math]::Round($roiY * $bmp.Height / $refHeight)
    $cw = [Math]::Max(1, [int][Math]::Round($rgLifeCloseGlyph[2] * $bmp.Width / $refWidth))
    $ch = [Math]::Max(1, [int][Math]::Round($rgLifeCloseGlyph[3] * $bmp.Height / $refHeight))
    if ($ct -lt 0 -or ($ct + $ch) -gt $bmp.Height) { return $false }
    $src = New-Object System.Drawing.Bitmap $cw, $ch
    $g1 = [System.Drawing.Graphics]::FromImage($src)
    $g1.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $cw, $ch),
      (New-Object System.Drawing.Rectangle $cl, $ct, $cw, $ch), [System.Drawing.GraphicsUnit]::Pixel)
    $g1.Dispose()
    $sc = New-Object System.Drawing.Bitmap $rgLifeCloseGlyph[2], $rgLifeCloseGlyph[3]
    $g2 = [System.Drawing.Graphics]::FromImage($sc)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $rgLifeCloseGlyph[2], $rgLifeCloseGlyph[3]),
      (New-Object System.Drawing.Rectangle 0, 0, $cw, $ch), [System.Drawing.GraphicsUnit]::Pixel)
    $g2.Dispose(); $src.Dispose()
    $lm = New-Object 'int[][]' $sc.Height
    for ($y = 0; $y -lt $sc.Height; $y++) {
      $row = New-Object 'int[]' $sc.Width
      for ($x = 0; $x -lt $sc.Width; $x++) { $c = $sc.GetPixel($x, $y); $row[$x] = [int](([int]$c.R + [int]$c.G + [int]$c.B) / 3) }
      $lm[$y] = $row
    }
    $sc.Dispose()
    return [bool](Find-LifeCloseGlyph -Luma $lm).Found
  } finally { $bmp.Dispose() }
}
$marginAssets = @($reportShots) + @($blueShots)
if ($marginAssets.Count -gt 0) {
  $worstUp = 99
  $worstDown = 99
  foreach ($shot in $marginAssets) {
    $up = 0
    while ($up -lt 40 -and (Test-GlyphWithShift -Path $shot.FullName -ShiftY (-($up + 1)))) { $up++ }
    if ($up -lt $worstUp) { $worstUp = $up }
    $down = 0
    while ($down -lt 40 -and (Test-GlyphWithShift -Path $shot.FullName -ShiftY ($down + 1))) { $down++ }
    if ($down -lt $worstDown) { $worstDown = $down }
  }
  # 위 방향(=고배율 PC 방향)이 취약했던 축입니다. 최소 20px 은 확보돼야 합니다
  # (100% 31px → 125% 39px 이 8px 차이였으므로 150% 까지 덮으려면 그 두 배 이상).
  Assert-Case "ROI 여유: 제보 자산 위 방향 최소 20px 이상 (실제 $worstUp)" ([bool]($worstUp -ge 20)) 'True'
  # 아래 방향도 함께 잽니다. 한쪽만 재면 '상하 sweep' 이라는 계약과 실제가 어긋납니다
  # (반대 방향은 아무도 재 본 적이 없다 - 이번 감사가 지적한 계열 그 자체).
  Assert-Case "ROI 여유: 제보 자산 아래 방향 최소 15px 이상 (실제 $worstDown)" ([bool]($worstDown -ge 15)) 'True'
}

# 개발 1272 캡처 전수 - 회귀 확인 (창 열림은 True, 필드/채집 화면은 False)
$devDir = Join-Path $projectRoot '던전이미지\생활\흐름캡처'
if (Test-Path $devDir) {
  foreach ($devShot in (Get-ChildItem $devDir -File | Sort-Object Name)) {
    $expectOpen = ($devShot.Name -match '내정보|생활스킬창|대상상세')
    $devHit = Get-CaptureGlyphHit -Path $devShot.FullName
    Assert-Case "1272 '$($devShot.Name)'" ([bool]$devHit.Found) "$expectOpen"
  }
  # 1272 에서 찾은 중심은 원래 하드코딩 좌표와 사실상 같아야 한다 (무회귀의 직접 증거)
  $devOpen = @(Get-ChildItem $devDir -File | Where-Object { $_.Name -match '내정보' } | Select-Object -First 1)
  if ($devOpen.Count -gt 0) {
    $devHit = Get-CaptureGlyphHit -Path $devOpen[0].FullName
    $devRefX = $rgLifeCloseGlyph[0] + [int]$devHit.X
    $devRefY = $rgLifeCloseGlyph[1] + [int]$devHit.Y
    Assert-Case '1272 글리프 중심이 기존 좌표(1227~1228, 65~67) 근처' `
      ([bool]([Math]::Abs($devRefX - 1228) -le 3 -and [Math]::Abs($devRefY - 66) -le 3)) 'True'
  }
}

# ── ③ 배선 가드 ──
$workerText = [IO.File]::ReadAllText($workerPath)
# 거리 상한(0,900 / 0,2000)으로 순서를 확인하면 주석 몇 줄만 늘어도 깨집니다 - 7차에서
# 실제로 터졌습니다. 함수 본문만 AST 로 떼어 **순서**로 확인합니다.
$lifeOpenBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-LifeWindowOpen'))
$idxGlyph = $lifeOpenBody.IndexOf('$glyphHit = Get-LifeCloseGlyphHit')
$idxGlyphTrue = $lifeOpenBody.IndexOf('return $true')
$idxPixel = $lifeOpenBody.IndexOf('Test-LifeWindowClosePixels -CrossA')
Assert-Case '워커: 글리프 탐색이 창 판정의 1순위' `
  ([bool]($idxGlyph -ge 0 -and $idxGlyphTrue -gt $idxGlyph)) 'True'
Assert-Case '워커: 기존 4점 판정도 폴백으로 유지 (1272 무회귀)' `
  ([bool]($idxPixel -gt $idxGlyph)) 'True'
Assert-Case '워커: ROI 캡처는 Scale 1 (창 크기 무관 정규화)' `
  ($workerText.Contains('-RegionWidth $rgLifeCloseGlyph[2] -RegionHeight $rgLifeCloseGlyph[3] -Scale 1')) 'True'
Assert-Case '워커: 캡처 실패 감지가 있는 경로 사용 (Get-GamePixel 원시 경로 아님)' `
  ([bool]($workerText -match "function Get-LifeCloseGlyphHit[\s\S]{0,1200}?Get-GameRegionCapture -Game")) 'True'
Assert-Case '워커: 캡처 래퍼는 .Bitmap 으로 해제' `
  ($workerText.Contains('if ($capture.Bitmap) { $capture.Bitmap.Dispose() }')) 'True'
# 판정만 고치고 클릭을 그대로 두면 사고가 '클릭이 빗나감'으로 옮겨갈 뿐이다
Assert-Case '워커: 닫기 클릭이 탐지 좌표를 우선 사용' `
  ([bool]($workerText -match "function Invoke-LifeWindowCloseClick[\s\S]{0,600}?\`$hit\.ReferenceX")) 'True'
Assert-Case '워커: 닫기 클릭 호출부가 전부 공용 함수 경유' `
  ([regex]::Matches($workerText, 'Click-GamePoint -Game \$Game -ReferenceX \$ptLifeWindowClose\[0\]').Count) '1'
Assert-Case '워커: 상수 폴백은 공용 함수 안에만 남음' `
  ([bool]($workerText -match "function Invoke-LifeWindowCloseClick[\s\S]{0,600}?\`$ptLifeWindowClose\[0\]")) 'True'

exit $fails
