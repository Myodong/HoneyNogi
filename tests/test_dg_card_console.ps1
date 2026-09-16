# 심층 소탕 카드 콘솔 렌더 대응 (2026-09-07 RDP→콘솔 실사고 - v2.1.6)
# 본체: mabinogi_run_once.ps1 (Get-DgOffAnchorFallbackDecision / Test-DgOffClearedBySequence /
#       Set-DgToggleCard UnknownWordPoint / Save-DgCardDiagnostics 배선)
# 사고: 콘솔 전환 후 '선택됨'이 결정적으로 깨져(09-06 창 1024·09-07 창 1908 동일 문자열
#       '人에E}1되', 40회 판독 전부) 판별 실패 → 해제 클릭 불가 → 코드 4 정지.
# 실측 캡처 보존: 던전이미지\던전\20260907_심층옵션_소탕선택됨_1908.png
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$workerSource = [IO.File]::ReadAllText($workerPath)
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Get-DgOffAnchorFallbackDecision', 'Test-DgOffClearedBySequence')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ---- 1. 판정 조각 실측 진리표 (판정식 사본 - 소스와 조각 동기화 앵커 포함) ----
# 09-07 에는 조각을 넓히지 않고 폴백에 맡기기로 했고, 09-16 에 콘솔 프레임 12장 + 보관 캡처 118장 오탐 스윕을
# 근거로 조각 '태되' 하나만 추가했습니다 (test_dg_card_console_offline 이 프레임 재현을 고정). 그 외 unknown
# 문자열은 여전히 판정 불가여야 하고(폴백이 담당), selected/challenge 는 기존 계약 그대로여야 합니다.
Assert-Case '판정식 조각 앵커(됨/선택/선태 → 태되 elseif → 도전 정확 일치 순서)' `
  ($workerSource.Contains("`$wordText.Contains('됨') -or `$wordText.Contains('선택') -or `$wordText.Contains('선태')") -and
   ($workerSource -match "Contains\('선태'\)\) \{\s+\`$isSelected = \`$true\s+\} elseif \(\`$wordText\.Contains\('태되'\)\) \{\s+\`$isSelected = \`$true\s+\`$matchedFragmentWord = \`$wordText\s+\} elseif \(\`$wordText -eq '도전'\)")) 'True'
function Get-CardWordVerdict {
  param([string]$WordText)   # 소스 판정식 사본 (앵커가 동기화를 보증)
  if ($WordText.Contains('됨') -or $WordText.Contains('선택') -or $WordText.Contains('선태')) { return 'selected' }
  if ($WordText.Contains('태되')) { return 'selected' }
  if ($WordText -eq '도전') { return 'challenge' }
  return 'unknown'
}
$cardWordCases = @(
  # 콘솔 실사고 문자열 (09-06/09-07 동일) - 판정 불가 = 폴백 담당. 09-16 프레임 재현으로 배율 5 보조의
  # **단일 단어**임이 확인됨(좌표 457,314). '태되' 조각이 없는 이 문자열은 그대로 unknown - 콘솔 구제는 3번째
  # 판독(배율 3 주 ',k•i태되')이 담당.
  @{ W = '人에E}1되'; E = 'unknown' }
  @{ W = 'RdEHEl'; E = 'unknown' }     # 콘솔 배율 5 주 (09-16 재현)
  # 09-16 조각 '태되' 추가 - 콘솔 12장 결정적 문자열 + 보관 118장 스윕에서 전부 진짜 선택됨(도전 9건 출현 0)
  @{ W = '人1태되'; E = 'selected' }   # 콘솔 배율 3 보조·배율 4 주/보조·배율 2 보조 (48회)
  @{ W = ',k•i태되'; E = 'selected' }  # 콘솔 배율 3 주 - 1회전 3번째 판독에서 확정되는 자리
  @{ W = 'Ad태되'; E = 'selected' }    # 09-07 오프라인 재현(1908, 배율 3)
  @{ W = 'A해태되'; E = 'selected' }   # 118장 스윕 (neg01 1272 배율 3)
  @{ W = 'A-t태되'; E = 'selected' }   # 118장 스윕 (1908 배율 2)
  @{ W = ',너태되'; E = 'selected' }   # 118장 스윕 (09-16 19:43 오류 캡처 1273 배율 4)
  @{ W = 'A-I태되'; E = 'selected' }   # 09-16 21:00:41 실기 (RDP 1273 창 첫 판독 - 콘솔 아닌 정상 세션에서도 조각이 먼저 잡힘, 해제 클릭 → 도전 확인 정상)
  @{ W = '人에태됩|'; E = 'unknown' }  # '태됩' - 조각 없음, 유지
  # 과거 실측 깨짐
  @{ W = '서대되'; E = 'unknown' }     # 2026-07-31 (1273 창 s5 - 당시 s3 정상)
  @{ W = '선태되'; E = 'selected' }    # 2026-07-19 ('선태' 조각)
  # 오늘 오프라인 재현 (워커 확대 규칙 - '됨' 생존 계열)
  @{ W = 'A•해태됨'; E = 'selected' }
  @{ W = '서태됨'; E = 'selected' }
  @{ W = 'A-i태됨'; E = 'selected' }
  @{ W = '人에태됨'; E = 'selected' }
  @{ W = '선택됨'; E = 'selected' }
  @{ W = '도전'; E = 'challenge' }
  @{ W = '도전!'; E = 'unknown' }      # 정확 일치 - 설명문 앞단어 구분 계약
  @{ W = '태되'; E = 'selected' }      # 조각 단독 (판정면 정의)
  @{ W = '도젓'; E = 'unknown' }       # 가상의 '도전' 깨짐 - 조각과 무관함을 명시 (실측 아님)
)
foreach ($case in $cardWordCases) {
  Assert-Case "판정 [$($case.W)]" (Get-CardWordVerdict -WordText $case.W) $case.E
}

# ---- 2. 폴백 게이트 진리표 (실함수) ----
$gateBase = @{ DeepMode = $true; InitialClicked = $false; InitialRechecked = $false
  SecondConfirmed = $false; SecondClicked = $false; HasWordPoint = $true
  RecheckCost = 1; ValidCosts = @(1, 2) }
function Invoke-GateCase { param($Override)
  $gateArgs = @{}
  foreach ($key in $gateBase.Keys) { $gateArgs[$key] = $gateBase[$key] }
  foreach ($key in $Override.Keys) { $gateArgs[$key] = $Override[$key] }
  return (Get-DgOffAnchorFallbackDecision @gateArgs)
}
Assert-Case '게이트: 실사고 조건(전부 충족) = 허용' (Invoke-GateCase @{}) $true
Assert-Case '게이트: 일반 던전(DeepMode=false) = 금지 (미실측 - 규칙 8)' (Invoke-GateCase @{ DeepMode = $false }) $false
Assert-Case '게이트: 초기 Set 클릭 있음 = 금지 (재켜기 방지)' (Invoke-GateCase @{ InitialClicked = $true }) $false
Assert-Case '게이트: 초기 Set 도전 확인 = 금지 (잔상 케이스)' (Invoke-GateCase @{ InitialRechecked = $true }) $false
Assert-Case '게이트: 2차 Set 확정 = 금지 (폴백 불필요)' (Invoke-GateCase @{ SecondConfirmed = $true }) $false
Assert-Case '게이트: 2차 Set 클릭 있음 = 금지' (Invoke-GateCase @{ SecondClicked = $true }) $false
Assert-Case '게이트: 단어 좌표 없음 = 금지 (블라인드 클릭 금지)' (Invoke-GateCase @{ HasWordPoint = $false }) $false
Assert-Case '게이트: 재확인 소모량 null = 금지' (Invoke-GateCase @{ RecheckCost = $null }) $false
Assert-Case '게이트: 재확인 소모량 유효 밖(7) = 금지' (Invoke-GateCase @{ RecheckCost = 7 }) $false

# ---- 3. 폴백 검증 시퀀스 진리표 (실함수 - null 2연속 계약) ----
function New-Reading { param($Cost, [bool]$CaptureFailed = $false)
  return @{ Cost = $Cost; CaptureFailed = $CaptureFailed }
}
$seqCases = @(
  @{ N = '숫자→null→null = 해제';            R = @((New-Reading 1), (New-Reading $null), (New-Reading $null)); E = 'cleared' }
  @{ N = 'null 1회뿐 = 대기 (단발 누락 방지)'; R = @((New-Reading $null)); E = 'pending' }
  @{ N = 'null→숫자→null = 리셋 후 대기';      R = @((New-Reading $null), (New-Reading 1), (New-Reading $null)); E = 'pending' }
  @{ N = '리셋 후 null 2연속 = 해제';          R = @((New-Reading $null), (New-Reading 1), (New-Reading $null), (New-Reading $null)); E = 'cleared' }
  @{ N = '숫자 지속 = 대기';                  R = @((New-Reading 1), (New-Reading 1), (New-Reading 1)); E = 'pending' }
  @{ N = '유효 밖 숫자 = 불명확 중단';         R = @((New-Reading 7)); E = 'noisy' }
  @{ N = '캡처 실패 null 미계상';             R = @((New-Reading $null $true), (New-Reading $null)); E = 'pending' }
  @{ N = '캡처 실패 건너뛰고 2연속';           R = @((New-Reading $null $true), (New-Reading $null), (New-Reading $null)); E = 'cleared' }
)
foreach ($case in $seqCases) {
  Assert-Case "시퀀스 [$($case.N)]" (Test-DgOffClearedBySequence -Readings $case.R -ValidCosts @(1, 2)) $case.E
}

# ---- 4. 배선 가드 ----
# 09-16 '태되' 조각: 배율 회전은 불변(배율 2 추가안은 12장 중 8장만 살려 철회), 조각 매치는 회전마다 초기화되는
# $matchedFragmentWord 로 추적해 확정 회전에만 [진단] 1줄 (주석 뺀 사본 검사)
$toggleBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Set-DgToggleCard'))
$toggleCode = ((($toggleBody -split "`r?`n") | ForEach-Object { ($_ -split '#', 2)[0] }) -join "`n")
Assert-Case '배선: 카드 배율 회전 불변 = 1~2회전·재확인 @(5, 3, 4) 2곳 + 그 외 @(5) 1곳 (배율 2 추가안 철회)' `
  (([regex]::Matches($toggleCode, '\$cardScales = @\(5, 3, 4\)').Count -eq 2) -and
   ([regex]::Matches($toggleCode, '\$cardScales = @\(5\)').Count -eq 1) -and
   ([regex]::Matches($toggleCode, '\$cardScales = @\(').Count -eq 3)) 'True'
Assert-Case "배선: '태되' 매치 추적은 회전 서두 초기화 + 매치 단어 기록 + 확정 뒤 진단 1줄 (실측 단어 기록)" `
  (($toggleCode -match '\$matchedWordPoint = \$null\s+\$matchedFragmentWord = ''''') -and
   ($toggleCode.Contains('$matchedFragmentWord = $wordText')) -and
   ($toggleCode.Contains('if ($matchedFragmentWord) {')) -and
   ($toggleCode.Contains("조각으로 판독: '`$matchedFragmentWord'"))) 'True'
Assert-Case '배선: UnknownWordPoint 초기화+정리 4곳(진입/성공/재확인생략/실패클릭)' `
  ([regex]::Matches($workerSource, '\$script:dgToggleUnknownWordPoint = \$null').Count) 4
Assert-Case '배선: 판정 불가 판독에서 3자+ 최장 단어 후보 갱신' `
  ($workerSource.Contains('$unknownLetters -ge 3 -and $unknownLetters -gt $unknownBestLetters')) 'True'
Assert-Case '배선: 호출부 게이트 호출(심층 한정 파라미터)' `
  ($workerSource.Contains('Get-DgOffAnchorFallbackDecision -DeepMode $deepMode -InitialClicked $coinToggleClicked')) 'True'
Assert-Case '배선: 폴백 클릭은 lastClickPerformed 확인(전송 확인)' `
  ($workerSource.Contains('$offAnchorClicked = [bool]$script:lastClickPerformed')) 'True'
Assert-Case '배선: 폴백 검증 강화(10회) vs 기존(5회) 분기' `
  ($workerSource.Contains('$offTryMax = $(if ($offAnchorClicked) { 10 } else { 5 })')) 'True'
Assert-Case '배선: 시퀀스 판정 호출' `
  ($workerSource.Contains('Test-DgOffClearedBySequence -Readings $offReadings -ValidCosts $dgValidCosts')) 'True'
Assert-Case '배선: 진단 저장 - 폴백 클릭 직전 1곳' `
  ([regex]::Matches($workerSource, "Save-DgCardDiagnostics -Game \`$Game -Tag 'fallback-before'").Count) 1
# Codex 보완: 진단 저장(수 초)으로 소모량 증거가 낡으므로 클릭 '직전' 신선 재확인이 계약
Assert-Case '배선: 폴백 클릭 직전 소모량 신선 재확인($offFreshCost)' `
  ($workerSource.Contains('$offFreshCost = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts') -and
   $workerSource.Contains('if ($null -ne $offFreshCost -and ($dgValidCosts -contains $offFreshCost))')) 'True'
# 2026-09-07 사용자 지적(2건째): 세트 7장 × 회차 3세트로 폴더 범람 → ROI 확대본 저장 폐지.
# 전체 프레임 1장 + 메타 로그의 영역 좌표로 오프라인 파생이 등가 (Codex 합의 - 파생 수식은
# 결정적이라 정보 손실 0). 금지 단언은 주석 뺀 사본으로 - 주석 언급만으로도 걸립니다.
$saveDiagBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Save-DgCardDiagnostics'))
$saveDiagCode = ((($saveDiagBody -split "`r?`n") | ForEach-Object { ($_ -split '#', 2)[0] }) -join "`n")
# '_roi_' 전체 부재로 걸면 레거시 청소 필터('carddiag_*_roi_*.png' - 코드)에 오탐되므로
# ROI '저장 경로 조립'(${Tag}_roi_)의 부재로 검사합니다
Assert-Case '배선: 진단은 전체 프레임 1장만(ROI 저장/재캡처 코드 없음)' `
  ((-not $saveDiagCode.Contains('${Tag}_roi_')) -and (-not $saveDiagCode.Contains('DrawImage')) -and
   -not $saveDiagCode.Contains('Get-GameRegionCapture')) 'True'
Assert-Case '배선: 진단 메타 로그에 판독 영역 좌표(오프라인 ROI 파생 입력)' `
  ($saveDiagCode.Contains("(`$Region -join ','), (`$AltRegion -join ',')")) 'True'
Assert-Case '배선: 보관 정리 = carddiag 최신 keepScreenshots 장(×7 세트 계산 폐지) + 레거시 _roi_ 청소' `
  (($saveDiagCode.Contains('Select-Object -Skip $keepShots')) -and
   (-not $saveDiagCode.Contains('$keepShots * 7')) -and
   ($saveDiagCode.Contains("Filter 'carddiag_*_roi_*.png'"))) 'True'
# fallback-before 는 직전 set-fail 캡처 재사용 (같은 프레임 중복 저장 실측 - ROI 바이트 동일.
# 폴백 게이트의 '클릭 전무' 보장이 근거, 5초는 stale 방지 보조 조건)
Assert-Case '배선: 진단 저장 성공 기록 3종(재사용 판정 입력)' `
  (($saveDiagCode.Contains('$script:dgCardDiagLastTag = $Tag')) -and
   ($saveDiagCode.Contains('$script:dgCardDiagLastPath = $cardShot')) -and
   ($saveDiagCode.Contains('$script:dgCardDiagLastAt = Get-Date'))) 'True'
Assert-Case '배선: fallback-before 는 직전 set-fail 재사용 분기(중복 프레임 저장 방지)' `
  (($workerSource -match "if \(\`$script:dgCardDiagLastTag -eq 'set-fail' -and \`$script:dgCardDiagLastPath -and\s+\(\(Get-Date\) - \`$script:dgCardDiagLastAt\)\.TotalSeconds -le 5\)") -and
   ($workerSource.Contains('fallback-before 캡처는 직전 set-fail 저장으로 대체합니다'))) 'True'
# 2026-09-07 사용자 지적: 경고 '순간'의 화면이 가장 이른 원인 자료 (폴백/정지 캡처는 늦음)
Assert-Case '배선: 진단 저장 - 카드 판정 최종 실패 경고 순간 1곳(실패 영역 전달)' `
  ([regex]::Matches($workerSource, "Save-DgCardDiagnostics -Game \`$Game -Tag 'set-fail' -Region \`$Region -AltRegion \`$AltRegion").Count) 1
Assert-Case '배선: 경고 순간 캡처는 회차당 2세트 제한(남발 방지)' `
  ($workerSource.Contains('if ([int]$script:dgCardDiagFailCount -lt 2)')) 'True'
Assert-Case '배선: 진단 영역 파라미터화(기본 소탕 - 루팅/사냥터 실패도 자기 영역)' `
  ($workerSource.Contains('if (-not $Region) { $Region = $rgDgCoinButton }')) 'True'
# 미사용 경로 3곳 + 사용 경로 3곳 (Codex 보완: 사용 분기의 카드/소모량 불일치 정지도 동일 진단)
Assert-Case '배선: 진단 저장 - 코드 4 정지 직전 6곳(미사용3+사용3)' `
  ([regex]::Matches($workerSource, "Save-DgCardDiagnostics -Game \`$Game -Tag 'stop'").Count) 6
Assert-Case '배선: set-fail 에 마지막 판독 단어별 좌표 로그' `
  ($workerSource.Contains('마지막 판독 단어: $unknownWordDetail')) 'True'
Assert-Case '배선: 카드 OCR 로그 단어 구분자(제보 분석용)' `
  ($workerSource.Contains("ForEach-Object { [string]`$_.Text }) -join '|'")) 'True'
Assert-Case '배선: 진단 접두 carddiag_ (error_* 보관 정리와 분리)' `
  ($workerSource.Contains('carddiag_${cardStamp}_$Tag.png')) 'True'

# ---- 5. 사용자 양보 확장 (2026-09-07 실전 2건째 - 조작 중 클릭 양보가 한도를 소진해 정지) ----
# 계약(Codex 합의): 양보 회전은 재시도 예산 미소모 + 조작 종료까지 상한 없는 대기 +
# 대기 후 재판독부터(옛 좌표 강행 클릭 금지 = v2.1.1 stale-click 계약 유지)
Assert-Case '양보: Wait-UserYieldEnd 함수(상한 없는 대기 + heartbeat)' `
  (($workerSource.Contains('function Wait-UserYieldEnd')) -and
   ($workerSource -match 'while \(Test-UserRecentlyActive\) \{\s+Test-SafeStopDuringCaptureFail')) 'True'
Assert-Case '양보: 클릭 생략 원인 메타 2종(user-active/cursor-not-ready)' `
  (($workerSource.Contains("`$script:lastClickSkipReason = 'user-active'")) -and
   ($workerSource.Contains("`$script:lastClickSkipReason = 'cursor-not-ready'"))) 'True'
Assert-Case '양보: 카드 클릭 사전 게이트(Focus 전 양보 + setTry 미소모 + 재판독)' `
  ($workerSource -match 'if \(Test-UserRecentlyActive\) \{\s+Wait-UserYieldEnd -Game \$Game -Context "\$Label 설정"\s+\$setTry--\s+continue\s+\}\s+Focus-Game') $true
Assert-Case '양보: 클릭 후 경합 창 백업 분기(원인 메타로 커서 실패와 구분)' `
  ($workerSource -match "elseif \(\`$script:lastClickSkipReason -eq 'user-active'\) \{[\s\S]{0,300}?\`$setTry--\s+continue") $true
Assert-Case '양보: 폴백은 양보 후 증거 재확보(2차 Set 재호출) 재시도' `
  ($workerSource -match "Wait-UserYieldEnd -Game \`$Game -Context '소탕 해제 폴백'[\s\S]{0,400}?Set-DgToggleCard") $true
Assert-Case '양보: 해제 확인 루프는 조작 중 판독 미계상(offTry--)' `
  ($workerSource -match "Wait-UserYieldEnd -Game \`$Game -Context '소탕 해제 확인'\s+\`$offTry--\s+continue") $true
Assert-Case '양보: 폴백 진단은 양보 재시도에도 1회만' `
  ($workerSource.Contains('if (-not $offFallbackDiagSaved)')) 'True'

if ($fails -gt 0) { Write-Output "FAIL 합계: $fails"; exit 1 }
Write-Output '전체 통과'
exit 0
