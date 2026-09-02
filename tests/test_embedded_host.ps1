# 임베디드 PowerShell 호스트 배선 가드 (v2.1.4 작업 관리자 브랜딩)
# 본체: build\launcher.cs (HoneyNogiHost) + mabinogi_gui.ps1 (감지/스폰 분기/정리 확장)
#       + mabinogi_run_once.ps1 ([설정] 호스트 표기) + build\build_exe.ps1 (SMA 참조)
# 호스트 실행 동작 자체(exit 코드 보존, RawUI, OCR)는 코드로 흉내 낼 수 없어 실기
# 검증 매트릭스가 담당합니다 (규칙 9). 여기서는 다음을 지킵니다:
#  ① 세 파일에 흩어진 호스트 이름('HoneyNogiHost') 계약이 서로 일치
#  ② 스폰/정리 분기가 소스에서 사라지지 않음 (앵커)
#  ③ 설계 합의의 금지 사항(AddScript, 즉시 Environment.Exit)이 다시 들어오지 않음
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$guiText = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_gui.ps1') -Raw -Encoding UTF8
$workerText = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
$launcherText = Get-Content -LiteralPath (Join-Path $projectRoot 'build\launcher.cs') -Raw -Encoding UTF8
$buildText = Get-Content -LiteralPath (Join-Path $projectRoot 'build\build_exe.ps1') -Raw -Encoding UTF8
# 금지 단언(AddScript/Environment.Exit 부재)은 주석을 뺀 사본으로 - 주석이 금지어를
# '언급'만 해도 걸립니다 (진리표 규칙: 소스 문자열 단언은 주석 제외 사본으로).
# 줄 단위 // 제거는 문자열 리터럴 안의 // 를 구분하지 못하지만 launcher.cs 에는 그런
# 리터럴이 없습니다 (생기면 이 스트리퍼도 함께 손볼 것).
$launcherCode = (($launcherText -split "`r?`n") | ForEach-Object { ($_ -split '//', 2)[0] }) -join "`n"

# ---- 1. 호스트 이름 계약 교차 검증 (launcher.cs ↔ gui.ps1 ↔ run_once.ps1) ----
# 이름이 한쪽만 바뀌면 감지가 조용히 죽고 임베디드 GUI 가 powershell 스폰으로 후퇴합니다.
$launcherHostName = $(if ($launcherText -match 'Name \{ get \{ return "([^"]+)"; \} \}') { $Matches[1] } else { '' })
$guiHostName = $(if ($guiText -match "\`$Host\.Name -eq '([^']+)'") { $Matches[1] } else { '' })
$workerHostName = $(if ($workerText -match "\`$Host\.Name -eq '([^']+)'") { $Matches[1] } else { '' })
Assert-Case '호스트 이름: launcher.cs 정의' $launcherHostName 'HoneyNogiHost'
Assert-Case '호스트 이름: gui.ps1 감지 일치' $guiHostName $launcherHostName
Assert-Case '호스트 이름: run_once.ps1 [설정] 표기 일치' $workerHostName $launcherHostName

# ---- 2. GUI 감지 이중 확인 (호스트 이름 + 주입 env + 파일 존재) ----
Assert-Case '감지: 주입 환경변수 확인' ($guiText.Contains('$env:HONEYNOGI_HOST_EXE') -and
  $guiText.Contains('$script:hostedExePath')) 'True'
Assert-Case '감지: exe 실재 확인(Test-Path)' `
  ($guiText -match "Test-Path -LiteralPath \`$env:HONEYNOGI_HOST_EXE") $true

# ---- 3. 스폰 분기 (워커 + 리사이즈 헬퍼) ----
Assert-Case '스폰: 워커 임베디드 분기(--run + $workerScript)' `
  ($guiText.Contains(('''--run'', (''"'' + $workerScript + ''"''))'))) 'True'
Assert-Case '스폰: 워커 기존 powershell 분기 보존' `
  ($guiText.Contains("Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList `$arguments -PassThru")) 'True'
Assert-Case '스폰: 리사이즈 헬퍼 임베디드 분기(--run + $helper)' `
  ($guiText.Contains(('@(''--run'', (''"'' + $helper + ''"''))'))) 'True'

# ---- 4. 정리 확장 (호스트 프로세스 열거) ----
Assert-Case '정리: Stop-ExistingAutomation 호스트 워커 열거(LIKE + --run)' `
  (($guiText -match "Name LIKE 'HoneyNogi%\.exe'") -and $guiText.Contains("`$_.CommandLine -match '--run' -and `$_.CommandLine -match `$pattern")) 'True'
Assert-Case '정리: Invoke-OldProcessShutdown 호스트 CIM 열거' `
  ($guiText.Contains('$cimRows += @(Get-CimInstance -ClassName Win32_Process -Filter "Name LIKE ''HoneyNogi%.exe''"')) 'True'
Assert-Case '정리: 스냅샷 루프에 HoneyNogi 프로세스 포함' `
  ($guiText.Contains("Get-Process -Name 'HoneyNogi*' -ErrorAction SilentlyContinue")) 'True'
Assert-Case '정리: 현재 버전 호스트 GUI 레이스 보호(--embedded-host)' `
  ($guiText.Contains("`$procCmd.IndexOf('--embedded-host'")) 'True'
Assert-Case '정리: Select-OldGuiProcesses 호스트 분기' `
  ($guiText.Contains("`$snapshotCmd.IndexOf('--embedded-host'")) 'True'

# ---- 5. launcher.cs 설계 합의 앵커 ----
Assert-Case '호스트: 실행 정책 Bypass 명시(기본 Restricted 실측)' `
  ($launcherText.Contains('ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass')) 'True'
# 2026-09-01 실사용 고장(v2.1.4): AddCommand(경로) 실행은 스크립트 함수를 새 스크립트
# 스코프에 가둬, GUI 셀 편집의 GetNewClosure 클로저 delegate 가 Invoke-CellEditApply 를
# CommandNotFound 로 못 찾았다. -File 과 같은 실행 의미(함수 글로벌 정의)는 **글로벌
# dot-source**(". '경로'") 뿐 - 아래 실행형 진리표가 그 기전을 영구 재현한다.
Assert-Case '호스트: 글로벌 dot-source 실행(". 경로" - 함수 글로벌 정의)' `
  ($launcherCode.Contains('ps.AddScript(". ''" + scriptPath.Replace("''", "''''") + "''")')) 'True'
Assert-Case '호스트: AddCommand(경로) 실행 금지(스코프 격리 - 셀 편집 고장 기전)' `
  ($launcherCode.Contains('ps.AddCommand(scriptPath)')) 'False'
Assert-Case '호스트: STA + 현재 스레드(WinForms/WinRT OCR)' `
  ($launcherText.Contains('ApartmentState = ApartmentState.STA') -and
   $launcherText.Contains('ThreadOptions = PSThreadOptions.UseCurrentThread')) 'True'
Assert-Case '호스트: SetShouldExit 는 저장만(즉시 Environment.Exit 금지)' `
  ($launcherCode.Contains('Environment.Exit')) 'False'
Assert-Case '호스트: RawUI WindowTitle setter(워커 1974행 제목 설정)' `
  ($launcherText -match 'public override string WindowTitle \{ get [^\r\n]+ set \{') $true
# --embedded-host 인자는 별도 비교 없이 '레거시가 아닌 모든 인자 = 임베디드' 설계로 흡수
# (시험 기간 바로가기 하위 호환 - 기본 전환 단언이 그 계약을 지킴)
Assert-Case '호스트: --run 모드 존재' ($launcherText.Contains('"--run"')) 'True'
Assert-Case '호스트: --run 오류 팝업 금지(무인 운용 - showErrorPopup false)' `
  ($launcherText -match '"--run"[\s\S]{0,400}?RunHostedScript\([^\r\n]+,\s*false\)') $true
# 2026-09-01 사용자 확정: 더블클릭 기본이 임베디드 (옵트인 시험 졸업). 레거시 powershell
# 스폰은 --legacy-powershell 폴백으로만 남습니다 - 폴백이 사라지면 탈출구가 없어집니다.
Assert-Case '호스트: 기본 = 임베디드(레거시 인자만 예외)' `
  ($launcherCode.Contains('bool embeddedGui = !legacyGui;') -and
   $launcherText.Contains('"--legacy-powershell"')) 'True'
Assert-Case '호스트: 레거시 폴백 powershell 스폰 보존(탈출구)' `
  ($launcherText.Contains('System32\WindowsPowerShell\v1.0\powershell.exe')) 'True'
# 2026-09-01 실측: API(Invoke) 경로에서는 exit 가 SetShouldExit 를 부르지 않고 런스페이스
# 전역 $LASTEXITCODE 에만 남습니다. 이 회수가 빠지면 워커 코드 0/4/10 분기가 전부 0 이 되어
# GUI 회차 처리가 무너집니다 (첫 빌드에서 실제로 겪음 - 종료 코드 7종 전부 0).
Assert-Case '호스트: 종료 코드 LASTEXITCODE 회수(실측 계약)' `
  ($launcherText.Contains('PSVariable.GetValue("LASTEXITCODE")')) 'True'

# ---- 6. 빌드 스크립트 (SMA 참조 + 5.1 Desktop 강제) ----
Assert-Case '빌드: SMA 참조 추가' ($buildText.Contains('"/reference:$smaPath"')) 'True'
Assert-Case '빌드: 5.1 Desktop 강제(pwsh 차단)' `
  ($buildText.Contains("`$PSVersionTable.PSEdition -ne 'Desktop'")) 'True'
Assert-Case '빌드: GAC SMA 버전 3.0.0.0 검증' ($buildText -match '\.Version\.Major -ne 3') $true
Assert-Case '빌드: AssemblyTitle 꿀비노기(작업 관리자 표시명)' `
  ($buildText.Contains('AssemblyTitle("꿀비노기")')) 'True'

# ---- 7. 워커 [설정] 호스트 표기 ----
Assert-Case '워커: [설정] 줄에 호스트 구분 표기' `
  ($workerText.Contains('$hostModeInfo') -and $workerText.Contains('v$appVersionInfo($hostModeInfo)')) 'True'

# ---- 8. 실행형 재현: GetNewClosure delegate 함수 조회 (2026-09-01 v2.1.4 실사용 고장) ----
# GUI 셀 편집(gui.ps1 3085/5597)은 GetNewClosure 클로저를 [Action] delegate 로 실행한다.
# 클로저는 새 동적 모듈에 묶여 함수 조회가 '자기 모듈 → 글로벌 폴백'뿐이므로, 러너가
# 스크립트를 AddCommand(새 스크립트 스코프)로 실행하면 함수를 못 찾아 CommandNotFound.
# 글로벌 dot-source 만 -File 과 같은 의미(함수 글로벌 정의)다. 앵커가 아니라 **실제 실행**
# 으로 두 방식을 재현해 계약을 고정한다 (임시 러너는 기본 runspace - 호스트 구현과 무관한
# 스코프 기전 자체의 진리표).
$reproDir = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_host_repro_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reproDir | Out-Null
$reproScript = Join-Path $reproDir 'closure_probe.ps1'
@'
function Test-EmbeddedHostReproTarget { return 'found' }
$probe = 'not-run'
try {
    $action = [Action]({ $global:embeddedHostRepro = (Test-EmbeddedHostReproTarget) }.GetNewClosure())
    $action.Invoke()
    $probe = [string]$global:embeddedHostRepro
} catch { $probe = 'EX:' + $_.Exception.GetType().Name }
Set-Content -LiteralPath (Join-Path $PSScriptRoot 'closure_result.txt') -Value $probe -Encoding UTF8
'@ | Set-Content -LiteralPath $reproScript -Encoding UTF8
$reproResult = Join-Path $reproDir 'closure_result.txt'
function Invoke-HostReproRunner {
  param([string]$Mode)
  Remove-Item -LiteralPath $reproResult -ErrorAction SilentlyContinue
  $reproRunspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
  $reproRunspace.Open()
  $reproPs = [System.Management.Automation.PowerShell]::Create()
  $reproPs.Runspace = $reproRunspace
  if ($Mode -eq 'dot') { $null = $reproPs.AddScript(". '" + $reproScript.Replace("'", "''") + "'").AddCommand('Out-Null') }
  else { $null = $reproPs.AddCommand($reproScript).AddCommand('Out-Null') }
  try { $null = $reproPs.Invoke() } catch { }
  $reproPs.Dispose(); $reproRunspace.Dispose()
  if (Test-Path -LiteralPath $reproResult) { return ([IO.File]::ReadAllText($reproResult)).Trim() }
  return '(no result)'
}
Assert-Case '재현: dot-source 러너는 클로저 delegate 가 함수를 찾는다' (Invoke-HostReproRunner -Mode 'dot') 'found'
Assert-Case '재현: AddCommand 러너는 CommandNotFound (금지 근거 - 셀 편집 고장 기전)' `
  ((Invoke-HostReproRunner -Mode 'cmd') -like 'EX:*') 'True'
Remove-Item -Recurse -Force $reproDir -ErrorAction SilentlyContinue

if ($fails -gt 0) { Write-Output "FAIL 합계: $fails"; exit 1 }
Write-Output '전체 통과'
exit 0
