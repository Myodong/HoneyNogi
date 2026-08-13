# 던전 옵션 제목 배율 사다리(s3→s4→s5)의 오프라인 OCR 재현 검증 (2026-08-11/12 실사고 2건)
# 본체: mabinogi_run_once.ps1 Read-DgTitleText - 좁은 s3 → 넓은 s3→s4→s5, '구역' 채택 게이트.
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
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Test-CustomTitleStageMatch', 'Read-DgTitleText', 'Get-DgStageEnterButtonText')) {
  Invoke-Expression $definition
}
# 영역 변수는 사본을 박지 않고 소스 대입식을 그대로 실행해 캡처합니다 (배선 원칙)
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$config = $null
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
foreach ($regionName in @('rgDgTitle', 'rgDgEnterBtn')) {
  $regionAssign = $sourceAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $regionName))
    }, $true)
  if (-not $regionAssign) { "FAIL 본체에서 `$$regionName 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $regionAssign.Extent.Text
}

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
  param([int]$RefX, [int]$RefY, [int]$RefW, [int]$RefH, [int]$Scale, [bool]$Binary = $false)
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
    if ($Binary) {
      # 워커 Get-GameRegionCapture 의 -BinaryWhiteText 등가 (임계 175 + NearestNeighbor)
      for ($binY = 0; $binY -lt $cropH; $binY++) {
        for ($binX = 0; $binX -lt $cropW; $binX++) {
          $binColor = $crop.GetPixel($binX, $binY)
          if ($binColor.R -gt 175 -and $binColor.G -gt 175 -and $binColor.B -gt 175) {
            $crop.SetPixel($binX, $binY, [System.Drawing.Color]::Black)
          } else {
            $crop.SetPixel($binX, $binY, [System.Drawing.Color]::White)
          }
        }
      }
    }
    $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
    try {
      $scaledGraphics.InterpolationMode = $(if ($Binary) { [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor }
        else { [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic })
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
$script:binReadCount = 0      # 이진화 판독 호출 계수 (게이트 계약 검증용)
$script:forceTitleBlank = $false   # 일반(비이진화) '제목 영역' 판독만 강제 실패시키는 스위치
function Get-GameRegionOcrText {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale, $Engine, [switch]$BinaryWhiteText)
  if ($BinaryWhiteText) { $script:binReadCount++ }
  # 이진화-단 동적 가드용: 제목 영역(좁/넓 모두 원점이 rgDgTitle)의 비이진화 판독만 비웁니다.
  # 진입 버튼 판독(게이트)은 실제 OCR 유지 - 전부 비우면 '입장하기' 게이트가 닫혀
  # 이진화 단 자체가 실행되지 않습니다 (교차 리뷰 지적).
  if ($script:forceTitleBlank -and -not $BinaryWhiteText -and
      $ReferenceX -eq $rgDgTitle[0] -and $ReferenceY -eq $rgDgTitle[1]) {
    return ''
  }
  return (Get-CaptureRegionText -RefX $ReferenceX -RefY $ReferenceY -RefW $RegionWidth -RefH $RegionHeight -Scale $Scale -Binary ([bool]$BinaryWhiteText))
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

# ── 2026-08-12 23:55 실사고 캡처 (심층 페카고분 - '다시 하기' 복귀 대기 40초 초과 → 오류 →
#    재시작 회차 선택 화면 오판 정지): 옵션 화면이 열려 있는데 제목이 '패가고분=石'.
#    재현: 좁 s3 '패가고분=石' / 넓 s3·s4 '구역' 소실 / **넓 s5 '제고분심증2증1구역' 복구**.
#    어제 룬다 캡처는 s4 성공·s5 실패로 반대 - 사다리 순회(3→4→5)가 두 캡처를 모두 살린다.
$deepCapturePath = Join-Path $projectRoot '던전이미지\실측기록\20260812_페카고분심층_다시하기복귀실패_1908창.png'
if (-not (Test-Path -LiteralPath $deepCapturePath)) {
  "SKIP 심층 실측 캡처가 없어 두 번째 재현을 건너뜁니다: $deepCapturePath"
} else {
  $sourceBitmap = [System.Drawing.Bitmap]::FromFile($deepCapturePath)
  try {
    $deepNarrow3 = Get-CaptureRegionText -RefX $rgDgTitle[0] -RefY $rgDgTitle[1] -RefW $rgDgTitle[2] -RefH $rgDgTitle[3] -Scale 3
    $deepWide4 = Get-CaptureRegionText -RefX $rgDgTitle[0] -RefY $rgDgTitle[1] -RefW 420 -RefH $rgDgTitle[3] -Scale 4
    $deepWide5 = Get-CaptureRegionText -RefX $rgDgTitle[0] -RefY $rgDgTitle[1] -RefW 420 -RefH $rgDgTitle[3] -Scale 5
    "정보(심층): 좁 s3='$deepNarrow3' / 넓 s4='$deepWide4' / 넓 s5='$deepWide5' (실측 당시 '패가고분=石'/'패가고분=石石丁曰'/'제고분심증2증1구역')"
    $script:binReadCount = 0
    $deepLadderText = Read-DgTitleText -Game $null
    Assert-Case '심층 캡처: 사다리 결과에 구역 생존(수정 전에는 40초 전멸)' ($deepLadderText.Contains('구역')) $true
    Assert-Case '심층 캡처: 목표 2-1 과 매치(복귀 확인 통과)' `
      (Test-CustomTitleStageMatch -TitleText $deepLadderText -Stage '2-1') 'match'
    Assert-Case '심층 캡처: 일반 사다리가 채택하면 이진화 비용 0회 (게이트/순서 계약)' $script:binReadCount 0
  } finally {
    $sourceBitmap.Dispose()
  }
}

# ── 2026-08-13 02시 실사고 캡처 (당시: 제목이 일반 판독 전 배율 사망 - 이진화 단이 유일한
#    생환 경로였음). v9 제목 영역 상단 확장(45→34) 후에는 **일반 단이 곧장 살린다**
#    ('페카고분심층2층2구역' - 상단 45가 구역 숫자 윗부분을 잘라 온 것이 전 배율 사망의
#    기여 원인이었다는 방증). 그래서 이 캡처로 두 계약을 나눠 고정한다:
#    ③-1 새 영역에서 일반 사다리가 살림 + 조기 종료라 이진화 비용 0회
#    ③-2 일반 판독 전멸 상황(제목 영역 비이진화 판독 강제 '')에서 이진화 단이 홀로 생환 -
#        '입장하기' 게이트와 이진화 배선의 동적 가드 (단을 빼면 이 단언이 실패)
$binCapturePath = Join-Path $projectRoot '던전이미지\실측기록\20260813_제목전배율사망_1908창_심층옵션.png'
if (-not (Test-Path -LiteralPath $binCapturePath)) {
  "SKIP 전배율 사망 캡처가 없어 이진화 단 재현을 건너뜁니다: $binCapturePath"
} else {
  $sourceBitmap = [System.Drawing.Bitmap]::FromFile($binCapturePath)
  try {
    $script:binReadCount = 0
    $binLadderText = Read-DgTitleText -Game $null
    "정보(이진화 ③-1): 사다리 결과='$binLadderText' (구영역 실측 당시 binS5 '페,江분심증2증2구역')"
    Assert-Case '전배율 사망 캡처: v9 영역에서 일반 사다리가 구역을 생환시킴' ($binLadderText.Contains('구역')) $true
    Assert-Case '전배율 사망 캡처: 화면 스테이지 2-2 매치' `
      (Test-CustomTitleStageMatch -TitleText $binLadderText -Stage '2-2') 'match'
    Assert-Case '전배율 사망 캡처: 일반 단 채택 시 이진화 비용 0회 (조기 종료 계약)' $script:binReadCount 0
    # ③-2 강제 전멸 → 이진화 단독 생환
    $script:forceTitleBlank = $true
    try {
      $script:binReadCount = 0
      $forcedLadderText = Read-DgTitleText -Game $null
      "정보(이진화 ③-2): 강제 전멸 사다리 결과='$forcedLadderText' (binReads=$script:binReadCount)"
      Assert-Case '강제 전멸: 이진화 단이 구역을 생환시킴 (단 제거 시 실패)' ($forcedLadderText.Contains('구역')) $true
      Assert-Case '강제 전멸: 화면 스테이지 2-2 매치' `
        (Test-CustomTitleStageMatch -TitleText $forcedLadderText -Stage '2-2') 'match'
      Assert-Case '강제 전멸: 이진화 판독이 실제로 발생 (게이트 통과 배선)' ($script:binReadCount -ge 1) $true
    } finally {
      $script:forceTitleBlank = $false
    }
  } finally {
    $sourceBitmap.Dispose()
  }
}

# ── 2026-08-13 11:00 실사고 캡처 (네이티브 1908 창의 선택 화면 난이도 알약 이탈):
#    모니터 배율 100% PC에서 창을 물리 1908x1076으로 리사이즈하면(제목줄 31px) 선택 화면
#    상단 UI가 순비율 위치보다 위에 놓여 알약 행이 y163에 옴 - 구영역(30,165,200,50)은
#    전 배율(4/3/5/2) 단어 0개로 3연속 정지. v8에서 위로 20 확장(30,145,200,70).
#    실제 Find-DgDifficultyPoint 사다리를 캡처 위에서 실행해 "구영역 REJECT / 신영역 PICK"
#    양쪽을 고정합니다 (신영역은 소스 대입식 캡처 - 영역을 되돌리면 이 단언이 실패).
$pillCapturePath = Join-Path $projectRoot '던전이미지\실측기록\20260813_난이도알약이탈_네이티브1908_선택화면.png'
if (-not (Test-Path -LiteralPath $pillCapturePath)) {
  "SKIP 난이도 알약 이탈 캡처가 없어 네 번째 재현을 건너뜁니다: $pillCapturePath"
} else {
  foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
      -Names @('Select-DgDifficultyWord', 'Find-DgDifficultyPoint')) {
    Invoke-Expression $definition
  }
  $regionAssign = $sourceAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq '$rgDgDifficulty')
    }, $true)
  if (-not $regionAssign) { 'FAIL 본체에서 $rgDgDifficulty 정의를 찾지 못했습니다'; $fails++ }
  else {
    Invoke-Expression $regionAssign.Extent.Text
    # Find-DgDifficultyPoint 의 게임 의존 3함수를 캡처 재생/항등으로 대체
    function Get-GameRegionOcrWords {
      param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale, $Engine)
      $imageW = $script:sourceBitmap.Width; $imageH = $script:sourceBitmap.Height
      $cropLeft = [int][Math]::Round($ReferenceX * $imageW / $script:referenceWidth)
      $cropTop = [int][Math]::Round($ReferenceY * $imageH / $script:referenceHeight)
      $cropW = [Math]::Max(1, [int][Math]::Round($RegionWidth * $imageW / $script:referenceWidth))
      $cropH = [Math]::Max(1, [int][Math]::Round($RegionHeight * $imageH / $script:referenceHeight))
      $crop = New-Object System.Drawing.Bitmap $cropW, $cropH
      $scaled = New-Object System.Drawing.Bitmap ($RegionWidth * $Scale), ($RegionHeight * $Scale)
      try {
        $cropGraphics = [System.Drawing.Graphics]::FromImage($crop)
        try {
          $cropGraphics.DrawImage($script:sourceBitmap, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)),
            (New-Object System.Drawing.Rectangle($cropLeft, $cropTop, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
        } finally { $cropGraphics.Dispose() }
        $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
        try {
          $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
          $scaledGraphics.DrawImage($crop, (New-Object System.Drawing.Rectangle(0, 0, ($RegionWidth * $Scale), ($RegionHeight * $Scale))),
            (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
        } finally { $scaledGraphics.Dispose() }
        $ocrResult = Invoke-OcrOnBitmap -Bitmap $scaled -Engine $ocrKoreanEngine
        $regionWords = @()
        foreach ($ocrLine in $ocrResult.Lines) {
          foreach ($ocrWord in $ocrLine.Words) {
            $regionWords += , @{
              Text = ($ocrWord.Text -replace '\s', '')
              X = $ReferenceX + [int][Math]::Round(($ocrWord.BoundingRect.X + $ocrWord.BoundingRect.Width / 2) / $Scale)
              Y = $ReferenceY + [int][Math]::Round(($ocrWord.BoundingRect.Y + $ocrWord.BoundingRect.Height / 2) / $Scale)
            }
          }
        }
        return $regionWords
      } finally { $crop.Dispose(); $scaled.Dispose() }
    }
    function Wait-GameRestoredIfMinimized { param($Game) }
    function Get-ScaledScreenPoint { param($Game, [int]$ReferenceX, [int]$ReferenceY) return @{ X = $ReferenceX; Y = $ReferenceY } }
    $sourceBitmap = [System.Drawing.Bitmap]::FromFile($pillCapturePath)
    try {
      $oldRegionPick = Find-DgDifficultyPoint -Game $null -Region @(30, 165, 200, 50) -Label '어려움' -HardX 140
      Assert-Case '알약 이탈 캡처: 구영역(165~215)은 전 배율 판독 실패 (사고 재현)' ($null -eq $oldRegionPick) $true
      $newRegionPick = Find-DgDifficultyPoint -Game $null -Region $rgDgDifficulty -Label '어려움' -HardX 140
      Assert-Case '알약 이탈 캡처: 소스 영역(v8 확장)이 어려움을 채택' ($null -ne $newRegionPick) $true
      if ($newRegionPick) {
        # 실측 채택 좌표 (127,163) - OCR 흔들림 허용 폭은 알약 크기(폭 ~55, 높이 ~40) 이내
        Assert-Case '알약 이탈 캡처: 채택 x가 알약 위 (127±10)' ([Math]::Abs([int]$newRegionPick.X - 127) -le 10) $true
        Assert-Case '알약 이탈 캡처: 채택 y가 알약 위 (163±8)' ([Math]::Abs([int]$newRegionPick.Y - 163) -le 8) $true
      }
    } finally {
      $sourceBitmap.Dispose()
    }
  }
}

# ── 2026-08-13 11:53 실사고 캡처 (네이티브 1908 옵션 화면 - 구역 2-2 전환이 실제 성공했는데
#    구영역(상단 45)이 크게 그려지는 구역 숫자 윗부분(글자 상단 ref 42)을 잘라 확인 8회 전멸
#    → fail-closed 정지). v9 영역(상단 34)의 존재 이유 - 영역을 되돌리면 아래 단언이 실패.
$tailCapturePath = Join-Path $projectRoot '던전이미지\실측기록\20260813_제목꼬리소실_네이티브1908_옵션2층2구역.png'
if (-not (Test-Path -LiteralPath $tailCapturePath)) {
  "SKIP 제목 꼬리 소실 캡처가 없어 다섯 번째 재현을 건너뜁니다: $tailCapturePath"
} else {
  foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-DgDungeonIdFromTitle')) {
    Invoke-Expression $definition
  }
  $patternsAssign = $sourceAst.FindAll({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq '$dgNamePatterns')
    }, $true) | Select-Object -First 1
  if (-not $patternsAssign) { 'FAIL 본체에서 $dgNamePatterns 정의를 찾지 못했습니다'; $fails++ }
  else {
    Invoke-Expression $patternsAssign.Extent.Text
    $sourceBitmap = [System.Drawing.Bitmap]::FromFile($tailCapturePath)
    try {
      $tailLadderText = Read-DgTitleText -Game $null
      "정보(꼬리 소실): 사다리 결과='$tailLadderText' (구영역 실측 당시 전 단 '메카고분' - 구역 없음)"
      Assert-Case '꼬리 소실 캡처: v9 영역에서 구역 꼬리 생환 (구영역은 8회 전멸)' ($tailLadderText.Contains('구역')) $true
      Assert-Case '꼬리 소실 캡처: 화면 스테이지 2-2 매치 (전환 확인 통과)' `
        (Test-CustomTitleStageMatch -TitleText $tailLadderText -Stage '2-2') 'match'
      Assert-Case '꼬리 소실 캡처: 던전 ID 페카고분 확정 (실측 이형 등록 포함)' `
        ([string](Get-DgDungeonIdFromTitle -TitleText $tailLadderText)) '페카고분'
    } finally {
      $sourceBitmap.Dispose()
    }
  }
}

# ── 2026-08-13 13:03 실사고 (네이티브 1908 카드 버튼 이탈): 소탕 해제가 필요한데 카드 버튼이
#    구영역(상단 292/493) 밖(실측 소탕 (427,280)/루팅 (415,466))이라 6회전 '(판독 없음)' 정지.
#    v10 = 4영역 상단 확장 + 클릭 자기앵커. 같은 11:53 캡처(두 카드 '선택됨')로
#    "신영역 × Set-DgToggleCard 배율 사다리(5,3,4) → 선택됨 단어 + 실측 위치" 를 고정합니다.
#    단어 y가 구 고정 클릭점(313/517)과 20px 이상 떨어져 있음까지 단언 - 고정점 클릭이
#    버튼을 빗나가는 기하라는 사고 근거의 회귀 가드 (영역/사다리를 되돌리면 실패).
if (-not (Test-Path -LiteralPath $tailCapturePath)) {
  "SKIP 제목 꼬리 소실 캡처가 없어 카드 버튼 재현을 건너뜁니다: $tailCapturePath"
} elseif (-not (Get-Command Get-GameRegionOcrWords -ErrorAction SilentlyContinue)) {
  # 단어 판독 스텁은 네 번째 케이스(알약 이탈) 블록에서 정의됩니다 - 그 캡처가 없어 스킵된
  # 부분 클론 환경에서는 이 케이스도 함께 건너뜁니다 (스킵 = 실패 아님)
  'SKIP 단어 판독 스텁이 없어(네 번째 케이스 스킵) 카드 버튼 재현을 건너뜁니다'
} else {
  foreach ($regionName in @('rgDgCoinButton', 'rgDgCoinButtonAlt', 'rgDgLootButton', 'rgDgLootButtonAlt')) {
    $regionAssign = $sourceAst.FindAll({
        param($node)
        ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
        ($node.Left.Extent.Text -eq ('$' + $regionName))
      }, $true) | Select-Object -First 1
    if (-not $regionAssign) { "FAIL 본체에서 `$$regionName 정의를 찾지 못했습니다"; $fails++ }
    else { Invoke-Expression $regionAssign.Extent.Text }
  }
  function Get-CardWordFromCapture {
    # Set-DgToggleCard 1회전 등가: 배율 5,3,4 × (주 → 보조) 순회, 선택됨 계열 단어 첫 매치
    param([int[][]]$Regions)
    foreach ($cardScale in 5, 3, 4) {
      foreach ($cardRegion in $Regions) {
        $cardWords = @(Get-GameRegionOcrWords -Game $null -ReferenceX $cardRegion[0] -ReferenceY $cardRegion[1] `
          -RegionWidth $cardRegion[2] -RegionHeight $cardRegion[3] -Scale $cardScale -Engine $ocrKoreanEngine)
        foreach ($cardWord in $cardWords) {
          $wordText = [string]$cardWord.Text
          if ($wordText.Contains('됨') -or $wordText.Contains('선택') -or $wordText.Contains('선태')) {
            return $cardWord
          }
        }
      }
    }
    return $null
  }
  $sourceBitmap = [System.Drawing.Bitmap]::FromFile($tailCapturePath)
  try {
    $coinWord = Get-CardWordFromCapture -Regions @($rgDgCoinButton, $rgDgCoinButtonAlt)
    Assert-Case '카드 버튼 캡처: 소탕 선택됨 단어 검출 (구영역은 판독 없음)' ($null -ne $coinWord) $true
    if ($coinWord) {
      Assert-Case '카드 버튼 캡처: 소탕 단어 위치 (427,280)±12' `
        (([Math]::Abs([int]$coinWord.X - 427) -le 12) -and ([Math]::Abs([int]$coinWord.Y - 280) -le 12)) $true
      Assert-Case '카드 버튼 캡처: 소탕 단어가 구 고정 클릭점(y313)과 다른 행' `
        ([Math]::Abs([int]$coinWord.Y - 313) -gt 20) $true
    }
    $lootWord = Get-CardWordFromCapture -Regions @($rgDgLootButton, $rgDgLootButtonAlt)
    Assert-Case '카드 버튼 캡처: 루팅 선택됨 단어 검출 (구영역은 판독 없음)' ($null -ne $lootWord) $true
    if ($lootWord) {
      Assert-Case '카드 버튼 캡처: 루팅 단어 위치 (415,466)±12' `
        (([Math]::Abs([int]$lootWord.X - 415) -le 12) -and ([Math]::Abs([int]$lootWord.Y - 466) -le 12)) $true
      Assert-Case '카드 버튼 캡처: 루팅 단어가 구 고정 클릭점(y517)과 다른 행' `
        ([Math]::Abs([int]$lootWord.Y - 517) -gt 20) $true
    }
  } finally {
    $sourceBitmap.Dispose()
  }
}

exit $fails
