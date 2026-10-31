# 커스텀 리스트 셀 편집 진리표 (2026-07-25 - 셀 클릭 오버레이 드롭다운 수정)
# 본체: mabinogi_gui.ps1 Get-CrCellEditPlan / Set-CrItemCellValue / Get-AcrCellEditPlan /
#       ConvertFrom-AcrModeOption / Convert-AcrItemsForGlobalSetting / Convert-AcrItemsForModeEdit /
#       Get-AbyssListLock / Get-AbyssMatchingIssues / Get-AbyssFixedItemNumbers / Invoke-AcrCellEdit
# 2026-10-27 사용자 결정 - 어비스 방식·매칭 칸 편집은 그 행만 바꿉니다(칸 하나로 리스트 전체를 바꾸던 일괄 변경은 없앰).
# 2026-10-28 사용자 결정 - 바꾼 결과가 리스트 규칙(파티 찾기·파티(파티장) 항목이 든 리스트는 전체가 같은 방식·매칭)에 어긋나도 막지 않고 그 행을
#   바꾼 뒤 로그에 경고 한 줄을 남깁니다(10-27 의 '알림 뒤 그대로'를 거둠 - 최종 차단은 시작 게이트, test_abyss_matching_uniform GS).
# 2026-10-30 사용자 결정 - 지옥 난이도 줄을 혼자하기로 바꿀 때의 강등 확인창('커스텀 반복 - 난이도 변경 확인')도 없앴습니다: 칸 편집에 MessageBox 가
#   없습니다(지옥 강등은 확인창 없이 그 행만 '매우 어려움' + 행 로그 꼬리표). §9 하니스의 MessageBox 스텁은 되살아난 창을 가로채는 안전장치입니다.
#   §6 소스 계약(강등 확인창 없음 · 꼬리표 한 곳) · §7 칸 편집 결과 진리표(GE) · §8 계획 Scope 정보 값 · 일괄 흔적(GP · GX3) ·
#   §9 Invoke-AcrCellEdit 실물 하니스(HB · HW · HD1) · 정적 행(HX1 · HX2).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms   # §9 하니스: ListView 실물 · 스텁 답 DialogResult(되살아난 창 대비)
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Get-CrCellEditPlan', 'Set-CrItemCellValue', 'Get-AcrCellEditPlan',
             'ConvertFrom-AcrModeOption', 'Convert-AcrItemsForGlobalSetting',
             'Get-AbyssListLock', 'Get-AbyssMatchingIssues', 'Get-AbyssFixedItemNumbers')) {
  Invoke-Expression $definition
}
# 칸 편집 결과 함수(2026-10-27)는 따로 올립니다 - 없으면 시험을 멈추지 않고 §7 의 행마다 '함수 없음' FAIL 로 남깁니다(고치기 전 코드로
# 돌린 재현도 행 단위로 남게). §9 하니스용 원문(Invoke-AcrCellEdit · 리스트 표시/읽기 셋)은 §9 에서 올립니다 - Invoke-AcrCellEdit 는
# MessageBox 를 가로챈 뒤에만 정의합니다(지금은 칸 편집에 MessageBox 가 없지만, 회귀 · 변이로 창이 되살아나 실제 모달 창이 뜨면 무인 러너가 멈춤).
try {
  Invoke-Expression (Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') -Names @('Convert-AcrItemsForModeEdit'))
} catch {
  "INFO 칸 편집 결과 함수를 올리지 못했습니다 - §7 은 행마다 FAIL ($($_.Exception.Message))"
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
Assert-Case '어비스: 방식 열도 행 단위(2026-10-27 일괄 변경 없앰 — 계획 Scope 는 정보 값)' $plan.Scope 'row'
Assert-Case '어비스: 혼자 난이도 옵션 4개 (지옥 없음)' (@((Get-AcrCellEditPlan -ColumnIndex 3 -Item $acrSolo).Options).Count) 4
Assert-Case '어비스: 함께 난이도 옵션 14개 (지옥1~10 포함)' (@((Get-AcrCellEditPlan -ColumnIndex 3 -Item $acrParty).Options).Count) 14
Assert-Case '어비스: 난이도 열은 행 단위' ((Get-AcrCellEditPlan -ColumnIndex 3 -Item $acrParty).Scope) 'row'
Assert-Case '어비스: 던전 열 옵션 3개' (@((Get-AcrCellEditPlan -ColumnIndex 4 -Item $acrSolo).Options).Count) 3
Assert-Case '어비스: 혼자 항목의 매칭 열은 편집 불가' ($null -eq (Get-AcrCellEditPlan -ColumnIndex 5 -Item $acrSolo)) $true
Assert-Case '어비스: 함께 매칭 열 옵션 3개 + 행 단위' `
  "$(@((Get-AcrCellEditPlan -ColumnIndex 5 -Item $acrParty).Options).Count)/$((Get-AcrCellEditPlan -ColumnIndex 5 -Item $acrParty).Scope)" '3/row'

# ── 4. 방식 옵션 → 구조화 키 (표시 문구 파싱 대신 고정 매핑) ─────────────────
Assert-Case '옵션: 혼자하기' ((ConvertFrom-AcrModeOption -OptionText '혼자하기').Mode) 'solo'
Assert-Case '옵션: 함께+우연한 만남' ((ConvertFrom-AcrModeOption -OptionText '함께하기 · 우연한 만남').Matching) '우연한 만남'
Assert-Case '옵션: 함께+파티장' ((ConvertFrom-AcrModeOption -OptionText '함께하기 · 파티(파티장)').Matching) '파티(파티장)'
Assert-Case '옵션: 알 수 없는 문구는 null' ($null -eq (ConvertFrom-AcrModeOption -OptionText '???')) $true

# ── 5. 방식/매칭 리스트 일괄 변환 (칸 편집은 고친 행 하나만 넘김) ─────────────
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
# 2026-10-08: 어비스 완료 기록 저장의 mutator 도 .GetNewClosure() 클로저입니다(구현 명세 ① 2.0 체크리스트 6 - 진행 초기화의
#   완료 기록 폐기부터 GUI 에 생김). GUI 전체 개수는 셀 편집과 무관하게 늘어나므로, 세는 대상을 셀 편집의 예약 콜백 두 곳
#   (BeginInvoke 에 넘기는 세션 캡처 클로저)의 모양으로 좁힙니다 - 둘 중 하나의 클로저만 지워도 여전히 FAIL 입니다.
$guiCodeOnly = (($guiSource -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '오버레이: 예약 콜백은 세션을 클로저로 캡처 (실제 호출 2곳)' `
  ([regex]::Matches($guiCodeOnly, 'BeginInvoke\(\[Action\] \(\{\s*(?:Invoke-CellEditApply -ExpectedSession \$commitSession|Open-CellEditDropDown -ExpectedSession \$openSession)\s*\}\.GetNewClosure\(\)\)\)').Count) 2
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
# 2026-10-30 사용자 결정 - 지옥 줄을 혼자하기로 바꿀 때의 강등 확인창을 없앴습니다(옛 단언 '강등 1건 이상이면 사전 확인창'을 뒤집음).
# 주석 뺀 사본(Remove-SourceComments - 아래 §7 · §8 · §9 의 정적 행도 이 사본을 씀)에서 'DowngradeCount -gt 0' 은 행 로그 강등 꼬리표 한 곳만 남고
# 그 뒤 700자 안에 MessageBox 가 없어야 합니다. 앞 숫자는 꼬리표가 남았는지도 봅니다(꼬리표 줄을 지우면 0/False, 확인창 덩이를 되살리면 2/True).
$guiCodeNoComments = Remove-SourceComments -Text $guiSource
Assert-Case '적용: 강등이 있어도 확인창 없음 — 강등 꼬리표 한 곳(2026-10-30 사용자 결정)' `
  ('{0}/{1}' -f ([regex]::Matches($guiCodeNoComments, 'DowngradeCount -gt 0')).Count, ($guiCodeNoComments -match "DowngradeCount -gt 0[\s\S]{0,700}MessageBox")) '1/False'
Assert-Case '표시 규칙 단일 소스: 추가와 편집이 같은 함수 사용 (4리스트)' `
  (([regex]::Matches($guiSource, 'Set-CustomListRowTexts -Row').Count -ge 3) -and
   ([regex]::Matches($guiSource, 'Set-AbyssListRowTexts -Row').Count -ge 3) -and
   ([regex]::Matches($guiSource, 'Set-DeepListRowTexts -Row').Count -ge 3) -and
   ([regex]::Matches($guiSource, 'Set-LifeListRowTexts -Row').Count -ge 3)) $true

# ── 7. 방식·매칭 칸 편집 결과 (Convert-AcrItemsForModeEdit - 2026-10-27 그 행만 · 2026-10-28 막지 않음) ──────────
# 늘 그 행 하나만 바꾼 후보를 돌려줍니다(함께→혼자로 그 행이 지옥이면 그 행만 강등) - 리스트 규칙에 어긋나는 후보도 그대로입니다(어긋남 판정은
# 적용 쪽 Invoke-AcrCellEdit 의 경고 한 줄 - §9 HB · HW · HX2). 행 번호가 범위 밖이면 'none'(바꾸지 않음). 10-27 의 'blocked' · Reason · FixedMatching 은
# 없앴습니다(GE24 · GE-S). 출력 = Scope · 강등 N · 돌려준 Items. 기대값: Scope 는 계약 열거값('row' · 'none'), 바뀐 칸은 계약 자료(그 행만 ·
# 함께→혼자의 지옥은 '매우 어려움'). 강등 건수는 결과 함수의 계약 그대로이고, 적용 쪽은 확인창 없이 행 로그 꼬리표에만 씁니다(2026-10-30 - §9 HB7t).
# 소스 단언은 주석 뺀 사본($guiCodeNoComments - §6 에서 만듦)으로 봅니다.
function NewAcr {
  param([string]$Mode, [string]$Matching, [string]$Difficulty = '어려움', [string]$Dungeon = '허상의 정박지')
  return [pscustomobject]@{ kind = 'abyss'; mode = $Mode; difficulty = $Difficulty; dungeon = $Dungeon; matching = $Matching }
}
function EditRow {
  # 방식 칸(2)은 드롭다운 문구를 ConvertFrom-AcrModeOption 으로, 매칭 칸(5)은 함께하기 + 그 매칭으로 넘깁니다(Invoke-AcrCellEdit 와 같은 입력)
  param($Items, [int]$Row, [string]$Option, [int]$Column = 2)
  if (-not (Get-Command Convert-AcrItemsForModeEdit -ErrorAction SilentlyContinue)) { return '함수 없음' }
  $target = $(if ($Column -eq 2) { ConvertFrom-AcrModeOption -OptionText $Option } else { @{ Mode = 'party'; Matching = $Option } })
  $result = Convert-AcrItemsForModeEdit -Items $Items -RowIndex $Row -Mode ([string]$target.Mode) -Matching ([string]$target.Matching)
  $cells = @($result.Items | ForEach-Object { '{0}/{1}/{2}' -f $_.mode, $_.difficulty, $_.matching }) -join ' · '
  return ('{0} · 강등 {1} · {2}' -f $result.Scope, $result.DowngradeCount, $cells)
}
$solo = NewAcr 'solo' '없음'
$chance = NewAcr 'party' '우연한 만남' '입문' '광기의 동굴'
$find = NewAcr 'party' '파티 찾기'
$lead = NewAcr 'party' '파티(파티장)'
$member = NewAcr 'party' '파티(파티원)'
$soloHard = NewAcr 'solo' '없음' '어려움' '허상의 정박지'
$chanceHell = NewAcr 'party' '우연한 만남' '지옥3' '광기의 동굴'
$soloIntro = NewAcr 'solo' '없음' '입문' '흩어진 물길'
$findHell = NewAcr 'party' '파티 찾기' '지옥3' '허상의 정박지'
$findHard = NewAcr 'party' '파티 찾기' '어려움' '광기의 동굴'
$findNs = NewAcr 'party' '파티찾기'
Assert-Case 'GE1 섞을 수 있는 리스트 2행 우연(지옥3) → 혼자하기 = 그 행만 · 강등 1' (EditRow @($soloHard, $chanceHell, $soloIntro) 1 '혼자하기') 'row · 강등 1 · solo/어려움/없음 · solo/매우 어려움/없음 · solo/입문/없음'
Assert-Case 'GE2 섞을 수 있는 리스트 1행 혼자 → 함께하기 · 우연한 만남 = 그 행만' (EditRow @($soloHard, $chanceHell) 0 '함께하기 · 우연한 만남') 'row · 강등 0 · party/어려움/우연한 만남 · party/지옥3/우연한 만남'
Assert-Case 'GE3 섞을 수 있는 리스트 1행 → 함께하기 · 파티 찾기 = 그 행만 바뀜(어긋나도 막지 않음 - 경고는 적용 쪽)' (EditRow @($soloHard, $chanceHell) 0 '함께하기 · 파티 찾기') 'row · 강등 0 · party/어려움/파티 찾기 · party/지옥3/우연한 만남'
Assert-Case 'GE4 섞을 수 있는 리스트 2행 매칭 칸 → 파티(파티장) = 그 행만 바뀜' (EditRow @($soloHard, $chanceHell) 1 '파티(파티장)' 5) 'row · 강등 0 · solo/어려움/없음 · party/지옥3/파티(파티장)'
Assert-Case 'GE5 고정 리스트(찾기) 1행 → 혼자하기 = 그 행만 · 지옥 강등 1(적용 쪽 확인창 없음 - 2026-10-30 사용자 결정)' (EditRow @($findHell, $findHard) 0 '혼자하기') 'row · 강등 1 · solo/매우 어려움/없음 · party/어려움/파티 찾기'
Assert-Case 'GE6 고정 리스트(찾기) 2행 매칭 칸 → 우연한 만남 = 그 행만 바뀜' (EditRow @($findHell, $findHard) 1 '우연한 만남' 5) 'row · 강등 0 · party/지옥3/파티 찾기 · party/어려움/우연한 만남'
Assert-Case 'GE7 1항목 [우연 지옥1] → 혼자하기 = 그 행 · 강등 1' (EditRow @((NewAcr 'party' '우연한 만남' '지옥1')) 0 '혼자하기') 'row · 강등 1 · solo/매우 어려움/없음'
Assert-Case 'GE8 직접 편집 [혼자, 찾기](고정) 1행 → 우연 = 그 행만(결과 [우연, 찾기]도 어긋남 - 막지 않음)' (EditRow @($soloHard, $findHard) 0 '함께하기 · 우연한 만남') 'row · 강등 0 · party/어려움/우연한 만남 · party/어려움/파티 찾기'
Assert-Case 'GE9 행 번호 범위 밖 → 바꾸지 않음(none)' (EditRow @($soloHard, $chanceHell) 5 '혼자하기') 'none · 강등 0 · solo/어려움/없음 · party/지옥3/우연한 만남'
Assert-Case 'GE10 1항목 [찾기 지옥3] → 혼자하기 = 그 행 · 강등 1(1항목은 무엇으로든)' (EditRow @($findHell) 0 '혼자하기') 'row · 강등 1 · solo/매우 어려움/없음'
Assert-Case 'GE11 1항목 [혼자] → 함께하기 · 파티 찾기 = 그 행' (EditRow @($soloHard) 0 '함께하기 · 파티 찾기') 'row · 강등 0 · party/어려움/파티 찾기'
Assert-Case 'GE12 고정 [찾기, 찾기] 1행 → 파티(파티장) = 그 행만 바뀜' (EditRow @($find, $find) 0 '함께하기 · 파티(파티장)') 'row · 강등 0 · party/어려움/파티(파티장) · party/어려움/파티 찾기'
Assert-Case 'GE13 고정 [찾기, 찾기] 1행 매칭 칸 → 파티 찾기(같은 값) = 그 행(바뀌는 것 없음)' (EditRow @($find, $find) 0 '파티 찾기' 5) 'row · 강등 0 · party/어려움/파티 찾기 · party/어려움/파티 찾기'
Assert-Case 'GE14 직접 편집 [혼자, 찾기] 1행 → 파티 찾기 = 그 행(고친 결과가 규칙에 맞음)' (EditRow @($soloHard, $findHard) 0 '함께하기 · 파티 찾기') 'row · 강등 0 · party/어려움/파티 찾기 · party/어려움/파티 찾기'
Assert-Case 'GE15 직접 편집 [혼자, 우연, 찾기] 3행 → 혼자하기 = 그 행(섞을 수 있는 리스트가 됨)' (EditRow @($solo, $chance, $find) 2 '혼자하기') 'row · 강등 0 · solo/어려움/없음 · party/입문/우연한 만남 · solo/어려움/없음'
Assert-Case 'GE16 섞이지 않은 [혼자, 혼자] 1행 → 파티 찾기 = 그 행만(일괄 변경 없음)' (EditRow @($solo, $soloIntro) 0 '함께하기 · 파티 찾기') 'row · 강등 0 · party/어려움/파티 찾기 · solo/입문/없음'
Assert-Case 'GE17 직접 편집 [우연, 파티원] 1행 → 혼자하기 = 그 행만(모르는 값 항목은 그대로)' (EditRow @($chance, $member) 0 '혼자하기') 'row · 강등 0 · solo/입문/없음 · party/어려움/파티(파티원)'
Assert-Case 'GE18 직접 편집 [우연, 파티원] 2행 → 우연한 만남 = 그 행(고친 결과가 맞음)' (EditRow @($chance, $member) 1 '함께하기 · 우연한 만남') 'row · 강등 0 · party/입문/우연한 만남 · party/어려움/우연한 만남'
Assert-Case 'GE19 고정 [파티장 ×3] 3행 매칭 칸 → 파티 찾기 = 그 행만' (EditRow @($lead, $lead, $lead) 2 '파티 찾기' 5) 'row · 강등 0 · party/어려움/파티(파티장) · party/어려움/파티(파티장) · party/어려움/파티 찾기'
Assert-Case 'GE20 직접 편집 [파티찾기 ×2](공백 없음) 1행 → 혼자하기 = 그 행만 · 다른 항목의 원래 표기 그대로' (EditRow @($findNs, $findNs) 0 '혼자하기') 'row · 강등 0 · solo/어려움/없음 · party/어려움/파티찾기'
Assert-Case 'GE21 직접 편집 [파티장, 찾기, 찾기] 1행 → 우연 = 그 행만' (EditRow @($lead, $find, $find) 0 '함께하기 · 우연한 만남') 'row · 강등 0 · party/어려움/우연한 만남 · party/어려움/파티 찾기 · party/어려움/파티 찾기'
Assert-Case 'GE22 직접 편집 [혼자, 찾기] 2행 매칭 칸 → 파티 찾기(같은 값) = 그 행(바뀌는 것 없음 - 적용 쪽 같음 검사가 돌려보냄, §9 HW7)' (EditRow @($soloHard, $findHard) 1 '파티 찾기' 5) 'row · 강등 0 · solo/어려움/없음 · party/어려움/파티 찾기'
Assert-Case 'GE23 직접 편집 [우연, 찾기, 파티장] 1행 → 혼자하기 = 그 행만' (EditRow @($chance, $find, $lead) 0 '혼자하기') 'row · 강등 0 · solo/입문/없음 · party/어려움/파티 찾기 · party/어려움/파티(파티장)'
Assert-Case 'GE-W 칸 편집 적용이 범위 함수를 부름(행 번호 함께)' ([regex]::Matches($guiCodeNoComments, [regex]::Escape('Convert-AcrItemsForModeEdit -Items $editItems -RowIndex $RowIndex'))).Count 1
# 반환 키 = Items · DowngradeCount · Scope 셋(10-27 의 Reason · FixedMatching 없음 - 판정 키가 되살아나 적용 쪽이 다시 막는 꼴을 잡음)
function ResultKeys {
  param($Items, [int]$Row, [string]$Option)
  if (-not (Get-Command Convert-AcrItemsForModeEdit -ErrorAction SilentlyContinue)) { return '함수 없음' }
  $target = ConvertFrom-AcrModeOption -OptionText $Option
  $result = Convert-AcrItemsForModeEdit -Items $Items -RowIndex $Row -Mode ([string]$target.Mode) -Matching ([string]$target.Matching)
  return ((@($result.Keys) | Sort-Object) -join ',')
}
Assert-Case 'GE24 반환 키 셋(어긋나는 그 행 · 범위 밖) = DowngradeCount,Items,Scope' ('{0}|{1}' -f (ResultKeys @($soloHard, $chanceHell) 0 '함께하기 · 파티 찾기'), (ResultKeys @($soloHard, $chanceHell) 5 '혼자하기')) 'DowngradeCount,Items,Scope|DowngradeCount,Items,Scope'
# 던전 보존 (구현 리뷰 반영): 위 GE 행은 방식/난이도/매칭만 견주므로, 방식·매칭 칸 편집이 던전을 비우거나 행끼리 섞어도 통과합니다. 항목마다 다른
# 던전을 두고 강등(지옥 → 혼자) · 혼자 → 함께 · 어긋나는 편집 · 범위 밖에서 던전 열이 그대로인지 따로 봅니다.
function DungeonsAfter {
  param($Items, [int]$Row, [string]$Option)
  if (-not (Get-Command Convert-AcrItemsForModeEdit -ErrorAction SilentlyContinue)) { return '함수 없음' }
  $target = ConvertFrom-AcrModeOption -OptionText $Option
  $result = Convert-AcrItemsForModeEdit -Items $Items -RowIndex $Row -Mode ([string]$target.Mode) -Matching ([string]$target.Matching)
  return ((@($result.Items) | ForEach-Object { [string]$_.dungeon }) -join ',')
}
$dgA = NewAcr 'party' '우연한 만남' '지옥3' '던전A'
$dgB = NewAcr 'solo' '없음' '어려움' '던전B'
$dgC = NewAcr 'party' '파티 찾기' '어려움' '던전C'
Assert-Case 'GE-D 방식·매칭 칸 편집은 던전을 그대로 둠(항목마다 다른 던전 - 강등 · 혼자 → 함께 · 어긋나는 편집 · 범위 밖)' ('{0}|{1}|{2}|{3}' -f (DungeonsAfter @($dgA, $dgB, $dgC) 0 '혼자하기'),
    (DungeonsAfter @($dgA, $dgB, $dgC) 1 '함께하기 · 우연한 만남'), (DungeonsAfter @($dgA, $dgB, $dgC) 1 '함께하기 · 파티 찾기'), (DungeonsAfter @($dgA, $dgB, $dgC) 5 '혼자하기')) '던전A,던전B,던전C|던전A,던전B,던전C|던전A,던전B,던전C|던전A,던전B,던전C'
# 결과 함수 안에는 규칙 판정이 없어야 합니다(판정은 적용 쪽 한 곳 - 시작 게이트와 같은 Get-AbyssMatchingIssues): 판정 함수 호출 0 · 'blocked' 글자 0
$modeEditText = ''
try { $modeEditText = [string]@(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') -Names @('Convert-AcrItemsForModeEdit'))[0] } catch { $modeEditText = '' }
$modeEditTokens = $null; $modeEditErrors = $null
$modeEditAst = [System.Management.Automation.Language.Parser]::ParseInput($modeEditText, [ref]$modeEditTokens, [ref]$modeEditErrors)
Assert-Case 'GE-S 칸 편집 결과 함수 - 함수 있음 · 규칙 판정 호출 0 · blocked 글자 0' ('{0}/{1}/{2}' -f ([bool]$modeEditText),
    @($modeEditAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.CommandAst]) -and (@('Get-AbyssMatchingIssues', 'Get-AbyssListLock') -contains [string]$n.GetCommandName()) }, $true)).Count,
    @($modeEditAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and ([string]$n.Value -ceq 'blocked') }, $true)).Count) 'True/0/0'

# ── 8. 칸 편집 계획 Scope 정보 값 · 일괄 흔적 (2026-10-27) ─────────────────────
# 계획 Get-AcrCellEditPlan 의 Scope 는 읽는 코드가 없는 정보 값입니다 - 방식·매칭도 'row'(옛 'all' = 리스트 전체 일괄은 거짓이 됨).
# 칸 편집의 일괄 흔적(전체 변경 로그 · 리스트 전체 변환 호출 둘 · 일괄 실패 로그)은 주석 뺀 사본에서 0 이어야 합니다.
$planParty = NewAcr 'party' '우연한 만남' '지옥1' '광기의 동굴'
Assert-Case 'GP1 계획 Scope - 방식(2) · 난이도(3) · 던전(4) · 매칭(5) 모두 row' ((@(2, 3, 4, 5) | ForEach-Object { [string](Get-AcrCellEditPlan -ColumnIndex $_ -Item $planParty).Scope }) -join ',') 'row,row,row,row'
Assert-Case 'GP2 계획의 Scope 를 읽는 코드 0(정보 값)' ([regex]::Matches($guiCodeNoComments, '\$cellPlan\.Scope').Count) 0
Assert-Case 'GX3 칸 편집 일괄 흔적 0(전체 변경 로그 · 리스트 전체 변환 호출 둘 · 일괄 실패 로그)' ('{0}/{1}/{2}/{3}' -f ([regex]::Matches($guiCodeNoComments, [regex]::Escape('어비스 리스트 방식·매칭 전체 변경'))).Count,
    ([regex]::Matches($guiCodeNoComments, [regex]::Escape('Convert-AcrItemsForGlobalSetting -Items $meList '))).Count, ([regex]::Matches($guiCodeNoComments, [regex]::Escape('Convert-AcrItemsForGlobalSetting -Items $editItems'))).Count,
    ([regex]::Matches($guiCodeNoComments, [regex]::Escape('방식·매칭 일괄 변경 저장에 실패'))).Count) '0/0/0/0'

# ── 9. 칸 편집 적용 Invoke-AcrCellEdit 실물 하니스 (2026-10-27 그 행만 · 2026-10-28 막지 않고 어긋나면 로그 경고 한 줄 · 2026-10-30 강등 확인창 없음) ──────────
# ListView 실물 + 리스트 표시/읽기 원문(Add-AbyssCustomListRow · Set-AbyssListRowTexts · Get-AbyssCustomItemsFromList) + 칸 편집 원문을 그대로 부릅니다.
# 칸 편집에는 MessageBox 가 없습니다(2026-10-28 차단 알림 없앰 · 2026-10-30 사용자 결정 - 지옥 강등은 확인창 없이 행 로그 꼬리표). 그래도 칸 편집
# 원문(주석 뺀 사본)의 '[System.Windows.Forms.MessageBox]::Show(' 글자는 스텁 객체 호출로 바꿔 가로챕니다 - 회귀 · 변이로 창이 되살아나도 실제 모달 창이
# 떠 무인 러너가 멈추지 않게 하는 안전장치입니다(인자를 그대로 기록 · 답은 행이 정함 - 되살아난 창은 알림 수로 FAIL). 저장(Save-CustomRepeatToConfig) ·
# 잠금(Update-AbyssInputLock) · 로그(Add-GuiLog)는 횟수 · 글자를 세는 스텁이고, 넷 모두 사건 목록(save · lock · log안내/log경고 · mb)에도 적어 차례를
# 행동으로 봅니다(HW8 · HB5t · HD1 - 5b-6 의 정적 HB-S 를 대신함).
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$guiParseTokens = $null; $guiParseErrors = $null
$guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$guiParseTokens, [ref]$guiParseErrors)
$hbNames = @('Invoke-AcrCellEdit', 'Get-AbyssCustomItemsFromList', 'Add-AbyssCustomListRow', 'Set-AbyssListRowTexts')
$hbTexts = @(Get-SourceFunctionDefinitions -Path $guiPath -Names $hbNames)
$hbNeed = @{}
for ($hbNameIndex = 0; $hbNameIndex -lt $hbNames.Count; $hbNameIndex++) { $hbNeed[$hbNames[$hbNameIndex]] = $hbTexts[$hbNameIndex] }
Invoke-Expression $hbNeed['Get-AbyssCustomItemsFromList']
Invoke-Expression $hbNeed['Add-AbyssCustomListRow']
Invoke-Expression $hbNeed['Set-AbyssListRowTexts']
$mbToken = '[System.Windows.Forms.MessageBox]::Show('
$hbCellEditCode = Remove-SourceComments -Text $hbNeed['Invoke-AcrCellEdit']
$hbMbSites = ([regex]::Matches($hbCellEditCode, [regex]::Escape($mbToken))).Count
$hbReplaced = $hbCellEditCode.Replace($mbToken, '$global:hbMbStub.Show(')
# 하니스 준비 검사: 바꾼 뒤에도 MessageBox 형식(이름이 MessageBox 로 끝나는 형식)의 정적 Show 호출이 남거나 파서 오류가 있으면 실제 모달 창이
# 떠 무인 러너가 멈추므로, 그때는 칸 편집 함수를 정의하지 않고 HB · HW · HD1 · 참고 줄을 부르지 않습니다(HB0 · HX1 · HX2 는 정적이라 그대로 봄).
$hbTokens = $null; $hbErrors = $null
$hbReplacedAst = [System.Management.Automation.Language.Parser]::ParseInput($hbReplaced, [ref]$hbTokens, [ref]$hbErrors)
$hbResidualShows = @($hbReplacedAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and $n.Static -and
      ($n.Member.Extent.Text -eq 'Show') -and ($n.Expression -is [System.Management.Automation.Language.TypeExpressionAst]) -and
      ([string]$n.Expression.TypeName.FullName -match '(^|\.)MessageBox$') }, $true)).Count
$hbReady = ($hbResidualShows -eq 0) -and (@($hbErrors).Count -eq 0)
if ($hbReady) { Invoke-Expression $hbReplaced }
$global:hbMbStub = New-Object PSObject
Add-Member -InputObject $global:hbMbStub -MemberType ScriptMethod -Name Show -Value {
  param($Text, $Caption, $Buttons, $Icon)
  [void]$global:hbMb.Add(@([string]$Text, [string]$Caption, [int]$Buttons, [int]$Icon))
  [void]$global:hbEvents.Add('mb')
  return $global:hbAnswer
}
function Add-GuiLog {
  param([string]$Message)
  [void]$global:hbLog.Add($Message)
  [void]$global:hbEvents.Add($(if ($Message.StartsWith('[경고]')) { 'log경고' } elseif ($Message.StartsWith('[안내]')) { 'log안내' } else { 'log' }))
}
function Save-CustomRepeatToConfig { $global:hbSaves++; [void]$global:hbEvents.Add('save'); if ($global:hbSaveFails) { $script:lastCustomSaveOk = $false } }
function Update-AbyssInputLock { $global:hbLocks++; [void]$global:hbEvents.Add('lock') }
$lvAcrList = New-Object System.Windows.Forms.ListView
$script:customViewShuffled = $false
$script:uiReady = $true
$script:crLoading = $false
function HbRows { return ((@(Get-AbyssCustomItemsFromList) | ForEach-Object { '{0}/{1}/{2}' -f $_.mode, $_.difficulty, $_.matching }) -join ' · ') }
function Invoke-Hb {
  # 리스트를 그 항목들로 채운 뒤 칸 편집 원문을 부르고, 앞뒤 행 · 알림(인자) · 로그 · 저장/잠금 횟수를 돌려줍니다
  param([object[]]$Items, [int]$Row, [int]$Column, [string]$Value, [string]$Answer = 'Yes', [bool]$SaveFails = $false)
  $lvAcrList.Items.Clear()
  foreach ($hbItem in $Items) { Add-AbyssCustomListRow -Mode ([string]$hbItem.mode) -Difficulty ([string]$hbItem.difficulty) -Dungeon ([string]$hbItem.dungeon) -Matching ([string]$hbItem.matching) }
  $global:hbMb = New-Object System.Collections.ArrayList
  $global:hbLog = New-Object System.Collections.ArrayList
  $global:hbEvents = New-Object System.Collections.ArrayList
  $global:hbSaves = 0
  $global:hbLocks = 0
  $global:hbSaveFails = $SaveFails
  $global:hbAnswer = $(if ($Answer -eq 'Yes') { [System.Windows.Forms.DialogResult]::Yes } else { [System.Windows.Forms.DialogResult]::No })
  $before = HbRows
  Invoke-AcrCellEdit -RowIndex $Row -ColumnIndex $Column -Value $Value
  return @{ Before = $before; After = (HbRows); Mb = @($global:hbMb); Log = @($global:hbLog); Saves = $global:hbSaves; Locks = $global:hbLocks; Events = (@($global:hbEvents) -join ',') }
}
# 상태 한 줄: 행(바뀌지 않았으면 '그대로') · 저장 · 잠금 갱신 · 알림 수(첫 알림 제목/단추/아이콘) · 로그 수
function HbState {
  param($R)
  $mbHead = $(if (@($R.Mb).Count -gt 0) { '{0}/{1}/{2}' -f $R.Mb[0][1], $R.Mb[0][2], $R.Mb[0][3] } else { '-' })
  $rowsText = $(if ([string]$R.After -ceq [string]$R.Before) { '그대로' } else { [string]$R.After })
  return ('{0} · 저장 {1} · 잠금 {2} · 알림 {3}({4}) · 로그 {5}' -f $rowsText, $R.Saves, $R.Locks, @($R.Mb).Count, $mbHead, @($R.Log).Count)
}
# 기대 원문 캡처: 칸 편집 함수의 경고 형식('[경고] 어비스 항목 ' 로 시작하는 상수 - 정확히 1개). 강등 확인창은 없으므로(2026-10-30 사용자 결정) 그 제목 ·
# 단추 · 아이콘 기대값은 두지 않습니다 - 되살아난 창은 HB0 · HB5 · HB7 · HB8 · HB9 · HD1 의 알림 수와 HX1(제목 글자 0)이 잡습니다.
$cellEditAst = $guiAst.Find({ param($n) ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($n.Name -eq 'Invoke-AcrCellEdit') }, $true)
$warnFormats = @($cellEditAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and ([string]$n.Value).StartsWith('[경고] 어비스 항목 ') }, $true) | ForEach-Object { [string]$_.Value })
# 경고 줄 글자: 원문 형식에 이 행의 값(행 번호 · 고정 항목 번호)을 넣은 것과 같고, 결정의 뜻 구절이 들어 있으며 차단 시절 구절이 없어야 합니다
# (원문 형식만 캡처해 견주면 형식을 고친 변경을 기대가 같이 따라가므로 뜻 구절은 글자로 둡니다). 경고는 늘 두 번째 줄(행 로그 다음)입니다.
# 해소 길의 대상은 '방금 바꾼 N번 항목'(N = 이 행의 번호)입니다 - 바로 앞 고정 항목 번호(F번)로 읽히지 않게 번호로 적음(설계 리뷰 반영).
function HbWarnCheck {
  param($R, [int]$RowNumber, [string]$FixedNumbers)
  if ($warnFormats.Count -ne 1) { return ('원문 캡처 {0}' -f $warnFormats.Count) }
  $logs = @($R.Log)
  if ($logs.Count -ne 2) { return ('로그 {0}줄' -f $logs.Count) }
  $actual = [string]$logs[1]
  $problems = @()
  if ($actual -cne ($warnFormats[0] -f $RowNumber, $FixedNumbers)) { $problems += "글자 [$actual]" }
  $phrases = @(('어비스 항목 {0} ' -f $RowNumber), "'파티 찾기'·'파티(파티장)'", ('항목({0}번)' -f $FixedNumbers), '모든 항목이 같은 방식·매칭이어야',
    '시작할 수 없습니다', ('나머지 항목도 방금 바꾼 {0}번 항목과 같은 방식·매칭으로 바꾸면' -f $RowNumber))
  $miss = @($phrases | Where-Object { -not $actual.Contains($_) })
  if ($miss.Count -gt 0) { $problems += ('뜻 구절 없음 [' + ($miss -join ' | ') + ']') }
  $bad = @(@('바꿀 수 없습니다', '변경 차단', '되돌') | Where-Object { $actual.Contains($_) })
  if ($bad.Count -gt 0) { $problems += ('차단 시절 구절 [' + ($bad -join ' | ') + ']') }
  if (-not $actual.StartsWith('[경고] ')) { $problems += '머리' }
  if ($problems.Count -eq 0) { return 'OK' }
  return ($problems -join ' / ')
}
Assert-Case 'HB0 하니스 준비(MessageBox 자리 0 = 차단 알림 · 강등 확인창 모두 없음, 2026-10-30 사용자 결정 / 바꾼 뒤 남은 실제 MessageBox 호출 0)' ('{0}/{1}' -f $hbMbSites, $hbResidualShows) '0/0'
if ($hbReady) {
  $hbr = Invoke-Hb @($solo, $chance) 0 2 '함께하기 · 파티 찾기'
  Assert-Case 'HB1 섞을 수 있는 [혼자, 우연] 1행 방식 → 파티 찾기 = 그 행 적용 · 저장 1 · 잠금 1 · 알림 0 · 로그 2(행 로그 + 경고)' (HbState $hbr) 'party/어려움/파티 찾기 · party/입문/우연한 만남 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 2'
  Assert-Case 'HB1t 행 로그 · 경고 글자(고정 항목 1번)' ('{0} | {1}' -f [string]@($hbr.Log)[0], (HbWarnCheck $hbr 1 '1')) '[안내] 어비스 항목 1 방식 변경: 함께하기/파티 찾기 | OK'
  Assert-Case 'HW8 차례 - 저장 → 잠금 → 행 로그 → 경고(경고는 저장 성공 꼬리에서만)' $hbr.Events 'save,lock,log안내,log경고'
  $hbr = Invoke-Hb @($solo, $chance) 1 5 '파티(파티장)'
  Assert-Case 'HB2 섞을 수 있는 [혼자, 우연] 2행 매칭 칸 → 파티(파티장) = 그 행 적용 + 경고' (HbState $hbr) 'solo/어려움/없음 · party/입문/파티(파티장) · 저장 1 · 잠금 1 · 알림 0(-) · 로그 2'
  Assert-Case 'HB2t 행 로그 · 경고 글자(고정 항목 2번)' ('{0} | {1}' -f [string]@($hbr.Log)[0], (HbWarnCheck $hbr 2 '2')) '[안내] 어비스 항목 2 방식 변경: 함께하기/파티(파티장) | OK'
  $hbr = Invoke-Hb @($find, $find) 1 2 '혼자하기'
  Assert-Case 'HB3 고정 [찾기, 찾기] 2행 방식 → 혼자하기 = 그 행 적용 + 경고' (HbState $hbr) 'party/어려움/파티 찾기 · solo/어려움/없음 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 2'
  Assert-Case 'HB3t 행 로그 · 경고 글자(고정 항목 1번 - 위반 번호 2 가 아님)' ('{0} | {1}' -f [string]@($hbr.Log)[0], (HbWarnCheck $hbr 2 '1')) '[안내] 어비스 항목 2 방식 변경: 혼자하기 | OK'
  $hbr = Invoke-Hb @($lead, $lead) 0 5 '우연한 만남'
  Assert-Case 'HB4 고정 [파티장, 파티장] 1행 매칭 칸 → 우연한 만남 = 그 행 적용 + 경고' (HbState $hbr) 'party/어려움/우연한 만남 · party/어려움/파티(파티장) · 저장 1 · 잠금 1 · 알림 0(-) · 로그 2'
  Assert-Case 'HB4t 행 로그 · 경고 글자(고정 항목 2번)' ('{0} | {1}' -f [string]@($hbr.Log)[0], (HbWarnCheck $hbr 1 '2')) '[안내] 어비스 항목 1 방식 변경: 함께하기/우연한 만남 | OK'
  $hbr = Invoke-Hb @($findHell, $findHard) 0 2 '혼자하기' 'Yes'
  Assert-Case 'HB5 고정 [찾기 지옥3, 찾기] 1행 → 혼자하기 = 확인창 없이 그 행 강등 적용 + 경고(2026-10-30 사용자 결정)' (HbState $hbr) 'solo/매우 어려움/없음 · party/어려움/파티 찾기 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 2'
  Assert-Case 'HB5t 강등 로그 · 경고 글자 · 차례(저장 → 잠금 → 행 로그 → 경고)' ('{0} | {1} | {2}' -f [string]@($hbr.Log)[0], (HbWarnCheck $hbr 1 '2'), $hbr.Events) '[안내] 어비스 항목 1 방식 변경: 혼자하기 (지옥 → 매우 어려움 강등 1건) | OK | save,lock,log안내,log경고'
  $hbr = Invoke-Hb @($solo, $chance) 0 2 '함께하기 · 우연한 만남'
  Assert-Case 'HB6 섞을 수 있는 [혼자, 우연] 1행 → 우연한 만남 = 그 행만 · 저장 1 · 잠금 1 · 알림 0' (HbState $hbr) 'party/어려움/우연한 만남 · party/입문/우연한 만남 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1'
  Assert-Case 'HB6t 행 변경 로그' ([string]@($hbr.Log)[0]) '[안내] 어비스 항목 1 방식 변경: 함께하기/우연한 만남'
  $hbr = Invoke-Hb @($chanceHell, $solo) 0 2 '혼자하기' 'Yes'
  Assert-Case 'HB7 섞을 수 있는 [우연 지옥3, 혼자] 1행 → 혼자하기 = 확인창 없이 그 행만 강등' (HbState $hbr) 'solo/매우 어려움/없음 · solo/어려움/없음 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1'
  Assert-Case 'HB7t 강등 로그(1건)' ([string]@($hbr.Log)[0]) '[안내] 어비스 항목 1 방식 변경: 혼자하기 (지옥 → 매우 어려움 강등 1건)'
  $hbr = Invoke-Hb @($chanceHell, $solo) 0 2 '혼자하기' 'No'
  Assert-Case 'HB8 같은 편집 · 스텁 답 아니요 = 답을 묻지 않아 HB7 과 같음(확인창이 되살아나 아니요면 그대로 · 저장 0 으로 잡힘)' (HbState $hbr) 'solo/매우 어려움/없음 · solo/어려움/없음 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1'
  $hbr = Invoke-Hb @($findHell) 0 2 '혼자하기' 'Yes'
  Assert-Case 'HB9 1항목 [찾기 지옥3] → 혼자하기 = 그 행 강등(1항목은 무엇으로든)' (HbState $hbr) 'solo/매우 어려움/없음 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1'
  # HD1 (2026-10-30 사용자 결정): 강등되는 편집이 저장에 실패하면 그 행이 지옥 그대로 되돌아가고, 칸 편집이 남기는 줄은 저장 실패 경고 하나뿐입니다
  # (강등 꼬리표 · 규칙 경고 없음). 실제 GUI '로그' 탭에는 그 앞에 저장 함수 자신의 실패 줄이 먼저 찍혀 두 줄로 보이지만, 이 하니스의 저장은 스텁이라 1 입니다.
  $hbr = Invoke-Hb @($chanceHell, $solo) 0 2 '혼자하기' 'Yes' $true
  Assert-Case 'HD1 [우연 지옥3, 혼자] 1행 → 혼자하기 · 저장 실패 = 되돌림(1행 지옥3 그대로) · 로그는 저장 실패 경고 한 줄뿐 · 차례(저장 → 잠금 → 경고)' ('{0} | {1} | {2}' -f (HbState $hbr), [string]@($hbr.Log)[0], $hbr.Events) '그대로 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1 | [경고] 셀 수정 저장에 실패해 항목을 되돌렸습니다. | save,lock,log경고'
  # HB-D 던전 보존 (구현 리뷰 반영): 실물 적용 경로(행 적용 · 저장 · 되돌림)에서도 방식·매칭 칸 편집은 리스트의 던전 열을 바꾸지 않습니다 - 위 HB 행은
  # 방식/난이도/매칭만 견주므로 항목마다 다른 던전으로 어긋나는 편집(경고) · 강등 · 저장 실패 되돌림 뒤의 던전 열을 따로 봅니다.
  function HbDungeons { return ((@(Get-AbyssCustomItemsFromList) | ForEach-Object { [string]$_.dungeon }) -join ',') }
  $hbDungeonRows = @()
  [void](Invoke-Hb @($dgB, $dgA) 0 2 '함께하기 · 파티 찾기'); $hbDungeonRows += (HbDungeons)
  [void](Invoke-Hb @($dgA, $dgB) 0 2 '혼자하기'); $hbDungeonRows += (HbDungeons)
  [void](Invoke-Hb @($dgA, $dgB) 0 2 '혼자하기' 'Yes' $true); $hbDungeonRows += (HbDungeons)
  Assert-Case 'HB-D 실물 칸 편집은 던전 열을 그대로 둠(어긋나는 편집 · 강등 · 저장 실패 되돌림)' ($hbDungeonRows -join '|') '던전B,던전A|던전A,던전B|던전A,던전B'
  $hbr = Invoke-Hb @($solo) 0 2 '함께하기 · 파티 찾기'
  Assert-Case 'HB10 1항목 [혼자] → 파티 찾기 = 그 행 · 경고 없음(항목 1개는 위반 0)' (HbState $hbr) 'party/어려움/파티 찾기 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1'
  $hbr = Invoke-Hb @($solo, $chance) 0 2 '함께하기 · 우연한 만남' 'Yes' $true
  Assert-Case 'HB11 그 행 변경 저장 실패 = 되돌림 · 잠금 재계산 · 경고 1' (HbState $hbr) '그대로 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1'
  Assert-Case 'HB11t 저장 실패 경고(그 행 편집 글자 - 일괄 아님)' ([string]@($hbr.Log)[0]) '[경고] 셀 수정 저장에 실패해 항목을 되돌렸습니다.'
  $hbr = Invoke-Hb @($solo, $soloIntro) 0 2 '함께하기 · 파티 찾기'
  Assert-Case 'HB12 섞이지 않은 [혼자, 혼자] 1행 → 파티 찾기 = 그 행 적용 + 경고(일괄 변경 없음)' (HbState $hbr) 'party/어려움/파티 찾기 · solo/입문/없음 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 2'
  $hbr = Invoke-Hb @($find, $find) 0 2 '함께하기 · 파티 찾기'
  Assert-Case 'HB13 고정 [찾기, 찾기] 1행 → 같은 값 = 아무것도 안 함' (HbState $hbr) '그대로 · 저장 0 · 잠금 0 · 알림 0(-) · 로그 0'
  $hbr = Invoke-Hb @($lead, $find, $find) 0 2 '함께하기 · 우연한 만남'
  Assert-Case 'HW2 [파티장, 찾기, 찾기] 1행 → 우연 = 위반 2 · 3 이어도 경고는 한 줄(고정 항목 2, 3번)' ('{0} | {1}' -f (HbState $hbr), (HbWarnCheck $hbr 1 '2, 3')) 'party/어려움/우연한 만남 · party/어려움/파티 찾기 · party/어려움/파티 찾기 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 2 | OK'
  $hbr = Invoke-Hb @($soloHard, $findHard) 0 2 '함께하기 · 파티 찾기'
  Assert-Case 'HW3 어긋난 [혼자, 찾기] 1행 → 파티 찾기 = 고친 결과가 맞아 경고 없음' (HbState $hbr) 'party/어려움/파티 찾기 · party/어려움/파티 찾기 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1'
  $hbr = Invoke-Hb @($solo, $chance, $find) 1 2 '혼자하기'
  Assert-Case 'HW4 어긋난 [혼자, 우연, 찾기] 2행 → 혼자하기 = 여전히 어긋나 경고(고정 항목 3번)' ('{0} | {1}' -f (HbState $hbr), (HbWarnCheck $hbr 2 '3')) 'solo/어려움/없음 · solo/입문/없음 · party/어려움/파티 찾기 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 2 | OK'
  $hbr = Invoke-Hb @($solo, $chance) 0 2 '함께하기 · 파티 찾기' 'Yes' $true
  Assert-Case 'HW6 어긋나는 편집 · 저장 실패 = 되돌림 · 경고는 저장 실패 한 줄뿐' ('{0} | {1}' -f (HbState $hbr), [string]@($hbr.Log)[0]) '그대로 · 저장 1 · 잠금 1 · 알림 0(-) · 로그 1 | [경고] 셀 수정 저장에 실패해 항목을 되돌렸습니다.'
  $hbr = Invoke-Hb @($soloHard, $findHard) 1 5 '파티 찾기'
  Assert-Case 'HW7 어긋난 [혼자, 찾기] 2행 매칭 칸 → 같은 값 = 아무 일 없음(경고도 없음 - 같음 검사가 먼저)' (HbState $hbr) '그대로 · 저장 0 · 잠금 0 · 알림 0(-) · 로그 0'
  $hbr = Invoke-Hb @($soloHard, $findHard) 1 3 '입문'
  Assert-Case 'HW9 어긋난 [혼자, 찾기] 2행 난이도 칸 = 그 행만 · 경고 없음(규칙 판정은 방식·매칭 칸만)' (HbState $hbr) 'solo/어려움/없음 · party/입문/파티 찾기 · 저장 1 · 잠금 0 · 알림 0(-) · 로그 1'
} else {
  # 하니스 준비 실패 - 실제 모달 창이 떠 무인 러너가 멈추지 않게 HB · HW · HD1 · 참고 줄을 부르지 않고 이 FAIL 한 줄만 남깁니다
  Assert-Case 'HB-준비 하니스 준비 실패(바꾼 뒤 남은 실제 MessageBox 호출 / 파서 오류 - HB · HW · HD1 을 부르지 않음)' ('{0}/{1}' -f $hbResidualShows, @($hbErrors).Count) '0/0'
}
# HX1 차단 갈래 · 강등 확인창 없음(정적 - 주석 뺀 사본 · AST): GUI 의 차단 알림 제목 · 차단 로그 머리 · 차단 구절 0 / 칸 편집의 'blocked' 글자 0 /
# 칸 편집의 Show 호출 0 · 주석 뺀 GUI 의 강등 확인창 제목 0(2026-10-30 사용자 결정 - 강등 확인창 없앰)
$cellEditShows = @($cellEditAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($n.Member.Extent.Text -eq 'Show') }, $true))
Assert-Case 'HX1 차단 갈래 · 강등 확인창 0 - 차단 알림 제목 · 차단 로그 머리 · 차단 구절 0 / blocked 0 / 칸 편집 Show 0 · 강등 확인창 제목 0' ('{0}/{1}/{2}|{3}|{4}/{5}' -f ([regex]::Matches($guiCodeNoComments, [regex]::Escape('커스텀 반복 - 변경 불가'))).Count,
    ([regex]::Matches($guiCodeNoComments, [regex]::Escape('[안내] 변경 차단:'))).Count, ([regex]::Matches($guiCodeNoComments, [regex]::Escape('이 줄만 바꿀 수 없습니다'))).Count,
    @($cellEditAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and ([string]$n.Value -ceq 'blocked') }, $true)).Count,
    $cellEditShows.Count, ([regex]::Matches($guiCodeNoComments, [regex]::Escape('커스텀 반복 - 난이도 변경 확인'))).Count) '0/0/0|0|0/0'
# HX2 경고 판정 = 시작 게이트와 같은 술어 · 방금 적용한 배열(정적 - 주석 뺀 칸 편집 원문, GE-W 와 같은 꼴): 'Get-AbyssMatchingIssues -Items $convertedItems'
# 정확히 1. HB · HW 는 경고가 나는지를 행동으로만 보므로, 판정을 다른 배열(원래 리스트 등)이나 다른 술어로 옮기는 변경은 이 행이 잡습니다.
Assert-Case 'HX2 칸 편집 경고 판정 = 시작 게이트와 같은 함수 · 방금 적용한 배열(주석 뺀 칸 편집 원문의 호출 정확히 1)' ([regex]::Matches($hbCellEditCode, [regex]::Escape('Get-AbyssMatchingIssues -Items $convertedItems'))).Count 1
# 참고 줄(행 아님): 경고 줄 원문(실기 대조용)
if ($hbReady) {
  $info = Invoke-Hb @($solo, $chance) 0 2 '함께하기 · 파티 찾기'
  if (@($info.Log).Count -gt 1) { 'INFO 칸 편집 경고 = {0}' -f [string]@($info.Log)[1] }
}

exit $fails
