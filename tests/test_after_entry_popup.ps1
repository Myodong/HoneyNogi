# 입장 직후 키 입력 전 구매 팝업 사전 처리 - 소스 계약 (2026-07-28 실기: 물약 부족 입장 시
# 팝업이 먼저 떠 B(음식) 키가 먹히던 문제. 본체: mabinogi_run_once.ps1 Invoke-AfterEntryKeys)
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$functionText = @(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Invoke-AfterEntryKeys'))[0]

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# 팝업 사전 처리가 키 입력보다 먼저 있어야 함 (닫기 탐색 위치 < 첫 Press-KeyOnce 위치)
$popupSearchIndex = $functionText.IndexOf("-SearchText '닫기'")
$keyPressIndex = $functionText.IndexOf('Press-KeyOnce')
Assert-Case '계약: 닫기 탐색이 존재' ($popupSearchIndex -ge 0) $true
Assert-Case '계약: 키 입력이 존재' ($keyPressIndex -ge 0) $true
Assert-Case '계약: 닫기 탐색이 키 입력보다 먼저' ($popupSearchIndex -lt $keyPressIndex) $true

# 확인 최대 4회 = 닫기 최대 3회 + 마지막 재확인 (무팝업이면 OCR 1회 - Codex 합의 계약)
Assert-Case '계약: 확인 루프 상한 4회' ($functionText -match '\$popupTry -le 4') $true
Assert-Case '계약: 4회째는 클릭 없이 잔존 판정만' ($functionText -match '\$popupTry -ge 4[\s\S]{0,80}break') $true

# 캡처 실패 중에는 사전 처리를 건너뛰고 키 입력 (실패를 팝업 잔존으로 오인 금지 - Codex 지적)
Assert-Case '계약: 캡처 실패 가드' ($functionText -match 'if \(-not \$script:screenCaptureFailing\)') $true

# 키 입력 루프는 1개 그대로 (재입력 금지 - B 이중 입력은 음식 중복 소모 위험)
Assert-Case '계약: Press-KeyOnce 는 1곳뿐' ([regex]::Matches($functionText, 'Press-KeyOnce').Count) 1
Assert-Case '계약: 잔존 시 경고 후 진행' ($functionText -match '\[경고\] 구매 팝업이 닫히지 않습니다') $true

exit $fails
