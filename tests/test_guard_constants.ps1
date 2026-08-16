# 안전장치의 **상수 값**과 **가드 방향**을 고정합니다 (2026-08-09 5차 변이 검증 대응).
#
# 왜 필요한가: 변이 검증에서 49종 중 12종이 살아남았고, 전부 두 부류였습니다.
#   ① 숫자 접두 매칭 - `-le 3` → `-le 3000`, 유예 `60` → `600`, 대기 `1200` → `12000`,
#      간격 `3` → `30`, 프레임 대기 `120` → `1200`. 기존 단언이 '그 숫자로 시작하는가'만
#      봐서 뒤에 0을 붙여도 전부 통과했습니다. 게다가 진리표가 상수를 **테스트 안에 다시
#      박은 사본**이라 소스가 바뀌어도 움직이지 않았습니다.
#   ② 가드 조건식 방향 - `$hitWindow -eq [IntPtr]::Zero` 를 `-ne` 로 **한 글자** 바꾸면
#      커서 대피가 전 경로에서 영구 무동작이 되는데 49종이 조용히 통과했습니다.
#
# 처방: **소스에서 숫자를 캡처해 값으로 단언**하고, 가드는 연산자까지 포함해 고정합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$workerSource = [IO.File]::ReadAllText($workerPath)
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Get-Captured {
  # 소스에서 숫자 하나를 **캡처해 값으로** 돌려줍니다 ($null = 패턴 자체가 사라짐).
  # 접두 매칭을 막으려 캡처 그룹 뒤에 (?!\d) 를 붙여 뒤에 숫자가 더 붙으면 잡히지 않게 합니다.
  param([string]$Body, [string]$Pattern)
  $m = [regex]::Match($Body, $Pattern)
  if (-not $m.Success) { return $null }
  return [int]$m.Groups[1].Value
}

$park = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Move-CursorOutsideGame'))
$parkPoint = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-CursorParkPoint'))
$wait = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Wait-GameRestoredIfMinimized'))
$safeStop = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-SafeStopDuringCaptureFail'))
$settle = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Wait-DgTributeCostSettles'))
$click = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Click-ScreenPoint'))
$entry = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-AfterEntryKeys'))

# ── ① 상수 값 고정 (접두 매칭 불가) ─────────────────────────────────────────
# 2026-08-16 개정: v2.1.1 사용자 양보 루프(500ms 폴링)가 함수 앞부분에 끼어 '첫 번째
# 슬립' 앵커가 무효화됨 - 프레임 대기는 SetCursorPos 실패 throw 뒤의 슬립으로 앵커 이동
Assert-Case '상수: 대피 후 프레임 대기 120ms' `
  (Get-Captured $park 'SetCursorPos 실패[\s\S]{0,600}?Start-Sleep -Milliseconds (\d+)(?!\d)') 120
Assert-Case '상수: 사용자 양보 폴링 500ms' `
  (Get-Captured $park 'while \(\(Test-CursorOverGame[\s\S]{0,700}?Start-Sleep -Milliseconds (\d+)(?!\d)') 500
Assert-Case '상수: 대피 후 위치 비교 허용 오차 3px' `
  (Get-Captured $park 'Abs\(\$after\.X - \[int\]\$cursor\.X\) -le (\d+)(?!\d)') 3
Assert-Case '상수: 대피 지점 여백 기본 12px' `
  (Get-Captured $parkPoint '\[int\]\$Margin = (\d+)(?!\d)') 12
Assert-Case '상수: 클릭 전 커서 확인 허용 오차 3px' `
  (Get-Captured $click 'Abs\(\$cursorNow\.X - \$X\) -le (\d+)(?!\d)') 3
Assert-Case '상수: 클릭 커서 확인 시도 2회' `
  (Get-Captured $click 'cursorTry -le (\d+)(?!\d)') 2
Assert-Case '상수: 최소화 복원 예산 = max(25, 유휴+10)' `
  ("{0}/{1}" -f (Get-Captured $wait 'Max\((\d+)(?!\d)'), (Get-Captured $wait 'refocusIdleSeconds \+ (\d+)(?!\d)')) '25/10'
Assert-Case '상수: 복원 시도 간격 3초' `
  (Get-Captured $wait 'lastRestoreTry\)\.TotalSeconds -ge (\d+)(?!\d)') 3
Assert-Case '상수: 창 핸들 소실 유예 60초' `
  (Get-Captured $safeStop 'gameWindowMissingSince\)\.TotalSeconds -ge (\d+)(?!\d)') 60
Assert-Case '상수: 안전 중지 지속 요구 120초' `
  (Get-Captured $safeStop 'captureFailingSince\)\.TotalSeconds -lt (\d+)(?!\d)') 120
Assert-Case '상수: 소모량 안정화 기본 상한 16초' `
  (Get-Captured $settle '\[int\]\$TimeoutSeconds = (\d+)(?!\d)') 16
Assert-Case '상수: 팝업 연쇄 재확인 대기 1200ms' `
  (Get-Captured $entry 'Start-Sleep -Milliseconds (\d+)(?!\d)') 1200
Assert-Case '상수: 입장 팝업 루프 상한 4회전' `
  (Get-Captured $entry 'popupTry -le (\d+)(?!\d)') 4
# ★ 10차: OCR 무한 대기를 막는 상한만 이 목록에서 빠져 있어, 3000초로 늘려도 통과했습니다.
#   이 값이 커지면 '무인 운용이 밤새 조용히 멈춤'이 그대로 돌아옵니다.
$awaitBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Await-WinRt'))
Assert-Case '상수: WinRT 대기 상한 30초' `
  (Get-Captured $awaitBody '\[int\]\$TimeoutSeconds = (\d+)(?!\d)') 30
Assert-Case '가드: 상한 초과는 예외로 마친다(무한 대기 금지)' `
  ([bool]($awaitBody -match 'if \(-not \$completed\) \{[\s\S]{0,200}throw ')) 'True'
# 실패 사유 벗기기는 **Wait 를 감싼 catch 안**에 있어야 합니다. Wait 뒤에 IsFaulted 를 보는
# 형태는 Wait 가 먼저 던지므로 도달하지 못하는 죽은 코드입니다 (10차 실측으로 확인).
Assert-Case '가드: 사유 벗기기가 Wait 의 catch 안' `
  ([bool]($awaitBody -match '(?s)try \{\s*\r?\n\s*\$completed = \$task\.Wait\([\s\S]{0,600}?\} catch \{[\s\S]{0,600}?while \(\$baseEx\.InnerException\)')) 'True'
# 주석에는 '왜 IsFaulted 를 쓰면 안 되는가'가 적혀 있으므로 **코드 사본**으로 봅니다
$awaitCodeOnly = (($awaitBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '가드: 죽은 IsFaulted 검사를 되살리지 않는다' `
  ([bool]($awaitCodeOnly -match '\$task\.IsFaulted')) 'False'

# 값들 사이의 **관계**도 고정합니다 (하나만 바뀌어도 계약이 깨지는 곳)
$budgetFloor = Get-Captured $wait 'Max\((\d+)(?!\d)'
$idleAdd = Get-Captured $wait 'refocusIdleSeconds \+ (\d+)(?!\d)'
Assert-Case '관계: 복원 예산이 기본 유휴 15초를 넘는다' `
  ([bool](([Math]::Max($budgetFloor, 15 + $idleAdd)) -gt 15)) 'True'
$chainWait = Get-Captured $entry 'Start-Sleep -Milliseconds (\d+)(?!\d)'
Assert-Case '관계: 1초(클릭 후) + 재확인 대기 > 실측 최대 연쇄 간격 1.75초' `
  ([bool](((1000 + $chainWait) / 1000.0) -gt 1.75)) 'True'

# ── ② 가드 조건식 방향 고정 ─────────────────────────────────────────────────
# 한 글자만 뒤집혀도 기능이 통째로 죽는 곳들입니다. 연산자까지 포함해 못 박습니다.
Assert-Case '가드: WindowFromPoint 널이면 대피 안 함 (-eq)' `
  ([bool]($park -match 'if \(\$hitWindow -eq \[IntPtr\]::Zero\) \{ return \}')) 'True'
Assert-Case '가드: 루트 창이 게임과 **다르면** 대피 안 함 (-ne)' `
  ([bool]($park -match 'GetAncestor\(\$hitWindow, 2\) -ne \$Game\.MainWindowHandle\) \{ return \}')) 'True'
Assert-Case '가드: 최소화가 **아니면** 즉시 반환 (-not IsIconic)' `
  ([bool]($wait -match 'if \(-not \[HoneyNogiInput\]::IsIconic\(\$Game\.MainWindowHandle\)\) \{ return \}')) 'True'
# ★ 7차 점검: 예전 이 단언은 바로 위 '즉시 반환' 패턴에서 뒤쪽 ` return }` 만 뺀
#   **진부분집합**이라 위가 통과하면 무조건 통과했습니다. 실제로 while 루프 안의 복원 감지
#   4줄을 통째로 지우고 변이 검증을 돌렸더니 52종이 전부 통과했습니다. 그 상태로 배포되면
#   창이 곧 돌아와도 예산(25초)을 끝까지 태우고 거짓 경고를 남기며, Click-GamePoint 는
#   호출부가 80여 곳이라 클릭 1회마다 25초가 붙습니다.
#   → 루프 안 형태(복원 로그 + return)로 앵커하고, 검사 지점 개수까지 고정합니다.
$waitCodeOnly = (($wait -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '가드: 복원되면 루프 안에서 로그를 남기고 탈출' `
  ([bool]($waitCodeOnly -match "IsIconic\(\`$Game\.MainWindowHandle\)\) \{\s*\r?\n\s*Write-RunLog '\[안내\] 최소화된 게임 창을 복원해 진행합니다\.'\s*\r?\n\s*return")) 'True'
Assert-Case '가드: IsIconic 검사는 진입 1 + 루프 1 = 정확히 2곳' `
  ([regex]::Matches($waitCodeOnly, 'IsIconic\(\$Game\.MainWindowHandle\)').Count) 2
Assert-Case '가드: 게임 사망 검사가 안전중지 검사보다 **앞**' `
  ([bool]($safeStop -match '(?s)HasExited.*safeStopFlagPath')) 'True'
Assert-Case '가드: 프로세스 참조 없으면 검사 자체를 건너뜀' `
  ([bool]($safeStop -match 'if \(\$script:gameProcess\) \{')) 'True'
Assert-Case '가드: 연쇄 재확인은 같은 검색어(닫기)로' `
  ([regex]::Matches($entry, "-SearchText '닫기'").Count) 2
Assert-Case '가드: 실제 클릭일 때만 계상 (-not 아님)' `
  ([bool]($entry -match 'if \(\$script:lastClickPerformed\) \{ \$entryPopupClicks\+\+ \}')) 'True'

# ── ③ 대피 게이트의 **의도**를 문서로 남기는 진리표 ─────────────────────────
# ※ 이 네 케이스는 아래에서 테스트가 스스로 만든 함수를 검사합니다 = **소스를 읽지 않습니다.**
#   즉 회귀를 잡는 것은 위 ②의 배선 단언(-eq / -ne / 실패 기록)이고, 여기는 '어떤 입력에서
#   무동작이어야 하는가'를 사람이 읽을 수 있게 남기는 용도입니다. 이 구분을 적어 두지 않으면
#   '진리표가 있으니 안전하다'는 착각을 줍니다 (2026-08-10 9차 점검 지적 반영).
function Test-ParkGate {
  param([bool]$CursorPosOk, [bool]$HitWindowNull, [bool]$RootIsGame)
  if (-not $CursorPosOk) { return '무동작' }
  if ($HitWindowNull) { return '무동작' }
  if (-not $RootIsGame) { return '무동작' }
  return '대피'
}
Assert-Case '게이트: 커서 밑이 게임 → 대피' (Test-ParkGate $true $false $true) '대피'
Assert-Case '게이트: 커서 밑이 남의 창 → 무동작' (Test-ParkGate $true $false $false) '무동작'
Assert-Case '게이트: 커서 밑에 창 없음 → 무동작' (Test-ParkGate $true $true $false) '무동작'
Assert-Case '게이트: 커서 위치 못 읽음 → 무동작' (Test-ParkGate $false $false $true) '무동작'

exit $fails
