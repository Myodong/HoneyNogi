# 공지 게시판 X 자리 진리표 (2026-11-05 - 설계 .claude\설계\복귀연장\공지X_설계.md, 재현 자료 던전이미지\어비스\20261104_복귀연장_실기\)
#
# 실사고 11-05 14:42 실기: 1272 창(클라이언트 1250x661, 150%)에서 공지 게시판을 고정점 (1092,135) 으로 42번 눌렀는데 안 닫혀 복귀가 코드 1 로 끝났습니다. 1908 창은 같은 점이 글자 위라 한 번에 닫혔습니다.
# 공지 창은 클라이언트 높이에 비례하고 가로 가운데에 놓입니다. 그 전에 쓰던 테스트는 버튼 크기를 추측해 고정점이 닫는다고 가정했고, 코드와 같이 틀렸습니다 (규칙 9).
# 세 층입니다:
#   §1 끝까지 진리표 - 늘 실행. 운영 Click-NoticeBoardClose → Get-NoticeCloseReferencePoint → Get-NoticeCloseReferenceFromClient → Get-ScaledScreenPoint 를 그대로 돌립니다.
#                      창 API 만 C# 스텁이고 Click-ScreenPoint 만 모의입니다 - 단언은 그래서 '최종 클릭점' 입니다. 최소화 복원 순서도 행동으로 봅니다 (복원 전에 재면 화면 밖 좌표를 씁니다)
#   §2 그림 재생 - 개발 PC. 커서 없는 그림에서 **계산과 무관한 고정 상자** 안의 밝은 픽셀로 글자 중심을 재고 최종 클릭점과 비교합니다. 던전이미지 루트가 없으면 SKIP, 루트가 있는데 그림이 없으면 FAIL
#   §3 배선 - 늘 실행. 주석 뺀 소스 기준. 공지를 닫는 8곳이 한 입구를 쓰고 옛 고정점 호출이 없는지
# 복귀 루프의 횟수 상한 · X 후보 넘김은 test_abyss_return_loop 의 RLX1n · RLX1s~u 가 봅니다.
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
  param([string]$Name, [bool]$Condition, [string]$Detail = '')
  if ($Condition) { "OK   $Name $Detail" }
  else { "FAIL $Name $Detail"; $script:fails++ }
}
function Test-Near {
  param([double]$Actual, [double]$Expected, [double]$Tolerance)
  return ([Math]::Abs($Actual - $Expected) -le $Tolerance)
}

# ── 창 API 스텁: 운영 코드가 부르는 이름과 모양 그대로입니다 ──
Add-Type -TypeDefinition @'
using System;
public static class HoneyNogiInput {
  public struct RECT { public int Left, Top, Right, Bottom; }
  public struct POINT { public int X; public int Y; }
  public static RECT WindowRect;
  public static RECT ClientRect;
  public static POINT ClientOrigin;
  public static bool WindowRectOk = true;
  public static bool ClientRectOk = true;
  public static bool ClientOriginOk = true;
  public static bool ClientThrows = false;
  public static bool Iconic = false;
  public static bool IsIconic(IntPtr handle) { return Iconic; }
  public static bool GetWindowRect(IntPtr handle, out RECT rect) { rect = WindowRect; return WindowRectOk; }
  public static bool GetClientRect(IntPtr handle, out RECT rect) {
    if (ClientThrows) { throw new InvalidOperationException("client rect failed"); }
    rect = ClientRect; return ClientRectOk;
  }
  public static bool ClientToScreen(IntPtr handle, ref POINT point) { point = ClientOrigin; return ClientOriginOk; }
}
'@

# ── 운영 코드: 함수와 상수를 소스 그대로 씁니다 (사본 금지) ──
Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-NoticeCloseReferenceFromClient', 'Get-NoticeCloseReferencePoint', 'Click-NoticeBoardClose', 'Get-ScaledScreenPoint')))
$workerText = [IO.File]::ReadAllText($workerPath)
$workerTokens = $null; $workerParseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseInput($workerText, [ref]$workerTokens, [ref]$workerParseErrors)
if ($workerParseErrors.Count -gt 0) { "FAIL 워커 파싱 오류 $($workerParseErrors.Count)건 - 첫 오류: $($workerParseErrors[0].Message)"; exit 1 }
$config = $null
# config 키 clickPoints.noticeBoardClose 는 표식 값을 돌려줍니다 - 키를 지우고 고정 값으로 바꾸면 대체 자리 행이 실패합니다 (이 키가 남아서 configSchemaVersion 을 안 올렸습니다 - 구현 리뷰 P2)
$noticeBoardConfigMark = @(1111, 222)
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) if (($Path -join '.') -ceq 'clickPoints.noticeBoardClose') { return $noticeBoardConfigMark }; return $Default }
function Get-ConfigInteger { param([object]$Root, [string[]]$Path, $Default, $Minimum, $Maximum) return $Default }
foreach ($constantName in @('$referenceWidth', '$referenceHeight', '$noticeCloseCenterRatio', '$noticeCloseTopRatio', '$noticeCloseTryLimit', '$ptNoticeBoardClose')) {
  $sourceAssignments = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($_.Left.Extent.Text -eq $constantName) })
  if ($sourceAssignments.Count -ne 1) { "FAIL 셋업: 워커 최상위의 $constantName 대입문이 1곳이 아닙니다 ($($sourceAssignments.Count)곳)"; exit 1 }
  Invoke-Expression $sourceAssignments[0].Extent.Text
}

# ── 모의: 복원 대기와 마지막 클릭, 로그 ──
$script:lastClick = $null
$script:restoreCalls = 0
$script:logs = New-Object 'System.Collections.Generic.List[string]'
function Write-RunLog { param([string]$Message) [void]$script:logs.Add($Message) }
function Click-ScreenPoint { param([int]$X, [int]$Y) $script:lastClick = @{ X = $X; Y = $Y } }
function Wait-GameRestoredIfMinimized {
  param($Game)
  $script:restoreCalls++
  # 복원되면 창 정보가 제자리로 돌아옵니다. 자리를 복원 전에 재면 아래 최소화 행이 실패합니다
  if ([HoneyNogiInput]::Iconic -and $script:restoreSucceeds) { [HoneyNogiInput]::Iconic = $false; $restored = $script:restoredWindow; Set-WindowFixture @restored }
}
function Set-WindowFixture {
  param([int]$Left, [int]$Top, [int]$Width, [int]$Height, [int]$ClientLeft, [int]$ClientTop, [int]$ClientWidth, [int]$ClientHeight)
  $windowRect = New-Object HoneyNogiInput+RECT
  $windowRect.Left = $Left; $windowRect.Top = $Top; $windowRect.Right = $Left + $Width; $windowRect.Bottom = $Top + $Height
  [HoneyNogiInput]::WindowRect = $windowRect
  $clientRect = New-Object HoneyNogiInput+RECT
  $clientRect.Right = $ClientWidth; $clientRect.Bottom = $ClientHeight
  [HoneyNogiInput]::ClientRect = $clientRect
  $clientOrigin = New-Object HoneyNogiInput+POINT
  $clientOrigin.X = $ClientLeft; $clientOrigin.Y = $ClientTop
  [HoneyNogiInput]::ClientOrigin = $clientOrigin
  [HoneyNogiInput]::WindowRectOk = $true; [HoneyNogiInput]::ClientRectOk = $true; [HoneyNogiInput]::ClientOriginOk = $true; [HoneyNogiInput]::ClientThrows = $false
}
$game = [System.Diagnostics.Process]::GetCurrentProcess()
function Get-FinalClickInWindow {
  # 운영 입구를 끝까지 돌리고 창 왼쪽 위 기준 클릭점을 돌려줍니다
  Click-NoticeBoardClose -Game $game
  return @{ X = $script:lastClick.X - [HoneyNogiInput]::WindowRect.Left; Y = $script:lastClick.Y - [HoneyNogiInput]::WindowRect.Top }
}

# 두 창은 11-05 실기 로그의 창 정보 그대로입니다 (창 왼쪽 위 (972,10), 클라이언트 원점은 그 그림의 테두리 왼쪽 11 · 위 45)
$window1272 = @{ Left = 972; Top = 10; Width = 1272; Height = 717; ClientLeft = 983; ClientTop = 55; ClientWidth = 1250; ClientHeight = 661 }
$window1908 = @{ Left = 972; Top = 10; Width = 1908; Height = 1076; ClientLeft = 983; ClientTop = 55; ClientWidth = 1886; ClientHeight = 1020 }

# ── §1. 끝까지 진리표 ──
Check-Equal '상수: 공지 클릭 횟수 상한은 사용자 결정 U-R-10 의 2번' $noticeCloseTryLimit 2

# 글자 중심은 §2 가 그림으로 다시 잽니다. 여기는 실측값과 ±2 입니다 (1272 는 기준 좌표 1px = 화면 1px, 1908 은 1.5px)
Set-WindowFixture @window1272
$click1272 = Get-FinalClickInWindow
Check-True '1272 150%: 최종 클릭점이 글자 중심 (1078,148.5) ±2' ((Test-Near $click1272.X 1078 2) -and (Test-Near $click1272.Y 148.5 2)) "($($click1272.X),$($click1272.Y))"
Set-WindowFixture @window1908
$click1908 = Get-FinalClickInWindow
Check-True '1908 150%: 최종 클릭점이 글자 중심 (1636.5,205) ±2' ((Test-Near $click1908.X 1636.5 2) -and (Test-Near $click1908.Y 205 2)) "($($click1908.X),$($click1908.Y))"

# 식을 만들 때 쓰지 않은 옛 값입니다. 근거가 약합니다: 1417 은 클라이언트 크기가 [추정]이고, 1272 는 1256x678 이 11-04 로그 값이지만 원점 (8,31) 은 [추정]이며 그 좌표를 잰 07-17 창의 로그가 없습니다 - 값이 어긋나면 식보다 그 추정을 먼저 의심합니다
Set-WindowFixture -Left 0 -Top 0 -Width 1417 -Height 799 -ClientLeft 8 -ClientTop 31 -ClientWidth 1401 -ClientHeight 760
$old1417 = @(Get-NoticeCloseReferencePoint -Game $game)
Check-True '옛 값 1417 타 PC: 기준 좌표가 07-19 실측 (1092,135) ±1' ((Test-Near $old1417[0] 1092 1) -and (Test-Near $old1417[1] 135 1)) "($($old1417 -join ','))"
Set-WindowFixture -Left 0 -Top 0 -Width 1272 -Height 717 -ClientLeft 8 -ClientTop 31 -ClientWidth 1256 -ClientHeight 678
$old1272 = @(Get-NoticeCloseReferencePoint -Game $game)
Check-True '옛 값 1272 100%: 기준 좌표가 07-17 실측 (1090,137) ±1' ((Test-Near $old1272[0] 1090 1) -and (Test-Near $old1272[1] 137 1)) "($($old1272 -join ','))"

# 창이 어디 있든 같은 자리입니다 (화면 좌표에서 기준 좌표로 되돌리는 빼기를 지키는 행)
$movedWindow = $window1272.Clone(); $movedWindow.Left = 100; $movedWindow.Top = 300; $movedWindow.ClientLeft = 111; $movedWindow.ClientTop = 345
Set-WindowFixture @movedWindow
$clickMoved = Get-FinalClickInWindow
Check-Equal '창 위치: 창을 옮겨도 창 기준 클릭점이 같음' "$($clickMoved.X),$($clickMoved.Y)" "$($click1272.X),$($click1272.Y)"

# 최소화: GetWindowRect 는 실패 없이 화면 밖을 돌려줍니다. 복원을 먼저 기다려야 제자리를 잽니다 (설계 리뷰 P2)
$script:restoredWindow = $window1272
$script:restoreSucceeds = $true
Set-WindowFixture -Left -32000 -Top -32000 -Width 160 -Height 28 -ClientLeft -32000 -ClientTop -32000 -ClientWidth 0 -ClientHeight 0
[HoneyNogiInput]::Iconic = $true
$script:restoreCalls = 0
$clickRestored = Get-FinalClickInWindow
Check-Equal '최소화: 복원 뒤의 창으로 재서 1272 자리를 누름' "$($clickRestored.X),$($clickRestored.Y)" "$($click1272.X),$($click1272.Y)"
Check-Equal '최소화: 복원 대기는 정확히 1번' $script:restoreCalls 1
# 끝내 복원되지 않으면 대기 1번 뒤 Click-GamePoint 와 같은 문구로 끝나고 클릭이 없습니다 (구현 리뷰 P2 - 대기가 두 번이면 둘째에서 풀린 창에 대체 자리를 재지 않고 눌렀습니다)
$script:restoreSucceeds = $false
Set-WindowFixture -Left -32000 -Top -32000 -Width 160 -Height 28 -ClientLeft -32000 -ClientTop -32000 -ClientWidth 0 -ClientHeight 0
[HoneyNogiInput]::Iconic = $true
$script:restoreCalls = 0
$script:lastClick = $null
$restoreFailure = ''
try { Click-NoticeBoardClose -Game $game } catch { $restoreFailure = $_.Exception.Message }
Check-Equal '최소화: 복원 실패면 대기 1번 · 기존 문구 · 클릭 없음' "$($script:restoreCalls)/$restoreFailure/$($null -eq $script:lastClick)" '1/게임 창이 최소화되어 있습니다./True'
[HoneyNogiInput]::Iconic = $false
$script:restoreSucceeds = $true

# 창 정보를 못 읽으면 대체 자리입니다. 각 호출이 실패하는 경우를 따로 봅니다
$fallbackText = "$($noticeBoardConfigMark[0]),$($noticeBoardConfigMark[1])"
$fallbackCases = @(
  @{ Name = 'GetWindowRect 실패'; Field = 'WindowRectOk' },
  @{ Name = 'GetClientRect 실패'; Field = 'ClientRectOk' },
  @{ Name = 'ClientToScreen 실패'; Field = 'ClientOriginOk' })
foreach ($fallbackCase in $fallbackCases) {
  Set-WindowFixture @window1272
  [HoneyNogiInput]::($fallbackCase.Field) = $false
  Check-Equal "대체 자리: $($fallbackCase.Name)" (@(Get-NoticeCloseReferencePoint -Game $game) -join ',') $fallbackText
}
Set-WindowFixture @window1272
$zeroClient = New-Object HoneyNogiInput+RECT
[HoneyNogiInput]::ClientRect = $zeroClient
Check-Equal '대체 자리: 클라이언트 크기 0' (@(Get-NoticeCloseReferencePoint -Game $game) -join ',') $fallbackText
Set-WindowFixture @window1272
[HoneyNogiInput]::ClientThrows = $true
$script:logs.Clear()
Check-Equal '대체 자리: 창 API 예외' (@(Get-NoticeCloseReferencePoint -Game $game) -join ',') $fallbackText
Check-True '대체 자리: 예외는 진단 줄 1' (@($script:logs | Where-Object { $_ -match '공지 X 자리를 계산하지 못해' }).Count -eq 1) "($($script:logs -join ' / '))"
Set-WindowFixture @window1272

# ── §2. 그림 재생 ──
function Measure-GlyphCenter {
  # 고정 상자 안의 밝은 픽셀 범위 가운데입니다. 상자는 계산 자리와 무관하게 그림에서 정했습니다 - 계산이 틀어져도 상자는 따라가지 않습니다
  param([string]$Path, [int]$Left, [int]$Top, [int]$Right, [int]$Bottom, [int]$Threshold)
  $bitmap = [System.Drawing.Bitmap]::FromFile($Path)
  try {
    $minX = [int]::MaxValue; $maxX = -1; $minY = [int]::MaxValue; $maxY = -1
    for ($y = $Top; $y -lt $Bottom; $y++) {
      for ($x = $Left; $x -lt $Right; $x++) {
        $pixel = $bitmap.GetPixel($x, $y)
        if ([Math]::Min([Math]::Min($pixel.R, $pixel.G), $pixel.B) -gt $Threshold) {
          if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
          if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
        }
      }
    }
    if ($maxX -lt 0) { return $null }
    return @{ X = ($minX + $maxX) / 2.0; Y = ($minY + $maxY) / 2.0; Width = $maxX - $minX + 1; Height = $maxY - $minY + 1; ImageWidth = $bitmap.Width; ImageHeight = $bitmap.Height }
  } finally {
    $bitmap.Dispose()
  }
}
$imageRoot = Join-Path $root '던전이미지'
if (-not (Test-Path -LiteralPath $imageRoot)) {
  "SKIP §2 그림 재생: 던전이미지 폴더가 없어 건너뜁니다 (로컬 전용 - 개발 PC 외): $imageRoot"
} else {
  $pictureRows = @(
    @{ Id = '1272'; File = '공지게시판_1272_클릭전.png'; Window = $window1272; Box = @(1062, 134, 1096, 163) },
    @{ Id = '1908'; File = '공지게시판_1908_클릭전.png'; Window = $window1908; Box = @(1610, 188, 1660, 226) })
  foreach ($pictureRow in $pictureRows) {
    $picturePath = Join-Path $imageRoot "어비스\20261104_복귀연장_실기\$($pictureRow.File)"
    if (-not (Test-Path -LiteralPath $picturePath)) {
      "FAIL §2 그림 없음 ($($pictureRow.Id)): $picturePath - 폴더를 옮겼다면 이 테스트의 경로도 함께 고칠 것"; $fails++
      continue
    }
    $glyph = Measure-GlyphCenter -Path $picturePath -Left $pictureRow.Box[0] -Top $pictureRow.Box[1] -Right $pictureRow.Box[2] -Bottom $pictureRow.Box[3] -Threshold 110
    if ($null -eq $glyph) { "FAIL §2 $($pictureRow.Id) 상자 안에 글자가 없습니다"; $fails++; continue }
    Check-Equal "§2 $($pictureRow.Id): 그림 크기가 창 크기" "$($glyph.ImageWidth)x$($glyph.ImageHeight)" "$($pictureRow.Window.Width)x$($pictureRow.Window.Height)"
    Check-True "§2 $($pictureRow.Id): 찾은 것이 X 글자 크기 (커서가 아님 - 글자는 창 높이의 약 1.7%)" (($glyph.Width -le 24) -and ($glyph.Height -le 24) -and ($glyph.Width -ge 8) -and ($glyph.Height -ge 8)) "($($glyph.Width)x$($glyph.Height))"
    $windowFixture = $pictureRow.Window
    Set-WindowFixture @windowFixture
    $pictureClick = Get-FinalClickInWindow
    Check-True "§2 $($pictureRow.Id): 최종 클릭점이 그림의 글자 중심 ±3" ((Test-Near $pictureClick.X $glyph.X 3) -and (Test-Near $pictureClick.Y $glyph.Y 3)) "(클릭 $($pictureClick.X),$($pictureClick.Y) / 글자 $($glyph.X),$($glyph.Y))"
    if ($pictureRow.Id -eq '1272') {
      # 이 행이 힘이 있는지: 11-05 에 42번 빗나간 옛 고정점은 같은 잣대를 통과하지 못해야 합니다
      Check-True '§2 1272: 옛 고정점 (1092,135) 는 같은 ±3 잣대에서 탈락' (-not ((Test-Near 1092 $glyph.X 3) -and (Test-Near 135 $glyph.Y 3))) "(글자 $($glyph.X),$($glyph.Y))"
    }
  }
}

# ── §3. 배선 ──
$workerCode = Remove-SourceComments -Text $workerText
Check-Equal '배선: 옛 고정점 변수가 소스에 없음' ([regex]::Matches($workerCode, '\$ptNoticeClose\b').Count) 0
Check-Equal '배선: 공지 자리를 고정 좌표로 직접 누르는 호출이 없음' ([regex]::Matches($workerCode, 'Click-GamePoint[^\r\n]*\$ptNoticeBoardClose').Count) 0
Check-Equal '배선: 공지를 닫는 8곳이 모두 공용 입구를 씀' ([regex]::Matches($workerCode, 'Click-NoticeBoardClose -Game \$Game').Count) 8
Check-Equal '배선: 대체 자리는 자리 함수 안 1곳에서만 읽음' ([regex]::Matches($workerCode, '\$ptNoticeBoardClose\b').Count) 2
$shippedConfig = Get-Content -LiteralPath (Join-Path $root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Check-Equal '배선: 내장 config 에 대체 자리 키가 남아 있음 (configSchemaVersion 을 안 올린 전제)' (@($shippedConfig.clickPoints.noticeBoardClose).Count) 2

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
