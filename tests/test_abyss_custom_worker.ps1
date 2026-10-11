# 어비스 커스텀 항목 파싱·설정 오버라이드·완료 복구 계약을 검사합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('ConvertFrom-AbyssCustomItemSpec', 'Format-AbyssCustomItemLabel', 'Test-CustomCleanupOnly')) {
  Invoke-Expression $definition
}

# ★ 10차 추가 계약: 어비스 시작 상태를 **재판독으로 뒤집을 때는 그 값에 매달린 판단도
#   함께 다시 내려야 합니다.** $startInsideDetected 만 덮어쓰고 customCleanupOnly /
#   recoveryOnly 가드를 그대로 두면, 첫 판독이 OCR 플레이크로 '밖'이었다가 재판독에서
#   '안'으로 읽히는 순간 **사용자가 손으로 돌던 판이 자동 회차로 계상**됩니다
#   (수동 진행분 오계상 방지 장치가 통째로 무력화 - 9차 수정이 만든 구멍을 10차에서 발견).
$abyssWorkerText = [IO.File]::ReadAllText($workerPath)
if ($abyssWorkerText -match '(?s)if \(\$fieldHudNow -and \$fieldQuestNow -and -not \$startInsideDetected\) \{[\s\S]{0,900}?\$script:customCleanupOnly = Test-CustomCleanupOnly[\s\S]{0,400}?customRecoveryOnly[\s\S]{0,200}?throw ') {
  "OK   배선: 재판독으로 '던전 안'이 되면 커스텀 판단을 다시 내린다"
} else {
  "FAIL 배선: 재판독 후 customCleanupOnly/recoveryOnly 재계산이 없습니다"; $fails++
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function Describe-AbyssItem {
  param($Item)
  if ($null -eq $Item) { return 'null' }
  return ('{0}/{1}/{2}/{3}' -f $Item.Mode, $Item.Difficulty, $Item.Dungeon, $Item.Matching)
}

Assert-Case '혼자하기 파싱' `
  (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|solo|게임 그대로|허상의 정박지|없음')) `
  'solo/게임 그대로/허상의 정박지/없음'
Assert-Case '함께하기 우연한 만남 파싱' `
  (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|party|어려움|광기의 동굴|우연한 만남')) `
  'party/어려움/광기의 동굴/우연한 만남'
Assert-Case '파티 찾기 공백 표기 정규화' `
  (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|party|매우 어려움|흩어진 물길|파티 찾기')) `
  'party/매우 어려움/흩어진 물길/파티찾기'
Assert-Case '파티장 파싱' `
  (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|party|지옥1|허상의 정박지|파티(파티장)')) `
  'party/지옥1/허상의 정박지/파티(파티장)'
Assert-Case '잘못된 접두사 거부' (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'D|solo|어려움|허상의 정박지|없음')) 'null'
Assert-Case '잘못된 입장 방식 거부' (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|member|어려움|허상의 정박지|없음')) 'null'
Assert-Case '함께하기의 미지원 매칭 거부' (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|party|어려움|허상의 정박지|파티(파티원)')) 'null'
Assert-Case '난이도 빈 값 거부' (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|solo||허상의 정박지|없음')) 'null'
Assert-Case '혼자하기 지옥 난이도 거부' (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|solo|지옥1|허상의 정박지|없음')) 'null'
Assert-Case '지원하지 않는 난이도 거부' (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|party|전설|허상의 정박지|우연한 만남')) 'null'
Assert-Case '지원하지 않는 어비스 거부' (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|solo|어려움|미등록 던전|없음')) 'null'
Assert-Case '조각 수 오류 거부' (Describe-AbyssItem (ConvertFrom-AbyssCustomItemSpec 'A|solo|어려움|허상의 정박지')) 'null'

$partyItem = ConvertFrom-AbyssCustomItemSpec 'A|party|어려움|광기의 동굴|우연한 만남'
$soloItem = ConvertFrom-AbyssCustomItemSpec 'A|solo|게임 그대로|허상의 정박지|없음'
Assert-Case '함께하기 로그 라벨' (Format-AbyssCustomItemLabel $partyItem) "함께하기 어려움 광기의 동굴, 매칭 '우연한 만남'"
Assert-Case '혼자하기 로그 라벨' (Format-AbyssCustomItemLabel $soloItem) '혼자하기 게임 그대로 허상의 정박지'

Assert-Case '새 시작+어비스 내부는 준비 실행' (Test-CustomCleanupOnly $true $false $true $false) $true
Assert-Case '오류 재시작+어비스 내부는 항목 계상' (Test-CustomCleanupOnly $true $true $true $false) $false
Assert-Case '새 시작+결과 화면은 준비 실행' (Test-CustomCleanupOnly $true $false $false $true) $true

$worker = Get-Content -LiteralPath $workerPath -Raw -Encoding UTF8
function Check-Pattern {
  param([string]$Name, [string]$Pattern)
  if ($worker -match $Pattern) { "OK   $Name" }
  else { "FAIL $Name"; $script:fails++ }
}

Check-Pattern '항목 던전이 프로파일 선택 전에 적용됨' `
  'abyssCustomPreparsed[\s\S]{0,500}\$selectedDungeon\s*=\s*\[string\]\$script:abyssCustomPreparsed\.Dungeon[\s\S]{0,1000}\$builtinDungeonCards'
Check-Pattern '어비스 항목이 입장 방식·매칭·난이도 덮어씀' `
  '\$dungeonMode\s*=\s*\[string\]\$script:abyssCustomPreparsed\.Mode[\s\S]{0,300}\$abyssMatching\s*=\s*\[string\]\$script:abyssCustomPreparsed\.Matching[\s\S]{0,400}\$dungeonDifficulty'
Check-Pattern '클리어 확정 후 완료 마커 기록' `
  '결과 화면 도달 = 현재 어비스 항목의 클리어 확정[\s\S]{0,700}Write-CustomClearMarker'
# 2026-08-01: Return-ToAbyssSelection 에 -SafeStopExitCode 가 추가되어 호출부가 길어짐
# (준비/정리 실행 중 안전 중지도 회차로 계상하지 않는 계약 - 거리 상한 완화)
Check-Pattern '수동 진행분 정리 후 코드 10' `
  'Return-ToAbyssSelection -Game \$game[\s\S]{0,320}customCleanupOnly\) \{ exit 10 \}'
Check-Pattern '안전 중지 종료 코드가 호출 문맥을 따름' `
  'Return-ToAbyssSelection -Game \$game -SafeStopExitCode 10[\s\S]{0,400}exit 10'
# 2026-09-30 ⑥e 설계 2.14(09-30 리뷰5 P1-1, 사용자 결정 D7): 완료 항목 마무리 복구 워커는 새 워커라 선택 화면 출처(워커 자신의 '어비스' 클릭)가
#   없습니다 - 선택 화면·상세 화면은 던전 안 오버레이로도 열려(09-20 실사고) 모양만으로는 던전 밖의 증거가 아닙니다. 옛 '재입장 없이 복구 완료'
#   (코드 0 → GUI 가 다음 항목 시작)는 오버레이에서 다음 항목으로 넘어갈 수 있었습니다 → 진단 캡처 + 코드 4 (GUI 는 유효 마커로 계상·전진 뒤 정지).
#   두 블록 안에 exit 0 은 0건이어야 합니다 (되돌림 변이 검출 - 블록은 앵커부터 그 블록의 exit 4 까지)
function Check-RecoveryBlock {
  param([string]$Name, [string]$Pattern)
  $m = [regex]::Match($worker, $Pattern)
  if ($m.Success -and ($m.Value -notmatch '(?m)^\s*exit 0\s*$')) { "OK   $Name" }
  else { "FAIL $Name (일치=$($m.Success), 블록 안 exit 0=$([regex]::Matches($m.Value, '(?m)^\s*exit 0\s*$').Count))"; $script:fails++ }
}
Check-RecoveryBlock '완료 복구가 선택 화면에서 시작하면 출처 없음 코드 4(재입장·복구 완료 없음)' `
  'customRecoveryOnly -and \(Test-AbyssSelectionScreen[\s\S]{0,400}Write-LifeDiagnostics[\s\S]{0,400}exit 4'
# 2026-09-10: 이 분기의 뒤로가기가 상태 기반 재클릭 헬퍼로 바뀌면서 근거 주석이 붙어 구간이
# 1200 → 1386자가 됐습니다(재클릭 허가·전면화 보존·재클릭 간격의 이유). 계약 자체는 그대로라
# 상한만 넓힙니다 - 뒤로가기 동작의 세부 계약은 tests\test_abyss_detail_back.ps1 이 봅니다.
# 2026-09-30 ⑥e: '<' 클릭(관측된 전이)은 그대로 두고 그 뒤 완료 대신 진단 + 코드 4 (구현 뒤 실측 창: 앵커 → 뒤로가기 1028자, 뒤로가기 →
#   진단 522자, 진단 → exit 4 172자 - 창 1600/900/400 안)
Check-RecoveryBlock '완료 복구가 상세 화면에서 시작하면 뒤로가기 뒤 출처 없음 코드 4' `
  'customRecoveryOnly -and -not \$startInsideDetected[\s\S]{0,1600}Invoke-ClickUntil -Game \$game -Point \$ptDetailBack[\s\S]{0,900}Write-LifeDiagnostics[\s\S]{0,400}exit 4'
Check-Pattern '완료 복구 두 블록의 옛 복구 완료 문구 0건 (어비스 선택·상세 경로)' `
  '^(?![\s\S]*(어비스 선택 화면이 이미 준비돼 있습니다 - 완료 항목 재입장 없이 복구 완료|어비스 상세 화면에서 선택 화면으로 복귀 - 완료 항목 재입장 없이 복구 완료))'

# ── 완료 마커 기록 함수의 반환값 (2026-10-09 구현 명세 ① 2.10 W5 · 5절 A9) ──
# 기록함 $true · 경로가 빈 값 $true(GUI 가 이번 회차 마커를 일부러 비움 - 기록 대상이 아니라 실패가 아님) · 소유자 정보 없음 $false · 쓰기 20회 실패
# $false. 결과를 실제로 받는 호출은 뒤 단위(⑤ - 다시 하기 가능 여부)에서 생기고, 지금 호출 4곳은 [void] 로 버립니다 - 감싸지 않으면 반환값이 그 자리의
# 출력으로 흘러(던전 사이클 함수 안이면 그 함수의 반환값에 섞임) 오염시킵니다(명세 리뷰 2 P3). 실제 함수를 추출해 임시 파일로 돌리고 Write-RunLog 는
# 줄을 모으는 모의입니다. 20회 실패는 이 프로세스가 마커 파일을 FileShare.None 으로 쥐어 Set-Content 가 매번 막히게 합니다(재시도 사이 대기는 그 행 동안
# Start-Sleep 모의로 셈 - 실제로는 자지 않음, 20번·합 1000ms 단언).
$markerDefinitionText = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Write-CustomClearMarker'))
# 마커 함수 안 exit 문 0 (단계 2.10 구현 검증 - 생존 변이 e3): 마커를 못 써도 같은 판의 본류(완료 기록 · 나가기 · 복귀)가 이어져야 합니다. 이 회귀는 함수를
# 같은 프로세스에서 부르므로 exit 가 들면 아래 행이 단언 없이 끝나 통과로 보입니다 - 그래서 동작 행보다 먼저 정적으로 봅니다
$markerDefinitionAst = [System.Management.Automation.Language.Parser]::ParseInput($markerDefinitionText, [ref]$null, [ref]$null)
Assert-Case 'W5 마커 함수 정의 1 · 그 안 exit 문 0(동작 행보다 먼저)' `
  ('{0}/{1}' -f @($markerDefinitionAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)).Count,
    @($markerDefinitionAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count) '1/0'
Invoke-Expression $markerDefinitionText
$script:markerLogLines = New-Object System.Collections.Generic.List[string]
function Write-RunLog {
  param([string]$Message)
  $script:markerLogLines.Add($Message)
}
$markerFolder = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_marker_return_' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($markerFolder)
$markerOwnerJson = '{"version":3,"fingerprint":"A|solo|어려움|허상의 정박지|없음","orderKey":"","lap":1,"index":0,"item":"A|solo|어려움|허상의 정박지|없음","generation":2}'
function Invoke-MarkerReturnRow {
  # 한 행 = 마커 경로·소유자 JSON 을 두고 실제 함수 1번 → '반환값 개수/형식/값 · 로그' (파일 내용은 부른 쪽이 잡은 파일을 놓은 뒤 Get-MarkerFileText 로)
  param([string]$MarkerPath, [string]$OwnerJson)
  $script:customMarkerPath = $MarkerPath
  $script:customOwnerJson = $OwnerJson
  $script:markerLogLines.Clear()
  $output = @(Write-CustomClearMarker)
  $firstType = $(if ($output.Count -gt 0 -and $null -ne $output[0]) { $output[0].GetType().Name } else { '(없음)' })
  return ('{0}개/{1}/{2} · [{3}]' -f $output.Count, $firstType, ($output -join ','), (@($script:markerLogLines) -join ' | '))
}
function Get-MarkerFileText {
  param([string]$MarkerPath)
  if ($MarkerPath -and [IO.File]::Exists($MarkerPath)) { return ([IO.File]::ReadAllText($MarkerPath)).Trim() }
  return '(파일 없음)'
}
try {
  $writtenPath = Join-Path $markerFolder 'written.marker'
  $writtenRow = Invoke-MarkerReturnRow -MarkerPath $writtenPath -OwnerJson $markerOwnerJson
  Assert-Case 'W5 기록함 → $true 하나 · 기록 줄 · 파일 = 소유자 JSON' ('{0} · {1}' -f $writtenRow, (Get-MarkerFileText $writtenPath)) `
    ('1개/Boolean/True · [[커스텀] 완료 마커 기록 (결과 화면 도달)] · {0}' -f $markerOwnerJson)
  Assert-Case 'W5 경로 빈 값(GUI 가 일부러 비움) → $true 하나 · 로그 0' (Invoke-MarkerReturnRow -MarkerPath '' -OwnerJson $markerOwnerJson) `
    '1개/Boolean/True · []'
  $noOwnerPath = Join-Path $markerFolder 'no-owner.marker'
  $noOwnerRow = Invoke-MarkerReturnRow -MarkerPath $noOwnerPath -OwnerJson ''
  Assert-Case 'W5 소유자 정보 없음 → $false 하나 · 경고 1줄 · 파일 없음' ('{0} · {1}' -f $noOwnerRow, (Get-MarkerFileText $noOwnerPath)) `
    '1개/Boolean/False · [[경고] 완료 마커 소유자 정보가 없어 마커를 기록하지 않습니다 - GUI/워커 버전을 확인해 주세요] · (파일 없음)'
  $heldPath = Join-Path $markerFolder 'held.marker'
  [IO.File]::WriteAllText($heldPath, 'held-before')
  $heldStream = [IO.File]::Open($heldPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  # 재시도 사이 대기를 셉니다(단계 2.10 구현 검증 - 생존 변이 r13): 본문 무변경 계약(명세 2.10 W5 - 20회 Set-Content · 실패마다 50ms)이라 결과값만 보면
  # 재시도 횟수를 줄여도 같은 $false 가 나옵니다. 이 행 동안만 Start-Sleep 을 같은 이름 함수로 가립니다(실제로는 자지 않음)
  $script:markerSleepCalls = 0
  $script:markerSleepMs = 0
  function Start-Sleep {
    param([int]$Seconds = 0, [int]$Milliseconds = 0)
    $script:markerSleepCalls++
    $script:markerSleepMs += $Milliseconds + ($Seconds * 1000)
  }
  try {
    $heldRow = Invoke-MarkerReturnRow -MarkerPath $heldPath -OwnerJson $markerOwnerJson
  } finally {
    $heldStream.Dispose()
    Remove-Item -Path 'Function:\Start-Sleep'
  }
  Assert-Case 'W5 쓰기 20회 실패(다른 쪽이 마커 파일을 쥠) → $false 하나 · 실패 경고 1줄 · 파일 그대로' ('{0} · {1}' -f $heldRow, (Get-MarkerFileText $heldPath)) `
    '1개/Boolean/False · [[경고] 완료 마커 기록에 실패했습니다 - 정상 종료면 GUI가 종료 코드로 계상하므로 진행을 계속합니다] · held-before'
  Assert-Case 'W5 쓰기 20회 실패 → 재시도 사이 대기 20번 · 합 1000ms(본문 그대로 - 20회 · 실패마다 50ms)' ('{0}번/{1}ms' -f $script:markerSleepCalls, $script:markerSleepMs) '20번/1000ms'
} finally {
  try { [IO.Directory]::Delete($markerFolder, $true) } catch { "참고: 임시 폴더 정리 실패 - $($_.Exception.Message)" }
}
# 호출 4곳(던전 사이클 1 · 어비스 보상 화면 시작 1 · 클리어 화면 시작 1 · 본류 1)은 전부 [void](…) 로 반환값을 버림 - 감싸지 않은 호출 0
# (주석 뺀 사본의 AST - 호출 소유자 함수와 감싼 모양을 함께 봅니다)
$markerWorkerAst = [System.Management.Automation.Language.Parser]::ParseInput((Remove-SourceComments -Text $worker), [ref]$null, [ref]$null)
$markerCalls = @($markerWorkerAst.FindAll({ param($node)
      ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Write-CustomClearMarker') }, $true))
$markerCallShapes = foreach ($markerCall in $markerCalls) {
  $ownerNode = $markerCall.Parent
  while ($ownerNode -and -not ($ownerNode -is [System.Management.Automation.Language.FunctionDefinitionAst])) { $ownerNode = $ownerNode.Parent }
  $wrapped = ($markerCall.Parent -is [System.Management.Automation.Language.PipelineAst]) -and
    ($markerCall.Parent.Parent -is [System.Management.Automation.Language.ParenExpressionAst]) -and
    ($markerCall.Parent.Parent.Parent -is [System.Management.Automation.Language.ConvertExpressionAst]) -and
    ($markerCall.Parent.Parent.Parent.Type.TypeName.Name -eq 'void')
  '{0}:{1}' -f $(if ($ownerNode) { $ownerNode.Name } else { '(최상위)' }), $(if ($wrapped) { '[void]' } else { '감싸지 않음' })
}
Assert-Case 'W5 호출 4곳 전부 [void](Write-CustomClearMarker) (던전 사이클 1 · 최상위 흐름 3)' ((@($markerCallShapes) | Sort-Object) -join ', ') `
  '(최상위):[void], (최상위):[void], (최상위):[void], Invoke-NormalDungeonCycle:[void]'

exit $fails
