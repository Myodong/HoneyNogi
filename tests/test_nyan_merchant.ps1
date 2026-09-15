# 냥코인 뽑기(기타 - 고양이 상인) 판정 진리표 + 배선 가드 (2026-08-15 신설)
# 실측 근거: 던전이미지\고양이상인\ 캡처 4장(1272×1 + 네이티브 1908×3) 스윕 판독문
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-NyanNumberValue', 'Test-NyanMerchantTitle', 'Get-NyanPriceTags', 'Test-NyanSameTag', 'Test-NyanCoinSuspect', 'Get-NyanCoinCorrection', 'Get-NyanCommonTags', 'Get-NyanStableTag', 'Get-NyanWaitSeconds')) {
  Invoke-Expression $definition
}
$workerText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))
$guiText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_gui.ps1'))

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 재화 숫자 파서 (digits-only - 아이콘 오독/구분자 깨짐 흡수) ──
Assert-Case '재화: 1272 냥코인 실측(아이콘이 0으로) → 401217' (Get-NyanNumberValue -Text '0401,217') 401217
Assert-Case '재화: 1908 냥코인 실측(쉼표→마침표 + @) → 8181217' (Get-NyanNumberValue -Text '@8.181.217') 8181217
Assert-Case '재화: 골드 실측 → 21830510' (Get-NyanNumberValue -Text '021,830,510') 21830510
Assert-Case '재화: 정상 표기 → 21788110' (Get-NyanNumberValue -Text '21,788,110') 21788110
Assert-Case '재화: 빈 판독 → -1' (Get-NyanNumberValue -Text '') (-1)
Assert-Case '재화: 숫자 없음 → -1' (Get-NyanNumberValue -Text '골드') (-1)
Assert-Case '재화: 12자리 초과(오독 뭉침) → -1' (Get-NyanNumberValue -Text '1234567890123') (-1)
# 2026-09-15 골드 앞자리 소실 분석 (프레임 5,015장): 내부 잡음('기')은 틀린 값 대신 -1, 접두·접미 잡음은 그대로 무해
Assert-Case "재화: 내부 잡음 '기'(실측 02965기124) → -1 (틀린 7자리 금지)" (Get-NyanNumberValue -Text '02965기124') (-1)
Assert-Case "재화: 내부 잡음 + 마침표 구분(실측 @29.59기524) → -1" (Get-NyanNumberValue -Text '@29.59기524') (-1)
Assert-Case "재화: 접두 ')'(냥코인 실측 )14,021,217) → 14021217" (Get-NyanNumberValue -Text ')14,021,217') 14021217
Assert-Case "재화: 접두 '@' + 마침표(골드 실측 @30.062.324) → 30062324" (Get-NyanNumberValue -Text '@30.062.324') 30062324
Assert-Case "재화: 접두 '0'(아이콘, 실측 029,962,924) → 29962924" (Get-NyanNumberValue -Text '029,962,924') 29962924
Assert-Case '재화: 내부 공백(OCR 단어 분리)은 허용 → 29782324' (Get-NyanNumberValue -Text '29,782 324') 29782324
Assert-Case '재화: 접미 잡음은 무해 → 29782324' (Get-NyanNumberValue -Text '29,782,324골') 29782324

# ── 제목 게이트 (조각 2개: 고양이+뽑기) ──
Assert-Case '제목: 실측 정상 → true' (Test-NyanMerchantTitle -Text '고양이 상인 뽑기') 'True'
Assert-Case '제목: 조각 1개(고양이만) → false' (Test-NyanMerchantTitle -Text '고양이 상인') 'False'
Assert-Case '제목: 조각 1개(뽑기만) → false' (Test-NyanMerchantTitle -Text '다시 뽑기') 'False'
Assert-Case '제목: 무관 화면 → false' (Test-NyanMerchantTitle -Text '생활 스킬') 'False'

# ── 가격표 토큰 (구분자 포함 + digits 3~6 - 위치 탐지 전용) ──
# 1272 카드존 스윕 실측: '7,800'(1→7 오독)×2 / '1특十'(비가격) / '97,600'(노이즈 접두) / '7,600'
$tags1272 = @(Get-NyanPriceTags -Words @(
    @{ Text = '7,800'; X = 705; Y = 373 }, @{ Text = '7,800'; X = 492; Y = 377 },
    @{ Text = '1특十'; X = 393; Y = 403 }, @{ Text = '97,600'; X = 563; Y = 611 },
    @{ Text = '7,600'; X = 765; Y = 607 }))
Assert-Case '가격표: 1272 실측 5토큰 중 4개 인정 (비가격 제외)' (@($tags1272).Count) 4
Assert-Case '가격표: 첫 토큰 좌표 보존' ('{0},{1}' -f $tags1272[0].X, $tags1272[0].Y) '705,373'
# 1908 실측: '01,800'(아이콘 0 접두) / '@1.600'(쉼표→마침표) 인정
$tags1908 = @(Get-NyanPriceTags -Words @(
    @{ Text = '01,800'; X = 472; Y = 422 }, @{ Text = '@1.600'; X = 594; Y = 630 }))
Assert-Case '가격표: 1908 깨짐 표기 2개 모두 인정' (@($tags1908).Count) 2
# 판 종료 실측: 아이템명·단독 숫자만 남음 - 가격표 0개 (다시 뽑기 판정의 근거)
$tagsDone = @(Get-NyanPriceTags -Words @(
    @{ Text = '회복'; X = 467; Y = 607 }, @{ Text = '물약'; X = 502; Y = 602 },
    @{ Text = '러스트'; X = 656; Y = 624 }, @{ Text = '7'; X = 755; Y = 504 },
    @{ Text = '막내'; X = 763; Y = 570 }, @{ Text = '패치'; X = 797; Y = 566 }))
Assert-Case '가격표: 판 종료 실측 → 0개 (단독 숫자·아이템명 제외)' (@($tagsDone).Count) 0
Assert-Case '가격표: digits 7자리(재화 오유입 방어) → 제외' (@(Get-NyanPriceTags -Words @(@{ Text = '8,181,217'; X = 1; Y = 1 })).Count) 0
Assert-Case '가격표: 구분자 없는 3~6자리(단독 숫자류) → 제외 (구분자 요구 계약)' (@(Get-NyanPriceTags -Words @(@{ Text = '1800'; X = 1; Y = 1 })).Count) 0

# ── 잔량 급변 의심 (2026-08-15 조기 정지 실사고 - 아이콘 '9' 접두 오독) ──
Assert-Case '급변: 실사고 원값 8,603,217 → 판독 98,603,217 = 의심' (Test-NyanCoinSuspect -Previous 8603217 -Current 98603217) 'True'
Assert-Case '급변: 현상금 정상 증가 +7,000 = 채택' (Test-NyanCoinSuspect -Previous 8603217 -Current 8610217) 'False'
Assert-Case '급변: 감소는 오독 (소비 경로 없음 - 앞자리 소실 확정 방지)' (Test-NyanCoinSuspect -Previous 8603217 -Current 603217) 'True'
Assert-Case '급변: 동일 값 = 채택' (Test-NyanCoinSuspect -Previous 8603217 -Current 8603217) 'False'
Assert-Case '급변: 기준 없음(첫 판독) = 의심 아님' (Test-NyanCoinSuspect -Previous -1 -Current 98603217) 'False'
Assert-Case '급변: 판독 실패는 별도 경로 = 의심 아님' (Test-NyanCoinSuspect -Previous 8603217 -Current -1) 'False'
# 배선: 실패/의심 판독은 확정 갱신 없이 이번 주기 구매를 건너뜀 (continue)
Assert-Case '배선: 의심 판독 시 구매 진행 금지 (continue)' `
  ([bool]($workerText -match '\$coinFailStreak -ge 8[\s\S]{0,300}Start-Sleep -Milliseconds 800\r?\n\s+continue')) 'True'

# ── 접두 오독 자기 보정 (2026-08-15 07:11 실사고 - 지속형 '9' 접두로 8연속 의심 → 조건부 정지) ──
Assert-Case '보정: 실사고 98,842,217 → 직전 확정값 8,842,217 채택' (Get-NyanCoinCorrection -Previous 8842217 -Current 98842217) 8842217
Assert-Case '보정: +100,000 경계(포함) → 채택' (Get-NyanCoinCorrection -Previous 8842217 -Current 98942217) 8942217
Assert-Case '보정: +100,001 초과 → 거부' (Get-NyanCoinCorrection -Previous 8842217 -Current 98942218) (-1)
Assert-Case "보정: 접두 '9' 아님(88,842,217) → 거부 (미관측 접두 - 규칙 8)" (Get-NyanCoinCorrection -Previous 8842217 -Current 88842217) (-1)
Assert-Case '보정: 접미부 선행 0(908,842,217) → 거부 (2자리 접두 조용한 제거 방지)' (Get-NyanCoinCorrection -Previous 8842217 -Current 908842217) (-1)
Assert-Case '보정: 첫 판독(Previous=-1) → 보정 안 함 (시작 시점 접두 오독 미관측)' (Get-NyanCoinCorrection -Previous -1 -Current 98842217) (-1)
Assert-Case '보정: 판독 실패(Current=-1) → 보정 안 함' (Get-NyanCoinCorrection -Previous 8842217 -Current -1) (-1)
Assert-Case '보정: 감소형 접두(942,217 → 뗀 값 42,217 < 직전) → 거부' (Get-NyanCoinCorrection -Previous 8842217 -Current 942217) (-1)
Assert-Case '보정: 목표 경계 복합 오독(9,950,000→910,000,000) → 10,000,000 채택 (잔여 위험 문서화 - 다음 정상 판독이 감소로 걸려 fail-closed)' `
  (Get-NyanCoinCorrection -Previous 9950000 -Current 910000000) 10000000
# 배선: 의심 분기 안에서 보정 시도 → 성공 시 정상 경로 합류($coinNow 치환 + 의심 해제)
Assert-Case '배선: 보정 성공 시 정상 판독 경로 합류' `
  ([bool]($workerText -match 'Get-NyanCoinCorrection -Previous \$lastCoinValue -Current \$coinNow[\s\S]{0,500}\$coinNow = \$correctedCoin\r?\n\s+\$coinSuspect = \$false')) 'True'
# 체인 구매 뒤에는 정당한 누적 증가가 10만을 넘을 수 있음 (2026-08-15 Codex 반례:
# 현상금 +6만+6만 체인 후 '9' 오독이면 기본 상한에 걸려 8연속 fail-closed) → 배치 인식
Assert-Case '보정: 체인 배치 상한(30만)으로 +250,000 채택' (Get-NyanCoinCorrection -Previous 8842217 -Current 99092217 -AllowedGain 300000) 9092217
Assert-Case '보정: 기본 상한(10만)은 +250,000 거부' (Get-NyanCoinCorrection -Previous 8842217 -Current 99092217) (-1)
Assert-Case '배선: 보정 상한을 판독 간 구매 수로 배치 인식' `
  ([bool]($workerText -match '-AllowedGain \(100000 \* \[int64\]\[Math\]::Max\(1, \$coinReadGapPurchases\)\)')) 'True'
Assert-Case '배선: 판독 간 구매 수 추적 (구매마다 증가 + 잔량 확정 시 0 복귀)' `
  (($workerText -match '\$purchaseCount\+\+\r?\n\s+\$coinReadGapPurchases\+\+') -and
   ($workerText -match '\$coinFailStreak = 0\r?\n\s+\$coinReadGapPurchases = 0')) 'True'

# ── 좌표 소멸 확인 (±12) ──
$sameTags = @(@{ X = 705; Y = 373 }, @{ X = 492; Y = 377 })
Assert-Case '소멸: 같은 좌표(±12) 잔존 → true' (Test-NyanSameTag -Tags $sameTags -X 710 -Y 380) 'True'
Assert-Case '소멸: 그 좌표만 사라짐 → false (다른 카드의 같은 금액은 증거 아님)' (Test-NyanSameTag -Tags @(@{ X = 492; Y = 377 }) -X 705 -Y 373) 'False'
Assert-Case '소멸: 빈 목록 → false' (Test-NyanSameTag -Tags @() -X 705 -Y 373) 'False'
Assert-Case '소멸: 30px 차이는 다른 카드 (±12 계약 - 이웃 카드 오인 금지)' (Test-NyanSameTag -Tags @(@{ X = 735; Y = 373 }) -X 705 -Y 373) 'False'
# 2026-08-15 x0 y0 실사고: 빈 판독($null)이 @()에서 1칸 배열이 되고 null 항목의 [int] 캐스팅이
# X=0 Y=0으로 읽혀 (0,0) 앵커와 일치 → "가격표 잔존" 오판 → 8초 교착 → 조건부 정지 (재현 확정)
Assert-Case '소멸: null 항목은 무시 - (0,0) 앵커와 일치 오판 금지' (Test-NyanSameTag -Tags @($null) -X 0 -Y 0) 'False'

# ── 배선 가드 (워커) ──
Assert-Case "배선: 기타 분기(etc → Invoke-NyanMerchantRun)" `
  ([bool]($workerText -match "if \(\`$mainCategory -eq 'etc'\) \{[\s\S]{0,200}Invoke-NyanMerchantRun -Game \`$game")) 'True'
Assert-Case '배선: 구매 확인은 클릭한 좌표의 소멸 (Test-NyanSameTag)' `
  ([bool]($workerText -match 'Test-NyanSameTag -Tags \$tagsNow -X \(\[int\]\$firstTag\.X\) -Y \(\[int\]\$firstTag\.Y\)')) 'True'
# 2026-08-15 개정: 구매 속도 개선으로 PURCHASE_WAIT가 횟수 루프(1..8×1000ms)에서 Stopwatch
# 경과 시간 판정(폴링 500ms, 재클릭 4초, 타임아웃 8초)으로 바뀜 (리뷰 조건 - OCR 소요 때문에
# 횟수×간격은 벽시계가 아님). 벽시계 계약(4초/8초)은 그대로.
# 2026-09-13 재개정: 폴링 500→150ms (수동 52판 프레임 실측 - 구매 클릭 뒤 가격표 소멸은 다음 프레임).
Assert-Case '배선: 재클릭은 최대 1회 ($reclicked 래치, 경과 4초 판정)' `
  ([bool]($workerText -match 'if \(\(Get-NyanWaitSeconds -Clock \$purchaseWaitClock -LostMs \$purchaseWaitLostMs\) -ge 4 -and -not \$reclicked\)')) 'True'
Assert-Case '배선: 구매 확인은 경과 8초 타임아웃 + 150ms 폴링' `
  ([bool]($workerText -match 'while \(\(Get-NyanWaitSeconds -Clock \$purchaseWaitClock -LostMs \$purchaseWaitLostMs\) -lt 8\) \{\r?\n\s+\$pollStartMs = \$purchaseWaitClock\.ElapsedMilliseconds\r?\n\s+Start-Sleep -Milliseconds 150')) 'True'
# 2026-08-15 재개정: 사용자 추가 단축 요청으로 '무조건 1200ms'가 '경계 근접/미확정 1200ms,
# 원거리 300ms' 조건부로 완화됨 (Codex 승인 명시적 계약 완화 - stale-low는 경계 부근에서만
# 유해, 여유폭 냥코인 30만/골드 10만은 현상금·가격표 실측 상한의 3~12배)
Assert-Case '배선: 확인 후 대기가 경계 조건부 (근접·미확정 1200ms / 원거리 300ms)' `
  ([bool]($workerText -match '\$nearTarget = \(\$lastCoinValue -lt 0 -or \(\$nyanTargetCoins - \$lastCoinValue\) -le 300000\)[\s\S]{0,400}if \(\$nearTarget -or \$nearGoldLimit\) \{ Start-Sleep -Milliseconds 1200 \} else \{ Start-Sleep -Milliseconds 300 \}')) 'True'
Assert-Case '배선: 골드 상한 경계도 여유폭 10만으로 검사 ($lastGoldValue 추적 포함)' `
  (($workerText -match '\$nearGoldLimit = \(\$lastGoldValue -lt 0 -or \(\$nyanGoldLimit - \(\$startGold - \$lastGoldValue\)\) -le 100000\)') -and
   ($workerText -match '\$goldFailStreak = 0\r?\n\s+\$lastGoldValue = \$goldNow')) 'True'
Assert-Case '배선: 소멸 확정 판독 전체로 안정 1연속 시딩 (빈 판은 빈 배열 - 새 판 2연속 유지)' `
  ([bool]($workerText -match '\$stableTags = @\(\$tagsNow\)\r?\n\s+continue')) 'True'
# ── 체인 구매 (2026-08-15 사용자 '1~2초' 요청 - Codex 3조건 반영 승인) ──
Assert-Case '배선: 체인 구매는 최대 2장 추가 (잔량 판독 간 최대 3구매)' `
  ([bool]($workerText -match '\$chainBudget = 2\r?\n\s+while \(\$true\) \{')) 'True'
# 2026-08-15 개정: 판당 뽑기 한도 5 도입으로 체인 계속 조건에 한도 미달이 추가됨
Assert-Case '배선: 체인 계속은 원거리 문턱 60만/30만 + 남은 카드 + 예산 + 판 한도 미달' `
  (($workerText -match '\$farFromTarget = \(\$lastCoinValue -ge 0 -and \(\$nyanTargetCoins - \$lastCoinValue\) -gt 600000\)') -and
   ($workerText -match '\$farFromGoldLimit = \(-not \$nyanGoldLimitEnabled -or \(\$lastGoldValue -ge 0 -and \(\$nyanGoldLimit - \(\$startGold - \$lastGoldValue\)\) -gt 300000\)\)') -and
   ($workerText -match 'if \(\$chainBudget -gt 0 -and \$farFromTarget -and \$farFromGoldLimit -and @\(\$tagsNow\)\.Count -gt 0 -and \$boardPurchases -lt 5\)')) 'True'
# ── 판당 뽑기 한도 5 (2026-08-15 실측: 상인 말풍선 '4번 남았다냥'(1장 구매 후) + 사용자 확인.
#    판은 7카드지만 5회만 구매 가능 - 6번째 클릭은 게임이 거부하는 무효 클릭이었음) ──
Assert-Case '배선: 한도 도달 시 카드가 보여도 구매 금지 (탐색 게이트)' `
  ([bool]($workerText -match 'if \(@\(\$tags\)\.Count -gt 0 -and \$boardPurchases -lt 5\)')) 'True'
Assert-Case '배선: 한도 도달은 소진 재확인 생략하고 바로 다시 뽑기' `
  (($workerText -match '\$boardLimitReached = \(\$boardPurchases -ge 5\)') -and
   ($workerText -match 'if \(-not \$boardLimitReached\) \{')) 'True'
Assert-Case '배선: 확인된 구매만 판 카운트 증가 + 리롤 확인 후 0 복귀' `
  (($workerText -match 'exit 4\r?\n\s+\}\r?\n\s+\$boardPurchases\+\+') -and
   ($workerText -match '\(조건부 정지\)''\r?\n\s+exit 4\r?\n\s+\}\r?\n\s+\$boardPurchases = 0')) 'True'
Assert-Case '배선: 한도 리롤은 0개 판독 1회 선행 요구 (구판 잔존 가격표 오인 방지)' `
  (($workerText -match '\$rerollCleared = \(-not \$boardLimitReached\)') -and
   ($workerText -match 'if \(-not \$rerollCleared\) \{ continue \}')) 'True'
Assert-Case '배선: pendingBoardTags 는 일회성 + 나이 3초 상한 + 캡처 실패 시 폐기' `
  (($workerText -match '-not \$script:screenCaptureFailing -and\r?\n\s+\$pendingBoardTagsClock\.Elapsed\.TotalSeconds -le 3') -and
   ($workerText -match '\$tags = @\(Read-NyanPriceTags -Game \$Game\)\r?\n\s+\}\r?\n\s+\$pendingBoardTags = \$null')) 'True'
Assert-Case '배선: 재등장 시딩은 직전·최신 공통 카드만 pendingBoardTags 로 (최신 전체 금지)' `
  ([bool]($workerText -match '\$rerollCommon = @\(Get-NyanCommonTags -Current \$tagsNow -Previous \$rerollPrevTags\)\r?\n\s+if \(@\(\$rerollCommon\)\.Count -gt 0\) \{\r?\n\s+\$pendingBoardTags = \$rerollCommon\r?\n\s+\$pendingBoardTagsClock = \[System\.Diagnostics\.Stopwatch\]::StartNew\(\)')) 'True'
Assert-Case '배선: 체인 클릭마다 지정 시간 검사 (Codex 조건 - 최악 8초×2 누적 유예 방지)' `
  ([bool]($workerText -match '\$firstTag = \$tagsNow\[0\]\r?\n\s+Test-NyanUntilReached')) 'True'
# 유령 태그 클릭 무해 논증의 전제: 누적 구매 수는 로그 표기 전용 - 종료/상한 판단에 쓰이면
# 과계상이 실해가 됨 (Codex 무해 조건). if/while 조건식에 등장하지 않아야 합니다.
Assert-Case '배선: $purchaseCount 는 어떤 조건식에도 미사용 (로그 전용)' `
  ([bool]($workerText -match '(if|while) \([^\r\n]*\$purchaseCount')) 'False'
# 2026-08-15 x0 y0 실사고: Read-NyanPriceTags 반환은 파이프라인에서 풀림(규칙 3) - 1개면
# Hashtable 맨몸([0]=null → 클릭 좌표 0,0), 0개면 null(@()에서 1칸 배열 → 빈 판인데 게이트
# 통과). 모든 호출부는 @()로 수집해야 하며 맨몸 할당은 금지 (오프라인 재현으로 확정).
# 2026-08-15 +1: 소진 재확인 루프($recheckTags) 신설로 4곳
Assert-Case '배선: Read-NyanPriceTags 호출부 4곳 전부 @() 수집' `
  (([regex]::Matches($workerText, '= @\(Read-NyanPriceTags -Game \$Game\)')).Count) 4
Assert-Case '배선: Read-NyanPriceTags 맨몸 할당 0건' `
  (([regex]::Matches($workerText, '= Read-NyanPriceTags')).Count) 0
# 2026-08-15 REROLL_WAIT 속도 개선: 폴링 1000→400ms + Stopwatch 12초 (캡처 실패 중 시계
# 동결 - 전역 계약) + 재등장 2연속의 두 판독 좌표가 일치(±12)하면 $stableTag 시딩으로
# 새 판 첫 클릭까지 한 주기 절약 (좌표가 흔들리면 시딩 없이 기존 2연속 유지)
# 2026-08-15 재개정: 재등장 1회 확인 후의 2차 확인 폴만 250ms (첫 감지는 400ms 유지)
Assert-Case '배선: REROLL_WAIT = Stopwatch 12초 + 400ms 폴링 (2차 확인 250ms)' `
  ([bool]($workerText -match 'while \(\(Get-NyanWaitSeconds -Clock \$rerollWaitClock -LostMs \$rerollWaitLostMs\) -lt 12\) \{[\s\S]{0,900}Start-Sleep -Milliseconds \$\(if \(\$rerollSeen -ge 1\) \{ 250 \} else \{ 400 \}\)')) 'True'
Assert-Case '배선: REROLL_WAIT 캡처 실패 중 시계 동결 (Stop → 복구까지 안전 검사·2초·탐침 반복 → Start)' `
  ([bool]($workerText -match '\$rerollWaitClock\.Stop\(\)\r?\n\s+while \(\$script:screenCaptureFailing\) \{\r?\n\s+Test-SafeStopDuringCaptureFail\r?\n\s+Start-Sleep -Seconds 2\r?\n\s+\[void\]\(Test-CaptureRecovered -Game \$Game\)[^\r\n]*\r?\n\s+\}\r?\n\s+\$rerollWaitClock\.Start\(\)\r?\n\s+continue')) 'True'
Assert-Case '배선: 재등장 2연속 시 $stableTags 는 최신 판독 전체 (그 다음 공통 카드 계산)' `
  ([bool]($workerText -match 'if \(\$rerollSeen -ge 2\) \{[\s\S]{0,900}?\$stableTags = @\(\$tagsNow\)\r?\n\s+\$rerollCommon = @\(Get-NyanCommonTags')) 'True'
# 2026-08-15 개정: 소진 확정이 루프 상단 전체 주기 반복(잔량 OCR+800ms ×3 ≈ 5~7초)에서
# 가격표 전용 빠른 재판독 루프로 경량화됨 (사용자 속도 요청). '3연속 빈 판독' 계약은 유지
# (상단 1회 + 재확인 2회) + Codex 조건: 최소 벽시계 2초(연출 압축 오판 방지), 매 판독 직후
# 캡처 실패 확인(상단 복구 경로 복귀).
Assert-Case '배선: 소진 확정 = 재확인 2회 + 최소 벽시계 2초' `
  ([bool]($workerText -match 'if \(\$emptyRechecks -ge 2 -and \$emptyClock\.Elapsed\.TotalSeconds -ge 2\) \{ \$emptyConfirmed = \$true; break \}')) 'True'
Assert-Case '배선: 소진 재확인 루프가 매 판독 직후 캡처 실패 확인' `
  ([bool]($workerText -match '\$recheckTags = @\(Read-NyanPriceTags -Game \$Game\)\r?\n\s+if \(\$script:screenCaptureFailing\) \{ break \}')) 'True'
Assert-Case '배선: 미확정 소진은 루프 상단 복귀 (다시 뽑기 금지)' `
  ([bool]($workerText -match 'if \(-not \$emptyConfirmed\) \{ continue \}')) 'True'
# 안전 중지: 판 종료(다시 뽑기 클릭 직전)가 유일한 안전 경계 - flag 소비 후 exit 4, 확인과
# 클릭 사이에 다른 동작 금지 (2026-08-15 실기 결함: 배선 부재로 안전 중지가 영영 안 먹었음)
Assert-Case '배선: 안전 중지 flag 확인이 다시 뽑기 입력 직전 (소비 → exit 4 → 앵커 분기 → A/폴백 순서)' `
  ([bool]($workerText -match 'if \(Test-Path -LiteralPath \$safeStopFlagPath\) \{\r?\n\s+Remove-Item -LiteralPath \$safeStopFlagPath[^\r\n]*\r?\n\s+Write-RunLog \("\[완료\] 안전 중지[\s\S]{0,100}exit 4\r?\n\s+\}\r?\n\s+if \(\$null -ne \$rerollAnchor\) \{')) 'True'
Assert-Case '배선: 목표 도달은 2연속 동일 값으로 확정' `
  ([bool]($workerText -match '\$coinNow -eq \$lastCoinValue -and \$coinNow -ge \$nyanTargetCoins')) 'True'
Assert-Case '배선: 골드 상한은 잔량 차감 (시작-현재)' `
  ([bool]($workerText -match '\(\$startGold - \$goldNow\) -ge \$nyanGoldLimit')) 'True'
Assert-Case '배선: 모든 종료가 exit 4 (기타 흐름에 exit 0 없음)' `
  ([bool]([regex]::Match($workerText, 'function Invoke-NyanMerchantRun[\s\S]*?\r?\n\}\r?\n').Value -match 'exit 0')) 'False'
# 영역 값 고정 (하드코딩 - 두 기하 겸용 스윕 실측. 값 변경 시 오프라인 재검 필수)
Assert-Case '배선: 판독 영역 5종 실측값' `
  (($workerText.Contains('$rgNyanTitle  = @(25, 38, 300, 55)')) -and
   ($workerText.Contains('$rgNyanCoin   = @(1085, 40, 125, 45)')) -and
   ($workerText.Contains('$rgNyanGold   = @(910, 40, 175, 45)')) -and
   ($workerText.Contains('$rgNyanCards  = @(390, 330, 480, 340)')) -and
   ($workerText.Contains('$rgNyanReroll = @(1090, 630, 170, 50)'))) 'True'

# ── 2026-09-13 속도 개선 (수동 52판 실측 - 이력 '냥코인 뽑기 속도 실측' 참고): 전면이면 포커스 생략,
#    구매 확인 폴링 150ms, 다시 뽑기는 앵커 확인 후 단축키 A. 함수 본문의 **주석을 뺀 사본**으로 단언합니다. ──
$nyanCode = Remove-SourceComments -Text (@(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Invoke-NyanMerchantRun'))[0])
Assert-Case '속도: 구매 클릭 2곳(체인·재클릭)의 포커스는 전면 확인 조건부' `
  (([regex]::Matches($nyanCode, 'if \(-not \(Test-GameForeground -Game \$Game\)\) \{ Focus-Game -Game \$Game \}\s+Click-GamePoint -Game \$Game -ReferenceX \(\[int\]\$firstTag\.X \+ 20\)')).Count) 2
# 2026-09-15: 골드 상한이 켜진 채 잔량 판독이 -1 이면 그 회전은 구매하지 않음 (실패 카운터 뒤 800ms + continue)
Assert-Case '골드 상한: 판독 실패 분기가 구매 경로로 내려가지 않음 (8회 정지 검사 뒤 대기 + continue)' `
  ([bool]($nyanCode -match "\`$goldFailStreak\+\+\s+if \(\`$goldFailStreak -ge 8\) \{[^}]*exit 4\s*\}\s+Start-Sleep -Milliseconds 800\s+continue")) 'True'
Assert-Case '속도: 냥 루프 안에 무조건 Focus-Game 호출 0건 (전부 전면 조건부)' `
  (([regex]::Matches($nyanCode, '(?m)^\s*Focus-Game -Game \$Game\s*$')).Count) 0
Assert-Case '속도: 구매 확인 폴링 150ms 직후 가격표 판독 (4초 재클릭·8초 타임아웃 벽시계 불변)' `
  ([bool]($nyanCode -match 'while \(\(Get-NyanWaitSeconds -Clock \$purchaseWaitClock -LostMs \$purchaseWaitLostMs\) -lt 8\) \{\s+\$pollStartMs = \$purchaseWaitClock\.ElapsedMilliseconds\s+Start-Sleep -Milliseconds 150\s+\$tagsNow = @\(Read-NyanPriceTags')) 'True'
Assert-Case '다시 뽑기: 앵커 있으면 단축키 A 1회 (Press-KeyOnce 0x41) - 앵커 클릭 0건·Press-KeyVerified 미사용' `
  ((([regex]::Matches($nyanCode, 'Press-KeyOnce -VirtualKey 0x41')).Count -eq 1) -and
   (([regex]::Matches($nyanCode, 'Click-GamePoint -Game \$Game -ReferenceX \(\[int\]\$rerollAnchor')).Count -eq 0) -and
   (-not $nyanCode.Contains('Press-KeyVerified'))) 'True'
Assert-Case '다시 뽑기: 순서 = 전면 복구(조건부) → 앵커 판독 → 사용자 재확인 → 안전 중지 → 앵커 분기 → 전면 최종 확인(실패 continue) → A' `
  ([bool]($nyanCode -match 'if \(-not \(Test-GameForeground -Game \$Game\)\) \{ Focus-Game -Game \$Game \}\s+\$rerollWords = @\(Get-GameRegionOcrWords[\s\S]{0,700}?if \(Test-UserRecentlyActive\) \{\s+Wait-UserYieldEnd -Game \$Game -Context ''냥 상인 다시 뽑기''\s+continue\s+\}\s+if \(Test-Path -LiteralPath \$safeStopFlagPath\) \{[\s\S]{0,400}?exit 4\s+\}\s+if \(\$null -ne \$rerollAnchor\) \{\s+if \(-not \(Test-GameForeground -Game \$Game\)\) \{\s+Write-RunLog ''\[기타\] 다시 뽑기 키\(A\)를 보내지 않았습니다[^\r\n]*\s+continue\s+\}\s+Press-KeyOnce -VirtualKey 0x41')) 'True'
$nyanSafeStopToKey = [regex]::Match($nyanCode, 'Test-Path -LiteralPath \$safeStopFlagPath[\s\S]*?Press-KeyOnce -VirtualKey 0x41').Value
Assert-Case '다시 뽑기: 안전 중지 확인과 A 사이에 sleep·판독·포커스·사용자 검사 없음 (입력 직전 마지막 동작 계약)' `
  (($nyanSafeStopToKey.Length -gt 0) -and -not ($nyanSafeStopToKey -match 'Start-Sleep|Get-GameRegion|Read-Nyan|Focus-Game|Test-UserRecentlyActive')) 'True'
$nyanKeyBranch = [regex]::Match($nyanCode, 'if \(\$null -ne \$rerollAnchor\) \{[\s\S]*?\} else \{').Value
Assert-Case '다시 뽑기: 키 경로는 직전 클릭 메타(lastClickPerformed/SkipReason)를 읽지 않음' `
  (($nyanKeyBranch.Length -gt 0) -and -not ($nyanKeyBranch -match 'lastClickPerformed|lastClickSkipReason')) 'True'
Assert-Case '다시 뽑기: 앵커 없으면 폴백 고정점 클릭(전면 조건부) + 미전송 시 continue' `
  ([bool]($nyanCode -match '\} else \{\s+if \(-not \(Test-GameForeground -Game \$Game\)\) \{ Focus-Game -Game \$Game \}\s+Click-GamePoint -Game \$Game -ReferenceX \$ptNyanReroll\[0\] -ReferenceY \$ptNyanReroll\[1\]\s+if \(-not \$script:lastClickPerformed\) \{[\s\S]{0,600}?continue\s+\}\s+\}\s+Write-RunLog \("\[기타\] 가격표 소진')) 'True'

# ── 다시 뽑기 입력 분기 모의 실행 (2026-09-13 구현 리뷰 지적: 배선 정규식은 '뽑기' 앵커 판정 자체를 보호하지
#    못함 - `-eq '뽑기'` 를 '닫기' 로 바꿔도 통과). 주석 뺀 함수 본문에서 **전면 복구 ~ A/폴백 분기**를 잘라
#    실제 코드를 실행합니다. `continue` 가 살아 있도록 1회 foreach 로 감싸고, 점소싱(. )으로 돌려 대입이
#    호출자에 보이게 합니다 (규칙 3). 안전 중지 flag 는 없는 경로로 두어 exit 4 가 실행되지 않습니다. ──
$nyanRerollSpan = [regex]::Match($nyanCode, 'if \(-not \(Test-GameForeground -Game \$Game\)\) \{ Focus-Game -Game \$Game \}\s+\$rerollWords = @\(Get-GameRegionOcrWords[\s\S]*?(?=\s+Write-RunLog \("\[기타\] 가격표 소진)').Value
Assert-Case '모의: 다시 뽑기 분기 추출 (전면 복구 ~ A/폴백)' ($nyanRerollSpan.Length -gt 200) 'True'
$nyanRerollBlock = [scriptblock]::Create("foreach (`$nyanOnce in 1) {`n" + $nyanRerollSpan + "`n`$script:nyanReachedEnd = `$true`n}")
$rgNyanReroll = @(1090, 630, 170, 50); $ptNyanReroll = @(1163, 655); $ocrKoreanEngine = $null
$safeStopFlagPath = Join-Path $env:TEMP ('honeynogi_no_such_flag_' + [guid]::NewGuid().ToString('N'))
$Game = New-Object PSObject
function Reset-NyanMock {
  param($Words, [bool]$Foreground = $true, [bool]$UserActive = $false)
  $script:mockWords = $Words; $script:mockForeground = $Foreground; $script:mockUserActive = $UserActive
  $script:nyanKeyCount = 0; $script:nyanClickCount = 0; $script:nyanFocusCount = 0; $script:nyanYieldCount = 0
  $script:nyanLogs = @(); $script:nyanReachedEnd = $false; $script:lastClickPerformed = $false; $script:lastClickSkipReason = ''
}
function Get-GameRegionOcrWords { return $script:mockWords }
function Test-GameForeground { param($Game) return $script:mockForeground }
function Focus-Game { param($Game) $script:nyanFocusCount++ }
function Test-UserRecentlyActive { return $script:mockUserActive }
function Wait-UserYieldEnd { param($Game, $Context) $script:nyanYieldCount++ }
function Press-KeyOnce { param([byte]$VirtualKey) if ($VirtualKey -eq 0x41) { $script:nyanKeyCount++ } }
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) $script:nyanClickCount++; $script:lastClickPerformed = $true }
function Write-RunLog { param([string]$Message) $script:nyanLogs += $Message }
# ① 앵커 '뽑기' + 전면: A 1회, 클릭 0회, 끝까지 진행
Reset-NyanMock -Words @(@{ Text = '뽑기'; X = 1163; Y = 649 })
. $nyanRerollBlock
Assert-Case "모의: 앵커 '뽑기' → A 1회·클릭 0회·포커스 0회·끝까지 진행" ('{0},{1},{2},{3}' -f $script:nyanKeyCount, $script:nyanClickCount, $script:nyanFocusCount, $script:nyanReachedEnd) '1,0,0,True'
# ② 앵커가 '닫기'(다른 글자): A 0회, 폴백 클릭 1회
Reset-NyanMock -Words @(@{ Text = '닫기'; X = 1163; Y = 649 })
. $nyanRerollBlock
Assert-Case "모의: 앵커가 '닫기' → A 0회·폴백 클릭 1회·끝까지 진행" ('{0},{1},{2}' -f $script:nyanKeyCount, $script:nyanClickCount, $script:nyanReachedEnd) '0,1,True'
# ③ 빈 판독: A 0회, 폴백 클릭 1회
Reset-NyanMock -Words @()
. $nyanRerollBlock
Assert-Case '모의: 빈 판독 → A 0회·폴백 클릭 1회' ('{0},{1}' -f $script:nyanKeyCount, $script:nyanClickCount) '0,1'
# ④ 앵커 있음 + 전면 아님: 포커스 복구 1회(판독 전) 후 최종 확인 실패 → A 0회·클릭 0회·continue(끝 미도달)·전면 미확인 로그
Reset-NyanMock -Words @(@{ Text = '뽑기'; X = 1163; Y = 649 }) -Foreground $false
. $nyanRerollBlock
Assert-Case '모의: 전면 아님 → 판독 전 복구 1회, A 0회, 클릭 0회, continue, 전면 미확인 로그' ('{0},{1},{2},{3},{4}' -f $script:nyanFocusCount, $script:nyanKeyCount, $script:nyanClickCount, $script:nyanReachedEnd, [bool]($script:nyanLogs -match '전면 미확인')) '1,0,0,False,True'
# ⑤ 사용자 조작 중(판독 뒤 재확인): 대기 1회 후 continue - A·클릭 0회
Reset-NyanMock -Words @(@{ Text = '뽑기'; X = 1163; Y = 649 }) -UserActive $true
. $nyanRerollBlock
Assert-Case '모의: 사용자 조작 중 → Wait-UserYieldEnd 1회, A 0회, 클릭 0회, continue' ('{0},{1},{2},{3}' -f $script:nyanYieldCount, $script:nyanKeyCount, $script:nyanClickCount, $script:nyanReachedEnd) '1,0,0,False'

# ── 공통 카드 규칙 (2026-09-13 실기 정체: 카드 존 OCR 간헐 검출·줄 순서 변동으로 '첫 가격표 2연속 일치' 26% 통과) ──
$tagA = @{ X = 480; Y = 414 }; $tagB = @{ X = 636; Y = 632 }; $tagC = @{ X = 793; Y = 414 }
$pick = Get-NyanStableTag -Current @($tagB, $tagA) -Previous @($tagA, $tagB)
Assert-Case '공통: 직전 [A,B]·현재 [B,A] → 현재 순서의 B' ('{0},{1}' -f $pick.X, $pick.Y) '636,632'
$pick = Get-NyanStableTag -Current @($tagA, $tagB) -Previous @($tagB)
Assert-Case '공통: 직전 [B]·현재 [A,B] → B (한 번만 본 A 금지)' ('{0},{1}' -f $pick.X, $pick.Y) '636,632'
Assert-Case '공통: 직전 [A]·현재 [B] → 없음' ($null -eq (Get-NyanStableTag -Current @($tagB) -Previous @($tagA))) 'True'
$moved = @{ X = 492; Y = 414 }
$pick = Get-NyanStableTag -Current @($moved) -Previous @($tagA)
Assert-Case '공통: ±12 이동 허용 + 선택 좌표는 현재 값' ('{0},{1}' -f $pick.X, $pick.Y) '492,414'
Assert-Case '공통: 한 축 13 이동은 거부' ($null -eq (Get-NyanStableTag -Current @(@{ X = 493; Y = 414 }) -Previous @($tagA))) 'True'
Assert-Case '공통: 직전 빈 배열 → 없음' ($null -eq (Get-NyanStableTag -Current @($tagA) -Previous @())) 'True'
Assert-Case '공통: 직전 $null → 없음' ($null -eq (Get-NyanStableTag -Current @($tagA) -Previous $null)) 'True'
Assert-Case '공통: 현재 빈 배열 → 없음' ($null -eq (Get-NyanStableTag -Current @() -Previous @($tagA))) 'True'
Assert-Case '공통: 현재의 null 항목은 무시' ('{0},{1}' -f (Get-NyanStableTag -Current @($null, $tagA) -Previous @($tagA)).X, (Get-NyanStableTag -Current @($null, $tagA) -Previous @($tagA)).Y) '480,414'
$common = @(Get-NyanCommonTags -Current @($tagA, $tagB, $tagC) -Previous @($tagC, $tagA))
Assert-Case '공통 목록: 직전 [C,A]·현재 [A,B,C] → [A,C] (현재 순서, B 제외)' (($common | ForEach-Object { $_.X }) -join ',') '480,793'
Assert-Case '공통 목록: 1개면 @() 수집으로 1칸 배열' (@(Get-NyanCommonTags -Current @($tagA) -Previous @($tagA))).Count 1
Assert-Case '공통 목록: 0개면 @() 수집으로 빈 배열' (@(Get-NyanCommonTags -Current @($tagA) -Previous @($tagB))).Count 0
# [A] → [B] → [A]: 호출부가 직전 판독을 '교체'해야 마지막 A 가 2연속으로 오인되지 않음 - 호출 시퀀스로 모의
$prevTags = @(); $seq = @(@($tagA), @($tagB), @($tagA)); $picks = @()
foreach ($cur in $seq) {
  $pk = Get-NyanStableTag -Current $cur -Previous $prevTags
  if ($null -eq $pk) { $prevTags = @($cur) }   # 워커 READY 의 교체 규칙
  $picks += , $(if ($null -eq $pk) { '-' } else { 'hit' })
}
Assert-Case '공통 시퀀스: [A]→[B]→[A] 는 전부 미확정 (교체 규칙 - 누적 금지)' ($picks -join ',') '-,-,-'
Assert-Case '배선: READY 는 Get-NyanStableTag + 공통 없으면 직전 판독 교체(누적 금지) + 700ms' `
  ([bool]($nyanCode -match '\$firstTag = Get-NyanStableTag -Current \$tags -Previous \$stableTags\s+if \(\$null -eq \$firstTag\) \{\s+\$stableTags = @\(\$tags\)\s+Start-Sleep -Milliseconds 700\s+continue')) 'True'
Assert-Case '배선: $stableTags 초기·판 전환 2곳 빈 배열 + 옛 단수 변수 0건' `
  ((([regex]::Matches($nyanCode, '\$stableTags = @\(\)')).Count -eq 2) -and (([regex]::Matches($nyanCode, '\$stableTag(?!s)')).Count -eq 0)) 'True'
Assert-Case '배선: $rerollPrevTags 는 재확인마다 최신 판독 전체로 갱신 + 초기·소진 시 빈 배열' `
  ((([regex]::Matches($nyanCode, '\$rerollPrevTags = @\(\$tagsNow\)')).Count -eq 1) -and (([regex]::Matches($nyanCode, '\$rerollPrevTags = @\(\)')).Count -eq 2) -and (([regex]::Matches($nyanCode, '\$rerollPrevTag(?!s)')).Count -eq 0)) 'True'
Assert-Case '배선: 체인 구매는 최신 단일 판독 유지 ($firstTag = $tagsNow[0])' `
  (([regex]::Matches($nyanCode, '\$firstTag = \$tagsNow\[0\]')).Count) 1

# ── 규칙 15 동결 (2026-09-13 구현 리뷰 지적: PURCHASE_WAIT 가 캡처 실패의 빈 배열을 '소멸'로 채택, REROLL_WAIT 가
#    실패 빈 배열로 $rerollCleared 를 세움, 재화 판독 실패 카운터가 캡처 실패를 소모). 예산 경과 = 시계 − 버린 폴링 시간. ──
$fakeClock = New-Object PSObject
$fakeClock | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:fakeElapsed }
$fakeClock | Add-Member -MemberType ScriptMethod -Name Stop -Value { $script:fakeRunning = $false }
$fakeClock | Add-Member -MemberType ScriptMethod -Name Start -Value { $script:fakeRunning = $true }
$script:fakeElapsed = 7900; $script:fakeRunning = $true
Assert-Case '예산: 7,900ms − 버린 0 → 7.9초' (Get-NyanWaitSeconds -Clock $fakeClock -LostMs 0) 7.9
$script:fakeElapsed = 8050
Assert-Case '예산: 8,050ms − 버린 150 → 7.9초 (실패 폴링은 예산 밖)' (Get-NyanWaitSeconds -Clock $fakeClock -LostMs 150) 7.9
$script:fakeElapsed = 4000
Assert-Case '예산: LostMs 생략 = 0' (Get-NyanWaitSeconds -Clock $fakeClock) 4
Assert-Case '배선: 냥코인·골드 판독 직후 캡처 실패 가드 (실패 카운터 미소모 → 상단 동결)' `
  ((([regex]::Matches($nyanCode, '\$coinNow = Read-NyanAmount -Game \$Game -Region \$rgNyanCoin\s+if \(\$script:screenCaptureFailing\) \{\s+Test-SafeStopDuringCaptureFail\s+continue\s+\}')).Count -eq 1) -and
   (([regex]::Matches($nyanCode, '\$goldNow = Read-NyanAmount -Game \$Game -Region \$rgNyanGold\s+if \(\$script:screenCaptureFailing\) \{\s+Test-SafeStopDuringCaptureFail\s+continue\s+\}')).Count -eq 1)) 'True'
Assert-Case '배선: PURCHASE_WAIT 판독 직후 동결 = 버린 시간 보정 → 시계 정지 → 복구까지 안전 검사·2초·탐침 반복 → 재개 → continue' `
  ([bool]($nyanCode -match '\$tagsNow = @\(Read-NyanPriceTags -Game \$Game\)\s+if \(\$script:screenCaptureFailing\) \{\s+\$purchaseWaitLostMs \+= \(\$purchaseWaitClock\.ElapsedMilliseconds - \$pollStartMs\)\s+\$purchaseWaitClock\.Stop\(\)\s+while \(\$script:screenCaptureFailing\) \{\s+Test-SafeStopDuringCaptureFail\s+Start-Sleep -Seconds 2\s+\[void\]\(Test-CaptureRecovered -Game \$Game\)\s+\}\s+\$purchaseWaitClock\.Start\(\)\s+continue\s+\}\s+if \(-not \(Test-NyanSameTag')) 'True'
Assert-Case '배선: REROLL_WAIT 판독 직후 캡처 실패 가드 (안전 검사 + 버린 시간 보정 + continue, cleared/카운터 손대지 않음)' `
  ([bool]($nyanCode -match '\$tagsNow = @\(Read-NyanPriceTags -Game \$Game\)\s+if \(\$script:screenCaptureFailing\) \{\s+Test-SafeStopDuringCaptureFail\s+\$rerollWaitLostMs \+= \(\$rerollWaitClock\.ElapsedMilliseconds - \$rerollPollStartMs\)\s+continue\s+\}\s+if \(@\(\$tagsNow\)\.Count -gt 0\) \{')) 'True'
# PURCHASE_WAIT 를 실제 소스에서 잘라 모의 시계로 실행 (시간 경계 - 설계 합의 조건)
$nyanPwSpan = [regex]::Match($nyanCode, '\$purchaseWaitLostMs = 0[\s\S]*?(?=\s+if \(-not \$purchaseGone\) \{)').Value
Assert-Case '모의: PURCHASE_WAIT 구간 추출' ($nyanPwSpan.Length -gt 300 -and $nyanPwSpan.Contains('while (')) 'True'
$nyanPwBlock = [scriptblock]::Create("foreach (`$nyanOnce in 1) {`n" + $nyanPwSpan + "`n}")
function Reset-PwMock {
  param([int]$ElapsedMs, [string[]]$Reads, [int]$RecoverAt = 1)
  $script:fakeElapsed = $ElapsedMs; $script:fakeRunning = $true
  $script:pwReads = [System.Collections.Generic.List[string]]$Reads; $script:pwRecoverAt = $RecoverAt
  $script:screenCaptureFailing = $false; $script:pwProbes = 0; $script:pwSafeStops = 0; $script:pwClicks = 0
  $script:lastClickPerformed = $false; $script:lastClickSkipReason = ''; $script:nyanLogs = @()
  $script:mockUserActive = $false; $script:mockForeground = $true   # 앞 블록의 모의 상태 초기화 (조작 중 아님·전면)
}
function Click-GamePoint { param($Game, $ReferenceX, $ReferenceY) $script:pwClicks++; $script:lastClickPerformed = $true }
function Start-Sleep { param([int]$Milliseconds = 0, [int]$Seconds = 0) if ($script:fakeRunning) { $script:fakeElapsed += ($Milliseconds + 1000 * $Seconds) } }
function Read-NyanPriceTags { param($Game)
  $kind = if ($script:pwReads.Count -gt 1) { $k = $script:pwReads[0]; $script:pwReads.RemoveAt(0); $k } else { $script:pwReads[0] }
  if ($kind -eq 'fail') { $script:screenCaptureFailing = $true; return @() }
  if ($kind -eq 'present') { return @(@{ X = 480; Y = 414 }) }
  return @()
}
function Test-SafeStopDuringCaptureFail { $script:pwSafeStops++ }
function Test-CaptureRecovered { param($Game) $script:pwProbes++; if ($script:pwProbes -ge $script:pwRecoverAt) { $script:screenCaptureFailing = $false; return $true }; return $false }
$purchaseWaitClock = $fakeClock; $firstTag = @{ X = 480; Y = 414 }
# ① 캡처 정상: 잔존 2회 → 소멸 (재클릭 없음, 버린 시간 0)
Reset-PwMock -ElapsedMs 0 -Reads @('present', 'present', 'gone'); $purchaseGone = $false; $reclicked = $false
. $nyanPwBlock
Assert-Case '모의 PW: 정상 경로 - 잔존·잔존·소멸 → 확인, 재클릭 0, 버린 시간 0' ('{0},{1},{2},{3}' -f $purchaseGone, $reclicked, $purchaseWaitLostMs, $script:pwSafeStops) 'True,False,0,0'
# ② 7.9초 진입 뒤 캡처 실패 → 탐침 2회째 복구 → 새 판독 소멸 (실패 폴링 150ms 는 예산 밖 - 무보정이면 8.05초로 미확인 종료)
Reset-PwMock -ElapsedMs 7900 -Reads @('fail', 'gone') -RecoverAt 2; $purchaseGone = $false; $reclicked = $false
. $nyanPwBlock
Assert-Case '모의 PW: 7.9초 진입 + 캡처 실패 → 복구 후 소멸 확인 (버린 150ms, 탐침 2, 안전 검사 2, 시계는 정지 중 안 흐름)' ('{0},{1},{2},{3},{4}' -f $purchaseGone, $purchaseWaitLostMs, $script:pwProbes, $script:pwSafeStops, $script:fakeElapsed) 'True,150,2,2,8200'
# ③ 복구 탐침 연속 실패 5회 → 복구 → 소멸
Reset-PwMock -ElapsedMs 0 -Reads @('fail', 'gone') -RecoverAt 5; $purchaseGone = $false; $reclicked = $false
. $nyanPwBlock
Assert-Case '모의 PW: 탐침 5회째 복구 - 그동안 안전 검사 5회, 예산 미소모' ('{0},{1},{2},{3}' -f $purchaseGone, $script:pwProbes, $script:pwSafeStops, (Get-NyanWaitSeconds -Clock $fakeClock -LostMs $purchaseWaitLostMs)) 'True,5,5,0.15'
# ④ 3.9초 진입 + 실패 → 복구 후 잔존 → 4초 재클릭 1회 → 소멸
Reset-PwMock -ElapsedMs 3900 -Reads @('fail', 'present', 'gone') -RecoverAt 1; $purchaseGone = $false; $reclicked = $false
. $nyanPwBlock
Assert-Case '모의 PW: 복구 후 잔존이면 4초 재클릭 1회 뒤 소멸 확인' ('{0},{1},{2}' -f $purchaseGone, $reclicked, $script:pwClicks) 'True,True,1'
# ⑤ 냥코인 판독 직후 캡처 실패: 실패 카운터 7 유지 + 안전 검사 + continue
$nyanCoinSpan = [regex]::Match($nyanCode, '\$coinNow = Read-NyanAmount -Game \$Game -Region \$rgNyanCoin\s+if \(\$script:screenCaptureFailing\) \{[\s\S]*?continue\s+\}').Value
$nyanCoinBlock = [scriptblock]::Create("foreach (`$nyanOnce in 1) {`n" + $nyanCoinSpan + "`n`$script:nyanReachedEnd = `$true`n}")
function Read-NyanAmount { param($Game, $Region) $script:screenCaptureFailing = $true; return [int64](-1) }
$coinFailStreak = 7; $script:pwSafeStops = 0; $script:nyanReachedEnd = $false; $rgNyanCoin = @(1085, 40, 125, 45)
. $nyanCoinBlock
Assert-Case '모의 재화: 캡처 실패 판독은 실패 카운터(7) 유지 + 안전 검사 1 + continue' ('{0},{1},{2}' -f $coinFailStreak, $script:pwSafeStops, $script:nyanReachedEnd) '7,1,False'

# ── 2026-09-14 구현 리뷰 반영: REROLL_WAIT 동결 시간 경계 + 재화 판독 창 좌표 예외 경계 + 카드 존 배율 상수 ──
Assert-Case '배선: Read-NyanPriceTags 가 카드 존 배율 상수($nyanCardsScale)를 사용' `
  ([bool]($workerText -match '-RegionWidth \$rgNyanCards\[2\] -RegionHeight \$rgNyanCards\[3\] -Scale \$nyanCardsScale -Engine \$ocrKoreanEngine')) 'True'
Assert-Case '배선: 카드 존 배율 상수 = 5 (라벨 실험 - 값 변경 시 test_nyan_cards_scale_offline 재검)' `
  ([bool]($workerText -match '(?m)^\$nyanCardsScale = 5\s*$')) 'True'
# 재화 판독: 창 좌표 실패 예외(플래그 선 채 throw)는 -1 로 경계 처리, 다른 예외는 그대로 (실제 함수 추출)
$readAmountDef = @(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Names @('Read-NyanAmount'))[0]
Invoke-Expression $readAmountDef
$ocrKoreanEngine = $null
function Get-GameRegionOcrText { param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine, [switch]$BinaryWhiteText)
  if ($script:amountMode -eq 'rect') { $script:screenCaptureFailing = $true; throw 'OCR용 게임 창 좌표를 읽지 못했습니다.' }
  if ($script:amountMode -eq 'other') { throw 'unexpected' }
  return '21,830,510'
}
$script:screenCaptureFailing = $false; $script:amountMode = 'ok'
Assert-Case '재화 경계: 정상 판독 → 값' (Read-NyanAmount -Game $null -Region @(935, 40, 150, 45)) 21830510
$script:amountMode = 'rect'
$rectResult = 'threw'   # 예외가 그대로 올라오면 FAIL 로 잡히게 (변이 검증: 경계 제거 시 스크립트가 죽어 무적발이었음)
try { $rectResult = Read-NyanAmount -Game $null -Region @(935, 40, 150, 45) } catch { $rectResult = 'threw' }
Assert-Case '재화 경계: 창 좌표 실패(플래그 선 채 throw) → -1 (동결 경로로)' $rectResult (-1)
$script:screenCaptureFailing = $false; $script:amountMode = 'other'
$otherRethrown = $false
try { [void](Read-NyanAmount -Game $null -Region @(935, 40, 150, 45)) } catch { $otherRethrown = ($_.Exception.Message -eq 'unexpected') }
Assert-Case '재화 경계: 플래그 없는 다른 예외는 그대로 올림' $otherRethrown 'True'
# REROLL_WAIT 구간을 실제 소스에서 잘라 모의 시계로 실행 (시간 경계: 안전 검사 비용이 예산에 누적되지 않아야 함)
$nyanRwSpan = [regex]::Match($nyanCode, '\$rerollWaitLostMs = 0[\s\S]*?(?=\s+if \(\$rerollSeen -lt 2\) \{)').Value
Assert-Case '모의: REROLL_WAIT 구간 추출' ($nyanRwSpan.Length -gt 300 -and $nyanRwSpan.Contains('while (')) 'True'
$nyanRwBlock = [scriptblock]::Create("foreach (`$nyanOnce in 1) {`n" + $nyanRwSpan + "`n}")
function Test-SafeStopDuringCaptureFail { $script:pwSafeStops++; if ($script:fakeRunning) { $script:fakeElapsed += 20 } }   # 검사 비용 20ms 모의 (시계가 돌 때만 누적)
$rerollWaitClock = $fakeClock
function Reset-RwMock { param([int]$ElapsedMs, [string[]]$Reads, [int]$RecoverAt = 1)
  Reset-PwMock -ElapsedMs $ElapsedMs -Reads $Reads -RecoverAt $RecoverAt
  $script:rerollSeen = 0; $script:rerollPrevTags = @(); $script:stableTags = @(); $script:pendingBoardTags = $null; $script:pendingBoardTagsClock = $null
}
# ① 11.5초 진입 + 캡처 실패 → 탐침 5회째 복구(그동안 안전 검사 5회 × 20ms 는 시계 정지 중) → 재등장 2연속 → 완료
Reset-RwMock -ElapsedMs 11500 -Reads @('fail', 'present', 'present') -RecoverAt 5
$rerollSeen = 0; $rerollPrevTags = @(); $rerollCleared = $true; $boardLimitReached = $false; $stableTags = @(); $pendingBoardTags = $null
. $nyanRwBlock
Assert-Case '모의 RW: 11.5초 진입 + 실패 → 복구까지 시계 정지(안전 검사 5회) → 재등장 2연속 완료 (버린 400ms + 판독 직후 안전 검사 20ms 도 보정, 예산 12초 안)' ('{0},{1},{2},{3}' -f $rerollSeen, $script:pwProbes, $rerollWaitLostMs, (Get-NyanWaitSeconds -Clock $fakeClock -LostMs $rerollWaitLostMs)) '2,5,420,12.15'
# ② 실패 없음: 0개 1회 뒤 재등장 2연속 (한도 경로 - cleared 선행)
Reset-RwMock -ElapsedMs 0 -Reads @('present', 'gone', 'present', 'present')
$rerollSeen = 0; $rerollPrevTags = @(); $rerollCleared = $false; $boardLimitReached = $true; $stableTags = @(); $pendingBoardTags = $null
. $nyanRwBlock
Assert-Case '모의 RW: 한도 경로 - 구판 잔존(present) 무시 → 0개 1회 → 재등장 2연속 → 완료, pending 은 공통 카드' ('{0},{1},{2}' -f $rerollSeen, $rerollCleared, @($pendingBoardTags).Count) '2,True,1'

# ── 배선 가드 (GUI) ──
Assert-Case 'GUI: 기타 시작 시 커스텀 경로 배제' `
  ([bool]($guiText -match '-not \$isLifeStart -and -not \$isEtcStart\)\)')) 'True'
Assert-Case 'GUI: 기타 반복 그룹 숨김 + 상단 블록 이동' `
  (($guiText.Contains('$grpRepeat.Visible = -not $isEtc')) -and
   ($guiText -match '\$etcShiftTop = \$\(if \(\$isEtc\) \{ -60 \} else \{ 0 \}\)')) 'True'
Assert-Case 'GUI: etc 설정 저장 4키' `
  ([bool]($guiText -match "foreach \(\`$etcKey in @\('content', 'nyanTargetCoins', 'goldLimitEnabled', 'goldLimitGold'\)\)")) 'True'
Assert-Case 'GUI: 골드 상한 체크가 입력 활성 제어' `
  ([bool]($guiText -match '\$numEtcGoldLimit\.Enabled = \[bool\]\$chkEtcGoldLimit\.Checked')) 'True'
Assert-Case "GUI: 로그 색 매퍼가 '기타' 태그 인지" `
  ($guiText.Contains("'\[(던전|어비스|심층|사냥터|생활|기타|커스텀|파티원|설정)\]'")) 'True'
Assert-Case 'GUI: 안전 중지 안내에 etc 전용 분기 (전투 문구 오안내 방지)' `
  (($guiText -match "elseif \(\`$script:mainCategory -eq 'etc'\)") -and
   ($guiText.Contains('이번 판을 마치면 멈춥니다'))) 'True'

exit $fails
