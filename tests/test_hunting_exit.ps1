# 나가기 확인 종료 계약 (2026-08-11 ⑤) - 배선 가드 + 필드 증거 판정
# 실측 근거: 클릭 생략 기전은 13:33 사냥터 실기로 확정 (같은 클릭 함수·같은 조건).
# 계약: 나가기 후 종료 3곳(사냥터 소진/안전 중지/던전 잔량)은 필드 복귀를 **연속 2회**
# 확인한 뒤에만 종료하고, 안전 중지의 성공 코드(0/10)는 확인 성공일 때만. 재클릭은
# 소스 화면이 그대로 보일 때만 (상태 기반 - 무조건 재클릭 금지).
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

$fails = 0
function Assert-Case {
  param([string]$Name, $Actual, $Expected)
  $actualText = if ($null -eq $Actual) { 'null' } else { "$Actual" }
  $expectedText = if ($null -eq $Expected) { 'null' } else { "$Expected" }
  if ($actualText -eq $expectedText) { Write-Host "OK   ${Name}: $actualText" }
  else { Write-Host "FAIL ${Name}: 실제 [$actualText] 기대 [$expectedText]"; $script:fails++ }
}

$workerRaw = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))

# ── 1. 필드 증거 판정 (본체 + 스텁 진리표) ────────────────────────────────────
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Test-BattleFieldEvidence')) {
  . ([scriptblock]::Create($definition))
}
$script:screenCaptureFailing = $false
$script:stubHud = $true
$script:stubQuest = ''
$rgQuestTracker = @(980, 212, 285, 55)
$ocrKoreanEngine = $null
function Test-HomeEndEscHud { param($Game) return $script:stubHud }
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine) return $script:stubQuest }

$script:stubHud = $true; $script:stubQuest = '주간목표모험가길드의정기의뢰'
Assert-Case '필드 증거: HUD + 콘텐츠 목표 없음 = 참' (Test-BattleFieldEvidence -Game $null) 'True'
$script:stubQuest = '심층2층2구역클리어'
Assert-Case '필드 증거: 던전 목표(구역) 잔존 = 거짓' (Test-BattleFieldEvidence -Game $null) 'False'
$script:stubQuest = '창백한산몬스터소탕45회'
Assert-Case '필드 증거: 사냥 임무(소탕) 잔존 = 거짓' (Test-BattleFieldEvidence -Game $null) 'False'
$script:stubQuest = '8구역정찰지점이동'
Assert-Case '필드 증거: 정찰 임무 잔존 = 거짓 (구역 조각과 중복이어도 무해)' (Test-BattleFieldEvidence -Game $null) 'False'
$script:stubHud = $false; $script:stubQuest = ''
Assert-Case '필드 증거: HUD 없음 = 거짓' (Test-BattleFieldEvidence -Game $null) 'False'
$script:stubHud = $true
$script:screenCaptureFailing = $true
Assert-Case '필드 증거: 캡처 실패 중 판독은 무효' (Test-BattleFieldEvidence -Game $null) 'False'
$script:screenCaptureFailing = $false

# ── 2. 검증 종료 루프 배선 ────────────────────────────────────────────────────
$loopBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Invoke-VerifiedContentExit'))
$loopCode = (($loopBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '루프: 필드 증거 연속 2회 요구' `
  ([bool]($loopCode -match '\$fieldStreak -ge 2')) 'True'
Assert-Case '루프: 증거가 끊기면 연속 카운트 리셋' `
  (@([regex]::Matches($loopCode, '\$fieldStreak = 0')).Count -ge 2) 'True'
Assert-Case "루프: '계속하' 팝업 나가기는 검증 입력(Space)" `
  ([bool]($loopCode -match "Press-KeyVerified -Game \`$Game -VirtualKey \(\[byte\]32\)")) 'True'
Assert-Case '루프: 캡처 실패 동결 계약 (공통 진입점 + 복구 탐침 + 한도 리셋)' `
  ([bool]($loopCode -match '(?s)Test-SafeStopDuringCaptureFail.{0,200}Test-CaptureRecovered.{0,200}AddSeconds\(\$TimeoutSeconds\)')) 'True'

# ── 3. 세 종료 경로 배선 ──────────────────────────────────────────────────────
$htBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Exit-HuntingGroundExhausted'))
Assert-Case '사냥터 소진: 검증 종료 루프 경유' ([bool]($htBody -match 'Invoke-VerifiedContentExit')) 'True'
Assert-Case '사냥터 소진: 재클릭은 화면 상태 조건부 (첫 화면 X / 결과 나가기)' `
  ([bool]($htBody -match '(?s)if \(Find-HtEntryButtonPoint[\s\S]{0,220}ptHtClose[\s\S]{0,120}elseif \(Find-HtNewMissionPoint[\s\S]{0,220}ptDgResultExit')) 'True'
Assert-Case '사냥터 소진: 확인 실패도 정지는 함(정직한 경고 후 exit 4)' `
  ([bool]($htBody -match '(?s)복귀를 확인하지 못한 채 정지합니다[\s\S]{0,120}exit 4')) 'True'

$ssBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Invoke-SafeStopExitIfRequested'))
$ssCode = (($ssBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '안전 중지: 검증 종료 루프 경유' ([bool]($ssCode -match 'Invoke-VerifiedContentExit')) 'True'
Assert-Case '안전 중지: exit 0 은 확인 성공 분기 안에서만' `
  ([bool]($ssCode -match '(?s)if \(\$exitVerified\) \{[^}]*exit 0')) 'True'
Assert-Case '안전 중지: 확인 실패는 회차 미계상 정지 (exit 4)' `
  ([bool]($ssCode -match '(?s)나가기\(필드 복귀\)를 확인하지 못했습니다[^}]*exit 4')) 'True'
Assert-Case '안전 중지: 커스텀 정리 모드 성공은 코드 10 유지' `
  ([bool]($ssCode -match '(?s)customCleanupOnly[\s\S]{0,600}exit 10')) 'True'
Assert-Case '안전 중지: 재클릭은 결과 화면 잔존일 때만 (던전/사냥터 양쪽 탐지)' `
  ([bool]($ssCode -match '(?s)Find-DgRetryButtonPoint[\s\S]{0,120}Find-HtNewMissionPoint[\s\S]{0,220}ptDgResultExit')) 'True'
Assert-Case '안전 중지: 신호 파일은 여전히 먼저 소비 (잔존 오작동 방지 계약 유지)' `
  ([bool]($ssCode -match '(?s)Remove-Item -LiteralPath \$safeStopFlagPath[\s\S]{0,400}Invoke-VerifiedContentExit')) 'True'

Assert-Case '던전 잔량 부족: 검증 종료 루프 경유 + exit 4' `
  ([bool]($workerRaw -match '(?s)나가기를 누르고 설정대로 자동화를 마칩니다[\s\S]{0,700}Invoke-VerifiedContentExit[\s\S]{0,700}exit 4')) 'True'

exit $fails
