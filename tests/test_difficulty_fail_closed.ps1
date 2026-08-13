# 난이도 fail-closed 배선 가드 (2026-08-11 ③ - 13:33 사냥터 실기 실측 대응)
# 실측된 결함 사슬: 클릭 생략(커서) → 거짓 '클릭' 로그 → 확인 실패 무시 → 오난이도 진행.
# 수정 계약: ①생략 시 같은 화면 한정 재전송(최대 3회) ②'클릭' 로그는 실제 전송 후에만
# ③확인 실패는 정지(비커스텀 포함) ④옵션 화면은 기존 자기 방해 방지 계약 보존
# (실제 클릭 후 수동 확인 3회 → 최종 1회 재클릭 - 생략 재전송만 추가).
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

# ── 사냥터 ──
Assert-Case '사냥터: 생략 재전송 루프 (같은 화면 = 입장 버튼 잔존일 때만)' `
  ([bool]($workerRaw -match '(?s)\$htDiffClicked = \$false.{0,600}if \(\$script:lastClickPerformed\) \{ \$htDiffClicked = \$true; break \}.{0,300}Find-HtEntryButtonPoint')) 'True'
Assert-Case '사냥터: 전송 실패 지속이면 정지 (exit 4)' `
  ([bool]($workerRaw -match "(?s)if \(-not \`$htDiffClicked\) \{[^}]*클릭을 전송하지 못했습니다[^}]*exit 4")) 'True'
Assert-Case "사냥터: '클릭' 로그가 전송 확인 뒤" `
  ([bool]($workerRaw -match "(?s)if \(-not \`$htDiffClicked\) \{[^}]*exit 4\s*\r?\n\s*\}\s*\r?\n\s*Write-RunLog \(?`"\[사냥터\] 난이도 '\`$htDifficulty' 클릭`"")) 'True'
Assert-Case '사냥터: 확인 결과를 버리지 않음 (Out-Null 제거)' `
  ([bool]($workerRaw -match 'Confirm-DifficultySelected -Game \$Game -ClickPoint \$difficultyPoint -Label \$htDifficulty \| Out-Null')) 'False'
Assert-Case '사냥터: 확인 실패 시 같은 화면 한정 1회 정정 후 최종 정지' `
  ([bool]($workerRaw -match "(?s)if \(-not \`$htDiffConfirmed\) \{\s*\r?\n\s*Write-RunLog `"\[완료\] 난이도 '\`$htDifficulty' 선택을 확인하지 못했습니다[^`"]*정지합니다`"\s*\r?\n\s*exit 4")) 'True'
# 글자 미발견도 정지로 격상 (2026-08-13 23:31 실사고 - '경고 후 현재 난이도로 진행' 계약이
# 네이티브 1908 판독 실패와 만나 **어려움 요청을 일반 판으로** 돌렸음(사용자 확인).
# 미지원 난이도와 판독 실패는 구분할 수 없어 둘 다 정지가 안전 - 던전·어비스와 계약 통일)
Assert-Case '사냥터: 글자 미발견도 fail-closed 정지 (오난이도 판 방지)' `
  ([bool]($workerRaw -match "(?s)\[완료\] 난이도 '\`$htDifficulty' 글자를 찾지 못했습니다[^`"]*정지합니다[^`"]*`"\s*\r?\n\s*exit 4")) 'True'
Assert-Case '사냥터: 옛 경고 진행 문구가 남아 있지 않음' `
  ([bool]($workerRaw -match '이 사냥터에 없는 난이도일 수 있음')) 'False'

# ── 던전 선택 화면 ──
Assert-Case '던전 선택: 생략 재전송 루프 (진입 버튼 잔존일 때만)' `
  ([bool]($workerRaw -match '(?s)\$ndDiffClicked = \$false.{0,600}Get-DgStageEnterButtonText.{0,120}진입')) 'True'
Assert-Case '던전 선택: 매우 어려움 확인 실패는 기존 throw 유지' `
  ([bool]($workerRaw -match "매우 어려움' 선택 강조를 확인하지 못했습니다 - 오난이도 입장을 막기 위해 중단합니다")) 'True'
Assert-Case '던전 선택: 일반/어려움 확인 실패도 정지 (신설)' `
  ([bool]($workerRaw -match "(?s)if \(-not \`$diffConfirmed\) \{[^}]*난이도 '\`$ndDifficulty' 선택을 확인하지 못했습니다[^}]*exit 4")) 'True'

# ── 어비스 상세 ──
Assert-Case '어비스: 생략 재전송 루프 (상세 제목 일치일 때만)' `
  ([bool]($workerRaw -match '(?s)\$abyssDiffClicked = \$false.{0,600}Test-DetailTitleMatches -Game \$game')) 'True'
Assert-Case '어비스: 확인 실패는 커스텀 여부와 무관하게 정지' `
  ([bool]($workerRaw -match "(?s)if \(-not \`$abyssDiffConfirmed\) \{[^}]*선택을 확정하지 못했습니다[^}]*exit 4")) 'True'
Assert-Case '어비스: 옛 커스텀 한정 게이트가 남아 있지 않음' `
  ([bool]($workerRaw -match 'if \(\$script:customMode -and -not \$abyssDiffConfirmed\)')) 'False'

# ── 옵션 화면 (기존 계약 보존 + 생략 재전송) ──
$optBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Set-DgOptionDifficulty'))
$optCode = (($optBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '옵션: 생략 재전송은 lastClickPerformed 조건 + 제목 구역 확인' `
  ([bool]($optCode -match '(?s)-not \$script:lastClickPerformed[\s\S]{0,200}Read-DgTitleText[^\r\n]*Contains\(''구역''\)')) 'True'
Assert-Case '옵션: 실제 클릭 후 수동 확인 3회 유지 (자기 방해 방지 계약)' `
  ([bool]($optCode -match '(?s)passiveTry = 1; \$passiveTry -le 3')) 'True'
Assert-Case '옵션: 최종 1회 재클릭 계약 유지' `
  ([bool]($optCode -match '(?s)finalTry = 1; \$finalTry -le 3')) 'True'
Assert-Case '옵션 호출부: 비커스텀 일반/어려움 확정 실패도 정지 (신설)' `
  ([bool]($workerRaw -match "(?s)옵션 화면에서 난이도 '\`$ndDifficulty' 선택을 확정하지 못했습니다 - 오난이도 판 방지를 위해 정지합니다[^\r\n]*\r?\n\s*exit 4")) 'True'

exit $fails
