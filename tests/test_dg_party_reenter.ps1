# 파티 재입장 대응 (v2.1.2 - 2026-08-17 신설) 진리표 + 오류 캡처 재현 + 배선 가드
# 실사고: 월요일 06:00 주간 리셋 회차 - '다시 하기' 직후 우연한 만남 파티의 재입장이 진입
# 옵션 화면을 생략하고 곧장 입장 → '옵션 화면 대기' 40초 초과 exit 1 → 복구 회차도 완료
# 마커+던전 내부 조합으로 안전 중단. 오류 캡처(보존: 던전이미지\던전\20260817_파티재입장_
# 던전내부_1272.png)가 던전 내부(트래커 '심층 2층 1구역')를 실측.
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
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Test-DgQuestStageMatch')) {
  Invoke-Expression $definition
}
$workerText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 진리표: 퀘스트 트래커 층·구역 일치 판정 ──
Assert-Case '트래커: 실사고 문구 → 2-1 일치' (Test-DgQuestStageMatch -QuestText '던전클리어심층2층1구역클리어' -Stage '2-1') 'True'
Assert-Case '트래커: 실사고 문구 → 다른 항목(2-3) 불일치' (Test-DgQuestStageMatch -QuestText '던전클리어심층2층1구역클리어' -Stage '2-3') 'False'
Assert-Case '트래커: 공백 포함 원문 → 일치' (Test-DgQuestStageMatch -QuestText '던전 클리어 · 심층 2층 1구역 클리어' -Stage '2-1') 'True'
Assert-Case '트래커: 필드 주간 퀘스트(층·구역 쌍 없음) → false' (Test-DgQuestStageMatch -QuestText '심층던전클리어' -Stage '2-1') 'False'
Assert-Case '트래커: 빈 판독 → false (fail-closed)' (Test-DgQuestStageMatch -QuestText '' -Stage '2-1') 'False'
Assert-Case '트래커: 일반 던전 1층 3구역 → 일치' (Test-DgQuestStageMatch -QuestText '1층3구역클리어' -Stage '1-3') 'True'
Assert-Case '트래커: 범위 밖 층(3층) → false' (Test-DgQuestStageMatch -QuestText '3층1구역' -Stage '3-1') 'False'

# ── 오류 캡처 재현 (규칙 9): 실제 트래커 영역 판독이 층·구역 일치를 확정하는가 ──
$refW = 1272; $refH = 717
$rgQuestTracker = @(980, 190, 285, 77)   # config 기본값과 동일 (ocrRegions.questTracker)
function Read-CaptureRegionText {
  # test_nyan_ocr_offline 의 검증된 크롭/확대/판독 패턴 (기준 비율 크롭 → 기준×배율 확대 → ko OCR)
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
    return [string]$ocr.Text
  } finally { $crop.Dispose(); $scaled.Dispose() }
}
$capturePath = Join-Path $projectRoot '던전이미지\던전\20260817_파티재입장_던전내부_1272.png'
$captureSrc = [System.Drawing.Bitmap]::FromFile($capturePath)
$trackerText = (Read-CaptureRegionText -Src $captureSrc -Region $rgQuestTracker -Scale 3) -replace '\s', ''
$captureSrc.Dispose()
# 타 PC 동일 연쇄 제보(같은 날 06:02)의 '새로운 한 주' 주간 리셋 팝업 캡처 - 입장 로딩
# 대기를 덮은 그 화면. 스윕 게이트(하단 문구 '협동'+'참여')가 실측 화면에서 발화하는지.
$weeklyCapPath = Join-Path $projectRoot '던전이미지\던전\20260817_주간리셋팝업_입장대기_1272.png'
$weeklyCapSrc = [System.Drawing.Bitmap]::FromFile($weeklyCapPath)
$rgClearExitDefault = @(430, 570, 420, 125)   # config ocrRegions.clearAndExitText 기본값
$weeklyBottomText = (Read-CaptureRegionText -Src $weeklyCapSrc -Region $rgClearExitDefault -Scale 3) -replace '\s', ''
$weeklyCapSrc.Dispose()
"  (판독문: '$trackerText')"
Assert-Case '재현: 오류 캡처 트래커 판독에 층·구역 존재' ([bool]($trackerText -match '[12]층[123]구역')) 'True'
Assert-Case '재현: 판독문이 사고 당시 목표(2-1)와 일치 판정' (Test-DgQuestStageMatch -QuestText $trackerText -Stage '2-1') 'True'
Assert-Case '재현: 다른 구역(1-1)과는 불일치 판정' (Test-DgQuestStageMatch -QuestText $trackerText -Stage '1-1') 'False'
"  (주간 팝업 하단 판독문: '$weeklyBottomText')"
Assert-Case '재현: 주간 리셋 팝업 하단 문구가 스윕 게이트(협동+참여) 발화' `
  ($weeklyBottomText.Contains('협동') -and $weeklyBottomText.Contains('참여')) 'True'

# ── 구조 가드 (AST): 라벨 루프가 클리어 대기~옵션 대기를 감싸고, 무라벨 break/continue 가
#    루프 직속에 없어야 함 (2026-08-17 구현 중 중괄호 오배치를 AST 검사로 적발한 계약을 영구화) ──
$dgAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'mabinogi_run_once.ps1'), [ref]$null, [ref]$null)
$dgLoop = $dgAst.Find({ param($n) $n -is [System.Management.Automation.Language.WhileStatementAst] -and $n.Label -eq 'dgClearCycle' }, $true)
Assert-Case '구조: dgClearCycle 라벨 루프 존재' ($null -ne $dgLoop) 'True'
if ($null -ne $dgLoop) {
  $loopBody = $dgLoop.Extent.Text
  Assert-Case '구조: 루프가 클리어 대기~옵션 대기~재입장 분기를 전부 포함' `
    (($loopBody.Contains('던전 클리어 화면 감지 대기 시작')) -and
     ($loopBody.Contains("'다시 하기' 클릭 - 옵션 화면 복귀 대기")) -and
     ($loopBody.Contains('진입 옵션 화면 대기 시간이 초과됐습니다')) -and
     ($loopBody.Contains('파티 재입장'))) 'True'
  $unlabeledDirect = 0
  foreach ($stmt in $dgLoop.FindAll({ param($n) ($n -is [System.Management.Automation.Language.BreakStatementAst]) -or ($n -is [System.Management.Automation.Language.ContinueStatementAst]) }, $true)) {
    if ([string]$stmt.Label) { continue }
    $parentNode = $stmt.Parent
    $nearestLoop = $null
    while ($parentNode) {
      if ($parentNode -is [System.Management.Automation.Language.LoopStatementAst] -or $parentNode -is [System.Management.Automation.Language.SwitchStatementAst]) { $nearestLoop = $parentNode; break }
      $parentNode = $parentNode.Parent
    }
    if ($nearestLoop -eq $dgLoop) { $unlabeledDirect++ }
  }
  Assert-Case '구조: 무라벨 break/continue 의 루프 직속 0건 (의도치 않은 루프 이탈 방지)' $unlabeledDirect 0
}

# ── 배선 가드 ──
Assert-Case '배선: 옵션 대기의 던전 내부 감지 (트래커 층·구역 일치 + 2연속)' `
  (($workerText -match 'Test-DgQuestStageMatch -QuestText \$waitQuestText -Stage \$ndStage') -and
   ($workerText -match '\$insideStreak -ge 2')) 'True'
Assert-Case '배선: 캡처 실패 표본은 연속 초기화' `
  ([bool]($workerText -match '\} else \{\r?\n\s+\$insideStreak = 0\r?\n\s+\}\r?\n\s+\} else \{\r?\n\s+\$insideStreak = 0')) 'True'
Assert-Case '배선: 커스텀 재진입 (AfterEntryKeys + insideAlready 재진입 + continue)' `
  ([bool]($workerText -match "Invoke-AfterEntryKeys -Game \`$Game -LogPrefix '\[던전\]'\r?\n\s+\`$onResultScreen = \`$false\r?\n\s+\`$insideAlready = \`$true\r?\n\s+\`$reenteredInside = \`$false\r?\n\s+continue dgClearCycle")) 'True'
Assert-Case '배선: 비커스텀은 회차 완료 처리 후 루프 종료' `
  ([bool]($workerText -match '회차를 완료로 처리합니다[^\r\n]*\r?\n\s+break dgClearCycle')) 'True'
Assert-Case '배선: 옵션 대기 타임아웃 오류는 유지 (fail-closed)' `
  ($workerText.Contains("throw '다시 하기 → 진입 옵션 화면 대기 시간이 초과됐습니다.'")) 'True'
Assert-Case '배선: 마무리 복구 완화 - 같은 구역 재판독 2연속 + 불일치 fail-closed 유지' `
  (($workerText -match 'Test-DgQuestStageMatch -QuestText \$questText -Stage \$ndStage') -and
   ($workerText -match '\$recoveryStageOk = \(-not \$script:screenCaptureFailing\) -and \(Test-DgQuestStageMatch -QuestText \$recoveryRecheck -Stage \$ndStage\)') -and
   ($workerText.Contains("throw '완료 항목 마무리 복구 중 던전 내부 화면이 감지됐습니다 - 항목을 다시 실행하지 않고 안전하게 중단합니다.'"))) 'True'
Assert-Case '배선: 재입장 회차의 완료 로그는 옵션 복귀 문구를 쓰지 않음' `
  ([bool]($workerText -match 'if \(-not \$reenteredInside\) \{\r?\n\s+Write-RunLog ''\[던전\] 다시 하기 → 옵션 화면 복귀 - 회차 완료''')) 'True'
# 타 PC 제보(06:02): 주간 리셋 '새로운 한 주' 팝업이 팝업 스윕에 빠져 있어 입장 로딩 대기
# 45초 초과 + 재시작 시작 판정 오판(결과 화면 오인 - 완료 마커 오기록). 스윕에 게이트 추가 -
# 협동 전체 창 처리 뒤, 이미 읽은 하단 문구로 게이트 (평상시 추가 판독 없음)
Assert-Case '배선: 팝업 스윕에 주간 리셋 팝업 처리 (전체 창 뒤 + 하단 문구 게이트)' `
  ([bool]($workerText -match "Close-CoopMissionBoardScreen -Game \`$Game\) \{ return \`$true \}[\s\S]{0,700}\`$bottomText\.Contains\('협동'\) -and \`$bottomText\.Contains\('참여'\) -and \(Close-WeeklyCoopResetPopup -Game \`$Game\)\) \{ return \`$true \}[\s\S]{0,300}Close-NetworkUnstablePopup")) 'True'

exit $fails
