# 2026-08-01 전수 점검(교차 리뷰) 수정 배선 가드 - 워커/GUI/빌드/런처 일괄
# 각 수정의 근거·경위는 이슈_개선점_목록.md '2026-08-01 - 전수 점검 결함 일괄 수정' 참고
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$workerSource = [IO.File]::ReadAllText($workerPath)
# 함수 본문만 AST 로 떼어내는 공용 헬퍼 (주석 앵커를 코드 앵커로 바꾸는 데 필요 - 8차 점검)
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$guiSource = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_gui.ps1'))
$buildSource = [IO.File]::ReadAllText((Join-Path $projectRoot 'build\build_exe.ps1'))
$launcherSource = [IO.File]::ReadAllText((Join-Path $projectRoot 'build\launcher.cs'))

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 워커 ──────────────────────────────────────────────────────────────────────
# ① 선택 화면 복귀 성공 3경로에서 화면 플래그 확정 (미갱신 시 '던전 화면이 아닙니다' 헛 오류)
Assert-Case '워커: 복귀 성공 후 onSelectionScreen 확정 3곳' `
  ([regex]::Matches($workerSource, '\$onSelectionScreen = \$true\s+#?\s*').Count -ge 3) $true

# ② 클리어 대기 - 마감/연장 판정이 본문 최상단 (continue 가 건너뛰지 못함)
# ★ 8차 점검: 아래 두 단언은 **주석에만** 걸려 있었습니다. 앵커가 '# 마감/전투 연장 판정
#   (본문 최상단' / '# 연장 판독(Test-InDungeonQuest) 도중' 이라는 설명 주석이었고, 정작
#   계약인 `if ((Get-Date) -ge $deadline)` 조건과 '이 분기에서는 던지지 않는다'는 본문은
#   패턴 어디에도 없었습니다. 그래서 시간 상한을 통째로 죽이거나 그 분기에 throw 를 넣어도
#   52종이 전부 통과했습니다(변이 실측). 주석은 언제든 정리되므로 계약을 걸어 둘 자리가
#   아닙니다 - **주석을 뺀 코드 사본**으로 실제 구조를 확인합니다.
$clearBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Wait-ForDungeonClearScreen'))
$clearCode = (($clearBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '워커: 클리어 대기 while($true) + 최상단 마감 판정' `
  ([bool]($clearCode -match 'while \(\$true\) \{\s*\r?\n\s*if \(\(Get-Date\) -ge \$deadline\) \{')) $true
Assert-Case '워커: 마감 도달의 최종 결말은 throw (무한 대기 금지)' `
  ([bool]($clearCode -match '(?s)if \(\(Get-Date\) -ge \$deadline\) \{.*throw ''던전 클리어 화면 감지 대기 시간이 초과됐습니다\.''')) $true
Assert-Case '워커: 마감 판정이 폴링 카운터보다 앞(continue 가 건너뛰지 못함)' `
  ([bool]($clearCode.IndexOf('if ((Get-Date) -ge $deadline) {') -lt $clearCode.IndexOf('$pollCounter++') -and
          $clearCode.IndexOf('$pollCounter++') -ge 0)) $true
# 캡처 실패 분기는 **던지지 않는 것**이 계약입니다 (죽은 화면에 워커를 재투입하지 않기 위함).
# 마감 처리 안에는 이런 분기가 3개 있습니다: 진입부 `if (…) {` 1개 + `} elseif (…) {` 2개.
# ★ 변이 실측: 처음엔 elseif 2개만 검사해서, **진입부 if 분기에 throw 를 넣어도 통과**했습니다.
#   세 개를 모두 세고 각 본문에 throw 가 없음을 확인합니다.
# 닫는 중괄호는 `} elseif` 뿐 아니라 `} else` 로도 이어지므로 **같은 들여쓰기의 닫는
# 중괄호**까지만 봅니다 (앞 형태만 앵커로 쓰면 마지막 분기가 else 블록까지 삼켜 그 안의
# throw 를 자기 것으로 착각합니다 - 첫 작성 때 실제로 그렇게 빗나갔음).
$deadlineBlock = [regex]::Match($clearCode, '(?s)if \(\(Get-Date\) -ge \$deadline\) \{(.*?)\r?\n    \}')
Assert-Case '워커: 마감 처리 블록을 찾음' ([bool]$deadlineBlock.Success) $true
$captureFailBranches = @([regex]::Matches($deadlineBlock.Groups[1].Value,
  '(?s)(?:if|\} elseif) \(\$script:screenCaptureFailing\) \{(.*?)\r?\n      \}'))
Assert-Case '워커: 마감 처리의 캡처 실패 분기 3곳' $captureFailBranches.Count 3
$throwInCaptureFail = 0
foreach ($m in $captureFailBranches) { if ($m.Groups[1].Value -match 'throw') { $throwInCaptureFail++ } }
Assert-Case '워커: 캡처 실패 분기에서는 던지지 않는다' $throwInCaptureFail 0
# ★ 연장 판정은 **콘텐츠별**이어야 합니다. 어비스 전용 Test-InDungeonQuest 하나만 쓰면
#   퀘스트 추적기 문구가 다른 던전·심층·사냥터에서는 절대 매칭되지 않아, 2026-07-17 에 넣은
#   '전투 중이면 60초씩 연장' 안전망이 4개 콘텐츠 중 1개에서만 살아 있게 됩니다
#   (2026-08-10 8차 점검에서 발견 - 조용히 죽어 있어 로그에도 흔적이 없었음).
Assert-Case '워커: 연장 판정은 콘텐츠별 판정을 쓴다' `
  ([bool]($clearCode -match '-lt \$extendLimit -and \(Test-CombatStillRunning -Game \$Game\)')) $true
$combatBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-CombatStillRunning'))
Assert-Case '워커: 연장 판정이 던전/심층/사냥터 키워드를 덮는다' `
  ([bool](($combatBody -match "'\[던전\]'") -and ($combatBody -match "'\[심층\]'") -and
          ($combatBody -match "'\[사냥터\]'") -and ($combatBody -match "Contains\('구역'\)") -and
          ($combatBody -match "Contains\('소탕'\)") -and ($combatBody -match "Contains\('정찰'\)"))) $true
Assert-Case '워커: 어비스는 기존 판정을 그대로 위임' `
  ([bool]($combatBody -match 'return \[bool\]\(Test-InDungeonQuest -Game \$Game\)')) $true
Assert-Case '워커: 클리어 대기 바닥 연장 블록 제거(연장 판정 1곳뿐)' `
  ([regex]::Matches($workerSource, '클리어 대기 한도\(\$\{TimeoutSeconds\}초\)를 넘겼지만').Count) 1

# ③ 준비/정리 실행의 안전 중지는 회차로 계상하지 않음
Assert-Case '워커: Return-ToAbyssSelection SafeStopExitCode 파라미터' `
  (($workerSource -match '\[int\]\$SafeStopExitCode = 0') -and
   ($workerSource -match 'exit \$SafeStopExitCode')) $true
Assert-Case '워커: 준비 실행 호출부가 코드 10 전달(2곳 이상)' `
  ([regex]::Matches($workerSource, '-SafeStopExitCode 10').Count -ge 1 -and
   [regex]::Matches($workerSource, '-SafeStopExitCode \$\(if').Count -ge 3) $true

# ④ 파티찾기 토글 fail-closed (던전+어비스: unknown 재판독 → 정지 / 끄기 후 off 확정)
Assert-Case '워커: 파티찾기 토글 unknown 정지 2곳(던전/어비스)' `
  ([regex]::Matches($workerSource, "토글 상태를 확인하지 못했습니다 - 오입장을 막기 위해 정지").Count) 2
Assert-Case '워커: 끄기 후 off 확정 요구 2곳' `
  ([regex]::Matches($workerSource, '\$toggleAfterOff -ne ''off''').Count -ge 4) $true

# ⑤ 커스텀: 카드 설정 실패 + 소모량 null → 정지 (반대 설정 입장 방지)
# 2026-08-09 리뷰: '확인'의 기준을 Ok(설정 반영)에서 Rechecked(실제 재판독)로 격상.
# Ok 만 보면 클릭 후 글자를 못 읽어 '재확인 생략'으로 받은 $true 까지 확인으로 세어,
# 아무 증거 없이 반대 설정으로 입장할 수 있었습니다.
Assert-Case '워커: 커스텀 카드 미확인+소모량 null 정지' `
  ($workerSource -match 'customMode -and \(-not \$coinConfirmed -or -not \$lootConfirmed\)[\s\S]{0,300}?exit 4') $true
Assert-Case '워커: 확인 판정이 Rechecked 를 포함' `
  ($workerSource -match '\$coinConfirmed = \(\$coinToggleOk -and \$coinToggleRechecked\)') $true

# ⑦ 사냥터 재시도 경로도 continueSweepOnly 존중 (10~19개면 더블 루팅만 끄고 재입장)
Assert-Case '워커: 사냥터 재시도 소탕만 계속 폴백' `
  ($workerSource -match '\$htLootFallback -and\s+-not \$lootFallbackDone[\s\S]{0,600}?더블 루팅을 끄고 소탕만 계속') $true

# ⑧ '가루 부족' 해석은 R키 가루 부활 직후에만 (여신상/전멸 후 팝업 오인 방지)
Assert-Case '워커: 가루 부족 해석은 가루 부활 한정' `
  ($workerSource -match "reviveConfirmPending -and \`$revivePendingKind -eq '가루 부활'") $true

# ⑨ Wait-ForScreen: 캡처 실패 중에는 Condition 성공을 인정하지 않음 (실행은 유지)
Assert-Case '워커: Wait-ForScreen 캡처 실패 게이트' `
  ($workerSource -match 'if \(\(& \$Condition\) -and -not \$script:screenCaptureFailing\)') $true

# ⑩ 어비스 커스텀 난이도 격상 (던전 -Strict 계약과 통일)
Assert-Case '워커: 어비스 커스텀 난이도 확인 실패 정지' `
  ([regex]::Matches($workerSource, '오난이도 판 방지를 위해 정지합니다').Count) 9   # 08-11 ③ 6곳 + 08-13 사냥터 미탐색 격상 1곳

# ⑪ 파티원 준비 버튼은 '준비' 조각까지 요구
Assert-Case "워커: 파티원 버튼 '준비'+'완료' 요구" `
  ($workerSource -match "match '준비' -and \`$memberBtnText -match '완료'") $true

# 설정부: 좌표 int 범위 검사 + 기준 좌표계 1272x717 고정
Assert-Case '워커: 좌표 int 범위 검사' `
  ($workerSource -match '\$number -lt \[int\]::MinValue -or \$number -gt \[int\]::MaxValue') $true
Assert-Case '워커: referenceResolution 1272x717 강제' `
  ($workerSource -match 'referenceWidth -ne 1272 -or \$referenceHeight -ne 717[\s\S]{0,400}?\$referenceWidth = 1272') $true

# ── GUI ──────────────────────────────────────────────────────────────────────
Assert-Case 'GUI: preparedStreak 은 코드 10 외 전부 초기화' `
  ($guiSource -match 'if \(\$exitCode -ne 10\) \{ \$script:preparedStreak = 0 \}') $true
Assert-Case 'GUI: Start-Process 실패 시 실행 상태 복원' `
  ($guiSource -match 'try \{\s+\$script:worker = Start-Process[\s\S]{0,400}?워커 시작 실패') $true
Assert-Case 'GUI: Kill 실패 재시도 + 잔존 경고' `
  ($guiSource -match '자동화 프로세스를 종료하지 못했습니다') $true
Assert-Case 'GUI: 임시/백업 청소 실패는 저장 실패 아님' `
  ($guiSource -match 'try \{ if \(\[System\.IO\.File\]::Exists\(\$backupPath\)\) \{ \[System\.IO\.File\]::Delete\(\$backupPath\) \} \} catch \{ \}') $true
Assert-Case 'GUI: 일반 던전 커스텀 로드 stage 형식 검증' `
  ($guiSource -match '\(\[string\]\$crSavedItem\.stage\) -notmatch ''\^?\[12\]-\[123\]\$''') $true
Assert-Case 'GUI: 새 버전 팝업 승인 조회 중 생략' `
  ($guiSource -match '-not \$script:running -and -not \$script:approvalPendingStart') $true
Assert-Case 'GUI: 종료 확인은 UserClosing 만' `
  ($guiSource -match 'CloseReason\]::UserClosing') $true
Assert-Case 'GUI: 프로세스 열거 실패를 실패로 보고' `
  ($guiSource -match '열거 자체가 실패하면[\s\S]{0,200}?\$failed\+\+') $true

# ── 빌드/런처 ─────────────────────────────────────────────────────────────────
Assert-Case '빌드: 해시 대장 없으면 차단(fail-closed)' `
  ($buildSource -match 'release_hashes\.json 이 없습니다') $true
Assert-Case '빌드: released 잠금이 중복 항목도 검사' `
  ($buildSource -match '\$currentReleased\.Count -gt 0') $true
Assert-Case '빌드: PS 문법 검사 내장' `
  ($buildSource -match '\[System\.Management\.Automation\.Language\.Parser\]::ParseFile') $true
Assert-Case '빌드: coordsVersion 타입 검사' `
  ($buildSource -match 'coordsVersion 이 정수') $true
Assert-Case '빌드: 대장 쓰기 직전 재조회' `
  ($buildSource -match '\$freshLedger = Get-Content -LiteralPath \$hashLedgerPath') $true
Assert-Case '런처: LOCALAPPDATA 빈 값 가드' `
  ($launcherSource -match 'IsNullOrEmpty\(localAppData\)') $true
Assert-Case '런처: config 이전은 임시 파일 경유' `
  ($launcherSource -match 'cfgPath \+ "\.migrate\."') $true
Assert-Case '런처: 시스템 PowerShell 절대 경로 우선' `
  ($launcherSource -match 'System32\\WindowsPowerShell\\v1\.0\\powershell\.exe') $true

# ── 3차 전수 검사 반영 (2026-08-01 - 리뷰 조건 포함) ─────────────────────────
# 회귀: 복구 회차가 복귀로 확정된 선택 화면 플래그를 신뢰 (2026-08-13 개정: 진입 버튼으로
# 옵션 화면이 확정된 회차는 죽은 제목의 '고분' 조각이 만드는 선택 화면 오판을 제외)
Assert-Case '3차: 복구 판정이 onSelectionScreen 플래그 신뢰 (+probe 옵션 제외)' `
  ($workerSource -match '\$recoveryOnSelection = \(-not \$optionsByProbe\) -and \(\$onSelectionScreen -or \(Test-DgSelectionTitle') $true
# 회귀: 마감 throw 직전 성공 화면(클리어/결과/보상/선택) 최종 탐침 + 탐침 중 캡처 실패 동결
Assert-Case '3차: 마감 직전 성공 화면 최종 탐침(4상태+HUD 부재)' `
  ($workerSource -match 'elseif \(\(Test-DungeonClearPrompt -Game \$Game\) -or\s+\(\$FindResultButton[\s\S]{0,120}Test-HomeEndEscHud[\s\S]{0,400}Test-AbyssSelectionScreen') $true
Assert-Case '3차: 최종 탐침 중 캡처 실패도 동결' `
  ([regex]::Matches($workerSource, '\} elseif \(\$script:screenCaptureFailing\) \{').Count -ge 2) $true
# 과소 게이트 보강: 사용 경로 재판독 null + 미사용 경로 유효 밖 값
Assert-Case '3차: 사용 경로 재판독 null 커스텀 정지' `
  ($workerSource -match '소모량 재판독도 실패했습니다[\s\S]{0,120}exit 4') $true
Assert-Case '3차: 미사용 게이트가 유효 밖 값도 차단' `
  ($workerSource -match '\(\$null -eq \$offCost -or -not \(\$dgValidCosts -contains \$offCost\)\)') $true
# 잔상 가드: 방금 카드 클릭 직후의 유효값 불일치는 정정 클릭 금지
# ※ 존재 여부가 아니라 **개수**로 셉니다. 같은 소모량 교차 검증이 던전 정방향/사냥터 정방향
#   두 곳에 복제돼 있는데, 2026-07-29 잔상 가드가 던전에만 들어가고 사냥터는 1년 가까이
#   빠진 채였습니다(08-09 감사 적발 - 회차마다 은동전 10개 손실). 존재 검사는 한 곳만
#   고쳐도 초록이라 비대칭을 오히려 조장합니다. 복제된 판정은 가드도 개수로 고정합니다.
Assert-Case '3차: 정정 클릭 잔상 가드(coin/loot 클릭 공통) - 던전+사냥터 2곳' `
  ([regex]::Matches($workerSource, '\(\$coinToggleClicked -or \$lootToggleClicked\) -and \$coinToggleOk -and \$lootToggleOk').Count) 2
Assert-Case '3차: 클릭했으나 확인 실패 시 무클릭 재판독 - 던전+사냥터 2곳' `
  ([regex]::Matches($workerSource, '\} elseif \(\$coinToggleClicked -or \$lootToggleClicked\) \{').Count) 2

# ── 반환값 의미 분리 (2026-08-09 감사) ──────────────────────────────────────
# Set-DgToggleCard 의 $true 는 '설정 반영'까지만 뜻합니다. 클릭 후 글자를 못 읽어도
# '재확인 생략'으로 $true 를 돌려주기 때문입니다. 그런데 호출부의 교차 검증 생략 게이트는
# 주석상 '재판독으로 확인했으니 생략'이라 적혀 있어, 재판독 없이도 안전장치가 꺼졌습니다.
# → '상태를 실제로 확인함'을 $script:dgToggleRechecked 로 분리하고 4개 게이트가 요구합니다.
Assert-Case '분리: dgToggleRechecked 초기화 1곳' `
  ([regex]::Matches($workerSource, '\$script:dgToggleRechecked = \$false').Count) 1
Assert-Case '분리: dgToggleRechecked 참 설정은 상태 확인 경로 1곳뿐' `
  ([regex]::Matches($workerSource, '\$script:dgToggleRechecked = \$true').Count) 1
Assert-Case '분리: 참 설정이 상태 일치 분기 안에 있음' `
  ($workerSource -match 'if \(\$isSelected -eq \$WantSelected\) \{[\s\S]{0,300}\$script:dgToggleRechecked = \$true') $true
Assert-Case '분리: 재확인 생략 경로는 참으로 만들지 않음' `
  ($workerSource -match '재확인 생략[\s\S]{0,80}return \$true') $true
Assert-Case '분리: 정방향 잔상 게이트가 rechecked 요구 - 던전+사냥터 2곳' `
  ([regex]::Matches($workerSource, '\$coinToggleRechecked -and \$lootToggleRechecked').Count) 2
Assert-Case '분리: 역방향 생략 게이트가 rechecked 요구 - 던전+사냥터 2곳' `
  ([regex]::Matches($workerSource, '\$coinToggleClicked -and \$coinToggleOk -and \$coinToggleRechecked').Count) 2
Assert-Case '분리: rechecked 없는 옛 역방향 게이트 잔존 없음' `
  ([regex]::Matches($workerSource, '\$coinToggleClicked -and \$coinToggleOk\)').Count) 0
Assert-Case '분리: 심층은 더블 루팅 카드가 없어 rechecked 기본 참' `
  ($workerSource -match '\$lootToggleRechecked = \$true[\s\S]{0,120}if \(-not \$deepMode\)') $true

# 게이트 진리표: '클릭했다'만으로는 교차 검증을 생략할 수 없습니다.
function Test-SkipCrossCheck {
  param([bool]$Clicked, [bool]$Ok, [bool]$Rechecked)
  return [bool]($Clicked -and $Ok -and $Rechecked)
}
Assert-Case '진리표: 클릭+반영+재판독 = 생략 허용' (Test-SkipCrossCheck $true $true $true) $true
Assert-Case '진리표: 클릭+반영이지만 재판독 실패 = 생략 금지' (Test-SkipCrossCheck $true $true $false) $false
Assert-Case '진리표: 클릭 안 함 = 생략 금지' (Test-SkipCrossCheck $false $true $true) $false
Assert-Case '진리표: 설정 미반영 = 생략 금지' (Test-SkipCrossCheck $true $false $true) $false

# ── 재화 부족 폴백도 같은 기준 (2026-08-09 리뷰 2차 적발) ────────────────────
# 잔량 부족으로 카드를 끄는 폴백 4곳이 Set-DgToggleCard 결과를 **버리거나**(| Out-Null)
# 반환값만 보고 $effectiveLoot/$effectiveCoin 을 내리고 있었습니다. 실제로는 카드가 켜진
# 채인데 자동화만 '껐다'고 믿으면, 이후 필요량이 10 으로 내려가 20 이 드는 판에 그대로
# 입장해 재화를 더 씁니다. 앞의 게이트들만 고치고 폴백을 빠뜨린 것이 이번 적발입니다.
Assert-Case '폴백: 토글 결과를 버리는 호출 없음(| Out-Null 금지)' `
  ([regex]::Matches($workerSource, 'Set-DgToggleCard[^\r\n]*\| Out-Null').Count) 0
Assert-Case '폴백: 해제 확인은 Ok + Rechecked 동시 요구 4곳(던전3 + 사냥터1)' `
  ([regex]::Matches($workerSource, '\$(?:lootOffOk|coinOffOk|htLootOffOk) -and \$script:dgToggleRechecked').Count) 4
Assert-Case '폴백: 미확인이면 필요량을 낮추지 않는다는 안내 4곳' `
  ([regex]::Matches($workerSource, '해제를 확인하지 못했습니다[^\r\n]*켜진 것으로 간주').Count) 4
# latch 는 성공/실패 무관 (Set-DgToggleCard 는 내부 재클릭이 있어 루프 반복 호출 금지 계약)
Assert-Case '폴백: lootFallbackDone latch 가 확인 분기 밖에 있음' `
  ([regex]::Matches($workerSource, '(?m)^\s*\$lootFallbackDone = \$true\s*$').Count) 2
Assert-Case '폴백: 사냥터 공짜 재시도는 확인된 경우에만' `
  ($workerSource -match '\$htLootOffOk -and \$script:dgToggleRechecked\) \{\s*\r?\n\s*\$effectiveLoot = \$false\s*\r?\n\s*\$enterTry--') $true
# 다중 스케일 1~2회전 (첫 회전 화면 전환 대비)
Assert-Case '3차: 카드 다중 스케일 1~2회전' `
  ($workerSource -match 'if \(\$setTry -le 2\) \{ \$cardScales = @\(5, 3, 4\) \}') $true
# 복귀 함수: 선택 화면 return 직전 안전 중지 소비
# ★ 8차 점검: 이 단언도 주석 앵커였습니다. 계약의 핵심은 '**예약 파일을 실제로 소비(삭제)한
#   뒤** 종료한다' 인데, 소비 게이트(`Test-Path $safeStopFlagPath`)와 삭제가 패턴에 없어서
#   게이트를 항상 거짓으로 만들어도 통과했습니다. 그러면 예약이 다음 실행으로 새어 나가
#   헛 조기 종료가 됩니다(3차 점검이 고친 회귀 그대로). 코드 사본으로 3요소를 함께 봅니다.
$abyssBackBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Return-ToAbyssSelection'))
$abyssBackCode = (($abyssBackBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '3차: 선택 화면 복귀 직전 안전 중지 소비(게이트+삭제+종료)' `
  ([bool]($abyssBackCode -match '(?s)Test-AbyssSelectionScreen -Game \$Game\) \{.{0,600}?Test-Path -LiteralPath \$safeStopFlagPath.{0,400}?Remove-Item -LiteralPath \$safeStopFlagPath.{0,400}?exit \$SafeStopExitCode')) $true
# GUI: 혼합 잠금 이전 상태 저장/복원 왕복
Assert-Case '3차: 혼합 잠금 진입 시 이전 상태 저장' `
  ($guiSource -match '\$mixState\.PrevInfinite = -not \[bool\]\$RbCount\.Checked[\s\S]{0,60}\$mixState\.PrevLaps') $true
Assert-Case '3차: 혼합 잠금 해제 시 복원(+범위 보정)' `
  ($guiSource -match 'if \(\[bool\]\$mixState\.PrevInfinite\) \{ \$RbInfinite\.Checked = \$true \}[\s\S]{0,400}\$NumLaps\.Minimum') $true
# GUI: Kill 대기 타임아웃화 (무기한 WaitForExit 제거, timeout=false 를 재시도로 연결)
Assert-Case '3차: 무기한 WaitForExit() 제거' `
  ([regex]::Matches($guiSource, '\.WaitForExit\(\)').Count) 0
Assert-Case '3차: WaitForExit(10000) false → 재시도 연결 2곳' `
  ([regex]::Matches($guiSource, 'WaitForExit\(10000\)\) \{ \$\w+ = \$true \} else \{ \$\w+ = \$true \}').Count) 2
# 빌드: releases null 거부(초기+재조회), coordsVersion 범위
Assert-Case '3차: 대장 releases null 거부 2곳' `
  ([regex]::Matches($buildSource, '-and \$null -ne \$(ledger|freshLedger)\.releases').Count -ge 2) $true
Assert-Case '3차: coordsVersion 범위 0~100000' `
  ($buildSource -match '\$configVerNumber -lt 0 -or \$configVerNumber -gt 100000') $true
# 런처: PID 임시 파일명 + powershell fail-closed
Assert-Case '3차: 런처 임시 파일명 PID 포함' `
  ($launcherSource -match '\.migrate\." \+ Process\.GetCurrentProcess\(\)\.Id \+ "\.tmp') $true
Assert-Case '3차: 런처 powershell 이름 검색 fallback 제거' `
  ($launcherSource -notmatch 'psExe = "powershell\.exe"') $true

# ── v1.2.1: 코드 4 상태줄에 실제 [완료] 사유 표시 (2026-08-02 오해 실사례) ──────────
Assert-Case 'GUI: [완료] 사유 수집 3곳(기본/복구/최종 폴링)' `
  ([regex]::Matches($guiSource, "match '\\\[완료\\\]\\s\*\(\.\+\)'").Count) 3
Assert-Case 'GUI: 코드 4 상태줄이 실제 사유 우선 + 범용 폴백(생활 분기 선행)' `
  ($guiSource -match '\$code4Reason = "조건 정지: \$code4Reason"[\s\S]{0,400}elseif \(\$script:mainCategory -eq ''life''\)[\s\S]{0,400}elseif \(\$rbCatDeep\.Checked\)') $true
Assert-Case 'GUI: 회차 시작 시 사유 초기화' `
  ($guiSource -match '\$script:lastWorkerDoneReason = ''''[\s\S]{0,400}Start-Process -FilePath ''powershell\.exe''') $true

# ── v1.2.1: 오클릭 사고(08-02 22:02 - 커서 간섭 클릭이 재화줄을 눌러 화면 가림) ──
# ★ 앵커를 **로그 문구에서 코드 구조로** 격상했습니다 (2026-08-10). 원래는 경고 문구
#   '오클릭 방지를 위해 이번 클릭을 건너뜁니다' 를 앵커로 삼았는데, 문구를 [안내]/[경고]
#   2단계로 바꾸자 이 단언이 깨졌습니다. 이 단언이 지키려는 것은 문구가 아니라 **안전 게이트**
#   (커서를 확인 못 하면 클릭을 쏘지 않는다)이므로, 문구가 어떻게 바뀌든 살아남게 고칩니다.
#   판정 → 게이트 → mouse_event 순서가 유지되는지를 봅니다.
Assert-Case '워커: 커서 미확인 시 클릭 건너뜀(강행 제거)' `
  ($workerSource -match 'Get-CursorClickWarnAction[\s\S]{0,1500}if \(-not \$cursorReady\) \{ return \}[\s\S]{0,300}mouse_event\(0x0002') $true
Assert-Case '워커: 보유한 재화 화면 감지 조각(유한/보유+재화)' `
  ($workerSource -match "Contains\('보유'\) -or \`$ccTitle\.Contains\('유한'\)\) -and \`$ccTitle\.Contains\('재화'\)") $true
Assert-Case '워커: 재화 화면 닫기 배선 2곳(클리어 대기+결과 대기)' `
  ([regex]::Matches($workerSource, 'if \(Close-CurrencyOverviewScreen -Game \$Game\) \{ continue \}').Count) 2

# ── v1.2.1: 월요일 6시 주간 리셋 팝업이 복귀 대기를 막던 사고(08-03 06:02) ─────────
Assert-Case '워커: 주간 리셋 팝업 소함수 추출' `
  ($workerSource -match 'function Close-WeeklyCoopResetPopup[\s\S]{0,900}협동[\s\S]{0,300}참여') $true
Assert-Case '워커: 복귀 대기 2곳+다음 층 대기+생활 사이클 3곳에 주간 리셋 팝업 배선' `
  ([regex]::Matches($workerSource, "if \(Close-WeeklyCoopResetPopup -Game \`$Game -LogPrefix '\[").Count) 6
Assert-Case '워커: 복귀 대기 공지 팝업 닫기 2곳' `
  ([regex]::Matches($workerSource, '공지 게시판 팝업 감지 - X로 닫기 \(복귀 대기 중\)').Count) 2
Assert-Case '워커: 이벤트 스킵이 소함수 호출로 치환' `
  ($workerSource -match 'if \(Close-WeeklyCoopResetPopup -Game \$Game -LogPrefix \$LogPrefix\) \{ return \$true \}') $true

# ── v1.2.1: 게임 프리즈 제보(08-02 타 PC) 반영 ─────────────────────────────────
Assert-Case '워커: Test-KnownScreen 에 클리어/결과 화면 포함(이벤트 오인 방지)' `
  ($workerSource -match 'if \(Test-DungeonClearPrompt -Game \$Game\) \{ return \$true \}\s+if \(Find-DgRetryButtonPoint -Game \$Game\) \{ return \$true \}') $true
Assert-Case '워커: 결과 대기 타임아웃 시 클리어 잔존 재판정 + 무응답 안내' `
  ($workerSource -match 'Test-DungeonClearPrompt -Game \$Game\)\) \{\s+throw ''클리어 화면이 터치에 반응하지 않습니다[\s\S]{0,120}throw \$MissingMessage') $true

# ── v1.2.1: 08-03 실사고 2건 (06:02 협동 미션 전체 창 / 08:50 1908 창 알약 판독 전멸) ──
# 협동 미션 전체 창: 순수 판정 소함수('협동' AND ('미션' OR '미선')) - 진리표는 test_weekly_coop_popup
Assert-Case '워커: 협동 창 제목 판정 소함수(미선 이형 포함)' `
  ($workerSource -match "function Test-CoopMissionBoardTitle[\s\S]{0,900}Contains\('협동'\) -and \(\`$t\.Contains\('미션'\) -or \`$t\.Contains\('미선'\)\)") $true
# 제목 ROI 판독은 s3→s4 사다리 - '판정 참'만 조기 종료 (1810 창 s3 '미선' 깨짐 실사고, 타 PC 1810 창)
Assert-Case '워커: 협동 창 판독 사다리 @(3,4)' `
  ($workerSource -match 'foreach \(\$boardScale in @\(3, 4\)\)') $true
# 닫기 함수: 감지 + Focus 후 재확인(스테일 방지) 두 번 모두 같은 판독 함수 사용
Assert-Case '워커: 협동 창 닫기 - Focus 전후 이중 확인' `
  ([regex]::Matches($workerSource, 'if \(-not \(Test-CoopMissionBoardVisible -Game \$Game\)\) \{ return \$false \}').Count) 2
# X(1228,67) 클릭 = 보유한 재화 창과 동일 위치 - 두 함수 각각 1곳씩
Assert-Case '워커: 우상단 X(1228,67) 클릭 2곳(재화 창+협동 창)' `
  ([regex]::Matches($workerSource, 'Click-GamePoint -Game \$Game -ReferenceX 1228 -ReferenceY 67').Count) 2
# 배선 ①: 입장/매칭 스윕 (스윕을 쓰는 입장 대기·복귀 대기·시작 판정 일괄 커버)
Assert-Case '워커: 협동 창 닫기 - 스윕 배선' `
  ([regex]::Matches($workerSource, 'if \(Close-CoopMissionBoardScreen -Game \$Game\) \{ return \$true \}').Count) 1
# 배선 ②: 이벤트 스킵 - 범용 '건너'/'지원'/'확인' 탐색보다 먼저 (리뷰 순서 조건)
Assert-Case '워커: 협동 창 닫기 - 이벤트 스킵 선두 배선' `
  ($workerSource -match 'if \(Close-CoopMissionBoardScreen -Game \$Game -LogPrefix \$LogPrefix\) \{ return \$true \}[\s\S]{0,300}\$skipPoint = Find-GameTextPoint') $true
# 배선 ③④: 클리어 대기 + 결과 대기 (주간 리셋 팝업과 협동 창 각 2곳)
Assert-Case '워커: 협동 창 닫기 - 클리어/결과 대기 배선 2곳' `
  ([regex]::Matches($workerSource, 'if \(Close-CoopMissionBoardScreen -Game \$Game -LogPrefix "\$\(\$script:contentTag\) "\) \{ continue \}').Count) 2
Assert-Case '워커: 주간 리셋 팝업 - 클리어/결과 대기 배선 2곳' `
  ([regex]::Matches($workerSource, 'if \(Close-WeeklyCoopResetPopup -Game \$Game -LogPrefix "\$\(\$script:contentTag\) "\) \{ continue \}').Count) 2
# 배선 ⑤: '다음 층으로' 전환 대기 - 복귀 대기와 같은 블로커 계약 (스윕+주간 리셋)
Assert-Case '워커: 다음 층 대기 - 스윕+주간 리셋 배선(재클릭 판정 앞)' `
  ($workerSource -match "if \(Invoke-PurchasePopupSweep -Game \`$Game\) \{ continue \}\s+if \(Close-WeeklyCoopResetPopup -Game \`$Game -LogPrefix '\[던전\] '\) \{ continue \}\s+\`$floorAgainPoint = Find-DgNextFloorButtonPoint") $true

# ── v2.0.0: 대분류(전투/생활) GUI 단계 (2026-08-05 시안 확정, 리뷰 조건 A~G) ─────────
# 시작 이중 차단 (조건 D): 버튼 핸들러 서두 + 승인 비동기 콜백 경유(Invoke-StartAutomation) 서두
Assert-Case 'GUI: 생활 시작 차단 - btnStart 핸들러 서두' `
  ($guiSource -match '\$btnStart\.Add_Click\(\{\s+#[^\r\n]*\r?\n    if \(Test-LifeStartBlocked\) \{ return \}') $true
Assert-Case 'GUI: 생활 시작 차단 - Invoke-StartAutomation 서두(비동기 우회 차단)' `
  ($guiSource -match 'function Invoke-StartAutomation \{[\s\S]{0,900}?if \(Test-LifeStartBlocked\) \{ return \}') $true
# 대분류 전환 단일 진입점 (조건 B) + 실행 중 전환 금지 (조건 C)
Assert-Case 'GUI: Set-MainCategory 단일 진입점(실행 중 금지 포함)' `
  ($guiSource -match 'function Set-MainCategory \{[\s\S]{0,700}?if \(\$script:running\) \{ return \}') $true
Assert-Case 'GUI: 실행 중 대분류 버튼 잠금(Set-UiRunning)' `
  (($guiSource -match '\$btnCatBattle\.Enabled = \(-not \$IsRunning\)') -and
   ($guiSource -match '\$btnCatLife\.Enabled = \(-not \$IsRunning\)')) $true
# 테마 일괄 적용 후 상태 스타일 재적용 (조건 E)
Assert-Case 'GUI: 테마 후 대분류/슬라이더 스타일 재적용' `
  ($guiSource -match 'Apply-HoneyTheme -Root \$form[\s\S]{0,1200}?Update-MainCategoryVisual\s+Update-LifeSliders') $true
# updateCategoryPanels 생활 게이트 (조건 B): 전투 플래그 전부 (-not isLife) 게이트.
# 2026-08-08 생활 채집에 커스텀 반복이 생기면서 커스텀 게이트만 '사냥터 제외 + 생활은
# 채집만'으로 바뀌었습니다 (가공은 리스트 자체가 없어 여전히 제외)
Assert-Case 'GUI: 카테고리 패널 갱신에 isLife 게이트' `
  (($guiSource -match '\$isDungeon = \(-not \$isLife\) -and \$rbCatDungeon\.Checked') -and
   ($guiSource -match '\$supportsCustom = \(-not \$isHunting\) -and \(\(-not \$isLife\) -or \$isLifeGather\)')) $true
# 승인 오버레이 확장 (조건 A): (15,42) 유지 + 높이 158 + 미승인 시 대분류 잠금
Assert-Case 'GUI: 승인 오버레이 514x158 + 대분류 승인 잠금' `
  (($guiSource -match '\$grpApproval\.Size = New-Object System\.Drawing\.Size\(514, 158\)') -and
   ($guiSource -match '\$btnCatBattle\.Enabled = \$approved')) $true
# config 스키마 5 (조건 F): mainCategory 최상위 이전 + life 섹션 allowlist
Assert-Case 'GUI: 마이그레이션 - mainCategory 이전 + life allowlist' `
  (($guiSource -match "if \(\`$usr\.PSObject\.Properties\['mainCategory'\]\) \{ \`$def\.mainCategory = \`$usr\.mainCategory \}") -and
   ($guiSource -match "'deepCustomRepeat', 'lifeCustomRepeat', 'assist', 'life'\)")) $true
$auditConfigJson = Get-Content (Join-Path $projectRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Case 'config: 스키마 8 + mainCategory 기본 battle + life 섹션' `
  (([int]$auditConfigJson.configSchemaVersion -eq 8) -and ([string]$auditConfigJson.mainCategory -eq 'battle') -and
   ($null -ne $auditConfigJson.life) -and ([string]$auditConfigJson.life.skill -eq 'daily')) $true
# 버전 번호를 고정값으로 박으면 올릴 때마다 이 테스트가 깨집니다 (2026-08-09 v2.0.1 에서 발생).
# 여기서 지켜야 할 계약은 '어떤 번호인가'가 아니라 **$appVersion 이 GUI 에 단일 선언으로
# 존재하고 형식이 유효한가**(빌드가 이 값을 exe 버전으로 삼음) 입니다.
Assert-Case 'GUI: $appVersion 단일 선언 + 형식 유효' `
  ([regex]::Matches($guiSource, "(?m)^\`$appVersion = '\d+\.\d+\.\d+'").Count) 1
# 생활 스킬 아이콘: 내장 base64 9종을 실제 .NET 디코드로 검증 (2026-08-05 - 손 전사 손상으로
# herb 등 5종이 조용히 깨졌던 사고. 회귀 가드가 실디코드를 안 해서 못 잡았음 - 리뷰 권고)
Add-Type -AssemblyName System.Drawing
$iconDecodeOk = 0
$iconIds = @('daily', 'wood', 'mining', 'herb', 'wool', 'harvest', 'hoe', 'insect', 'fishing')
foreach ($iconId in $iconIds) {
  $iconMatch = [regex]::Match($guiSource, "(?m)^  $iconId = '([A-Za-z0-9+/=]+)'")
  if (-not $iconMatch.Success) { continue }
  try {
    $iconStream = New-Object System.IO.MemoryStream(, [Convert]::FromBase64String($iconMatch.Groups[1].Value))
    $iconTmp = [System.Drawing.Image]::FromStream($iconStream)
    $iconBmp = New-Object System.Drawing.Bitmap($iconTmp)
    $iconTmp.Dispose(); $iconStream.Dispose()
    # 스트림 해제 후에도 픽셀 접근 가능해야 함 (Bitmap 사본 분리 계약)
    # 24px = 카드 높이 56 에서 글자와 안 겹치는 실측 크기 (2026-08-05 배치 비교로 확정)
    if ($iconBmp.Width -eq 24 -and $iconBmp.Height -eq 24 -and $null -ne $iconBmp.GetPixel(12, 12)) { $iconDecodeOk++ }
    $iconBmp.Dispose()
  } catch { }
}
Assert-Case 'GUI: 생활 아이콘 base64 9종 실디코드(24x24 + 사본 분리)' $iconDecodeOk 9
# 대분류 버튼 아이콘 2종 (공격력=전투/생활력=생활, 20px - 2026-08-05 사용자 제공)
$catIconOk = 0
foreach ($catIconId in @('catBattle', 'catLife')) {
  $catIconMatch = [regex]::Match($guiSource, "(?m)^  $catIconId = '([A-Za-z0-9+/=]+)'")
  if (-not $catIconMatch.Success) { continue }
  try {
    $catIconStream = New-Object System.IO.MemoryStream(, [Convert]::FromBase64String($catIconMatch.Groups[1].Value))
    $catIconTmp = [System.Drawing.Image]::FromStream($catIconStream)
    $catIconBmp = New-Object System.Drawing.Bitmap($catIconTmp)
    $catIconTmp.Dispose(); $catIconStream.Dispose()
    if ($catIconBmp.Width -eq 20 -and $catIconBmp.Height -eq 20 -and $null -ne $catIconBmp.GetPixel(10, 10)) { $catIconOk++ }
    $catIconBmp.Dispose()
  } catch { }
}
Assert-Case 'GUI: 대분류 버튼 아이콘 2종 실디코드(20x20)' $catIconOk 2
# 글자 정중앙 + 아이콘이 글자 바로 왼쪽 (2026-08-05 정렬 수렴: 묶음 중앙 = 글자 밀림 /
# 독립 정렬 = 아이콘이 구석 - Button.Image 로는 불가 → Paint 로 글자 폭 기준 직접 그리기)
Assert-Case 'GUI: 대분류 아이콘 - Paint 직접 그리기(글자 폭 기준 인접 좌표)' `
  ($guiSource -match 'MeasureText\(\$Sender\.Text, \$Sender\.Font\)[\s\S]{0,300}?- \$paintIcon\.Width - 6') $true
Assert-Case 'GUI: 대분류 Paint 배선 2곳 + 상태 변경 시 Invalidate' `
  (([regex]::Matches($guiSource, 'Add_Paint\(\{ Invoke-MainCatButtonPaint -Sender \$this -PaintArgs \$_ \}\)').Count -eq 2) -and
   ($guiSource -match '\$catButton\.Invalidate\(\)')) $true
# 흰 원본 아이콘은 크림 비활성 버튼에서 안 보임 → 진갈색 틴트 사본을 상태별 사용 (스모크 실측)
Assert-Case 'GUI: 대분류 아이콘 비활성용 틴트 사본 생성+상태별 사용' `
  (($guiSource -match "\`$script:lifeSkillIcons\[\`$catIconId \+ 'Dark'\] = \`$catDarkIcon") -and
   ($guiSource -match "ContainsKey\(\`$paintIconKey \+ 'Dark'\)")) $true
# 카드 정렬 회귀 가드 (2026-08-05 실기 제보: TopCenter/BottomCenter 분리 정렬은 카드 높이
# 56 에서 아이콘·글자가 겹침 - '중앙 쌓기' 조합을 고정. 크기 134×56 은 스킬/대상 카드 2곳)
Assert-Case 'GUI: 생활 카드 아이콘 중앙 쌓기 정렬(겹침 회귀 방지)' `
  ($guiSource -match '\$lifeCard\.TextImageRelation = \[System\.Windows\.Forms\.TextImageRelation\]::ImageAboveText\s+\$lifeCard\.ImageAlign = \[System\.Drawing\.ContentAlignment\]::MiddleCenter\s+\$lifeCard\.TextAlign = \[System\.Drawing\.ContentAlignment\]::MiddleCenter') $true
Assert-Case 'GUI: 생활 카드 크기 134×56 (스킬+대상 2곳)' `
  ([regex]::Matches($guiSource, '\$lifeCard\.Size = New-Object System\.Drawing\.Size\(134, 56\)').Count) 2
# 슬라이더 애니메이션 (2026-08-05 사용자 확정 320ms - 리뷰 조건: 잠금 게이트/Stop 계약/종료 정리)
Assert-Case 'GUI: 슬라이드 320ms 상수' `
  ($guiSource -match '\$script:lifeSlideDurationMs = 320') $true
# 계약의 뜻은 '틱 본문을 인라인 클로저로 쓰지 말고 **명명 함수 한 줄 호출**로 두라'입니다.
# 10차에서 예외 가드(try/catch)를 두르면서 형태가 한 줄에서 여러 줄로 바뀌었으므로,
# '한 줄 리터럴' 대신 **명명 함수 호출 + 다른 로직 없음**으로 확인합니다.
$slideTickBlock = [regex]::Match($guiSource, '(?s)\$script:lifeSlideTimer\.Add_Tick\(\{(.*?)\r?\n  \}\)')
Assert-Case 'GUI: 슬라이드 틱 블록을 찾음' ([bool]$slideTickBlock.Success) $true
$slideTickCode = (($slideTickBlock.Groups[1].Value -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case 'GUI: 슬라이드 틱 = 명명 함수(클로저 금지 계약)' `
  ([bool]($slideTickCode -match '(?m)^\s*Invoke-LifeSlideTick\s*$')) $true
Assert-Case 'GUI: 슬라이드 틱 본문에 다른 로직 없음(가드 + 호출뿐)' `
  ([bool]($slideTickCode -notmatch 'lifeSlide(Active|From|To|Start)')) $true
# 무인 운용 보호: 틱 예외가 밖으로 나가면 모달 오류 창이 떠 메시지 루프가 멈춥니다 (10차 실측)
Assert-Case 'GUI: 슬라이드 틱도 예외 가드' `
  ([bool]($slideTickCode -match '(?s)try \{.*\} catch \{')) $true
Assert-Case 'GUI: 화살표 4곳 Start-LifeSlide 경유' `
  ([regex]::Matches($guiSource, 'Start-LifeSlide -Slider ''(skill|target)'' -Direction -?1').Count) 4
Assert-Case 'GUI: 슬라이드 잠금 가드(카드 2곳+Start 서두)' `
  ([regex]::Matches($guiSource, 'if \(\$script:lifeSlideActive -or \$script:running\) \{ return \}').Count) 3
Assert-Case 'GUI: 화살표 Enabled 에 canNavigate 게이트' `
  ($guiSource -match '\$canNavigate = \(-not \$script:lifeSlideActive\) -and \(-not \$script:running\)') $true
# Stop 배선: 패널 갱신/폼 종료 = SkipUiRefresh 2곳. 실행 시작(Set-UiRunning)은 일반 Stop -
# SkipUiRefresh 면 화살표 false 가 실행 스냅샷에 저장돼 종료 후 영구 비활성 (리뷰 지적)
Assert-Case 'GUI: Stop-LifeSlideNow -SkipUiRefresh 2곳(패널 갱신/종료)' `
  ([regex]::Matches($guiSource, 'Stop-LifeSlideNow -SkipUiRefresh').Count) 2
Assert-Case 'GUI: 실행 시작 시 일반 Stop(스냅샷 오염 방지)' `
  ($guiSource -match 'if \(\$IsRunning -and \$script:lifeSlideActive\) \{ Stop-LifeSlideNow \}') $true
Assert-Case 'GUI: 종료 타이머 정리 목록에 슬라이드 타이머 포함 (2026-08-13: 리사이즈 결과 타이머 추가)' `
  ($guiSource -match '\$script:approvalTimer, \$script:lifeSlideTimer, \$script:timerResizeResult\)') $true
Assert-Case 'GUI: 폼 Dispose 전 슬라이드 정리' `
  ($guiSource -match 'Stop-LifeSlideNow -SkipUiRefresh \} catch \{ \}\s+try \{ \$form\.Dispose\(\)') $true

# ── v1.2.1: 08-01 타 PC(1810 창) 네트워크 불안정 팝업 실사고 (클리어 대기 600초 소진 + 3연속 정지) ──
# 순수 선택 소함수: '도하기' 조각 + 위치 게이트 (진리표는 test_weekly_coop_popup)
Assert-Case '워커: 네트워크 재시도 버튼 선택 게이트(X>=640, Y 585~655)' `
  ($workerSource -match 'if \(\$wordX -ge 640 -and \$wordY -ge 585 -and \$wordY -le 655\)') $true
# 제목 엄격 판정('네트워크'+'불안정') - 감지 + Focus 후 재확인 2곳 (예비 좌표 오클릭 방지)
Assert-Case '워커: 네트워크 팝업 제목 이중 확인(감지+클릭 직전)' `
  ([regex]::Matches($workerSource, "Contains\('네트워크'\) -and \`$netTitle\.Contains\('불안정'\)").Count) 2
# 예비 좌표 (743,620) = '다시 시도하기' 중심 실측 - 제목 재확정 전제 1곳
Assert-Case '워커: 네트워크 재시도 예비 좌표(743,620) 1곳' `
  ([regex]::Matches($workerSource, 'Click-GamePoint -Game \$Game -ReferenceX 743 -ReferenceY 620').Count) 1
# 배선 ①: 입장/매칭 스윕 끝
Assert-Case '워커: 네트워크 팝업 - 스윕 배선' `
  ([regex]::Matches($workerSource, 'if \(Close-NetworkUnstablePopup -Game \$Game\) \{ return \$true \}').Count) 1
# 배선 ②: 이벤트 스킵 선두 (알 수 없는 화면 루프의 정식 출구)
Assert-Case '워커: 네트워크 팝업 - 이벤트 스킵 배선' `
  ([regex]::Matches($workerSource, 'if \(Close-NetworkUnstablePopup -Game \$Game -LogPrefix \$LogPrefix\) \{ return \$true \}').Count) 1
# 배선 ③: 클리어 대기 - 결과 화면 감지(FindResultButton)보다 먼저 (어휘 충돌 방지 - 리뷰)
Assert-Case '워커: 네트워크 팝업 - 클리어 대기 배선(결과 감지 앞)' `
  ($workerSource -match 'Close-NetworkUnstablePopup -Game \$Game -LogPrefix "\$\(\$script:contentTag\) "\)\) \{ continue \}[\s\S]{0,600}if \(\$FindResultButton -and \(\$pollCounter % 2\)') $true
# 배선 ④: 결과 대기 - 반복 버튼 탐색보다 먼저
Assert-Case '워커: 네트워크 팝업 - 결과 대기 배선(버튼 탐색 앞)' `
  ($workerSource -match 'if \(Close-NetworkUnstablePopup -Game \$Game -LogPrefix "\$\(\$script:contentTag\) "\) \{ continue \}\s+\$retryPoint = & \$FindRetryButton') $true

# ── v2.0.0: 로그/신호 폴더 %LOCALAPPDATA%\HoneyNogi\Log 통일 (2026-08-05 사용자 결정) ──
# 워커·GUI 가 같은 규칙이어야 안전 중지 신호/마커/로그 폴링이 만난다 (exe 는 경로 불변)
Assert-Case '워커: 로그 폴더 LOCALAPPDATA 통일 + 빈 값 스크립트 옆 폴백' `
  ($workerSource -match "GetFolderPath\('LocalApplicationData'\)[\s\S]{0,400}Join-Path \`$honeyLogBase 'HoneyNogi\\Log'") $true
Assert-Case 'GUI: 로그 폴더 워커와 같은 규칙 + 폴더 생성' `
  (($guiSource -match "GetFolderPath\('LocalApplicationData'\)[\s\S]{0,500}Join-Path \`$honeyLogBase 'HoneyNogi\\Log'") -and
   ($guiSource -match 'New-Item -ItemType Directory -Path \$honeyLogDir -Force')) $true
Assert-Case "GUI: scriptRoot 기준 'Log' 는 honeyLogDir 폴백 정의 1곳만 (신호/마커 어긋남 방지)" `
  (([regex]::Matches($guiSource, "Join-Path \`$scriptRoot 'Log").Count -eq 1) -and
   ([regex]::Matches($guiSource, 'Join-Path \$scriptRoot \("Log').Count -eq 0)) $true
# 워커 부트스트랩 trap 도 같은 규칙 (초기화 오류가 옛 폴더로 가면 GUI 폴링이 못 봄 - 리뷰)
Assert-Case '워커: 부트스트랩 trap 로그도 LOCALAPPDATA 규칙' `
  ($workerSource -match '\$bootLogBase = \[string\]\[Environment\]::GetFolderPath\(''LocalApplicationData''\)[\s\S]{0,300}HoneyNogi\\Log') $true
# 회차 보관도 통일 폴더 기준 (scriptRoot 로 남아 있으면 저장소 실행에서 보관 실패 - 리뷰)
Assert-Case 'GUI: 회차 로그 보관(run_*.log)이 honeyLogDir 기준' `
  ($guiSource -match '\$archivePath = Join-Path \$honeyLogDir \("run_') $true


# ── 어비스 메뉴: 고정 좌표 → 글자 탐색 (2026-08-08 실사고) ──
# 상단 광고 배너('NEXON ESSENTIAL')가 뜨면서 타일 그리드가 아래로 밀려, 옛 좌표 (971,387)
# 이 '아르바이트' 아이콘이 됐습니다 (실측: 어비스는 (971,531)). 새 고정 좌표로 바꾸면
# 다음 배너에서 또 깨지므로 글자를 찾아 누릅니다.
Assert-Case '어비스 메뉴: 고정 좌표 대신 글자 탐색으로 클릭' `
  ($workerSource -match "Find-GameTextPoint[^\r\n]*\`$rgAbyssMenu\[0\][\s\S]{0,200}-SearchText '어비스' -ExactText '어비스'") $true
Assert-Case '어비스 메뉴: 글자를 못 찾으면 클릭하지 않고 재시도' `
  ($workerSource -match "메뉴에서 '어비스' 글자를 찾지 못했습니다") $true
Assert-Case '어비스 메뉴: 클릭 후 검증 - 다른 화면이면 ESC 복귀' `
  ($workerSource -match '어비스가 아닌 화면이 열렸습니다[\s\S]{0,300}Press-KeyOnce -VirtualKey 0x1B') $true
Assert-Case '어비스 메뉴: 판독 영역이 타일 그리드 전체 (한 줄 아님)' `
  ($workerSource -match "\`$rgAbyssMenu\s*=\s*@\(Get-ConfigValue \`$config @\('ocrRegions', 'abyssMenu'\) @\(850, 180, 350, 520\)\)") $true
Assert-Case '어비스 메뉴: 좌표 영역 변경이라 coordsVersion 인상 (v8~v13 - 네이티브 1908 계열)' `
  ($workerSource -match '\$coordsVersionCurrent = 13') $true
$abyssMenuRegion = $auditConfigJson.ocrRegions.abyssMenu
Assert-Case 'config: abyssMenu 영역이 워커 기본값과 일치' (($abyssMenuRegion -join ',')) '850,180,350,520'
Assert-Case 'config: coordsVersion 13' ([int]$auditConfigJson.coordsVersion) 13
# v12 (2026-08-13 21:35·21:38 실사고 ×2): 네이티브 1908에서 어비스 상세 하단 버튼 '이동하기'가
# 우측 경계(1080)에 걸려 '하7'로 반토막 - 이동 클릭 루프 조기 탈출 + 도착 대기 180초 헛대기.
# 오른쪽 +80 (왼쪽/상하 불변 - 구 범위가 신 범위의 부분집합).
Assert-Case 'v12: enterButton 워커 기본값 (880,630,280,48)' `
  ($workerSource -match "'enterButton'\) @\(880, 630, 280, 48\)") $true
$enterBtnRegion = $auditConfigJson.ocrRegions.enterButton
Assert-Case 'config: enterButton 영역이 워커 기본값과 일치' (($enterBtnRegion -join ',')) '880,630,280,48'
# 이동 클릭 루프 정직성 (2026-08-09 계약 배선 - 실제 전송된 클릭만 계수 + 0회면 도착 대기 금지)
Assert-Case 'v12: 이동 클릭 루프 2곳이 lastClickPerformed 검사' `
  ([regex]::Matches($workerSource, "이동 클릭을 건너뜀 \(커서 확인 실패\)").Count) 2
Assert-Case 'v12: 실제 클릭 0회면 도착 대기 진입 금지 (throw) 2곳' `
  ([regex]::Matches($workerSource, "'이동하기' 클릭을 한 번도 보내지 못했습니다").Count) 2
# 지역 제한 거부 토스트 (2026-08-13 21:51 진단 클릭 실측: '일반 필드에서만 입장 신청할 수
# 있습니다.' - 특수 지역이면 클릭을 받고도 거부만 하고 ~2초 표시. 같은 위치 재시작도
# 재실패 확정이라 조건부 정지(코드 4)로 사용자 조치 안내)
Assert-Case 'v12: 거부 토스트 판정 함수 존재 (조각 필드에서만/일반+신청)' `
  (($workerSource -match "function Test-AbyssFieldOnlyToast") -and
   ($workerSource -match "Contains\('필드에서만'\)")) $true
Assert-Case 'v12: 이동 클릭 직후 토스트 확인 → 조건부 정지 2곳 (혼자/함께)' `
  ([regex]::Matches($workerSource, "게임이 입장 신청을 거부했습니다").Count) 2
# '고스트 등록' 안내 (2026-08-13 22:18 실측 - 신규 화면, 사용자 확정: '나중에'만 클릭):
# '고스트'+'나중에' 이중 게이트, '나중에' 단어 자기앵커, 초록 버튼 좌표 미보유.
# 배선 2곳: 시작 복구 이벤트 ladder + 어비스 ESC-복귀 루프(X 순환보다 앞, 즉시).
Assert-Case '고스트: 판정 함수 존재 (이중 게이트)' `
  (($workerSource -match 'function Close-GhostRegisterPrompt') -and
   ($workerSource -match "Contains\('고스트'\)") -and
   ($workerSource -match "-eq '나중에'")) $true
Assert-Case '고스트: 배선 2곳 (시작 복구 ladder + 어비스 복귀 루프)' `
  ([regex]::Matches($workerSource, 'Close-GhostRegisterPrompt -Game \$Game').Count) 2
Assert-Case '고스트: 클릭은 자기앵커만 (지금 고스트 등록 좌표 미보유)' `
  ($workerSource -notmatch "'지금 고스트 등록'[^\r\n]*@\(") $true
# v13 (2026-08-13 23:31 실사고): 네이티브 1908 사냥터 첫 화면의 난이도 알약(글자 y102)과
# 더블 루팅 '도전'(y493)이 영역 상단(100/490)에 잘려 탐색 실패 → **어려움 요청이 일반 판으로
# 입장**(사용자 확인). 두 영역 위로 확장 + 난이도 미탐색을 fail-closed 정지로 격상
# (던전 2026-08-11 ③·어비스 08-01 과 계약 통일). 은동전 카드는 같은 캡처에서 판독 성공이라
# 무변경(규칙 8).
Assert-Case 'v13: htDifficulty 워커 기본값 (560,85,330,60)' `
  ($workerSource -match "'htDifficulty'\) @\(560, 85, 330, 60\)") $true
Assert-Case 'v13: htLootButton 워커 기본값 (388,470,130,102)' `
  ($workerSource -match "'htLootButton'\) @\(388, 470, 130, 102\)") $true
Assert-Case 'v13: htLootButtonAlt 워커 기본값 (388,469,205,106)' `
  ($workerSource -match "'htLootButtonAlt'\) @\(388, 469, 205, 106\)") $true
foreach ($htCase in @(
    @{ Key = 'htDifficulty';   E = '560,85,330,60';   Row = 102 }
    @{ Key = 'htLootButton';   E = '388,470,130,102'; Row = 493 }
    @{ Key = 'htLootButtonAlt'; E = '388,469,205,106'; Row = 493 })) {
  $htRegion = $auditConfigJson.ocrRegions.($htCase.Key)
  Assert-Case ('v13: config {0} = ({1})' -f $htCase.Key, $htCase.E) (($htRegion -join ',')) $htCase.E
  $htTop = [int]$htRegion[1]; $htBottom = $htTop + [int]$htRegion[3]
  Assert-Case ('v13: {0}이 네이티브 1908 글자 행 y{1}을 덮음' -f $htCase.Key, $htCase.Row) `
    (($htTop -le $htCase.Row) -and ($htBottom -ge $htCase.Row)) $true
}
Assert-Case 'v13: 사냥터 난이도 미탐색은 경고 진행이 아니라 정지 (오난이도 판 방지)' `
  (($workerSource -match "글자를 찾지 못했습니다 \(이 사냥터에 없는 난이도이거나 화면 판독 실패\)[\s\S]{0,200}?exit 4") -and
   ($workerSource -notmatch '이 사냥터에 없는 난이도일 수 있음')) $true
Assert-Case 'v13: 은동전 카드 영역은 무변경 (관측된 것만 수정 - 규칙 8)' `
  (($auditConfigJson.ocrRegions.htCardButton -join ',')) '400,288,130,80'
# v11 (2026-08-13 20:30 실사고): 네이티브 1908 창의 '발견한 전리품' 라벨이 ref (614~658,277)
# - 구영역 상단 293을 16px 이탈해 전리품 화면 진행 클릭이 안 나가 결과 대기 정체.
# 상단 265 확장 (하단 333·x 불변 - 구 범위가 신 범위의 부분집합이라 1272 회귀 면 0).
Assert-Case 'v11: dgLootReveal 워커 기본값 (520,265,240,68)' `
  ($workerSource -match "'dgLootReveal'\) @\(520, 265, 240, 68\)") $true
$lootRevealRegion = $auditConfigJson.ocrRegions.dgLootReveal
Assert-Case 'config: dgLootReveal 영역이 워커 기본값과 일치' (($lootRevealRegion -join ',')) '520,265,240,68'
$lootRevealTop = [int]$auditConfigJson.ocrRegions.dgLootReveal[1]
$lootRevealBottom = $lootRevealTop + [int]$auditConfigJson.ocrRegions.dgLootReveal[3]
Assert-Case 'v11: 네이티브 1908 라벨(y277)을 덮음' (($lootRevealTop -le 277) -and ($lootRevealBottom -ge 277)) $true
Assert-Case 'v11: 구 하단 경계(333) 유지 (1272 커버 불변)' $lootRevealBottom 333
# 옵션 난이도 알약 (2026-08-13 20:48 실사고 - 하드코딩 영역이라 coordsVersion 무관):
# 네이티브 1908 심층 다시하기-복귀 옵션의 '어려움' 글자 상단(~95)이 구 상단 95에 걸려
# 토큰째 사망. 상단 85 확장 (하단 145 유지 - 구 범위가 신 범위의 부분집합).
# 리터럴 (600,85,320,60) = 네이티브 y103·1272 y121 모두 커버 (85≤103,121≤145 - 산술 자명)
Assert-Case '옵션 알약: 워커 하드코딩 (600,85,320,60)' `
  ($workerSource -match '\$rgDgOptDifficulty = @\(600, 85, 320, 60\)') $true
# 어비스 ESC 자기앵커 (2026-08-13 21:25 실사고): 고정점 (1083,89)가 네이티브 1908에서 버튼
# 밖(실측 (1102,74)) - 17회 무반응. 읽힌 'ESC' 글자 위치 클릭 + 고정점 폴백(1272 유지).
Assert-Case '어비스 ESC: 글자 탐색 클릭 배선 (rgHomeEndEsc + ESC)' `
  ($workerSource -match "Find-GameTextPoint[^\r\n]*\`$rgHomeEndEsc\[0\][\s\S]{0,220}?-SearchText 'ESC' -ExactText 'ESC'") $true
Assert-Case '어비스 ESC: 미발견 시 고정점 폴백 유지' `
  ($workerSource -match "if \(\`$escPoint\) \{[\s\S]{0,120}?Click-ScreenPoint[\s\S]{0,200}?Click-GamePoint[^\r\n]*ptEscButton") $true
# v8 (2026-08-13 실사고): 네이티브 1908 창(모니터 100% + 물리 1908 리사이즈, 제목줄 31px)은
# 선택 화면 알약 행이 y163 - 구영역(30,165,200,50)을 1px 차로 이탈해 3연속 정지.
# 위로 20 확장. 두 실측 기하(1272 네이티브 y187 / 1908 네이티브 y163)를 모두 덮고,
# 탭 행(1272 y128)과 층 패널 '1층 매우 어려움'(1908 y232)은 계속 배제해야 합니다.
Assert-Case 'v8: dgDifficulty 워커 기본값 (30,145,200,70)' `
  ($workerSource -match "\`$rgDgDifficulty = @\(Get-ConfigValue \`$config @\('ocrRegions', 'dgDifficulty'\) @\(30, 145, 200, 70\)\)") $true
$dgDiffRegion = $auditConfigJson.ocrRegions.dgDifficulty
Assert-Case 'config: dgDifficulty 영역이 워커 기본값과 일치' (($dgDiffRegion -join ',')) '30,145,200,70'
$dgDiffTop = [int]$auditConfigJson.ocrRegions.dgDifficulty[1]
$dgDiffBottom = $dgDiffTop + [int]$auditConfigJson.ocrRegions.dgDifficulty[3]
Assert-Case 'v8: 네이티브 1908 알약(y163)을 덮음' (($dgDiffTop -le 163) -and ($dgDiffBottom -ge 163)) $true
Assert-Case 'v8: 네이티브 1272 알약(y187)을 덮음' (($dgDiffTop -le 187) -and ($dgDiffBottom -ge 187)) $true
Assert-Case 'v8: 탭 행(y128)은 배제' ($dgDiffTop -gt 128) $true
Assert-Case 'v8: 층 패널 라벨(y232)은 배제' ($dgDiffBottom -lt 232) $true
# v9 (2026-08-13 11:53 실사고): 네이티브 1908 창의 제목 글자 상단이 ref 42(사용자 PC)~44.6
# (타 PC 5장 실측) - 구영역 상단 45가 구역 숫자 윗부분을 잘라 '2층 2구역' 꼬리가 전 단에서
# 사망. 상단 34로 확장(하단 100 유지). 제목줄 밴드(DWM 스트레치 하단 ref 31.3)는 계속 배제.
Assert-Case 'v9: dgTitle 워커 기본값 (30,34,250,66)' `
  ($workerSource -match "\`$rgDgTitle\s+=\s+@\(Get-ConfigValue \`$config @\('ocrRegions', 'dgTitle'\) @\(30, 34, 250, 66\)\)") $true
$dgTitleRegion = $auditConfigJson.ocrRegions.dgTitle
Assert-Case 'config: dgTitle 영역이 워커 기본값과 일치' (($dgTitleRegion -join ',')) '30,34,250,66'
$dgTitleTop = [int]$auditConfigJson.ocrRegions.dgTitle[1]
$dgTitleBottom = $dgTitleTop + [int]$auditConfigJson.ocrRegions.dgTitle[3]
Assert-Case 'v9: 네이티브 1908 제목 글자 상단(y42)을 덮음' ($dgTitleTop -le 42) $true
Assert-Case 'v9: 창 제목줄 밴드(y31)는 배제' ($dgTitleTop -gt 31) $true
Assert-Case 'v9: 하단 경계 100 유지 (아래 요소 오탐 면 불변)' $dgTitleBottom 100
# v10 (2026-08-13 13:03 실사고): 네이티브 1908 창의 카드 버튼 글자가 소탕 (427,280) /
# 루팅 (415,466) - 기존 영역(상단 292/493)을 이탈해 6회전 '(판독 없음)' 정지. 4영역 상단
# 확장 + Set-DgToggleCard 클릭 자기앵커(-AnchorClickToText, 던전 호출부 한정 - 사냥터는
# 실측 캡처가 없어 기존 고정점 유지).
foreach ($cardCase in @(
    @{ Key = 'dgCoinButton';    E = '388,264,205,86'; Rows = @(280, 314) }
    @{ Key = 'dgCoinButtonAlt'; E = '400,262,130,74'; Rows = @(280, 314) }
    @{ Key = 'dgLootButton';    E = '388,452,130,90'; Rows = @(466, 516) }
    @{ Key = 'dgLootButtonAlt'; E = '388,448,205,95'; Rows = @(466, 516) })) {
  $cardRegion = $auditConfigJson.ocrRegions.($cardCase.Key)
  Assert-Case ('v10: config {0} = ({1})' -f $cardCase.Key, $cardCase.E) (($cardRegion -join ',')) $cardCase.E
  $cardTop = [int]$cardRegion[1]; $cardBottom = $cardTop + [int]$cardRegion[3]
  foreach ($rowY in $cardCase.Rows) {
    Assert-Case ('v10: {0}이 글자 행 y{1}을 덮음 (네이티브 1908/1272 실측)' -f $cardCase.Key, $rowY) `
      (($cardTop -le $rowY) -and ($cardBottom -ge $rowY)) $true
  }
}
# 워커 기본값이 config와 일치 (사본 방지 - 소스 대입식 문자열 검증)
Assert-Case 'v10: dgCoinButton 워커 기본값 일치' `
  ($workerSource -match "'dgCoinButton'\) @\(388, 264, 205, 86\)") $true
Assert-Case 'v10: dgLootButton 워커 기본값 일치' `
  ($workerSource -match "'dgLootButton'\) @\(388, 452, 130, 90\)") $true
Assert-Case 'v10: dgCoinButtonAlt 워커 기본값 일치' `
  ($workerSource -match "'dgCoinButtonAlt'\) @\(400, 262, 130, 74\)") $true
Assert-Case 'v10: dgLootButtonAlt 워커 기본값 일치' `
  ($workerSource -match "'dgLootButtonAlt'\) @\(388, 448, 205, 95\)") $true
# 자기앵커 배선: 던전 호출부 6곳만 스위치 사용, 사냥터 4곳은 기존 고정점 동작 유지
Assert-Case 'v10: -AnchorClickToText 던전 호출부 6곳' `
  ([regex]::Matches($workerSource, 'Set-DgToggleCard[^\r\n]*-AnchorClickToText').Count) 6
Assert-Case 'v10: 사냥터 호출부는 자기앵커 미사용 (Ht 영역 + 스위치 없음)' `
  ([regex]::Matches($workerSource, 'Set-DgToggleCard[^\r\n]*rgHt[^\r\n]*-AnchorClickToText').Count) 0
# 소모량 정정 1회 클릭: 고정점 블라인드 클릭 제거, 스냅샷 좌표만 사용
Assert-Case 'v10: 정정 클릭이 고정 ptDgLootButton 을 직접 쓰지 않음' `
  ([regex]::Matches($workerSource, 'Click-GamePoint[^\r\n]*ptDgLootButton').Count) 0
Assert-Case 'v10: 정정 클릭이 스냅샷 좌표(lootWordPoint) 사용' `
  ($workerSource -match 'Click-GamePoint[^\r\n]*lootWordPoint') $true
# '우연한 만남' 토글 자기앵커 (2026-08-13 19:15·19:26 실사고 ×2): 고정점 (1183,415)가
# 네이티브 1908에서 토글 밖 회색 - 'off' 오판 + 빈 자리 클릭. 던전 두 분기(켜기/끄기)를
# 라벨 앵커로 개편, 고정점($ptDgChanceToggle) 사용 0곳, 미확인은 fail-closed.
Assert-Case '토글: 던전 흐름에서 고정점 사용 0곳 (자기앵커 전환)' `
  ([regex]::Matches($workerSource, '\$ptDgChanceToggle\[').Count) 0
Assert-Case '토글: 켜기/끄기 분기가 앵커 헬퍼 사용 (2곳 이상)' `
  ([regex]::Matches($workerSource, 'Find-DgChanceTogglePoint -Game \$Game').Count -ge 2) $true
Assert-Case '토글: 켬 확인 실패는 경고 진행이 아니라 정지 (오입장 방지)' `
  ($workerSource -match "토글을 켠 것을 확인하지 못했습니다[^\r\n]*정지") $true
Assert-Case '토글: 어비스 고정점은 무변경 (실측 없음 - 규칙 8)' `
  ([regex]::Matches($workerSource, '\$ptAbyssChanceToggle\[').Count -ge 1) $true
# 판독 영역은 '광고 없음(어비스 y387)' 과 '광고 있음(y531)' 을 모두 덮어야 합니다.
# 실측: 광고 없을 때 y387(2026-07-16 옛 ptAbyssMenu) / 광고 있을 때 y531(2026-08-08).
$abyssTop = [int]$auditConfigJson.ocrRegions.abyssMenu[1]
$abyssBottom = $abyssTop + [int]$auditConfigJson.ocrRegions.abyssMenu[3]
Assert-Case '어비스 메뉴: 광고 없을 때 위치(y387)를 덮음' (($abyssTop -le 387) -and ($abyssBottom -ge 387)) $true
Assert-Case '어비스 메뉴: 광고 있을 때 위치(y531)를 덮음' (($abyssTop -le 531) -and ($abyssBottom -ge 531)) $true
# 배너 영역(y33~175)은 **일부러 제외**합니다 - 포함하면 광고 문구의 '어비스'를 누릅니다
Assert-Case '어비스 메뉴: 상단 광고 배너 영역은 제외 (광고 문구 오클릭 방지)' ($abyssTop -ge 176) $true
exit $fails
