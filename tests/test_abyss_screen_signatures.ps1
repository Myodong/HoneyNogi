# 어비스 화면 서명 진리표 + 판정 fail-closed 배선 (v2.1.12 - 2026-09-21 설계 합의 A1~A5, 09-20 23:24 실사고)
#
# 실사고: 보스전 중 사용자 조작으로 선택 화면 오버레이가 열리자 클리어 감시가 'selection' 을 돌려줘 회차를 끝냈고, 복귀 루프는
# 던전 안 HUD 를 '던전 밖' 으로 보고 ESC → 메뉴 '어비스' 로 **던전 안에서** 오버레이를 열어 '복귀 완료'(코드 0) → 다음 회차가
# 클리어 S 화면에서 오류. 09-18 실측: '다시 하기' 뒤 재매칭 패널은 카드 영역이 선택 화면으로, 하단 '나가기'(매칭 취소)가 보상
# 화면으로 읽힘. 오버레이·패널은 추적기·HUD 를 가림 → 던전 안·밖 부정 증거는 오버레이가 뜨기 전(HUD 단계)에서만 얻을 수 있음.
# 여기서 고정하는 계약:
#   ① 순수 판정 Test-AbyssRewardText: '나가기' + ('다시|다세|다셔'+'하기' 또는 '다른'+'던전') - 패널의 취소용 '나가기' 만으로는 거짓
#   ② 순수 판정 Test-AbyssMatchingPanelText: abyssMenu 영역에 '플레이어가모이면' + '자동입장' 둘 다
#   ③ 배선: Test-ExitButton 은 ①, 선택 화면 판정은 양성일 때 패널 배제, 클리어 감시는 패널 → 보상 → 오버레이(불명, 관측 지속) 순이고
#      'selection' 을 돌려주지 않으며 마감 시 불명·필드 관측이 있으면 코드 4, 본류 마커는 clear/reward 문맥에서만, 복귀 루프는 던전 안
#      (HUD+추적기, 2연속·20초) 이면 ESC 금지 + 코드 4 이고 필드를 직접 확인한 뒤에만 메뉴 '어비스' 클릭, 나가기 헬퍼 gone 은
#      HUD+추적기 없음 2연속(ESC 메뉴 제외 - 선택 화면은 ⑥e 부터 'selection')이고 패널이면 'matching', 시작 디스패치는 패널이면 취소 없이 입장 대기,
#      알려진 화면에 패널 포함
#   ④ ⑥a (2026-09-26 설계 합의 4.2): 패널 판독은 Get-AbyssPanelKind 하나(준비 > 재매칭 순), 접힌 준비 패널('나가기'+'대기중')은 하단 판독으로
#      따로 - 선택 화면 판정은 두 패널·접힌 패널을 배제, 클리어 감시·복귀 루프·시작 디스패치·나가기 헬퍼는 셋 다 클릭 없이 기다리고,
#      복귀 루프는 준비·접힌 패널이 마감까지 이어지면 진단 + 코드 4, 알려진 화면에 파티원 보상·접힌 패널·권장 인원 팝업·두 패널 등록.
#   ⑤ ⑥e (2026-09-30 설계 합의 2.11~2.14): 파티원은 Clear-EventOverlay 앞 디스패치로 관측 루프 D 에 들어가고(시작 패널 대기의 파티원 제외 항 삭제 -
#      ⑥a 의 두 출구는 D·퇴장 절차 P 로 바뀜, 4절), 시작 패널 대기·판정 루프는 스윕 참·복구 회전·탐침 복구 뒤 회전도 조정 마감을 보고 서두 동결은
#      마감을 되돌리지 않음(2.12·2.13). 복귀 루프는 만료 판정이 모두 Get-FreezeAdjustedDeadline(양보 + 캡처 실패 누적 차분), 동결 블록은 양보 게이트 앞
#      복구 탐침 + continue 형, 선택 화면은 워커 자신의 '어비스' 클릭 출처가 살아 있을 때만 완료(회전 서두 한 곳), 필드 모양은 W 초 확정 뒤에만 ESC(2.14)
#   ⑥ ESC 메뉴 '어비스' 아이콘 폴백 (2026-10-07 설계 v2 10.4): 클릭 로그의 탐색 출처는 변수 $abyssMenuFoundBy - '글자 탐색' 은 글자 탐색 바로 뒤,
#      '아이콘 탐색' 은 아이콘 found 블록 안 각 1곳. 클릭 블록·토큰 소비·선택 화면 출처 발급은 그대로 하나 (행동은 test_abyss_return_loop RLI 사례)
#   ⑦ 어비스 완료 기록 (2026-10-09 구현 명세 ① 2.10): 본류 마커 호출은 반환값을 버리는 [void] 모양(W5), 완료 기록(cleared) 호출은 마커 블록 바로 뒤 ·
#      나가기 헬퍼 바로 앞의 별도 if 1곳(W3 - 조건 = 클리어·보상 문맥 ∧ 정리 전용 아님). 기록 내용은 test_abyss_journal_store X4, GUI 계상과의 결합은
#      test_abyss_handoff_gui 결합 행
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
foreach ($name in @('Test-AbyssRewardText', 'Test-AbyssMatchingPanelText')) {
  Invoke-Expression ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($name)))
}

# ── 1. 보상 화면 서명 (실측 문자열 그대로) ──
$rewardS3 = '아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기'   # 09-18 보상 화면, clearAndExitText 배율 3
$rewardS3b = '아이템을누르면상세정보테볼수있습니다나가기Space다세하기다른던전가기' # 09-18 1270x702 캡처
$rewardS4 = '아이템을누르면상세정보로볼수있습니다나가기Space다셔하기다른던전가기' # 배율 4 는 '다셔'
$panelExit = '사제아이템을누르면상세정보를7나가기'                                  # 09-18 재매칭 패널 1/4 - 하단 '나가기' = 매칭 취소
$panelExit2 = '사제아이들1을누르면상세정보를'                                       # 재매칭 패널 4/4 (나가기 조각 없음)
$clearPrompt = '화면을X해주'                                                       # 09-20 클리어 S 화면 하단
$clearPrompt2 = '화면을Eå夫6주'
Check-Equal '보상: 09-18 배율 3 판독 → 참' (Test-AbyssRewardText -Text $rewardS3) $true
Check-Equal '보상: 09-18 1270x702 판독 → 참' (Test-AbyssRewardText -Text $rewardS3b) $true
Check-Equal "보상: 배율 4 '다셔' 판독 → 참" (Test-AbyssRewardText -Text $rewardS4) $true
Check-Equal "보상: 재매칭 패널의 취소용 '나가기' 만 → 거짓 (매칭 취소 오클릭 차단 - 09-20 사후 리뷰 P2)" (Test-AbyssRewardText -Text $panelExit) $false
Check-Equal '보상: 재매칭 패널 4/4 판독 → 거짓' (Test-AbyssRewardText -Text $panelExit2) $false
Check-Equal '보상: 클리어 화면 하단 → 거짓' (Test-AbyssRewardText -Text $clearPrompt) $false
Check-Equal '보상: 클리어 화면 하단(다른 깨짐) → 거짓' (Test-AbyssRewardText -Text $clearPrompt2) $false
Check-Equal '보상: 빈 판독(캡처 실패) → 거짓' (Test-AbyssRewardText -Text '') $false
Check-Equal '보상: null → 거짓' (Test-AbyssRewardText -Text $null) $false
Check-Equal "보상: '나가기'+'다시'+'하기' 조각만 → 참 (다른 던전 조각 없이)" (Test-AbyssRewardText -Text '나가기다시하기') $true
Check-Equal "보상: '나가기'+'다른'+'던전' 조각만 → 참 (다시 하기 조각 없이)" (Test-AbyssRewardText -Text '나가기다른던전') $true
Check-Equal "보상: '나가기'+'가기' 는 거짓 ('가기' 단독은 조각이 아님)" (Test-AbyssRewardText -Text '나가기가기') $false
Check-Equal "보상: '나가기' 없이 나머지 조각만 → 거짓" (Test-AbyssRewardText -Text 'Space다세하기다른던전가기') $false
Check-Equal '보상: 공백이 섞인 원문도 같은 판정' (Test-AbyssRewardText -Text '나가기 Space 다세 하기 다른 던전 가기') $true

# ── 2. 재매칭 패널 서명 (abyssMenu 영역 배율 4, 09-18 3프레임) ──
$panelMenu1 = '빻지/입문근든플레이어가모이면자동입장합니다.00:00'
$panelMenu2 = '4지/입문\밀러프핫빙결술사도H지자식대결전人l근든플레이어가모이면자동입장합니다.'
$panelMenu3 = '나지/100\밐러4100프핫\다년,현술人l100도H지자노``머검전사=플레이어가모이면자동입장합니다.'
$overlayMenu = '4'                                                                    # 09-18 선택 화면 오버레이의 같은 영역
$insideMenu = '수허상의정박지들부활6회이내트[주간목표]모험가길드의모험가길드의고난도C6豸보름달이비추는C2금빛결실兮8|4뇨글100마물퇴' # 던전 안 HUD 프레임
Check-Equal '패널: 1/4 프레임 → 참' (Test-AbyssMatchingPanelText -Text $panelMenu1) $true
Check-Equal '패널: 4/4 프레임 → 참' (Test-AbyssMatchingPanelText -Text $panelMenu2) $true
Check-Equal '패널: 카운트다운 프레임 → 참' (Test-AbyssMatchingPanelText -Text $panelMenu3) $true
Check-Equal '패널: 선택 화면 오버레이 → 거짓' (Test-AbyssMatchingPanelText -Text $overlayMenu) $false
Check-Equal '패널: 던전 안 프레임 → 거짓' (Test-AbyssMatchingPanelText -Text $insideMenu) $false
Check-Equal '패널: 빈 판독 → 거짓' (Test-AbyssMatchingPanelText -Text '') $false
Check-Equal "패널: '플레이어가모이면' 만 (자동입장 없음) → 거짓 (두 조각 요구)" (Test-AbyssMatchingPanelText -Text '플레이어가모이면') $false
Check-Equal "패널: '자동입장' 만 → 거짓" (Test-AbyssMatchingPanelText -Text '자동입장합니다') $false

# ── 3. 배선 (주석 뺀 사본) ──
$src = Remove-SourceComments -Text ([IO.File]::ReadAllText($workerPath))
function Body([string]$fn) { Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($fn))) }
$exitBtn = Body 'Test-ExitButton'
Check-Equal '배선: Test-ExitButton 은 3버튼 서명 판정을 씀' ([bool]($exitBtn -match 'Test-AbyssRewardText -Text \$ocrText')) 'True'
$sel = Body 'Test-AbyssSelectionScreen'
Check-Equal '배선: 선택 화면 판정이 양성일 때 두 패널(재매칭·준비)과 접힌 준비 패널을 배제하고, 배제 판독이 캡처 실패면 양성 반환 금지 (⑥a)' ([bool]($sel -match '\$panelKindNow = Get-AbyssPanelKind -Game \$Game\s*if \(\$script:screenCaptureFailing\) \{ return \$false \}\s*if \(\$panelKindNow -ne ''none''\) \{ return \$false \}\s*\$entryWaitingNow = Test-AbyssEntryWaiting -Game \$Game\s*if \(\$script:screenCaptureFailing\) \{ return \$false \}\s*if \(\$entryWaitingNow\) \{ return \$false \}\s*return \$true')) 'True'
$panelKindFn = Body 'Get-AbyssPanelKind'
Check-Equal '배선(⑥a): 패널 종류는 abyssMenu 한 번 판독(배율 4) → 준비 패널 먼저, 재매칭 패널 다음, 그 외 none' (([regex]::Matches($panelKindFn, 'Get-GameRegionOcrText').Count -eq 1) -and ([bool]($panelKindFn -match 'rgAbyssMenu\[3\] -Scale 4')) -and ($panelKindFn.IndexOf('Test-AbyssReadyPanelText') -gt 0) -and ($panelKindFn.IndexOf('Test-AbyssReadyPanelText') -lt $panelKindFn.IndexOf('Test-AbyssMatchingPanelText')) -and ([bool]($panelKindFn -match "return 'none'\s*\}$"))) 'True'
$clearWait = Body 'Wait-ForDungeonClearScreen'
Check-Equal "배선: 클리어 감시는 'selection' 을 돌려주지 않음" ([regex]::Matches($clearWait, "return 'selection'").Count) 0
$cwMatching = $clearWait.IndexOf('$panelKindNow = Get-AbyssPanelKind -Game $Game'); $cwEntry = $clearWait.IndexOf('Test-AbyssEntryWaitingText -Text $script:lastClearPromptText'); $cwReward = $clearWait.IndexOf('if (Test-ExitButton -Game $Game) {'); $cwAmbiguous = $clearWait.IndexOf('$ambiguousOverlaySeen = $true')
Check-Equal '배선: 클리어 감시 어비스 분기 순서 = 패널(준비·재매칭) → 접힌 준비 패널 → 보상 → 선택 화면 오버레이(불명) (⑥a)' (($cwMatching -gt 0) -and ($cwMatching -lt $cwEntry) -and ($cwEntry -lt $cwReward) -and ($cwReward -lt $cwAmbiguous)) 'True'
# 창 {0,900} → {0,2400} (⑥e 설계 3절 2): 패널 분기 첫머리에 파티원(-MemberMode) 즉시 반환 블록이 들어가 분기 길이가 약 1741자(주석 포함)가 됐습니다 -
#   비파티원 경로(로그 1회 + 2초 + continue)는 그대로이고, 파티원 블록의 배선은 test_abyss_party_member §4 가 봅니다
Check-Equal '배선(⑥a): 클리어 감시 - 접힌 패널은 같은 폴의 하단 판독문 재사용 + HUD 부재 요구, 판독 도중 캡처 실패 표본은 패널 판정에 안 씀(흘려 동결 처리로), 세 패널 모두 클릭 없이 2초 뒤 관측 지속' ([bool]($clearWait -match '\$panelSerial = \$script:captureFailSerial\s*\$panelKindNow = Get-AbyssPanelKind -Game \$Game\s*\$entryWaitingNow = \(\$panelKindNow -eq ''none''\) -and \(Test-AbyssEntryWaitingText -Text \$script:lastClearPromptText\) -and\s*\(-not \$script:screenCaptureFailing\) -and \(-not \(Test-HomeEndEscHud -Game \$Game\)\)\s*if \(\$script:screenCaptureFailing -or \$script:captureFailSerial -ne \$panelSerial\) \{\s*\$panelKindNow = ''none''; \$entryWaitingNow = \$false\s*\}\s*if \(\$panelKindNow -ne ''none'' -or \$entryWaitingNow\) \{[\s\S]{0,2400}Start-Sleep -Seconds 2\s*continue\s*\}')) 'True'
Check-Equal '배선: 클리어 감시 마감 시 불명 오버레이·필드 관측이면 진단 + 코드 4' ([bool]($clearWait -match '\$ambiguousOverlaySeen -or \$fieldSeen\) \{[\s\S]{0,400}Write-LifeDiagnostics[\s\S]{0,600}exit 4')) 'True'
Check-Equal '배선: 클리어 감시 최종 탐침에 선택 화면 조항 없음 (있으면 불명 오버레이가 마감을 영영 넘김)' ([regex]::Matches($clearWait, 'Test-AbyssSelectionScreen -Game \$Game\) -and -not \(Test-HomeEndEscHud').Count) 0
Check-Equal '배선: 클리어 감시 필드 증거는 HUD + 추적기 던전명 없음 2연속' ([bool]($clearWait -match '\$questNow = Test-InDungeonQuest -Game \$Game[\s\S]{0,300}\$fieldStreak -ge 2')) 'True'
# 2026-10-09 구현 명세 ① 2.10 W5: 마커 함수가 기록 성공 여부(bool)를 돌려주게 되어 결과를 쓰지 않는 호출은 [void] 로 버립니다(호출 4곳 전부 -
#   반환값 정의·4곳 단언은 test_abyss_custom_worker). 이 단언은 본류 호출의 모양만 W5 로 바꿨고 '클리어·보상 문맥에서만' 은 그대로입니다
Check-Equal "배선: 본류 마커는 clear/reward 문맥에서만" ([bool]($src -match "customCleanupOnly -and \(\`$clearOutcome -eq 'clear' -or \`$clearOutcome -eq 'reward'\)\) \{\s*\[void\]\(Write-CustomClearMarker\)")) 'True'
# 2.10 W3: 어비스 완료 기록(cleared)은 마커 블록 바로 뒤 · 나가기 헬퍼 바로 앞의 별도 if 이고, 조건 = 클리어·보상 문맥 ∧ 정리 전용 아님(커스텀·비커스텀
#   모두 - 마커를 썼는지와 무관). 마커 블록 안에 넣으면 비커스텀·마커 실패 판이 빠지고, 헬퍼 뒤로 가면 나가기 위치 미발견 코드 4(클리어 뒤 정지)의 근거가
#   사라집니다. 호출은 워커 전체에 1곳(보상·클리어 화면 시작 분기는 기록하지 않음 - 명세 J1)
Check-Equal '배선(2.10 W3): 마커 블록 → 완료 기록 if(조건 = clear/reward ∧ 정리 전용 아님) → 나가기 헬퍼 순 · 호출 1곳' (
  ([bool]($src -match "customCleanupOnly -and \(\`$clearOutcome -eq 'clear' -or \`$clearOutcome -eq 'reward'\)\) \{\s*\[void\]\(Write-CustomClearMarker\)\s*\}\s*if \(\(\`$clearOutcome -eq 'clear' -or \`$clearOutcome -eq 'reward'\) -and -not \(\`$script:customMode -and \`$script:customCleanupOnly\)\) \{\s*Add-AbyssJournalClearedEntry\s*\}\s*\[void\]\(Invoke-AbyssExitClick -Game \`$game ")) -and
  ([regex]::Matches($src, 'Add-AbyssJournalClearedEntry').Count -eq 2)) 'True'
$ret = Body 'Return-ToAbyssSelection'
Check-Equal '배선: 복귀 루프 - 재매칭·준비·접힌 준비 패널이면 대기 (선택 화면 판정보다 앞)' (($ret.IndexOf('Get-AbyssPanelKind -Game $Game') -gt 0) -and ($ret.IndexOf('Get-AbyssPanelKind -Game $Game') -lt $ret.IndexOf('if (Test-AbyssSelectionScreen -Game $Game) {')) -and ([bool]($ret -match '\$entryWaitingNow = \(\$panelKindNow -eq ''none''\) -and \(-not \$script:screenCaptureFailing\) -and \(Test-AbyssEntryWaiting -Game \$Game\)'))) 'True'
# ⑥e 설계 2.13: 만료 판정 산술이 Get-YieldAdjustedDeadline → Get-FreezeAdjustedDeadline(양보 + 캡처 실패 누적 차분 - 같은 회전 실패 → 복구의 실패 시간도 뺌)
Check-Equal '배선(⑥a): 복귀 루프 - 패널 분기 안에서 이 패널 표본이 유효할 때만(플래그·일련번호) 마감 판정, 준비·접힌 패널이면 진단 + 코드 4, 재매칭이면 break → 기존 throw' ([bool]($ret -match 'if \(\$panelKindNow -ne ''none'' -or \$entryWaitingNow\) \{\s*if \(\(-not \$script:screenCaptureFailing\) -and \(\$script:captureFailSerial -eq \$turnSerial\) -and\s*\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline[^\r\n]*\)\) \{\s*if \(\$panelKindNow -eq ''ready'' -or \$entryWaitingNow\) \{[\s\S]{0,700}exit 4\s*\}\s*break\s*\}')) 'True'
Check-Equal '배선: 복귀 루프 - 던전 안(HUD+추적기) 2연속·20초면 ESC 금지 + 진단 + 코드 4' ([bool]($ret -match 'if \(\$questNow\) \{[\s\S]{0,700}\$insideStreak -ge 2 -and[\s\S]{0,120}TotalSeconds -ge 20[\s\S]{0,300}Write-LifeDiagnostics[\s\S]{0,500}exit 4')) 'True'
Check-Equal '배선: 복귀 루프 - 필드를 직접 확인(fieldProven)한 뒤에만 메뉴 어비스 클릭, 아니면 전면 확인 ESC 로 닫고 재확인(전송 성공만 계수, 3회 상한 코드 4)' ([bool]($ret -match 'if \(-not \$fieldProven\) \{[\s\S]{0,300}\$menuCloseTries -ge 3[\s\S]{0,500}exit 4[\s\S]{0,700}if \(Press-KeyVerified -Game \$Game -VirtualKey 0x1B[^\r\n]*\) \{\s*\$menuCloseTries\+\+')) 'True'
Check-Equal '배선: 복귀 루프 - fieldProven 은 필드 확인 뒤 ESC 클릭이 실제 전송됐을 때만 발급' ([bool]($ret -match 'Write-RunLog ''\[어비스\] ESC 클릭''\s*\$fieldProven = \$true')) 'True'
# 2026-09-30 ⑥e 설계 2.14: 양보 앞 폐기 줄 끝에 선택 화면 출처 폐기('; $selectionExpected = $false')가 같은 줄로 붙어 두 번째 조항의 줄 끝을 [^\r\n]* 로
#   넓힙니다 - 토큰·연속 수 폐기가 양보 호출 바로 앞 줄에 있어야 한다는 뜻은 그대로이고, 출처 폐기는 아래 ③ 의 '양보 호출 수 = 출처 폐기 줄 수' 가 봅니다
# 2026-10-07 ESC 메뉴 '어비스' 아이콘 폴백 (설계 v2 10.4): 클릭 로그의 탐색 출처가 고정 글자 '글자 탐색' 에서 변수 $abyssMenuFoundBy 로 바뀌어
#   (글자 탐색 성공 = '글자 탐색' / 아이콘 found = '아이콘 탐색') 이 단언과 아래 출처 발급 단언의 접두를 '\(\$abyssMenuFoundBy 화면좌표' 로 바꿨습니다 -
#   클릭 블록은 그대로 하나이고(복제 금지), 클릭 로그 바로 다음 줄이 토큰 소비라는 뜻은 같습니다
Check-Equal '배선: 복귀 루프 - 양보·캡처 실패·재매칭 패널·던전 안에서 토큰 폐기, 어비스 클릭에서 소비' (([regex]::Matches($ret, '\$fieldProven = \$false').Count -ge 5) -and ([bool]($ret -match '\$fieldProven = \$false; \$insideStreak = 0; \$insideSince = \$null[^\r\n]*\s*Invoke-UserYieldWithDeadline')) -and ([bool]($ret -match '어비스 메뉴 클릭 \(\$abyssMenuFoundBy 화면좌표[^\r\n]*\r?\n\s*\$fieldProven = \$false'))) 'True'
# 탐색 출처 대입 (설계 v2 10.4 · 7.4): '글자 탐색' 은 글자 탐색(Find-GameTextPoint '어비스') 바로 다음 문장 1곳 - 아이콘 found 가 아니면 클릭 로그는
#   항상 '글자 탐색' 이어야 합니다. '아이콘 탐색' 은 아이콘 결과가 found 인 블록 안(중첩 블록 밖) 1곳 - 다른 자리에서 대입하면 글자로 찾은 클릭이
#   '아이콘 탐색' 으로 찍히거나(로그 거짓) 아이콘 클릭이 '글자 탐색' 으로 남습니다 (워커 전체 기준 각 1곳, 주석 뺀 사본)
Check-Equal "배선(설계 v2 10.4): 탐색 출처 '글자 탐색' 대입은 워커 전체 1곳이고 메뉴 '어비스' 글자 탐색 바로 다음 문장" (
  ([regex]::Matches($src, "\`$abyssMenuFoundBy = '글자 탐색'").Count -eq 1) -and
  ([bool]($ret -match "\`$abyssMenuPoint = Find-GameTextPoint -Game \`$Game -ReferenceX \`$rgAbyssMenu\[0\][^\r\n]*(?:\r?\n[^\r\n]*)?-SearchText '어비스' -ExactText '어비스' -Scale 4\s*\r?\n\s*\`$abyssMenuFoundBy = '글자 탐색'"))) 'True'
Check-Equal "배선(설계 v2 10.4): 탐색 출처 '아이콘 탐색' 대입은 워커 전체 1곳이고 아이콘 결과 found 블록 안 (중첩 블록 밖)" (
  ([regex]::Matches($src, "\`$abyssMenuFoundBy = '아이콘 탐색'").Count -eq 1) -and
  ([bool]($ret -match "if \(\`$abyssMenuIcon\.Status -eq 'found'\) \{[^{}]*\`$abyssMenuFoundBy = '아이콘 탐색'"))) 'True'
$retLoop = $ret.Substring($ret.IndexOf('while ($true) {'))
# ⑥e 설계 2.13 (09-30 리뷰4·리뷰5 ②): 만료 판정은 5곳 모두 `(Get-Date) -ge (Get-FreezeAdjustedDeadline -Deadline ([ref]$deadline) …` 형입니다 - 표식 블록·
#   패널 분기·출처 없는 선택 화면·복구 회전·일반. 플래그·일련번호 조건은 기존 둘(패널 분기·일반) 그대로이고, 순서(패널 판독 < 패널 분기 판정 / 선택 화면 판정
#   < 마지막 판정 < 메뉴 분기)는 이 형의 IndexOf·LastIndexOf 로 찾습니다 - 4) 분기의 호출 직전 조정은 '-ge' 형이 아니라 잡히지 않습니다.
#   옛 산술 Get-YieldAdjustedDeadline 은 0건 (되돌리면 같은 회전 실패 → 복구의 실패 시간이 마감에서 빠지지 않음 - 행동으로는 하니스와 동치라 여기서 잡음)
$retDeadlineForm = '(Get-Date) -ge (Get-FreezeAdjustedDeadline -Deadline ([ref]$deadline)'
$retGuardedForm = '\(-not \$script:screenCaptureFailing\) -and \(\$script:captureFailSerial -eq \$turnSerial\) -and\s*\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$deadline\)'
$retGuardedFirst = [regex]::Match($retLoop, $retGuardedForm).Index
Check-Equal '배선: 복귀 루프 - while(\$true) + 만료 판정 5곳(Get-FreezeAdjustedDeadline 형)은 양보 게이트 뒤·이 회전 판독 뒤에만, 캡처 실패 중·실패 표본에서는 판정 안 함(플래그·일련번호 조건 2곳), 일반 만료는 성공(선택 화면) 판정 뒤 (⑥a 구현 리뷰 1·2차 P1 · ⑥e 2.13)' (
  ($retLoop.IndexOf('if (Test-UserRecentlyActive) {') -gt 0) -and ($retLoop.IndexOf('if (Test-UserRecentlyActive) {') -lt $retLoop.IndexOf('$panelKindNow = Get-AbyssPanelKind')) -and
  ([regex]::Matches($retLoop, [regex]::Escape($retDeadlineForm)).Count -eq 5) -and ([regex]::Matches($retLoop, $retGuardedForm).Count -eq 2) -and
  ($retLoop.IndexOf('$panelKindNow = Get-AbyssPanelKind') -lt $retGuardedFirst) -and
  ($retLoop.IndexOf('if (Test-AbyssSelectionScreen -Game $Game) {') -lt $retLoop.LastIndexOf($retDeadlineForm)) -and
  ($retLoop.LastIndexOf($retDeadlineForm) -lt $retLoop.IndexOf('if (Test-AbyssMenu -Game $Game) {')) -and ($ret.IndexOf('Get-YieldAdjustedDeadline') -lt 0)) 'True'
# 복구 회전 블록 (⑥e 설계 2.13, ㉻): 판독(패널·선택 화면) 도중 실패했다가 이미 복구된 회전은 판정·조작 없이 조정 마감만 → break, 700ms, continue.
#   ⑥a 는 이 회전을 두 만료 판정의 일련번호 조건으로 건너뛴 채 뒤 분기로 보내, 같은 회전 복구가 매 회전 이어지면 마감에 영영 닿지 않았습니다(RL1).
#   선택 화면 판정(1)) 뒤·일반 판정 앞입니다 - 양성은 이 회전의 마지막 실패 뒤 새로 찍은 성공 캡처 셋이라 무효 표본이 아님(09-30 리뷰4 P3-1)
$retRecovered = [regex]::Match($retLoop, 'if \(\(-not \$script:screenCaptureFailing\) -and \$script:captureFailSerial -ne \$turnSerial\) \{\s*if \(\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$deadline\)[^\r\n]*\)\) \{ break \}\s*Start-Sleep -Milliseconds 700\s*continue\s*\}')
Check-Equal '배선(⑥e 2.13): 복귀 루프 복구 회전 블록 - 조정 마감이면 break, 아니면 700ms + continue, 선택 화면 판정 뒤·일반 판정 앞' (
  $retRecovered.Success -and ($retLoop.IndexOf('if (Test-AbyssSelectionScreen -Game $Game) {') -lt $retRecovered.Index) -and ($retRecovered.Index -lt $retLoop.LastIndexOf($retDeadlineForm))) 'True'
# 판정 자리 끝냄 (⑥e 설계 2.13 - 반영본 검증, 09-30 리뷰4): 판정 자리까지 실패가 이어진 회전은 뒤 판독(메뉴·HUD·보상 - 성공이면 플래그를 풂) 없이 끝냅니다 -
#   같은 한 줄이 HUD 분기·5) 분기에도 있어 개수가 아니라 위치(일반 판정 뒤 첫 줄이 메뉴 분기 앞)로 봅니다
$retFinishLine = 'if ($script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial) { Start-Sleep -Milliseconds 700; continue }'
$retFinishAt = $retLoop.IndexOf($retFinishLine, [Math]::Max(0, $retLoop.LastIndexOf($retDeadlineForm)))
Check-Equal '배선(⑥e 2.13): 복귀 루프 판정 자리 끝냄 - 일반 판정 뒤 첫 실패 회전 끝냄 줄이 메뉴 분기 앞' (($retFinishAt -gt 0) -and ($retFinishAt -lt $retLoop.IndexOf('if (Test-AbyssMenu -Game $Game) {'))) 'True'
# 4) 분기 (⑥e 설계 2.13 - 09-30 리뷰4 P1-2): 호출 직전 조정 마감 1곳 → 헬퍼 -ParentDeadline → 다음 줄 'expired' 면 break. 헬퍼 FrozenMs 는 더하지 않음
#   (만료 판정이 캡처 실패 누적 차분이라 이중 가산 - ⑥a 필드 복귀 루프의 선례, 옛 186 단언이 이 자리로 옴)
Check-Equal "배선(⑥e 2.13): 복귀 루프 4) 분기 - 호출 직전 조정 마감을 부모 마감으로 넘기고 'expired' 는 다음 줄에서 break, 루프 본문 FrozenMs 0건" (
  ([regex]::Matches($retLoop, '\$exitParentDeadline = Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$deadline\)').Count -eq 1) -and
  ([bool]($retLoop -match '\$exitParentDeadline = Get-FreezeAdjustedDeadline[^\r\n]*\s*\$exitClick = Invoke-AbyssExitClick -Game \$Game [^\r\n]*-ParentDeadline \$exitParentDeadline\s*if \(\$exitClick\.Result -eq ''expired''\) \{ break \}')) -and
  ([regex]::Matches($ret, 'FrozenMs').Count -eq 0)) 'True'
Check-Equal '배선: 복귀 루프 - HUD·추적기 두 판독 사이 캡처 실패(일련번호)면 그 표본으로 판정하지 않음' ([bool]($ret -match '\$questNow = Test-InDungeonQuest -Game \$Game\s*if \(\$script:screenCaptureFailing -or \$script:captureFailSerial -ne \$turnSerial\) \{ continue \}')) 'True'
$helper = Body 'Invoke-AbyssExitClick'
# ⑥e 설계 2.13·2.14 ④: 헬퍼 복구 회전 블록 조건은 '탐침 복구 뒤 또는 같은 회전 복구'(닫는 괄호 둘 - 옛 `…-ne \$turnSerial\) \{` 로는 맞지 않음).
#   부모 마감이 있는 호출은 그 회전에 부모 마감 분기(부모 마감 있음 < 조작 양보 < 선택 화면 → 'selection' < 조정 마감 < 'expired')를 거친 뒤 300ms < 단독 줄 continue.
#   블록은 주석 포함 약 1449자(구현 뒤 실측) - 창 2400
$helperRb = [regex]::Match($helper, 'if \(\$probeRecovered -or \(-not \$script:screenCaptureFailing -and \$script:captureFailSerial -ne \$turnSerial\)\) \{[\s\S]{0,2400}?Start-Sleep -Milliseconds 300\s*\r?\n\s*continue\s*\r?\n\s*\}')
$hb = $helperRb.Value
$hbOrder = @('if ($null -ne $ParentDeadline) {', 'if (Test-UserRecentlyActive)', "if (`$passed -eq '선택 화면') {", "Result = 'selection'", 'Get-FreezeAdjustedDeadline', "Result = 'expired'", 'Start-Sleep -Milliseconds 300') | ForEach-Object { $hb.IndexOf($_) }
$hbOrdered = ($hbOrder[0] -ge 0) -and (@(0..($hbOrder.Count - 2) | Where-Object { $hbOrder[$_] -ge $hbOrder[$_ + 1] }).Count -eq 0)
Check-Equal '배선: 캡처 실패 일련번호 - Register-CaptureFailure 가 증가, 나가기 헬퍼는 실패가 있던 회전(같은 회전 복구·탐침 복구 뒤)을 판정 없이 넘기고, 부모 마감이 있으면 양보 → 선택 화면 → 조정 마감 순 (⑥e 2.13)' (
  ([bool]($src -match '\$script:captureFailSerial\+\+')) -and $helperRb.Success -and $hbOrdered) 'True'
Check-Equal '배선: 나가기 헬퍼 gone 증거에 ESC 메뉴 없음' ([regex]::Matches($helper, 'Test-AbyssMenu').Count) 0
Check-Equal "배선(⑥e 2.14 ④): 나가기 헬퍼 Result = 'gone' 은 선택 화면 조건 아래 0건 (선택 화면은 'selection' - 워커가 연 화면인지는 복귀 루프의 출처가 판정)" ([regex]::Matches($helper, "if \(\`$passed -eq '선택 화면'\) \{[^}]*Result = 'gone'").Count) 0
Check-Equal '배선: 나가기 헬퍼 필드 증거 = HUD + 추적기 던전명 없음 2연속 - 표본은 판독에서, 연속 수 갱신은 일련번호·동결 검사 뒤 (2차 P2)' (([bool]($helper -match 'elseif \(Test-HomeEndEscHud -Game \$Game\) \{\s*\$questNow = Test-InDungeonQuest[^\r\n]*\s*if \(-not \$script:screenCaptureFailing\) \{ \$fieldSample = \$\(if \(\$questNow\) \{ ''inside'' \} else \{ ''field'' \}\) \}')) -and ([bool]($helper -match 'if \(\$fieldSample -eq ''field''\) \{ \$fieldStreak\+\+ \} else \{ \$fieldStreak = 0 \}\s*if \(\$fieldStreak -ge 2\) \{ \$passed = ''필드 HUD'' \}')) -and ($helper.IndexOf('if ($fieldSample -eq ''field'')') -gt $helper.IndexOf('$script:captureFailSerial -ne $turnSerial'))) 'True'
Check-Equal "배선(⑥a 구현 리뷰 1차 P3): 나가기 헬퍼 판독 순서 = 하단('나가기' 위치) → 패널 → 클릭 - 뒤에 읽는 패널 판독이 클릭 게이트" (($helper.IndexOf('Find-AbyssExitButtonPoint -Game $Game') -gt 0) -and ($helper.IndexOf('Find-AbyssExitButtonPoint -Game $Game') -lt $helper.IndexOf('Get-AbyssPanelKind -Game $Game')) -and ($helper.IndexOf('Get-AbyssPanelKind -Game $Game') -lt $helper.IndexOf('Click-GamePoint -Game $Game'))) 'True'
Check-Equal "배선(2차 P2·⑥a): 나가기 헬퍼 - 위치 유무와 무관하게 회전마다 패널 판정 (준비 > 재매칭 > 접힌 패널=같은 회전 하단 판독문), 패널이면 후속 화면 판정 안 함" ([bool]($helper -match 'if \(-not \$script:screenCaptureFailing\) \{\s*\$panelKind = Get-AbyssPanelKind -Game \$Game\s*if \(\$panelKind -eq ''matching''\) \{ \$panelNow = ''matching'' \}\s*elseif \(\$panelKind -eq ''ready''\) \{ \$panelNow = ''ready-panel'' \}\s*elseif \(Test-AbyssEntryWaitingText -Text \$read\.Text\) \{ \$panelNow = ''entry-waiting'' \}\s*\}\s*if \(\(-not \$read\.Point\) -and \(-not \$panelNow\) -and \(-not \$script:screenCaptureFailing\)\) \{')) 'True'
Check-Equal "배선: 나가기 헬퍼 - 패널(재매칭·준비·접힌)이면 그 결과를 반환, 클릭 없음" ([bool]($helper -match "if \(\`$panelNow\) \{[\s\S]{0,900}return @\{ Result = \`$panelNow; FrozenMs = \`$frozenMs \}")) 'True'
# 창 {0,2600} → {0,5400} (⑥e 설계 2.12·5.2): 시작 패널 입장 대기에 스윕 참 분기 마감·판독 쪽 복구 회전 블록·서두 메타 비움·표식 회전 블록이 더해지고 서두 동결의
#   되돌림 세 줄이 빠져, 복구 전용 exit 4 → 입장 2연속 break 구간이 구현 뒤 실측 5213자(주석 포함 - Remove-SourceComments 는 주석을 같은 길이의 공백으로 바꿈)
Check-Equal '배선: 시작 디스패치 - 재매칭·준비·접힌 준비 패널이면 취소·나가기 없이 입장 대기(HUD+추적기 2연속), 복구 전용은 코드 4' ([bool]($src -match '\$startMatchingDetected = \(\$startPanelKind -ne ''none''\) -or \$startEntryWaiting[\s\S]{0,400}customRecoveryOnly\) \{[\s\S]{0,400}exit 4[\s\S]{0,5400}\$startInsideStreak -ge 2\) \{ break \}')) 'True'
# ⑥e 설계 2.13 (반영본 검증, 09-30 리뷰3): 시작 패널 판정의 교대 모양 전용 한도 - '패널 판독 성공 → 하단 판독에서 실패 시작 → 다음 회전 동결 탐침 복구' 가 이어지면
#   유효 회전이 한 번도 오지 않아 끝나지 않았습니다(⑥a 회귀 - HEAD 는 판독 1회, SJ1). 동결 블록은 탐침 뒤 표식을 세우고, 다음 회전은 판독 없이 조작 양보 → 조정 한도
#   ($timeoutPartyMatch 를 빌림 - 새 한도 값 아님) → 진단 + 코드 4 / 2초. 판독 둘과 유효 회전 break 는 그대로
Check-Equal '배선(⑥a 구현 리뷰 1차 P1 · ⑥e 2.13): 시작 패널 판정은 판독이 모두 유효한 회전으로만 확정 - 실패 중 동결(안전 확인·복구 탐침·표식), 탐침 복구 뒤 회전은 판독 없이 조작 양보 → 조정 한도만, 실패 표본은 버리고 다시 읽음' ([bool]($src -match 'while \(\$true\) \{\s*\$startPanelSerial = \$script:captureFailSerial\s*if \(\$script:screenCaptureFailing\) \{\s*Test-SafeStopDuringCaptureFail\s*Start-Sleep -Seconds 2\s*\[void\]\(Test-CaptureRecovered -Game \$game\)\s*\$startPanelProbeRecovered = -not \$script:screenCaptureFailing\s*continue\s*\}\s*if \(\$startPanelProbeRecovered\) \{\s*if \(Test-UserRecentlyActive\) \{ Wait-UserYieldEnd -Game \$game -Context ''시작 패널 판정''; continue \}\s*\$startPanelProbeRecovered = \$false\s*if \(\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$startPanelLimitDeadline\)[^\r\n]*\)\) \{\s*Write-LifeDiagnostics -Game \$game -Context ''시작 패널 판정 불가'' -CaptureOnly\s*Write-RunLog[^\r\n]*\s*exit 4\s*\}\s*Start-Sleep -Seconds 2\s*continue\s*\}\s*\$startPanelKind = Get-AbyssPanelKind -Game \$game\s*\$startEntryWaiting = [^\r\n]*\s*if \(\(-not \$script:screenCaptureFailing\) -and \$script:captureFailSerial -eq \$startPanelSerial\) \{ break \}')) 'True'
# ⑥e 설계 2.11: 파티원 디스패치는 기타 분기 뒤·Clear-EventOverlay 앞입니다(생활·기타와 같은 이유 - 파티원이 시작하는 준비 패널·접힌 패널·파티원 보상·재매칭을
#   이벤트 정리가 '알 수 없는 화면' 으로 보고 누르지 않게). 조건에 커스텀 토큰 오류 제외(그때 customMode 는 거짓이고 config 매칭이 남음 - 리뷰 B4), 호출 뒤 throw
#   (반환 = 내부 오류). 그래서 시작 패널 대기의 옛 파티원 제외 항(-not $abyssPartyMemberRun)은 지웠습니다 - 파티원은 거기까지 오지 않습니다
$dispatchAt = $src.IndexOf('if ($abyssPartyMemberRun) {')
Check-Equal '배선(⑥e 2.11): 파티원 디스패치 - 기타 분기 뒤·Clear-EventOverlay 앞, customMode·customSpecInvalid 제외, 호출 뒤 throw, 옛 디스패치·시작 패널 대기 제외 항 0건' (
  ($dispatchAt -gt $src.IndexOf('Invoke-NyanMerchantRun -Game $game')) -and ($dispatchAt -lt $src.IndexOf('if (Clear-EventOverlay -Game $game) {')) -and
  ($src.IndexOf('$abyssPartyMemberRun = ') -lt $dispatchAt) -and
  ([bool]($src -match '\$abyssPartyMemberRun = \(\(-not \$script:customMode\) -and \(-not \$script:customSpecInvalid\) -and')) -and
  ([bool]($src -match 'if \(\$abyssPartyMemberRun\) \{\s*Invoke-AbyssPartyMemberCycle -Game \$game\s*throw ')) -and
  ([regex]::Matches($src, 'Invoke-AbyssPartyMemberCycle -Game').Count -eq 1) -and ([regex]::Matches($src, '-not \$abyssPartyMemberRun').Count -eq 0)) 'True'
$member = Body 'Invoke-AbyssPartyMemberCycle'
$leave = Body 'Invoke-AbyssMemberLeave'
$memberDp = $member + "`n" + $leave
# ⑥e: 옛 파티원 사이클(두 출구)의 배선 넷(필드 2연속 + 헬퍼 재클릭 / 옛 raw HUD Wait-ForScreen / 양보 뒤 연속 수 리셋·실패 표본 폐기 / 간접 양보)을 D·P 로
#   다시 씁니다. D·P 는 나가기 헬퍼를 쓰지 않습니다 - 커서가 가린 접힌 패널에서 헬퍼는 (492,654) = 던전 퇴장을 누릅니다(09-29 재생). 퇴장 확인은 퇴장 전이 표
Check-Equal '배선(⑥e): 파티원 D·P - 나가기 헬퍼(Invoke-AbyssExitClick)·3버튼 단독 판정(Test-ExitButton)·옛 raw HUD Wait-ForScreen 0건' (
  ([regex]::Matches($memberDp, 'Invoke-AbyssExitClick').Count -eq 0) -and ([regex]::Matches($memberDp, 'Test-ExitButton').Count -eq 0) -and
  (-not ($memberDp -match "Description '던전 밖\(필드\) 복귀'"))) 'True'
$memberReadAt = $member.IndexOf('$promptNow = Test-DungeonClearPrompt -Game $Game')
$memberValidityAt = $member.IndexOf('if ($script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial) {', [Math]::Max(0, $memberReadAt))
Check-Equal '배선(⑥e): 파티원 D·시작 재매칭 - 양보 뒤 연속 수 리셋, 실패 표본은 일련번호로 폐기(아직 실패 중이면 continue, 이미 복구면 복구 회전)' (
  ([bool]($member -match 'if \(Test-UserRecentlyActive\) \{ \$insideStreak = 0; \$fieldStreak = 0;[^\r\n]*Wait-UserYieldEnd -Game \$Game -Context ''파티원 대기''; continue \}')) -and
  ([bool]($member -match 'if \(\$script:screenCaptureFailing -or \$script:captureFailSerial -ne \$turnSerial\) \{\s*\$turnRecovered = -not \$script:screenCaptureFailing\s*if \(-not \$turnRecovered\) \{\s*continue\s*\}')) -and
  ([bool]($src -match '\$startInsideStreak = 0; Wait-UserYieldEnd'))) 'True'
Check-Equal '배선(2차 P2 · ⑥e): 시작 재매칭·파티원 D - 회전 안 간접 양보(누적 변수 차분)가 있으면 연속 수 새로' (
  ([bool]($src -match 'if \(\[double\]\$script:userYieldTotalMs -ne \$turnYieldMs\) \{ \$startInsideStreak = 0 \}')) -and
  ([bool]($member -match 'if \(\[double\]\$script:userYieldTotalMs -ne \$turnYieldMs\) \{ \$insideStreak = 0; \$fieldStreak = 0 \}'))) 'True'
Check-Equal '배선(2차 P1): 복귀 루프 - 토큰 발급 시 양보 누적·캡처 실패 일련번호 기준값을 함께 기록' ([bool]($ret -match '\$fieldProven = \$true[^\r\n]*\r?\n\s*\$fieldProvenYieldMs = \[double\]\$script:userYieldTotalMs; \$fieldProvenSerial = \$script:captureFailSerial')) 'True'
$retMenu = $ret.Substring($ret.IndexOf('if (Test-AbyssMenu -Game $Game) {'))
Check-Equal '배선(2차·3차 P1): 복귀 루프 - 메뉴 분기 진입 시 일련번호·양보 누적 어느 쪽이든 변했으면 토큰 폐기(재판독 아님), fieldProven 검사보다 앞' (([bool]($retMenu -match 'if \(\$fieldProven -and \(\(\$script:captureFailSerial -ne \$fieldProvenSerial\) -or \(\[double\]\$script:userYieldTotalMs -ne \$fieldProvenYieldMs\)\)\) \{\s*\$fieldProven = \$false')) -and ($retMenu.IndexOf('$fieldProvenYieldMs))) {') -lt $retMenu.IndexOf('if (-not $fieldProven) {'))) 'True'
$retYieldCalls = [regex]::Matches($ret, 'Invoke-UserYieldWithDeadline -Game \$Game').Count
$retYieldGuarded = [regex]::Matches($ret, '\$fieldProven = \$false[^\r\n]*\r?\n\s*Invoke-UserYieldWithDeadline -Game \$Game').Count
Check-Equal "배선(3차 P1): 복귀 루프 - 모든 양보 호출(${retYieldCalls}곳, 8곳 이상) 직전에 토큰 폐기 (누적 양보 차분이 0 인 경계 대비)" ("$retYieldGuarded/$([int]($retYieldCalls -ge 8))") "$retYieldCalls/1"
$startBlock = $src.Substring($src.IndexOf('$startMatchingDetected = '), $src.IndexOf('뒤 입장 완료 감지 - 이 판의 클리어 대기부터') - $src.IndexOf('$startMatchingDetected = '))
# ⑥e: 옛 파티원 필드 복귀 루프 쪽 단언은 D 로 - D 의 간접 양보 리셋(⑤)이 유효성 블록(⑥ - 실패 표본 폐기)보다 앞
Check-Equal '배선(3차 P2 · ⑥e): 시작 재매칭·파티원 D - 간접 양보 리셋이 실패 표본 폐기보다 앞 (같은 회전에 겹쳐도 옛 연속 수가 남지 않음)' ((($startBlock.IndexOf('-ne $turnYieldMs) { $startInsideStreak = 0 }') -gt 0) -and ($startBlock.IndexOf('-ne $turnYieldMs) { $startInsideStreak = 0 }') -lt $startBlock.IndexOf('-ne $turnSerial) { continue }'))) -and (($member.IndexOf('-ne $turnYieldMs) { $insideStreak = 0; $fieldStreak = 0 }') -gt 0) -and ($member.IndexOf('-ne $turnYieldMs) { $insideStreak = 0; $fieldStreak = 0 }') -lt $memberValidityAt))) 'True'
Check-Equal '배선(4차 P1): 복귀 루프 - ESC 전송 직전에 이 회전의 캡처 실패(플래그·일련번호)를 검사해 실패 회전은 전송 없이 재판독 (토큰 세탁 금지)' ([bool]($ret -match 'if \(\$script:screenCaptureFailing -or \$script:captureFailSerial -ne \$turnSerial\) \{ Start-Sleep -Milliseconds 700; continue \}\s*if \(\$escPoint\) \{')) 'True'
Check-Equal '배선(4차 P1·P2): 복귀 루프 - 보상 화면·복구 분기(이벤트/스텔라/알 수 없음) 진입 시 토큰·연속 수 폐기, 메뉴 분기는 연속 수 리셋' (([bool]($ret -match 'if \(Test-ExitButton -Game \$Game\) \{\s*\$unknownSince = \$null\s*\$fieldProven = \$false; \$insideStreak = 0; \$insideSince = \$null')) -and ([bool]($ret -match 'if \(-not \$script:screenCaptureFailing\) \{\s*\$fieldProven = \$false; \$insideStreak = 0; \$insideSince = \$null[^\r\n]*\s*if \(Invoke-EventSkipOrConfirm')) -and ([bool]($ret -match 'if \(Test-AbyssMenu -Game \$Game\) \{\s*\$unknownSince = \$null\s*\$insideStreak = 0; \$insideSince = \$null'))) 'True'
Check-Equal '배선(2차 P2): 복귀 루프 - 캡처 실패 동결 회전 길이만큼 던전 안 첫 확인 시각을 미룸' ([bool]($ret -match 'if \(\$null -ne \$insideSince\) \{ \$insideSince = \$insideSince\.AddMilliseconds\(\(\$turnNow - \$turnStart\)\.TotalMilliseconds\) \}')) 'True'
# ── 3b. ⑥e 복귀 루프 (설계 2.13·2.14 - 09-30 리뷰5 ①~⑤, 반영본 검증) ──
# ① 동결 블록 (P2-1): continue 형 - 양보 게이트 앞에서 입력 없는 복구 탐침. 옛 대기형은 캡처 실패 + 조작이면 조작이 끝날 때까지 캡처 시도가 0 이었고
#   (규칙 15 ⑤) 그 양보 대기와 흐르는 실패 누적이 같은 벽시계 시간을 마감에 두 번 더했습니다. 블록 안 순서 = 안전 확인 < 토큰·출처 폐기 < 던전 안 첫 확인
#   미룸 < 알 수 없음 시계 미룸 < turnStart 갱신 < 700ms < 탐침 < 표식 < 단독 줄 continue. 마감·기준값 대입 0건(되돌리면 실패 회전이 사이에 한 번씩
#   끼는 섞인 모양에서 마감이 영영 오지 않음 - 09-30 리뷰4 P1-1, RL2). 옛 '탐침 복구 뒤 블록'($turnStartFailing)·'탐침 자리 끝냄' 줄은 없음
$retFreeze = [regex]::Match($retLoop, '(?s)if \(\$script:screenCaptureFailing\) \{(.*?)\r?\n    \}')
$fb = $retFreeze.Groups[1].Value
$fbOrder = @('Test-SafeStopDuringCaptureFail', '$fieldProven = $false; $selectionExpected = $false', 'if ($null -ne $insideSince) { $insideSince = $insideSince.AddMilliseconds(',
  'if ($null -ne $unknownSince) { $unknownSince = $unknownSince.AddMilliseconds(', '$turnStart = $turnNow', 'Start-Sleep -Milliseconds 700', '[void](Test-CaptureRecovered -Game $Game)',
  '$returnFreezeRecovered = -not $script:screenCaptureFailing') | ForEach-Object { $fb.IndexOf($_) }
$fbOrdered = ($fbOrder[0] -ge 0) -and (@(0..($fbOrder.Count - 2) | Where-Object { $fbOrder[$_] -ge $fbOrder[$_ + 1] }).Count -eq 0)
Check-Equal '배선(⑥e 2.13 ①): 복귀 루프 동결 블록 = 안전 확인 < 토큰·출처 폐기 < insideSince·unknownSince 미룸 < turnStart 갱신 < 700ms < 복구 탐침 < 표식 < 단독 줄 continue, 마감·기준값 대입 0건' (
  $retFreeze.Success -and $fbOrdered -and ([bool]($fb -match '\$returnFreezeRecovered = -not \$script:screenCaptureFailing\s*\r?\n\s*continue\s*$')) -and
  (-not ($fb -match '\$deadline =|\$seenYieldMs =|\$seenFailMs ='))) 'True'
Check-Equal '배선(⑥e 2.13 ①): 복귀 루프 동결 블록 < 양보 게이트 < 표식 블록(표식 비움 → 조정 마감이면 break → 700ms → continue) < 패널 판독, 옛 탐침 복구 뒤 블록·탐침 자리 끝냄 0건, 캡처 실패 기준값은 루프 앞 1곳' (
  ($retFreeze.Index -lt $retLoop.IndexOf('if (Test-UserRecentlyActive) {')) -and
  ($retLoop.IndexOf('if (Test-UserRecentlyActive) {') -lt $retLoop.IndexOf('if ($returnFreezeRecovered) {')) -and
  ([bool]($retLoop -match 'if \(\$returnFreezeRecovered\) \{\s*\$returnFreezeRecovered = \$false\s*if \(\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$deadline\)[^\r\n]*\)\) \{ break \}\s*Start-Sleep -Milliseconds 700\s*continue\s*\}')) -and
  ($retLoop.IndexOf('if ($returnFreezeRecovered) {') -lt $retLoop.IndexOf('$panelKindNow = Get-AbyssPanelKind')) -and
  ($ret.IndexOf('$turnStartFailing') -lt 0) -and ([regex]::Matches($ret, '\$seenFailMs = Get-CaptureFailTotalMs').Count -eq 1) -and
  ($ret.IndexOf('$seenFailMs = Get-CaptureFailTotalMs') -lt $ret.IndexOf('while ($true) {'))) 'True'
# ③ 선택 화면 출처 (P1-1 · 사용자 결정 D7): 선택 화면 양성은 던전 밖의 증명이 아닙니다(오버레이는 전투 중에도 열리고 HUD·추적기를 가림 - 09-20 23:25 실사고).
#   완료는 '확정된 필드 → 워커 ESC → 메뉴 → 워커 어비스 클릭 전송' 이 끊김 없이 이어진 출처가 살아 있는 판독이 예약하고 회전 서두 한 곳에서 합니다
#   (마감 경계에서 선택 화면이 나타나면 성공이 먼저 - ⑥a 구현 리뷰 2차 P1). 출처 없는 선택 화면은 누르지 않고 조정 마감이면 진단 + 코드 4
Check-Equal '배선(⑥e 2.14 ③): 회전 서두 - turnNow 바로 뒤 필드 연속 이어받기 한 줄, 그 뒤 완료 블록(안전 중지 소비 → exit / 완료 로그 → return)이 동결 블록 앞, 완료 문자열·이어받기 줄 각 1곳' (
  ([bool]($retLoop -match '\$turnNow = Get-Date\s*\$fieldSettleAlive = \$fieldSettleNext; \$fieldSettleNext = \$false\s*if \(\$selectionConfirmed\) \{\s*if \(Test-Path -LiteralPath \$safeStopFlagPath\) \{[\s\S]{0,600}?exit \$SafeStopExitCode\s*\}\s*Write-RunLog ''\[어비스\] 선택 화면 복귀 확인''\s*return\s*\}')) -and
  ($retLoop.IndexOf('if ($selectionConfirmed) {') -lt $retFreeze.Index) -and
  ([regex]::Matches($ret, '선택 화면 복귀 확인').Count -eq 1) -and ([regex]::Matches($ret, '\$fieldSettleAlive = \$fieldSettleNext; \$fieldSettleNext = \$false').Count -eq 1)) 'True'
$retSel = [regex]::Match($retLoop, '(?s)if \(Test-AbyssSelectionScreen -Game \$Game\) \{(.*?)\r?\n    \}')
$sb = $retSel.Groups[1].Value
Check-Equal '배선(⑥e 2.14 ③): 1) 선택 화면 - 출처 유효(기준 = 회전 서두 turnSerial)면 완료 예약 + continue, 아니면 출처 폐기·안내 1회·조정 마감이면 진단 + exit 4, 2초 + continue, 누르는 것 0건, 복구 회전 블록보다 앞' (
  $retSel.Success -and ([bool]($sb -match 'if \(Test-AbyssSelectionProvenance -Expected \$selectionExpected -ExpectedSerial \$selectionExpectedSerial\s*`?\s*-ExpectedYieldMs \$selectionExpectedYieldMs -ReferenceSerial \$turnSerial -YieldMs \(\[double\]\$script:userYieldTotalMs\)\) \{\s*\$selectionConfirmed = \$true\s*continue\s*\}')) -and
  ([bool]($sb -match '\$selectionExpected = \$false;[^\r\n]*\s*if \(-not \$unprovenancedLogged\) \{[\s\S]{0,400}?if \(\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$deadline\)[^\r\n]*\)\) \{\s*Write-LifeDiagnostics -Game \$Game -Context ''어비스 복귀 중 출처 없는 선택 화면'' -CaptureOnly\s*Write-RunLog[^\r\n]*\s*exit 4\s*\}\s*Start-Sleep -Seconds 2\s*continue\s*$')) -and
  (-not ($sb -match 'Click-|Press-Key|Focus-Game')) -and $retRecovered.Success -and ($retSel.Index -lt $retRecovered.Index)) 'True'
Check-Equal '배선(⑥e 2.14 ③): 출처 발급 1곳 - 어비스 메뉴 클릭 전송 확인 로그·토큰 소비 뒤, 2초 대기 앞, 같은 줄에 기준값 둘(캡처 실패 일련번호·양보 누적)' (
  ([regex]::Matches($ret, '\$selectionExpected = \$true').Count -eq 1) -and
  ([bool]($ret -match '어비스 메뉴 클릭 \(\$abyssMenuFoundBy 화면좌표[^\r\n]*\r?\n\s*\$fieldProven = \$false\s*\$selectionExpected = \$true; \$selectionExpectedSerial = \$script:captureFailSerial; \$selectionExpectedYieldMs = \[double\]\$script:userYieldTotalMs\s*Start-Sleep -Seconds 2'))) 'True'
Check-Equal '배선(⑥e 2.14 ③): 확인 루프 - 그 시도의 판독 직전 일련번호로 출처를 보고 완료 예약 + break, 루프 뒤 완료 예약이면 오클릭 판정 없이 continue, 완료 예약 대입 = 초기화 1 + 확인 루프 1 + 1) 1' (
  ([bool]($ret -match '\$confirmSerial = \$script:captureFailSerial\s*if \(Test-AbyssSelectionScreen -Game \$Game\) \{\s*\$selectionConfirmed = Test-AbyssSelectionProvenance -Expected \$selectionExpected -ExpectedSerial \$selectionExpectedSerial\s*`?\s*-ExpectedYieldMs \$selectionExpectedYieldMs -ReferenceSerial \$confirmSerial -YieldMs \(\[double\]\$script:userYieldTotalMs\)\s*break\s*\}')) -and
  ($ret.IndexOf('if ($selectionConfirmed) { continue }') -gt 0) -and ($ret.IndexOf('if ($selectionConfirmed) { continue }') -lt $ret.IndexOf('-not (Test-AbyssSelectionScreen')) -and
  ([regex]::Matches($ret, '\$selectionConfirmed = ').Count -eq 3)) 'True'
$retYieldProvenance = [regex]::Matches($ret, '\$fieldProven = \$false[^\r\n]*\$selectionExpected = \$false[^\r\n]*\r?\n\s*Invoke-UserYieldWithDeadline -Game \$Game').Count
Check-Equal "배선(⑥e 2.14 ③): 모든 양보 호출(${retYieldCalls}곳) 앞 폐기 줄이 선택 화면 출처 폐기를 같은 줄에 담음 (누적 양보 차분이 0 인 경계에서도 fail-closed)" $retYieldProvenance $retYieldCalls
$escPrefix = $ret.Substring(0, [Math]::Max(0, $ret.IndexOf('Press-KeyOnce -VirtualKey 0x1B')))
$escPrev3 = ((($escPrefix -split "`n") | Select-Object -Last 4 | Select-Object -First 3) -join "`n")
Check-Equal '배선(⑥e 2.14 ③): 단계 전환 출처 폐기 - 패널 분기·메뉴 분기 첫 줄·HUD 분기 첫 줄·보상 분기·복구 분기, 오클릭 복구 ESC 바로 앞 3줄에는 없음(09-15 어비스 → 상세 → ESC → 선택 화면 경로 보존)' (
  ([bool]($ret -match '\$fieldProven = \$false; \$insideStreak = 0; \$insideSince = \$null; \$selectionExpected = \$false\s*Start-Sleep -Seconds 2\s*continue')) -and
  ([bool]($ret -match 'if \(Test-AbyssMenu -Game \$Game\) \{\s*\$unknownSince = \$null\s*\$insideStreak = 0; \$insideSince = \$null; \$selectionExpected = \$false')) -and
  ([bool]($ret -match 'if \(Test-HomeEndEscHud -Game \$Game\) \{\s*\$selectionExpected = \$false\s*\r?\n\s*\$questNow = Test-InDungeonQuest -Game \$Game')) -and
  ([bool]($ret -match 'if \(Test-ExitButton -Game \$Game\) \{\s*\$unknownSince = \$null\s*\$fieldProven = \$false; \$insideStreak = 0; \$insideSince = \$null; \$selectionExpected = \$false')) -and
  ([bool]($ret -match 'if \(-not \$script:screenCaptureFailing\) \{\s*\$fieldProven = \$false; \$insideStreak = 0; \$insideSince = \$null; \$selectionExpected = \$false\s*if \(Invoke-EventSkipOrConfirm')) -and
  ($escPrefix.Length -gt 0) -and (-not $escPrev3.Contains('$selectionExpected = $false'))) 'True'
# ⑤ 필드 확정(W)·실패 판독 가드 (⑥e 설계 2.14 - 반영본 검증, 09-30 리뷰5): 같은 두 판독(HUD·추적기)이 던전 안에서 필드 모양을 내는 일이 관측이라
#   (입장 직후 추적기 제목 반짝임 2.1~4.2초 · 보스 이펙트의 '정박' 누락 2연속) 1표본으로 ESC 를 보내면 던전 안 메뉴 → 워커 '어비스' → 출처 있는 완료가 됩니다.
#   필드 모양 유효 표본이 끊김 없이 2개 이상이고 첫 표본부터 W($memberFieldSettleSeconds) 이상일 때만 안전 중지 소비·공지 X·ESC 를 합니다
$retHud = $retLoop.Substring([Math]::Max(0, $retLoop.IndexOf('if (Test-HomeEndEscHud -Game $Game) {')))
$settle = [regex]::Match($retHud, '\$insideStreak = 0; \$insideSince = \$null[\s\S]*?if \(\$fieldSettleCount -lt 2 -or \(\$turnNow - \$fieldSettleSince\)\.TotalSeconds -lt \$memberFieldSettleSeconds\) \{\s*\$fieldSettleNext = \$true\s*Start-Sleep -Milliseconds 700\s*continue\s*\}')
$settleEnd = $settle.Index + $settle.Length
Check-Equal '배선(⑥e 2.14 ⑤): 필드 확정 - HUD 분기에서 필드 모양 2표본 이상·첫 표본부터 W 이상일 때만 진행(아니면 이어받기 표식 + 700ms + continue), 안전 중지 소비·공지 X·ESC 는 모두 그 뒤, 이어받기 표식 대입 1곳' (
  $settle.Success -and ($settleEnd -lt $retHud.IndexOf('Test-Path -LiteralPath $safeStopFlagPath')) -and ($settleEnd -lt $retHud.IndexOf('Test-NoticeBoardPopup')) -and
  ($settleEnd -lt $retHud.IndexOf("-SearchText 'ESC'")) -and ([regex]::Matches($ret, '\$fieldSettleNext = \$true').Count -eq 1)) 'True'
Check-Equal '배선(⑥e 2.14 ⑤): 오클릭 판정 - 세 판독 직전 일련번호(misclickSerial) 1곳, 조건 블록 첫 줄이 실패 회전 끝냄(오클릭 로그·진단·ESC 앞 - 실패한 음성으로 ESC 금지)' (
  ([regex]::Matches($ret, '\$misclickSerial = \$script:captureFailSerial').Count -eq 1) -and
  ([bool]($ret -match '\$misclickSerial = \$script:captureFailSerial\s*if \(-not \$script:screenCaptureFailing -and -not \(Test-AbyssSelectionScreen -Game \$Game\) -and\s*-not \(Test-AbyssMenu -Game \$Game\) -and -not \(Test-HomeEndEscHud -Game \$Game\)\) \{\s*if \(\$script:screenCaptureFailing -or \$script:captureFailSerial -ne \$misclickSerial\) \{ Start-Sleep -Milliseconds 700; continue \}\s*Write-RunLog ''\[어비스\] 어비스가 아닌 화면이 열렸습니다')) -and
  ($ret.IndexOf('-ne $misclickSerial) { Start-Sleep -Milliseconds 700; continue }') -lt $ret.IndexOf('Press-KeyOnce -VirtualKey 0x1B'))) 'True'
$ghostAt = $retLoop.IndexOf('if (Close-GhostRegisterPrompt -Game $Game')
$branch5Guard = $retLoop.IndexOf($retFinishLine, [Math]::Max(0, $ghostAt))
Check-Equal '배선(⑥e 2.14 ⑤): 5) 분기 - 고스트 안내 판독 뒤·알 수 없음 시계 앞에 실패 회전 끝냄 (X 후보 (1229,67) 를 실패한 음성으로 누르지 않음)' (
  ($ghostAt -gt 0) -and ($branch5Guard -gt $ghostAt) -and ($branch5Guard -lt $retLoop.IndexOf('if ($null -eq $unknownSince)'))) 'True'
$known = Body 'Test-KnownScreen'
Check-Equal '배선: 알려진 화면에 재매칭·준비 패널 포함 (이벤트 정리 X 클릭 방지)' ([bool]($known -match '\(Get-AbyssPanelKind -Game \$Game\) -ne ''none''\) \{ return \$true \}')) 'True'
Check-Equal '배선(⑥a V4-P2-3): 알려진 화면에 하단 한 번 판독으로 3버튼 보상·파티원 보상·접힌 준비 패널·권장 인원 팝업 등록' ([bool]($known -match '\$bottomText = Get-GameOcrText -Game \$Game\s*if \(\(Test-AbyssRewardText -Text \$bottomText\) -or \(Test-AbyssMemberRewardText -Text \$bottomText\) -or\s*\(Test-AbyssEntryWaitingText -Text \$bottomText\) -or \(Test-AbyssFewMembersPopupText -Text \$bottomText\)\) \{ return \$true \}')) 'True'

# ── 4. ⑥e 파티원 D·P + 시작 패널 대기 배선 (⑥a 두 출구 배선을 D·P 로 다시 씀 - 행동·세부 배선은 test_abyss_party_member) ──
# ⑥a 의 두 출구(S 터치 헬퍼 + 보상 '나가기' 뒤 필드 복귀 루프)·입장 대기·시작 판정 루프는 ⑥e(2026-09-30 설계 합의)에서 관측 루프 D 하나와 퇴장 절차 P
# 하나로 바뀌었습니다. 여기서는 ⑥a 가 이 파일에 걸어 둔 계약(입장 키 1곳·S 터치 1회·클릭 직전 새 판독·throw 없음·회전 순서·캡처 실패 누적 차분 마감)이
# D·P 에서도 그대로인지 봅니다 - 스윕 참 분기·복구 회전·퇴장 전이·경계 인계 등 세부는 tests\test_abyss_party_member.ps1 §3 이 봅니다.
Check-Equal '배선(⑥e): 입장 키(Invoke-AfterEntryKeys)는 D 의 입장 확정(던전 안 2연속) 뒤 1곳, P 0곳 - S 터치·퇴장 절차는 입장 키를 보내지 않음' (
  ([regex]::Matches($member, 'Invoke-AfterEntryKeys').Count -eq 1) -and ([regex]::Matches($leave, 'Invoke-AfterEntryKeys').Count -eq 0) -and
  ([bool]($member -match 'if \(\$screen -eq ''inside'' -and \$insideStreak -ge 2\) \{[\s\S]{0,2000}?Invoke-AfterEntryKeys -Game \$Game'))) 'True'
Check-Equal '배선(⑥e): S 터치는 판당 실제 전송 최대 1회 - 미전송·커서 예산 안에서만, 클릭 직전 새 판독 S → 패널 순(패널이 마지막 게이트), 전송 확인 뒤에만 전송 표시, 클릭 호출 1곳' (
  ([bool]($member -match 'if \(\(-not \$touchSent\) -and \$touchCursorMisses -lt 3\) \{[\s\S]{0,900}?\$freshPrompt = Test-DungeonClearPrompt -Game \$Game\s*\$freshPanel = [^\r\n]*Get-AbyssPanelKind -Game \$Game[\s\S]{0,400}?Click-GamePoint -Game \$Game -ReferenceX \$ptClearCenter\[0\][^\r\n]*\s*if \(\$script:lastClickPerformed\) \{\s*\$touchSent = \$true')) -and
  ([regex]::Matches($memberDp, 'Click-GamePoint -Game \$Game -ReferenceX \$ptClearCenter\[0\]').Count -eq 1)) 'True'
Check-Equal '배선(⑥e): D·P 에 throw·Invoke-ClickUntil 0건 - 모든 출구가 exit (한도는 진단 + 코드 4, 경계 인계는 코드 0)' (
  ([regex]::Matches($memberDp, '(?m)^\s*throw\b').Count -eq 0) -and ([regex]::Matches($memberDp, 'Invoke-ClickUntil').Count -eq 0)) 'True'
Check-Equal "배선(⑥a '11088 자리 2연속' · ⑥e): START 의 입장 확정은 던전 안(HUD + 추적기 - 분류 'inside') 2연속, 추적기 1회로 확정하는 옛 형태 0건" (
  ([bool]($member -match 'if \(\$screen -eq ''inside'' -and \$insideStreak -ge 2\) \{')) -and ([regex]::Matches($member, 'if \(Test-InDungeonQuest -Game \$Game\) \{ break \}').Count -eq 0)) 'True'
Check-Equal "배선(⑥e): '준비 완료' 는 D 의 화면 분류 'ready-available' 분기 1곳 - 직전 실제 전송에서 3초 이상, 전송 확인 뒤에만 전송 시각, 조작 생략은 양보 뒤 다음 회전(옛 좌표 재클릭 없음)" (
  ([bool]($member -match "if \(\`$screen -eq 'ready-available' -and [^{]*\(\(Get-Date\) - \`$readySendAt\)\.TotalSeconds -ge 3\)\) \{\s*Focus-Game -Game \`$Game\s*Click-GamePoint -Game \`$Game -ReferenceX \`$ptPartyEnter\[0\][^\r\n]*\s*if \(\`$script:lastClickPerformed\) \{\s*\`$readySendAt = Get-Date[\s\S]{0,1400}?\} elseif \(\`$script:lastClickSkipReason -eq 'user-active'\) \{\s*Wait-UserYieldEnd[^\r\n]*\s*continue")) -and
  ([regex]::Matches($memberDp, 'Click-GamePoint -Game \$Game -ReferenceX \$ptPartyEnter\[0\]').Count -eq 1)) 'True'
Check-Equal '배선(⑥e 2.10): 안전 중지 예약 소비는 P 의 Test-Path 참 분기 안(G 가 안전 중지일 때만)의 Remove-Item -Force -ErrorAction SilentlyContinue 형태만, D 0곳' (
  ([regex]::Matches($member, 'Remove-Item').Count -eq 0) -and ([regex]::Matches($leave, 'Remove-Item').Count -ge 1) -and
  ([regex]::Matches($leave, 'if \(\$ConsumeSafeStop -and [^\r\n]*\(Test-Path -LiteralPath \$safeStopFlagPath\)\) \{\s*Remove-Item -LiteralPath \$safeStopFlagPath -Force -ErrorAction SilentlyContinue').Count -eq [regex]::Matches($leave, 'Remove-Item').Count)) 'True'
Check-Equal '배선(⑥e): D·P 의 화면 판정은 순수 분류(Resolve-AbyssMemberScreen) 1곳씩 - 파티원 보상은 그 안의 게임 상태 판정(서명 + 패널 없음 + HUD 없음)' ("$([regex]::Matches($member, 'Resolve-AbyssMemberScreen').Count)/$([regex]::Matches($leave, 'Resolve-AbyssMemberScreen').Count)") '1/1'
$memberRewardFn = Body 'Test-AbyssMemberReward'
Check-Equal '배선(⑥a 설계 4.1 · 구현 리뷰 1차 P3): 파티원 보상 게임 상태 = 하단 서명 AND 패널 없음 AND HUD 없음 (입력으로 준 판독은 다시 읽지 않음)' (([bool]($memberRewardFn -match 'if \(-not \(Test-AbyssMemberRewardText -Text \$text\)\) \{ return \$false \}[\s\S]{0,300}if \(\$kind -ne ''none''\) \{ return \$false \}[\s\S]{0,300}return \(-not \$hud\)')) -and ([bool]($memberRewardFn -match 'if \(\$null -ne \$HudVisible\) \{ \[bool\]\$HudVisible \} else \{ Test-HomeEndEscHud -Game \$Game \}'))) 'True'
Check-Equal '배선(⑥a 구현 리뷰 1차 P1 · ⑥e): D·P 서두 동결 = 안전 확인 + 2초 + 복구 탐침 + 탐침 복구 표식 + 단독 줄 continue (마감·시계 대입 없음 - 여러 줄이라 stall 계수)' (
  ([bool]($member -match 'if \(\$script:screenCaptureFailing\) \{\s*Test-SafeStopDuringCaptureFail\s*Start-Sleep -Seconds 2\s*\[void\]\(Test-CaptureRecovered -Game \$Game\)\s*\$freezeRecovered = -not \$script:screenCaptureFailing\s*continue\s*\}')) -and
  ([bool]($leave -match 'if \(\$script:screenCaptureFailing\) \{\s*Test-SafeStopDuringCaptureFail\s*Start-Sleep -Seconds 2\s*\[void\]\(Test-CaptureRecovered -Game \$Game\)\s*\$freezeRecovered = -not \$script:screenCaptureFailing\s*continue\s*\}'))) 'True'
# 회전 순서 (⑥a 구현 리뷰 1차 P1): 동결 → 조작 양보 → 판독 → 판독 유효성(실패 표본 폐기) → 성공(분류) → 마감. 세 루프 모두 양보 게이트가 첫 판독보다, 실패 표본 폐기가
# 마감보다 앞. 시작 패널 대기는 마감·기준값 초기화부터 보는 범위입니다(아래 기준값 검사가 초기화를 봐야 함 - 09-30 리뷰3 로 범위를 넓힘)
$startWait = $startBlock.Substring([Math]::Max(0, $startBlock.IndexOf('$startMatchDeadline = (Get-Date)')))
$loopOrders = @(
  @{ Name = '파티원 D'; Body = $member; Read = '$promptNow = Test-DungeonClearPrompt -Game $Game'; Drop = 'if ($script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial) {'; Success = '$screen = Resolve-AbyssMemberScreen'; Deadline = 'Test-AbyssMemberClockExpired' },
  @{ Name = '퇴장 절차 P'; Body = $leave; Read = '$promptNow = Test-DungeonClearPrompt -Game $Game'; Drop = 'if ($script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial) {'; Success = '$screen = Resolve-AbyssMemberScreen'; Deadline = 'Test-AbyssMemberClockExpired' },
  @{ Name = '시작 패널 대기'; Body = $startWait; Read = 'Invoke-PurchasePopupSweep -Game $game'; Drop = '-ne $turnSerial) { continue }'; Success = 'if ($startInsideStreak -ge 2) { break }'; Deadline = 'Get-FreezeAdjustedDeadline -Deadline ([ref]$startMatchDeadline)' })
$orderBad = @()
foreach ($lo in $loopOrders) {
  $b = [string]$lo.Body
  $iYield = $b.IndexOf('if (Test-UserRecentlyActive)'); $iRead = $b.IndexOf($lo.Read); $iDrop = $b.IndexOf($lo.Drop, [Math]::Max(0, $iRead)); $iSuccess = $b.IndexOf($lo.Success); $iDeadline = $b.LastIndexOf($lo.Deadline)
  if (-not (($iYield -gt 0) -and ($iYield -lt $iRead) -and ($iRead -lt $iDrop) -and ($iDrop -lt $iSuccess) -and ($iSuccess -lt $iDeadline))) { $orderBad += "$($lo.Name)($iYield/$iRead/$iDrop/$iSuccess/$iDeadline)" }
}
Check-Equal '배선(⑥a 구현 리뷰 1·2차 P1 · ⑥e): 세 루프(파티원 D·퇴장 절차 P·시작 패널 대기) 회전 순서 = 양보 게이트 < 첫 판독 < 실패 표본 폐기 < 성공(분류) 판정 < 마감' ($orderBad -join ',') ''
$freezeBad = @()
$yieldOnly = @()
if ($startWait.IndexOf('Get-YieldAdjustedDeadline') -ge 0) { $yieldOnly += '시작 패널 대기' }
if ([regex]::Matches($startWait, [regex]::Escape('$startMatchSeenFailMs = Get-CaptureFailTotalMs')).Count -lt 1) { $freezeBad += '시작 패널 대기' }
foreach ($dp in @(@{ Name = '파티원 D'; Body = $member }, @{ Name = '퇴장 절차 P'; Body = $leave })) { if (([string]$dp.Body).IndexOf('Get-YieldAdjustedDeadline') -ge 0) { $yieldOnly += $dp.Name } }
Check-Equal '배선(⑥a 구현 리뷰 2차 P1 · ⑥e): 시작 패널 대기의 마감은 Get-FreezeAdjustedDeadline(양보 + 캡처 실패 누적 차분)만 쓰고 캡처 실패 기준값을 초기화, D·P 는 파티원 시계 헬퍼만(Get-YieldAdjustedDeadline 0건)' ("$($yieldOnly -join ',')|$($freezeBad -join ',')") '|'
# 마감 생성·재설정마다 양보·캡처 실패 기준값 갱신이 바로 뒤에 짝으로 붙음 (⑥a 구현 리뷰 3차 P2 - '한 번 이상 있음' 만 보면 초기 대입이 남아
# 있는 한 재설정 뒤 갱신을 지워도 통과했음. 갱신이 빠지면 되돌린 마감에 이미 반영된 실패 시간이 차분으로 한 번 더 더해짐 = 이중 가산)
# ⑥e: 시작 패널 대기는 서두 동결의 되돌림을 지워 2 → 1(시작만 - 설계 2.12: 되돌리면 복구 회전 사이에 실패 회전이 한 번씩 끼는 섞인 모양에서 마감이 영영
#   오지 않음, SP3), 시작 패널 판정의 교대 모양 한도 1(설계 2.13). S 터치·입장 대기·필드 복귀 셋은 D·P 로 바뀌어 파티원 시계(Set-AbyssMemberClock 한 곳 - 아래)로
$pairSpecs = @(
  @{ Name = '시작 패널 대기'; Body = $src; D = 'startMatchDeadline'; Y = 'startMatchSeenYieldMs'; F = 'startMatchSeenFailMs'; Expect = 1 },   # 시작만
  @{ Name = '시작 패널 판정'; Body = $src; D = 'startPanelLimitDeadline'; Y = 'startPanelSeenYieldMs'; F = 'startPanelSeenFailMs'; Expect = 1 })   # 시작만 (교대 모양 한도)
$pairBad = @()
foreach ($ps in $pairSpecs) {
  $b = [string]$ps.Body
  $resets = [regex]::Matches($b, '\$' + $ps.D + ' = \(Get-Date\)\.AddSeconds\(').Count
  $paired = [regex]::Matches($b, '\$' + $ps.D + ' = \(Get-Date\)\.AddSeconds\([^\r\n]*\)\s*\$' + $ps.Y + ' = \[double\]\$script:userYieldTotalMs\s*\$' + $ps.F + ' = Get-CaptureFailTotalMs').Count
  if (($resets -ne $ps.Expect) -or ($paired -ne $resets)) { $pairBad += "$($ps.Name)(재설정 $resets/짝 $paired/기대 $($ps.Expect))" }
}
Check-Equal '배선(⑥a 구현 리뷰 3차 P2 · ⑥e): 시작 패널 대기·판정의 마감 생성·재설정마다 양보·캡처 실패 기준값 갱신이 바로 뒤에 짝 (재설정 개수 고정 + 전부 짝)' ($pairBad -join ',') ''
$setClockFn = Body 'Set-AbyssMemberClock'
Check-Equal '배선(⑥e 2.1): 파티원 시계의 마감·양보 기준값·캡처 실패 기준값은 Set-AbyssMemberClock 한 곳에서 짝으로 갱신, D·P 에 마감 직접 대입((Get-Date).AddSeconds·.Deadline =) 0건' (
  ([bool]($setClockFn -match '\$Clock\.Deadline = \(Get-Date\)\.AddMilliseconds\(\$setMs\)\s*\$Clock\.SeenYieldMs = \[double\]\$script:userYieldTotalMs\s*\$Clock\.SeenFailMs = Get-CaptureFailTotalMs')) -and
  ([regex]::Matches($memberDp, '\(Get-Date\)\.AddSeconds\(').Count -eq 0) -and ([regex]::Matches($memberDp, '\.Deadline = ').Count -eq 0)) 'True'
$freezeFn = Body 'Get-FreezeAdjustedDeadline'
Check-Equal '배선(⑥a 구현 리뷰 2차 P1): Get-FreezeAdjustedDeadline = 양보 차분(Get-YieldAdjustedDeadline) + 캡처 실패 누적 차분(Get-CaptureFailTotalMs), 기준값 갱신으로 이중 가산 없음' (([bool]($freezeFn -match 'Get-YieldAdjustedDeadline -Deadline \$Deadline -SeenYieldMs \$SeenYieldMs')) -and ([bool]($freezeFn -match '\$failDelta = \(Get-CaptureFailTotalMs\) - \[double\]\$SeenCaptureFailMs\.Value\s*if \(\$failDelta -gt 0\) \{\s*\$Deadline\.Value = \$Deadline\.Value\.AddMilliseconds\(\$failDelta\)\s*\$SeenCaptureFailMs\.Value = [^\r\n]*\+ \$failDelta'))) 'True'
Check-Equal '배선(⑥e): D·P 는 나가기 헬퍼를 쓰지 않아 FrozenMs 0건 (복귀 루프의 FrozenMs 0건은 3절 4) 분기 단언)' ([regex]::Matches($memberDp, 'FrozenMs').Count) 0
# 시작 패널 입장 대기 (⑥e 설계 2.12 - ⑥a 회귀 수정): 회전 서두 메타 비움(규칙 4), 서두 동결은 마감을 되돌리지 않고 탐침 뒤 표식, 표식 회전·스윕 참(조작 생략·아직
#   실패 중 제외)·판독 도중 복구 회전도 조정 마감을 봅니다 - 닫히지 않는 팝업 + 커서 확인 실패, 같은 회전 복구, 교대 모양이 이어지면 옛 루프는 마감에 닿지
#   않았습니다(SP1~SP4). 조작 생략·아직 실패 중인 회전은 마감을 보지 않습니다(⑥a 구현 리뷰 1차 P1 의 순서 원칙 - 규칙 4·15)
Check-Equal '배선(⑥e 2.12): 시작 패널 대기 서두 - turnSerial 바로 뒤 메타 비움, 동결 블록 = 안전 확인 + 2초 + 탐침 + 표식 + continue (마감 되돌림 0건 - 마감 대입은 시작 1곳)' (
  ([bool]($startWait -match '\$turnSerial = \$script:captureFailSerial\s*\$script:lastClickSkipReason = ''''\s*if \(\$script:screenCaptureFailing\) \{\s*Test-SafeStopDuringCaptureFail\s*Start-Sleep -Seconds 2\s*\[void\]\(Test-CaptureRecovered -Game \$game\)\s*\$startFreezeRecovered = -not \$script:screenCaptureFailing\s*continue\s*\}')) -and
  ([regex]::Matches($startWait, '\$startMatchDeadline = ').Count -eq 1)) 'True'
$swYield = $startWait.IndexOf('if (Test-UserRecentlyActive)'); $swMarker = $startWait.IndexOf('if ($startFreezeRecovered) {'); $swSweep = $startWait.IndexOf('if (Invoke-PurchasePopupSweep -Game $game) {')
Check-Equal '배선(⑥e 2.12): 시작 패널 대기 표식 블록 - 양보 게이트 뒤·스윕 앞, 표식 비움 → 조정 마감이면 진단 + exit 4 → 2초 → continue (스윕·판독 없이 마감만)' (
  ($swYield -gt 0) -and ($swYield -lt $swMarker) -and ($swMarker -lt $swSweep) -and
  ([bool]($startWait -match 'if \(\$startFreezeRecovered\) \{\s*\$startFreezeRecovered = \$false\s*if \(\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$startMatchDeadline\)[^\r\n]*\)\) \{\s*Write-LifeDiagnostics -Game \$game -Context ''시작 패널 입장 대기 초과'' -CaptureOnly\s*Write-RunLog[^\r\n]*\s*exit 4\s*\}\s*Start-Sleep -Seconds 2\s*continue\s*\}'))) 'True'
Check-Equal '배선(⑥e 2.12): 시작 패널 대기 스윕 참 분기 - 조작 생략·아직 실패 중이면 continue(마감 판정 앞), 그 밖은 조정 마감이면 (팝업) 진단 + exit 4, 스윕 도중 복구면 2초, 분기 끝 continue' (
  [bool]($startWait -match 'if \(Invoke-PurchasePopupSweep -Game \$game\) \{\s*\$startInsideStreak = 0\s*\$startSweepYielded = \(-not \$script:lastClickPerformed\) -and \$script:lastClickSkipReason -eq ''user-active''\s*if \(\$startSweepYielded -or \$script:screenCaptureFailing\) \{\s*continue\s*\}\s*if \(\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$startMatchDeadline\)[^\r\n]*\)\) \{\s*Write-LifeDiagnostics -Game \$game -Context ''시작 패널 입장 대기 초과\(팝업\)'' -CaptureOnly\s*Write-RunLog[^\r\n]*\s*exit 4\s*\}\s*if \(\$script:captureFailSerial -ne \$turnSerial\) \{\s*Start-Sleep -Seconds 2\s*\}\s*continue\s*\}')) 'True'
$swReset = $startWait.IndexOf('-ne $turnYieldMs) { $startInsideStreak = 0 }')
$swRecovered = $startWait.IndexOf('if ((-not $script:screenCaptureFailing) -and $script:captureFailSerial -ne $turnSerial) {')
$swDrop = $startWait.IndexOf('if ($script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial) { continue }')
Check-Equal '배선(⑥e 2.12): 시작 패널 대기 판독 쪽 복구 회전 블록 - 간접 양보 리셋 뒤·실패 표본 폐기 줄 앞, 조정 마감이면 진단 + exit 4 / 아니면 2초' (
  ($swReset -gt 0) -and ($swReset -lt $swRecovered) -and ($swRecovered -lt $swDrop) -and
  ([bool]($startWait -match 'if \(\(-not \$script:screenCaptureFailing\) -and \$script:captureFailSerial -ne \$turnSerial\) \{\s*if \(\(Get-Date\) -ge \(Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$startMatchDeadline\)[^\r\n]*\)\) \{\s*Write-LifeDiagnostics[^\r\n]*\s*Write-RunLog[^\r\n]*\s*exit 4\s*\}\s*Start-Sleep -Seconds 2\s*\}'))) 'True'
Check-Equal '배선(⑥e 2.12): 시작 패널 대기의 조정 마감 판정 4곳 (표식 회전·스윕 참·판독 도중 복구·일반)' ([regex]::Matches($startWait, 'Get-FreezeAdjustedDeadline -Deadline \(\[ref\]\$startMatchDeadline\)').Count) 4

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0