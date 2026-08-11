# Press-KeyVerified (검증 키 입력) 동작 진리표 + 배선 가드 (2026-08-11 ④)
# 본체: mabinogi_run_once.ps1 Press-KeyVerified - 전면 확인 후에만 키를 정확히 1회 전송.
# 관측 근거: 2026-08-08 hyodong 제보(전면 아닌 게임에 C 키 무시 - 전역 입력이 다른 창으로 샘).
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

$fails = 0
function Assert-Case {
  param([string]$Name, $Actual, $Expected)
  $actualText = if ($null -eq $Actual) { 'null' } else { "$Actual" }
  $expectedText = if ($null -eq $Expected) { 'null' } else { "$Expected" }
  if ($actualText -eq $expectedText) { Write-Host "OK   ${Name}: $actualText" }
  else { Write-Host "FAIL ${Name}: 실제 [$actualText] 기대 [$expectedText]"; $script:fails++ }
}

# ── 1. 동작 진리표 (본체 함수 + 스텁) ──────────────────────────────────────────
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Press-KeyVerified')) {
  . ([scriptblock]::Create($definition))
}
$script:keyVerifyWarnActive = $false
$script:logLines = @()
$script:fgSeq = @()          # Test-GameForeground 가 돌려줄 시퀀스 (소진 후 false)
$script:fgCalls = 0
$script:rawPresses = 0
$script:focusCalls = 0
function Write-RunLog { param([string]$Message) $script:logLines += $Message }
function Test-GameForeground { param($Game)
  $script:fgCalls++
  if ($script:fgSeq.Count -gt 0) { $v = $script:fgSeq[0]; $script:fgSeq = @($script:fgSeq | Select-Object -Skip 1); return $v }
  return $false
}
function Focus-Game { param($Game) $script:focusCalls++ }
function Press-KeyOnce { param([byte]$VirtualKey) $script:rawPresses++ }
function Start-Sleep { param([int]$Seconds, [int]$Milliseconds) }

function Reset-KeyStub {
  param([bool[]]$Seq)
  $script:fgSeq = $Seq
  $script:fgCalls = 0
  $script:rawPresses = 0
  $script:focusCalls = 0
  $script:logLines = @()
  $script:keyVerifyWarnActive = $false
}

# 이미 전면: 전면화 시도 없이 즉시 1회 전송
Reset-KeyStub -Seq @($true)
$r = Press-KeyVerified -Game $null -VirtualKey ([byte]82) -Label 'R'
Assert-Case '전면이면 즉시 전송 1회' ('{0}/{1}/{2}' -f $r, $script:rawPresses, $script:focusCalls) 'True/1/0'

# 첫 확인 실패 → 전면화 → 성공: 키는 정확히 1회
Reset-KeyStub -Seq @($false, $true)
$r = Press-KeyVerified -Game $null -VirtualKey ([byte]82)
Assert-Case '전면화 후 성공 - 키 1회' ('{0}/{1}' -f $r, $script:rawPresses) 'True/1'

# 전부 실패: 키 0회 + $false + 안내 1회
Reset-KeyStub -Seq @()
$r = Press-KeyVerified -Game $null -VirtualKey ([byte]82) -Label 'R 부활'
Assert-Case '전면 확인 전부 실패 - 키 0회' ('{0}/{1}' -f $r, $script:rawPresses) 'False/0'
Assert-Case '실패 안내 로그 1회 (라벨 포함)' `
  (@($script:logLines | Where-Object { $_ -match '키 입력을 건너뛰었습니다.*R 부활' }).Count) '1'
# 연속 실패에서 안내가 쌓이지 않음
$r = Press-KeyVerified -Game $null -VirtualKey ([byte]82) -Label 'R 부활'
Assert-Case '연속 실패 - 안내 반복 없음' `
  (@($script:logLines | Where-Object { $_ -match '건너뛰었습니다' }).Count) '1'
# 회복 시 재개 안내
$script:fgSeq = @($true)
$r = Press-KeyVerified -Game $null -VirtualKey ([byte]82)
Assert-Case '회복 - 전송 재개 + 안내' ('{0}/{1}' -f $r, (@($script:logLines | Where-Object { $_ -match '재개' }).Count)) 'True/1'

# ── 2. 배선 가드 (호출부가 검증 입력을 쓰는가) ────────────────────────────────
$workerRaw = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))
Assert-Case '배선: R 부활이 검증 입력 경유 + 성공 시에만 계상' `
  ([bool]($workerRaw -match '(?s)if \(Press-KeyVerified -Game \$Game -VirtualKey \(\[byte\]\$reviveKey\)[^\)]*\) \{\s*\r?\n\s*\$reviveCount\+\+')) 'True'
Assert-Case '배선: 자동사냥 재개가 검증 입력 경유 + 성공 시에만 계상' `
  ([bool]($workerRaw -match '(?s)if \(Press-KeyVerified -Game \$Game -VirtualKey \(\[byte\]\$reviveResumeKey\)[^\)]*\) \{\s*\r?\n\s*\$autoHuntPresses\+\+')) 'True'
Assert-Case '배선: ASSIST 가 검증 입력 경유 + 성공 시에만 계상' `
  ([bool]($workerRaw -match '(?s)if \(Press-KeyVerified -Game \$Game -VirtualKey \(\[byte\]\$assistKey\)[^\)]*\) \{\s*\r?\n\s*\$assistPresses\+\+')) 'True'
Assert-Case '배선: 입장 직후 키가 검증 입력 경유 + 성공/생략 로그 분기' `
  ([bool]($workerRaw -match '(?s)if \(Press-KeyVerified -Game \$Game -VirtualKey \(\[byte\]\$action\.Key\)[\s\S]{0,40}\) \{[\s\S]{0,220}입력완료[\s\S]{0,120}\} else \{[\s\S]{0,220}건너뜀')) 'True'
Assert-Case '배선: 생활 C 키가 공용 검증 입력의 래퍼' `
  ([bool]($workerRaw -match '(?s)function Press-LifeMenuKey \{[^}]*Press-KeyVerified -Game \$Game -VirtualKey \(\[byte\]0x43\)')) 'True'
# 검증 입력은 '키 재시도'가 아니라 '전면 확인 재시도' - 함수 안에 Press-KeyOnce 는 1곳만
$kvBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Press-KeyVerified'))
$kvCode = (($kvBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 검증 입력 안의 실제 전송은 1곳 (키 반복 금지)' `
  (@([regex]::Matches($kvCode, 'Press-KeyOnce')).Count) '1'
Assert-Case '배선: 경고 상태 플래그 초기화 존재' `
  ([bool]($workerRaw -match '(?m)^\$script:keyVerifyWarnActive = \$false')) 'True'

exit $fails
