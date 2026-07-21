# 비커스텀 던전의 소진 대응이 커스텀과 같은 공용 판정/라디오 계약을 쓰는지 검사합니다.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
$guiPath = Join-Path $root 'mabinogi_gui.ps1'
Invoke-Expression (Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-CustomCoinDecision'))

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
function Check-Pattern {
  param([string]$Name, [string]$Text, [string]$Pattern)
  if ($Text -match $Pattern) { "OK   $Name" }
  else { "FAIL $Name"; $script:fails++ }
}
function Describe-Decision {
  param($Decision)
  return ('{0}/{1}/{2}' -f $Decision.Action, $Decision.Coin, $Decision.Loot)
}

# 두 설정은 서로의 범위를 침범하지 않습니다: <10은 소진 설정, 10~19는 더블 불가 설정.
Check-Equal '잔량9 + 소진 진행 + 더블 불가 멈춤 → 미사용 진행' `
  (Describe-Decision (Get-CustomCoinDecision $true $true 9 $true $false)) 'proceed/False/False'
Check-Equal '잔량9 + 소진 멈춤 + 더블 불가 소탕 → 멈춤' `
  (Describe-Decision (Get-CustomCoinDecision $true $true 9 $false $true)) 'stop/False/False'
Check-Equal '잔량15 + 더블 불가 멈춤 → 멈춤' `
  (Describe-Decision (Get-CustomCoinDecision $true $true 15 $true $false)) 'stop/True/False'
Check-Equal '잔량15 + 더블 불가 소탕 → 소탕만 진행' `
  (Describe-Decision (Get-CustomCoinDecision $true $true 15 $false $true)) 'proceed/True/False'

$worker = Get-Content -LiteralPath $workerPath -Raw -Encoding UTF8
$gui = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
Check-Pattern '비커스텀도 공용 판정에 저장값 전달' $worker `
  'Get-CustomCoinDecision\s+-UseCoin\s+\$ndUseCoin[\s\S]{0,180}-ExhaustContinue\s+\$ndCoinFallback\s+-NoDoubleSweep\s+\$ndLootFallback'
Check-Pattern '비커스텀 동전 소진 라디오 문구' $gui `
  '\$lblNdExhaust\.Text\s*=\s*''동전 소진 시\(잔량 10 미만\):'''
Check-Pattern '비커스텀 더블 불가 라디오 문구' $gui `
  '\$lblNdNoDouble\.Text\s*=\s*''더블 루팅 불가 시\(잔량 10~19\):'''
Check-Pattern '동전 소진 진행 라디오를 기존 config 키로 저장' $gui `
  'continueWithoutCoin\s*=\s*\[bool\]\(\$chkNdCoin\.Checked\s+-and\s+\$rbNdExhaustGo\.Checked\)'
Check-Pattern '더블 불가 소탕 라디오를 기존 config 키로 저장' $gui `
  'continueSweepOnly\s*=\s*\[bool\]\(\$chkNdCoin\.Checked\s+-and\s+\$chkNdDoubleLoot\.Checked\s+-and\s+\$rbNdNoDoubleSweep\.Checked\)'
Check-Pattern '두 대응 줄 표시 시 상세 그룹 높이 확장' $gui `
  '\$ndNoDoubleRowOn[\s\S]{0,120}\$pnlNdParty\.Top\s*=\s*174[\s\S]{0,80}\$grpContentDetail\.Height\s*=\s*208'
Check-Pattern '권장 창 모드 버튼 폭 108' $gui `
  '\$btnRecommendedWindow\.Size\s*=\s*New-Object System\.Drawing\.Size\(108, 30\)'
Check-Pattern '적용된 설정 버튼 폭 108' $gui `
  '\$btnAlwaysOn\.Size\s*=\s*New-Object System\.Drawing\.Size\(108, 30\)'
Check-Pattern '진행 초기화 버튼 폭 94(리스트 버튼과 동일)' $gui `
  '\$btnCrReset\.Size\s*=\s*New-Object System\.Drawing\.Size\(94, 26\)'
Check-Pattern '리스트 버튼과 진행 초기화 버튼 폭 동일' $gui `
  '\$btnCrAdd\.Size\s*=\s*New-Object System\.Drawing\.Size\(94, 30\)[\s\S]{0,9000}\$btnCrReset\.Size\s*=\s*New-Object System\.Drawing\.Size\(94, 26\)'
Check-Pattern '커스텀 반복 중 사냥터 선택 비활성화' $gui `
  '\$isCustom\s*=\s*\$supportsCustom\s+-and\s+\$rbCustomRepeat\.Checked[\s\S]{0,500}\$rbCatHunting\.Enabled\s*=\s*-not\s+\$isCustom'
Check-Pattern '커스텀 반복 중 사냥터 미지원 문구 표시' $gui `
  '\$rbCatHunting\.Text\s*=\s*\$\(if\s*\(\$isCustom\)\s*\{\s*''사냥터\(미지원\)''\s*\}\s*else\s*\{\s*''사냥터''\s*\}\)'

exit $fails
