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

# ── 3b. 무제한형 사망 (2026-08-11 타 PC 제보 + 사용자 전수 캡처) ─────────────
# 부활 제한이 **없는** 구역(심층던전·일반 던전 실측)에는 '남은 부활 횟수' 줄이 아예 없고
# '당신은 이 세계에서 죽지 않습니다 / 다만 지금은 움직일 수 없을 뿐입니다' 로 나옵니다.
# 기존 조각이 하나도 없어 Dead 로 안 잡혔고, 자동 부활이 통째로 죽어 클리어 대기 600초를
# 그대로 태운 뒤 회차가 실패했습니다(제보 03:23 입장 → 03:33 초과, 부활 시도 로그 0건).
# 아래는 **실측 판독 원문**입니다 (같은 ROI(500,160,290,120)·s3·ko).
$info = Get-DeathInfoFromText -Text '6H도-느당신은미세기ICⅡ서죽지않습니다.다만天l금은딥식일수없을뿐입니다.'
Assert-Case '무제한형: 실측 던전 00:09 (죽지+않습니다)' (Format-DeathInfo $info) 'True/null/False'
$info = Get-DeathInfoFromText -Text '6H도-느00百0당신은미세계에서죽지않습니다.다만치금은딥식일수없을뿐입니다.'
Assert-Case '무제한형: 실측 던전 00:13 (캠프파이어 버튼 화면)' (Format-DeathInfo $info) 'True/null/False'
# ★ 제보 캡처는 중앙 문구가 **통째로 깨져** 의미 조각이 하나도 안 남았습니다.
#   '행동불능'의 실측 깨짐 별칭 '6H도-느' 로만 잡힙니다 (7장 × 배율 2~6 공통).
$info = Get-DeathInfoFromText -Text "6H도-느「팀&크미국지뇨'亡LI다.다인치二'"
Assert-Case '무제한형: 실측 심층 03:33 (중앙 전파괴 - 별칭으로만 잡힘)' (Format-DeathInfo $info) 'True/null/False'
# 제한형 실측도 그대로 통과해야 합니다 (회귀 가드)
$info = Get-DeathInfoFromText -Text '6H도-느00百0부할제한구역입니다.남은부활횟수3/3'
Assert-Case '제한형: 실측 어비스 23:52 (개인 3/3)' (Format-DeathInfo $info) 'True/3/False'
$info = Get-DeathInfoFromText -Text '6H도~느00百0부활제한구역입니다.üEl의남은부활횟수4/6'
Assert-Case '제한형: 실측 어비스 23:58 (파티 4/6)' (Format-DeathInfo $info) 'True/4/False'
$info = Get-DeathInfoFromText -Text '전별하였百LI다01지막객프파이어에서부터재도전하人l겠습니까?재도전가능횟수가초기호}팀LI다.'
Assert-Case '전멸: 실측 00:06 (캠프파이어 버튼 화면)' (Format-DeathInfo $info) 'False/null/True'

# ★ 위 세 실측은 전부 '6H도-느' 로 시작해서 **별칭만으로도** 잡힙니다. 그래서 의미 조합을
#   지워도 통과합니다(2026-08-11 변이 검증에서 이 구멍이 드러남). 두 신호가 각각 제 몫을
#   하는지 보려면 **한쪽만 있는 입력**이 필요합니다.
#   '행동불능'이 다른 형태로 깨지거나 아예 안 읽히는 화면은 의미 조합만 남습니다.
$info = Get-DeathInfoFromText -Text '당신은이세계에서죽지않습니다.다만지금은움직일수없을뿐입니다.'
Assert-Case '무제한형: 별칭 없이 의미 조합만으로 잡힌다' (Format-DeathInfo $info) 'True/null/False'
$info = Get-DeathInfoFromText -Text '헤도느당신은이세계에서죽지않습니다.'
Assert-Case '무제한형: 별칭이 다르게 깨져도 죽지+않습니다로 잡힘' (Format-DeathInfo $info) 'True/null/False'
$info = Get-DeathInfoFromText -Text '다만지금은움직일수없을뿐입니다.'
Assert-Case '무제한형: 둘째 줄만 남아도 수없+뿐입니다로 잡힘' (Format-DeathInfo $info) 'True/null/False'
# 반대로 별칭만 남고 의미 문구가 통째로 깨진 경우(제보 03:33)도 잡혀야 합니다 - 위 3b 참고

# 음성: 낱말 하나만으로는 Dead 가 아니어야 합니다 (조합 요구 - 오탐 방어)
Assert-Case '음성: 죽지 단독' ([bool](Get-DeathInfoFromText -Text '죽지').Dead) $false
Assert-Case '음성: 않습니다 단독' ([bool](Get-DeathInfoFromText -Text '않습니다').Dead) $false
Assert-Case '음성: 수없 단독' ([bool](Get-DeathInfoFromText -Text '수없').Dead) $false
Assert-Case '음성: 뿐입니다 단독' ([bool](Get-DeathInfoFromText -Text '뿐입니다').Dead) $false
# 별칭을 짧게 줄이면 오탐 여지가 커집니다 - 정확한 형태만 인정 (리뷰 조건)
Assert-Case '음성: 별칭 축약형(6H도)은 비대상' ([bool](Get-DeathInfoFromText -Text '6H도').Dead) $false
Assert-Case '음성: 별칭 일부(도-느)는 비대상' ([bool](Get-DeathInfoFromText -Text '도-느').Dead) $false
# 버튼 어휘는 판정에 쓰지 않습니다 ('나가기'는 다른 화면 판정과 겹침 - 리뷰 지적)
foreach ($btnWord in @('도움요청그만두기', '나가기', '동행부르기', '성장가이드')) {
  Assert-Case "음성: 버튼 어휘 '$btnWord' 는 판정 근거가 아니다" `
    ([bool](Get-DeathInfoFromText -Text $btnWord).Dead) $false
}

# ── 4. 배선 가드 (워커 소스 - 전멸 분기 구조 유지 확인) ─────────────────────
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '배선: Wiped 를 Dead 보다 먼저 분기' `
  ($workerSource -match 'if \(\$death\.Wiped\) \{[\s\S]{100,3000}\} elseif \(\$death\.Dead\) \{') $true
# ★ 2026-08-11: 거점 부활 버튼은 화면에 따라 '여신상에서 부활' 또는 '캠프파이어에서 부활'
#   하나만 있습니다(실측 전멸 2장이 각각). '여신'만 찾으면 캠프파이어 화면에서 못 찾습니다.
#   손실 순서상 **캠프파이어가 여신상보다 유리**하므로(중간 세이브 vs 처음부터) 캠프 우선입니다.
Assert-Case '배선: 거점 부활 탐색이 공용 함수 경유' `
  ([bool]($workerSource -match 'function Find-ReviveAnchorPoint')) $true
$anchorBody = [string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
  -Names @('Find-ReviveAnchorPoint'))
$anchorCode = (($anchorBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 캠프파이어를 여신상보다 **먼저** 찾는다' `
  ([bool]($anchorCode -match "@\{ Text = '캠프'[^\r\n]*\}, @\{ Text = '여신'")) $true
Assert-Case "배선: 공통 조각 '부활'로 찾지 않는다(여기서 부활 오클릭 방지)" `
  ([bool]($anchorCode -match "SearchText '부활'")) $false
Assert-Case '배선: 전멸 분기가 공용 탐색을 쓴다' `
  ([bool]($workerSource -match '\$wipeAnchorHit = Find-ReviveAnchorPoint -Game \$Game')) $true
Assert-Case '배선: 개인 거점 부활도 공용 탐색을 쓴다' `
  ([bool]($workerSource -match '\$anchorHit = Find-ReviveAnchorPoint -Game \$Game')) $true
Assert-Case "배선: '여신' 단독 검색이 남아 있지 않다" `
  ([bool]($workerSource -match "-SearchText '여신'")) $false
Assert-Case '배선: 예비 좌표는 전멸 재확인 후에만' `
  ($workerSource -match '\$wipeRecheck = Get-DeathScreenInfo[\s\S]{0,200}if \(\$wipeRecheck\.Wiped\)') $true
Assert-Case '배선: 전멸 해제 시 미발견 누적 초기화' `
  ($workerSource -match 'if \(-not \$death\.Wiped\) \{ \$wipeButtonMisses = 0 \}') $true
Assert-Case '배선: 재도전 횟수는 기존 부활 상한 공유' `
  ($workerSource -match 'Wiped\)[\s\S]{0,300}\$reviveCount -ge \$reviveMaxPerCycle') $true
Assert-Case '배선: 전멸 예비 좌표 config 키' `
  ($workerSource -match "wipeStatueRevive'\) @\(986, 670\)") $true

exit $fails
