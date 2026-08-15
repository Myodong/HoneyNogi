# 냥코인 뽑기(기타 - 고양이 상인) 판정 진리표 + 배선 가드 (2026-08-15 신설)
# 실측 근거: 던전이미지\고양이상인\ 캡처 4장(1272×1 + 네이티브 1908×3) 스윕 판독문
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-NyanNumberValue', 'Test-NyanMerchantTitle', 'Get-NyanPriceTags', 'Test-NyanSameTag', 'Test-NyanCoinSuspect', 'Get-NyanCoinCorrection')) {
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
# 경과 시간 판정(폴링 500ms, 재클릭 4초, 타임아웃 8초)으로 바뀜 (Codex 조건 - OCR 소요 때문에
# 횟수×간격은 벽시계가 아님). 벽시계 계약(4초/8초)은 그대로.
Assert-Case '배선: 재클릭은 최대 1회 ($reclicked 래치, 경과 4초 판정)' `
  ([bool]($workerText -match 'if \(\$purchaseWaitClock\.Elapsed\.TotalSeconds -ge 4 -and -not \$reclicked\)')) 'True'
Assert-Case '배선: 구매 확인은 경과 8초 타임아웃 + 500ms 폴링' `
  ([bool]($workerText -match 'while \(\$purchaseWaitClock\.Elapsed\.TotalSeconds -lt 8\) \{\r?\n\s+Start-Sleep -Milliseconds 500')) 'True'
# 2026-08-15 재개정: 사용자 추가 단축 요청으로 '무조건 1200ms'가 '경계 근접/미확정 1200ms,
# 원거리 300ms' 조건부로 완화됨 (Codex 승인 명시적 계약 완화 - stale-low는 경계 부근에서만
# 유해, 여유폭 냥코인 30만/골드 10만은 현상금·가격표 실측 상한의 3~12배)
Assert-Case '배선: 확인 후 대기가 경계 조건부 (근접·미확정 1200ms / 원거리 300ms)' `
  ([bool]($workerText -match '\$nearTarget = \(\$lastCoinValue -lt 0 -or \(\$nyanTargetCoins - \$lastCoinValue\) -le 300000\)[\s\S]{0,400}if \(\$nearTarget -or \$nearGoldLimit\) \{ Start-Sleep -Milliseconds 1200 \} else \{ Start-Sleep -Milliseconds 300 \}')) 'True'
Assert-Case '배선: 골드 상한 경계도 여유폭 10만으로 검사 ($lastGoldValue 추적 포함)' `
  (($workerText -match '\$nearGoldLimit = \(\$lastGoldValue -lt 0 -or \(\$nyanGoldLimit - \(\$startGold - \$lastGoldValue\)\) -le 100000\)') -and
   ($workerText -match '\$goldFailStreak = 0\r?\n\s+\$lastGoldValue = \$goldNow')) 'True'
Assert-Case '배선: 소멸 확정 판독으로 안정 1연속 시딩 (빈 판은 $null - 새 판 2연속 유지)' `
  ([bool]($workerText -match '\$stableTag = \$\(if \(@\(\$tagsNow\)\.Count -gt 0\) \{ \$tagsNow\[0\] \} else \{ \$null \}\)')) 'True'
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
Assert-Case '배선: 시딩 성공 시 확정 판독을 pendingBoardTags 로 재사용' `
  ([bool]($workerText -match '\$stableTag = \$tagsNow\[0\]\r?\n\s+\$pendingBoardTags = \$tagsNow\r?\n\s+\$pendingBoardTagsClock = \[System\.Diagnostics\.Stopwatch\]::StartNew\(\)')) 'True'
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
  ([bool]($workerText -match 'while \(\$rerollWaitClock\.Elapsed\.TotalSeconds -lt 12\) \{[\s\S]{0,400}Start-Sleep -Milliseconds \$\(if \(\$rerollSeen -ge 1\) \{ 250 \} else \{ 400 \}\)')) 'True'
Assert-Case '배선: REROLL_WAIT 캡처 실패 중 시계 동결 (Stop→복구 탐침→Start)' `
  ([bool]($workerText -match '\$rerollWaitClock\.Stop\(\)[\s\S]{0,120}Test-CaptureRecovered -Game \$Game[\s\S]{0,60}\$rerollWaitClock\.Start\(\)')) 'True'
Assert-Case '배선: 재등장 2연속 좌표 일치 시 $stableTag 시딩' `
  ([bool]($workerText -match '\$rerollPrevTag\.Y\) -le 12\) \{\r?\n\s+\$stableTag = \$tagsNow\[0\]')) 'True'
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
Assert-Case '배선: 안전 중지 flag 확인이 다시 뽑기 클릭 직전 (소비 → exit 4 → Focus/클릭 순서)' `
  ([bool]($workerText -match 'if \(Test-Path -LiteralPath \$safeStopFlagPath\) \{\r?\n\s+Remove-Item -LiteralPath \$safeStopFlagPath[^\r\n]*\r?\n\s+Write-RunLog \("\[완료\] 안전 중지[\s\S]{0,100}exit 4\r?\n\s+\}\r?\n\s+Focus-Game -Game \$Game')) 'True'
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
   ($workerText.Contains('$rgNyanGold   = @(935, 40, 150, 45)')) -and
   ($workerText.Contains('$rgNyanCards  = @(390, 330, 480, 340)')) -and
   ($workerText.Contains('$rgNyanReroll = @(1090, 630, 170, 50)'))) 'True'

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
