# 던전 시작 0-1단계(진입 옵션 화면 스테이지 검증) 판정 진리표 - 설정 1-3 기준
# 본체: mabinogi_run_once.ps1 Invoke-NormalDungeonCycle 0-1단계
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-DgSelectionRecoveryAction', 'Get-DgOptStageFallbackPoint', 'Test-DgStageEnterTextMatches')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# 선택 화면 목표 클릭이 빗나간 경우의 복구 판정. 첫 케이스는 2026-07-21 사용자 오류 로그 원문입니다.
$selectionCases = @(
  @{ N = '오류 로그 1-1 목표/현재 1-3'; T = '11층3구역진입'; S = '1-1'; A = 'same-floor'; C = '1-3' }
  @{ N = '같은 층 1-2 오선택'; T = '1층2구역진입'; S = '1-1'; A = 'same-floor'; C = '1-2' }
  @{ N = '목표 구역 선택 성공'; T = '11층1구역진입'; S = '1-1'; A = 'selected'; C = '1-1' }
  @{ N = '다른 층 오선택'; T = '2층3구역진입'; S = '1-1'; A = 'different-floor'; C = '2-3' }
  @{ N = '층 글자 깨짐도 같은 층'; T = '1츰3구역진입'; S = '1-1'; A = 'same-floor'; C = '1-3' }
  @{ N = '층 글자 소실도 같은 층'; T = '13구역진입'; S = '1-1'; A = 'same-floor'; C = '1-3' }
  @{ N = '층 숫자 없음'; T = '3구역진입'; S = '1-1'; A = 'unclear'; C = '' }
  @{ N = '빈 OCR'; T = ''; S = '1-1'; A = 'unclear'; C = '' }
  @{ N = '목표 형식 오류'; T = '1층3구역진입'; S = 'x'; A = 'unclear'; C = '' }
)
foreach ($case in $selectionCases) {
  $result = Get-DgSelectionRecoveryAction -EnterText $case.T -TargetStage $case.S
  Assert-Case "$($case.N): 동작" $result.Action $case.A
  Assert-Case "$($case.N): 현재 구역" $result.CurrentStage $case.C
}

# 옵션 화면 구역 지도는 층마다 실제 배치가 다릅니다. 특히 2-1은 2026-07-21 오류 캡처에서
# 기존 1층 예비 좌표(830,308)가 카드 왼쪽 빈 곳을 눌렀던 사례를 그대로 고정합니다.
$optionFallbackCases = @(
  @{ N = '1층 1구역 기존 좌표 유지'; S = '1-1'; X = 830;  Y = 308 }
  @{ N = '1층 2구역 기존 좌표 유지'; S = '1-2'; X = 918;  Y = 310 }
  @{ N = '1층 3구역 기존 좌표 유지'; S = '1-3'; X = 1022; Y = 266 }
  @{ N = '2층 1구역 실측 좌표';      S = '2-1'; X = 875;  Y = 307 }
  @{ N = '2층 2구역 실측 좌표';      S = '2-2'; X = 875;  Y = 225 }
  @{ N = '2층 3구역 실측 좌표';      S = '2-3'; X = 980;  Y = 266 }
)
foreach ($case in $optionFallbackCases) {
  $point = Get-DgOptStageFallbackPoint -Stage $case.S
  Assert-Case "$($case.N): X" $point.X $case.X
  Assert-Case "$($case.N): Y" $point.Y $case.Y
}
Assert-Case '지원하지 않는 층·구역은 좌표 없음' `
  ($null -eq (Get-DgOptStageFallbackPoint -Stage '3-1')) $true

Assert-Case '던전 진입 게이트: 목표 1-1 버튼 허용' `
  (Test-DgStageEnterTextMatches -EnterText '1층 1구역 진입' -Stage '1-1') $true
Assert-Case '던전 진입 게이트: 공물 숫자가 붙은 목표 버튼 허용' `
  (Test-DgStageEnterTextMatches -EnterText '101층1구역진입' -Stage '1-1') $true
Assert-Case '던전 진입 게이트: 다른 구역 차단' `
  (Test-DgStageEnterTextMatches -EnterText '1층 2구역 진입' -Stage '1-1') $false
Assert-Case '던전 진입 게이트: 좁은 영역처럼 구역 숫자가 없으면 차단' `
  (Test-DgStageEnterTextMatches -EnterText '진입' -Stage '1-1') $false

$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '던전 진입 버튼 판독은 던전 전용 넓은 영역 사용' `
  ($workerSource -match 'function Get-DgStageEnterButtonText[\s\S]{0,900}\$rgDgEnterBtn\[0\]') $true
Assert-Case '던전 진입 3경로 모두 전용 SourceCondition 사용' `
  ([regex]::Matches($workerSource, 'SourceCondition\s*\{\s*Test-DgStageEnterButtonVisible').Count) 3
Assert-Case '실제 클릭 전의 오해 소지 진입 클릭 로그 제거' `
  ($workerSource.Contains('Write-RunLog "[던전] ${stageFloor}층 ${stageArea}구역 진입 클릭"')) $false
Assert-Case '던전 오류 진단도 전용 진입 버튼 영역 사용' `
  ($workerSource.Contains('$diagDetail = Get-DgStageEnterButtonText -Game $game')) $true
Assert-Case '같은 층은 옵션 화면 공용 전환기 사용' `
  ($workerSource -match "Action -eq 'same-floor'[\s\S]{0,1800}Set-DgOptionStage") $true
Assert-Case '다른 층은 옵션 화면에서 뒤로 복귀 후 재시도' `
  ($workerSource -match "Action -eq 'different-floor'[\s\S]{0,1800}Invoke-DgBackToSelection[\s\S]{0,600}continue") $true
Assert-Case '선택·복구 후 옵션 화면에서 목표 난이도 재확정' `
  ($workerSource -match "if \(-not \`$selectionReady\)[\s\S]{0,1200}Set-DgOptionDifficulty -Game \`$Game -Label \`$ndDifficulty") $true
Assert-Case '처음 연 옵션 화면도 같은 층이면 뒤로 가지 않고 구역 카드 전환' `
  ($workerSource -match "titleFloorVerdict -eq 'match'[\s\S]{0,1400}Set-DgOptionStage") $true
Assert-Case '커스텀도 같은 옵션 화면 전환기 사용' `
  ($workerSource -match "startAction -eq 'stay-select'[\s\S]{0,1800}Set-DgOptionStage") $true

$stageFloor = '1'; $stageArea = '3'

$cases = @(
  @{ T = '1층3구역';  E = '일치(진행)' }      # 정상 복귀 회차
  @{ T = '2층3구역';  E = '불일치(되돌림)' }  # 2026-07-18 실측 사고 케이스
  @{ T = '2증3구역';  E = '불일치(되돌림)' }  # 층 깨짐 + 다른 층
  @{ T = '1츰3구역';  E = '일치(진행)' }      # 층 깨짐 + 같은 스테이지
  @{ T = '23구역';    E = '불일치(되돌림)' }  # 층 소실 + 다른 층 ({0,2} 완화로 감지)
  @{ T = '13구역';    E = '일치(진행)' }      # 층 소실 + 같은 스테이지
  @{ T = '153구역';   E = '불일치(되돌림)' }  # 층이 숫자로 깨짐 - 되돌려도 재선택이라 무해
  @{ T = 'l층3구역';  E = '불명확(진행)' }    # 숫자 판독 불가
  @{ T = '';          E = '캡처실패(첫 판정 유지)' }
  @{ T = '글라스기브넨던전'; E = '옵션화면아님' }
)
foreach ($c in $cases) {
  $titleText = $c.T
  $onOptions = $titleText.Contains('구역')
  if (-not $onOptions) {
    $verdict = if ($titleText.Length -eq 0) { '캡처실패(첫 판정 유지)' } else { '옵션화면아님' }
  } elseif ($titleText -notmatch "${stageFloor}\D{1,2}${stageArea}구역") {
    if ($titleText -match "(\d)\D{0,2}(\d)구역") {
      if (($Matches[1] -eq $stageFloor) -and ($Matches[2] -eq $stageArea)) { $verdict = '일치(진행)' }
      else { $verdict = '불일치(되돌림)' }
    } else { $verdict = '불명확(진행)' }
  } else { $verdict = '일치(진행)' }
  if ($verdict -eq $c.E) { "OK  '{0}' -> {1}" -f $c.T, $verdict }
  else { "FAIL '{0}' -> {1} (기대 {2})" -f $c.T, $verdict, $c.E; $fails++ }
}

# 선택 화면 복귀 성공 판정 ('구역' 없고 '던전'/'오드' 있음)
$backCases = @(
  @{ T = '글라스기브넨던전'; E = $true }
  @{ T = '바리오드'; E = $true }
  @{ T = '1층3구역'; E = $false }
  @{ T = ''; E = $false }
)
foreach ($c in $backCases) {
  $t = $c.T
  $backOk = (-not $t.Contains('구역')) -and ($t.Contains('던전') -or $t.Contains('오드'))
  if ($backOk -eq $c.E) { "OK  복귀판정 '{0}' -> {1}" -f $c.T, $backOk }
  else { "FAIL 복귀판정 '{0}' -> {1} (기대 {2})" -f $c.T, $backOk, $c.E; $fails++ }
}
exit $fails
