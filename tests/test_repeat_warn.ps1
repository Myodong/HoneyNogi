# 실패해도 진행하는 '확인 경고'(게임 전면화·커서 이동)의 반복 억제 판정을 검사합니다.
# 클릭마다 호출되는 확인이라, 연속 실패 중에 같은 경고가 로그를 도배하던 문제
# (2026-07-22 어비스 실주행 실측)를 막기 위한 규칙입니다.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
Invoke-Expression ((Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-RepeatWarnAction')) -join "`n")

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ($Actual -eq $Expected) { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

# --- 진리표: (이미 경고했는가) x (이번에 실패했는가) ---
Check-Equal '첫 실패 → 경고' (Get-RepeatWarnAction -WasWarned $false -Failed $true) 'warn'
Check-Equal '연속 실패 → 기록 없음' (Get-RepeatWarnAction -WasWarned $true -Failed $true) 'none'
Check-Equal '경고 후 성공 → 회복 안내' (Get-RepeatWarnAction -WasWarned $true -Failed $false) 'recover'
Check-Equal '정상 유지 → 기록 없음' (Get-RepeatWarnAction -WasWarned $false -Failed $false) 'none'

# --- 시퀀스 검증: 실패가 이어져도 경고는 1회, 회복도 1회만 나와야 합니다 ---
# 실제 호출부와 같은 상태 전이를 모사합니다 (warn 시 활성화, recover 시 해제).
function Invoke-WarnSequence {
  param([bool[]]$FailSequence)
  $warned = $false
  $emitted = @()
  foreach ($failed in $FailSequence) {
    $action = Get-RepeatWarnAction -WasWarned $warned -Failed $failed
    if ($action -eq 'warn') { $warned = $true; $emitted += 'W' }
    elseif ($action -eq 'recover') { $warned = $false; $emitted += 'R' }
  }
  return ($emitted -join '')
}

Check-Equal '실패 5연속 → 경고 1회만' (Invoke-WarnSequence -FailSequence @($true, $true, $true, $true, $true)) 'W'
Check-Equal '실패 3회 후 성공 → W 다음 R' (Invoke-WarnSequence -FailSequence @($true, $true, $true, $false)) 'WR'
Check-Equal '실패-성공 반복 → 전이마다 1회' (Invoke-WarnSequence -FailSequence @($true, $false, $true, $false)) 'WRWR'
Check-Equal '전부 성공 → 기록 없음' (Invoke-WarnSequence -FailSequence @($false, $false, $false)) ''
Check-Equal '성공 후 실패 → 경고 1회' (Invoke-WarnSequence -FailSequence @($false, $true, $true)) 'W'
# 회복 안내 뒤 다시 실패하면 새 연속 구간이므로 경고가 다시 나와야 합니다
Check-Equal '회복 후 재실패 → 경고 재발행' (Invoke-WarnSequence -FailSequence @($true, $false, $true, $true, $true)) 'WRW'

# --- 호출부 계약: 두 확인(전면화·커서)이 서로 다른 상태 변수를 쓰는지 소스로 확인 ---
$workerText = Get-Content -LiteralPath $workerPath -Raw
foreach ($stateVar in @('focusWarnActive', 'focusWarnSuppressed')) {
  Check-Equal "상태 변수 선언: $stateVar" ($workerText -match ('\$script:{0}\s*=' -f $stateVar)) $true
}
# 억제 중에는 생략 횟수를 세고, 회복 안내에서 그 횟수를 알려야 진단 정보가 남습니다
Check-Equal '전면화: 회복 안내에 생략 횟수 포함' ($workerText -match '전면화 확인이 정상으로 돌아왔습니다[^"]*focusWarnSuppressed') $true

# ★ 커서 확인은 2026-08-10 부터 **이 규칙을 쓰지 않습니다.**
#   첫 실패를 곧바로 [경고]로 남기는 것이 문제였습니다 - 사용자가 안전 중지 버튼을 누르려고
#   마우스를 옮긴 것만으로 실패가 나고, 그 경고를 보고 놀라 자동화를 즉시 중지했습니다.
#   그래서 커서만 연속 횟수 기반 2단계([안내] → 3회 연속 [경고])로 분리했습니다.
#   진리표와 배선은 tests\test_cursor_click_warn.ps1 이 담당합니다.
#   여기서는 **두 정책이 다시 섞이지 않는지**만 지킵니다 (섞이면 한쪽이 다른 쪽 억제를 풀어
#   버리고, 첫 실패 경고가 되살아나 이번 실사고가 그대로 재발합니다).
Check-Equal '커서: 전용 연속 카운터를 쓴다' ($workerText -match '\$script:cursorFailureStreak\s*=') $true
Check-Equal '커서: 옛 전면화식 억제 상태를 되살리지 않는다' `
  ($workerText -match '\$script:cursorWarn(Active|Suppressed)') $false
$clickBodyText = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Click-ScreenPoint'))
Check-Equal '커서: Click-ScreenPoint 가 이 규칙을 쓰지 않는다' `
  ($clickBodyText -match 'Get-RepeatWarnAction') $false

exit $fails
