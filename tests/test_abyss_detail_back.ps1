# 어비스 상세 화면 '<' 뒤로가기의 재클릭 허가·전면화 보존 계약 (2026-09-10)
#
# 배경: 이 두 자리는 전송 확인도 재클릭 경로도 없어, 사용자 조작으로 클릭이 생략되면 한 번도
# 누르지 못한 채 대기만 태우고 초과 throw 였습니다. Invoke-ClickUntil 로 위임하면서 두 가지가
# 새로 생겼고, 그 둘을 여기서 고정합니다.
#   ① 재클릭 허가(SourceCondition)를 '제목 기반'으로 둔 것 - 버튼 기반이면 '이동하기' 상태에서
#      거짓이 되어 원래 가능하던 뒤로가기를 첫 클릭부터 막습니다.
#   ② 주기 전면화 보존 - Invoke-ClickUntil 은 클릭할 때만 전면화하므로, 창이 가려지면
#      Wait-ForScreen 이 하던 복구가 사라집니다.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'

# 운영 함수를 소스에서 그대로 추출해 실행합니다 (사본 재구현 금지 계약).
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @(
    'Test-AbyssKnownDetailScreen', 'Invoke-AbyssBackRefocus', 'Invoke-ClickUntil', 'Get-YieldAdjustedDeadline')) {
  Invoke-Expression $definition
}

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ($Actual -eq $Expected) { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

$game = Get-Process -Id $PID

# ── 공용 스텁 ────────────────────────────────────────────────────────────────
$allDungeonKeywords = @('정박', '광기', '물길')
$script:screenCaptureFailing = $false
$script:detailTitle = ''
$script:enterButtonText = '입장하기'
function Get-DetailTitleText { param($Game) $script:detailTitle }
function Get-EnterButtonText { param($Game) $script:enterButtonText }

# ── 1. 재클릭 허가 판정 (Test-AbyssKnownDetailScreen) ───────────────────────

$script:detailTitle = '허상의정박지'
Check-Equal '등록 던전 제목이면 재클릭 허가' (Test-AbyssKnownDetailScreen -Game $game) $true

$script:detailTitle = '어비스'
Check-Equal '선택 화면 제목이면 재클릭 금지' (Test-AbyssKnownDetailScreen -Game $game) $false

$script:detailTitle = ''
Check-Equal '제목이 비면 재클릭 금지' (Test-AbyssKnownDetailScreen -Game $game) $false

# 핵심 설계 결정: 버튼이 아니라 제목으로 판정하는 이유.
# 캐릭터가 멀면 하단 버튼이 '입장하기' → '이동하기' 로 바뀌어, 버튼 기반 판정은 거짓이 됩니다.
# 제목은 그대로이므로 이 상태에서도 뒤로가기가 살아 있어야 합니다.
$script:detailTitle = '광기의물길'
$script:enterButtonText = '이동하기'   # 버튼 기반 판정이면 여기서 거짓이 됨
Check-Equal "'이동하기' 상태에서도 재클릭 허가 (버튼 아닌 제목 기준)" (Test-AbyssKnownDetailScreen -Game $game) $true
$script:enterButtonText = '입장하기'

# 판독 도중 캡처가 실패하면 그 결과를 믿으면 안 됩니다.
$script:detailTitle = '허상의정박지'
function Get-DetailTitleText { param($Game) $script:screenCaptureFailing = $true; '' }
$script:screenCaptureFailing = $false
Check-Equal '판독 도중 캡처가 실패하면 재클릭 금지' (Test-AbyssKnownDetailScreen -Game $game) $false

# 캡처 실패 검사가 **판독 뒤**여야 하는 진짜 이유: 판독이 성공하면 그 안에서 캡처 성공이
# 등록되어 실패 표시가 풀립니다. 먼저 검사하면 직전까지 실패였다는 **낡은 표시** 때문에
# 화면이 이미 돌아왔는데도 이 함수가 거짓을 돌려줍니다.
# ※ 푸는 것은 글자 인식 성공이 아니라 **캡처 성공**입니다. 그리고 이건 **이 함수 단독의 계약**이라,
#   실제 배선에서는 앞서 도는 목표 판독이 복구 탐침 역할을 해 회차가 영구 정지하지는 않습니다
#   (2026-09-10 리뷰 정정 - 단독 함수의 계약과 실제 정지 재현을 구분할 것).
# (앞뒤 어느 쪽이든 거짓이 나오는 케이스만으로는 이 순서가 고정되지 않습니다 - 그래서 이 단언을
#  따로 둡니다. 2026-09-10: 처음 쓴 캡처 단언은 순서를 전혀 구분하지 못했습니다.)
$script:screenCaptureFailing = $true
function Get-DetailTitleText { param($Game) $script:screenCaptureFailing = $false; $script:detailTitle }
Check-Equal '판독 성공으로 캡처가 복구되면 재클릭 허가 (판독 뒤 검사여야 통과)' (Test-AbyssKnownDetailScreen -Game $game) $true

# 이후 케이스를 위해 부작용 없는 스텁으로 되돌립니다.
function Get-DetailTitleText { param($Game) $script:detailTitle }
$script:screenCaptureFailing = $false

# ── 2. 주기 전면화 보존 (Invoke-AbyssBackRefocus) ───────────────────────────

$script:refocusCalls = 0
$script:refocusResult = $true
function Invoke-AutoRefocus { param($Game) $script:refocusCalls++; $script:refocusResult }

# (a) 아무 값도 흘리지 않아야 합니다 - 호출부 Condition 안에서 도는데 값이 새면
#     화면 판정 결과와 섞여 `-and` 가 배열을 받습니다.
$refocusEverySeconds = 8
$script:abyssBackRefocusAt = (Get-Date).AddSeconds(-60)
$emitted = @(Invoke-AbyssBackRefocus -Game $game)
Check-Equal '전면화 함수는 아무 값도 반환하지 않음' $emitted.Count 0

# (b) 주기가 지나면 시도하고, 성공하면 시각을 갱신해 곧바로 또 부르지 않습니다.
$script:refocusCalls = 0
$script:abyssBackRefocusAt = (Get-Date).AddSeconds(-60)
Invoke-AbyssBackRefocus -Game $game
Check-Equal '주기 경과 시 전면화 시도' $script:refocusCalls 1
Invoke-AbyssBackRefocus -Game $game
Check-Equal '성공 직후에는 주기 전이라 재시도 안 함' $script:refocusCalls 1

# (c) 가려지지 않았으면(거짓 반환) 시각을 갱신하지 않아 다음 폴링에서 다시 확인합니다.
$script:refocusResult = $false
$script:refocusCalls = 0
$script:abyssBackRefocusAt = (Get-Date).AddSeconds(-60)
Invoke-AbyssBackRefocus -Game $game
Invoke-AbyssBackRefocus -Game $game
Check-Equal '가려지지 않았으면 시각 갱신 없이 다음 폴링에서 재확인' $script:refocusCalls 2
$script:refocusResult = $true

# (d) 설정으로 끄면(0) 아예 시도하지 않습니다.
$refocusEverySeconds = 0
$script:refocusCalls = 0
$script:abyssBackRefocusAt = (Get-Date).AddSeconds(-60)
Invoke-AbyssBackRefocus -Game $game
Check-Equal '전면화를 끄면(0) 시도하지 않음' $script:refocusCalls 0
$refocusEverySeconds = 8

# ── 3. 통합: **운영 호출부를 소스에서 그대로 꺼내 실행** ────────────────────
# 여기서 호출을 다시 써서 만들면 안 됩니다. 2026-09-10 리뷰에서, 실제 호출부를
# `-SourceCondition { $true }` 로 변이시켜도 이 파일의 단언이 **전부 통과**하는 것이 확인됐습니다
# (테스트가 자기가 지어낸 호출만 검사하고 있었습니다). 그래서 AST 로 실제 호출문을 꺼내 돌립니다.
$tokens = $null; $parseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$tokens, [ref]$parseErrors)
$backCallAsts = @($workerAst.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.CommandAst] -and
      $node.GetCommandName() -eq 'Invoke-ClickUntil' -and
      $node.Extent.Text -match '\$ptDetailBack'
    }, $true))
Check-Equal '운영 뒤로가기 호출부를 소스에서 2곳 추출' $backCallAsts.Count 2
$backCalls = @($backCallAsts | ForEach-Object { [scriptblock]::Create($_.Extent.Text) })

# 호출부가 참조하는 변수들 (소스와 같은 이름)
$ptDetailBack = @(43, 67)
$timeoutAbyssSelect = 3

$script:clickCount = 0
$script:yieldWaits = 0
$script:userYieldTotalMs = [double]0
$script:lastClickPerformed = $false
$script:lastClickSkipReason = ''
$script:userActiveSeq = @()
$script:clickSendSeq = @()
$script:selectionReached = $false
function Test-AbyssSelectionScreen { param($Game) $script:selectionReached }

function Focus-Game { param($Game) }
function Test-SafeStopDuringCaptureFail {}
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) }
# 시퀀스는 **인덱스로** 소비합니다. `$head, $rest = @($x)` 식으로 줄이면 소진 시 `@($null)`(Count 1)이
# 남아 계속 거짓을 돌려주고, 그러면 클릭이 영원히 생략돼 무한 루프가 됩니다 (2026-09-10 실제로 겪음).
# 소진 후에는 각 계약의 **기본값**(조작 없음 / 전송됨)으로 떨어져야 합니다.
$script:userActiveIdx = 0
$script:clickSendIdx = 0
function Test-UserRecentlyActive {
  if ($script:userActiveIdx -lt $script:userActiveSeq.Count) {
    $value = $script:userActiveSeq[$script:userActiveIdx]
    $script:userActiveIdx++
    return $value
  }
  return $false
}
function Wait-UserYieldEnd {
  param($Game, $Context)
  $script:yieldWaits++
  # 실제 계약: 조작이 끝날 때까지 기다린 시간만큼 누적 양보가 늘어납니다.
  $script:userYieldTotalMs += 3000
}
function Click-GamePoint {
  param($Game, $ReferenceX, $ReferenceY)
  # 전송 여부를 시퀀스로 정합니다 (소진 후 기본은 전송).
  $sent = $true
  if ($script:clickSendIdx -lt $script:clickSendSeq.Count) {
    $sent = $script:clickSendSeq[$script:clickSendIdx]
    $script:clickSendIdx++
  }
  $script:lastClickPerformed = $sent
  $script:lastClickSkipReason = if ($sent) { '' } else { 'user-active' }
  # 실제 클릭이 나갔을 때만 화면이 넘어갑니다.
  if ($sent) { $script:clickCount++; $script:selectionReached = $true }
}

function Reset-Case {
  param($ActiveSeq = @(), $SendSeq = @())
  $script:clickCount = 0
  $script:yieldWaits = 0
  $script:selectionReached = $false
  $script:detailTitle = '허상의정박지'
  $script:screenCaptureFailing = $false
  $script:userActiveIdx = 0; $script:userActiveSeq = @($ActiveSeq)
  $script:clickSendIdx = 0;  $script:clickSendSeq = @($SendSeq)
  $script:abyssBackRefocusAt = Get-Date
}

foreach ($callIndex in 0..1) {
  $backCall = $backCalls[$callIndex]
  $label = "호출부$($callIndex + 1)"

  # (a) 조작이 없으면 한 번 눌러 복귀합니다.
  Reset-Case
  & $backCall
  Check-Equal "$label - 조작이 없으면 한 번 눌러 복귀" $script:clickCount 1
  Check-Equal "$label - 조작이 없으면 양보 대기 없음" $script:yieldWaits 0

  # (b) 게이트에서 조작이 잡히면 **기다린 뒤** 다시 확인하고 그 다음에 누릅니다.
  #     (이 수정 전에는 기다리지 않고 대기만 태우다 초과 throw 였습니다)
  Reset-Case -ActiveSeq @($true, $true, $false)
  & $backCall
  Check-Equal "$label - 조작 중에는 기다렸다가 복구" $script:clickCount 1
  Check-Equal "$label - 조작한 횟수만큼 양보 대기" $script:yieldWaits 2

  # (c) 게이트는 통과했는데 클릭 직전에 조작이 시작돼 생략된 경우도 같은 양보 경로를 탑니다.
  Reset-Case -SendSeq @($false, $false)
  & $backCall
  Check-Equal "$label - 클릭 직전 경합으로 생략돼도 기다린 뒤 복구" $script:clickCount 1
  Check-Equal "$label - 생략된 횟수만큼 양보 대기" $script:yieldWaits 2

  # (d) ★ 이미 선택 화면인데 목표 판독만 실패하는 경우 - **클릭이 나가면 안 됩니다.**
  #     재클릭 허가가 `$true` 로 변이되면 여기서 잡힙니다 (2026-09-10 리뷰가 지적한 구멍).
  Reset-Case
  $script:detailTitle = '어비스'      # 상세 화면이 아님 = 허가 거짓
  try { & $backCall } catch { }       # 목표를 못 찾아 시간 초과 throw 는 정상
  Check-Equal "$label - 선택 화면에서는 목표 판독이 실패해도 클릭 금지" $script:clickCount 0

  # (e) ★ 창 가림이 풀린 뒤 **마감 전에** 다시 눌러야 합니다.
  #     재클릭 간격이 기본 5초면 내부 대기가 목표 화면만 보느라 소스 재판독을 못 해
  #     제한 시간(3초)을 그대로 흘리고 클릭 0회로 끝납니다 (리뷰의 가상 시계 재현을 고정).
  Reset-Case
  $script:coverUntil = (Get-Date).AddMilliseconds(1200)
  function Get-DetailTitleText { param($Game) if ((Get-Date) -lt $script:coverUntil) { '' } else { $script:detailTitle } }
  try { & $backCall } catch { }
  Check-Equal "$label - 가림이 풀리면 마감 전에 재클릭" $script:clickCount 1
  function Get-DetailTitleText { param($Game) $script:detailTitle }
}

# ── 4. 운영 호출부가 계약을 지키는지 (소스 문자열 단언) ────────────────────
# 주석을 뺀 사본으로 검사합니다 (Extent.Text 는 주석을 포함하므로).
$workerRaw = Get-Content -LiteralPath $workerPath -Raw -Encoding UTF8
$workerBody = (($workerRaw -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
$backCalls = ([regex]::Matches($workerBody, 'Invoke-ClickUntil\s+-Game\s+\$game\s+-Point\s+\$ptDetailBack')).Count
Check-Equal '뒤로가기 2곳 모두 상태 기반 재클릭 헬퍼를 사용' $backCalls 2
$backRefocus = ([regex]::Matches($workerBody, 'Invoke-AbyssBackRefocus\s+-Game\s+\$game')).Count
Check-Equal '뒤로가기 2곳 모두 주기 전면화를 보존' $backRefocus 2
$rawBackClick = ([regex]::Matches($workerBody, 'Click-GamePoint[^\r\n]*\$ptDetailBack')).Count
Check-Equal '뒤로가기에 확인 없는 생클릭이 남아 있지 않음' $rawBackClick 0

# 재클릭 간격을 기본(5초)에 맡기면 안 됩니다 - 위 (e) 시나리오가 그 이유입니다.
$backReclick = ([regex]::Matches($workerBody, '\$timeoutAbyssSelect\s+-ReclickEverySeconds\s+1')).Count
Check-Equal '뒤로가기 2곳 모두 재클릭 간격을 1초로 명시' $backReclick 2

# 헬퍼의 양보 게이트보다 먼저 도는 무조건 전면화가 남아 있으면 안 됩니다
# (클릭은 양보하면서 ALT 입력과 전면화는 이미 해 버리는 모순 - 2026-09-10 리뷰).
$backAutoRefocus = ([regex]::Matches($workerBody, 'Invoke-AutoRefocus -Game \$game \| Out-Null')).Count
Check-Equal '뒤로가기 2곳 모두 설정을 따르는 전면화를 사용' $backAutoRefocus 2

exit $fails
