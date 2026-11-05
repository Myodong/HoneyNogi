# 어비스 보상 화면 '나가기' 글자 위치 클릭 (v2.1.11 - 2026-09-18 실사고)
#
# 관측(2026-09-18 21:02 개발 PC, 던전이미지\어비스\20260918_보상화면_3버튼_나가기_다시하기_다른던전가기_1270x702.png):
# 보상 화면 하단이 1버튼(나가기 중앙)에서 3버튼('[ESC] 나가기' / '[Space] 다시 하기' / '다른 던전 가기')으로 바뀌어
# 고정 좌표 $ptExitButton (636,655) 가 '다시 하기' 한복판 = 재입장. Test-ExitButton 은 여전히 참이라 로그엔 '나가기 클릭'.
# 워커와 같은 경로(clearAndExitText (430,570,420,125), 배율 3, ko) 판독의 기준좌표(진리표 원본 - 실측 문자열 그대로):
#   아이템을@533 누르면@582 상세@619 정보테@656 볼@686 수@703 있습니다@740 (y591) / 나가기@(478,654) / Space@(579,630) /
#   다세@(615,654) 하기@(657,654) / 다른@(759,654) 던전@(794,654) 가기@(829,654)   (배율 4 는 '정보로'·'다셔' - 나머지 동일)
# 여기서 고정하는 계약(설계·구현 리뷰 반영):
#   ① 순수 판정 Select-AbyssExitWord: 정확 일치 '나가기' 우선 → '나가' 포함 → $null ('가기' 기준 금지: '다른 던전 가기')
#   ② Invoke-AbyssExitClick: 규칙 4(조작 중 미소모·양보 뒤 재판독·전송 확인) / 규칙 15(캡처 실패 동결·안전 확인·시도 미소모,
#      동결 시간을 FrozenMs 로 반환 - 가상 시계로 생산까지 단언) / 위치·후속 화면 모두 없음이 3회 이상 + 첫
#      미검출부터 20초(동결·양보 제외 - 양보 제외는 2026-09-20 사후 구현 리뷰 P2) → 진단 캡처 + [완료] + exit 4 / 후속 화면: 필드(HUD + 추적기
#      던전명 없음 2연속) → 'gone' / 선택 화면 → 'selection'(워커가 연 화면인지 헬퍼는 모름 - 복귀 루프의 출처가 판정, ⑥e 설계 2.14·09-30 리뷰5) /
#      ESC 메뉴는 증거 아님(2026-09-21 설계 합의 A4) / 재매칭 패널 → 'matching'(설계 합의 A3) / 커서 미확인 3회 → 'skipped' / 후속 판정 도중 캡처 실패는 동결(미소모)
#      부모 마감(-ParentDeadline - ⑥e 설계 2.13, 09-30 리뷰4 P1-2): 판독 도중 캡처가 끊겼다 돌아오는 회전(같은 회전 복구·탐침 복구 뒤)만 이어지면
#      미검출 예산·20초 창에 닿지 않으므로 그 회전에서 부모의 조정 마감(양보·캡처 실패 차분)만 보고 넘으면 'expired' (2-11~2-15)
#   ③ 배선: 고정 좌표 클릭 0곳, 헬퍼 호출 5곳(복귀 루프 1 + 본류 3 + '다른 던전 가기' 끝 함수 1 - 모두 부모 마감 전달), 복구 루프는 헬퍼 FrozenMs 를 마감에 더하지 않음
#      (만료 판정이 캡처 실패 누적 차분이라 이중 가산 - ⑥e 설계 2.13), 부모 마감 분기 순서(양보 → 선택 화면 예외 → 조정 마감 → 300ms)
#   ④ ⑥a(2026-09-26 설계 합의): 헬퍼 패널 게이트 3종 - 재매칭 'matching' / 준비 패널 'ready-panel' / 접힌 준비 패널 'entry-waiting' 은 전부
#      클릭 0 (준비 패널 위 '나가기' 는 패널 닫기, 접힌 패널의 '나가기' 는 던전 퇴장 - 실기 -1), 파티원 보상 2버튼은 '나가기'@515 클릭.
#      옛 4절 '파티원 두 출구' 행동 진리표는 ⑥e(2026-09-30)에서 두 출구가 관측 루프 D·퇴장 절차 P 로 바뀌며 지웠습니다 - D·P 는 이 헬퍼를
#      쓰지 않고(커서가 가린 접힌 패널에서 (492,654) = 던전 퇴장을 누르는 헬퍼 - 09-29 재생), 행동은 tests\test_abyss_party_member.ps1 이 봅니다
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

# ── 운영 코드 추출 (사본 재구현 금지) ─────────────────────────────────────────
# 부모 마감 산술(⑥e 설계 2.13): 헬퍼의 복구 회전은 Get-FreezeAdjustedDeadline(양보 차분 + 캡처 실패 누적 차분)으로 부모 마감을 봅니다 - 운영 함수 그대로
foreach ($name in @('Get-YieldAdjustedDeadline', 'Get-FreezeAdjustedDeadline')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}
$defs = @{}
foreach ($name in @('Select-AbyssExitWord', 'Find-AbyssExitButtonPoint', 'Invoke-AbyssExitClick', 'Test-AbyssEntryWaitingText')) {
  $defs[$name] = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name))
}
Invoke-Expression $defs['Select-AbyssExitWord']
Invoke-Expression $defs['Find-AbyssExitButtonPoint']
Invoke-Expression $defs['Test-AbyssEntryWaitingText']   # 헬퍼가 같은 회전의 하단 판독문으로 접힌 준비 패널을 봄 (순수 판정 - 운영 코드 그대로)
# exit 4 는 테스트 프로세스를 죽이므로 '기록 뒤 반환'으로 치환
$clickDef = $defs['Invoke-AbyssExitClick']
Check-Equal '추출: 헬퍼 안 exit 4 는 정확히 1곳 (위치·후속 화면 미확인)' ([regex]::Matches($clickDef, '(?m)^\s*exit 4\s*$').Count) 1
$clickDef = $clickDef -replace '(?m)^(\s*)exit 4\s*$', '$1$script:exitCode = 4; return @{ Result = ''stopped''; FrozenMs = $frozenMs }'
Invoke-Expression $clickDef

# ── 1. 순수 판정 진리표 ─────────────────────────────────────────────────────────
function W { param([string]$Text, [int]$X, [int]$Y = 654) @{ Text = $Text; X = $X; Y = $Y } }
$captureS3 = @((W '아이템을' 533 591), (W '누르면' 582 591), (W '상세' 619 591), (W '정보테' 656 591), (W '볼' 686 591), (W '수' 703 591), (W '있습니다' 740 591),
  (W '나가기' 478), (W 'Space' 579 630), (W '다세' 615), (W '하기' 657), (W '다른' 759), (W '던전' 794), (W '가기' 829))
$captureS4 = @((W '아이템을' 533 591), (W '누르면' 582 591), (W '상세' 619 591), (W '정보로' 656 591), (W '볼' 686 591), (W '수' 703 591), (W '있습니다' 740 591),
  (W '나가기' 478), (W 'Space' 579 630), (W '다셔' 615), (W '하기' 657), (W '다른' 759), (W '던전' 794), (W '가기' 829))
$oldSingle = @((W '아이템을' 533 591), (W '나가기' 636))                                   # 옛 1버튼 배치 - 그대로 동작해야 함
$splitNaga = @((W '나가' 470), (W '기' 500), (W '다세' 615), (W '하기' 657))                # '나가'+'기' 로 쪼개짐 → '나가' 채택
$splitNa = @((W '나' 460), (W '가기' 490), (W '다세' 615), (W '하기' 657), (W '가기' 829))  # '나'+'가기' → 선택 불가 ('가기' 금지)
$noExit = @((W '다세' 615), (W '하기' 657), (W '다른' 759), (W '던전' 794), (W '가기' 829))  # 나가기 없음
$partialThenExact = @((W '나가는' 300), (W '나가기' 478))                                   # 앞에 부분 일치, 뒤에 정확 일치 → 정확 일치가 이김
function Pick { param($Words) $w = Select-AbyssExitWord -Words $Words; if ($w) { "$($w.X),$($w.Y)" } else { 'null' } }
Check-Equal '판정: 09-18 캡처 배율 3 → 나가기 (478,654)' (Pick $captureS3) '478,654'
Check-Equal '판정: 09-18 캡처 배율 4 → 나가기 (478,654)' (Pick $captureS4) '478,654'
Check-Equal '판정: 옛 1버튼 배치 → 중앙 나가기 (636,654)' (Pick $oldSingle) '636,654'
Check-Equal "판정: '나가'+'기' 분리 → '나가' 채택" (Pick $splitNaga) '470,654'
Check-Equal "판정: '나'+'가기' 분리 → 선택 불가 ('가기' 는 다른 던전 가기에도 있음)" (Pick $splitNa) 'null'
Check-Equal '판정: 나가기 없음(다시 하기·다른 던전 가기만) → null' (Pick $noExit) 'null'
Check-Equal '판정: 부분 일치가 앞에 있어도 정확 일치가 이김 (변이 검증 대상)' (Pick $partialThenExact) '478,654'
Check-Equal '판정: 빈 목록 → null' (Pick @()) 'null'
Check-Equal '판정: 636 (다시 하기 자리) 는 어느 케이스에서도 채택되지 않음' ((@((Pick $captureS3), (Pick $captureS4), (Pick $noExit), (Pick $splitNa)) | Where-Object { $_ -like '636,*' }).Count) 0

# ── 2. 헬퍼 모의 실행 ───────────────────────────────────────────────────────────
# 가상 시계: 헬퍼의 Get-Date 는 이 시계를 읽고, 모의 Start-Sleep 이 시계를 전진시킵니다 - 동결 시간(FrozenMs)과
# 20초 미검출 기준이 실제로 '생산'되는지까지 단언하기 위해서입니다 (test_yield_batch 의 $vclock 선례)
$game = $null
$rgClearExit = @(430, 570, 420, 125); $ocrKoreanEngine = 'ko'
function Get-Date { return $script:vclock }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) $script:vclock = $script:vclock.AddMilliseconds($Milliseconds + $Seconds * 1000) }
# 판독 모의의 실패·성공 등록은 이 두 함수로 모읍니다 - 운영 계약(Register-CaptureFailure / Register-CaptureSuccess / Get-CaptureFailTotalMs)과 같이
# 실패 시작 시각과 누적을 남겨, 부모 마감(Get-FreezeAdjustedDeadline)이 실패 시간을 빼는 산술까지 실제로 돌립니다 (⑥e 설계 5.2).
# -SlowMs: 실패를 등록한 뒤 그만큼 가상 시계를 흘림(느린 실패) - 새 모드(2-11~2-15)는 1초, 기존 'capfail'·selectionFailOnce 주입은 0초
# (2-2·2-7 의 FrozenMs 1400 이 그대로이려면 기존 주입은 시간을 흘리지 않아야 함 - 반영본 검증, 09-30 리뷰4)
function Register-Fail { param([int]$SlowMs = 0)
  $script:captureFailSerial++
  if (-not $script:screenCaptureFailing) { $script:screenCaptureFailing = $true; $script:failSince = $script:vclock }
  if ($SlowMs -gt 0) { $script:vclock = $script:vclock.AddMilliseconds($SlowMs) }
}
function Register-Success {
  if ($script:screenCaptureFailing) { $script:failTotalMs += ($script:vclock - $script:failSince).TotalMilliseconds; $script:screenCaptureFailing = $false; $script:failSince = $null }
}
function Get-CaptureFailTotalMs {
  $total = [double]$script:failTotalMs
  if ($script:screenCaptureFailing -and $null -ne $script:failSince) { $total += ($script:vclock - $script:failSince).TotalMilliseconds }
  return $total
}
function Focus-Game { param($Game) }
function Test-SafeStopDuringCaptureFail { $script:safeStopCalls++ }
function Write-RunLog { param([string]$Message) $script:logs += $Message }
function Write-LifeDiagnostics { param($Game, $Context, [switch]$CaptureOnly) $script:diagCalls++; $script:diagContext = $Context; $script:diagCaptureOnly = [bool]$CaptureOnly }
function Next-Seq { param([string]$Name, $Default)
  $seq = Get-Variable -Name ($Name + 'Seq') -Scope Script -ValueOnly
  $idx = Get-Variable -Name ($Name + 'Idx') -Scope Script -ValueOnly
  if ($idx -lt $seq.Count) { Set-Variable -Name ($Name + 'Idx') -Scope Script -Value ($idx + 1); return $seq[$idx] }
  return $Default
}
function Get-GameRegionOcrWords { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine)
  $script:readCalls++; $script:readRegion = "$ReferenceX,$ReferenceY,$RegionWidth,$RegionHeight/$Scale/$Engine"
  # 호출 상한 (⑥e 설계 5.2): 부모 마감을 못 보는 변이는 이 하단 판독을 끝없이 돌리므로 케이스당 20000회에서 끊어 FAIL 로 끝냅니다 (러너 정지 방지)
  if ($script:readCalls -gt 20000) { throw '__VTIMEOUT__' }
  $r = Next-Seq 'words' 'default'
  if ("$r" -eq 'capfail') { Register-Fail; return @() }     # 캡처 실패 = 플래그·일련번호·실패 시작 시각 (Register-CaptureFailure 계약)
  Register-Success                                          # 캡처 성공 = 플래그 해제·실패 구간 누적 (Register-CaptureSuccess 계약)
  if ("$r" -eq 'default') { return $script:defaultWords }
  if ("$r" -eq 'empty') { return @() }                                               # 캡처 성공·단어 0개 (판독 '')
  return $r
}
function Test-UserRecentlyActive { return [bool](Next-Seq 'active' $false) }
function Wait-UserYieldEnd { param($Game, $Context) $script:yieldWaits++; $script:yieldContexts += $Context; $script:vclock = $script:vclock.AddSeconds($script:yieldSeconds); $script:userYieldTotalMs += $script:yieldSeconds * 1000 }   # 양보 N초(기본 5) - 실제처럼 $script:userYieldTotalMs 에 누적 (사후 리뷰 P3: 모의 충실도. FrozenMs 에 섞이면 안 됨)
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY)
  $script:clickPoints += "$ReferenceX,$ReferenceY"
  $r = Next-Seq 'send' 'sent'
  $script:lastClickPerformed = ($r -eq 'sent'); $script:lastClickSkipReason = $(if ($r -eq 'sent') { '' } else { $r })
  if ($r -eq 'sent') { $script:clicksSent++ }
}
# 후속 판정 모의는 실제처럼 **판독 성공이 캡처 실패 플래그를 풉니다** (Register-CaptureSuccess 계약 - 2026-09-21 구현 리뷰 P3:
# 이 부작용이 없으면 '실패 뒤 다른 판독 성공이 플래그를 풀어 실패 회전이 소모되는' 결함(P2)이 모의에서 안 보임)
# 새 모의 모드 셋 (⑥e 설계 5.2 - 부모 마감):
#   'selFail'     = 선택 화면 판독 영구 실패(1초) → 같은 회전의 HUD 판독이 복구 (같은 회전 복구 - 2-11·2-14)
#   'panelFail'   = 패널 판독 영구 실패(1초) → 다음 회전 하단 판독이 복구 (교대 - 2-12)
#   'selSameCall' = 선택 화면 판정 안에서 실패 등록(1초) 뒤 같은 판정이 복구해 참 (카드 판독 실패 → 제목·배제 성공의 모양 - 2-15, 반영본 검증)
#   'selSameCallOnce' = 첫 판정만 'selSameCall', 다음부터 실패 없이 참 (2-15 대조 - 부모 마감 없는 호출)
function Test-AbyssSelectionScreen { param($Game) $script:successorChecks++
  if ($script:selectionFailOnce) { $script:selectionFailOnce = $false; Register-Fail; return $false }   # 후속 판정 도중 캡처 실패 (0초 - 기존 주입)
  if ($script:mode -eq 'selFail') { Register-Fail -SlowMs 1000; return $false }
  if ($script:mode -eq 'selSameCall') { Register-Fail -SlowMs 1000; Register-Success; return $true }
  if ($script:mode -eq 'selSameCallOnce') { $script:mode = 'selVisible'; Register-Fail -SlowMs 1000; Register-Success; return $true }
  Register-Success
  if ($script:mode -eq 'selVisible') { return $true }
  return $script:selectionVisible }
function Test-HomeEndEscHud { param($Game) $script:successorChecks++; Register-Success; return [bool](Next-Seq 'hud' $script:hudVisible) }   # 회전별 수열(HudSeq)이 있으면 그 값, 없으면 고정값
function Test-AbyssMenu { param($Game) $script:successorChecks++; Register-Success; return $script:menuVisible }
function Get-AbyssPanelKind { param($Game) $script:successorChecks++   # 패널 종류 (재매칭 2026-09-21 / 준비 ⑥a)
  if ($script:mode -eq 'panelFail') { Register-Fail -SlowMs 1000; return 'none' }
  Register-Success
  if ($script:readyVisible) { return 'ready' }
  if ($script:matchingVisible) { return 'matching' }
  return 'none' }
function Test-InDungeonQuest { param($Game) $script:successorChecks++; Register-Success; return $script:questVisible }         # 추적기 던전명 (필드 부정 증거)
function Reset-Case {
  param($WordsSeq = @(), $ActiveSeq = @(), $SendSeq = @(), $DefaultWords = $null, $HudSeq = @())
  $script:wordsSeq = @($WordsSeq); $script:wordsIdx = 0
  $script:activeSeq = @($ActiveSeq); $script:activeIdx = 0
  $script:sendSeq = @($SendSeq); $script:sendIdx = 0
  $script:hudSeq = @($HudSeq); $script:hudIdx = 0
  $script:defaultWords = $(if ($null -ne $DefaultWords) { $DefaultWords } else { $captureS3 })
  $script:vclock = [datetime]'2026-09-18 21:00:00'
  $script:logs = @(); $script:yieldWaits = 0; $script:yieldContexts = @(); $script:clicksSent = 0; $script:clickPoints = @()
  $script:readCalls = 0; $script:readRegion = ''; $script:safeStopCalls = 0; $script:successorChecks = 0
  $script:diagCalls = 0; $script:diagContext = ''; $script:diagCaptureOnly = $null; $script:exitCode = $null
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타 - 오발동 없어야 함
  $script:screenCaptureFailing = $false
  $script:selectionVisible = $false; $script:hudVisible = $false; $script:menuVisible = $false; $script:selectionFailOnce = $false
  $script:yieldSeconds = 5; $script:userYieldTotalMs = [double]0
  $script:matchingVisible = $false; $script:questVisible = $false; $script:readyVisible = $false
  $script:captureFailSerial = 0; $script:failSince = $null; $script:failTotalMs = [double]0
  $script:mode = ''; $script:startClock = $script:vclock; $script:threw = ''
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }
# 부모 마감(-ParentDeadline)은 새 케이스(2-11~2-15)만 넘깁니다 - 기존 케이스는 인자 없는 호출(헬퍼 옛 경로 그대로 - ⑥e 설계 2.13 호출부 전수 표).
# 호출 상한 센티널('__VTIMEOUT__')은 여기서 받아 결과 'THREW' 로 돌려 FAIL 로 끝냅니다
function Run-Click { param([string]$Context = '나가기 클릭', $Parent = $null)
  try {
    if ($null -ne $Parent) { Invoke-AbyssExitClick -Game $game -LogPrefix '[어비스]' -Context $Context -ParentDeadline $Parent }
    else { Invoke-AbyssExitClick -Game $game -LogPrefix '[어비스]' -Context $Context }
  } catch { $script:threw = $_.Exception.Message; @{ Result = 'THREW'; FrozenMs = -1 } }
}
# (가상 경과 − 누적 캡처 실패 − 누적 양보) 초 - 부모 마감 60초가 실패·양보를 뺀 시간으로 흐르는지 봅니다
function Adj { [math]::Round(((($script:vclock - $script:startClock).TotalMilliseconds - $script:failTotalMs - $script:userYieldTotalMs) / 1000.0), 2) }
# (주의) 큰따옴표 문자열 안의 $( ) 에 괄호가 든 따옴표 문자열을 넣으면 PS 5.1 파서가 하위식 끝을 못 찾습니다 - 패턴 개수는 변수로 미리 셉니다

# 2-1. 기준: 3버튼 화면 → 나가기 글자 위치 클릭 1회 전송
Reset-Case
$r = Run-Click
Check-Equal '기준: clicked, 클릭 지점 = 나가기 (478,654), 판독 1회, 양보 0' ("$($r.Result)/$($script:clickPoints -join ';')/$($script:readCalls)/$($script:yieldWaits)") 'clicked/478,654/1/0'
Check-Equal '기준: 잔존 메타(user-active)가 양보를 오발동하지 않음 + 클릭 로그에 기준좌표' ("$($script:yieldWaits)/$((Count-Log '나가기 클릭 - 글자 탐색 기준좌표 \(478,654\)'))") '0/1'
Check-Equal '기준: 판독 영역·배율·엔진이 Test-ExitButton 과 동일 (clearAndExitText, 3, ko)' $script:readRegion '430,570,420,125/3/ko'
Check-Equal '기준: FrozenMs 0 (캡처 실패 없음)' ([int]$r.FrozenMs) 0

# 2-2. 규칙 15: 캡처 실패 2회 → 안전 확인 2회·시도 미소모 → 복구 뒤 클릭. 실패 중엔 후속 화면 판정도 안 함. FrozenMs = 700ms×2
Reset-Case -WordsSeq @('capfail', 'capfail', $captureS3)
$r = Run-Click
Check-Equal '캡처 실패 2회: 안전 확인 2회, 판독 3회(회전마다 캡처 시도), 클릭 1회, 재판독 소모 0' ("$($script:safeStopCalls)/$($script:readCalls)/$($script:clicksSent)/$((Count-Log '재판독'))") '2/3/1/0'
Check-Equal '캡처 실패 2회: 실패 중 후속 화면 판정 0회 (정상 회전의 재매칭 패널 확인 1회만), 결과 clicked' ("$($script:successorChecks)/$($r.Result)") '1/clicked'
Check-Equal '캡처 실패 2회: FrozenMs = 1400 (동결 회전 700ms×2 - 부모 마감 연장 근거가 실제로 생산됨)' ([int]$r.FrozenMs) 1400

# 2-3. 규칙 4: 클릭 전 조작 감지 → 양보 → **다시 읽은** 좌표로 클릭 (옛 좌표 재클릭 금지). 양보 시간은 FrozenMs 에 안 섞임
$movedS3 = @((W '나가기' 480), (W '다세' 617), (W '하기' 659))
Reset-Case -WordsSeq @($captureS3, $movedS3) -ActiveSeq @($true, $false)
$r = Run-Click
Check-Equal '조작 중: 양보 1회 → 재판독 → 새 좌표 (480,654) 클릭 (첫 판독 478 재클릭 없음)' ("$($script:yieldWaits)/$($script:readCalls)/$($script:clickPoints -join ';')") '1/2/480,654'
Check-Equal '조작 중: 양보 5초는 FrozenMs 에 가산되지 않음 (중복 가산 금지)' ([int]$r.FrozenMs) 0

#    2-3b. ★ 사후 구현 리뷰 P2(2026-09-20): 미검출 사이의 양보 시간은 20초 미검출 창을 소모하지 않음.
#    미검출(0s) → 조작 감지 → 양보 30초 → 미검출(경과 31-30=1s) → … 경과 20s 인 21번째 미검출에서 정지 = 판독 22회(양보 회전 1 포함).
#    양보를 빼지 않으면 세 번째 미검출(실시간 32초)에서 즉시 정지 = 판독 4회 (변이 검증 대상)
Reset-Case -DefaultWords $noExit -ActiveSeq @($false, $true)
$script:yieldSeconds = 30
$r = Run-Click
$thirdMissLog = Count-Log '재판독 \(3회, 2초'
Check-Equal '양보 30초 교차: 판독 22회(미검출 21 + 양보 회전 1), 양보 1, exit 4, 세 번째 미검출 경과 2초(양보 제외)' ("$($script:readCalls)/$($script:yieldWaits)/$($script:exitCode)/$thirdMissLog") '22/1/4/1'

# 2-4. 규칙 4: 클릭이 조작으로 생략(user-active) → 양보 → 재판독 → 전송. 예산 미소모
Reset-Case -SendSeq @('user-active', 'sent')
$r = Run-Click
Check-Equal '클릭 생략(조작): 양보 1회, 판독 2회, 전송 1회, clicked, 커서 미확인 카운트 0' ("$($script:yieldWaits)/$($script:readCalls)/$($script:clicksSent)/$($r.Result)/$((Count-Log '커서 미확인'))") '1/2/1/clicked/0'

# 2-5. 커서 미확인 3회 → skipped (호출부 복귀 루프가 담당), 전송 0
Reset-Case -SendSeq @('cursor-not-ready', 'cursor-not-ready', 'cursor-not-ready')
$r = Run-Click
Check-Equal '커서 미확인 3회: skipped, 전송 0, 안내 1, exit 없음' ("$($r.Result)/$($script:clicksSent)/$((Count-Log '커서 미확인으로 3회'))/$($script:exitCode)") 'skipped/0/1/'
#    2-5b. 커서 미확인과 조작 생략이 섞임 → 조작은 커서 예산을 소모하지 않고, 커서 카운트는 양보 회전을 넘어 유지
Reset-Case -SendSeq @('cursor-not-ready', 'user-active', 'cursor-not-ready', 'cursor-not-ready')
$r = Run-Click
$cursorSkipLogs = Count-Log '건너뜀 \(커서 미확인'
Check-Equal '커서·조작 혼합: skipped, 양보 1, 커서 건너뜀 로그 3, 전송 0' ("$($r.Result)/$($script:yieldWaits)/$cursorSkipLogs/$($script:clicksSent)") 'skipped/1/3/0'

# 2-6. ★ 핵심: 위치도 후속 화면도 없음(캡처 성공)이 3회 이상 + 20초 → 진단 캡처 + [완료] + exit 4, 클릭 0 (고정 좌표 폴백 없음)
#    미검출 회전은 1초 간격 → 첫 미검출(0초)부터 20초가 되는 21번째 판독에서 정지
Reset-Case -DefaultWords $noExit
$r = Run-Click
$rereadLogs = Count-Log '재판독 \('
Check-Equal '미검출: exit 4, 클릭 0, 판독 21회(20초), 재판독 로그 21' ("$($script:exitCode)/$($script:clicksSent)/$($script:readCalls)/$rereadLogs") '4/0/21/21'
$stopReasonLogs = Count-Log "재입장 오클릭\('다시 하기' 자리\)"
Check-Equal '미검출: 진단 캡처 1회(CaptureOnly, 문맥) + 정지 사유가 재입장 오클릭' ("$($script:diagCalls)/$($script:diagContext)/$($script:diagCaptureOnly)/$stopReasonLogs") '1/어비스 나가기 위치 미발견/True/1'
Check-Equal '미검출: 판독문이 로그에 남음 (다음 진리표 재료)' ((Count-Log "판독: '다세하기다른던전가기'")) 22
Check-Equal '미검출: 마지막 재판독 로그에 횟수·초가 찍힘 (PS 5.1 ${missCount}회 - 사후 리뷰 P3: $missCount회 는 빈 변수)' ((Count-Log '재판독 \(21회, 20초')) 1
#    2-6b. 3회는 됐지만 20초가 안 됐으면 정지하지 않음: 미검출 3회 뒤 나가기가 다시 보이면 클릭 (페이드 중 판독 공백 허용)
Reset-Case -WordsSeq @($noExit, $noExit, $noExit, $captureS3)
$r = Run-Click
Check-Equal '미검출 3회 뒤 재출현: 정지 없이 클릭 (시간 기준 - 전이 중 판독 공백을 정지로 오판하지 않음)' ("$($r.Result)/$($script:exitCode)/$($script:clicksSent)") 'clicked//1'

# 2-7. 규칙 15: 미검출 사이에 캡처 실패가 끼어도 실패 회전은 소모하지 않고 20초 기준에서도 동결 시간을 뺌
#    판독: noExit(0s) capfail(→0.7s, 동결 0.7) noExit(경과 1.7-0.7=1.0) capfail(→2.4, 동결 1.4) noExit(경과 3.4-1.4=2.0) … 경과 20 = 미검출 21회 → 판독 23회
Reset-Case -WordsSeq @($noExit, 'capfail', $noExit, 'capfail', $noExit) -DefaultWords $noExit
$r = Run-Click
Check-Equal '미검출+캡처 실패 교차: 판독 23회(미검출 21 + 실패 2), 안전 확인 2회, exit 4, FrozenMs 1400' ("$($script:readCalls)/$($script:safeStopCalls)/$($script:exitCode)/$([int]$r.FrozenMs)") '23/2/4/1400'
#    2-7b. 후속 화면 판정 도중 캡처 실패 → 뒤의 HUD 판독 성공이 플래그를 풀어도 **그 회전은 폐기**(미검출 미소모, 화면은 돌아왔으니
#    동결 아님 - 안전 확인 0·FrozenMs 0), 다음 회전에 정상 판독 → 클릭 (2026-09-21 구현 리뷰 P2: 일련번호로 '실패가 있던 회전' 판정)
Reset-Case -WordsSeq @($noExit, $captureS3)
$script:selectionFailOnce = $true
$r = Run-Click
Check-Equal '후속 판정 중 캡처 실패(뒤 판독 성공): 회전 폐기 - 재판독 소모 0, 안전 확인 0, 다음 회전 clicked, FrozenMs 0' ("$((Count-Log '재판독'))/$($script:safeStopCalls)/$($r.Result)/$([int]$r.FrozenMs)") '0/0/clicked/0'
#    2-7c. 양보 뒤에는 필드 증거 연속도 새로 셉니다 (구현 리뷰 P1: 양보 중 재입장하면 옛 필드 1회 + 새 판독 1회로 gone 이 나옴)
#    필드(0s, 연속 1) → 조작 감지 → 양보 → 필드(연속 1 - 리셋) → 필드(연속 2) → gone = 판독 4회 (리셋 없으면 3회)
Reset-Case -DefaultWords $noExit -ActiveSeq @($false, $true)
$script:hudVisible = $true
$r = Run-Click
Check-Equal '양보 뒤 필드 연속 리셋: 판독 4회 뒤 gone (양보 1)' ("$($r.Result)/$($script:readCalls)/$($script:yieldWaits)") 'gone/4/1'
#    2-7d. ★ 구현 리뷰 2차 P2(2026-09-21): 실패가 있던 회전의 필드 표본은 연속 수에 들어가지 않음 - 옛 코드는 HUD 판독 직후 올린 뒤
#    일련번호 검사로 회전을 버려 '폐기 회전 1 + 정상 회전 1' 로 gone 이 났음. 선택 화면 판독 실패(→ 뒤 HUD 성공이 플래그 해제) →
#    회전 폐기(연속 0 유지) → 필드(1) → 필드(2) → gone = 판독 3회 (옛 코드 2회 - 변이 검증 대상)
Reset-Case -DefaultWords $noExit
$script:hudVisible = $true; $script:selectionFailOnce = $true
$r = Run-Click
Check-Equal '실패 회전의 필드 표본 미계수: gone 은 판독 3회째, 재판독 로그 1' ("$($r.Result)/$($script:readCalls)/$((Count-Log '재판독'))") 'gone/3/1'
#    2-7e. 같은 P2: 필드 표본이 아닌 유효 회전(HUD 없음 - 로딩·선택 화면·나가기 재출현)은 연속 수를 0 으로 - 떨어진 두 표본은 '2연속' 이 아님
#    필드(1) → HUD 없음(0) → 필드(1) → 필드(2) → gone = 판독 4회 (옛 코드는 3회째 gone)
Reset-Case -DefaultWords $noExit -HudSeq @($true, $false, $true, $true)
$r = Run-Click
Check-Equal '비증거 회전의 연속 리셋: gone 은 판독 4회째, 재판독 로그 3' ("$($r.Result)/$($script:readCalls)/$((Count-Log '재판독'))") 'gone/4/3'

# 2-8. 후속 화면 확인 (사용자가 이미 눌렀거나 전환), 클릭 0, 정지 없음. 필드(HUD + 추적기 던전명 없음 2연속) → gone.
#      ESC 메뉴는 2026-09-21 부터 증거가 아님 (상세 헤더 오탐 + 던전 안에서도 열리는 메뉴 - 09-20 실사고, 설계 합의 A4)
#      ★ 뒤집음(⑥e 설계 2.14 - 09-30 리뷰5 P1-1): 선택 화면은 'gone' 이 아니라 'selection' - 헬퍼는 메뉴를 열지 않아 출처를 가질 수 없고
#      선택 화면 양성은 던전 밖의 증명이 아닙니다(던전 안 오버레이 프레임 S1·O3 재생에서 옛 헬퍼는 'gone'). 판정은 복귀 루프의 출처 규칙이 합니다
Reset-Case -DefaultWords $noExit
$script:selectionVisible = $true
$r = Run-Click
$goneLogs = Count-Log '선택 화면 이\(가\) 확인돼 클릭 없이'
$selectionLogs = Count-Log '워커가 연 화면인지 알 수 없어'
Check-Equal '후속 화면(선택 화면): selection, 클릭 0, exit 없음, 안내 로그 1, 옛 gone 로그 0' ("$($r.Result)/$($script:clicksSent)/$($script:exitCode)/$selectionLogs/$goneLogs") 'selection/0//1/0'
Reset-Case -DefaultWords $noExit
$script:hudVisible = $true
$r = Run-Click
Check-Equal '후속 화면(필드 HUD, 추적기 없음): 2연속 뒤 gone - 판독 2회, 첫 회전은 미검출로 셈' ("$($r.Result)/$($script:readCalls)/$((Count-Log '필드 HUD'))") 'gone/2/1'
Reset-Case -DefaultWords $noExit
$script:hudVisible = $true; $script:questVisible = $true
$r = Run-Click
Check-Equal '던전 안(HUD + 추적기 던전명): gone 아님 - 미검출 정지 경로 (exit 4, 클릭 0, 필드 로그 0)' ("$($script:exitCode)/$($script:clicksSent)/$((Count-Log '필드 HUD'))") '4/0/0'
Reset-Case -DefaultWords $noExit
$script:menuVisible = $true
$r = Run-Click
Check-Equal 'ESC 메뉴만 보임: gone 아님 - 미검출 정지 경로 (메뉴는 증거에서 제외)' ("$($script:exitCode)/$($script:clicksSent)/$((Count-Log 'ESC 메뉴'))") '4/0/0'
Reset-Case -DefaultWords $noExit
$script:selectionVisible = $true; $script:hudVisible = $true
$r = Run-Click
# ★ 뒤집음(⑥e 설계 2.14): 선택 화면이 먼저라는 판정 순서의 뜻은 그대로 - 결과가 'gone' 대신 'selection'
$bothSelectionLogs = Count-Log '어비스 선택 화면이 보입니다'
Check-Equal '판정 순서: 선택 화면 + 필드 HUD 동시 → selection (선택 화면이 먼저 - 사후 리뷰 P3 HUD 우선 변이 검출), 필드 HUD 로그 0' ("$($r.Result)/$bothSelectionLogs/$((Count-Log '필드 HUD'))") 'selection/1/0'
#    2-8b. 재매칭 패널 ('다시 하기' 뒤 - 09-18 실측): 나가기 위치는 보이지만 그 버튼은 매칭 취소 → 'matching', 클릭 0 (설계 합의 A3)
Reset-Case
$script:matchingVisible = $true
$r = Run-Click
Check-Equal '재매칭 패널: matching 반환, 클릭 0, exit 없음, 안내 로그' ("$($r.Result)/$($script:clicksSent)/$($script:exitCode)/$((Count-Log '매칭 취소 버튼입니다'))") 'matching/0//1'
#    2-8c. 구현 리뷰 2차 P2(2026-09-21): '나가기' 조각이 빠진 패널 프레임(09-18 실측 4/4 프레임 - 진리표 $panelExit2)도 matching -
#    옛 코드는 위치가 있을 때만 패널을 봐서 미검출 3회·20초 뒤 코드 4 로 정지했음
Reset-Case -DefaultWords $noExit
$script:matchingVisible = $true
$r = Run-Click
Check-Equal "재매칭 패널('나가기' 없는 프레임): matching, 클릭 0, exit 없음, 판독 1회" ("$($r.Result)/$($script:clicksSent)/$($script:exitCode)/$($script:readCalls)") 'matching/0//1'

#    2-8d. ⑥a 준비 패널: 보상 위 준비 패널 첫 프레임(09-21 D1b)은 하단 '나가기'@492 가 같이 읽힘 - 그 '나가기' 는 패널 닫기라 누르지 않음
$wordsD1b = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '모든' 839 610), (W '나가기' 492))
Reset-Case -DefaultWords $wordsD1b
$script:readyVisible = $true
$r = Run-Click
Check-Equal "준비 패널(D1b '나가기'@492 공존): ready-panel, 클릭 0, exit 없음, 판독 1회, 안내 로그" ("$($r.Result)/$($script:clicksSent)/$($script:exitCode)/$($script:readCalls)/$((Count-Log '패널 닫기입니다'))") 'ready-panel/0//1/1'
#    2-8e. 준비 패널에 '나가기' 조각이 없는 프레임(실기 -1 M2+1)도 미검출로 세지 않고 ready-panel
$wordsM2p1 = @((W '0田I들1을' 530 591), (W '누르면' 581 591), (W '&)dl' 618 591), (W '정보를' 656 591), (W 'Space' 744 630), (W '모든' 839 597))
Reset-Case -DefaultWords $wordsM2p1
$script:readyVisible = $true
$r = Run-Click
Check-Equal "준비 패널('나가기' 없는 M2+1): ready-panel, 클릭 0, 재판독 로그 0" ("$($r.Result)/$($script:clicksSent)/$((Count-Log '재판독'))") 'ready-panel/0/0'
#    2-8f. ⑥a 접힌 준비 패널(실기 -1 L5f): 패널 영역은 비어 종류 'none' - 하단 '나가기'@492 + '입장 대기 중' → 그 '나가기' 는 던전 퇴장이라 누르지 않음
$wordsL5f = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591),
  (W '나가기' 492), (W '입장' 700), (W '대기' 743), (W '중' 776))
Reset-Case -DefaultWords $wordsL5f
$r = Run-Click
Check-Equal "접힌 준비 패널(L5f): entry-waiting, 클릭 0, exit 없음, 판독 1회, 안내 로그" ("$($r.Result)/$($script:clicksSent)/$($script:exitCode)/$($script:readCalls)/$((Count-Log '던전 퇴장입니다'))") 'entry-waiting/0//1/1'
#    2-8g. 커서가 '입장' 을 가린 프레임(M4-pre '나가기'@492 + '자대기중'@744)도 entry-waiting ('대기중' 조각 - '입장대기' 는 이렇게 깨짐)
$wordsM4pre = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 492), (W '자대기중' 744))
Reset-Case -DefaultWords $wordsM4pre
$r = Run-Click
Check-Equal "접힌 준비 패널(M4-pre 커서 가림): entry-waiting, 클릭 0" ("$($r.Result)/$($script:clicksSent)") 'entry-waiting/0'
#    2-8h. ⑥a 파티원 보상 2버튼(M5r '나가기'@515 + '파티장 선택 대기'): 패널 아님 → '나가기'@515 클릭 (옛 파티원 사이클의 마무리 클릭)
$wordsM5r = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591),
  (W '나가기' 515), (W '파티장' 714), (W '선택' 765), (W '대기' 808))
Reset-Case -DefaultWords $wordsM5r
$r = Run-Click -Context '나가기 클릭'
Check-Equal '파티원 보상(M5r): clicked, 클릭 지점 = 나가기 (515,654), 판독 1회' ("$($r.Result)/$($script:clickPoints -join ';')/$($script:readCalls)") 'clicked/515,654/1'
#    2-8i. 준비 패널이 재매칭 패널보다 먼저 (Get-AbyssPanelKind 가 'ready' 를 먼저 돌려줌 - 두 서명은 실측 상호 배타라 순서는 방어가 아니라 명시)
Reset-Case -DefaultWords $wordsD1b
$script:readyVisible = $true; $script:matchingVisible = $true
$r = Run-Click
Check-Equal '준비·재매칭 동시(모의): ready-panel 우선, 클릭 0' ("$($r.Result)/$($script:clicksSent)") 'ready-panel/0'

# 2-9. 위치 선택 불가('나'+'가기')도 미검출과 같은 정지 경로 - '가기' 로 다른 던전 가기를 누르지 않음
Reset-Case -DefaultWords $splitNa
$r = Run-Click
Check-Equal "위치 선택 불가('나'+'가기'): exit 4, 클릭 0" ("$($script:exitCode)/$($script:clicksSent)") '4/0'
#    2-9b. 캡처 성공·단어 0개(판독 '') 도 같은 정지 경로, 판독문 '' 이 로그에 남음
Reset-Case -WordsSeq @('empty') -DefaultWords @()
$r = Run-Click
$emptyLogs = Count-Log "판독: ''"
Check-Equal "빈 판독: exit 4, 클릭 0, 판독문 '' 기록" ("$($script:exitCode)/$($script:clicksSent)/$([int]($emptyLogs -ge 1))") '4/0/1'

# 2-10. 후속 화면이 있어도 나가기 위치가 보이면 클릭이 우선 (보상 화면 + ESC 메뉴 오탐 공존 시 나가기 전송)
Reset-Case
$script:menuVisible = $true
$r = Run-Click
Check-Equal '나가기 보임 + 메뉴 오탐: 후속 판정 없이 클릭 (재매칭 패널 확인 1회만 - successorChecks 1)' ("$($r.Result)/$($script:successorChecks)/$($script:clicksSent)") 'clicked/1/1'

# ── 2-11~2-15. 부모 마감 (⑥e 설계 2.13 - 09-30 리뷰4 P1-2 · 반영본 검증 · 09-30 리뷰5) ─────────────────────────────
# 판독 도중 캡처가 끊겼다 돌아오는 회전(같은 회전 복구·탐침 복구 뒤)은 미검출 예산·20초 창을 쓰지 않아(규칙 15 - 실패 회전은 소모 안 함),
# 그 모양이 이어지면 옛 헬퍼는 끝나지 않았습니다(미관측 - 종료 보장 확인). 부모 마감을 준 호출은 그 회전에서만 부모의 조정 마감을 보고
# 넘으면 'expired'(클릭 0) - 조작 중에는 확정하지 않고(규칙 4), 선택 화면 양성은 'expired' 보다 먼저 'selection' 으로 넘깁니다.
# 2-11. 같은 회전 복구 영구: 하단 위치 없음·패널 none·선택 화면 판독 실패(1초) → HUD 판독 복구. 부모 마감 = 가상 시작 + 60초
Reset-Case -DefaultWords $noExit
$script:mode = 'selFail'
$r = Run-Click -Parent ($script:vclock.AddSeconds(60))
$reads211 = $script:readCalls
Check-Equal '2-11 같은 회전 복구 영구: expired, 클릭 0, 재판독(미검출) 로그 0, exit 4 없음, 안전 확인 0, throw 없음' ("$($r.Result)/$($script:clicksSent)/$((Count-Log '재판독'))/$($script:exitCode)/$($script:safeStopCalls)/$($script:threw)") 'expired/0/0//0/'
Check-Equal ('2-11 하단 판독 약 200회(= 60 / 0.3 ± 2 - 호출 상한 없이 유한, 실제 ' + $reads211 + '회), (가상 경과 − 누적 실패) = 60 ± 0.3초 (실제 ' + (Adj) + ')') ("$([int]([math]::Abs($reads211 - 200) -le 2))/$([int]([math]::Abs((Adj) - 60) -le 0.3))") '1/1'
# 2-12. 교대 영구: 하단 위치 있음($captureS3)·패널 판독 실패(1초) → 동결 분기 → 다음 회전 하단 판독이 복구(탐침 복구 뒤 회전 = 복구 회전)
Reset-Case -DefaultWords $captureS3
$script:mode = 'panelFail'
$r = Run-Click -Parent ($script:vclock.AddSeconds(60))
$reads212 = $script:readCalls
Check-Equal '2-12 교대 영구: expired, 클릭 0, 안전 확인 = 동결 분기 수(1 이상 - 회전 둘에 하나), throw 없음' ("$($r.Result)/$($script:clicksSent)/$([int]($script:safeStopCalls -ge 1 -and [math]::Abs($script:safeStopCalls * 2 - $reads212) -le 2))/$($script:threw)") 'expired/0/1/'
Check-Equal ('2-12 하단 판독 약 400회(실제 ' + $reads212 + '회), (가상 경과 − 누적 실패) = 60 ± 0.3초 (실제 ' + (Adj) + ')') ("$([int]([math]::Abs($reads212 - 400) -le 2))/$([int]([math]::Abs((Adj) - 60) -le 0.3))") '1/1'
# 2-13. 부모 마감이 이미 지난 값이어도 유효 회전(2-1 기준 배치)은 클릭 - 부모 마감은 복구 회전에서만 봅니다
Reset-Case
$r = Run-Click -Parent ($script:vclock.AddSeconds(-1))
Check-Equal '2-13 지난 부모 마감 + 유효 회전: clicked, 판독 1회, expired 아님' ("$($r.Result)/$($script:readCalls)") 'clicked/1'
# 2-14. 2-11 + 조작 5회전: 조작 동안 expired 없이 양보(규칙 4), (가상 − 누적 실패 − 누적 양보) = 60 ± 0.3
Reset-Case -DefaultWords $noExit -ActiveSeq @($true, $true, $true, $true, $true)
$script:mode = 'selFail'
$r = Run-Click -Parent ($script:vclock.AddSeconds(60))
Check-Equal ('2-14 조작 5회전: expired, 양보 5, (가상 − 누적 실패 − 누적 양보) = 60 ± 0.3 (실제 ' + (Adj) + ')') ("$($r.Result)/$($script:yieldWaits)/$([int]([math]::Abs((Adj) - 60) -le 0.3))") 'expired/5/1'
# 2-14b. 부모 마감이 이미 지난 값 + 조작 5회전: 조작 중 expired 0(양보 5), 조작이 끝난 첫 복구 회전(판독 6회째)에서 expired
#        (2-14 는 조작 중에 마감 전이라 '양보 게이트를 마감 판정 뒤로' 옮기는 변이를 못 잡음 - 반영본 검증, 09-30 리뷰4)
Reset-Case -DefaultWords $noExit -ActiveSeq @($true, $true, $true, $true, $true)
$script:mode = 'selFail'
$r = Run-Click -Parent ($script:vclock.AddSeconds(-1))
Check-Equal '2-14b 지난 부모 마감 + 조작 5회전: 양보 5 뒤 첫 복구 회전에서 expired (판독 6회)' ("$($r.Result)/$($script:yieldWaits)/$($script:readCalls)") 'expired/5/6'
# 2-15. 선택 화면 예외: 부모 마감이 이미 지났고 같은 회전 복구 회전의 선택 화면 판정이 실패 뒤 같은 판정 안에서 복구해 참(셋째 모드) →
#       'expired' 가 아니라 'selection'(클릭 0, 안내 1) - 양성은 이 회전의 마지막 실패 뒤 새로 찍은 성공 캡처 셋이라 무효 표본이 아님
#       (09-30 리뷰4 반영본 검증 · 09-30 리뷰5 ③ 로 'gone' → 'selection'). 예외를 지우거나 'expired' 판정 뒤로 옮기는 변이는 'expired' 로 FAIL
Reset-Case -DefaultWords $noExit
$script:mode = 'selSameCall'
$r = Run-Click -Parent ($script:vclock.AddSeconds(-1))
Check-Equal "2-15 지난 부모 마감 + 복구 회전의 선택 화면: selection, 클릭 0, 안내 로그 1, exit 없음" ("$($r.Result)/$($script:clicksSent)/$((Count-Log '워커가 연 화면인지 알 수 없어'))/$($script:exitCode)") 'selection/0/1/'
#       대조(부모 마감 없는 호출): 같은 회전 복구 회전은 판정 없이 300ms 뒤 다음 회전 → 그 회전의 선택 화면으로 selection (판독 2회 - 2-7b 와 같은 폐기)
Reset-Case -DefaultWords $noExit
$script:mode = 'selSameCallOnce'
$r = Run-Click
Check-Equal '2-15 대조(부모 마감 없음): 복구 회전은 폐기 → 다음 회전 selection (판독 2회)' ("$($r.Result)/$($script:readCalls)") 'selection/2'

# ── 3. 배선 (주석 뺀 사본) ─────────────────────────────────────────────────────
$workerSource = Remove-SourceComments -Text ([IO.File]::ReadAllText($workerPath))
Check-Equal '배선: 고정 좌표 $ptExitButton 클릭 0곳' ([regex]::Matches($workerSource, 'Click-GamePoint[^\r\n]*\$ptExitButton').Count) 0
# 2026-09-30 ⑥e: 옛 파티원 두 호출(클릭·재클릭)은 관측 루프 D·퇴장 절차 P 로 바뀌며 사라졌습니다 - D·P 는 이 헬퍼를 쓰지 않습니다
#   (커서가 가린 접힌 패널에서 (492,654) = 던전 퇴장을 누르는 헬퍼, 09-29 재생 - D·P 쪽 0건 단언은 test_abyss_party_member §3)
Check-Equal '배선: 헬퍼 호출 5곳 (본류·시작 보상·시작 클리어·복구 루프·다른 던전 가기 끝 함수)' ([regex]::Matches($workerSource, 'Invoke-AbyssExitClick -Game').Count) 5
# 부모 마감 (⑥e 설계 2.13 - 09-30 리뷰4 P1-2 · 반영본 검증): 워커의 다섯 호출 모두 넘깁니다 - 복귀 루프 1곳은 호출 직전 조정한 자기 마감,
# 본류 세 호출은 뒤이어 부를 복귀 루프와 같은 예산(`[void]` 호출 다음 줄이 Return-ToAbyssSelection). 넷째 항 = '다른 던전 가기' 끝 함수(Complete-AbyssOtherSelection)의
# 폴백 ② - 같은 예산이고 `$Game` 대문자 · 헬퍼 결과를 `$exitClick` 에 받아 같은 블록의 다음 문장이 호출 E if(패널 셋 ∧ 재입장 요청 판이면 재입장 대기 Wait-AbyssReentry),
# 그다음 문장이 복귀 루프 · 복귀 루프 종료 코드는 앞에서 계산한 변수 하나(구현 명세 ⑤b3 3.4 · B-9 · ⑤b4 3.4 - '[void] 헬퍼 → 바로 다음 줄 복귀 루프' 꼴에서 바뀜)
$parentReturnCalls = [regex]::Matches($workerSource, 'Invoke-AbyssExitClick -Game \$Game [^\r\n]*-ParentDeadline \$exitParentDeadline').Count
$parentMainCalls = [regex]::Matches($workerSource, '\[void\]\(Invoke-AbyssExitClick -Game \$game [^\r\n]*-ParentDeadline \(\(Get-Date\)\.AddSeconds\(\$timeoutHud \+ \$timeoutAbyssMenu \+ \$timeoutAbyssSelect\)\)\)\s*\r?\n\s*Return-ToAbyssSelection -Game \$game').Count
$parentOtherCalls = [regex]::Matches($workerSource, '\$exitClick = Invoke-AbyssExitClick -Game \$Game [^\r\n]*-ParentDeadline \(\(Get-Date\)\.AddSeconds\(\$timeoutHud \+ \$timeoutAbyssMenu \+ \$timeoutAbyssSelect\)\)\s*\r?\n(?<indent>[ \t]*)if \([^\r\n]*\$exitClick\.Result[^\r\n]*\{\s*\r?\n(?:[^\r\n]*\r?\n)*?[^\r\n]*Wait-AbyssReentry -Game \$Game[^\r\n]*\r?\n(?:[^\r\n]*\r?\n)*?\k<indent>\}\s*\r?\n\k<indent>Return-ToAbyssSelection -Game \$Game -SafeStopExitCode \$returnExitCode').Count
Check-Equal '배선: -ParentDeadline 을 넘기는 헬퍼 호출 5곳 = 복귀 루프 1(조정 마감) + 본류 3 + 다른 던전 가기 끝 함수 1(복귀 루프 예산, 호출 E if 다음 문장 Return-ToAbyssSelection)' ("$([regex]::Matches($workerSource, 'Invoke-AbyssExitClick -Game [^\r\n]*-ParentDeadline').Count)/$parentReturnCalls/$parentMainCalls/$parentOtherCalls") '5/1/3/1'
$returnDef = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Return-ToAbyssSelection')))
# ★ 뒤집음(⑥e 설계 2.13): 복구 루프의 만료 판정은 Get-FreezeAdjustedDeadline(캡처 실패 누적 차분 포함)이라 헬퍼 FrozenMs 를 더하면 같은 실패 시간이
#   두 번 더해집니다(⑥a 필드 복귀 루프의 선례). 'expired' 는 호출 바로 다음 줄에서 break(→ 안전 중지가 없으면 throw, 있으면 while 뒤 마감 출구)
Check-Equal '배선: 복구 루프는 헬퍼 FrozenMs 를 마감에 더하지 않음 (이중 가산 금지)' ([regex]::Matches($returnDef, 'FrozenMs').Count) 0
Check-Equal "배선: 복구 루프는 호출 직전 조정 마감을 넘기고 'expired' 를 다음 줄에서 break" ([bool]($returnDef -match '\$exitParentDeadline = Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$deadline\)[^\r\n]*\r?\n\s*\$exitClick = Invoke-AbyssExitClick -Game \$Game [^\r\n]*-ParentDeadline \$exitParentDeadline\s*\r?\n\s*if \(\$exitClick\.Result -eq ''expired''\) \{ break \}')) 'True'
Check-Equal '배선: 복구 루프에 옛 메타 분기(나가기 클릭 건너뜀) 없음' ([bool]($returnDef -match '나가기 클릭 건너뜀')) 'False'
$clickCode = Remove-SourceComments -Text $defs['Invoke-AbyssExitClick']
Check-Equal '헬퍼: 캡처 실패 동결이 공통 진입점을 거침' ([bool]($clickCode -match 'if \(\$script:screenCaptureFailing\)\s*\{[\s\S]{0,160}Test-SafeStopDuringCaptureFail')) 'True'
Check-Equal '헬퍼: 판독이 동결 검사보다 앞 (회전마다 캡처 시도 = 복구 탐침)' ($clickCode.IndexOf('Find-AbyssExitButtonPoint') -lt $clickCode.IndexOf('if ($script:screenCaptureFailing)')) 'True'
Check-Equal '헬퍼: 후속 화면 판정(선택·HUD·추적기)이 동결 검사보다 앞 (판정 중 캡처 실패도 그 회전에서 동결)' ($clickCode.IndexOf('Test-InDungeonQuest') -lt $clickCode.IndexOf('if ($script:screenCaptureFailing)')) 'True'
Check-Equal '헬퍼: 조작 검사가 재판독 카운트보다 앞 (규칙 4 - 조작이 예산을 소모하지 않음)' ($clickCode.IndexOf('Test-UserRecentlyActive') -lt $clickCode.IndexOf('$missCount++')) 'True'
Check-Equal '헬퍼: 정지 조건 = 3회 이상 + 20초(동결 제외)' ([bool]($clickCode -match '\$missCount -ge 3 -and \$missElapsedMs -ge 20000')) 'True'
Check-Equal '헬퍼(⑥a): 패널 판독은 회전마다 한 번(위치 유무 무관), 후속 화면 판정보다 앞, 클릭 분기보다 앞에서 반환' (
  ([regex]::Matches($clickCode, 'Get-AbyssPanelKind -Game \$Game').Count -eq 1) -and
  ($clickCode.IndexOf('Get-AbyssPanelKind -Game $Game') -lt $clickCode.IndexOf('Test-AbyssSelectionScreen -Game $Game')) -and
  ($clickCode.IndexOf('return @{ Result = $panelNow') -lt $clickCode.IndexOf('Click-GamePoint -Game $Game'))) 'True'
# 결과 'selection' / 'gone' (⑥e 설계 2.14 - 09-30 리뷰5 ④): 'selection' 은 평소 후속 화면 분기와 부모 마감 분기 두 곳, 둘 다 선택 화면 조건 아래.
# 'gone' 은 한 곳이고 선택 화면 조건 뒤(그 분기에 오는 $passed 는 '필드 HUD' 뿐)
$selectionReturns = [regex]::Matches($clickCode, "if \(\`$passed -eq '선택 화면'\) \{[^}]*?return @\{ Result = 'selection'; FrozenMs = \`$frozenMs \}").Count
Check-Equal "헬퍼(⑥e): Result = 'selection' 2곳 모두 선택 화면 조건 아래, Result = 'gone' 1곳은 마지막 선택 화면 분기 뒤" (
  ([regex]::Matches($clickCode, "Result = 'selection'").Count -eq 2) -and ($selectionReturns -eq 2) -and
  ([regex]::Matches($clickCode, "Result = 'gone'").Count -eq 1) -and
  ($clickCode.IndexOf("Result = 'gone'") -gt $clickCode.LastIndexOf("if (`$passed -eq '선택 화면') {"))) 'True'
# 부모 마감 분기 (⑥e 설계 2.13): 복구 회전 블록(같은 회전 복구·탐침 복구 뒤) 안에서만, $null -ne $ParentDeadline 조건 아래.
# 순서 = 조작 양보 < 선택 화면 예외('selection') < 조정 마감(Get-FreezeAdjustedDeadline) < 'expired' < 300ms 대기 < 단독 줄 continue
$recoveredStart = $clickCode.IndexOf('if ($probeRecovered -or (-not $script:screenCaptureFailing -and $script:captureFailSerial -ne $turnSerial)) {')
$freezeStart = $clickCode.IndexOf('if ($script:screenCaptureFailing) {')
$recoveredBlock = $(if ($recoveredStart -ge 0 -and $freezeStart -gt $recoveredStart) { $clickCode.Substring($recoveredStart, $freezeStart - $recoveredStart) } else { '' })
$rbParent = $recoveredBlock.IndexOf('if ($null -ne $ParentDeadline) {'); $rbYield = $recoveredBlock.IndexOf('if (Test-UserRecentlyActive)')
$rbSelection = $recoveredBlock.IndexOf("if (`$passed -eq '선택 화면') {"); $rbFreeze = $recoveredBlock.IndexOf('Get-FreezeAdjustedDeadline -Deadline ([ref]$parentDeadlineAt)')
$rbExpired = $recoveredBlock.IndexOf("Result = 'expired'"); $rbSleep = $recoveredBlock.IndexOf('Start-Sleep -Milliseconds 300')
Check-Equal '헬퍼(⑥e): 복구 회전 블록 조건 = 탐침 복구 뒤 또는 같은 회전 복구, 안의 부모 마감 분기 순서 = 부모 마감 있음 < 양보 < 선택 화면 < 조정 마감 < expired < 300ms < continue' (
  ($recoveredStart -gt 0) -and ($rbParent -ge 0) -and ($rbParent -lt $rbYield) -and ($rbYield -lt $rbSelection) -and ($rbSelection -lt $rbFreeze) -and
  ($rbFreeze -lt $rbExpired) -and ($rbExpired -lt $rbSleep) -and ([bool]($recoveredBlock -match 'Start-Sleep -Milliseconds 300\s*\r?\n\s*continue\s*\r?\n\s*\}\s*$'))) 'True'
Check-Equal '헬퍼(⑥e): Get-FreezeAdjustedDeadline 은 1곳(복구 회전 블록의 부모 마감 분기) - 유효 회전은 부모 마감을 보지 않음' (
  ([regex]::Matches($clickCode, 'Get-FreezeAdjustedDeadline').Count -eq 1) -and ($rbFreeze -gt $rbParent)) 'True'
# 탐침 복구 뒤 회전 표식: 하단 판독(Find-AbyssExitButtonPoint) 바로 뒤·패널 판독 앞 1곳, 부모 마감이 있는 호출에서만. 패널·후속 판독은 표식이 거짓일 때만
$probeAt = $clickCode.IndexOf('$probeRecovered = ')
$probeGuardAt = $clickCode.IndexOf('if (-not $probeRecovered) {')
$probeReadsBlock = $(if ($probeGuardAt -ge 0 -and $recoveredStart -gt $probeGuardAt) { $clickCode.Substring($probeGuardAt, $recoveredStart - $probeGuardAt) } else { '' })
Check-Equal '헬퍼(⑥e): $probeRecovered 대입 1곳 = 하단 판독 바로 뒤(부모 마감 조건 포함), 패널·선택 화면·HUD·추적기 판독은 if (-not $probeRecovered) 안' (
  ([regex]::Matches($clickCode, '\$probeRecovered = ').Count -eq 1) -and
  ([bool]($clickCode -match '\$read = Find-AbyssExitButtonPoint -Game \$Game\s*\$probeRecovered = \(\$null -ne \$ParentDeadline\) -and ')) -and
  ($probeAt -lt $clickCode.IndexOf('Get-AbyssPanelKind -Game $Game')) -and
  ($probeReadsBlock.Contains('Get-AbyssPanelKind -Game $Game')) -and ($probeReadsBlock.Contains('Test-AbyssSelectionScreen -Game $Game')) -and
  ($probeReadsBlock.Contains('Test-HomeEndEscHud -Game $Game')) -and ($probeReadsBlock.Contains('Test-InDungeonQuest -Game $Game'))) 'True'
$findCode = Remove-SourceComments -Text $defs['Find-AbyssExitButtonPoint']
Check-Equal '탐색: Test-ExitButton 과 같은 영역(clearAndExitText)·배율 3' ([bool]($findCode -match 'rgClearExit\[0\][\s\S]{0,200}-Scale 3')) 'True'

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
