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
  '결과/선택 화면 도달 = 현재 어비스 항목의 클리어 확정[\s\S]{0,300}Write-CustomClearMarker'
Check-Pattern '수동 진행분 정리 후 코드 10' `
  'Return-ToAbyssSelection -Game \$game[\s\S]{0,150}customCleanupOnly\) \{ exit 10 \}'
Check-Pattern '완료 복구에서 선택 화면이면 재입장 없이 완료' `
  'customRecoveryOnly -and \(Test-AbyssSelectionScreen[\s\S]{0,250}exit 0'
Check-Pattern '완료 복구에서 상세 화면도 선택 화면으로 복귀' `
  'customRecoveryOnly -and -not \$startInsideDetected[\s\S]{0,1200}완료 항목 재입장 없이 복구 완료[\s\S]{0,80}exit 0'

exit $fails
