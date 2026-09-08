# 옵션 화면 구역 전환 루프(Set-DgOptionStage) 시뮬레이션 진리표
# 본체: mabinogi_run_once.ps1 Set-DgOptionStage (실함수를 AST로 추출해 모의 의존성으로 실행)
# 배경: 2026-07-26 실사고 - 피오드 옵션 화면 제목 '[피오듸층1구역' 지속 불명 상태에서
#   ① 내부 보조 판정이 배율 4·6만 읽어 표 부족(null) ② null인데도 1회 잠금에 걸려 재시도 불가
#   → 클릭 한 번 없이 8회 대기만 하다 정지. 수정: 배율 3 추가 + null은 잠금 제외 +
#   시작 분기 확정 시 첫 클릭 허용(-AssumeMismatchFirst, 같은 층 목표 카드 클릭은 멱등).
# 2026-09-08 09:07 실사고(v2.1.6 배포 직후): 사용자 조작 중 Click-ScreenPoint 가 클릭을 버리는데
#   이 루프는 결과 메타를 보지 않아 3회를 7초 만에 소진 → 코드 4 정지. 수정: 사용자 양보 계약
#   (대기 + 시도 회수 미소모 + 재판독부터) + 로그 정직성(실제 클릭/커서 실패/양보 분기).
#   모의 클릭이 lastClickPerformed/lastClickSkipReason 을 설정해야 새 계약을 검증할 수 있음 (Codex).
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Test-CustomTitleStageMatch', 'Set-DgOptionStage')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ---- 모의 의존성 (Set-DgOptionStage가 호출하는 함수들을 시퀀스 기반으로 대체) ----
function Get-DgOptObservedStage {
  param($Game, $TitleText)
  $script:assistCalls++
  if ($script:mockAssistQueue.Count -gt 0) { return $script:mockAssistQueue.Dequeue() }
  return $null   # 시퀀스 소진 = 계속 불명
}
function Get-DgOptStageCardPoint { param($Game, $Stage) return $script:mockCardPoint }
function Focus-Game { param($Game) }
function Move-CursorOutsideGame { param($Game) }   # v2.1.7: 양보 재판독 직전 커서 대피 (모의 - 판정에 영향 없음)
function Invoke-MockClickOutcome {
  # 클릭 결과 큐: 'performed'(기본) / 'user-active' / 'cursor-not-ready' - 실제 Click-ScreenPoint 의
  # 메타 계약($script:lastClickPerformed / $script:lastClickSkipReason)을 그대로 흉내냅니다
  $outcome = 'performed'
  if ($script:mockClickQueue.Count -gt 0) { $outcome = $script:mockClickQueue.Dequeue() }
  if ($outcome -eq 'performed') {
    $script:lastClickPerformed = $true
    $script:lastClickSkipReason = ''
    $script:performedCount++
    if ($script:titleAfterClick) { $script:currentTitle = $script:titleAfterClick }
  } else {
    $script:lastClickPerformed = $false
    $script:lastClickSkipReason = $outcome
  }
}
function Click-ScreenPoint {
  param($X, $Y)
  $script:clickCount++
  Invoke-MockClickOutcome
}
function Click-GamePoint {
  param($Game, $ReferenceX, $ReferenceY)
  $script:clickCount++
  Invoke-MockClickOutcome
}
function Test-UserRecentlyActive {
  # 사전 게이트 호출마다 큐를 하나 소비, 소진되면 '조작 없음'
  if ($script:mockActiveQueue.Count -gt 0) { return [bool]$script:mockActiveQueue.Dequeue() }
  return $false
}
function Wait-UserYieldEnd {
  param($Game, [string]$Context)
  $script:yieldCalls++
  $script:runLogs += "[안내] 양보 대기($Context)"
  # 대기 중 사용자가 화면을 바꾼 상황 모의 (재판독부터 다시 = 클릭 없이 목표 도달 가능)
  if ($script:titleAfterYield) { $script:currentTitle = $script:titleAfterYield }
}
function Write-RunLog { param([string]$Message) $script:runLogs += $Message }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) }   # 대기 생략 (판정 로직만 검증)
$readTitle = { $script:currentTitle }

function Reset-Mock {
  param(
    [string]$Title,
    [object[]]$AssistSeq = @(),
    [string]$AfterClickTitle = '',
    $CardPoint = @{ Screen = @{ X = 918; Y = 238 } },
    [object[]]$ActiveSeq = @(),
    [string[]]$ClickSeq = @(),
    [string]$AfterYieldTitle = ''
  )
  $script:currentTitle = $Title
  $script:mockAssistQueue = New-Object System.Collections.Queue
  foreach ($assist in $AssistSeq) { $script:mockAssistQueue.Enqueue($assist) }
  $script:mockActiveQueue = New-Object System.Collections.Queue
  foreach ($active in $ActiveSeq) { $script:mockActiveQueue.Enqueue($active) }
  $script:mockClickQueue = New-Object System.Collections.Queue
  foreach ($click in $ClickSeq) { $script:mockClickQueue.Enqueue($click) }
  $script:assistCalls = 0
  $script:clickCount = 0
  $script:performedCount = 0
  $script:yieldCalls = 0
  $script:lastClickPerformed = $false
  $script:lastClickSkipReason = ''
  $script:titleAfterClick = $AfterClickTitle
  $script:titleAfterYield = $AfterYieldTitle
  $script:mockCardPoint = $CardPoint
  $script:runLogs = @()
}
function Get-LogCount { param([string]$Needle) return @($script:runLogs | Where-Object { $_.Contains($Needle) }).Count }

# 1. 2026-07-26 사고 재현 + 수정 검증: 제목 지속 불명, 보조 판정이 2회 불명 후 3회째 '1-1'
#    (null 잠금 해제로 재시도가 가능해야 카드 클릭까지 도달 - 구버전은 1회 null 후 영구 잠금)
Reset-Mock -Title '[피오듸층1구역' -AssistSeq @($null, $null, '1-1') -AfterClickTitle '피오드 1층 2구역'
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]'
Assert-Case '사고 재현(보조 재시도): 성공' $result.Ok $true
Assert-Case '사고 재현(보조 재시도): 클릭 1회' $script:clickCount 1
Assert-Case '사고 재현(보조 재시도): 보조 판정 3회 호출(불명 2회 재시도)' $script:assistCalls 3

# 2. 시작 분기 확정 호출(-AssumeMismatchFirst): 제목 불명이어도 첫 클릭 진행 → 클릭 후 제목 확인
Reset-Mock -Title '[피오듸층1구역' -AfterClickTitle '피오드 1층 2구역'
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '첫 클릭 허용: 성공' $result.Ok $true
Assert-Case '첫 클릭 허용: 클릭 1회' $script:clickCount 1
Assert-Case '첫 클릭 허용: 보조 판정 불필요' $script:assistCalls 0
Assert-Case '첫 클릭 허용: 실제 클릭 로그는 시도 예산 표기' (Get-LogCount '구역 1-2 카드 클릭 - 글자 탐색 (시도 1/3)') 1

# 3. 첫 클릭 허용 + 이미 목표 구역(멱등 재선택): 클릭 후에도 제목 불명 → 보조 판정 '목표 일치'로 확인
Reset-Mock -Title '[피오듸층2구역' -AssistSeq @('1-2')
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '멱등 재선택: 성공(보조 판정 확인)' $result.Ok $true
Assert-Case '멱등 재선택: 클릭 1회' $script:clickCount 1
Assert-Case '멱등 재선택: 보조 판정 1회' $script:assistCalls 1

# 4. 첫 클릭 허용은 '첫 클릭 한 번'뿐: 이후 계속 불명이면 재클릭 없이 안전 정지 (무조건 재클릭 금지)
Reset-Mock -Title '[피오듸층1구역'
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '첫 클릭 이후 불명 지속: 안전 정지' $result.Ok $false
Assert-Case '첫 클릭 이후 불명 지속: 사유 not-confirmed' $result.Reason 'not-confirmed'
Assert-Case '첫 클릭 이후 불명 지속: 클릭은 1회뿐(맹목 재클릭 금지)' $script:clickCount 1

# 5. 다른 층 보조 판정은 그대로 안전 실패 (이 화면에서 전환 불가 계약 유지)
Reset-Mock -Title '[피오듸층1구역' -AssistSeq @('2-1')
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]'
Assert-Case '다른 층: 실패' $result.Ok $false
Assert-Case '다른 층: 사유 wrong-floor' $result.Reason 'wrong-floor'
Assert-Case '다른 층: 클릭 없음' $script:clickCount 0

# 6. 스위치 없이 전부 불명: 클릭 없이 안전 정지하되, 보조 판정은 매 회 재시도 (null 잠금 없음)
Reset-Mock -Title '[피오듸층1구역'
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]'
Assert-Case '전부 불명: 안전 정지' $result.Ok $false
Assert-Case '전부 불명: 사유 not-confirmed' $result.Reason 'not-confirmed'
Assert-Case '전부 불명: 클릭 없음' $script:clickCount 0
Assert-Case '전부 불명: 보조 판정 6회 재시도(3회차부터 매 회)' $script:assistCalls 6

# 7. 첫 클릭 허용인데 카드 좌표를 못 만들면 not-found (틀린 좌표 클릭 금지 계약 유지)
Reset-Mock -Title '[피오듸층1구역' -CardPoint $null
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '카드 없음: 실패' $result.Ok $false
Assert-Case '카드 없음: 사유 not-found' $result.Reason 'not-found'
Assert-Case '카드 없음: 실제 클릭 없음' $script:clickCount 0

# 8. 명확한 mismatch 제목은 기존 경로 그대로 (예비 좌표 클릭 분기 포함)
Reset-Mock -Title '피오드 1층 1구역' -AfterClickTitle '피오드 1층 2구역' -CardPoint @{ Reference = @(918, 238) }
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]'
Assert-Case '명확 mismatch: 성공' $result.Ok $true
Assert-Case '명확 mismatch: 클릭 1회' $script:clickCount 1
Assert-Case '명확 mismatch: 보조 판정 불필요' $script:assistCalls 0
Assert-Case '명확 mismatch: 예비 좌표 클릭 로그' (Get-LogCount '구역 1-2 카드 클릭 - 예비 좌표 (시도 1/3)') 1

# 9. 이미 목표 제목이 명확하면 클릭 없이 즉시 성공
Reset-Mock -Title '피오드 1층 2구역'
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '이미 목표(명확): 성공' $result.Ok $true
Assert-Case '이미 목표(명확): 클릭 없음' $script:clickCount 0

# 10. 2026-08-11 23:55 실사고 재현(타 PC 1908 창): 시작 제목 '훈다0'(구역 소실 - 불명)
#     → 첫 클릭 허용으로 예비 좌표 클릭(전환은 실제 성공) → 제목 배율 사다리(s4)가 복구한
#     '로다2증1구역'이 매치 = 성공. 수정 전에는 재판독 8회 전부 '훈다0'이라 Ok=false 로
#     다 된 화면을 두고 exit 4 였음 (케이스 4가 그 구버전 경로의 진리표).
Reset-Mock -Title '훈다0' -AfterClickTitle '로다2증1구역' -CardPoint @{ Reference = @(918, 238) }
$result = Set-DgOptionStage -Game $null -Stage '2-1' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '08-11 실사고 재현: 성공(사다리 복구 제목 매치)' $result.Ok $true
Assert-Case '08-11 실사고 재현: 클릭 1회' $script:clickCount 1

# ---- 2026-09-08 09:07 실사고: 사용자 조작 양보 (실측 제목 '페카고분심층2층3구역]' 그대로) ----
# 11. 사고 재현 (구버전 경로 그대로): 클릭이 조작 때문에 3회 연속 생략됨 - 구버전은 생략을
#     모른 채 3회 소진 후 not-confirmed(exit 4) / 신버전은 사후 백업으로 되돌리고 기다린 뒤 성공.
#     (Codex: 사전 게이트 큐만으로는 구버전에서 첫 클릭이 나가 버려 사고가 재현되지 않음)
Reset-Mock -Title '페카고분심층2층3구역]' -ClickSeq @('user-active', 'user-active', 'user-active') -AfterClickTitle '페카고분심층2층2구역'
$result = Set-DgOptionStage -Game $null -Stage '2-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '09-08 사고 재현(생략 3연속): 성공(구버전은 not-confirmed)' $result.Ok $true
Assert-Case '09-08 사고 재현: 양보 대기 3회' $script:yieldCalls 3
Assert-Case '09-08 사고 재현: 클릭 호출 4회 중 실제 1회' "$($script:clickCount)/$($script:performedCount)" '4/1'
Assert-Case '09-08 사고 재현: 실제 클릭 로그 1회(시도 1/3 - 생략 회전은 예산 미소모)' (Get-LogCount '카드 클릭 - 글자 탐색 (시도 1/3)') 1

# 11b. 사전 게이트의 $try 미소모: 조작이 8회전 이어져도(for 상한 8) 성공해야 함 - 사전 `$try--` 를
#      지우면 시도 상한 소진으로 실패 (Codex: 4회전은 상한 안이라 행동으로 못 잡음)
Reset-Mock -Title '페카고분심층2층3구역]' -ActiveSeq @($true, $true, $true, $true, $true, $true, $true, $true) -AfterClickTitle '페카고분심층2층2구역'
$result = Set-DgOptionStage -Game $null -Stage '2-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '사전 양보 8회전: 성공(try 미소모)' $result.Ok $true
Assert-Case '사전 양보 8회전: 양보 8회 + 클릭 0→1' "$($script:yieldCalls)/$($script:clickCount)/$($script:performedCount)" '8/1/1'

# 11c. 사후 백업의 $try 미소모: 클릭이 8회 연속 user-active 생략 → 호출 9회·실제 1회·성공
Reset-Mock -Title '페카고분심층2층3구역]' -ClickSeq @('user-active', 'user-active', 'user-active', 'user-active', 'user-active', 'user-active', 'user-active', 'user-active') -AfterClickTitle '페카고분심층2층2구역'
$result = Set-DgOptionStage -Game $null -Stage '2-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '사후 생략 8회: 성공(try 미소모)' $result.Ok $true
Assert-Case '사후 생략 8회: 호출 9회·실제 1회·양보 8회' "$($script:clickCount)/$($script:performedCount)/$($script:yieldCalls)" '9/1/8'

# 12. 대기 중 사용자가 이미 목표 구역으로 바꿔 둠 → 재판독부터 다시 = 클릭 없이 성공 (옛 좌표 강행 금지)
Reset-Mock -Title '페카고분심층2층3구역]' -ActiveSeq @($true) -AfterYieldTitle '페카고분심층2층2구역'
$result = Set-DgOptionStage -Game $null -Stage '2-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '대기 중 목표 도달: 성공' $result.Ok $true
Assert-Case '대기 중 목표 도달: 클릭 없음' $script:clickCount 0
Assert-Case '대기 중 목표 도달: 양보 1회' $script:yieldCalls 1

# 13. 사후 경합: 사전 게이트는 통과했는데 클릭 직전에 조작 시작(user-active 생략) → 방금 올린
#     시도 회수 되돌림 + 대기 + 재판독 → 다음 회전 클릭 성공. '카드 클릭' 로그는 실제 1회만.
Reset-Mock -Title '페카고분심층2층3구역]' -ClickSeq @('user-active') -AfterClickTitle '페카고분심층2층2구역'
$result = Set-DgOptionStage -Game $null -Stage '2-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '사후 경합: 성공' $result.Ok $true
Assert-Case '사후 경합: 클릭 호출 2회 중 실제 1회' "$($script:clickCount)/$($script:performedCount)" '2/1'
Assert-Case '사후 경합: 양보 1회' $script:yieldCalls 1
Assert-Case '사후 경합: 되돌린 시도 회수로 재클릭(시도 1/3 - 2/3 아님)' (Get-LogCount '(시도 1/3)') 1
Assert-Case '사후 경합: 생략 클릭을 눌렀다고 적지 않음' (Get-LogCount '카드 클릭 - 글자 탐색') 1

# 13b. 사후 경합 + 대기 중 목표 도달: 재판독부터 다시라 재클릭 없이 성공 (호출 1·실제 0)
Reset-Mock -Title '페카고분심층2층3구역]' -ClickSeq @('user-active') -AfterYieldTitle '페카고분심층2층2구역'
$result = Set-DgOptionStage -Game $null -Stage '2-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '사후 경합+목표 도달: 성공' $result.Ok $true
Assert-Case '사후 경합+목표 도달: 호출 1회·실제 0회' "$($script:clickCount)/$($script:performedCount)" '1/0'

# 14. 커서 미확인은 기존대로 유한 소모: 3회 전부 cursor-not-ready → 대기 없이 not-confirmed
Reset-Mock -Title '페카고분심층2층3구역]' -ClickSeq @('cursor-not-ready', 'cursor-not-ready', 'cursor-not-ready')
$result = Set-DgOptionStage -Game $null -Stage '2-2' -ReadTitle $readTitle -LogTag '[커스텀]' -AssumeMismatchFirst
Assert-Case '커서 미확인 3회: 유한 종료(not-confirmed)' "$($result.Ok)/$($result.Reason)" 'False/not-confirmed'
Assert-Case '커서 미확인 3회: 양보 없음(조작이 아니라 커서 미확인)' $script:yieldCalls 0
Assert-Case '커서 미확인 3회: 건너뜀 로그 3회(시도 예산 소모)' (Get-LogCount '카드 클릭 건너뜀 (커서 미확인, 시도') 3
Assert-Case '커서 미확인 3회: 눌렀다는 로그 없음' (Get-LogCount '카드 클릭 - 글자 탐색') 0

# 15. 보조 판정 잠금 해제 (Codex 조건): 제목 불명 지속, 보조 판정이 '1-1'(같은 층 다른 구역)로
#     클릭 승격 → 그 순간 양보 → 재개 후 보조 판정을 **다시** 돌려 '1-2'(목표 일치)로 성공해야 함.
#     잠금($observedTried)을 안 풀면 보조 판정이 다시 안 돌아 남은 회수를 소진(not-confirmed).
#     제목은 양보 후에도 불명 유지(AfterYieldTitle 없음) - 보조 판독을 반드시 거치게 함.
Reset-Mock -Title '[피오듸층1구역' -AssistSeq @('1-1', '1-2') -ActiveSeq @($true)
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]'
Assert-Case '잠금 해제(사전 양보): 성공' $result.Ok $true
Assert-Case '잠금 해제(사전 양보): 보조 판정 2회·실제 클릭 0회' "$($script:assistCalls)/$($script:performedCount)" '2/0'
Reset-Mock -Title '[피오듸층1구역' -AssistSeq @('1-1', '1-2') -ClickSeq @('user-active')
$result = Set-DgOptionStage -Game $null -Stage '1-2' -ReadTitle $readTitle -LogTag '[커스텀]'
Assert-Case '잠금 해제(사후 경합): 성공' $result.Ok $true
Assert-Case '잠금 해제(사후 경합): 보조 판정 2회·호출 1회·실제 0회' "$($script:assistCalls)/$($script:clickCount)/$($script:performedCount)" '2/1/0'

# ---- 실측 문자열 진리표 (2026-08-11 23:55 오류 캡처 재현 판독문 그대로) ----
Assert-Case '실측: 넓은 s4 정상 판독은 매치' (Test-CustomTitleStageMatch -TitleText '로다2증1구역' -Stage '2-1') 'match'
Assert-Case '실측: 넓은 s3 역 깨짐은 불명(채택 탈락과 일관)' (Test-CustomTitleStageMatch -TitleText '로다2증1구°' -Stage '2-1') 'unclear'
Assert-Case '실측: 좁은 s3 구역 소실은 불명' (Test-CustomTitleStageMatch -TitleText '훈다0' -Stage '2-1') 'unclear'
Assert-Case '실측: 전환 전 제목은 목표와 mismatch(전환 필요 판정)' (Test-CustomTitleStageMatch -TitleText '로다2증2구역' -Stage '2-1') 'mismatch'
# 2026-09-08 09:07 실측 제목(꼬리 ']' 오독 포함) - 전환 전 2-3 은 목표 2-2 와 mismatch, 전환 후는 match
Assert-Case '실측 09-08: 꼬리 ] 오독 제목도 mismatch 판정' (Test-CustomTitleStageMatch -TitleText '페카고분심층2층3구역]' -Stage '2-2') 'mismatch'
Assert-Case '실측 09-08: 전환 후 제목 매치' (Test-CustomTitleStageMatch -TitleText '페카고분심층2층2구역' -Stage '2-2') 'match'

# ---- 소스 계약 검사 ----
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '보조 판정 지도 판독은 배율 3·4·6 (피오드 옵션1층은 4·6만으로 표 부족 - 07-26 실측)' `
  ($workerSource -match 'foreach \(\$mapScale in 3, 4, 6\)') $true
Assert-Case '첫 클릭 허용은 커스텀 시작 stay-select 호출 1곳뿐 (0-1 검증·오선택 복구는 미사용)' `
  ([regex]::Matches($workerSource, ' -AssumeMismatchFirst').Count) 1
# v2.1.7 양보 계약 배선: 사전 게이트(Focus 전) + 사후 경합 백업 둘 다 시도 회수 미소모 + 보조 판정 잠금 해제 + 재판독
$switchBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Set-DgOptionStage'))
Assert-Case '배선: 사전 양보 게이트(대기 → try 미소모 → 잠금 해제 → 재판독) 가 clicks++ 앞' `
  ([bool]($switchBody -match 'if \(Test-UserRecentlyActive\) \{\s+Wait-UserYieldEnd -Game \$Game -Context "구역 \$\{Stage\} 전환"\s+Move-CursorOutsideGame -Game \$Game[^\r\n]*\s+\$try--\s+\$observedTried = \$false\s+\$titleText = & \$ReadTitle\s+continue\s+\}\s+\$clicks\+\+')) 'True'
Assert-Case '배선: 사후 경합 백업(user-active → clicks 되돌림 → 대기 → try 미소모 → 잠금 해제 → 재판독)' `
  ([bool]($switchBody -match "elseif \(\`$script:lastClickSkipReason -eq 'user-active'\) \{(?:\s*#[^\r\n]*)*\s+\`$clicks--\s+Wait-UserYieldEnd -Game \`$Game -Context `"구역 \`$\{Stage\} 전환`"\s+Move-CursorOutsideGame -Game \`$Game[^\r\n]*\s+\`$try--\s+\`$observedTried = \`$false\s+\`$titleText = & \`$ReadTitle\s+continue")) 'True'   # v2.1.7: 재판독 직전 커서 대피 추가
Assert-Case '배선: 클릭 로그는 lastClickPerformed 참일 때만' `
  ([bool]($switchBody -match 'if \(\$script:lastClickPerformed\) \{\s+Write-RunLog "\$LogTag 구역 \$\{Stage\} 카드 클릭 - \$clickHow \(시도')) 'True'

if ($fails -gt 0) { Write-Output "FAIL 합계: $fails"; exit 1 }
Write-Output '전체 통과'
exit 0
