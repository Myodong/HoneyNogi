# ============================================================
#  꿀비노기 (마비노기 모바일 자동화) - 컨트롤 패널 (GUI)
#  mabinogi_UI실행기.cmd 로 실행하세요.
# ============================================================
$ErrorActionPreference = 'Stop'

# ----- 관리자 권한 확인 (게임 입력에 필요) -----
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $PSCommandPath + '"'))
  exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ----- 작업표시줄 아이콘/그룹 분리 -----
# 이 창은 powershell.exe 안에서 뜨기 때문에 기본으로는 작업표시줄에서 PowerShell 아이콘으로
# 묶입니다. 창을 만들기 전에 전용 AppUserModelID 를 부여하면 작업표시줄이 이 창을 독립 앱으로
# 취급해 창 아이콘(꿀단지, $form.Icon)을 그대로 보여줍니다.
try {
  Add-Type -Namespace Win32 -Name TaskbarAppId -MemberDefinition @'
[DllImport("shell32.dll", SetLastError = true)]
public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);
'@
  [Win32.TaskbarAppId]::SetCurrentProcessExplicitAppUserModelID('HoneyNogi.ControlPanel') | Out-Null
} catch { }

# ----- 임베디드 호스트 모드 감지 (v2.1.4 작업 관리자 브랜딩) -----
# HoneyNogi.exe --embedded-host 로 실행되면 이 스크립트는 powershell.exe 가 아니라 exe 안의
# PowerShell 호스트(HoneyNogiHost)에서 돕니다. 이때 워커/리사이즈 헬퍼도 같은 exe 의
# --run 으로 띄워야 작업 관리자 전체가 '꿀비노기'(꿀단지 아이콘)로 표시됩니다.
# 판별은 호스트 이름($Host.Name) + exe 가 주입한 경로 환경변수의 **이중 확인**입니다
# (프로세스 이름 비교는 이름 바꾼 exe/저장소 직접 실행에서 어긋나므로 금지 - 설계 합의).
# 환경변수만으로 판별하지 않는 이유: 임베디드 GUI 가 띄운 자식에게 변수가 상속되므로,
# powershell 로 뜬 프로세스가 변수만 보고 임베디드로 오판할 수 있습니다.
$script:hostedExePath = ''
if ($Host.Name -eq 'HoneyNogiHost' -and -not [string]::IsNullOrWhiteSpace($env:HONEYNOGI_HOST_EXE) -and
    (Test-Path -LiteralPath $env:HONEYNOGI_HOST_EXE)) {
  $script:hostedExePath = [string]$env:HONEYNOGI_HOST_EXE
}

# ----- 중복 실행 방지 뮤텍스는 '구버전 정리' 다음으로 이동 (2026-07-27) -----
# 구버전 GUI가 뮤텍스를 쥔 채 실행 중이면 새 버전이 '이미 실행 중'으로 종료되므로,
# 신규 버전 최초 실행 1회의 구버전 정리(구버전 프로세스 종료 포함)를 뮤텍스 검사보다
# 먼저 수행해야 합니다. 실제 뮤텍스 획득은 아래 '구버전 정리 실행 + 중복 실행 방지'
# 섹션에 있습니다 (이 지점과 그 사이에는 함수 정의뿐이라 부작용 없음).

# 화면 꺼짐 방지용 API (자동화 실행 중에만 화면 유지 신호를 켭니다)
Add-Type -Namespace Win32 -Name PowerState -MemberDefinition @'
[DllImport("kernel32.dll")]
public static extern uint SetThreadExecutionState(uint esFlags);
'@
# 입력 상태 정리용 API: 워커를 즉시 종료(Kill)하는 순간이 워커의 키/마우스 '누름'과 '뗌'
# 사이일 수 있습니다(ALT 약 160ms, 좌클릭 약 100ms 간격). 주입된 눌림 상태는 프로세스가
# 죽어도 풀리지 않아 이후 수동 조작이 ALT+클릭처럼 동작하므로, Kill 후 강제로 떼 줍니다.
Add-Type -Namespace Win32 -Name InputRelease -MemberDefinition @'
[DllImport("user32.dll")]
public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
[DllImport("user32.dll")]
public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
'@
# 전역 단축키 감지용 API: 게임 창에 포커스가 있어도 F9/F10을 인식하기 위해
# 키보드 상태를 직접 읽습니다 (레거시 컨트롤러의 F12와 같은 방식).
Add-Type -Namespace Win32 -Name HotkeyPoll -MemberDefinition @'
[DllImport("user32.dll")]
public static extern short GetAsyncKeyState(int vKey);
'@
# 게임 창 물리 크기 추정용 API (권장 창 모드 메뉴의 현재 크기 체크 표시 - 2026-08-13):
# 비 DPI 인식 GUI 의 GetWindowRect 는 가상(축소) 좌표를 주므로, 물리 데스크톱 해상도
# (GetDeviceCaps DESKTOPHORZRES=118/VERTRES=117)와 가상 화면 크기의 비율로 환산합니다.
Add-Type -Namespace Win32 -Name WindowProbe -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
[DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
[DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
'@

function Get-RecommendedSizeMatch {
  # 물리 창 크기가 권장 두 크기 중 어느 쪽인지 (순수 - 진리표 대상). 권장 창 모드 메뉴의
  # 현재 크기 체크 표시용. 허용 오차 ±6px - 정상 상태는 정확히 일치(MoveWindow/워커
  # nearest 정규화가 정확값을 씀)하고, 1280x720 같은 이웃 크기(폭 차 8px)를 권장 크기로
  # 오표시하지 않는 경계입니다. 반환: '1272' | '1908' | ''(불일치/판독 실패).
  param([int]$PhysicalWidth, [int]$PhysicalHeight)
  if (([Math]::Abs($PhysicalWidth - 1272) -le 6) -and ([Math]::Abs($PhysicalHeight - 717) -le 6)) { return '1272' }
  if (([Math]::Abs($PhysicalWidth - 1908) -le 6) -and ([Math]::Abs($PhysicalHeight - 1076) -le 6)) { return '1908' }
  return ''
}

function Get-GameWindowPhysicalSize {
  # 게임 창의 '물리 픽셀' 크기 추정 (메뉴 체크 표시용 - 실패하면 $null = 체크 없음, 무해).
  # 다중 모니터에서 배율이 서로 다르면 주 모니터 비율 기준이라 부정확할 수 있는데, 그때도
  # 체크가 안 보일 뿐 크기 적용 동작(헬퍼가 DPI 인식으로 별도 계산)에는 영향이 없습니다.
  try {
    $game = Get-Process -Name 'MabinogiMobile' -ErrorAction SilentlyContinue |
      Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $game) { return $null }
    $rect = New-Object Win32.WindowProbe+RECT
    if (-not [Win32.WindowProbe]::GetWindowRect($game.MainWindowHandle, [ref]$rect)) { return $null }
    $desktopDc = [Win32.WindowProbe]::GetDC([IntPtr]::Zero)
    try {
      $physicalScreenW = [Win32.WindowProbe]::GetDeviceCaps($desktopDc, 118)
    } finally { [void][Win32.WindowProbe]::ReleaseDC([IntPtr]::Zero, $desktopDc) }
    $virtualScreenW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    if ($virtualScreenW -le 0 -or $physicalScreenW -le 0) { return $null }
    $dpiScale = $physicalScreenW / [double]$virtualScreenW
    return @{
      Width  = [int][Math]::Round(($rect.Right - $rect.Left) * $dpiScale)
      Height = [int][Math]::Round(($rect.Bottom - $rect.Top) * $dpiScale)
    }
  } catch { return $null }
}

function Apply-RecommendedWindowSize {
  # 게임 창을 권장 크기로 즉시 변경합니다. Width/Height 지정 시 그 크기(메뉴에서 사용자
  # 선택 - 2026-08-13 시안 확정), 미지정 시 기존 자동 결정(화면에 들어가면 1908, 아니면 1272).
  # GUI 프로세스는 DPI 가상 좌표를 쓰고 워커는 실제 픽셀을 쓰므로, 좌표 불일치를 피하기 위해
  # DPI 인식 헬퍼 스크립트를 별도 프로세스로 실행합니다 (워커의 계산과 완전히 동일).
  # 선택 크기가 모니터 작업 영역보다 크면(FHD에서 1908 등) 적용하지 않습니다 - 창이 잘리면
  # 하단 버튼 인식이 깨져 무인 운용이 죽음(fail-closed, 사용자 확정). 헬퍼는 별도 프로세스라
  # GUI 로그를 직접 못 쓰므로 결과 파일을 남기고 아래 결과 타이머가 읽어 안내합니다.
  param([int]$Width = 0, [int]$Height = 0)
  $helper = Join-Path $scriptRoot 'resize_to_recommended.ps1'
  # 요청별 새 결과 파일 (교차 리뷰: 고정 경로면 연속 클릭·GUI 재시작 시 이전 헬퍼의 늦은
  # 결과를 새 타이머가 소비할 수 있음 - GUID 로 요청과 결과를 1:1 묶고, 타이머는 현재
  # 경로만 읽으므로 낡은 결과는 자연히 무시됩니다. 임시 폴더의 고아 파일은 무해)
  $script:resizeResultPath = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_resize_' + [guid]::NewGuid().ToString('N') + '.txt')
  # 헬퍼 스크립트의 작은따옴표 문자열에 박히므로 경로의 ' 는 '' 로 이스케이프 (교차 리뷰 -
  # 사용자 프로필 경로에 ' 가 있으면 헬퍼가 구문 오류로 통째로 죽음)
  $resultPath = ([string]$script:resizeResultPath).Replace("'", "''")
  Remove-Item -LiteralPath $script:resizeResultPath -ErrorAction SilentlyContinue
  $sizeLine = if ($Width -gt 0 -and $Height -gt 0) {
    "`$tw = $Width; `$th = $Height"
  } else {
    "if (`$ww -ge 2100 -and `$wh -ge 1150) { `$tw = 1908; `$th = 1076 } else { `$tw = 1272; `$th = 717 }"
  }
  $lines = @(
    "`$ErrorActionPreference = 'SilentlyContinue'",
    "`$md = '[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }' +",
    " '[DllImport(`"user32.dll`")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);' +",
    " '[DllImport(`"user32.dll`")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool bRepaint);' +",
    " '[DllImport(`"user32.dll`")] public static extern int GetSystemMetrics(int nIndex);' +",
    " '[DllImport(`"user32.dll`")] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref RECT pvParam, uint fWinIni);' +",
    " '[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }' +",
    " '[DllImport(`"user32.dll`")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);' +",
    " '[DllImport(`"user32.dll`")] public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);' +",
    " '[DllImport(`"user32.dll`")] public static extern bool SetProcessDPIAware();'",
    "Add-Type -Namespace RW -Name Win -MemberDefinition `$md",
    "[RW.Win]::SetProcessDPIAware() | Out-Null",
    "`$p = Get-Process -Name 'MabinogiMobile' -ErrorAction SilentlyContinue | Where-Object { `$_.MainWindowHandle -ne 0 } | Select-Object -First 1",
    "if (-not `$p) { Set-Content -LiteralPath '$resultPath' -Value 'no-game' -Encoding UTF8; exit }",
    "# 작업 영역(작업표시줄 제외) - **게임 창이 있는 모니터** 기준 (교차 리뷰: 주 모니터",
    "# 기준이면 보조 모니터의 1908 을 잘못 거부하거나 창을 주 모니터 쪽으로 끌어올 수 있음)",
    "`$haveWork = `$false",
    "`$mon = [RW.Win]::MonitorFromWindow(`$p.MainWindowHandle, 2)",
    "`$mi = New-Object RW.Win+MONITORINFO",
    "`$mi.cbSize = [Runtime.InteropServices.Marshal]::SizeOf(`$mi)",
    "if (`$mon -ne [IntPtr]::Zero -and [RW.Win]::GetMonitorInfo(`$mon, [ref]`$mi)) { `$wx=`$mi.rcWork.Left; `$wy=`$mi.rcWork.Top; `$ww=`$mi.rcWork.Right-`$mi.rcWork.Left; `$wh=`$mi.rcWork.Bottom-`$mi.rcWork.Top; `$haveWork=`$true }",
    "if (-not `$haveWork) {",
    "  `$wa = New-Object RW.Win+RECT",
    "  if ([RW.Win]::SystemParametersInfo(0x0030, 0, [ref]`$wa, 0)) { `$wx=`$wa.Left; `$wy=`$wa.Top; `$ww=`$wa.Right-`$wa.Left; `$wh=`$wa.Bottom-`$wa.Top }",
    "  else { `$wx=0; `$wy=0; `$ww=[RW.Win]::GetSystemMetrics(0); `$wh=[RW.Win]::GetSystemMetrics(1) }",
    "}",
    $sizeLine,
    "if (`$tw -gt `$ww -or `$th -gt `$wh) { Set-Content -LiteralPath '$resultPath' -Value ('too-big ' + `$tw + ' x ' + `$th) -Encoding UTF8; exit }",
    "`$r = New-Object RW.Win+RECT",
    "[RW.Win]::GetWindowRect(`$p.MainWindowHandle, [ref]`$r) | Out-Null",
    "`$tx = [Math]::Min([Math]::Max(`$r.Left, `$wx), [Math]::Max(`$wx + `$ww - `$tw, `$wx))",
    "`$ty = [Math]::Min([Math]::Max(`$r.Top, `$wy), [Math]::Max(`$wy + `$wh - `$th, `$wy))",
    "# 적용 결과를 실측으로 검증 - MoveWindow 성공 반환만으로는 게임이 크기를 거부한 경우를",
    "# 못 잡음 (교차 리뷰: 무조건 ok 는 거짓 성공 로그가 됨)",
    "[void][RW.Win]::MoveWindow(`$p.MainWindowHandle, `$tx, `$ty, `$tw, `$th, `$true)",
    "Start-Sleep -Milliseconds 250",
    "`$r2 = New-Object RW.Win+RECT",
    "[RW.Win]::GetWindowRect(`$p.MainWindowHandle, [ref]`$r2) | Out-Null",
    "`$aw = `$r2.Right - `$r2.Left",
    "`$ah = `$r2.Bottom - `$r2.Top",
    "if (`$aw -eq `$tw -and `$ah -eq `$th) { Set-Content -LiteralPath '$resultPath' -Value ('ok ' + `$tw + ' x ' + `$th) -Encoding UTF8 }",
    "else { Set-Content -LiteralPath '$resultPath' -Value ('failed ' + `$aw + ' x ' + `$ah) -Encoding UTF8 }"
  )
  try {
    Set-Content -LiteralPath $helper -Value ($lines -join "`r`n") -Encoding UTF8
    if ($script:hostedExePath) {
      # 임베디드 호스트: 헬퍼도 같은 exe(--run)로 (작업 관리자 브랜딩 - 워커 스폰과 같은 분기)
      Start-Process -FilePath $script:hostedExePath -ArgumentList @('--run', ('"' + $helper + '"'))
    } else {
      Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $helper + '"'))
    }
    if ($Width -gt 0) { Add-GuiLog "[안내] 게임 창을 $Width x $Height(으)로 변경합니다" }
    else { Add-GuiLog '[안내] 게임 창을 권장 크기로 변경합니다 (OCR 인식 최적 - 1908x1076 또는 1272x717)' }
    # 결과 타이머 시작 (헬퍼가 남긴 결과 파일을 읽어 성공/거부/게임 없음을 로그로 안내).
    # pending 플래그는 시작 버튼·추가 리사이즈를 잠깐 막고, 타이머가 어느 경로로든 해제
    $script:resizePending = $true
    $script:resizeResultTicks = 0
    if ($script:timerResizeResult) { $script:timerResizeResult.Stop(); $script:timerResizeResult.Start() }
  } catch {
    Add-GuiLog "[경고] 권장 창 크기 적용 실패: $($_.Exception.Message)"
  }
}

function Release-StuckInput {
  # 워커 강제 종료 직후 호출: 워커가 누를 수 있는 키들과 마우스 왼쪽 버튼을 '뗌' 상태로 되돌립니다.
  # (Kill 시점이 키 '누름-뗌' 사이면 그 키가 눌린 채 남기 때문. 키업만 보내므로
  #  이미 떼어져 있는 키에는 아무 효과가 없는 안전한 호출입니다.)
  try {
    # 기본 해제 목록: ALT(Focus-Game), Space(자동출발/부활 재개), B(음식), R(부활),
    # ESC(메뉴/뒤로), C(내 정보 - 생활), H(어시스트 토글).
    # ★ 뒤 세 개가 빠져 있었습니다 (2026-08-10 10차 점검). 워커를 강제 종료한 순간이
    #   그 키의 '누름-뗌' 사이였다면 게임에 눌린 채로 남아, 다음 회차의 입력이 엉킵니다.
    #   키업만 보내므로 이미 떼어져 있으면 아무 효과가 없는 안전한 추가입니다.
    $releaseKeys = @(0x12, 32, 66, 82, 27, 67, 72)
    # config에 사용자 지정 키(afterEntry.keys / revive)가 있으면 그 키들도 포함합니다
    try {
      $cfgNow = Read-Config
      if ($cfgNow) {
        if ($cfgNow.PSObject.Properties['afterEntry'] -and $cfgNow.afterEntry.PSObject.Properties['keys']) {
          foreach ($entry in @($cfgNow.afterEntry.keys)) {
            if ($entry.PSObject.Properties['key']) { $releaseKeys += [int]$entry.key }
          }
        }
        if ($cfgNow.PSObject.Properties['revive']) {
          if ($cfgNow.revive.PSObject.Properties['key']) { $releaseKeys += [int]$cfgNow.revive.key }
          if ($cfgNow.revive.PSObject.Properties['resumeKey']) { $releaseKeys += [int]$cfgNow.revive.resumeKey }
        }
      }
    } catch { }
    foreach ($vk in ($releaseKeys | Sort-Object -Unique)) {
      if ($vk -gt 0 -and $vk -le 255) {
        [Win32.InputRelease]::keybd_event([byte]$vk, 0, 2, [UIntPtr]::Zero)   # KEYEVENTF_KEYUP
      }
    }
    [Win32.InputRelease]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)       # 좌클릭 up (MOUSEEVENTF_LEFTUP)
  } catch { }
}
# ES_CONTINUOUS(0x80000000) | ES_SYSTEM_REQUIRED(0x1) | ES_DISPLAY_REQUIRED(0x2)
$script:esKeepAwake = [uint32]2147483651   # 0x80000003
$script:esRelease   = [uint32]2147483648   # 0x80000000 (ES_CONTINUOUS only)

# 앱 버전 (단일 관리 지점): 여기만 올리면 GUI 제목·로그·exe 파일 속성(빌드 시 자동 추출)에
# 모두 반영됩니다. 파일명은 HoneyNogi.exe 로 고정 - 업데이트는 늘 '덮어쓰기 한 번'.
# ※ 좌표 버전(coordsVersion)과는 별개입니다 (그쪽은 화면 좌표 변경 시에만 올림)
$appVersion = '2.1.5'

$scriptRoot = $PSScriptRoot
$configPath = Join-Path $scriptRoot 'config.json'
$workerScript = Join-Path $scriptRoot 'mabinogi_run_once.ps1'
# 로그/신호/마커 폴더는 실행 위치와 무관하게 %LOCALAPPDATA%\HoneyNogi\Log 로 통일합니다
# (2026-08-05 사용자 결정 - 워커와 같은 규칙이어야 안전 중지 신호/마커/로그 폴링이 만납니다).
# exe 는 스크립트가 그 폴더에 풀려 실행되므로 경로가 그대로 = 기존 사용자 영향 없음.
# LOCALAPPDATA 를 못 얻는 비정상 환경만 기존처럼 스크립트 옆 Log 폴백 (런처와 같은 가드).
$honeyLogBase = [string][Environment]::GetFolderPath('LocalApplicationData')
$honeyLogDir = $(if ([string]::IsNullOrWhiteSpace($honeyLogBase)) { Join-Path $scriptRoot 'Log' }
  else { Join-Path $honeyLogBase 'HoneyNogi\Log' })
if (-not (Test-Path -LiteralPath $honeyLogDir)) {
  New-Item -ItemType Directory -Path $honeyLogDir -Force | Out-Null
}
$workerLog = Join-Path $honeyLogDir 'mabinogi_run_once.log'
$workerRecoveryLog = Join-Path $honeyLogDir 'mabinogi_run_once.recovery.log'
# 안전 중지 신호 파일: GUI가 만들면 워커가 '던전 밖(HUD) 확인' 시점에서 회차를 조기 종료합니다.
$safeStopFlag = Join-Path $honeyLogDir 'safe_stop.flag'
# 커스텀 반복 완료 마커: 던전/어비스를 별도 파일로 두어 한쪽 모드로 먼저 시작해도 다른 쪽의
# 미완료 복구 근거가 지워지지 않게 합니다. 워커가 클리어 확정(결과 화면 도달) 시점에 현재
# 항목의 소유자 정보(리스트 지문/lap/index/항목 토큰)를 기록하고 코드 0에서 한 번만 전진합니다.
$customDungeonMarkerFile = Join-Path $honeyLogDir 'custom_done.marker' # 기존 던전 마커 경로 호환
$customAbyssMarkerFile = Join-Path $honeyLogDir 'abyss_custom_done.marker'
$customDeepMarkerFile = Join-Path $honeyLogDir 'deep_custom_done.marker'
# 생활(채집)은 마커를 만들지 않습니다 - 채집 사이클은 '퀘스트 소멸 = 완료'라 던전의 '클리어는
# 됐는데 마무리 중 종료'라는 중간 상태가 없기 때문입니다. 경로만 전용으로 두어 공용 마커
# 검사들이 다른 모드의 마커를 잘못 집어가지 않게 합니다 (파일은 생성되지 않음)
$customLifeMarkerFile = Join-Path $honeyLogDir 'life_custom_done.marker'
$customMarkerFile = $customDungeonMarkerFile
$redirectScript = Join-Path $scriptRoot 'rdp_redirect_console.ps1'

function Get-CustomMarkerFileForSection {
  # config 섹션명 → 그 섹션의 완료 마커 경로.
  # $customMarkerFile 은 '마지막으로 **시작한**' 한 섹션만 가리키는 전역이라, SectionName 을
  # 파라미터로 받는 함수(진행 초기화·랜덤 토글) 안에서 그 전역을 쓰면 컨텍스트가 갈라집니다.
  # 실제로 어비스 리스트를 초기화하면 마지막으로 시작했던 던전의 유효 마커가 지워져,
  # 클리어한 판을 한 번 더 도는 오복구가 가능했습니다 (2026-08-09 감사).
  # 값 캡처가 아니라 **함수 호출**이어야 합니다 (CLAUDE.md 함정 3 - 함수 안에서 만든
  # 클로저는 $script: 변수를 $null 로 읽음).
  param([string]$SectionName)
  switch ($SectionName) {
    'lifeCustomRepeat' { return $customLifeMarkerFile }
    'abyssCustomRepeat' { return $customAbyssMarkerFile }
    'deepCustomRepeat' { return $customDeepMarkerFile }
    default { return $customDungeonMarkerFile }   # 'customRepeat'(던전) + 빈 값 안전 기본
  }
}

function Get-CustomMarkerStaleFile {
  # '이 마커는 무효인데 지우지 못했다'는 사실을 남기는 묘비 파일 경로 (마커 옆에 나란히).
  param([string]$Path)
  return ($Path + '.stale')
}

function Clear-CustomMarkerFile {
  # 완료 마커 무효화의 **단일 계약**: 삭제 → 존재 확인 → 남아 있으면 '{}' 로 소유자 형식 무효화.
  # 삭제만 하고 SilentlyContinue 로 넘기면, 파일이 잠겼을 때 'progress 는 초기화됐는데 옛
  # 마커는 살아 있는' 상태가 조용히 만들어집니다. 옛 진행이 1바퀴 0번이었다면 초기화 후
  # 컨텍스트와 마커 소유자가 그대로 맞아 잘못된 마무리 복구가 일어납니다 (2026-08-09 리뷰).
  #
  # 둘 다 실패하면 **묘비 파일(.stale)을 디스크에 남깁니다**. 메모리 플래그는 프로그램을
  # 껐다 켜면 사라지는데, 그 사이 잠금이 풀리면 옛 마커가 유효 마커로 되살아나기 때문입니다.
  # 시작 게이트가 이 묘비를 보고 재시도하거나 그 마커를 무시합니다 (Test-CustomMarkerStale).
  # 반환: 무효화까지 확실히 끝났으면 $true (호출부가 실패를 삼키지 않도록).
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $true }
  $staleFlagPath = Get-CustomMarkerStaleFile -Path $Path
  Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if (-not (Test-Path -LiteralPath $Path)) {
    # 묘비 제거까지 **확인**해야 $true 입니다. 묘비만 남으면 이번 회차가 새로 기록할
    # 정상 마커를 나중에 시작 게이트가 '무효'로 보고 지워버립니다 (2026-08-09 리뷰)
    Remove-Item -LiteralPath $staleFlagPath -Force -ErrorAction SilentlyContinue
    return (-not (Test-Path -LiteralPath $staleFlagPath))
  }
  try {
    Set-Content -LiteralPath $Path -Value '{}' -Encoding UTF8 -ErrorAction Stop
    Remove-Item -LiteralPath $staleFlagPath -Force -ErrorAction SilentlyContinue
    return (-not (Test-Path -LiteralPath $staleFlagPath))
  } catch { }
  # 묘비 생성 자체가 실패해도 $false 를 돌려주므로 호출부의 판단(무시/차단)은 안전 쪽입니다
  try { Set-Content -LiteralPath $staleFlagPath -Value 'stale' -Encoding UTF8 -ErrorAction Stop } catch { }
  return $false
}

function Test-CustomMarkerStale {
  # 지우지 못한 무효 마커가 남아 있는가 (묘비 파일 존재 = 재시작해도 유지되는 사실)
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
  return [bool](Test-Path -LiteralPath (Get-CustomMarkerStaleFile -Path $Path))
}

# ----- 설정 읽기/쓰기 -----
function Read-Config {
  # 파싱 실패 원인을 기억해 두어, 사용자에게 '어디가 잘못됐는지'까지 안내할 수 있게 합니다.
  $script:configReadError = $null
  if (Test-Path -LiteralPath $configPath) {
    try { return (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { $script:configReadError = $_.Exception.Message; return $null }
  }
  $script:configReadError = '파일이 없습니다'
  return $null
}

function ConvertTo-StrictBoolean {
  param($Value, [bool]$Default)
  # PowerShell의 [bool]'false' 는 $true 이므로 JSON 불리언만 그대로 인정합니다.
  if ($Value -is [bool]) { return [bool]$Value }
  return $Default
}

function Get-KeyEntry {
  param($Config, [int]$KeyCode)
  if (-not $Config) { return $null }
  $afterEntry = $Config.PSObject.Properties['afterEntry']
  if (-not $afterEntry) { return $null }
  $keys = $afterEntry.Value.PSObject.Properties['keys']
  if (-not $keys) { return $null }
  foreach ($entry in @($keys.Value)) {
    if (-not $entry.PSObject.Properties['key']) { continue }
    try {
      if ([int]$entry.key -eq $KeyCode) { return $entry }
    } catch { continue }
  }
  return $null
}

function Write-Utf8FileAtomic {
  param([string]$Path, [string]$Text)

  # 완성본을 같은 폴더의 임시 파일에 먼저 닫아 쓴 뒤 File.Replace 로 교체합니다.
  # 기존 파일은 교체 성공 전까지 그대로 남으므로 쓰기 중 종료/동시 읽기에도 부분 JSON이 보이지 않습니다.
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $dir = [System.IO.Path]::GetDirectoryName($fullPath)
  if (-not [System.IO.Directory]::Exists($dir)) { [System.IO.Directory]::CreateDirectory($dir) | Out-Null }
  $tempName = '.{0}.{1}.{2}.tmp' -f [System.IO.Path]::GetFileName($fullPath), $PID, ([guid]::NewGuid().ToString('N'))
  $tempPath = [System.IO.Path]::Combine($dir, $tempName)
  $backupPath = $tempPath + '.bak'
  try {
    $utf8Bom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $true
    [System.IO.File]::WriteAllText($tempPath, $Text, $utf8Bom)
    if ([System.IO.File]::Exists($fullPath)) {
      [System.IO.File]::Replace($tempPath, $fullPath, $backupPath, $true)
    } else {
      [System.IO.File]::Move($tempPath, $fullPath)
    }
  } finally {
    # 임시/백업 파일 청소 실패는 저장 실패가 아닙니다 (2026-08-01 전수 점검: 교체(Replace)가
    # 이미 성공했는데 .bak 삭제 예외로 전체가 실패 처리되면, 호출부가 UI 를 롤백해 디스크(새
    # 값)와 화면(옛 값)이 역방향으로 어긋남 - 청소 실패는 무시하고 다음 저장 때 재시도됨)
    try { if ([System.IO.File]::Exists($tempPath)) { [System.IO.File]::Delete($tempPath) } } catch { }
    try { if ([System.IO.File]::Exists($backupPath)) { [System.IO.File]::Delete($backupPath) } } catch { }
  }
}

function Save-Config {
  param($Config)
  $json = $Config | ConvertTo-Json -Depth 10
  # PS5.1 의 ConvertTo-Json 은 한글을 \uXXXX 로 바꾸므로 사람이 읽을 수 있게 복원합니다.
  $json = [regex]::Replace($json, '\\u([0-9a-fA-F]{4})', {
      param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) })
  # 교체 전 직렬화 결과 자체도 다시 파싱해, 유효하지 않은 JSON은 기존 config 를 건드리지 않습니다.
  [void]($json | ConvertFrom-Json -ErrorAction Stop)
  Write-Utf8FileAtomic -Path $configPath -Text $json
}

function Update-ConfigToLatest {
  # exe 업데이트 자동 이전: 사용자 config 의 좌표 버전(coordsVersion) 또는 설정 구조 버전
  # (configSchemaVersion)이 내장 최신 config(config.default.json)보다 낮으면 최신 config 를 기반으로
  # '사용자가 바꾸는 설정'만 옮겨 담아 config.json 을 재생성합니다.
  # 이렇게 하면 업데이트 때 좌표/구조는 항상 최신이 되고 사용자 설정은 유지됩니다.
  # 반환: 이전을 수행했으면 $true
  $script:configMigrationError = $null
  $defaultPath = Join-Path $scriptRoot 'config.default.json'
  if (-not (Test-Path -LiteralPath $defaultPath)) { return $false }
  try {
    $def = Get-Content -LiteralPath $defaultPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $usr = Read-Config
    if (-not $usr -or -not $def) { return $false }
    $defVer = 0; if ($def.PSObject.Properties['coordsVersion']) { $defVer = [int]$def.coordsVersion }
    $usrVer = 0; if ($usr.PSObject.Properties['coordsVersion']) { $usrVer = [int]$usr.coordsVersion }
    $defSchema = 0; if ($def.PSObject.Properties['configSchemaVersion']) { $defSchema = [int]$def.configSchemaVersion }
    $usrSchema = 0; if ($usr.PSObject.Properties['configSchemaVersion']) { $usrSchema = [int]$usr.configSchemaVersion }
    if ($usrVer -ge $defVer -and $usrSchema -ge $defSchema) { return $false }

    # 1) 어비스 선택/카테고리 (프로파일 좌표는 최신 것 유지, 선택 값만 이전)
    if ($usr.PSObject.Properties['contentCategory']) { $def.contentCategory = $usr.contentCategory }
    # 대분류(전투/생활)도 최상위 키로 이전 (v2.0.0 - 구 config 에 없으면 기본값 battle 유지)
    if ($usr.PSObject.Properties['mainCategory']) { $def.mainCategory = $usr.mainCategory }
    if ($usr.PSObject.Properties['dungeons'] -and $def.PSObject.Properties['dungeons']) {
      foreach ($n in @('selected', 'mode', 'difficulty', 'matching')) {
        if ($usr.dungeons.PSObject.Properties[$n]) {
          if ($def.dungeons.PSObject.Properties[$n]) { $def.dungeons.$n = $usr.dungeons.$n }
          else { $def.dungeons | Add-Member -NotePropertyName $n -NotePropertyValue $usr.dungeons.$n }
        }
      }
    }
    # 이번 이전에서 '진행 기록을 실제로 지운' 섹션 목록. 매 호출 초기화합니다 (같은 프로세스에서
    # 두 번 호출될 수 있고, 앞선 호출의 목록이 남으면 무관한 마커를 지웁니다)
    $script:customProgressResetSections = @()
    # 2) 값 섹션들: '_' 주석 키를 제외하고, 최신 구조에 존재하는 키만 사용자 값으로 덮어씀
    #    (최신 구조에서 사라진 키는 버리고, 새로 생긴 키는 최신 기본값 유지)
    foreach ($sect in @('normalDungeon', 'deepDungeon', 'huntingGround', 'timeoutsSeconds', 'focus', 'repeat', 'diagnostics', 'window', 'rdp', 'ui', 'customRepeat', 'abyssCustomRepeat', 'deepCustomRepeat', 'lifeCustomRepeat', 'assist', 'life', 'etc')) {
      if ($usr.PSObject.Properties[$sect] -and $def.PSObject.Properties[$sect]) {
        foreach ($prop in $usr.$sect.PSObject.Properties) {
          if ($prop.Name -like '_*') { continue }
          if ($def.$sect.PSObject.Properties[$prop.Name]) { $def.$sect.($prop.Name) = $prop.Value }
        }
      }
    }
    # 2-0) '채집 대기' 특례 (schema 6): 이 설정은 **의미가 바뀌었습니다** - '사이클 총 시간'
    #      → '진행이 멈춘 시간'(2026-08-08). 옛 값은 총 시간 기준으로 정한 숫자라 새 의미에서는
    #      뜻이 달라집니다(실제로 구 기본값 120 이 그대로 남아 멀쩡한 채집을 잘랐습니다).
    #      그래서 그대로 옮기지 않고 최신 기본값으로 되돌리고, 시작 로그로 안내합니다.
    if ($usrSchema -lt 6 -and $def.PSObject.Properties['life'] -and
      $def.life.PSObject.Properties['gatherWaitSeconds']) {
      $oldGatherWait = 0
      try {
        if ($usr.PSObject.Properties['life'] -and $usr.life -and $usr.life.PSObject.Properties['gatherWaitSeconds']) {
          $oldGatherWait = [int]$usr.life.gatherWaitSeconds
        }
      } catch { }
      $def.life.gatherWaitSeconds = 600
      if ($oldGatherWait -gt 0 -and $oldGatherWait -ne 600) { $script:gatherWaitReset = $oldGatherWait }
    }
    # 2-1) 커스텀 반복 특례: 리스트/설정은 위 루프로 이전하되 '진행 기록만' 초기화합니다.
    #      업데이트로 좌표/판정이 바뀌었을 수 있어 이어가기보다 처음부터가 안전 (요청사항 확정 스펙).
    #      사용자에게는 시작 로그로 안내합니다 ($script:customProgressReset).
    if ($def.PSObject.Properties['customRepeat']) {
      $hadCustomProgress = $false
      try {
        if ($usr.PSObject.Properties['customRepeat'] -and $usr.customRepeat -and
            $usr.customRepeat.PSObject.Properties['progress'] -and $usr.customRepeat.progress) {
          $hadCustomProgress = $true
        }
      } catch { }
      if ($def.customRepeat.PSObject.Properties['progress']) { $def.customRepeat.progress = $null }
      else { $def.customRepeat | Add-Member -NotePropertyName 'progress' -NotePropertyValue $null }
      $script:customProgressReset = $hadCustomProgress
      # 어느 섹션의 진행을 실제로 지웠는지 따로 모읍니다 (저장 성공 뒤 그 섹션 마커만 삭제).
      # 집계 플래그 하나로 4종 마커를 다 지우면 진행이 없던 섹션의 정상 마커까지 파괴됩니다.
      if ($hadCustomProgress) { $script:customProgressResetSections += 'customRepeat' }
    }
    if ($def.PSObject.Properties['abyssCustomRepeat']) {
      $hadAbyssCustomProgress = $false
      try {
        if ($usr.PSObject.Properties['abyssCustomRepeat'] -and $usr.abyssCustomRepeat -and
            $usr.abyssCustomRepeat.PSObject.Properties['progress'] -and $usr.abyssCustomRepeat.progress) {
          $hadAbyssCustomProgress = $true
        }
      } catch { }
      if ($def.abyssCustomRepeat.PSObject.Properties['progress']) { $def.abyssCustomRepeat.progress = $null }
      else { $def.abyssCustomRepeat | Add-Member -NotePropertyName 'progress' -NotePropertyValue $null }
      $script:customProgressReset = ($script:customProgressReset -or $hadAbyssCustomProgress)
      if ($hadAbyssCustomProgress) { $script:customProgressResetSections += 'abyssCustomRepeat' }
    }
    if ($def.PSObject.Properties['deepCustomRepeat']) {
      $hadDeepCustomProgress = $false
      try {
        if ($usr.PSObject.Properties['deepCustomRepeat'] -and $usr.deepCustomRepeat -and
            $usr.deepCustomRepeat.PSObject.Properties['progress'] -and $usr.deepCustomRepeat.progress) {
          $hadDeepCustomProgress = $true
        }
      } catch { }
      if ($def.deepCustomRepeat.PSObject.Properties['progress']) { $def.deepCustomRepeat.progress = $null }
      else { $def.deepCustomRepeat | Add-Member -NotePropertyName 'progress' -NotePropertyValue $null }
      $script:customProgressReset = ($script:customProgressReset -or $hadDeepCustomProgress)
      if ($hadDeepCustomProgress) { $script:customProgressResetSections += 'deepCustomRepeat' }
    }
    if ($def.PSObject.Properties['lifeCustomRepeat']) {
      $hadLifeCustomProgress = $false
      try {
        if ($usr.PSObject.Properties['lifeCustomRepeat'] -and $usr.lifeCustomRepeat -and
            $usr.lifeCustomRepeat.PSObject.Properties['progress'] -and $usr.lifeCustomRepeat.progress) {
          $hadLifeCustomProgress = $true
        }
      } catch { }
      if ($def.lifeCustomRepeat.PSObject.Properties['progress']) { $def.lifeCustomRepeat.progress = $null }
      else { $def.lifeCustomRepeat | Add-Member -NotePropertyName 'progress' -NotePropertyValue $null }
      $script:customProgressReset = ($script:customProgressReset -or $hadLifeCustomProgress)
      if ($hadLifeCustomProgress) { $script:customProgressResetSections += 'lifeCustomRepeat' }
    }
    # 3) 자동부활 on/off (키 코드/횟수 상한은 최신 기본값 유지)
    if ($usr.PSObject.Properties['revive'] -and $def.PSObject.Properties['revive'] -and
        $usr.revive.PSObject.Properties['enabled']) {
      $def.revive.enabled = ConvertTo-StrictBoolean $usr.revive.enabled $def.revive.enabled
    }
    # 4) 입장 후 키 입력의 켬/끔 (키 코드로 짝을 맞춰 이전)
    if ($usr.PSObject.Properties['afterEntry'] -and $def.PSObject.Properties['afterEntry']) {
      foreach ($defKey in @($def.afterEntry.keys)) {
        $matchKey = @($usr.afterEntry.keys) | Where-Object { $_.PSObject.Properties['key'] -and [int]$_.key -eq [int]$defKey.key } | Select-Object -First 1
        if ($matchKey -and $matchKey.PSObject.Properties['enabled']) {
          $defKey.enabled = ConvertTo-StrictBoolean $matchKey.enabled $defKey.enabled
        }
      }
    }
    # 5) 사용 승인 캐시/구버전 정리 마커: 최상위 키를 그대로 이전합니다.
    #    기본 config 에는 이 키들이 없어서, 여기서 놓치면 업데이트 때마다 승인 유예가
    #    초기화되고(오프라인 무인 PC 가 차단됨) 정리 안내 팝업이 다시 뜹니다 (설계 합의).
    foreach ($keepKey in @('approval', 'oldExeCleanup')) {
      if ($usr.PSObject.Properties[$keepKey]) {
        if ($def.PSObject.Properties[$keepKey]) { $def.$keepKey = $usr.$keepKey }
        else { $def | Add-Member -NotePropertyName $keepKey -NotePropertyValue $usr.$keepKey }
      }
    }

    Save-Config $def
    # 진행 기록을 지운 섹션은 그 섹션의 완료 마커도 함께 버립니다 (2026-08-09 감사).
    # 마커는 '이 항목까지 클리어했다'는 근거인데 progress 만 0으로 돌아가면 마커가 progress
    # 보다 앞서 있게 되어, 다음 시작에서 '미완료 마무리 복구'가 잘못 발동해 클리어한 판을
    # 한 번 더 돌 수 있습니다.
    # ★ 반드시 **저장 성공 뒤**에 지웁니다. 먼저 지우면 저장이 실패했을 때 GUI 는 '기존
    #   설정으로 계속'하는데 마커만 사라져, 옛 progress + 마커 없음으로 유료 판을 재입장할
    #   수 있습니다 (비트랜잭션 - 리뷰 적발).
    # ★ 집계 플래그 하나로 4종을 다 지우지 않습니다. 던전 progress 때문에 이전하면서
    #   progress 가 null 인 어비스의 **정상적인** 미완료 마무리 마커까지 파괴하면
    #   섹션 분리(Get-CustomMarkerFileForSection)의 취지와 정면으로 어긋납니다 (리뷰 적발).
    # ★ 무효화 실패를 조용히 성공으로 처리하지 않습니다 (리뷰 적발). 실패하면 시작 안내에
    #   남겨 사용자가 '진행 기록은 처음부터'와 어긋난 복구를 만나도 원인을 알 수 있게 합니다.
    $script:customMarkerClearFailed = $false
    foreach ($resetSection in @($script:customProgressResetSections)) {
      if ([string]::IsNullOrWhiteSpace($resetSection)) { continue }
      if (-not (Clear-CustomMarkerFile -Path (Get-CustomMarkerFileForSection -SectionName $resetSection))) {
        $script:customMarkerClearFailed = $true
      }
    }
    return $true
  } catch {
    $script:configMigrationError = $_.Exception.Message
    return $false
  }
}

# ----- 기존 자동화 프로세스 정리 -----
function Stop-ExistingAutomation {
  # 실제로 종료된 수와 실패한 수를 구분해 돌려줍니다. 실패를 성공처럼 보고하면
  # 새 워커가 '중복 실행'(코드 2)으로 죽는 원인을 사용자가 알 수 없게 됩니다.
  $pattern = 'mabinogi_controller\.ps1|mabinogi_run_once\.ps1'
  $killed = 0
  $failed = 0
  try {
    $existing = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
      Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -match $pattern })
    # 임베디드 호스트 워커(HoneyNogi*.exe --run …run_once.ps1)도 같은 기준으로 정리합니다
    # (v2.1.4 작업 관리자 브랜딩). powershell 열거만으로는 호스트 워커가 안 잡혀 남은 채
    # 게임을 계속 조작하고, 새 워커는 뮤텍스 코드 2 로 죽습니다. '--run' 동시 확인으로
    # 임베디드 GUI 자신(--embedded-host)은 대상에서 자연 제외됩니다.
    $existing += @(Get-CimInstance Win32_Process -Filter "Name LIKE 'HoneyNogi%.exe'" |
      Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and
        $_.CommandLine -match '--run' -and $_.CommandLine -match $pattern })
    foreach ($proc in $existing) {
      try { Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop; $killed++ } catch { $failed++ }
    }
    if ($existing.Count -gt 0) { Start-Sleep -Milliseconds 500 }
  } catch {
    # 열거 자체가 실패하면 '기존 프로세스 없음'과 구분되지 않던 문제 (2026-08-01 전수 점검):
    # 실제 탐색을 못 했음을 실패 1건으로 보고합니다 (최종 방어는 워커 뮤텍스 코드 2)
    $failed++
  }
  return @{ Killed = $killed; Failed = $failed }
}

# ----- RDP 자동 전환 예약 작업 -----
function Sync-RdpRedirectTask {
  param([bool]$Enable)
  try {
    $taskName = 'HoneyNogiRDPToConsole'
    # 옛 이름(MabinogiRDPToConsole)의 예약 작업이 남아 있으면 정리합니다 (꿀비노기 리네임 이전 버전)
    $legacyTask = Get-ScheduledTask -TaskName 'MabinogiRDPToConsole' -ErrorAction SilentlyContinue
    if ($legacyTask) {
      try { Unregister-ScheduledTask -TaskName 'MabinogiRDPToConsole' -Confirm:$false } catch { }
    }
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($Enable -and -not $existing -and (Test-Path -LiteralPath $redirectScript)) {
      $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
        '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $redirectScript + '"')
      $channel = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
      $triggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
      $trigger = New-CimInstance -CimClass $triggerClass -ClientOnly
      $trigger.Enabled = $true
      $trigger.Subscription = "<QueryList><Query Id=`"0`" Path=`"$channel`"><Select Path=`"$channel`">*[System[(EventID=24)]]</Select></Query></QueryList>"
      $principalTask = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -RunLevel Highest
      $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
      Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Principal $principalTask -Settings $settings -Force | Out-Null
      return 'installed'
    } elseif (-not $Enable -and $existing) {
      Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
      return 'removed'
    }
    return 'unchanged'
  } catch { return "error: $($_.Exception.Message)" }
}

# ----- 로그 tail (다른 프로세스가 쓰는 중에도 안전하게 읽기) -----
function Read-NewLogLines {
  param([string]$Path, [ref]$Offset)
  if (-not (Test-Path -LiteralPath $Path)) {
    $Offset.Value = [long]0
    return @()
  }
  # 마지막으로 끝까지 기록된 줄의 다음 바이트부터만 읽습니다. LF(0x0A)는 UTF-8 다중 바이트
  # 안에 나타나지 않으므로 마지막 LF까지만 디코딩하고, 쓰는 중인 마지막 줄은 다음 호출에 남깁니다.
  # 파일이 회차 시작 때 삭제/재생성되어 짧아지면 오프셋을 0으로 되돌립니다.
  $fs = $null
  try {
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    if ($fs.Length -lt [long]$Offset.Value) { $Offset.Value = [long]0 }
    $available = $fs.Length - [long]$Offset.Value
    if ($available -le 0) { return @() }
    if ($available -gt [int]::MaxValue) { throw '로그 증분 읽기 크기가 허용 범위를 넘었습니다.' }
    [void]$fs.Seek([long]$Offset.Value, [System.IO.SeekOrigin]::Begin)
    $bytes = New-Object byte[] ([int]$available)
    $read = 0
    while ($read -lt $bytes.Length) {
      $count = $fs.Read($bytes, $read, ($bytes.Length - $read))
      if ($count -le 0) { break }
      $read += $count
    }
    $lastLf = -1
    for ($i = $read - 1; $i -ge 0; $i--) {
      if ($bytes[$i] -eq 10) { $lastLf = $i; break }
    }
    if ($lastLf -lt 0) { return @() }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes, 0, ($lastLf + 1))
    $Offset.Value = [long]$Offset.Value + $lastLf + 1
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return @($text -split "`r?`n" | Where-Object { $_ })
  } catch { return $null }
  finally {
    if ($fs) { $fs.Dispose() }
  }
}

function Convert-WorkerLogLineForGui {
  param(
    [AllowEmptyString()][string]$Line,
    [bool]$CustomActive
  )

  # 진단·세부 동작은 원본 워커 로그에 그대로 보존하고, 컨트롤 패널에는 사용자가 진행 상황을
  # 판단하는 데 필요한 요약과 경고만 표시합니다.
  if ($Line -match '\[설정\]|\[준비\]\s*게임 확인:\s*PID|^\[\d{4}-\d{2}-\d{2}\]\s*자동화 로그\s*\(시작') {
    return $null
  }
  # [진단] 줄은 전부 분석용 원문 덤프(캡처 경로/OCR 원문/목록행/탐색 궤적)라 화면에는
  # 소음입니다 (2026-08-15 사용자 피드백 2회 - 소멸 판정 한정에서 전체 숨김으로 확대).
  # 원본 로그 파일에는 그대로 남아 제보 분석 가치를 보존하고, 화면에는 [오류]/[경고]/[완료]
  # 요약이 그대로 남습니다. 시각 프리픽스 뒤 태그 위치에 앵커링해 다른 메시지 안에 인용된
  # '[진단]' 문자열은 숨기지 않습니다 (Codex 합의)
  if ($Line -match '^\s*(?:\d{2}:\d{2}:\d{2}\s+)?\[진단\]') { return $null }
  # 정상 워커 로그는 항상 시각(HH:mm:ss)으로 시작합니다. 숫자 단독 줄은 화면에서만 버립니다.
  # ※ 과거 이 줄의 주석은 원인을 '파일 교체 경계'로 적어 두었지만 **오진이었습니다**.
  #   진짜 원인은 타이머의 Read-NewLogLines 반환을 @() 로 감싸지 않아 새 줄이 1줄뿐인 틱에서
  #   문자열로 풀리고, $lines[0] 이 시각의 첫 자리 숫자만 넘어온 것이었습니다(2026-08-09 감사).
  #   호출부를 고쳤으므로 이 필터는 이제 방어용으로만 남습니다 - 원본 로그는 변경하지 않습니다.
  if ($Line -match '^\s*\d+\s*$') { return $null }

  # 정상 적용 성공은 시작 요약과 최종 검증 로그로 충분합니다. 실패/경고는 이 패턴에 걸리지 않아
  # 그대로 표시됩니다.
  if ($Line -match "\[던전\]\s*'우연한 만남'\s*토글\s*(켬|켜짐 확인)" -or
      $Line -match '\[던전\].*난이도.*(재?클릭|추가 클릭 생략)' -or
      $Line -match '\[던전\]\s*(은동전\(소탕\)|더블 루팅)\s*=' -or
      $Line -match '\[던전\]\s*입장하기 클릭') {
    return $null
  }

  # 클리어 과정의 세부 단계는 파일에 남기고 GUI에서는 성공 요약 두 줄로 통합합니다.
  $timePrefix = ''
  if ($Line -match '^(\d{2}:\d{2}:\d{2}\s+)') { $timePrefix = $Matches[1] }
  if ($Line -match '\[던전\]\s*(던전 클리어 - 화면 터치|클리어 화면을 이미 지나친 상태)') { return "${timePrefix}[던전] 클리어 완료" }
  if ($Line -match '\[던전\]\s*결과 화면 확인') { return "${timePrefix}[던전] 결과 화면 확인" }
  if ($Line -match '\[던전\]\s*던전 클리어 화면 감지 대기 시작|\[던전\]\s*클리어 문구\(화면을 터치\) 감지|\[던전\]\s*결과 화면 감지 \(클리어 화면이 이미 지나감\)|\[던전\]\s*결과 화면 대기') {
    return $null
  }

  if ($CustomActive -and
      ($Line -match '\[커스텀\]\s*완료 마커 기록' -or
       $Line -match '\[던전\]\s*다시 하기 → 옵션 화면 복귀 - 회차 완료' -or
       $Line -match '\[커스텀\]\s*다음 층 화면 전환 확인 - 회차 완료' -or
       $Line -match '\[커스텀\].*완료 항목 마무리 복구\s*-' -or
       $Line -match '\[커스텀\]\s*마무리 목표 화면이')) {
    return $null
  }

  # 좌표·판독 근거 같은 진단 꼬리는 파일에만 남기고 화면에서는 지웁니다 (2026-08-11 사용자
  # 요청 - "(Y=575, 근거 text)"·"(링크 탐색 530,390)" 은 쓰는 사람에게 의미가 없음).
  # 진단 키워드로 시작하는 **줄 끝 괄호 덩어리만** 지우므로 오류 사유 등 사용자에게 필요한
  # 괄호 문구는 그대로 남습니다. 워커 파일 원본은 무변경 - 제보 원격 진단은 무손실.
  $Line = $Line -replace ' \((?:Y=|링크 탐색 |판독: |표본: |글자 탐색 |화면좌표 )[^\r\n]*\)\s*$', ''

  return $Line
}

# ============================================================
#  사용 승인(화이트리스트) + 구버전 정리 (2026-07-27, 설계 합의)
#  - 승인: 비공개 구글 시트 명단(Apps Script /exec)이 활성 기기 코드만 텍스트로 응답.
#    검사는 GUI 시작·새 자동화 시작 시만, 실행 중 자동화는 어떤 전이에도 중단하지 않음.
#    조회 실패(전송/형식)는 캐시 유예 7일, 유효 명단에서 명시적 부재만 즉시 차단.
#  - 정리: 신규 버전 최초 실행 1회, SHA-256이 공식 '이전 릴리스' 해시와 정확히 일치하는
#    파일만 완전 삭제. 이 승인제는 평문 스크립트 구조상 보안 경계가 아니라
#    '지인 관리용 소프트 게이트'입니다 (결심한 사용자는 우회 가능 - 이슈 문서 참고).
# ============================================================
$whitelistUrl = 'https://script.google.com/macros/s/AKfycbwHLZtR0EPApTIkU-IQUc2Jc7mMPCySPWs1caqKqLPm1tN9Q6IhC_JmAeb_OygNNZZkkQ/exec'
$approvalGraceDays = 7
$script:cleanupLogLines = @()        # 폼 생성 전 정리 결과를 모아 두었다가 시작 로그로 출력

function Get-DeviceCode {
  param([string]$MachineGuid)
  # PC 식별 코드: 앱 전용 프리픽스 + 정규화된 MachineGuid 의 SHA-256 (소문자 hex 64자).
  # 원본 MachineGuid 는 화면·로그·네트워크에 노출하지 않고, 빈 값은 해시하지 않습니다
  # (빈 문자열 해시가 '유효한 코드'가 되어 차단을 우회하는 것을 방지 - 실패 폐쇄).
  $normalized = ([string]$MachineGuid).Trim().Trim('{', '}').ToLowerInvariant()
  if ($normalized -eq '') { return '' }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes('HoneyNogi:device:v1:' + $normalized))
    return (($hashBytes | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally {
    $sha.Dispose()
  }
}

function Get-LocalDeviceCode {
  # 이 PC(윈도우 설치)의 식별 코드. 레지스트리 읽기 실패는 빈 코드 = 차단측으로 처리합니다.
  $machineGuid = ''
  try {
    $machineGuid = [string](Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name 'MachineGuid' -ErrorAction Stop).MachineGuid
  } catch { }
  return (Get-DeviceCode -MachineGuid $machineGuid)
}

function Test-WhitelistResponse {
  param([string]$Text)
  # 명단 응답 엄격 검증: 형식이 조금이라도 어긋나면 전체를 '조회 실패'로 취급합니다
  # (구글 점검/로그인 페이지가 200으로 와도 철회로 오인하지 않음 - 유예 로직과 맞물림).
  # 허용: 선두 BOM, CRLF/LF, 끝의 빈 줄. 불허: 중간 빈 줄, COUNT 불일치, 중복, 형식 오류.
  $invalid = @{ Valid = $false; Codes = @() }
  $raw = [string]$Text
  if ($raw.Length -eq 0 -or $raw.Length -gt 65536) { return $invalid }
  $raw = $raw.TrimStart([char]0xFEFF)
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($raw -split "`n")) { $lines.Add($line.TrimEnd("`r").Trim()) }
  while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
  if ($lines.Count -lt 2 -or $lines.Count -gt 1002) { return $invalid }
  if ($lines[0] -ne 'HONEYNOGI-WL-V1') { return $invalid }
  if ($lines[1] -notmatch '^COUNT=([0-9]{1,4})$') { return $invalid }   # \d 는 유니코드 숫자까지 허용해 [int] 변환 예외 가능 (리뷰 #7)
  $expectedCount = [int]$Matches[1]
  $codeLines = @($lines | Select-Object -Skip 2)
  if ($codeLines.Count -ne $expectedCount) { return $invalid }
  $seenCodes = @{}
  foreach ($code in $codeLines) {
    # -cnotmatch: PS 기본 -notmatch 는 대소문자 무시라 대문자 응답이 통과함 (진리표로 검출)
    if ($code -cnotmatch '^[0-9a-f]{64}$') { return $invalid }
    if ($seenCodes.ContainsKey($code)) { return $invalid }
    $seenCodes[$code] = $true
  }
  return @{ Valid = $true; Codes = @($codeLines) }
}

function Get-ApprovalDecision {
  param(
    [bool]$FetchOk,          # 전송 성공 + 응답 전체 검증 성공일 때만 $true
    $Codes,
    [string]$DeviceCode,
    [string]$CacheApprovedAtUtc,
    [string]$CacheDeviceCode,
    [datetime]$NowUtc,
    [int]$GraceDays = 7
  )
  # 승인 판정 (순수부 - 진리표 테스트 대상):
  #   approved-live  = 유효 명단에 내 코드 있음 (캐시 갱신 신호)
  #   denied         = 유효 명단에 내 코드 없음 = 철회/미승인 확정 (캐시 삭제 신호, 유예 없음)
  #   approved-grace = 조회 실패 + 7일 내 승인 캐시 (무인 운용 보호)
  #   no-cache       = 조회 실패 + 캐시 없음/만료/기기 불일치/미래 시각 (차단측)
  if ([string]$DeviceCode -eq '') { return 'no-cache' }   # 기기 코드 산출 불가 = 차단측
  if ($FetchOk) {
    if (@($Codes) -contains $DeviceCode) { return 'approved-live' }
    return 'denied'
  }
  if ([string]$CacheDeviceCode -ne $DeviceCode) { return 'no-cache' }
  $approvedAt = [datetime]::MinValue
  $parsedOk = [datetime]::TryParseExact([string]$CacheApprovedAtUtc, "yyyy-MM-dd'T'HH:mm:ss'Z'",
    [System.Globalization.CultureInfo]::InvariantCulture,
    ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal),
    [ref]$approvedAt)
  if (-not $parsedOk) { return 'no-cache' }
  $elapsed = $NowUtc - $approvedAt
  if ($elapsed.TotalSeconds -lt 0) { return 'no-cache' }          # 미래 시각 캐시 무효
  if ($elapsed.TotalDays -gt $GraceDays) { return 'no-cache' }    # 유예 만료
  return 'approved-grace'
}

function Get-CleanupPlan {
  param([string]$DoneVersion, [bool]$Pending, [string]$CurrentVersion)
  # 구버전 정리 단계 판정 (순수부): full = 신규 버전 최초 실행(팝업+프로세스+파일),
  # files-only = 같은 버전에서 남은 파일만 무팝업 재시도, skip = 아무것도 안 함.
  # doneVersion 이 현재보다 높으면(다운그레이드 실행) 과잉 정리를 막기 위해 skip 입니다.
  $doneVersionParsed = $null
  if (-not [System.Version]::TryParse([string]$DoneVersion, [ref]$doneVersionParsed)) { return 'full' }
  if ($doneVersionParsed -lt [System.Version]$CurrentVersion) { return 'full' }
  if ($doneVersionParsed -gt [System.Version]$CurrentVersion) { return 'skip' }   # 다운그레이드 실행 - 아무것도 안 함
  if ($Pending) { return 'files-only' }
  return 'skip'
}

function Test-OldGuiTitle {
  param([string]$Title, [string]$CurrentVersion)
  # 실행 중 구버전 GUI 판정 1축: 창 제목 엄격 일치 + 버전 파싱 성공 + 현재보다 낮음.
  # 정규식만으로는 '1..2' 같은 값이 통과할 수 있어 [System.Version] 파싱을 이중으로 요구합니다.
  if ([string]$Title -notmatch '^꿀비노기 컨트롤 패널 v(\d+(?:\.\d+){1,3})$') { return $false }
  $titleVersion = $null
  if (-not [System.Version]::TryParse($Matches[1], [ref]$titleVersion)) { return $false }
  return ($titleVersion -lt [System.Version]$CurrentVersion)
}

function Select-OldGuiProcesses {
  param($Snapshots, [string]$CurrentVersion, [string]$GuiScriptPath)
  # 종료 대상 구버전 GUI 선정 (순수부). 제목과 명령줄 이중 확인 - 명령줄은 '우리 사용자의
  # 추출 경로 전체'와 대조합니다 (다른 윈도우 사용자 세션의 HoneyNogi 는 프로필 경로가 달라
  # 제외됨 - 교차 리뷰 #1). 제목이 비어 있거나(식별 불가) 명령줄이 다르면 '보존'합니다
  # (과잉 종료 방향으로는 실패하지 않음).
  $selected = @()
  foreach ($snapshot in @($Snapshots)) {
    if (-not $snapshot) { continue }
    if ([int]$snapshot.Id -eq $PID) { continue }
    if (-not (Test-OldGuiTitle -Title ([string]$snapshot.Title) -CurrentVersion $CurrentVersion)) { continue }
    # 임베디드 호스트 GUI(HoneyNogi.exe --embedded-host)는 명령줄에 gui.ps1 경로가 없습니다
    # (v2.1.4). 식별은 엄격 제목(버전 파싱 + 현재보다 낮음) + '--embedded-host' 플래그의
    # 이중 확인 - 제목이 위조 수준으로 일치하지 않는 한 다른 앱을 잡을 수 없습니다.
    $snapshotCmd = [string]$snapshot.CommandLine
    if ($snapshotCmd.IndexOf('--embedded-host', [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
      if ([string]$GuiScriptPath -eq '') { continue }
      if ($snapshotCmd.IndexOf([string]$GuiScriptPath, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
    }
    $selected += , $snapshot
  }
  return $selected
}

function Test-ReleaseManifest {
  param($Manifest)
  # 공식 릴리스 해시 대장 사전 검증 (순수부): 항목 없음/버전 파싱 실패/해시 형식 오류/
  # 버전·해시 중복이 하나라도 있으면 전체 무효 = 그 실행에서는 한 건도 삭제하지 않습니다.
  if (-not $Manifest) { return $false }
  if (-not $Manifest.PSObject.Properties['releases']) { return $false }
  $entries = @($Manifest.releases)
  if ($entries.Count -eq 0) { return $false }
  $seenVersions = @{}
  $seenHashes = @{}
  foreach ($entry in $entries) {
    if (-not $entry) { return $false }
    $entryVersion = $null
    if (-not $entry.PSObject.Properties['version']) { return $false }
    if (-not [System.Version]::TryParse([string]$entry.version, [ref]$entryVersion)) { return $false }
    $entryHash = ''
    if ($entry.PSObject.Properties['sha256']) { $entryHash = ([string]$entry.sha256).Trim().ToLowerInvariant() }
    if ($entryHash -notmatch '^[0-9a-f]{64}$') { return $false }
    if ($seenVersions.ContainsKey($entryVersion.ToString())) { return $false }
    if ($seenHashes.ContainsKey($entryHash)) { return $false }
    $seenVersions[$entryVersion.ToString()] = $true
    $seenHashes[$entryHash] = $true
  }
  return $true
}

function Select-OldZipTargets {
  param($ZipInfos, $Manifest, [string]$CurrentVersion)
  # 구버전 zip 삭제 대상 선정 (순수부). zip 자체 해시는 압축 시점마다 달라 쓸 수 없으므로
  # '내용물'로 판정합니다: 모든 엔트리가 HoneyNogi*.exe 이름이고 그 해시가 전부 대장의
  # '이전 릴리스'와 일치할 때만 (사용자 파일이 섞인 zip, 빈 zip, 미지 해시는 보존).
  # ZipInfo = @{ Path; Entries = @(@{ Name(잎 이름); Hash }) }
  if (-not (Test-ReleaseManifest -Manifest $Manifest)) { return @() }
  $currentVersionParsed = [System.Version]$CurrentVersion
  $hashToVersion = @{}
  foreach ($entry in @($Manifest.releases)) {
    $hashToVersion[([string]$entry.sha256).Trim().ToLowerInvariant()] = [System.Version][string]$entry.version
  }
  $targets = @()
  foreach ($zipInfo in @($ZipInfos)) {
    if (-not $zipInfo) { continue }
    $zipEntries = @($zipInfo.Entries)
    if ($zipEntries.Count -eq 0) { continue }
    $allOldOfficial = $true
    foreach ($zipEntry in $zipEntries) {
      if (([string]$zipEntry.Name) -notlike 'HoneyNogi*.exe') { $allOldOfficial = $false; break }
      $entryHash = ([string]$zipEntry.Hash).Trim().ToLowerInvariant()
      if (-not $hashToVersion.ContainsKey($entryHash)) { $allOldOfficial = $false; break }
      if ($hashToVersion[$entryHash] -ge $currentVersionParsed) { $allOldOfficial = $false; break }
    }
    if ($allOldOfficial) { $targets += , $zipInfo }
  }
  return $targets
}

function Select-OldExeTargets {
  param($Candidates, $Manifest, [string]$CurrentVersion)
  # 삭제 대상 선정 (순수부): SHA-256 이 대장의 '이전 릴리스' 해시와 정확히 일치할 때만.
  # 대장에 없는 해시(자작/새 버전 사본/미보관 구버전)와 현재 이상 버전은 무조건 보존합니다.
  if (-not (Test-ReleaseManifest -Manifest $Manifest)) { return @() }
  $currentVersionParsed = [System.Version]$CurrentVersion
  $hashToVersion = @{}
  foreach ($entry in @($Manifest.releases)) {
    $hashToVersion[([string]$entry.sha256).Trim().ToLowerInvariant()] = [System.Version][string]$entry.version
  }
  $targets = @()
  foreach ($candidate in @($Candidates)) {
    if (-not $candidate) { continue }
    $candidateHash = ([string]$candidate.Hash).Trim().ToLowerInvariant()
    if (-not $hashToVersion.ContainsKey($candidateHash)) { continue }
    if ($hashToVersion[$candidateHash] -ge $currentVersionParsed) { continue }
    $targets += , $candidate
  }
  return $targets
}

# ----- 승인 상태 캐시 (config.approval) -----
function Get-ConfigApprovalCache {
  $cache = @{ At = ''; Code = '' }
  try {
    $cacheConfig = Read-Config
    if ($cacheConfig -and $cacheConfig.PSObject.Properties['approval'] -and $cacheConfig.approval) {
      if ($cacheConfig.approval.PSObject.Properties['lastApprovedAtUtc']) { $cache.At = [string]$cacheConfig.approval.lastApprovedAtUtc }
      if ($cacheConfig.approval.PSObject.Properties['deviceCode']) { $cache.Code = [string]$cacheConfig.approval.deviceCode }
    }
  } catch { }
  return $cache
}

function Set-ApprovalCache {
  # 승인 확인 성공 시각 기록 (유예 7일의 기준). fresh read 후 해당 키만 병합해 저장합니다.
  try {
    $cacheConfig = Read-Config
    if (-not $cacheConfig) { return }
    $cacheNode = [pscustomobject]@{
      lastApprovedAtUtc = [DateTime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
      deviceCode        = $script:deviceCode
    }
    if ($cacheConfig.PSObject.Properties['approval']) { $cacheConfig.approval = $cacheNode }
    else { $cacheConfig | Add-Member -NotePropertyName 'approval' -NotePropertyValue $cacheNode }
    Save-Config $cacheConfig
  } catch { }
}

function Clear-ApprovalCache {
  # 유효 명단에서 명시적 부재(철회) 확인 시 호출 - 이후 조회 실패가 유예로 살아나는 구멍을 막습니다.
  # 저장 실패는 경고로 남깁니다 (재시작+오프라인 조합에서 과거 캐시가 유예로 통과할 수 있는
  # 잔여 위험 - config 원자 저장이라 극히 드묾, 이슈 문서에 한계 명시. 리뷰 #4)
  try {
    $cacheConfig = Read-Config
    if (-not $cacheConfig -or -not $cacheConfig.PSObject.Properties['approval']) { return }
    $cacheConfig.approval = $null
    Save-Config $cacheConfig
  } catch {
    try { Add-GuiLog ('[경고] 승인 캐시 삭제 실패: {0}' -f $_.Exception.Message) } catch { }
  }
}

function Test-ApprovalAllowsStart {
  return ([string]$script:approvalState -like 'approved*')
}

# ----- 구버전 정리: 탐색/삭제 -----
function Read-ReleaseManifest {
  # 런처가 추출한 공식 릴리스 해시 대장. 없거나 손상이면 null = 파일 삭제 0건 (안전측).
  $manifestPath = Join-Path $scriptRoot 'release_hashes.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) { return $null }
  try { return (Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Get-OwnExePath {
  # 런처가 기록한 자기 exe 경로 (관리자 승격을 거쳐도 파일이라 유실되지 않음).
  try {
    $recordPath = Join-Path $scriptRoot 'exe_path.txt'
    if (Test-Path -LiteralPath $recordPath) {
      $recorded = (Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 -ErrorAction Stop).Trim()
      if ($recorded -and (Test-Path -LiteralPath $recorded)) { return $recorded }
    }
  } catch { }
  return ''
}

function Get-DownloadsFolderPath {
  # Downloads 는 환경변수 조합이 아니라 셸 등록 경로로 구합니다 (사용자 이동/리디렉션 반영).
  try {
    $shellFolders = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction Stop
    $downloadsRaw = [string]$shellFolders.'{374DE290-123F-4565-9164-39C4925E467B}'
    if ($downloadsRaw) { return [Environment]::ExpandEnvironmentVariables($downloadsRaw) }
  } catch { }
  return (Join-Path $env:USERPROFILE 'Downloads')
}

function Get-OldExeSearchRoots {
  # 탐색 범위 (사용자 확정): 자기 exe 폴더(직속만) + Downloads + 바탕화면 + 문서(하위 포함).
  # exe 폴더는 깊이 0 - 구버전은 새 exe '옆'에 놓이는 게 일반적이고, 하위까지 훑으면
  # 개발 PC 의 버전 보관 폴더(version\v1.0.7 등)처럼 '일부러 보관한' 하위 사본을 지우는
  # 사고가 남 (2026-07-27 실제 발견). 반환: @(@{ Path; MaxDepth })
  $rawRoots = New-Object System.Collections.Generic.List[object]
  $ownExe = Get-OwnExePath
  if ($ownExe) { $rawRoots.Add(@{ Path = (Split-Path -Parent $ownExe); MaxDepth = 0 }) }
  $rawRoots.Add(@{ Path = (Get-DownloadsFolderPath); MaxDepth = 5 })
  foreach ($specialFolder in @([System.Environment+SpecialFolder]::Desktop, [System.Environment+SpecialFolder]::MyDocuments)) {
    try { $rawRoots.Add(@{ Path = [Environment]::GetFolderPath($specialFolder); MaxDepth = 5 }) } catch { }
  }
  $depthByKey = @{}
  $pathByKey = @{}
  foreach ($rawRoot in $rawRoots) {
    if (-not $rawRoot -or -not $rawRoot.Path) { continue }
    $fullRoot = ''
    try { $fullRoot = [System.IO.Path]::GetFullPath([string]$rawRoot.Path).TrimEnd('\') } catch { continue }
    if ($fullRoot -eq '') { continue }
    if (-not [System.IO.Directory]::Exists($fullRoot)) { continue }
    $rootKey = $fullRoot.ToLowerInvariant()
    # 같은 경로가 두 규칙으로 들어오면(예: exe 가 Downloads 에 있음) 더 깊은 쪽을 채택
    if ($depthByKey.ContainsKey($rootKey) -and [int]$depthByKey[$rootKey] -ge [int]$rawRoot.MaxDepth) { continue }
    $depthByKey[$rootKey] = [int]$rawRoot.MaxDepth
    $pathByKey[$rootKey] = $fullRoot
  }
  $roots = @()
  foreach ($rootKey in $pathByKey.Keys) {
    $roots += , @{ Path = $pathByKey[$rootKey]; MaxDepth = [int]$depthByKey[$rootKey] }
  }
  return $roots
}

function Find-OldExeCandidates {
  # 2단계 평가의 1단계: 후보 파일(exe·zip) '전체 수집'만 하고 아무것도 삭제하지 않습니다.
  # 가드: 루트별 깊이(exe 폴더 0, 나머지 5), 방문 폴더 5000개, 전체 20초, reparse 폴더 제외,
  #       OFFLINE/REPARSE/RECALL_* 속성 파일 제외(OneDrive 자리표시자 강제 다운로드 방지), 10MB 초과 제외.
  $skipAttrMask = [int]0x1000 -bor [int]0x400 -bor [int]0x40000 -bor [int]0x400000
  $candidateByKey = @{}
  $zipByKey = @{}
  $skippedCount = 0
  $visitedDirs = 0
  $aborted = $false
  $abortReason = ''
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  foreach ($root in @(Get-OldExeSearchRoots)) {
    if ($aborted) { break }
    $rootMaxDepth = [int]$root.MaxDepth
    $stack = New-Object System.Collections.Generic.Stack[object]
    $stack.Push(@{ Path = [string]$root.Path; Depth = 0 })
    while ($stack.Count -gt 0) {
      if ($stopwatch.Elapsed.TotalSeconds -gt 20) { $aborted = $true; $abortReason = '시간 상한(20초)'; break }
      $visitedDirs++
      if ($visitedDirs -gt 5000) { $aborted = $true; $abortReason = '폴더 수 상한(5000개)'; break }
      $entry = $stack.Pop()
      foreach ($pattern in @('HoneyNogi*.exe', 'HoneyNogi*.zip')) {
        try {
          foreach ($filePath in [System.IO.Directory]::GetFiles([string]$entry.Path, $pattern)) {
            try {
              $fileInfo = New-Object System.IO.FileInfo($filePath)
              if (([int]$fileInfo.Attributes -band $skipAttrMask) -ne 0) { $skippedCount++; continue }
              if ($fileInfo.Length -gt 10MB) { $skippedCount++; continue }
              if ($pattern -eq 'HoneyNogi*.zip') { $zipByKey[$filePath.ToLowerInvariant()] = $filePath }
              else { $candidateByKey[$filePath.ToLowerInvariant()] = $filePath }
            } catch { $skippedCount++ }
          }
        } catch { }   # 접근 거부 등은 폴더 단위로 격리
      }
      if ([int]$entry.Depth -ge $rootMaxDepth) { continue }
      try {
        foreach ($subDir in [System.IO.Directory]::GetDirectories([string]$entry.Path)) {
          try {
            if (([System.IO.File]::GetAttributes($subDir) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
          } catch { continue }
          $stack.Push(@{ Path = $subDir; Depth = ([int]$entry.Depth + 1) })
        }
      } catch { }
    }
  }
  return @{ Files = @($candidateByKey.Values); ZipFiles = @($zipByKey.Values); Skipped = $skippedCount; Aborted = $aborted; AbortReason = $abortReason }
}

function Get-ZipEntryInfos {
  param([string]$ZipPath)
  # zip 내용물 판독: 폴더 엔트리를 제외한 각 파일의 잎 이름과 SHA-256 (디스크 추출 없이
  # 스트림으로 해시). 손상 zip/엔트리 과다(>5)/대형 엔트리는 Ok=$false = 보존 (실패 폐쇄).
  $entryInfos = @()
  $archive = $null
  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    foreach ($archiveEntry in $archive.Entries) {
      $entryFullName = [string]$archiveEntry.FullName
      if ($entryFullName.EndsWith('/') -or $entryFullName.EndsWith('\')) { continue }   # 폴더 엔트리
      if ([long]$archiveEntry.Length -gt 10MB) { return @{ Ok = $false; Entries = @() } }
      if (@($entryInfos).Count -ge 5) { return @{ Ok = $false; Entries = @() } }        # 공식 zip 은 엔트리 1개
      $sha = [System.Security.Cryptography.SHA256]::Create()
      $entryStream = $archiveEntry.Open()
      try {
        # 헤더의 Length 는 위조 가능하므로 '실제 읽은 누적량'으로 상한을 검사합니다
        # (압축폭탄 방어 - 리뷰 지적). 초과 시 즉시 중단하고 zip 전체를 보존합니다.
        $buffer = New-Object byte[] 81920
        $totalRead = [long]0
        while ($true) {
          $readCount = $entryStream.Read($buffer, 0, $buffer.Length)
          if ($readCount -le 0) { break }
          $totalRead += $readCount
          if ($totalRead -gt 10MB) { return @{ Ok = $false; Entries = @() } }
          [void]$sha.TransformBlock($buffer, 0, $readCount, $null, 0)
        }
        [void]$sha.TransformFinalBlock($buffer, 0, 0)
        $entryHash = (($sha.Hash | ForEach-Object { $_.ToString('x2') }) -join '')
      } finally {
        $entryStream.Dispose()
        $sha.Dispose()
      }
      $entryInfos += , @{ Name = [System.IO.Path]::GetFileName($entryFullName); Hash = $entryHash }
    }
    return @{ Ok = $true; Entries = $entryInfos }
  } catch {
    return @{ Ok = $false; Entries = @() }
  } finally {
    if ($archive) { try { $archive.Dispose() } catch { } }
  }
}

function Invoke-OldExeFileSweep {
  param($Manifest)
  # 2단계 평가의 2단계: 상한·매니페스트 검증 통과 후, 해시가 '이전 릴리스'와 일치하는
  # 파일만 완전 삭제합니다 (휴지통 미사용 - 사용자 확정. 원본은 개발자가 보유).
  # 반환: @{ Deleted; Unverified; Failed; Pending }
  $result = @{ Deleted = 0; Unverified = 0; Failed = 0; Pending = $false }
  # 대장이 없거나 손상이면 이번 실행은 정리 불가 - '완료'가 아니라 '재시도 대기'로 남깁니다
  # (일시적 추출 실패가 이 버전의 정리를 영구히 건너뛰게 하지 않음 - 리뷰 #6)
  if (-not (Test-ReleaseManifest -Manifest $Manifest)) {
    $script:cleanupLogLines += '[경고] 공식 릴리스 해시 목록을 읽지 못해 이번에는 구버전 파일을 정리하지 않습니다 (다음 실행 때 재시도)'
    $result.Pending = $true
    return $result
  }
  $found = Find-OldExeCandidates
  if ($found.Aborted) {
    $script:cleanupLogLines += ('[경고] 구버전 탐색을 중단했습니다({0}) - 다음 실행 때 다시 시도합니다' -f $found.AbortReason)
    $result.Pending = $true
    return $result
  }
  $candidateFiles = @($found.Files)
  $zipFiles = @($found.ZipFiles)
  if (($candidateFiles.Count + $zipFiles.Count) -eq 0) { return $result }
  if (($candidateFiles.Count + $zipFiles.Count) -gt 20) {
    # 비정상적으로 많은 후보 = 오판 가능성 → 한 건도 삭제하지 않고 중단 (설계 합의)
    $script:cleanupLogLines += ('[경고] HoneyNogi exe/zip 후보가 {0}개로 비정상적으로 많아 정리를 건너뜁니다' -f ($candidateFiles.Count + $zipFiles.Count))
    $result.Pending = $true
    return $result
  }
  # 자기 자신/현재 버전 사본 식별용: 자기 exe 의 경로와 해시 (내장 대장에는 자기 해시가 없음 -
  # 빌드 순환 방지 설계라, 방금 받은 새 버전 사본은 여기서 걸러 '확인 불가'로 세지 않습니다)
  $ownExePath = (Get-OwnExePath).ToLowerInvariant()
  $ownExeHash = ''
  if ($ownExePath) {
    try { $ownExeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ownExePath -ErrorAction Stop).Hash.ToLowerInvariant() } catch { }
  }
  $candidates = @()
  foreach ($candidateFile in $candidateFiles) {
    if ($ownExePath -and ($candidateFile.ToLowerInvariant() -eq $ownExePath)) { continue }   # 자기 자신 제외
    $candidateHash = ''
    try {
      $candidateHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidateFile -ErrorAction Stop).Hash.ToLowerInvariant()
    } catch { $result.Failed++; continue }
    if ($ownExeHash -and ($candidateHash -eq $ownExeHash)) { continue }                      # 현재 버전 사본 보존
    $candidates += , @{ Path = $candidateFile; Hash = $candidateHash }
  }
  $targets = @(Select-OldExeTargets -Candidates $candidates -Manifest $Manifest -CurrentVersion $appVersion)
  $result.Unverified = @($candidates).Count - $targets.Count
  foreach ($target in $targets) {
    try {
      [System.IO.File]::Delete([string]$target.Path)
      $result.Deleted++
      $script:cleanupLogLines += ('[안내] 구버전 삭제: {0}' -f $target.Path)
    } catch {
      $result.Failed++
      $script:cleanupLogLines += ('[경고] 구버전 삭제 실패(다음 실행 때 재시도): {0} - {1}' -f $target.Path, $_.Exception.Message)
    }
  }
  # zip 후보: 내용물이 '전부 공식 이전 릴리스 exe'일 때만 삭제 (2026-07-27 사용자 요청 -
  # HoneyNogi.zip 배포본 정리). 새 버전 zip(내용 = 자기 해시)과 판독 불가/혼합 zip 은 보존.
  $zipInfos = @()
  foreach ($zipFile in $zipFiles) {
    $zipRead = Get-ZipEntryInfos -ZipPath $zipFile
    if (-not [bool]$zipRead.Ok) { $result.Unverified++; continue }
    $zipEntries = @($zipRead.Entries)
    $isOwnCopy = $false
    if ($ownExeHash) {
      foreach ($zipEntry in $zipEntries) {
        if (([string]$zipEntry.Hash) -eq $ownExeHash) { $isOwnCopy = $true; break }
      }
    }
    if ($isOwnCopy) { continue }   # 현재 버전 zip 사본(방금 받은 배포물) 보존
    $zipInfos += , @{ Path = $zipFile; Entries = $zipEntries }
  }
  $zipTargets = @(Select-OldZipTargets -ZipInfos $zipInfos -Manifest $Manifest -CurrentVersion $appVersion)
  $result.Unverified += @($zipInfos).Count - @($zipTargets).Count
  foreach ($zipTarget in $zipTargets) {
    try {
      [System.IO.File]::Delete([string]$zipTarget.Path)
      $result.Deleted++
      $script:cleanupLogLines += ('[안내] 구버전 압축본 삭제: {0}' -f $zipTarget.Path)
    } catch {
      $result.Failed++
      $script:cleanupLogLines += ('[경고] 구버전 압축본 삭제 실패(다음 실행 때 재시도): {0} - {1}' -f $zipTarget.Path, $_.Exception.Message)
    }
  }
  if ($result.Unverified -gt 0) {
    $script:cleanupLogLines += ('[안내] 공식 릴리스 해시와 일치하지 않는 HoneyNogi 파일/압축본 {0}개는 보존했습니다' -f $result.Unverified)
  }
  $result.Pending = ($result.Failed -gt 0)
  return $result
}

function Set-CleanupMarker {
  param([string]$DoneVersion, [bool]$Pending)
  # '이 버전은 정리 완료(팝업 1회 소진)' 마커. fresh read 후 해당 키만 병합해 저장합니다.
  try {
    $markerConfig = Read-Config
    if (-not $markerConfig) { return }
    $markerNode = [pscustomobject]@{ doneVersion = $DoneVersion; pending = $Pending }
    if ($markerConfig.PSObject.Properties['oldExeCleanup']) { $markerConfig.oldExeCleanup = $markerNode }
    else { $markerConfig | Add-Member -NotePropertyName 'oldExeCleanup' -NotePropertyValue $markerNode }
    Save-Config $markerConfig
  } catch {
    $script:cleanupLogLines += ('[경고] 구버전 정리 마커 저장 실패: {0}' -f $_.Exception.Message)
  }
}

# ----- 구버전 정리: 실행 중 구버전 프로세스 종료 -----
function Invoke-OldProcessShutdown {
  # 실행 중 구버전 = 구버전이 띄운 powershell(GUI/워커). exe 파일은 잠기지 않지만(런처는
  # 즉시 종료) 구 GUI 가 전역 뮤텍스를 쥐고 있으면 새 버전이 못 뜨고, 구 워커는 계속
  # 게임을 조작하므로 반드시 정리합니다. 워커 스냅샷을 GUI 종료 '전'에 수집합니다.
  # 명령줄 대조는 '우리 사용자의 추출 경로 전체'로 - 다른 윈도우 사용자 세션 제외 (리뷰 #1).
  $shutdown = @{ GuiKilled = 0; WorkerKilled = 0 }
  $guiScriptPath = Join-Path $scriptRoot 'mabinogi_gui.ps1'
  $cimRows = @()
  try { $cimRows = @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction Stop) } catch { }
  # 임베디드 호스트 프로세스(HoneyNogi*.exe)도 열거합니다 (v2.1.4 작업 관리자 브랜딩).
  # 호스트 GUI/워커는 powershell 이 아니라서 기존 열거에 안 잡히면 구버전 정리가 통째로
  # 비켜가고, 구 호스트 GUI 가 뮤텍스를 쥔 채 새 버전이 '이미 실행 중'으로 죽습니다.
  # 워커 스냅샷은 아래 CommandLine 대조($workerScript 포함 여부)가 이름과 무관하게 잡아 줍니다.
  try { $cimRows += @(Get-CimInstance -ClassName Win32_Process -Filter "Name LIKE 'HoneyNogi%.exe'" -ErrorAction Stop) } catch { }
  $commandLineByPid = @{}
  foreach ($cimRow in $cimRows) { $commandLineByPid[[int]$cimRow.ProcessId] = [string]$cimRow.CommandLine }
  # 워커 스냅샷: 우리 추출 경로의 run_once 만. .Handle 접근으로 핸들을 지금 바인딩해
  # PID 재사용에도 '그 프로세스'만 가리키게 합니다 (Kill 은 캐시된 핸들 사용 - 리뷰 #3)
  $workerProcs = @()
  foreach ($cimRow in $cimRows) {
    if (([string]$cimRow.CommandLine).IndexOf($workerScript, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
    if ([int]$cimRow.ProcessId -eq $PID) { continue }
    try {
      $workerProc = Get-Process -Id ([int]$cimRow.ProcessId) -ErrorAction Stop
      [void]$workerProc.Handle
      $workerProcs += , $workerProc
    } catch { }
  }
  # 구버전 GUI 선정 (제목+명령줄 이중 확인, 순수부)
  $processByPid = @{}
  $snapshots = @()
  $currentGuiElsewhere = $false
  foreach ($psProc in @(@(Get-Process -Name 'powershell' -ErrorAction SilentlyContinue) +
      @(Get-Process -Name 'HoneyNogi*' -ErrorAction SilentlyContinue))) {
    try { [void]$psProc.Handle } catch { }   # 스냅샷 시점 핸들 바인딩 - 이후 Kill 이 PID 재사용본을 잡지 않음 (리뷰 #3)
    $processByPid[[int]$psProc.Id] = $psProc
    $procTitle = [string]$psProc.MainWindowTitle
    $procCmd = [string]$commandLineByPid[[int]$psProc.Id]
    $snapshots += , @{ Id = $psProc.Id; Title = $procTitle; CommandLine = $procCmd }
    # 현재 버전 GUI 가 이미 떠 있는지 (동시 기동 레이스에서 그쪽 워커를 죽이지 않기 위함 - 리뷰 #1/#2)
    # 임베디드 호스트 GUI 는 명령줄에 gui.ps1 경로가 없고 '--embedded-host' 플래그가 있습니다 (v2.1.4)
    if ([int]$psProc.Id -ne $PID -and $procTitle -eq ('꿀비노기 컨트롤 패널 v' + $appVersion) -and
        ($procCmd.IndexOf($guiScriptPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
         $procCmd.IndexOf('--embedded-host', [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) {
      $currentGuiElsewhere = $true
    }
  }
  $oldGuis = @(Select-OldGuiProcesses -Snapshots $snapshots -CurrentVersion $appVersion -GuiScriptPath $guiScriptPath)
  $hasWorkers = (@($workerProcs).Count -gt 0)
  foreach ($oldGui in $oldGuis) {
    $guiProc = $processByPid[[int]$oldGui.Id]
    if (-not $guiProc) { continue }
    try {
      if ($hasWorkers) {
        # 자동화 실행 중인 구 GUI 는 정상 닫기가 종료 확인창(YesNo)에 걸리므로 바로 강제 종료
        if (-not $guiProc.HasExited) { $guiProc.Kill() }
      } else {
        [void]$guiProc.CloseMainWindow()
        if (-not $guiProc.WaitForExit(3000)) {
          if (-not $guiProc.HasExited) { $guiProc.Kill() }
        }
      }
      [void]$guiProc.WaitForExit(3000)
      $shutdown.GuiKilled++
    } catch { }
  }
  # 워커 종료. 단 '현재 버전 GUI 가 다른 프로세스로 이미 떠 있으면' 워커가 그쪽의 정상
  # 워커일 수 있으므로 일절 건드리지 않습니다 (동시 기동 레이스 - 어차피 이쪽 인스턴스는
  # 곧 GUI 뮤텍스에서 중복 실행으로 종료되고, 방금 죽인 구 GUI 의 워커가 남더라도 회차
  # 하나를 끝내면 스스로 종료됨). 그 외 시점의 run_once 워커는 전부 구버전/고아입니다.
  if ($currentGuiElsewhere) {
    return $shutdown
  }
  foreach ($workerProc in $workerProcs) {
    try {
      if (-not $workerProc.HasExited) {
        $workerProc.Kill()
        [void]$workerProc.WaitForExit(3000)
        $shutdown.WorkerKilled++
      }
    } catch { }
  }
  if ($shutdown.GuiKilled -gt 0 -or $shutdown.WorkerKilled -gt 0) {
    $script:cleanupLogLines += ('[안내] 실행 중이던 구버전을 종료했습니다 (GUI {0}개, 워커 {1}개)' -f $shutdown.GuiKilled, $shutdown.WorkerKilled)
  }
  return $shutdown
}

# ----- 구버전 정리: 안내 팝업 (자동 닫힘 - 클릭 대기 없음, 무인 재시작 보호) -----
function Show-CleanupPopup {
  param([string]$Text)
  $popupForm = New-Object System.Windows.Forms.Form
  $popupForm.FormBorderStyle = 'None'
  $popupForm.TopMost = $true
  $popupForm.ShowInTaskbar = $false
  $popupForm.StartPosition = 'CenterScreen'
  $popupForm.Size = New-Object System.Drawing.Size(440, 100)
  $popupForm.BackColor = [System.Drawing.Color]::FromArgb(255, 250, 235)
  $popupLabel = New-Object System.Windows.Forms.Label
  $popupLabel.Dock = 'Fill'
  $popupLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
  $popupLabel.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
  $popupLabel.ForeColor = [System.Drawing.Color]::FromArgb(120, 84, 20)
  $popupLabel.Text = $Text
  $popupForm.Controls.Add($popupLabel)
  $popupForm.Show()
  $popupForm.Refresh()
  [System.Windows.Forms.Application]::DoEvents()
  return @{ Form = $popupForm; Label = $popupLabel }
}

function Invoke-OldExeCleanup {
  # 구버전 정리 전체 오케스트레이션. 동시 최초 실행 레이스는 전용 뮤텍스로 직렬화하고,
  # 획득 후 config 를 다시 읽어 판정합니다 (설계 합의). 프로세스 종료는 최초 1회(full)만,
  # pending 재시도는 파일만 건드립니다.
  if ($script:cleanupInProgress) { return }
  $script:cleanupInProgress = $true
  $script:cleanupProcessPhaseDone = $false
  $cleanupMutex = $null
  $cleanupMutexHeld = $false
  $popup = $null
  try {
    $cleanupMutex = New-Object System.Threading.Mutex($false, 'Global\HoneyNogiCleanup')
    try {
      # 대기 40초 = 정리 최대 소요(탐색 20초 + 프로세스 정리 + 해싱)보다 길게 - 동시 기동 시
      # 두 번째 인스턴스가 첫 인스턴스의 정리 완료를 실제로 기다리게 합니다 (리뷰 #2)
      $cleanupMutexHeld = $cleanupMutex.WaitOne(40000)
    } catch [System.Threading.AbandonedMutexException] {
      $cleanupMutexHeld = $true
    }
    if (-not $cleanupMutexHeld) {
      # 다른 인스턴스가 40초 넘게 정리 중 = 그쪽이 GUI 가 됩니다. 이 인스턴스가 정리 없이
      # 계속 진행하면 그쪽 정리와 레이스가 생기므로 조용히 종료합니다 (리뷰 #2)
      $script:cleanupMutexTimedOut = $true
      return
    }
    $markerConfig = Read-Config
    $doneVersion = ''
    $pending = $false
    if ($markerConfig -and $markerConfig.PSObject.Properties['oldExeCleanup'] -and $markerConfig.oldExeCleanup) {
      if ($markerConfig.oldExeCleanup.PSObject.Properties['doneVersion']) { $doneVersion = [string]$markerConfig.oldExeCleanup.doneVersion }
      if ($markerConfig.oldExeCleanup.PSObject.Properties['pending']) { $pending = ConvertTo-StrictBoolean $markerConfig.oldExeCleanup.pending $false }
    }
    $plan = Get-CleanupPlan -DoneVersion $doneVersion -Pending $pending -CurrentVersion $appVersion
    if ($plan -eq 'skip') { return }
    $manifest = Read-ReleaseManifest
    if ($plan -eq 'files-only') {
      # 안내 창은 버전당 1회 약속 - 재시도는 조용히 (로그만)
      $sweep = Invoke-OldExeFileSweep -Manifest $manifest
      Set-CleanupMarker -DoneVersion $appVersion -Pending ([bool]$sweep.Pending)
      return
    }
    # full: 신규 버전 최초 실행 1회
    $popup = Show-CleanupPopup -Text ('구버전 확인 및 삭제를 진행합니다.' + [Environment]::NewLine + '잠시만 기다려주세요…')
    $shutdown = Invoke-OldProcessShutdown
    $script:cleanupProcessPhaseDone = $true   # 여기 도달 = 프로세스 정리 완료 (리뷰 #5)
    if ($shutdown.WorkerKilled -gt 0) { Release-StuckInput }   # 워커 강제 종료 시 키/마우스 눌림 해제
    $sweep = Invoke-OldExeFileSweep -Manifest $manifest
    Set-CleanupMarker -DoneVersion $appVersion -Pending ([bool]$sweep.Pending)
    $resultText = if ([int]$sweep.Deleted -gt 0) { ('구버전 {0}개 삭제 완료' -f $sweep.Deleted) }
      elseif ([bool]$sweep.Pending) { '일부를 확인하지 못했습니다 (다음 실행 때 재시도)' }
      else { '구버전이 없습니다' }
    $popup.Label.Text = $resultText
    $popup.Form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    $closeAt = [DateTime]::UtcNow.AddMilliseconds(2500)
    while ([DateTime]::UtcNow -lt $closeAt) {
      Start-Sleep -Milliseconds 100
      [System.Windows.Forms.Application]::DoEvents()
    }
  } catch {
    # 어떤 오류도 프로그램 시작을 막지 않습니다 (예외 경로 MessageBox 금지 - 무인 운용 보호).
    # 마커는 '프로세스 정리까지 끝난 경우'에만 남깁니다 - 그 전에 실패했으면 다음 실행이
    # full 정리(구버전 종료 포함)를 다시 시도해야 하기 때문입니다 (리뷰 #5)
    $script:cleanupLogLines += ('[경고] 구버전 정리 중 오류: {0}' -f $_.Exception.Message)
    if ($script:cleanupProcessPhaseDone) {
      try { Set-CleanupMarker -DoneVersion $appVersion -Pending $true } catch { }
    }
  } finally {
    if ($popup -and $popup.Form) {
      try { $popup.Form.Close() } catch { }
      try { $popup.Form.Dispose() } catch { }
    }
    if ($cleanupMutexHeld) { try { $cleanupMutex.ReleaseMutex() } catch { } }
    if ($cleanupMutex) { try { $cleanupMutex.Dispose() } catch { } }
    $script:cleanupInProgress = $false
  }
}

# ============================================================
#  구버전 정리 실행 + 중복 실행 방지 (순서 중요 - 위 이동 안내 주석 참고)
# ============================================================
$script:cleanupInProgress = $false
$script:cleanupMutexTimedOut = $false
try { Invoke-OldExeCleanup } catch { $script:cleanupLogLines += ('[경고] 구버전 정리 실행 실패: {0}' -f $_.Exception.Message) }
if ($script:cleanupMutexTimedOut) { exit }   # 다른 인스턴스가 정리 중 - 그쪽에 양보하고 종료

# 컨트롤 패널이 여러 개 뜨면 [시작] 시 서로의 워커를 '기존 프로세스'로 종료시키고
# 설정 저장도 서로 덮어쓰므로, 두 번째 인스턴스는 안내 후 스스로 종료합니다.
$script:guiMutex = New-Object System.Threading.Mutex($false, 'Global\HoneyNogiGui')
$guiMutexAcquired = $false
try {
  $guiMutexAcquired = $script:guiMutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
  # 이전 GUI가 강제 종료되어 뮤텍스가 버려진 경우: 이 인스턴스가 소유권을 이어받음
  $guiMutexAcquired = $true
}
if (-not $guiMutexAcquired) {
  [System.Windows.Forms.MessageBox]::Show(
    '컨트롤 패널이 이미 실행 중입니다. 기존 창을 사용해 주세요.' + [Environment]::NewLine +
    '(기존 창이 안 보이면 작업 관리자에서 powershell.exe 또는 꿀비노기를 확인하세요)',
    '꿀비노기', [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
  try { $script:guiMutex.Dispose() } catch { }
  exit
}

# ----- 상태 변수 -----
$script:worker = $null
$script:running = $false
# 실행 중 콘텐츠 상세 자식들의 원래 Enabled 스냅샷 (커스텀 리스트 스크롤 허용 잠금 방식.
# null = 미실행 상태. 스냅샷 존재 여부가 전이 토큰 - Set-UiRunning 중복 호출에도 멱등)
$script:contentDetailEnabledSnapshot = $null
$script:stopRequested = $false
$script:completedCycles = 0
$script:targetCycles = 0      # 0 = 무한
$script:targetTime = $null    # 시간 지정 모드의 목표 시각 (null = 사용 안 함)
$script:logOffset = [long]0
$script:recoveryLogOffset = [long]0
$script:uiReady = $false      # 초기 로딩 중 설정 저장이 일어나지 않게 하는 플래그
$script:preparedStreak = 0    # 연속 '준비 실행'(코드 10) 횟수 - 화면 오판으로 인한 무한 준비 루프 방지 (컨트롤러와 동일)
$script:lastWorkerDoneReason = ''  # 이번 회차 로그의 마지막 '[완료]' 사유 - 코드 4 상태줄에 실제 이유 표시용 (2026-08-02)
# --- 커스텀 반복(던전/어비스 리스트 모드) 실행 컨텍스트 ---
$script:customActive = $false        # 이번 실행이 커스텀 반복 모드인지 (시작 시 확정 - 실행 중 라디오 변경 영향 차단)
$script:customConfigSection = 'customRepeat' # 실행 중 진행 기록을 읽고 쓸 config 섹션
$script:customErrorStreak = 0        # 같은 항목 연속 오류(코드 1) 횟수 - 2회까지 자동 재시작, 초과 시 정지
$script:customPrevItem = ''          # 직전 '완료' 항목 토큰 (HONEYNOGI_CUSTOM_PREV 용 - 빈 값이면 선택 화면 절차)
$script:customViewShuffled = $false  # 랜덤 진행: 커스텀 리스트가 '이번 바퀴 순서' 표시 상태인지 (저장은 Tag 정렬로 등록 순서 보존)
$script:customRestart = $false       # 다음 회차가 '오류 후 자동 재시작'인지 (복구 화면 판을 완료로 계상하는 플래그)
$script:customRecoveryPending = $false # 완료 마커가 있는 코드 1 뒤, 같은 항목의 결과 화면 마무리만 복구 중인지
$script:customMarkerIgnore = $false  # 실행 직전 이전 마커 삭제 실패 시 이번 회차는 마커 무시 (오계상 방지)
$script:crLoading = $false           # 커스텀 리스트뷰를 프로그램적으로 조작 중일 때 저장 이벤트 억제 가드
# 혼합 리스트로 반복이 '횟수 1바퀴'로 잠겼는지 (던전/심층 섹션별).
# PrevInfinite/PrevLaps = 잠금 직전의 반복 설정 (해제 시 복원 - 2026-08-01 3차 점검)
$script:crMixLockState = @{
  cr  = @{ Locked = $false; PrevInfinite = $false; PrevLaps = 1 }
  dcr = @{ Locked = $false; PrevInfinite = $false; PrevLaps = 1 }
}
$script:crSwitching = $false         # 카테고리 전환에 의한 커스텀 라디오 폴백/복원 중 가드 (enabled 보존)
$script:customEnabledWish = $false   # 커스텀 반복 '선택 의도' - 던전 외 카테고리에서 라디오가 풀려도 보존 (config enabled 와 동기)
$script:customProgressReset = $false # 업데이트 이전(Update-ConfigToLatest)에서 진행 기록을 초기화했는지 (시작 로그 안내용)
$script:customProgressResetSections = @() # 그중 실제로 초기화된 섹션들 (그 섹션 마커만 저장 성공 뒤 삭제)
$script:customMarkerClearFailed = $false  # 그 마커 무효화가 실패했는지 (시작 안내에 경고로 노출)
$script:gatherWaitReset = 0          # '진행 없음' 설정을 기본값으로 되돌렸으면 '되돌리기 전 값' (의미 변경 안내용)
$script:configMigrationError = $null # 설정 자동 이전 실패 원인 (실패와 '이전 불필요'를 구분해 시작 로그에 표시)
$script:acrLockUpdating = $false     # 어비스 커스텀 방식·매칭 잠금 적용 중 재진입 가드 (라디오 Checked 변경 → 패널 갱신 → 재호출 방지)
$script:acrLockOn = $false           # 어비스 방식·매칭이 리스트 값으로 잠겨 있는지 (비활성 라디오 툴팁 판정용)
$script:acrTipShownFor = $null       # 현재 툴팁을 띄워 둔 잠긴 라디오 (같은 컨트롤에서 반복 호출 → 깜박임 방지)
# --- 사용 승인(화이트리스트) 상태 ---
$script:deviceCode = Get-LocalDeviceCode   # 이 PC 의 식별 코드 (빈 값 = 산출 불가 → 차단측)
$script:approvalState = 'no-cache'   # 'approved-live'|'approved-grace'|'denied'|'no-cache' (시작 시 캐시로 잠정 판정)
$script:approvalPendingStart = $false # 시작 버튼이 눌려 '조회 완료 후 시작'이 예약된 상태 (새 자동화 시작 시 검사 스펙)
$script:approvalDeniedSeen = $false  # 이 세션에서 '유효 명단에 부재(철회)'를 확인한 적 있음 - 캐시 삭제가
                                     # 실패해도 세션 내에서는 이후 조회 실패가 유예로 되살아나지 않게 함 (리뷰 #4)
$script:approvalPs = $null           # 진행 중 명단 조회 러닝스페이스 (null = 조회 없음, single-flight 가드)
$script:approvalAsync = $null
# 조회 시작 시각. GUI 쪽 상한의 기준입니다 - 러닝스페이스가 끝내 반환하지 않으면 폴링
# 타이머가 영원히 돌고, [시작] 버튼을 되살리는 유일한 경로(Complete-ApprovalCheck)에
# 도달하지 못해 **시작 버튼과 F9 가 영구 잠깁니다** (2026-08-10 8차 점검).
$script:approvalStartedAt = $null
$approvalFetchTimeoutSeconds = 25    # 내부 -TimeoutSec 10 + 리다이렉트/DNS 여유

function Start-ApprovalCheck {
  # 명단 비동기 조회 시작. 진행 중이면 새로 만들지 않고 합류합니다 (single-flight -
  # 조회는 한 번에 하나뿐이라 늦게 온 과거 응답이 최신 판정을 덮는 역전이 생기지 않음).
  param([switch]$ForStart)
  if ($ForStart) { $script:approvalPendingStart = $true }
  if ($script:approvalPs) { return }
  try {
    $script:approvalPs = [System.Management.Automation.PowerShell]::Create()
    [void]$script:approvalPs.AddScript({
        param($fetchUrl)
        try {
          # PS 5.1 기본 설정에는 TLS 1.2가 빠져 있을 수 있어 추가합니다 (3072 = Tls12).
          # -UseBasicParsing: IE 초기 설정 의존 제거 (무인 환경). /exec 는 302 리다이렉트를
          # 거치므로 기본 리다이렉트 추종을 그대로 둡니다. ?t= 는 캐시 무효화용입니다.
          [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
          $response = Invoke-WebRequest -Uri ($fetchUrl + '?t=' + [DateTime]::UtcNow.Ticks) -UseBasicParsing -TimeoutSec 10
          if ([int]$response.StatusCode -ne 200) { return '' }
          return [string]$response.Content
        } catch { return '' }
      }).AddArgument($whitelistUrl)
    $script:approvalAsync = $script:approvalPs.BeginInvoke()
    $script:approvalStartedAt = Get-Date
    if ($script:approvalTimer) { $script:approvalTimer.Start() }
  } catch {
    # 조회 기동 자체가 실패하면(러닝스페이스 생성 불가 등) '조회 실패'로 즉시 판정합니다 -
    # 방치하면 single-flight 가드와 예약된 시작이 영구 고착됨 (리뷰 #9)
    try { if ($script:approvalPs) { $script:approvalPs.Dispose() } } catch { }
    $script:approvalPs = $null
    $script:approvalAsync = $null
    Complete-ApprovalCheck -ResponseText ''
  }
}

function Complete-ApprovalCheck {
  param([string]$ResponseText)
  # 조회 결과 반영: 검증 → 판정 → 캐시 갱신/삭제 → UI/로그 → 예약된 시작 처리.
  # 실행 중인 자동화는 어떤 판정에도 건드리지 않습니다 (다음 새 시작부터 적용).
  $parsed = Test-WhitelistResponse -Text $ResponseText
  $cache = Get-ConfigApprovalCache
  $decision = Get-ApprovalDecision -FetchOk ([bool]$parsed.Valid) -Codes $parsed.Codes -DeviceCode $script:deviceCode `
    -CacheApprovedAtUtc $cache.At -CacheDeviceCode $cache.Code -NowUtc ([DateTime]::UtcNow) -GraceDays $approvalGraceDays
  # 세션 내 철회 tombstone: 이 세션에서 denied 를 확인했다면, 캐시 삭제 성패와 무관하게
  # 이후 조회 실패가 grace 로 되살아나지 못하게 합니다 (리뷰 #4)
  if ($decision -eq 'approved-grace' -and $script:approvalDeniedSeen) { $decision = 'no-cache' }
  $script:approvalState = $decision
  switch ($decision) {
    'approved-live' { $script:approvalDeniedSeen = $false; Set-ApprovalCache }
    'denied' { $script:approvalDeniedSeen = $true; Clear-ApprovalCache }   # 명시적 부재 = 철회 확정, 유예 근거 제거
  }
  # 확인 결과는 '매번' 로그로 남깁니다 - 상태가 이전과 같다고 침묵하면 [승인 다시 확인]이
  # 동작하지 않는 것처럼 보임 (2026-07-27 타 PC 실기 제보). denied 문구는 사용자용으로
  # 간결하게 하되 기기 코드 끝자리는 유지합니다 - 제보 스크린샷 한 장으로 관리자가 명단과
  # 대조(미등록/오타/체크 꺼짐 구분)할 수 있는 진단 정보 (2026-07-28 사용자 확정 문구).
  $codeTail = $(if ($script:deviceCode.Length -ge 6) { $script:deviceCode.Substring($script:deviceCode.Length - 6) } else { '' })
  switch ($decision) {
    'approved-live' { Add-GuiLog '[안내] 사용 승인 확인 완료' }
    'approved-grace' { Add-GuiLog '[안내] 승인 서버에 연결하지 못했지만 최근 승인 기록(7일 이내)으로 계속 사용합니다' }
    'denied' { Add-GuiLog ('[경고] 사용 승인이 확인되지 않았습니다 - 개발자에게 문의해 주세요 (기기 코드 끝자리 {0})' -f $codeTail) }
    default { Add-GuiLog '[경고] 사용 승인을 확인하지 못했습니다 (인터넷 연결 확인) - 승인 기록이 없어 시작할 수 없습니다' }
  }
  Update-ApprovalUi
  if ($script:approvalPendingStart) {
    $script:approvalPendingStart = $false
    $lblStatus.Text = '대기 중'
    if (Test-ApprovalAllowsStart) {
      Invoke-StartAutomation
    } else {
      Add-GuiLog '[안내] 사용 승인이 확인되지 않아 시작하지 않았습니다'
    }
  }
}

function Update-ApprovalUi {
  # 미승인이면 '사용 승인' 그룹을 보여주고 시작 버튼을 잠급니다. 팝업 없음(메인 폼 내 표시).
  # Stop/즉시 중지 등 실행 중 제어는 승인 상태와 무관하게 그대로 둡니다.
  $approved = Test-ApprovalAllowsStart
  $grpApproval.Visible = -not $approved
  if (-not $approved) {
    $grpApproval.BringToFront()
    $txtApprovalCode.Text = $(if ($script:deviceCode) { $script:deviceCode } else { '기기 코드를 계산할 수 없습니다 - 개발자에게 문의해 주세요' })
    $lblApprovalMsg.Text = $(if ($script:approvalState -eq 'denied') {
        '이 PC는 사용 승인 목록에 없습니다. 아래 기기 코드를 복사해 개발자에게 보내 승인을 요청해 주세요.'
      } else {
        '승인 확인에 실패했습니다 (인터넷 연결 확인). 아직 승인 전이라면 아래 기기 코드를 개발자에게 보내 주세요.'
      })
  }
  if (-not $script:running) {
    $btnStart.Enabled = $approved
    # 대분류 전환도 승인 전에는 잠금 (승인 오버레이가 버튼 줄을 다 덮지만 이중 방어 - 리뷰 조건 A)
    $btnCatBattle.Enabled = $approved
    $btnCatLife.Enabled = $approved
    $btnCatEtc.Enabled = $approved
  }
}

# ============================================================
#  UI 구성
# ============================================================
$form = New-Object System.Windows.Forms.Form
# 허니 테마 팔레트 (컨트롤 생성 코드가 참조하므로 폼 생성보다 먼저 정의 - 테마 일괄 적용
# 함수(Apply-HoneyTheme)는 기존대로 모든 컨트롤 생성 뒤에 실행됩니다)
$script:themeBack     = [System.Drawing.Color]::FromArgb(253, 248, 238)  # 창 배경 (크림)
$script:themeControl  = [System.Drawing.Color]::FromArgb(255, 253, 247)  # 일반 버튼 (밝은 크림)
$script:themeInput    = [System.Drawing.Color]::FromArgb(255, 255, 255)  # 입력 배경 (흰색)
$script:themeLogBack  = [System.Drawing.Color]::FromArgb(40, 34, 24)     # 로그 배경 (진한 갈색 콘솔풍)
$script:themeText     = [System.Drawing.Color]::FromArgb(66, 50, 22)     # 기본 글자 (진한 갈색)
$script:themeMuted    = [System.Drawing.Color]::FromArgb(158, 138, 104)  # 흐린 글자
$script:themeBorder   = [System.Drawing.Color]::FromArgb(226, 205, 160)  # 버튼 테두리 (연한 꿀색)
$script:themeTitle    = [System.Drawing.Color]::FromArgb(191, 128, 7)    # 섹션 제목 (꿀 갈색)
$script:themeHoney    = [System.Drawing.Color]::FromArgb(247, 181, 0)    # 꿀색 (강조)
$script:themeHoneyInk = [System.Drawing.Color]::FromArgb(66, 45, 0)      # 꿀색 위 글자
$script:themeDanger   = [System.Drawing.Color]::FromArgb(222, 105, 92)   # 위험(중지)

$form.Text = "꿀비노기 컨트롤 패널 v$appVersion"
$form.Size = New-Object System.Drawing.Size(560, 872)   # 폭 616→560 (2026-08-04 시안 확정 - 문구·배치 불변, 폭 상수만 축소)
# 세로 크기 조절 가능: 로그 영역이 창 크기에 맞춰 늘어나고 줄어듭니다 (Anchor 설정 참고)
$form.FormBorderStyle = 'Sizable'
$form.MinimumSize = New-Object System.Drawing.Size(560, 700)
$form.MaximizeBox = $true
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
# 창/작업표시줄 아이콘: 스크립트 폴더에 app.ico 가 있으면 사용합니다 (exe가 실행 시 추출)
$appIconPath = Join-Path $scriptRoot 'app.ico'
if (Test-Path -LiteralPath $appIconPath) {
  try { $form.Icon = New-Object System.Drawing.Icon($appIconPath) } catch { }
}

# --- 상태 표시 ---
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 12)
$lblStatus.Size = New-Object System.Drawing.Size(514, 26)
$lblStatus.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$lblStatus.Text = '대기 중'
$lblStatus.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($lblStatus)

# --- 대분류: [전투 | 생활] (v2.0.0 - 2026-08-05 시안 확정. 상태줄 아래·반복 그룹 위) ---
# 활성 쪽 = 시작 버튼과 같은 꿀색 강조 (스타일은 Update-MainCategoryVisual 이 담당 -
# Apply-HoneyTheme 가 모든 버튼을 일반 스타일로 덮으므로 테마 적용 '후' 반드시 재호출.
# 기본값 'battle' - 기존 사용자 화면 변화 없음. 전환 로직은 Set-MainCategory 단일 진입점.
$script:mainCategory = 'battle'
# 2026-08-15 '기타' 신설: 2버튼(254폭) → 3버튼(168폭), 총폭 514 불변 (시안 사용자 확정)
$btnCatBattle = New-Object System.Windows.Forms.Button
$btnCatBattle.Name = 'btnCatBattle'
$btnCatBattle.Text = '전투'
$btnCatBattle.Location = New-Object System.Drawing.Point(15, 44)
$btnCatBattle.Size = New-Object System.Drawing.Size(168, 32)
$form.Controls.Add($btnCatBattle)
$btnCatLife = New-Object System.Windows.Forms.Button
$btnCatLife.Name = 'btnCatLife'
$btnCatLife.Text = '생활'
$btnCatLife.Location = New-Object System.Drawing.Point(188, 44)
$btnCatLife.Size = New-Object System.Drawing.Size(168, 32)
$form.Controls.Add($btnCatLife)
$btnCatEtc = New-Object System.Windows.Forms.Button
$btnCatEtc.Name = 'btnCatEtc'
$btnCatEtc.Text = '기타'
$btnCatEtc.Location = New-Object System.Drawing.Point(361, 44)
$btnCatEtc.Size = New-Object System.Drawing.Size(168, 32)
$form.Controls.Add($btnCatEtc)
$btnCatBattle.Add_Click({ Set-MainCategory -Category 'battle' })
$btnCatLife.Add_Click({ Set-MainCategory -Category 'life' })
$btnCatEtc.Add_Click({ Set-MainCategory -Category 'etc' })
# 아이콘은 Button.Image 대신 Paint 로 '중앙 글자 바로 왼쪽'에 직접 그림 (2026-08-05 사용자
# 제보 반복 수렴: 묶음 중앙 = 글자 밀림 / 독립 정렬 = 아이콘이 구석에 붙어 글자와 멀어짐.
# 기본 정렬로는 '글자 정중앙 + 아이콘 인접' 조합이 불가 - 그리기 좌표를 글자 폭에서 계산)
$btnCatBattle.Add_Paint({ Invoke-MainCatButtonPaint -Sender $this -PaintArgs $_ })
$btnCatLife.Add_Paint({ Invoke-MainCatButtonPaint -Sender $this -PaintArgs $_ })
$btnCatEtc.Add_Paint({ Invoke-MainCatButtonPaint -Sender $this -PaintArgs $_ })

# --- 사용 승인 안내 (미승인일 때만 표시 - 설정 영역 위에 겹쳐 나타남, 팝업 아님) ---
# 높이 158: 대분류 버튼 줄 신설로 y144 의 시작 버튼 줄까지 덮어야 함 (리뷰 조건 A -
# 42+158 = 200 으로 콘텐츠 선택(190) 상단 10px 를 덮던 기존 범위도 유지)
$grpApproval = New-Object System.Windows.Forms.GroupBox
$grpApproval.Text = '사용 승인 필요'
$grpApproval.Location = New-Object System.Drawing.Point(15, 42)
$grpApproval.Size = New-Object System.Drawing.Size(514, 158)
$grpApproval.Visible = $false
$form.Controls.Add($grpApproval)

$lblApprovalMsg = New-Object System.Windows.Forms.Label
$lblApprovalMsg.Location = New-Object System.Drawing.Point(12, 20)
$lblApprovalMsg.Size = New-Object System.Drawing.Size(490, 34)
$lblApprovalMsg.Text = ''
$grpApproval.Controls.Add($lblApprovalMsg)

$txtApprovalCode = New-Object System.Windows.Forms.TextBox
$txtApprovalCode.Location = New-Object System.Drawing.Point(12, 58)
$txtApprovalCode.Size = New-Object System.Drawing.Size(490, 24)
$txtApprovalCode.ReadOnly = $true
$txtApprovalCode.Font = New-Object System.Drawing.Font('Consolas', 8)
$grpApproval.Controls.Add($txtApprovalCode)

$btnApprovalCopy = New-Object System.Windows.Forms.Button
$btnApprovalCopy.Text = '기기 코드 복사'
$btnApprovalCopy.Location = New-Object System.Drawing.Point(12, 86)
$btnApprovalCopy.Size = New-Object System.Drawing.Size(120, 26)
$grpApproval.Controls.Add($btnApprovalCopy)

$btnApprovalRecheck = New-Object System.Windows.Forms.Button
$btnApprovalRecheck.Text = '승인 다시 확인'
$btnApprovalRecheck.Location = New-Object System.Drawing.Point(140, 86)
$btnApprovalRecheck.Size = New-Object System.Drawing.Size(120, 26)
$grpApproval.Controls.Add($btnApprovalRecheck)

$btnApprovalCopy.Add_Click({
    # 클립보드 실패(원격 세션 등)에도 코드가 전달되도록 로그에도 함께 남깁니다
    try { [System.Windows.Forms.Clipboard]::SetText([string]$txtApprovalCode.Text) } catch { }
    Add-GuiLog ('[안내] 기기 코드: {0}' -f [string]$txtApprovalCode.Text)
    Add-GuiLog '[안내] 기기 코드를 복사했습니다 - 개발자에게 보내 주세요'
  })
$btnApprovalRecheck.Add_Click({
    Add-GuiLog '[안내] 사용 승인을 다시 확인합니다…'
    Start-ApprovalCheck
  })

# --- 반복 설정 (가로 한 줄로 압축) ---
$grpRepeat = New-Object System.Windows.Forms.GroupBox
$grpRepeat.Text = '반복'
$grpRepeat.Location = New-Object System.Drawing.Point(15, 84)   # 대분류 줄 신설로 +40 (v2.0.0)
$grpRepeat.Size = New-Object System.Drawing.Size(514, 52)
$form.Controls.Add($grpRepeat)

# 4번째 라디오('커스텀 반복')를 한 줄에 넣기 위해 기존 컨트롤들의 가로 배치를 압축했습니다
# (화면 좌표가 아닌 GUI 배치라 coordsVersion 과 무관)
$rbInfinite = New-Object System.Windows.Forms.RadioButton
$rbInfinite.Text = '무한 반복'
$rbInfinite.Location = New-Object System.Drawing.Point(15, 20)
$rbInfinite.Size = New-Object System.Drawing.Size(80, 22)
$rbInfinite.Checked = $true
$grpRepeat.Controls.Add($rbInfinite)

$rbCount = New-Object System.Windows.Forms.RadioButton
$rbCount.Text = '횟수 지정:'
$rbCount.Location = New-Object System.Drawing.Point(100, 20)
$rbCount.Size = New-Object System.Drawing.Size(80, 22)
$grpRepeat.Controls.Add($rbCount)

$numCount = New-Object System.Windows.Forms.NumericUpDown
$numCount.Location = New-Object System.Drawing.Point(180, 18)
$numCount.Size = New-Object System.Drawing.Size(55, 24)
$numCount.Minimum = 1
$numCount.Maximum = 9999
$numCount.Value = 2
$grpRepeat.Controls.Add($numCount)

$rbTime = New-Object System.Windows.Forms.RadioButton
$rbTime.Text = '시간 지정:'
$rbTime.Location = New-Object System.Drawing.Point(240, 20)
$rbTime.Size = New-Object System.Drawing.Size(80, 22)
$grpRepeat.Controls.Add($rbTime)

$dtpUntil = New-Object System.Windows.Forms.DateTimePicker
$dtpUntil.Format = 'Custom'
$dtpUntil.CustomFormat = 'HH:mm'
$dtpUntil.ShowUpDown = $true
$dtpUntil.Location = New-Object System.Drawing.Point(320, 18)
$dtpUntil.Size = New-Object System.Drawing.Size(66, 24)
$grpRepeat.Controls.Add($dtpUntil)

# 커스텀 반복 (던전/어비스 실행 지원, 사냥터 미지원).
# 선택하면 상단 횟수/시간 입력은 비활성 - 반복 방식은 콘텐츠별 리스트의 '리스트 반복'이 담당합니다.
# 선택 여부는 config(customRepeat.enabled)에 영속화됩니다 (재시작 후 옛 단일 설정 오작동 방지).
$rbCustomRepeat = New-Object System.Windows.Forms.RadioButton
$rbCustomRepeat.Text = '커스텀 반복'
$rbCustomRepeat.Location = New-Object System.Drawing.Point(390, 20)
$rbCustomRepeat.Size = New-Object System.Drawing.Size(110, 22)
$rbCustomRepeat.Enabled = $false   # 던전/어비스 카테고리에서 활성 (updateCategoryPanels 가 제어)
$grpRepeat.Controls.Add($rbCustomRepeat)

$rbCustomRepeat.Add_CheckedChanged({
    # 커스텀 선택 시 상단 횟수/시간 입력 비활성 (택일 관계 - 반복은 하단 '리스트 반복'이 담당)
    $numCount.Enabled = -not $rbCustomRepeat.Checked
    $dtpUntil.Enabled = -not $rbCustomRepeat.Checked
    if (-not $script:crSwitching) {
      # 카테고리 전환에 의한 표시상 폴백/복원(crSwitching)이 아닌 '실제 선택 변경'만 의도로 기억/저장
      $script:customEnabledWish = [bool]$rbCustomRepeat.Checked
      if ($script:uiReady -and -not $script:crLoading) { Save-CustomRepeatToConfig }
    }
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })

# --- 제어 버튼 (한 줄) ---
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = '시작(F9)'
$btnStart.Location = New-Object System.Drawing.Point(15, 144)   # 대분류 줄 신설로 +40 (v2.0.0)
$btnStart.Size = New-Object System.Drawing.Size(150, 38)
$btnStart.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(70, 160, 90)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = 'Flat'
$form.Controls.Add($btnStart)

# 중지 버튼 2개는 평소 숨겨져 있다가 실행 중에만 시작 버튼 자리부터 나타납니다
# (대기 중 중지 오클릭 / 실행 중 시작 오클릭 방지 - Set-UiRunning 이 전환)
$btnSafeStop = New-Object System.Windows.Forms.Button
$btnSafeStop.Text = ("안전 중지(F9)" + [Environment]::NewLine + "(회차 완료 후)")
$btnSafeStop.Location = New-Object System.Drawing.Point(15, 144)   # 대분류 줄 신설로 +40 (v2.0.0)
$btnSafeStop.Size = New-Object System.Drawing.Size(210, 38)
$btnSafeStop.Enabled = $false
$btnSafeStop.Visible = $false
$form.Controls.Add($btnSafeStop)

$btnKill = New-Object System.Windows.Forms.Button
$btnKill.Text = '즉시 중지(F10)'
$btnKill.Location = New-Object System.Drawing.Point(231, 144)   # 대분류 줄 신설로 +40 (v2.0.0)
$btnKill.Size = New-Object System.Drawing.Size(150, 38)
$btnKill.Enabled = $false
$btnKill.Visible = $false
$form.Controls.Add($btnKill)

# 선택한 콘텐츠에 맞는 사용 설명서 팝업 (어비스 설명서 / 던전 설명서 - 카테고리에 따라 자동 전환)
$btnManual = New-Object System.Windows.Forms.Button
$btnManual.Text = '어비스 설명서'
$btnManual.Location = New-Object System.Drawing.Point(413, 144)   # 대분류 줄 신설로 +40 (v2.0.0)
$btnManual.Size = New-Object System.Drawing.Size(116, 38)
$form.Controls.Add($btnManual)

$btnManual.Add_Click({
    # 생활 대분류: 숨겨진 전투 라디오 상태보다 mainCategory 를 먼저 검사 (리뷰 조건 G)
    if ($script:mainCategory -eq 'life') {
      # v2.0.0 에서 채집 8종이 실제로 배포됐는데 이 안내만 '준비 중'으로 남아 있었습니다
      # (2026-08-10 10차 점검). 사용자가 기능을 안 쓰거나 사용법을 못 찾게 만드는 문구입니다.
      $lifeManualText = "채집 자동화 사용법`n`n" +
      "[지원 범위]`n" +
      " - 채집 8종: 일상 채집 / 나무 베기 / 광석 캐기 / 약초 채집 / 양털 깎기 /`n" +
      "   추수 / 호미질 / 곤충 채집`n" +
      " - 낚시와 가공은 아직 지원하지 않습니다 (고르면 시작 전에 안내로 막습니다)`n`n" +
      "[사용법]`n" +
      " 1. 대분류에서 [생활]을 고릅니다.`n" +
      " 2. 채집 스킬과 대상을 고릅니다 (좌우 화살표로 넘김).`n" +
      " 3. 캐릭터는 아무 데나 서 있어도 됩니다 - 매크로가 '가까운 위치 찾기'로`n" +
      "    퀘스트를 만들고 자동 이동까지 맡깁니다.`n" +
      " 4. [시작]을 누릅니다.`n`n" +
      "[한 사이클 흐름]`n" +
      " 퀘스트 확인 → C(내 정보) → 생활 스킬 → 대상 선택 → 가까운 위치 찾기`n" +
      " → 자동 이동 → 채집 → 퀘스트 소멸 확인 = 1회 완료`n`n" +
      "[설정]`n" +
      " - 채집 대기: 한 대상을 채집하는 데 기다릴 시간. 권장 1200초.`n" +
      "   젖소·광맥·뾰족한 나무처럼 이동이 먼 대상은 900초로는 모자랍니다.`n" +
      " - 진행 없음 한도: 수량이 늘지 않는 채로 견디는 시간입니다.`n" +
      "   총 시간 제한이 아니므로, 먼 대상에서 멈추면 이 값을 늘리면 됩니다.`n`n" +
      "[커스텀 반복]`n" +
      " 채집 스킬을 섞어 리스트를 짜고 항목마다 반복 횟수를 정할 수 있습니다.`n" +
      " 진행 위치는 저장되어 다시 켜도 이어집니다.`n`n" +
      "[알아 둘 점]`n" +
      " - 요구 스킬 레벨이 모자란 대상은 게임이 퀘스트를 만들어 주지 않아`n" +
      "   자동화로 통과할 수 없습니다 (실패 안내에 요구 레벨을 적어 둡니다).`n" +
      " - 가방 가득 / 도구 내구도 소진은 아직 감지하지 못합니다.`n" +
      "   그 경우 게임이 스스로 멈추고 매크로는 '진행 없음' 한도로 정지합니다.`n" +
      " - 다른 대상의 채집이 진행 중이면 방해하지 않고 최대 3분 기다립니다."
      [System.Windows.Forms.MessageBox]::Show($lifeManualText, '생활 설명서',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
      return
    }
    # 기타(고양이 상인) 설명서 (2026-08-15)
    if ($script:mainCategory -eq 'etc') {
      $etcManualText = "냥코인 뽑기 사용법`n`n" +
      "[동작]`n" +
      " - 고양이 상인의 물음표 카드를 골드로 구매해 정체를 공개합니다.`n" +
      " - 카드에서 '도둑 고양이'가 나오면 현상금(냥코인)을 받습니다.`n" +
      " - 가격표가 다 사라지면 자동으로 [다시 뽑기]를 눌러 새 판을 엽니다.`n" +
      " - 우상단 냥코인 잔량이 '목표 냥코인' 이상이 되면 스스로 멈춥니다.`n`n" +
      "[사용법]`n" +
      " 1. 게임에서 고양이 상인의 '뽑기' 화면을 엽니다.`n" +
      " 2. 목표 냥코인을 정합니다.`n" +
      " 3. (선택) '최대 사용 골드'를 켜면 그만큼 쓴 뒤 멈춥니다.`n" +
      " 4. [시작]을 누릅니다.`n`n" +
      "[주의]`n" +
      " - 카드 구매에 골드가 실제로 소모됩니다.`n" +
      " - 냥코인은 확률로 나오므로 목표가 크면 골드가 많이 들 수 있습니다.`n" +
      "   '최대 사용 골드' 옵션을 켜 두는 것을 권장합니다."
      [System.Windows.Forms.MessageBox]::Show($etcManualText, '기타 설명서',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
      return
    }
    # 모든 설명서 공통 머리말 (콘텐츠와 무관하게 동일)
    $manualCommon = "이 매크로는 게임 화면을 캡처해 글자를 읽는(OCR) 방식으로 동작합니다.`n" +
    "화면 비율/크기가 기준과 다르면 OCR 인식이 어긋나 오류가 발생할 수 있으니,`n" +
    "게임을 16:9 비율의 창 모드로 실행해 주세요.`n`n" +
    "[매크로 필수]`n" +
    " - OCR 언어 필요: 한국어(ko), 영어(en-US)`n" +
    " - OCR이 없으면 최초 [시작] 시 자동 설치합니다`n" +
    "   (영어는 백그라운드 설치, 10~15분 소요될 수 있음)`n" +
    " - 단축키: F9 = 시작 / 안전 중지, F10 = 즉시 중지`n" +
    "   (게임 화면에서도 동작합니다)`n`n"
    if ($rbCatHunting.Checked) {
      $manualText = $manualCommon +
      "[사냥터 자동화 사용법]`n" +
      " 1) 게임을 창 모드로 변경합니다.`n" +
      " 2) 원하는 사냥터의 석상을 클릭하여 사냥터 구역 선택 화면을 열어둡니다.`n" +
      " 3) [시작] 버튼을 클릭 후 마우스를 잠시 움직이지 마세요."
      [System.Windows.Forms.MessageBox]::Show($manualText, '사냥터 설명서',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
      return
    }
    if ($rbCatDungeon.Checked) {
      $manualText = $manualCommon +
      "[던전 자동화 사용법]`n" +
      " 1) 게임을 창 모드로 변경합니다.`n" +
      " 2) 원하는 던전의 석상을 클릭하여 던전 구역 선택 화면을 열어둡니다.`n" +
      " 3) [시작] 버튼을 클릭 후 마우스를 잠시 움직이지 마세요.`n`n" +
      "[커스텀 반복]`n" +
      " - 반복에서 '커스텀 반복'을 선택하면 리스트에 추가한 항목(난이도+구역+은동전)을`n" +
      "   위에서부터 순서대로 1판씩 실행합니다 (같은 항목을 여러 번 추가하면 그만큼 반복).`n" +
      " - 시작 시 열어 둔 던전 하나에서만 동작합니다 (리스트에 던전 구분 없음).`n" +
      " - 1차 버전은 매칭 설정과 무관하게 '우연한 만남'으로 진행합니다.`n" +
      " - 은동전 항목은 실제로 은동전이 소모되니 잔량을 확인해 주세요."
      [System.Windows.Forms.MessageBox]::Show($manualText, '던전 설명서',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    } elseif ($rbCatDeep.Checked) {
      $manualText = $manualCommon +
      "[심층던전 자동화 사용법]`n" +
      " 1) 게임을 창 모드로 변경합니다.`n" +
      " 2) 원하는 심층던전의 석상을 클릭하여 구역 선택 화면을 열어둡니다.`n" +
      " 3) [시작] 버튼을 클릭 후 마우스를 잠시 움직이지 마세요.`n`n" +
      "[던전과 다른 점]`n" +
      " - 입장 재화가 마족공물입니다 (소탕: 어려움 1개 / 매우 어려움 2개, 더블 루팅 없음).`n" +
      " - 난이도는 어려움만 있고, 주마다 심층던전 1곳에만 '매우 어려움'이 열립니다.`n" +
      " - '매우 어려움'을 고르면 이번 주 매우 어려움 던전의 화면을 열어 두세요.`n" +
      "   그 구역을 자동 채택해 반복합니다 (구역 설정 무시).`n`n" +
      "[커스텀 반복]`n" +
      " - 리스트에 추가한 항목(구역+마족공물)을 위에서부터 순서대로 1판씩 실행합니다.`n" +
      " - 시작 시 열어 둔 심층던전 하나에서만 동작하며 난이도는 어려움 고정입니다.`n" +
      " - 마족공물 항목은 실제로 공물이 소모되니 잔량을 확인해 주세요."
      [System.Windows.Forms.MessageBox]::Show($manualText, '심층던전 설명서',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    } else {
      $manualText = $manualCommon +
      "[어비스 사용법]`n" +
      " 1) 게임을 창 모드로 변경합니다.`n" +
      " 2) [시작] 버튼을 클릭해주세요.`n" +
      "    - 어비스 던전 선택 화면에서 [시작] 시 가장 안정적`n" +
      " 3) 마우스를 잠시 움직이지 마세요.`n`n" +
      "※ 매칭 '파티(파티장)': 파티를 먼저 짠 상태에서 시작하세요.`n" +
      "   입장하기 후 파티원 전원이 준비되면 자동 입장됩니다.`n" +
      "   (인원이 부족해도 채우지 않고 확인 팝업을 넘겨 그대로 도전합니다)`n" +
      "※ 매칭 '파티(파티원)': 파티를 짠 상태로 캐릭터를 필드에 두고 시작하세요.`n" +
      "   파티장이 입장을 시작하면 자동으로 '준비 완료'를 누르고 따라갑니다.`n" +
      "   (메뉴 이동 없이 대기 → 입장 → 클리어 → 나가기만 반복)"
      [System.Windows.Forms.MessageBox]::Show($manualText, '어비스 설명서',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
  })

# --- 콘텐츠 선택 (종류: 어비스/던전/심층던전) ---
$grpContent = New-Object System.Windows.Forms.GroupBox
$grpContent.Text = '콘텐츠 선택'
$grpContent.Location = New-Object System.Drawing.Point(15, 190)   # 대분류 줄 신설로 +40 (v2.0.0)
$grpContent.Size = New-Object System.Drawing.Size(514, 52)
$form.Controls.Add($grpContent)

# --- 콘텐츠 상세 설정 (입장 방식 / 난이도 / 세부 던전) ---
$grpContentDetail = New-Object System.Windows.Forms.GroupBox
$grpContentDetail.Text = '콘텐츠 상세 설정'
$grpContentDetail.Location = New-Object System.Drawing.Point(15, 250)   # 대분류 줄 신설로 +40 (v2.0.0. 탭 이하 배치는 Bottom 기준 자동)
$grpContentDetail.Size = New-Object System.Drawing.Size(514, 122)
$form.Controls.Add($grpContentDetail)

# 1줄: 콘텐츠 종류 (라디오 그룹 분리를 위해 Panel 로 감쌈)
$pnlCategory = New-Object System.Windows.Forms.Panel
$pnlCategory.Location = New-Object System.Drawing.Point(15, 20)
$pnlCategory.Size = New-Object System.Drawing.Size(524, 26)
$grpContent.Controls.Add($pnlCategory)

$rbCatAbyss = New-Object System.Windows.Forms.RadioButton
$rbCatAbyss.Text = '어비스'
$rbCatAbyss.Location = New-Object System.Drawing.Point(0, 2)
$rbCatAbyss.Size = New-Object System.Drawing.Size(80, 22)
$rbCatAbyss.Checked = $true
$pnlCategory.Controls.Add($rbCatAbyss)

$rbCatDungeon = New-Object System.Windows.Forms.RadioButton
$rbCatDungeon.Text = '던전'
$rbCatDungeon.Location = New-Object System.Drawing.Point(100, 2)
$rbCatDungeon.Size = New-Object System.Drawing.Size(70, 22)
$pnlCategory.Controls.Add($rbCatDungeon)

$rbCatDeep = New-Object System.Windows.Forms.RadioButton
$rbCatDeep.Text = '심층던전'
$rbCatDeep.Location = New-Object System.Drawing.Point(180, 2)
$rbCatDeep.Size = New-Object System.Drawing.Size(100, 22)
$pnlCategory.Controls.Add($rbCatDeep)

$rbCatHunting = New-Object System.Windows.Forms.RadioButton
$rbCatHunting.Text = '사냥터'
$rbCatHunting.Location = New-Object System.Drawing.Point(290, 2)
$rbCatHunting.Size = New-Object System.Drawing.Size(130, 22)
$pnlCategory.Controls.Add($rbCatHunting)

# 상세 설정 1줄: 입장 방식 (혼자하기 / 함께하기)
$pnlMode = New-Object System.Windows.Forms.Panel
$pnlMode.Location = New-Object System.Drawing.Point(15, 20)
$pnlMode.Size = New-Object System.Drawing.Size(524, 26)
$grpContentDetail.Controls.Add($pnlMode)

$rbModeSolo = New-Object System.Windows.Forms.RadioButton
$rbModeSolo.Text = '혼자하기'
$rbModeSolo.Location = New-Object System.Drawing.Point(0, 2)
$rbModeSolo.Size = New-Object System.Drawing.Size(90, 22)
$rbModeSolo.Checked = $true
$pnlMode.Controls.Add($rbModeSolo)

$rbModeParty = New-Object System.Windows.Forms.RadioButton
$rbModeParty.Text = '함께하기'
$rbModeParty.Location = New-Object System.Drawing.Point(140, 2)
$rbModeParty.Size = New-Object System.Drawing.Size(200, 22)
$pnlMode.Controls.Add($rbModeParty)

# 상세 설정 2줄: 난이도 선택 (드롭다운). 워커가 상세 화면에서 같은 이름의 난이도 버튼을
#      OCR로 찾아 클릭합니다. '게임 그대로'는 난이도를 건드리지 않고 현재 선택된 상태로 입장.
#      새 난이도가 추가되면 아래 목록에 이름만 추가하면 됩니다 (워커는 글자 탐색이라 수정 불필요).
$pnlDifficulty = New-Object System.Windows.Forms.Panel
$pnlDifficulty.Location = New-Object System.Drawing.Point(15, 52)
$pnlDifficulty.Size = New-Object System.Drawing.Size(524, 26)
$grpContentDetail.Controls.Add($pnlDifficulty)

$lblDifficulty = New-Object System.Windows.Forms.Label
$lblDifficulty.Text = '난이도:'
$lblDifficulty.Location = New-Object System.Drawing.Point(0, 5)
$lblDifficulty.Size = New-Object System.Drawing.Size(52, 20)
$pnlDifficulty.Controls.Add($lblDifficulty)

$cboDifficulty = New-Object System.Windows.Forms.ComboBox
$cboDifficulty.Location = New-Object System.Drawing.Point(58, 1)
$cboDifficulty.Size = New-Object System.Drawing.Size(150, 24)
$cboDifficulty.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
# 난이도 목록은 입장 방식에 따라 달라집니다: 지옥 난이도는 함께하기(파티) 전용이라
# 혼자하기에서는 '매우 어려움'까지만 선택할 수 있습니다. 방식 전환 시 목록을 갈아끼우고,
# 선택 중이던 난이도가 새 목록에 없으면 '게임 그대로'로 되돌립니다.
$updateDifficultyItems = {
  $currentDifficulty = [string]$cboDifficulty.SelectedItem
  $cboDifficulty.Items.Clear()
  [void]$cboDifficulty.Items.Add('게임 그대로')
  foreach ($difficultyName in @('입문', '어려움', '매우 어려움')) { [void]$cboDifficulty.Items.Add($difficultyName) }
  if ($rbModeParty.Checked) {
    for ($hellLevel = 1; $hellLevel -le 10; $hellLevel++) { [void]$cboDifficulty.Items.Add("지옥$hellLevel") }
  }
  if ($currentDifficulty -and $cboDifficulty.Items.Contains($currentDifficulty)) {
    $cboDifficulty.SelectedItem = $currentDifficulty
  } else {
    $cboDifficulty.SelectedIndex = 0
  }
}
& $updateDifficultyItems
$pnlDifficulty.Controls.Add($cboDifficulty)

$rbModeSolo.Add_CheckedChanged({
    & $updateDifficultyItems
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })
$rbModeParty.Add_CheckedChanged({
    & $updateDifficultyItems
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })

# 3줄: 세부 던전 목록 (1줄에서 고른 종류에 따라 내용이 바뀌는 자리.
#      지금은 어비스만 있으므로 어비스 던전 3종을 표시. 추후 던전/심층던전이
#      개발되면 카테고리 CheckedChanged 에서 이 패널의 항목을 갈아끼우면 됨)
$pnlDungeon = New-Object System.Windows.Forms.Panel
$pnlDungeon.Location = New-Object System.Drawing.Point(15, 84)
$pnlDungeon.Size = New-Object System.Drawing.Size(524, 26)
$grpContentDetail.Controls.Add($pnlDungeon)

$rbDgHeosang = New-Object System.Windows.Forms.RadioButton
$rbDgHeosang.Text = '허상의 정박지'
$rbDgHeosang.Location = New-Object System.Drawing.Point(0, 2)
$rbDgHeosang.Size = New-Object System.Drawing.Size(120, 22)
$rbDgHeosang.Checked = $true
$pnlDungeon.Controls.Add($rbDgHeosang)

$rbDgMadness = New-Object System.Windows.Forms.RadioButton
$rbDgMadness.Text = '광기의 동굴'
$rbDgMadness.Location = New-Object System.Drawing.Point(140, 2)
$rbDgMadness.Size = New-Object System.Drawing.Size(185, 22)
$pnlDungeon.Controls.Add($rbDgMadness)

$rbDgScattered = New-Object System.Windows.Forms.RadioButton
$rbDgScattered.Text = '흩어진 물길'
$rbDgScattered.Location = New-Object System.Drawing.Point(340, 2)
$rbDgScattered.Size = New-Object System.Drawing.Size(155, 22)
$pnlDungeon.Controls.Add($rbDgScattered)

# 함께하기 전용 매칭 방식 줄 (우연한 만남 / 파티 찾기). 함께하기를 선택하면 난이도
# 아래에 나타나고, 세부 던전 목록이 한 줄 아래로 내려갑니다 (배치는 updateCategoryPanels).
$pnlAbyssMatching = New-Object System.Windows.Forms.Panel
$pnlAbyssMatching.Location = New-Object System.Drawing.Point(15, 84)
$pnlAbyssMatching.Size = New-Object System.Drawing.Size(524, 26)
$pnlAbyssMatching.Visible = $false
$grpContentDetail.Controls.Add($pnlAbyssMatching)

$lblAbyssMatching = New-Object System.Windows.Forms.Label
$lblAbyssMatching.Text = '매칭:'
$lblAbyssMatching.Location = New-Object System.Drawing.Point(0, 5)
$lblAbyssMatching.Size = New-Object System.Drawing.Size(52, 20)
$pnlAbyssMatching.Controls.Add($lblAbyssMatching)

$rbAbyssChance = New-Object System.Windows.Forms.RadioButton
$rbAbyssChance.Text = '우연한 만남'
$rbAbyssChance.Location = New-Object System.Drawing.Point(58, 2)
$rbAbyssChance.Size = New-Object System.Drawing.Size(110, 22)
$rbAbyssChance.Checked = $true
$pnlAbyssMatching.Controls.Add($rbAbyssChance)

$rbAbyssFindParty = New-Object System.Windows.Forms.RadioButton
$rbAbyssFindParty.Text = '파티 찾기'
$rbAbyssFindParty.Location = New-Object System.Drawing.Point(190, 2)
$rbAbyssFindParty.Size = New-Object System.Drawing.Size(85, 22)
$pnlAbyssMatching.Controls.Add($rbAbyssFindParty)

# 직접 짠 파티로 도는 모드 (파티장 = 입장하기 클릭 주도 / 파티원 = 준비·따라가기 전담)
$rbAbyssPartyLead = New-Object System.Windows.Forms.RadioButton
$rbAbyssPartyLead.Text = '파티(파티장)'
$rbAbyssPartyLead.Location = New-Object System.Drawing.Point(280, 2)
$rbAbyssPartyLead.Size = New-Object System.Drawing.Size(100, 22)
$pnlAbyssMatching.Controls.Add($rbAbyssPartyLead)

$rbAbyssPartyMember = New-Object System.Windows.Forms.RadioButton
$rbAbyssPartyMember.Text = '파티(파티원)'
$rbAbyssPartyMember.Location = New-Object System.Drawing.Point(385, 2)
$rbAbyssPartyMember.Size = New-Object System.Drawing.Size(110, 22)
$pnlAbyssMatching.Controls.Add($rbAbyssPartyMember)

# ============================================================
#  '던전' 카테고리 전용 상세 설정 (콘텐츠 선택에서 '던전'을 고르면 아래 패널들이 표시되고
#  어비스용 패널은 숨겨집니다. 전체 자동화 구현: 선택 → 옵션 → 입장 → 클리어 → 다시 하기 반복)
# ============================================================
# 1줄: 난이도 (일반 / 어려움)
$pnlNdDifficulty = New-Object System.Windows.Forms.Panel
$pnlNdDifficulty.Location = New-Object System.Drawing.Point(15, 20)
$pnlNdDifficulty.Size = New-Object System.Drawing.Size(524, 26)
$pnlNdDifficulty.Visible = $false
$grpContentDetail.Controls.Add($pnlNdDifficulty)

$lblNdDifficulty = New-Object System.Windows.Forms.Label
$lblNdDifficulty.Text = '난이도:'
$lblNdDifficulty.Location = New-Object System.Drawing.Point(0, 5)
$lblNdDifficulty.Size = New-Object System.Drawing.Size(52, 20)
$pnlNdDifficulty.Controls.Add($lblNdDifficulty)

$rbNdNormal = New-Object System.Windows.Forms.RadioButton
$rbNdNormal.Text = '일반'
$rbNdNormal.Location = New-Object System.Drawing.Point(58, 2)
$rbNdNormal.Size = New-Object System.Drawing.Size(60, 22)
$rbNdNormal.Checked = $true
$pnlNdDifficulty.Controls.Add($rbNdNormal)

$rbNdHard = New-Object System.Windows.Forms.RadioButton
$rbNdHard.Text = '어려움'
$rbNdHard.Location = New-Object System.Drawing.Point(128, 2)
$rbNdHard.Size = New-Object System.Drawing.Size(75, 22)
$pnlNdDifficulty.Controls.Add($rbNdHard)

# 매우 어려움은 일부 던전에만 있습니다 (2026-07-24 실측: 10던전 중 8곳 - 룬다·피오드 제외).
# 없는 던전에서 선택하면 글자 탐색 실패 → 선택 확정 검증이 막아 잘못 입장하지 않습니다.
$rbNdVeryHard = New-Object System.Windows.Forms.RadioButton
$rbNdVeryHard.Text = '매우 어려움'
$rbNdVeryHard.Location = New-Object System.Drawing.Point(213, 2)
$rbNdVeryHard.Size = New-Object System.Drawing.Size(105, 22)
$pnlNdDifficulty.Controls.Add($rbNdVeryHard)

# 2줄: 스테이지 (1-1 ~ 2-3 드롭다운. 새 스테이지가 나오면 목록에 추가)
$pnlNdStage = New-Object System.Windows.Forms.Panel
$pnlNdStage.Location = New-Object System.Drawing.Point(15, 52)
$pnlNdStage.Size = New-Object System.Drawing.Size(524, 26)
$pnlNdStage.Visible = $false
$grpContentDetail.Controls.Add($pnlNdStage)

$lblNdStage = New-Object System.Windows.Forms.Label
$lblNdStage.Text = '구역:'
$lblNdStage.Location = New-Object System.Drawing.Point(0, 5)
$lblNdStage.Size = New-Object System.Drawing.Size(62, 20)
$pnlNdStage.Controls.Add($lblNdStage)

$cboNdStage = New-Object System.Windows.Forms.ComboBox
$cboNdStage.Location = New-Object System.Drawing.Point(68, 1)
$cboNdStage.Size = New-Object System.Drawing.Size(100, 24)
$cboNdStage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
foreach ($ndChapter in 1..2) {
  foreach ($ndStep in 1..3) { [void]$cboNdStage.Items.Add("$ndChapter-$ndStep") }
}
$cboNdStage.SelectedIndex = 0
$pnlNdStage.Controls.Add($cboNdStage)

# 3줄: 은동전 사용 (체크하면 바로 옆에 더블 루팅 선택이 나타남)
$pnlNdCoin = New-Object System.Windows.Forms.Panel
$pnlNdCoin.Location = New-Object System.Drawing.Point(15, 84)
$pnlNdCoin.Size = New-Object System.Drawing.Size(524, 26)
$pnlNdCoin.Visible = $false
$grpContentDetail.Controls.Add($pnlNdCoin)

$chkNdCoin = New-Object System.Windows.Forms.CheckBox
$chkNdCoin.Text = '은동전 사용'
$chkNdCoin.Location = New-Object System.Drawing.Point(0, 2)
$chkNdCoin.Size = New-Object System.Drawing.Size(105, 22)
$pnlNdCoin.Controls.Add($chkNdCoin)

$chkNdDoubleLoot = New-Object System.Windows.Forms.CheckBox
$chkNdDoubleLoot.Text = '더블 루팅'
$chkNdDoubleLoot.Location = New-Object System.Drawing.Point(125, 2)
$chkNdDoubleLoot.Size = New-Object System.Drawing.Size(95, 22)
$chkNdDoubleLoot.Visible = $false
$pnlNdCoin.Controls.Add($chkNdDoubleLoot)

# 비커스텀 던전도 커스텀 항목과 같은 2단계 소진 대응 라디오를 사용합니다.
# 저장 키(continueWithoutCoin/continueSweepOnly)는 구버전 config 호환을 위해 그대로 유지합니다.
$pnlNdExhaust = New-Object System.Windows.Forms.Panel
$pnlNdExhaust.Location = New-Object System.Drawing.Point(15, 116)
$pnlNdExhaust.Size = New-Object System.Drawing.Size(524, 26)
$pnlNdExhaust.Visible = $false
$grpContentDetail.Controls.Add($pnlNdExhaust)

$lblNdExhaust = New-Object System.Windows.Forms.Label
$lblNdExhaust.Text = '동전 소진 시(잔량 10 미만):'
$lblNdExhaust.Location = New-Object System.Drawing.Point(0, 5)
$lblNdExhaust.Size = New-Object System.Drawing.Size(175, 20)
$pnlNdExhaust.Controls.Add($lblNdExhaust)

$rbNdExhaustStop = New-Object System.Windows.Forms.RadioButton
$rbNdExhaustStop.Text = '멈춤'
$rbNdExhaustStop.Location = New-Object System.Drawing.Point(180, 2)
$rbNdExhaustStop.Size = New-Object System.Drawing.Size(60, 22)
$rbNdExhaustStop.Checked = $true
$pnlNdExhaust.Controls.Add($rbNdExhaustStop)

$rbNdExhaustGo = New-Object System.Windows.Forms.RadioButton
$rbNdExhaustGo.Text = '미사용으로 진행'
$rbNdExhaustGo.Location = New-Object System.Drawing.Point(245, 2)
$rbNdExhaustGo.Size = New-Object System.Drawing.Size(135, 22)
$pnlNdExhaust.Controls.Add($rbNdExhaustGo)

$pnlNdNoDouble = New-Object System.Windows.Forms.Panel
$pnlNdNoDouble.Location = New-Object System.Drawing.Point(15, 142)
$pnlNdNoDouble.Size = New-Object System.Drawing.Size(524, 26)
$pnlNdNoDouble.Visible = $false
$grpContentDetail.Controls.Add($pnlNdNoDouble)

$lblNdNoDouble = New-Object System.Windows.Forms.Label
$lblNdNoDouble.Text = '더블 루팅 불가 시(잔량 10~19):'
$lblNdNoDouble.Location = New-Object System.Drawing.Point(0, 5)
$lblNdNoDouble.Size = New-Object System.Drawing.Size(195, 20)
$pnlNdNoDouble.Controls.Add($lblNdNoDouble)

$rbNdNoDoubleStop = New-Object System.Windows.Forms.RadioButton
$rbNdNoDoubleStop.Text = '멈춤'
$rbNdNoDoubleStop.Location = New-Object System.Drawing.Point(200, 2)
$rbNdNoDoubleStop.Size = New-Object System.Drawing.Size(60, 22)
$rbNdNoDoubleStop.Checked = $true
$pnlNdNoDouble.Controls.Add($rbNdNoDoubleStop)

$rbNdNoDoubleSweep = New-Object System.Windows.Forms.RadioButton
$rbNdNoDoubleSweep.Text = '소탕만 진행'
$rbNdNoDoubleSweep.Location = New-Object System.Drawing.Point(265, 2)
$rbNdNoDoubleSweep.Size = New-Object System.Drawing.Size(110, 22)
$pnlNdNoDouble.Controls.Add($rbNdNoDoubleSweep)

# 더블 루팅을 해제하면 해당하지 않는 두 번째 단계는 기본값(멈춤)으로 되돌립니다.
$chkNdDoubleLoot.Add_CheckedChanged({
    if (-not $chkNdDoubleLoot.Checked) { $rbNdNoDoubleStop.Checked = $true }
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })

# 은동전 사용을 해제하면 숨겨지는 소진 대응도 기본값(멈춤)으로 되돌립니다.
$chkNdCoin.Add_CheckedChanged({
    $chkNdDoubleLoot.Visible = $chkNdCoin.Checked
    if (-not $chkNdCoin.Checked) {
      $chkNdDoubleLoot.Checked = $false
      $rbNdExhaustStop.Checked = $true
      $rbNdNoDoubleStop.Checked = $true
    }
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })

# ============================================================
#  '심층던전' 카테고리 전용 상세 설정 (던전과 동일 구조 - 재화만 마족공물 1/2개,
#  난이도는 어려움 고정 + 주간 매우 어려움(이번 주 단일 구역) 선택형. 2026-07-27 실측 스펙)
# ============================================================
# 1줄: 난이도 (어려움 / 주간 매우 어려움)
$pnlDdDifficulty = New-Object System.Windows.Forms.Panel
$pnlDdDifficulty.Location = New-Object System.Drawing.Point(15, 20)
$pnlDdDifficulty.Size = New-Object System.Drawing.Size(524, 26)
$pnlDdDifficulty.Visible = $false
$grpContentDetail.Controls.Add($pnlDdDifficulty)

$lblDdDifficulty = New-Object System.Windows.Forms.Label
$lblDdDifficulty.Text = '난이도:'
$lblDdDifficulty.Location = New-Object System.Drawing.Point(0, 5)
$lblDdDifficulty.Size = New-Object System.Drawing.Size(52, 20)
$pnlDdDifficulty.Controls.Add($lblDdDifficulty)

$rbDdHard = New-Object System.Windows.Forms.RadioButton
$rbDdHard.Text = '어려움'
$rbDdHard.Location = New-Object System.Drawing.Point(58, 2)
$rbDdHard.Size = New-Object System.Drawing.Size(75, 22)
$rbDdHard.Checked = $true
$pnlDdDifficulty.Controls.Add($rbDdHard)

# 주간 매우 어려움: 주마다 심층던전 1곳에만 열리는 단일 구역 - 이번 주 던전의 '매우 어려움'
# 화면을 열어 두면 그 구역을 자동 채택해 반복합니다 (구역 설정 무시)
$rbDdWeeklyVeryHard = New-Object System.Windows.Forms.RadioButton
$rbDdWeeklyVeryHard.Text = '매우 어려움'
$rbDdWeeklyVeryHard.Location = New-Object System.Drawing.Point(143, 2)
$rbDdWeeklyVeryHard.Size = New-Object System.Drawing.Size(110, 22)
$pnlDdDifficulty.Controls.Add($rbDdWeeklyVeryHard)

# 2줄: 구역 (표시는 D1-1 형식, 저장은 내부 표현 1-1)
$pnlDdStage = New-Object System.Windows.Forms.Panel
$pnlDdStage.Location = New-Object System.Drawing.Point(15, 52)
$pnlDdStage.Size = New-Object System.Drawing.Size(524, 26)
$pnlDdStage.Visible = $false
$grpContentDetail.Controls.Add($pnlDdStage)

$lblDdStage = New-Object System.Windows.Forms.Label
$lblDdStage.Text = '구역:'
$lblDdStage.Location = New-Object System.Drawing.Point(0, 5)
$lblDdStage.Size = New-Object System.Drawing.Size(52, 20)
$pnlDdStage.Controls.Add($lblDdStage)

$cboDdStage = New-Object System.Windows.Forms.ComboBox
$cboDdStage.Location = New-Object System.Drawing.Point(68, 1)
$cboDdStage.Size = New-Object System.Drawing.Size(100, 24)
$cboDdStage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
foreach ($ddChapter in 1..2) {
  foreach ($ddStep in 1..3) { [void]$cboDdStage.Items.Add("D$ddChapter-$ddStep") }
}
$cboDdStage.SelectedIndex = 0
$pnlDdStage.Controls.Add($cboDdStage)

# 3줄: 마족공물 사용 (소탕 카드 - 어려움 1개/매우 어려움 2개 소모. 해제 시 무료 입장)
$pnlDdTribute = New-Object System.Windows.Forms.Panel
$pnlDdTribute.Location = New-Object System.Drawing.Point(15, 84)
$pnlDdTribute.Size = New-Object System.Drawing.Size(524, 26)
$pnlDdTribute.Visible = $false
$grpContentDetail.Controls.Add($pnlDdTribute)

$chkDdTribute = New-Object System.Windows.Forms.CheckBox
$chkDdTribute.Text = '마족공물 사용 (소탕)'
$chkDdTribute.Location = New-Object System.Drawing.Point(0, 2)
$chkDdTribute.Size = New-Object System.Drawing.Size(160, 22)
$pnlDdTribute.Controls.Add($chkDdTribute)

# 4줄: 공물 소진 대응 (던전의 은동전 소진 대응과 동일 의미)
$pnlDdExhaust = New-Object System.Windows.Forms.Panel
$pnlDdExhaust.Location = New-Object System.Drawing.Point(15, 116)
$pnlDdExhaust.Size = New-Object System.Drawing.Size(524, 26)
$pnlDdExhaust.Visible = $false
$grpContentDetail.Controls.Add($pnlDdExhaust)

$lblDdExhaust = New-Object System.Windows.Forms.Label
$lblDdExhaust.Text = '공물 소진 시:'
$lblDdExhaust.Location = New-Object System.Drawing.Point(0, 5)
$lblDdExhaust.Size = New-Object System.Drawing.Size(100, 20)
$pnlDdExhaust.Controls.Add($lblDdExhaust)

$rbDdExhaustStop = New-Object System.Windows.Forms.RadioButton
$rbDdExhaustStop.Text = '멈춤'
$rbDdExhaustStop.Location = New-Object System.Drawing.Point(105, 2)
$rbDdExhaustStop.Size = New-Object System.Drawing.Size(60, 22)
$rbDdExhaustStop.Checked = $true
$pnlDdExhaust.Controls.Add($rbDdExhaustStop)

$rbDdExhaustGo = New-Object System.Windows.Forms.RadioButton
$rbDdExhaustGo.Text = '미사용으로 진행'
$rbDdExhaustGo.Location = New-Object System.Drawing.Point(170, 2)
$rbDdExhaustGo.Size = New-Object System.Drawing.Size(135, 22)
$pnlDdExhaust.Controls.Add($rbDdExhaustGo)

# 5줄: 매칭 (우연한 만남 / 파티 찾기 - 던전과 동일)
$pnlDdMatching = New-Object System.Windows.Forms.Panel
$pnlDdMatching.Location = New-Object System.Drawing.Point(15, 148)
$pnlDdMatching.Size = New-Object System.Drawing.Size(524, 26)
$pnlDdMatching.Visible = $false
$grpContentDetail.Controls.Add($pnlDdMatching)

$lblDdMatching = New-Object System.Windows.Forms.Label
$lblDdMatching.Text = '매칭:'
$lblDdMatching.Location = New-Object System.Drawing.Point(0, 5)
$lblDdMatching.Size = New-Object System.Drawing.Size(52, 20)
$pnlDdMatching.Controls.Add($lblDdMatching)

$rbDdChance = New-Object System.Windows.Forms.RadioButton
$rbDdChance.Text = '우연한 만남'
$rbDdChance.Location = New-Object System.Drawing.Point(58, 2)
$rbDdChance.Size = New-Object System.Drawing.Size(105, 22)
$rbDdChance.Checked = $true
$pnlDdMatching.Controls.Add($rbDdChance)

$rbDdFindParty = New-Object System.Windows.Forms.RadioButton
$rbDdFindParty.Text = '파티 찾기'
$rbDdFindParty.Location = New-Object System.Drawing.Point(173, 2)
$rbDdFindParty.Size = New-Object System.Drawing.Size(95, 22)
$pnlDdMatching.Controls.Add($rbDdFindParty)

# 주간 매우 어려움 선택 시 구역 콤보는 의미가 없어 비활성화합니다 (화면 기준 자동 채택)
$rbDdWeeklyVeryHard.Add_CheckedChanged({
    $cboDdStage.Enabled = -not $rbDdWeeklyVeryHard.Checked
  })

# ============================================================
#  '사냥터' 카테고리 전용 상세 설정 (특정 사냥터에 매이지 않는 범용 방식 -
#  사용자가 원하는 사냥터의 첫 화면을 열어 두면 그 사냥터로 동작합니다)
# ============================================================
# 1줄: 난이도 (일반 / 어려움)
$pnlHtDifficulty = New-Object System.Windows.Forms.Panel
$pnlHtDifficulty.Location = New-Object System.Drawing.Point(15, 20)
$pnlHtDifficulty.Size = New-Object System.Drawing.Size(524, 26)
$pnlHtDifficulty.Visible = $false
$grpContentDetail.Controls.Add($pnlHtDifficulty)

$lblHtDifficulty = New-Object System.Windows.Forms.Label
$lblHtDifficulty.Text = '난이도:'
$lblHtDifficulty.Location = New-Object System.Drawing.Point(0, 5)
$lblHtDifficulty.Size = New-Object System.Drawing.Size(52, 20)
$pnlHtDifficulty.Controls.Add($lblHtDifficulty)

$rbHtNormal = New-Object System.Windows.Forms.RadioButton
$rbHtNormal.Text = '일반'
$rbHtNormal.Location = New-Object System.Drawing.Point(58, 2)
$rbHtNormal.Size = New-Object System.Drawing.Size(60, 22)
$rbHtNormal.Checked = $true
$pnlHtDifficulty.Controls.Add($rbHtNormal)

$rbHtHard = New-Object System.Windows.Forms.RadioButton
$rbHtHard.Text = '어려움'
$rbHtHard.Location = New-Object System.Drawing.Point(128, 2)
$rbHtHard.Size = New-Object System.Drawing.Size(75, 22)
$pnlHtDifficulty.Controls.Add($rbHtHard)

# 매우 어려움은 일부 사냥터에만 있습니다. 없는 사냥터에서 선택하면
# 해당 글자를 찾지 못해 현재 선택된 난이도로 진행합니다(중단 없음).
$rbHtVeryHard = New-Object System.Windows.Forms.RadioButton
$rbHtVeryHard.Text = '매우 어려움'
$rbHtVeryHard.Location = New-Object System.Drawing.Point(213, 2)
$rbHtVeryHard.Size = New-Object System.Drawing.Size(105, 22)
$pnlHtDifficulty.Controls.Add($rbHtVeryHard)

# 2줄: 공물(은동전 10개) 사용 + 소진 대응
$pnlHtCoin = New-Object System.Windows.Forms.Panel
$pnlHtCoin.Location = New-Object System.Drawing.Point(15, 52)
$pnlHtCoin.Size = New-Object System.Drawing.Size(524, 26)
$pnlHtCoin.Visible = $false
$grpContentDetail.Controls.Add($pnlHtCoin)

$chkHtCoin = New-Object System.Windows.Forms.CheckBox
$chkHtCoin.Text = '은동전 사용'
$chkHtCoin.Location = New-Object System.Drawing.Point(0, 2)
$chkHtCoin.Size = New-Object System.Drawing.Size(105, 22)
$pnlHtCoin.Controls.Add($chkHtCoin)

$chkHtDoubleLoot = New-Object System.Windows.Forms.CheckBox
$chkHtDoubleLoot.Text = '더블 루팅'
$chkHtDoubleLoot.Location = New-Object System.Drawing.Point(125, 2)
$chkHtDoubleLoot.Size = New-Object System.Drawing.Size(95, 22)
$chkHtDoubleLoot.Visible = $false
$pnlHtCoin.Controls.Add($chkHtDoubleLoot)

# 사냥터 소진 대응 (사용자 결정 2026-07-18): '소진 시 미사용으로 계속'은 없습니다 -
# 은동전이 10개 미만이면 사냥터에서 나가서 자동화를 마칩니다. 단 '더블 루팅 불가 시
# 소탕만 계속'은 유지: 잔량 10~19개면 더블 루팅만 끄고 소탕(10개)으로 계속합니다.
$chkHtLootFallback = New-Object System.Windows.Forms.CheckBox
$chkHtLootFallback.Text = '더블 루팅 불가 시 소탕만 계속'
$chkHtLootFallback.Location = New-Object System.Drawing.Point(240, 2)
$chkHtLootFallback.Size = New-Object System.Drawing.Size(240, 22)
$chkHtLootFallback.Visible = $false
$chkHtLootFallback.Enabled = $false   # 더블 루팅을 켰을 때만 의미 있는 옵션이라 그때만 활성화
$pnlHtCoin.Controls.Add($chkHtLootFallback)

$chkHtDoubleLoot.Add_CheckedChanged({
    $chkHtLootFallback.Enabled = $chkHtDoubleLoot.Checked
    if (-not $chkHtDoubleLoot.Checked) { $chkHtLootFallback.Checked = $false }
  })

# 은동전 사용을 체크하면 더블 루팅/소탕만 계속이 나타나고, 해제하면 숨기면서 선택도 해제합니다
$chkHtCoin.Add_CheckedChanged({
    $chkHtDoubleLoot.Visible = $chkHtCoin.Checked
    $chkHtLootFallback.Visible = $chkHtCoin.Checked
    if (-not $chkHtCoin.Checked) {
      $chkHtDoubleLoot.Checked = $false
      $chkHtLootFallback.Checked = $false
    }
  })

# 3줄: 매칭 방식 (파티찾기 / 바로 입장)
$pnlHtParty = New-Object System.Windows.Forms.Panel
$pnlHtParty.Location = New-Object System.Drawing.Point(15, 84)
$pnlHtParty.Size = New-Object System.Drawing.Size(524, 26)
$pnlHtParty.Visible = $false
$grpContentDetail.Controls.Add($pnlHtParty)

$rbHtParty = New-Object System.Windows.Forms.RadioButton
$rbHtParty.Text = '파티찾기'
$rbHtParty.Location = New-Object System.Drawing.Point(0, 2)
$rbHtParty.Size = New-Object System.Drawing.Size(90, 22)
$rbHtParty.Checked = $true
$pnlHtParty.Controls.Add($rbHtParty)

$rbHtDirect = New-Object System.Windows.Forms.RadioButton
$rbHtDirect.Text = '바로 입장'
$rbHtDirect.Location = New-Object System.Drawing.Point(105, 2)
$rbHtDirect.Size = New-Object System.Drawing.Size(95, 22)
$pnlHtParty.Controls.Add($rbHtDirect)

# 4줄: 매칭 방식 (파티찾기 / 우연한 만남)
$pnlNdParty = New-Object System.Windows.Forms.Panel
$pnlNdParty.Location = New-Object System.Drawing.Point(15, 116)
$pnlNdParty.Size = New-Object System.Drawing.Size(524, 26)
$pnlNdParty.Visible = $false
$grpContentDetail.Controls.Add($pnlNdParty)

$rbNdChance = New-Object System.Windows.Forms.RadioButton
$rbNdChance.Text = '우연한 만남'
$rbNdChance.Location = New-Object System.Drawing.Point(0, 2)
$rbNdChance.Size = New-Object System.Drawing.Size(110, 22)
$rbNdChance.Checked = $true
$pnlNdParty.Controls.Add($rbNdChance)

$rbNdFindParty = New-Object System.Windows.Forms.RadioButton
$rbNdFindParty.Text = '파티찾기'
$rbNdFindParty.Location = New-Object System.Drawing.Point(125, 2)
$rbNdFindParty.Size = New-Object System.Drawing.Size(90, 22)
$pnlNdParty.Controls.Add($rbNdFindParty)

# ============================================================
#  '던전 + 커스텀 반복' 전용 리스트 빌더 (반복 그룹에서 '커스텀 반복'을 고르면 단일 모드
#  줄들 대신 아래 패널들이 표시됩니다. 리스트 편집은 즉시 config(customRepeat)에 저장)
# ============================================================
# 입력 줄: 난이도 + 스테이지 + 은동전 + 더블 루팅(은동전 체크 시만 표시).
# [추가] 버튼은 리스트 옆 버튼 열 최상단에 있습니다
$pnlCrInput = New-Object System.Windows.Forms.Panel
$pnlCrInput.Location = New-Object System.Drawing.Point(15, 20)
$pnlCrInput.Size = New-Object System.Drawing.Size(524, 26)
$pnlCrInput.Visible = $false
$grpContentDetail.Controls.Add($pnlCrInput)

$cboCrDifficulty = New-Object System.Windows.Forms.ComboBox
$cboCrDifficulty.Location = New-Object System.Drawing.Point(0, 1)
$cboCrDifficulty.Size = New-Object System.Drawing.Size(92, 24)   # '매우 어려움' 표시 폭 (2026-07-24)
$cboCrDifficulty.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
foreach ($crDifficultyName in @('일반', '어려움', '매우 어려움')) { [void]$cboCrDifficulty.Items.Add($crDifficultyName) }
$cboCrDifficulty.SelectedIndex = 0
$pnlCrInput.Controls.Add($cboCrDifficulty)

$cboCrStage = New-Object System.Windows.Forms.ComboBox
$cboCrStage.Location = New-Object System.Drawing.Point(102, 1)
$cboCrStage.Size = New-Object System.Drawing.Size(70, 24)
$cboCrStage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
foreach ($crChapter in 1..2) {
  foreach ($crStep in 1..3) { [void]$cboCrStage.Items.Add("$crChapter-$crStep") }
}
$cboCrStage.SelectedIndex = 0
$pnlCrInput.Controls.Add($cboCrStage)

$chkCrCoin = New-Object System.Windows.Forms.CheckBox
$chkCrCoin.Text = '은동전'
$chkCrCoin.Location = New-Object System.Drawing.Point(182, 2)
$chkCrCoin.Size = New-Object System.Drawing.Size(70, 22)
$pnlCrInput.Controls.Add($chkCrCoin)

$chkCrDouble = New-Object System.Windows.Forms.CheckBox
$chkCrDouble.Text = '더블 루팅'
$chkCrDouble.Location = New-Object System.Drawing.Point(257, 2)
$chkCrDouble.Size = New-Object System.Drawing.Size(90, 22)
$chkCrDouble.Visible = $false   # 은동전 체크 시에만 표시 (단일 모드 chkNdCoin 과 동일한 동작)
$pnlCrInput.Controls.Add($chkCrDouble)

# 입력 줄 아래 라디오 줄 2개: '다음에 [추가]할 항목'의 소진/더블 불가 대응 속성입니다.
# 즉시 저장 대상이 아니라 [추가]로 리스트에 들어갈 때 항목별 속성으로 기록됩니다.
# 기본값 = 멈춤. 소진 줄은 은동전 체크 시, 더블 불가 줄은 더블 루팅 체크 시에만 표시
# (표시/배치는 updateCategoryPanels 가 제어 - 소진 줄이 위, 더블 불가 줄이 아래)
$pnlCrExhaust = New-Object System.Windows.Forms.Panel
$pnlCrExhaust.Location = New-Object System.Drawing.Point(15, 50)
$pnlCrExhaust.Size = New-Object System.Drawing.Size(524, 26)
$pnlCrExhaust.Visible = $false
$grpContentDetail.Controls.Add($pnlCrExhaust)

$lblCrExhaust = New-Object System.Windows.Forms.Label
$lblCrExhaust.Text = '동전 소진 시(잔량 10 미만):'
$lblCrExhaust.Location = New-Object System.Drawing.Point(0, 5)
# 폭 195 = 아래 '더블 루팅 불가 시' 라벨과 동일 - 두 줄의 라디오 시작 위치를 세로로 맞춥니다
$lblCrExhaust.Size = New-Object System.Drawing.Size(195, 20)
$pnlCrExhaust.Controls.Add($lblCrExhaust)

$rbCrExhaustStop = New-Object System.Windows.Forms.RadioButton
$rbCrExhaustStop.Text = '멈춤'
$rbCrExhaustStop.Location = New-Object System.Drawing.Point(200, 2)
$rbCrExhaustStop.Size = New-Object System.Drawing.Size(60, 22)
$rbCrExhaustStop.Checked = $true
$pnlCrExhaust.Controls.Add($rbCrExhaustStop)

$rbCrExhaustGo = New-Object System.Windows.Forms.RadioButton
$rbCrExhaustGo.Text = '미사용으로 진행'
$rbCrExhaustGo.Location = New-Object System.Drawing.Point(265, 2)
$rbCrExhaustGo.Size = New-Object System.Drawing.Size(135, 22)
$pnlCrExhaust.Controls.Add($rbCrExhaustGo)

$pnlCrNoDouble = New-Object System.Windows.Forms.Panel
$pnlCrNoDouble.Location = New-Object System.Drawing.Point(15, 76)
$pnlCrNoDouble.Size = New-Object System.Drawing.Size(524, 26)
$pnlCrNoDouble.Visible = $false
$grpContentDetail.Controls.Add($pnlCrNoDouble)

$lblCrNoDouble = New-Object System.Windows.Forms.Label
$lblCrNoDouble.Text = '더블 루팅 불가 시(잔량 10~19):'
$lblCrNoDouble.Location = New-Object System.Drawing.Point(0, 5)
$lblCrNoDouble.Size = New-Object System.Drawing.Size(195, 20)
$pnlCrNoDouble.Controls.Add($lblCrNoDouble)

$rbCrNoDoubleStop = New-Object System.Windows.Forms.RadioButton
$rbCrNoDoubleStop.Text = '멈춤'
$rbCrNoDoubleStop.Location = New-Object System.Drawing.Point(200, 2)
$rbCrNoDoubleStop.Size = New-Object System.Drawing.Size(60, 22)
$rbCrNoDoubleStop.Checked = $true
$pnlCrNoDouble.Controls.Add($rbCrNoDoubleStop)

$rbCrNoDoubleSweep = New-Object System.Windows.Forms.RadioButton
$rbCrNoDoubleSweep.Text = '소탕만 진행'
$rbCrNoDoubleSweep.Location = New-Object System.Drawing.Point(265, 2)
$rbCrNoDoubleSweep.Size = New-Object System.Drawing.Size(110, 22)
$pnlCrNoDouble.Controls.Add($rbCrNoDoubleSweep)

# 입력 줄의 은동전 체크: 더블 루팅 표시/해제 + 라디오 줄 표시 변경 (입력 줄 자체는 저장
# 대상이 아니라 저장 없음 - 항목은 [추가]를 눌러 리스트에 들어갈 때만 config 에 반영됩니다).
# 줄 표시가 바뀌면 리스트/하단 줄 위치와 그룹 높이를 updateCategoryPanels 로 재배치합니다
$chkCrCoin.Add_CheckedChanged({
    $chkCrDouble.Visible = $chkCrCoin.Checked
    if (-not $chkCrCoin.Checked) { $chkCrDouble.Checked = $false }
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })
$chkCrDouble.Add_CheckedChanged({
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })

# 리스트 (표 형태): 체크 / # / 난이도 / 구역 / 은동전(판당 소모량 - 더블 루팅 20개/소탕만 10개/미사용 0개)
#                 / 소진 시(진행·멈춤·—) / 더블 불가 시(소탕만·멈춤·—) - 뒤 2열은 항목별 소진 대응 속성
$lvCrList = New-Object System.Windows.Forms.ListView
$lvCrList.Location = New-Object System.Drawing.Point(15, 52)
$lvCrList.Size = New-Object System.Drawing.Size(392, 174)   # 아래끝을 [랜덤] 버튼 아래끝(listTop+174)과 일치 (2026-08-04 요청)
$lvCrList.View = [System.Windows.Forms.View]::Details
$lvCrList.GridLines = $true
$lvCrList.CheckBoxes = $true
$lvCrList.FullRowSelect = $true
$lvCrList.MultiSelect = $false
$lvCrList.HideSelection = $false
$lvCrList.Visible = $false
[void]$lvCrList.Columns.Add('', 28)
[void]$lvCrList.Columns.Add('#', 32)
[void]$lvCrList.Columns.Add('난이도', 74)   # '매우 어려움'까지 표시 (2026-07-24)
[void]$lvCrList.Columns.Add('구역', 44)
[void]$lvCrList.Columns.Add('은동전', 50)
[void]$lvCrList.Columns.Add('소진 시', 58)
[void]$lvCrList.Columns.Add('더블 불가 시', 82)
$grpContentDetail.Controls.Add($lvCrList)

# 0번(체크) 열 머리글 클릭 = 전체 선택/해제. WinForms ListView 에는 실제 머리글 체크박스가
# 없어 열 클릭으로 구현합니다 (요청사항의 '머리글 체크박스 칸 클릭' 스펙 충족).
$lvCrList.Add_ColumnClick({
    param($clickSender, $clickArgs)
    if ($script:running) { return }   # 실행 중엔 리스트가 스크롤용으로만 살아 있음 - 전체 토글 금지
    if ($clickArgs.Column -ne 0) { return }
    if ($lvCrList.Items.Count -eq 0) { return }
    $allChecked = $true
    foreach ($crRow in $lvCrList.Items) { if (-not $crRow.Checked) { $allChecked = $false; break } }
    $newState = -not $allChecked
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try { foreach ($crRow in $lvCrList.Items) { $crRow.Checked = $newState } }
    finally { $script:crLoading = $prevLoading }
  })
# 실행 중 체크 토글 금지 (마우스·Space 키 전 경로 차단): 리스트가 스크롤용으로 살아 있어
# 클릭이 닿습니다. running 만 조건으로 - crLoading 을 넣으면 실행 중 가드가 우회될 여지
# (리뷰 계약. 세 커스텀 리스트 공통)
$lvCrList.Add_ItemCheck({
    param($checkSender, $checkArgs)
    if ($script:running) { $checkArgs.NewValue = $checkArgs.CurrentValue }
  })

# 리스트 옆 버튼 열: [추가] [삭제] [↑] [↓] 순서 (추가 = 입력 줄+라디오 줄의 현재 상태를
# 항목으로 리스트에 넣음 / 삭제 = 체크 항목 일괄 / ↑↓ = 선택한 1줄 이동).
# Top 값은 라디오 줄 표시에 따라 updateCategoryPanels 가 리스트와 함께 재배치합니다
$btnCrAdd = New-Object System.Windows.Forms.Button
$btnCrAdd.Text = '추가'
$btnCrAdd.Location = New-Object System.Drawing.Point(413, 52)
$btnCrAdd.Size = New-Object System.Drawing.Size(94, 30)
$btnCrAdd.Visible = $false
$grpContentDetail.Controls.Add($btnCrAdd)

$btnCrDelete = New-Object System.Windows.Forms.Button
$btnCrDelete.Text = '삭제(체크)'
$btnCrDelete.Location = New-Object System.Drawing.Point(413, 88)
$btnCrDelete.Size = New-Object System.Drawing.Size(94, 30)
$btnCrDelete.Visible = $false
$grpContentDetail.Controls.Add($btnCrDelete)

$btnCrUp = New-Object System.Windows.Forms.Button
$btnCrUp.Text = '↑ 위로'
$btnCrUp.Location = New-Object System.Drawing.Point(413, 124)
$btnCrUp.Size = New-Object System.Drawing.Size(94, 30)
$btnCrUp.Visible = $false
$grpContentDetail.Controls.Add($btnCrUp)

$btnCrDown = New-Object System.Windows.Forms.Button
$btnCrDown.Text = '↓ 아래로'
$btnCrDown.Location = New-Object System.Drawing.Point(413, 160)
$btnCrDown.Size = New-Object System.Drawing.Size(94, 30)
$btnCrDown.Visible = $false
$grpContentDetail.Controls.Add($btnCrDown)

# 랜덤 진행 토글 (2026-08-04 확정 시안: 버튼 열 5번째. 층 혼합 리스트면 비활성 - Update-CustomRandomMixGate)
$chkCrRandom = New-Object System.Windows.Forms.CheckBox
$chkCrRandom.Appearance = 'Button'
$chkCrRandom.Text = '랜덤'
$chkCrRandom.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$chkCrRandom.Location = New-Object System.Drawing.Point(413, 196)
$chkCrRandom.Size = New-Object System.Drawing.Size(94, 30)
$chkCrRandom.FlatStyle = 'Flat'
$chkCrRandom.FlatAppearance.BorderColor = $script:themeBorder
$chkCrRandom.FlatAppearance.BorderSize = 1
$chkCrRandom.UseVisualStyleBackColor = $false
$chkCrRandom.BackColor = $script:themeControl
$chkCrRandom.Visible = $false
$grpContentDetail.Controls.Add($chkCrRandom)
$chkCrRandom.Add_CheckedChanged({
    Update-CustomRandomToggleStyle -Toggle $chkCrRandom
    if ($script:uiReady -and -not $script:crLoading) {
      Save-CustomRandomOrder -SectionName 'customRepeat' -Enabled ([bool]$chkCrRandom.Checked)
    }
  })

$btnCrAdd.Add_Click({
    $crDifficultyValue = [string]$cboCrDifficulty.SelectedItem
    $crStageValue = [string]$cboCrStage.SelectedItem
    if (-not $crDifficultyValue -or -not $crStageValue) { return }
    # 소진/더블 대응 정규화: coin=false 면 둘 다 false, double=false 면 noDoubleSweep=false.
    # double=true + 멈춤(noDoubleSweep=false)이면 소진 분기에 도달할 수 없어 exhaustContinue 도
    # false 로 저장합니다 (리스트 '—' 표기 ↔ Get-CustomItemsFromList 역해석 false 와 일치 -
    # 여기서 true 를 남기면 리스트 재저장 때 값이 바뀌어 지문 불일치로 진행 기록이 날아감)
    $crCoinValue = [bool]$chkCrCoin.Checked
    $crDoubleValue = [bool]($crCoinValue -and $chkCrDouble.Checked)
    $crNoDoubleValue = [bool]($crDoubleValue -and $rbCrNoDoubleSweep.Checked)
    $crExhaustValue = [bool]($crCoinValue -and $rbCrExhaustGo.Checked -and
      ((-not $crDoubleValue) -or $crNoDoubleValue))
    # 추가 차단 (2026-07-20 사용자 확정): 마지막 항목 → 새 항목 전환이 게임에서 불가능한
    # 조합(2층→1층 / 1-3 아닌 1층→2층)이면 추가하지 않고 팝업으로 안내합니다.
    # 이 팝업은 사용자가 [추가]를 누른 직후에만 뜰 수 있어 무인 운용을 막지 않음 -
    # 'GUI 팝업 금지' 규칙의 명시적 예외 (CLAUDE.md 참고. 실행 중엔 상세 설정이 비활성이라
    # 자동화 도중에는 발생 불가). ↑↓ 이동/삭제는 재배치 중간 상태가 일시적으로 위반일 수
    # 있어 차단하지 않고 경고 로그 + 시작 게이트로만 잡습니다.
    $crExistingItems = @(Get-CustomItemsFromList)
    if ($crExistingItems.Count -gt 0) {
      $crLastItem = $crExistingItems[$crExistingItems.Count - 1]
      $crNewItem = [pscustomobject]@{
        difficulty = $crDifficultyValue; stage = $crStageValue
        coin = $crCoinValue; doubleLoot = $crDoubleValue
        exhaustContinue = $crExhaustValue; noDoubleSweep = $crNoDoubleValue
      }
      # 마지막→새 항목 한 쌍만 검사 (count/1바퀴로 호출해 순환 검사는 제외 - 기존 위반과 무관하게
      # 이번 추가가 만드는 전환만 판정)
      $crPairIssues = @(Get-CustomTransitionIssues -Items @($crLastItem, $crNewItem) `
          -ListRepeat 'count' -ListRepeatCount 1)
      if ($crPairIssues.Count -gt 0) {
        $crBlockText = ("이 순서로는 추가할 수 없습니다.`n`n" +
          "마지막 항목 '{0}' 다음에 '{1}' 항목은 올 수 없습니다.`n{2}" -f `
            (Get-CustomItemLabel -Item $crLastItem), (Get-CustomItemLabel -Item $crNewItem), `
            [string]$crPairIssues[0].Reason)
        Add-GuiLog ('[안내] 추가 차단: {0} → {1} - {2}' -f `
            (Get-CustomItemLabel -Item $crLastItem), (Get-CustomItemLabel -Item $crNewItem), `
            [string]$crPairIssues[0].Reason)
        [System.Windows.Forms.MessageBox]::Show($crBlockText, '커스텀 반복 - 추가 불가',
          [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
      }
    }
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      Add-CustomListRow -Difficulty $crDifficultyValue -Stage $crStageValue `
        -Coin $crCoinValue -DoubleLoot $crDoubleValue `
        -ExhaustContinue $crExhaustValue -NoDoubleSweep $crNoDoubleValue
      Update-CustomListNumbers
    } finally { $script:crLoading = $prevLoading }
    if ($script:uiReady) { Save-CustomRepeatToConfig }
    # 전환 규칙 사전 경고: 지금 리스트에 불가능한 층 전환이 있으면 알려만 줍니다 (추가 자체는
    # 허용 - 이후 항목 추가로 위반이 해소될 수 있음. 최종 차단은 시작 버튼 게이트가 같은
    # 함수(Get-CustomTransitionIssues)로 수행)
    $crAddRepeat = $(if ($rbCrCount.Checked) { 'count' } else { 'infinite' })
    $crAddIssues = @(Get-CustomTransitionIssues -Items @(Get-CustomItemsFromList) `
        -ListRepeat $crAddRepeat -ListRepeatCount ([int]$numCrLaps.Value))
    foreach ($crAddIssue in $crAddIssues) {
      $crAddWrapTag = $(if ([bool]$crAddIssue.Wrap) { ' [바퀴 순환: 마지막 → 첫 항목]' } else { '' })
      Add-GuiLog ('[경고] {0} → {1}{2}: {3} - 이대로는 시작할 수 없습니다 (순서 조정 또는 뒤에 항목을 더 추가해 해소해 주세요).' -f `
          $crAddIssue.From, $crAddIssue.To, $crAddWrapTag, $crAddIssue.Reason)
    }
  })

$btnCrDelete.Add_Click({
    $checkedRows = @()
    foreach ($crRow in $lvCrList.Items) { if ($crRow.Checked) { $checkedRows += $crRow } }
    if ($checkedRows.Count -eq 0) {
      Add-GuiLog '[안내] 삭제할 항목의 앞 체크박스를 켠 뒤 [삭제(체크)]를 눌러 주세요. (첫 열 머리글 클릭 = 전체 선택/해제)'
      return
    }
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      foreach ($crRow in $checkedRows) { $lvCrList.Items.Remove($crRow) }
      Update-CustomListNumbers
    } finally { $script:crLoading = $prevLoading }
    if ($script:uiReady) { Save-CustomRepeatToConfig }
  })

$btnCrUp.Add_Click({ Move-CustomListRow -Delta (-1) })
$btnCrDown.Add_Click({ Move-CustomListRow -Delta 1 })

# 하단 줄: 리스트 반복 (무한 / 횟수 N바퀴 - '바퀴' 표기로 상단 '횟수 지정'과 구분) + 진행 초기화
# (소진 대응은 항목별 속성으로 옮겨 전역 소진 대응 줄(pnlCrFallback)은 폐지됐습니다)
$pnlCrRepeat = New-Object System.Windows.Forms.Panel
$pnlCrRepeat.Location = New-Object System.Drawing.Point(15, 238)
$pnlCrRepeat.Size = New-Object System.Drawing.Size(494, 28)
$pnlCrRepeat.Visible = $false
$grpContentDetail.Controls.Add($pnlCrRepeat)

$lblCrRepeat = New-Object System.Windows.Forms.Label
$lblCrRepeat.Text = '리스트 반복:'
$lblCrRepeat.Location = New-Object System.Drawing.Point(0, 5)
$lblCrRepeat.Size = New-Object System.Drawing.Size(80, 20)
$pnlCrRepeat.Controls.Add($lblCrRepeat)

$rbCrInfinite = New-Object System.Windows.Forms.RadioButton
$rbCrInfinite.Text = '무한'
$rbCrInfinite.Location = New-Object System.Drawing.Point(85, 2)
$rbCrInfinite.Size = New-Object System.Drawing.Size(55, 22)
$rbCrInfinite.Checked = $true
$pnlCrRepeat.Controls.Add($rbCrInfinite)

$rbCrCount = New-Object System.Windows.Forms.RadioButton
$rbCrCount.Text = '횟수:'
$rbCrCount.Location = New-Object System.Drawing.Point(145, 2)
$rbCrCount.Size = New-Object System.Drawing.Size(60, 22)
$pnlCrRepeat.Controls.Add($rbCrCount)

$numCrLaps = New-Object System.Windows.Forms.NumericUpDown
$numCrLaps.Location = New-Object System.Drawing.Point(205, 0)
$numCrLaps.Size = New-Object System.Drawing.Size(50, 24)
$numCrLaps.Minimum = 1
$numCrLaps.Maximum = 999
$numCrLaps.Value = 1
$numCrLaps.Enabled = $false   # '횟수' 라디오를 골랐을 때만 활성
$pnlCrRepeat.Controls.Add($numCrLaps)

$lblCrLaps = New-Object System.Windows.Forms.Label
$lblCrLaps.Text = '바퀴'
$lblCrLaps.Location = New-Object System.Drawing.Point(258, 5)
$lblCrLaps.Size = New-Object System.Drawing.Size(35, 20)
$pnlCrRepeat.Controls.Add($lblCrLaps)

# 리스트에 필요한 은동전 합계 표시 (합산 Get-CustomCoinTotalPerLap / 갱신 Update-CustomCoinTotalLabel)
$lblCrCoinTotal = New-Object System.Windows.Forms.Label
$lblCrCoinTotal.Text = '바퀴당 은동전 0개'
$lblCrCoinTotal.Location = New-Object System.Drawing.Point(293, 5)
$lblCrCoinTotal.Size = New-Object System.Drawing.Size(119, 20)
$lblCrCoinTotal.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblCrCoinTotal.AutoEllipsis = $true   # 항목이 많아 합계가 길어져도 두 줄로 깨지지 않게 (2026-08-08)
$lblCrCoinTotal.ForeColor = [System.Drawing.Color]::SteelBlue
$pnlCrRepeat.Controls.Add($lblCrCoinTotal)

$btnCrReset = New-Object System.Windows.Forms.Button
$btnCrReset.Text = '진행 초기화'
$btnCrReset.Location = New-Object System.Drawing.Point(414, 0)
$btnCrReset.Size = New-Object System.Drawing.Size(80, 26)
$pnlCrRepeat.Controls.Add($btnCrReset)

# 커스텀 설정 변경 = 즉시 저장 (ui.logFontSize 즉시 저장 패턴. 로딩 중에는 가드로 억제)
# 라디오 전환은 상대 버튼 CheckedChanged 도 발화하므로 '횟수' 버튼 하나로 켬/끔 전환을 모두 잡습니다
$rbCrCount.Add_CheckedChanged({
    $numCrLaps.Enabled = $rbCrCount.Checked
    if ($script:uiReady -and -not $script:crLoading) { Save-CustomRepeatToConfig }
  })
$numCrLaps.Add_ValueChanged({ if ($script:uiReady -and -not $script:crLoading) { Save-CustomRepeatToConfig } })
$btnCrReset.Add_Click({
    Reset-CustomProgress -SectionName 'customRepeat' `
      -LogMessage '[안내] 커스텀 반복 진행 기록을 초기화했습니다 - 다음 시작은 리스트 처음(1바퀴째 1번)부터입니다.'
  })

# ============================================================
#  '어비스 + 커스텀 반복' 목록/설정 화면
#  던전 커스텀과 별도 목록을 사용하되 진행 기록·완료 마커·오류 재시도 계약은 공용입니다.
# ============================================================
$pnlAcrInput = New-Object System.Windows.Forms.Panel
$pnlAcrInput.Location = New-Object System.Drawing.Point(15, 20)
$pnlAcrInput.Size = New-Object System.Drawing.Size(524, 26)
$pnlAcrInput.Visible = $false
$grpContentDetail.Controls.Add($pnlAcrInput)

$rbAcrSolo = New-Object System.Windows.Forms.RadioButton
$rbAcrSolo.Text = '혼자하기'
$rbAcrSolo.Location = New-Object System.Drawing.Point(0, 2)
$rbAcrSolo.Size = New-Object System.Drawing.Size(82, 22)
$rbAcrSolo.Checked = $true
$pnlAcrInput.Controls.Add($rbAcrSolo)

$rbAcrParty = New-Object System.Windows.Forms.RadioButton
$rbAcrParty.Text = '함께하기'
$rbAcrParty.Location = New-Object System.Drawing.Point(85, 2)
$rbAcrParty.Size = New-Object System.Drawing.Size(86, 22)
$pnlAcrInput.Controls.Add($rbAcrParty)

$lblAcrDifficulty = New-Object System.Windows.Forms.Label
$lblAcrDifficulty.Text = '난이도:'
$lblAcrDifficulty.Location = New-Object System.Drawing.Point(175, 5)
$lblAcrDifficulty.Size = New-Object System.Drawing.Size(50, 20)
$pnlAcrInput.Controls.Add($lblAcrDifficulty)

$cboAcrDifficulty = New-Object System.Windows.Forms.ComboBox
$cboAcrDifficulty.Location = New-Object System.Drawing.Point(225, 1)
$cboAcrDifficulty.Size = New-Object System.Drawing.Size(96, 24)
$cboAcrDifficulty.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$pnlAcrInput.Controls.Add($cboAcrDifficulty)

$lblAcrDungeon = New-Object System.Windows.Forms.Label
$lblAcrDungeon.Text = '어비스:'
$lblAcrDungeon.Location = New-Object System.Drawing.Point(330, 5)
$lblAcrDungeon.Size = New-Object System.Drawing.Size(50, 20)
$pnlAcrInput.Controls.Add($lblAcrDungeon)

$cboAcrDungeon = New-Object System.Windows.Forms.ComboBox
$cboAcrDungeon.Location = New-Object System.Drawing.Point(380, 1)
$cboAcrDungeon.Size = New-Object System.Drawing.Size(115, 24)
$cboAcrDungeon.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
foreach ($acrDungeonName in @('허상의 정박지', '광기의 동굴', '흩어진 물길')) {
  [void]$cboAcrDungeon.Items.Add($acrDungeonName)
}
$cboAcrDungeon.SelectedIndex = 0
$pnlAcrInput.Controls.Add($cboAcrDungeon)

$updateAcrDifficultyItems = {
  $currentAcrDifficulty = [string]$cboAcrDifficulty.SelectedItem
  $cboAcrDifficulty.Items.Clear()
  foreach ($acrDifficultyName in @('게임 그대로', '입문', '어려움', '매우 어려움')) {
    [void]$cboAcrDifficulty.Items.Add($acrDifficultyName)
  }
  if ($rbAcrParty.Checked) {
    for ($acrHellLevel = 1; $acrHellLevel -le 10; $acrHellLevel++) {
      [void]$cboAcrDifficulty.Items.Add("지옥$acrHellLevel")
    }
  }
  if ($currentAcrDifficulty -and $cboAcrDifficulty.Items.Contains($currentAcrDifficulty)) {
    $cboAcrDifficulty.SelectedItem = $currentAcrDifficulty
  } else {
    $cboAcrDifficulty.SelectedIndex = 0
  }
}
& $updateAcrDifficultyItems

# 함께하기에서만 표시되는 어비스 커스텀 매칭 줄 (파티원 모드는 목록 대상에서 제외).
$pnlAcrMatching = New-Object System.Windows.Forms.Panel
$pnlAcrMatching.Location = New-Object System.Drawing.Point(15, 50)
$pnlAcrMatching.Size = New-Object System.Drawing.Size(524, 26)
$pnlAcrMatching.Visible = $false
$grpContentDetail.Controls.Add($pnlAcrMatching)

$lblAcrMatching = New-Object System.Windows.Forms.Label
$lblAcrMatching.Text = '매칭:'
$lblAcrMatching.Location = New-Object System.Drawing.Point(0, 5)
$lblAcrMatching.Size = New-Object System.Drawing.Size(52, 20)
$pnlAcrMatching.Controls.Add($lblAcrMatching)

$rbAcrChance = New-Object System.Windows.Forms.RadioButton
$rbAcrChance.Text = '우연한 만남'
$rbAcrChance.Location = New-Object System.Drawing.Point(58, 2)
$rbAcrChance.Size = New-Object System.Drawing.Size(110, 22)
$rbAcrChance.Checked = $true
$pnlAcrMatching.Controls.Add($rbAcrChance)

$rbAcrFindParty = New-Object System.Windows.Forms.RadioButton
$rbAcrFindParty.Text = '파티 찾기'
$rbAcrFindParty.Location = New-Object System.Drawing.Point(185, 2)
$rbAcrFindParty.Size = New-Object System.Drawing.Size(95, 22)
$pnlAcrMatching.Controls.Add($rbAcrFindParty)

$rbAcrPartyLead = New-Object System.Windows.Forms.RadioButton
$rbAcrPartyLead.Text = '파티(파티장)'
$rbAcrPartyLead.Location = New-Object System.Drawing.Point(292, 2)
$rbAcrPartyLead.Size = New-Object System.Drawing.Size(120, 22)
$pnlAcrMatching.Controls.Add($rbAcrPartyLead)

# 잠긴(비활성) 라디오 위에서도 자동부활 체크박스처럼 설명이 뜨게 합니다.
# WinForms 는 비활성 컨트롤에 마우스 이벤트를 주지 않아 SetToolTip 이 통하지 않으므로,
# 부모 패널의 MouseMove 로 커서가 어느 라디오 영역에 있는지 직접 판정해 띄웁니다.
# 같은 컨트롤 위에서는 Show 를 다시 부르지 않아 깜박이지 않습니다(2026-07-22 실기 반영).
$acrLockTipText = '리스트의 방식·매칭과 같아야 합니다. 리스트의 방식/매칭 칸을 클릭하면 전체를 한 번에 바꿀 수 있습니다.'
$acrLockTipMove = {
  param($tipSender, $tipArgs)
  if (-not $script:acrLockOn) { return }
  $tipHit = $null
  foreach ($tipCtl in $tipSender.Controls) {
    if ($tipCtl -is [System.Windows.Forms.RadioButton] -and (-not $tipCtl.Enabled) -and
      $tipCtl.Bounds.Contains($tipArgs.Location)) { $tipHit = $tipCtl; break }
  }
  if ($tipHit) {
    if ($script:acrTipShownFor -ne $tipHit) {
      $script:acrTipShownFor = $tipHit
      $toolTip.Show($acrLockTipText, $tipSender, $tipHit.Left, ($tipHit.Bottom + 2), 8000)
    }
  } elseif ($script:acrTipShownFor) {
    $script:acrTipShownFor = $null
    $toolTip.Hide($tipSender)
  }
}
$acrLockTipLeave = {
  param($tipSender, $tipArgs)
  if ($script:acrTipShownFor) {
    $script:acrTipShownFor = $null
    $toolTip.Hide($tipSender)
  }
}
foreach ($acrTipPanel in @($pnlAcrInput, $pnlAcrMatching)) {
  $acrTipPanel.Add_MouseMove($acrLockTipMove)
  $acrTipPanel.Add_MouseLeave($acrLockTipLeave)
}

# ============================================================
#  커스텀 리스트 셀 편집 오버레이 (2026-07-25): 셀 클릭 → 그 자리 드롭다운으로 수정.
#  에디터는 드롭다운이 열려 있는 동안만 존재합니다 (닫히면 즉시 숨김 - 스크롤/리사이즈
#  동기화 문제 원천 제거). 적용은 SelectionChangeCommitted 에서 '예약'(BeginInvoke)만 하고
#  DropDownClosed 는 숨기기만 합니다 (ESC/외부 클릭은 커밋 없이 닫힘 - 설계 합의).
# ============================================================
$script:cellEditCombo = New-Object System.Windows.Forms.ComboBox
$script:cellEditCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$script:cellEditCombo.Visible = $false
$script:cellEditContext = $null
$script:cellEditSession = 0

$script:cellEditCombo.Add_SelectionChangeCommitted({
    $commitContext = $script:cellEditContext
    if (-not $commitContext -or $commitContext.Applied) { return }
    $commitContext.Applied = $true
    $commitContext.Value = [string]$script:cellEditCombo.SelectedItem
    # 이벤트 연쇄가 끝난 뒤 적용. 예약 시점의 세션을 클로저로 캡처해 오래된 callback 이
    # 새 편집 세션의 컨텍스트를 건드리지 못하게 합니다 (리뷰 지적).
    $commitSession = [int]$commitContext.Session
    $null = $script:cellEditCombo.BeginInvoke([Action] ({ Invoke-CellEditApply -ExpectedSession $commitSession }.GetNewClosure()))
  })
$script:cellEditCombo.Add_DropDownClosed({
    # 숨기기만 - 컨텍스트는 지우지 않습니다 (커밋된 편집의 지연 적용이 사용)
    Hide-CellEditCombo
  })

$cellEditMouseUp = {
  param($clickSender, $clickArgs)
  if ($clickArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
  # customViewShuffled 도 막습니다: 랜덤 표시 중에는 화면 행 순서와 Get-*ItemsFromList 의
  # 반환 순서(Tag = 등록 순서)가 서로 다른 좌표계라, HitTest 로 얻은 화면 인덱스로 읽고
  # 쓰면 A 행을 읽어 B 행에 씁니다. 지금은 셔플이 실행 중에만 켜져 running 가드에 가려
  # 도달하지 않지만, 로직이 옳아서가 아니라 가려져 있을 뿐이라 명시적으로 닫습니다
  # (한 줄로 4리스트 전부 봉인 - 리스트별 비대칭 금지)
  if ($script:crLoading -or $script:running -or $script:customViewShuffled) { return }
  if (-not $clickSender.Enabled -or -not $clickSender.Visible) { return }
  $cellHit = $clickSender.HitTest($clickArgs.X, $clickArgs.Y)
  if (-not $cellHit.Item -or -not $cellHit.SubItem) { return }
  $cellColumn = $cellHit.Item.SubItems.IndexOf($cellHit.SubItem)
  if ($cellColumn -lt 2) { return }   # 체크박스/# 열은 편집 대상 아님
  $cellRow = $cellHit.Item.Index
  # 리스트마다 **명시 분기**입니다. 예전에는 마지막이 조건 없는 어비스 폴백(`} else {`)이라
  # 새 리스트를 연결하는 순간 그 클릭이 어비스 계획을 타 엉뚱한 옵션이 떴습니다
  # (2026-08-08 생활 리스트 추가하며 발견). 마지막 else 는 return 으로 닫아 5번째 리스트가
  # 생겨도 같은 사고가 반복되지 않게 합니다.
  if ($clickSender -eq $lvCrList) {
    $cellItems = @(Get-CustomItemsFromList)
    if ($cellRow -ge $cellItems.Count) { return }
    $cellPlan = Get-CrCellEditPlan -ColumnIndex $cellColumn -Item $cellItems[$cellRow]
  } elseif ($clickSender -eq $lvDcrList) {
    $cellItems = @(Get-DeepCustomItemsFromList)
    if ($cellRow -ge $cellItems.Count) { return }
    $cellPlan = Get-DcrCellEditPlan -ColumnIndex $cellColumn -Item $cellItems[$cellRow]
  } elseif ($clickSender -eq $lvLcrList) {
    $cellItems = @(Get-LifeCustomItemsFromList)
    if ($cellRow -ge $cellItems.Count) { return }
    $cellPlan = Get-LcrCellEditPlan -ColumnIndex $cellColumn -Item $cellItems[$cellRow]
  } elseif ($clickSender -eq $lvAcrList) {
    $cellItems = @(Get-AbyssCustomItemsFromList)
    if ($cellRow -ge $cellItems.Count) { return }
    $cellPlan = Get-AcrCellEditPlan -ColumnIndex $cellColumn -Item $cellItems[$cellRow]
  } else {
    return   # 알 수 없는 리스트는 조용히 무시 (어비스 폴백 금지)
  }
  if (-not $cellPlan) { return }
  Show-CellEditCombo -ListView $clickSender -RowIndex $cellRow -ColumnIndex $cellColumn `
    -Options ([string[]]$cellPlan.Options) -Current ([string]$cellPlan.Current)
}
# 주의: 이벤트 연결은 각 ListView 가 '생성된 뒤'에 합니다 - $lvAcrList 는 이 아래에서
# 생성되므로 여기서는 던전 리스트만 연결하고, 어비스는 생성 직후에 연결합니다 (리뷰 지적).
$lvCrList.Add_MouseUp($cellEditMouseUp)

$lvAcrList = New-Object System.Windows.Forms.ListView
$lvAcrList.Location = New-Object System.Drawing.Point(15, 52)
$lvAcrList.Size = New-Object System.Drawing.Size(392, 174)   # 아래끝을 [랜덤] 버튼 아래끝(listTop+174)과 일치 (2026-08-04 요청)
$lvAcrList.View = [System.Windows.Forms.View]::Details
$lvAcrList.GridLines = $true
$lvAcrList.CheckBoxes = $true
$lvAcrList.FullRowSelect = $true
$lvAcrList.MultiSelect = $false
$lvAcrList.HideSelection = $false
$lvAcrList.Visible = $false
[void]$lvAcrList.Columns.Add('', 28)
[void]$lvAcrList.Columns.Add('#', 30)
[void]$lvAcrList.Columns.Add('방식', 65)
[void]$lvAcrList.Columns.Add('난이도', 72)
[void]$lvAcrList.Columns.Add('어비스 던전', 90)
[void]$lvAcrList.Columns.Add('매칭', 82)
$grpContentDetail.Controls.Add($lvAcrList)
$lvAcrList.Add_MouseUp($cellEditMouseUp)   # 셀 편집 - 생성 직후 연결 (위 던전 리스트와 공용 핸들러)

$lvAcrList.Add_ColumnClick({
    param($acrClickSender, $acrClickArgs)
    if ($script:running) { return }   # 실행 중 전체 토글 금지 (던전 리스트와 동일 가드)
    if ($acrClickArgs.Column -ne 0 -or $lvAcrList.Items.Count -eq 0) { return }
    $acrAllChecked = $true
    foreach ($acrRow in $lvAcrList.Items) { if (-not $acrRow.Checked) { $acrAllChecked = $false; break } }
    foreach ($acrRow in $lvAcrList.Items) { $acrRow.Checked = -not $acrAllChecked }
  })
$lvAcrList.Add_ItemCheck({
    param($acrCheckSender, $acrCheckArgs)
    if ($script:running) { $acrCheckArgs.NewValue = $acrCheckArgs.CurrentValue }   # 실행 중 체크 토글 금지
  })

$btnAcrAdd = New-Object System.Windows.Forms.Button
$btnAcrAdd.Text = '추가'
$btnAcrAdd.Location = New-Object System.Drawing.Point(413, 52)
$btnAcrAdd.Size = New-Object System.Drawing.Size(94, 30)
$btnAcrAdd.Visible = $false
$grpContentDetail.Controls.Add($btnAcrAdd)

$btnAcrDelete = New-Object System.Windows.Forms.Button
$btnAcrDelete.Text = '삭제(체크)'
$btnAcrDelete.Location = New-Object System.Drawing.Point(413, 88)
$btnAcrDelete.Size = New-Object System.Drawing.Size(94, 30)
$btnAcrDelete.Visible = $false
$grpContentDetail.Controls.Add($btnAcrDelete)

$btnAcrUp = New-Object System.Windows.Forms.Button
$btnAcrUp.Text = '↑ 위로'
$btnAcrUp.Location = New-Object System.Drawing.Point(413, 124)
$btnAcrUp.Size = New-Object System.Drawing.Size(94, 30)
$btnAcrUp.Visible = $false
$grpContentDetail.Controls.Add($btnAcrUp)

$btnAcrDown = New-Object System.Windows.Forms.Button
$btnAcrDown.Text = '↓ 아래로'
$btnAcrDown.Location = New-Object System.Drawing.Point(413, 160)
$btnAcrDown.Size = New-Object System.Drawing.Size(94, 30)
$btnAcrDown.Visible = $false
$grpContentDetail.Controls.Add($btnAcrDown)

# 랜덤 진행 토글 (어비스 - 층 제약이 없어 항상 사용 가능)
$chkAcrRandom = New-Object System.Windows.Forms.CheckBox
$chkAcrRandom.Appearance = 'Button'
$chkAcrRandom.Text = '랜덤'
$chkAcrRandom.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$chkAcrRandom.Location = New-Object System.Drawing.Point(413, 196)
$chkAcrRandom.Size = New-Object System.Drawing.Size(94, 30)
$chkAcrRandom.FlatStyle = 'Flat'
$chkAcrRandom.FlatAppearance.BorderColor = $script:themeBorder
$chkAcrRandom.FlatAppearance.BorderSize = 1
$chkAcrRandom.UseVisualStyleBackColor = $false
$chkAcrRandom.BackColor = $script:themeControl
$chkAcrRandom.Visible = $false
$grpContentDetail.Controls.Add($chkAcrRandom)
$chkAcrRandom.Add_CheckedChanged({
    Update-CustomRandomToggleStyle -Toggle $chkAcrRandom
    if ($script:uiReady -and -not $script:crLoading) {
      Save-CustomRandomOrder -SectionName 'abyssCustomRepeat' -Enabled ([bool]$chkAcrRandom.Checked)
    }
  })

$btnAcrAdd.Add_Click({
    $acrMode = $(if ($rbAcrParty.Checked) { 'party' } else { 'solo' })
    $acrMatchingText = '없음'
    if ($rbAcrParty.Checked) {
      if ($rbAcrFindParty.Checked) { $acrMatchingText = '파티 찾기' }
      elseif ($rbAcrPartyLead.Checked) { $acrMatchingText = '파티(파티장)' }
      else { $acrMatchingText = '우연한 만남' }
    }
    Add-AbyssCustomListRow -Mode $acrMode -Difficulty ([string]$cboAcrDifficulty.SelectedItem) `
      -Dungeon ([string]$cboAcrDungeon.SelectedItem) -Matching $acrMatchingText
    Update-AbyssCustomListNumbers
    # 첫 항목이 들어오면 방식·매칭 입력을 그 값으로 잠급니다 (리스트 전체 통일 규칙)
    Update-AbyssInputLock
    if ($script:uiReady) { Save-CustomRepeatToConfig }
  })

$btnAcrDelete.Add_Click({
    $acrCheckedRows = @($lvAcrList.Items | Where-Object { $_.Checked })
    if ($acrCheckedRows.Count -eq 0) {
      Add-GuiLog '[안내] 삭제할 어비스 항목의 앞 체크박스를 선택해 주세요.'
      return
    }
    foreach ($acrRow in $acrCheckedRows) { $lvAcrList.Items.Remove($acrRow) }
    Update-AbyssCustomListNumbers
    # 리스트가 비면 방식·매칭 입력을 다시 열어 줍니다
    Update-AbyssInputLock
    if ($script:uiReady) { Save-CustomRepeatToConfig }
  })

$btnAcrUp.Add_Click({ Move-AbyssCustomListRow -Delta (-1) })
$btnAcrDown.Add_Click({ Move-AbyssCustomListRow -Delta 1 })

$pnlAcrRepeat = New-Object System.Windows.Forms.Panel
$pnlAcrRepeat.Location = New-Object System.Drawing.Point(15, 238)
$pnlAcrRepeat.Size = New-Object System.Drawing.Size(494, 28)
$pnlAcrRepeat.Visible = $false
$grpContentDetail.Controls.Add($pnlAcrRepeat)

$lblAcrRepeat = New-Object System.Windows.Forms.Label
$lblAcrRepeat.Text = '리스트 반복:'
$lblAcrRepeat.Location = New-Object System.Drawing.Point(0, 5)
$lblAcrRepeat.Size = New-Object System.Drawing.Size(80, 20)
$pnlAcrRepeat.Controls.Add($lblAcrRepeat)

$rbAcrInfinite = New-Object System.Windows.Forms.RadioButton
$rbAcrInfinite.Text = '무한'
$rbAcrInfinite.Location = New-Object System.Drawing.Point(85, 2)
$rbAcrInfinite.Size = New-Object System.Drawing.Size(55, 22)
$rbAcrInfinite.Checked = $true
$pnlAcrRepeat.Controls.Add($rbAcrInfinite)

$rbAcrCount = New-Object System.Windows.Forms.RadioButton
$rbAcrCount.Text = '횟수:'
$rbAcrCount.Location = New-Object System.Drawing.Point(145, 2)
$rbAcrCount.Size = New-Object System.Drawing.Size(60, 22)
$pnlAcrRepeat.Controls.Add($rbAcrCount)

$numAcrLaps = New-Object System.Windows.Forms.NumericUpDown
$numAcrLaps.Location = New-Object System.Drawing.Point(205, 0)
$numAcrLaps.Size = New-Object System.Drawing.Size(50, 24)
$numAcrLaps.Minimum = 1
$numAcrLaps.Maximum = 999
$numAcrLaps.Value = 1
$numAcrLaps.Enabled = $false
$pnlAcrRepeat.Controls.Add($numAcrLaps)

$lblAcrLaps = New-Object System.Windows.Forms.Label
$lblAcrLaps.Text = '바퀴'
$lblAcrLaps.Location = New-Object System.Drawing.Point(258, 5)
$lblAcrLaps.Size = New-Object System.Drawing.Size(35, 20)
$pnlAcrRepeat.Controls.Add($lblAcrLaps)

$btnAcrReset = New-Object System.Windows.Forms.Button
$btnAcrReset.Text = '진행 초기화'
$btnAcrReset.Location = New-Object System.Drawing.Point(414, 0)
$btnAcrReset.Size = New-Object System.Drawing.Size(80, 26)
$btnAcrReset.Enabled = $true
$pnlAcrRepeat.Controls.Add($btnAcrReset)

$rbAcrInfinite.Add_CheckedChanged({
    if ($rbAcrInfinite.Checked -and $script:uiReady -and -not $script:crLoading) { Save-CustomRepeatToConfig }
  })
$rbAcrCount.Add_CheckedChanged({
    $numAcrLaps.Enabled = $rbAcrCount.Checked
    if ($rbAcrCount.Checked -and $script:uiReady -and -not $script:crLoading) { Save-CustomRepeatToConfig }
  })
$numAcrLaps.Add_ValueChanged({
    if ($script:uiReady -and -not $script:crLoading) { Save-CustomRepeatToConfig }
  })
$btnAcrReset.Add_Click({
    Reset-CustomProgress -SectionName 'abyssCustomRepeat' `
      -LogMessage '[안내] 어비스 커스텀 반복 진행 기록을 초기화했습니다 - 다음 시작은 리스트 처음(1바퀴째 1번)부터입니다.'
  })
$rbAcrSolo.Add_CheckedChanged({
    & $updateAcrDifficultyItems
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })
$rbAcrParty.Add_CheckedChanged({
    & $updateAcrDifficultyItems
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })

# ============================================================
#  '심층던전 + 커스텀 반복' 목록/설정 화면 (2026-07-28)
#  던전 커스텀과 같은 항목 계약(6조각 토큰)을 쓰되 컨트롤·저장 섹션(deepCustomRepeat)·
#  완료 마커를 완전히 분리합니다 (경량안 합의 - 기존 던전 커스텀 코드 무접촉).
#  난이도는 어려움 고정/더블 루팅 없음이라 입력은 구역 + 마족공물 + 소진 대응만 받습니다.
# ============================================================
$pnlDcrInput = New-Object System.Windows.Forms.Panel
$pnlDcrInput.Location = New-Object System.Drawing.Point(15, 20)
$pnlDcrInput.Size = New-Object System.Drawing.Size(524, 26)
$pnlDcrInput.Visible = $false
$grpContentDetail.Controls.Add($pnlDcrInput)

# 난이도 고정 안내 라벨: 심층 커스텀은 어려움 고정이라 난이도 입력이 없는데, 던전 커스텀
# 입력 줄(난이도 콤보 시작)과 비교하면 빠진 것처럼 보임 (2026-07-28 사용자 피드백 →
# 설계 합의: 입력 줄에서 고정 제약을 설명하고 리스트에는 변동값만 표시)
$lblDcrDifficulty = New-Object System.Windows.Forms.Label
$lblDcrDifficulty.Text = '난이도: 어려움 (고정)'
$lblDcrDifficulty.Location = New-Object System.Drawing.Point(0, 5)
$lblDcrDifficulty.Size = New-Object System.Drawing.Size(140, 20)
$pnlDcrInput.Controls.Add($lblDcrDifficulty)

$cboDcrStage = New-Object System.Windows.Forms.ComboBox
$cboDcrStage.Location = New-Object System.Drawing.Point(145, 1)
$cboDcrStage.Size = New-Object System.Drawing.Size(84, 24)
$cboDcrStage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
foreach ($dcrChapter in 1..2) {
  foreach ($dcrStep in 1..3) { [void]$cboDcrStage.Items.Add("D$dcrChapter-$dcrStep") }
}
$cboDcrStage.SelectedIndex = 0
$pnlDcrInput.Controls.Add($cboDcrStage)

$chkDcrTribute = New-Object System.Windows.Forms.CheckBox
$chkDcrTribute.Text = '마족공물'
$chkDcrTribute.Location = New-Object System.Drawing.Point(239, 2)
$chkDcrTribute.Size = New-Object System.Drawing.Size(85, 22)
$pnlDcrInput.Controls.Add($chkDcrTribute)

# 입력 줄 아래 라디오 줄: '다음에 [추가]할 항목'의 공물 소진 대응 속성 (기본 멈춤,
# 마족공물 체크 시에만 표시. 표시/배치는 updateCategoryPanels 가 제어)
$pnlDcrExhaust = New-Object System.Windows.Forms.Panel
$pnlDcrExhaust.Location = New-Object System.Drawing.Point(15, 50)
$pnlDcrExhaust.Size = New-Object System.Drawing.Size(524, 26)
$pnlDcrExhaust.Visible = $false
$grpContentDetail.Controls.Add($pnlDcrExhaust)

$lblDcrExhaust = New-Object System.Windows.Forms.Label
$lblDcrExhaust.Text = '공물 소진 시(잔량 부족):'
$lblDcrExhaust.Location = New-Object System.Drawing.Point(0, 5)
$lblDcrExhaust.Size = New-Object System.Drawing.Size(195, 20)
$pnlDcrExhaust.Controls.Add($lblDcrExhaust)

$rbDcrExhaustStop = New-Object System.Windows.Forms.RadioButton
$rbDcrExhaustStop.Text = '멈춤'
$rbDcrExhaustStop.Location = New-Object System.Drawing.Point(200, 2)
$rbDcrExhaustStop.Size = New-Object System.Drawing.Size(60, 22)
$rbDcrExhaustStop.Checked = $true
$pnlDcrExhaust.Controls.Add($rbDcrExhaustStop)

$rbDcrExhaustGo = New-Object System.Windows.Forms.RadioButton
$rbDcrExhaustGo.Text = '미사용으로 진행'
$rbDcrExhaustGo.Location = New-Object System.Drawing.Point(265, 2)
$rbDcrExhaustGo.Size = New-Object System.Drawing.Size(135, 22)
$pnlDcrExhaust.Controls.Add($rbDcrExhaustGo)

$chkDcrTribute.Add_CheckedChanged({
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
  })

# 리스트 (표 형태): 체크 / # / 구역(D표기) / 마족공물(판당 소모량) / 소진 시
$lvDcrList = New-Object System.Windows.Forms.ListView
$lvDcrList.Location = New-Object System.Drawing.Point(15, 52)
$lvDcrList.Size = New-Object System.Drawing.Size(392, 174)   # 아래끝을 [랜덤] 버튼 아래끝(listTop+174)과 일치 (2026-08-04 요청)
$lvDcrList.View = [System.Windows.Forms.View]::Details
$lvDcrList.GridLines = $true
$lvDcrList.CheckBoxes = $true
$lvDcrList.FullRowSelect = $true
$lvDcrList.MultiSelect = $false
$lvDcrList.HideSelection = $false
$lvDcrList.Visible = $false
[void]$lvDcrList.Columns.Add('', 28)
[void]$lvDcrList.Columns.Add('#', 32)
[void]$lvDcrList.Columns.Add('구역', 68)
[void]$lvDcrList.Columns.Add('마족공물', 74)
[void]$lvDcrList.Columns.Add('소진 시', 78)
$grpContentDetail.Controls.Add($lvDcrList)
$lvDcrList.Add_MouseUp($cellEditMouseUp)   # 셀 편집 - 생성 직후 연결 (던전/어비스 리스트와 공용 핸들러)

# 0번(체크) 열 머리글 클릭 = 전체 선택/해제 (던전 리스트와 동일 규칙)
$lvDcrList.Add_ColumnClick({
    param($dcrClickSender, $dcrClickArgs)
    if ($script:running) { return }   # 실행 중 전체 토글 금지 (던전 리스트와 동일 가드)
    if ($dcrClickArgs.Column -ne 0 -or $lvDcrList.Items.Count -eq 0) { return }
    $dcrAllChecked = $true
    foreach ($dcrRow in $lvDcrList.Items) { if (-not $dcrRow.Checked) { $dcrAllChecked = $false; break } }
    $dcrNewState = -not $dcrAllChecked
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try { foreach ($dcrRow in $lvDcrList.Items) { $dcrRow.Checked = $dcrNewState } }
    finally { $script:crLoading = $prevLoading }
  })
$lvDcrList.Add_ItemCheck({
    param($dcrCheckSender, $dcrCheckArgs)
    if ($script:running) { $dcrCheckArgs.NewValue = $dcrCheckArgs.CurrentValue }   # 실행 중 체크 토글 금지
  })

$btnDcrAdd = New-Object System.Windows.Forms.Button
$btnDcrAdd.Text = '추가'
$btnDcrAdd.Location = New-Object System.Drawing.Point(413, 52)
$btnDcrAdd.Size = New-Object System.Drawing.Size(94, 30)
$btnDcrAdd.Visible = $false
$grpContentDetail.Controls.Add($btnDcrAdd)

$btnDcrDelete = New-Object System.Windows.Forms.Button
$btnDcrDelete.Text = '삭제(체크)'
$btnDcrDelete.Location = New-Object System.Drawing.Point(413, 88)
$btnDcrDelete.Size = New-Object System.Drawing.Size(94, 30)
$btnDcrDelete.Visible = $false
$grpContentDetail.Controls.Add($btnDcrDelete)

$btnDcrUp = New-Object System.Windows.Forms.Button
$btnDcrUp.Text = '↑ 위로'
$btnDcrUp.Location = New-Object System.Drawing.Point(413, 124)
$btnDcrUp.Size = New-Object System.Drawing.Size(94, 30)
$btnDcrUp.Visible = $false
$grpContentDetail.Controls.Add($btnDcrUp)

$btnDcrDown = New-Object System.Windows.Forms.Button
$btnDcrDown.Text = '↓ 아래로'
$btnDcrDown.Location = New-Object System.Drawing.Point(413, 160)
$btnDcrDown.Size = New-Object System.Drawing.Size(94, 30)
$btnDcrDown.Visible = $false
$grpContentDetail.Controls.Add($btnDcrDown)

# 랜덤 진행 토글 (심층 - 층 혼합 리스트면 비활성)
$chkDcrRandom = New-Object System.Windows.Forms.CheckBox
$chkDcrRandom.Appearance = 'Button'
$chkDcrRandom.Text = '랜덤'
$chkDcrRandom.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$chkDcrRandom.Location = New-Object System.Drawing.Point(413, 196)
$chkDcrRandom.Size = New-Object System.Drawing.Size(94, 30)
$chkDcrRandom.FlatStyle = 'Flat'
$chkDcrRandom.FlatAppearance.BorderColor = $script:themeBorder
$chkDcrRandom.FlatAppearance.BorderSize = 1
$chkDcrRandom.UseVisualStyleBackColor = $false
$chkDcrRandom.BackColor = $script:themeControl
$chkDcrRandom.Visible = $false
$grpContentDetail.Controls.Add($chkDcrRandom)
$chkDcrRandom.Add_CheckedChanged({
    Update-CustomRandomToggleStyle -Toggle $chkDcrRandom
    if ($script:uiReady -and -not $script:crLoading) {
      Save-CustomRandomOrder -SectionName 'deepCustomRepeat' -Enabled ([bool]$chkDcrRandom.Checked)
    }
  })

$btnDcrAdd.Add_Click({
    $dcrStageValue = Get-DeepStageInternal -Display ([string]$cboDcrStage.SelectedItem)
    if (-not $dcrStageValue) { return }
    # 정규화: 공물 미사용이면 소진 대응도 false (던전 [추가] 정규화와 같은 원칙 -
    # 리스트 '—' 표기 ↔ 역해석 false 일치. 어긋나면 재저장 때 지문이 바뀌어 진행 기록이 날아감)
    $dcrCoinValue = [bool]$chkDcrTribute.Checked
    $dcrExhaustValue = [bool]($dcrCoinValue -and $rbDcrExhaustGo.Checked)
    # 추가 차단: 마지막 항목 → 새 항목 전환이 게임에서 불가능한 조합이면 팝업 안내
    # (던전 커스텀과 동일 규칙 - 심층도 같은 1층/2층 구역 지도 구조. 사용자 버튼 즉답
    # 팝업이라 무인 운용과 무관 - GUI 팝업 금지 규칙의 명시적 예외)
    $dcrExistingItems = @(Get-DeepCustomItemsFromList)
    if ($dcrExistingItems.Count -gt 0) {
      $dcrLastItem = $dcrExistingItems[$dcrExistingItems.Count - 1]
      $dcrNewItem = [pscustomobject]@{
        difficulty = '어려움'; stage = $dcrStageValue
        coin = $dcrCoinValue; doubleLoot = $false
        exhaustContinue = $dcrExhaustValue; noDoubleSweep = $false
      }
      $dcrPairIssues = @(Get-CustomTransitionIssues -Items @($dcrLastItem, $dcrNewItem) `
          -ListRepeat 'count' -ListRepeatCount 1)
      if ($dcrPairIssues.Count -gt 0) {
        $dcrBlockText = ("이 순서로는 추가할 수 없습니다.`n`n" +
          "마지막 항목 '{0}' 다음에 '{1}' 항목은 올 수 없습니다.`n{2}" -f `
            (Get-DeepCustomItemLabel -Item $dcrLastItem), (Get-DeepCustomItemLabel -Item $dcrNewItem), `
            [string]$dcrPairIssues[0].Reason)
        Add-GuiLog ('[안내] 심층 추가 차단: {0} → {1} - {2}' -f `
            (Get-DeepCustomItemLabel -Item $dcrLastItem), (Get-DeepCustomItemLabel -Item $dcrNewItem), `
            [string]$dcrPairIssues[0].Reason)
        [System.Windows.Forms.MessageBox]::Show($dcrBlockText, '심층 커스텀 반복 - 추가 불가',
          [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
      }
    }
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      Add-DeepCustomListRow -Stage $dcrStageValue -Coin $dcrCoinValue -ExhaustContinue $dcrExhaustValue
      Update-DeepCustomListNumbers
    } finally { $script:crLoading = $prevLoading }
    if ($script:uiReady) { Save-DeepCustomRepeatToConfig }
    # 전환 규칙 사전 경고 (최종 차단은 시작 게이트 - 던전 커스텀과 동일)
    $dcrAddRepeat = $(if ($rbDcrCount.Checked) { 'count' } else { 'infinite' })
    $dcrAddIssues = @(Get-CustomTransitionIssues -Items @(Get-DeepCustomItemsFromList) `
        -ListRepeat $dcrAddRepeat -ListRepeatCount ([int]$numDcrLaps.Value))
    foreach ($dcrAddIssue in $dcrAddIssues) {
      $dcrAddWrapTag = $(if ([bool]$dcrAddIssue.Wrap) { ' [바퀴 순환: 마지막 → 첫 항목]' } else { '' })
      Add-GuiLog ('[경고] {0} → {1}{2}: {3} - 이대로는 시작할 수 없습니다 (순서 조정 또는 뒤에 항목을 더 추가해 해소해 주세요).' -f `
          $dcrAddIssue.From, $dcrAddIssue.To, $dcrAddWrapTag, $dcrAddIssue.Reason)
    }
  })

$btnDcrDelete.Add_Click({
    $dcrCheckedRows = @()
    foreach ($dcrRow in $lvDcrList.Items) { if ($dcrRow.Checked) { $dcrCheckedRows += $dcrRow } }
    if ($dcrCheckedRows.Count -eq 0) {
      Add-GuiLog '[안내] 삭제할 항목의 앞 체크박스를 켠 뒤 [삭제(체크)]를 눌러 주세요. (첫 열 머리글 클릭 = 전체 선택/해제)'
      return
    }
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      foreach ($dcrRow in $dcrCheckedRows) { $lvDcrList.Items.Remove($dcrRow) }
      Update-DeepCustomListNumbers
    } finally { $script:crLoading = $prevLoading }
    if ($script:uiReady) { Save-DeepCustomRepeatToConfig }
  })

$btnDcrUp.Add_Click({ Move-DeepCustomListRow -Delta (-1) })
$btnDcrDown.Add_Click({ Move-DeepCustomListRow -Delta 1 })

# 하단 줄: 리스트 반복 (무한 / 횟수 N바퀴) + 공물 합계 + 진행 초기화
$pnlDcrRepeat = New-Object System.Windows.Forms.Panel
$pnlDcrRepeat.Location = New-Object System.Drawing.Point(15, 238)
$pnlDcrRepeat.Size = New-Object System.Drawing.Size(494, 28)
$pnlDcrRepeat.Visible = $false
$grpContentDetail.Controls.Add($pnlDcrRepeat)

$lblDcrRepeat = New-Object System.Windows.Forms.Label
$lblDcrRepeat.Text = '리스트 반복:'
$lblDcrRepeat.Location = New-Object System.Drawing.Point(0, 5)
$lblDcrRepeat.Size = New-Object System.Drawing.Size(80, 20)
$pnlDcrRepeat.Controls.Add($lblDcrRepeat)

$rbDcrInfinite = New-Object System.Windows.Forms.RadioButton
$rbDcrInfinite.Text = '무한'
$rbDcrInfinite.Location = New-Object System.Drawing.Point(85, 2)
$rbDcrInfinite.Size = New-Object System.Drawing.Size(55, 22)
$rbDcrInfinite.Checked = $true
$pnlDcrRepeat.Controls.Add($rbDcrInfinite)

$rbDcrCount = New-Object System.Windows.Forms.RadioButton
$rbDcrCount.Text = '횟수:'
$rbDcrCount.Location = New-Object System.Drawing.Point(145, 2)
$rbDcrCount.Size = New-Object System.Drawing.Size(60, 22)
$pnlDcrRepeat.Controls.Add($rbDcrCount)

$numDcrLaps = New-Object System.Windows.Forms.NumericUpDown
$numDcrLaps.Location = New-Object System.Drawing.Point(205, 0)
$numDcrLaps.Size = New-Object System.Drawing.Size(50, 24)
$numDcrLaps.Minimum = 1
$numDcrLaps.Maximum = 999
$numDcrLaps.Value = 1
$numDcrLaps.Enabled = $false   # '횟수' 라디오를 골랐을 때만 활성
$pnlDcrRepeat.Controls.Add($numDcrLaps)

$lblDcrLaps = New-Object System.Windows.Forms.Label
$lblDcrLaps.Text = '바퀴'
$lblDcrLaps.Location = New-Object System.Drawing.Point(258, 5)
$lblDcrLaps.Size = New-Object System.Drawing.Size(35, 20)
$pnlDcrRepeat.Controls.Add($lblDcrLaps)

# 리스트에 필요한 마족공물 합계 표시 (심층 소탕 = 어려움 1개 - 커스텀은 어려움 고정)
$lblDcrTributeTotal = New-Object System.Windows.Forms.Label
$lblDcrTributeTotal.Text = '바퀴당 마족공물 0개'
$lblDcrTributeTotal.Location = New-Object System.Drawing.Point(293, 5)
$lblDcrTributeTotal.Size = New-Object System.Drawing.Size(119, 20)
$lblDcrTributeTotal.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblDcrTributeTotal.AutoEllipsis = $true   # 위와 같은 이유 (2026-08-08)
$lblDcrTributeTotal.ForeColor = [System.Drawing.Color]::SteelBlue
$pnlDcrRepeat.Controls.Add($lblDcrTributeTotal)

$btnDcrReset = New-Object System.Windows.Forms.Button
$btnDcrReset.Text = '진행 초기화'
$btnDcrReset.Location = New-Object System.Drawing.Point(414, 0)
$btnDcrReset.Size = New-Object System.Drawing.Size(80, 26)
$pnlDcrRepeat.Controls.Add($btnDcrReset)

# 커스텀 설정 변경 = 즉시 저장 (던전 커스텀과 동일 패턴 - 로딩 중 가드)
$rbDcrCount.Add_CheckedChanged({
    $numDcrLaps.Enabled = $rbDcrCount.Checked
    if ($script:uiReady -and -not $script:crLoading) { Save-DeepCustomRepeatToConfig }
  })
$numDcrLaps.Add_ValueChanged({ if ($script:uiReady -and -not $script:crLoading) { Save-DeepCustomRepeatToConfig } })
$btnDcrReset.Add_Click({
    Reset-CustomProgress -SectionName 'deepCustomRepeat' `
      -LogMessage '[안내] 심층 커스텀 반복 진행 기록을 초기화했습니다 - 다음 시작은 리스트 처음(1바퀴째 1번)부터입니다.'
  })

# ============================================================
#  '생활(채집) + 커스텀 반복' 목록/설정 화면 (v2.0.0 - 2026-08-08 시안 확정)
#  입력은 위쪽 생활 슬라이더(채집 스킬/대상)를 그대로 씁니다 - 커스텀에서는 슬라이더가
#  '담을 항목 고르기'용이 되고, 실제 실행 순서는 아래 리스트가 결정합니다.
#  던전 커스텀과 다른 점: **항목마다 반복 횟수**가 있고, 층 전환 규칙·완료 마커가 없습니다
#  (생활 사이클은 종료 코드 0 하나로 완료가 확정돼 마무리 복구 개념이 없습니다).
# ============================================================
# 반복 횟수 줄: 슬라이더 아래 독립 줄 (담기 전에 정하고 [추가] - 전투 커스텀과 같은 흐름)
$pnlLcrInput = New-Object System.Windows.Forms.Panel
$pnlLcrInput.Location = New-Object System.Drawing.Point(15, 150)
$pnlLcrInput.Size = New-Object System.Drawing.Size(494, 26)
$pnlLcrInput.Visible = $false
$grpContentDetail.Controls.Add($pnlLcrInput)

$lblLcrCount = New-Object System.Windows.Forms.Label
$lblLcrCount.Text = '반복 횟수'
$lblLcrCount.Location = New-Object System.Drawing.Point(0, 5)
$lblLcrCount.Size = New-Object System.Drawing.Size(62, 20)
$pnlLcrInput.Controls.Add($lblLcrCount)

$numLcrCount = New-Object System.Windows.Forms.NumericUpDown
$numLcrCount.Location = New-Object System.Drawing.Point(66, 1)
$numLcrCount.Size = New-Object System.Drawing.Size(50, 24)
$numLcrCount.Minimum = 1
$numLcrCount.Maximum = 99
$numLcrCount.Value = 1
$pnlLcrInput.Controls.Add($numLcrCount)

$lblLcrCountUnit = New-Object System.Windows.Forms.Label
$lblLcrCountUnit.Text = '회  — 위에서 고른 스킬·대상을 이 횟수로 담습니다'
$lblLcrCountUnit.Location = New-Object System.Drawing.Point(120, 5)
$lblLcrCountUnit.Size = New-Object System.Drawing.Size(374, 20)
$lblLcrCountUnit.ForeColor = $script:themeMuted
$pnlLcrInput.Controls.Add($lblLcrCountUnit)

# 리스트 (표 형태): 체크 / # / 스킬 / 대상 / 횟수 - 치수는 전투 커스텀과 동일 (392x174)
$lvLcrList = New-Object System.Windows.Forms.ListView
$lvLcrList.Location = New-Object System.Drawing.Point(15, 180)
$lvLcrList.Size = New-Object System.Drawing.Size(392, 174)
$lvLcrList.View = [System.Windows.Forms.View]::Details
$lvLcrList.GridLines = $true
$lvLcrList.CheckBoxes = $true
$lvLcrList.FullRowSelect = $true
$lvLcrList.MultiSelect = $false
$lvLcrList.HideSelection = $false
$lvLcrList.Visible = $false
[void]$lvLcrList.Columns.Add('', 28)
[void]$lvLcrList.Columns.Add('#', 32)
[void]$lvLcrList.Columns.Add('스킬', 96)
[void]$lvLcrList.Columns.Add('대상', 148)
[void]$lvLcrList.Columns.Add('횟수', 46)
$grpContentDetail.Controls.Add($lvLcrList)
$lvLcrList.Add_MouseUp($cellEditMouseUp)   # 셀 편집 - 생성 직후 연결 (전투 3리스트와 공용 핸들러)

# 0번(체크) 열 머리글 클릭 = 전체 선택/해제 (기존 세 커스텀 리스트와 같은 계약)
$lvLcrList.Add_ColumnClick({
    param($lcrClickSender, $lcrClickArgs)
    if ($script:running) { return }   # 실행 중 전체 토글 금지
    if ($lcrClickArgs.Column -ne 0 -or $lvLcrList.Items.Count -eq 0) { return }
    $lcrAllChecked = $true
    foreach ($lcrRow in $lvLcrList.Items) { if (-not $lcrRow.Checked) { $lcrAllChecked = $false; break } }
    $lcrNewState = -not $lcrAllChecked
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try { foreach ($lcrRow in $lvLcrList.Items) { $lcrRow.Checked = $lcrNewState } }
    finally { $script:crLoading = $prevLoading }
  })
$lvLcrList.Add_ItemCheck({
    param($lcrCheckSender, $lcrCheckArgs)
    if ($script:running) { $lcrCheckArgs.NewValue = $lcrCheckArgs.CurrentValue }   # 실행 중 체크 토글 금지
  })

$btnLcrAdd = New-Object System.Windows.Forms.Button
$btnLcrAdd.Text = '추가'
$btnLcrAdd.Location = New-Object System.Drawing.Point(413, 180)
$btnLcrAdd.Size = New-Object System.Drawing.Size(94, 30)
$btnLcrAdd.Visible = $false
$grpContentDetail.Controls.Add($btnLcrAdd)

$btnLcrDelete = New-Object System.Windows.Forms.Button
$btnLcrDelete.Text = '삭제(체크)'
$btnLcrDelete.Location = New-Object System.Drawing.Point(413, 216)
$btnLcrDelete.Size = New-Object System.Drawing.Size(94, 30)
$btnLcrDelete.Visible = $false
$grpContentDetail.Controls.Add($btnLcrDelete)

$btnLcrUp = New-Object System.Windows.Forms.Button
$btnLcrUp.Text = '↑ 위로'
$btnLcrUp.Location = New-Object System.Drawing.Point(413, 252)
$btnLcrUp.Size = New-Object System.Drawing.Size(94, 30)
$btnLcrUp.Visible = $false
$grpContentDetail.Controls.Add($btnLcrUp)

$btnLcrDown = New-Object System.Windows.Forms.Button
$btnLcrDown.Text = '↓ 아래로'
$btnLcrDown.Location = New-Object System.Drawing.Point(413, 288)
$btnLcrDown.Size = New-Object System.Drawing.Size(94, 30)
$btnLcrDown.Visible = $false
$grpContentDetail.Controls.Add($btnLcrDown)

# 랜덤 진행 토글 (생활은 층 혼합 개념이 없어 항상 사용 가능 - 잠금 게이트 없음)
$chkLcrRandom = New-Object System.Windows.Forms.CheckBox
$chkLcrRandom.Appearance = 'Button'
$chkLcrRandom.Text = '랜덤'
$chkLcrRandom.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$chkLcrRandom.Location = New-Object System.Drawing.Point(413, 324)
$chkLcrRandom.Size = New-Object System.Drawing.Size(94, 30)
$chkLcrRandom.FlatStyle = 'Flat'
$chkLcrRandom.FlatAppearance.BorderColor = $script:themeBorder
$chkLcrRandom.FlatAppearance.BorderSize = 1
$chkLcrRandom.UseVisualStyleBackColor = $false
$chkLcrRandom.BackColor = $script:themeControl
$chkLcrRandom.Visible = $false
$grpContentDetail.Controls.Add($chkLcrRandom)
$chkLcrRandom.Add_CheckedChanged({
    Update-CustomRandomToggleStyle -Toggle $chkLcrRandom
    if ($script:uiReady -and -not $script:crLoading) {
      Save-CustomRandomOrder -SectionName 'lifeCustomRepeat' -Enabled ([bool]$chkLcrRandom.Checked)
    }
  })

$btnLcrAdd.Add_Click({
    # 담을 항목은 위쪽 슬라이더의 현재 선택입니다 (가공 화면에서는 이 버튼이 보이지 않음)
    $lcrSkill = $script:lifeSkills[$script:lifeSkillIndex]
    $lcrTargets = @($lcrSkill.Targets)
    if ($script:lifeTargetIndex -ge $lcrTargets.Count) { return }
    $lcrTargetName = [string]$lcrTargets[$script:lifeTargetIndex]
    if ([string]::IsNullOrWhiteSpace($lcrTargetName)) { return }
    # 미지원 스킬(낚시)은 담기 자체를 막습니다 - 리스트에 들어가면 그 항목 차례에 반드시
    # 멈추므로 담는 시점에 알려 주는 편이 낫습니다. 사용자가 [추가]를 누른 직후에만 뜰 수
    # 있는 즉답 팝업이라 무인 운용을 막지 않습니다 (GUI 팝업 금지 규칙의 명시적 예외)
    if ($script:lifeSupportedSkillIds -notcontains [string]$lcrSkill.Id) {
      $lcrBlockText = ("'{0}'은(는) 아직 지원하지 않습니다.`n`n" -f [string]$lcrSkill.Name) +
        '지원하는 채집 스킬로만 리스트를 구성해 주세요.'
      Add-GuiLog ("[안내] 생활 커스텀 추가 차단: '{0}'은(는) 아직 지원하지 않습니다." -f [string]$lcrSkill.Name)
      [System.Windows.Forms.MessageBox]::Show($lcrBlockText, '생활 커스텀 반복 - 추가 불가',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
      return
    }
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      Add-LifeCustomListRow -Skill ([string]$lcrSkill.Id) -Target $lcrTargetName -Count ([int]$numLcrCount.Value)
      Update-LifeCustomListNumbers
    } finally { $script:crLoading = $prevLoading }
    if ($script:uiReady) { Save-LifeCustomRepeatToConfig }
  })

$btnLcrDelete.Add_Click({
    $lcrCheckedRows = @()
    foreach ($lcrRow in $lvLcrList.Items) { if ($lcrRow.Checked) { $lcrCheckedRows += $lcrRow } }
    if ($lcrCheckedRows.Count -eq 0) {
      Add-GuiLog '[안내] 삭제할 항목의 앞 체크박스를 켠 뒤 [삭제(체크)]를 눌러 주세요. (첫 열 머리글 클릭 = 전체 선택/해제)'
      return
    }
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      foreach ($lcrRow in $lcrCheckedRows) { $lvLcrList.Items.Remove($lcrRow) }
      Update-LifeCustomListNumbers
    } finally { $script:crLoading = $prevLoading }
    if ($script:uiReady) { Save-LifeCustomRepeatToConfig }
  })

$btnLcrUp.Add_Click({ Move-LifeCustomListRow -Delta (-1) })
$btnLcrDown.Add_Click({ Move-LifeCustomListRow -Delta 1 })

# 하단 줄: 리스트 반복 (무한 / 횟수 N바퀴) + 채집 횟수 합계 + 진행 초기화
$pnlLcrRepeat = New-Object System.Windows.Forms.Panel
$pnlLcrRepeat.Location = New-Object System.Drawing.Point(15, 360)
$pnlLcrRepeat.Size = New-Object System.Drawing.Size(494, 28)
$pnlLcrRepeat.Visible = $false
$grpContentDetail.Controls.Add($pnlLcrRepeat)

$lblLcrRepeat = New-Object System.Windows.Forms.Label
$lblLcrRepeat.Text = '리스트 반복:'
$lblLcrRepeat.Location = New-Object System.Drawing.Point(0, 5)
$lblLcrRepeat.Size = New-Object System.Drawing.Size(80, 20)
$pnlLcrRepeat.Controls.Add($lblLcrRepeat)

$rbLcrInfinite = New-Object System.Windows.Forms.RadioButton
$rbLcrInfinite.Text = '무한'
$rbLcrInfinite.Location = New-Object System.Drawing.Point(85, 2)
$rbLcrInfinite.Size = New-Object System.Drawing.Size(55, 22)
$rbLcrInfinite.Checked = $true
$pnlLcrRepeat.Controls.Add($rbLcrInfinite)

$rbLcrCount = New-Object System.Windows.Forms.RadioButton
$rbLcrCount.Text = '횟수:'
$rbLcrCount.Location = New-Object System.Drawing.Point(145, 2)
$rbLcrCount.Size = New-Object System.Drawing.Size(60, 22)
$pnlLcrRepeat.Controls.Add($rbLcrCount)

$numLcrLaps = New-Object System.Windows.Forms.NumericUpDown
$numLcrLaps.Location = New-Object System.Drawing.Point(205, 0)
$numLcrLaps.Size = New-Object System.Drawing.Size(50, 24)
$numLcrLaps.Minimum = 1
$numLcrLaps.Maximum = 999
$numLcrLaps.Value = 1
$numLcrLaps.Enabled = $false   # '횟수' 라디오를 골랐을 때만 활성
$pnlLcrRepeat.Controls.Add($numLcrLaps)

$lblLcrLaps = New-Object System.Windows.Forms.Label
$lblLcrLaps.Text = '바퀴'
$lblLcrLaps.Location = New-Object System.Drawing.Point(258, 5)
$lblLcrLaps.Size = New-Object System.Drawing.Size(35, 20)
$pnlLcrRepeat.Controls.Add($lblLcrLaps)

# 리스트 1바퀴에 실제로 도는 채집 횟수 (항목 횟수의 합 - 은동전 합계 자리를 그대로 씁니다)
$lblLcrCycleTotal = New-Object System.Windows.Forms.Label
$lblLcrCycleTotal.Text = '바퀴당 0회'
$lblLcrCycleTotal.Location = New-Object System.Drawing.Point(293, 5)
$lblLcrCycleTotal.Size = New-Object System.Drawing.Size(119, 20)
$lblLcrCycleTotal.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
# WinForms Label 은 폭을 넘기면 **줄바꿈**이 기본이라, 높이 20 짜리 한 줄 라벨에서는 둘째
# 줄이 잘려 글자가 겹쳐 보입니다 (2026-08-08 실기 제보). AutoEllipsis 를 켜면 넘쳐도
# 한 줄 + '…' 로 끝나 이 깨짐이 원천 차단됩니다 (렌더링 실측 확인).
$lblLcrCycleTotal.AutoEllipsis = $true
$lblLcrCycleTotal.ForeColor = [System.Drawing.Color]::SteelBlue
$pnlLcrRepeat.Controls.Add($lblLcrCycleTotal)

$btnLcrReset = New-Object System.Windows.Forms.Button
$btnLcrReset.Text = '진행 초기화'
$btnLcrReset.Location = New-Object System.Drawing.Point(414, 0)
$btnLcrReset.Size = New-Object System.Drawing.Size(80, 26)
$pnlLcrRepeat.Controls.Add($btnLcrReset)

# 커스텀 설정 변경 = 즉시 저장 (기존 세 커스텀과 동일 패턴 - 로딩 중 가드)
$rbLcrCount.Add_CheckedChanged({
    $numLcrLaps.Enabled = $rbLcrCount.Checked
    if ($script:uiReady -and -not $script:crLoading) { Save-LifeCustomRepeatToConfig }
  })
$numLcrLaps.Add_ValueChanged({ if ($script:uiReady -and -not $script:crLoading) { Save-LifeCustomRepeatToConfig } })
$btnLcrReset.Add_Click({
    Reset-CustomProgress -SectionName 'lifeCustomRepeat' `
      -LogMessage '[안내] 생활 커스텀 반복 진행 기록을 초기화했습니다 - 다음 시작은 리스트 처음(1바퀴째 1번)부터입니다.'
  })

# ============================================================
#  생활 카테고리 UI (v2.0.0 - 2026-08-05 시안 확정. 워커는 낚시 외 채집 8종 지원 - 2026-08-07)
# ============================================================
# 채집 스킬 9종 + 스킬별 채집 대상 (나무위키 '마비노기 모바일/생활 스킬' 실측 데이터.
# Id 는 config 저장용 안정 식별자, Name 은 표시명. 대상은 게임 용어 그대로 저장 - 설계 합의)
$script:lifeSkills = @(
  @{ Id = 'daily';   Name = '일상 채집'; Targets = @('둥지', '거미줄', '물', '우물', '젖소', '사과 나무', '차나무', '거미줄 뭉치', '헤이즐넛', '얽힌 거미줄') }
  @{ Id = 'wood';    Name = '나무 베기'; Targets = @('나무', '뾰족 나무', '굵은 나무', '쓸 만한 나무', '갑옷 나무', '어스름 나무', '벼락 나무', '흰 껍질 나무') }
  @{ Id = 'mining';  Name = '광석 캐기'; Targets = @('광맥', '철 광맥', '얼음', '석탄 광맥', '동 광맥', '백동 광맥', '은 광맥', '운철 광맥', '백금 광맥') }
  @{ Id = 'herb';    Name = '약초 채집'; Targets = @('허브', '블러디 허브', '화살꽃', '마나 허브', '새록 버섯', '튼튼 버섯', '끈기 풀', '쑥쑥 버섯', '숨숨꽃', '깔끔 버섯', '생채기꽃', '증폭 버섯', '진정초', '끈적 풀', '솔솔 버섯', '산뜻 버섯') }
  @{ Id = 'wool';    Name = '양털 깎기'; Targets = @('양', '곱슬 양', '먹구름 양', '구름털 양', '복슬 양') }
  @{ Id = 'harvest'; Name = '추수';      Targets = @('밀', '옥수수', '콩', '쌀', '귀리') }
  @{ Id = 'hoe';     Name = '호미질';    Targets = @('감자', '양파', '조개', '파스닙', '양배추', '호박', '개암 버섯') }
  @{ Id = 'insect';  Name = '곤충 채집'; Targets = @('빛 무리', '설원 빛 무리', '곤충 무리', '고요한 빛 무리', '따스한 빛 무리', '차가운 빛 무리', '삭막한 곤충 무리', '황폐한 곤충 무리', '일렁이는 빛 무리') }
  @{ Id = 'fishing'; Name = '낚시';      Targets = @('작은 낚시터', '남쪽 성벽 낚시터', '동쪽 성벽 낚시터', '동쪽 호수 낚시터', '해변 낚시터', '옛 낚시터', '하구 낚시터', '서쪽 호수 낚시터', '산속 낚시터', '미지의 낚시터') }
)
# 채집 스킬 아이콘 (게임 화면 캡처 원본 104px → 24px 축소, PNG base64 내장.
# 원본: 던전이미지\생활\*.png - exe 는 이미지 파일을 추출하지 않으므로 스크립트에 내장.
# 채집 대상 아이콘은 캡처 수급 후 같은 방식으로 추가 예정 - 지금은 글자 카드)
$script:lifeSkillIconB64 = @{
  daily = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAQvSURBVEhLjVVNbFRVFL7tzHSm8/fOuT/vZ/oTWkit2I0x1KYRN2KkqW5QsVo1IUZTUYQYQuKCPxOILkBBN001xrSEykIoQReNoXEnNlLcmf6xQigbCrigJviZ+2Y6dN5U7JeczLx77/m+c8875zwh/gfZbKCZ/a2Kg32aC18oVRhSqnBcy+ADw01PCdFYH/VZE/L5/HpmfZIpWFBcgJENcFUjXPPAjCpAycI0kflISpmPcvwnpDTvM+vbSnpg9iEpgJJ+xDxo5cHoBrimAK39P5j9nihXFDVK6W+NLhKEArRSoLi2mmlZgFY+FJu9UdIyFLtfK+WD2a0wyW4VYYWxB8n2vw+tAih2B6LcgvL0ro2A2aZlbQJ2vT6VQyxWh2RdOny2HJrd+zIvO8vknCo0EZm/lKomX02AySARr0ddIo3u7s0YHBzE4UOHkbIijoErAxjyLgshYqGA4/gnpLR5riZfKUCOQaw2iXR9Fs/3voCzZ8ewtPQ3lvHO2wOI1SRh2IOnAjDr7cKWF7O5KcOKiZKX1koRZzOEl196FRcvTpRJV+L69QW0trQhn5VhqpjVuJDSfbaa3D7bHPtIJrOIx5LY+lwvJiZ+jnJW4Y3Xd4TB2BKWrO8KZrNPykjlkA8mD0LE0d7egZGRU1GeKkz+Oon3du5CU2MLyNGlHvEhmN0vKwXsS/QQj6fQ3/8mbty4GeWqwp07d9HSsgFCiBK5Dy09GBVAEJmhlQKSAwhRh23bXiwTXJn6HXt2f4ienl68sr0Po6PfVQgMDg4hHqurqDTNHowM7A3M8ZUC9SmC7zVhfn4+dB4ePoVDBz9GW1t7GKE1x2HMzxX3p6dn0NDQhGzWqeoTo/zwBruWBYhMGP1XQ9+EzmNj5zF6+kxYjgMDO5FIJEGORC7r4NKlyfDM/v0HQ1GtVmlGKyBz3pPMJhRIJFLo63stdJyZnsWxY5/h2rU/ce7ceRw4cAhC1CCfIwR+A+bnruL+/X/Q1dWNVDK9qoAtfyHEEwkiNWMFbMsPD49g8dYijh75BIu3bmN8/CdMTV3Bjh1vobY2jkw6h/ZHNoZBzM7O2WYCOao46CLRE5nTpU7mvVIaOI7CunXrw5wePfIp7t1bwonPT2J6ehatrRvC1NgUKWlw+bcp/HDhx7Dm7bALh1zFDQyIaHMo4HlehkheldJFLicRj9ejo+NxdHZ2Y+OjHdi0qQuZTD4cJdbsC21ubkF7+2PhecUBtB01/OA7way+Lw+74i2cLUS6WKrSQyZDSKVy5d+V3b68n0475XU7r5b3mM2ClLKhQqAoIvcUD0RHx9qsJHaPSD8d5S6DSO9mO8+r5tPDrVTqNvItUc4qMJtuIvcXJYNlx1WslJrSiCdpzjAHzVGuh6GW8m4/kzdO5N6xNyqaX0qFByK9QI467TjuM1HnZfwLbuEEPn8bWPEAAAAASUVORK5CYII='
  wood = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAQbSURBVEhLlZVNbFRVFMfvfHU+OvPePefe9zGlQ0HUhS6kkkoKbaMWVIgJcYMxdaUxsRFRoK0QSEjjnkRFN0Sr0ko0WPdEWaIrQaPG2pAay6asoB/YpDZ/c+9jhr7XqR//5GQy7+P3v/ecc88T4l9ULj+oicJnlApGFPnvKQ7OKQrOMAeHiao9QrQXk+/8JzmOs41c/S7JcE5xGzxVjYVWVSj2QOT9JmVwgpmdJGNDScmHpFS3FfsGACYfigP7S2tCKQ9aBfB0FczBr0ThviQrqRSR+kSpIAba0ICDRmgV2lDkDSWhDZHyPlQqjEHqoEqZkBI5lIplKGWueTGDKIxJFYr8V5NsIaUaZG1yGoczBygWK9h23wMYHX0bvT19yOXy0KqZQd0kWGXmxxrwNqKaZLVISq8zyOfL2Lp1G6ampmA0PT0N36+iVCo3gdfTVTW1+14IkbEGitQ7WgcgFRWUKapBS0srhBA4efKUhdc1fn4CmUwO0tV3n29eE8fRB4VpL8X6pukGkgrpVAuEyNrfhx96xMKa6eWXXkFKZCzMpHH9Lkwt9SXB7O81cNdR2NJxP04cP4Xh4bcs+Nat20luQ/PzC9jxaBdyueK61VsD23V6QSjyRkzOivkydnX3JjlrtBr7t7CwgO7u3RAiBSm9Jrvw7RkRTP5ZrdrgVAi19g7Mzt6IgZK6ePFLjH30MZ4/+ALeP/sBjh4ZQjqVa2IQpUkwh+e02mQdU6kMxsbGksyGxscnbNFNnP903F5b/nMZPbv7kM0UYM5Q3KAKoah6RrMxCFEstGL79k67/aTuLN1BZ+cOZLMF27r9T+7F4uKivffzT78gCGsoliVYh9aofrIFc/B6NLiMY2C3Ozj4WpKPH679iErZgeOwLarJ/bGjxxr3Jz77HKlMHg5pa2LHBocQFeadsZNLPrLpAkaGj2NlZaUBuHLlW+TzrZAyOoyuq5DL5jE5+VXjmUOHj0CIjF2oVoanbppzlpOSp4k0SJrcVUFugHQ6hyce78c3X1+2L8/M/A6SHhxH3V1MgEKhhM21Lbh+fcY+s7S0hJ6ePhTyJWjtQ0q+YE+y66oh0wVRP0fBrK2JGQn79z+LgYEX7epNS96bU+aZLJ5+ah9WVv6yJlevXoPSPhxJkFL2WoMgCFqJvJmo1eqT0n5M4LqETKbFmtldxmaVGRUaQqRx+vSoNZj94wZqtQ4USq2TjWFnxC7viXaxFhL/LjQL0xxmJpXLEgcOPIeurp2oVNw55vZNMQNrwvpNtiv/fwYmSGpksy3me7EchmFfkt2QlPwGkVo1+V2fkvVRN/B0aGoyx8x7ksx1IqJdUurvTB9Hadt4J1HdTM/7XxBVNydZ/6S0dPwBkt4lkv68AUVxz1RKPSdd74Lrqv7ky3X9DT3tIQ2iTIRVAAAAAElFTkSuQmCC'
  mining = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAASRSURBVEhLjVVtiFRVGL7unTs733PPOe85556ZVWnNKCl0WSrzo9hSc/1ASfFPP1OzsFVw0QL7YagEG4aZIshakrnqj0CEAkmUhIisfiRGtILu/tNsoy9ZbPWJc+/cO7OzWj3wMnPv3Pd53vd5z33Hcf4DhcJDxGSwWAi9lUSwT4rgkBRmD5HpkczMa2tryzbn/C9IKacJCt5j3FznVAGpCjRVoVU9JGkIEfzEuX6Dc15q5rgvpNQbpdS/SRmAKLAkkGTuERpKGmhtoFTwIxF1N3M1YxIJdUTJSpgoKQCJKCaSN0YApWyOLUb2NpMmECLot+QxIQmDfK4Mv0yQDUKcqfB+2svAddNwWzykUml4qVZwRrabDc3cjhDylcjXemXMl+jqWoAZjzwGL5VFNlMISWx3c+fMx7q167Fz524c2H8Q/f2H0df3Djo6HodfFnc4508k5JVKZTKR+tNWH5NnWgtYvXoNrl27hp6eTfjg8IfYvv1N7Nq1C5cufY+xsTE0YnhoGKdOncbcuc+gXBS24+8cx3FDASnV3kBXw8oi/ysoFTlmzuxAX18fBgcHx5HFuHLlCnbseAuzZ88B8wU8L4tyiZJTxhitcTh/sERkbiiKqo8FspkilnQvxejoaDMvhoaGsW3b66hWJyOV8pDPl8B8BVnjsKfPDpyEPOMoZRY2WmO/W/WUm8Hy5SswNvb3OPLbt29j4fOL4TgOGBdQKsqJ8usC9mQJof5wpDBbG4cb29P+wHRcvvzDOPIYXQsXwXE9SF3PaSyy3oWBQ2TebxQQXCPtZXF84ERC+PnZc7h6dQhDw8N4ae06bN7Si+kPz0AuX4IQOjzOSfUNoWQVjt0tjQJpL4eVK1Yl5Ec+OopMrogZj85C99LlOHvuXHj/2MBxpNx0OFwSumbLPQXMnljAVm/tuXDhy5Dk0OF+eJkc8kUfrteKqe3t+PnmzUR8/csb4DgtIFKQUt9HgJvXYgF7cp7tWhQmn/7sU2SKRRR8AWFXgFJIpdNY+cIq3Ll7N3xmZORXdMzqRCaTs2/vBAEbjubVJ+MLz81g/4GD+GVkBFPbp4XWCFkBpwCcdPg5yW3Fu3v3JV2cP/8FSkUfJZ9DhM8FoNr7RMLccDo7Oz0hgkGyHWRLODZwAq9u7MEk14OQBtzuHpsoAgiqouRL+Ezi64vfJCK7d78Np8WrFRIJhK6IYCDeQ72kAjDSMG1T4HMCJwUhbdVR5TasVaQMUuksnpo3D7du/RUK2HdjSfey0OJwIdojquyqp/mhgNY6z0he5cqgWGbwuYx8l3VrIgFTu6/htLjY0tubdPHx0QG4La2hgF3dRPKTZNlZlDlfwBq8rvteuxYmitpvZUbIFUrhzC5e/BZLl61EJleKZiaC65zz6jiBSERtDqsOvY9FmkXr3ZSZRDZfhs8UcgU//FvlFIz6RE83cyfgpDZxCu5EA47JVS3Gi9hgQodCteevc64WNHNOAGNyjhDmK5JttcSJHcRdWEvsTIRUJ5lhU5q5/g0tvm9eZKTPMAp+T8iUJTTg1krrtQgGhBDPNSfH+AevNAVav6YlcwAAAABJRU5ErkJggg=='
  herb = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAATxSURBVEhLjVVbbBRVGB4Q2m13Ozsz5zZntosKKwKtRRLjrYBWqRY0mpCG0hJeFQOID1xiMPAATYgPJNJCuGgISRXRRIJNSVwfQNKWKpY09UbbB4OJlAUMUSuFBvjMf4YdYKmXLznZOTs53/f/3/+ffyzrP6C15r4orxNCr5c8aBEi2CdEsJ1z/aZ29dxyq7yk8Mz/grDT0yRP7/Blec5X5RhvCaHhMn/Qc9TbnufZhRz/CKXUKimD37U/xRApmYIUwT2LCw0ug1vv9Rnu+gsLuQoxQUp9IE9658qTCq4Ri8VRUhI3z8yViBUnkIi7EDwAY2JtIWkEIfQH2k/fRUxiTpIbkrKEa/aNjU1YvHgxEgkbzBN4+aVXMLd6PhyHQQofjMkVhdyWEP4b40XuOgKzZlWhqWk5MpkZePGFRcijvr4ee/fsM8/nh3OYPn0GnCSjzG4opR6PyIMgSEupRwrJOfONDT093xiS4eFhbNz4Di5evGj2hw8fMcSEa9fGUFFRBbvMgxIpCOaftizrPiMgpf+e1vdGT9akgvuROx+SEHpP9+Lo0aPmub//e/z4w0/o6+vDpk2bMXHiJBOQFCkolYLr8iVWJuPZQgQXwkLeFiG/mSdhWROwbt2GSGB0dBRtbW24fv262Q+cGUB3dzc6OjqwdGkTkrZHHQUpTcGzlpS61lfUIaRMvyH56lVr0NPzNT5s+whTp2bQ0NCIoaEhQ5rNZnH58mWMjY0hl7ud3c0bNzHn0cfMeeLyPPUndc56309BSt8s8p0zhYGBwehgf/93sG0Htp3Ehg3ro/9HRkbQ3t6O1tZWnDp1Cpcu/YaZMypNHcgqzjQsyXUrdU+Ylm+US0tsfHzwUEREWLlyFYqKipH9Iovjx7/C2bO/RO+o6M1bm1FR8QicJFlE9yUAZwEsmi2+St+ySBv/kzY3kVBUefR+24uurm6cONEJy7LQsKQxekc49+t5eC6nwkYX0mQghN4eZhDeVBKgPaUZBGlzoY4c+Twi2rlzF556stp0TF3dIpMNddn+/QfgeRycq5DcC+22hFCrfRWOAiXLwTyFeGnS2EQdVPPscxgcHDT+XvnrSiSUzX6JTGY6iotK8FDmYbgOoxsMKfWt6H0wz4elvNQT1FKm6o5EZUUVli1bjvr6BrTsaA3TPzeM2bPnYMuW5kiA0N7egeLiEthljmlpIg6XAmcSrssu0D2bzLkeyo+FysoqbNv2Ljo7uzA6ehXHjh3H7t17je/UBCdP9kQCXZ3dSMQdQ5gvbBi9NMtx2MH8HFpLN5m8Z0wYMor40KFPUVqaQEvLTsycWYFYrBQPPjANW7c2Y++e91FTUwu7jAacNt8GKmpojTDLcZx5RkApFRfC/5kEPDcsUmvrLvT19SNWXILa2jrMq65BMsmQTHoomhzD5EmlKEt4UDINSWPbI1tCAcqIufyzaNiF8yhYQEUui3tYWPcqmpu34fXXVmBu9TOm6FJSp6Xu8Dm/qN/DjglFaFz7Oc/zUncJEDjXb5GI4CnEikuRiNugrxrzQqLxBcKo7xC5yh1/fiF3BM7lGiH8G0qFs4luIxFLSYUcn5giF4xsosjlgkLOeyCEeFqKoMeXU0KPSYCKyMPvgyEn3/O/RkR+4rp6SiHXv2DzRMb0MsGDrOD6j9ttGLaiJzQc5uccTx5MJuXzhafz+Buq9FDwlVLWVAAAAABJRU5ErkJggg=='
  wool = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAASBSURBVEhLjZRriFVVFMe33jv3zLmPc/bae5/nvT7ogQjVCKWBWEqNppkiiiaZlohQpGkpUxEFWcE0laAOQZof+uQjnTQw8tEXibQcB5JemBFlhqP4mEfiBDP/2PvOvTpnpsk/LM77/9trn7UWY/+jfD5SROFM6QUNpMItQsbbSMYbhYieJy+aUmIlO/nNLclxnNuJ1GbOi+1CFiG9GNIrDQxVhJDxaeFFrwghnKTHf0qIaBWXQQfJCCRikNDHwSFkbCDKL4JU8DNROCvpldQIJYOPPa8EKq8OtTbHyHQOLg+HBJQjglQxhApB0lufNK2KZLhdb0XFwLIcLH1qBVatfgHpmhxyeWkMk6BqyAhC6aP/TNKbcS6fVTeZ62Asgw1vNUJr64fb4bgKVq07PESYjHodISZVzamWRnHudQsZmJdcWQ6WtjF/wWID0Dpy+EuUSrchYznDQnRREAVtjC1MlQFuuEnon9kPqEAytoO6CRNx7dr1KuSbb1sRFcfAsgrDQqQsgZxgEdPlRTy4YF6mCLblIpPOI20VkM5kYVl5nDzZVgVoHfziCFxHIpsTg4xvZBGBuHdIl+R0s2IKoVQRD017BLMfnYeZs+Zg8pSpGDN6LBob3xkA0Nq18xOwERZcHvRnMjAboYP8LkYyahCqCMf1IVWE48dOVE16+/rQ0dGBxsYm/PH72er9lpYWnD37J157/Q0wVgOSYbl6BgBCKBmCEYXN1e2xOe64czxaE1uit6i5+QNz3tfXh/nzF2DPnhZzPWPGbKRSFpTSppW+6O8NGYNxHm4TFIN4CE4hUjU2/LCIT/ftHwBpanofJ1tvgC9evITOzi6cPn0GYRDDKQgI3WxVgI4iGPFoYwVAej9FADvrIGvnsXbNi7hy5aoxPHfuL6xf14Cenn9w6tT3qK+fgen1M82zrVs/AmMMeQ1JAgSPVt8MIPINhLsSjKVQV3cfdu/aa4xOnGjFkieWYt26BixauNiYNr37nnm2bNly2FnXjJb+IWg6mxUKwf3G2AASQQGsTB416SwWP/4kfvzhJ5w/346e6z2YM3eeAVh2Dl8fO24gbW3fYULdROSyLpQuU/IvMMbureGu/4ugIQA8hOjPbASzwLnCmxveRmdnJy5dvoznVq9BbTaHUWPGYsWKleju6sJn+w8gna6FFPpbb4fpZNeV63VZJc0rAEkRJIXI58ls29133YOWvfvMqjdtbjaZ6Dhw4HOcOfMrCnmum0wv6AEDCIIgR+T9NlQWNwOkCEzUWnljePDgYVy92oFx48ZjzmNz0dvbiy1bmpFKZbR5S3XYaQlX1OufmwQMCtKFECCdtjFt6nR0d//dX7jA0aNfoRiPQjZbaBdCFAcADET4a8tbpefIEOaJ0ANv0qTJePmlV7H86ZXwVIys7VxXSj2Y9K6Kc38NUdgr6BYg5MO2C2Zc1KRyegC2+yKuT3oOEpE3mXP/uO6Pco8MBdP3dGOWzwUPdxPR6KTXcBrJeWkJ8fAQ52GnzqgCNNlRBO767dz1d7iu/3Dy44r+BYXUEafdhEUlAAAAAElFTkSuQmCC'
  harvest = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAASCSURBVEhLjZVNaB1VFMcnycvL+5g3c7/vfL0WtEqTaCwotYbYUJuksbiRil24Km4U/KiaBoMbsYi7gp+gNUIRLGhbWhdaU2sVlFpsGl2oMS4srpKuWhPJF/Uv9755j5epUQ8c5r2Zuf/fPeeec8Zx/sNcNxRUJsNchqNcRK9zGR/mMjokRPyUDKt9TpIUs2v+l3le9WbON77GRDInVAKhjVchdbVxVaoKJZMZKeMxxpiX1VjXGNNPUBFeE6oKIRNwGUHIGFLUXIgYXNauSibQwQZIlUwLEdyf1cpai+DqiJQhqApBpQbjIZiIIEQCyROoFGIAdZcqgTIRabuZkaxowzhV40JGYCJIPQShAYolilzeRaHggREFKSJIEa6B1EE6qIKr4LGstkMIf5w3hGue73BRrjBs3daHB/fsxeDgbgQ6QanoQadpywLM2UidXGdMb22IUxpVCQsWSJN4a66A/h07cebzs1hcWkLdJiensGtoN9pzRXs2NwBMuoIqpAovOY7TVgP4yatMxPB5AC5CtOWK2PPQXiws/NkQbrb5+XkMDQ4j115Mo6iB6gCpYgRBFULohx1TXoSGVyiPQFmEQpHg9p67cPXqNSv2V1Y9tdnZWXR23mbTpaQ5k6gJYFKVgItgwvGYGmRWPLTelivhyPsfWJFm8eXlFXx2egLj4+9hZmbG3vv0k9NwywSCBzVIM0AZQDzvUC5HTRka8ULJR8+WOzGfSc25L77CPb39yOfLcBwHWkU4M3HWPht7/gV7jzNlS7UZYP47lAVvMB5bgNPSgQOjY2vET5w4hYrL0NZehomU89CWa2dXD06e+hj7n3kO+/Y9ijCqgjBt8193CyAsOGwApt5z+TI+Ona8IX7x4hSEDG0frKkWXUWx5OHWzd2Y+v4H++6LLx2E05KDUCGkMumKoIIEDqXhIQPwfAWPCHw3eckuWFxcQl/fDuRyZZNL280NiIhR8QRu2rQZly//bt9fWl7GfQO7kMuXoLSJILKd7RAWPlkHmPr/afoXu+CtN99Gi9MBziObmmaA/S0SG/HQ8ANYWVm1a378eRpRshE+ESkghlOp6LtN/n2iQZiygJXVVXR33YFikYCl1WUhGecyhNOax8GXX2mk9Z13x1EsVyCU6fToiumzdkL1r6YP2jtcfP3NeRw7fhItrQUrUi/frHgd4FOJis9x9tyXFnD+wgW4HrHPuAyO2k72fTliFpRdju39A+jq3gLXE00AkyIzVZtmVQowOy1XKDbd0olnRw5gW28fPJ/bvhBC3GsBWusyYeo3c3gdBR9uhYMLs8va7v8RIIJ0l6FJBdyKsPOr5FLoIDFj4kRj2NkomBowiyjXaz1NkU2TAdkD16nXImlOmf36qXiOMRavAaSQ/RbSDFoXUKs6+0GyHhlhM/iWiEi2Z7UbRph4mnF9vRHNuoA0gtTTqTrHmBrIat5glMpeQtW3ZoSb3FNzFmaXDUD9PBS41Gl/hB9SGm7Iav2btRKSPEK5niBM/2FFeWy91tlmfkVzhMujnKud2cV1+xvpKvPOaFkZwgAAAABJRU5ErkJggg=='
  hoe = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAQ/SURBVEhLjZVdaBxVFMenyWa/d2fnzr3nfuxsipQ0DVWKRG1paxFNtX0VrW2KINVqkrbqQ1EaqrSKlCIUbdIXkyBFNOKDVPsgxjyIvvjkg4oWReprUmqwTSR+xL/cmd3ZzSQ1Hjjs7Myd/++eM+ec6zhrWFFrLlSwRwj9AiczIoQZE8Kc41w/K4Te6QRBLvnO/zIhaht8bs4rbmakrEKqYKVTFZLMj0zUTjDGykmNWxoT8igX1d+kWg9JAYgMxCpu71s4qU5wUb3Cudqb1EraOi7lRVIBBNUgyP6uFF7NyYJkAF+Y40nR2ASpCamDcLHPNbK5ElIdWRTLLjK5PNo7Mkhnc/B8AVI6AYk2ZVNHpAaS2k5FiEFRF/c8gULJxYGDj2P45MvovXsrDj11GCMXLmDo6DEIqVCueOHaJEDImr2/xJi8Jxb3PFNjguZ9ZcB8ibLLMDYxjobdXPg9vrb26WfTMLVOuBW+IlUWRMqmV33tOE57CPAFvSmUgS81MtkiTp1+NRZbWibdtLfGJ8IUctGaKhuRjcRWXQ3ck/scW14+6Vmuqih5HBu6ujEzOxuKWPF/EsKz165hYWEB1+fm0NXdA7fiJ9JUd1mDz82Uw0jv5iqALw2yRRe77rs/Idm06elpBLUAp145Hf6/s/culMpsdQAF8Hn1puPbDtURIFeqYNuOnfjzr79bZKMYvvnuW0ij4TgO9vf3h/d2P7Q3TFNUoo30NJ1kDQ5TerQBKDOBam09fr76S126maDH+vvhpNIoMY7bujbixvw8Pv/iSzhOG3KFEqSO+qABi6474TBpxhoA66lMFm+cH10GsLv3ScH1JXwZIJ0v4enBIbx4YhhPHHoSDz/yKLL5QtQDSYAvzblWQMmtYPMdW3D917l49yOjo2hLpcGljtaRQjqbx2tnzobP7Yfv7tmMYsmLRseyCIQ+1gqwTZRKZzB88qUYMDB0BO0d6fCZkBqcJPLFEi6+82685tJHl5HOFsF81RJF1aaourUh3vCKTyi4DJ9MTYcv79t/INxxs1o0XI/BBJ34/ocrMeTwM4NhpHaMkNUSetbpdXo7GFc/2T6IIaqKfNnDptu34NLHl7Ft+46wu5vNZIebQUc6h74H92Bx8Y8QYHsjLF23AqkNmKDJeier46QtoJ5jadBoPDvomKgPN5sianYuJ4V17SmcOft6HMXA4BF0ZLIhgHN+bwiQUhY4qauiNYoGSMh67uveArDu+RykDMYn3sZ7k+9j46Ye+ILApfwwHnbWyJg+qaJDpFVgLbcfkjFCLl9GtlAE4wJC6RnGguoyQAgher5Ry0mhtTwcelGUi1ypXUnt2Djp50iaJVIWkjxUbuHSQNr1dudEfUnNFSaE2C6U/koae95aUKs3hW2kdWFbBB94Wncmtf7L2ipEB4VUU4LMjagz60difeYwMjM+qUnXpweSLzfsX7YbGg4IQ29fAAAAAElFTkSuQmCC'
  insect = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAT1SURBVEhLjVRbbBRVGF5BA8v2sruzO3PuZ3Zm2wKaKLa0hSgvVqNQ0wfEmIiaaBQIIEQuCQFiwdsDAsFrAvqAGjE+SAIoyIuUChQEDBAvUYkPGmTxibLSRoKfOWd2h2WJly/5s2dm9nzf+b/znZNI/Acobc0JEd5PRXEl48HrjAfbmAg2cR48K2XrXUKIZP2c/wUpZci4fI2JQknIIoRqhZCtEKolLqlaoGTxB8lbVmWzxaZ6jn8EFWoRE/oilyEYD0F5AZT7YCKIi/MAUoTQsgitWs34e871A/Vc9biJUb1dGGIZghhiFhVhCoRpuEQhm2NIpz00NWbR1JBFPs+gdAt8XYQS/vJ60hiUqHeFCEFZAMoDODmG5mYXjkPAuQ9KJHy/BVM7pqO3tw8L5i/E4kVL0NHeDSfrQasQWoeQUs+v504wphcIa0eAvCuRTudx55Qu9M7qQ1fnNDw0+xHs2f0Zzp8v4dKlMmph3vX1zYaTJVAyMHW1UCh0xuSZDJOU6zIVAVyi4eY53nrzbYyOjMQkB74YwJrV/Th8eKiG+q94NDh42HbBmV/pwj85Z86csVbAJWKLUCGoKGBCKov16162k347dw7vv/cBThz/2j6XSr9j/rxFGBg4GBNXcejQkYqAhhQF+H4AxuTDCRMvj6kLJinGGq1a8Osv5zA8PIzurukYM2YcMmkXK1esikTOl/DY3CdQKl24TmDu3MfR3JSD4AUI7kOpAFyo/QlK5b12U1kBWYdhyh2ddsLQkaNINztgVIF4EjePTWLN6ufttx0ffoStW9+JyTdu3IzGhjQ4M+SBFTBdCO5fSnjUX8l4EZT5cPIUkyffjsuXR3H2p7OglMNzmfWVeMpu4qlTZ1Aul7F2bSS2b99+OI5nv5uQCBbGAkqGSBDiv2E6INSHRxWyWQ8DBwbt5Jkze5Ga0FRpO0ByfCNeevEV+23zpi04fvwkJk28DTmbnmJEbgUKECKAr1qR8Dy9zR4k6ttqSGXw1JNPV2waguO4yKTzdlXJ8SksW7bCflvXvx4dHV32sEW2FCu/ZjFGIIQvjQBVm2oFCJHIpHPYtWu3Jdqz51O0tU3C+HENaG7KYu/ez1Eu/4HOqd1obGi2qbHes1qByCKtikjkPbW4VoBxPzqVOrTkBiZRO3fuwtGhr+zzt998B0YFXJdUBPzI/wr5tT0IjEV+l0c0qkWZBhM+sg5BzvGwdOlzOHHiJC5eLNuVV9Hf/wKSyRQ4k1akSnxNwKbpQqK9vf0W15U/EuLHApRHIsQTSKWa4bkcYTARE9tuxenTZ6zAyMgoenruszYJXhEQCkJEY3MvSe7vsCeZ5NVyRgsgnra5NxW1HpV5NiITko2YNetBXLnypxU5duwYuLllPVFZuY4EhA8lfVAq77YCnuelCBE/c+KDEUOowatV277QNkkbNrwaW7V2zTqbvMj/SMCeYi4/iS87A8ZUDyUaxDPWaFCi7PVc240RMZ1QKjB48Etr07xnFqKxIVPznwI41yUhBL9OwMB1+VJGzb0fxZUQcYNdJh1uniEM2jCte4Ydm8XE5EyPCiJm1HPHoJQvoVRcZcwI8LiLalUjaDoxca4uwLzjTJUYYz31nDcgn2fTCaFDjInrNroqUJv16FIzq1cfU0pVPde/YYzr0kcJEfsZVcPVPbhGalNT4lTtcF12T/3kKv4Gzb9C+9eSXpkAAAAASUVORK5CYII='
  fishing = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAATnSURBVEhLjZVZbFVVFIZPe+fpnD2cPZ3biwEHDAkSAymGFC8iJmqhULGlVUzkDQlUVIL6YhH1BQkR8EGDhvgixgQKBMJgEBAfHAnlycjUBF/a+IDWGmmCv9n70Gs4DLqSlbPvvXuvb6+1/nWu5/2Hlcv3hZTqx2mg1lMqtxMidlAqthAS9tFyrc3zWgrJM//LfF/cTSnfRokcZkyDsQiMGcTr2EkQgRD+MyHsdcaYn4xxWyOErSaE/8a5AGUclIagVIBSeQsXYCwEIeynSoU+kYyVtCbfDz6xh7LZItLpHDKZHCi1EOt3gsTPIODrkkEbVvbJx77PQAKB9icXo3NJFzo6liCTyaOpKYVS0QejEpwp5zeD4t8olSuTsb1yofyClAaHD32BDz/4CEePHMPIyK/47tvv0de3Fq+ufw33T52GdCqHQr58W4DNhDF5jTHW2ghOKa35Zf8PrSJcOD+E/fsPYO/evbh08SKOHfsSx4+fhLXR0VHs3LkT06fPQJOXQRDYkt0MYkyBEHna87pSDsADvlVyCRowTKpNxpQp92L+/PlYsWIF6vV5eKrzaRw4cBD423Fw5coV9K15CalUDpUKbfThRoiB76tuz8or5GJEhAqCKwQ+RSadQ2vrbFy+/Avq9UfgeZ777qHZc7Bv3/6YAuDdTZudEAKfgDHh+jPhnGlQIo56UsrHpNAIuQUYhKFEPlfAokWLXZDe3uVIpTKghCObyTvQKy+va0A29G9EqjkNzkSj+dZDbgFy1BNCrNciQhgacGEghEYhX8LChR0uQFfXMmTTeRcg5BIkYC6jlStXNSCdnUuRas66oEmIJ0P9vpJViNDe3kCENwK6u3uQyxbAaAg7eEIo97SQTZs2uz3nzp2HUhH8CksADDzB9Y4JgHOhkM8X0d6+yB3u6XkG2WwOShk3bLaEQir4FYIgoBgcPOv2vbXxHXhe6hYAYbZo1QIpIudJQHd3rxuy3bsHsPHNt10PpNRun10vW9aLXZ9+hueWPw8bhwRhozz2whaw5o6Arh40Nadx5sxZXL06jhkPPIhy2XcQm41dr1q1Gj/+cBoHDx5CsVgBI/I6QMNTqjpbyRbYMlmXwqCQr2Bh+5IGwPOaceLEV+7z4cNHXHlcqYRCLleIZwTA+Pg4Zs1qRbFQdqpkLBzxZs6cmZEyOmezmIAUCwEWdyx1h2wmtqGnTn2NsbExDAzsQ612l9O9zTiXLTkhTFh//wYnaztXjPFdbpKF0OuM+RdQKVHMqy9wB7Zt3Y65bXWMjf2JPbsH4HlN7vZKGAegRCKKahgaGnL7BwcHY8UxAULCuQ6glCpJbS5pHUNscygR2Pre9sbNLl64hLa2Okqliqu/FgZK2N61uLdt/xsb3L6TJ09dD873NF521qIoWmBMFVobJ0l7y0qFuFeFHaQpk+9BqeRDhREUN87tgCpRBecaUkWunFOnTrNyHmaMVW8AWJPSrI0hkYPYm1pIoVBxGTmlhQYqNNDWHSByWdt3T7FYtv9sf2nd8nAydsOkNC9qHV3TuuogdkJjldUghXWrtFjSFhC7gVFVSGmGpZQLkjFvMiHEHK3NN1FUhdFV6OuAGBILwZbGiCoi2QIjDbTUn1NqJiVj3cmapZTPKhUdVbL6u1Y1GD3JTatdW4gJo2HDzS7J5aPJwxP2Dymw9f+Tl5meAAAAAElFTkSuQmCC'
  catLife = 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAGnSURBVDhPxdJPiE9RGMbx8S+SIgumTP78JNkiJpGoWSiU1WRBiSILQ7OwUEZsLAhZShZW7JSFUpKyZEVZz4qwUKQsPq+Oee+v68zFpORbt8593/d57nPuOQMD/4OIWI3zdf2vwV58iYiFdW/GRMS8iFhc1jgdU/TyfWk9/0ciYhGe4QweFDecw21cr+dnBA5lsj74hmX17C/BKoyWQ8DDDsNPuIVx7ImIJbXHT2AMk7VRF3iJbbXHNCJiLtbgRIfJh4jYHhGDta5P+SfY3FEvW3uPj2k2ia840J4rNwLDJUgjPJwBehGxEhsjYhYuYQg30nA3duF46nbmbsZSP5UaG1JwB0dzPd4kwLGsDWWiBRFxP2tb8Q6vI2JOE7mkeZMDO3Az13fTcEsR5GwPr7K/v9yGXF9pAjQprmXjBS7mFgoX0mgT5peTzbm3OFv+ab6P1IZr8bll9IM8hBU5c7DuF/Ckv93KdCSvRS0Yzf69jt5zLK+9+mAdHleik9l7VNWvlgOqPaYREbPLl1vCU1l/2qpN1LrfgiO5nfLsK7WIuNyqra81/4TvZ+zNNSBx/2oAAAAASUVORK5CYII='
  catBattle = 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAEpSURBVDhP3ZTNKkVRGIbPgAy5ACMjBshMOZSiGChjl6EwZehEyBUY+rkJ12CiXAEiwimp59U6fVur1zrbyUR5ag/2t7736du7tVaj8S+RNAqsA1vxrEnq876ekNQEHmQAY977I8CspCeXJYAp769F0gLwEuFbYEbS9q+EIXuL4B0wkerAeTbkiOeKAIvAazbZeKpLOsum2/VckYKsM5nJjj3XARhIi2kbxPu8ySZT3WSH7vlC0hDQjsYT4N5lwGkm23PHN9K2AJ6z0E2Xf1b+zBLAdDbdUdTyyQ48U4ukfuA6wu/AVSZreX8tkgaBy0qQA+x4fy0uS6cC2Ace433DM7UAm5msDSxFPR2x6vyueq4rwArwkW4SYNnW5oCLavv0TNxzw17/Uz4BYO8JTHUO+5AAAAAASUVORK5CYII='
  catEtc = 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAADQSURBVDhP7dTBKoVRFIbhMxBFJqdMFG4Ao1Pch7sxdAluQGZuABOUsc7UfaCMeJa2tr/zL5s6/kzkrW/wrd16W6M9Gv02WMqzH4N13OOo9IhYxhY2ciJis+TbA7AXEYGb2k/whIdGHvFcdrKnA5MqPK/9uvSvwGlELGRPR0N4mSUfYIqV7Ogxp/Ag739iTuFtRCxmR4+G8CqLZsFxdvRoCM/wipdGyrxkkj0dM8KL2sfYxXYjOzWr2dORhYP5Fw4H+1X4/jkMBmu4w2F++zu8ASXM53NtJAuMAAAAAElFTkSuQmCC'
}
# 맵에는 대분류 버튼 아이콘 3종(catBattle=공격력/catLife=생활력/catEtc=일 아이콘, 20px)도 함께
# 들어 있어 같은 디코드/실패 로그/종료 해제 계약을 공유합니다 (2026-08-05 사용자 제공,
# catEtc 는 2026-08-15 사용자 제공 work1.png 64px → 20px 축소 내장)
$script:lifeSkillIcons = @{}
$script:lifeSkillIconLoadFailures = @()
foreach ($lifeIconId in @($script:lifeSkillIconB64.Keys)) {
  # 아이콘은 선택적 장식 - 실패해도 글자 카드로 계속 (단 조용히 삼키지 않고 실패 ID 를
  # 모아 시작 로그로 경고. 임시 리소스는 finally 로 항상 정리 - 리뷰 조건)
  $lifeIconStream = $null
  $lifeIconTmp = $null
  try {
    $lifeIconStream = New-Object System.IO.MemoryStream(, [Convert]::FromBase64String([string]$script:lifeSkillIconB64[$lifeIconId]))
    $lifeIconTmp = [System.Drawing.Image]::FromStream($lifeIconStream)
    # FromStream 은 스트림 수명에 묶이므로 Bitmap 사본으로 분리해 보관
    $script:lifeSkillIcons[$lifeIconId] = New-Object System.Drawing.Bitmap($lifeIconTmp)
  } catch {
    $script:lifeSkillIconLoadFailures += [string]$lifeIconId
  } finally {
    if ($lifeIconTmp) { try { $lifeIconTmp.Dispose() } catch { } }
    if ($lifeIconStream) { try { $lifeIconStream.Dispose() } catch { } }
  }
}

# 대분류 버튼 아이콘 (Paint 로 정중앙 글자 바로 왼쪽에 직접 그림 - Invoke-MainCatButtonPaint.
# 아이콘이 없으면 글자만).
# 원본이 흰색(투명 배경) 아이콘이라 꿀색 활성 버튼에서만 보임 → 비활성(크림)용으로
# themeText 진갈색 틴트 사본을 만들어 상태별로 교체 (Update-MainCategoryVisual 담당.
# 사본도 lifeSkillIcons 에 넣어 종료 해제 계약 공유)
foreach ($catIconId in @('catBattle', 'catLife', 'catEtc')) {
  if (-not $script:lifeSkillIcons.ContainsKey($catIconId)) { continue }
  $catSrcIcon = $script:lifeSkillIcons[$catIconId]
  $catDarkIcon = New-Object System.Drawing.Bitmap($catSrcIcon.Width, $catSrcIcon.Height)
  foreach ($catPy in 0..($catSrcIcon.Height - 1)) {
    foreach ($catPx in 0..($catSrcIcon.Width - 1)) {
      $catSrcPx = $catSrcIcon.GetPixel($catPx, $catPy)
      $catDarkIcon.SetPixel($catPx, $catPy, [System.Drawing.Color]::FromArgb($catSrcPx.A, 66, 50, 22))
    }
  }
  $script:lifeSkillIcons[$catIconId + 'Dark'] = $catDarkIcon
}
function Invoke-MainCatButtonPaint {
  # 대분류 버튼 아이콘 그리기: 글자는 버튼 기본 정렬(정중앙) 그대로 두고, 아이콘을 글자
  # 시작점 왼쪽 6px 에 직접 그립니다 (활성 = 흰 원본 / 비활성 = 진갈색 틴트).
  # Button.Image 방식은 '글자 정중앙 + 아이콘 인접'을 만들 수 없음 (2026-08-05 정렬 수렴)
  param($Sender, $PaintArgs)
  try {
    # 2026-08-15: 기타 버튼 아이콘(catEtc) 추가로 2분기(battle/life)에서 3분기로 일반화
    $paintCategory = $(switch ($Sender.Name) {
        'btnCatBattle' { 'battle' } 'btnCatLife' { 'life' } default { 'etc' } })
    $paintIconKey = $(switch ($paintCategory) {
        'battle' { 'catBattle' } 'life' { 'catLife' } default { 'catEtc' } })
    $paintActive = ($script:mainCategory -eq $paintCategory)
    if (-not $paintActive) {
      if ($script:lifeSkillIcons.ContainsKey($paintIconKey + 'Dark')) { $paintIconKey = $paintIconKey + 'Dark' }
    }
    if (-not $script:lifeSkillIcons.ContainsKey($paintIconKey)) { return }
    $paintIcon = $script:lifeSkillIcons[$paintIconKey]
    $paintTextSize = [System.Windows.Forms.TextRenderer]::MeasureText($Sender.Text, $Sender.Font)
    $paintIconX = [int](($Sender.Width - $paintTextSize.Width) / 2) - $paintIcon.Width - 6
    $paintIconY = [int](($Sender.Height - $paintIcon.Height) / 2)
    $PaintArgs.Graphics.DrawImage($paintIcon, $paintIconX, $paintIconY, $paintIcon.Width, $paintIcon.Height)
  } catch { }
}

# 슬라이더 상태: 선택 인덱스(전체 목록 기준) + 표시 페이지 (3개 단위 - 설계 합의 규칙:
# 화살표 = 페이지 이동(끝에서 비활성), 점 = 페이지 수, 카드 클릭 = 선택,
# 스킬 변경 시 대상은 첫 항목으로 폴백)
$script:lifeSkillIndex = 0
$script:lifeSkillPage = 0
$script:lifeTargetIndex = 0
$script:lifeTargetPage = 0
# 자동화가 지원하는 채집 스킬 (워커 $lifeSkillMenuTable 과 1:1). 시작 게이트와 '적용된 설정'
# 안내가 같은 목록을 봐야 하므로 script 스코프에 한 번만 둡니다 (2026-08-08 - 함수 지역
# 변수였을 때 팝업 쪽에서 못 읽어 낚시도 지원되는 것처럼 보였습니다)
$script:lifeSupportedSkillIds = @('daily', 'wood', 'mining', 'herb', 'wool', 'harvest', 'hoe', 'insect')
$script:lifeCardFontNormal = New-Object System.Drawing.Font('Segoe UI', 9)
$script:lifeCardFontBold = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$script:lifeCardSelectedBack = [System.Drawing.Color]::FromArgb(250, 240, 218)   # 선택 카드 배경 (확정 시안 #FAF0DA - 안전 중지 버튼과 동일 계열)

# 콘텐츠 선택 - 생활용 라디오 줄 (전투 pnlCategory 와 교대 표시. 라디오 상태는 서로 보존)
$pnlLifeCategory = New-Object System.Windows.Forms.Panel
$pnlLifeCategory.Location = New-Object System.Drawing.Point(15, 20)
$pnlLifeCategory.Size = New-Object System.Drawing.Size(484, 26)
$pnlLifeCategory.Visible = $false
$grpContent.Controls.Add($pnlLifeCategory)

$rbLifeGather = New-Object System.Windows.Forms.RadioButton
$rbLifeGather.Text = '채집'
$rbLifeGather.Location = New-Object System.Drawing.Point(0, 2)
$rbLifeGather.Size = New-Object System.Drawing.Size(80, 22)
$rbLifeGather.Checked = $true
$pnlLifeCategory.Controls.Add($rbLifeGather)

$rbLifeProcess = New-Object System.Windows.Forms.RadioButton
$rbLifeProcess.Text = '가공'
$rbLifeProcess.Location = New-Object System.Drawing.Point(100, 2)
$rbLifeProcess.Size = New-Object System.Drawing.Size(70, 22)
$pnlLifeCategory.Controls.Add($rbLifeProcess)

# 콘텐츠 선택 - 기타용 라디오 줄 (2026-08-15 신설 - 전투/생활 패널과 교대 표시)
$pnlEtcCategory = New-Object System.Windows.Forms.Panel
$pnlEtcCategory.Location = New-Object System.Drawing.Point(15, 20)
$pnlEtcCategory.Size = New-Object System.Drawing.Size(484, 26)
$pnlEtcCategory.Visible = $false
$grpContent.Controls.Add($pnlEtcCategory)

$rbEtcMerchant = New-Object System.Windows.Forms.RadioButton
$rbEtcMerchant.Text = '고양이 상인'
$rbEtcMerchant.Location = New-Object System.Drawing.Point(0, 2)
$rbEtcMerchant.Size = New-Object System.Drawing.Size(110, 22)
$rbEtcMerchant.Checked = $true
$pnlEtcCategory.Controls.Add($rbEtcMerchant)

# 상세 설정 - 기타: 냥코인 뽑기 (시안 확정 배치 - 카드 + 목표 냥코인 + 골드 상한 옵션 + 안내)
$lblEtcFeature = New-Object System.Windows.Forms.Label
$lblEtcFeature.Text = '기능'
$lblEtcFeature.Location = New-Object System.Drawing.Point(15, 20)
$lblEtcFeature.Size = New-Object System.Drawing.Size(200, 16)
$lblEtcFeature.Visible = $false
$grpContentDetail.Controls.Add($lblEtcFeature)

$btnEtcNyanCard = New-Object System.Windows.Forms.Button
$btnEtcNyanCard.Text = '냥코인 뽑기'
$btnEtcNyanCard.Location = New-Object System.Drawing.Point(15, 40)
$btnEtcNyanCard.Size = New-Object System.Drawing.Size(158, 34)
$btnEtcNyanCard.Visible = $false
$btnEtcNyanCard.TabStop = $false   # 기능이 하나뿐이라 표시용 카드 (선택 스타일은 테마 적용 후 지정)
$grpContentDetail.Controls.Add($btnEtcNyanCard)

$lblEtcTarget = New-Object System.Windows.Forms.Label
$lblEtcTarget.Text = '목표 냥코인'
$lblEtcTarget.Location = New-Object System.Drawing.Point(15, 92)
$lblEtcTarget.Size = New-Object System.Drawing.Size(70, 18)
$lblEtcTarget.Visible = $false
$grpContentDetail.Controls.Add($lblEtcTarget)

$numEtcTarget = New-Object System.Windows.Forms.NumericUpDown
$numEtcTarget.Location = New-Object System.Drawing.Point(90, 88)
$numEtcTarget.Size = New-Object System.Drawing.Size(96, 24)
$numEtcTarget.Minimum = 1
$numEtcTarget.Maximum = 99999999
$numEtcTarget.ThousandsSeparator = $true
$numEtcTarget.Value = 10
$numEtcTarget.Visible = $false
$grpContentDetail.Controls.Add($numEtcTarget)

$lblEtcTargetSuffix = New-Object System.Windows.Forms.Label
$lblEtcTargetSuffix.Text = '개'
$lblEtcTargetSuffix.Location = New-Object System.Drawing.Point(190, 92)
$lblEtcTargetSuffix.Size = New-Object System.Drawing.Size(24, 18)
$lblEtcTargetSuffix.Visible = $false
$grpContentDetail.Controls.Add($lblEtcTargetSuffix)

# 골드 상한 - 체크 옵션 (기본 꺼짐. 사용자 지시: "체크박스로 옵션처럼". 켜면 워커가
# '시작 골드 - 현재 골드'로 사용액을 재서 상한 도달 시 정지 - Codex 필수 권고의 절충)
$chkEtcGoldLimit = New-Object System.Windows.Forms.CheckBox
$chkEtcGoldLimit.Text = '최대 사용 골드'
$chkEtcGoldLimit.Location = New-Object System.Drawing.Point(238, 90)
$chkEtcGoldLimit.Size = New-Object System.Drawing.Size(104, 22)
$chkEtcGoldLimit.Visible = $false
$grpContentDetail.Controls.Add($chkEtcGoldLimit)

$numEtcGoldLimit = New-Object System.Windows.Forms.NumericUpDown
$numEtcGoldLimit.Location = New-Object System.Drawing.Point(344, 88)
$numEtcGoldLimit.Size = New-Object System.Drawing.Size(110, 24)
$numEtcGoldLimit.Minimum = 1000
$numEtcGoldLimit.Maximum = 999999999
$numEtcGoldLimit.ThousandsSeparator = $true
$numEtcGoldLimit.Value = 1000000
$numEtcGoldLimit.Enabled = $false
$numEtcGoldLimit.Visible = $false
$grpContentDetail.Controls.Add($numEtcGoldLimit)
$chkEtcGoldLimit.Add_CheckedChanged({ $numEtcGoldLimit.Enabled = [bool]$chkEtcGoldLimit.Checked })

$lblEtcGoldSuffix = New-Object System.Windows.Forms.Label
$lblEtcGoldSuffix.Text = '골드'
$lblEtcGoldSuffix.Location = New-Object System.Drawing.Point(458, 92)
$lblEtcGoldSuffix.Size = New-Object System.Drawing.Size(40, 18)
$lblEtcGoldSuffix.Visible = $false
$grpContentDetail.Controls.Add($lblEtcGoldSuffix)

$lblEtcHint = New-Object System.Windows.Forms.Label
$lblEtcHint.Text = "고양이 상인 '뽑기' 화면을 열어 둔 상태에서 시작하면 목표 냥코인 개수에 도달할 때까지" + [Environment]::NewLine +
  "카드 구매(골드 소모) → 다시 뽑기를 반복합니다."
$lblEtcHint.Location = New-Object System.Drawing.Point(15, 124)
$lblEtcHint.Size = New-Object System.Drawing.Size(484, 50)
$lblEtcHint.Visible = $false
$grpContentDetail.Controls.Add($lblEtcHint)

# 상세 설정 - 채집: '채집 스킬' 슬라이더 줄
$lblLifeSkillCaption = New-Object System.Windows.Forms.Label
$lblLifeSkillCaption.Text = '채집 스킬'
$lblLifeSkillCaption.Location = New-Object System.Drawing.Point(15, 20)
$lblLifeSkillCaption.Size = New-Object System.Drawing.Size(200, 16)
$lblLifeSkillCaption.Visible = $false
$grpContentDetail.Controls.Add($lblLifeSkillCaption)

$btnLifeSkillPrev = New-Object System.Windows.Forms.Button
$btnLifeSkillPrev.Text = '◀'
$btnLifeSkillPrev.Location = New-Object System.Drawing.Point(15, 38)
$btnLifeSkillPrev.Size = New-Object System.Drawing.Size(24, 56)
$btnLifeSkillPrev.Visible = $false
$grpContentDetail.Controls.Add($btnLifeSkillPrev)

$btnLifeSkillNext = New-Object System.Windows.Forms.Button
$btnLifeSkillNext.Text = '▶'
$btnLifeSkillNext.Location = New-Object System.Drawing.Point(475, 38)
$btnLifeSkillNext.Size = New-Object System.Drawing.Size(24, 56)
$btnLifeSkillNext.Visible = $false
$grpContentDetail.Controls.Add($btnLifeSkillNext)

$script:lifeSkillCards = @()
foreach ($lifeCardSlot in 0..2) {
  $lifeCard = New-Object System.Windows.Forms.Button
  $lifeCard.Text = ''
  $lifeCard.Location = New-Object System.Drawing.Point((47 + $lifeCardSlot * 142), 38)
  $lifeCard.Size = New-Object System.Drawing.Size(134, 56)
  $lifeCard.Visible = $false
  $lifeCard.Tag = -1
  # 게임 아이콘을 글자 위에 표시 (시안의 아이콘+이름 카드).
  # 정렬은 둘 다 MiddleCenter = '아이콘+글자'를 한 덩어리로 중앙 배치 - TopCenter/BottomCenter
  # 분리 배치는 카드 높이 56 에서 글자가 아이콘을 침범함 (2026-08-05 사용자 실기 제보,
  # 4개 변형 렌더링 비교로 24px+중앙 쌓기 채택)
  $lifeCard.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageAboveText
  $lifeCard.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
  $lifeCard.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
  $lifeCard.Add_Click({
      # 슬라이드 애니메이션 중에는 반대 행 카드 클릭도 무시 (스트립이 낡은 대상을 보여주다
      # 점프하는 혼선 방지 - 리뷰 조건)
      if ($script:lifeSlideActive -or $script:running) { return }
      $cardIndex = [int]$this.Tag
      if ($cardIndex -lt 0) { return }
      if ($script:lifeSkillIndex -ne $cardIndex) {
        $script:lifeSkillIndex = $cardIndex
        # 스킬이 바뀌면 대상 목록이 교체되므로 첫 항목으로 폴백 (설계 합의)
        $script:lifeTargetIndex = 0
        $script:lifeTargetPage = 0
      }
      Update-LifeSliders
    })
  $grpContentDetail.Controls.Add($lifeCard)
  $script:lifeSkillCards += , $lifeCard
}

$lblLifeSkillDots = New-Object System.Windows.Forms.Label
$lblLifeSkillDots.Text = ''
$lblLifeSkillDots.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblLifeSkillDots.Location = New-Object System.Drawing.Point(15, 96)
$lblLifeSkillDots.Size = New-Object System.Drawing.Size(484, 14)
$lblLifeSkillDots.Visible = $false
$grpContentDetail.Controls.Add($lblLifeSkillDots)

# 상세 설정 - 채집: '채집 대상' 슬라이더 줄 (목록은 선택한 스킬을 따라 교체)
$lblLifeTargetCaption = New-Object System.Windows.Forms.Label
$lblLifeTargetCaption.Text = '채집 대상'
$lblLifeTargetCaption.Location = New-Object System.Drawing.Point(15, 116)
$lblLifeTargetCaption.Size = New-Object System.Drawing.Size(200, 16)
$lblLifeTargetCaption.Visible = $false
$grpContentDetail.Controls.Add($lblLifeTargetCaption)

$btnLifeTargetPrev = New-Object System.Windows.Forms.Button
$btnLifeTargetPrev.Text = '◀'
$btnLifeTargetPrev.Location = New-Object System.Drawing.Point(15, 134)
$btnLifeTargetPrev.Size = New-Object System.Drawing.Size(24, 56)
$btnLifeTargetPrev.Visible = $false
$grpContentDetail.Controls.Add($btnLifeTargetPrev)

$btnLifeTargetNext = New-Object System.Windows.Forms.Button
$btnLifeTargetNext.Text = '▶'
$btnLifeTargetNext.Location = New-Object System.Drawing.Point(475, 134)
$btnLifeTargetNext.Size = New-Object System.Drawing.Size(24, 56)
$btnLifeTargetNext.Visible = $false
$grpContentDetail.Controls.Add($btnLifeTargetNext)

$script:lifeTargetCards = @()
foreach ($lifeCardSlot in 0..2) {
  $lifeCard = New-Object System.Windows.Forms.Button
  $lifeCard.Text = ''
  $lifeCard.Location = New-Object System.Drawing.Point((47 + $lifeCardSlot * 142), 134)
  $lifeCard.Size = New-Object System.Drawing.Size(134, 56)
  $lifeCard.Visible = $false
  $lifeCard.Tag = -1
  $lifeCard.Add_Click({
      # 슬라이드 애니메이션 중에는 반대 행 카드 클릭도 무시 (리뷰 조건)
      if ($script:lifeSlideActive -or $script:running) { return }
      $cardIndex = [int]$this.Tag
      if ($cardIndex -lt 0) { return }
      $script:lifeTargetIndex = $cardIndex
      Update-LifeSliders
    })
  $grpContentDetail.Controls.Add($lifeCard)
  $script:lifeTargetCards += , $lifeCard
}

$lblLifeTargetDots = New-Object System.Windows.Forms.Label
$lblLifeTargetDots.Text = ''
$lblLifeTargetDots.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblLifeTargetDots.Location = New-Object System.Drawing.Point(15, 192)
$lblLifeTargetDots.Size = New-Object System.Drawing.Size(484, 14)
$lblLifeTargetDots.Visible = $false
$grpContentDetail.Controls.Add($lblLifeTargetDots)

# '가방 가득 시' / '도구 내구도 소진 시' 옵션은 제거했습니다 (2026-08-08 사용자 판단).
# 두 상황 모두 **게임이 스스로 채집을 멈춥니다**. 그러면 자동화도 진행이 없어 정지하므로
# '계속 진행'이라는 선택지가 성립하지 않았습니다 - 고를 수 있게 두면 동작하는 것처럼
# 오해만 됩니다 (워커는 이 값을 읽은 적이 없음). 준비물 부족 '감지'는 옵션이 아니라
# 안내이므로 그대로 둡니다 (필요한 아이템 이름을 로그에 남기고 즉시 정지).

# 상세 설정 - 가공: 1차는 안내만 (높이는 채집과 같은 268 유지 - 전환 시 폼 흔들림 방지, 리뷰 조건)
$lblLifeProcessInfo = New-Object System.Windows.Forms.Label
$lblLifeProcessInfo.Text = '가공 자동화는 추후 지원 예정입니다.'
$lblLifeProcessInfo.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblLifeProcessInfo.Location = New-Object System.Drawing.Point(15, 110)
$lblLifeProcessInfo.Size = New-Object System.Drawing.Size(484, 40)
$lblLifeProcessInfo.Visible = $false
$grpContentDetail.Controls.Add($lblLifeProcessInfo)

function Update-LifeSliders {
  # 두 슬라이더(스킬/대상)의 카드 3개·화살표·점·선택 강조를 현재 상태로 다시 그립니다.
  # Apply-HoneyTheme 가 버튼 스타일을 일괄 덮으므로 테마 적용 후에도 반드시 재호출 (리뷰 조건 E)
  $lifeSkillCount = @($script:lifeSkills).Count
  $lifeSkillPages = [Math]::Ceiling($lifeSkillCount / 3.0)
  if ($script:lifeSkillIndex -ge $lifeSkillCount) { $script:lifeSkillIndex = 0 }
  if ($script:lifeSkillPage -ge $lifeSkillPages) { $script:lifeSkillPage = $lifeSkillPages - 1 }
  if ($script:lifeSkillPage -lt 0) { $script:lifeSkillPage = 0 }
  $currentSkill = $script:lifeSkills[$script:lifeSkillIndex]
  $lifeTargets = @($currentSkill.Targets)
  $lifeTargetPages = [Math]::Max(1, [Math]::Ceiling(@($lifeTargets).Count / 3.0))
  if ($script:lifeTargetIndex -ge @($lifeTargets).Count) { $script:lifeTargetIndex = 0 }
  if ($script:lifeTargetPage -ge $lifeTargetPages) { $script:lifeTargetPage = $lifeTargetPages - 1 }
  if ($script:lifeTargetPage -lt 0) { $script:lifeTargetPage = 0 }
  # 커스텀 반복 화면에서는 카드 높이가 26 이라 아이콘이 들어갈 자리가 없습니다 - 글자만
  # 남깁니다 (아이콘 9종은 일반 생활 모드 그대로. 시안 확정 - 2026-08-08)
  $lifeIconsOff = ($script:mainCategory -eq 'life') -and $rbLifeGather.Checked -and $rbCustomRepeat.Checked
  # 렌더 공통 (카드 배열 / 항목 이름 배열 / 페이지 / 선택 인덱스)
  $lifeSliderSets = @(
    @{ Cards = $script:lifeSkillCards; Names = @($script:lifeSkills | ForEach-Object { [string]$_.Name })
       Icons = $(if ($lifeIconsOff) { $null } else { @($script:lifeSkills | ForEach-Object { $script:lifeSkillIcons[[string]$_.Id] }) })
       Page = $script:lifeSkillPage; Pages = $lifeSkillPages; Selected = $script:lifeSkillIndex
       Dots = $lblLifeSkillDots; Prev = $btnLifeSkillPrev; Next = $btnLifeSkillNext }
    @{ Cards = $script:lifeTargetCards; Names = @($lifeTargets | ForEach-Object { [string]$_ })
       Icons = $null   # 대상 아이콘은 캡처 수급 후 추가 (글자 카드)
       Page = $script:lifeTargetPage; Pages = $lifeTargetPages; Selected = $script:lifeTargetIndex
       Dots = $lblLifeTargetDots; Prev = $btnLifeTargetPrev; Next = $btnLifeTargetNext }
  )
  foreach ($sliderSet in $lifeSliderSets) {
    $sliderNames = @($sliderSet.Names)
    foreach ($slotIndex in 0..2) {
      $slotCard = $sliderSet.Cards[$slotIndex]
      $itemIndex = ([int]$sliderSet.Page) * 3 + $slotIndex
      if ($itemIndex -lt $sliderNames.Count) {
        $slotCard.Text = $sliderNames[$itemIndex]
        $slotCard.Tag = $itemIndex
        # ★ 실행 중에는 잠금을 유지합니다. Set-UiRunning 이 시작할 때 상세 패널을 통째로
        #   잠그는데, 설정/로그 탭 토글은 (실행 중에도 써야 해서) 잠그지 않고 그 핸들러가
        #   이 함수를 다시 부릅니다. 그때 무조건 $true 로 되돌려 **카드만 다시 눌리는 것처럼
        #   보이는** 상태 불일치가 생겼습니다. 실제 값 변경은 클릭 핸들러의 running 가드가
        #   막고 있지만, 잠금 계약과 화면이 갈라져 있으면 다음 사람이 그 가드를 믿지 못합니다
        #   (화살표는 아래 canNavigate 게이트로 이미 제대로 잠겨 있어 대비가 더 뚜렷했습니다.
        #   2026-08-10 8차 점검).
        $slotCard.Enabled = (-not $script:running)
        $slotCard.Image = $(if ($null -ne $sliderSet.Icons) { $sliderSet.Icons[$itemIndex] } else { $null })
        $slotCard.FlatStyle = 'Flat'
        if ($itemIndex -eq [int]$sliderSet.Selected) {
          $slotCard.BackColor = $script:lifeCardSelectedBack
          $slotCard.ForeColor = $script:themeText
          $slotCard.FlatAppearance.BorderColor = $script:themeHoney
          $slotCard.FlatAppearance.BorderSize = 2
          $slotCard.Font = $script:lifeCardFontBold
        } else {
          $slotCard.BackColor = $script:themeControl
          $slotCard.ForeColor = $script:themeText
          $slotCard.FlatAppearance.BorderColor = $script:themeBorder
          $slotCard.FlatAppearance.BorderSize = 1
          $slotCard.Font = $script:lifeCardFontNormal
        }
      } else {
        # 마지막 페이지의 빈 칸: 클릭 대상이 아님을 명확히 (빈 카드 비활성)
        $slotCard.Text = ''
        $slotCard.Tag = -1
        $slotCard.Enabled = $false
        $slotCard.Image = $null
        $slotCard.BackColor = $script:themeControl
        $slotCard.FlatAppearance.BorderColor = $script:themeBorder
        $slotCard.FlatAppearance.BorderSize = 1
        $slotCard.Font = $script:lifeCardFontNormal
      }
    }
    # 페이지 점: 현재 페이지 = ●, 나머지 = ○ (페이지 수 = ceil(항목/3) - 설계 합의)
    $dotParts = @()
    foreach ($dotIndex in 0..([int]$sliderSet.Pages - 1)) {
      $dotParts += $(if ($dotIndex -eq [int]$sliderSet.Page) { '●' } else { '○' })
    }
    $sliderSet.Dots.Text = ($dotParts -join '  ')
    # 위치점은 흐린 색 (확정 시안 themeMuted. Apply-HoneyTheme 가 Label 을 themeText 로
    # 덮으므로 여기서 매번 복원 - 리뷰 지적)
    $sliderSet.Dots.ForeColor = $script:themeMuted
    # 화살표: 끝 페이지에서 비활성 (순환 없음 - 설계 합의) + 애니메이션/실행 중 잠금
    # (Start-LifeSlide 도중의 Update-LifeSliders 호출이 잠금을 되돌리지 않게 - 리뷰 조건)
    $canNavigate = (-not $script:lifeSlideActive) -and (-not $script:running)
    $sliderSet.Prev.Enabled = $canNavigate -and ([int]$sliderSet.Page -gt 0)
    $sliderSet.Next.Enabled = $canNavigate -and ([int]$sliderSet.Page -lt ([int]$sliderSet.Pages - 1))
  }
}

# ── 슬라이더 페이지 전환 애니메이션 (v2.0.0 - 320ms ease-out, 데모 3속도 비교로 사용자 확정) ──
# 방식: 현재/다음 페이지 카드를 비트맵으로 합성해 임시 클리핑 Panel 위의 PictureBox 스트립을
# 밀고, 끝나면 실제 버튼 노출. 상태는 전부 $script: (GetNewClosure 금지 - 데모 1차에서
# 클로저 안 $script: 쓰기가 본체에 반영되지 않아 화살표 영구 잠김 실사고).
$script:lifeSlideActive = $false
$script:lifeSlideOverlayPanel = $null
$script:lifeSlidePicture = $null
$script:lifeSlideStrip = $null
$script:lifeSlideSw = $null
$script:lifeSlideDirection = 1
$script:lifeSlideWidth = 0
$script:lifeSlideDurationMs = 320.0   # 사용자 확정 속도
$script:lifeSlideTimer = New-Object System.Windows.Forms.Timer
$script:lifeSlideTimer.Interval = 15
# 다른 타이머 핸들러와 같은 계약: 예외를 밖으로 흘리면 PS 5.1 WinForms 가 모달 오류 창을
# 띄워 메시지 루프가 멈춥니다 (무인 운용에서 아무도 못 닫음 - 2026-08-10 10차 점검)
$script:lifeSlideTimer.Add_Tick({
    try {
      Invoke-LifeSlideTick
    } catch {
      try { Add-GuiLog "[오류] 내부 타이머(생활 슬라이드) 처리 중 예외 - 자동화는 계속 시도합니다: $($_.Exception.Message)" } catch { }
    }
  })

function Stop-LifeSlideNow {
  # 애니메이션 즉시 종료 + 전체 정리 (이미 반영된 새 페이지로 스냅). 어떤 중단 경로에서도
  # 잠금이 남지 않게 스스로 UI 를 복원합니다 (리뷰 조건 - SkipUiRefresh 는 폼 종료/패널
  # 갱신용: 이어지는 흐름이 UI 를 직접 갱신하는 곳에서만 사용)
  param([switch]$SkipUiRefresh)
  try { $script:lifeSlideTimer.Stop() } catch { }
  if ($script:lifeSlidePicture) {
    try { $script:lifeSlidePicture.Image = $null } catch { }
    try { $script:lifeSlidePicture.Dispose() } catch { }
    $script:lifeSlidePicture = $null
  }
  if ($script:lifeSlideOverlayPanel) {
    try { $grpContentDetail.Controls.Remove($script:lifeSlideOverlayPanel) } catch { }
    try { $script:lifeSlideOverlayPanel.Dispose() } catch { }
    $script:lifeSlideOverlayPanel = $null
  }
  if ($script:lifeSlideStrip) {
    try { $script:lifeSlideStrip.Dispose() } catch { }
    $script:lifeSlideStrip = $null
  }
  if ($script:lifeSlideSw) {
    try { $script:lifeSlideSw.Stop() } catch { }
    $script:lifeSlideSw = $null
  }
  $script:lifeSlideActive = $false
  if (-not $SkipUiRefresh) { Update-LifeSliders }
}

function Invoke-LifeSlideTick {
  # 타이머 틱 (명명 함수 - 클로저 미사용 계약). 예외는 Stop 으로 수렴해 영구 잠금 차단
  try {
    $slideT = [Math]::Min(1.0, $script:lifeSlideSw.Elapsed.TotalMilliseconds / $script:lifeSlideDurationMs)
    $slideInv = 1.0 - $slideT
    $slideEase = 1.0 - ($slideInv * $slideInv)   # ease-out (PS 에서 ^ 는 제곱이 아님 - 곱으로)
    $slideOffset = [int]($script:lifeSlideWidth * $slideEase)
    if ($script:lifeSlidePicture) {
      $script:lifeSlidePicture.Left = $(if ($script:lifeSlideDirection -gt 0) { -$slideOffset } else { -$script:lifeSlideWidth + $slideOffset })
    }
    if ($slideT -ge 1.0) { Stop-LifeSlideNow }
  } catch {
    Stop-LifeSlideNow
  }
}

function New-LifeSlideSnapshot {
  # 카드 3장을 현재 모습 그대로 합성 (간격은 themeBack - DrawToBitmap 은 버튼만 그림)
  param($Cards, [int]$ZoneX, [int]$ZoneW, [int]$ZoneH)
  $snapshot = New-Object System.Drawing.Bitmap($ZoneW, $ZoneH)
  $snapshotG = $null
  try {
    $snapshotG = [System.Drawing.Graphics]::FromImage($snapshot)
    $snapshotG.Clear($script:themeBack)
    foreach ($snapCard in @($Cards)) {
      $snapCard.DrawToBitmap($snapshot, (New-Object System.Drawing.Rectangle(($snapCard.Left - $ZoneX), 0, $snapCard.Width, $snapCard.Height)))
    }
  } catch {
    # 합성 실패 시 반환되지 못하는 Bitmap 을 여기서 직접 정리 (호출부 finally 가 못 봄 - 리뷰 지적)
    if ($snapshot) { try { $snapshot.Dispose() } catch { } }
    throw
  } finally {
    if ($snapshotG) { try { $snapshotG.Dispose() } catch { } }
  }
  return , $snapshot
}

function Start-LifeSlide {
  param([string]$Slider, [int]$Direction)
  if ($script:lifeSlideActive -or $script:running) { return }
  $slideCards = $(if ($Slider -eq 'target') { $script:lifeTargetCards } else { $script:lifeSkillCards })
  # 페이지 경계 재확인 (화살표 Enabled 가 1차 방어지만 이중 확인)
  $slideItemCount = $(if ($Slider -eq 'target') { @($script:lifeSkills[$script:lifeSkillIndex].Targets).Count } else { @($script:lifeSkills).Count })
  $slidePages = [Math]::Max(1, [Math]::Ceiling($slideItemCount / 3.0))
  $slideCurPage = $(if ($Slider -eq 'target') { $script:lifeTargetPage } else { $script:lifeSkillPage })
  $slideNewPage = $slideCurPage + $Direction
  if ($slideNewPage -lt 0 -or $slideNewPage -ge $slidePages) { return }
  $script:lifeSlideActive = $true
  $slideBefore = $null
  $slideAfter = $null
  $slideStripG = $null
  try {
    # 카드 존은 런타임 값으로 계산 (상수 419 는 실폭 418 과 1px 어긋남 - 리뷰 지적)
    $slideZoneX = [int]$slideCards[0].Left
    $slideZoneY = [int]$slideCards[0].Top
    $slideZoneW = [int]$slideCards[2].Right - $slideZoneX
    $slideZoneH = [int]$slideCards[0].Height
    $slideBefore = New-LifeSlideSnapshot -Cards $slideCards -ZoneX $slideZoneX -ZoneW $slideZoneW -ZoneH $slideZoneH
    # 실제 상태를 새 페이지로 갱신 (Update-LifeSliders 의 화살표 갱신은 canNavigate 게이트가 잠금 유지)
    if ($Slider -eq 'target') { $script:lifeTargetPage = $slideNewPage } else { $script:lifeSkillPage = $slideNewPage }
    Update-LifeSliders
    $slideAfter = New-LifeSlideSnapshot -Cards $slideCards -ZoneX $slideZoneX -ZoneW $slideZoneW -ZoneH $slideZoneH
    # 두 페이지 스트립 구성 (다음 = before|after 왼쪽으로 / 이전 = after|before 오른쪽으로)
    $script:lifeSlideStrip = New-Object System.Drawing.Bitmap(($slideZoneW * 2), $slideZoneH)
    $slideStripG = [System.Drawing.Graphics]::FromImage($script:lifeSlideStrip)
    if ($Direction -gt 0) {
      $slideStripG.DrawImage($slideBefore, 0, 0)
      $slideStripG.DrawImage($slideAfter, $slideZoneW, 0)
    } else {
      $slideStripG.DrawImage($slideAfter, 0, 0)
      $slideStripG.DrawImage($slideBefore, $slideZoneW, 0)
    }
    # 임시 클리핑 Panel + 스트립 PictureBox (dots/화살표는 존 밖이라 안 덮임)
    $script:lifeSlideOverlayPanel = New-Object System.Windows.Forms.Panel
    $script:lifeSlideOverlayPanel.Location = New-Object System.Drawing.Point($slideZoneX, $slideZoneY)
    $script:lifeSlideOverlayPanel.Size = New-Object System.Drawing.Size($slideZoneW, $slideZoneH)
    $script:lifeSlideOverlayPanel.BackColor = $script:themeBack
    $grpContentDetail.Controls.Add($script:lifeSlideOverlayPanel)
    $script:lifeSlideOverlayPanel.BringToFront()
    $script:lifeSlidePicture = New-Object System.Windows.Forms.PictureBox
    $script:lifeSlidePicture.BorderStyle = 'None'
    $script:lifeSlidePicture.Location = New-Object System.Drawing.Point($(if ($Direction -gt 0) { 0 } else { -$slideZoneW }), 0)
    $script:lifeSlidePicture.Size = New-Object System.Drawing.Size(($slideZoneW * 2), $slideZoneH)
    $script:lifeSlidePicture.Image = $script:lifeSlideStrip
    $script:lifeSlideOverlayPanel.Controls.Add($script:lifeSlidePicture)
    $script:lifeSlideDirection = $Direction
    $script:lifeSlideWidth = $slideZoneW
    $script:lifeSlideSw = [System.Diagnostics.Stopwatch]::StartNew()
    $script:lifeSlideTimer.Start()
  } catch {
    # 어떤 실패도 즉시 스냅 + 잠금 해제로 수렴 (페이지 값은 이미 반영돼 있어 즉시 전환과 동일)
    Stop-LifeSlideNow
  } finally {
    if ($slideStripG) { try { $slideStripG.Dispose() } catch { } }
    if ($slideBefore) { try { $slideBefore.Dispose() } catch { } }
    if ($slideAfter) { try { $slideAfter.Dispose() } catch { } }
  }
}

$btnLifeSkillPrev.Add_Click({ Start-LifeSlide -Slider 'skill' -Direction -1 })
$btnLifeSkillNext.Add_Click({ Start-LifeSlide -Slider 'skill' -Direction 1 })
$btnLifeTargetPrev.Add_Click({ Start-LifeSlide -Slider 'target' -Direction -1 })
$btnLifeTargetNext.Add_Click({ Start-LifeSlide -Slider 'target' -Direction 1 })
$rbLifeGather.Add_CheckedChanged({ if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels } })

function Update-MainCategoryVisual {
  # 대분류 버튼의 활성/비활성 스타일 전체 재설정 (활성 = 시작 버튼과 같은 꿀색 강조.
  # 전환 시 비활성 쪽의 폰트/테두리까지 원상 복구 - 리뷰 조건 E)
  # 기타 버튼도 2026-08-15 부터 아이콘(catEtc = work1.png 내장) 포함 - 3버튼 모두 Paint 구독
  foreach ($catPair in @(, @($btnCatBattle, 'battle', 'catBattle')) + @(, @($btnCatLife, 'life', 'catLife')) + @(, @($btnCatEtc, 'etc', 'catEtc'))) {
    $catButton = $catPair[0]
    $catActive = ($script:mainCategory -eq [string]$catPair[1])
    $catIconKey = [string]$catPair[2]
    $catButton.FlatStyle = 'Flat'
    if ($catActive) {
      $catButton.BackColor = $script:themeHoney
      $catButton.ForeColor = $script:themeHoneyInk
      $catButton.FlatAppearance.BorderSize = 0
      $catButton.Font = $script:lifeCardFontBold
    } else {
      $catButton.BackColor = $script:themeControl
      $catButton.ForeColor = $script:themeText
      $catButton.FlatAppearance.BorderColor = $script:themeBorder
      $catButton.FlatAppearance.BorderSize = 1
      $catButton.Font = $script:lifeCardFontNormal
    }
    # 아이콘은 Paint(Invoke-MainCatButtonPaint)가 상태별로 직접 그림 - 상태 변경 시 다시 그리기
    $catButton.Invalidate()
  }
}

function Set-MainCategory {
  # 대분류(전투/생활) 전환 단일 진입점 (리뷰 조건 B): 상태 변경 → 버튼 스타일 →
  # 패널/설정/설명서/커스텀 처리와 레이아웃 재계산은 updateCategoryPanels 가 일괄 담당.
  # 실행 중에는 전환 금지 (Set-UiRunning 이 버튼을 잠그지만 이중 방어 - 리뷰 조건 C)
  param([string]$Category)
  # 진행 중 슬라이드는 즉시 정리 (같은 카테고리 재클릭의 조기 반환보다 먼저 - 리뷰 조건:
  # 조기 반환 경로에서 잠금이 남지 않게 Stop 이 스스로 UI 복원)
  if ($script:lifeSlideActive) { Stop-LifeSlideNow }
  if ($script:running) { return }
  if ($Category -ne 'life' -and $Category -ne 'etc') { $Category = 'battle' }
  if ($script:mainCategory -eq $Category) { return }
  $script:mainCategory = $Category
  Update-MainCategoryVisual
  if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
}

function Test-LifeStartBlocked {
  # 생활 대분류 시작 게이트 (v2.0.0): 낚시를 제외한 채집 8종만 시작 허용
  # (2026-08-07 양털 깎기·추수·호미질·곤충 채집 추가 - 전 대상 전수 배치 검증 완료).
  # 채집 자동화 자체는 2026-08-05 워커 단독 실기 1사이클 통과로 차단 해제 (설계 합의 조건).
  # 가공·미지원 스킬은 워커가 어차피 코드 4로 안내 정지하지만, 시작 전에 즉답 팝업으로
  # 알려 주는 쪽이 무인 반복 진입을 막습니다. 팝업은 GUI 팝업 금지 규칙의 허용 예외 ②
  # (사용자 버튼 클릭 즉답 - F9 도 PerformClick 경유라 같은 경로).
  # 승인 비동기 콜백의 우회 시작을 막기 위해 Invoke-StartAutomation 서두에서도 호출 (리뷰 조건 D)
  if ($script:mainCategory -ne 'life') { return $false }
  if ($rbLifeProcess.Checked) {
    [System.Windows.Forms.MessageBox]::Show(
      '가공 자동화는 아직 개발 중입니다. 현재는 채집만 사용할 수 있습니다.',
      '가공 준비 중',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    return $true
  }
  # 커스텀 반복에서는 슬라이더가 '담기용'이라 실제 실행 대상이 아닙니다 - 리스트가 결정하므로
  # 슬라이더 선택으로 시작을 막으면 안 됩니다 (리스트에 미지원 스킬이 들어갈 수 없게
  # [추가] 시점에서 이미 차단합니다. 빈 리스트 검사는 커스텀 시작 게이트 담당 - 2026-08-08)
  if ($rbCustomRepeat.Checked) { return $false }
  $selectedLifeSkill = $script:lifeSkills[$script:lifeSkillIndex]
  if ($script:lifeSupportedSkillIds -notcontains [string]$selectedLifeSkill.Id) {
    [System.Windows.Forms.MessageBox]::Show(
      ("'" + [string]$selectedLifeSkill.Name + "' 자동화는 아직 지원하지 않습니다." + [Environment]::NewLine +
        "현재 지원: 낚시를 제외한 채집 8종"),
      '채집 스킬 준비 중',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    return $true
  }
  return $false
}

# --- 설정 (on/off) ---
$grpSettings = New-Object System.Windows.Forms.GroupBox
$grpSettings.Text = '설정'
$grpSettings.Location = New-Object System.Drawing.Point(15, 340)
$grpSettings.Size = New-Object System.Drawing.Size(514, 150)
$form.Controls.Add($grpSettings)

$chkSpace = New-Object System.Windows.Forms.CheckBox
$chkSpace.Text = '자동출발 (Space)'
$chkSpace.Location = New-Object System.Drawing.Point(15, 25)
$chkSpace.Size = New-Object System.Drawing.Size(150, 22)
$grpSettings.Controls.Add($chkSpace)

$chkFood = New-Object System.Windows.Forms.CheckBox
$chkFood.Text = '음식 자동 먹기 (B)'
$chkFood.Location = New-Object System.Drawing.Point(183, 25)   # 체크 가로 배치 (2026-08-13 시안 - 버튼 열과 같은 x)
$chkFood.Size = New-Object System.Drawing.Size(150, 22)
$grpSettings.Controls.Add($chkFood)

$chkRevive = New-Object System.Windows.Forms.CheckBox
$chkRevive.Text = '자동부활 (불사의 가루)'
$chkRevive.Location = New-Object System.Drawing.Point(15, 52)
$chkRevive.Size = New-Object System.Drawing.Size(185, 22)
$grpSettings.Controls.Add($chkRevive)

# 어시스트 자동 켜기 (2026-07-28 사용자 요청): 전투 중 우측 ASSIST 토글이 꺼져 있으면 H키로 켬.
# 배치는 체크 가로 1줄의 3번째 열 (2026-08-13 시안 - 버튼 열과 같은 x 15/183/351 정렬)
$chkAssist = New-Object System.Windows.Forms.CheckBox
$chkAssist.Text = '어시스트 자동 켜기 (H)'
$chkAssist.Location = New-Object System.Drawing.Point(351, 25)
$chkAssist.Size = New-Object System.Drawing.Size(158, 22)
$grpSettings.Controls.Add($chkAssist)

# 권장 창 모드 버튼: 클릭하면 크기 선택 메뉴(1272 추천 / 1908)가 버튼 아래 열리고, 항목을
# 누르면 게임 창을 그 크기로 즉시 변경합니다 (2026-08-13 시안 확정 - 기존 자동 결정에서
# 사용자 선택으로 변경). 한 번 맞춰두면 매 회차 자동 보정이 그 크기를 그대로 유지합니다.
# 1272 추천 근거: 캡처 확대가 '기준 크기(1272)×배율' 고정이라 1908은 실효 배율이 1.5로
# 나뉘어 떨어짐 - 제목 열화 계열 실사고 전부가 1908 창 (이슈 이력 08-11~13).
$btnRecommendedWindow = New-Object System.Windows.Forms.Button
$btnRecommendedWindow.Text = '권장 창 모드 ▾'
$btnRecommendedWindow.Location = New-Object System.Drawing.Point(15, 110)   # 아래 가로 1줄 (2026-08-13 시안 - 생활과 동일 배치)
$btnRecommendedWindow.Size = New-Object System.Drawing.Size(158, 28)
$grpSettings.Controls.Add($btnRecommendedWindow)

# 크기 선택 드롭다운 - 버튼 클릭 즉답 UI 라 GUI 팝업 금지 규칙의 예외 ②에 해당.
# 열 때마다 현재 게임 창의 물리 크기를 읽어 일치하는 항목에 체크(✓)를 표시합니다.
$menuRecommendedWindow = New-Object System.Windows.Forms.ContextMenuStrip
$menuItemWin1272 = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemWin1272.Text = '1272 x 717   (추천)'
$menuItemWin1908 = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemWin1908.Text = '1908 x 1076  (큰 모니터용)'
[void]$menuRecommendedWindow.Items.Add($menuItemWin1272)
[void]$menuRecommendedWindow.Items.Add($menuItemWin1908)
# 실행 중 크기 변경 금지 (교차 리뷰): 워커의 좌표 계산·캡처와 리사이즈가 경쟁하면 이전
# 좌표를 클릭할 수 있음. 버튼(메뉴 열기)과 항목 클릭 양쪽에서 막습니다 (이중 가드 -
# 메뉴를 열어 둔 채 시작을 누르는 틈까지 차단).
function Test-ResizeBlockedByRunning {
  if ($script:running) {
    Add-GuiLog '[안내] 자동화 실행 중에는 창 크기를 바꾸지 않습니다 (판독·클릭 좌표와 충돌 방지) - 중지 후 다시 눌러 주세요'
    return $true
  }
  if ($script:resizePending) {
    # 직전 변경의 헬퍼가 아직 끝나지 않음 - 연속 선택이 서로 덮어쓰는 경쟁 방지 (교차 리뷰)
    Add-GuiLog '[안내] 직전 창 크기 변경이 진행 중입니다 - 몇 초 뒤 다시 눌러 주세요'
    return $true
  }
  return $false
}
$menuItemWin1272.Add_Click({ if (Test-ResizeBlockedByRunning) { return }; Apply-RecommendedWindowSize -Width 1272 -Height 717 })
$menuItemWin1908.Add_Click({ if (Test-ResizeBlockedByRunning) { return }; Apply-RecommendedWindowSize -Width 1908 -Height 1076 })
$menuRecommendedWindow.Add_Opening({
    # 체크 갱신 - 판독 실패($null)면 둘 다 체크 없음 (적용 동작에는 영향 없음)
    $physicalSize = Get-GameWindowPhysicalSize
    $sizeMatch = if ($physicalSize) { Get-RecommendedSizeMatch -PhysicalWidth $physicalSize.Width -PhysicalHeight $physicalSize.Height } else { '' }
    $menuItemWin1272.Checked = ($sizeMatch -eq '1272')
    $menuItemWin1908.Checked = ($sizeMatch -eq '1908')
  })

# 크기 변경 결과 타이머: DPI 헬퍼(별도 프로세스)가 남긴 결과 파일을 읽어 로그로 안내합니다
# (성공 / 모니터보다 커서 거부 / 게임 없음). 0.5초 x 8회 안에 없으면 안내 후 종료.
$script:resizeResultPath = ''   # 요청마다 GUID 파일로 새로 발급 (Apply-RecommendedWindowSize)
$script:resizeResultTicks = 0
$script:resizePending = $false  # 리사이즈 헬퍼 진행 중 표시 - 시작·추가 리사이즈를 잠깐 차단
$script:timerResizeResult = New-Object System.Windows.Forms.Timer
$script:timerResizeResult.Interval = 500
$script:timerResizeResult.Add_Tick({
    # 타이머 틱은 통째로 try/catch (교차 리뷰 - 이 저장소 실측 계약: 타이머 예외는 PS 5.1
    # 모달 오류창으로 이어져 무인 자동화 전체를 멈춤. TEMP 접근 오류 등도 여기서 삼킴)
    try {
      $script:resizeResultTicks++
      $resizeResultLine = $null
      if ($script:resizeResultPath -and (Test-Path -LiteralPath $script:resizeResultPath)) {
        $resizeResultLine = ([string](Get-Content -LiteralPath $script:resizeResultPath -ErrorAction SilentlyContinue | Select-Object -First 1)).Trim()
      }
      if ($resizeResultLine) {
        $script:timerResizeResult.Stop()
        $script:resizePending = $false
        Remove-Item -LiteralPath $script:resizeResultPath -ErrorAction SilentlyContinue
        if ($resizeResultLine -like 'ok *') {
          Add-GuiLog "[안내] 게임 창 크기 변경 완료: $($resizeResultLine.Substring(3))"
        } elseif ($resizeResultLine -like 'too-big *') {
          Add-GuiLog "[경고] 선택한 크기($($resizeResultLine.Substring(8)))가 모니터 작업 영역보다 큽니다 - 적용하지 않았습니다. 1272 x 717을 사용해 주세요"
        } elseif ($resizeResultLine -like 'failed *') {
          Add-GuiLog "[경고] 창 크기 변경이 적용되지 않았습니다 (현재 $($resizeResultLine.Substring(7)) - 게임이 크기를 거부했을 수 있음) - 게임 창을 직접 확인해 주세요"
        } elseif ($resizeResultLine -eq 'no-game') {
          Add-GuiLog '[경고] 게임 창을 찾지 못해 크기를 변경하지 못했습니다 - 게임 실행 후 다시 눌러 주세요'
        }
        return
      }
      if ($script:resizeResultTicks -ge 8) {
        $script:timerResizeResult.Stop()
        $script:resizePending = $false
        Add-GuiLog '[안내] 창 크기 변경 결과를 확인하지 못했습니다 - 게임 창 크기를 직접 확인해 주세요'
      }
    } catch {
      $script:resizePending = $false
      try { $script:timerResizeResult.Stop() } catch { }
    }
  })

# '적용된 설정' 버튼: 설정 그룹에서 켜 둔 항목과 기본 설정 기능(항상 자동 동작)을
# 한 팝업으로 보여줍니다 (설정 저장 버튼 위). 콘텐츠/난이도 등은 화면에서 바로
# 보이므로 팝업에는 넣지 않습니다. 켠 항목만 누를 때 상태를 읽어 표시합니다.
$btnAlwaysOn = New-Object System.Windows.Forms.Button
$btnAlwaysOn.Text = '적용된 설정'
$btnAlwaysOn.Location = New-Object System.Drawing.Point(183, 110)
$btnAlwaysOn.Size = New-Object System.Drawing.Size(158, 28)
$grpSettings.Controls.Add($btnAlwaysOn)

$btnAlwaysOn.Add_Click({
    # 생활 대분류: 전투 체크박스 대신 생활 설정만 표시 (리뷰 조건 G.
    # 가공 선택 중에는 채집 전용 항목을 생략해 화면 상태와 일치 - 리뷰 권고)
    if ($script:mainCategory -eq 'life') {
      # '준비 중' 안내는 **아직 지원하지 않는 것에만** 붙입니다 (2026-08-08 사용자 지시).
      # 채집 8종은 전 대상 실기 검증까지 끝났는데 머리글이 계속 '준비 중'이라 사실과 달랐습니다.
      $lifeLines = New-Object System.Collections.Generic.List[string]
      $lifeLines.Add('[생활 설정]')
      if ($rbLifeProcess.Checked) {
        $lifeLines.Add(' - 콘텐츠: 가공 (아직 지원하지 않습니다 - 시작할 수 없음)')
      } else {
        $lifeSkillNow = $script:lifeSkills[$script:lifeSkillIndex]
        $lifeTargetsNow = @($lifeSkillNow.Targets)
        $lifeTargetName = $(if ($script:lifeTargetIndex -lt $lifeTargetsNow.Count) { [string]$lifeTargetsNow[$script:lifeTargetIndex] } else { '' })
        $lifeLines.Add(' - 콘텐츠: 채집')
        $lifeSkillNote = $(if ($script:lifeSupportedSkillIds -contains [string]$lifeSkillNow.Id) { '' } else { ' (아직 지원하지 않습니다 - 시작할 수 없음)' })
        $lifeLines.Add(" - 채집 스킬: $([string]$lifeSkillNow.Name)$lifeSkillNote")
        $lifeLines.Add(" - 채집 대상: $lifeTargetName")
        $lifeLines.Add(" - 진행 없음 한도: $([int]$numGatherWait.Value)초 (총 시간 제한 아님)")
      }
      [System.Windows.Forms.MessageBox]::Show(($lifeLines -join "`n"), '적용된 설정',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
      return
    }
    # 체크박스 항목은 켠 것만 표시합니다 (꺼진 항목은 줄 자체를 생략)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('[내가 선택한 설정] (켠 항목만 표시)')
    $lines.Add(" - 클리어 대기: $([int]$numClearWait.Value)초")
    if ($chkSpace.Checked) { $lines.Add(" - $($chkSpace.Text)") }
    if ($chkFood.Checked) { $lines.Add(" - $($chkFood.Text)") }
    if ($chkRevive.Checked) { $lines.Add(" - $($chkRevive.Text)") }
    if ($chkAssist.Checked) { $lines.Add(" - $($chkAssist.Text)") }
    $lines.Add('')
    $lines.Add('[기본 설정 기능]')
    $lines.Add('<화면/창 관리>')
    $lines.Add(' - 게임 창 자동 정렬 (크기·위치 보정)')
    $lines.Add(' - 게임 창이 가려지면 자동 복구')
    $lines.Add(' - 화면 캡처 실패 시 일시정지 후 자동 복구 (최소화/끊김/재접속 구분 안내)')
    $lines.Add('')
    $lines.Add('<진행 자동 처리>')
    $lines.Add(' - 출석 자동 넘기기(우편보상지급)')
    $lines.Add(' - 오늘의 스텔라 픽 자동 확정')
    $lines.Add(' - 공지/이벤트 팝업 자동 닫기')
    $lines.Add(' - 보스방/엔딩 컷신 자동 스킵')
    $lines.Add(' - 구매 안내 팝업(물약 부족 등) 자동 닫기')
    $lines.Add(' - 자동사냥 꺼짐 감시 (꺼져 있으면 자동출발)')
    $lines.Add(' - 클릭이 빗나가면 확인 후 자동 재클릭')
    $lines.Add(" - 던전 입장 확인 팝업 '일주일 동안 보지 않기' 자동 체크")
    $lines.Add(' - 은동전 소탕 전리품 공개 화면 자동 진행')
    $lines.Add(' - 부활 재료(불사의 가루) 부족 시 여신상 부활로 자동 전환')
    $appliedText = ($lines -join "`n")
    [System.Windows.Forms.MessageBox]::Show($appliedText, '적용된 설정',
      [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
  })

# '?' 도움말 버튼: 파란 원형 배지, 클릭하면 클리어 대기 시간 설명 팝업
$btnClearHelp = New-Object System.Windows.Forms.Button
$btnClearHelp.Text = '?'
$btnClearHelp.Location = New-Object System.Drawing.Point(210, 52)   # 클리어 대기 줄을 자동부활 오른쪽으로 (2026-08-13 시안)
$btnClearHelp.Size = New-Object System.Drawing.Size(18, 18)
$btnClearHelp.FlatStyle = 'Flat'
$btnClearHelp.FlatAppearance.BorderSize = 0
$btnClearHelp.BackColor = [System.Drawing.Color]::SteelBlue
$btnClearHelp.ForeColor = [System.Drawing.Color]::White
$btnClearHelp.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
$btnClearHelp.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnClearHelp.TextAlign = 'MiddleCenter'
# 버튼을 원형으로 잘라냅니다
$helpCirclePath = New-Object System.Drawing.Drawing2D.GraphicsPath
$helpCirclePath.AddEllipse(0, 0, $btnClearHelp.Width, $btnClearHelp.Height)
$btnClearHelp.Region = New-Object System.Drawing.Region($helpCirclePath)
$grpSettings.Controls.Add($btnClearHelp)

$btnClearHelp.Add_Click({
    $helpText = "던전에 입장한 뒤 '던전 클리어!' 화면이 뜰 때까지 기다리는 최대 시간입니다.`n`n" +
    "- 클리어가 감지되면 즉시 다음 단계로 넘어갑니다 (설정한 시간을 다 기다리지 않음)`n" +
    "- 이 시간을 넘겨도 클리어 화면이 안 나오면 문제가 생긴 것으로 판단하고 그 회차를 중단합니다`n`n" +
    "즉, '한 판이 아무리 길어도 이 시간 안에는 끝난다'는 안전 한도입니다.`n" +
    "보통 한 판에 3~4분 걸리므로 기본값 600초(10분)면 충분하고,`n" +
    "더 오래 걸리는 던전이라면 여유 있게 늘려 주세요."
    [System.Windows.Forms.MessageBox]::Show($helpText, '클리어 대기 시간이란?',
      [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
  })

$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.SetToolTip($btnClearHelp, '클릭하면 자세한 설명이 나옵니다')
$toolTip.SetToolTip($chkRevive, "전투 중 행동불능이 되면 남은 부활 횟수를 확인해 R키(여기서 부활)로 자동 부활합니다.`r`n남은 횟수가 없으면 '여신상에서 부활'을 클릭해 이어갑니다.`r`n불사의 가루 등 부활 재화가 소모될 수 있으니 원치 않으면 꺼 두세요.")
$toolTip.SetToolTip($chkAssist, "전투 중 화면 우측의 ASSIST(어시스트 모드) 토글이 꺼져 있으면 자동으로 H키를 눌러 켭니다.`r`n분홍(클래스 특화)/초록(일반) 어느 쪽이든 켜져 있으면 건드리지 않습니다.")
$toolTip.SetToolTip($chkCrRandom, "켜면 매 바퀴 시작 때 리스트 순서를 무작위로 섞어 진행합니다 (항목 구성은 동일).`r`n1층·2층이 섞인 리스트에서는 사용할 수 없습니다.")
$toolTip.SetToolTip($chkDcrRandom, "켜면 매 바퀴 시작 때 리스트 순서를 무작위로 섞어 진행합니다 (항목 구성은 동일).`r`n1층·2층이 섞인 리스트에서는 사용할 수 없습니다.")
$toolTip.SetToolTip($chkAcrRandom, "켜면 매 바퀴 시작 때 리스트 순서를 무작위로 섞어 진행합니다 (항목 구성은 동일).")

$lblClearWait = New-Object System.Windows.Forms.Label
$lblClearWait.Text = '클리어 대기(초):'
$lblClearWait.Location = New-Object System.Drawing.Point(236, 53)
$lblClearWait.Size = New-Object System.Drawing.Size(95, 20)
$grpSettings.Controls.Add($lblClearWait)

$numClearWait = New-Object System.Windows.Forms.NumericUpDown
$numClearWait.Location = New-Object System.Drawing.Point(333, 50)
$numClearWait.Size = New-Object System.Drawing.Size(65, 24)
$numClearWait.Minimum = 60
$numClearWait.Maximum = 10800
$numClearWait.Value = 600
$grpSettings.Controls.Add($numClearWait)

# 초 → 분·초 환산 표시 (값이 바뀔 때마다 자동 갱신)
$lblClearHuman = New-Object System.Windows.Forms.Label
$lblClearHuman.Location = New-Object System.Drawing.Point(404, 53)
$lblClearHuman.Size = New-Object System.Drawing.Size(105, 20)   # x404 + 105 = 509 (그룹 폭 514 안 - 교차 리뷰)
$lblClearHuman.ForeColor = [System.Drawing.Color]::SteelBlue
$grpSettings.Controls.Add($lblClearHuman)

# 생활(채집) 전용: '채집 대기(초)' 줄 - 전투의 체크박스/클리어 대기 줄과 교대 표시
# (updateCategoryPanels 가 mainCategory 에 따라 Visible 전환)
# 의미는 '총 시간'이 아니라 **진행이 멈춘 채로 견디는 시간**입니다 (2026-08-08 설계 변경 -
# 총 시간으로 재면 대상별 소요(실측 100~520초)를 사용자가 미리 알아야 숫자를 정할 수 있음).
$lblGatherWait = New-Object System.Windows.Forms.Label
$lblGatherWait.Text = '진행 없음(초):'
$lblGatherWait.Location = New-Object System.Drawing.Point(15, 28)
$lblGatherWait.Size = New-Object System.Drawing.Size(95, 20)
$lblGatherWait.Visible = $false
$grpSettings.Controls.Add($lblGatherWait)

$numGatherWait = New-Object System.Windows.Forms.NumericUpDown
$numGatherWait.Location = New-Object System.Drawing.Point(112, 25)
$numGatherWait.Size = New-Object System.Drawing.Size(65, 24)
$numGatherWait.Minimum = 60
$numGatherWait.Maximum = 3600
$numGatherWait.Value = 600
$numGatherWait.Visible = $false
$grpSettings.Controls.Add($numGatherWait)
$toolTip.SetToolTip($numGatherWait, ("채집 수량이 늘지 않은 채로 이 시간이 지나면 멈춥니다." + [Environment]::NewLine +
    "수량이 오르는 동안은 오래 걸려도 자르지 않습니다 (총 시간 제한이 아닙니다)." + [Environment]::NewLine +
    "이동이 아주 먼 대상에서 멈추면 늘려 주세요. 기본 600초 권장."))
$toolTip.SetToolTip($lblGatherWait, ("채집 수량이 늘지 않은 채로 이 시간이 지나면 멈춥니다." + [Environment]::NewLine +
    "수량이 오르는 동안은 오래 걸려도 자르지 않습니다 (총 시간 제한이 아닙니다)."))

$lblGatherHuman = New-Object System.Windows.Forms.Label
$lblGatherHuman.Location = New-Object System.Drawing.Point(185, 28)
$lblGatherHuman.Size = New-Object System.Drawing.Size(160, 20)
$lblGatherHuman.Visible = $false
$grpSettings.Controls.Add($lblGatherHuman)

$updateGatherHuman = {
  $gatherSeconds = [int]$numGatherWait.Value
  $gatherMinutes = [Math]::Floor($gatherSeconds / 60)
  $gatherRemain = $gatherSeconds % 60
  $lblGatherHuman.Text = $(if ($gatherMinutes -gt 0 -and $gatherRemain -gt 0) { "= ${gatherMinutes}분 ${gatherRemain}초" }
    elseif ($gatherMinutes -gt 0) { "= ${gatherMinutes}분" } else { "= ${gatherSeconds}초" })
}
$numGatherWait.Add_ValueChanged($updateGatherHuman)
& $updateGatherHuman

$updateClearHuman = {
  $totalSeconds = [int]$numClearWait.Value
  $hours = [Math]::Floor($totalSeconds / 3600)
  $minutes = [Math]::Floor(($totalSeconds % 3600) / 60)
  $seconds = $totalSeconds % 60
  $parts = @()
  if ($hours -gt 0) { $parts += "${hours}시간" }
  if ($minutes -gt 0) { $parts += "${minutes}분" }
  if ($seconds -gt 0 -or $parts.Count -eq 0) { $parts += "${seconds}초" }
  $lblClearHuman.Text = '= ' + ($parts -join ' ')
}
$numClearWait.Add_ValueChanged($updateClearHuman)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = '설정 저장'
$btnSave.Location = New-Object System.Drawing.Point(351, 110)
$btnSave.Size = New-Object System.Drawing.Size(158, 28)
$grpSettings.Controls.Add($btnSave)

$lblSaveInfo = New-Object System.Windows.Forms.Label
$lblSaveInfo.Text = ''
$lblSaveInfo.Location = New-Object System.Drawing.Point(353, 88)
$lblSaveInfo.Size = New-Object System.Drawing.Size(156, 20)   # x353 + 156 = 509 (그룹 폭 안 - 교차 리뷰)
$lblSaveInfo.ForeColor = [System.Drawing.Color]::SeaGreen
$grpSettings.Controls.Add($lblSaveInfo)

# --- 로그 ---
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Location = New-Object System.Drawing.Point(15, 498)
$txtLog.Size = New-Object System.Drawing.Size(514, 300)
# 창 크기를 조절하면 로그 영역이 함께 늘어나고 줄어듭니다
$txtLog.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font('Consolas', 9)
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 30)
$txtLog.ForeColor = [System.Drawing.Color]::Gainsboro
$form.Controls.Add($txtLog)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text = 'Log 폴더 열기'
$btnOpenLog.Location = New-Object System.Drawing.Point(15, 806)
$btnOpenLog.Size = New-Object System.Drawing.Size(100, 28)   # [설정] 토글과 동일 폭 (2026-08-04 요청)
$btnOpenLog.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($btnOpenLog)

$lblFontSize = New-Object System.Windows.Forms.Label
$lblFontSize.Text = '로그 글자 크기:'
$lblFontSize.Location = New-Object System.Drawing.Point(140, 812)
$lblFontSize.Size = New-Object System.Drawing.Size(88, 20)
$lblFontSize.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($lblFontSize)

$numFontSize = New-Object System.Windows.Forms.NumericUpDown
$numFontSize.Location = New-Object System.Drawing.Point(230, 809)
$numFontSize.Size = New-Object System.Drawing.Size(48, 24)
$numFontSize.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$numFontSize.Minimum = 8
$numFontSize.Maximum = 20
$numFontSize.Value = 9
$form.Controls.Add($numFontSize)

$numFontSize.Add_ValueChanged({
    # Font 속성을 바꾸면 기존 색상 서식이 리셋되므로, 색을 보존하는 확대 배율로 크기를 조절합니다
    $txtLog.ZoomFactor = [float]([int]$numFontSize.Value / 9.0)
    if ($script:uiReady) {
      # 선택한 크기를 config 에 저장해 다음 실행에도 유지
      $cfg = Read-Config
      if ($cfg) {
        if ($cfg.PSObject.Properties['ui']) {
          if ($cfg.ui.PSObject.Properties['logFontSize']) { $cfg.ui.logFontSize = [int]$numFontSize.Value }
          else { $cfg.ui | Add-Member -NotePropertyName 'logFontSize' -NotePropertyValue ([int]$numFontSize.Value) }
        } else {
          $cfg | Add-Member -NotePropertyName 'ui' -NotePropertyValue ([pscustomobject]@{ logFontSize = [int]$numFontSize.Value })
        }
        try { Save-Config $cfg }
        catch { Add-GuiLog "[경고] 로그 글자 크기 저장 실패: $($_.Exception.Message)" }
      }
    }
  })

$btnClearLog = New-Object System.Windows.Forms.Button
$btnClearLog.Text = '로그 지우기'
$btnClearLog.Location = New-Object System.Drawing.Point(280, 806)
$btnClearLog.Size = New-Object System.Drawing.Size(80, 28)
$btnClearLog.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($btnClearLog)

# 앱 버전 표시 (로그 지우기 버튼 옆 - 제목줄보다 눈에 잘 띄는 위치)
$lblVersion = New-Object System.Windows.Forms.Label
$lblVersion.Text = "v$appVersion"
$lblVersion.Location = New-Object System.Drawing.Point(369, 812)
$lblVersion.Size = New-Object System.Drawing.Size(160, 20)
$lblVersion.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblVersion.ForeColor = [System.Drawing.Color]::DimGray
$lblVersion.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($lblVersion)

# 새 버전 안내 링크 (평소 숨김 - 시작 시 최신 버전 확인에서 새 버전이 감지되면
# 버전 표시 대신 이 링크가 나타나고, 클릭하면 GitHub 릴리스 페이지가 열립니다)
$lnkUpdate = New-Object System.Windows.Forms.LinkLabel
$lnkUpdate.Location = New-Object System.Drawing.Point(369, 812)
$lnkUpdate.Size = New-Object System.Drawing.Size(160, 20)
$lnkUpdate.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lnkUpdate.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$lnkUpdate.Visible = $false
$lnkUpdate.Add_LinkClicked({ Start-Process 'https://github.com/Myodong/HoneyNogi/releases/latest' })
$form.Controls.Add($lnkUpdate)

# ----- 탭 토글: 설정/로그 표시 (2026-08-04 시안 확정 - 각각 독립 열림/닫힘, 설정 위·로그 아래) -----
# CheckBox Appearance='Button' = 눌린 상태 유지 시각을 공짜로 얻음. 실행 중에도 사용해야
# 하므로 Set-UiRunning 잠금 그룹(반복/콘텐츠/상세)에 넣지 않습니다. 배치·폼 높이는
# updateCategoryPanels 끝의 적용부가, 순수 계산은 Get-TabToggleLayout(진리표 테스트 대상)이 담당.
$script:logViewHeight = 150      # 로그 뷰포트 기억값 - 총 폼 높이가 아니라 로그 영역 높이만 기억해 설정을 접으면 폼도 함께 줄어듦 (리뷰 계약. 기본 150 = 2026-08-04 사용자 조정 - 300은 너무 높음, 늘리면 그 높이가 유지됨)
$script:logLayoutOpen = $null    # 직전 레이아웃의 로그 상태 3상태 토큰 (null=최초) - 열림이었을 때만 뷰포트를 흡수
$script:hiddenLogErrors = 0      # 로그 접힘 중 발생한 미열람 오류/경고 수 (토글 배지)
$script:hiddenLogWarns = 0
$script:footerGap = 28           # ClientHeight - 하단 줄 Top (아래에서 실측으로 갱신 - Bottom 앵커 지연과 무관하게 직접 계산용)

$chkTabSettings = New-Object System.Windows.Forms.CheckBox
$chkTabSettings.Appearance = 'Button'
$chkTabSettings.Text = '설정'
$chkTabSettings.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$chkTabSettings.Size = New-Object System.Drawing.Size(100, 32)
$chkTabSettings.FlatStyle = 'Flat'
$chkTabSettings.FlatAppearance.BorderColor = $script:themeBorder
$chkTabSettings.FlatAppearance.BorderSize = 1
$chkTabSettings.UseVisualStyleBackColor = $false   # 커스텀 배경색 확실 적용 (리뷰 조건)
$chkTabSettings.BackColor = $script:themeControl
$form.Controls.Add($chkTabSettings)

$chkTabLog = New-Object System.Windows.Forms.CheckBox
$chkTabLog.Appearance = 'Button'
$chkTabLog.Text = '로그'
$chkTabLog.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$chkTabLog.Size = New-Object System.Drawing.Size(100, 32)
$chkTabLog.FlatStyle = 'Flat'
$chkTabLog.FlatAppearance.BorderColor = $script:themeBorder
$chkTabLog.FlatAppearance.BorderSize = 1
$chkTabLog.UseVisualStyleBackColor = $false
$chkTabLog.BackColor = $script:themeControl
$form.Controls.Add($chkTabLog)

# 접힘 중 마지막 경고/오류 1줄 미리보기 (토글 줄 우측)
$lblLogPreview = New-Object System.Windows.Forms.Label
$lblLogPreview.Size = New-Object System.Drawing.Size(299, 20)
$lblLogPreview.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblLogPreview.AutoEllipsis = $true
$lblLogPreview.Text = ''
$form.Controls.Add($lblLogPreview)

function Update-LogTabBadge {
  # 접힘 중 미열람 오류/경고 배지 (오류 우선). 리셋은 로그를 실제로 열 때/로그 지우기 때만 -
  # 배지는 '새 회차'가 아니라 '마지막으로 로그를 본 뒤'의 의미라 회차 시작에 지우지 않음 (리뷰)
  if ($script:hiddenLogErrors -gt 0) {
    $chkTabLog.Text = "로그 ● 오류 $($script:hiddenLogErrors)"
    $chkTabLog.BackColor = $script:themeDanger
    $chkTabLog.ForeColor = [System.Drawing.Color]::White
  } elseif ($script:hiddenLogWarns -gt 0) {
    $chkTabLog.Text = "로그 ● 경고 $($script:hiddenLogWarns)"
    $chkTabLog.BackColor = [System.Drawing.Color]::Gold
    $chkTabLog.ForeColor = $script:themeHoneyInk
  }
}

function Update-TabToggleStyle {
  # 토글 눌림 배경 (안전 중지 버튼과 같은 크림). 로그 배지가 활성일 때는 배지 색이 우선.
  # 활성 = 캐러멜 (2026-08-04 C안 확정 - 연크림은 기본색과 구분이 안 됨)
  $chkTabSettings.BackColor = $(if ($chkTabSettings.Checked) { [System.Drawing.Color]::FromArgb(244, 213, 141) } else { $script:themeControl })
  $chkTabSettings.ForeColor = $(if ($chkTabSettings.Checked) { [System.Drawing.Color]::FromArgb(91, 62, 6) } else { $script:themeText })
  if ($script:hiddenLogErrors -gt 0 -or $script:hiddenLogWarns -gt 0) { Update-LogTabBadge; return }
  $chkTabLog.BackColor = $(if ($chkTabLog.Checked) { [System.Drawing.Color]::FromArgb(244, 213, 141) } else { $script:themeControl })
  $chkTabLog.ForeColor = $(if ($chkTabLog.Checked) { [System.Drawing.Color]::FromArgb(91, 62, 6) } else { $script:themeText })
}

function Reset-LogTabBadge {
  $script:hiddenLogErrors = 0
  $script:hiddenLogWarns = 0
  $chkTabLog.Text = '로그'
  $chkTabLog.ForeColor = $script:themeText
  $lblLogPreview.Text = ''
  Update-TabToggleStyle
}

function Save-UiToggleState {
  # 두 토글 상태를 항상 함께 저장 (ui.logFontSize 즉시 저장 패턴, 단일 헬퍼 통일 - 리뷰 조건)
  if (-not $script:uiReady) { return }
  $cfg = Read-Config
  if (-not $cfg) { return }
  if (-not $cfg.PSObject.Properties['ui']) {
    $cfg | Add-Member -NotePropertyName 'ui' -NotePropertyValue ([pscustomobject]@{})
  }
  foreach ($togglePair in @(, @('settingsOpen', [bool]$chkTabSettings.Checked)) + @(, @('logOpen', [bool]$chkTabLog.Checked))) {
    if ($cfg.ui.PSObject.Properties[[string]$togglePair[0]]) { $cfg.ui.([string]$togglePair[0]) = [bool]$togglePair[1] }
    else { $cfg.ui | Add-Member -NotePropertyName ([string]$togglePair[0]) -NotePropertyValue ([bool]$togglePair[1]) }
  }
  try { Save-Config $cfg }
  catch { Add-GuiLog "[경고] 설정/로그 표시 상태 저장 실패: $($_.Exception.Message)" }
}

$chkTabSettings.Add_CheckedChanged({
    Update-TabToggleStyle
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
    Save-UiToggleState
  })
$chkTabLog.Add_CheckedChanged({
    if ($chkTabLog.Checked) { Reset-LogTabBadge }   # 여는 순간 미열람 배지 해소
    Update-TabToggleStyle
    if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels }
    if ($chkTabLog.Checked) {
      # 숨김 중 생략했던 표시 상태 복구: 확대 배율 재적용 + 끝으로 스크롤 1회
      $txtLog.ZoomFactor = [float]([int]$numFontSize.Value / 9.0)
      $txtLog.SelectionStart = $txtLog.TextLength
      $txtLog.ScrollToCaret()
    }
    Save-UiToggleState
  })

# 하단 줄 간격 실측: ClientHeight - 하단 버튼 Top. 레이아웃이 폼 높이를 바꿔도 이 값으로
# 로그 높이를 직접 계산합니다 (SuspendLayout 중 Bottom 앵커 재배치 지연과 무관 - 리뷰 조건)
$script:footerGap = $form.ClientSize.Height - $btnOpenLog.Top

$btnClearLog.Add_Click({
    $txtLog.Clear()
    # Clear() 후에는 확대 배율이 1.0으로 초기화되므로 다시 적용합니다
    $txtLog.ZoomFactor = [float]([int]$numFontSize.Value / 9.0)
    # 지운 내용의 미열람 배지를 남기면 모순이므로 함께 리셋합니다 (리뷰 조건)
    Reset-LogTabBadge
    # 화면 표시만 지웁니다. Log 폴더의 파일 기록은 그대로 남습니다.
  })

# ============================================================
#  동작 로직
# ============================================================
function Add-ColoredLogLine {
  param([string]$Text)

  # 내용에 따라 색을 입혀 로그창에 한 줄 추가합니다. 색과 접힘 배지가 같은 심각도 판정을
  # 공유합니다 (2026-08-04 탭 토글 - 리뷰 계약).
  # ★ **태그를 먼저** 봅니다. 예전에는 '실패' 라는 낱말을 태그보다 앞서 검사해서, 워커의
  #   정상 로그가 빨강 오류로 뜨고 접힘 배지에도 오류로 계상됐습니다. 예를 들어
  #   `[안내] 커서 위치 확인이 정상으로 돌아왔습니다 (… 확인 실패 3회는 기록을 생략했습니다)`,
  #   `[완료] 화면 캡처 실패가 2분 이상 지속 - …`, 그리고 이번에 정직성을 높이며 새로 넣은
  #   `구매 팝업 감지 - 커서 확인 실패로 닫기 클릭을 건너뜀` 같은 줄이 전부 걸렸습니다.
  #   **로그를 정직하게 만들수록 오류 배지가 부푸는** 구조였습니다 (2026-08-09 5차 점검).
  #   태그가 붙은 줄은 태그가 정본이고, '실패' 휴리스틱은 태그 없는 줄에만 적용합니다.
  $severity = ''
  $lineColor = [System.Drawing.Color]::Gainsboro                                  # 기본(회백색)
  if ($Text -match '\[오류\]') {
    $lineColor = [System.Drawing.Color]::FromArgb(255, 110, 110)                  # 오류 = 빨강
    $severity = 'error'
  } elseif ($Text -match '\[경고\]') {
    $lineColor = [System.Drawing.Color]::Gold                                     # 경고 = 노랑
    $severity = 'warn'
  } elseif ($Text -match '\[안내\]|\[진단\]|\[중단\]') {
    $lineColor = [System.Drawing.Color]::SkyBlue                                  # 안내 = 하늘색
  } elseif ($Text -match '\[완료\]|회차 완료|===|복귀 확인') {
    $lineColor = [System.Drawing.Color]::LightGreen                               # 완료 = 초록
  } elseif ($Text -match '\[준비\]') {
    $lineColor = [System.Drawing.Color]::MediumPurple                             # 준비 = 보라
  } elseif ($Text -match '\[(던전|어비스|심층|사냥터|생활|기타|커스텀|파티원|설정)\]') {
    # 콘텐츠(도메인) 태그도 **태그가 붙은 줄**입니다. 워커의 계약은 '심각도는 [오류]/[경고]
    # 로만 표시한다' 이므로, 도메인 태그만 달린 줄은 정상 진행 기록입니다.
    # 5차에서 '태그 우선'으로 고쳤지만 심각도 태그 7종만 앞세웠고 도메인 태그는 빠져 있어,
    # 6차 AST 전수 스캔에서 **7줄**이 여전히 빨강 + 오류 배지로 새는 것을 확인했습니다:
    #   `[던전] 템플릿 좌표의 카드 픽셀 확인 실패 - 좌표는 실측 매핑이라 그대로 시도합니다`,
    #   `[생활] 목록 스크롤: 게임 전면화 실패로 건너뜀`,
    #   `[던전] 공물 소모량 재판독 실패 - 교차 검증을 건너뜁니다` 등 전부 정상 폴백입니다.
    # 낱말 하나씩 고쳐 봐야 새 로그가 생길 때마다 재발하므로 분류 규칙에서 닫습니다
    # (2026-08-09 6차 점검. 태그 목록의 완전성은 tests\test_log_severity.ps1 이 감시합니다).
    $lineColor = [System.Drawing.Color]::Gainsboro
  } elseif ($Text -match '오류 종료|실패') {
    # 태그가 전혀 없는 줄(GUI 자체 메시지 등)에만 낱말로 판정합니다
    $lineColor = [System.Drawing.Color]::FromArgb(255, 110, 110)
    $severity = 'error'
  }
  $txtLog.SelectionStart = $txtLog.TextLength
  $txtLog.SelectionLength = 0
  $txtLog.SelectionColor = $lineColor
  $txtLog.AppendText($Text + "`r`n")
  $txtLog.SelectionColor = $txtLog.ForeColor
  # 로그 접힘 판정은 논리 상태(토글 Checked)로 - $txtLog.Visible 은 폼 표시 전엔 열림
  # 상태여도 false 라 배지가 오작동합니다 (리뷰 지적)
  if (-not $chkTabLog.Checked) {
    if ($severity -eq 'error') { $script:hiddenLogErrors++ }
    elseif ($severity -eq 'warn') { $script:hiddenLogWarns++ }
    if ($severity) {
      $lblLogPreview.Text = $Text
      Update-LogTabBadge
    }
    return   # 접힘 중에는 ScrollToCaret 생략 (열 때 1회 수행)
  }
  $txtLog.ScrollToCaret()
}

function Add-GuiLog {
  param([string]$Message)
  Add-ColoredLogLine "$(Get-Date -Format 'HH:mm:ss') $Message"
}

function Get-TabToggleLayout {
  param(
    [int]$DetailBottom,
    [bool]$SettingsOpen,
    [bool]$LogOpen,
    [int]$LogViewHeight,
    [int]$SettingsHeight,
    [int]$FooterGap,
    [int]$NonClientHeight,
    [int]$WorkAreaHeight
  )

  # 탭 토글 줄 이하의 세로 배치 순수 계산 (진리표 테스트 대상 - 2026-08-04 시안 확정, 설계 합의):
  #  토글 줄(높이 32) → [설정 그룹(열림 시)] → [로그(열림 시)] → 하단 줄. 접힌 섹션만큼
  #  ClientHeight 가 줄어듭니다. 로그는 총 폼 높이가 아니라 '뷰포트 높이'를 기억값으로 받아
  #  설정을 접으면 폼도 함께 줄어듭니다 (리뷰 지적 반영). 작업 영역을 넘으면 로그 뷰포트를
  #  최소 100까지 축소합니다 (100 보장이 우선 - 화면 이탈은 적용부의 Top 보정이 마무리).
  # 반환: TabRowTop / SettingsTop·LogTop(-1 = 숨김) / LogHeight / ClientHeight /
  #        LockHeight(접힘 = 높이 잠금) / MinOuterHeight(열림 시 동적 최소 - 로그 100 보장)
  $tabRowTop = $DetailBottom + 8
  $stackBottom = $tabRowTop + 32
  $settingsTop = -1
  if ($SettingsOpen) {
    $settingsTop = $stackBottom + 8
    $stackBottom = $settingsTop + $SettingsHeight
  }
  if ($LogOpen) {
    $logTop = $stackBottom + 8
    $logView = [Math]::Max(100, $LogViewHeight)
    $clientHeight = $logTop + $logView + 8 + $FooterGap
    $maxClient = $WorkAreaHeight - $NonClientHeight
    if ($clientHeight -gt $maxClient) {
      $logView = [Math]::Max(100, $maxClient - $logTop - 8 - $FooterGap)
      $clientHeight = $logTop + $logView + 8 + $FooterGap
    }
    return @{
      TabRowTop = $tabRowTop; SettingsTop = $settingsTop; LogTop = $logTop; LogHeight = $logView
      ClientHeight = $clientHeight; LockHeight = $false
      MinOuterHeight = ($logTop + 100 + 8 + $FooterGap + $NonClientHeight)
    }
  }
  $clientHeight = $stackBottom + 8 + $FooterGap
  return @{
    TabRowTop = $tabRowTop; SettingsTop = $settingsTop; LogTop = -1; LogHeight = 0
    ClientHeight = $clientHeight; LockHeight = $true
    MinOuterHeight = ($clientHeight + $NonClientHeight)
  }
}

# ============================================================
#  커스텀 반복 - 순수 판정 함수 (UI/파일 접근 없음. tests\ 의 진리표 테스트가 이 함수들의
#  사본으로 전진/완주/오류 재시도/지문 판정을 검증합니다 - 판정식을 고치면 사본도 함께 갱신)
# ============================================================
function Format-CustomItemToken {
  # 던전 항목 → "어려움|1-3|1|1|0|1" 6조각(기존 형식 유지),
  # 어비스 항목 → "A|party|어려움|허상의 정박지|우연한 만남" 5조각.
  # 완료 마커 소유자·진행 지문·워커 환경변수가 모두 이 단일 토큰을 사용합니다.
  param($Item)
  # 생활(채집) 항목 → "L|daily|사과 나무|3" 4조각 (skill 은 config 저장용 Id, count 는 반복 횟수).
  # 던전/어비스보다 먼저 판정합니다 - 생활 항목에는 stage/dungeon 이 없어 아래 분기가
  # 전부 빈 문자열 토큰을 만들어 서로 다른 항목이 같은 지문을 갖게 됩니다
  $isLifeItem = $false
  try {
    $isLifeItem = (([string]$Item.kind -eq 'life') -or $null -ne $Item.PSObject.Properties['skill'])
  } catch { }
  if ($isLifeItem) {
    $lifeCount = 1
    try { $lifeCount = [int]$Item.count } catch { $lifeCount = 1 }
    if ($lifeCount -lt 1) { $lifeCount = 1 }
    if ($lifeCount -gt 99) { $lifeCount = 99 }
    return ('L|{0}|{1}|{2}' -f [string]$Item.skill, [string]$Item.target, $lifeCount)
  }
  $isAbyssItem = $false
  try {
    $isAbyssItem = (([string]$Item.kind -eq 'abyss') -or $null -ne $Item.PSObject.Properties['dungeon'])
  } catch { }
  if ($isAbyssItem) {
    $mode = $(if ([string]$Item.mode -eq 'party') { 'party' } else { 'solo' })
    $difficulty = [string]$Item.difficulty
    if ([string]::IsNullOrWhiteSpace($difficulty)) { $difficulty = '게임 그대로' }
    $matching = $(if ($mode -eq 'party') { [string]$Item.matching } else { '없음' })
    if ([string]::IsNullOrWhiteSpace($matching)) { $matching = '없음' }
    return ('A|{0}|{1}|{2}|{3}' -f $mode, $difficulty, [string]$Item.dungeon, $matching)
  }
  $coinFlag = $(if ([bool]$Item.coin) { '1' } else { '0' })
  $doubleFlag = $(if ([bool]$Item.doubleLoot) { '1' } else { '0' })
  $exhaustFlag = $(if ([bool]$Item.exhaustContinue) { '1' } else { '0' })
  $noDoubleFlag = $(if ([bool]$Item.noDoubleSweep) { '1' } else { '0' })
  return ('{0}|{1}|{2}|{3}|{4}|{5}' -f [string]$Item.difficulty, [string]$Item.stage,
    $coinFlag, $doubleFlag, $exhaustFlag, $noDoubleFlag)
}

function Get-CustomFingerprint {
  # 리스트 전체 → 지문 문자열 (항목 토큰을 ';' 로 연결). 진행 기록 저장 시와 시작 시
  # 이어가기 대조 양쪽에서 이 단일 구현을 사용합니다 (형식 불일치 사고 차단).
  param($Items)
  $tokens = @()
  foreach ($fpItem in @($Items)) {
    if ($null -eq $fpItem) { continue }
    $tokens += (Format-CustomItemToken -Item $fpItem)
  }
  return ($tokens -join ';')
}

function New-CustomMarkerOwnerJson {
  # 완료 마커 소유자: 같은 항목 토큰이 리스트에 중복될 수 있어 항목만으로는 부족합니다.
  # 리스트 전체 지문 + lap/index + 현재 항목 토큰을 함께 기록해 재시작 후에도 정확히 대조합니다.
  param($Context)
  if (-not $Context -or -not $Context.Item) { return '' }
  # version 2 (2026-08-04 랜덤 진행): orderKey = 이번 바퀴 순열 식별자 (순차는 '').
  # 진행 초기화 후 우연히 같은 lap/index 가 재현돼도 다른 순열의 낡은 마커가 일치하지 않게 함
  $owner = [pscustomobject]@{
    version     = 2
    fingerprint = (Get-CustomFingerprint -Items $Context.Items)
    orderKey    = (Get-CustomOrderKey -Order $Context.Order)
    lap         = [int]$Context.Lap
    index       = [int]$Context.Index
    item        = (Format-CustomItemToken -Item $Context.Item)
  }
  return ($owner | ConvertTo-Json -Compress)
}

function Read-CustomMarkerOwner {
  # 구버전 타임스탬프 마커나 부분 파일은 소유자를 확인할 수 없으므로 $null 처리합니다.
  if (-not (Test-Path -LiteralPath $customMarkerFile)) { return $null }
  try {
    $raw = Get-Content -LiteralPath $customMarkerFile -Raw -Encoding UTF8 -ErrorAction Stop
    $owner = $raw | ConvertFrom-Json -ErrorAction Stop
    if (-not $owner.PSObject.Properties['version'] -or (@(1, 2) -notcontains [int]$owner.version)) { return $null }
    foreach ($required in @('fingerprint', 'lap', 'index', 'item')) {
      if (-not $owner.PSObject.Properties[$required]) { return $null }
    }
    return $owner
  } catch {
    return $null
  }
}

function Test-CustomMarkerOwnerMatchesContext {
  param($Owner, $Context)
  if (-not $Owner -or -not $Context -or -not $Context.Item) { return $false }
  try {
    $ownerOrderKey = ''
    if ($Owner.PSObject.Properties['orderKey']) { $ownerOrderKey = [string]$Owner.orderKey }
    return (([string]$Owner.fingerprint -eq (Get-CustomFingerprint -Items $Context.Items)) -and
      ($ownerOrderKey -eq (Get-CustomOrderKey -Order $Context.Order)) -and
      ([int]$Owner.lap -eq [int]$Context.Lap) -and
      ([int]$Owner.index -eq [int]$Context.Index) -and
      ([string]$Owner.item -eq (Format-CustomItemToken -Item $Context.Item)))
  } catch {
    return $false
  }
}

function Test-CustomMarkerValidForCurrent {
  # 완료 마커가 **지금 항목의 유효한 마커인가**. 파일 존재만 보면 안 됩니다.
  #
  # Clear-CustomMarkerFile 은 파일이 잠겨 삭제가 막히면 내용을 '{}' 로 덮어 **소유자 형식을
  # 무효화**하고 성공으로 끝냅니다(그게 그 폴백의 목적). 그런데 종료 코드 처리부가
  # Test-Path 만 보면 그 '{}' 를 '이번 판 클리어 확정'으로 읽어, **돌지도 않은 항목을 완료로
  # 계상하고 건너뜁니다** (2026-08-09 6차 점검). 이어가기 복구가 쓰는 판정과 같은 것을
  # 쓰게 해서 두 경로가 같은 사실을 보게 만듭니다 - 한쪽만 인정하면 계상과 복구가 어긋납니다.
  if (-not (Test-Path -LiteralPath $customMarkerFile)) { return $false }
  $owner = Read-CustomMarkerOwner
  # 소유자 형식이 아니면 무조건 거절합니다 - '{}' 무효화 잔존, 구버전 타임스탬프 마커,
  # 깨진 파일이 전부 여기서 걸립니다. 6차에서 닫으려던 구멍이 바로 이것입니다.
  if (-not $owner) { return $false }
  $context = Get-CustomCurrentContext
  if (-not $context) {
    # ★ '컨텍스트를 못 읽음'은 **'마커가 틀렸다'가 아니라 '판단 불가'** 입니다.
    #   Get-CustomCurrentContext 는 부를 때마다 Read-Config 로 **디스크를 다시 읽습니다.**
    #   그 읽기가 한 번 실패하면(백신 스캔·외부 점유 등 일시 공유 위반) $null 이 되는데,
    #   이걸 '무효'로 처리하면 **정당하게 끝낸 판을 안 세고 그 항목을 한 번 더 돌립니다**
    #   = 은동전/마족공물 이중 소모. 이 프로젝트에서 가장 나쁜 결과입니다.
    #   6차 수정(파일 존재 → 소유자 대조)이 새로 만든 위험이라 7차에서 막습니다.
    #   소유자 형식은 위에서 이미 확인했으므로 '{}' 잔존은 이 경로로 새지 않습니다.
    #   판단 불가일 때만 예전 계약(존재하면 인정)으로 되돌아가고, 사실을 로그로 남깁니다.
    Add-GuiLog '[경고] 커스텀 진행 정보를 읽지 못해 완료 마커를 소유자 형식만으로 인정합니다 (설정 파일 접근 실패 - 다음 회차에 다시 확인합니다).'
    return $true
  }
  return [bool](Test-CustomMarkerOwnerMatchesContext -Owner $owner -Context $context)
}

function Get-CustomNextProgress {
  # 진행(lap/index)을 한 칸 전진시킨 결과를 반환합니다 (저장은 호출부 몫).
  # lap 은 1부터, index 는 0부터(= 다음 실행할 항목). 리스트 끝이면 index=0 으로 감고 lap+1.
  param($Progress, [int]$ItemCount)
  $lap = 1; $index = 0
  if ($Progress) {
    try { $lap = [int]$Progress.lap } catch { $lap = 1 }
    try { $index = [int]$Progress.index } catch { $index = 0 }
  }
  if ($lap -lt 1) { $lap = 1 }
  if ($index -lt 0) { $index = 0 }
  if ($ItemCount -lt 1) { $ItemCount = 1 }
  $index++
  if ($index -ge $ItemCount) { $index = 0; $lap++ }
  return [pscustomobject]@{ lap = $lap; index = $index }
}

function New-CustomShuffleOrder {
  # 랜덤 진행: 이번 바퀴의 실행 순서(등록 인덱스 순열)를 만듭니다. 생성 지점은 시작 게이트
  # (Confirm-CustomShuffleReady)와 Step 의 바퀴 전환 두 곳뿐 - getter/복구 경로는 읽기 전용
  # (호출 횟수에 따라 순서가 바뀌는 사고 방지 - 리뷰 계약).
  param([int]$ItemCount)
  if ($ItemCount -lt 1) { return @() }
  if ($ItemCount -eq 1) { return @(0) }
  return @(Get-Random -InputObject @(0..($ItemCount - 1)) -Count $ItemCount)
}

function Test-CustomShuffleOrder {
  # 순열 검증 (순수 - 진리표 대상): 길이 = 항목 수, 정수, 0..N-1 범위, 중복 없음.
  param($Order, [int]$ItemCount)
  $orderArr = @($Order)
  if ($ItemCount -lt 1 -or $orderArr.Count -ne $ItemCount) { return $false }
  $seenIdx = @{}
  foreach ($orderVal in $orderArr) {
    if ($null -eq $orderVal -or (([string]$orderVal) -notmatch '^\d+$')) { return $false }
    $orderNum = [int]$orderVal
    if ($orderNum -lt 0 -or $orderNum -ge $ItemCount) { return $false }
    if ($seenIdx.ContainsKey($orderNum)) { return $false }
    $seenIdx[$orderNum] = $true
  }
  return $true
}

function Get-CustomOrderKey {
  # 완료 마커 대조용 순서 식별자. 순차 모드는 '' - v1 마커의 '필드 없음'과 동치 (하위 호환)
  param($Order)
  if ($null -eq $Order) { return '' }
  return (@($Order) -join ',')
}

function Get-CustomExecutionItems {
  # 등록 항목 배열 -> 실행 순서 배열 (열거용 - 호출부 @() 규약. 중복 항목도 인덱스 치환이라
  # 정확히 1회씩 실행됩니다)
  param($Items, $Order)
  $execItems = @()
  foreach ($regIndex in @($Order)) { $execItems += @($Items)[[int]$regIndex] }
  return $execItems
}

function Get-CustomRandomOrderEnabled {
  # 섹션 노드의 randomOrder (JSON 불리언만 인정 - ConvertTo-StrictBoolean 계약)
  param($Node)
  if (-not $Node -or -not $Node.PSObject.Properties['randomOrder']) { return $false }
  return (ConvertTo-StrictBoolean $Node.randomOrder $false)
}

function Test-CustomLapComplete {
  # count 모드 완주 판정: 전진 '후'의 lap 이 목표 바퀴 수를 넘는 순간 완주입니다.
  # lap 은 1 시작이므로 N=1 이면 전진 후 lap 이 2가 되는 순간 (off-by-one 주의:
  # '전진 전 lap -ge N' 으로 쓰면 마지막 판을 계상하기 전에 정지하는 사고).
  # 시작 시 '무한으로 돌다 N 축소' 검사도 같은 식(저장된 lap -gt N)을 사용합니다.
  param([string]$ListRepeat, [int]$ListRepeatCount, [int]$Lap)
  if ($ListRepeat -ne 'count') { return $false }
  if ($ListRepeatCount -lt 1) { $ListRepeatCount = 1 }
  return ($Lap -gt $ListRepeatCount)
}

function Get-CustomErrorAction {
  # 오류 종료(코드 1) 대응 판정. ErrorStreak = 지금까지의 같은 항목 연속 오류 횟수(이번 오류 제외).
  # 반환: 'recover' = 완료 마커 있음 - 전진하지 않고 같은 항목의 마무리만 자동 복구
  #       'retry'   = 같은 항목 자동 재시작 (2회까지)
  #       'stop'    = 재시도 상한 초과(같은 항목 3회째 실패) - 정지
  param([bool]$MarkerExists, [int]$ErrorStreak)
  if (($ErrorStreak + 1) -gt 2) { return 'stop' }
  if ($MarkerExists) { return 'recover' }
  return 'retry'
}

function Get-CustomPositionText {
  # 진행 위치 표기: '2바퀴째 3/4번' (index 는 0 시작이므로 표기는 +1)
  param([int]$Lap, [int]$Index, [int]$Total)
  return ('{0}바퀴째 {1}/{2}번' -f $Lap, ($Index + 1), $Total)
}

function Get-CustomItemLabel {
  # 던전/어비스 공용 로그용 항목 표기.
  param($Item)
  $isAbyssItem = $false
  try { $isAbyssItem = ([string]$Item.kind -eq 'abyss') } catch { }
  if ($isAbyssItem) {
    $modeText = $(if ([string]$Item.mode -eq 'party') { '함께하기' } else { '혼자하기' })
    $label = ('{0} {1} {2}' -f $modeText, [string]$Item.difficulty, [string]$Item.dungeon)
    if ([string]$Item.mode -eq 'party') { $label += (", 매칭 '{0}'" -f [string]$Item.matching) }
    return $label
  }
  $label = ('{0} {1}' -f [string]$Item.difficulty, [string]$Item.stage)
  if ([bool]$Item.coin -and [bool]$Item.doubleLoot) { $label += ' (은동전·더블 루팅)' }
  elseif ([bool]$Item.coin) { $label += ' (은동전)' }
  return $label
}

function Get-CustomListCompact {
  # 던전/어비스 리스트 압축 표기 (워커 [설정] 스냅샷 한 줄 기록용).
  # 항목당 '어1-3(20,소·진)' 형식: 괄호 안은 판당 소모량(20/10/0),
  # 더블 루팅이면 noDoubleSweep 를 소(소탕만 진행)/멈(멈춤)으로, 이어서 소진 분기에 도달
  # 가능하면 ·진/·멈(exhaustContinue)을 붙입니다. 소모량 0(미사용)은 '(0)' 만.
  # 예: '1.어1-3(20,소·진) 2.어1-3(20,멈) 3.일2-1(10,멈) 4.일2-3(0)'
  param($Items)
  $parts = @()
  $seq = 0
  foreach ($compactItem in @($Items)) {
    if ($null -eq $compactItem) { continue }
    $seq++
    $isAbyssItem = $false
    try { $isAbyssItem = ([string]$compactItem.kind -eq 'abyss') } catch { }
    if ($isAbyssItem) {
      $modeText = $(if ([string]$compactItem.mode -eq 'party') { '함께' } else { '혼자' })
      $matchingText = $(if ([string]$compactItem.mode -eq 'party') { "/$([string]$compactItem.matching)" } else { '' })
      $parts += ('{0}.{1}/{2}/{3}{4}' -f $seq, $modeText, [string]$compactItem.difficulty,
        [string]$compactItem.dungeon, $matchingText)
      continue
    }
    $difficultyChar = $(switch ([string]$compactItem.difficulty) {
        '어려움' { '어' } '매우 어려움' { '매' } default { '일' }
      })
    $exhaustChar = $(if ([bool]$compactItem.exhaustContinue) { '진' } else { '멈' })
    $suffix = if (-not [bool]$compactItem.coin) { '(0)' }
    elseif (-not [bool]$compactItem.doubleLoot) { ('(10,{0})' -f $exhaustChar) }
    elseif ([bool]$compactItem.noDoubleSweep) { ('(20,소·{0})' -f $exhaustChar) }
    else { '(20,멈)' }   # 더블+멈춤: 소진 분기 도달 불가 - exhaust 표기 생략
    $parts += ('{0}.{1}{2}{3}' -f $seq, $difficultyChar, [string]$compactItem.stage, $suffix)
  }
  return ($parts -join ' ')
}

function Get-CustomCoinTotalPerLap {
  # 리스트 1바퀴에 필요한 은동전 합계 (더블 루팅 20 / 소탕만 10 / 미사용 0).
  # 정상 진행 기준 예산 표시용 - 소진 대응으로 강등되면 실소모는 이보다 적을 수 있음.
  param($Items)
  $total = 0
  foreach ($totalItem in @($Items)) {
    if ($null -eq $totalItem) { continue }
    if ([bool]$totalItem.coin) { $total += $(if ([bool]$totalItem.doubleLoot) { 20 } else { 10 }) }
  }
  return $total
}

function Update-CustomRepeatMixLock {
  # 혼합 리스트 자동 잠금 (2026-07-30 사용자 요청, 리뷰 승인): 마지막→첫 항목의 바퀴 순환이
  # 게임에서 불가능한 층 조합(Get-CustomTransitionIssues 의 Wrap 이슈)이면 리스트 반복을
  # '횟수 1바퀴'로 강제하고 무한 라디오·바퀴 수 입력을 잠급니다. 혼합이 해소되면 자동 해제.
  # 기존에는 시작 게이트가 거부하고 수동 변경을 안내했음 - 그 게이트는 config 직접 편집
  # 방어선으로 유지. 호출: 던전/심층 저장 함수 서두(모든 리스트 변경이 저장을 경유) +
  # config 로드 직후. 잠금 중 컨트롤 강제는 crLoading 가드로 저장 이벤트를 억제하고,
  # 이 함수 자신은 저장을 부르지 않아 재귀가 없습니다.
  param($Items, $RbInfinite, $RbCount, $NumLaps, [string]$StateKey)
  $mixLockNeeded = $false
  if (@($Items).Count -ge 2) {
    $mixWrapIssues = @(@(Get-CustomTransitionIssues -Items $Items -ListRepeat 'infinite' -ListRepeatCount 1) |
        Where-Object { [bool]$_.Wrap })
    $mixLockNeeded = ($mixWrapIssues.Count -gt 0)
  }
  $mixState = $script:crMixLockState[$StateKey]
  $mixWasLocked = [bool]$mixState.Locked
  if ($mixLockNeeded -and -not $mixWasLocked) {
    # 잠금 진입 시에만 이전 반복 상태를 저장합니다 (2026-08-01 3차 점검: 해제 때 Enabled 만
    # 복원하고 무한/바퀴 수는 잠금이 바꾼 '횟수 1바퀴'로 남아, 저장 실패 롤백 등으로 잠금이
    # 풀리면 사용자의 원래 반복 설정이 유실됐음 - 리뷰 조건: 진입 시 저장/해제 시 복원)
    $mixState.PrevInfinite = -not [bool]$RbCount.Checked
    $mixState.PrevLaps = [int]$NumLaps.Value
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      # '횟수' 강제 - CheckedChanged 핸들러가 NumLaps.Enabled 를 켜지만 아래에서 다시 잠급니다
      if (-not $RbCount.Checked) { $RbCount.Checked = $true }
      $NumLaps.Value = 1
    } finally { $script:crLoading = $prevLoading }
    $RbInfinite.Enabled = $false
    $NumLaps.Enabled = $false
    $mixState.Locked = $true
    # 생활 대분류에서는 커스텀 리스트 안내를 표시하지 않습니다 (잠금 상태 관리는 전투 복귀
    # 대비로 그대로 - 2026-08-06 00:06 실기 제보: 생활 시작 중 이 안내가 떠 혼란)
    if ($script:mainCategory -ne 'life') {
      Add-GuiLog "[안내] 층이 섞인 혼합 리스트라 반복을 '횟수 1바퀴'로 고정합니다 (마지막→첫 항목 순환이 게임에서 불가능)."
    }
  } elseif ((-not $mixLockNeeded) -and $mixWasLocked) {
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      # 이전 반복 상태 복원 (범위 보정: NumericUpDown 한계 밖 값 방어 - 리뷰 조건)
      if ([bool]$mixState.PrevInfinite) { $RbInfinite.Checked = $true }
      $restoreLaps = [int]$mixState.PrevLaps
      if ($restoreLaps -lt [int]$NumLaps.Minimum) { $restoreLaps = [int]$NumLaps.Minimum }
      if ($restoreLaps -gt [int]$NumLaps.Maximum) { $restoreLaps = [int]$NumLaps.Maximum }
      $NumLaps.Value = $restoreLaps
    } finally { $script:crLoading = $prevLoading }
    $RbInfinite.Enabled = $true
    $NumLaps.Enabled = [bool]$RbCount.Checked   # 기존 규칙 복원: '횟수' 선택 시만 활성
    $mixState.Locked = $false
    if ($script:mainCategory -ne 'life') {
      Add-GuiLog '[안내] 혼합 리스트가 해소돼 반복 방식 잠금을 풀고 이전 반복 설정을 복원했습니다.'
    }
  }
}

function Get-CustomTransitionIssues {
  # 리스트 전환 규칙 검사 (2026-07-20 실기 실측 근거: '다시 하기'로 돌아온 화면은 같은 층
  # 구역만 선택 가능(역방향 포함), 1층→2층은 1-3 결과 화면의 '다음 층으로'로만 가능,
  # 2층→1층은 '나가기(필드행)' 없이는 불가능 - 나가기는 금지이므로 전환 자체를 사전 차단).
  # 검사 대상: 연속 항목 전환(i → i+1) 전부 + 바퀴 순환 전환(마지막 → 첫 항목 - 리스트 반복이
  # 무한이거나 2바퀴 이상일 때만. 1바퀴면 마지막 항목 후 정지라 순환 전환이 발생하지 않음).
  # 위반 규칙: ① 2층 → 1층 전환 금지 ② 1층 → 2층 전환은 출발 항목이 1-3일 때만 허용.
  # 같은 층 전환·같은 구역은 항상 허용 (난이도 차이는 알약 클릭으로 해소 가능 - 제약 없음).
  # 반환: 위반 배열 [{From; To; Wrap; Reason}] (From/To 는 'N번(난이도 구역)' 표기, 없으면 빈 배열).
  # PS 5.1 배열 풀림 주의: 열거용이므로 return $issues 그대로 + 호출부 @() 감싸기 규약.
  param($Items, [string]$ListRepeat, [int]$ListRepeatCount)
  $issues = @()
  $tiList = @()
  foreach ($tiItem in @($Items)) { if ($null -ne $tiItem) { $tiList += $tiItem } }
  if ($tiList.Count -lt 1) { return $issues }
  $tiCheckWrap = (($ListRepeat -ne 'count') -or ($ListRepeatCount -ge 2))
  for ($tiIdx = 0; $tiIdx -lt $tiList.Count; $tiIdx++) {
    $tiWrap = ($tiIdx -eq ($tiList.Count - 1))
    if ($tiWrap -and -not $tiCheckWrap) { continue }
    $tiToIdx = ($tiIdx + 1) % $tiList.Count
    $fromItem = $tiList[$tiIdx]
    $toItem = $tiList[$tiToIdx]
    $fromStage = [string]$fromItem.stage
    $toStage = [string]$toItem.stage
    # 층 번호 추출 ('1-3' → 1). 형식 밖 값은 판정 불가이므로 검사를 건너뜁니다 (방어적 통과 -
    # 실제 리스트는 콤보박스 고정값이라 도달하지 않음)
    $fromFloor = 0; $toFloor = 0
    if ($fromStage -match '^(\d+)-') { $fromFloor = [int]$Matches[1] }
    if ($toStage -match '^(\d+)-') { $toFloor = [int]$Matches[1] }
    if ($fromFloor -lt 1 -or $toFloor -lt 1) { continue }
    if ($fromFloor -eq $toFloor) { continue }
    $tiReason = $null
    if ($fromFloor -gt $toFloor) {
      $tiReason = ('{0}층에서 {1}층으로 내려가는 전환은 게임에서 불가능합니다' -f $fromFloor, $toFloor)
    } elseif ($fromStage -ne '1-3') {
      $tiReason = "1층에서 2층으로 올라가는 전환은 1-3에서만('다음 층으로' 버튼) 가능합니다"
    }
    if ($tiReason) {
      $issues += [pscustomobject]@{
        From   = ('{0}번({1} {2})' -f ($tiIdx + 1), [string]$fromItem.difficulty, $fromStage)
        To     = ('{0}번({1} {2})' -f ($tiToIdx + 1), [string]$toItem.difficulty, $toStage)
        Wrap   = [bool]$tiWrap
        Reason = $tiReason
      }
    }
  }
  return $issues
}

# ============================================================
#  커스텀 반복 - 리스트뷰/설정/진행 기록 헬퍼 (UI·config 접근)
# ============================================================
# ============================================================
#  커스텀 리스트 셀 편집 - 오버레이 표시/적용 (2026-07-25)
# ============================================================
function Hide-CellEditCombo {
  $script:cellEditCombo.Visible = $false
  if ($script:cellEditCombo.Parent) { $script:cellEditCombo.Parent.Controls.Remove($script:cellEditCombo) }
}

function Show-CellEditCombo {
  param($ListView, [int]$RowIndex, [int]$ColumnIndex, [string[]]$Options, [string]$Current)
  $script:cellEditSession++
  $ListView.EnsureVisible($RowIndex)   # 부분 노출 셀 대비 - bounds 를 읽기 전에 행을 화면 안으로
  $cellBounds = $ListView.Items[$RowIndex].SubItems[$ColumnIndex].Bounds
  # ListView 자식으로 붙여 셀 좌표계를 그대로 사용합니다 (좌표 변환 불필요)
  $ListView.Controls.Add($script:cellEditCombo)
  $script:cellEditCombo.SetBounds($cellBounds.X, $cellBounds.Y, [Math]::Max($cellBounds.Width, 48), $cellBounds.Height)
  $script:cellEditCombo.DropDownWidth = [Math]::Max($cellBounds.Width, 170)   # '함께하기 · 파티(파티장)' 등 긴 문구 대응
  # 기본 8줄이면 생활 횟수(99개)·약초 대상(16개)·어비스 함께 난이도(14개)가 전부 스크롤에
  # 갇힙니다. 상한 16 = 가장 긴 대상 목록(약초)이 딱 들어오는 값이며, 그 이상은 드롭다운이
  # 패널을 덮어 오히려 답답합니다(20줄로 실기해 보고 낮춤 - 2026-08-08). 짧은 목록은 그대로
  $script:cellEditCombo.MaxDropDownItems = [Math]::Max(8, [Math]::Min(16, @($Options).Count))
  $script:cellEditCombo.Items.Clear()
  foreach ($comboOption in $Options) { [void]$script:cellEditCombo.Items.Add($comboOption) }
  $script:cellEditCombo.SelectedItem = $Current
  $script:cellEditContext = @{
    List = $ListView; RowIndex = $RowIndex; ColumnIndex = $ColumnIndex
    Session = $script:cellEditSession; Applied = $false; Value = ''
  }
  $script:cellEditCombo.Visible = $true
  $script:cellEditCombo.BringToFront()
  [void]$script:cellEditCombo.Focus()
  # Visible/Focus 가 자리잡은 뒤 드롭다운을 여는 편이 안정적. 예약 시점 세션을 지역 변수로
  # 캡처해, 그 사이 상태가 바뀌었으면(다른 편집 시작/숨김/실행 시작) 열지 않습니다.
  #
  # 검사 자체는 반드시 **함수 안에서** 해야 합니다 (2026-08-08 실측 수정):
  # PS 5.1 의 GetNewClosure() 는 새 동적 모듈을 만들고 **지역 변수만** 복사하므로,
  # 함수 안에서 만든 클로저에서는 $script: 변수가 그 빈 모듈을 가리켜 전부 $null 로 읽힙니다.
  # 그래서 예전 코드의 `[int]$script:cellEditSession -ne $openSession` 은 항상
  # `0 -ne N` = 참이 되어 **드롭다운이 한 번도 열린 적이 없었습니다**(셀을 눌러도 콤보만
  # 뜨고 목록이 안 펼쳐짐). 함수 호출은 실제 스크립트 스코프에서 실행되므로 안전합니다
  # - 바로 위 Add_SelectionChangeCommitted 가 Invoke-CellEditApply 를 부르는 것과 같은 패턴.
  $openSession = [int]$script:cellEditSession
  $null = $script:cellEditCombo.BeginInvoke([Action] ({
        Open-CellEditDropDown -ExpectedSession $openSession
      }.GetNewClosure()))
}

function Open-CellEditDropDown {
  # 예약된 드롭다운 펼침의 실행부. $script: 상태를 '지금' 다시 읽어야 하므로 클로저가 아니라
  # 함수로 둡니다 (위 Show-CellEditCombo 주석의 GetNewClosure 함정 참고).
  param([int]$ExpectedSession)
  if ([int]$script:cellEditSession -ne $ExpectedSession) { return }
  if (-not $script:cellEditCombo.Visible -or -not $script:cellEditCombo.Parent) { return }
  if ($script:running) { return }
  $script:cellEditCombo.DroppedDown = $true
}

function Invoke-CellEditApply {
  # SelectionChangeCommitted 가 예약한 적용 실행부. 지연 실행 사이에 행이 사라졌거나
  # 세션이 바뀐 경우를 방어합니다. 검증이 전부 통과한 뒤에만 컨텍스트를 제거합니다 -
  # 오래된 예약이 새 세션의 컨텍스트를 지우지 못하게 (리뷰 지적).
  param([int]$ExpectedSession = -1)
  $applyContext = $script:cellEditContext
  if (-not $applyContext -or -not $applyContext.Applied) { return }
  if ($ExpectedSession -ge 0 -and [int]$applyContext.Session -ne $ExpectedSession) { return }
  if ([int]$applyContext.Session -ne [int]$script:cellEditSession) { return }
  $script:cellEditContext = $null
  $applyList = $applyContext.List
  if ($applyContext.RowIndex -lt 0 -or $applyContext.RowIndex -ge $applyList.Items.Count) { return }
  # 위 $cellEditMouseUp 의 분기와 **반드시 쌍으로** 유지합니다. 한쪽만 고치면 '클릭은 생활
  # 옵션이 뜨는데 적용은 어비스 리스트를 통째로 바꾸는' 최악 조합이 됩니다
  # (Invoke-AcrCellEdit 는 대상 리스트를 인자로 받지 않고 $lvAcrList 를 직접 씁니다).
  if ($applyList -eq $lvCrList) {
    Invoke-CrCellEdit -RowIndex $applyContext.RowIndex -ColumnIndex $applyContext.ColumnIndex -Value $applyContext.Value
  } elseif ($applyList -eq $lvDcrList) {
    Invoke-DcrCellEdit -RowIndex $applyContext.RowIndex -ColumnIndex $applyContext.ColumnIndex -Value $applyContext.Value
  } elseif ($applyList -eq $lvLcrList) {
    Invoke-LcrCellEdit -RowIndex $applyContext.RowIndex -ColumnIndex $applyContext.ColumnIndex -Value $applyContext.Value
  } elseif ($applyList -eq $lvAcrList) {
    Invoke-AcrCellEdit -RowIndex $applyContext.RowIndex -ColumnIndex $applyContext.ColumnIndex -Value $applyContext.Value
  } else {
    return   # 알 수 없는 리스트는 적용하지 않음 (어비스 폴백 금지)
  }
}

function Invoke-CrCellEdit {
  # 던전 리스트 행 단위 셀 편집 적용: 정규화 → 행 텍스트 갱신 → 저장(실패 시 원복) →
  # 전환 규칙 경고 (이동(↑↓)과 동일 취급 - 차단하지 않고 시작 게이트가 최종 방어).
  param([int]$RowIndex, [int]$ColumnIndex, [string]$Value)
  $editItems = @(Get-CustomItemsFromList)
  if ($RowIndex -ge $editItems.Count) { return }
  $beforeItem = $editItems[$RowIndex]
  $afterItem = Set-CrItemCellValue -Item $beforeItem -ColumnIndex $ColumnIndex -Value $Value
  if (([string]$beforeItem.difficulty -eq [string]$afterItem.difficulty) -and
      ([string]$beforeItem.stage -eq [string]$afterItem.stage) -and
      ([bool]$beforeItem.coin -eq [bool]$afterItem.coin) -and
      ([bool]$beforeItem.doubleLoot -eq [bool]$afterItem.doubleLoot) -and
      ([bool]$beforeItem.exhaustContinue -eq [bool]$afterItem.exhaustContinue) -and
      ([bool]$beforeItem.noDoubleSweep -eq [bool]$afterItem.noDoubleSweep)) { return }
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try { Set-CustomListRowTexts -Row $lvCrList.Items[$RowIndex] -Item $afterItem } finally { $script:crLoading = $prevLoading }
  $script:lastCustomSaveOk = $true
  if ($script:uiReady) { Save-CustomRepeatToConfig }
  if (-not $script:lastCustomSaveOk) {
    # 저장 실패: 화면과 config 이 어긋나지 않게 행을 원복하고 은동전 합계도 되돌립니다
    # (저장 시도 중 변경된 행 기준으로 합계가 이미 갱신됐음 - 리뷰 지적)
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try { Set-CustomListRowTexts -Row $lvCrList.Items[$RowIndex] -Item $beforeItem } finally { $script:crLoading = $prevLoading }
    Update-CustomCoinTotalLabel
    # 롤백이 끝난 실제 리스트 기준으로 혼합 잠금을 다시 계산합니다 (2026-07-31 점검 - 저장
    # 함수가 먼저 잠금을 바꿔 놓은 뒤 행만 되돌리면 잠금 상태가 리스트와 어긋남)
    Update-CustomRepeatMixLock -Items @(Get-CustomItemsFromList) `
      -RbInfinite $rbCrInfinite -RbCount $rbCrCount -NumLaps $numCrLaps -StateKey 'cr'
    Update-CustomRandomMixGate -Toggle $chkCrRandom -Items @(Get-CustomItemsFromList) -SectionName 'customRepeat'
    Add-GuiLog '[경고] 셀 수정 저장에 실패해 항목을 되돌렸습니다.'
    return
  }
  Add-GuiLog ('[안내] 항목 {0} 수정: {1} → {2}' -f ($RowIndex + 1),
    (Get-CustomItemLabel -Item $beforeItem), (Get-CustomItemLabel -Item $afterItem))
  # 전환 규칙 사전 경고 ([추가]와 같은 로그 - 최종 차단은 시작 게이트)
  $editRepeat = $(if ($rbCrCount.Checked) { 'count' } else { 'infinite' })
  $editIssues = @(Get-CustomTransitionIssues -Items @(Get-CustomItemsFromList) `
      -ListRepeat $editRepeat -ListRepeatCount ([int]$numCrLaps.Value))
  foreach ($editIssue in $editIssues) {
    $editWrapTag = $(if ([bool]$editIssue.Wrap) { ' [바퀴 순환: 마지막 → 첫 항목]' } else { '' })
    Add-GuiLog ('[경고] {0} → {1}{2}: {3} - 이대로는 시작할 수 없습니다 (순서 조정 또는 항목 수정으로 해소해 주세요).' -f `
        $editIssue.From, $editIssue.To, $editWrapTag, $editIssue.Reason)
  }
}

function Invoke-AcrCellEdit {
  # 어비스 리스트 셀 편집 적용. 난이도/어비스 던전은 행 단위, 방식/매칭은 통일 규칙에 따라
  # 리스트 전체 일괄 변경입니다. 함께→혼자 전환으로 지옥 난이도가 강등될 때는 사전 확인창을
  # 띄웁니다 (원래 난이도를 잃는 변경 - 사용자 버튼 조작 즉답 팝업이라 무인 운용과 무관).
  param([int]$RowIndex, [int]$ColumnIndex, [string]$Value)
  $editItems = @(Get-AbyssCustomItemsFromList)
  if ($RowIndex -ge $editItems.Count) { return }
  if ($ColumnIndex -eq 3 -or $ColumnIndex -eq 4) {
    $beforeItem = $editItems[$RowIndex]
    $afterItem = [pscustomobject]@{
      kind = 'abyss'; mode = [string]$beforeItem.mode
      difficulty = $(if ($ColumnIndex -eq 3) { $Value } else { [string]$beforeItem.difficulty })
      dungeon = $(if ($ColumnIndex -eq 4) { $Value } else { [string]$beforeItem.dungeon })
      matching = [string]$beforeItem.matching
    }
    if (([string]$beforeItem.difficulty -eq [string]$afterItem.difficulty) -and
        ([string]$beforeItem.dungeon -eq [string]$afterItem.dungeon)) { return }
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try { Set-AbyssListRowTexts -Row $lvAcrList.Items[$RowIndex] -Item $afterItem } finally { $script:crLoading = $prevLoading }
    $script:lastCustomSaveOk = $true
    if ($script:uiReady) { Save-CustomRepeatToConfig }
    if (-not $script:lastCustomSaveOk) {
      $prevLoading = $script:crLoading
      $script:crLoading = $true
      try { Set-AbyssListRowTexts -Row $lvAcrList.Items[$RowIndex] -Item $beforeItem } finally { $script:crLoading = $prevLoading }
      Add-GuiLog '[경고] 셀 수정 저장에 실패해 항목을 되돌렸습니다.'
      return
    }
    Add-GuiLog ('[안내] 어비스 항목 {0} 수정: {1}/{2}' -f ($RowIndex + 1), [string]$afterItem.difficulty, [string]$afterItem.dungeon)
    return
  }
  if ($ColumnIndex -ne 2 -and $ColumnIndex -ne 5) { return }
  # 방식(2)/매칭(5) = 리스트 전체 일괄 변경 (통일 규칙 유지)
  $globalTarget = $(if ($ColumnIndex -eq 2) { ConvertFrom-AcrModeOption -OptionText $Value }
    else { @{ Mode = 'party'; Matching = $Value } })
  if (-not $globalTarget) { return }
  $convertResult = Convert-AcrItemsForGlobalSetting -Items $editItems -Mode ([string]$globalTarget.Mode) -Matching ([string]$globalTarget.Matching)
  $convertedItems = @($convertResult.Items)
  $isSame = ($convertedItems.Count -eq $editItems.Count)
  if ($isSame) {
    for ($sameIndex = 0; $sameIndex -lt $editItems.Count; $sameIndex++) {
      if (([string]$editItems[$sameIndex].mode -ne [string]$convertedItems[$sameIndex].mode) -or
          ([string]$editItems[$sameIndex].difficulty -ne [string]$convertedItems[$sameIndex].difficulty) -or
          ([string]$editItems[$sameIndex].matching -ne [string]$convertedItems[$sameIndex].matching)) { $isSame = $false; break }
    }
  }
  if ($isSame) { return }
  if ([int]$convertResult.DowngradeCount -gt 0) {
    $downgradeText = ("혼자하기로 바꾸면 함께하기 전용 난이도(지옥)를 쓸 수 없어`n" +
      "지옥 난이도 항목 {0}건이 '매우 어려움'으로 바뀝니다.`n`n계속할까요?" -f [int]$convertResult.DowngradeCount)
    $downgradeAnswer = [System.Windows.Forms.MessageBox]::Show($downgradeText, '커스텀 반복 - 난이도 변경 확인',
      [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($downgradeAnswer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
  }
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    for ($applyIndex = 0; $applyIndex -lt $lvAcrList.Items.Count -and $applyIndex -lt $convertedItems.Count; $applyIndex++) {
      Set-AbyssListRowTexts -Row $lvAcrList.Items[$applyIndex] -Item $convertedItems[$applyIndex]
    }
  } finally { $script:crLoading = $prevLoading }
  $script:lastCustomSaveOk = $true
  if ($script:uiReady) { Save-CustomRepeatToConfig }
  if (-not $script:lastCustomSaveOk) {
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      for ($revertIndex = 0; $revertIndex -lt $lvAcrList.Items.Count -and $revertIndex -lt $editItems.Count; $revertIndex++) {
        Set-AbyssListRowTexts -Row $lvAcrList.Items[$revertIndex] -Item $editItems[$revertIndex]
      }
    } finally { $script:crLoading = $prevLoading }
    Update-AbyssInputLock
    Add-GuiLog '[경고] 방식·매칭 일괄 변경 저장에 실패해 리스트를 되돌렸습니다.'
    return
  }
  Update-AbyssInputLock
  $modeLabel = $(if ([string]$globalTarget.Mode -eq 'party') { "함께하기/$([string]$globalTarget.Matching)" } else { '혼자하기' })
  $downgradeTag = $(if ([int]$convertResult.DowngradeCount -gt 0) { " (지옥 → 매우 어려움 강등 $([int]$convertResult.DowngradeCount)건)" } else { '' })
  Add-GuiLog ('[안내] 어비스 리스트 방식·매칭 전체 변경: {0}항목 → {1}{2}' -f $convertedItems.Count, $modeLabel, $downgradeTag)
}

# ============================================================
#  커스텀 리스트 셀 편집 판정 (2026-07-25) - 순수 함수 (진리표 테스트 대상)
#  셀 클릭 → 오버레이 드롭다운으로 값 변경. 어비스의 방식/매칭 열은 통일 규칙 때문에
#  '리스트 전체 일괄 변경' 진입점으로 동작합니다 (설계 합의).
# ============================================================
function Get-CrCellEditPlan {
  # 던전 리스트 셀 편집 계획: 편집 가능하면 @{ Options; Current }, 아니면 $null.
  # 소진 시 열은 소진 분기에 도달 가능한 조합(coin && (!double || noDoubleSweep))에서만,
  # 더블 불가 시 열은 더블 루팅 항목에서만 편집할 수 있습니다 ('—' 표기 상태는 편집 무의미).
  param([int]$ColumnIndex, $Item)
  switch ($ColumnIndex) {
    2 { return @{ Options = @('일반', '어려움', '매우 어려움'); Current = [string]$Item.difficulty } }
    3 { return @{ Options = @('1-1', '1-2', '1-3', '2-1', '2-2', '2-3'); Current = [string]$Item.stage } }
    4 {
      $planCurrent = $(if ([bool]$Item.coin -and [bool]$Item.doubleLoot) { '20개' } elseif ([bool]$Item.coin) { '10개' } else { '0개' })
      return @{ Options = @('0개', '10개', '20개'); Current = $planCurrent }
    }
    5 {
      if (-not [bool]$Item.coin) { return $null }
      if ([bool]$Item.doubleLoot -and -not [bool]$Item.noDoubleSweep) { return $null }
      $planCurrent = $(if ([bool]$Item.exhaustContinue) { '진행' } else { '멈춤' })
      return @{ Options = @('진행', '멈춤'); Current = $planCurrent }
    }
    6 {
      if (-not [bool]$Item.doubleLoot) { return $null }
      $planCurrent = $(if ([bool]$Item.noDoubleSweep) { '소탕만' } else { '멈춤' })
      return @{ Options = @('소탕만', '멈춤'); Current = $planCurrent }
    }
  }
  return $null
}

function Set-CrItemCellValue {
  # 선택값을 항목에 적용하고 [추가]와 동일한 일관성 정규화를 수행합니다
  # (coin=false → 전부 false / double 아니면 noDouble=false / 더블+멈춤이면 exhaust=false).
  param($Item, [int]$ColumnIndex, [string]$Value)
  $newDifficulty = [string]$Item.difficulty
  $newStage = [string]$Item.stage
  $newCoin = [bool]$Item.coin
  $newDouble = [bool]$Item.doubleLoot
  $newExhaust = [bool]$Item.exhaustContinue
  $newNoDouble = [bool]$Item.noDoubleSweep
  switch ($ColumnIndex) {
    2 { $newDifficulty = $Value }
    3 { $newStage = $Value }
    4 { $newCoin = ($Value -ne '0개'); $newDouble = ($Value -eq '20개') }
    5 { $newExhaust = ($Value -eq '진행') }
    6 { $newNoDouble = ($Value -eq '소탕만') }
  }
  $newDouble = ($newCoin -and $newDouble)
  $newNoDouble = ($newDouble -and $newNoDouble)
  $newExhaust = ($newCoin -and $newExhaust -and ((-not $newDouble) -or $newNoDouble))
  return [pscustomobject]@{
    difficulty = $newDifficulty; stage = $newStage; coin = $newCoin; doubleLoot = $newDouble
    exhaustContinue = $newExhaust; noDoubleSweep = $newNoDouble
  }
}

function Get-AcrCellEditPlan {
  # 어비스 리스트 셀 편집 계획. Scope='row'(행 단위: 난이도/어비스 던전) 또는
  # 'all'(리스트 전체 일괄: 방식/매칭 - 통일 규칙). 혼자하기 항목의 매칭 열은 편집 불가.
  # 방식 열은 방식+매칭을 한 번에 고르는 원자 옵션 4개 (혼자→함께 전환 시 매칭 명시 선택 보장).
  param([int]$ColumnIndex, $Item)
  $planMode = $(if ([string]$Item.mode -eq 'party') { 'party' } else { 'solo' })
  switch ($ColumnIndex) {
    2 {
      $planCurrent = $(if ($planMode -eq 'party') { "함께하기 · $([string]$Item.matching)" } else { '혼자하기' })
      return @{ Options = @('혼자하기', '함께하기 · 우연한 만남', '함께하기 · 파티 찾기', '함께하기 · 파티(파티장)')
                Current = $planCurrent; Scope = 'all' }
    }
    3 {
      $planOptions = @('게임 그대로', '입문', '어려움', '매우 어려움')
      if ($planMode -eq 'party') {
        for ($hellLevel = 1; $hellLevel -le 10; $hellLevel++) { $planOptions += "지옥$hellLevel" }
      }
      return @{ Options = $planOptions; Current = [string]$Item.difficulty; Scope = 'row' }
    }
    4 { return @{ Options = @('허상의 정박지', '광기의 동굴', '흩어진 물길'); Current = [string]$Item.dungeon; Scope = 'row' } }
    5 {
      if ($planMode -ne 'party') { return $null }
      return @{ Options = @('우연한 만남', '파티 찾기', '파티(파티장)'); Current = [string]$Item.matching; Scope = 'all' }
    }
  }
  return $null
}

function ConvertFrom-AcrModeOption {
  # 방식 열 드롭다운 표시 문구 → 구조화 키 (파싱 대신 고정 매핑 - 설계 합의)
  param([string]$OptionText)
  switch ([string]$OptionText) {
    '혼자하기'                { return @{ Mode = 'solo'; Matching = '없음' } }
    '함께하기 · 우연한 만남'   { return @{ Mode = 'party'; Matching = '우연한 만남' } }
    '함께하기 · 파티 찾기'     { return @{ Mode = 'party'; Matching = '파티 찾기' } }
    '함께하기 · 파티(파티장)'  { return @{ Mode = 'party'; Matching = '파티(파티장)' } }
  }
  return $null
}

function Convert-AcrItemsForGlobalSetting {
  # 방식/매칭 리스트 일괄 변환 (순수). 함께→혼자 전환 시 함께하기 전용 난이도(지옥N)는
  # '매우 어려움'으로 강등하고 강등 건수를 반환합니다 (호출부가 1건 이상이면 사전 확인창).
  # 반환: 단일 해시테이블 @{ Items = [array]; DowngradeCount = N } (PS 5.1 배열 풀림 방지)
  param($Items, [string]$Mode, [string]$Matching)
  $convertedItems = @()
  $downgradeCount = 0
  foreach ($convertItem in @($Items)) {
    if ($null -eq $convertItem) { continue }
    $convertDifficulty = [string]$convertItem.difficulty
    if ($Mode -ne 'party' -and $convertDifficulty -like '지옥*') {
      $convertDifficulty = '매우 어려움'
      $downgradeCount++
    }
    $convertedItems += [pscustomobject]@{
      kind = 'abyss'; mode = $Mode; difficulty = $convertDifficulty
      dungeon = [string]$convertItem.dungeon
      matching = $(if ($Mode -eq 'party') { $Matching } else { '없음' })
    }
  }
  return @{ Items = $convertedItems; DowngradeCount = $downgradeCount }
}

function Set-CustomListRowTexts {
  # 던전 리스트 1행의 표시 텍스트를 항목 값으로 갱신합니다 - 표시 규칙의 단일 소스
  # ([추가]와 셀 편집이 공용. 읽기는 Get-CustomItemsFromList 가 이 문자열을 역해석하므로
  # 표기 변경 시 함께 수정):
  # 은동전 열 = 더블 루팅까지면 '20개', 소탕만이면 '10개', 미사용이면 '0개'.
  # 소진 시 열 = 은동전 미사용 '—' / 더블+멈춤 '—'(소진 분기 도달 불가) / 그 외 진행·멈춤.
  # 더블 불가 시 열 = 더블 루팅 아니면 '—' / noDoubleSweep 이면 '소탕만', 아니면 '멈춤'.
  param($Row, $Item)
  $rowCoin = [bool]$Item.coin
  $rowDouble = [bool]$Item.doubleLoot
  $rowExhaust = [bool]$Item.exhaustContinue
  $rowNoDouble = [bool]$Item.noDoubleSweep
  $Row.SubItems[2].Text = [string]$Item.difficulty
  $Row.SubItems[3].Text = [string]$Item.stage
  $Row.SubItems[4].Text = $(if ($rowCoin -and $rowDouble) { '20개' } elseif ($rowCoin) { '10개' } else { '0개' })
  $Row.SubItems[5].Text = $(if (-not $rowCoin) { '—' }
    elseif ($rowDouble -and -not $rowNoDouble) { '—' }
    elseif ($rowExhaust) { '진행' } else { '멈춤' })
  $Row.SubItems[6].Text = $(if (-not $rowDouble) { '—' }
    elseif ($rowNoDouble) { '소탕만' } else { '멈춤' })
}

function Add-CustomListRow {
  # 리스트뷰에 항목 1행 추가 (열: 체크빈칸 / # / 난이도 / 구역 / 은동전 판당 소모량 / 소진 시 / 더블 불가 시).
  # 표시 규칙은 Set-CustomListRowTexts 가 단일 소스입니다.
  param([string]$Difficulty, [string]$Stage, [bool]$Coin, [bool]$DoubleLoot,
    [bool]$ExhaustContinue, [bool]$NoDoubleSweep)
  $row = New-Object System.Windows.Forms.ListViewItem('')
  [void]$row.SubItems.Add([string]($lvCrList.Items.Count + 1))
  for ($fillIndex = 2; $fillIndex -le 6; $fillIndex++) { [void]$row.SubItems.Add('') }
  Set-CustomListRowTexts -Row $row -Item ([pscustomobject]@{
      difficulty = $Difficulty; stage = $Stage; coin = $Coin; doubleLoot = $DoubleLoot
      exhaustContinue = $ExhaustContinue; noDoubleSweep = $NoDoubleSweep
    })
  [void]$lvCrList.Items.Add($row)
}

function Update-CustomListNumbers {
  # 각 행의 # 열을 1부터 다시 매깁니다 (추가/삭제/이동 직후 호출. crLoading 가드로 이벤트 재발화 억제)
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    for ($rowIndex = 0; $rowIndex -lt $lvCrList.Items.Count; $rowIndex++) {
      $lvCrList.Items[$rowIndex].SubItems[1].Text = [string]($rowIndex + 1)
    }
  } finally { $script:crLoading = $prevLoading }
}

function Move-CustomListRow {
  # 선택한 1줄을 위(-1)/아래(+1)로 이동합니다
  param([int]$Delta)
  if ($lvCrList.SelectedItems.Count -eq 0) { return }
  $row = $lvCrList.SelectedItems[0]
  $fromIndex = $row.Index
  $toIndex = $fromIndex + $Delta
  if ($toIndex -lt 0 -or $toIndex -ge $lvCrList.Items.Count) { return }
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    $lvCrList.Items.RemoveAt($fromIndex)
    [void]$lvCrList.Items.Insert($toIndex, $row)
    Update-CustomListNumbers
    $row.Selected = $true
    $lvCrList.EnsureVisible($toIndex)
  } finally { $script:crLoading = $prevLoading }
  if ($script:uiReady) { Save-CustomRepeatToConfig }
}

function Get-CustomItemsFromList {
  # 리스트뷰 → 계약 형태 항목 배열(@{difficulty; stage; coin; doubleLoot; exhaustContinue; noDoubleSweep}).
  # 소진 시/더블 불가 시 열의 '—' 는 false 로 읽습니다 ([추가] 시 정규화와 일치 - 도달 불가/무의미 상태).
  # PS 5.1 배열 풀림 주의: 열거용이므로 return $items 그대로 두고 호출부에서 @()로 감쌉니다.
  $items = @()
  $crSourceRows = @($lvCrList.Items)
  if ($script:customViewShuffled) { $crSourceRows = @($crSourceRows | Sort-Object { $(if ($null -ne $_.Tag) { [int]$_.Tag } else { [int]$_.Index }) }) }
  foreach ($listRow in $crSourceRows) {
    $items += [pscustomobject]@{
      difficulty      = [string]$listRow.SubItems[2].Text
      stage           = [string]$listRow.SubItems[3].Text
      coin            = ($listRow.SubItems[4].Text -ne '0개')
      doubleLoot      = ($listRow.SubItems[4].Text -eq '20개')
      exhaustContinue = ($listRow.SubItems[5].Text -eq '진행')
      noDoubleSweep   = ($listRow.SubItems[6].Text -eq '소탕만')
    }
  }
  return $items
}

function Set-AbyssListRowTexts {
  # 어비스 리스트 1행의 표시 텍스트를 항목 값으로 갱신합니다 - 표시 규칙의 단일 소스
  # ([추가]와 셀 편집 공용. Get-AbyssCustomItemsFromList 가 역해석하므로 표기 변경 시 함께 수정)
  param($Row, $Item)
  $rowMode = $(if ([string]$Item.mode -eq 'party' -or [string]$Item.mode -eq '함께하기') { 'party' } else { 'solo' })
  $rowMatching = [string]$Item.matching
  $Row.SubItems[2].Text = $(if ($rowMode -eq 'party') { '함께하기' } else { '혼자하기' })
  $Row.SubItems[3].Text = [string]$Item.difficulty
  $Row.SubItems[4].Text = [string]$Item.dungeon
  $Row.SubItems[5].Text = $(if ($rowMode -eq 'party' -and -not [string]::IsNullOrWhiteSpace($rowMatching) -and $rowMatching -ne '없음') { $rowMatching } else { '—' })
}

function Add-AbyssCustomListRow {
  param([string]$Mode, [string]$Difficulty, [string]$Dungeon, [string]$Matching)
  $normalizedMode = $(if ($Mode -eq 'party' -or $Mode -eq '함께하기') { 'party' } else { 'solo' })
  $row = New-Object System.Windows.Forms.ListViewItem('')
  [void]$row.SubItems.Add([string]($lvAcrList.Items.Count + 1))
  for ($fillIndex = 2; $fillIndex -le 5; $fillIndex++) { [void]$row.SubItems.Add('') }
  Set-AbyssListRowTexts -Row $row -Item ([pscustomobject]@{
      kind = 'abyss'; mode = $normalizedMode; difficulty = $Difficulty; dungeon = $Dungeon
      matching = $(if ($normalizedMode -eq 'party') { $Matching } else { '없음' })
    })
  [void]$lvAcrList.Items.Add($row)
}

function Update-AbyssCustomListNumbers {
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    for ($rowIndex = 0; $rowIndex -lt $lvAcrList.Items.Count; $rowIndex++) {
      $lvAcrList.Items[$rowIndex].SubItems[1].Text = [string]($rowIndex + 1)
    }
  } finally { $script:crLoading = $prevLoading }
}

function Move-AbyssCustomListRow {
  param([int]$Delta)
  if ($lvAcrList.SelectedItems.Count -eq 0) { return }
  $row = $lvAcrList.SelectedItems[0]
  $fromIndex = $row.Index
  $toIndex = $fromIndex + $Delta
  if ($toIndex -lt 0 -or $toIndex -ge $lvAcrList.Items.Count) { return }
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    $lvAcrList.Items.RemoveAt($fromIndex)
    [void]$lvAcrList.Items.Insert($toIndex, $row)
    Update-AbyssCustomListNumbers
    $row.Selected = $true
    $lvAcrList.EnsureVisible($toIndex)
  } finally { $script:crLoading = $prevLoading }
  # 순서가 바뀌면 기준이 되는 첫 항목도 바뀔 수 있어 잠금을 다시 계산합니다
  Update-AbyssInputLock
  if ($script:uiReady) { Save-CustomRepeatToConfig }
}

function Get-AbyssCustomItemsFromList {
  $items = @()
  $acrSourceRows = @($lvAcrList.Items)
  if ($script:customViewShuffled) { $acrSourceRows = @($acrSourceRows | Sort-Object { $(if ($null -ne $_.Tag) { [int]$_.Tag } else { [int]$_.Index }) }) }
  foreach ($listRow in $acrSourceRows) {
    $mode = $(if ($listRow.SubItems[2].Text -eq '함께하기') { 'party' } else { 'solo' })
    $items += [pscustomobject]@{
      kind       = 'abyss'
      mode       = $mode
      difficulty = [string]$listRow.SubItems[3].Text
      dungeon    = [string]$listRow.SubItems[4].Text
      matching   = $(if ($mode -eq 'party') { [string]$listRow.SubItems[5].Text } else { '없음' })
    }
  }
  return $items
}

# ============================================================
#  심층던전 커스텀 반복 - 헬퍼 (2026-07-28, 경량안 합의로 던전 커스텀과 분리)
#  항목 계약은 던전과 동일한 6필드(difficulty/stage/coin/doubleLoot/exhaustContinue/
#  noDoubleSweep)를 쓰되 difficulty='어려움'/doubleLoot=false/noDoubleSweep=false 고정 -
#  토큰·지문·마커·워커 env 계약(Format-CustomItemToken)을 그대로 재사용하기 위함입니다.
# ============================================================
function Get-DeepStageInternal {
  # 표시용 'D1-1' → 내부 표기 '1-1'. 형식 밖 값은 '' (호출부가 추가/저장을 건너뜀)
  param([string]$Display)
  if ([string]$Display -match '^D([12]-[123])$') { return $Matches[1] }
  return ''
}

function Get-DeepStageDisplay {
  # 내부 표기 '1-1' → 표시용 'D1-1'. 형식 밖 값은 그대로 반환 (방어적 표시)
  param([string]$Stage)
  if ([string]$Stage -match '^[12]-[123]$') { return ('D' + $Stage) }
  return [string]$Stage
}

function Get-DeepCustomItemLabel {
  # 심층 항목 로그 표기: 'D1-1 (마족공물)' / 'D1-1'
  param($Item)
  $label = Get-DeepStageDisplay -Stage ([string]$Item.stage)
  if ([bool]$Item.coin) { $label += ' (마족공물)' }
  return $label
}

function Get-DeepTributeTotalPerLap {
  # 리스트 1바퀴에 필요한 마족공물 합계 (심층 커스텀은 어려움 고정 - 소탕 1개/미사용 0개)
  param($Items)
  $total = 0
  foreach ($totalItem in @($Items)) {
    if ($null -eq $totalItem) { continue }
    if ([bool]$totalItem.coin) { $total += 1 }
  }
  return $total
}

function Get-DeepCustomListCompact {
  # 심층 리스트 압축 표기 (워커 [설정] 스냅샷 한 줄 기록용).
  # 항목당 'D1-1(1,멈)' 형식: 괄호 안은 판당 공물 소모량(1/0)과 소진 대응(진/멈).
  param($Items)
  $parts = @()
  $seq = 0
  foreach ($compactItem in @($Items)) {
    if ($null -eq $compactItem) { continue }
    $seq++
    $suffix = if (-not [bool]$compactItem.coin) { '(0)' }
    elseif ([bool]$compactItem.exhaustContinue) { '(1,진)' } else { '(1,멈)' }
    $parts += ('{0}.{1}{2}' -f $seq, (Get-DeepStageDisplay -Stage ([string]$compactItem.stage)), $suffix)
  }
  return ($parts -join ' ')
}

function Set-DeepListRowTexts {
  # 심층 리스트 1행의 표시 텍스트 갱신 - 표시 규칙의 단일 소스
  # ([추가]와 셀 편집 공용. Get-DeepCustomItemsFromList 가 역해석하므로 표기 변경 시 함께 수정):
  # 구역 열 = 'D1-1' 표기. 마족공물 열 = 사용 '1개' / 미사용 '0개'.
  # 소진 시 열 = 공물 미사용 '—' / 그 외 진행·멈춤.
  param($Row, $Item)
  $rowCoin = [bool]$Item.coin
  $Row.SubItems[2].Text = Get-DeepStageDisplay -Stage ([string]$Item.stage)
  $Row.SubItems[3].Text = $(if ($rowCoin) { '1개' } else { '0개' })
  $Row.SubItems[4].Text = $(if (-not $rowCoin) { '—' }
    elseif ([bool]$Item.exhaustContinue) { '진행' } else { '멈춤' })
}

function Add-DeepCustomListRow {
  # 심층 리스트뷰에 항목 1행 추가 (열: 체크빈칸 / # / 구역 / 마족공물 / 소진 시)
  param([string]$Stage, [bool]$Coin, [bool]$ExhaustContinue)
  $row = New-Object System.Windows.Forms.ListViewItem('')
  [void]$row.SubItems.Add([string]($lvDcrList.Items.Count + 1))
  for ($fillIndex = 2; $fillIndex -le 4; $fillIndex++) { [void]$row.SubItems.Add('') }
  Set-DeepListRowTexts -Row $row -Item ([pscustomobject]@{
      difficulty = '어려움'; stage = $Stage; coin = $Coin; doubleLoot = $false
      exhaustContinue = $ExhaustContinue; noDoubleSweep = $false
    })
  [void]$lvDcrList.Items.Add($row)
}

function Update-DeepCustomListNumbers {
  # 각 행의 # 열을 1부터 다시 매깁니다 (추가/삭제/이동 직후 호출. crLoading 가드로 이벤트 재발화 억제)
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    for ($rowIndex = 0; $rowIndex -lt $lvDcrList.Items.Count; $rowIndex++) {
      $lvDcrList.Items[$rowIndex].SubItems[1].Text = [string]($rowIndex + 1)
    }
  } finally { $script:crLoading = $prevLoading }
}

function Move-DeepCustomListRow {
  # 선택한 1줄을 위(-1)/아래(+1)로 이동합니다
  param([int]$Delta)
  if ($lvDcrList.SelectedItems.Count -eq 0) { return }
  $row = $lvDcrList.SelectedItems[0]
  $fromIndex = $row.Index
  $toIndex = $fromIndex + $Delta
  if ($toIndex -lt 0 -or $toIndex -ge $lvDcrList.Items.Count) { return }
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    $lvDcrList.Items.RemoveAt($fromIndex)
    [void]$lvDcrList.Items.Insert($toIndex, $row)
    Update-DeepCustomListNumbers
    $row.Selected = $true
    $lvDcrList.EnsureVisible($toIndex)
  } finally { $script:crLoading = $prevLoading }
  if ($script:uiReady) { Save-DeepCustomRepeatToConfig }
}

function Get-DeepCustomItemsFromList {
  # 심층 리스트뷰 → 계약 형태 항목 배열 (던전과 동일 6필드 - 고정값 포함).
  # PS 5.1 배열 풀림 주의: 열거용이므로 return $items 그대로 두고 호출부에서 @()로 감쌉니다.
  $items = @()
  $dcrSourceRows = @($lvDcrList.Items)
  if ($script:customViewShuffled) { $dcrSourceRows = @($dcrSourceRows | Sort-Object { $(if ($null -ne $_.Tag) { [int]$_.Tag } else { [int]$_.Index }) }) }
  foreach ($listRow in $dcrSourceRows) {
    $items += [pscustomobject]@{
      difficulty      = '어려움'
      stage           = (Get-DeepStageInternal -Display ([string]$listRow.SubItems[2].Text))
      coin            = ($listRow.SubItems[3].Text -ne '0개')
      doubleLoot      = $false
      exhaustContinue = ($listRow.SubItems[4].Text -eq '진행')
      noDoubleSweep   = $false
    }
  }
  return $items
}

function Get-DcrCellEditPlan {
  # 심층 리스트 셀 편집 계획: 편집 가능하면 @{ Options; Current }, 아니면 $null (순수 - 진리표 대상).
  # 소진 시 열은 마족공물 사용 항목에서만 편집할 수 있습니다 ('—' 표기 상태는 편집 무의미).
  param([int]$ColumnIndex, $Item)
  switch ($ColumnIndex) {
    2 {
      return @{ Options = @('D1-1', 'D1-2', 'D1-3', 'D2-1', 'D2-2', 'D2-3')
                Current = (Get-DeepStageDisplay -Stage ([string]$Item.stage)) }
    }
    3 {
      $planCurrent = $(if ([bool]$Item.coin) { '1개' } else { '0개' })
      return @{ Options = @('0개', '1개'); Current = $planCurrent }
    }
    4 {
      if (-not [bool]$Item.coin) { return $null }
      $planCurrent = $(if ([bool]$Item.exhaustContinue) { '진행' } else { '멈춤' })
      return @{ Options = @('진행', '멈춤'); Current = $planCurrent }
    }
  }
  return $null
}

function Set-DcrItemCellValue {
  # 선택값을 심층 항목에 적용하고 [추가]와 동일한 정규화를 수행합니다 (coin=false → exhaust=false).
  # 고정 필드(difficulty/doubleLoot/noDoubleSweep)는 항상 고정값으로 되돌립니다 (순수 - 진리표 대상).
  param($Item, [int]$ColumnIndex, [string]$Value)
  $newStage = [string]$Item.stage
  $newCoin = [bool]$Item.coin
  $newExhaust = [bool]$Item.exhaustContinue
  switch ($ColumnIndex) {
    2 {
      $parsedStage = Get-DeepStageInternal -Display $Value
      if ($parsedStage) { $newStage = $parsedStage }
    }
    3 { $newCoin = ($Value -ne '0개') }
    4 { $newExhaust = ($Value -eq '진행') }
  }
  $newExhaust = ($newCoin -and $newExhaust)
  return [pscustomobject]@{
    difficulty = '어려움'; stage = $newStage; coin = $newCoin; doubleLoot = $false
    exhaustContinue = $newExhaust; noDoubleSweep = $false
  }
}

function Invoke-DcrCellEdit {
  # 심층 리스트 행 단위 셀 편집 적용: 정규화 → 행 텍스트 갱신 → 저장(실패 시 원복) →
  # 전환 규칙 경고 (던전 Invoke-CrCellEdit 와 동일 구조 - 심층 전용 저장/라벨만 다름)
  param([int]$RowIndex, [int]$ColumnIndex, [string]$Value)
  $editItems = @(Get-DeepCustomItemsFromList)
  if ($RowIndex -ge $editItems.Count) { return }
  $beforeItem = $editItems[$RowIndex]
  $afterItem = Set-DcrItemCellValue -Item $beforeItem -ColumnIndex $ColumnIndex -Value $Value
  if (([string]$beforeItem.stage -eq [string]$afterItem.stage) -and
      ([bool]$beforeItem.coin -eq [bool]$afterItem.coin) -and
      ([bool]$beforeItem.exhaustContinue -eq [bool]$afterItem.exhaustContinue)) { return }
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try { Set-DeepListRowTexts -Row $lvDcrList.Items[$RowIndex] -Item $afterItem } finally { $script:crLoading = $prevLoading }
  $script:lastCustomSaveOk = $true
  if ($script:uiReady) { Save-DeepCustomRepeatToConfig }
  if (-not $script:lastCustomSaveOk) {
    # 저장 실패: 화면과 config 이 어긋나지 않게 행을 원복하고 공물 합계도 되돌립니다
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try { Set-DeepListRowTexts -Row $lvDcrList.Items[$RowIndex] -Item $beforeItem } finally { $script:crLoading = $prevLoading }
    Update-DeepTributeTotalLabel
    # 롤백이 끝난 실제 리스트 기준으로 혼합 잠금을 다시 계산합니다 (2026-07-31 점검)
    Update-CustomRepeatMixLock -Items @(Get-DeepCustomItemsFromList) `
      -RbInfinite $rbDcrInfinite -RbCount $rbDcrCount -NumLaps $numDcrLaps -StateKey 'dcr'
    Update-CustomRandomMixGate -Toggle $chkDcrRandom -Items @(Get-DeepCustomItemsFromList) -SectionName 'deepCustomRepeat'
    Add-GuiLog '[경고] 셀 수정 저장에 실패해 항목을 되돌렸습니다.'
    return
  }
  Add-GuiLog ('[안내] 심층 항목 {0} 수정: {1} → {2}' -f ($RowIndex + 1),
    (Get-DeepCustomItemLabel -Item $beforeItem), (Get-DeepCustomItemLabel -Item $afterItem))
  $editRepeat = $(if ($rbDcrCount.Checked) { 'count' } else { 'infinite' })
  $editIssues = @(Get-CustomTransitionIssues -Items @(Get-DeepCustomItemsFromList) `
      -ListRepeat $editRepeat -ListRepeatCount ([int]$numDcrLaps.Value))
  foreach ($editIssue in $editIssues) {
    $editWrapTag = $(if ([bool]$editIssue.Wrap) { ' [바퀴 순환: 마지막 → 첫 항목]' } else { '' })
    Add-GuiLog ('[경고] {0} → {1}{2}: {3} - 이대로는 시작할 수 없습니다 (순서 조정 또는 항목 수정으로 해소해 주세요).' -f `
        $editIssue.From, $editIssue.To, $editWrapTag, $editIssue.Reason)
  }
}

function Invoke-LcrCellEdit {
  # 생활 리스트 행 단위 셀 편집 적용 (Invoke-DcrCellEdit 와 같은 골격 - 생활 전용 저장/라벨만 다름).
  # 롤백에서 부르면 안 되는 것: Update-CustomRepeatMixLock('lcr' 키가 $script:crMixLockState 에
  # 없어 $null 참조 예외) / Update-CustomRandomMixGate(생활에 없는 stage 의존 + 진행 기록·마커를
  # 비가역으로 지울 수 있음). 생활이 되돌릴 것은 행 텍스트와 합계 라벨 둘뿐입니다.
  param([int]$RowIndex, [int]$ColumnIndex, [string]$Value)
  $editItems = @(Get-LifeCustomItemsFromList)
  if ($RowIndex -ge $editItems.Count) { return }
  $beforeItem = $editItems[$RowIndex]
  $afterItem = Set-LcrItemCellValue -Item $beforeItem -ColumnIndex $ColumnIndex -Value $Value
  # 비교는 **정규화가 끝난 after 기준**입니다: 스킬만 바꿔도 대상이 함께 폴백되므로
  # '내가 고른 열'만 비교하면 오판합니다. 같은 스킬을 다시 고르면 3필드가 전부 같아
  # 여기서 조용히 끝납니다 (불필요한 저장·로그 없음 - 기존 3리스트와 같은 계약)
  if (([string]$beforeItem.skill -eq [string]$afterItem.skill) -and
      ([string]$beforeItem.target -eq [string]$afterItem.target) -and
      ([int]$beforeItem.count -eq [int]$afterItem.count)) { return }
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try { Set-LifeListRowTexts -Row $lvLcrList.Items[$RowIndex] -Item $afterItem } finally { $script:crLoading = $prevLoading }
  $script:lastCustomSaveOk = $true
  if ($script:uiReady) { Save-LifeCustomRepeatToConfig }
  if (-not $script:lastCustomSaveOk) {
    # 저장 실패: 화면과 config 이 어긋나지 않게 행을 원복하고 합계 라벨도 되돌립니다
    # (저장 함수 말미의 라벨 갱신이 try/catch 밖이라 실패해도 이미 새 값으로 바뀌어 있음).
    # 순서는 반드시 행 복원 → 라벨 (라벨이 리스트뷰를 다시 읽으므로 역순이면 무의미)
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try { Set-LifeListRowTexts -Row $lvLcrList.Items[$RowIndex] -Item $beforeItem } finally { $script:crLoading = $prevLoading }
    Update-LifeCustomTotalLabel
    Add-GuiLog '[경고] 셀 수정 저장에 실패해 항목을 되돌렸습니다.'
    return
  }
  Add-GuiLog ('[안내] 생활 항목 {0} 수정: {1} → {2}' -f ($RowIndex + 1),
    (Get-LifeCustomItemLabel -Item $beforeItem), (Get-LifeCustomItemLabel -Item $afterItem))
}

function Update-DeepTributeTotalLabel {
  # 심층 하단 줄의 마족공물 예산 라벨 갱신 (리스트 편집·리스트 반복 설정 변경·복원 시 호출)
  $totalItems = @(Get-DeepCustomItemsFromList)
  $perLap = Get-DeepTributeTotalPerLap -Items $totalItems
  if ($rbDcrCount.Checked) {
    $lblDcrTributeTotal.Text = ('바퀴당 {0:N0} · 총 {1:N0}개' -f $perLap, ($perLap * [int]$numDcrLaps.Value))
  } else {
    $lblDcrTributeTotal.Text = ('바퀴당 마족공물 {0:N0}개' -f $perLap)
  }
}

function Set-DeepCustomRepeatOnConfig {
  # deepCustomRepeat 섹션을 현재 UI 상태로 갱신합니다 (Save-Config 는 호출부 몫).
  # progress 는 절대 건드리지 않고 그대로 옮겨 담습니다 (진행 기록 비파괴 원칙).
  param($Config)
  $prevProgress = $null
  if ($Config.PSObject.Properties['deepCustomRepeat'] -and $Config.deepCustomRepeat -and
      $Config.deepCustomRepeat.PSObject.Properties['progress']) {
    $prevProgress = $Config.deepCustomRepeat.progress
  }
  $node = [pscustomobject]@{
    '_설명'         = "'심층던전 커스텀 반복' 모드 설정입니다. items 리스트를 위에서부터 순서대로 1판씩 실행합니다. progress 는 이어가기용 진행 기록이므로 직접 수정하지 마세요."
    '_items'        = "각 항목: difficulty(항상 '어려움')/stage/coin(마족공물 사용)/doubleLoot(항상 false) + exhaustContinue(공물 소진 시 true=미사용으로 진행, false=멈춤) / noDoubleSweep(항상 false). 던전 커스텀과 같은 항목 계약을 사용합니다"
    items           = [array]@(Get-DeepCustomItemsFromList)
    randomOrder     = [bool]$chkDcrRandom.Checked
    listRepeat      = $(if ($rbDcrCount.Checked) { 'count' } else { 'infinite' })
    listRepeatCount = [int]$numDcrLaps.Value
    progress        = $prevProgress
  }
  if ($Config.PSObject.Properties['deepCustomRepeat']) { $Config.deepCustomRepeat = $node }
  else { $Config | Add-Member -NotePropertyName 'deepCustomRepeat' -NotePropertyValue $node }
}

function Save-DeepCustomRepeatToConfig {
  # 심층 커스텀 즉시 저장 경로 (던전/어비스 공용 Save-CustomRepeatToConfig 와 분리 -
  # 경량안 합의: 기존 저장 경로 무접촉. 실패 신호는 같은 부채널을 사용합니다)
  # 혼합 리스트면 저장 전에 반복을 '횟수 1바퀴'로 강제해 그 값이 저장되게 합니다
  Update-CustomRepeatMixLock -Items @(Get-DeepCustomItemsFromList) `
    -RbInfinite $rbDcrInfinite -RbCount $rbDcrCount -NumLaps $numDcrLaps -StateKey 'dcr'
  Update-CustomRandomMixGate -Toggle $chkDcrRandom -Items @(Get-DeepCustomItemsFromList) -SectionName 'deepCustomRepeat'
  $script:lastCustomSaveOk = $false
  $cfg = Read-Config
  if (-not $cfg) {
    Add-GuiLog '[경고] config.json 을 읽지 못해 심층 커스텀 반복 설정을 저장하지 못했습니다 - 화면 목록과 저장된 설정이 다를 수 있습니다. 목록을 한 번 더 변경하면 다시 저장을 시도합니다.'
    return
  }
  Set-DeepCustomRepeatOnConfig -Config $cfg
  try {
    Save-Config $cfg
    $script:lastCustomSaveOk = $true
  }
  catch {
    # 셀 편집 외 경로(추가/삭제/이동 등)는 롤백이 없어 화면과 저장 파일이 어긋난 채 남을 수
    # 있습니다 - 어긋남과 복구 방법을 문구로 명시 (2026-08-01 전수 점검. 다음 저장 성공 시 해소)
    Add-GuiLog "[경고] 심층 커스텀 반복 설정 저장 실패: $($_.Exception.Message) - 화면 목록과 저장된 설정이 다를 수 있습니다. 목록을 한 번 더 변경하면 다시 저장을 시도합니다."
  }
  Update-DeepTributeTotalLabel
}

# ============================================================
#  생활(채집) 커스텀 반복 - 데이터 계층 (v2.0.0 - 2026-08-08)
#  던전/어비스/심층과 다른 점 하나: **항목마다 반복 횟수**를 가집니다.
#  진행 기록(lap/index)은 공용 계약 그대로 '실행 단위 1칸 = index 1칸'이므로,
#  count 를 컨텍스트 계산 시점에 펼쳐서(Expand-LifeCustomItems) 그 배열 위에서 셉니다.
#  등록 목록(items)은 펼치지 않고 그대로 저장 - 지문/랜덤 순열은 등록 단위입니다.
# ============================================================
function Get-LifeSkillNameById {
  # 스킬 Id → 표시명 ('daily' → '일상 채집'). 못 찾으면 Id 를 그대로 돌려줍니다
  # (config 를 직접 편집해 모르는 Id 가 들어와도 로그가 비지 않게)
  param([string]$Id)
  foreach ($skillDef in @($script:lifeSkills)) {
    if ([string]$skillDef.Id -eq $Id) { return [string]$skillDef.Name }
  }
  return $Id
}

function Get-LifeSkillIdByName {
  # 표시명 → 스킬 Id (리스트뷰는 표시명을 담으므로 역해석에 필요). 못 찾으면 빈 문자열
  param([string]$Name)
  foreach ($skillDef in @($script:lifeSkills)) {
    if ([string]$skillDef.Name -eq $Name) { return [string]$skillDef.Id }
  }
  return ''
}

function Get-LifeCustomItemLabel {
  # 로그·팝업용 항목 표기: '일상 채집 - 사과 나무 3회' (1회면 횟수 생략)
  param($Item)
  $label = ('{0} - {1}' -f (Get-LifeSkillNameById -Id ([string]$Item.skill)), [string]$Item.target)
  $labelCount = 1
  try { $labelCount = [int]$Item.count } catch { $labelCount = 1 }
  if ($labelCount -gt 1) { $label += (' {0}회' -f $labelCount) }
  return $label
}

function Expand-LifeCustomItems {
  # 등록 항목(항목마다 count 회) → 실행 단위 배열. 한 항목의 count 사이클을 모두 끝내야
  # 다음 항목으로 넘어가는 계약이라 같은 항목을 count 개 연속으로 놓습니다.
  # 각 원소에 rep(몇 번째인지) / repTotal / sourceIndex(등록 순번)를 함께 실어
  # 로그의 '(2/3회)' 표기와 리스트 하이라이트가 원본 항목을 찾을 수 있게 합니다.
  # 열거용이라 return $expanded + 호출부 @() 규약 (PS 5.1 배열 풀림).
  param($Items)
  $expanded = @()
  $sourceIndex = 0
  foreach ($srcItem in @($Items)) {
    if ($null -eq $srcItem) { continue }
    $repTotal = 1
    try { $repTotal = [int]$srcItem.count } catch { $repTotal = 1 }
    if ($repTotal -lt 1) { $repTotal = 1 }
    if ($repTotal -gt 99) { $repTotal = 99 }
    for ($rep = 1; $rep -le $repTotal; $rep++) {
      $expanded += [pscustomobject]@{
        kind        = 'life'
        skill       = [string]$srcItem.skill
        target      = [string]$srcItem.target
        count       = $repTotal
        rep         = $rep
        repTotal    = $repTotal
        sourceIndex = $sourceIndex
      }
    }
    $sourceIndex++
  }
  return $expanded
}

function Get-LifeCustomPositionText {
  # 진행 위치 표기: '2바퀴째 3/7번 (일상 채집 - 사과 나무 2/3회)'.
  # 앞부분은 공용 표기(실행 단위 기준)를 그대로 쓰고, 뒤에 '이 항목의 몇 번째 사이클'인지를
  # 덧붙입니다 - 실행 단위로만 세면 리스트의 어느 줄인지 알 수 없기 때문입니다.
  param([int]$Lap, [int]$Index, [int]$Total, $Item)
  $text = Get-CustomPositionText -Lap $Lap -Index $Index -Total $Total
  if ($null -eq $Item) { return $text }
  $repNow = 1; $repAll = 1
  try { $repNow = [int]$Item.rep } catch { $repNow = 1 }
  try { $repAll = [int]$Item.repTotal } catch { $repAll = 1 }
  if ($repAll -lt 1) { $repAll = 1 }
  return ('{0} ({1} - {2} {3}/{4}회)' -f $text,
    (Get-LifeSkillNameById -Id ([string]$Item.skill)), [string]$Item.target, $repNow, $repAll)
}

function Get-LifeCustomListCompact {
  # 생활 리스트 압축 표기 (워커 [설정] 스냅샷 한 줄 기록용).
  # 항목당 '1.일상 채집/사과 나무x3' 형식
  param($Items)
  $parts = @()
  $seq = 0
  foreach ($compactItem in @($Items)) {
    if ($null -eq $compactItem) { continue }
    $seq++
    $compactCount = 1
    try { $compactCount = [int]$compactItem.count } catch { $compactCount = 1 }
    $parts += ('{0}.{1}/{2}x{3}' -f $seq, (Get-LifeSkillNameById -Id ([string]$compactItem.skill)),
      [string]$compactItem.target, $compactCount)
  }
  return ($parts -join ' ')
}

function Set-LifeListRowTexts {
  # 생활 리스트 1행의 표시 텍스트 갱신 - 표시 규칙의 단일 소스
  # (열: 체크빈칸 / # / 스킬 / 대상 / 횟수. Get-LifeCustomItemsFromList 가 역해석하므로
  #  표기를 바꾸면 그쪽도 함께 고쳐야 합니다)
  param($Row, $Item)
  $rowCount = 1
  try { $rowCount = [int]$Item.count } catch { $rowCount = 1 }
  if ($rowCount -lt 1) { $rowCount = 1 }
  $Row.SubItems[2].Text = Get-LifeSkillNameById -Id ([string]$Item.skill)
  $Row.SubItems[3].Text = [string]$Item.target
  $Row.SubItems[4].Text = ('{0}회' -f $rowCount)
}

function Add-LifeCustomListRow {
  # 생활 리스트뷰에 항목 1행 추가
  param([string]$Skill, [string]$Target, [int]$Count)
  $row = New-Object System.Windows.Forms.ListViewItem('')
  [void]$row.SubItems.Add([string]($lvLcrList.Items.Count + 1))
  for ($fillIndex = 2; $fillIndex -le 4; $fillIndex++) { [void]$row.SubItems.Add('') }
  Set-LifeListRowTexts -Row $row -Item ([pscustomobject]@{
      kind = 'life'; skill = $Skill; target = $Target; count = $Count
    })
  [void]$lvLcrList.Items.Add($row)
}

function Update-LifeCustomListNumbers {
  # 각 행의 # 열을 1부터 다시 매깁니다 (추가/삭제/이동 직후. crLoading 가드로 이벤트 재발화 억제)
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    for ($rowIndex = 0; $rowIndex -lt $lvLcrList.Items.Count; $rowIndex++) {
      $lvLcrList.Items[$rowIndex].SubItems[1].Text = [string]($rowIndex + 1)
    }
  } finally { $script:crLoading = $prevLoading }
}

function Move-LifeCustomListRow {
  # 선택한 1줄을 위(-1)/아래(+1)로 이동합니다
  param([int]$Delta)
  if ($lvLcrList.SelectedItems.Count -eq 0) { return }
  $row = $lvLcrList.SelectedItems[0]
  $fromIndex = $row.Index
  $toIndex = $fromIndex + $Delta
  if ($toIndex -lt 0 -or $toIndex -ge $lvLcrList.Items.Count) { return }
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  try {
    $lvLcrList.Items.RemoveAt($fromIndex)
    [void]$lvLcrList.Items.Insert($toIndex, $row)
    Update-LifeCustomListNumbers
    $row.Selected = $true
    $lvLcrList.EnsureVisible($toIndex)
  } finally { $script:crLoading = $prevLoading }
  if ($script:uiReady) { Save-LifeCustomRepeatToConfig }
}

function Get-LifeCustomItemsFromList {
  # 생활 리스트뷰 → 계약 형태 항목 배열 (skill 은 Id 로 되돌립니다).
  # PS 5.1 배열 풀림 주의: 열거용이므로 return $items 그대로 두고 호출부에서 @()로 감쌉니다.
  $items = @()
  $lcrSourceRows = @($lvLcrList.Items)
  if ($script:customViewShuffled) { $lcrSourceRows = @($lcrSourceRows | Sort-Object { $(if ($null -ne $_.Tag) { [int]$_.Tag } else { [int]$_.Index }) }) }
  foreach ($listRow in $lcrSourceRows) {
    $rowCount = 1
    try { $rowCount = [int](([string]$listRow.SubItems[4].Text) -replace '[^\d]', '') } catch { $rowCount = 1 }
    if ($rowCount -lt 1) { $rowCount = 1 }
    if ($rowCount -gt 99) { $rowCount = 99 }
    $items += [pscustomobject]@{
      kind   = 'life'
      skill  = (Get-LifeSkillIdByName -Name ([string]$listRow.SubItems[2].Text))
      target = [string]$listRow.SubItems[3].Text
      count  = $rowCount
    }
  }
  return $items
}

function Get-LifeCustomCycleTotal {
  # 리스트 1바퀴에 실제로 도는 사이클 수 (항목 count 합계) - 하단 줄 안내 라벨용
  param($Items)
  $total = 0
  foreach ($totalItem in @($Items)) {
    if ($null -eq $totalItem) { continue }
    $itemCount = 1
    try { $itemCount = [int]$totalItem.count } catch { $itemCount = 1 }
    if ($itemCount -lt 1) { $itemCount = 1 }
    if ($itemCount -gt 99) { $itemCount = 99 }
    $total += $itemCount
  }
  return $total
}

function Set-LifeCustomRepeatOnConfig {
  # lifeCustomRepeat 섹션을 현재 UI 상태로 갱신합니다 (Save-Config 는 호출부 몫).
  # progress 는 절대 건드리지 않고 그대로 옮겨 담습니다 (진행 기록 비파괴 원칙).
  param($Config)
  $prevProgress = $null
  if ($Config.PSObject.Properties['lifeCustomRepeat'] -and $Config.lifeCustomRepeat -and
      $Config.lifeCustomRepeat.PSObject.Properties['progress']) {
    $prevProgress = $Config.lifeCustomRepeat.progress
  }
  $node = [pscustomobject]@{
    '_설명'         = "'생활(채집) 커스텀 반복' 모드 설정입니다. items 리스트를 위에서부터 순서대로 실행하며, 한 항목의 count 사이클을 모두 끝낸 뒤 다음 항목으로 넘어갑니다. progress 는 이어가기용 진행 기록이므로 직접 수정하지 마세요."
    '_items'        = "각 항목: skill(채집 스킬 Id - daily/wood/mining/herb/wool/harvest/hoe/insect/fishing) / target(채집 대상 이름, 게임 표기 그대로) / count(반복 횟수 1~99)"
    items           = [array]@(Get-LifeCustomItemsFromList)
    randomOrder     = [bool]$chkLcrRandom.Checked
    listRepeat      = $(if ($rbLcrCount.Checked) { 'count' } else { 'infinite' })
    listRepeatCount = [int]$numLcrLaps.Value
    progress        = $prevProgress
  }
  if ($Config.PSObject.Properties['lifeCustomRepeat']) { $Config.lifeCustomRepeat = $node }
  else { $Config | Add-Member -NotePropertyName 'lifeCustomRepeat' -NotePropertyValue $node }
}

function Save-LifeCustomRepeatToConfig {
  # 생활 커스텀 즉시 저장 경로 (던전/어비스/심층 저장 경로 무접촉 - 실패 신호는 같은 부채널).
  # 던전의 '층 혼합 → 1바퀴 강제' 잠금은 적용하지 않습니다: 생활은 사이클마다 C키부터
  # 새로 시작해 스킬을 섞어도 기술적 제약이 없습니다 (시안 확정)
  $script:lastCustomSaveOk = $false
  $cfg = Read-Config
  if (-not $cfg) {
    Add-GuiLog '[경고] config.json 을 읽지 못해 생활 커스텀 반복 설정을 저장하지 못했습니다 - 화면 목록과 저장된 설정이 다를 수 있습니다. 목록을 한 번 더 변경하면 다시 저장을 시도합니다.'
    return
  }
  Set-LifeCustomRepeatOnConfig -Config $cfg
  try {
    Save-Config $cfg
    $script:lastCustomSaveOk = $true
  }
  catch {
    Add-GuiLog "[경고] 생활 커스텀 반복 설정 저장 실패: $($_.Exception.Message) - 화면 목록과 저장된 설정이 다를 수 있습니다. 목록을 한 번 더 변경하면 다시 저장을 시도합니다."
  }
  Update-LifeCustomTotalLabel
}

function Update-LifeCustomTotalLabel {
  # 하단 줄의 사이클 수 라벨 갱신 (리스트 편집·반복 설정 변경·복원 시 호출).
  # 횟수 모드에서는 **총합만** 씁니다 (2026-08-08 사용자 지적): 바퀴 수는 바로 왼쪽
  # 입력칸에 보이므로 '바퀴당 N · 총 M' 은 중복인데다, 라벨 폭 119px 를 넘겨(127px)
  # 두 줄로 깨졌습니다. 무한 모드는 총합이 없으므로 '바퀴당' 표기가 정보 그 자체라 유지합니다.
  # 단위는 '사이클'이 아니라 **'회'** - 오른쪽 [횟수] 열('3회')과 위쪽 [반복 횟수 N 회]
  # 입력이 이미 '회'를 쓰고 있어 한 화면에서 같은 것을 두 이름으로 부르지 않게 합니다
  # (2026-08-08 사용자 지적).
  $totalItems = @(Get-LifeCustomItemsFromList)
  $perLap = Get-LifeCustomCycleTotal -Items $totalItems
  if ($rbLcrCount.Checked) {
    $lblLcrCycleTotal.Text = ('총 {0:N0}회' -f ($perLap * [int]$numLcrLaps.Value))
  } else {
    $lblLcrCycleTotal.Text = ('바퀴당 {0:N0}회' -f $perLap)
  }
}

# ============================================================
#  생활(채집) 커스텀 반복 - 셀 편집 (2026-08-08)
#  아래 두 함수는 **순수 함수(진리표 대상)** 입니다. 컨트롤($lvLcrList/$numLcrCount 등)을
#  한 번이라도 참조하면 tests/source_test_helpers.ps1 의 AST 추출 단독 실행이 불가능해져
#  진리표 자체를 못 돌립니다. 참조 허용은 $script:lifeSkills / $script:lifeSupportedSkillIds
#  와 Get-LifeSkillNameById / Get-LifeSkillIdByName 뿐입니다.
# ============================================================
function Get-LifeSkillTargets {
  # 스킬 Id → 그 스킬의 대상 배열. 모르는 Id 면 빈 배열.
  # 열거용이라 return $targets + 호출부 @() 규약 (PS 5.1 배열 풀림)
  param([string]$SkillId)
  $targets = @()
  foreach ($skillDef in @($script:lifeSkills)) {
    if ([string]$skillDef.Id -eq $SkillId) { $targets = @($skillDef.Targets); break }
  }
  return $targets
}

function Get-LcrCellEditPlan {
  # 생활 리스트 셀 편집 계획: 편집 가능하면 @{ Options; Current }, 아니면 $null (순수 - 진리표 대상).
  # 어비스의 Scope 키(리스트 전체 일괄)는 쓰지 않습니다 - 생활은 스킬 혼합이 자유라
  # 전 열이 행 단위입니다 (Save-LifeCustomRepeatToConfig 주석의 계약).
  # 현재값이 옵션에 없으면 **목록 끝에** 덧붙입니다: 콤보가 DropDownList 라 현재값이 목록에
  # 없으면 선택이 비어 사용자가 지금 값을 못 봅니다. 끝에 붙이는 이유는 낚시 같은 미지원
  # 값이 목록 첫 줄에 와서 '고르라는 것'처럼 보이지 않게 하기 위함입니다.
  param([int]$ColumnIndex, $Item)
  switch ($ColumnIndex) {
    2 {
      # 스킬: **지원 8종만** 옵션에 넣습니다. [추가] 버튼과 시작 게이트가 막는 낚시를
      # 셀 편집이 우회하는 뒷문이 되지 않게 (미지원 스킬은 새로 들어올 수 없음).
      # 옵션은 Id 가 아니라 표시명이어야 합니다 - 리스트 셀에 들어가는 값이 표시명이고
      # Get-LifeCustomItemsFromList 가 그 문자열을 Id 로 역해석하기 때문입니다.
      $skillOptions = @()
      foreach ($supportedId in @($script:lifeSupportedSkillIds)) {
        $skillOptions += (Get-LifeSkillNameById -Id ([string]$supportedId))
      }
      $skillCurrent = Get-LifeSkillNameById -Id ([string]$Item.skill)
      if ((-not [string]::IsNullOrWhiteSpace($skillCurrent)) -and ($skillOptions -notcontains $skillCurrent)) {
        $skillOptions += $skillCurrent
      }
      return @{ Options = @($skillOptions); Current = [string]$skillCurrent }
    }
    3 {
      # 대상: 그 행의 스킬이 가진 목록만 (어비스 난이도 열이 항목의 mode 를 보고 옵션을
      # 바꾸는 것과 같은 '행 상태의 함수'). 모르는 스킬 Id 면 고를 대상 자체가 없어 편집 불가
      $targetOptions = @(Get-LifeSkillTargets -SkillId ([string]$Item.skill))
      if ($targetOptions.Count -eq 0) { return $null }
      $targetCurrent = [string]$Item.target
      if ((-not [string]::IsNullOrWhiteSpace($targetCurrent)) -and ($targetOptions -notcontains $targetCurrent)) {
        $targetOptions += $targetCurrent
      }
      return @{ Options = @($targetOptions); Current = $targetCurrent }
    }
    4 {
      # 횟수: 1~99 (config·펼침 함수와 같은 범위). 현재값도 같은 범위로 클램프해
      # 손편집된 0/300 같은 값에서도 선택이 비지 않게 합니다
      $countOptions = @()
      foreach ($countValue in 1..99) { $countOptions += ('{0}회' -f $countValue) }
      $countNow = 1
      try { $countNow = [int]$Item.count } catch { $countNow = 1 }
      if ($countNow -lt 1) { $countNow = 1 }
      if ($countNow -gt 99) { $countNow = 99 }
      return @{ Options = @($countOptions); Current = ('{0}회' -f $countNow) }
    }
  }
  return $null
}

function Set-LcrItemCellValue {
  # 선택값을 생활 항목에 적용하고 [추가]와 같은 조합 정규화를 수행합니다 (순수 - 진리표 대상).
  # 입력 $Item 은 변형하지 않고 새 객체를 돌려줍니다.
  param($Item, [int]$ColumnIndex, [string]$Value)
  $newSkill = [string]$Item.skill
  $newTarget = [string]$Item.target
  $newCount = 1
  try { $newCount = [int]$Item.count } catch { $newCount = 1 }
  switch ($ColumnIndex) {
    2 {
      # 모르는 표시명이면 이전 스킬을 유지합니다 - skill 이 빈 값으로 저장되면 워커가
      # 스킬 창에서 아무것도 찾지 못합니다 (심층 Set-DcrItemCellValue 의 stage 방어와 같은 결)
      $parsedSkillId = Get-LifeSkillIdByName -Name $Value
      if ($parsedSkillId) { $newSkill = $parsedSkillId }
    }
    3 { $newTarget = $Value }
    4 {
      # 숫자가 하나도 없으면(형식 오류) 이전 값을 유지하고, 숫자가 있으면 그 값을 쓴 뒤
      # 아래에서 1~99 로 클램프합니다 - '0회'와 '300회'가 같은 규칙을 따르게
      $parsedText = ($Value -replace '[^\d]', '')
      if ($parsedText) { try { $newCount = [int]$parsedText } catch { } }
    }
  }
  if ($newCount -lt 1) { $newCount = 1 }
  if ($newCount -gt 99) { $newCount = 99 }
  # 조합 무결성 재확정 (어느 열을 고쳤든 매번): 스킬과 대상은 종속 관계라 스킬을 바꾸면
  # 이전 대상이 새 스킬에 없을 수 있고, 그대로 두면 워커가 대상 행을 못 찾아 반드시 멈춥니다.
  # 판정은 '스킬이 바뀌었는가'가 아니라 **'지금 대상이 새 스킬에 있는가'** 입니다 - 같은 스킬을
  # 다시 골랐을 때 대상이 보존돼야 '변경 없음' 조기 반환이 성립합니다(조용한 재저장 방지).
  # 슬라이더도 같은 규칙을 씁니다(스킬 변경 시 대상은 첫 항목으로 폴백 - 설계 합의).
  $newTargets = @(Get-LifeSkillTargets -SkillId $newSkill)
  if ($newTargets.Count -gt 0 -and ($newTargets -notcontains $newTarget)) {
    $newTarget = [string]$newTargets[0]
  }
  return [pscustomobject]@{
    kind   = 'life'
    skill  = $newSkill
    target = $newTarget
    count  = $newCount
  }
}

function Get-AbyssListLock {
  # 어비스 커스텀 리스트의 '방식·매칭 고정값'을 첫 항목에서 뽑습니다 (2026-07-22 사용자 확정:
  # 리스트 전체가 같은 방식+매칭이어야 함 - 항목마다 다르면 파티 상태가 항목 간에 꼬임).
  # 반환: 리스트가 비었으면 $null, 아니면 단일 해시테이블 @{ Mode; Matching }
  #       (Mode = 'solo'/'party', Matching = 혼자하기면 '없음', 함께하기면 GUI 표기 문구).
  # 단일 객체 반환이라 PS 5.1 배열 풀림과 무관합니다 - 호출부는 $null 검사만 하면 됩니다.
  param($Items)
  $alList = @()
  foreach ($alItem in @($Items)) { if ($null -ne $alItem) { $alList += $alItem } }
  if ($alList.Count -lt 1) { return $null }
  $alFirst = $alList[0]
  $alMode = $(if ([string]$alFirst.mode -eq 'party' -or [string]$alFirst.mode -eq '함께하기') { 'party' } else { 'solo' })
  $alMatching = '없음'
  if ($alMode -eq 'party') {
    # config 를 직접 편집해 '파티찾기'(공백 없음)처럼 적혀 있어도 같은 값으로 보도록 공백을 지워 비교하고,
    # 라디오에 되돌려 맞출 수 있게 GUI 표기 문구로 정규화합니다.
    $alKey = ([string]$alFirst.matching) -replace '\s', ''
    switch ($alKey) {
      '파티찾기'     { $alMatching = '파티 찾기' }
      '파티(파티장)' { $alMatching = '파티(파티장)' }
      default        { $alMatching = '우연한 만남' }
    }
  }
  return @{ Mode = $alMode; Matching = $alMatching }
}

function Get-AbyssMatchingIssues {
  # 첫 항목과 방식·매칭이 다른 항목들을 찾아 돌려줍니다 (config 를 직접 편집해 섞인 리스트가
  # 들어온 경우의 시작 게이트용 - GUI 에서는 라디오 잠금으로 애초에 섞이지 않습니다).
  # 반환: 위반 배열 [{Index; Mode; Matching; Reason}] (없으면 빈 배열).
  # PS 5.1 배열 풀림 주의: 열거용이므로 return $issues 그대로 + 호출부 @() 감싸기 규약.
  param($Items)
  $issues = @()
  $amList = @()
  foreach ($amItem in @($Items)) { if ($null -ne $amItem) { $amList += $amItem } }
  if ($amList.Count -lt 2) { return $issues }
  $amLock = Get-AbyssListLock -Items $amList
  if ($null -eq $amLock) { return $issues }
  $amLockKey = ([string]$amLock.Matching) -replace '\s', ''
  for ($amIdx = 1; $amIdx -lt $amList.Count; $amIdx++) {
    $amItemCur = $amList[$amIdx]
    $amMode = $(if ([string]$amItemCur.mode -eq 'party' -or [string]$amItemCur.mode -eq '함께하기') { 'party' } else { 'solo' })
    $amMatching = $(if ($amMode -eq 'party') { [string]$amItemCur.matching } else { '없음' })
    $amKey = $amMatching -replace '\s', ''
    $amModeText = $(if ($amMode -eq 'party') { '함께하기' } else { '혼자하기' })
    $amLockModeText = $(if ($amLock.Mode -eq 'party') { '함께하기' } else { '혼자하기' })
    $amReason = $null
    if ($amMode -ne $amLock.Mode) {
      $amReason = ("리스트의 방식은 '{0}'인데 이 항목은 '{1}'입니다" -f $amLockModeText, $amModeText)
    } elseif ($amMode -eq 'party' -and $amKey -ne $amLockKey) {
      $amReason = ("리스트의 매칭은 '{0}'인데 이 항목은 '{1}'입니다" -f [string]$amLock.Matching, $amMatching)
    }
    if ($amReason) {
      $issues += [pscustomobject]@{
        Index    = ($amIdx + 1)
        Mode     = $amModeText
        Matching = $amMatching
        Reason   = $amReason
      }
    }
  }
  return $issues
}

function Update-AbyssInputLock {
  # 어비스 커스텀 입력 줄 잠금: 리스트에 항목이 하나라도 있으면 그 리스트의 방식·매칭으로
  # 라디오를 맞추고 비활성화합니다 (팝업 대신 애초에 못 고르게 하는 방식 - 사용자 확정).
  # 리스트가 비면 전부 다시 활성화합니다. 항목 추가/삭제/이동/설정 복원/카테고리 전환 후 호출.
  # 라디오 Checked 를 코드로 바꾸면 CheckedChanged → 패널 갱신 → 이 함수 재호출로 이어질 수
  # 있어 $script:acrLockUpdating 로 재진입을 막습니다.
  if ($script:acrLockUpdating) { return }
  $script:acrLockUpdating = $true
  try {
    $acrLock = Get-AbyssListLock -Items @(Get-AbyssCustomItemsFromList)
    $acrLockOn = ($null -ne $acrLock)
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try {
      if ($acrLockOn) {
        if ($acrLock.Mode -eq 'party') {
          if (-not $rbAcrParty.Checked) { $rbAcrParty.Checked = $true }
          if ($acrLock.Matching -eq '파티 찾기') {
            if (-not $rbAcrFindParty.Checked) { $rbAcrFindParty.Checked = $true }
          } elseif ($acrLock.Matching -eq '파티(파티장)') {
            if (-not $rbAcrPartyLead.Checked) { $rbAcrPartyLead.Checked = $true }
          } else {
            if (-not $rbAcrChance.Checked) { $rbAcrChance.Checked = $true }
          }
        } else {
          if (-not $rbAcrSolo.Checked) { $rbAcrSolo.Checked = $true }
        }
      }
      $rbAcrSolo.Enabled = -not $acrLockOn
      $rbAcrParty.Enabled = -not $acrLockOn
      $rbAcrChance.Enabled = -not $acrLockOn
      $rbAcrFindParty.Enabled = -not $acrLockOn
      $rbAcrPartyLead.Enabled = -not $acrLockOn
    } finally { $script:crLoading = $prevLoading }
    # 잠긴 이유 안내: 항상 보이는 라벨이 주 수단입니다.
    # (툴팁은 비활성 컨트롤에 안 뜨는 WinForms 특성 때문에 라디오+패널에 겹쳐 걸었더니
    #  마우스가 둘 사이를 오갈 때 깜박였음 - 2026-07-22 실기 확인 → 패널에만 남깁니다)
    # 툴팁은 아래 MouseMove 핸들러가 잠긴 라디오 위에서만 직접 띄웁니다
    # (비활성 컨트롤은 마우스 이벤트를 받지 못해 SetToolTip 이 동작하지 않는 WinForms 특성)
    $script:acrLockOn = $acrLockOn
    if (-not $acrLockOn -and $script:acrTipShownFor) {
      $script:acrTipShownFor = $null
      $toolTip.Hide($pnlAcrInput)
      $toolTip.Hide($pnlAcrMatching)
    }
  } finally { $script:acrLockUpdating = $false }
}

function Update-CustomRandomToggleStyle {
  # 랜덤 토글 눌림 배경 (설정/로그 탭 토글과 동일한 크림 - 활성 상태를 색으로 표시)
  param($Toggle)
  # 활성 = 캐러멜 (설정/로그 탭 토글과 동일 - 2026-08-04 C안 확정)
  $Toggle.BackColor = $(if ($Toggle.Checked) { [System.Drawing.Color]::FromArgb(244, 213, 141) } else { $script:themeControl })
  $Toggle.ForeColor = $(if ($Toggle.Checked) { [System.Drawing.Color]::FromArgb(91, 62, 6) } else { $script:themeText })
}

function Save-CustomRandomOrder {
  # 랜덤 토글 즉시 저장 + 진행/완료 마커 무효화. 켜고 끄는 것 자체가 실행 순서의 의미를
  # 바꾸므로 진행 기록은 처음부터 - 같은 저장에서 원자적으로 처리합니다 (리뷰 조건)
  param([string]$SectionName, [bool]$Enabled)
  $cfg = Read-Config
  if (-not $cfg -or -not $cfg.PSObject.Properties[$SectionName] -or -not $cfg.$SectionName) {
    Add-GuiLog '[경고] config 를 읽지 못해 랜덤 진행 설정을 저장하지 못했습니다.'
    return
  }
  $node = $cfg.$SectionName
  if ($node.PSObject.Properties['randomOrder']) { $node.randomOrder = $Enabled }
  else { $node | Add-Member -NotePropertyName 'randomOrder' -NotePropertyValue $Enabled }
  if ($node.PSObject.Properties['progress']) { $node.progress = $null }
  else { $node | Add-Member -NotePropertyName 'progress' -NotePropertyValue $null }
  try {
    Save-Config $cfg
  } catch {
    Add-GuiLog "[경고] 랜덤 진행 설정 저장 실패: $($_.Exception.Message) - 토글을 한 번 더 눌러 다시 시도해 주세요."
    return
  }
  # 전역($customMarkerFile = 마지막으로 시작한 섹션)이 아니라 **이 토글이 속한 섹션**의
  # 마커만 지웁니다 (2026-08-09 감사 - 다른 콘텐츠의 유효 마커 파괴 방지).
  # 삭제 실패 시 '{}' 무효화까지 하는 공용 계약을 씁니다 (Clear-CustomMarkerFile).
  if (-not (Clear-CustomMarkerFile -Path (Get-CustomMarkerFileForSection -SectionName $SectionName))) {
    Add-GuiLog '[경고] 이전 완료 기록 파일을 지우지 못했습니다 - 다음 시작에서 이미 끝낸 판을 복구하려 할 수 있습니다.'
  }
  Add-GuiLog $(if ($Enabled) { '[안내] 랜덤 진행 켬 - 매 바퀴 시작 때 리스트 순서를 무작위로 섞습니다 (진행 기록은 처음부터).' }
    else { '[안내] 랜덤 진행 끔 - 등록 순서로 진행합니다 (진행 기록은 처음부터).' })
}

function Update-CustomRandomMixGate {
  # 층 혼합 리스트의 랜덤 게이트: 혼합이면 토글 비활성 + 켜져 있으면 자동 해제 (리뷰 정책:
  # 편집 차단 대신 자동 해제 + 안내. 혼합 해소 시 재활성만 - 자동으로 다시 켜지는 않음)
  param($Toggle, $Items, [string]$SectionName)
  $mixGateNeeded = $false
  if (@($Items).Count -ge 2) {
    $mixGateIssues = @(@(Get-CustomTransitionIssues -Items $Items -ListRepeat 'infinite' -ListRepeatCount 1) |
        Where-Object { [bool]$_.Wrap })
    $mixGateNeeded = ($mixGateIssues.Count -gt 0)
  }
  if ($mixGateNeeded -and $Toggle.Checked) {
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    try { $Toggle.Checked = $false } finally { $script:crLoading = $prevLoading }
    Update-CustomRandomToggleStyle -Toggle $Toggle
    if ($script:uiReady) { Save-CustomRandomOrder -SectionName $SectionName -Enabled $false }
    Add-GuiLog '[안내] 층이 섞인 혼합 리스트라 랜덤 진행을 해제했습니다 (1층·2층 혼합은 랜덤 사용 불가).'
  }
  $Toggle.Enabled = -not $mixGateNeeded
}

function Get-CustomActiveListView {
  param([string]$SectionName = $script:customConfigSection)
  if ($SectionName -eq 'abyssCustomRepeat') { return $lvAcrList }
  if ($SectionName -eq 'deepCustomRepeat') { return $lvDcrList }
  if ($SectionName -eq 'lifeCustomRepeat') { return $lvLcrList }
  return $lvCrList
}

function Set-CustomListRandomView {
  # 실행 중 표시 (확정 시안): 이번 바퀴 순열 순서로 행을 재배열하고 # 열을 '진행순서 (등록번호)'
  # 로, 현재 항목 행을 크림색으로 표시합니다. 행 객체를 재사용(Tag=등록 인덱스)해 체크/셀
  # 텍스트 손실이 없고, 저장 함수는 Tag 순 정렬로 등록 순서를 보존합니다 (실행 중 [설정 저장]
  # 이 화면 순서를 그대로 저장하는 사고 방어 - 리뷰 조건)
  param($Context)
  if (-not $Context) { return }
  $view = Get-CustomActiveListView -SectionName ([string]$Context.SectionName)
  if (-not $Context.RandomOrder) {
    # 등록 순서(비랜덤) 바퀴에서도 현재 항목 행 색을 표시합니다 (2026-08-15 사용자 요청 -
    # 기존에는 랜덤 바퀴 전용). 재배열·'진행순서 (등록번호)' 표기·열 폭 변경은 하지 않고
    # **행 색만** 바꿉니다. 현재 행 인덱스는 전투 = Index(비랜덤은 실행 순서 = 등록 순서),
    # 생활 = RegisteredIndex(비랜덤이면 sourceIndex = 등록 순번) - getter 계약 그대로.
    # 정지 시 색 복원은 랜덤과 같은 공용 경로(Restore-CustomListRegisteredView)를 쓰도록
    # Tag(등록 인덱스 identity)와 플래그를 동일하게 세팅합니다 - 복원의 Tag 순 정렬은
    # 비랜덤에서 순서 불변이고, 열 폭 30/32 재설정도 원값이라 무해 (Codex 합의).
    $plainTotal = [int]$Context.RegisteredTotal
    $plainIndex = $(if ([string]$Context.SectionName -eq 'lifeCustomRepeat') { [int]$Context.RegisteredIndex } else { [int]$Context.Index })
    if ($view.Items.Count -ne $plainTotal) { return }              # 화면-config 불일치면 표시만 생략 (안전)
    if ($plainIndex -lt 0 -or $plainIndex -ge $view.Items.Count) { return }   # 인덱스 범위 확인 후에만 Tag/플래그 (Codex 조건)
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    $view.BeginUpdate()
    try {
      if (-not $script:customViewShuffled) {
        foreach ($viewRow in $view.Items) { $viewRow.Tag = [int]$viewRow.Index }   # 등록 인덱스 고정 (복원 경로 공용)
      }
      foreach ($viewRow in $view.Items) { $viewRow.BackColor = [System.Drawing.Color]::White }
      $view.Items[$plainIndex].BackColor = [System.Drawing.Color]::FromArgb(245, 231, 201)
      $view.Items[$plainIndex].EnsureVisible()
      $script:customViewShuffled = $true   # '실행 중 표시/Tag 관리 상태' 플래그 (재배열 여부가 아님)
    } finally {
      $view.EndUpdate()
      $script:crLoading = $prevLoading
    }
    return
  }
  if (-not $Context.Order) { return }   # 랜덤일 때만 순열 유효성 요구
  # 리스트 행 수 기준은 '등록 항목 수'입니다. 생활만 Total 이 펼친 실행 칸 수라 다르므로
  # RegisteredTotal/RegisteredIndex 를 씁니다 (리스트에는 항목이 한 줄씩만 있음)
  $viewTotal = [int]$Context.Total
  $viewIndex = [int]$Context.Index
  if ([string]$Context.SectionName -eq 'lifeCustomRepeat') {
    $viewTotal = [int]$Context.RegisteredTotal
    $viewIndex = [int]$Context.RegisteredIndex
    # 등록 인덱스는 '등록 순서'의 번호라 화면(순열 순서) 행 위치로 한 번 되짚어야 합니다
    $viewIndex = @($Context.Order).IndexOf([int]$Context.RegisteredIndex)
    if ($viewIndex -lt 0) { $viewIndex = 0 }
  }
  if ($view.Items.Count -ne $viewTotal) { return }   # 화면-config 불일치면 표시만 생략 (안전)
  $prevLoading = $script:crLoading
  $script:crLoading = $true
  $view.BeginUpdate()
  try {
    if (-not $script:customViewShuffled) {
      foreach ($viewRow in $view.Items) { $viewRow.Tag = [int]$viewRow.Index }   # 등록 인덱스 고정 (실행 중 편집 잠김)
      $view.Columns[1].Width = 52   # '12 (12)' 잘림 방지 - 복원 시 원래 폭
    }
    $orderedRows = @()
    foreach ($regIdx in @($Context.Order)) {
      $foundRow = $null
      foreach ($viewRow in $view.Items) { if ($null -ne $viewRow.Tag -and [int]$viewRow.Tag -eq [int]$regIdx) { $foundRow = $viewRow; break } }
      if (-not $foundRow) { return }
      $orderedRows += $foundRow
    }
    $view.Items.Clear()
    for ($vi = 0; $vi -lt $orderedRows.Count; $vi++) {
      [void]$view.Items.Add($orderedRows[$vi])
      $orderedRows[$vi].SubItems[1].Text = ('{0} ({1})' -f ($vi + 1), ([int]$orderedRows[$vi].Tag + 1))
      $orderedRows[$vi].BackColor = [System.Drawing.Color]::White
    }
    if ($viewIndex -ge 0 -and $viewIndex -lt $view.Items.Count) {
      $view.Items[$viewIndex].BackColor = [System.Drawing.Color]::FromArgb(245, 231, 201)
      $view.Items[$viewIndex].EnsureVisible()
    }
    $script:customViewShuffled = $true
  } finally {
    $view.EndUpdate()
    $script:crLoading = $prevLoading
  }
}

function Restore-CustomListRegisteredView {
  # 등록 순서 표기 복원 - 모든 정지 경로 공용 (Set-UiRunning(false) 서두에서 호출)
  if (-not $script:customViewShuffled) { return }
  foreach ($view in @($lvCrList, $lvAcrList, $lvDcrList, $lvLcrList)) {
    if ($view.Items.Count -eq 0) { continue }
    $tagsOk = $true
    foreach ($viewRow in $view.Items) { if ($null -eq $viewRow.Tag) { $tagsOk = $false; break } }
    if (-not $tagsOk) { continue }
    $prevLoading = $script:crLoading
    $script:crLoading = $true
    $view.BeginUpdate()
    try {
      $restoreRows = @($view.Items | Sort-Object { [int]$_.Tag })
      $view.Items.Clear()
      for ($vi = 0; $vi -lt $restoreRows.Count; $vi++) {
        [void]$view.Items.Add($restoreRows[$vi])
        $restoreRows[$vi].SubItems[1].Text = [string]($vi + 1)
        $restoreRows[$vi].BackColor = [System.Drawing.Color]::White
        $restoreRows[$vi].Tag = $null
      }
      $view.Columns[1].Width = $(if ($view -eq $lvAcrList) { 30 } else { 32 })
    } finally {
      $view.EndUpdate()
      $script:crLoading = $prevLoading
    }
  }
  $script:customViewShuffled = $false
}

function Set-CustomRepeatOnConfig {
  # customRepeat 섹션을 현재 UI 상태로 갱신합니다 (Save-Config 는 호출부 몫).
  # progress 는 절대 건드리지 않고 그대로 옮겨 담습니다 (진행 기록 비파괴 원칙).
  # enabled 는 라디오가 아니라 $script:customEnabledWish 를 기록합니다 - 던전 외 카테고리에서
  # 라디오가 표시상 무한 반복으로 폴백해 있어도 선택 의도가 보존되게 (요청사항 확정 스펙).
  param($Config)
  $prevProgress = $null
  if ($Config.PSObject.Properties['customRepeat'] -and $Config.customRepeat -and
      $Config.customRepeat.PSObject.Properties['progress']) {
    $prevProgress = $Config.customRepeat.progress
  }
  $node = [pscustomobject]@{
    '_설명'         = "'던전 커스텀 반복' 설정입니다. items 리스트를 위에서부터 순서대로 1판씩 실행합니다. enabled 는 던전/어비스 공용 커스텀 반복 선택 상태이며 progress 는 이어가기용 진행 기록입니다."
    enabled         = [bool]$script:customEnabledWish
    '_items'        = '각 항목: difficulty/stage/coin/doubleLoot + exhaustContinue(동전 소진 시 true=미사용으로 진행, false=멈춤) / noDoubleSweep(더블 루팅 불가 시 true=소탕만 진행, false=멈춤). 소진/더블 대응은 항목별 속성입니다'
    items           = [array]@(Get-CustomItemsFromList)
    randomOrder     = [bool]$chkCrRandom.Checked
    listRepeat      = $(if ($rbCrCount.Checked) { 'count' } else { 'infinite' })
    listRepeatCount = [int]$numCrLaps.Value
    progress        = $prevProgress
  }
  if ($Config.PSObject.Properties['customRepeat']) { $Config.customRepeat = $node }
  else { $Config | Add-Member -NotePropertyName 'customRepeat' -NotePropertyValue $node }
}

function Set-AbyssCustomRepeatOnConfig {
  param($Config)
  $prevProgress = $null
  if ($Config.PSObject.Properties['abyssCustomRepeat'] -and $Config.abyssCustomRepeat -and
      $Config.abyssCustomRepeat.PSObject.Properties['progress']) {
    $prevProgress = $Config.abyssCustomRepeat.progress
  }
  $node = [pscustomobject]@{
    '_설명'         = "'어비스 커스텀 반복' 모드 설정입니다. items 리스트를 위에서부터 순서대로 1판씩 실행합니다. progress 는 이어가기용 진행 기록이므로 직접 수정하지 마세요."
    '_items'        = "각 항목: kind=abyss / mode(solo 또는 party) / difficulty / dungeon / matching. 혼자하기 항목의 matching 은 '없음'입니다."
    items           = [array]@(Get-AbyssCustomItemsFromList)
    randomOrder     = [bool]$chkAcrRandom.Checked
    listRepeat      = $(if ($rbAcrCount.Checked) { 'count' } else { 'infinite' })
    listRepeatCount = [int]$numAcrLaps.Value
    progress        = $prevProgress
  }
  if ($Config.PSObject.Properties['abyssCustomRepeat']) { $Config.abyssCustomRepeat = $node }
  else { $Config | Add-Member -NotePropertyName 'abyssCustomRepeat' -NotePropertyValue $node }
}

function Save-CustomRepeatToConfig {
  # 던전/어비스 커스텀 설정 공용 즉시 저장 경로.
  # 성공 여부를 $script:lastCustomSaveOk 로 남깁니다 (반환값으로 바꾸면 기존 호출부 전체가
  # 파이프라인 오염 방어를 해야 해서 부채널 사용 - 셀 편집이 실패 시 원복에 사용).
  # 혼합 리스트면 저장 전에 반복을 '횟수 1바퀴'로 강제해 그 값이 저장되게 합니다
  # (어비스 저장 경유 호출에서도 던전 리스트 기준으로만 동작 - 무해)
  Update-CustomRepeatMixLock -Items @(Get-CustomItemsFromList) `
    -RbInfinite $rbCrInfinite -RbCount $rbCrCount -NumLaps $numCrLaps -StateKey 'cr'
  Update-CustomRandomMixGate -Toggle $chkCrRandom -Items @(Get-CustomItemsFromList) -SectionName 'customRepeat'
  $script:lastCustomSaveOk = $false
  $cfg = Read-Config
  if (-not $cfg) {
    Add-GuiLog '[경고] config.json 을 읽지 못해 커스텀 반복 설정을 저장하지 못했습니다 - 화면 목록과 저장된 설정이 다를 수 있습니다. 목록을 한 번 더 변경하면 다시 저장을 시도합니다.'
    return
  }
  Set-CustomRepeatOnConfig -Config $cfg
  Set-AbyssCustomRepeatOnConfig -Config $cfg
  try {
    Save-Config $cfg
    $script:lastCustomSaveOk = $true
  }
  catch {
    # 셀 편집 외 경로(추가/삭제/이동 등)는 롤백이 없어 화면과 저장 파일이 어긋난 채 남을 수
    # 있습니다 - 어긋남과 복구 방법을 문구로 명시 (2026-08-01 전수 점검. 다음 저장 성공 시 해소)
    Add-GuiLog "[경고] 커스텀 반복 설정 저장 실패: $($_.Exception.Message) - 화면 목록과 저장된 설정이 다를 수 있습니다. 목록을 한 번 더 변경하면 다시 저장을 시도합니다."
  }
  Update-CustomCoinTotalLabel
}

function Update-CustomCoinTotalLabel {
  # 하단 줄의 은동전 예산 라벨 갱신 (리스트 편집·리스트 반복 설정 변경·복원 시 호출).
  # 무한이면 바퀴당 합계, 횟수 N바퀴면 총합(합계 x N)을 표시합니다.
  $totalItems = @(Get-CustomItemsFromList)
  $perLap = Get-CustomCoinTotalPerLap -Items $totalItems
  if ($rbCrCount.Checked) {
    # 횟수 모드: 바퀴당과 총합(x N)을 같이 표시
    $lblCrCoinTotal.Text = ('바퀴당 {0:N0} · 총 {1:N0}개' -f $perLap, ($perLap * [int]$numCrLaps.Value))
  } else {
    $lblCrCoinTotal.Text = ('바퀴당 은동전 {0:N0}개' -f $perLap)
  }
}

function Test-CustomLastRun {
  param([string]$ListRepeat, [int]$ListRepeatCount, [int]$Lap, [int]$Index, [int]$Total)

  # '마지막 판' 판정 (2026-07-25 마지막 판 나가기 기능): 횟수(count) 모드에서 마지막 바퀴의
  # 마지막 항목일 때만 true. 무한 반복은 마지막이 없습니다. 워커가 이 신호를 받으면 던전
  # 결과 화면에서 '다시 하기' 대신 '나가기'로 필드에 나가며 자동화를 마칩니다.
  if ($ListRepeat -ne 'count') { return $false }
  if ($ListRepeatCount -lt 1 -or $Total -lt 1) { return $false }
  return (($Lap -ge $ListRepeatCount) -and ($Index -ge ($Total - 1)))
}

function Get-CustomCurrentContext {
  # 이번 회차에 실행할 항목/위치 정보를 config 에서 읽습니다 (단일 해시테이블 반환 - 배열 풀림 무관).
  # 반환: @{ Items; Total; Lap; Index; Item; ListRepeat; ListRepeatCount; Position } 또는 $null
  param([string]$SectionName = $script:customConfigSection)
  $cfg = Read-Config
  if ([string]::IsNullOrWhiteSpace($SectionName)) { $SectionName = 'customRepeat' }
  if (-not $cfg -or -not $cfg.PSObject.Properties[$SectionName] -or -not $cfg.$SectionName) { return $null }
  $node = $cfg.$SectionName
  $items = @()
  if ($node.PSObject.Properties['items']) { $items = @($node.items) }
  if ($items.Count -eq 0) { return $null }
  $lap = 1; $index = 0
  if ($node.PSObject.Properties['progress'] -and $node.progress) {
    try { $lap = [int]$node.progress.lap } catch { $lap = 1 }
    try { $index = [int]$node.progress.index } catch { $index = 0 }
  }
  if ($lap -lt 1) { $lap = 1 }
  # 상한 검사는 아래 '실행 단위' 개수가 확정된 뒤에 합니다 (생활은 count 만큼 펼쳐서
  # 실행 칸이 등록 항목 수보다 많음 - 여기서 등록 수로 자르면 정상 진행이 1번으로 되감김)
  if ($index -lt 0) { $index = 0 }
  $listRepeat = 'infinite'
  if ($node.PSObject.Properties['listRepeat']) { try { $listRepeat = [string]$node.listRepeat } catch { } }
  $listRepeatCount = 1
  if ($node.PSObject.Properties['listRepeatCount']) { try { $listRepeatCount = [int]$node.listRepeatCount } catch { } }
  # 랜덤 진행 (2026-08-04): Items 는 항상 '등록 순서'로 유지(지문/마커 계약 불변)하고,
  # 실행 순서는 ExecutionItems/Order 로 분리합니다. 이 getter 는 읽기·매핑만 담당 -
  # 순열 생성은 시작 게이트와 Step 의 바퀴 전환에서만 (리뷰 계약).
  $randomOrder = Get-CustomRandomOrderEnabled -Node $node
  $shuffleOrder = $null
  $shuffleValid = $true
  if ($randomOrder) {
    $savedOrder = $null
    if ($node.PSObject.Properties['progress'] -and $node.progress -and
        $node.progress.PSObject.Properties['shuffleOrder']) { $savedOrder = $node.progress.shuffleOrder }
    if (Test-CustomShuffleOrder -Order $savedOrder -ItemCount $items.Count) {
      $shuffleOrder = @([int[]]@($savedOrder))
    } else {
      $shuffleValid = $false
    }
  }
  $executionItems = $items
  if ($randomOrder -and $shuffleOrder) { $executionItems = @(Get-CustomExecutionItems -Items $items -Order $shuffleOrder) }
  # 생활만 '항목 1개 = count 사이클'이라 실행 단위로 펼칩니다 (셔플 뒤에 펼쳐야 한 항목의
  # count 사이클이 연속으로 붙습니다). 등록 목록/지문/순열은 그대로 - 펼침은 실행용입니다
  $isLifeSection = ($SectionName -eq 'lifeCustomRepeat')
  if ($isLifeSection) { $executionItems = @(Expand-LifeCustomItems -Items $executionItems) }
  # 진행 index 는 '실행 단위' 위에서 셉니다 - 생활은 펼친 개수가 총 칸 수입니다
  $executionTotal = @($executionItems).Count
  if ($executionTotal -lt 1) { return $null }
  if ($index -ge $executionTotal) { $index = 0 }
  $currentItem = @($executionItems)[$index]
  if ($isLifeSection) {
    $positionText = Get-LifeCustomPositionText -Lap $lap -Index $index -Total $executionTotal -Item $currentItem
  } else {
    $positionText = Get-CustomPositionText -Lap $lap -Index $index -Total $executionTotal
  }
  if ($randomOrder) { $positionText += ' (랜덤)' }
  return @{
    Items           = $items
    ExecutionItems  = $executionItems
    Total           = $executionTotal
    RegisteredTotal = $items.Count
    Lap             = $lap
    Index           = $index
    Item            = $currentItem
    # 생활은 index 가 '펼친 칸' 번호라 등록 순번을 항목이 실어 온 sourceIndex 로 되짚습니다
    # (sourceIndex 는 셔플된 실행 순서에서의 위치 - 순열을 한 번 더 통과시켜야 등록 번호)
    RegisteredIndex = $(if ($isLifeSection) {
        $lifeSourceIndex = 0
        try { $lifeSourceIndex = [int]$currentItem.sourceIndex } catch { $lifeSourceIndex = 0 }
        if ($randomOrder -and $shuffleOrder -and $lifeSourceIndex -lt @($shuffleOrder).Count) { [int]$shuffleOrder[$lifeSourceIndex] } else { $lifeSourceIndex }
      } elseif ($randomOrder -and $shuffleOrder) { [int]$shuffleOrder[$index] } else { $index })
    RandomOrder     = $randomOrder
    Order           = $shuffleOrder
    ShuffleValid    = $shuffleValid
    ListRepeat      = $listRepeat
    ListRepeatCount = $listRepeatCount
    SectionName     = $SectionName
    Position        = $positionText
  }
}

function Step-CustomProgress {
  # 판 완료 계상: progress 를 한 칸 전진시키고 '즉시' 디스크에 저장합니다.
  # 전진 후 progress 를 반환합니다 (호출부가 Test-CustomLapComplete 로 완주를 판정).
  # 저장 실패(파일 잠금 등)는 $null을 반환해 호출부가 다음 회차를 시작하지 않게 합니다.
  param([string]$SectionName = $script:customConfigSection)
  $cfg = Read-Config
  if ([string]::IsNullOrWhiteSpace($SectionName)) { $SectionName = 'customRepeat' }
  if (-not $cfg -or -not $cfg.PSObject.Properties[$SectionName] -or -not $cfg.$SectionName) {
    Add-GuiLog '[경고] config 를 읽지 못해 커스텀 진행 기록을 전진시키지 못했습니다.'
    return $null
  }
  $node = $cfg.$SectionName
  $items = @()
  if ($node.PSObject.Properties['items']) { $items = @($node.items) }
  $prevProgress = $null
  if ($node.PSObject.Properties['progress'] -and $node.progress) { $prevProgress = $node.progress }
  # 전진 칸 수 = '실행 단위' 개수. 생활만 항목마다 count 사이클이라 펼친 개수를 씁니다
  # (등록 수로 전진하면 count 2 이상인 항목이 1회만 돌고 다음 항목으로 넘어갑니다).
  # 셔플 순열은 여전히 등록 항목 단위 - 펼침은 순열과 무관하게 개수만 바꿉니다
  $stepUnitCount = $items.Count
  if ($SectionName -eq 'lifeCustomRepeat') { $stepUnitCount = @(Expand-LifeCustomItems -Items $items).Count }
  $next = Get-CustomNextProgress -Progress $prevProgress -ItemCount $stepUnitCount
  $newProgress = [pscustomobject]@{
    lap         = [int]$next.lap
    index       = [int]$next.index
    fingerprint = (Get-CustomFingerprint -Items $items)
  }
  # 랜덤 진행: 바퀴 전환(index=0 복귀)에서만 새 순열, 같은 바퀴 전진은 기존 순열 그대로 복사
  # (재시도/복구 경로는 Step 을 부르지 않으므로 재셔플 없음 - 리뷰 계약)
  if (Get-CustomRandomOrderEnabled -Node $node) {
    if ([int]$next.index -eq 0) {
      $stepShuffle = @(New-CustomShuffleOrder -ItemCount $items.Count)
    } else {
      $stepShuffle = $null
      if ($prevProgress -and $prevProgress.PSObject.Properties['shuffleOrder']) { $stepShuffle = $prevProgress.shuffleOrder }
      if (-not (Test-CustomShuffleOrder -Order $stepShuffle -ItemCount $items.Count)) {
        Add-GuiLog '[오류] 랜덤 진행 순서 기록이 손상돼 진행을 전진시키지 못했습니다 - [진행 초기화] 후 다시 시작해 주세요.'
        return $null
      }
      $stepShuffle = @([int[]]@($stepShuffle))
    }
    $newProgress | Add-Member -NotePropertyName 'shuffleOrder' -NotePropertyValue ([array]$stepShuffle)
  }
  if ($node.PSObject.Properties['progress']) { $node.progress = $newProgress }
  else { $node | Add-Member -NotePropertyName 'progress' -NotePropertyValue $newProgress }
  try {
    Save-Config $cfg
  } catch {
    Add-GuiLog "[오류] 커스텀 진행 기록 저장 실패: $($_.Exception.Message) - 중복 실행 방지를 위해 다음 판을 시작하지 않습니다."
    return $null
  }
  return $newProgress
}

function Reset-CustomProgress {
  # 진행 기록 삭제(progress = null). 진행 초기화 버튼 / 시작 시 지문 불일치 / 완주 / lap 초과 4곳 공용
  # 반환: 디스크 저장까지 성공했으면 $true, 읽기/저장 실패면 $false.
  param([string]$LogMessage = '', [string]$SectionName = $script:customConfigSection)
  $cfg = Read-Config
  if ([string]::IsNullOrWhiteSpace($SectionName)) { $SectionName = 'customRepeat' }
  if (-not $cfg -or -not $cfg.PSObject.Properties[$SectionName] -or -not $cfg.$SectionName) {
    Add-GuiLog '[오류] config 를 읽지 못해 커스텀 진행 기록을 초기화하지 못했습니다.'
    return $false
  }
  $node = $cfg.$SectionName
  if ($node.PSObject.Properties['progress']) { $node.progress = $null }
  else { $node | Add-Member -NotePropertyName 'progress' -NotePropertyValue $null }
  try {
    Save-Config $cfg
  } catch {
    Add-GuiLog "[오류] 커스텀 진행 초기화 저장 실패: $($_.Exception.Message)"
    return $false
  }
  # 완료 마커도 함께 무효화 (랜덤 진행: 초기화 후 우연히 같은 순열이 재현돼 낡은 마커가
  # 일치하는 사고 방지 - 리뷰 조건. 순차 모드에서도 초기화 = 새 출발 의도라 무해)
  # progress 는 위에서 $SectionName 으로 정확히 분기하는데 마커만 전역을 쓰고 있었습니다
  # (2026-08-09 감사 - 파라미터 컨텍스트와 전역 상태가 한 함수 안에 공존하면 반드시 갈라짐)
  if (-not (Clear-CustomMarkerFile -Path (Get-CustomMarkerFileForSection -SectionName $SectionName))) {
    Add-GuiLog '[경고] 이전 완료 기록 파일을 지우지 못했습니다 - 다음 시작에서 이미 끝낸 판을 복구하려 할 수 있습니다.'
  }
  if ($LogMessage) { Add-GuiLog $LogMessage }
  return $true
}

function Confirm-CustomShuffleReady {
  # 랜덤 진행 시작 게이트: 이번 바퀴 순열을 '시작 전에' 확보하고 디스크에 저장합니다
  # (저장 실패 = 시작 금지). 층 혼합 리스트 + randomOrder(config 직접 편집)는 랜덤을
  # 해제·정규화하고 순차로 진행합니다 (던전/심층 한정 - 어비스는 층 제약 없음).
  # 반환: 시작 가능 여부. 순차 모드는 항상 $true.
  param([string]$SectionName = $script:customConfigSection)
  $cfg = Read-Config
  if ([string]::IsNullOrWhiteSpace($SectionName)) { $SectionName = 'customRepeat' }
  if (-not $cfg -or -not $cfg.PSObject.Properties[$SectionName] -or -not $cfg.$SectionName) { return $false }
  $node = $cfg.$SectionName
  if (-not (Get-CustomRandomOrderEnabled -Node $node)) { return $true }
  $gateItems = @()
  if ($node.PSObject.Properties['items']) { $gateItems = @($node.items) }
  if ($gateItems.Count -lt 1) { return $false }
  # 층 전환 규칙은 던전/심층에만 있습니다. 어비스는 층 제약이 없고, 생활은 항목에 stage 가
  # 아예 없어 이 검사를 돌리면 빈 값끼리 비교한 헛 위반이 나옵니다 (2026-08-08 생활 커스텀 신설)
  if ($SectionName -ne 'abyssCustomRepeat' -and $SectionName -ne 'lifeCustomRepeat') {
    $gateWrapIssues = @(@(Get-CustomTransitionIssues -Items $gateItems -ListRepeat 'infinite' -ListRepeatCount 1) |
        Where-Object { [bool]$_.Wrap })
    if ($gateWrapIssues.Count -gt 0) {
      $node.randomOrder = $false
      try { Save-Config $cfg } catch {
        Add-GuiLog "[오류] 랜덤 진행 해제 저장 실패: $($_.Exception.Message) - 시작하지 않습니다."
        return $false
      }
      Add-GuiLog '[안내] 층이 섞인 혼합 리스트는 랜덤 진행을 쓸 수 없어 해제했습니다 - 등록 순서로 진행합니다.'
      return $true
    }
  }
  $gateProgress = $null
  if ($node.PSObject.Properties['progress'] -and $node.progress) { $gateProgress = $node.progress }
  $gateOrder = $null
  if ($gateProgress -and $gateProgress.PSObject.Properties['shuffleOrder']) { $gateOrder = $gateProgress.shuffleOrder }
  if ($gateProgress -and (Test-CustomShuffleOrder -Order $gateOrder -ItemCount $gateItems.Count)) { return $true }
  $gateLap = 1
  $gateIndex = 0
  if ($gateProgress) {
    try { $gateLap = [int]$gateProgress.lap } catch { $gateLap = 1 }
    try { $gateIndex = [int]$gateProgress.index } catch { $gateIndex = 0 }
  }
  if ($gateLap -lt 1) { $gateLap = 1 }
  if ($gateProgress -and $gateIndex -gt 0) {
    # 바퀴 중간의 순열 유실/손상: 기존 index 를 새 순열에 적용하면 중복/누락이 생기므로
    # 진행 전체를 처음부터 (리뷰 조건: index>0 이면 전체 초기화)
    Add-GuiLog '[안내] 랜덤 진행 순서 기록이 없거나 손상돼 처음(1바퀴)부터 새로 시작합니다.'
    $gateLap = 1
    $gateIndex = 0
  }
  $gateNewProgress = [pscustomobject]@{
    lap          = $gateLap
    index        = $gateIndex
    fingerprint  = (Get-CustomFingerprint -Items $gateItems)
    shuffleOrder = [array]@(New-CustomShuffleOrder -ItemCount $gateItems.Count)
  }
  if ($node.PSObject.Properties['progress']) { $node.progress = $gateNewProgress }
  else { $node | Add-Member -NotePropertyName 'progress' -NotePropertyValue $gateNewProgress }
  try {
    Save-Config $cfg
  } catch {
    Add-GuiLog "[오류] 랜덤 진행 순서 저장 실패: $($_.Exception.Message) - 시작하지 않습니다."
    return $false
  }
  return $true
}

function Clear-CustomEnv {
  # GUI 프로세스의 환경변수는 회차/모드 전환 뒤에도 남습니다. HONEYNOGI_CUSTOM_ITEM 이 남아
  # 있으면 워커가 '존재 = 커스텀 모드' 규약 때문에 어비스/사냥터 회차를 커스텀으로 오동작하므로,
  # 비커스텀 회차 시작 전과 정지(Stop-AllRun) 시 반드시 전부 제거합니다.
  # (HONEYNOGI_REPEAT_INFO 는 기존 변수라 매 회차 덮어쓰므로 정리 불필요)
  foreach ($envName in @('HONEYNOGI_CUSTOM_ITEM', 'HONEYNOGI_CUSTOM_PREV', 'HONEYNOGI_CUSTOM_NEXT',
      'HONEYNOGI_CUSTOM_RESTART', 'HONEYNOGI_CUSTOM_RECOVERY', 'HONEYNOGI_CUSTOM_POSITION',
      'HONEYNOGI_CUSTOM_LIST', 'HONEYNOGI_CUSTOM_MARKER', 'HONEYNOGI_CUSTOM_OWNER',
      'HONEYNOGI_LAST_RUN')) {
    Remove-Item -LiteralPath "Env:\$envName" -ErrorAction SilentlyContinue
  }
}

function Load-SettingsToUi {
  $cfg = Read-Config
  if (-not $cfg) {
    $causeText = $(if ($script:configReadError) { " (원인: $($script:configReadError))" } else { '' })
    Add-GuiLog "config.json 을 읽지 못해 기본값으로 표시합니다.$causeText"
    return
  }
  $spaceEntry = Get-KeyEntry $cfg 32
  $foodEntry = Get-KeyEntry $cfg 66
  if ($spaceEntry -and $spaceEntry.PSObject.Properties['enabled']) { $chkSpace.Checked = ConvertTo-StrictBoolean $spaceEntry.enabled $true } else { $chkSpace.Checked = $true }
  if ($foodEntry -and $foodEntry.PSObject.Properties['enabled']) { $chkFood.Checked = ConvertTo-StrictBoolean $foodEntry.enabled $true } else { $chkFood.Checked = $true }
  # 자동부활 설정 복원 (revive 항목이 없던 예전 config 는 기본 켜짐)
  if ($cfg.PSObject.Properties['revive'] -and $cfg.revive.PSObject.Properties['enabled']) {
    $chkRevive.Checked = ConvertTo-StrictBoolean $cfg.revive.enabled $true
  } else {
    $chkRevive.Checked = $true
  }
  # 어시스트 자동 켜기 설정 복원 (assist 항목이 없던 예전 config 는 기본 켜짐)
  if ($cfg.PSObject.Properties['assist'] -and $cfg.assist.PSObject.Properties['autoEnable']) {
    $chkAssist.Checked = ConvertTo-StrictBoolean $cfg.assist.autoEnable $true
  } else {
    $chkAssist.Checked = $true
  }
  # 저장된 선택 던전 복원 (해당 라디오가 활성화된 경우에만)
  try {
    $savedDungeon = [string]$cfg.dungeons.selected
    if ($savedDungeon -eq '광기의 동굴' -and $rbDgMadness.Enabled) { $rbDgMadness.Checked = $true }
    elseif ($savedDungeon -eq '흩어진 물길' -and $rbDgScattered.Enabled) { $rbDgScattered.Checked = $true }
    else { $rbDgHeosang.Checked = $true }
  } catch { $rbDgHeosang.Checked = $true }
  # 저장된 입장 방식 복원
  try {
    if ([string]$cfg.dungeons.mode -eq 'party') { $rbModeParty.Checked = $true } else { $rbModeSolo.Checked = $true }
  } catch { $rbModeSolo.Checked = $true }
  # 저장된 어비스 매칭 방식 복원 (함께하기 전용 설정).
  # 과도기 config 는 파티 상태가 dungeons.partyState 로 분리 저장된 버전이 있었으므로
  # 그 값이 파티(파티장)/(파티원)이면 매칭으로 되돌려 해석합니다.
  try {
    $savedMatching = [string]$cfg.dungeons.matching
    $legacyPartyState = [string]$cfg.dungeons.partyState
    if ($legacyPartyState -eq '파티(파티장)' -or $legacyPartyState -eq '파티(파티원)') {
      $savedMatching = $legacyPartyState
    }
    switch ($savedMatching) {
      '파티찾기' { $rbAbyssFindParty.Checked = $true }
      '파티(파티장)' { $rbAbyssPartyLead.Checked = $true }
      '파티(파티원)' { $rbAbyssPartyMember.Checked = $true }
      default { $rbAbyssChance.Checked = $true }
    }
  } catch { $rbAbyssChance.Checked = $true }
  # 저장된 콘텐츠 카테고리 복원 (abyss = 어비스 / dungeon = 던전 / deepdungeon = 심층던전 / hunting = 사냥터)
  try {
    switch ([string]$cfg.contentCategory) {
      'dungeon'     { $rbCatDungeon.Checked = $true }
      'deepdungeon' { $rbCatDeep.Checked = $true }
      'hunting'     { $rbCatHunting.Checked = $true }
      default       { $rbCatAbyss.Checked = $true }
    }
  } catch { $rbCatAbyss.Checked = $true }
  # 저장된 대분류(전투/생활)와 생활 설정 복원 (v2.0.0. 잘못된 값은 전부 기본값 폴백 - 리뷰 조건 F)
  try {
    $lifeCfg = $null
    if ($cfg.PSObject.Properties['life']) { $lifeCfg = $cfg.life }
    if ($lifeCfg) {
      $rbLifeProcess.Checked = ([string]$lifeCfg.content -eq 'process')
      $rbLifeGather.Checked = -not $rbLifeProcess.Checked
      $savedSkillId = [string]$lifeCfg.skill
      $script:lifeSkillIndex = 0
      foreach ($skillIdx in 0..(@($script:lifeSkills).Count - 1)) {
        if ([string]$script:lifeSkills[$skillIdx].Id -eq $savedSkillId) { $script:lifeSkillIndex = $skillIdx; break }
      }
      $script:lifeSkillPage = [Math]::Floor($script:lifeSkillIndex / 3)
      $savedTarget = [string]$lifeCfg.target
      $savedTargets = @($script:lifeSkills[$script:lifeSkillIndex].Targets)
      $script:lifeTargetIndex = 0
      foreach ($targetIdx in 0..($savedTargets.Count - 1)) {
        if ([string]$savedTargets[$targetIdx] -eq $savedTarget) { $script:lifeTargetIndex = $targetIdx; break }
      }
      $script:lifeTargetPage = [Math]::Floor($script:lifeTargetIndex / 3)
      $gatherWaitSaved = 600
      try { $gatherWaitSaved = [int]$lifeCfg.gatherWaitSeconds } catch { }
      $numGatherWait.Value = [Math]::Min([Math]::Max($gatherWaitSaved, [int]$numGatherWait.Minimum), [int]$numGatherWait.Maximum)
    }
  } catch {
    Add-GuiLog "[경고] 생활 설정 복원 중 오류 - 기본값으로 시작합니다 ($($_.Exception.Message))"
  }
  # 저장된 기타(냥코인 뽑기) 설정 복원 (2026-08-15)
  try {
    if ($cfg.PSObject.Properties['etc'] -and $cfg.etc) {
      $etcCfg = $cfg.etc
      $etcTargetSaved = 10
      try { if ($etcCfg.PSObject.Properties['nyanTargetCoins']) { $etcTargetSaved = [int64]$etcCfg.nyanTargetCoins } } catch { }
      $numEtcTarget.Value = [Math]::Min([Math]::Max($etcTargetSaved, [int64]$numEtcTarget.Minimum), [int64]$numEtcTarget.Maximum)
      try { if ($etcCfg.PSObject.Properties['goldLimitEnabled']) { $chkEtcGoldLimit.Checked = ConvertTo-StrictBoolean $etcCfg.goldLimitEnabled $false } } catch { }
      $etcGoldSaved = 1000000
      try { if ($etcCfg.PSObject.Properties['goldLimitGold']) { $etcGoldSaved = [int64]$etcCfg.goldLimitGold } } catch { }
      $numEtcGoldLimit.Value = [Math]::Min([Math]::Max($etcGoldSaved, [int64]$numEtcGoldLimit.Minimum), [int64]$numEtcGoldLimit.Maximum)
      $numEtcGoldLimit.Enabled = [bool]$chkEtcGoldLimit.Checked
    }
  } catch {
    Add-GuiLog "[경고] 기타 설정 복원 중 오류 - 기본값으로 시작합니다 ($($_.Exception.Message))"
  }
  # 대분류 복원은 생활 세부 값 복원과 분리 - 세부 복원이 실패해도 사용자가 쓰던 화면(생활)은
  # 유지되게 합니다 (리뷰 권고. Set-MainCategory 는 같은 값이면 조기 반환)
  try {
    if ([string]$cfg.mainCategory -eq 'life') { Set-MainCategory -Category 'life' }
    elseif ([string]$cfg.mainCategory -eq 'etc') { Set-MainCategory -Category 'etc' }
  } catch { }
  # 저장된 사냥터 설정 복원
  try {
    $ht = $cfg.huntingGround
    if ($ht) {
      switch ([string]$ht.difficulty) {
        '어려움'      { $rbHtHard.Checked = $true }
        '매우 어려움' { $rbHtVeryHard.Checked = $true }
        default       { $rbHtNormal.Checked = $true }
      }
      $chkHtCoin.Checked = ConvertTo-StrictBoolean $ht.useOffering $false
      $chkHtDoubleLoot.Checked = ConvertTo-StrictBoolean $ht.doubleLoot $false
      # '소탕만 계속'은 더블 루팅이 켜져 있을 때만 의미가 있으므로 함께 확인합니다
      try { $chkHtLootFallback.Checked = ((ConvertTo-StrictBoolean $ht.continueSweepOnly $false) -and $chkHtDoubleLoot.Checked) } catch { $chkHtLootFallback.Checked = $false }
      if ([string]$ht.matching -eq '바로 입장') { $rbHtDirect.Checked = $true } else { $rbHtParty.Checked = $true }
    }
  } catch { }
  # 저장된 일반 던전 설정 복원
  try {
    $nd = $cfg.normalDungeon
    if ($nd) {
      switch ([string]$nd.difficulty) {
        '어려움' { $rbNdHard.Checked = $true }
        '매우 어려움' { $rbNdVeryHard.Checked = $true }
        default { $rbNdNormal.Checked = $true }
      }
      $stageValue = [string]$nd.stage
      if ($stageValue) {
        if (-not $cboNdStage.Items.Contains($stageValue)) { [void]$cboNdStage.Items.Add($stageValue) }
        $cboNdStage.SelectedItem = $stageValue
      }
      $chkNdCoin.Checked = ConvertTo-StrictBoolean $nd.useSilverCoin $false
      $chkNdDoubleLoot.Checked = ConvertTo-StrictBoolean $nd.doubleLoot $false
      try { $rbNdExhaustGo.Checked = ConvertTo-StrictBoolean $nd.continueWithoutCoin $false } catch { $rbNdExhaustStop.Checked = $true }
      # 두 번째 단계는 더블 루팅이 켜져 있을 때만 유효합니다.
      try { $rbNdNoDoubleSweep.Checked = ((ConvertTo-StrictBoolean $nd.continueSweepOnly $false) -and $chkNdDoubleLoot.Checked) } catch { $rbNdNoDoubleStop.Checked = $true }
      if ([string]$nd.matching -eq '우연한 만남') { $rbNdChance.Checked = $true } else { $rbNdFindParty.Checked = $true }
    }
  } catch { }
  # 저장된 심층던전 설정 복원 (difficulty '매우 어려움' = 주간 단일 구역 반복.
  # stage 는 내부 표기('1-1')로 저장되고 콤보는 'D1-1' 표시라 변환해 선택합니다)
  try {
    $dd = $cfg.deepDungeon
    if ($dd) {
      if ([string]$dd.difficulty -eq '매우 어려움') { $rbDdWeeklyVeryHard.Checked = $true } else { $rbDdHard.Checked = $true }
      $ddStageDisplay = Get-DeepStageDisplay -Stage ([string]$dd.stage)
      if ($ddStageDisplay -and $cboDdStage.Items.Contains($ddStageDisplay)) { $cboDdStage.SelectedItem = $ddStageDisplay }
      $chkDdTribute.Checked = ConvertTo-StrictBoolean $dd.useTribute $false
      try { $rbDdExhaustGo.Checked = ConvertTo-StrictBoolean $dd.continueWithoutTribute $false } catch { $rbDdExhaustStop.Checked = $true }
      if ([string]$dd.matching -eq '파티찾기') { $rbDdFindParty.Checked = $true } else { $rbDdChance.Checked = $true }
    }
  } catch { }
  # 저장된 커스텀 반복 설정 복원 (리스트/반복 방식/소진 대응. progress 는 UI에 표시하지 않고
  # 시작 시 판정합니다. 카테고리 복원이 위에서 먼저 실행되므로 이 위치가 안전 - 던전이면 라디오 복원)
  try {
    if ($cfg.PSObject.Properties['customRepeat'] -and $cfg.customRepeat) {
      $cr = $cfg.customRepeat
      $script:crLoading = $true
      try {
        $lvCrList.Items.Clear()
        if ($cr.PSObject.Properties['items']) {
          foreach ($crSavedItem in @($cr.items)) {
            if ($null -eq $crSavedItem) { continue }
            # 계약 밖 stage 값(직접 편집 등)은 행으로 넣지 않습니다 - 심층 로드(4890 부근)와
            # 같은 규칙 (2026-08-01 전수 점검: 일반 던전만 미검증이라 범위 밖 구역이 시작
            # 게이트(층 해석 불가 → 방어적 통과)를 지나 워커까지 전달될 수 있었음)
            if (([string]$crSavedItem.stage) -notmatch '^[12]-[123]$') { continue }
            # 구버전(계약 v1) config 항목에는 exhaustContinue/noDoubleSweep 가 없음 - 기본 false(멈춤)
            Add-CustomListRow -Difficulty ([string]$crSavedItem.difficulty) -Stage ([string]$crSavedItem.stage) `
              -Coin (ConvertTo-StrictBoolean $crSavedItem.coin $false) `
              -DoubleLoot (ConvertTo-StrictBoolean $crSavedItem.doubleLoot $false) `
              -ExhaustContinue (ConvertTo-StrictBoolean $crSavedItem.exhaustContinue $false) `
              -NoDoubleSweep (ConvertTo-StrictBoolean $crSavedItem.noDoubleSweep $false)
          }
        }
        Update-CustomListNumbers
        if ([string]$cr.listRepeat -eq 'count') { $rbCrCount.Checked = $true } else { $rbCrInfinite.Checked = $true }
        try { $numCrLaps.Value = [Math]::Min(999, [Math]::Max(1, [int]$cr.listRepeatCount)) } catch { $numCrLaps.Value = 1 }
        Update-CustomCoinTotalLabel
        # 선택 의도 복원: 던전이 아닌 카테고리로 저장돼 있어도 enabled 는 의도로 보존하고,
        # 던전/어비스 카테고리일 때 라디오를 실제로 켭니다 (사냥터는 커스텀 미지원).
        $script:customEnabledWish = $false
        if ($cr.PSObject.Properties['enabled'] -and (ConvertTo-StrictBoolean $cr.enabled $false)) { $script:customEnabledWish = $true }
        if ($script:customEnabledWish -and -not $rbCatHunting.Checked) { $rbCustomRepeat.Checked = $true }
      } finally { $script:crLoading = $false }
      # 복원된 리스트가 혼합이면 반복을 '횟수 1바퀴'로 즉시 고정 (저장은 다음 변경 때 반영)
      Update-CustomRepeatMixLock -Items @(Get-CustomItemsFromList) `
        -RbInfinite $rbCrInfinite -RbCount $rbCrCount -NumLaps $numCrLaps -StateKey 'cr'
    }
  } catch { $script:crLoading = $false }
  # 저장된 어비스 커스텀 반복 목록/반복 방식 복원. 진행 기록은 시작 시 지문과 함께 판정합니다.
  try {
    if ($cfg.PSObject.Properties['abyssCustomRepeat'] -and $cfg.abyssCustomRepeat) {
      $acr = $cfg.abyssCustomRepeat
      $script:crLoading = $true
      try {
        $lvAcrList.Items.Clear()
        if ($acr.PSObject.Properties['items']) {
          foreach ($acrSavedItem in @($acr.items)) {
            if ($null -eq $acrSavedItem) { continue }
            Add-AbyssCustomListRow -Mode ([string]$acrSavedItem.mode) `
              -Difficulty ([string]$acrSavedItem.difficulty) -Dungeon ([string]$acrSavedItem.dungeon) `
              -Matching ([string]$acrSavedItem.matching)
          }
        }
        Update-AbyssCustomListNumbers
        if ([string]$acr.listRepeat -eq 'count') { $rbAcrCount.Checked = $true } else { $rbAcrInfinite.Checked = $true }
        try { $numAcrLaps.Value = [Math]::Min(999, [Math]::Max(1, [int]$acr.listRepeatCount)) } catch { $numAcrLaps.Value = 1 }
        $numAcrLaps.Enabled = $rbAcrCount.Checked
      } finally { $script:crLoading = $false }
      # 복원된 리스트 기준으로 방식·매칭 입력 잠금을 맞춥니다 (통일 규칙)
      Update-AbyssInputLock
    }
  } catch { $script:crLoading = $false }
  # 저장된 심층 커스텀 반복 목록/반복 방식 복원. 진행 기록은 시작 시 지문과 함께 판정합니다.
  try {
    if ($cfg.PSObject.Properties['deepCustomRepeat'] -and $cfg.deepCustomRepeat) {
      $dcr = $cfg.deepCustomRepeat
      $script:crLoading = $true
      try {
        $lvDcrList.Items.Clear()
        if ($dcr.PSObject.Properties['items']) {
          foreach ($dcrSavedItem in @($dcr.items)) {
            if ($null -eq $dcrSavedItem) { continue }
            # 계약 밖 stage 값(직접 편집 등)은 행으로 넣지 않습니다 - 내부 형식('1-1'~'2-3')만 인정
            # (리뷰 지적: D 접두 검사만으로는 'D3-1' 같은 범위 밖 값이 통과해 워커 파싱에서 실패)
            $dcrSavedStage = [string]$dcrSavedItem.stage
            if ($dcrSavedStage -notmatch '^[12]-[123]$') { continue }
            $dcrSavedCoin = ConvertTo-StrictBoolean $dcrSavedItem.coin $false
            Add-DeepCustomListRow -Stage $dcrSavedStage -Coin $dcrSavedCoin `
              -ExhaustContinue ($dcrSavedCoin -and (ConvertTo-StrictBoolean $dcrSavedItem.exhaustContinue $false))
          }
        }
        Update-DeepCustomListNumbers
        if ([string]$dcr.listRepeat -eq 'count') { $rbDcrCount.Checked = $true } else { $rbDcrInfinite.Checked = $true }
        try { $numDcrLaps.Value = [Math]::Min(999, [Math]::Max(1, [int]$dcr.listRepeatCount)) } catch { $numDcrLaps.Value = 1 }
        $numDcrLaps.Enabled = $rbDcrCount.Checked
        Update-DeepTributeTotalLabel
      } finally { $script:crLoading = $false }
      # 복원된 리스트가 혼합이면 반복을 '횟수 1바퀴'로 즉시 고정 (저장은 다음 변경 때 반영)
      Update-CustomRepeatMixLock -Items @(Get-DeepCustomItemsFromList) `
        -RbInfinite $rbDcrInfinite -RbCount $rbDcrCount -NumLaps $numDcrLaps -StateKey 'dcr'
    }
  } catch { $script:crLoading = $false }
  # 저장된 생활(채집) 커스텀 반복 목록/반복 방식 복원. 진행 기록은 시작 시 지문과 함께 판정합니다.
  # 심층과 달리 '혼합 리스트 1바퀴 고정'은 적용하지 않습니다 (생활은 스킬을 섞어도 무제약)
  try {
    if ($cfg.PSObject.Properties['lifeCustomRepeat'] -and $cfg.lifeCustomRepeat) {
      $lcr = $cfg.lifeCustomRepeat
      $script:crLoading = $true
      try {
        $lvLcrList.Items.Clear()
        if ($lcr.PSObject.Properties['items']) {
          foreach ($lcrSavedItem in @($lcr.items)) {
            if ($null -eq $lcrSavedItem) { continue }
            # 계약 밖 값(직접 편집 등)은 행으로 넣지 않습니다 - 모르는 스킬 Id 나 빈 대상은
            # 워커가 스킬 창에서 찾지 못해 그 항목 차례에 반드시 멈춥니다
            $lcrSavedSkill = [string]$lcrSavedItem.skill
            $lcrSavedTarget = [string]$lcrSavedItem.target
            if ([string]::IsNullOrWhiteSpace($lcrSavedSkill) -or [string]::IsNullOrWhiteSpace($lcrSavedTarget)) { continue }
            if ([string](Get-LifeSkillNameById -Id $lcrSavedSkill) -eq $lcrSavedSkill) { continue }
            $lcrSavedCount = 1
            try { $lcrSavedCount = [int]$lcrSavedItem.count } catch { $lcrSavedCount = 1 }
            if ($lcrSavedCount -lt 1) { $lcrSavedCount = 1 }
            if ($lcrSavedCount -gt 99) { $lcrSavedCount = 99 }
            Add-LifeCustomListRow -Skill $lcrSavedSkill -Target $lcrSavedTarget -Count $lcrSavedCount
          }
        }
        Update-LifeCustomListNumbers
        if ([string]$lcr.listRepeat -eq 'count') { $rbLcrCount.Checked = $true } else { $rbLcrInfinite.Checked = $true }
        try { $numLcrLaps.Value = [Math]::Min(999, [Math]::Max(1, [int]$lcr.listRepeatCount)) } catch { $numLcrLaps.Value = 1 }
        $numLcrLaps.Enabled = $rbLcrCount.Checked
        Update-LifeCustomTotalLabel
      } finally { $script:crLoading = $false }
    }
  } catch { $script:crLoading = $false }
  # 랜덤 진행 토글 복원 (3섹션 - JSON 불리언만 인정. 프로그램적 변경은 crLoading 가드로
  # 저장 이벤트 억제, 복원 후 층 혼합 게이트를 다시 계산합니다)
  $script:crLoading = $true
  try {
    try { $chkCrRandom.Checked = (Get-CustomRandomOrderEnabled -Node $cfg.customRepeat) } catch { }
    try { $chkAcrRandom.Checked = (Get-CustomRandomOrderEnabled -Node $cfg.abyssCustomRepeat) } catch { }
    try { $chkDcrRandom.Checked = (Get-CustomRandomOrderEnabled -Node $cfg.deepCustomRepeat) } catch { }
    try { $chkLcrRandom.Checked = (Get-CustomRandomOrderEnabled -Node $cfg.lifeCustomRepeat) } catch { }
  } finally { $script:crLoading = $false }
  Update-CustomRandomToggleStyle -Toggle $chkCrRandom
  Update-CustomRandomToggleStyle -Toggle $chkAcrRandom
  Update-CustomRandomToggleStyle -Toggle $chkDcrRandom
  Update-CustomRandomToggleStyle -Toggle $chkLcrRandom
  Update-CustomRandomMixGate -Toggle $chkCrRandom -Items @(Get-CustomItemsFromList) -SectionName 'customRepeat'
  Update-CustomRandomMixGate -Toggle $chkDcrRandom -Items @(Get-DeepCustomItemsFromList) -SectionName 'deepCustomRepeat'
  # 저장된 난이도 복원 (없거나 빈 값이면 '게임 그대로'. 목록에 없는 이름이 저장돼
  # 있으면 - 예: config 에 직접 적은 새 난이도 - 목록에 추가한 뒤 선택합니다.
  # 단, 지옥 난이도는 함께하기 전용이라 혼자하기 상태면 '게임 그대로'로 되돌립니다)
  try {
    $savedDifficulty = [string]$cfg.dungeons.difficulty
    if ($savedDifficulty) {
      if ($cboDifficulty.Items.Contains($savedDifficulty)) {
        $cboDifficulty.SelectedItem = $savedDifficulty
      } elseif ($rbModeSolo.Checked -and $savedDifficulty -match '^지옥') {
        $cboDifficulty.SelectedIndex = 0
      } else {
        [void]$cboDifficulty.Items.Add($savedDifficulty)
        $cboDifficulty.SelectedItem = $savedDifficulty
      }
    } else {
      $cboDifficulty.SelectedIndex = 0
    }
  } catch { $cboDifficulty.SelectedIndex = 0 }
  try { $numClearWait.Value = [int]$cfg.timeoutsSeconds.dungeonClear } catch { }
  try { $numCount.Value = [int]$cfg.repeat.defaultCount } catch { }
  # 반복 모드/종료 시각 복원 (숫자만 복원하면 화면과 실제 동작이 어긋납니다 - 10차 점검).
  # 시간 지정은 **오늘 그 시각**으로 되살리되, 이미 지난 시각이면 무한으로 되돌리고 알립니다
  # (그대로 두면 시작하자마자 '지정 시간 도달'로 멈춰 이유를 알기 어렵습니다).
  try {
    $savedUntil = [string]$cfg.repeat.untilTime
    if ($savedUntil -match '^\d{1,2}:\d{2}$') {
      $parsedUntil = [datetime]::ParseExact($savedUntil, 'H:mm', $null)
      $dtpUntil.Value = (Get-Date).Date.AddHours($parsedUntil.Hour).AddMinutes($parsedUntil.Minute)
    }
  } catch { }
  # ★★ [커스텀 반복] 라디오도 **같은 GroupBox($grpRepeat) 소속**이라, 여기서 무한/횟수/시간
  #   중 하나를 켜면 WinForms 자동 배타로 **커스텀 선택이 풀립니다.** 게다가 그
  #   CheckedChanged 가 $script:customEnabledWish 까지 $false 로 덮어 복구 경로마저 끊고,
  #   이후 저장이 config 의 customRepeat.enabled=false 를 디스크에 굳힙니다.
  #   그러면 커스텀 반복을 켜 둔 사용자가 컨트롤 패널을 껐다 켤 때마다 **조용히 단일 콘텐츠
  #   무한 반복으로 돌아갑니다** - 리스트가 통째로 무시되는 배포 차단급 회귀입니다.
  #   (2026-08-10 11차 점검. 10차에 넣은 이 복원이 만든 것이고, 실제 WinForms 하네스로
  #    4가지 저장값 전부에서 재현했습니다. 프로젝트가 8590 부근에서 같은 배타 문제를 이미
  #    crSwitching 가드로 다루고 있었는데 새 코드가 그 교훈을 비껴갔습니다.)
  #   → 커스텀이 선택돼 있으면 상단 모드 복원을 **건너뜁니다.** 커스텀 반복 자체가 이 그룹의
  #     네 번째 모드이므로, 그때는 복원할 '상단 모드'가 없는 것이 맞습니다.
  if (-not $rbCustomRepeat.Checked) {
    try {
      switch ([string]$cfg.repeat.mode) {
        'count' { $rbCount.Checked = $true }
        'time' {
          if ($dtpUntil.Value -gt (Get-Date)) { $rbTime.Checked = $true }
          else {
            $rbInfinite.Checked = $true
            Add-GuiLog "[안내] 저장된 종료 시각($($dtpUntil.Value.ToString('HH:mm')))이 이미 지나 '무한 반복'으로 되돌렸습니다 - 필요하면 다시 지정해 주세요."
          }
        }
        default { $rbInfinite.Checked = $true }
      }
    } catch { }
  }
  try { $numFontSize.Value = [int]$cfg.ui.logFontSize } catch { }
  # 탭 토글 상태 복원 (2026-08-04 시안 - 기본 둘 다 접힘. JSON 불리언만 인정 - 리뷰 조건.
  # 프로그램적 체크 변경의 CheckedChanged 저장은 uiReady 가드가 막음)
  try { $chkTabSettings.Checked = ConvertTo-StrictBoolean $cfg.ui.settingsOpen $false } catch { }
  try { $chkTabLog.Checked = ConvertTo-StrictBoolean $cfg.ui.logOpen $false } catch { }
}

function Save-SettingsFromUi {
  $cfg = Read-Config
  if (-not $cfg) {
    # 복구 방법까지 알려 줍니다. 파일이 깨지면 런처는 '파일이 있으니 정상'으로 보고 기본
    # config 를 다시 추출하지 않고, 저장도 읽기가 선행이라 계속 실패합니다. 그러면 [시작]을
    # 눌러도 로그 한 줄만 남고 영영 시작되지 않는데 화면 어디에도 복구 안내가 없었습니다
    # (2026-08-10 8차 점검). 파일을 지우면 다음 실행에서 기본값으로 다시 만들어집니다.
    $causeText = $(if ($script:configReadError) { " (원인: $($script:configReadError))" } else { '' })
    Add-GuiLog "[오류] config.json 을 읽지 못해 저장할 수 없습니다.$causeText"
    Add-GuiLog "[안내] 복구 방법: 컨트롤 패널을 끄고 '$configPath' 파일을 지운 뒤 다시 실행하면 기본 설정으로 새로 만들어집니다 (설정은 초기화됩니다)."
    return $false
  }
  $spaceEntry = Get-KeyEntry $cfg 32
  $foodEntry = Get-KeyEntry $cfg 66
  if ($spaceEntry) { $spaceEntry.enabled = [bool]$chkSpace.Checked }
  if ($foodEntry) { $foodEntry.enabled = [bool]$chkFood.Checked }
  # 자동부활(불사의 가루) 설정 저장. revive 항목이 없던 예전 config 에는 새로 만들어 기록합니다.
  if ($cfg.PSObject.Properties['revive']) {
    if ($cfg.revive.PSObject.Properties['enabled']) { $cfg.revive.enabled = [bool]$chkRevive.Checked }
    else { $cfg.revive | Add-Member -NotePropertyName 'enabled' -NotePropertyValue ([bool]$chkRevive.Checked) }
  } else {
    $cfg | Add-Member -NotePropertyName 'revive' -NotePropertyValue ([pscustomobject]@{
      '_설명'  = '던전에서 캐릭터가 행동불능(사망)이 되면 자동으로 부활하는 기능입니다.'
      enabled  = [bool]$chkRevive.Checked
      key      = 82
      maxPerCycle = 10
    })
  }
  # 탭 토글(설정/로그 표시) 상태도 최종 병합 - 즉시 저장(Save-UiToggleState)과 별개로 시작 시
  # 저장 경로에서도 두 값을 함께 보존합니다 (리뷰 조건)
  if (-not $cfg.PSObject.Properties['ui']) {
    $cfg | Add-Member -NotePropertyName 'ui' -NotePropertyValue ([pscustomobject]@{})
  }
  foreach ($togglePair in @(, @('settingsOpen', [bool]$chkTabSettings.Checked)) + @(, @('logOpen', [bool]$chkTabLog.Checked))) {
    if ($cfg.ui.PSObject.Properties[[string]$togglePair[0]]) { $cfg.ui.([string]$togglePair[0]) = [bool]$togglePair[1] }
    else { $cfg.ui | Add-Member -NotePropertyName ([string]$togglePair[0]) -NotePropertyValue ([bool]$togglePair[1]) }
  }
  # 어시스트 자동 켜기 설정 저장. assist 항목이 없던 예전 config 에는 새로 만들어 기록합니다.
  if ($cfg.PSObject.Properties['assist']) {
    if ($cfg.assist.PSObject.Properties['autoEnable']) { $cfg.assist.autoEnable = [bool]$chkAssist.Checked }
    else { $cfg.assist | Add-Member -NotePropertyName 'autoEnable' -NotePropertyValue ([bool]$chkAssist.Checked) }
  } else {
    $cfg | Add-Member -NotePropertyName 'assist' -NotePropertyValue ([pscustomobject]@{
      '_설명'    = '전투 중 우측 ASSIST(어시스트 모드) 토글이 꺼져 있으면 자동으로 켜는 기능입니다.'
      autoEnable = [bool]$chkAssist.Checked
      key        = 72
    })
  }
  # 창 자동 정렬과 가림 자동 복구는 안정 동작의 핵심이라 항상 켜둡니다.
  # 가림 자동 복구는 "실제로 가려짐 + 사용자 자리 비움"일 때만 동작하므로 성가실 일이 없습니다.
  # 아래 섹션들은 구버전/수동 편집 config 에 없을 수 있으므로, 없으면 만들어 넣어 저장이 죽지 않게 합니다.
  if (-not $cfg.PSObject.Properties['window']) { $cfg | Add-Member -NotePropertyName 'window' -NotePropertyValue ([pscustomobject]@{}) }
  if ($cfg.window.PSObject.Properties['normalize']) { $cfg.window.normalize = $true }
  else { $cfg.window | Add-Member -NotePropertyName 'normalize' -NotePropertyValue $true }
  # 창 크기 모드: GUI 는 nearest(사용자 크기 유지 + 비율 보정)를 사용합니다.
  # '권장 창 모드' 버튼은 즉시 1회 적용 방식이라 상시 모드가 필요 없습니다.
  # (과거 체크박스 시절 저장된 recommended 는 nearest 로 되돌리고, 직접 적은 fixed 는 유지)
  if ($cfg.window.PSObject.Properties['mode']) {
    if ([string]$cfg.window.mode -eq 'recommended') { $cfg.window.mode = 'nearest' }
  } else {
    $cfg.window | Add-Member -NotePropertyName 'mode' -NotePropertyValue 'nearest'
  }
  # RDP 자동 전환은 config 값(rdp.autoConsoleRedirect)을 존중합니다. false 로 바꾸면
  # 다음 시작/저장 때 예약 작업이 제거됩니다 (config 주석의 안내와 동작을 일치시킴).
  if (-not $cfg.PSObject.Properties['rdp']) { $cfg | Add-Member -NotePropertyName 'rdp' -NotePropertyValue ([pscustomobject]@{}) }
  if (-not $cfg.rdp.PSObject.Properties['autoConsoleRedirect']) { $cfg.rdp | Add-Member -NotePropertyName 'autoConsoleRedirect' -NotePropertyValue $true }
  # 가림 복구 주기: 문서대로 '0 = 기능 끄기'를 허용합니다. 키가 아예 없을 때만 기본 8초를 넣습니다.
  if (-not $cfg.PSObject.Properties['focus']) { $cfg | Add-Member -NotePropertyName 'focus' -NotePropertyValue ([pscustomobject]@{}) }
  if (-not $cfg.focus.PSObject.Properties['refocusEverySeconds']) { $cfg.focus | Add-Member -NotePropertyName 'refocusEverySeconds' -NotePropertyValue 8 }
  if (-not $cfg.PSObject.Properties['timeoutsSeconds']) { $cfg | Add-Member -NotePropertyName 'timeoutsSeconds' -NotePropertyValue ([pscustomobject]@{}) }
  if ($cfg.timeoutsSeconds.PSObject.Properties['dungeonClear']) { $cfg.timeoutsSeconds.dungeonClear = [int]$numClearWait.Value }
  else { $cfg.timeoutsSeconds | Add-Member -NotePropertyName 'dungeonClear' -NotePropertyValue ([int]$numClearWait.Value) }
  if (-not $cfg.PSObject.Properties['repeat']) { $cfg | Add-Member -NotePropertyName 'repeat' -NotePropertyValue ([pscustomobject]@{}) }
  if ($cfg.repeat.PSObject.Properties['defaultCount']) { $cfg.repeat.defaultCount = [int]$numCount.Value }
  else { $cfg.repeat | Add-Member -NotePropertyName 'defaultCount' -NotePropertyValue ([int]$numCount.Value) }
  # ★ 숫자만 저장하고 **모드(무한/횟수/시간)** 는 저장하지 않던 것을 함께 저장합니다.
  #   그러면 다시 켰을 때 칸에는 '50' 이 그대로 보이는데 실제로는 무한 반복이라,
  #   사용자가 '50회로 맞춰 뒀다'고 믿은 채 밤새 도는 상태가 됩니다 (2026-08-10 10차 점검).
  # 커스텀 반복이 선택된 동안에는 상단 모드가 전부 꺼져 있습니다(같은 라디오 그룹).
  # 그때 'infinite' 로 덮어쓰면 사용자가 커스텀을 껐을 때 원래 쓰던 '횟수 50' 이 사라집니다.
  # → 커스텀 중에는 **마지막 비커스텀 모드를 그대로 보존**합니다 (2026-08-10 11차 점검).
  if (-not $rbCustomRepeat.Checked) {
    $repeatMode = $(if ($rbCount.Checked) { 'count' } elseif ($rbTime.Checked) { 'time' } else { 'infinite' })
    if ($cfg.repeat.PSObject.Properties['mode']) { $cfg.repeat.mode = $repeatMode }
    else { $cfg.repeat | Add-Member -NotePropertyName 'mode' -NotePropertyValue $repeatMode }
  } elseif (-not $cfg.repeat.PSObject.Properties['mode']) {
    $cfg.repeat | Add-Member -NotePropertyName 'mode' -NotePropertyValue 'infinite'
  }
  $repeatUntil = $dtpUntil.Value.ToString('HH:mm')
  if ($cfg.repeat.PSObject.Properties['untilTime']) { $cfg.repeat.untilTime = $repeatUntil }
  else { $cfg.repeat | Add-Member -NotePropertyName 'untilTime' -NotePropertyValue $repeatUntil }

  # 선택된 던전을 config 에 기록 (워커가 이 값으로 카드 클릭 대상을 정함)
  $dungeonName = '허상의 정박지'
  if ($rbDgMadness.Checked) { $dungeonName = '광기의 동굴' }
  elseif ($rbDgScattered.Checked) { $dungeonName = '흩어진 물길' }
  $modeValue = 'solo'
  if ($rbModeParty.Checked) { $modeValue = 'party' }
  # 선택된 난이도 ('' = 게임 그대로, 난이도 클릭 안 함)
  $difficultyValue = ''
  if ($cboDifficulty.SelectedIndex -gt 0 -and $cboDifficulty.SelectedItem) {
    $difficultyValue = [string]$cboDifficulty.SelectedItem
  }
  # 콘텐츠 카테고리 저장 (abyss = 어비스 / dungeon = 던전 / deepdungeon = 심층던전 / hunting = 사냥터)
  $categoryValue = 'abyss'
  if ($rbCatDungeon.Checked) { $categoryValue = 'dungeon' }
  elseif ($rbCatDeep.Checked) { $categoryValue = 'deepdungeon' }
  elseif ($rbCatHunting.Checked) { $categoryValue = 'hunting' }
  if ($cfg.PSObject.Properties['contentCategory']) { $cfg.contentCategory = $categoryValue }
  else { $cfg | Add-Member -NotePropertyName 'contentCategory' -NotePropertyValue $categoryValue }
  # 대분류(전투/생활) 저장 (v2.0.0. contentCategory 는 전투 하위 선택이므로 그대로 두고
  # 별도 키로 저장 - 리뷰 조건 F)
  if ($cfg.PSObject.Properties['mainCategory']) { $cfg.mainCategory = [string]$script:mainCategory }
  else { $cfg | Add-Member -NotePropertyName 'mainCategory' -NotePropertyValue ([string]$script:mainCategory) }
  # 생활 설정 저장 (skill 은 안정 Id, target 은 게임 용어 표시명 그대로 - 설계 합의).
  # 섹션이 이미 있으면 객체 교체가 아니라 값 6개만 갱신합니다 - 교체하면 config.json 의
  # '_설명' 안내 키와 향후 워커 키가 저장 한 번에 삭제됨 (리뷰 지적)
  $lifeSkillSave = $script:lifeSkills[$script:lifeSkillIndex]
  $lifeTargetsSave = @($lifeSkillSave.Targets)
  $lifeValues = @{
    content   = $(if ($rbLifeProcess.Checked) { 'process' } else { 'gather' })
    skill     = [string]$lifeSkillSave.Id
    target    = $(if ($script:lifeTargetIndex -lt $lifeTargetsSave.Count) { [string]$lifeTargetsSave[$script:lifeTargetIndex] } else { '' })
    gatherWaitSeconds = [int]$numGatherWait.Value
  }
  if (-not $cfg.PSObject.Properties['life']) {
    $cfg | Add-Member -NotePropertyName 'life' -NotePropertyValue ([pscustomobject]@{
      '_설명' = "'생활' 대분류 설정입니다 (v2.0.0 - 채집은 낚시를 제외한 8종 지원. 낚시·가공은 개발 중)"
    })
  }
  foreach ($lifeKey in @('content', 'skill', 'target', 'gatherWaitSeconds')) {
    if ($cfg.life.PSObject.Properties[$lifeKey]) { $cfg.life.$lifeKey = $lifeValues[$lifeKey] }
    else { $cfg.life | Add-Member -NotePropertyName $lifeKey -NotePropertyValue $lifeValues[$lifeKey] }
  }
  # 기타(냥코인 뽑기) 설정 저장 (2026-08-15 - 생활과 같은 '값만 갱신' 방식)
  $etcValues = @{
    content          = 'catMerchant'
    nyanTargetCoins  = [int64]$numEtcTarget.Value
    goldLimitEnabled = [bool]$chkEtcGoldLimit.Checked
    goldLimitGold    = [int64]$numEtcGoldLimit.Value
  }
  if (-not $cfg.PSObject.Properties['etc']) {
    $cfg | Add-Member -NotePropertyName 'etc' -NotePropertyValue ([pscustomobject]@{
      '_설명' = "'기타' 대분류 설정입니다 (2026-08-15 - 고양이 상인 냥코인 뽑기)"
    })
  }
  foreach ($etcKey in @('content', 'nyanTargetCoins', 'goldLimitEnabled', 'goldLimitGold')) {
    if ($cfg.etc.PSObject.Properties[$etcKey]) { $cfg.etc.$etcKey = $etcValues[$etcKey] }
    else { $cfg.etc | Add-Member -NotePropertyName $etcKey -NotePropertyValue $etcValues[$etcKey] }
  }
  # 던전 설정 저장 (전체 자동화: 선택 → 옵션 → 입장 → 클리어 → 다시 하기 반복)
  $ndSettings = [pscustomobject]@{
    '_설명'       = "'던전' 카테고리 전용 설정입니다 (던전 전체 자동화 - 은동전/더블 루팅/매칭 포함)"
    difficulty    = $(if ($rbNdVeryHard.Checked) { '매우 어려움' } elseif ($rbNdHard.Checked) { '어려움' } else { '일반' })
    stage         = [string]$cboNdStage.SelectedItem
    useSilverCoin = [bool]$chkNdCoin.Checked
    doubleLoot    = [bool]($chkNdCoin.Checked -and $chkNdDoubleLoot.Checked)
    '_continueWithoutCoin' = '동전 소진 시(잔량 10 미만): true=미사용으로 진행 / false=멈춤'
    continueWithoutCoin = [bool]($chkNdCoin.Checked -and $rbNdExhaustGo.Checked)
    '_continueSweepOnly' = '더블 루팅 불가 시(잔량 10~19): true=소탕만 진행 / false=멈춤'
    continueSweepOnly   = [bool]($chkNdCoin.Checked -and $chkNdDoubleLoot.Checked -and $rbNdNoDoubleSweep.Checked)
    matching      = $(if ($rbNdChance.Checked) { '우연한 만남' } else { '파티찾기' })
  }
  if ($cfg.PSObject.Properties['normalDungeon']) { $cfg.normalDungeon = $ndSettings }
  else { $cfg | Add-Member -NotePropertyName 'normalDungeon' -NotePropertyValue $ndSettings }
  # 심층던전 설정 저장 (던전과 동일 흐름 - 재화만 마족공물. '매우 어려움' = 주간 단일 구역 반복)
  $ddSettings = [pscustomobject]@{
    '_설명'      = "'심층던전' 카테고리 전용 설정입니다 (던전과 동일 흐름 - 재화만 마족공물(어려움 1개/매우 어려움 2개), 더블 루팅 없음. difficulty '매우 어려움'은 주간 단일 구역 반복 - stage 는 무시하고 화면의 매우 어려움 구역을 자동 채택합니다)"
    difficulty   = $(if ($rbDdWeeklyVeryHard.Checked) { '매우 어려움' } else { '어려움' })
    stage        = (Get-DeepStageInternal -Display ([string]$cboDdStage.SelectedItem))
    useTribute   = [bool]$chkDdTribute.Checked
    '_continueWithoutTribute' = '공물 소진 시(잔량 부족): true=미사용으로 진행 / false=멈춤'
    continueWithoutTribute = [bool]($chkDdTribute.Checked -and $rbDdExhaustGo.Checked)
    matching     = $(if ($rbDdChance.Checked) { '우연한 만남' } else { '파티찾기' })
  }
  if ($cfg.PSObject.Properties['deepDungeon']) { $cfg.deepDungeon = $ddSettings }
  else { $cfg | Add-Member -NotePropertyName 'deepDungeon' -NotePropertyValue $ddSettings }
  # 사냥터 설정 저장 (특정 사냥터에 매이지 않음 - 원하는 사냥터 첫 화면을 열어 두고 시작)
  $htSettings = [pscustomobject]@{
    '_설명'      = "'사냥터' 카테고리 설정입니다. 원하는 사냥터의 첫 화면을 열어 두고 시작하면 어느 사냥터든 동작합니다"
    difficulty   = $(if ($rbHtVeryHard.Checked) { '매우 어려움' } elseif ($rbHtHard.Checked) { '어려움' } else { '일반' })
    useOffering  = [bool]$chkHtCoin.Checked
    doubleLoot   = [bool]($chkHtCoin.Checked -and $chkHtDoubleLoot.Checked)
    '_continueSweepOnly' = 'true면 은동전이 10~19개(더블 루팅 불가, 소탕은 가능)일 때 더블 루팅만 끄고 소탕(10개)으로 계속합니다. 10개 미만이면 옵션과 무관하게 사냥터에서 나가고 자동화를 마칩니다'
    continueSweepOnly   = [bool]($chkHtCoin.Checked -and $chkHtDoubleLoot.Checked -and $chkHtLootFallback.Checked)
    matching     = $(if ($rbHtDirect.Checked) { '바로 입장' } else { '파티찾기' })
  }
  if ($cfg.PSObject.Properties['huntingGround']) { $cfg.huntingGround = $htSettings }
  else { $cfg | Add-Member -NotePropertyName 'huntingGround' -NotePropertyValue $htSettings }
  $abyssMatchingValue = '우연한 만남'
  if ($rbAbyssFindParty.Checked) { $abyssMatchingValue = '파티찾기' }
  elseif ($rbAbyssPartyLead.Checked) { $abyssMatchingValue = '파티(파티장)' }
  elseif ($rbAbyssPartyMember.Checked) { $abyssMatchingValue = '파티(파티원)' }
  if ($cfg.PSObject.Properties['dungeons']) {
    $cfg.dungeons.selected = $dungeonName
    if ($cfg.dungeons.PSObject.Properties['mode']) { $cfg.dungeons.mode = $modeValue }
    else { $cfg.dungeons | Add-Member -NotePropertyName 'mode' -NotePropertyValue $modeValue }
    if ($cfg.dungeons.PSObject.Properties['difficulty']) { $cfg.dungeons.difficulty = $difficultyValue }
    else { $cfg.dungeons | Add-Member -NotePropertyName 'difficulty' -NotePropertyValue $difficultyValue }
    if ($cfg.dungeons.PSObject.Properties['matching']) { $cfg.dungeons.matching = $abyssMatchingValue }
    else { $cfg.dungeons | Add-Member -NotePropertyName 'matching' -NotePropertyValue $abyssMatchingValue }
    # 과도기 버전이 남긴 partyState 키는 더 이상 쓰지 않으므로 제거합니다 (매칭에 통합)
    if ($cfg.dungeons.PSObject.Properties['partyState']) { $cfg.dungeons.PSObject.Properties.Remove('partyState') }
    if ($cfg.dungeons.PSObject.Properties['_partyState']) { $cfg.dungeons.PSObject.Properties.Remove('_partyState') }
    # 세 던전 모두 전체 자동화(full)로 보정합니다 (구버전 config 의 detail 값도 갱신)
    try {
      foreach ($profileName in @($cfg.dungeons.profiles.PSObject.Properties.Name)) {
        $profileNode = $cfg.dungeons.profiles.$profileName
        if ($profileNode.PSObject.Properties['stage']) {
          $profileNode.stage = 'full'
        } else {
          $profileNode | Add-Member -NotePropertyName 'stage' -NotePropertyValue 'full'
        }
      }
    } catch { }
  } else {
    # 예전 config 에는 dungeons 항목이 없으므로 기본 프로파일과 함께 새로 만듭니다
    $defaultProfiles = [pscustomobject]@{
      '허상의 정박지' = [pscustomobject]@{ card = @(956, 157); stage = 'full'; match = '정박' }
      '광기의 동굴'   = [pscustomobject]@{ card = @(956, 272); stage = 'full'; match = '광기' }
      '흩어진 물길'   = [pscustomobject]@{ card = @(956, 387); stage = 'full'; match = '물길' }
    }
    $cfg | Add-Member -NotePropertyName 'dungeons' -NotePropertyValue ([pscustomobject]@{
        selected   = $dungeonName
        mode       = $modeValue
        difficulty = $difficultyValue
        matching   = $abyssMatchingValue
        profiles   = $defaultProfiles
      })
  }
  # 커스텀 반복 설정도 같은 config 객체에 함께 동기화합니다 (progress 는 보존 -
  # 별도 Read/Save 를 하면 아래 Save-Config 가 되돌려 덮어쓰므로 반드시 이 객체에 병합)
  Set-CustomRepeatOnConfig -Config $cfg
  Set-AbyssCustomRepeatOnConfig -Config $cfg
  Set-DeepCustomRepeatOnConfig -Config $cfg
  Set-LifeCustomRepeatOnConfig -Config $cfg

  try {
    Save-Config $cfg
  } catch {
    Add-GuiLog "[오류] config.json 저장 실패: $($_.Exception.Message)"
    return $false
  }
  return $true
}

function Set-UiRunning {
  param([bool]$IsRunning)
  # 실행 시작 시 진행 중 슬라이드 정리 (상세 Enabled 스냅샷이 오버레이/잠금 상태를 뜨지 않게 -
  # 리뷰 권고. 생활에서는 시작이 차단되지만 향후 생활 실행 대비 방어).
  # 일반 Stop(UI 복원 포함)이어야 함 - SkipUiRefresh 면 화살표 false 가 스냅샷에 저장돼
  # 실행 종료 후 영구 비활성 (리뷰 지적)
  if ($IsRunning -and $script:lifeSlideActive) { Stop-LifeSlideNow }
  $script:running = $IsRunning
  # 랜덤 진행 표시 복원 - 모든 정지 경로가 이 함수를 지나므로 여기서 한 번에 처리
  if (-not $IsRunning) { Restore-CustomListRegisteredView }
  # 시작 버튼은 '미실행 + 사용 승인'의 합성 조건 (실행 종료 후에도 미승인이면 잠금 유지)
  $btnStart.Enabled = (-not $IsRunning) -and (Test-ApprovalAllowsStart)
  # 대분류(전투/생활) 전환은 실행 중 잠금 - 전투 실행 중 생활 화면으로 바뀌면 상세/설정
  # 표시가 실행 내용과 어긋남 (리뷰 조건 C. 미승인 시 잠금은 Update-ApprovalUi 담당)
  $btnCatBattle.Enabled = (-not $IsRunning) -and (Test-ApprovalAllowsStart)
  $btnCatLife.Enabled = (-not $IsRunning) -and (Test-ApprovalAllowsStart)
  $btnCatEtc.Enabled = (-not $IsRunning) -and (Test-ApprovalAllowsStart)
  $btnSafeStop.Enabled = $IsRunning
  $btnKill.Enabled = $IsRunning
  # 대기 중에는 시작만, 실행 중에는 중지 2개만 표시 (시작 자리에 중지가 나타남 - 오클릭 방지)
  $btnStart.Visible = -not $IsRunning
  $btnSafeStop.Visible = $IsRunning
  $btnKill.Visible = $IsRunning
  $grpRepeat.Enabled = -not $IsRunning
  $grpContent.Enabled = -not $IsRunning
  # 콘텐츠 상세는 그룹 통째 잠금이 아니라 '자식 개별 잠금': 커스텀 리스트 3개는 실행 중에도
  # 살려 둬 스크롤로 진행 항목을 볼 수 있게 합니다 (2026-08-04 사용자 요청 - WinForms 는
  # 부모 비활성 시 자식 스크롤까지 죽음). 편집은 별도 가드가 전부 차단: 셀 편집/콤보(기존
  # running 가드) + 머리글 전체 토글·체크 토글(running 가드 추가). 스냅샷을 떠서 복원하는
  # 이유: 조건부 Enabled 자식(주간 카드 연동 구역 콤보 등)의 상태 보존. 스냅샷 존재 여부가
  # 전이 토큰이라 중복 호출(true→true 등)에도 원상태가 유실되지 않습니다 (설계 합의 계약).
  if ($IsRunning -and $null -eq $script:contentDetailEnabledSnapshot) {
    $detailSnapshot = @{}
    $scrollableLists = @($lvCrList, $lvAcrList, $lvDcrList, $lvLcrList)
    foreach ($detailChild in $grpContentDetail.Controls) {
      if ($scrollableLists -contains $detailChild) { continue }
      $detailSnapshot[$detailChild] = [bool]$detailChild.Enabled
    }
    # 전부 캡처한 뒤 별도 루프로 비활성 (Enabled 게터는 조상 상태가 반영된 유효값 - 리뷰 지적)
    $script:contentDetailEnabledSnapshot = $detailSnapshot
    foreach ($detailChild in @($detailSnapshot.Keys)) { $detailChild.Enabled = $false }
  } elseif ((-not $IsRunning) -and $null -ne $script:contentDetailEnabledSnapshot) {
    foreach ($detailEntry in $script:contentDetailEnabledSnapshot.GetEnumerator()) {
      if (-not $detailEntry.Key.IsDisposed) { $detailEntry.Key.Enabled = [bool]$detailEntry.Value }
    }
    $script:contentDetailEnabledSnapshot = $null
  }
  if ($IsRunning) {
    # 실행 시작 시: 커밋된(적용 대기) 편집은 즉시 완료하고, 미커밋 편집만 폐기합니다
    # (리뷰 지적 - 사용자가 고른 값이 실행 직전에 유실되지 않게)
    $pendingCellEdit = $script:cellEditContext
    if ($pendingCellEdit -and [bool]$pendingCellEdit.Applied) {
      Invoke-CellEditApply
    } else {
      $script:cellEditContext = $null
    }
    Hide-CellEditCombo
  }
}

function Get-CycleWaitSecondsForEstimate {
  # 시간 지정 판단에 쓸 '한 사이클 예상 상한' - 대분류별 설정을 따릅니다
  # (생활에서 숨겨진 전투 클리어 대기값을 참조하면 목표 시각을 크게 넘기거나 잘못 거부 - 리뷰)
  if ($script:mainCategory -eq 'life') { return [int]$numGatherWait.Value }
  return [int]$numClearWait.Value
}

function Test-TimeAllowsNextCycle {
  # 시간 지정 모드에서 "지금 시작하면 목표 시각 안에 끝날 수 있는지" 판단합니다.
  # 판단 기준: 현재 시각 + 대분류별 사이클 상한(전투=클리어 대기/생활=진행 없음 한도) <= 목표 시각
  if ($null -eq $script:targetTime) { return $true }
  $estimatedEnd = (Get-Date).AddSeconds((Get-CycleWaitSecondsForEstimate))
  return ($estimatedEnd -le $script:targetTime)
}

function Move-WorkerLogToArchive {
  param(
    [string]$Path,
    [string]$Suffix = ''
  )

  if (-not (Test-Path -LiteralPath $Path)) { return [long]0 }
  try {
    $archiveStamp = (Get-Item -LiteralPath $Path -ErrorAction Stop).LastWriteTime.ToString('yyyyMMdd_\hHH\mmm\sss')
    $archivePath = Join-Path $honeyLogDir ("run_{0}{1}.log" -f $archiveStamp, $Suffix)
    Move-Item -LiteralPath $Path -Destination $archivePath -Force -ErrorAction Stop
    return [long]0
  } catch {
    # 외부 프로그램이 파일을 잠갔으면 과거 내용은 GUI에 다시 표시하지 않고, 워커가 기본 로그를
    # 열 수 없을 때 사용할 복구 로그를 별도로 감시합니다.
    try { return [long](Get-Item -LiteralPath $Path -ErrorAction Stop).Length }
    catch { return [long]0 }
  }
}

function Start-NextCycle {
  $cycleNumber = $script:completedCycles + 1
  # 지난 세션(또는 직전 회차)의 로그 파일이 남아 있으면, 워커가 새로 쓰기 전에
  # GUI 타이머가 그 내용을 '새 로그'로 착각해 화면에 다시 출력합니다.
  # 워커 시작 전에 파일을 치워 과거 로그가 다시 뜨지 않게 하되, 그냥 지우지 않고
  # run_시각.log 로 보관해 지난 회차 로그를 최근 10개까지 남깁니다 (오류 세트 보관 개수와 동일).
  # 시각은 읽기 쉽게 h/m/s 표기를 씁니다 (예: run_20260718_h21m49s09.log).
  $script:logOffset = Move-WorkerLogToArchive -Path $workerLog
  $script:recoveryLogOffset = Move-WorkerLogToArchive -Path $workerRecoveryLog -Suffix '_recovery'
  # 보관 개수(10개) 초과분은 오래된 것부터 삭제 (정리는 파일명이 아니라 수정 시각 기준이라
  # 옛 형식과 복구 로그가 섞여 있어도 함께 정리됩니다)
  $oldRunLogs = @(Get-ChildItem -Path $honeyLogDir -Filter 'run_*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip 10)
  foreach ($oldLog in $oldRunLogs) { Remove-Item -LiteralPath $oldLog.FullName -Force -ErrorAction SilentlyContinue }
  $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $workerScript + '"'))
  # 반복 모드와 앱 버전은 config에 없는 GUI 쪽 정보라 환경변수로 워커에 전달합니다.
  # 워커가 이 값을 로그 파일의 [설정] 스냅샷(화면 미표시)에 함께 기록합니다.
  $env:HONEYNOGI_APP_VERSION = $appVersion
  $customContext = $null
  if ($script:customActive) {
    $customContext = Get-CustomCurrentContext
    if (-not $customContext) {
      # 실행 중에는 리스트 편집이 비활성이라 정상 경로에선 없지만, config 읽기 실패 등 방어
      Add-GuiLog '[오류] 커스텀 반복 정보를 config 에서 읽지 못해 정지합니다.'
      Stop-AllRun -IsError '커스텀 반복 정보 읽기 실패'
      return
    }
  }
  if ($customContext) {
    # 커스텀 반복: 워커 실행 환경변수 세트 (HONEYNOGI_CUSTOM_ITEM 존재 = 워커 커스텀 모드)
    $env:HONEYNOGI_CUSTOM_ITEM = Format-CustomItemToken -Item $customContext.Item
    $env:HONEYNOGI_CUSTOM_PREV = $script:customPrevItem
    # 다음 항목(리스트 순환) - 워커가 결과 화면에서 '다시 하기'(다음도 같은 구역) vs
    # '나가기 → 선택 화면'(다른 구역)을 결정하는 데 씁니다. 다시 하기로 온 옵션 화면에는
    # 좌상단 '<' 가 없다는 실측(2026-07-20) 때문에 회차 마무리 시점에 갈림길을 정해야 합니다.
    # 1항목 리스트면 다음 = 자기 자신(같은 구역) → 기존처럼 다시 하기.
    # 랜덤 진행 주의: 바퀴 마지막 항목의 NEXT 는 '현재 순열의 첫 항목'입니다 (다음 바퀴의 새
    # 순열이 아님). 랜덤은 같은 층 전용 + 워커가 NEXT 를 마무리 갈림길에만 쓰는 불변식 덕에
    # 동작상 안전 - 혼합 랜덤을 허용하거나 워커가 NEXT 항목을 실제 소비하게 되면 다음 바퀴
    # 순열을 미리 계산해야 합니다 (리뷰 계약, test_custom_random 가드).
    $customNextIndex = ($customContext.Index + 1) % [Math]::Max(1, [int]$customContext.Total)
    $env:HONEYNOGI_CUSTOM_NEXT = Format-CustomItemToken -Item (@($customContext.ExecutionItems)[$customNextIndex])
    $env:HONEYNOGI_CUSTOM_RESTART = $(if ($script:customRestart) { '1' } else { '' })
    $env:HONEYNOGI_CUSTOM_RECOVERY = $(if ($script:customRecoveryPending) { '1' } else { '' })
    $env:HONEYNOGI_CUSTOM_POSITION = $customContext.Position
    $env:HONEYNOGI_CUSTOM_LIST = $(if ($script:customConfigSection -eq 'lifeCustomRepeat') {
        # 생활은 펼친 실행 목록이 아니라 '등록 목록'을 기록합니다 (같은 항목이 count 개
        # 늘어선 줄이 아니라 사용자가 짠 리스트 그대로여야 제보 로그를 읽을 수 있음)
        Get-LifeCustomListCompact -Items $customContext.Items
      } elseif ($script:customConfigSection -eq 'deepCustomRepeat') {
        Get-DeepCustomListCompact -Items $customContext.ExecutionItems
      } else { Get-CustomListCompact -Items $customContext.ExecutionItems })
    $env:HONEYNOGI_CUSTOM_OWNER = New-CustomMarkerOwnerJson -Context $customContext
    $repeatModeText = $(if ($customContext.ListRepeat -eq 'count') { "$($customContext.ListRepeatCount)바퀴" } else { '무한' })
    $env:HONEYNOGI_REPEAT_INFO = "커스텀 반복(항목 $($customContext.Total)개, $($customContext.Lap)바퀴째 $($customContext.Index + 1)번, $repeatModeText)"
    # 마지막 판 신호: N바퀴 모드의 마지막 바퀴 마지막 항목이면 워커가 결과 화면에서
    # '나가기'로 필드에 나가며 마칩니다 (마무리 복구 회차도 같은 컨텍스트로 자연 판정)
    $env:HONEYNOGI_LAST_RUN = $(if (Test-CustomLastRun -ListRepeat ([string]$customContext.ListRepeat) `
        -ListRepeatCount ([int]$customContext.ListRepeatCount) -Lap ([int]$customContext.Lap) `
        -Index ([int]$customContext.Index) -Total ([int]$customContext.Total)) { '1' } else { '' })
    # 랜덤 진행: 리스트를 이번 바퀴 순서로 표시 (순열이 같으면 하이라이트만 이동)
    Set-CustomListRandomView -Context $customContext
    # 일반 회차는 이전 마커를 삭제하고 시작합니다. 마무리 복구 회차는 현재 항목이 이미 클리어됐다는
    # 근거이자 GUI 재시작 복구 정보이므로 같은 소유자의 마커를 보존합니다.
    # 일반 회차에서 삭제 실패(파일 잠금 등) 시에는 이번 회차 마커를 무시해 오계상을 막습니다.
    #
    # 마커와 묘비(.stale)를 **한 계약**(Clear-CustomMarkerFile)으로 정리합니다. 예전처럼
    # 마커만 직접 지우면 묘비가 남고, 이번 회차 워커가 같은 경로에 기록한 **정상** 마커를
    # 나중에 시작 게이트가 묘비만 보고 지워버립니다 → 복구했어야 할 판을 다시 돌아 재화
    # 이중 소모 (2026-08-09 리뷰 적발). Test-Path 로 감싸지 않는 이유도 같습니다 -
    # 마커가 이미 없어도 남은 묘비는 여기서 치워야 합니다.
    $script:customMarkerIgnore = $false
    if (-not $script:customRecoveryPending) {
      if (-not (Clear-CustomMarkerFile -Path $customMarkerFile)) {
        Add-GuiLog '[경고] 이전 완료 마커 파일을 정리하지 못했습니다 - 이번 회차는 마커를 무시합니다 (완료 계상은 정상 종료 코드로만).'
        $script:customMarkerIgnore = $true
      }
    }
    # 정리에 실패한 회차에는 워커에게 **마커 경로를 주지 않습니다**(빈 값 = 기록 안 함,
    # 워커 Write-CustomClearMarker 가 빈 경로면 즉시 return). 경로를 주면 묘비가 남은 채
    # 워커가 같은 경로에 '정상' 마커를 기록하고, 다음 시작 게이트가 묘비만 보고 그 정상
    # 마커를 지워 복구했어야 할 판을 다시 돌게 됩니다 (2026-08-09 재점검 적발).
    # 반드시 위 정리 결과가 확정된 **뒤에** 설정해야 합니다.
    $env:HONEYNOGI_CUSTOM_MARKER = $(if ($script:customMarkerIgnore) { '' } else { $customMarkerFile })
  } else {
    # 비커스텀 회차: GUI 프로세스에 잔존한 커스텀 환경변수를 정리합니다
    # (남으면 어비스/사냥터 워커가 커스텀 모드로 오동작 - Clear-CustomEnv 주석 참고)
    Clear-CustomEnv
    $env:HONEYNOGI_REPEAT_INFO = if ($null -ne $script:targetTime) {
      "시간 지정(~$($script:targetTime.ToString('MM-dd HH:mm')))"
    } elseif ($script:targetCycles -gt 0) {
      "횟수 지정(${cycleNumber}/$($script:targetCycles)회차)"
    } else { '무한 반복' }
    # 마지막 판 신호: 횟수 지정의 마지막 회차만. 시간 지정/무한은 마지막을 사전에 알 수 없어
    # 기존(옵션 화면 잔류) 그대로입니다. (Clear-CustomEnv 가 이전 값을 지웠으므로 명시 설정)
    $env:HONEYNOGI_LAST_RUN = $(if (($null -eq $script:targetTime) -and ($script:targetCycles -gt 0) -and
        ($cycleNumber -ge $script:targetCycles)) { '1' } else { '' })
  }
  # 시간 지정 모드(생활): 목표 시각을 워커에 전달합니다 - 워커가 사이클 **중에도** 도달 시
  # 스스로 멈춥니다 (2026-08-11 실측 ①: GUI 는 사이클이 끝나야 시간을 봐서 목표를 2분 24초
  # 넘김. 사이클 길이는 이동 거리로 크게 흔들려 예측 불가가 실측됨 - 이슈 문서 참고).
  # 매 회차 **먼저 지우고** 조건(생활 + 시간 지정)일 때만 다시 설정합니다 - GUI 프로세스에
  # 남은 값이 다음 비시간/전투 회차 워커로 새는 것 방지 (커스텀 env 정리와 같은 이유).
  # 전투는 전달하지 않습니다 - 판 중간 정지 불가 + 전투 초과는 미실측 (규칙 8).
  # 전체 타임스탬프인 이유는 자정 넘김(23:50 에 00:30 지정) 모호성 방지입니다.
  $env:HONEYNOGI_UNTIL_TIME = ''
  if (($null -ne $script:targetTime) -and ($script:mainCategory -eq 'life')) {
    $env:HONEYNOGI_UNTIL_TIME = $script:targetTime.ToString('yyyy-MM-dd HH:mm')
  }
  # 이번 회차의 [완료] 사유 수집을 초기화합니다 (이전 회차 사유가 코드 4 상태줄에 오표시되는
  # 것 방지 - 리뷰 조건)
  $script:lastWorkerDoneReason = ''
  # 프로세스 생성 실패 시 UI 잠금·절전 방지가 복원되지 않던 문제 방어 (2026-08-01 전수 점검:
  # 종료 타이머 조건이 running && worker 라 worker 가 null 이면 자동 복구 경로가 없었음)
  try {
    if ($script:hostedExePath) {
      # 임베디드 호스트: 워커도 같은 exe(--run)로 - 작업 관리자에 '꿀비노기'로 표시됩니다.
      # exe 는 /target:winexe(창 없는 GUI 서브시스템)라 -WindowStyle 이 필요 없습니다.
      $script:worker = Start-Process -FilePath $script:hostedExePath -ArgumentList @(
        '--run', ('"' + $workerScript + '"')) -PassThru
    } else {
      $script:worker = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList $arguments -PassThru
    }
  } catch {
    $script:worker = $null
  }
  if (-not $script:worker) {
    Add-GuiLog '[경고] 자동화 프로세스를 시작하지 못했습니다 - 실행 상태를 되돌립니다. 잠시 후 다시 시작해 주세요.'
    Stop-AllRun -IsError -Reason '워커 시작 실패'
    return
  }
  if ($customContext) {
    $lblStatus.Text = "커스텀: $($customContext.Position) 실행 중"
  } else {
    $statusSuffix = ''
    if ($null -ne $script:targetTime) { $statusSuffix = " ($($script:targetTime.ToString('HH:mm')) 까지)" }
    $lblStatus.Text = "${cycleNumber}회차 실행 중...$statusSuffix"
  }
  $lblStatus.ForeColor = [System.Drawing.Color]::ForestGreen
  if ($customContext) {
    Add-GuiLog "=== ${cycleNumber}회차 시작($($customContext.Index + 1)/$($customContext.Total)) ==="
    # 생활은 항목마다 반복 횟수가 있어 '리스트 몇 번째 / 그 항목의 몇 번째 사이클'을 함께
    # 보여 줍니다 (던전은 항목 1개 = 1판이라 위 줄만으로 충분)
    if ($script:customConfigSection -eq 'lifeCustomRepeat') {
      $lifeStartItem = $customContext.Item
      $lifeStartRep = 1; $lifeStartRepAll = 1
      try { $lifeStartRep = [int]$lifeStartItem.rep } catch { $lifeStartRep = 1 }
      try { $lifeStartRepAll = [int]$lifeStartItem.repTotal } catch { $lifeStartRepAll = 1 }
      Add-GuiLog ('[커스텀] {0}/{1} {2} - {3} ({4}/{5}회)' -f
        ([int]$customContext.RegisteredIndex + 1), [int]$customContext.RegisteredTotal,
        (Get-LifeSkillNameById -Id ([string]$lifeStartItem.skill)), [string]$lifeStartItem.target,
        $lifeStartRep, $lifeStartRepAll)
    }
  } else {
    Add-GuiLog "=== ${cycleNumber}회차 시작 ==="
  }
}

function Stop-AllRun {
  # IsError: 이 정지가 **오류**인지(빨강 + 오류 배지) 정상/사용자 정지인지.
  # ★ 예전에는 사유를 태그 없이 `"중지: $Reason"` 으로만 남겼습니다. 그러면 심각도가
  #   '실패' 라는 낱말로 정해져, **정상 조건 정지(코드 4)의 사유에 '실패'가 들어가면
  #   빨강 오류로 뜨고** 반대로 진짜 오류 정지의 사유에 그 낱말이 없으면 회백색이 됐습니다.
  #   5~7차가 워커 로그에서 없앤 '정직하게 쓸수록 오류 배지가 부푸는' 구조가 GUI 자기
  #   메시지 쪽에 그대로 남아 있던 것입니다 (2026-08-10 8차 점검).
  #   → 호출부가 아는 사실(오류인가)로 태그를 정합니다. 기본은 정상 정지입니다.
  param([string]$Reason, [switch]$IsError)
  $wasCustom = $script:customActive
  $workerToDispose = $script:worker
  if ($workerToDispose) {
    # Kill 실패/미종료 시 재시도 + 잔존 경고 (2026-08-01 전수 점검 + 3차 리뷰: 첫 대기가
    # 무기한 WaitForExit() 라 종료 신호가 안 오면 GUI 전체가 멈추고 재시도에도 못 갔음 -
    # 타임아웃 대기로 바꾸고, 종료가 '확인된 경우에만' workerWasKilled 를 세움. 리뷰 조건)
    $workerWasKilled = $false
    $killTryFailed = $false
    try {
      if (-not $workerToDispose.HasExited) {
        $workerToDispose.Kill()
        if ($workerToDispose.WaitForExit(10000)) { $workerWasKilled = $true } else { $killTryFailed = $true }
      }
    } catch { $killTryFailed = $true }
    if ($killTryFailed) {
      try {
        if (-not $workerToDispose.HasExited) {
          $workerToDispose.Kill()
          if ($workerToDispose.WaitForExit(3000)) { $workerWasKilled = $true }
        } else { $workerWasKilled = $true }
      } catch { }
      $workerStillAlive = $false
      try { $workerStillAlive = (-not $workerToDispose.HasExited) } catch { }
      if ($workerStillAlive) {
        Add-GuiLog '[경고] 자동화 프로세스를 종료하지 못했습니다 - 게임 조작이 계속되면 작업 관리자에서 powershell 프로세스를 직접 종료해 주세요.'
      }
    }
    try { $workerToDispose.Dispose() } catch { }
    $script:worker = $null
    if ($workerWasKilled) {
      # Kill 시점이 키/마우스 '누름-뗌' 사이였을 수 있으므로 입력 상태를 정리합니다
      Release-StuckInput
    }
  }
  $script:worker = $null
  Set-UiRunning $false
  $script:stopRequested = $false
  $script:targetTime = $null
  $btnSafeStop.Text = ("안전 중지(F9)" + [Environment]::NewLine + "(회차 완료 후)")
  Remove-Item -LiteralPath $safeStopFlag -Force -ErrorAction SilentlyContinue
  # 화면 유지 신호 해제 (평소 절전 설정으로 복귀)
  [Win32.PowerState]::SetThreadExecutionState($script:esRelease) | Out-Null
  if ($wasCustom) {
    # 커스텀 정지 상태줄: '완료: N바퀴 M항목(통산 K판)'. progress 는 '다음에 실행할' 위치이므로
    # 완료량 = (lap-1)바퀴 + index 항목. 완주 정지로 progress 가 지워졌으면 'N바퀴 완료' 표기.
    # 여기서는 progress 를 읽기만 하고 절대 쓰지 않습니다 (즉시 중지/강제 종료 = 진행 무변경 원칙).
    $doneText = "통산 $($script:completedCycles)판"
    try {
      $cfgStop = Read-Config
      $nodeStop = $null
       if ($cfgStop -and $cfgStop.PSObject.Properties[$script:customConfigSection]) { $nodeStop = $cfgStop.$script:customConfigSection }
      $progressStop = $null
      if ($nodeStop -and $nodeStop.PSObject.Properties['progress'] -and $nodeStop.progress) { $progressStop = $nodeStop.progress }
      if ($progressStop) {
        $lapDone = [int]$progressStop.lap - 1
        $itemDone = [int]$progressStop.index
        $doneText = "완료: ${lapDone}바퀴 ${itemDone}항목(통산 $($script:completedCycles)판)"
      } elseif ($nodeStop -and [string]$nodeStop.listRepeat -eq 'count' -and $script:completedCycles -gt 0) {
        $lapTarget = 1
        try { $lapTarget = [int]$nodeStop.listRepeatCount } catch { }
        $doneText = "${lapTarget}바퀴 완료(통산 $($script:completedCycles)판)"
      } else {
        $doneText = "완료: 0바퀴 0항목(통산 $($script:completedCycles)판)"
      }
    } catch { }
    $lblStatus.Text = "중지됨 - $Reason ($doneText)"
    # 커스텀 실행 컨텍스트/환경변수 정리 (다음 비커스텀 실행이 커스텀으로 오동작하는 사고 방지)
    Clear-CustomEnv
    $script:customActive = $false
  } else {
    $lblStatus.Text = "중지됨 - $Reason (완료: $($script:completedCycles)회)"
  }
  $lblStatus.ForeColor = [System.Drawing.Color]::DimGray
  Add-GuiLog "$(if ($IsError) { '[오류]' } else { '[중단]' }) 중지: $Reason"
}

# --- 타이머: 워커 상태 + 로그 tail ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 600
$timer.Add_Tick({
    try {
    # 워커 로그 tail
    if ($script:running) {
      # @() 는 필수입니다. 함수의 배열 반환은 PS 5.1 파이프라인에서 풀리므로, 새 줄이
      # **딱 1줄**인 틱에서는 $lines 가 문자열이 됩니다. 그러면 $lines.Count 는 1(스칼라)
      # 이고 $lines[0] 은 그 줄의 **첫 글자**('1' 같은 시각 첫 자리)라, 그 줄이 통째로
      # 사라지고 [완료] 사유 수집도 함께 실패했습니다 (2026-08-09 감사 적발).
      # 인덱스 대신 foreach 로 돌면 같은 계열이 재발해도 문자열 순회로 드러납니다.
      $lines = @(Read-NewLogLines -Path $workerLog -Offset ([ref]$script:logOffset))
      foreach ($logLine in $lines) {
        # 읽기 실패는 $null 반환이고 @($null) 은 원소 1개짜리 배열이라 여기서 걸러냅니다
        if ($null -eq $logLine) { continue }
        # 코드 4 상태줄용 실제 사유 수집 (범용 '공물 소진 등' 문구가 실제 이유와 달라
        # 사용자가 오해한 실사례 - 2026-08-02, 리뷰 승인)
        if ($logLine -match '\[완료\]\s*(.+)') { $script:lastWorkerDoneReason = $Matches[1].Trim() }
        $displayLine = Convert-WorkerLogLineForGui -Line $logLine -CustomActive $script:customActive
        if ($null -eq $displayLine) { continue }
        Add-ColoredLogLine ('  ' + $displayLine)
      }
      # 기본 로그가 이미 잠긴 상태에서 시작했거나 쓰기 스트림에 장애가 생긴 경우 워커는
      # 복구 로그로 전환합니다. 기본 로그의 마지막 오프셋 이후 내용을 이어서 화면에 표시합니다.
      $recoveryLines = @(Read-NewLogLines -Path $workerRecoveryLog -Offset ([ref]$script:recoveryLogOffset))
      foreach ($recoveryLine in $recoveryLines) {
        if ($null -eq $recoveryLine) { continue }
        if ($recoveryLine -match '\[완료\]\s*(.+)') { $script:lastWorkerDoneReason = $Matches[1].Trim() }
        $displayLine = Convert-WorkerLogLineForGui -Line $recoveryLine -CustomActive $script:customActive
        if ($null -eq $displayLine) { continue }
        Add-ColoredLogLine ('  ' + $displayLine)
      }
      if ($txtLog.TextLength -gt 200000) {
        $txtLog.Text = $txtLog.Text.Substring($txtLog.TextLength - 100000)
        $txtLog.SelectionStart = $txtLog.TextLength
        # Text 교체 후 확대 배율이 초기화될 수 있어 다시 적용합니다
        $txtLog.ZoomFactor = [float]([int]$numFontSize.Value / 9.0)
      }
    }

    # 워커 종료 처리
    if ($script:running -and $script:worker -and $script:worker.HasExited) {
      $finishedWorker = $script:worker
      $exitCode = 1
      try { $exitCode = $finishedWorker.ExitCode }
      catch { Add-GuiLog "[오류] 워커 종료 코드를 읽지 못했습니다: $($_.Exception.Message)" }
      finally {
        try { $finishedWorker.Dispose() } catch { }
        $script:worker = $null
      }
      # '연속 준비 실행' 카운터는 코드 10 이 아닌 모든 종료에서 초기화합니다 (2026-08-01 전수
      # 점검: 기존에는 코드 0 에서만 초기화해 10→1(재시작)→10→1→10 교차도 '3회 연속'으로 오판)
      if ($exitCode -ne 10) { $script:preparedStreak = 0 }
      if ($exitCode -eq 0) {
        $script:completedCycles++
        $finishedContext = $null
        if ($script:customActive) {
          $finishedContext = Get-CustomCurrentContext
          # 복구 회차는 아래의 전용 성공 문구만 표시합니다. 정상 회차는 바퀴/항목 위치로 완료를 표시합니다.
          if (-not $script:customRecoveryPending) {
            if ($finishedContext) { Add-GuiLog "[커스텀] $($finishedContext.Position) 항목 완료" }
            else { Add-GuiLog "=== $($script:completedCycles)회차 완료 ===" }
          }
        } else {
          Add-GuiLog "=== $($script:completedCycles)회차 완료 ==="
        }
        if ($script:customActive) {
          # 커스텀 반복: 정상 판 또는 완료 후 마무리 복구가 코드 0에 도달한 시점에만 한 번 계상합니다.
          # 마커를 먼저 소비해 완주 정지/GUI 재시작에서도 같은 판을 다시 복구하지 않게 합니다.
          $wasRecovery = $script:customRecoveryPending
          $script:customErrorStreak = 0
          $script:customRestart = $false
          if ($finishedContext) { $script:customPrevItem = Format-CustomItemToken -Item $finishedContext.Item }
          $advanced = Step-CustomProgress
          if (-not $advanced) {
            # 완료 마커는 소비하지 않습니다. 다음 수동 시작에서 같은 소유 항목의 완료 사실을
            # 복구해 은동전 판을 다시 돌지 않게 합니다.
            $script:customRecoveryPending = $true
            $script:customRestart = $true
            Stop-AllRun -IsError '커스텀 진행 기록 저장 실패 - 중복 실행 방지를 위해 정지'
            $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
            return
          }
          $script:customRecoveryPending = $false
          # 삭제 실패 파일이 다음 수동 시작에서 유효 마커로 복구되지 않도록 소유자 형식을 무효화합니다.
          # 실패하면 묘비가 남고, 다음 회차 준비(Clear-CustomMarkerFile)가 다시 정리합니다.
          if (-not (Clear-CustomMarkerFile -Path $customMarkerFile)) {
            Add-GuiLog '[경고] 완료 마커 파일을 정리하지 못했습니다 - 다음 회차 시작 때 다시 정리합니다.'
          }
          if ($wasRecovery) {
            Add-GuiLog '[커스텀] 마무리 복구 완료 - 다음 항목으로 진행합니다.'
          }
          $lapComplete = $false
          if ($advanced -and $finishedContext) {
            # 완주 판정(GUI 담당): 전진 '후' lap 이 목표를 넘는 순간 (lap 은 1 시작 - N=1 이면 전진 후 lap 2)
            $lapComplete = Test-CustomLapComplete -ListRepeat $finishedContext.ListRepeat `
              -ListRepeatCount $finishedContext.ListRepeatCount -Lap ([int]$advanced.lap)
          }
          if ($script:stopRequested) {
            # 안전 중지도 판 완료(코드 0)이므로 전진을 먼저 마친 뒤 정지합니다
            Stop-AllRun '안전 중지'
          } elseif ($lapComplete) {
            # 완주 정지 시점에 진행 기록 자동 삭제 - 다음 시작은 새 1바퀴부터 (요청사항 확정 스펙)
            if (Reset-CustomProgress) {
              Stop-AllRun '지정 바퀴 완료'
            } else {
              # 전진된 lap>N 진행은 디스크에 남아 다음 시작 게이트가 다시 초기화를 시도합니다.
              Stop-AllRun -IsError '지정 바퀴 완료 후 진행 초기화 저장 실패'
              $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
            }
          } else {
            Start-NextCycle
          }
        } else {
          $reachedTarget = ($script:targetCycles -gt 0 -and $script:completedCycles -ge $script:targetCycles)
          if ($script:stopRequested) {
            Stop-AllRun '안전 중지'
          } elseif ($reachedTarget) {
            Stop-AllRun '지정 횟수 완료'
          } elseif (-not (Test-TimeAllowsNextCycle)) {
            # 남은 시간이 클리어 대기 시간보다 짧으면 다음 회차를 시작하지 않습니다
            $targetText = $script:targetTime.ToString('HH:mm')
            Add-GuiLog "지정 시간($targetText)까지 남은 시간이 부족해 다음 회차를 시작하지 않습니다."
            Stop-AllRun "지정 시간($targetText) 도달"
          } else {
            Start-NextCycle
          }
        }
      } elseif ($exitCode -eq 10) {
        # 준비 실행(화면 복귀만 수행, 던전 미실행): 회차로 세지 않고 곧바로 본 회차를 시작합니다.
        # 이렇게 해야 횟수 지정 모드에서 실제 던전 실행 횟수가 요청보다 적어지지 않습니다.
        $script:preparedStreak++
        Add-GuiLog '[안내] 화면 복귀(준비 실행)만 수행 - 회차로 세지 않고 이어서 시작합니다'
        if ($script:customActive) {
          # 커스텀: 전진 없음(미계상) - 같은 항목을 다시 실행합니다. 준비 실행이 화면을 옵션/선택
          # 화면까지 정리했으므로 PREV 를 비워 다음 회차가 '다시 하기' 경로 대신 선택 화면 절차를 밟게 함
          $script:customPrevItem = ''
          $script:customRestart = $false
        }
        if ($script:stopRequested) {
          Stop-AllRun '안전 중지'
        } elseif ($script:preparedStreak -ge 3) {
          # 화면 오판 등으로 준비 실행만 반복되는 무한 루프 방지 (레거시 컨트롤러와 동일한 상한)
          Stop-AllRun -IsError '준비 실행(화면 복귀)이 3회 연속 반복 - 게임 화면 상태를 확인해 주세요'
          $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
        } elseif (-not (Test-TimeAllowsNextCycle)) {
          $targetText = $script:targetTime.ToString('HH:mm')
          Stop-AllRun "지정 시간($targetText) 도달"
        } else {
          Start-NextCycle
        }
      } elseif ($exitCode -eq 2) {
        # 다른 인스턴스가 이미 실행 중(뮤텍스 충돌): 이중 조작을 피하기 위해 이 GUI는 멈춥니다
        Stop-AllRun -IsError '다른 자동화 인스턴스가 이미 실행 중 (중복 실행 방지) - 작업 관리자에서 powershell.exe(또는 꿀비노기)를 종료한 뒤 다시 시작해 주세요'
        $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
      } elseif ($exitCode -eq 3) {
        # 미개발 구간 도달: 구현된 데까지 완료하고 정상 정지 (오류 아님, 상세는 로그 참고)
        Stop-AllRun '구현된 구간까지 완료 - 정지 (자세한 내용은 로그 참고)'
        $lblStatus.ForeColor = [System.Drawing.Color]::SteelBlue
      } elseif ($exitCode -eq 4) {
        # 조건 충족에 의한 정상 정지 (예: 은동전 소진 + '소진 시 계속' 옵션 꺼짐)
        # 파일 존재가 아니라 **지금 항목의 유효한 소유자 마커**인지로 판단합니다
        # (무효화된 '{}' 잔존 파일을 완료로 오계상하던 구멍 - 2026-08-09 6차 점검)
        if ($script:customActive -and -not $script:customMarkerIgnore -and (Test-CustomMarkerValidForCurrent)) {
          # 커스텀 + 완료 마커: 클리어 확정(결과 화면 도달) 후 마무리 단계에서 조건 정지된 판이므로
          # 완료로 계상하고 전진한 '뒤' 정지합니다 (전진 없이 정지하면 다음 시작 때 같은 은동전 판을
          # 한 번 더 돌아 이중 소모 - 요청사항 확정 스펙)
          $script:completedCycles++
          $finishedContext = Get-CustomCurrentContext
          if ($finishedContext) { Add-GuiLog "[커스텀] $($finishedContext.Position) 항목 완료" }
          else { Add-GuiLog "=== $($script:completedCycles)회차 완료 ===" }
          if ($finishedContext) { $script:customPrevItem = Format-CustomItemToken -Item $finishedContext.Item }
          $stoppedProgress = Step-CustomProgress
          if (-not $stoppedProgress) {
            Stop-AllRun -IsError '조건 정지 판의 커스텀 진행 기록 저장 실패 - 완료 마커를 보존하고 정지'
            $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
            return
          }
          # 전진에 성공했으면 이 마커는 소임을 다했습니다. 남겨 두면 나중에 진행 기록이
          # 초기화될 때(업데이트 이전·진행 초기화 버튼) 마커가 progress 보다 앞선 상태가
          # 되어 '마무리 복구'가 잘못 발동합니다 (2026-08-09 감사 - 근본 원인 제거).
          # 삭제 확인 + '{}' 무효화 폴백은 코드 0 경로와 같은 계약입니다 (파일이 잠겨 삭제가
          # 실패해도 다음 시작에서 유효 마커로 부활하지 않게 함 - 리뷰 조건).
          if (-not (Clear-CustomMarkerFile -Path $customMarkerFile)) {
            Add-GuiLog '[경고] 완료 마커 파일을 정리하지 못했습니다 - 다음 시작 때 다시 정리합니다.'
          }
        }
        # 종료 직전 기록된 [완료] 사유를 놓치지 않게 잔여 로그를 한 번 더 수집합니다
        # (타이머 tail 과 종료 사이의 경쟁 방지 - 리뷰 조건)
        $finalLines = @()
        $finalLines += @(Read-NewLogLines -Path $workerLog -Offset ([ref]$script:logOffset))
        $finalLines += @(Read-NewLogLines -Path $workerRecoveryLog -Offset ([ref]$script:recoveryLogOffset))
        foreach ($finalLine in $finalLines) {
          if ($null -eq $finalLine) { continue }
          if ($finalLine -match '\[완료\]\s*(.+)') { $script:lastWorkerDoneReason = $Matches[1].Trim() }
          $displayLine = Convert-WorkerLogLineForGui -Line $finalLine -CustomActive $script:customActive
          if ($null -ne $displayLine) { Add-ColoredLogLine ('  ' + $displayLine) }
        }
        # 상태줄에 실제 정지 사유 표시 - 범용 문구('공물 소진 등')가 실제 이유와 달라 오해를
        # 만든 실사례(2026-08-02) 반영. 사유를 못 잡은 경우에만 기존 범용 문구 폴백
        $code4Reason = ''
        if ($script:lastWorkerDoneReason) {
          $code4Reason = ($script:lastWorkerDoneReason -replace '\s+', ' ').Trim()
          if ($code4Reason.Length -gt 80) { $code4Reason = $code4Reason.Substring(0, 80) + '…' }
          $code4Reason = "조건 정지: $code4Reason"
        } elseif ($script:mainCategory -eq 'etc') {
          $code4Reason = '조건 충족으로 정지 - 목표 냥코인 도달/화면 확인 등 (자세한 내용은 로그 참고)'
        } elseif ($script:mainCategory -eq 'life') {
          # 생활 폴백 - 숨겨진 전투 라디오(rbCatDeep 등)를 참조하면 엉뚱한 재화 문구 표시 (리뷰)
          $code4Reason = '조건 충족으로 정지 - 채집 시간 초과/미지원 항목 등 (자세한 내용은 로그 참고)'
        } elseif ($rbCatDeep.Checked) {
          $code4Reason = '조건 충족으로 정지 - 마족공물 소진 등 (자세한 내용은 로그 참고)'
        } else {
          $code4Reason = '조건 충족으로 정지 - 은동전 소진 등 (자세한 내용은 로그 참고)'
        }
        Stop-AllRun $code4Reason
        $lblStatus.ForeColor = [System.Drawing.Color]::SteelBlue
      } else {
        if ($script:customActive -and $exitCode -eq 1) {
          # 커스텀 오류(코드 1): 완료 마커가 있으면 진행도를 먼저 넘기지 않고 같은 항목의 마무리만
          # 복구합니다. 복구 워커가 코드 0으로 끝난 뒤 위 정상 분기에서 딱 한 번 전진합니다.
          # 마커가 없으면 같은 항목 전체를 2회까지 자동 재시작합니다.
          $markerExists = ($script:customRecoveryPending -or
            ((-not $script:customMarkerIgnore) -and (Test-CustomMarkerValidForCurrent)))
          $errorAction = Get-CustomErrorAction -MarkerExists $markerExists -ErrorStreak $script:customErrorStreak
          if ($errorAction -eq 'recover') {
            $script:customErrorStreak++
            $finishedContext = Get-CustomCurrentContext
            if ($finishedContext) { $script:customPrevItem = Format-CustomItemToken -Item $finishedContext.Item }
            $script:customRecoveryPending = $true
            $script:customRestart = $true
            if ($script:stopRequested) {
              Stop-AllRun '안전 중지'
            } else {
              Add-GuiLog '[커스텀] 이전 완료 항목의 마무리를 복구합니다.'
              Start-NextCycle
            }
          } elseif ($errorAction -eq 'retry') {
            $script:customErrorStreak++
            $script:customRecoveryPending = $false
            $script:customRestart = $true
            $script:customPrevItem = ''
            if ($script:stopRequested) {
              Stop-AllRun '안전 중지'
            } else {
              # ★ 태그는 [안내]가 아니라 [경고]입니다. 6차에서 '태그 우선'으로 바꾼 뒤로는
              #   태그가 정본이라, [안내]로 두면 '오류 종료'라는 낱말이 있어도 심각도가 0이 되어
              #   **로그 탭을 접어 둔 무인 운용에서 오류 배지가 0인 채로 워커가 계속 죽었다
              #   살아납니다.** 실제로 워커가 코드 1로 죽은 사실이므로 경고가 맞습니다
              #   (2026-08-10 8차 점검).
              Add-GuiLog "[경고] 오류 종료(코드 1) - 같은 항목을 자동 재시작합니다 (재시도 $($script:customErrorStreak)/2)"
              Start-NextCycle
            }
          } else {
            Stop-AllRun -IsError '오류 종료(코드 1) - 같은 항목 3회 연속 실패 (로그 확인)'
            $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
          }
        } else {
          Stop-AllRun -IsError "오류 종료(코드 $exitCode) - 로그 확인"
          $lblStatus.ForeColor = [System.Drawing.Color]::Firebrick
        }
      }
    }
    } catch {
      # 타이머 핸들러의 예외는 반드시 여기서 멈춰야 합니다 - 밖으로 나가면 PS 5.1 WinForms 가
      # 모달 오류 창을 띄워 메시지 루프가 정지하고, 무인 운용에서는 아무도 그 창을 못 닫습니다
      # (2026-08-10 10차 점검 - 실행으로 확인). 사유는 로그로 남기고 다음 틱에서 이어갑니다.
      try { Add-GuiLog "[오류] 내부 타이머(워커 감시) 처리 중 예외 - 자동화는 계속 시도합니다: $($_.Exception.Message)" } catch { }
    }
  })

# --- 버튼 이벤트 ---
function Invoke-StartAutomation {
  # [시작]의 실제 본문. 승인 게이트(아래 btnStart 핸들러)를 통과한 뒤에만 호출됩니다.
  # 함수로 분리한 이유: '새 자동화 시작 시 승인 검사' 스펙 - 클릭 시 비동기 조회를 먼저
  # 돌리고, 조회 완료 콜백(Complete-ApprovalCheck)이 승인 확인 후 이 함수를 호출합니다.
    # 생활 대분류 재검사 (리뷰 조건 D): 승인 조회가 비동기라 '전투에서 시작 → 조회 중
    # 생활로 전환 → 콜백이 여기 직접 호출'로 버튼 게이트가 우회될 수 있음 - 서두에서 차단
    if (Test-LifeStartBlocked) { return }
    # 생활 대분류 시작: 전투 하위 라디오(던전/커스텀 체크 등)는 복귀 대비로 Checked 가
    # 보존돼 있어, 게이트 없이는 던전 안내·커스텀 시작 경로가 그대로 실행됩니다
    # (2026-08-06 00:06 실기 제보: 생활 시작인데 혼합 리스트 안내가 표시됨)
    $isLifeStart = ($script:mainCategory -eq 'life')
    # 기타(2026-08-15): 커스텀 미지원 - 보존된 커스텀 라디오 Checked 가 전투 커스텀 시작
    # 경로를 타지 않게 가드합니다 (생활과 같은 이유)
    $isEtcStart = ($script:mainCategory -eq 'etc')
    # 생활 커스텀 (2026-08-08): 채집일 때만. 가공은 아직 리스트 자체가 없습니다
    # ('$isLifeStart -and 채집'이 아니라 채집 라디오를 직접 봐야 - 가공 화면에서는 커스텀
    #  라디오가 비활성이지만 Checked 는 보존될 수 있음)
    $isLifeCustomStart = ($isLifeStart -and $rbCustomRepeat.Checked -and $rbLifeGather.Checked)
    $isCustomStart = ($isLifeCustomStart -or
      ($rbCustomRepeat.Checked -and -not $rbCatHunting.Checked -and -not $isLifeStart -and -not $isEtcStart))
    $script:customConfigSection = $(if ($isLifeCustomStart) { 'lifeCustomRepeat' }
      elseif ($rbCatAbyss.Checked) { 'abyssCustomRepeat' }
      elseif ($rbCatDeep.Checked) { 'deepCustomRepeat' } else { 'customRepeat' })
    # 생활은 완료 마커를 쓰지 않습니다 (사이클 완료 = 종료 코드 0 하나로 확정 - 던전처럼
    # '클리어 후 마무리 중 종료'라는 중간 상태가 없음). 존재하지 않을 전용 경로를 줘서
    # 마커 검사들이 항상 '없음'으로 통과하게 합니다
    # 섹션 → 마커 매핑은 한 곳(Get-CustomMarkerFileForSection)에만 둡니다. 여기와 진행
    # 초기화·랜덤 토글이 각자 분기하다 갈라진 것이 08-09 감사에서 나온 마커 오삭제입니다.
    $script:customMarkerFile = Get-CustomMarkerFileForSection -SectionName $script:customConfigSection
    if ($isLifeStart) {
      Add-GuiLog '[안내] 채집 자동화: 캐릭터가 필드에 있으면 어디서든 시작할 수 있습니다 (사이클마다 메뉴부터 다시 진행).'
      if ($isLifeCustomStart) {
        Add-GuiLog '[안내] 생활 커스텀 반복: 리스트 순서대로 항목을 실행하며, 한 항목의 지정 횟수를 모두 끝낸 뒤 다음 항목으로 넘어갑니다.'
      }
    }
    if ($isEtcStart) {
      Add-GuiLog "[안내] 고양이 상인: '고양이 상인 뽑기' 화면을 열어 둔 상태로 시작하세요. 카드 구매에 골드가 실제로 소모됩니다."
      Add-GuiLog '[안내] 목표 냥코인에 도달하면 스스로 멈춥니다.'
    }
    if ($rbCatDungeon.Checked -and -not $isLifeStart -and -not $isEtcStart) {
      if ($isCustomStart) {
        # 커스텀 반복 시작 안내 (한 번만 표시: 열어 둔 던전 하나 / 우연한 만남 강제)
        Add-GuiLog '[안내] 커스텀 반복: 시작 시 열어 둔 던전 하나에서 리스트 순서대로 동작합니다.'
        Add-GuiLog "[안내] '커스텀 반복'은 설정과 무관하게 '우연한 만남'으로 진행합니다."
      } else {
        # 시작 화면 요구사항 안내: 던전은 구역 선택 화면(또는 진입 옵션/결과 화면)에서 시작해야 합니다
        Add-GuiLog '[안내] 던전 자동화: 원하는 던전의 구역 선택 화면(또는 진입 옵션 화면)을 열어 두고 시작하세요. 은동전 옵션을 켰다면 실제로 은동전이 소모됩니다.'
      }
    }
    if ($rbCatAbyss.Checked -and $isCustomStart) {
      Add-GuiLog '[안내] 어비스 커스텀 반복: 리스트 순서대로 항목을 한 판씩 실행합니다.'
    }
    if ($rbCatDeep.Checked -and -not $isLifeStart -and -not $isEtcStart) {
      if ($isCustomStart) {
        Add-GuiLog '[안내] 심층 커스텀 반복: 시작 시 열어 둔 심층던전 하나에서 리스트 순서대로 동작합니다 (난이도는 어려움 고정).'
        Add-GuiLog "[안내] '커스텀 반복'은 설정과 무관하게 '우연한 만남'으로 진행합니다."
      } else {
        Add-GuiLog '[안내] 심층던전 자동화: 원하는 심층던전의 구역 선택 화면(또는 진입 옵션 화면)을 열어 두고 시작하세요. 마족공물 옵션을 켰다면 실제로 공물이 소모됩니다.'
        if ($rbDdWeeklyVeryHard.Checked) {
          Add-GuiLog "[안내] '매우 어려움'은 주간 던전입니다 - 이번 주 매우 어려움 심층던전의 화면을 열어 두면 그 구역을 자동 채택해 반복합니다 (구역 설정 무시)."
        }
      }
    }
    if (-not (Test-Path -LiteralPath $workerScript)) {
      [System.Windows.Forms.MessageBox]::Show('mabinogi_run_once.ps1 을 찾지 못했습니다.', '오류') | Out-Null
      return
    }
    if (-not (Save-SettingsFromUi)) { return }
    # ----- 커스텀 반복 시작 게이트: 빈 리스트 거부 / 이어가기 지문 검사 / 완주 취급 / 컨텍스트 초기화 -----
    $script:customActive = $isCustomStart
    if ($script:customActive) {
      $crCfg = Read-Config
      $crNode = $null
      if ($crCfg -and $crCfg.PSObject.Properties[$script:customConfigSection]) { $crNode = $crCfg.$script:customConfigSection }
      $crItems = @()
      if ($crNode -and $crNode.PSObject.Properties['items']) { $crItems = @($crNode.items) }
      if ($crItems.Count -eq 0) {
        # 빈 리스트는 시작하지 않고 로그로만 안내 (GUI 팝업 금지 규칙)
        Add-GuiLog '[안내] 커스텀 반복 리스트가 비어 있습니다 - [추가] 버튼으로 항목을 추가한 뒤 시작해 주세요.'
        $script:customActive = $false
        return
      }
      # 전환 규칙 게이트: 게임에서 불가능한 층 전환(2층→1층, 1-3 아닌 1층→2층)이 리스트에
      # 있으면 시작을 거부합니다 (워커 v4 전환 설계가 같은 층/1-3→2층만 처리 가능 - 실측 근거는
      # Get-CustomTransitionIssues 주석). Save-SettingsFromUi 직후라 config 값 = UI 값입니다.
      $crGateRepeat = 'infinite'; $crGateLaps = 1
      try { if ($crNode.PSObject.Properties['listRepeat']) { $crGateRepeat = [string]$crNode.listRepeat } } catch { }
      try { if ($crNode.PSObject.Properties['listRepeatCount']) { $crGateLaps = [int]$crNode.listRepeatCount } } catch { }
      $crGateIssues = @()
      if ($script:customConfigSection -eq 'customRepeat' -or $script:customConfigSection -eq 'deepCustomRepeat') {
        # 심층도 같은 1층/2층 구역 지도 구조라 던전과 동일한 층 전환 규칙을 적용합니다
        $crGateIssues = @(Get-CustomTransitionIssues -Items $crItems -ListRepeat $crGateRepeat -ListRepeatCount $crGateLaps)
      }
      # 어비스 방식·매칭 통일 게이트: GUI 에서는 라디오 잠금으로 섞일 수 없지만 config 를 직접
      # 편집하면 섞인 리스트가 들어올 수 있어 시작을 거부하고 어떤 항목이 다른지 로그로 알립니다
      # (무인 운용 보호 - 팝업 없이 로그만).
      # 생활 미지원 스킬 게이트: [추가] 시점에서 이미 막지만 config 를 직접 편집하면 낚시가
      # 들어올 수 있습니다. 그 항목 차례에 반드시 멈추므로 시작 전에 거부합니다 (팝업 없이 로그만)
      if ($script:customConfigSection -eq 'lifeCustomRepeat') {
        $lcrGateBad = @()
        $lcrGateSeq = 0
        foreach ($lcrGateItem in @($crItems)) {
          $lcrGateSeq++
          if ($null -eq $lcrGateItem) { continue }
          if ($script:lifeSupportedSkillIds -notcontains [string]$lcrGateItem.skill) {
            $lcrGateBad += ('{0}번: {1}' -f $lcrGateSeq, (Get-LifeCustomItemLabel -Item $lcrGateItem))
          }
        }
        if ($lcrGateBad.Count -gt 0) {
          Add-GuiLog '[경고] 생활 커스텀 반복: 아직 지원하지 않는 채집 스킬이 리스트에 있어 시작할 수 없습니다 - 해당 항목을 삭제해 주세요.'
          foreach ($lcrGateLine in $lcrGateBad) { Add-GuiLog ('[경고] ' + $lcrGateLine) }
          $script:customActive = $false
          return
        }
      }
      if ($script:customConfigSection -eq 'abyssCustomRepeat') {
        $acrGateIssues = @(Get-AbyssMatchingIssues -Items $crItems)
        if ($acrGateIssues.Count -gt 0) {
          Add-GuiLog '[경고] 어비스 커스텀 반복: 리스트의 방식·매칭이 서로 달라 시작할 수 없습니다 - 리스트 전체가 같은 방식·매칭이어야 합니다.'
          foreach ($acrGateIssue in $acrGateIssues) {
            Add-GuiLog ('[경고] {0}번({1} 매칭 ''{2}''): {3}' -f $acrGateIssue.Index, $acrGateIssue.Mode, $acrGateIssue.Matching, $acrGateIssue.Reason)
          }
          Add-GuiLog '[안내] 리스트의 방식/매칭 칸을 클릭해 전체를 한 번에 바꾸거나, 리스트를 비우고 다시 추가해 주세요.'
          $script:customActive = $false
          return
        }
      }
      if ($crGateIssues.Count -gt 0) {
        Add-GuiLog '[경고] 커스텀 반복: 게임에서 불가능한 층 전환이 리스트에 있어 시작할 수 없습니다 - 아래 항목의 순서를 조정해 주세요.'
        # 팝업 안내 (2026-07-20 사용자 확정): 시작 버튼 클릭 즉답 팝업 - 팝업 금지 규칙의
        # 명시적 예외 (실행 중엔 시작 버튼이 숨겨져 있어 무인 운용을 막지 않음. CLAUDE.md 참고).
        # 위반이 많으면 앞 5건까지만 팝업에 담고 나머지는 로그로 확인하게 합니다.
        $crGateLines = @()
        $crGateWrapSeen = $false
        foreach ($crGateIssue in $crGateIssues) {
          $crGateWrapTag = $(if ([bool]$crGateIssue.Wrap) { ' [바퀴 순환: 마지막 → 첫 항목]' } else { '' })
          Add-GuiLog ('[경고] {0} → {1}{2}: {3}' -f $crGateIssue.From, $crGateIssue.To, $crGateWrapTag, $crGateIssue.Reason)
          if ([bool]$crGateIssue.Wrap) {
            $crGateWrapSeen = $true
            Add-GuiLog "[경고] 층이 섞인 혼합 리스트는 1바퀴 전용입니다 - 리스트 반복을 '횟수 1바퀴'로 바꿔 주세요."
          }
          if ($crGateLines.Count -lt 5) {
            $crGateLines += ('- {0} → {1}{2}' -f $crGateIssue.From, $crGateIssue.To, $crGateWrapTag)
            $crGateLines += ('  {0}' -f [string]$crGateIssue.Reason)
          }
        }
        $crGateText = "시작할 수 없습니다 - 게임에서 불가능한 층 전환이 리스트에 있습니다.`n`n" +
          ($crGateLines -join "`n")
        if ($crGateIssues.Count -gt 5) { $crGateText += "`n... 외 $($crGateIssues.Count - 5)건 (로그 참고)" }
        if ($crGateWrapSeen) {
          $crGateText += "`n`n층이 섞인 혼합 리스트는 1바퀴 전용입니다.`n리스트 반복을 '횟수 1바퀴'로 바꿔 주세요."
        } else {
          $crGateText += "`n`n항목의 순서를 조정한 뒤 다시 시작해 주세요."
        }
        [System.Windows.Forms.MessageBox]::Show($crGateText, '커스텀 반복 - 시작 불가',
          [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        $script:customActive = $false
        return
      }
      $crProgress = $null
      if ($crNode.PSObject.Properties['progress'] -and $crNode.progress) { $crProgress = $crNode.progress }
      if ($crProgress) {
        # 이어가기 안전장치: 리스트가 하나라도 바뀌었으면(지문 불일치) 무조건 처음부터 (요청사항 확정)
        $savedFingerprint = ''
        try { $savedFingerprint = [string]$crProgress.fingerprint } catch { }
        if ($savedFingerprint -ne (Get-CustomFingerprint -Items $crItems)) {
          if (-not (Reset-CustomProgress -LogMessage '[안내] 커스텀 반복: 리스트 변경 - 처음부터 시작합니다.')) {
            Add-GuiLog '[오류] 변경된 리스트의 진행 기록을 초기화하지 못해 시작하지 않습니다.'
            $script:customActive = $false
            return
          }
          $crProgress = $null
        }
      }
      if ($crProgress) {
        # 무한으로 돌다 N바퀴로 줄인 경우 등: 저장된 lap 이 이미 목표를 넘었으면 완주 취급 후 새 1바퀴
        $crListRepeat = 'infinite'; $crLapTarget = 1; $crLapNow = 1; $crIndexNow = 0
        try { if ($crNode.PSObject.Properties['listRepeat']) { $crListRepeat = [string]$crNode.listRepeat } } catch { }
        try { if ($crNode.PSObject.Properties['listRepeatCount']) { $crLapTarget = [int]$crNode.listRepeatCount } } catch { }
        try { $crLapNow = [int]$crProgress.lap } catch { }
        try { $crIndexNow = [int]$crProgress.index } catch { }
        if (Test-CustomLapComplete -ListRepeat $crListRepeat -ListRepeatCount $crLapTarget -Lap $crLapNow) {
          if (-not (Reset-CustomProgress -LogMessage '[안내] 커스텀 반복: 저장된 진행이 지정 바퀴를 이미 완주한 상태 - 새 1바퀴부터 시작합니다.')) {
            Add-GuiLog '[오류] 완주된 진행 기록을 초기화하지 못해 시작하지 않습니다.'
            $script:customActive = $false
            return
          }
        } else {
          # 생활은 '항목 x 횟수'를 펼친 개수가 총 칸 수라 표기도 그 기준이어야 합니다
          $crResumeTotal = $(if ($script:customConfigSection -eq 'lifeCustomRepeat') {
              @(Expand-LifeCustomItems -Items $crItems).Count } else { $crItems.Count })
          Add-GuiLog "[안내] 커스텀 반복: 저장된 진행을 이어갑니다 - $(Get-CustomPositionText -Lap $crLapNow -Index $crIndexNow -Total $crResumeTotal)부터 시작합니다."
        }
      }
      # 랜덤 진행: 이번 바퀴 순열을 시작 전에 확보합니다 (아래 마커 복구 검사의 resumeContext 가
      # 확정된 순열로 항목을 해석해야 하므로 반드시 이 지점 - 리뷰 삽입 지점 합의)
      if (-not (Confirm-CustomShuffleReady)) {
        Add-GuiLog '[오류] 랜덤 진행 순서를 준비하지 못해 시작하지 않습니다.'
        $script:customActive = $false
        return
      }
      $script:customErrorStreak = 0
      $script:customPrevItem = ''
      $script:customRestart = $false
      $script:customRecoveryPending = $false
    }
    $cleanup = Stop-ExistingAutomation
    if ($cleanup.Killed -gt 0) {
      Add-GuiLog "기존 자동화 프로세스 $($cleanup.Killed)개를 종료했습니다."
      # 강제 종료된 워커가 키/마우스 '누름-뗌' 사이였을 수 있으므로 입력 상태를 정리합니다
      Release-StuckInput
    }
    if ($cleanup.Failed -gt 0) { Add-GuiLog "[경고] 기존 자동화 프로세스 $($cleanup.Failed)개를 종료하지 못했습니다 - 새 회차가 '중복 실행'으로 멈추면 작업 관리자에서 powershell.exe(또는 꿀비노기)를 직접 종료해 주세요." }
    # 진행 기록을 초기화할 때 무효화하지 **못한** 마커가 있으면 여기서 반드시 소비합니다.
    # 실패를 메모리 플래그로만 들고 있으면 프로그램을 껐다 켜는 순간 사라지고, 그 사이 파일
    # 잠금이 풀리면 옛 마커가 멀쩡한 유효 마커로 되살아납니다. 특히 옛 진행이 1바퀴 0번이면
    # 초기화된 위치와 소유자가 **정확히 일치**해 잘못된 마무리 복구가 그대로 발동합니다
    # (2026-08-09 리뷰 적발). 그래서 실패 사실은 디스크(.stale)에 남기고 여기서 재시도합니다.
    $markerStaleBlocked = $false
    if ($script:customActive -and (Test-CustomMarkerStale -Path $customMarkerFile)) {
      if (Clear-CustomMarkerFile -Path $customMarkerFile) {
        Add-GuiLog '[안내] 지우지 못했던 이전 완료 기록을 정리했습니다 (진행은 초기화된 위치부터 시작합니다).'
      } else {
        $markerStaleBlocked = $true
        Add-GuiLog '[경고] 이전 완료 기록 파일이 잠겨 있어 이번 시작에서는 무시합니다 - 완료 계상은 정상 종료 코드로만 이뤄집니다.'
      }
    }
    if ($script:customActive -and -not $markerStaleBlocked -and (Test-Path -LiteralPath $customMarkerFile)) {
      # GUI/워커가 클리어 뒤 마무리 중 종료됐어도 구조화 마커의 소유자가 현재 progress 와
      # 정확히 같으면 그 항목을 다시 입장하지 않고 마무리 복구부터 이어갑니다.
      # ★ '컨텍스트를 못 읽음'은 **'마커가 틀렸다'가 아니라 '판단 불가'** 입니다.
      #   Get-CustomCurrentContext 는 부를 때마다 Read-Config 로 디스크를 다시 읽습니다.
      #   그 읽기가 한 번 실패하면 $null 인데, 여기서 $null 을 '불일치'로 처리하면 아래
      #   else 가 **정당한 완료 마커를 디스크에서 지웁니다.** 그러면 이미 클리어가 확정된 판의
      #   마무리 복구가 영영 불가능해져 그 항목을 처음부터 다시 돌립니다 = 재화 이중 소모.
      #   종료 코드 경로(2026-08-09 7차)는 계상만 건너뛰고 마커는 보존하는데, 이쪽은
      #   **되돌릴 수 없어 더 파괴적**입니다 (2026-08-10 8차 점검 - 7차가 만든 계약 비대칭).
      #   → 먼저 짧게 재시도하고(일시 공유 위반이 대부분), 그래도 못 읽으면 **아무것도 지우지
      #     않고 시작 자체를 멈춥니다.** 여기서 그냥 진행하면 바로 뒤 Start-NextCycle 의
      #     마커 정리가 같은 파일을 지워 버리므로 '보존 후 무시'는 성립하지 않습니다.
      $resumeContext = Get-CustomCurrentContext
      for ($ctxTry = 1; $ctxTry -le 3 -and -not $resumeContext; $ctxTry++) {
        Start-Sleep -Milliseconds 200
        $resumeContext = Get-CustomCurrentContext
      }
      $markerOwner = Read-CustomMarkerOwner
      if ($markerOwner -and -not $resumeContext) {
        Add-GuiLog '[오류] 설정 파일을 읽지 못해 이전 완료 기록의 주인을 확인할 수 없습니다 - 완료 기록을 지우지 않고 시작을 멈춥니다. 잠시 뒤 다시 시작해 주세요 (계속 반복되면 config.json 을 확인해 주세요).'
        $script:customActive = $false
        return
      }
      if (Test-CustomMarkerOwnerMatchesContext -Owner $markerOwner -Context $resumeContext) {
        $script:customRecoveryPending = $true
        $script:customRestart = $true
        $script:customPrevItem = Format-CustomItemToken -Item $resumeContext.Item
        Add-GuiLog '[커스텀] 이전 완료 항목의 마무리를 복구합니다.'
      } else {
        # 구버전 타임스탬프/부분 파일/다른 리스트·위치의 마커는 오계상 방지를 위해 폐기합니다.
        # 무효화는 단일 계약을 거칩니다 - 맨 Remove-Item 은 실패 시 묘비를 남기지 않아
        # 그 시점의 실패가 디스크에 기록되지 않습니다 (2026-08-09 재점검).
        if (Clear-CustomMarkerFile -Path $customMarkerFile) {
          Add-GuiLog '[안내] 현재 진행 위치와 맞지 않는 이전 완료 마커를 정리했습니다.'
        } else {
          Add-GuiLog '[경고] 현재 진행 위치와 맞지 않는 완료 마커를 삭제하지 못했습니다 - 이번 회차는 마커를 무시합니다.'
          $script:customMarkerIgnore = $true
        }
      }
    }
    # 지난 세션의 안전 중지 신호가 남아 있으면 제거 (남아 있으면 첫 회차가 조기 종료됨)
    Remove-Item -LiteralPath $safeStopFlag -Force -ErrorAction SilentlyContinue
    $btnSafeStop.Text = ("안전 중지(F9)" + [Environment]::NewLine + "(회차 완료 후)")
    # RDP 자동 전환은 config 의 rdp.autoConsoleRedirect 값을 따릅니다 (false = 예약 작업 제거)
    $rdpEnable = $true
    $cfgNow = Read-Config
    if ($cfgNow -and $cfgNow.PSObject.Properties['rdp'] -and $cfgNow.rdp.PSObject.Properties['autoConsoleRedirect']) {
      $rdpEnable = ConvertTo-StrictBoolean $cfgNow.rdp.autoConsoleRedirect $true
    }
    $rdpResult = Sync-RdpRedirectTask -Enable $rdpEnable
    if ($rdpResult -eq 'installed') { Add-GuiLog 'RDP 자동 전환이 설치됐습니다. RDP 창을 닫아도 계속 돕니다.' }
    elseif ($rdpResult -eq 'removed') { Add-GuiLog 'RDP 자동 전환 예약 작업을 제거했습니다 (config 의 rdp.autoConsoleRedirect = false). RDP 창을 닫으면 캡처가 멈출 수 있습니다.' }
    elseif ($rdpResult -like 'error*') { Add-GuiLog "RDP 자동 전환 설정 실패: $rdpResult" }

    $script:completedCycles = 0
    $script:stopRequested = $false
    $script:preparedStreak = 0
    $script:targetTime = $null
    if ($rbCount.Checked) { $script:targetCycles = [int]$numCount.Value } else { $script:targetCycles = 0 }
    if ($rbTime.Checked) {
      # 목표 시각 계산: 오늘 그 시각, 이미 지났으면 내일 그 시각.
      # DateTimePicker 는 화면에 HH:mm 만 보여도 생성 시점의 초가 값에 숨어 남습니다 -
      # UI 약속은 분 단위이므로 초를 잘라 정규화합니다 (2026-08-11 교차 리뷰. 안 자르면
      # 워커에 넘기는 문자열(yyyy-MM-dd HH:mm)과 GUI 내부 비교 시각이 최대 59초 어긋남)
      $untilTod = $dtpUntil.Value.TimeOfDay
      $candidate = (Get-Date).Date.AddHours($untilTod.Hours).AddMinutes($untilTod.Minutes)
      if ($candidate -le (Get-Date)) { $candidate = $candidate.AddDays(1) }
      $script:targetTime = $candidate
      if (-not (Test-TimeAllowsNextCycle)) {
        $estimateLabel = $(if ($script:mainCategory -eq 'life') { '진행 없음 한도' } else { '클리어 대기' })
        Add-GuiLog "[안내] 지정 시간($($script:targetTime.ToString('HH:mm')))까지 남은 시간이 ${estimateLabel}($(Get-CycleWaitSecondsForEstimate)초)보다 짧아 시작할 수 없습니다."
        $script:targetTime = $null
        return
      }
      Add-GuiLog "시간 지정 모드: $($script:targetTime.ToString('MM-dd HH:mm')) 까지 반복합니다."
    }
    # 커스텀 반복은 상단 횟수/시간과 택일 관계 - 라디오가 비활성이라 실질 방어용 강제 해제
    if ($script:customActive) { $script:targetCycles = 0; $script:targetTime = $null }
    # 실행 중에는 화면 꺼짐/절전을 막습니다 (감지가 화면 렌더링에 의존)
    [Win32.PowerState]::SetThreadExecutionState($script:esKeepAwake) | Out-Null
    Set-UiRunning $true
    Start-NextCycle
}

$btnStart.Add_Click({
    # 생활 대분류 지원 범위 게이트 (가공/미지원 스킬 차단. F9 도 PerformClick 경유라 함께 검사)
    if (Test-LifeStartBlocked) { return }
    # 창 크기 변경 진행 중 시작 금지 (2026-08-13 교차 리뷰): 비동기 리사이즈 헬퍼의
    # MoveWindow 가 워커 시작 직후 좌표 계산을 흔들 수 있음. pending 은 결과 타이머가
    # 결과 확인/타임아웃(최대 4초)에 반드시 해제하므로 잠깐만 막힙니다.
    if ($script:resizePending) {
      Add-GuiLog '[안내] 창 크기 변경이 끝난 뒤 시작해 주세요 (몇 초 안에 완료됩니다)'
      return
    }
    # 사용 승인 게이트 (새 자동화 시작 시 검사 - 스펙): 미승인 상태는 즉시 거부하고,
    # 승인 상태여도 명단을 한 번 더 비동기 조회한 뒤 시작합니다.
  # 상한은 GUI 쪽 $approvalFetchTimeoutSeconds(25초)입니다 - 러닝스페이스 안의 -TimeoutSec 10 은
  # 응답 헤더까지만 덮으므로 그것만으로는 시작 버튼이 영영 안 풀릴 수 있었습니다(8차 점검).
  # ('최대 10초'라고 적혀 있던 옛 문구를 11차에서 실제 상한으로 정정)
    # 조회 실패 시에는 7일 유예 캐시가 판정을 대신합니다 (무인 운용 보호).
    if (-not (Test-ApprovalAllowsStart)) {
      Add-GuiLog '[안내] 사용 승인이 확인되지 않아 시작할 수 없습니다 - 화면의 기기 코드를 개발자에게 보내 승인을 받아 주세요.'
      Update-ApprovalUi
      return
    }
    $btnStart.Enabled = $false
    $lblStatus.Text = '사용 승인 확인 중…'
    Start-ApprovalCheck -ForStart
  })

$btnSafeStop.Add_Click({
    # 토글 동작: 이미 예약된 상태에서 다시 누르면 예약을 취소하고 반복을 계속합니다.
    if ($script:stopRequested) {
      $script:stopRequested = $false
      Remove-Item -LiteralPath $safeStopFlag -Force -ErrorAction SilentlyContinue
      $btnSafeStop.Text = ("안전 중지(F9)" + [Environment]::NewLine + "(회차 완료 후)")
      if ($script:customActive) {
        # 커스텀 반복은 회차 번호 대신 진행 위치로 표기합니다
        $positionNow = ''
        try {
          $contextNow = Get-CustomCurrentContext
          if ($contextNow) { $positionNow = $contextNow.Position }
        } catch { }
        $lblStatus.Text = "커스텀: $positionNow 실행 중 (안전 중지 취소됨)"
      } else {
        $statusSuffix = ''
        if ($null -ne $script:targetTime) { $statusSuffix = " ($($script:targetTime.ToString('HH:mm')) 까지)" }
        $lblStatus.Text = "$($script:completedCycles + 1)회차 실행 중...$statusSuffix (안전 중지 취소됨)"
      }
      $lblStatus.ForeColor = [System.Drawing.Color]::ForestGreen
      Add-GuiLog '안전 중지 취소: 반복을 계속합니다.'
      return
    }
    $script:stopRequested = $true
    # 워커에게 신호 파일을 남깁니다: 던전에서 나와 밖(HUD)이 확인되면 어비스 선택 화면까지
    # 복귀하지 않고 그 시점에서 회차를 마칩니다.
    try {
      Set-Content -LiteralPath $safeStopFlag -Value 'stop' -Encoding ASCII
    } catch {
      # 신호 파일 생성 실패: 워커의 조기 종료 지점은 동작하지 않지만, GUI의 stopRequested 로
      # 이번 회차가 끝나는 시점에는 멈추므로 그 사실을 정확히 알립니다.
      Add-GuiLog "[경고] 안전 중지 신호 파일을 만들지 못했습니다($($_.Exception.Message)) - 진행 중인 회차가 완전히 끝나는 시점에 멈춥니다."
    }
    $btnSafeStop.Text = '안전 중지 취소(F9)'
    # 문구는 대분류마다 다릅니다 (2026-08-08 사용자 지적: 생활인데 '던전에서 나오면'이라고 안내).
    # 전투는 워커가 결과 화면에서 '나가기'를 눌러 밖이 확인되는 시점에 회차를 마치지만,
    # 생활은 그런 조기 종료 지점이 없어(채집을 중간에 버리면 퀘스트만 날아감) **진행 중인
    # 채집을 끝까지 마친 뒤** GUI 가 다음 사이클을 시작하지 않는 방식으로 멈춥니다.
    if ($script:mainCategory -eq 'life') {
      $lblStatus.Text = '안전 중지 예약됨 - 이번 채집을 마치면 멈춥니다 (다시 누르면 취소)'
      Add-GuiLog '안전 중지 예약: 진행 중인 채집을 끝까지 마친 뒤 다음 사이클을 시작하지 않습니다 (채집이 끝날 때까지 몇 분 걸릴 수 있습니다). 버튼을 다시 누르면 취소.'
    } elseif ($script:mainCategory -eq 'etc') {
      # 냥코인 뽑기는 판(가격표 소진) 단위가 안전 경계 - 워커가 다시 뽑기 클릭 직전에 신호를
      # 소비하고 정지합니다 (2026-08-15 실기 결함 수정: 배선 부재 + '던전에서 나오는 대로' 오안내)
      $lblStatus.Text = '안전 중지 예약됨 - 이번 판을 마치면 멈춥니다 (다시 누르면 취소)'
      Add-GuiLog '안전 중지 예약: 지금 판의 남은 카드를 모두 구매한 뒤 다시 뽑기 전에 멈춥니다. (버튼을 다시 누르면 취소)'
    } else {
      $lblStatus.Text = '안전 중지 예약됨 - 던전에서 나오는 대로 멈춥니다 (다시 누르면 취소)'
      Add-GuiLog '안전 중지 예약: 던전에서 나와 밖이 확인되면 멈춥니다. (버튼을 다시 누르면 취소)'
    }
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkOrange
  })

$btnKill.Add_Click({ Stop-AllRun '즉시 중지' })

$btnSave.Add_Click({
    if (Save-SettingsFromUi) {
      # RDP 자동 전환은 config 의 rdp.autoConsoleRedirect 값을 따릅니다 (false = 예약 작업 제거)
      $rdpEnable = $true
      $cfgNow = Read-Config
      if ($cfgNow -and $cfgNow.PSObject.Properties['rdp'] -and $cfgNow.rdp.PSObject.Properties['autoConsoleRedirect']) {
        $rdpEnable = ConvertTo-StrictBoolean $cfgNow.rdp.autoConsoleRedirect $true
      }
      $rdpResult = Sync-RdpRedirectTask -Enable $rdpEnable
      $lblSaveInfo.Text = "저장됨 ($(Get-Date -Format 'HH:mm:ss'))"
      Add-GuiLog '설정이 저장됐습니다. 다음 회차부터 적용됩니다.'
      if ($rdpResult -eq 'installed') { Add-GuiLog 'RDP 자동 전환이 설치됐습니다.' }
      elseif ($rdpResult -eq 'removed') { Add-GuiLog 'RDP 자동 전환 예약 작업을 제거했습니다 (config 의 rdp.autoConsoleRedirect = false).' }
    }
  })

$btnOpenLog.Add_Click({
    if (Test-Path -LiteralPath $honeyLogDir) { Start-Process explorer.exe $honeyLogDir }
  })

$btnRecommendedWindow.Add_Click({
    # 즉시 적용 대신 크기 선택 메뉴를 버튼 바로 아래에 엽니다 (2026-08-13 시안 확정).
    # 실행 중에는 메뉴 자체를 열지 않습니다 (항목 클릭 쪽에도 같은 가드 - 이중 방어)
    if (Test-ResizeBlockedByRunning) { return }
    $menuRecommendedWindow.Show($btnRecommendedWindow, (New-Object System.Drawing.Point(0, $btnRecommendedWindow.Height)))
  })

$form.Add_FormClosing({
    param($formSender, $closeArgs)
    if ($script:running) {
      # 종료 확인 팝업은 사용자가 직접 닫을 때만 (2026-08-01 전수 점검: Windows 종료/로그오프
      # 등 비사용자 종료에도 팝업이 떠 시스템 종료를 막을 수 있었음 - 그 경우 확인 없이 정리)
      if ($closeArgs.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
          '자동화가 실행 중입니다. 종료하면 현재 회차도 함께 중단됩니다. 종료할까요?',
          '종료 확인', [System.Windows.Forms.MessageBoxButtons]::YesNo)
        if ($answer -eq [System.Windows.Forms.DialogResult]::No) {
          $closeArgs.Cancel = $true
          return
        }
      }
      $closingWorker = $script:worker
      if ($closingWorker) {
        # Stop-AllRun 과 같은 방어 (2026-08-01 3차 리뷰: 무기한 WaitForExit() 는 종료 신호가
        # 안 오면 폼 종료 전체가 멈추고 재시도에도 못 감 - 타임아웃 대기 + 확인된 경우에만
        # workerWasKilled. 리뷰 조건)
        $closingWorkerWasKilled = $false
        $closingKillFailed = $false
        try {
          if (-not $closingWorker.HasExited) {
            $closingWorker.Kill()
            if ($closingWorker.WaitForExit(10000)) { $closingWorkerWasKilled = $true } else { $closingKillFailed = $true }
          }
        } catch { $closingKillFailed = $true }
        if ($closingKillFailed) {
          try {
            if (-not $closingWorker.HasExited) {
              $closingWorker.Kill()
              if ($closingWorker.WaitForExit(3000)) { $closingWorkerWasKilled = $true }
            } else { $closingWorkerWasKilled = $true }
          } catch { }
          $closingWorkerAlive = $false
          try { $closingWorkerAlive = (-not $closingWorker.HasExited) } catch { }
          if ($closingWorkerAlive -and $closeArgs.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
            # 사용자가 직접 닫는 문맥의 즉답 안내 (무인 운용 아님 - 팝업 예외 범주.
            # Windows 종료/로그오프 등 비사용자 종료에서는 모달로 시스템 종료를 막지 않음)
            [System.Windows.Forms.MessageBox]::Show(
              '자동화 프로세스를 종료하지 못했습니다. 게임 조작이 계속되면 작업 관리자에서 powershell 프로세스를 직접 종료해 주세요.',
              '꿀비노기', [System.Windows.Forms.MessageBoxButtons]::OK,
              [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
          }
        }
        try { $closingWorker.Dispose() } catch { }
        $script:worker = $null
        if ($closingWorkerWasKilled) { Release-StuckInput }
      }
      # 종료 전에 안전 중지 신호 파일을 정리합니다. 남겨 두면 컨트롤러 등 다른 실행 경로의
      # 다음 워커가 시작하자마자 조기 종료를 반복할 수 있습니다.
      Remove-Item -LiteralPath $safeStopFlag -Force -ErrorAction SilentlyContinue
    }
  })

# ----- 카테고리 전환: 상세 설정 패널 교체 + 그룹 높이/아래 요소 위치 재계산 -----
$updateCategoryPanels = {
  # 대분류(전투/생활) 게이트 (v2.0.0): 생활에서는 전투 카테고리 플래그를 전부 끕니다.
  # 전투 라디오의 Checked 는 건드리지 않아 전투 복귀 시 상태가 그대로 보존됩니다 (리뷰 조건 B).
  $isLife = ($script:mainCategory -eq 'life')
  $isEtc = ($script:mainCategory -eq 'etc')   # 2026-08-15 신설 - 고양이 상인
  $isBattle = (-not $isLife) -and (-not $isEtc)
  $isLifeGather = $isLife -and $rbLifeGather.Checked
  $isLifeProcess = $isLife -and (-not $rbLifeGather.Checked)
  $isDungeon = $isBattle -and $rbCatDungeon.Checked
  $isDeep = $isBattle -and $rbCatDeep.Checked
  $isHunting = $isBattle -and $rbCatHunting.Checked
  $isAbyss = $isBattle -and (-not $isDungeon -and -not $isDeep -and -not $isHunting)
  # 설명서 버튼 글자를 선택한 콘텐츠에 맞게 전환
  $btnManual.Text = $(if ($isEtc) { '기타 설명서' } elseif ($isLife) { '생활 설명서' } elseif ($isDungeon) { '던전 설명서' } elseif ($isDeep) { '심층 설명서' }
    elseif ($isHunting) { '사냥터 설명서' } else { '어비스 설명서' })
  # ----- 기타 대분류 (2026-08-15): 반복 그룹을 숨기고(목표 냥코인이 반복을 대신 - Codex
  # 합의: 비활성으로 남기면 동작에 영향 주는 것처럼 보임) 아래 블록을 60px 위로 당깁니다.
  # 전투/생활 복귀 시 원위치 - 상수는 컨트롤 생성부의 값과 짝 (144/190/250)
  $grpRepeat.Visible = -not $isEtc
  $etcShiftTop = $(if ($isEtc) { -60 } else { 0 })
  $btnStart.Top = 144 + $etcShiftTop
  $btnSafeStop.Top = 144 + $etcShiftTop
  $btnKill.Top = 144 + $etcShiftTop
  $btnManual.Top = 144 + $etcShiftTop
  $grpContent.Top = 190 + $etcShiftTop
  $grpContentDetail.Top = 250 + $etcShiftTop
  # 커스텀 반복 라디오는 던전/어비스/심층 + 생활 채집에서 활성화합니다. 사냥터와 생활 가공은
  # 리스트 개념이 없어 전환할 수 없고, 선택 의도는 config 에 보존합니다.
  # (생활 채집 커스텀은 2026-08-08 신설 - 그전까지 생활 전체가 미지원이었습니다)
  # crSwitching 가드: 이 프로그램적 전환이 라디오 CheckedChanged 의 enabled 저장을 오염시키지 않게 함
  $supportsCustom = (-not $isEtc) -and (-not $isHunting) -and ((-not $isLife) -or $isLifeGather)
  $rbCustomRepeat.Enabled = $supportsCustom
  if (-not $supportsCustom) {
    if ($rbCustomRepeat.Checked) {
      $script:crSwitching = $true
      try { $rbInfinite.Checked = $true } finally { $script:crSwitching = $false }
    }
  } elseif ($script:customEnabledWish -and -not $rbCustomRepeat.Checked) {
    $script:crSwitching = $true
    try { $rbCustomRepeat.Checked = $true } finally { $script:crSwitching = $false }
  }
  $isCustom = $supportsCustom -and $rbCustomRepeat.Checked
  $isDungeonCustom = $isDungeon -and $isCustom
  $isAbyssCustom = $isAbyss -and $isCustom
  $isDeepCustom = $isDeep -and $isCustom
  $isLifeCustom = $isLifeGather -and $isCustom
  # 커스텀에서는 슬라이더가 '담기용'이라 리스트 자리를 만들려고 카드를 글자만 남긴 26px 로
  # 줄입니다 (아이콘 9종은 일반 생활 모드에서 그대로 - 시안 확정. 두 줄에서 60px 확보)
  $lifeCardHeight = $(if ($isLifeCustom) { 26 } else { 56 })
  $lifeSkillRowTop = 38
  $lifeSkillDotsTop = $lifeSkillRowTop + $lifeCardHeight + 2
  $lifeTargetCaptionTop = $lifeSkillDotsTop + 18
  $lifeTargetRowTop = $lifeTargetCaptionTop + 18
  $lifeTargetDotsTop = $lifeTargetRowTop + $lifeCardHeight + 2
  $grpContentDetail.Text = '콘텐츠 상세 설정'
  # 커스텀 반복 중에는 사냥터 카테고리로 전환하지 못하게 합니다.
  # 커스텀 반복을 해제하거나 다른 카테고리로 폴백하면 문구와 활성 상태가 즉시 원래대로 돌아옵니다.
  $rbCatHunting.Text = $(if ($isCustom) { '사냥터(미지원)' } else { '사냥터' })
  $rbCatHunting.Enabled = -not $isCustom
  # ----- 생활 대분류 (v2.0.0): 콘텐츠 선택 줄 교대 + 생활 상세/설정 표시 전환 -----
  # 채집/가공·대분류 전환 시 진행 중 슬라이드를 즉시 정리 (오버레이 잔존 방지 - 리뷰 조건.
  # UI 갱신은 아래 흐름이 이어서 하므로 SkipUiRefresh)
  if ($script:lifeSlideActive) { Stop-LifeSlideNow -SkipUiRefresh }
  $pnlCategory.Visible = $isBattle
  $pnlLifeCategory.Visible = $isLife
  $pnlEtcCategory.Visible = $isEtc
  # 기타 상세 컨트롤 (냥코인 뽑기)
  $lblEtcFeature.Visible = $isEtc
  $btnEtcNyanCard.Visible = $isEtc
  $lblEtcTarget.Visible = $isEtc
  $numEtcTarget.Visible = $isEtc
  $lblEtcTargetSuffix.Visible = $isEtc
  $chkEtcGoldLimit.Visible = $isEtc
  $numEtcGoldLimit.Visible = $isEtc
  $lblEtcGoldSuffix.Visible = $isEtc
  $lblEtcHint.Visible = $isEtc
  if ($isEtc) {
    # 카드 선택 스타일 (생활 스킬 카드와 동일 - Apply-HoneyTheme 가 일반 버튼 스타일로
    # 덮으므로 표시 시점마다 재지정)
    $btnEtcNyanCard.FlatStyle = 'Flat'
    $btnEtcNyanCard.BackColor = $script:lifeCardSelectedBack
    $btnEtcNyanCard.Font = $script:lifeCardFontBold
    $btnEtcNyanCard.FlatAppearance.BorderColor = $script:themeHoney
    $btnEtcNyanCard.FlatAppearance.BorderSize = 2
  }
  $lblLifeSkillCaption.Visible = $isLifeGather
  $btnLifeSkillPrev.Visible = $isLifeGather
  $btnLifeSkillNext.Visible = $isLifeGather
  foreach ($lifeCardCtl in @($script:lifeSkillCards)) { $lifeCardCtl.Visible = $isLifeGather }
  $lblLifeSkillDots.Visible = $isLifeGather
  $lblLifeTargetCaption.Visible = $isLifeGather
  $btnLifeTargetPrev.Visible = $isLifeGather
  $btnLifeTargetNext.Visible = $isLifeGather
  foreach ($lifeCardCtl in @($script:lifeTargetCards)) { $lifeCardCtl.Visible = $isLifeGather }
  $lblLifeTargetDots.Visible = $isLifeGather
  $lblLifeProcessInfo.Visible = $isLifeProcess
  # 생활 슬라이더 두 줄의 세로 배치 - 커스텀이면 카드가 낮아져 아래 줄이 전부 올라옵니다
  $btnLifeSkillPrev.Top = $lifeSkillRowTop
  $btnLifeSkillPrev.Height = $lifeCardHeight
  $btnLifeSkillNext.Top = $lifeSkillRowTop
  $btnLifeSkillNext.Height = $lifeCardHeight
  foreach ($lifeCardCtl in @($script:lifeSkillCards)) {
    $lifeCardCtl.Top = $lifeSkillRowTop
    $lifeCardCtl.Height = $lifeCardHeight
  }
  $lblLifeSkillDots.Top = $lifeSkillDotsTop
  $lblLifeTargetCaption.Top = $lifeTargetCaptionTop
  $btnLifeTargetPrev.Top = $lifeTargetRowTop
  $btnLifeTargetPrev.Height = $lifeCardHeight
  $btnLifeTargetNext.Top = $lifeTargetRowTop
  $btnLifeTargetNext.Height = $lifeCardHeight
  foreach ($lifeCardCtl in @($script:lifeTargetCards)) {
    $lifeCardCtl.Top = $lifeTargetRowTop
    $lifeCardCtl.Height = $lifeCardHeight
  }
  $lblLifeTargetDots.Top = $lifeTargetDotsTop
  # 생활 커스텀 리스트 화면 (반복 횟수 줄 → 리스트+버튼 열 → 리스트 반복 줄)
  $pnlLcrInput.Visible = $isLifeCustom
  $lvLcrList.Visible = $isLifeCustom
  $btnLcrAdd.Visible = $isLifeCustom
  $btnLcrDelete.Visible = $isLifeCustom
  $btnLcrUp.Visible = $isLifeCustom
  $btnLcrDown.Visible = $isLifeCustom
  $chkLcrRandom.Visible = $isLifeCustom
  $pnlLcrRepeat.Visible = $isLifeCustom
  if ($isLifeCustom) {
    $lcrInputTop = $lifeTargetDotsTop + 20
    $lcrListTop = $lcrInputTop + 30
    $pnlLcrInput.Top = $lcrInputTop
    $lvLcrList.Top = $lcrListTop
    $btnLcrAdd.Top = $lcrListTop
    $btnLcrDelete.Top = $lcrListTop + 36
    $btnLcrUp.Top = $lcrListTop + 72
    $btnLcrDown.Top = $lcrListTop + 108
    $chkLcrRandom.Top = $lcrListTop + 144
    $pnlLcrRepeat.Top = $lcrListTop + 186
  }
  if ($isLifeGather) { Update-LifeSliders }
  # 설정 그룹 내용 교대: 전투(체크 4개 + 클리어 대기 줄) ↔ 생활(진행 없음 줄).
  # 공용 버튼(권장 창 모드/적용된 설정/설정 저장)과 저장 안내 라벨은 양쪽 유지 (시안 확정)
  $chkSpace.Visible = $isBattle
  $chkFood.Visible = $isBattle
  $chkRevive.Visible = $isBattle
  $chkAssist.Visible = $isBattle
  $btnClearHelp.Visible = $isBattle
  $lblClearWait.Visible = $isBattle
  $numClearWait.Visible = $isBattle
  $lblClearHuman.Visible = $isBattle
  $lblGatherWait.Visible = $isLife
  $numGatherWait.Visible = $isLife
  $lblGatherHuman.Visible = $isLife
  # 공용 버튼 3개(권장 창 모드/적용된 설정/설정 저장)는 양 대분류 모두 **아래 가로 1줄**
  # (폭 158×28, x 15/183/351)로 통일됐습니다 (2026-08-13 시안 확정 - 전투는 체크 4개를
  # 가로 2줄로 압축하고 클리어 대기 줄을 자동부활 오른쪽으로 옮겨 그룹 높이 150을 유지).
  # 대분류별로 갈리는 것은 버튼 줄의 y(전투 110 / 생활 56)와 저장 안내 위치·그룹 높이뿐.
  if ($isEtc) {
    # 기타: 진행 없음 줄도 없어 버튼 3개 한 줄만 (저장 안내는 버튼 줄 위 오른쪽)
    $btnRecommendedWindow.Location = New-Object System.Drawing.Point(15, 44)
    $btnAlwaysOn.Location = New-Object System.Drawing.Point(183, 44)
    $btnSave.Location = New-Object System.Drawing.Point(351, 44)
    $lblSaveInfo.Location = New-Object System.Drawing.Point(350, 20)
    $lblSaveInfo.Size = New-Object System.Drawing.Size(159, 20)
    $grpSettings.Height = 82
  }
  elseif ($isLife) {
    $btnRecommendedWindow.Location = New-Object System.Drawing.Point(15, 56)
    $btnAlwaysOn.Location = New-Object System.Drawing.Point(183, 56)
    $btnSave.Location = New-Object System.Drawing.Point(351, 56)
    # 저장 안내는 진행 없음 줄 오른쪽 빈 자리로 (버튼 줄과 겹치지 않게)
    $lblSaveInfo.Location = New-Object System.Drawing.Point(350, 28)
    $lblSaveInfo.Size = New-Object System.Drawing.Size(159, 20)
    $grpSettings.Height = 94
  }
  else {
    $btnRecommendedWindow.Location = New-Object System.Drawing.Point(15, 110)
    $btnAlwaysOn.Location = New-Object System.Drawing.Point(183, 110)
    $btnSave.Location = New-Object System.Drawing.Point(351, 110)
    $lblSaveInfo.Location = New-Object System.Drawing.Point(353, 88)
    $lblSaveInfo.Size = New-Object System.Drawing.Size(156, 20)
    $grpSettings.Height = 150
  }
  # 어비스용 패널 (함께하기일 때만 매칭 줄이 난이도 아래에 나타나고 던전 목록이 내려감)
  # 파티(파티원)은 난이도/던전 선택이 의미가 없어(파티장이 결정) 두 줄을 숨기고
  # 매칭 줄을 난이도 자리로 올립니다.
  $abyssSingleOn = $isAbyss -and -not $isAbyssCustom
  $abyssPartyOn = $abyssSingleOn -and $rbModeParty.Checked
  $abyssMemberOn = $abyssPartyOn -and $rbAbyssPartyMember.Checked
  $pnlMode.Visible = $abyssSingleOn
  $pnlDifficulty.Visible = $abyssSingleOn -and -not $abyssMemberOn
  $pnlAbyssMatching.Visible = $abyssPartyOn
  $pnlAbyssMatching.Top = $(if ($abyssMemberOn) { 52 } else { 84 })
  $pnlDungeon.Visible = $abyssSingleOn -and -not $abyssMemberOn
  $pnlDungeon.Top = $(if ($abyssPartyOn) { 116 } else { 84 })
  # 던전용 패널 (더블 루팅은 은동전 사용 체크박스 옆, 2단계 소진 대응은 해당 조건에서만 표시.
  # 커스텀 반복 선택 시 단일 모드 줄들은 전부 숨기고 리스트 빌더로 전환합니다)
  $ndSingleOn = $isDungeon -and -not $isDungeonCustom
  $coinRowOn = $ndSingleOn -and $chkNdCoin.Checked
  $ndNoDoubleRowOn = $coinRowOn -and $chkNdDoubleLoot.Checked
  $pnlNdDifficulty.Visible = $ndSingleOn
  $pnlNdStage.Visible = $ndSingleOn
  $pnlNdCoin.Visible = $ndSingleOn
  $pnlNdExhaust.Visible = $coinRowOn
  $pnlNdNoDouble.Visible = $ndNoDoubleRowOn
  $pnlNdParty.Visible = $ndSingleOn
  # 심층던전용 패널 (던전과 같은 줄 구성 - 더블 루팅 없음. 공물 소진 대응은 마족공물 체크 시에만.
  # 커스텀 반복 선택 시 단일 모드 줄들은 전부 숨기고 심층 리스트 빌더로 전환합니다)
  $ddSingleOn = $isDeep -and -not $isDeepCustom
  $ddExhaustRowOn = $ddSingleOn -and $chkDdTribute.Checked
  $pnlDdDifficulty.Visible = $ddSingleOn
  $pnlDdStage.Visible = $ddSingleOn
  $pnlDdTribute.Visible = $ddSingleOn
  $pnlDdExhaust.Visible = $ddExhaustRowOn
  $pnlDdMatching.Visible = $ddSingleOn
  # 커스텀 반복 리스트 빌더 패널 (던전 + 커스텀 반복 선택 시에만 표시.
  # 소진/더블 불가 라디오 줄은 입력 줄의 은동전/더블 루팅 체크 상태를 따라갑니다)
  $crExhaustRowOn = $isDungeonCustom -and $chkCrCoin.Checked
  $crNoDoubleRowOn = $crExhaustRowOn -and $chkCrDouble.Checked
  $pnlCrInput.Visible = $isDungeonCustom
  $pnlCrExhaust.Visible = $crExhaustRowOn
  $pnlCrNoDouble.Visible = $crNoDoubleRowOn
  $lvCrList.Visible = $isDungeonCustom
  $btnCrAdd.Visible = $isDungeonCustom
  $btnCrDelete.Visible = $isDungeonCustom
  $btnCrUp.Visible = $isDungeonCustom
  $btnCrDown.Visible = $isDungeonCustom
  $chkCrRandom.Visible = $isDungeonCustom
  $pnlCrRepeat.Visible = $isDungeonCustom
  # 어비스 커스텀: 함께하기일 때만 입력 줄 바로 아래에 매칭 줄을 추가합니다.
  $acrPartyOn = $isAbyssCustom -and $rbAcrParty.Checked
  $pnlAcrInput.Visible = $isAbyssCustom
  $pnlAcrMatching.Visible = $acrPartyOn
  $lvAcrList.Visible = $isAbyssCustom
  $btnAcrAdd.Visible = $isAbyssCustom
  $btnAcrDelete.Visible = $isAbyssCustom
  $btnAcrUp.Visible = $isAbyssCustom
  $btnAcrDown.Visible = $isAbyssCustom
  $chkAcrRandom.Visible = $isAbyssCustom
  $pnlAcrRepeat.Visible = $isAbyssCustom
  # 심층 커스텀 리스트 빌더 (심층던전 + 커스텀 반복 선택 시에만 표시.
  # 소진 라디오 줄은 입력 줄의 마족공물 체크 상태를 따라갑니다)
  $dcrExhaustRowOn = $isDeepCustom -and $chkDcrTribute.Checked
  $pnlDcrInput.Visible = $isDeepCustom
  $pnlDcrExhaust.Visible = $dcrExhaustRowOn
  $lvDcrList.Visible = $isDeepCustom
  $btnDcrAdd.Visible = $isDeepCustom
  $btnDcrDelete.Visible = $isDeepCustom
  $btnDcrUp.Visible = $isDeepCustom
  $btnDcrDown.Visible = $isDeepCustom
  $chkDcrRandom.Visible = $isDeepCustom
  $pnlDcrRepeat.Visible = $isDeepCustom
  # 사냥터용 패널 (소진 대응 옵션 없음 - 은동전이 부족하면 나가고 자동화 종료)
  $pnlHtDifficulty.Visible = $isHunting
  $pnlHtCoin.Visible = $isHunting
  $pnlHtParty.Visible = $isHunting
  # 줄 수에 맞춰 배치/그룹 높이를 조절하고 아래 요소들을 내리거나 올립니다
  # (어비스/사냥터 3줄 = 122 / 어비스 함께하기·던전 4줄 = 150 /
  #  던전 + 소진 대응 5줄 = 182 / 더블 불가 대응까지 6줄 = 208 /
  #  던전 커스텀 반복 = 입력 줄 + 라디오 줄 0~2개 + 리스트 + 리스트 반복 줄: 라디오 줄 수에
  #  따라 리스트/버튼 열/하단 줄을 내리고 그룹 높이를 244~296 으로 재계산)
  if ($isEtc) {
    # 기타(냥코인 뽑기): 기능 카드 + 목표/상한 줄 + 안내 3줄 고정
    $grpContentDetail.Height = 184
  } elseif ($isLife) {
    if ($isLifeCustom) {
      # 생활 커스텀: 슬라이더 두 줄(글자 카드 26)이 위로 접히고 그 아래 리스트 화면이 붙습니다.
      # 위치는 위쪽 표시 블록이 이미 계산해 뒀으므로 여기서는 높이만 맞춥니다
      $grpContentDetail.Height = $pnlLcrRepeat.Top + 36
    } else {
      # 생활 상세: 채집(슬라이더 2줄 + 소진 2줄)·가공(안내) 모두 268 고정
      # (채집↔가공 전환 시 탭/폼 흔들림 방지 - 리뷰 조건. 탭 이하 배치는 아래 공통 계산이 처리)
      $grpContentDetail.Height = 268
    }
  } elseif ($isDungeon) {
    if ($isDungeonCustom) {
      $crRowTop = 50
      if ($crExhaustRowOn) { $pnlCrExhaust.Top = $crRowTop; $crRowTop += 26 }
      if ($crNoDoubleRowOn) { $pnlCrNoDouble.Top = $crRowTop; $crRowTop += 26 }
      $crListTop = $crRowTop + 2
      $lvCrList.Top = $crListTop
      $btnCrAdd.Top = $crListTop
      $btnCrDelete.Top = $crListTop + 36
      $btnCrUp.Top = $crListTop + 72
      $btnCrDown.Top = $crListTop + 108
      $chkCrRandom.Top = $crListTop + 144
      $pnlCrRepeat.Top = $crListTop + 186
      $grpContentDetail.Height = $pnlCrRepeat.Top + 36
    } elseif ($ndNoDoubleRowOn) {
      $pnlNdParty.Top = 174
      $grpContentDetail.Height = 208
    } elseif ($coinRowOn) {
      $pnlNdParty.Top = 148
      $grpContentDetail.Height = 182
    } else {
      $pnlNdParty.Top = 116
      $grpContentDetail.Height = 150
    }
  } elseif ($isDeep) {
    # 심층: 단일 모드는 난이도/구역/공물 3줄 + (공물 체크 시) 소진 대응 + 매칭.
    # 커스텀은 던전 커스텀과 같은 배치 규칙 (입력 줄 + 소진 라디오 0~1줄 + 리스트 + 하단 줄)
    if ($isDeepCustom) {
      $dcrListTop = $(if ($dcrExhaustRowOn) { 78 } else { 52 })
      $lvDcrList.Top = $dcrListTop
      $btnDcrAdd.Top = $dcrListTop
      $btnDcrDelete.Top = $dcrListTop + 36
      $btnDcrUp.Top = $dcrListTop + 72
      $btnDcrDown.Top = $dcrListTop + 108
      $chkDcrRandom.Top = $dcrListTop + 144
      $pnlDcrRepeat.Top = $dcrListTop + 186
      $grpContentDetail.Height = $pnlDcrRepeat.Top + 36
    } elseif ($ddExhaustRowOn) {
      $pnlDdMatching.Top = 148
      $grpContentDetail.Height = 182
    } else {
      $pnlDdMatching.Top = 116
      $grpContentDetail.Height = 150
    }
  } elseif ($isAbyssCustom) {
    $acrListTop = $(if ($acrPartyOn) { 78 } else { 52 })
    $lvAcrList.Top = $acrListTop
    $btnAcrAdd.Top = $acrListTop
    $btnAcrDelete.Top = $acrListTop + 36
    $btnAcrUp.Top = $acrListTop + 72
    $btnAcrDown.Top = $acrListTop + 108
    $chkAcrRandom.Top = $acrListTop + 144
    $pnlAcrRepeat.Top = $acrListTop + 186
    $grpContentDetail.Height = $pnlAcrRepeat.Top + 36
  } elseif ($abyssPartyOn) {
    # 파티원은 입장 방식 + 매칭 2줄만 남아 그룹을 줄입니다
    $grpContentDetail.Height = $(if ($abyssMemberOn) { 90 } else { 150 })
  } else {
    $grpContentDetail.Height = 122
  }
  # ----- 탭 토글 줄 이하 배치 (2026-08-04 시안 확정: 순수 계산 Get-TabToggleLayout + 여기서 적용) -----
  # 직전 레이아웃이 '로그 열림'이었을 때만 현재 로그 높이를 뷰포트 기억값으로 흡수합니다
  # (사용자 세로 리사이즈 보존 + open→closed 전환의 기억 갱신을 한 줄로. 닫힘 상태의 낡은
  # 높이를 흡수하지 않는 것이 핵심 - 리뷰 3상태 전이 계약)
  if ($script:logLayoutOpen -eq $true) { $script:logViewHeight = [Math]::Max(100, [int]$txtLog.Height) }
  $tabLayout = Get-TabToggleLayout -DetailBottom ([int]$grpContentDetail.Bottom) `
    -SettingsOpen ([bool]$chkTabSettings.Checked) -LogOpen ([bool]$chkTabLog.Checked) `
    -LogViewHeight $script:logViewHeight -SettingsHeight ([int]$grpSettings.Height) `
    -FooterGap $script:footerGap -NonClientHeight ([int]($form.Height - $form.ClientSize.Height)) `
    -WorkAreaHeight ([int][System.Windows.Forms.Screen]::FromControl($form).WorkingArea.Height)
  # 접힘으로 높이를 잠글 때 최대화 상태면 먼저 정상 창으로 (Min=Max 잠금과 충돌 방지 - 리뷰 조건)
  if ($tabLayout.LockHeight -and $form.WindowState -ne 'Normal') { $form.WindowState = 'Normal' }
  $form.SuspendLayout()
  # 크기 제약은 Max → Min 순서로 전부 해제한 뒤 새 크기를 적용 (이전 잠금이 방해하지 않게 - 리뷰 조건)
  $form.MaximumSize = [System.Drawing.Size]::Empty
  $form.MinimumSize = [System.Drawing.Size]::Empty
  $chkTabSettings.Location = New-Object System.Drawing.Point(15, $tabLayout.TabRowTop)
  $chkTabLog.Location = New-Object System.Drawing.Point(120, $tabLayout.TabRowTop)
  $lblLogPreview.Location = New-Object System.Drawing.Point(230, ($tabLayout.TabRowTop + 6))
  if ($tabLayout.SettingsTop -ge 0) {
    $grpSettings.Top = $tabLayout.SettingsTop
    $grpSettings.Visible = $true
  } else {
    $grpSettings.Visible = $false
  }
  # 로그는 프로그램적 폼 크기 변경 동안 앵커 간섭이 없도록 Top 계열로 내려 두고 마지막에 복원
  $txtLog.Visible = $false
  $txtLog.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
  $form.ClientSize = New-Object System.Drawing.Size($form.ClientSize.Width, $tabLayout.ClientHeight)
  if ($tabLayout.LogTop -ge 0) {
    $txtLog.Top = $tabLayout.LogTop
    $txtLog.Height = $tabLayout.LogHeight
    $txtLog.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $txtLog.Visible = $true
  }
  # 로그 전용 하단 컨트롤(글자 크기·지우기)은 로그가 열려 있을 때만 표시 (2026-08-04 추가 요청.
  # 'Log 폴더 열기'/버전 표시는 로그와 무관해 항상 유지. 숨김 중에도 numFontSize.Value 는
  # 배율 재적용/저장 로직이 정상 참조)
  $lblFontSize.Visible = ($tabLayout.LogTop -ge 0)
  $numFontSize.Visible = ($tabLayout.LogTop -ge 0)
  $btnClearLog.Visible = ($tabLayout.LogTop -ge 0)
  $form.ResumeLayout($true)
  # 새 크기 확정 후 제약 재설정: 접힘 = 높이만 잠금(가로는 계속 조절 가능), 열림 = 동적 최소
  # (로그 100 + 하단 줄이 겹치지 않는 하한 - 고정 700 최소는 커스텀 상세에서 겹침 유발. 리뷰 조건)
  if ($tabLayout.LockHeight) {
    $form.MinimumSize = New-Object System.Drawing.Size(560, $form.Height)
    # 가로 최대는 큰 값으로 - 최상위 Form 의 MaximumSize 는 '0 = 무제한' 규칙이 적용되지
    # 않고 문자 그대로 0 이 되어 창이 최소 크롬 폭(136px)으로 짜부라짐 (2026-08-04 실사고,
    # 배포 전 사용자 실기에서 발견 - 컨트롤의 0 규칙과 다름)
    $form.MaximumSize = New-Object System.Drawing.Size(65535, $form.Height)
    $form.MaximizeBox = $false
  } else {
    $form.MinimumSize = New-Object System.Drawing.Size(560, $tabLayout.MinOuterHeight)
    $form.MaximumSize = [System.Drawing.Size]::Empty
    $form.MaximizeBox = $true
  }
  # 펼침으로 화면 아래를 넘으면 창을 위로 보정 (현재 모니터의 작업 영역 기준 - 리뷰 조건)
  $tabWorkArea = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
  if ($form.Bottom -gt $tabWorkArea.Bottom) {
    $form.Top = [Math]::Max($tabWorkArea.Top, $tabWorkArea.Bottom - $form.Height)
  }
  $script:logLayoutOpen = [bool]$chkTabLog.Checked
  # 어비스 커스텀 방식·매칭 입력 잠금 재적용 (여기서 라디오가 바뀌면 CheckedChanged 로 이 블록이
  # 한 번 더 돌아 배치가 다시 맞춰집니다 - 잠금 함수 쪽 재진입 가드로 무한 재귀는 없습니다)
  Update-AbyssInputLock
}
$rbCatAbyss.Add_CheckedChanged($updateCategoryPanels)
$rbCatDungeon.Add_CheckedChanged($updateCategoryPanels)
$rbCatDeep.Add_CheckedChanged($updateCategoryPanels)
$rbCatHunting.Add_CheckedChanged($updateCategoryPanels)
# 심층 마족공물 체크 = 소진 대응 줄 표시/숨김 (던전 chkNdCoin 과 동일한 재배치 트리거)
$chkDdTribute.Add_CheckedChanged({ if ($null -ne $updateCategoryPanels) { & $updateCategoryPanels } })
# 파티(파티원) 선택/해제 시 난이도·던전 줄 표시가 바뀝니다 (라디오 전환은 상대 버튼의
# CheckedChanged 도 함께 발생하므로 파티원 버튼 하나에만 걸어도 모든 전환을 잡습니다)
$rbAbyssPartyMember.Add_CheckedChanged($updateCategoryPanels)

# ----- 시작 -----
# exe 업데이트로 좌표/구조가 바뀐 경우 사용자 설정만 옮겨 담아 config 를 자동 이전합니다
$script:configMigrated = Update-ConfigToLatest
Load-SettingsToUi
& $updateClearHuman
& $updateCategoryPanels
# --- 전역 단축키: F9 = 시작/안전 중지(토글), F10 = 즉시 중지 ---
# 게임 창에 포커스가 있어도 동작하도록 키 상태를 0.1초마다 확인합니다.
# '눌리는 순간'(이전에는 안 눌림 → 지금 눌림)만 반응해, 키를 누르고 있어도 한 번만 실행됩니다.
$hotkeyTimer = New-Object System.Windows.Forms.Timer
$hotkeyTimer.Interval = 100
$script:f9WasDown = $false
$script:f10WasDown = $false
$hotkeyTimer.Add_Tick({
    try {
    $f9Down = ([Win32.HotkeyPoll]::GetAsyncKeyState(0x78) -band 0x8000) -ne 0   # F9
    $f10Down = ([Win32.HotkeyPoll]::GetAsyncKeyState(0x79) -band 0x8000) -ne 0  # F10
    # 에지 판정을 먼저 래치하고 나서 동작 실행 (v2.0.0 리뷰 지적: PerformClick 이 모달
    # 팝업(생활 시작 차단 등)을 띄우면 그 메시지 루프에서 이 Tick 이 재진입하는데,
    # 래치가 동작 뒤에 있으면 f9WasDown 이 아직 false 라 팝업이 여러 겹 뜸)
    $f9Pressed = $f9Down -and -not $script:f9WasDown
    $f10Pressed = $f10Down -and -not $script:f10WasDown
    $script:f9WasDown = $f9Down
    $script:f10WasDown = $f10Down
    if ($f9Pressed) {
      if ($script:running) {
        # 실행 중 F9 = 안전 중지 버튼과 동일 (예약 상태에서 다시 누르면 예약 취소 - 버튼 토글 그대로)
        Add-GuiLog '[단축키] F9 - 안전 중지'
        $btnSafeStop.PerformClick()
      } else {
        Add-GuiLog '[단축키] F9 - 시작'
        $btnStart.PerformClick()
      }
    }
    if ($f10Pressed) {
      if ($script:running) {
        Add-GuiLog '[단축키] F10 - 즉시 중지'
        $btnKill.PerformClick()
      }
    }
    } catch {
      # 타이머 핸들러의 예외는 반드시 여기서 멈춰야 합니다 - 밖으로 나가면 PS 5.1 WinForms 가
      # 모달 오류 창을 띄워 메시지 루프가 정지하고, 무인 운용에서는 아무도 그 창을 못 닫습니다
      # (2026-08-10 10차 점검 - 실행으로 확인). 사유는 로그로 남기고 다음 틱에서 이어갑니다.
      try { Add-GuiLog "[오류] 내부 타이머(단축키 감시) 처리 중 예외 - 자동화는 계속 시도합니다: $($_.Exception.Message)" } catch { }
    }
  })

$script:uiReady = $true
Add-GuiLog '컨트롤 패널이 준비됐습니다. [시작]을 누르면 반복을 시작합니다.'
# 임베디드 호스트 시험 모드 표시 (v2.1.4): 시험 중 어떤 모드로 떠 있는지 로그로 확인 가능
if ($script:hostedExePath) {
  Add-GuiLog '[안내] 임베디드 호스트 모드로 실행 중 - 작업 관리자에 꿀비노기로 표시됩니다.'
}
# 폼 생성 전(구버전 정리)에 모아 둔 안내를 로그로 출력합니다
foreach ($cleanupLine in @($script:cleanupLogLines)) { Add-GuiLog $cleanupLine }
# 생활 스킬 아이콘 디코드 실패 경고 (실패해도 글자 카드로 동작 - 리뷰 조건: 조용한 생략 금지)
if (@($script:lifeSkillIconLoadFailures).Count -gt 0) {
  Add-GuiLog "[경고] 생활 스킬 아이콘 $((@($script:lifeSkillIconLoadFailures) -join ', ')) 을 불러오지 못했습니다 - 글자 카드로 표시합니다."
}
$script:cleanupLogLines = @()

# --- 사용 승인 확인 (시작 시 1회) ---
# 캐시로 잠정 판정해 승인된 지인의 오프라인 시작을 막지 않고(유예 7일), 곧바로 명단을
# 비동기 조회해 실제 판정으로 갱신합니다. 폴링 타이머는 업데이트 확인과 같은 패턴입니다.
$script:approvalTimer = New-Object System.Windows.Forms.Timer
$script:approvalTimer.Interval = 500
$script:approvalTimer.Add_Tick({
    try {
    if (-not $script:approvalAsync) { return }
    if (-not $script:approvalAsync.IsCompleted) {
      # ★ GUI 쪽 상한. 러닝스페이스 안의 -TimeoutSec 10 은 Invoke-WebRequest 에만 걸리고,
      #   그 밖의 이유로 조회가 끝나지 않으면 여기가 영원히 돕니다. 그동안 btnStart 는
      #   비활성이고 F9 는 PerformClick 이 무동작이라 컨트롤 패널을 껐다 켜는 것 말고는
      #   회복 경로가 없습니다. 상한을 넘기면 조회 실패로 확정해 기존 실패 경로로 보냅니다
      #   (캐시 유예 판정이 그대로 적용되므로 승인된 사용자는 그대로 시작됩니다).
      if ($script:approvalStartedAt -and
          ((Get-Date) - $script:approvalStartedAt).TotalSeconds -ge $approvalFetchTimeoutSeconds) {
        $script:approvalTimer.Stop()
        # ★★ 여기서 Stop()/Dispose() 를 **동기로 부르면 안 됩니다.** 둘 다 실행 중 파이프라인이
        #   끝날 때까지 UI 스레드를 잡습니다 (PS 5.1 실측: 12초 슬립에 Stop 11.5초 /
        #   10초 슬립에 Dispose 9.5초 블로킹). 그런데 이 상한이 발동하는 전제 자체가
        #   '조회가 끝나지 않는 상태'이고, Invoke-WebRequest 의 -TimeoutSec 10 은 응답 헤더까지만
        #   덮어 본문 읽기는 ReadWriteTimeout(기본 300초)이 지배합니다. 즉 동기 정지는
        #   **상한이 구하려던 바로 그 상황에서 컨트롤 패널을 통째로 얼립니다** - 창 이동·닫기도
        #   안 되고 F9/F10 핫키와 워커 감시 타이머까지 함께 멈춰, 원래 있던 '껐다 켜기' 회복
        #   경로마저 사라집니다. 8차에서 넣은 이 수정이 오히려 상황을 악화시켰습니다
        #   (2026-08-10 9차 점검, 실측으로 확인).
        #   → 참조만 끊고 정지 요청은 **비동기(BeginStop)** 로 던집니다. Dispose 는 하지
        #     않습니다(그것도 블로킹). 러닝스페이스는 웹 요청이 끝나면 스스로 정리되고,
        #     최악이라도 조회 1건 분량이 남을 뿐입니다 - UI 를 얼리는 것보다 훨씬 낫습니다.
        $abandonedPs = $script:approvalPs
        $script:approvalPs = $null
        $script:approvalAsync = $null
        $script:approvalStartedAt = $null
        if ($abandonedPs) { try { [void]$abandonedPs.BeginStop($null, $null) } catch { } }
        Add-GuiLog "[경고] 사용 승인 명단 조회가 ${approvalFetchTimeoutSeconds}초 안에 끝나지 않아 조회를 중단했습니다 (저장된 승인 기록으로 판정합니다)."
        Complete-ApprovalCheck -ResponseText ''
      }
      return
    }
    $script:approvalTimer.Stop()
    $script:approvalStartedAt = $null
    $responseText = ''
    try {
      $fetchResult = $script:approvalPs.EndInvoke($script:approvalAsync)
      if ($fetchResult -and $fetchResult.Count -gt 0) { $responseText = [string]$fetchResult[0] }
    } catch { }
    try { $script:approvalPs.Dispose() } catch { }
    $script:approvalPs = $null
    $script:approvalAsync = $null
    Complete-ApprovalCheck -ResponseText $responseText
    } catch {
      # 타이머 핸들러의 예외는 반드시 여기서 멈춰야 합니다 - 밖으로 나가면 PS 5.1 WinForms 가
      # 모달 오류 창을 띄워 메시지 루프가 정지하고, 무인 운용에서는 아무도 그 창을 못 닫습니다
      # (2026-08-10 10차 점검 - 실행으로 확인). 사유는 로그로 남기고 다음 틱에서 이어갑니다.
      try { Add-GuiLog "[오류] 내부 타이머(승인 조회) 처리 중 예외 - 자동화는 계속 시도합니다: $($_.Exception.Message)" } catch { }
    }
  })
$initialCache = Get-ConfigApprovalCache
$script:approvalState = Get-ApprovalDecision -FetchOk:$false -Codes @() -DeviceCode $script:deviceCode `
  -CacheApprovedAtUtc $initialCache.At -CacheDeviceCode $initialCache.Code -NowUtc ([DateTime]::UtcNow) -GraceDays $approvalGraceDays
Update-ApprovalUi
Start-ApprovalCheck
if ($script:configMigrated) {
  Add-GuiLog '[안내] 업데이트 감지: 설정을 새 버전 형식으로 이전했습니다 (사용자 설정은 유지, 화면 좌표는 최신으로 갱신)'
  if ($script:customProgressReset) {
    Add-GuiLog '[안내] 업데이트로 커스텀 반복 진행 기록을 초기화했습니다 (리스트는 유지 - 다음 시작은 처음부터)'
    if ($script:customMarkerClearFailed) {
      # 마커 무효화 실패를 조용히 넘기면 '처음부터'인데 완료 복구가 뜨는 모순을 사용자가
      # 이해할 수 없습니다 (2026-08-09 리뷰 - 실패를 성공으로 처리하지 않기).
      # 실패 사실 자체는 묘비 파일로 디스크에 남아, 시작 버튼을 누를 때 다시 처리됩니다.
      Add-GuiLog '[경고] 이전 완료 기록 파일을 지우지 못했습니다 (다른 프로그램이 사용 중일 수 있음) - 시작할 때 다시 정리하며, 그때도 안 되면 그 기록은 무시합니다.'
    }
  }
  if ($script:gatherWaitReset -gt 0) {
    Add-GuiLog "[안내] '진행 없음' 설정의 의미가 바뀌어(사이클 총 시간 → 진행이 멈춘 시간) 기존 값 $($script:gatherWaitReset)초를 기본값 600초로 되돌렸습니다. 이제 채집 수량이 늘어나는 동안은 오래 걸려도 멈추지 않습니다."
  }
}
if ($script:configMigrationError) {
  Add-GuiLog "[경고] 설정 자동 이전 실패: $($script:configMigrationError) (기존 설정으로 계속합니다)"
}
$timer.Start()
$hotkeyTimer.Start()
# ===== 꿀비노기 허니 테마 (밝은 크림 + 꿀색) =====
# 모든 컨트롤 생성이 끝난 뒤 한 번에 입힙니다 (컨트롤 생성/로직 코드는 손대지 않음).
# 색 철학: 따뜻한 크림 배경 + 꿀색 강조 + 갈색 글자. 로그만 콘솔풍으로 어둡게.
# 실행 중 색을 바꾸는 곳은 상태 라벨뿐이며(초록/빨강/파랑/주황) 밝은 배경에서 모두 잘 보입니다.
# ($script:theme* 색 변수 정의는 폼 생성 앞으로 이동 - 탭 토글 생성/초기 배지가 팔레트를
#  먼저 쓰기 때문. 2026-08-04 리뷰 지적)

function Apply-HoneyTheme {
  param([System.Windows.Forms.Control]$Root)
  foreach ($ctl in @($Root.Controls)) {
    switch ($ctl.GetType().Name) {
      'Button' {
        $ctl.FlatStyle = 'Flat'
        $ctl.FlatAppearance.BorderColor = $script:themeBorder
        $ctl.FlatAppearance.BorderSize = 1
        $ctl.BackColor = $script:themeControl
        $ctl.ForeColor = $script:themeText
      }
      'GroupBox'    { $ctl.ForeColor = $script:themeTitle; $ctl.BackColor = $script:themeBack }
      'Label'       { $ctl.ForeColor = $script:themeText }
      'CheckBox'    { $ctl.ForeColor = $script:themeText }
      'RadioButton' { $ctl.ForeColor = $script:themeText }
      'Panel'       { $ctl.BackColor = $script:themeBack }
      'NumericUpDown' { $ctl.BackColor = $script:themeInput; $ctl.ForeColor = $script:themeText }
      'ComboBox'    { $ctl.BackColor = $script:themeInput; $ctl.ForeColor = $script:themeText }
      'RichTextBox' { $ctl.BackColor = $script:themeLogBack; $ctl.BorderStyle = 'None' }
    }
    if ($ctl.Controls.Count -gt 0) { Apply-HoneyTheme -Root $ctl }
  }
}

$form.BackColor = $script:themeBack
Apply-HoneyTheme -Root $form
# 강조색 지정 (일괄 적용 뒤 개별 덮어쓰기)
$btnStart.BackColor = $script:themeHoney
$btnStart.ForeColor = $script:themeHoneyInk
$btnStart.FlatAppearance.BorderSize = 0
$btnKill.BackColor = $script:themeDanger
$btnKill.ForeColor = [System.Drawing.Color]::White
$btnKill.FlatAppearance.BorderSize = 0
$btnSafeStop.BackColor = [System.Drawing.Color]::FromArgb(250, 240, 218)
$btnClearHelp.BackColor = $script:themeHoney
$btnClearHelp.ForeColor = $script:themeHoneyInk
$lblStatus.ForeColor = $script:themeTitle
$lnkUpdate.LinkColor = $script:themeTitle          # 새 버전 링크도 꿀 갈색으로
# 대분류 버튼·생활 슬라이더 카드의 상태 스타일 재적용 (Apply-HoneyTheme 가 모든 버튼을
# 일반 스타일로 덮으므로 테마 '후'에 반드시 다시 그림 - 리뷰 조건 E)
Update-MainCategoryVisual
Update-LifeSliders

# ============================================================
#  최신 버전 확인 (GitHub 릴리스, 시작 시 1회)
# ============================================================
# 백그라운드 러닝스페이스에서 확인하므로 GUI가 멈추지 않고, 실패(오프라인/비공개
# 저장소/요청 한도)는 조용히 무시하고 정상 시작합니다. 새 버전이 있으면 우하단
# 버전 표시가 다운로드 링크로 바뀝니다. 무인 운용을 방해하지 않도록 팝업은
# 절대 띄우지 않습니다.
$script:updateCheckPs = [System.Management.Automation.PowerShell]::Create()
[void]$script:updateCheckPs.AddScript({
    try {
      # PS 5.1 기본 설정에는 TLS 1.2가 빠져 있을 수 있어 추가합니다 (3072 = Tls12)
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
      # User-Agent 헤더가 없으면 GitHub API가 요청을 거부합니다
      $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Myodong/HoneyNogi/releases/latest' `
        -Headers @{ 'User-Agent' = 'HoneyNogi-UpdateCheck' } -TimeoutSec 5
      return [string]$release.tag_name
    } catch { return '' }
  })
$script:updateCheckAsync = $script:updateCheckPs.BeginInvoke()
$script:updateTimer = New-Object System.Windows.Forms.Timer
$script:updateTimer.Interval = 1000
$script:updateTimer.Add_Tick({
    try {
    if (-not $script:updateCheckAsync.IsCompleted) { return }
    $script:updateTimer.Stop()
    $tag = ''
    try {
      $checkResult = $script:updateCheckPs.EndInvoke($script:updateCheckAsync)
      if ($checkResult -and $checkResult.Count -gt 0) { $tag = [string]$checkResult[0] }
    } catch { }
    try { $script:updateCheckPs.Dispose() } catch { }
    $remoteVersion = $null
    if (-not [System.Version]::TryParse(($tag -replace '^[vV]', ''), [ref]$remoteVersion)) { return }
    if ($remoteVersion -le [System.Version]$appVersion) { return }
    $lblVersion.Visible = $false
    $lnkUpdate.Text = "새 버전 v$remoteVersion 다운로드"
    $lnkUpdate.Visible = $true
    # 구버전 실행 시 새 버전 안내 팝업 (확인 1번 = 안내만, 자동 동작 없음).
    # 자동화가 이미 실행 중이면 팝업으로 방해하지 않고 우하단 링크만 보여줍니다.
    # 시작 승인 조회 대기 중에도 생략 (2026-08-01 전수 점검: 조회 중에는 running 이 아직
    # false 라 팝업이 뜰 수 있고, 모달이 열린 사이 승인 완료 → 워커가 팝업을 띄운 채 시작돼
    # '실행 중 팝업 생략' 규칙이 우회됐음)
    if (-not $script:running -and -not $script:approvalPendingStart) {
      [System.Windows.Forms.MessageBox]::Show(
        $form,
        ("새 버전 v$remoteVersion 이 나왔습니다!" + [Environment]::NewLine + [Environment]::NewLine +
          "우측 하단의 '새 버전 다운로드' 링크를 누르면" + [Environment]::NewLine +
          "다운로드 페이지가 열립니다."),
        '꿀비노기 업데이트 안내',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
    } catch {
      # 타이머 핸들러의 예외는 반드시 여기서 멈춰야 합니다 - 밖으로 나가면 PS 5.1 WinForms 가
      # 모달 오류 창을 띄워 메시지 루프가 정지하고, 무인 운용에서는 아무도 그 창을 못 닫습니다
      # (2026-08-10 10차 점검 - 실행으로 확인). 사유는 로그로 남기고 다음 틱에서 이어갑니다.
      try { Add-GuiLog "[오류] 내부 타이머(업데이트 확인) 처리 중 예외 - 자동화는 계속 시도합니다: $($_.Exception.Message)" } catch { }
    }
  })
$script:updateTimer.Start()

try {
  [void]$form.ShowDialog()
} finally {
  # 창을 닫을 때 폴링 타이머·업데이트 러닝스페이스·전역 뮤텍스를 명시적으로 정리합니다.
  # 프로세스 종료에만 맡기면 업데이트 확인 중 닫은 직후 재실행 시 뮤텍스가 잠깐 남을 수 있습니다.
  foreach ($uiTimer in @($hotkeyTimer, $timer, $script:updateTimer, $script:approvalTimer, $script:lifeSlideTimer, $script:timerResizeResult)) {
    if ($uiTimer) {
      try { $uiTimer.Stop() } catch { }
      try { $uiTimer.Dispose() } catch { }
    }
  }
  # ★ 아직 **끝나지 않은** 조회에는 동기 Stop()/Dispose() 를 부르면 안 됩니다. 둘 다 실행 중
  #   파이프라인이 끝날 때까지 블로킹합니다(PS 5.1 실측: 12초 슬립에 Stop 11.5초). 여기는
  #   폼 종료 경로라, 그 몇 분 동안 **프로세스가 살아 있는 채 Global 뮤텍스를 쥐고 있어**
  #   사용자가 컨트롤 패널을 다시 켜면 '이미 실행 중'으로 차단됩니다. 창은 이미 닫혔는데
  #   다시 열리지도 않는, 사용자 눈에는 완전한 고장입니다 (2026-08-10 10차 점검 -
  #   9차에서 타이머 쪽만 걷어내고 이 종료 경로는 그대로 남아 있었습니다).
  #   → 끝난 것만 정리하고, 진행 중인 것은 **비동기 정지 요청만** 던지고 버립니다.
  #     프로세스가 곧 끝나므로 러닝스페이스도 함께 사라집니다.
  foreach ($pendingPs in @(
      @{ Ps = $script:updateCheckPs; Async = $script:updateCheckAsync },
      @{ Ps = $script:approvalPs;    Async = $script:approvalAsync })) {
    if (-not $pendingPs.Ps) { continue }
    $stillRunning = ($pendingPs.Async -and -not $pendingPs.Async.IsCompleted)
    if ($stillRunning) {
      try { [void]$pendingPs.Ps.BeginStop($null, $null) } catch { }
      continue   # Dispose 도 블로킹이므로 부르지 않습니다
    }
    try { $pendingPs.Ps.Dispose() } catch { }
  }
  # 진행 중 슬라이드 정리 (스트립 Bitmap 등 - PictureBox.Dispose 는 Image 를 해제하지 않음.
  # 폼 종료 경로라 UI 복원 생략 - 리뷰 조건)
  try { Stop-LifeSlideNow -SkipUiRefresh } catch { }
  try { $form.Dispose() } catch { }
  # 생활 스킬 아이콘 Bitmap 해제 - Button.Dispose 는 할당된 Image 를 해제하지 않음 (리뷰 실험 확인)
  foreach ($lifeIconBmp in @($script:lifeSkillIcons.Values)) {
    try { $lifeIconBmp.Dispose() } catch { }
  }
  try { $script:lifeSkillIcons.Clear() } catch { }
  if ($guiMutexAcquired) {
    try { $script:guiMutex.ReleaseMutex() } catch { }
  }
  try { $script:guiMutex.Dispose() } catch { }
}
