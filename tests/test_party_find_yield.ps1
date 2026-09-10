# '파티 찾기' 클릭의 사용자 조작 양보 계약 (2026-09-10 Codex 설계 합의 + 구현 리뷰)
#
# 배경: 던전·사냥터의 '파티 찾기'는 전송 확인 없이 한 번만 누르고 로그도 클릭 **전에** 남겼다.
# 조작으로 클릭이 생략되면 매칭이 시작되지 않은 채 매칭/입장 대기(기본 300초)를 다 태우고
# throw → 오류 종료였다 (2026-09-09 전수 감사. 사냥터는 matching 기본값이 '파티찾기'라 기본 경로).
#
# 계약 3가지 (Codex 가 회귀 핵심 단언으로 지정):
#   ① 취소 뒤 재판독 - 기다린 다음 화면을 다시 읽고, 조건이 맞을 때만 누른다
#   ② 실제 전송 뒤 추가 클릭 0회 - 매칭이 시작된 뒤 같은 자리를 다시 누르면 매칭 취소가 될 수 있다
#   ③ 화면이 확인되지 않으면 추가 클릭 금지, 관측으로 넘긴다
# 던전 전용: '구역' 단독으로는 부족하다 - 토글이 켜지면 같은 자리가 넓은 '입장하기'라
#   (파티찾기 분기 서두의 실측 계약) 토글 off 확정을 함께 요구한다.
#
# ★ 캡처 실패 경계 (2026-09-10 Codex 구현 리뷰가 잡은 실결함 2건):
#   P1) 판독 **도중** 캡처가 끊기면 빈 값이 나오는데, 그걸 '화면이 바뀌었다'로 확정하고
#       break 하면 화면이 곧 돌아와 옵션 화면이 그대로여도 재클릭 루프를 이미 빠져나온 뒤라
#       클릭 0회로 300초를 태우고 오류로 끝난다.
#   P2) 재판독 표시를 블록 **진입 즉시** 지우면, 동결 continue 뒤 사용자가 유휴가 됐을 때
#       다음 회전이 재판독을 통째로 건너뛰고 **캡처 실패 플래그가 참인 채로 클릭**한다.
#   → 첫 버전 테스트는 캡처 플래그를 항상 정상으로 둬서 이 둘을 놓쳤다. 스텁을 시퀀스 기반으로
#     바꿔 '판독 도중 실패 / 복구 탐침 여러 번 / 복구 후 소스 없음'을 직접 모형화한다.
#
# 루프 본문은 소스에서 그대로 잘라 실행한다 (사본 재구현 금지 - 진리표 계약).
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Get-LoopBlock {
  param([string]$SentVar)
  $pattern = '(?s)( *\$' + $SentVar + ' = \$false\r?\n.*?\r?\n    \})\r?\n    Start-Sleep -Milliseconds 1200'
  $m = [regex]::Match($script:workerText, $pattern)
  if (-not $m.Success) { throw "루프 본문을 소스에서 찾지 못했습니다: $SentVar" }
  return [scriptblock]::Create($m.Groups[1].Value)
}
$dgLoop = Get-LoopBlock -SentVar 'dgPartyFindSent'
$htLoop = Get-LoopBlock -SentVar 'htPartyFindSent'

$Game = $null
$ptDgPartyFind = @(775, 655)
$script:contentTag = '[던전]'
function Write-RunLog { param([string]$Message) }
function Focus-Game { param($Game) }
function Start-Sleep { param([int]$Seconds, [int]$Milliseconds) }
function Test-SafeStopDuringCaptureFail { $script:safeStopCalls++ }
function Move-CursorOutsideGame { param($Game) $script:parkCalls++ }
function Wait-UserYieldEnd { param($Game, [string]$Context = '자동화') $script:waitCalls++ }
function Test-UserRecentlyActive {
  param([int]$IdleMs = 2500)
  $i = $script:activeCalls; $script:activeCalls++
  if ($i -lt $script:activeSeq.Count) { return [bool]$script:activeSeq[$i] }
  return $false
}
function Click-GamePoint {
  param($Game, $ReferenceX, $ReferenceY)
  $i = $script:clickCalls; $script:clickCalls++
  # 캡처 실패 플래그가 참인 채로 클릭하면 안 됩니다 (Codex 구현 리뷰 P2 의 직접 증거)
  if ($script:screenCaptureFailing) { $script:clickedWhileFailing++ }
  $r = if ($i -lt $script:clickSeq.Count) { [string]$script:clickSeq[$i] } else { 'ok' }
  $script:lastClickPerformed = ($r -eq 'ok')
  $script:lastClickSkipReason = $(if ($r -eq 'ok') { '' } else { $r })
}
# 판독 스텁: 회차별로 '판독값 + 그 판독 도중의 캡처 실패 여부'를 주입합니다.
# 시퀀스가 소진되면 스칼라 기본값을 쓰고 플래그는 건드리지 않습니다 (기존 케이스 보존).
function Step-ReadSeq {
  param([object[]]$Seq, [int]$Index)
  if ($Index -lt $Seq.Count) { return $Seq[$Index] }
  return $null
}
function Read-DgTitleText {
  param($Game)
  $i = $script:titleCalls; $script:titleCalls++
  $e = Step-ReadSeq -Seq $script:titleSeq -Index $i
  if ($null -ne $e) {
    $script:screenCaptureFailing = [bool]$e.Fail
    return [string]$e.Text
  }
  $script:screenCaptureFailing = $false   # 기본 판독 = 성공 (Register-CaptureSuccess 계약)
  return [string]$script:titleValue
}
function Find-DgChanceTogglePoint {
  param($Game)
  $i = $script:togglePointCalls; $script:togglePointCalls++
  $e = Step-ReadSeq -Seq $script:togglePointSeq -Index $i
  if ($null -ne $e) {
    $script:screenCaptureFailing = [bool]$e.Fail
    return $(if ([bool]$e.Found) { @{ X = 1136; Y = 443 } } else { $null })
  }
  $script:screenCaptureFailing = $false   # 기본 판독 = 성공 (Register-CaptureSuccess 계약)
  return $(if ($script:togglePointFound) { @{ X = 1136; Y = 443 } } else { $null })
}
function Get-ChanceToggleState {
  # ★ 2026-09-10 Codex 정정: 실제 Get-ChanceToggleState 는 Get-GamePixel 직접 픽셀 판독이라
  #   Register-CaptureSuccess 를 부르지 않습니다 - **캡처 플래그를 갱신하지 않습니다**.
  #   (원본 실행 확인: 플래그 참 + 픽셀 성공 → 'off' 이면서 플래그 참 유지 / 플래그 거짓 +
  #    픽셀 예외 → 'unknown' 이면서 플래그 거짓 유지). 픽셀 판독 실패는 'unknown' 으로 모형화하고,
  #   '판독 중 캡처 실패'는 앵커 OCR(togglePointSeq) 쪽으로 주입해야 합니다.
  param($Game, $Point)
  $i = $script:toggleCalls; $script:toggleCalls++
  $e = Step-ReadSeq -Seq $script:toggleSeq -Index $i
  if ($null -ne $e) { return [string]$e.State }
  return [string]$script:toggleValue
}
function Find-HtEntryButtonPoint {
  param($Game)
  $i = $script:htButtonCalls; $script:htButtonCalls++
  $e = Step-ReadSeq -Seq $script:htSeq -Index $i
  if ($null -ne $e) {
    $script:screenCaptureFailing = [bool]$e.Fail
    return $(if ([bool]$e.Found) { @{ X = 900; Y = 650 } } else { $null })
  }
  $script:screenCaptureFailing = $false   # 기본 판독 = 성공 (Register-CaptureSuccess 계약)
  return $(if ($script:htButtonFound) { @{ X = 900; Y = 650 } } else { $null })
}

function Reset-Sim {
  param([object[]]$Active = @(), [object[]]$Clicks = @())
  $script:activeSeq = $Active; $script:clickSeq = $Clicks
  $script:activeCalls = 0; $script:clickCalls = 0
  $script:waitCalls = 0; $script:parkCalls = 0; $script:safeStopCalls = 0
  $script:titleCalls = 0; $script:toggleCalls = 0; $script:togglePointCalls = 0; $script:htButtonCalls = 0
  $script:clickedWhileFailing = 0
  $script:titleSeq = @(); $script:toggleSeq = @(); $script:togglePointSeq = @(); $script:htSeq = @()
  $script:screenCaptureFailing = $false
  $script:titleValue = '허상의 정박지 2층 2구역'
  $script:togglePointFound = $true; $script:toggleValue = 'off'
  $script:htButtonFound = $true
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = ''
}

# ══════════ 던전 ══════════
Reset-Sim -Active @($false) -Clicks @('ok')
. $dgLoop
Assert-Case '던전: 조작 없으면 클릭 1회로 전송 확정' ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '1/True'
Assert-Case '던전: 전송됐으면 대기·재판독을 하지 않는다' ('{0}/{1}' -f $script:waitCalls, $script:titleCalls) '0/0'

Reset-Sim -Active @($false, $false) -Clicks @('user-active', 'ok')
. $dgLoop
Assert-Case '던전: 조작 취소 → 기다렸다가 다시 눌러 전송 (클릭 2회)' ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '2/True'
Assert-Case '던전: 취소 뒤 반드시 기다린다' $script:waitCalls 1
Assert-Case '던전: 취소 뒤 반드시 재판독한다 (대피 + 제목 + 토글)' ('{0}/{1}/{2}' -f $script:parkCalls, $script:titleCalls, $script:toggleCalls) '1/1/1'

Reset-Sim -Active @($false, $false) -Clicks @('user-active', 'ok')
$script:titleValue = '허상의 정박지'
. $dgLoop
Assert-Case '던전: 옵션 화면이 확인되지 않으면 다시 누르지 않는다 (클릭 1회에서 멈춤)' ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '1/False'

Reset-Sim -Active @($false, $false) -Clicks @('user-active', 'ok')
$script:toggleValue = 'on'
. $dgLoop
Assert-Case "던전: 토글이 'on' 이면 그 자리가 '입장하기'라 누르지 않는다" ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '1/False'

Reset-Sim -Active @($false, $false) -Clicks @('user-active', 'ok')
$script:toggleValue = 'unknown'
. $dgLoop
Assert-Case "던전: 토글이 'unknown' 이어도 누르지 않는다 (off 확정 요구)" $script:clickCalls 1

Reset-Sim -Active @($false, $false) -Clicks @('user-active', 'ok')
$script:togglePointFound = $false
. $dgLoop
Assert-Case '던전: 토글 앵커를 못 찾으면 누르지 않는다 (고정점 폴백 금지 계약)' $script:clickCalls 1

Reset-Sim -Active @($false) -Clicks @('cursor-not-ready')
. $dgLoop
Assert-Case '던전: 커서 미확인이면 재시도하지 않고 관측으로 넘긴다' ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '1/False'

# ── 캡처 실패 경계 (Codex 구현 리뷰 P1) ──
# 제목 판독 **도중** 캡처가 끊김 → 빈 값. 이걸 '화면이 바뀌었다'로 확정하면 안 된다.
# 다음 회전에 복구되면 옵션 화면이 그대로이므로 눌러야 한다.
Reset-Sim -Active @($false, $false, $false) -Clicks @('user-active', 'ok')
$script:titleSeq = @(
  @{ Text = ''; Fail = $true },                              # 1회 판독 도중 실패
  @{ Text = '허상의 정박지 2층 2구역'; Fail = $false },        # 동결 분기의 복구 탐침 = 복구
  @{ Text = '허상의 정박지 2층 2구역'; Fail = $false })        # 재판독 - 옵션 화면 그대로
. $dgLoop
Assert-Case '던전: 제목 판독 도중 캡처 실패는 화면 변경이 아니다 (복구 후 눌러야 함)' `
  ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '2/True'
Assert-Case '던전: 캡처 실패 중에는 클릭하지 않는다' $script:clickedWhileFailing 0

# 토글 **앵커 OCR** 판독 도중 캡처 실패도 같은 계약 (상태 판독은 픽셀이라 플래그를 안 건드립니다)
Reset-Sim -Active @($false, $false, $false) -Clicks @('user-active', 'ok')
$script:togglePointSeq = @(
  @{ Found = $false; Fail = $true },                         # 앵커 OCR 도중 실패
  @{ Found = $true; Fail = $false })                         # 재판독 - 앵커 정상
. $dgLoop
Assert-Case '던전: 토글 앵커 OCR 도중 캡처 실패도 미확정으로 다룬다 (관측으로 새지 않음)' `
  ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '2/True'
Assert-Case '던전: 그때도 캡처 실패 중 클릭 0회' $script:clickedWhileFailing 0

# 픽셀 판독 실패는 캡처 플래그가 아니라 'unknown' 으로 나타납니다 - off 확정 요구에 걸려 관측으로
Reset-Sim -Active @($false, $false) -Clicks @('user-active', 'ok')
$script:toggleSeq = @(@{ State = 'unknown' })
. $dgLoop
Assert-Case '던전: 픽셀 판독 실패(unknown)는 off 확정 요구에 걸려 누르지 않는다' `
  ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '1/False'

# ── 동결 continue 뒤 재판독 우회 금지 (Codex 구현 리뷰 P2) ──
# 진입 시 이미 캡처 실패 + 사용자는 곧 유휴. 복구 탐침이 2회 필요한 경우.
Reset-Sim -Active @($true, $false, $false, $false) -Clicks @('ok')
$script:screenCaptureFailing = $true
$script:titleSeq = @(
  @{ Text = ''; Fail = $true },                              # 동결 탐침 1 - 아직 실패
  @{ Text = ''; Fail = $false },                             # 동결 탐침 2 - 복구
  @{ Text = '허상의 정박지 2층 2구역'; Fail = $false })        # 재판독 - 검증 통과
. $dgLoop
Assert-Case '던전: 동결 continue 뒤에도 재판독을 건너뛰지 않는다 (탐침 2회 필요)' `
  ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '1/True'
Assert-Case '던전: 동결 중 클릭 0회 + 안전 중지 확인 2회' `
  ('{0}/{1}' -f $script:clickedWhileFailing, $script:safeStopCalls) '0/2'

# 복구했는데 소스 화면이 없으면 → 그때는 관측으로 (클릭 금지)
Reset-Sim -Active @($true, $false, $false) -Clicks @('ok')
$script:screenCaptureFailing = $true
$script:titleSeq = @(
  @{ Text = ''; Fail = $false },                             # 동결 탐침 - 복구
  @{ Text = '허상의 정박지'; Fail = $false })                  # 재판독 - '구역' 없음
. $dgLoop
Assert-Case '던전: 복구 후 소스 화면이 없으면 누르지 않는다' ('{0}/{1}' -f $script:clickCalls, $dgPartyFindSent) '0/False'

# ══════════ 사냥터 ══════════
Reset-Sim -Active @($false) -Clicks @('ok')
. $htLoop
Assert-Case '사냥터: 조작 없으면 클릭 1회로 전송 확정' ('{0}/{1}' -f $script:clickCalls, $htPartyFindSent) '1/True'
Assert-Case '사냥터: 전송됐으면 첫 화면을 다시 읽지 않는다 (추가 클릭 0회)' $script:htButtonCalls 0

Reset-Sim -Active @($false, $false) -Clicks @('user-active', 'ok')
. $htLoop
Assert-Case '사냥터: 조작 취소 → 기다렸다가 첫 화면 확인 후 재클릭' ('{0}/{1}' -f $script:clickCalls, $htPartyFindSent) '2/True'
Assert-Case '사냥터: 취소 뒤 대기 + 대피 + 첫 화면 재판독' ('{0}/{1}/{2}' -f $script:waitCalls, $script:parkCalls, $script:htButtonCalls) '1/1/1'

Reset-Sim -Active @($false, $false) -Clicks @('user-active', 'ok')
$script:htButtonFound = $false
. $htLoop
Assert-Case '사냥터: 첫 화면이 확인되지 않으면 다시 누르지 않는다 (관측으로)' ('{0}/{1}' -f $script:clickCalls, $htPartyFindSent) '1/False'

Reset-Sim -Active @($false) -Clicks @('cursor-not-ready')
. $htLoop
Assert-Case '사냥터: 커서 미확인이면 재시도하지 않는다' ('{0}/{1}' -f $script:clickCalls, $htPartyFindSent) '1/False'

# 캡처 실패 경계
Reset-Sim -Active @($false, $false, $false) -Clicks @('user-active', 'ok')
$script:htSeq = @(
  @{ Found = $false; Fail = $true },                         # 판독 도중 실패 ($null)
  @{ Found = $true; Fail = $false },                         # 동결 탐침 - 복구
  @{ Found = $true; Fail = $false })                         # 재판독 - 첫 화면 그대로
. $htLoop
Assert-Case '사냥터: 버튼 판독 도중 캡처 실패는 화면 변경이 아니다' ('{0}/{1}' -f $script:clickCalls, $htPartyFindSent) '2/True'
Assert-Case '사냥터: 캡처 실패 중 클릭 0회' $script:clickedWhileFailing 0

Reset-Sim -Active @($true, $false, $false, $false) -Clicks @('ok')
$script:screenCaptureFailing = $true
$script:htSeq = @(
  @{ Found = $false; Fail = $true },                         # 동결 탐침 1 - 아직 실패
  @{ Found = $false; Fail = $false },                        # 동결 탐침 2 - 복구
  @{ Found = $true; Fail = $false })                         # 재판독 - 검증 통과
. $htLoop
Assert-Case '사냥터: 동결 continue 뒤에도 재판독을 건너뛰지 않는다' ('{0}/{1}' -f $script:clickCalls, $htPartyFindSent) '1/True'
Assert-Case '사냥터: 동결 중 클릭 0회 + 안전 중지 확인 2회' ('{0}/{1}' -f $script:clickedWhileFailing, $script:safeStopCalls) '0/2'

# ── 배선 가드: 로그 정직화 + 생활 잔존 창 계약 ──
Assert-Case '배선: 던전 파티찾기 로그가 전송 확인 뒤로 옮겨졌다' `
  ([bool]($workerText -match "\`$dgPartyFindSent = \`$true[\s\S]{0,200}?'파티 찾기' 클릭 - 파티 매칭을 기다립니다")) 'True'
Assert-Case '배선: 사냥터도 동일' `
  ([bool]($workerText -match "\`$htPartyFindSent = \`$true[\s\S]{0,200}?'파티 찾기' 클릭 - 파티 매칭을 기다립니다")) 'True'
Assert-Case '배선: 생활 잔존 창 X 닫기도 조작 취소를 회전 미계상으로 돌린다' `
  ([bool]($workerText -match "Invoke-LifeWindowCloseClick -Game \`$Game[\s\S]{0,1200}?if \(-not \`$script:lastClickPerformed -and \`$script:lastClickSkipReason -eq 'user-active'\) \{[\s\S]{0,300}?\`$script:lifeMenuYielded = \`$true[\s\S]{0,300}?return \`$false")) 'True'
# 미검출만으로 '화면이 바뀌었다'고 단정하지 않습니다 (Codex P3 - 문구는 '확인되지 않습니다')
Assert-Case '배선: 미검출 로그가 화면 변경을 단정하지 않는다' `
  ((-not $workerText.Contains("양보 중 옵션 화면을 벗어났습니다")) -and
   (-not $workerText.Contains("양보 중 첫 화면이 바뀌었습니다"))) 'True'

if ($fails -gt 0) { "실패 $fails 건"; exit 1 }
'전부 통과'
exit 0
