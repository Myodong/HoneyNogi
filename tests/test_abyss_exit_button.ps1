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
#      동결 시간을 FrozenMs 로 부모 마감에 반환 - 가상 시계로 생산까지 단언) / 위치·후속 화면 모두 없음이 3회 이상 + 첫
#      미검출부터 20초(동결 제외) → 진단 캡처 + [완료] + exit 4 / 후속 화면(선택 화면 → 필드 HUD → ESC 메뉴 순) 확인 →
#      'gone' / 커서 미확인 3회 → 'skipped' / 후속 판정 도중 캡처 실패는 동결(미소모)
#   ③ 배선: 고정 좌표 클릭 0곳, 헬퍼 호출 5곳, 복구 루프가 FrozenMs 를 마감에 반영
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
$defs = @{}
foreach ($name in @('Select-AbyssExitWord', 'Find-AbyssExitButtonPoint', 'Invoke-AbyssExitClick')) {
  $defs[$name] = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name))
}
Invoke-Expression $defs['Select-AbyssExitWord']
Invoke-Expression $defs['Find-AbyssExitButtonPoint']
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
  $r = Next-Seq 'words' 'default'
  if ("$r" -eq 'capfail') { $script:screenCaptureFailing = $true; return @() }     # 캡처 실패 = 플래그 세우고 빈 배열 (실제 계약)
  $script:screenCaptureFailing = $false                                              # 캡처 성공 = 플래그 해제 (Register-CaptureSuccess 계약)
  if ("$r" -eq 'default') { return $script:defaultWords }
  if ("$r" -eq 'empty') { return @() }                                               # 캡처 성공·단어 0개 (판독 '')
  return $r
}
function Test-UserRecentlyActive { return [bool](Next-Seq 'active' $false) }
function Wait-UserYieldEnd { param($Game, $Context) $script:yieldWaits++; $script:yieldContexts += $Context; $script:vclock = $script:vclock.AddSeconds(5) }   # 양보 5초 (FrozenMs 에 섞이면 안 됨)
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY)
  $script:clickPoints += "$ReferenceX,$ReferenceY"
  $r = Next-Seq 'send' 'sent'
  $script:lastClickPerformed = ($r -eq 'sent'); $script:lastClickSkipReason = $(if ($r -eq 'sent') { '' } else { $r })
  if ($r -eq 'sent') { $script:clicksSent++ }
}
function Test-AbyssSelectionScreen { param($Game) $script:successorChecks++
  if ($script:selectionFailOnce) { $script:selectionFailOnce = $false; $script:screenCaptureFailing = $true; return $false }   # 후속 판정 도중 캡처 실패
  return $script:selectionVisible }
function Test-HomeEndEscHud { param($Game) $script:successorChecks++; return $script:hudVisible }
function Test-AbyssMenu { param($Game) $script:successorChecks++; return $script:menuVisible }
function Reset-Case {
  param($WordsSeq = @(), $ActiveSeq = @(), $SendSeq = @(), $DefaultWords = $null)
  $script:wordsSeq = @($WordsSeq); $script:wordsIdx = 0
  $script:activeSeq = @($ActiveSeq); $script:activeIdx = 0
  $script:sendSeq = @($SendSeq); $script:sendIdx = 0
  $script:defaultWords = $(if ($null -ne $DefaultWords) { $DefaultWords } else { $captureS3 })
  $script:vclock = [datetime]'2026-09-18 21:00:00'
  $script:logs = @(); $script:yieldWaits = 0; $script:yieldContexts = @(); $script:clicksSent = 0; $script:clickPoints = @()
  $script:readCalls = 0; $script:readRegion = ''; $script:safeStopCalls = 0; $script:successorChecks = 0
  $script:diagCalls = 0; $script:diagContext = ''; $script:diagCaptureOnly = $null; $script:exitCode = $null
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'   # 잔존 메타 - 오발동 없어야 함
  $script:screenCaptureFailing = $false
  $script:selectionVisible = $false; $script:hudVisible = $false; $script:menuVisible = $false; $script:selectionFailOnce = $false
}
function Count-Log { param([string]$Pattern) @($script:logs | Where-Object { $_ -match $Pattern }).Count }
function Run-Click { param([string]$Context = '나가기 클릭') Invoke-AbyssExitClick -Game $game -LogPrefix '[어비스]' -Context $Context }
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
Check-Equal '캡처 실패 2회: 실패 중 후속 화면 판정 0회, 결과 clicked' ("$($script:successorChecks)/$($r.Result)") '0/clicked'
Check-Equal '캡처 실패 2회: FrozenMs = 1400 (동결 회전 700ms×2 - 부모 마감 연장 근거가 실제로 생산됨)' ([int]$r.FrozenMs) 1400

# 2-3. 규칙 4: 클릭 전 조작 감지 → 양보 → **다시 읽은** 좌표로 클릭 (옛 좌표 재클릭 금지). 양보 시간은 FrozenMs 에 안 섞임
$movedS3 = @((W '나가기' 480), (W '다세' 617), (W '하기' 659))
Reset-Case -WordsSeq @($captureS3, $movedS3) -ActiveSeq @($true, $false)
$r = Run-Click
Check-Equal '조작 중: 양보 1회 → 재판독 → 새 좌표 (480,654) 클릭 (첫 판독 478 재클릭 없음)' ("$($script:yieldWaits)/$($script:readCalls)/$($script:clickPoints -join ';')") '1/2/480,654'
Check-Equal '조작 중: 양보 5초는 FrozenMs 에 가산되지 않음 (중복 가산 금지)' ([int]$r.FrozenMs) 0

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
#    2-6b. 3회는 됐지만 20초가 안 됐으면 정지하지 않음: 미검출 3회 뒤 나가기가 다시 보이면 클릭 (페이드 중 판독 공백 허용)
Reset-Case -WordsSeq @($noExit, $noExit, $noExit, $captureS3)
$r = Run-Click
Check-Equal '미검출 3회 뒤 재출현: 정지 없이 클릭 (시간 기준 - 전이 중 판독 공백을 정지로 오판하지 않음)' ("$($r.Result)/$($script:exitCode)/$($script:clicksSent)") 'clicked//1'

# 2-7. 규칙 15: 미검출 사이에 캡처 실패가 끼어도 실패 회전은 소모하지 않고 20초 기준에서도 동결 시간을 뺌
#    판독: noExit(0s) capfail(→0.7s, 동결 0.7) noExit(경과 1.7-0.7=1.0) capfail(→2.4, 동결 1.4) noExit(경과 3.4-1.4=2.0) … 경과 20 = 미검출 21회 → 판독 23회
Reset-Case -WordsSeq @($noExit, 'capfail', $noExit, 'capfail', $noExit) -DefaultWords $noExit
$r = Run-Click
Check-Equal '미검출+캡처 실패 교차: 판독 23회(미검출 21 + 실패 2), 안전 확인 2회, exit 4, FrozenMs 1400' ("$($script:readCalls)/$($script:safeStopCalls)/$($script:exitCode)/$([int]$r.FrozenMs)") '23/2/4/1400'
#    2-7b. 후속 화면 판정 도중 캡처 실패 → 그 회전은 동결(안전 확인·미소모), 다음 회전에 정상 판독 → 클릭
Reset-Case -WordsSeq @($noExit, $captureS3)
$script:selectionFailOnce = $true
$r = Run-Click
Check-Equal '후속 판정 중 캡처 실패: 안전 확인 1, 재판독 소모 0, 다음 회전 clicked, FrozenMs 700' ("$($script:safeStopCalls)/$((Count-Log '재판독'))/$($r.Result)/$([int]$r.FrozenMs)") '1/0/clicked/700'

# 2-8. 후속 화면 확인 → gone (사용자가 이미 눌렀거나 전환), 클릭 0, 정지 없음. 판정 순서 = 선택 화면 → 필드 HUD → ESC 메뉴
Reset-Case -DefaultWords $noExit
$script:selectionVisible = $true
$r = Run-Click
$goneLogs = Count-Log '선택 화면 이\(가\) 확인돼 클릭 없이'
Check-Equal '후속 화면(선택 화면): gone, 클릭 0, exit 없음, 안내 로그' ("$($r.Result)/$($script:clicksSent)/$($script:exitCode)/$goneLogs") 'gone/0//1'
Reset-Case -DefaultWords $noExit
$script:hudVisible = $true
$r = Run-Click
Check-Equal '후속 화면(필드 HUD): gone' ("$($r.Result)/$((Count-Log '필드 HUD'))") 'gone/1'
Reset-Case -DefaultWords $noExit
$script:menuVisible = $true
$r = Run-Click
Check-Equal '후속 화면(ESC 메뉴): gone' ("$($r.Result)/$((Count-Log 'ESC 메뉴'))") 'gone/1'
Reset-Case -DefaultWords $noExit
$script:selectionVisible = $true; $script:menuVisible = $true
$r = Run-Click
Check-Equal '판정 순서: 선택 화면 + ESC 메뉴 동시 → 선택 화면으로 기록 (메뉴는 상세 헤더 오탐 이력이라 맨 뒤)' ("$((Count-Log '선택 화면 이'))/$((Count-Log 'ESC 메뉴'))") '1/0'
Reset-Case -DefaultWords $noExit
$script:hudVisible = $true; $script:menuVisible = $true
$r = Run-Click
Check-Equal '판정 순서: 필드 HUD + ESC 메뉴 동시 → 필드 HUD 로 기록' ("$((Count-Log '필드 HUD'))/$((Count-Log 'ESC 메뉴'))") '1/0'

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
Check-Equal '나가기 보임 + 메뉴 오탐: 후속 판정 없이 클릭 (successorChecks 0)' ("$($r.Result)/$($script:successorChecks)/$($script:clicksSent)") 'clicked/0/1'

# ── 3. 배선 (주석 뺀 사본) ─────────────────────────────────────────────────────
$workerSource = Remove-SourceComments -Text ([IO.File]::ReadAllText($workerPath))
Check-Equal '배선: 고정 좌표 $ptExitButton 클릭 0곳' ([regex]::Matches($workerSource, 'Click-GamePoint[^\r\n]*\$ptExitButton').Count) 0
Check-Equal '배선: 헬퍼 호출 5곳 (본류·시작 보상·시작 클리어·파티원·복구 루프)' ([regex]::Matches($workerSource, 'Invoke-AbyssExitClick -Game').Count) 5
$returnDef = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Return-ToAbyssSelection')))
Check-Equal '배선: 복구 루프가 헬퍼 FrozenMs 를 마감에 반영' ([bool]($returnDef -match 'FrozenMs -gt 0\)\s*\{\s*\$deadline = \$deadline\.AddMilliseconds')) 'True'
Check-Equal '배선: 복구 루프에 옛 메타 분기(나가기 클릭 건너뜀) 없음' ([bool]($returnDef -match '나가기 클릭 건너뜀')) 'False'
$clickCode = Remove-SourceComments -Text $defs['Invoke-AbyssExitClick']
Check-Equal '헬퍼: 캡처 실패 동결이 공통 진입점을 거침' ([bool]($clickCode -match 'if \(\$script:screenCaptureFailing\)\s*\{[\s\S]{0,160}Test-SafeStopDuringCaptureFail')) 'True'
Check-Equal '헬퍼: 판독이 동결 검사보다 앞 (회전마다 캡처 시도 = 복구 탐침)' ($clickCode.IndexOf('Find-AbyssExitButtonPoint') -lt $clickCode.IndexOf('if ($script:screenCaptureFailing)')) 'True'
Check-Equal '헬퍼: 후속 화면 판정 3종이 동결 검사보다 앞 (판정 중 캡처 실패도 그 회전에서 동결)' ($clickCode.IndexOf('Test-AbyssMenu') -lt $clickCode.IndexOf('if ($script:screenCaptureFailing)')) 'True'
Check-Equal '헬퍼: 조작 검사가 재판독 카운트보다 앞 (규칙 4 - 조작이 예산을 소모하지 않음)' ($clickCode.IndexOf('Test-UserRecentlyActive') -lt $clickCode.IndexOf('$missCount++')) 'True'
Check-Equal '헬퍼: 정지 조건 = 3회 이상 + 20초(동결 제외)' ([bool]($clickCode -match '\$missCount -ge 3 -and \$missElapsedMs -ge 20000')) 'True'
$findCode = Remove-SourceComments -Text $defs['Find-AbyssExitButtonPoint']
Check-Equal '탐색: Test-ExitButton 과 같은 영역(clearAndExitText)·배율 3' ([bool]($findCode -match 'rgClearExit\[0\][\s\S]{0,200}-Scale 3')) 'True'

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
