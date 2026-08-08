# 생활(채집) 커스텀 반복 진리표 + 배선 가드 (v2.0.0 - 2026-08-08 시안 확정 구현)
#
# 던전/어비스/심층 커스텀과 결정적으로 다른 점 하나만 검증하면 됩니다:
#   **항목마다 반복 횟수(count)** 가 있고, 진행 기록(lap/index)은 그 count 를 펼친
#   '실행 단위' 위에서 셉니다. 등록 목록(items)은 펼치지 않으므로 지문/랜덤 순열은
#   등록 단위 그대로입니다. 이 두 축이 어긋나면 count 2 이상인 항목이 1회만 돌거나
#   (전진 칸 수를 등록 수로 세는 실수), 정상 진행이 1번으로 되감깁니다(index 상한 검사).
$fails = 0

$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 본체에서 순수 함수 추출 ──
# Get-LifeSkillNameById 는 $script:lifeSkills 를 읽으므로 그 정의도 함께 가져옵니다
foreach ($definition in Get-SourceFunctionDefinitions -Path $guiPath `
    -Names @('Format-CustomItemToken', 'Get-CustomFingerprint', 'Get-CustomNextProgress',
             'Get-CustomPositionText', 'Get-CustomExecutionItems', 'Test-CustomShuffleOrder',
             'Get-LifeSkillNameById', 'Get-LifeSkillIdByName', 'Get-LifeCustomItemLabel',
             'Expand-LifeCustomItems', 'Get-LifeCustomPositionText', 'Get-LifeCustomListCompact',
             'Get-LifeCustomCycleTotal', 'Get-LifeSkillTargets', 'Get-LcrCellEditPlan',
             'Set-LcrItemCellValue')) {
  Invoke-Expression $definition
}
$guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$null, [ref]$null)
# $script:lifeSkills 와 $script:lifeSupportedSkillIds 둘 다 필요합니다 - 후자를 빼면
# 셀 편집 계획의 스킬 옵션이 0종이 되어 진리표가 조용히 오답을 냅니다
foreach ($needVar in @('lifeSkills', 'lifeSupportedSkillIds')) {
  $varAssign = $guiAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$script:' + $needVar))
    }, $true)
  if (-not $varAssign) { "FAIL 본체에서 `$script:$needVar 정의를 찾지 못했습니다"; $fails++; continue }
  Invoke-Expression $varAssign.Extent.Text
}

# 테스트용 리스트 (사용자가 짤 법한 모양: 스킬 혼합 + 횟수 혼합 + 같은 조합 중복)
$sampleItems = @(
  [pscustomobject]@{ kind = 'life'; skill = 'daily';  target = '사과 나무'; count = 3 }
  [pscustomobject]@{ kind = 'life'; skill = 'mining'; target = '은광맥';    count = 2 }
  [pscustomobject]@{ kind = 'life'; skill = 'daily';  target = '사과 나무'; count = 1 }
)

# ── ① 항목 토큰 / 지문 ──
Assert-Case '토큰: 생활 4조각' (Format-CustomItemToken -Item $sampleItems[0]) 'L|daily|사과 나무|3'
Assert-Case '토큰: 횟수 0 이하는 1로 정규화' `
  (Format-CustomItemToken -Item ([pscustomobject]@{ kind = 'life'; skill = 'wood'; target = '나무'; count = 0 })) 'L|wood|나무|1'
Assert-Case '토큰: 횟수 상한 99' `
  (Format-CustomItemToken -Item ([pscustomobject]@{ kind = 'life'; skill = 'wood'; target = '나무'; count = 500 })) 'L|wood|나무|99'
# 던전/어비스 토큰이 생활 분기에 잡아먹히지 않아야 합니다 (kind/속성으로만 구분)
Assert-Case '토큰: 던전 항목은 그대로 6조각' `
  (Format-CustomItemToken -Item ([pscustomobject]@{ difficulty = '어려움'; stage = '1-3'; coin = $true; doubleLoot = $true; exhaustContinue = $false; noDoubleSweep = $true })) '어려움|1-3|1|1|0|1'
Assert-Case '토큰: 어비스 항목도 그대로 5조각' `
  (Format-CustomItemToken -Item ([pscustomobject]@{ kind = 'abyss'; mode = 'party'; difficulty = '어려움'; dungeon = '허상의 정박지'; matching = '우연한 만남' })) 'A|party|어려움|허상의 정박지|우연한 만남'
# 지문은 count 를 포함해야 합니다 - 횟수만 바꿔도 '리스트 변경'으로 처음부터 시작해야 하기
# 때문입니다 (횟수를 바꿨는데 옛 진행을 이어가면 몇 번 남았는지가 어긋남)
$fpBefore = Get-CustomFingerprint -Items $sampleItems
$fpCountChanged = Get-CustomFingerprint -Items @(
  [pscustomobject]@{ kind = 'life'; skill = 'daily';  target = '사과 나무'; count = 5 }
  [pscustomobject]@{ kind = 'life'; skill = 'mining'; target = '은광맥';    count = 2 }
  [pscustomobject]@{ kind = 'life'; skill = 'daily';  target = '사과 나무'; count = 1 }
)
Assert-Case '지문: 횟수만 바뀌어도 달라짐' ($fpBefore -ne $fpCountChanged) 'True'
Assert-Case '지문: 같은 리스트는 같은 값' ($fpBefore -eq (Get-CustomFingerprint -Items $sampleItems)) 'True'

# ── ② count 펼침 (실행 단위) ──
$expanded = @(Expand-LifeCustomItems -Items $sampleItems)
Assert-Case '펼침: 총 실행 칸 = 횟수 합 (3+2+1)' $expanded.Count '6'
Assert-Case '펼침: 같은 항목이 연속으로' `
  ((@($expanded | ForEach-Object { $_.target }) -join ',')) '사과 나무,사과 나무,사과 나무,은광맥,은광맥,사과 나무'
Assert-Case '펼침: rep 는 1부터 항목마다 다시' `
  ((@($expanded | ForEach-Object { $_.rep }) -join ',')) '1,2,3,1,2,1'
Assert-Case '펼침: sourceIndex 는 등록 순번' `
  ((@($expanded | ForEach-Object { $_.sourceIndex }) -join ',')) '0,0,0,1,1,2'
Assert-Case '펼침: 빈 리스트는 0칸' (@(Expand-LifeCustomItems -Items @()).Count) '0'
Assert-Case '펼침: null 항목은 건너뜀' (@(Expand-LifeCustomItems -Items @($null, $sampleItems[2])).Count) '1'
Assert-Case '펼침: count 없는 항목은 1회' `
  (@(Expand-LifeCustomItems -Items @([pscustomobject]@{ skill = 'daily'; target = '둥지' })).Count) '1'
Assert-Case '펼침: count 상한 99' `
  (@(Expand-LifeCustomItems -Items @([pscustomobject]@{ skill = 'daily'; target = '둥지'; count = 300 })).Count) '99'
Assert-Case '합계: 바퀴당 사이클 수 = 펼친 칸 수' (Get-LifeCustomCycleTotal -Items $sampleItems) '6'

# ── ③ 진행 전진 (실행 단위 기준) ──
# 항목 3개(합 6칸)를 1바퀴 도는 동안 index 가 0→5 를 지나 lap 2 로 넘어가야 합니다.
# 등록 수(3)로 전진하면 3칸 만에 바퀴가 넘어가 count 2 이상인 항목이 잘립니다
$progress = $null
$trail = @()
for ($step = 0; $step -lt 7; $step++) {
  $progress = Get-CustomNextProgress -Progress $progress -ItemCount $expanded.Count
  $trail += ('{0}:{1}' -f $progress.lap, $progress.index)
}
Assert-Case '전진: 6칸을 다 돌고 lap 2 로' ($trail -join ' ') '1:1 1:2 1:3 1:4 1:5 2:0 2:1'

# ── ④ 위치 표기 ──
Assert-Case '표기: 실행 칸 + 항목 내 회차' `
  (Get-LifeCustomPositionText -Lap 1 -Index 3 -Total 6 -Item $expanded[3]) '1바퀴째 4/6번 (광석 캐기 - 은광맥 1/2회)'
Assert-Case '표기: 마지막 칸' `
  (Get-LifeCustomPositionText -Lap 2 -Index 5 -Total 6 -Item $expanded[5]) '2바퀴째 6/6번 (일상 채집 - 사과 나무 1/1회)'
Assert-Case '표기: 항목이 없으면 공용 표기만' `
  (Get-LifeCustomPositionText -Lap 1 -Index 0 -Total 6 -Item $null) '1바퀴째 1/6번'

# ── ⑤ 스킬 Id ↔ 표시명 (리스트뷰는 표시명, config 는 Id) ──
Assert-Case 'Id→이름: daily' (Get-LifeSkillNameById -Id 'daily') '일상 채집'
Assert-Case 'Id→이름: insect' (Get-LifeSkillNameById -Id 'insect') '곤충 채집'
Assert-Case 'Id→이름: 모르는 Id 는 그대로' (Get-LifeSkillNameById -Id 'unknown') 'unknown'
Assert-Case '이름→Id: 일상 채집' (Get-LifeSkillIdByName -Name '일상 채집') 'daily'
Assert-Case '이름→Id: 모르는 이름은 빈 값' (Get-LifeSkillIdByName -Name '없는 스킬') ''
# 왕복 무손실 (리스트 저장/복원이 이 왕복을 매번 지나므로 하나라도 깨지면 항목이 사라집니다)
$roundTripOk = $true
foreach ($skillDef in @($script:lifeSkills)) {
  if ((Get-LifeSkillIdByName -Name ([string]$skillDef.Name)) -ne [string]$skillDef.Id) { $roundTripOk = $false }
}
Assert-Case 'Id↔이름 왕복 무손실 (9종 전부)' $roundTripOk 'True'

# ── ⑥ 로그 표기 ──
Assert-Case '표기: 항목 라벨 (횟수 2 이상)' (Get-LifeCustomItemLabel -Item $sampleItems[0]) '일상 채집 - 사과 나무 3회'
Assert-Case '표기: 항목 라벨 (1회면 횟수 생략)' (Get-LifeCustomItemLabel -Item $sampleItems[2]) '일상 채집 - 사과 나무'
Assert-Case '표기: 압축 리스트 (등록 순서)' `
  (Get-LifeCustomListCompact -Items $sampleItems) '1.일상 채집/사과 나무x3 2.광석 캐기/은광맥x2 3.일상 채집/사과 나무x1'

# ── ⑦ 랜덤 순열과 펼침의 순서 계약 ──
# 셔플은 '등록 항목' 단위이고 펼침은 그 뒤에 옵니다 - 그래야 한 항목의 count 사이클이
# 흩어지지 않고 연속으로 붙습니다 (사용자가 '3회 연속'을 기대하는 대로)
$order = @(2, 0, 1)
Assert-Case '랜덤: 순열 검증은 등록 항목 수 기준' (Test-CustomShuffleOrder -Order $order -ItemCount 3) 'True'
Assert-Case '랜덤: 펼친 수로는 검증 실패해야 정상' (Test-CustomShuffleOrder -Order $order -ItemCount 6) 'False'
$shuffledExpanded = @(Expand-LifeCustomItems -Items (Get-CustomExecutionItems -Items $sampleItems -Order $order))
Assert-Case '랜덤: 셔플 후 펼치면 항목별 연속 유지' `
  ((@($shuffledExpanded | ForEach-Object { $_.target }) -join ',')) '사과 나무,사과 나무,사과 나무,사과 나무,은광맥,은광맥'
Assert-Case '랜덤: 총 칸 수는 순서와 무관' $shuffledExpanded.Count '6'

# ── ⑦b 진행 사이클 시뮬레이션 (실제 컨텍스트/전진 함수를 메모리 config 로 구동) ──
# 진리표만으로는 '컨텍스트 getter 와 전진 함수가 같은 칸 수를 보는지'를 못 잡습니다.
# 한쪽이 등록 수, 다른 쪽이 펼친 수를 보면 항목이 잘리거나 되감기므로 두 함수를 실제로
# 이어 돌려 1바퀴 전체 궤적을 확인합니다.
foreach ($definition in Get-SourceFunctionDefinitions -Path $guiPath `
    -Names @('ConvertTo-StrictBoolean', 'Get-CustomRandomOrderEnabled', 'Get-CustomCurrentContext',
             'Step-CustomProgress', 'Test-CustomLapComplete')) {
  Invoke-Expression $definition
}
# 디스크 대신 메모리 노드를 쓰는 스텁 (Save-Config 는 같은 객체를 그대로 들고 있으므로 무동작)
$script:simConfig = [pscustomobject]@{
  lifeCustomRepeat = [pscustomobject]@{
    items           = [array]$sampleItems
    randomOrder     = $false
    listRepeat      = 'count'
    listRepeatCount = 2
    progress        = $null
  }
}
function Read-Config { return $script:simConfig }
function Save-Config { param($Config) }
function Add-GuiLog { param([string]$Message) }
$script:customConfigSection = 'lifeCustomRepeat'

$simTrail = @()
$simLapDone = $false
for ($cycle = 0; $cycle -lt 12; $cycle++) {
  $ctx = Get-CustomCurrentContext -SectionName 'lifeCustomRepeat'
  if (-not $ctx) { $simTrail += 'NULL'; break }
  $simTrail += ('{0}/{1}x{2}' -f [string]$ctx.Item.target, [int]$ctx.Item.rep, [int]$ctx.RegisteredIndex)
  $advanced = Step-CustomProgress -SectionName 'lifeCustomRepeat'
  if (-not $advanced) { $simTrail += 'STEPFAIL'; break }
  if (Test-CustomLapComplete -ListRepeat 'count' -ListRepeatCount 2 -Lap ([int]$advanced.lap)) { $simLapDone = $true; break }
}
Assert-Case '시뮬: 1바퀴 6칸 전부 등장 (횟수만큼 연속)' `
  (($simTrail | Select-Object -First 6) -join ' ') '사과 나무/1x0 사과 나무/2x0 사과 나무/3x0 은광맥/1x1 은광맥/2x1 사과 나무/1x2'
Assert-Case '시뮬: 2바퀴 = 12칸 뒤 완주' $simTrail.Count '12'
Assert-Case '시뮬: 완주 판정 도달' $simLapDone 'True'
Assert-Case '시뮬: 완주 시점 lap 은 3 (전진 후 목표 초과)' ([int]$script:simConfig.lifeCustomRepeat.progress.lap) '3'
# 중간 재시작 이어가기: progress 를 3칸 진행 상태로 두면 4번째 칸(은광맥 1회차)부터여야 합니다
$script:simConfig.lifeCustomRepeat.progress = [pscustomobject]@{
  lap = 1; index = 3; fingerprint = (Get-CustomFingerprint -Items $sampleItems)
}
$resumeCtx = Get-CustomCurrentContext -SectionName 'lifeCustomRepeat'
Assert-Case '시뮬: 이어가기 - 4번째 칸으로 복귀' `
  ('{0} {1}/{2}' -f [string]$resumeCtx.Item.target, [int]$resumeCtx.Item.rep, [int]$resumeCtx.Item.repTotal) '은광맥 1/2'
Assert-Case '시뮬: 이어가기 - Total 은 펼친 6칸' ([int]$resumeCtx.Total) '6'
Assert-Case '시뮬: 이어가기 - RegisteredTotal 은 등록 3개' ([int]$resumeCtx.RegisteredTotal) '3'
Assert-Case '시뮬: 이어가기 - 위치 표기' ([string]$resumeCtx.Position) '1바퀴째 4/6번 (광석 캐기 - 은광맥 1/2회)'
# 범위를 벗어난 index(리스트 축소 등)는 1번으로 되감아야 합니다
$script:simConfig.lifeCustomRepeat.progress = [pscustomobject]@{ lap = 1; index = 99; fingerprint = '' }
$wrapCtx = Get-CustomCurrentContext -SectionName 'lifeCustomRepeat'
Assert-Case '시뮬: 범위 밖 index 는 1번으로' ([int]$wrapCtx.Index) '0'
# 빈 리스트는 컨텍스트 없음 ($null) - 시작 게이트가 빈 리스트를 먼저 막지만 이중 방어
$script:simConfig.lifeCustomRepeat.items = [array]@()
Assert-Case '시뮬: 빈 리스트는 컨텍스트 null' ($null -eq (Get-CustomCurrentContext -SectionName 'lifeCustomRepeat')) 'True'

# ── ⑧ 배선 가드 (GUI) ──
$guiText = [IO.File]::ReadAllText($guiPath)
Assert-Case 'GUI: 컨텍스트가 생활만 펼침' `
  ($guiText.Contains("if (`$isLifeSection) { `$executionItems = @(Expand-LifeCustomItems -Items `$executionItems) }")) 'True'
Assert-Case 'GUI: index 상한 검사는 펼친 개수 확정 뒤' `
  ([bool]($guiText -match "if \(\`$index -lt 0\) \{ \`$index = 0 \}[\s\S]{0,2000}\`$executionTotal = @\(\`$executionItems\)\.Count[\s\S]{0,200}if \(\`$index -ge \`$executionTotal\) \{ \`$index = 0 \}")) 'True'
Assert-Case 'GUI: 전진 칸 수도 펼친 개수' `
  ($guiText.Contains("if (`$SectionName -eq 'lifeCustomRepeat') { `$stepUnitCount = @(Expand-LifeCustomItems -Items `$items).Count }")) 'True'
Assert-Case 'GUI: 층 전환 검사는 생활 제외 (stage 가 없음)' `
  ($guiText.Contains("if (`$SectionName -ne 'abyssCustomRepeat' -and `$SectionName -ne 'lifeCustomRepeat') {")) 'True'
Assert-Case 'GUI: 리스트뷰 매핑에 생활 섹션' `
  ($guiText.Contains("if (`$SectionName -eq 'lifeCustomRepeat') { return `$lvLcrList }")) 'True'
Assert-Case 'GUI: 저장 노드 4키 계약' `
  ((([regex]::Matches($guiText, "items           = \[array\]@\(Get-LifeCustomItemsFromList\)")).Count -eq 1) -and
   ($guiText.Contains("randomOrder     = [bool]`$chkLcrRandom.Checked")) -and
   ($guiText.Contains("listRepeat      = `$(if (`$rbLcrCount.Checked) { 'count' } else { 'infinite' })")) -and
   ($guiText.Contains("listRepeatCount = [int]`$numLcrLaps.Value"))) 'True'
Assert-Case 'GUI: progress 는 옮겨 담기만 (비파괴)' `
  ([bool]($guiText -match "function Set-LifeCustomRepeatOnConfig[\s\S]{0,1600}?progress        = \`$prevProgress")) 'True'
Assert-Case 'GUI: 설정 저장 경로에 생활 섹션 포함' `
  ($guiText.Contains('Set-LifeCustomRepeatOnConfig -Config $cfg')) 'True'
Assert-Case 'GUI: 낚시 등 미지원 스킬은 [추가] 차단' `
  ([bool]($guiText -match "btnLcrAdd\.Add_Click[\s\S]{0,1400}\`$script:lifeSupportedSkillIds -notcontains \[string\]\`$lcrSkill\.Id")) 'True'
Assert-Case 'GUI: config 직접 편집 대비 시작 게이트' `
  ($guiText.Contains('[경고] 생활 커스텀 반복: 아직 지원하지 않는 채집 스킬이 리스트에 있어 시작할 수 없습니다 - 해당 항목을 삭제해 주세요.')) 'True'
Assert-Case 'GUI: 커스텀에서는 슬라이더 시작 게이트 통과' `
  ([bool]($guiText -match "if \(\`$rbCustomRepeat\.Checked\) \{ return \`$false \}[\s\S]{0,200}\`$selectedLifeSkill = ")) 'True'
Assert-Case 'GUI: 생활 전용 마커 경로 (파일은 만들지 않음)' `
  (($guiText.Contains("`$customLifeMarkerFile = Join-Path `$honeyLogDir 'life_custom_done.marker'")) -and
   ($guiText.Contains("`$script:customMarkerFile = `$(if (`$isLifeCustomStart) { `$customLifeMarkerFile }"))) 'True'
Assert-Case 'GUI: 커스텀 화면 카드 높이 26 / 일반 56' `
  ($guiText.Contains("`$lifeCardHeight = `$(if (`$isLifeCustom) { 26 } else { 56 })")) 'True'
Assert-Case 'GUI: 커스텀 화면에서만 아이콘 제거' `
  ($guiText.Contains("`$lifeIconsOff = (`$script:mainCategory -eq 'life') -and `$rbLifeGather.Checked -and `$rbCustomRepeat.Checked")) 'True'
Assert-Case 'GUI: 리스트 치수는 전투 커스텀과 동일 (392x174 / 94x30)' `
  (($guiText.Contains('$lvLcrList.Size = New-Object System.Drawing.Size(392, 174)')) -and
   ($guiText.Contains('$btnLcrAdd.Size = New-Object System.Drawing.Size(94, 30)'))) 'True'
Assert-Case 'GUI: 컬럼 5개 (체크28/#32/스킬96/대상148/횟수46)' `
  (([regex]::Matches($guiText, "\`$lvLcrList\.Columns\.Add\('', 28\)|\`$lvLcrList\.Columns\.Add\('#', 32\)|\`$lvLcrList\.Columns\.Add\('스킬', 96\)|\`$lvLcrList\.Columns\.Add\('대상', 148\)|\`$lvLcrList\.Columns\.Add\('횟수', 46\)")).Count) '5'
Assert-Case 'GUI: 반복 횟수 입력 1~99' `
  (($guiText.Contains('$numLcrCount.Minimum = 1')) -and ($guiText.Contains('$numLcrCount.Maximum = 99'))) 'True'
# 하단 합계 라벨 두 줄 깨짐 (2026-08-08 실기 제보): 라벨 폭은 119px 인데 옛 문구
# '바퀴당 6 · 총 12사이클' 이 127px 라 WinForms Label 의 기본 줄바꿈이 발동, 높이 20 에
# 둘째 줄이 잘려 글자가 겹쳐 보였습니다. 바퀴 수는 바로 왼쪽 입력칸에 있으니 중복이라
# 횟수 모드는 총합만 씁니다. 단위도 '사이클' → '회' (오른쪽 [횟수] 열과 위쪽 [반복 횟수]
# 입력이 이미 '회'라 한 화면에서 같은 것을 두 이름으로 부르지 않게 - 사용자 지적).
Assert-Case 'GUI: 횟수 모드 합계는 총합만 (바퀴당 중복 제거)' `
  ($guiText.Contains("`$lblLcrCycleTotal.Text = ('총 {0:N0}회' -f (`$perLap * [int]`$numLcrLaps.Value))")) 'True'
Assert-Case 'GUI: 무한 모드는 바퀴당 표기 유지 (총합 개념 없음)' `
  ($guiText.Contains("`$lblLcrCycleTotal.Text = ('바퀴당 {0:N0}회' -f `$perLap)")) 'True'
Assert-Case 'GUI: 옛 두 줄 문구 잔재 없음' `
  ($guiText.Contains('바퀴당 {0:N0} · 총 {1:N0}사이클')) 'False'
Assert-Case 'GUI: 합계 라벨 단위는 회로 통일 (사이클 잔재 없음)' `
  ([regex]::Matches($guiText, "\`$lblLcrCycleTotal\.Text = [^\r\n]*사이클").Count) '0'
Assert-Case 'GUI: 합계 라벨 3종 모두 말줄임 (넘쳐도 한 줄 보장)' `
  (($guiText.Contains('$lblLcrCycleTotal.AutoEllipsis = $true')) -and
   ($guiText.Contains('$lblCrCoinTotal.AutoEllipsis = $true')) -and
   ($guiText.Contains('$lblDcrTributeTotal.AutoEllipsis = $true'))) 'True'
Assert-Case 'GUI: 커스텀 시작 로그 (리스트 위치 + 항목 내 회차)' `
  ($guiText.Contains("Add-GuiLog ('[커스텀] {0}/{1} {2} - {3} ({4}/{5}회)' -f")) 'True'
Assert-Case 'GUI: 스냅샷은 등록 목록 (펼친 목록 아님)' `
  ([bool]($guiText -match "if \(\`$script:customConfigSection -eq 'lifeCustomRepeat'\) \{[\s\S]{0,300}Get-LifeCustomListCompact -Items \`$customContext\.Items")) 'True'

# ── ⑧b 셀 편집 진리표 (2026-08-08 신설) ──
# 생활만의 난제: 스킬과 대상이 종속 관계라, 스킬을 바꾸면 이전 대상이 새 스킬에 없을 수 있다.
# 그대로 두면 워커가 스킬 창에서 대상 행을 못 찾아 그 항목 차례에 반드시 멈춘다.
$editDaily = [pscustomobject]@{ kind = 'life'; skill = 'daily'; target = '사과 나무'; count = 3 }
$editHerb = [pscustomobject]@{ kind = 'life'; skill = 'herb'; target = '허브'; count = 1 }
$editFishing = [pscustomobject]@{ kind = 'life'; skill = 'fishing'; target = '민물고기'; count = 1 }
$editBroken = [pscustomobject]@{ kind = 'life'; skill = 'daily'; target = '광맥'; count = 3 }
$editUnknown = [pscustomobject]@{ kind = 'life'; skill = 'zzz'; target = '아무개'; count = 2 }

# 편집 불가 열 (기존 3리스트가 전부 갖고 있는 케이스)
Assert-Case '편집: 체크 열은 편집 불가' ($null -eq (Get-LcrCellEditPlan -ColumnIndex 0 -Item $editDaily)) 'True'
Assert-Case '편집: # 열은 편집 불가' ($null -eq (Get-LcrCellEditPlan -ColumnIndex 1 -Item $editDaily)) 'True'
Assert-Case '편집: 범위 밖 열은 편집 불가' ($null -eq (Get-LcrCellEditPlan -ColumnIndex 5 -Item $editDaily)) 'True'
# 스킬 열: 지원 8종만 (셀 편집이 [추가]·시작 게이트의 낚시 차단을 우회하면 안 됨)
$planSkill = Get-LcrCellEditPlan -ColumnIndex 2 -Item $editDaily
Assert-Case '편집: 스킬 옵션 8개 (낚시 제외)' (@($planSkill.Options).Count) '8'
Assert-Case '편집: 스킬 옵션에 낚시 없음' (@($planSkill.Options) -contains '낚시') 'False'
Assert-Case '편집: 스킬 현재값은 표시명 (Id 아님)' ([string]$planSkill.Current) '일상 채집'
Assert-Case '편집: 스킬 옵션은 표시명' (@($planSkill.Options)[0]) '일상 채집'
# 미지원 스킬 행은 '지금 값'을 볼 수 있게 끝에 덧붙임 (앞에 넣으면 고르라는 것처럼 보임)
$planFish = Get-LcrCellEditPlan -ColumnIndex 2 -Item $editFishing
Assert-Case '편집: 낚시 행은 현재값을 끝에 덧붙여 9개' (@($planFish.Options).Count) '9'
Assert-Case '편집: 덧붙인 현재값은 마지막' (@($planFish.Options)[8]) '낚시'
Assert-Case '편집: 낚시 행도 스킬 열은 편집 가능 (유일한 복구 경로)' ($null -ne $planFish) 'True'
# 대상 열: 그 행의 스킬이 가진 목록만 (행 상태의 함수)
Assert-Case '편집: 대상 옵션 = daily 10개' (@((Get-LcrCellEditPlan -ColumnIndex 3 -Item $editDaily).Options).Count) '10'
Assert-Case '편집: 대상 옵션 = herb 16개 (스킬 따라 바뀜)' (@((Get-LcrCellEditPlan -ColumnIndex 3 -Item $editHerb).Options).Count) '16'
Assert-Case '편집: 손상 행은 현재값을 끝에 덧붙여 11개' (@((Get-LcrCellEditPlan -ColumnIndex 3 -Item $editBroken).Options).Count) '11'
Assert-Case '편집: 손상 행 덧붙인 값은 마지막' (@((Get-LcrCellEditPlan -ColumnIndex 3 -Item $editBroken).Options)[10]) '광맥'
Assert-Case '편집: 모르는 스킬 Id 행의 대상 열은 편집 불가' ($null -eq (Get-LcrCellEditPlan -ColumnIndex 3 -Item $editUnknown)) 'True'
# 횟수 열
$planCount = Get-LcrCellEditPlan -ColumnIndex 4 -Item $editDaily
Assert-Case '편집: 횟수 옵션 99개' (@($planCount.Options).Count) '99'
Assert-Case '편집: 횟수 현재값 표기' ([string]$planCount.Current) '3회'
Assert-Case '편집: 횟수 현재값도 클램프 (0 → 1회)' `
  ([string](Get-LcrCellEditPlan -ColumnIndex 4 -Item ([pscustomobject]@{ skill = 'daily'; target = '둥지'; count = 0 })).Current) '1회'
Assert-Case '편집: 횟수 현재값도 클램프 (300 → 99회)' `
  ([string](Get-LcrCellEditPlan -ColumnIndex 4 -Item ([pscustomobject]@{ skill = 'daily'; target = '둥지'; count = 300 })).Current) '99회'
# 현재값이 항상 옵션 안에 있어야 콤보(DropDownList)에서 선택이 비지 않음
$currentInOptions = $true
foreach ($editCase in @($editDaily, $editHerb, $editFishing, $editBroken)) {
  foreach ($editCol in @(2, 3, 4)) {
    $casePlan = Get-LcrCellEditPlan -ColumnIndex $editCol -Item $editCase
    if ($null -eq $casePlan) { continue }
    if (@($casePlan.Options) -notcontains [string]$casePlan.Current) { $currentInOptions = $false }
  }
}
Assert-Case '편집: 현재값은 언제나 옵션 안에' $currentInOptions 'True'
# Scope 키는 어비스 전용 (리스트 전체 일괄) - 생활은 스킬 혼합이 자유라 전 열이 행 단위
$noScope = $true
foreach ($editCol in @(2, 3, 4)) {
  $scopePlan = Get-LcrCellEditPlan -ColumnIndex $editCol -Item $editDaily
  if ($null -ne $scopePlan -and $null -ne $scopePlan.Scope) { $noScope = $false }
}
Assert-Case '편집: Scope 키 없음 (전부 행 단위)' $noScope 'True'

# 적용(Set) - 스킬↔대상 종속 규칙
$setA = Set-LcrItemCellValue -Item $editDaily -ColumnIndex 2 -Value '광석 캐기'
Assert-Case '적용: 스킬 변경 시 없는 대상은 새 스킬 첫 대상으로' `
  ('{0}/{1}/{2}' -f $setA.skill, $setA.target, $setA.count) ('mining/{0}/3' -f @(Get-LifeSkillTargets -SkillId 'mining')[0])
$setB = Set-LcrItemCellValue -Item $editDaily -ColumnIndex 2 -Value '일상 채집'
Assert-Case '적용: 같은 스킬 재선택은 3필드 그대로 (변경 없음 = 조용히 끝)' `
  ('{0}/{1}/{2}' -f $setB.skill, $setB.target, $setB.count) 'daily/사과 나무/3'
$setC = Set-LcrItemCellValue -Item $editBroken -ColumnIndex 4 -Value '5회'
Assert-Case '적용: 손상 행은 횟수만 고쳐도 대상이 수리됨' `
  ('{0}/{1}/{2}' -f $setC.skill, $setC.target, $setC.count) 'daily/둥지/5'
$setD = Set-LcrItemCellValue -Item $editDaily -ColumnIndex 3 -Value '차나무'
Assert-Case '적용: 대상만 변경 시 스킬·횟수 유지' `
  ('{0}/{1}/{2}' -f $setD.skill, $setD.target, $setD.count) 'daily/차나무/3'
Assert-Case '적용: 횟수 0회는 1로 클램프' `
  ([int](Set-LcrItemCellValue -Item $editDaily -ColumnIndex 4 -Value '0회').count) '1'
Assert-Case '적용: 횟수 300회는 99로 클램프' `
  ([int](Set-LcrItemCellValue -Item $editDaily -ColumnIndex 4 -Value '300회').count) '99'
Assert-Case '적용: kind 는 항상 life' `
  ([string](Set-LcrItemCellValue -Item $editDaily -ColumnIndex 3 -Value '차나무').kind) 'life'
Assert-Case '적용: 모르는 표시명이면 이전 스킬 유지 (빈 값 저장 방지)' `
  ([string](Set-LcrItemCellValue -Item $editDaily -ColumnIndex 2 -Value '???').skill) 'daily'
Assert-Case '적용: 모르는 스킬 Id 행의 대상은 파괴하지 않음' `
  ([string](Set-LcrItemCellValue -Item $editUnknown -ColumnIndex 4 -Value '5회').target) '아무개'
Assert-Case '적용: 입력 항목은 변형되지 않음 (순수)' ([string]$editDaily.target) '사과 나무'

# 배선 가드 - 셀 편집
Assert-Case 'GUI: 생활 리스트에 MouseUp 연결' `
  ($guiText.Contains('$lvLcrList.Add_MouseUp($cellEditMouseUp)')) 'True'
Assert-Case 'GUI: 연결은 리스트 생성 뒤 (시작 크래시 방지)' `
  ($guiText.IndexOf('$lvLcrList = New-Object') -lt $guiText.IndexOf('$lvLcrList.Add_MouseUp($cellEditMouseUp)')) 'True'
# 예전 디스패처의 마지막 else 는 조건 없는 '어비스 폴백'이라, 새 리스트를 연결하면 그 클릭이
# 어비스 계획을 타 엉뚱한 옵션이 뜨고(계획) 어비스 리스트를 통째로 바꾼다(적용).
Assert-Case 'GUI: 계획·적용 둘 다 생활 명시 분기' `
  (($guiText.Contains('} elseif ($clickSender -eq $lvLcrList) {')) -and
   ($guiText.Contains('} elseif ($applyList -eq $lvLcrList) {'))) 'True'
Assert-Case 'GUI: 어비스도 명시 분기로 좁힘' `
  (($guiText.Contains('} elseif ($clickSender -eq $lvAcrList) {')) -and
   ($guiText.Contains('} elseif ($applyList -eq $lvAcrList) {'))) 'True'
Assert-Case 'GUI: 어비스 else 폴백 잔재 없음 (계획)' `
  ([bool]($guiText -match '\} else \{\s*\r?\n\s*\$cellItems = @\(Get-AbyssCustomItemsFromList\)')) 'False'
Assert-Case 'GUI: 어비스 else 폴백 잔재 없음 (적용)' `
  ([bool]($guiText -match '\} else \{\s*\r?\n\s*Invoke-AcrCellEdit')) 'False'
Assert-Case 'GUI: 셔플 표시 중 편집 봉인 (좌표계 어긋남 방지) - 단일 지점' `
  ([regex]::Matches($guiText, 'if \(\$script:crLoading -or \$script:running -or \$script:customViewShuffled\) \{ return \}').Count) '1'
# 롤백에서 부르면 죽거나 비가역인 것들: Update-CustomRepeatMixLock 은 $script:crMixLockState 에
# 'lcr' 키가 없어 $null 참조 예외, Update-CustomRandomMixGate 는 생활에 없는 stage 에 의존하고
# 내부에서 진행 기록·마커를 지울 수 있다. 함수 본문만 잘라 검사한다.
$lcrEditStart = $guiText.IndexOf('function Invoke-LcrCellEdit {')
$lcrEditEnd = $guiText.IndexOf("`nfunction ", $lcrEditStart + 10)
$lcrEditBody = $(if ($lcrEditStart -ge 0 -and $lcrEditEnd -gt $lcrEditStart) { $guiText.Substring($lcrEditStart, $lcrEditEnd - $lcrEditStart) } else { '' })
Assert-Case 'GUI: 셀 편집 적용 함수 본문을 찾음' ($lcrEditBody.Length -gt 200) 'True'
# 주석 줄은 걷어냅니다 - 함수 머리 주석이 '부르면 안 되는 함수'를 이름으로 경고하고 있어
# 그대로 검사하면 경고문 자체를 호출로 오인합니다 (실제 호출만 봐야 함)
$lcrEditCode = (@($lcrEditBody -split "`n") | Where-Object { $_.TrimStart() -notlike '#*' }) -join "`n"
Assert-Case 'GUI: 롤백에 혼합 잠금·랜덤 게이트를 부르지 않음 (lcr 키 없음/비가역)' `
  (($lcrEditCode -notmatch 'Update-CustomRepeatMixLock') -and
   ($lcrEditCode -notmatch 'Update-CustomRandomMixGate') -and
   ($lcrEditCode -notmatch 'Reset-CustomProgress')) 'True'
Assert-Case 'GUI: 롤백은 행 복원 → 합계 라벨 순서' `
  ([bool]($lcrEditBody -match 'Set-LifeListRowTexts -Row \$lvLcrList\.Items\[\$RowIndex\] -Item \$beforeItem[\s\S]{0,200}Update-LifeCustomTotalLabel')) 'True'
Assert-Case 'GUI: 저장 실패 무장은 저장 직전 $true' `
  ([bool]($lcrEditBody -match '\$script:lastCustomSaveOk = \$true\s*\r?\n\s*if \(\$script:uiReady\) \{ Save-LifeCustomRepeatToConfig \}')) 'True'
Assert-Case 'GUI: 표시 규칙 단일 소스 - 추가 1 + 편집 2 = 3곳' `
  ([regex]::Matches($guiText, 'Set-LifeListRowTexts -Row').Count) '3'
# 드롭다운 자동 펼침이 실제로는 죽어 있었음 (2026-08-08 실측): 함수 안에서 만든
# GetNewClosure 클로저는 $script: 변수를 $null 로 읽어 세션 검사가 항상 참 -> 즉시 return.
Assert-Case 'GUI: 드롭다운 펼침 검사는 함수로 (클로저에서 $script: 는 null)' `
  (($guiText.Contains('Open-CellEditDropDown -ExpectedSession $openSession')) -and
   ($guiText.Contains('function Open-CellEditDropDown {'))) 'True'
Assert-Case 'GUI: 클로저 안에 $script: 세션 검사 잔재 없음' `
  ($guiText.Contains('if ([int]$script:cellEditSession -ne $openSession) { return }')) 'False'
Assert-Case 'GUI: 긴 목록도 펼쳐 보이게 (99개 횟수/16개 대상)' `
  ($guiText.Contains('$script:cellEditCombo.MaxDropDownItems = [Math]::Max(8, [Math]::Min(16, @($Options).Count))')) 'True'

# ── ⑨ 배선 가드 (워커) ──
$workerText = [IO.File]::ReadAllText($workerPath)
Assert-Case '워커: 생활 커스텀 토큰으로 스킬/대상 오버라이드' `
  ([bool]($workerText -match "\`$lifeCustomParts\[0\] -eq 'L'[\s\S]{0,400}\`$lifeSkillId = \[string\]\`$lifeCustomParts\[1\][\s\S]{0,80}\`$lifeTargetName = \[string\]\`$lifeCustomParts\[2\]")) 'True'
Assert-Case '워커: 대분류가 생활일 때만 파싱' `
  ($workerText.Contains("if (`$mainCategory -eq 'life' -and -not [string]::IsNullOrWhiteSpace(`$env:HONEYNOGI_CUSTOM_ITEM)) {")) 'True'
Assert-Case '워커: 토큰 깨지면 config 값으로 진행하지 않고 오류' `
  (($workerText.Contains('$script:lifeCustomSpecInvalid = $true')) -and
   ($workerText.Contains('throw "생활 커스텀 반복 항목 형식이 올바르지 않습니다'))) 'True'
Assert-Case '워커: 커스텀이면 채집으로 고정 (가공 리스트 없음)' `
  ($workerText.Contains("`$lifeContent = 'gather'   # 커스텀 리스트는 채집 전용 (가공은 리스트 자체가 없음)")) 'True'
Assert-Case '워커: [설정] 스냅샷에 생활 커스텀 줄' `
  ($workerText.Contains('[설정] 생활 커스텀 리스트: ')) 'True'

# ── ⑩ config 기본 키 ──
$configJson = Get-Content (Join-Path $projectRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Case 'config: lifeCustomRepeat 섹션 존재' ($null -ne $configJson.lifeCustomRepeat) 'True'
Assert-Case 'config: items 기본 빈 배열' (@($configJson.lifeCustomRepeat.items).Count) '0'
Assert-Case 'config: listRepeat 기본 infinite' ([string]$configJson.lifeCustomRepeat.listRepeat) 'infinite'
Assert-Case 'config: listRepeatCount 기본 1' ([int]$configJson.lifeCustomRepeat.listRepeatCount) '1'
Assert-Case 'config: randomOrder 기본 false' ($configJson.lifeCustomRepeat.randomOrder -eq $false) 'True'
Assert-Case 'config: progress 기본 null' ($null -eq $configJson.lifeCustomRepeat.progress) 'True'

exit $fails
