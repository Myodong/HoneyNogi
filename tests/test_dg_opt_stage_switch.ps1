# 옵션 화면 구역 전환 루프(Set-DgOptionStage) 시뮬레이션 진리표
# 본체: mabinogi_run_once.ps1 Set-DgOptionStage (실함수를 AST로 추출해 모의 의존성으로 실행)
# 배경: 2026-07-26 실사고 - 피오드 옵션 화면 제목 '[피오듸층1구역' 지속 불명 상태에서
#   ① 내부 보조 판정이 배율 4·6만 읽어 표 부족(null) ② null인데도 1회 잠금에 걸려 재시도 불가
#   → 클릭 한 번 없이 8회 대기만 하다 정지. 수정: 배율 3 추가 + null은 잠금 제외 +
#   시작 분기 확정 시 첫 클릭 허용(-AssumeMismatchFirst, 같은 층 목표 카드 클릭은 멱등).
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
function Click-ScreenPoint {
  param($X, $Y)
  $script:clickCount++
  if ($script:titleAfterClick) { $script:currentTitle = $script:titleAfterClick }
}
function Click-GamePoint {
  param($Game, $ReferenceX, $ReferenceY)
  $script:clickCount++
  if ($script:titleAfterClick) { $script:currentTitle = $script:titleAfterClick }
}
function Write-RunLog { param([string]$Message) $script:runLogs += $Message }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) }   # 대기 생략 (판정 로직만 검증)
$readTitle = { $script:currentTitle }

function Reset-Mock {
  param(
    [string]$Title,
    [object[]]$AssistSeq = @(),
    [string]$AfterClickTitle = '',
    $CardPoint = @{ Screen = @{ X = 918; Y = 238 } }
  )
  $script:currentTitle = $Title
  $script:mockAssistQueue = New-Object System.Collections.Queue
  foreach ($assist in $AssistSeq) { $script:mockAssistQueue.Enqueue($assist) }
  $script:assistCalls = 0
  $script:clickCount = 0
  $script:titleAfterClick = $AfterClickTitle
  $script:mockCardPoint = $CardPoint
  $script:runLogs = @()
}

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

# ---- 실측 문자열 진리표 (2026-08-11 23:55 오류 캡처 재현 판독문 그대로) ----
Assert-Case '실측: 넓은 s4 정상 판독은 매치' (Test-CustomTitleStageMatch -TitleText '로다2증1구역' -Stage '2-1') 'match'
Assert-Case '실측: 넓은 s3 역 깨짐은 불명(채택 탈락과 일관)' (Test-CustomTitleStageMatch -TitleText '로다2증1구°' -Stage '2-1') 'unclear'
Assert-Case '실측: 좁은 s3 구역 소실은 불명' (Test-CustomTitleStageMatch -TitleText '훈다0' -Stage '2-1') 'unclear'
Assert-Case '실측: 전환 전 제목은 목표와 mismatch(전환 필요 판정)' (Test-CustomTitleStageMatch -TitleText '로다2증2구역' -Stage '2-1') 'mismatch'

# ---- 소스 계약 검사 ----
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '보조 판정 지도 판독은 배율 3·4·6 (피오드 옵션1층은 4·6만으로 표 부족 - 07-26 실측)' `
  ($workerSource -match 'foreach \(\$mapScale in 3, 4, 6\)') $true
Assert-Case '첫 클릭 허용은 커스텀 시작 stay-select 호출 1곳뿐 (0-1 검증·오선택 복구는 미사용)' `
  ([regex]::Matches($workerSource, ' -AssumeMismatchFirst').Count) 1

if ($fails -gt 0) { Write-Output "FAIL 합계: $fails"; exit 1 }
Write-Output '전체 통과'
exit 0
