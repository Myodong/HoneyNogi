# Redirects disconnected RDP sessions to the physical console so that
# screen rendering continues and the OCR-based automation keeps working.
# Triggered automatically by the scheduled task 'HoneyNogiRDPToConsole'
# whenever an RDP session disconnects (Event ID 24).
$ErrorActionPreference = 'SilentlyContinue'
$logDir = Join-Path $PSScriptRoot 'Log'
$logPath = Join-Path $logDir 'rdp_redirect.log'

function Write-RedirectLog {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    # Add-Content cannot create the directory itself; without this the retry loop
    # below would fail 10 times and silently drop the log line.
    if (-not (Test-Path -LiteralPath $logDir)) {
        try { New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null } catch { return }
    }
    for ($i = 0; $i -lt 10; $i++) {
        try { Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8 -ErrorAction Stop; break }
        catch { Start-Sleep -Milliseconds 50 }
    }
}

# Give the session a moment to settle into the Disconnected state.
Start-Sleep -Seconds 2

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WtsApi {
  [StructLayout(LayoutKind.Sequential)]
  public struct WTS_SESSION_INFO { public int SessionId; public IntPtr pWinStationName; public int State; }
  [DllImport("wtsapi32.dll", SetLastError=true)]
  public static extern bool WTSEnumerateSessions(IntPtr hServer, int Reserved, int Version, out IntPtr ppSessionInfo, out int pCount);
  [DllImport("wtsapi32.dll")]
  public static extern void WTSFreeMemory(IntPtr pMemory);
}
'@

$pp = [IntPtr]::Zero
$count = 0
if (-not [WtsApi]::WTSEnumerateSessions([IntPtr]::Zero, 0, 1, [ref]$pp, [ref]$count)) {
    Write-RedirectLog 'WTSEnumerateSessions failed'
    exit
}

$size = [System.Runtime.InteropServices.Marshal]::SizeOf([type][WtsApi+WTS_SESSION_INFO])
$disconnected = @()
for ($i = 0; $i -lt $count; $i++) {
    $ptr = [IntPtr]($pp.ToInt64() + $i * $size)
    $info = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][WtsApi+WTS_SESSION_INFO])
    # State 4 = WTSDisconnected. Session 0 is services; never touch it.
    if ($info.State -eq 4 -and $info.SessionId -gt 0) {
        $disconnected += $info.SessionId
    }
}
[WtsApi]::WTSFreeMemory($pp)

if ($disconnected.Count -eq 0) {
    Write-RedirectLog 'no disconnected session found (nothing to do)'
    exit
}

foreach ($sessionId in $disconnected) {
    $result = & tscon $sessionId /dest:console 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-RedirectLog "session $sessionId redirected to console (automation keeps running)"
        break
    } else {
        Write-RedirectLog "tscon $sessionId failed: $result"
    }
}
