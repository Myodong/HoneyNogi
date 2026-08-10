# 커스텀 리스트 셀 편집 진리표 (2026-07-25 - 셀 클릭 오버레이 드롭다운 수정)
# 본체: mabinogi_gui.ps1 Get-CrCellEditPlan / Set-CrItemCellValue / Get-AcrCellEditPlan /
#       ConvertFrom-AcrModeOption / Convert-AcrItemsForGlobalSetting
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Get-CrCellEditPlan', 'Set-CrItemCellValue', 'Get-AcrCellEditPlan',
             'ConvertFrom-AcrModeOption', 'Convert-AcrItemsForGlobalSetting')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 1. 던전 셀 편집 계획 ────────────────────────────────────────────────────
$crCoin20 = [pscustomobject]@{ difficulty = '일반'; stage = '1-1'; coin = $true; doubleLoot = $true; exhaustContinue = $false; noDoubleSweep = $true }
$crCoin20Stop = [pscustomobject]@{ difficulty = '일반'; stage = '1-1'; coin = $true; doubleLoot = $true; exhaustContinue = $false; noDoubleSweep = $false }
$crCoin10 = [pscustomobject]@{ difficulty = '어려움'; stage = '2-3'; coin = $true; doubleLoot = $false; exhaustContinue = $true; noDoubleSweep = $false }
$crCoin0 = [pscustomobject]@{ difficulty = '매우 어려움'; stage = '1-3'; coin = $false; doubleLoot = $false; exhaustContinue = $false; noDoubleSweep = $false }

$plan = Get-CrCellEditPlan -ColumnIndex 2 -Item $crCoin10
Assert-Case '던전: 난이도 열 옵션 3개' (@($plan.Options).Count) 3
Assert-Case '던전: 난이도 현재값' $plan.Current '어려움'
$plan = Get-CrCellEditPlan -ColumnIndex 3 -Item $crCoin10
Assert-Case '던전: 구역 열 옵션 6개' (@($plan.Options).Count) 6
$plan = Get-CrCellEditPlan -ColumnIndex 4 -Item $crCoin20
Assert-Case '던전: 은동전 현재값 20개' $plan.Current '20개'
Assert-Case '던전: 은동전 현재값 0개' ((Get-CrCellEditPlan -ColumnIndex 4 -Item $crCoin0).Current) '0개'
Assert-Case '던전: 소진 열 - 은동전 미사용이면 편집 불가' ($null -eq (Get-CrCellEditPlan -ColumnIndex 5 -Item $crCoin0)) $true
Assert-Case '던전: 소진 열 - 더블+멈춤(도달 불가)이면 편집 불가' ($null -eq (Get-CrCellEditPlan -ColumnIndex 5 -Item $crCoin20Stop)) $true
Assert-Case '던전: 소진 열 - 더블+소탕만이면 편집 가능' ($null -ne (Get-CrCellEditPlan -ColumnIndex 5 -Item $crCoin20)) $true
Assert-Case '던전: 소진 열 현재값 (10개 진행)' ((Get-CrCellEditPlan -ColumnIndex 5 -Item $crCoin10).Current) '진행'
Assert-Case '던전: 더블 불가 열 - 더블 아니면 편집 불가' ($null -eq (Get-CrCellEditPlan -ColumnIndex 6 -Item $crCoin10)) $true
Assert-Case '던전: 더블 불가 열 현재값' ((Get-CrCellEditPlan -ColumnIndex 6 -Item $crCoin20).Current) '소탕만'
Assert-Case '던전: 체크 열은 편집 불가' ($null -eq (Get-CrCellEditPlan -ColumnIndex 0 -Item $crCoin10)) $true
Assert-Case '던전: # 열은 편집 불가' ($null -eq (Get-CrCellEditPlan -ColumnIndex 1 -Item $crCoin10)) $true

# ── 2. 던전 셀 값 적용 + 정규화 ([추가]와 동일 규칙) ─────────────────────────
$after = Set-CrItemCellValue -Item $crCoin10 -ColumnIndex 4 -Value '20개'
Assert-Case '적용: 10개→20개 coin/double' "$([bool]$after.coin)/$([bool]$after.doubleLoot)" 'True/True'
Assert-Case '적용: 10개→20개(멈춤) 소진은 도달 불가라 false 정규화' ([bool]$after.exhaustContinue) $false
$after = Set-CrItemCellValue -Item $crCoin20 -ColumnIndex 4 -Value '0개'
Assert-Case '적용: 20개→0개 전부 해제' "$([bool]$after.coin)/$([bool]$after.doubleLoot)/$([bool]$after.exhaustContinue)/$([bool]$after.noDoubleSweep)" 'False/False/False/False'
$after = Set-CrItemCellValue -Item $crCoin10 -ColumnIndex 3 -Value '2-1'
Assert-Case '적용: 구역만 변경 시 나머지 유지' "$($after.stage)/$([bool]$after.coin)/$([bool]$after.exhaustContinue)" '2-1/True/True'
$after = Set-CrItemCellValue -Item $crCoin20 -ColumnIndex 6 -Value '멈춤'
Assert-Case '적용: 소탕만→멈춤이면 소진 분기 도달 불가로 소진 false' "$([bool]$after.noDoubleSweep)/$([bool]$after.exhaustContinue)" 'False/False'

# ── 3. 어비스 셀 편집 계획 ──────────────────────────────────────────────────
$acrSolo = [pscustomobject]@{ kind = 'abyss'; mode = 'solo'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '없음' }
$acrParty = [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '지옥1'; dungeon = '광기의 동굴'; matching = '우연한 만남' }

$plan = Get-AcrCellEditPlan -ColumnIndex 2 -Item $acrParty
Assert-Case '어비스: 방식 열은 방식+매칭 원자 옵션 4개' (@($plan.Options).Count) 4
Assert-Case '어비스: 방식 열 현재값 (함께+매칭 결합)' $plan.Current '함께하기 · 우연한 만남'
Assert-Case '어비스: 방식 열은 전체 일괄' $plan.Scope 'all'
Assert-Case '어비스: 혼자 난이도 옵션 4개 (지옥 없음)' (@((Get-AcrCellEditPlan -ColumnIndex 3 -Item $acrSolo).Options).Count) 4
Assert-Case '어비스: 함께 난이도 옵션 14개 (지옥1~10 포함)' (@((Get-AcrCellEditPlan -ColumnIndex 3 -Item $acrParty).Options).Count) 14
Assert-Case '어비스: 난이도 열은 행 단위' ((Get-AcrCellEditPlan -ColumnIndex 3 -Item $acrParty).Scope) 'row'
Assert-Case '어비스: 던전 열 옵션 3개' (@((Get-AcrCellEditPlan -ColumnIndex 4 -Item $acrSolo).Options).Count) 3
Assert-Case '어비스: 혼자 항목의 매칭 열은 편집 불가' ($null -eq (Get-AcrCellEditPlan -ColumnIndex 5 -Item $acrSolo)) $true
Assert-Case '어비스: 함께 매칭 열 옵션 3개 + 전체 일괄' `
  "$(@((Get-AcrCellEditPlan -ColumnIndex 5 -Item $acrParty).Options).Count)/$((Get-AcrCellEditPlan -ColumnIndex 5 -Item $acrParty).Scope)" '3/all'

# ── 4. 방식 옵션 → 구조화 키 (표시 문구 파싱 대신 고정 매핑) ─────────────────
Assert-Case '옵션: 혼자하기' ((ConvertFrom-AcrModeOption -OptionText '혼자하기').Mode) 'solo'
Assert-Case '옵션: 함께+우연한 만남' ((ConvertFrom-AcrModeOption -OptionText '함께하기 · 우연한 만남').Matching) '우연한 만남'
Assert-Case '옵션: 함께+파티장' ((ConvertFrom-AcrModeOption -OptionText '함께하기 · 파티(파티장)').Matching) '파티(파티장)'
Assert-Case '옵션: 알 수 없는 문구는 null' ($null -eq (ConvertFrom-AcrModeOption -OptionText '???')) $true

# ── 5. 방식/매칭 리스트 일괄 변환 ───────────────────────────────────────────
$partyItems = @(
  [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '지옥3'; dungeon = '허상의 정박지'; matching = '파티 찾기' }
  [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '광기의 동굴'; matching = '파티 찾기' }
  [pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '지옥10'; dungeon = '흩어진 물길'; matching = '파티 찾기' }
)
$result = Convert-AcrItemsForGlobalSetting -Items $partyItems -Mode 'solo' -Matching '없음'
Assert-Case '일괄: 함께→혼자 항목 수 유지' (@($result.Items).Count) 3
Assert-Case '일괄: 지옥 강등 건수' ([int]$result.DowngradeCount) 2
Assert-Case '일괄: 지옥3 → 매우 어려움' ([string]@($result.Items)[0].difficulty) '매우 어려움'
Assert-Case '일괄: 일반 난이도는 유지' ([string]@($result.Items)[1].difficulty) '어려움'
Assert-Case '일괄: 혼자 매칭은 없음' ([string]@($result.Items)[0].matching) '없음'
$result = Convert-AcrItemsForGlobalSetting -Items @($acrSolo) -Mode 'party' -Matching '파티(파티장)'
Assert-Case '일괄: 혼자→함께 강등 없음' ([int]$result.DowngradeCount) 0
Assert-Case '일괄: 혼자→함께 매칭 적용' ([string]@($result.Items)[0].matching) '파티(파티장)'
$result = Convert-AcrItemsForGlobalSetting -Items @() -Mode 'solo' -Matching '없음'
Assert-Case '일괄: 빈 리스트' (@($result.Items).Count) 0

# ── 6. 본체 소스 계약 검사 ──────────────────────────────────────────────────
$guiSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_gui.ps1') -Raw -Encoding UTF8
Assert-Case '오버레이: 네 리스트에 MouseUp 연결' `
  (($guiSource.Contains('$lvCrList.Add_MouseUp($cellEditMouseUp)')) -and
   ($guiSource.Contains('$lvAcrList.Add_MouseUp($cellEditMouseUp)')) -and
   ($guiSource.Contains('$lvDcrList.Add_MouseUp($cellEditMouseUp)')) -and
   ($guiSource.Contains('$lvLcrList.Add_MouseUp($cellEditMouseUp)'))) $true
# 2026-08-08: 디스패처의 마지막 else 가 조건 없는 '어비스 폴백'이라, 새 리스트를 연결하는
# 순간 그 클릭이 어비스 계획을 타고(엉뚱한 옵션) 적용은 어비스 리스트를 통째로 바꿨습니다
# (Invoke-AcrCellEdit 는 대상 리스트를 인자로 받지 않고 $lvAcrList 를 직접 씁니다).
# 전 리스트를 명시 분기로 좁히고 최종 else 를 return 으로 닫았습니다.
Assert-Case '오버레이: 리스트 분기는 전부 명시 (어비스 폴백 금지)' `
  (($guiSource.Contains('} elseif ($clickSender -eq $lvAcrList) {')) -and
   ($guiSource.Contains('} elseif ($applyList -eq $lvAcrList) {')) -and
   (-not ($guiSource -match '\} else \{\s*\r?\n\s*\$cellItems = @\(Get-AbyssCustomItemsFromList\)')) -and
   (-not ($guiSource -match '\} else \{\s*\r?\n\s*Invoke-AcrCellEdit'))) $true
Assert-Case '오버레이: 어비스 이벤트 연결은 리스트 생성 뒤 (시작 크래시 방지 - 리뷰 지적)' `
  ($guiSource.IndexOf('$lvAcrList = New-Object') -lt $guiSource.IndexOf('$lvAcrList.Add_MouseUp($cellEditMouseUp)')) $true
# ★ 9차 점검: 예전 단언은 낱말 'GetNewClosure' 를 세어 **주석 3건만으로 충족**됐습니다.
#   실제 클로저 두 개를 통째로 지워도 52종이 전부 통과했습니다. 주석을 뺀 코드에서
#   **실제 호출**만 세고 개수를 정확히 고정합니다.
$guiCodeOnly = (($guiSource -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '오버레이: 예약 콜백은 세션을 클로저로 캡처 (실제 호출 2곳)' `
  ([regex]::Matches($guiCodeOnly, '\.GetNewClosure\(\)').Count) 2
Assert-Case '오버레이: 실행 시작 시 커밋된 편집은 완료, 미커밋만 폐기' `
  ($guiSource -match "pendingCellEdit[\s\S]{0,200}Applied[\s\S]{0,120}Invoke-CellEditApply") $true
Assert-Case '오버레이: 커밋은 SelectionChangeCommitted + BeginInvoke 예약' `
  ($guiSource -match "Add_SelectionChangeCommitted[\s\S]{0,700}BeginInvoke") $true
Assert-Case '오버레이: DropDownClosed 는 숨기기만' `
  ($guiSource -match "Add_DropDownClosed[\s\S]{0,300}Hide-CellEditCombo") $true
# 2026-08-04 잠금 방식 변경: 그룹 통째 잠금 → 자식 개별 잠금 (커스텀 리스트는 실행 중에도
# 스크롤 허용 - 사용자 요청). 스냅샷 멱등 + 복원 + 리스트 편집 가드가 새 계약 (설계 합의)
Assert-Case '오버레이: 실행 시작 시 편집 취소 (스냅샷 잠금 뒤)' `
  ($guiSource -match "\`$IsRunning -and \`$null -eq \`$script:contentDetailEnabledSnapshot[\s\S]{0,1500}Hide-CellEditCombo") $true
Assert-Case '잠금: 커스텀 리스트 4개는 스냅샷 제외(스크롤 허용)' `
  ($guiSource -match "\`$scrollableLists = @\(\`$lvCrList, \`$lvAcrList, \`$lvDcrList, \`$lvLcrList\)") $true
Assert-Case '잠금: 전부 캡처 후 별도 루프로 비활성' `
  ($guiSource -match 'foreach \(\$detailChild in @\(\$detailSnapshot\.Keys\)\) \{ \$detailChild\.Enabled = \$false \}') $true
Assert-Case '잠금: 종료 전환 시 스냅샷 복원(+IsDisposed 방어) 후 폐기' `
  ($guiSource -match '\(-not \$IsRunning\) -and \$null -ne \$script:contentDetailEnabledSnapshot[\s\S]{0,400}IsDisposed[\s\S]{0,200}\$script:contentDetailEnabledSnapshot = \$null') $true
Assert-Case '가드: 머리글 전체 토글 running 차단 4곳' `
  ([regex]::Matches($guiSource, 'if \(\$script:running\) \{ return \}   # 실행 중').Count) 4
Assert-Case '가드: 체크 토글 running 취소(ItemCheck) 4곳' `
  ([regex]::Matches($guiSource, '\.NewValue = \$\w+\.CurrentValue').Count) 4
Assert-Case '적용: 저장 실패 시 원복 (부채널 플래그)' `
  ([regex]::Matches($guiSource, 'lastCustomSaveOk').Count -ge 6) $true
Assert-Case '적용: 강등 1건 이상이면 사전 확인창' `
  ($guiSource -match "DowngradeCount -gt 0[\s\S]{0,700}MessageBox") $true
Assert-Case '표시 규칙 단일 소스: 추가와 편집이 같은 함수 사용 (4리스트)' `
  (([regex]::Matches($guiSource, 'Set-CustomListRowTexts -Row').Count -ge 3) -and
   ([regex]::Matches($guiSource, 'Set-AbyssListRowTexts -Row').Count -ge 3) -and
   ([regex]::Matches($guiSource, 'Set-DeepListRowTexts -Row').Count -ge 3) -and
   ([regex]::Matches($guiSource, 'Set-LifeListRowTexts -Row').Count -ge 3)) $true

exit $fails
