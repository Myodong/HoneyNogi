# 심층던전 진리표 (2026-07-28 - 던전과 동일 흐름, 재화만 마족공물/어려움 고정 + 주간 매우 어려움)
# 본체: mabinogi_run_once.ps1 Get-DgMapLabelText / Get-CustomCoinDecision(파라미터화) /
#       mabinogi_gui.ps1 Get-DeepStageInternal / Get-DeepStageDisplay / Get-DcrCellEditPlan /
#       Set-DcrItemCellValue / Get-DeepTributeTotalPerLap / Get-DeepCustomListCompact /
#       Get-DeepCustomItemLabel / Get-CustomTransitionIssues(심층 재사용)
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-DgMapLabelText', 'Get-CustomCoinDecision')) {
  Invoke-Expression $definition
}
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Get-DeepStageInternal', 'Get-DeepStageDisplay', 'Get-DcrCellEditPlan',
             'Set-DcrItemCellValue', 'Get-DeepTributeTotalPerLap', 'Get-DeepCustomListCompact',
             'Get-DeepCustomItemLabel', 'Get-CustomTransitionIssues')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 1. 워커 지도 라벨 정규화 (Get-DgMapLabelText - $deepMode 스크립트 변수 참조) ──
$deepMode = $false
Assert-Case '라벨(던전): D 접두는 건드리지 않음' (Get-DgMapLabelText -Text 'D1-2') 'D1-2'
Assert-Case '라벨(던전): 일반 표기 그대로' (Get-DgMapLabelText -Text '1-2') '1-2'
$deepMode = $true
Assert-Case '라벨(심층): D1-1 → 1-1' (Get-DgMapLabelText -Text 'D1-1') '1-1'
Assert-Case '라벨(심층): D2-3 → 2-3' (Get-DgMapLabelText -Text 'D2-3') '2-3'
Assert-Case '라벨(심층): 공백 trim 후 정규화' (Get-DgMapLabelText -Text ' D1-1 ') '1-1'
Assert-Case '라벨(심층): DI-3 오독(대문자 I) → 1-3' (Get-DgMapLabelText -Text 'DI-3') '1-3'
Assert-Case '라벨(심층): 02-3 오독(D→0, 실측) → 2-3' (Get-DgMapLabelText -Text '02-3') '2-3'
Assert-Case '라벨(심층): 01-2 오독 → 1-2' (Get-DgMapLabelText -Text '01-2') '1-2'
Assert-Case '라벨(심층): 화이트리스트 밖(D3-1)은 그대로' (Get-DgMapLabelText -Text 'D3-1') 'D3-1'
Assert-Case '라벨(심층): 소문자 di-3 은 관용 없음(대소문자 구분)' (Get-DgMapLabelText -Text 'di-3') 'di-3'
Assert-Case '라벨(심층): D 없는 원문은 그대로' (Get-DgMapLabelText -Text '2-3') '2-3'
$deepMode = $false

# ── 2. 워커 공물 소진 판정 (Get-CustomCoinDecision 심층 파라미터화 - 어려움 1개) ──
$decision = Get-CustomCoinDecision -UseCoin $false -DoubleLoot $false -Balance 0 -ExhaustContinue $false -NoDoubleSweep $false `
  -SweepCost 1 -FullCost 1 -CurrencyName '마족공물'
Assert-Case '공물: 미사용이면 잔량 무관 진행' $decision.Action 'proceed'
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $false -Balance $null -ExhaustContinue $false -NoDoubleSweep $false `
  -SweepCost 1 -FullCost 1 -CurrencyName '마족공물'
Assert-Case '공물: 잔량 판독 실패는 검사 생략 진행' "$($decision.Action)/$([bool]$decision.Coin)" 'proceed/True'
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $false -Balance 2 -ExhaustContinue $false -NoDoubleSweep $false `
  -SweepCost 1 -FullCost 1 -CurrencyName '마족공물'
Assert-Case '공물: 잔량 2 >= 소탕 1 진행' "$($decision.Action)/$([bool]$decision.Coin)" 'proceed/True'
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $false -Balance 1 -ExhaustContinue $false -NoDoubleSweep $false `
  -SweepCost 1 -FullCost 1 -CurrencyName '마족공물'
Assert-Case '공물: 잔량 1 = 소탕 1 경계 진행' "$($decision.Action)/$([bool]$decision.Coin)" 'proceed/True'
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $false -Balance 0 -ExhaustContinue $true -NoDoubleSweep $false `
  -SweepCost 1 -FullCost 1 -CurrencyName '마족공물'
Assert-Case '공물: 잔량 0 + 미사용 진행 설정 → 소탕 해제 진행' "$($decision.Action)/$([bool]$decision.Coin)" 'proceed/False'
Assert-Case '공물: 진행 사유 문구에 마족공물 표기' ($decision.Reason -like '*마족공물*') $true
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $false -Balance 0 -ExhaustContinue $false -NoDoubleSweep $false `
  -SweepCost 1 -FullCost 1 -CurrencyName '마족공물'
Assert-Case '공물: 잔량 0 + 멈춤 설정 → 정지' $decision.Action 'stop'
Assert-Case '공물: 정지 사유에 필요 1개 표기' ($decision.Reason -like '*필요 1개*') $true
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $false -Balance 0 -ExhaustContinue $false -NoDoubleSweep $false `
  -SweepCost 1 -FullCost 1 -CurrencyName '마족공물' -ExhaustLabel '공물 소진 시'
Assert-Case '공물: 심층 사유 라벨은 공물 소진 시' ($decision.Reason -like "*'공물 소진 시' 설정*") $true
# 주간 매우 어려움(일반 반복 전용)은 소탕 2개
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $false -Balance 1 -ExhaustContinue $false -NoDoubleSweep $false `
  -SweepCost 2 -FullCost 2 -CurrencyName '마족공물'
Assert-Case '공물(매우): 잔량 1 < 소탕 2 → 정지' $decision.Action 'stop'
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $false -Balance 2 -ExhaustContinue $false -NoDoubleSweep $false `
  -SweepCost 2 -FullCost 2 -CurrencyName '마족공물'
Assert-Case '공물(매우): 잔량 2 = 소탕 2 경계 진행' $decision.Action 'proceed'
# 던전 기본값 회귀 가드: 파라미터를 안 주면 기존 10/20 은동전 판정 그대로
$decision = Get-CustomCoinDecision -UseCoin $true -DoubleLoot $true -Balance 15 -ExhaustContinue $false -NoDoubleSweep $true
Assert-Case '회귀(던전): 기본 파라미터 잔량 15 더블 불가 → 소탕만 진행' "$($decision.Action)/$([bool]$decision.Coin)/$([bool]$decision.Loot)" 'proceed/True/False'
Assert-Case '회귀(던전): 기본 사유 문구는 은동전 표기' ($decision.Reason -like '*은동전*') $true

# ── 3. GUI 구역 표기 변환 (D 표시 ↔ 내부 '1-1') ─────────────────────────────
Assert-Case '변환: D1-1 → 1-1' (Get-DeepStageInternal -Display 'D1-1') '1-1'
Assert-Case '변환: D2-3 → 2-3' (Get-DeepStageInternal -Display 'D2-3') '2-3'
Assert-Case '변환: 범위 밖 D3-1 은 빈 값' (Get-DeepStageInternal -Display 'D3-1') ''
Assert-Case '변환: D 없는 1-1 은 빈 값' (Get-DeepStageInternal -Display '1-1') ''
Assert-Case '변환: 빈 문자열은 빈 값' (Get-DeepStageInternal -Display '') ''
Assert-Case '표시: 1-1 → D1-1' (Get-DeepStageDisplay -Stage '1-1') 'D1-1'
Assert-Case '표시: 2-3 → D2-3' (Get-DeepStageDisplay -Stage '2-3') 'D2-3'
Assert-Case '표시: 형식 밖 값은 그대로(방어적)' (Get-DeepStageDisplay -Stage '3-9') '3-9'

# ── 4. 심층 셀 편집 계획 (Get-DcrCellEditPlan) ──────────────────────────────
$dcrTribute = [pscustomobject]@{ difficulty = '어려움'; stage = '1-2'; coin = $true; doubleLoot = $false; exhaustContinue = $true; noDoubleSweep = $false }
$dcrFree = [pscustomobject]@{ difficulty = '어려움'; stage = '2-1'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
$plan = Get-DcrCellEditPlan -ColumnIndex 2 -Item $dcrTribute
Assert-Case '심층 셀: 구역 열 옵션 6개' (@($plan.Options).Count) 6
Assert-Case '심층 셀: 구역 현재값 D 표기' $plan.Current 'D1-2'
$plan = Get-DcrCellEditPlan -ColumnIndex 3 -Item $dcrTribute
Assert-Case '심층 셀: 공물 열 옵션 2개(0개/1개)' (@($plan.Options) -join ',') '0개,1개'
Assert-Case '심층 셀: 공물 현재값 1개' $plan.Current '1개'
Assert-Case '심층 셀: 공물 현재값 0개' ((Get-DcrCellEditPlan -ColumnIndex 3 -Item $dcrFree).Current) '0개'
Assert-Case '심층 셀: 소진 열 - 공물 미사용이면 편집 불가' ($null -eq (Get-DcrCellEditPlan -ColumnIndex 4 -Item $dcrFree)) $true
Assert-Case '심층 셀: 소진 열 현재값 진행' ((Get-DcrCellEditPlan -ColumnIndex 4 -Item $dcrTribute).Current) '진행'
Assert-Case '심층 셀: 체크 열은 편집 불가' ($null -eq (Get-DcrCellEditPlan -ColumnIndex 0 -Item $dcrTribute)) $true
Assert-Case '심층 셀: # 열은 편집 불가' ($null -eq (Get-DcrCellEditPlan -ColumnIndex 1 -Item $dcrTribute)) $true

# ── 5. 심층 셀 값 적용 + 정규화 (Set-DcrItemCellValue) ──────────────────────
$after = Set-DcrItemCellValue -Item $dcrTribute -ColumnIndex 2 -Value 'D2-1'
Assert-Case '심층 적용: 구역 D2-1 → 내부 2-1, 나머지 유지' "$($after.stage)/$([bool]$after.coin)/$([bool]$after.exhaustContinue)" '2-1/True/True'
$after = Set-DcrItemCellValue -Item $dcrTribute -ColumnIndex 2 -Value '???'
Assert-Case '심층 적용: 형식 밖 구역 값은 기존 유지' $after.stage '1-2'
$after = Set-DcrItemCellValue -Item $dcrTribute -ColumnIndex 3 -Value '0개'
Assert-Case '심층 적용: 공물 해제 시 소진 대응도 false 정규화' "$([bool]$after.coin)/$([bool]$after.exhaustContinue)" 'False/False'
$after = Set-DcrItemCellValue -Item $dcrFree -ColumnIndex 3 -Value '1개'
Assert-Case '심층 적용: 공물 켜기(소진 대응은 기존 false 유지)' "$([bool]$after.coin)/$([bool]$after.exhaustContinue)" 'True/False'
$after = Set-DcrItemCellValue -Item $dcrTribute -ColumnIndex 4 -Value '멈춤'
Assert-Case '심층 적용: 진행→멈춤' ([bool]$after.exhaustContinue) $false
$after = Set-DcrItemCellValue -Item $dcrTribute -ColumnIndex 2 -Value 'D1-3'
Assert-Case '심층 적용: 고정 필드 유지(어려움/더블 false/소탕만 false)' `
  "$($after.difficulty)/$([bool]$after.doubleLoot)/$([bool]$after.noDoubleSweep)" '어려움/False/False'

# ── 6. 공물 합계/압축 표기/라벨 ─────────────────────────────────────────────
$deepItems = @(
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-1'; coin = $true; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-2'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
  [pscustomobject]@{ difficulty = '어려움'; stage = '2-3'; coin = $true; doubleLoot = $false; exhaustContinue = $true; noDoubleSweep = $false }
)
Assert-Case '합계: 공물 항목 2개 = 바퀴당 2개' (Get-DeepTributeTotalPerLap -Items $deepItems) 2
Assert-Case '합계: 빈 리스트 0개' (Get-DeepTributeTotalPerLap -Items @()) 0
Assert-Case '압축: D표기 + (소모량,대응)' (Get-DeepCustomListCompact -Items $deepItems) '1.D1-1(1,멈) 2.D1-2(0) 3.D2-3(1,진)'
Assert-Case '라벨: 공물 항목' (Get-DeepCustomItemLabel -Item $deepItems[0]) 'D1-1 (마족공물)'
Assert-Case '라벨: 무료 항목' (Get-DeepCustomItemLabel -Item $deepItems[1]) 'D1-2'

# ── 7. 층 전환 게이트 재사용 (심층도 같은 1층/2층 구조 - 내부 표기로 판정) ────
$deepUp = @(
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-3'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
  [pscustomobject]@{ difficulty = '어려움'; stage = '2-1'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
)
Assert-Case '전환: 심층 1-3→2-1 허용 (1바퀴)' (@(Get-CustomTransitionIssues -Items $deepUp -ListRepeat 'count' -ListRepeatCount 1).Count) 0
$deepDown = @(
  [pscustomobject]@{ difficulty = '어려움'; stage = '2-1'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-1'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
)
Assert-Case '전환: 심층 2-1→1-1 하향 금지' (@(Get-CustomTransitionIssues -Items $deepDown -ListRepeat 'count' -ListRepeatCount 1).Count) 1
$deepBadUp = @(
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-1'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
  [pscustomobject]@{ difficulty = '어려움'; stage = '2-2'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }
)
Assert-Case '전환: 심층 1-1→2-2 상향은 1-3에서만 가능 → 위반' (@(Get-CustomTransitionIssues -Items $deepBadUp -ListRepeat 'count' -ListRepeatCount 1).Count) 1
Assert-Case '전환: 심층 1-3→2-1 무한 반복은 바퀴 순환(2층→1-3) 위반' (@(Get-CustomTransitionIssues -Items $deepUp -ListRepeat 'infinite' -ListRepeatCount 1).Count) 1

# ── 8. 배선 가드 (소스 텍스트 검사 - GUI 심층 분기가 유지되는지) ─────────────
$guiSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_gui.ps1') -Raw -Encoding UTF8
Assert-Case '배선: 심층 카테고리 저장값 deepdungeon' ($guiSource -match "rbCatDeep\.Checked\)\s*\{\s*\`$categoryValue = 'deepdungeon'") $true
Assert-Case '배선: 커스텀 섹션 3분기(deepCustomRepeat)' ($guiSource -match "rbCatDeep\.Checked\)\s*\{\s*'deepCustomRepeat'") $true
Assert-Case '배선: 심층 전용 마커 파일 분기' ($guiSource -match 'rbCatDeep\.Checked\)\s*\{\s*\$customDeepMarkerFile') $true
Assert-Case '배선: 셀 편집 디스패처에 심층 리스트 분기' ($guiSource -match 'elseif \(\$clickSender -eq \$lvDcrList\)') $true
Assert-Case '배선: 셀 편집 적용에 심층 분기' ($guiSource -match 'elseif \(\$applyList -eq \$lvDcrList\)') $true
Assert-Case '배선: 시작 게이트 층 전환 검사에 deepCustomRepeat 포함' ($guiSource -match "-eq 'customRepeat' -or \`$script:customConfigSection -eq 'deepCustomRepeat'") $true
Assert-Case '배선: 마이그레이션 섹션 목록에 deepDungeon/deepCustomRepeat' `
  (($guiSource -match "'deepDungeon',") -and ($guiSource -match "'deepCustomRepeat'\)\)")) $true
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '배선(워커): 심층 커스텀 강제 규칙(어려움 고정)' ($workerSource -match "if \(\`$deepMode\) \{[\s\S]{0,400}\`$ndDifficulty = '어려움'") $true
Assert-Case '배선(워커): 심층 재화 테이블 치환(1/2개)' ($workerSource -match '\$dgValidCosts = @\(1, 2\)') $true

exit $fails
