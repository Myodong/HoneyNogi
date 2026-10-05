# 파티 재입장 대응 (v2.1.2 - 2026-08-17 신설) 진리표 + 오류 캡처 재현 + 배선 가드
# 실사고: 월요일 06:00 주간 리셋 회차 - '다시 하기' 직후 우연한 만남 파티의 재입장이 진입
# 옵션 화면을 생략하고 곧장 입장 → '옵션 화면 대기' 40초 초과 exit 1 → 복구 회차도 완료
# 마커+던전 내부 조합으로 안전 중단. 오류 캡처(보존: 던전이미지\공통\20260817_파티재입장_
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
# Get-DgTimeVerdict 는 T6(꼬리) 전용입니다 - 꼬리가 시각을 다시 판단하는 결함이 생기면 그 호출이 실제 판단 함수로 돌아 행 7·8 이 '판단값만 본다'
# 계약 위반으로 실패하게 합니다 (함수가 없으면 명령 없음 예외로 실패해 원인이 흐려짐)
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Test-DgQuestStageMatch', 'Get-DgTimeVerdict')) {
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
# 영역은 소스 대입식에서 가져옵니다 (사본 진리표 금지 - v15 에서 하드코딩 사본이 옛 영역을 검증하던 것을 정정)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$reenterAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'mabinogi_run_once.ps1'), [ref]$null, [ref]$null)
$reenterAssign = $reenterAst.Find({ param($n) ($n -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($n.Left.Extent.Text -eq '$rgQuestTracker') }, $true)
if (-not $reenterAssign) { 'FAIL 본체에서 $rgQuestTracker 정의를 찾지 못했습니다'; exit 1 }
Invoke-Expression $reenterAssign.Extent.Text
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
$capturePath = Join-Path $projectRoot '던전이미지\공통\20260817_파티재입장_던전내부_1272.png'
$captureSrc = [System.Drawing.Bitmap]::FromFile($capturePath)
$trackerText = (Read-CaptureRegionText -Src $captureSrc -Region $rgQuestTracker -Scale 3) -replace '\s', ''
$captureSrc.Dispose()
# 타 PC 동일 연쇄 제보(같은 날 06:02)의 '새로운 한 주' 주간 리셋 팝업 캡처 - 입장 로딩
# 대기를 덮은 그 화면. 스윕 게이트(하단 문구 '협동'+'참여')가 실측 화면에서 발화하는지.
$weeklyCapPath = Join-Path $projectRoot '던전이미지\공통\20260817_주간리셋팝업_입장대기_1272.png'
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
# v2.1.6 태그 동적화: LogPrefix 가 리터럴 '[던전]'에서 $script:contentTag 로 (심층 [심층] 교정)
Assert-Case '배선: 커스텀 재진입 (AfterEntryKeys + insideAlready 재진입 + continue)' `
  ([bool]($workerText -match "Invoke-AfterEntryKeys -Game \`$Game -LogPrefix \`$script:contentTag\r?\n\s+\`$onResultScreen = \`$false\r?\n\s+\`$insideAlready = \`$true\r?\n\s+\`$reenteredInside = \`$false\r?\n\s+continue dgClearCycle")) 'True'
Assert-Case '배선: 비커스텀은 회차 완료 처리 후 루프 종료' `
  ([bool]($workerText -match '회차를 완료로 처리합니다[^\r\n]*\r?\n\s+break dgClearCycle')) 'True'
Assert-Case '배선: 옵션 대기 타임아웃 오류는 유지 (fail-closed)' `
  ($workerText.Contains("throw '다시 하기 → 진입 옵션 화면 대기 시간이 초과됐습니다.'")) 'True'
Assert-Case '배선: 마무리 복구 완화 - 같은 구역 재판독 2연속 + 불일치 fail-closed 유지' `
  (($workerText -match 'Test-DgQuestStageMatch -QuestText \$questText -Stage \$ndStage') -and
   ($workerText -match '\$recoveryStageOk = \(-not \$script:screenCaptureFailing\) -and \(Test-DgQuestStageMatch -QuestText \$recoveryRecheck -Stage \$ndStage\)') -and
   ($workerText.Contains("throw '완료 항목 마무리 복구 중 던전 내부 화면이 감지됐습니다 - 항목을 다시 실행하지 않고 안전하게 중단합니다.'"))) 'True'
Assert-Case '배선: 재입장 회차의 완료 로그는 옵션 복귀 문구를 쓰지 않음' `
  ([bool]($workerText -match 'if \(-not \$reenteredInside\) \{\r?\n\s+Write-RunLog "\$\(\$script:contentTag\) 다시 하기 → 옵션 화면 복귀 - 회차 완료"')) 'True'
# 타 PC 제보(06:02): 주간 리셋 '새로운 한 주' 팝업이 팝업 스윕에 빠져 있어 입장 로딩 대기
# 45초 초과 + 재시작 시작 판정 오판(결과 화면 오인 - 완료 마커 오기록). 스윕에 게이트 추가 -
# 협동 전체 창 처리 뒤, 이미 읽은 하단 문구로 게이트 (평상시 추가 판독 없음)
Assert-Case '배선: 팝업 스윕에 주간 리셋 팝업 처리 (전체 창 뒤 + 하단 문구 게이트)' `
  ([bool]($workerText -match "Close-CoopMissionBoardScreen -Game \`$Game\) \{ return \`$true \}[\s\S]{0,700}\`$bottomText\.Contains\('협동'\) -and \`$bottomText\.Contains\('참여'\) -and \(Close-WeeklyCoopResetPopup -Game \`$Game\)\) \{ return \`$true \}[\s\S]{0,300}Close-NetworkUnstablePopup")) 'True'

# ── T6 던전 함수 꼬리 (시간 지정 '그 판까지' 설계 8.2 T6 - 회귀 R-5·경합 P2-2) ──
# 파티 재입장(우연한 만남)도 옵션 복귀와 같은 꼬리를 지납니다 - 시간 지정에서 14-T 가 '이어 감'('continue')으로 정한 판은 두 경우 모두 종료 코드 11 로
# 끝나야 GUI 가 지정 시각을 보지 않고 다음 워커를 띄웁니다 (재입장 판 뒤에 GUI 가 멈추면 파티와 함께 던전 안에 남음 - 조건 4). 꼬리는 판단값만 보고
# 시각을 다시 보지 않습니다.
# 꼬리 = Invoke-NormalDungeonCycle 본문에서 :dgClearCycle while 뒤의 형제 문장 전부 (정리 모드 exit 10 · 옵션 복귀 로그 · 시간 이어 감 exit 11 · exit 0).
# 줄 단독 exit 는 대입이 아니라 throw 센티널로 바꿉니다 - 꼬리에는 exit 가 차례로 셋이라 대입이면 뒤 exit 가 앞 값을 덮습니다 (14-0 하니스는 exit 하나라
# 대입). 실행 전 3중 단언(원본 ExitStatementAst 3 = 줄 단독 exit 3 = 치환 수 3, 치환 뒤 다시 파싱한 ExitStatementAst 0)이 하나라도 어긋나면 FAIL 을 찍고,
# 치환이 안전하지 않으면(치환 안 된 exit 가 남음) 행을 실행하지 않습니다 - 치환 안 된 exit 가 이 테스트 프로세스를 끝내면 이 파일 끝(exit $fails)에
# 닿지 않고 그 exit 값으로 끝나, 0 이면 러너가 '통과'로 셉니다 (러너는 FAIL 줄 없음 + 종료 코드 0 이면 통과). 행은 헬퍼 함수 안에서 점소싱합니다
# (규칙 3 - 꼬리가 읽는 지역 변수를 그 함수에 둠)
$tailFunction = $dgAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-NormalDungeonCycle' }, $true)
$tailStatements = @()
if ($null -ne $tailFunction) {
  $bodyStatements = @($tailFunction.Body.EndBlock.Statements)
  $loopIndex = -1
  for ($i = 0; $i -lt $bodyStatements.Count; $i++) {
    if ($bodyStatements[$i] -is [System.Management.Automation.Language.WhileStatementAst] -and $bodyStatements[$i].Label -eq 'dgClearCycle') { $loopIndex = $i }
  }
  if ($loopIndex -ge 0) { $tailStatements = @($bodyStatements | Select-Object -Skip ($loopIndex + 1)) }
}
$tailText = (@($tailStatements | ForEach-Object { [string]$_.Extent.Text }) -join "`n")
$tailExitPattern = '(?m)^(\s*)exit (\d+)\s*$'
$tailOriginalExits = @([System.Management.Automation.Language.Parser]::ParseInput($tailText, [ref]$null, [ref]$null).FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count
$tailLineExits = [regex]::Matches($tailText, $tailExitPattern).Count
$tailConverted = $tailText -replace $tailExitPattern, '$1throw "__EXIT__$2"'
$tailReplaced = [regex]::Matches($tailConverted, 'throw "__EXIT__\d+"').Count
$tailRemaining = @([System.Management.Automation.Language.Parser]::ParseInput($tailConverted, [ref]$null, [ref]$null).FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count
$tailSentinel = "$tailOriginalExits/$tailLineExits/$tailReplaced/$tailRemaining"
Assert-Case 'T6 센티널: 꼬리 원본 ExitStatementAst 3 = 줄 단독 exit 3 = 치환 수 3, 치환 뒤 ExitStatementAst 0' $tailSentinel '3/3/3/0'
# 행 실행 조건은 '치환이 안전함'(원본 = 줄 단독 = 치환 수, 남은 exit 0) 입니다 - 개수가 3 이 아니어도(예: 이어 감 exit 11 블록이 빠짐) 안전하면 행을 돌려
# 그 결함이 위 개수 단언과 함께 행동(1·2·7행)으로도 드러나게 합니다. 안전하지 않으면 실행하지 않습니다 (치환 안 된 exit 가 프로세스를 끝냄)
$tailSafe = ($tailOriginalExits -gt 0) -and ($tailOriginalExits -eq $tailLineExits) -and ($tailLineExits -eq $tailReplaced) -and ($tailRemaining -eq 0)
$tailBlock = $(if ($tailSafe) { [scriptblock]::Create($tailConverted) } else { $null })
function Write-RunLog { param([string]$Message) $script:tailLogs += $Message }
$script:contentTag = '[던전]'
$script:tailRows = 0
function Invoke-DgTail {
  # 꼬리 한 행 - 꼬리가 읽는 지역 변수(재입장 여부·판단값·지정 시각)를 이 함수 안에 두고 꼬리를 점소싱합니다. 반환: 센티널의 종료 코드 또는 사유 문자열.
  # $Until 은 타입 없이 받습니다 - 시간 지정이 아닌 행은 $null 이고 [datetime] 이면 변환 실패 (규칙 3)
  param([bool]$CleanupOnly, [bool]$ReenteredInside, [string]$Verdict, $Until)
  $script:customCleanupOnly = $CleanupOnly
  $reenteredInside = $ReenteredInside
  $dgTimeVerdict = $Verdict
  $dgUntil = $Until
  $script:tailLogs = @()
  $script:tailRows++
  try { . $tailBlock; return '(반환됨 - exit 없음)' }
  catch {
    if ($_.Exception.Message -match '^__EXIT__(\d+)$') { return [int]$Matches[1] }
    return "예외: $($_.Exception.Message)"
  }
}
$tailUntil = [datetime]'2026-10-01 10:00:00'
$optionLog = '[던전] 다시 하기 → 옵션 화면 복귀 - 회차 완료'
$continueLog = '[던전] 지정 시간 10:00 전에 다음 판으로 이어 갔습니다 - 다음 워커가 이어받습니다'
# 행: 정리 모드 · 재입장 · 판단값 · 지정 시각 → 기대 종료 코드 (로그 L 이 있으면 순서대로 정확히). 7·8 행은 판단값과 시계를 일부러 어긋나게 둡니다
$tailCases = @(
  @{ I = 1; N = "'continue' · 옵션 복귀 → exit 11 (옵션 복귀 로그 → 이어 감 로그)"; C = $false; R = $false; V = 'continue'; U = $tailUntil; E = 11; L = @($optionLog, $continueLog) }
  @{ I = 2; N = "'continue' · 파티 재입장 → exit 11 (옵션 복귀 로그 0)"; C = $false; R = $true; V = 'continue'; U = $tailUntil; E = 11; L = @($continueLog) }
  @{ I = 3; N = "시간 지정 아님('') · 옵션 복귀 → exit 0"; C = $false; R = $false; V = ''; U = $null; E = 0; L = @($optionLog) }
  @{ I = 4; N = "시간 지정 아님('') · 파티 재입장 → exit 0"; C = $false; R = $true; V = ''; U = $null; E = 0; L = @() }
  @{ I = 5; N = "'last' → exit 0 (실제로는 14-0 이 먼저 끝내는 조합 - 꼬리 조건이 'continue' 하나만 보는지)"; C = $false; R = $false; V = 'last'; U = $tailUntil; E = 0; L = @($optionLog) }
  @{ I = 6; N = '정리 모드 → exit 10'; C = $true; R = $false; V = ''; U = $null; E = 10; L = $null }
  @{ I = 7; N = "'continue' + 지정 시각이 이미 지남(지금 − 1시간) → exit 11 (꼬리는 시각을 다시 보지 않음)"; C = $false; R = $false; V = 'continue'; U = (Get-Date).AddHours(-1); E = 11; L = $null }
  @{ I = 8; N = "'' + 지정 시각이 아직 미래(지금 + 1시간) → exit 0 (판단값만 봄)"; C = $false; R = $false; V = ''; U = (Get-Date).AddHours(1); E = 0; L = $null }
  @{ I = 9; N = "정리 모드 + 'continue' → exit 10 (정리 모드가 11 보다 먼저 - 꼬리 순서)"; C = $true; R = $false; V = 'continue'; U = $tailUntil; E = 10; L = $null }
)
foreach ($row in $tailCases) {
  if ($null -eq $tailBlock) { break }   # 치환이 안전하지 않음 - 행을 실행하지 않음 (아래 개수 단언이 FAIL)
  $tailExit = Invoke-DgTail -CleanupOnly $row.C -ReenteredInside $row.R -Verdict $row.V -Until $row.U
  Assert-Case "T6 꼬리 $($row.I)행: $($row.N)" $tailExit $row.E
  if ($null -ne $row.L) { Assert-Case "T6 꼬리 $($row.I)행 로그 (순서대로)" (@($script:tailLogs) -join ' / ') (@($row.L) -join ' / ') }
}
Assert-Case 'T6 꼬리: 9행 모두 실행됨 (치환이 안전하지 않으면 0)' $script:tailRows 9

exit $fails
