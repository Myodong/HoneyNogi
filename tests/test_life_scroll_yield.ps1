# 채집 목록 스크롤의 사용자 조작 양보 계약 (2026-09-09 실기 실측 대응)
#
# ★ 실사고: 2026-09-09 20:46 생활 채집 실기(나무 베기 / 갑옷 나무 / 한도 60초).
#   사용자가 마우스를 계속 쓰는 동안 Invoke-LifeListScroll 이 **기다리지 않고 건너뛰기만** 했고,
#   호출부는 그 회전의 예산을 그대로 소모했습니다.
#     20:46:21~26  [생활] 목록 스크롤: 사용자 마우스 조작 감지로 건너뜀   ← 11회 연속(스텝당 ~0.5초)
#     20:46:26     [오류] 채집 대상 '갑옷 나무' 을 목록에서 찾지 못했습니다
#     20:46:27     [완료] 채집 대상 미발견 - 조건부 정지
#   진단 궤적도 스텝4~11 판독이 완전히 동일했습니다(목록이 한 칸도 안 움직임).
#   기다리지 않으면 $script:userYieldTotalMs 도 안 늘어 마감 연장조차 안 걸립니다.
# 계약(Codex 설계 합의 B안): **기다린다 → 이 호출에서는 드래그하지 않는다 → 호출부가 예산을
#   면제하고 목록을 다시 읽는다.** (A안=대기 후 그대로 드래그는 기각 - 이 함수는 실제 마우스
#   버튼을 누르고 커서를 옮기므로, 대기 중 창이 닫혔으면 드래그가 게임 월드로 들어갑니다)
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Invoke-LifeListScroll')) {
  Invoke-Expression $definition
}
$workerText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 경계 스텁 ──
# 드래그 직전 관문(Wait-GameRestoredIfMinimized)의 호출 여부로 '드래그 경로에 진입했는가'를 셉니다.
# 전면화는 $false 를 돌려줘 P/Invoke 까지 가지 않고 반환하게 합니다 (단위 시험에서 실제 입력 금지).
$script:userActive = $false
$script:waitCalls = 0
$script:untilCalls = 0
$script:dragPathCalls = 0
function Write-RunLog { param([string]$Message) }
function Test-UserRecentlyActive { param([int]$IdleMs = 2500) return $script:userActive }
function Wait-UserYieldEnd { param($Game, [string]$Context = '자동화') $script:waitCalls++ }
function Test-LifeUntilReached { $script:untilCalls++ }
function Wait-GameRestoredIfMinimized { param($Game) $script:dragPathCalls++ }
function Test-GameForeground { param($Game) return $false }   # 드래그 전 반환 (실제 입력 방지)
function Focus-Game { param($Game) }

# ── ① 조작 중: 기다리고, 표시하고, 드래그 경로에 진입하지 않는다 ──
$script:userActive = $true
$script:waitCalls = 0; $script:untilCalls = 0; $script:dragPathCalls = 0
$script:lifeScrollYielded = $false
$scrollResult = Invoke-LifeListScroll -Game $null -Steps -1
Assert-Case '조작 중: 반환은 $false (드래그 미수행)' $scrollResult $false
Assert-Case '조작 중: 조작이 끝날 때까지 기다린다 (건너뛰기 금지 - 실사고 본체)' $script:waitCalls 1
Assert-Case '조작 중: 양보 표시를 세운다 (호출부의 예산 면제 근거)' $script:lifeScrollYielded $true
Assert-Case '조작 중: 드래그 경로에 진입하지 않는다 (대기 뒤 재판독은 호출부 몫)' $script:dragPathCalls 0
Assert-Case '조작 중: 양보 복귀 후 지정 종료 시각을 확인한다' $script:untilCalls 1

# ── ② 조작 없음: 표시는 거짓, 대기 없음, 드래그 경로로 진입 ──
$script:userActive = $false
$script:waitCalls = 0; $script:untilCalls = 0; $script:dragPathCalls = 0
$scrollResult = Invoke-LifeListScroll -Game $null -Steps -1
Assert-Case '조작 없음: 기다리지 않는다' $script:waitCalls 0
Assert-Case '조작 없음: 양보 표시 없음' $script:lifeScrollYielded $false
Assert-Case '조작 없음: 드래그 경로로 진입' $script:dragPathCalls 1

# ── ③ 표시 초기화는 **조기 반환보다 앞**이어야 한다 (Codex 조건) ──
# 직전 호출이 양보로 표시를 세운 뒤, Steps 0 같은 조기 반환 호출이 오면 표시가 남아 있으면 안 됩니다
# (남으면 호출부가 엉뚱한 회전의 예산을 면제합니다)
$script:userActive = $true
$script:lifeScrollYielded = $false
[void](Invoke-LifeListScroll -Game $null -Steps -1)
Assert-Case '초기화: 양보 호출 직후 표시는 참' $script:lifeScrollYielded $true
[void](Invoke-LifeListScroll -Game $null -Steps 0)
Assert-Case '초기화: Steps 0 조기 반환에서도 표시가 거짓으로 초기화' $script:lifeScrollYielded $false

# ── 배선 가드: 호출부 2곳이 예산을 면제하는가 ──
# (함수만 고치고 호출부를 안 고치면 실사고가 그대로 재발합니다 - 예산 소모는 호출부에 있습니다)
Assert-Case '배선: 탐색 루프가 양보 회전의 탐색 스텝을 되돌린다' `
  ([bool]($workerText -match '\$lastScrollSent = \[bool\]\(Invoke-LifeListScroll[^\r\n]*\r?\n(?:\s*#[^\r\n]*\r?\n|\s*if \(\$script:lifeScrollYielded\) \{\r?\n)+(?:\s*#[^\r\n]*\r?\n)*\s*\$scrollStep--')) 'True'
Assert-Case '배선: 탐색 루프가 양보 회전을 진단 궤적에서도 뺀다' `
  ([bool]($workerText -match '\$scrollStep--[\s\S]{0,300}?\$scanTrail = @\(\$scanTrail\[0\.\.\(\$scanTrail\.Count - 2\)\]\)')) 'True'
Assert-Case '배선: 정렬 루프가 양보 회전을 전송 실패 3회 제한에서 면제' `
  ([bool]($workerText -match 'if \(\$script:lifeScrollYielded\) \{[\s\S]{0,900}?Get-LifeTargetRows[\s\S]{0,400}?continue\r?\n\s*\}\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*\$topScrollFails\+\+')) 'True'
Assert-Case '배선: 정렬 루프가 양보 후 **재판독으로** 다음 드래그를 정한다 (최상단이면 종료)' `
  ([bool]($workerText -match 'if \(\$script:lifeScrollYielded\) \{[\s\S]{0,900}?Test-LifeListAtTop -Rows \$topRows -Order @\(\$SkillEntry\.Order\)\) \{ break \}')) 'True'
Assert-Case '배선: 옛 건너뛰기 문구가 남아 있지 않다 (기다리지 않던 계약의 흔적)' `
  ([bool]($workerText -match '사용자 마우스 조작 감지로 건너뜀')) 'False'

if ($fails -gt 0) { "실패 $fails 건"; exit 1 }
'전부 통과'
exit 0
