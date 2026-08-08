# 마지막 판 나가기 기능 진리표 (2026-07-25 - 마지막 판 완료 시 '나가기'로 필드 복귀)
# 본체: mabinogi_gui.ps1 Test-CustomLastRun + Start-NextCycle env / mabinogi_run_once.ps1 14-0 단계
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Test-CustomLastRun')) {
  Invoke-Expression $definition
}
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-DgLastRunExitStep')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 커스텀 마지막 판 판정 (횟수 모드 x 마지막 바퀴 x 마지막 항목일 때만 true) ──
$lastRunCases = @(
  @{ N = '2바퀴 마지막 바퀴 마지막 항목'; R = 'count'; C = 2; L = 2; I = 2; T = 3; E = $true }
  @{ N = '2바퀴 마지막 바퀴 중간 항목';   R = 'count'; C = 2; L = 2; I = 1; T = 3; E = $false }
  @{ N = '2바퀴 첫 바퀴 마지막 항목';     R = 'count'; C = 2; L = 1; I = 2; T = 3; E = $false }
  @{ N = '1바퀴 단일 항목';               R = 'count'; C = 1; L = 1; I = 0; T = 1; E = $true }
  @{ N = '1바퀴 6항목 마지막 (실기 구성)'; R = 'count'; C = 1; L = 1; I = 5; T = 6; E = $true }
  @{ N = '1바퀴 6항목 첫 항목';           R = 'count'; C = 1; L = 1; I = 0; T = 6; E = $false }
  @{ N = '무한 반복은 마지막 없음';       R = 'infinite'; C = 1; L = 9; I = 5; T = 6; E = $false }
  @{ N = '방어: 바퀴 수 0';               R = 'count'; C = 0; L = 1; I = 0; T = 1; E = $false }
  @{ N = '방어: 바퀴 초과 진행도 저장분'; R = 'count'; C = 2; L = 3; I = 2; T = 3; E = $true }
)
foreach ($case in $lastRunCases) {
  Assert-Case "마지막판: $($case.N)" `
    (Test-CustomLastRun -ListRepeat $case.R -ListRepeatCount $case.C -Lap $case.L -Index $case.I -Total $case.T) $case.E
}

# ── 나가기 확인 루프의 한 판독분 판정 (리뷰 2차 리뷰 반영 - 단발 OCR 오판 방지) ──
$exitStepCases = @(
  @{ N = '나가기 팝업 (탐험+계속하)'; H = $false; Q = ''; C = '던전탐험을 계속하시겠습니까?'; R = $false; E = 'popup-exit' }
  @{ N = '팝업이 결과 화면 판독보다 우선'; H = $true; Q = ''; C = '던전탐험을계속하시겠습니까'; R = $true; E = 'popup-exit' }
  @{ N = "'계속하' 조각만으로는 팝업 아님 (느슨 매칭 금지)"; H = $false; Q = ''; C = '계속하'; R = $false; E = 'wait' }
  @{ N = '결과 화면 잔존 = 재클릭'; H = $false; Q = ''; C = ''; R = $true; E = 'reclick' }
  @{ N = '필드 증거 (HUD + 던전 목표 없음)'; H = $true; Q = '반호르 가기'; C = ''; R = $false; E = 'field-evidence' }
  @{ N = 'HUD 있어도 던전 목표(구역) 있으면 보류'; H = $true; Q = '1층 1구역 클리어'; C = ''; R = $false; E = 'wait' }
  @{ N = 'HUD 없음 = 보류'; H = $false; Q = ''; C = ''; R = $false; E = 'wait' }
)
foreach ($case in $exitStepCases) {
  Assert-Case "나가기판정: $($case.N)" `
    (Get-DgLastRunExitStep -HudVisible $case.H -QuestText $case.Q -CenterText $case.C -RetryVisible $case.R) $case.E
}

# ── 본체 소스 계약 검사 ──────────────────────────────────────────────────────
$guiSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_gui.ps1') -Raw -Encoding UTF8
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8

Assert-Case 'GUI: 커스텀/비커스텀 두 분기 모두 신호 설정 + 정리 목록 포함' `
  ([regex]::Matches($guiSource, 'HONEYNOGI_LAST_RUN').Count -ge 3) $true
Assert-Case 'GUI: 비커스텀은 시간 지정 아님 + 횟수 모드 조건 포함' `
  ($guiSource -match "HONEYNOGI_LAST_RUN = \`$\(if \(\(\`$null -eq \`$script:targetTime\) -and \(\`$script:targetCycles -gt 0\)") $true
Assert-Case '워커: 신호는 문자열 1 비교로 해석' `
  ($workerSource.Contains("`$script:dgLastRun = ([string]`$env:HONEYNOGI_LAST_RUN -eq '1')")) $true
Assert-Case '워커: 마지막 판 나가기는 은동전 잔량 검사(14-1)보다 앞' `
  ($workerSource.IndexOf('마지막 판 완료') -lt $workerSource.IndexOf('다음 판의 은동전 잔량')) $true
Assert-Case '워커: 수동 정리 모드는 나가기 제외' `
  ($workerSource -match "if \(\`$script:dgLastRun -and -not \`$script:customCleanupOnly\)") $true
Assert-Case '워커: 필드 확정은 HUD + 퀘스트 추적기 구역 부재 이중 확인' `
  ($workerSource -match "dgLastRun[\s\S]{0,4000}Test-HomeEndEscHud[\s\S]{0,600}rgQuestTracker") $true
Assert-Case '워커: 계속하시겠습니까 팝업은 나가기(Space) 선택' `
  ($workerSource.Contains('나가기(Space) 선택')) $true
Assert-Case '워커: 필드 미확인 시 진단 저장 후 정상 종료 (오류 재시작 방지)' `
  ($workerSource -match "마지막 판 나가기 후 필드 미확인[\s\S]{0,600}exit 0") $true
Assert-Case '워커: 필드 확정은 연속 2회 증거 요구 (단발 OCR 오판 방지)' `
  ($workerSource.Contains('$fieldStreak -ge 2')) $true
Assert-Case '워커: 판독 도중 캡처 실패 시 그 판독분 폐기' `
  ($workerSource.Contains('판독 도중 캡처 실패')) $true
Assert-Case '워커: 마지막 판 복구는 필드 상태를 복구 완료로 인정' `
  ($workerSource -match "customRecoveryOnly[\s\S]{0,1500}dgLastRun[\s\S]{0,1600}재입장 없이 복구 완료") $true

exit $fails
