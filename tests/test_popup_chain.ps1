# 입장 직후 구매 팝업 **연쇄** 처리 진리표 (2026-08-09 실측으로 원인 확정).
#
# 실측 배경: 이 팝업은 하나를 닫으면 다음이 잠시 뒤에 뜬다. 화면을 200ms 간격으로 관찰한
# 실제 간격은 **1.020 / 1.471 / 1.752초**(사라진 시각 → 다음 등장 시각) 였다.
# 워커는 클릭 후 1초만 자고 판독하므로 그 시점엔 화면이 비어 있고, 예전 코드는 거기서
# 곧바로 break 해서 **직후에 뜨는 팝업을 영영 못 닫았다.** 그 팝업이 이어지는 B(음식) 키를
# 먹는 것이 제보 증상이다.
#
# ※ 이 타이밍은 **커서 가림과 별개의 두 번째 원인**이다. 둘 다 실기로 확정됐다:
#   ① 커서 가림 - 커서가 게임 창 위에 있으면 게임이 자기 커서를 그려 캡처에 찍히고
#      '닫기'를 덮는다(커서 위 0/6 vs 창 밖 6/6). 판독 전 대피로 막는다.
#   ② 이 연쇄 타이밍 - 재확인으로 막는다.
#   중간 감사가 ①을 "기각"한 적이 있는데 그 측정은 커서가 창 위에 없는 상태(flags=1)에서
#   잰 것이라 게임이 커서를 그리지 않는 조건이었다. 이 계열은 flags 를 반드시 함께 볼 것.
#
# ★ 6차 점검 추가: 재확인의 **문턱**도 계약이다. 5차까지는 '한 번이라도 닫았는가'
#   ($entryPopupClicks -gt 0)로 열었는데, 팝업을 찾고도 커서 확인 실패로 클릭이 건너뛰어지면
#   횟수가 0이라 재확인이 통째로 생략됐다 → 팝업이 그대로인데 B 키가 나가 제보 증상 재현.
#   '봤는가'($entryPopupSeen)로 바꿔야 그 구멍이 닫힌다. 아래 ①-D 가 그 진리표다.
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

# ── ① 루프 시뮬레이션: 실측 간격을 그대로 넣어 연쇄가 처리되는지 ──────────────
# 화면을 시간 함수로 모형화한다. 팝업 i 는 [등장, 소멸] 구간에 보인다.
# 소멸은 '워커가 닫았을 때'로 잡고, 다음 팝업은 그로부터 gap 초 뒤에 뜬다.
function Invoke-PopupLoopSim {
  param(
    [double[]]$Gaps,          # 닫은 뒤 다음 팝업이 뜨기까지의 간격(초)
    [switch]$WithRecheck,     # 5차 수정(1200ms 재확인) 적용 여부
    [switch]$SeenGuard,       # 6차 수정: 재확인 문턱을 '봤는가'로. 미지정이면 구버전('닫았는가')
    [int]$SkipClicksUntil = 0, # 이 회전 번호까지는 커서 확인 실패로 클릭이 나가지 않는다
    [int]$MissAtTry = 0,       # 이 회전의 **첫 판독**만 팝업을 놓친다(OCR 순간 실패)
    # ★ 7차 점검: 예전 하네스는 이 값을 상수 $true 로 박아 둬서 `-Gaps @()` 가 '팝업 0개'가
    #   아니라 '팝업 1개'였습니다. 그래서 '정상 경로는 비용 0' 이라고 적힌 케이스가 실제로는
    #   팝업 1개끼리 비교하고 있었고, 무팝업 경로에 1.2초 대기와 추가 판독이 새어 들어와도
    #   통과했을 겁니다. 비용을 재려면 '팝업이 아예 없는 화면'을 모형화할 수 있어야 합니다.
    [bool]$StartVisible = $true,
    [double]$RecheckWait = 1.2,
    [int]$MaxTry = 4
  )
  $now = 0.0
  $clicks = 0
  $reads = 0                 # 판독(OCR) 횟수 - 정상 경로의 비용 계약을 재는 값
  $seenEver = $false
  $visibleAt = 0.0           # 현재 팝업이 보이기 시작한 시각
  $remaining = @($Gaps)
  $visible = $StartVisible   # 입장 시점에 첫 팝업이 떠 있는가
  for ($try = 1; $try -le $MaxTry; $try++) {
    $reads++
    $seen = ($visible -and $now -ge $visibleAt)
    if ($try -eq $MissAtTry) { $seen = $false }   # 첫 판독만 놓침
    if (-not $seen) {
      # 재확인을 열지 말지의 **문턱**. 여기가 6차에서 바뀐 지점이다.
      $guardOpen = $(if ($SeenGuard) { $seenEver } else { $clicks -gt 0 })
      if (-not $guardOpen) { return @{ Clicks = $clicks; Leftover = $visible; Reads = $reads; Waited = $now } }
      if (-not $WithRecheck) { return @{ Clicks = $clicks; Leftover = $visible; Reads = $reads; Waited = $now } }
      $now += $RecheckWait
      $seen = ($visible -and $now -ge $visibleAt)
      if (-not $seen) { return @{ Clicks = $clicks; Leftover = $visible; Reads = $reads; Waited = $now } }
    }
    $seenEver = $true
    if ($try -ge $MaxTry) { return @{ Clicks = $clicks; Leftover = $true; Reads = $reads; Waited = $now } }
    # 닫기 클릭 - 커서 확인에 걸리면 입력이 나가지 않아 팝업이 그대로 남는다
    if ($try -le $SkipClicksUntil) {
      $now += 1.0
      continue
    }
    $clicks++
    $visible = $false
    if ($remaining.Count -gt 0) {
      $visibleAt = $now + $remaining[0]
      $remaining = @($remaining | Select-Object -Skip 1)
      $visible = $true
    }
    $now += 1.0   # 워커의 클릭 후 대기
  }
  return @{ Clicks = $clicks; Leftover = $visible; Reads = $reads; Waited = $now }
}

$measured = @(1.020, 1.471, 1.752)   # 실측값

# ①-A 5차 수정 전: 실측 간격에서 한 개만 닫고 이탈
$old = Invoke-PopupLoopSim -Gaps $measured
Assert-Case '수정 전: 실측 간격에서 1개만 닫고 이탈' $old.Clicks 1
Assert-Case '수정 전: 팝업이 남은 채 키 입력으로 진행' $old.Leftover $true

# ①-B 5차 수정 후
$new = Invoke-PopupLoopSim -Gaps $measured -WithRecheck -SeenGuard
Assert-Case '수정 후: 3회(상한)까지 연달아 닫음' $new.Clicks 3
# 상한(4회전=3닫기)까지 쓰고도 남으면 기존 계약대로 '남음' 처리 → 클리어 대기 루프가 이어받음
Assert-Case '수정 후: 상한 도달은 기존 계약대로 남음 처리' $new.Leftover $true

# 팝업이 2개뿐이면 전부 닫고 깨끗하게 끝나야 한다
$two = Invoke-PopupLoopSim -Gaps @(1.020, 1.471) -WithRecheck -SeenGuard
Assert-Case '수정 후: 팝업 3개(연쇄 2회)면 전부 닫고 종료' $two.Clicks 3
Assert-Case '수정 후: 남은 팝업 없음' $two.Leftover $false

# ①-C 정상 경로(팝업이 **아예 없음**)는 비용이 늘지 않아야 한다.
# ★ 7차 점검: 예전에는 `-Gaps @()` 를 '팝업 없음'이라 부르며 클릭 횟수만 비교했는데,
#   하네스가 첫 팝업을 상수로 띄우고 있어 실제로는 '팝업 1개' 끼리의 비교였습니다.
#   설계 합의('무팝업이면 OCR 1회만 추가')를 지킨다고 적힌 케이스가 사실은 아무것도
#   지키지 못하고 있었던 것입니다. 이제 화면에 팝업이 없는 상태를 직접 모형화하고,
#   **판독 횟수와 누적 대기**로 비용을 잽니다.
$empty = Invoke-PopupLoopSim -Gaps @() -StartVisible:$false -WithRecheck -SeenGuard
Assert-Case '정상 경로(무팝업): 판독 1회' $empty.Reads 1
Assert-Case '정상 경로(무팝업): 추가 대기 0초' $empty.Waited 0
Assert-Case '정상 경로(무팝업): 클릭 0회' $empty.Clicks 0
Assert-Case '정상 경로(무팝업): 남은 팝업 없음' $empty.Leftover $false
# 문턱을 '닫았는가'로 되돌려도 무팝업 비용은 같아야 한다(이 케이스가 문턱 변경에 둔감한지 확인)
$emptyOld = Invoke-PopupLoopSim -Gaps @() -StartVisible:$false -WithRecheck
Assert-Case '정상 경로(무팝업): 문턱과 무관하게 비용 동일' `
  ("{0}/{1}" -f $emptyOld.Reads, $emptyOld.Waited) ("{0}/{1}" -f $empty.Reads, $empty.Waited)
# 팝업이 딱 1개인 경로도 5차 상태와 같아야 한다 (판독 3회 / 1초 + 1.2초)
$one = Invoke-PopupLoopSim -Gaps @() -WithRecheck -SeenGuard
Assert-Case '팝업 1개: 한 번 닫고 끝' $one.Clicks 1
Assert-Case '팝업 1개: 판독 2회(클릭 전 1 + 재확인 1)' $one.Reads 2
Assert-Case '팝업 1개: 누적 대기 2.2초(클릭 후 1 + 재확인 1.2)' ([Math]::Round($one.Waited, 3)) 2.2
Assert-Case '팝업 1개: 남은 팝업 없음' $one.Leftover $false

# ①-D ★6차: '봤지만 클릭이 안 나간' 경우의 문턱 (커서 확인 실패 + 다음 판독 순간 실패)
#   구버전 문턱(닫은 횟수)은 0이라 재확인이 안 열리고 팝업이 남은 채 키가 나간다.
$skipOld = Invoke-PopupLoopSim -Gaps $measured -WithRecheck -SkipClicksUntil 1 -MissAtTry 2
Assert-Case '6차 전: 클릭을 못 보내면 재확인이 안 열려 팝업이 남음' $skipOld.Leftover $true
Assert-Case '6차 전: 닫은 횟수 0' $skipOld.Clicks 0
$skipNew = Invoke-PopupLoopSim -Gaps $measured -WithRecheck -SeenGuard -SkipClicksUntil 1 -MissAtTry 2
Assert-Case '6차 후: 봤으면 재확인이 열려 결국 닫음' ([bool]($skipNew.Clicks -gt 0)) 'True'
#   전부 건너뛰기만 하면(커서 확인이 계속 실패) 상한까지 가고 '남음'으로 끝나야 한다
$allSkip = Invoke-PopupLoopSim -Gaps $measured -WithRecheck -SeenGuard -SkipClicksUntil 9
Assert-Case '6차 후: 클릭이 계속 안 나가면 남음으로 마감(경고 대상)' $allSkip.Leftover $true
Assert-Case '6차 후: 그때 닫은 횟수는 0' $allSkip.Clicks 0

# 대기 예산이 실측 최대 간격을 덮는가
Assert-Case '예산: 1초(클릭 후) + 1.2초(재확인) > 실측 최대 1.752초' `
  ([bool]((1.0 + 1.2) -gt ($measured | Measure-Object -Maximum).Maximum)) 'True'

# ── ② 배선 가드 ──────────────────────────────────────────────────────────────
$entryBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-AfterEntryKeys'))
Assert-Case '배선: 못 찾아도 바로 break 하지 않는다' `
  ([bool]($entryBody -match 'if \(-not \$entryPopupPoint\) \{\s*\r?\n')) 'True'
# ★ 문턱은 '봤는가'다. '닫았는가'로 되돌리면 위 ①-D 의 구멍이 다시 열린다.
Assert-Case '배선: 재확인 문턱이 봤는가(entryPopupSeen)' `
  ([bool]($entryBody -match 'if \(-not \$entryPopupSeen\) \{ break \}')) 'True'
Assert-Case '배선: 봤다는 사실은 클릭 성패와 무관하게 기록' `
  ([bool]($entryBody -match '(?s)if \(-not \$entryPopupPoint\) \{.*\$entryPopupSeen = \$true\s*\r?\n\s*if \(\$popupTry -ge 4\)')) 'True'
Assert-Case '배선: 재확인 대기가 실측 간격을 덮는다(1200ms)' `
  ([bool]($entryBody -match 'Start-Sleep -Milliseconds 1200')) 'True'
Assert-Case '배선: 재확인에서도 못 찾으면 이탈' `
  ([bool]($entryBody -match '(?s)Start-Sleep -Milliseconds 1200.*if \(-not \$entryPopupPoint\) \{ break \}')) 'True'
Assert-Case '배선: 연쇄 처리를 로그로 남긴다' `
  ([bool]($entryBody -match '팝업이 연달아 떠 한 번 더 닫습니다')) 'True'
# ★ 재확인 **전에도 커서 대피가 필요합니다.** 방금 '닫기'를 클릭했으니 커서가 그 자리에
#   남아 있고, 게임이 그린 커서가 다음 팝업의 '닫기'를 덮어 판독이 0% 가 됩니다
#   (2026-08-09 실측: 커서 위 0/6 vs 창 밖 6/6). 이 줄이 빠지면 연쇄 재확인이 거의 항상
#   실패해 이 수정 자체가 무의미해집니다 (5차 점검에서 실제로 빠져 있었음).
Assert-Case '배선: 재확인 Find 앞에 커서 대피가 있다' `
  ([bool]($entryBody -match 'Start-Sleep -Milliseconds 1200[\s\S]{0,500}Move-CursorOutsideGame -Game \$Game[\s\S]{0,300}Find-GameTextPoint')) 'True'
# ★ 클릭이 실제로 나갔을 때만 세야 합니다. 건너뛴 것까지 세면 '닫았다'로 계상돼 로그가
#   거짓이 되고 재확인 분기도 잘못 열립니다.
Assert-Case '배선: 실제 클릭만 계상(건너뜀은 세지 않음)' `
  ([bool]($entryBody -match 'if \(\$script:lastClickPerformed\) \{ \$entryPopupClicks\+\+ \}')) 'True'
Assert-Case '배선: 기존 상한(4회전) 계약 유지' `
  ([bool]($entryBody -match 'if \(\$popupTry -ge 4\) \{ \$entryPopupRemains = \$true; break \}')) 'True'
# ★ 6차: 잔존은 **클릭을 한 번도 못 보낸 경우에도** 알려야 한다. 예전 조건은 그 경우를
#   침묵으로 넘겨, 팝업이 남은 채 키가 나가는데 로그가 깨끗했다.
Assert-Case '배선: 잔존이면 클릭 0회여도 경고를 남긴다' `
  ([bool]($entryBody -match 'if \(\$entryPopupClicks -gt 0 -or \$entryPopupRemains\) \{')) 'True'
Assert-Case '배선: 클릭 0회 잔존은 사유를 구분해 기록' `
  ([bool]($entryBody -match '닫기 클릭을 한 번도 보내지 못했습니다')) 'True'

# ── 게임 재시작 요구 팝업 (2026-08-11 19:00 실사고) ─────────────────────────────
# '너무 오랫동안 실행되고 있습니다' 팝업이 난이도 알약을 덮어 "글자를 못 찾음" 오류로
# 오진되던 것 → 스윕 초입에서 감지해 명확한 사유로 조건부 정지 (사용자 요청).
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Test-GameRestartPopup')) {
  . ([scriptblock]::Create($definition))
}
$script:screenCaptureFailing = $false
$script:stubRestartText = ''
$rgRestartPopup = @(430, 70, 410, 70)
$ocrKoreanEngine = $null
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine) return $script:stubRestartText }

# 실측 판독 원문 (3장 × 2영역 × 2배율 전부 동일 - '시'는 항상 깨짐)
$script:stubRestartText = '게임이너무오랫동안실행되고있습니다.게임을재Å|작해주세요.'
Assert-Case '재시작 팝업: 실측 판독 = 감지' (Test-GameRestartPopup -Game $null) 'True'
$script:stubRestartText = '게임이너무오랫동안실행되고있습니다.게임을재ÅI작해주세요.'
Assert-Case '재시작 팝업: s4 변형 판독도 감지' (Test-GameRestartPopup -Game $null) 'True'
$script:stubRestartText = '2층2구역일반어려움'
Assert-Case '재시작 팝업: 옵션 화면 정상 판독은 비감지' (Test-GameRestartPopup -Game $null) 'False'
$script:stubRestartText = '오랫동안'
Assert-Case '재시작 팝업: 조각 단독은 비감지 (조합 요구)' (Test-GameRestartPopup -Game $null) 'False'
$script:stubRestartText = ''
Assert-Case '재시작 팝업: 빈 판독 비감지' (Test-GameRestartPopup -Game $null) 'False'
$script:screenCaptureFailing = $true
$script:stubRestartText = '게임이너무오랫동안실행되고있습니다'
Assert-Case '재시작 팝업: 캡처 실패 중 판독 무효' (Test-GameRestartPopup -Game $null) 'False'
$script:screenCaptureFailing = $false

# 배선: 스윕 초입에서 검사하고 명확한 사유 + exit 4
$sweepBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Invoke-PurchasePopupSweep'))
$sweepCode = (($sweepBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 스윕이 재시작 팝업을 닫기 탐색보다 먼저 검사' `
  ([bool]($sweepCode -match "(?s)Test-GameRestartPopup -Game \`$Game[\s\S]{0,400}SearchText '닫기'")) 'True'
Assert-Case '배선: 감지 시 명확한 사유로 조건부 정지 (exit 4)' `
  ([bool]($sweepCode -match '(?s)너무 오랫동안 실행되고 있습니다[^\r\n]*재시작[^\r\n]*\r?\n\s*exit 4')) 'True'

# ── 퀘스트 클리어 보상 전체 화면 - 클리어 대기 배선 (2026-08-27 실사고: 사냥 완료 대기 중
#    '[주간 목표]' 보상 화면이 덮여 확인을 못 누름. 처리기는 스윕에만 있었고(07-28 입장 대기
#    실사고분) 클리어 대기(어비스/던전/사냥터 공용)에는 미배선. 공용 소함수로 추출 + 같은 폴
#    의 클리어 문구 판독 스태시를 재사용해 추가 판독 0회 - Codex 합의) ──
$rewardFnCode = ((([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Close-QuestRewardScreen'))) -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '보상: 공용 소함수 게이트(아이템을누르/상세정보) + 확인 탐색 영역(400,628)' `
  (($rewardFnCode.Contains("'아이템을누르'") -and $rewardFnCode.Contains("'상세정보'")) -and
   ($rewardFnCode -match '-ReferenceX 400 -ReferenceY 628')) 'True'
Assert-Case '보상: BottomText 전달 여부는 PSBoundParameters 로 판정 (재판독 생략 정밀화)' `
  ($rewardFnCode.Contains("PSBoundParameters.ContainsKey('BottomText')")) 'True'
Assert-Case '보상: 스윕은 이미 읽은 하단 문구를 넘겨 재판독 생략' `
  ([bool]($workerSource -match 'if \(Close-QuestRewardScreen -Game \$Game -BottomText \$bottomText\) \{ return \$true \}')) 'True'
Assert-Case '보상: 클리어 문구 판정이 판독문을 스태시 (조기 return 전)' `
  ([bool]($workerSource -match '\$normalized = \$ocrText -replace[\s\S]{0,420}\$script:lastClearPromptText = \$normalized[\s\S]{0,80}화면을')) 'True'
Assert-Case '보상: 클리어 대기 배선 - 스태시 재사용 + 보상 처리가 clear 반환보다 먼저 (합성 판독 오인 방지)' `
  ([bool]($workerSource -match '\$clearPromptDetected = Test-DungeonClearPrompt -Game \$Game[\s\S]{0,900}Close-QuestRewardScreen -Game \$Game -LogPrefix[\s\S]{0,120}-BottomText \$script:lastClearPromptText\)\) \{ continue \}\r?\n\s+if \(\$clearPromptDetected\)')) 'True'
Assert-Case '보상: 마감 최종 탐침에도 배선 (마지막 폴 간격 등장 시 timeout 확정 방지)' `
  ([bool]($workerSource -match "elseif \(Close-QuestRewardScreen -Game \`$Game -LogPrefix[\s\S]{0,500}throw '던전 클리어 화면 감지 대기 시간이 초과됐습니다\.'")) 'True'
# 실측 판독 재현 (2026-08-27 캡처: rgClearExit s3 = '아이템을누르면상세정보테볼수있습니다확인')
# - 게이트가 실제 사고 판독문에서 발화하고, 클리어 문구 조각들에는 전부 불발이어야 함
$rewardMeasured = '아이템을누르면상세정보테볼수있습니다확인'
Assert-Case '보상: 실측 판독문에서 게이트 발화' `
  ($rewardMeasured.Contains('아이템을누르') -or $rewardMeasured.Contains('상세정보')) 'True'
foreach ($clearPair in @(@('화면을', '터'), @('화면을', '주세요'), @('치해', '면'), @('화면', '치'))) {
  if ($rewardMeasured.Contains([string]$clearPair[0]) -and $rewardMeasured.Contains([string]$clearPair[1])) {
    "FAIL 보상: 실측 판독문이 클리어 조각 '$($clearPair -join '+')'에 걸림 (배타성 붕괴)"; $fails++
  }
}
"OK   보상: 실측 판독문이 클리어 문구 조각 4조합 전부 불발 (Codex 배타성 확인)"

exit $fails
