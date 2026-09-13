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
    'Set-DgOptionDifficulty', 'Resume-DgOptionDifficultyAfterYield', 'Get-KoreanObjectParticle',
    'Invoke-UserYieldWithDeadline', 'Wait-ForResultScreen', 'Get-YieldAdjustedDeadline',
    'Resolve-DgEntryAfterYield', 'Resolve-HtEntryAfterYield')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}
# 배선 검사용 주석 제거 사본 (여러 섹션이 쓰므로 맨 앞에서 한 번 정의)
$workerSource = [IO.File]::ReadAllText($workerPath)
$workerCode = (($workerSource -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")

# ---- 공용 모의: 가상 시계 + 입력 경계 ----
$script:vclock = [datetime]'2026-01-01 00:00:00'
function Get-Date { return $script:vclock }
function Start-Sleep {
  param([int]$Milliseconds, [int]$Seconds)
  $ms = $Milliseconds; if ($Seconds) { $ms = $Seconds * 1000 }
  $script:vclock = $script:vclock.AddMilliseconds($ms)
}
function Focus-Game { param($Game) }
function Move-CursorOutsideGame { param($Game) }   # v2.1.7: 양보 재판독 직전 커서 대피 (모의 - 판정에 영향 없음)
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
#     (v2.1.7: 양보 게이트가 선택 확인보다 **앞** - 옛 좌표를 성공으로 인정하지 않기 위함, Codex P1)
Reset-Mock -ActiveSeq @($true, $true, $true, $true) -SelectedSeq @($false, $true)
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

# ---- 4b. 결과 화면 대기(Wait-ForResultScreen, 90초) + 마감 연장 헬퍼 (2026-09-08 18:16 실기 후 추가) ----
$rgCutsceneTop = @(0, 0, 10, 10); $rgDgLootReveal = @(0, 0, 10, 10); $ptClearCenter = @(636, 400)
function Find-GameTextPoint { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $SearchText, $Scale, $ExactText) return $null }
function Test-DungeonClearPrompt {
  param($Game)
  if ($script:mockPromptQueue.Count -gt 0) { return [bool]$script:mockPromptQueue.Dequeue() }
  return $false
}
function Close-NetworkUnstablePopup { param($Game, $LogPrefix) return $false }
function Close-CurrencyOverviewScreen { param($Game) return $false }
function Close-WeeklyCoopResetPopup { param($Game, $LogPrefix) return $false }
function Close-CoopMissionBoardScreen { param($Game, $LogPrefix) return $false }
$script:mockPromptQueue = New-Object System.Collections.Queue
# 헬퍼: 양보 차분만큼 마감 연장, 두 번째 호출(새 양보 0)은 연장 0
Reset-Mock -ActiveSeq @($true) -YieldMs 30000
$dl = [datetime]'2026-01-01 00:00:40'; $seen = [double]0
Invoke-UserYieldWithDeadline -Game $game -Context '테스트' -Deadline ([ref]$dl) -SeenYieldMs ([ref]$seen)
$firstDl = $dl
$script:mockYieldMs = 0   # 두 번째 호출은 새 양보 없음(실제 Wait 는 유휴면 즉시 반환) - 차분 0 이어야 함
Invoke-UserYieldWithDeadline -Game $game -Context '테스트' -Deadline ([ref]$dl) -SeenYieldMs ([ref]$seen)
Assert-Case '헬퍼: 양보 30초 → 마감 +30초, 재호출(새 양보 없음)은 +0' "$(($firstDl - [datetime]'2026-01-01 00:00:40').TotalSeconds)/$(($dl - $firstDl).TotalSeconds)" '30/0'
# R1. 90초 상한, 첫 회전 양보 100초 → 연장으로 이어서 반복 버튼 발견 (연장 없으면 throw)
Reset-Mock -ActiveSeq @($true) -YieldMs 100000
$script:mockPromptQueue = New-Object System.Collections.Queue
$script:retryCalls = 0
$threw = $false
try { $rp = Wait-ForResultScreen -Game $game -MissingMessage '결과 없음' -FindRetryButton { $script:retryCalls++; if ($script:retryCalls -ge 2) { @{ X = 1; Y = 1 } } else { $null } } }
catch { $threw = $true }
Assert-Case '결과 대기: 상한(90초)을 넘는 양보(100초) 후에도 반복 버튼 도달(마감 연장)' "$threw/$($script:yieldCalls)/$($null -ne $rp)" 'False/1/True'
# R2. 클리어 재터치가 경합으로 생략(user-active) → 대기 후 서두부터 → '다시 터치' 로그 없음
Reset-Mock -ClickSeq @('user-active') -YieldMs 5000
$script:mockPromptQueue = New-Object System.Collections.Queue; $script:mockPromptQueue.Enqueue($true)
$script:retryCalls = 0
$rp = Wait-ForResultScreen -Game $game -MissingMessage '결과 없음' -FindRetryButton { $script:retryCalls++; if ($script:retryCalls -ge 1) { @{ X = 1; Y = 1 } } else { $null } }
Assert-Case '결과 대기: 재터치 경합 생략 → 양보 1·실제 클릭 0·거짓 터치 로그 0' "$($script:yieldCalls)/$($script:performedCount)/$(Get-LogCount '클리어 화면이 남아 있어 다시 터치')" '1/0/0'
# R3. 커서 미확인 재터치는 기존대로 건너뜀 로그 + 다음 감지 (양보 없음)
Reset-Mock -ClickSeq @('cursor-not-ready')
$script:mockPromptQueue = New-Object System.Collections.Queue; $script:mockPromptQueue.Enqueue($true)
$script:retryCalls = 0
$rp = Wait-ForResultScreen -Game $game -MissingMessage '결과 없음' -FindRetryButton { $script:retryCalls++; if ($script:retryCalls -ge 1) { @{ X = 1; Y = 1 } } else { $null } }
Assert-Case '결과 대기: 커서 미확인 재터치 → 건너뜀 로그 1·양보 0' "$(Get-LogCount '클리어 화면 재터치를 건너뜀 (커서 미확인)')/$($script:yieldCalls)" '1/0'
# R5. 판독 헬퍼 안의 커서 대피 양보(이 루프 코드가 부르지 않는 곳)도 만료 판정에 반영 (반박 검토 major):
#     Close-NetworkUnstablePopup 모의가 첫 호출에서 '커서 대피 양보 100초'처럼 누적 변수만 올리고 시계를
#     전진 → while 조건의 Get-YieldAdjustedDeadline 이 반영해야 90초 상한을 넘겨도 반복 버튼에 도달
function Close-NetworkUnstablePopup {
  param($Game, $LogPrefix)
  if (-not $script:helperYieldDone) {
    $script:helperYieldDone = $true
    $script:vclock = $script:vclock.AddMilliseconds(100000)
    $script:userYieldTotalMs = [double]$script:userYieldTotalMs + 100000
  }
  return $false
}
Reset-Mock
$script:helperYieldDone = $false
$script:mockPromptQueue = New-Object System.Collections.Queue
$script:retryCalls = 0
$threw = $false
try { $rp = Wait-ForResultScreen -Game $game -MissingMessage '결과 없음' -FindRetryButton { $script:retryCalls++; if ($script:retryCalls -ge 2) { @{ X = 1; Y = 1 } } else { $null } } }
catch { $threw = $true }
Assert-Case '결과 대기: 판독 헬퍼 안 커서 대피 양보(100초)도 만료 판정에 반영돼 도달' "$threw/$($null -ne $rp)/$($script:yieldCalls)" 'False/True/0'
function Close-NetworkUnstablePopup { param($Game, $LogPrefix) return $false }
# 헬퍼 단위: 차분 반영 1회 + 재호출 0 + 반환값이 갱신된 마감
$script:userYieldTotalMs = [double]25000
$dl2 = [datetime]'2026-01-01 00:01:00'; $seen2 = [double]5000
$ret = Get-YieldAdjustedDeadline -Deadline ([ref]$dl2) -SeenYieldMs ([ref]$seen2)
$ret2 = Get-YieldAdjustedDeadline -Deadline ([ref]$dl2) -SeenYieldMs ([ref]$seen2)
Assert-Case '만료 판정 헬퍼: 차분 20초 반영 → +20, 재호출 +0, 반환 = 갱신 마감' "$(($ret - [datetime]'2026-01-01 00:01:00').TotalSeconds)/$(($ret2 - $ret).TotalSeconds)/$($seen2)" '20/0/25000'
# R4. 양보 없이 끝내 못 찾으면 기존대로 throw (연장이 무한 대기를 만들지 않음)
Reset-Mock
$script:mockPromptQueue = New-Object System.Collections.Queue
$threw = $false
try { [void](Wait-ForResultScreen -Game $game -MissingMessage '결과 없음' -FindRetryButton { $null }) } catch { $threw = $true }
Assert-Case '결과 대기: 양보 없는 미발견은 기존대로 throw' $threw $true
# 배선: 다음 층·다시 하기 루프
Assert-Case "배선: '다음 층으로' 대기 루프 양보 2곳(서두 게이트+재클릭 경합) + 초기 클릭 양보 후 재탐색" `
  (([regex]::Matches($workerCode, "Invoke-UserYieldWithDeadline -Game \`$Game -Context `"'다음 층으로' 전환 대기`"").Count -eq 3) -and
   ($workerCode -match "Wait-UserYieldEnd -Game \`$Game -Context `"'다음 층으로' 클릭`"\s+\`$yieldedBeforeRetry = \`$true\s+\`$nextFloorPoint = Find-DgNextFloorButtonPoint")) 'True'
Assert-Case "배선: '다시 하기' 복귀 루프 양보 2곳 + 초기 클릭 양보 후 재탐색(못 찾으면 고정 좌표 강행 금지)" `
  (([regex]::Matches($workerCode, "Invoke-UserYieldWithDeadline -Game \`$Game -Context `"'다시 하기' 복귀 대기`"").Count -eq 4) -and
   ($workerCode -match "Wait-UserYieldEnd -Game \`$Game -Context `"'다시 하기' 클릭`"\s+\`$dgRetryPoint = Find-DgRetryButtonPoint") -and
   ($workerCode.Contains('$dgRetryClickSkipped = $true'))) 'True'
Assert-Case '배선: 결과 화면 대기 루프 양보 4곳(서두 게이트 + 컷신/재터치/전리품 경합)' `
  ([regex]::Matches($workerCode, "Invoke-UserYieldWithDeadline -Game \`$Game -Context '결과 화면 대기'").Count) 4
# 반박 검토 반영: 5개 시간 상한 루프의 만료 판정이 전부 누적 양보를 반영 (ClickUntil 외·내부 while 2 +
# VerifiedExit + 결과 화면 + 다음 층 + 다시 하기 = 6 조건식)
# 09-08 어비스 배치 +3: Return-ToAbyssSelection(60초) + 이동하기 2곳(30초) / +1: 사냥터 첫 화면 복귀(40초)
# 2026-09-09 +1: Wait-ForScreen (Codex P2 - Condition 안의 팝업 스윕이 판독 직전 커서 대피를
#   부르고 그 양보가 상한 없는데 마감에서 빠지지 않아, 양보 뒤 스윕이 팝업을 닫아 Condition 이
#   거짓이 된 회전에서 시간 초과 throw → 코드 1 + 자동 재시도 소모였음)
# 2026-09-13 +1: 마지막 판 '나가기' 필드 복귀 확인(40초) - 취소된 클릭·Space·wait 경로의 양보가 마감에서 빠지던 자리
Assert-Case '배선: 시간 상한 루프 만료 판정 12곳이 Get-YieldAdjustedDeadline 경유' `
  ([regex]::Matches($workerCode, '-lt \(Get-YieldAdjustedDeadline -Deadline \(\[ref\]\$\w+\) -SeenYieldMs \(\[ref\]\$\w+\)\)\)').Count) 12
# 2차 배치 잔여분 (생활·냥 상인·더블 루팅 정정) - 2026-09-08 사용자 지시로 전량 처리
Assert-Case '생활: 메뉴 사이클 입력 5곳 양보 게이트 + 회전 미계상(while 전환)' `
  (([regex]::Matches($workerCode, 'Test-LifeYieldBeforeInput -Game \$Game -Step').Count -eq 5) -and
   ($workerCode.Contains('while ($menuTry -lt 3 -and -not $menuOk -and (Get-Date) -le (Get-LifeCycleDeadline))')) -and
   ($workerCode -match '\$script:lifeMenuYielded\) \{[\s\S]{0,200}?\$menuTry--')) 'True'
Assert-Case '생활: 링크 클릭 전송 확인(생략이면 퀘스트 확인으로 안 넘어감)' `
  ($workerCode.Contains("[생활] '가까운 위치 찾기' 클릭이 전송되지 않았습니다")) 'True'
# 시계 동결은 **두 경로 모두**(사전 게이트·경합 백업) 필요 - 하나만 세면 한쪽 제거를 놓칩니다
# (2026-09-09 변이 검증 적발: M4 가 한 곳만 지워도 통과했음)
Assert-Case '냥 상인: 구매·재클릭·다시 뽑기 3곳 양보(재클릭 기회·구매 확인 시계 보호)' `
  (([regex]::Matches($workerCode, "Wait-UserYieldEnd -Game \`$Game -Context '냥 상인").Count -ge 5) -and
   ([regex]::Matches($workerCode, '\$purchaseWaitClock\.Stop\(\)\s+Wait-UserYieldEnd -Game \$Game -Context ''냥 상인 구매 확인''\s+\$purchaseWaitClock\.Start\(\)').Count -eq 2)) 'True'
Assert-Case '냥 상인: 안전 중지 확인은 여전히 클릭 직전 마지막 동작(양보 게이트는 그 앞)' `
  ([bool]($workerCode -match "if \(Test-UserRecentlyActive\) \{\s+Wait-UserYieldEnd -Game \`$Game -Context '냥 상인 다시 뽑기'\s+continue\s+\}[\s\S]{0,900}Test-Path -LiteralPath \`$safeStopFlagPath")) 'True'
Assert-Case '더블 루팅 정정 2곳: 양보 후 소모량 재확인으로 정정 필요성 재판단' `
  (([regex]::Matches($workerCode, "Wait-UserYieldEnd -Game \`$Game -Context '더블 루팅 정정'").Count -eq 2) -and
   ([regex]::Matches($workerCode, '양보 중 공물 소모량이 예상').Count -eq 2)) 'True'
Assert-Case '사냥터: 첫 화면 복귀 루프 양보(서두 게이트 + 재클릭·정리 Space)' `
  ([regex]::Matches($workerCode, "Invoke-UserYieldWithDeadline -Game \`$Game -Context '사냥터 첫 화면 복귀'").Count) 3

# ---- 4d. 어비스 경로 배치 (2026-09-08 22:51 실사고: 마우스 사용 중 난이도 3회 소진 → 코드 4 정지) ----
Assert-Case '어비스: 난이도 루프 재개(대기 → 목표 던전 확정 → 재탐색) + 시도 미소모' `
  (($workerCode.Contains("if (`$script:lastClickSkipReason -eq 'user-active') { `$abyssDiffTry--; `$abyssDiffRefind = `$true; continue }")) -and
   ($workerCode.Contains("`$abyssDiffStopReason = '양보 후 난이도 글자 재탐색 실패'; break")) -and
   ($workerCode.Contains("`$abyssDiffStopReason = '양보 후 목표 던전 상세 화면을 확인하지 못함'; break"))) 'True'
# 제목이 읽히면 목표 일치 필수, 안 읽히면 3회 재판독 후 거짓 (Test-DetailTitleMatches 의 '입장 버튼만으로
# 통과'는 양보 재개에 쓰면 다른 던전도 통과 - Codex P1)
Assert-Case '어비스: 양보 재개 전용 목표 던전 판정(fail-closed)' `
  (($workerCode -match 'function Test-AbyssDetailTargetConfirmed[\s\S]{0,700}if \(\$titleNow\) \{ return \$titleNow\.Contains\(\$dungeonMatch\) \}[\s\S]{0,200}return \$false')) 'True'
Assert-Case '어비스: 탭 확인 실패는 정지(반환을 버리지 않음) 4곳' `
  ([regex]::Matches($workerCode, "if \(-not \(Confirm-TabSelected -Game \`$game[^\r\n]*\)\) \{").Count) 4
Assert-Case '탭 확인: 양보 시 재클릭 기회 미소모 + 경합 pending' `
  (($workerCode.Contains('$script:tabConfirmYieldPending = $true')) -and
   ($workerCode -match '\(\(Test-UserRecentlyActive\)\) -or \$script:tabConfirmYieldPending|\(Test-UserRecentlyActive\) -or \$script:tabConfirmYieldPending')) 'True'
# 2026-09-11: 대기와 반환 사이에 호출부용 결과 전달($Outcome = 'user-active')이 한 줄 들어감 -
# 계약(대기 후 $false)은 그대로라 그 한 줄만 허용. 결과 전달 자체는 test_event_overlay_yield.ps1 이 봄
Assert-Case '이벤트 화면: Space 주입 전 양보 게이트(대기 후 재판독)' `
  ([bool]($workerCode -match "if \(Test-UserRecentlyActive\) \{\s+Wait-UserYieldEnd -Game \`$Game -Context '이벤트 화면 처리'\s+(?:if \(\`$Outcome[^\r\n]*\s+)?return \`$false")) 'True'
# unknownSince 보정은 누적 변수 차분으로 (서두 게이트뿐 아니라 판독 헬퍼 안 커서 대피 양보까지 - Codex P2)
Assert-Case '어비스: 선택 화면 복귀 루프 서두 게이트 + 알 수 없는 화면 20초 판정에서 양보 제외' `
  (($workerCode -match "if \(Test-UserRecentlyActive\) \{\s+Invoke-UserYieldWithDeadline -Game \`$Game -Context '어비스 선택 화면 복귀' -Deadline \(\[ref\]\`$deadline\) -SeenYieldMs \(\[ref\]\`$seenYieldMs\)\s+continue") -and
   ($workerCode.Contains('if ($null -eq $unknownSince) { $unknownSince = Get-Date; $unknownSeenYieldMs = [double]$script:userYieldTotalMs }')) -and
   ($workerCode -match '\$unknownSince = \$unknownSince\.AddMilliseconds\(\[double\]\$script:userYieldTotalMs - \$unknownSeenYieldMs\)')) 'True'
Assert-Case '어비스: X 후보 순환 - 조작 생략은 유지, 커서 미확인은 다음 후보로' `
  (($workerCode -match "\`$xAttempts\+\+\s+Write-RunLog `"\[안내\] 복귀 중 닫기\(X\) 후보[^\r\n]*커서 미확인")) 'True'
Assert-Case '어비스: 복구 ESC 키 주입 전 양보 게이트(Press-KeyOnce 에는 게이트 없음)' `
  ([bool]($workerCode -match "Invoke-UserYieldWithDeadline -Game \`$Game -Context '어비스 선택 화면 복귀'[^\r\n]*\r?\n\s+continue\s+\}\s+Focus-Game -Game \`$Game\s+Press-KeyOnce -VirtualKey 0x1B")) 'True'
Assert-Case '난이도 확인: 양보 후 RefindPoint 재탐색(호출부 5곳 전달) + 실패 시 재클릭 금지' `
  (([regex]::Matches($workerCode, '-RefindPoint \{').Count -eq 5) -and
   ($workerCode.Contains('Write-RunLog "[경고] 양보 후 난이도 ''$Label'' 글자를 다시 찾지 못했습니다 - 재클릭하지 않고 확인 실패로 처리합니다"')) -and
   ($workerCode.Contains('$script:difficultyConfirmYieldPending = $true'))) 'True'
# 2026-09-10: 같은 '재판독 계약'을 던전·사냥터 '파티 찾기' 2곳이 추가로 채택했습니다
#   (단일 줄 elseif 형은 토글 3곳 전용 그대로 - 파티찾기는 여러 줄 형태)
Assert-Case '토글 3곳 + 파티찾기 2곳: user-active 생략 뒤에는 유휴 여부와 무관하게 재판독(옛 상태 재사용 금지)' `
  (([regex]::Matches($workerCode, "elseif \(\`$script:lastClickSkipReason -eq 'user-active'\) \{ \`$\w+Recheck = \`$true \}").Count -eq 3) -and
   ([regex]::Matches($workerCode, '\$\w+Recheck -or \(Test-UserRecentlyActive\)').Count -eq 5)) 'True'
Assert-Case '어비스: 복귀 루프 클릭 로그 정직화 5곳(메뉴/ESC/공지 X/나가기 + 생략 시 마감 연장)' `
  (([regex]::Matches($workerCode, "클릭 건너뜀 \(\`$\(if \(\`$script:lastClickSkipReason -eq 'user-active'\)").Count -ge 4) -and
   ([regex]::Matches($workerCode, "Invoke-UserYieldWithDeadline -Game \`$Game -Context '어비스 선택 화면 복귀'").Count -ge 6)) 'True'
Assert-Case '어비스: 스텔라·X 후보 카운터는 실제 클릭 뒤에만 증가(생략으로 상한 소진 금지)' `
  (($workerCode -match '\$script:lastClickPerformed\) \{\s+\$stellaHandled\+\+') -and
   ($workerCode -match '\$script:lastClickPerformed\) \{\s+\$xAttempts\+\+')) 'True'
Assert-Case '어비스: 이동하기 루프 2곳 서두 게이트 + 경합 백업(마감 연장)' `
  ([regex]::Matches($workerCode, "Invoke-UserYieldWithDeadline -Game \`$game -Context '이동하기 클릭'").Count) 4
Assert-Case '어비스: 파티찾기 토글 단발 전송 확인 루프(양보 중 사용자가 끄면 클릭 생략)' `
  (($workerCode.Contains("while (-not `$abyssToggleSent -and `$toggleState -eq 'on')")) -and
   ($workerCode.Contains("[어비스] '우연한 만남' 토글 꺼짐 확인 (양보 중 전환됨 - 파티찾기 준비)"))) 'True'
Assert-Case "배선: '다음 층으로' 양보 사실을 '다시 하기' 게이트에 전달(옛 좌표 낙하 경로 차단)" `
  (($workerCode.Contains('$yieldedBeforeRetry = $true')) -and
   ($workerCode.Contains('if ($yieldedBeforeRetry -or (Test-UserRecentlyActive)) {'))) 'True'
Assert-Case "배선: 40초 루프의 '계속하기'·공지 닫기 로그는 실제 클릭일 때만" `
  (([regex]::Matches($workerCode, "'계속하기' 클릭을 건너뜀").Count -eq 2) -and
   ($workerCode.Contains('공지 게시판 X 닫기 클릭을 건너뜀'))) 'True'
# 어비스 복귀 루프의 클릭 생략 → 즉시 마감 연장 (메뉴·ESC·공지 X·나가기 4곳 + 스텔라 2·X 후보 1 = elseif)
Assert-Case '배선: 어비스 복귀 루프 클릭 생략 시 즉시 마감 연장 7곳' `
  ([regex]::Matches($workerCode, "Invoke-UserYieldWithDeadline -Game \`$Game -Context '어비스 선택 화면 복귀'").Count) 9   # 서두 게이트 1 + 복구 ESC 게이트 1 + 클릭 생략 7

# ---- 4c. Codex 리뷰 반영 (2026-09-08): 양보 후 입장 판정은 긍정 증거 / 결과 화면 인계 / 재탐색 실패 폐기 ----
$rgQuestTracker = @(0, 0, 10, 10); $ocrKoreanEngine = $null
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine) return $script:mockQuestText }
function Test-HomeEndEscHud { param($Game) return $script:mockHud }
function Test-DgImePopupVisible { param($Game) return $false }
function Find-HtEntryButtonPoint { param($Game) return $script:mockHtEntry }
# 던전: 옵션 화면 그대로 → 'options' (클릭 없이 다음 회전)
function Read-DgTitleText { param($Game) return $script:mockTitle }
Reset-Mock; $script:mockTitle = '페카고분 심층 2층 2구역'; $script:mockQuestText = ''; $script:mockHud = $true
Assert-Case '입장 양보 후(던전): 제목에 구역 = 옵션 화면 그대로' (Resolve-DgEntryAfterYield -Game $game) 'options'
# 던전: 필드로 나감(HUD 만 있고 추적기에 구역 없음) → 15초 뒤 'unknown' (예전 판정은 여기서 입장으로 오인)
Reset-Mock; $script:mockTitle = ''; $script:mockQuestText = '일일 임무 진행'; $script:mockHud = $true
$r = Resolve-DgEntryAfterYield -Game $game
Assert-Case '입장 양보 후(던전): HUD 만 있고 추적기에 구역 없음(필드) = unknown, 15초 폴링' "$r/$(($script:vclock - [datetime]'2026-01-01 00:00:00').TotalSeconds -ge 15)" 'unknown/True'
# 던전: 로딩 뒤 던전 내부(HUD + 추적기 '2구역 클리어') → 'entered'
Reset-Mock; $script:mockTitle = ''; $script:mockQuestText = '심층2층2구역클리어'; $script:mockHud = $true
Assert-Case '입장 양보 후(던전): HUD + 추적기 구역 = entered' (Resolve-DgEntryAfterYield -Game $game) 'entered'
# 사냥터: 첫 화면 / 내부 / unknown
Reset-Mock; $script:mockHtEntry = @{ X = 1; Y = 1 }; $script:mockQuestText = ''
Assert-Case '입장 양보 후(사냥터): 입장 버튼 보임 = options' (Resolve-HtEntryAfterYield -Game $game) 'options'
Reset-Mock; $script:mockHtEntry = $null; $script:mockQuestText = '소탕임무진행'
Assert-Case '입장 양보 후(사냥터): 추적기 소탕 = entered' (Resolve-HtEntryAfterYield -Game $game) 'entered'
Reset-Mock; $script:mockHtEntry = $null; $script:mockQuestText = ''
Assert-Case '입장 양보 후(사냥터): 둘 다 아님 = unknown' (Resolve-HtEntryAfterYield -Game $game) 'unknown'
function Read-DgTitleText { param($Game) return '페카고분 1층 1구역' }
# 결과 화면 인계: 양보가 있었던 호출에서만 PastResultCondition 을 보고, 참이면 $null + 플래그
Reset-Mock -ActiveSeq @($true) -YieldMs 5000
$script:mockPromptQueue = New-Object System.Collections.Queue
$script:pastCalls = 0
$rp = Wait-ForResultScreen -Game $game -MissingMessage '결과 없음' -FindRetryButton { $null } -PastResultCondition { $script:pastCalls++; $true }
Assert-Case '결과 대기: 양보 후 다음 화면 도달 → $null 반환 + 플래그' "$($null -eq $rp)/$($script:resultScreenSkippedByUser)/$($script:pastCalls)" 'True/True/1'
Reset-Mock
$script:mockPromptQueue = New-Object System.Collections.Queue
$script:pastCalls = 0
$script:retryCalls = 0
$rp = Wait-ForResultScreen -Game $game -MissingMessage '결과 없음' -FindRetryButton { $script:retryCalls++; if ($script:retryCalls -ge 2) { @{ X = 1; Y = 1 } } else { $null } } -PastResultCondition { $script:pastCalls++; $true }
Assert-Case '결과 대기: 양보 없으면 다음 화면 조건을 보지 않음(기존 흐름 불변)' "$($null -ne $rp)/$($script:resultScreenSkippedByUser)/$($script:pastCalls)" 'True/False/0'
# 배선
Assert-Case '배선: 던전·사냥터 입장 루프 양보 후 판정이 긍정 증거 헬퍼 경유(각 2곳) + unknown 은 정지' `
  (([regex]::Matches($workerCode, '\$yieldEntry = Resolve-DgEntryAfterYield -Game \$Game').Count -eq 2) -and
   ([regex]::Matches($workerCode, '\$yieldEntry = Resolve-HtEntryAfterYield -Game \$Game').Count -eq 2) -and
   ([regex]::Matches($workerCode, "if \(\`$yieldEntry -eq 'unknown'\) \{\s+Write-RunLog[^\r\n]+\s+exit 4").Count -eq 4)) 'True'
Assert-Case '배선: 우연한 만남 켜기/끄기 재탐색 실패 = 앵커 폐기(정지)' `
  ([regex]::Matches($workerCode, "if \(-not \`$chance(?:Off)?Refound\) \{\s+Write-RunLog[^\r\n]+\s+exit 4").Count) 2
Assert-Case '배선: 사냥터 정정 재탐색 실패 = 정정 없이 종료(옛 절대 좌표 폐기)' `
  ([bool]($workerCode -match 'if \(-not \$htDiffRefound\) \{\s+Write-RunLog[^\r\n]+\s+break')) 'True'
Assert-Case '배선: 40초 루프 팝업 클릭의 조작 생략은 즉시 마감 연장(3곳)' `
  ([regex]::Matches($workerCode, "(?<!else)if \(\`$script:lastClickSkipReason -eq 'user-active'\) \{\s+Invoke-UserYieldWithDeadline -Game \`$Game -Context `"'(?:다음 층으로' 전환|다시 하기' 복귀) 대기`"").Count) 3
Assert-Case '배선: 결과 화면 인계 - 호출부 2곳이 PastResultCondition 전달 + 다시 하기/새 임무 선택 클릭 생략' `
  (([regex]::Matches($workerCode, '-PastResultCondition \{').Count -eq 2) -and
   ($workerCode.Contains('if ($script:resultScreenSkippedByUser) {') -and
   ($workerCode.Contains('if (-not $script:resultScreenSkippedByUser) {')))) 'True'

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
