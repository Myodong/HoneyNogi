# 사용 승인(화이트리스트) + 구버전 exe 자동 삭제 판정 진리표
# 본체: mabinogi_gui.ps1 (Get-DeviceCode / Test-WhitelistResponse / Get-ApprovalDecision /
#       Get-CleanupPlan / Test-OldGuiTitle / Select-OldGuiProcesses / Test-ReleaseManifest /
#       Select-OldExeTargets) - 실함수를 AST 로 추출해 진리표 검증 (2026-07-27 Codex 설계 합의)
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Get-DeviceCode', 'Test-WhitelistResponse', 'Get-ApprovalDecision', 'Get-CleanupPlan',
      'Test-OldGuiTitle', 'Select-OldGuiProcesses', 'Test-ReleaseManifest', 'Select-OldExeTargets',
      'Select-OldZipTargets', 'Get-ZipEntryInfos')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ---- 1. 기기 코드 (Get-DeviceCode) ----
$codeA = Get-DeviceCode -MachineGuid 'ABCD-1234'
Assert-Case '기기 코드: 64자리 소문자 hex' ($codeA -match '^[0-9a-f]{64}$') $true
Assert-Case '기기 코드: 결정적(같은 입력 = 같은 코드)' (Get-DeviceCode -MachineGuid 'ABCD-1234') $codeA
Assert-Case '기기 코드: 정규화(공백/중괄호/대문자 무시)' (Get-DeviceCode -MachineGuid ' {abcd-1234} ') $codeA
Assert-Case '기기 코드: 다른 GUID 는 다른 코드' ((Get-DeviceCode -MachineGuid 'XYZ') -ne $codeA) $true
Assert-Case '기기 코드: 빈 GUID 는 빈 코드(차단측 - 빈 문자열 해시 금지)' (Get-DeviceCode -MachineGuid '') ''
Assert-Case '기기 코드: 중괄호만 있는 GUID 도 빈 코드' (Get-DeviceCode -MachineGuid ' {} ') ''

# ---- 2. 명단 응답 검증 (Test-WhitelistResponse) ----
$h1 = 'a' * 64
$h2 = 'b' * 64
$respCases = @(
  @{ N = '정상 LF 2건';            T = "HONEYNOGI-WL-V1`nCOUNT=2`n$h1`n$h2";          V = $true;  C = 2 }
  @{ N = '정상 CRLF + 끝 개행';     T = "HONEYNOGI-WL-V1`r`nCOUNT=1`r`n$h1`r`n";       V = $true;  C = 1 }
  @{ N = '선두 BOM 허용';          T = ([char]0xFEFF + "HONEYNOGI-WL-V1`nCOUNT=1`n$h1"); V = $true; C = 1 }
  @{ N = '빈 명단(COUNT=0)';       T = "HONEYNOGI-WL-V1`nCOUNT=0";                    V = $true;  C = 0 }
  @{ N = 'COUNT 불일치';           T = "HONEYNOGI-WL-V1`nCOUNT=2`n$h1";               V = $false; C = 0 }
  @{ N = '중복 코드';              T = "HONEYNOGI-WL-V1`nCOUNT=2`n$h1`n$h1";          V = $false; C = 0 }
  @{ N = '63자리 코드';            T = "HONEYNOGI-WL-V1`nCOUNT=1`n" + ('a' * 63);     V = $false; C = 0 }
  @{ N = '대문자 코드(정규화는 서버 몫)'; T = "HONEYNOGI-WL-V1`nCOUNT=1`n" + ('A' * 64); V = $false; C = 0 }
  @{ N = '중간 빈 줄';             T = "HONEYNOGI-WL-V1`nCOUNT=2`n$h1`n`n$h2";        V = $false; C = 0 }
  @{ N = '매직 토큰 없음(HTML 오류 페이지)'; T = "<html><body>Error</body></html>";   V = $false; C = 0 }
  @{ N = '매직 토큰 오타';         T = "HONEYNOGI-WL-V2`nCOUNT=1`n$h1";               V = $false; C = 0 }
  @{ N = '빈 응답(전송 실패)';      T = '';                                            V = $false; C = 0 }
  @{ N = 'COUNT 5자리(상한 초과)'; T = "HONEYNOGI-WL-V1`nCOUNT=10000`n$h1";           V = $false; C = 0 }
)
foreach ($case in $respCases) {
  $parsed = Test-WhitelistResponse -Text $case.T
  Assert-Case "응답 [$($case.N)]: Valid" $parsed.Valid $case.V
  Assert-Case "응답 [$($case.N)]: 코드 수" (@($parsed.Codes).Count) $case.C
}
$hugeResp = "HONEYNOGI-WL-V1`nCOUNT=1`n$h1" + ('x' * 70000)
Assert-Case '응답 [크기 상한 64KB 초과]: Valid' (Test-WhitelistResponse -Text $hugeResp).Valid $false

# ---- 3. 승인 판정 (Get-ApprovalDecision) ----
$nowUtc = [datetime]::new(2026, 7, 27, 12, 0, 0, [System.DateTimeKind]::Utc)
function Format-CacheTime { param([datetime]$Value) $Value.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") }
$decisionCases = @(
  @{ N = '조회 성공 + 명단에 있음';   F = $true;  L = @($h1, $codeA); At = '';  Dev = $codeA; E = 'approved-live' }
  @{ N = '조회 성공 + 명단에 없음(철회)'; F = $true; L = @($h1);      At = (Format-CacheTime $nowUtc.AddDays(-1)); Dev = $codeA; E = 'denied' }
  @{ N = '조회 성공 + 빈 명단';       F = $true;  L = @();            At = '';  Dev = $codeA; E = 'denied' }
  @{ N = '기기 코드 산출 불가';       F = $true;  L = @($h1);         At = '';  Dev = '';     E = 'no-cache' }
  @{ N = '조회 실패 + 1일 전 캐시';   F = $false; L = @();            At = (Format-CacheTime $nowUtc.AddDays(-1)); Dev = $codeA; E = 'approved-grace' }
  @{ N = '조회 실패 + 정확히 7일 캐시(경계 포함)'; F = $false; L = @(); At = (Format-CacheTime $nowUtc.AddDays(-7)); Dev = $codeA; E = 'approved-grace' }
  @{ N = '조회 실패 + 7일 1분 초과';  F = $false; L = @();            At = (Format-CacheTime $nowUtc.AddDays(-7).AddMinutes(-1)); Dev = $codeA; E = 'no-cache' }
  @{ N = '조회 실패 + 미래 시각 캐시(시계 조작/오류)'; F = $false; L = @(); At = (Format-CacheTime $nowUtc.AddMinutes(5)); Dev = $codeA; E = 'no-cache' }
  @{ N = '조회 실패 + 캐시 없음';     F = $false; L = @();            At = '';  Dev = $codeA; E = 'no-cache' }
  @{ N = '조회 실패 + 날짜 형식 오류'; F = $false; L = @();           At = '2026-07-27 12:00:00'; Dev = $codeA; E = 'no-cache' }
)
foreach ($case in $decisionCases) {
  $cacheDev = $(if ($case.At -ne '') { $case.Dev } else { '' })
  $decision = Get-ApprovalDecision -FetchOk $case.F -Codes $case.L -DeviceCode $case.Dev `
    -CacheApprovedAtUtc $case.At -CacheDeviceCode $cacheDev -NowUtc $nowUtc -GraceDays 7
  Assert-Case "판정 [$($case.N)]" $decision $case.E
}
Assert-Case '판정 [캐시 기기 불일치(다른 PC 캐시 복사)]' (Get-ApprovalDecision -FetchOk:$false -Codes @() -DeviceCode $codeA `
    -CacheApprovedAtUtc (Format-CacheTime $nowUtc.AddDays(-1)) -CacheDeviceCode $h1 -NowUtc $nowUtc -GraceDays 7) 'no-cache'

# ---- 4. 정리 단계 판정 (Get-CleanupPlan) ----
$planCases = @(
  @{ N = '마커 없음(최초 도입)';        D = '';      P = $false; E = 'full' }
  @{ N = '이전 버전 마커(업데이트)';    D = '1.1.3'; P = $false; E = 'full' }
  @{ N = '현재 버전 + 잔여 없음';       D = '1.2.0'; P = $false; E = 'skip' }
  @{ N = '현재 버전 + 잔여 있음(무팝업 재시도)'; D = '1.2.0'; P = $true; E = 'files-only' }
  @{ N = '미래 버전 마커(다운그레이드 실행)';  D = '1.3.0'; P = $true;  E = 'skip' }
  @{ N = '마커 손상';                  D = 'abc';   P = $false; E = 'full' }
)
foreach ($case in $planCases) {
  Assert-Case "정리 계획 [$($case.N)]" (Get-CleanupPlan -DoneVersion $case.D -Pending $case.P -CurrentVersion '1.2.0') $case.E
}

# ---- 5. 실행 중 구버전 GUI 판정 (Test-OldGuiTitle / Select-OldGuiProcesses) ----
$titleCases = @(
  @{ N = '구버전 제목';        T = '꿀비노기 컨트롤 패널 v1.1.3';        E = $true }
  @{ N = '같은 버전(신버전 중복 실행)'; T = '꿀비노기 컨트롤 패널 v1.2.0'; E = $false }
  @{ N = '더 높은 버전(문자열 비교였다면 오판)'; T = '꿀비노기 컨트롤 패널 v1.10.0'; E = $false }
  @{ N = '버전 형식 오류(1..2)'; T = '꿀비노기 컨트롤 패널 v1..2';        E = $false }
  @{ N = '빈 제목(식별 불가 = 보존)'; T = '';                             E = $false }
  @{ N = '제목 뒤 추가 문자(엄격 일치)'; T = '꿀비노기 컨트롤 패널 v1.1.3 - 대기'; E = $false }
  @{ N = '무관한 창 제목';     T = 'Windows PowerShell';                  E = $false }
)
foreach ($case in $titleCases) {
  Assert-Case "제목 판정 [$($case.N)]" (Test-OldGuiTitle -Title $case.T -CurrentVersion '1.2.0') $case.E
}
$guiScriptPath = 'C:\Users\U\AppData\Local\HoneyNogi\mabinogi_gui.ps1'
$guiCmd = 'powershell.exe -File ' + $guiScriptPath
$procSnapshots = @(
  @{ Id = 1001; Title = '꿀비노기 컨트롤 패널 v1.1.3'; CommandLine = $guiCmd }                       # 대상
  @{ Id = 1002; Title = '꿀비노기 컨트롤 패널 v1.1.3'; CommandLine = 'powershell.exe -File C:\other.ps1' } # 명령줄 불일치 = 보존
  @{ Id = 1003; Title = '';                             CommandLine = $guiCmd }                       # 제목 없음 = 보존
  @{ Id = 1004; Title = '꿀비노기 컨트롤 패널 v1.2.0'; CommandLine = $guiCmd }                       # 현재 버전 = 보존
  @{ Id = $PID; Title = '꿀비노기 컨트롤 패널 v1.1.3'; CommandLine = $guiCmd }                       # 자기 PID = 보존
  @{ Id = 1005; Title = '꿀비노기 컨트롤 패널 v1.1.3';                                               # 다른 윈도우 사용자 세션 = 보존 (Codex #1)
     CommandLine = 'powershell.exe -File C:\Users\OTHER\AppData\Local\HoneyNogi\mabinogi_gui.ps1' }
  @{ Id = 1006; Title = '꿀비노기 컨트롤 패널 v1.1.3';                                               # 대소문자 차이는 같은 경로로 인정
     CommandLine = 'powershell.exe -File C:\USERS\U\APPDATA\Local\HoneyNogi\MABINOGI_GUI.PS1' }
)
$selected = @(Select-OldGuiProcesses -Snapshots $procSnapshots -CurrentVersion '1.2.0' -GuiScriptPath $guiScriptPath)
Assert-Case '프로세스 선정: 대상 2개(본인 경로만, 대소문자 무시)' $selected.Count 2
Assert-Case '프로세스 선정: PID 1001 포함' (@($selected | Where-Object { $_.Id -eq 1001 }).Count) 1
Assert-Case '프로세스 선정: PID 1006 포함(대소문자 무시)' (@($selected | Where-Object { $_.Id -eq 1006 }).Count) 1
Assert-Case '프로세스 선정: 경로 미지정 시 전부 보존(실패 폐쇄)' `
  (@(Select-OldGuiProcesses -Snapshots $procSnapshots -CurrentVersion '1.2.0' -GuiScriptPath '').Count) 0

# ---- 6. 릴리스 해시 대장 검증 + 삭제 대상 선정 ----
$manifestGood = [pscustomobject]@{ releases = @(
    [pscustomobject]@{ version = '1.1.3'; sha256 = $h1 }
    [pscustomobject]@{ version = '1.2.0'; sha256 = $h2 }
  ) }
Assert-Case '대장 검증: 정상' (Test-ReleaseManifest -Manifest $manifestGood) $true
Assert-Case '대장 검증: null' (Test-ReleaseManifest -Manifest $null) $false
Assert-Case '대장 검증: 빈 목록' (Test-ReleaseManifest -Manifest ([pscustomobject]@{ releases = @() })) $false
Assert-Case '대장 검증: 버전 손상' (Test-ReleaseManifest -Manifest ([pscustomobject]@{ releases = @([pscustomobject]@{ version = 'x'; sha256 = $h1 }) })) $false
Assert-Case '대장 검증: 해시 63자리' (Test-ReleaseManifest -Manifest ([pscustomobject]@{ releases = @([pscustomobject]@{ version = '1.1.3'; sha256 = ('a' * 63) }) })) $false
Assert-Case '대장 검증: 버전 중복' (Test-ReleaseManifest -Manifest ([pscustomobject]@{ releases = @(
        [pscustomobject]@{ version = '1.1.3'; sha256 = $h1 }, [pscustomobject]@{ version = '1.1.3'; sha256 = $h2 }) })) $false
Assert-Case '대장 검증: 해시 중복' (Test-ReleaseManifest -Manifest ([pscustomobject]@{ releases = @(
        [pscustomobject]@{ version = '1.1.2'; sha256 = $h1 }, [pscustomobject]@{ version = '1.1.3'; sha256 = $h1 }) })) $false

$sweepCandidates = @(
  @{ Path = 'C:\Downloads\HoneyNogi.exe';     Hash = $h1 }          # v1.1.3 = 이전 릴리스 → 삭제 대상
  @{ Path = 'C:\Downloads\HoneyNogi (1).exe'; Hash = $h2 }          # v1.2.0 = 현재 버전 사본 → 보존
  @{ Path = 'C:\Desktop\HoneyNogi_mod.exe';   Hash = ('c' * 64) }   # 대장에 없는 해시(자작/미보관) → 보존
)
$targets = @(Select-OldExeTargets -Candidates $sweepCandidates -Manifest $manifestGood -CurrentVersion '1.2.0')
Assert-Case '삭제 대상: 이전 릴리스 1개만' $targets.Count 1
Assert-Case '삭제 대상: v1.1.3 파일' $targets[0].Path 'C:\Downloads\HoneyNogi.exe'
Assert-Case '삭제 대상: 대장 결함 시 0건(매칭 후보가 있어도)' `
  (@(Select-OldExeTargets -Candidates $sweepCandidates -Manifest ([pscustomobject]@{ releases = @() }) -CurrentVersion '1.2.0').Count) 0
Assert-Case '삭제 대상: 후보 없음 = 0건' (@(Select-OldExeTargets -Candidates @() -Manifest $manifestGood -CurrentVersion '1.2.0').Count) 0

# ---- 6-1. 구버전 zip 대상 선정 (내용물 해시 기반 - zip 자체 해시는 압축마다 달라 사용 불가) ----
$zipCases = @(
  @{ N = '공식 구버전 단일 엔트리';  Entries = @(@{ Name = 'HoneyNogi.exe'; Hash = $h1 });      E = 1 }
  @{ N = '변형 이름 + 구버전 해시';  Entries = @(@{ Name = 'HoneyNogi (1).exe'; Hash = $h1 });  E = 1 }
  @{ N = '현재 버전 내용물(새 배포 zip)'; Entries = @(@{ Name = 'HoneyNogi.exe'; Hash = $h2 }); E = 0 }
  @{ N = '미지 해시(자작 빌드)';      Entries = @(@{ Name = 'HoneyNogi.exe'; Hash = ('d' * 64) }); E = 0 }
  @{ N = '이름 불일치(abc.exe) + 구버전 해시'; Entries = @(@{ Name = 'abc.exe'; Hash = $h1 }); E = 0 }
  @{ N = '혼합(공식 exe + 사용자 파일)'; Entries = @(@{ Name = 'HoneyNogi.exe'; Hash = $h1 }, @{ Name = 'readme.txt'; Hash = ('d' * 64) }); E = 0 }
  @{ N = '빈 zip';                   Entries = @();                                             E = 0 }
)
foreach ($case in $zipCases) {
  $zipInfo = @{ Path = 'C:\Downloads\HoneyNogi.zip'; Entries = $case.Entries }
  Assert-Case "zip 대상 [$($case.N)]" `
    (@(Select-OldZipTargets -ZipInfos @($zipInfo) -Manifest $manifestGood -CurrentVersion '1.2.0').Count) $case.E
}
Assert-Case 'zip 대상: 대장 결함 시 0건' `
  (@(Select-OldZipTargets -ZipInfos @(@{ Path = 'C:\a.zip'; Entries = @(@{ Name = 'HoneyNogi.exe'; Hash = $h1 }) }) `
      -Manifest ([pscustomobject]@{ releases = @() }) -CurrentVersion '1.2.0').Count) 0

# zip 판독 실동작 (임시 zip 생성 → 내용물 잎 이름·해시 판독 확인)
$tempZipRoot = Join-Path $env:TEMP ('honeynogi_zip_test_' + $PID)
New-Item -ItemType Directory -Force -Path $tempZipRoot | Out-Null
try {
  $dummyExePath = Join-Path $tempZipRoot 'HoneyNogi.exe'
  [System.IO.File]::WriteAllBytes($dummyExePath, [byte[]](1..64))
  $dummyHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $dummyExePath).Hash.ToLower()
  $tempZipPath = Join-Path $tempZipRoot 'HoneyNogi.zip'
  Compress-Archive -LiteralPath $dummyExePath -DestinationPath $tempZipPath -Force
  $zipRead = Get-ZipEntryInfos -ZipPath $tempZipPath
  Assert-Case 'zip 판독: Ok' $zipRead.Ok $true
  Assert-Case 'zip 판독: 엔트리 1개' (@($zipRead.Entries).Count) 1
  Assert-Case 'zip 판독: 잎 이름' (@($zipRead.Entries)[0].Name) 'HoneyNogi.exe'
  Assert-Case 'zip 판독: 내용물 해시 일치' (@($zipRead.Entries)[0].Hash) $dummyHash
  Assert-Case 'zip 판독: zip 아닌 파일은 Ok=false(보존)' (Get-ZipEntryInfos -ZipPath $dummyExePath).Ok $false
} finally {
  Remove-Item -Recurse -Force $tempZipRoot -ErrorAction SilentlyContinue
}

# ---- 7. 소스 계약 검사 ----
$guiSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_gui.ps1') -Raw -Encoding UTF8
Assert-Case '계약: 구버전 정리가 GUI 뮤텍스 검사보다 먼저 실행' `
  ($guiSource.IndexOf('try { Invoke-OldExeCleanup }') -lt $guiSource.IndexOf("Mutex(`$false, 'Global\HoneyNogiGui')") -and $guiSource.IndexOf('try { Invoke-OldExeCleanup }') -ge 0) $true
Assert-Case '계약: 설정 이전이 approval/oldExeCleanup 키를 보존' `
  ($guiSource -match "foreach \(\`$keepKey in @\('approval', 'oldExeCleanup'\)\)") $true
Assert-Case '계약: 시작 버튼 활성은 미실행+승인 합성' `
  ($guiSource -match '\$btnStart\.Enabled = \(-not \$IsRunning\) -and \(Test-ApprovalAllowsStart\)') $true
Assert-Case '계약: 명단 URL 내장' ($guiSource -match 'script\.google\.com/macros/s/') $true
Assert-Case '계약: 정리 전용 뮤텍스 사용' ($guiSource -match "Mutex\(\`$false, 'Global\\HoneyNogiCleanup'\)") $true
Assert-Case '계약: 삭제는 File.Delete(완전 삭제 - 사용자 확정)' ($guiSource -match '\[System\.IO\.File\]::Delete\(') $true
Assert-Case '계약: 승인 러닝스페이스 종료 정리' ($guiSource -match 'if \(\$script:approvalPs\) \{') $true
Assert-Case '계약: exe 폴더 탐색은 직속만(깊이 0 - 보관 폴더 하위 사본 오삭제 방지)' `
  ($guiSource -match '\(Split-Path -Parent \$ownExe\); MaxDepth = 0') $true
$launcherSource = Get-Content -LiteralPath (Join-Path $projectRoot 'build\launcher.cs') -Raw -Encoding UTF8
Assert-Case '계약: 런처가 exe 경로 기록(exe_path.txt)' ($launcherSource -match 'exe_path\.txt') $true
Assert-Case '계약: 런처가 해시 대장 추출' ($launcherSource -match 'release_hashes\.json') $true
$buildSource = Get-Content -LiteralPath (Join-Path $projectRoot 'build\build_exe.ps1') -Raw -Encoding UTF8
Assert-Case '계약: 빌드가 현재 버전 제외 매니페스트 내장(자기 해시 순환 방지)' `
  ($buildSource -match '-lt \(\[version\]\$appVersion\)') $true
Assert-Case '계약: 빌드 후 자기 해시 upsert' ($buildSource -match 'RELEASE HASH') $true

if ($fails -gt 0) { Write-Output "FAIL 합계: $fails"; exit 1 }
Write-Output '전체 통과'
exit 0
