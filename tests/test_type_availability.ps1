# 각 스크립트가 **자기 프로세스에서** 쓰는 모든 .NET 타입이 실제로 해석되는지 검사합니다.
#
# 왜 필요한가 (2026-08-09 배포 차단급 실사고):
# 워커는 GUI 와 별도 프로세스(powershell.exe -NoProfile -File)라 GUI 가 로드한 어셈블리를
# 물려받지 않습니다. 그런데 Move-CursorOutsideGame 이 [System.Windows.Forms.Screen] 을 쓰면서
# 워커에 Add-Type -AssemblyName System.Windows.Forms 가 없었고, 함수 끝의 빈 catch 가
# 'Unable to find type' 예외를 삼켜 **커서 대피 기능이 전 PC에서 100% 무동작**이었습니다.
# 회귀 46종은 순수 함수 진리표 + 소스 문자열 배선 가드뿐이라 본문이 한 번도 실행되지 않아
# 이걸 잡지 못했습니다.
#
# 이 테스트는 스크립트별로 **그 스크립트의 초기화만 재현한 자식 프로세스**를 띄우고,
# AST 에서 뽑은 타입 리터럴을 전부 해석해 봅니다. 타입을 새로 쓰면서 어셈블리 로드를
# 빠뜨리면 여기서 즉시 FAIL 이 납니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# 자식 프로세스에서 돌 검사 본문. $args[0] = 검사할 스크립트 경로
$childBody = @'
param([string]$TargetPath)
$ErrorActionPreference = 'Stop'
$src = [IO.File]::ReadAllText($TargetPath)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($TargetPath, [ref]$null, [ref]$null)

# ① 그 스크립트가 로드하는 어셈블리를 그대로 로드
foreach ($m in [regex]::Matches($src, '(?m)^\s*Add-Type -AssemblyName (\S+)')) {
  try { Add-Type -AssemblyName $m.Groups[1].Value } catch { }
}
# ② 인라인 C# 타입 정의(HoneyNogiInput 등)도 그대로 컴파일
foreach ($cmd in $ast.FindAll({ param($n)
      $n -is [System.Management.Automation.Language.CommandAst] -and
      $n.GetCommandName() -eq 'Add-Type' -and $n.Extent.Text -notmatch '-AssemblyName' }, $true)) {
  try { Invoke-Expression $cmd.Extent.Text } catch { }
}
# ③ WinRT 타입 사전 로드 줄(ContentType=WindowsRuntime)도 그대로 실행
foreach ($line in ($src -split "`r?`n")) {
  if ($line -match 'ContentType=WindowsRuntime\]\s*\|\s*Out-Null') {
    try { Invoke-Expression $line.Trim() } catch { }
  }
}

# ④ AST 에서 타입 리터럴 수집 ([Foo]::Bar 의 [Foo], [Foo]$x 의 [Foo], param 의 [Foo])
$names = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($n in $ast.FindAll({ param($x)
      ($x -is [System.Management.Automation.Language.TypeExpressionAst]) -or
      ($x -is [System.Management.Automation.Language.TypeConstraintAst]) }, $true)) {
  $full = [string]$n.TypeName.FullName
  if ([string]::IsNullOrWhiteSpace($full)) { continue }
  # 어셈블리 한정 WinRT 리터럴은 ③에서 이미 다뤘고 -as [type] 로는 해석되지 않습니다
  if ($full -match ',') { continue }
  # [ordered] 는 실제 타입이 아니라 해시테이블 리터럴용 파서 키워드라 -as [type] 로 안 잡힙니다
  if ($full -eq 'ordered') { continue }
  [void]$names.Add($full)
}

$missing = @()
foreach ($name in $names) {
  if ($null -eq ($name -as [type])) { $missing += $name }
}
"TOTAL=$($names.Count)"
foreach ($m in $missing) { "MISSING=$m" }
'@

$childPath = Join-Path ([IO.Path]::GetTempPath()) ("honeynogi_typecheck_{0}.ps1" -f [guid]::NewGuid().ToString('N'))
[IO.File]::WriteAllText($childPath, $childBody, (New-Object System.Text.UTF8Encoding($true)))
try {
  foreach ($target in @('mabinogi_run_once.ps1', 'mabinogi_gui.ps1')) {
    $targetPath = Join-Path $projectRoot $target
    $out = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $childPath $targetPath 2>&1)
    $total = ($out | Where-Object { $_ -match '^TOTAL=' } | Select-Object -First 1) -replace '^TOTAL=', ''
    $missing = @($out | Where-Object { $_ -match '^MISSING=' } | ForEach-Object { $_ -replace '^MISSING=', '' })
    if (-not $total) {
      "FAIL $target 타입 검사 자식 프로세스 실패: $($out -join ' / ')"
      $fails++
      continue
    }
    Assert-Case "$target : 사용 타입 전부 해석됨 (검사 $total 종)" `
      ($(if ($missing.Count -eq 0) { '없음' } else { '해석 실패: ' + ($missing -join ', ') })) '없음'
  }
} finally {
  Remove-Item -LiteralPath $childPath -Force -ErrorAction SilentlyContinue
}

# 워커가 커서 대피에 WinForms 를 쓰는 한, 로드 줄이 반드시 함께 있어야 합니다.
# (위 검사가 이미 잡지만, 원인을 바로 알 수 있게 전용 단언을 하나 더 둡니다)
$workerSource = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))
$usesForms = [bool]($workerSource -match '\[System\.Windows\.Forms\.')
$loadsForms = [bool]($workerSource -match '(?m)^\s*Add-Type -AssemblyName System\.Windows\.Forms\s*$')
Assert-Case '워커: WinForms 를 쓰면 로드도 한다' ($(if ($usesForms) { $loadsForms } else { $true })) 'True'

# 무음 catch 금지: 조용히 죽은 기능을 다시 만들지 않기 위한 계약
Assert-Case '워커: 커서 대피 catch 가 로그를 남긴다' `
  ([bool]($workerSource -match '(?s)Move-CursorOutsideGame[\s\S]{0,3000}\} catch \{[\s\S]{0,600}커서 대피 실패')) 'True'

exit $fails
