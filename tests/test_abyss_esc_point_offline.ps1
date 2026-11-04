# 복귀 루프 ESC 글자 탐색 · 고정점 진리표 (2026-11-04 - 구현 명세 ESC탐색 3.1, 재현 자료 던전이미지\어비스\20261103_필드ESC미감지_재현\)
#
# 실사고 10-28 실기 1-D′a(1908x1076 · 창 DPI 96): 필드 확정 뒤 'ESC 클릭' 다섯 번에 메뉴가 안 열려 복귀 대기 초과 코드 1. 판독 영역 왼쪽의 다른 플레이어 이름표 하나로
# 일반 판독이 통째로 '' 가 됐는데 Test-HomeEndEscHud 는 이진화로 참이라 ESC 분기까지 왔고, 글자 탐색은 일반 판독 한 번뿐이라 1272 실측 고정점 (1083,89) = 창 (1624,134) 을
# 눌렀습니다. 그 점은 네이티브 1908 · 1914 에서 라벨 밖입니다. 복귀 루프는 이제 일반 → 이진화(한국어 엔진)로 읽고, 둘 다 못 찾으면 커서를 치운 뒤 창 크기에 맞는 고정점을 누릅니다.
# 세 층입니다 (선례 test_dg_retry_button_offline · test_abyss_menu_icon):
#   §1 배선 - 늘 실행. 주석 뺀 사본 · LF 기준. 탐색 함수의 두 호출, 복귀 루프 ESC 분기의 순서, 계약값, 회전 서두 메타 비움
#   §2 진리표 - 늘 실행, 그림 없음. 캡처 스텁 + 판독결과 단어 줄 모의로 실제 Find-GameTextPoint · Find-AbyssEscButtonPoint 를 돌리고, 고정점 고르기 표 · 라벨 상자 · 창 크기 실행 행
#   §3 그림 재생 - 개발 PC. 그림 37장(재현 28 + 작은 창 9)을 워커 경로 그대로 판독. 던전이미지 루트가 없으면 SKIP, 루트가 있는데 그림이 없으면 FAIL, 엔진이 없으면 그 단만 SKIP
# 행동(대피 · 고정점 차례 · 토큰 · 로그 줄)은 test_abyss_return_loop 의 RLE 사례가 봅니다. 라벨 상자는 그림에서 잰 값입니다 (구현 명세 ESC탐색의 조사_배치실측).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing
$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
function Check-True {
  param([string]$Name, [bool]$Condition, [string]$Detail)
  if ($Condition) { "OK   $Name" }
  else { "FAIL $Name ($Detail)"; $script:fails++ }
}

# ── 소스: 한 번 파싱해 함수 · 상수를 그대로 씁니다 (사본 금지) ──
$workerText = [IO.File]::ReadAllText($workerPath)
$workerTokens = $null; $workerParseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseInput($workerText, [ref]$workerTokens, [ref]$workerParseErrors)
if ($workerParseErrors.Count -gt 0) { "FAIL 워커 파싱 오류 $($workerParseErrors.Count)건 - 첫 오류: $($workerParseErrors[0].Message)"; exit 1 }
$functionAsts = @{}
foreach ($functionAst in $workerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
  if (-not $functionAsts.ContainsKey($functionAst.Name)) { $functionAsts[$functionAst.Name] = $functionAst }   # 같은 이름이면 첫 정의 (Get-SourceFunctionDefinitions 와 같은 선택)
}
function Get-WorkerFunctionText {
  param([string]$Name)
  if (-not $functionAsts.ContainsKey($Name)) { throw "워커에서 함수를 찾지 못했습니다: $Name" }
  return [string]$functionAsts[$Name].Extent.Text
}
function Get-LfCode {
  # 주석 뺀 사본 - LF 기준이고 빈 줄 · 줄 끝 공백이 없습니다 (주석 자리는 공백으로 남으므로 지워야 '바로 앞 줄' 단언이 주석 줄에 끊기지 않습니다)
  param([string]$Text)
  $codeLines = @((Remove-SourceComments -Text $Text) -split "`r?`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne '' })
  return ($codeLines -join "`n")
}
function Get-TextAt {
  # 문화권과 무관한 위치 찾기 - 시작 자리가 음수(앞 단계 못 찾음)면 처음부터 찾습니다
  param([string]$Text, [string]$Needle, [int]$From = 0)
  return $Text.IndexOf($Needle, [Math]::Max(0, $From), [StringComparison]::Ordinal)
}
function Get-LineJoinPattern {
  # 줄 목록을 '바로 다음 줄' 로 잇는 정규식 (LF 사본 기준 - 들여쓰기만 허용)
  param([string[]]$Lines)
  return (($Lines | ForEach-Object { [regex]::Escape($_) }) -join '\n\s*')
}

# ── 상수: 소스 대입문을 그대로 실행 (config 미정의 → 기본값). 최상위 문장만 봅니다 - 조건문 안의 재대입은 기본 경로가 아닙니다 ──
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
function Get-ConfigInteger { param([object]$Root, [string[]]$Path, $Default, $Minimum, $Maximum) return $Default }
$constantNames = @('$referenceWidth', '$referenceHeight', '$rgHomeEndEsc', '$ptEscButton', '$ptEscButtonLarge', '$escLargeWindowMinWidth')
$constantAssignments = @{}
foreach ($constantName in $constantNames) {
  $sourceAssignments = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq $constantName) })
  if ($sourceAssignments.Count -ne 1) { "FAIL 셋업: 워커 최상위의 $constantName 대입문이 1곳이 아닙니다 ($($sourceAssignments.Count)곳)"; exit 1 }
  $constantAssignments[$constantName] = $sourceAssignments[0]
  Invoke-Expression $sourceAssignments[0].Extent.Text
}

# ── §1. 배선 ──
$finderCode = Get-LfCode (Get-WorkerFunctionText 'Find-AbyssEscButtonPoint')
$finderCommands = @($functionAsts['Find-AbyssEscButtonPoint'].FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
$finderCalls = @($finderCommands | ForEach-Object { (($_.Extent.Text -replace '`\r?\n', ' ') -replace '\s+', ' ').Trim() })
$searchCallHead = "Find-GameTextPoint -Game `$Game -ReferenceX `$rgHomeEndEsc[0] -ReferenceY `$rgHomeEndEsc[1] -RegionWidth `$rgHomeEndEsc[2] -RegionHeight `$rgHomeEndEsc[3] -SearchText 'ESC' -ExactText 'ESC' -Scale 5"
Check-Equal '§1 탐색 함수: 명령은 Find-GameTextPoint 두 번뿐 (판독만 - 클릭 · 키 · Focus-Game · Move-CursorOutsideGame · 양보 호출 0)' `
  (@($finderCommands | ForEach-Object { $_.GetCommandName() }) -join ',') 'Find-GameTextPoint,Find-GameTextPoint'
Check-Equal '§1 탐색 함수: 이진화 호출 1곳' ([regex]::Matches($finderCode, '-BinaryWhiteText').Count) 1
# 주석 뺀 사본은 LF 로 이어져 있습니다 - 두 위치가 모두 있어야 하고(≥0) 일반이 앞입니다 (test_dg_retry_button_offline 의 헛단언 주석 참고)
$normalCallAt = Get-TextAt $finderCode ('-Engine $ocrEnglishEngine' + "`n")
$binaryCallAt = Get-TextAt $finderCode '-Engine $ocrKoreanEngine -BinaryWhiteText'
Check-True '§1 탐색 함수: 일반 판독 위치 < 이진화 위치 (LF 기준)' (($normalCallAt -ge 0) -and ($binaryCallAt -ge 0) -and ($normalCallAt -lt $binaryCallAt)) "일반 $normalCallAt / 이진화 $binaryCallAt"
Check-Equal '§1 탐색 함수: 두 호출의 영역 · 찾는 글자 · 배율이 같음 ($rgHomeEndEsc · ESC · 5)' `
  (@($finderCalls | ForEach-Object { $_ -replace ' -Engine \$\w+( -BinaryWhiteText)?$', '' } | Select-Object -Unique) -join ' | ') $searchCallHead
Check-Equal '§1 탐색 함수: 일반은 $ocrEnglishEngine · 이진화는 $ocrKoreanEngine' ($finderCalls -join ' | ') ("$searchCallHead -Engine `$ocrEnglishEngine | $searchCallHead -Engine `$ocrKoreanEngine -BinaryWhiteText")

$returnAst = $functionAsts['Return-ToAbyssSelection']
$returnCode = Get-LfCode (Get-WorkerFunctionText 'Return-ToAbyssSelection')
$turnGuard = 'if ($script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial) { Start-Sleep -Milliseconds 700; continue }'
$branchPattern = Get-LineJoinPattern @('Focus-Game -Game $Game', '$escRead = Find-AbyssEscButtonPoint -Game $Game', '$escPoint = $escRead.Point', $turnGuard, 'if ($escPoint) {', '$escMissCount = 0')
Check-Equal '§1 복귀 루프: ESC 분기 순서 = Focus-Game → 탐색 → 회전 가드 → if ($escPoint) { 바로 안의 $escMissCount = 0 (두 판독을 같은 가드가 덮음 - 규칙 15)' ([regex]::Matches($returnCode, $branchPattern).Count) 1
Check-Equal '§1 복귀 루프: $ptEscButton · $ptEscButtonLarge 직접 사용 0 (고른 점만 누름)' ([regex]::Matches($returnCode, '\$ptEscButton').Count) 0
$e6Pattern = '\$escFallback = Get-AbyssEscFallbackPoint -Game \$Game -LargeTurn \$escLargeTurn\n\s*\$escClickTail = [^\n]*\n\s*Click-GamePoint -Game \$Game -ReferenceX \$escFallback\.X -ReferenceY \$escFallback\.Y\n'
Check-Equal '§1 복귀 루프: Get-AbyssEscFallbackPoint 호출은 E6 의 Click-GamePoint 바로 앞 (꼬리 대입 한 줄만 사이) - 클릭 직전의 창 너비' ([regex]::Matches($returnCode, $e6Pattern).Count) 1
$fallbackCalls = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Get-AbyssEscFallbackPoint') }, $true))
Check-Equal '§1 복귀 루프: Get-AbyssEscFallbackPoint 호출은 워커 전체 1곳' $fallbackCalls.Count 1

$e5At = Get-TextAt $returnCode 'if ($escMissCount % 2 -eq 1) {'
$e5Diagnostics = "if (`$escMissCount -eq 3) { Write-LifeDiagnostics -Game `$Game -Context '어비스 ESC 글자 미발견' -CaptureOnly }"
$e5Steps = [ordered]@{
  '갈래 시작' = $e5At
  'Test-CursorOverGame' = Get-TextAt $returnCode 'Test-CursorOverGame -Game $Game' $e5At
  'Write-RunLog' = Get-TextAt $returnCode 'Write-RunLog "[어비스] ESC 글자를 못 읽어' $e5At
  'Move-CursorOutsideGame' = Get-TextAt $returnCode 'Move-CursorOutsideGame -Game $Game' $e5At
  '3회째 진단' = Get-TextAt $returnCode $e5Diagnostics $e5At
  'continue' = ([regex]'\n\s*continue\n').Match($returnCode, [Math]::Max(0, $e5At)).Index
  '클릭 메타 읽기' = Get-TextAt $returnCode 'if ($script:lastClickPerformed) {' $e5At
}
$e5Values = @($e5Steps.Values)
Check-True '§1 복귀 루프: E5 갈래 순서 = Test-CursorOverGame → Write-RunLog → Move-CursorOutsideGame → 3회째 진단 → continue, 그 continue 가 $script:lastClickPerformed 읽기보다 앞 (앞 클릭의 참이 거짓 토큰이 되지 않게 - 규칙 4)' `
  (($e5Values[0] -ge 0) -and (@(0..($e5Values.Count - 2) | Where-Object { $e5Values[$_] -ge $e5Values[$_ + 1] }).Count -eq 0)) (@($e5Steps.Keys | ForEach-Object { '{0}={1}' -f $_, $e5Steps[$_] }) -join ', ')
Check-Equal '§1 복귀 루프: 진단 줄 원문이 Move-CursorOutsideGame 바로 뒤 · continue 바로 앞 (다음 판독이 볼 화면을 찍음 - -CaptureOnly)' `
  ([regex]::Matches($returnCode, (Get-LineJoinPattern @('Move-CursorOutsideGame -Game $Game', $e5Diagnostics, 'continue'))).Count) 1
$rollbackPattern = Get-LineJoinPattern @("if (`$script:lastClickSkipReason -eq 'user-active') {", 'if ($escMissCount -gt 0) { $escMissCount-- }',
  '$fieldProven = $false; $insideStreak = 0; $insideSince = $null; $selectionExpected = $false', "Invoke-UserYieldWithDeadline -Game `$Game -Context '어비스 선택 화면 복귀' -Deadline ([ref]`$deadline) -SeenYieldMs ([ref]`$seenYieldMs)")
Check-Equal '§1 복귀 루프: user-active 갈래의 계수 되돌림 줄이 폐기 줄보다 앞이고 폐기 줄이 양보 바로 앞 (보내지 않은 고정점은 차례를 쓰지 않음 - 규칙 4)' ([regex]::Matches($returnCode, $rollbackPattern).Count) 1

$mainLoops = @($returnAst.Body.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.WhileStatementAst]) -and ($_.Condition.Extent.Text -eq '$true') })
if ($mainLoops.Count -ne 1) { "FAIL 셋업: Return-ToAbyssSelection 의 최상위 while (`$true) 가 1곳이 아닙니다 ($($mainLoops.Count)곳)"; exit 1 }
$loopBody = $mainLoops[0].Body
$skipAssignments = @($returnAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$script:lastClickSkipReason') }, $true))
$firstBranch = @($loopBody.Statements | Where-Object { $_ -is [System.Management.Automation.Language.IfStatementAst] })[0]
$firstClick = $mainLoops[0].Find({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ([string]$node.GetCommandName() -like 'Click-*') }, $true)
Check-True "§1 복귀 루프: `$script:lastClickSkipReason = '' 대입은 함수 전체 1곳이고 회전 본문의 문장이며 첫 분기 · 첫 클릭보다 앞 (규칙 4 - 직전 회전의 메타가 남지 않게)" `
  (($skipAssignments.Count -eq 1) -and ($skipAssignments[0].Right.Extent.Text -eq "''") -and [object]::ReferenceEquals($skipAssignments[0].Parent, $loopBody) -and
   ($skipAssignments[0].Extent.StartOffset -lt $firstBranch.Extent.StartOffset) -and ($skipAssignments[0].Extent.StartOffset -lt $firstClick.Extent.StartOffset)) `
  "대입 $($skipAssignments.Count)곳"

Check-Equal '§1 계약값: 큰 창 고정점 1102,78 (창 DPI 96 · 144 라벨이 겹치는 띠 안 - 바꾸려면 설계 재합의)' ($ptEscButtonLarge -join ',') '1102,78'
Check-Equal '§1 계약값: 큰 창 경계 1590 (권장 크기 1272 · 1908 의 가운데)' $escLargeWindowMinWidth 1590
Check-Equal '§1 계약값: 두 상수는 Get-ConfigValue 를 거치지 않는 스크립트 상수 (coordsVersion · configSchemaVersion 과 무관)' `
  ('{0} / {1}' -f $constantAssignments['$ptEscButtonLarge'].Right.Extent.Text, $constantAssignments['$escLargeWindowMinWidth'].Right.Extent.Text) '@(1102, 78) / 1590'
$selectCommands = @($functionAsts['Select-AbyssEscFallbackPoint'].FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
Check-Equal '§1 고르기 함수: 명령 0 (순수 함수 - 창 너비 · 순번만 받음)' $selectCommands.Count 0
# §3 재생은 워커 Get-GameRegionCapture 본문을 그대로 돌립니다 - 자르기 · 이진화 · 확대를 베끼면 워커가 바뀌어도 재생은 옛 동작으로 통과합니다. 바꾸는 자리는 함수 머리와 화면 취득 한 줄뿐입니다
$captureSource = Get-WorkerFunctionText 'Get-GameRegionCapture'
$captureHead = 'function Get-GameRegionCapture {'
$screenCopyLine = '$sourceGraphics.CopyFromScreen($cropLeft, $cropTop, 0, 0, $sourceCapture.Size)'
Check-Equal '§1 재생 전제: 워커 캡처 본문에서 바꾸는 자리는 함수 머리 1곳 · 화면 취득 줄 1곳뿐' ('{0}/{1}' -f [regex]::Matches($captureSource, [regex]::Escape($captureHead)).Count, [regex]::Matches($captureSource, [regex]::Escape($screenCopyLine)).Count) '1/1'

# ── §2. 진리표 (그림 없음) ──
# 실제 함수를 돌립니다 - Find-GameTextPoint 의 단어 선택 · 좌표 환산, Find-AbyssEscButtonPoint 의 결정, 고르기 함수, 창 좌표 읽기. 모의는 캡처 · OCR · 창 좌표뿐입니다
foreach ($functionName in @('Find-GameTextPoint', 'Find-AbyssEscButtonPoint', 'Select-AbyssEscFallbackPoint', 'Get-AbyssEscFallbackPoint', 'Get-ScaledScreenPoint')) {
  Invoke-Expression (Get-WorkerFunctionText $functionName)
}
$ocrEnglishEngine = 'en'; $ocrKoreanEngine = 'ko'
$script:screenCaptureFailing = $false
$script:captureFailSerial = 0
$script:captureModes = New-Object 'System.Collections.Generic.List[string]'
$script:ocrEngines = New-Object 'System.Collections.Generic.List[string]'
$script:mockWindowWidth = 1908; $script:mockWindowHeight = 1076
$script:mockFailModes = @()       # 'null' 모드 - 이 판독 모드의 캡처가 실패합니다
$script:mockWordLines = @{}
$script:lastCaptureMode = ''
function Get-GameRegionCapture {
  # 스텁 - 호출 모드를 기록하고, 창 크기로 판독결과의 crop 값을 내는 워커 산식(창 원점 0,0)을 돌려줍니다. 비트맵은 모의 OCR 이 보지 않습니다
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3,
    [switch]$BinaryWhiteText, [switch]$ThrowOnWindowRectFailure)
  $captureMode = $(if ($BinaryWhiteText) { 'bin' } else { 'normal' })
  $script:captureModes.Add($captureMode)
  if ($script:mockFailModes -contains $captureMode) {
    $script:captureFailSerial++   # Register-CaptureFailure 대응
    $script:screenCaptureFailing = $true
    return $null
  }
  $script:screenCaptureFailing = $false   # Register-CaptureSuccess 대응
  $script:lastCaptureMode = $captureMode
  $width = $script:mockWindowWidth; $height = $script:mockWindowHeight
  return [pscustomobject]@{
    Bitmap = (New-Object System.Drawing.Bitmap 1, 1)
    CropLeft = [int][Math]::Round($ReferenceX * $width / $referenceWidth)
    CropTop = [int][Math]::Round($ReferenceY * $height / $referenceHeight)
    CropWidth = [Math]::Max(1, [int][Math]::Round($RegionWidth * $width / $referenceWidth))
    CropHeight = [Math]::Max(1, [int][Math]::Round($RegionHeight * $height / $referenceHeight))
    ScaledWidth = ($RegionWidth * $Scale); ScaledHeight = ($RegionHeight * $Scale); Scale = $Scale
  }
}
function ConvertTo-MockLine {
  # 판독결과 파일의 단어 줄("'Home'@(238,50,138x42) 'End'@(761,51,84x41)")을 Invoke-OcrOnBitmap 의 한 줄 모양으로 - 실측 판독문은 그대로 둡니다
  param([string]$WordText)
  $mockWords = @([regex]::Matches($WordText, "'([^']*)'@\((\d+),(\d+),(\d+)x(\d+)\)") | ForEach-Object {
      [pscustomobject]@{ Text = $_.Groups[1].Value
        BoundingRect = [pscustomobject]@{ X = [double]$_.Groups[2].Value; Y = [double]$_.Groups[3].Value; Width = [double]$_.Groups[4].Value; Height = [double]$_.Groups[5].Value } }
    })
  return [pscustomobject]@{ Words = $mockWords }
}
function Invoke-OcrOnBitmap {
  # 모의 - 스텁이 기록한 모드로 단어 줄을 고릅니다 (판독 영역의 일반 · 이진화 결과가 다른 것이 이 사고의 핵심)
  param($Bitmap, $Engine)
  $script:ocrEngines.Add([string]$Engine)
  return [pscustomobject]@{ Lines = @($script:mockWordLines[$script:lastCaptureMode]) }
}
function Format-EscRead {
  # 못 찾았을 때의 FoundBy 는 호출부가 읽지 않으므로 값으로 삼지 않습니다
  param($Read)
  if ($Read.Point) { return ('{0},{1} {2}' -f $Read.Point.X, $Read.Point.Y, $Read.FoundBy) }
  return '없음'
}

# 판독 행 - 단어 줄은 판독결과_*.txt 의 일반/영어 · 이진화/한국어 줄 그대로입니다. 'Esc' · 'esc' 두 행은 그 그림의 이진화/영어 줄을 쓰고 일반 줄을 비워 둘째 판독까지 닿게 합니다 -
# 영어 엔진이 없는 PC 의 대체 경로가 아니라 Find-GameTextPoint 의 1차 규칙(대소문자 무시 완전 일치)을 실측 낱말로 고정하는 행입니다. 캡처 실패 행의 이진화 줄은 'ESC' 를 담아
# 둘째 판독이 실제로 돌면 점이 나오게 해 둡니다
$readRows = @(
  @{ Id = '일반 성공 f2'; Width = 1908; Height = 1076; Normal = "'Home'@(238,50,138x42) 'End'@(761,51,84x41) 'ESC'@(1090,49,89x43)"
    Binary = "'Home'@(239,52,136x40) 'Y'@(541,52,27x40) 'End'@(761,52,83x40) 'ESC'@(1091,52,86x40)"; Expected = '1653,111 글자 탐색 / 모드 normal / 엔진 en / 플래그 False / 일련번호 0'; Note = '둘째 판독 0회' },
  @{ Id = '일반 성공 g10'; Width = 1914; Height = 1079; Normal = "'Home'@(254,93,135x43) 'ESC'@(1092,92,88x43)"
    Binary = "'Home'@(255,95,132x40) 'End'@(769,95,80x40) 'ESC'@(1095,95,83x40)"; Expected = '1659,124 글자 탐색 / 모드 normal / 엔진 en / 플래그 False / 일련번호 0'; Note = '1914x1079' },
  @{ Id = '이진화 구제 f1'; Width = 1908; Height = 1076; Normal = ''
    Binary = "'Home'@(240,40,137x44) 'Y'@(543,48,28x41) 'End'@(762,55,85x42) 'ESC'@(1092,64,87x43)"; Expected = '1653,116 글자 탐색 이진화 / 모드 normal,bin / 엔진 en,ko / 플래그 False / 일련번호 0'; Note = '이름표로 일반 판독이 빈 문자열' },
  @{ Id = '이진화 구제 b4'; Width = 1270; Height = 702; Normal = "'Home'@(370,124,147x48) 'End'@(662,124,92x48)"
    Binary = "'Home'@(373,125,140x46) 'End'@(663,125,90x46) 'ESC'@(1013,125,95x46)"; Expected = '1086,88 글자 탐색 이진화 / 모드 normal,bin / 엔진 en,ko / 플래그 False / 일련번호 0'; Note = '1270 필드 - 일반은 ESC 만 놓침' },
  @{ Id = '이진화 구제 b1'; Width = 1273; Height = 718; Normal = ''
    Binary = "'HO(""II言'@(86,143,141x45) 'E11d'@(645,162,87x44) 'ESC'@(1000,175,92x43)"; Expected = '1085,99 글자 탐색 이진화 / 모드 normal,bin / 엔진 en,ko / 플래그 False / 일련번호 0'; Note = '1273 필드 - 타 PC 글자 흐림' },
  @{ Id = '둘 다 실패 g_085904'; Width = 1908; Height = 1076; Normal = "'Home'@(238,50,138x42) 'End'@(761,51,84x41)"
    Binary = "'Home'@(239,52,136x40) 'Y'@(541,52,27x40) 'End'@(761,52,83x40)"; Expected = '없음 / 모드 normal,bin / 엔진 en,ko / 플래그 False / 일련번호 0'; Note = '커서가 ESC 글자에 겹침' },
  @{ Id = '일반 캡처 실패'; Width = 1908; Height = 1076; Normal = ''; Binary = "'ESC'@(1091,52,86x40)"; FailModes = @('normal')
    Expected = '없음 / 모드 normal / 엔진 - / 플래그 True / 일련번호 1'; Note = "둘째 판독 0회 - '못 찾음' 이 아님 (규칙 15)" },
  @{ Id = '둘째 캡처 실패'; Width = 1908; Height = 1076; Normal = ''; Binary = "'ESC'@(1091,52,86x40)"; FailModes = @('bin')
    Expected = '없음 / 모드 normal,bin / 엔진 en / 플래그 True / 일련번호 1'; Note = '호출부 가드가 그 회전을 끊음' },
  @{ Id = "실측 판독문 'Esc' a1"; Width = 1272; Height = 717; Normal = ''; Binary = "'Home'@(343,123,145x45) 'Esc'@(998,123,95x45)"
    Expected = '1084,89 글자 탐색 이진화 / 모드 normal,bin / 엔진 en,ko / 플래그 False / 일련번호 0'; Note = '1272 이진화/영어 낱말' },
  @{ Id = "실측 판독문 'esc' b3"; Width = 1315; Height = 741; Normal = ''; Binary = "'Honie'@(337,119,150x43) 'esc'@(999,119,92x43)"
    Expected = '1121,91 글자 탐색 이진화 / 모드 normal,bin / 엔진 en,ko / 플래그 False / 일련번호 0'; Note = '1315 이진화/영어 낱말' }
)
foreach ($readRow in $readRows) {
  # 행 사이에 플래그 · 일련번호 · 기록을 되돌립니다 - 앞 행의 캡처 실패가 다음 행의 둘째 판독을 막으면 안 됩니다
  $script:screenCaptureFailing = $false; $script:captureFailSerial = 0
  $script:captureModes.Clear(); $script:ocrEngines.Clear(); $script:lastCaptureMode = ''
  $script:mockWindowWidth = $readRow.Width; $script:mockWindowHeight = $readRow.Height
  $script:mockFailModes = $(if ($readRow.ContainsKey('FailModes')) { $readRow.FailModes } else { @() })
  $script:mockWordLines = @{ normal = (ConvertTo-MockLine $readRow.Normal); bin = (ConvertTo-MockLine $readRow.Binary) }
  $mockRead = Find-AbyssEscButtonPoint -Game $null
  $engineText = $(if ($script:ocrEngines.Count -gt 0) { $script:ocrEngines -join ',' } else { '-' })
  Check-Equal ('§2 탐색 {0} ({1})' -f $readRow.Id, $readRow.Note) `
    ('{0} / 모드 {1} / 엔진 {2} / 플래그 {3} / 일련번호 {4}' -f (Format-EscRead $mockRead), ($script:captureModes -join ','), $engineText, $script:screenCaptureFailing, $script:captureFailSerial) $readRow.Expected
}
$script:screenCaptureFailing = $false; $script:captureFailSerial = 0; $script:mockFailModes = @()

# 고정점 고르기 표 - 너비는 리터럴, 점은 소스 캡처입니다
$smallPointText = '{0},{1}' -f $ptEscButton[0], $ptEscButton[1]
$largePointText = '{0},{1}' -f $ptEscButtonLarge[0], $ptEscButtonLarge[1]
function Format-FallbackPoint { param($Selected) return ('{0},{1}/{2}' -f $Selected.X, $Selected.Y, $Selected.Large) }
foreach ($smallWidth in @(1270, 1272, 1273, 1276, 1315, 1368, 1589)) {
  foreach ($largeTurn in @(0, 1)) {
    Check-Equal ('§2 고르기 너비 {0} · 순번 {1} → 작은 창 점 · Large 거짓' -f $smallWidth, $largeTurn) (Format-FallbackPoint (Select-AbyssEscFallbackPoint -WindowWidth $smallWidth -LargeTurn $largeTurn)) "$smallPointText/False"
  }
}
foreach ($largeWidth in @(1590, 1908, 1914)) {
  Check-Equal ('§2 고르기 너비 {0} · 순번 0 → 큰 창 새 점 · Large 참' -f $largeWidth) (Format-FallbackPoint (Select-AbyssEscFallbackPoint -WindowWidth $largeWidth -LargeTurn 0)) "$largePointText/True"
  Check-Equal ('§2 고르기 너비 {0} · 순번 1 → 옛 점 · Large 참 (1908 스트레치 배치)' -f $largeWidth) (Format-FallbackPoint (Select-AbyssEscFallbackPoint -WindowWidth $largeWidth -LargeTurn 1)) "$smallPointText/True"
  Check-Equal ('§2 고르기 너비 {0} · 순번 2 → 큰 창 새 점 · Large 참 (번갈아)' -f $largeWidth) (Format-FallbackPoint (Select-AbyssEscFallbackPoint -WindowWidth $largeWidth -LargeTurn 2)) "$largePointText/True"
}

# 창 좌표를 읽는 두 함수를 돌리는 가짜 형 - 시작 Add-Type 은 user32 를 부르므로 같은 이름 · 같은 서명의 형을 씁니다 (RECT 중첩 · GetWindowRect · IsIconic)
Add-Type -TypeDefinition @'
using System;
public static class HoneyNogiInput {
  public struct RECT { public int Left, Top, Right, Bottom; }
  public static bool RectReadable = true;
  public static int WindowLeft, WindowTop, WindowWidth, WindowHeight;
  public static bool GetWindowRect(IntPtr hWnd, out RECT rect) {
    rect = new RECT();
    if (!RectReadable) { return false; }
    rect.Left = WindowLeft; rect.Top = WindowTop; rect.Right = WindowLeft + WindowWidth; rect.Bottom = WindowTop + WindowHeight;
    return true;
  }
  public static bool IsIconic(IntPtr hWnd) { return false; }
}
'@
$fakeGame = [System.Diagnostics.Process]::GetCurrentProcess()
function Set-FakeWindow {
  param([int]$Left, [int]$Top, [int]$Width, [int]$Height)
  [HoneyNogiInput]::WindowLeft = $Left; [HoneyNogiInput]::WindowTop = $Top; [HoneyNogiInput]::WindowWidth = $Width; [HoneyNogiInput]::WindowHeight = $Height
}

# 워커 캡처 본문 그대로 - 화면 취득 한 줄만 그림의 같은 자리를 옮기는 것으로 바꿉니다 (§1 재생 전제). 창 크기 · 원점은 위 가짜 형이 줍니다.
# 재생 그림은 빈 화면이 아니고 캡처는 늘 성공하므로 화면 상태를 보는 둘만 모의입니다 (실패 등록 경로는 닿지 않습니다)
function Test-BlankCapture { param($Bitmap) return $false }
function Register-CaptureSuccess { $script:screenCaptureFailing = $false }
$script:replayWindow = $null
function Copy-ReplayRegion {
  # 1:1 복사 - 크기를 바꾸지 않고 보간 · 합성이 섞이지 않게 둡니다. 이 Graphics 는 워커에서 화면 취득에만 쓰여 뒤의 확대에 닿지 않습니다
  param($Graphics, [int]$Left, [int]$Top, [int]$Width, [int]$Height)
  $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $Graphics.DrawImage($script:replayWindow, (New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)), (New-Object System.Drawing.Rectangle($Left, $Top, $Width, $Height)), [System.Drawing.GraphicsUnit]::Pixel)
}
Invoke-Expression ($captureSource.Replace($captureHead, 'function Invoke-WorkerRegionCapture {').Replace($screenCopyLine, 'Copy-ReplayRegion -Graphics $sourceGraphics -Left $cropLeft -Top $cropTop -Width $cropWidth -Height $cropHeight'))
function Format-CaptureCrop { param($Capture) return ('{0},{1},{2}x{3}' -f $Capture.CropLeft, $Capture.CropTop, $Capture.CropWidth, $Capture.CropHeight) }

# 판독결과의 crop 값 - 워커 본문이 그 기록을 내고, §2 스텁 산식도 같은 값을 내는지 봅니다 (스텁은 좌표 환산의 입력만 만듭니다)
foreach ($cropRow in @(
    @{ Width = 1908; Height = 1076; Crop = '1312,90,398x83' }, @{ Width = 1914; Height = 1079; Crop = '1317,90,399x83' }, @{ Width = 1272; Height = 717; Crop = '875,60,265x55' },
    @{ Width = 1273; Height = 718; Crop = '876,60,265x55' }, @{ Width = 1315; Height = 741; Crop = '905,62,274x57' }, @{ Width = 1270; Height = 702; Crop = '874,59,265x54' },
    @{ Width = 1276; Height = 719; Crop = '878,60,266x55' })) {
  Set-FakeWindow -Left 0 -Top 0 -Width $cropRow.Width -Height $cropRow.Height
  $script:mockWindowWidth = $cropRow.Width; $script:mockWindowHeight = $cropRow.Height
  $script:replayWindow = New-Object System.Drawing.Bitmap $cropRow.Width, $cropRow.Height
  try {
    $cropArguments = @{ ReferenceX = $rgHomeEndEsc[0]; ReferenceY = $rgHomeEndEsc[1]; RegionWidth = $rgHomeEndEsc[2]; RegionHeight = $rgHomeEndEsc[3]; Scale = 5 }
    $workerCrop = Invoke-WorkerRegionCapture -Game $fakeGame @cropArguments
    $stubCrop = Get-GameRegionCapture -Game $null @cropArguments
    Check-Equal ('§2 판독 영역 {0}x{1} = 판독결과 crop (워커 본문 · 스텁)' -f $cropRow.Width, $cropRow.Height) ('{0} / {1}' -f (Format-CaptureCrop $workerCrop), (Format-CaptureCrop $stubCrop)) ('{0} / {0}' -f $cropRow.Crop)
    $workerCrop.Bitmap.Dispose(); $stubCrop.Bitmap.Dispose()
  } finally { $script:replayWindow.Dispose(); $script:replayWindow = $null }
}

# 실측 라벨 상자 (창 픽셀, 테두리 바깥 끝). S 는 1272 상자의 1.5배 환산이고 나머지는 그림에서 잰 값입니다
$labelBoxes = @{
  A = @{ Left = 1070; Top = 81; Right = 1098; Bottom = 98; Name = '1272x717 창 DPI 96' }
  B = @{ Left = 1633; Top = 100; Right = 1671; Bottom = 123; Name = '1908x1076 창 DPI 96' }
  C = @{ Left = 1635; Top = 113; Right = 1672; Bottom = 135; Name = '1908x1076 창 DPI 144' }
  D = @{ Left = 1640; Top = 113; Right = 1678; Bottom = 136; Name = '1914x1079 창 DPI 144' }
  E = @{ Left = 1075; Top = 94; Right = 1102; Bottom = 110; Name = '1276x719 창 DPI 144' }
  F = @{ Left = 1072; Top = 80; Right = 1099; Bottom = 96; Name = '1270x702' }
  G = @{ Left = 1636; Top = 114; Right = 1674; Bottom = 137; Name = '1914x1093' }
  H1 = @{ Left = 1072; Top = 88; Right = 1099; Bottom = 104; Name = '1273x718 타 PC' }
  H2 = @{ Left = 1106; Top = 83; Right = 1135; Bottom = 100; Name = '1315x741' }
  S = @{ Left = 1605; Top = 121.5; Right = 1647; Bottom = 147; Name = '1908 스트레치 (1272 렌더 1.5배)' }
}
function Test-PointInBox {
  param($X, $Y, [hashtable]$Box)
  return (($X -ge $Box.Left) -and ($X -le $Box.Right) -and ($Y -ge $Box.Top) -and ($Y -le $Box.Bottom))
}
function Format-PlacedPoint {
  # 기준 좌표를 창 크기로 환산한 점(운영 Get-ScaledScreenPoint)과 그 상자 안팎 - '위끝' 은 윗 테두리 1px 안입니다
  param([int]$Width, [int]$Height, [int]$ReferenceX, [int]$ReferenceY, [hashtable]$Box)
  Set-FakeWindow -Left 0 -Top 0 -Width $Width -Height $Height
  $placedPoint = Get-ScaledScreenPoint -Game $fakeGame -ReferenceX $ReferenceX -ReferenceY $ReferenceY
  $placedWhere = $(if (-not (Test-PointInBox $placedPoint.X $placedPoint.Y $Box)) { '밖' } elseif (($placedPoint.Y - $Box.Top) -le 1) { '위끝' } else { '안' })
  return ('{0},{1} {2}' -f $placedPoint.X, $placedPoint.Y, $placedWhere)
}
foreach ($placementRow in @(
    @{ Box = 'A'; Width = 1272; Height = 717; Turn = 0; Expected = '1083,89 안'; Note = '글자 중심에서 1px' },
    @{ Box = 'F'; Width = 1270; Height = 702; Turn = 0; Expected = '1081,87 안'; Note = '' },
    @{ Box = 'H2'; Width = 1315; Height = 741; Turn = 0; Expected = '1120,92 안'; Note = '' },
    @{ Box = 'H1'; Width = 1273; Height = 718; Turn = 0; Expected = '1084,89 위끝'; Note = '윗 테두리 1px 안' },
    @{ Box = 'E'; Width = 1276; Height = 719; Turn = 0; Expected = '1086,89 밖'; Note = '상자 밖 · 지금과 같음 - 상자보다 5px 위 아이콘 원, 눌러서 열리는지 기록 없음' },
    @{ Box = 'B'; Width = 1908; Height = 1076; Turn = 0; Expected = '1653,117 안'; Note = '' },
    @{ Box = 'C'; Width = 1908; Height = 1076; Turn = 0; Expected = '1653,117 안'; Note = '' },
    @{ Box = 'D'; Width = 1914; Height = 1079; Turn = 0; Expected = '1658,117 안'; Note = '' },
    @{ Box = 'G'; Width = 1914; Height = 1093; Turn = 0; Expected = '1658,119 안'; Note = '' },
    @{ Box = 'S'; Width = 1908; Height = 1076; Turn = 1; Expected = '1624,134 안'; Note = '번갈아 누르는 이유 - 옛 점이 글자 위' },
    @{ Box = 'S'; Width = 1908; Height = 1076; Turn = 0; Expected = '1653,117 밖'; Note = '새 점은 이 배치에서 라벨 밖' })) {
  $placedBox = $labelBoxes[$placementRow.Box]
  $selectedPoint = Select-AbyssEscFallbackPoint -WindowWidth $placementRow.Width -LargeTurn $placementRow.Turn
  Check-Equal ('§2 고른 점의 라벨 상자 {0} · 순번 {1} {2}' -f $placedBox.Name, $placementRow.Turn, $placementRow.Note) `
    (Format-PlacedPoint -Width $placementRow.Width -Height $placementRow.Height -ReferenceX $selectedPoint.X -ReferenceY $selectedPoint.Y -Box $placedBox) $placementRow.Expected
}
# 고치기 전 재현 (사고의 뒤 절반): 글자를 못 찾으면 늘 누르던 옛 고정점은 네이티브 큰 창 네 배치에서 라벨 밖입니다 - 새 점은 위 표에서 네 배치 모두 안입니다
foreach ($oldPointRow in @(
    @{ Box = 'B'; Width = 1908; Height = 1076; Expected = '1624,134 밖' }, @{ Box = 'C'; Width = 1908; Height = 1076; Expected = '1624,134 밖' },
    @{ Box = 'D'; Width = 1914; Height = 1079; Expected = '1630,134 밖' }, @{ Box = 'G'; Width = 1914; Height = 1093; Expected = '1630,136 밖' })) {
  $oldBox = $labelBoxes[$oldPointRow.Box]
  Check-Equal ('§2 고치기 전 재현: 옛 고정점의 라벨 상자 {0}' -f $oldBox.Name) `
    (Format-PlacedPoint -Width $oldPointRow.Width -Height $oldPointRow.Height -ReferenceX $ptEscButton[0] -ReferenceY $ptEscButton[1] -Box $oldBox) $oldPointRow.Expected
}

# 실제 창 크기로 고르는 실행 행 - 창 원점을 실측값으로 둡니다 (너비가 아니라 오른쪽 끝을 재면 1272 창도 큰 창이 됩니다). 높이로 재면 1908 창이 작은 창이 됩니다
foreach ($fallbackRow in @(
    @{ Left = 971; Top = 0; Width = 1908; Height = 1076; Turn = 0; Expected = "$largePointText/True"; Note = '1908x1076@(971,0) → 큰 점' },
    @{ Left = 971; Top = 0; Width = 1908; Height = 1076; Turn = 1; Expected = "$smallPointText/True"; Note = '1908x1076@(971,0) 순번 1 → 옛 점' },
    @{ Left = 646; Top = 2; Width = 1272; Height = 717; Turn = 0; Expected = "$smallPointText/False"; Note = '1272x717@(646,2) → 작은 점' },
    @{ Left = 642; Top = 5; Width = 1276; Height = 719; Turn = 1; Expected = "$smallPointText/False"; Note = '1276x719@(642,5) RDP 끊김으로 줄어든 창 → 작은 점 · 순번 무관' })) {
  Set-FakeWindow -Left $fallbackRow.Left -Top $fallbackRow.Top -Width $fallbackRow.Width -Height $fallbackRow.Height
  Check-Equal ('§2 실제 창 크기 {0}' -f $fallbackRow.Note) (Format-FallbackPoint (Get-AbyssEscFallbackPoint -Game $fakeGame -LargeTurn $fallbackRow.Turn)) $fallbackRow.Expected
}
[HoneyNogiInput]::RectReadable = $false
$rectError = ''
try { [void](Get-AbyssEscFallbackPoint -Game $fakeGame -LargeTurn 0) } catch { $rectError = $_.Exception.Message } finally { [HoneyNogiInput]::RectReadable = $true }
Check-Equal '§2 실제 창 크기: 창 좌표를 못 읽으면 너비를 짐작하지 않고 던짐 (Get-ScaledScreenPoint 와 같은 사유)' $rectError '게임 창 좌표를 읽지 못했습니다.'

# ── §3. 그림 재생 ──
# 기대값은 재현 폴더 판독결과_이진화엔진비교.txt (37장의 일반/영어 · 이진화/한국어 클릭 자리)와 판독결과_1·3·5·6·7·8·9 (HUD 판독문). 그림은 재현 폴더 원본표.md 의 경로입니다.
# Kind: normal 일반 판독이 찾음 / rescue 이진화가 구제 / none HUD 는 참인데 둘 다 못 찾음 / nohud HUD 거짓 - ESC 분기에 오지 않음. HudBinary: 일반 판독에 HUD 낱말이 없어 이진화로 판정
$reproDir = '어비스\20261103_필드ESC미감지_재현'
$sourceDir = "$reproDir\원본"
$variantDir = "$reproDir\변형그림"
$sceneDir = '어비스\20261026_⑤_다시하기\2차\1-D'
$consoleDir = '어비스\20261008_메뉴아이콘_실기3_콘솔전환\frames'
$replayRows = @(
  [pscustomobject]@{ Id = 'f1'; Rel = "$sceneDir\esc_121538.png"; Box = 'B'; Kind = 'rescue'; Point = '1653,116'; HudBinary = $true; OldWhere = '밖'; Note = '1-D′a 실패 도중 필드 - 이름표 + 고정점 자리 커서' }
  [pscustomobject]@{ Id = 'f2'; Rel = "$sceneDir\stuck_131218.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '던전 안 HUD - 판독 영역 깨끗' }
  [pscustomobject]@{ Id = 'f3'; Rel = '던전\20260813_ESC버튼이탈_네이티브1908_필드HUD.png'; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '08-13 고정점 전용 실패 필드 - 커서 고정점 자리' }
  [pscustomobject]@{ Id = 'f4'; Rel = "$sourceDir\cap_121450_616_00042_abyssResult-space.png"; Box = ''; Kind = 'nohud'; Point = ''; HudBinary = $true; Note = '로딩 - HUD 없음' }
  [pscustomobject]@{ Id = 'f5'; Rel = "$sourceDir\cap_121433_543_00041_abyssResult.png"; Box = ''; Kind = 'nohud'; Point = ''; HudBinary = $true; Note = '보상 화면 - HUD 없음' }
  [pscustomobject]@{ Id = 'g1'; Rel = "$sourceDir\cap_171652_060_00013_dialog.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '1908 필드 - 판독 영역 깨끗' }
  [pscustomobject]@{ Id = 'g2'; Rel = "$sourceDir\cap_093949_875_00001_start.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '1908 필드 - 이름표가 있어도 일반이 읽음' }
  [pscustomobject]@{ Id = 'g3'; Rel = "$sourceDir\cap_133531_764_00001_start.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '1908 필드 - 판독 영역 깨끗' }
  [pscustomobject]@{ Id = 'g4'; Rel = "$sourceDir\cap_094330_748_00001_start.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '1908 필드 - 이름표가 있어도 일반이 읽음' }
  [pscustomobject]@{ Id = 'g9'; Rel = '어비스\20261001_⑥e_실기\frames\cap_110251_020_1908x1076.png'; Box = 'C'; Kind = 'normal'; Point = '1654,124'; HudBinary = $false; Note = '창 DPI 144 - 라벨 13px 아래' }
  [pscustomobject]@{ Id = 'g10'; Rel = '어비스\20261008_메뉴아이콘_실기3_2차\frames\cap_091201_884_1914x1079.png'; Box = 'D'; Kind = 'normal'; Point = '1659,124'; HudBinary = $false; Note = '1914x1079 창 DPI 144' }
  [pscustomobject]@{ Id = 'g_085900'; Rel = "$consoleDir\cap_085900_945_1908x1076.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '10-08 클릭 전 - 깨끗' }
  [pscustomobject]@{ Id = 'g_085902'; Rel = "$consoleDir\cap_085902_039_1908x1076.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '10-08 클릭 전 - 깨끗' }
  [pscustomobject]@{ Id = 'g_085903'; Rel = "$consoleDir\cap_085903_137_1908x1076.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '10-08 클릭 전 - 깨끗' }
  [pscustomobject]@{ Id = 'g_085904'; Rel = "$consoleDir\cap_085904_258_1908x1076.png"; Box = ''; Kind = 'none'; Point = ''; HudBinary = $false; Note = '클릭 직후 - 커서가 ESC 글자에 겹침' }
  [pscustomobject]@{ Id = 'g_085905'; Rel = "$consoleDir\cap_085905_350_1908x1076.png"; Box = ''; Kind = 'none'; Point = ''; HudBinary = $false; Note = '메뉴 열리는 중' }
  [pscustomobject]@{ Id = 'g_090205'; Rel = "$consoleDir\cap_090205_228_1908x1076.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '이름표가 있어도 일반이 읽음' }
  [pscustomobject]@{ Id = 'g_090206'; Rel = "$consoleDir\cap_090206_321_1908x1076.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '클릭 직후 커서 끝이 글자 바로 아래 + 이름표 - 이진화 단독이면 놓침' }
  [pscustomobject]@{ Id = 'v_f2_plus_cursor'; Rel = "$variantDir\v_f2_plus_cursor.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = 'f2 + f1 커서 합성' }
  [pscustomobject]@{ Id = 'v_f2_plus_name'; Rel = "$variantDir\v_f2_plus_name.png"; Box = 'B'; Kind = 'rescue'; Point = '1653,112'; HudBinary = $true; OldWhere = '밖'; Note = 'f2 + f1 이름표 합성 - 이름표 하나로 일반 판독이 깨짐' }
  [pscustomobject]@{ Id = 'v_f2_plus_both'; Rel = "$variantDir\v_f2_plus_both.png"; Box = 'B'; Kind = 'rescue'; Point = '1653,116'; HudBinary = $true; OldWhere = '밖'; Note = 'f2 + f1 커서 · 이름표 합성' }
  [pscustomobject]@{ Id = 'v_f1_minus_cursor'; Rel = "$variantDir\v_f1_minus_cursor.png"; Box = 'B'; Kind = 'rescue'; Point = '1653,112'; HudBinary = $true; OldWhere = '밖'; Note = 'f1 에서 커서를 지운 변형 - 이름표는 남음' }
  [pscustomobject]@{ Id = 'v_f1_minus_name'; Rel = "$variantDir\v_f1_minus_name.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = 'f1 에서 이름표 밝은 채움을 지운 변형 - 어두운 외곽선이 남음' }
  [pscustomobject]@{ Id = 'v_f1_minus_both'; Rel = "$variantDir\v_f1_minus_both.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = 'f1 에서 커서 · 이름표 밝은 채움을 지운 변형 - 어두운 외곽선이 남음' }
  [pscustomobject]@{ Id = 'v2_clean_cursor_on_esc'; Rel = "$variantDir\v2_clean_cursor_on_esc.png"; Box = ''; Kind = 'none'; Point = ''; HudBinary = $false; Note = '커서를 ESC 글자 위로 옮긴 합성' }
  [pscustomobject]@{ Id = 'v2_name_cursor_on_esc'; Rel = "$variantDir\v2_name_cursor_on_esc.png"; Box = ''; Kind = 'none'; Point = ''; HudBinary = $true; Note = '이름표 + 커서를 ESC 글자 위로 옮긴 합성' }
  [pscustomobject]@{ Id = 'v2_clean_cursor_on_end'; Rel = "$variantDir\v2_clean_cursor_on_end.png"; Box = 'B'; Kind = 'normal'; Point = '1653,111'; HudBinary = $false; Note = '커서를 End 글자 위로 옮긴 합성' }
  [pscustomobject]@{ Id = 'v2_name_cursor_fixedpoint_p8'; Rel = "$variantDir\v2_name_cursor_fixedpoint_p8.png"; Box = 'B'; Kind = 'rescue'; Point = '1653,112'; HudBinary = $true; OldWhere = '밖'; Note = '이름표 + 커서를 고정점 +8px 로 옮긴 합성' }
  [pscustomobject]@{ Id = 'a1'; Rel = '어비스\20260925_사망화면_던전퇴장_수동조작_흐름\03_필드_이멘마하_HUD_추적기주간목표.png'; Box = 'A'; Kind = 'normal'; Point = '1084,89'; HudBinary = $false; Note = '1272 필드' }
  [pscustomobject]@{ Id = 'a2'; Rel = '어비스\20261014_②_이어받기\신버전_②\14_R6-1_2\error_20261015_h23m28s41.png'; Box = 'A'; Kind = 'normal'; Point = '1084,94'; HudBinary = $false; Note = '1272 필드' }
  [pscustomobject]@{ Id = 'a3'; Rel = '어비스\20261014_②_이어받기\기준선_①\06_B-1f_R6-1\error_20261015_h00m00s25.png'; Box = 'A'; Kind = 'normal'; Point = '1084,89'; HudBinary = $false; Note = '1272 필드' }
  [pscustomobject]@{ Id = 'a4'; Rel = "$sourceDir\cap_192447_876_00001_start.png"; Box = 'A'; Kind = 'normal'; Point = '1084,89'; HudBinary = $false; Note = '1272 필드' }
  [pscustomobject]@{ Id = 'b1'; Rel = '생활\1273캡처\report_1273_field_error_20260809_h02m32s16.png'; Box = 'H1'; Kind = 'rescue'; Point = '1085,99'; HudBinary = $true; OldWhere = '위끝'; Note = '1273 필드 - 타 PC 글자 흐림' }
  [pscustomobject]@{ Id = 'b2'; Rel = '사망부활\3_무제한형_심층_중앙전파괴_제보건.png'; Box = 'H1'; Kind = 'normal'; Point = '1086,96'; HudBinary = $false; Note = '1273 사망 화면' }
  [pscustomobject]@{ Id = 'b3'; Rel = '사망부활\6_전멸_여신상버튼.png'; Box = 'H2'; Kind = 'normal'; Point = '1121,91'; HudBinary = $false; Note = '1315 전멸 화면' }
  [pscustomobject]@{ Id = 'b4'; Rel = "$sourceDir\cap_194850_190_00001_start.png"; Box = 'F'; Kind = 'rescue'; Point = '1086,88'; HudBinary = $false; OldWhere = '안'; Note = '1270 필드 - 커서 없이 일반이 ESC 만 놓침' }
  [pscustomobject]@{ Id = 'b5'; Rel = '어비스\20261008_메뉴아이콘_실기3_2차\worker_logs\error_20261008_h09m17s58.png'; Box = 'E'; Kind = 'normal'; Point = '1089,102'; HudBinary = $false; Note = '1276 던전 안' }
)
Check-Equal '§3 목록: 37장 (재현 28 + 작은 창 a1~a4 · b1~b5)' ('{0} = {1} + {2}' -f $replayRows.Count, @($replayRows | Where-Object { $_.Id -notmatch '^[ab]\d$' }).Count, @($replayRows | Where-Object { $_.Id -match '^[ab]\d$' }).Count) '37 = 28 + 9'
$imageRoot = Join-Path $root '던전이미지'
if (-not (Test-Path -LiteralPath $imageRoot)) {
  "SKIP §3 그림 재생: 던전이미지 폴더가 없어 건너뜁니다 (로컬 전용 - 개발 PC 외): $imageRoot"
} else {
  # 루트가 있는데 목록 파일이 없으면 SKIP 이 아니라 FAIL - 파일 하나 이동이 핵심 재현을 조용히 끄지 않게 (러너 머리 2026-10-07 SKIP 규칙)
  foreach ($listedRow in $replayRows) {
    if (-not (Test-Path -LiteralPath (Join-Path $imageRoot $listedRow.Rel))) {
      "FAIL §3 목록 파일 없음 ($($listedRow.Id)): 던전이미지\$($listedRow.Rel) - 폴더를 옮겼다면 이 테스트의 경로도 함께 고칠 것"
      $fails++
    }
  }
  $ocrKoreanEngine = $null; $ocrEnglishEngine = $null
  $ocrUnavailableReason = ''
  try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
    [Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null
    [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
    $asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
      Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } |
      Select-Object -First 1
    $ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('ko')))
    $ocrEnglishEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('en-US')))
  } catch {
    $ocrUnavailableReason = $_.Exception.Message
  }
  if ((-not $ocrKoreanEngine) -or (-not $ocrEnglishEngine)) {
    "SKIP §3 그림 재생: en-US · ko OCR 엔진을 만들 수 없어 건너뜁니다 (언어 팩 없음) $ocrUnavailableReason"
  } else {
    $replayStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($functionName in @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Find-GameTextPoint', 'Find-AbyssEscButtonPoint', 'Test-HomeEndEscHud', 'Get-GameRegionOcrText')) {
      Invoke-Expression (Get-WorkerFunctionText $functionName)
    }
    # 캡처 입구만 감쌉니다 - 호출 모드를 기록하고 워커 본문(위 Invoke-WorkerRegionCapture)을 그대로 부릅니다. 창 원점이 0,0 이라 화면 좌표 = 이미지 px 입니다.
    # 이진화 시작 시각을 남겨 판독 1회 소요를 잽니다 - 둘째 판독은 탐색 함수의 마지막 일이라 반환까지가 그 판독입니다
    $script:binaryReadWatch = $null
    function Get-GameRegionCapture {
      param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3,
        [switch]$BinaryWhiteText, [switch]$ThrowOnWindowRectFailure)
      $script:captureModes.Add($(if ($BinaryWhiteText) { 'bin' } else { 'normal' }))
      if ($BinaryWhiteText) { $script:binaryReadWatch = [System.Diagnostics.Stopwatch]::StartNew() }
      return (Invoke-WorkerRegionCapture -Game $Game -ReferenceX $ReferenceX -ReferenceY $ReferenceY -RegionWidth $RegionWidth -RegionHeight $RegionHeight -Scale $Scale `
          -BinaryWhiteText:$BinaryWhiteText -ThrowOnWindowRectFailure:$ThrowOnWindowRectFailure)
    }
    function Open-ReplayWindow {
      # 그림을 화면 대신 올립니다 - 창 크기 = 그림 크기, 창 원점 0,0
      param([string]$Path)
      $script:replayWindow = New-Object System.Drawing.Bitmap($Path)
      Set-FakeWindow -Left 0 -Top 0 -Width $script:replayWindow.Width -Height $script:replayWindow.Height
    }
    function Find-EscByOneRead {
      # 한 판독만으로 찾기 - 탐색 함수의 두 호출과 같은 인자 (고치기 전 재현 · 순서 · 엔진 근거 행)
      param($Engine, [switch]$Binary)
      return (Find-GameTextPoint -Game $fakeGame -ReferenceX $rgHomeEndEsc[0] -ReferenceY $rgHomeEndEsc[1] -RegionWidth $rgHomeEndEsc[2] -RegionHeight $rgHomeEndEsc[3] `
          -SearchText 'ESC' -ExactText 'ESC' -Scale 5 -Engine $Engine -BinaryWhiteText:$Binary)
    }
    function Format-OneRead { param($Point) return $(if ($Point) { '{0},{1}' -f $Point.X, $Point.Y } else { '없음' }) }

    # 첫 OCR 준비 시간을 재기 전에 씁니다 - 두 엔진 · 두 모드를 한 번씩
    $warmupRow = @($replayRows | Where-Object { Test-Path -LiteralPath (Join-Path $imageRoot $_.Rel) })[0]
    Open-ReplayWindow (Join-Path $imageRoot $warmupRow.Rel)
    try {
      [void](Find-EscByOneRead -Engine $ocrEnglishEngine)
      [void](Find-EscByOneRead -Engine $ocrKoreanEngine -Binary)
    } finally { $script:replayWindow.Dispose(); $script:replayWindow = $null }

    # 재생 전제: 화면 취득 자리의 1:1 복사가 그림을 바꾸지 않습니다 - f1 판독 영역 전체를 Bitmap.Clone 과 픽셀로 대조합니다
    $fidelityRow = $replayRows | Where-Object { $_.Id -eq 'f1' } | Select-Object -First 1
    $fidelityPath = Join-Path $imageRoot $fidelityRow.Rel
    if (Test-Path -LiteralPath $fidelityPath) {
      Open-ReplayWindow $fidelityPath
      $expectedRegion = $script:replayWindow.Clone((New-Object System.Drawing.Rectangle(1312, 90, 398, 83)), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
      $copiedRegion = New-Object System.Drawing.Bitmap 398, 83
      $copiedGraphics = [System.Drawing.Graphics]::FromImage($copiedRegion)
      try {
        Copy-ReplayRegion -Graphics $copiedGraphics -Left 1312 -Top 90 -Width 398 -Height 83
        $differentPixels = 0
        for ($pixelY = 0; $pixelY -lt 83; $pixelY++) {
          for ($pixelX = 0; $pixelX -lt 398; $pixelX++) {
            if ($expectedRegion.GetPixel($pixelX, $pixelY).ToArgb() -ne $copiedRegion.GetPixel($pixelX, $pixelY).ToArgb()) { $differentPixels++ }
          }
        }
        Check-Equal '§3 재생 전제: 화면 취득 자리의 1:1 복사 = 그림 픽셀 그대로 (f1 판독 영역 398x83, 다른 픽셀 수)' $differentPixels 0
      } finally { $copiedGraphics.Dispose(); $copiedRegion.Dispose(); $expectedRegion.Dispose(); $script:replayWindow.Dispose(); $script:replayWindow = $null }
    }

    $replayCounts = @{ normal = 0; rescue = 0; none = 0; nohud = 0 }
    $binaryMs = New-Object 'System.Collections.Generic.List[double]'
    $binaryMaxId = ''
    foreach ($replayRow in $replayRows) {
      $replayPath = Join-Path $imageRoot $replayRow.Rel
      if (-not (Test-Path -LiteralPath $replayPath)) { continue }
      Open-ReplayWindow $replayPath
      try {
        $script:captureModes.Clear()
        $hudVisible = Test-HomeEndEscHud -Game $fakeGame
        $hudModes = $script:captureModes -join ','
        $script:captureModes.Clear()
        $script:binaryReadWatch = $null
        $replayRead = Find-AbyssEscButtonPoint -Game $fakeGame
        if ($script:binaryReadWatch) {
          $script:binaryReadWatch.Stop()
          if (($binaryMs.Count -eq 0) -or ($script:binaryReadWatch.Elapsed.TotalMilliseconds -gt (($binaryMs | Measure-Object -Maximum).Maximum))) { $binaryMaxId = $replayRow.Id }
          $binaryMs.Add($script:binaryReadWatch.Elapsed.TotalMilliseconds)
        }
        $searchModes = $script:captureModes -join ','
        $replayPointText = Format-EscRead $replayRead
        $boxText = ''
        if ($replayRead.Point -and $replayRow.Box) { $boxText = $(if (Test-PointInBox $replayRead.Point.X $replayRead.Point.Y $labelBoxes[$replayRow.Box]) { ' · 상자 안' } else { ' · 상자 밖' }) }
        $actualKind = $(if (-not $hudVisible) { 'nohud' } elseif (-not $replayRead.Point) { 'none' } elseif ($replayRead.FoundBy -eq '글자 탐색') { 'normal' } else { 'rescue' })
        $replayCounts[$actualKind]++
        $expectedHud = '{0}({1})' -f ($replayRow.Kind -ne 'nohud'), $(if ($replayRow.HudBinary) { 'normal,bin' } else { 'normal' })
        $expectedSearch = switch ($replayRow.Kind) {
          'normal' { "normal · $($replayRow.Point) 글자 탐색 · 상자 안" }
          'rescue' { "normal,bin · $($replayRow.Point) 글자 탐색 이진화 · 상자 안" }
          default { 'normal,bin · 없음' }
        }
        Check-Equal ('§3 재생 {0} ({1})' -f $replayRow.Id, $replayRow.Note) ('HUD {0}({1}) / 탐색 {2} · {3}{4}' -f $hudVisible, $hudModes, $searchModes, $replayPointText, $boxText) "HUD $expectedHud / 탐색 $expectedSearch"
        if ($replayRow.Kind -eq 'rescue') {
          # 고치기 전 재현: 옛 코드는 일반 판독 한 번뿐이고 못 찾으면 옛 고정점을 눌렀습니다. 그 점이 라벨의 어디에 떨어지는지까지 봅니다
          $oldReadText = Format-OneRead (Find-EscByOneRead -Engine $ocrEnglishEngine)
          $oldPlaced = Format-PlacedPoint -Width $script:replayWindow.Width -Height $script:replayWindow.Height -ReferenceX $ptEscButton[0] -ReferenceY $ptEscButton[1] -Box $labelBoxes[$replayRow.Box]
          Check-Equal ('§3 고치기 전 재현 {0}: 일반만이면 없음 → 옛 고정점은 라벨 {1} (고친 뒤 {2})' -f $replayRow.Id, $replayRow.OldWhere, $replayRow.Point) `
            ('{0} / {1}' -f $oldReadText, ($oldPlaced -replace '^\S+ ', '')) ('없음 / {0}' -f $replayRow.OldWhere)
        }
      } finally { $script:replayWindow.Dispose(); $script:replayWindow = $null }
    }
    # 위 행이 모두 통과하면 함께 참인 요약입니다 - 회귀를 더 잡지는 않고, 행을 빼거나 종류를 바꿀 때 표가 판독결과와 어긋나지 않았는지 봅니다
    Check-Equal '§3 표 구성 요약: 일반 24 · 구제 7 · 둘 다 없음 4 · HUD 없음 2' ('일반 {0} · 구제 {1} · 둘 다 없음 {2} · HUD 없음 {3}' -f $replayCounts.normal, $replayCounts.rescue, $replayCounts.none, $replayCounts.nohud) '일반 24 · 구제 7 · 둘 다 없음 4 · HUD 없음 2'

    # 근거 행: 순서가 일반 → 이진화인 이유 · 이진화가 한국어 엔진인 이유
    $g090206Row = $replayRows | Where-Object { $_.Id -eq 'g_090206' } | Select-Object -First 1
    $b4Row = $replayRows | Where-Object { $_.Id -eq 'b4' } | Select-Object -First 1
    foreach ($reasonRow in @(
        @{ Row = $g090206Row; Engine = $ocrKoreanEngine; Note = 'g_090206 은 이진화 단독이면 없음 - 순서는 일반 먼저' },
        @{ Row = $b4Row; Engine = $ocrEnglishEngine; Note = 'b4 는 이진화/영어면 없음 - 이진화는 한국어 엔진' })) {
      $reasonPath = Join-Path $imageRoot $reasonRow.Row.Rel
      if (-not (Test-Path -LiteralPath $reasonPath)) { continue }
      Open-ReplayWindow $reasonPath
      try { Check-Equal "§3 근거 $($reasonRow.Note)" (Format-OneRead (Find-EscByOneRead -Engine $reasonRow.Engine -Binary)) '없음' }
      finally { $script:replayWindow.Dispose(); $script:replayWindow = $null }
    }
    $replayStopwatch.Stop()
    if ($binaryMs.Count -gt 0) {
      $binaryStats = $binaryMs | Measure-Object -Maximum -Average
      'INFO 이진화 판독 1회 최대 {0:0}ms ({1}) · 평균 {2:0}ms · {3}회 - 잘라내기 · GetPixel/SetPixel · 확대 · OCR, 첫 OCR 준비 제외' -f $binaryStats.Maximum, $binaryMaxId, $binaryStats.Average, $binaryMs.Count
    }
    'INFO §3 재생 전체 {0:0.0}초' -f $replayStopwatch.Elapsed.TotalSeconds
  }
}

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
