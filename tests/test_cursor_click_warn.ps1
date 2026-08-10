# 커서 확인 실패의 **심각도 단계** 진리표 (2026-08-10 실기 실사고 - 사용자 반응).
#
# 실사고: 사용자가 **안전 중지 버튼을 누르려고 마우스를 옮긴 것**만으로 Click-ScreenPoint 의
# 커서 확인이 실패했고, 그때 뜬 [경고]를 보고 놀라 자동화를 즉시 중지했습니다.
#   17:14:45 안전 중지 예약: 던전에서 나와 밖이 확인되면 멈춥니다
#   17:14:46 [경고] 커서를 목표 위치(2760,101)로 두 번 이동했지만 ... 건너뜁니다
#   17:14:49 [중단] 중지: 즉시 중지
# 클릭을 건너뛴 것은 **의도한 안전 동작**(2026-08-02 오클릭 실사고 대응)인데 로그가
# 고장처럼 읽혔습니다.
#
# 그렇다고 첫 실패를 숨기면 안 됩니다 - 이번처럼 사용자가 곧바로 중지하면 진단 흔적이
# 통째로 사라집니다. 그래서 **기록은 남기되 첫 줄은 [안내]**, 연속 3회부터 [경고]입니다.
#
# ★ 같은 로그에서 **두 번째 결함**이 드러났습니다: 커서 확인 실패로 클릭을 건너뛰었는데
#   컷신 호출부가 무조건 '장면 넘기기 클릭'이라고 기록해, 경고 바로 다음 줄에 성공 로그가
#   찍혔습니다. 팝업 닫기·카드 토글·생활 정리는 5~8차에 이 구분을 넣었는데 컷신 2곳만
#   빠져 있었습니다. 로그를 읽는 사람이 '재시도해서 성공했다'로 오독하게 만드는 형태입니다.
$ErrorActionPreference = 'Stop'
$fails = 0
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
$workerRaw = [IO.File]::ReadAllText($workerPath)
# 판정 함수는 **소스에서 그대로** 불러옵니다 (사본을 다시 쓰면 소스가 바뀌어도 안 움직임)
Invoke-Expression ((Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-CursorClickWarnAction')) -join "`n")

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── ① 임계값은 소스에서 캡처 (테스트에 숫자를 다시 박지 않습니다) ────────────
$warnBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-CursorClickWarnAction'))
$threshold = [int]([regex]::Match($warnBody, '\$WarnThreshold = (\d+)').Groups[1].Value)
Assert-Case '임계값을 소스에서 읽었다(0 이면 캡처 실패)' ($threshold -gt 0) 'True'

# 실패/성공 시퀀스를 흘려 **로그로 나가는 것만** 모읍니다 (본체 switch 와 같은 분기)
function Get-LogSequence {
  param([bool[]]$Failures)
  $streak = 0
  $out = @()
  foreach ($failed in $Failures) {
    $v = Get-CursorClickWarnAction -PreviousStreak $streak -Failed $failed
    $before = $streak
    $streak = [int]$v.Streak
    switch ([string]$v.Action) {
      'notice'  { $out += '안내' }
      'warn'    { $out += ('경고(' + $streak + ')') }
      'recover' { $out += ('회복(' + $before + ')') }
      default   { }
    }
  }
  if ($out.Count -eq 0) { return '(로그 없음)' }
  return ($out -join ' → ')
}
function Rep { param([bool]$V, [int]$N) return @(1..$N | ForEach-Object { $V }) }

# ── ② 진리표 ────────────────────────────────────────────────────────────────
Assert-Case '성공만: 로그 없음' (Get-LogSequence -Failures (Rep $false 5)) '(로그 없음)'
Assert-Case '실패 1회: 안내만 (놀라게 하지 않음)' (Get-LogSequence -Failures (Rep $true 1)) '안내'
Assert-Case '실패 2회: 여전히 안내 1줄' (Get-LogSequence -Failures (Rep $true 2)) '안내'
Assert-Case '실패 3회: 안내 뒤 경고로 승격' (Get-LogSequence -Failures (Rep $true 3)) '안내 → 경고(3)'
Assert-Case '실패 6회: 경고는 한 번만(이후 억제)' (Get-LogSequence -Failures (Rep $true 6)) '안내 → 경고(3)'
# ★ 이번 실사고 그 자체: 마우스를 잠깐 쓴 뒤 바로 정상화 → **경고도 회복 안내도 없어야** 합니다
Assert-Case '실사고 재현: 1회 실패 후 성공 → 안내 한 줄뿐' `
  (Get-LogSequence -Failures @($true, $false)) '안내'
Assert-Case '2회 실패 후 성공 → 회복 안내 없음(조용히 초기화)' `
  (Get-LogSequence -Failures @($true, $true, $false)) '안내'
Assert-Case '3회 실패 후 성공 → 회복 안내(연속 3회)' `
  (Get-LogSequence -Failures @($true, $true, $true, $false)) '안내 → 경고(3) → 회복(3)'
Assert-Case '5회 실패 후 성공 → 회복이 실제 연속 횟수를 보고' `
  (Get-LogSequence -Failures ((Rep $true 5) + @($false))) '안내 → 경고(3) → 회복(5)'
Assert-Case '회복 뒤 다시 실패 → 새 구간이 안내부터 시작' `
  (Get-LogSequence -Failures @($true, $true, $true, $false, $true)) '안내 → 경고(3) → 회복(3) → 안내'
Assert-Case '성공이 섞이면 연속이 끊겨 경고까지 안 간다' `
  (Get-LogSequence -Failures @($true, $true, $false, $true, $true, $false)) '안내 → 안내'
# 성공에서 시작해도 streak 가 0 으로 유지되는지 (초기 상태 오염 방지)
Assert-Case '성공 → 실패 1회: 안내' (Get-LogSequence -Failures @($false, $true)) '안내'

# ── ③ 임계값을 바꾸면 승격 지점이 따라 움직인다 (상수를 못 박는 검사) ────────
# 소스의 기본값을 그대로 쓰는지 확인합니다 - 본체가 4로 바뀌면 위 '3회 → 경고'가 깨지고,
# 여기서는 그 이유가 임계값 변경임이 드러납니다.
$atThreshold = Get-CursorClickWarnAction -PreviousStreak ($threshold - 1) -Failed $true
Assert-Case "임계값($threshold) 도달 시 경고" ([string]$atThreshold.Action) 'warn'
$beforeThreshold = Get-CursorClickWarnAction -PreviousStreak ($threshold - 2) -Failed $true
Assert-Case '임계값 직전은 경고가 아니다' ([bool]([string]$beforeThreshold.Action -eq 'warn')) 'False'
Assert-Case '임계값 미만에서 회복하면 안내 없음' `
  ([string](Get-CursorClickWarnAction -PreviousStreak ($threshold - 1) -Failed $false).Action) 'none'
Assert-Case '임계값 이상에서 회복하면 안내' `
  ([string](Get-CursorClickWarnAction -PreviousStreak $threshold -Failed $false).Action) 'recover'
Assert-Case '성공은 언제나 streak 를 0 으로' `
  ([int](Get-CursorClickWarnAction -PreviousStreak 9 -Failed $false).Streak) 0

# ── ④ 배선: 본체가 이 판정을 실제로 쓰는가 ──────────────────────────────────
$clickBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Click-ScreenPoint'))
$clickCode = (($clickBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: Click-ScreenPoint 가 전용 판정을 쓴다' `
  ([bool]($clickCode -match 'Get-CursorClickWarnAction -PreviousStreak \$script:cursorFailureStreak -Failed \(-not \$cursorReady\)')) 'True'
# 전면화 경고와 상태를 섞으면 한쪽이 다른 쪽 억제를 풀어 버립니다
Assert-Case '배선: 전면화용 억제 상태를 쓰지 않는다' `
  ([bool]($clickCode -match 'focusWarn')) 'False'
Assert-Case '배선: 옛 첫-1회 경고 규칙으로 되돌아가지 않는다' `
  ([bool]($clickCode -match 'Get-RepeatWarnAction')) 'False'
# 첫 실패가 다시 [경고]로 올라가면 이번 실사고가 그대로 재발합니다
Assert-Case '문구: 첫 실패는 [안내]' `
  ([bool]($clickCode -match "'notice' \{\s*\r?\n\s*Write-RunLog \""\[안내\]")) 'True'
Assert-Case '문구: 연속 실패는 [경고]' `
  ([bool]($clickCode -match "'warn' \{\s*\r?\n\s*Write-RunLog \""\[경고\]")) 'True'
# 경고는 '이번 실패까지 포함한' 횟수를, 회복은 '초기화 전' 횟수를 써야 합니다 (뒤바뀌면
# '3회 연속'이 2로 나가거나 회복 문구가 0회가 됨)
Assert-Case '문구: 경고가 갱신된 streak 를 쓴다' `
  ([bool]($clickCode -match '\[경고\][^"]*\$\{cursorStreakNow\}회 연속')) 'True'
Assert-Case '문구: 회복이 초기화 전 streak 를 쓴다' `
  ([bool]($clickCode -match '정상으로 돌아왔습니다 \(연속 \$\{cursorStreakBefore\}회')) 'True'
# 안전 게이트 자체는 그대로여야 합니다 - 커서 미확인이면 클릭을 쏘지 않습니다
Assert-Case '안전: 커서 미확인이면 mouse_event 전에 반환' `
  ([bool]($clickCode -match '(?s)if \(-not \$cursorReady\) \{ return \}.*mouse_event')) 'True'
Assert-Case '안전: 성공 표시는 mouse_event 뒤에만' `
  ([bool]($clickCode -match 'mouse_event\(0x0004[\s\S]{0,120}\$script:lastClickPerformed = \$true')) 'True'
Assert-Case '배선: streak 초기 상태가 선언돼 있다' `
  ([bool]($workerRaw -match '(?m)^\$script:cursorFailureStreak = 0\s*$')) 'True'

# ── ⑤ 컷신 호출부의 정직성 (같은 로그가 드러낸 두 번째 결함) ────────────────
# 커서 확인 실패로 클릭을 건너뛰었는데 '클릭'이라고 쓰면, 경고 바로 다음 줄에 성공 로그가
# 찍혀 읽는 사람이 '재시도해서 성공했다'로 오독합니다 (2026-08-10 실기에서 실제 발생).
Assert-Case '컷신: 실제 클릭일 때만 성공 로그 (2곳)' `
  ([regex]::Matches($workerRaw,
    'Click-ScreenPoint -X \$skipScene[^\r\n]*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*if \(\$script:lastClickPerformed\) \{').Count) 2
Assert-Case '컷신: 건너뜀도 사유를 남긴다 (2곳)' `
  ([regex]::Matches($workerRaw, '컷신 - 커서 확인 실패로 장면 넘기기 클릭을 건너뜀').Count) 2
# 무조건 기록으로 되돌아가면(클릭 바로 다음 줄에 성공 로그) 여기서 걸립니다
Assert-Case '컷신: 무조건 성공 기록으로 되돌아가지 않는다' `
  ([bool]($workerRaw -match
    'Click-ScreenPoint -X \$skipScene[^\r\n]*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*Write-RunLog[^\r\n]*장면 넘기기 클릭')) 'False'

exit $fails
