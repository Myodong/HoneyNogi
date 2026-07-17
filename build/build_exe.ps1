# 마비노기자동화.exe 빌드 스크립트
# outputs2 의 스크립트들을 리소스로 내장한 단일 실행 파일을 만듭니다.
$ErrorActionPreference = 'Stop'
$buildDir = $PSScriptRoot
$root = Split-Path $buildDir -Parent

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "csc.exe not found: $csc" }

$exePath = Join-Path $root 'MabinogiAuto.exe'

# 앱 버전을 gui.ps1 에서 추출해 exe 파일 속성(제품/파일 버전)에 새깁니다.
# 파일명은 고정이지만, 탐색기에서 exe 우클릭 → 속성 → 자세히로 버전 확인 가능.
# (주의: $cscArgs 배열보다 먼저 정의되어야 $asmInfoPath 가 배열에 제대로 들어갑니다)
$guiText = Get-Content (Join-Path $root 'mabinogi_gui.ps1') -Raw -Encoding UTF8
$appVersion = if ($guiText -match "\`$appVersion\s*=\s*'([\d\.]+)'") { $Matches[1] } else { throw 'appVersion 을 gui.ps1 에서 찾지 못했습니다' }
$asmInfoPath = Join-Path $buildDir 'AssemblyInfo.generated.cs'
@"
using System.Reflection;
[assembly: AssemblyTitle("마비노기 모바일 자동화")]
[assembly: AssemblyProduct("MabinogiAuto")]
[assembly: AssemblyVersion("$appVersion")]
[assembly: AssemblyFileVersion("$appVersion")]
"@ | Set-Content -LiteralPath $asmInfoPath -Encoding UTF8

$cscArgs = @(
  '/nologo', '/target:winexe', '/platform:anycpu', '/codepage:65001',
  "/out:$exePath",
  "/win32manifest:$buildDir\app.manifest",
  '/reference:System.Windows.Forms.dll',
  "/resource:$root\mabinogi_gui.ps1,gui.ps1",
  "/resource:$root\mabinogi_run_once.ps1,run_once.ps1",
  "/resource:$root\rdp_redirect_console.ps1,redirect.ps1",
  "/resource:$root\config.json,config.json",
  "$buildDir\launcher.cs",
  $asmInfoPath
)

# 좌표 버전 일치 검사: run_once.ps1 의 $coordsVersionCurrent 와 config.json 의
# coordsVersion 이 다르면 (좌표를 바꾸며 한쪽만 올린 실수) 빌드를 중단합니다.
$runOnceText = Get-Content (Join-Path $root 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
$scriptVer = if ($runOnceText -match '\$coordsVersionCurrent\s*=\s*(\d+)') { [int]$Matches[1] } else { throw 'coordsVersionCurrent 를 run_once.ps1 에서 찾지 못했습니다' }
$configVer = [int](Get-Content (Join-Path $root 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json).coordsVersion
if ($scriptVer -ne $configVer) {
  throw "BUILD FAILED: 좌표 버전 불일치 - run_once.ps1($scriptVer) vs config.json($configVer). 좌표를 바꿨다면 두 값을 함께 올리세요."
}

# 이전 빌드 산출물이 남아 있으면 컴파일이 실패해도 Test-Path 가 참이 되어
# 'BUILD OK'로 오판할 수 있으므로, 빌드 전에 지웁니다 (exe 실행 중이면 여기서 명확히 실패).
if (Test-Path $exePath) { Remove-Item -LiteralPath $exePath -Force }

& $csc @cscArgs
if ($LASTEXITCODE -ne 0) {
  throw "BUILD FAILED: csc exit code $LASTEXITCODE"
}

if (Test-Path $exePath) {
  $size = [Math]::Round((Get-Item $exePath).Length / 1KB, 1)
  Write-Host "BUILD OK: $exePath (v$appVersion, $size KB)"
} else {
  throw 'BUILD FAILED: exe not produced'
}
