# 커스텀 반복 - 종료 코드 x 완료 마커 매트릭스 + 오류 재시도 카운터 진리표 (2026-07-20)
# 본체의 순수 판정 함수는 AST로 직접 불러오고, 타이머의 상태 변화만 시뮬레이터로 검증합니다.
$fails = 0

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Get-CustomNextProgress', 'Test-CustomLapComplete', 'Get-CustomErrorAction')) {
  Invoke-Expression $definition
}

# ---------- 타이머 종료 코드 상태 시뮬레이션 (안전 중지/시간 조건 제외) ----------
# 상태 해시테이블을 받아 한 번의 워커 종료를 처리한 뒤의 상태/행동을 반환합니다.
# 반환 필드: Outcome(다음시작/완주정지/같은항목재실행/조건정지/다음항목재시작/같은항목재시작/오류정지),
#            Counted(회차 계상), Streak(오류 카운터), Progress(전진 결과, 완주 리셋 시 $null),
#            Prev(''=비움/완료항목=갱신/유지), Restart(다음 회차 RESTART=1 여부)
function Invoke-ExitCodeSim {
  param([int]$ExitCode, [bool]$Marker, [int]$Streak, $Progress,
        [int]$ItemCount, [string]$ListRepeat, [int]$ListRepeatCount)
  $counted = $false; $newStreak = $Streak; $newProgress = $Progress
  $prev = '유지'; $restart = $false; $outcome = ''
  if ($ExitCode -eq 0) {
    # 판 완료: 카운터 리셋 + PREV 갱신 + 전진, 완주면 진행 삭제 후 정지
    $counted = $true; $newStreak = 0; $restart = $false; $prev = '완료항목'
    $newProgress = Get-CustomNextProgress -Progress $Progress -ItemCount $ItemCount
    if (Test-CustomLapComplete -ListRepeat $ListRepeat -ListRepeatCount $ListRepeatCount -Lap ([int]$newProgress.lap)) {
      $newProgress = $null   # 본체: Reset-CustomProgress
      $outcome = '완주정지'
    } else { $outcome = '다음시작' }
  } elseif ($ExitCode -eq 10) {
    # 준비 실행: 미계상 + 전진 없음 + PREV 비움(선택 화면 절차 유도) - 마커 유무 무관
    $prev = ''; $restart = $false
    $outcome = '같은항목재실행'
  } elseif ($ExitCode -eq 4) {
    # 조건부 정지: 마커 있으면 계상+전진 '후' 정지 (완주 검사는 다음 시작 게이트가 흡수)
    if ($Marker) {
      $counted = $true; $prev = '완료항목'
      $newProgress = Get-CustomNextProgress -Progress $Progress -ItemCount $ItemCount
    }
    $outcome = '조건정지'
  } elseif ($ExitCode -eq 1) {
    $errorAction = Get-CustomErrorAction -MarkerExists $Marker -ErrorStreak $Streak
    if ($errorAction -eq 'recover') {
      # 마커 있음: 계상/전진하지 않고 같은 완료 항목의 마무리만 복구합니다.
      # 복구 워커 코드 0에서 기존 정상 분기가 딱 한 번 전진합니다.
      $newStreak = $Streak + 1; $prev = '완료항목'; $restart = $true
      $outcome = '마무리복구'
    } elseif ($errorAction -eq 'retry') {
      $newStreak = $Streak + 1; $prev = ''; $restart = $true
      $outcome = '같은항목재시작'
    } else {
      $outcome = '오류정지'
    }
  }
  return @{ Outcome = $outcome; Counted = $counted; Streak = $newStreak
            Progress = $newProgress; Prev = $prev; Restart = $restart }
}

function Describe-SimResult {
  param($R)
  $progText = if ($null -eq $R.Progress) { 'null' } else { "$($R.Progress.lap)/$($R.Progress.index)" }
  return ('{0} 계상={1} 카운터={2} 진행={3} PREV={4} RESTART={5}' -f `
    $R.Outcome, $R.Counted, $R.Streak, $progText, $R.Prev, $R.Restart)
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$prog10 = [pscustomobject]@{lap=1; index=0}   # 1바퀴째 1번 항목 실행 중 (4항목 기준)
$prog13 = [pscustomobject]@{lap=1; index=3}   # 1바퀴째 마지막(4번) 항목 실행 중

# ---------- 진리표 ② 종료 코드 x 마커 매트릭스 ----------
# 코드 0: 마커 유무 무관 전진 (마커는 0에서 참조하지 않음 - 정상 완료 자체가 근거)
$r = Invoke-ExitCodeSim 0 $false 0 $prog10 4 'infinite' 1
Assert-Case '코드0/마커없음: 계상+전진+다음시작' (Describe-SimResult $r) '다음시작 계상=True 카운터=0 진행=1/1 PREV=완료항목 RESTART=False'
$r = Invoke-ExitCodeSim 0 $true 0 $prog10 4 'infinite' 1
Assert-Case '코드0/마커있음: 동일 (마커 미참조)' (Describe-SimResult $r) '다음시작 계상=True 카운터=0 진행=1/1 PREV=완료항목 RESTART=False'
$r = Invoke-ExitCodeSim 0 $false 0 $prog13 4 'count' 1
Assert-Case '코드0: 마지막 항목 완료 → 완주정지+진행삭제' (Describe-SimResult $r) '완주정지 계상=True 카운터=0 진행=null PREV=완료항목 RESTART=False'
$r = Invoke-ExitCodeSim 0 $false 0 $prog13 4 'count' 2
Assert-Case '코드0: wrap 하되 N 미달 → 계속' (Describe-SimResult $r) '다음시작 계상=True 카운터=0 진행=2/0 PREV=완료항목 RESTART=False'
$r = Invoke-ExitCodeSim 0 $false 0 $prog13 4 'infinite' 1
Assert-Case '코드0: 무한 모드 wrap → 계속' (Describe-SimResult $r) '다음시작 계상=True 카운터=0 진행=2/0 PREV=완료항목 RESTART=False'

# 코드 10: 미계상 + 진행 무변경 + PREV 비움 (마커 유무 무관)
$r = Invoke-ExitCodeSim 10 $false 0 $prog10 4 'count' 2
Assert-Case '코드10/마커없음: 미계상 같은항목재실행' (Describe-SimResult $r) '같은항목재실행 계상=False 카운터=0 진행=1/0 PREV= RESTART=False'
$r = Invoke-ExitCodeSim 10 $true 1 $prog10 4 'count' 2
Assert-Case '코드10/마커있음: 동일(마커 미참조, 카운터 유지)' (Describe-SimResult $r) '같은항목재실행 계상=False 카운터=1 진행=1/0 PREV= RESTART=False'

# 코드 4: 마커 있으면 계상+전진 후 정지 / 없으면 무변경 정지
$r = Invoke-ExitCodeSim 4 $true 0 $prog10 4 'infinite' 1
Assert-Case '코드4/마커있음: 계상+전진 후 조건정지' (Describe-SimResult $r) '조건정지 계상=True 카운터=0 진행=1/1 PREV=완료항목 RESTART=False'
$r = Invoke-ExitCodeSim 4 $false 0 $prog10 4 'infinite' 1
Assert-Case '코드4/마커없음: 무변경 조건정지' (Describe-SimResult $r) '조건정지 계상=False 카운터=0 진행=1/0 PREV=유지 RESTART=False'
$r = Invoke-ExitCodeSim 4 $true 0 $prog13 4 'count' 1
Assert-Case '코드4/마커: 전진으로 lap>N 이어도 진행 보존(다음 시작 게이트가 흡수)' (Describe-SimResult $r) '조건정지 계상=True 카운터=0 진행=2/0 PREV=완료항목 RESTART=False'

# 코드 1: 마커 있으면 진행 유지+같은 항목 마무리 복구, 없으면 retry/stop
$r = Invoke-ExitCodeSim 1 $true 0 $prog10 4 'infinite' 1
Assert-Case '코드1/마커있음: 미계상+진행유지+같은항목 마무리복구' (Describe-SimResult $r) '마무리복구 계상=False 카운터=1 진행=1/0 PREV=완료항목 RESTART=True'
$r = Invoke-ExitCodeSim 1 $true 1 $prog10 4 'infinite' 1
Assert-Case '코드1/마커있음: 두 번째 오류까지 같은 항목 복구' (Describe-SimResult $r) '마무리복구 계상=False 카운터=2 진행=1/0 PREV=완료항목 RESTART=True'
$r = Invoke-ExitCodeSim 1 $true 0 $prog13 4 'count' 1
Assert-Case '코드1/마커있음: 마지막 항목도 복구 성공 전에는 완주 처리 안 함' (Describe-SimResult $r) '마무리복구 계상=False 카운터=1 진행=1/3 PREV=완료항목 RESTART=True'
$r = Invoke-ExitCodeSim 1 $true 2 $prog10 4 'infinite' 1
Assert-Case '코드1/마커있음/카운터2: 세 번째 마무리 오류는 정지' (Describe-SimResult $r) '오류정지 계상=False 카운터=2 진행=1/0 PREV=유지 RESTART=False'
$r = Invoke-ExitCodeSim 1 $false 0 $prog10 4 'infinite' 1
Assert-Case '코드1/마커없음/카운터0: 재시도1 (같은 항목)' (Describe-SimResult $r) '같은항목재시작 계상=False 카운터=1 진행=1/0 PREV= RESTART=True'
$r = Invoke-ExitCodeSim 1 $false 1 $prog10 4 'infinite' 1
Assert-Case '코드1/마커없음/카운터1: 재시도2 (상한)' (Describe-SimResult $r) '같은항목재시작 계상=False 카운터=2 진행=1/0 PREV= RESTART=True'
$r = Invoke-ExitCodeSim 1 $false 2 $prog10 4 'infinite' 1
Assert-Case '코드1/마커없음/카운터2: 3회째 실패 → 정지' (Describe-SimResult $r) '오류정지 계상=False 카운터=2 진행=1/0 PREV=유지 RESTART=False'

# ---------- 진리표 ③ 오류 재시도 카운터 (2회 상한 / 성공 시 리셋) - 연속 시퀀스 ----------
function Invoke-Sequence {
  param([object[]]$Steps)   # 각 스텝 = @(코드, 마커)
  $streak = 0; $prog = $null; $trace = @()
  foreach ($s in $Steps) {
    $r = Invoke-ExitCodeSim ([int]$s[0]) ([bool]$s[1]) $streak $prog 4 'infinite' 1
    $streak = [int]$r.Streak
    $prog = $r.Progress
    $trace += $r.Outcome
    if ($r.Outcome -match '정지') { break }
  }
  return ($trace -join '>')
}
Assert-Case '시퀀스: 오류3연속 = 재시도2회 후 정지' (Invoke-Sequence @(@(1,$false), @(1,$false), @(1,$false))) '같은항목재시작>같은항목재시작>오류정지'
Assert-Case '시퀀스: 오류2회 후 성공 = 카운터 리셋 (재차 오류 3회 허용)' `
  (Invoke-Sequence @(@(1,$false), @(1,$false), @(0,$false), @(1,$false), @(1,$false), @(1,$false))) `
  '같은항목재시작>같은항목재시작>다음시작>같은항목재시작>같은항목재시작>오류정지'
Assert-Case '시퀀스: 마커 오류 → 마무리 복구 성공 = 진행 한 번만 전진' `
  (Invoke-Sequence @(@(1,$true), @(0,$false))) `
  '마무리복구>다음시작'
Assert-Case '시퀀스: 일반 오류 뒤 마커 오류 → 복구 오류 한도 도달 시 정지' `
  (Invoke-Sequence @(@(1,$false), @(1,$true), @(1,$true))) `
  '같은항목재시작>마무리복구>오류정지'
Assert-Case '시퀀스: 준비 실행(10)은 카운터 유지' (Invoke-Sequence @(@(1,$false), @(10,$false), @(1,$false), @(1,$false))) '같은항목재시작>같은항목재실행>같은항목재시작>오류정지'

# Get-CustomErrorAction 단독 진리표 (경계 재확인)
Assert-Case '오류판정: 마커+카운터0 → recover' (Get-CustomErrorAction $true 0) 'recover'
Assert-Case '오류판정: 마커+카운터1 → recover' (Get-CustomErrorAction $true 1) 'recover'
Assert-Case '오류판정: 마커+카운터2 → stop' (Get-CustomErrorAction $true 2) 'stop'
Assert-Case '오류판정: 카운터0 → retry' (Get-CustomErrorAction $false 0) 'retry'
Assert-Case '오류판정: 카운터1 → retry' (Get-CustomErrorAction $false 1) 'retry'
Assert-Case '오류판정: 카운터2 → stop (3회째)' (Get-CustomErrorAction $false 2) 'stop'
Assert-Case '오류판정: 카운터3 → stop' (Get-CustomErrorAction $false 3) 'stop'

exit $fails
