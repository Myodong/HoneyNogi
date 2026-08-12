# 심층던전 진리표 (2026-07-28 - 던전과 동일 흐름, 재화만 마족공물/어려움 고정 + 주간 매우 어려움)
# 본체: mabinogi_run_once.ps1 Get-DgMapLabelText / Get-CustomCoinDecision(파라미터화) /
#       mabinogi_gui.ps1 Get-DeepStageInternal / Get-DeepStageDisplay / Get-DcrCellEditPlan /
#       Set-DcrItemCellValue / Get-DeepTributeTotalPerLap / Get-DeepCustomListCompact /
#       Get-DeepCustomItemLabel / Get-CustomTransitionIssues(심층 재사용)
$ErrorActionPreference = 'Stop'
# ★ 10차 추가: 심층 전용 소모량 영역과 **예비 영역**의 계약.
#   좁은 영역(978,636,152,44)은 아이콘 오독('7' 접두)을 막으려 만든 것이고, 넓은 예비
#   (840,636,290,44)는 하단 버튼이 '파티 찾기'+'입장하기' 2버튼일 때 숫자가 좌우로 밀리는
#   레이아웃을 덮습니다. 9차에 사다리를 넣었는데 테스트가 없어 지워도 통과했습니다.
$ddRoot = Split-Path -Parent $PSScriptRoot
$ddWorker = [IO.File]::ReadAllText((Join-Path $ddRoot 'mabinogi_run_once.ps1'))
$ddFails = 0
foreach ($ddCase in @(
    @{ N = '심층: 전용 소모량 영역(아이콘 제외)'; P = '\$rgDgTributeCost = @\(978, 636, 152, 44\)' },
    @{ N = '심층: 전용 잔량 영역'; P = '\$rgDgCoinBalance = @\(1056, 45, 64, 44\)' },
    @{ N = '심층: 두 버튼 레이아웃용 예비 영역'; P = '\$rgDgTributeCostAlt = @\(840, 636, 290, 44\)' },
    @{ N = '심층: 예비는 심층에서만(기본은 null)'; P = '\$rgDgTributeCostAlt = \$null' },
    @{ N = '판독: 주 → 예비 사다리를 실제로 순회'; P = 'foreach \(\$costRegion in \$costRegions\)' },
    @{ N = '판독: 예비가 있을 때만 목록에 추가'; P = 'if \(\$rgDgTributeCostAlt\) \{ \$costRegions \+= , \$rgDgTributeCostAlt \}' })) {
  if ($ddWorker -match $ddCase.P) { "OK   $($ddCase.N)" } else { "FAIL $($ddCase.N)"; $ddFails++ }
}
# 심층 전용 값은 넓은 기본 대입 **뒤에** 와야 합니다 (앞에 두면 통째로 덮여 죽습니다 - 8차 사고)
if ($ddWorker.IndexOf('$rgDgTributeCost = @(978, 636, 152, 44)') -gt
    $ddWorker.IndexOf("Get-ConfigValue `$config @('ocrRegions', 'dgTributeCost')")) {
  "OK   심층: 전용 영역이 기본 대입보다 뒤(덮임 방지)"
} else { "FAIL 심층: 전용 영역이 기본 대입에 덮입니다"; $ddFails++ }
if ($ddFails -gt 0) { exit $ddFails }
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-DgMapLabelText', 'Get-CustomCoinDecision', 'Select-DgTabWord', 'Test-DgTabProbeMatchesMode')) {
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

# ── 7.5 던전|심층 던전 탭 자동 전환 (2026-07-28 사용자 요청 - 실측 단어 기반) ──
$tabWordsMeasured = @(
  [pscustomobject]@{ Text = '던전'; X = 66; Y = 128 }
  [pscustomobject]@{ Text = '심층'; X = 135; Y = 128 }
  [pscustomobject]@{ Text = '던전'; X = 172; Y = 128 }
)
$tabPick = Select-DgTabWord -Words $tabWordsMeasured -DeepTab $true
Assert-Case '탭: 심층 던전 탭 = 심층 단어(135,128)' "$($tabPick.X),$($tabPick.Y)" '135,128'
$tabPick = Select-DgTabWord -Words $tabWordsMeasured -DeepTab $false
Assert-Case '탭: 던전 탭 = 심층 짝 아닌 던전(66,128)' "$($tabPick.X),$($tabPick.Y)" '66,128'
$tabWordsMisread = @(
  [pscustomobject]@{ Text = '던전'; X = 66; Y = 128 }
  [pscustomobject]@{ Text = '심충'; X = 135; Y = 128 }
  [pscustomobject]@{ Text = '던전'; X = 172; Y = 128 }
)
$tabPick = Select-DgTabWord -Words $tabWordsMisread -DeepTab $true
Assert-Case '탭: 심충 오독도 심층 탭으로 인정' "$($tabPick.X),$($tabPick.Y)" '135,128'
$tabPick = Select-DgTabWord -Words $tabWordsMisread -DeepTab $false
Assert-Case '탭: 오독 세트에서도 던전 탭은 66,128' "$($tabPick.X),$($tabPick.Y)" '66,128'
$tabWordsNoDeep = @([pscustomobject]@{ Text = '던전'; X = 66; Y = 128 })
Assert-Case '탭: 심층 단어 없으면 심층 탭 null(예비 좌표행)' ($null -eq (Select-DgTabWord -Words $tabWordsNoDeep -DeepTab $true)) $true
Assert-Case '탭: 빈 목록 null' ($null -eq (Select-DgTabWord -Words @() -DeepTab $false)) $true

Assert-Case '탭 확인: 심층 진입 버튼 + deep 목표 = 일치' (Test-DgTabProbeMatchesMode -ProbeText 'Space심층2층3구역진입' -DeepTab $true) $true
Assert-Case '탭 확인: 심층 진입 버튼 + 던전 목표 = 불일치' (Test-DgTabProbeMatchesMode -ProbeText 'Space심층2층3구역진입' -DeepTab $false) $false
Assert-Case '탭 확인: 심충 오독 + deep 목표 = 일치' (Test-DgTabProbeMatchesMode -ProbeText 'Space심충1층1구역진입' -DeepTab $true) $true
Assert-Case '탭 확인: 일반 진입 버튼 + 던전 목표 = 일치' (Test-DgTabProbeMatchesMode -ProbeText '1층1구역진입' -DeepTab $false) $true
Assert-Case '탭 확인: 일반 진입 버튼 + deep 목표 = 불일치' (Test-DgTabProbeMatchesMode -ProbeText '1층1구역진입' -DeepTab $true) $false
Assert-Case '탭 확인: 빈 판독은 어느 쪽도 성공 아님' `
  ((Test-DgTabProbeMatchesMode -ProbeText '' -DeepTab $false) -or (Test-DgTabProbeMatchesMode -ProbeText '' -DeepTab $true)) $false
Assert-Case '탭 확인: 진입 소실 판독은 성공 아님' (Test-DgTabProbeMatchesMode -ProbeText 'Space심층2층3구역' -DeepTab $true) $false
# ── '심증' 오독 관용 (2026-08-13 00:33 실사고 - 1908 창): s5 복구 제목 '제고분심증2증1구역'의
#    '심증' 이 심[층충] 에 없어 심층 옵션 화면을 타 탭으로 오판 → '<' 없는 다시하기 옵션
#    화면에서 복귀 4회 실패 → 정지. '층'→'증' 깨짐은 '로다2증' 등 반복 실측 계열.
Assert-Case '탭 확인: 심증 오독 + deep 목표 = 일치 (08-13 실사고 계열)' `
  (Test-DgTabProbeMatchesMode -ProbeText 'Space심증2증1구역진입' -DeepTab $true) $true
Assert-Case '실측 제목의 심층 표식: 제고분심증2증1구역 -match 심[층충증]' `
  ([bool]('제고분심증2증1구역' -match '심[층충증]')) $true
$tabWordsSimJeung = @(
  @{ Text = '던전'; X = 66; Y = 128 }, @{ Text = '심증'; X = 135; Y = 128 }, @{ Text = '던전'; X = 172; Y = 128 })
Assert-Case '탭: 심증 오독 탭 단어 - 심층 선택은 135' ((Select-DgTabWord -Words $tabWordsSimJeung -DeepTab $true).X) 135
Assert-Case '탭: 심증 오독 탭 단어 - 던전 선택은 66 (심증 짝 172 제외)' ((Select-DgTabWord -Words $tabWordsSimJeung -DeepTab $false).X) 66
Assert-Case '탭: 심증+던전(짝)만 있으면 던전 선택 null (오클릭 방지)' `
  ($null -eq (Select-DgTabWord -Words @(@{ Text = '심증'; X = 135; Y = 128 }, @{ Text = '던전'; X = 172; Y = 128 }) -DeepTab $false)) $true
# 배선: 심층 표식 정규식이 워커 5곳 전부 '심[층충증]' 이고 구형 '심[층충]' 은 0곳
Assert-Case '배선(워커): 심층 표식 심[층충증] = 5곳' ([regex]::Matches($ddWorker, '심\[층충증\]').Count) 5
Assert-Case '배선(워커): 구형 심[층충] 잔존 0곳' ([regex]::Matches($ddWorker, '심\[층충\]').Count) 0

# ── '입장하기' 2차 신호 계약 (2026-08-12 23:55 + 08-13 00:51 실사고 ×2 - 제목이 화면
#    인스턴스 단위로 전 배율 사망하는 1908 창. 진입 버튼 영역은 두 사고 모두 'Space입장하기'
#    정확 판독 = 옵션 화면 전용 판별자. '진입'은 선택 화면 전용) ──
Assert-Case '배선(워커): 다시하기 복귀 대기 - 입장하기 1차 + 제목 구역 2차' `
  ($ddWorker -match "\`$backProbe\.Contains\('입장하기'\) -or \(Read-DgTitleText -Game \`$Game\)\.Contains\('구역'\)") $true
Assert-Case '배선(워커): 시작 probe 입장하기 → 옵션 확정 + 선택 오판 무효화' `
  ($ddWorker -match "(?s)if \(\`$selProbe\.Contains\('입장하기'\)\) \{\s*\r?\n\s*\`$optionsByProbe = \`$true\s*\r?\n\s*if \(\`$onSelectionScreen\) \{ \`$onSelectionScreen = \`$false \}") $true
Assert-Case '배선(워커): 복구 판정에 probe 옵션 전달 (복구 한정 수용)' `
  ($ddWorker -match '-OnOptionsScreen \(\$onOptionsScreen -or \$optionsByProbe\)') $true
Assert-Case '배선(워커): lastRun 필드 복구도 probe 옵션이면 차단' `
  ($ddWorker -match 'if \(\$script:dgLastRun -and -not \$onOptionsScreen -and -not \$optionsByProbe -and -not \$recoveryOnSelection\)') $true
# 선택→옵션 전환 대기 3곳 중 2곳만 probe 확장 (01:24 실사고 - 기본 진입 대기 초과):
# 다른층 오선택(3곳째)은 대기 직후 Invoke-DgBackToSelection 이 죽은 제목의 '고분' 오판으로
# '<' 없이 Ok=true 를 돌려주는 구멍이 있어 **일부러 제외** (교차 리뷰 반례 - 확장 금지 고정)
Assert-Case '배선(워커): 기본 진입 대기에 입장하기 probe' `
  ($ddWorker -match "(?s)-Description '던전 진입 옵션 화면'[\s\S]{0,700}Contains\('입장하기'\)") $true
Assert-Case '배선(워커): 같은층 오선택 대기에 입장하기 probe' `
  ($ddWorker -match "(?s)-Description '같은 층 오선택 구역의 진입 옵션 화면'[\s\S]{0,700}Contains\('입장하기'\)") $true
Assert-Case '배선(워커): 다른층 오선택 대기는 probe 미확장 (뒤로가기 오판 구멍 - 제목만)' `
  ($ddWorker -notmatch "(?s)-Description '다른 층 오선택 구역의 진입 옵션 화면'[\s\S]{0,900}Contains\('입장하기'\)") $true
Assert-Case '배선(워커): 복구의 선택 화면 인정에서 probe 옵션 제외 (고분 오판 차단)' `
  ($ddWorker -match '\$recoveryOnSelection = \(-not \$optionsByProbe\) -and') $true
Assert-Case '배선(워커): probe 옵션은 일반 회차에서 fail-closed 정지 (무증거 진행 금지)' `
  ($ddWorker -match '(?s)if \(\$optionsByProbe\) \{\s*\r?\n\s*Write-RunLog[^\r\n]*진입 옵션 화면으로 확인되지만[\s\S]{0,220}exit 4') $true
# (죽은 제목 '메카고분0°°=='가 선택 화면으로 오판되는 실측 근거 케이스는
#  test_dg_layout_system.ps1 의 선택 화면 진리표에 있음 - probe 무효화의 존재 이유)

# ── 8. 배선 가드 (소스 텍스트 검사 - GUI 심층 분기가 유지되는지) ─────────────
$guiSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_gui.ps1') -Raw -Encoding UTF8
Assert-Case '배선: 심층 카테고리 저장값 deepdungeon' ($guiSource -match "rbCatDeep\.Checked\)\s*\{\s*\`$categoryValue = 'deepdungeon'") $true
Assert-Case '배선: 커스텀 섹션 3분기(deepCustomRepeat)' ($guiSource -match "rbCatDeep\.Checked\)\s*\{\s*'deepCustomRepeat'") $true
# 2026-08-09 감사: 섹션→마커 매핑을 Get-CustomMarkerFileForSection 한 곳으로 모았습니다
# (시작 시 분기와 초기화/랜덤 토글의 분기가 갈라져 다른 콘텐츠 마커를 지우던 결함).
Assert-Case '배선: 심층 전용 마커 파일 분기' `
  ($guiSource -match "'deepCustomRepeat' \{ return \`$customDeepMarkerFile \}") $true
Assert-Case '배선: 셀 편집 디스패처에 심층 리스트 분기' ($guiSource -match 'elseif \(\$clickSender -eq \$lvDcrList\)') $true
Assert-Case '배선: 셀 편집 적용에 심층 분기' ($guiSource -match 'elseif \(\$applyList -eq \$lvDcrList\)') $true
Assert-Case '배선: 시작 게이트 층 전환 검사에 deepCustomRepeat 포함' ($guiSource -match "-eq 'customRepeat' -or \`$script:customConfigSection -eq 'deepCustomRepeat'") $true
# 목록 끝 고정 검사는 뒤에 섹션이 추가될 때마다 깨지므로 포함 여부만 확인 (2026-07-28 assist 추가로 수정)
Assert-Case '배선: 마이그레이션 섹션 목록에 deepDungeon/deepCustomRepeat' `
  (($guiSource -match "'deepDungeon', 'huntingGround'") -and ($guiSource -match "'deepCustomRepeat', ")) $true
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '배선(워커): 심층 커스텀 강제 규칙(어려움 고정)' ($workerSource -match "if \(\`$deepMode\) \{[\s\S]{0,400}\`$ndDifficulty = '어려움'") $true
Assert-Case '배선(워커): 심층 재화 테이블 치환(1/2개)' ($workerSource -match '\$dgValidCosts = @\(1, 2\)') $true
# 2026-07-28 실기 2건(상반): 심층 옵션 제목은 폭 250에서 '구역' 잘림(20:20) / 밝은 배경
# 선택 화면은 폭 420 판독 전멸(20:53) → Read-DgTitleText 이중 판독(좁은 우선 + 조건부 확장).
# 2026-08-11 23:29 실사고(타 PC 1908 창)로 확장을 **일반 던전에도** 개방 - 좁은 판독
# '로다0'(구역/층 소실)이 옵션 화면을 선택 화면으로 오판시켰고, 같은 캡처 폭 420은 3장
# 전부 '로다2증2구역'('구역' 생존). 채택은 '구역' 보일 때만이라 07-28 반례는 그대로 안전.
# 2026-08-11 23:55 실사고(같은 PC)로 넓은 판독에 **배율 3→4 사다리** 추가 - 넓은 s3 가
# '로다2증1구°'('역'→'°' 깨짐)로 8회 전부 채택 탈락해 다 된 2-1 전환을 두고 정지.
# 같은 캡처 s4 는 '로다2증1구역' 정상(스테이지 매칭 통과). 로컬 보관 87장 전수 재생 -
# s4 가 반환값을 바꾸는 캡처 0건. (단언은 주석 뺀 사본 기준 - Extent.Text 는 주석 포함)
# 2026-08-12 23:55 실사고(심층 페카고분)로 **s5 추가** - 그 캡처는 s3/s4 둘 다 '구역' 소실
# ('패가고분=石' 등)이고 s5 만 '제고분심증2증1구역'으로 복구. 어제 캡처는 반대(s4 성공·s5
# 실패)라 사다리 순회가 정답. 로컬 보관 90장 전수 재생 - s5 채택 변화 0건.
$titleCode = ((([string](Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Read-DgTitleText'))) -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선(워커): 제목 이중 판독 함수 존재(조건부 확장)' `
  ($titleCode -match '-RegionWidth 420') $true
Assert-Case '배선(워커): 확장이 심층 전용 게이트 없이 전 모드 적용 (2026-08-11)' `
  ($titleCode -notmatch 'if \(-not \$deepMode\) \{ return \$narrowText \}') $true
Assert-Case '배선(워커): 넓은 판독은 배율 3→4→5 사다리 (2026-08-11/12 실사고 2건)' `
  ($titleCode -match 'foreach \(\$wideScale in 3, 4, 5\)') $true
Assert-Case '배선(워커): 넓은 판독이 사다리 변수 배율을 실제로 사용 (-Scale 고정값 퇴행 방지)' `
  ($titleCode -match '-Scale \$wideScale') $true
Assert-Case '배선(워커): 확장 채택은 구역이 보일 때만 + 전부 실패 시 좁은 결과 유지 (전멸 반례 안전 계약)' `
  ($titleCode -match "(?s)\`$wideText\.Contains\('구역'\)\) \{ return \`$wideText \}\s*\r?\n\s*\}\s*\r?\n\s*return \`$narrowText") $true
Assert-Case '배선(워커): 폭 420 전역 오버라이드 철회됨' `
  ($workerSource -notmatch '\$rgDgTitle = @\(\$rgDgTitle\[0\], \$rgDgTitle\[1\], 420') $true
# 2026-07-28 실기 2차: 주간 구역 채택이 '매우 어려움' 클릭 전 버튼을 읽어 어려움 상태 구역을
# 오채택 → 난이도 확정 '후' 재채택 2지점(선택=진입 버튼 / 옵션=제목)이 있어야 함
Assert-Case '배선(워커): 주간 구역 재채택(선택 화면, 난이도 전환 후)' `
  ($workerSource -match '주간 구역 재채택: \$\{ndStage\} → \$\{weeklyNowStage\}') $true
Assert-Case '배선(워커): 주간 구역 최종 확인(옵션 화면 수렴점)' `
  ($workerSource -match '주간 구역 최종 확인: \$\{ndStage\} → \$\{weeklyTitleStage\}') $true
# 2026-07-28 실기 3차: 시작 정리가 심층 선택 화면을 못 알아보고 X 후보 클릭으로 던전 UI를
# 닫은 사고 → Test-KnownScreen 진입 버튼 2차 신호 + 주간 판독 3회 재시도
Assert-Case '배선(워커): Test-KnownScreen 진입 버튼 2차 신호' `
  ($workerSource -match "\`$dgEnterProbe\.Contains\('진입'\)") $true
Assert-Case '배선(워커): 주간 구역 판독 3회 재시도' `
  ($workerSource -match '\$weeklyTry -le 3 -and -not \$weeklyStage') $true
# 2026-07-28 실기 4차: 입장 직후 물약 팝업이 입장 완료 감지를 가림 → 입장/매칭 대기 6지점에
# 팝업 스윕 추가 (Condition 안에서는 반환값을 소비해 대기 오판 방지 - PS 5.1 출력 오염)
Assert-Case '배선(워커): 입장 대기 팝업 스윕 6지점(반환값 소비 계약)' `
  ([regex]::Matches($workerSource, 'if \(Invoke-PurchasePopupSweep -Game \$[Gg]ame\) \{ return \$false \}').Count -eq 5 -and
   [regex]::Matches($workerSource, '\[void\]\(Invoke-PurchasePopupSweep').Count -eq 1) $true
# 2026-07-28 22:40 실기: 입장 버튼 뿔 아이콘이 'V'/'7'로 오독돼 소모량 1이 7로 판독 →
# deep 은 아이콘 제외 영역(978,636,152,44)으로 오버라이드 (캡처 19/19 첫 시도 정확 판독)
Assert-Case '배선(워커): 심층 소모량 판독 영역 아이콘 제외 오버라이드' `
  ($workerSource -match '\$rgDgTributeCost = @\(978, 636, 152, 44\)') $true
# 2026-07-28 22:48 실기: 제목 공백 시 선택 화면 미인식 → 진입 버튼 2차 신호 + 게이트/분기 변수 통일
Assert-Case '배선(워커): 시작 검증 선택 화면 2차 신호(진입 버튼)' `
  (($workerSource -match '선택 화면 인식 \(제목 판독 실패') -and
   ($workerSource -match 'if \(\$onOptionsScreen -or \$onSelectionScreen\)') -and
   ($workerSource -match 'if \(-not \$onOptionsScreen -and -not \$onSelectionScreen\)')) $true
# 2026-07-28 23:12 실기: 입장 로딩 중 퀘스트 클리어 보상 전체 화면이 입장 감지를 가림 →
# 스윕 헬퍼가 전용 문구 확인 후 '확인' 버튼 클릭 (Space 금지 정책 - 상태 기반 클릭만)
Assert-Case '배선(워커): 입장 대기 스윕에 퀘스트 클리어 확인 처리' `
  (($workerSource -match '퀘스트 클리어 보상 화면 감지 - 확인 클릭') -and
   ($workerSource -match "아이템을누르")) $true
Assert-Case '배선(워커): 구역 좌표 소진 시 이미 선택 확인' `
  ($workerSource -match '이미 선택 확인 - 카드 클릭 불필요') $true
# ── 카드 토글 루프 상태 기계 시뮬레이션 (2026-08-02 06:03 실사고 회귀) ─────────────
# 사고: RDP 전환 5초가 6회 중 5회를 소모 → 복구 직후 마지막 회전에서 클릭만 하고 재확인 없이
# 종료 → 게이트 정지. 새 계약: ①캡처 실패는 회전 미소모 ②마지막 회전 클릭 시 1회전 연장.
# 프레임 시퀀스: FAIL=캡처실패 / SEL=선택됨 / CHA=도전 / NONE=판독불가
function Simulate-ToggleLoop {
  param([string[]]$Frames, [bool]$WantSelected)
  $idx = 0; $clicked = $false; $recheckDone = $false; $extended = $false
  $setTryMax = 6; $rounds = 0
  for ($setTry = 1; $setTry -le $setTryMax; $setTry++) {
    while ($idx -lt $Frames.Count -and $Frames[$idx] -eq 'FAIL') { $idx++ }   # 캡처 실패 대기 (회전 미소모)
    $rounds++
    $frame = $(if ($idx -lt $Frames.Count) { $Frames[$idx] } else { 'NONE' }); $idx++
    if ($clicked -and -not $recheckDone) { $recheckDone = $true }
    $isSelected = ($frame -eq 'SEL'); $isChallenge = ($frame -eq 'CHA')
    if (-not ($isSelected -or $isChallenge)) {
      if ($clicked) { return @{ Ok = $true; Via = '재확인 생략'; Rounds = $rounds; Extended = $extended } }
      continue
    }
    if ($isSelected -eq $WantSelected) { return @{ Ok = $true; Via = '확인'; Rounds = $rounds; Extended = $extended } }
    $clicked = $true
    if ($setTry -eq $setTryMax -and $setTryMax -eq 6 -and -not $recheckDone) { $setTryMax = 7; $extended = $true }
  }
  return @{ Ok = $false; Via = '실패'; Rounds = $rounds; Extended = $extended }
}
# 사고 재현: 캡처 실패 5프레임이 회전을 소모하지 않아, 복구 후 클릭→재확인이 정상 진행
$simCase1 = Simulate-ToggleLoop -Frames @('FAIL','FAIL','FAIL','FAIL','FAIL','SEL','CHA') -WantSelected $false
Assert-Case '토글 시뮬: 캡처 실패 5회 미소모 → 클릭 후 재확인 성공' ($simCase1.Ok -and $simCase1.Rounds -eq 2) $true
# 마지막(6회째) 회전 클릭 → 1회전 연장으로 재확인 보장
$simCase2 = Simulate-ToggleLoop -Frames @('NONE','NONE','NONE','NONE','NONE','SEL','CHA') -WantSelected $false
Assert-Case '토글 시뮬: 6회째 첫 클릭 → 연장 재확인 성공' ($simCase2.Ok -and $simCase2.Extended -and $simCase2.Rounds -eq 7) $true
# 연장 회전에서도 반대 상태면 성공 처리 없이 실패 (게이트 유지 - 리뷰 조건)
$simCase3 = Simulate-ToggleLoop -Frames @('NONE','NONE','NONE','NONE','NONE','SEL','SEL') -WantSelected $false
Assert-Case '토글 시뮬: 연장 재확인도 반대 상태면 실패 반환' (-not $simCase3.Ok -and $simCase3.Extended) $true
# 연장은 1회뿐 (무한 연장 금지)
Assert-Case '토글 시뮬: 연장 후 추가 연장 없음(총 7회전)' ($simCase3.Rounds -eq 7) $true
# 배선: 실제 함수가 시뮬과 같은 계약을 갖는지
Assert-Case '배선(워커): 토글 루프 캡처 실패 대기(회전 미소모)' `
  ($workerSource -match 'for \(\$setTry = 1; \$setTry -le \$setTryMax; \$setTry\+\+\) \{[\s\S]{0,700}?while \(\$script:screenCaptureFailing\)') $true
Assert-Case '배선(워커): 마지막 회전 클릭 시 1회전 연장' `
  ($workerSource -match 'if \(\$setTry -eq \$setTryMax -and \$setTryMax -eq 6 -and -not \$clickedRecheckDone\) \{ \$setTryMax = 7 \}') $true

# 2026-07-31 다른 PC 실기(창 1273x718): 카드 버튼 '선택됨'이 스케일 5에서 '서대되'로 깨져
# 판별 실패 → 안전 정지. 같은 화면을 스케일 3으로 읽으면 정확 판독(오프라인 재현) → 다중
# 스케일 재시도. 스케일 우선 순회(각 배율에서 주→보조)라 기존 s5 성공 경로는 1회째 그대로
# (보관 캡처 21장 전수 1회째 성공 실측 - 리뷰 조건)
# 다중 스케일은 첫 회전과 '클릭 직후 첫 재확인'에서만 - 그 외 회전은 s5 만 (2026-07-31 점검:
# 판별 완전 실패 시 OCR 이 최대 36회로 불어남. 판독 구제 효과는 두 지점에서 그대로 유지 - 리뷰 조건)
Assert-Case '배선(워커): 카드 버튼 판독 다중 스케일(5,3,4) 스케일 우선 순회' `
  (($workerSource -match 'foreach \(\$cardScale in \$cardScales\)[\s\S]{0,200}?foreach \(\$cardRegion in \$cardRegions\)') -and
   ($workerSource -match '\$cardRegions \+= , \$Region')) $true
Assert-Case '배선(워커): 다중 스케일은 1~2회전 + 클릭 후 첫 재확인만' `
  (($workerSource -match '\$cardScales = @\(5\)') -and
   ($workerSource -match 'if \(\$setTry -le 2\) \{ \$cardScales = @\(5, 3, 4\) \}') -and
   ($workerSource -match 'elseif \(\$clicked -and -not \$clickedRecheckDone\)[\s\S]{0,120}\$clickedRecheckDone = \$true')) $true
Assert-Case '배선(워커): 경고 로그가 빈 판독을 명시' `
  ($workerSource -match "\(판독 없음\)") $true
# 2026-07-30 스윕: 공물 잔량 '0'/'1' 고립 숫자 미검출 → 재화줄 넓은 판독에서 공물 자리
# (단어 중심 x 1080~1110) 단어의 끝 숫자 채택 (캡처 6장 정답률 100%). 실패 시 기존 좁은
# 영역 폴백 유지, 일반 던전 경로 무접촉 (deepMode 분기)
Assert-Case '배선(워커): 공물 잔량 공물 자리 단어 판독 + 기존 폴백 유지' `
  ($workerSource -match 'function Get-DgCoinBalance[\s\S]{0,2200}?-ge 1080 -and [\s\S]{0,60}?-le 1110[\s\S]{0,1000}?rgDgCoinBalance') $true
# 2026-07-30 00:36 1908 타 PC 실기: 제목 오독 → ID 불명 → 라벨은 정상인데 적갈색 카드라
# 남색 픽셀 확인 전멸 → 정지. 심층은 화이트리스트 라벨 신뢰(픽셀 미확인 채택) + 클릭 후
# 진입 버튼/제목 2차 검증에 위임 (색 판별식은 카드 R24~103 vs 배경 R16~45 겹침으로 기각)
Assert-Case '배선(워커): 심층 선택 라벨 픽셀 미확인 채택 2곳(배율3/5)' `
  (($workerSource -match "Source = '라벨\(픽셀 미확인\)'") -and
   ($workerSource -match "라벨\(배율5·픽셀 미확인\)")) $true
Assert-Case '배선(워커): 일반 던전은 라벨 픽셀 확인 유지(심층 완화는 실패 후 분기)' `
  ($workerSource -match "Test-DgCardPixelAt[\s\S]{0,220}?Source = '라벨'[\s\S]{0,900}?라벨\(픽셀 미확인\)") $true
Assert-Case '배선(워커): 심층 옵션 라벨도 픽셀 미확인 채택' `
  ($workerSource -match 'if \(\$deepMode -and \$refPoint\)') $true
# 2026-07-29 00:07 실기: 미사용 역방향 해제는 Set-DgToggleCard 1회(상태 기반) + 클릭 없는
# 수동 재판독 5회x2초 (offCost 기반 raw 클릭이 해제된 카드를 도로 켜던 토글 자기 방해 교체)
Assert-Case '배선(워커): 미사용 역방향 해제 = 상태 기반 1회 + 수동 재판독' `
  (($workerSource -match '\$offTry -le 5[\s\S]{0,120}Start-Sleep -Milliseconds 2000') -and
   ($workerSource -notmatch 'offClicks')) $true
# 2026-07-29 00:58 실기: 카드를 끈 직후 소모량 표시가 갱신되지 않고 남는 잔상 실측(정지 직후
# 캡처는 버튼 깨끗+카드 도전). 카드 '도전' 확정 판독($offCardConfirmed)이 1차 증거로 이기고
# 표시 잔존은 경고 진행, 카드 미확인일 때만 정지 유지 (던전+사냥터 2곳, 리뷰 승인)
# 2026-08-09 리뷰: 이 '확정 판독'이 소모량 잔상을 이기는 근거이므로, 반환 $true 만으로는
# 부족하고 상태를 실제로 재판독($script:dgToggleRechecked)했어야 합니다.
Assert-Case '배선(워커): 역방향 카드 확인 우선 계약(잔상 허용) 2곳' `
  (([regex]::Matches($workerSource, '\$offCardConfirmed = \(\[bool\]\(Set-DgToggleCard').Count -eq 2) -and
   ([regex]::Matches($workerSource, 'elseif \(\$offCardConfirmed\)').Count -eq 2)) $true
Assert-Case '배선(워커): 역방향 확정 판독이 Rechecked 를 요구 2곳' `
  ([regex]::Matches($workerSource, "Label '?[^\r\n]*'?\)\s*-and\r?\n\s*\`$script:dgToggleRechecked\)").Count) 2
# 2026-07-28 23:56 실기: 옵션 확정은 선확인 5회 + 클릭 후 재클릭 없는 수동 확인(2초x3) +
# 최종 재클릭 1회 계약 (재클릭마다 연출이 다시 시작되는 자기 방해 방지 - 리뷰 계약)
Assert-Case '배선(워커): 옵션 확정 수동 확인 계약(선확인 5회/수동 3회/최종 재클릭 1회)' `
  (($workerSource -match '\$preTry -le 5') -and ($workerSource -match '\$passiveTry -le 3') -and
   ($workerSource -match '\$finalTry -le 3')) $true
# 2026-07-28 23:40 실기 '71': 아이콘 '7' 결합 이형 → 앞 7 제거 후 유효값 채택 보정
Assert-Case '배선(워커): 소모량 아이콘 결합 이형(7X) 보정' `
  ($workerSource -match "\^7\(\\d\+\)\`$' -and \`$ValidCosts -contains") $true
# 2026-07-28 사용자 제보: 은동전 상한 150 / 마족공물 상한 15 → 잔량 판독 상한 검증
Assert-Case '배선(워커): 잔량 판독 모드별 상한(150/15)' `
  (($workerSource -match '\$dgBalanceMax = 150') -and ($workerSource -match '\$dgBalanceMax = 15 ') -and
   ($workerSource -match '\$value -gt \$dgBalanceMax')) $true
# 2026-07-28: 탭 게이트 = 자동 전환 (전환 확인 실패 시에만 코드 4 fail-closed + 전환 후 던전 재판별)
Assert-Case '배선(워커): 탭 자동 전환 + 실패 시 정지 + 재판별' `
  (($workerSource -match "탭으로 자동 전환합니다") -and
   ($workerSource -match "탭 자동 전환을 확인하지 못했습니다") -and
   ($workerSource -match '탭 전환 확인\$tabRedetectTag')) $true

exit $fails
