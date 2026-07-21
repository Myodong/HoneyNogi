# 커스텀 반복 - 전진/완주/지문(6조각)/시작 게이트/리스트 표기 왕복 진리표 (계약 v2, 2026-07-20)
# 본체 순수 함수는 AST로 직접 불러오고, WinForms 행 표기/시작 게이트만 시뮬레이터로 검증합니다.
# 계약 v2: 토큰 6조각(난이도|스테이지|coin|doubleLoot|exhaustContinue|noDoubleSweep),
#          압축 표기 '어1-3(20,소·진)' 형식, 리스트 행 표기 ↔ 역해석 왕복 일치.
$fails = 0

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_gui.ps1') `
    -Names @('Format-CustomItemToken', 'Get-CustomFingerprint', 'Get-CustomNextProgress',
      'Test-CustomLapComplete', 'Get-CustomPositionText', 'Get-CustomItemLabel',
      'Get-CustomListCompact', 'Get-CustomCoinTotalPerLap')) {
  Invoke-Expression $definition
}

# ---------- 시뮬레이터: WinForms 리스트 행 표기 / 역해석 ----------
# WinForms 없이 문자열 계산부만 사본으로 검증합니다 (행 표기 ↔ 역해석 왕복 일치가 계약 -
# 불일치하면 재저장 때 지문이 바뀌어 진행 기록이 초기화되는 사고).
function Get-CustomRowTexts {
  param([string]$Difficulty, [string]$Stage, [bool]$Coin, [bool]$DoubleLoot,
    [bool]$ExhaustContinue, [bool]$NoDoubleSweep)
  $exhaustText = if (-not $Coin) { '—' }
  elseif ($DoubleLoot -and -not $NoDoubleSweep) { '—' }
  elseif ($ExhaustContinue) { '진행' } else { '멈춤' }
  $noDoubleText = if (-not $DoubleLoot) { '—' }
  elseif ($NoDoubleSweep) { '소탕만' } else { '멈춤' }
  $coinText = $(if ($Coin -and $DoubleLoot) { '20개' } elseif ($Coin) { '10개' } else { '0개' })
  return @{ Coin = $coinText; Exhaust = $exhaustText; NoDouble = $noDoubleText }
}

function ConvertFrom-CustomRowTexts {
  param([string]$Difficulty, [string]$Stage, [string]$CoinText, [string]$ExhaustText, [string]$NoDoubleText)
  return [pscustomobject]@{
    difficulty      = [string]$Difficulty
    stage           = [string]$Stage
    coin            = ($CoinText -ne '0개')
    doubleLoot      = ($CoinText -eq '20개')
    exhaustContinue = ($ExhaustText -eq '진행')
    noDoubleSweep   = ($NoDoubleText -eq '소탕만')
  }
}

# ---------- 시뮬레이터: btnCrAdd 정규화 (라디오/체크 상태 → 저장할 항목 속성) ----------
# coin=false → 둘 다 false / double=false → noDoubleSweep=false /
# double+멈춤(noDoubleSweep=false) → exhaustContinue 도 false (리스트 '—' 역해석과 일치)
function Get-CustomAddNormalized {
  param([bool]$CoinChecked, [bool]$DoubleChecked, [bool]$ExhaustGoChecked, [bool]$NoDoubleSweepChecked)
  $crCoinValue = [bool]$CoinChecked
  $crDoubleValue = [bool]($crCoinValue -and $DoubleChecked)
  $crNoDoubleValue = [bool]($crDoubleValue -and $NoDoubleSweepChecked)
  $crExhaustValue = [bool]($crCoinValue -and $ExhaustGoChecked -and
    ((-not $crDoubleValue) -or $crNoDoubleValue))
  return @{ coin = $crCoinValue; doubleLoot = $crDoubleValue
            exhaustContinue = $crExhaustValue; noDoubleSweep = $crNoDoubleValue }
}

# ---------- 시뮬레이터: btnStart 시작 게이트 (빈 리스트/지문 불일치/lap>N) ----------
function Invoke-StartGateSim {
  param($Items, $Progress, [string]$ListRepeat, [int]$ListRepeatCount)
  $crItems = @($Items)
  if ($crItems.Count -eq 0) { return '거부-빈리스트' }
  $crProgress = $Progress
  if ($crProgress) {
    $savedFingerprint = ''
    try { $savedFingerprint = [string]$crProgress.fingerprint } catch { }
    if ($savedFingerprint -ne (Get-CustomFingerprint -Items $crItems)) {
      # 본체: Reset-CustomProgress '리스트 변경 - 처음부터'
      return '리셋-리스트변경'
    }
  }
  if ($crProgress) {
    $crLapNow = 1
    try { $crLapNow = [int]$crProgress.lap } catch { }
    if (Test-CustomLapComplete -ListRepeat $ListRepeat -ListRepeatCount $ListRepeatCount -Lap $crLapNow) {
      # 본체: Reset-CustomProgress '완주 취급 - 새 1바퀴'
      return '리셋-완주취급'
    }
    return '이어가기'
  }
  return '새시작'
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ---------- 진리표 ① 전진 (lap 1시작 / index 0시작 / 끝이면 index=0·lap+1) ----------
$p = Get-CustomNextProgress -Progress $null -ItemCount 4
Assert-Case '전진: 첫 판(진행 없음, 4항목)' "$($p.lap)/$($p.index)" '1/1'
$p = Get-CustomNextProgress -Progress ([pscustomobject]@{lap=1; index=2}) -ItemCount 4
Assert-Case '전진: 중간(1바퀴 3번째 완료)' "$($p.lap)/$($p.index)" '1/3'
$p = Get-CustomNextProgress -Progress ([pscustomobject]@{lap=1; index=3}) -ItemCount 4
Assert-Case '전진: 리스트 끝 wrap(index=0, lap+1)' "$($p.lap)/$($p.index)" '2/0'
$p = Get-CustomNextProgress -Progress $null -ItemCount 1
Assert-Case '전진: 1항목 리스트 첫 판 = 즉시 wrap' "$($p.lap)/$($p.index)" '2/0'
$p = Get-CustomNextProgress -Progress ([pscustomobject]@{lap=5; index=0}) -ItemCount 1
Assert-Case '전진: 1항목 리스트 매판 lap+1' "$($p.lap)/$($p.index)" '6/0'
$p = Get-CustomNextProgress -Progress ([pscustomobject]@{lap=0; index=-3}) -ItemCount 4
Assert-Case '전진: 손상값(lap 0/index 음수) 방어' "$($p.lap)/$($p.index)" '1/1'
$p = Get-CustomNextProgress -Progress $null -ItemCount 0
Assert-Case '전진: ItemCount 0 방어(1로 취급)' "$($p.lap)/$($p.index)" '2/0'

# ---------- 진리표 ① 완주 (전진 "후" lap -gt N / 무한은 항상 false) ----------
Assert-Case '완주: 무한 모드는 lap 무관 false' (Test-CustomLapComplete 'infinite' 1 99) 'False'
Assert-Case '완주: N=1 전진 후 lap 1 (마지막 판 전)' (Test-CustomLapComplete 'count' 1 1) 'False'
Assert-Case '완주: N=1 전진 후 lap 2 (off-by-one 경계)' (Test-CustomLapComplete 'count' 1 2) 'True'
Assert-Case '완주: N=3 전진 후 lap 3 (마지막 바퀴 진행 중)' (Test-CustomLapComplete 'count' 3 3) 'False'
Assert-Case '완주: N=3 전진 후 lap 4' (Test-CustomLapComplete 'count' 3 4) 'True'
Assert-Case '완주: N=0 손상값은 1로 취급' (Test-CustomLapComplete 'count' 0 2) 'True'

# 총 판수 시뮬레이션: T항목 x N바퀴 = T*N판 후 정확히 완주 (조기/지각 정지 금지)
function Get-TotalPlays {
  param([int]$ItemCount, [int]$LapTarget)
  $plays = 0; $prog = $null
  while ($plays -lt 50) {
    $plays++
    $prog = Get-CustomNextProgress -Progress $prog -ItemCount $ItemCount
    if (Test-CustomLapComplete -ListRepeat 'count' -ListRepeatCount $LapTarget -Lap ([int]$prog.lap)) { return $plays }
  }
  return -1
}
Assert-Case '총판수: 1항목 x 1바퀴 = 1판' (Get-TotalPlays 1 1) '1'
Assert-Case '총판수: 3항목 x 1바퀴 = 3판' (Get-TotalPlays 3 1) '3'
Assert-Case '총판수: 2항목 x 2바퀴 = 4판' (Get-TotalPlays 2 2) '4'
Assert-Case '총판수: 4항목 x 3바퀴 = 12판' (Get-TotalPlays 4 3) '12'

# ---------- 진리표 ① 지문 (토큰 6조각 형식 / 순서·옵션·소진 대응 변경 감지) ----------
$itemA = @{ difficulty='어려움'; stage='1-3'; coin=$true; doubleLoot=$true; exhaustContinue=$true; noDoubleSweep=$true }
$itemB = @{ difficulty='일반'; stage='2-1'; coin=$false; doubleLoot=$false; exhaustContinue=$false; noDoubleSweep=$false }
$itemC = @{ difficulty='일반'; stage='2-1'; coin=$true; doubleLoot=$false; exhaustContinue=$false; noDoubleSweep=$false }
$itemD = @{ difficulty='어려움'; stage='1-3'; coin=$true; doubleLoot=$true; exhaustContinue=$false; noDoubleSweep=$false }
Assert-Case '토큰: 어려움 1-3 은+더+소진진행+소탕만' (Format-CustomItemToken $itemA) '어려움|1-3|1|1|1|1'
Assert-Case '토큰: 일반 2-1 옵션 없음' (Format-CustomItemToken $itemB) '일반|2-1|0|0|0|0'
Assert-Case '토큰: 구버전 항목(뒤 2필드 부재)은 0 처리' (Format-CustomItemToken @{ difficulty='일반'; stage='1-1'; coin=$true; doubleLoot=$false }) '일반|1-1|1|0|0|0'
Assert-Case '지문: 2항목 join' (Get-CustomFingerprint @($itemA, $itemB)) '어려움|1-3|1|1|1|1;일반|2-1|0|0|0|0'
Assert-Case '지문: 순서 변경 감지' ((Get-CustomFingerprint @($itemA, $itemB)) -ne (Get-CustomFingerprint @($itemB, $itemA))) 'True'
Assert-Case '지문: 은동전 토글 감지' ((Get-CustomFingerprint @($itemB)) -ne (Get-CustomFingerprint @($itemC))) 'True'
Assert-Case '지문: 소진 대응 속성 토글 감지' ((Get-CustomFingerprint @($itemA)) -ne (Get-CustomFingerprint @($itemD))) 'True'
Assert-Case '지문: 빈 리스트 = 빈 문자열' (Get-CustomFingerprint @()) ''

# ---------- 진리표 ① 시작 게이트 (빈 리스트 거부 / 지문 불일치 리셋 / lap>N 완주 취급) ----------
$list2 = @($itemA, $itemB)
$fp2 = Get-CustomFingerprint -Items $list2
Assert-Case '게이트: 빈 리스트 시작 거부' (Invoke-StartGateSim @() $null 'infinite' 1) '거부-빈리스트'
Assert-Case '게이트: 진행 없음 새 시작' (Invoke-StartGateSim $list2 $null 'count' 2) '새시작'
Assert-Case '게이트: 지문 일치 이어가기' (Invoke-StartGateSim $list2 ([pscustomobject]@{lap=2; index=1; fingerprint=$fp2}) 'count' 3) '이어가기'
Assert-Case '게이트: 지문 불일치(리스트 변경) 리셋' (Invoke-StartGateSim $list2 ([pscustomobject]@{lap=2; index=1; fingerprint='어려움|1-3|1|1'}) 'count' 3) '리셋-리스트변경'
Assert-Case '게이트: 저장 lap>N 완주 취급 리셋' (Invoke-StartGateSim $list2 ([pscustomobject]@{lap=3; index=0; fingerprint=$fp2}) 'count' 2) '리셋-완주취급'
Assert-Case '게이트: 저장 lap=N 은 이어가기(마지막 바퀴)' (Invoke-StartGateSim $list2 ([pscustomobject]@{lap=2; index=0; fingerprint=$fp2}) 'count' 2) '이어가기'
Assert-Case '게이트: 무한 모드는 lap 커도 이어가기' (Invoke-StartGateSim $list2 ([pscustomobject]@{lap=99; index=1; fingerprint=$fp2}) 'infinite' 1) '이어가기'
Assert-Case '게이트: 지문 불일치가 완주 검사보다 우선' (Invoke-StartGateSim $list2 ([pscustomobject]@{lap=9; index=0; fingerprint='다른지문'}) 'count' 2) '리셋-리스트변경'

# ---------- 표기 함수 (위치/라벨/압축) ----------
Assert-Case '위치 표기: index 0시작 → +1' (Get-CustomPositionText 2 2 4) '2바퀴째 3/4번'
Assert-Case '위치 표기: 첫 판' (Get-CustomPositionText 1 0 3) '1바퀴째 1/3번'
Assert-Case '라벨: 은동전+더블' (Get-CustomItemLabel $itemA) '어려움 1-3 (은동전·더블 루팅)'
Assert-Case '라벨: 은동전만' (Get-CustomItemLabel $itemC) '일반 2-1 (은동전)'
Assert-Case '라벨: 옵션 없음' (Get-CustomItemLabel $itemB) '일반 2-1'

# 압축 표기 (계약 v2 - [설정] 제보 분석용): 계약 문서의 예시 문자열과 정확히 일치해야 합니다
$itemE = @{ difficulty='일반'; stage='2-3'; coin=$false; doubleLoot=$false; exhaustContinue=$false; noDoubleSweep=$false }
Assert-Case '압축: 계약 예시 4항목' (Get-CustomListCompact @($itemA, $itemD, $itemC, $itemE)) '1.어1-3(20,소·진) 2.어1-3(20,멈) 3.일2-1(10,멈) 4.일2-3(0)'
Assert-Case '압축: 코인만+소진 진행 = (10,진)' (Get-CustomListCompact @(@{ difficulty='일반'; stage='1-1'; coin=$true; doubleLoot=$false; exhaustContinue=$true; noDoubleSweep=$false })) '1.일1-1(10,진)'
Assert-Case '압축: 더블+소탕만+소진 멈춤 = (20,소·멈)' (Get-CustomListCompact @(@{ difficulty='어려움'; stage='2-2'; coin=$true; doubleLoot=$true; exhaustContinue=$false; noDoubleSweep=$true })) '1.어2-2(20,소·멈)'
Assert-Case '압축: 구버전 항목(뒤 2필드 부재) = 멈춤 취급' (Get-CustomListCompact @(@{ difficulty='일반'; stage='1-2'; coin=$true; doubleLoot=$false })) '1.일1-2(10,멈)'

# ---------- 진리표 ⑦ 리스트 행 표기 규칙 + 역해석 왕복 (round-trip) ----------
# 행 표기 규칙: 소진 시 = coin 아니면 — / 더블+멈춤이면 —(도달 불가) / 진행·멈춤,
#              더블 불가 시 = double 아니면 — / 소탕만·멈춤. 은동전 열 = 20개/10개/0개.
$rt = Get-CustomRowTexts '일반' '2-1' $false $false $false $false
Assert-Case '행 표기: 미사용 → 0개/—/—' "$($rt.Coin)/$($rt.Exhaust)/$($rt.NoDouble)" '0개/—/—'
$rt = Get-CustomRowTexts '일반' '2-1' $true $false $true $false
Assert-Case '행 표기: 코인만+진행 → 10개/진행/—' "$($rt.Coin)/$($rt.Exhaust)/$($rt.NoDouble)" '10개/진행/—'
$rt = Get-CustomRowTexts '일반' '2-1' $true $false $false $false
Assert-Case '행 표기: 코인만+멈춤 → 10개/멈춤/—' "$($rt.Coin)/$($rt.Exhaust)/$($rt.NoDouble)" '10개/멈춤/—'
$rt = Get-CustomRowTexts '어려움' '1-3' $true $true $false $false
Assert-Case '행 표기: 더블+멈춤 → 20개/—(도달 불가)/멈춤' "$($rt.Coin)/$($rt.Exhaust)/$($rt.NoDouble)" '20개/—/멈춤'
$rt = Get-CustomRowTexts '어려움' '1-3' $true $true $false $true
Assert-Case '행 표기: 더블+소탕만+소진 멈춤 → 20개/멈춤/소탕만' "$($rt.Coin)/$($rt.Exhaust)/$($rt.NoDouble)" '20개/멈춤/소탕만'
$rt = Get-CustomRowTexts '어려움' '1-3' $true $true $true $true
Assert-Case '행 표기: 더블+소탕만+소진 진행 → 20개/진행/소탕만' "$($rt.Coin)/$($rt.Exhaust)/$($rt.NoDouble)" '20개/진행/소탕만'

# 왕복: 정규화된 항목 → 행 표기 → 역해석 → 토큰 동일 (정규화 도달 가능한 6가지 상태 전부).
# 여기가 어긋나면 리스트 재저장 시 지문이 바뀌어 진행 기록이 초기화되는 사고가 납니다.
$normalizedStates = @(
  @{ difficulty='일반';   stage='2-1'; coin=$false; doubleLoot=$false; exhaustContinue=$false; noDoubleSweep=$false },
  @{ difficulty='일반';   stage='1-1'; coin=$true;  doubleLoot=$false; exhaustContinue=$false; noDoubleSweep=$false },
  @{ difficulty='일반';   stage='1-2'; coin=$true;  doubleLoot=$false; exhaustContinue=$true;  noDoubleSweep=$false },
  @{ difficulty='어려움'; stage='1-3'; coin=$true;  doubleLoot=$true;  exhaustContinue=$false; noDoubleSweep=$false },
  @{ difficulty='어려움'; stage='2-2'; coin=$true;  doubleLoot=$true;  exhaustContinue=$false; noDoubleSweep=$true },
  @{ difficulty='어려움'; stage='2-3'; coin=$true;  doubleLoot=$true;  exhaustContinue=$true;  noDoubleSweep=$true }
)
foreach ($rtItem in $normalizedStates) {
  $rowTexts = Get-CustomRowTexts -Difficulty $rtItem.difficulty -Stage $rtItem.stage `
    -Coin $rtItem.coin -DoubleLoot $rtItem.doubleLoot `
    -ExhaustContinue $rtItem.exhaustContinue -NoDoubleSweep $rtItem.noDoubleSweep
  $parsedBack = ConvertFrom-CustomRowTexts -Difficulty $rtItem.difficulty -Stage $rtItem.stage `
    -CoinText $rowTexts.Coin -ExhaustText $rowTexts.Exhaust -NoDoubleText $rowTexts.NoDouble
  $caseName = '왕복: {0}' -f (Format-CustomItemToken $rtItem)
  Assert-Case $caseName (Format-CustomItemToken $parsedBack) (Format-CustomItemToken $rtItem)
}

# ---------- 진리표 ⑧ [추가] 정규화 (라디오/체크 상태 → 저장 속성) ----------
function Describe-Norm {
  param($N)
  return ('{0}/{1}/{2}/{3}' -f $N.coin, $N.doubleLoot, $N.exhaustContinue, $N.noDoubleSweep)
}
# 라디오/체크 16조합 전부: 정규화 결과가 왕복 가능한 6가지 상태 중 하나로 떨어져야 합니다
Assert-Case '정규화: 코인 해제면 라디오 무관 전부 false' (Describe-Norm (Get-CustomAddNormalized $false $true $true $true)) 'False/False/False/False'
Assert-Case '정규화: 코인 해제(라디오도 멈춤)' (Describe-Norm (Get-CustomAddNormalized $false $false $false $false)) 'False/False/False/False'
Assert-Case '정규화: 코인만+멈춤' (Describe-Norm (Get-CustomAddNormalized $true $false $false $false)) 'True/False/False/False'
Assert-Case '정규화: 코인만+진행' (Describe-Norm (Get-CustomAddNormalized $true $false $true $false)) 'True/False/True/False'
Assert-Case '정규화: 코인만이면 더블 라디오 무시' (Describe-Norm (Get-CustomAddNormalized $true $false $true $true)) 'True/False/True/False'
Assert-Case '정규화: 더블+멈춤 → exhaust 도 강제 false (지문 보존 계약)' (Describe-Norm (Get-CustomAddNormalized $true $true $true $false)) 'True/True/False/False'
Assert-Case '정규화: 더블+멈춤+소진 멈춤' (Describe-Norm (Get-CustomAddNormalized $true $true $false $false)) 'True/True/False/False'
Assert-Case '정규화: 더블+소탕만+소진 진행' (Describe-Norm (Get-CustomAddNormalized $true $true $true $true)) 'True/True/True/True'
Assert-Case '정규화: 더블+소탕만+소진 멈춤' (Describe-Norm (Get-CustomAddNormalized $true $true $false $true)) 'True/True/False/True'

# 정규화 → 행 표기 → 역해석 왕복까지 한 번에 (16조합 전수 - 저장/재저장 지문 불변 보장)
foreach ($coinChecked in @($false, $true)) {
  foreach ($doubleChecked in @($false, $true)) {
    foreach ($exhaustGo in @($false, $true)) {
      foreach ($sweepGo in @($false, $true)) {
        $norm = Get-CustomAddNormalized $coinChecked $doubleChecked $exhaustGo $sweepGo
        $normItem = @{ difficulty='일반'; stage='1-1'; coin=$norm.coin; doubleLoot=$norm.doubleLoot
                       exhaustContinue=$norm.exhaustContinue; noDoubleSweep=$norm.noDoubleSweep }
        $rowTexts = Get-CustomRowTexts -Difficulty '일반' -Stage '1-1' `
          -Coin $normItem.coin -DoubleLoot $normItem.doubleLoot `
          -ExhaustContinue $normItem.exhaustContinue -NoDoubleSweep $normItem.noDoubleSweep
        $parsedBack = ConvertFrom-CustomRowTexts -Difficulty '일반' -Stage '1-1' `
          -CoinText $rowTexts.Coin -ExhaustText $rowTexts.Exhaust -NoDoubleText $rowTexts.NoDouble
        $caseName = '정규화 왕복: 체크 {0}/{1}/{2}/{3}' -f $coinChecked, $doubleChecked, $exhaustGo, $sweepGo
        Assert-Case $caseName (Format-CustomItemToken $parsedBack) (Format-CustomItemToken $normItem)
      }
    }
  }
}

# ---------- 진리표 ⑨ 은동전 예산 합계 (더블 20 / 소탕만 10 / 미사용 0) ----------
Assert-Case '예산: 빈 리스트' (Get-CustomCoinTotalPerLap -Items @()) '0'
$budgetItems = @(
  [pscustomobject]@{ coin = $true;  doubleLoot = $true },
  [pscustomobject]@{ coin = $true;  doubleLoot = $false },
  [pscustomobject]@{ coin = $false; doubleLoot = $false }
)
Assert-Case '예산: 20+10+0 혼합' (Get-CustomCoinTotalPerLap -Items $budgetItems) '30'
Assert-Case '예산: 단일 더블 항목(배열 풀림 확인)' (Get-CustomCoinTotalPerLap -Items @([pscustomobject]@{ coin = $true; doubleLoot = $true })) '20'
$budgetSame = @(
  [pscustomobject]@{ coin = $true; doubleLoot = $true },
  [pscustomobject]@{ coin = $true; doubleLoot = $true }
)
Assert-Case '예산: 같은 항목 중복 합산' (Get-CustomCoinTotalPerLap -Items $budgetSame) '40'

exit $fails
