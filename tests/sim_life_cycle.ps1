# 생활(채집) 사이클 시뮬레이터 - test_life_gather.ps1 이 자식 프로세스로 실행합니다.
# (파일명이 test_ 로 시작하지 않아 run_all_tests 집계 대상이 아닙니다)
# 워커의 Invoke-LifeGatherCycle 본체를 AST 로 추출하고, 화면/입력 의존을 전부 스텁으로
# 바꾼 뒤 시나리오별 모의 시퀀스를 돌려 '종료 코드'와 '호출 궤적'을 검증 가능하게 합니다.
# 궤적은 [Console]::WriteLine 으로 남깁니다 (Write-Output 은 함수 반환값을 오염시킴 - PS 5.1).
param([string]$Scenario)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Invoke-LifeGatherCycle', 'Get-LifeRequiredLevel', 'Get-LifeNormalizedName',
      'Get-LifeRepairedTexts', 'Get-LifeQuestOwner', 'Get-LifeAllTargetNames', 'Test-LifeNameMatches', 'Test-LifeQuestFragments', 'Get-LifeProgressValue', 'Get-LifeQuestGoalValue', 'Get-LifeQuestGoalConsensus')) {
  Invoke-Expression $definition
}
# 소유 판정이 쓰는 실제 데이터 (이형 표 / 공통 치환 쌍) - 스텁이 아니라 본체 값을 그대로 씁니다
$simAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'mabinogi_run_once.ps1'), [ref]$null, [ref]$null)
foreach ($simVar in @('lifeTargetVariants', 'lifeNameRepairPairs', 'rgLifeQuestWide')) {
  $simAssign = $simAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $simVar))
    }, $true)
  if (-not $simAssign) { [Console]::WriteLine("FAIL 본체에서 `$$simVar 정의를 찾지 못했습니다"); exit 97 }
  Invoke-Expression $simAssign.Extent.Text
}

# ── 공통 스텁 (화면/입력/대기 제거) ──
function Write-RunLog { param([string]$Message) [Console]::WriteLine("LOG $Message") }
# 가상 시계: '한도 초과'를 검증하려면 시간이 흘러야 하는데(deadline 은 사이클 함수 내부의
# 지역 변수라 밖에서 앞당길 수 없음), 실제로 기다리면 느린 머신에서 초기 확인 단계가 먼저
# 만료되는 플래키가 생깁니다 (리뷰 지적). Get-Date 를 덮고 Start-Sleep 이 가상 시각만
# 앞으로 돌리면 대기 없이 결정적으로 재현됩니다 - 운영 코드는 그대로.
$script:useVirtualClock = $false
$script:virtualNow = [datetime]'2026-08-07T00:00:00'
function Get-Date {
  if ($script:useVirtualClock) { return $script:virtualNow }
  return [datetime]::Now
}
function Start-Sleep {
  param([int]$Seconds, [int]$Milliseconds)
  if (-not $script:useVirtualClock) { return }
  $advanceMs = ($Seconds * 1000) + $Milliseconds
  if ($advanceMs -le 0) { $advanceMs = 1000 }
  $script:virtualNow = $script:virtualNow.AddMilliseconds($advanceMs)
}
function Close-LifeOpenWindows { param($Game) return $false }
function Clear-EventOverlay { param($Game) return $false }
function Invoke-PurchasePopupSweep { param($Game) return $false }
function Close-WeeklyCoopResetPopup { param($Game, [string]$LogPrefix) return $false }
function Test-NoticeBoardPopup { param($Game) return $false }
function Close-LifeBlockingDialog { param($Game) return 'none' }
function Write-LifeDiagnostics { param($Game, [string]$Context) [Console]::WriteLine("DIAG $Context") }
function Test-SafeStopDuringCaptureFail { }
# 캡처 복구 탐침: N 번 탐침한 뒤 복구되도록 흉내 냅니다 (0 = 영영 복구 안 됨).
# 운영 코드에서 이 탐침이 빠지면 캡처 실패 플래그가 영영 안 풀려 한도까지 갇힙니다
# (2026-08-07 실사고) - 'capture-recover' 시나리오가 그 회귀를 잡습니다
$script:captureProbes = 0
$script:captureRecoverAfterProbes = 0
function Test-CaptureRecovered {
  param($Game)
  $script:captureProbes++
  [Console]::WriteLine("PROBE#$($script:captureProbes)")
  if ($script:captureRecoverAfterProbes -gt 0 -and $script:captureProbes -ge $script:captureRecoverAfterProbes) {
    $script:screenCaptureFailing = $false
  }
  return (-not $script:screenCaptureFailing)
}
function Focus-Game { param($Game) }
function Test-GameForeground { param($Game) return $true }   # 시뮬레이션은 항상 전면 가정
function Click-GamePoint { param($Game, [int]$ReferenceX, [int]$ReferenceY) }
# 수량 판독 스텁: 시나리오가 시퀀스를 주면 순서대로, 소진 후에는 마지막 값을 계속 돌려줍니다
$script:countSeq = @()
$script:countCalls = 0
function Get-LifeQuestCountText {
  param($Game)
  if (@($script:countSeq).Count -eq 0) { return '' }
  $script:countCalls++
  $countIndex = [Math]::Min($script:countCalls - 1, @($script:countSeq).Count - 1)
  return [string]$script:countSeq[$countIndex]
}
# 초기 퀘스트 대상 확인용 - 시뮬레이션에서는 설정 대상과 같은 퀘스트로 간주
$script:questTrackerText = ''      # 비우면 '설정 대상의 퀘스트'로 응답 (시나리오가 덮어씀)
function Get-GameRegionOcrText {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale, $Engine)
  if ($script:questTrackerText) { return $script:questTrackerText }
  return "채집 장소 탐색 $lifeTargetName 채집 0/10"
}
$rgQuestTracker = @(980, 212, 285, 55)
$ocrKoreanEngine = $null
$ptNoticeClose = @(1228, 67)
$script:screenCaptureFailing = $false

# 운영 기본 설정값 (시나리오가 덮어씀)
$lifeSkillMenuTable = @{
  daily = @{ Name = '일상 채집'; Cell = @(236, 205); Sig = @('둥지')
             Order = @('둥지', '거미줄', '물', '우물', '젖소', '사과 나무', '차나무', '거미줄 뭉치', '헤이즐넛', '얽힌 거미줄') }
}
$lifeContent = 'gather'
$lifeSkillId = 'daily'
$lifeTargetName = '사과나무'
$lifeGatherWait = 600
$lifeGatherHardCapSeconds = 3600      # 절대 상한 (진행이 있어도 이 시간을 넘으면 정지)

# 메뉴 사이클 스텁: 시나리오 시퀀스대로 성공/실패를 돌려주고 호출 궤적을 남깁니다
$script:menuResults = @()
$script:menuCalls = 0
$script:menuDetailText = ''
function Invoke-LifeMenuSequence {
  param($Game, $SkillEntry, [string]$TargetName, [datetime]$Deadline)
  $script:menuCalls++
  [Console]::WriteLine("MENU#$($script:menuCalls)")
  # 실제 메뉴 시퀀스는 '상세를 이 대상의 팝업으로 확정한 뒤에만' 요구 레벨을 남깁니다.
  # 여기서도 같은 계약으로 채워 실제 추출 함수(Get-LifeRequiredLevel)까지 태웁니다
  if ($script:menuDetailText) {
    $script:lifeLastDetail = @{
      Target = [string]$TargetName
      Level  = (Get-LifeRequiredLevel -DetailText $script:menuDetailText)
    }
  }
  $menuIndex = $script:menuCalls - 1
  if ($menuIndex -lt $script:menuResults.Count) { return [bool]$script:menuResults[$menuIndex] }
  return $false
}

# 퀘스트 상태 스텁: 시퀀스 소진 후에는 tail 값을 계속 반환합니다 (무한 루프 방지)
$script:stateSeq = @()
$script:stateTail = 'unknown'
$script:stateCalls = 0
# N 번째 판독 이후부터 캡처 실패로 전환 (0 = 사용 안 함) - '진행 중 화면이 안 그려지는' 재현용
$script:captureFailAfterStateCalls = 0
function Get-LifeQuestState {
  param($Game)
  $script:stateCalls++
  # -eq 로 '그 판독에서 한 번만' 장애를 주입합니다 (-ge 면 복구된 뒤 판독마다 다시 켜져
  # 일회성 장애 재현이 아니게 됨 - 리뷰 지적)
  if ($script:captureFailAfterStateCalls -gt 0 -and $script:stateCalls -eq $script:captureFailAfterStateCalls) {
    $script:screenCaptureFailing = $true
  }
  $stateIndex = $script:stateCalls - 1
  $state = if ($stateIndex -lt $script:stateSeq.Count) { [string]$script:stateSeq[$stateIndex] } else { [string]$script:stateTail }
  [Console]::WriteLine("STATE#$($script:stateCalls)=$state")
  return $state
}

switch ($Scenario) {
  'unsupported-skill' {
    # 1차 미지원 스킬(낚시) → 안내 후 조건부 정지 (exit 4)
    $lifeSkillId = 'fishing'
  }
  'process-content' {
    # 가공 콘텐츠 → 안내 후 조건부 정지 (exit 4)
    $lifeContent = 'process'
  }
  'menu-fail' {
    # 메뉴 사이클 3회 전부 실패 → 시작 확정 실패 (exit 4)
    $script:menuResults = @($false, $false, $false)
    $script:stateSeq = @('absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'happy' {
    # 정상: 초기 확인 3회 absent → 메뉴 성공 → 생성 확인 present 2회 → 소멸(absent 3연속) → exit 0
    # (초기 확인이 3회 판독으로 바뀜 - 2026-08-07 트래커 가림 오판 방지)
    $script:menuResults = @($true)
    $script:stateSeq = @('absent', 'absent', 'absent') + @('present', 'present') + @('absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'confirm-retry' {
    # 1차 메뉴는 성공했지만 퀘스트가 안 생김(확인 8회 absent) → 재시도 2차에서 생성 → exit 0
    $script:menuResults = @($true, $true)
    $script:stateSeq = @('absent', 'absent', 'absent') + @('absent') * 8 + @('present', 'present', 'absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'goal-count' {
    # 2026-08-08 실사고 재현: 마지막 개를 채우는 순간 트래커가 사라져 폴링이 '10/10' 을
    # 못 봅니다. 마지막 판독은 '9/10' 이지만 **완료 로그에는 목표 개수 10 이 찍혀야** 합니다.
    # 분모가 튀는 회차('0/1')도 섞어 '가장 많이 본 분모' 합의가 도는지 확인합니다.
    $script:menuResults = @($true)
    $script:countSeq = @('0/10', '0/1', '3/10', '6/10', '9/10')
    $script:stateSeq = @('absent', 'absent', 'absent') + @('present', 'present') +
      @('present', 'present', 'present') + @('absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'goal-unknown' {
    # 분모를 한 번도 못 읽으면(전부 깨짐) 목표를 단정하지 않고 '마지막 판독'임을 밝힙니다
    $script:menuResults = @($true)
    $script:countSeq = @('0/0', '2/1', '0/0')
    $script:stateSeq = @('absent', 'absent', 'absent') + @('present', 'present') +
      @('present', 'present', 'present') + @('absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'resume' {
    # 시작 시 이미 퀘스트 진행 중(초기 present) → 메뉴 생략하고 이어서 대기 → exit 0 (MENU 0회)
    $script:stateSeq = @('present', 'absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'resume-sibling' {
    # 형제 대상('우물')의 퀘스트가 진행 중인데 목표는 '물'. 부분 문자열 비교 시절에는 이걸
    # 자기 것으로 인수해 빈 사이클을 완료로 계상했습니다 (2026-08-07 감사).
    # 이제는 '다른 대상'으로 보고 끝나기를 기다렸다가 메뉴를 엽니다.
    $lifeTargetName = '물'
    $script:questTrackerText = '채집 장소 탐색 우물 채집 3/10'
    $script:menuResults = @($true)
    # 초기 present → (다른 대상 대기) absent 3연속 → 메뉴 → 생성 확인 present 2 → 소멸 3
    $script:stateSeq = @('present') + @('absent', 'absent', 'absent') + @('present', 'present') + @('absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'start-unknown' {
    # 초기 확인 20회가 전부 unknown(로딩/다른 화면 지속) → 입력하지 않고 조건부 정지
    $script:stateSeq = @('unknown')
    $script:stateTail = 'unknown'
  }
  'unknown-reset' {
    # absent 2연속 후 unknown 1회 = 연속 카운트 리셋 → absent 3연속을 다시 채워야 종료
    # (리셋이 없으면 STATE 5회 만에 종료 / 리셋이 있으면 7회 - 부모가 STATE 줄 수로 판별)
    $script:stateSeq = @('present', 'absent', 'absent', 'unknown', 'absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'menu-fail-level' {
    # 2026-08-07 실사고 재현: 곤충 채집 '일렁이는 빛 무리'(레벨 27 이상, 캐릭터 25).
    # 메뉴 시퀀스는 **성공**합니다 - 상세도 확인하고 '가까운 위치 찾기'까지 눌렀습니다.
    # 그런데 레벨이 모자라 게임이 퀘스트를 만들지 않아 생성 확인 8회가 전부 실패하고,
    # 그게 3회 반복돼 소진됐습니다 (메뉴 자체를 실패시키면 이 경로를 안 탐 - 리뷰 지적).
    $script:menuResults = @($true, $true, $true)
    $script:stateSeq = @('absent', 'absent', 'absent')
    $script:stateTail = 'absent'
    # 실제 메뉴 시퀀스가 남기는 판독문을 스텁이 대신 채웁니다 (사이클 함수가 시작 시
    # 초기화하므로 시나리오에서 직접 넣으면 지워집니다 - 반드시 메뉴 호출 시점에 채울 것)
    $script:menuDetailText = '일렁이는빛무리자|집물(곤충채집레벨27이실h1창백한산'
    $lifeSkillId = 'insect'
    $lifeSkillMenuTable = @{ insect = @{ Name = '곤충 채집'; Cell = @(1143, 205); Sig = @('빛무리') } }
    $lifeTargetName = '일렁이는 빛 무리'
  }
  'deadline' {
    # 진행이 없는 채로 한도 초과 (exit 4). 수량 판독이 계속 빈 값이라 진행이 인정되지 않습니다.
    # 한도를 0초로 두면 초기 확인 단계에서 이미 지나 메뉴 경로로 끝나 버려 '대기 루프의
    # 한도'를 전혀 검증하지 못했습니다 (2026-08-07 발견) - 초기 확인은 present 로 통과시키고
    # 가상 시계로 대기 루프 안에서 넘기게 합니다 (한도 1초 + 대기 1회 3초)
    $script:useVirtualClock = $true
    $lifeGatherWait = 1
    $script:stateSeq = @('present')
    $script:stateTail = 'present'
  }
  'progress-extends' {
    # **수량이 늘면 한도를 다시 잰다** (2026-08-08 설계 변경의 핵심).
    # 한도 10초 + 매 회차 3초 경과인데 수량이 계속 올라, 총 시간이 한도를 훨씬 넘겨도
    # 잘리지 않고 소멸(absent 3연속)로 정상 완료해야 합니다.
    # 진행 인정이 빠지면 4회차(12초)에서 exit 4 로 떨어집니다.
    $script:useVirtualClock = $true
    $lifeGatherWait = 10
    $script:countSeq = @('1/10', '2/10', '3/10', '4/10', '5/10', '6/10', '7/10', '8/10')
    $script:stateSeq = @('present') + (@('present') * 8) + @('absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  'progress-noise-not-extends' {
    # 판독 노이즈('6/10 → 0/10 → 6/10')는 진행이 아닙니다 - **본 적 있는 최댓값**만 기준.
    # 수량이 6 에서 오르내리기만 하면 한도가 되살아나지 않고 정지해야 합니다.
    $script:useVirtualClock = $true
    $lifeGatherWait = 10
    $script:countSeq = @('6/10', '0/10', '6/10', '0/10', '6/10', '0/10', '6/10', '0/10')
    $script:stateSeq = @('present')
    $script:stateTail = 'present'
  }
  'hard-cap' {
    # 절대 상한: 수량이 계속 올라도 1시간을 넘기면 정지 (무인 운용 백스톱).
    $script:useVirtualClock = $true
    $lifeGatherWait = 600
    $lifeGatherHardCapSeconds = 20
    $script:countSeq = @('1/10', '2/10', '3/10', '4/10', '5/10', '6/10', '7/10', '8/10', '9/10')
    $script:stateSeq = @('present')
    $script:stateTail = 'present'
  }
  'deadline-capture-fail' {
    # 한도 초과 시점에 화면 캡처가 실패 중이면 원인을 '채집이 느림'이 아니라 '화면 미표시'로
    # 안내해야 합니다 (2026-08-07 실사고: RDP 최소화 16분 → '채집 대기를 늘리라'는 오안내).
    # 실사고 그대로: 채집이 진행 중(present)이던 도중 화면이 멈춥니다 - 초기 확인은 통과하고
    # 대기 루프의 두 번째 판독에서 캡처 실패로 전환(그 판독은 unknown). 복구는 안 됩니다.
    $script:useVirtualClock = $true
    $lifeGatherWait = 1
    $script:captureFailAfterStateCalls = 2
    $script:stateSeq = @('present', 'unknown')
    $script:stateTail = 'unknown'
  }
  'capture-recover' {
    # 캡처가 실패했다가 화면이 돌아오면 사이클을 이어가야 합니다.
    # 2026-08-07 실사고: 대기 지점들이 '캡처 실패 중이면 판독을 건너뛰고 continue' 하는 바람에
    # 아무도 캡처를 시도하지 않아 화면이 돌아와도 감지하지 못하고 한도까지 갔습니다.
    # 복구 탐침이 빠지면 이 시나리오는 exit 4(한도 초과)로 떨어집니다.
    $script:useVirtualClock = $true
    $lifeGatherWait = 600
$lifeGatherHardCapSeconds = 3600      # 절대 상한 (진행이 있어도 이 시간을 넘으면 정지)
    $script:captureFailAfterStateCalls = 2       # 대기 루프 첫 판독 직후 화면 정지
    $script:captureRecoverAfterProbes = 2        # 탐침 2회 만에 복구
    $script:stateSeq = @('present', 'unknown', 'absent', 'absent', 'absent')
    $script:stateTail = 'absent'
  }
  default {
    [Console]::WriteLine("FAIL 알 수 없는 시나리오: $Scenario")
    exit 98
  }
}

Invoke-LifeGatherCycle -Game $null
# 사이클 함수는 반드시 exit 로 끝나야 합니다 (여기 도달 = 계약 위반)
[Console]::WriteLine('RETURNED-WITHOUT-EXIT')
exit 99
