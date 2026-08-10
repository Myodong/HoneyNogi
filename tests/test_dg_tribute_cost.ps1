# 입장 버튼 소모량 판독의 **엔진별 예비값 자격** 진리표 (2026-08-10 심층 실기로 확정).
#
# 실사고: 사용자가 마족공물 **미사용**으로 심층 커스텀 반복을 돌리는데 회차가 계속 정지했습니다.
#   [완료] 카드 설정을 확인하지 못했고 소모량 판독도 유효 밖 값('6')입니다 - 정지합니다
# 화면에는 소모량 표시가 **아예 없었고**(소탕 카드가 '도전'), 그런데도 6이 올라왔습니다.
#
# 실측 판독 (게임 창 1908x1076, 심층 옵션 화면, 소탕 미사용):
#   좁은 영역(978,636,152,44)  ko s3/s5 = ''        en s3/s5 = ''       → 숫자 없음 (정답)
#   넓은 영역(840,636,290,44)  ko s3/s5 = '입장하기'  en s3 = 'otn6Pl'   → 6
#                                                    en s5 = 'otm6Dl'   → 6
# 즉 **영어 엔진이 '입장하기' 글자를 오독해 없는 숫자 6을 만들어냅니다.** 한국어 엔진은
# 같은 화면을 정확히 읽고 숫자를 내지 않습니다.
#
# 원인 사슬: 유효값(던전 10/20, 심층 1/2)이 아니어도 '마지막 숫자 그룹'을 예비값으로
# 돌려주던 규칙 + 2026-08-09(9차)에 넣은 **영역 사다리**(좁은 영역이 비면 넓은 영역도 시도).
# 사다리 자체는 두 버튼 레이아웃 대비로 필요하므로, **영어 엔진 결과만 예비값 자격에서
# 뺐습니다.** 숫자가 실제로 있으면 영어 엔진도 유효값으로 잡혀 정상 채택됩니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$workerSource = [IO.File]::ReadAllText($workerPath)
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── ① 판독 시퀀스 → 최종 반환값 진리표 ─────────────────────────────────────
# 본체의 attempts 루프를 같은 규칙으로 재현합니다 (판독문 = 실측값).
function Get-CostFromReads {
  param($Reads, [int[]]$ValidCosts)
  $fallbackValue = $null
  foreach ($r in $Reads) {
    $groups = [regex]::Matches([string]$r.Text, '\d+')
    if ($groups.Count -eq 0) { continue }
    foreach ($grp in $groups) {
      $n = [int]$grp.Value
      if ($ValidCosts -contains $n) { return $n }
      # 공물 뿔 아이콘이 '7'로 붙는 이형 (2026-07-28 실기)
      if ($grp.Value -match '^7(\d+)$' -and $ValidCosts -contains [int]$Matches[1]) { return [int]$Matches[1] }
    }
    if ($r.AllowFallback -and $null -eq $fallbackValue) {
      $fallbackValue = [int]$groups[$groups.Count - 1].Value
    }
  }
  return $fallbackValue
}

# 실측 시퀀스 (좁은 영역 → 넓은 영역, 각 배율 ko→en)
$measuredNoCost = @(
  @{ Text = '';         AllowFallback = $true },   # 좁음 ko s3
  @{ Text = '';         AllowFallback = $false },  # 좁음 en s3
  @{ Text = '';         AllowFallback = $true },   # 좁음 ko s5
  @{ Text = '';         AllowFallback = $false },  # 좁음 en s5
  @{ Text = '입장하기'; AllowFallback = $true },   # 넓음 ko s3
  @{ Text = 'otn6Pl';   AllowFallback = $false },  # 넓음 en s3
  @{ Text = '입장하기'; AllowFallback = $true },   # 넓음 ko s5
  @{ Text = 'otm6Dl';   AllowFallback = $false }   # 넓음 en s5
)
Assert-Case '실측(심층 미사용): 소모량 없음으로 판정' `
  ($null -eq (Get-CostFromReads -Reads $measuredNoCost -ValidCosts @(1, 2))) $true

# 같은 판독문인데 영어도 예비 자격을 주면(수정 전) 가짜 6이 올라옵니다 - 회귀 재현
$brokenReads = @($measuredNoCost | ForEach-Object { @{ Text = $_.Text; AllowFallback = $true } })
Assert-Case '수정 전 재현: 영어 오독이 예비값으로 올라옴' `
  (Get-CostFromReads -Reads $brokenReads -ValidCosts @(1, 2)) 6

# 소탕을 켠 정상 화면: 좁은 영역 한국어가 바로 유효값을 읽습니다
Assert-Case '심층 소탕 켬: ko 가 1 을 읽으면 즉시 채택' `
  (Get-CostFromReads -Reads @(@{ Text = '1입장하기'; AllowFallback = $true }) -ValidCosts @(1, 2)) 1
Assert-Case '심층 매우 어려움: 2 도 유효' `
  (Get-CostFromReads -Reads @(@{ Text = '2입장하기'; AllowFallback = $true }) -ValidCosts @(1, 2)) 2
# 뿔 아이콘이 '7' 로 붙는 이형 (2026-07-28 23:40 실기 '71')
Assert-Case '이형: 71 → 1 로 교정' `
  (Get-CostFromReads -Reads @(@{ Text = '71입장하기'; AllowFallback = $true }) -ValidCosts @(1, 2)) 1
# 일반 던전 10/20 도 그대로
Assert-Case '던전: 10 채택' `
  (Get-CostFromReads -Reads @(@{ Text = '10입장하기'; AllowFallback = $true }) -ValidCosts @(10, 20)) 10
Assert-Case '던전: 20 채택' `
  (Get-CostFromReads -Reads @(@{ Text = '20입장하기'; AllowFallback = $true }) -ValidCosts @(10, 20)) 20
# 한국어가 숫자를 냈는데 유효값이 아니면 예비로 남습니다 (기존 계약 유지 - 진단 가치)
Assert-Case '한국어의 유효 밖 숫자는 예비로 유지(기존 계약)' `
  (Get-CostFromReads -Reads @(@{ Text = '3입장하기'; AllowFallback = $true }) -ValidCosts @(1, 2)) 3
# 영어만 유효값을 읽는 화면(한국어가 깨진 경우)은 여전히 구제됩니다
Assert-Case '영어만 유효값을 읽으면 채택(구제 경로 유지)' `
  (Get-CostFromReads -Reads @(
    @{ Text = ''; AllowFallback = $true },
    @{ Text = '10'; AllowFallback = $false }) -ValidCosts @(10, 20)) 10

# ── ② 배선 가드 ────────────────────────────────────────────────────────────
$costBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-DgTributeCost'))
$costCode = (($costBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: attempts 가 엔진별 예비 자격을 갖는다' `
  ([regex]::Matches($costCode, 'AllowFallback = \$(true|false)').Count) 4
Assert-Case '배선: 한국어 2회는 예비 허용' `
  ([regex]::Matches($costCode, 'Engine = \$ocrKoreanEngine; AllowFallback = \$true').Count) 2
Assert-Case '배선: 영어 2회는 예비 금지' `
  ([regex]::Matches($costCode, 'Engine = \$ocrEnglishEngine; AllowFallback = \$false').Count) 2
Assert-Case '배선: 예비값 기록이 그 자격을 확인한다' `
  ([bool]($costCode -match 'if \(\$attempt\.AllowFallback -and \$null -eq \$fallbackValue\)')) 'True'
# 영역 사다리(9차)는 유지돼야 합니다 - 두 버튼 레이아웃 대비
Assert-Case '배선: 영역 사다리는 그대로 유지' `
  ([bool]($costCode -match 'foreach \(\$costRegion in \$costRegions\)')) 'True'

exit $fails
