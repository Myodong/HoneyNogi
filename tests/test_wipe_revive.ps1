# 파티 전멸('전멸하였습니다') 자동 재도전 진리표 (2026-07-28 실기 오류 기반)
# 본체: mabinogi_run_once.ps1 Get-DeathInfoFromText (Get-DeathScreenInfo 의 순수 판정부)
# 근거 캡처: error_20260728_h03m27s19.png - 어비스 매우 어려움 파티 전멸 화면.
# 실측 판독(동일 영역·배율 재현): 중앙 '전별하였습LI다 … 재도전하시겠습니)가? …',
# 우하단 '여신상에서'(986,670). 클릭은 워커가 '여신' 버튼을 실제로 찾은 뒤에만 수행.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-DeathInfoFromText')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Format-DeathInfo {
  param($Info)
  $remainingText = if ($null -eq $Info.Remaining) { 'null' } else { [string]$Info.Remaining }
  return ('{0}/{1}/{2}' -f [bool]$Info.Dead, $remainingText, [bool]$Info.Wiped)
}

# ── 1. 전멸 화면 (Wiped) - 실측 깨짐 포함 ───────────────────────────────────
$info = Get-DeathInfoFromText -Text '전별하였습LI다 마지막 객프가이어이1서부Ed 재도전하시겠습니)가? 재도전 부함 가능 횟수가 초기한됩니다.'
Assert-Case '전멸: 2026-07-28 실측 전문(전멸→전별 깨짐)' (Format-DeathInfo $info) 'False/null/True'
$info = Get-DeathInfoFromText -Text '전멸하였습니다 마지막 캠프파이어에서부터 재도전하시겠습니까? 재도전 시 부활 가능 횟수가 초기화됩니다.'
Assert-Case '전멸: 온전 판독' (Format-DeathInfo $info) 'False/null/True'
Assert-Case '전멸: 전멸하 조각 단독' ([bool](Get-DeathInfoFromText -Text '전멸하').Wiped) $true
Assert-Case '전멸: 전별하 오독 조각 단독' ([bool](Get-DeathInfoFromText -Text '전별하였').Wiped) $true
Assert-Case '전멸: 재도전하 조각 (질문 문구)' ([bool](Get-DeathInfoFromText -Text '재도전하시겠습니까?').Wiped) $true
Assert-Case '전멸: 공백 섞인 판독도 정규화 후 매칭' ([bool](Get-DeathInfoFromText -Text '재도전 하시겠습니까').Wiped) $true

# ── 2. Wiped 음성 케이스 (오탐 방어 - 리뷰 지적: 클리어 점수표의 '재도전 보너스') ──
$info = Get-DeathInfoFromText -Text '처치완벽한전주권장전투력재도전보너스협동보너스11050201010'
Assert-Case '음성: 클리어 점수표 실측(타 PC) - 재도전 보너스는 비대상' (Format-DeathInfo $info) 'False/null/False'
$info = Get-DeathInfoFromText -Text '처치완벽한전루재도전보너스협동보너스110501010'
Assert-Case '음성: 클리어 점수표 실측(User) - 재도전 보너스는 비대상' (Format-DeathInfo $info) 'False/null/False'
Assert-Case '음성: 재도전 단독(하 없음)은 비대상' ([bool](Get-DeathInfoFromText -Text '재도전').Wiped) $false
Assert-Case '음성: 클리어 문구' ([bool](Get-DeathInfoFromText -Text '화면을 터치해 주세요').Wiped) $false
Assert-Case '음성: 빈 문자열' (Format-DeathInfo (Get-DeathInfoFromText -Text '')) 'False/null/False'
Assert-Case '음성: 부활 가능 횟수 초기화 문구만으로는 Dead 아님(부활[가능]횟수)' `
  ([bool](Get-DeathInfoFromText -Text '재도전 시 부활 가능 횟수가 초기화됩니다').Dead) $false

# ── 3. 개인 행동불능 (Dead - 기존 규칙 회귀 가드) ───────────────────────────
$info = Get-DeathInfoFromText -Text '남은 부활 횟수 3/3'
Assert-Case '행동불능: 남은 부활 횟수 3/3' (Format-DeathInfo $info) 'True/3/False'
$info = Get-DeathInfoFromText -Text '행동불능 부활 제한 구역입니다 남은 부활 횟수 0/6'
Assert-Case '행동불능: 남은 횟수 0 (여신상 전환 조건)' (Format-DeathInfo $info) 'True/0/False'
$info = Get-DeathInfoFromText -Text '남은 부활'
Assert-Case '행동불능: 숫자 소실 시 Remaining null' (Format-DeathInfo $info) 'True/null/False'
Assert-Case '행동불능: 부활횟수 조각' ([bool](Get-DeathInfoFromText -Text '부활횟수 2/6').Dead) $true

# ── 4. 배선 가드 (워커 소스 - 전멸 분기 구조 유지 확인) ─────────────────────
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '배선: Wiped 를 Dead 보다 먼저 분기' `
  ($workerSource -match 'if \(\$death\.Wiped\) \{[\s\S]{100,3000}\} elseif \(\$death\.Dead\) \{') $true
Assert-Case '배선: 클릭 전 여신 버튼 이중 확인' `
  ($workerSource -match '\$wipeStatuePoint = Find-GameTextPoint[\s\S]{0,200}-SearchText ''여신''') $true
Assert-Case '배선: 예비 좌표는 전멸 재확인 후에만' `
  ($workerSource -match '\$wipeRecheck = Get-DeathScreenInfo[\s\S]{0,200}if \(\$wipeRecheck\.Wiped\)') $true
Assert-Case '배선: 전멸 해제 시 미발견 누적 초기화' `
  ($workerSource -match 'if \(-not \$death\.Wiped\) \{ \$wipeButtonMisses = 0 \}') $true
Assert-Case '배선: 재도전 횟수는 기존 부활 상한 공유' `
  ($workerSource -match 'Wiped\)[\s\S]{0,300}\$reviveCount -ge \$reviveMaxPerCycle') $true
Assert-Case '배선: 전멸 예비 좌표 config 키' `
  ($workerSource -match "wipeStatueRevive'\) @\(986, 670\)") $true

exit $fails
