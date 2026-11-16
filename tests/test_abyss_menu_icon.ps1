# ESC 메뉴 '어비스' 아이콘 폴백 진리표·배선 (2026-10 - 설계 v2 10.2 B1~B12·C1~C5, 설계 리뷰 ①·② 합의)
#
# 실사고 4건(09-15 타 PC 네이티브 1908 '어H|스' / 10-01 17:31·10-02 15:52·17:14 개발 PC RDP 150% → 콘솔 전환 뒤 '어HI스'): ESC 메뉴의
# '어비스' 글자가 렌더 이상으로 깨져 한 메뉴에서 글자 탐색이 끝까지 실패 → 60초 마감 → 코드 1. 복귀 루프 메뉴 분기는 글자로 먼저 찾고,
# 글자가 유효한 캡처로 실패하고 그 회전의 메뉴 판정이 2차 신호 '게임 종료' 만으로 참일 때만(D-R) 아이콘 그림으로 찾습니다.
# 여기서 고정하는 계약:
#   B1  상수: ① 계약값 고정 24/33/0.80/0.20/0.91 (의도된 걸림 장치 - 바꾸려면 설계 재합의) ② 측정 분리 (경계 숫자는 측정값)
#   B2  메뉴 분기 순서 = 출처 없는 메뉴 닫기 < 신호 스냅숏 < 글자 탐색 < 가드#1 < D-R 조건 < 아이콘 < 가드#2 < 미발견 < 전면 < 클릭,
#       아이콘 호출 워커 전체 1곳, 클릭 1개, 고정 좌표 0, 클릭 출처 변수('글자 탐색'/'아이콘 탐색') 대입 자리
#   B3  메뉴 판정·알려진 화면·이벤트 정리에 아이콘 0        B4 캡처 입구 = Get-GameRegionCapture($rgAbyssMenu, -Scale 1) 1회 (+ 행동)
#   B5  새 함수 6개에 양보·클릭·키·전면·커서 대피 0          B6 매칭 형은 시작 Add-Type 하나(조건·반복·함수 밖), 형 리터럴은 새 함수 안 3곳
#   B7  템플릿 준비 = 한 번만·실패를 삼키지 않음              B8 수락 진리표(고정 경계값)      B9 클릭점 환산(탐지와 같은 환산 왕복)
#   B10 합성 진리표(워커 base64 해독본)                       B11 진단 꼬리 배선(판정 미사용)  B12 메뉴 판정 신호 진리표(로그 실측 판독문)
#   C1~C5 저장 캡처 재생 - 던전이미지\ 가 없으면 C 단 전체 SKIP, 있는데 목록 파일이 없으면 FAIL, ko OCR 엔진이 없으면 C3 만 SKIP
# 셋업(설계 10.2): 시작 Add-Type 원문을 인자 추가 없이 실행(운영과 같은 명령 - PS 5.1 의 경고=오류도 함께), 상수·영역·표 대입문은 소스
# AST 에서 실행, 함수는 소스에서 추출(사본 금지), 캡처는 저장 PNG 재생 모의(정확 잘라내기 + HighQualityBicubic - 워커 Get-GameRegionCapture 와
# 같은 환산이고 창 원점이 0,0 이라 화면 좌표 = 이미지 px).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing
$invariant = [Globalization.CultureInfo]::InvariantCulture
$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
function Check-True {
  param([string]$Name, [bool]$Condition, [string]$Detail)
  if ($Condition) { "OK   $Name" }
  else { "FAIL $Name ($Detail)"; $script:fails++ }
}

# ── 소스: 한 번 파싱해 AST 와 주석 뺀 사본을 같은 오프셋으로 씁니다 (Remove-SourceComments 는 주석을 같은 길이 공백으로 바꿈) ──
$workerText = [IO.File]::ReadAllText($workerPath)
$workerTokens = $null; $workerParseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseInput($workerText, [ref]$workerTokens, [ref]$workerParseErrors)
if ($workerParseErrors.Count -gt 0) { "FAIL 워커 파싱 오류 $($workerParseErrors.Count)건 - 첫 오류: $($workerParseErrors[0].Message)"; exit 1 }
$workerCode = Remove-SourceComments -Text $workerText
$functionAsts = @{}
foreach ($functionAst in $workerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
  if (-not $functionAsts.ContainsKey($functionAst.Name)) { $functionAsts[$functionAst.Name] = $functionAst }   # 같은 이름이면 첫 정의 (Get-SourceFunctionDefinitions 와 같은 선택)
}
function Get-FunctionCode {
  # 함수 정의의 주석 뺀 사본 - 전체 사본을 AST 범위로 잘라 냅니다 (같은 원문을 파싱했으므로 오프셋이 같음)
  param([string]$Name)
  if (-not $functionAsts.ContainsKey($Name)) { throw "워커에서 함수를 찾지 못했습니다: $Name" }
  $functionExtent = $functionAsts[$Name].Extent
  return $workerCode.Substring($functionExtent.StartOffset, $functionExtent.EndOffset - $functionExtent.StartOffset)
}
function Test-InsideFunction {
  param($Node)
  $parentNode = $Node.Parent
  while ($null -ne $parentNode) {
    if ($parentNode -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return $true }
    $parentNode = $parentNode.Parent
  }
  return $false
}

# ── 셋업 1: 상수 5개·영역·아이콘 표·준비 플래그 대입문을 소스 AST 에서 그대로 실행 (사본 금지 - config 미정의 → 기본값) ──
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$setupAssignmentNames = @('$abyssMenuIconMinSize', '$abyssMenuIconMaxSize', '$abyssMenuIconMinScore', '$abyssMenuIconMinMargin', '$abyssMenuIconLabelRatio',
  '$rgAbyssMenu', '$script:workerIconB64', '$script:abyssMenuIconTemplatesReady')
$topAssignments = @($workerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
    Where-Object { ($setupAssignmentNames -contains $_.Left.Extent.Text) -and -not (Test-InsideFunction -Node $_) })
foreach ($assignmentName in $setupAssignmentNames) {
  $sourceAssignments = @($topAssignments | Where-Object { $_.Left.Extent.Text -eq $assignmentName })
  if ($sourceAssignments.Count -ne 1) { "FAIL 셋업: 워커 최상위(함수 밖)의 $assignmentName 대입문이 1곳이 아닙니다 ($($sourceAssignments.Count)곳)"; exit 1 }
  Invoke-Expression $sourceAssignments[0].Extent.Text
}

# ── B1. 상수 계약 ──
$contractText = [string]::Format($invariant, '{0}/{1}/{2}/{3}/{4}', $abyssMenuIconMinSize, $abyssMenuIconMaxSize, $abyssMenuIconMinScore, $abyssMenuIconMinMargin, $abyssMenuIconLabelRatio)
Check-Equal 'B1① 계약값 고정 - 크기 24~33 / 임계 0.80 / 2등 차이 0.20 / 라벨 비율 0.91 (설계 리뷰 ① 승인값. 바꾸면 여기서 걸리는 것이 의도 - 설계 재합의 필요, 리뷰 ② P1: 범위 단언만으로는 0.70·0.01 같은 중간 약화가 통과)' `
  $contractText '24/33/0.8/0.2/0.91'
Check-True 'B1② 측정 분리 - 어비스를 지운 메뉴의 최고 0.601 < 임계 < 메뉴 열림 양성 최소 0.894' (($abyssMenuIconMinScore -gt 0.601) -and ($abyssMenuIconMinScore -lt 0.894)) "임계 $abyssMenuIconMinScore"
Check-True 'B1② 측정 분리 - 0 < 2등 차이 < 양성 최소 차이 0.313 (같은 그림 두 곳 = 차이 0 은 거부)' (($abyssMenuIconMinMargin -gt 0) -and ($abyssMenuIconMinMargin -lt 0.313)) "2등 차이 $abyssMenuIconMinMargin"
Check-True 'B1② 측정 분리 - 관측 최적 크기 25~32(1272·1908@150%·네이티브 1908) ⊂ [최소+1, 최대-1]' ((($abyssMenuIconMinSize + 1) -le 25) -and (32 -le ($abyssMenuIconMaxSize - 1))) `
  "크기 $abyssMenuIconMinSize~$abyssMenuIconMaxSize"

# ── B2. 메뉴 분기 배선 (주석 뺀 사본) ──
$returnCode = Get-FunctionCode 'Return-ToAbyssSelection'
$returnAst = $functionAsts['Return-ToAbyssSelection']
$menuBranches = @($returnAst.FindAll({
      param($node)
      ($node -is [System.Management.Automation.Language.IfStatementAst]) -and
      ($node.Clauses[0].Item1.Extent.Text -eq 'Test-AbyssMenu -Game $Game') -and
      $node.Clauses[0].Item2.Extent.Text.Contains("-SearchText '어비스'")
    }, $true))
if ($menuBranches.Count -ne 1) { "FAIL B2 전제: 복귀 루프의 메뉴 분기(if (Test-AbyssMenu -Game `$Game) { … -SearchText '어비스' … })가 1곳이 아닙니다 ($($menuBranches.Count)곳)"; exit 1 }
$menuStart = $menuBranches[0].Extent.StartOffset
$menuEnd = $menuBranches[0].Extent.EndOffset
$menuCode = $workerCode.Substring($menuStart, $menuEnd - $menuStart)
$guardLine = 'if ($script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial) { Start-Sleep -Milliseconds 700; continue }'
$guardAts = @([regex]::Matches($menuCode, [regex]::Escape($guardLine)) | ForEach-Object { $_.Index })
$missAt = $menuCode.IndexOf('$abyssMenuMissCount++')
$menuOrder = [ordered]@{
  '출처 없는 메뉴 닫기' = $menuCode.IndexOf('if (-not $fieldProven) {')
  '신호 스냅숏' = $menuCode.IndexOf('$abyssMenuSignal = $script:lastAbyssMenuSignal')
  '글자 탐색' = $menuCode.IndexOf('$abyssMenuPoint = Find-GameTextPoint -Game $Game')
  '가드#1' = $(if ($guardAts.Count -ge 1) { $guardAts[0] } else { -1 })
  'D-R 조건' = $menuCode.IndexOf('if ($abyssMenuSignal -eq ''exit-label'') {')
  '아이콘 탐색' = $menuCode.IndexOf('Find-AbyssMenuIconPoint -Game $Game')
  '가드#2' = $(if ($guardAts.Count -ge 2) { $guardAts[1] } else { -1 })
  '미발견 계상' = $missAt
  '전면' = $menuCode.IndexOf('Focus-Game -Game $Game', [Math]::Max(0, $missAt))
  '클릭' = $menuCode.IndexOf('Click-ScreenPoint -X $abyssMenuPoint.X')
}
$orderValues = @($menuOrder.Values)
$orderOk = ($guardAts.Count -eq 2) -and ($orderValues[0] -ge 0) -and (@(0..($orderValues.Count - 2) | Where-Object { $orderValues[$_] -ge $orderValues[$_ + 1] }).Count -eq 0)
Check-True 'B2: 메뉴 분기 순서 = 출처 없는 메뉴 닫기 < 신호 스냅숏 < 글자 탐색 < 가드#1 < D-R 조건(exit-label) < 아이콘 탐색 < 가드#2 < 미발견 계상 < 전면 < 클릭, 캡처 실패 가드는 정확히 2줄 (규칙 15 - 설계 4.1 ⓐⓒⓔ)' `
  $orderOk ((@($menuOrder.Keys | ForEach-Object { '{0}={1}' -f $_, $menuOrder[$_] }) -join ', ') + ", 가드 $($guardAts.Count)줄")
$entryBraceEnd = $menuCode.IndexOf('{') + 1
$signalAt = $menuOrder['신호 스냅숏']
$entryToSignal = $(if ($signalAt -ge $entryBraceEnd) { $menuCode.Substring($entryBraceEnd, $signalAt - $entryBraceEnd) } else { '' })
$signalCount = [regex]::Matches($workerCode, [regex]::Escape('$abyssMenuSignal = $script:lastAbyssMenuSignal')).Count
Check-True 'B2: 신호 스냅숏은 워커 전체 1곳(메뉴 분기 안)이고 입구 판정과 스냅숏 사이에 Test-AbyssMenu 호출 0 (같은 회전·같은 판정의 신호 - D-R)' `
  (($signalCount -eq 1) -and ($signalAt -gt $entryBraceEnd) -and (-not $entryToSignal.Contains('Test-AbyssMenu'))) `
  ('워커 전체 {0}곳, 분기 안 위치 {1}, 사이 Test-AbyssMenu {2}건' -f $signalCount, $signalAt, ([regex]::Matches($entryToSignal, 'Test-AbyssMenu').Count))
$iconCallAsts = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Find-AbyssMenuIconPoint') }, $true))
Check-True 'B2: 아이콘 탐색 호출(Find-AbyssMenuIconPoint)은 워커 전체 1곳이고 메뉴 분기 안 (설계 4.1 ⓒ - 토큰 대조 뒤에만)' `
  (($iconCallAsts.Count -eq 1) -and ($iconCallAsts[0].Extent.StartOffset -gt $menuStart) -and ($iconCallAsts[0].Extent.EndOffset -lt $menuEnd)) "호출 $($iconCallAsts.Count)곳"
Check-Equal 'B2: 메뉴 분기의 Click-ScreenPoint 1개 (글자·아이콘이 같은 클릭 블록 공유 - 복제 금지, 설계 4.1 ⓕ)' ([regex]::Matches($menuCode, 'Click-ScreenPoint').Count) 1
Check-Equal 'B2: 복귀 함수에 고정 좌표 $ptAbyssMenu 0건 (못 찾으면 누르지 않음 - 08-08 광고 배너 실사고, 설계 4.1 ⓓ)' ([regex]::Matches($returnCode, '\$ptAbyssMenu\b').Count) 0
Check-True "B2: 클릭 출처 변수 `$abyssMenuFoundBy = '글자 탐색' 은 글자 탐색 바로 다음 줄 1곳" `
  (([bool]($menuCode -match '-SearchText ''어비스'' -ExactText ''어비스'' -Scale 4\s*\r?\n\s*\$abyssMenuFoundBy = ''글자 탐색''')) -and
   ([regex]::Matches($workerCode, [regex]::Escape('$abyssMenuFoundBy = ''글자 탐색''')).Count -eq 1)) '글자 탐색 바로 뒤 대입 없음 또는 워커에 2곳 이상'
$iconFoundByAsts = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and ($node.Left.Extent.Text -eq '$abyssMenuFoundBy') -and ($node.Right.Extent.Text -eq "'아이콘 탐색'") }, $true))
$foundBlocks = @($returnAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.IfStatementAst]) -and ($node.Clauses[0].Item1.Extent.Text -eq '$abyssMenuIcon.Status -eq ''found''') }, $true))
$foundBody = $(if ($foundBlocks.Count -eq 1) { $foundBlocks[0].Clauses[0].Item2.Extent } else { $null })
Check-True "B2: `$abyssMenuFoundBy = '아이콘 탐색' 은 워커 전체 1곳이고 found 블록(if (`$abyssMenuIcon.Status -eq 'found')) 안" `
  (($iconFoundByAsts.Count -eq 1) -and ($null -ne $foundBody) -and ($iconFoundByAsts[0].Extent.StartOffset -gt $foundBody.StartOffset) -and ($iconFoundByAsts[0].Extent.EndOffset -lt $foundBody.EndOffset)) `
  ('대입 {0}곳, found 블록 {1}곳' -f $iconFoundByAsts.Count, $foundBlocks.Count)

# ── B3. 아이콘은 메뉴 판정·알려진 화면·이벤트 정리에 넣지 않음 (설계 4.1 ⓒ - 출처 없는 메뉴, 리셋 팝업 체인 X 후보) ──
$iconNamePattern = 'Find-AbyssMenuIconPoint|Initialize-AbyssMenuIconTemplates|Test-AbyssMenuIconAccept|Get-AbyssMenuIconClickPoint|Get-BitmapBgraBytes|Get-GameWindowShapeText|HoneyNogiIconMatch|workerIconB64'
foreach ($screenFunction in @('Test-AbyssMenu', 'Test-KnownScreen', 'Clear-EventOverlay')) {
  Check-Equal "B3: $screenFunction 본문에 아이콘 함수·형 0건" ([regex]::Matches((Get-FunctionCode $screenFunction), $iconNamePattern).Count) 0
}

# ── B4. 캡처 입구 (정적) ──
$newFunctionNames = @('Get-BitmapBgraBytes', 'Initialize-AbyssMenuIconTemplates', 'Test-AbyssMenuIconAccept', 'Get-AbyssMenuIconClickPoint', 'Get-GameWindowShapeText', 'Find-AbyssMenuIconPoint')
$newFunctionCode = @($newFunctionNames | ForEach-Object { Get-FunctionCode $_ }) -join "`n"
$captureCommandAsts = @($functionAsts['Find-AbyssMenuIconPoint'].FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Get-GameRegionCapture') }, $true))
$captureCallText = $(if ($captureCommandAsts.Count -eq 1) { (($captureCommandAsts[0].Extent.Text -replace '`\r?\n', ' ') -replace '\s+', ' ').Trim() } else { "호출 $($captureCommandAsts.Count)곳" })
Check-Equal 'B4: Find-AbyssMenuIconPoint 의 캡처 = Get-GameRegionCapture 1회, 글자 탐색과 같은 영역 $rgAbyssMenu[0..3]·기준 단위 -Scale 1 (캡처 실패 등록·최소화 처리를 공유 - 설계 3.1)' `
  $captureCallText 'Get-GameRegionCapture -Game $Game -ReferenceX $rgAbyssMenu[0] -ReferenceY $rgAbyssMenu[1] -RegionWidth $rgAbyssMenu[2] -RegionHeight $rgAbyssMenu[3] -Scale 1'
Check-Equal 'B4: 새 함수 6개에 CopyFromScreen·Get-GamePixel 0건 (화면은 공용 캡처 입구로만)' ([regex]::Matches($newFunctionCode, 'CopyFromScreen|Get-GamePixel').Count) 0

# ── B5. 숨은 양보·조작 없음 ──
Check-Equal 'B5: 새 함수 6개에 양보·클릭·키·전면화·커서 대피 0건 (토큰 대조 뒤 숨은 양보가 출처를 끊으면 안 됨 - 규칙 4, 설계 4.1 ⓑ)' `
  ([regex]::Matches($newFunctionCode, 'Move-CursorOutsideGame|Wait-UserYieldEnd|Invoke-UserYieldWithDeadline|Click-|Press-Key|Focus-Game').Count) 0

# ── B6. 컴파일 위치 ──
function Test-InsideDeferredBlock {
  # 조건문·반복문·함수 안이면 시작 때 실행이 보장되지 않습니다 (test_type_availability 의 조건부 판정 + 함수 안 = 지연 컴파일)
  param($Node)
  $parentNode = $Node.Parent
  while ($null -ne $parentNode) {
    if (($parentNode -is [System.Management.Automation.Language.IfStatementAst]) -or ($parentNode -is [System.Management.Automation.Language.SwitchStatementAst]) -or
        ($parentNode -is [System.Management.Automation.Language.LoopStatementAst]) -or ($parentNode -is [System.Management.Automation.Language.FunctionDefinitionAst])) { return $true }
    $parentNode = $parentNode.Parent
  }
  return $false
}
$addTypeAsts = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Add-Type') }, $true))
$inlineAddTypes = @($addTypeAsts | Where-Object { $_.Extent.Text -notmatch '-AssemblyName' })
$startAddTypes = @($inlineAddTypes | Where-Object { -not (Test-InsideDeferredBlock -Node $_) })
Check-True 'B6: 워커의 -AssemblyName 없는 Add-Type 은 1곳이고 조건문·반복문·함수 밖 (= 시작 Add-Type - 지연 컴파일은 실패를 삼켜 전 PC 무동작이 될 수 있음, 설계 3.6)' `
  (($inlineAddTypes.Count -eq 1) -and ($startAddTypes.Count -eq 1)) ('전체 {0}곳, 조건·반복·함수 밖 {1}곳' -f $inlineAddTypes.Count, $startAddTypes.Count)
if ($startAddTypes.Count -ne 1) { 'FAIL 셋업: 시작 Add-Type(조건·반복·함수 밖, -AssemblyName 없음)을 하나로 정할 수 없어 행동 단언을 중단합니다'; $fails++; "FAIL: $fails 건"; exit 1 }
$startAddTypeText = $startAddTypes[0].Extent.Text
Check-Equal 'B6: 시작 Add-Type 원문에 public static class HoneyNogiIconMatch 1곳 (HoneyNogiInput 과 한 번에 컴파일)' ([regex]::Matches($startAddTypeText, 'public static class HoneyNogiIconMatch\b').Count) 1
$addTypeOptionParams = @($addTypeAsts | ForEach-Object { $_.CommandElements } | Where-Object { ($_ -is [System.Management.Automation.Language.CommandParameterAst]) -and ($_.ParameterName -match '^(Ref|Ign)') })
Check-Equal 'B6: 워커 전체(주석 제외)에 -IgnoreWarnings·-ReferencedAssemblies 0건, Add-Type 의 줄임 인자(-Ref…·-Ign…)도 0 (경고=오류 - 운영·테스트가 같은 명령으로 함께 실패)' `
  ([regex]::Matches($workerCode, '-IgnoreWarnings|-ReferencedAssemblies').Count + $addTypeOptionParams.Count) 0
$matchTypeUses = @($workerAst.FindAll({
      param($node)
      (($node -is [System.Management.Automation.Language.TypeExpressionAst]) -or ($node -is [System.Management.Automation.Language.TypeConstraintAst])) -and
      ($node.TypeName.FullName -eq 'HoneyNogiIconMatch')
    }, $true) | ForEach-Object {
      $ownerFunction = $_.Parent
      while ($ownerFunction -and -not ($ownerFunction -is [System.Management.Automation.Language.FunctionDefinitionAst])) { $ownerFunction = $ownerFunction.Parent }
      $memberName = $(if ($_.Parent -is [System.Management.Automation.Language.MemberExpressionAst]) { $_.Parent.Member.Extent.Text } else { '(멤버 아님)' })
      '{0}:{1}' -f $(if ($ownerFunction) { $ownerFunction.Name } else { '(최상위)' }), $memberName
    } | Sort-Object)
Check-Equal 'B6: [HoneyNogiIconMatch] 리터럴은 새 함수 안 3곳(준비의 ClearTemplates·SetTemplate, 탐색의 Match)뿐' ($matchTypeUses -join ' / ') `
  'Find-AbyssMenuIconPoint:Match / Initialize-AbyssMenuIconTemplates:ClearTemplates / Initialize-AbyssMenuIconTemplates:SetTemplate'

# ── B11. 진단 꼬리 배선 (판정에 쓰지 않음 - 설계 6.4) ──
$questCode = Get-FunctionCode 'Test-InDungeonQuest'
$trackerAssignLine = '$script:lastQuestTrackerText = $normalized'
$trackerAssignCount = [regex]::Matches($questCode, [regex]::Escape($trackerAssignLine)).Count
$questNormalizeAt = $questCode.IndexOf('$normalized = $ocrText -replace')
$questAssignAt = $questCode.IndexOf($trackerAssignLine)
$questKeywordAt = $questCode.IndexOf('foreach ($titleKeyword in $allDungeonKeywords)')
Check-True 'B11: 운영 Test-InDungeonQuest 가 판독문을 진단 변수에 남기는 대입 1곳 - 정규화 뒤·키워드 판정 foreach 앞' `
  (($trackerAssignCount -eq 1) -and ($questNormalizeAt -ge 0) -and ($questNormalizeAt -lt $questAssignAt) -and ($questAssignAt -lt $questKeywordAt)) `
  ('대입 {0}곳, 위치 정규화 {1} / 대입 {2} / foreach {3}' -f $trackerAssignCount, $questNormalizeAt, $questAssignAt, $questKeywordAt)
$trackerSnapshot = '$fieldProvenTrackerText = [string]$script:lastQuestTrackerText'
$trackerSnapshotCount = [regex]::Matches($workerCode, [regex]::Escape($trackerSnapshot)).Count
Check-True 'B11: 복귀 루프 토큰 발급 줄(fieldProven = $true 다음 줄의 기준값 대입)에 필드 확정 추적기 판독문 스냅숏 1곳' `
  (($trackerSnapshotCount -eq 1) -and
   ([bool]($returnCode -match '\$fieldProven = \$true[^\r\n]*\r?\n\s*\$fieldProvenYieldMs = \[double\]\$script:userYieldTotalMs; \$fieldProvenSerial = \$script:captureFailSerial; \$fieldProvenTrackerText = \[string\]\$script:lastQuestTrackerText'))) `
  "워커 전체 $trackerSnapshotCount 곳 또는 토큰 발급 줄 모양 불일치"
function Test-InsideDecision {
  # 변수 참조가 판정식 안인지 - 부모를 따라 올라가며 if·elseif 조건, 반복·switch 조건, -and·-or·-xor 피연산자 자리를 찾습니다
  param($Node)
  $childNode = $Node; $parentNode = $Node.Parent
  while ($null -ne $parentNode) {
    if (($parentNode -is [System.Management.Automation.Language.BinaryExpressionAst]) -and (@('And', 'Or', 'Xor') -contains [string]$parentNode.Operator)) { return $true }
    if ($parentNode -is [System.Management.Automation.Language.IfStatementAst]) {
      foreach ($clause in $parentNode.Clauses) { if ([object]::ReferenceEquals($clause.Item1, $childNode)) { return $true } }
    }
    if ((($parentNode -is [System.Management.Automation.Language.LoopStatementAst]) -or ($parentNode -is [System.Management.Automation.Language.SwitchStatementAst])) -and
        [object]::ReferenceEquals($parentNode.Condition, $childNode)) { return $true }
    $childNode = $parentNode; $parentNode = $parentNode.Parent
  }
  return $false
}
$diagnosticVariables = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.VariableExpressionAst]) -and ($node.VariablePath.UserPath -match '(^|:)(lastQuestTrackerText|fieldProvenTrackerText)$') }, $true))
$diagnosticInDecision = @($diagnosticVariables | Where-Object { Test-InsideDecision -Node $_ })
Check-True 'B11: 진단 변수 둘($script:lastQuestTrackerText·$fieldProvenTrackerText)은 판정식(if·반복·switch 조건, -and·-or)에 0회 - 판정에 쓰지 않음' `
  (($diagnosticVariables.Count -ge 4) -and ($diagnosticInDecision.Count -eq 0)) ('참조 {0}곳, 판정식 안 {1}곳' -f $diagnosticVariables.Count, $diagnosticInDecision.Count)
# 찾음 로그의 추적기 꼬리는 토큰 발급 줄에서 떠 둔 스냅숏이어야 합니다 (설계 6.4 - W 를 확정한 표본). 전역을 직접 읽어도 대개 값이 같지만, ESC 반응이
# 늦어 같은 토큰으로 HUD 분기(추적기 판독)를 한 번 더 돈 회전 - 필드 확정 대기 continue 는 토큰을 폐기·재발급하지 않음 - 에서는 다른 필드 표본이
# 찍힙니다. 하니스 RLI1 은 그 회전을 만들지 않아 이 바꿔치기를 못 잡습니다 (변이 V18c). 정렬은 문화권과 무관하게 서수 비교로 합니다
$globalTrackerSites = [string[]]@($diagnosticVariables | Where-Object { $_.VariablePath.UserPath -match '(^|:)lastQuestTrackerText$' } | ForEach-Object {
    $ownerFunction = $_.Parent
    while ($ownerFunction -and -not ($ownerFunction -is [System.Management.Automation.Language.FunctionDefinitionAst])) { $ownerFunction = $ownerFunction.Parent }
    $isWrite = ($_.Parent -is [System.Management.Automation.Language.AssignmentStatementAst]) -and [object]::ReferenceEquals($_.Parent.Left, $_)
    '{0}:{1}' -f $(if ($ownerFunction) { $ownerFunction.Name } else { '(최상위)' }), $(if ($isWrite) { '쓰기' } else { '읽기' })
  })
[Array]::Sort($globalTrackerSites, [StringComparer]::Ordinal)
$foundLogCalls = @(if ($foundBlocks.Count -eq 1) { $foundBlocks[0].Clauses[0].Item2.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Write-RunLog') }, $true) })
$foundLogSnapshotRefs = @(if ($foundLogCalls.Count -eq 1) { $foundLogCalls[0].FindAll({ param($node) ($node -is [System.Management.Automation.Language.VariableExpressionAst]) -and ($node.VariablePath.UserPath -eq 'fieldProvenTrackerText') }, $true) })
# 2026-11-16 재입장대기_클리어화면 A2: 재입장 대기(Wait-AbyssReentry)의 진단 요약 줄도 그 회전에 HUD 가 읽혔을 때만(⑧ 유효 회전 · Test-InDungeonQuest 가 방금 남긴 판독)
#   전역을 지역 스냅숏으로 받습니다 - 읽기 1곳 · 판정식 밖(위 판정식 0회 단언이 함께 봄). 요약 시점에 전역을 바로 읽으면 대기 밖(직전 판 클리어 대기)의 옛 판독이 찍힙니다
Check-Equal 'B11: 찾음 로그(found 블록의 Write-RunLog 1개)는 스냅숏 $fieldProvenTrackerText 를 1회 쓰고, 전역 $script:lastQuestTrackerText 는 최상위 초기화·Test-InDungeonQuest 대입·복귀 루프 스냅숏 읽기·재입장 대기 진단 스냅숏 읽기 4곳뿐 (설계 6.4 - W 를 확정한 표본, 변이 V18c · 재입장대기_클리어화면 A2)' `
  ('찾음 로그 {0}개·스냅숏 참조 {1}회 / 전역 {2}' -f $foundLogCalls.Count, $foundLogSnapshotRefs.Count, ($globalTrackerSites -join ', ')) `
  '찾음 로그 1개·스냅숏 참조 1회 / 전역 (최상위):쓰기, Return-ToAbyssSelection:읽기, Test-InDungeonQuest:쓰기, Wait-AbyssReentry:읽기'

# ── 셋업 2: 시작 Add-Type 원문 그대로 컴파일(인자 추가 없음 - 운영과 같은 명령, 설계 3.6·B6) → 함수 추출 → 모의 ──
Invoke-Expression $startAddTypeText
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-BitmapBgraBytes', 'Initialize-AbyssMenuIconTemplates',
    'Test-AbyssMenuIconAccept', 'Get-AbyssMenuIconClickPoint', 'Find-AbyssMenuIconPoint', 'Test-AbyssMenu', 'Find-GameTextPoint', 'Invoke-OcrOnBitmap', 'Await-WinRt')) {
  Invoke-Expression $definition
}
$script:screenCaptureFailing = $false
$script:runLogs = New-Object System.Collections.Generic.List[string]
function Write-RunLog { param([string]$Message) $script:runLogs.Add($Message) }
$mockWindowShape = '1272x717·DPI 96 (모의)'
function Get-GameWindowShapeText { param($Game) return $mockWindowShape }
# 캡처 재생 모의 - 'window': 창 이미지(원점 0,0)에서 워커 Get-GameRegionCapture 와 같은 환산으로 정확 잘라내기(CopyFromScreen 대응 Bitmap.Clone)
# + 영역 x 배율 HighQualityBicubic (설계 부록 V-2 의 재생 경로) / 'region': 준비된 기준 비트맵(합성·변형) 그대로 / 'null': 캡처 실패($null)
$script:replayMode = 'window'
$script:replayWindow = $null
$script:replayRegion = $null
$script:captureCalls = 0
function Get-GameRegionCapture {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3,
    [switch]$BinaryWhiteText, [switch]$ThrowOnWindowRectFailure)
  $script:captureCalls++
  if ($script:replayMode -eq 'null') { return $null }
  if ($script:replayMode -eq 'region') {
    if ((($RegionWidth * $Scale) -ne $script:replayRegion.Width) -or (($RegionHeight * $Scale) -ne $script:replayRegion.Height)) {
      throw "재생 모의: 준비된 기준 비트맵($($script:replayRegion.Width)x$($script:replayRegion.Height))과 요청 크기가 다릅니다"
    }
    $regionCopy = $script:replayRegion.Clone((New-Object System.Drawing.Rectangle(0, 0, $script:replayRegion.Width, $script:replayRegion.Height)), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    return [pscustomobject]@{ Bitmap = $regionCopy; CropLeft = $ReferenceX; CropTop = $ReferenceY; CropWidth = $RegionWidth; CropHeight = $RegionHeight
      ScaledWidth = ($RegionWidth * $Scale); ScaledHeight = ($RegionHeight * $Scale); Scale = $Scale }
  }
  $window = $script:replayWindow
  $cropLeft = [int][Math]::Round($ReferenceX * $window.Width / 1272)
  $cropTop = [int][Math]::Round($ReferenceY * $window.Height / 717)
  $cropWidth = [Math]::Max(1, [int][Math]::Round($RegionWidth * $window.Width / 1272))
  $cropHeight = [Math]::Max(1, [int][Math]::Round($RegionHeight * $window.Height / 717))
  $crop = $window.Clone((New-Object System.Drawing.Rectangle($cropLeft, $cropTop, $cropWidth, $cropHeight)), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $scaled = New-Object System.Drawing.Bitmap ($RegionWidth * $Scale), ($RegionHeight * $Scale)
  $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
  try {
    $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $scaledGraphics.DrawImage($crop, (New-Object System.Drawing.Rectangle(0, 0, ($RegionWidth * $Scale), ($RegionHeight * $Scale))),
      (New-Object System.Drawing.Rectangle(0, 0, $cropWidth, $cropHeight)), [System.Drawing.GraphicsUnit]::Pixel)
  } finally { $scaledGraphics.Dispose(); $crop.Dispose() }
  return [pscustomobject]@{ Bitmap = $scaled; CropLeft = $cropLeft; CropTop = $cropTop; CropWidth = $cropWidth; CropHeight = $cropHeight
    ScaledWidth = ($RegionWidth * $Scale); ScaledHeight = ($RegionHeight * $Scale); Scale = $Scale }
}
function Invoke-IconReplay {
  # 저장 창 캡처 한 장을 워커 경로 그대로(Find-AbyssMenuIconPoint → 재생 캡처 → 매칭 → 클릭점) 판독합니다 - 비트맵 해제는 호출부
  param([System.Drawing.Bitmap]$Window)
  $script:replayMode = 'window'; $script:replayWindow = $Window
  try { return (Find-AbyssMenuIconPoint -Game $null) } finally { $script:replayWindow = $null }
}
function Invoke-RegionMatch {
  # 준비된 기준 비트맵(350x520) 한 장을 같은 함수로 판독합니다 - 비트맵 해제는 호출부
  param([System.Drawing.Bitmap]$Region)
  $script:replayMode = 'region'; $script:replayRegion = $Region
  try { return (Find-AbyssMenuIconPoint -Game $null) } finally { $script:replayRegion = $null }
}
function Format-IconResult {
  param($Result)
  $pointText = $(if ($null -ne $Result.Point) { [string]::Format($invariant, '{0},{1}', $Result.Point.X, $Result.Point.Y) } else { '없음' })
  return [string]::Format($invariant, '상태 {0}, 일치도 {1:0.000}, 2등 {2:0.000}, 크기 {3}, 아이콘 중심 {4},{5}, 유도점 {6}',
    $Result.Status, $Result.Score, $Result.Second, $Result.Size, $Result.CenterX, $Result.CenterY, $pointText)
}

# ── B7. 템플릿 준비 계약 ──
$expectedTemplateCount = $abyssMenuIconMaxSize - $abyssMenuIconMinSize + 1
Initialize-AbyssMenuIconTemplates
Check-Equal "B7① 정상 준비 → 템플릿 수 = 최대 - 최소 + 1 ($expectedTemplateCount), 준비 플래그 참" ('{0}/{1}' -f [HoneyNogiIconMatch]::TemplateCount, $script:abyssMenuIconTemplatesReady) "$expectedTemplateCount/True"
[HoneyNogiIconMatch]::ClearTemplates()
Initialize-AbyssMenuIconTemplates
Check-Equal 'B7② 플래그가 참이면 다시 등록하지 않음 (ClearTemplates 뒤 재호출 → 0 그대로 - 첫 폴백 때 한 번)' ([HoneyNogiIconMatch]::TemplateCount) 0
$savedIconBase64 = $script:workerIconB64['abyssMenu']
$script:abyssMenuIconTemplatesReady = $false
$script:workerIconB64['abyssMenu'] = 'AAAA'
$prepareError = ''
try { Initialize-AbyssMenuIconTemplates } catch { $prepareError = $_.Exception.Message }
Check-True 'B7③ 해독할 수 없는 아이콘(AAAA) → 예외가 밖으로 나오고(삼키지 않음 - 최상위 catch 의 오류 세트가 원인을 남김) 준비 플래그는 거짓 유지' `
  (($prepareError -ne '') -and (-not $script:abyssMenuIconTemplatesReady)) ("예외 '{0}', 플래그 {1}" -f $prepareError, $script:abyssMenuIconTemplatesReady)
$script:workerIconB64['abyssMenu'] = $savedIconBase64
$script:abyssMenuIconTemplatesReady = $false
Initialize-AbyssMenuIconTemplates
Check-Equal 'B7 복원: 원래 아이콘으로 다시 준비 → 템플릿 수 복구 (아래 단언의 전제)' ([HoneyNogiIconMatch]::TemplateCount) $expectedTemplateCount

# ── B8. 수락 진리표 - 고정 경계값 (소스 상수를 다시 읽지 않음: B1① 이 계약값을 고정하므로 여기 숫자는 그 계약의 경계) ──
# 차이 경계를 정확히 0.200 으로 두지 않는 이유: 0.95 - 0.75 는 배정밀도에서 0.19999999999999996 이라 구현이 맞아도 경계 판정이 흔들립니다 - 0.199/0.201 로 양쪽을 봅니다
foreach ($acceptCase in @(
    @{ Best = 0.800; Second = 0.0; Expected = $true; Note = '임계 0.80 이상' },
    @{ Best = 0.799; Second = 0.0; Expected = $false; Note = '임계 미만' },
    @{ Best = 0.95; Second = 0.751; Expected = $false; Note = '2등 차이 0.199' },
    @{ Best = 0.95; Second = 0.749; Expected = $true; Note = '2등 차이 0.201' },
    @{ Best = 0.80; Second = 0.80; Expected = $false; Note = '동점 - 같은 그림 두 곳' },
    @{ Best = 0.0; Second = 0.0; Expected = $false; Note = '평탄' })) {
  Check-Equal ([string]::Format($invariant, 'B8 수락({0:0.000}, {1:0.000}) → {2} ({3})', $acceptCase.Best, $acceptCase.Second, $acceptCase.Expected, $acceptCase.Note)) `
    (Test-AbyssMenuIconAccept -Best $acceptCase.Best -Second $acceptCase.Second) $acceptCase.Expected
}

# ── B9. 클릭점 환산 - 라벨 상당점 = 아이콘 중심 + (0, 라벨 비율 x 크기), 역환산은 Find-GameTextPoint 와 같은 식 (탐지와 클릭이 같은 환산 왕복) ──
function New-MockCapture {
  param([int]$Left, [int]$Top, [int]$Width, [int]$Height)
  return [pscustomobject]@{ CropLeft = $Left; CropTop = $Top; CropWidth = $Width; CropHeight = $Height; ScaledWidth = 350; ScaledHeight = 520 }
}
foreach ($clickCase in @(
    @{ Name = '① 1272 창 원점 (646,2) - Crop (1496,182,350,520), 중심 (125,183)·크기 30'; Capture = (New-MockCapture -Left 1496 -Top 182 -Width 350 -Height 520); X = 125; Y = 183; Size = 30; Expected = '1621,392' },
    @{ Name = '② 1908 창 원점 (971,0) - Crop (2246,270,525,780), 중심 (150,145)·크기 28 = 실제 글자 클릭 화면좌표 2471,526 (어비스\20261001_⑥e_실기\worker_logs\run_20261001_h10m54s31.log 20행)'
      Capture = (New-MockCapture -Left 2246 -Top 270 -Width 525 -Height 780); X = 150; Y = 145; Size = 28; Expected = '2471,526' },
    @{ Name = '③ 음수 원점 보조 모니터 (-1920,0) 1272 - Crop (-1070,180,350,520), 중심 (125,183)·크기 30 (같은 식)'; Capture = (New-MockCapture -Left (-1070) -Top 180 -Width 350 -Height 520); X = 125; Y = 183; Size = 30; Expected = '-945,390' })) {
  $clickPoint = Get-AbyssMenuIconClickPoint -Capture $clickCase.Capture -CenterX $clickCase.X -CenterY $clickCase.Y -Size $clickCase.Size
  Check-Equal ('B9{0} → 화면 {1}' -f $clickCase.Name, $clickCase.Expected) ([string]::Format($invariant, '{0},{1}', $clickPoint.X, $clickPoint.Y)) $clickCase.Expected
}
$labelPoint = Get-AbyssMenuIconClickPoint -Capture (New-MockCapture -Left 0 -Top 0 -Width 350 -Height 520) -CenterX 100 -CenterY 100 -Size 100
Check-Equal 'B9④ 라벨 오프셋 = 라벨 비율 x 크기 (같은 배율 캡처, 중심 (100,100)·크기 100 → 가로 그대로, 세로 + round(비율 x 100))' `
  ([string]::Format($invariant, '{0},{1}', $labelPoint.X, $labelPoint.Y)) ([string]::Format($invariant, '100,{0}', (100 + [int][Math]::Round($abyssMenuIconLabelRatio * 100))))

# ── B10. 합성 진리표 - 아이콘은 워커 base64 해독본(B7 의 같은 표), 회색 35 바탕 350x520 (설계 부록 V-2 합성 6건) ──
function New-SyntheticRegion {
  param([int[][]]$Placements, [int]$Size, [int]$Background = 35)
  $syntheticBitmap = New-Object System.Drawing.Bitmap 350, 520
  $syntheticGraphics = [System.Drawing.Graphics]::FromImage($syntheticBitmap)
  try {
    $syntheticGraphics.Clear([System.Drawing.Color]::FromArgb(255, $Background, $Background, $Background))
    $syntheticGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $iconStream = New-Object System.IO.MemoryStream(, [Convert]::FromBase64String([string]$script:workerIconB64['abyssMenu']))
    try {
      $iconImage = [System.Drawing.Image]::FromStream($iconStream)
      try {
        foreach ($placement in $Placements) { $syntheticGraphics.DrawImage($iconImage, (New-Object System.Drawing.Rectangle($placement[0], $placement[1], $Size, $Size))) }
      } finally { $iconImage.Dispose() }
    } finally { $iconStream.Dispose() }
  } finally { $syntheticGraphics.Dispose() }
  return $syntheticBitmap
}
foreach ($syntheticCase in @(
    @{ Id = 'S1'; Note = '크기 28 한 개 @(100,200)'; Placements = @(, @(100, 200)); Size = 28; Status = 'found'; Center = '114,214'; BestSize = 28; Best = 1.000 },
    @{ Id = 'S2'; Note = '크기 28 두 개 @(100,200)·(220,200) - 같은 그림 두 곳은 2등 차이 0 으로 거부'; Placements = @(@(100, 200), @(220, 200)); Size = 28; Status = 'not-found'; Best = 1.000; SameAsSecond = $true },
    @{ Id = 'S3'; Note = '평탄 - 평탄 창 0점'; Placements = @(); Size = 28; Status = 'not-found'; ZeroBest = $true },
    @{ Id = 'S4'; Note = '크기 25 @(60,300) - 범위 안'; Placements = @(, @(60, 300)); Size = 25; Status = 'found'; Center = '72.5,312.5'; BestSize = 25; Best = 1.000 },
    @{ Id = 'S5'; Note = '크기 33 @(60,300) - 범위 끝'; Placements = @(, @(60, 300)); Size = 33; Status = 'found'; Center = '76.5,316.5'; BestSize = 33; Best = 1.000 },
    @{ Id = 'S6'; Note = '크기 40 @(60,300) - 범위 밖은 기준 미달'; Placements = @(, @(60, 300)); Size = 40; Status = 'not-found'; Center = '76,317'; BestSize = 28; Best = 0.439 })) {
  $syntheticRegion = New-SyntheticRegion -Placements $syntheticCase.Placements -Size $syntheticCase.Size
  try { $syntheticResult = Invoke-RegionMatch -Region $syntheticRegion } finally { $syntheticRegion.Dispose() }
  # 중심은 영역 비트맵 안 px 로 비교합니다 (함수는 기준 좌표 = 영역 원점 + 비트맵 안 px 를 돌려줌)
  $regionCenter = [string]::Format($invariant, '{0},{1}', ($syntheticResult.CenterX - $rgAbyssMenu[0]), ($syntheticResult.CenterY - $rgAbyssMenu[1]))
  $syntheticOk = ($syntheticResult.Status -eq $syntheticCase.Status)
  if ($syntheticCase.ContainsKey('Center')) { $syntheticOk = $syntheticOk -and ($regionCenter -eq $syntheticCase.Center) }
  if ($syntheticCase.ContainsKey('BestSize')) { $syntheticOk = $syntheticOk -and ($syntheticResult.Size -eq $syntheticCase.BestSize) }
  if ($syntheticCase.ContainsKey('Best')) { $syntheticOk = $syntheticOk -and ([Math]::Abs($syntheticResult.Score - $syntheticCase.Best) -le 0.005) }
  if ($syntheticCase.ContainsKey('SameAsSecond')) { $syntheticOk = $syntheticOk -and ([Math]::Abs($syntheticResult.Score - $syntheticResult.Second) -lt 0.005) }
  if ($syntheticCase.ContainsKey('ZeroBest')) { $syntheticOk = $syntheticOk -and ($syntheticResult.Score -eq 0) }
  $syntheticExpect = @("상태 $($syntheticCase.Status)")
  if ($syntheticCase.ContainsKey('Center')) { $syntheticExpect += "중심 $($syntheticCase.Center)" }
  if ($syntheticCase.ContainsKey('BestSize')) { $syntheticExpect += "크기 $($syntheticCase.BestSize)" }
  if ($syntheticCase.ContainsKey('Best')) { $syntheticExpect += [string]::Format($invariant, '일치도 {0:0.000}±0.005', $syntheticCase.Best) }
  if ($syntheticCase.ContainsKey('SameAsSecond')) { $syntheticExpect += '2등과 차이 < 0.005' }
  if ($syntheticCase.ContainsKey('ZeroBest')) { $syntheticExpect += '일치도 0' }
  Check-True ('B10 {0} {1} → {2}' -f $syntheticCase.Id, $syntheticCase.Note, ($syntheticExpect -join '·')) $syntheticOk ((Format-IconResult $syntheticResult) + ", 영역 안 중심 $regionCenter")
}

# ── B4 (행동). 캡처 계약 - 실패 중이면 캡처 없이 capture-failed, 캡처가 없으면(실패 등록 뒤 $null) capture-failed, 정상은 캡처 1회 (설계 4.1 ⓐ·4.6) ──
$captureProbeRegion = New-SyntheticRegion -Placements @(, @(100, 200)) -Size 28
try {
  $script:captureCalls = 0
  $normalProbe = Invoke-RegionMatch -Region $captureProbeRegion
  $normalProbeCalls = $script:captureCalls
  $script:screenCaptureFailing = $true; $script:captureCalls = 0
  $failingProbe = Invoke-RegionMatch -Region $captureProbeRegion
  $failingProbeCalls = $script:captureCalls
  $script:screenCaptureFailing = $false
  $script:replayMode = 'null'; $script:captureCalls = 0
  $nullProbe = Find-AbyssMenuIconPoint -Game $null
  $nullProbeCalls = $script:captureCalls
} finally {
  $script:screenCaptureFailing = $false; $script:replayMode = 'window'
  $captureProbeRegion.Dispose()
}
Check-Equal 'B4 행동: 정상 판독은 캡처 1회 + 창 모양 꼬리(진단 - Get-GameWindowShapeText) 채움' ('{0}/{1}/{2}' -f $normalProbe.Status, $normalProbeCalls, $normalProbe.Window) "found/1/$mockWindowShape"
Check-Equal 'B4 행동: 캡처 실패 중이면 캡처 시도 없이 capture-failed·클릭점 없음 (호출부 가드#2 가 회전을 끝냄 - 규칙 15)' ('{0}/{1}/{2}' -f $failingProbe.Status, $failingProbeCalls, ($null -eq $failingProbe.Point)) 'capture-failed/0/True'
Check-Equal 'B4 행동: 캡처가 없으면(Register-CaptureFailure 뒤 $null) capture-failed·클릭점 없음' ('{0}/{1}/{2}' -f $nullProbe.Status, $nullProbeCalls, ($null -eq $nullProbe.Point)) 'capture-failed/1/True'

# ── B12. 메뉴 판정 신호 진리표 (D-R) - 운영 Test-AbyssMenu 그대로, 1차 판독(Get-GameRegionOcrText)·2차 신호(Test-MenuExitLabel)만 모의 ──
# 판독문은 소스가 아니라 사고 로그 원문에서 옮긴 실측입니다 (규칙 문서 '실기 검증' 5) - 미발견 진단의 목록 덤프 한 줄:
#   ③ 던전이미지\어비스\20260915_타PC_어비스_입장미감지_트래커상단잘림\run_20260915_h03m18s10.log 23행 '1필드보스어H|스망령의@428'
#   ④ 던전이미지\어비스\20261002_RDP콘솔전환_메뉴어비스_오독\mabinogi_run_once.log 43행 '필드보스어HI스망령의@391'
$script:menuOcrText = ''; $script:exitLabelResult = $false; $script:exitLabelCalls = 0
function Get-GameRegionOcrText {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale = 3, $Engine, [switch]$BinaryWhiteText)
  return $script:menuOcrText
}
function Test-MenuExitLabel { param($Game) $script:exitLabelCalls++; return $script:exitLabelResult }
foreach ($signalCase in @(
    @{ Id = '①'; Text = '1필드보스어비스망령의'; ExitLabel = $true; Before = '(이전 값)'; Expected = 'True/abyss-text/0'; Note = "정상 판독 '어비스' → 1차 신호에서 끝남(2차가 참이어도 보지 않음)" },
    @{ Id = '②'; Text = '필드보스비스망령'; ExitLabel = $true; Before = '(이전 값)'; Expected = 'True/abyss-text/0'; Note = "'비스' 조각 → 1차 신호" },
    @{ Id = '③'; Text = '1필드보스어H|스망령의'; ExitLabel = $true; Before = '(이전 값)'; Expected = 'True/exit-label/1'; Note = "09-15 타 PC 실측 '어H|스' + 2차 참 → 2차 신호만으로 메뉴(아이콘 폴백이 열리는 모양)" },
    @{ Id = '④'; Text = '필드보스어HI스망령의'; ExitLabel = $false; Before = '(이전 값)'; Expected = 'False//1'; Note = "10-02 콘솔 전환 실측 '어HI스' + 2차 거짓 → 메뉴 아님, 신호 ''" },
    @{ Id = '⑤'; Text = '필드보스어HI스망령의'; ExitLabel = $false; Before = 'exit-label'; Expected = 'False//1'; Note = "직전 'exit-label' 이 남은 채 ④ → '' 로 덮임(갈래마다 대입)" })) {
  $script:menuOcrText = $signalCase.Text; $script:exitLabelResult = $signalCase.ExitLabel; $script:exitLabelCalls = 0
  $script:lastAbyssMenuSignal = $signalCase.Before
  $menuResult = Test-AbyssMenu -Game $null
  Check-Equal ('B12{0} {1} - 판정/신호/2차 호출 수' -f $signalCase.Id, $signalCase.Note) ('{0}/{1}/{2}' -f $menuResult, $script:lastAbyssMenuSignal, $script:exitLabelCalls) $signalCase.Expected
}

# ── C. 저장 캡처 재생 (던전이미지\ - 로컬 전용) ──
# 기대값은 설계 부록 V-2(저장 캡처 14장 - 워커 경로 재생)·V-5(배율·지움 변형) 실측입니다. 경로는 던전이미지\ 아래
# P8 은 구현 뒤 실기(10-08 실기 3 - RDP 150% → 콘솔 전환 뒤 창 1276x719·창 DPI 144)에서 아이콘 폴백이 실제로 누른 메뉴입니다 (설계 11.4 ⑥). 그 순간의 워커
# 캡처는 남지 않아 프레임 기록 한 장에서 창을 재구성했고(방법·원점 근거 = P8 PNG 옆 같은 이름 .txt), 기대값은 재생값이 아니라 라이브 워커 로그(그 폴더
# worker_logs\run_20261008_h09m16s09.log 의 09:16:05 찾음·09:16:06 클릭 줄) 값이며 재생과 같음을 확인했습니다 (유도점 = 클릭 1620,397 - 창 원점 642,5)
$positiveCases = @(
  [pscustomobject]@{ Id = 'P1'; Rel = '어비스\20261002_RDP콘솔전환_메뉴어비스_오독\error_20261002_h15m52s04.png'; Note = '10-02 15:52 콘솔 전환 1272(글자 어HI스)'; Best = 0.913; Size = 30; CenterX = 975.0; CenterY = 363.0; PointX = 975; PointY = 390 }
  [pscustomobject]@{ Id = 'P2'; Rel = '어비스\20261002_RDP콘솔전환_메뉴어비스_오독\error_20261002_h15m52s43.png'; Note = '같은 메뉴 39초 뒤'; Best = 0.913; Size = 30; CenterX = 975.0; CenterY = 363.0; PointX = 975; PointY = 390 }
  [pscustomobject]@{ Id = 'P3'; Rel = '어비스\20260915_타PC_어비스_입장미감지_트래커상단잘림\error_20260915_h03m18s00.png'; Note = '09-15 타 PC 네이티브 1908 + 배너(글자 어H|스)'; Best = 0.954; Size = 25; CenterX = 1027.5; CenterY = 405.5; PointX = 1541; PointY = 642 }
  [pscustomobject]@{ Id = 'P4'; Rel = '어비스\20261002_RDP콘솔전환_메뉴어비스_오독\정상기준_20261001_215938_1272_ESC메뉴.png'; Note = '정상 1272'; Best = 0.945; Size = 31; CenterX = 970.5; CenterY = 357.5; PointX = 970; PointY = 386 }
  [pscustomobject]@{ Id = 'P5'; Rel = '어비스\20261001_⑥e_실기\frames\cap_105425_612_1908x1076.png'; Note = '1908@150%(창 DPI 144) - 유도점 = 실제 글자 클릭 2471,526 - 창 원점 971'; Best = 0.972; Size = 28; CenterX = 1000.0; CenterY = 325.0; PointX = 1500; PointY = 526 }
  [pscustomobject]@{ Id = 'P6'; Rel = '어비스\20260921_파티장4인_토글OFF_입장하기_파티패널준비취소_다른던전가기2회_실측\cap_203537_706_1272x717.png'; Note = '클릭 직후(양성 최저)'; Best = 0.894; Size = 32; CenterX = 971.0; CenterY = 357.0; PointX = 971; PointY = 386 }
  [pscustomobject]@{ Id = 'P7'; Rel = '어비스\20261002_시간지정_실기\frames_실기6\cap_211258_073_1272x717.png'; Note = '메뉴 열림 페이드'; Best = 0.957; Size = 30; CenterX = 971.0; CenterY = 358.0; PointX = 971; PointY = 385 }
  [pscustomobject]@{ Id = 'P8'; Rel = '어비스\20261008_메뉴아이콘_실기3_2차\P8_창재구성_091605_1276x719.png'; Note = '10-08 실기 3 콘솔 전환 1276x719 창 DPI 144 - 라이브 아이콘 클릭 1620,397 - 창 원점 642,5'; Best = 0.965; Size = 30; CenterX = 975.0; CenterY = 363.0; PointX = 978; PointY = 392 }
)
$negativeCases = @(
  [pscustomobject]@{ Id = 'N1'; Rel = '어비스\20260915_타PC_어비스_입장미감지_트래커상단잘림\error_20260915_h02m48s43.png'; Note = '09-15 상세 화면'; Best = 0.434 }
  [pscustomobject]@{ Id = 'N2'; Rel = '어비스\20260915_타PC_어비스_입장미감지_트래커상단잘림\error_20260915_h03m24s43.png'; Note = '09-15 입장 대기'; Best = 0.446 }
  [pscustomobject]@{ Id = 'N3'; Rel = '어비스\20261001_⑥e_실기\frames2\cap_151115_895_1908x1076.png'; Note = '음성 1위(던전 안 스킬 버튼)'; Best = 0.595 }
  [pscustomobject]@{ Id = 'N4'; Rel = '어비스\20261001_⑥e_실기\frames2\cap_133722_717_1908x1076.png'; Note = '음성 2위'; Best = 0.593 }
  [pscustomobject]@{ Id = 'N5'; Rel = '어비스\20261001_⑥e_실기\frames2\cap_133159_990_1908x1076.png'; Note = '음성 3위'; Best = 0.590 }
  [pscustomobject]@{ Id = 'N6'; Rel = '어비스\20260918_다른던전가기_01_어비스선택오버레이_3카드_X_1272x717.png'; Note = '선택 오버레이'; Best = 0.466 }
  [pscustomobject]@{ Id = 'N7'; Rel = '어비스\20260918_다른던전가기_01b_카드클릭후_상세화면_광기의동굴_함께하기_1272x717.png'; Note = '상세 화면 1272'; Best = 0.473 }
)
function New-VariantRegion {
  # 아이콘 중심 고정 F 배 변형 (설계 10.2 끝·부록 V-5): 원본 창 이미지의 실수 원본 사각형
  # (L,T,W,H) = (cx·sx - (cx-850)·sx/F, cy·sy - (cy-180)·sy/F, 350·sx/F, 520·sy/F) 를 350x520 에 HighQualityBicubic 으로 그립니다 (sx = 창폭/1272, sy = 창높이/717)
  param([System.Drawing.Bitmap]$Window, [double]$CenterRefX, [double]$CenterRefY, [double]$Factor)
  $scaleX = $Window.Width / 1272.0; $scaleY = $Window.Height / 717.0
  $sourceWidth = $rgAbyssMenu[2] * $scaleX / $Factor; $sourceHeight = $rgAbyssMenu[3] * $scaleY / $Factor
  $sourceLeft = $CenterRefX * $scaleX - ($CenterRefX - $rgAbyssMenu[0]) * $scaleX / $Factor
  $sourceTop = $CenterRefY * $scaleY - ($CenterRefY - $rgAbyssMenu[1]) * $scaleY / $Factor
  $variantBitmap = New-Object System.Drawing.Bitmap -ArgumentList $rgAbyssMenu[2], $rgAbyssMenu[3]
  $variantGraphics = [System.Drawing.Graphics]::FromImage($variantBitmap)
  try {
    $variantGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $variantGraphics.DrawImage($Window, (New-Object System.Drawing.RectangleF(0, 0, $rgAbyssMenu[2], $rgAbyssMenu[3])),
      (New-Object System.Drawing.RectangleF([single]$sourceLeft, [single]$sourceTop, [single]$sourceWidth, [single]$sourceHeight)), [System.Drawing.GraphicsUnit]::Pixel)
  } finally { $variantGraphics.Dispose() }
  return $variantBitmap
}
function New-ErasedWindow {
  # 어비스 지움 (설계 10.2 C5·부록 V-5): 아이콘 사각형(중심·크기 + 여유)을 바깥 띠(폭 Band)의 평균색으로 채운 창 이미지 사본 - 비트맵 해제는 호출부
  param([System.Drawing.Bitmap]$Window, [double]$CenterX, [double]$CenterY, [int]$IconSize, [int]$Margin, [int]$Band)
  $half = $IconSize / 2.0 + $Margin
  $eraseLeft = [int][Math]::Floor($CenterX - $half); $eraseRight = [int][Math]::Ceiling($CenterX + $half)
  $eraseTop = [int][Math]::Floor($CenterY - $half); $eraseBottom = [int][Math]::Ceiling($CenterY + $half)
  $sumRed = 0; $sumGreen = 0; $sumBlue = 0; $bandCount = 0
  for ($bandY = $eraseTop - $Band; $bandY -le $eraseBottom + $Band; $bandY++) {
    for ($bandX = $eraseLeft - $Band; $bandX -le $eraseRight + $Band; $bandX++) {
      if ($bandX -ge $eraseLeft -and $bandX -le $eraseRight -and $bandY -ge $eraseTop -and $bandY -le $eraseBottom) { continue }
      $bandColor = $Window.GetPixel($bandX, $bandY)
      $sumRed += $bandColor.R; $sumGreen += $bandColor.G; $sumBlue += $bandColor.B; $bandCount++
    }
  }
  $fillColor = [System.Drawing.Color]::FromArgb(255, [int]($sumRed / $bandCount), [int]($sumGreen / $bandCount), [int]($sumBlue / $bandCount))
  $erasedBitmap = $Window.Clone((New-Object System.Drawing.Rectangle(0, 0, $Window.Width, $Window.Height)), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $eraseGraphics = [System.Drawing.Graphics]::FromImage($erasedBitmap)
  $fillBrush = New-Object System.Drawing.SolidBrush($fillColor)
  try { $eraseGraphics.FillRectangle($fillBrush, $eraseLeft, $eraseTop, ($eraseRight - $eraseLeft + 1), ($eraseBottom - $eraseTop + 1)) }
  finally { $fillBrush.Dispose(); $eraseGraphics.Dispose() }
  return [pscustomobject]@{ Bitmap = $erasedBitmap; Fill = ('RGB({0},{1},{2})' -f $fillColor.R, $fillColor.G, $fillColor.B); Rect = ('({0},{1})~({2},{3})' -f $eraseLeft, $eraseTop, $eraseRight, $eraseBottom) }
}

$imageRoot = Join-Path $root '던전이미지'
if (-not (Test-Path -LiteralPath $imageRoot)) {
  "SKIP C 단 전체(C1~C5): 던전이미지 폴더가 없어 저장 캡처 재생을 건너뜁니다 (로컬 전용 - 개발 PC 외): $imageRoot"
} else {
  # 루트가 있는데 목록 파일이 없으면 SKIP 이 아니라 FAIL - 파일 하나 이동이 핵심 재현을 조용히 끄지 않게 (설계 10.2 SKIP 규칙, 리뷰 B8)
  foreach ($listedCase in @(@($positiveCases) + @($negativeCases))) {
    if (-not (Test-Path -LiteralPath (Join-Path $imageRoot $listedCase.Rel))) {
      "FAIL C 목록 파일 없음 ($($listedCase.Id)): 던전이미지\$($listedCase.Rel) - 폴더를 옮겼다면 이 테스트의 경로도 함께 고칠 것"
      $fails++
    }
  }

  # ── C1. 저장 캡처 양성 (워커 경로 재생: 캡처 → 매칭 → 라벨 상당점) ──
  foreach ($positiveCase in $positiveCases) {
    $capturePath = Join-Path $imageRoot $positiveCase.Rel
    if (-not (Test-Path -LiteralPath $capturePath)) { continue }
    $captureWindow = New-Object System.Drawing.Bitmap($capturePath)
    try { $replayResult = Invoke-IconReplay -Window $captureWindow } finally { $captureWindow.Dispose() }
    $positiveOk = ($replayResult.Status -eq 'found') -and ([Math]::Abs($replayResult.Score - $positiveCase.Best) -le 0.005) -and ($replayResult.Size -eq $positiveCase.Size) -and
      ($replayResult.CenterX -eq $positiveCase.CenterX) -and ($replayResult.CenterY -eq $positiveCase.CenterY) -and ($null -ne $replayResult.Point) -and
      ($replayResult.Point.X -eq $positiveCase.PointX) -and ($replayResult.Point.Y -eq $positiveCase.PointY)
    Check-True ([string]::Format($invariant, 'C1 {0} {1} → found, 일치도 {2:0.000}±0.005·크기 {3}·아이콘 중심 {4},{5}·유도점(이미지 px) {6},{7}',
        $positiveCase.Id, $positiveCase.Note, $positiveCase.Best, $positiveCase.Size, $positiveCase.CenterX, $positiveCase.CenterY, $positiveCase.PointX, $positiveCase.PointY)) `
      $positiveOk (Format-IconResult $replayResult)
  }

  # ── C2. 저장 캡처 음성 (메뉴가 아닌 화면·메뉴 밖 최상위 음성 - 누르지 않음) ──
  foreach ($negativeCase in $negativeCases) {
    $capturePath = Join-Path $imageRoot $negativeCase.Rel
    if (-not (Test-Path -LiteralPath $capturePath)) { continue }
    $captureWindow = New-Object System.Drawing.Bitmap($capturePath)
    try { $replayResult = Invoke-IconReplay -Window $captureWindow } finally { $captureWindow.Dispose() }
    Check-True ([string]::Format($invariant, 'C2 {0} {1} → not-found·클릭점 없음 (평가 최고 {2:0.000})', $negativeCase.Id, $negativeCase.Note, $negativeCase.Best)) `
      (($replayResult.Status -eq 'not-found') -and ($null -eq $replayResult.Point)) (Format-IconResult $replayResult)
  }

  # ── C3. 고치기 전 재현 - 운영 글자 탐색(Find-GameTextPoint + Invoke-OcrOnBitmap + Await-WinRt, 메뉴 분기와 같은 인자)을 그대로 ──
  $ocrKoreanEngine = $null
  $ocrUnavailableReason = ''
  try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
    [Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null
    [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
    $asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
      Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 } |
      Select-Object -First 1
    $ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language('ko')))
  } catch {
    $ocrUnavailableReason = $_.Exception.Message
  }
  if (-not $ocrKoreanEngine) {
    "SKIP C3: 한국어 OCR 엔진을 만들 수 없어 고치기 전 재현을 건너뜁니다 (ko 언어 팩 없음) $ocrUnavailableReason"
  } else {
    foreach ($ocrCase in @(
        @{ Id = 'P1'; Expected = '없음'; Note = "글자 '어HI스' - 글자 탐색 실패(사고 재현)" },
        @{ Id = 'P2'; Expected = '없음'; Note = '같은 메뉴 39초 뒤도 실패(기다려도 안 읽힘)' },
        @{ Id = 'P3'; Expected = '없음'; Note = "글자 '어H|스' - 글자 탐색 실패(09-15 재현)" },
        @{ Id = 'P4'; Expected = '971,386'; Note = '정상 1272 - 글자 자리 (아이콘 유도점 970,386 과 1px)' },
        @{ Id = 'P5'; Expected = '1500,526'; Note = '1908@150% - 실제 글자 클릭 2471,526 - 창 원점 971' },
        @{ Id = 'P8'; Expected = '없음'; Note = "재생 판독 '어HI스' - 글자 탐색 실패(10-08 실기 3 라이브와 같음 - 그래서 아이콘 폴백)" })) {
      $ocrSource = $positiveCases | Where-Object { $_.Id -eq $ocrCase.Id } | Select-Object -First 1
      $capturePath = Join-Path $imageRoot $ocrSource.Rel
      if (-not (Test-Path -LiteralPath $capturePath)) { continue }
      $captureWindow = New-Object System.Drawing.Bitmap($capturePath)
      $script:replayMode = 'window'; $script:replayWindow = $captureWindow
      try {
        $textPoint = Find-GameTextPoint -Game $null -ReferenceX $rgAbyssMenu[0] -ReferenceY $rgAbyssMenu[1] `
          -RegionWidth $rgAbyssMenu[2] -RegionHeight $rgAbyssMenu[3] -SearchText '어비스' -ExactText '어비스' -Scale 4
      } finally {
        $script:replayWindow = $null
        $captureWindow.Dispose()
      }
      $textPointText = $(if ($null -eq $textPoint) { '없음' } else { [string]::Format($invariant, '{0},{1}', $textPoint.X, $textPoint.Y) })
      Check-Equal ("C3 {0} {1} - 운영 글자 탐색 결과(이미지 px)" -f $ocrCase.Id, $ocrCase.Note) $textPointText $ocrCase.Expected
    }
  }

  # ── C4. 연속 배율 (R-3) - P3 를 아이콘 중심 고정으로 F 배 (실효 크기 = 24.85 x F) ──
  $p3Case = $positiveCases | Where-Object { $_.Id -eq 'P3' } | Select-Object -First 1
  $p3Path = Join-Path $imageRoot $p3Case.Rel
  if (Test-Path -LiteralPath $p3Path) {
    $p3Window = New-Object System.Drawing.Bitmap($p3Path)
    try {
      foreach ($variantCase in @(@{ Factor = 0.96; Size = 24; Best = 0.910 }, @{ Factor = 1.30; Size = 32; Best = 0.942 })) {
        $variantRegion = New-VariantRegion -Window $p3Window -CenterRefX $p3Case.CenterX -CenterRefY $p3Case.CenterY -Factor $variantCase.Factor
        try { $variantResult = Invoke-RegionMatch -Region $variantRegion } finally { $variantRegion.Dispose() }
        $variantOk = ($variantResult.Status -eq 'found') -and ($variantResult.Size -eq $variantCase.Size) -and ([Math]::Abs($variantResult.Score - $variantCase.Best) -le 0.005) -and
          ([Math]::Abs($variantResult.CenterX - $p3Case.CenterX) -le 2) -and ([Math]::Abs($variantResult.CenterY - $p3Case.CenterY) -le 2)
        Check-True ([string]::Format($invariant, 'C4 P3 x{0:0.00} → found·크기 {1}·일치도 {2:0.000}±0.005·중심 {3},{4}±2 (설계 부록 V-5 - 이 변형 경로의 값)',
            $variantCase.Factor, $variantCase.Size, $variantCase.Best, $p3Case.CenterX, $p3Case.CenterY)) $variantOk (Format-IconResult $variantResult)
      }
    } finally { $p3Window.Dispose() }
  }

  # ── C5. 어비스 지움 (R-3) - P4 의 아이콘 사각형(중심 970.5,357.5 · 크기 31 + 여유 2)을 바깥 3px 띠 평균색으로 → 다른 타일을 수락하지 않음 ──
  $p4Case = $positiveCases | Where-Object { $_.Id -eq 'P4' } | Select-Object -First 1
  $p4Path = Join-Path $imageRoot $p4Case.Rel
  if (Test-Path -LiteralPath $p4Path) {
    $p4Window = New-Object System.Drawing.Bitmap($p4Path)
    try {
      $erasedWindow = New-ErasedWindow -Window $p4Window -CenterX $p4Case.CenterX -CenterY $p4Case.CenterY -IconSize $p4Case.Size -Margin 2 -Band 3
      try { $erasedResult = Invoke-IconReplay -Window $erasedWindow.Bitmap } finally { $erasedWindow.Bitmap.Dispose() }
    } finally { $p4Window.Dispose() }
    Check-True ('C5 P4 어비스 지움(사각형 {0} 을 바깥 3px 띠 평균색 {1} 로) → not-found·일치도 < 0.65 (설계 실측 0.520 - 다른 타일 수락 0)' -f $erasedWindow.Rect, $erasedWindow.Fill) `
      (($erasedResult.Status -eq 'not-found') -and ($erasedResult.Score -lt 0.65)) (Format-IconResult $erasedResult)
  }
}

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
