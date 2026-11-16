# 어비스 주간 전리품 정산 전 '입장 불가' 팝업 안내 정지 회귀 (2026-11-17 신설 - 사용자 결정 (가) · 설계 합의)
# 사고: 2026-11-16 월요일 06시 주간 리셋 뒤 주간 전리품을 받기 전에 어비스 카드를 누르면 상세 화면 대신 '입장 불가 / 주간 전리품을 먼저 정산하세요. /
#   [확인](Space)' 팝업이 떠, 카드 클릭의 상세 화면 대기가 15초 뒤 시간 초과 → 코드 1(06:02 밤샘 무한 반복이 그때부터 멈춤 · 09:01 커스텀은 자동 재시작).
#   고친 동작: 정확히 그 대기의 시간 초과일 때만 팝업을 한 번 읽어 맞으면 계상 없이 안내 정지(코드 4), 그 밖은 지금처럼 다시 던짐(코드 1). 여기서 고정하는 것:
#   §1 순수 판정(Test-AbyssWeeklyLootPopupText) - 실측 판독문 · 조각 분리 행(설계 합의 조건 P2 - 두 갈래 OR 를 따로 고정) · 공백 정규화 · 비대상 · 결과는 bool 형(§2-0 · §2 도)
#   §2-0 판독 함수 인자(그림 없이 모든 PC 에서) - 공용 판독의 원문 param 으로 만든 감시 함수가 영역 · 배율 · 엔진 · 게임을 기록
#   §2 실측 재생 - 팝업 두 캡처(1272 100% · 1914 150%)는 참이고 판독문 그대로, 비교 여섯(선택 화면 · 상세 화면 · 매칭 패널 · 회복 물약 팝업 · 클리어 화면 · 던전 안)은 거짓
#   §3 정지 함수(Stop-AbyssWeeklyLootPopup) - 진단 캡처(그림만 · 받은 게임) → [완료] → 코드 4 · 명령은 진단 · 로그 둘뿐
#   §4 호출부 catch 행동 - 원문 try 문을 그대로 실행하고, 시간 초과 문구는 Invoke-ClickUntil 원문의 throw 로 만듦(사본 문구 금지 - 구현 리뷰 P2):
#       정확한 시간 초과 + 팝업 → 정지 / 정확한 시간 초과 + 팝업 아님 → 같은 예외 다시 던짐 / 다른 예외 → 판독 없이 다시 던짐(단락 평가) / 성공 → 판독 0 /
#       판독이 창 좌표 예외를 던지면 그 예외가 올라감(지금 동작 고정 - 종료 코드 1 은 같음)
#   §5 배선 - catch 절 1 · finally 없음 · 조건 정확 일치 · 마지막 문장 다시 던지기 · 대기 인자 그대로 · 영역 상수 하나(설정 키 아님)
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
[Console]::OutputEncoding = [Text.Encoding]::UTF8
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -ceq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
function Check-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = '')
  if ($Condition) { "OK   $Name" }
  else { "FAIL $Name ($Detail)"; $script:fails++ }
}

. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$parseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { "FAIL 준비: 워커 파싱 오류 $($parseErrors.Count)건 - $($parseErrors[0].Message)"; exit 1 }
$functionAsts = @{}
foreach ($functionAst in $workerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
  if (-not $functionAsts.ContainsKey($functionAst.Name)) { $functionAsts[$functionAst.Name] = $functionAst }
}
function Get-WorkerFunctionText {
  param([string]$Name)
  if (-not $functionAsts.ContainsKey($Name)) { throw "워커에서 함수를 찾지 못했습니다: $Name" }
  return [string]$functionAsts[$Name].Extent.Text
}
function Get-CodeOnly {
  # 주석 뺀 사본 - 공백을 하나로 모아 글자 비교가 줄바꿈·들여쓰기에 흔들리지 않게 합니다
  param([string]$Text)
  return (((Remove-SourceComments -Text $Text) -replace '\s+', ' ').Trim())
}
function Convert-ExitSentinel {
  # 줄 단독 exit 를 센티널 throw('__EXIT__N')로 바꿉니다 (test_reentry_clear_screen.ps1 과 같은 구현)
  param([string]$Text)
  return ($Text -replace '(?m)^(\s*)exit (\d+)\s*$', '$1throw "__EXIT__$2"')
}
# 소스 상수 대입문 실행 (config 미정의 → 기본값). 영역은 숫자를 다시 박지 않고 소스 대입문 그대로 씁니다
$config = $null
function Get-ConfigValue { param($Root, [string[]]$Path, $Default) return $Default }
function Get-ConfigInteger { param($Root, [string[]]$Path, $Default, $Min, $Max) return $Default }
$regionAssign = $null
foreach ($constantName in @('referenceWidth', 'referenceHeight', 'rgAbyssWeeklyLootPopup')) {
  $assign = $workerAst.Find({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq ('$' + $constantName)) }, $true)
  if (-not $assign) { "FAIL 준비: 워커에서 `$$constantName 대입을 찾지 못했습니다"; exit 1 }
  if ($constantName -eq 'rgAbyssWeeklyLootPopup') { $regionAssign = $assign }
  Invoke-Expression $assign.Extent.Text
}
$OBSERVED_POPUP_TEXT = '입장불가주간전리품을먼저정산하세요.'   # 실측 판독(두 캡처 · 배율 2·3 · 공백 뺌 - 2026-11-17 재생 실험) - 실측 문자열은 그대로 남깁니다

# ── §1 순수 판정 ──
Invoke-Expression (Get-WorkerFunctionText 'Test-AbyssWeeklyLootPopupText')
foreach ($textRow in @(
    @('실측 판독(06:02 · 09:01 두 캡처)', $OBSERVED_POPUP_TEXT, $true),
    @('공백 섞인 원문', '입장 불가 주간 전리품을 먼저 정산하세요.', $true),
    @('분리 - 공백 섞인 입장 불가 + 전리품(정산 깨짐 · 공백 정규화가 있어야 참)', '입장 불가 주간 전리품을 먼저', $true),
    @('분리 - 전리품 + 정산(입장불가 없음 - 제목 깨짐 꼴)', '주간전리품을먼저정산하세요.', $true),
    @('분리 - 입장불가 + 전리품(정산 없음 - 본문 끝 깨짐 꼴)', '입장불가주간전리품을먼저', $true),
    @('분리 - 입장불가 + 정산(전리품 없음)', '입장불가먼저정산하세요.', $false),
    @('단일 조각 - 전리품', '전리품', $false),
    @('단일 조각 - 정산', '정산', $false),
    @('단일 조각 - 입장불가', '입장불가', $false),
    @('선택 화면 이름표 꼴 - 주간 전리품', '주간전리품', $false),
    @('실측 비교 - 상세 화면(주요 전리품 · 전리품만 있음)', '주요전리품100', $false),
    @('실측 비교 - 선택 화면', '후수령기능', $false),
    @('실측 비교 - 우연한 만남 매칭 패널', '한가포인트100부꼼', $false),
    @('실측 비교 - 회복 물약 팝업', '탁월한자동회복물약거2B소ㆍ서구國', $false),
    @('던전 안 재생 판독(비교)', '발구르기+10*', $false),
    @('빈 값(캡처 실패)', '', $false))) {
  # 값과 함께 형([bool])을 봅니다 - Check-Equal 은 글자로 비교해 문자열 'False' 도 $false 와 같게 보는데, 호출부 조건식에서 비어 있지 않은 문자열은 참이라
  # 팝업이 아닌 시간 초과를 코드 4 로 잘못 멈춥니다(구현 리뷰 P2 - 2026-11-17)
  $textResult = Test-AbyssWeeklyLootPopupText -Text $textRow[1]
  Check-Equal ('§1 판정 - {0} ''{1}'' (bool 형|값)' -f $textRow[0], $textRow[1]) ('{0}|{1}' -f ($textResult -is [bool]), $textResult) ('True|{0}' -f $textRow[2])
}

# ── §2-0 판독 함수 인자 (그림 없이 모든 PC 에서 진짜 판독 함수를 돌림) ──
# 감시 함수는 공용 판독(Get-GameRegionOcrText)의 원문 param 블록으로 만들어, 판독 함수의 호출이 실제 서명에 묶이는지까지 봅니다.
# §2 의 재생은 그림 폴더가 있는 개발 PC 에서만 돌고, 거기서 '판독문 = 실측' 은 테스트가 따로 한 번 더 읽은 글이라 판독 함수의 영역 인자를 직접 보지 않습니다(구현 리뷰 P3)
$ocrParamBlock = $functionAsts['Get-GameRegionOcrText'].Body.ParamBlock
Check-True '§2-0 전제: 공용 판독의 param 블록 있음' ($null -ne $ocrParamBlock) ''
if ($null -ne $ocrParamBlock) {
  Invoke-Expression ("function Get-GameRegionOcrText {`n" + $ocrParamBlock.Extent.Text + "`n" +
    '  $script:probeCalls.Add((''{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}'' -f [object]::ReferenceEquals($Game, $script:spyGame), $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, [object]::ReferenceEquals($Engine, $script:spyEngine), [bool]$BinaryWhiteText))' + "`n" +
    '  return $script:probeReturnText' + "`n}")
  Invoke-Expression (Get-WorkerFunctionText 'Test-AbyssWeeklyLootPopup')
  $script:spyGame = [System.Diagnostics.Process]::GetCurrentProcess()
  $script:spyEngine = New-Object object
  $ocrKoreanEngine = $script:spyEngine
  $probeWantArgs = 'True|{0}|{1}|{2}|{3}|2|True|False' -f $rgAbyssWeeklyLootPopup[0], $rgAbyssWeeklyLootPopup[1], $rgAbyssWeeklyLootPopup[2], $rgAbyssWeeklyLootPopup[3]
  foreach ($probeRow in @(
      @('팝업 원문(공백 섞임)', '입장 불가 주간 전리품을 먼저 정산하세요.', $true),
      @('빈 값(캡처 실패 - 판독 헬퍼가 빈 문자열을 돌려줌)', '', $false),
      @('상세 화면 꼴(전리품만)', '주요 전리품 100', $false))) {
    $script:probeCalls = New-Object System.Collections.Generic.List[string]
    $script:probeReturnText = $probeRow[1]
    $probeResult = Test-AbyssWeeklyLootPopup -Game $script:spyGame
    Check-Equal ('§2-0 판독 함수 - {0} (bool 형|결과|판독 횟수|게임 그대로|영역 X·Y·폭·높이|배율|한국어 엔진|흰 글자 이진화)' -f $probeRow[0]) `
      ('{0}|{1}|{2}|{3}' -f ($probeResult -is [bool]), $probeResult, $script:probeCalls.Count, ($script:probeCalls -join ' ; ')) ('True|{0}|1|{1}' -f $probeRow[2], $probeWantArgs)
  }
  $ocrKoreanEngine = $null
}

# ── §2 실측 재생 (워커 캡처 본문 그대로 - 화면 취득 한 줄만 그림의 같은 자리를 옮김, test_reentry_clear_screen §2 와 같은 방식) ──
$imageRoot = Join-Path $projectRoot '던전이미지'
$replayCases = @(
  @{ Name = 'P1 팝업 06:02 1272x717 100%'; Path = '어비스\20261116_⑤d_S분리_실기\주간전리품팝업_밤샘무한반복_error_20261116_h06m02s53.png'; Want = $true },
  @{ Name = 'P2 팝업 09:01 1914x1079 150%'; Path = '어비스\20261116_⑤d_S분리_실기\worker_logs\error_20261116_h09m01s34.png'; Want = $true },
  @{ Name = 'N1 선택 화면(카드 셋 · 왼쪽 아래 주간 전리품 패널)'; Path = '어비스\20260918_다른던전가기_01_어비스선택오버레이_3카드_X_1272x717.png'; Want = $false },
  @{ Name = 'N2 상세 화면'; Path = '어비스\20260918_다른던전가기_01b_카드클릭후_상세화면_광기의동굴_함께하기_1272x717.png'; Want = $false },
  @{ Name = 'N3 우연한 만남 매칭 패널(가운데 창)'; Path = '어비스\20260918_다시하기_01_클릭직후_우연한만남패널_1of4_1272x717.png'; Want = $false },
  @{ Name = 'N4 회복 물약 팝업(가운데 창)'; Path = '어비스\20260918_다시하기_05_입장직후_회복물약팝업_1272x717.png'; Want = $false },
  @{ Name = 'N5 클리어 화면(11-16 14:19 정지 캡처)'; Path = '어비스\20261116_v2112_재입장대기300초_새판클리어화면_정지\error_20261116_h14m19s04_정지순간_새판클리어화면.png'; Want = $false },
  @{ Name = 'N6 던전 안(11-16 13:57)'; Path = '어비스\20261116_v2112_재입장대기300초_새판클리어화면_정지\error_20261116_h13m57s32_클리어대기필드판정_추적기깨짐.png'; Want = $false }
)
if (-not (Test-Path -LiteralPath $imageRoot)) {
  "SKIP §2 실측 재생: 던전이미지 폴더가 없어 건너뜁니다 (로컬 전용 - 개발 PC 외): $imageRoot"
} else {
  $missingImages = @($replayCases | Where-Object { -not (Test-Path -LiteralPath (Join-Path $imageRoot $_.Path)) })
  foreach ($missingImage in $missingImages) { "FAIL §2 재생 그림 없음: $($missingImage.Path) - 폴더를 옮겼다면 이 테스트의 경로도 함께 고칠 것"; $fails++ }
  $ocrKoreanEngine = $null; $ocrEnglishEngine = $null
  try {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
    [Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null
    [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
    $asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
      Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } | Select-Object -First 1
    $ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('ko')))
    $ocrEnglishEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('en-US')))
  } catch { $ocrKoreanEngine = $null }
  if ($missingImages.Count -gt 0) {
    # 위에서 FAIL 로 셌습니다
  } elseif (-not $ocrKoreanEngine) {
    'SKIP §2 실측 재생: ko OCR 엔진을 만들 수 없어 건너뜁니다 (언어 팩 없음)'
  } else {
    Add-Type -TypeDefinition @'
using System;
public static class HoneyNogiInput {
  public struct RECT { public int Left, Top, Right, Bottom; }
  public static int WindowWidth, WindowHeight;
  public static bool GetWindowRect(IntPtr hWnd, out RECT rect) {
    rect = new RECT(); rect.Left = 0; rect.Top = 0; rect.Right = WindowWidth; rect.Bottom = WindowHeight; return true;
  }
  public static bool IsIconic(IntPtr hWnd) { return false; }
}
'@
    $fakeGame = [System.Diagnostics.Process]::GetCurrentProcess()
    function Test-BlankCapture { param($Bitmap) return $false }
    function Test-DesktopRenderingAlive { return $true }
    function Register-CaptureSuccess { $script:screenCaptureFailing = $false }
    function Register-CaptureFailure { param($GameWindowIssue) $script:screenCaptureFailing = $true }
    function Invoke-AutoRefocus { param($Game) }
    function Write-RunLog { param([string]$Message) }
    $script:replayWindow = $null
    function Copy-ReplayRegion {
      param($Graphics, [int]$Left, [int]$Top, [int]$Width, [int]$Height)
      $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
      $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
      $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
      $Graphics.DrawImage($script:replayWindow, (New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)), (New-Object System.Drawing.Rectangle($Left, $Top, $Width, $Height)), [System.Drawing.GraphicsUnit]::Pixel)
    }
    $captureSource = Get-WorkerFunctionText 'Get-GameRegionCapture'
    $screenCopyLine = '$sourceGraphics.CopyFromScreen($cropLeft, $cropTop, 0, 0, $sourceCapture.Size)'
    Check-Equal '§2 재생 전제: 워커 캡처 본문의 화면 취득 줄 = 1곳' ([regex]::Matches($captureSource, [regex]::Escape($screenCopyLine)).Count) 1
    Invoke-Expression ($captureSource.Replace($screenCopyLine, 'Copy-ReplayRegion -Graphics $sourceGraphics -Left $cropLeft -Top $cropTop -Width $cropWidth -Height $cropHeight'))
    foreach ($name in @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Get-GameRegionOcrText', 'Test-AbyssWeeklyLootPopup')) { Invoke-Expression (Get-WorkerFunctionText $name) }
    foreach ($replayCase in $replayCases) {
      $script:replayWindow = New-Object System.Drawing.Bitmap((Join-Path $imageRoot $replayCase.Path))
      try {
        [HoneyNogiInput]::WindowWidth = $script:replayWindow.Width
        [HoneyNogiInput]::WindowHeight = $script:replayWindow.Height
        $script:screenCaptureFailing = $false
        $detected = Test-AbyssWeeklyLootPopup -Game $fakeGame
        # 판독문 기록 - 운영 함수와 같은 영역·배율·엔진(소스 상수)으로 한 번 더 읽어 남깁니다(실측 문자열 보존)
        $readText = (Get-GameRegionOcrText -Game $fakeGame -ReferenceX $rgAbyssWeeklyLootPopup[0] -ReferenceY $rgAbyssWeeklyLootPopup[1] -RegionWidth $rgAbyssWeeklyLootPopup[2] `
            -RegionHeight $rgAbyssWeeklyLootPopup[3] -Scale 2 -Engine $ocrKoreanEngine) -replace '\s', ''
      } finally { $script:replayWindow.Dispose(); $script:replayWindow = $null }
      "  ($($replayCase.Name) 판독: '$readText')"
      if ($replayCase.Want) {
        Check-Equal ('§2 {0} → 팝업 참(bool) · 판독문 = 실측' -f $replayCase.Name) ('{0}|{1}|{2}' -f ($detected -is [bool]), $detected, $readText) ('True|True|{0}' -f $OBSERVED_POPUP_TEXT)
      } else {
        Check-Equal ('§2 {0} → 팝업 거짓(bool)' -f $replayCase.Name) ('{0}|{1}' -f ($detected -is [bool]), $detected) 'True|False'
      }
    }
  }
}

# ── §3 정지 함수 ──
Invoke-Expression (Convert-ExitSentinel -Text (Get-WorkerFunctionText 'Stop-AbyssWeeklyLootPopup'))
# 진단 모의는 실제 Write-LifeDiagnostics 와 같은 서명 - 스위치 둘과 받은 게임이 그대로 건너가는지 기록합니다(구현 리뷰 P3)
function Write-LifeDiagnostics {
  param([System.Diagnostics.Process]$Game, [string]$Context, [switch]$CaptureOnly, [switch]$WithLogCopy)
  $script:events.Add(('diag:{0}|{1}|{2}|{3}' -f $Context, [bool]$CaptureOnly, [bool]$WithLogCopy, [object]::ReferenceEquals($Game, $script:sentinelGame)))
}
function Write-RunLog { param([string]$Message) $script:events.Add('log:' + $Message) }
$script:events = New-Object System.Collections.Generic.List[string]
$script:sentinelGame = [System.Diagnostics.Process]::GetCurrentProcess()
$stopError = ''
try { Stop-AbyssWeeklyLootPopup -Game $script:sentinelGame } catch { $stopError = [string]$_.Exception.Message }
$stopEvents = $script:events.ToArray()
Check-True '§3 정지 함수 → 진단 캡처 1(그림만 · 로그 사본 없음 · 받은 게임) → [완료] 1줄(주간 전리품 정산 안내) → 코드 4' (($stopError -ceq '__EXIT__4') -and ($stopEvents.Count -eq 2) -and
  ($stopEvents[0] -match '^diag:[^|]*주간 전리품[^|]*\|True\|False\|True$') -and $stopEvents[1].StartsWith('log:[완료] 어비스 입장 불가 - 주간 전리품을 먼저 정산해야 합니다.', [StringComparison]::Ordinal) -and
  $stopEvents[1].Contains("[전리품 정산]을 받은 뒤 다시 시작해 주세요")) ('{0} / {1}' -f $stopError, ($stopEvents -join ' | '))
# 입력 0 은 금지 목록이 아니라 허용 목록으로 봅니다 - 정지 함수 안의 명령은 진단 캡처 · 로그 둘뿐(exit 는 명령이 아님). 입력 함수 이름을 빠뜨린 금지 목록은 새 입력을 놓칩니다
$stopCommands = @($functionAsts['Stop-AbyssWeeklyLootPopup'].Body.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
Check-Equal '§3 정지 함수의 명령 = 진단 캡처 · 로그 둘뿐(클릭·키 입력 0 - 팝업은 그대로 둠)' ($stopCommands -join ',') 'Write-LifeDiagnostics,Write-RunLog'

# ── §4 호출부 catch 행동 (원문 try 문을 그대로 실행) ──
$cardIfs = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq '$needCardClick') }, $true))
Check-Equal '§4 전제: 본류 if ($needCardClick) = 1' $cardIfs.Count 1
$cardTry = $null
if ($cardIfs.Count -eq 1) {
  $cardTries = @($cardIfs[0].Clauses[0].Item2.Statements | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] })
  Check-Equal '§4 전제: 그 if 몸통의 try 문 = 1' $cardTries.Count 1
  if ($cardTries.Count -eq 1) { $cardTry = $cardTries[0] }
}
$timeoutTemplate = $null
if ($null -ne $cardTry) {
  # 시간 초과 문구는 테스트에 다시 박지 않고 Invoke-ClickUntil 원문의 throw 로 만듭니다 - 헬퍼 문구가 바뀌면(진단 꼬리 · 맞춤법) catch 의 정확 일치가
  # 조용히 꺼져 월요일 팝업이 다시 코드 1 로 끝나는데, 사본 문구로는 그것을 못 잡습니다(구현 리뷰 P2 - 2026-11-17)
  $clickUntilThrows = @($functionAsts['Invoke-ClickUntil'].FindAll({ param($node) $node -is [System.Management.Automation.Language.ThrowStatementAst] }, $true))
  Check-Equal '§4 전제: Invoke-ClickUntil 의 throw = 1곳(대기 시간 초과)' $clickUntilThrows.Count 1
  if (($clickUntilThrows.Count -eq 1) -and ($null -ne $clickUntilThrows[0].Pipeline)) {
    $timeoutTemplate = [scriptblock]::Create('param($Description, $TimeoutSeconds) ' + $clickUntilThrows[0].Pipeline.Extent.Text)
  }
}
if (($null -ne $cardTry) -and ($null -ne $timeoutTemplate)) {
  # 대기 모의는 원문 param 블록으로 만들어 try 몸통의 인자가 실제 서명에 묶이는지까지 봅니다. 'timeout' 모드는 받은 Description · 한도로 원문 throw 를 그대로 던집니다
  Invoke-Expression ("function Invoke-ClickUntil {`n" + $functionAsts['Invoke-ClickUntil'].Body.ParamBlock.Extent.Text + "`n" +
    '  $script:clickUntilDescriptions.Add($Description)' + "`n" +
    '  if ($script:clickUntilThrow -ceq ''timeout'') { throw (& $timeoutTemplate $Description $TimeoutSeconds) }' + "`n" +
    '  if ($script:clickUntilThrow) { throw $script:clickUntilThrow }' + "`n}")
  function Test-AbyssWeeklyLootPopup {
    param($Game)
    $script:popupReads++
    if ($script:popupThrow) { throw $script:popupThrow }
    return [bool]$script:popupValue
  }
  function Stop-AbyssWeeklyLootPopup { param($Game) $script:stopCalls++; throw '__STOP__' }
  $cardTryBlock = [scriptblock]::Create($cardTry.Extent.Text)
  $selectedDungeon = '허상의 정박지'; $game = $null; $dungeonCard = @(957, 160); $timeoutDetail = 15
  $exactTimeout = [string](& $timeoutTemplate "$selectedDungeon 상세 화면" $timeoutDetail)
  $otherDungeonTimeout = [string](& $timeoutTemplate '광기의 동굴 상세 화면' $timeoutDetail)
  $windowRectError = 'OCR용 게임 창 좌표를 읽지 못했습니다.'
  foreach ($catchRow in @(
      @{ Name = '정확한 시간 초과 + 팝업 → 안내 정지'; Throw = 'timeout'; Popup = $true; PopupThrow = ''; Want = '__STOP__|1|1' },
      @{ Name = '정확한 시간 초과 + 팝업 아님 → 같은 예외 다시 던짐(지금의 코드 1)'; Throw = 'timeout'; Popup = $false; PopupThrow = ''; Want = ('{0}|1|0' -f $exactTimeout) },
      @{ Name = '다른 예외(창 좌표) + 팝업 → 판독 없이 다시 던짐(단락 평가)'; Throw = $windowRectError; Popup = $true; PopupThrow = ''; Want = ('{0}|0|0' -f $windowRectError) },
      @{ Name = '다른 던전의 시간 초과 문구 + 팝업 → 판독 없이 다시 던짐(정확 일치)'; Throw = $otherDungeonTimeout; Popup = $true; PopupThrow = ''; Want = ('{0}|0|0' -f $otherDungeonTimeout) },
      @{ Name = '상세 화면 확인(예외 없음) → 판독 0'; Throw = ''; Popup = $true; PopupThrow = ''; Want = '|0|0' },
      # 지금 동작 고정(구현 리뷰 P3 · 규칙 8 - 관측 없는 방어는 넣지 않음): 시간 초과 뒤 팝업 판독이 창 좌표 예외를 던지면 그 예외가 원래 시간 초과 대신 올라갑니다.
      # 종료 코드는 둘 다 1(최상위 catch)이라 행동은 같고 [오류] 문구만 다릅니다 - 바꾸려면 설계부터
      @{ Name = '정확한 시간 초과 + 판독이 창 좌표 예외 → 그 예외가 올라감(종료 코드 1 은 같음)'; Throw = 'timeout'; Popup = $true; PopupThrow = $windowRectError; Want = ('{0}|1|0' -f $windowRectError) })) {
    $script:clickUntilDescriptions = New-Object System.Collections.Generic.List[string]
    $script:clickUntilThrow = $catchRow.Throw
    $script:popupValue = $catchRow.Popup
    $script:popupThrow = $catchRow.PopupThrow
    $script:popupReads = 0
    $script:stopCalls = 0
    $catchOutcome = ''
    try { . $cardTryBlock } catch { $catchOutcome = [string]$_.Exception.Message }
    Check-Equal ('§4 {0} (결과|팝업 판독|정지)' -f $catchRow.Name) ('{0}|{1}|{2}' -f $catchOutcome, $script:popupReads, $script:stopCalls) $catchRow.Want
    Check-Equal ('§4 {0} - 대기 Description 그대로' -f $catchRow.Name) ($script:clickUntilDescriptions -join ',') "$selectedDungeon 상세 화면"
  }
}

# ── §5 배선 ──
if ($null -ne $cardTry) {
  Check-Equal '§5 catch 절 = 1 · 타입 거르기 없음(규칙 3 - 절 2 이하) · finally 없음(정지 · 다시 던지기 뒤에 끼어드는 처리 0)' `
    ('{0}|{1}|{2}' -f $cardTry.CatchClauses.Count, @($cardTry.CatchClauses | Where-Object { $_.CatchTypes.Count -gt 0 }).Count, ($null -eq $cardTry.Finally)) '1|0|True'
  $catchStatements = @($cardTry.CatchClauses[0].Body.Statements)
  $catchIf = $(if ($catchStatements.Count -ge 1) { $catchStatements[0] } else { $null })
  $catchIfCondition = $(if ($catchIf -is [System.Management.Automation.Language.IfStatementAst]) { Get-CodeOnly $catchIf.Clauses[0].Item1.Extent.Text } else { '(if 아님)' })
  Check-Equal '§5 catch 첫 문장 = 정확 일치 시간 초과 ∧ 팝업 판독(단락 평가 순서)' $catchIfCondition `
    "([string]`$_.Exception.Message -ceq `"`$selectedDungeon 상세 화면 대기 시간이 초과됐습니다.`") -and (Test-AbyssWeeklyLootPopup -Game `$game)"
  $catchIfBody = $(if ($catchIf -is [System.Management.Automation.Language.IfStatementAst]) { Get-CodeOnly $catchIf.Clauses[0].Item2.Extent.Text } else { '' })
  Check-Equal '§5 그 if 몸통 = 정지 함수 호출 하나' $catchIfBody '{ Stop-AbyssWeeklyLootPopup -Game $game }'
  $catchLast = $(if ($catchStatements.Count -ge 1) { Get-CodeOnly $catchStatements[-1].Extent.Text } else { '' })
  Check-Equal '§5 catch 마지막 문장 = 다시 던지기(인자 없음 - 원래 예외 그대로)' ('{0}|{1}' -f $catchStatements.Count, $catchLast) '2|throw'
  $tryBody = Get-CodeOnly $cardTry.Body.Extent.Text
  Check-Equal '§5 try 몸통 = 카드 클릭 대기 원문 그대로(인자 · 조건 · 재클릭 허가)' $tryBody `
    ('{ Invoke-ClickUntil -Game $game -Point $dungeonCard -Description "$selectedDungeon 상세 화면" ` -TimeoutSeconds $timeoutDetail -Condition { Test-DetailTitleMatches -Game $game } ` -SourceCondition { Test-AbyssSelectionScreen -Game $game } }')
  $cardBody = @($cardIfs[0].Clauses[0].Item2.Statements)
  $cardLogAt = [Array]::IndexOf($cardBody, @($cardBody | Where-Object { (Get-CodeOnly $_.Extent.Text) -ceq 'Write-RunLog "[어비스] $selectedDungeon 카드 클릭"' })[0])
  # 카드 클릭 줄을 지우면 그 위치가 -1 이 되고 try 가 맨 앞(0 = -1 + 1)으로 와 '바로 다음' 비교가 빈 채로 참이 되므로, 그 줄이 있는지(0 이상)도 함께 봅니다(구현 리뷰 P3)
  Check-True '§5 카드 클릭 줄 있음 · 바로 다음이 그 try 문' (($cardLogAt -ge 0) -and ([Array]::IndexOf($cardBody, $cardTry) -eq ($cardLogAt + 1))) `
    ('카드 클릭 줄 위치 {0} · try 위치 {1}' -f $cardLogAt, [Array]::IndexOf($cardBody, $cardTry))
}
# 영역은 스크립트 상수 하나 - 워커 전체에서 대입 1곳이고, 오른쪽은 숫자 상수 4칸 배열(변수 · 명령 0)입니다. 설정 키가 아니라 좌표 · 설정 스키마 버전과 무관합니다
$regionAssigns = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -match '(?i)rgAbyssWeeklyLootPopup') }, $true))
$regionShape = '(대입 없음)'
if ($null -ne $regionAssign) {
  $regionShape = '{0}|{1}|{2}|{3}' -f ($null -ne $regionAssign.Right.Find({ param($node) $node -is [System.Management.Automation.Language.ArrayExpressionAst] }, $true)),
    @($regionAssign.Right.FindAll({ param($node) ($node -is [System.Management.Automation.Language.VariableExpressionAst]) -or ($node -is [System.Management.Automation.Language.CommandAst]) }, $true)).Count,
    @($regionAssign.Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.ConstantExpressionAst] }, $true)).Count,
    @($rgAbyssWeeklyLootPopup).Count
}
Check-Equal '§5 영역 = 스크립트 상수 하나(대입 수|배열|변수·명령|숫자 상수|값 칸 수 - 설정 키 아님)' ('{0}|{1}' -f $regionAssigns.Count, $regionShape) '1|True|0|4|4'
$probeCode = Get-CodeOnly (Get-WorkerFunctionText 'Test-AbyssWeeklyLootPopup')
Check-True '§5 판독 함수 = 그 영역 · 배율 2 · 한국어 엔진 1회 → 순수 판정' (($probeCode.Contains('-ReferenceX $rgAbyssWeeklyLootPopup[0] -ReferenceY $rgAbyssWeeklyLootPopup[1]')) -and
  $probeCode.Contains('-Scale 2 -Engine $ocrKoreanEngine') -and ([regex]::Matches($probeCode, 'Get-GameRegionOcrText').Count -eq 1) -and $probeCode.Contains('Test-AbyssWeeklyLootPopupText -Text $popupText')) $probeCode
$callOwners = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and (@('Test-AbyssWeeklyLootPopup', 'Stop-AbyssWeeklyLootPopup') -contains $node.GetCommandName()) }, $true))
Check-Equal '§5 판독 · 정지 함수를 부르는 곳 = 그 catch 안 각 1곳(대기 중 판독 늘림 0)' ('{0}|{1}' -f $callOwners.Count, @($callOwners | Where-Object { ($null -ne $cardTry) -and ($_.Extent.StartOffset -ge $cardTry.CatchClauses[0].Extent.StartOffset) -and ($_.Extent.EndOffset -le $cardTry.CatchClauses[0].Extent.EndOffset) }).Count) '2|2'

exit $fails
