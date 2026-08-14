# 냥코인 뽑기(기타 - 고양이 상인) 판정 진리표 + 배선 가드 (2026-08-15 신설)
# 실측 근거: 던전이미지\고양이상인\ 캡처 4장(1272×1 + 네이티브 1908×3) 스윕 판독문
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-NyanNumberValue', 'Test-NyanMerchantTitle', 'Get-NyanPriceTags', 'Test-NyanSameTag')) {
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

# ── 좌표 소멸 확인 (±12) ──
$sameTags = @(@{ X = 705; Y = 373 }, @{ X = 492; Y = 377 })
Assert-Case '소멸: 같은 좌표(±12) 잔존 → true' (Test-NyanSameTag -Tags $sameTags -X 710 -Y 380) 'True'
Assert-Case '소멸: 그 좌표만 사라짐 → false (다른 카드의 같은 금액은 증거 아님)' (Test-NyanSameTag -Tags @(@{ X = 492; Y = 377 }) -X 705 -Y 373) 'False'
Assert-Case '소멸: 빈 목록 → false' (Test-NyanSameTag -Tags @() -X 705 -Y 373) 'False'
Assert-Case '소멸: 30px 차이는 다른 카드 (±12 계약 - 이웃 카드 오인 금지)' (Test-NyanSameTag -Tags @(@{ X = 735; Y = 373 }) -X 705 -Y 373) 'False'

# ── 배선 가드 (워커) ──
Assert-Case "배선: 기타 분기(etc → Invoke-NyanMerchantRun)" `
  ([bool]($workerText -match "if \(\`$mainCategory -eq 'etc'\) \{[\s\S]{0,200}Invoke-NyanMerchantRun -Game \`$game")) 'True'
Assert-Case '배선: 구매 확인은 클릭한 좌표의 소멸 (Test-NyanSameTag)' `
  ([bool]($workerText -match 'Test-NyanSameTag -Tags \$tagsNow -X \(\[int\]\$firstTag\.X\) -Y \(\[int\]\$firstTag\.Y\)')) 'True'
Assert-Case '배선: 재클릭은 최대 1회 ($reclicked 래치)' `
  ([bool]($workerText -match 'if \(\$purchaseTry -ge 4 -and -not \$reclicked\)')) 'True'
Assert-Case '배선: 가격표 0개 3연속 후에만 다시 뽑기' `
  ([bool]($workerText -match '\$emptyStreak\+\+[\s\S]{0,80}if \(\$emptyStreak -lt 3\)')) 'True'
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

exit $fails
