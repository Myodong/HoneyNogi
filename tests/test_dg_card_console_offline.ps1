# 소탕 카드 버튼 '태되' 조각 - 콘솔 렌더 프레임 오프라인 재현 (2026-09-16, v2.1.10)
# 본체: mabinogi_run_once.ps1 Set-DgToggleCard 판정식의 조각 '태되' (기존 '됨'/'선택'/'선태' 뒤 elseif).
# 사고: RDP 세션이 끊겨 콘솔 상태가 되면(창 1024x577) '선택됨'이 결정적으로 깨져 배율 5·3·4 × 주·보조 6판독 전부
#       판정 불가('RdEHEl'/'人에E}1되'/',k•i태되'/'人1태되') → 소모량 근거 블라인드 해제 폴백(회차당 약 8초)에만 의존.
#       09-07 2장 + 09-14 진단 10장 = 12장이 한 글자도 다르지 않은 결정적 깨짐. 조각 '태되'('택됨'의 아랫획 소실)는
#       12장 전부 배율 3 주(1회전 3번째 판독)에서 나옴. 오탐 스윕: 보관 캡처 118장 × 카드 2 × 배율 4 × 영역 2 판독에서
#       '태되' 출현 21건 전부 진짜 선택됨(현행 판정 selected 9 + 콘솔 12), '도전' 9건에서 출현 0.
#       배율 2 추가안은 12장 중 8장만 살려(배경 밝기 미세 차에 흔들림) 철회 - 성공군·실패군 프레임을 함께 둔다.
# 이 테스트는 보관 프레임을 워커와 같은 경로(비율 크롭 → 기준크기×배율 HighQualityBicubic → ko OCR 단어)로 재생해
#  ① 구판 판정식(기준선 사본 - 고정)으로는 6판독 전부 불가 = 사고 재현
#  ② **추출한 실함수** Set-DgToggleCard 가 3번째 판독(배율 3 주)에서 확정 → 자기앵커 해제 클릭 1회 → 재확인까지 끝나는 흐름
#     ('도전' 대역 / 빈 판독 대역), 진단 로그가 확정 회전 1회만
#  ③ RDP 1908 프레임은 배율 5 첫 판독에서 기존 조각으로 확정 - 진단 로그 없음, 채택 단어·좌표가 구판과 동일
# 을 고정합니다. 소스에서 '태되'를 빼면 ②가 실패합니다 (①은 기준선이라 불변).
# 캡처 폴더가 없는 PC(부분 클론 등)에서는 건너뜁니다 (스킵 = 실패 아님).
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$consoleDir = Join-Path $projectRoot '던전이미지/실측기록/20260916_콘솔카드_선택됨깨짐_프레임12장'
$consoleFrames = @(
  (Join-Path $consoleDir 'carddiag_20260914_h17m46s56_set-fail.png'),   # 배율 2 안이 살렸던 프레임
  (Join-Path $consoleDir 'carddiag_20260914_h22m17s14_set-fail.png'),   # 배율 2 안이 살렸던 프레임
  (Join-Path $consoleDir 'carddiag_20260914_h22m19s44_set-fail.png'),   # 배율 2 안이 못 살린 프레임
  (Join-Path $consoleDir 'carddiag_20260914_h22m25s37_set-fail.png'),   # 배율 2 안이 못 살린 프레임
  (Join-Path $projectRoot '던전이미지/던전/20260907_콘솔렌더깨짐_소탕선택됨_1024_setfail.png'),
  (Join-Path $projectRoot '던전이미지/던전/20260907_콘솔렌더깨짐_소탕선택됨_1024_fallbackbefore.png')
)
$rdpFrame = Join-Path $projectRoot '던전이미지/던전/20260907_심층옵션_소탕선택됨_1908.png'
foreach ($framePath in ($consoleFrames + $rdpFrame)) {
  if (-not (Test-Path -LiteralPath $framePath)) {
    "SKIP 실측 캡처가 없어 오프라인 OCR 재현을 건너뜁니다: $framePath"
    exit 0
  }
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
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Set-DgToggleCard')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# 영역은 사본을 박지 않고 소스 대입식을 그대로 실행해 캡처합니다 (배선 원칙)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
foreach ($regionName in @('rgDgCoinButton', 'rgDgCoinButtonAlt')) {
  $regionAssign = $sourceAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $regionName))
    }, $true)
  if (-not $regionAssign) { "FAIL 본체에서 `$$regionName 정의를 찾지 못했습니다"; $fails++; exit 1 }
  Invoke-Expression $regionAssign.Extent.Text
}
$ptDgCoinButton = @(463, 313)   # 고정 클릭점 (자기앵커 클릭이 이 값을 쓰지 않음을 단언하는 용도)
$script:referenceWidth = 1272
$script:referenceHeight = 717

# ---- 구판 판정식 기준선 (2026-09-16 이전 - 고정 사본, 소스와 동기화하지 않음: 사고 재현의 기준선) ----
function Get-LegacyVerdict {
  param($Words)
  foreach ($word in $Words) {
    $wordText = [string]$word.Text
    if ($wordText.Contains('됨') -or $wordText.Contains('선택') -or $wordText.Contains('선태')) { return 'selected' }
    if ($wordText -eq '도전') { return 'challenge' }
  }
  return 'unknown'
}

# ---- 게임 의존 함수 대체: 캡처 재생 + 기록 스텁 ----
# 워커 Get-GameRegionCapture/Get-GameRegionOcrWords 와 같은 수식 (PixelOffsetMode 기본 - 다르면 판독 문자열이 바뀝니다:
# 09-16 재현 중 Half 로 두었을 때 배율 4 보조가 '人에태됨' 으로 살아나는 등 결과가 달라졌음)
$script:readLog = @()
$script:stubMode = 'frame'    # frame = 프레임 판독 / challenge-s5 = 배율 5 주 영역에서 '도전' / blank = 전 배율 빈 판독
function Get-GameRegionOcrWords {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale, $Engine)
  $regionKind = $(if ($ReferenceX -eq $rgDgCoinButton[0] -and $ReferenceY -eq $rgDgCoinButton[1]) { '주' } else { '보조' })
  $script:readLog += , @{ Scale = $Scale; Region = $regionKind }
  if ($script:stubMode -eq 'blank') { return @() }
  if ($script:stubMode -eq 'challenge-s5') {
    # 콘솔 '도전' 상태 프레임은 없어(폴백 뒤 소모량으로만 확인) RDP 판독 모양의 대역 - 배율 5 주 영역에서만 '도전'.
    # 제어 흐름 검증용이며 콘솔 '도전' 오탐(음성) 검증을 대신하지 않습니다 (설계 리뷰 조건 - 실전 [진단] 로그로 관측).
    if ($Scale -eq 5 -and $regionKind -eq '주') { return @(, @{ Text = '도전'; X = 440; Y = 313 }) }
    return @()
  }
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
$script:clicks = @()
$script:logs = @()
function Move-CursorOutsideGame { param($Game) }
function Get-GamePixel { param($Game, [int]$ReferenceX, [int]$ReferenceY) throw '픽셀 판독 없음(캡처 재생)' }
function Test-UserRecentlyActive { return $false }
function Focus-Game { param($Game) }
function Wait-UserYieldEnd { param($Game, [string]$Context) }
function Test-SafeStopDuringCaptureFail { }
function Get-GameRegionOcrText { return '' }
function Save-DgCardDiagnostics { param($Game, [string]$Tag, [int[]]$Region, [int[]]$AltRegion, [string]$Label) $script:logs += "DIAG:$Tag" }
function Start-Sleep { param([int]$Milliseconds = 0, [int]$Seconds = 0) }
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Click-GamePoint {
  param($Game, [int]$ReferenceX, [int]$ReferenceY)
  $script:clicks += , @{ X = $ReferenceX; Y = $ReferenceY; ReadsBefore = $script:readLog.Count }
  $script:lastClickPerformed = $true
  $script:lastClickSkipReason = ''
  # 클릭 = 카드 해제. 이후 판독은 지정한 대역으로 전환
  $script:stubMode = $script:afterClickMode
}
function Reset-Sim {
  $script:readLog = @(); $script:clicks = @(); $script:logs = @()
  $script:stubMode = 'frame'; $script:lastClickPerformed = $false; $script:lastClickSkipReason = ''
  $script:screenCaptureFailing = $false
  $script:contentTag = '[심층]'
  $script:dgCardDiagFailCount = 0
}
function Format-ReadLog { param($Log) return (@($Log | ForEach-Object { "s$($_.Scale)$($_.Region)" }) -join ',') }
function Count-Diag { return @($script:logs | Where-Object { $_ -like "*'태되' 조각으로 판독*" }).Count }
# 버튼 '선택됨' 기하 (1024 프레임 실측: 버튼 x≈30~430/4·y≈95~245/4 → 기준 x 397~521, y 293~340) - 자기앵커 클릭이 버튼 안인지
function Test-InsideCoinButton { param([int]$X, [int]$Y) return (($X -ge 397) -and ($X -le 521) -and ($Y -ge 293) -and ($Y -le 340)) }

# ---- 1. 콘솔 프레임 6장: 구판 기준선으로 6판독 전부 불가(사고 재현) + 실함수가 3번째 판독에서 확정·해제 ----
foreach ($framePath in $consoleFrames) {
  $frameName = Split-Path -Leaf $framePath
  $script:sourceBitmap = [System.Drawing.Bitmap]::FromFile($framePath)
  try {
    Reset-Sim
    $legacyVerdicts = @(); $legacyTexts = @()
    foreach ($cardScale in 5, 3, 4) {
      foreach ($cardRegion in @($rgDgCoinButton, $rgDgCoinButtonAlt)) {
        $cardWords = @(Get-GameRegionOcrWords -Game $null -ReferenceX $cardRegion[0] -ReferenceY $cardRegion[1] `
          -RegionWidth $cardRegion[2] -RegionHeight $cardRegion[3] -Scale $cardScale -Engine $ocrKoreanEngine)
        $legacyVerdicts += (Get-LegacyVerdict -Words $cardWords)
        $legacyTexts += ((@($cardWords | ForEach-Object { [string]$_.Text }) -join '|'))
      }
    }
    "정보($frameName): 배율 5·3·4 판독 = $($legacyTexts -join ' / ')"
    Assert-Case "콘솔 [$frameName]: 구판 조각(됨/선택/선태)으로는 6판독 전부 판정 불가 (사고 재현 기준선)" `
      (($legacyVerdicts | Where-Object { $_ -ne 'unknown' }).Count) 0
    # 배율 3 주 영역의 '태되' 단어 중심 = 실함수가 자기앵커로 눌러야 하는 정확한 좌표 (구현 리뷰 P2: 버튼 안 검사만으로는
    # 상수 클릭 변이를 못 잡음)
    $s3Words = @(Get-GameRegionOcrWords -Game $null -ReferenceX $rgDgCoinButton[0] -ReferenceY $rgDgCoinButton[1] `
      -RegionWidth $rgDgCoinButton[2] -RegionHeight $rgDgCoinButton[3] -Scale 3 -Engine $ocrKoreanEngine)
    $expectedAnchor = @($s3Words | Where-Object { ([string]$_.Text).Contains('태되') } | Select-Object -First 1)
    Assert-Case "콘솔 [$frameName]: 배율 3 주 영역에 '태되' 단어 존재 (확정 근거 단어)" ($expectedAnchor.Count) 1

    # 실함수: 해제(WantSelected=false) - 재확인은 '도전' 대역
    Reset-Sim
    $script:afterClickMode = 'challenge-s5'
    $toggleResult = Set-DgToggleCard -Game $null -Region $rgDgCoinButton -AltRegion $rgDgCoinButtonAlt -ClickPoint $ptDgCoinButton `
      -WantSelected $false -Label '마족공물(소탕)' -AnchorClickToText
    Assert-Case "콘솔 [$frameName]: 실함수 - 반환 true, 해제 클릭 1회" (($toggleResult -eq $true) -and ($script:clicks.Count -eq 1)) $true
    if ($script:clicks.Count -ge 1) {
      # 클릭 '시점'의 판독 수가 정확히 3 (s5주,s5보조,s3주) - 앞 3개만 잘라 비교하면 s3 보조 확정 변이를 못 잡음 (구현 리뷰 P2)
      $preClickReads = @(); for ($i = 0; $i -lt [Math]::Min([int]$script:clicks[0].ReadsBefore, $script:readLog.Count); $i++) { $preClickReads += , $script:readLog[$i] }
      Assert-Case "콘솔 [$frameName]: 실함수 - 클릭까지 정확히 3판독(s5주,s5보조,s3주)에서 확정" `
        ("$([int]$script:clicks[0].ReadsBefore)/$(Format-ReadLog -Log $preClickReads)") '3/s5주,s5보조,s3주'
      Assert-Case "콘솔 [$frameName]: 실함수 - 클릭 좌표 = 배율 3 주 '태되' 단어 중심과 정확 일치 (자기앵커) + 버튼 안" `
        (($expectedAnchor.Count -eq 1) -and ([int]$script:clicks[0].X -eq [int]$expectedAnchor[0].X) -and ([int]$script:clicks[0].Y -eq [int]$expectedAnchor[0].Y) -and
         (Test-InsideCoinButton -X $script:clicks[0].X -Y $script:clicks[0].Y)) $true
    }
    Assert-Case "콘솔 [$frameName]: 실함수 - '태되' 진단 로그는 확정 회전 1회만 (재확인 회전에서 반복 없음)" (Count-Diag) 1
    Assert-Case "콘솔 [$frameName]: 실함수 - 진단 로그에 실제 매치 단어(태되 포함) 기록" `
      (@($script:logs | Where-Object { $_ -match "조각으로 판독: '[^']*태되[^']*'" }).Count) 1
    Assert-Case "콘솔 [$frameName]: 실함수 - 재확인 도전 확인 + Rechecked/Clicked 참, set-fail 진단 없음" `
      ((@($script:logs | Where-Object { $_ -like '*미사용(도전) 확인*' }).Count -eq 1) -and $script:dgToggleRechecked -and $script:dgToggleClicked -and
       (@($script:logs | Where-Object { $_ -like 'DIAG:*' }).Count -eq 0)) $true
    Assert-Case "콘솔 [$frameName]: 실함수 - 폴백 후보 좌표 비움(판정 성공 경로)" ($null -eq $script:dgToggleUnknownWordPoint) $true
  } finally { $script:sourceBitmap.Dispose() }
}

# ---- 2. 실함수: 해제 뒤 재확인이 전 배율 빈 판독인 경우(콘솔 '도전'이 전혀 안 읽힌다는 가설) - 재클릭 없이 '재확인 생략' ----
$script:sourceBitmap = [System.Drawing.Bitmap]::FromFile($consoleFrames[2])
try {
  Reset-Sim
  $script:afterClickMode = 'blank'
  $toggleResult = Set-DgToggleCard -Game $null -Region $rgDgCoinButton -AltRegion $rgDgCoinButtonAlt -ClickPoint $ptDgCoinButton `
    -WantSelected $false -Label '마족공물(소탕)' -AnchorClickToText
  Assert-Case '빈 판독 대역: 반환 true (재확인 생략 경로), 클릭 1회만 (빈 판독으로 재클릭하지 않음)' (($toggleResult -eq $true) -and ($script:clicks.Count -eq 1)) $true
  Assert-Case '빈 판독 대역: 재확인 생략 로그 1줄 + dgToggleRechecked 거짓 (호출부 교차 검증이 이어받음)' `
    ((@($script:logs | Where-Object { $_ -like '*미사용으로 설정 (재확인 생략)*' }).Count -eq 1) -and -not $script:dgToggleRechecked) $true
  Assert-Case '빈 판독 대역: 진단 로그는 확정 회전 1회만' (Count-Diag) 1
} finally { $script:sourceBitmap.Dispose() }

# ---- 3. RDP 1908 프레임: 배율 5 첫 판독에서 기존 조각으로 확정 - 진단 없음, 채택 단어·좌표가 구판과 동일 ----
$script:sourceBitmap = [System.Drawing.Bitmap]::FromFile($rdpFrame)
try {
  Reset-Sim
  $firstWords = @(Get-GameRegionOcrWords -Game $null -ReferenceX $rgDgCoinButton[0] -ReferenceY $rgDgCoinButton[1] `
    -RegionWidth $rgDgCoinButton[2] -RegionHeight $rgDgCoinButton[3] -Scale 5 -Engine $ocrKoreanEngine)
  $legacyFirst = @($firstWords | Where-Object { ([string]$_.Text).Contains('됨') -or ([string]$_.Text).Contains('선택') -or ([string]$_.Text).Contains('선태') } | Select-Object -First 1)
  Reset-Sim
  $script:afterClickMode = 'frame'
  $toggleResult = Set-DgToggleCard -Game $null -Region $rgDgCoinButton -AltRegion $rgDgCoinButtonAlt -ClickPoint $ptDgCoinButton `
    -WantSelected $true -Label '마족공물(소탕)' -AnchorClickToText
  Assert-Case 'RDP 1908: 사용(선택됨) 확인 - 반환 true, 클릭 0, 판독 1회(s5 주)' `
    (($toggleResult -eq $true) -and ($script:clicks.Count -eq 0) -and ((Format-ReadLog -Log $script:readLog) -eq 's5주')) $true
  Assert-Case 'RDP 1908: 진단 로그 없음 (기존 조각으로 확정)' (Count-Diag) 0
  Assert-Case 'RDP 1908: 채택 단어 좌표가 구판 첫 매치와 동일 (조각 추가로 조기 종료 단어가 바뀌지 않음)' `
    (($legacyFirst.Count -eq 1) -and ($null -ne $script:dgToggleWordPoint) -and
     ([int]$script:dgToggleWordPoint.X -eq [int]$legacyFirst[0].X) -and ([int]$script:dgToggleWordPoint.Y -eq [int]$legacyFirst[0].Y)) $true
} finally { $script:sourceBitmap.Dispose() }

if ($fails -gt 0) { Write-Output "FAIL 합계: $fails"; exit 1 }
Write-Output '전체 통과'
exit 0
