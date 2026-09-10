# 생활(채집) 사이클 한도와 사용자 조작 양보의 상호작용 진리표 (2026-09-09 Codex 사후 리뷰 P1)
#
# 배경(실사고 아님 - 리뷰가 잡은 결함): 09-09 00:24 에 '양보 즉시 사이클 접기 → 8초 주기 무한
# 재시작(진행 0)'을 고치면서 Test-LifeYieldBeforeInput 에 '화면이 그대로면 그 자리에서 이어서
# 진행'($false) 경로를 넣었습니다. 그런데 사이클 한도 연장은 '접은 회전'($script:lifeMenuYielded)
# 분기에만 있어서, 이어서 진행한 회전의 양보는 마감에 전혀 반영되지 않았습니다.
# → 사용자가 화면을 바꾸지 않고 PC 를 쓰기만 해도 한도를 먹고 조건부 정지(exit 4).
# 던전·어비스·사냥터·냥 상인은 전부 while 만료 조건에서 Get-YieldAdjustedDeadline 을 부르는데
# 생활만 raw 마감을 쓰고 있었습니다 - Get-LifeCycleDeadline 으로 그 계약에 통일했습니다.
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-YieldAdjustedDeadline', 'Get-LifeCycleDeadline')) {
  Invoke-Expression $definition
}
$workerText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 진리표: 마감 = min(양보를 반영한 사이클 한도, 지정 종료 시각) ──
# 값은 소스 함수를 그대로 실행해 얻습니다 (사본 재구현 금지 - 진리표 계약)
$base = [datetime]'2026-09-09T10:00:00'
$script:lifeCycleDeadline = $base
$script:lifeSeenYieldMs   = [double]0
$script:userYieldTotalMs  = [double]0
$script:lifeUntilDeadline = $null

Assert-Case '양보 0 → 마감 불변' (Get-LifeCycleDeadline) $base

# 양보 300초: '이어서 진행' 경로든 '접은 회전'이든 누적 변수는 같습니다 (Wait-UserYieldEnd /
# Move-CursorOutsideGame 이 $script:userYieldTotalMs 에 더함) - 마감이 그만큼 밀려야 합니다
$script:userYieldTotalMs = [double]300000
Assert-Case '양보 300초 → 마감 +300초 (이 단언이 P1 의 본체)' (Get-LifeCycleDeadline) $base.AddSeconds(300)

# 차분 계약: 같은 양보를 다시 조회해도 두 번 더해지지 않습니다 (만료 판정마다 불리므로 필수)
Assert-Case '재조회 → 같은 양보가 중복 가산되지 않음' (Get-LifeCycleDeadline) $base.AddSeconds(300)
Assert-Case '재조회 3회째도 동일' (Get-LifeCycleDeadline) $base.AddSeconds(300)

# 추가 양보 120초 (누적값이 늘어난 만큼만 추가 반영)
$script:userYieldTotalMs = [double]420000
Assert-Case '추가 양보 120초 → 누적 +420초' (Get-LifeCycleDeadline) $base.AddSeconds(420)

# 지정 종료 시각은 **사용자 약속이라 연장하지 않습니다** - 더 이르면 그 시각이 마감
$script:lifeUntilDeadline = $base.AddSeconds(60)
Assert-Case '지정 시각이 더 이르면 지정 시각이 마감' (Get-LifeCycleDeadline) $base.AddSeconds(60)
$script:userYieldTotalMs = [double]900000
Assert-Case '양보가 아무리 길어도 지정 시각은 밀리지 않음' (Get-LifeCycleDeadline) $base.AddSeconds(60)

# 지정 시각이 더 늦으면 다시 사이클 한도가 마감 (위에서 누적 900초까지 반영된 값)
$script:lifeUntilDeadline = $base.AddSeconds(5000)
Assert-Case '지정 시각이 더 늦으면 사이클 한도가 마감' (Get-LifeCycleDeadline) $base.AddSeconds(900)

# 지정 시각 미설정($null)이면 사이클 한도만
$script:lifeUntilDeadline = $null
Assert-Case '지정 시각 없음 → 사이클 한도' (Get-LifeCycleDeadline) $base.AddSeconds(900)

# ── 배선 가드: 생활의 만료 판정이 전부 이 한 곳을 거치는가 ──
# (raw 스냅숏 비교가 하나라도 남으면 그 지점에서 P1 이 그대로 재발합니다)
Assert-Case '배선: 스냅숏 변수 $lifeMenuDeadline 대입이 사라짐' `
  ([bool]($workerText -match '\$lifeMenuDeadline\s*=')) 'False'
Assert-Case '배선: raw $cycleDeadline 비교가 남아 있지 않음' `
  ([bool]($workerText -match '(-gt|-le|-lt|-ge) \$cycleDeadline')) 'False'
Assert-Case '배선: Invoke-LifeMenuSequence 가 Deadline 스냅숏을 받지 않음' `
  ([bool]($workerText -match 'Invoke-LifeMenuSequence[^\r\n]*-Deadline')) 'False'
Assert-Case '배선: 시퀀스 param 에 $Deadline 이 없음' `
  ([bool]($workerText -match 'function Invoke-LifeMenuSequence \{[\s\S]{0,900}?param\([^\r\n]*\$Deadline')) 'False'
# 만료 판정 개수: 시퀀스 내부 16 + 호출부 6 = 22 (복제된 판정은 개수로 세야 갈라지지 않습니다).
# 앞에 공백이 오는 것만 셉니다 - 주석의 '한도(Get-LifeCycleDeadline)' 같은 언급을 빼기 위함
Assert-Case '배선: Get-LifeCycleDeadline 실제 호출 22곳' `
  ([regex]::Matches($workerText, '(?<= )\(Get-LifeCycleDeadline\)').Count) 22
# 접은 회전 분기가 담당하는 것은 두 가지뿐입니다: ①재진입 전 대기 ②재시도 미계상.
# 마감 연장은 Get-LifeCycleDeadline 이 만료 판정마다 상시 처리하므로 여기서 따로 하지
# 않습니다 - 예전에는 여기서만 연장해서 '이어서 진행' 경로의 양보가 통째로 누락됐습니다.
# ①은 2026-09-09 Codex 구현 리뷰 P2: 다음 회전 서두의 잔존 창 X 닫기가 게이트보다 먼저
# 와서, 대기 없이 재진입하면 그 X 클릭이 조작 중에 취소돼 재시도만 소모됐습니다.
Assert-Case '배선: 접은 회전 분기 = 재진입 전 대기 + 재시도 미계상 (마감 연장은 헬퍼가 상시)' `
  (($workerText -match '\$script:lifeMenuYielded\) \{[\s\S]{0,900}?Wait-UserYieldEnd[\s\S]{0,900}?\$menuTry--\r?\n\s*continue') -and
   -not ($workerText -match '\$script:lifeMenuYielded\) \{[\s\S]{0,1200}?Get-YieldAdjustedDeadline')) 'True'

if ($fails -gt 0) { "실패 $fails 건"; exit 1 }
'전부 통과'
exit 0
