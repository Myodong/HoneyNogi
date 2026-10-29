# 어비스 커스텀 반복 - 리스트 방식·매칭 규칙 진리표 (2026-07-22 사용자 확정 · 2026-10-26 섞기 허용 · 2026-10-27 칸 편집 그 행만 - 구현 명세 ⑤b6 1.8 · 1.9)
# 규칙: 혼자하기와 함께하기·우연한 만남은 한 리스트에 섞을 수 있고, 파티 찾기·파티(파티장)(직접 편집된 모르는 매칭 포함) 항목이 하나라도
#       있으면 리스트 전체가 첫 항목의 방식+매칭으로 고정된다(Get-AbyssListLock 의 Fixed). GUI 는 라디오 비활성으로 막고(섞을 수 있는
#       리스트는 파티 찾기·파티장 둘만, 고정 리스트는 다섯 다), config 직접 편집 대비로 시작 게이트에서 한 번 더 검사한다(고정 리스트만 첫 항목 기준).
# 본체 순수 함수(Get-AbyssListLock / Get-AbyssMatchingIssues)를 AST 로 직접 불러 검사하고, 라디오 잠금(Update-AbyssInputLock)은 WinForms
# 실물 하니스로 원문 함수를 그대로 부릅니다(GR). 툴팁 문구는 GUI 최상위 대입문에서 캡처하고, 새 소스 문자열 단언은 주석 뺀 사본으로 봅니다.
$fails = 0

$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path $guiPath `
    -Names @('Get-AbyssListLock', 'Get-AbyssMatchingIssues')) {
  Invoke-Expression $definition
}
# 시작 게이트 [경고] 한 줄의 번호 함수(구현 명세 ⑤b6 C-11 · B-14 둘째 안)는 따로 올립니다 - 옛 GUI 에 없으면 파일 전체가 아니라 GW 행만 FAIL
try {
  Invoke-Expression (Get-SourceFunctionDefinitions -Path $guiPath -Names @('Get-AbyssFixedItemNumbers'))
} catch {
  Write-Host ("INFO Get-AbyssFixedItemNumbers 를 올리지 못했습니다: {0}" -f $_.Exception.Message)
}

function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ([string]$Actual -eq [string]$Expected) {
    Write-Host ("PASS {0} (= '{1}')" -f $Name, $Actual)
  } else {
    Write-Host ("FAIL {0}: got '{1}' expected '{2}'" -f $Name, $Actual, $Expected)
    $script:fails++
  }
}

function NewAcr([string]$mode, [string]$matching) {
  [pscustomobject]@{ kind = 'abyss'; mode = $mode; difficulty = '어려움'
    dungeon = '허상의 정박지'; matching = $matching }
}

function LockText($items) {
  $lock = Get-AbyssListLock -Items $items
  if ($null -eq $lock) { return 'none' }
  return ('{0}/{1}' -f $lock.Mode, $lock.Matching)
}

function IssueIndexes($items) {
  # 위반 항목 번호를 순서대로 이은 문자열 (없으면 '')
  return ((@(Get-AbyssMatchingIssues -Items $items) | ForEach-Object { [string]$_.Index }) -join ',')
}

$solo = NewAcr 'solo' '없음'
$chance = NewAcr 'party' '우연한 만남'
$find = NewAcr 'party' '파티 찾기'
$lead = NewAcr 'party' '파티(파티장)'
$member = NewAcr 'party' '파티(파티원)'   # GUI 가 만들지 않는 모르는 매칭(직접 편집) - 고정으로 봄

# ----- Get-AbyssListLock 진리표 -----
Check-Equal 'lock-빈 리스트' (LockText @()) 'none'
Check-Equal 'lock-null만 든 리스트' (LockText @($null, $null)) 'none'
Check-Equal 'lock-혼자하기 1개' (LockText @($solo)) 'solo/없음'
Check-Equal 'lock-혼자하기만' (LockText @($solo, $solo)) 'solo/없음'
Check-Equal 'lock-함께하기+우연한 만남' (LockText @($chance, $chance)) 'party/우연한 만남'
Check-Equal 'lock-함께하기+파티 찾기' (LockText @($find, $find)) 'party/파티 찾기'
Check-Equal 'lock-함께하기+파티장' (LockText @($lead)) 'party/파티(파티장)'
# 첫 항목 기준 - 뒤가 달라도 잠금값은 첫 항목의 것
Check-Equal 'lock-첫 항목 기준' (LockText @($find, $solo, $chance)) 'party/파티 찾기'
# config 직접 편집 표기 흔들림 정규화 (공백 없는 '파티찾기', 한글 방식명)
Check-Equal 'lock-공백 없는 파티찾기 정규화' (LockText @((NewAcr 'party' '파티찾기'))) 'party/파티 찾기'
Check-Equal 'lock-한글 방식명 party 정규화' (LockText @((NewAcr '함께하기' '우연한 만남'))) 'party/우연한 만남'
# 혼자하기 항목에 매칭이 잘못 적혀 있어도 '없음'으로 본다
Check-Equal 'lock-혼자하기 매칭 무시' (LockText @((NewAcr 'solo' '파티 찾기'))) 'solo/없음'

# ----- GL: Get-AbyssListLock 의 Fixed (전체 고정 리스트인가 - 2026-10-26 섞기 허용, 구현 명세 ⑤b6 1.9) -----
# 출력 = 방식/매칭/Fixed. 함께하기인데 매칭(공백 무시)이 우연한 만남이 아닌 항목이 하나라도 있으면 고정 - 방식·매칭은 지금처럼 첫 항목 값
function LockRow($items) {
  $lock = Get-AbyssListLock -Items $items
  if ($null -eq $lock) { return 'none' }
  return ('{0}/{1}/{2}' -f $lock.Mode, $lock.Matching, $lock.Fixed)
}
Check-Equal 'GL1 빈 리스트' (LockRow @()) 'none'
Check-Equal 'GL2 [혼자]' (LockRow @($solo)) 'solo/없음/False'
Check-Equal 'GL3 [우연]' (LockRow @($chance)) 'party/우연한 만남/False'
Check-Equal 'GL4 [혼자, 우연] 섞을 수 있는 리스트' (LockRow @($solo, $chance)) 'solo/없음/False'
Check-Equal 'GL5 [찾기]' (LockRow @($find)) 'party/파티 찾기/True'
Check-Equal 'GL6 [파티장]' (LockRow @($lead)) 'party/파티(파티장)/True'
Check-Equal 'GL7 [혼자, 찾기](직접 편집) - 찾기가 있으면 고정 · 잠금값은 첫 항목' (LockRow @($solo, $find)) 'solo/없음/True'
Check-Equal 'GL8 [공백 없는 파티찾기]' (LockRow @((NewAcr 'party' '파티찾기'))) 'party/파티 찾기/True'
Check-Equal 'GL9 [모르는 매칭 파티원] - 우연 정규화 그대로 · 고정' (LockRow @($member)) 'party/우연한 만남/True'
Check-Equal 'GL10 [혼자하기 항목의 매칭이 파티 찾기로 적힘] - 혼자하기라 고정 아님' (LockRow @((NewAcr 'solo' '파티 찾기'))) 'solo/없음/False'
Check-Equal 'GL11 [공백 없는 우연한만남](직접 편집) - 공백 무시로 우연한 만남 · 고정 아님' (LockRow @((NewAcr 'party' '우연한만남'))) 'party/우연한 만남/False'

# ----- Get-AbyssMatchingIssues 진리표 -----
Check-Equal 'issue-빈 리스트' (IssueIndexes @()) ''
Check-Equal 'issue-항목 1개' (IssueIndexes @($chance)) ''
Check-Equal 'issue-혼자하기만' (IssueIndexes @($solo, $solo, $solo)) ''
Check-Equal 'issue-함께하기+우연한 만남만' (IssueIndexes @($chance, $chance)) ''
Check-Equal 'issue-함께하기+파티찾기만' (IssueIndexes @($find, $find, $find)) ''
Check-Equal 'issue-표기만 다른 파티찾기는 위반 아님' (IssueIndexes @($find, (NewAcr 'party' '파티찾기'))) ''
# 혼자하기 ↔ 함께하기·우연한 만남 혼합은 2026-10-26 사용자 결정으로 섞기 허용 - 위반 아님 (옛 기대 '2' · '3')
Check-Equal 'issue-방식 혼합(2번) - 섞기 허용으로 위반 없음' (IssueIndexes @($solo, $chance)) ''
Check-Equal 'issue-방식 혼합(3번) - 섞기 허용으로 위반 없음' (IssueIndexes @($chance, $chance, $solo)) ''
Check-Equal 'issue-매칭 혼합(2번)' (IssueIndexes @($chance, $find)) '2'
Check-Equal 'issue-매칭 혼합 다중(2,4번)' (IssueIndexes @($chance, $lead, $chance, $find)) '2,4'
Check-Equal 'issue-혼자하기 리스트에 함께하기 삽입(2,3번)' (IssueIndexes @($solo, $find, $chance)) '2,3'

# ----- GM: 시작 게이트 - 섞을 수 있는 리스트는 위반 0, 고정 리스트(파티 찾기·파티장·모르는 매칭)만 첫 항목 기준 검사 -----
Check-Equal 'GM1 [우연, 우연, 혼자] 위반 없음' (IssueIndexes @($chance, $chance, $solo)) ''
Check-Equal 'GM2 [혼자, 우연, 혼자, 우연] 위반 없음' (IssueIndexes @($solo, $chance, $solo, $chance)) ''
Check-Equal 'GM3 [혼자, 우연, 찾기] → 2,3(찾기가 있으면 고정 · 기준 첫 항목)' (IssueIndexes @($solo, $chance, $find)) '2,3'
Check-Equal 'GM4 [찾기, 우연] → 2' (IssueIndexes @($find, $chance)) '2'
Check-Equal 'GM5 [찾기, 혼자] → 2' (IssueIndexes @($find, $solo)) '2'
Check-Equal 'GM6 [파티장, 파티장] 위반 없음' (IssueIndexes @($lead, $lead)) ''
Check-Equal 'GM7 [우연, 파티장, 우연, 찾기] → 2,4(지금 행 그대로)' (IssueIndexes @($chance, $lead, $chance, $find)) '2,4'
Check-Equal 'GM8 [혼자, 파티원(모르는 값)] → 2(지금처럼 거부)' (IssueIndexes @($solo, $member)) '2'
Check-Equal 'GM9 [찾기, 파티장] → 2' (IssueIndexes @($find, $lead)) '2'
Check-Equal 'GM10 [혼자, 우연한만남(직접 편집)] 위반 없음(섞을 수 있는 리스트)' (IssueIndexes @($solo, (NewAcr 'party' '우연한만남'))) ''

# ----- GW: 시작 게이트 [경고] 한 줄의 번호 - 리스트를 고정으로 만든 항목(구현 명세 ⑤b6 C-11 · B-14 둘째 안, 2026-10-27 명세 리뷰 2 선택) -----
function FixedNumbers($items) {
  # 고정을 만드는 항목 번호를 순서대로 이은 문자열 (없으면 '', 함수가 없으면 '함수 없음')
  if (-not (Get-Command Get-AbyssFixedItemNumbers -ErrorAction SilentlyContinue)) { return '함수 없음' }
  return ((@(Get-AbyssFixedItemNumbers -Items $items) | ForEach-Object { [string]$_ }) -join ',')
}
Check-Equal 'GW1 [혼자, 우연] 섞을 수 있는 리스트 → 번호 없음' (FixedNumbers @($solo, $chance)) ''
Check-Equal 'GW2 [혼자, 우연, 찾기](직접 편집) → 3' (FixedNumbers @($solo, $chance, $find)) '3'
Check-Equal 'GW3 [찾기, 파티장, 혼자] → 1,2' (FixedNumbers @($find, $lead, $solo)) '1,2'
Check-Equal 'GW4 [혼자, 파티원(모르는 값)] → 2(Fixed 와 같은 판정)' (FixedNumbers @($solo, $member)) '2'
Check-Equal 'GW5 [우연한만남(공백 없음), 혼자하기 항목의 매칭이 파티 찾기로 적힘] → 번호 없음' (FixedNumbers @((NewAcr 'party' '우연한만남'), (NewAcr 'solo' '파티 찾기'))) ''
Check-Equal 'GW6 [null, 혼자, 찾기] → 2(null 을 뺀 순번 - 위반 번호와 같은 기준)' ('{0}/{1}' -f (FixedNumbers @($null, $solo, $find)), (IssueIndexes @($null, $solo, $find))) '2/2'
# 번호가 하나라도 있음 ⇔ Get-AbyssListLock 의 Fixed (같은 판정을 두 함수가 따로 들고 있어 어긋나면 게이트 문구가 거짓이 됨)
$gwLists = @(@($solo), @($chance), @($find), @($lead), @($member), @($solo, $chance), @($solo, $find), @($chance, $lead),
  @((NewAcr 'party' '우연한만남')), @((NewAcr 'party' '파티찾기')), @((NewAcr 'solo' '파티 찾기')), @((NewAcr '함께하기' '파티 찾기')))
$gwMismatch = 0
foreach ($gwList in $gwLists) {
  $gwHas = $(if (Get-Command Get-AbyssFixedItemNumbers -ErrorAction SilentlyContinue) { @(Get-AbyssFixedItemNumbers -Items $gwList).Count -gt 0 } else { $null })
  if ($gwHas -ne [bool](Get-AbyssListLock -Items $gwList).Fixed) { $gwMismatch++ }
}
Check-Equal ('GW7 번호가 있음 ⇔ Get-AbyssListLock 의 Fixed ({0} 리스트)' -f $gwLists.Count) $gwMismatch 0

# 위반 항목의 번호·사유 문구 (게이트 로그에 그대로 실리는 값)
$mixIssues = @(Get-AbyssMatchingIssues -Items @($solo, $find))
Check-Equal 'issue-방식 위반 건수' $mixIssues.Count 1
Check-Equal 'issue-방식 위반 번호' $mixIssues[0].Index 2
Check-Equal 'issue-방식 위반 방식표기' $mixIssues[0].Mode '함께하기'
Check-Equal 'issue-방식 위반 사유' $mixIssues[0].Reason "리스트의 방식은 '혼자하기'인데 이 항목은 '함께하기'입니다"

$matchIssues = @(Get-AbyssMatchingIssues -Items @($chance, $lead))
Check-Equal 'issue-매칭 위반 번호' $matchIssues[0].Index 2
Check-Equal 'issue-매칭 위반 매칭표기' $matchIssues[0].Matching '파티(파티장)'
Check-Equal 'issue-매칭 위반 사유' $matchIssues[0].Reason "리스트의 매칭은 '우연한 만남'인데 이 항목은 '파티(파티장)'입니다"

# ----- GUI 배선 검사 (라디오 잠금·툴팁·갱신 시점·시작 게이트) -----
$gui = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
function Check-Pattern {
  param([string]$Name, [string]$Pattern)
  if ($gui -match $Pattern) { Write-Host ("PASS {0}" -f $Name) }
  else { Write-Host ("FAIL {0}" -f $Name); $script:fails++ }
}
# 2026-10-26 섞기 허용 · 2026-10-27 칸 편집 그 행만(구현 명세 ⑤b6 3.2) 뒤의 새 단언은 주석 뺀 사본으로 봅니다(주석에만 걸리는 단언 방지)
$guiCode = Remove-SourceComments -Text $gui
$guiTokens = $null; $guiErrors = $null
$guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$guiTokens, [ref]$guiErrors)
function Check-CodePattern {
  param([string]$Name, [string]$Pattern)
  if ($guiCode -match $Pattern) { Write-Host ("PASS {0}" -f $Name) }
  else { Write-Host ("FAIL {0}" -f $Name); $script:fails++ }
}
function Get-GuiFunctionCode {
  # GUI 함수 하나의 주석 뺀 원문 (없으면 빈 문자열)
  param([string]$FunctionName)
  $fnAst = $guiAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq $FunctionName) }, $true)
  if ($null -eq $fnAst) { return '' }
  return (Remove-SourceComments -Text $fnAst.Extent.Text)
}

# 혼자하기·함께하기·우연한 만남은 고정 리스트에서만, 파티 찾기·파티장은 리스트에 항목이 있으면 잠급니다 (2026-10-26 섞기 허용)
Check-CodePattern '방식·매칭 라디오 Enabled 잠금(혼자·함께·우연 = 고정 리스트만 · 찾기·파티장 = 항목이 있으면)' `
  '\$rbAcrSolo\.Enabled\s*=\s*-not \$acrFixed[\s\S]{0,300}\$rbAcrParty\.Enabled\s*=\s*-not \$acrFixed[\s\S]{0,300}\$rbAcrChance\.Enabled\s*=\s*-not \$acrFixed[\s\S]{0,300}\$rbAcrFindParty\.Enabled\s*=\s*-not \$acrLockOn[\s\S]{0,300}\$rbAcrPartyLead\.Enabled\s*=\s*-not \$acrLockOn'
$inputLockCode = Get-GuiFunctionCode -FunctionName 'Update-AbyssInputLock'
Check-Equal '고정 판정 한 줄(Update-AbyssInputLock - $acrFixed = 잠금 켬 그리고 리스트 Fixed)' `
  ([regex]::Matches($inputLockCode, [regex]::Escape('$acrFixed = ($acrLockOn -and [bool]$acrLock.Fixed)')).Count) 1
Check-Equal '툴팁 고름 한 줄(Update-AbyssInputLock - 고정 리스트 = 고정 문구 · 그 밖 = 섞기 문구)' `
  ([regex]::Matches($inputLockCode, [regex]::Escape('$script:acrLockTipText = $(if ($acrFixed) { $script:acrLockTipTextFixed } else { $script:acrLockTipTextMixable })')).Count) 1
Check-Equal '게이트 Fixed 조기 반환 한 줄(Get-AbyssMatchingIssues - 섞을 수 있는 리스트는 위반 0)' `
  ([regex]::Matches((Get-GuiFunctionCode -FunctionName 'Get-AbyssMatchingIssues'), [regex]::Escape('if (-not [bool]$amLock.Fixed) { return $issues }')).Count) 1
Check-Equal 'GT 잠긴 라디오 위 툴팁은 고른 문구를 띄움' ([regex]::Matches($guiCode, [regex]::Escape('$toolTip.Show($script:acrLockTipText, $tipSender')).Count) 1
Check-Pattern '잠글 때 리스트 값으로 라디오 Checked 보정' `
  '\$acrLock\.Mode -eq ''party''[\s\S]{0,600}\$rbAcrFindParty\.Checked = \$true[\s\S]{0,400}\$rbAcrPartyLead\.Checked = \$true'
Check-Pattern '라디오 보정 시 저장 이벤트 가드 사용' `
  'function Update-AbyssInputLock[\s\S]{0,900}\$script:crLoading = \$true'
Check-Pattern '재진입 가드' `
  'function Update-AbyssInputLock[\s\S]{0,600}if \(\$script:acrLockUpdating\) \{ return \}'
Check-Pattern '잠금 상태를 툴팁 판정용으로 보관' `
  '\$script:acrLockOn = \$acrLockOn'
Check-Pattern '잠긴 라디오 위 툴팁 - 패널 MouseMove 로 직접 판정' `
  '\$tipCtl -is \[System\.Windows\.Forms\.RadioButton\][\s\S]{0,120}-not \$tipCtl\.Enabled[\s\S]{0,120}\$tipCtl\.Bounds\.Contains'
Check-Pattern '같은 컨트롤에서 툴팁 재호출 안 함 (깜박임 방지)' `
  'if \(\$script:acrTipShownFor -ne \$tipHit\)[\s\S]{0,200}\$toolTip\.Show\('
Check-Pattern '패널 이탈 시 툴팁 숨김' `
  'Add_MouseLeave\(\$acrLockTipLeave\)'
Check-CodePattern '툴팁 문구 (2026-10-27 칸 편집 그 행만 — 일괄 안내 뺌)' `
  '리스트의 방식·매칭과 같아야 합니다\. 다른 방식·매칭으로 바꾸려면 리스트를 비우고 다시 추가해 주세요\.'
Check-Pattern '추가 후 잠금 갱신' `
  '\$btnAcrAdd\.Add_Click\(\{[\s\S]{0,900}Update-AbyssInputLock'
Check-Pattern '삭제 후 잠금 갱신' `
  '\$btnAcrDelete\.Add_Click\(\{[\s\S]{0,900}Update-AbyssInputLock'
Check-Pattern '이동 후 잠금 갱신' `
  'function Move-AbyssCustomListRow[\s\S]{0,900}Update-AbyssInputLock'
Check-Pattern '설정 복원 후 잠금 갱신' `
  'function Load-SettingsToUi[\s\S]{0,60000}Update-AbyssInputLock'
Check-Pattern '카테고리·모드 전환 후 잠금 갱신' `
  '\$updateCategoryPanels = \{[\s\S]{0,20000}Update-AbyssInputLock[\s\S]{0,20}\}'   # v2.0.0 생활 분기 추가로 블록이 길어짐 - 탐색 창 확대
Check-Pattern '시작 게이트에서 어비스 방식·매칭 규칙 검사' `
  'abyssCustomRepeat''\s*\)\s*\{\s*\r?\n\s*\$acrGateIssues = @\(Get-AbyssMatchingIssues -Items \$crItems\)'
Check-Pattern '게이트 위반 시 시작 거부' `
  '\$acrGateIssues\.Count -gt 0[\s\S]{0,1500}\$script:customActive = \$false[\s\S]{0,40}return'   # ⑤b6 C-11 [경고] 한 줄(주석 포함 약 420자)이 더해져 탐색 창 확대
$gateHeadNew = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and ([string]$node.Value).StartsWith('[경고] 어비스 커스텀 반복:') }, $true))
Check-Equal 'GG 시작 게이트 머리 문구 1 · 섞기 허용 안내 포함 · 옛 통일 문구 0' ('{0}/{1}/{2}' -f $gateHeadNew.Count, @($gateHeadNew | Where-Object { ([string]$_.Value).Contains('섞어도 됩니다') }).Count,
    ([regex]::Matches($guiCode, [regex]::Escape('리스트의 방식·매칭이 서로 달라 시작할 수 없습니다'))).Count) '1/1/0'
Check-Equal 'GX2 시작 게이트 안내 - 칸 일괄 변경 안내 0 · 위 항목을 지우거나 비우고 다시 추가 1' ('{0}/{1}' -f ([regex]::Matches($guiCode, [regex]::Escape('방식/매칭 칸을 클릭해 전체를 한 번에'))).Count,
    ([regex]::Matches($guiCode, [regex]::Escape("Add-GuiLog '[안내] 위 항목을 지우거나, 리스트를 비우고 다시 추가해 주세요.'"))).Count) '0/1'
# 게이트 [경고] 한 줄(구현 명세 ⑤b6 C-11 · B-14 둘째 안): 형식 문자열 1개 · 번호 3 을 넣은 글자가 명세 문안과 같고, 머리 문구 → 번호 → 한 줄 → 위반 줄 반복 순서
$gwFormatNodes = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and ([string]$node.Value).StartsWith('[경고] 이 리스트에는 ') }, $true))
$gwRendered = $(if ($gwFormatNodes.Count -eq 1) { ([string]$gwFormatNodes[0].Value) -f '3' } else { '' })
Check-Equal 'GW8 [경고] 한 줄 형식 1개 · 번호 3 을 넣은 글자 = 명세 B-14 둘째 안' ('{0}/{1}' -f $gwFormatNodes.Count, $gwRendered) `
  "1/[경고] 이 리스트에는 '파티 찾기'·'파티(파티장)' 항목(3번)이 있어 모든 항목이 같은 방식·매칭이어야 합니다 (첫 항목 기준으로 다른 항목을 표시합니다)."
Check-CodePattern 'GW9 게이트 순서 - 머리 문구 → 고정 항목 번호 → [경고] 한 줄(번호를 '', '' 로 이음) → 위반 줄 반복' `
  '섞어도 됩니다\)\."\s*\r?\n\s*\$acrGateFixedNumbers = @\(Get-AbyssFixedItemNumbers -Items \$crItems\)\s*\r?\n\s*Add-GuiLog \("\[경고\] 이 리스트에는 [^\r\n]*" -f \(\$acrGateFixedNumbers -join '', ''\)\)\s*\r?\n\s*foreach \(\$acrGateIssue in \$acrGateIssues\)'

# ----- GR: 라디오 잠금 실물 하니스 (2026-10-26 섞기 허용 - Update-AbyssInputLock 원문을 WinForms 라디오·패널·툴팁 실물로 부름) -----
# 툴팁 문구 둘 캡처: GUI 최상위 대입문(함수·스크립트 블록 밖)을 원문 그대로 실행해 고정·섞기 문구와 지금 문구 변수를 만듭니다
$tipAssignNames = @('$script:acrLockTipTextFixed', '$script:acrLockTipTextMixable', '$script:acrLockTipText')
$tipAssigns = @($guiAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] }, $false) |
    Where-Object { $tipAssignNames -contains $_.Left.Extent.Text })
foreach ($tipAssign in $tipAssigns) { Invoke-Expression $tipAssign.Extent.Text }
Check-Equal '툴팁 문구 둘 캡처 - GUI 최상위 대입문의 고정 · 섞기 문구(둘 다 있고 서로 다름)' ('{0}/{1}' -f @($tipAssigns | Where-Object { $_.Left.Extent.Text -ne '$script:acrLockTipText' }).Count,
    ((-not [string]::IsNullOrEmpty([string]$script:acrLockTipTextFixed)) -and (-not [string]::IsNullOrEmpty([string]$script:acrLockTipTextMixable)) -and
      ([string]$script:acrLockTipTextFixed -cne [string]$script:acrLockTipTextMixable))) '2/True'
# 2026-10-27 사용자 결정: 칸 편집은 그 행만 · 어긋나면 알림이라 툴팁에 '칸에서 고르면 전체가 한 번에 바뀐다' 류 안내가 없어야 합니다(다른 말로 쓴 것도 낱말 셋으로 잡음)
Check-Equal "GX1 툴팁 문구 둘 - '한 번에' · '전체' · '칸' 0 · 고정 문구 '리스트를 비우고 다시 추가' · 섞기 문구 '리스트를 비운 뒤 다시 추가'" ('{0}/{1}/{2}' -f @(@([string]$script:acrLockTipTextFixed, [string]$script:acrLockTipTextMixable) | Where-Object { $_.Contains('한 번에') -or $_.Contains('전체') -or $_.Contains('칸') }).Count,
    ([string]$script:acrLockTipTextFixed).Contains('리스트를 비우고 다시 추가'), ([string]$script:acrLockTipTextMixable).Contains('리스트를 비운 뒤 다시 추가')) '0/True/True'
# 하니스: 패널 둘(방식 · 매칭)에 라디오 다섯 실물, 리스트 읽기는 스텁(이 행의 항목), 툴팁 실물 - 함수는 원문 그대로 정의
Add-Type -AssemblyName System.Windows.Forms
$inputLockFn = $guiAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq 'Update-AbyssInputLock') }, $true)
Invoke-Expression $inputLockFn.Extent.Text
$pnlAcrInput = New-Object System.Windows.Forms.Panel
$pnlAcrMatching = New-Object System.Windows.Forms.Panel
$rbAcrSolo = New-Object System.Windows.Forms.RadioButton
$rbAcrParty = New-Object System.Windows.Forms.RadioButton
$rbAcrChance = New-Object System.Windows.Forms.RadioButton
$rbAcrFindParty = New-Object System.Windows.Forms.RadioButton
$rbAcrPartyLead = New-Object System.Windows.Forms.RadioButton
$pnlAcrInput.Controls.AddRange(@($rbAcrSolo, $rbAcrParty))
$pnlAcrMatching.Controls.AddRange(@($rbAcrChance, $rbAcrFindParty, $rbAcrPartyLead))
$toolTip = New-Object System.Windows.Forms.ToolTip
$script:crLoading = $false
$script:acrLockUpdating = $false
$script:acrTipShownFor = $null
$script:harnessItems = @()
function Get-AbyssCustomItemsFromList { return $script:harnessItems }
function RadioRow {
  # 미리 고른 라디오(Preset) + 리스트 항목 → 원문 Update-AbyssInputLock → 켬(Enabled 다섯) · 고름(Checked 다섯) · 잠금 · 툴팁(캡처한 문구 중 어느 것인지)
  param($Items, [string]$Preset)
  foreach ($rb in @($rbAcrSolo, $rbAcrParty, $rbAcrChance, $rbAcrFindParty, $rbAcrPartyLead)) { $rb.Enabled = $true }
  switch ($Preset) {
    'solo' { $rbAcrSolo.Checked = $true; $rbAcrChance.Checked = $true }
    'chance' { $rbAcrParty.Checked = $true; $rbAcrChance.Checked = $true }
    'find' { $rbAcrParty.Checked = $true; $rbAcrFindParty.Checked = $true }
    'lead' { $rbAcrParty.Checked = $true; $rbAcrPartyLead.Checked = $true }
  }
  $script:harnessItems = @($Items)
  $script:acrLockTipText = 'unset'
  Update-AbyssInputLock
  $enabled = (@($rbAcrSolo, $rbAcrParty, $rbAcrChance, $rbAcrFindParty, $rbAcrPartyLead) | ForEach-Object { [int]$_.Enabled }) -join ''
  $checked = (@($rbAcrSolo, $rbAcrParty, $rbAcrChance, $rbAcrFindParty, $rbAcrPartyLead) | ForEach-Object { [int]$_.Checked }) -join ''
  $tip = $(if (($null -ne $script:acrLockTipTextMixable) -and ([string]$script:acrLockTipText -ceq [string]$script:acrLockTipTextMixable)) { 'mixable' }
    elseif (($null -ne $script:acrLockTipTextFixed) -and ([string]$script:acrLockTipText -ceq [string]$script:acrLockTipTextFixed)) { 'fixed' } else { [string]$script:acrLockTipText })
  return ('켬(혼자·함께·우연·찾기·파티장) {0} · 고름 {1} · 잠금 {2} · 툴팁 {3}' -f $enabled, $checked, [int][bool]$script:acrLockOn, $tip)
}
Check-Equal 'GR1 빈 리스트(찾기 골라 둠) → 다섯 다 켬 · 고름 그대로' (RadioRow @() 'find') '켬(혼자·함께·우연·찾기·파티장) 11111 · 고름 01010 · 잠금 0 · 툴팁 mixable'
Check-Equal 'GR2 [혼자](찾기 골라 둠) → 찾기 · 파티장만 끔 · 우연으로' (RadioRow @($solo) 'find') '켬(혼자·함께·우연·찾기·파티장) 11100 · 고름 01100 · 잠금 1 · 툴팁 mixable'
Check-Equal 'GR3 [혼자, 우연](혼자 골라 둠) → 찾기 · 파티장만 끔 · 고름 그대로' (RadioRow @($solo, $chance) 'solo') '켬(혼자·함께·우연·찾기·파티장) 11100 · 고름 10100 · 잠금 1 · 툴팁 mixable'
Check-Equal 'GR4 [우연](파티장 골라 둠) → 우연으로' (RadioRow @($chance) 'lead') '켬(혼자·함께·우연·찾기·파티장) 11100 · 고름 01100 · 잠금 1 · 툴팁 mixable'
Check-Equal 'GR5 [찾기, 찾기](혼자 골라 둠) → 다섯 다 끔 · 함께+찾기로' (RadioRow @($find, $find) 'solo') '켬(혼자·함께·우연·찾기·파티장) 00000 · 고름 01010 · 잠금 1 · 툴팁 fixed'
Check-Equal 'GR6 [파티장](우연 골라 둠) → 다섯 다 끔 · 함께+파티장으로' (RadioRow @($lead) 'chance') '켬(혼자·함께·우연·찾기·파티장) 00000 · 고름 01001 · 잠금 1 · 툴팁 fixed'
# 고정 리스트의 모르는 매칭(직접 편집 '파티(파티원)')은 우연한 만남으로 정규화돼 우연 보정 else 갈래를 탐 (2026-10-28 구현 리뷰 B 지적 - 검토 변이 S4 생존)
Check-Equal 'GR7 [파티원(모르는 값)](찾기 골라 둠) → 다섯 다 끔 · 함께+우연으로(고정 갈래의 우연 보정)' (RadioRow @($member) 'find') '켬(혼자·함께·우연·찾기·파티장) 00000 · 고름 01100 · 잠금 1 · 툴팁 fixed'

exit $fails
