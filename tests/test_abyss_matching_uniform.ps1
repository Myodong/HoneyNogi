# 어비스 커스텀 반복 - 리스트 방식·매칭 규칙 진리표 (2026-07-22 사용자 확정 · 2026-10-26 섞기 허용 · 2026-10-27 칸 편집 그 행만 - 구현 명세 ⑤b6 1.8 · 1.9 ·
#   2026-10-28 칸 편집 막지 않음 · 시작 게이트 팝업 - 구현 명세 ⑤b7)
# 규칙: 혼자하기와 함께하기·우연한 만남은 한 리스트에 섞을 수 있고, 파티 찾기·파티(파티장)(직접 편집된 모르는 매칭 포함) 항목이 하나라도
#       있으면 리스트 전체가 첫 항목의 방식+매칭으로 고정된다(Get-AbyssListLock 의 Fixed). GUI 는 [추가] 라디오 비활성으로 막고(섞을 수 있는
#       리스트는 파티 찾기·파티장 둘만, 고정 리스트는 다섯 다), 칸 편집은 막지 않고 경고만 남기므로(test_custom_cell_edit HW) 칸 편집 · config 직접
#       편집으로 생긴 어긋난 리스트를 시작 게이트가 로그 줄 + '커스텀 반복 - 시작 불가' 팝업으로 거부한다(고정 리스트만 첫 항목 기준 - GS).
# 본체 순수 함수(Get-AbyssListLock / Get-AbyssMatchingIssues)를 AST 로 직접 불러 검사하고, 라디오 잠금(Update-AbyssInputLock)은 WinForms
# 실물 하니스로 원문 함수를 그대로 부릅니다(GR). 시작 게이트는 Invoke-StartAutomation 의 어비스 블록을 잘라 팝업만 가로채 점소싱합니다(GS -
# 실기 대조용 INFO 참고 줄 둘은 PASS 수에 들지 않음). 툴팁 문구는 GUI 최상위 대입문에서 캡처하고, 새 소스 문자열 단언은 주석 뺀 사본으로 봅니다.
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
Check-CodePattern '툴팁 문구 (2026-10-27 칸 편집 그 행만 — 일괄 안내 뺌 · 10-30 사용자 결정 3 칸에서 항목마다 바꾸는 길 · 10-31 실기 소감으로 세 줄)' `
  '리스트의 방식·매칭과 같아야 합니다\.`r`n다른 방식·매칭으로 바꾸려면 리스트의 방식·매칭 칸을 항목마다 바꾸거나,`r`n리스트를 비우고 다시 추가해 주세요\.'
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
# '게이트 위반 시 시작 거부'(탐색 창 정규식 {0,1500})는 아래 GS7(AST - 위반 if 몸통의 마지막 두 문장 · 팝업 차례)로 옮겼습니다 - 팝업 덩이가 들어와
# 거리가 1500자를 넘음(구현 명세 ⑤b7)
$gateHeadNew = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and ([string]$node.Value).StartsWith('[경고] 어비스 커스텀 반복:') }, $true))
Check-Equal 'GG 시작 게이트 머리 문구 1 · 섞기 허용 안내 포함 · 옛 통일 문구 0' ('{0}/{1}/{2}' -f $gateHeadNew.Count, @($gateHeadNew | Where-Object { ([string]$_.Value).Contains('섞어도 됩니다') }).Count,
    ([regex]::Matches($guiCode, [regex]::Escape('리스트의 방식·매칭이 서로 달라 시작할 수 없습니다'))).Count) '1/1/0'
Check-Equal 'GX2 시작 게이트 안내 - 칸 일괄 변경 안내 0 · 옛 안내(지우거나 비우고 다시 추가) 0 · 새 안내(칸을 첫 항목과 같게 바꾸거나 지운 뒤) 1' ('{0}/{1}/{2}' -f ([regex]::Matches($guiCode, [regex]::Escape('방식/매칭 칸을 클릭해 전체를 한 번에'))).Count,
    ([regex]::Matches($guiCode, [regex]::Escape("Add-GuiLog '[안내] 위 항목을 지우거나, 리스트를 비우고 다시 추가해 주세요.'"))).Count,
    ([regex]::Matches($guiCode, [regex]::Escape("Add-GuiLog '[안내] 위 항목의 방식·매칭 칸을 첫 항목과 같게 바꾸거나, 위 항목을 지운 뒤 다시 시작해 주세요.'"))).Count) '0/0/1'
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
# 2026-10-27 사용자 결정: 칸 편집은 그 행만이라 툴팁에 '칸에서 고르면 전체가 한 번에 바뀐다' 류 안내가 없어야 합니다(다른 말로 쓴 것도 낱말 둘로 잡음).
# 2026-10-28 사용자 결정으로 칸 편집을 막지 않으므로 두 문구 모두 '칸을 항목마다 바꾸기' 와 '비우고 다시 추가' 두 길을 안내합니다(10-30 사용자 결정 3 - 구현 명세 ⑤b7)
Check-Equal "GX1 툴팁 문구 둘 - '한 번에' · '전체' 0 · 둘 다 '칸을 항목마다' · 고정 문구 '리스트를 비우고 다시 추가' · 섞기 문구 '리스트를 비운 뒤 다시 추가'" ('{0}/{1}/{2}/{3}' -f @(@([string]$script:acrLockTipTextFixed, [string]$script:acrLockTipTextMixable) | Where-Object { $_.Contains('한 번에') -or $_.Contains('전체') }).Count,
    (([string]$script:acrLockTipTextFixed).Contains('칸을 항목마다') -and ([string]$script:acrLockTipTextMixable).Contains('칸을 항목마다')),
    ([string]$script:acrLockTipTextFixed).Contains('리스트를 비우고 다시 추가'), ([string]$script:acrLockTipTextMixable).Contains('리스트를 비운 뒤 다시 추가')) '0/True/True/True'
# 2026-10-31 실기 사용자 소감(한 줄로 너무 길게 뜸)으로 두 문구를 `r`n 세 줄로 나눔: 캡처한 실제 문자열을 CR LF 로 나눠 줄 수와 줄마다의 글자를 사용자에게 보여 준
# 세 줄과 정확히(-ceq) 견줍니다 - 줄을 이어 붙여 견주면 줄바꿈 하나가 다른 글자로 바뀐 꼴도 같은 값이 되므로 줄 수 · 줄 하나하나를 따로 셉니다(설계 리뷰 P3)
$tipFixedLines = @('리스트의 방식·매칭과 같아야 합니다.', '다른 방식·매칭으로 바꾸려면 리스트의 방식·매칭 칸을 항목마다 바꾸거나,', '리스트를 비우고 다시 추가해 주세요.')
$tipMixableLines = @("'파티 찾기'·'파티(파티장)'는 리스트의 모든 항목이 같은 매칭일 때만 쓸 수 있습니다.", '쓰려면 리스트의 방식·매칭 칸을 항목마다 그 매칭으로 바꾸거나,', '리스트를 비운 뒤 다시 추가해 주세요.')
function Get-TipLineMatch {
  # 문구를 CR LF 로 나눈 줄 수와, 기대 줄과 같은 자리에서 글자가 정확히 같은 줄 수를 '줄 수:같은 줄 수' 로 돌려줍니다
  param([string]$Text, [string[]]$ExpectedLines)
  $actualLines = @($Text -split "`r`n")
  $sameCount = @(0..($ExpectedLines.Count - 1) | Where-Object { ($_ -lt $actualLines.Count) -and ([string]$actualLines[$_] -ceq [string]$ExpectedLines[$_]) }).Count
  return ('{0}:{1}' -f $actualLines.Count, $sameCount)
}
Check-Equal 'GX3 툴팁 문구 둘 - CR LF 로 나눈 줄 수 · 사용자에게 보여 준 세 줄과 정확히 같은 줄 수 (고정 / 섞기)' ('{0}/{1}' -f (Get-TipLineMatch -Text ([string]$script:acrLockTipTextFixed) -ExpectedLines $tipFixedLines),
    (Get-TipLineMatch -Text ([string]$script:acrLockTipTextMixable) -ExpectedLines $tipMixableLines)) '3:3/3:3'
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
# 칸 편집으로 만들 수 있게 된 어긋난 리스트(2026-10-28 - 막지 않음)의 [추가] 라디오: 고정 갈래 · 잠금값은 첫 항목(혼자하기) - [추가] 잠금 그대로인 상태가 GUI 로 닿음
Check-Equal 'GR8 [혼자, 찾기](찾기 골라 둠 - 칸 편집으로 생김) → 다섯 다 끔 · 혼자하기로' (RadioRow @($solo, $find) 'find') '켬(혼자·함께·우연·찾기·파티장) 00000 · 고름 10010 · 잠금 1 · 툴팁 fixed'

# ----- GS: 시작 게이트 팝업 (2026-10-28 사용자 결정 '던전하고 동일하게' - 구현 명세 ⑤b7) -----
# Invoke-StartAutomation 의 어비스 블록(if ($script:customConfigSection -eq 'abyssCustomRepeat') 몸통)을 주석 뺀 사본으로 잘라, MessageBox 글자만 스텁
# 호출로 바꾼 뒤 끝에 통과 표지를 붙여 하니스 함수 Invoke-Gs 안에서 점소싱합니다(규칙 3 - 잘라낸 블록을 원래 자리처럼 호출자 스코프에서 돌림: 블록의
# 지역 대입($acrGateIssues · $acrGateLines 등)은 Invoke-Gs 의 지역 변수가 되어 함수와 함께 사라지고, 블록 안 return(시작 거부)은 블록만 끝냄 -
# test_time_until_mode T4-g 와 같은 꼴). 블록 안 $script: 대입(customActive · 통과 표지)은 & 로 돌려도 스크립트 스코프에 닿으므로 점소싱의 까닭이 아닙니다.
# 준비 검사(블록 1개 · 바꾼 뒤 남은 실제 MessageBox 호출 0 · 파서 오류 0)를 못 지나면 실제 모달 창이 떠 무인 러너가 멈추므로 GS1~GS5b 와 INFO 참고 줄을
# 부르지 않고 FAIL 한 줄(GS-준비)만 남깁니다.
$startFnAst = $guiAst.Find({ param($node) ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq 'Invoke-StartAutomation') }, $true)
$acrGateIfs = @()
if ($null -ne $startFnAst) {
  $acrGateIfs = @($startFnAst.Body.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and
        ($node.Clauses[0].Item1.Extent.Text -ceq "`$script:customConfigSection -eq 'abyssCustomRepeat'") }, $true))
}
$gsResidual = -1; $gsParseErrorCount = -1; $gsBlock = $null
if ($acrGateIfs.Count -eq 1) {
  $gsBodyText = Remove-SourceComments -Text ((@($acrGateIfs[0].Clauses[0].Item2.Statements | ForEach-Object { $_.Extent.Text })) -join "`n")
  $gsReplaced = $gsBodyText.Replace('[System.Windows.Forms.MessageBox]::Show(', '$global:gsMbStub.Show(')
  $gsTokens = $null; $gsParseErrors = $null
  $gsAst = [System.Management.Automation.Language.Parser]::ParseInput($gsReplaced, [ref]$gsTokens, [ref]$gsParseErrors)
  $gsResidual = @($gsAst.FindAll({ param($n) ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and $n.Static -and ($n.Member.Extent.Text -eq 'Show') -and
        ($n.Expression -is [System.Management.Automation.Language.TypeExpressionAst]) -and ([string]$n.Expression.TypeName.FullName -match '(^|\.)MessageBox$') }, $true)).Count
  $gsParseErrorCount = @($gsParseErrors).Count
  if (($gsResidual -eq 0) -and ($gsParseErrorCount -eq 0)) { $gsBlock = [scriptblock]::Create($gsReplaced + "`n`$script:gsPassed = `$true") }
}
$global:gsMbStub = New-Object PSObject
Add-Member -InputObject $global:gsMbStub -MemberType ScriptMethod -Name Show -Value {
  param($Text, $Caption, $Buttons, $Icon)
  [void]$global:gsMb.Add(@([string]$Text, [string]$Caption, [int]$Buttons, [int]$Icon))
  [void]$global:gsEvents.Add('mb')
  return [System.Windows.Forms.DialogResult]::OK
}
function Add-GuiLog { param([string]$Message) [void]$global:gsLog.Add($Message); [void]$global:gsEvents.Add('log') }
function Invoke-Gs {
  # 그 리스트로 어비스 게이트 블록을 돌려 통과 표지 · customActive · 로그 · 팝업 · 사건 차례를 돌려줍니다
  param([object[]]$Items)
  $global:gsMb = New-Object System.Collections.ArrayList
  $global:gsLog = New-Object System.Collections.ArrayList
  $global:gsEvents = New-Object System.Collections.ArrayList
  $script:gsPassed = $false
  $script:customActive = $true
  $script:customConfigSection = 'abyssCustomRepeat'
  $crItems = @($Items)
  . $gsBlock
  return @{ Passed = $script:gsPassed; Active = $script:customActive; Log = @($global:gsLog); Mb = @($global:gsMb); Events = (@($global:gsEvents) -join ',') }
}
function GsPopup {
  # 팝업 본문 줄: 머리 · 위반 줄('- ' 로 시작) · '외 N건' 줄 · 끝 두 줄
  param($R)
  if (@($R.Mb).Count -lt 1) { return @() }
  return @(([string]$R.Mb[0][0]) -split "`n")
}
function GsItemHeads {
  # 팝업 위반 줄('- ' 로 시작)의 머리 '- N번' 을 차례대로 쉼표로 이은 문자열 (위반 줄이 없으면 '')
  param([string[]]$Lines)
  return ((@($Lines | Where-Object { $_.StartsWith('- ') }) | ForEach-Object { ([regex]::Match($_, '^- \d+번')).Value }) -join ',')
}
function GsPopupShape {
  # 팝업 본문 줄의 차례를 낱말로 이은 문자열 (구현 명세 ⑤b7 1.7 - '외 N건' 줄은 다섯째 위반 줄 바로 뒤, 그 뒤에 빈 줄과 끝 두 줄):
  #   머리('시작할 수 없습니다' 로 시작) · 빈(빈 줄) · 위반('- ' 로 시작) · 외('... 외' 로 시작) · 기준(첫 항목 기준 줄) ·
  #   안내(같은 실행의 로그 마지막 줄에서 머리 '[안내] ' 를 뗀 글과 같음) · 그 밖은 '?'
  param($R)
  $shapeGuide = $(if (@($R.Log).Count -gt 0) { ([string]@($R.Log)[-1]) -replace '^\[안내\] ', '' } else { $null })
  $shapeWords = @(foreach ($shapeLine in @(GsPopup $R)) {
      if ($shapeLine.StartsWith('시작할 수 없습니다')) { '머리' }
      elseif ($shapeLine -ceq '') { '빈' }
      elseif ($shapeLine.StartsWith('- ')) { '위반' }
      elseif ($shapeLine.StartsWith('... 외')) { '외' }
      elseif ($shapeLine -ceq '첫 항목 기준으로 다른 항목을 표시했습니다.') { '기준' }
      elseif (($null -ne $shapeGuide) -and ($shapeLine -ceq $shapeGuide)) { '안내' }
      else { '?' }
    })
  return ($shapeWords -join ',')
}
$gsOk = [int][System.Windows.Forms.MessageBoxButtons]::OK
$gsWarning = [int][System.Windows.Forms.MessageBoxIcon]::Warning
if ($null -ne $gsBlock) {
  $gs = Invoke-Gs @($solo, $chance)
  Check-Equal 'GS1 [혼자, 우연] 섞을 수 있는 리스트 → 통과 · customActive 참 · 로그 0 · 팝업 0' ('{0}/{1}/{2}/{3}' -f $gs.Passed, $gs.Active, @($gs.Log).Count, @($gs.Mb).Count) 'True/True/0/0'
  $gs = Invoke-Gs @($solo, $chance, $find)
  Check-Equal 'GS2 [혼자, 우연, 찾기] → 거부 · customActive 거짓 · 로그 다섯 줄 뒤 팝업 하나(차례)' ('{0}/{1}/{2}/{3}/{4}' -f $gs.Passed, $gs.Active, @($gs.Log).Count, @($gs.Mb).Count, $gs.Events) 'False/False/5/1/log,log,log,log,log,mb'
  # GS2t: 팝업 위반 줄의 기대 = 같은 실행의 로그 위반 줄(로그[2] ~ 로그[위반 수 + 1] - 머리 · C-11 다음, 안내 앞)에서 머리 '[경고] ' 를 '- ' 로 바꾼 것
  # (10-30 사용자 결정 4 - 방식이 다른 위반의 이유에는 매칭이 없어, 로그 줄과 같은 꼴의 방식·매칭 괄호가 2번(우연한 만남) · 3번(파티 찾기)을 가름 -
  # 그래서 위반 줄의 번호 뒤 글자가 서로 달라야 함). 위반 수는 게이트가 쓰는 Get-AbyssMatchingIssues 로 셉니다.
  # 끝 두 줄 = 첫 항목 기준 줄 · 같은 실행의 로그 안내 줄(로그[위반 수 + 2])에서 머리 '[안내] ' 를 뗀 글 - 한쪽만 고치면 FAIL
  # 위반 줄 꼴 (구현 리뷰 반영): '팝업 = 로그' 만 보면 두 줄이 함께 방식 · 사유를 잃어도 통과하므로, 위반 객체(게이트와 같은 Get-AbyssMatchingIssues)로
  # 사용자 결정 4 의 꼴 '- N번(방식 매칭 ''X''): 이유' 를 만들어 팝업 위반 줄과도 견줍니다(꼴은 사용자가 정한 계약이라 글자로 둠 - 값은 위반 객체에서).
  $gsLines = @(GsPopup $gs)
  $gsMb0 = $(if (@($gs.Mb).Count -gt 0) { $gs.Mb[0] } else { @('', '', '', '') })
  $gsIssueObjects = @(Get-AbyssMatchingIssues -Items @($solo, $chance, $find))
  $gsIssueCount = $gsIssueObjects.Count
  $gsSpecItems = @($gsIssueObjects | ForEach-Object { '- {0}번({1} 매칭 ''{2}''): {3}' -f $_.Index, $_.Mode, $_.Matching, $_.Reason })
  $gsLogItems = @(@($gs.Log) | Select-Object -Skip 2 -First $gsIssueCount | ForEach-Object { ([string]$_) -replace '^\[경고\] ', '- ' })
  $gsPopupItems = @($gsLines | Where-Object { $_.StartsWith('- ') })
  $gsPopupTails = @($gsPopupItems | ForEach-Object { $_ -replace '^- \d+번', '' })
  $gsGuide = $(if (@($gs.Log).Count -ge ($gsIssueCount + 3)) { ([string]@($gs.Log)[$gsIssueCount + 2]) -replace '^\[안내\] ', '' } else { '?' })
  Check-Equal 'GS2t 팝업 - 제목 · 단추 · 아이콘 / 머리(고정 항목 3번) / 위반 줄 = 같은 실행의 로그 위반 줄(머리 [경고] → -) / 위반 줄 꼴 = 위반 객체로 만든 사용자 결정 4 의 꼴 / 위반 줄의 번호 뒤 글자가 서로 다름 / 끝 둘 = 첫 항목 기준 · 로그 안내 줄과 같은 글' ('{0}/{1}/{2}|{3}|{4}|{5}|{6}|{7}|{8}' -f $gsMb0[1], $gsMb0[2], $gsMb0[3],
      ([string]$gsLines[0]).StartsWith("시작할 수 없습니다 - '파티 찾기'·'파티(파티장)' 항목(3번)이 있는 리스트는 모든 항목이 같은 방식·매칭이어야"),
      (($gsPopupItems.Count -gt 0) -and (($gsPopupItems -join '¦') -ceq ($gsLogItems -join '¦'))),
      (($gsSpecItems.Count -gt 0) -and (($gsPopupItems -join '¦') -ceq ($gsSpecItems -join '¦'))),
      (($gsPopupTails.Count -ge 2) -and (@($gsPopupTails | Select-Object -Unique).Count -eq $gsPopupTails.Count)),
      ([string]$gsLines[$gsLines.Count - 2] -ceq '첫 항목 기준으로 다른 항목을 표시했습니다.'), ([string]$gsLines[$gsLines.Count - 1] -ceq $gsGuide)) ('커스텀 반복 - 시작 불가/{0}/{1}|True|True|True|True|True|True' -f $gsOk, $gsWarning)
  $gs = Invoke-Gs @($find, $lead, $solo)
  $gsLines = @(GsPopup $gs)
  Check-Equal 'GS3 [찾기, 파티장, 혼자] → 로그 C-11 줄 · 팝업 머리 모두 항목(1, 2번) · 위반 줄 2(매칭) · 3(방식)' ('{0}/{1}/{2}|{3}' -f $gs.Passed, ([string]@($gs.Log)[1]).Contains('항목(1, 2번)'), ([string]$gsLines[0]).Contains('항목(1, 2번)'),
      (GsItemHeads $gsLines)) 'False/True/True|- 2번,- 3번'
  $gs = Invoke-Gs @($find, $find)
  Check-Equal 'GS4 [찾기, 찾기] 고정 리스트 · 같은 매칭 → 통과' ('{0}/{1}/{2}/{3}' -f $gs.Passed, $gs.Active, @($gs.Log).Count, @($gs.Mb).Count) 'True/True/0/0'
  # GS5: 위반 6건 - 개수와 함께 줄 차례(11줄)를 봅니다. '외 N건' 줄은 다섯째 위반 줄 바로 뒤이고 그 뒤에 빈 줄과 끝 두 줄(구현 명세 ⑤b7 1.7 · 2.2)
  $gs = Invoke-Gs @($find, $solo, $solo, $solo, $solo, $solo, $solo)
  $gsLines = @(GsPopup $gs)
  Check-Equal 'GS5 [찾기, 혼자 ×6] 위반 6 → 로그 아홉 줄 · 팝업은 앞 5건(2~6번) + 외 1건 · 줄 차례(머리 · 빈 줄 · 위반 5 · 외 · 빈 줄 · 끝 둘 = 11줄)' ('{0}|{1}|{2}|{3}' -f @($gs.Log).Count, (GsItemHeads $gsLines),
      @($gsLines | Where-Object { $_ -ceq '... 외 1건 (로그 참고)' }).Count, (GsPopupShape $gs)) '9|- 2번,- 3번,- 4번,- 5번,- 6번|1|머리,빈,위반,위반,위반,위반,위반,외,빈,기준,안내'
  # GS5b: 위반이 정확히 5건이면 '외 N건' 줄이 없습니다 - 조건(위반 수 > 5)의 경계 (조건을 '>= 5' 로 바꾸면 '... 외 0건' 이 붙어 잡힘)
  $gs = Invoke-Gs @($find, $solo, $solo, $solo, $solo, $solo)
  $gsLines = @(GsPopup $gs)
  Check-Equal 'GS5b [찾기, 혼자 ×5] 위반 정확히 5 → 로그 여덟 줄 · 팝업 위반 줄 5건(2~6번) · ''... 외'' 로 시작하는 줄 0 · 10줄' ('{0}|{1}|{2}|{3}' -f @($gs.Log).Count, (GsItemHeads $gsLines),
      @($gsLines | Where-Object { $_.StartsWith('... 외') }).Count, $gsLines.Count) '8|- 2번,- 3번,- 4번,- 5번,- 6번|0|10'
  # 실기 대조 참고 줄 (구현 명세 ⑤b7 3절 '1-M-G 다시' ⓓ · ⓗ 의 통과 기준 - 행이 아니라 PASS 수에 들지 않음): 실기 리스트로 게이트 블록을 돌려
  # 로그 줄과 팝업 본문(줄을 ' ¦ ' 로 이음)을 소스에서 만든 글자로 찍습니다. 실제 [시작] 에서는 이 로그 줄 앞에 승인 확인 줄과 시작 안내 줄이 먼저 찍힙니다
  foreach ($gsInfoCase in @(
      @{ Name = 'ⓓ [찾기, 혼자, 혼자]'; Items = @($find, $solo, $solo) },
      @{ Name = 'ⓗ [찾기, 혼자 ×6]'; Items = @($find, $solo, $solo, $solo, $solo, $solo, $solo) })) {
    $gs = Invoke-Gs $gsInfoCase.Items
    $gsInfoPopup = @(GsPopup $gs)
    $gsInfoTitle = $(if (@($gs.Mb).Count -gt 0) { [string]$gs.Mb[0][1] } else { '(없음)' })
    Write-Host ("INFO 실기 {0} - 로그 {1}줄: {2} / 팝업 '{3}' {4}줄: {5}" -f $gsInfoCase.Name, @($gs.Log).Count, (@($gs.Log) -join ' ¦ '), $gsInfoTitle, $gsInfoPopup.Count, ($gsInfoPopup -join ' ¦ '))
  }
} else {
  Check-Equal 'GS-준비 시작 게이트 하니스 준비(어비스 블록 1 / 바꾼 뒤 남은 실제 MessageBox 호출 0 / 파서 오류 0 - GS1~GS5b · INFO 참고 줄을 부르지 않음)' ('{0}/{1}/{2}' -f $acrGateIfs.Count, $gsResidual, $gsParseErrorCount) '1/0/0'
}
# GS6 정적: '커스텀 반복 - 시작 불가' 팝업은 GUI 에 둘(커스텀 던전 · 어비스)이고 단추 · 아이콘 인자 글자가 같으며 그중 하나가 어비스 블록 안
$gsTitleShows = @($guiAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($node.Member.Extent.Text -eq 'Show') -and
      ($node.Expression.Extent.Text -eq '[System.Windows.Forms.MessageBox]') -and (@($node.Arguments).Count -ge 4) -and ($node.Arguments[1] -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and
      ([string]$node.Arguments[1].Value -ceq '커스텀 반복 - 시작 불가') }, $true))
$gsArgText = @($gsTitleShows | ForEach-Object { '{0}|{1}' -f $_.Arguments[2].Extent.Text, $_.Arguments[3].Extent.Text } | Select-Object -Unique)
$gsInAbyss = $(if ($acrGateIfs.Count -eq 1) { @($gsTitleShows | Where-Object { ($_.Extent.StartOffset -ge $acrGateIfs[0].Extent.StartOffset) -and ($_.Extent.EndOffset -le $acrGateIfs[0].Extent.EndOffset) }).Count } else { -1 })
Check-Equal 'GS6 시작 불가 팝업 둘(던전 · 어비스) · 단추 · 아이콘 인자 같음 · 어비스 블록 안 1' ('{0}/{1}/{2}' -f $gsTitleShows.Count, $gsArgText.Count, $gsInAbyss) '2/1/1'
# GS7 정적(AST - '게이트 위반 시 시작 거부' 를 대신함): 위반 if 몸통의 마지막 두 문장 = customActive 거짓 · return / Show 를 품은 문장 1 이 Add-GuiLog 를 품은 모든 문장 뒤
$gsIssueIfs = @($acrGateIfs | ForEach-Object { $_.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -ceq '$acrGateIssues.Count -gt 0') }, $true) })
$gs7 = 'n/a'
if ($gsIssueIfs.Count -eq 1) {
  $gsStmts = @($gsIssueIfs[0].Clauses[0].Item2.Statements)
  $gsLast2 = ('{0}' -f (($gsStmts.Count -ge 2) -and ($gsStmts[$gsStmts.Count - 2].Extent.Text -ceq '$script:customActive = $false') -and ($gsStmts[$gsStmts.Count - 1] -is [System.Management.Automation.Language.ReturnStatementAst])))
  $gsShowIdx = @(); $gsLogIdx = @()
  for ($si = 0; $si -lt $gsStmts.Count; $si++) {
    if (@($gsStmts[$si].FindAll({ param($n) ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($n.Member.Extent.Text -eq 'Show') }, $true)).Count -gt 0) { $gsShowIdx += $si }
    if (@($gsStmts[$si].FindAll({ param($n) ($n -is [System.Management.Automation.Language.CommandAst]) -and ([string]$n.GetCommandName() -eq 'Add-GuiLog') }, $true)).Count -gt 0) { $gsLogIdx += $si }
  }
  $gs7 = '{0}/{1}/{2}' -f $gsLast2, $gsShowIdx.Count, (($gsShowIdx.Count -eq 1) -and ($gsLogIdx.Count -gt 0) -and ($gsShowIdx[0] -gt ($gsLogIdx | Measure-Object -Maximum).Maximum))
}
Check-Equal 'GS7 위반 if 몸통 - 끝 두 문장 customActive 거짓 · return / Show 문장 1 / Show 가 모든 로그 줄 뒤' ('{0}|{1}' -f $gsIssueIfs.Count, $gs7) '1|True/1/True'

exit $fails
