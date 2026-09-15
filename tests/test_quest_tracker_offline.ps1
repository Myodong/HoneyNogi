# 퀘스트 추적기 영역 오프라인 진리표 (v2.1.9 - 2026-09-15 신설)
# 타 PC 제보(1272x717 창, HUD 배치가 달라 추적기 제목 줄이 y≈190): 어비스 파티 입장을 감지하지 못해 300초 한도 초과 →
# '파티 매칭 완료 후 던전 입장 대기 시간 초과' 오류. 원인은 영역 상단(190)에서 제목 줄 '광기의 동굴 클리어'가 잘려
# 던전 키워드가 사라진 것. 여기서 고정하는 것:
#   ① 고치기 전 재현: 제보 캡처를 v14 영역(980,190,285,77)으로 읽으면 Test-InDungeonQuest 가 거짓
#   ② 고친 후 통과: 소스의 현행 영역으로 읽으면 참 (영역 값은 소스 대입식에서 가져옴 - 사본 금지)
#   ③ 기존 배치 보존: 개발 PC 배치의 던전 안 캡처(층·구역 파서 포함)와 필드 캡처 판정이 그대로
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
[Console]::OutputEncoding = [Text.Encoding]::UTF8
function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$reportDir = Join-Path $projectRoot '던전이미지\실측기록\20260915_타PC_어비스_입장미감지_트래커상단잘림'
$captures = @{
  Report  = Join-Path $reportDir 'error_20260915_h03m24s43.png'                                   # 제보: 던전 안, 제목 줄 y≈190
  Inside  = Join-Path $projectRoot '던전이미지\던전\20260817_파티재입장_던전내부_1272.png'          # 개발 PC 배치: 던전 안 '심층 2층 1구역'
  Revive  = Join-Path $projectRoot '던전이미지\사망부활\1_제한형_개인_남은부활3-3_여신상+여기서.png' # 개발 PC 배치: 어비스 안 (던전명 키워드)
  Field   = Join-Path $projectRoot '던전이미지\실측기록\20260913_마지막판_필드복귀_물약팝업가림.png' # 필드 (키워드 없음)
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
# 본체 함수는 소스에서 그대로 (OCR 브리지 2 + 영역 판독 + 판정 2)
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Get-GameRegionOcrText', 'Test-InDungeonQuest', 'Test-DgQuestStageMatch')) {
  Invoke-Expression $definition
}
# 영역·키워드는 소스 대입식에서 캡처 (config 미정의 → 기본값)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$trackerAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
foreach ($sourceVar in @('rgQuestTracker', 'allDungeonKeywords')) {
  $assign = $trackerAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $sourceVar))
    }, $true)
  if (-not $assign) { "FAIL 본체에서 `$$sourceVar 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $assign.Extent.Text
}
$currentRegion = @($rgQuestTracker)
$v14Region = @(980, 190, 285, 77)   # 고치기 전 영역 (재현용 - 소스가 아니라 사고 당시 값이라 리터럴)

# 게임 창 캡처를 PNG 재생으로 대체 (워커 Get-GameRegionCapture 와 같은 수식 - 창 = 이미지 전체)
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
function Read-Tracker {
  param([int[]]$Region)
  return ((Get-GameRegionOcrText -Game $null -ReferenceX $Region[0] -ReferenceY $Region[1] `
      -RegionWidth $Region[2] -RegionHeight $Region[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', '')
}
function Use-Capture { param([string]$Path) if ($script:sourceBitmap) { $script:sourceBitmap.Dispose() }; $script:sourceBitmap = [System.Drawing.Bitmap]::FromFile($Path) }

# ── 0. 영역 계약 ──
Assert-Case '영역: 상단이 제보 제목 줄(y≈183~198)보다 위 (≤175)' ([int]$currentRegion[1] -le 175) $true
Assert-Case '영역: 하단 경계 267 유지 (v14 소비처 보존)' ([int]$currentRegion[1] + [int]$currentRegion[3]) 267
Assert-Case '영역: x·폭 불변 (980, 285)' ("$($currentRegion[0]),$($currentRegion[2])") '980,285'

# ── 1. 제보 캡처: 고치기 전 재현 → 고친 후 통과 ──
Use-Capture $captures.Report
Assert-Case '제보 캡처 크기 1272x717 (권장 창 크기 그대로)' ("$($script:sourceBitmap.Width)x$($script:sourceBitmap.Height)") '1272x717'
$rgQuestTracker = $v14Region
$v14Text = Read-Tracker $v14Region
"  (v14 영역 판독문: '$v14Text')"
Assert-Case '재현(v14 영역): 제목 줄이 잘려 던전 키워드 없음 → Test-InDungeonQuest 거짓' (Test-InDungeonQuest -Game $null) $false
Assert-Case '재현(v14 영역): 잘린 판독문에 둘째 줄(부활/클리어)만 남음' ($v14Text -notmatch '광기') $true
$rgQuestTracker = $currentRegion
$curText = Read-Tracker $currentRegion
"  (현행 영역 판독문: '$curText')"
Assert-Case '통과(현행 영역): 제목 줄 포함 → Test-InDungeonQuest 참' (Test-InDungeonQuest -Game $null) $true
Assert-Case '통과(현행 영역): 판독문에 던전명 조각 광기' ($curText.Contains('광기')) $true

# ── 2. 개발 PC 배치 보존: 던전 안 캡처의 층·구역 파서 ──
Use-Capture $captures.Inside
$insideText = Read-Tracker $currentRegion
"  (던전 안 판독문: '$insideText')"
Assert-Case '보존(던전 안 1272): 현행 영역 판독에 층·구역 존재' ([bool]($insideText -match '[12]층[123]구역')) $true
Assert-Case '보존(던전 안 1272): 첫 층·구역 쌍이 2-1 (탭 줄 유입이 파서 순서를 바꾸지 않음)' (Test-DgQuestStageMatch -QuestText $insideText -Stage '2-1') $true
Assert-Case '보존(던전 안 1272): 다른 구역(1-1)과는 불일치' (Test-DgQuestStageMatch -QuestText $insideText -Stage '1-1') $false

# ── 3. 개발 PC 배치 보존: 어비스 안 캡처의 던전명 키워드 (창 폭 1315 - 비율 환산 경로) ──
Use-Capture $captures.Revive
Assert-Case '보존(어비스 안 1315): Test-InDungeonQuest 참' (Test-InDungeonQuest -Game $null) $true

# ── 4. 필드 캡처: 키워드·구역 없음 (필드 증거 판정이 '없음'을 성공으로 쓰므로 새 글자가 유입되지 않아야 함) ──
Use-Capture $captures.Field
$fieldText = Read-Tracker $currentRegion
"  (필드 판독문: '$fieldText')"
Assert-Case '필드: Test-InDungeonQuest 거짓' (Test-InDungeonQuest -Game $null) $false
Assert-Case '필드: 구역/소탕/정찰 없음 (Test-BattleFieldEvidence 계약)' (-not ($fieldText.Contains('구역') -or $fieldText.Contains('소탕') -or $fieldText.Contains('정찰'))) $true
if ($script:sourceBitmap) { $script:sourceBitmap.Dispose() }

exit $fails
