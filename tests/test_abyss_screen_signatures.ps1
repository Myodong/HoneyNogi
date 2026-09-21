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
#      선택 화면 또는 HUD+추적기 없음 2연속(ESC 메뉴 제외)이고 패널이면 'matching', 시작 디스패치는 패널이면 취소 없이 입장 대기,
#      파티원은 필드 2연속 + 보상 화면 재클릭, 알려진 화면에 패널 포함
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
Check-Equal '배선: 선택 화면 판정이 양성일 때 재매칭 패널을 배제하고, 배제 판독이 캡처 실패면 양성 반환 금지' ([bool]($sel -match '\$matchingNow = Test-AbyssMatchingPanel -Game \$Game\s*if \(\$script:screenCaptureFailing\) \{ return \$false \}\s*if \(\$matchingNow\) \{ return \$false \}\s*return \$true')) 'True'
$clearWait = Body 'Wait-ForDungeonClearScreen'
Check-Equal "배선: 클리어 감시는 'selection' 을 돌려주지 않음" ([regex]::Matches($clearWait, "return 'selection'").Count) 0
$cwMatching = $clearWait.IndexOf('if (Test-AbyssMatchingPanel -Game $Game) {'); $cwReward = $clearWait.IndexOf('if (Test-ExitButton -Game $Game) {'); $cwAmbiguous = $clearWait.IndexOf('$ambiguousOverlaySeen = $true')
Check-Equal '배선: 클리어 감시 어비스 분기 순서 = 재매칭 패널 → 보상 → 선택 화면 오버레이(불명)' (($cwMatching -gt 0) -and ($cwMatching -lt $cwReward) -and ($cwReward -lt $cwAmbiguous)) 'True'
Check-Equal '배선: 클리어 감시 마감 시 불명 오버레이·필드 관측이면 진단 + 코드 4' ([bool]($clearWait -match '\$ambiguousOverlaySeen -or \$fieldSeen\) \{[\s\S]{0,400}Write-LifeDiagnostics[\s\S]{0,600}exit 4')) 'True'
Check-Equal '배선: 클리어 감시 최종 탐침에 선택 화면 조항 없음 (있으면 불명 오버레이가 마감을 영영 넘김)' ([regex]::Matches($clearWait, 'Test-AbyssSelectionScreen -Game \$Game\) -and -not \(Test-HomeEndEscHud').Count) 0
Check-Equal '배선: 클리어 감시 필드 증거는 HUD + 추적기 던전명 없음 2연속' ([bool]($clearWait -match '\$questNow = Test-InDungeonQuest -Game \$Game[\s\S]{0,300}\$fieldStreak -ge 2')) 'True'
Check-Equal "배선: 본류 마커는 clear/reward 문맥에서만" ([bool]($src -match "customCleanupOnly -and \(\`$clearOutcome -eq 'clear' -or \`$clearOutcome -eq 'reward'\)\) \{\s*Write-CustomClearMarker")) 'True'
$ret = Body 'Return-ToAbyssSelection'
Check-Equal '배선: 복귀 루프 - 재매칭 패널이면 대기 (선택 화면 판정보다 앞)' (($ret.IndexOf('Test-AbyssMatchingPanel -Game $Game') -gt 0) -and ($ret.IndexOf('Test-AbyssMatchingPanel -Game $Game') -lt $ret.IndexOf('if (Test-AbyssSelectionScreen -Game $Game) {'))) 'True'
Check-Equal '배선: 복귀 루프 - 던전 안(HUD+추적기) 2연속·20초면 ESC 금지 + 진단 + 코드 4' ([bool]($ret -match 'if \(\$questNow\) \{[\s\S]{0,700}\$insideStreak -ge 2 -and[\s\S]{0,120}TotalSeconds -ge 20[\s\S]{0,300}Write-LifeDiagnostics[\s\S]{0,500}exit 4')) 'True'
Check-Equal '배선: 복귀 루프 - 필드를 직접 확인(fieldProven)한 뒤에만 메뉴 어비스 클릭, 아니면 전면 확인 ESC 로 닫고 재확인(전송 성공만 계수, 3회 상한 코드 4)' ([bool]($ret -match 'if \(-not \$fieldProven\) \{[\s\S]{0,300}\$menuCloseTries -ge 3[\s\S]{0,500}exit 4[\s\S]{0,700}if \(Press-KeyVerified -Game \$Game -VirtualKey 0x1B[^\r\n]*\) \{\s*\$menuCloseTries\+\+')) 'True'
Check-Equal '배선: 복귀 루프 - fieldProven 은 필드 확인 뒤 ESC 클릭이 실제 전송됐을 때만 발급' ([bool]($ret -match 'Write-RunLog ''\[어비스\] ESC 클릭''\s*\$fieldProven = \$true')) 'True'
Check-Equal '배선: 복귀 루프 - 양보·캡처 실패·재매칭 패널·던전 안에서 토큰 폐기, 어비스 클릭에서 소비' (([regex]::Matches($ret, '\$fieldProven = \$false').Count -ge 5) -and ([bool]($ret -match '\$fieldProven = \$false; \$insideStreak = 0; \$insideSince = \$null\s*Invoke-UserYieldWithDeadline')) -and ([bool]($ret -match '어비스 메뉴 클릭 \(글자 탐색 화면좌표[^\r\n]*\r?\n\s*\$fieldProven = \$false'))) 'True'
Check-Equal '배선: 복귀 루프 - while(\$true) + 캡처 실패 중에는 만료 판정 안 함 (마감 직전 실패가 throw 로 새지 않게)' ([bool]($ret -match 'while \(\$true\) \{[\s\S]{0,1200}if \(-not \$script:screenCaptureFailing -and \(Get-Date\) -ge \(Get-YieldAdjustedDeadline[^\r\n]*\) \{ break \}')) 'True'
Check-Equal '배선: 복귀 루프 - HUD·추적기 두 판독 사이 캡처 실패(일련번호)면 그 표본으로 판정하지 않음' ([bool]($ret -match '\$questNow = Test-InDungeonQuest -Game \$Game\s*if \(\$script:screenCaptureFailing -or \$script:captureFailSerial -ne \$turnSerial\) \{ continue \}')) 'True'
Check-Equal '배선: 캡처 실패 일련번호 - Register-CaptureFailure 가 증가, 나가기 헬퍼는 실패가 있던 회전을 폐기' (([bool]($src -match '\$script:captureFailSerial\+\+')) -and ([bool]((Body 'Invoke-AbyssExitClick') -match '-not \$script:screenCaptureFailing -and \$script:captureFailSerial -ne \$turnSerial\) \{[\s\S]{0,400}continue'))) 'True'
$helper = Body 'Invoke-AbyssExitClick'
Check-Equal '배선: 나가기 헬퍼 gone 증거에 ESC 메뉴 없음' ([regex]::Matches($helper, 'Test-AbyssMenu').Count) 0
Check-Equal '배선: 나가기 헬퍼 필드 증거 = HUD + 추적기 던전명 없음 2연속' ([bool]($helper -match 'elseif \(Test-HomeEndEscHud -Game \$Game\) \{\s*\$questNow = Test-InDungeonQuest[\s\S]{0,200}\$fieldStreak -ge 2\) \{ \$passed')) 'True'
Check-Equal "배선: 나가기 헬퍼 - 재매칭 패널이면 'matching' 반환, 클릭 없음" ([bool]($helper -match "if \(\`$matchingNow\) \{[\s\S]{0,300}return @\{ Result = 'matching'")) 'True'
Check-Equal '배선: 시작 디스패치 - 재매칭 패널이면 취소 없이 입장 대기(HUD+추적기 2연속), 복구 전용은 코드 4' ([bool]($src -match '\$startMatchingDetected = \(-not \$startExitDetected\)[\s\S]{0,400}customRecoveryOnly\) \{[\s\S]{0,300}exit 4[\s\S]{0,2400}\$startInsideStreak -ge 2\) \{ break \}')) 'True'
$member = Body 'Invoke-AbyssPartyMemberCycle'
Check-Equal '배선: 파티원 - 필드 복귀는 HUD + 추적기 없음 2연속, 보상 화면이면 헬퍼 재클릭' (([bool]($member -match '\$memberFieldStreak -ge 2\) \{ break \}')) -and ([regex]::Matches($member, 'Invoke-AbyssExitClick -Game \$Game').Count -eq 2)) 'True'
Check-Equal '배선: 파티원 - 옛 raw HUD Wait-ForScreen 없음' ([bool]($member -match "Description '던전 밖\(필드\) 복귀'")) 'False'
Check-Equal '배선: 파티원·시작 재매칭 - 양보 뒤 연속 수 리셋, 실패 표본은 일련번호로 폐기(연속 유지)' (([bool]($member -match '\$memberFieldStreak = 0; Wait-UserYieldEnd')) -and ([bool]($member -match '-or \$script:captureFailSerial -ne \$turnSerial\) \{ continue \}')) -and ([bool]($src -match '\$startInsideStreak = 0; Wait-UserYieldEnd'))) 'True'
$known = Body 'Test-KnownScreen'
Check-Equal '배선: 알려진 화면에 재매칭 패널 포함 (이벤트 정리 X 클릭 방지)' ([bool]($known -match 'Test-AbyssMatchingPanel -Game \$Game\) \{ return \$true \}')) 'True'

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0