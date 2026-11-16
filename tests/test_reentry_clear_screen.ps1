# 재입장 대기 클리어 화면 복구 · 진단 보강 회귀 (재입장대기_클리어화면 설계 v3 - 2026-11-16 신설)
# 사고: 2026-11-16 14:14 어비스 '다시 하기'(우연한 만남) 뒤 재입장 대기가 300초 동안 던전 안 2연속을 못 봐 코드 4 로 멈췄는데, 정지 캡처는 새 판의
#   클리어 화면이었다(새 판에 들어가 클리어까지 끝났는데 워커가 입장을 놓침 - 그 뒤 4시간 넘게 정지). 여기서 고정하는 것:
#   §1 순수 함수 - 클리어 화면 확신 단계(Get-AbyssClearPromptTextLevel) · 점수표 서명(Test-AbyssClearScoreText - Test-DungeonClearPrompt 의 같은 식과 글자 일치)
#       · 진단 집계 줄(Format-AbyssReentryDiagSummary)
#   §2 실측 재생 - 정지 캡처(새 판 클리어 화면)를 워커 판독 함수로 읽으면 분류 prompt · 확신 단계 strong / 같은 날 던전 안 캡처는 none
#   §3 추론 재입장 터치 루프(Invoke-AbyssPromptTimeoutClearTouch)의 전이 계약 - 클릭 전 보상 음성 → 엄격 클리어 화면에서 전송 → 전송 뒤 보상 양성만 성공.
#       실제 파티원 시계로 양보·캡처 실패 마감 연장(규칙 4·15) · 같은 회전 복구 회전 폐기 · 규칙 4 재클릭 · 전송 뒤 커서 미확인 · 스윕 회전 · 비전이 끝 진단 줄
#       (2026-11-16 다관점 리뷰 반영 - 설계 8.7·8.8)
#   §4 그 끝 함수(Complete-AbyssPromptTimeoutClearTouch) - 성공이면 돌아오고 그 밖은 [완료] + 코드 4 (꼬리 = 커스텀/비커스텀의 다음 시작 · reward-before-click 만 놓아줌 표지)
#   §5 추론 재입장 끝(Complete-AbyssPromptTimeoutHandoff) - 표지 저장 성공일 때만 재입장 완료 끝으로, 실패면 [경고] 뒤 돌아감
#   §6 표지 저장(Set-AbyssJournalReenteredBy) - retry-* 항목에만 reenteredBy 칸을 만듦
#   §7 Consume-Handoff 가 next 항목의 표지를 옮김
#   §8 배선 - 시간 초과 갈래 · 본류 S 갈래 · 연속 끊김 자리 수 · 결과 키 · 호출 자리 · 터치 루프 결론·진단 자리 · 본류 이벤트 정리 건너뜀 조건
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
  # 줄 단독 exit 를 센티널 throw('__EXIT__N')로 바꿉니다 (test_abyss_party_leader.ps1 과 같은 구현) - 같은 프로세스에서 exit 함수를 돌리려고
  param([string]$Text)
  return ($Text -replace '(?m)^(\s*)exit (\d+)\s*$', '$1throw "__EXIT__$2"')
}
# 소스 상수 대입문 실행 (config 미정의 → 기본값)
$config = $null
function Get-ConfigValue { param($Root, [string[]]$Path, $Default) return $Default }
function Get-ConfigInteger { param($Root, [string[]]$Path, $Default, $Min, $Max) return $Default }
foreach ($constantName in @('referenceWidth', 'referenceHeight', 'rgClearExit', 'rgClearScore', 'rgAbyssMenu', 'rgHomeEndEsc', 'rgQuestTracker', 'ptClearCenter', 'timeoutExit', 'memberSweepStreakLimit')) {
  $assign = $workerAst.Find({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq ('$' + $constantName)) }, $true)
  if (-not $assign) { "FAIL 준비: 워커에서 `$$constantName 대입을 찾지 못했습니다"; exit 1 }
  Invoke-Expression $assign.Extent.Text
}
$allDungeonKeywords = @('정박', '광기', '물길')

# ── §1 순수 함수 ──
foreach ($name in @('Get-AbyssClearPromptTextLevel', 'Test-AbyssClearScoreText', 'Format-AbyssReentryDiagSummary', 'Format-AbyssTouchDiagSummary')) { Invoke-Expression (Get-WorkerFunctionText $name) }
$levelRows = @(
  @('11-16 정지 캡처 판독', '화면을터치해주세요', 'strong'),
  @('07-16 치 깨짐', '화면을터夫6주', 'strong'),
  @('07-18 터 소실', '화면을치해주세요', 'strong'),
  @('08-13 면·터 깨짐 s3', '화D을1치ö주세요', 'strong'),
  @('08-13 s2', '호을4치6주세요', 'strong'),
  @('08-13 s4', '호十D을터치ö주세요', 'strong'),
  @('07-17 면 깨짐(파손 골격)', '화n을터치해주l요', 'strong'),
  @('07-19 캐릭터 겹침 1', '면百치해', 'weak'),
  @('07-19 캐릭터 겹침 2', '화면치6H天서j“', 'weak'),
  @('비대상 경험치', '경험치 고二', 'none'),
  @('비대상 보상 확인', '보상을확인해주세요', 'none'),
  @('3버튼 보상 하단', '아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기', 'none'),
  @('재매칭 패널 하단', '사제아이템을누르면상세정보를7나가기', 'none'),
  @('나가기 섞인 클리어 문구(제외 우선)', '화면을터치해주세요나가기', 'none'),
  @('권장 인원 팝업', '㉬취소Space도전하기', 'none'),
  @('합성 - 클리어 문구 위 권장 인원 팝업(관측 없음 · 취소+도전하 갈래 고정용)', '화면을터치해주세요취소Space도전하기', 'none'),
  @('로딩 팁 꼴 단독 낱말', '스킬을터치하면자동으로사용합니다', 'none'),
  @('빈 값', '', 'none'),
  @('공백 섞인 정상 문구', '화면을 터치해 주세요', 'strong'))
foreach ($levelRow in $levelRows) {
  Check-Equal ('§1 확신 단계 - {0} ''{1}''' -f $levelRow[0], $levelRow[1]) (Get-AbyssClearPromptTextLevel -Text $levelRow[1]) $levelRow[2]
}
foreach ($scoreRow in @(
    @('빠른처치완벽한전투', $true), @('빠른 처치 협동 보너스', $true), @('처치', $false), @('완벽한전투협동보너스', $false), @('', $false))) {
  Check-Equal ('§1 점수표 서명 ''{0}''' -f $scoreRow[0]) (Test-AbyssClearScoreText -Text $scoreRow[0]) $scoreRow[1]
}
# 두 사본의 식 일치 - Test-DungeonClearPrompt 의 마지막 return 식과 Test-AbyssClearScoreText 의 마지막 return 식이 글자 그대로 같아야 합니다
$promptReturns = @($functionAsts['Test-DungeonClearPrompt'].FindAll({ param($node) $node -is [System.Management.Automation.Language.ReturnStatementAst] }, $true))
$scoreReturns = @($functionAsts['Test-AbyssClearScoreText'].FindAll({ param($node) $node -is [System.Management.Automation.Language.ReturnStatementAst] }, $true))
$promptScoreExpr = $(if ($promptReturns.Count -gt 0) { Get-CodeOnly $promptReturns[-1].Extent.Text } else { '(없음)' })
$scoreExpr = $(if ($scoreReturns.Count -gt 0) { Get-CodeOnly $scoreReturns[-1].Extent.Text } else { '(없음)' })
Check-Equal '§1 점수표 식 = Test-DungeonClearPrompt 보조 신호 식과 글자 일치 (두 사본이 갈라지지 않게)' $scoreExpr $promptScoreExpr
$summaryCounts = @{ 'prompt' = 3; 'unknown' = 5; 'inside' = 1 }
$summaryLine = Format-AbyssReentryDiagSummary -Context "'다시 하기' 뒤 입장 대기" -Stage '시간 초과' -KindCounts $summaryCounts -InsideMax 1 -LastKind 'prompt' -PromptStreak 3 `
  -YieldTurns 1 -SweepTurns 2 -RecoveredTurns 0 -ReadFailTurns 4 -TrackerText ('가' * 70) -BottomText '화면을터치해주세요'
Check-Equal '§1 집계 줄 - 정해진 차례(inside · unknown · prompt) · 판독문 60자 자름 · [진단] 머리' $summaryLine `
  ("[진단] '다시 하기' 뒤 입장 대기 시간 초과 분류 집계 - inside 1 · unknown 5 · prompt 3 (던전 안 최장 1연속 · 끝 분류 'prompt' · 엄격 클리어 화면 3연속) / 판독 없는 회전: 양보 1 · 스윕 2 · 탐침 복구 0 · 판독 실패 4 / 마지막 추적기 '" + ('가' * 60) + "' · 마지막 하단 '화면을터치해주세요'")
Check-True '§1 집계 줄 - 유효 표본이 없으면 그렇게 적음' ((Format-AbyssReentryDiagSummary -Context 'c' -Stage 's' -KindCounts @{} -InsideMax 0 -LastKind '' -PromptStreak 0 -YieldTurns 0 -SweepTurns 0 -RecoveredTurns 0 -ReadFailTurns 0 -TrackerText '' -BottomText '').Contains(' - 유효 표본 없음 ('))
# 터치 루프 집계 줄 (설계 8.7) - 다섯 칸을 늘 같은 차례로(0 칸도 적음) · 합계 = 유효 회전 · 판독문 60자
$touchSummary = Format-AbyssTouchDiagSummary -Result 'timeout' -KindCounts @{ strict = 2; loose = 3; other = 1 } -Sends 1 -ClickYields 3 -CursorMissesBefore 0 -CursorMissesAfter 2 `
  -YieldTurns 1 -SweepTurns 0 -RecoveredTurns 1 -ReadFailTurns 1 -BottomText ('나' * 70)
Check-Equal '§1 터치 집계 줄 - 다섯 칸 고정 차례 · 합계 = 유효 회전 · 클릭 조작 생략 · 커서 미확인 전송 전/뒤 · 판독문 60자 · [진단] 머리' $touchSummary `
  ("[진단] 추론 재입장 클리어 화면 터치 timeout 집계 - 유효 회전 6 (보상 0 · 패널 0 · 엄격 클리어 화면 2 · 느슨한 클리어 화면 3 · 그 밖 1) · 터치 전송 1 · 클릭 조작 생략 3 · 커서 미확인 전송 전 0 · 전송 뒤 2 / 판독 없는 회전: 양보 1 · 스윕 0 · 탐침 복구 1 · 판독 실패 1 / 마지막 하단 '" + ('나' * 60) + "'")

# ── §2 실측 재생 (정지 캡처 · 같은 날 던전 안 캡처) ──
$imageRoot = Join-Path $projectRoot '던전이미지'
$evidenceDir = Join-Path $imageRoot '어비스\20261116_v2112_재입장대기300초_새판클리어화면_정지'
$replayImages = [ordered]@{
  Clear  = Join-Path $evidenceDir 'error_20261116_h14m19s04_정지순간_새판클리어화면.png'
  Inside = Join-Path $evidenceDir 'error_20261116_h13m57s32_클리어대기필드판정_추적기깨짐.png'
}
if (-not (Test-Path -LiteralPath $imageRoot)) {
  "SKIP §2 실측 재생: 던전이미지 폴더가 없어 건너뜁니다 (로컬 전용 - 개발 PC 외): $imageRoot"
} else {
  $missingImages = @($replayImages.Values | Where-Object { -not (Test-Path -LiteralPath $_) })
  foreach ($missingImage in $missingImages) { "FAIL §2 재생 그림 없음: $missingImage - 폴더를 옮겼다면 이 테스트의 경로도 함께 고칠 것"; $fails++ }
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
  } elseif ((-not $ocrKoreanEngine) -or (-not $ocrEnglishEngine)) {
    'SKIP §2 실측 재생: ko · en-US OCR 엔진을 만들 수 없어 건너뜁니다 (언어 팩 없음)'
  } else {
    # 워커 캡처 본문 그대로 - 화면 취득 한 줄만 그림의 같은 자리를 옮기는 것으로 바꿉니다 (test_abyss_esc_point_offline.ps1 §3 과 같은 방식)
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
    foreach ($name in @('Invoke-OcrOnBitmap', 'Await-WinRt', 'Get-GameRegionOcrText', 'Get-GameOcrText', 'Test-DungeonClearPrompt', 'Test-ExitButton', 'Test-AbyssRewardText',
        'Get-AbyssPanelKind', 'Test-AbyssReadyPanelText', 'Test-AbyssMatchingPanelText', 'Test-HomeEndEscHud', 'Test-InDungeonQuest', 'Resolve-AbyssHandoffStartScreen',
        'Test-AbyssFewMembersPopupText', 'Test-AbyssEntryWaitingText')) {
      Invoke-Expression (Get-WorkerFunctionText $name)
    }
    function Read-ReplayFrame {
      param([string]$Path)
      $script:replayWindow = New-Object System.Drawing.Bitmap($Path)
      try {
        [HoneyNogiInput]::WindowWidth = $script:replayWindow.Width
        [HoneyNogiInput]::WindowHeight = $script:replayWindow.Height
        $prompt = Test-DungeonClearPrompt -Game $fakeGame
        $bottom = [string]$script:lastClearPromptText
        $panel = Get-AbyssPanelKind -Game $fakeGame
        $hud = Test-HomeEndEscHud -Game $fakeGame
        $quest = $(if ($hud) { Test-InDungeonQuest -Game $fakeGame } else { $false })
        $exit = Test-ExitButton -Game $fakeGame
        return [pscustomobject]@{
          Prompt = $prompt; Bottom = $bottom; Panel = $panel; Exit = $exit; Level = (Get-AbyssClearPromptTextLevel -Text $bottom)
          Kind = (Resolve-AbyssHandoffStartScreen -PromptVisible $prompt -BottomText $bottom -PanelKind $panel -HudVisible $hud -InDungeonQuest $quest)
        }
      } finally { $script:replayWindow.Dispose(); $script:replayWindow = $null }
    }
    $clearFrame = Read-ReplayFrame $replayImages.Clear
    "  (정지 캡처 하단 판독: '$($clearFrame.Bottom)')"
    Check-Equal '§2 정지 캡처(14:19:04 새 판 클리어 화면) - 분류 prompt' $clearFrame.Kind 'prompt'
    Check-Equal '§2 정지 캡처 - 확신 단계 strong (B 의 엄격 표본)' $clearFrame.Level 'strong'
    Check-Equal '§2 정지 캡처 - 보상 3버튼 아님 · 패널 없음' ('{0}/{1}' -f $clearFrame.Exit, $clearFrame.Panel) 'False/none'
    $insideFrame = Read-ReplayFrame $replayImages.Inside
    "  (던전 안 캡처 하단 판독: '$($insideFrame.Bottom)')"
    Check-Equal '§2 같은 날 던전 안 캡처(13:57:32) - 클리어 문구 아님 · 확신 단계 none' ('{0}/{1}' -f $insideFrame.Prompt, $insideFrame.Level) 'False/none'
  }
}

# ── §3 추론 재입장 터치 루프 - 전이 계약 · 규칙 4·15 (실제 파티원 시계 · 가상 시각) ──
# 판독 회전마다 프레임 하나를 씁니다(첫 판독 Test-ExitButton 이 다음 프레임으로 넘김 - 마지막 프레임은 계속 남음. 동결·양보·스윕·탐침 복구 뒤 회전은 프레임을
#   쓰지 않음). 프레임 키: Exit · Prompt · Bottom · Score · Panel = 화면 / Fail = 첫 판독에서 캡처 실패(다음 회전부터 동결 - Probes 번째 탐침에서 복구, 기본 1) /
#   Recover = 같은 회전 복구(첫 판독 실패 → 뒤 판독 성공: 플래그는 풀리고 일련번호만 바뀜 - ⑦ 이 판정·클릭 없는 복구 회전으로 봐야 함)
# 마감은 워커의 실제 파티원 시계(New-AbyssMemberClock 묶음 · Get-CaptureFailTotalMs)로 잽니다 - 양보·캡처 실패 차분만큼 늘고 되돌리지 않아야 합니다(규칙 4·15 -
#   다관점 리뷰 2026-11-16: 옛 모의 시계는 벽시계라 이 계약을 못 봤음)
foreach ($name in @('Invoke-AbyssPromptTimeoutClearTouch', 'Resolve-AbyssMemberSweepTurn', 'Format-AbyssTouchDiagSummary', 'New-AbyssMemberClock', 'Set-AbyssMemberClock',
    'Update-AbyssMemberClockFreeze', 'Test-AbyssMemberClockExpired', 'Get-FreezeAdjustedDeadline', 'Get-YieldAdjustedDeadline', 'Get-CaptureFailTotalMs')) {
  Invoke-Expression (Get-WorkerFunctionText $name)
}
$script:vnow = [datetime]'2026-11-16 14:20:00'
function Get-Date { return $script:vnow }                                             # 가상 시계 (3초 재클릭 · 마감 · 캡처 실패 누적)
function Start-Sleep { param([int]$Seconds = 0, [int]$Milliseconds = 0) $script:vnow = $script:vnow.AddSeconds($Seconds).AddMilliseconds($Milliseconds) }
function Register-MockFail {
  # 캡처 실패 등록 - 워커 Register-CaptureFailure 의 상태 계약만(구간 시작 시각 · 일련번호 +1 · 플래그)
  if (-not $script:screenCaptureFailing) { $script:captureFailingSince = $script:vnow }
  $script:screenCaptureFailing = $true
  $script:captureFailSerial++
}
function Register-MockSuccess {
  # 캡처 성공 등록 - 워커 Register-CaptureSuccess 의 상태 계약만(끝난 실패 구간을 누적에 더하고 플래그를 풂)
  if ($script:screenCaptureFailing -and ($null -ne $script:captureFailingSince)) {
    $script:captureFailTotalMs = [double]$script:captureFailTotalMs + ($script:vnow - [datetime]$script:captureFailingSince).TotalMilliseconds
  }
  $script:screenCaptureFailing = $false
  $script:captureFailingSince = $null
}
function Get-Frame { return $script:frames[[Math]::Min([Math]::Max($script:frameIndex, 0), $script:frames.Count - 1)] }
function Test-ExitButton {
  # 판독 회전의 첫 판독 - 여기서 다음 프레임으로 넘어갑니다
  param($Game)
  $script:frameIndex++
  $frame = Get-Frame
  if ($frame.Fail -or $frame.Recover) {
    Register-MockFail
    if ($frame.Fail) { $script:probesLeft = $(if ($frame.Probes) { [int]$frame.Probes } else { 1 }) }
    return $false
  }
  return [bool]$frame.Exit
}
function Test-DungeonClearPrompt {
  param($Game)
  $frame = Get-Frame
  if ($frame.Fail) { $script:lastClearPromptText = ''; return $false }   # 캡처 실패 중 판독 = 빈 판독문(공용 판독 계약)
  if ($frame.Recover) { Register-MockSuccess }                          # 같은 회전 뒤 판독 성공 - 플래그만 풀림(일련번호는 첫 판독에서 이미 바뀜)
  $script:lastClearPromptText = ([string]$frame.Bottom) -replace '\s', ''
  return [bool]$frame.Prompt
}
function Read-AbyssClearScoreText { param($Game) $script:scoreReads++; return [string](Get-Frame).Score }
function Get-AbyssPanelKind { param($Game) $frame = Get-Frame; if ($frame.Panel) { return [string]$frame.Panel }; return 'none' }
function Invoke-PurchasePopupSweep {
  # 팝업 스윕 - 계획의 다음 칸: '' = 거짓 / 'sent' = 스윕이 닫기 클릭을 보냄(참 · 전송 메타 → 분류 'counted' - 판독 없이 다음 회전)
  param($Game)
  $sweepPlanItem = ''
  if ($script:sweepPlan.Count -gt 0) { $sweepPlanItem = [string]$script:sweepPlan[0]; $script:sweepPlan.RemoveAt(0) }
  if ($sweepPlanItem -eq 'sent') { $script:sweeps++; $script:lastClickPerformed = $true; $script:lastClickSkipReason = ''; return $true }
  return $false
}
function Test-UserRecentlyActive {
  # 조작 감지 - 계획의 다음 칸(없으면 거짓)
  if ($script:activePlan.Count -gt 0) { $activeNow = [bool]$script:activePlan[0]; $script:activePlan.RemoveAt(0); return $activeNow }
  return $false
}
function Wait-UserYieldEnd {
  # 양보 - 조작이 끝날 때까지 기다린 시간(행의 YieldSeconds)만큼 가상 시각과 양보 누적을 늘림(워커 Wait-UserYieldEnd 의 누적 계약)
  param($Game, $Context)
  $script:yields++
  $script:vnow = $script:vnow.AddSeconds($script:yieldSeconds)
  $script:userYieldTotalMs = [double]$script:userYieldTotalMs + ($script:yieldSeconds * 1000)
}
function Test-SafeStopDuringCaptureFail { $script:safeStops++ }
function Test-CaptureRecovered {
  # 탐침 - 프레임이 정한 횟수째에 복구
  param($Game)
  $script:probeCalls++
  $script:probesLeft--
  if ($script:probesLeft -le 0) { Register-MockSuccess }
  return (-not $script:screenCaptureFailing)
}
function Focus-Game { param($Game) }
function Click-GamePoint {
  param($Game, $ReferenceX, $ReferenceY)
  $script:clickAttempts++
  $script:clickPoints.Add(('{0},{1}' -f $ReferenceX, $ReferenceY))
  $script:clickFrames.Add([string]$script:frameIndex)
  $plan = 'sent'
  if ($script:clickPlan.Count -gt 0) { $plan = [string]$script:clickPlan[0]; $script:clickPlan.RemoveAt(0) }
  $script:lastClickPerformed = ($plan -eq 'sent')
  $script:lastClickSkipReason = $(if ($plan -eq 'user-active') { 'user-active' } elseif ($plan -eq 'cursor') { 'cursor-not-ready' } else { '' })
  if ($script:lastClickPerformed) { $script:clicksSent++ }
}
function Write-RunLog { param([string]$Message) $script:logs.Add($Message) }
function Invoke-TouchRow {
  param([object[]]$Frames, [string[]]$ClickPlan = @(), [object[]]$ActivePlan = @(), [string[]]$SweepPlan = @(), [int]$YieldSeconds = 5)
  $script:frames = $Frames
  $script:frameIndex = -1
  $script:clickPlan = New-Object System.Collections.Generic.List[string]
  foreach ($planItem in $ClickPlan) { $script:clickPlan.Add($planItem) }
  $script:activePlan = New-Object System.Collections.Generic.List[object]
  foreach ($activeItem in $ActivePlan) { $script:activePlan.Add([bool]$activeItem) }
  $script:sweepPlan = New-Object System.Collections.Generic.List[string]
  foreach ($sweepItem in $SweepPlan) { $script:sweepPlan.Add($sweepItem) }
  $script:yieldSeconds = $YieldSeconds
  $script:clickPoints = New-Object System.Collections.Generic.List[string]
  $script:clickFrames = New-Object System.Collections.Generic.List[string]
  $script:logs = New-Object System.Collections.Generic.List[string]
  $script:clickAttempts = 0; $script:clicksSent = 0; $script:yields = 0; $script:safeStops = 0; $script:scoreReads = 0; $script:sweeps = 0; $script:probeCalls = 0
  $script:screenCaptureFailing = $false; $script:captureFailSerial = 0; $script:captureFailCause = $null; $script:captureFailingSince = $null
  $script:captureFailTotalMs = [double]0; $script:userYieldTotalMs = [double]0; $script:probesLeft = 0
  $script:lastClickPerformed = $true; $script:lastClickSkipReason = 'user-active'   # 묵은 메타로 시작 - 서두 비움을 행동으로 봄
  $startAt = $script:vnow
  $result = Invoke-AbyssPromptTimeoutClearTouch -Game $null
  $diagLines = @($script:logs | Where-Object { $_.StartsWith('[진단] ') })
  return [pscustomobject]@{ Result = [string]$result; Attempts = $script:clickAttempts; Sent = $script:clicksSent; Yields = $script:yields; SafeStops = $script:safeStops
    ScoreReads = $script:scoreReads; Seconds = ($script:vnow - $startAt).TotalSeconds; Points = ($script:clickPoints -join ' '); Logs = $script:logs.ToArray()
    ClickFrames = ($script:clickFrames -join ','); ReadTurns = ($script:frameIndex + 1); FailSeconds = ([double]$script:captureFailTotalMs / 1000.0); Sweeps = $script:sweeps
    DiagCount = $diagLines.Count; Diag = $(if ($diagLines.Count -eq 1) { [string]$diagLines[0] } else { '(진단 줄 {0}개)' -f $diagLines.Count }) }
}
$touchLimit = $timeoutExit + 15   # 터치 루프 마감(소스 상수에서 - 지금 S 갈래와 같은 예산)
function Get-TouchDiagWant {
  # 진단 줄 기대값 - 행 기록에서 유효 회전 수를 받아 서식 함수 없이 글자로 짭니다(서식 함수 변이도 잡히게)
  param([string]$Result, [int]$Reward = 0, [int]$Panel = 0, [int]$Strict = 0, [int]$Loose = 0, [int]$Other = 0, [int]$Sends = 0, [int]$ClickYield = 0, [int]$Before = 0, [int]$After = 0,
    [int]$Yield = 0, [int]$Sweep = 0, [int]$Recovered = 0, [int]$ReadFail = 0, [string]$Bottom = '')
  return ("[진단] 추론 재입장 클리어 화면 터치 $Result 집계 - 유효 회전 $($Reward + $Panel + $Strict + $Loose + $Other) (보상 $Reward · 패널 $Panel · 엄격 클리어 화면 $Strict · 느슨한 클리어 화면 $Loose · 그 밖 $Other) · 터치 전송 $Sends · 클릭 조작 생략 $ClickYield · 커서 미확인 전송 전 $Before · 전송 뒤 $After / 판독 없는 회전: 양보 $Yield · 스윕 $Sweep · 탐침 복구 $Recovered · 판독 실패 $ReadFail / 마지막 하단 '$Bottom'")
}
$S = @{ Prompt = $true; Bottom = '화면을터치해주세요'; Exit = $false }
$R = @{ Prompt = $false; Bottom = '아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기'; Exit = $true }
$L = @{ Prompt = $true; Bottom = '스킬을터치하면자동으로사용합니다'; Exit = $false }
$W = @{ Prompt = $true; Bottom = '면百치해'; Score = '빠른처치완벽한전투'; Exit = $false }
$W0 = @{ Prompt = $true; Bottom = '면百치해'; Score = ''; Exit = $false }
$Sp = @{ Prompt = $true; Bottom = '화면을터치해주세요'; Exit = $false; Panel = 'matching' }
$Rp = @{ Prompt = $false; Bottom = '아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기'; Exit = $true; Panel = 'matching' }
$X = @{ Fail = $true }
$clearPointText = ('{0},{1}' -f $ptClearCenter[0], $ptClearCenter[1])
$row = Invoke-TouchRow @($S, $R)
Check-Equal '§3 T1 S → 클릭 전송 → 보상 = transition · 전송 1 · 클리어 중앙' ('{0}/{1}/{2}' -f $row.Result, $row.Sent, $row.Points) "transition/1/$clearPointText"
Check-True '§3 T1 첫 전송 안내 줄 1' (@($row.Logs | Where-Object { $_.StartsWith('[어비스] 클리어 화면 터치 전송 - ') }).Count -eq 1) ($row.Logs -join ' | ')
$row = Invoke-TouchRow @($R)
Check-Equal '§3 T2 첫 유효 판독부터 보상 = reward-before-click · 클릭 0' ('{0}/{1}' -f $row.Result, $row.Attempts) 'reward-before-click/0'
$row = Invoke-TouchRow @($L, $R)
Check-Equal '§3 T3 느슨한 클리어 문구(로딩 팁 꼴)는 누르지 않음 → 그 뒤 보상 = reward-before-click · 클릭 0' ('{0}/{1}' -f $row.Result, $row.Attempts) 'reward-before-click/0'
$row = Invoke-TouchRow @($W, $R)
Check-Equal '§3 T4 weak + 점수표 = 엄격 → 전송 → transition · 점수표 판독 1' ('{0}/{1}/{2}' -f $row.Result, $row.Sent, $row.ScoreReads) 'transition/1/1'
$row = Invoke-TouchRow @($W0)
Check-Equal '§3 T5 weak + 점수표 없음 = 누르지 않음 → 마감 timeout · 클릭 0' ('{0}/{1}' -f $row.Result, $row.Attempts) 'timeout/0'
Check-True '§3 T5 마감 = 지금 S 갈래와 같은 예산($timeoutExit + 15) 안팎' (($row.Seconds -ge ($timeoutExit + 15)) -and ($row.Seconds -lt ($timeoutExit + 15 + 3))) ('{0}초' -f $row.Seconds)
$row = Invoke-TouchRow @($Sp)
Check-Equal '§3 T6 패널 위 클리어 문구는 누르지 않음 → timeout · 클릭 0' ('{0}/{1}' -f $row.Result, $row.Attempts) 'timeout/0'
$row = Invoke-TouchRow @($S, $Rp, $R)
Check-Equal '§3 T6b 전송 뒤 패널 섞인 보상은 성공이 아님 → 다음 패널 없는 보상에서 transition' ('{0}/{1}' -f $row.Result, $row.Sent) 'transition/1'
$row = Invoke-TouchRow @($S, $S, $S, $S, $S, $S, $R)
Check-Equal '§3 T7 클리어 화면이 이어지면 3초 뒤 다시 전송 (0초 · 3.5초) → transition · 전송 2' ('{0}/{1}' -f $row.Result, $row.Sent) 'transition/2'
$row = Invoke-TouchRow @($S, $S, $R) @('user-active', 'sent')
Check-Equal '§3 T8 조작 생략 → 양보 · 새 판독으로 전송 → transition (시도 2 · 전송 1 · 양보 1)' ('{0}/{1}/{2}/{3}' -f $row.Result, $row.Attempts, $row.Sent, $row.Yields) 'transition/2/1/1'
$row = Invoke-TouchRow @($S) @('cursor', 'cursor', 'cursor')
Check-Equal '§3 T9 커서 미확인 3회 = skipped (전송 0)' ('{0}/{1}/{2}' -f $row.Result, $row.Attempts, $row.Sent) 'skipped/3/0'
$row = Invoke-TouchRow @($S, $X, $R)
Check-Equal '§3 T10 전송 뒤 판독 도중 캡처 실패 → 동결 · 복구 → 보상 = transition (안전 확인 1)' ('{0}/{1}/{2}' -f $row.Result, $row.Sent, $row.SafeStops) 'transition/1/1'
$row = Invoke-TouchRow @($S)
Check-True '§3 T11 보상이 안 나오면 마감 timeout · 전송 ≥ 2(3초 재전송)' (($row.Result -ceq 'timeout') -and ($row.Sent -ge 2)) ('{0}/{1}' -f $row.Result, $row.Sent)
$row = Invoke-TouchRow @($X, $R)
Check-Equal '§3 T12 첫 판독이 캡처 실패(음성 관측 아님) → 그 뒤 첫 보상 = reward-before-click · 클릭 0 (설계 리뷰 3차의 경로)' ('{0}/{1}' -f $row.Result, $row.Attempts) 'reward-before-click/0'

# ── §3 보강 (다관점 리뷰 2026-11-16 · 설계 8.7~8.8) - 마감 연장 · ⑦ 회전 폐기 · 규칙 4 재클릭 · 전송 뒤 커서 미확인 · 스윕 회전 · 진단 줄 ──
$Srec = @{ Recover = $true; Prompt = $true; Bottom = '화면을터치해주세요'; Exit = $false }
# T13 조작 20초 → 마감이 그만큼 늦게(양보 차분 - 규칙 4)
$row = Invoke-TouchRow @($W0) -ActivePlan @($false, $false, $true) -YieldSeconds 20
Check-True '§3 T13 클릭 없는 화면 · 셋째 회전에 조작 20초 → timeout · 양보 1 · 끝 = 마감 + 20초 무렵(양보는 마감에서 빠짐)' `
  (($row.Result -ceq 'timeout') -and ($row.Yields -eq 1) -and ($row.Seconds -ge ($touchLimit + 20)) -and ($row.Seconds -lt ($touchLimit + 20 + 3))) ('{0} · 양보 {1} · {2}초' -f $row.Result, $row.Yields, $row.Seconds)
# T14 판독 도중 캡처 실패 → 탐침 5번째에 복구 → 마감이 실패 구간만큼 늦게(동결 - 규칙 15 ①, 되돌림 없음)
$row = Invoke-TouchRow @($W0, $W0, @{ Fail = $true; Probes = 5 }, $W0)
Check-True '§3 T14 셋째 판독 캡처 실패 · 탐침 5번째 복구 → timeout · 안전 확인 5 · 실패 구간 ≥ 8초 · 끝 = 마감 + 실패 구간 무렵' `
  (($row.Result -ceq 'timeout') -and ($row.SafeStops -eq 5) -and ($row.FailSeconds -ge 8) -and ($row.Seconds -ge ($touchLimit + $row.FailSeconds - 0.001)) -and ($row.Seconds -lt ($touchLimit + $row.FailSeconds + 3))) `
  ('{0} · 안전 확인 {1} · 실패 {2}초 · 끝 {3}초' -f $row.Result, $row.SafeStops, $row.FailSeconds, $row.Seconds)
# T15 같은 회전 복구 회전의 엄격 클리어 화면은 누르지 않음 → 다음 유효 회전에서 누름(⑦ - 전이 계약의 '같은 유효 회전')
$row = Invoke-TouchRow @($Srec, $S, $R)
Check-Equal '§3 T15 같은 회전 복구 회전(엄격 S)은 판정·클릭 없음 → 다음 유효 S(둘째 프레임)에서 전송 → transition' ('{0}/{1}/{2}' -f $row.Result, $row.Sent, $row.ClickFrames) 'transition/1/1'
# T16 동결 뒤 탐침 복구 회전은 판독하지 않음(프레임을 안 씀) → 다음 회전이 클리어 화면을 읽고 누름(③)
$row = Invoke-TouchRow @(@{ Fail = $true }, $S, $R)
Check-Equal '§3 T16 첫 판독 캡처 실패 → 동결 1 · 탐침 복구 회전(판독 0) → 둘째 프레임 S 에서 전송 → transition · 판독 회전 3' ('{0}/{1}/{2}/{3}' -f $row.Result, $row.ClickFrames, $row.SafeStops, $row.ReadTurns) 'transition/1/1/3'
# T17 클릭이 조작으로 생략되면 양보 뒤 새 판독으로만 누름 - 그 판독이 느슨한 문구면 누르지 않음(규칙 4 - 옛 판독으로 재클릭 금지)
$row = Invoke-TouchRow @($S, $L, $R) @('user-active')
Check-Equal '§3 T17 S 에서 클릭 조작 생략 → 양보 → 다음 판독 느슨한 문구(누르지 않음) → 보상 = reward-before-click (시도 1 · 전송 0 · 양보 1)' ('{0}/{1}/{2}/{3}' -f $row.Result, $row.Attempts, $row.Sent, $row.Yields) 'reward-before-click/1/0/1'
# T18 조작 생략은 커서 예산을 쓰지 않음 - 생략 3번 뒤에도 skipped 가 아님(규칙 4)
$row = Invoke-TouchRow @($S, $S, $S, $S, $R) @('user-active', 'user-active', 'user-active', 'sent')
Check-Equal '§3 T18 조작 생략 3 → 넷째 전송 → transition (시도 4 · 전송 1 · 양보 3)' ('{0}/{1}/{2}/{3}' -f $row.Result, $row.Attempts, $row.Sent, $row.Yields) 'transition/4/1/3'
# T19 전송 뒤 재클릭의 커서 미확인은 결론을 바꾸지 않음 - 3번 넘게 나도 skipped 가 아니고 다음 재클릭 전송 · 전이로 이어짐(설계 8.8)
$row = Invoke-TouchRow @($S, $S, $S, $S, $S, $S, $S, $S, $S, $S, $R) @('sent', 'cursor', 'cursor', 'cursor', 'cursor')
Check-Equal '§3 T19 전송 뒤 3초 지나 재클릭 커서 미확인 4번 → skipped 아님 → 다음 재클릭 전송 → transition (시도 6 · 전송 2)' ('{0}/{1}/{2}' -f $row.Result, $row.Attempts, $row.Sent) 'transition/6/2'
# T20 재클릭은 엄격 클리어 화면이 그대로일 때만 - 전송 뒤 느슨한 문구가 3초 넘게 이어져도 다시 누르지 않음
$row = Invoke-TouchRow @($S, $L, $L, $L, $L, $L, $L, $R)
Check-Equal '§3 T20 전송 뒤 느슨한 문구 4.2초 → 재클릭 0 → 보상 = transition (시도 1)' ('{0}/{1}' -f $row.Result, $row.Attempts) 'transition/1'
# T21 스윕이 닫기를 보낸 회전은 판독·클릭 없음(프레임을 안 씀) → 다음 회전이 클리어 화면을 읽고 누름
$row = Invoke-TouchRow @($S, $R) -SweepPlan @('sent')
Check-Equal '§3 T21 첫 회전 스윕 전송 → 판독 0 → 다음 회전 S(첫 프레임)에서 전송 → transition (스윕 1 · 판독 회전 2)' ('{0}/{1}/{2}/{3}' -f $row.Result, $row.ClickFrames, $row.Sweeps, $row.ReadTurns) 'transition/0/1/2'
# D1 느슨한 문구만 → timeout 진단 줄(유효 회전 = 판독 회전 · 느슨 전부 · 마지막 하단 = 그 문구)
$row = Invoke-TouchRow @($L)
Check-Equal '§3 D1 느슨한 문구만 → timeout 진단 줄 1(유효 회전 = 판독 회전 · 느슨 전부)' $row.Diag (Get-TouchDiagWant -Result 'timeout' -Loose $row.ReadTurns -Bottom $L.Bottom)
# D2 reward-before-click 은 결론 회전(보상)도 셈 · 패널 회전은 패널 칸 · 마지막 하단 = 결론 회전 판독
$row = Invoke-TouchRow @($L, $Sp, $R)
Check-Equal '§3 D2 느슨 → 패널 위 S → 보상 = reward-before-click 진단 줄(보상 1 · 패널 1 · 느슨 1)' $row.Diag (Get-TouchDiagWant -Result 'reward-before-click' -Reward 1 -Panel 1 -Loose 1 -Bottom $R.Bottom)
# D3 skipped(첫 전송 전 커서 미확인 3) 진단 줄
$row = Invoke-TouchRow @($S) @('cursor', 'cursor', 'cursor')
Check-Equal '§3 D3 skipped 진단 줄(엄격 3 · 전송 0 · 커서 미확인 전송 전 3 · 뒤 0)' $row.Diag (Get-TouchDiagWant -Result 'skipped' -Strict 3 -Before 3 -Bottom $S.Bottom)
# D4 전송 뒤 커서 미확인은 '전송 뒤' 칸 - 보상이 끝내 안 나오면 timeout 진단 줄
$row = Invoke-TouchRow @($S) @('sent', 'cursor', 'cursor')
Check-Equal '§3 D4 전송 뒤 커서 미확인 2 → timeout 진단 줄(엄격 전부 · 전송 = 행 전송 수 · 전송 뒤 2)' $row.Diag (Get-TouchDiagWant -Result 'timeout' -Strict $row.ReadTurns -Sends $row.Sent -After 2 -Bottom $S.Bottom)
# D5 판독 없는 회전 칸 - 양보 1 · 판독 실패 2(같은 회전 복구 1 · 동결 시작 1) · 스윕 1 · 탐침 복구 1 · 유효 회전 = 판독 회전 − 판독 실패
$row = Invoke-TouchRow @($W0, $Srec, @{ Fail = $true }, $W0) -ActivePlan @($false, $true) -SweepPlan @('', '', 'sent')
Check-Equal '§3 D5 판독 없는 회전 칸(양보 1 · 스윕 1 · 탐침 복구 1 · 판독 실패 2) · 유효 회전 = 판독 회전 − 2(느슨 전부)' $row.Diag `
  (Get-TouchDiagWant -Result 'timeout' -Loose ($row.ReadTurns - 2) -Yield 1 -Sweep 1 -Recovered 1 -ReadFail 2 -Bottom $W0.Bottom)
# D6 전이 성공이면 진단 줄 0
$row = Invoke-TouchRow @($S, $R)
Check-Equal '§3 D6 transition → 진단 줄 0' $row.DiagCount 0
# D7 마지막 하단 = 마지막 유효 회전의 지역 판독 - 뒤에 판독 실패 회전만 이어져 전역 판독문이 바뀌어도 그대로(설계 리뷰 조건)
$row = Invoke-TouchRow @($L, @{ Recover = $true; Prompt = $false; Bottom = 'GLOBALLAST'; Exit = $false })
Check-Equal '§3 D7 유효 1 뒤 같은 회전 복구만 → 진단 줄 마지막 하단 = 유효 회전 판독(전역 아님) · 판독 실패 = 나머지 판독 회전' $row.Diag `
  (Get-TouchDiagWant -Result 'timeout' -Loose 1 -ReadFail ($row.ReadTurns - 1) -Bottom $L.Bottom)
# D8 클릭 조작 생략은 '클릭 조작 생략' 칸 - 그 회전은 유효 판독(엄격)이라 판독 없는 회전의 양보 칸에는 들지 않음(구현 리뷰 비차단 지적 반영)
$row = Invoke-TouchRow @($S, $L, $R) @('user-active')
Check-Equal '§3 D8 S 에서 클릭 조작 생략 → 느슨 → 보상 = reward-before-click 진단 줄(엄격 1 · 느슨 1 · 보상 1 · 클릭 조작 생략 1 · 양보 0)' $row.Diag `
  (Get-TouchDiagWant -Result 'reward-before-click' -Reward 1 -Strict 1 -Loose 1 -ClickYield 1 -Bottom $R.Bottom)

# ── §4 Complete-AbyssPromptTimeoutClearTouch ──
Invoke-Expression (Convert-ExitSentinel -Text (Get-WorkerFunctionText 'Complete-AbyssPromptTimeoutClearTouch'))
function Invoke-AbyssPromptTimeoutClearTouch { param($Game, $Context) return $script:touchStub }
function Write-LifeDiagnostics { param($Game, [string]$Context, [switch]$CaptureOnly, [switch]$WithLogCopy) $script:diagCalls.Add($Context) }
# 결과 × 커스텀 여부 (설계 8.8 · 다관점 리뷰 P3): reward-before-click = 선분기 next × 3버튼과 같은 사실이라 같은 놓아줌 표지 ' (release)' + 같은 커스텀/비커스텀 꼬리 /
#   skipped · timeout = 클리어 전 정지(넘긴 기록을 열어 둠 - 표지 없음), 커스텀은 다음 시작이 같은 판을 이어받고 비커스텀은 새 실행 id 라 Role none 이 화면을 마무리
$stopHeadRewardBefore = '[완료] 클리어 화면으로 추론해 넘겨받은 판인데 누르기 전부터 보상 화면이 보여 새 판의 클리어로 확인하지 못했습니다 - 계상 없이 정지합니다 '
$stopHeadSkipped = '[완료] 클리어 화면으로 추론해 넘겨받은 판의 클리어 화면을 커서 미확인으로 누르지 못했습니다 - 계상 없이 정지합니다 '
$stopHeadTimeout = "[완료] 클리어 화면으로 추론해 넘겨받은 판인데 클리어 화면이 이어지지 않거나 눌러도 $($timeoutExit + 15)초 안에 보상 화면이 나오지 않았습니다 - 계상 없이 정지합니다 "
$stopTailCustomRelease = '(이 판은 계상되지 않으며, 다음 시작은 정리 전용(코드 10) 뒤 같은 항목을 다시 돕니다) (release)'
$stopTailPlainRelease = '(다음 시작이 이 보상 화면을 마무리하며 그때 1회 계상합니다) (release)'
$stopTailCustomKeep = '(다음 시작이 같은 판을 이어받아 화면부터 다시 확인합니다)'
$stopTailPlainKeep = '(다시 시작하면 그 시작이 이 화면을 마무리하며, 클리어·보상 화면이면 그때 1회 계상합니다)'
foreach ($stopRow in @(
    @('transition', $true, ''),
    @('transition', $false, ''),
    @('reward-before-click', $true, ($stopHeadRewardBefore + $stopTailCustomRelease)),
    @('reward-before-click', $false, ($stopHeadRewardBefore + $stopTailPlainRelease)),
    @('skipped', $true, ($stopHeadSkipped + $stopTailCustomKeep)),
    @('skipped', $false, ($stopHeadSkipped + $stopTailPlainKeep)),
    @('timeout', $true, ($stopHeadTimeout + $stopTailCustomKeep)),
    @('timeout', $false, ($stopHeadTimeout + $stopTailPlainKeep)))) {
  $script:touchStub = $stopRow[0]
  $script:customMode = [bool]$stopRow[1]
  $script:logs = New-Object System.Collections.Generic.List[string]
  $script:diagCalls = New-Object System.Collections.Generic.List[string]
  $stopError = ''
  try { Complete-AbyssPromptTimeoutClearTouch -Game $null } catch { $stopError = [string]$_.Exception.Message }
  $lastLog = $(if ($script:logs.Count -gt 0) { $script:logs[$script:logs.Count - 1] } else { '' })
  $stopModeText = $(if ($stopRow[1]) { '커스텀' } else { '비커스텀' })
  if ($stopRow[0] -eq 'transition') {
    Check-Equal ('§4 transition({0}) → 돌아옴 (종료 · 로그 · 진단 0)' -f $stopModeText) ('{0}/{1}/{2}' -f $stopError, $script:logs.Count, $script:diagCalls.Count) '/0/0'
  } else {
    Check-Equal ('§4 {0}({1}) → [완료] 1줄(꼬리 = 다음 시작 · 놓아줌 표지는 reward-before-click 만) + 진단 캡처 1 + 코드 4' -f $stopRow[0], $stopModeText) `
      ('{0} | {1} | 진단 {2} | 줄 {3}' -f $stopError, $lastLog, $script:diagCalls.Count, $script:logs.Count) ('__EXIT__4 | {0} | 진단 1 | 줄 1' -f $stopRow[2])
  }
}
$script:customMode = $false

# ── §5 Complete-AbyssPromptTimeoutHandoff ──
Invoke-Expression (Get-WorkerFunctionText 'Complete-AbyssPromptTimeoutHandoff')
function Set-AbyssJournalReenteredBy { param([string]$Nonce, [string]$Value) $script:markCalls.Add(('{0}={1}' -f $Nonce, $Value)); return $script:markTag }
function Complete-AbyssInsideHandoff { param([string]$Nonce) $script:handoffCalls.Add($Nonce); throw '__HANDOFF__' }
foreach ($handoffRow in @(
    @('changed', '__HANDOFF__', '[어비스] 재입장 대기 끝에 새 판의 클리어 화면(화면을 터치)이 이어 보입니다 - '),
    @('locked', '', '[경고] 클리어 화면 추론 표지를 저장하지 못했습니다 (파일 사용 중) - 넘기지 않고 입장 대기 시간 초과로 정지합니다'),
    @('corrupt', '', '[경고] 클리어 화면 추론 표지를 저장하지 못했습니다 (파일 손상) - '),
    @('expect-failed', '', '[경고] 클리어 화면 추론 표지를 저장하지 못했습니다 (기록 실패) - '))) {
  $script:markTag = $handoffRow[0]
  $script:markCalls = New-Object System.Collections.Generic.List[string]
  $script:handoffCalls = New-Object System.Collections.Generic.List[string]
  $script:logs = New-Object System.Collections.Generic.List[string]
  $script:diagCalls = New-Object System.Collections.Generic.List[string]
  $handoffError = ''
  try { Complete-AbyssPromptTimeoutHandoff -Game $null -Nonce 'n-1' } catch { $handoffError = [string]$_.Exception.Message }
  $lastLog = $(if ($script:logs.Count -gt 0) { $script:logs[$script:logs.Count - 1] } else { '' })
  if ($handoffRow[0] -eq 'changed') {
    Check-True '§5 표지 저장 성공 → 진단 캡처 1 · 안내 줄 · 재입장 완료 끝(같은 nonce)' (($handoffError -ceq '__HANDOFF__') -and ($script:diagCalls.Count -eq 1) -and $lastLog.StartsWith($handoffRow[2]) -and (($script:handoffCalls -join ',') -ceq 'n-1') -and (($script:markCalls -join ',') -ceq 'n-1=prompt-timeout')) `
      ('{0} / {1} / {2} / {3}' -f $handoffError, $lastLog, ($script:handoffCalls -join ','), ($script:markCalls -join ','))
  } else {
    Check-True ('§5 표지 저장 {0} → [경고] 뒤 돌아옴 (재입장 완료 끝 0 · 진단 0)' -f $handoffRow[0]) (($handoffError -ceq '') -and $lastLog.StartsWith($handoffRow[2]) -and ($script:handoffCalls.Count -eq 0) -and ($script:diagCalls.Count -eq 0)) ('{0} / {1}' -f $handoffError, $lastLog)
  }
}

# ── §6 Set-AbyssJournalReenteredBy ──
Invoke-Expression (Get-WorkerFunctionText 'Set-AbyssJournalProperty')
Invoke-Expression (Get-WorkerFunctionText 'Set-AbyssJournalReenteredBy')
$abyssJournalPath = 'TEST'
function Update-AbyssJournal {
  # 모의 저장소 - 잠금 아래 재판독 대신 행의 기록을 그대로 쓰고, -Expect 와 -Mutator 를 원문 계약대로 돌립니다
  param([string]$Path, [scriptblock]$Mutator, [scriptblock]$Expect)
  if (-not [bool](& $Expect $script:fakeJournal)) { return @{ Tag = 'expect-failed'; Warnings = @() } }
  $change = @{ Changed = $false }
  $null = & $Mutator $script:fakeJournal $change
  return @{ Tag = $(if ($change.Changed) { 'changed' } else { 'unchanged' }); Warnings = @('[경고] 모의 복구 경고') }
}
foreach ($markRow in @(
    @('retry-clicked', 'n-1', 'changed', 'prompt-timeout'),
    @('retry-attempt', 'n-1', 'changed', 'prompt-timeout'),
    @('reentered', 'n-1', 'expect-failed', ''),
    @('retry-clicked', 'other', 'expect-failed', ''))) {
  $script:fakeJournal = ('{"version":1,"seq":1,"entries":[{"nonce":"n-1","stage":"' + $markRow[0] + '","at":{"retryClicked":null}}],"applied":[],"pending":[]}') | ConvertFrom-Json
  $script:logs = New-Object System.Collections.Generic.List[string]
  $markTagActual = Set-AbyssJournalReenteredBy -Nonce $markRow[1] -Value 'prompt-timeout'
  $markEntry = $script:fakeJournal.entries[0]
  # 저장소 경고(잠금 아래 직전본 복구 등)는 호출부가 로그로 남깁니다(저장소 계약) - 모의는 저장까지 간 행에서만 경고 1개를 돌려줍니다
  $warningLogged = (@($script:logs | Where-Object { $_ -ceq '[경고] 모의 복구 경고' }).Count -eq 1)
  Check-Equal ('§6 단계 {0} · nonce {1} → 태그 {2} · 칸 ''{3}'' · 단계 그대로 · 저장소 경고 로그' -f $markRow[0], $markRow[1], $markRow[2], $markRow[3]) `
    ('{0}/{1}/{2}/{3}' -f $markTagActual, [string]$markEntry.reenteredBy, [string]$markEntry.stage, $warningLogged) ('{0}/{1}/{2}/{3}' -f $markRow[2], $markRow[3], $markRow[0], ($markRow[2] -eq 'changed'))
}

# ── §7 Consume-Handoff 가 next 항목의 표지를 옮김 ──
Invoke-Expression (Get-WorkerFunctionText 'Consume-Handoff')
$handoffInit = $workerAst.Find({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$script:handoff') }, $true)
Check-True '§7 초기 이어받기 상태에 ReenteredBy = '''' 칸' (($null -ne $handoffInit) -and $handoffInit.Right.Extent.Text.Contains("ReenteredBy = ''")) $(if ($null -ne $handoffInit) { $handoffInit.Right.Extent.Text } else { '(대입 없음)' })
function Read-AbyssJournal { param([string]$Path) return @{ Status = 'ok'; Journal = $script:consumeJournal; Warnings = @() } }
function Test-AbyssJournalOwnerMatch { param($Entry, $Owner, $Generation, [string]$Field = 'owner') return $true }
$script:customRecoveryOnly = $false; $script:customMode = $false; $script:abyssRunId = 'run-1'
$savedNonceEnv = $env:HONEYNOGI_HANDOFF_NONCE; $savedResumeEnv = $env:HONEYNOGI_RESUME_REENTRY
try {
  $env:HONEYNOGI_HANDOFF_NONCE = 'n-1'; $env:HONEYNOGI_RESUME_REENTRY = ''
  foreach ($consumeRow in @(
      @('표지 있는 재입장 기록', ',"reenteredBy":"prompt-timeout"', 'next/prompt-timeout'),
      @('표지 없는 재입장 기록(정상 · 옛 항목)', '', 'next/'))) {
    Invoke-Expression $handoffInit.Extent.Text
    $script:consumeJournal = ('{"version":1,"seq":1,"entries":[{"nonce":"n-1","stage":"reentered","launchState":"launched","afterEntry":{"index":0,"total":null,"keys":null},"at":{}' + $consumeRow[1] + '}],"applied":["n-1"],"pending":[]}') | ConvertFrom-Json
    $script:logs = New-Object System.Collections.Generic.List[string]
    $consumeTag = Consume-Handoff
    Check-Equal ('§7 {0} → Role next · ReenteredBy' -f $consumeRow[0]) ('{0}|{1}/{2}' -f $consumeTag, [string]$script:handoff.Role, [string]$script:handoff.ReenteredBy) ('ok|' + $consumeRow[2])
  }
} finally {
  $env:HONEYNOGI_HANDOFF_NONCE = $savedNonceEnv; $env:HONEYNOGI_RESUME_REENTRY = $savedResumeEnv
}

# ── §8 배선 ──
function Get-CommandCalls {
  param([string]$Name)
  return @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq $Name) }, $true))
}
function Get-OwnerName {
  param($Node)
  $cursor = $Node.Parent
  while (($null -ne $cursor) -and (-not ($cursor -is [System.Management.Automation.Language.FunctionDefinitionAst]))) { $cursor = $cursor.Parent }
  return $(if ($null -ne $cursor) { $cursor.Name } else { '(최상위)' })
}
foreach ($callRow in @(
    @('Complete-AbyssPromptTimeoutHandoff', 'Complete-AbyssRetrySelection'),
    @('Set-AbyssJournalReenteredBy', 'Complete-AbyssPromptTimeoutHandoff'),
    @('Invoke-AbyssPromptTimeoutClearTouch', 'Complete-AbyssPromptTimeoutClearTouch'),
    @('Complete-AbyssPromptTimeoutClearTouch', '(최상위)'),
    @('Format-AbyssReentryDiagSummary', 'Wait-AbyssReentry,Wait-AbyssReentry'),
    @('Format-AbyssTouchDiagSummary', 'Invoke-AbyssPromptTimeoutClearTouch'),
    @('Get-AbyssClearPromptTextLevel', 'Invoke-AbyssPromptTimeoutClearTouch,Wait-AbyssReentry'),
    @('Read-AbyssClearScoreText', 'Invoke-AbyssPromptTimeoutClearTouch,Wait-AbyssReentry'),
    @('Test-AbyssClearScoreText', 'Invoke-AbyssPromptTimeoutClearTouch,Wait-AbyssReentry'))) {
  $owners = @(Get-CommandCalls $callRow[0] | ForEach-Object { Get-OwnerName $_ } | Sort-Object -CaseSensitive)
  Check-Equal ('§8 {0} 호출 자리' -f $callRow[0]) ($owners -join ',') $callRow[1]
}
# 시간 초과 갈래 - B 조건 if 가 Stop-AbyssReentryTimeout 바로 앞
$retryCode = Get-CodeOnly (Get-WorkerFunctionText 'Complete-AbyssRetrySelection')
$timeoutBranch = "if (`$reentryResult -eq 'timeout') { if (([string]`$reentry.LastKind -eq 'prompt') -and ([int]`$reentry.PromptStreak -ge 2)) { Complete-AbyssPromptTimeoutHandoff -Game `$Game -Nonce `$Nonce } Stop-AbyssReentryTimeout -Game `$Game }"
Check-Equal '§8 시간 초과 갈래(원 워커 호출 B · 재개 워커 호출 D - 같은 함수, 역할 조건 없음 · 설계 8.9) = (끝 분류 prompt ∧ 엄격 연속 2 이상 → 추론 재입장 끝) 뒤 시간 초과 정지' ([regex]::Matches($retryCode, [regex]::Escape($timeoutBranch)).Count) 1
# 재입장 대기 - 결과 키 · 연속 끊김 자리 수
$waiterNode = $functionAsts['Wait-AbyssReentry']
$waiterReturns = @($waiterNode.FindAll({ param($node) $node -is [System.Management.Automation.Language.ReturnStatementAst] }, $true))
$waiterKeys = $(if ($waiterReturns.Count -eq 1) { (@($waiterReturns[0].Pipeline.PipelineElements[0].Expression.KeyValuePairs | ForEach-Object { [string]$_.Item1.Value } | Sort-Object -CaseSensitive)) -join ',' } else { "(return $($waiterReturns.Count)개)" })
Check-Equal '§8 재입장 대기 결과 키 = LastKind · PanelSeen · PromptStreak · Result' $waiterKeys 'LastKind,PanelSeen,PromptStreak,Result'
$waiterCode = Get-CodeOnly (Get-WorkerFunctionText 'Wait-AbyssReentry')
Check-Equal '§8 재입장 대기 연속 0 대입 = 6 (시작 1 · ② 양보 · ③ 탐침 복구 · ④ 스윕 · ⑥ 간접 양보 · ⑦ 판독 실패 - ① 동결은 ⑦·④ 로 시작해 ③ 으로 끝나 따로 없음)' ([regex]::Matches($waiterCode, [regex]::Escape('$promptStreak = 0')).Count) 6
Check-Equal '§8 재입장 대기 연속 갱신 = 엄격 표본만 +1 (1곳)' ([regex]::Matches($waiterCode, [regex]::Escape('$promptStreak = $(if ($promptStrict) { $promptStreak + 1 } else { 0 })')).Count) 1
Check-Equal '§8 재입장 대기 엄격 표본 식' ([regex]::Matches($waiterCode, [regex]::Escape("`$promptStrict = ((`$screen -eq 'prompt') -and ((`$promptLevel -eq 'strong') -or ((`$promptLevel -eq 'weak') -and `$promptScoreOk)))")).Count) 1
Check-Equal '§8 재입장 대기 중간 진단 표식은 호출 전에 (재시도 없음)' ([regex]::Matches($waiterCode, [regex]::Escape('if ((-not $diagCaptured) -and (Test-AbyssMemberClockExpired -Clock $diagClock)) { $diagCaptured = $true Write-LifeDiagnostics')).Count) 1
# 본류 S 갈래 - 표지일 때만 전용 루프, 그 밖은 기존 Invoke-ClickUntil 그대로 · 계상 기록은 그 if 뒤
# 본류는 워커 최상위 try 안이라 문서 전체에서 찾습니다 (조건 + 시작 줄 문구로 그 if 하나를 고름 - test_abyss_handoff_start 의 promptBranchIfs 와 같은 앵커)
$promptIfs = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq '$startClearDetected') -and
      $node.Extent.Text.Contains('클리어 화면 감지 - 마무리부터 진행') }, $true))
Check-Equal '§8 본류 S 갈래 if ($startClearDetected) = 1' $promptIfs.Count 1
if ($promptIfs.Count -eq 1) {
  $promptBody = Get-CodeOnly $promptIfs[0].Clauses[0].Item2.Extent.Text
  $touchIf = "if (([string]`$script:handoff.Role -eq 'next') -and ([string]`$script:handoff.ReenteredBy -eq 'prompt-timeout')) { Complete-AbyssPromptTimeoutClearTouch -Game `$game } else { Invoke-ClickUntil -Game `$game -Point `$ptClearCenter -Description '클리어 화면 터치(나가기 버튼 표시)' `` -TimeoutSeconds (`$timeoutExit + 15) -ReclickEverySeconds 3 -Condition { Test-ExitButton -Game `$game } `` -SourceCondition { Test-DungeonClearPrompt -Game `$game } }"
  $touchAt = $promptBody.IndexOf($touchIf, [StringComparison]::Ordinal)
  $clearedAt = $promptBody.IndexOf('[void](Add-AbyssJournalClearedEntry)', [StringComparison]::Ordinal)
  Check-True '§8 본류 S 갈래 = 표지 if(전용 루프) / else(기존 Invoke-ClickUntil 그대로) · 계상 기록은 그 뒤' (($touchAt -ge 0) -and ($clearedAt -gt $touchAt)) ('터치 if 자리 {0} · 계상 자리 {1}' -f $touchAt, $clearedAt)
}
# Consume-Handoff - next 갈래가 표지를 옮김 (return 'ok' 앞)
$consumeCode = Get-CodeOnly (Get-WorkerFunctionText 'Consume-Handoff')
Check-Equal '§8 Consume-Handoff next 갈래의 표지 옮김 1곳 (AfterEntry 다음 · return 앞)' ([regex]::Matches($consumeCode, [regex]::Escape("`$script:handoff.AfterEntry = `$entryAfterEntry `$script:handoff.ReenteredBy = [string]`$handoffEntry.reenteredBy return 'ok'")).Count) 1
# 전용 루프 - exit 0 · 서두 메타 비움 · 클릭은 결론·마감 뒤
$touchNode = $functionAsts['Invoke-AbyssPromptTimeoutClearTouch']
Check-Equal '§8 전용 루프 안 exit 0 (끝 함수가 정지)' @($touchNode.FindAll({ param($node) $node -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count 0
$touchCode = Get-CodeOnly $touchNode.Extent.Text
$transitionAt = $touchCode.IndexOf("if (`$exitNow -and (`$panelKind -eq 'none')) { `$touchResult = `$(if (`$clickSent) { 'transition' } else { 'reward-before-click' }) break }", [StringComparison]::Ordinal)
$deadlineAt = $touchCode.IndexOf("if (Test-AbyssMemberClockExpired -Clock `$touchClock) { `$touchResult = 'timeout' break }", [StringComparison]::Ordinal)
$clickAt = $touchCode.IndexOf('Click-GamePoint -Game $Game -ReferenceX $ptClearCenter[0] -ReferenceY $ptClearCenter[1]', [StringComparison]::Ordinal)
Check-True '§8 전용 루프 순서 = ⑨ 결론(전송 뒤만 transition) → ⑩ 마감 → ⑪ 클릭' (($transitionAt -ge 0) -and ($deadlineAt -gt $transitionAt) -and ($clickAt -gt $deadlineAt)) ('결론 {0} · 마감 {1} · 클릭 {2}' -f $transitionAt, $deadlineAt, $clickAt)
Check-Equal "§8 전용 루프 `$script:lastClickSkipReason = '' = 2 (회전 서두 · 클릭 직전 - 규칙 4)" ([regex]::Matches($touchCode, [regex]::Escape("`$script:lastClickSkipReason = ''")).Count) 2
# 결론은 결과 변수 + break 로 루프 밖 한 곳에서 돌려주고(return 1개), 비전이 끝의 진단 줄은 그 앞 한 곳(설계 8.7 - 결론 자리마다 진단을 빠뜨리지 않게)
$touchReturns = @($touchNode.FindAll({ param($node) $node -is [System.Management.Automation.Language.ReturnStatementAst] }, $true))
Check-Equal '§8 전용 루프 return = 1개(return $touchResult)' (@($touchReturns | ForEach-Object { Get-CodeOnly $_.Extent.Text }) -join ' / ') 'return $touchResult'
$touchDiagAt = $touchCode.IndexOf("if (`$touchResult -ne 'transition') { Write-RunLog (Format-AbyssTouchDiagSummary", [StringComparison]::Ordinal)
$touchReturnAt = $touchCode.LastIndexOf('return $touchResult', [StringComparison]::Ordinal)
$touchDiagCalls = @($touchNode.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Format-AbyssTouchDiagSummary') }, $true))
$touchDiagInLoop = @($touchDiagCalls | Where-Object {
    $ancestor = $_.Parent
    $insideLoop = $false
    while (($null -ne $ancestor) -and (-not ($ancestor -is [System.Management.Automation.Language.FunctionDefinitionAst]))) {
      if ($ancestor -is [System.Management.Automation.Language.LoopStatementAst]) { $insideLoop = $true }
      $ancestor = $ancestor.Parent
    }
    $insideLoop
  })
Check-True '§8 전용 루프 진단 줄 = 루프 밖(while 부모 없음) · return 앞 1곳(transition 이 아닐 때만)' (($touchDiagCalls.Count -eq 1) -and ($touchDiagInLoop.Count -eq 0) -and ($touchDiagAt -ge 0) -and ($touchReturnAt -gt $touchDiagAt)) `
  ('호출 {0} · 루프 안 {1} · 진단 {2} · return {3}' -f $touchDiagCalls.Count, $touchDiagInLoop.Count, $touchDiagAt, $touchReturnAt)
# 본류 이벤트 정리 건너뜀 (설계 8.6) - 조건 = Role next ∧ 표지 'prompt-timeout' ∧ 선분기 결론 'prompt' 정확히 그 셋, 이벤트 정리 if 바로 앞 · 대입 1곳
#   (행동은 test_abyss_handoff_start V18-T - 표지 next × S 정리 0 / 표지 없는 next × S · 표지 next × 던전 안 정리 1)
$workerCodeOnly = Get-CodeOnly ([IO.File]::ReadAllText($workerPath))
$skipAssign = "`$skipEventOverlay = (([string]`$script:handoff.Role -eq 'next') -and ([string]`$script:handoff.ReenteredBy -eq 'prompt-timeout') -and ([string]`$script:handoff.StartScreen -eq 'prompt'))"
$skipIf = 'if ((-not $skipEventOverlay) -and (Clear-EventOverlay -Game $game)) {'
$skipAssignAt = $workerCodeOnly.IndexOf($skipAssign, [StringComparison]::Ordinal)
$skipIfAt = $workerCodeOnly.IndexOf($skipIf, [StringComparison]::Ordinal)
Check-True '§8 본류 이벤트 정리 건너뜀 - 조건 대입 1곳(셋 그대로) · 바로 뒤 이벤트 정리 if 1곳' (([regex]::Matches($workerCodeOnly, [regex]::Escape($skipAssign)).Count -eq 1) -and
  ([regex]::Matches($workerCodeOnly, [regex]::Escape($skipIf)).Count -eq 1) -and ($skipAssignAt -ge 0) -and ($skipIfAt -eq ($skipAssignAt + $skipAssign.Length + 1))) ('대입 {0} · if {1}' -f $skipAssignAt, $skipIfAt)

exit $fails
