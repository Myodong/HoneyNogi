$ErrorActionPreference = 'Stop'

# 초기화 구간(아래 메인 try 이전: config 읽기, 형 변환, WinRT/OCR 준비 등)에서 예외가 나면
# 로그 없이 조용히 죽어 GUI에는 '오류 종료(코드 1)'만 뜹니다. 원인을 로그 파일에 남기고 끝냅니다.
# (메인 흐름의 예외는 아래쪽 try/catch가 먼저 잡아 진단까지 남기므로 이 trap에 오지 않습니다)
trap {
  try {
    # 메인 $logDir 해석(아래 '로그 폴더 통일' 주석) 전에 실행되는 trap 이라 같은 규칙을
    # 독립적으로 씁니다 - 어긋나면 초기화 오류가 옛 폴더에 남아 GUI 폴링이 못 봅니다 (리뷰)
    $bootLogBase = [string][Environment]::GetFolderPath('LocalApplicationData')
    $bootLogDir = $(if ([string]::IsNullOrWhiteSpace($bootLogBase)) { Join-Path $PSScriptRoot 'Log' }
      else { Join-Path $bootLogBase 'HoneyNogi\Log' })
    if (-not (Test-Path -LiteralPath $bootLogDir)) {
      New-Item -ItemType Directory -Path $bootLogDir -Force | Out-Null
    }
    Add-Content -LiteralPath (Join-Path $bootLogDir 'mabinogi_run_once.log') `
      -Value ("{0} [오류] 시작 준비 중 오류: {1}" -f (Get-Date -Format 'HH:mm:ss'), $_.Exception.Message) `
      -Encoding UTF8
  } catch { }
  exit 1
}

# ===== 설정 로드 =====
# 같은 폴더의 config.json 에서 좌표·타임아웃·OCR 영역 등을 읽습니다.
# config.json 이 없거나 항목이 빠지면 각 항목의 기본값(두 번째 인자)을 사용합니다.
$script:configValidationWarnings = @()
$script:configCoordinateWidth = 1272
$script:configCoordinateHeight = 717

function Add-ConfigValidationWarning {
  param([string]$Message)
  if ($script:configValidationWarnings -notcontains $Message) {
    $script:configValidationWarnings += $Message
  }
}

function Resolve-ConfigCoordinateArray {
  param($Value, $Default, [ValidateSet('point', 'region')][string]$Kind,
        [string]$Name, [int]$ReferenceWidth, [int]$ReferenceHeight)

  $expectedCount = $(if ($Kind -eq 'point') { 2 } else { 4 })
  $values = @($Value)
  $valid = ($values.Count -eq $expectedCount)
  $numbers = @()
  if ($valid) {
    foreach ($entry in $values) {
      $number = 0.0
      if ($entry -is [bool] -or $entry -is [string]) { $valid = $false; break }
      try { $number = [double]$entry } catch { $valid = $false; break }
      if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or
          $number -ne [Math]::Truncate($number)) { $valid = $false; break }
      # int 범위 검사 ([int] 변환 전 - 2026-08-01 전수 점검: 2147483648 같은 값은 정수성
      # 검사를 통과한 뒤 [int] 캐스트에서 예외가 터져 기본값 복구까지 못 갔음)
      if ($number -lt [int]::MinValue -or $number -gt [int]::MaxValue) { $valid = $false; break }
      $numbers += [int]$number
    }
  }
  if ($valid) {
    if ($Kind -eq 'point') {
      $valid = ($numbers[0] -ge 0 -and $numbers[0] -le $ReferenceWidth -and
        $numbers[1] -ge 0 -and $numbers[1] -le $ReferenceHeight)
    } else {
      $valid = ($numbers[0] -ge 0 -and $numbers[1] -ge 0 -and
        $numbers[2] -gt 0 -and $numbers[3] -gt 0 -and
        ($numbers[0] + $numbers[2]) -le $ReferenceWidth -and
        ($numbers[1] + $numbers[3]) -le $ReferenceHeight)
    }
  }
  if ($valid) { return $numbers }
  Add-ConfigValidationWarning "config '$Name' 값이 올바른 $Kind 형식/범위를 벗어나 내장 기본값을 사용합니다"
  return @($Default)
}

function Get-ConfigValue {
  param([object]$Root, [string[]]$Path, $Default)
  $node = $Root
  foreach ($key in $Path) {
    if ($null -eq $node) { return $Default }
    $prop = $node.PSObject.Properties[$key]
    if (-not $prop -or $null -eq $prop.Value) { return $Default }
    $node = $prop.Value
  }
  if ($null -eq $node) { return $Default }
  if ($Path.Count -ge 2 -and $Path[0] -eq 'clickPoints') {
    return (Resolve-ConfigCoordinateArray -Value $node -Default $Default -Kind point `
      -Name ($Path -join '.') -ReferenceWidth $script:configCoordinateWidth -ReferenceHeight $script:configCoordinateHeight)
  }
  if ($Path.Count -ge 2 -and $Path[0] -eq 'ocrRegions') {
    return (Resolve-ConfigCoordinateArray -Value $node -Default $Default -Kind region `
      -Name ($Path -join '.') -ReferenceWidth $script:configCoordinateWidth -ReferenceHeight $script:configCoordinateHeight)
  }
  return $node
}

function Resolve-ConfigInteger {
  param($Value, [int]$Default, [int]$Minimum, [int]$Maximum, [string]$Name)
  $valid = $null -ne $Value -and -not ($Value -is [bool] -or $Value -is [string])
  $number = 0.0
  if ($valid) {
    try { $number = [double]$Value } catch { $valid = $false }
  }
  if ($valid -and ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or
      $number -ne [Math]::Truncate($number))) { $valid = $false }
  # [int] 변환 전에 범위를 확인해야 Int32 바깥의 큰 값도 예외 없이 기본값으로 복구됩니다.
  if ($valid -and ($number -lt $Minimum -or $number -gt $Maximum)) { $valid = $false }
  if ($valid) { return [int]$number }
  Add-ConfigValidationWarning "config '$Name' 값이 정수 형식/허용 범위($Minimum~$Maximum)를 벗어나 기본값 $Default 을 사용합니다"
  return $Default
}

function Get-ConfigInteger {
  param([object]$Root, [string[]]$Path, [int]$Default, [int]$Minimum, [int]$Maximum)
  $raw = Get-ConfigValue -Root $Root -Path $Path -Default $Default
  return (Resolve-ConfigInteger -Value $raw -Default $Default -Minimum $Minimum -Maximum $Maximum `
    -Name ($Path -join '.'))
}

function Resolve-ConfigBoolean {
  param($Value, [bool]$Default, [string]$Name)
  if ($Value -is [bool]) { return [bool]$Value }
  Add-ConfigValidationWarning "config '$Name' 값이 true/false 형식이 아니라 기본값 $Default 을 사용합니다"
  return $Default
}

function Get-ConfigBoolean {
  param([object]$Root, [string[]]$Path, [bool]$Default)
  $raw = Get-ConfigValue -Root $Root -Path $Path -Default $Default
  return (Resolve-ConfigBoolean -Value $raw -Default $Default -Name ($Path -join '.'))
}

# ===== 커스텀 반복(리스트 방식) 판정 유틸 =====
# GUI가 환경변수(HONEYNOGI_CUSTOM_*)로 전달한 항목을 해석/판정하는 순수 함수들입니다.
# 화면/입력/설정에 의존하지 않는 순수 판정이며 tests\ 진리표가 AST로 본체 함수를 직접 실행합니다.

function ConvertFrom-CustomItemSpec {
  param([string]$Spec)

  # "어려움|1-3|1|1|0|1" (난이도|스테이지|은동전|더블 루팅|소진 시 진행|더블 불가 시 소탕만)
  # 형식을 해시테이블로 풉니다 (뒤 4조각은 1/0 - 소진 대응 2개는 항목별 속성, 계약 v2).
  # 조각 수가 6개가 아니거나 난이도/스테이지가 비어 있으면 $null (형식 오류).
  # 주의: [bool]'0' 은 PS에서 $true 라서 반드시 -eq '1' 문자열 비교로 변환합니다.
  # HONEYNOGI_CUSTOM_ITEM 과 HONEYNOGI_CUSTOM_PREV 둘 다 이 함수로 파싱합니다.
  if ([string]::IsNullOrWhiteSpace($Spec)) { return $null }
  $parts = $Spec -split '\|'
  if ($parts.Count -ne 6) { return $null }
  if ([string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) { return $null }
  return @{
    Difficulty      = [string]$parts[0]
    Stage           = [string]$parts[1]
    Coin            = ($parts[2] -eq '1')
    Double          = ($parts[3] -eq '1')
    ExhaustContinue = ($parts[4] -eq '1')   # 동전 소진 시: $true=미사용으로 진행 / $false=멈춤
    NoDoubleSweep   = ($parts[5] -eq '1')   # 더블 루팅 불가 시: $true=소탕만 진행 / $false=멈춤
  }
}

function ConvertFrom-AbyssCustomItemSpec {
  param([string]$Spec)

  # "A|party|어려움|허상의 정박지|우연한 만남"
  # (종류|입장 방식|난이도|어비스 던전|매칭) 형식. 혼자하기의 매칭은 '없음'.
  if ([string]::IsNullOrWhiteSpace($Spec)) { return $null }
  $parts = $Spec -split '\|'
  if ($parts.Count -ne 5 -or $parts[0] -ne 'A') { return $null }
  if ($parts[1] -ne 'solo' -and $parts[1] -ne 'party') { return $null }
  if ([string]::IsNullOrWhiteSpace($parts[2]) -or [string]::IsNullOrWhiteSpace($parts[3])) { return $null }
  # config 직접 편집이나 손상된 토큰으로 존재하지 않는 카드 좌표를 누르지 않게, GUI가 실제로
  # 제공하는 던전·난이도만 허용합니다. 새 어비스/난이도를 지원할 때 GUI 목록과 함께 갱신합니다.
  if ($parts[3] -notin @('허상의 정박지', '광기의 동굴', '흩어진 물길')) { return $null }
  $allowedDifficulties = @('게임 그대로', '입문', '어려움', '매우 어려움')
  if ($parts[1] -eq 'party') {
    $allowedDifficulties += @(1..10 | ForEach-Object { "지옥$_" })
  }
  if ($parts[2] -notin $allowedDifficulties) { return $null }
  $matching = [string]$parts[4]
  if ($parts[1] -eq 'solo') { $matching = '없음' }
  elseif ($matching -eq '파티 찾기') { $matching = '파티찾기' }
  if ($parts[1] -eq 'party' -and $matching -notin @('우연한 만남', '파티찾기', '파티(파티장)')) { return $null }
  return @{
    Kind       = 'abyss'
    Mode       = [string]$parts[1]
    Difficulty = [string]$parts[2]
    Dungeon    = [string]$parts[3]
    Matching   = $matching
  }
}

function Format-AbyssCustomItemLabel {
  param([hashtable]$Item)
  if (-not $Item) { return '(항목 없음)' }
  $modeText = $(if ($Item.Mode -eq 'party') { '함께하기' } else { '혼자하기' })
  $label = "$modeText $($Item.Difficulty) $($Item.Dungeon)"
  if ($Item.Mode -eq 'party') { $label += ", 매칭 '$($Item.Matching)'" }
  return $label
}

function Format-CustomItemLabel {
  param([hashtable]$Item)

  # 로그용 항목 표기: '어려움 1-3 (은동전·더블 루팅)' / '일반 2-1 (은동전)' / '일반 2-1'.
  # 회차 시작 로그와 조건부 정지(코드 4) 로그들이 공용으로 씁니다.
  # 심층 모드는 재화 표기만 마족공물로 바꿉니다 (더블 루팅 조합은 심층에 없음 - 리뷰 지적)
  if (-not $Item) { return '(항목 없음)' }
  $label = "$($Item.Difficulty) $($Item.Stage)"
  if ($Item.Coin -and $Item.Double) { return "$label (은동전·더블 루팅)" }
  if ($Item.Coin) { return "$label ($(if ($deepMode) { '마족공물' } else { '은동전' }))" }
  return $label
}

function Test-CustomSameAsPrev {
  param([hashtable]$Item, [hashtable]$Prev)

  # PREV 비교 판정: 직전 완료 항목과 난이도·스테이지가 모두 같으면 '다시 하기' 경로
  # (결과/옵션 화면을 그대로 이어감), 다르거나 PREV 가 없으면 선택 화면 경유 경로입니다.
  # 은동전/더블 루팅 차이는 옵션 화면에서 카드로 맞추므로 경로 판정에는 넣지 않습니다.
  if (-not $Item -or -not $Prev) { return $false }
  return (([string]$Item.Difficulty -eq [string]$Prev.Difficulty) -and
          ([string]$Item.Stage -eq [string]$Prev.Stage))
}

function Get-CustomStageFloor {
  param([string]$Stage)

  # 스테이지 표기('1-3')에서 층('1')을 뽑습니다. 'N-M' 형식이 아니면 $null 을 돌려주고,
  # 호출부(마무리 갈림길/시작 분기)는 판정 불가로 보고 안전측 경로를 탑니다.
  $parts = ([string]$Stage) -split '-'
  if ($parts.Count -lt 2) { return $null }
  if ([string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) { return $null }
  return [string]$parts[0]
}

function Get-CustomFinishAction {
  param([hashtable]$Item, [hashtable]$Next)

  # 회차 마무리 갈림길 판정 (계약 v4 - 2026-07-20 실기 검증 실측 반영):
  #  - 'retry'     : NEXT 없음/판정 불가, 또는 NEXT 가 같은 층 - 기존대로 '다시 하기'로 마침.
  #                  다시 하기로 돌아온 옵션 화면에서 같은 층의 구역(역방향 포함)과 난이도는
  #                  전부 바꿀 수 있어(실측) 층이 같으면 선택 화면 경유가 필요 없습니다.
  #  - 'next-floor': 현재 항목이 층 마지막 구역(X-3)이고 NEXT 가 바로 윗층 - 결과 화면의
  #                  '다음 층으로' 버튼으로 윗층 구역 선택 화면에 넘어가며 마침
  #                  (1-3 실측: '다음 층으로' → 2층 구역 선택 화면, 난이도 선택 가능).
  #  - 'retry-warn': 그 외 층 이동(2층→1층, 1-3 아닌 1층→2층) - 게임 UI로 불가능한 전환이라
  #                  GUI 리스트 검증이 사전 차단합니다. 방어적으로 다시 하기로 마치고 경고
  #                  로그만 남깁니다 (다음 워커의 시작 검증이 잡음).
  # ※ v3의 '나가기 → 선택 화면' 마무리는 폐기: 결과 화면 '나가기'는 필드로 나가버려
  #   자동 복귀가 불가능합니다 (2026-07-20 실측 - 절대 누르지 말 것).
  if (-not $Item -or -not $Next) { return 'retry' }
  $itemFloor = Get-CustomStageFloor -Stage ([string]$Item.Stage)
  $nextFloor = Get-CustomStageFloor -Stage ([string]$Next.Stage)
  if (($null -eq $itemFloor) -or ($null -eq $nextFloor)) { return 'retry' }
  if ($itemFloor -eq $nextFloor) { return 'retry' }
  $itemArea = [string]((([string]$Item.Stage) -split '-')[1])
  $itemFloorNum = 0
  $nextFloorNum = 0
  if (([int]::TryParse($itemFloor, [ref]$itemFloorNum)) -and ([int]::TryParse($nextFloor, [ref]$nextFloorNum)) -and
      ($nextFloorNum -eq ($itemFloorNum + 1)) -and ($itemArea -eq '3')) {
    return 'next-floor'
  }
  return 'retry-warn'
}

function Test-CustomTitleStageMatch {
  param([string]$TitleText, [string]$Stage)

  # 진입 옵션 화면 제목('N층 M구역')이 항목 스테이지('N-M')와 같은 구역인지 판정합니다.
  # 0-1 스테이지 검증과 같은 기준: '층' 글자는 OCR에서 통째로 소실될 수 있어
  # ('2층3구역'→'23구역' 실측) 숫자 사이 비숫자를 \D{0,2}로 허용하고,
  # 숫자가 명확히 읽힌 경우에만 match/mismatch 를 냅니다.
  # 반환: 'match' | 'mismatch' | 'unclear' (unclear = 숫자 미판독 - 호출부가 재판독)
  $stageParts = ([string]$Stage) -split '-'
  if ($stageParts.Count -lt 2) { return 'mismatch' }
  if (([string]$TitleText) -match "(\d)\D{0,2}(\d)구역") {
    if (($Matches[1] -eq $stageParts[0]) -and ($Matches[2] -eq $stageParts[1])) { return 'match' }
    return 'mismatch'
  }
  return 'unclear'
}

function Test-CustomTitleFloorMatch {
  param([string]$TitleText, [string]$Stage)

  # 진입 옵션 화면 제목의 '층' 숫자가 항목 스테이지('N-M')의 층과 같은지 판정합니다.
  # 파싱 기준은 Test-CustomTitleStageMatch 와 동일('층' 소실 대비 \D{0,2}, 숫자 명확할 때만).
  # 시작 분기 stay-select 판정용: 제목 구역 != 항목 구역이어도 층이 같으면 그 화면의
  # 구역 카드로 항목 구역을 선택할 수 있습니다 (2026-07-20 실측: 다시 하기로 온 옵션
  # 화면에서 같은 층 구역은 역방향 포함 선택 가능, 다른 층 구역은 선택 불가).
  # 반환: 'match' | 'mismatch' | 'unclear' (unclear = 숫자 미판독)
  $floor = Get-CustomStageFloor -Stage $Stage
  if ($null -eq $floor) { return 'mismatch' }
  if (([string]$TitleText) -match "(\d)\D{0,2}(\d)구역") {
    if ($Matches[1] -eq $floor) { return 'match' }
    return 'mismatch'
  }
  return 'unclear'
}

function Get-CustomOptionStartAction {
  param([bool]$TitleStageMatches, [bool]$SameAsPrev, [bool]$TitleFloorMatches)

  # 진입 옵션 화면에서 시작한 커스텀 회차의 경로 판정 (계약 v4 - 2026-07-20 실측 개정):
  #  - 'retry-path': PREV 와 난이도·구역 모두 같음 - 기존 다시 하기 경로 그대로
  #    (0-1 스테이지 검증이 2차 안전망)
  #  - 'stay-adjust': 화면 구역 == 항목 구역 (난이도만 다르거나 PREV 없음) - 선택 화면
  #    복귀 없이 그 자리에서 옵션 화면 난이도 알약을 눌러 맞추고 진행
  #    (다시 하기로 온 옵션 화면에는 '<'가 없어 복귀 시도는 항상 실패 - 2026-07-20 실측)
  #  - 'stay-select': 화면 구역 != 항목 구역이지만 같은 층 - 화면의 구역 카드를 눌러
  #    항목 구역으로 전환 후 진행 (실측: 같은 층 구역은 역방향 포함 선택 가능)
  #  - 'go-back': 다른 층(층 판정 불가 포함) - 좌상단 '<'로 선택 화면 복귀 시도
  #    (사용자가 선택 화면에서 직접 연 옵션 화면에만 '<' 존재)
  if ($SameAsPrev) { return 'retry-path' }
  if ($TitleStageMatches) { return 'stay-adjust' }
  if ($TitleFloorMatches) { return 'stay-select' }
  return 'go-back'
}

function Get-DgSelectionRecoveryAction {
  param([string]$EnterText, [string]$TargetStage)

  # 선택 화면의 하단 버튼 OCR로 현재 선택된 구역과 목표 구역의 관계를 판정합니다.
  # OCR 영역에 공물 숫자가 붙어 '11층3구역진입'처럼 읽혀도 마지막 '1층3구역'을 잡도록
  # 현재 게임 범위(한 자리 층/구역)에 맞춰 한 자리 숫자 패턴을 사용합니다.
  $targetParts = ([string]$TargetStage) -split '-'
  if ($targetParts.Count -ne 2 -or $targetParts[0] -notmatch '^\d$' -or $targetParts[1] -notmatch '^\d$') {
    return [pscustomobject]@{ Action = 'unclear'; CurrentFloor = ''; CurrentArea = ''; CurrentStage = '' }
  }
  $normalized = ([string]$EnterText) -replace '\s', ''
  $matches = [regex]::Matches($normalized, '(\d)\D{0,2}(\d)구역')
  if ($matches.Count -eq 0) {
    return [pscustomobject]@{ Action = 'unclear'; CurrentFloor = ''; CurrentArea = ''; CurrentStage = '' }
  }
  # 앞쪽 공물 숫자가 붙은 경우를 피하려고 가장 마지막 스테이지 모양을 사용합니다.
  $match = $matches[$matches.Count - 1]
  $currentFloor = [string]$match.Groups[1].Value
  $currentArea = [string]$match.Groups[2].Value
  $targetFloor = [string]$targetParts[0]
  $targetArea = [string]$targetParts[1]
  $action = if ($currentFloor -eq $targetFloor -and $currentArea -eq $targetArea) { 'selected' }
    elseif ($currentFloor -eq $targetFloor) { 'same-floor' }
    else { 'different-floor' }
  return [pscustomobject]@{
    Action       = $action
    CurrentFloor = $currentFloor
    CurrentArea  = $currentArea
    CurrentStage = "$currentFloor-$currentArea"
  }
}

function Test-CustomCleanupOnly {
  param([bool]$CustomMode, [bool]$Restart, [bool]$InsideAlready, [bool]$OnResultScreen)

  # 복구 분기 판정 (RESTART 여부 x 시작 화면): 사용자가 시작 버튼으로 새로 시작했는데
  # (자동 재시작 아님) 이미 던전 안/결과 화면이면 그 판은 수동 진행분이므로 완료로
  # 계상하지 않고 화면 정리만 합니다 (준비 실행, 코드 10 - 수동 판 오계상 방지).
  # 오류 후 자동 재시작(Restart=1)이면 복구 판을 현재 항목 완료로 계상합니다 (코드 0).
  return ($CustomMode -and (-not $Restart) -and ($InsideAlready -or $OnResultScreen))
}

function Get-CustomRecoveryReadyAction {
  param([bool]$RecoveryOnly, [bool]$OnOptionsScreen, [bool]$OnSelectionScreen,
        [string]$FinishAction)

  # 완료 항목의 마무리 복구를 시작했는데 결과 화면이 아니라 목표 화면이 이미 보이는 경우:
  #  - 같은 층 retry 계열은 옵션/선택 화면 모두 다음 항목이 안전하게 시작 가능
  #  - 1-3→2층 next-floor 는 2층 선택 화면만 완료로 인정 (1층 옵션이면 전환 미완료)
  if (-not $RecoveryOnly) { return 'continue' }
  if ($OnOptionsScreen -and $FinishAction -eq 'next-floor') { return 'blocked' }
  if ($OnOptionsScreen -or $OnSelectionScreen) { return 'complete' }
  return 'continue'
}

function Get-CustomCoinDecision {
  param([bool]$UseCoin, [bool]$DoubleLoot, $Balance, [bool]$ExhaustContinue, [bool]$NoDoubleSweep,
    [int]$SweepCost = 10, [int]$FullCost = 20, [string]$CurrencyName = '은동전',
    [string]$ExhaustLabel = '동전 소진 시')   # 사유 문구의 GUI 라디오 라벨 (심층 = '공물 소진 시')

  # 던전 공용 은동전 소진 대응 판정(기존 함수명은 테스트/호환을 위해 유지):
  #  - 은동전 미사용이면 검사 없이 진행
  #  - 잔량 판독 실패($null)는 '소진 확인'이 아니므로 검사를 생략하고 진행
  #    (최종 판정은 기존 입장 단계의 오류/정지 처리가 담당 - OCR 순단 오정지 방지)
  #  - 더블 루팅 항목 (잔량 범위별 판정):
  #    · 잔량 >= 20 → 코인+더블 그대로 진행
  #    · 잔량 10~19 → '더블 루팅 불가 시' 설정으로 멈춤/소탕만 진행
  #    · 잔량 < 10 → 더블 설정과 무관하게 '동전 소진 시' 설정으로 멈춤/미사용 진행
  #  - 더블 루팅 아닌 은동전 사용도 잔량 <10이면 같은 '동전 소진 시' 설정 적용
  # 반환: @{ Action = 'proceed'|'stop'; Coin = 적용할 소탕; Loot = 적용할 더블; Reason = 로그 문구 }
  $wantLoot = ($UseCoin -and $DoubleLoot)
  if (-not $UseCoin) {
    return @{ Action = 'proceed'; Coin = $false; Loot = $false; Reason = '' }
  }
  if ($null -eq $Balance) {
    return @{ Action = 'proceed'; Coin = $UseCoin; Loot = $wantLoot; Reason = '' }
  }
  $bal = [int]$Balance
  if ($wantLoot) {
    if ($bal -ge $FullCost) {
      return @{ Action = 'proceed'; Coin = $true; Loot = $true; Reason = '' }
    }
    if ($bal -ge $SweepCost) {
      if (-not $NoDoubleSweep) {
        return @{ Action = 'stop'; Coin = $true; Loot = $false
                  Reason = "${CurrencyName} 잔량 ${bal}개 (더블 루팅 포함 ${FullCost}개 필요) - '더블 루팅 불가 시' 설정(멈춤)에 따라 자동화를 정지합니다" }
      }
      return @{ Action = 'proceed'; Coin = $true; Loot = $false
                Reason = "${CurrencyName} 잔량 ${bal}개 (더블 루팅 포함 ${FullCost}개 필요) - '더블 루팅 불가 시' 설정(소탕만 진행)에 따라 더블 루팅만 끄고 진행합니다" }
    }
    if ($ExhaustContinue) {
      return @{ Action = 'proceed'; Coin = $false; Loot = $false
                Reason = "${CurrencyName} 잔량 ${bal}개 (소탕에 ${SweepCost}개 필요) - '${ExhaustLabel}' 설정(미사용으로 진행)에 따라 소탕을 해제하고 진행합니다" }
    }
    return @{ Action = 'stop'; Coin = $false; Loot = $false
              Reason = "${CurrencyName} 소진(잔량 ${bal}개, 필요 ${SweepCost}개) - '${ExhaustLabel}' 설정(멈춤)에 따라 자동화를 정지합니다" }
  }
  if ($bal -ge $SweepCost) {
    return @{ Action = 'proceed'; Coin = $true; Loot = $false; Reason = '' }
  }
  if ($ExhaustContinue) {
    return @{ Action = 'proceed'; Coin = $false; Loot = $false
              Reason = "${CurrencyName} 잔량 ${bal}개 (소탕에 ${SweepCost}개 필요) - '${ExhaustLabel}' 설정(미사용으로 진행)에 따라 소탕을 해제하고 진행합니다" }
  }
  return @{ Action = 'stop'; Coin = $false; Loot = $false
            Reason = "${CurrencyName} 소진(잔량 ${bal}개, 필요 ${SweepCost}개) - '${ExhaustLabel}' 설정(멈춤)에 따라 자동화를 정지합니다" }
}

$config = $null
$configPath = Join-Path $PSScriptRoot 'config.json'
if (Test-Path -LiteralPath $configPath) {
  try {
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    Write-Host "config.json 을 읽지 못해 기본값으로 진행합니다: $($_.Exception.Message)" -ForegroundColor Yellow
    $config = $null
  }
}

# ===== 좌표 버전 게이트 =====
# exe 는 config.json 을 '처음 한 번만' 풀기 때문에, 게임 UI 개편으로 좌표가 바뀌어도
# 옛 config 의 좌표가 내장 최신 기본값을 계속 덮어쓰는 사고가 납니다
# (실측 2026-07-17: 다른 PC의 옛 config 가 개편 전 abyssMenu(1028,510)를 갖고 있어
#  길드 부근을 16회 헛클릭). config 의 coordsVersion 이 아래 값보다 낮으면
# 좌표 섹션(ocrRegions/clickPoints)을 무시하고 스크립트 내장 최신 좌표를 사용합니다.
# ※ 좌표를 직접 수정해 쓰려면 config 에 "coordsVersion": <아래 값> 을 함께 적어 주세요.
# ※ 개발 규칙: 이 파일의 좌표 기본값(ocrRegions/clickPoints 계열)을 하나라도 바꾸면
#    아래 버전과 config.json 의 coordsVersion 을 반드시 함께 +1 하세요.
#    (안 올리면 옛 config 의 좌표가 게이트를 통과해 이번 사고가 재발합니다.
#     두 값이 어긋나면 빌드 스크립트가 실패하도록 검사합니다)
$coordsVersionCurrent = 7
$script:staleCoordsIgnored = $false
$configCoordsVersion = Get-ConfigInteger $config @('coordsVersion') 0 0 100000
if ($config -and $configCoordsVersion -lt $coordsVersionCurrent) {
  if ($config.PSObject.Properties['ocrRegions'] -or $config.PSObject.Properties['clickPoints']) {
    $config.PSObject.Properties.Remove('ocrRegions')
    $config.PSObject.Properties.Remove('clickPoints')
    $script:staleCoordsIgnored = $true
  }
}

$referenceWidth  = Get-ConfigInteger $config @('referenceResolution', 'width') 1272 640 7680
$referenceHeight = Get-ConfigInteger $config @('referenceResolution', 'height') 717 360 4320
# 기준 좌표계는 1272x717 고정입니다 (2026-08-01 전수 점검: 스크립트에 하드코딩된 좌표·영역
# 전부가 이 기준이라, referenceResolution 만 바꾸면 config 좌표와 하드코딩 좌표의 환산이
# 어긋나 전체 클릭이 빗나감 - 다른 값은 경고 후 기본값으로 강제. 이 키는 config 편집으로만
# 바뀔 수 있고 GUI 는 노출하지 않음)
if ($referenceWidth -ne 1272 -or $referenceHeight -ne 717) {
  Add-ConfigValidationWarning "config 'referenceResolution' ${referenceWidth}x${referenceHeight} 은 지원하지 않아 기준 1272x717 을 사용합니다 (하드코딩 좌표와의 정합)"
  $referenceWidth = 1272
  $referenceHeight = 717
}
$script:configCoordinateWidth = $referenceWidth
$script:configCoordinateHeight = $referenceHeight

$timeoutDetail      = Get-ConfigInteger $config @('timeoutsSeconds', 'detailScreen') 15 1 600
$timeoutEntry       = Get-ConfigInteger $config @('timeoutsSeconds', 'dungeonEntry') 45 1 3600
$timeoutClear       = Get-ConfigInteger $config @('timeoutsSeconds', 'dungeonClear') 600 30 86400
$timeoutExit        = Get-ConfigInteger $config @('timeoutsSeconds', 'exitButton') 20 1 600
$timeoutHud         = Get-ConfigInteger $config @('timeoutsSeconds', 'homeEndEscHud') 30 1 600
$timeoutAbyssMenu   = Get-ConfigInteger $config @('timeoutsSeconds', 'abyssMenu') 15 1 600
$timeoutAbyssSelect = Get-ConfigInteger $config @('timeoutsSeconds', 'abyssSelectionScreen') 15 1 600
$contentCategory = [string](Get-ConfigValue $config @('contentCategory') 'abyss')
# 심층던전 모드: 던전과 화면 구조·좌표가 동일해 던전 사이클을 공유하고, 차이(재화·라벨·
# 난이도·제목 조각)만 데이터로 치환합니다 (2026-07-27 설계 합의 - 아래 심층 데이터 구역 참고)
$deepMode = ($contentCategory -eq 'deepdungeon')
# 대분류(전투/생활) - v2.0.0. 'life' 면 전투 콘텐츠 대신 생활(채집) 사이클로 분기합니다
# (contentCategory 는 전투 하위 선택이라 그대로 보존 - 설계 합의)
$mainCategory = [string](Get-ConfigValue $config @('mainCategory') 'battle')
$lifeContent = [string](Get-ConfigValue $config @('life', 'content') 'gather')
$lifeSkillId = [string](Get-ConfigValue $config @('life', 'skill') 'daily')
$lifeTargetName = [string](Get-ConfigValue $config @('life', 'target') '둥지')
# 생활 커스텀 반복 (2026-08-08): GUI 가 회차마다 이번에 돌 항목 하나만 환경변수로 넘깁니다
# (config 는 불변 - 던전/어비스/심층과 같은 방식). 토큰 형식 'L|<스킬Id>|<대상>|<횟수>'.
# 여기서 슬라이더 선택(config life.skill/target)을 덮어써 이후 채집 흐름 전체가 이 항목으로
# 동작합니다. 횟수는 GUI 가 진행 기록으로 세므로 워커는 사이클 1회만 수행합니다.
$script:lifeCustomMode = $false
$script:lifeCustomSpecInvalid = $false
if ($mainCategory -eq 'life' -and -not [string]::IsNullOrWhiteSpace($env:HONEYNOGI_CUSTOM_ITEM)) {
  $lifeCustomParts = ([string]$env:HONEYNOGI_CUSTOM_ITEM) -split '\|'
  if ($lifeCustomParts.Count -ge 3 -and [string]$lifeCustomParts[0] -eq 'L' -and
      -not [string]::IsNullOrWhiteSpace($lifeCustomParts[1]) -and
      -not [string]::IsNullOrWhiteSpace($lifeCustomParts[2])) {
    $lifeSkillId = [string]$lifeCustomParts[1]
    $lifeTargetName = [string]$lifeCustomParts[2]
    $lifeContent = 'gather'   # 커스텀 리스트는 채집 전용 (가공은 리스트 자체가 없음)
    $script:lifeCustomMode = $true
  } else {
    # 형식이 어긋나면 조용히 config 값으로 진행하지 않습니다 - 엉뚱한 대상을 캐면
    # 남의 채집을 망칠 수 있어 로그 경로 준비 후 명확한 오류로 끝냅니다
    $script:lifeCustomSpecInvalid = $true
  }
}
# '채집 대기' = 총 시간이 아니라 **진행이 멈춘 채로 견디는 시간** (2026-08-08 설계 변경).
# 수량이 오르는 동안은 오래 걸려도 자르지 않습니다 - 자세한 근거는 대기 루프 주석 참고.
$lifeGatherWait = Get-ConfigInteger $config @('life', 'gatherWaitSeconds') 600 60 3600
# 절대 상한(하드 백스톱). 무인 운용에서 영원히 매달리지 않기 위한 안전장치일 뿐이라 넉넉히
# 잡습니다 - 실측 최장 사이클이 521초였으므로 정상 채집은 절대 여기 닿지 않습니다.
$lifeGatherHardCapSeconds = 3600

$ptAbyssCard   = @(Get-ConfigValue $config @('clickPoints', 'abyssCard') @(956, 157))

# 선택된 던전 프로파일: config.dungeons.selected 로 대상 던전이 정해지고,
# 카드 클릭 좌표와 로그 문구가 그 던전 기준으로 바뀝니다. (UI에서 선택 시 자동 기록)
$selectedDungeon = [string](Get-ConfigValue $config @('dungeons', 'selected') '허상의 정박지')
if ([string]::IsNullOrWhiteSpace($selectedDungeon)) { $selectedDungeon = '허상의 정박지' }
# 어비스 커스텀 항목은 프로파일 좌표를 고르기 전에 먼저 파싱해야 해당 던전의 카드/제목
# 키워드가 정확히 준비됩니다. 형식 오류는 로그 경로가 준비된 뒤 명확한 오류로 종료합니다.
$script:abyssCustomPreparsed = $null
if ($contentCategory -eq 'abyss' -and -not [string]::IsNullOrWhiteSpace($env:HONEYNOGI_CUSTOM_ITEM)) {
  $script:abyssCustomPreparsed = ConvertFrom-AbyssCustomItemSpec -Spec ([string]$env:HONEYNOGI_CUSTOM_ITEM)
  if ($script:abyssCustomPreparsed) { $selectedDungeon = [string]$script:abyssCustomPreparsed.Dungeon }
}
# 내장 최신 어비스 카드 좌표 (config.json profiles 와 동일 값 유지).
# 좌표 버전 게이트가 발동하면 구버전 profiles.<던전>.card 대신 이 값을 씁니다.
$builtinDungeonCards = @{
  '허상의 정박지' = @(956, 157)
  '광기의 동굴'   = @(956, 272)
  '흩어진 물길'   = @(956, 387)
}
$dungeonCard = $ptAbyssCard
$dungeonStage = 'full'   # full = 전체 자동화 / detail = 상세 화면 진입까지만(이후 미개발)
$dungeonMatch = $selectedDungeon.Substring(0, [Math]::Min(2, $selectedDungeon.Length))  # 제목 확인용 키워드(기본: 이름 앞 2글자)
$dungeonProfiles = Get-ConfigValue $config @('dungeons', 'profiles') $null
if ($dungeonProfiles) {
  $selectedProfile = $dungeonProfiles.PSObject.Properties[$selectedDungeon]
  if ($selectedProfile) {
    if ($selectedProfile.Value.PSObject.Properties['card']) {
      $dungeonCard = @(Resolve-ConfigCoordinateArray -Value $selectedProfile.Value.card -Default $ptAbyssCard `
        -Kind point -Name "dungeons.profiles.$selectedDungeon.card" `
        -ReferenceWidth $referenceWidth -ReferenceHeight $referenceHeight)
    }
    if ($selectedProfile.Value.PSObject.Properties['stage'] -and $selectedProfile.Value.stage) {
      $dungeonStage = [string]$selectedProfile.Value.stage
    }
    if ($selectedProfile.Value.PSObject.Properties['match'] -and $selectedProfile.Value.match) {
      $dungeonMatch = [string]$selectedProfile.Value.match
    }
  }
}
# 좌표 버전 게이트 보강 (2026-07-19 개선점): ocrRegions/clickPoints 는 위에서 통째로
# 무시되지만 어비스 카드 좌표는 dungeons.profiles.<던전>.card 에도 있어 게이트를
# 빠져나갔음. 게이트 발동 시 카드 좌표만 내장 최신값으로 대체하고, 사용자 선택값
# (selected/stage/match)은 좌표가 아니므로 그대로 유지합니다.
# (내장 목록에 없는 미래 던전이면 대체할 값이 없어 profiles 값을 그대로 씀 - 한계 명시)
if ($script:staleCoordsIgnored -and $builtinDungeonCards.ContainsKey($selectedDungeon)) {
  $dungeonCard = @($builtinDungeonCards[$selectedDungeon])
}

# 모든 던전의 제목 키워드 목록: "지금 화면이 (어느 던전이든) 상세 화면인가"를 판단할 때 사용
$allDungeonKeywords = @('정박', '광기', '물길')
if ($dungeonProfiles) {
  $keywordList = @()
  foreach ($profileProp in $dungeonProfiles.PSObject.Properties) {
    if ($profileProp.Value.PSObject.Properties['match'] -and $profileProp.Value.match) {
      $keywordList += [string]$profileProp.Value.match
    }
  }
  if ($keywordList.Count -gt 0) { $allDungeonKeywords = $keywordList }
}
$ptEnter       = @(Get-ConfigValue $config @('clickPoints', 'enter') @(981, 654))
$ptClearCenter = @(Get-ConfigValue $config @('clickPoints', 'clearScreenCenter') @(636, 358))
$ptExitButton  = @(Get-ConfigValue $config @('clickPoints', 'exitButton') @(636, 655))
$ptEscButton   = @(Get-ConfigValue $config @('clickPoints', 'escButton') @(1083, 89))
$ptAbyssMenu   = @(Get-ConfigValue $config @('clickPoints', 'abyssMenu') @(971, 387))   # 2026-07-16 UI 개편: 아이콘 그리드 메뉴의 '어비스' 타일 (OCR 실측)

$rgClearExit   = @(Get-ConfigValue $config @('ocrRegions', 'clearAndExitText') @(430, 570, 420, 125))
# 클리어 화면 좌측 점수표(빠른 처치/완벽한 전투/재도전·협동 보너스 등) - 하단 문구의 보조 신호.
# 하단 문구는 캐릭터가 겹쳐 깨지기 일쑤지만 점수표는 겹치지 않는 위치라 안정적 (2026-07-19 실측:
# 클리어 캡처 2장 모두 라벨 판독, 결과/옵션/전투 화면에선 미검출)
$rgClearScore  = @(185, 300, 230, 165)
$rgEnterButton = @(Get-ConfigValue $config @('ocrRegions', 'enterButton') @(880, 630, 200, 48))
$rgHomeEndEsc  = @(Get-ConfigValue $config @('ocrRegions', 'homeEndEsc') @(875, 60, 265, 55))
# ESC 메뉴의 **타일 그리드 전체**를 봅니다 (2026-08-08 coordsVersion 7).
# 예전에는 '필드 보스/어비스/망령의 탑/레이드' 한 줄만 보는 좁은 영역(850,330,350,85)이라,
# 상단에 광고 배너('NEXON ESSENTIAL', y33~175)가 생겨 그리드가 아래로 밀리자 그 영역이
# '캐릭터/가방/크래프팅/연금술' 줄을 읽었습니다 - 어비스 줄을 통째로 놓친 것.
# 배너 높이는 광고마다 다를 수 있으므로 줄이 아니라 그리드 전체를 보고 글자로 찾습니다.
# 실측 근거: **광고 없을 때 어비스 y387**(2026-07-16, 옛 ptAbyssMenu 값) /
# **광고 있을 때 y531**(2026-08-08) - 두 경우 모두 이 영역(y180~700) 안입니다.
# 위쪽을 배너 아래(180)에서 시작하는 것은 **의도한 것**입니다: 배너까지 포함하면
# '어비스 신규 던전 오픈' 같은 광고 문구를 어비스 항목으로 잘못 잡아 광고를 누릅니다.
$rgAbyssMenu   = @(Get-ConfigValue $config @('ocrRegions', 'abyssMenu') @(850, 180, 350, 520))
$rgAbyssCards  = @(Get-ConfigValue $config @('ocrRegions', 'abyssCards') @(690, 110, 280, 310)) # 어비스 선택 화면 우측 던전 배너 3장의 제목 영역 (2026-07-16 개편 화면 실측)
$rgMenuExitLabel = @(Get-ConfigValue $config @('ocrRegions', 'menuExitLabel') @(1160, 600, 112, 90)) # ESC 메뉴 우하단 '게임 종료' 문구 (메뉴 열림 2차 신호, 두 창 크기 실측)
$rgNoticeTabs    = @(170, 495, 930, 62)   # 공지 게시판 팝업 하단 탭 줄(공지사항/이벤트/쿠폰 입력/FAQ) - 2026-07-19 타 PC 캡처 실측
$ptNoticeClose   = @(1092, 135)           # 공지 게시판 팝업 우상단 X - 같은 캡처 실측 (공용 X 후보 1090,137과 동일 계열)
$rgAbyssSelect = @(Get-ConfigValue $config @('ocrRegions', 'abyssSelectionTitle') @(0, 25, 240, 95))
$rgDetailTitle = @(Get-ConfigValue $config @('ocrRegions', 'detailTitle') @(30, 100, 350, 65))
$ptDetailBack  = @(Get-ConfigValue $config @('clickPoints', 'detailBack') @(43, 67))
$ptSoloTab     = @(Get-ConfigValue $config @('clickPoints', 'soloTab') @(533, 76))
$ptPartyTab    = @(Get-ConfigValue $config @('clickPoints', 'partyTab') @(760, 76))

# 함께하기 화면 전용 (2026-07-16 실측): 하단 버튼이 토글 상태에 따라 달라집니다 -
# 우연한 만남 꺼짐 = '파티원 모집'+'입장하기' 2버튼 / 켜짐 = 넓은 단일 '입장하기'.
# 클릭 지점과 글자 영역은 두 레이아웃을 모두 커버하도록 잡았습니다 (실측 검증).
$ptPartyEnter        = @(Get-ConfigValue $config @('clickPoints', 'partyEnter') @(1077, 655))       # 함께하기 '입장하기' 버튼 (두 레이아웃 모두 버튼 안)
$ptPartyFind         = @(Get-ConfigValue $config @('clickPoints', 'partyFind') @(836, 655))          # 함께하기 '파티 찾기' 버튼 (토글 꺼짐 레이아웃 전용, 실측)
$ptAbyssChanceToggle = @(Get-ConfigValue $config @('clickPoints', 'abyssChanceToggle') @(1208, 339)) # '우연한 만남' 토글 (켜짐 초록 13,179,118 실측)
$rgPartyEnterBtn     = @(Get-ConfigValue $config @('ocrRegions', 'partyEnterButton') @(900, 630, 260, 48)) # 함께하기 '입장하기' 글자 영역 (두 레이아웃 커버)

# 입장 방식: solo = 혼자하기 / party = 함께하기 (우연한 만남 매칭 자동화 지원)
$dungeonMode = [string](Get-ConfigValue $config @('dungeons', 'mode') 'solo')
if ($dungeonMode -ne 'party') { $dungeonMode = 'solo' }
# 함께하기 매칭 방식: '우연한 만남'(토글 켜고 입장 - 모이면 자동 입장) / '파티찾기'(토글 끄고
# 파티 찾기 클릭) / '파티(파티장)'(직접 짠 파티로 입장하기 클릭 주도 - 전원 준비되면 자동 입장,
# 인원이 부족해도 채우지 않고 도전 확인 팝업을 Space 로 확인) / '파티(파티원)'(필드 대기 →
# 파티장이 입장 시작하면 '준비 완료' 클릭 → 따라 입장, 전용 사이클)
$abyssMatching = [string](Get-ConfigValue $config @('dungeons', 'matching') '우연한 만남')
# 과도기 config 호환: 잠시 파티 상태가 dungeons.partyState 로 분리 저장된 버전이 있었습니다
$legacyPartyState = [string](Get-ConfigValue $config @('dungeons', 'partyState') '')
if ($legacyPartyState -eq '파티(파티장)' -or $legacyPartyState -eq '파티(파티원)') { $abyssMatching = $legacyPartyState }
if ($abyssMatching -eq '파티원') { $abyssMatching = '파티(파티장)' }

# 난이도: 입장 전 상세 화면에서 클릭할 난이도 이름 (예: '입문', '어려움', '매우 어려움').
# 빈 값이면 난이도를 건드리지 않고 게임에 선택돼 있는 그대로 입장합니다.
$dungeonDifficulty = [string](Get-ConfigValue $config @('dungeons', 'difficulty') '')
if ($script:abyssCustomPreparsed) {
  $dungeonMode = [string]$script:abyssCustomPreparsed.Mode
  $abyssMatching = [string]$script:abyssCustomPreparsed.Matching
  $dungeonDifficulty = $(if ([string]$script:abyssCustomPreparsed.Difficulty -eq '게임 그대로') {
      ''
    } else { [string]$script:abyssCustomPreparsed.Difficulty })
}
# 상세 화면에서 난이도 버튼들(입문/어려움/매우 어려움...)이 표시되는 좌상단 영역.
# 난이도가 추가되어 버튼 위치가 바뀌어도 되도록, 이 영역에서 글자를 OCR로 찾아 클릭합니다.
$rgDifficultyTabs  = @(Get-ConfigValue $config @('ocrRegions', 'difficultyTabs') @(30, 150, 500, 60))

# 아침 6시 리셋 후 뜨는 출석/이벤트 화면 처리용 영역 (2026-07-15 실측):
#  - eventSkip: 출석부 우상단 '출석부 건너뛰기' 버튼 영역
#  - eventConfirm: '출석 완료' 보상 요약 하단 '확인' 버튼 영역
$rgEventSkip    = @(Get-ConfigValue $config @('ocrRegions', 'eventSkip') @(1110, 45, 155, 45))
$rgEventConfirm = @(Get-ConfigValue $config @('ocrRegions', 'eventConfirm') @(480, 625, 320, 55))
# '출석 완료 / 우편으로 지원품이 지급되었습니다' 보상 요약 화면 - 하단 초록 버튼이
# 마우스 클릭 대신 Space 확인이라, 이 문구('지원')가 보이면 Space로 넘깁니다 (2026-07-17 실측)
$rgEventReward  = @(Get-ConfigValue $config @('ocrRegions', 'eventReward') @(480, 190, 320, 100))
# 아침 6시 알리사 NPC 대화(출석 전 도입 장면)의 말풍선 영역: 글자가 보이면 대화 진행 중으로
# 판단하고 중앙 클릭으로 넘깁니다 (실측 2026-07-17: '있잖아, 부꼼~ 그거 봤어?' 정상 인식)
$rgNpcDialogue  = @(Get-ConfigValue $config @('ocrRegions', 'npcDialogue') @(450, 115, 380, 80))
# '오늘의 스텔라 픽' 데일리 팝업 (2026-07-16 실측): 좌상단 제목으로 감지하고,
# 카드 3장 중 가운데를 골라 진행. 두 번 골라도 남아 있으면 우상단 닫기(X)로 닫음
$rgStellaTitle  = @(Get-ConfigValue $config @('ocrRegions', 'stellaTitle') @(50, 45, 230, 45))
# 2단계(확정 화면): 카드 캐러셀 + 하단 초록 '스텔라 픽' 버튼 (2026-07-17 실측: 중심 968,654)
$rgStellaPickBtn = @(Get-ConfigValue $config @('ocrRegions', 'stellaPickButton') @(740, 632, 450, 50))
# 공지 팝업의 '오늘 그만 보기'(팝업 좌하단)와 이벤트 팝업의 '닫기' 버튼 영역 (2026-07-17 실측)
# 팝업 높이가 공지 내용에 따라 달라질 수 있어 세로로 넉넉히 잡습니다
$rgEventTodayOff = @(Get-ConfigValue $config @('ocrRegions', 'eventTodayOff') @(250, 430, 520, 120))
$rgEventCloseBtn = @(Get-ConfigValue $config @('ocrRegions', 'eventCloseButton') @(100, 600, 550, 80))
# 웹뷰형 공지 보드(공지사항/이벤트/쿠폰 입력/FAQ 탭): 탭 글자로 감지하고 전용 X 로 닫음 (2026-07-17 실측)
$rgNoticeBoardTabs  = @(Get-ConfigValue $config @('ocrRegions', 'noticeBoardTabs') @(600, 500, 480, 55))
$ptNoticeBoardClose = @(Get-ConfigValue $config @('clickPoints', 'noticeBoardClose') @(1090, 137))
$ptStellaCard   = @(Get-ConfigValue $config @('clickPoints', 'stellaCard') @(640, 420))
$ptStellaClose  = @(Get-ConfigValue $config @('clickPoints', 'stellaClose') @(1229, 67))   # 전체 화면 UI 공용 닫기(X) 위치 (스텔라 픽/인벤토리 실측 동일)
# 우측 퀘스트 추적기 첫 줄 영역: 던전 안에서는 '<던전 이름> 클리어' 목표가 고정 표시되므로
# 이 글자로 '던전 안'과 '필드(던전 밖)'를 구분합니다 (HUD는 양쪽 다 보여서 구분 불가).
$rgQuestTracker = @(Get-ConfigValue $config @('ocrRegions', 'questTracker') @(980, 212, 285, 55))

# 캐릭터가 던전에서 먼 곳에 있어 상세 화면에 '이동하기'가 뜬 경우, 자동 이동으로
# 던전에 도착(상세 화면이 다시 열리며 '입장하기' 표시)할 때까지 기다리는 최대 시간(초)
$timeoutTravel = Get-ConfigInteger $config @('timeoutsSeconds', 'travelToDungeon') 180 1 3600
# 던전 '파티 찾기' 매칭이 완료되어 던전에 입장할 때까지 기다리는 최대 시간(초)
$timeoutPartyMatch = Get-ConfigInteger $config @('timeoutsSeconds', 'partyMatching') 300 1 3600

# 보스방 진입 컷신의 '장면 넘기기' 버튼 탐색 영역: 정확한 버튼 위치가 화면마다 다를 수
# 있어 상단/하단 오른쪽 절반을 넓게 잡고, '넘기' 글자를 OCR로 찾아 그 위치를 클릭합니다.
$rgCutsceneTop    = @(Get-ConfigValue $config @('ocrRegions', 'cutsceneSkipTop') @(636, 40, 630, 70))
$rgCutsceneBottom = @(Get-ConfigValue $config @('ocrRegions', 'cutsceneSkipBottom') @(636, 590, 630, 110))

# 구매 제안 팝업(회복 물약 부족 등)의 '닫기' 버튼 탐색 영역: 팝업이 뜨면 화면 중앙을
# 덮어 모든 감지가 가려지므로, 이 영역에서 '닫기' 글자를 찾아 클릭해 닫습니다 (실측 검증됨).
$rgPopupClose = @(Get-ConfigValue $config @('ocrRegions', 'popupClose') @(380, 590, 320, 60))

# ===== '던전' 카테고리 설정 (전체 자동화 구현: 선택 → 옵션 → 입장 → 클리어 → 다시 하기 반복) =====
$ndDifficulty    = [string](Get-ConfigValue $config @('normalDungeon', 'difficulty') '일반')
$ndStage         = [string](Get-ConfigValue $config @('normalDungeon', 'stage') '1-1')
$ndUseCoin       = Get-ConfigBoolean $config @('normalDungeon', 'useSilverCoin') $false
$ndDoubleLoot    = Get-ConfigBoolean $config @('normalDungeon', 'doubleLoot') $false
$ndCoinFallback  = Get-ConfigBoolean $config @('normalDungeon', 'continueWithoutCoin') $false
$ndLootFallback  = Get-ConfigBoolean $config @('normalDungeon', 'continueSweepOnly') $false
$ndMatching      = [string](Get-ConfigValue $config @('normalDungeon', 'matching') '우연한 만남')

# ===== '심층던전' 카테고리 설정 (던전 사이클 공유 - $nd* 를 심층 값으로 덮어씀) =====
# 재화 = 마족공물(소탕 카드가 어려움 1개/매우 어려움 2개 소모, 해제 시 무료 입장 - 사용자
# 실측 확정). 더블 루팅 없음. 난이도는 어려움 고정 + '주간 매우 어려움'(단일 구역) 선택형.
if ($deepMode) {
  $ndDifficulty   = [string](Get-ConfigValue $config @('deepDungeon', 'difficulty') '어려움')
  $ndStage        = [string](Get-ConfigValue $config @('deepDungeon', 'stage') '1-1')
  $ndUseCoin      = Get-ConfigBoolean $config @('deepDungeon', 'useTribute') $false
  $ndDoubleLoot   = $false
  $ndCoinFallback = Get-ConfigBoolean $config @('deepDungeon', 'continueWithoutTribute') $false
  $ndLootFallback = $false
  $ndMatching     = [string](Get-ConfigValue $config @('deepDungeon', 'matching') '우연한 만남')
}

# ===== 커스텀 반복 모드 (GUI가 환경변수로 이번 회차 항목을 전달) =====
# 던전은 기존 6조각 토큰으로 $nd* 설정을 덮어쓰고, 어비스는 A 접두 5조각 토큰으로
# 선택 던전/입장 방식/난이도/매칭을 덮어씁니다. 완료 마커·진행 위치·재시작 환경변수는 공용입니다.
# ※ 이 블록은 $logPath 정의 이전이라 여기서는 로그를 남기지 않습니다.
$script:customMode = $false
$script:customSpecInvalid = $false
$script:customItem = $null
$script:customPrev = $null
$script:customNext = $null
$script:customRestart = $false
$script:customRecoveryOnly = $false
$script:customSameAsPrev = $false
$script:customCleanupOnly = $false
$script:customPositionText = ''
$script:customListText = ''
$script:customMarkerPath = ''
$script:customOwnerJson = ''
if (-not [string]::IsNullOrWhiteSpace($env:HONEYNOGI_CUSTOM_ITEM)) {
  if ($contentCategory -eq 'dungeon' -or $deepMode) {
    # 심층 커스텀은 던전 6조각 토큰을 그대로 재사용합니다 (난이도 '어려움' 고정,
    # Coin=마족공물 소탕, Double=항상 false - 아래 심층 강제 규칙 참고. 설계 합의)
    $script:customItem = ConvertFrom-CustomItemSpec -Spec ([string]$env:HONEYNOGI_CUSTOM_ITEM)
    if ($null -eq $script:customItem) {
      $script:customSpecInvalid = $true
    } else {
      $script:customMode = $true
      $script:customPrev = ConvertFrom-CustomItemSpec -Spec ([string]$env:HONEYNOGI_CUSTOM_PREV)
      # 다음 항목(리스트 순환 - 1항목 리스트면 자기 자신): 회차 마무리에서 '다시 하기' vs
      # '다음 층으로' 갈림길 판정에 씁니다 (Get-CustomFinishAction, 계약 v4 - 나가기 폐기).
      # 파싱 실패(빈 값/형식 오류)면 $null → 마무리는 기존 다시 하기 경로 그대로.
      $script:customNext = ConvertFrom-CustomItemSpec -Spec ([string]$env:HONEYNOGI_CUSTOM_NEXT)
      $script:customSameAsPrev = Test-CustomSameAsPrev -Item $script:customItem -Prev $script:customPrev
      # normalDungeon 설정 오버라이드: 이후 던전 흐름의 모든 $nd* 사용처가 항목 기준으로 동작
      $ndDifficulty   = [string]$script:customItem.Difficulty
      $ndStage        = [string]$script:customItem.Stage
      $ndUseCoin      = [bool]$script:customItem.Coin
      $ndDoubleLoot   = [bool]$script:customItem.Double
      # 소진 대응도 항목별 속성으로 덮어씁니다: 이후 던전 흐름의 폴백 분기
      # (입장 재시도 시 카드 단계 해제 등)가 이 항목의 설정대로 동작합니다.
      $ndCoinFallback = [bool]$script:customItem.ExhaustContinue
      $ndLootFallback = [bool]$script:customItem.NoDoubleSweep
      $ndMatching     = '우연한 만남'   # 1차 릴리스 제한: 매칭 설정 무관 강제
      if ($deepMode) {
        # 심층 강제 규칙: 난이도 어려움 고정(주간 매우 어려움은 일반 반복 전용 - 리스트 제외),
        # 더블 루팅 없음. 잘못된 토큰 값이 흘러 들어와도 여기서 정규화합니다 (설계 합의).
        $ndDifficulty = '어려움'
        $ndDoubleLoot = $false
        $ndLootFallback = $false
      }
    }
  } elseif ($contentCategory -eq 'abyss') {
    $script:customItem = $script:abyssCustomPreparsed
    if ($null -eq $script:customItem) {
      $script:customSpecInvalid = $true
    } else {
      $script:customMode = $true
      $script:customPrev = ConvertFrom-AbyssCustomItemSpec -Spec ([string]$env:HONEYNOGI_CUSTOM_PREV)
      $script:customNext = ConvertFrom-AbyssCustomItemSpec -Spec ([string]$env:HONEYNOGI_CUSTOM_NEXT)
    }
  }
  if ($script:customMode) {
    $script:customRestart = ($env:HONEYNOGI_CUSTOM_RESTART -eq '1')
    $script:customRecoveryOnly = ($env:HONEYNOGI_CUSTOM_RECOVERY -eq '1')
    $script:customPositionText = [string]$env:HONEYNOGI_CUSTOM_POSITION
    $script:customListText = [string]$env:HONEYNOGI_CUSTOM_LIST
    $script:customMarkerPath = [string]$env:HONEYNOGI_CUSTOM_MARKER
    $script:customOwnerJson = [string]$env:HONEYNOGI_CUSTOM_OWNER
  }
}
# 마지막 판 신호 (GUI가 사전 판정: 커스텀 N바퀴의 마지막 바퀴 마지막 항목 / 횟수 지정 마지막 회차).
# 던전 흐름만 사용합니다 - 결과 화면에서 '다시 하기' 대신 '나가기'로 필드에 나가며 마칩니다.
$script:dgLastRun = ([string]$env:HONEYNOGI_LAST_RUN -eq '1')
# 던전 선택/옵션 화면의 OCR 영역들 (2026-07-15 실측 검증)
$rgDgTitle      = @(Get-ConfigValue $config @('ocrRegions', 'dgTitle') @(30, 45, 250, 55))        # 좌상단 제목 (선택: '○○ 던전' / 옵션: 'N층 M구역') - 기본값은 config.json과 동일하게 유지
$rgDgDifficulty = @(Get-ConfigValue $config @('ocrRegions', 'dgDifficulty') @(30, 165, 200, 50))  # 일반/어려움 알약
$rgDgEnterBtn   = @(Get-ConfigValue $config @('ocrRegions', 'dgEnterButton') @(660, 620, 520, 70)) # 'N층 M구역 진입' 버튼
# 은동전/더블 루팅 카드 버튼은 상태별로 위치·폭이 달라('선택됨'=넓고 우측 / '도전'=좁고 좌측)
# 한 영역으로 두 상태를 다 읽지 못합니다. 그래서 각 카드마다 주 영역 + 보조 영역을 두고,
# 주 영역에서 판별이 안 되면 보조 영역을 읽습니다 (Set-DgToggleCard의 AltRegion).
$rgDgCoinButton = @(Get-ConfigValue $config @('ocrRegions', 'dgCoinButton') @(388, 300, 205, 50))     # 은동전 주: 넓은 영역 ('선택됨' 대응, 실측 검증)
$rgDgCoinButtonAlt = @(Get-ConfigValue $config @('ocrRegions', 'dgCoinButtonAlt') @(400, 292, 130, 44)) # 은동전 보조: 좁은 영역 ('도전' 대응)
$rgDgLootButton = @(Get-ConfigValue $config @('ocrRegions', 'dgLootButton') @(388, 494, 130, 48))     # 더블 루팅 주: 좁은 영역 ('도전' 대응, 실측 검증)
$rgDgLootButtonAlt = @(Get-ConfigValue $config @('ocrRegions', 'dgLootButtonAlt') @(388, 493, 205, 50)) # 더블 루팅 보조: 넓은 영역 ('선택됨' 대응)
# ===== 던전 구역 지도 4유형 좌표 체계 (2026-07-24 확정 실측: 10던전 x 4화면 40장, 3중 교차 검증) =====
# 구역 지도 배치는 던전·층마다 다르며 총 4유형입니다:
#   A  = 가로형·소카드 하단  / B = 가로형·소카드 상단
#   CR = 세로형(위=n-2, 아래=n-1) / CN = 세로형(위=n-1, 아래=n-2)
# 같은 유형 안에서는 던전 간 좌표 편차가 ~1px라 유형 템플릿 + 던전·층→유형 매핑으로 좌표를 정합니다.
# 선택 화면 좌표는 '1층 포커스' 상태 기준이며, 2층 포커스면 전체가 정확히 29px 위로 밀립니다
# (10던전 전부 강체 이동 실측 - 연속 스크롤이 아니라 2상태뿐). 옵션 화면 지도는 밀림 없음.
# 과거의 룬다 단일 좌표표 + 라벨 평균 오프셋 보정은 배치가 다른 던전의 라벨이 평균을 오염시켜
# 폐기했습니다 (2026-07-22 피오드 실사고 - run_20260722_h20m55s16.log).
$dgFocusShiftY = 29
# 던전·층 → 배치 유형 매핑 (@(1층 유형, 2층 유형)). 미등록 던전은 라벨/기하 프로브로만 진행.
$dgLayoutTable = @{
  '룬다'      = @('A', 'CR');  '피오드'    = @('B', 'A');  '페카고분'  = @('B', 'A')
  '페론고분'  = @('CR', 'A');  '바리1광구' = @('A', 'B');  '바리2광구' = @('B', 'A')
  '마스던전'  = @('B', 'CN');  '라비던전'  = @('A', 'A');  '알비던전'  = @('A', 'B')
  '키아던전'  = @('CR', 'A')
}
# 난이도 2단계(일반/어려움) 던전 - 2026-07-24 실측: 10던전 중 룬다·피오드만 '매우 어려움' 없음.
# '매우 어려움' 요청 + 2단계 던전이면 즉시 중단합니다 (없는 난이도로 오입장 방지 - 교차 리뷰 반영).
$dgTwoTierDungeons = @('룬다', '피오드')
# 제목 OCR 조각 → 던전 ID (오독 이형 실측 포함: 룬다→로다, 피오드→피오듸, 페론→페로).
# 바리 광구는 숫자까지 명확해야 채택 - 숫자 소실 시 ID 불명으로 처리 (리뷰 교차 합의).
$dgNamePatterns = @(
  # 오독 이형은 전부 2026-07-24~25 실기 검증 실측입니다 (첫 글자/둘째 글자가 자주 깨짐).
  # '오드'는 약한 조각이지만 다른 던전명과 충돌하지 않고, '바리오드'류는 다중 매칭 가드가
  # null 처리합니다 (설계 합의).
  @{ Id = '룬다';     Any = @('룬다', '로다', '른다', '분다', '닡다', '눛나') }
  @{ Id = '피오드';   Any = @('피오', '깨오', '오드') }
  @{ Id = '페카고분'; Any = @('페카', '패가') }
  @{ Id = '페론고분'; Any = @('페론', '페로', '페혼', '페붇') }
  @{ Id = '마스던전'; Any = @('마스', '마싀') }   # '마싀' = '마스'+'1층' 합쳐진 오독 ('마싀층2구역' 실측)
  @{ Id = '라비던전'; Any = @('라비', '라바') }   # '라바' = 라비 오독 (실기 매 회차 관측)
  @{ Id = '알비던전'; Any = @('알비') }
  @{ Id = '키아던전'; Any = @('키아', '기아') }   # '기아' = 키아 오독 (실기 관측)
)
# 선택 화면 구역 라벨 중심 (유형별, 1층 포커스 기준. 라벨은 카드 안이라 클릭 유효점)
# CN 1층은 실측 던전이 없어 CR 대칭값 (현재 CN 1층 던전 미발견 - 매핑에 없으면 사용되지 않음)
$dgSelStagePoints = @{
  'A'  = @{ '1-1' = @(206, 425); '1-2' = @(293, 425); '1-3' = @(397, 398)
            '2-1' = @(206, 668); '2-2' = @(293, 668); '2-3' = @(397, 640) }
  'B'  = @{ '1-1' = @(206, 338); '1-2' = @(293, 338); '1-3' = @(397, 394)
            '2-1' = @(206, 580); '2-2' = @(293, 580); '2-3' = @(397, 637) }
  'CR' = @{ '1-1' = @(249, 425); '1-2' = @(249, 337); '1-3' = @(353, 394)
            '2-1' = @(249, 665); '2-2' = @(249, 580); '2-3' = @(353, 637) }
  'CN' = @{ '1-1' = @(249, 337); '1-2' = @(249, 425); '1-3' = @(353, 394)
            '2-1' = @(249, 580); '2-2' = @(249, 667); '2-3' = @(353, 640) }
}
# 옵션 화면 구역 라벨 중심 (유형별·구역 번호별 - 1층/2층 좌표 동일 실측, 밀림 없음)
$dgOptStagePoints = @{
  'A'  = @{ '1' = @(830, 326); '2' = @(918, 326); '3' = @(1022, 298) }
  'B'  = @{ '1' = @(830, 238); '2' = @(918, 238); '3' = @(1022, 295) }
  'CR' = @{ '1' = @(874, 326); '2' = @(874, 238); '3' = @(979, 295) }
  'CN' = @{ '1' = @(874, 238); '2' = @(874, 326); '3' = @(979, 298) }
}
$rgNdStageMap = @(40, 230, 520, 470)   # 스테이지 지도 라벨 판독 영역

# ===== 심층던전 모드 데이터 (2026-07-27 확정 실측: 9던전 43장, 이슈 문서 참고) =====
# 심층은 던전과 좌표 그리드가 픽셀 단위로 동일합니다 (선택/옵션 지도, 포커스 29px 포함).
# 신규 배치는 키아의 L형 2종뿐이고, 내부 스테이지 표현은 '1-1'을 유지하며 'D' 접두는
# 화면 라벨 계층에서만 변환합니다 (설계 합의 - 제목/층 파싱 함수 전체 무변경 재사용).
$dgSelStagePoints['L1'] = @{ '1-1' = @(266, 426); '1-2' = @(266, 338); '1-3' = @(354, 338)
                             '2-1' = @(266, 668); '2-2' = @(354, 668); '2-3' = @(354, 581) }   # 2층 키는 L2 값 (키아 전용 - 방어용)
$dgSelStagePoints['L2'] = @{ '1-1' = @(266, 426); '1-2' = @(266, 338); '1-3' = @(354, 338)     # 1층 키는 L1 값 (방어용)
                             '2-1' = @(266, 668); '2-2' = @(354, 668); '2-3' = @(354, 581) }
$dgOptStagePoints['L1'] = @{ '1' = @(891, 326); '2' = @(891, 239); '3' = @(979, 238) }
$dgOptStagePoints['L2'] = @{ '1' = @(891, 326); '2' = @(979, 326); '3' = @(979, 239) }
$ddLayoutTable = @{
  '페카고분'  = @('B', 'A');  '북쪽폐허'  = @('A', 'A');  '남쪽폐허'  = @('CR', 'B')
  '알비던전'  = @('A', 'B');  '키아던전'  = @('L1', 'L2'); '라비던전'  = @('A', 'A')
  '마스던전'  = @('B', 'CN'); '바리1광구' = @('A', 'B');  '바리2광구' = @('B', 'A')
}
# 심층 제목 조각 → 던전 ID (오독 이형은 2026-07-27 실측: 페카→메카, 키아→기아, 폐허→폐하는
# 북쪽/남쪽 첫 단어로 구분되어 조각에 불필요). 바리 광구 숫자 가드는 공용 함수에 내장.
$ddNamePatterns = @(
  @{ Id = '페카고분';  Any = @('페카', '패가', '메카') }
  @{ Id = '북쪽폐허';  Any = @('북쪽', '록쪽') }   # '록쪽' = '북'→'록' 오독 (2026-07-28 23:04 실기, 비권장 창 크기)
  @{ Id = '남쪽폐허';  Any = @('남쪽') }
  @{ Id = '알비던전';  Any = @('알비') }
  @{ Id = '키아던전';  Any = @('키아', '기아') }
  @{ Id = '라비던전';  Any = @('라비', '라바') }
  @{ Id = '마스던전';  Any = @('마스', '마싀', '파스') }   # '파스' = '마'→'파' 오독 (2026-07-29 21:52 실기)
)
# 알약 '어려움' 표준 x (Select-DgDifficultyWord 의 HardX): 심층은 '어려움'이 첫 알약
# 자리라 던전(선택 140/옵션 724)과 다름 (실측: 선택 (78,186), 옵션 (660,120)).
$dgSelHardX = 140
$dgOptHardX = 724
# 주간 매우 어려움 단일 카드 좌표 (실측): 선택 화면 카드 라벨 (310,382), 옵션 지도 단일 카드 (941,284)
$ddWeeklyCardPoint = @(310, 382)
$ddWeeklyOptCardPoint = @(941, 284)
# 던전 사이클이 쓰는 재화 상수 (심층이면 마족공물로 치환 - 수량은 난이도 기준.
# 커스텀 항목 오버라이드가 이 위에서 끝나므로 여기서 계산하는 $ndDifficulty 가 최종값)
$dgSweepCost = 10
$dgFullCost = 20
$dgCurrencyName = '은동전'
$dgExhaustLabel = '동전 소진 시'
$dgValidCosts = @(10, 20)
$dgBalanceMax = 150   # 은동전 보유 상한 (2026-07-28 사용자 제보) - 잔량 판독이 이를 넘으면 오독 확정

if ($deepMode) {
  # 모드 테이블 치환: 이후 모든 소비 함수(던전 판별/선택 화면 판정/좌표 산출)가 심층 기준으로 동작.
  # 2단계 가드($dgTwoTierDungeons)는 심층에서 미사용(어려움 고정)이라 비웁니다.
  $dgLayoutTable = $ddLayoutTable
  $dgNamePatterns = $ddNamePatterns
  $dgTwoTierDungeons = @()
  # 마족공물: 소탕 = 어려움 1개 / 매우 어려움 2개, 더블 루팅 없음 (사용자 실측 확정)
  $dgSweepCost = $(if ($ndDifficulty -eq '매우 어려움') { 2 } else { 1 })
  $dgFullCost = $dgSweepCost
  $dgCurrencyName = '마족공물'
  $dgExhaustLabel = '공물 소진 시'
  $dgValidCosts = @(1, 2)
  $dgBalanceMax = 15   # 마족공물 보유 상한 (2026-07-28 사용자 제보)
  $dgSelHardX = 78
  $dgOptHardX = 660
  # 공물 잔량 표시 영역 (옵션 화면 우상단). 재화줄은 골드(950)·은동전(1039)·마족공물(1087)·
  # 하트토큰(1146) 순서 고정 (2026-07-28 사용자 제보 + 캡처 2장 단어 좌표 실측 - 07-27 실측
  # (1088,67)과 일치). 이 영역(1056~1120)은 공물만 잡고 은동전/하트토큰은 밖이라 오독 없음.
  # Get-DgCoinBalance 가 마지막 숫자 그룹을 읽음.
  $rgDgCoinBalance = @(1056, 45, 64, 44)
  # 입장 버튼 소모량 판독 영역: 공물 뿔 아이콘을 제외하고 숫자+'입장하기'만 읽습니다
  # (2026-07-28 22:40 실기: 아이콘이 'V'/'7' 등으로 오독돼 소모량 1이 7로 읽혀 안전 정지 -
  # 'VI입장하기'/'Space72입장하기' 실측. 아이콘 x953~977, 숫자 x980~ 픽셀 실측으로 경계 확정.
  # 아이콘 제외 영역은 소탕선택 캡처 21장 중 IME 팝업 오염 2장 제외 전수가 첫 시도에
  # '1입장하기'/'2입장하기'로 즉시 정확 판독. config 키 값 불변 - coordsVersion 유지)
  $rgDgTributeCost = @(978, 636, 152, 44)
  # 제목 판독은 Read-DgTitleText 의 '좁은 우선 + 심층 조건부 확장' 이중 판독을 사용합니다
  # (폭 420 전역 확장은 밝은 배경 선택 화면에서 판독 전멸 - 2026-07-28 20:53 실기로 철회.
  # 근거 실측은 Read-DgTitleText 주석 참고).
}

function Get-DgMapLabelText {
  param([string]$Text)
  # 지도 라벨 OCR 원문 → 내부 스테이지 표기('1-1')로 정규화합니다.
  # 던전 모드는 원문 그대로(trim만), 심층 모드는 'D' 접두 제거 + 실측 오독 3종만 관용:
  # 'DI-n'→'D1-n'(1이 대문자 I), 전체 패턴 일치 시 '0'→'D'('02-3' 실측), 최종 화이트리스트
  # D[12]-[123] 통과분만 인정 (전역 치환 금지 - 설계 합의).
  $label = ([string]$Text).Trim()
  if (-not $deepMode) { return $label }
  if ($label -cmatch '^DI-([123])$') { $label = 'D1-' + $Matches[1] }
  elseif ($label -match '^0([12])-([123])$') { $label = 'D' + $Matches[1] + '-' + $Matches[2] }
  if ($label -match '^D([12]-[123])$') { return [string]$Matches[1] }
  return $label
}

function Get-DgDungeonIdFromTitle {
  param([string]$TitleText)

  # 선택('룬다 던전')/옵션('페카 고분 1층 1구역') 제목에서 던전 ID를 확정합니다.
  # 정확히 한 던전만 매칭될 때만 채택하고, 다중 매칭·바리 광구 숫자 소실은 ID 불명($null)입니다.
  # ID 불명은 '미등록 던전 확정'이 아니라 '모름'이며, 호출부는 라벨/기하 프로브로만 진행합니다.
  $normalized = ([string]$TitleText) -replace '\s', ''
  if ($normalized.Length -eq 0) { return $null }
  $found = @()
  foreach ($entry in $dgNamePatterns) {
    foreach ($fragment in $entry.Any) {
      if ($normalized.Contains([string]$fragment)) { $found += [string]$entry.Id; break }
    }
  }
  if ($normalized.Contains('바리')) {
    if ($normalized -match '([12])광') { $found += ('바리' + $Matches[1] + '광구') }
    else { $found += '바리광구불명' }
  }
  $found = @($found | Select-Object -Unique)
  if ($found.Count -ne 1) { return $null }
  if ($found[0] -eq '바리광구불명') { return $null }
  return [string]$found[0]
}

function Test-DgSelectionTitle {
  param([string]$TitleText)

  # 던전 선택 화면 제목 판정. 기존 '던전'/'오드' 조각만으로는 '페카 고분'/'페론 고분'/
  # '바리 N광구'처럼 제목에 '던전'이 없는 던전을 인식하지 못해, 시작 전 화면 정리가
  # 선택 화면을 '알 수 없는 화면'으로 오인하고 중앙/X 클릭으로 필드까지 이탈했습니다
  # (2026-07-25 01:07 실기 재현). '고분'/'광구' 조각과 던전 ID 매칭(오독 이형 포함)을 추가.
  # 옵션 화면('구역')은 선택 화면이 아니므로 먼저 제외합니다 ('피오드1층1구역'의 '오드' 오인 방지).
  $normalized = ([string]$TitleText) -replace '\s', ''
  if ($normalized.Length -eq 0) { return $false }
  # 옵션 화면 제외: '구역'뿐 아니라 '층'도 선제외합니다 - 선택 화면 제목에는 '층'이 없고,
  # '구역'이 '구멱' 등으로 깨진 옵션 제목('페카고분1층3구멱')이 선택 화면으로 오판되는 것 방지
  # (교차 리뷰 반영).
  if ($normalized.Contains('구역') -or $normalized.Contains('층')) { return $false }
  if ($normalized.Contains('던전') -or $normalized.Contains('오드') -or
      $normalized.Contains('고분') -or $normalized.Contains('광구')) { return $true }
  if (Get-DgDungeonIdFromTitle -TitleText $normalized) { return $true }
  # 심층 전용 던전(북쪽/남쪽 폐허)은 던전 모드의 이름 테이블($dgNamePatterns)에 없어 위
  # ID 매칭이 실패 → 선택 화면 미인식 → 탭 자동 전환 게이트에 도달하지 못합니다
  # (2026-07-28 21:58 실기: 던전 모드 + 심층 탭 '북쪽폐하'가 '던전 화면이 아닙니다'로 정지).
  # 모드와 무관하게 심층 이름 조각도 선택 화면 제목으로 인정합니다 (옵션 화면은 위의
  # 구역/층 선제외가 그대로 걸러줌).
  foreach ($ddEntry in $ddNamePatterns) {
    foreach ($ddFragment in $ddEntry.Any) {
      if ($normalized.Contains([string]$ddFragment)) { return $true }
    }
  }
  return $false
}

function Test-ImeOverlayText {
  param([string]$Text)

  # Windows IME 알림 팝업("한국어 Microsoft 입력기 / 입력 방법을 전환하려면 Windows 키 +
  # 스페이스를 누르세요") 판별식. 팝업이 게임 창 우하단(진입/입장 버튼 자리)을 덮으면
  # 버튼 OCR이 이 문구로 대체돼 클릭 게이트가 막히고, 클릭도 팝업에 먹힙니다
  # (2026-07-29 00:20 실기 + 보관 캡처 2장 재발 실증). 단일 조각은 오탐 위험이 있어
  # 두 조각 복합 조건으로만 판정합니다 (리뷰 계약). 실측 OCR 원문:
  # 'SpaceMicrosoft입력기심층1층입력방법을전환하러면Windows기+스페이스' ('하려면/키' 깨짐 포함)
  $normalized = ([string]$Text) -replace '\s', ''
  if ($normalized.Length -eq 0) { return $false }
  if ($normalized.Contains('Microsoft') -and $normalized.Contains('입력')) { return $true }
  if ($normalized.Contains('입력방법') -and $normalized.Contains('전환')) { return $true }
  if ($normalized.Contains('Windows') -and $normalized.Contains('스페이스')) { return $true }
  return $false
}

function Test-DgCardColor {
  param([int]$R, [int]$G, [int]$B)

  # 구역 카드 내부의 남색 판별식 (2026-07-24 40장 픽셀 실측으로 보정:
  # 포커스 패널 카드 300/300 + 비포커스 패널의 어두운(딤) 카드 300/300 통과,
  # 빈 공간·패널 배경 오탐 0/120 - 완벽 분리). 보라색 포커스 패널 배경(G가 R보다
  # 크게 낮음)은 G >= R-10 조건에서 걸러집니다. 딤 카드 최저 실측 B=52.
  return ((($B - $R) -ge 14) -and ($B -ge 50) -and ($G -ge ($R - 10)))
}

function Test-DgCardPixelAt {
  param([System.Diagnostics.Process]$Game, [int]$ReferenceX, [int]$ReferenceY)

  # 좌표에 실제 구역 카드가 있는지 픽셀로 확인합니다 (틀린 좌표 클릭 방지의 1차 관문).
  # 라벨 중심 주변 5점(흰 글자·S 아이콘을 피하는 오프셋)을 표본해 3점 이상 남색이면 카드입니다.
  $hits = 0
  foreach ($offset in @(@(-28, -2), @(28, -2), @(-28, 8), @(28, 8), @(0, 13))) {
    try {
      $c = Get-GamePixel -Game $Game -ReferenceX ($ReferenceX + $offset[0]) -ReferenceY ($ReferenceY + $offset[1])
    } catch { continue }
    if (Test-DgCardColor -R $c.R -G $c.G -B $c.B) { $hits++ }
  }
  return ($hits -ge 3)
}

function ConvertTo-GameReferencePoint {
  param([System.Diagnostics.Process]$Game, [System.Drawing.Point]$ScreenPoint)

  # 화면 픽셀 좌표를 기준 좌표(1272x717)로 역환산합니다 (픽셀 검증이 기준 좌표를 받기 때문).
  $rect = New-Object HoneyNogiInput+RECT
  if (-not [HoneyNogiInput]::GetWindowRect($Game.MainWindowHandle, [ref]$rect)) { return $null }
  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  if ($width -le 0 -or $height -le 0) { return $null }
  return @(
    [int][Math]::Round(($ScreenPoint.X - $rect.Left) * $referenceWidth / $width),
    [int][Math]::Round(($ScreenPoint.Y - $rect.Top) * $referenceHeight / $height)
  )
}

function Get-DgSelStagePoint {
  param([string]$LayoutType, [string]$Stage, [int]$FocusFloor)

  # 선택 화면 구역 라벨의 기대 좌표: 유형 템플릿 + 포커스 밀림(2층 포커스면 -29).
  # focusDy는 항상 기준(1층 포커스) 좌표에서 직접 계산합니다 - 누적 적용 금지 (설계 합의).
  if ([string]::IsNullOrEmpty($LayoutType) -or -not $dgSelStagePoints.ContainsKey($LayoutType)) { return $null }
  $table = $dgSelStagePoints[$LayoutType]
  if (-not $table.ContainsKey([string]$Stage)) { return $null }
  $point = $table[[string]$Stage]
  $dy = 0
  if ($FocusFloor -eq 2) { $dy = -$dgFocusShiftY }
  return @([int]$point[0], [int]($point[1] + $dy))
}

function Select-DgDifficultyWord {
  param($Words, [string]$Key, [int]$HardX = -1)

  # 던전 난이도 알약의 클릭 단어를 고르는 순수 판정 (진리표 테스트 대상 - 교차 리뷰 반영):
  #  - '매우어려움' → '매우' 단어를 채택 (OCR이 '매우'+'어려움' 두 단어로 읽음. '매우' 단어도
  #    알약 안이라 클릭 유효 - 사냥터에서 실전 검증된 방식)
  #  - '어려움' → 왼쪽 70px 안 같은 줄에 '매우' 단어가 있는 '어려움'은 건너뜀
  #    ('매우 어려움'의 뒷단어를 어려움으로 오채택해 오난이도 입장하는 사고 방지)
  #  - 그 외('일반' 등) → 단어 정확 일치
  # HardX = 해당 영역에서 '어려움' 알약의 표준 x (기준좌표. 선택 140 / 옵션 724 실측):
  # 앵커('일반'/'매우')가 하나도 안 읽혀도 단어 위치가 표준 자리 ±35px 면 단독 채택합니다.
  # 어려움이 이미 선택된 상태에서는 '일반' 알약이 흐릿해 OCR이 못 읽는 경우가 많고(2026-07-25
  # 피오드 실사고 - 앵커 없음으로 과잉 거부), '매우 어려움' 뒷단어는 표준 자리에서 110px 이상
  # 떨어져 있어 위치 검증으로는 오채택될 수 없습니다.
  # 반환: @{ X; Y } (기준 좌표) 또는 $null
  if ($Key -eq '매우어려움') {
    foreach ($word in $Words) {
      if ([string]$word.Text -eq '매우') { return @{ X = [int]$word.X; Y = [int]$word.Y } }
    }
    return $null
  }
  foreach ($word in $Words) {
    # '어려움'의 실측 깨짐 이형 허용 (2026-07-29 키아/페카 심층 실기 - 금색 선택 강조가 걸린
    # 알약의 깨짐이 스케일마다 다름: '이려움'(s3, 키아 옵션) / '이컪움'(s4, 페카·키아·알비
    # 선택) / '이컪울'(s5, 같은 화면). 전부 오류 캡처 오프라인 재현 실측. 이형도 아래 짝
    # 제외·앵커/HardX 검증을 똑같이 통과해야 채택되므로 오채택 불가 - 리뷰 승인)
    $textMatches = ([string]$word.Text -eq $Key) -or
                   ($Key -eq '어려움' -and (@('이려움', '이컪움', '이컪울') -contains [string]$word.Text))
    if (-not $textMatches) { continue }
    if ($Key -eq '어려움') {
      # ① '매우'의 짝(오른쪽 70px 이내 같은 줄)이면 '매우 어려움'의 뒷단어 - 제외
      $partOfVeryHard = $false
      foreach ($other in $Words) {
        if ([string]$other.Text -ne '매우') { continue }
        $dx = [int]$word.X - [int]$other.X
        if ($dx -gt 0 -and $dx -le 70 -and [Math]::Abs([int]$word.Y - [int]$other.Y) -le 14) {
          $partOfVeryHard = $true
          break
        }
      }
      if ($partOfVeryHard) { continue }
      # ② 기준 검증: '일반'의 40~110px 오른쪽(알약 간격 실측 71~72px)이거나 '매우' 토큰이
      #    보이는(= 짝이 아님이 확인된) 경우, 또는 단어 위치가 표준 '어려움' 자리(HardX ±35px)
      #    인 경우에만 채택. 어느 기준에도 안 맞는 단독 '어려움'은 매우 어려움의 뒷단어일 수
      #    있어 채택하지 않습니다 (오난이도 입장 방지).
      $anchorConfirmed = $false
      foreach ($other in $Words) {
        if ([string]$other.Text -eq '일반') {
          $dx = [int]$word.X - [int]$other.X
          if ($dx -ge 40 -and $dx -le 110 -and [Math]::Abs([int]$word.Y - [int]$other.Y) -le 14) {
            $anchorConfirmed = $true
            break
          }
        } elseif ([string]$other.Text -eq '매우') {
          $anchorConfirmed = $true
          break
        }
      }
      if (-not $anchorConfirmed -and $HardX -ge 0 -and [Math]::Abs([int]$word.X - $HardX) -le 35) {
        $anchorConfirmed = $true
      }
      if (-not $anchorConfirmed) { continue }
    }
    return @{ X = [int]$word.X; Y = [int]$word.Y }
  }
  return $null
}

function Select-DgTabWord {
  param($Words, [bool]$DeepTab)

  # 선택 화면 상단 '던전|심층 던전' 탭에서 클릭할 단어를 고릅니다 (순수 - 진리표 대상).
  # 실측 (2026-07-28, 1272x717): 던전(66,128) / 심층(135,128) 던전(172,128).
  # 심층 던전 탭 = '심층' 단어('심충' 오독 관용 - 퀘스트 트래커 실측 사례).
  # 던전 탭 = 왼쪽 70px 안 같은 줄에 심층 단어가 없는 '던전' 단어
  # (난이도 알약의 '매우 어려움' 뒷단어 제외와 같은 패턴 - 심층 던전 탭의 '던전' 오클릭 방지).
  # 반환: @{ X; Y } (기준 좌표) 또는 $null (호출부가 실측 예비 좌표 사용)
  if ($DeepTab) {
    foreach ($word in $Words) {
      if ([string]$word.Text -match '^심[층충]$') { return @{ X = [int]$word.X; Y = [int]$word.Y } }
    }
    return $null
  }
  foreach ($word in $Words) {
    if ([string]$word.Text -ne '던전') { continue }
    $deepPaired = $false
    foreach ($other in $Words) {
      if ([string]$other.Text -match '^심[층충]$') {
        $dx = [int]$word.X - [int]$other.X
        if ($dx -gt 0 -and $dx -le 70 -and [Math]::Abs([int]$word.Y - [int]$other.Y) -le 14) {
          $deepPaired = $true
          break
        }
      }
    }
    if (-not $deepPaired) { return @{ X = [int]$word.X; Y = [int]$word.Y } }
  }
  return $null
}

function Test-DgTabProbeMatchesMode {
  param([string]$ProbeText, [bool]$DeepTab)

  # 탭 전환 확인 (순수 - 진리표 대상): 선택 화면 진입 버튼 문구가 목표 탭과 일치하는지.
  # 빈/불완전 판독이 '심층 없음 = 던전 탭 성공'으로 오인되지 않게 '진입' 존재를 함께
  # 요구합니다 (리뷰 지적). '심층' 오독 '심충' 관용 포함.
  $normalized = ([string]$ProbeText) -replace '\s', ''
  if (-not $normalized.Contains('진입')) { return $false }
  $deepSeen = [bool]($normalized -match '심[층충]')
  return ($deepSeen -eq $DeepTab)
}

function Find-DgDifficultyPoint {
  param([System.Diagnostics.Process]$Game, [int[]]$Region, [string]$Label, [int]$HardX = -1)

  # 던전 난이도 알약의 클릭 지점(화면 픽셀)을 찾습니다. 단어 목록 기반 판정으로
  # '매우 어려움' 지원과 '어려움'↔'매우 어려움' 오채택 방지를 함께 처리합니다.
  # HardX = 이 영역에서 '어려움' 알약의 표준 x (Select-DgDifficultyWord 주석 참고).
  # 다중 스케일 재시도 (2026-07-29 실측): 금색 선택 강조가 걸린 알약은 스케일에 따라
  # 깨짐이 달라(선택 화면은 s3 정상/s4·s5 깨짐, 키아 옵션은 s4 빈 판독/s5 정상) 단일
  # 스케일로는 전멸할 수 있음. 실측 전 케이스에서 최소 한 스케일은 정상 판독 - 첫 성공
  # 채택, 성공 시 조기 종료라 기존 성공 경로 비용 불변 (Get-DgTributeCost 전례, 리뷰 승인).
  #
  # s2 최종 폴백 (2026-08-03 08:50 실사고): 1908x1076 창은 캡처 확대가 '기준 크기x배율'
  # 고정이라 실효 배율이 배율/1.5 로 떨어짐 - 옵션 '어려움' 알약이 s4/s3/s5(실효 2.67/2.0/
  # 3.33) 전부 깨져('1권하움'/빈 판독) 3연속 정지. 오류 캡처 3장을 워커 동일 파이프라인으로
  # 재현: s2(실효 1.33, 거의 원본)만 3장 모두 '어려움'(660,121) 정상 판독 + 채택 통과.
  # s6~s8(실효 4.0~5.3)도 전부 깨짐 실측 - 고배율 확장은 답이 아님. '어려움' 키 한정인
  # 이유: 앵커/HardX 위치 게이트가 어려움에만 있어 s2 오독이 있어도 오채택 불가지만,
  # 일반/매우어려움은 텍스트 게이트뿐이라 판정면을 늘리지 않음 (보수 조건. 매우
  # 어려움의 1908 실측이 모이면 확장 검토 - 백로그).
  $key = ([string]$Label) -replace '\s', ''
  $pillScales = @(4, 3, 5)
  if ($key -eq '어려움') { $pillScales += 2 }
  foreach ($pillScale in $pillScales) {
    $words = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $Region[0] -ReferenceY $Region[1] `
        -RegionWidth $Region[2] -RegionHeight $Region[3] -Scale $pillScale -Engine $ocrKoreanEngine)
    $refPoint = Select-DgDifficultyWord -Words $words -Key $key -HardX $HardX
    if ($refPoint) {
      $screenPoint = Get-ScaledScreenPoint -Game $Game -ReferenceX ([int]$refPoint.X) -ReferenceY ([int]$refPoint.Y)
      return [System.Drawing.Point]::new([int]$screenPoint.X, [int]$screenPoint.Y)
    }
  }
  return $null
}
# ===== '사냥터' 카테고리 설정 - 특정 사냥터에 매이지 않는 범용 방식 =====
# 사용자가 원하는 사냥터의 첫 화면(하단에 파티 찾기/입장하기)을 열어 두면 동작합니다.
$htDifficulty   = [string](Get-ConfigValue $config @('huntingGround', 'difficulty') '일반')
# 사냥터 소진 대응 (사용자 결정 2026-07-18): '소진 시 미사용으로 계속'은 없습니다 -
# 은동전이 10개 미만이면 사냥터에서 나가서(우상단 X) 자동화를 마칩니다 (코드 4).
# 단 continueSweepOnly(더블 루팅 불가 시 소탕만 계속)는 유지: 잔량 10~19개면
# 더블 루팅만 끄고 소탕(10개)으로 계속합니다.
$htUseCoin      = Get-ConfigBoolean $config @('huntingGround', 'useOffering') $false
$htDoubleLoot   = Get-ConfigBoolean $config @('huntingGround', 'doubleLoot') $false
$htLootFallback = Get-ConfigBoolean $config @('huntingGround', 'continueSweepOnly') $false
$htMatching     = [string](Get-ConfigValue $config @('huntingGround', 'matching') '파티찾기')
# 사냥터 첫 화면의 영역/좌표 (2026-07-15 창백한 산 화면 실측 - 모든 사냥터 공통 배치)
$rgHtDifficulty = @(Get-ConfigValue $config @('ocrRegions', 'htDifficulty') @(560, 100, 330, 45))  # 난이도 알약 (상단 중앙, 매우 어려움 3개 배치까지 커버)
# 임무 카드 버튼: 카드의 설명 줄 수에 따라 버튼 위치가 달라집니다 (2026-07-18 실측:
# 1줄 카드 = y292 / 2줄 카드 = y322). 두 위치를 모두 덮는 세로 확장 영역을 씁니다.
# (이 x 구간(388~530)에는 버튼 외 다른 글자가 없어 넓혀도 안전 - 실측 확인)
$rgHtCardButton = @(Get-ConfigValue $config @('ocrRegions', 'htCardButton') @(400, 288, 130, 80))  # 은동전 임무 카드의 '선택됨'/'도전' 버튼
$rgHtCardButtonAlt = @(Get-ConfigValue $config @('ocrRegions', 'htCardButtonAlt') @(388, 286, 205, 84)) # 보조: 넓은 영역 (버튼 상태별 위치·폭 차이 대응)
$rgHtEnterBtn   = @(Get-ConfigValue $config @('ocrRegions', 'htEnterButton') @(930, 632, 230, 50)) # 하단 입장 버튼 글자 (첫 화면 감지용 - 첫 진입 '입장하기' / 새 임무 선택 복귀 후 '임무 시작')
$ptHtCardButton = @(463, 330)      # 클릭 지점: 1줄(버튼 292~335)/2줄(322~364) 두 배치 모두 버튼 안 (실측)
# 더블 루팅 카드: 임무 카드 줄 수에 따라 같이 내려갑니다 (1줄 = y494 / 2줄 = y524 실측)
$rgHtLootButton = @(Get-ConfigValue $config @('ocrRegions', 'htLootButton') @(388, 490, 130, 82))
$rgHtLootButtonAlt = @(Get-ConfigValue $config @('ocrRegions', 'htLootButtonAlt') @(388, 489, 205, 86)) # 보조: 넓은 영역
$ptHtLootButton = @(452, 530)      # 클릭 지점: 두 배치(494~537 / 524~568) 모두 버튼 안 (실측)
# 결과 화면 (2026-07-17 실측): 던전(나가기/다시 하기)과 달리 '나가기/머무르기/새 임무 선택'
# 3버튼 구성이라 반복 재시작 버튼이 다릅니다 - '새 임무 선택'을 눌러야 첫 화면으로 돌아갑니다.
$rgHtRetryBtn  = @(Get-ConfigValue $config @('ocrRegions', 'htRetryButton') @(620, 625, 300, 60)) # '새 임무 선택' 버튼 글자 영역
$ptHtNewMission = @(797, 655)      # '새 임무 선택' 버튼 클릭 지점 (실측)
$ptHtClose      = @(1228, 67)      # 첫 화면 우상단 닫기(X) - 은동전 소진 시 나가기용 (실측)

# 진입 옵션 화면의 클릭 좌표 (기준 1272x717 실측)
$ptDgStageEnter   = @(918, 655)    # 선택 화면의 'N층 M구역 진입' 버튼
# IME 팝업 예비: 시스템 입력기 팝업(우하단 x≈908~, 2026-07-29 00:20 실측)이 기본 클릭
# 지점을 덮을 때 쓰는 진입 버튼 왼쪽 지점. 선택 화면 보관 캡처 43장 전수 픽셀 실측으로
# 전부 버튼 위(심층 분홍 206,64,96 / 일반 보라 129,99,255) 확인. 단 옵션 화면에서는 같은
# 자리가 '파티 찾기' 초록 버튼이므로 반드시 '선택 화면 제목 확인' 게이트와 함께만 사용.
$ptDgStageEnterLeft = @(770, 655)
# IME 팝업 전용 판독 영역 (팝업 실측 x≈908~1265, y≈612~700 - 여유 포함). OS 팝업은 게임
# 창 크기와 무관한 고정 픽셀 크기라 큰 창(1908x1076)에서는 비율 환산 영역과 어긋날 수
# 있지만, 우하단 앵커는 같아서 대부분 겹쳐 판독됩니다 (판별식이 조각 복합 조건이라 부분
# 판독으로도 동작).
$rgImePopup = @(905, 610, 360, 95)
$ptDgBackArrow    = @(43, 67)      # 진입 옵션 화면 좌상단 '<' (선택 화면으로 한 단계 뒤로) - 2026-07-18 실측
                                   # 주의: ESC는 한 단계 뒤로가 아니라 던전 UI 전체를 닫고 필드로 나감 (18:44 실측)
$rgDgOptDifficulty = @(600, 95, 320, 50) # 진입 옵션 화면 상단 난이도 알약 - 2026-07-24 확장: '매우 어려움'('매우' 단어 x≈796)까지 커버 (기존 190 폭은 x790에서 잘림)
$ptDgCoinButton   = @(463, 313)    # 은동전(소탕) 카드의 선택됨/도전 버튼
$ptDgLootButton   = @(452, 517)    # 더블 루팅 카드의 선택됨/도전 버튼
$ptDgChanceToggle = @(1183, 415)   # '우연한 만남' 토글 (초록 = 켜짐)
$ptDgPartyFind    = @(775, 655)    # '파티 찾기' 버튼
$ptDgEnterFinal   = @(1015, 655)   # '입장하기' 버튼
# '던전에 입장하시겠습니까?' 확인 팝업 (도전 미수락 시 표시): '일주일 동안 보지 않기' 체크 후 입장
$rgDgWeekPopup    = @(Get-ConfigValue $config @('ocrRegions', 'dgWeekPopup') @(450, 520, 380, 60)) # '일주일 동안 보지 않기' 문구 영역
$ptDgConfirmEnter = @(742, 618)    # 확인 팝업의 '입장하기' 버튼
# 클리어 후 결과 화면의 버튼 구성 (2026-07-18 실측 - 스테이지/난이도에 따라 달라짐):
#   1-1/1-2/2-1/2-2      = 나가기 / 다시 하기 / 다음 구역으로   (3버튼)
#   1-3                  = 나가기 / 다시 하기 / 다음 층으로     (3버튼)
#   일반 2-3             = 나가기 / 다시 하기 / 다음 난이도로   (3버튼)
#   어려움(최종) 2-3     = 나가기 / 다시 하기                   (2버튼)
# 3버튼일 때 다시 하기는 가운데(637,655)로 이동합니다. 그래서 클릭은 고정 좌표가 아니라
# '다시 하기' 글자 탐색 지점을 쓰고('다음 ~로' 계열은 탐색어에 안 걸림), 영역은 두 배치를 모두 덮습니다.
$rgDgRetryBtn   = @(Get-ConfigValue $config @('ocrRegions', 'dgRetryButton') @(540, 625, 340, 60)) # '다시 하기' 버튼 영역 (두 배치 커버)
$ptDgRetry      = @(637, 655)      # '다시 하기' 예비 좌표 (글자 탐색 실패 시 - 3버튼 배치 기준)

# '다시 하기'로 온 진입 옵션 화면의 구역 지도:
# 선택 화면의 세로 지도와 배치가 달라 $ndStagePoints 를 재사용하면 왼쪽 소탕 카드를 오클릭합니다.
# 카드 숫자 라벨 OCR을 우선하고, 못 읽으면 층별 실측 예비 좌표를 씁니다. 1층과 2층은 배치가
# 다릅니다(2026-07-21 실측: 2층은 2-2/2-1이 왼쪽에 세로로 놓이고 2-3이 오른쪽에 위치).
$rgDgOptStageMap = @(750, 170, 360, 210) # 옵션 화면 구역 지도 영역

function Get-DgOptStageFallbackPoint {
  param([string]$Stage, [string]$LayoutType)

  # 옵션 화면 유형 템플릿 좌표 (2026-07-24 40장 확정 실측 - 유형 내 던전 간 편차 ~1px).
  # 과거의 룬다 단일표(1층=A형, 2층=CR형 좌표)는 다른 배치 던전에서 카드 밖/다른 카드를
  # 눌러 폐기했습니다. 유형을 모르면 좌표를 만들지 않습니다 (틀린 좌표 클릭 금지).
  # PSCustomObject 단일 객체로 반환해 PowerShell의 2요소 배열 풀림을 피합니다.
  if ([string]::IsNullOrEmpty($LayoutType) -or -not $dgOptStagePoints.ContainsKey($LayoutType)) { return $null }
  $stageParts = ([string]$Stage) -split '-'
  if ($stageParts.Count -ne 2) { return $null }
  $table = $dgOptStagePoints[$LayoutType]
  if (-not $table.ContainsKey([string]$stageParts[1])) { return $null }
  $point = $table[[string]$stageParts[1]]
  return [pscustomobject]@{ X = [int]$point[0]; Y = [int]$point[1] }
}

function Get-DgOptLayoutTypeByPixels {
  param([System.Diagnostics.Process]$Game)

  # 미등록 던전의 옵션 화면 배치를 카드 픽셀로 판별합니다. 가로형 상/하 행은 88px 떨어져
  # 분리가 명확합니다. 세로형(C)은 위/아래 카드의 의미 순서(CR/CN)를 픽셀로 알 수 없어
  # 'C'만 반환하며, 호출부는 라벨 판독 없이는 진행하지 않습니다 (설계 합의).
  # 주의: 가로형에서 세로 열 지점(874)은 옆 카드와 표본이 겹칠 수 있어 행 판정을 우선합니다.
  $rowBottom = (Test-DgCardPixelAt -Game $Game -ReferenceX 830 -ReferenceY 326) -and
               (Test-DgCardPixelAt -Game $Game -ReferenceX 918 -ReferenceY 326)
  $rowTop    = (Test-DgCardPixelAt -Game $Game -ReferenceX 830 -ReferenceY 238) -and
               (Test-DgCardPixelAt -Game $Game -ReferenceX 918 -ReferenceY 238)
  if ($rowBottom -and -not $rowTop) { return 'A' }
  if ($rowTop -and -not $rowBottom) { return 'B' }
  if (-not $rowTop -and -not $rowBottom) {
    $colBoth = (Test-DgCardPixelAt -Game $Game -ReferenceX 874 -ReferenceY 238) -and
               (Test-DgCardPixelAt -Game $Game -ReferenceX 874 -ReferenceY 326)
    if ($colBoth) { return 'C' }
  }
  return $null
}

function Get-DgOptStageCardPoint {
  # 옵션 화면에서 항목 구역 카드의 클릭 지점을 찾습니다 (2026-07-24 상태·기하 중심 재설계).
  #  1) 카드 숫자 라벨 다중 배율 탐색(4→6→8 - 단일 배율은 화면마다 성패가 갈림, 40장 실측)
  #     + 카드 픽셀 확인 (라벨 오독으로 엉뚱한 곳을 잡는 오탐 차단)
  #  2) 던전·층→유형 매핑의 템플릿 좌표 + 카드 픽셀 확인
  #  3) 미등록 던전: 행 픽셀 판별로 가로 상/하(A/B)만 지원 - 세로형은 순서 불명이라 정지
  # 반환: @{ Screen = (화면 픽셀 지점) } 또는 @{ Reference = @(기준X, 기준Y) } / 실패 시 $null
  param([System.Diagnostics.Process]$Game, [string]$Stage)
  # 심층 모드는 화면 라벨이 'D1-1' 형태 + 실측 오독('DI-1'/'02-3')이 있어 후보를 함께 탐색합니다
  $labelCandidates = @([string]$Stage)
  if ($deepMode) {
    $labelCandidates = @('D' + $Stage)
    $deepParts = ([string]$Stage) -split '-'
    if ($deepParts.Count -eq 2) {
      if ([string]$deepParts[0] -eq '1') { $labelCandidates += ('DI-' + $deepParts[1]) }
      $labelCandidates += ('0' + $Stage)
    }
  }
  foreach ($labelScale in 4, 6, 8) {
    foreach ($labelCandidate in $labelCandidates) {
      $cardPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgDgOptStageMap[0] -ReferenceY $rgDgOptStageMap[1] `
        -RegionWidth $rgDgOptStageMap[2] -RegionHeight $rgDgOptStageMap[3] `
        -SearchText $labelCandidate -ExactText $labelCandidate -Scale $labelScale
      if ($cardPoint) {
        $refPoint = ConvertTo-GameReferencePoint -Game $Game -ScreenPoint $cardPoint
        if ($refPoint -and (Test-DgCardPixelAt -Game $Game -ReferenceX $refPoint[0] -ReferenceY $refPoint[1])) {
          return @{ Screen = $cardPoint }
        }
        if ($deepMode -and $refPoint) {
          # 심층 카드 적갈색이라 픽셀 확인 항상 실패 - 정확 일치 라벨(D1-1/DI-1/01-1 한정
          # 후보)은 신뢰하고, 카드 전환 후 제목 확인(호출부 2차 검증)에 맡긴다
          # (선택 화면 라벨 경로와 동일 계약 - 2026-07-30 리뷰 승인)
          return @{ Screen = $cardPoint }
        }
      }
    }
  }
  $layoutType = $null
  $stageParts = ([string]$Stage) -split '-'
  if ($script:dgDungeonId -and $dgLayoutTable.ContainsKey([string]$script:dgDungeonId) -and $stageParts.Count -eq 2) {
    $floorNum = 0
    if ([int]::TryParse([string]$stageParts[0], [ref]$floorNum) -and $floorNum -ge 1 -and $floorNum -le 2) {
      $layoutType = [string]($dgLayoutTable[[string]$script:dgDungeonId][$floorNum - 1])
    }
  }
  if (-not $layoutType) {
    $probedType = Get-DgOptLayoutTypeByPixels -Game $Game
    if ($probedType -eq 'A' -or $probedType -eq 'B') {
      $layoutType = $probedType
      Write-RunLog "[던전] 미등록 던전 - 옵션 지도 배치를 픽셀로 판별: $probedType"
    } elseif ($probedType -eq 'C') {
      # 세로형의 순서 모호성(CR/CN)은 소카드 1/2에만 있습니다. 대카드(구역 3)는 두 순서에서
      # 위치가 같아(979,295~298 - 중간값 297) 미등록이어도 진행합니다. 카드 픽셀 확인 실패나
      # 소카드 목표는 기존대로 정지합니다 (2026-07-25 페론 고분 실기 과잉 정지 - 설계 합의).
      if ($stageParts.Count -eq 2 -and [string]$stageParts[1] -eq '3' -and
          (Test-DgCardPixelAt -Game $Game -ReferenceX 979 -ReferenceY 297)) {
        Write-RunLog '[던전] 미등록 던전 세로형 - 대카드(구역 3)는 순서 무관 위치라 진행합니다'
        return @{ Reference = @(979, 297) }
      }
      Write-RunLog '[던전] 미등록 던전의 세로형 지도 - 소카드 순서를 알 수 없어 라벨 없이는 클릭하지 않습니다'
      return $null
    }
  }
  if ($layoutType) {
    $fallback = Get-DgOptStageFallbackPoint -Stage $Stage -LayoutType $layoutType
    if ($fallback) {
      if (-not (Test-DgCardPixelAt -Game $Game -ReferenceX $fallback.X -ReferenceY $fallback.Y)) {
        # 유형이 실측 매핑 또는 행 프로브로 이미 확인된 상태라 픽셀 미확인이어도 좌표를
        # 신뢰하고 시도합니다 (RDP 색 왜곡 대비 - 전환 실패는 제목 검증이 잡음).
        Write-RunLog "[던전] 옵션 템플릿 좌표의 카드 픽셀 확인 실패 - 유형이 확인된 상태라 그대로 시도합니다"
      }
      return @{ Reference = @([int]$fallback.X, [int]$fallback.Y) }
    }
  }
  return $null
}

function Resolve-DgObservedStage {
  param([string[]]$MapTexts, [string]$TitleText)

  # 제목 숫자가 깨졌을 때('피오듸층3구역' 실사고 - 던전 이름 끝 글자와 층 숫자가 합쳐짐)의
  # 보조 판정 순수부 (진리표 테스트 대상): 층 = 지도 라벨 앞 숫자가 단일 층이고 표가
  # 2개 이상일 때만, 구역 = 제목 꼬리 '(\d)구역'. 두 신호가 모두 명확할 때만 'N-M' 반환
  # (설계 합의: 라벨 1개 단독 확정 금지 + 요청 값과 전부 일치 시에만 성공 처리).
  $floorVotes = @{}
  foreach ($text in $MapTexts) {
    if ([string]$text -match '^([12])-[123]$') {
      $floorVotes[$Matches[1]] = [int]$floorVotes[$Matches[1]] + 1
    }
  }
  if ($floorVotes.Keys.Count -ne 1) { return $null }   # 라벨 미판독 또는 층 혼재 - 불명
  $observedFloor = [string]@($floorVotes.Keys)[0]
  if ([int]$floorVotes[$observedFloor] -lt 2) { return $null }   # 표 1개로는 층 확정 금지
  $areaMatches = [regex]::Matches((([string]$TitleText) -replace '\s', ''), '(\d)구역')
  if ($areaMatches.Count -eq 0) { return $null }
  $observedArea = [string]$areaMatches[$areaMatches.Count - 1].Groups[1].Value
  return "$observedFloor-$observedArea"
}

function Get-DgOptObservedStage {
  param([System.Diagnostics.Process]$Game, [string]$TitleText)

  # 옵션 지도 라벨을 세 배율로 읽어 보조 판정 순수부에 넘깁니다 (같은 라벨이 두 배율에서
  # 읽히면 표 2개 = 배율 합의로 인정). 배율 3 포함 - 2026-07-26 실사고: 피오드 옵션1층은
  # S4=1개/S6=0개인데 S3는 소카드까지 읽혀서(진단 덤프 실측) 4·6만으로는 표가 부족했음.
  $mapTexts = @()
  foreach ($mapScale in 3, 4, 6) {
    $mapWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $rgDgOptStageMap[0] -ReferenceY $rgDgOptStageMap[1] `
        -RegionWidth $rgDgOptStageMap[2] -RegionHeight $rgDgOptStageMap[3] -Scale $mapScale -Engine $ocrKoreanEngine)
    foreach ($mapWord in $mapWords) { $mapTexts += (Get-DgMapLabelText -Text $mapWord.Text) }   # 심층 D라벨 정규화 포함
  }
  return (Resolve-DgObservedStage -MapTexts $mapTexts -TitleText $TitleText)
}

function Set-DgOptionStage {
  param(
    [System.Diagnostics.Process]$Game,
    [string]$Stage,
    [scriptblock]$ReadTitle,
    [string]$LogTag = '[던전]',
    [switch]$AssumeMismatchFirst
  )

  # 진입 옵션 화면에서 같은 층의 목표 구역 카드로 전환합니다. 커스텀 반복과 일반 던전의
  # 선택 화면 오클릭 복구가 같은 구현을 사용하며, 제목이 목표 구역으로 바뀐 것이 확인돼야 성공입니다.
  # 제목 숫자가 계속 불명확하면(던전 이름에 따라 층 숫자가 합쳐지는 실사고) 지도 라벨 층 +
  # 제목 꼬리 구역의 보조 판정을 1회 시도합니다.
  $titleText = & $ReadTitle
  $stageSwitched = $false
  $clicks = 0
  $unclearReads = 0
  $observedTried = $false
  for ($try = 1; $try -le 8; $try++) {
    $match = Test-CustomTitleStageMatch -TitleText $titleText -Stage $Stage
    if ($match -eq 'match') { $stageSwitched = $true; break }
    if ($match -ne 'mismatch') {
      $unclearReads++
      # 제목이 '연속' 3회 불명확할 때 보조 판정을 시도합니다. 판정이 '나온' 경우에만 화면
      # 상태별 1회 잠금(mismatch/클릭이 나오면 카운터·플래그 리셋 - 전환 중 화면 오확정 방지,
      # 교차 리뷰 반영), 불명(null)이면 잠그지 않고 다음 회차에 재시도합니다.
      # 보조 판정이 '현재 = 목표'면 성공, '같은 층 다른 구역'이면 mismatch로 승격해 카드를
      # 클릭하고, '다른 층'이면 이 화면에서 전환 불가라 안전 실패합니다.
      $observedPromoted = $false
      if ($AssumeMismatchFirst -and $clicks -eq 0) {
        # 호출부(커스텀 시작 분기)가 이미 보조 판정으로 '같은 층의 다른 구역'을 확정한 호출:
        # 제목이 불명확해도 첫 클릭은 진행합니다. 같은 층에서 목표 카드 클릭은 멱등이라
        # (이미 목표 구역이어도 재선택일 뿐 무해) 상태 기반 클릭 정책에 어긋나지 않고,
        # 전환 확인은 이후 제목/보조 판정으로 동일하게 검증합니다. (2026-07-26 실사고:
        # 내부 보조 판정까지 불명이면 클릭 한 번 없이 8회 대기만 하다 정지했음)
        Write-RunLog "$LogTag 제목 불명확 - 시작 보조 판정(같은 층 다른 구역)에 따라 카드 클릭을 진행합니다 (제목: '$titleText')"
        $observedPromoted = $true
      } elseif ($unclearReads -ge 3 -and -not $observedTried) {
        $observedStage = Get-DgOptObservedStage -Game $Game -TitleText $titleText
        # 판정이 '나온' 경우에만 상태별 1회 잠금 - 불명(null)이면 다음 회차에 재시도합니다
        # (2026-07-26 실사고: 1회 불명 후 잠겨서 남은 회차 내내 보조 판정이 다시 돌지 않았음)
        if ($observedStage) { $observedTried = $true }
        if ($observedStage -eq $Stage) {
          Write-RunLog "$LogTag 제목 숫자가 계속 불명확하지만 지도 라벨 층 + 제목 구역 보조 판정이 목표(${Stage})와 일치 - 전환 확인 (제목: '$titleText')"
          $stageSwitched = $true
          break
        }
        if ($observedStage) {
          $observedFloorText = ([string]$observedStage -split '-')[0]
          $targetFloorText = (([string]$Stage) -split '-')[0]
          if ($observedFloorText -eq $targetFloorText) {
            Write-RunLog "$LogTag 보조 판정: 현재 ${observedStage} - 같은 층의 다른 구역이라 카드 클릭으로 전환합니다 (제목: '$titleText')"
            $observedPromoted = $true
          } else {
            Write-RunLog "$LogTag 보조 판정: 현재 ${observedStage} - 다른 층이라 이 화면에서는 전환할 수 없습니다 (제목: '$titleText')"
            return [pscustomobject]@{ Ok = $false; Title = $titleText; Reason = 'wrong-floor' }
          }
        }
      }
      if (-not $observedPromoted) {
        Start-Sleep -Milliseconds 1200
        $titleText = & $ReadTitle
        continue
      }
    }
    $unclearReads = 0
    if ($clicks -ge 3) { break }
    $clicks++
    $target = Get-DgOptStageCardPoint -Game $Game -Stage $Stage
    if (-not $target) {
      return [pscustomobject]@{ Ok = $false; Title = $titleText; Reason = 'not-found' }
    }
    Focus-Game -Game $Game
    if ($target.ContainsKey('Screen')) {
      Click-ScreenPoint -X $target.Screen.X -Y $target.Screen.Y
      Write-RunLog "$LogTag 구역 ${Stage} 카드 클릭 - 글자 탐색 (${clicks}/3)"
    } else {
      Click-GamePoint -Game $Game -ReferenceX $target.Reference[0] -ReferenceY $target.Reference[1]
      Write-RunLog "$LogTag 구역 ${Stage} 카드 클릭 - 예비 좌표 (${clicks}/3)"
    }
    Start-Sleep -Milliseconds 1100
    $titleText = & $ReadTitle
    # 클릭으로 화면 상태가 바뀌었으므로 보조 판정은 새 상태에서 다시 1회 허용합니다
    $observedTried = $false
  }
  return [pscustomobject]@{
    Ok     = $stageSwitched
    Title  = $titleText
    Reason = $(if ($stageSwitched) { '' } else { 'not-confirmed' })
  }
}
$ptDgResultExit = @(515, 654)      # 결과 화면 '나가기' 버튼 (안전 중지 시 사용)
# 은동전 소탕 결과 화면: 전리품 공개(카드) 상태에서는 나가기/다시 하기가 아직 없고
# 화면을 한 번 클릭해야 진행됩니다. '발견한 전리품' 라벨로 이 상태를 감지합니다.
$rgDgLootReveal = @(Get-ConfigValue $config @('ocrRegions', 'dgLootReveal') @(520, 293, 240, 40))  # '발견한 전리품' 라벨 영역
# 우상단 재화 표시줄(골드 + 은동전): 마지막 숫자 그룹이 은동전 잔량입니다 (실측 검증됨)
$rgDgCoinBalance = @(Get-ConfigValue $config @('ocrRegions', 'dgCoinBalance') @(1040, 52, 225, 34))   # 2026-07-17 확장: 결과 화면은 재화 바가 우측 끝까지 밀려 175 폭으론 은동전 숫자가 잘림 (실측)
# '입장하기' 버튼의 공물(은동전) 소모량 표시: 소탕만 10 / 더블 루팅까지 20.
# 아이콘+'입장하기' 텍스트까지 함께 읽어야 숫자가 안정적으로 잡힘 (실측 검증됨).
# 하단 버튼이 '파티 찾기'+'입장하기' 2버튼 ↔ 넓은 단일 '입장하기'로 바뀌면 숫자 위치도
# 좌우로 움직이므로, 두 레이아웃을 모두 덮는 넓은 영역을 씁니다 (두 레이아웃 실측 검증됨)
$rgDgTributeCost = @(Get-ConfigValue $config @('ocrRegions', 'dgTributeCost') @(840, 636, 290, 44))

# 행동불능(사망) 자동 부활: 던전 클리어 대기 중 화면 중앙의 '남은 부활 횟수' 안내가
# 보이면(=행동불능 상태), 남은 횟수가 있을 때 R키(여기서 부활)를 눌러 전투를 이어갑니다.
$reviveEnabled     = Get-ConfigBoolean $config @('revive', 'enabled') $true
$reviveKey         = Get-ConfigInteger $config @('revive', 'key') 82 1 255    # 82 = R ('여기서 부활' 단축키)
$reviveMaxPerCycle = Get-ConfigInteger $config @('revive', 'maxPerCycle') 10 0 1000
# 부활 완료 후 전투를 다시 시작하는 키: 부활하면 자동전투가 꺼진 상태라 자동출발(Space)을
# 다시 눌러야 전투가 이어집니다. 0 을 넣으면 누르지 않습니다.
$reviveResumeKey   = Get-ConfigInteger $config @('revive', 'resumeKey') 32 0 255   # 32 = Space
# 행동불능 안내 영역: '행동불능 / 부활 제한 구역입니다 / 남은 부활 횟수 N/M' 문구가 표시되는 화면 중앙
$rgDeathStatus     = @(Get-ConfigValue $config @('ocrRegions', 'deathStatus') @(500, 160, 290, 120))
# 남은 부활 횟수가 없을 때 클릭할 '여신상에서 부활' 버튼 위치(OCR 탐색 실패 시 예비 좌표)
$ptStatueRevive    = @(Get-ConfigValue $config @('clickPoints', 'statueRevive') @(968, 610))
# 파티 전멸('전멸하였습니다') 화면의 '여신상에서 부활' 버튼 예비 좌표 - 세이브 지점 재도전.
# 개인 행동불능 화면과 버튼 배치가 달라 별도 좌표 (2026-07-28 오류 캡처 실측: '여신상에서' 중심)
$ptWipeStatueRevive = @(Get-ConfigValue $config @('clickPoints', 'wipeStatueRevive') @(986, 670))
# 부활 버튼들이 표시되는 우하단 영역: 버튼 배치가 남은 횟수에 따라 달라지므로
# 이 영역 안에서 '여신상' 글자를 OCR로 찾아 실제 위치를 클릭합니다.
$rgReviveButtons   = @(Get-ConfigValue $config @('ocrRegions', 'reviveButtons') @(700, 570, 555, 135))
# 우하단 자동사냥 버튼의 아이콘 중심 좌표(클릭용 아님, 상태 판별용).
# 꺼짐 = 나침반 아이콘(중심에 검은 점) / 켜짐 = 흰 사각형(정지 아이콘) → 픽셀로 구분합니다.
$ptAutoHuntIcon    = @(Get-ConfigValue $config @('clickPoints', 'autoHuntIcon') @(1192, 637))
# ASSIST(어시스트 모드) 자동 켜기 (2026-07-28 사용자 요청·실측): 전투 HUD 우측 ASSIST
# 토글이 꺼져 있으면 H키로 켭니다. 좌표는 토글 필의 기준점(클릭용 아님, 상태 판별용).
$assistAutoOn      = Get-ConfigBoolean $config @('assist', 'autoEnable') $true
$assistKey         = Get-ConfigInteger $config @('assist', 'key') 72 1 255   # 72 = H (ASSIST 토글)
$ptAssistToggle    = @(Get-ConfigValue $config @('clickPoints', 'assistToggle') @(1216, 513))

$refocusEverySeconds = Get-ConfigInteger $config @('focus', 'refocusEverySeconds') 8 0 3600
$refocusIdleSeconds  = Get-ConfigInteger $config @('focus', 'onlyWhenUserIdleSeconds') 15 0 3600

$windowNormalize = Get-ConfigBoolean $config @('window', 'normalize') $true
$windowMode      = [string](Get-ConfigValue $config @('window', 'mode') 'nearest')
$windowX         = Get-ConfigInteger $config @('window', 'x') 0 -32768 32767
$windowY         = Get-ConfigInteger $config @('window', 'y') 0 -32768 32767
$windowWidth     = Get-ConfigInteger $config @('window', 'width') 1908 640 7680
$windowHeight    = Get-ConfigInteger $config @('window', 'height') 1076 360 4320

$afterEntryDelayMs = Get-ConfigInteger $config @('afterEntry', 'keyDelayMs') 500 0 60000

# 입장 후 누를 키 목록을 해석합니다. 새 형식({key, label, enabled})과
# 예전 형식(숫자 목록 + keyLabels)을 모두 지원하며, enabled=false 인 키는 건너뜁니다.
$rawAfterEntryKeys = @(Get-ConfigValue $config @('afterEntry', 'keys') @())
$legacyKeyLabels   = @(Get-ConfigValue $config @('afterEntry', 'keyLabels') @('자동출발', '음식 자동 먹기'))
if ($rawAfterEntryKeys.Count -eq 0) {
  $rawAfterEntryKeys = @(
    [pscustomobject]@{ key = 32; label = '자동출발'; enabled = $true },
    [pscustomobject]@{ key = 66; label = '음식 자동 먹기'; enabled = $true }
  )
}

$afterEntryActions = @()
for ($entryIndex = 0; $entryIndex -lt $rawAfterEntryKeys.Count; $entryIndex++) {
  $entry = $rawAfterEntryKeys[$entryIndex]
  if ($entry -is [System.Management.Automation.PSCustomObject] -and $entry.PSObject.Properties['key']) {
    $entryEnabled = $true
    if ($entry.PSObject.Properties['enabled'] -and $null -ne $entry.enabled) {
      $entryEnabled = Resolve-ConfigBoolean -Value $entry.enabled -Default $true `
        -Name "afterEntry.keys[$entryIndex].enabled"
    }
    if (-not $entryEnabled) { continue }
    $entryLabel = '키 입력'
    if ($entry.PSObject.Properties['label'] -and $entry.label) { $entryLabel = [string]$entry.label }
    $entryKey = Resolve-ConfigInteger -Value $entry.key -Default 0 -Minimum 1 -Maximum 255 `
      -Name "afterEntry.keys[$entryIndex].key"
    if ($entryKey -gt 0) { $afterEntryActions += @{ Key = $entryKey; Label = $entryLabel } }
  } else {
    $entryLabel = '키 입력'
    if ($entryIndex -lt $legacyKeyLabels.Count -and $legacyKeyLabels[$entryIndex]) {
      $entryLabel = [string]$legacyKeyLabels[$entryIndex]
    }
    $entryKey = Resolve-ConfigInteger -Value $entry -Default 0 -Minimum 1 -Maximum 255 `
      -Name "afterEntry.keys[$entryIndex]"
    if ($entryKey -gt 0) { $afterEntryActions += @{ Key = $entryKey; Label = $entryLabel } }
  }
}

# 로그/신호 폴더는 실행 위치와 무관하게 %LOCALAPPDATA%\HoneyNogi\Log 로 통일합니다
# (2026-08-05 사용자 결정). exe 는 스크립트가 원래 그 폴더에 풀려 실행되므로 경로가 그대로라
# 기존 사용자 영향이 없고, 저장소에서 직접 돌리는 개발/실기 로그도 같은 곳에 모입니다.
# LOCALAPPDATA 를 못 얻는 비정상 환경만 기존처럼 스크립트 옆 Log 로 폴백 (런처와 같은 가드).
$honeyLogBase = [string][Environment]::GetFolderPath('LocalApplicationData')
if ([string]::IsNullOrWhiteSpace($honeyLogBase)) {
  $logDir = Join-Path $PSScriptRoot 'Log'
} else {
  $logDir = Join-Path $honeyLogBase 'HoneyNogi\Log'
}
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logPath = Join-Path $logDir 'mabinogi_run_once.log'
$logRecoveryPath = Join-Path $logDir 'mabinogi_run_once.recovery.log'
# 안전 중지 신호 파일: 컨트롤 패널에서 '안전 중지'를 누르면 생성됩니다.
# 이 파일이 있으면 던전에서 나와 밖(HUD)이 확인된 시점에서 회차를 조기 종료합니다.
$safeStopFlagPath = Join-Path $logDir 'safe_stop.flag'

# 원격 데스크톱 창 최소화 등으로 화면 캡처가 안 되는 동안 true가 되는 상태 플래그입니다.
# 이 동안에는 각 대기 단계의 제한 시간이 흐르지 않습니다(화면 복구 후 이어서 감지).
$script:screenCaptureFailing = $false
# 캡처 실패 중 마지막으로 안내한 원인 문구/원인 종류입니다. 실패 도중 원인이 바뀌면
# (예: 최소화 → RDP 연결 끊김) 새 원인을 한 번 더 안내하고, 복구 시에는 기억해 둔
# 원인에 맞춰 "어떻게 복구됐는지"(본체 전환/RDP 재개 등)를 로그에 남깁니다.
$script:captureFailMessage = $null
$script:captureFailCause = $null
# 캡처 실패가 '시작된 시각'입니다. 안전 중지 예약을 캡처 실패 대기 중에 소비하는 것은
# 실패가 충분히 오래(2분 이상) 지속되어 '영영 복구되지 않는 상황'으로 보일 때만 하기 위한 기준.
$script:captureFailingSince = $null
# 마지막으로 캡처에 성공했을 때의 세션 연결 이름입니다(예: 'rdp-tcp#3', 'console').
# RDP는 접속할 때마다 새 연결 이름이 되므로, 실패 시점에 이름이 바뀌어 있으면
# '창 최소화'(연결 유지, 이름 동일)가 아니라 'RDP 재접속 직후'로 판별합니다.
$script:lastGoodStationName = $null
# 현재 실행 중인 콘텐츠의 로그 접두어입니다. 공통 함수(클리어 대기, 토글 카드, 팝업 처리 등)의
# 로그가 어느 콘텐츠에서 나온 것인지 보이도록, 던전/사냥터 흐름 진입 시 각자 값으로 바꿉니다.
$script:contentTag = '[어비스]'
# 실패해도 진행하는 '확인 경고'(게임 전면화·커서 이동)의 반복 억제 상태입니다.
# 이 확인들은 클릭마다 호출되므로, 사용자가 PC를 쓰는 동안(다른 창이 전면) 같은 경고가
# 로그를 도배했습니다(2026-07-22 어비스 실주행 실측). 연속 실패 중에는 첫 1회만 남기고,
# 회복될 때 그 사이 억제한 횟수와 함께 한 번 더 안내해 진단 정보는 보존합니다.
$script:focusWarnActive = $false
$script:focusWarnSuppressed = 0
$script:cursorWarnActive = $false
$script:cursorWarnSuppressed = 0
$script:runLogWriter = $null
$script:runLogTargetPath = $null
$script:runLogUsingRecovery = $false
$script:runLogHeader = $null
$script:runLogOpenAttempts = 20
$script:runLogRetryDelayMs = 50

function Close-RunLogWriter {
  if ($null -ne $script:runLogWriter) {
    try { $script:runLogWriter.Flush() } catch {}
    try { $script:runLogWriter.Dispose() } catch {}
  }
  $script:runLogWriter = $null
  $script:runLogTargetPath = $null
}

function Open-RunLogWriter {
  param(
    [string]$Path,
    [System.IO.FileMode]$Mode
  )

  for ($attempt = 0; $attempt -lt $script:runLogOpenAttempts; $attempt++) {
    $stream = $null
    try {
      # 워커가 먼저 공유 쓰기 스트림을 유지하면, 나중에 실행된 tail 등 읽기 도구가
      # 쓰기를 막는 방식으로 파일을 열 수 없습니다. GUI의 공유 읽기와 파일 보관은 허용합니다.
      $share = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
      $stream = New-Object System.IO.FileStream($Path, $Mode, [System.IO.FileAccess]::Write, $share)
      $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding($true)))
      $writer.AutoFlush = $true
      return $writer
    } catch {
      if ($null -ne $stream) { try { $stream.Dispose() } catch {} }
      if ($attempt + 1 -lt $script:runLogOpenAttempts -and $script:runLogRetryDelayMs -gt 0) {
        Start-Sleep -Milliseconds $script:runLogRetryDelayMs
      }
    }
  }
  return $null
}

function Initialize-RunLog {
  param([switch]$Reset)

  Close-RunLogWriter
  $script:runLogUsingRecovery = $false
  if ($Reset -or [string]::IsNullOrWhiteSpace($script:runLogHeader)) {
    $script:runLogHeader = "[$(Get-Date -Format 'yyyy-MM-dd')] 자동화 로그 (시작 $(Get-Date -Format 'HH:mm:ss'))"
  }

  $mode = if ($Reset) { [System.IO.FileMode]::Create } else { [System.IO.FileMode]::Append }
  $writer = Open-RunLogWriter -Path $logPath -Mode $mode
  if ($null -eq $writer) {
    $writer = Open-RunLogWriter -Path $logRecoveryPath -Mode $mode
    if ($null -eq $writer) {
      throw "기본 로그와 복구 로그를 모두 열 수 없습니다: '$logPath', '$logRecoveryPath'"
    }
    $script:runLogUsingRecovery = $true
    $script:runLogTargetPath = $logRecoveryPath
  } else {
    $script:runLogTargetPath = $logPath
  }
  $script:runLogWriter = $writer

  if ($Reset) { $script:runLogWriter.WriteLine($script:runLogHeader) }
  if ($script:runLogUsingRecovery) {
    $warningLine = "$(Get-Date -Format 'HH:mm:ss') [경고] 기본 로그 파일이 다른 프로그램에 잠겨 복구 로그(mabinogi_run_once.recovery.log)로 기록합니다"
    $script:runLogWriter.WriteLine($warningLine)
    Write-Host $warningLine -ForegroundColor Yellow
  }
}

function Write-RunLog {
  param([string]$Message)
  # 날짜는 로그 맨 위 헤더에 한 번만 기록하고, 각 줄에는 시각만 붙입니다.
  $line = "$(Get-Date -Format 'HH:mm:ss') $Message"
  if ($null -eq $script:runLogWriter) { Initialize-RunLog }

  try {
    $script:runLogWriter.WriteLine($line)
  } catch {
    $primaryError = $_.Exception.Message
    $failedPath = $script:runLogTargetPath
    Close-RunLogWriter
    if ($script:runLogUsingRecovery) {
      throw "복구 로그 기록에도 실패했습니다('$failedPath'): $primaryError"
    }

    # 디스크/외부 프로그램 문제로 열린 기본 스트림 자체가 실패하면, 실패한 줄부터 복구 로그에
    # 이어 적습니다. 중복 가능성보다 누락 방지를 우선하며 이후 줄도 같은 스트림을 사용합니다.
    $script:runLogUsingRecovery = $true
    $recoveryWriter = Open-RunLogWriter -Path $logRecoveryPath -Mode ([System.IO.FileMode]::Create)
    if ($null -eq $recoveryWriter) {
      throw "기본 로그 기록 실패 후 복구 로그도 열 수 없습니다('$failedPath'): $primaryError"
    }
    $script:runLogWriter = $recoveryWriter
    $script:runLogTargetPath = $logRecoveryPath
    $script:runLogWriter.WriteLine($script:runLogHeader)
    $warningLine = "$(Get-Date -Format 'HH:mm:ss') [경고] 기본 로그 기록 중 오류가 발생해 복구 로그(mabinogi_run_once.recovery.log)로 전환했습니다: $primaryError"
    $script:runLogWriter.WriteLine($warningLine)
    $script:runLogWriter.WriteLine($line)
    Write-Host $warningLine -ForegroundColor Yellow
  }
  Write-Host $line
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdministrator) {
  if (-not [string]::IsNullOrWhiteSpace($env:HONEYNOGI_CUSTOM_ITEM)) {
    # ShellExecute(RunAs) 재실행에는 GUI가 세팅한 HONEYNOGI_* 환경변수가 승계되지 않을 수
    # 있습니다. 커스텀 항목이 조용히 무시된 채 normalDungeon 설정으로 돌면 오계상 사고라
    # 흔적을 남깁니다 (GUI가 관리자로 떠 있으면 이 경로 자체가 실행되지 않음).
    Write-RunLog '[경고] 커스텀 반복 항목이 전달된 상태에서 관리자 권한 재실행이 필요합니다 - 재실행에는 커스텀 정보가 승계되지 않을 수 있으니 꿀비노기(GUI)를 관리자 권한으로 실행해 주세요'
  }
  $quotedScript = '"' + $PSCommandPath + '"'
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Normal -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $quotedScript
  )
  exit
}

# 중복 실행 방지: 이미 다른 자동화 인스턴스가 돌고 있으면 이 인스턴스는 바로 종료합니다.
# (컨트롤러 없이 떠도는 워커가 게임을 계속 조작하는 사고를 막습니다)
$script:instanceMutex = New-Object System.Threading.Mutex($false, 'Global\HoneyNogiRunOnce')
if (-not $script:instanceMutex.WaitOne(0)) {
  Write-RunLog '[중단] 이미 다른 자동화 인스턴스가 실행 중이라 이 실행을 취소합니다.'
  Write-Host '이미 다른 자동화가 실행 중입니다. 3초 후 이 창을 닫습니다.' -ForegroundColor Red
  Start-Sleep -Seconds 3
  exit 2
}

Initialize-RunLog -Reset
$Host.UI.RawUI.WindowTitle = '꿀비노기'
Write-Host '꿀비노기(마비노기 모바일 자동화)를 시작합니다.' -ForegroundColor Cyan
Write-Host '진행 상황은 이 창과 Log 폴더의 실행 로그에 기록됩니다.' -ForegroundColor DarkGray
foreach ($configWarning in @($script:configValidationWarnings)) {
  Write-RunLog "[경고] $configWarning"
}

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null

$asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() |
  Where-Object {
    $_.Name -eq 'AsTask' -and
    $_.IsGenericMethod -and
    $_.GetParameters().Count -eq 1
  } |
  Select-Object -First 1

$ocrKoreanLanguage = New-Object Windows.Globalization.Language('ko')
$ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($ocrKoreanLanguage)
$ocrEnglishLanguage = New-Object Windows.Globalization.Language('en-US')
$ocrEnglishEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($ocrEnglishLanguage)

# 화면 감지가 전부 OCR 기반입니다. 한국어 OCR은 필수이고(감지 문구 대부분이 한국어),
# 영어 OCR은 Home/End/ESC 버튼 감지의 정확도를 높여 주는 선택 사항입니다 - 없어도
# 한국어 OCR이 영문을 읽을 수 있어(실측: 'HomeESC'로 판독됨) 그걸로 대체 진행합니다.
if (-not $ocrKoreanEngine) {
  # 한국어 OCR이 없는 드문 경우(한국어가 아닌 Windows)만 설치를 기다립니다.
  # dism.exe로 설치하면 출력에 진행률(%)이 찍히므로 10초마다 읽어 진행 로그를 남깁니다.
  # 종료 코드 3010 = 성공 + 재부팅 필요. 30분 넘으면 대기만 중단(설치는 백그라운드 계속).
  Write-RunLog '[준비] 한국어 OCR이 이 PC에 없습니다 - 자동 설치를 시작합니다 (보통 10~15분)'
  $dismProc = $null
  $dismOut = $null
  try {
    $dismOut = Join-Path $env:TEMP "mabinogi_ocr_install_$PID.log"
    $dismProc = Start-Process -FilePath 'dism.exe' `
      -ArgumentList @('/Online', '/Add-Capability', '/CapabilityName:Language.OCR~~~ko-KR~0.0.1.0', '/NoRestart') `
      -WindowStyle Hidden -PassThru -RedirectStandardOutput $dismOut
    $null = $dismProc.Handle   # Handle을 미리 캐시해야 종료 후 ExitCode를 읽을 수 있음 (PS 함정 - 실측)
    $elapsedSec = 0
    $lastLoggedPct = ''
    $lastLogSec = 0
    while (-not $dismProc.HasExited) {
      Start-Sleep -Seconds 10
      $elapsedSec += 10
      if ($elapsedSec -ge 1800) {
        # 30분 초과: dism 클라이언트는 중단하지만, 실제 설치(TrustedInstaller)는
        # 백그라운드에서 계속돼 나중에 완료되는 경우가 많습니다 (실측 확인).
        try { $dismProc.Kill(); $dismProc.WaitForExit() } catch { }
        throw '설치가 30분을 넘겨 대기를 중단했습니다 - Windows가 백그라운드에서 설치를 이어갈 수 있으니 10분쯤 뒤 [시작]을 다시 눌러 보세요'
      }
      # dism 출력 파일에서 마지막 진행률(%)을 읽습니다 (쓰는 중이라 공유 읽기로 열기)
      $pctText = ''
      try {
        # 읽기 도중 예외가 나도 핸들이 남지 않도록 finally 에서 해제합니다
        # (StreamReader.Dispose 가 내부 FileStream 까지 닫으므로 sr 우선, 없으면 fs)
        $fs = $null; $sr = $null
        try {
          $fs = New-Object System.IO.FileStream($dismOut, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
          $sr = New-Object System.IO.StreamReader($fs)
          $dismText = $sr.ReadToEnd()
        } finally {
          if ($sr) { $sr.Dispose() } elseif ($fs) { $fs.Dispose() }
        }
        $pctMatches = [regex]::Matches($dismText, '(\d{1,3}(?:\.\d)?)\s*%')
        if ($pctMatches.Count -gt 0) { $pctText = " $($pctMatches[$pctMatches.Count - 1].Groups[1].Value)%" }
      } catch { }
      # 진행률이 바뀌면 10초마다 바로 기록하고, 정체 중에는 60초마다만 기록해
      # 긴 설치에서 같은 줄이 수백 개 쌓이지 않게 합니다.
      if (-not $dismProc.HasExited) {
        if (($pctText -and $pctText -ne $lastLoggedPct) -or (($elapsedSec - $lastLogSec) -ge 60)) {
          Write-RunLog "[준비] 한국어 OCR 설치 진행 중...$pctText (경과 $([Math]::Floor($elapsedSec / 60))분 $($elapsedSec % 60)초)"
          $lastLoggedPct = $pctText
          $lastLogSec = $elapsedSec
        }
      }
    }
    $dismCode = $null
    try { $dismCode = $dismProc.ExitCode } catch { }
    if ($null -eq $dismCode) {
      # 종료 코드를 못 읽는 경우가 있어(실측), 실패로 단정하지 않고 아래의 엔진
      # 재생성 결과로 설치 성공 여부를 판정합니다.
      Write-RunLog '[준비] 한국어 OCR 설치 프로세스 종료 (코드 확인 불가 - 설치 여부는 이어서 확인합니다)'
    } elseif ($dismCode -eq 3010) {
      Write-RunLog '[준비] 한국어 OCR 설치 완료 (Windows가 재부팅을 요청했습니다 - 인식이 안 되면 재부팅 후 다시 실행하세요)'
    } elseif ($dismCode -eq 0) {
      Write-RunLog '[준비] 한국어 OCR 설치 완료'
    } else {
      # 실패 원인 진단용으로 dism 출력의 마지막 줄들을 함께 남깁니다
      $dismTail = ''
      try {
        $dismTail = ((Get-Content -LiteralPath $dismOut | Where-Object { $_.Trim() } | Select-Object -Last 3) -join ' / ')
      } catch { }
      throw "dism 설치 실패 (종료 코드 $dismCode)$(if ($dismTail) { " - $dismTail" })"
    }
    Remove-Item -LiteralPath $dismOut -Force -ErrorAction SilentlyContinue
  } catch {
    Write-RunLog "[경고] 한국어 OCR 자동 설치 실패: $($_.Exception.Message)"
  } finally {
    if ($dismProc) {
      try { $dismProc.Dispose() } catch { }
      $dismProc = $null
    }
  }
  $ocrKoreanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($ocrKoreanLanguage)
}
if (-not $ocrKoreanEngine) {
  # (이 검사는 메인 try/catch 밖이라, 이유를 로그에 남기고 명시적으로 종료합니다)
  $installedOcr = ''
  try { $installedOcr = ([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | ForEach-Object { $_.LanguageTag }) -join ', ' } catch { }
  Write-RunLog "[오류] 한국어 OCR을 사용할 수 없습니다 $(if ($installedOcr) { "(설치된 OCR 언어: $installedOcr)" } else { '(설치된 OCR 언어 없음)' })"
  Write-RunLog "[안내] 방금 자동 설치가 진행됐다면 Windows가 백그라운드에서 마무리 중일 수 있습니다 - 5~10분 뒤 [시작]을 다시 눌러 보고, 그래도 안 되면 재부팅 후 다시 실행하세요"
  Write-RunLog "[안내] 자동 설치가 실패했다면(인터넷 없음 등): 설정 > 시간 및 언어 > 언어 및 지역 > '언어 추가'에서 '한국어'를 설치하세요"
  exit 1
}
if (-not $ocrEnglishEngine) {
  # 영어 OCR은 기다리지 않습니다: 백그라운드로 설치만 걸어 두고 이번 실행은 한국어
  # OCR로 대체해 바로 시작합니다 (설치가 끝나면 다음 실행부터 영어 OCR을 사용).
  # Windows가 같은 기능 설치를 직렬화하므로 여러 번 걸어도 실제 설치는 한 번만 됩니다.
  # 설치 상태를 확인해 상황에 맞는 안내를 남깁니다 (설치됨/진행 중/미설치 구분).
  try {
    $enCapState = $null
    try { $enCapState = [string](Get-WindowsCapability -Online -Name 'Language.OCR~~~en-US~0.0.1.0' -ErrorAction Stop).State } catch { }
    if ($enCapState -match 'Installed') {
      Write-RunLog '[준비] 영어 OCR 설치는 끝났지만 아직 반영 전입니다 (다음 실행 또는 재부팅 후 적용) - 이번 실행은 한국어 OCR로 대체해 진행합니다'
    } elseif (Get-Process -Name 'dism' -ErrorAction SilentlyContinue) {
      Write-RunLog '[준비] 영어 OCR 백그라운드 설치가 진행 중입니다 (중복 설치 아님) - 이번 실행은 한국어 OCR로 대체해 진행합니다'
    } else {
      Start-Process -FilePath 'dism.exe' `
        -ArgumentList @('/Online', '/Add-Capability', '/CapabilityName:Language.OCR~~~en-US~0.0.1.0', '/NoRestart') `
        -WindowStyle Hidden | Out-Null
      Write-RunLog '[준비] 영어 OCR이 없어 백그라운드 설치를 걸어 두고, 이번 실행은 한국어 OCR로 대체해 바로 진행합니다'
    }
  } catch {
    Write-RunLog '[준비] 영어 OCR이 없습니다 - 한국어 OCR로 대체해 진행합니다'
  }
  $ocrEnglishEngine = $ocrKoreanEngine
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class HoneyNogiInput {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }

  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int command);

  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();

  [DllImport("user32.dll")]
  public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);

  [DllImport("user32.dll")]
  public static extern bool SetCursorPos(int x, int y);

  [DllImport("user32.dll")]
  public static extern bool GetCursorPos(out POINT point);

  [DllImport("user32.dll")]
  public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);

  [DllImport("user32.dll")]
  public static extern bool SetProcessDPIAware();

  [DllImport("user32.dll")]
  public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

  [DllImport("user32.dll")]
  public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);

  [DllImport("user32.dll")]
  public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int width, int height, bool repaint);

  [DllImport("user32.dll")]
  public static extern int GetSystemMetrics(int index);

  [DllImport("user32.dll")]
  public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref RECT pvParam, uint fWinIni);

  [StructLayout(LayoutKind.Sequential)]
  public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }

  [DllImport("user32.dll")]
  public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

  [DllImport("kernel32.dll")]
  public static extern uint GetTickCount();

  [DllImport("kernel32.dll")]
  public static extern uint SetThreadExecutionState(uint esFlags);

  [StructLayout(LayoutKind.Sequential)]
  public struct POINT { public int X; public int Y; }

  [DllImport("user32.dll")]
  public static extern IntPtr WindowFromPoint(POINT point);

  [DllImport("user32.dll")]
  public static extern IntPtr GetAncestor(IntPtr hWnd, uint flags);

  [DllImport("user32.dll")]
  public static extern bool IsIconic(IntPtr hWnd);

  [DllImport("wtsapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern bool WTSQuerySessionInformation(IntPtr hServer, int sessionId, int wtsInfoClass, out IntPtr ppBuffer, out int pBytesReturned);

  [DllImport("wtsapi32.dll")]
  public static extern void WTSFreeMemory(IntPtr pMemory);
}
'@

# 디스플레이 배율(DPI) 대응: 창 좌표·클릭·캡처가 항상 "실제 픽셀"을 쓰도록 통일합니다.
# 모니터별 DPI 인식(V2)을 사용해야 실행 도중 배율이 바뀌어도(예: RDP 150% 세션이
# 본체 모니터 100%로 전환) 좌표계가 어긋나지 않습니다. 실패 시 구형 방식으로 폴백합니다.
$dpiContextSet = $false
try {
  $dpiContextSet = [HoneyNogiInput]::SetProcessDpiAwarenessContext([IntPtr](-4))
} catch { }
if (-not $dpiContextSet) {
  try {
    $threadContext = [HoneyNogiInput]::SetThreadDpiAwarenessContext([IntPtr](-4))
    $dpiContextSet = ($threadContext -ne [IntPtr]::Zero)
  } catch { }
}
if (-not $dpiContextSet) {
  [HoneyNogiInput]::SetProcessDPIAware() | Out-Null
}

# 화면 꺼짐/시스템 절전 방지: 감지가 화면 렌더링에 의존하므로, 자동화가 도는 동안
# 디스플레이가 꺼지지 않게 유지합니다. (원격 도구 접속을 끊은 뒤 유휴 시간으로
# 화면이 꺼지면서 캡처가 실패하는 것을 예방. 프로세스 종료 시 자동 해제됨)
# 2147483651 = 0x80000003 = ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
[HoneyNogiInput]::SetThreadExecutionState([uint32]2147483651) | Out-Null

function Get-GameProcess {
  # 프로세스가 아예 없으면 Get-Process가 먼저 예외를 던져 아래 한국어 안내가 묻히므로,
  # SilentlyContinue로 조회한 뒤 조치 방법이 담긴 메시지로 직접 알립니다.
  $process = Get-Process -Name 'MabinogiMobile' -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 } |
    Select-Object -First 1

  if (-not $process) {
    throw '마비노기 모바일 창을 찾지 못했습니다. 게임을 먼저 실행한 뒤 다시 시작해 주세요.'
  }
  return $process
}

function Get-TickElapsedMilliseconds {
  param([uint32]$CurrentTick, [uint32]$PreviousTick)
  # GetTickCount/LASTINPUTINFO.dwTime은 uint32라 약 49.7일마다 0으로 감깁니다.
  # 현재 값이 더 작으면 2^32를 더해 rollover 뒤의 실제 경과 시간을 계산합니다.
  if ($CurrentTick -ge $PreviousTick) {
    return ([uint64]$CurrentTick - [uint64]$PreviousTick)
  }
  return (([uint64]4294967296 + [uint64]$CurrentTick) - [uint64]$PreviousTick)
}

function Get-UserIdleSeconds {
  # 사용자의 마지막 키보드/마우스 입력 이후 경과 시간(초)을 반환합니다.
  $info = New-Object HoneyNogiInput+LASTINPUTINFO
  $info.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($info)
  if (-not [HoneyNogiInput]::GetLastInputInfo([ref]$info)) {
    return [double]::MaxValue
  }
  $elapsedMs = Get-TickElapsedMilliseconds -CurrentTick ([HoneyNogiInput]::GetTickCount()) `
    -PreviousTick $info.dwTime
  return [double]$elapsedMs / 1000.0
}

function Test-GameCovered {
  param([System.Diagnostics.Process]$Game)

  # 게임 창이 실제로 다른 창에 가려져 있는지 확인합니다.
  # 창 내부의 주요 지점(중앙, HUD 영역, 하단 문구 영역 등)에 어떤 창이 떠 있는지
  # WindowFromPoint 로 조사해서, 하나라도 게임이 아니면 "가려짐"으로 판단합니다.
  $gameHandle = $Game.MainWindowHandle
  if ([HoneyNogiInput]::IsIconic($gameHandle)) { return $true }

  $rect = New-Object HoneyNogiInput+RECT
  if (-not [HoneyNogiInput]::GetWindowRect($gameHandle, [ref]$rect)) { return $false }
  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  if ($width -le 0 -or $height -le 0) { return $false }

  # 확인 지점: 중앙 / 우상단(HUD) / 하단 중앙(클리어 문구) / 좌측 중앙
  $probes = @(
    @(0.50, 0.50), @(0.78, 0.12), @(0.50, 0.85), @(0.25, 0.50)
  )
  foreach ($probe in $probes) {
    $point = New-Object HoneyNogiInput+POINT
    $point.X = $rect.Left + [int]($width * $probe[0])
    $point.Y = $rect.Top + [int]($height * $probe[1])
    $hitWindow = [HoneyNogiInput]::WindowFromPoint($point)
    if ($hitWindow -eq [IntPtr]::Zero) { return $true }
    $rootWindow = [HoneyNogiInput]::GetAncestor($hitWindow, 2)  # GA_ROOT
    if ($rootWindow -ne $gameHandle) { return $true }
  }
  return $false
}

function Invoke-AutoRefocus {
  param([System.Diagnostics.Process]$Game)

  # 게임 창이 "실제로 가려져 있을 때만" 앞으로 가져옵니다.
  # (가려지지 않았다면 아무것도 하지 않으므로 불필요한 포커스 이동이 없습니다)
  # 또한 사용자가 PC를 조작 중이면(최근 입력 있음) 포커스를 뺏지 않고 건너뜁니다.
  # config.json: focus.onlyWhenUserIdleSeconds (0 = 유휴 검사 없이 진행)
  if (-not (Test-GameCovered -Game $Game)) {
    return $false
  }
  if ($refocusIdleSeconds -gt 0 -and (Get-UserIdleSeconds) -lt $refocusIdleSeconds) {
    return $false
  }
  Focus-Game -Game $Game
  return $true
}

function Test-GameForeground {
  param([System.Diagnostics.Process]$Game)
  $foreground = [HoneyNogiInput]::GetForegroundWindow()
  if ($foreground -eq [IntPtr]::Zero) { return $false }
  $root = [HoneyNogiInput]::GetAncestor($foreground, 2)  # GA_ROOT
  return ($root -eq $Game.MainWindowHandle)
}

function Get-RepeatWarnAction {
  # 실패해도 진행하는 '확인 경고'의 반복 억제 판정입니다. 클릭마다 호출되는 확인(전면화·커서)이
  # 실패 상태로 머물면 같은 줄이 로그를 채우므로, 연속 실패 중에는 첫 1회만 남기고 회복 시
  # 한 번 더 안내합니다. 반환: 'warn'(경고 기록) / 'recover'(회복 안내) / 'none'(기록 없음)
  param([bool]$WasWarned, [bool]$Failed)
  if ($Failed) {
    if ($WasWarned) { return 'none' }
    return 'warn'
  }
  if ($WasWarned) { return 'recover' }
  return 'none'
}

function Focus-Game {
  param([System.Diagnostics.Process]$Game)

  # SetForegroundWindow 반환값은 실제 결과와 어긋날 수 있어 신뢰하지 않고, 전면 루트 창을
  # 확인합니다. 첫 시도가 빗나가면 ALT 트릭을 포함해 한 번 더 시도하되 클릭 자체는 막지 않습니다.
  $focusOk = $false
  for ($focusTry = 1; $focusTry -le 2; $focusTry++) {
    [HoneyNogiInput]::ShowWindowAsync($Game.MainWindowHandle, 9) | Out-Null
    [HoneyNogiInput]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    try {
      Start-Sleep -Milliseconds 80
      [HoneyNogiInput]::SetForegroundWindow($Game.MainWindowHandle) | Out-Null
      Start-Sleep -Milliseconds 80
    } finally {
      [HoneyNogiInput]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    }
    Start-Sleep -Milliseconds 350
    if (Test-GameForeground -Game $Game) { $focusOk = $true; break }
  }
  # 경고는 연속 실패의 첫 1회만 (사용자가 다른 창을 쓰는 동안 매 클릭마다 쌓이던 문제)
  switch (Get-RepeatWarnAction -WasWarned $script:focusWarnActive -Failed (-not $focusOk)) {
    'warn' {
      Write-RunLog '[경고] 게임 창 전면화를 두 번 시도했지만 실제 전면 루트 창으로 확인되지 않았습니다 - 기존 동작대로 입력은 계속합니다 (연속 실패 중에는 이 경고를 반복하지 않습니다)'
      $script:focusWarnActive = $true
      $script:focusWarnSuppressed = 0
    }
    'recover' {
      Write-RunLog "[안내] 게임 창 전면화 확인이 정상으로 돌아왔습니다 (그 사이 확인 실패 $($script:focusWarnSuppressed)회는 기록을 생략했습니다)"
      $script:focusWarnActive = $false
      $script:focusWarnSuppressed = 0
    }
    default { if (-not $focusOk) { $script:focusWarnSuppressed++ } }
  }
}

function Get-ScaledScreenPoint {
  param(
    [System.Diagnostics.Process]$Game,
    [int]$ReferenceX,
    [int]$ReferenceY
  )

  $rect = New-Object HoneyNogiInput+RECT
  if (-not [HoneyNogiInput]::GetWindowRect($Game.MainWindowHandle, [ref]$rect)) {
    throw '게임 창 좌표를 읽지 못했습니다.'
  }

  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  if ($width -lt 900 -or $height -lt 500) {
    throw "게임 창 크기가 너무 작습니다: ${width}x${height}"
  }

  return [System.Drawing.Point]::new(
    $rect.Left + [int][Math]::Round($ReferenceX * $width / $referenceWidth),
    $rect.Top + [int][Math]::Round($ReferenceY * $height / $referenceHeight)
  )
}

function Click-ScreenPoint {
  param([int]$X, [int]$Y)

  # SetCursorPos 뒤 실제 커서가 목표 ±3px 안인지 확인하고, 어긋나면 같은 지점으로 한 번 더
  # 이동합니다. 확인에 실패하면 클릭하지 않습니다 (2026-08-02 22:02 실사고: 사용자 마우스
  # 간섭으로 커서가 목표를 벗어난 채 클릭이 강행돼 재화줄을 오클릭 → '보유한 재화' 전체
  # 화면이 열려 클리어 대기가 가려짐. 이 프로젝트는 상태 기반 재확인 구조라 건너뛴 클릭은
  # 다음 감지에서 자연 재시도됨 - 리뷰 승인: 커서 미확인 시 클릭 금지, 좌표 폴백 금지).
  $cursorReady = $false
  for ($cursorTry = 1; $cursorTry -le 2; $cursorTry++) {
    [HoneyNogiInput]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds 80
    $cursorNow = New-Object HoneyNogiInput+POINT
    if ([HoneyNogiInput]::GetCursorPos([ref]$cursorNow) -and
        [Math]::Abs($cursorNow.X - $X) -le 3 -and [Math]::Abs($cursorNow.Y - $Y) -le 3) {
      $cursorReady = $true
      break
    }
  }
  # 경고는 연속 실패의 첫 1회만 (전면화 확인과 같은 억제 규칙 - Get-RepeatWarnAction)
  switch (Get-RepeatWarnAction -WasWarned $script:cursorWarnActive -Failed (-not $cursorReady)) {
    'warn' {
      Write-RunLog "[경고] 커서를 목표 위치(${X},${Y})로 두 번 이동했지만 실제 위치를 확인하지 못했습니다 - 오클릭 방지를 위해 이번 클릭을 건너뜁니다 (다음 감지에서 재시도. 연속 실패 중에는 이 경고를 반복하지 않습니다)"
      $script:cursorWarnActive = $true
      $script:cursorWarnSuppressed = 0
    }
    'recover' {
      Write-RunLog "[안내] 커서 위치 확인이 정상으로 돌아왔습니다 (그 사이 확인 실패 $($script:cursorWarnSuppressed)회는 기록을 생략했습니다)"
      $script:cursorWarnActive = $false
      $script:cursorWarnSuppressed = 0
    }
    default { if (-not $cursorReady) { $script:cursorWarnSuppressed++ } }
  }
  if (-not $cursorReady) { return }
  Start-Sleep -Milliseconds 250
  [HoneyNogiInput]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 100
  [HoneyNogiInput]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Click-GamePoint {
  param(
    [System.Diagnostics.Process]$Game,
    [int]$ReferenceX,
    [int]$ReferenceY
  )

  $point = Get-ScaledScreenPoint -Game $Game -ReferenceX $ReferenceX -ReferenceY $ReferenceY
  Click-ScreenPoint -X $point.X -Y $point.Y
}

function Get-GamePixel {
  param(
    [System.Diagnostics.Process]$Game,
    [int]$ReferenceX,
    [int]$ReferenceY
  )

  $point = Get-ScaledScreenPoint -Game $Game -ReferenceX $ReferenceX -ReferenceY $ReferenceY
  $bitmap = New-Object System.Drawing.Bitmap 1, 1
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($point.X, $point.Y, 0, 0, $bitmap.Size)
    return $bitmap.GetPixel(0, 0)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

function Invoke-OcrOnBitmap {
  param(
    [System.Drawing.Bitmap]$Bitmap,
    $Engine
  )

  # 비트맵을 임시 PNG 파일 없이 메모리에서 곧바로 WinRT OCR로 넘깁니다.
  # (기존 경로: 캡처 → PNG 저장 → 파일 열기 → 디코드 → OCR. 이 경로를 제거해 OCR 호출당
  #  디스크 쓰기 1회와 비동기 왕복 2회가 사라짐. 동등성 실측: 6개 조합 텍스트 동일, 약 2배 빠름)
  # Format32bppArgb 의 메모리 배치(B,G,R,A)는 WinRT Bgra8 과 같아 그대로 복사하면 됩니다.
  $lockRect = New-Object System.Drawing.Rectangle(0, 0, $Bitmap.Width, $Bitmap.Height)
  $bmpData = $Bitmap.LockBits($lockRect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $byteCount = $bmpData.Stride * $bmpData.Height
    $pixelBytes = New-Object byte[] $byteCount
    [System.Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $pixelBytes, 0, $byteCount)
  } finally {
    $Bitmap.UnlockBits($bmpData)
  }
  $buffer = [System.Runtime.InteropServices.WindowsRuntime.WindowsRuntimeBufferExtensions]::AsBuffer($pixelBytes, 0, $byteCount)
  $softwareBitmap = [Windows.Graphics.Imaging.SoftwareBitmap]::CreateCopyFromBuffer($buffer, [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8, $Bitmap.Width, $Bitmap.Height)
  try {
    return (Await-WinRt ($Engine.RecognizeAsync($softwareBitmap)) ([Windows.Media.Ocr.OcrResult]))
  } finally {
    $softwareBitmap.Dispose()
  }
}

function Await-WinRt {
  param($Operation, [Type]$ResultType)

  $task = $asTaskMethod.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
  $task.Wait()
  return $task.Result
}

function Get-SessionConnectState {
  # 자동화가 돌고 있는 현재 세션의 연결 상태를 조회합니다.
  # 반환값: 0 = Active(사용 중), 4 = Disconnected(RDP 연결 끊김) 등 / 조회 실패 시 -1.
  # (RDP 창 '최소화'는 세션이 여전히 Active이고, RDP '종료/끊김'은 Disconnected가 됩니다)
  $buffer = [IntPtr]::Zero
  $bytes = 0
  try {
    # -1 = WTS_CURRENT_SESSION(현재 세션), 8 = WTSConnectState
    if ([HoneyNogiInput]::WTSQuerySessionInformation([IntPtr]::Zero, -1, 8, [ref]$buffer, [ref]$bytes)) {
      return [System.Runtime.InteropServices.Marshal]::ReadInt32($buffer)
    }
    return -1
  } catch {
    return -1
  } finally {
    if ($buffer -ne [IntPtr]::Zero) { [HoneyNogiInput]::WTSFreeMemory($buffer) }
  }
}

function Get-SessionStationName {
  # 현재 세션의 연결 이름(예: 'rdp-tcp#3', 'console')을 조회합니다. 조회 실패 시 $null.
  $buffer = [IntPtr]::Zero
  $bytes = 0
  try {
    # -1 = WTS_CURRENT_SESSION(현재 세션), 6 = WTSWinStationName
    if ([HoneyNogiInput]::WTSQuerySessionInformation([IntPtr]::Zero, -1, 6, [ref]$buffer, [ref]$bytes)) {
      return [System.Runtime.InteropServices.Marshal]::PtrToStringUni($buffer)
    }
    return $null
  } catch {
    return $null
  } finally {
    if ($buffer -ne [IntPtr]::Zero) { [HoneyNogiInput]::WTSFreeMemory($buffer) }
  }
}

function Get-CaptureFailInfo {
  # 화면 캡처 실패의 원인을 세션 상태로 구분해, 원인 종류(Cause)와 안내 문구(Message)를 돌려줍니다.
  # Cause 는 복구 시 "어떻게 복구됐는지" 문구를 고르는 데도 사용됩니다.
  $state = Get-SessionConnectState
  if ($state -eq 4) {
    return @{
      Cause   = 'disconnected'
      Message = '[경고] 화면 캡처 실패 - RDP 연결이 끊긴 상태입니다. 본체 화면 자동 전환을 기다립니다 (조치 불필요, 보통 몇 초 내 자동 복구).'
    }
  }
  # 4096 = SM_REMOTESESSION: 0이 아니면 현재 RDP 세션에서 실행 중
  if ([HoneyNogiInput]::GetSystemMetrics(4096) -ne 0) {
    # 재접속이 빠르면 '끊김' 상태가 감지 주기 사이에 지나가 관측되지 않습니다.
    # 이때는 연결 이름 변화로 구분합니다: 최소화는 연결이 유지되어 이름이 그대로이고,
    # 재접속은 새 연결이라 이름이 바뀝니다(예: console → rdp-tcp#4).
    $station = Get-SessionStationName
    if ($script:lastGoodStationName -and $station -and $station -ne $script:lastGoodStationName) {
      return @{
        Cause   = 'reconnecting'
        Message = '[안내] RDP 재접속이 진행 중입니다. 잠시 후 자동으로 이어집니다.'
      }
    }
    return @{
      Cause   = 'minimized'
      Message = '[경고] 화면 캡처 실패 - RDP 창이 최소화된 것으로 보입니다. RDP 창을 다시 열어 주세요. 복구를 기다립니다.'
    }
  }
  return @{
    Cause   = 'other'
    Message = '[경고] 화면 캡처 실패 - 화면이 그려지지 않고 있습니다. 모니터 꺼짐/화면 잠금 여부를 확인해 주세요. 복구를 기다립니다.'
  }
}

function Get-CaptureRecoveryMessage {
  # 실패 원인과 '복구된 시점'의 세션 상태를 조합해, 어떻게 복구됐는지까지 안내합니다.
  # (예: RDP 종료 후 복구 = 본체 화면 전환 완료 / 최소화 후 복구 = RDP 창 다시 열림)
  param([string]$FailCause)

  $isRemoteNow = ([HoneyNogiInput]::GetSystemMetrics(4096) -ne 0)
  switch ($FailCause) {
    'disconnected' {
      if ($isRemoteNow) {
        return '[안내] RDP 재접속이 확인되어 화면 캡처가 복구됐습니다. 감지를 계속합니다.'
      }
      return '[안내] 본체 화면 자동 전환 완료 - 화면 캡처가 복구되어 감지를 계속합니다.'
    }
    'minimized' {
      if ($isRemoteNow) {
        return '[안내] RDP 창이 다시 열려 화면 캡처가 복구됐습니다. 감지를 계속합니다.'
      }
      # 최소화 경고 직후 사용자가 RDP를 닫아, 끊김 감지 전에 본체 전환까지 끝난 경우
      return '[안내] 본체 화면 자동 전환 완료 - 화면 캡처가 복구되어 감지를 계속합니다.'
    }
    'reconnecting' {
      return '[안내] RDP 재접속이 확인되어 화면 캡처가 복구됐습니다. 감지를 계속합니다.'
    }
    default {
      return '[안내] 화면 캡처가 복구되어 감지를 계속합니다.'
    }
  }
}

function Test-DesktopRenderingAlive {
  # 화면 렌더링이 실제로 살아 있는지 바탕화면 전체에서 띄엄띄엄 픽셀을 표본 조사합니다.
  # 게임의 OCR 영역이 전부 검을 때(던전 로딩 화면 등 '진짜 검은 장면'), 렌더링 중단
  # (RDP 최소화)과 구분하는 용도입니다. 로딩 화면이어도 작업표시줄/다른 창 등
  # 화면 어딘가에는 색이 있으므로, 표본에 색이 하나라도 있으면 렌더링은 정상입니다.
  $w = [HoneyNogiInput]::GetSystemMetrics(0)   # SM_CXSCREEN
  $h = [HoneyNogiInput]::GetSystemMetrics(1)   # SM_CYSCREEN
  if ($w -le 0 -or $h -le 0) { return $false }
  $bmp = New-Object System.Drawing.Bitmap 1, 1
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    foreach ($fx in 0.1, 0.5, 0.9) {
      foreach ($fy in 0.05, 0.5, 0.97) {
        $x = [int]($w * $fx)
        $y = [int]($h * $fy)
        try { $g.CopyFromScreen($x, $y, 0, 0, $bmp.Size) } catch { continue }
        $c = $bmp.GetPixel(0, 0)
        if ($c.R -ne 0 -or $c.G -ne 0 -or $c.B -ne 0) { return $true }
      }
    }
    return $false
  } finally {
    $g.Dispose()
    $bmp.Dispose()
  }
}

function Test-BlankCapture {
  # 원격 데스크톱 창 최소화 등으로 화면이 그려지지 않으면, CopyFromScreen 이 예외 없이
  # '검게 비어 있는' 프레임을 돌려줄 때가 있습니다. 실제 게임 화면은 표본 픽셀이 전부
  # 순수 검정(0,0,0)일 수 없으므로, 그런 경우 '빈 캡처(=실패)'로 판단합니다.
  # (표본이 하나라도 검정이 아니면 정상 캡처로 보아, 정상 화면을 실패로 오판하지 않습니다.)
  param([System.Drawing.Bitmap]$Bitmap)

  $w = $Bitmap.Width
  $h = $Bitmap.Height
  if ($w -le 0 -or $h -le 0) { return $true }

  $stepX = [Math]::Max(1, [int]($w / 8))
  $stepY = [Math]::Max(1, [int]($h / 8))
  for ($y = 0; $y -lt $h; $y += $stepY) {
    for ($x = 0; $x -lt $w; $x += $stepX) {
      $c = $Bitmap.GetPixel($x, $y)
      if ($c.R -ne 0 -or $c.G -ne 0 -or $c.B -ne 0) {
        return $false
      }
    }
  }
  return $true
}

function Register-CaptureFailure {
  # 캡처 실패(예외/렌더링 멈춤)를 공용 상태로 기록합니다. 어떤 캡처 경로(영역 OCR,
  # 글자 위치 탐색)든 같은 상태를 공유해야 대기 루프의 '실패 중 시간 동결'이 정확히 동작합니다.
  # 경고는 실패가 '시작'될 때 한 번만 남기되, 원인을 세션 상태로 구분해 안내합니다
  # (RDP 연결 끊김 / RDP 창 최소화 / 그 외). 실패 도중 원인이 바뀌면 한 번 더 안내합니다.
  $failInfo = Get-CaptureFailInfo
  # 'RDP 끊김' 실패가 이어지던 중 세션이 다시 RDP 활성으로 바뀌면, 창 최소화가 아니라
  # 사용자가 RDP로 재접속하는 중입니다(끊김에서 RDP 활성으로 가는 경로는 재접속뿐).
  # 재접속 완료 직전 1~2초의 렌더링 공백을 '최소화'로 잘못 안내하지 않도록 구분합니다.
  if ($script:screenCaptureFailing -and
      ($script:captureFailCause -eq 'disconnected' -or $script:captureFailCause -eq 'reconnecting') -and
      $failInfo.Cause -eq 'minimized') {
    $failInfo = @{
      Cause   = 'reconnecting'
      Message = '[안내] RDP 재접속이 진행 중입니다. 잠시 후 자동으로 이어집니다.'
    }
  }
  if (-not $script:screenCaptureFailing) {
    # 이번 실패 구간이 언제 시작됐는지 기록 (안전 중지 조기 소비 판단 기준)
    $script:captureFailingSince = Get-Date
  }
  if (-not $script:screenCaptureFailing -or $failInfo.Message -ne $script:captureFailMessage) {
    $script:screenCaptureFailing = $true
    $script:captureFailMessage = $failInfo.Message
    $script:captureFailCause = $failInfo.Cause
    Write-RunLog $failInfo.Message
  }
}

function Register-CaptureSuccess {
  # 정상 캡처 성공을 공용 상태로 기록합니다. 실패 중이었다면 복구 로그를 남기고,
  # 세션 연결 이름을 추적해 끊김 없는 전환(RDP 재접속/본체 전환)도 한 줄 안내합니다.
  # (빈 화면으로 인한 헛복구/로그 반복을 막기 위해, 실제 정상 화면을 받은 경로에서만 호출)
  $justRecovered = $false
  if ($script:screenCaptureFailing) {
    $script:screenCaptureFailing = $false
    Write-RunLog (Get-CaptureRecoveryMessage -FailCause $script:captureFailCause)
    $script:captureFailMessage = $null
    $script:captureFailCause = $null
    $script:captureFailingSince = $null
    $justRecovered = $true
  }
  # 캡처 성공 시 현재 연결 이름을 기억해 둡니다. 다음 실패 때 이 이름과 비교해
  # '최소화'(이름 유지)와 'RDP 재접속'(이름 변경)을 구분하는 기준이 됩니다.
  # 또한 캡처가 한 번도 끊기지 않을 만큼 매끄럽게 세션이 전환된 경우에도(실패 로그 없음)
  # 전환 사실을 한 줄 남깁니다. 방금 복구 로그를 남겼다면 중복 안내는 생략합니다.
  $currentStation = Get-SessionStationName
  if (-not $justRecovered -and $script:lastGoodStationName -and $currentStation -and
      $currentStation -ne $script:lastGoodStationName) {
    if ($currentStation -like 'Console*') {
      Write-RunLog '[안내] 본체 화면 전환이 감지됐습니다 (캡처 중단 없음). 감지를 계속합니다.'
    } else {
      Write-RunLog '[안내] RDP 재접속이 감지됐습니다 (캡처 중단 없음). 감지를 계속합니다.'
    }
  }
  if ($currentStation) { $script:lastGoodStationName = $currentStation }
}

function Test-SafeStopDuringCaptureFail {
  # 캡처 실패로 대기가 길어지는 동안에도 '안전 중지' 예약을 확인합니다.
  # 화면이 영영 복구되지 않는 상황(RDP 미복구 등)에서도 사용자가 강제 종료 없이
  # 안전하게 끝낼 수단을 남기기 위한 것입니다.
  # 단, 짧은 순단(RDP 재접속 몇 초)에 발동하면 '회차 완료 후 중지'라는 안전 중지의
  # 원래 약속이 깨지므로, 실패가 2분 이상 이어질 때만 조기 종료합니다.
  if (-not (Test-Path -LiteralPath $safeStopFlagPath)) { return }
  if (-not $script:captureFailingSince) { return }
  if (((Get-Date) - $script:captureFailingSince).TotalSeconds -lt 120) { return }
  Remove-Item -LiteralPath $safeStopFlagPath -Force -ErrorAction SilentlyContinue
  Write-RunLog '[완료] 화면 캡처 실패가 2분 이상 지속 - 안전 중지 예약을 확인해 자동화를 마칩니다 (회차 미완료)'
  # 코드 0 이면 GUI/컨트롤러가 '회차 완료'로 세어 완료 횟수가 과다 계상되므로,
  # 던전을 끝내지 못한 이 경로는 '조건에 따른 정상 정지'(코드 4)로 종료합니다.
  exit 4
}

function Get-GameRegionCapture {
  param(
    [System.Diagnostics.Process]$Game,
    [int]$ReferenceX,
    [int]$ReferenceY,
    [int]$RegionWidth,
    [int]$RegionHeight,
    [int]$Scale = 3,
    [switch]$BinaryWhiteText,
    [switch]$ThrowOnWindowRectFailure
  )

  # OCR 텍스트/위치/단어 함수가 공통으로 쓰는 캡처·빈 프레임 판정·확대 경로입니다.
  # 성공 시 반환된 Bitmap은 호출자가 반드시 Dispose해야 합니다.
  $rect = New-Object HoneyNogiInput+RECT
  if (-not [HoneyNogiInput]::GetWindowRect($Game.MainWindowHandle, [ref]$rect)) {
    if ($ThrowOnWindowRectFailure) { throw 'OCR용 게임 창 좌표를 읽지 못했습니다.' }
    return $null
  }

  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  $cropLeft = $rect.Left + [int][Math]::Round($ReferenceX * $width / $referenceWidth)
  $cropTop = $rect.Top + [int][Math]::Round($ReferenceY * $height / $referenceHeight)
  $cropWidth = [Math]::Max(1, [int][Math]::Round($RegionWidth * $width / $referenceWidth))
  $cropHeight = [Math]::Max(1, [int][Math]::Round($RegionHeight * $height / $referenceHeight))
  $sourceCapture = New-Object System.Drawing.Bitmap $cropWidth, $cropHeight
  $sourceGraphics = [System.Drawing.Graphics]::FromImage($sourceCapture)
  $scaledCapture = New-Object System.Drawing.Bitmap ($RegionWidth * $Scale), ($RegionHeight * $Scale)
  $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaledCapture)
  $keepScaledCapture = $false

  try {
    $captureFailed = $false
    try {
      $sourceGraphics.CopyFromScreen($cropLeft, $cropTop, 0, 0, $sourceCapture.Size)
    } catch {
      # 원격 데스크톱 창 최소화 등으로 화면 그리기가 멈추면 캡처가 예외로 실패합니다.
      $captureFailed = $true
    }
    # 예외가 없더라도 '검은(빈) 화면'만 돌아오는 경우가 있습니다(RDP 최소화 시 자주 발생).
    # 다만 던전 로딩 화면처럼 게임이 '진짜 검은 장면'을 보여주는 중일 수도 있으므로,
    # 바탕화면 전체 표본에 색이 하나도 없을 때만(=렌더링 자체가 멈춤) 실패로 처리합니다.
    if (-not $captureFailed -and (Test-BlankCapture -Bitmap $sourceCapture)) {
      if (-not (Test-DesktopRenderingAlive)) {
        $captureFailed = $true
      }
    }
    if ($captureFailed) {
      # 오류로 중단하지 않고 '글자를 못 읽은 상태'로 처리해, 화면이 복구되면 이어서 감지합니다.
      Register-CaptureFailure
      return $null
    }
    Register-CaptureSuccess

    if ($BinaryWhiteText) {
      for ($y = 0; $y -lt $cropHeight; $y++) {
        for ($x = 0; $x -lt $cropWidth; $x++) {
          $color = $sourceCapture.GetPixel($x, $y)
          if ($color.R -gt 175 -and $color.G -gt 175 -and $color.B -gt 175) {
            $sourceCapture.SetPixel($x, $y, [System.Drawing.Color]::Black)
          } else {
            $sourceCapture.SetPixel($x, $y, [System.Drawing.Color]::White)
          }
        }
      }
      $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    } else {
      $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    }

    $scaledGraphics.DrawImage(
      $sourceCapture,
      (New-Object System.Drawing.Rectangle 0, 0, ($RegionWidth * $Scale), ($RegionHeight * $Scale)),
      (New-Object System.Drawing.Rectangle 0, 0, $cropWidth, $cropHeight),
      [System.Drawing.GraphicsUnit]::Pixel
    )
    $keepScaledCapture = $true
    return [pscustomobject]@{
      Bitmap = $scaledCapture
      CropLeft = $cropLeft
      CropTop = $cropTop
      CropWidth = $cropWidth
      CropHeight = $cropHeight
      ScaledWidth = ($RegionWidth * $Scale)
      ScaledHeight = ($RegionHeight * $Scale)
      Scale = $Scale
    }
  } finally {
    $scaledGraphics.Dispose()
    $sourceGraphics.Dispose()
    $sourceCapture.Dispose()
    if (-not $keepScaledCapture) { $scaledCapture.Dispose() }
  }
}

function Get-GameRegionOcrText {
  param(
    [System.Diagnostics.Process]$Game,
    [int]$ReferenceX,
    [int]$ReferenceY,
    [int]$RegionWidth,
    [int]$RegionHeight,
    [int]$Scale = 3,
    $Engine = $ocrKoreanEngine,
    [switch]$BinaryWhiteText
  )

  $capture = Get-GameRegionCapture -Game $Game -ReferenceX $ReferenceX -ReferenceY $ReferenceY `
    -RegionWidth $RegionWidth -RegionHeight $RegionHeight -Scale $Scale `
    -BinaryWhiteText:$BinaryWhiteText -ThrowOnWindowRectFailure
  if (-not $capture) { return '' }
  try {
    # 임시 PNG 파일 없이 메모리에서 곧바로 OCR (Invoke-OcrOnBitmap 주석 참고)
    return (Invoke-OcrOnBitmap -Bitmap $capture.Bitmap -Engine $Engine).Text
  } finally {
    $capture.Bitmap.Dispose()
  }
}

function Get-GameOcrText {
  param([System.Diagnostics.Process]$Game)

  return Get-GameRegionOcrText -Game $Game -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] `
    -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -Scale 3 -Engine $ocrKoreanEngine
}

function Find-GameTextPoint {
  param(
    [System.Diagnostics.Process]$Game,
    [int]$ReferenceX,
    [int]$ReferenceY,
    [int]$RegionWidth,
    [int]$RegionHeight,
    [string]$SearchText,
    [string]$ExactText = '',
    [int]$Scale = 3,
    $Engine = $ocrKoreanEngine
  )

  # 영역을 OCR로 읽되 단어별 위치(BoundingRect)까지 받아, 찾는 글자가 포함된 단어의
  # 중심을 '화면 픽셀 좌표'로 돌려줍니다. 게임 UI가 상황에 따라 버튼 위치를 바꾸는 경우
  # (예: 부활 버튼 배치가 남은 횟수에 따라 달라짐) 고정 좌표 대신 이 함수로 찾아 클릭합니다.
  # ExactText 를 주면 '단어 전체가 정확히 일치'하는 것을 먼저 찾고, 없을 때만 SearchText
  # 부분 일치로 넘어갑니다. (예: '지옥1'과 '지옥10'처럼 이름이 겹치는 버튼 구분용)
  # 글자를 못 찾거나 캡처에 실패하면 $null 을 돌려줍니다.
  $capture = Get-GameRegionCapture -Game $Game -ReferenceX $ReferenceX -ReferenceY $ReferenceY `
    -RegionWidth $RegionWidth -RegionHeight $RegionHeight -Scale $Scale
  if (-not $capture) { return $null }
  try {
    # 임시 PNG 파일 없이 메모리에서 곧바로 OCR (Invoke-OcrOnBitmap 주석 참고)
    $result = Invoke-OcrOnBitmap -Bitmap $capture.Bitmap -Engine $Engine
    $matchedWord = $null
    if ($ExactText) {
      # 1차: 단어 전체가 정확히 일치하는 것을 우선 채택 ('지옥1' vs '지옥10' 구분)
      foreach ($line in $result.Lines) {
        foreach ($word in $line.Words) {
          if (($word.Text -replace '\s', '') -eq $ExactText) { $matchedWord = $word; break }
        }
        if ($matchedWord) { break }
      }
    }
    if (-not $matchedWord) {
      # 2차: 찾는 글자가 포함된 첫 단어 (읽기 순서 = 왼쪽부터)
      foreach ($line in $result.Lines) {
        foreach ($word in $line.Words) {
          if (($word.Text -replace '\s', '').Contains($SearchText)) { $matchedWord = $word; break }
        }
        if ($matchedWord) { break }
      }
    }
    if ($matchedWord) {
      # 확대 이미지 좌표 -> 캡처 원본 픽셀 -> 화면 좌표로 역환산합니다.
      $centerXScaled = $matchedWord.BoundingRect.X + ($matchedWord.BoundingRect.Width / 2)
      $centerYScaled = $matchedWord.BoundingRect.Y + ($matchedWord.BoundingRect.Height / 2)
      $screenX = $capture.CropLeft + [int][Math]::Round($centerXScaled * $capture.CropWidth / $capture.ScaledWidth)
      $screenY = $capture.CropTop + [int][Math]::Round($centerYScaled * $capture.CropHeight / $capture.ScaledHeight)
      return [System.Drawing.Point]::new($screenX, $screenY)
    }
    return $null
  } finally {
    $capture.Bitmap.Dispose()
  }
}

function Get-GameRegionOcrWords {
  param(
    [System.Diagnostics.Process]$Game,
    [int]$ReferenceX,
    [int]$ReferenceY,
    [int]$RegionWidth,
    [int]$RegionHeight,
    [int]$Scale = 3,
    $Engine = $ocrKoreanEngine
  )

  # 영역을 한 번 OCR 해 모든 단어를 '기준 좌표(1272x717 환산)'와 함께 돌려줍니다.
  # 여러 라벨을 한 번에 읽어 위치를 비교할 때 사용합니다 (예: 던전 스테이지 지도 스크롤 보정).
  # 캡처 실패 시 빈 배열을 반환합니다.
  $capture = Get-GameRegionCapture -Game $Game -ReferenceX $ReferenceX -ReferenceY $ReferenceY `
    -RegionWidth $RegionWidth -RegionHeight $RegionHeight -Scale $Scale
  if (-not $capture) { return @() }
  try {
    $result = Invoke-OcrOnBitmap -Bitmap $capture.Bitmap -Engine $Engine
    $words = @()
    foreach ($line in $result.Lines) {
      foreach ($word in $line.Words) {
        $centerXScaled = $word.BoundingRect.X + ($word.BoundingRect.Width / 2)
        $centerYScaled = $word.BoundingRect.Y + ($word.BoundingRect.Height / 2)
        # 확대 배율만 되돌리면 기준 좌표가 됩니다 (창 크기와 무관)
        $words += , @{
          Text = ($word.Text -replace '\s', '')
          X = $ReferenceX + [int][Math]::Round($centerXScaled / $Scale)
          Y = $ReferenceY + [int][Math]::Round($centerYScaled / $Scale)
        }
      }
    }
    # 주의: ,$words 로 감싸 반환하면 호출부의 @()가 '배열을 담은 1칸짜리 배열'로 만들어
    # foreach 가 단어가 아닌 배열 자체를 돌게 됩니다 (2026-07-18 18:07 실측 사고).
    # 그냥 반환해 파이프라인이 단어 단위로 풀게 하고, 호출부에서 @()로 모읍니다.
    return $words
  } finally {
    $capture.Bitmap.Dispose()
  }
}

function Get-DgLastRunExitStep {
  param([bool]$HudVisible, [string]$QuestText, [string]$CenterText, [bool]$RetryVisible)

  # 마지막 판 '나가기' 확인 루프의 한 판독분 판정 (순수 - 진리표 테스트 대상, 교차 리뷰 반영):
  #  'popup-exit'     = '던전 탐험을 계속하시겠습니까?' 팝업 - '탐험'+'계속하' 두 신호를 모두
  #                     요구 (Space=나가기 입력이라 느슨한 단일 조각 매칭 금지)
  #  'reclick'        = 결과 화면(다시 하기 버튼)이 그대로 - 나가기 재클릭
  #  'field-evidence' = 필드 증거 1회 (게임플레이 HUD + 퀘스트 추적기에 던전 목표('구역') 없음.
  #                     호출부는 연속 2회일 때만 확정 - 단발 OCR 오판 방지)
  #  'wait'           = 판단 보류 (전환 중)
  $center = ([string]$CenterText) -replace '\s', ''
  if ($center.Contains('탐험') -and $center.Contains('계속하')) { return 'popup-exit' }
  if ($RetryVisible) { return 'reclick' }
  if ($HudVisible -and -not ((([string]$QuestText) -replace '\s', '').Contains('구역'))) { return 'field-evidence' }
  return 'wait'
}

function Get-DgSelectionFocusFloor {
  param([System.Diagnostics.Process]$Game)

  # 선택 화면의 포커스(선택된) 층을 판별합니다. 근거: 하단 진입 버튼 'N층 M구역 진입'의
  # 층 숫자 = 포커스 패널 (2026-07-24 40장 실측 20/20 일치 - 게임이 패널 포커스 시 그 층
  # 구역을 자동 선택). 버튼 글자가 커서 신뢰도가 가장 높습니다. 애니메이션 중 이전 값이
  # 잠깐 남을 수 있어 2회 연속 같은 값일 때만 채택합니다 (설계 합의 - 안정 프레임 확인).
  # 반환: 1 | 2 | 0(판별 실패)
  $lastFloor = ''
  for ($readNo = 1; $readNo -le 3; $readNo++) {
    $enterText = Get-DgStageEnterButtonText -Game $Game
    $floorText = ''
    $stageShapes = [regex]::Matches(([string]$enterText), '(\d)\D{0,2}(\d)구역')
    if ($stageShapes.Count -gt 0) {
      $floorText = [string]$stageShapes[$stageShapes.Count - 1].Groups[1].Value
    }
    if ($floorText -eq '1' -or $floorText -eq '2') {
      if ($lastFloor -eq $floorText) { return [int]$floorText }
      $lastFloor = $floorText
    } else {
      $lastFloor = ''
    }
    Start-Sleep -Milliseconds 350
  }
  return 0
}

function Get-NdStageClickPoint {
  param([System.Diagnostics.Process]$Game, [string]$Stage, [string[]]$ExcludeTypes = @())

  # 던전 선택 화면의 구역 클릭 지점 (2026-07-24 상태·기하 중심 재설계 - 40장 실측 근거):
  #  1) 목표 라벨 정확 일치 + 카드 픽셀 확인 → 그 자리 클릭 (교차 확인된 최선)
  #  2) 던전 ID를 알면: 유형 템플릿 + 포커스 밀림(1층 포커스 0 / 2층 포커스 -29) + 카드 픽셀 확인.
  #     템플릿 자리에 카드가 없으면 반대 포커스 후보를 기하로 확인(카드 있음 + 카드 아래는 빈 공간).
  #  3) 미등록 던전: 라벨 배율 5 재시도 후, 유형 후보(A→B→CR→CN) 중 카드가 실제 있는 지점을
  #     시도 - 클릭 후 진입 버튼 검증이 잡고, 오선택된 후보는 호출부가 ExcludeTypes 로 제외.
  # 과거의 라벨 평균 오프셋 스크롤 보정은 폐기 (배치가 다른 라벨이 평균을 오염 - 2026-07-22 실사고.
  # 밀림은 연속 스크롤이 아니라 포커스 2상태뿐임이 실측 확정).
  # 반환: @{ Point = @(x, y); Source = '설명' } 또는 $null(확정 좌표 없음 - 틀린 좌표로 클릭 금지)
  $mapWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $rgNdStageMap[0] -ReferenceY $rgNdStageMap[1] `
      -RegionWidth $rgNdStageMap[2] -RegionHeight $rgNdStageMap[3] -Scale 3 -Engine $ocrKoreanEngine)
  foreach ($mapWord in $mapWords) {
    if ((Get-DgMapLabelText -Text $mapWord.Text) -eq [string]$Stage) {
      if (Test-DgCardPixelAt -Game $Game -ReferenceX ([int]$mapWord.X) -ReferenceY ([int]$mapWord.Y)) {
        return @{ Point = @([int]$mapWord.X, [int]$mapWord.Y); Source = '라벨' }
      }
      if ($deepMode) {
        # 심층 카드는 적갈색이라 남색 픽셀 판별이 항상 실패 (실측: 카드 몸통 R24~103 vs 패널
        # 배경 R16~45 - 색 분리 불가로 심층 전용 색 판별식은 기각). 화이트리스트(D[12]-[123])
        # 통과 라벨은 신뢰하고 클릭 후 진입 버튼 검증(2차 방어선)에 맡긴다
        # (2026-07-30 00:36 1908 타 PC 실기: 제목 오독 → ID 불명 → 라벨은 정상인데 픽셀
        # 확인 전멸로 안전 정지 - 리뷰 승인).
        return @{ Point = @([int]$mapWord.X, [int]$mapWord.Y); Source = '라벨(픽셀 미확인)' }
      }
    }
  }
  $stageParts = ([string]$Stage) -split '-'
  if ($stageParts.Count -ne 2) { return $null }
  $floorNum = 0
  if (-not [int]::TryParse([string]$stageParts[0], [ref]$floorNum) -or $floorNum -lt 1 -or $floorNum -gt 2) { return $null }
  $layoutType = $null
  if ($script:dgDungeonId -and $dgLayoutTable.ContainsKey([string]$script:dgDungeonId)) {
    $layoutType = [string]($dgLayoutTable[[string]$script:dgDungeonId][$floorNum - 1])
  }
  $focusFloor = Get-DgSelectionFocusFloor -Game $Game
  if ($layoutType) {
    if ($focusFloor -lt 1) { return $null }   # 포커스 불명 - 좌표를 만들지 않음 (안전 정지 유도)
    $point = Get-DgSelStagePoint -LayoutType $layoutType -Stage $Stage -FocusFloor $focusFloor
    if ($point -and (Test-DgCardPixelAt -Game $Game -ReferenceX $point[0] -ReferenceY $point[1])) {
      return @{ Point = $point; Source = "템플릿:$layoutType" }
    }
    # 템플릿 자리 픽셀 확인 실패: 포커스 오판 가능성 - 반대 포커스 후보를 기하로 확인.
    # (카드 아래 우측(x+28, y+25)은 진짜 라벨 위치일 때만 카드 밖 - 두 상태 구분점)
    $altFocus = 1
    if ($focusFloor -eq 1) { $altFocus = 2 }
    $altPoint = Get-DgSelStagePoint -LayoutType $layoutType -Stage $Stage -FocusFloor $altFocus
    if ($altPoint -and (Test-DgCardPixelAt -Game $Game -ReferenceX $altPoint[0] -ReferenceY $altPoint[1]) -and
        -not (Test-DgCardPixelAt -Game $Game -ReferenceX ($altPoint[0] + 28) -ReferenceY ($altPoint[1] + 25))) {
      Write-RunLog "[던전] 포커스 판별($focusFloor)과 달리 반대 상태 좌표에서 카드 확인 - 기하 확인 좌표 사용"
      return @{ Point = $altPoint; Source = "템플릿보정:$layoutType" }
    }
    # 실측 검증된 매핑의 템플릿이므로 픽셀 미확인이어도 좌표는 신뢰하고 시도합니다
    # (RDP 색 왜곡 등으로 판별식이 어긋나는 환경 대비 - 오클릭은 진입 버튼 검증이 잡음).
    if ($point) {
      Write-RunLog "[던전] 템플릿 좌표의 카드 픽셀 확인 실패 - 좌표는 실측 매핑이라 그대로 시도합니다"
      return @{ Point = $point; Source = "템플릿(픽셀 미확인):$layoutType" }
    }
    return $null
  }
  # 미등록 던전(ID 불명 포함): 라벨을 더 큰 배율로 한 번 더 시도
  $mapWordsRetry = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $rgNdStageMap[0] -ReferenceY $rgNdStageMap[1] `
      -RegionWidth $rgNdStageMap[2] -RegionHeight $rgNdStageMap[3] -Scale 5 -Engine $ocrKoreanEngine)
  foreach ($mapWord in $mapWordsRetry) {
    if ((Get-DgMapLabelText -Text $mapWord.Text) -eq [string]$Stage) {
      if (Test-DgCardPixelAt -Game $Game -ReferenceX ([int]$mapWord.X) -ReferenceY ([int]$mapWord.Y)) {
        return @{ Point = @([int]$mapWord.X, [int]$mapWord.Y); Source = '라벨(배율5)' }
      }
      if ($deepMode) {
        # 위 배율 3 라벨 경로와 동일한 심층 완화 (근거 주석은 그쪽 참고)
        return @{ Point = @([int]$mapWord.X, [int]$mapWord.Y); Source = '라벨(배율5·픽셀 미확인)' }
      }
    }
  }
  if ($focusFloor -lt 1) { return $null }
  # 유형 후보 순서 시도: 카드가 실제로 있는 지점만 채택. 오선택은 진입 버튼 검증이 잡고,
  # 호출부가 오선택된 후보 유형을 ExcludeTypes로 넘겨 같은 후보를 반복 클릭하지 않습니다
  # (교차 리뷰 반영 - Attempt 회전만으로는 같은 통과 후보가 반복 반환되는 문제 수정).
  # CR/CN은 같은 자리의 라벨 반전이라 제외 순환이 두 순서를 모두 시도하게 됩니다.
  foreach ($candidateType in @('A', 'B', 'CR', 'CN')) {
    if ($ExcludeTypes -contains $candidateType) { continue }
    $point = Get-DgSelStagePoint -LayoutType $candidateType -Stage $Stage -FocusFloor $focusFloor
    if ($point -and (Test-DgCardPixelAt -Game $Game -ReferenceX $point[0] -ReferenceY $point[1])) {
      return @{ Point = $point; Source = "미등록후보:$candidateType" }
    }
  }
  return $null
}

function Write-DgStageDiagnostics {
  param([System.Diagnostics.Process]$Game, [string]$Context, [string]$MapKind = 'selection')

  # 구역 선택 실패로 조건부 정지(코드 4)하기 전, 원인 분석용 진단 세트를 남깁니다.
  # 코드 4는 오류 catch를 타지 않아 기존에는 캡처가 없어서 제보 로그만으로 배치·원인을
  # 확인할 수 없었습니다 (2026-07-22 실사고 교훈). 스크린샷은 error_* 명명/보관 정책 공유.
  try {
    $diagStamp = Get-Date -Format 'yyyyMMdd_\hHH\mmm\sss'
    if ($Game) {
      $diagRect = New-Object HoneyNogiInput+RECT
      if ([HoneyNogiInput]::GetWindowRect($Game.MainWindowHandle, [ref]$diagRect)) {
        $diagW = $diagRect.Right - $diagRect.Left
        $diagH = $diagRect.Bottom - $diagRect.Top
        if ($diagW -gt 0 -and $diagH -gt 0) {
          $diagShot = Join-Path $logDir "error_$diagStamp.png"
          $diagBmp = New-Object System.Drawing.Bitmap $diagW, $diagH
          $diagGfx = [System.Drawing.Graphics]::FromImage($diagBmp)
          try {
            $diagGfx.CopyFromScreen($diagRect.Left, $diagRect.Top, 0, 0, $diagBmp.Size)
            $diagBmp.Save($diagShot, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-RunLog "[진단] $Context - 화면 캡처 저장: $diagShot"
          } finally {
            $diagGfx.Dispose()
            $diagBmp.Dispose()
          }
          $keepShots = Get-ConfigInteger $config @('diagnostics', 'keepScreenshots') 10 0 1000
          if ($keepShots -gt 0) {
            $oldShots = @(Get-ChildItem -LiteralPath $logDir -Filter 'error_*.png' -File -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -Skip $keepShots)
            foreach ($old in $oldShots) {
              Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
            }
          }
        }
      }
    }
    $diagRegion = $rgNdStageMap
    if ($MapKind -eq 'option') { $diagRegion = $rgDgOptStageMap }
    $diagWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $diagRegion[0] -ReferenceY $diagRegion[1] `
        -RegionWidth $diagRegion[2] -RegionHeight $diagRegion[3] -Scale 3 -Engine $ocrKoreanEngine)
    $wordDump = (@($diagWords | ForEach-Object { "$($_.Text)($($_.X),$($_.Y))" }) -join ' ')
    Write-RunLog "[진단] $Context - 지도 OCR 원문: $wordDump"
    Write-RunLog "[진단] $Context - 진입 버튼 OCR: '$(Get-DgStageEnterButtonText -Game $Game)'"
    Write-RunLog "[진단] $Context - 던전 ID: '$([string]$script:dgDungeonId)'"
  } catch {
    Write-RunLog "[진단] 진단 수집 실패: $($_.Exception.Message)"
  }
}

function Get-EnterButtonText {
  param([System.Diagnostics.Process]$Game)

  # 상세 화면 하단 버튼 영역의 글자를 읽습니다. 캐릭터 위치에 따라
  # '입장하기'(던전 근처에 있음) 또는 '이동하기'(멀리 있어 이동 필요)가 표시됩니다.
  $ocrText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgEnterButton[0] -ReferenceY $rgEnterButton[1] `
    -RegionWidth $rgEnterButton[2] -RegionHeight $rgEnterButton[3] -Scale 4 -Engine $ocrKoreanEngine
  return ($ocrText -replace '\s', '')
}

function Get-DgStageEnterButtonText {
  param([System.Diagnostics.Process]$Game)

  # 던전 구역 선택 화면의 넓은 하단 버튼 전용 판독입니다. 어비스 상세 화면용
  # Get-EnterButtonText($rgEnterButton)는 영역이 좁고 오른쪽에 있어, 1908x1076 환경에서
  # '1층 1구역' 숫자 부분을 놓치며 SourceCondition이 실제 클릭을 막은 사례가 있었습니다.
  return ((Get-GameRegionOcrText -Game $Game -ReferenceX $rgDgEnterBtn[0] -ReferenceY $rgDgEnterBtn[1] `
      -RegionWidth $rgDgEnterBtn[2] -RegionHeight $rgDgEnterBtn[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', '')
}

function Test-DgStageEnterTextMatches {
  param([string]$EnterText, [string]$Stage)

  $verdict = Get-DgSelectionRecoveryAction -EnterText $EnterText -TargetStage $Stage
  return ($verdict.Action -eq 'selected')
}

function Test-DgStageEnterButtonVisible {
  param([System.Diagnostics.Process]$Game, [string]$Stage)

  # 클릭 직전에도 버튼이 목표 구역을 가리키는지 같은 판정기로 확인합니다. OCR에 공물 숫자가
  # 붙거나 '층'이 깨져도 Get-DgSelectionRecoveryAction의 실측 완화 규칙을 그대로 사용합니다.
  return (Test-DgStageEnterTextMatches -EnterText (Get-DgStageEnterButtonText -Game $Game) -Stage $Stage)
}

function Test-DgImePopupVisible {
  param([System.Diagnostics.Process]$Game)

  # 게임 창 우하단에 시스템 입력기(IME) 팝업이 떠 있는지 전용 영역 OCR로 확인합니다.
  # 이 팝업은 진입/입장 버튼을 덮어 버튼 OCR과 클릭을 동시에 무력화합니다 (2026-07-29 실측).
  $ocrText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgImePopup[0] -ReferenceY $rgImePopup[1] `
    -RegionWidth $rgImePopup[2] -RegionHeight $rgImePopup[3] -Scale 3 -Engine $ocrKoreanEngine
  return (Test-ImeOverlayText -Text $ocrText)
}

function Test-DetailScreen {
  param([System.Diagnostics.Process]$Game)

  # 상세 화면 하단의 '입장하기' 버튼 글자로 '입장 가능한 상세 화면'인지 판단합니다.
  # (기존 픽셀 색 검사는 원격 데스크톱 등 환경에 따라 색이 조금 달라지면 어긋나므로 OCR로 대체)
  # OCR이 '입'을 깨뜨려도 살아남는 '장하'까지 함께 봅니다 ('이동하기'에는 없는 글자라 안전).
  return ((Get-EnterButtonText -Game $Game) -match '입장|장하')
}

function Test-PartyDetailScreen {
  param([System.Diagnostics.Process]$Game)

  # 함께하기 탭 화면인지 판단합니다. 하단이 '파티원 모집'+'입장하기' 2버튼 배치라
  # 입장하기 버튼이 혼자하기보다 오른쪽에 있어 전용 영역으로 읽습니다 (실측).
  $ocrText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgPartyEnterBtn[0] -ReferenceY $rgPartyEnterBtn[1] `
    -RegionWidth $rgPartyEnterBtn[2] -RegionHeight $rgPartyEnterBtn[3] -Scale 4 -Engine $ocrKoreanEngine) -replace '\s', ''
  return ($ocrText -match '입장|장하')
}

function Get-DetailTitleText {
  param([System.Diagnostics.Process]$Game)

  # 상세 화면 좌측 상단의 던전 이름 영역을 OCR로 읽습니다.
  # 제목은 혼자하기/함께하기 어느 탭에서든 항상 표시되므로,
  # '입장하기' 버튼(탭에 따라 위치가 바뀜)보다 안정적인 상세 화면 판별 기준입니다.
  $ocrText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgDetailTitle[0] -ReferenceY $rgDetailTitle[1] `
    -RegionWidth $rgDetailTitle[2] -RegionHeight $rgDetailTitle[3] -Scale 3 -Engine $ocrKoreanEngine
  return ($ocrText -replace '\s', '')
}

function Test-DetailTitleMatches {
  param([System.Diagnostics.Process]$Game)

  # 지금 열린 상세 화면이 "선택한 던전"의 것이 맞는지 확인합니다.
  # 1순위: 제목에 던전 키워드가 있으면 확정.
  # 2순위: 혼자하기 탭이 활성이면 좌상단 제목이 회색으로 흐려져 OCR이 실패할 수 있는데,
  #   이때 하단 '입장하기' 버튼이 읽히면 상세 화면에 도착한 것으로 인정합니다
  #   (다른 던전 상세로 잘못 들어간 경우는 시작 시 제목 검사에서 이미 걸러집니다).
  if ((Get-DetailTitleText -Game $Game).Contains($dungeonMatch)) { return $true }
  return (Test-DetailScreen -Game $Game)
}

function Test-DungeonEntered {
  param([System.Diagnostics.Process]$Game)

  # 던전 입장이 끝나면 우측 상단에 Home / End / ESC HUD가 나타납니다.
  # 이 HUD는 던전 선택/상세 화면에는 없고 게임플레이 화면에서만 보이므로,
  # 내용이 계속 바뀌는 퀘스트 추적기보다 훨씬 안정적인 입장 완료 신호입니다.
  return Test-HomeEndEscHud -Game $Game
}

function Wait-ForScreen {
  param(
    [scriptblock]$Condition,
    [int]$TimeoutSeconds,
    [string]$Description,
    [System.Diagnostics.Process]$Game,
    [int]$PollMilliseconds = 400
  )

  # 감지가 계속 실패하면(게임 창이 다른 창에 가려진 경우 등) 주기적으로 게임 창을
  # 다시 앞으로 가져와 감지를 복구합니다. config.json focus.refocusEverySeconds 로 조절(0=끄기).
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $lastFocus = Get-Date
  do {
    # Condition 은 실행하되 캡처 실패 중에는 성공으로 인정하지 않습니다 (2026-08-01 전수
    # 점검: `-not (Test-...)` 형태 Condition 이 캡처 실패의 빈 판독을 성공으로 뒤집어 즉시
    # 반환할 수 있었음. 실행 자체는 유지해야 캡처 성공 등록이 복구를 진행시킴 - 리뷰 조건.
    # Invoke-ClickUntil 의 기존 게이트와 같은 계약)
    if ((& $Condition) -and -not $script:screenCaptureFailing) {
      return
    }
    if ($script:screenCaptureFailing) {
      # 화면 캡처가 안 되는 동안은 제한 시간을 멈춥니다(복구되면 남은 시간부터 다시 진행).
      # 복구가 영영 안 되는 상황에서도 안전하게 끝낼 수 있게 안전 중지 예약을 확인합니다.
      Test-SafeStopDuringCaptureFail
      $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    }
    if ($Game -and $refocusEverySeconds -gt 0 -and
        ((Get-Date) - $lastFocus).TotalSeconds -ge $refocusEverySeconds) {
      if (Invoke-AutoRefocus -Game $Game) { $lastFocus = Get-Date }
    }
    Start-Sleep -Milliseconds $PollMilliseconds
  } while ((Get-Date) -lt $deadline)

  throw "$Description 대기 시간이 초과됐습니다."
}

function Wait-ForDungeonClearScreen {
  param(
    [System.Diagnostics.Process]$Game,
    [int]$TimeoutSeconds = 300,
    [switch]$DungeonMode,
    [scriptblock]$FindResultButton
  )
  # DungeonMode: 던전/사냥터용. 어비스 전용 검사(나가기/어비스 선택 화면)를 건너뛰고
  # 폴링 간격을 1초로 줄여 클리어 화면을 더 빨리 감지합니다.
  # FindResultButton: 콘텐츠별 결과 화면 버튼 탐색(던전='다시 하기'/사냥터='새 임무 선택').
  # 사용자가 클리어 화면을 직접 터치해 이미 결과 화면으로 넘어간 경우를 잡습니다.

  # 반환값: 'clear' = 클리어 화면 감지 / 'reward' = 이미 보상 화면(사용자가 직접 터치해 넘긴 경우)
  #         'selection' = 이미 어비스 선택 화면(사용자가 끝까지 직접 진행한 경우)
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $lastFocus = Get-Date
  $reviveCount = 0              # 이번 회차에 자동 부활한 횟수
  $reviveConfirmPending = $false # R키 입력 후 부활 완료 확인 대기 중
  $revivePendingKind = ''        # 진행 중인 부활 종류 (가루 부활/여신상 부활/전멸 재도전 - 완료 로그에 표기)
  $reviveBlockedLogged = $false  # 부활 불가 경고를 이미 남겼는지(반복 출력 방지)
  $autoHuntPresses = 0           # 자동사냥 꺼짐 감시가 자동출발 키를 누른 횟수(로그 정리용)
  $assistPresses = 0             # ASSIST 꺼짐 감시가 H키를 누른 횟수(로그 정리용)
  $pollCounter = 0               # 팝업(2회)/컷신(3회) 확인 주기 조절용
  $useStatueRevive = $false      # 부활 재료 부족이 확인되면 이후 부활을 여신상으로 전환
  $wipeButtonMisses = 0          # 전멸 감지 상태에서 '여신' 버튼 연속 미발견 횟수 (3회째 예비 좌표)
  # 전투 진행 중 연장 한도: 제한 시간이 다 됐어도 퀘스트 추적기에 클리어 목표가 남아
  # 있으면(= 판이 길어진 것뿐) 오류 대신 대기를 연장하되, 이 절대 한도까지만 허용합니다.
  $extendLimit = (Get-Date).AddSeconds([Math]::Max($TimeoutSeconds * 3, 1800))
  $extendLogged = $false
  while ($true) {
    # 마감/전투 연장 판정 (본문 최상단 - 2026-08-01 전수 점검: 기존 do-while 은 이 판정이
    # 루프 바닥에 있어 팝업/부활/협동 처리의 continue 가 판정을 건너뛰었고, 마감 직전에
    # 팝업을 닫으면 전투가 진행 중이어도 연장 없이 시간 초과로 죽을 수 있었음. 최상단으로
    # 옮기면 continue 가 어디서 나와도 매 바퀴 반드시 거침 - 리뷰 승인).
    if ((Get-Date) -ge $deadline) {
      if ($script:screenCaptureFailing) {
        # 캡처 실패 중에는 연장 판독이 불가 - throw 하지 않고 아래 캡처 실패 처리(시간 동결)에
        # 맡깁니다 (리뷰 조건: 실패 중 마감 도달을 오류로 확정하지 않음)
      } elseif ((Get-Date) -lt $extendLimit -and (Test-InDungeonQuest -Game $Game)) {
        if (-not $extendLogged) {
          Write-RunLog "$($script:contentTag) 클리어 대기 한도(${TimeoutSeconds}초)를 넘겼지만 전투가 아직 진행 중 - 끝날 때까지 연장 대기합니다"
          $extendLogged = $true
        }
        $deadline = (Get-Date).AddSeconds(60)
      } elseif ($script:screenCaptureFailing) {
        # 연장 판독(Test-InDungeonQuest) 도중 캡처 실패가 새로 시작된 경우 - 판독 불가를
        # 오류로 확정하지 않고 아래 캡처 실패 처리(시간 동결)에 맡깁니다 (교차 리뷰 지적)
      } elseif ((Test-DungeonClearPrompt -Game $Game) -or
          ($FindResultButton -and (& $FindResultButton) -and -not (Test-HomeEndEscHud -Game $Game)) -or
          ((-not $DungeonMode) -and (Test-ExitButton -Game $Game) -and -not (Test-HomeEndEscHud -Game $Game)) -or
          ((-not $DungeonMode) -and (Test-AbyssSelectionScreen -Game $Game) -and -not (Test-HomeEndEscHud -Game $Game))) {
        # 마감 도달 순간 이미 성공 화면(클리어/결과/보상/선택)이면 오류가 아니라 이번 바퀴의
        # 정상 판정에 맡깁니다 (3차 점검: 마감 직전 전환을 놓치고 throw 하던 회귀. 결과/보상
        # 판정의 HUD 부재 조건은 본문과 동일 - 리뷰 조건. 탐침만 하고 처리·로그는 본문이 담당)
      } elseif ($script:screenCaptureFailing) {
        # 위 최종 탐침 도중 캡처 실패가 새로 시작된 경우도 동결 처리에 맡깁니다 (리뷰 조건)
      } else {
        throw '던전 클리어 화면 감지 대기 시간이 초과됐습니다.'
      }
    }
    $pollCounter++

    # 클리어 감지가 목적이므로 가장 먼저, 매 바퀴 확인합니다 (지연 최소화)
    if (Test-DungeonClearPrompt -Game $Game) {
      Write-RunLog "$($script:contentTag) 클리어 문구(화면을 터치) 감지"
      return 'clear'
    }

    # 네트워크 불안정 팝업 - 결과 화면 감지보다 먼저 처리합니다 ('다시 시도하기'가
    # Find-DgRetryButtonPoint 의 '다시/다셔/하기' 어휘와 겹쳐 오인 여지 - 리뷰 조건.
    # 2026-08-01 KJM 실사고: 이 대기 중에 떠서 600초를 통째로 소진했음)
    if (($pollCounter % 2) -eq 0 -and (Close-NetworkUnstablePopup -Game $Game -LogPrefix "$($script:contentTag) ")) { continue }

    # 던전/사냥터: 사용자가 클리어 화면을 직접 터치해 이미 결과 화면으로 넘어간 경우 감지
    # (2026-07-18 21:52 실측: 18초 클리어 + 수동 터치 → 워커가 클리어 문구만 계속 대기하다
    #  시간 초과. 결과 화면에는 HUD가 없으므로, 전투 중 오탐 방지로 HUD 부재를 함께 확인)
    if ($FindResultButton -and ($pollCounter % 2) -eq 0 -and -not $script:screenCaptureFailing) {
      if ((& $FindResultButton) -and -not (Test-HomeEndEscHud -Game $Game)) {
        Write-RunLog "$($script:contentTag) 결과 화면 감지 (클리어 화면이 이미 지나감)"
        return 'reward'
      }
    }

    # 어비스 전용: 사용자가 직접 진행해 보상/선택 화면으로 넘어간 경우 감지 (던전 모드에서는 건너뜀)
    if (-not $DungeonMode) {
      # 사용자가 클리어 화면을 직접 터치해서 이미 보상 화면으로 넘어간 경우를 감지합니다.
      # (전투 중 채팅에 '나가기'가 지나가는 오탐을 막기 위해, HUD가 사라진 상태인지 함께 확인)
      if (Test-ExitButton -Game $Game) {
        if (-not (Test-HomeEndEscHud -Game $Game)) {
          Write-RunLog '[어비스] 보상 화면 감지 (클리어 화면이 이미 지나감)'
          return 'reward'
        }
      }

      # 사용자가 나가기까지 직접 눌러 어비스 선택 화면으로 돌아간 경우
      if (Test-AbyssSelectionScreen -Game $Game) {
        if (-not (Test-HomeEndEscHud -Game $Game)) {
          Write-RunLog '[어비스] 선택 화면 복귀 상태 감지 (직접 진행됨)'
          return 'selection'
        }
      }
    }

    # 구매 제안 팝업(회복 물약 부족 등)이 떠 있으면 화면 중앙을 덮어 감지가 가려지므로
    # '닫기'를 찾아 클릭합니다(부하를 줄이려고 2회 폴링마다 확인). 부활 시도 직후에 떴다면
    # 부활 재료(불사의 가루) 부족으로 판단하고 이후 부활은 여신상으로 전환합니다.
    if (($pollCounter % 2) -eq 0 -and -not $script:screenCaptureFailing) {
      $popupClosePoint = Find-GameTextPoint -Game $Game -ReferenceX $rgPopupClose[0] -ReferenceY $rgPopupClose[1] `
        -RegionWidth $rgPopupClose[2] -RegionHeight $rgPopupClose[3] -SearchText '닫기'
      if ($popupClosePoint) {
        Focus-Game -Game $Game
        Click-ScreenPoint -X $popupClosePoint.X -Y $popupClosePoint.Y
        # '가루 부족' 해석은 R키 가루 부활 직후에만 (2026-08-01 전수 점검: 여신상/전멸 부활은
        # 가루를 안 쓰므로 그 직후의 임의 구매 팝업(물약 부족 등)을 재료 부족으로 오인해
        # 여신상 전환이 영구 고정되던 문제 - 리뷰 승인. 완료 로그용 pending 은 종류 무관 유지)
        if ($reviveConfirmPending -and $revivePendingKind -eq '가루 부활') {
          $useStatueRevive = $true
          $reviveConfirmPending = $false
          Write-RunLog "$($script:contentTag) 부활 직후 구매 팝업(재료 부족 추정) - 닫고 이후 부활은 여신상으로 전환"
        } else {
          Write-RunLog "$($script:contentTag) 구매 팝업 감지 - 닫기 클릭"
        }
        Start-Sleep -Seconds 1
        continue
      }
      # 협동 미션 완료 전체 화면 (2026-07-31 점검에서 발견한 사각지대 - 협동 미션은 몬스터
      # 처치 누적으로 완료되므로 정작 전투/클리어 대기 중에 뜰 확률이 가장 높은데, 이 루프는
      # 입장 대기용 팝업 스윕을 쓰지 않아 화면이 덮인 채 클리어 감지가 가려졌습니다).
      # 구매 팝업 '닫기'를 못 찾았을 때만 확인하고, 실제로 닫았을 때만 폴링을 다시 돕니다.
      # 부활 대기 상태($reviveConfirmPending)는 구매 팝업이 아니므로 건드리지 않습니다.
      if (Close-CoopMissionScreen -Game $Game) { continue }
      # 오클릭으로 열린 '보유한 재화' 전체 화면도 같은 주기로 정리 (2026-08-02 실사고)
      if (Close-CurrencyOverviewScreen -Game $Game) { continue }
      # 월요일 06:00 주간 리셋 블로커 2종 - 리셋은 게임 상태와 무관하게 발생하므로 클리어
      # 대기 중에도 걸릴 수 있음 (2026-08-03 06:02 실사고의 배선 확장 - 리뷰 권고)
      if (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix "$($script:contentTag) ") { continue }
      if (Close-CoopMissionBoardScreen -Game $Game -LogPrefix "$($script:contentTag) ") { continue }
    }

    # 행동불능(사망)/파티 전멸 감지 시 자동 부활:
    #  - 파티 전멸('전멸하였습니다')이면 '여신상에서 부활' 클릭 = 세이브 지점(캠프파이어)부터
    #    재도전 (2026-07-28 실기 오류 + 사용자 확정 스펙. Dead 보다 먼저 판정)
    #  - 남은 부활 횟수가 있으면 R키로 '여기서 부활' (그 자리에서 바로 전투 재개)
    #  - 남은 횟수가 없으면 '여신상에서 부활' 클릭 (여신상에서 살아나 전투를 이어감)
    if ($reviveEnabled) {
      $death = Get-DeathScreenInfo -Game $Game
      if (-not $death.Wiped) { $wipeButtonMisses = 0 }   # 전멸 상태가 풀리면 미발견 누적 초기화 (리뷰 조건)
      if ($death.Wiped) {
        if ($reviveCount -ge $reviveMaxPerCycle) {
          # 전멸 재도전도 자동 복구 시도이므로 기존 부활 상한을 공유합니다 (무한 재도전 루프 방지)
          if (-not $reviveBlockedLogged) {
            Write-RunLog "[경고] 이번 회차 자동 부활이 ${reviveMaxPerCycle}회에 도달해 전멸 재도전을 더 시도하지 않습니다."
            $reviveBlockedLogged = $true
          }
        } else {
          # 이중 확인: 우하단에서 '여신' 버튼 글자를 실제로 찾은 뒤에만 클릭합니다
          # (중앙 문구 오탐 방어 + 상태 기반 클릭 정책. 실측: '여신상에서' 중심 (986,670))
          $wipeClicked = $false
          $wipeStatuePoint = Find-GameTextPoint -Game $Game -ReferenceX $rgReviveButtons[0] -ReferenceY $rgReviveButtons[1] `
            -RegionWidth $rgReviveButtons[2] -RegionHeight $rgReviveButtons[3] -SearchText '여신'
          if ($wipeStatuePoint) {
            $wipeButtonMisses = 0
            Focus-Game -Game $Game
            Click-ScreenPoint -X $wipeStatuePoint.X -Y $wipeStatuePoint.Y
            $wipeClicked = $true
          } else {
            $wipeButtonMisses++
            if ($wipeButtonMisses -ge 3) {
              # 예비 좌표는 클릭 직전 전멸 상태를 한 번 더 확인한 뒤에만 사용합니다 (리뷰 조건 -
              # 그 사이 화면이 바뀌었으면 고정 좌표 클릭이 다른 버튼을 누를 수 있음)
              $wipeButtonMisses = 0
              $wipeRecheck = Get-DeathScreenInfo -Game $Game
              if ($wipeRecheck.Wiped) {
                Write-RunLog '[경고] 전멸 화면에서 여신상 부활 버튼 글자를 찾지 못해 예비 좌표를 클릭합니다'
                Focus-Game -Game $Game
                Click-GamePoint -Game $Game -ReferenceX $ptWipeStatueRevive[0] -ReferenceY $ptWipeStatueRevive[1]
                $wipeClicked = $true
              }
            }
          }
          if ($wipeClicked) {
            $reviveCount++
            Write-RunLog "$($script:contentTag) 전멸 감지 - 여신상에서 부활 클릭 (세이브 지점부터 재도전)"
            $revivePendingKind = '전멸 재도전'
            $reviveConfirmPending = $true
            Start-Sleep -Seconds 3
            # 재도전으로 전투가 이어지므로 클리어 제한 시간을 처음부터 다시 셉니다.
            $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
            continue
          }
        }
      } elseif ($death.Dead) {
        if ($reviveCount -ge $reviveMaxPerCycle) {
          if (-not $reviveBlockedLogged) {
            Write-RunLog "[경고] 이번 회차 자동 부활이 ${reviveMaxPerCycle}회에 도달해 더 시도하지 않습니다."
            $reviveBlockedLogged = $true
          }
        } elseif ($useStatueRevive -or ($null -ne $death.Remaining -and $death.Remaining -le 0)) {
          $reviveCount++
          $statueReason = if ($useStatueRevive) { '부활 재료 부족' } else { '남은 부활 횟수 없음' }
          Write-RunLog "$($script:contentTag) 행동불능($statueReason) - 여신상에서 부활 클릭"
          $revivePendingKind = '여신상 부활'
          Focus-Game -Game $Game
          # 부활 버튼 배치는 남은 횟수 유무에 따라 달라지므로(0회면 버튼들이 한 줄로 재배치됨),
          # 고정 좌표 대신 '여신상' 글자를 OCR로 찾아 실제 버튼 위치를 클릭합니다.
          $statuePoint = Find-GameTextPoint -Game $Game -ReferenceX $rgReviveButtons[0] -ReferenceY $rgReviveButtons[1] `
            -RegionWidth $rgReviveButtons[2] -RegionHeight $rgReviveButtons[3] -SearchText '여신'
          if ($statuePoint) {
            Click-ScreenPoint -X $statuePoint.X -Y $statuePoint.Y
          } else {
            Write-RunLog '[경고] 여신상 부활 버튼 글자를 찾지 못해 예비 좌표를 클릭합니다'
            Click-GamePoint -Game $Game -ReferenceX $ptStatueRevive[0] -ReferenceY $ptStatueRevive[1]
          }
          $reviveConfirmPending = $true
          Start-Sleep -Seconds 3
          # 부활 후 전투가 이어지므로 클리어 제한 시간을 처음부터 다시 셉니다.
          $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
          continue
        } else {
          $reviveCount++
          $remainText = if ($null -ne $death.Remaining) { "남은 부활 횟수 $($death.Remaining)회" } else { '남은 횟수 인식 불가' }
          Write-RunLog "$($script:contentTag) 행동불능($remainText) - 여기서 부활 (R키, 불사의 가루 소모)"
          $revivePendingKind = '가루 부활'
          Focus-Game -Game $Game
          Press-KeyOnce -VirtualKey ([byte]$reviveKey)
          $reviveConfirmPending = $true
          Start-Sleep -Seconds 3
          # 부활 후 전투가 이어지므로 클리어 제한 시간을 처음부터 다시 셉니다.
          $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
          continue
        }
      } elseif ($reviveConfirmPending) {
        $reviveConfirmPending = $false
        $reviveBlockedLogged = $false
        # 어떤 부활이었는지 종류를 함께 표기 (사용자가 로그만 보고 사망/부활 경위를 알 수 있게)
        $reviveDoneKind = $(if ($revivePendingKind) { "($revivePendingKind)" } else { '' })
        Write-RunLog "$($script:contentTag) 부활 완료$reviveDoneKind - 전투 계속"
        $revivePendingKind = ''
      }

      # 자동사냥 꺼짐 상시 감시: 입장 키가 씹혔거나(그 순간 사용자가 마우스/키보드를 쓴 경우 등),
      # 부활 직후이거나, 어떤 이유로든 자동사냥이 꺼진 채 서 있으면 우하단에 나침반 아이콘(off)이
      # 보입니다. 그때만 자동출발 키를 눌러 다시 켭니다. 전투 중(스킬 버튼)이나 다른 화면에서는
      # 'unknown'으로 판정되어 아무것도 누르지 않으므로 안전합니다. resumeKey = 0 이면 감시를 끕니다.
      if ($reviveResumeKey -gt 0 -and -not $script:screenCaptureFailing) {
        $huntState = Get-AutoHuntState -Game $Game
        if ($huntState -eq 'off') {
          $autoHuntPresses++
          if ($autoHuntPresses -eq 1) {
            Write-RunLog "$($script:contentTag) 자동사냥 꺼짐 감지 - Space 재입력"
          } elseif (($autoHuntPresses % 15) -eq 0) {
            Write-RunLog "[경고] 자동출발 입력 ${autoHuntPresses}회째에도 자동사냥이 켜지지 않습니다 - 계속 시도합니다"
          }
          Focus-Game -Game $Game
          Press-KeyOnce -VirtualKey ([byte]$reviveResumeKey)
          Start-Sleep -Seconds 2
        } elseif ($huntState -eq 'on' -and $autoHuntPresses -gt 0) {
          Write-RunLog "$($script:contentTag) 자동사냥 켜짐 확인 (Space ${autoHuntPresses}회 입력)"
          $autoHuntPresses = 0
        }
      }
    }

    # ASSIST 자동 켜기 상시 감시 (2026-07-28 사용자 요청): 전투 HUD 우측 ASSIST 토글이
    # 꺼져 있으면 H키로 켭니다 (분홍=클래스 특화/초록=일반 모두 '켜짐'으로 인정).
    # 픽셀 3점이 꺼짐 패턴과 정확히 일치할 때만 입력 - 다른 화면/전투 버튼은 unknown 으로
    # 아무것도 누르지 않습니다 (자동사냥 꺼짐 감시와 동일 패턴, 입력 후 2초 대기).
    if ($assistAutoOn -and -not $script:screenCaptureFailing) {
      $assistState = Get-AssistState -Game $Game
      if ($assistState -eq 'off') {
        $assistPresses++
        if ($assistPresses -eq 1) {
          Write-RunLog "$($script:contentTag) ASSIST 꺼짐 감지 - H키로 켬"
        } elseif (($assistPresses % 15) -eq 0) {
          Write-RunLog "[경고] ASSIST 켜기 입력 ${assistPresses}회째에도 켜지지 않습니다 - 계속 시도합니다"
        }
        Focus-Game -Game $Game
        Press-KeyOnce -VirtualKey ([byte]$assistKey)
        Start-Sleep -Seconds 2
      } elseif ($assistState -eq 'on' -and $assistPresses -gt 0) {
        Write-RunLog "$($script:contentTag) ASSIST 켜짐 확인 (H ${assistPresses}회 입력)"
        $assistPresses = 0
      }
    }

    # 보스방 진입 컷신이 재생 중이면 '장면 넘기기' 버튼을 찾아 클릭해 바로 넘깁니다.
    # (부하를 줄이기 위해 3회 폴링마다 한 번씩만 확인)
    if (($pollCounter % 3) -eq 0 -and -not $script:screenCaptureFailing) {
      $skipSceneRegion = $rgCutsceneTop
      $skipScenePoint = Find-GameTextPoint -Game $Game -ReferenceX $rgCutsceneTop[0] -ReferenceY $rgCutsceneTop[1] `
        -RegionWidth $rgCutsceneTop[2] -RegionHeight $rgCutsceneTop[3] -SearchText '넘기'
      if (-not $skipScenePoint) {
        $skipSceneRegion = $rgCutsceneBottom
        $skipScenePoint = Find-GameTextPoint -Game $Game -ReferenceX $rgCutsceneBottom[0] -ReferenceY $rgCutsceneBottom[1] `
          -RegionWidth $rgCutsceneBottom[2] -RegionHeight $rgCutsceneBottom[3] -SearchText '넘기'
      }
      if ($skipScenePoint) {
        # 컷신이 그 사이에 저절로 끝났을 수 있으므로 클릭 직전에 한 번 더 확인합니다.
        # (끝난 뒤 그 자리를 누르면 클리어 화면을 건드리거나 미니맵이 열릴 수 있음)
        # 재확인은 '처음 찾았던 그 영역'을 다시 읽습니다 - 하단에서 찾고 상단을 재확인하면
        # 항상 무효화되어 하단 배치 컷신이 절대 스킵되지 않는 문제가 있었습니다.
        $skipScenePoint = Find-GameTextPoint -Game $Game -ReferenceX $skipSceneRegion[0] -ReferenceY $skipSceneRegion[1] `
          -RegionWidth $skipSceneRegion[2] -RegionHeight $skipSceneRegion[3] -SearchText '넘기'
      }
      if ($skipScenePoint) {
        Focus-Game -Game $Game
        Click-ScreenPoint -X $skipScenePoint.X -Y $skipScenePoint.Y
        Write-RunLog "$($script:contentTag) 컷신 - 장면 넘기기 클릭"
        Start-Sleep -Seconds 2
      }
    }

    if ($script:screenCaptureFailing) {
      # 원격 창 최소화 등으로 캡처가 안 되는 동안은 제한 시간을 멈춥니다.
      Test-SafeStopDuringCaptureFail
      $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    }
    # 게임 창이 가려져 있으면 OCR이 계속 실패하므로 주기적으로 게임을 앞으로 가져옵니다.
    if ($refocusEverySeconds -gt 0 -and
        ((Get-Date) - $lastFocus).TotalSeconds -ge $refocusEverySeconds) {
      if (Invoke-AutoRefocus -Game $Game) { $lastFocus = Get-Date }
    }
    # 폴링 간격 1초 (던전/어비스 공통): 원래 어비스는 2초였으나 보스 클리어 후
    # '화면을 터치' 감지가 늦다는 실사용 피드백(2026-07-19)으로 던전과 동일하게 통일.
    # 클리어 확인이 매 바퀴 첫 순서이므로 감지 지연 = 이 간격 + 나머지 검사 시간.
    Start-Sleep -Milliseconds 1000
  }
}

function Get-AutoHuntState {
  param([System.Diagnostics.Process]$Game)

  # 우하단 자동사냥 버튼 아이콘을 픽셀 9곳(중심 5 + 반지름 10px 둘레 4)으로 판별합니다.
  #  - 'off' = 꺼짐(나침반): 중심 검은 바늘 축(실측 0,0,0) + 둘레는 흰 원(실측 255) → Space를 눌러도 되는 상태
  #  - 'on'  = 자동사냥 중(흰 사각형 정지 아이콘): 중심·둘레 모두 밝음 (실측 250+)
  #  - 'unknown' = 그 외. 전투 중에는 이 자리에 스킬 버튼이 떠서 나침반 패턴과 일치하지 않으며,
  #    이때 Space를 눌러도 게임이 받지 않으므로 '대기'로 처리해 헛입력을 막습니다.
  $centerOffsets = @(@(0, 0), @(-4, 0), @(4, 0), @(0, -4), @(0, 4))
  $ringOffsets = @(@(-10, 0), @(10, 0), @(0, -10), @(0, 10))
  $centerBright = 0
  $centerDark = 0
  $ringBright = 0
  foreach ($offset in $centerOffsets) {
    try {
      $color = Get-GamePixel -Game $Game -ReferenceX ($ptAutoHuntIcon[0] + $offset[0]) -ReferenceY ($ptAutoHuntIcon[1] + $offset[1])
    } catch {
      return 'unknown'
    }
    if ($color.R -gt 200 -and $color.G -gt 200 -and $color.B -gt 200) { $centerBright++ }
    elseif ($color.R -lt 100 -and $color.G -lt 100 -and $color.B -lt 100) { $centerDark++ }
  }
  foreach ($offset in $ringOffsets) {
    try {
      $color = Get-GamePixel -Game $Game -ReferenceX ($ptAutoHuntIcon[0] + $offset[0]) -ReferenceY ($ptAutoHuntIcon[1] + $offset[1])
    } catch {
      return 'unknown'
    }
    if ($color.R -gt 200 -and $color.G -gt 200 -and $color.B -gt 200) { $ringBright++ }
  }
  if ($centerBright -eq $centerOffsets.Count -and $ringBright -eq $ringOffsets.Count) { return 'on' }
  if ($centerDark -eq $centerOffsets.Count -and $ringBright -eq $ringOffsets.Count) { return 'off' }
  return 'unknown'
}

function Get-AssistStateFromColors {
  param($Left, $Mid, $Right)

  # ASSIST 토글 상태 분류의 순수부 (진리표 테스트 대상 - Get-AssistState 가 픽셀 프로브 후 위임).
  # 2026-07-28 실측 (1272x717, 토글 필 y=513 의 L=-7/M=0/R=+12 오프셋 3점):
  #  - 꺼짐: 흰 점이 왼쪽 = L(255,255,255) + 필 회색 = M/R(78~100)
  #  - 켜짐(분홍=클래스 특화 어시): L/M (206,64,96) - R채널 우세
  #  - 켜짐(초록=일반 어시): L/M (13,179,118) - G채널 우세
  #    (켜지면 흰 점이 오른쪽으로 이동 - R점은 점 위치 가변이라 켜짐 판정에서 제외)
  # 꺼짐은 3점 전부 일치(보수적 - H 입력 조건), 켜짐은 L/M 이 '같은 색 계열'일 때만
  # (혼합색 오탐 방지 - 설계 합의). 그 외 unknown = 다른 화면/전투 버튼 - 아무것도 안 누름.
  $leftWhite = ($Left.R -gt 200 -and $Left.G -gt 200 -and $Left.B -gt 200)
  $midGrey = ($Mid.R -ge 50 -and $Mid.R -le 140 -and $Mid.G -ge 50 -and $Mid.G -le 140 -and $Mid.B -ge 50 -and $Mid.B -le 140)
  $rightGrey = ($Right.R -ge 50 -and $Right.R -le 140 -and $Right.G -ge 50 -and $Right.G -le 140 -and $Right.B -ge 50 -and $Right.B -le 140)
  if ($leftWhite -and $midGrey -and $rightGrey) { return 'off' }
  $leftPink = ($Left.R -gt 160 -and $Left.G -lt 110 -and $Left.B -lt 140)
  $midPink = ($Mid.R -gt 160 -and $Mid.G -lt 110 -and $Mid.B -lt 140)
  $leftGreen = ($Left.G -gt 140 -and $Left.R -lt 80 -and $Left.B -ge 60 -and $Left.B -le 160)
  $midGreen = ($Mid.G -gt 140 -and $Mid.R -lt 80 -and $Mid.B -ge 60 -and $Mid.B -le 160)
  if (($leftPink -and $midPink) -or ($leftGreen -and $midGreen)) { return 'on' }
  return 'unknown'
}

function Get-AssistState {
  param([System.Diagnostics.Process]$Game)

  # ASSIST 토글 3점 픽셀 프로브 (분류 규칙은 Get-AssistStateFromColors 참고).
  # 캡처/픽셀 읽기 실패는 unknown = 아무것도 하지 않음 (오입력 방지).
  try {
    $assistLeft  = Get-GamePixel -Game $Game -ReferenceX ($ptAssistToggle[0] - 7)  -ReferenceY $ptAssistToggle[1]
    $assistMid   = Get-GamePixel -Game $Game -ReferenceX $ptAssistToggle[0]        -ReferenceY $ptAssistToggle[1]
    $assistRight = Get-GamePixel -Game $Game -ReferenceX ($ptAssistToggle[0] + 12) -ReferenceY $ptAssistToggle[1]
  } catch {
    return 'unknown'
  }
  return Get-AssistStateFromColors -Left $assistLeft -Mid $assistMid -Right $assistRight
}

function Get-DeathInfoFromText {
  param([string]$Text)

  # 사망/전멸 안내 판정의 순수부 (진리표 테스트 대상 - Get-DeathScreenInfo 가 OCR 후 위임).
  # Dead(개인 행동불능): '행동불능' 장식 폰트는 OCR이 잘 못 읽어 그 아래 '남은 부활 횟수 3/3'
  # 줄을 기준으로 삼습니다. Wiped(파티 전멸): '전멸하였습니다 / 마지막 캠프파이어에서부터
  # 재도전하시겠습니까?' 화면 - 2026-07-28 실기 오류 캡처 실측 판독은
  # '전별하였습LI다 … 재도전하시겠습니)가?' ('전멸'→'전별' 깨짐, '캠프파이어' 전파괴).
  # 조각은 '전멸하/전별하/재도전하'만 인정 - '재도전' 단독은 클리어 점수표의 '재도전 보너스'
  # 실측 판독('처치완벽한전주권장전투력재도전보너스…')과 겹쳐 오탐이라 제외 (설계 합의.
  # 전멸 화면 실측은 '재도전하시겠…'라 '재도전하'로 잡힘). 실제 클릭은 호출부가 우하단에서
  # '여신' 버튼을 실제로 찾은 뒤에만 수행하는 이중 확인 구조입니다.
  # 반환: @{ Dead; Remaining(파싱 실패 시 $null); Wiped }
  $normalized = ([string]$Text) -replace '\s', ''
  $wiped = (
    $normalized.Contains('전멸하') -or
    $normalized.Contains('전별하') -or
    $normalized.Contains('재도전하')
  )
  $dead = (
    $normalized.Contains('남은부활') -or
    $normalized.Contains('부활횟수') -or
    $normalized.Contains('행동불능')
  )
  $remaining = $null
  if ($dead) {
    $match = [regex]::Match($normalized, '(\d+)/(\d+)')
    if ($match.Success) { $remaining = [int]$match.Groups[1].Value }
  }
  return @{ Dead = $dead; Remaining = $remaining; Wiped = $wiped }
}

function Get-DeathScreenInfo {
  param([System.Diagnostics.Process]$Game)

  # 화면 중앙의 사망/전멸 안내 영역을 읽어 판정합니다 (판정 규칙은 Get-DeathInfoFromText 참고).
  # 반환: @{ Dead = 개인 행동불능; Remaining = 남은 부활 횟수($null 가능); Wiped = 파티 전멸 }
  $ocrText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgDeathStatus[0] -ReferenceY $rgDeathStatus[1] `
    -RegionWidth $rgDeathStatus[2] -RegionHeight $rgDeathStatus[3] -Scale 3 -Engine $ocrKoreanEngine
  return Get-DeathInfoFromText -Text $ocrText
}

function Test-DungeonClearPrompt {
  param([System.Diagnostics.Process]$Game)

  # 클리어 화면의 '화면을 터치해 주세요' 문구를 감지합니다.
  # 문구 뒤에 캐릭터가 겹치면 글자가 깨져 읽히는 경우가 있어 조합으로 느슨하게 확인합니다.
  # 실측된 깨짐 사례:
  #  - '화면을터夫6주' (2026-07-16: '치'가 깨짐)      → '화면을' + '터' 조합으로 잡음
  #  - '화n을터치해주l요' (2026-07-17: '면'이 깨짐)   → '터치해/터치하' 조각으로 잡음
  #  - '화면을치해주세요' (2026-07-18: '터'가 통째로 소실, 클리어 화면 2분 방치 실측)
  #    → '화면을' + '주세요' 조합으로 잡음
  #  - '면百치해' / '화면치6H天서j“' (2026-07-19: 캐릭터가 글자 뒤에 겹쳐 판독마다 다르게
  #    깨짐 - 같은 화면에서 600초 초과 실측. 진단과 재현 판독이 서로 달랐음)
  #    → '면'+'치해' 및 '화면'+'치' 조합으로 잡음 ('경험치 고二', '보상을확인해주세요' 같은
  #      비대상 실측 판독에는 안 걸리는 조합 - 진리표 테스트 참고)
  # '화면을'이나 '터치'만 단독으로 쓰면 다른 안내와 겹칠 수 있어 두 조각 조합을 요구합니다.
  $ocrText = Get-GameOcrText -Game $Game
  $normalized = $ocrText -replace '\s', ''
  if ($normalized.Contains('화면을') -and $normalized.Contains('터')) { return $true }
  if ($normalized.Contains('화면을') -and $normalized.Contains('주세요')) { return $true }
  if ($normalized.Contains('치해') -and $normalized.Contains('면')) { return $true }
  if ($normalized.Contains('화면') -and $normalized.Contains('치')) { return $true }
  if ($normalized.Contains('터치해') -or $normalized.Contains('터치하')) { return $true }

  # 보조 신호(사용자 제안 2026-07-19): 하단 문구가 아예 못 읽힐 만큼 깨져도, 클리어 화면
  # 좌측 점수표('빠른 처치'/'완벽한 전투'/'재도전·협동 보너스')는 캐릭터와 안 겹쳐 잘 읽힙니다.
  # '처치' + ('완벽' 또는 '보너스') 두 줄 조합 요구 - 결과/옵션/전투 화면 실측 판독에는 안 걸림.
  # (제목 '던전 클리어!'는 스타일 폰트라 '코전쎠/'처럼 깨져 신호로 쓰지 않음 - 실측 2장 공통)
  $scoreText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgClearScore[0] -ReferenceY $rgClearScore[1] `
    -RegionWidth $rgClearScore[2] -RegionHeight $rgClearScore[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  return ($scoreText.Contains('처치') -and ($scoreText.Contains('완벽') -or $scoreText.Contains('보너스')))
}

function Test-NoticeBoardPopup {
  param([System.Diagnostics.Process]$Game)

  # 공지 게시판 팝업(하단 탭: 공지사항/이벤트/쿠폰 입력/FAQ)을 감지합니다.
  # 아침 6시 리셋 뒤 이 팝업이 화면을 덮은 채 남으면, 가장자리로 필드 HUD가 그대로
  # 보여 '필드 상태'로 오판되고 ESC 클릭이 팝업에 막혀 무한 반복됩니다
  # (2026-07-19 06:42 타 PC 실측: ESC 클릭 18회 후 시간 초과).
  # 탭 줄 글자가 크고 또렷해 판독이 안정적입니다 ('공지사항'/'이벤트'/'쿠폰'/'FAQ').
  $text = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgNoticeTabs[0] -ReferenceY $rgNoticeTabs[1] `
    -RegionWidth $rgNoticeTabs[2] -RegionHeight $rgNoticeTabs[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if (-not $text) { return $false }
  if ($text.Contains('쿠폰')) { return $true }
  return ($text.Contains('공지') -and $text.Contains('이벤트'))
}

function Test-ExitButton {
  param([System.Diagnostics.Process]$Game)

  $ocrText = Get-GameOcrText -Game $Game
  $normalized = $ocrText -replace '\s', ''
  return $normalized.Contains('나가기')
}

function Test-HomeEndEscHud {
  param([System.Diagnostics.Process]$Game)

  # 게임플레이 화면 우측 상단의 Home / End / ESC 버튼을 감지합니다.
  # - 알림 아이콘이 끼면 배치가 밀리므로 Home~ESC가 모두 들어오는 넉넉한 영역을 사용합니다.
  # - 원격 데스크톱 압축 등으로 글자가 흐려질 수 있어 일반 OCR과 흰색 이진화 OCR 두 방식으로 읽고,
  #   세 단어(Home/End/ESC) 중 하나라도 확인되면 HUD가 있는 것으로 판단합니다.
  #   (선택/상세/클리어/보상 화면에서는 이 영역에 글자가 전혀 없어 오탐 위험이 없습니다.)
  $plainText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgHomeEndEsc[0] -ReferenceY $rgHomeEndEsc[1] `
    -RegionWidth $rgHomeEndEsc[2] -RegionHeight $rgHomeEndEsc[3] -Scale 5 -Engine $ocrEnglishEngine
  $normalized = ($plainText -replace '\s', '').ToLowerInvariant()
  if ($normalized.Contains('hom') -or $normalized.Contains('esc') -or $normalized.Contains('end')) {
    return $true
  }

  $binaryText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgHomeEndEsc[0] -ReferenceY $rgHomeEndEsc[1] `
    -RegionWidth $rgHomeEndEsc[2] -RegionHeight $rgHomeEndEsc[3] -Scale 5 -Engine $ocrEnglishEngine -BinaryWhiteText
  $normalized = ($binaryText -replace '\s', '').ToLowerInvariant()
  return ($normalized.Contains('hom') -or $normalized.Contains('esc') -or $normalized.Contains('end'))
}

function Test-MenuExitLabel {
  param([System.Diagnostics.Process]$Game)

  # ESC 메뉴 우하단의 '게임 종료' 문구를 확인합니다. 이 문구는 메뉴에서만 표시되므로
  # '메뉴가 열려 있다'는 독립적인 2차 신호로 씁니다 (두 창 크기에서 실측: '게임 종료' 정상 인식).
  $ocrText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgMenuExitLabel[0] -ReferenceY $rgMenuExitLabel[1] `
    -RegionWidth $rgMenuExitLabel[2] -RegionHeight $rgMenuExitLabel[3] -Scale 4 -Engine $ocrKoreanEngine
  return (($ocrText -replace '\s', '').Contains('종료'))
}

function Test-AbyssMenu {
  param([System.Diagnostics.Process]$Game)

  # 창이 작은 PC(예: 1368x771)에서는 메뉴 글자가 ~13px로 작아 OCR이 깨지기 쉽습니다
  # (실측: scale 3에서 '보스'→'니人' 등). 확대 배율을 4로 올리고,
  # '어비스'의 '어'가 깨져도 잡히도록 '비스' 조각까지 허용합니다
  # (이 메뉴 줄의 다른 글자(필드 보스/망령의 탑/레이드)와 겹치지 않음 - 실측 확인).
  $ocrText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgAbyssMenu[0] -ReferenceY $rgAbyssMenu[1] `
    -RegionWidth $rgAbyssMenu[2] -RegionHeight $rgAbyssMenu[3] -Scale 4 -Engine $ocrKoreanEngine
  $normalized = $ocrText -replace '\s', ''
  if ($normalized.Contains('어비스') -or $normalized.Contains('비스')) { return $true }
  # 2차 신호: 4번째 줄 글자가 통째로 깨지는 PC(OCR 엔진 차이)에서도 메뉴 열림을 놓치지 않게
  # 다른 위치의 메뉴 전용 문구('게임 종료')로 한 번 더 확인합니다.
  # (이 판정이 없으면 메뉴가 열린 채 공지사항의 'Home' 배지가 HUD로 오인되어
  #  ESC 위치를 재클릭 → 우편함이 열리는 사고가 남 - 2026-07-17 04:25 실측)
  return (Test-MenuExitLabel -Game $Game)
}

function Test-AbyssSelectionScreen {
  param([System.Diagnostics.Process]$Game)

  # 2026-07-16 UI 개편 대응: 좌상단 '어비스' 제목은 장식 폰트+아이콘 탓에 OCR이 불안정합니다
  # (실측: scale 3 '!힌 어비스' / scale 4 '0!切스' 로 깨짐). 우측 던전 배너 3장의 제목
  # (허상의 정박지/광기의 동굴/흩어진 물길)은 안정적으로 읽히므로 그쪽을 1차 기준으로 삼고,
  # 기존 제목 '비스' 검사는 보조 기준으로 유지합니다 (배너가 가려진 경우 대비).
  $cardsText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgAbyssCards[0] -ReferenceY $rgAbyssCards[1] `
    -RegionWidth $rgAbyssCards[2] -RegionHeight $rgAbyssCards[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  foreach ($titleKeyword in $allDungeonKeywords) {
    if ($cardsText.Contains($titleKeyword)) { return $true }
  }
  $ocrText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgAbyssSelect[0] -ReferenceY $rgAbyssSelect[1] `
    -RegionWidth $rgAbyssSelect[2] -RegionHeight $rgAbyssSelect[3] -Scale 3 -Engine $ocrKoreanEngine
  $normalized = $ocrText -replace '\s', ''
  return $normalized.Contains('비스')
}

function Invoke-ClickUntil {
  param(
    [System.Diagnostics.Process]$Game,
    [int[]]$Point,
    [scriptblock]$Condition,
    [scriptblock]$SourceCondition,
    [string]$Description,
    [int]$TimeoutSeconds = 20,
    [int]$ReclickEverySeconds = 5,
    [int[]]$FallbackPoint,
    [scriptblock]$FallbackCondition
  )

  # 클릭 후 목표 화면이 나타나는지 확인하고, 정해진 시간 동안 안 나오면 다시 클릭합니다.
  # SourceCondition을 준 호출부는 원래 버튼/화면이 여전히 확인될 때만 재클릭합니다.
  # 화면은 이미 바뀌었지만 목표 OCR이 늦게 잡히는 사이 같은 좌표의 다른 버튼을 누르는 사고를 막습니다.
  # FallbackPoint/FallbackCondition: 원래 버튼 확인(SourceCondition)이 시스템 팝업 등에 가려
  # 실패했지만 별도 신호(예: IME 팝업 감지 + 좌상단 제목)가 '원래 화면 그대로'를 보증할 때,
  # 팝업에 안 덮이는 예비 지점을 대신 클릭합니다 (사이클당 1클릭 유지 - 2026-07-29 실기).
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    # 조건이 참이어도 캡처 실패 중이면 믿지 않습니다: 실패 중 OCR은 빈 문자열을 돌려주므로
    # '-not (화면 감지)' 형태의 부정형 조건이 클릭도 안 했는데 참이 되는 오판을 막습니다.
    if ((& $Condition) -and -not $script:screenCaptureFailing) { return }
    if ($script:screenCaptureFailing) {
      # 화면 캡처가 안 되는 동안은 결과 확인이 불가능하므로 클릭하지 않고 기다립니다.
      Test-SafeStopDuringCaptureFail
      $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
      Start-Sleep -Milliseconds 700
      continue
    }
    $sourceStillVisible = ($null -eq $SourceCondition) -or (& $SourceCondition)
    if ($script:screenCaptureFailing) { continue }
    if ($sourceStillVisible) {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $Point[0] -ReferenceY $Point[1]
    } elseif ($null -ne $FallbackPoint -and $null -ne $FallbackCondition -and
              (& $FallbackCondition) -and -not $script:screenCaptureFailing) {
      Write-RunLog "[안내] $Description - 원래 버튼이 팝업에 가려져 예비 지점을 클릭합니다"
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $FallbackPoint[0] -ReferenceY $FallbackPoint[1]
    }
    $nextClick = (Get-Date).AddSeconds($ReclickEverySeconds)
    while ((Get-Date) -lt $nextClick -and (Get-Date) -lt $deadline) {
      if ((& $Condition) -and -not $script:screenCaptureFailing) { return }
      # 클릭 후 대기 중 캡처가 실패하면(RDP 끊김 등) 바깥 루프의 실패 처리로 나가
      # 제한 시간을 연장합니다 - 여기서 그냥 기다리면 실패 구간이 제한 시간을 소모해
      # 복구 직후 억울하게 초과되는 사고가 있었습니다 (2026-07-17 23:47 실측).
      if ($script:screenCaptureFailing) { break }
      Start-Sleep -Milliseconds 400
    }
  }
  throw "$Description 대기 시간이 초과됐습니다."
}

function Test-InDungeonQuest {
  param([System.Diagnostics.Process]$Game)

  # 던전 안에서는 우측 퀘스트 추적기 맨 위에 '<던전 이름> 클리어' 목표가 고정 표시됩니다.
  # 이 영역에 던전 키워드(정박/광기/물길...)가 보이면 '던전 안'으로 판정합니다.
  # (실측 검증: 던전 안 '허상의 정박지 클리어' → True / 필드 '[주간 목표]...' → False)
  $ocrText = Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
    -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine
  $normalized = $ocrText -replace '\s', ''
  foreach ($titleKeyword in $allDungeonKeywords) {
    if ($normalized.Contains($titleKeyword)) { return $true }
  }
  return $false
}

function Read-DgTitleText {
  param([System.Diagnostics.Process]$Game)

  # 좌상단 던전 제목 판독 - 좁은 기본 영역(config 폭 250) 우선, 심층에서만 조건부 확장.
  # 실측 근거 (2026-07-28, 같은 날 상반된 두 사고):
  #  - 심층 옵션 제목('던전명+심층+N층 M구역')은 길어서 폭 250이면 끝 '구역'이 잘림
  #    (20:20 오류: '〈북쪽폐61심층2층3국'. 폭 420은 심층 옵션 캡처 21장 전수 '구역' 포함)
  #  - 반대로 밝은 배경(노을 항구)의 선택 화면에서는 폭 420 판독이 통째로 빈 값
  #    (20:53 오류: 같은 캡처가 폭 250='북쪽폐하', 폭 420=''. 밝은 영역이 넓게 들어오면
  #    OCR 텍스트 검출 자체가 전멸. 옵션 화면은 배경이 항상 어두운 오버레이라 확장이 안정)
  # → 좁게 읽어 '구역'이 있으면 그대로, 없으면 심층에서만 폭 420 재판독해 '구역'이 보일
  #   때만 채택. 일반 던전은 기존과 동일한 좁은 판독 1회 (무접촉).
  $narrowText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgDgTitle[0] -ReferenceY $rgDgTitle[1] `
    -RegionWidth $rgDgTitle[2] -RegionHeight $rgDgTitle[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if (-not $deepMode) { return $narrowText }
  if ($narrowText.Contains('구역')) { return $narrowText }
  $wideText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgDgTitle[0] -ReferenceY $rgDgTitle[1] `
    -RegionWidth 420 -RegionHeight $rgDgTitle[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if ($wideText.Contains('구역')) { return $wideText }
  return $narrowText
}

function Test-KnownScreen {
  param([System.Diagnostics.Process]$Game)

  # 자동화가 알고 있는 화면(어비스 선택 / 상세 / 던전 밖 HUD / 보상 / ESC 메뉴 /
  # 던전 선택·옵션 / 사냥터 첫 화면) 중 하나라도 감지되면 true.
  # 출석/이벤트 같은 전체 화면 오버레이 여부를 판단할 때 씁니다.
  if (Test-AbyssSelectionScreen -Game $Game) { return $true }
  if (Test-HomeEndEscHud -Game $Game) { return $true }
  if (Test-ExitButton -Game $Game) { return $true }
  if (Test-AbyssMenu -Game $Game) { return $true }
  $title = Get-DetailTitleText -Game $Game
  foreach ($titleKeyword in $allDungeonKeywords) {
    if ($title.Contains($titleKeyword)) { return $true }
  }
  # 던전 선택('~던전')/진입 옵션('N층 M구역') 화면 - 던전 카테고리도 이벤트 넘기기를 거치므로 필요
  $dgTitle = Read-DgTitleText -Game $Game
  if ($dgTitle.Contains('구역') -or (Test-DgSelectionTitle -TitleText $dgTitle)) { return $true }
  # 던전 선택 화면 2차 신호: 하단 'N층 M구역 진입' 버튼의 '진입' 조각 (2026-07-28 실기:
  # 제목 OCR이 일시적으로 빈 값이라 심층 선택 화면을 못 알아보고, 알 수 없는 화면 폴백의
  # X 후보(1229,67)가 던전 우상단 X(1228,67)와 같은 자리라 던전 UI를 닫고 필드로 이탈.
  # 제목(좌상단)과 독립된 우하단 영역이라 이중 신호가 됨. '진입'은 선택 화면 전용 문구 -
  # 옵션/어비스 상세는 '입장하기', 결과 화면은 '다시 하기'라 오탐 없음)
  $dgEnterProbe = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgDgEnterBtn[0] -ReferenceY $rgDgEnterBtn[1] `
    -RegionWidth $rgDgEnterBtn[2] -RegionHeight $rgDgEnterBtn[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if ($dgEnterProbe.Contains('진입')) { return $true }
  # 클리어 화면('화면을 터치')과 던전 결과 화면(다시 하기) - 이벤트 오버레이로 오인해 중앙/
  # X 후보를 헛클릭하지 않게 알려진 화면으로 인정 (2026-08-02 타 PC 프리즈 제보에서 발견:
  # 클리어 화면을 '출석/이벤트 화면 추정'으로 오인해 중앙 5회 + X 후보 20회 헛클릭 - 72초
  # 낭비. 두 화면 모두 시작 판정('클리어 화면 감지 - 터치부터'/'결과 화면 감지')이 담당)
  if (Test-DungeonClearPrompt -Game $Game) { return $true }
  if (Find-DgRetryButtonPoint -Game $Game) { return $true }
  # 사냥터 첫 화면 (하단 '입장하기'/'임무 시작' 버튼)
  if (Find-HtEntryButtonPoint -Game $Game) { return $true }
  # 사냥터 결과 화면 (나가기/머무르기/새 임무 선택) - 이걸 모르는 화면으로 보고 중앙을
  # 클릭하면 전리품 아이템 상세가 열릴 수 있어 알려진 화면으로 인식합니다 (2026-07-17 실측)
  if (Find-HtNewMissionPoint -Game $Game) { return $true }
  return $false
}

function Invoke-EventSkipOrConfirm {
  param(
    [System.Diagnostics.Process]$Game,
    [string]$LogPrefix = ''
  )

  # 출석/이벤트 화면의 '출석부 건너뛰기' 또는 보상 요약의 '확인' 버튼을 찾아 클릭합니다.
  # 클릭했으면 $true, 두 버튼 모두 없으면 $false 를 반환합니다.
  # (스텔라 픽/알 수 없는 화면 폴백은 시도 횟수 상태와 묶여 있어 여기에 포함하지 않습니다)
  # 협동 미션 전체 창은 범용 '지원'/'확인' 탐색보다 먼저 전용 제목으로 판정합니다 (이 창에
  # 그 단어들이 없다는 실측이 없으므로 특정 화면 확인 → 전용 X 순서 - 리뷰 조건, 06:02 실사고)
  if (Close-CoopMissionBoardScreen -Game $Game -LogPrefix $LogPrefix) { return $true }
  # 네트워크 불안정 팝업도 같은 이유로 선두 - 알 수 없는 화면 루프의 정식 출구 (08-01 KJM 실사고:
  # 중앙/X 후보 20클릭이 전부 빗나갔음)
  if (Close-NetworkUnstablePopup -Game $Game -LogPrefix $LogPrefix) { return $true }
  $skipPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgEventSkip[0] -ReferenceY $rgEventSkip[1] `
    -RegionWidth $rgEventSkip[2] -RegionHeight $rgEventSkip[3] -SearchText '건너'
  if ($skipPoint) {
    Focus-Game -Game $Game
    Click-ScreenPoint -X $skipPoint.X -Y $skipPoint.Y
    Write-RunLog "[안내] ${LogPrefix}출석부 건너뛰기 클릭"
    Start-Sleep -Seconds 2
    return $true
  }
  # '출석 완료 - 우편으로 지원품이 지급되었습니다' 보상 화면: 하단 확인 버튼이 Space 조작이라
  # 클릭 대신 Space 를 눌러 넘깁니다 ('지원' 문구로 감지 - 실측 2026-07-17).
  $rewardText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgEventReward[0] -ReferenceY $rgEventReward[1] `
    -RegionWidth $rgEventReward[2] -RegionHeight $rgEventReward[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if ($rewardText.Contains('지원')) {
    Focus-Game -Game $Game
    Press-KeyOnce -VirtualKey ([byte]32)   # Space = 확인
    Write-RunLog "[안내] ${LogPrefix}출석 완료(지원품 지급) 화면 - Space로 확인"
    Start-Sleep -Seconds 2
    return $true
  }
  $confirmPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgEventConfirm[0] -ReferenceY $rgEventConfirm[1] `
    -RegionWidth $rgEventConfirm[2] -RegionHeight $rgEventConfirm[3] -SearchText '확인'
  if ($confirmPoint) {
    Focus-Game -Game $Game
    Click-ScreenPoint -X $confirmPoint.X -Y $confirmPoint.Y
    Write-RunLog "[안내] ${LogPrefix}보상 확인 클릭"
    Start-Sleep -Seconds 2
    return $true
  }
  # 주간 협동 미션 리셋 팝업 - 공용 소함수로 처리 (2026-08-03 추출)
  if (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix $LogPrefix) { return $true }
  return $false
}

function Close-WeeklyCoopResetPopup {
  param(
    [System.Diagnostics.Process]$Game,
    [string]$LogPrefix = ''
  )

  # 주간 협동 미션 리셋 팝업 (월요일 오전 6시 - 2026-07-20 06:03 실측: '새로운 한 주가
  # 시작되었어요!' 전체 화면이 어비스 복귀를 막아 시간 초과. 알 수 없는 화면 X 후보들도
  # 이 팝업의 버튼 위치와 달라 못 닫았음). 하단 버튼 줄 판독('닫기 협동 미션 참여하기')이
  # 두 창 크기(1272/1908) 모두 또렷 - '협동'+'참여' 조합으로 감지하고 '닫기'를 클릭합니다.
  # 2026-08-03 06:02 실사고로 소함수 추출: 이 팝업이 '다시 하기 → 옵션 복귀 대기'를 40초
  # 막아 무인 정지 - 이벤트 스킵 외에 복귀 대기 루프들(던전/사냥터)도 공용해야 함.
  # 예비 좌표 클릭은 '협동'+'참여' 동시 확정이 전제 (이 분기 자체가 그 게이트 - 리뷰 조건).
  if ($script:screenCaptureFailing) { return $false }
  $weeklyText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] `
    -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if ($weeklyText.Contains('협동') -and $weeklyText.Contains('참여')) {
    $weeklyClosePoint = Find-GameTextPoint -Game $Game -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] `
      -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -SearchText '닫기'
    Focus-Game -Game $Game
    if ($weeklyClosePoint) {
      Click-ScreenPoint -X $weeklyClosePoint.X -Y $weeklyClosePoint.Y
    } else {
      Click-GamePoint -Game $Game -ReferenceX 495 -ReferenceY 654   # '닫기' 실측 예비 좌표 (두 창 크기 동일)
    }
    Write-RunLog "[안내] ${LogPrefix}주간 협동 미션 팝업 감지 - 닫기 클릭"
    Start-Sleep -Seconds 2
    return $true
  }
  return $false
}

function Clear-EventOverlay {
  param([System.Diagnostics.Process]$Game)

  # 아침 6시 리셋 후 뜨는 출석/이벤트 화면(전체 화면 NPC 장면)을 자동으로 넘깁니다.
  # 실측 흐름(2026-07-15): NPC 대화(중앙 클릭으로 진행) → 출석부 1~N개 연쇄
  # ('출석부 건너뛰기' 클릭) → '출석 완료' 보상 요약('확인' 클릭, 보상은 우편 지급) → 복귀.
  # 알려진 화면이 이미 보이면 아무것도 하지 않고 false, 넘기기를 수행했으면 true 반환.
  if (Test-KnownScreen -Game $Game) { return $false }

  Write-RunLog '[안내] 출석/이벤트 화면 추정 - 자동으로 넘깁니다'
  # 캡처 실패 중에는 시도 횟수를 소모하지 않습니다 (다른 대기 루프의 '시간 동결'과 동일한 원칙).
  # 아래(루프 끝)의 Test-KnownScreen OCR이 복구 탐침을 겸하므로 복구되면 자연히 이어집니다.
  # 시도 상한 20회: 아침 리셋 체인이 길 수 있습니다
  # (NPC 대화 여러 줄 + 출석부 + 출석 완료 + 스텔라 픽 2단계 + 공지 팝업들 - 실측 기준 여유 포함)
  $attempt = 0
  $maxAttempts = 20
  $stellaPicks = 0   # '오늘의 스텔라 픽' 카드 선택 시도 횟수 (2회 후에는 닫기 X로 전환)
  while ($attempt -lt $maxAttempts) {
    if ($script:screenCaptureFailing) {
      Test-SafeStopDuringCaptureFail
      Start-Sleep -Seconds 2
    } else {
      $attempt++
      # 0) '오늘의 스텔라 픽' 데일리 팝업(카드 3장 선택 - 실측 2026-07-16):
      #    좌상단 제목으로 감지해 가운데 카드를 골라 진행하고, 두 번 골라도 화면이
      #    남아 있으면(선택 불가 상태 등) 우상단 닫기(X)를 눌러 닫습니다.
      $stellaTitle = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgStellaTitle[0] -ReferenceY $rgStellaTitle[1] `
        -RegionWidth $rgStellaTitle[2] -RegionHeight $rgStellaTitle[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
      if ($stellaTitle.Contains('스텔라')) {
        Focus-Game -Game $Game
        if ($stellaPicks -lt 2) {
          $stellaPicks++
          Click-GamePoint -Game $Game -ReferenceX $ptStellaCard[0] -ReferenceY $ptStellaCard[1]
          Write-RunLog '[안내] 오늘의 스텔라 픽 감지 - 가운데 카드 선택'
        } else {
          Click-GamePoint -Game $Game -ReferenceX $ptStellaClose[0] -ReferenceY $ptStellaClose[1]
          Write-RunLog '[안내] 스텔라 픽 화면이 남아 있어 닫기(X) 클릭'
        }
        Start-Sleep -Seconds 2
      } elseif ($stellaPickBtn = Find-GameTextPoint -Game $Game -ReferenceX $rgStellaPickBtn[0] -ReferenceY $rgStellaPickBtn[1] `
          -RegionWidth $rgStellaPickBtn[2] -RegionHeight $rgStellaPickBtn[3] -SearchText '스텔라') {
        # 스텔라 픽 2단계(확정 화면 - 실측 2026-07-17): 1단계에서 카드를 고르면 카드 캐러셀과
        # 하단 초록 '스텔라 픽' 확정 버튼이 나옵니다. 버튼을 눌러 오늘의 픽을 확정합니다.
        Focus-Game -Game $Game
        Click-ScreenPoint -X $stellaPickBtn.X -Y $stellaPickBtn.Y
        Write-RunLog '[안내] 스텔라 픽 2단계 - 확정 버튼(스텔라 픽) 클릭'
        Start-Sleep -Seconds 2
      } elseif ($todayOffBtn = Find-GameTextPoint -Game $Game -ReferenceX $rgEventTodayOff[0] -ReferenceY $rgEventTodayOff[1] `
          -RegionWidth $rgEventTodayOff[2] -RegionHeight $rgEventTodayOff[3] -SearchText '그만') {
        # 공지 팝업(점검/안내 - 실측 2026-07-17): '오늘 그만 보기'를 눌러 닫으면
        # 오늘 다시 뜨지 않습니다. 안내 문구의 '확인할...'을 확인 버튼으로 오인해
        # 헛클릭을 반복하지 않도록 이 검사가 '확인' 탐색보다 먼저 옵니다.
        Focus-Game -Game $Game
        Click-ScreenPoint -X $todayOffBtn.X -Y $todayOffBtn.Y
        Write-RunLog "[안내] 공지 팝업 - '오늘 그만 보기' 클릭"
        Start-Sleep -Seconds 2
      } elseif ($eventCloseBtn = Find-GameTextPoint -Game $Game -ReferenceX $rgEventCloseBtn[0] -ReferenceY $rgEventCloseBtn[1] `
          -RegionWidth $rgEventCloseBtn[2] -RegionHeight $rgEventCloseBtn[3] -SearchText '닫기') {
        # 새 이벤트 안내 팝업('닫기'/'이벤트 바로가기' 배치): 닫기를 눌러 넘어갑니다
        Focus-Game -Game $Game
        Click-ScreenPoint -X $eventCloseBtn.X -Y $eventCloseBtn.Y
        Write-RunLog "[안내] 이벤트 안내 팝업 - '닫기' 클릭"
        Start-Sleep -Seconds 2
      } elseif (Find-GameTextPoint -Game $Game -ReferenceX $rgNoticeBoardTabs[0] -ReferenceY $rgNoticeBoardTabs[1] `
          -RegionWidth $rgNoticeBoardTabs[2] -RegionHeight $rgNoticeBoardTabs[3] -SearchText '쿠폰') {
        # 웹뷰형 공지 보드(공지사항/이벤트/쿠폰 입력/FAQ 탭 - 실측 2026-07-17):
        # 텍스트 버튼이 없어 팝업 우상단 X(1090,137)로 닫습니다. 중앙 클릭 폴백이
        # 프로모션 썸네일을 눌러 다른 화면을 열지 않도록 폴백보다 먼저 처리합니다.
        Focus-Game -Game $Game
        Click-GamePoint -Game $Game -ReferenceX $ptNoticeBoardClose[0] -ReferenceY $ptNoticeBoardClose[1]
        Write-RunLog '[안내] 공지 보드 팝업 - 우상단 닫기(X) 클릭'
        Start-Sleep -Seconds 2
      } elseif (-not (Invoke-EventSkipOrConfirm -Game $Game)) {
        # 건너뛰기/확인 버튼이 둘 다 없는 화면. 처리 우선순위:
        # 1) 말풍선에 글자가 보이면 NPC 대화(알리사 도입 장면 등)로 보고 중앙 클릭으로 진행
        #    (대화가 길 수 있어 15회차까지 허용 - 실측 2026-07-17)
        # 2) 초반(1~5회)에는 말풍선이 없어도 NPC 장면 전환 중일 수 있어 중앙 클릭
        # 3) 후반(6회부터)에는 전체 화면 UI(인벤토리 등)로 보고 알려진 닫기(X) 위치를 순환 클릭
        #    (실측 2026-07-16~17: 화면 우상단/웹뷰 공지 보드/중앙 공지 팝업)
        # 어떤 시도든 로그를 남겨 '조용히 헤매는' 상황을 없앱니다.
        $bubbleText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgNpcDialogue[0] -ReferenceY $rgNpcDialogue[1] `
          -RegionWidth $rgNpcDialogue[2] -RegionHeight $rgNpcDialogue[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
        Focus-Game -Game $Game
        if ($bubbleText.Length -ge 2 -and $attempt -lt 15) {
          Click-GamePoint -Game $Game -ReferenceX $ptClearCenter[0] -ReferenceY $ptClearCenter[1]
          Write-RunLog "[안내] NPC 대화 진행 - 중앙 클릭 ($attempt/$maxAttempts)"
        } elseif ($attempt -ge 6) {
          $xCandidates = @(@(1229, 67), @(1090, 137), @(959, 180))
          $xPick = $xCandidates[($attempt - 6) % $xCandidates.Count]
          Click-GamePoint -Game $Game -ReferenceX $xPick[0] -ReferenceY $xPick[1]
          Write-RunLog "[안내] 알 수 없는 화면 - 닫기(X) 후보($($xPick[0]),$($xPick[1])) 클릭 시도 ($attempt/$maxAttempts)"
        } else {
          Click-GamePoint -Game $Game -ReferenceX $ptClearCenter[0] -ReferenceY $ptClearCenter[1]
          Write-RunLog "[안내] 알 수 없는 화면 - 중앙 클릭으로 진행 시도 ($attempt/$maxAttempts)"
        }
        Start-Sleep -Seconds 2
      }
    }
    if (Test-KnownScreen -Game $Game) {
      Write-RunLog '[안내] 이벤트 화면을 지나 원래 화면으로 복귀했습니다'
      return $true
    }
  }
  Write-RunLog '[경고] 이벤트 화면 자동 넘기기가 끝나지 않았습니다 - 그대로 진행합니다 (오류 시 Log의 스크린샷 확인)'
  return $true
}

function Resolve-DgEnterConfirmPopup {
  param([System.Diagnostics.Process]$Game)

  # '던전에 입장하시겠습니까?' 확인 팝업(도전 미수락 시 표시)이 떠 있으면
  # '일주일 동안 보지 않기'를 체크한 뒤 팝업의 입장하기를 눌러 진행합니다.
  # 팝업이 없으면 아무것도 하지 않고 false 를 돌려줍니다.
  $weekPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgDgWeekPopup[0] -ReferenceY $rgDgWeekPopup[1] `
    -RegionWidth $rgDgWeekPopup[2] -RegionHeight $rgDgWeekPopup[3] -Scale 4 -SearchText '일주일'
  if (-not $weekPoint) { return $false }
  # 체크박스는 '일주일' 글자 바로 왼쪽에 있습니다 (기준 좌표로 40px, 창 크기에 맞춰 환산)
  $rectWeek = New-Object HoneyNogiInput+RECT
  [HoneyNogiInput]::GetWindowRect($Game.MainWindowHandle, [ref]$rectWeek) | Out-Null
  $checkOffset = [int][Math]::Round(40 * ($rectWeek.Right - $rectWeek.Left) / $referenceWidth)
  Focus-Game -Game $Game
  Click-ScreenPoint -X ($weekPoint.X - $checkOffset) -Y $weekPoint.Y
  Write-RunLog "$($script:contentTag) 입장 확인 팝업 - '일주일 동안 보지 않기' 체크"
  Start-Sleep -Milliseconds 600
  Focus-Game -Game $Game
  Click-GamePoint -Game $Game -ReferenceX $ptDgConfirmEnter[0] -ReferenceY $ptDgConfirmEnter[1]
  Write-RunLog "$($script:contentTag) 입장 확인 팝업 - 입장하기 클릭"
  Start-Sleep -Milliseconds 1000
  return $true
}

function Get-DgCoinBalance {
  param([System.Diagnostics.Process]$Game)

  # 우상단 재화 표시줄을 읽어 은동전 잔량을 얻습니다. 골드 뒤의 마지막 숫자 그룹이
  # 은동전입니다 (은동전 아이콘이 '0'으로 붙어 '026'처럼 읽혀도 정수 변환으로 정리됨).
  # 읽기 실패 시 $null 을 돌려주고, 호출한 쪽에서 '알 수 없음'으로 처리합니다.
  if ($deepMode) {
    # 심층 공물 잔량: 좁은 영역(숫자만)은 '0'/'1' 같은 한 자리 고립 숫자가 OCR 미검출
    # (2026-07-30 01:42 / 07-29 20:02 두 환경 실측 - 사전 소진 감지가 생략됨).
    # 재화줄을 넓게 읽으면 공물 아이콘이 '뗳'으로 오독되며 값과 한 단어로 붙어 나옴
    # ('뗳0'/'뗳1'/'뗳3' - 캡처 6장 스윕 전수 일관). 단어 중심 x가 공물 자리(1080~1110)인
    # 단어의 끝 숫자를 채택하면 정답률 100%, 이웃(은동전 x≈1038·하트토큰 잡음 x≈1122)은
    # x 범위 밖이라 자연 배제 (리뷰 승인). 전 스케일 실패 시 아래 기존 방식으로 폴백.
    foreach ($balScale in @(4, 5, 3)) {
      $balWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX 960 -ReferenceY 45 `
          -RegionWidth 175 -RegionHeight 44 -Scale $balScale -Engine $ocrKoreanEngine)
      foreach ($balWord in $balWords) {
        $balText = ([string]$balWord.Text) -replace '[,\.]', ''
        if ([int]$balWord.X -ge 1080 -and [int]$balWord.X -le 1110 -and $balText -match '(\d{1,3})$') {
          $balValue = [int]$Matches[1]
          if ($balValue -le $dgBalanceMax) { return $balValue }
        }
      }
    }
  }
  $text = Get-GameRegionOcrText -Game $Game -ReferenceX $rgDgCoinBalance[0] -ReferenceY $rgDgCoinBalance[1] `
    -RegionWidth $rgDgCoinBalance[2] -RegionHeight $rgDgCoinBalance[3] -Scale 4 -Engine $ocrKoreanEngine
  # 금화 자릿수 구분(쉼표, OCR이 마침표로 읽기도 함)을 먼저 제거합니다.
  # 안 그러면 '10,994,078'이 [10][994][078]로 쪼개져 금화 조각이 '마지막 그룹'이 되고,
  # 은동전 숫자가 영역 밖으로 잘린 화면에서 그 조각을 잔량으로 오인합니다 (실측 재현: 잔량 0 오판).
  $cleaned = $text -replace '[,\.]', ''
  $numberGroups = [regex]::Matches($cleaned, '\d+')
  if ($numberGroups.Count -eq 0) { return $null }
  $lastGroup = $numberGroups[$numberGroups.Count - 1].Value
  # 6자리 초과면 은동전이 아니라 금화가 병합된 것(은동전 숫자가 안 읽힘)이므로 실패 처리
  if ($lastGroup.Length -gt 6) { return $null }
  $value = [int]$lastGroup
  # 게임 보유 상한(은동전 150 / 마족공물 15 - 2026-07-28 사용자 제보)을 넘는 판독은 오독
  # 확정(하트토큰/골드 조각 오인 등)이므로 실패 처리합니다 - null = 검사 생략 진행(안전측)
  if ($value -gt $dgBalanceMax) { return $null }
  return $value
}

function Get-DgTributeCost {
  param([System.Diagnostics.Process]$Game, [int[]]$ValidCosts = @(10, 20))

  # '입장하기' 버튼에 표시되는 공물(은동전) 소모량을 읽습니다. 소탕만이면 10,
  # 더블 루팅까지면 20입니다. 숫자만 좁게 자르면 고립 숫자라 OCR이 실패해서
  # 아이콘+'입장하기' 텍스트까지 함께 읽고 숫자 그룹만 뽑습니다. 10/20 중 하나가
  # 잡히면 우선 그 값을, 아니면 마지막 숫자 그룹을 돌려줍니다. 실패 시 $null.
  # 숫자가 한 번에 안 잡히는 경우가 있어 스케일/엔진을 바꿔가며 재시도합니다.
  # (01:45 실기로 커서 호버 이론이 반증되어 판독 전 커서 파킹은 제거 - 리뷰 지시.
  #  카드를 끈 직후의 '1' 지속은 게임 자체의 표시 지연이며, 호출부가 '방금 전환 확인' 시
  #  검증을 생략하는 것으로 대응)
  # IME 팝업이 입장 버튼(소모량 표시 자리)을 덮으면 팝업 글자의 오독 숫자('전환하己1면'의
  # '1' 등)가 소모량으로 잡히는 실사고가 있어(2026-07-29 00:48 - 10초 내내 '1' 판독 → 오정지),
  # 팝업 중에는 판독 불가($null)로 처리하고 $script:dgCostImeBlocked 로 사유를 남깁니다.
  # 판독 영역이 팝업 안쪽 조각이라 조각 복합 판별이 안 통해, 전용 ROI 판별을 사용합니다.
  $script:dgCostImeBlocked = $false
  if (Test-DgImePopupVisible -Game $Game) {
    $script:dgCostImeBlocked = $true
    return $null
  }
  $attempts = @(
    @{ Scale = 3; Engine = $ocrKoreanEngine },
    @{ Scale = 5; Engine = $ocrKoreanEngine },
    @{ Scale = 3; Engine = $ocrEnglishEngine },
    @{ Scale = 5; Engine = $ocrEnglishEngine }
  )
  $fallbackValue = $null
  foreach ($attempt in $attempts) {
    $text = Get-GameRegionOcrText -Game $Game -ReferenceX $rgDgTributeCost[0] -ReferenceY $rgDgTributeCost[1] `
      -RegionWidth $rgDgTributeCost[2] -RegionHeight $rgDgTributeCost[3] -Scale $attempt.Scale -Engine $attempt.Engine
    $numberGroups = [regex]::Matches($text, '\d+')
    if ($numberGroups.Count -eq 0) { continue }
    foreach ($grp in $numberGroups) {
      $n = [int]$grp.Value
      if ($ValidCosts -contains $n) { return $n }   # 던전 10/20, 심층 1/2 (호출부 주입)
      # 공물 뿔 아이콘이 '7'로 읽혀 숫자 앞에 붙는 이형 (2026-07-28 23:40 실기 '71' - 아이콘
      # 제외 영역에서도 렌더링 순간에 드물게 발생): 앞의 7을 떼서 유효값이면 그 값을 채택
      if ($grp.Value -match '^7(\d+)$' -and $ValidCosts -contains [int]$Matches[1]) { return [int]$Matches[1] }
    }
    # 유효값(10/20)은 아니지만 숫자는 읽힌 경우: 첫 성공 읽기를 예비로 보관
    if ($null -eq $fallbackValue) { $fallbackValue = [int]$numberGroups[$numberGroups.Count - 1].Value }
  }
  return $fallbackValue
}

function Find-DgRetryButtonPoint {
  param([System.Diagnostics.Process]$Game)

  # 결과 화면의 '다시 하기' 버튼을 찾습니다. OCR이 '다시'를 '다셔'로 깨뜨리거나
  # 기본 배율(3)에서는 '하기'만 읽는 경우가 있어(실측) 배율 5로 여러 후보를 찾습니다.
  # ('하기'는 이 영역에 다시 하기 버튼 글자만 들어와 안전 - 나가기는 영역 밖 + '가기')
  foreach ($searchWord in @('다시', '다셔', '하기')) {
    $point = Find-GameTextPoint -Game $Game -ReferenceX $rgDgRetryBtn[0] -ReferenceY $rgDgRetryBtn[1] `
      -RegionWidth $rgDgRetryBtn[2] -RegionHeight $rgDgRetryBtn[3] -SearchText $searchWord -Scale 5
    if ($point) { return $point }
  }
  return $null
}

function Find-DgNextFloorButtonPoint {
  param([System.Diagnostics.Process]$Game)

  # 결과 화면의 '다음 층으로' 버튼을 찾습니다 (1-3 결과 화면: 나가기/다시 하기/다음 층으로
  # 3버튼의 오른쪽). '다시 하기'와 같은 줄이라 rgDgRetryBtn 영역을 그대로 씁니다.
  # 커스텀 반복 마무리 v4 전용: 현재 1-3 → 다음 항목 2층이면 이 버튼으로 2층 구역 선택
  # 화면에 넘어갑니다 (2026-07-20 실측. 결과 화면 '나가기'는 필드로 나가버려 금지).
  # '층으' 조각을 우선 찾고('다시 하기'/'나가기'에는 없는 글자), '층'이 깨질 때를 대비해
  # '다음층'/'다음'도 후보로 봅니다 (이 영역에서 '다음~'으로 시작하는 글자는 세 번째 버튼뿐).
  foreach ($searchWord in @('층으', '다음층', '다음')) {
    $point = Find-GameTextPoint -Game $Game -ReferenceX $rgDgRetryBtn[0] -ReferenceY $rgDgRetryBtn[1] `
      -RegionWidth $rgDgRetryBtn[2] -RegionHeight $rgDgRetryBtn[3] -SearchText $searchWord -Scale 5
    if ($point) { return $point }
  }
  return $null
}

function Find-HtNewMissionPoint {
  param([System.Diagnostics.Process]$Game)

  # 사냥터 결과 화면의 '새 임무 선택' 버튼을 찾습니다 (2026-07-17 실측: 던전과 달리
  # 나가기/머무르기/새 임무 선택 3버튼). 같은 영역의 '머무르기'/'나가기'에는 없는
  # '임무' 글자를 우선 찾고, OCR 깨짐 대비로 '선택'도 후보로 봅니다.
  foreach ($searchWord in @('임무', '선택')) {
    $point = Find-GameTextPoint -Game $Game -ReferenceX $rgHtRetryBtn[0] -ReferenceY $rgHtRetryBtn[1] `
      -RegionWidth $rgHtRetryBtn[2] -RegionHeight $rgHtRetryBtn[3] -SearchText $searchWord -Scale 5
    if ($point) { return $point }
  }
  return $null
}

function Exit-HuntingGroundExhausted {
  param([System.Diagnostics.Process]$Game, [string]$Reason)

  # 은동전 소진 시 사냥터를 완전히 벗어나고 자동화를 마칩니다 (사용자 결정 2026-07-18).
  # 첫 화면이면 X로 닫는데, 첫 화면이 결과 화면 위에 열려 있던 경우('새 임무 선택' 경유)
  # X를 닫으면 밑의 결과 화면이 다시 나오므로(2026-07-18 01:05 실측) 결과 화면이
  # 보이면 나가기 버튼까지 눌러 사냥터 밖(필드)으로 나갑니다.
  Write-RunLog "[완료] $Reason - 사냥터에서 나가고 자동화를 마칩니다"
  if (Find-HtEntryButtonPoint -Game $Game) {
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ptHtClose[0] -ReferenceY $ptHtClose[1]
    Start-Sleep -Seconds 2
  }
  if (Find-HtNewMissionPoint -Game $Game) {
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ptDgResultExit[0] -ReferenceY $ptDgResultExit[1]
    Write-RunLog '[사냥터] 결과 화면 나가기 클릭 (사냥터 밖으로)'
    Start-Sleep -Seconds 2
  }
  exit 4
}

function Find-HtEntryButtonPoint {
  param([System.Diagnostics.Process]$Game)

  # 사냥터 첫 화면 하단 우측 버튼을 찾습니다. 첫 진입 때는 '(은동전 10) 입장하기'인데,
  # '새 임무 선택'으로 복귀하면 다음 임무가 자동 선택되며 '(은동전 10) 임무 시작'으로
  # 바뀝니다 (2026-07-18 00:01 실측 - '입장'만 찾다 복귀를 인식 못 한 사고).
  # '시작'이 OCR에서 깨질 수 있어('ÅI즈' 실측) 같은 버튼의 '임무'도 후보로 봅니다.
  # (결과 화면에는 이 영역에 아무 버튼도 없어 '임무' 오탐 없음 - 실측 확인)
  foreach ($searchWord in @('입장', '임무', '시작')) {
    $point = Find-GameTextPoint -Game $Game -ReferenceX $rgHtEnterBtn[0] -ReferenceY $rgHtEnterBtn[1] `
      -RegionWidth $rgHtEnterBtn[2] -RegionHeight $rgHtEnterBtn[3] -SearchText $searchWord
    if ($point) { return $point }
  }
  return $null
}

# ===== 어비스/던전/사냥터 공통 블록 (2026-07-18 기술 부채 정리: 복사 코드 → 헬퍼 통일) =====

function Close-CurrencyOverviewScreen {
  param([System.Diagnostics.Process]$Game)

  # '보유한 재화' 전체 화면을 감지해 우상단 X 로 닫습니다. 닫았으면 $true.
  # (2026-08-02 22:02 실사고: 커서 간섭 오클릭이 재화줄을 눌러 이 화면이 열렸고 클리어
  #  대기가 가려짐 - 라이브 캡처 실측: 좌상단 제목 '보유한 재화', 우상단 X ≈ (1228,67)).
  # 제목을 좁은 ROI 에서 엄격히 확인한 경우에만 닫습니다 (리뷰 조건 - 오탐 클릭 금지).
  # 클릭은 커서 확인 게이트(Click-ScreenPoint)가 지키므로 간섭 중엔 다음 폴링에서 재시도.
  if ($script:screenCaptureFailing) { return $false }
  # '보유한'은 s3 에서 '모유한'으로 깨짐(실측) → '유한'+'재화' 조각 조합으로 판정
  # (좌상단 제목 전용 ROI 라 다른 화면 오탐 없음 - 보관 93장 스윕 0건)
  $ccTitle = (Get-GameRegionOcrText -Game $Game -ReferenceX 25 -ReferenceY 45 `
      -RegionWidth 260 -RegionHeight 50 -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if (-not (($ccTitle.Contains('보유') -or $ccTitle.Contains('유한')) -and $ccTitle.Contains('재화'))) { return $false }
  Write-RunLog "$($script:contentTag) '보유한 재화' 화면 감지(오클릭 추정) - 닫기(X) 클릭"
  Focus-Game -Game $Game
  Click-GamePoint -Game $Game -ReferenceX 1228 -ReferenceY 67
  Start-Sleep -Seconds 1
  return $true
}

function Test-CoopMissionBoardTitle {
  param([string]$TitleText)

  # 친구 창 '협동 미션' 전체 화면의 좌상단 제목 판정 (순수 - 진리표 테스트 대상):
  # '협동' AND ('미션' OR '미선'). '미선' = 1810x1020 창 s3 실측 깨짐 (2026-08-03 KJM PC
  # 오류 캡처 - '협동'(194,64)+'미선'(250,62)). '미.' 같은 광범위 완화는 금지 - 실측된
  # 이형만 정확히 허용합니다 (리뷰 조건). '협동' 조각은 두 배율 음성 스윕에서 0건이라
  # 이형 추가로 오탐면이 늘지 않음.
  $t = ([string]$TitleText) -replace '\s', ''
  return [bool]($t.Contains('협동') -and ($t.Contains('미션') -or $t.Contains('미선')))
}

function Test-CoopMissionBoardVisible {
  param([System.Diagnostics.Process]$Game)

  # 협동 미션 전체 창의 제목 ROI(120,45,220,50)를 s3→s4 사다리로 판독합니다.
  # 판정(Test-CoopMissionBoardTitle)이 참일 때만 조기 종료 - 빈/깨진 판독은 다음 배율로
  # 넘어갑니다 (리뷰 조건: 'OCR 비어 있지 않음'이 아니라 '판정 참'이 종료 조건).
  # 실측: 1272 창 = s3 즉시('협동'+'미션') / 1810 창 = s3 '미선' 이형 채택, s4 정상 판독.
  # 단일 배율 함정(카드/알약/협동 확인 버튼 실사고 반복) 방지를 위한 이중 배율입니다.
  foreach ($boardScale in @(3, 4)) {
    $boardTitle = Get-GameRegionOcrText -Game $Game -ReferenceX 120 -ReferenceY 45 `
      -RegionWidth 220 -RegionHeight 50 -Scale $boardScale -Engine $ocrKoreanEngine
    if (Test-CoopMissionBoardTitle -TitleText $boardTitle) { return $true }
  }
  return $false
}

function Close-CoopMissionBoardScreen {
  param(
    [System.Diagnostics.Process]$Game,
    [string]$LogPrefix = ''
  )

  # 친구 창의 '협동 미션' 전체 화면(참여 가능 미션 목록)을 감지해 우상단 X 로 닫습니다.
  # (2026-08-03 06:02 실사고 2건: 월요일 06:00 주간 리셋이 이 전체 창을 자동으로 띄워
  #  '다시 하기' 복귀 대기가 40초 가려짐 - 개발 PC(1272)는 3연속 오류 후 범용 X 후보가
  #  우연히 닫아 자가 복구, KJM PC(1810, v1.2.0)는 재시도 없이 그대로 정지. 기존
  #  Close-WeeklyCoopResetPopup 은 '새로운 한 주' 팝업의 하단 버튼 줄용이라 이 전체 창은
  #  매칭 불가 - 두 PC 로그 모두 미발동 확인.)
  # 완료 팝업(Close-CoopMissionScreen)과는 다른 화면 - 그 제목은 화면 중앙이라 이 ROI 밖.
  # X(1228,67)는 '보유한 재화' 창과 동일 위치 (1272/1810 두 캡처 실측 일치).
  if ($script:screenCaptureFailing) { return $false }
  if (-not (Test-CoopMissionBoardVisible -Game $Game)) { return $false }
  Focus-Game -Game $Game
  # 전면화 사이 화면이 바뀔 수 있어 재확인 후에만 X 클릭 (스테일 클릭 방지 - 리뷰 조건.
  # 주 1회 리셋에만 도달하는 분기라 추가 OCR 비용은 사실상 없음)
  if (-not (Test-CoopMissionBoardVisible -Game $Game)) { return $false }
  Click-GamePoint -Game $Game -ReferenceX 1228 -ReferenceY 67
  Write-RunLog "[안내] ${LogPrefix}협동 미션 전체 창 감지(주간 리셋 추정) - 닫기(X) 클릭"
  Start-Sleep -Seconds 2
  return $true
}

function Select-NetworkRetryWord {
  param($Words)

  # 네트워크 불안정 팝업의 '다시 시도하기'(우측 녹색) 버튼 단어를 고릅니다 (순수 - 진리표
  # 대상). '도하기' 조각 + 위치 게이트(X>=640, Y 585~655): 실측(2026-08-01 KJM 캡처 3장)
  # s3 'kl도하기'(764,619) / s4 '人I도하기'(764,619) - '시도' 조각은 깨짐이 불안정하지만
  # '도하기'는 양 배율 생존. 좌측 '시작 화면으로'(488~550,619)는 타이틀 화면 이탈이라
  # 절대 선택 금지 - X 게이트가 원천 차단합니다. 반환: @{ X; Y } (기준 좌표) 또는 $null
  foreach ($word in $Words) {
    if (-not ([string]$word.Text).Contains('도하기')) { continue }
    $wordX = [int]$word.X
    $wordY = [int]$word.Y
    if ($wordX -ge 640 -and $wordY -ge 585 -and $wordY -le 655) {
      return @{ X = $wordX; Y = $wordY }
    }
  }
  return $null
}

function Close-NetworkUnstablePopup {
  param(
    [System.Diagnostics.Process]$Game,
    [string]$LogPrefix = ''
  )

  # '네트워크 연결이 불안정합니다' 팝업에서 '다시 시도하기'를 클릭해 재접속을 시도합니다.
  # (2026-08-01 KJM PC 실사고: 심층 클리어 대기 중 발생 → 전용 처리가 없어 600초 통째
  #  소진 + 재시작 워커의 알 수 없는 화면 클릭 20회 전부 빗나감 → 3연속 정지.)
  # 감지: 제목 ROI(420,355,440,70) s3 '네트워크'+'불안정' 엄격 확인 (실측: '네트워크'
  #  (532,389) '불안정합니다'(718,389), s4 '불안정합LI다'도 조각 생존. '연결' 완화는
  #  다른 연결 오류 팝업 오포섭 위험으로 기각 - 리뷰 조건).
  # 버튼: rgClearExit 를 s3→s4 로 읽어 Select-NetworkRetryWord 로 선택, 전 배율 실패 시
  #  실측 예비 좌표(743,620 = 버튼 중심). 클릭 직전 제목 재확인(전면화 사이 팝업이 사라지면
  #  예비 좌표가 밑 화면을 누르는 사고 방지 - 리뷰 조건). 단어 좌표는 기준 좌표이므로
  #  반드시 Click-GamePoint 로 클릭 (Click-ScreenPoint 직결 금지 - 리뷰 지적).
  # Space 배지가 있지만 위험 화면 오입력 금지 정책상 키 대신 상태 확정 클릭.
  # 재접속 실패로 팝업이 다시 떠도 다음 폴링이 같은 게이트로 재클릭(자연 재시도),
  # 네트워크가 진짜 죽어 있으면 기존 대기 한도가 오류로 정지 (최후 방어 현행 유지).
  if ($script:screenCaptureFailing) { return $false }
  $netTitle = (Get-GameRegionOcrText -Game $Game -ReferenceX 420 -ReferenceY 355 `
      -RegionWidth 440 -RegionHeight 70 -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if (-not ($netTitle.Contains('네트워크') -and $netTitle.Contains('불안정'))) { return $false }
  # 버튼 후보 결정 (s3→s4 사다리 - 제목이 확정된 실제 팝업에서만 실행되므로 평시 비용 없음)
  $retryWord = $null
  foreach ($netScale in @(3, 4)) {
    $netWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] `
        -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -Scale $netScale -Engine $ocrKoreanEngine)
    $retryWord = Select-NetworkRetryWord -Words $netWords
    if ($retryWord) { break }
  }
  Focus-Game -Game $Game
  # 전면화 사이 화면이 바뀌었으면 클릭 금지 (제목 재확인 - 특히 예비 좌표 오클릭 방지)
  $netTitle = (Get-GameRegionOcrText -Game $Game -ReferenceX 420 -ReferenceY 355 `
      -RegionWidth 440 -RegionHeight 70 -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if (-not ($netTitle.Contains('네트워크') -and $netTitle.Contains('불안정'))) { return $false }
  if ($retryWord) {
    Click-GamePoint -Game $Game -ReferenceX ([int]$retryWord.X) -ReferenceY ([int]$retryWord.Y)
  } else {
    Click-GamePoint -Game $Game -ReferenceX 743 -ReferenceY 620   # '다시 시도하기' 중심 실측 예비 (제목 재확정 전제)
  }
  Write-RunLog "[안내] ${LogPrefix}네트워크 불안정 팝업 감지 - '다시 시도하기' 클릭 (재접속 시도)"
  Start-Sleep -Seconds 3
  return $true
}

function Close-CoopMissionScreen {
  param([System.Diagnostics.Process]$Game)

  # 협동 미션 완료 전체 화면을 감지해 '확인'을 클릭합니다. 닫았으면 $true, 아니면 $false.
  # (2026-07-30 캡처 실측 - 던전이미지\어시스트\협동미션완료_확인버튼.png)
  # 제목 '협동 미션 완료'는 OCR이 '협동1/四완로'로 심하게 깨져 쓸 수 없고, 부제
  # '아이템은 대표 캐릭터가 위치한 서버 우편으로 전송됩니다.'는 단어별로 정확히 판독됩니다
  # → 이 화면 전용 문구인 부제 조각으로 감지합니다 (보관 캡처 92장 오탐 0 실측).
  # 확인 버튼은 퀘스트 보상 화면과 같은 자리(중심 636,654)라 같은 영역을 재사용합니다.
  # Space 배지가 있지만 위험 화면 오입력 금지 정책상 키는 쓰지 않습니다 (상태 기반 클릭).
  #
  # 입장/매칭 대기(Invoke-PurchasePopupSweep)와 클리어 대기 루프가 공용합니다 - 협동 미션은
  # 몬스터 처치 누적으로 완료되므로 정작 전투/클리어 대기 중에 뜰 확률이 가장 높은데, 클리어
  # 대기 루프는 스윕이 아니라 자체 팝업 처리를 써서 이 화면이 안 닫혔습니다 (2026-07-31 점검).
  # 주의: 반환값이 파이프라인에 새지 않도록 호출부에서 반드시 소비해야 합니다 (PS 5.1).
  $coopText = (Get-GameRegionOcrText -Game $Game -ReferenceX 360 -ReferenceY 285 `
      -RegionWidth 560 -RegionHeight 35 -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if (-not (($coopText.Contains('우편으로') -and $coopText.Contains('전송')) -or $coopText.Contains('캐릭터가위치한'))) {
    return $false
  }
  # '확인' 버튼 탐색: 다중 스케일 3→4→5 (2026-08-01 실사고 - 기본 s3 은 이 버튼을
  # '>poce'/'할인'으로 깨뜨려 두 밤 연속 라이브 미감지. s4 는 오류 캡처 2장 모두 정상 판독.
  # 카드 버튼 '서대되'와 같은 단일 배율 결함 - 리뷰 승인)
  $coopConfirmPoint = $null
  foreach ($coopBtnScale in @(3, 4, 5)) {
    $coopConfirmPoint = Find-GameTextPoint -Game $Game -ReferenceX 400 -ReferenceY 628 `
      -RegionWidth 470 -RegionHeight 55 -SearchText '확인' -Scale $coopBtnScale
    if ($coopConfirmPoint) { break }
  }
  if ($coopConfirmPoint) {
    Focus-Game -Game $Game
    Click-ScreenPoint -X $coopConfirmPoint.X -Y $coopConfirmPoint.Y
    Write-RunLog "$($script:contentTag) 협동 미션 완료 화면 감지 - 확인 클릭"
    Start-Sleep -Seconds 1
    return $true
  }
  # 전 배율 실패 폴백: 실측 고정 좌표 (2026-07-30 실측 확인 버튼 중심 636,654).
  # 부제로 화면이 확정된 상태지만, 클릭 직전 부제를 한 번 더 재확인해 그 사이 화면 전환을
  # 배제합니다 (상태 기반 클릭 원칙 - 리뷰 조건: 재확인 성공 시에만 폴백 실행)
  $coopRecheck = (Get-GameRegionOcrText -Game $Game -ReferenceX 360 -ReferenceY 285 `
      -RegionWidth 560 -RegionHeight 35 -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if ((($coopRecheck.Contains('우편으로') -and $coopRecheck.Contains('전송')) -or $coopRecheck.Contains('캐릭터가위치한'))) {
    Write-RunLog "$($script:contentTag) 협동 미션 완료 화면 감지 - 확인 글자 탐색 실패, 실측 좌표로 클릭 (부제 재확인 완료)"
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX 636 -ReferenceY 654
    Start-Sleep -Seconds 1
    return $true
  }
  return $false
}

function Invoke-PurchasePopupSweep {
  param([System.Diagnostics.Process]$Game)

  # 구매 제안 팝업(회복 물약 부족 등)이 떠 있으면 '닫기'를 눌러 닫습니다. 닫았으면 $true.
  # 입장/매칭 대기 루프용 (2026-07-28 실기 20:45: 심층 입장 직후 물약 팝업이 화면을 덮어
  # HUD/퀘스트 기반 입장 완료 감지가 45초 내내 가려짐 - 클리어 대기 루프와 입장 직후 키
  # 입력에는 같은 처리가 있었지만 입장 대기 루프들에는 없었음). 캡처 실패 중에는 무동작.
  # 주의: Wait-ForScreen 의 Condition 안에서 쓸 때는 반환값이 파이프라인에 새어 나가
  # 대기 성공으로 오판되지 않게 `if (Invoke-PurchasePopupSweep ...) { return $false }`
  # 계약으로 소비해야 합니다 (리뷰 지적 - PS 5.1 스크립트블록 출력 오염).
  if ($script:screenCaptureFailing) { return $false }
  $sweepPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgPopupClose[0] -ReferenceY $rgPopupClose[1] `
    -RegionWidth $rgPopupClose[2] -RegionHeight $rgPopupClose[3] -SearchText '닫기'
  if ($sweepPoint) {
    Focus-Game -Game $Game
    Click-ScreenPoint -X $sweepPoint.X -Y $sweepPoint.Y
    Write-RunLog '[안내] 구매 팝업 감지 - 닫기 클릭 (입장 대기 중)'
    Start-Sleep -Seconds 1
    return $true
  }
  # 퀘스트 클리어 보상 전체 화면 (2026-07-28 23:12 실기: 입장 로딩 중 '법황청의 특별 의뢰'
  # 완료 화면이 덮여 입장 감지가 45초 내내 가려짐). 하단 안내 문구('아이템을 누르면 상세
  # 정보...')가 이 화면 전용이라 그 문구가 보일 때만 '확인' 버튼 글자를 찾아 클릭합니다.
  # Space 배지가 있지만 위험 화면 오입력 금지 정책상 키 입력은 쓰지 않음 (상태 기반 클릭).
  $bottomText = (Get-GameOcrText -Game $Game) -replace '\s', ''
  if ($bottomText.Contains('아이템을누르') -or $bottomText.Contains('상세정보')) {
    $confirmPoint = Find-GameTextPoint -Game $Game -ReferenceX 400 -ReferenceY 628 `
      -RegionWidth 470 -RegionHeight 55 -SearchText '확인'
    if ($confirmPoint) {
      Focus-Game -Game $Game
      Click-ScreenPoint -X $confirmPoint.X -Y $confirmPoint.Y
      Write-RunLog '[안내] 퀘스트 클리어 보상 화면 감지 - 확인 클릭 (입장 대기 중)'
      Start-Sleep -Seconds 1
      return $true
    }
  }
  # 협동 미션 완료 전체 화면 (공용 소함수 - 클리어 대기 루프도 같은 함수를 씁니다)
  if (Close-CoopMissionScreen -Game $Game) { return $true }
  # 주간 리셋이 자동으로 띄우는 협동 미션 전체 창 (2026-08-03 06:02 실사고 - 이 스윕을
  # 쓰는 입장/매칭 대기·복귀 대기·시작 판정이 일괄 커버됩니다)
  if (Close-CoopMissionBoardScreen -Game $Game) { return $true }
  # 네트워크 불안정 팝업 - '다시 시도하기'로 재접속 (2026-08-01 KJM PC 실사고)
  if (Close-NetworkUnstablePopup -Game $Game) { return $true }
  return $false
}

function Invoke-AfterEntryKeys {
  param([System.Diagnostics.Process]$Game, [string]$LogPrefix)

  # 입장 직후 키 입력: config.json 의 afterEntry.keys 중 enabled 인 키만 순서대로 한 번씩
  # 입력합니다 (예: 음식 자동 먹기(B)를 끄려면 해당 항목의 enabled 를 false 로).
  # 어비스 본류/파티원/던전/사냥터 네 흐름이 같은 동작을 씁니다.
  #
  # 키 입력 전 구매 제안 팝업 사전 처리 (2026-07-28 실기: 물약 부족 상태로 입장하면 구매
  # 팝업이 이미 떠 있어 B(음식) 키가 팝업에 먹혀 음식을 못 먹음 - 02:56 로그 실측. 클리어
  # 대기 루프의 팝업 감시는 키 입력 '이후'라 못 막았음). 확인 최대 4회 = 닫기 최대 3회 +
  # 마지막 재확인 - 무팝업이면 OCR 1회만 추가 (설계 합의 계약). 캡처 실패 중이면 사전
  # 처리를 건너뛰고 바로 키 입력 (실패를 '팝업 잔존'으로 오인 금지 - 리뷰 지적).
  # 키 입력 후 재입력은 하지 않음 - 팝업이 키보다 늦게 떴다면 키는 이미 전달된 것이고,
  # B 재입력은 음식 중복 소모 위험 (상태 확인 없는 재입력 금지 정책).
  if (-not $script:screenCaptureFailing) {
    $entryPopupClicks = 0
    $entryPopupRemains = $false
    for ($popupTry = 1; $popupTry -le 4; $popupTry++) {
      $entryPopupPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgPopupClose[0] -ReferenceY $rgPopupClose[1] `
        -RegionWidth $rgPopupClose[2] -RegionHeight $rgPopupClose[3] -SearchText '닫기'
      if (-not $entryPopupPoint) { break }
      if ($popupTry -ge 4) { $entryPopupRemains = $true; break }   # 3회 닫고도 남아 있음
      Focus-Game -Game $Game
      Click-ScreenPoint -X $entryPopupPoint.X -Y $entryPopupPoint.Y
      $entryPopupClicks++
      Start-Sleep -Seconds 1
    }
    if ($entryPopupClicks -gt 0) {
      if ($entryPopupRemains) {
        Write-RunLog "[경고] 구매 팝업이 닫히지 않습니다 - 키 입력을 진행하고 클리어 대기 중 다시 닫기를 시도합니다"
      } else {
        Write-RunLog "$LogPrefix 구매 팝업 감지 - 닫은 뒤 키 입력 진행"
      }
    }
  }
  Focus-Game -Game $Game
  for ($keyIndex = 0; $keyIndex -lt $afterEntryActions.Count; $keyIndex++) {
    if ($keyIndex -gt 0) { Start-Sleep -Milliseconds $afterEntryDelayMs }
    $action = $afterEntryActions[$keyIndex]
    Press-KeyOnce -VirtualKey ([byte]$action.Key)
    Write-RunLog ("{0} {1} ({2} 키 입력완료)" -f $LogPrefix, $action.Label, (Get-KeyDisplayName $action.Key))
  }
}

function Wait-ForResultScreen {
  param(
    [System.Diagnostics.Process]$Game,
    [scriptblock]$FindRetryButton,
    [string]$MissingMessage
  )

  # 클리어 터치 후 엔딩 컷신을 넘기며 결과 화면을 기다립니다 (던전/사냥터 공통).
  #  - 컷신 '장면 넘기기' 클릭 (탐색이 캡처 상태 탐침을 겸함 - 실패 중에는 제한 시간 동결)
  #  - 클리어 터치가 등급 연출에 무시된 경우 '화면을 터치'가 남아 있으면 재터치
  #  - 은동전 소탕의 전리품 공개 화면은 '발견한 전리품' 라벨 지점 클릭으로 진행
  #    (라벨은 카드/버튼이 아니라 어디를 눌러도 진행만 되는 안전한 지점)
  # 반환: 반복 버튼 지점(던전 = 다시 하기 / 사냥터 = 새 임무 선택). 못 찾으면 throw.
  $resultDeadline = (Get-Date).AddSeconds(90)
  $retryPoint = $null
  while ((Get-Date) -lt $resultDeadline) {
    $skipScene = Find-GameTextPoint -Game $Game -ReferenceX $rgCutsceneTop[0] -ReferenceY $rgCutsceneTop[1] `
      -RegionWidth $rgCutsceneTop[2] -RegionHeight $rgCutsceneTop[3] -SearchText '넘기'
    if ($script:screenCaptureFailing) {
      Test-SafeStopDuringCaptureFail
      $resultDeadline = (Get-Date).AddSeconds(90)
      Start-Sleep -Seconds 2
      continue
    }
    if ($skipScene) {
      # 컷신이 그 사이 끝났을 수 있으므로 클릭 직전에 한 번 더 확인 (스테일 클릭 방지)
      $skipScene = Find-GameTextPoint -Game $Game -ReferenceX $rgCutsceneTop[0] -ReferenceY $rgCutsceneTop[1] `
        -RegionWidth $rgCutsceneTop[2] -RegionHeight $rgCutsceneTop[3] -SearchText '넘기'
    }
    if ($skipScene) {
      Focus-Game -Game $Game
      Click-ScreenPoint -X $skipScene.X -Y $skipScene.Y
      Write-RunLog "$($script:contentTag) 컷신 - 장면 넘기기 클릭"
      Start-Sleep -Seconds 2
      continue
    }
    if (Test-DungeonClearPrompt -Game $Game) {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptClearCenter[0] -ReferenceY $ptClearCenter[1]
      Write-RunLog "$($script:contentTag) 클리어 화면이 남아 있어 다시 터치"
      Start-Sleep -Seconds 2
      continue
    }
    # 네트워크 불안정 팝업 - 반복 버튼 탐색('다시/다셔/하기')과 어휘가 겹치므로 그보다 먼저
    # 처리합니다 (리뷰 조건 - 클리어 대기와 같은 계약)
    if (Close-NetworkUnstablePopup -Game $Game -LogPrefix "$($script:contentTag) ") { continue }

    $retryPoint = & $FindRetryButton
    if ($retryPoint) { break }

    $lootLabelPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgDgLootReveal[0] -ReferenceY $rgDgLootReveal[1] `
      -RegionWidth $rgDgLootReveal[2] -RegionHeight $rgDgLootReveal[3] -SearchText '발견'
    if ($lootLabelPoint) {
      Focus-Game -Game $Game
      # 라벨 지점을 그대로 클릭하면 게임 커서가 라벨 위에 주차돼 다음 폴링부터 OCR이
      # 라벨을 못 읽어 진행 클릭이 멈춥니다 (2026-07-19 08:26 실측: '발견한전'으로 판독,
      # 82초 방치 후 시간 초과). 어디를 눌러도 진행되는 화면이므로 라벨/카드에서 떨어진
      # 빈 배경(400,300)을 클릭해 커서가 감지를 가리지 않게 합니다.
      # 탐색어도 '발견' 조각으로 완화 (다른 요인으로 라벨 일부가 가려져도 감지 유지).
      Click-GamePoint -Game $Game -ReferenceX 400 -ReferenceY 300
      Write-RunLog "$($script:contentTag) 전리품 공개 화면 - 화면 클릭으로 진행"
      Start-Sleep -Seconds 2
      continue
    }
    # 오클릭으로 열린 '보유한 재화' 전체 화면 정리 (2026-08-02 실사고 - 결과 대기도 가려짐)
    if (Close-CurrencyOverviewScreen -Game $Game) { continue }
    # 월요일 06:00 주간 리셋 블로커 2종 - 클리어 직후~결과 화면 사이(최대 90초)에 리셋이
    # 걸리면 결과 대기도 같은 방식으로 가려짐 (2026-08-03 06:02 실사고의 배선 확장 - 리뷰 권고)
    if (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix "$($script:contentTag) ") { continue }
    if (Close-CoopMissionBoardScreen -Game $Game -LogPrefix "$($script:contentTag) ") { continue }
    Start-Sleep -Seconds 2
  }
  if (-not $retryPoint) {
    # 타임아웃 시점에 클리어 화면이 '여전히' 보이면 = 수십 회 터치가 전부 무시된 것 - 게임
    # 클라이언트 무응답(로딩 멈춤) 가능성이 높아 원인을 알 수 있는 문구로 바꿉니다
    # (2026-08-02 타 PC 제보: 프리즈 상태에서 50+회 클릭 불변 → 기존 문구로는 원인 불명.
    # 리뷰 조건: 이 시점에 새로 재판정해 유지 확인된 경우만 교체, 아니면 기존 문구 폴백)
    if ((-not $script:screenCaptureFailing) -and (Test-DungeonClearPrompt -Game $Game)) {
      throw '클리어 화면이 터치에 반응하지 않습니다 - 게임이 응답 없음(로딩 멈춤) 상태로 보입니다. 게임을 재시작한 뒤 다시 시작해 주세요.'
    }
    throw $MissingMessage
  }
  return $retryPoint
}

function Invoke-SafeStopExitIfRequested {
  param([System.Diagnostics.Process]$Game)

  # 결과 화면에서 안전 중지 예약이 있으면 나가기를 눌러 회차를 마칩니다 (던전/사냥터 공통).
  # 신호 파일은 워커가 소비(삭제)합니다 - GUI가 강제 종료되어 파일이 남아도
  # 다음 실행이 시작하자마자 헛되이 조기 종료되는 일이 없게 하기 위함입니다.
  if (-not (Test-Path -LiteralPath $safeStopFlagPath)) { return }
  Remove-Item -LiteralPath $safeStopFlagPath -Force -ErrorAction SilentlyContinue
  Focus-Game -Game $Game
  Click-GamePoint -Game $Game -ReferenceX $ptDgResultExit[0] -ReferenceY $ptDgResultExit[1]
  if ($script:customCleanupOnly) {
    # 커스텀 새 시작 정리 모드: 이 판은 사용자가 수동으로 돌린 것이라 코드 0으로 끝내면
    # GUI가 항목 완료로 오계상합니다 - 준비 실행(코드 10)으로 마칩니다.
    Write-RunLog '[완료] 안전 중지 예약 확인 - 수동 진행분 정리 중이라 판으로 계상하지 않고 마칩니다 (준비 실행)'
    Start-Sleep -Seconds 2
    exit 10
  }
  Write-RunLog '[완료] 안전 중지 예약 확인 - 결과 화면에서 나가기를 눌러 회차를 마칩니다'
  Start-Sleep -Seconds 2
  exit 0
}

function Get-ChanceToggleState {
  param(
    [System.Diagnostics.Process]$Game,
    [int[]]$Point
  )

  # '우연한 만남' 토글 상태를 픽셀로 판별합니다 (던전/어비스 공용 - 같은 위젯).
  # 켜짐이면 토글 왼쪽이 초록색(실측 13,179,118)이고, 꺼짐이면 회색이라 초록이 전혀 없습니다.
  # 반환: 'on' / 'off' / 'unknown'
  # 'unknown' = 픽셀을 못 읽었거나 표본이 전부 검정(RDP 최소화 중 빈 프레임)인 경우.
  # 빈 프레임을 '꺼짐'으로 단정하면 켜져 있던 토글을 블라인드 클릭으로 꺼버릴 수 있어 구분합니다.
  $blackSamples = 0
  $totalSamples = 0
  foreach ($offset in @(-11, 0, 7)) {
    try {
      $color = Get-GamePixel -Game $Game -ReferenceX ($Point[0] + $offset) -ReferenceY $Point[1]
    } catch {
      return 'unknown'
    }
    $totalSamples++
    if ($color.G -gt 150 -and $color.G -gt ($color.R + 80) -and $color.B -lt $color.G) { return 'on' }
    if (([int]$color.R + [int]$color.G + [int]$color.B) -lt 45) { $blackSamples++ }
  }
  if ($totalSamples -gt 0 -and $blackSamples -eq $totalSamples) { return 'unknown' }
  return 'off'
}

function Test-DifficultySelectedAt {
  param(
    [System.Diagnostics.Process]$Game,
    [System.Drawing.Point]$ScreenPoint
  )

  # 난이도 알약이 '선택됨' 상태인지 픽셀로 확인합니다. 선택된 알약에는 채도 높은 밝은
  # 테두리가 생기고(실측 2026-07-17: 입문=보라, 어려움=금색 239,174,66, 매우 어려움/지옥=빨강),
  # 선택 안 된 알약은 어두운 배경 + 흰 글자뿐입니다. 글자 중심 기준 위아래 테두리 지점
  # (dy≈±16)을 좁은 폭(dx≈±12)으로 표본 조사해, '밝고 채도 높은' 픽셀이 3개 이상이면 선택.
  #  - 흰 글자(채도 낮음)·어두운 비선택 배경은 안 걸림
  #  - dx 를 좁게 잡아 옆 알약 테두리 침범을 방지 (실측: 어려움 선택 시 6/18, 비선택은 0/18)
  $rect = New-Object HoneyNogiInput+RECT
  if (-not [HoneyNogiInput]::GetWindowRect($Game.MainWindowHandle, [ref]$rect)) { return $false }
  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  if ($width -le 0 -or $height -le 0) { return $false }
  $refX = [int][Math]::Round(($ScreenPoint.X - $rect.Left) * $referenceWidth / $width)
  $refY = [int][Math]::Round(($ScreenPoint.Y - $rect.Top) * $referenceHeight / $height)
  $hits = 0
  $probeRows = @()
  # dy 그물 확대 (2026-07-29 21:28 계측으로 원인 확정 - 리뷰 승인): OCR 단어 박스의 Y 중심이
  # 판독(스케일/깨짐)마다 최대 ~11px 출렁여, 기존 ±14~18 좁은 창이 금 테두리를 통째로 비껴가는
  # 간헐 실패가 5회 재발 (기준(660,114) 2/18 실측 - 알약 중심 103 대비 11px 아래로 잡힘).
  # 선택 알약은 글자도 금색이라 dy 0 근처도 유효 신호 - 촘촘한 그물로 Y 출렁임을 흡수한다.
  # 비선택 알약은 어두운 배경(밝기<150)+흰 글자(채도≈0)라 추가 표본이 색 조건에 전부 걸러져
  # 오탐 없음 (보관+오류 캡처 오프라인 스윕으로 검증 후 배포).
  foreach ($dy in @(-18, -14, -10, -6, 0, 6, 10, 14, 18)) {
    $rowMaxBright = 0
    $rowMaxSat = 0
    foreach ($dx in @(-12, 0, 12)) {
      try {
        $c = Get-GamePixel -Game $Game -ReferenceX ($refX + $dx) -ReferenceY ($refY + $dy)
      } catch { continue }
      $chMax = [Math]::Max([int]$c.R, [Math]::Max([int]$c.G, [int]$c.B))
      $chMin = [Math]::Min([int]$c.R, [Math]::Min([int]$c.G, [int]$c.B))
      if ($chMax -gt $rowMaxBright) { $rowMaxBright = $chMax }
      if (($chMax - $chMin) -gt $rowMaxSat) { $rowMaxSat = $chMax - $chMin }
      if ($chMax -gt 150 -and ($chMax - $chMin) -gt 60) { $hits++ }
    }
    $probeRows += ('{0}:{1}/{2}' -f $dy, $rowMaxBright, $rowMaxSat)
  }
  # 판정 실패의 실측 계측 (2026-07-29 - 5회 재발한 '캡처는 정상인데 런타임만 실패' 원인
  # 추적용): 실패 순간 실제로 읽힌 픽셀 요약을 남겨 다음 재발 때 원인을 확정한다 (리뷰 승인).
  # 형식: 히트수/18 + dy행별 '최대밝기/최대채도' (기준점 포함)
  $script:lastPillProbe = ('기준({0},{1}) {2}/18 [{3}]' -f $refX, $refY, $hits, ($probeRows -join ' '))
  return ($hits -ge 3)
}

function Confirm-DifficultySelected {
  param(
    [System.Diagnostics.Process]$Game,
    [System.Drawing.Point]$ClickPoint,   # 첫 난이도 클릭에 성공한 '정확한' 좌표
    [string]$Label,
    [switch]$Strict
  )

  # 난이도 클릭 '사후 검증': 클릭이 빗나가 다른 난이도로 바뀌는 사고를 막습니다.
  # 재클릭은 반드시 '첫 클릭과 같은 좌표'로만 합니다. OCR로 난이도를 다시 찾으면
  # '어려움'을 찾을 때 '매우 어려움'의 '어려움' 조각을 잡아 엉뚱한 난이도를 누르는
  # 사고가 나기 때문입니다 (실측 2026-07-17: 어려움 재클릭이 매우 어려움으로 감).
  # 선택 강조가 확인 안 되면 같은 자리를 다시 누르고(재클릭 = 같은 난이도 재선택이라 멱등),
  # 그래도 안 되면 경고만 남깁니다. 시도 3회·대기 1200ms (2026-07-28 실기 20:59: 심층
  # 매우 어려움은 알약 전환과 함께 옵션 패널이 주간 단일 구역으로 재구성돼 강조 렌더링이
  # 확인 시점보다 늦을 수 있음 - 오류 캡처에는 정상 선택돼 있었고 판정식·좌표는 오프라인
  # 재현 통과. 기존 2회·800ms 에서 확인 여유만 늘림)
  for ($tryNo = 1; $tryNo -le 3; $tryNo++) {
    if (Test-DifficultySelectedAt -Game $Game -ScreenPoint $ClickPoint) {
      if ($tryNo -gt 1) { Write-RunLog "$($script:contentTag) 난이도 '$Label' 재클릭으로 선택 확인" }
      return $true
    }
    if ($tryNo -lt 3) {
      Focus-Game -Game $Game
      Click-ScreenPoint -X $ClickPoint.X -Y $ClickPoint.Y
      Start-Sleep -Milliseconds 1200
    }
  }
  if ($Strict) {
    Write-RunLog "[경고] 난이도 '$Label' 선택 강조를 확인하지 못했습니다 (호출부가 오류 처리, 표본: $($script:lastPillProbe))"
  } else {
    Write-RunLog "[경고] 난이도 '$Label' 선택 강조를 확인하지 못했습니다 - 현재 상태로 진행합니다 (표본: $($script:lastPillProbe))"
  }
  return $false
}

function Set-DgOptionDifficulty {
  param(
    [System.Diagnostics.Process]$Game,
    [string]$Label,
    [switch]$Strict
  )

  # 진입 옵션 화면의 난이도 알약을 OCR로 찾고 클릭한 뒤, 선택 화면과 같은 채도 높은
  # 테두리 판정으로 실제 선택 상태를 확인합니다. Confirm-DifficultySelected 가 첫 클릭
  # 좌표만 재사용하므로 재탐색 오클릭이 없고, 첫 탐색도 단어 목록 판정
  # (Select-DgDifficultyWord)이라 '어려움'이 '매우 어려움' 뒷단어에 걸리지 않습니다.
  $point = $null
  for ($findTry = 1; $findTry -le 3; $findTry++) {
    $point = Find-DgDifficultyPoint -Game $Game -Region $rgDgOptDifficulty -Label $Label -HardX $dgOptHardX
    if ($point) { break }
    Write-RunLog "[던전] 옵션 화면에서 난이도 '$Label' 글자를 찾지 못했습니다 - 잠시 후 재탐색 (${findTry}/3)"
    Start-Sleep -Milliseconds 1200
  }
  if (-not $point) {
    if ($Strict) {
      Write-RunLog "[경고] 옵션 화면에서 난이도 '$Label' 글자를 3회 모두 찾지 못했습니다 (호출부가 오류 처리)"
    } else {
      Write-RunLog "[경고] 옵션 화면에서 난이도 '$Label' 글자를 찾지 못했습니다 - 현재 선택된 난이도로 진행합니다"
    }
    return $false
  }
  # 클릭 전 선확인 (2026-07-28 실기 20:59/21:06): 이미 선택된 알약을 다시 누르면 전환/눌림
  # 연출로 강조가 잠깐 꺼지고, 확인 재시도가 매번 그 연출 중에 샘플링돼 실패하는 자기 방해
  # 루프가 됩니다 (오류 시점 캡처는 판정 6/18 완벽 통과 - 화면·판정식 정상 실측).
  # 심층 매우 어려움 진입 경로는 옵션 도달 시 항상 이미 선택 상태라 클릭 자체가 불필요.
  # '검증 후 조작' 클릭 정책 그대로 - 이미 선택돼 있으면 클릭을 생략합니다.
  # 선확인 최대 5회·1초 간격 (2026-07-28 22:14/23:56 실기: 진입 직후 옵션 도달 경로에서는
  # 초기 페이드인으로 알약 강조가 수 초 늦게 그려져(글자는 먼저 그려져 Find 는 성공) 짧은
  # 선확인이 미선택으로 오판 → 클릭 → 자기 방해 재발. 5회 모두 미선택일 때만 진짜 미선택)
  for ($preTry = 1; $preTry -le 5; $preTry++) {
    if (Test-DifficultySelectedAt -Game $Game -ScreenPoint $point) {
      Write-RunLog "[던전] 난이도 '$Label' 이미 선택 확인 - 클릭 생략 (옵션 화면)"
      return $true
    }
    if ($preTry -lt 5) { Start-Sleep -Milliseconds 1000 }
  }
  # 클릭 1회 → 재클릭 없이 2초 간격 수동 확인 (리뷰 계약 - 확인 실패마다 재클릭하면
  # 눌림/전환 연출이 다시 시작돼 확인이 영원히 연출 구간에 걸리는 자기 방해 루프.
  # 23:56 실기: 오류 3초 뒤 캡처는 판정 완벽 통과 = 기다리기만 하면 되는 상태였음)
  Focus-Game -Game $Game
  Click-ScreenPoint -X $point.X -Y $point.Y
  Write-RunLog "[던전] 난이도 '$Label' 확정 클릭 (옵션 화면)"
  Start-Sleep -Milliseconds 900
  for ($passiveTry = 1; $passiveTry -le 3; $passiveTry++) {
    if (Test-DifficultySelectedAt -Game $Game -ScreenPoint $point) { return $true }
    Start-Sleep -Milliseconds 2000
  }
  # 전부 실패했을 때만 같은 좌표를 최종 1회 재클릭하고 다시 수동 확인 (그래도 실패면
  # 기존 계약대로 경고 후 $false - Strict 처리는 호출부 몫)
  Focus-Game -Game $Game
  Click-ScreenPoint -X $point.X -Y $point.Y
  Start-Sleep -Milliseconds 900
  for ($finalTry = 1; $finalTry -le 3; $finalTry++) {
    if (Test-DifficultySelectedAt -Game $Game -ScreenPoint $point) {
      Write-RunLog "[던전] 난이도 '$Label' 재클릭으로 선택 확인 (옵션 화면)"
      return $true
    }
    Start-Sleep -Milliseconds 2000
  }
  if ($Strict) {
    Write-RunLog "[경고] 난이도 '$Label' 선택 강조를 확인하지 못했습니다 (호출부가 오류 처리, 표본: $($script:lastPillProbe))"
  } else {
    Write-RunLog "[경고] 난이도 '$Label' 선택 강조를 확인하지 못했습니다 - 현재 상태로 진행합니다 (표본: $($script:lastPillProbe))"
  }
  return $false
}

function Test-TabSelectedAt {
  param(
    [System.Diagnostics.Process]$Game,
    [int[]]$Point
  )

  # 상세 화면의 입장 방식 탭(혼자하기/함께하기)이 선택 상태인지 확인합니다.
  # 선택된 탭은 배경이 채도 높은 밝은 색으로 채워지고(혼자하기=청록, 함께하기=보라 -
  # 실측 2026-07-17: 선택 5/8, 비선택 0/8), 선택 안 된 탭은 어둡습니다.
  # 탭 글자 주변 배경을 표본 조사해 '밝고 채도 높은' 픽셀이 2개 이상이면 선택으로 판단합니다.
  # (dx를 좌우로 벌려 흰 글자를 피하고, 두 탭 사이 중앙의 장식 아이콘과 겹치지 않는 범위)
  $hits = 0
  foreach ($dx in @(-35, -15, 15, 35)) {
    foreach ($dy in @(-6, 6)) {
      try {
        $c = Get-GamePixel -Game $Game -ReferenceX ($Point[0] + $dx) -ReferenceY ($Point[1] + $dy)
      } catch { continue }
      $chMax = [Math]::Max([int]$c.R, [Math]::Max([int]$c.G, [int]$c.B))
      $chMin = [Math]::Min([int]$c.R, [Math]::Min([int]$c.G, [int]$c.B))
      if ($chMax -gt 150 -and ($chMax - $chMin) -gt 60) { $hits++ }
    }
  }
  return ($hits -ge 2)
}

function Confirm-TabSelected {
  param(
    [System.Diagnostics.Process]$Game,
    [int[]]$Point,
    [string]$Label
  )

  # 탭 클릭 사후 검증: 두 탭의 입장 버튼 영역이 겹쳐 있어 화면 대기만으로는 탭 클릭
  # 실패를 못 잡는 경우가 있으므로(함께하기를 눌렀는데 혼자하기 화면 그대로인 경우 등),
  # 선택 배경색으로 한 번 더 확인합니다. 실패 시 1회 재클릭, 그래도 안 되면 경고만 남기고
  # 진행합니다 (같은 탭 재클릭은 부작용이 없어 재시도가 안전).
  for ($tryNo = 1; $tryNo -le 2; $tryNo++) {
    if (Test-TabSelectedAt -Game $Game -Point $Point) {
      if ($tryNo -gt 1) { Write-RunLog "$($script:contentTag) $Label 탭 재클릭으로 선택 확인" }
      return $true
    }
    if ($tryNo -lt 2) {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $Point[0] -ReferenceY $Point[1]
      Start-Sleep -Milliseconds 800
    }
  }
  Write-RunLog "[경고] $Label 탭 선택 상태를 확인하지 못했습니다 - 현재 상태로 진행합니다"
  return $false
}

function Set-DgToggleCard {
  param(
    [System.Diagnostics.Process]$Game,
    [int[]]$Region,
    [int[]]$ClickPoint,
    [bool]$WantSelected,
    [string]$Label,
    [int[]]$AltRegion = $null
  )

  # 은동전(소탕)/더블 루팅 카드의 상태를 설정값에 맞춥니다. 버튼 글자가
  # '선택됨' = 사용 중 / '도전' = 미사용이며, 클릭할 때마다 서로 전환됩니다.
  # ('선택됨'이 OCR에서 'A-I태됨'처럼 깨져도 '됨'은 남아서 판별 가능 - 실측 확인)
  # 버튼은 상태에 따라 위치·폭이 달라('선택됨'=넓고 우측 / '도전'=좁고 좌측) 한 영역으로
  # 두 상태를 다 읽지 못합니다. 주 영역에서 판별이 안 되면 보조 영역(AltRegion)을 읽습니다.
  $lastText = ''
  $clicked = $false
  # 이번 호출에서 실제 클릭이 있었는지를 호출부에 알립니다 (매 호출 초기화 - 리뷰 계약).
  # '방금 우리가 클릭해서 전환을 확인한' 경우 소모량 교차 검증을 생략하는 판단에 쓰입니다.
  $script:dgToggleClicked = $false
  # 판독 영역 목록 (주 → 보조). PS 5.1 배열 풀림 방지로 쉼표 연산자를 씁니다.
  $cardRegions = @()
  $cardRegions += , $Region
  if ($AltRegion) { $cardRegions += , $AltRegion }
  $clickedRecheckDone = $false
  $setTryMax = 6
  for ($setTry = 1; $setTry -le $setTryMax; $setTry++) {
    # 캡처 실패 중에는 시도를 소모하지 않고 복구를 기다립니다 (2026-08-02 06:03 실사고:
    # 아침 6시 리셋 + RDP 본체 전환 5초가 6회 중 5회를 태워, 복구 직후 마지막 회전에서
    # 클릭만 하고 재확인 없이 종료 → 커스텀 게이트 정지. 입장 재시도 루프와 같은 계약 -
    # 복구 탐침이 캡처 성공을 등록해 플래그를 갱신합니다. 리뷰 조건: setTry 절대 미소모)
    while ($script:screenCaptureFailing) {
      Test-SafeStopDuringCaptureFail
      Start-Sleep -Seconds 2
      Get-GameRegionOcrText -Game $Game -ReferenceX $Region[0] -ReferenceY $Region[1] `
        -RegionWidth $Region[2] -RegionHeight $Region[3] -Scale 5 -Engine $ocrKoreanEngine | Out-Null
    }
    # 버튼 글자 판독: 다중 스케일 재시도 (2026-07-31 다른 PC 실기 - 창 1273x718 에서 스케일 5는
    # '서대되'로 깨져 판별 실패했는데 같은 화면을 스케일 3으로 읽으면 '선택됨' 정확 판독.
    # 07-29 난이도 알약과 같은 '단일 스케일 고정' 사고). 스케일 우선 순회(각 배율에서 주 →
    # 보조)라 기존 스케일 5 성공 경로는 첫 배율에서 그대로 끝납니다.
    #
    # 다중 스케일은 **1~2회전과 클릭 직후 첫 재확인에서만** 씁니다 (리뷰 조건 - 3차 점검에서
    # 1회전 한정의 회귀 확인: 첫 회전이 화면 전환 중이라 3배율 전부 실패하면 이후 s5 만 남아
    # s5 가 깨지는 창(어제 타 PC)에서 구제 불가. 2회전까지면 800ms 대기 후 안정 화면 재시도).
    # 그래도 실패하면 글자 판독이 안 되는 상태(회색 비활성 등)라 픽셀 폴백·재확인 생략이 담당.
    # 최악 비용: 1~2회전 3배율 12회 + 3~6회전 s5 8회 + 클릭 재확인이 s5 회전을 3배율로
    # 대체하는 증가분 4회 = 24회 (전 회전 3배율이면 36회 - 리뷰 재산정).
    $cardScales = @(5)
    if ($setTry -le 2) { $cardScales = @(5, 3, 4) }
    elseif ($clicked -and -not $clickedRecheckDone) {
      $cardScales = @(5, 3, 4)
      $clickedRecheckDone = $true
    }
    $isSelected = $false
    $isChallenge = $false
    foreach ($cardScale in $cardScales) {
      foreach ($cardRegion in $cardRegions) {
        $cardText = (Get-GameRegionOcrText -Game $Game -ReferenceX $cardRegion[0] -ReferenceY $cardRegion[1] `
          -RegionWidth $cardRegion[2] -RegionHeight $cardRegion[3] -Scale $cardScale -Engine $ocrKoreanEngine) -replace '\s', ''
        # 진단 로그가 실제 마지막 판독을 가리키도록 빈 값도 그대로 반영합니다
        # (기존에는 비어 있으면 갱신을 건너뛰어 이전 오독값이 경고에 남았음)
        $lastText = $cardText
        # '선태되' = '선택됨' 깨짐 실측 (2026-07-19 00:21 - '됨'도 '선택'도 안 남아 판별 불가였음)
        $isSelected = ($cardText.Contains('됨') -or $cardText.Contains('선택') -or $cardText.Contains('선태'))
        $isChallenge = $cardText.Contains('도전')
        if ($isSelected -or $isChallenge) { break }
      }
      if ($isSelected -or $isChallenge) { break }
    }
    if (-not ($isSelected -or $isChallenge)) {
      # 은동전이 부족하면 게임이 카드를 자동 해제하고 버튼을 회색 비활성('도전')으로
      # 바꾸는데, 회색 글자는 대비가 낮아 OCR이 못 읽습니다 (실측: 두 영역 모두 빈값).
      # 버튼 배경색으로 보완 판별: 활성 버튼은 보라색(B가 높음), 비활성은 무채색 회색이라
      # 샘플 픽셀이 전부 회색이면 '미사용(도전)' 상태로 간주합니다.
      $graySamples = 0; $totalSamples = 0
      foreach ($dxOffset in @(-25, 0, 25)) {
        try {
          $pxColor = Get-GamePixel -Game $Game -ReferenceX ($ClickPoint[0] + $dxOffset) -ReferenceY $ClickPoint[1]
        } catch { continue }
        $totalSamples++
        $chMax = [Math]::Max([int]$pxColor.R, [Math]::Max([int]$pxColor.G, [int]$pxColor.B))
        $chMin = [Math]::Min([int]$pxColor.R, [Math]::Min([int]$pxColor.G, [int]$pxColor.B))
        # 표본이 검정에 가까우면(RDP 최소화 중 빈 프레임) 회색으로 치지 않습니다.
        # 빈 프레임을 '도전(미사용) 확정'으로 오판해 카드를 블라인드 클릭하는 것을 방지
        # (실측 회색 비활성 버튼은 밝기가 충분해 이 문턱에 걸리지 않음)
        $chSum = [int]$pxColor.R + [int]$pxColor.G + [int]$pxColor.B
        if ($chSum -ge 45 -and ($chMax - $chMin) -lt 40 -and $pxColor.B -lt 130) { $graySamples++ }
      }
      if ($totalSamples -gt 0 -and $graySamples -eq $totalSamples) {
        $isChallenge = $true
        $lastText = '(회색 비활성 - 은동전 부족으로 게임이 해제함)'
      }
    }
    if (-not ($isSelected -or $isChallenge)) {
      # 글자를 못 읽은 상태. 해제된 카드는 버튼 글자가 사라지거나 흐려져 OCR이 실패하는데,
      # 이미 원하는 방향으로 한 번 클릭했다면 그 클릭으로 설정은 반영된 것이므로 성공 처리합니다
      # (재확인만 불가). 아직 클릭 전이면 화면 전환 중일 수 있어 잠시 기다렸다 다시 확인합니다.
      if ($clicked) {
        Write-RunLog "$($script:contentTag) $Label = $(if ($WantSelected) { '사용' } else { '미사용' })으로 설정 (재확인 생략)"
        return $true
      }
      Start-Sleep -Milliseconds 800
      continue
    }
    if ($isSelected -eq $WantSelected) {
      Write-RunLog "$($script:contentTag) $Label = $(if ($WantSelected) { '사용(선택됨)' } else { '미사용(도전)' }) 확인"
      return $true
    }
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ClickPoint[0] -ReferenceY $ClickPoint[1]
    Write-RunLog "$($script:contentTag) $Label 버튼 클릭 → $(if ($WantSelected) { '사용' } else { '미사용' })으로 변경"
    $clicked = $true
    $script:dgToggleClicked = $true
    # 마지막 회전에서 클릭했다면 재확인용으로 1회전만 연장합니다 (2026-08-02 실사고 - 재확인
    # 없이 종료돼 게이트 정지. 연장 회전에서도 반대 상태로 읽히면 성공 처리 없이 기존
    # 경고/$false 경로로 갑니다 - 리뷰 조건)
    if ($setTry -eq $setTryMax -and $setTryMax -eq 6 -and -not $clickedRecheckDone) { $setTryMax = 7 }
    Start-Sleep -Milliseconds 1100
  }
  # 여기 도달: 클릭했는데도 계속 반대 상태로 읽히거나(설정이 안 먹힘), 클릭 전부터 계속 판별 불가
  $lastTextLog = $(if ($lastText) { $lastText } else { '(판독 없음)' })
  Write-RunLog "[경고] $Label 상태를 설정값에 맞추지 못했습니다 (버튼 OCR: '$lastTextLog') - 현재 상태로 진행합니다"
  return $false
}

function Invoke-DgBackToSelection {
  param(
    [System.Diagnostics.Process]$Game,
    [scriptblock]$ReadTitle
  )

  # 진입 옵션 화면 → 던전 선택 화면 복귀 (기존 0-1 경로의 뒤로 가기 루프를 그대로 추출 -
  # 커스텀 반복의 강제 복귀 경로와 공용. 동작은 추출 전과 동일해야 합니다).
  # 상태 기반 클릭 정책 (무조건 재클릭 금지): 매번 화면 제목을 먼저 판독하고, 옵션 화면
  # ('구역')이 그대로 보일 때만 좌상단 '<'를 클릭합니다 (누적 4클릭 상한). 전환 중이라
  # 판독이 불명확하면 입력 없이 기다렸다가 재확인합니다 (복귀가 이미 성공했는데 판독이
  # 한 번 흔들렸다고 여분의 입력을 쏘지 않기 위함).
  # 주의: ESC/우상단 X는 한 단계 뒤로가 아니라 던전 UI 전체를 닫고 필드로
  # 나가버립니다 (2026-07-18 18:44 실측 - 좌상단 '<'만 선택 화면으로 돌아감).
  # Test-HomeEndEscHud 로 필드 이탈이 확인되면 즉시 중단하고 호출부 오류 처리에 맡깁니다.
  # 반환: @{ Ok = 복귀 성공 여부; Title = 마지막으로 판독한 제목 } (단일 해시테이블)
  $backOk = $false
  $backInputs = 0
  $titleText = ''
  for ($backTry = 1; $backTry -le 10; $backTry++) {
    $titleText = & $ReadTitle
    if (-not $titleText.Contains('구역')) {
      if (Test-DgSelectionTitle -TitleText $titleText) { $backOk = $true; break }
      # 던전 UI 밖(필드 HUD)으로 나가버렸으면 더 조작하지 않고 호출부 오류로 안내합니다
      if (Test-HomeEndEscHud -Game $Game) { break }
      Start-Sleep -Milliseconds 1500   # 전환 중/판독 불명확 - 입력 없이 재확인
      continue
    }
    if ($backInputs -ge 4) { break }
    $backInputs++
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ptDgBackArrow[0] -ReferenceY $ptDgBackArrow[1]
    Write-RunLog "[던전] 선택 화면으로 뒤로 가기: 좌상단 < 클릭 (${backInputs}/4)"
    Start-Sleep -Milliseconds 1500
  }
  return @{ Ok = $backOk; Title = $titleText }
}

function Write-CustomClearMarker {
  # 커스텀 반복 완료 마커: 결과 화면 도달(클리어 확정) 시점에 GUI가 지정한 경로에
  # 현재 항목 소유자 JSON(리스트 지문/lap/index/항목 토큰)을 기록합니다. 마무리 오류 시
  # GUI는 진행도를 넘기지 않고 이 소유자의 결과 화면만 복구한 뒤 코드 0에서 한 번 전진합니다.
  # GUI 타이머가 같은 Log 폴더를 폴링 중이라 공유 위반이 날 수 있어 Write-RunLog 와
  # 같은 20회 재시도 패턴으로 흡수하고, 끝내 실패해도 진행은 계속합니다
  # (마커는 보험이지 필수가 아님 - 정상 코드 0이면 GUI가 종료 코드로 전진).
  if ([string]::IsNullOrWhiteSpace($script:customMarkerPath)) { return }
  if ([string]::IsNullOrWhiteSpace($script:customOwnerJson)) {
    Write-RunLog '[경고] 완료 마커 소유자 정보가 없어 마커를 기록하지 않습니다 - GUI/워커 버전을 확인해 주세요'
    return
  }
  $written = $false
  for ($attempt = 0; $attempt -lt 20; $attempt++) {
    try {
      Set-Content -LiteralPath $script:customMarkerPath -Value $script:customOwnerJson -Encoding UTF8 -ErrorAction Stop
      $written = $true
      break
    } catch {
      Start-Sleep -Milliseconds 50
    }
  }
  if ($written) {
    Write-RunLog '[커스텀] 완료 마커 기록 (결과 화면 도달)'
  } else {
    Write-RunLog '[경고] 완료 마커 기록에 실패했습니다 - 정상 종료면 GUI가 종료 코드로 계상하므로 진행을 계속합니다'
  }
}

function Invoke-NormalDungeonCycle {
  param([System.Diagnostics.Process]$Game)

  # '던전' 자동화 - 현재 구현 범위:
  #   선택 화면(난이도/스테이지 선택·검증) → 진입 옵션(은동전 소탕/더블 루팅/매칭) → 입장
  #   → 던전 내부(어비스와 동일: 자동출발 → 클리어 대기 → 터치 → 나가기)까지.
  # 클리어 후 결과 화면에서 '다시 하기'로 진입 옵션 화면까지 복귀하고 정상 종료(코드 0)하면,
  # GUI가 다음 회차 워커를 띄워 옵션 화면부터 이어가는 방식으로 반복됩니다.
  $script:contentTag = $(if ($deepMode) { '[심층]' } else { '[던전]' })

  if ($script:customSpecInvalid) {
    # 커스텀 항목 형식 오류: 조용히 normalDungeon 설정으로 돌면 오계상 사고라 명확히 실패시킵니다
    throw "커스텀 반복 항목 형식이 올바르지 않습니다: '$env:HONEYNOGI_CUSTOM_ITEM' - GUI와 워커 버전이 어긋났을 수 있으니 꿀비노기를 최신 버전으로 맞춘 뒤 다시 시작해 주세요"
  }

  $dungeonRunItem = @{
    Difficulty = $ndDifficulty
    Stage      = $ndStage
    Coin       = $ndUseCoin
    Double     = $ndDoubleLoot
  }
  Write-RunLog "$($script:contentTag) 자동화 시작: $(Format-CustomItemLabel -Item $dungeonRunItem), 매칭 '$ndMatching'"

  if ($script:customMode) {
    $customPosLabel = $script:customPositionText
    if ([string]::IsNullOrWhiteSpace($customPosLabel)) { $customPosLabel = '(위치 정보 없음)' }
    if ($script:customRecoveryOnly) {
      Write-RunLog "[커스텀] $customPosLabel 완료 항목 마무리 복구 - $(Format-CustomItemLabel -Item $script:customItem)"
    }
  }

  if (-not $dgSelStagePoints['A'].ContainsKey($ndStage)) {
    throw "알 수 없는 스테이지입니다: '$ndStage' (지원: $($dgSelStagePoints['A'].Keys -join ', '))"
  }
  $stageParts = $ndStage -split '-'
  $stageFloor = $stageParts[0]
  $stageArea = $stageParts[1]
  # '매우 어려움' 요청 여부: 없는 난이도로 오입장하는 사고를 막기 위해 모드와 무관하게
  # 탐색·확정 실패를 치명 처리하는 데 씁니다 (교차 리뷰 반영)
  $ndVeryHardTarget = ((($ndDifficulty -replace '\s', '')) -eq '매우어려움')

  # 0. 현재 화면 판별: 좌상단 제목이 'N구역'을 포함하면 이미 진입 옵션 화면입니다.
  #    선택 화면 제목에는 던전 이름과 '던전'이 들어갑니다. OCR이 이름 일부를 깨뜨리는
  #    경우까지 고려해 '던전'/'오드' 조각을 함께 봐서 느슨하게 확인합니다.
  #    선택/옵션 화면 둘 다 아니면, 던전 안에서 재시작한 경우인지 확인합니다
  #    (게임플레이 HUD + 퀘스트 추적기의 'N구역 클리어' 목표로 판별).
  $readDgTitle = {
    Read-DgTitleText -Game $Game   # 좁은 우선 + 심층 조건부 확장 이중 판독 (함수 주석 참고)
  }
  # 시작 화면 판정 전 전체 화면 팝업 정리 (2026-08-01 실사고: 물약 부족 팝업+협동 미션 완료
  # 화면이 겹친 채 재시도 워커가 시작되자 제목/HUD 판독이 전부 가려져 "던전 화면이 아닙니다"
  # 3연속 즉사 → 정지. 스윕이 닫은 경우에만 1.2초 대기 후 재확인, 최대 2회 - 리뷰 조건)
  for ($startSweep = 1; $startSweep -le 2; $startSweep++) {
    if (-not (Invoke-PurchasePopupSweep -Game $Game)) { break }
    Start-Sleep -Milliseconds 1200
  }
  $titleText = & $readDgTitle
  $onOptionsScreen = $titleText.Contains('구역')

  # 던전 ID 확정 (상태·기하 중심 좌표 체계의 상태 ID): 선택/옵션 제목 모두에 던전 이름이
  # 포함되므로 시작 시 1회 판별합니다. 불명이면 '미등록 확정'이 아니라 '모름'으로 두고,
  # 이후 좌표는 라벨/기하 프로브로만 만들어집니다 (설계 합의 - ID 불명 상태 분리).
  $script:dgDungeonId = Get-DgDungeonIdFromTitle -TitleText $titleText
  if ($script:dgDungeonId) {
    Write-RunLog "[던전] 던전 판별: $($script:dgDungeonId) (제목: '$titleText')"
  } else {
    Write-RunLog "[던전] 던전 이름을 확정하지 못했습니다 (제목: '$titleText') - 라벨·기하 확인 좌표로만 진행합니다"
  }

  # 선택 화면 2차 인식 (2026-07-28 22:48 실기: 제목 OCR이 일시적으로 빈 값이면 선택 화면을
  # 몰라 탭 게이트도 스킵되고 '던전 화면이 아닙니다'로 정지 - 비권장 창 크기(1279x721)에서
  # 제목만 판독 실패·진입 버튼은 정상 판독 실측). 하단 'N층 M구역 진입' 버튼은 선택 화면
  # 전용 문구라 2차 신호로 인정합니다 (Test-KnownScreen 의 이중 신호와 동일 원리).
  # 탭 게이트/시작 분기 두 곳이 이 변수로 통일됩니다.
  $onSelectionScreen = (Test-DgSelectionTitle -TitleText $titleText)
  if (-not $onOptionsScreen -and -not $onSelectionScreen) {
    $selProbe = ([string](Get-DgStageEnterButtonText -Game $Game)) -replace '\s', ''
    if ($selProbe.Contains('진입')) {
      $onSelectionScreen = $true
      Write-RunLog "[던전] 선택 화면 인식 (제목 판독 실패 - 진입 버튼 '$selProbe' 기준)"
    }
  }
  # '매우 어려움' 요청인데 2단계(일반/어려움) 던전으로 판별되면 시작하지 않습니다
  if ($ndVeryHardTarget -and $script:dgDungeonId -and ($dgTwoTierDungeons -contains [string]$script:dgDungeonId)) {
    throw "던전 '$($script:dgDungeonId)'에는 '매우 어려움' 난이도가 없습니다 - 난이도 설정을 확인해 주세요."
  }

  # 던전|심층 탭 확인·자동 전환: 같은 선택 화면의 탭이라 제목(던전명)만으로는 구분되지
  # 않습니다. 옵션 화면은 제목의 '심층' 조각으로, 선택 화면은 진입 버튼('심층 N층 M구역
  # 진입')의 '심층' 조각으로 확인합니다 ('심충' 오독 관용). 요청 모드와 다르면 상단
  # '던전|심층 던전' 탭을 눌러 자동 전환하고(2026-07-28 사용자 요청 - 기존 코드 4 정지에서
  # 변경), 전환 확인 실패 시에만 기존 안내로 정지합니다 (fail-closed 유지).
  # 선택/옵션 화면이 아닌 재시작(던전 안/결과 화면)은 게이트 대상이 아닙니다.
  if ($onOptionsScreen -or $onSelectionScreen) {
    $deepTabMark = $false
    if ($onOptionsScreen) {
      $deepTabMark = [bool]($titleText -match '심[층충]')
    } else {
      $deepTabProbe = ([string](Get-DgStageEnterButtonText -Game $Game)) -replace '\s', ''
      $deepTabMark = [bool]($deepTabProbe -match '심[층충]')
    }
    if ($deepMode -ne $deepTabMark) {
      $tabTargetLabel = $(if ($deepMode) { '심층 던전' } else { '던전' })
      Write-RunLog "$($script:contentTag) 화면 탭이 요청 모드와 다릅니다 - '$tabTargetLabel' 탭으로 자동 전환합니다"
      if ($onOptionsScreen) {
        # 옵션 화면에는 탭이 없어 좌상단 '<'로 선택 화면에 먼저 복귀합니다
        # ('다시 하기'로 돌아온 옵션 화면에는 '<'가 없음 - 복귀 실패 시 기존 안내로 정지)
        $tabBack = Invoke-DgBackToSelection -Game $Game -ReadTitle $readDgTitle
        $titleText = [string]$tabBack.Title
        if (-not $tabBack.Ok) {
          Write-RunLog "[완료] 탭 전환을 위해 선택 화면으로 돌아가지 못했습니다 - 던전 선택 화면에서 '$tabTargetLabel' 탭을 연 뒤 다시 시작해 주세요 (제목: '$titleText')"
          exit 4
        }
        $onOptionsScreen = $false
        # 복귀 성공 = 선택 화면 확정 (2026-08-01 전수 점검: 이 플래그를 안 세우면 아래 시작
        # 분기가 '선택/옵션 화면 아님'으로 오판해 "던전 화면이 아닙니다" 헛 오류 - GUI 재시도가
        # 가려주던 결함. 세 복귀 경로 공통)
        $onSelectionScreen = $true
      }
      $tabSwitched = $false
      for ($tabTry = 1; $tabTry -le 3 -and -not $tabSwitched; $tabTry++) {
        # 탭 단어 탐색 후 클릭 (실측 예비 좌표: 심층 던전 탭 중앙 150,128 / 던전 탭 66,128)
        $tabWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX 20 -ReferenceY 100 `
            -RegionWidth 280 -RegionHeight 50 -Scale 3 -Engine $ocrKoreanEngine)
        $tabPoint = Select-DgTabWord -Words $tabWords -DeepTab $deepMode
        if (-not $tabPoint) {
          $tabPoint = $(if ($deepMode) { @{ X = 150; Y = 128 } } else { @{ X = 66; Y = 128 } })
        }
        Focus-Game -Game $Game
        Click-GamePoint -Game $Game -ReferenceX ([int]$tabPoint.X) -ReferenceY ([int]$tabPoint.Y)
        Start-Sleep -Milliseconds 1200
        # 전환 확인: 빈 판독이 '심층 없음 = 던전 탭'으로 오인되지 않게 '진입' 존재까지 요구 (리뷰)
        if (Test-DgTabProbeMatchesMode -ProbeText ([string](Get-DgStageEnterButtonText -Game $Game)) -DeepTab $deepMode) {
          $tabSwitched = $true
        }
      }
      if (-not $tabSwitched) {
        Write-RunLog "[완료] '$tabTargetLabel' 탭 자동 전환을 확인하지 못했습니다 - 던전 선택 화면에서 '$tabTargetLabel' 탭을 연 뒤 다시 시작해 주세요 (제목: '$titleText')"
        exit 4
      }
      # 전환 후 제목 재판독 → 던전 ID 재산출 + 매우 어려움 2단계 던전 가드 재평가 (리뷰 조건 -
      # 전환 전 판별이 이후 좌표·배치 판정을 오염시키지 않게)
      $titleText = & $readDgTitle
      $script:dgDungeonId = Get-DgDungeonIdFromTitle -TitleText $titleText
      $tabRedetectTag = $(if ($script:dgDungeonId) { " (던전 재판별: $($script:dgDungeonId))" } else { '' })
      Write-RunLog "$($script:contentTag) '$tabTargetLabel' 탭 전환 확인$tabRedetectTag"
      if ($ndVeryHardTarget -and $script:dgDungeonId -and ($dgTwoTierDungeons -contains [string]$script:dgDungeonId)) {
        throw "던전 '$($script:dgDungeonId)'에는 '매우 어려움' 난이도가 없습니다 - 난이도 설정을 확인해 주세요."
      }
    }
  }

  # 주간 매우 어려움 (심층 전용): 단일 구역이며 주마다 위치가 바뀌므로 구역 설정을 쓰지 않고
  # 화면에 열려 있는 그 구역을 동적으로 채택합니다 (층·구역 전환/선택 클릭 전체 미사용 -
  # 매우 어려움 카드는 색이 달라(빨강) 남색 카드 픽셀 검증 경로를 태울 수 없음. 설계 합의).
  if ($deepMode -and $ndVeryHardTarget) {
    # 판독 최대 3회 재시도 (2026-07-28 실기: 시작 직후 첫 OCR이 일시적으로 빈 값이면 1회
    # 판독만으로 코드 4 정지 - 매회 재판독으로 일시 공백을 흡수. 옵션 경로는 제목, 선택
    # 경로는 진입 버튼을 다시 읽음)
    $weeklyStage = ''
    $weeklySource = ''
    for ($weeklyTry = 1; $weeklyTry -le 3 -and -not $weeklyStage; $weeklyTry++) {
      if ($weeklyTry -gt 1) { Start-Sleep -Milliseconds 1200 }
      $weeklySource = $(if ($onOptionsScreen) { [string](& $readDgTitle) }
        else { ([string](Get-DgStageEnterButtonText -Game $Game)) -replace '\s', '' })
      $weeklyShapes = [regex]::Matches(([string]$weeklySource), '(\d)\D{0,2}(\d)구역')
      if ($weeklyShapes.Count -gt 0) {
        $weeklyStage = ('{0}-{1}' -f $weeklyShapes[$weeklyShapes.Count - 1].Groups[1].Value, `
            $weeklyShapes[$weeklyShapes.Count - 1].Groups[2].Value)
      }
    }
    if ($weeklyStage -and $dgSelStagePoints['A'].ContainsKey($weeklyStage)) {
      $ndStage = $weeklyStage
      $stageParts = $ndStage -split '-'
      $stageFloor = $stageParts[0]
      $stageArea = $stageParts[1]
      Write-RunLog "[심층] 주간 매우 어려움 - 이번 주 구역 ${ndStage} 채택 (판독: '$weeklySource')"
    } else {
      Write-RunLog "[완료] 주간 매우 어려움 구역을 판독하지 못했습니다 (판독: '$weeklySource') - 심층 탭에서 '매우 어려움'을 선택해 단일 구역 화면을 열어 두고 다시 시작해 주세요"
      exit 4
    }
  }

  # 완료 마커 복구 전용 회차에서 옵션/선택 화면이 이미 보이면 이전 워커의 마무리 입력은
  # 성공했고 화면 전환 확인만 실패했던 경우입니다. 완료 항목을 다시 입장하지 않고 코드 0으로
  # GUI에 복구 완료를 알립니다. GUI는 그때 현재 항목을 딱 한 번 전진시킵니다.
  if ($script:customMode -and $script:customRecoveryOnly) {
    # 복귀/진입 버튼으로 이미 확정된 선택 화면 플래그를 신뢰합니다 (2026-08-01 3차 점검:
    # 탭 전환 복귀 후 제목 재판독이 일시 공백이면 제목만 보는 판정이 선택 화면을 놓쳐,
    # 완료 마커가 있는 항목을 다시 입장할 수 있었음 - 리뷰 승인)
    $recoveryOnSelection = ($onSelectionScreen -or (Test-DgSelectionTitle -TitleText $titleText))
    # 마지막 판 복구: 마무리가 '나가기 → 필드'라서 옵션/선택 화면이 아니라 필드가 목표 화면입니다.
    # 필드 상태(HUD + 던전 목표 없음, 연속 2회)면 재입장 없이 복구 완료 처리하고, 나가기 팝업에서
    # 끊긴 경우는 나가기(Space)를 이어서 처리합니다 (교차 리뷰 반영 - 기존 로직은 필드를
    # '던전 화면 아님' 오류로 처리해 마지막 판 복구가 항상 실패).
    if ($script:dgLastRun -and -not $onOptionsScreen -and -not $recoveryOnSelection) {
      $recoveryFieldStreak = 0
      $recoveryPopupHandled = $false
      for ($recoveryProbe = 1; $recoveryProbe -le 8; $recoveryProbe++) {
        $probeFailed = $false
        $probeHud = Test-HomeEndEscHud -Game $Game
        if ($script:screenCaptureFailing) { $probeFailed = $true }
        $probeQuest = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
          -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine)
        if ($script:screenCaptureFailing) { $probeFailed = $true }
        $probeCenter = Get-GameOcrText -Game $Game
        if ($script:screenCaptureFailing) { $probeFailed = $true }
        if ($probeFailed) { Start-Sleep -Milliseconds 1500; continue }
        $recoveryStep = Get-DgLastRunExitStep -HudVisible $probeHud -QuestText $probeQuest `
          -CenterText $probeCenter -RetryVisible $false
        if ($recoveryStep -eq 'field-evidence') {
          $recoveryFieldStreak++
          if ($recoveryFieldStreak -ge 2) {
            Write-RunLog '[커스텀] 마지막 판 마무리 복구 - 필드 복귀가 이미 완료된 상태 확인, 재입장 없이 복구 완료'
            exit 0
          }
        } elseif ($recoveryStep -eq 'popup-exit') {
          $recoveryFieldStreak = 0
          Focus-Game -Game $Game
          Press-KeyOnce -VirtualKey ([byte]32)
          Write-RunLog "[던전] '던전 탐험을 계속하시겠습니까?' 팝업 - 나가기(Space) 선택 (마지막 판 복구)"
          $recoveryPopupHandled = $true
        } elseif ($recoveryPopupHandled) {
          # 팝업 처리 직후의 전환(로딩/페이드)은 'wait'로 읽힙니다 - 끊지 않고 필드 확인을
          # 계속합니다 (리뷰 조건: 팝업 처리 후 즉시 break 금지)
          $recoveryFieldStreak = 0
        } else {
          # 팝업 처리 전의 미지 상태는 기존 복구 흐름(결과 화면 복구 등)에 맡깁니다
          break
        }
        Start-Sleep -Milliseconds 1500
      }
    }
    $recoveryFinishAction = Get-CustomFinishAction -Item $script:customItem -Next $script:customNext
    $recoveryReadyAction = Get-CustomRecoveryReadyAction -RecoveryOnly $true `
      -OnOptionsScreen $onOptionsScreen -OnSelectionScreen $recoveryOnSelection -FinishAction $recoveryFinishAction
    if ($recoveryReadyAction -eq 'blocked') {
      # 1-3 → 2층은 반드시 '다음 층으로' 뒤의 선택 화면이어야 합니다. 1층 옵션 화면을
      # 복구 완료로 인정하면 다음 2층 항목이 < 없는 화면에서 막히므로 진행도를 유지합니다.
      throw "완료 항목의 다음 층 전환이 끝나지 않았습니다 (현재 옵션 화면: '$titleText') - 진행도를 유지하고 복구를 중단합니다. 2층 구역 선택 화면을 연 뒤 다시 시작해 주세요."
    }
    if ($recoveryReadyAction -eq 'complete') {
      Write-RunLog "[커스텀] 마무리 목표 화면이 이미 준비돼 있습니다 (제목: '$titleText') - 완료 항목 재입장 없이 복구 완료"
      exit 0
    }
  }

  # 0-커스텀. 진입 옵션 화면에서 시작한 경우의 경로 판정 (판정식: Get-CustomOptionStartAction,
  # 계약 v4 - 2026-07-20 실측: 다시 하기로 돌아온 옵션 화면에는 좌상단 '<'가 없지만
  # 같은 층의 구역 카드는 역방향 포함 선택 가능. 그래서 제목의 구역/층을 먼저 판독):
  #  - PREV 와 난이도·구역 모두 같으면('retry-path') 기존 다시 하기 경로 그대로 - 옵션 화면을
  #    이어가고, 아래 0-1 스테이지 검증이 2차 안전망으로 동작합니다 ($ndStage 가 항목값).
  #  - 제목 구역 == 항목 구역('stay-adjust' - 난이도만 다르거나 PREV 없음): 선택 화면 복귀
  #    없이 그 자리에서 옵션 화면 난이도 알약을 눌러 항목 난이도로 맞추고 진행합니다.
  #  - 제목 구역 != 항목 구역, 같은 층('stay-select'): 화면의 구역 카드를 눌러 항목 구역으로
  #    전환합니다 (선택 화면의 노드 좌표+라벨 스크롤 보정 재사용). 전환 확인 실패 시
  #    조건부 정지(코드 4) - 오구역 판이 항목 완료로 계상되는 사고를 막습니다.
  #  - 다른 층('go-back' - 층 판독 불가 포함): 좌상단 '<'로 선택 화면 복귀를 시도합니다
  #    (사용자가 직접 연 화면이면 '<' 존재). 실패는 오류(코드 1)가 아니라 조건부 정지(코드 4) -
  #    < 없는 화면에 오류 재시도 2회가 무의미하게 반복되는 것을 막습니다.
  $customOptDiffAdjusted = $false
  if ($script:customMode -and $onOptionsScreen -and -not $script:customSameAsPrev) {
    # 제목 구역 판독 (기존 0-1 검증의 제목 파싱 기준 재사용 - Test-CustomTitleStageMatch).
    # 첫 판독이 불명확하면 0-1의 재확인 관례대로 잠시 후 한 번 재판독합니다.
    $titleMatch = Test-CustomTitleStageMatch -TitleText $titleText -Stage $ndStage
    if ($titleMatch -eq 'unclear') {
      Start-Sleep -Milliseconds 700
      $titleText = & $readDgTitle
      $titleMatch = Test-CustomTitleStageMatch -TitleText $titleText -Stage $ndStage
    }
    # 층 비교는 구역이 명확히 '다르다'고 읽힌 경우에만 의미가 있습니다
    $titleFloorSame = $false
    if ($titleMatch -eq 'mismatch') {
      $titleFloorSame = ((Test-CustomTitleFloorMatch -TitleText $titleText -Stage $ndStage) -eq 'match')
    } elseif ($titleMatch -eq 'unclear') {
      # 재판독까지 불명확: 지도 라벨 층 + 제목 꼬리 구역 보조 판정으로 현재 구역을 추정합니다.
      # 층 숫자 유실('피오듸층1구역', 2026-07-25 00:09 실기 재발)이 go-back으로 빠지면
      # '<'가 없는 다시 하기 옵션 화면에서 복귀 실패로 정지하므로, 같은 층이 확인되면
      # stay 경로로 보냅니다. 보조 판정도 불명이면 기존 안전측(go-back)을 유지합니다.
      $observedStart = Get-DgOptObservedStage -Game $Game -TitleText $titleText
      if ($observedStart) {
        Write-RunLog "[커스텀] 제목 숫자 불명확 - 보조 판정으로 현재 구역 ${observedStart} 추정 (제목: '$titleText')"
        if ($observedStart -eq $ndStage) {
          $titleMatch = 'match'
        } else {
          $titleMatch = 'mismatch'
          $titleFloorSame = ((([string]$observedStart -split '-')[0]) -eq [string](Get-CustomStageFloor -Stage $ndStage))
        }
      }
    }
    $startAction = Get-CustomOptionStartAction -TitleStageMatches ($titleMatch -eq 'match') -SameAsPrev $false `
      -TitleFloorMatches $titleFloorSame
    if ($startAction -eq 'stay-select') {
      # 같은 층의 다른 구역: 이 옵션 화면에서도 같은 층 구역 카드는 선택할 수 있습니다
      # (2026-07-20 실측 - 역방향 포함). 구역 지도가 화면 오른쪽 중앙 '가로 배치'라
      # 선택 화면 좌표($ndStagePoints)와 다름 - 전용 탐색(Get-DgOptStageCardPoint:
      # 카드 숫자 라벨 글자 탐색 + 실측 예비 좌표)으로 클릭하고, 제목 재판독으로 전환을
      # 확인합니다. 상태 기반 클릭(무조건 재클릭 금지): 이 분기 도달 = '같은 층의 다른
      # 구역'이 이미 확정된 상태(명확한 제목 또는 보조 판정 2표)라, 제목이 다시 불명확해져도
      # 첫 클릭은 진행(-AssumeMismatchFirst - 같은 층 목표 카드 클릭은 멱등이라 무해).
      # 전환 확인은 이후 제목/보조 판정으로 검증하고, 끝내 확인 실패면 조건부 정지(코드 4) -
      # 난이도 확정 격상과 같은 규칙입니다. (2026-07-26 실사고: 제목 층 숫자 유실 지속 시
      # 클릭 없이 8회 대기만 하다 정지 → 첫 클릭 허용으로 재발 방지)
      Write-RunLog "[커스텀] 진입 옵션 화면에서 시작 - 같은 층의 다른 구역이라 화면에서 구역 ${ndStage}를 선택합니다 (제목: '$titleText')"
      $switchResult = Set-DgOptionStage -Game $Game -Stage $ndStage -ReadTitle $readDgTitle -LogTag '[커스텀]' -AssumeMismatchFirst
      $titleText = [string]$switchResult.Title
      if (-not $switchResult.Ok) {
        Write-DgStageDiagnostics -Game $Game -Context "커스텀 시작 구역 ${ndStage} 전환 실패" -MapKind 'option'
        if ([string]$switchResult.Reason -eq 'not-found') {
          Write-RunLog "[완료] 옵션 화면에서 구역 ${ndStage} 카드를 찾지 못해 진행하지 않습니다 (미해금이거나 화면 인식 실패) - 던전 구역 선택 화면을 열어 두고 다시 시작해 주세요"
          exit 4
        }
        Write-RunLog "[완료] 옵션 화면에서 구역 ${ndStage} 전환을 확인하지 못해 진행하지 않습니다 (제목: '$titleText' - 화면 인식 문제 가능) - 던전 구역 선택 화면을 열어 두고 다시 시작해 주세요"
        exit 4
      }
      Write-RunLog "[커스텀] 구역 ${ndStage} 전환 확인 (제목: '$titleText') - 이어서 난이도를 맞춥니다"
    }
    if ($startAction -eq 'stay-adjust' -or $startAction -eq 'stay-select') {
      # 그 자리에서 난이도 알약을 항목 난이도로 맞춥니다 (stay-select 는 구역 전환 후 합류).
      # 탐색 실패 시 '경고 후 진행'이 아니라 조건부 정지(코드 4)입니다 - 오난이도 판이 항목
      # 완료로 계상되면 난이도별 첫 클리어 보상을 잃는 사고라 격상합니다 (선택 화면 2단계와 같은 규칙).
      if ($startAction -eq 'stay-adjust') {
        Write-RunLog "[커스텀] 진입 옵션 화면에서 시작 - 항목과 같은 구역이라 그 자리에서 난이도만 맞춥니다 (제목: '$titleText')"
      }
      $customOptDiffAdjusted = Set-DgOptionDifficulty -Game $Game -Label $ndDifficulty -Strict
      if (-not $customOptDiffAdjusted) {
        # 화면 인식 실패 = 오류 (자동 재시작 1회 + 오류 세트 저장 - 2026-07-25 사용자 지적)
        throw "옵션 화면에서 난이도 '$ndDifficulty' 선택을 확정하지 못했습니다 - 화면 인식 실패로 중단합니다 (오난이도 판 방지)."
      }
    } elseif ($startAction -eq 'go-back') {
      # 다른 층(제목 재판독까지 불명확한 경우 포함): 선택 화면으로 복귀해 새로 고릅니다.
      # Invoke-DgBackToSelection 은 상태 기반이라 '<' 없는 화면에서도 여분 입력 없이 안전합니다.
      Write-RunLog "[커스텀] 진입 옵션 화면에서 시작 - 항목과 다른 층의 구역이라 선택 화면으로 복귀합니다 (제목: '$titleText')"
      $backResult = Invoke-DgBackToSelection -Game $Game -ReadTitle $readDgTitle
      $titleText = [string]$backResult.Title
      if (-not $backResult.Ok) {
        Write-RunLog "[완료] 이 옵션 화면에서는 선택 화면으로 돌아갈 수 없습니다(다시 하기 화면에는 < 버튼이 없음). 던전 구역 선택 화면을 열어 두고 다시 시작해 주세요. (제목 영역 OCR: '$titleText')"
        exit 4
      }
      Write-RunLog '[던전] 선택 화면 복귀 확인 - 난이도/구역 선택부터 진행합니다'
      $onOptionsScreen = $false
      $onSelectionScreen = $true   # 복귀 성공 = 선택 화면 확정 (2026-08-01 - 위 탭 전환 경로와 동일)
    }
  }

  # 0-1. 옵션 화면이라면 제목의 스테이지(N층 M구역)가 설정과 같은지 확인합니다.
  #      '다시 하기' 복귀 회차라면 항상 일치하지만, 사용자가 다른 스테이지의 옵션 화면을
  #      열어 둔 채 시작하면 검증 없이 그 스테이지로 입장하는 사고가 됩니다
  #      (2026-07-18 실측: 설정 1-3인데 2-3 옵션 화면에서 시작 → 그대로 2-3 입장).
  #      OCR 숫자 오독으로 멀쩡한 복귀 회차를 되돌리는 일이 없도록 재확인까지 해서,
  #      '다른 스테이지'가 명확히 읽힌 경우에만 선택 화면으로 되돌아갑니다.
  if ($onOptionsScreen -and ((Test-CustomTitleStageMatch -TitleText $titleText -Stage $ndStage) -ne 'match')) {
    Start-Sleep -Milliseconds 700
    $titleText = & $readDgTitle
    $titleStageVerdict = Test-CustomTitleStageMatch -TitleText $titleText -Stage $ndStage
    if ($titleStageVerdict -eq 'mismatch') {
      $titleFloorVerdict = Test-CustomTitleFloorMatch -TitleText $titleText -Stage $ndStage
      if ($titleFloorVerdict -eq 'match') {
        # 사용자가 같은 층의 다른 구역 상세 화면을 열어 둔 경우에는 선택 화면까지 되돌아갈
        # 필요가 없습니다. 커스텀 반복과 같은 옵션 화면 구역 카드 전환기를 사용한 뒤 제목으로
        # 목표 구역을 확인하고, 아래 공통 옵션 난이도 단계에서 목표 난이도도 다시 맞춥니다.
        Write-RunLog "[던전] 시작: 옵션 화면이 같은 층의 다른 구역입니다 (제목: '$titleText', 설정: ${ndStage}) - 이 화면에서 목표 구역으로 변경합니다"
        $switchResult = Set-DgOptionStage -Game $Game -Stage $ndStage -ReadTitle $readDgTitle -LogTag '[던전]'
        $titleText = [string]$switchResult.Title
        if (-not $switchResult.Ok) {
          $switchFailure = if ([string]$switchResult.Reason -eq 'not-found') { '카드를 찾지 못했습니다 (미해금이거나 화면 인식 실패)' } else { "전환을 확인하지 못했습니다 (제목: '$titleText' - 화면 인식 문제 가능)" }
          Write-DgStageDiagnostics -Game $Game -Context "시작 옵션 화면 구역 ${ndStage} 전환 실패" -MapKind 'option'
          if ($script:customMode) {
            Write-RunLog "[완료] 옵션 화면에서 구역 ${ndStage} $switchFailure - 잘못된 구역 입장을 막기 위해 자동화를 정지합니다"
            exit 4
          }
          throw "옵션 화면에서 구역 ${ndStage} $switchFailure - 잘못된 구역 입장을 막기 위해 중단합니다."
        }
        Write-RunLog "[던전] 옵션 화면에서 구역 ${ndStage} 전환 확인 (제목: '$titleText')"
        $onOptionsScreen = $true
      } else {
        Write-RunLog "[던전] 시작: 진입 옵션 화면이 설정과 다른 층의 구역입니다 (제목: '$titleText', 설정: ${ndStage}) - 선택 화면으로 되돌아갑니다"
        # 상태 기반 뒤로 가기(무조건 재클릭 금지)는 Invoke-DgBackToSelection 로 추출했습니다
        # (커스텀 반복의 강제 복귀 경로와 공용 - 클릭 정책/상한/필드 이탈 감지는 기존 그대로).
        $backResult = Invoke-DgBackToSelection -Game $Game -ReadTitle $readDgTitle
        $titleText = [string]$backResult.Title
        if (-not $backResult.Ok) {
          throw "설정(${ndStage})과 다른 구역의 진입 옵션 화면에서 선택 화면으로 돌아가지 못했습니다 (제목 영역 OCR: '$titleText'). 게임에서 원하는 던전의 구역 선택 화면을 열어 두고 다시 시작해 주세요."
        }
        Write-RunLog '[던전] 선택 화면 복귀 확인 - 난이도/구역 선택부터 진행합니다'
        $onOptionsScreen = $false
        $onSelectionScreen = $true   # 복귀 성공 = 선택 화면 확정 (2026-08-01 - 위 두 복귀 경로와 동일)
      }
    } elseif ($titleText.Length -gt 0) {
      # 재확인에서 설정과 일치했거나 숫자를 명확히 읽지 못한 경우: 새 판독 기준으로 진행
      $onOptionsScreen = $titleText.Contains('구역')
    }
    # 재판독이 빈 문자열(일시 캡처 실패)이면 첫 판독(옵션 화면) 판정을 그대로 둡니다
  }
  $insideAlready = $false
  $onResultScreen = $false
  if (-not $onOptionsScreen -and -not $onSelectionScreen) {
    # 던전 안에서만 퀘스트 추적기에 'N층 M구역 클리어' 목표가 표시됩니다.
    # ('던전' 키워드는 필드의 주간 퀘스트("심층 던전 클리어" 등)와 겹쳐 오인하므로 '구역'만 사용)
    $questText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
      -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
    if ((Test-HomeEndEscHud -Game $Game) -and $questText.Contains('구역')) {
      $insideAlready = $true
      Write-RunLog '[던전] 시작: 던전 안 상태 감지 - 클리어 대기부터 재개'
    } elseif (Find-DgRetryButtonPoint -Game $Game) {
      $onResultScreen = $true
      Write-RunLog '[던전] 시작: 결과 화면 감지 - 재입장부터 진행'
    } elseif (Test-DungeonClearPrompt -Game $Game) {
      # 클리어 화면(화면을 터치)에 멈춘 채 재시작한 경우: 터치로 넘긴 뒤 결과 처리부터 이어갑니다
      Write-RunLog '[던전] 시작: 클리어 화면 감지 - 화면 터치부터 진행'
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptClearCenter[0] -ReferenceY $ptClearCenter[1]
      Start-Sleep -Seconds 2
      $onResultScreen = $true
    } else {
      throw "던전 화면이 아닙니다. 게임에서 원하는 던전의 구역 선택 화면을 열어 두고 시작해 주세요. (제목 영역 OCR: '$titleText')"
    }
  }

  if ($script:customMode -and $script:customRecoveryOnly -and $insideAlready) {
    # 완료 마커는 결과 화면 도달 뒤에만 기록되므로 복구 시작이 던전 내부라면 소유 상태가
    # 모순됩니다. 이미 완료된 항목을 다시 싸워 계상하는 대신 입력 없이 오류로 중단합니다.
    throw '완료 항목 마무리 복구 중 던전 내부 화면이 감지됐습니다 - 항목을 다시 실행하지 않고 안전하게 중단합니다.'
  }

  # 0-커스텀-2. 복구 판 계상 판정 (판정식: Test-CustomCleanupOnly): 사용자가 새로 시작했는데
  # (자동 재시작 아님) 이미 던전 안/결과 화면이면 그 판은 수동 진행분입니다. 복구 흐름
  # 자체(클리어 대기 → 터치 → 결과 → 다시 하기 → 옵션 복귀)는 그대로 태우되 - 던전 안에서는
  # 완주 외 안전한 정리 수단이 없습니다 - 완료 마커를 남기지 않고 마지막에 코드 10으로 끝내
  # 판으로 계상하지 않습니다 (수동 판 오계상 방지).
  $script:customCleanupOnly = Test-CustomCleanupOnly -CustomMode $script:customMode -Restart $script:customRestart `
    -InsideAlready $insideAlready -OnResultScreen $onResultScreen
  if ($script:customCleanupOnly) {
    Write-RunLog '[커스텀] 새 시작인데 던전 안/결과 화면 감지 - 이 판은 계상하지 않고 화면 정리만 진행합니다'
  }

  if (-not $onResultScreen) {

  if (-not $insideAlready) {

  if (-not $onOptionsScreen) {
  Write-RunLog '[던전] 던전 선택 화면 확인'

  # 2. 난이도 클릭 (일반/어려움/매우 어려움 - 이미 선택돼 있어도 다시 눌러 확정, 부작용 없음)
  #    단어 목록 기반 판정(Select-DgDifficultyWord)으로 '매우 어려움'(두 단어로 읽힘)을
  #    지원하고, '어려움'이 '매우 어려움'의 뒷단어에 걸리는 오채택을 차단합니다.
  #    커스텀 반복에서는 '경고 후 진행'을 격상합니다: 오난이도 판이 항목 완료로 계상되면
  #    난이도별 첫 클리어 보상을 잃는 사고라, 탐색/검증을 재시도하고 끝내 확인이 안 되면
  #    진행하지 않고 조건부 정지(코드 4)합니다. '매우 어려움' 요청은 비커스텀에서도
  #    실패 시 중단합니다 - 없는 난이도로 오입장하는 사고 방지 (교차 리뷰 반영).
  if ($script:customMode) {
    $diffOk = $false
    for ($diffTry = 1; $diffTry -le 3; $diffTry++) {
      $difficultyPoint = Find-DgDifficultyPoint -Game $Game -Region $rgDgDifficulty -Label $ndDifficulty -HardX $dgSelHardX
      if (-not $difficultyPoint) {
        Write-RunLog "[커스텀] 난이도 '$ndDifficulty' 글자를 찾지 못했습니다 - 잠시 후 재탐색 (${diffTry}/3)"
        Start-Sleep -Milliseconds 1200
        continue
      }
      Focus-Game -Game $Game
      Click-ScreenPoint -X $difficultyPoint.X -Y $difficultyPoint.Y
      Write-RunLog "[던전] 난이도 '$ndDifficulty' 클릭"
      Start-Sleep -Milliseconds 900
      # 사후 검증 반환값을 그대로 사용합니다 (내부의 같은 좌표 1회 재클릭은 기존 그대로)
      $diffOk = Confirm-DifficultySelected -Game $Game -ClickPoint $difficultyPoint -Label $ndDifficulty -Strict
      if ($diffOk) { break }
      Start-Sleep -Milliseconds 800
    }
    if (-not $diffOk) {
      # 화면 인식 실패는 '조건부 정상 정지'가 아니라 오류입니다 - 오류로 던져야 자동 재시작
      # 1회와 오류 스크린샷 세트가 남습니다 (2026-07-25 사용자 지적. 오난이도 판 방지는 동일)
      throw "난이도 '$ndDifficulty' 선택을 확인하지 못했습니다 - 화면 인식 실패로 중단합니다 (오난이도 판 방지)."
    }
  } else {
  $difficultyPoint = Find-DgDifficultyPoint -Game $Game -Region $rgDgDifficulty -Label $ndDifficulty -HardX $dgSelHardX
  if ($difficultyPoint) {
    Focus-Game -Game $Game
    Click-ScreenPoint -X $difficultyPoint.X -Y $difficultyPoint.Y
    Write-RunLog "[던전] 난이도 '$ndDifficulty' 클릭"
    Start-Sleep -Milliseconds 900
    # 사후 검증: 클릭이 빗나가 다른 난이도로 바뀌지 않았는지 선택 강조로 확인 (첫 좌표 재사용)
    $diffConfirmed = Confirm-DifficultySelected -Game $Game -ClickPoint $difficultyPoint -Label $ndDifficulty -Strict:$ndVeryHardTarget
    if ($ndVeryHardTarget -and -not $diffConfirmed) {
      throw "'매우 어려움' 선택 강조를 확인하지 못했습니다 - 오난이도 입장을 막기 위해 중단합니다."
    }
  } elseif ($ndVeryHardTarget) {
    throw "'매우 어려움' 글자를 찾지 못했습니다 - 이 던전에 없는 난이도일 수 있어 진행하지 않습니다."
  } else {
    Write-RunLog "[경고] 난이도 '$ndDifficulty' 글자를 찾지 못했습니다 - 현재 선택된 난이도로 진행합니다"
  }
  }

  # 구역 노드 클릭 후 '진입' 버튼 문구(N층 M구역)로 선택을 검증합니다. 목표 클릭이 다른
  # 구역에 떨어지면 같은 층은 옵션 화면의 가로 카드에서 다시 맞추고, 다른 층은 옵션 화면의
  # '<'로 선택 화면에 복귀한 뒤 한 번 더 시도합니다. 어느 경로든 목표 제목 확인 전 실제 입장 금지.
  $selectionReady = $false
  $enterText = ''
  $stagePlanMissing = $false
  $stageLabelSeen = $false
  $selectionResult = [pscustomobject]@{ Action = 'unclear'; CurrentFloor = ''; CurrentArea = ''; CurrentStage = '' }
  $triedCandidateTypes = @()
  for ($selectionRound = 1; $selectionRound -le 2 -and -not $selectionReady; $selectionRound++) {
    $stageSelected = $false
    $triedCandidateTypes = @()
    $stagePlan = $null
    for ($stageTry = 1; $stageTry -le 4; $stageTry++) {
      if ($deepMode -and $ndVeryHardTarget) {
        # 주간 매우 어려움: 단일 카드가 이미 선택된 화면이라 구역 클릭 없이 진입 버튼
        # 확인만 합니다 (구역은 위에서 화면 기준으로 동적 채택됨 - 클릭할 카드도 하나뿐)
        $stagePlan = $null
        $stageLabelSeen = $true
        Start-Sleep -Milliseconds 300
      } else {
      # 포커스/선택 상태가 클릭마다 바뀔 수 있어 매 시도마다 클릭 지점을 다시 계산합니다.
      # 오선택된 미등록 배치 후보는 제외 목록으로 넘겨 같은 후보를 반복 클릭하지 않습니다.
      $stagePlan = Get-NdStageClickPoint -Game $Game -Stage $ndStage -ExcludeTypes $triedCandidateTypes
      if (-not $stagePlan) {
        # 확정 좌표 없음(후보 소진 포함): 정지 전에 '이미 목표 구역이 선택돼 있는지'를 진입
        # 버튼으로 확인합니다 (2026-07-28 23:04 실기: 탭 전환 직후 심층 기본 선택이 이미
        # 목표 1-1이었는데 카드 좌표를 못 만들어 그대로 정지 - 클릭 없이 상태 확인만 추가).
        $enterText = Get-DgStageEnterButtonText -Game $Game
        $selectionResult = Get-DgSelectionRecoveryAction -EnterText $enterText -TargetStage $ndStage
        if ($selectionResult.Action -eq 'selected') {
          Write-RunLog "[던전] 구역 ${ndStage} 이미 선택 확인 - 카드 클릭 불필요 (진입 버튼 기준)"
          $stageSelected = $true
          break
        }
        # 이미 선택도 아님: 틀린 좌표로 클릭하지 않고 안전 정지로 넘어갑니다.
        # 이전 시도의 오선택 판정이 남아 옵션 복구로 새지 않도록 판정도 초기화합니다 (교차 리뷰).
        $stagePlanMissing = $true
        $selectionResult = [pscustomobject]@{ Action = 'unclear'; CurrentFloor = ''; CurrentArea = ''; CurrentStage = '' }
        break
      }
      if ([string]$stagePlan.Source -like '라벨*') { $stageLabelSeen = $true }
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $stagePlan.Point[0] -ReferenceY $stagePlan.Point[1]
      Write-RunLog "[던전] 구역 ${ndStage} 클릭 ($($stagePlan.Source))"
      Start-Sleep -Milliseconds 900
      }
      $enterText = Get-DgStageEnterButtonText -Game $Game
      if ($deepMode -and $ndVeryHardTarget) {
        # 주간 구역 재채택(선택 화면): 시작 시 채택은 난이도 전환 '전' 버튼을 읽어 어려움
        # 상태의 구역을 오채택할 수 있습니다 (2026-07-28 실기: 어려움 1-3 오채택 → 실제
        # 매우 어려움 2-3과 불일치 → 단일 카드 지도에서 1-3 탐색 실패로 안전 정지).
        # '매우 어려움' 클릭이 끝난 이 시점의 진입 버튼이 진짜 주간 구역이므로 여기서 최종
        # 확정합니다. 같은 텍스트로 목표를 만들어 아래 판정이 즉시 selected 가 되고,
        # 4회 재시도 루프가 매 시도 갱신하므로 일시 오독도 다음 시도에서 자기 교정됩니다.
        $weeklyNow = ([string]$enterText) -replace '\s', ''
        $weeklyNowShapes = [regex]::Matches($weeklyNow, '(\d)\D{0,2}(\d)구역')
        if ($weeklyNowShapes.Count -gt 0) {
          $weeklyNowStage = ('{0}-{1}' -f $weeklyNowShapes[$weeklyNowShapes.Count - 1].Groups[1].Value, `
              $weeklyNowShapes[$weeklyNowShapes.Count - 1].Groups[2].Value)
          if ($weeklyNowStage -ne $ndStage -and $dgSelStagePoints['A'].ContainsKey($weeklyNowStage)) {
            Write-RunLog "[심층] 주간 구역 재채택: ${ndStage} → ${weeklyNowStage} (매우 어려움 전환 후 진입 버튼 기준)"
            $ndStage = $weeklyNowStage
            $stageParts = $ndStage -split '-'
            $stageFloor = $stageParts[0]
            $stageArea = $stageParts[1]
          }
        }
      }
      $selectionResult = Get-DgSelectionRecoveryAction -EnterText $enterText -TargetStage $ndStage
      if ($selectionResult.Action -eq 'selected') {
        $stageSelected = $true
        break
      }
      # 현재 구역이 명확히 읽혔으면 같은 좌표를 반복 클릭하지 않고 복구 경로로 즉시 전환합니다.
      # 단 미등록 던전의 배치 후보 클릭이 다른 구역을 잡은 경우는 선택 화면이 그대로이므로
      # 그 후보 유형을 제외하고 다음 배치 후보를 계속 시도합니다 (교차 리뷰 반영).
      if ($selectionResult.Action -eq 'same-floor' -or $selectionResult.Action -eq 'different-floor') {
        if ([string]$stagePlan.Source -like '미등록후보*') {
          $misselectType = ([string]$stagePlan.Source -split ':')[1]
          if ($misselectType) { $triedCandidateTypes += [string]$misselectType }
          Write-RunLog "[던전] 배치 후보($misselectType) 클릭이 다른 구역($($selectionResult.CurrentStage))을 선택했습니다 - 다음 배치 후보로 계속"
          continue
        }
        break
      }
    }

    # 미등록 배치 후보의 오선택은 옵션 복구를 태우지 않습니다 - 후보 자체가 추정이라
    # 복구 루프 대신 다음 후보/안전 정지가 맞습니다 (교차 리뷰 반영).
    $planWasCandidate = ($stagePlan -and ([string]$stagePlan.Source -like '미등록후보*'))

    if ($stageSelected) {
      Write-RunLog "[던전] 구역 $ndStage 선택 확인 (진입 버튼: ${stageFloor}층 ${stageArea}구역 진입)"
      Invoke-ClickUntil -Game $Game -Point $ptDgStageEnter -Description '던전 진입 옵션 화면' -TimeoutSeconds 20 -Condition {
        (Read-DgTitleText -Game $Game).Contains('구역')
      } -SourceCondition {
        Test-DgStageEnterButtonVisible -Game $Game -Stage $ndStage
      } -FallbackPoint $ptDgStageEnterLeft -FallbackCondition {
        # IME 팝업이 진입 버튼을 덮으면 버튼 OCR·클릭이 모두 막힘 - 좌상단 제목(팝업 무관
        # 영역)이 아직 선택 화면임을 보증할 때만 버튼 왼쪽 지점을 클릭 (옵션 화면의 같은
        # 자리는 '파티 찾기'라 제목 게이트 필수 - 2026-07-29 00:20 실기)
        (Test-DgImePopupVisible -Game $Game) -and (Test-DgSelectionTitle -TitleText (Read-DgTitleText -Game $Game))
      }
      $titleText = & $readDgTitle
      $onOptionsScreen = $true
      $selectionReady = $true
      break
    }

    if ($selectionResult.Action -eq 'same-floor' -and -not $planWasCandidate) {
      Write-RunLog "[던전] 구역 ${ndStage} 클릭 대신 같은 층의 $($selectionResult.CurrentStage)이 선택됐습니다 - 옵션 화면에서 목표 구역으로 변경합니다"
      Invoke-ClickUntil -Game $Game -Point $ptDgStageEnter -Description '같은 층 오선택 구역의 진입 옵션 화면' -TimeoutSeconds 20 -Condition {
        ((& $readDgTitle) -replace '\s', '').Contains('구역')
      } -SourceCondition {
        Test-DgStageEnterButtonVisible -Game $Game -Stage $selectionResult.CurrentStage
      } -FallbackPoint $ptDgStageEnterLeft -FallbackCondition {
        # IME 팝업 가림 예비 - 위 기본 진입과 동일 게이트 (선택 화면 제목 확인 필수)
        (Test-DgImePopupVisible -Game $Game) -and (Test-DgSelectionTitle -TitleText (Read-DgTitleText -Game $Game))
      }
      $titleText = & $readDgTitle
      $switchResult = Set-DgOptionStage -Game $Game -Stage $ndStage -ReadTitle $readDgTitle -LogTag '[던전]'
      $titleText = [string]$switchResult.Title
      if ($switchResult.Ok) {
        Write-RunLog "[던전] 옵션 화면에서 구역 ${ndStage} 전환 확인 (제목: '$titleText')"
        $onOptionsScreen = $true
        $selectionReady = $true
        break
      }
      $switchFailure = if ([string]$switchResult.Reason -eq 'not-found') { '카드를 찾지 못했습니다 (미해금이거나 화면 인식 실패)' } else { "전환을 확인하지 못했습니다 (제목: '$titleText' - 화면 인식 문제 가능)" }
      Write-DgStageDiagnostics -Game $Game -Context "옵션 화면 구역 ${ndStage} 전환 실패" -MapKind 'option'
      if ($script:customMode) {
        Write-RunLog "[완료] 옵션 화면에서 구역 ${ndStage} $switchFailure - 잘못된 구역 입장을 막기 위해 자동화를 정지합니다"
        exit 4
      }
      throw "옵션 화면에서 구역 ${ndStage} $switchFailure - 잘못된 구역 입장을 막기 위해 중단합니다."
    }

    if ($selectionResult.Action -eq 'different-floor' -and -not $planWasCandidate -and $selectionRound -lt 2) {
      Write-RunLog "[던전] 구역 ${ndStage} 클릭 대신 다른 층의 $($selectionResult.CurrentStage)이 선택됐습니다 - 옵션 화면에서 뒤로 나간 뒤 다시 선택합니다"
      Invoke-ClickUntil -Game $Game -Point $ptDgStageEnter -Description '다른 층 오선택 구역의 진입 옵션 화면' -TimeoutSeconds 20 -Condition {
        ((& $readDgTitle) -replace '\s', '').Contains('구역')
      } -SourceCondition {
        Test-DgStageEnterButtonVisible -Game $Game -Stage $selectionResult.CurrentStage
      } -FallbackPoint $ptDgStageEnterLeft -FallbackCondition {
        # IME 팝업 가림 예비 - 위 기본 진입과 동일 게이트 (선택 화면 제목 확인 필수)
        (Test-DgImePopupVisible -Game $Game) -and (Test-DgSelectionTitle -TitleText (Read-DgTitleText -Game $Game))
      }
      $titleText = & $readDgTitle
      $backResult = Invoke-DgBackToSelection -Game $Game -ReadTitle $readDgTitle
      $titleText = [string]$backResult.Title
      if (-not $backResult.Ok) {
        throw "다른 층 오선택 화면에서 던전 선택 화면으로 돌아가지 못했습니다 (제목: '$titleText')."
      }
      $onOptionsScreen = $false
      Write-RunLog '[던전] 선택 화면 복귀 확인 - 목표 구역 선택을 다시 시도합니다'
      continue
    }
    break
  }
  if (-not $selectionReady) {
    # (B) 오진단 분리: 원인과 무관하게 '미해금 추정'으로 단정하던 문구를 상황별로 나누고,
    # 코드 4에도 진단 세트(캡처+원시 OCR)를 남깁니다 (2026-07-22 좌표 문제를 미해금으로
    # 안내해 원인 추적을 막았던 실사고 교훈).
    $selectionFailure = if ($triedCandidateTypes.Count -gt 0) {
      "미등록 던전의 배치 후보($($triedCandidateTypes -join ', ') 시도)로 구역 ${ndStage}를 선택하지 못했습니다 (진입 버튼 문구: '$enterText')"
    } elseif ($stagePlanMissing) {
      if ($stageLabelSeen) { "구역 ${ndStage} 카드 위치를 다시 확정하지 못했습니다 (화면 인식 문제 가능)" }
      else { "구역 ${ndStage} 카드를 찾지 못했습니다 (미해금이거나 화면 인식 실패)" }
    } else {
      "구역 ${ndStage} 선택이 확인되지 않습니다 (진입 버튼 문구: '$enterText')"
    }
    Write-DgStageDiagnostics -Game $Game -Context "구역 ${ndStage} 선택 실패" -MapKind 'selection'
    if ($script:customMode) {
      Write-RunLog "[완료] $selectionFailure - 잘못된 구역 입장을 막기 위해 자동화를 정지합니다"
      exit 4
    }
    throw "$selectionFailure. 잘못된 구역 입장을 막기 위해 중단합니다."
  }
  } else {
    Write-RunLog '[던전] 시작: 진입 옵션 화면 감지 - 옵션 설정부터 진행'
  }
  # 선택 화면에서 새로 진입했거나 구역 오선택을 복구한 경우도 옵션 화면에서 목표 난이도를
  # 다시 맞춥니다. 선택 화면의 난이도가 유지된다고 가정하지 않고, 모든 진입 경로가 같은
  # 최종 난이도 클릭·선택 강조 확인을 거친 뒤 카드/입장 설정으로 진행합니다.
  # 0-커스텀(stay-adjust/stay-select)에서 방금 확정한 경우만 중복 클릭을 생략합니다.
  if ($customOptDiffAdjusted) {
    Write-RunLog "[던전] 난이도 '$ndDifficulty' 확정은 커스텀 시작 단계에서 완료 - 추가 클릭 생략"
  } else {
    # '매우 어려움' 요청은 비커스텀에서도 확정 실패를 치명 처리합니다 (없는 난이도 오입장 방지)
    $optDifficultyOk = Set-DgOptionDifficulty -Game $Game -Label $ndDifficulty -Strict:($script:customMode -or $ndVeryHardTarget)
    if (-not $optDifficultyOk) {
      if ($script:customMode) {
        # 화면 인식 실패 = 오류 (자동 재시작 1회 + 오류 세트 저장 - 2026-07-25 사용자 지적)
        throw "옵션 화면에서 난이도 '$ndDifficulty' 선택을 확정하지 못했습니다 - 화면 인식 실패로 중단합니다 (오난이도 판 방지)."
      }
      if ($ndVeryHardTarget) {
        throw "옵션 화면에서 '매우 어려움' 선택을 확정하지 못했습니다 - 오난이도 입장을 막기 위해 중단합니다."
      }
    }
  }
  if ($deepMode -and $ndVeryHardTarget) {
    # 주간 구역 최종 확인(옵션 화면 수렴점): 어려움 옵션 화면을 열어 두고 시작하면 위의
    # '매우 어려움' 확정과 함께 구역도 주간 단일 구역으로 바뀝니다. 확정 후 제목이 가리키는
    # 구역으로 재채택해 이후 제목 대조가 어긋나지 않게 합니다 (선택 경로는 진입 버튼에서
    # 이미 재채택 - 2026-07-28 실기 오채택 사고의 옵션 경로 방어).
    Start-Sleep -Milliseconds 400
    $weeklyTitleNow = (([string](& $readDgTitle)) -replace '\s', '')
    $weeklyTitleShapes = [regex]::Matches($weeklyTitleNow, '(\d)\D{0,2}(\d)구역')
    if ($weeklyTitleShapes.Count -gt 0) {
      $weeklyTitleStage = ('{0}-{1}' -f $weeklyTitleShapes[$weeklyTitleShapes.Count - 1].Groups[1].Value, `
          $weeklyTitleShapes[$weeklyTitleShapes.Count - 1].Groups[2].Value)
      if ($weeklyTitleStage -ne $ndStage -and $dgSelStagePoints['A'].ContainsKey($weeklyTitleStage)) {
        Write-RunLog "[심층] 주간 구역 최종 확인: ${ndStage} → ${weeklyTitleStage} (매우 어려움 확정 후 제목 기준)"
        $ndStage = $weeklyTitleStage
        $stageParts = $ndStage -split '-'
        $stageFloor = $stageParts[0]
        $stageArea = $stageParts[1]
      }
    }
  }
  Write-RunLog '[던전] 진입 옵션 화면 확인'

  # 5. 은동전(소탕)/더블 루팅을 설정값에 맞춥니다 (선택됨 = 사용 / 도전 = 미사용).
  #    커스텀/비커스텀 모두 같은 판정: 10~19개는 '더블 루팅 불가 시', 10개 미만은
  #    '동전 소진 시' 라디오 설정을 적용합니다.
  $effectiveCoin = $ndUseCoin
  $effectiveLoot = $ndDoubleLoot
  if ($ndUseCoin) {
    $coinBalance = Get-DgCoinBalance -Game $Game
    $coinDecision = Get-CustomCoinDecision -UseCoin $ndUseCoin -DoubleLoot $ndDoubleLoot -Balance $coinBalance `
      -ExhaustContinue $ndCoinFallback -NoDoubleSweep $ndLootFallback `
      -SweepCost $dgSweepCost -FullCost $dgFullCost -CurrencyName $dgCurrencyName -ExhaustLabel $dgExhaustLabel
    if ($coinDecision.Action -eq 'stop') {
      Write-RunLog "[완료] $($coinDecision.Reason)"
      exit 4
    }
    $effectiveCoin = [bool]$coinDecision.Coin
    $effectiveLoot = [bool]$coinDecision.Loot
    if ($coinDecision.Reason) { Write-RunLog "[던전] $($coinDecision.Reason)" }
  }
  $coinToggleOk = [bool](Set-DgToggleCard -Game $Game -Region $rgDgCoinButton -AltRegion $rgDgCoinButtonAlt -ClickPoint $ptDgCoinButton -WantSelected $effectiveCoin -Label "$dgCurrencyName(소탕)")
  $coinToggleClicked = $script:dgToggleClicked
  # 더블 루팅은 소탕(은동전) 전제 기능이라, 소탕을 해제하면 카드 자체가 화면에서 사라집니다.
  # 소탕을 사용할 때만 더블 루팅 상태를 맞추고, 미사용이면 확인을 생략합니다.
  # 심층던전에는 더블 루팅 카드가 없어(소탕 단독) 토글을 건너뜁니다 - 매우 어려움 화면의
  # 2번째 카드(능숙한 던전 소탕 - 무료 도전과제)를 오클릭하지 않기 위한 가드이기도 합니다.
  if ($effectiveCoin) {
    $lootToggleOk = $true
    $lootToggleClicked = $false
    if (-not $deepMode) {
      $lootToggleOk = [bool](Set-DgToggleCard -Game $Game -Region $rgDgLootButton -AltRegion $rgDgLootButtonAlt -ClickPoint $ptDgLootButton -WantSelected $effectiveLoot -Label '더블 루팅')
      $lootToggleClicked = $script:dgToggleClicked
    }

    # 5-1. '입장하기' 버튼의 공물(은동전) 소모량으로 더블 루팅 설정을 교차 검증합니다.
    #      소탕만 = 10, 더블 루팅까지 = 20. 카드 버튼 글자('선택됨'/'도전')보다 크고
    #      또렷해 더 확실합니다. 예상과 다르고 값이 유효(10/20)하면 더블 루팅 버튼을
    #      한 번 눌러 정정하고, 그래도 안 맞거나 값이 이상하면 경고만 남기고 진행합니다.
    Start-Sleep -Milliseconds 500
    $expectedCost = if ($effectiveLoot) { $dgFullCost } else { $dgSweepCost }
    $actualCost = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
    if ($null -eq $actualCost) {
      # 카드 설정도 미확인 + 소모량(2차 방어)도 판독 실패 = 설정 상태를 아무것도 보증할 수
      # 없는 상태입니다. 커스텀(항목별 명시 설정)은 반대 설정 완료 오계상을 막기 위해 정지
      # (2026-08-01 전수 점검 - 리뷰 조건: 소탕/더블 루팅 어느 카드든 실패 + 소모량 null).
      # 일반 모드는 기존대로 경고 진행 (OCR 약한 환경 헛 정지 방지).
      if ($script:customMode -and (-not $coinToggleOk -or -not $lootToggleOk)) {
        Write-RunLog "[완료] 카드 설정을 확인하지 못했고 소모량 판독도 실패했습니다 (소탕 확인: $coinToggleOk, 더블 루팅 확인: $lootToggleOk) - 반대 설정 입장을 막기 위해 정지합니다"
        exit 4
      }
      Write-RunLog "[던전] 공물 소모량을 읽지 못해 교차 검증을 건너뜁니다 (예상 ${expectedCost}개)"
    } elseif ($actualCost -eq $expectedCost) {
      Write-RunLog "[던전] 공물 소모량 ${actualCost}개 확인"
    } elseif ((-not $deepMode) -and ($dgValidCosts -contains $actualCost)) {
      # 심층은 더블 루팅이 없어 유효값 불일치(1↔2)를 버튼 클릭으로 정정할 수 없습니다 -
      # 아래 예상 밖 값 분기(커스텀 재확인 후 정지 / 비커스텀 경고 진행)로 흘려보냅니다.
      if (($coinToggleClicked -or $lootToggleClicked) -and $coinToggleOk -and $lootToggleOk) {
        # 방금 카드를 클릭해 전환을 글자로 확인한 직후의 유효값 불일치 = 소모량 표시 지연
        # 잔상 (2026-07-29 01:45 실측 13초+ 지연, 카드 확정 판독 > 소모량 잔상 증거 우선 계약.
        # 소모량은 두 카드의 합산이라 어느 쪽 클릭이든 지연 영향 - 리뷰 조건. 3차 점검 반영)
        Write-RunLog "[던전] 방금 카드 전환을 확인해 소모량 불일치(예상 ${expectedCost}, 실제 ${actualCost})는 표시 지연으로 판단 - 정정 클릭 생략"
      } elseif ($coinToggleClicked -or $lootToggleClicked) {
        # 방금 클릭했는데 카드 확인은 실패 - 정정 클릭은 이중 토글 위험이라 금지하고 무클릭
        # 재판독으로만 판정합니다 (리뷰 조건: clicked && !toggleOk 는 재판독 또는 정지)
        Start-Sleep -Milliseconds 2500
        $lagRecheck = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
        if ($null -ne $lagRecheck -and $lagRecheck -eq $expectedCost) {
          Write-RunLog "[던전] 공물 소모량 ${lagRecheck}개 재확인 (첫 판독 ${actualCost}는 표시 지연으로 판단)"
        } elseif ($script:customMode) {
          Write-RunLog "[완료] 카드 클릭 후 상태 확인에 실패했고 소모량도 항목 설정과 다릅니다 (예상 ${expectedCost}, 실제 ${actualCost}→'$lagRecheck') - 입장하지 않고 정지합니다"
          exit 4
        } else {
          Write-RunLog "[경고] 공물 소모량이 여전히 예상(${expectedCost})과 다릅니다 (실제 '$lagRecheck') - 현재 상태로 진행합니다"
        }
      } else {
      Write-RunLog "[경고] 공물 소모량 불일치 (예상 ${expectedCost}, 실제 ${actualCost}) - 더블 루팅 버튼을 눌러 정정합니다"
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptDgLootButton[0] -ReferenceY $ptDgLootButton[1]
      Start-Sleep -Milliseconds 1100
      $recheck = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
      if ($null -ne $recheck -and $recheck -eq $expectedCost) {
        Write-RunLog "[던전] 공물 소모량 ${recheck}개로 정정 확인"
      } elseif ($script:customMode) {
        # 커스텀 격상: 정정 재시도 후에도 항목 기대값과 다르면 입장하지 않습니다
        # (초과 = 은동전 이중 소모 / 미달 = 소탕 미적용 판 - 둘 다 항목 오계상 사고).
        # 코드 4(조건부 정지)라 오류 자동 재시도를 소모하지 않고, 마커가 없어 전진도 없습니다.
        Write-RunLog "[완료] 공물 소모량이 항목 설정과 계속 다릅니다 (예상 ${expectedCost}, 실제 '$recheck') - 입장하지 않고 정지합니다"
        exit 4
      } else {
        Write-RunLog "[경고] 공물 소모량이 여전히 예상(${expectedCost})과 다릅니다 (실제 '$recheck') - 현재 상태로 진행합니다"
      }
      }
    } elseif ($script:customMode) {
      # 예상 밖 값(10/20 이 아닌 숫자): 한 번의 잡음 판독으로 리스트 전체를 세우지 않도록
      # 재판독으로 '계속 불일치'를 확인한 뒤에만 정지합니다 (null = 판독 실패는 검증 생략 유지.
      # 상태 불명 재클릭은 하지 않음 - 무조건 재클릭 금지 원칙).
      Start-Sleep -Milliseconds 800
      $oddRecheck = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
      if ($null -ne $oddRecheck -and $oddRecheck -eq $expectedCost) {
        Write-RunLog "[던전] 공물 소모량 ${oddRecheck}개 재확인 (첫 판독 ${actualCost}는 OCR 잡음으로 판단)"
      } elseif ($null -eq $oddRecheck) {
        # 카드 미확인 + 첫 판독 잡음 + 재판독 실패 = 보증 없는 상태 - 커스텀은 정지
        # (2026-08-01 3차 점검: 이 경로가 null 게이트를 우회해 검증 없이 입장했음 - 리뷰 승인)
        if ($script:customMode -and (-not $coinToggleOk -or -not $lootToggleOk)) {
          Write-RunLog "[완료] 카드 설정을 확인하지 못했고 소모량 재판독도 실패했습니다 (첫 판독 '${actualCost}') - 반대 설정 입장을 막기 위해 정지합니다"
          exit 4
        }
        Write-RunLog "[던전] 공물 소모량 재판독 실패 - 교차 검증을 건너뜁니다 (예상 ${expectedCost}개)"
      } else {
        Write-RunLog "[완료] 공물 소모량이 항목 설정과 계속 다릅니다 (예상 ${expectedCost}, 실제 ${actualCost}→${oddRecheck}) - 입장하지 않고 정지합니다"
        exit 4
      }
    } else {
      Write-RunLog "[경고] 공물 소모량이 예상 밖입니다 (예상 ${expectedCost}, 실제 ${actualCost}) - OCR 오류 가능성이 있어 현재 상태로 진행합니다"
    }
  } else {
    # 5-1(역방향). 미사용(원래 설정이든 '소진 시 미사용으로 계속' 강등이든)인데도 입장
    # 버튼에 소모량(10/20)이 보이면 소탕 카드가 켜진 채 남은 것입니다 (2026-07-19 00:21
    # 실측: 카드 글자가 '선태되'로 깨져 판별 불가 → 해제 클릭을 못 한 채 잔량 6개로
    # 입장하기가 거부돼 45초 헛대기. 버튼 숫자 '10 입장하기'는 멀쩡히 읽혔음).
    # 버튼 숫자가 카드 글자보다 크고 또렷해 이걸로 역방향 검증합니다.
    # 단, 방금 우리가 카드를 클릭해 '도전' 전환을 카드 글자로 확인한 경우는 검증을 생략합니다
    # (2026-07-29 01:45 확정 실측: 게임이 카드를 끈 뒤에도 소모량 표시를 13초+ 남겨두는
    # 표시 지연이 정상이라 교차 검증의 정보가치가 없고, 경고 소음+헛대기만 남음. 전환 확인은
    # 카드 자체의 글자 재판독으로 이미 완료 - 클릭 대상 오인 불가. 리뷰 승인).
    if ($coinToggleClicked -and $coinToggleOk) {
      Write-RunLog "[던전] 방금 $dgCurrencyName(소탕) 카드를 도전(미사용)으로 전환 확인 - 소모량 표시 검증 생략 (전환 직후 표시 지연 정상)"
    } else {
    Start-Sleep -Milliseconds 500
    $offCost = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
    # 커스텀 미사용 항목 게이트: 카드 미확인($coinToggleOk=false) + 신뢰할 소모량 증거 없음
    # (null 또는 유효 밖 잡음 값)이면 설정 상태를 아무것도 보증할 수 없어 정지합니다
    # (2026-08-01 교차 리뷰 - 사용 경로와 대칭. null 은 '소모량 없음(미사용 정상)'과 '일반
    # OCR 실패'가 구분되지 않고, 유효 밖 숫자도 증거가 아님. 유효값(10/20)이 보이면 카드가
    # 켜진 증거라 아래 해제 루프가 처리. IME 팝업 가림도 동일하게 이 게이트에 걸림)
    if ($script:customMode -and -not $coinToggleOk -and
        ($null -eq $offCost -or -not ($dgValidCosts -contains $offCost))) {
      $offGateReason = $(if ($script:dgCostImeBlocked) { '입력기 팝업으로 소모량도 읽을 수 없습니다' }
        elseif ($null -eq $offCost) { '소모량 표시로도 확인할 수 없습니다' }
        else { "소모량 판독도 유효 밖 값('$offCost')입니다" })
      Write-RunLog "[완료] 카드 설정을 확인하지 못했고 $offGateReason - 반대 설정 입장을 막기 위해 정지합니다"
      exit 4
    }
    if ($script:dgCostImeBlocked) {
      Write-RunLog '[안내] 입력기 팝업이 입장 버튼을 가려 소모량 역방향 확인을 건너뜁니다 (카드 상태 기준 진행)'
    }
    if ($null -ne $offCost -and ($dgValidCosts -contains $offCost)) {
      Write-RunLog "[경고] ${dgCurrencyName} 미사용인데 입장 버튼에 소모량 ${offCost}개가 보입니다 - 소탕 카드를 눌러 해제합니다"
      # 상태 기반 해제 (2026-07-29 00:07 실기로 교체): 카드는 이미 '도전(미사용)'인데 입장
      # 버튼의 소모량 표시 갱신이 몇 초 늦는 경우, 기존의 offCost 기반 raw 클릭(최대 2회)이
      # 해제된 카드를 도로 켜는 토글 자기 방해가 됨. Set-DgToggleCard 를 **1회만** 호출해
      # 카드가 실제 '선택됨'일 때만 클릭하게 하고(이미 도전이면 무클릭), 그 후에는 클릭 없이
      # 2초 간격 수동 재판독으로 버튼 갱신을 기다립니다 (리뷰 계약 - 헬퍼 내부에 자체 재클릭
      # 로직이 있어 루프 반복 호출 금지).
      $offCleared = $false
      $imeOffWaitTotal = 0
      $offCardConfirmed = [bool](Set-DgToggleCard -Game $Game -Region $rgDgCoinButton -AltRegion $rgDgCoinButtonAlt -ClickPoint $ptDgCoinButton -WantSelected $false -Label "$dgCurrencyName(소탕)")
      for ($offTry = 1; $offTry -le 5; $offTry++) {
        Start-Sleep -Milliseconds 2000
        $offCost = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
        if ($script:dgCostImeBlocked) {
          # 팝업이 떠 있는 동안의 판독(null)은 해제 증거가 아님 - 이 바퀴는 세지 않고
          # 소멸을 기다립니다 (총 40초 한도, 초과 시 기존 불명확 분기 - 카드 증거 기준 처리)
          if ($imeOffWaitTotal -eq 0) { Write-RunLog '[안내] 입력기 팝업이 소모량 표시를 가리고 있습니다 - 사라질 때까지 대기' }
          if ($imeOffWaitTotal -ge 40) { break }
          $imeOffWaitTotal += 2
          $offTry--
          continue
        }
        if ($null -eq $offCost) {
          if (-not $script:screenCaptureFailing) { $offCleared = $true; break }
          # 캡처 실패 중의 null 은 해제 증거가 아니므로 다음 바퀴에서 재확인
        } elseif (-not ($dgValidCosts -contains $offCost)) {
          break   # 잡음 숫자 - 기존 계약대로 불명확 분기로
        }
      }
      if ($offCleared) {
        Write-RunLog '[던전] 소모량 표시 사라짐 - 은동전 미사용 확인'
      } elseif ($offCardConfirmed) {
        # 카드 '도전' 확정 판독 = 1차 증거 (2026-07-29 00:58 실측: 카드를 끈 직후 입장 버튼의
        # 소모량 표시가 갱신되지 않고 남는 잔상 - 수동 10초 대기로도 안 사라지고, 정지 직후
        # 캡처는 버튼 깨끗+카드 도전. 카드 클릭이 없던 항목은 무사 통과 = 잔상과 정합).
        # 카드 확인이 이기고 소모량 표시는 경고만 남기고 진행합니다 (리뷰 승인 -
        # 카드 미확인 시에만 아래 정지가 유지되어 07-19 원사고(카드 판별 불가+표시 10)도 커버).
        Write-RunLog "[경고] 소탕 카드는 '도전(미사용)'으로 확인됐지만 소모량 표시가 남아 있습니다 (판독: '$offCost') - 표시 잔상으로 판단하고 미사용으로 진행합니다"
      } elseif ($null -ne $offCost -and ($dgValidCosts -contains $offCost)) {
        if ($script:customMode) {
          # 커스텀 격상: 오류(코드 1) 대신 조건부 정지(코드 4) - 오류 자동 재시도 2회를
          # 소모하지 않습니다 (미사용 항목의 소모량 초과 표시도 '불일치 → 입장 불허' 계약에 포함)
          Write-RunLog "[완료] ${dgCurrencyName} 미사용 항목인데 소탕 해제가 안 됩니다 (소모량 ${offCost}개) - 입장하지 않고 정지합니다"
          exit 4
        }
        throw "${dgCurrencyName} 미사용 설정인데 소탕을 해제하지 못했습니다 (입장 버튼 소모량: ${offCost}개). 게임에서 소탕 카드를 직접 '도전'으로 바꾼 뒤 다시 시작해 주세요."
      } elseif ($script:customMode) {
        # 이 분기는 블록 서두에서 소모량 10/20(불일치)이 '확인'된 뒤 해제 확인만 불명확해진
        # 경우입니다. 이대로 입장하면 은동전 미사용 항목이 소모 판으로 돌 수 있어(이중 소모
        # 사고와 같은 유형) 커스텀은 진행하지 않고 정지합니다 (비커스텀은 기존 경고 후 진행).
        Write-RunLog "[완료] 소탕 해제 확인이 불명확합니다 (소모량 판독: '$offCost') - 입장하지 않고 정지합니다"
        exit 4
      } else {
        Write-RunLog "[경고] 소탕 해제 확인이 불명확합니다 (소모량 판독: '$offCost') - 현재 상태로 진행합니다"
      }
    }
    }
  }

  # 6. 매칭 방식 처리
  if ($ndMatching -eq '우연한 만남') {
    $toggleState = Get-ChanceToggleState -Game $Game -Point $ptDgChanceToggle
    if ($toggleState -eq 'unknown') {
      # 빈 프레임/픽셀 확인 불가: 켜져 있던 토글을 실수로 꺼버리지 않도록 클릭하지 않습니다
      Write-RunLog "[경고] '우연한 만남' 토글 상태를 판별하지 못했습니다(화면 확인 불가) - 클릭 없이 현재 상태로 진행합니다"
    } elseif ($toggleState -ne 'on') {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptDgChanceToggle[0] -ReferenceY $ptDgChanceToggle[1]
      Start-Sleep -Milliseconds 900
      if ((Get-ChanceToggleState -Game $Game -Point $ptDgChanceToggle) -eq 'on') {
        Write-RunLog "[던전] '우연한 만남' 토글 켬"
      } else {
        Write-RunLog "[경고] '우연한 만남' 토글이 켜진 것을 확인하지 못했습니다 - 현재 상태로 진행합니다"
      }
    } else {
      Write-RunLog "[던전] '우연한 만남' 토글 켜짐 확인"
    }
    # 7. 입장하기 클릭 → 옵션 화면을 실제로 벗어나는지 확인하며 재시도합니다.
    #    은동전이 부족하면 입장하기가 비활성이라 화면이 그대로 남는데, 이때
    #    '소진 시 미사용으로 계속' 설정이 켜져 있으면 소탕 선택을 해제하고 이어갑니다.
    Write-RunLog '[던전] 입장하기 클릭'
    $entered = $false
    $coinFallbackDone = $false
    $lootFallbackDone = $false
    $imePopupWaitTotal = 0
    for ($enterTry = 1; $enterTry -le 5; $enterTry++) {
      # 캡처 실패 중에는 입장 여부를 확인할 수 없는 채 클릭/시도 횟수만 소모되므로,
      # 제목 OCR을 복구 탐침 삼아 캡처가 돌아올 때까지 기다렸다가 진행합니다.
      while ($script:screenCaptureFailing) {
        Test-SafeStopDuringCaptureFail
        Start-Sleep -Seconds 2
        Get-GameRegionOcrText -Game $Game -ReferenceX $rgDgTitle[0] -ReferenceY $rgDgTitle[1] `
          -RegionWidth $rgDgTitle[2] -RegionHeight $rgDgTitle[3] -Scale 3 -Engine $ocrKoreanEngine | Out-Null
      }
      # IME 팝업 '사전' 확인 (2026-08-01 전수 점검: 기존에는 팝업을 감지한 뒤에도 다음 반복이
      # 확인 없이 다시 클릭해, 가려진 좌표를 최대 40초 동안 반복 클릭했음 - 클릭 전에 확인해
      # 재클릭 정책(원래 버튼이 보일 때만 클릭)을 지킵니다. 대기 한도(40초)·시도 미계상은
      # 아래 사후 확인과 공유 - 리뷰 승인)
      if (-not $script:screenCaptureFailing -and (Test-DgImePopupVisible -Game $Game)) {
        if ($imePopupWaitTotal -eq 0) {
          Write-RunLog '[안내] 입력기 팝업이 입장하기 버튼을 가리고 있습니다 - 사라질 때까지 대기'
        }
        if ($imePopupWaitTotal -ge 40) {
          throw '입력기 팝업이 계속 게임 화면을 가려 입장을 확인할 수 없습니다. 게임 창을 한 번 클릭해 팝업을 닫은 뒤 다시 시작해 주세요.'
        }
        Start-Sleep -Seconds 2
        $imePopupWaitTotal += 2
        $enterTry--
        continue
      }
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptDgEnterFinal[0] -ReferenceY $ptDgEnterFinal[1]
      Start-Sleep -Milliseconds 1200

      # 7-1. '던전에 입장하시겠습니까?' 확인 팝업(도전 미수락 시)이 뜨면 처리합니다.
      Resolve-DgEnterConfirmPopup -Game $Game | Out-Null

      # 옵션 화면(제목 'N구역')을 벗어났으면 입장(로딩)이 시작된 것입니다.
      # 로딩이 늦게 시작할 수 있어 2초 뒤 한 번 더 확인합니다.
      $titleNow = Read-DgTitleText -Game $Game
      if ($titleNow.Contains('구역')) {
        Start-Sleep -Seconds 2
        $titleNow = Read-DgTitleText -Game $Game
      }
      # 캡처 실패 중의 빈 OCR('')을 '옵션 화면을 벗어남'으로 오판하지 않도록 함께 확인합니다.
      if (-not $titleNow.Contains('구역') -and -not $script:screenCaptureFailing) {
        $entered = $true
        break
      }

      # 여전히 옵션 화면인데 IME 팝업이 입장하기 버튼을 덮고 있으면, 클릭이 게임에 닿지
      # 않은 것이므로 이 시도를 세지 않고 팝업 소멸을 기다립니다. 팝업 중에는 아래 재화
      # 부족 폴백도 평가하지 않습니다 - 팝업에 먹힌 클릭을 부족으로 오판해 소탕을 풀어버리는
      # 사고 방지 (2026-07-29 00:20 실기 + 리뷰 계약: 명시적 부족 증거 없이는 해제 금지).
      if (-not $script:screenCaptureFailing -and (Test-DgImePopupVisible -Game $Game)) {
        if ($imePopupWaitTotal -eq 0) {
          Write-RunLog '[안내] 입력기 팝업이 입장하기 버튼을 가리고 있습니다 - 사라질 때까지 대기'
        }
        if ($imePopupWaitTotal -ge 40) {
          throw '입력기 팝업이 계속 게임 화면을 가려 입장을 확인할 수 없습니다. 게임 창을 한 번 클릭해 팝업을 닫은 뒤 다시 시작해 주세요.'
        }
        Start-Sleep -Seconds 2
        $imePopupWaitTotal += 2
        $enterTry--
        continue
      }

      # 여전히 옵션 화면이면 잔량을 다시 읽어 같은 공용 판정으로 대응합니다. 잔량을 못 읽은
      # 경우에만 선택한 진행 옵션 범위 안에서 단계적으로 낮추며, '멈춤' 선택을 우회하지 않습니다.
      if ($enterTry -ge 2 -and $ndUseCoin -and -not $script:screenCaptureFailing) {
        $retryBalance = Get-DgCoinBalance -Game $Game
        $retryDecision = Get-CustomCoinDecision -UseCoin $ndUseCoin -DoubleLoot $ndDoubleLoot -Balance $retryBalance `
          -ExhaustContinue $ndCoinFallback -NoDoubleSweep $ndLootFallback `
      -SweepCost $dgSweepCost -FullCost $dgFullCost -CurrencyName $dgCurrencyName -ExhaustLabel $dgExhaustLabel
        if ($null -ne $retryBalance -and $retryDecision.Action -eq 'stop') {
          Write-RunLog "[완료] $($retryDecision.Reason)"
          exit 4
        }
        if ($null -ne $retryBalance -and $retryDecision.Coin -and -not $retryDecision.Loot -and $effectiveLoot -and -not $lootFallbackDone) {
          Write-RunLog "[던전] $($retryDecision.Reason)"
          Set-DgToggleCard -Game $Game -Region $rgDgLootButton -AltRegion $rgDgLootButtonAlt -ClickPoint $ptDgLootButton -WantSelected $false -Label '더블 루팅' | Out-Null
          $effectiveLoot = $false
          $lootFallbackDone = $true
        }
        if ($null -ne $retryBalance -and -not $retryDecision.Coin -and $effectiveCoin -and -not $coinFallbackDone) {
          if ($effectiveLoot) {
            Set-DgToggleCard -Game $Game -Region $rgDgLootButton -AltRegion $rgDgLootButtonAlt -ClickPoint $ptDgLootButton -WantSelected $false -Label '더블 루팅' | Out-Null
            $effectiveLoot = $false
          }
          Write-RunLog "[던전] $($retryDecision.Reason)"
          Set-DgToggleCard -Game $Game -Region $rgDgCoinButton -AltRegion $rgDgCoinButtonAlt -ClickPoint $ptDgCoinButton -WantSelected $false -Label "$dgCurrencyName(소탕)" | Out-Null
          $effectiveCoin = $false
          $coinFallbackDone = $true
        }
        # 잔량을 못 읽은 경우($null)의 '부족 추정' 해제 분기는 제거했습니다 (2026-07-29).
        # 클릭이 팝업 등에 먹혀 화면이 안 넘어간 것을 재화 부족으로 오판해, 잔량이 충분한데
        # 소탕/더블 루팅을 풀고 입장한 실사고(07-28 23:49, 공물 2개 보유)가 있었습니다.
        # 해제는 잔량이 실제로 읽힌 명시적 부족 증거가 있을 때만 하고, 못 읽으면 재시도 후
        # 아래의 안전 정지(오류)로 마칩니다 (리뷰 계약).
      }
    }
    if (-not $entered) {
      # 은동전 소진 대응이 '멈춤'이면 오류가 아니라 조건부 정상 정지(code 4)로 마칩니다.
      $finalBalance = Get-DgCoinBalance -Game $Game
      $finalDecision = Get-CustomCoinDecision -UseCoin $ndUseCoin -DoubleLoot $ndDoubleLoot -Balance $finalBalance `
        -ExhaustContinue $ndCoinFallback -NoDoubleSweep $ndLootFallback `
      -SweepCost $dgSweepCost -FullCost $dgFullCost -CurrencyName $dgCurrencyName -ExhaustLabel $dgExhaustLabel
      if ($null -ne $finalBalance -and $finalDecision.Action -eq 'stop') {
        Write-RunLog "[완료] $($finalDecision.Reason)"
        exit 4
      }
      if ($effectiveCoin -and $null -eq $finalBalance) {
        # 소탕 사용 중 + 잔량 미판독 + 입장 거부 = 재화 부족이 유력한 조합 (잔량 '0' 한 자리
        # 고립 숫자는 OCR이 자주 실패 - 2026-07-30 01:42 타 PC / 07-29 20:02 두 환경 실측).
        # 임의 해제 없이(부족 추정 해제 금지 계약 유지) 오류 대신 조건부 정상 정지로 안내한다
        # (이 지점은 클릭 5회 재시도+IME 팝업 대기+확인 팝업 처리를 지난 뒤라 일시 원인은
        # 소진된 상태 - 리뷰 승인).
        Write-RunLog "[완료] 입장이 진행되지 않습니다 - ${dgCurrencyName} 부족으로 보입니다 (잔량 판독 불가). 잔량을 확인해 충전하거나 소탕을 끄고 다시 시작해 주세요."
        exit 4
      }
      throw "입장하기가 진행되지 않습니다. ${dgCurrencyName} 잔량과 '소진 시/더블 루팅 불가 시' 설정을 확인해 주세요."
    }
  } else {
    # 파티찾기: '우연한 만남' 토글이 켜져 있으면 파티 찾기 버튼이 없고 그 자리가 넓은
    # 입장하기 버튼이라, 잘못 누르면 우연한 만남(혼자)으로 입장돼 버립니다.
    # 어비스와 동일하게 토글을 먼저 끄고 꺼짐을 확인한 뒤 파티 찾기를 클릭합니다.
    $toggleState = Get-ChanceToggleState -Game $Game -Point $ptDgChanceToggle
    # unknown 은 재판독으로 해소를 시도하고, 끝내 확인이 안 되면 정지합니다 (2026-08-01 전수
    # 점검: 기존 '꺼짐으로 보고 진행'은 토글이 실제로 켜져 있으면 그 자리의 넓은 입장하기
    # 버튼을 눌러 혼자 오입장 - 파티찾기는 정확한 꺼짐 확인이 안전 전제라 fail-closed. 리뷰 승인)
    for ($toggleProbe = 1; $toggleProbe -le 3 -and $toggleState -eq 'unknown'; $toggleProbe++) {
      Start-Sleep -Milliseconds 900
      $toggleState = Get-ChanceToggleState -Game $Game -Point $ptDgChanceToggle
    }
    if ($toggleState -eq 'unknown') {
      Write-RunLog "[완료] '우연한 만남' 토글 상태를 확인하지 못했습니다 - 오입장을 막기 위해 정지합니다. 화면을 확인하고 다시 시작해 주세요."
      exit 4
    }
    if ($toggleState -eq 'on') {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptDgChanceToggle[0] -ReferenceY $ptDgChanceToggle[1]
      Start-Sleep -Milliseconds 900
      # 끄기 확인도 'off' 확정을 요구합니다 (기존에는 'on'만 아니면 통과 → unknown 이 꺼짐으로 둔갑)
      $toggleAfterOff = Get-ChanceToggleState -Game $Game -Point $ptDgChanceToggle
      for ($toggleProbe = 1; $toggleProbe -le 3 -and $toggleAfterOff -ne 'off'; $toggleProbe++) {
        Start-Sleep -Milliseconds 900
        $toggleAfterOff = Get-ChanceToggleState -Game $Game -Point $ptDgChanceToggle
      }
      if ($toggleAfterOff -eq 'on') {
        throw "'우연한 만남' 토글을 끄지 못해 파티찾기를 진행할 수 없습니다 (토글이 켜진 상태에서는 파티 찾기 버튼이 없음)"
      }
      if ($toggleAfterOff -ne 'off') {
        # 클릭 후 재확인이 unknown = 판별 불가 - 최초 unknown 과 같은 조건부 정지(코드 4)로
        # 통일합니다 (교차 리뷰 지적: throw(코드 1)면 오류 재시도를 소모하는 비대칭)
        Write-RunLog "[완료] '우연한 만남' 토글을 끈 뒤 상태를 확인하지 못했습니다 - 오입장을 막기 위해 정지합니다. 화면을 확인하고 다시 시작해 주세요."
        exit 4
      }
      Write-RunLog "[던전] '우연한 만남' 토글 끔"
    }
    # 클릭하면 자동으로 파티 매칭이 진행되고, 파티가 구성되면 게임이 알아서
    # 던전에 입장합니다. 여기서는 클릭 후 아래의 입장 감지에서 매칭 완료를 기다립니다.
    Write-RunLog "[던전] '파티 찾기' 클릭 - 파티 매칭을 기다립니다"
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ptDgPartyFind[0] -ReferenceY $ptDgPartyFind[1]
    Start-Sleep -Milliseconds 1200
    # 입장 확인 팝업이 뜨는 경우 동일하게 처리합니다
    Resolve-DgEnterConfirmPopup -Game $Game | Out-Null
  }

  # 8. 던전 로딩/입장 완료 대기.
  #    - 우연한 만남: 바로 로딩되므로 HUD 표시로 판단 (어비스와 동일)
  #    - 파티찾기: 매칭 중에는 캐릭터가 필드에 나와 대기하는데 필드에도 HUD가 보이므로,
  #      HUD 대신 퀘스트 추적기의 'N구역 클리어' 목표(던전 안에서만 표시)로 입장을 판단합니다.
  Write-RunLog '[던전] 던전 로딩 중...'
  Start-Sleep -Seconds 1
  if ($ndMatching -eq '우연한 만남') {
    Wait-ForScreen -Game $Game -TimeoutSeconds $timeoutEntry -Description '던전 입장 완료 화면' -Condition {
      if (Invoke-PurchasePopupSweep -Game $Game) { return $false }
      Test-DungeonEntered -Game $Game
    }
  } else {
    Wait-ForScreen -Game $Game -TimeoutSeconds $timeoutPartyMatch -Description '파티 매칭 완료 후 던전 입장' -Condition {
      if (Invoke-PurchasePopupSweep -Game $Game) { return $false }
      ((Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
          -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', '').Contains('구역')
    }
  }
  Write-RunLog '[던전] 던전 입장 완료 감지'

  # 입장 후 키 입력 (자동출발/음식 - 어비스와 동일한 설정을 그대로 사용)
  Invoke-AfterEntryKeys -Game $Game -LogPrefix '[던전]'

  }  # end if (-not $insideAlready)

  # 10. 클리어 대기 - 어비스와 동일한 감지/안전장치(자동사냥 꺼짐 감시, 자동 부활,
  #     컷신 장면 넘기기, 구매 팝업 닫기)를 전부 그대로 사용합니다.
  Write-RunLog '[던전] 던전 클리어 화면 감지 대기 시작'
  $clearOutcome = Wait-ForDungeonClearScreen -Game $Game -TimeoutSeconds $timeoutClear -DungeonMode `
    -FindResultButton { Find-DgRetryButtonPoint -Game $Game }
  if ($clearOutcome -eq 'clear') {
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ptClearCenter[0] -ReferenceY $ptClearCenter[1]
    Write-RunLog '[던전] 던전 클리어 - 화면 터치'
  } else {
    Write-RunLog "[던전] 클리어 화면을 이미 지나친 상태($clearOutcome) - 결과 화면 처리로 진행"
  }

  }  # end if (-not $onResultScreen)

  # 12. 클리어 터치 후에는 엔딩 컷신이 나옵니다. '장면 넘기기'를 눌러 넘기고,
  #     결과 화면(전리품 + 나가기/다시 하기)이 나타날 때까지 기다립니다.
  if (-not $onResultScreen) {
    Write-RunLog '[던전] 결과 화면 대기 (엔딩 컷신은 자동으로 넘김)'
  }
  $dgRetryPoint = Wait-ForResultScreen -Game $Game -MissingMessage '던전 결과 화면(다시 하기 버튼)을 찾지 못했습니다.' `
    -FindRetryButton { Find-DgRetryButtonPoint -Game $Game }
  Write-RunLog '[던전] 결과 화면 확인 (나가기 / 다시 하기)'

  # 13-커스텀. 결과 화면 도달 = 이 판의 클리어 확정 지점 (정상 판/복구 판/전리품 공개 경유가
  # 전부 여기로 합류). 이후 마무리(다시 하기 → 옵션 복귀)에서 끊겨도 GUI가 완료로 계상하도록
  # 완료 마커를 먼저 기록합니다. 새 시작 정리 모드(수동 진행분)는 기록하지 않습니다.
  if ($script:customMode -and -not $script:customCleanupOnly) {
    Write-CustomClearMarker
  }

  # 14. 안전 중지가 예약돼 있으면 나가기로 마치고, 아니면 다시 하기로 곧장 재입장합니다.
  Invoke-SafeStopExitIfRequested -Game $Game

  # 14-0. 마지막 판(GUI가 HONEYNOGI_LAST_RUN 으로 사전 판정: 커스텀 N바퀴의 마지막 바퀴
  #       마지막 항목 / 횟수 지정 마지막 회차 - 2026-07-25 사용자 요청)이면 '나가기'로 필드에
  #       나가며 마칩니다. 이후 회차가 없어 옵션 화면에 머물 이유가 없고, 나가기의 '자동 복귀
  #       불가' 문제(계약 v4에서 폐기된 이유)는 마지막 판에는 해당하지 않습니다.
  #       시간 지정/무한/안전 중지는 마지막 판을 사전에 알 수 없어 기존 그대로이며,
  #       수동 정리 모드(코드 10 - 같은 항목을 새로 시작)는 제외합니다.
  #       은동전 잔량 검사(14-1)보다 앞: 마지막 판에는 '다음 판' 잔량 판단이 무의미 (설계 합의).
  if ($script:dgLastRun -and -not $script:customCleanupOnly) {
    # '나가기' 글자 탐색 우선 (2버튼/3버튼 배치 모두 커버하는 영역), 실패 시 실측 예비 좌표
    Focus-Game -Game $Game
    $lastExitPoint = Find-GameTextPoint -Game $Game -ReferenceX 440 -ReferenceY 625 -RegionWidth 260 -RegionHeight 60 `
      -SearchText '나가' -ExactText '나가기'
    if ($lastExitPoint) {
      Click-ScreenPoint -X $lastExitPoint.X -Y $lastExitPoint.Y
    } else {
      Click-GamePoint -Game $Game -ReferenceX $ptDgResultExit[0] -ReferenceY $ptDgResultExit[1]
    }
    Write-RunLog "[던전] 마지막 판 완료 - '나가기'로 필드에 나가며 자동화를 마칩니다"
    $fieldDeadline = (Get-Date).AddSeconds(40)
    $fieldStreak = 0
    $fieldReached = $false
    while ((Get-Date) -lt $fieldDeadline) {
      Start-Sleep -Seconds 2
      if ($script:screenCaptureFailing) {
        Test-SafeStopDuringCaptureFail
        $fieldDeadline = (Get-Date).AddSeconds(40)
        continue
      }
      # 판독 도중 캡처 실패는 누적 래치로 잡습니다 - 뒤 판독이 성공하면 전역 플래그가
      # 지워져 중간 실패를 놓칠 수 있음 (리뷰 조건: 실패 누적)
      $probeFailed = $false
      $probeHud = Test-HomeEndEscHud -Game $Game
      if ($script:screenCaptureFailing) { $probeFailed = $true }
      $probeQuest = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
        -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine)
      if ($script:screenCaptureFailing) { $probeFailed = $true }
      $probeCenter = Get-GameOcrText -Game $Game
      if ($script:screenCaptureFailing) { $probeFailed = $true }
      $probeRetry = [bool](Find-DgRetryButtonPoint -Game $Game)
      if ($script:screenCaptureFailing) { $probeFailed = $true }
      # 판독 도중 캡처 실패가 있었으면 이번 판독분은 신뢰하지 않습니다
      if ($probeFailed) { continue }
      $exitStep = Get-DgLastRunExitStep -HudVisible $probeHud -QuestText $probeQuest `
        -CenterText $probeCenter -RetryVisible $probeRetry
      if ($exitStep -eq 'field-evidence') {
        # 단발 OCR 오판 방지: 연속 2회 확인될 때만 필드로 확정 (리뷰 조건)
        $fieldStreak++
        if ($fieldStreak -ge 2) {
          $fieldReached = $true
          break
        }
        continue
      }
      $fieldStreak = 0
      if ($exitStep -eq 'popup-exit') {
        # '던전 탐험을 계속하시겠습니까?' 팝업: 목적이 '나감'이므로 나가기(Space)를 선택합니다
        # (다시 하기 경로의 ESC=계속하기와 반대. '탐험'+'계속하' 두 신호 확인 시에만 입력)
        Focus-Game -Game $Game
        Press-KeyOnce -VirtualKey ([byte]32)
        Write-RunLog "[던전] '던전 탐험을 계속하시겠습니까?' 팝업 - 나가기(Space) 선택"
        Start-Sleep -Seconds 1
        continue
      }
      if ($exitStep -eq 'reclick') {
        # 결과 화면(다시 하기 버튼)이 그대로 보일 때만 상태 기반 재클릭
        Write-RunLog "[던전] 결과 화면이 남아 있어 '나가기'를 다시 클릭합니다"
        Focus-Game -Game $Game
        $lastExitRetry = Find-GameTextPoint -Game $Game -ReferenceX 440 -ReferenceY 625 -RegionWidth 260 -RegionHeight 60 `
          -SearchText '나가' -ExactText '나가기'
        if ($lastExitRetry) {
          Click-ScreenPoint -X $lastExitRetry.X -Y $lastExitRetry.Y
        } else {
          Click-GamePoint -Game $Game -ReferenceX $ptDgResultExit[0] -ReferenceY $ptDgResultExit[1]
        }
      }
    }
    if ($fieldReached) {
      Write-RunLog '[던전] 필드 복귀 확인 - 회차 완료'
    } else {
      # 판은 클리어 확정 상태(완료 마커 기록됨) - 코드 1로 던지면 GUI 오류 재시작이 완료된
      # 마지막 판을 재실행할 위험이 있어, 진단만 남기고 정상 종료합니다 (설계 합의)
      Write-DgStageDiagnostics -Game $Game -Context '마지막 판 나가기 후 필드 미확인' -MapKind 'selection'
      Write-RunLog '[경고] 나가기 후 필드 복귀를 확인하지 못했습니다 - 판은 완료 상태라 그대로 마칩니다'
    }
    exit 0
  }

  # 14-1. 다음 판의 은동전 잔량이 선택한 소진 대응에서 '멈춤' 조건이면 나가기를 누르고
  #       '조건에 따른 정상 정지'(코드 4)로 마칩니다. 결과 화면 우상단 재화 표시줄에서
  #       잔량을 읽습니다 ('은동전이 부족해요' 말풍선이 뜨는 상황 - 실측 검증).
  #       커스텀 반복에서는 이 검사를 생략합니다: ①'같은 설정 반복' 전제인데 다음 판은 다른
  #       항목(코인 미사용일 수도)이라 정지가 오판이 되고 ②나가기 클릭이 던전 UI를 떠나
  #       커스텀 연속 진행 전제(옵션 화면 잔류)를 깨며 ③마커 기록 후의 코드 4는 GUI가
  #       '전진 후 정지'로 처리해 다음 항목이 코인 불요여도 리스트가 서 버립니다.
  #       커스텀의 소진 판정은 다음 워커의 '시작 전 잔량 확인'(항목 기준)이 정확한 시점에 수행.
  if (-not $script:customMode -and $ndUseCoin) {
    $resultBalance = Get-DgCoinBalance -Game $Game
    $resultDecision = Get-CustomCoinDecision -UseCoin $ndUseCoin -DoubleLoot $ndDoubleLoot -Balance $resultBalance `
      -ExhaustContinue $ndCoinFallback -NoDoubleSweep $ndLootFallback `
      -SweepCost $dgSweepCost -FullCost $dgFullCost -CurrencyName $dgCurrencyName -ExhaustLabel $dgExhaustLabel
    if ($null -ne $resultBalance -and $resultDecision.Action -eq 'stop') {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptDgResultExit[0] -ReferenceY $ptDgResultExit[1]
      Write-RunLog "[완료] $($resultDecision.Reason) - 나가기를 누르고 설정대로 자동화를 마칩니다"
      Start-Sleep -Seconds 2
      exit 4
    }
  }

  # 14-2. 커스텀 반복 갈림길 (판정식: Get-CustomFinishAction, 계약 v4 - 2026-07-20 실기 검증):
  #       v3의 '나가기 → 선택 화면' 마무리는 폐기 - 결과 화면 '나가기'는 필드로 나가버려
  #       자동 복귀가 불가능합니다 (실측. 안전 중지/잔량 부족의 기존 나가기 정지 경로는
  #       '정지'가 목적이라 그대로 유지). 대신:
  #       · NEXT 없음/같은 층('retry') → 기존 '다시 하기'로 마침 - 다시 하기로 돌아온 옵션
  #         화면에서 같은 층 구역(역방향 포함)·난이도를 다음 워커가 바꿉니다 (0-커스텀
  #         stay-adjust/stay-select).
  #       · 현재 1-3 + NEXT 2층('next-floor') → 결과 화면의 '다음 층으로'를 글자 탐색으로
  #         클릭하고 화면 전환을 확인한 뒤 회차를 마칩니다 (코드 0 - 완료 마커는 13-커스텀에서
  #         이미 기록됨). 실측: '다음 층으로' → 2층 구역 선택 화면 - 다음 워커가 그 화면에서
  #         시작합니다. 버튼을 못 찾으면 방어적으로 다시 하기로 마치고 경고만 남깁니다.
  #       · 그 외 층 전환('retry-warn' - 2층→1층, 1-3 아닌 1층→2층) → GUI 리스트 검증이
  #         사전 차단하는 조합이라 정상 경로에서 나오지 않음 - 방어적으로 다시 하기로 마치고
  #         경고 로그 (다음 워커의 시작 검증(go-back 실패 시 코드 4)이 잡습니다).
  #       안전 중지 예약은 위 14의 기존 나가기 경로가 우선합니다 (여기 도달 = 예약 없음).
  #       수동 진행분 정리 모드(customCleanupOnly)는 같은 항목을 새로 시작하므로 기존
  #       다시 하기 → 코드 10 경로를 그대로 탑니다.
  if ($script:customMode -and -not $script:customCleanupOnly) {
    $customFinishAction = Get-CustomFinishAction -Item $script:customItem -Next $script:customNext
    if ($customFinishAction -eq 'next-floor') {
      Write-RunLog "[커스텀] 다음 항목이 2층 - '다음 층으로'로 이동하며 회차를 마칩니다"
      $nextFloorPoint = Find-DgNextFloorButtonPoint -Game $Game
      if (-not $nextFloorPoint) {
        Write-RunLog "[경고] '다음 층으로' 버튼을 찾지 못했습니다 - 일단 '다시 하기'로 마칩니다 (다음 회차의 시작 검증이 이어서 판정)"
      } else {
        Focus-Game -Game $Game
        Click-ScreenPoint -X $nextFloorPoint.X -Y $nextFloorPoint.Y
        Write-RunLog "[던전] '다음 층으로' 클릭 - 다음 층 구역 선택 화면 대기"
        # 전환 확인은 아래 다시 하기 대기와 같은 규칙: 제목이 던전 UI(구역/선택 화면)로
        # 바뀌면 성공, '던전 탐험을 계속하시겠습니까?' 팝업은 계속하기로 넘기고,
        # 재클릭은 결과 화면('다음 층으로' 버튼)이 그대로 보일 때만 합니다 (상태 기반).
        $floorDeadline = (Get-Date).AddSeconds(40)
        $movedToNextFloor = $false
        while ((Get-Date) -lt $floorDeadline) {
          Start-Sleep -Seconds 2
          if ($script:screenCaptureFailing) {
            Test-SafeStopDuringCaptureFail
            $floorDeadline = (Get-Date).AddSeconds(40)
            continue
          }
          $floorTitleNow = & $readDgTitle
          if ($floorTitleNow.Contains('구역') -or (Test-DgSelectionTitle -TitleText $floorTitleNow)) {
            $movedToNextFloor = $true
            break
          }
          $floorCenterNow = (Get-GameOcrText -Game $Game) -replace '\s', ''
          if ($floorCenterNow.Contains('계속하')) {
            $floorContPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] `
              -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -SearchText '계속하'
            Focus-Game -Game $Game
            if ($floorContPoint) {
              Click-ScreenPoint -X $floorContPoint.X -Y $floorContPoint.Y
            } else {
              Press-KeyOnce -VirtualKey ([byte]27)   # ESC = 계속하기 (버튼 지점을 못 찾은 경우 예비)
            }
            Write-RunLog "[던전] '던전 탐험을 계속하시겠습니까?' 팝업 - 계속하기 선택"
            Start-Sleep -Seconds 1
            continue
          }
          # 아침 6시 리셋 블로커 처리 ('다시 하기' 복귀 대기와 같은 계약 - 이 대기도 40초라
          # 리셋 팝업/협동 창에 가려지면 동일하게 시간 초과 (2026-08-03 리뷰 배선 확장.
          # 협동 미션 전체 창은 스윕 안에서 함께 처리됨)
          if (Invoke-PurchasePopupSweep -Game $Game) { continue }
          if (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix '[던전] ') { continue }
          $floorAgainPoint = Find-DgNextFloorButtonPoint -Game $Game
          if ($floorAgainPoint) {
            Write-RunLog "[던전] 결과 화면이 남아 있어 '다음 층으로'를 다시 클릭합니다"
            Focus-Game -Game $Game
            Click-ScreenPoint -X $floorAgainPoint.X -Y $floorAgainPoint.Y
          }
        }
        if (-not $movedToNextFloor) {
          # 완료 마커는 이미 기록돼 있어 GUI가 이 판을 완료로 계상하고 다음 항목을 재시작합니다
          throw "'다음 층으로' → 다음 층 구역 선택 화면 대기 시간이 초과됐습니다."
        }
        Write-RunLog '[커스텀] 다음 층 화면 전환 확인 - 회차 완료'
        exit 0
      }
    } elseif ($customFinishAction -eq 'retry-warn') {
      Write-RunLog "[경고] 다음 항목($(Format-CustomItemLabel -Item $script:customNext))은 결과 화면에서 이동할 수 없는 층 전환입니다 - 일단 '다시 하기'로 마칩니다 (다음 회차의 시작 검증이 이어서 판정)"
    }
  }
  # '다시 하기'는 던전에 바로 들어가지 않고 진입 옵션 화면으로 돌아갑니다(도전을 다시 고를
  # 기회를 줌). 옵션 화면이 뜨면 이번 회차를 마치고, 다음 회차 워커가 '옵션 화면'을
  # 인식해 은동전/더블 루팅 설정부터 이어갑니다.
  # 주의 (2026-07-18 17:04 실측 사고): 던전 밖에서 진행할 퀘스트가 있으면 다시 하기 뒤에
  # '던전 탐험을 계속하시겠습니까?' 팝업(계속하기=ESC / 나가기=Space)이 끼어듭니다.
  # 무조건 재클릭하면 그 자리가 팝업의 '나가기' 버튼이라 던전 밖으로 나가버리므로,
  # '계속하'가 보이면 계속하기를 누르고, 재클릭은 결과 화면(다시 하기 버튼)이
  # 그대로 보일 때만 합니다 (사냥터 '새 임무 선택'과 동일한 규칙).
  # 3버튼 배치에서 옛 고정 좌표(757,654)는 '다음 구역으로' 자리라, 탐색으로 찾은
  # '다시 하기' 글자 지점을 클릭합니다 (다른 스테이지로 넘어가는 오클릭 방지 - 실측).
  Focus-Game -Game $Game
  if ($dgRetryPoint) {
    Click-ScreenPoint -X $dgRetryPoint.X -Y $dgRetryPoint.Y
  } else {
    Click-GamePoint -Game $Game -ReferenceX $ptDgRetry[0] -ReferenceY $ptDgRetry[1]
  }
  Write-RunLog "[던전] '다시 하기' 클릭 - 옵션 화면 복귀 대기"
  $optionsDeadline = (Get-Date).AddSeconds(40)
  $backToOptions = $false
  while ((Get-Date) -lt $optionsDeadline) {
    Start-Sleep -Seconds 2
    if ($script:screenCaptureFailing) {
      Test-SafeStopDuringCaptureFail
      $optionsDeadline = (Get-Date).AddSeconds(40)
      continue
    }
    if ((Read-DgTitleText -Game $Game).Contains('구역')) {
      $backToOptions = $true
      break
    }
    $centerNow = (Get-GameOcrText -Game $Game) -replace '\s', ''
    if ($centerNow.Contains('계속하')) {
      $contPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] `
        -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -SearchText '계속하'
      Focus-Game -Game $Game
      if ($contPoint) {
        Click-ScreenPoint -X $contPoint.X -Y $contPoint.Y
      } else {
        Press-KeyOnce -VirtualKey ([byte]27)   # ESC = 계속하기 (버튼 지점을 못 찾은 경우 예비)
      }
      Write-RunLog "[던전] '던전 탐험을 계속하시겠습니까?' 팝업 - 계속하기 선택"
      Start-Sleep -Seconds 1
      continue
    }
    # 아침 6시 리셋 블로커 처리 (2026-08-03 06:02 실사고: 월요일 주간 협동 리셋 팝업이 이
    # 대기를 40초 막아 무인 정지 → 3연속 오류. '계속하' 처리 뒤 순서 - Space 위험 팝업 우선.
    # 닫은 경우 continue 로 재캡처해 같은 프레임으로 다음 판정을 하지 않음 - 리뷰 조건)
    if (Invoke-PurchasePopupSweep -Game $Game) { continue }
    if (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix '[던전] ') { continue }
    if (-not $script:screenCaptureFailing -and (Test-NoticeBoardPopup -Game $Game)) {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptNoticeClose[0] -ReferenceY $ptNoticeClose[1]
      Write-RunLog '[던전] 공지 게시판 팝업 감지 - X로 닫기 (복귀 대기 중)'
      Start-Sleep -Seconds 2
      continue
    }
    $retryAgainPoint = Find-DgRetryButtonPoint -Game $Game
    if ($retryAgainPoint) {
      Write-RunLog "[던전] 결과 화면이 남아 있어 '다시 하기'를 다시 클릭합니다"
      Focus-Game -Game $Game
      Click-ScreenPoint -X $retryAgainPoint.X -Y $retryAgainPoint.Y
    }
  }
  if (-not $backToOptions) {
    throw '다시 하기 → 진입 옵션 화면 대기 시간이 초과됐습니다.'
  }
  if ($script:customCleanupOnly) {
    # 수동 진행분 정리 완료: 화면은 옵션 화면까지 복귀됐고, 판은 계상하지 않습니다.
    # 코드 10 = 준비 실행 - GUI가 회차로 세지 않고 같은 항목을 새로 시작합니다.
    Write-RunLog '[커스텀] 수동 진행분 화면 정리 완료 - 판으로 계상하지 않습니다 (준비 실행)'
    exit 10
  }
  Write-RunLog '[던전] 다시 하기 → 옵션 화면 복귀 - 회차 완료'
  exit 0
}

function Invoke-HuntingGroundCycle {
  param([System.Diagnostics.Process]$Game)

  # '사냥터' 자동화 - 특정 사냥터에 매이지 않는 범용 방식입니다.
  # 사용자가 원하는 사냥터의 첫 화면(하단에 '파티 찾기 / 입장하기')을 열어 두면
  # 난이도/공물(사냥 임무)을 설정하고 입장 → 사냥 완료 → 결과 → 다시 하기로 반복합니다.
  # 새 사냥터가 게임에 추가되어도 프로그램 수정 없이 그대로 동작합니다.
  $script:contentTag = '[사냥터]'
  Write-RunLog "[사냥터] 자동화 시작: 난이도 '$htDifficulty', 은동전 $(if ($htUseCoin) { '사용' } else { '미사용' })$(if ($htUseCoin -and $htDoubleLoot) { ' + 더블 루팅' }), 매칭 '$htMatching'"

  # 시작 화면 판정 전 전체 화면 팝업 정리 (던전/심층 시작부와 같은 계약 - 2026-08-01 실사고)
  for ($startSweep = 1; $startSweep -le 2; $startSweep++) {
    if (-not (Invoke-PurchasePopupSweep -Game $Game)) { break }
    Start-Sleep -Milliseconds 1200
  }

  # 0. 현재 화면 판별: 첫 화면(입장하기 버튼) / 결과 화면(새 임무 선택) / 사냥 진행 중(임무 표시)
  $onEntryScreen = [bool](Find-HtEntryButtonPoint -Game $Game)
  $onResultScreen = $false
  $insideAlready = $false
  if (-not $onEntryScreen) {
    if (Find-HtNewMissionPoint -Game $Game) {
      $onResultScreen = $true
      Write-RunLog '[사냥터] 시작: 결과 화면 감지 - 재입장부터 진행'
    } elseif (Test-DungeonClearPrompt -Game $Game) {
      # 완료 화면(화면을 터치)에 멈춘 채 재시작한 경우: 터치로 넘긴 뒤 결과 처리부터 이어갑니다
      Write-RunLog '[사냥터] 시작: 완료 화면 감지 - 화면 터치부터 진행'
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptClearCenter[0] -ReferenceY $ptClearCenter[1]
      Start-Sleep -Seconds 2
      $onResultScreen = $true
    } else {
      # 사냥 중에는 퀘스트 추적기에 '몬스터 소탕 N회'/'구역 정찰' 같은 사냥 임무가 표시됩니다
      $questText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
        -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
      if ((Test-HomeEndEscHud -Game $Game) -and ($questText.Contains('소탕') -or $questText.Contains('정찰'))) {
        $insideAlready = $true
        Write-RunLog '[사냥터] 시작: 사냥 진행 중 감지 - 완료 대기부터 재개'
      } else {
        throw "사냥터 화면이 아닙니다. 원하는 사냥터의 첫 화면(하단에 '파티 찾기 / 입장하기')을 열어 두고 시작해 주세요."
      }
    }
  }

  if (-not $onResultScreen) {

  if (-not $insideAlready) {

  # 1. 난이도 클릭 (화면 상단 중앙의 알약: 일반/어려움, 일부 사냥터는 매우 어려움도 있음).
  #    '매우 어려움'은 두 단어로 읽히므로 앞 2글자('매우')로 찾습니다. 해당 사냥터에
  #    없는 난이도를 선택했으면 글자를 못 찾고 현재 난이도로 그대로 진행합니다.
  $difficultyKey = $htDifficulty -replace '\s', ''
  $difficultySearch = $difficultyKey.Substring(0, [Math]::Min(2, $difficultyKey.Length))
  $difficultyPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgHtDifficulty[0] -ReferenceY $rgHtDifficulty[1] `
    -RegionWidth $rgHtDifficulty[2] -RegionHeight $rgHtDifficulty[3] -Scale 4 -SearchText $difficultySearch -ExactText $difficultyKey
  if ($difficultyPoint) {
    Focus-Game -Game $Game
    Click-ScreenPoint -X $difficultyPoint.X -Y $difficultyPoint.Y
    Write-RunLog "[사냥터] 난이도 '$htDifficulty' 클릭"
    Start-Sleep -Milliseconds 900
    # 사후 검증: 클릭이 빗나가 다른 난이도로 바뀌지 않았는지 선택 강조로 확인 (첫 좌표 재사용)
    Confirm-DifficultySelected -Game $Game -ClickPoint $difficultyPoint -Label $htDifficulty | Out-Null
  } else {
    Write-RunLog "[경고] 난이도 '$htDifficulty' 글자를 찾지 못했습니다 (이 사냥터에 없는 난이도일 수 있음) - 현재 선택된 난이도로 진행합니다"
  }

  # 2. 은동전(사냥 임무)/더블 루팅 카드 설정 - 소탕 10개, 더블 루팅 +10개(합 20개).
  #    잔량 10~19개는 옵션에 따라 더블 루팅만 끄고 계속, 10개 미만이면 나가서 마칩니다.
  $effectiveCoin = $htUseCoin
  $effectiveLoot = ($htUseCoin -and $htDoubleLoot)
  if ($htUseCoin) {
    $coinBalance = Get-DgCoinBalance -Game $Game
    if ($null -ne $coinBalance) {
      if ($coinBalance -lt 10) {
        Exit-HuntingGroundExhausted -Game $Game -Reason "은동전 잔량 ${coinBalance}개 (소탕에 10개 필요) - 소진"
      } elseif ($effectiveLoot -and $coinBalance -lt 20) {
        if ($htLootFallback) {
          $effectiveLoot = $false
          Write-RunLog "[사냥터] 은동전 잔량 ${coinBalance}개 (더블 루팅 포함 20개 필요) - 더블 루팅만 끄고 소탕(10개)으로 계속합니다"
        } else {
          Exit-HuntingGroundExhausted -Game $Game -Reason "은동전 잔량 ${coinBalance}개 (더블 루팅 포함 20개 필요, '소탕만 계속' 옵션 꺼짐)"
        }
      }
    }
  }
  $coinToggleOk = [bool](Set-DgToggleCard -Game $Game -Region $rgHtCardButton -AltRegion $rgHtCardButtonAlt -ClickPoint $ptHtCardButton -WantSelected $effectiveCoin -Label '은동전(사냥 임무)')
  $coinToggleClicked = $script:dgToggleClicked
  # 더블 루팅은 소탕(은동전) 전제 기능이라 소탕을 사용할 때만 상태를 맞춥니다 (던전과 동일)
  if ($effectiveCoin) {
    Set-DgToggleCard -Game $Game -Region $rgHtLootButton -AltRegion $rgHtLootButtonAlt -ClickPoint $ptHtLootButton -WantSelected $effectiveLoot -Label '더블 루팅' | Out-Null

    # 입장 버튼의 공물 소모량(소탕 10 / 더블 루팅 20)으로 교차 검증합니다 (던전과 동일 영역).
    # 사냥터 화면에 소모량 표기가 없으면 읽기 실패로 건너뛰므로 무해합니다.
    Start-Sleep -Milliseconds 500
    $expectedCost = if ($effectiveLoot) { $dgFullCost } else { $dgSweepCost }
    $actualCost = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
    if ($null -eq $actualCost) {
      Write-RunLog "[사냥터] 공물 소모량을 읽지 못해 교차 검증을 건너뜁니다 (예상 ${expectedCost}개)"
    } elseif ($actualCost -eq $expectedCost) {
      Write-RunLog "[사냥터] 공물 소모량 ${actualCost}개 확인 (더블 루팅 $(if ($effectiveLoot) { '켬' } else { '끔' })과 일치)"
    } elseif ((-not $deepMode) -and ($dgValidCosts -contains $actualCost)) {
      # 심층은 더블 루팅이 없어 유효값 불일치(1↔2)를 버튼 클릭으로 정정할 수 없습니다 -
      # 아래 예상 밖 값 분기(커스텀 재확인 후 정지 / 비커스텀 경고 진행)로 흘려보냅니다.
      Write-RunLog "[경고] 공물 소모량 불일치 (예상 ${expectedCost}, 실제 ${actualCost}) - 더블 루팅 버튼을 눌러 정정합니다"
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptHtLootButton[0] -ReferenceY $ptHtLootButton[1]
      Start-Sleep -Milliseconds 1100
      $recheck = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
      if ($null -ne $recheck -and $recheck -eq $expectedCost) {
        Write-RunLog "[사냥터] 공물 소모량 ${recheck}개로 정정 확인"
      } else {
        Write-RunLog "[경고] 공물 소모량이 여전히 예상(${expectedCost})과 다릅니다 (실제 '$recheck') - 현재 상태로 진행합니다"
      }
    } else {
      Write-RunLog "[경고] 공물 소모량이 예상 밖입니다 (예상 ${expectedCost}, 실제 ${actualCost}) - OCR 오류 가능성이 있어 현재 상태로 진행합니다"
    }
  } else {
    # 역방향 검증: 미사용인데도 시작 버튼에 소모량(10/20)이 보이면 카드가 켜진 채 남은 것
    # (던전 2026-07-19 00:21 실측 사고와 동일 구조 - 카드 글자 깨짐 대비).
    # 사냥터 화면에 소모량 표기가 없으면 읽기 실패($null)로 건너뛰므로 무해합니다.
    # 방금 우리가 클릭해 '도전' 전환을 확인한 경우는 생략 (전환 직후 소모량 표시가 13초+
    # 남는 게임 표시 지연이 정상 - 던전 역방향과 동일 계약, 2026-07-29 01:45 실측)
    if ($coinToggleClicked -and $coinToggleOk) {
      Write-RunLog '[사냥터] 방금 은동전(사냥 임무) 카드를 도전(미사용)으로 전환 확인 - 소모량 표시 검증 생략 (전환 직후 표시 지연 정상)'
    } else {
    Start-Sleep -Milliseconds 500
    $offCost = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
    if ($script:dgCostImeBlocked) {
      Write-RunLog '[안내] 입력기 팝업이 시작 버튼을 가려 소모량 역방향 확인을 건너뜁니다 (카드 상태 기준 진행)'
    }
    if ($null -ne $offCost -and ($dgValidCosts -contains $offCost)) {
      Write-RunLog "[경고] 은동전 미사용인데 시작 버튼에 소모량 ${offCost}개가 보입니다 - 은동전(사냥 임무) 카드를 눌러 해제합니다"
      # 상태 기반 해제 (던전 역방향 검증과 동일한 계약 - 2026-07-29 00:07 실측).
      # 소모량 표시는 버튼 갱신 지연으로 카드보다 늦게 바뀔 수 있어, 소모량만 보고 raw 클릭을
      # 반복하면 이미 해제된 카드를 도로 켜는 토글 자기 방해가 됨. Set-DgToggleCard 를 **1회만**
      # 호출해 카드 상태 기준으로 해제하고, 이후에는 클릭 없이 소모량 사라짐만 재확인한다.
      $offCleared = $false
      $imeOffWaitTotal = 0
      $offCardConfirmed = [bool](Set-DgToggleCard -Game $Game -Region $rgHtCardButton -AltRegion $rgHtCardButtonAlt -ClickPoint $ptHtCardButton -WantSelected $false -Label '은동전(사냥 임무)')
      for ($offTry = 1; $offTry -le 5; $offTry++) {
        Start-Sleep -Milliseconds 2000
        $offCost = Get-DgTributeCost -Game $Game -ValidCosts $dgValidCosts
        if ($script:dgCostImeBlocked) {
          # 팝업 중 판독(null)은 해제 증거가 아님 - 세지 않고 대기 (던전 역방향과 동일 계약)
          if ($imeOffWaitTotal -eq 0) { Write-RunLog '[안내] 입력기 팝업이 소모량 표시를 가리고 있습니다 - 사라질 때까지 대기' }
          if ($imeOffWaitTotal -ge 40) { break }
          $imeOffWaitTotal += 2
          $offTry--
          continue
        }
        if ($null -eq $offCost) {
          if (-not $script:screenCaptureFailing) { $offCleared = $true; break }
          # 캡처 실패 중 - 입력 없이 다음 바퀴에서 재확인
        } elseif (-not ($dgValidCosts -contains $offCost)) {
          break   # 소모량이 유효값이 아니면 불명확 처리(아래 분기)로 넘어감
        }
      }
      if ($offCleared) {
        Write-RunLog '[사냥터] 소모량 표시 사라짐 - 은동전 미사용 확인'
      } elseif ($offCardConfirmed) {
        # 카드 '도전' 확정 판독 = 1차 증거, 소모량 표시는 잔상 가능 (던전 역방향과 동일 계약 -
        # 2026-07-29 00:58 실측 근거는 그쪽 주석 참고)
        Write-RunLog "[경고] 카드는 '도전(미사용)'으로 확인됐지만 소모량 표시가 남아 있습니다 (판독: '$offCost') - 표시 잔상으로 판단하고 미사용으로 진행합니다"
      } elseif ($null -ne $offCost -and ($dgValidCosts -contains $offCost)) {
        throw "은동전 미사용 설정인데 은동전(사냥 임무)을 해제하지 못했습니다 (시작 버튼 소모량: ${offCost}개). 게임에서 카드를 직접 '도전'으로 바꾼 뒤 다시 시작해 주세요."
      } else {
        Write-RunLog "[경고] 카드 해제 확인이 불명확합니다 (소모량 판독: '$offCost') - 현재 상태로 진행합니다"
      }
    }
    }
  }

  # 3. 입장 (매칭 방식별)
  if ($htMatching -eq '파티찾기') {
    Write-RunLog "[사냥터] '파티 찾기' 클릭 - 파티 매칭을 기다립니다"
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ptDgPartyFind[0] -ReferenceY $ptDgPartyFind[1]
    Start-Sleep -Milliseconds 1200
    Resolve-DgEnterConfirmPopup -Game $Game | Out-Null
  } else {
    # 바로 입장: 첫 화면(입장하기 버튼)이 사라지는지 확인하며 재시도합니다.
    # 은동전이 부족해 입장이 막히면 옵션에 따라 공물 임무를 해제하고 이어갑니다.
    Write-RunLog '[사냥터] 입장하기 클릭'
    $entered = $false
    $imePopupWaitTotal = 0
    $lootFallbackDone = $false
    for ($enterTry = 1; $enterTry -le 4; $enterTry++) {
      # 캡처 실패 중에는 입장 여부를 확인할 수 없는 채 클릭/시도 횟수만 소모되므로,
      # 입장 버튼 탐색을 복구 탐침 삼아 캡처가 돌아올 때까지 기다렸다가 진행합니다.
      while ($script:screenCaptureFailing) {
        Test-SafeStopDuringCaptureFail
        Start-Sleep -Seconds 2
        Find-HtEntryButtonPoint -Game $Game | Out-Null
      }
      # IME 팝업 '사전' 확인 - 던전 입장 재시도와 같은 계약 (2026-08-01: 가려진 좌표를 확인
      # 없이 재클릭하지 않기 위한 클릭 전 게이트. 대기 한도·시도 미계상은 사후 확인과 공유)
      if (-not $script:screenCaptureFailing -and (Test-DgImePopupVisible -Game $Game)) {
        if ($imePopupWaitTotal -eq 0) {
          Write-RunLog '[안내] 입력기 팝업이 입장하기 버튼 자리를 가리고 있습니다 - 사라질 때까지 대기'
        }
        if ($imePopupWaitTotal -ge 40) {
          throw '입력기 팝업이 계속 게임 화면을 가려 입장을 확인할 수 없습니다. 게임 창을 한 번 클릭해 팝업을 닫은 뒤 다시 시작해 주세요.'
        }
        Start-Sleep -Seconds 2
        $imePopupWaitTotal += 2
        $enterTry--
        continue
      }
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptDgEnterFinal[0] -ReferenceY $ptDgEnterFinal[1]
      Start-Sleep -Milliseconds 1200
      Resolve-DgEnterConfirmPopup -Game $Game | Out-Null
      $stillEntry = [bool](Find-HtEntryButtonPoint -Game $Game)
      if ($stillEntry) {
        Start-Sleep -Seconds 2
        $stillEntry = [bool](Find-HtEntryButtonPoint -Game $Game)
      }
      # 캡처 실패 중에는 버튼 탐색이 무조건 실패($null)하므로 '입장됨'으로 오판하지 않습니다.
      if (-not $stillEntry -and -not $script:screenCaptureFailing) {
        # IME 팝업이 버튼 자리를 덮으면 '버튼이 안 보임'이 입장의 증거가 못 되고 클릭도
        # 팝업에 먹혔을 수 있음 - 이 시도를 세지 않고 팝업 소멸을 기다립니다 (2026-07-29 실기).
        if (Test-DgImePopupVisible -Game $Game) {
          if ($imePopupWaitTotal -eq 0) {
            Write-RunLog '[안내] 입력기 팝업이 입장하기 버튼 자리를 가리고 있습니다 - 사라질 때까지 대기'
          }
          if ($imePopupWaitTotal -ge 40) {
            throw '입력기 팝업이 계속 게임 화면을 가려 입장을 확인할 수 없습니다. 게임 창을 한 번 클릭해 팝업을 닫은 뒤 다시 시작해 주세요.'
          }
          Start-Sleep -Seconds 2
          $imePopupWaitTotal += 2
          $enterTry--
          continue
        }
        $entered = $true
        break
      }
      # 재시도 실패만으로 더블 루팅을 끄던 '부족 추정' 예비는 제거했습니다 (2026-07-29).
      # 클릭이 팝업 등에 먹힌 것을 부족으로 오판하는 사고 방지 - 잔량이 실제로 읽힌 명시적
      # 부족 증거가 있을 때만 대응하고, 못 읽으면 안전 정지합니다 (리뷰 계약).
      # '소탕만 계속'(continueSweepOnly) 존중 - 던전 재시도 경로와 동일 (2026-08-01 전수 점검:
      # 최초 판독·결과 화면 경로만 이 옵션을 존중하고 여기는 20개 기준으로 정지했음. 잔량이
      # 실제로 10~19개로 읽히면 더블 루팅만 끄고 다음 반복에서 재입장 - 리뷰 조건).
      if ($enterTry -ge 2 -and $htUseCoin -and $effectiveCoin -and $effectiveLoot -and $htLootFallback -and
          -not $lootFallbackDone -and -not $script:screenCaptureFailing) {
        $retryBalance = Get-DgCoinBalance -Game $Game
        if ($null -ne $retryBalance -and $retryBalance -ge 10 -and $retryBalance -lt 20) {
          Write-RunLog "[사냥터] 은동전 잔량 ${retryBalance}개 - 더블 루팅을 끄고 소탕만 계속합니다 (소탕만 계속 설정)"
          # 해제가 확인된 경우에만 내부 상태를 내립니다 (미확인이면 실제 카드가 켜진 채일 수
          # 있어 이후 필요량 판정이 어긋남 - 교차 리뷰 지적). 폴백 처리 바퀴는 시도로 세지
          # 않아 마지막 회전에서 발견돼도 재입장이 보장됩니다.
          if ([bool](Set-DgToggleCard -Game $Game -Region $rgHtLootButton -AltRegion $rgHtLootButtonAlt -ClickPoint $ptHtLootButton -WantSelected $false -Label '더블 루팅')) {
            $effectiveLoot = $false
          }
          $lootFallbackDone = $true
          $enterTry--
        }
      }
    }
    if (-not $entered) {
      # 은동전 부족으로 입장이 막힌 것으로 확인되면 사냥터에서 나가고 마칩니다 (사용자 결정)
      $finalBalance = Get-DgCoinBalance -Game $Game
      $neededNow = $(if ($effectiveLoot) { 20 } else { 10 })
      if ($htUseCoin -and $effectiveCoin -and $null -ne $finalBalance -and $finalBalance -lt $neededNow) {
        Exit-HuntingGroundExhausted -Game $Game -Reason "은동전 소진(잔량 ${finalBalance}개, 필요 ${neededNow}개)"
      }
      throw '입장하기가 진행되지 않습니다. 은동전 잔량 또는 입장 조건을 확인해 주세요.'
    }
  }

  # 4. 입장 완료 대기: 사냥터는 필드형이라 HUD로는 구분되지 않으므로,
  #    퀘스트 추적기에 사냥 임무('소탕'/'정찰')가 나타나는 것으로 판단합니다.
  Write-RunLog '[사냥터] 사냥터 로딩 중...'
  Start-Sleep -Seconds 1
  $entryWaitSeconds = $(if ($htMatching -eq '파티찾기') { $timeoutPartyMatch } else { $timeoutEntry })
  Wait-ForScreen -Game $Game -TimeoutSeconds $entryWaitSeconds -Description '사냥터 입장 완료' -Condition {
    if (Invoke-PurchasePopupSweep -Game $Game) { return $false }
    $questNow = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
        -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
    ($questNow.Contains('소탕') -or $questNow.Contains('정찰'))
  }
  Write-RunLog '[사냥터] 사냥터 입장 완료 감지'

  # 입장 후 키 입력 (자동출발/음식 - 어비스/던전과 동일한 설정 사용)
  Invoke-AfterEntryKeys -Game $Game -LogPrefix '[사냥터]'

  }  # end if (-not $insideAlready)

  # 5. 완료 대기 - 던전과 동일한 감지/안전장치(자동사냥 감시, 자동 부활, 컷신, 팝업)를 사용합니다.
  Write-RunLog '[사냥터] 사냥 완료 화면 감지 대기 시작'
  $clearOutcome = Wait-ForDungeonClearScreen -Game $Game -TimeoutSeconds $timeoutClear -DungeonMode `
    -FindResultButton { Find-HtNewMissionPoint -Game $Game }
  if ($clearOutcome -eq 'clear') {
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ptClearCenter[0] -ReferenceY $ptClearCenter[1]
    Write-RunLog '[사냥터] 사냥 완료 - 화면 터치'
  } else {
    Write-RunLog "[사냥터] 완료 화면을 이미 지나친 상태($clearOutcome) - 결과 화면 처리로 진행"
  }

  }  # end if (-not $onResultScreen)

  # 7. 컷신을 넘기며 결과 화면(나가기/머무르기/새 임무 선택)을 기다립니다 (던전과 유사 구조)
  if (-not $onResultScreen) {
    Write-RunLog '[사냥터] 결과 화면 대기 (컷신은 자동으로 넘김)'
  }
  $null = Wait-ForResultScreen -Game $Game -MissingMessage '사냥터 결과 화면(새 임무 선택 버튼)을 찾지 못했습니다.' `
    -FindRetryButton { Find-HtNewMissionPoint -Game $Game }
  Write-RunLog '[사냥터] 결과 화면 확인 (나가기 / 머무르기 / 새 임무 선택)'

  # 8-1. 다음 임무 몫의 은동전이 없으면 '새 임무 선택'을 게임이 거부합니다
  #      ('다음 임무에 사용할 은동전이 부족해요' 안내 - 2026-07-18 01:05 실측).
  #      그래서 누르기 전에 잔량을 확인해 부족하면 여기서 나가기로 마칩니다.
  if ($htUseCoin) {
    $retryBalance = Get-DgCoinBalance -Game $Game
    if ($null -ne $retryBalance) {
      if ($retryBalance -lt 10) {
        Exit-HuntingGroundExhausted -Game $Game -Reason "은동전 잔량 ${retryBalance}개 (소탕에 10개 필요) - 소진"
      } elseif ($htDoubleLoot -and $retryBalance -lt 20 -and -not $htLootFallback) {
        Exit-HuntingGroundExhausted -Game $Game -Reason "은동전 잔량 ${retryBalance}개 (더블 루팅 포함 20개 필요, '소탕만 계속' 옵션 꺼짐)"
      }
    }
  }

  # 9. 안전 중지가 예약돼 있으면 나가기로 마치고, 아니면 '새 임무 선택'으로 첫 화면 복귀 후 반복합니다.
  Invoke-SafeStopExitIfRequested -Game $Game
  # '새 임무 선택' 클릭 → 첫 화면(입장하기) 복귀 대기.
  # 주의: 첫 화면에서는 같은 자리(797,655 부근)가 '파티 찾기' 버튼입니다. 전환 로딩 중에
  # '입장하기'가 아직 안 읽힌다고 같은 자리를 무조건 재클릭하면 파티 찾기가 눌려 의도치
  # 않은 재입장이 시작됩니다 (2026-07-17 23:51 실측 사고 - 검은 로딩 화면에서 시간 초과).
  # 그래서 결과 화면(새 임무 선택 버튼)이 그대로 보일 때만 다시 클릭하고, 전환 중에는
  # 기다리기만 합니다 (파티장 '입장 취소' 오클릭 방지와 같은 규칙).
  Focus-Game -Game $Game
  Click-GamePoint -Game $Game -ReferenceX $ptHtNewMission[0] -ReferenceY $ptHtNewMission[1]
  Write-RunLog "[사냥터] '새 임무 선택' 클릭 - 첫 화면 복귀 대기"
  $returnDeadline = (Get-Date).AddSeconds(40)
  $returnedToEntry = $false
  while ((Get-Date) -lt $returnDeadline) {
    Start-Sleep -Seconds 2
    if ($script:screenCaptureFailing) {
      Test-SafeStopDuringCaptureFail
      $returnDeadline = (Get-Date).AddSeconds(40)
      continue
    }
    if (Find-HtEntryButtonPoint -Game $Game) {
      $returnedToEntry = $true
      break
    }
    # 가방이 차면 '새 임무 선택' 뒤에 아이템 정리 화면(정리 대상 → Space 정리하기)이
    # 끼어듭니다 (2026-07-18 00:14 실측). 게임 내 정리 규칙대로 정리하고 계속합니다.
    $cleanupText = (Get-GameOcrText -Game $Game) -replace '\s', ''
    # '탐험을 계속하시겠습니까?' 팝업(밖에서 진행할 퀘스트 안내)이 끼어들면 계속하기를
    # 선택합니다 - 이 팝업에서 Space 는 '나가기'라 절대 Space 로 넘기면 안 됩니다.
    if ($cleanupText.Contains('계속하')) {
      $contPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgClearExit[0] -ReferenceY $rgClearExit[1] `
        -RegionWidth $rgClearExit[2] -RegionHeight $rgClearExit[3] -SearchText '계속하'
      Focus-Game -Game $Game
      if ($contPoint) {
        Click-ScreenPoint -X $contPoint.X -Y $contPoint.Y
      } else {
        Press-KeyOnce -VirtualKey ([byte]27)   # ESC = 계속하기 (버튼 지점을 못 찾은 경우 예비)
      }
      Write-RunLog "[사냥터] '탐험을 계속하시겠습니까?' 팝업 - 계속하기 선택"
      Start-Sleep -Seconds 1
      continue
    }
    if ($cleanupText.Contains('정리')) {
      Focus-Game -Game $Game
      Press-KeyOnce -VirtualKey ([byte]32)   # Space = 정리하기
      Write-RunLog '[사냥터] 아이템 정리 화면 감지 - Space로 정리하기'
      Start-Sleep -Seconds 2
      continue
    }
    # 아침 6시 리셋 블로커 처리 (2026-08-03 - 던전 '다시 하기' 복귀 대기와 같은 계약)
    if (Invoke-PurchasePopupSweep -Game $Game) { continue }
    if (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix '[사냥터] ') { continue }
    if (-not $script:screenCaptureFailing -and (Test-NoticeBoardPopup -Game $Game)) {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptNoticeClose[0] -ReferenceY $ptNoticeClose[1]
      Write-RunLog '[사냥터] 공지 게시판 팝업 감지 - X로 닫기 (복귀 대기 중)'
      Start-Sleep -Seconds 2
      continue
    }
    if (Find-HtNewMissionPoint -Game $Game) {
      Write-RunLog "[사냥터] 결과 화면이 남아 있어 '새 임무 선택'을 다시 클릭합니다"
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptHtNewMission[0] -ReferenceY $ptHtNewMission[1]
    }
  }
  if (-not $returnedToEntry) {
    throw '새 임무 선택 후 사냥터 첫 화면(입장하기)이 확인되지 않습니다.'
  }
  Write-RunLog '[사냥터] 첫 화면 복귀 확인 - 회차 완료'
  exit 0
}

# ============================================================
#  어비스 '파티(파티원)' 전용 사이클 (2026-07-17 실측 기반)
#  파티원은 ESC/어비스 메뉴 이동 없이 필드에서 대기합니다. 파티장이 입장하기를
#  누르면 파티 패널에 '준비 완료' 버튼이 활성화되고, 누른 뒤 전원이 준비되면
#  자동 입장됩니다. 클리어 후에는 각자 나가기를 눌러 필드로 돌아오고(사용자
#  확인), 다음 회차는 다시 '준비 완료' 대기부터 반복합니다.
#  '준비 완료' 버튼은 파티장의 입장하기/입장 취소와 같은 자리(하단 우측)라
#  글자 영역(rgPartyEnterBtn)과 클릭 지점(ptPartyEnter)을 그대로 재사용합니다.
# ============================================================
function Invoke-AbyssPartyMemberCycle {
  param([System.Diagnostics.Process]$Game)

  # --- 시작 상태 재개: 이미 던전 안/클리어/보상 화면이면 그 지점부터 이어갑니다 ---
  $skipToFinish = $false
  $inDungeon = $false
  if (Test-ExitButton -Game $Game) {
    Write-RunLog '[파티원] 시작: 보상 화면(나가기) 감지 - 마무리부터 진행'
    $skipToFinish = $true
  } elseif (Test-DungeonClearPrompt -Game $Game) {
    Write-RunLog '[파티원] 시작: 클리어 화면 감지 - 마무리부터 진행'
    Invoke-ClickUntil -Game $Game -Point $ptClearCenter -Description '클리어 화면 터치(나가기 버튼 표시)' `
      -TimeoutSeconds ($timeoutExit + 15) -ReclickEverySeconds 3 -Condition { Test-ExitButton -Game $Game } `
      -SourceCondition { Test-DungeonClearPrompt -Game $Game }
    $skipToFinish = $true
  } elseif (Test-InDungeonQuest -Game $Game) {
    Write-RunLog '[파티원] 시작: 던전 입장 상태 감지 - 클리어 대기부터 진행'
    $inDungeon = $true
  }

  if (-not $skipToFinish) {
    if (-not $inDungeon) {
      # --- 1. 파티장의 입장 시작 대기 → '준비 완료' 클릭 → 자동 입장 대기 (단일 루프) ---
      # 파티장의 회차 사이 복귀/재진입이 몇 분 걸릴 수 있어 매칭 대기보다 길게 기다립니다.
      $memberWaitSeconds = [Math]::Max($timeoutPartyMatch, 1800)
      Write-RunLog "[파티원] 파티장의 입장 시작 대기 중... ('준비 완료' 버튼이 뜨면 클릭, 최대 ${memberWaitSeconds}초)"
      $memberDeadline = (Get-Date).AddSeconds($memberWaitSeconds)
      $readyClicked = $false
      while ($true) {
        if ((Get-Date) -ge $memberDeadline) {
          throw "파티장의 입장 시작을 기다리다 시간을 초과했습니다 (${memberWaitSeconds}초) - 파티 상태와 파티장 쪽 자동화를 확인해 주세요."
        }
        [void](Invoke-PurchasePopupSweep -Game $Game)
        if (Test-InDungeonQuest -Game $Game) { break }
        # '준비 완료'를 누르기 전(순수 대기 중)에만 안전 중지 예약을 소비합니다 (필드 = 안전 지점)
        if (-not $readyClicked -and (Test-Path -LiteralPath $safeStopFlagPath)) {
          Remove-Item -LiteralPath $safeStopFlagPath -Force -ErrorAction SilentlyContinue
          Write-RunLog '[완료] 안전 중지 예약 확인 - 파티원 대기 상태에서 자동화를 마칩니다 (회차 미완료)'
          exit 4
        }
        $memberBtnText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgPartyEnterBtn[0] -ReferenceY $rgPartyEnterBtn[1] `
          -RegionWidth $rgPartyEnterBtn[2] -RegionHeight $rgPartyEnterBtn[3] -Scale 4 -Engine $ocrKoreanEngine) -replace '\s', ''
        # '준비' 조각까지 요구합니다 (2026-08-01 전수 점검: '완료' 포함만으로는 같은 영역에
        # 잡히는 다른 완료성 문구('협동 미션 완료' 등)에도 오클릭 - 버튼 문구는 '준비 완료')
        if ($memberBtnText -match '준비' -and $memberBtnText -match '완료' -and $memberBtnText -notmatch '취소') {
          # '준비 완료' 활성 - 클릭. 누르면 '준비 취소'로 바뀐다고 보고 '취소'가 보이면 더
          # 누르지 않습니다 (파티장의 '입장 취소'와 같은 오클릭 방지 규칙). 파티장이 입장을
          # 취소했다가 다시 시작하면 버튼이 되살아나므로 그때는 이 분기가 다시 클릭합니다.
          Focus-Game -Game $Game
          Click-GamePoint -Game $Game -ReferenceX $ptPartyEnter[0] -ReferenceY $ptPartyEnter[1]
          Write-RunLog "[파티원] '준비 완료' 클릭 - 전원 준비되면 자동 입장"
          $readyClicked = $true
        }
        Start-Sleep -Seconds 3
      }
      Write-RunLog '[파티원] 던전 입장 완료 감지'
    }

    # --- 2. 입장 직후 키 입력 (자동출발 등 - 어비스 본류와 동일) ---
    Invoke-AfterEntryKeys -Game $Game -LogPrefix '[파티원]'

    # --- 3. 클리어 대기 → 터치 → 나가기 (어비스 본류와 동일한 헬퍼 재사용) ---
    Write-RunLog '[파티원] 클리어 화면 감지 대기 시작'
    $clearOutcome = Wait-ForDungeonClearScreen -Game $Game -TimeoutSeconds $timeoutClear
    if ($clearOutcome -eq 'clear') {
      Write-RunLog '[파티원] 클리어 화면 터치'
      Invoke-ClickUntil -Game $Game -Point $ptClearCenter -Description '클리어 화면 터치(나가기 버튼 표시)' `
        -TimeoutSeconds ($timeoutExit + 15) -ReclickEverySeconds 3 -Condition { Test-ExitButton -Game $Game } `
        -SourceCondition { Test-DungeonClearPrompt -Game $Game }
      Write-RunLog '[파티원] 나가기 버튼 감지'
    }
    if ($clearOutcome -eq 'selection') {
      # 사용자가 직접 화면을 넘겨 선택 화면까지 간 예외 상황 - 나가기 단계가 없습니다
      Write-RunLog '[완료] 파티원 회차 완료 (선택 화면 상태)'
      exit 0
    }
  }

  # --- 4. 나가기 → 필드 복귀 확인. 파티원은 어비스 선택 화면으로 복귀하지 않습니다 ---
  Focus-Game -Game $Game
  Click-GamePoint -Game $Game -ReferenceX $ptExitButton[0] -ReferenceY $ptExitButton[1]
  Write-RunLog '[파티원] 나가기 클릭'
  Wait-ForScreen -Game $Game -TimeoutSeconds $timeoutHud -Description '던전 밖(필드) 복귀' -Condition {
    Test-HomeEndEscHud -Game $Game
  }
  Write-RunLog '[완료] 파티원 회차 완료 - 필드에서 다음 입장을 기다립니다'
  exit 0
}

function Return-ToAbyssSelection {
  param(
    [System.Diagnostics.Process]$Game,
    # 복귀 도중 안전 중지 예약을 소비할 때 쓸 종료 코드 (2026-08-01 전수 점검: 준비 실행
    # (코드 10이어야 함)이 이 함수의 안전 중지 분기에서 무조건 exit 0 으로 끝나 던전을 돌지
    # 않은 실행이 완료 회차로 계상됐음 - 호출부가 자기 문맥의 코드를 전달. 리뷰 승인)
    [int]$SafeStopExitCode = 0
  )

  # 던전 밖에서 어비스 선택 화면으로 돌아가는 과정을 '상태 기반'으로 반복합니다.
  # 매 반복마다 현재 화면을 다시 판단해 필요한 조작만 하므로, ESC 클릭이 빗나가거나
  # 사용자가 화면을 조작해 뒤로 가더라도 스스로 다시 시도해 복구합니다.
  $deadline = (Get-Date).AddSeconds($timeoutHud + $timeoutAbyssMenu + $timeoutAbyssSelect)
  $loggedHud = $false
  $loggedMenu = $false
  $lastFocus = Get-Date
  $unknownSince = $null   # '알 수 없는 화면' 상태가 시작된 시각 (오클릭으로 열린 우편함 등 복구용)
  $xAttempts = 0          # 닫기(X) 후보 순환 인덱스
  $stellaHandled = 0      # 복귀 중 스텔라 픽 처리 횟수 (무한 클릭 방지 상한용)
  $abyssMenuMissCount = 0 # 메뉴에서 '어비스' 글자를 못 찾은 횟수 (진단 캡처 1회용)

  while ((Get-Date) -lt $deadline) {
    # 0) 화면 캡처가 안 되는 동안은 판단이 불가능하므로 제한 시간을 멈추고 기다립니다.
    if ($script:screenCaptureFailing) {
      Test-SafeStopDuringCaptureFail
      $deadline = (Get-Date).AddSeconds($timeoutHud + $timeoutAbyssMenu + $timeoutAbyssSelect)
      Start-Sleep -Milliseconds 700
      # 아래 상태 검사(OCR)는 계속 시도해 복구 여부를 확인합니다.
    }

    # 1) 이미 어비스 선택 화면이면 완료
    if (Test-AbyssSelectionScreen -Game $Game) {
      # 선택 화면 도달 직전의 안전 중지 예약도 여기서 소비합니다 (2026-08-01 3차 점검:
      # 이 return 이 아래 HUD 분기의 안전 중지 확인보다 먼저라, 도달 직전 예약이 소비되지
      # 않은 채 다음 실행으로 새어 헛 조기 종료를 만들 수 있었음 - 리뷰 승인)
      if (Test-Path -LiteralPath $safeStopFlagPath) {
        Remove-Item -LiteralPath $safeStopFlagPath -Force -ErrorAction SilentlyContinue
        if ($SafeStopExitCode -eq 10) {
          Write-RunLog '[완료] 안전 중지 예약 확인 - 선택 화면 복귀 완료, 준비/정리 실행이라 회차로 세지 않고 마칩니다'
        } else {
          Write-RunLog '[완료] 안전 중지 예약 확인 - 선택 화면 복귀 완료 시점에서 회차를 마칩니다'
        }
        exit $SafeStopExitCode
      }
      Write-RunLog '[어비스] 선택 화면 복귀 확인'
      return
    }

    # 2) ESC 메뉴가 열려 있으면(어비스 항목 보임) 어비스 클릭
    if (Test-AbyssMenu -Game $Game) {
      $unknownSince = $null
      if (-not $loggedMenu) { Write-RunLog '[어비스] 어비스 메뉴 감지'; $loggedMenu = $true }
      # **글자를 찾아 누릅니다** - 고정 좌표는 메뉴 구성이 바뀌면 조용히 다른 항목을 누릅니다.
      # 2026-08-08 실사고: 상단에 'NEXON ESSENTIAL' 광고 배너(y33~175)가 생기면서 타일
      # 그리드가 통째로 아래로 밀려, 옛 좌표 (971,387) 이 '아르바이트' 아이콘이 됐습니다
      # (실측: 어비스는 (971,531) 로 이동). 배너 높이는 광고마다 다를 수 있어 새 고정 좌표로
      # 바꾸면 다음 배너에서 또 깨집니다 - 생활 분기의 '가까운 위치 찾기'와 같은 계약입니다.
      # 못 찾으면 클릭하지 않습니다 (엉뚱한 항목을 여는 것보다 재시도가 낫습니다).
      $abyssMenuPoint = Find-GameTextPoint -Game $Game -ReferenceX $rgAbyssMenu[0] -ReferenceY $rgAbyssMenu[1] `
        -RegionWidth $rgAbyssMenu[2] -RegionHeight $rgAbyssMenu[3] -SearchText '어비스' -ExactText '어비스' -Scale 4
      if (-not $abyssMenuPoint) {
        $abyssMenuMissCount++
        Write-RunLog "[어비스] 메뉴에서 '어비스' 글자를 찾지 못했습니다 - 재시도 ($abyssMenuMissCount)"
        if ($abyssMenuMissCount -eq 3) { Write-LifeDiagnostics -Game $Game -Context '어비스 메뉴 항목 미발견' }
        Start-Sleep -Seconds 2
        continue
      }
      Focus-Game -Game $Game
      Click-ScreenPoint -X $abyssMenuPoint.X -Y $abyssMenuPoint.Y
      Write-RunLog "[어비스] 어비스 메뉴 클릭 (글자 탐색 화면좌표 $([int]$abyssMenuPoint.X),$([int]$abyssMenuPoint.Y))"
      Start-Sleep -Seconds 2
      # **클릭 검증** (2026-08-08 사용자 요청): 눌렀는데 다른 화면이 열렸으면 메뉴로 되돌립니다.
      # 검증 없이 넘기면 엉뚱한 창(아르바이트 등)이 열린 채 '알 수 없는 화면'으로만 돌다가
      # 시간 초과로 끝납니다 - 무엇이 잘못됐는지도 로그에 안 남습니다.
      foreach ($abyssOpenTry in 1..6) {
        Start-Sleep -Seconds 1
        if ($script:screenCaptureFailing) { continue }
        if (Test-AbyssSelectionScreen -Game $Game) { break }
        if (Test-AbyssMenu -Game $Game) { break }      # 아직 메뉴 - 다음 회전에서 다시 클릭
      }
      if (-not $script:screenCaptureFailing -and -not (Test-AbyssSelectionScreen -Game $Game) -and
        -not (Test-AbyssMenu -Game $Game) -and -not (Test-HomeEndEscHud -Game $Game)) {
        Write-RunLog '[어비스] 어비스가 아닌 화면이 열렸습니다 - ESC 로 되돌립니다'
        Write-LifeDiagnostics -Game $Game -Context '어비스 메뉴 오클릭'
        Focus-Game -Game $Game
        Press-KeyOnce -VirtualKey 0x1B
        Start-Sleep -Seconds 2
      }
      continue
    }

    # 3) 던전 밖 Home/End/ESC HUD가 보이면 ESC를 눌러 메뉴 열기
    if (Test-HomeEndEscHud -Game $Game) {
      $unknownSince = $null
      if (-not $loggedHud) { Write-RunLog '[어비스] 던전 밖(HUD) 확인'; $loggedHud = $true }
      # 안전 중지가 예약된 경우: 어차피 멈출 것이므로 어비스 선택 화면까지 복귀하지 않고
      # 던전 밖이 확인된 이 시점에서 회차를 마칩니다.
      if (Test-Path -LiteralPath $safeStopFlagPath) {
        # 신호 파일은 워커가 소비(삭제)합니다 (남은 파일로 인한 헛 조기 종료 방지)
        Remove-Item -LiteralPath $safeStopFlagPath -Force -ErrorAction SilentlyContinue
        if ($SafeStopExitCode -eq 10) {
          Write-RunLog '[완료] 안전 중지 예약 확인 - 준비/정리 실행 중이라 회차로 세지 않고 마칩니다'
        } else {
          Write-RunLog '[완료] 안전 중지 예약 확인 - 던전 밖(HUD) 확인 시점에서 회차를 마칩니다'
        }
        exit $SafeStopExitCode
      }
      # 공지 게시판 팝업이 화면을 덮고 있으면(HUD는 가장자리로 계속 보임) ESC 클릭이
      # 팝업에 막혀 헛돌기만 합니다 - 먼저 팝업 우상단 X를 눌러 닫습니다
      # (2026-07-19 06:42 타 PC 실측: 6시 리셋 후 이 팝업으로 ESC 18회 헛클릭 → 시간 초과)
      if (Test-NoticeBoardPopup -Game $Game) {
        Focus-Game -Game $Game
        Click-GamePoint -Game $Game -ReferenceX $ptNoticeClose[0] -ReferenceY $ptNoticeClose[1]
        Write-RunLog '[어비스] 공지 게시판 팝업 감지 - X로 닫기'
        Start-Sleep -Seconds 2
        continue
      }
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptEscButton[0] -ReferenceY $ptEscButton[1]
      Write-RunLog '[어비스] ESC 클릭'
      Start-Sleep -Seconds 2
      continue
    }

    # 4) 보상 화면(나가기 버튼)이 아직 남아 있으면 나가기 클릭 (앞선 클릭이 빗나간 경우 복구)
    if (Test-ExitButton -Game $Game) {
      $unknownSince = $null
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptExitButton[0] -ReferenceY $ptExitButton[1]
      Write-RunLog '[어비스] 나가기 클릭 (복구 재시도)'
      Start-Sleep -Seconds 2
      continue
    }

    # 5) 어느 상태도 아니면 출석/이벤트 화면이 덮였을 수 있으므로 '건너뛰기'/'확인' 버튼을
    #    찾아 클릭합니다 (6시 리셋 이벤트가 복귀 도중 뜨는 경우 대응. 없으면 그냥 대기).
    if (-not $script:screenCaptureFailing) {
      if (Invoke-EventSkipOrConfirm -Game $Game -LogPrefix '복귀 중 ') {
        $unknownSince = $null
        continue
      }

      # 5-1) 오늘의 스텔라 픽(스텔라그램) 팝업이 복귀 중에 뜨면 바로 처리합니다.
      #      기존에는 '알 수 없는 화면 20초 → X 닫기'로 느리게 넘겼고 X로 닫으면 오늘 픽을
      #      고르지 못할 수 있었습니다 (실측 2026-07-18 06:00). Clear-EventOverlay 와 같은
      #      방식: 1단계(카드 선택) → 2단계(확정 버튼). 상한(5회)을 넘으면 X 폴백에 맡깁니다.
      if ($stellaHandled -lt 5) {
        $stellaTitleNow = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgStellaTitle[0] -ReferenceY $rgStellaTitle[1] `
          -RegionWidth $rgStellaTitle[2] -RegionHeight $rgStellaTitle[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
        if ($stellaTitleNow.Contains('스텔라')) {
          $stellaHandled++
          Focus-Game -Game $Game
          Click-GamePoint -Game $Game -ReferenceX $ptStellaCard[0] -ReferenceY $ptStellaCard[1]
          Write-RunLog '[안내] 복귀 중 스텔라 픽 감지 - 가운데 카드 선택'
          Start-Sleep -Seconds 2
          $unknownSince = $null
          continue
        }
        $stellaBtnNow = Find-GameTextPoint -Game $Game -ReferenceX $rgStellaPickBtn[0] -ReferenceY $rgStellaPickBtn[1] `
          -RegionWidth $rgStellaPickBtn[2] -RegionHeight $rgStellaPickBtn[3] -SearchText '스텔라'
        if ($stellaBtnNow) {
          $stellaHandled++
          Focus-Game -Game $Game
          Click-ScreenPoint -X $stellaBtnNow.X -Y $stellaBtnNow.Y
          Write-RunLog '[안내] 복귀 중 스텔라 픽 2단계 - 확정 버튼 클릭'
          Start-Sleep -Seconds 2
          $unknownSince = $null
          continue
        }
      }

      # 5.5) 알 수 없는 화면이 계속되면(오클릭으로 열린 우편함/전체 화면 UI 등 - 실측 2026-07-17)
      #      알려진 닫기(X) 위치를 순환 클릭해 원래 화면으로 복구를 시도합니다.
      #      단, 나가기 직후 화면 전환(페이드/로딩)도 몇 초간 '알 수 없음'으로 보이므로
      #      반드시 20초 이상 지속될 때만 발동합니다
      #      (실측 2026-07-17 05:18: 횟수 기준으로 조기 발동해 필드의 미니맵(1229,67)을 오클릭).
      if ($null -eq $unknownSince) { $unknownSince = Get-Date }
      if (((Get-Date) - $unknownSince).TotalSeconds -ge 20) {
        $xCandidates = @(@(1229, 67), @(1090, 137), @(959, 180))
        $xPick = $xCandidates[$xAttempts % $xCandidates.Count]
        $xAttempts++
        Focus-Game -Game $Game
        Click-GamePoint -Game $Game -ReferenceX $xPick[0] -ReferenceY $xPick[1]
        Write-RunLog "[안내] 복귀 중 알 수 없는 화면 20초 지속 - 닫기(X) 후보($($xPick[0]),$($xPick[1])) 클릭"
        Start-Sleep -Seconds 2
        continue
      }
    }

    # 6) 로딩/전환 중이거나 게임 창이 가려진 경우 - 잠시 기다렸다 재확인.
    #    감지가 계속 안 되면 게임 창을 주기적으로 앞으로 가져옵니다.
    if ($refocusEverySeconds -gt 0 -and
        ((Get-Date) - $lastFocus).TotalSeconds -ge $refocusEverySeconds) {
      if (Invoke-AutoRefocus -Game $Game) { $lastFocus = Get-Date }
    }
    Start-Sleep -Milliseconds 700
  }

  throw '어비스 선택 화면 복귀 대기 시간이 초과됐습니다.'
}

function Get-KeyDisplayName {
  param([int]$VirtualKey)

  # 로그 표시용 키 이름. 자주 쓰는 키만 이름으로, 나머지는 코드로 표시합니다.
  if ($VirtualKey -eq 32) { return 'Space' }
  if (($VirtualKey -ge 65 -and $VirtualKey -le 90) -or ($VirtualKey -ge 48 -and $VirtualKey -le 57)) {
    return [string][char]$VirtualKey
  }
  return ('VK 0x{0:X2}' -f $VirtualKey)
}

function Press-KeyOnce {
  param([byte]$VirtualKey)

  [HoneyNogiInput]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 120
  [HoneyNogiInput]::keybd_event($VirtualKey, 0, 2, [UIntPtr]::Zero)
}

# ============================================================
#  '생활(채집)' 대분류 (v2.0.0 - 2026-08-05 사용자 시연 251프레임 실측 + 설계 합의.
#  흐름: C(내 정보) → 생활 스킬 → 스킬 셀 → 대상 행 → '가까운 위치 찾기' → 게임이 자동
#  이동(전투 포함)·자동 반복 채집 → 퀘스트 소멸 = 1사이클. 판정은 퀘스트 존재 기반 -
#  카운트 파싱은 로그용 보조 (사용자 합의 단순화). 실측 근거: 던전이미지\생활\흐름캡처\ 9장)
# ============================================================

# 스킬 셀 좌표 (생활 스킬 창 8열 그리드 y205 - 실측: x 236/366/496/625/755/884/1014/1143).
# 셀 라벨 OCR 은 실측상 판독 불가(흐린 글꼴) → 고정 좌표 클릭 후 '우측 대상 목록 내용'으로
# 사후 검증합니다 (Sig = 해당 스킬 대상들의 고유 조각 - 다른 스킬 대상과 겹치면 안 되며
# tests\test_life_gather.ps1 이 전 조합을 대조합니다. 2026-08-07 '버섯' 충돌 실사고).
# 미지원: 낚시(채집 흐름 미검증) - 안내 정지
# Order = 게임 대상 목록의 실제 표시 순서 (GUI $script:lifeSkills 와 동일). 판독이 안 되는
# 짧은 이름의 행 위치를 '판독된 앵커 + 균일 격자'로 추론하는 데 씁니다 - 2026-08-06 실측:
# WinRT OCR 이 1글자 한글('물')을 s3~s6 전 스케일에서 놓쳐 순서 기반 보완이 유일한 해법.
$lifeSkillMenuTable = @{
  daily  = @{ Name = '일상 채집'; Cell = @(236, 205); Sig = @('둥지', '젖소', '사과', '차나무', '헤이즐넛')
              Order = @('둥지', '거미줄', '물', '우물', '젖소', '사과 나무', '차나무', '거미줄 뭉치', '헤이즐넛', '얽힌 거미줄') }
  wood   = @{ Name = '나무 베기'; Cell = @(366, 205); Sig = @('뾰족', '굵은', '갑옷', '어스름')
              Order = @('나무', '뾰족 나무', '굵은 나무', '쓸 만한 나무', '갑옷 나무', '어스름 나무', '벼락 나무', '흰 껍질 나무') }
  mining = @{ Name = '광석 캐기'; Cell = @(496, 205); Sig = @('광맥', '석탄', '얼음')
              Order = @('광맥', '철 광맥', '얼음', '석탄 광맥', '동 광맥', '백동 광맥', '은 광맥', '운철 광맥', '백금 광맥') }
  # 약초 Sig 에서 '버섯'을 뺐습니다 - 호미질에 '개암 버섯'이 생겨 더는 고유 조각이 아닙니다
  # (약초를 누르려다 호미질이 열려도 '버섯'만 보고 맞다고 확정할 위험 - 리뷰 지적 2026-08-07)
  herb   = @{ Name = '약초 채집'; Cell = @(625, 205); Sig = @('허브', '블러디', '화살꽃')
              Order = @('허브', '블러디 허브', '화살꽃', '마나 허브', '새록 버섯', '튼튼 버섯', '끈기 풀', '쑥쑥 버섯', '숨숨꽃', '깔끔 버섯', '생채기꽃', '증폭 버섯', '진정초', '끈적 풀', '솔솔 버섯', '산뜻 버섯') }
  # 2026-08-07 실측 추가: 스킬 창은 열 때마다 8열 전체 그리드라 5~6번째 셀도 바로 클릭됩니다
  # (양털 755 / 추수 884, y205 - 앞 4종과 같은 행). 스킬 선택 뒤에는 4열로 좁아지지만
  # 워커는 창을 열자마자 셀을 누르므로 8열 좌표가 항상 맞습니다.
  wool   = @{ Name = '양털 깎기'; Cell = @(755, 205); Sig = @('먹구름', '구름털', '복슬', '곱슬')
              Order = @('양', '곱슬 양', '먹구름 양', '구름털 양', '복슬 양') }
  # 추수는 대상이 밀/콩/쌀 등 1글자라 목록·상세 어디서도 이름이 안 읽힙니다 - 스킬 설명
  # ('낫으로 잘 여문 곡식')으로 스킬을 확인하고, 행은 목록 순서(최상단 기준)로 찾습니다
  harvest = @{ Name = '추수'; Cell = @(884, 205); Sig = @('옥수수', '귀리', '곡식', '낫으로')
              Order = @('밀', '옥수수', '콩', '쌀', '귀리') }
  hoe    = @{ Name = '호미질'; Cell = @(1014, 205); Sig = @('감자', '양파', '조개', '파스', '양배추')
              Order = @('감자', '양파', '조개', '파스닙', '양배추', '호박', '개암 버섯') }
  insect = @{ Name = '곤충 채집'; Cell = @(1143, 205); Sig = @('빛무리', '곤충무리', '설원', '고요한')
              Order = @('빛 무리', '설원 빛 무리', '곤충 무리', '고요한 빛 무리', '따스한 빛 무리', '차가운 빛 무리', '삭막한 곤충 무리', '황폐한 곤충 무리', '일렁이는 빛 무리') }
}
# 대상 목록 첫 행의 기준 Y (실측: 일상 '둥지'·추수 '밀'·양털 '양' 모두 394. 스킬 셀을 누른
# 직후 목록은 항상 최상단이라, 이름이 전혀 안 읽히는 짧은 대상은 이 값 + 순서 x 간격으로
# 위치를 계산합니다 - 2026-08-07 실측)
$lifeListFirstRowY = 394
$lifeListRowGap = 90                      # 대상 목록 행 간격(실측) - 격자 추론용
# 대상 이름 이형 (실측 깨짐 - 행 조합 후 공백 제거 비교. 새 깨짐은 실기 로그로 수집해 추가)
# '나무'→'나부' 는 2회 실측 공통 깨짐 (트래커 '사과나부', 목록 '나부만한쓸' - 08-05).
# '흰'→'혼!' 은 상세 제목 s3 실측 (23:51 실기 - 자기 팝업을 다른 대상으로 오판하던 사고)
$lifeTargetVariants = @{
  '얽힌거미줄' = @('읽힌거미줄', '읽힌거미좋', '읽힌거미줗')
  '사과나무'   = @('ÅI과나무', '사과나부')
  '흰껍질나무' = @('흰껍질나부', '혼!껍질나무', '혼!껍질나부')
  '쓸만한나무' = @('쓸만한나부')
  '둥지'       = @('등지', '둥人I')
  '거미줄'     = @('거미좋', '거미줗')
  '거미줄뭉치' = @('거미줄풍치', '거미좋뭉치', '거미줄뭉지')
  '화살꽃'     = @('호b살꽃', '화살것')
  '벼락나무'   = @('벍락나무', '벼락나부', '벍락나부')
  '운철광맥'   = @('문철광맥', '운철괌맥', '문철괌맥')
  '은광맥'     = @('으광맥', '은괌맥', '으괌맥')
  '석탄광맥'   = @('석탄괌맥', '섹탄광맥')
  '백동광맥'   = @('백동괌맥', '밸동광맥')
  '파스닙'     = @('파스님', '파스납')
  '빛무리'     = @('국빛무리', '르국빛무리', '빛부리')
  '곤충무리'   = @('들곤충무리', '수곤충무리', '곤충부리')
  # 2026-08-08 hyodong 제보(1908 창): '빛'이 통째로 소실돼 읽힘. 치환 규칙으로는 못 잡습니다
  # (없어진 글자는 바꿀 대상이 없음) - 이형으로 직접 등록해야 합니다
  '고요한빛무리' = @('고요한무리')
}
# ── 상세 팝업 '제목 전용' 이형 (2026-08-08 8종 전 대상 팝업 전수 실측) ──
# 위 공용 표와 **분리**합니다. 공용 표는 목록 행 선택과 퀘스트 소유 판정에도 쓰이는데,
# 퀘스트 쪽은 정확 일치가 아니라 Contains 비교라 깨짐 문자열이 섞이면 엉뚱한 행을 클릭하거나
# 남의 퀘스트를 자기 것으로 볼 수 있습니다 (리뷰 지적). 이 표는 **클릭 직전 제목 재확인**
# 에서만 쓰이고, 그 판정은 틀려도 '차단하지 않음'으로만 흐르므로 위험이 한 방향입니다.
# 아래 이름들은 상세·링크 영역, s3·s4 어느 조합으로도 정상 판독이 안 됩니다 (전수 재측정으로
# 확인 - 배율/영역 문제가 아니라 OCR 이 못 읽는 글자꼴).
$lifeTitleVariants = @{
  # '헤이즐넛' = @('헤OI즐넛') 은 제거했습니다 (2026-08-08): 공용 치환에 'OI'->'이' 가
  # 생기면서 '헤OI즐넛' 이 정식 이름으로 복원돼 이형 등록이 중복이 됩니다
  # (그대로 두면 이형 표 중복 가드가 실패합니다)
  '화살꽃'     = @('호발꽃')
  '벼락나무'   = @('H*락나무')
  '광맥'       = @('고十OH')
  '은광맥'     = @('으과DH')
  '석탄광맥'   = @('A-IEY광DH')
  '동광맥'     = @('도과DH')
  '백동광맥'   = @('BHE고十DH')
  '백금광맥'   = @('BHZ고十DH')
  '양'         = @('0홀')
  '곱슬양'     = @('고스0')
  '먹구름양'   = @('04기르0')
  '끈기풀'     = @('=츹')
}

function Test-LifeTitleNameMatches {
  # 제목 비교 전용 - 공용 이름 매칭 + 제목 전용 이형 표 (순수 - 진리표 대상).
  param([string]$Title, [string]$TargetName)
  if (Test-LifeNameMatches -RowText $Title -TargetName $TargetName) { return $true }
  $targetNorm = Get-LifeNormalizedName $TargetName
  if ($lifeTitleVariants.ContainsKey($targetNorm)) {
    if (@($lifeTitleVariants[$targetNorm]) -contains (Get-LifeNormalizedName $Title)) { return $true }
  }
  return $false
}
# 채집 퀘스트 판독용 넓은 영역 (기본 rgQuestTracker 는 첫 줄만 보는 좁은 영역이라, 획득
# 알림/경험치 배지가 덮거나 퀘스트가 아래로 밀리면 '없음'으로 오판 - 2026-08-07 실사고:
# 채집 중인데 40초 만에 '끝났다'고 보고 다른 대상으로 넘어감). 우측 퀘스트 목록 전체를
# 보고 '채집'+'장소' 조합을 찾습니다 (주간 목표 등 다른 줄에는 이 조합이 없어 오탐 없음)
$rgLifeQuestWide = @(955, 195, 315, 240)
$rgLifeStats = @(150, 330, 300, 180)     # 내 정보 능력치 라벨 영역 ('생활력' = 화면 확정 신호)
$rgLifeTargetList = @(700, 140, 520, 540) # 생활 스킬 창 우측 대상 목록 (행 간격 ~90px, 레벨 열 x>1100)
$rgLifeDetail = @(430, 150, 420, 300)     # 대상 상세 팝업 (제목 y~191, '채집물' y~218)
# 상세 팝업 라벨('채집물')의 안정 조각. 제목부 절단·요구 레벨 탐색·팝업 인식이 전부 이 앵커
# 하나에 걸려 있어, 여기서 못 찾으면 팝업이 멀쩡히 떠 있어도 '확인 실패'로 3회 소진합니다
# (2026-08-09 제보: '채집물' -> '채집묻' 으로 받침이 깨져 전체가 무너짐).
# **조각을 늘릴 때는 반드시 실측 근거가 있어야 합니다** - 느슨하면 설명 본문에서 잘못 끊깁니다.
$lifeDetailLabelFragments = @('집물', '집묻')

# 라벨이 나올 수 있는 최대 위치(문자 수). 팝업 구조가 '이름 → 채집물' 이라 라벨은 제목
# 바로 뒤입니다. 정규화된 대상 이름은 가장 긴 것이 7자, 관측된 제목 깨짐이 8자라 16이면
# 충분히 넉넉합니다. **상한이 없으면** 진짜 라벨을 놓쳤을 때 설명 본문에 우연히 있는 같은
# 조각을 라벨로 인정해 **제목이 통째로 엉뚱하게 잘립니다**(2026-08-09 교차 리뷰 반례:
# '운철광맥채집들…설명집묻뒤' → 제목을 '…설명' 까지로 잡음). 오클릭 확정으로 이어질 수 있어
# 위치 상한이 안전장치입니다.
$lifeDetailLabelMaxIndex = 16

function Get-LifeDetailLabelIndex {
  # 판독 문자열에서 라벨 위치를 찾습니다 (순수 - 진리표 대상). 못 찾으면 -1.
  # 여러 조각 중 **가장 앞에 나오는** 것을 쓰되, 위치 상한을 넘으면 라벨로 보지 않습니다.
  # 조각은 전부 2글자라 호출부의 '+2' 계산이 그대로 유효합니다.
  param([string]$Text, [int]$MaxIndex = $lifeDetailLabelMaxIndex)
  $best = -1
  foreach ($fragment in $lifeDetailLabelFragments) {
    $found = ([string]$Text).IndexOf($fragment)
    if ($found -ge 0 -and ($best -lt 0 -or $found -lt $best)) { $best = $found }
  }
  if ($best -gt $MaxIndex) { return -1 }
  return $best
}

function Test-LifeDetailHasLabel {
  # 라벨이 있는가 (= 상세 팝업 판독인가). 순수 - 진리표 대상
  param([string]$Text)
  return ((Get-LifeDetailLabelIndex -Text $Text) -ge 0)
}
$rgLifeFindLink = @(430, 150, 420, 470)   # '가까운 위치 찾기' 링크 탐색 영역 (팝업 전체 높이 -
                                          # 링크 y 는 설명 길이에 따라 대상별 상이. 00:53 실사고)
$ptLifeSkillMenu = @(68, 393)             # 내 정보 좌측 '생활 스킬' 메뉴 (실측 50~86,393)
$ptLifeDetailConfirm = @(636, 642)        # 상세 팝업 확인 버튼
$ptLifeWindowClose = @(1228, 67)          # 전체 창 우상단 X (보유한 재화 창과 동일 위치)
# 직전 Test-LifeWindowOpen 이 글리프 서명으로 찾아낸 X 중심 (기준 좌표). 닫기 클릭이 이 값을
# 우선 쓰고, 못 찾았을 때만 위 상수로 폴백합니다 - 탐지와 클릭이 같은 환산을 왕복해야
# '판정은 고쳤는데 클릭이 15px 아래로 빗나가는' 다음 사고가 생기지 않습니다 (2026-08-08)
$script:lifeCloseGlyphHit = $null

function Invoke-LifeWindowCloseClick {
  # 생활 창 우상단 X 클릭 - 탐지된 글리프 중심 우선, 없으면 기준 상수 폴백
  param([System.Diagnostics.Process]$Game)
  $hit = $script:lifeCloseGlyphHit
  if ($hit -and $hit.Found) {
    Click-GamePoint -Game $Game -ReferenceX ([int]$hit.ReferenceX) -ReferenceY ([int]$hit.ReferenceY)
    return
  }
  Click-GamePoint -Game $Game -ReferenceX $ptLifeWindowClose[0] -ReferenceY $ptLifeWindowClose[1]
}
$ptLifeListCenter = @(950, 410)           # 대상 목록 중앙 (휠 스크롤 커서 위치)

function Get-LifeNormalizedName {
  param([string]$Name)
  return (([string]$Name) -replace '\s', '')
}

# 공통 깨짐 치환 쌍 (판독 → 실제). 대상 이름 매칭과 퀘스트 트래커 소유 판정이 함께 씁니다 -
# 한쪽만 고치면 '목록에서는 찾는데 트래커에서는 남의 퀘스트로 보이는' 불일치가 납니다.
# '일럼'→'일렁' 은 2026-08-08 실측: 곤충 '일렁이는 빛 무리' 가 s3~s6 **전 배율에서 일관되게**
# '일럼이는빛무리' 로 깨져 목록에서 대상을 못 찾았습니다(레벨 해금 후 첫 시도에서 발견).
# 목록의 다른 대상에 '일럼' 이 정당하게 들어간 이름이 없어 오탐 없음.
# 2026-08-08 hyodong 제보(1908 창)로 2쌍 추가:
#  · 'OI' -> '이' : 한글 '이'가 라틴 O+I 로 쪼개져 읽힘 ('일럼OI는빛무리'). 개발 PC 배율표
#    s6 행에도 이미 관측돼 있었는데 규칙에 반영되지 않아 놓쳤습니다.
#  · '및'  -> '빛' : '빛'이 '및'으로 읽힘 ('차가운및무리', '일럼이는및무리').
#    **좁은 쌍('및무리'->'빛무리')으로 넣으면 안 됩니다** - 아래 Get-LifeRepairedTexts 가
#    치환 여부를 '원문 기준'으로 판정하므로, '일럼이는및부리'처럼 깨짐이 겹친 문자열에서는
#    '및무리' 조각이 원문에 없어 규칙이 아예 발동하지 않습니다.
$lifeNameRepairPairs = @(@('나부', '나무'), @('부리', '무리'), @('곤춤', '곤충'), @('일럼', '일렁'),
  @('OI', '이'), @('및', '빛'))

function Get-LifeRepairedTexts {
  # 판독 문자열의 '깨짐 보정 사본들'을 돌려줍니다 (원문 + 규칙별 사본 + 전부 적용한 사본).
  # 한 문자열에 두 깨짐이 겹칠 수 있어 전부 적용한 사본이 필요합니다 (황폐한곤춤부리).
  param([string]$Text)
  $normalized = ([string]$Text) -replace '\s', ''
  $texts = @($normalized)
  if (-not $normalized) { return $texts }
  $allRepaired = $normalized
  foreach ($repairPair in $lifeNameRepairPairs) {
    if (-not $normalized.Contains($repairPair[0])) { continue }
    $texts += , $normalized.Replace($repairPair[0], $repairPair[1])
    $allRepaired = $allRepaired.Replace($repairPair[0], $repairPair[1])
  }
  if ($allRepaired -ne $normalized) { $texts += , $allRepaired }
  return $texts
}

function Get-LifeAllTargetNames {
  # 지원 8종 전체의 대상 이름 (퀘스트 소유 판정용).
  # 현재 스킬의 Order 만 후보로 쓰면 **다른 스킬의 잔여 퀘스트가 전부 '미확정'** 이 되고,
  # 더 나쁘게는 현재 스킬의 짧은 대상으로 오인됩니다 (2026-08-07 감사 실측:
  # 나무 베기 중 '사과 나무'/'차나무' 퀘스트 → '나무', 양털 중 '양파'/'양배추' → '양').
  param()
  $allNames = @()
  foreach ($skillKey in $lifeSkillMenuTable.Keys) {
    foreach ($targetName in @($lifeSkillMenuTable[$skillKey].Order)) { $allNames += , $targetName }
  }
  return $allNames
}

function Get-LifeQuestOwner {
  # 퀘스트 트래커 판독이 '어느 대상의 채집인지' 정합니다 (순수 - 진리표 대상).
  # 반환: 대상 이름 (못 정하면 '')
  # 단순 부분 문자열 비교는 형제 대상의 퀘스트를 자기 것으로 인수합니다 - '우물' 퀘스트를
  # 목표 '물' 이, '얽힌 거미줄' 을 '거미줄' 이, '뾰족 나무' 를 '나무' 가 가로챕니다
  # (2026-08-07 감사). **긴 이름부터** 대조해 어느 대상인지 먼저 확정합니다.
  # 트래커 이름도 깨지므로 이형 표와 공통 치환 사본을 모두 후보로 씁니다.
  param([string]$QuestText, [string[]]$Order = @())
  $haystacks = @(Get-LifeRepairedTexts -Text $QuestText)
  if (-not $haystacks[0]) { return '' }
  # 길이 내림차순 + 이름 오름차순(2차 키) - 같은 길이 대상이 여럿이라 PS 5.1 Sort-Object 의
  # 동률 순서가 불확정이면 결과가 흔들립니다 (리뷰 지적)
  foreach ($candidate in (@($Order) | Sort-Object { -(Get-LifeNormalizedName $_).Length }, { Get-LifeNormalizedName $_ })) {
    $candidateNorm = Get-LifeNormalizedName $candidate
    if (-not $candidateNorm) { continue }
    $needles = @($candidateNorm)
    if ($lifeTargetVariants.ContainsKey($candidateNorm)) { $needles += @($lifeTargetVariants[$candidateNorm]) }
    foreach ($needle in $needles) {
      foreach ($haystack in $haystacks) {
        if ($haystack.Contains($needle)) { return $candidate }
      }
    }
  }
  return ''
}

function Test-LifeNameMatches {
  # 행 조합 텍스트가 설정 대상과 일치하는지 (공백 제거 정확 일치 + 실측 이형 - 순수 판정)
  param([string]$RowText, [string]$TargetName)
  $rowNorm = Get-LifeNormalizedName $RowText
  $targetNorm = Get-LifeNormalizedName $TargetName
  if ($rowNorm -eq $targetNorm) { return $true }
  if ($lifeTargetVariants.ContainsKey($targetNorm) -and (@($lifeTargetVariants[$targetNorm]) -contains $rowNorm)) {
    return $true
  }
  # 공통 깨짐 보정 (판독 쪽을 정확 치환한 사본으로 재비교):
  #  '나무'→'나부'  실측 3회 (사과나부/나부만한쓸/흰껍질나부)
  #  '무리'→'부리'  실측 2회 (설원빛부리/고요한빛부리 - 곤충 채집, 2026-08-07)
  #  '곤충'→'곤춤'  실측 1회 (황폐한곤춤부리 - 같은 행에 두 깨짐이 겹침)
  # 일부 대상만 이형 등록하면 같은 계열 다른 대상이 빠지므로 규칙으로 처리합니다.
  # 한 행에 두 개 이상 겹칠 수 있어(황폐한곤춤부리 = 곤춤 + 부리) **개별 치환뿐 아니라
  # 전부 적용한 사본까지** 비교합니다 (리뷰 지적 - '부리'만 고치면 '곤춤'이 남아 실패).
  # 현재 대상 목록에 정당한 '나부'/'부리'/'곤춤'이 든 이름이 없어 오탐 없음 - 새 대상 추가 시 재확인
  $repairCandidates = @()
  $allRepaired = $rowNorm
  foreach ($repairPair in $lifeNameRepairPairs) {
    if (-not $rowNorm.Contains($repairPair[0])) { continue }
    $repairCandidates += , $rowNorm.Replace($repairPair[0], $repairPair[1])
    $allRepaired = $allRepaired.Replace($repairPair[0], $repairPair[1])
  }
  if ($allRepaired -ne $rowNorm) { $repairCandidates += , $allRepaired }
  foreach ($rowRepaired in $repairCandidates) {
    if ($rowRepaired -eq $targetNorm) { return $true }
    if ($lifeTargetVariants.ContainsKey($targetNorm) -and (@($lifeTargetVariants[$targetNorm]) -contains $rowRepaired)) {
      return $true
    }
  }
  return $false
}

function Get-LifeDetailTitleFromWords {
  # 링크 탐색 판독(팝업 전체 영역)에서 **제목 줄**만 뽑습니다 (순수 - 진리표 대상).
  # 제목은 팝업 최상단 줄이므로 가장 작은 Y 의 행을 X 순으로 이어 붙입니다.
  # 용도: '가까운 위치 찾기'를 누르기 직전에, **링크를 찾은 그 판독 그대로** 대상 이름을
  # 다시 확인하기 위함입니다 (2026-08-07 사용자 제안). 지금까지는 제목 검증과 링크 클릭이
  # 서로 다른 캡처라, 그 사이에 팝업이 바뀌면 검증하지 않은 화면을 누를 수 있었습니다.
  # **고정 Y 를 쓰면 안 됩니다** - 팝업이 세로 중앙 정렬이라 내용 길이에 따라 제목 Y 가
  # 움직입니다 (실측: 사과 나무 = 위치 줄 '[일반필드] 던바튼' 있어 y191 /
  # 나무 = 위치 줄 없어 y213). 그래서 '최상단 행'으로 잡습니다.
  param($Words, [int]$RowTolerance = 14)
  $wordList = @($Words)
  if ($wordList.Count -eq 0) { return '' }
  $topY = $null
  foreach ($word in $wordList) {
    if ($null -eq $topY -or [int]$word.Y -lt $topY) { $topY = [int]$word.Y }
  }
  $titleWords = @($wordList | Where-Object { [Math]::Abs([int]$_.Y - $topY) -le $RowTolerance } | Sort-Object { [int]$_.X })
  $titleText = ((($titleWords | ForEach-Object { [string]$_.Text }) -join '') -replace '\s', '')
  # 이름 줄이 통째로 안 읽히면 최상단 행이 라벨('채집물')이 됩니다 - 실측 전수 확인에서
  # '채집물'/'자|집물' 로 나온 사례 4건 (물·우물·젖소·추수 대상들. 2026-08-07).
  # 라벨을 제목으로 넘기면 '읽었는데 이름이 다르다' 로 오해할 소지가 있어 빈 값으로 둡니다.
  if (Test-LifeDetailHasLabel -Text $titleText) { return '' }
  return $titleText
}

function Get-LifeTitleFromDetailText {
  # 상세 영역 판독 문자열에서 제목부만 잘라 냅니다 (순수 - 진리표 대상).
  # 구조가 '이름 → 채집물(라벨) → …' 이라 라벨 앞이 제목입니다.
  # 라벨이 없으면 팝업 판독이 아니므로 빈 값 (클릭 직전 재확인을 건너뜁니다).
  param([string]$DetailText)
  $normalized = ([string]$DetailText) -replace '\s', ''
  $labelIndex = Get-LifeDetailLabelIndex -Text $normalized
  if ($labelIndex -lt 1) { return '' }
  return $normalized.Substring(0, $labelIndex)
}

function Get-LifeTitleStripRegion {
  # 제목 '띠' 영역을 라벨('채집물') 행 기준으로 계산합니다 (순수 - 진리표 대상).
  # 팝업이 세로 중앙 정렬이라 제목 Y 가 고정이 아니어서(실측: 사과 나무 191 / 나무 213)
  # 라벨 Y 에서 역산합니다 - 제목은 라벨보다 약 27px 위, 글자 높이 약 26px.
  # 왜 필요한가: 넓은 영역 저배율로는 아예 안 읽히는 이름이 **좁은 띠 고배율에서는 읽힙니다**
  # (2026-08-08 실측: '숨숨꽃'은 s6 에서만, '옥수수'는 s4·s6 에서, '흰 껍질 나무'·'운철 광맥'
  #  은 s6 에서 깨짐 없이 판독). 라벨을 못 찾으면 $null (재확인 생략).
  # 후보가 여럿이면 **가장 위(Y 최소)** 를 씁니다 - 단어 배열의 열거 순서는 보장되지 않아
  # 설명 쪽 단어가 먼저 걸리면 제목 띠가 아래로 밀려 엉뚱한 줄을 읽습니다
  # (2026-08-09 교차 리뷰 반례: 440,174 대신 440,286 이 나옴). 라벨은 팝업에서 제목 바로
  # 아래 한 줄뿐이므로 최소 Y 가 곧 진짜 라벨입니다.
  param($Words)
  $labelY = $null
  foreach ($word in @($Words)) {
    if (-not (Test-LifeDetailHasLabel -Text ([string]$word.Text))) { continue }
    $wordY = [int]$word.Y
    if ($null -eq $labelY -or $wordY -lt $labelY) { $labelY = $wordY }
  }
  if ($null -eq $labelY) { return $null }
  return @(440, ($labelY - 44), 300, 36)
}

function Get-LifeProgressValue {
  # 채집 수량 표기('6/10')에서 '모은 개수'를 뽑습니다 (순수 - 진리표 대상). 못 읽으면 -1.
  # 판독이 '0/0', '2/1' 처럼 튀는 일이 잦아(실측) 분모는 신뢰하지 않고 분자만 씁니다.
  param([string]$CountText)
  $normalized = ([string]$CountText) -replace '\s', ''
  if ($normalized -notmatch '(\d{1,3})/(\d{1,3})') { return -1 }
  $collected = [int]$Matches[1]
  if ($collected -lt 0 -or $collected -gt 999) { return -1 }
  return $collected
}

function Get-LifeQuestGoalValue {
  # 채집 수량 표기('6/10')에서 '목표 개수'(분모)를 뽑습니다 (순수 - 진리표 대상). 못 읽으면 0.
  # 분모는 '0/0', '2/1' 처럼 깨지는 실측이 있어 **분자보다 작으면 버립니다** (말이 안 되는 값).
  param([string]$CountText)
  $normalized = ([string]$CountText) -replace '\s', ''
  if ($normalized -notmatch '(\d{1,3})/(\d{1,3})') { return 0 }
  $collected = [int]$Matches[1]
  $goal = [int]$Matches[2]
  if ($goal -lt 1 -or $goal -gt 999) { return 0 }
  if ($goal -lt $collected) { return 0 }
  return $goal
}

function Get-LifeQuestGoalConsensus {
  # 관측된 목표 개수(분모)들 중 **가장 많이 본 값**을 채택합니다 (순수 - 진리표 대상).
  # 실측에서 분모가 '0/1' 처럼 튀는 회차가 섞이므로 한 번의 판독을 믿으면 안 됩니다.
  # 동률이면 큰 값 - 깨짐은 대개 작은 값으로 나옵니다('/1', '/0').
  param($GoalCounts)
  $bestGoal = 0
  $bestSeen = 0
  if (-not $GoalCounts) { return 0 }
  foreach ($goalKey in $GoalCounts.Keys) {
    $seen = [int]$GoalCounts[$goalKey]
    $goal = [int]$goalKey
    if ($seen -gt $bestSeen -or ($seen -eq $bestSeen -and $goal -gt $bestGoal)) {
      $bestGoal = $goal
      $bestSeen = $seen
    }
  }
  return $bestGoal
}

function Get-LifeConsensusVerdict {
  # 여러 배율 판정의 합의 (순수 - 진리표 대상).
  # 'mine'/'other' 는 **모든 확정 판정이 같을 때만** 채택하고, 엇갈리면 'unknown'(막지 않음).
  # 확정이 하나도 없으면 'unknown'. 판정 하나로 확정하면 한 배율의 깨짐이 곧 오차단입니다.
  param([string[]]$Verdicts)
  $decided = @(@($Verdicts) | Where-Object { $_ -and $_ -ne 'unknown' })
  if ($decided.Count -eq 0) { return 'unknown' }
  $first = [string]$decided[0]
  foreach ($verdict in $decided) { if ([string]$verdict -ne $first) { return 'unknown' } }
  # 'other'(차단)는 확정 판정이 2개 이상 일치할 때만 - 단독 other 는 보류합니다
  if ($first -eq 'other' -and $decided.Count -lt 2) { return 'unknown' }
  return $first
}

function Get-LifeTitleVerdictFromDetail {
  # 상세 영역 판독으로 내리는 클릭 직전 재확인 판정 (순수 - 진리표 대상).
  # 반환: 'mine' / 'other' / 'unknown'
  # 상세 판독의 제목 끝에는 **라벨('채집물')의 앞 1~2 글자가 남습니다** ('…채' / '…자|').
  # 임의 축약이 아니라 '라벨 잔여 제거'라는 근거가 있는 절단이므로 0~2 자를 깎으며 봅니다.
  # 잘못 깎여 다른 대상이 되는 위험은 Get-LifeTitleVerdict 의 '목표 이름의 일부면 unknown'
  # 규칙이 막습니다 (예: '나무채' → '나무' 는 목표 '뾰족 나무'의 일부라 차단하지 않음).
  param([string]$DetailText, [string]$TargetName, [string[]]$Order = @())
  $title = Get-LifeTitleFromDetailText -DetailText $DetailText
  if (-not $title) { return 'unknown' }
  for ($trimCount = 0; $trimCount -le 2; $trimCount++) {
    if (($title.Length - $trimCount) -lt 1) { break }
    $candidate = $title.Substring(0, $title.Length - $trimCount)
    $verdict = Get-LifeTitleVerdict -Title $candidate -TargetName $TargetName -Order $Order
    if ($verdict -ne 'unknown') { return $verdict }
  }
  return 'unknown'
}

function Get-LifeTitleVerdict {
  # 제목 문자열만으로 내리는 '고신뢰' 판정 (순수 - 진리표 대상).
  # 반환: 'mine' / 'other' / 'unknown'
  # 클릭 직전 재확인 전용입니다. Get-LifeDetailVerdict 의 규칙(꼬리 2자 trim, 본문 구제,
  # 가독성 휴리스틱)을 그대로 쓰면 **정상 팝업을 다른 대상으로 오판**합니다 (리뷰 재현:
  # '거미줄XX' 가 2자 깎여 '거미줄' 이 되어 목표 '거미줄 뭉치' 를 차단). 여기서는 깎지 않고
  # 정확 일치(이형·공통 치환 포함)만 봅니다.
  # 그리고 읽힌 다른 이름이 **목표 이름의 일부**면 'unknown' 으로 둡니다 - 복합 이름의 앞
  # 낱말이 누락돼 일부만 읽힌 경우('뾰족 나무' → '나무', '철 광맥' → '광맥')를 오차단하지
  # 않기 위함입니다. 확신이 없으면 막지 않는다(fail-open)는 정책입니다.
  param([string]$Title, [string]$TargetName, [string[]]$Order = @())
  $titleNorm = Get-LifeNormalizedName $Title
  if (-not $titleNorm) { return 'unknown' }
  if (Test-LifeTitleNameMatches -Title $titleNorm -TargetName $TargetName) { return 'mine' }
  $targetNorm = Get-LifeNormalizedName $TargetName
  foreach ($otherName in @($Order)) {
    if (Test-LifeNameMatches -RowText $otherName -TargetName $TargetName) { continue }   # 자기 자신 제외
    if (-not (Test-LifeTitleNameMatches -Title $titleNorm -TargetName $otherName)) { continue }
    # 목표 이름이 이 이름을 품고 있으면 '일부만 읽힌 것' 일 수 있어 확정하지 않습니다
    if ($targetNorm.Contains((Get-LifeNormalizedName $otherName))) { return 'unknown' }
    return 'other'
  }
  return 'unknown'
}

function Select-LifeFindNearestWord {
  # '가까운 위치 찾기' 링크 클릭 지점 선택 (순수 - 진리표 대상).
  # 행 단위로 묶어 결합 문구에 '위치찾기'가 있는 행만 링크로 인정하고, 그런 행이 정확히
  # 1개일 때 그 행의 가로 중앙을 돌려줍니다 (설명 본문 오클릭 방지 - 리뷰 조건).
  # '가까운' 단어 자체를 요구하면 실기 깨짐('가7)}운' - 2026-08-06 라운드 5 실측)에서
  # 링크를 못 찾습니다. 안정 조각은 '위치찾기' 쪽입니다.
  param($Words)
  $rows = @()
  foreach ($linkWord in @($Words)) {
    $matched = $false
    foreach ($row in $rows) {
      if ([Math]::Abs([int]$linkWord.Y - [int]$row.Y) -le 14) { $row.Words += , $linkWord; $matched = $true; break }
    }
    if (-not $matched) { $rows += , @{ Words = @(, $linkWord); Y = [int]$linkWord.Y } }
  }
  $candidates = @()
  foreach ($row in $rows) {
    $sortedWords = @($row.Words | Sort-Object { [int]$_.X })
    $rowText = (($sortedWords | ForEach-Object { [string]$_.Text }) -join '')
    if ($rowText.Contains('위치찾기') -or $rowText.Contains('위치칮기')) {
      $minX = [int]($sortedWords[0].X)
      $maxX = [int]($sortedWords[@($sortedWords).Count - 1].X)
      $candidates += , @{ X = [int](($minX + $maxX) / 2); Y = [int]$row.Y }
    }
  }
  if (@($candidates).Count -ne 1) { return $null }
  return $candidates[0]
}

function Test-LifeBodyNameAmbiguous {
  # 상세 팝업 '본문 포함' 만으로 대상을 확정해도 되는 이름인지 (순수 - 진리표 대상).
  # $true = 모호하니 본문 근거를 쓰면 안 됨.
  # 본문 구조가 '이름 → 채집물 → 스킬명 레벨 N 이상 → 설명' 이라 스킬 이름은 **항상** 있고,
  # 목록의 다른 대상이 이 이름을 통째로 품으면 그 대상 팝업에서도 똑같이 참이 됩니다.
  # SelfName: 수식어(첫 낱말)로 검사할 때 '자기 자신' 판단에 쓸 원래 대상 이름.
  param([string]$Name, [string[]]$Order = @(), [string]$SkillName = '', [string]$SelfName = '')
  $nameNorm = Get-LifeNormalizedName $Name
  if ($nameNorm.Length -lt 2) { return $true }
  if ($SkillName) {
    # 예: 목표 '나무' 는 스킬명 '나무 베기' 에 들어 있어 나무 베기의 모든 팝업 본문과 일치
    if ((Get-LifeNormalizedName $SkillName).Contains($nameNorm)) { return $true }
  }
  $selfForCompare = $(if ($SelfName) { $SelfName } else { $Name })
  foreach ($otherName in @($Order)) {
    if (Test-LifeNameMatches -RowText $otherName -TargetName $selfForCompare) { continue }   # 자기 자신 제외
    if ((Get-LifeNormalizedName $otherName).Contains($nameNorm)) { return $true }
  }
  return $false
}

function Get-LifeDetailVerdict {
  # 대상 상세 팝업 판정 (순수 - 진리표 대상).
  # 반환: 'match' / 'wrong-target' / 'unreadable' / 'no-label'
  #  match       = 제목이 대상과 일치하거나, 본문에 대상 이름이 있음
  #  wrong-target= 제목이 '정상 한글로 또렷이' 읽히는데 대상과 다름 = 오클릭 확정
  #  unreadable  = 팝업은 떴으나 제목이 깨져 판단 불가 (호출부는 행 매칭 증거로 진행)
  #  no-label    = 팝업 자체가 안 보임
  # 라벨은 '채집물'의 안정 조각 '집물'로 찾습니다 (실기: '자|집물'/'재집물' 깨짐 다수).
  # 제목부는 깨진 '채' 잔여(최대 2자)만 끝에서 잘라내며 정확 일치 - 무제한 접두 축소는
  # '거미줄 뭉치' 팝업을 '거미줄' 설정과 오인하므로 2자 제한이 필수.
  # unreadable 구분 근거(전수 배치 01:04 실측): 우물 제목 '丁亞'(한글 0자), 젖소 'C0자'
  # (한글 1/3) 처럼 깨진 제목을 오클릭으로 확정해 3회 소진하던 사고 - 정상 오클릭이면
  # 제목이 그 대상 이름으로 또렷이(한글 비율 0.8+) 읽힌다는 실측 성질을 이용합니다.
  param([string]$DetailText, [string]$TargetName, [string[]]$Order = @(), [string]$SkillName = '')
  $labelIndex = Get-LifeDetailLabelIndex -Text ([string]$DetailText)
  if ($labelIndex -lt 0) { return 'no-label' }
  $detailTitle = ([string]$DetailText).Substring(0, $labelIndex)
  # ⓪ 제목이 '깎아내지 않은 그대로' 목표와 일치하면 그 자리에서 확정합니다.
  #    ① 의 오클릭 대조는 제목을 최대 2자 깎아 가며 비교하는데, 그 때문에 '거미줄 뭉치'
  #    자기 팝업이 2자 깎여 '거미줄' 이 되어 오클릭으로 확정되는 반례가 있습니다
  #    (실측 깨짐으로 '채' 가 사라져 제목이 정확히 '거미줄뭉치' 로 읽힐 때 - 2026-08-07 감사).
  #    깎지 않은 일치가 깎은 일치보다 강한 증거이므로 순서를 앞에 둡니다.
  if (Test-LifeNameMatches -RowText $detailTitle -TargetName $TargetName) { return 'match' }
  # ① 오클릭 확정을 '가장 먼저' 검사합니다 (리뷰 블로커): 제목 그대로가 같은 목록의 다른
  #    대상과 정확히 일치하면 오클릭. 목표 검사를 먼저 하면 접두 축소(trim)가 '거미줄 뭉치'
  #    팝업을 '거미줄' 목표로 오인합니다. 여기서는 trim 없이 원문만 비교합니다.
  # 긴 이름부터 검사해야 '거미줄 뭉치' 팝업이 '거미줄'로 축소 해석되지 않습니다.
  # 제목의 깨진 '채' 잔여(최대 2자)는 목표 검사와 같은 규칙으로 잘라내며 비교합니다.
  foreach ($otherName in (@($Order) | Sort-Object { -(Get-LifeNormalizedName $_).Length })) {
    if (Test-LifeNameMatches -RowText $otherName -TargetName $TargetName) { continue }   # 자기 자신 제외
    for ($trimCount = 0; $trimCount -le 2; $trimCount++) {
      if (($detailTitle.Length - $trimCount) -lt 1) { break }
      $titleCandidate = $detailTitle.Substring(0, $detailTitle.Length - $trimCount)
      if (Test-LifeNameMatches -RowText $titleCandidate -TargetName $otherName) { return 'wrong-target' }
    }
  }
  # ② 제목이 목표와 일치 (깨진 '채' 잔여 최대 2자만 끝에서 제거)
  for ($trimCount = 0; $trimCount -le 2; $trimCount++) {
    if (($detailTitle.Length - $trimCount) -lt 1) { break }
    $titleCandidate = $detailTitle.Substring(0, $detailTitle.Length - $trimCount)
    if (Test-LifeNameMatches -RowText $titleCandidate -TargetName $TargetName) { return 'match' }
  }
  # ③ 본문 구제 (실측: 젖소 '…특징인젖소'). 라벨 '집물' 두 글자는 반드시 제외하고, 2자
  #    이상 이름만 허용합니다 - '물' 같은 1글자는 라벨 자체에 들어 있어 전 팝업이 일치해
  #    다른 대상을 통과시켰습니다 (리뷰 블로커 반례).
  #    이름 전체가 없으면 '고유 수식어'(첫 낱말, 2자 이상)로도 확인합니다 - 실측: 백동 광맥
  #    본문은 '백동이 섞인…백동 광석'이라 '백동광맥'은 없지만 '백동'은 확실 (라운드 5)
  $targetNorm = Get-LifeNormalizedName $TargetName
  if ($targetNorm.Length -ge 2) {
    $detailBody = ([string]$DetailText).Substring([Math]::Min($labelIndex + 2, ([string]$DetailText).Length))
    # 전체 이름 경로에도 모호성 검사를 겁니다 (2026-08-07 감사 - high).
    # 본문에는 **항상 스킬 이름이** 들어가고('… 나무 베기 레벨 1 이상'), 목록의 다른 대상이
    # 목표 이름을 통째로 품는 경우도 많습니다(뾰족 나무 ⊃ 나무 / 철 광맥 ⊃ 광맥 /
    # 설원 빛 무리 ⊃ 빛 무리 / 거미줄 뭉치 ⊃ 거미줄). 그런 목표는 본문 포함이 아무것도
    # 증명하지 못하는데도 match 를 돌려줘, 제목이 깨진 순간 오클릭을 전혀 못 잡았습니다.
    # (2026-08-06 리뷰 블로커였던 1글자 '물' 문제가 2글자 기저 명사로 살아남은 것)
    if ((-not (Test-LifeBodyNameAmbiguous -Name $TargetName -Order $Order -SkillName $SkillName)) -and
      $detailBody.Contains($targetNorm)) {
      return 'match'
    }
    $targetHead = (([string]$TargetName).Trim() -split '\s+')[0]
    if ($targetHead.Length -ge 2 -and $targetHead -ne $targetNorm -and $detailBody.Contains($targetHead) -and
      -not (Test-LifeBodyNameAmbiguous -Name $targetHead -Order $Order -SkillName $SkillName -SelfName $TargetName)) {
      # 실측: 백동 광맥 본문은 '백동이 섞인…백동 광석' 이라 '백동광맥'은 없지만 '백동'은 확실
      return 'match'
    }
  }
  # ④ 목록 정보가 없을 때만 가독성 휴리스틱 (또렷한 한글 제목 = 오클릭)
  if (@($Order).Count -eq 0) {
    if ($detailTitle.Length -lt 2) { return 'unreadable' }
    $hangulCount = 0
    foreach ($titleChar in $detailTitle.ToCharArray()) {
      if ($titleChar -ge [char]0xAC00 -and $titleChar -le [char]0xD7A3) { $hangulCount++ }
    }
    if (($hangulCount / [double]$detailTitle.Length) -ge 0.8) { return 'wrong-target' }
  }
  return 'unreadable'
}

function Get-LifeRequiredLevel {
  # 상세 팝업 판독 문자열에서 대상의 요구 스킬 레벨('… 레벨 N 이상')을 뽑습니다 (순수 - 진리표 대상).
  # 2026-08-07 실측: 곤충 채집 '일렁이는 빛 무리'는 레벨 27 이상이 필요한데 캐릭터가 25라
  # '가까운 위치 찾기'를 눌러도 퀘스트가 생기지 않고 메뉴 사이클 3회를 소진했습니다.
  # 원인이 화면에만 남아 로그만 보면 알 수 없었으므로, 실패 안내에 요구치를 함께 적습니다.
  # '이상'은 OCR 이 자주 깨뜨리므로('레벨27이실h1') '레벨' + 숫자만으로 찾습니다.
  # 캐릭터의 현재 레벨은 목록 머리글 판독이 불안정해('LⅥ2512,396') 비교하지 않습니다 -
  # 요구치만 알려 주고 판단은 사용자에게 맡깁니다 (단정 금지).
  # 못 찾거나 값이 비상식적이면 0 을 돌려 호출부가 안내를 생략하게 합니다.
  # 탐색 범위는 라벨('채집물'의 안정 조각 '집물') **뒤쪽으로 제한**합니다 - 팝업 구조가
  # '이름 → 채집물 → 스킬명 레벨 N 이상 → 설명' 이라 요구치는 반드시 라벨 뒤에 옵니다.
  # 라벨이 없으면 상세 팝업이 아니거나 판독이 깨진 것이므로 안내하지 않습니다 (리뷰 지적).
  param([string]$DetailText)
  $normalized = ([string]$DetailText) -replace '\s', ''
  $labelIndex = Get-LifeDetailLabelIndex -Text $normalized
  if ($labelIndex -lt 0) { return 0 }
  # 라벨 **바로 뒤 짧은 구간만** 봅니다. 팝업 구조가 '채집물 → 스킬명 레벨 N 이상 → 설명'
  # 이라 요구치는 라벨 직후에 오고, 뒤 설명까지 훑으면 설명 속 숫자를 요구치로 오독합니다
  # (2026-08-09 교차 리뷰 반례: 진짜 요구치가 깨져 사라지고 설명의 '레豊30' 만 잡힘).
  # 24자면 실측 '광석개기레豊30이상'(9자)에 스킬명이 긴 경우까지 충분히 들어옵니다.
  $afterStart = [Math]::Min($labelIndex + 2, $normalized.Length)
  $afterLength = [Math]::Min(24, $normalized.Length - $afterStart)
  $afterLabel = $normalized.Substring($afterStart, $afterLength)
  # (?!\d) 로 숫자 뒤가 더 이어지면 매칭하지 않습니다 - 없으면 '레벨1000'이 앞 세 자리만
  # 잘려 100 으로 읽힙니다 (리뷰 지적: 상한 검사만으로는 못 막는 접두부 절단).
  # '레벨' 자체도 깨집니다 - 2026-08-09 제보에서 '레豊30이상' 관측. 임의로 느슨하게 하면
  # 설명 본문의 숫자를 요구치로 오독할 수 있으므로 **실측된 깨짐만** 후보로 둡니다.
  $levelMatches = [regex]::Matches($afterLabel, '레[벨豊](\d{1,3})(?!\d)')
  if ($levelMatches.Count -eq 0) { return 0 }
  # 서로 다른 값이 둘 이상 잡히면 어느 쪽이 요구치인지 확신할 수 없어 안내를 생략합니다
  $distinctLevels = @($levelMatches | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique)
  if ($distinctLevels.Count -ne 1) { return 0 }
  $requiredLevel = [int]$distinctLevels[0]
  # 생활 스킬 레벨은 두 자리대라 100 을 넘는 값은 판독 합성으로 봅니다 (예: '2512' → 251)
  if ($requiredLevel -lt 1 -or $requiredLevel -gt 100) { return 0 }
  return $requiredLevel
}

function Test-CaptureRecovered {
  # 화면 캡처가 복구됐는지 확인합니다 (반환: 복구됨 여부).
  # 2026-08-07 실사고(호미질 개암 버섯): 채집 3/10 진행 중 RDP 창이 최소화돼 캡처가 실패하자
  # 생활 분기의 모든 대기 지점이 '캡처 실패 중이면 판독을 건너뛰고 continue' 하는 바람에
  # **아무도 캡처를 시도하지 않아** 화면이 돌아와도 감지하지 못하고 한도까지 기다렸습니다
  # ($script:screenCaptureFailing 은 캡처가 성공해야만 해제됨 - 리뷰 지적).
  # 던전 분기는 같은 자리에서 OCR 판독을 복구 탐침으로 쓰는데, 여기서는 글자가 필요 없으므로
  # 작은 영역을 뜨기만 합니다 (성공하면 Get-GameRegionCapture 안에서 플래그가 풀림).
  param([System.Diagnostics.Process]$Game)
  # 반환값은 Bitmap 이 아니라 Bitmap 속성을 가진 래퍼입니다 - 래퍼에 Dispose 를 부르면
  # 'Dispose 메서드 없음' 예외가 납니다 (리뷰 지적 - 복구되는 순간에만 터지는 경로라
  # 실기에서 늦게 드러났을 사고)
  $probeCapture = Get-GameRegionCapture -Game $Game -ReferenceX 0 -ReferenceY 0 `
    -RegionWidth 40 -RegionHeight 40 -Scale 1
  # 캡처가 $null 이면 실패입니다. GetWindowRect 실패 경로는 플래그를 세우지 않고 $null 만
  # 돌려주므로, 플래그만 보면 '정상'으로 통과합니다 (리뷰 지적 - 클릭 직전 게이트가 뚫림)
  if (-not $probeCapture) { return $false }
  $probeCapture.Bitmap.Dispose()
  return (-not $script:screenCaptureFailing)
}

function Wait-LifeCaptureAlive {
  # 화면이 그려질 때까지 기다립니다 (반환: 진행해도 되면 $true / 한도 초과면 $false).
  # 판독과 입력이 섞인 구간 앞에 둡니다 - 캡처가 끊긴 채로 판독하면 '행 0개'가 나오고,
  # 그걸 '목록이 사라졌다'로 해석해 미발견 정지(exit 4)까지 갔습니다 (2026-08-07 감사).
  # 프리즈된 화면에 드래그·클릭을 보내는 것도 함께 막습니다 (안 보이는 채로 조작 금지).
  param([System.Diagnostics.Process]$Game, [datetime]$Deadline, [string]$Context = '')
  if (-not $script:screenCaptureFailing) { return $true }
  Write-RunLog "[생활] 화면이 그려지지 않습니다 - 복구를 기다립니다 (${Context})"
  while ($script:screenCaptureFailing) {
    if ((Get-Date) -gt $Deadline) {
      Write-RunLog "[생활] 사이클 한도 초과 - ${Context} 중단 (화면 미표시 상태)"
      return $false
    }
    Test-SafeStopDuringCaptureFail
    Start-Sleep -Seconds 2
    [void](Test-CaptureRecovered -Game $Game)
  }
  # 대기 중에 한도를 넘겼을 수 있습니다 - 여기서 $true 를 돌려주면 호출부가 곧바로 드래그를
  # 보냅니다 (한도 초과 후 입력 금지 계약 위반 - 리뷰 지적)
  if ((Get-Date) -gt $Deadline) {
    Write-RunLog "[생활] 화면은 복구됐지만 사이클 한도를 넘겼습니다 - ${Context} 중단"
    return $false
  }
  Write-RunLog "[생활] 화면이 복구됐습니다 - ${Context} 계속"
  return $true
}

function Confirm-LifeGameFront {
  # 게임 창이 '실제로 전면'인지 확인하고, 아니면 전면화합니다 (최대 3회).
  # 2026-08-07 실사고: 개발 창(에디터/터미널)이 게임을 덮은 채로 자동화가 계속 돌아
  # 판독이 그 창의 글자('mabinogi_gui.ps1', 'GroupBox' 등)를 읽고, 클릭도 엉뚱한 곳에
  # 들어갔습니다. 판독·클릭 전에 이 확인을 통과해야 진행합니다.
  param([System.Diagnostics.Process]$Game)
  foreach ($frontTry in 1..3) {
    if (Test-GameForeground -Game $Game) { return $true }
    Focus-Game -Game $Game
    Start-Sleep -Milliseconds 600
  }
  Write-RunLog '[생활] 게임 창이 전면이 아닙니다(다른 창이 가림) - 이번 판단을 보류합니다'
  return $false
}

function Test-LifeInfoScreen {
  # 내 정보 화면 판정: 능력치 라벨 영역에 '생활력' (실측: (232,419) s3 정확 판독)
  param([System.Diagnostics.Process]$Game)
  if ($script:screenCaptureFailing) { return $false }
  $statsText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgLifeStats[0] -ReferenceY $rgLifeStats[1] `
      -RegionWidth $rgLifeStats[2] -RegionHeight $rgLifeStats[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  return $statsText.Contains('생활력')
}

function Get-LifeTargetRows {
  # 대상 목록을 행 단위로 조합해 반환 (레벨 열(x>1100) 제외, Y ±14px 그룹).
  # 반환: @(@{ Text; Y }) - 행 클릭은 x950 고정 (행 전체가 버튼)
  param([System.Diagnostics.Process]$Game, [int]$Scale)
  $listWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $rgLifeTargetList[0] -ReferenceY $rgLifeTargetList[1] `
      -RegionWidth $rgLifeTargetList[2] -RegionHeight $rgLifeTargetList[3] -Scale $Scale -Engine $ocrKoreanEngine)
  $rows = @()
  foreach ($listWord in ($listWords | Where-Object { [int]$_.X -lt 1100 } | Sort-Object { [int]$_.Y }, { [int]$_.X })) {
    $matched = $false
    foreach ($row in $rows) {
      if ([Math]::Abs([int]$listWord.Y - [int]$row.Y) -le 14) {
        $row.Words += , $listWord
        $matched = $true
        break
      }
    }
    if (-not $matched) { $rows += , @{ Words = @(, $listWord); Y = [int]$listWord.Y } }
  }
  # 같은 행 안에서는 X 로 다시 정렬해 붙입니다 - 전역 Y,X 정렬만 쓰면 두 단어의 Y 중심이
  # 1~2px 어긋날 때 순서가 뒤집힘 (GUI 실기 23:24 실측: '뾰족 나무' → '나무뾰족'으로
  # 조합돼 정확 일치가 전부 빗나감 - 대상 미발견 실사고)
  foreach ($row in $rows) {
    $row.Text = (($row.Words | Sort-Object { [int]$_.X } | ForEach-Object { [string]$_.Text }) -join '')
  }
  return $rows
}

function Get-LifeTargetRowByOrder {
  # 판독된 행들을 목록 순서(Order)에 대응시켜 '판독 안 된 대상'의 행 Y 를 추론합니다
  # (순수 - 진리표 대상). 규칙:
  #  ① 각 행 텍스트를 Order 의 어느 이름과 일치시켜 (인덱스, Y) 앵커를 만든다
  #  ② 앵커가 2개 이상이고, 인덱스 차이 대비 Y 간격이 RowGap 과 ±12px 안에서 일관될 때만 채택
  #  ③ 목표 인덱스의 Y = 앵커 Y + (목표 인덱스 - 앵커 인덱스) x RowGap
  #  ④ 추론 Y 가 목록 영역(TopY~BottomY) 밖이면 $null (화면 밖 = 스크롤 필요)
  # 앵커 1개 이하거나 간격이 흔들리면 추론하지 않습니다 (오클릭 방지 - 화면 대상은 정확
  # 일치 경로가 이미 처리하므로, 이 함수는 '보이지만 안 읽히는 행' 전용 보완입니다)
  param($Rows, [string[]]$Order, [string]$TargetName, [int]$RowGap = 90,
        [int]$TopY = 150, [int]$BottomY = 680)
  if (-not $Order -or @($Order).Count -eq 0) { return $null }
  $targetIndex = -1
  for ($orderIndex = 0; $orderIndex -lt @($Order).Count; $orderIndex++) {
    if (Test-LifeNameMatches -RowText ([string]$Order[$orderIndex]) -TargetName $TargetName) { $targetIndex = $orderIndex; break }
  }
  if ($targetIndex -lt 0) { return $null }
  # 앵커 수집: ① 정확/이형 일치 우선 ② 실패 시 '행에 이름이 포함'되면 앵커로 인정
  # (아이콘 조각이 붙는 실측 '4거미줄' 때문에 정확 일치만으로는 앵커가 부족해 신뢰도가
  # 떨어짐 - 2026-08-06 라운드 7). ②는 긴 이름부터 검사해 '거미줄 뭉치'를 '거미줄'로
  # 오인하지 않게 합니다. 앵커는 위치 추정용이라 포함 매칭으로도 안전합니다.
  $orderByLength = @(0..(@($Order).Count - 1) | Sort-Object { -(Get-LifeNormalizedName $Order[$_]).Length })
  $anchors = @()
  foreach ($row in @($Rows)) {
    $rowNorm = Get-LifeNormalizedName ([string]$row.Text)
    $anchorIndex = -1
    for ($orderIndex = 0; $orderIndex -lt @($Order).Count; $orderIndex++) {
      if (Test-LifeNameMatches -RowText ([string]$row.Text) -TargetName ([string]$Order[$orderIndex])) {
        $anchorIndex = $orderIndex
        break
      }
    }
    if ($anchorIndex -lt 0) {
      foreach ($candidateIndex in $orderByLength) {
        $candidateNorm = Get-LifeNormalizedName ([string]$Order[$candidateIndex])
        if ($candidateNorm.Length -ge 2 -and $rowNorm.Contains($candidateNorm)) {
          $anchorIndex = $candidateIndex
          break
        }
      }
    }
    if ($anchorIndex -ge 0) { $anchors += , @{ Index = $anchorIndex; Y = [int]$row.Y } }
  }
  if (@($anchors).Count -lt 2) { return $null }
  # 앵커 간 간격 일관성 검사 (정렬 후 인접 쌍 전부)
  $sorted = @($anchors | Sort-Object { [int]$_.Index })
  for ($pairIndex = 1; $pairIndex -lt @($sorted).Count; $pairIndex++) {
    $indexGap = [int]$sorted[$pairIndex].Index - [int]$sorted[$pairIndex - 1].Index
    if ($indexGap -le 0) { return $null }
    $expectedY = [int]$sorted[$pairIndex - 1].Y + ($indexGap * $RowGap)
    if ([Math]::Abs([int]$sorted[$pairIndex].Y - $expectedY) -gt 12) { return $null }
  }
  # 목표와 가장 가까운 앵커 기준으로 환산 (누적 오차 최소화)
  $nearest = $sorted[0]
  foreach ($anchor in $sorted) {
    if ([Math]::Abs([int]$anchor.Index - $targetIndex) -lt [Math]::Abs([int]$nearest.Index - $targetIndex)) { $nearest = $anchor }
  }
  $estimatedY = [int]$nearest.Y + (($targetIndex - [int]$nearest.Index) * $RowGap)
  if ($estimatedY -lt $TopY -or $estimatedY -gt $BottomY) { return $null }
  # 앵커 수를 함께 돌려줍니다 - 3개 이상이면 위치 신뢰도가 높아 '상세 제목이 안 읽혀도'
  # 진행할 근거가 됩니다 (2026-08-06 라운드 6: 1글자 '물'은 제목·본문 어느 쪽으로도
  # 검증이 불가능해, 격자 신뢰도 외에는 통과시킬 방법이 없음)
  return @{ Y = $estimatedY; AnchorCount = @($sorted).Count }
}

function Find-LifeTargetScan {
  # 탐색 스텝 1회의 판독: s4→s5 로 대상 행을 찾고, 행 증거/끝 판정용 rows 도 같은 판독으로
  # 반환합니다. 반환: @{ Y = 행 Y 또는 $null; Rows = 첫 판독 성공 스케일의 행 배열 }.
  # (기존 s4→s5→s3 + 별도 증거 판독 = 스텝당 OCR 4회가 스크롤 탐색을 느리게 함 -
  #  2026-08-06 사용자 요청으로 2회로 축소. s3 전용 이형은 '나부' 공통 치환 규칙과 이형
  #  맵이 커버 - 실측상 s3 는 보조였고 주력 판독은 s4/s5)
  # FreshList = 스킬 셀을 누른 직후(목록이 최상단으로 초기화된 상태)라는 뜻. 이때만
  # '순서 x 간격' 위치 계산을 허용합니다 - 스크롤한 뒤에는 첫 행 기준이 맞지 않습니다
  param([System.Diagnostics.Process]$Game, [string]$TargetName, [string[]]$Order = @(), [switch]$FreshList)
  $visibleRows = @()
  foreach ($scanScale in @(4, 5)) {
    $scanRows = @(Get-LifeTargetRows -Game $Game -Scale $scanScale)
    if ($visibleRows.Count -eq 0 -and $scanRows.Count -gt 0) { $visibleRows = $scanRows }
    foreach ($row in $scanRows) {
      if (Test-LifeNameMatches -RowText ([string]$row.Text) -TargetName $TargetName) {
        return @{ Y = [int]$row.Y; Rows = $visibleRows; Source = 'text' }
      }
    }
  }
  # 직접 판독 실패 - 목록 순서 격자로 추론 (짧은 이름 보완. 앵커 2개+간격 일관 시에만).
  # 앵커 3개 이상은 'order-strong' - 상세 제목이 안 읽혀도 진행할 수 있는 신뢰도입니다
  if (@($Order).Count -gt 0 -and @($visibleRows).Count -gt 0) {
    $orderResult = Get-LifeTargetRowByOrder -Rows $visibleRows -Order $Order -TargetName $TargetName -RowGap $lifeListRowGap
    if ($null -ne $orderResult) {
      $orderSource = $(if ([int]$orderResult.AnchorCount -ge 3) { 'order-strong' } else { 'order' })
      return @{ Y = [int]$orderResult.Y; Rows = $visibleRows; Source = $orderSource }
    }
  }
  # 마지막 수단: 목록이 최상단인 게 확실할 때(스킬 셀 클릭 직후) '순서 x 간격'으로 계산.
  # 추수의 밀/콩/쌀처럼 1글자 대상은 목록·상세 어디서도 이름이 안 읽혀 이 경로가 유일합니다
  # 단, 캡처가 끊긴 상태에서는 쓰지 않습니다 - 판독이 전멸해도 이 폴백만은 행을 돌려주므로
  # '목록이 안 읽히는데 클릭은 나가는' 경로가 됩니다 (2026-08-07 감사 high: 실제로 판독
  # 2회 전멸 + CaptureFailing=true 인데 Y=574/Source=index 가 반환되는 것을 재현)
  if ($FreshList -and @($Order).Count -gt 0 -and -not $script:screenCaptureFailing) {
    for ($freshIndex = 0; $freshIndex -lt @($Order).Count; $freshIndex++) {
      if (-not (Test-LifeNameMatches -RowText ([string]$Order[$freshIndex]) -TargetName $TargetName)) { continue }
      $freshY = $lifeListFirstRowY + ($freshIndex * $lifeListRowGap)
      if ($freshY -ge 150 -and $freshY -le 680) {
        return @{ Y = [int]$freshY; Rows = $visibleRows; Source = 'index' }
      }
      break
    }
  }
  return @{ Y = $null; Rows = $visibleRows; Source = 'none' }
}

function Invoke-LifeListScroll {
  # 대상 목록 스크롤 (Steps>0 = 위쪽 항목 노출, <0 = 아래쪽 항목 노출).
  # **드래그 방식** - 2026-08-06 실측 실험: 휠(0x0800)은 이 목록에서 위 방향이 전혀 먹지
  # 않고 아래도 불안정해 '물'/'얽힌 거미줄' 같은 양 끝 대상을 못 찾던 원인이었습니다.
  # 같은 화면에서 드래그는 전 방향 확실히 동작(실험 05/06 캡처) → 드래그로 전환.
  # 게임 전면 + 커서 확인 후에만 입력하고, 실제 드래그 수행 여부를 반환합니다.
  param([System.Diagnostics.Process]$Game, [int]$Steps)
  if ($Steps -eq 0) { return $false }
  if (-not (Test-GameForeground -Game $Game)) {
    Focus-Game -Game $Game
    Start-Sleep -Milliseconds 400
    if (-not (Test-GameForeground -Game $Game)) {
      Write-RunLog '[생활] 목록 스크롤: 게임 전면화 실패로 건너뜀'
      return $false   # 다음 탐색 회차에서 재시도
    }
  }
  # 드래그 구간은 '항목 카드가 실제로 깔린 영역'만 사용합니다 (실측: 스킬 제목 178 /
  # 설명 212 / 경험치 바 288 / Lv 316 / 첫 항목 394~ - 2026-08-06 라운드 2 실사고:
  # 시작점 y230 이 설명 영역이라 드래그가 목록에 먹지 않아 최상단 이동이 전부 무효였음).
  # 방향: 아래 항목을 보려면 목록을 위로 끌어올림(FromY > ToY), 위쪽 항목은 반대.
  # 거리는 2행(180px)만 - 길게 끌면 관성으로 5~7행이 한 번에 넘어가 중간 대상을 건너뜁니다
  # (2026-08-06 라운드 3 실사고: 최상단(1~4행)에서 한 번 내렸더니 11~16행이 보임 →
  # '새록 버섯'(5번) 미발견). 짧게·천천히 끌어 관성을 최소화합니다.
  $dragCenterRefY = 520
  $dragHalf = $lifeListRowGap
  $fromRefY = $(if ($Steps -lt 0) { $dragCenterRefY + $dragHalf } else { $dragCenterRefY - $dragHalf })
  $toRefY = $(if ($Steps -lt 0) { $dragCenterRefY - $dragHalf } else { $dragCenterRefY + $dragHalf })
  $fromPoint = Get-ScaledScreenPoint -Game $Game -ReferenceX $ptLifeListCenter[0] -ReferenceY $fromRefY
  $toPoint = Get-ScaledScreenPoint -Game $Game -ReferenceX $ptLifeListCenter[0] -ReferenceY $toRefY
  # 시작 지점 커서 확인 (Click-ScreenPoint 와 같은 규칙 - 확인 실패 시 입력 금지)
  $cursorReady = $false
  foreach ($cursorTry in 1..2) {
    [HoneyNogiInput]::SetCursorPos([int]$fromPoint.X, [int]$fromPoint.Y) | Out-Null
    Start-Sleep -Milliseconds 80
    $cursorNow = New-Object HoneyNogiInput+POINT
    if ([HoneyNogiInput]::GetCursorPos([ref]$cursorNow) -and
        [Math]::Abs($cursorNow.X - [int]$fromPoint.X) -le 3 -and
        [Math]::Abs($cursorNow.Y - [int]$fromPoint.Y) -le 3) {
      $cursorReady = $true
      break
    }
  }
  if (-not $cursorReady) {
    Write-RunLog "[생활] 목록 스크롤: 커서를 시작 지점($([int]$fromPoint.X),$([int]$fromPoint.Y))으로 확인하지 못해 건너뜀"
    return $false
  }
  # 버튼을 누른 뒤에는 무슨 일이 있어도 떼야 합니다 (예외/중단으로 눌린 채 남으면 이후 모든
  # 입력이 드래그로 처리됨 - 리뷰 조건). 이동 성공 여부는 마지막 커서 위치로 확인합니다.
  $dragMoved = $false
  [HoneyNogiInput]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)   # 왼쪽 버튼 누름
  try {
    Start-Sleep -Milliseconds 150
    # 중간 단계 이동 - 한 번에 점프하면 게임이 드래그가 아닌 '클릭'으로 처리합니다.
    # 단계를 잘게(16회) 나누고 마지막에 잠깐 멈춰 '던지는' 제스처가 되지 않게 합니다(관성 억제)
    foreach ($moveStep in 1..16) {
      $stepX = [int]$fromPoint.X + [int](([int]$toPoint.X - [int]$fromPoint.X) * $moveStep / 16.0)
      $stepY = [int]$fromPoint.Y + [int](([int]$toPoint.Y - [int]$fromPoint.Y) * $moveStep / 16.0)
      [HoneyNogiInput]::SetCursorPos($stepX, $stepY) | Out-Null
      Start-Sleep -Milliseconds 45
    }
    Start-Sleep -Milliseconds 250     # 손을 멈춘 뒤 떼기 = 플링(관성) 방지
    # 실제로 목표까지 이동했는지 확인 - 커서가 안 움직였으면 같은 자리 down/up = 항목 클릭
    $cursorEnd = New-Object HoneyNogiInput+POINT
    if ([HoneyNogiInput]::GetCursorPos([ref]$cursorEnd) -and
        [Math]::Abs($cursorEnd.Y - [int]$toPoint.Y) -le 6 -and
        [Math]::Abs($cursorEnd.Y - [int]$fromPoint.Y) -ge 40) {
      $dragMoved = $true
    }
  } finally {
    [HoneyNogiInput]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)   # 버튼 뗌 (항상)
  }
  if (-not $dragMoved) {
    Write-RunLog '[생활] 목록 스크롤: 커서 이동을 확인하지 못했습니다 - 이번 스크롤은 무효로 처리'
    Start-Sleep -Milliseconds 400
    return $false
  }
  # 관성 스크롤이 멎기 전에 판독하면 중간 상태를 읽습니다
  Start-Sleep -Milliseconds 900
  return $true
}

function Test-LifeQuestFragments {
  # 채집 퀘스트 문구 판정 (순수 - 진리표 대상): '채집 장소 탐색 - {대상} 채집 N/10'.
  # 세 조각(채집/장소/탐색) 중 2개 이상이면 present 로 봅니다 - 한 조각이 깨져도(실측:
  # '탐색'→'탐"', '장소'→'잠소') 놓치지 않기 위함 (2026-08-07 사용자 지적: '탐색'은
  # 채집 퀘스트 공통 단어). 주간 목표 등 다른 줄에는 이 조합이 없어 오탐이 없습니다.
  param([string]$QuestText)
  $normalized = ([string]$QuestText) -replace '\s', ''
  $hits = 0
  foreach ($piece in @('채집', '장소', '탐색')) {
    if ($normalized.Contains($piece)) { $hits++ }
  }
  return ($hits -ge 2)
}

function Get-LifeQuestState {
  # 채집 퀘스트 상태 (설계 합의 4상태 축약): 'present' / 'absent' / 'unknown'.
  # 판독은 좁은 영역(첫 줄) → 없으면 넓은 영역(우측 퀘스트 목록 전체) 순서로 두 번 봅니다 -
  # 획득 알림/경험치 배지가 첫 줄을 덮거나 퀘스트가 아래로 밀리면 좁은 영역만으로는
  # '없음'이 되어 채집 중에 완료로 오판합니다 (2026-08-07 실사고).
  # absent 는 HUD 가 보이는 확정 상태에서만. 그 외 전부 unknown (부재 오판 방지)
  param([System.Diagnostics.Process]$Game)
  if ($script:screenCaptureFailing) { return 'unknown' }
  # ① 먼저 그냥 읽습니다 - 퀘스트 조각이 보이면 게임 화면이라는 증거이므로 전면화가
  #    필요 없습니다 (전면화는 사용자 조작을 방해하니 꼭 필요할 때만 - 사용자 지시)
  if (Test-LifeQuestFragments -QuestText (Get-GameRegionOcrText -Game $Game `
      -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
      -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine)) { return 'present' }
  if (Test-LifeQuestFragments -QuestText (Get-GameRegionOcrText -Game $Game `
      -ReferenceX $rgLifeQuestWide[0] -ReferenceY $rgLifeQuestWide[1] `
      -RegionWidth $rgLifeQuestWide[2] -RegionHeight $rgLifeQuestWide[3] -Scale 3 -Engine $ocrKoreanEngine)) { return 'present' }
  # ② 안 읽혔을 때만 '다른 창이 가린 건 아닌지' 확인합니다 - 전면화 후 한 번 더 읽고,
  #    전면화조차 안 되면 판단을 포기합니다(unknown - 부재로 세지 않음. 2026-08-07 실사고:
  #    개발 창이 게임을 덮은 채 그 글자를 읽고 '퀘스트 없음'으로 완료 오판)
  if (-not (Test-GameForeground -Game $Game)) {
    Focus-Game -Game $Game
    Start-Sleep -Milliseconds 700
    if (-not (Test-GameForeground -Game $Game)) { return 'unknown' }
    if (Test-LifeQuestFragments -QuestText (Get-GameRegionOcrText -Game $Game `
        -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
        -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine)) { return 'present' }
    if (Test-LifeQuestFragments -QuestText (Get-GameRegionOcrText -Game $Game `
        -ReferenceX $rgLifeQuestWide[0] -ReferenceY $rgLifeQuestWide[1] `
        -RegionWidth $rgLifeQuestWide[2] -RegionHeight $rgLifeQuestWide[3] -Scale 3 -Engine $ocrKoreanEngine)) { return 'present' }
  }
  # ③ 게임 화면이 확실한데도 퀘스트가 없을 때만 absent (게임플레이 HUD 가 증거)
  if (Test-HomeEndEscHud -Game $Game) { return 'absent' }
  return 'unknown'
}

function Get-LifeQuestCountText {
  # 로그 표시용 N/10 (상태 전이에는 사용하지 않음 - 사용자 합의)
  param([System.Diagnostics.Process]$Game)
  $questText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
      -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine)
  $countMatch = [regex]::Match([string]$questText, '(\d+)\s*/\s*(\d+)')
  if ($countMatch.Success) { return ('{0}/{1}' -f $countMatch.Groups[1].Value, $countMatch.Groups[2].Value) }
  return ''
}

function Press-LifeMenuKey {
  # C 키 strict 입력 (리뷰 조건 + 사용자 합의): 전면화 → 전면 '확인' 후에만 입력.
  # 기존 Press-KeyOnce 는 전역 입력이라 게임이 전면이 아니면 엉뚱한 곳에 들어감 - 확인 필수
  param([System.Diagnostics.Process]$Game)
  foreach ($focusTry in 1..3) {
    Focus-Game -Game $Game
    Start-Sleep -Milliseconds 400
    if (Test-GameForeground -Game $Game) {
      Press-KeyOnce -VirtualKey ([byte]0x43)   # C
      return $true
    }
    Start-Sleep -Milliseconds 800
  }
  Write-RunLog '[경고] 게임 창을 전면으로 만들지 못해 C 키 입력을 건너뜁니다 - 잠시 후 재시도'
  return $false
}

function Test-LifeWindowClosePixels {
  # 생활 창(내 정보/생활 스킬 - 공통 우상단 X) 열림 판정식 (순수 - 진리표 대상).
  # 주의: 이 4점 판정은 **기준 크기(1272x717) 창에서만 신뢰할 수 있습니다.** 창이 크면
  # 제목줄 비비례 때문에 화면 최상단 좌표가 아래로 밀려 X 두 획 사이 틈을 읽습니다
  # (2026-08-08 hyodong 제보). 지금은 Test-LifeWindowOpen 의 **폴백**으로만 쓰이고
  # 1순위는 창 크기에 무관한 Find-LifeCloseGlyph 입니다.
  # X 교차점 2점은 흰색(min 200+, 실측 249~255), 좌우 여백은 '교차점보다 100 이상 어두움'
  # (상대 대비). 절대 임계(max 80)는 2차 실기에서 오판 - 미선택 생활 스킬 창은 배경이
  # 반투명이라 뒤 필드가 비쳐 여백이 G103 까지 올라감 (22:51:46 실측 R49G96/R52G103.
  # 필드 화면은 교차점부터 어긋나(4번 캡처 min R35) 상대 대비에서도 탈락 - 6장 재검증).
  param($CrossA, $CrossB, $SideA, $SideB)
  $crossMin = [Math]::Min(
    [Math]::Min([Math]::Min([int]$CrossA.R, [int]$CrossA.G), [int]$CrossA.B),
    [Math]::Min([Math]::Min([int]$CrossB.R, [int]$CrossB.G), [int]$CrossB.B))
  if ($crossMin -lt 200) { return $false }
  $sideMax = [Math]::Max(
    [Math]::Max([Math]::Max([int]$SideA.R, [int]$SideA.G), [int]$SideA.B),
    [Math]::Max([Math]::Max([int]$SideB.R, [int]$SideB.G), [int]$SideB.B))
  return ($sideMax -le ($crossMin - 100))
}

# ── 우상단 닫기 X '글리프 서명' 탐색 (2026-08-08 hyodong 제보로 신설) ──
# 고정 4점 판정은 **창 크기가 기준(1272x717)과 다르면 죽습니다.** 기준 좌표계가 제목줄을
# 포함하는데 제목줄 높이는 창 크기에 비례하지 않아(실측: 개발/제보 PC 31px, 다른 제보 PC
# 38px - PC마다 다름), 화면 최상단일수록 세로 오차가 커지기 때문입니다. 1908 창에서 4점은
# X 글리프 경계 안이지만 **두 획 사이의 검은 틈**에 떨어져 항상 false 였습니다.
# 그래서 '어디를 보느냐(고정 Y)'가 아니라 '무엇이 보이느냐(X 두 대각선의 교차)'로 바꿉니다.
# 좌표 보정이 아니라 형태 탐색이라 제목줄 높이·창 크기·저장 좌표의 ±2px 오차에 전부 면역입니다.
$rgLifeCloseGlyph = @(1196, 30, 64, 56)   # 우상단 닫기 X 주변 (기준 좌표계. 1272·1908 실측 글리프를 모두 포함하는 폭)

function Find-LifeCloseGlyph {
  # 밝기 배열에서 'X 자 교차' 서명을 찾습니다 (순수 - 진리표 대상).
  # 서명: 중심이 밝고 / 네 대각선 방향이 밝고 / 네 축(상하좌우) 방향이 어둡다.
  #   - 가로막대·세로막대·십자(+)·균일한 밝은 면은 축 검사에서 탈락합니다.
  #   - 팔 길이를 여러 개 보고 과반을 요구해 안티앨리어싱 한 칸에 좌우되지 않게 합니다.
  # 입력은 [int[][]] 밝기(0~255) 행 배열 - Drawing 없이 진리표를 돌리기 위함입니다.
  # 반환: @{ Found; X; Y; Score } (X/Y 는 배열 안 좌표. 못 찾으면 Found=$false)
  #
  # 축의 '어두움'은 **절대 임계가 아니라 중심과의 상대 대비**로 봅니다 (2026-08-09 제보).
  # 처음엔 절대 임계(110)를 썼는데, 생활 스킬 창의 **파란 배경(밝기 약 136)** 위에서는
  # X 가 또렷한데도 축이 '어둡지 않다'로 걸려 창을 통째로 못 봤습니다 - 어제 제보와 같은
  # 고착(창 열림 미감지 → C 무시 → 재시도 소진)으로 이어지는 경로입니다.
  # 상대 대비는 배경이 밝든 어둡든 'X 획과 그 사이 빈틈의 명암차'라는 성질만 보므로
  # 배경색에 영향받지 않습니다 (형제 함수 Test-LifeWindowClosePixels 의 상대 대비와 같은 결).
  param([int[][]]$Luma, [int]$BrightMin = 170, [int]$MinContrast = 90, [int[]]$Arms = @(6, 8, 10))
  $rows = @($Luma).Count
  if ($rows -lt 1) { return @{ Found = $false; X = -1; Y = -1; Score = 0 } }
  $cols = @($Luma[0]).Count
  $maxArm = 0
  foreach ($arm in $Arms) { if ($arm -gt $maxArm) { $maxArm = $arm } }
  if ($rows -le (2 * $maxArm) -or $cols -le (2 * $maxArm)) { return @{ Found = $false; X = -1; Y = -1; Score = 0 } }
  $bestScore = 0; $bestX = -1; $bestY = -1
  for ($y = $maxArm; $y -lt ($rows - $maxArm); $y++) {
    for ($x = $maxArm; $x -lt ($cols - $maxArm); $x++) {
      $center = $Luma[$y][$x]
      if ($center -lt $BrightMin) { continue }
      $darkCeiling = $center - $MinContrast   # 축은 중심보다 이만큼은 어두워야 함
      $armHits = 0
      foreach ($arm in $Arms) {
        # 네 대각선이 전부 밝고, 네 축이 전부 '중심보다 충분히 어두워야' 이 팔이 통과합니다
        if ($Luma[$y - $arm][$x - $arm] -lt $BrightMin) { continue }
        if ($Luma[$y - $arm][$x + $arm] -lt $BrightMin) { continue }
        if ($Luma[$y + $arm][$x - $arm] -lt $BrightMin) { continue }
        if ($Luma[$y + $arm][$x + $arm] -lt $BrightMin) { continue }
        if ($Luma[$y - $arm][$x] -gt $darkCeiling) { continue }
        if ($Luma[$y + $arm][$x] -gt $darkCeiling) { continue }
        if ($Luma[$y][$x - $arm] -gt $darkCeiling) { continue }
        if ($Luma[$y][$x + $arm] -gt $darkCeiling) { continue }
        $armHits++
      }
      # 과반(3개 중 2개 이상) 통과만 인정 - 한 칸짜리 얼룩으로 열리지 않게
      if ($armHits -ge 2 -and $armHits -gt $bestScore) {
        $bestScore = $armHits; $bestX = $x; $bestY = $y
      }
    }
  }
  return @{ Found = ($bestScore -ge 2); X = $bestX; Y = $bestY; Score = $bestScore }
}

function Get-LifeCloseGlyphHit {
  # 우상단 ROI 를 **기준 단위(Scale 1)** 로 캡처해 X 글리프를 찾습니다.
  # Scale 1 이라 반환 비트맵이 창 크기와 무관하게 항상 ROI 의 기준 크기(64x56)입니다
  # - 판정식에서 창 크기가 사라지는 것이 이 설계의 핵심입니다.
  # 반환: @{ Found; ReferenceX; ReferenceY } (찾으면 클릭에 그대로 쓸 기준 좌표)
  param([System.Diagnostics.Process]$Game)
  $miss = @{ Found = $false; ReferenceX = 0; ReferenceY = 0 }
  if ($script:screenCaptureFailing) { return $miss }
  # Get-GamePixel 의 원시 CopyFromScreen 과 달리 이 경로는 빈 프레임 판정과
  # Register-CaptureFailure/Success 가 들어 있어 캡처 끊김을 '창 닫힘'으로 오인하지 않습니다
  $capture = Get-GameRegionCapture -Game $Game -ReferenceX $rgLifeCloseGlyph[0] -ReferenceY $rgLifeCloseGlyph[1] `
    -RegionWidth $rgLifeCloseGlyph[2] -RegionHeight $rgLifeCloseGlyph[3] -Scale 1
  if (-not $capture) { return $miss }
  try {
    $bitmap = $capture.Bitmap
    $height = $bitmap.Height
    $width = $bitmap.Width
    $luma = New-Object 'int[][]' $height
    for ($y = 0; $y -lt $height; $y++) {
      $row = New-Object 'int[]' $width
      for ($x = 0; $x -lt $width; $x++) {
        $color = $bitmap.GetPixel($x, $y)
        $row[$x] = [int](([int]$color.R + [int]$color.G + [int]$color.B) / 3)
      }
      $luma[$y] = $row
    }
  } finally {
    if ($capture.Bitmap) { $capture.Bitmap.Dispose() }
  }
  $hit = Find-LifeCloseGlyph -Luma $luma
  if (-not $hit.Found) { return $miss }
  return @{
    Found      = $true
    ReferenceX = ($rgLifeCloseGlyph[0] + [int]$hit.X)
    ReferenceY = ($rgLifeCloseGlyph[1] + [int]$hit.Y)
  }
}

function Test-LifeWindowOpen {
  # 내 정보/생활 스킬 창이 열려 있는지 판정합니다 (두 화면 공통인 우상단 닫기 X 로).
  # 1순위는 글리프 서명 탐색(창 크기 무관), 2순위는 기존 고정 4점 판정입니다.
  # 4점 판정을 남겨 두는 이유: 기준 크기(1272x717) 창에서 지금까지의 동작을 그대로 보존하기
  # 위함입니다 (둘 중 하나만 통과해도 열림 - 1272 실측 캡처 전수 동일 판정 확인).
  # 찾은 글리프 중심은 $script:lifeCloseGlyphHit 에 남겨 '닫기 클릭'이 같은 좌표를 쓰게 합니다
  # - 탐지와 클릭이 같은 환산을 왕복해야 '판정은 고쳤는데 클릭이 빗나가는' 다음 사고를 막습니다.
  param([System.Diagnostics.Process]$Game)
  if ($script:screenCaptureFailing) { return $false }
  $glyphHit = Get-LifeCloseGlyphHit -Game $Game
  if ($glyphHit.Found) {
    $script:lifeCloseGlyphHit = $glyphHit
    return $true
  }
  try {
    $crossA = Get-GamePixel -Game $Game -ReferenceX 1227 -ReferenceY 65
    $crossB = Get-GamePixel -Game $Game -ReferenceX 1228 -ReferenceY 67
    $sideA = Get-GamePixel -Game $Game -ReferenceX 1210 -ReferenceY 65
    $sideB = Get-GamePixel -Game $Game -ReferenceX 1245 -ReferenceY 65
  } catch { return $false }
  $pixelVerdict = Test-LifeWindowClosePixels -CrossA $crossA -CrossB $crossB -SideA $sideA -SideB $sideB
  if (-not $pixelVerdict) { $script:lifeCloseGlyphHit = $null }
  return $pixelVerdict
}

function Format-LifeMissingItemNotice {
  # 준비물 부족 팝업에서 읽은 품목을 안내 조각으로 만듭니다 (순수 - 진리표 대상).
  # 2026-08-07 실측: 곤충 채집 도구가 떨어지자 '입문용 곤충 채집망 0 / 1' 팝업이 떴는데
  # 안내는 고정 문구 '(빈 병 등)' 이라 무엇을 사야 하는지 알 수 없었습니다. 품목은 스킬마다
  # 다르므로(빈 병 / 채집망 …) 팝업이 적어 준 이름을 그대로 옮깁니다.
  # 수량 표기(0/1)만 남거나 판독이 비면 조각을 만들지 않습니다 - 틀린 이름을 적느니 생략.
  param([string]$ItemText)
  $collapsed = (([string]$ItemText) -replace '\s+', ' ').Trim()
  if (-not $collapsed) { return '' }
  $nameOnly = ($collapsed -replace '\d+\s*/\s*\d+', '').Trim()
  if ($nameOnly.Length -lt 2) { return '' }
  return " (필요: $nameOnly)"
}

function Close-LifeBlockingDialog {
  # 생활 흐름을 막는 모달 대화상자 처리 (2026-08-06 전수 배치 실측):
  #  ① '퀘스트를 위해 필요한 아이템이 없습니다' - 준비물 부족. 빈 병(물/우물/젖소)뿐 아니라
  #     채집 도구 소진도 여기로 옵니다 (2026-08-07 실측: '입문용 곤충 채집망 0/1').
  #     채집 자체가 불가하므로 닫고 'material' 을 돌려 호출부가 조건부 정지하게 합니다.
  #     닫기 전에 품목 줄을 읽어 두어 무엇이 필요한지 로그에 남깁니다.
  #  ② '사냥터 퇴장 실패' 등 일반 오류 팝업 - 확인만 눌러 정리('closed').
  #     이 팝업이 남으면 C 키가 먹지 않아 이후 회차까지 연쇄 실패합니다 (mining 5연속 실측).
  #  ③ '게임 서버와 연결이 끊어졌습니다(ERROR 83)' - 재접속 전에는 무엇도 진행 불가.
  #     'disconnected' 를 돌려 즉시 정지시킵니다 (2026-08-06 라운드 4 실측: 끊긴 채
  #     3회차가 각 600초를 낭비하고 '가방 가득'으로 오인될 뻔함)
  # 반환: 'disconnected' / 'material' / 'closed' / 'none'
  param([System.Diagnostics.Process]$Game)
  if ($script:screenCaptureFailing) { return 'none' }
  # 판정은 팝업 본문이 있는 '중앙 한 영역'만 씁니다 - 서로 다른 위치의 낱말을 이어붙이면
  # 정상 화면의 '실패'/'연결' 같은 단어가 조합돼 오판합니다 (리뷰 조건)
  $dialogText = (Get-GameRegionOcrText -Game $Game -ReferenceX 380 -ReferenceY 300 `
      -RegionWidth 520 -RegionHeight 200 -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if (-not $dialogText) { return 'none' }
  # 강한 조합만 인정 (단일 낱말 금지)
  $isDisconnected = ($dialogText.Contains('서버와연결') -or $dialogText.Contains('연결이끊') -or
    $dialogText.Contains('다시접속') -or $dialogText.Contains('ERROR83'))
  $isMaterialShortage = ($dialogText.Contains('아이템이없습니다') -or
    ($dialogText.Contains('필요한아이템') -and $dialogText.Contains('없습니다')))
  $isErrorDialog = (($dialogText.Contains('오류가발생') -and $dialogText.Contains('습니다')) -or
    $dialogText.Contains('Blocked') -or $dialogText.Contains('퇴장실패') -or $dialogText.Contains('입장실패'))
  if ($isDisconnected) {
    Write-RunLog "[생활] 게임 서버 연결이 끊어졌습니다 (판독 '$dialogText') - 재접속이 필요합니다"
    return 'disconnected'
  }
  if (-not $isMaterialShortage -and -not $isErrorDialog) { return 'none' }
  # 준비물 부족이면 팝업을 닫기 전에 품목 줄을 읽어 둡니다 (닫은 뒤에는 사라짐).
  # 실측 좌표: 본문 아래 아이템 상자 x418~855 / y445~494 ('입문용 곤충 채집망  0 / 1')
  if ($isMaterialShortage) {
    $script:lifeMissingItemText = Get-GameRegionOcrText -Game $Game -ReferenceX 418 -ReferenceY 445 `
      -RegionWidth 440 -RegionHeight 50 -Scale 4 -Engine $ocrKoreanEngine
  }
  # 닫기 버튼은 팝업 종류에 따라 다릅니다 (실측: 준비물 부족 = '취소' y623 / 오류 팝업 =
  # '확인' y618). **하단 버튼 밴드에서만** 찾고, 못 찾으면 클릭하지 않습니다 - 본문에 있는
  # '확인' 같은 낱말이나 고정 좌표를 누르면 엉뚱한 조작이 됩니다 (리뷰 조건)
  $buttonBand = @(400, 560, 480, 120)
  $closePoint = $null
  foreach ($buttonText in @('취소', '확인')) {
    $closePoint = Find-GameTextPoint -Game $Game -ReferenceX $buttonBand[0] -ReferenceY $buttonBand[1] `
        -RegionWidth $buttonBand[2] -RegionHeight $buttonBand[3] -SearchText $buttonText -ExactText $buttonText
    if ($closePoint) { break }
  }
  Focus-Game -Game $Game
  if ($closePoint) {
    Click-ScreenPoint -X $closePoint.X -Y $closePoint.Y
  } else {
    # 팝업 자체가 강한 조합으로 확정된 상태에서만 실측 예비 좌표를 씁니다 (버튼 글자가
    # 초록 배경에서 안 읽히는 실측 - 2026-08-06 라운드 6: '사냥터 퇴장 실패'가 닫히지
    # 않아 5연속 실패). 아래 '닫힘 확인'이 오클릭을 걸러 냅니다.
    Write-RunLog "[생활] 닫기 버튼 글자를 못 읽어 실측 좌표로 닫기를 시도합니다 (판독 '$dialogText')"
    Click-GamePoint -Game $Game -ReferenceX 636 -ReferenceY 618
  }
  Start-Sleep -Seconds 2
  if ($isMaterialShortage) {
    Write-RunLog "[생활] 준비물 부족 팝업 감지 - 닫았습니다$(Format-LifeMissingItemNotice -ItemText ([string]$script:lifeMissingItemText))"
    return 'material'
  }
  # 오류 팝업은 '실제로 사라졌는지' 확인한 뒤에만 처리됐다고 봅니다 (리뷰 조건).
  # 안 닫혔으면 남은 예비 버튼 위치로 한 번 더 시도합니다 (확인/취소 위치가 팝업마다 다름)
  $afterText = (Get-GameRegionOcrText -Game $Game -ReferenceX 380 -ReferenceY 300 `
      -RegionWidth 520 -RegionHeight 200 -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if ($afterText -eq $dialogText) {
    Click-GamePoint -Game $Game -ReferenceX 636 -ReferenceY 453
    Start-Sleep -Seconds 2
    $afterText = (Get-GameRegionOcrText -Game $Game -ReferenceX 380 -ReferenceY 300 `
        -RegionWidth 520 -RegionHeight 200 -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  }
  if ($afterText -eq $dialogText) {
    Write-RunLog "[생활] 팝업이 닫히지 않았습니다 (판독 '$afterText') - 다음 회차에서 재시도"
    return 'none'
  }
  Write-RunLog "[생활] 진행을 막는 팝업 감지 - 닫았습니다 (판독 '$dialogText')"
  return 'closed'
}

function Write-LifeDiagnostics {
  # 생활 흐름 실패 지점의 원인 분석용 진단 세트 (조건부 정지 코드 4는 오류 catch 를 타지
  # 않아 캡처가 없음 - 던전 Write-DgStageDiagnostics 와 같은 2026-07-22 교훈. 1차 실기
  # 22:45 실패도 캡처 부재로 원인 미확정 → 신설). 스크린샷은 error_* 명명/보관 정책 공유.
  param([System.Diagnostics.Process]$Game, [string]$Context)
  try {
    $diagStamp = Get-Date -Format 'yyyyMMdd_\hHH\mmm\sss'
    if ($Game) {
      $diagRect = New-Object HoneyNogiInput+RECT
      if ([HoneyNogiInput]::GetWindowRect($Game.MainWindowHandle, [ref]$diagRect)) {
        $diagW = $diagRect.Right - $diagRect.Left
        $diagH = $diagRect.Bottom - $diagRect.Top
        if ($diagW -gt 0 -and $diagH -gt 0) {
          $diagShot = Join-Path $logDir "error_$diagStamp.png"
          $diagBmp = New-Object System.Drawing.Bitmap $diagW, $diagH
          $diagGfx = [System.Drawing.Graphics]::FromImage($diagBmp)
          try {
            $diagGfx.CopyFromScreen($diagRect.Left, $diagRect.Top, 0, 0, $diagBmp.Size)
            $diagBmp.Save($diagShot, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-RunLog "[진단] $Context - 화면 캡처 저장: $diagShot"
          } finally {
            $diagGfx.Dispose()
            $diagBmp.Dispose()
          }
          $keepShots = Get-ConfigInteger $config @('diagnostics', 'keepScreenshots') 10 0 1000
          if ($keepShots -gt 0) {
            $oldShots = @(Get-ChildItem -LiteralPath $logDir -Filter 'error_*.png' -File -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -Skip $keepShots)
            foreach ($old in $oldShots) {
              Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
            }
          }
        }
      }
    }
    # 생활 판정 재료 덤프: 창 상태 + 대상 목록 행 + 상세 영역 판독문 (분석 시 캡처와 대조)
    $diagRows = @(Get-LifeTargetRows -Game $Game -Scale 4)
    $rowDump = (@($diagRows | ForEach-Object { "$($_.Text)@$($_.Y)" }) -join ' | ')
    Write-RunLog "[진단] $Context - 창픽셀=$(Test-LifeWindowOpen -Game $Game) 내정보=$(Test-LifeInfoScreen -Game $Game) 목록행: $rowDump"
    $diagDetail = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgLifeDetail[0] -ReferenceY $rgLifeDetail[1] `
        -RegionWidth $rgLifeDetail[2] -RegionHeight $rgLifeDetail[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
    Write-RunLog "[진단] $Context - 상세 영역 판독: '$diagDetail'"
  } catch {
    Write-RunLog "[진단] 진단 수집 실패: $($_.Exception.Message)"
  }
}

function Close-LifeOpenWindows {
  # 시작 상태 복구 (멱등 - 리뷰 조건): 상세 팝업이 열려 있으면 확인으로, 내 정보/생활
  # 스킬 창이 열려 있으면(X 픽셀 판별 + 내정보 OCR 보조) X 로 닫습니다. 뭘 닫았으면 $true.
  # X 클릭 후 실제로 닫혔는지 재확인하고 안 닫혔으면 1회 재클릭합니다 (1차 실기 22:45:25
  # 재현: X 닫기 미확인 상태로 넘어가 다음 C 토글이 남은 창을 닫으며 재시도 1회 소실)
  param([System.Diagnostics.Process]$Game)
  $closed = $false
  $detailText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgLifeDetail[0] -ReferenceY $rgLifeDetail[1] `
      -RegionWidth $rgLifeDetail[2] -RegionHeight $rgLifeDetail[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
  if (Test-LifeDetailHasLabel -Text $detailText) {
    # '집물' = '채집물'의 안정 조각 (2차 실기: '채'가 '자|'로 깨져 팝업을 못 알아보고
    # X 를 눌러 모달에 막히던 사고 - 팝업은 반드시 '확인'으로 먼저 닫아야 함)
    Focus-Game -Game $Game
    Click-GamePoint -Game $Game -ReferenceX $ptLifeDetailConfirm[0] -ReferenceY $ptLifeDetailConfirm[1]
    Write-RunLog '[생활] 시작 정리: 대상 상세 팝업 확인 클릭'
    Start-Sleep -Seconds 1
    $closed = $true
  }
  foreach ($closeTry in 1..2) {
    if (-not ((Test-LifeWindowOpen -Game $Game) -or (Test-LifeInfoScreen -Game $Game))) { break }
    Focus-Game -Game $Game
    Invoke-LifeWindowCloseClick -Game $Game
    Write-RunLog "[생활] 시작 정리: 정보/스킬 창 닫기(X) - $closeTry 회차"
    Start-Sleep -Milliseconds 1200
    $closed = $true
  }
  if ((Test-LifeWindowOpen -Game $Game) -or (Test-LifeInfoScreen -Game $Game)) {
    Write-RunLog '[생활] 경고: 창 닫기 2회 후에도 창이 남아 있습니다 (다음 단계에서 재처리)'
  }
  return $closed
}

function Invoke-LifeMenuSequence {
  # 메뉴 사이클 1회: C → 내 정보 확인 → 생활 스킬 → 스킬 셀 → 대상 행 → 상세 확인 →
  # 가까운 위치 찾기. 성공 $true / 실패 $false (호출부가 재시도).
  # Deadline = 사이클 하드 상한: 이 함수 한 번에 탐색 12회·OCR 수십 회가 들어 있어 내부
  # 검사 없이는 한도를 넘긴 뒤에도 클릭이 이어짐 (리뷰 지적 - 특히 초과 후 '가까운 위치
  # 찾기' 입력 금지). 주요 입력 전마다 검사하고 초과 시 $false (호출부 말미 검사가 exit 4)
  param([System.Diagnostics.Process]$Game, $SkillEntry, [string]$TargetName, [datetime]$Deadline)
  if ((Get-Date) -gt $Deadline) { return $false }
  # 다른 창이 게임을 덮고 있으면 판독·클릭이 전부 엉뚱한 곳으로 갑니다 (2026-08-07 실사고)
  if (-not (Confirm-LifeGameFront -Game $Game)) { Start-Sleep -Seconds 3; return $false }
  # 1) 내 정보 열기 (이미 열려 있으면 C 생략 - 토글 사고 방지).
  # 판독 '도중' 캡처가 끊기면 false 가 '안 열림'으로 오인돼 열린 창에 C 토글이 들어갈 수
  # 있으므로, 판독 후 캡처 플래그를 재확인해 무효 처리합니다 (리뷰 경계 재현)
  if ($script:screenCaptureFailing) { return $false }
  $infoAlreadyOpen = Test-LifeInfoScreen -Game $Game
  if ($script:screenCaptureFailing) { return $false }
  if (-not $infoAlreadyOpen) {
    # 내정보는 아니지만 생활 창(스킬창 등)이 남아 있으면 **C 가 먹지 않습니다**.
    # (2026-08-08 hyodong 제보 실측: 생활 스킬 창이 열린 채 C 를 두 번 눌렀는데 12초 동안
    #  화면이 픽셀 0.03% 만 달라진 정지 상태 - 즉 '닫는 토글'이 아니라 '무시'였습니다.
    #  이 구분이 중요합니다: 토글이면 다음 사이클에 자기 복구되지만, 무시면 X 로 닫아 주기
    #  전까지 영구 고착이라 재시도 3회가 그대로 소진됩니다.) → X 로 먼저 닫고 확인
    if (Test-LifeWindowOpen -Game $Game) {
      Focus-Game -Game $Game
      Invoke-LifeWindowCloseClick -Game $Game
      Write-RunLog '[생활] 잔존 창 감지 - X로 닫고 내 정보를 새로 엽니다'
      Start-Sleep -Milliseconds 1200
      # 닫힘을 확인하고 나서 C 를 누릅니다. 아직 열려 있는데 C 를 보내면 무시돼 재시도 1회를
      # 통째로 버립니다 (위 실측). 닫힘 확인 실패는 사이클 실패로 돌려 다음 회차가 다시
      # 시도하게 둡니다 - 여기서 억지로 C 를 눌러 봐야 같은 자리에서 소진될 뿐입니다.
      if (Test-LifeWindowOpen -Game $Game) {
        Write-RunLog '[생활] 창이 아직 닫히지 않아 C 입력을 보류합니다 - 재시도'
        Write-LifeDiagnostics -Game $Game -Context '창 닫기 확인 실패'
        return $false
      }
    }
    if (-not (Press-LifeMenuKey -Game $Game)) { return $false }
    $infoSeen = $false
    foreach ($infoTry in 1..5) {
      Start-Sleep -Milliseconds 900
      if (Test-LifeInfoScreen -Game $Game) { $infoSeen = $true; break }
    }
    if (-not $infoSeen) {
      Write-RunLog '[생활] 내 정보 화면이 열리지 않았습니다 - 재시도'
      Write-LifeDiagnostics -Game $Game -Context '내 정보 열림 실패'
      return $false
    }
  }
  Write-RunLog '[생활] 내 정보 화면 확인'
  # 2) 좌측 '생활 스킬' 메뉴 클릭 → 화면 전환 확인 (스킬 창은 좌측 메뉴가 없는 레이아웃이라
  #    '생활력' 신호 소멸 = 전환 증거. 전환 확인 전에는 다음 클릭 금지 - 클릭 정책/리뷰 조건)
  if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 메뉴 진행 중단'; return $false }
  Focus-Game -Game $Game
  Click-GamePoint -Game $Game -ReferenceX $ptLifeSkillMenu[0] -ReferenceY $ptLifeSkillMenu[1]
  $menuMoved = $false
  foreach ($moveTry in 1..4) {
    Start-Sleep -Milliseconds 900
    if ($script:screenCaptureFailing) { continue }
    $infoStillVisible = Test-LifeInfoScreen -Game $Game
    # 판독 도중 캡처가 끊기면 false 를 '전환됨'으로 인정하면 안 됩니다 (리뷰 경계 재현 -
    # 캡처 실패 중 다음 셀 클릭이 이어지는 사고). 이번 확인은 무효로 하고 다음 회차로.
    if ($script:screenCaptureFailing) { continue }
    if (-not $infoStillVisible) { $menuMoved = $true; break }
  }
  if (-not $menuMoved) {
    Write-RunLog "[생활] '생활 스킬' 화면 전환을 확인하지 못했습니다 - 재시도"
    Write-LifeDiagnostics -Game $Game -Context '생활 스킬 전환 실패'
    return $false
  }
  # 3) 스킬 셀 클릭 → 우측 대상 목록 내용으로 검증 (셀 라벨 OCR 은 판독 불가 실측).
  #    전환 확인 직후는 화면이 아직 그려지는 중일 수 있어(1차 실기 22:45:24 시그니처 실패
  #    의심 원인) 안정 대기 후 클릭하고, 검증도 3회 x 3스케일로 여유를 둡니다
  Start-Sleep -Milliseconds 800
  Focus-Game -Game $Game
  Click-GamePoint -Game $Game -ReferenceX ([int]$SkillEntry.Cell[0]) -ReferenceY ([int]$SkillEntry.Cell[1])
  Start-Sleep -Milliseconds 1200
  $skillVerified = $false
  foreach ($verifyTry in 1..3) {
    foreach ($sigScale in @(4, 5, 3)) {
      $listRows = @(Get-LifeTargetRows -Game $Game -Scale $sigScale)
      $joined = (($listRows | ForEach-Object { [string]$_.Text }) -join '')
      foreach ($sigPiece in @($SkillEntry.Sig)) {
        if ($joined.Contains([string]$sigPiece)) { $skillVerified = $true; break }
      }
      if ($skillVerified) { break }
    }
    if ($skillVerified) { break }
    Start-Sleep -Milliseconds 900
  }
  if (-not $skillVerified) {
    Write-RunLog "[생활] '$([string]$SkillEntry.Name)' 선택을 확인하지 못했습니다 (대상 목록 미검증) - 재시도"
    Write-LifeDiagnostics -Game $Game -Context '스킬 선택 검증 실패'
    return $false
  }
  Write-RunLog "[생활] 채집 스킬 '$([string]$SkillEntry.Name)' 선택 확인"
  # 4) 대상 행 탐색: 목록 맨 위로 스크롤 후, '목록 끝'에 닿을 때까지 아래로 단계 탐색.
  #    끝 판정 = 스크롤 전후 행 구성이 그대로 (GUI 실기 23:24 실사고: 나무 베기 목록이
  #    고정 4회 탐색 범위보다 길어 하단 대상 도달 전에 포기 → 회수 상한이 아니라 끝 도달로
  #    변경, 무한 방지 안전 상한 12회). 최상단 스크롤은 직전 시그니처 검증으로 목록 존재가
  #    확정된 상태에서만 보냅니다.
  $targetRowY = $null
  $targetRowSource = 'none'
  # 4-0) 지금 화면에 이미 대상이 보이면 스크롤 없이 바로 클릭합니다 (2026-08-06 사용자
  #      관찰: 상단에 있는 '거미줄'도 매번 최상단 정렬을 2회 하고 눌러 시간을 낭비).
  #      스킬 셀 클릭 직후 목록은 그 스킬의 첫 화면이라 상단 대상은 대개 여기서 잡힙니다.
  # 스킬 셀을 방금 눌러 목록이 최상단인 시점이라 순서 기반 위치 계산을 허용합니다.
  # 판독 전에 화면이 살아 있는지 확인합니다 - 캡처가 끊긴 채 이 판독을 하면 순서 폴백이
  # '보이지도 않는 행'을 돌려주고 그대로 클릭까지 갑니다 (2026-08-07 감사 high)
  if (-not (Wait-LifeCaptureAlive -Game $Game -Deadline $Deadline -Context '대상 빠른 확인')) { return $false }
  $quickScan = Find-LifeTargetScan -Game $Game -TargetName $TargetName -Order @($SkillEntry.Order) -FreshList
  if ($null -ne $quickScan.Y) {
    $targetRowY = [int]$quickScan.Y
    $targetRowSource = [string]$quickScan.Source
    Write-RunLog "[생활] '$TargetName' 이 현재 화면에 있어 스크롤 없이 선택합니다 (Y=$targetRowY, 근거 $targetRowSource)"
  }
  # 4-1) 못 찾았을 때만 목록 최상단으로 정렬 ('행 구성이 안 바뀔 때까지' - 전수 배치
  #      01:03 실사고: 이전 스크롤 위치가 남아 목록 상단의 '물'이 탐색 범위 밖이었음.
  #      아래로만 훑는 구조라 최상단 도달이 전제)
  $previousRowsKey = ''
  if ($null -eq $targetRowY) {
    # 정렬 전에 '이미 최상단인지' 먼저 판단합니다 - 목록 첫 항목(Order[0])이 보이면 위로
    # 갈 곳이 없으므로 드래그 0회 (2026-08-06 사용자 지적: 최상단에서도 확인 목적으로
    # 2번씩 끌던 낭비. 판독은 위 quickScan 결과를 재사용해 추가 OCR 도 없음)
    $topRows = @($quickScan.Rows)
    $topRowsKey = (($topRows | ForEach-Object { [string]$_.Text }) -join '|')
    $firstItemName = $(if (@($SkillEntry.Order).Count -gt 0) { [string]$SkillEntry.Order[0] } else { '' })
    $alreadyAtTop = $false
    if ($firstItemName) {
      foreach ($topRow in $topRows) {
        if (Test-LifeNameMatches -RowText ([string]$topRow.Text) -TargetName $firstItemName) { $alreadyAtTop = $true; break }
      }
    }
    if ($alreadyAtTop) {
      Write-RunLog "[생활] 목록이 이미 최상단입니다 - 정렬 생략 (판독: $topRowsKey)"
    } else {
      # 판독에 성공한 회차만 예산(12회)을 소모합니다 - 캡처 플래핑으로 회차가 깎이면
      # 화면이 멀쩡할 때도 정렬을 다 못 하고 넘어갑니다 (2026-08-07 리뷰 지적)
      $topTries = 0
      while ($topTries -lt 12) {
        # 최상단 정렬도 사이클 한도 안에서만 (드래그 1회 약 2초 - 12회면 한도를 넘길 수 있음)
        if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 목록 정렬 중단'; return $false }
        if (-not (Wait-LifeCaptureAlive -Game $Game -Deadline $Deadline -Context '목록 정렬')) { return $false }
        if (-not (Invoke-LifeListScroll -Game $Game -Steps 1)) { break }
        $topRows = @(Get-LifeTargetRows -Game $Game -Scale 4)
        # 캡처가 끊겨 0행이면 '목록이 사라진 것'이 아니라 화면이 안 그려진 것입니다 (2026-08-07 감사)
        if ($topRows.Count -eq 0 -and $script:screenCaptureFailing) { continue }
        $topTries++
        if ($topRows.Count -eq 0) { break }
        $currentTopKey = (($topRows | ForEach-Object { [string]$_.Text }) -join '|')
        # 첫 항목이 보이면 그 자리가 최상단 - 더 끌지 않습니다
        if ($firstItemName) {
          $reachedTop = $false
          foreach ($topRow in $topRows) {
            if (Test-LifeNameMatches -RowText ([string]$topRow.Text) -TargetName $firstItemName) { $reachedTop = $true; break }
          }
          if ($reachedTop) { $topRowsKey = $currentTopKey; break }
        }
        if ($currentTopKey -eq $topRowsKey) { break }
        $topRowsKey = $currentTopKey
      }
      Write-RunLog "[생활] 목록 최상단 정렬 완료 (판독: $topRowsKey)"
    }
    $lastScrollSent = $false
    # 여기도 판독에 성공한 회차만 예산을 소모합니다 (캡처 플래핑이 탐색 범위를 갉아먹지 않게)
    $scrollStep = -1
    while ($scrollStep -lt 11) {
      if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 대상 탐색 중단'; return $false }
      # 화면이 안 그려지는 동안에는 판독도 드래그도 하지 않습니다 - 0행 판독을 '목록 소멸'로,
      # 프리즈된 화면을 '끝까지 훑었다'로 오인하고 미발견 정지(exit 4)로 직행했습니다 (2026-08-07 감사)
      if (-not (Wait-LifeCaptureAlive -Game $Game -Deadline $Deadline -Context '대상 탐색')) { return $false }
      # 스텝당 판독 1벌(s4→s5): 대상 찾기 + 행 증거 + 끝 판정이 같은 결과를 공유합니다
      $scanResult = Find-LifeTargetScan -Game $Game -TargetName $TargetName -Order @($SkillEntry.Order)
      if ($null -ne $scanResult.Y) {
        $targetRowY = [int]$scanResult.Y
        $targetRowSource = [string]$scanResult.Source
        if ($targetRowSource -like 'order*') {
          Write-RunLog "[생활] '$TargetName' 행을 목록 순서로 추정했습니다 (Y=$targetRowY - 이름 판독 실패 보완)"
        }
        break
      }
      # 아래로 스크롤하기 전에 목록이 계속 보인다는 증거를 요구합니다 - 행이 하나도 안 읽히면
      # 목록 소멸/화면 전환/OCR 전멸을 구분할 수 없으므로 휠을 멈추고 미발견 처리로 넘깁니다
      # (리뷰 조건: 추가 입력은 원래 화면이 유지될 때만)
      $visibleRows = @($scanResult.Rows)
      if ($visibleRows.Count -eq 0 -and $script:screenCaptureFailing) {
        # 판독 도중 화면이 멈췄으면 목록 소멸의 증거가 아닙니다 - 예산을 쓰지 않고 다시 시도
        continue
      }
      $scrollStep++
      if ($visibleRows.Count -eq 0) {
        Write-RunLog '[생활] 대상 목록이 더 이상 읽히지 않습니다 - 탐색 중단'
        break
      }
      # 끝 판정은 '스크롤을 실제로 보냈는데도' 행 구성이 그대로일 때만 - 전면화/커서 확인
      # 실패로 건너뛴 회차의 동일 화면을 끝으로 오인하면 일시 문제가 미발견 정지가 됨 (리뷰)
      $rowsKey = (($visibleRows | ForEach-Object { [string]$_.Text }) -join '|')
      if ($lastScrollSent -and ($rowsKey -eq $previousRowsKey)) {
        Write-RunLog '[생활] 목록 끝까지 탐색했지만 대상을 찾지 못했습니다'
        break
      }
      $previousRowsKey = $rowsKey
      if ($scrollStep -eq 11) { break }   # 마지막 회차는 재탐색이 없으므로 스크롤도 보내지 않음
      # 판독(OCR)에 시간이 든 뒤이므로 실제 입력 직전에 한도를 다시 확인합니다 (리뷰 조건)
      if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 대상 탐색 중단'; return $false }
      $lastScrollSent = [bool](Invoke-LifeListScroll -Game $Game -Steps -1)
    }
  }
  if ($null -eq $targetRowY) {
    # 캡처가 끊긴 상태의 '못 찾음'은 목록에 없다는 증거가 아닙니다. 여기서 미발견으로 확정하면
    # 화면이 몇 초 뒤 돌아와도 자동화가 이미 멈춘 뒤입니다 (exit 4 = GUI 반복 전체 정지).
    # 호출부의 캡처 대기·재시도로 넘깁니다 (2026-08-07 감사 - 검은 화면 진단 캡처가 실제
    # 오류 캡처를 보관 10개에서 밀어내는 부작용도 함께 막습니다)
    if ($script:screenCaptureFailing) {
      Write-RunLog '[생활] 화면이 그려지지 않아 대상 목록을 확인하지 못했습니다 - 복구 후 재시도'
      return $false
    }
    Write-RunLog "[오류] 채집 대상 '$TargetName' 을 목록에서 찾지 못했습니다 - 미해금이거나 화면 인식 실패입니다."
    Write-LifeDiagnostics -Game $Game -Context '채집 대상 미발견'
    Write-RunLog '[완료] 채집 대상 미발견 - 조건부 정지'
    exit 4
  }
  if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 메뉴 진행 중단'; return $false }
  # 클릭 직전에는 **새로 한 번 떠 봐야** 합니다. $script:screenCaptureFailing 은 '마지막 캡처
  # 결과'라, 행을 읽은 직후 화면이 멈추면 플래그는 여전히 정상으로 남아 있어 그대로 클릭이
  # 나갑니다 (리뷰 지적 - 대기 함수는 플래그가 false 면 즉시 통과).
  # 멈춰 있으면 기다렸다 누르지 않고 되돌아갑니다 - 복구 뒤 목록이 그대로라는 보장이 없어
  # 행 Y 를 다시 읽는 편이 안전합니다 (호출부가 캡처 복구를 기다린 뒤 재시도).
  if (-not (Test-CaptureRecovered -Game $Game)) {
    Write-RunLog '[생활] 대상 행 클릭 직전에 화면이 멈췄습니다 - 목록을 다시 확인합니다'
    return $false
  }
  Focus-Game -Game $Game
  Click-GamePoint -Game $Game -ReferenceX $ptLifeListCenter[0] -ReferenceY $targetRowY
  Start-Sleep -Milliseconds 1200
  # 5) 상세 팝업 검증: 라벨('집물' 조각 - 실기 깨짐 대응) + 제목이 설정 대상과 일치해야 함
  #    ('채집물'은 모든 대상 공통 문구라 단독으로는 오클릭을 못 잡음 - 리뷰 지적.
  #    판정식은 Get-LifeDetailVerdict 순수 함수 - 실측 깨짐 '자|집물' 진리표 포함)
  $detailOk = $false
  foreach ($detailTry in 1..2) {
    # 판독은 s3 → s4 사다리: 같은 팝업이라도 스케일에 따라 깨짐이 달라(23:51 실기 - s3
    # '흰'→'혼!') 한 스케일의 깨짐으로 자기 팝업을 다른 대상으로 확정하지 않기 위함.
    # verdict 는 스케일별로 누적해 '두 스케일 모두 wrong'일 때만 오클릭 확정합니다
    # (마지막 스케일 판정만 남기면 스케일 순서에 따라 결과가 달라짐 - 리뷰 지적)
    $detailMatched = $false
    $detailWrongCount = 0
    $detailUnreadableCount = 0
    $detailText = ''
    foreach ($detailScale in @(3, 4)) {
      $detailText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgLifeDetail[0] -ReferenceY $rgLifeDetail[1] `
          -RegionWidth $rgLifeDetail[2] -RegionHeight $rgLifeDetail[3] -Scale $detailScale -Engine $ocrKoreanEngine) -replace '\s', ''
      $detailVerdict = Get-LifeDetailVerdict -DetailText $detailText -TargetName $TargetName `
        -Order @($SkillEntry.Order) -SkillName ([string]$SkillEntry.Name)
      if ($detailVerdict -eq 'match') { $detailMatched = $true; break }
      if ($detailVerdict -eq 'wrong-target') { $detailWrongCount++ }
      if ($detailVerdict -eq 'unreadable') { $detailUnreadableCount++ }
    }
    if ($detailMatched) { $detailOk = $true; break }
    if ($detailWrongCount -ge 2) {
      # 두 스케일 모두 '정상 판독인데 다른 대상' = 오클릭 확정 (호출부가 정리 후 재시도)
      Write-RunLog "[생활] 다른 대상의 상세 팝업입니다 (판독 '$detailText', 목표 '$TargetName') - 재시도"
      return $false
    }
    if ($detailUnreadableCount -ge 2) {
      # 제목이 깨져 판단 불가. 행을 '이름 정확 판독'으로 찾은 경우에만 자기 팝업으로 보고
      # 진행합니다 (전수 배치 01:04 실측: 우물 '丁亞'/젖소 'C0자' 로 3회 소진하던 사고).
      # 격자 추론(order)으로 찍은 행은 이름 근거가 없어 여기서 통과시키면 안 됩니다 -
      # 추론이 빗나갔을 때 다른 대상을 채집하게 됨 (리뷰 블로커)
      if ($targetRowSource -eq 'order') {
        # 앵커 2개짜리 약한 추론은 이름 근거가 없어 통과시키지 않습니다 (다른 대상 채집 방지)
        Write-RunLog "[생활] 추정 행의 상세 제목을 확인하지 못했습니다 (판독 '$detailText') - 재시도"
        return $false
      }
      if ($targetRowSource -eq 'order-strong') {
        # 앵커 3개+ 격자 추론은 위치 신뢰도가 높아 진행합니다 - 1글자 대상('물')은 제목도
        # 본문도 검증 수단이 없어(라벨 '집물'과 충돌) 이 경로가 유일합니다 (라운드 6 실측)
        Write-RunLog "[생활] 추정 행(격자 앵커 3개+)의 상세 제목이 깨졌지만 진행합니다 (판독 '$detailText')"
        $detailOk = $true
        break
      }
      if ($targetRowSource -eq 'index') {
        # 순서 기반(추수의 밀/콩/쌀 등)은 이름 검증이 불가능하므로, 최소한 '이 스킬의 대상'
        # 인지만 확인합니다 - 상세 본문에 스킬 이름이 들어 있습니다 (실측: '…추수 레벨 1 이상')
        $skillNameNorm = Get-LifeNormalizedName ([string]$SkillEntry.Name)
        if ($detailText.Contains($skillNameNorm)) {
          Write-RunLog "[생활] 순서로 찾은 행의 상세에서 '$([string]$SkillEntry.Name)' 확인 - 진행합니다"
          $detailOk = $true
          break
        }
        Write-RunLog "[생활] 순서로 찾은 행의 상세를 확인하지 못했습니다 (판독 '$detailText') - 재시도"
        return $false
      }
      Write-RunLog "[생활] 상세 제목 판독이 깨졌지만(판독 '$detailText') 대상 행 일치 근거로 진행합니다"
      $detailOk = $true
      break
    }
    Start-Sleep -Milliseconds 900
  }
  if (-not $detailOk) {
    Write-RunLog "[생활] 대상 상세 팝업을 확인하지 못했습니다 - 재시도"
    Write-LifeDiagnostics -Game $Game -Context '상세 팝업 확인 실패'
    return $false
  }
  # 상세가 '이 대상의 팝업'으로 확정된 뒤에만 요구 레벨을 남깁니다 - 확정 전에 남기면 오클릭한
  # 다른 대상의 요구치가 그대로 실패 안내에 실립니다 (리뷰 지적). 대상 이름을 함께 묶어
  # 두고 안내 시점에 다시 대조합니다 - 재시도 중 대상이 바뀌는 경로는 없지만, 값이 어느
  # 대상 것인지 근거 없이 쓰지 않기 위한 계약입니다.
  $script:lifeLastDetail = @{
    Target = [string]$TargetName
    Level  = (Get-LifeRequiredLevel -DetailText $detailText)
  }
  # 6) 가까운 위치 찾기 - 링크 y 는 설명 길이에 따라 대상별로 달라(00:53 '둥지' 실사고:
  #    사과나무 실측 고정 좌표가 빗나가 퀘스트 미생성 3회 소진) 글자 탐색으로만 클릭합니다.
  #    고정 좌표 폴백은 원 사고 재도입이라 금지 - 못 찾으면 진단 후 재시도 (리뷰 블로커).
  #    순서: Focus → 판독 → 단일 후보 검증 → deadline 재검사 → 기준 좌표 클릭
  #    (Click-GamePoint 가 클릭 시점 창 rect 로 환산 - 캡처 후 창 이동에도 안전)
  if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 채집 시작 입력을 중단합니다'; return $false }
  # 링크 클릭은 사이클을 실제로 시작시키는 입력이라 전면 확인을 한 번 더 (리뷰 클릭 정책)
  if (-not (Confirm-LifeGameFront -Game $Game)) { return $false }
  $linkWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $rgLifeFindLink[0] -ReferenceY $rgLifeFindLink[1] `
      -RegionWidth $rgLifeFindLink[2] -RegionHeight $rgLifeFindLink[3] -Scale 3 -Engine $ocrKoreanEngine)
  $linkWord = Select-LifeFindNearestWord -Words $linkWords
  if ($null -eq $linkWord) {
    Write-RunLog "[생활] '가까운 위치 찾기' 링크를 찾지 못했습니다 - 재시도"
    Write-LifeDiagnostics -Game $Game -Context '위치 찾기 링크 미발견'
    return $false
  }
  # **누르기 직전 같은 프레임 재검증** (2026-08-07 사용자 제안): 링크를 찾은 바로 그 판독에
  # 팝업 제목도 들어 있습니다. 지금까지는 제목 검증(위 5단계)과 링크 클릭이 서로 다른
  # 캡처라, 그 사이에 팝업이 바뀌면 검증하지 않은 화면을 누를 수 있었습니다.
  # 여기서는 '다른 대상임이 또렷이 읽힐 때만' 막습니다 - 제목이 깨지는 건 흔하고(5단계가
  # 행 근거로 이미 통과시킨 경우도 있음) 여기서 unreadable 로 되돌리면 정상 대상까지
  # 시작을 못 합니다. 즉 새로 막는 것은 '검증 후 팝업이 다른 대상으로 바뀐' 경우뿐입니다.
  $linkTitle = Get-LifeDetailTitleFromWords -Words $linkWords
  $firstFrameTitle = $linkTitle
  $firstFrameLinkY = [int]$linkWord.Y
  $deepRecheckDone = $false
  $linkVerdict = Get-LifeTitleVerdict -Title $linkTitle -TargetName $TargetName -Order @($SkillEntry.Order)
  # 링크 판독만으로는 제목 인식률이 낮습니다 (2026-08-07 전수 실측 47/65 = 72%).
  # 링크 탐색 영역은 세로가 상세 영역의 1.5배(470 vs 300)라 같은 배율에서 글자가 작아지고,
  # 게다가 s3 한 배율뿐입니다 - 광석 캐기는 '은 광맥'이 '으과DH' 로 깨졌습니다.
  # 못 정했을 때만 상세 영역을 s3→s4 사다리로 한 번 더 읽습니다 (5단계가 쓰는, 제목이 잘
  # 읽히는 조합). 사이클이 수 분짜리라 판독 1~2회 추가는 무시할 수 있는 비용입니다.
  if ($linkVerdict -eq 'unknown') {
    $deepRecheckDone = $true
    # **두 배율 합의**를 요구합니다 - 먼저 나온 판정으로 확정하면 s3 만으로 오차단하거나,
    # s3 이 mine 이라고 s4 의 other 를 안 보고 클릭합니다 (5단계의 '두 스케일 모두 wrong 일
    # 때만 오클릭 확정' 규칙과 어긋남 - 리뷰 지적). 엇갈리면 unknown = 막지 않음.
    $recheckVerdicts = @()
    $recheckTitles = @()
    foreach ($recheckScale in @(3, 4)) {
      if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 클릭 직전 재확인 중단'; return $false }
      $recheckText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgLifeDetail[0] -ReferenceY $rgLifeDetail[1] `
          -RegionWidth $rgLifeDetail[2] -RegionHeight $rgLifeDetail[3] -Scale $recheckScale -Engine $ocrKoreanEngine) -replace '\s', ''
      $recheckVerdicts += , (Get-LifeTitleVerdictFromDetail -DetailText $recheckText -TargetName $TargetName -Order @($SkillEntry.Order))
      $recheckTitles += , (Get-LifeTitleFromDetailText -DetailText $recheckText)
    }
    $linkVerdict = Get-LifeConsensusVerdict -Verdicts $recheckVerdicts
    foreach ($recheckTitle in $recheckTitles) { if ($recheckTitle) { $linkTitle = $recheckTitle; break } }
    # 그래도 못 정했으면 **제목 띠만 좁게 잘라 고배율**로 봅니다. 넓은 영역으로는 아예 안
    # 읽히던 이름이 여기서 읽힙니다 (2026-08-08 실측 - 위 Get-LifeTitleStripRegion 주석).
    # 'mine' 은 한 배율만 맞아도 인정하고(막지 않는 방향이라 안전), 'other'(차단)는 합의 필요.
    if ($linkVerdict -eq 'unknown') {
      $stripRegion = Get-LifeTitleStripRegion -Words $linkWords
      if ($stripRegion) {
        $stripVerdicts = @()
        foreach ($stripScale in @(4, 5, 6)) {
          if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 제목 띠 재확인 중단'; return $false }
          $stripWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $stripRegion[0] -ReferenceY $stripRegion[1] `
              -RegionWidth $stripRegion[2] -RegionHeight $stripRegion[3] -Scale $stripScale -Engine $ocrKoreanEngine)
          $stripTitle = ((@($stripWords | Sort-Object { [int]$_.X } | ForEach-Object { [string]$_.Text }) -join '') -replace '\s', '')
          if (-not $stripTitle) { continue }
          $stripVerdict = Get-LifeTitleVerdict -Title $stripTitle -TargetName $TargetName -Order @($SkillEntry.Order)
          if ($stripVerdict -eq 'mine') { $linkVerdict = 'mine'; $linkTitle = $stripTitle; break }
          $stripVerdicts += , $stripVerdict
          if (-not $linkTitle) { $linkTitle = $stripTitle }
        }
        if ($linkVerdict -eq 'unknown') { $linkVerdict = Get-LifeConsensusVerdict -Verdicts $stripVerdicts }
      }
    }
  }
  if ($deepRecheckDone) {
    # 깊은 재확인은 새 캡처를 여러 장 썼습니다. 여기서 링크 좌표만 갱신하면 '판정은 A 팝업,
    # 클릭은 B 팝업' 이 될 수 있습니다 (리뷰 지적). 그래서 **마지막 프레임에서 링크와 제목을
    # 함께 다시 얻고, 첫 프레임과 같은 팝업인지 확인**한 뒤에만 앞의 판정을 적용합니다.
    if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 채집 시작 입력을 중단합니다'; return $false }
    if (-not (Confirm-LifeGameFront -Game $Game)) { return $false }
    $linkWords = @(Get-GameRegionOcrWords -Game $Game -ReferenceX $rgLifeFindLink[0] -ReferenceY $rgLifeFindLink[1] `
        -RegionWidth $rgLifeFindLink[2] -RegionHeight $rgLifeFindLink[3] -Scale 3 -Engine $ocrKoreanEngine)
    $linkWord = Select-LifeFindNearestWord -Words $linkWords
    if ($null -eq $linkWord) {
      Write-RunLog "[생활] 재확인 후 '가까운 위치 찾기' 링크를 다시 찾지 못했습니다 - 재시도"
      return $false
    }
    # 같은 팝업 판정: 링크 판독의 제목과 링크 Y 가 첫 프레임과 같아야 합니다. 제목이 안 읽히는
    # 대상은 양쪽 다 빈 문자열이라 링크 Y 가 근거가 됩니다 (대상마다 링크 Y 가 다름).
    $finalFrameTitle = Get-LifeDetailTitleFromWords -Words $linkWords
    if (($finalFrameTitle -ne $firstFrameTitle) -or ([Math]::Abs([int]$linkWord.Y - $firstFrameLinkY) -gt 6)) {
      Write-RunLog "[생활] 재확인 중에 팝업이 바뀌었습니다 (제목 '$firstFrameTitle' → '$finalFrameTitle') - 재시도"
      return $false
    }
  }
  if ($linkVerdict -eq 'other') {
    Write-RunLog "[생활] 클릭 직전 재확인에서 다른 대상의 팝업입니다 (제목 '$linkTitle', 목표 '$TargetName') - 재시도"
    Write-LifeDiagnostics -Game $Game -Context '클릭 직전 대상 불일치'
    return $false
  }
  # 판독/전면화에 시간이 들 수 있어 실제 클릭 직전에 한도를 다시 확인합니다 (리뷰 조건)
  if ((Get-Date) -gt $Deadline) { Write-RunLog '[생활] 사이클 한도 초과 - 채집 시작 입력을 중단합니다'; return $false }
  Write-RunLog "[생활] 대상 '$TargetName' 상세 확인 (제목 '$linkTitle') - '가까운 위치 찾기' 클릭 (링크 탐색 $([int]$linkWord.X),$([int]$linkWord.Y))"
  Click-GamePoint -Game $Game -ReferenceX ([int]$linkWord.X) -ReferenceY ([int]$linkWord.Y)
  Start-Sleep -Milliseconds 1500
  return $true
}

function Invoke-LifeGatherCycle {
  # 생활(채집) 1사이클: 메뉴 사이클 → 퀘스트 생성 확인 → 존재 대기 → 소멸 = 완료 (exit 0).
  # 전체 deadline = life.gatherWaitSeconds (이동+전투+채집 포함 - 기본 600초)
  param([System.Diagnostics.Process]$Game)
  # 커스텀 항목 토큰이 깨진 채로는 시작하지 않습니다 - config 의 슬라이더 값으로 대신 돌면
  # 사용자가 리스트에 넣지 않은 대상을 캐게 되고, 그 사이 남의 채집을 밀어낼 수 있습니다
  if ($script:lifeCustomSpecInvalid) {
    throw "생활 커스텀 반복 항목 형식이 올바르지 않습니다: '$env:HONEYNOGI_CUSTOM_ITEM' - GUI와 워커 버전이 어긋났을 수 있으니 꿀비노기를 최신 버전으로 맞춘 뒤 다시 시작해 주세요"
  }
  if ($lifeContent -eq 'process') {
    Write-RunLog '[완료] 가공 자동화는 아직 지원하지 않습니다 - 조건부 정지'
    exit 4
  }
  if (-not $lifeSkillMenuTable.ContainsKey($lifeSkillId)) {
    Write-RunLog "[완료] 채집 스킬 '$lifeSkillId' 는 아직 자동화를 지원하지 않습니다 (낚시 외 채집 8종 지원) - 조건부 정지"
    exit 4
  }
  $skillEntry = $lifeSkillMenuTable[$lifeSkillId]
  Write-RunLog "[생활] 자동화 시작: $([string]$skillEntry.Name) - $lifeTargetName (진행이 ${lifeGatherWait}초 없으면 정지 / 절대 상한 ${lifeGatherHardCapSeconds}초)"
  $questSeen = $false
  $absentStreak = 0
  $lastCountText = ''
  # 메뉴 사이클이 확정한 상세의 요구 레벨 @{ Target; Level } (실패 안내용 - 매 사이클 초기화)
  $script:lifeLastDetail = $null
  # 시작 상태 복구 (준비 단계): 열린 생활 창 정리 → 출석/이벤트 화면 정리 → 기존 퀘스트 확인.
  # (Clear-EventOverlay 는 생활 창을 '알 수 없는 화면'으로 오판할 수 있어 생활 창 정리를
  #  먼저 합니다 - 리뷰 지적. 메인 흐름의 이벤트 정리도 이 이유로 생활 분기 뒤에 둠)
  [void](Close-LifeOpenWindows -Game $Game)
  [void](Clear-EventOverlay -Game $Game)
  # 사이클 한도(deadline)는 '준비 정리 완료 시점'부터 잽니다 (설계 합의 계약 - 위 정리
  # 함수들의 내부 캡처 실패 대기는 이 한도 밖. 이후의 모든 내부 대기는 이 한도가 상한).
  $cycleDeadline = (Get-Date).AddSeconds($lifeGatherWait)
  # 시작 시점에 서버 연결이 끊겨 있으면 무엇도 진행되지 않습니다 - 퀘스트 판정보다 먼저
  # 확인합니다 (리뷰 조건: 초기 present 면 메뉴 루프를 건너뛰어 감지를 놓침)
  if ((Close-LifeBlockingDialog -Game $Game) -eq 'disconnected') {
    Write-RunLog '[완료] 게임 서버 연결이 끊어졌습니다 - 재접속 후 다시 시작해 주세요 (조건부 정지)'
    exit 4
  }
  # 초기 퀘스트 확인은 '전면화 후 여러 번' 판독합니다 (2026-08-07 사용자 지적: 트래커가
  # 잠깐 가려지면 없는 것으로 오판해 메뉴를 열고 다른 대상을 눌러 진행 중인 채집을 방해).
  # present 가 한 번이라도 보이면 진행 중으로 간주 - 없는데 있다고 보면 잠깐 기다릴 뿐이지만,
  # 있는데 없다고 보면 남의 채집을 망칩니다 (비대칭 위험이라 present 우선)
  # 맵 이동 로딩 화면에서는 퀘스트도 HUD 도 없어 'unknown' 만 나옵니다 - 그 상태로 '없음'
  # 판정을 내리면 이동 중에 메뉴를 열게 되므로, present/absent 가 확정될 때까지 기다립니다
  # (최대 약 60초. 로딩은 보통 10~30초 - 2026-08-07 사용자 지적)
  Focus-Game -Game $Game
  Start-Sleep -Milliseconds 700
  $initialState = 'unknown'
  $initialAbsentProbe = 0
  $loadingNoticed = $false
  $initialProbes = 0
  $initialPopupRounds = 0
  while ($initialProbes -lt 20) {
    if ((Get-Date) -gt $cycleDeadline) { break }
    if ($script:screenCaptureFailing) {
      Start-Sleep -Seconds 3
      [void](Test-CaptureRecovered -Game $Game)   # 복구 탐침이 없으면 화면이 돌아와도 못 알아챔
      # 캡처 실패는 판독 시도를 소모하지 않습니다 - 소모하면 잠깐의 화면 정지가 20회를 다 태우고
      # 'unknown' 인 채로 메뉴를 열어 진행 중인 채집을 방해합니다 (2026-08-07 감사).
      # Clear-EventOverlay 의 '캡처 실패 중에는 시도 미소모' 와 같은 계약입니다.
      continue
    }
    # 트래커를 가리는 팝업을 먼저 치웁니다. 특히 공지 게시판은 가장자리 HUD 가 그대로 보여
    # Test-HomeEndEscHud 가 참이 되므로 '게임 화면인데 퀘스트 없음'(absent)으로 확정됩니다 -
    # 그 상태로 메뉴를 열면 진행 중이던 채집을 끊습니다. 대기 루프(아래)에는 있던 방어가
    # 초기 확인에만 빠져 있었습니다 (2026-08-07 감사)
    if ($initialPopupRounds -lt 10) {
      $popupHandled = $false
      if (Invoke-PurchasePopupSweep -Game $Game) { $popupHandled = $true }
      elseif (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix '[생활] ') { $popupHandled = $true }
      elseif (Test-NoticeBoardPopup -Game $Game) {
        Focus-Game -Game $Game
        Click-GamePoint -Game $Game -ReferenceX $ptNoticeClose[0] -ReferenceY $ptNoticeClose[1]
        Write-RunLog '[생활] 공지 게시판 팝업 감지 - X로 닫기 (시작 확인 중)'
        $popupHandled = $true
      }
      if ($popupHandled) {
        $initialPopupRounds++
        Start-Sleep -Seconds 2
        continue      # 닫은 회차는 반드시 재캡처 - 같은 프레임으로 판정하면 오판 (리뷰 계약)
      }
    }
    $initialProbes++
    $probeState = Get-LifeQuestState -Game $Game
    if ($probeState -eq 'present') { $initialState = 'present'; break }
    if ($probeState -eq 'absent') {
      $initialAbsentProbe++
      if ($initialAbsentProbe -ge 2) { $initialState = 'absent'; break }
    } else {
      $initialAbsentProbe = 0
      if (-not $loadingNoticed) {
        Write-RunLog '[생활] 게임플레이 화면이 아닙니다(맵 이동/로딩 추정) - 화면이 안정될 때까지 기다립니다'
        $loadingNoticed = $true
      }
    }
    Start-Sleep -Seconds 3
  }
  # present/absent 어느 쪽도 확정하지 못했으면 입력하지 않습니다 - 게임플레이 화면인지조차
  # 모르는 상태에서 메뉴를 열면 진행 중인 채집을 끊거나 엉뚱한 화면을 누릅니다
  # (2026-08-07 리뷰 지적 - 주석의 '확정될 때까지' 계약이 코드에는 없었음)
  if ($initialState -eq 'unknown') {
    Write-RunLog '[완료] 게임플레이 화면을 확인하지 못했습니다 (로딩/다른 화면 지속) - 조건부 정지'
    Write-LifeDiagnostics -Game $Game -Context '시작 화면 확인 실패'
    exit 4
  }
  if ($initialState -eq 'present') {
    # 트래커의 퀘스트가 '설정 대상의 것'인지 확인합니다 - 다른 대상의 채집을 이어받으면
    # 엉뚱한 대상을 캐고 한도까지 대기합니다 (2026-08-06 라운드 5 실측: '거미줄' 잔여
    # 퀘스트를 '물' 사이클이 이어받아 600초 초과). 트래커 이름도 깨지므로 느슨하게 비교.
    # 판독은 **좁은 영역(퀘스트 첫 줄)만** 씁니다. 넓은 영역은 주간 목표 등 다른 퀘스트 줄까지
    # 들어와, 줄 구분 없이 이름을 찾으면 남의 줄에 있는 더 긴 이름을 소유자로 집습니다
    # (2026-08-07 감사 실측: '주간 목표 뾰족 나무' + '채집 장소 탐색 나무' → '뾰족 나무' 반환).
    # 좁은 영역으로 못 정하면 아래 '미확정 = 내 것' 기본값이 안전하게 받아 줍니다.
    $initialQuestText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
        -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
    # 후보는 **전 스킬의 대상 전체**입니다 - 현재 스킬 목록만 대조하면 다른 스킬의 잔여
    # 퀘스트를 현재 스킬의 짧은 대상으로 오인합니다 ('사과 나무' → '나무' - 2026-08-07 감사).
    # 단, **그 판독이 채집 퀘스트 줄일 때만** 이름을 찾습니다 - present 는 넓은 영역으로도
    # 잡히므로, 좁은 영역에 '주간 목표 뾰족 나무' 같은 다른 줄이 들어와 있으면 그 이름을
    # 소유자로 집어 남의 퀘스트로 오판합니다 (리뷰 지적). 아니면 미확정 → 아래 기본값.
    $questOwner = ''
    if (Test-LifeQuestFragments -QuestText $initialQuestText) {
      $questOwner = Get-LifeQuestOwner -QuestText $initialQuestText -Order (Get-LifeAllTargetNames)
    }
    # 어느 대상인지 못 정했으면(이름이 통째로 깨짐) '내 것'으로 봅니다 - 비대칭 비용 때문입니다.
    # 남의 것을 내 것으로 보면 그 채집이 끝날 때까지 기다렸다가 한 회차를 헛돌 뿐이지만,
    # 내 것을 남의 것으로 보면 3분 대기 후 exit 4 로 무인 반복 전체가 멈춥니다 (2026-08-07 감사)
    $questMatchesTarget = $true
    if ($questOwner) {
      $questMatchesTarget = (Test-LifeNameMatches -RowText $questOwner -TargetName $lifeTargetName)
    } else {
      Write-RunLog "[생활] 진행 중인 퀘스트의 대상 이름을 확정하지 못했습니다 (판독 '$initialQuestText') - 내 채집으로 보고 이어서 대기합니다"
    }
    if ($questMatchesTarget) {
      Write-RunLog '[생활] 진행 중인 채집 퀘스트 감지 - 이어서 대기합니다'
      $questSeen = $true
    } else {
      # 다른 대상의 채집이 진행 중(이동/채집)이면 새 퀘스트를 만들 수 없고, 메뉴를 열어
      # 다른 대상을 누르면 진행 중인 채집만 방해합니다 (2026-08-06 사용자 실기 관찰:
      # "이동 중인데 중간에 다른 채집을 누른다"). 그 채집이 끝날 때까지 기다렸다가
      # 시작합니다 - 바로 정지하면 대상을 바꿀 때마다 멈춰 버립니다(같은 날 실측).
      Write-RunLog "[생활] 다른 대상의 채집이 진행 중입니다 (판독 '$initialQuestText') - 끝나기를 기다립니다"
      # 소멸 판정도 '연속 3회' 확인해야 합니다 - 1회 판독으로 확정하면 트래커가 잠깐
      # 가려진 사이 '끝났다'고 보고 메뉴를 열어 진행 중인 채집을 방해합니다
      # (2026-08-07 사용자 실기 관찰: 5초 만에 끝났다고 판정하고 다른 대상을 누름)
      $otherQuestGone = $false
      $otherGoneStreak = 0
      $otherLastCount = ''
      $otherWaitProbes = 0
      while ($otherWaitProbes -lt 60) {        # 3초 간격 - 상한은 약 3분 (사이클 한도 안에서)
        if ((Get-Date) -gt $cycleDeadline) { break }
        Start-Sleep -Seconds 3
        if ($script:screenCaptureFailing) {
          [void](Test-CaptureRecovered -Game $Game)   # 복구 탐침 (없으면 플래그가 영영 안 풀림)
          continue      # 캡처 실패 회차는 예산을 소모하지 않습니다 (3분 정전이 exit 4 가 되던 문제)
        }
        $otherWaitProbes++
        # 남은 수량을 보여 줍니다 - 9/10 이면 곧 끝난다는 걸 로그로 알 수 있게 (사용자 요청)
        $otherCount = Get-LifeQuestCountText -Game $Game
        if ($otherCount -and $otherCount -ne $otherLastCount) {
          Write-RunLog "[생활] 이전 채집 진행 중: $otherCount"
          $otherLastCount = $otherCount
        }
        # 'absent'(게임플레이 HUD 가 보이는데 퀘스트가 없음) 일 때만 소멸로 셉니다.
        # 맵 이동 로딩 화면에서는 퀘스트도 HUD 도 사라져 'unknown' 이 되는데, 이걸 소멸로
        # 세면 이동 중에 다른 대상을 눌러 버립니다 (2026-08-07 사용자 지적)
        # absent = HUD 가 보이는데 퀘스트 없음 = 게임 화면이 앞에 있다는 증거이므로 전면화
        # 불필요 (가림 상황은 Get-LifeQuestState 내부에서 전면화+재판독으로 이미 처리)
        $otherProbe = Get-LifeQuestState -Game $Game
        # 소멸 확정 직전에도 전면 여부만 확인 (이미 전면이면 아무 동작 없음)
        if ($otherProbe -eq 'absent' -and $otherGoneStreak -ge 2 -and -not (Test-GameForeground -Game $Game)) {
          Focus-Game -Game $Game
          Start-Sleep -Milliseconds 700
          $otherProbe = Get-LifeQuestState -Game $Game
        }
        if ($otherProbe -ne 'absent') {
          if ($otherProbe -eq 'unknown') { Write-RunLog '[생활] 화면이 전환 중입니다(로딩 추정) - 소멸 판정 보류' }
          $otherGoneStreak = 0
          continue
        }
        $otherGoneStreak++
        if ($otherGoneStreak -ge 3) { $otherQuestGone = $true; break }
      }
      if (-not $otherQuestGone) {
        Write-RunLog "[완료] 진행 중이던 다른 채집이 끝나지 않아 '$lifeTargetName' 을 시작할 수 없습니다 - 조건부 정지"
        exit 4
      }
      Write-RunLog "[생활] 이전 채집이 끝났습니다 - '$lifeTargetName' 으로 시작합니다"
    }
  }
  # 메뉴 사이클 (최대 3회 재시도)
  if (-not $questSeen) {
    $menuOk = $false
    foreach ($menuTry in 1..3) {
      # 팝업 방어 (구매/보상/협동/네트워크 + 주간 리셋 + 공지 게시판)
      if (Invoke-PurchasePopupSweep -Game $Game) { Start-Sleep -Milliseconds 1200 }
      if (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix '[생활] ') { Start-Sleep -Milliseconds 1200 }
      if (-not $script:screenCaptureFailing -and (Test-NoticeBoardPopup -Game $Game)) {
        Focus-Game -Game $Game
        Click-GamePoint -Game $Game -ReferenceX $ptNoticeClose[0] -ReferenceY $ptNoticeClose[1]
        Write-RunLog '[생활] 공지 게시판 팝업 감지 - X로 닫기'
        Start-Sleep -Seconds 2
      }
      # 진행 차단 모달(연결 끊김/준비물 부족/오류 팝업) 정리 - 남으면 C 키가 먹지 않아 연쇄 실패
      $dialogState = Close-LifeBlockingDialog -Game $Game
      if ($dialogState -eq 'disconnected') {
        Write-RunLog '[완료] 게임 서버 연결이 끊어졌습니다 - 재접속 후 다시 시작해 주세요 (조건부 정지)'
        exit 4
      }
      if ($dialogState -eq 'material') {
        Write-RunLog "[완료] '$lifeTargetName' 채집에 필요한 준비물이 없습니다$(Format-LifeMissingItemNotice -ItemText ([string]$script:lifeMissingItemText)) - 조건부 정지"
        exit 4
      }
      while ($script:screenCaptureFailing) {
        # 영구 캡처 실패도 사이클 한도를 넘기면 정지합니다 (deadline 계약 - 리뷰 지적)
        if ((Get-Date) -gt $cycleDeadline) {
          Write-RunLog "[완료] 화면 캡처 실패가 지속돼 사이클 한도(${lifeGatherWait}초)를 넘겼습니다 - 조건부 정지"
          exit 4
        }
        Test-SafeStopDuringCaptureFail
        Start-Sleep -Seconds 2
        [void](Test-CaptureRecovered -Game $Game)   # 복구 탐침 (없으면 한도까지 여기 갇힘)
      }
      if (Invoke-LifeMenuSequence -Game $Game -SkillEntry $skillEntry -TargetName $lifeTargetName -Deadline $cycleDeadline) {
        # 퀘스트 생성 확인: 약 12초(1.5초 x 8회 + OCR 시간) 안에 present 2회 (리뷰 조건).
        # 사이클 한도는 이 확인 루프에도 우선합니다 (하드 상한 계약)
        $presentCount = 0
        foreach ($confirmTry in 1..8) {
          if ((Get-Date) -gt $cycleDeadline) { break }
          Start-Sleep -Milliseconds 1500
          if ((Get-LifeQuestState -Game $Game) -eq 'present') {
            $presentCount++
            if ($presentCount -ge 2) { break }
          }
        }
        if ($presentCount -ge 2) {
          Write-RunLog '[생활] 채집 퀘스트 생성 확인 - 자동 이동/채집을 기다립니다'
          $questSeen = $true
          $menuOk = $true
          break
        }
        Write-RunLog '[생활] 채집 퀘스트가 생성되지 않았습니다 - 화면 정리 후 재시도'
        # 링크를 눌렀는데 퀘스트가 안 생기는 원인은 화면에만 남습니다 (첫 회차만 캡처)
        if ($menuTry -eq 1) { Write-LifeDiagnostics -Game $Game -Context '퀘스트 생성 실패' }
        # 다른 대상의 채집 퀘스트가 아직 진행 중이면 새 퀘스트를 만들 수 없습니다
        # (2026-08-06 라운드 7 실측: 얽힌 거미줄/증폭·산뜻 버섯이 이 상태로 3회 소진).
        # 재시도해도 결과가 같으므로 안내 후 정지합니다 - 그 채집이 끝난 뒤 다시 시작하면 됩니다
        $leftoverQuestText = (Get-GameRegionOcrText -Game $Game -ReferenceX $rgQuestTracker[0] -ReferenceY $rgQuestTracker[1] `
            -RegionWidth $rgQuestTracker[2] -RegionHeight $rgQuestTracker[3] -Scale 3 -Engine $ocrKoreanEngine) -replace '\s', ''
        if (Test-LifeQuestFragments -QuestText $leftoverQuestText) {
          # 소유 판정은 초기 확인과 같은 규칙(긴 이름 우선 + 이형·치환)을 씁니다 - 부분 문자열
          # 비교는 '우물'을 '물'로, '얽힌 거미줄'을 '거미줄'로 오인합니다 (2026-08-07 감사).
          # 여기서는 '다른 대상임이 확정될 때만' 정지합니다 - 확정 못 하면 재시도가 안전합니다
          $leftoverOwner = Get-LifeQuestOwner -QuestText $leftoverQuestText -Order (Get-LifeAllTargetNames)
          $leftoverIsOther = ($leftoverOwner -and -not (Test-LifeNameMatches -RowText $leftoverOwner -TargetName $lifeTargetName))
          if ($leftoverIsOther) {
            Write-RunLog "[완료] 다른 채집 퀘스트가 진행 중이라 '$lifeTargetName' 을 시작할 수 없습니다 (판독 '$leftoverQuestText') - 조건부 정지"
            exit 4
          }
        }
        # 준비물 부족/연결 끊김이면 재시도해도 결과가 같으므로 즉시 안내 정지
        $questFailDialog = Close-LifeBlockingDialog -Game $Game
        if ($questFailDialog -eq 'disconnected') {
          Write-RunLog '[완료] 게임 서버 연결이 끊어졌습니다 - 재접속 후 다시 시작해 주세요 (조건부 정지)'
          exit 4
        }
        if ($questFailDialog -eq 'material') {
          Write-RunLog "[완료] '$lifeTargetName' 채집에 필요한 준비물이 없습니다$(Format-LifeMissingItemNotice -ItemText ([string]$script:lifeMissingItemText)) - 조건부 정지"
          exit 4
        }
      }
      [void](Close-LifeOpenWindows -Game $Game)
      Start-Sleep -Seconds 2
      if ((Get-Date) -gt $cycleDeadline) { break }
    }
    if (-not $menuOk) {
      Write-LifeDiagnostics -Game $Game -Context '메뉴 사이클 3회 소진'
      # 링크를 눌러도 퀘스트가 안 생기는 가장 흔한 원인은 '스킬 레벨 미달'입니다
      # (2026-08-07 실측: 곤충 채집 '일렁이는 빛 무리' = 레벨 27 이상, 캐릭터는 25).
      # 상세 팝업에 적힌 요구치를 그대로 안내합니다 - 캐릭터 레벨은 판독이 불안정해 단정하지 않습니다.
      $levelNotice = ''
      $detailRecord = $script:lifeLastDetail
      if ($detailRecord -and ([string]$detailRecord.Target) -eq ([string]$lifeTargetName) -and ([int]$detailRecord.Level) -gt 0) {
        $requiredLevel = [int]$detailRecord.Level
        $levelNotice = " (이 대상은 '$([string]$skillEntry.Name) 레벨 ${requiredLevel} 이상'이 필요합니다 - 스킬 레벨이 모자라면 '가까운 위치 찾기'가 동작하지 않습니다)"
      }
      Write-RunLog "[완료] 채집 시작(가까운 위치 찾기)을 확정하지 못했습니다 - 조건부 정지${levelNotice}"
      exit 4
    }
  }
  # 퀘스트 존재 대기: 소멸(absent 3연속) = 사이클 완료. unknown 은 부재로 세지 않음 (리뷰 조건)
  #
  # 한도는 '총 시간'이 아니라 **'진행이 멈춘 시간'** 으로 잽니다 (2026-08-08 사용자 지적:
  # "잘 캐고 있는데 왜 잘리나"). 총 시간으로 재면 사용자가 대상별 소요를 미리 알아야 숫자를
  # 정할 수 있는데 그건 알 수 없습니다 - 실측 소요가 100~520초로 대상마다 5배 차이입니다.
  # 워커는 이미 수량('6/10')을 읽고 있으므로, **모은 개수가 늘면 건강한 것**으로 보고
  # 한도를 다시 잽니다. 오래 걸리는 건 문제가 아니고, '아무 일도 안 일어나는' 게 문제입니다.
  # 수량 판독은 '6/10 → 0/10 → 6/10' 처럼 튀므로(실측) **본 적 있는 최댓값**만 기준으로 씁니다
  # (노이즈로 한도가 되살아나지 않게). 최댓값은 목표 개수를 넘지 못하니 무한 연장도 불가능하고,
  # 그 위에 절대 상한(1시간)을 백스톱으로 둡니다 - 무인 운용에서 영원히 매달리지 않기 위함.
  $waitPollCount = 0
  $progressMaxCount = -1
  $progressGoalCounts = @{}      # 목표 개수(분모) → 관측 횟수 (완료 로그 표기용)
  $progressDeadline = (Get-Date).AddSeconds($lifeGatherWait)
  $hardDeadline = (Get-Date).AddSeconds($lifeGatherHardCapSeconds)
  while ($true) {
    if ((Get-Date) -gt $hardDeadline) {
      Write-RunLog "[완료] 채집이 절대 상한(${lifeGatherHardCapSeconds}초)을 넘겼습니다 - 조건부 정지 (수량은 늘고 있었지만 끝나지 않았습니다)"
      exit 4
    }
    if ((Get-Date) -gt $progressDeadline) {
      # 멈춘 진짜 원인이 '채집이 느려서'가 아니라 '화면이 안 그려져서'일 수 있습니다
      # (2026-08-07 실측: 채집 3/10 진행 중 RDP 창이 최소화돼 16분간 캡처 실패).
      if ($script:screenCaptureFailing) {
        Write-RunLog "[완료] 화면이 그려지지 않는 상태가 ${lifeGatherWait}초 이어졌습니다 - 조건부 정지 (RDP 창 최소화/화면 잠금을 확인해 주세요)"
        exit 4
      }
      $progressNote = $(if ($progressMaxCount -ge 0) { "마지막 진행 ${progressMaxCount}개" } else { '수량 판독 없음(이동 중 추정)' })
      Write-RunLog "[완료] 채집 진행이 ${lifeGatherWait}초 동안 없었습니다 ($progressNote) - 조건부 정지 (이동이 아주 먼 대상이면 GUI 의 '채집 대기'를 늘려 주세요)"
      exit 4
    }
    Start-Sleep -Seconds 3
    if ($script:screenCaptureFailing) {
      Test-SafeStopDuringCaptureFail
      # 복구 탐침 - 이게 없으면 RDP 창이 다시 열려도 플래그가 안 풀려 한도까지 대기했습니다
      # (2026-08-07 실사고: 개암 버섯 채집 3/10 중 16분 캡처 실패 → 한도 초과 정지)
      [void](Test-CaptureRecovered -Game $Game)
      continue
    }
    # 대기 중 팝업 방어 (처리한 회차는 판정을 건너뜀 - 같은 프레임 오판 방지).
    # 공지 게시판은 HUD 가 가장자리로 계속 보여 트래커가 가려지면 absent 오판 위험
    # (리뷰 지적) - 닫은 회차는 반드시 continue 로 재캡처합니다.
    if (Invoke-PurchasePopupSweep -Game $Game) { continue }
    if (Close-WeeklyCoopResetPopup -Game $Game -LogPrefix '[생활] ') { continue }
    if (-not $script:screenCaptureFailing -and (Test-NoticeBoardPopup -Game $Game)) {
      Focus-Game -Game $Game
      Click-GamePoint -Game $Game -ReferenceX $ptNoticeClose[0] -ReferenceY $ptNoticeClose[1]
      Write-RunLog '[생활] 공지 게시판 팝업 감지 - X로 닫기 (채집 대기 중)'
      Start-Sleep -Seconds 2
      continue
    }
    # 채집 대기 중 서버 연결이 끊기면 한도(기본 600초)를 통째로 낭비하므로 즉시 정지합니다
    # (2026-08-06 라운드 4 실측: 끊긴 채 3회차가 각 600초 소진 → '가방 가득'으로 오인).
    # 중앙 모달 뒤로 트래커가 보일 수 있어 퀘스트 상태와 무관하게 주기 확인합니다 - 다만
    # 매 회차 OCR 은 비싸므로 5회차(약 15초)마다 (리뷰 조건)
    $waitPollCount++
    $questState = Get-LifeQuestState -Game $Game
    if ($questState -ne 'present' -or ($waitPollCount % 5) -eq 0) {
      $waitDialogState = Close-LifeBlockingDialog -Game $Game
      if ($waitDialogState -eq 'disconnected') {
        Write-RunLog '[완료] 게임 서버 연결이 끊어졌습니다 - 재접속 후 다시 시작해 주세요 (조건부 정지)'
        exit 4
      }
      if ($waitDialogState -ne 'none') { continue }
    }
    if ($questState -eq 'present') {
      $absentStreak = 0
      $countText = Get-LifeQuestCountText -Game $Game
      if ($countText -and $countText -ne $lastCountText) {
        Write-RunLog "[생활] 채집 진행: $countText"
        $lastCountText = $countText
      }
      # 모은 개수가 '지금까지 본 최댓값'을 넘었을 때만 진행으로 인정하고 한도를 다시 잽니다
      $countValue = Get-LifeProgressValue -CountText $countText
      if ($countValue -gt $progressMaxCount) {
        $progressMaxCount = $countValue
        $progressDeadline = (Get-Date).AddSeconds($lifeGatherWait)
      }
      # 목표 개수(분모)도 모읍니다 - 완료 로그에 '마지막으로 본 수량'이 아니라 '목표'를
      # 적기 위함입니다 (아래 완료 지점 주석 참고). 한 회차 판독은 못 믿으므로 표를 쌓습니다.
      $goalValue = Get-LifeQuestGoalValue -CountText $countText
      if ($goalValue -gt 0) {
        if (-not $progressGoalCounts.ContainsKey($goalValue)) { $progressGoalCounts[$goalValue] = 0 }
        $progressGoalCounts[$goalValue] = [int]$progressGoalCounts[$goalValue] + 1
      }
      continue
    }
    if ($questState -eq 'absent') {
      # 여기의 absent 는 'HUD 가 보이는데 퀘스트가 없다' 는 뜻이라 게임 화면이 앞에 있다는
      # 증거입니다 - 전면화가 필요 없습니다 (2026-08-07 사용자 지적: 가려지지도 않았는데
      # 게임이 자꾸 앞으로 튀어나옴). 가림 상황은 Get-LifeQuestState 안에서 이미
      # '판독 실패 → 전면화 → 재판독' 으로 처리되고, 실패하면 unknown 이라 여기 오지 않습니다.
      $absentStreak++
      if ($absentStreak -ge 3) {
        # 완료 확정은 되돌릴 수 없으므로 이 순간에만 '게임이 실제로 전면인지' 확인합니다.
        # HUD 가 보여도 게임이 전면이 아닐 수 있고(창 영역 밖의 다른 창), 그 상태의 판독은
        # 신뢰할 수 없습니다. 이미 전면이면 아무 일도 하지 않아 사용자 방해가 없습니다
        # (2026-08-07 사용자 지적 반영 - 판독 중에는 전면화하지 않되 확정 직전에만)
        if (-not (Test-GameForeground -Game $Game)) {
          Focus-Game -Game $Game
          Start-Sleep -Milliseconds 700
          if ((Get-LifeQuestState -Game $Game) -ne 'absent') {
            Write-RunLog '[생활] 전면화 후 재확인하니 퀘스트가 남아 있습니다 - 완료 판정 취소'
            $absentStreak = 0
            continue
          }
        }
        # 무엇을 캤는지 남깁니다 - 여러 대상을 번갈아 돌리면 로그만 봐서는 구분이 안 됩니다
        # (2026-08-08 사용자 요청).
        # 수량은 **목표 개수(분모)** 를 적습니다. '마지막으로 본 수량'을 적으면 거의 항상
        # 1개 모자라게 나옵니다 - 마지막 개를 채우는 순간 트래커가 사라지는데 폴링이 3초
        # 간격이라 그 프레임을 놓치기 때문입니다 (2026-08-08 사용자 제보: '9개' 로 표기됨).
        # 퀘스트가 사라진 것 자체가 '목표를 다 모았다'는 뜻이므로 목표 개수가 정확합니다.
        # 목표를 못 읽었으면 마지막 판독을 그대로 적되 '마지막 판독'임을 밝힙니다 (단정 금지).
        $goalCount = Get-LifeQuestGoalConsensus -GoalCounts $progressGoalCounts
        $doneCount = ''
        if ($goalCount -gt 0 -and $goalCount -ge $progressMaxCount) { $doneCount = " ${goalCount}개" }
        elseif ($progressMaxCount -ge 0) { $doneCount = " (마지막 판독 ${progressMaxCount}개)" }
        Write-RunLog "[생활] 채집 퀘스트 종료 확인 - '$lifeTargetName'${doneCount} 완료"
        Write-RunLog "[완료] 채집 1사이클 완료 - $([string]$skillEntry.Name) / $lifeTargetName${doneCount}"
        exit 0
      }
      continue
    }
    # unknown: 부재 카운트 유지하지 않고 다음 판독으로
    $absentStreak = 0
  }
}

try {
  $game = Get-GameProcess
  Write-RunLog "[준비] 게임 확인: PID $($game.Id)"

  # ===== 적용 설정 스냅샷 (로그 파일 전용) =====
  # GUI 화면에는 표시되지 않고([설정] 줄은 GUI가 건너뜀) 로그 파일에만 남습니다.
  # 다른 사용자의 오류 세트(error_*.log)만 받아도 반복/콘텐츠/상세/기능 설정을
  # 그대로 볼 수 있게 하기 위한 분석용 기록입니다. 좌표/영역 섹션은 제외합니다.
  try {
    $repeatInfo = [string]$env:HONEYNOGI_REPEAT_INFO
    if ([string]::IsNullOrWhiteSpace($repeatInfo)) { $repeatInfo = '(GUI 정보 없음 - 워커 단독 실행)' }
    $appVersionInfo = [string]$env:HONEYNOGI_APP_VERSION
    if ([string]::IsNullOrWhiteSpace($appVersionInfo)) { $appVersionInfo = '?' }
    # 대분류가 '생활'이면 contentCategory(전투 하위 선택)는 참고용으로만 남습니다.
    # 생활 상세 설정(스킬/대상/대기 등)은 아래 섹션 목록의 'life' 한 줄 JSON 으로 남습니다.
    Write-RunLog "[설정] 꿀비노기 v$appVersionInfo, 대분류 '$mainCategory', 콘텐츠 '$contentCategory', 반복 $repeatInfo, coordsVersion $(Get-ConfigValue $config @('coordsVersion') '?')"
    if ($script:customMode) {
      # 커스텀 리스트는 압축 문자열 한 줄로만 남깁니다 (타 PC 제보 분석 요건 -
      # customRepeat 섹션을 아래 목록에 넣으면 items 배열 전체가 JSON으로 쏟아져 제외)
      Write-RunLog "[설정] 커스텀 리스트: $($script:customListText) (현재 $($script:customPositionText), 이전 항목 '$env:HONEYNOGI_CUSTOM_PREV', 다음 항목 '$env:HONEYNOGI_CUSTOM_NEXT', 재시작 $($script:customRestart))"
    }
    if ($script:lifeCustomMode) {
      # 생활 커스텀은 이전/다음 항목 개념이 없습니다 (사이클마다 메뉴부터 새로 시작하므로
      # 던전의 '다시 하기 vs 선택 화면' 갈림길이 없음) - 리스트와 현재 위치만 남깁니다
      Write-RunLog "[설정] 생활 커스텀 리스트: $([string]$env:HONEYNOGI_CUSTOM_LIST) (현재 $([string]$env:HONEYNOGI_CUSTOM_POSITION))"
    }
    foreach ($sectionName in @('dungeons', 'normalDungeon', 'huntingGround', 'life', 'timeoutsSeconds', 'afterEntry', 'revive', 'rdp', 'window', 'diagnostics')) {
      $section = $config.$sectionName
      if ($null -eq $section) { continue }
      # 설명용 '_' 키와 부피 큰 profiles(좌표)는 빼고 실제 값만 한 줄 JSON으로 남깁니다
      $clean = [ordered]@{}
      foreach ($prop in $section.PSObject.Properties) {
        if ($prop.Name -like '_*' -or $prop.Name -eq 'profiles') { continue }
        $clean[$prop.Name] = $prop.Value
      }
      if ($clean.Count -gt 0) {
        Write-RunLog "[설정] ${sectionName}: $($clean | ConvertTo-Json -Compress -Depth 4)"
      }
    }
  } catch {
    Write-RunLog "[설정] 스냅샷 기록 실패: $($_.Exception.Message)"
  }

  Focus-Game -Game $game

  # 게임 창 정렬: RDP 재접속·배율 변화·콘솔 전환 등으로 창 크기가 바뀌면
  # 감지 좌표가 어긋나므로 매 사이클 시작 시 창을 보정합니다.
  #  - nearest 모드(기본): 사용자가 조절한 크기를 최대한 유지하고 "비율만" 기준(1272:717)에 맞춤.
  #                        창이 화면 밖으로 나가 있으면 화면 안으로 밀어 넣음.
  #  - fixed 모드        : config 의 x, y, width, height 로 항상 고정.
  # (게임이 "창 모드"일 때만 동작합니다)
  if ($windowNormalize) {
    $normalizeRect = New-Object HoneyNogiInput+RECT
    if ([HoneyNogiInput]::GetWindowRect($game.MainWindowHandle, [ref]$normalizeRect)) {
      $currentWidth = $normalizeRect.Right - $normalizeRect.Left
      $currentHeight = $normalizeRect.Bottom - $normalizeRect.Top
      $currentX = $normalizeRect.Left
      $currentY = $normalizeRect.Top
      # 작업 영역(작업표시줄 제외) 기준으로 배치합니다. 창이 작업표시줄과 겹치면
      # 하단 OCR 영역(클리어 문구/입장·나가기 버튼)이 게임 대신 작업표시줄을 읽고,
      # 하단 클릭도 작업표시줄에 먹히기 때문입니다.
      $workArea = New-Object HoneyNogiInput+RECT
      if ([HoneyNogiInput]::SystemParametersInfo(0x0030, 0, [ref]$workArea, 0)) {
        $workX = $workArea.Left
        $workY = $workArea.Top
        $workW = $workArea.Right - $workArea.Left
        $workH = $workArea.Bottom - $workArea.Top
      } else {
        $workX = 0
        $workY = 0
        $workW = [HoneyNogiInput]::GetSystemMetrics(0)
        $workH = [HoneyNogiInput]::GetSystemMetrics(1)
      }

      if ($windowMode -eq 'fixed') {
        $targetWidth = $windowWidth
        $targetHeight = $windowHeight
        $targetX = $windowX
        $targetY = $windowY
        $sizeOk = ($currentWidth -eq $targetWidth -and $currentHeight -eq $targetHeight)
      } elseif ($windowMode -eq 'recommended') {
        # 권장 크기(GUI '권장 창 크기' 체크): OCR 실측 기준(1272x717)의 깔끔한 배율로 맞춰
        # 글자 렌더링이 실측과 일치하게 합니다.
        #  - 작업 영역이 1.5배(1908x1076)를 '여유 있게' 담을 수 있으면(QHD 이상) 1908x1076
        #  - 그 외(FHD 포함)는 기준 1.0배(1272x717) - 가장 작으면서 인식이 정확한 크기
        # (FHD에서 1908은 화면을 거의 꽉 채워 불편하므로 여유 조건을 둡니다)
        if ($workW -ge 2100 -and $workH -ge 1150) {
          $targetWidth = 1908
          $targetHeight = 1076
        } else {
          $targetWidth = 1272
          $targetHeight = 717
        }
        $targetX = [Math]::Min([Math]::Max($currentX, $workX), [Math]::Max($workX + $workW - $targetWidth, $workX))
        $targetY = [Math]::Min([Math]::Max($currentY, $workY), [Math]::Max($workY + $workH - $targetHeight, $workY))
        $sizeOk = ([Math]::Abs($currentWidth - $targetWidth) -le 4 -and
                   [Math]::Abs($currentHeight - $targetHeight) -le 4)
      } else {
        # nearest: 현재 너비를 유지하되 높이를 기준 비율로 계산.
        # 창이 기준 크기(1272)보다 작으면 글자가 작아져 OCR 오독이 생기므로
        # 최소한 기준 크기까지 키웁니다 (작업 영역 폭은 넘지 않음).
        $targetWidth = [Math]::Max($currentWidth, $referenceWidth)
        $targetWidth = [Math]::Min($targetWidth, $workW)
        $targetHeight = [int][Math]::Round($targetWidth * $referenceHeight / $referenceWidth)
        if ($targetHeight -gt $workH) {
          $targetHeight = $workH
          $targetWidth = [int][Math]::Round($targetHeight * $referenceWidth / $referenceHeight)
        }
        # 위치는 유지하되 작업 영역 밖(작업표시줄 포함)으로 나가지 않게만 보정
        $targetX = [Math]::Min([Math]::Max($currentX, $workX), [Math]::Max($workX + $workW - $targetWidth, $workX))
        $targetY = [Math]::Min([Math]::Max($currentY, $workY), [Math]::Max($workY + $workH - $targetHeight, $workY))
        # 몇 픽셀 수준의 오차는 무시해 불필요한 리사이즈를 막습니다
        $sizeOk = ([Math]::Abs($currentWidth - $targetWidth) -le 4 -and
                   [Math]::Abs($currentHeight - $targetHeight) -le 4)
      }

      $positionOk = ($currentX -eq $targetX -and $currentY -eq $targetY)
      if (-not ($sizeOk -and $positionOk)) {
        [HoneyNogiInput]::MoveWindow($game.MainWindowHandle, $targetX, $targetY, $targetWidth, $targetHeight, $true) | Out-Null
        Start-Sleep -Milliseconds 800
        Write-RunLog "[준비] 게임 창 정렬($windowMode): ${currentWidth}x${currentHeight}@($currentX,$currentY) -> ${targetWidth}x${targetHeight}@($targetX,$targetY)"
      }
    }
  }

  # 시작 화면 판정 전 전체 화면 팝업 정리 (2026-08-01 실사고: 물약 부족 팝업+협동 미션 완료
  # 화면이 겹친 채 재시도 워커가 시작되자 판독이 전부 가려져 3연속 즉사 → 정지. 아래
  # 출석/이벤트 처리(Clear-EventOverlay)는 구매 팝업을 모르므로 스윕을 먼저 돌립니다.
  # 스윕이 닫은 경우에만 1.2초 대기 후 재확인, 최대 2회 - 리뷰 조건. 콘텐츠 공통)
  for ($startSweep = 1; $startSweep -le 2; $startSweep++) {
    if (-not (Invoke-PurchasePopupSweep -Game $game)) { break }
    Start-Sleep -Milliseconds 1200
  }

  # 시작 시 화면 캡처가 안 되는 상태(원격 데스크톱 창 최소화 등)면 복구될 때까지 기다립니다.
  $startExitDetected = Test-ExitButton -Game $game
  while ($script:screenCaptureFailing) {
    Test-SafeStopDuringCaptureFail
    Start-Sleep -Seconds 2
    $startExitDetected = Test-ExitButton -Game $game
  }

  # 대분류 '생활'이면 전투 콘텐츠 대신 채집 사이클로 진행합니다 (v2.0.0 - 내부에서 exit).
  # 위 공통 처리(창 보정/구매 팝업 스윕)는 공유하되, 아래 Clear-EventOverlay 는 생활
  # 창(내 정보/생활 스킬)을 '알 수 없는 화면'으로 오판할 수 있어 이 분기를 먼저 둡니다 -
  # 출석/이벤트 정리는 사이클 내부에서 생활 창 정리 '후' 수행합니다 (리뷰 지적).
  # 아래 전투 시작 화면 판정(나가기/클리어/커스텀 보호)도 생활과 무관하므로 타지 않습니다.
  if ($mainCategory -eq 'life') {
    Invoke-LifeGatherCycle -Game $game
    throw '생활 사이클이 종료 코드 없이 반환됐습니다 - 내부 오류'
  }

  # 아침 6시 리셋 후 뜨는 출석/이벤트/데일리 팝업(스텔라 픽 등)이 화면을 덮고 있으면
  # 자동으로 넘깁니다. 던전/사냥터 흐름도 이 화면에 막혀 시작하지 못하므로
  # 콘텐츠 분기보다 먼저 처리합니다. (넘긴 뒤에는 시작 상태를 다시 읽습니다)
  if (Clear-EventOverlay -Game $game) {
    $startExitDetected = Test-ExitButton -Game $game
  }

  if ($script:customSpecInvalid) {
    throw "커스텀 반복 항목 형식이 올바르지 않습니다: '$env:HONEYNOGI_CUSTOM_ITEM' - GUI와 워커 버전을 확인해 주세요"
  }
  if ($script:customMode -and $contentCategory -eq 'abyss') {
    Write-RunLog "[어비스] 자동화 시작: $(Format-AbyssCustomItemLabel -Item $script:customItem)"
  }

  # 어비스 커스텀도 던전 커스텀과 같은 수동 진행분 보호 규칙을 사용합니다. 새 시작인데 이미
  # 던전 안/클리어·결과 화면이면 해당 판은 목록 항목으로 계상하지 않고 선택 화면까지만 정리한
  # 뒤 코드 10으로 본 항목을 다시 시작합니다. 오류 재시작은 정상적으로 현재 항목에 계상합니다.
  $startClearDetected = Test-DungeonClearPrompt -Game $game
  $startInsideDetected = Test-DungeonEntered -Game $game
  if ($script:customMode -and $contentCategory -eq 'abyss') {
    $script:customCleanupOnly = Test-CustomCleanupOnly -CustomMode $true -Restart $script:customRestart `
      -InsideAlready $startInsideDetected -OnResultScreen ($startExitDetected -or $startClearDetected)
    if ($script:customRecoveryOnly -and $startInsideDetected -and -not ($startExitDetected -or $startClearDetected)) {
      throw '완료 항목 마무리 복구 중 어비스 내부 화면이 감지됐습니다 - 항목을 다시 실행하지 않고 안전하게 중단합니다.'
    }
    if ($script:customRecoveryOnly -and (Test-AbyssSelectionScreen -Game $game)) {
      Write-RunLog '[커스텀] 어비스 선택 화면이 이미 준비돼 있습니다 - 완료 항목 재입장 없이 복구 완료'
      exit 0
    }
  }

  # 파티(파티원) 매칭은 흐름이 완전히 다릅니다: 메뉴 이동 없이 필드에서 '준비 완료'만
  # 담당하고, 클리어 후에도 선택 화면으로 복귀하지 않습니다 (전용 사이클 내부에서 종료).
  if ($contentCategory -ne 'dungeon' -and $contentCategory -ne 'hunting' -and (-not $deepMode) -and
      $dungeonMode -eq 'party' -and $abyssMatching -eq '파티(파티원)') {
    Invoke-AbyssPartyMemberCycle -Game $game
  }

  # 콘텐츠 선택이 '던전'/'심층던전'/'사냥터'면 각 전용 흐름으로 진행합니다 (아래 어비스 흐름과
  # 분리). 이 화면들은 어비스의 '알 수 없는 화면' 처리에 걸리면 안 되므로 이 분기가 먼저 옵니다.
  # 심층던전은 던전 사이클을 공유합니다 ($deepMode 가 재화·라벨·난이도 데이터를 치환).
  if ($contentCategory -eq 'dungeon' -or $deepMode) {
    Invoke-NormalDungeonCycle -Game $game
  }
  if ($contentCategory -eq 'hunting') {
    Invoke-HuntingGroundCycle -Game $game
  }

  # 이전 실행이 ESC 메뉴가 열린 채 끝났을 수 있으므로, 메뉴가 열려 있으면
  # 먼저 어비스 선택 화면으로 복귀부터 처리합니다.
  if (-not $startExitDetected -and (Test-AbyssMenu -Game $game)) {
    Write-RunLog '[어비스] 시작: ESC 메뉴 감지 - 선택 화면으로 복귀부터 진행'
    Return-ToAbyssSelection -Game $game -SafeStopExitCode 10
    Write-RunLog '[완료] 어비스 선택 화면 복귀 완료 (준비 실행 - 회차로 세지 않음)'
    # 던전을 돌지 않고 화면 복귀만 한 '준비 실행'은 코드 10으로 끝냅니다.
    # GUI가 이를 회차로 세지 않고 곧바로 본 회차를 시작하므로, 횟수 지정 모드에서
    # 실제 던전 실행 횟수가 부족해지지 않습니다.
    if ($script:customMode -and $script:customRecoveryOnly) { exit 0 }
    exit 10
  }

  if ($startExitDetected) {
    Write-RunLog '[어비스] 시작: 보상 화면(나가기) 감지 - 마무리부터 진행'
    if ($script:customMode -and -not $script:customCleanupOnly) { Write-CustomClearMarker }
    Click-GamePoint -Game $game -ReferenceX $ptExitButton[0] -ReferenceY $ptExitButton[1]
    Write-RunLog '[어비스] 나가기 클릭'
    Return-ToAbyssSelection -Game $game -SafeStopExitCode $(if ($script:customMode -and $script:customCleanupOnly) { 10 } else { 0 })
    Write-RunLog '[완료] 어비스 선택 화면 복귀 완료'
    if ($script:customMode -and $script:customCleanupOnly) { exit 10 }
    # 이전 회차의 클리어를 실제로 마무리한 실행이므로 정상 완료(코드 0)로 계상합니다
    exit 0
  }

  if ($startClearDetected) {
    Write-RunLog '[어비스] 시작: 클리어 화면 감지 - 마무리부터 진행'
    Write-RunLog '[어비스] 클리어 화면 터치'
    # 등급 연출 중에는 터치가 무시될 수 있어(다른 PC 실측: 터치 후에도 '화면을 터치'가
    # 그대로 남음) 나가기 버튼이 보일 때까지 3초 간격으로 다시 터치합니다.
    Invoke-ClickUntil -Game $game -Point $ptClearCenter -Description '클리어 화면 터치(나가기 버튼 표시)' `
      -TimeoutSeconds ($timeoutExit + 15) -ReclickEverySeconds 3 -Condition { Test-ExitButton -Game $game } `
      -SourceCondition { Test-DungeonClearPrompt -Game $game }
    Write-RunLog '[어비스] 나가기 버튼 감지'
    if ($script:customMode -and -not $script:customCleanupOnly) { Write-CustomClearMarker }
    Focus-Game -Game $game
    Click-GamePoint -Game $game -ReferenceX $ptExitButton[0] -ReferenceY $ptExitButton[1]
    Write-RunLog '[어비스] 나가기 클릭'
    Return-ToAbyssSelection -Game $game -SafeStopExitCode $(if ($script:customMode -and $script:customCleanupOnly) { 10 } else { 0 })
    Write-RunLog '[완료] 어비스 선택 화면 복귀 완료'
    if ($script:customMode -and $script:customCleanupOnly) { exit 10 }
    # 이전 회차의 클리어를 실제로 마무리한 실행이므로 정상 완료(코드 0)로 계상합니다
    exit 0
  }

  # 게임플레이 화면(HUD 표시) 중 '필드(던전 밖)'에 서 있는 상태면, 카드 클릭을 시도하기 전에
  # 먼저 ESC → 어비스 메뉴를 통해 어비스 선택 화면으로 이동합니다 (매크로 시작 기본 동선).
  # 던전 안이면 이 분기를 건너뛰고 아래의 '던전 입장 상태' 재개 흐름을 그대로 탑니다.
  if ((Test-HomeEndEscHud -Game $game) -and -not (Test-InDungeonQuest -Game $game)) {
    Write-RunLog '[어비스] 시작: 필드 상태 감지 - ESC → 어비스로 선택 화면 이동'
    # 복귀 도중 안전 중지는 복구 완료 이전이므로 recoveryOnly 여도 10 (교차 리뷰 지적 -
    # 0이면 선택 화면 복구 전에 완료 마커·진행 위치가 전진함. 복구 완료의 exit 0 은 아래 줄)
    Return-ToAbyssSelection -Game $game -SafeStopExitCode 10
    Write-RunLog '[완료] 어비스 선택 화면 복귀 완료 (준비 실행 - 회차로 세지 않음)'
    if ($script:customMode -and $script:customRecoveryOnly) { exit 0 }
    # 화면 복귀만 수행한 준비 실행: 회차로 세지 않도록 코드 10으로 종료 (위 ESC 메뉴 분기와 동일)
    exit 10
  }

  if ($script:customMode -and $script:customRecoveryOnly -and -not $startInsideDetected) {
    # 선택/메뉴/결과/필드 복구는 위에서 모두 처리했습니다. 남은 상태가 상세 화면이면 뒤로 나가
    # 선택 화면까지 확인하고 완료하며, 그 밖의 불명확한 화면에서는 재입장하지 않습니다.
    $recoveryTitle = Get-DetailTitleText -Game $game
    $recoveryKnownDetail = $false
    foreach ($recoveryKeyword in $allDungeonKeywords) {
      if ($recoveryTitle.Contains($recoveryKeyword)) { $recoveryKnownDetail = $true; break }
    }
    if ($recoveryKnownDetail) {
      Focus-Game -Game $game
      Click-GamePoint -Game $game -ReferenceX $ptDetailBack[0] -ReferenceY $ptDetailBack[1]
      Wait-ForScreen -Game $game -TimeoutSeconds $timeoutAbyssSelect -Description '어비스 선택 화면(완료 항목 복구)' -Condition {
        Test-AbyssSelectionScreen -Game $game
      }
      Write-RunLog '[커스텀] 어비스 상세 화면에서 선택 화면으로 복귀 - 완료 항목 재입장 없이 복구 완료'
      exit 0
    }
    throw "완료 항목 마무리 복구 중 알 수 없는 화면이 감지됐습니다 (상세 제목: '$recoveryTitle') - 항목을 재입장하지 않고 중단합니다."
  }

  if ($startInsideDetected) {
    Write-RunLog '[어비스] 시작: 던전 안 상태 감지 - 클리어 대기부터 재개'
  } else {
    # 시작 시 이미 어떤 던전의 상세 화면이 열려 있는지 "제목"으로 판단합니다.
    # (혼자하기/함께하기 어느 탭이든 제목은 항상 표시되므로 탭 상태와 무관하게 동작)
    # 다른 던전의 상세 화면이면 뒤로가기(<)로 선택 화면에 나간 뒤 올바른 카드부터 다시 진행합니다.
    $needCardClick = $true
    $currentTitle = Get-DetailTitleText -Game $game
    $isKnownDetail = $false
    foreach ($titleKeyword in $allDungeonKeywords) {
      if ($currentTitle.Contains($titleKeyword)) { $isKnownDetail = $true; break }
    }
    if ($isKnownDetail) {
      if ($currentTitle.Contains($dungeonMatch)) {
        $needCardClick = $false
      } else {
        Write-RunLog "[어비스] 시작: 다른 던전 상세 화면 감지 - 뒤로 나가서 다시 선택"
        Focus-Game -Game $game
        Click-GamePoint -Game $game -ReferenceX $ptDetailBack[0] -ReferenceY $ptDetailBack[1]
        Wait-ForScreen -Game $game -TimeoutSeconds $timeoutAbyssSelect -Description '어비스 던전 선택 화면' -Condition {
          Test-AbyssSelectionScreen -Game $game
        }
      }
    }
    if ($needCardClick) {
      Write-RunLog "[어비스] $selectedDungeon 카드 클릭"
      Invoke-ClickUntil -Game $game -Point $dungeonCard -Description "$selectedDungeon 상세 화면" `
        -TimeoutSeconds $timeoutDetail -Condition { Test-DetailTitleMatches -Game $game } `
        -SourceCondition { Test-AbyssSelectionScreen -Game $game }
    }
    Write-RunLog "[어비스] $selectedDungeon 상세 화면 확인"

    # 미개발 던전: 상세 화면 진입까지만 지원하고 여기서 정상 종료합니다(종료 코드 3).
    if ($dungeonStage -ne 'full') {
      Write-RunLog "[안내] $selectedDungeon 은(는) 상세 화면 진입까지만 구현되어 있습니다. 이후 자동화는 미개발이라 여기서 종료합니다."
      exit 3
    }

    # 난이도 선택 동작 (설정된 난이도가 있으면 상세 화면에서 글자를 OCR로 찾아 클릭).
    # 혼자하기/함께하기 공용 - 사람이 하는 순서처럼 이동/입장 전에 먼저 난이도를 확정합니다.
    # (지옥1 등 난이도가 새로 추가되어 버튼 위치가 바뀌어도 글자 탐색이라 그대로 동작합니다.
    #  이미 선택돼 있는 난이도를 다시 클릭해도 부작용이 없어 상태 확인 없이 클릭합니다.)
    $selectDungeonDifficulty = {
      if ($dungeonDifficulty) {
        $difficultyKey = $dungeonDifficulty -replace '\s', ''
        $difficultySearch = $difficultyKey.Substring(0, [Math]::Min(2, $difficultyKey.Length))
        # 정확 일치 우선: '지옥1'을 찾을 때 '지옥10'을 잘못 잡지 않도록 단어 전체 일치를 먼저 봅니다.
        $difficultyPoint = Find-GameTextPoint -Game $game -ReferenceX $rgDifficultyTabs[0] -ReferenceY $rgDifficultyTabs[1] `
          -RegionWidth $rgDifficultyTabs[2] -RegionHeight $rgDifficultyTabs[3] -SearchText $difficultySearch -ExactText $difficultyKey
        if ($difficultyPoint) {
          Focus-Game -Game $game
          Click-ScreenPoint -X $difficultyPoint.X -Y $difficultyPoint.Y
          Write-RunLog "[어비스] 난이도 '$dungeonDifficulty' 클릭"
          Start-Sleep -Milliseconds 800
          # 사후 검증: 클릭이 빗나가 다른 난이도로 바뀌지 않았는지 선택 강조로 확인 (첫 좌표 재사용).
          # 커스텀(항목별 명시 난이도)은 확인 실패 시 정지 - 던전 커스텀의 -Strict 계약과 통일
          # (2026-08-01 전수 점검: 어비스만 경고 진행이라 오난이도 판이 항목 완료로 계상될 수 있었음)
          $abyssDiffConfirmed = [bool](Confirm-DifficultySelected -Game $game -ClickPoint $difficultyPoint -Label $dungeonDifficulty)
          if ($script:customMode -and -not $abyssDiffConfirmed) {
            Write-RunLog "[완료] 난이도 '$dungeonDifficulty' 선택을 확정하지 못했습니다 - 오난이도 판 방지를 위해 정지합니다"
            exit 4
          }
        } elseif ($script:customMode) {
          # 커스텀 격상: 명시 난이도 글자를 못 찾으면 현재 난이도로 진행하지 않습니다
          Write-RunLog "[완료] 상세 화면에서 난이도 '$dungeonDifficulty' 글자를 찾지 못했습니다 - 오난이도 판 방지를 위해 정지합니다"
          exit 4
        } else {
          Write-RunLog "[경고] 상세 화면에서 난이도 '$dungeonDifficulty' 글자를 찾지 못했습니다 - 현재 선택된 난이도로 진행합니다"
        }
      }
    }

    # 입장 방식 탭 클릭: 혼자하기는 명시적으로 탭을 한 번 클릭해 확정한 뒤 입장합니다.
    # 함께하기는 '우연한 만남'/'파티찾기'/'파티(파티장)' 세 매칭 방식을 지원합니다.
    if ($dungeonMode -eq 'party') {
      Click-GamePoint -Game $game -ReferenceX $ptPartyTab[0] -ReferenceY $ptPartyTab[1]
      Write-RunLog '[어비스] 함께하기 탭 클릭'
      # 함께하기 화면(하단 입장하기 버튼)이 뜰 때까지 대기.
      # 캐릭터가 던전에서 멀면 '입장하기' 대신 '이동하기' 단일 버튼이 표시되므로
      # (실측 2026-07-17: 다른 PC에서 함께하기 탭인데 혼자하기 버튼 영역에 '이동') 그 경우도 기다립니다.
      Wait-ForScreen -Game $game -TimeoutSeconds 10 -Description '함께하기 화면(입장하기/이동하기 버튼)' -Condition {
        (Test-PartyDetailScreen -Game $game) -or ((Get-EnterButtonText -Game $game) -match '이동|동하')
      }
      # 사후 검증: 두 탭의 입장 버튼 영역이 겹쳐 위 대기가 혼자하기 화면에서도 통과될 수
      # 있으므로, 탭 선택 배경색(함께하기=보라)으로 실제 전환을 확인합니다
      Confirm-TabSelected -Game $game -Point $ptPartyTab -Label '함께하기' | Out-Null

      # 캐릭터가 멀리 있으면: 이동하기 클릭 → 자동 이동 → 도착하면 상세 화면이 다시 열림
      # (혼자하기 탭의 이동 처리와 동일한 패턴 - '반드시 한 번은 클릭' 포함)
      if (-not (Test-PartyDetailScreen -Game $game) -and ((Get-EnterButtonText -Game $game) -match '이동|동하')) {
        Write-RunLog '[어비스] 이동하기 클릭 - 던전까지 자동 이동'
        $moveDeadline = (Get-Date).AddSeconds(30)
        $moveClicked = $false
        $goneCount = 0
        while ((Get-Date) -lt $moveDeadline) {
          if ((Get-EnterButtonText -Game $game) -match '이동|동하') {
            $goneCount = 0
            Focus-Game -Game $game
            Click-GamePoint -Game $game -ReferenceX $ptEnter[0] -ReferenceY $ptEnter[1]
            $moveClicked = $true
            Start-Sleep -Milliseconds 1500
          } else {
            $goneCount++
            if ($goneCount -ge 2 -and $moveClicked) { break }
            Start-Sleep -Milliseconds 500
          }
        }
        if (-not $moveClicked) {
          Write-RunLog '[경고] 이동하기 버튼을 클릭하지 못했습니다 - 화면 상태를 확인해 주세요'
        }
        # 도착하면 상세 화면이 다시 열립니다 (열리는 탭 상태가 다를 수 있어 어느 쪽 버튼이든 인정)
        Wait-ForScreen -Game $game -TimeoutSeconds $timeoutTravel -Description '던전 도착(상세 화면)' -Condition {
          (Test-PartyDetailScreen -Game $game) -or (Test-DetailScreen -Game $game)
        }
        Write-RunLog '[어비스] 던전 도착 - 상세 화면 다시 열림'
        Focus-Game -Game $game
        Click-GamePoint -Game $game -ReferenceX $ptPartyTab[0] -ReferenceY $ptPartyTab[1]
        Write-RunLog '[어비스] 함께하기 탭 클릭 (도착 후 재확정)'
        Start-Sleep -Milliseconds 800
        Wait-ForScreen -Game $game -TimeoutSeconds 10 -Description '함께하기 화면(입장하기 버튼)' -Condition {
          Test-PartyDetailScreen -Game $game
        }
        Confirm-TabSelected -Game $game -Point $ptPartyTab -Label '함께하기' | Out-Null
      }

      # 난이도 확정 (함께하기는 지옥 난이도까지 같은 알약 줄에서 OCR로 찾아 클릭)
      & $selectDungeonDifficulty

      # 하단 버튼은 토글 상태에 따라 달라집니다 (실측):
      #   토글 켜짐 = 넓은 단일 '입장하기' / 꺼짐 = '파티 찾기' + '입장하기' 2버튼.
      # 그래서 매칭 방식에 맞게 토글부터 확정한 뒤 해당 버튼을 클릭합니다.
      if ($abyssMatching -eq '파티(파티장)') {
        # 파티장: 직접 짠 파티 그대로 입장합니다 (빈자리를 매칭으로 채우지 않음 - 사용자 결정).
        # 파티가 가득 차면(4/4) '우연한 만남' 토글이 비활성화되지만(실측), 인원이 부족한
        # 상태에서 토글이 켜져 있으면 모르는 사람이 채워지므로 꺼짐을 확정하고 입장합니다.
        $toggleState = Get-ChanceToggleState -Game $game -Point $ptAbyssChanceToggle
        if ($toggleState -eq 'on') {
          Focus-Game -Game $game
          Click-GamePoint -Game $game -ReferenceX $ptAbyssChanceToggle[0] -ReferenceY $ptAbyssChanceToggle[1]
          Start-Sleep -Milliseconds 900
          # 'off' 확인만 성공 로그 - unknown 을 '끔'으로 보고하지 않습니다 (2026-08-01 3차
          # 점검 보류 조건: 파티장은 정지 없이 경고 유지하되 성공/미확인 로그는 구분)
          $leaderToggleAfter = Get-ChanceToggleState -Game $game -Point $ptAbyssChanceToggle
          if ($leaderToggleAfter -eq 'off') {
            Write-RunLog "[어비스] '우연한 만남' 토글 끔 - 짠 파티 그대로 입장합니다"
          } else {
            Write-RunLog "[경고] '우연한 만남' 토글 끄기를 확인하지 못했습니다 (상태: $leaderToggleAfter) - 빈자리가 매칭으로 채워질 수 있습니다"
          }
        } elseif ($toggleState -eq 'off') {
          Write-RunLog "[어비스] '우연한 만남' 토글 꺼짐 확인 - 짠 파티 그대로 입장합니다"
        } else {
          Write-RunLog "[경고] '우연한 만남' 토글 상태를 판별하지 못했습니다(화면 확인 불가) - 클릭 없이 진행합니다"
        }

        # 입장하기 클릭. 접수되면 상세 화면이 닫히고 파티 패널의 버튼이 '입장 취소'로
        # 바뀝니다 (실측). '입장 취소'에도 '입장' 글자가 있어 그 자리를 다시 누르면 준비
        # 요청이 취소되므로(17:00 로그 실측 사고), '취소'가 보이면 성공으로 판정하고
        # 재클릭은 버튼이 여전히 '입장하기'로 남아 있을 때(클릭 빗나감)만 합니다.
        # 인원이 부족한 채 토글 없이 입장하면 '권장 인원보다 적은 인원으로 도전합니다'
        # 확인 팝업이 뜨는데(실측), 확인(도전하기)이 Space 조작이라 Space 로 넘깁니다.
        Focus-Game -Game $game
        Click-GamePoint -Game $game -ReferenceX $ptPartyEnter[0] -ReferenceY $ptPartyEnter[1]
        Write-RunLog '[어비스] 입장하기 클릭 (파티장) - 파티원 준비 대기'
        $enterConfirmed = $false
        $enterDeadline = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $enterDeadline) {
          Start-Sleep -Seconds 3
          if (Test-InDungeonQuest -Game $game) { $enterConfirmed = $true; break }
          $challengeText = (Get-GameOcrText -Game $game) -replace '\s', ''
          if ($challengeText -match '도전하') {
            Focus-Game -Game $game
            Press-KeyOnce -VirtualKey ([byte]32)   # Space = 도전하기 확인
            Write-RunLog '[어비스] 인원 부족 도전 확인 팝업 - Space로 도전하기'
            continue
          }
          $partyBtnText = (Get-GameRegionOcrText -Game $game -ReferenceX $rgPartyEnterBtn[0] -ReferenceY $rgPartyEnterBtn[1] `
            -RegionWidth $rgPartyEnterBtn[2] -RegionHeight $rgPartyEnterBtn[3] -Scale 4 -Engine $ocrKoreanEngine) -replace '\s', ''
          if ($partyBtnText -match '취소') {
            Write-RunLog "[어비스] 준비 대기 시작 확인 (버튼: 입장 취소)"
            $enterConfirmed = $true
            break
          }
          if ($partyBtnText -match '입장하기|장하기') {
            Write-RunLog '[어비스] 입장하기가 눌리지 않은 것 같아 다시 클릭합니다'
            Focus-Game -Game $game
            Click-GamePoint -Game $game -ReferenceX $ptPartyEnter[0] -ReferenceY $ptPartyEnter[1]
          }
        }
        if (-not $enterConfirmed) {
          Write-RunLog "[경고] '입장 취소' 버튼(준비 대기 시작)을 확인하지 못했습니다 - 그대로 입장 대기를 진행합니다"
        }
      } elseif ($abyssMatching -eq '우연한 만남') {
        # '우연한 만남' 토글 확인 - 꺼져 있으면 켭니다 (초록 = 켜짐, 픽셀 판별)
        $toggleState = Get-ChanceToggleState -Game $game -Point $ptAbyssChanceToggle
        if ($toggleState -eq 'unknown') {
          Write-RunLog "[경고] '우연한 만남' 토글 상태를 판별하지 못했습니다(화면 확인 불가) - 클릭 없이 현재 상태로 진행합니다"
        } elseif ($toggleState -ne 'on') {
          Focus-Game -Game $game
          Click-GamePoint -Game $game -ReferenceX $ptAbyssChanceToggle[0] -ReferenceY $ptAbyssChanceToggle[1]
          Start-Sleep -Milliseconds 900
          if ((Get-ChanceToggleState -Game $game -Point $ptAbyssChanceToggle) -eq 'on') {
            Write-RunLog "[어비스] '우연한 만남' 토글 켬"
          } else {
            Write-RunLog "[경고] '우연한 만남' 토글이 켜진 것을 확인하지 못했습니다 - 현재 상태로 진행합니다"
          }
        } else {
          Write-RunLog "[어비스] '우연한 만남' 토글 켜짐 확인"
        }

        # 입장하기 클릭 → 상세 화면이 닫히고 필드에서 매칭 대기가 시작됩니다
        Write-RunLog '[어비스] 입장하기 클릭 - 파티원 대기 (모이면 자동 입장)'
        Invoke-ClickUntil -Game $game -Point $ptPartyEnter -Description '입장하기 클릭 확인(상세 화면 종료)' `
          -TimeoutSeconds 30 -Condition { -not (Test-PartyDetailScreen -Game $game) } `
          -SourceCondition { Test-PartyDetailScreen -Game $game }
      } else {
        # 파티찾기: 토글이 켜져 있으면 '파티 찾기' 버튼이 없고 그 자리가 넓은 입장하기라
        # 잘못 누르면 우연한 만남으로 입장돼 버립니다. 반드시 토글을 먼저 끕니다.
        $toggleState = Get-ChanceToggleState -Game $game -Point $ptAbyssChanceToggle
        # unknown 재판독 + 확인 불가 시 정지 - 던전 파티찾기와 같은 fail-closed 계약
        # (2026-08-01 전수 점검: '꺼짐으로 보고 진행'은 토글이 켜져 있으면 혼자 오입장. 리뷰 승인)
        for ($toggleProbe = 1; $toggleProbe -le 3 -and $toggleState -eq 'unknown'; $toggleProbe++) {
          Start-Sleep -Milliseconds 900
          $toggleState = Get-ChanceToggleState -Game $game -Point $ptAbyssChanceToggle
        }
        if ($toggleState -eq 'unknown') {
          Write-RunLog "[완료] '우연한 만남' 토글 상태를 확인하지 못했습니다 - 오입장을 막기 위해 정지합니다. 화면을 확인하고 다시 시작해 주세요."
          exit 4
        }
        if ($toggleState -eq 'on') {
          Focus-Game -Game $game
          Click-GamePoint -Game $game -ReferenceX $ptAbyssChanceToggle[0] -ReferenceY $ptAbyssChanceToggle[1]
          Start-Sleep -Milliseconds 900
          # 끄기 확인도 'off' 확정을 요구합니다 ('on'만 아니면 통과 → unknown 이 꺼짐으로 둔갑 방지)
          $toggleAfterOff = Get-ChanceToggleState -Game $game -Point $ptAbyssChanceToggle
          for ($toggleProbe = 1; $toggleProbe -le 3 -and $toggleAfterOff -ne 'off'; $toggleProbe++) {
            Start-Sleep -Milliseconds 900
            $toggleAfterOff = Get-ChanceToggleState -Game $game -Point $ptAbyssChanceToggle
          }
          if ($toggleAfterOff -eq 'on') {
            throw "'우연한 만남' 토글을 끄지 못해 파티찾기를 진행할 수 없습니다 (토글이 켜진 상태에서는 파티 찾기 버튼이 없음)"
          }
          if ($toggleAfterOff -ne 'off') {
            # 최초 unknown 과 같은 조건부 정지(코드 4)로 통일 (교차 리뷰 지적 - 던전과 동일)
            Write-RunLog "[완료] '우연한 만남' 토글을 끈 뒤 상태를 확인하지 못했습니다 - 오입장을 막기 위해 정지합니다. 화면을 확인하고 다시 시작해 주세요."
            exit 4
          }
          Write-RunLog "[어비스] '우연한 만남' 토글 끔 (파티찾기 준비)"
        } else {
          Write-RunLog "[어비스] '우연한 만남' 토글 꺼짐 확인 (파티찾기 준비)"
        }

        # 파티 찾기 클릭 → 상세 화면이 닫히고 필드 좌상단에 '파티 찾는 중' 타이머가 뜹니다
        Write-RunLog '[어비스] 파티 찾기 클릭 - 매칭 대기'
        Invoke-ClickUntil -Game $game -Point $ptPartyFind -Description '파티 찾기 클릭 확인(상세 화면 종료)' `
          -TimeoutSeconds 30 -Condition { -not (Test-PartyDetailScreen -Game $game) } `
          -SourceCondition { Test-PartyDetailScreen -Game $game }
      }

      # 매칭 완료 → 자동 입장 감지: 매칭 중에는 캐릭터가 필드에 있어 HUD로는 구분이
      # 안 되므로, 던전 안에서만 퀘스트 추적기에 뜨는 '<던전 이름> 클리어' 목표로 판정합니다.
      if ($abyssMatching -eq '파티(파티장)') {
        Write-RunLog '[어비스] 파티원 준비 대기 중... (전원 준비되면 자동 입장)'
      } else {
        Write-RunLog '[어비스] 파티 매칭 대기 중... (끝나면 자동 입장)'
      }
      Wait-ForScreen -Game $game -TimeoutSeconds $timeoutPartyMatch -Description '파티 매칭 완료 후 던전 입장' -Condition {
        if (Invoke-PurchasePopupSweep -Game $game) { return $false }
        Test-InDungeonQuest -Game $game
      }
      Write-RunLog '[어비스] 던전 입장 완료 감지'
    } else {
    Click-GamePoint -Game $game -ReferenceX $ptSoloTab[0] -ReferenceY $ptSoloTab[1]
    Write-RunLog '[어비스] 혼자하기 탭 클릭'
    # 혼자하기 화면의 하단 버튼(입장하기 또는 이동하기)이 나타난 것을 확인합니다
    # (함께하기 탭에서 전환된 경우 화면이 바뀌는 시간을 안전하게 기다림)
    # OCR이 '이'를 'OI'처럼 깨뜨려도('OI동하기' 실측) 살아남는 '장하'/'동하'까지 함께 봅니다.
    Wait-ForScreen -Game $game -TimeoutSeconds 10 -Description '혼자하기 화면(입장하기/이동하기 버튼)' -Condition {
      (Get-EnterButtonText -Game $game) -match '입장|이동|장하|동하'
    }
    # 사후 검증: 탭 선택 배경색(혼자하기=청록)으로 실제 전환 확인 (빗나감 시 1회 재클릭)
    Confirm-TabSelected -Game $game -Point $ptSoloTab -Label '혼자하기' | Out-Null

    # 난이도 확정 (위에서 정의한 공용 동작)
    & $selectDungeonDifficulty

    # 캐릭터가 던전에서 먼 필드에 있으면 버튼이 '입장하기' 대신 '이동하기'로 표시됩니다.
    # 이동하기를 누르면 캐릭터가 던전까지 자동 이동하고, 도착하면 상세 화면이 다시 열리며
    # '입장하기'로 바뀝니다. 그때 혼자하기 탭/난이도를 다시 확정한 뒤 입장 단계로 갑니다.
    if ((Get-EnterButtonText -Game $game) -match '이동|동하') {
      Write-RunLog '[어비스] 이동하기 클릭 - 던전까지 자동 이동'
      # 버튼 글자가 '이동'으로 보이는 동안 계속 클릭하고, 두 번 연속 안 보여야 넘어갑니다.
      # (OCR이 한 번 삐끗하면 클릭 없이 넘어가던 문제 수정 - 반드시 한 번은 클릭)
      $moveDeadline = (Get-Date).AddSeconds(30)
      $moveClicked = $false
      $goneCount = 0
      while ((Get-Date) -lt $moveDeadline) {
        if ((Get-EnterButtonText -Game $game) -match '이동|동하') {
          $goneCount = 0
          Focus-Game -Game $game
          Click-GamePoint -Game $game -ReferenceX $ptEnter[0] -ReferenceY $ptEnter[1]
          $moveClicked = $true
          Start-Sleep -Milliseconds 1500
        } else {
          $goneCount++
          if ($goneCount -ge 2 -and $moveClicked) { break }
          Start-Sleep -Milliseconds 500
        }
      }
      if (-not $moveClicked) {
        Write-RunLog '[경고] 이동하기 버튼을 클릭하지 못했습니다 - 화면 상태를 확인해 주세요'
      }
      Wait-ForScreen -Game $game -TimeoutSeconds $timeoutTravel -Description '던전 도착(상세 화면의 입장하기 버튼)' -Condition {
        Test-DetailScreen -Game $game
      }
      Write-RunLog '[어비스] 던전 도착 - 상세 화면 다시 열림'
      Focus-Game -Game $game
      Click-GamePoint -Game $game -ReferenceX $ptSoloTab[0] -ReferenceY $ptSoloTab[1]
      Write-RunLog '[어비스] 혼자하기 탭 클릭 (도착 후 재확정)'
      Start-Sleep -Milliseconds 800
      Confirm-TabSelected -Game $game -Point $ptSoloTab -Label '혼자하기' | Out-Null
      # 도착 후 상세 화면이 새로 열렸으니 난이도도 다시 확정합니다
      & $selectDungeonDifficulty
    }

    Write-RunLog '[어비스] 입장하기 클릭'
    # 클릭하는 순간 사용자가 마우스를 움직이면 클릭이 빗나갈 수 있습니다(커서 이동 후
    # 클릭 사이의 짧은 틈에 커서가 옮겨지면 그 자리를 클릭하게 됨). 그래서 상세 화면이
    # 사라진 것(=입장이 접수되어 로딩 시작)이 확인될 때까지 5초마다 다시 클릭합니다.
    Invoke-ClickUntil -Game $game -Point $ptEnter -Description '입장하기 클릭 확인(상세 화면 종료)' `
      -TimeoutSeconds 30 -Condition { -not (Test-DetailScreen -Game $game) } `
      -SourceCondition { Test-DetailScreen -Game $game }
    Write-RunLog '[어비스] 던전 로딩 중...'
    Start-Sleep -Seconds 1
    Wait-ForScreen -Game $game -TimeoutSeconds $timeoutEntry -Description '던전 입장 완료 화면' -Condition {
      if (Invoke-PurchasePopupSweep -Game $game) { return $false }
      Test-DungeonEntered -Game $game
    }
    Write-RunLog '[어비스] 던전 입장 완료 감지'
    }
  }

  # 입장 직후 키 입력 (config afterEntry.keys 중 enabled 만 - 공통 헬퍼)
  Invoke-AfterEntryKeys -Game $game -LogPrefix '[어비스]'

  Write-RunLog '[어비스] 클리어 화면 감지 대기 시작'
  $clearOutcome = Wait-ForDungeonClearScreen -Game $game -TimeoutSeconds $timeoutClear

  # 사용자가 직접 화면을 넘긴 경우(reward/selection)에는 해당 단계를 건너뛰고 이어갑니다.
  if ($clearOutcome -eq 'clear') {
    Write-RunLog '[어비스] 클리어 화면 터치'
    # 등급 연출 중에는 터치가 무시될 수 있어(다른 PC 실측: 터치 후에도 '화면을 터치'가
    # 그대로 남음) 나가기 버튼이 보일 때까지 3초 간격으로 다시 터치합니다.
    Invoke-ClickUntil -Game $game -Point $ptClearCenter -Description '클리어 화면 터치(나가기 버튼 표시)' `
      -TimeoutSeconds ($timeoutExit + 15) -ReclickEverySeconds 3 -Condition { Test-ExitButton -Game $game } `
      -SourceCondition { Test-DungeonClearPrompt -Game $game }
    Write-RunLog '[어비스] 나가기 버튼 감지'
  }
  if ($script:customMode -and -not $script:customCleanupOnly) {
    # 결과/선택 화면 도달 = 현재 어비스 항목의 클리어 확정. 이후 나가기·선택 화면 복귀에서
    # 끊겨도 GUI가 같은 판을 다시 입장하지 않고 마무리만 복구할 수 있게 먼저 기록합니다.
    Write-CustomClearMarker
  }
  if ($clearOutcome -ne 'selection') {
    Focus-Game -Game $game
    Click-GamePoint -Game $game -ReferenceX $ptExitButton[0] -ReferenceY $ptExitButton[1]
    Write-RunLog '[어비스] 나가기 클릭'
  }
  Return-ToAbyssSelection -Game $game -SafeStopExitCode $(if ($script:customMode -and $script:customCleanupOnly) { 10 } else { 0 })
  Write-RunLog '[완료] 어비스 선택 화면 복귀 완료'
  if ($script:customMode -and $script:customCleanupOnly) { exit 10 }
} catch {
  Write-RunLog "[오류] $($_.Exception.Message)"

  # ===== 오류 진단 덤프 =====
  # 실패 원인을 파악할 수 있도록 게임 창 스크린샷과 주요 OCR 원문을 Log 폴더에 남깁니다.
  # 스크린샷과 로그 사본은 같은 타임스탬프로 세트가 됩니다 (error_시각.png + error_시각.log).
  # 시각은 읽기 쉽게 h/m/s 표기를 씁니다 (예: error_20260718_h21m49s09.png).
  $diagStamp = Get-Date -Format 'yyyyMMdd_\hHH\mmm\sss'
  # 이미지와 로그가 각각 이름을 조합하지 않고 하나의 기본 이름을 공유하게 해, 오류 세트의
  # 날짜·시각 접미사가 반드시 동일하도록 고정합니다.
  $diagBaseName = "error_$diagStamp"
  try {
    if ($game) {
      $diagRect = New-Object HoneyNogiInput+RECT
      if ([HoneyNogiInput]::GetWindowRect($game.MainWindowHandle, [ref]$diagRect)) {
        $diagW = $diagRect.Right - $diagRect.Left
        $diagH = $diagRect.Bottom - $diagRect.Top
        Write-RunLog "[진단] 게임 창: ${diagW}x${diagH} @ L$($diagRect.Left),T$($diagRect.Top)"

        $diagShot = Join-Path $logDir "$diagBaseName.png"
        $diagBmp = New-Object System.Drawing.Bitmap $diagW, $diagH
        $diagGfx = [System.Drawing.Graphics]::FromImage($diagBmp)
        try {
          $diagGfx.CopyFromScreen($diagRect.Left, $diagRect.Top, 0, 0, $diagBmp.Size)
          $diagBmp.Save($diagShot, [System.Drawing.Imaging.ImageFormat]::Png)
          Write-RunLog "[진단] 화면 캡처 저장: $diagShot"
        } finally {
          $diagGfx.Dispose()
          $diagBmp.Dispose()
        }

        # 오래된 진단 스크린샷 정리: 최근 것만 남기고(기본 10개) 나머지는 삭제해
        # Log 폴더에 무한정 쌓이지 않게 합니다. config 의 diagnostics.keepScreenshots 로 조절.
        $keepShots = Get-ConfigInteger $config @('diagnostics', 'keepScreenshots') 10 0 1000
        if ($keepShots -gt 0) {
          $oldShots = @(Get-ChildItem -LiteralPath $logDir -Filter 'error_*.png' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -Skip $keepShots)
          foreach ($old in $oldShots) {
            Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
          }
          if ($oldShots.Count -gt 0) {
            Write-RunLog "[진단] 오래된 진단 스크린샷 $($oldShots.Count)개 정리(최근 ${keepShots}개 유지)"
          }
        }

        if ($contentCategory -eq 'dungeon' -or $deepMode) {
          # 던전 구역 선택/진입 오류는 실제 클릭 게이트와 같은 넓은 영역을 기록해야 합니다.
          # 어비스용 좁은 입장 영역을 남기면 버튼이 보여도 무관한 글자만 찍혀 원인 분석을 흐립니다.
          $diagDetail = Get-DgStageEnterButtonText -Game $game
          Write-RunLog "[진단] 던전 구역 진입 버튼 영역 OCR: '$diagDetail'"
        } else {
          $diagDetail = Get-GameRegionOcrText -Game $game -ReferenceX $rgEnterButton[0] -ReferenceY $rgEnterButton[1] `
            -RegionWidth $rgEnterButton[2] -RegionHeight $rgEnterButton[3] -Scale 3 -Engine $ocrKoreanEngine
          Write-RunLog "[진단] 입장하기 영역 OCR: '$diagDetail'"
        }
        $diagHud = Get-GameRegionOcrText -Game $game -ReferenceX $rgHomeEndEsc[0] -ReferenceY $rgHomeEndEsc[1] `
          -RegionWidth $rgHomeEndEsc[2] -RegionHeight $rgHomeEndEsc[3] -Scale 5 -Engine $ocrEnglishEngine -BinaryWhiteText
        Write-RunLog "[진단] HUD 영역 OCR: '$diagHud'"
        $diagBottom = Get-GameOcrText -Game $game
        Write-RunLog "[진단] 하단 문구 영역 OCR: '$diagBottom'"
      }
    }
  } catch {
    Write-RunLog "[진단] 진단 수집 실패: $($_.Exception.Message)"
  }

  # ===== 오류 로그 사본 보관 =====
  # 현재 사용 중인 기본/복구 로그 파일은 다음 회차가 시작되면 보관되므로, 오류 순간의 로그 전문을
  # 스크린샷과 같은 이름(error_시각.log)으로 복사해 세트로 남깁니다.
  # 위의 [오류]/[진단] 줄까지 모두 기록된 뒤에 복사하도록 맨 마지막에 수행합니다.
  try {
    $diagLog = Join-Path $logDir "$diagBaseName.log"
    Copy-Item -LiteralPath $script:runLogTargetPath -Destination $diagLog -Force
    # 좌표 버전 게이트 상태는 사용자 로그(GUI 표시)에는 보이지 않게, 오류 사본에만 직접 기록합니다
    if ($script:staleCoordsIgnored) {
      Add-Content -LiteralPath $diagLog -Encoding UTF8 -ErrorAction SilentlyContinue `
        -Value '[분석용] config 좌표가 구버전(coordsVersion 미달)이라 내장 최신 좌표로 동작 중이었음'
    }
    Write-RunLog "[진단] 오류 로그 사본 저장: $diagLog"
    # 로그 사본도 스크린샷과 같은 보관 규칙(기본 10개)으로 정리합니다
    $keepLogs = Get-ConfigInteger $config @('diagnostics', 'keepScreenshots') 10 0 1000
    if ($keepLogs -gt 0) {
      $oldLogs = @(Get-ChildItem -LiteralPath $logDir -Filter 'error_*.log' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip $keepLogs)
      foreach ($old in $oldLogs) {
        Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
      }
    }
  } catch {
    Write-RunLog "[진단] 오류 로그 사본 저장 실패: $($_.Exception.Message)"
  }
  exit 1
}
