# 2026-08-01 전수 점검(Codex 협업) 수정 배선 가드 - 워커/GUI/빌드/런처 일괄
# 각 수정의 근거·경위는 이슈_개선점_목록.md '2026-08-01 - 전수 점검 결함 일괄 수정' 참고
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerSource = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))
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
Assert-Case '워커: 클리어 대기 while($true) + 최상단 마감/연장 판정' `
  ($workerSource -match 'while \(\$true\) \{\s+# 마감/전투 연장 판정 \(본문 최상단[\s\S]{0,2800}?\$pollCounter\+\+') $true
Assert-Case '워커: 연장 판독 중 캡처 실패도 throw 제외' `
  ($workerSource -match '\} elseif \(\$script:screenCaptureFailing\) \{\s+# 연장 판독\(Test-InDungeonQuest\) 도중') $true
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
Assert-Case '워커: 커스텀 카드 미확인+소모량 null 정지' `
  ($workerSource -match 'customMode -and \(-not \$coinToggleOk -or -not \$lootToggleOk\)[\s\S]{0,300}?exit 4') $true

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
  ([regex]::Matches($workerSource, '오난이도 판 방지를 위해 정지합니다').Count) 2

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

# ── 3차 전수 검사 반영 (2026-08-01 - Codex 조건 포함) ─────────────────────────
# 회귀: 복구 회차가 복귀로 확정된 선택 화면 플래그를 신뢰
Assert-Case '3차: 복구 판정이 onSelectionScreen 플래그 신뢰' `
  ($workerSource -match '\$recoveryOnSelection = \(\$onSelectionScreen -or \(Test-DgSelectionTitle') $true
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
Assert-Case '3차: 정정 클릭 잔상 가드(coin/loot 클릭 공통)' `
  ($workerSource -match '\(\$coinToggleClicked -or \$lootToggleClicked\) -and \$coinToggleOk -and \$lootToggleOk') $true
# 다중 스케일 1~2회전 (첫 회전 화면 전환 대비)
Assert-Case '3차: 카드 다중 스케일 1~2회전' `
  ($workerSource -match 'if \(\$setTry -le 2\) \{ \$cardScales = @\(5, 3, 4\) \}') $true
# 복귀 함수: 선택 화면 return 직전 안전 중지 소비
Assert-Case '3차: 선택 화면 복귀 직전 안전 중지 소비' `
  ($workerSource -match 'Test-AbyssSelectionScreen -Game \$Game\) \{\s+# 선택 화면 도달 직전의 안전 중지[\s\S]{0,700}exit \$SafeStopExitCode') $true
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

exit $fails
