# 사용자 조작 양보 일괄 적용 (v2.1.7, 2026-09-08) 진리표 + 배선 가드
# 배경: 09-07(카드 설정)·09-08(구역 전환) 실사고로 확정된 기전 - 조작 중 Click-ScreenPoint 가 클릭을
#   버리는데 유한 재시도 루프가 그걸 모른 채 회수/시간을 소진해 정지. 클릭 호출부 138곳 전수 분류
#   (69곳 확정)에서 던전 회차 시작 구간·사냥터·허브 2개를 이 배치로 수정 (Codex: 루프별 재개 위치).
# 검증 단위(Codex 제안): ①시간 보정(허브 - 원래 마감을 넘는 양보 후 예산 보존, 중복 연장 없음)
#   ②급성 루프(한도 초과 반복 양보 후 성공, 대기 중 목표 도달 시 클릭 없음, 커서 실패 유한 종료)
#   ③저수준 계약(Click-ScreenPoint 는 대기하지 않고 취소만 - B1 기각 유지)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing   # 추출 함수의 [System.Drawing.Point] 타입 리터럴 해석용
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @(
    'Invoke-ClickUntil', 'Invoke-VerifiedContentExit', 'Confirm-DifficultySelected',
    'Set-DgOptionDifficulty', 'Resume-DgOptionDifficultyAfterYield', 'Get-KoreanObjectParticle')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ---- 공용 모의: 가상 시계 + 입력 경계 ----
$script:vclock = [datetime]'2026-01-01 00:00:00'
function Get-Date { return $script:vclock }
function Start-Sleep {
  param([int]$Milliseconds, [int]$Seconds)
  $ms = $Milliseconds; if ($Seconds) { $ms = $Seconds * 1000 }
  $script:vclock = $script:vclock.AddMilliseconds($ms)
}
function Focus-Game { param($Game) }
function Write-RunLog { param([string]$Message) $script:runLogs += $Message }
function Test-SafeStopDuringCaptureFail {}
function Test-CaptureRecovered { param($Game) return $true }
function Test-UserRecentlyActive {
  if ($script:mockActiveQueue.Count -gt 0) { return [bool]$script:mockActiveQueue.Dequeue() }
  return $false
}
function Wait-UserYieldEnd {
  # 실제 함수와 같은 계약: 양보 시간을 누적 변수에 더함 (가상 시계도 그만큼 전진)
  param($Game, [string]$Context)
  $script:yieldCalls++
  $script:vclock = $script:vclock.AddMilliseconds($script:mockYieldMs)
  $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $script:mockYieldMs
  if ($script:selectedAfterYield) { $script:selectedNow = $true }
}
function Invoke-MockClickOutcome {
  $outcome = 'performed'
  if ($script:mockClickQueue.Count -gt 0) { $outcome = $script:mockClickQueue.Dequeue() }
  if ($outcome -eq 'performed') {
    $script:lastClickPerformed = $true; $script:lastClickSkipReason = ''; $script:performedCount++
  } else {
    $script:lastClickPerformed = $false; $script:lastClickSkipReason = $outcome
  }
}
function Click-ScreenPoint { param($X, $Y); $script:clickCount++; Invoke-MockClickOutcome }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY); $script:clickCount++; Invoke-MockClickOutcome }
function Reset-Mock {
  param([object[]]$ActiveSeq = @(), [string[]]$ClickSeq = @(), [int]$YieldMs = 30000, [object[]]$SelectedSeq = @())
  $script:vclock = [datetime]'2026-01-01 00:00:00'
  $script:mockActiveQueue = New-Object System.Collections.Queue
  foreach ($a in $ActiveSeq) { $script:mockActiveQueue.Enqueue($a) }
  $script:mockClickQueue = New-Object System.Collections.Queue
  foreach ($c in $ClickSeq) { $script:mockClickQueue.Enqueue($c) }
  $script:mockSelectedQueue = New-Object System.Collections.Queue
  foreach ($s in $SelectedSeq) { $script:mockSelectedQueue.Enqueue($s) }
  $script:mockYieldMs = $YieldMs
  $script:yieldCalls = 0; $script:clickCount = 0; $script:performedCount = 0; $script:findCalls = 0
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = ''
  $script:userYieldTotalMs = [double]0
  $script:screenCaptureFailing = $false
  $script:selectedAfterYield = $false; $script:selectedNow = $false
  $script:runLogs = @()
  $script:fieldQueue = New-Object System.Collections.Queue
}
function Get-LogCount { param([string]$Needle) return @($script:runLogs | Where-Object { $_.Contains($Needle) }).Count }
$script:contentTag = '[던전]'
$game = $null

# ---- 1. Invoke-ClickUntil: 양보 시간만큼 마감 연장 ----
# 20초 상한인데 첫 회전에서 30초 양보 → 연장 없으면 마감 초과 throw, 연장하면 이어서 조건 도달
Reset-Mock -ActiveSeq @($true) -YieldMs 30000
$script:conditionChecks = 0
$threw = $false
try {
  Invoke-ClickUntil -Game $game -Point @(1, 1) -Description '테스트 화면' -TimeoutSeconds 20 `
    -Condition { [void]($script:conditionChecks++); $script:conditionChecks -ge 3 } -SourceCondition { $true }
} catch { $threw = $true }
Assert-Case '허브 ClickUntil: 상한(20초)을 넘는 양보(30초) 후에도 초과 아님(마감 연장)' $threw $false
Assert-Case '허브 ClickUntil: 양보 1회 + 대기 후 클릭 1회' "$($script:yieldCalls)/$($script:performedCount)" '1/1'
# 경합 백업: 게이트 통과 후 클릭이 user-active 로 생략 → 같은 연장 경로 (재클릭 간격 대기 없이 재판독)
Reset-Mock -ClickSeq @('user-active') -YieldMs 30000
$script:conditionChecks = 0
$threw = $false
try {
  Invoke-ClickUntil -Game $game -Point @(1, 1) -Description '테스트 화면' -TimeoutSeconds 20 `
    -Condition { [void]($script:conditionChecks++); $script:conditionChecks -ge 2 } -SourceCondition { $true }
} catch { $threw = $true }
Assert-Case '허브 ClickUntil: 경합 생략 → 대기 후 조건 재확인으로 종료(재클릭 없음)' "$threw/$($script:clickCount)/$($script:performedCount)/$($script:yieldCalls)" 'False/1/0/1'
# 대조: 양보 없이 조건이 영영 거짓이면 기존대로 초과 throw (연장이 무한 대기를 만들지 않음)
Reset-Mock
$threw = $false
try { Invoke-ClickUntil -Game $game -Point @(1, 1) -Description '테스트 화면' -TimeoutSeconds 5 -Condition { $false } -SourceCondition { $true } }
catch { $threw = $true }
Assert-Case '허브 ClickUntil: 양보 없는 조건 미충족은 기존대로 초과 throw' $threw $true
# 캡처 실패로 마감을 새로 잡으면 기준값도 갱신 - 과거 양보(30초)가 새 마감에 또 더해지지 않음
# (더해지면 5초 상한이 35초가 되어 조건 미충족 throw 가 늦어짐 - 가상 시계로 관측)
Reset-Mock -ActiveSeq @($true) -YieldMs 30000
$script:conditionChecks = 0
$script:captureFlip = 0
$threw = $false
try {
  Invoke-ClickUntil -Game $game -Point @(1, 1) -Description '테스트 화면' -TimeoutSeconds 5 `
    -Condition {
      $script:conditionChecks++
      # 2번째 확인부터 캡처 실패 1회 → 마감 재설정 → 복구. 그 뒤 영영 거짓
      if ($script:conditionChecks -eq 2) { $script:screenCaptureFailing = $true }
      if ($script:conditionChecks -eq 3) { $script:screenCaptureFailing = $false }
      $false
    } -SourceCondition { $true }
} catch { $threw = $true }
$elapsedAfterReset = ($script:vclock - [datetime]'2026-01-01 00:00:00').TotalSeconds
# 흐름: 양보 30초(연장) → 확인2 캡처실패 → 마감=지금+5 (기준값 갱신) → 확인3 복구 → 클릭·대기 → 5초 안에 초과.
# 기준값 갱신이 없으면 마감이 +30초 더 늘어 총 경과가 35초를 넘습니다.
Assert-Case '허브 ClickUntil: 캡처 실패 마감 재설정 시 과거 양보 중복 가산 없음(총 경과 < 45초)' ($threw -and $elapsedAfterReset -lt 45) $true

# ---- 2. Invoke-VerifiedContentExit: 40초 상한 + 50초 양보 → 연장으로 필드 증거 도달 ----
function Get-GameOcrText { param($Game) return '' }
function Press-KeyVerified { param($Game, $VirtualKey, $Label) return $true }
function Test-BattleFieldEvidence {
  param($Game)
  if ($script:fieldQueue.Count -gt 0) { return [bool]$script:fieldQueue.Dequeue() }
  return $false
}
Reset-Mock -ActiveSeq @($true) -YieldMs 50000
foreach ($f in @($false, $true, $true)) { $script:fieldQueue.Enqueue($f) }
$script:reclickCalls = 0
$exitOk = Invoke-VerifiedContentExit -Game $game -TimeoutSeconds 40 -ReclickIfSource { $script:reclickCalls++ }
Assert-Case '허브 VerifiedExit: 상한(40초)을 넘는 양보(50초) 뒤 필드 증거 2연속으로 성공' $exitOk $true
Assert-Case '허브 VerifiedExit: 양보 중 재클릭 없음(양보 1회, 재클릭 0회)' "$($script:yieldCalls)/$($script:reclickCalls)" '1/0'
# 대조: 양보 없이 증거가 영영 없으면 기존대로 $false
Reset-Mock
$exitOk = Invoke-VerifiedContentExit -Game $game -TimeoutSeconds 5 -ReclickIfSource { $script:reclickCalls++ }
Assert-Case '허브 VerifiedExit: 양보 없는 증거 부재는 기존대로 실패 반환' $exitOk $false

# ---- 3. Confirm-DifficultySelected: 재클릭 루프 양보 (같은 좌표 계약 유지) ----
function Test-DifficultySelectedAt {
  param($Game, $ScreenPoint)
  if ($script:selectedNow) { return $true }
  if ($script:mockSelectedQueue.Count -gt 0) { return [bool]$script:mockSelectedQueue.Dequeue() }
  return $false
}
$script:lastPillProbe = ''
# 3a. 조작 4회전(3회 상한 초과) → 시도 미소모로 기다렸다가 클릭 1회 → 다음 확인에서 선택
Reset-Mock -ActiveSeq @($true, $true, $true, $true) -SelectedSeq @($false, $false, $false, $false, $false, $true)
$ok = Confirm-DifficultySelected -Game $game -ClickPoint @{ X = 1; Y = 2 } -Label '어려움'
Assert-Case '난이도 확인: 조작 4회전 후 성공(tryNo 미소모)' "$ok/$($script:yieldCalls)/$($script:performedCount)" 'True/4/1'
# 3b. 경합 생략(user-active) 도 미소모
Reset-Mock -ClickSeq @('user-active') -SelectedSeq @($false, $false, $true)
$ok = Confirm-DifficultySelected -Game $game -ClickPoint @{ X = 1; Y = 2 } -Label '어려움'
Assert-Case '난이도 확인: 경합 생략 → 대기 후 재클릭 성공(호출 2·실제 1)' "$ok/$($script:clickCount)/$($script:performedCount)" 'True/2/1'
# 3c. 커서 미확인은 기존대로 유한 소모 → 3회 후 $false, 양보 없음
Reset-Mock -ClickSeq @('cursor-not-ready', 'cursor-not-ready')
$ok = Confirm-DifficultySelected -Game $game -ClickPoint @{ X = 1; Y = 2 } -Label '어려움'
Assert-Case '난이도 확인: 커서 미확인 2회는 소모 → 실패 반환, 양보 0' "$ok/$($script:yieldCalls)" 'False/0'

# ---- 4. Set-DgOptionDifficulty: 확정 클릭 전/재전송/최종 재클릭의 양보 재개 ----
$rgDgOptDifficulty = @(0, 0, 10, 10)
$dgOptHardX = 0
function Find-DgDifficultyPoint { param($Game, $Region, $Label, $HardX); $script:findCalls++; return @{ X = 5; Y = 6 } }
function Read-DgTitleText { param($Game) return '페카고분 1층 1구역' }
# 4a. 확정 클릭 전 양보 - 대기 중 사용자가 골라 둠 → 재탐색 후 선확인으로 클릭 없이 성공
Reset-Mock -ActiveSeq @($true) -SelectedSeq @($false, $false, $false, $false, $false)
$script:selectedAfterYield = $true
$ok = Set-DgOptionDifficulty -Game $game -Label '어려움'
Assert-Case '옵션 난이도: 확정 전 양보 + 대기 중 선택됨 → 클릭 0·재탐색 1' "$ok/$($script:clickCount)/$($script:findCalls)" 'True/0/2'
Assert-Case '옵션 난이도: 양보 후 재확인 로그' (Get-LogCount '클릭 생략 (양보 후 재확인)') 1
# 4b. 재전송 루프: 경합 생략 3회 연속(2회 상한 초과)이어도 미소모 → 재탐색 후 전송 성공
Reset-Mock -ClickSeq @('user-active', 'user-active', 'user-active') -SelectedSeq @($false, $false, $false, $false, $false, $false, $false, $false, $true)
$ok = Set-DgOptionDifficulty -Game $game -Label '어려움'
Assert-Case '옵션 난이도: 재전송 경합 3회 → 미소모·재탐색 후 성공(호출 4·실제 1·재탐색 4)' "$ok/$($script:clickCount)/$($script:performedCount)/$($script:findCalls)" 'True/4/1/4'
# 4c. 커서 미확인 재전송은 기존 2회 상한 유지 (재탐색 없음)
Reset-Mock -ClickSeq @('cursor-not-ready', 'cursor-not-ready', 'cursor-not-ready', 'cursor-not-ready') -SelectedSeq @($false, $false, $false, $false, $false)
$ok = Set-DgOptionDifficulty -Game $game -Label '어려움'
Assert-Case '옵션 난이도: 커서 미확인 재전송은 2회 상한(확정 1+재전송 2+최종 1 = 호출 4)' "$ok/$($script:clickCount)/$($script:findCalls)" 'False/4/1'
# 4d. 최종 재클릭 전 양보 - 대기 중 선택됨 → 재클릭 없이 성공
Reset-Mock -ActiveSeq @($false, $true) -SelectedSeq @($false, $false, $false, $false, $false, $false, $false, $false)
$script:selectedAfterYield = $true
$ok = Set-DgOptionDifficulty -Game $game -Label '어려움'
Assert-Case '옵션 난이도: 최종 재클릭 전 양보 + 선택됨 → 확정 클릭 1회뿐' "$ok/$($script:performedCount)" 'True/1'
Assert-Case '옵션 난이도: 최종 재클릭 생략 로그' (Get-LogCount '재클릭 생략, 옵션 화면') 1
# 4e. 양보 후 재탐색 실패 = fail-closed (옛 좌표 클릭 금지)
function Find-DgDifficultyPoint { param($Game, $Region, $Label, $HardX); $script:findCalls++; if ($script:findCalls -ge 2) { return $null }; return @{ X = 5; Y = 6 } }
Reset-Mock -ActiveSeq @($true) -SelectedSeq @($false, $false, $false, $false, $false)
$ok = Set-DgOptionDifficulty -Game $game -Label '어려움'
Assert-Case '옵션 난이도: 양보 후 재탐색 실패 → 클릭 없이 실패 반환' "$ok/$($script:clickCount)" 'False/0'

# ---- 5. 조사 헬퍼 ----
Assert-Case '조사: 받침 있음 → 을' ((Get-KoreanObjectParticle -Word '구역 2-2 전환') + '|' + (Get-KoreanObjectParticle -Word '소탕 해제 폴백') + '|' + (Get-KoreanObjectParticle -Word '입장하기 클릭')) '을|을|을'
Assert-Case '조사: 받침 없음 → 를' ((Get-KoreanObjectParticle -Word "'우연한 만남' 토글 켜기") + '|' + (Get-KoreanObjectParticle -Word '선택 화면 복귀')) '를|를'
Assert-Case '조사: 한글 아님 → 을(를)' (Get-KoreanObjectParticle -Word 'ABC') '을(를)'

# ---- 6. 배선 가드 (주석 제거 사본) ----
$workerSource = [IO.File]::ReadAllText($workerPath)
$workerCode = (($workerSource -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 던전 탭 전환 사전 게이트(대기 → tabTry 미소모 → 도달 확인)' `
  ([regex]::Matches($workerCode, "Wait-UserYieldEnd -Game \`$Game -Context `"'\`$tabTargetLabel' 탭 전환`"\s+\`$tabTry--\s+if \(Test-DgTabProbeMatchesMode").Count) 2
Assert-Case '배선: 커스텀 난이도 루프 양보 2곳(사전+경합, diffTry 미소모)' `
  ([regex]::Matches($workerCode, "Wait-UserYieldEnd -Game \`$Game -Context `"난이도 '\`$ndDifficulty' 선택`"\s+\`$diffTry--\s+continue").Count) 2
Assert-Case '배선: 비커스텀 난이도 재개 = 선택 화면 확인 → 재탐색(정지 사유 변수)' `
  (($workerCode.Contains("`$ndDiffStopReason = '양보 후 난이도 글자 재탐색 실패'; break")) -and
   ($workerCode.Contains("if (`$script:lastClickSkipReason -eq 'user-active') { `$ndDiffTry--; `$ndDiffRefind = `$true; continue }"))) 'True'
Assert-Case '배선: 선택 화면 구역 카드 양보 2곳(stageTry 미소모)' `
  ([regex]::Matches($workerCode, "Wait-UserYieldEnd -Game \`$Game -Context `"구역 \`$\{ndStage\} 선택`"\s+\`$stageTry--\s+continue").Count) 2
Assert-Case '배선: 우연한 만남 켜기/끄기 단발 토글 = 전송 확인 루프' `
  (($workerCode.Contains("while (-not `$chanceClickSent -and `$toggleState -ne 'on')")) -and
   ($workerCode.Contains("while (-not `$chanceOffSent -and `$toggleState -eq 'on')"))) 'True'
Assert-Case '배선: 던전·사냥터 입장 루프 양보 4곳(enterTry 미소모)' `
  ([regex]::Matches($workerCode, "Wait-UserYieldEnd -Game \`$Game -Context '입장하기 클릭'\s+\`$enterTry--").Count) 4
Assert-Case '배선: 선택 화면 복귀 경합 백업(backInputs 되돌림)' `
  ([bool]($workerCode -match '\$backInputs--\s+Wait-UserYieldEnd -Game \$Game -Context ''선택 화면 복귀''\s+\$backTry--')) 'True'
Assert-Case '배선: 사냥터 난이도 재개(재탐색) + 정정 양보' `
  (($workerCode.Contains("if (`$script:lastClickSkipReason -eq 'user-active') { `$diffDispatchTry--; `$htDiffRefind = `$true; continue }")) -and
   ($workerCode.Contains("Wait-UserYieldEnd -Game `$Game -Context `"난이도 '`$htDifficulty' 정정`""))) 'True'
$clickUntilCode = ((([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-ClickUntil'))) -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 허브 ClickUntil 마감 연장 2곳 + 기준값 갱신 3곳(시작·캡처 실패·연장)' `
  (([regex]::Matches($clickUntilCode, '\$deadline = \$deadline\.AddMilliseconds\(\[double\]\$script:userYieldTotalMs - \$seenYieldMs\)').Count -eq 2) -and
   ([regex]::Matches($clickUntilCode, '\$seenYieldMs = \[double\]\$script:userYieldTotalMs').Count -eq 4)) 'True'
Assert-Case '배선: 허브 ClickUntil 클릭 전 생략 메타 초기화(잔존 user-active 오발동 방지)' `
  ([bool]($clickUntilCode -match "\`$script:lastClickSkipReason = ''\s+if \(\`$sourceStillVisible\)")) 'True'
$verifiedExitCode = ((([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-VerifiedContentExit'))) -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 허브 VerifiedExit 마감 연장 2곳 + 재클릭 전 메타 초기화' `
  (([regex]::Matches($verifiedExitCode, '\$verifyDeadline = \$verifyDeadline\.AddMilliseconds').Count -eq 2) -and
   ($verifiedExitCode -match "\`$script:lastClickSkipReason = ''[^\r\n]*\r?\n\s+& \`$ReclickIfSource")) 'True'   # 줄 끝 인라인 주석 허용
Assert-Case '배선: 양보 시간 누적 2경로(Wait-UserYieldEnd + 커서 대피 양보)' `
  ([regex]::Matches($workerCode, '\$script:userYieldTotalMs = \[double\]\$script:userYieldTotalMs \+ \$\w+\.Elapsed\.TotalMilliseconds').Count) 2
# 저수준 계약 유지: Click-ScreenPoint 는 조작 중 '취소만' (내부 대기 = 대기 후 호출부의 연속 클릭이
# 재판독 없이 나가는 B1 위험 - Codex 기각). 주석 제거 사본으로 검사.
$clickCode = ((([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Click-ScreenPoint'))) -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '계약: Click-ScreenPoint 는 내부에서 양보 대기하지 않음(취소 후 즉시 반환)' `
  (-not $clickCode.Contains('Wait-UserYieldEnd')) 'True'

if ($fails -gt 0) { Write-Output "FAIL 합계: $fails"; exit 1 }
Write-Output '전체 통과'
exit 0
