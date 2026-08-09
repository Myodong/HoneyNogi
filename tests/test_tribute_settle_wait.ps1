# 카드 클릭 후 '상태 재판독 실패' 경로의 소모량 안정화 대기 진리표 (2026-08-09 리뷰).
#
# 배경: 게임은 카드를 끈 뒤에도 입장 버튼의 소모량 표시를 **실측 13초 이상** 남겨 둡니다.
# 예전에는 2.5초 한 번만 보고 판단해서, 정상 전환도 '불일치'로 몰려 커스텀이 헛정지할 수
# 있었습니다. 반대로 무한정 기다리면 무인 운용이 멈추므로 상한이 필요합니다.
# 또 하나: 화면이 안 그려지는 동안(캡처 실패) 흘린 시간을 '기다렸다'로 세면, 복구되자마자
# 마감이 되어 같은 헛정지가 납니다 - 그 구간은 시간을 동결해야 합니다.
#
# 실제 함수는 2.5초씩 자므로, 시계와 Start-Sleep 을 가상으로 바꿔 즉시·결정적으로 돌립니다.
$ErrorActionPreference = 'Stop'
$fails = 0
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
Invoke-Expression ((Get-SourceFunctionDefinitions -Path $workerPath -Names @('Wait-DgTributeCostSettles')) -join "`n")

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 가상 시계 / 가상 대기 ────────────────────────────────────────────────────
$script:virtualNow = [DateTime]'2026-08-09T12:00:00'
function Get-Date { return $script:virtualNow }
function Start-Sleep {
  param([int]$Seconds = 0, [int]$Milliseconds = 0)
  $script:virtualNow = $script:virtualNow.AddMilliseconds(($Seconds * 1000) + $Milliseconds)
}
# 클릭은 절대 없어야 합니다 (이중 토글 금지 - 절대 규칙 4). 불리면 즉시 드러나게 셉니다.
$script:clickCount = 0
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) $script:clickCount++ }
function Click-ScreenPoint { param($X, $Y) $script:clickCount++ }
function Focus-Game { param($Game) $script:clickCount++ }
$script:safeStopChecks = 0
function Test-SafeStopDuringCaptureFail { $script:safeStopChecks++ }

# 판독 스텁: 경과 시간(가상)에 따라 값을 돌려줍니다
$script:readLog = @()
$script:startedAt = $null
function Get-DgTributeCost {
  param($Game, [int[]]$ValidCosts)
  $elapsed = ($script:virtualNow - $script:startedAt).TotalSeconds
  $script:readLog += [Math]::Round($elapsed, 1)
  return (& $script:costScript $elapsed)
}
function Invoke-SettleCase {
  param([scriptblock]$CostScript, [int]$Expected = 10, [int]$TimeoutSeconds = 16)
  $script:costScript = $CostScript
  $script:startedAt = $script:virtualNow
  $script:readLog = @()
  $script:clickCount = 0
  $script:safeStopChecks = 0
  return (Wait-DgTributeCostSettles -Game $null -ValidCosts @(10, 20) -ExpectedCost $Expected -TimeoutSeconds $TimeoutSeconds)
}

# ── ① 실측 13초 잔상: 2.5초 1회로는 놓치지만 16초 대기는 잡는다 ──────────────
$script:screenCaptureFailing = $false
$result = Invoke-SettleCase -CostScript { param($e) if ($e -ge 13) { 10 } else { 20 } }
Assert-Case '잔상13초: 표시가 따라오면 일치로 확정' $result.Matched $true
Assert-Case '잔상13초: 최종 판독값' $result.Value 10
Assert-Case '잔상13초: 클릭 0회 (무클릭 재판독)' $script:clickCount 0
Assert-Case '잔상13초: 13초 이전에 포기하지 않음' `
  ([bool]($script:readLog[$script:readLog.Count - 1] -ge 13)) 'True'

# ── ② 끝까지 안 맞으면 상한 안에서 종료 (무인 운용이 멈추지 않게) ────────────
$result = Invoke-SettleCase -CostScript { param($e) 20 }
Assert-Case '불일치: 상한 도달 후 불일치 반환' $result.Matched $false
Assert-Case '불일치: 마지막 판독값 보존' $result.Value 20
Assert-Case '불일치: 클릭 0회' $script:clickCount 0
Assert-Case '불일치: 대기가 상한 부근에서 끝남 (판독 7회 이하)' `
  ([bool]($script:readLog.Count -le 8)) 'True'

# ── ③ 판독 실패($null)만 이어져도 클릭 없이 종료 ─────────────────────────────
$result = Invoke-SettleCase -CostScript { param($e) $null }
Assert-Case '판독실패: 불일치 반환' $result.Matched $false
Assert-Case '판독실패: 값 null' ($null -eq $result.Value) 'True'
Assert-Case '판독실패: 클릭 0회' $script:clickCount 0

# ── ④ 캡처 실패 구간은 시간 동결 (복구 후부터 다시 센다) ─────────────────────
# 화면이 20초 동안 안 그려지고, 복구 후 5초 지나서야 표시가 따라오는 상황.
# 동결이 없으면 20초 시점에 이미 상한(16초)을 넘겨 '불일치'로 헛정지합니다.
$script:screenCaptureFailing = $true
$result = Invoke-SettleCase -CostScript {
  param($e)
  if ($e -ge 20) { $script:screenCaptureFailing = $false }
  if ($e -ge 25) { return 10 }
  return $null
}
Assert-Case '캡처실패: 복구 후 표시를 잡아 일치 확정' $result.Matched $true
Assert-Case '캡처실패: 최종 판독값' $result.Value 10
Assert-Case '캡처실패: 동결 중 안전 중지를 확인함' ([bool]($script:safeStopChecks -gt 0)) 'True'
Assert-Case '캡처실패: 클릭 0회' $script:clickCount 0
$script:screenCaptureFailing = $false

# ── ⑤ 배선 가드: 던전/사냥터 두 사본 모두 이 헬퍼를 쓰는가 ───────────────────
$workerRaw = [IO.File]::ReadAllText($workerPath)
Assert-Case '배선: 안정화 대기 호출 2곳(던전 정방향 + 사냥터 정방향)' `
  ([regex]::Matches($workerRaw, '\$lagWait = Wait-DgTributeCostSettles').Count) 2
Assert-Case '배선: 옛 2.5초 단발 재판독 잔존 없음' `
  ([regex]::Matches($workerRaw, 'Start-Sleep -Milliseconds 2500\r?\n\s*\$lagRecheck').Count) 0
Assert-Case '배선: 헬퍼 안에 클릭 호출 없음' `
  ([bool]((Get-SourceFunctionDefinitions -Path $workerPath -Names @('Wait-DgTributeCostSettles')) -notmatch 'Click-')) 'True'

# ── ⑥ 계약 고정: 소모량 판독 자체가 null 인 분기는 대기 없이 fail-closed ─────
# '카드도 미확인 + 소모량도 판독 불가'는 상태를 아무것도 보증할 수 없는 상태입니다.
# 켜기 방향의 표시 생성 지연은 실측이 없어, 기다려서 통과시키는 대신 정지를 유지합니다
# (반대 설정으로 입장해 은동전을 잘못 쓰는 쪽이 헛정지보다 비쌉니다 - 리뷰 합의).
Assert-Case '계약: null 분기는 안정화 대기 없이 커스텀 정지' `
  ([bool]($workerRaw -match '\$coinConfirmed = \(\$coinToggleOk[\s\S]{0,400}?exit 4')) 'True'
Assert-Case '계약: null 분기에 안정화 대기를 끼워 넣지 않음' `
  ([bool]($workerRaw -match '(?s)소모량 판독도 실패했습니다(?:(?!Wait-DgTributeCostSettles).){0,200}exit 4')) 'True'

exit $fails
