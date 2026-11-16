# GUI 탭 토글(설정/로그 표시) 레이아웃 진리표 + 배선 가드 (2026-08-04 시안 확정, 설계 합의)
# 본체: mabinogi_gui.ps1 - 순수 계산 Get-TabToggleLayout + updateCategoryPanels 적용부
# 2026-11-14 하단 줄 여백(폼 높이 872 → 881): 9절 '하단 줄 버튼이 창 아래로 잘리지 않는다'(소스의 생성 문장에서 읽은 숫자 · 헤드리스 폼) ·
#   10절 '실제 값 FooterGap 36 의 대표 행'(관계식 · 작업 영역 한도 사례). 변이로 실패를 확인했습니다: 폼 높이를 872 로 되돌림 · footerGap 초기값을 28 로 ·
#   '로그 지우기' 의 앵커를 Top 으로 · 글자 크기 칸을 버튼 줄 아래로 내림 · 해/달 아이콘의 Top 을 다른 값으로 ·
#   버전 라벨의 세로 자리를 2px 올림(내부 검토 반영 - 아래 거리 값 행. 그 행을 넣기 전에는 통과하던 변이)
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$guiSource = [IO.File]::ReadAllText($guiPath)
# 함수 본문만 AST 로 떼어내는 공용 헬퍼 (주석 앵커를 코드 앵커로 바꾸는 데 필요 - 8차 점검)
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 1. 순수 함수 추출 (소스에서 그대로 가져와 실행 - 사본 진리표가 아닌 실물 검증) ──────
$funcMatch = [regex]::Match($guiSource, '(?s)function Get-TabToggleLayout.*?\r?\n\}')
Assert-Case '추출: Get-TabToggleLayout 존재' $funcMatch.Success $true
if (-not $funcMatch.Success) { exit 1 }
Invoke-Expression $funcMatch.Value

# 공통 입력: FooterGap 28 / 비클라이언트 39 / 작업영역 1050 / 설정 그룹 150 / 기본 상세 Bottom 332
$base = @{ FooterGap = 28; NonClientHeight = 39; WorkAreaHeight = 1050; SettingsHeight = 150; LogViewHeight = 300 }

# ── 2. 상태 조합 4종 (기본 상세 322+10 = Bottom 332) ─────────────────────────────
$r = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $false -LogOpen $false @base
Assert-Case '조합: 둘 다 접힘 - 토글 줄 Top' $r.TabRowTop 340
Assert-Case '조합: 둘 다 접힘 - ClientHeight(컴팩트)' $r.ClientHeight 408
Assert-Case '조합: 둘 다 접힘 - 높이 잠금' $r.LockHeight $true
Assert-Case '조합: 둘 다 접힘 - 설정/로그 숨김' "$($r.SettingsTop),$($r.LogTop)" '-1,-1'

$r = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $true -LogOpen $false @base
Assert-Case '조합: 설정만 - 설정 Top' $r.SettingsTop 380
Assert-Case '조합: 설정만 - ClientHeight' $r.ClientHeight 566
Assert-Case '조합: 설정만 - 높이 잠금' $r.LockHeight $true

$r = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $false -LogOpen $true @base
Assert-Case '조합: 로그만 - 로그 Top' $r.LogTop 380
Assert-Case '조합: 로그만 - 뷰포트 유지' $r.LogHeight 300
Assert-Case '조합: 로그만 - ClientHeight' $r.ClientHeight 716
Assert-Case '조합: 로그만 - 세로 조절 허용' $r.LockHeight $false
Assert-Case '조합: 로그만 - 동적 최소(로그 100 보장)' $r.MinOuterHeight 555

$r = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $true -LogOpen $true @base
Assert-Case '조합: 둘 다 열림 - 설정 위/로그 아래' "$($r.SettingsTop),$($r.LogTop)" '380,538'
Assert-Case '조합: 둘 다 열림 - ClientHeight' $r.ClientHeight 874

# ── 3. 핵심 계약: 설정을 접으면 폼도 함께 줄어듦 (총높이가 아니라 뷰포트 기억 - 리뷰 지적) ──
$both = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $true -LogOpen $true @base
$logOnly = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $false -LogOpen $true @base
Assert-Case '계약: 설정 접기 = 폼 158px 축소(로그 뷰포트 불변)' ($both.ClientHeight - $logOnly.ClientHeight) 158
Assert-Case '계약: 설정 접기 후에도 로그 뷰포트 동일' "$($both.LogHeight)/$($logOnly.LogHeight)" '300/300'

# ── 4. 뷰포트 보존/보정 ─────────────────────────────────────────────────────────
$r = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $false -LogOpen $true -LogViewHeight 450 `
  -SettingsHeight 150 -FooterGap 28 -NonClientHeight 39 -WorkAreaHeight 1050
Assert-Case '뷰포트: 사용자가 늘린 450 보존' $r.LogHeight 450
$r = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $false -LogOpen $true -LogViewHeight 40 `
  -SettingsHeight 150 -FooterGap 28 -NonClientHeight 39 -WorkAreaHeight 1050
Assert-Case '뷰포트: 최소 100 보장' $r.LogHeight 100

# ── 5. 작업 영역 초과 시 뷰포트 축소 (Top 보정은 적용부 담당) ──────────────────────
$r = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $false -LogOpen $true -LogViewHeight 300 `
  -SettingsHeight 150 -FooterGap 28 -NonClientHeight 39 -WorkAreaHeight 600
Assert-Case '작업영역: 초과 시 뷰포트 축소(145)' $r.LogHeight 145
Assert-Case '작업영역: ClientHeight = 한도' $r.ClientHeight 561
$r = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $false -LogOpen $true -LogViewHeight 300 `
  -SettingsHeight 150 -FooterGap 28 -NonClientHeight 39 -WorkAreaHeight 500
Assert-Case '작업영역: 극단에도 로그 100 보장 우선' $r.LogHeight 100

# ── 6. 커스텀 상세(리스트) 높이 증가 + 멱등 ─────────────────────────────────────
$r = Get-TabToggleLayout -DetailBottom 506 -SettingsOpen $false -LogOpen $false @base
Assert-Case '상세 증가: 접힘 ClientHeight 따라 증가' $r.ClientHeight 582
$r1 = Get-TabToggleLayout -DetailBottom 506 -SettingsOpen $true -LogOpen $true @base
$r2 = Get-TabToggleLayout -DetailBottom 506 -SettingsOpen $true -LogOpen $true @base
Assert-Case '멱등: 같은 입력 = 같은 출력' "$($r1.ClientHeight)/$($r1.LogTop)" "$($r2.ClientHeight)/$($r2.LogTop)"

# ── 7. 적용부/배선 가드 (소스 계약) ─────────────────────────────────────────────
Assert-Case '가드: 팔레트가 폼 생성보다 먼저 정의' `
  ($guiSource.IndexOf('$script:themeBack') -lt $guiSource.IndexOf('$form.Text = "꿀비노기')) $true
Assert-Case '가드: 크기 제약 Max→Min 순서 해제' `
  ($guiSource -match '\$form\.MaximumSize = \[System\.Drawing\.Size\]::Empty\s+\$form\.MinimumSize = \[System\.Drawing\.Size\]::Empty') $true
# Max 가로는 0 금지 - Form 은 '0=무제한' 규칙이 없어 창이 136px 로 짜부라짐 (08-04 실사고)
Assert-Case '가드: 접힘 = 높이만 잠금(Max 가로는 큰 값, 0 금지)' `
  ($guiSource -match '\$form\.MinimumSize = New-Object System\.Drawing\.Size\(560, \$form\.Height\)[\s\S]{0,400}\$form\.MaximumSize = New-Object System\.Drawing\.Size\(65535, \$form\.Height\)') $true
Assert-Case '가드: MaximumSize 가로 0 사용 없음' `
  ([regex]::Matches($guiSource, 'MaximumSize = New-Object System\.Drawing\.Size\(0,').Count) 0
Assert-Case '가드: 잠금 전 최대화 해제' `
  ($guiSource -match 'LockHeight -and \$form\.WindowState -ne ''Normal''\) \{ \$form\.WindowState = ''Normal'' \}') $true
Assert-Case '가드: 뷰포트 흡수는 직전 열림 상태에서만(3상태 전이)' `
  ($guiSource -match 'if \(\$script:logLayoutOpen -eq \$true\) \{ \$script:logViewHeight = \[Math\]::Max\(100, \[int\]\$txtLog\.Height\) \}') $true
Assert-Case '가드: 배지는 논리 상태(Checked) 기반 - Visible 금지' `
  ($guiSource -match 'if \(-not \$chkTabLog\.Checked\) \{\s+if \(\$severity') $true
# ★ 8차 점검: 이 단언은 **주석 문자열의 존재**만 봤습니다(공백 3칸까지 고정). return 앞에
#   $txtLog.ScrollToCaret() 를 넣어 계약을 정면으로 깨도 리터럴이 그대로라 통과했고, 반대로
#   주석 문구나 공백만 손봐도 동작은 그대로인데 FAIL 이 나는 양방향 거짓 안심이었습니다.
#   → 함수 본문을 AST 로 떼어 **주석을 뺀 코드**로 구조를 확인합니다.
$coloredBody = [string](Get-SourceFunctionDefinitions -Path $guiPath -Names @('Add-ColoredLogLine'))
$coloredCode = (($coloredBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
# 낱말이 아니라 **실제 호출**($txtLog.ScrollToCaret())로 셉니다 - 줄 끝 주석은 위 필터
# ($_ -notmatch '^\s*#')로는 안 지워져서, 낱말로 세면 설명 주석이 호출 하나로 잡힙니다.
Assert-Case '가드: 접힘 분기는 ScrollToCaret 없이 return' `
  ([bool]($coloredCode -match '(?s)if \(-not \$chkTabLog\.Checked\) \{(?:(?!\$txtLog\.ScrollToCaret\(\))[\s\S])*?\r?\n    return[^\r\n]*\r?\n  \}')) $true
Assert-Case '가드: ScrollToCaret 실제 호출은 1곳뿐(접힘 분기 이후)' `
  ([regex]::Matches($coloredCode, '\$txtLog\.ScrollToCaret\(\)').Count) 1
Assert-Case '가드: 로그 지우기 시 배지 리셋' `
  ($guiSource -match '\$txtLog\.Clear\(\)[\s\S]{0,400}Reset-LogTabBadge') $true
Assert-Case '가드: 토글 커스텀 배경색 확실 적용 6곳(설정/로그+랜덤 4)' `
  ([regex]::Matches($guiSource, 'UseVisualStyleBackColor = \$false').Count) 6
Assert-Case '가드: 하단 줄 간격 실측' `
  ($guiSource -match '\$script:footerGap = \$form\.ClientSize\.Height - \$btnOpenLog\.Top') $true
# 로그 전용 하단 컨트롤은 로그 열림에 연동 (2026-08-04 추가 요청 - Log 폴더 열기는 항상 유지)
Assert-Case '가드: 로그 접힘 시 글자 크기/지우기 숨김 3건' `
  ($guiSource -match '\$lblFontSize\.Visible = \(\$tabLayout\.LogTop -ge 0\)' -and
   $guiSource -match '\$numFontSize\.Visible = \(\$tabLayout\.LogTop -ge 0\)' -and
   $guiSource -match '\$btnClearLog\.Visible = \(\$tabLayout\.LogTop -ge 0\)') $true
# 로그 기본 뷰포트 150 (2026-08-04 사용자 조정 - 300은 너무 높음)
Assert-Case '가드: 로그 기본 뷰포트 150' `
  ($guiSource -match '\$script:logViewHeight = 150') $true
Assert-Case '가드: 토글 상태 저장 2경로(즉시+시작 시 병합)' `
  ([regex]::Matches($guiSource, "@\('settingsOpen', \[bool\]\`$chkTabSettings\.Checked\)").Count) 2
Assert-Case '가드: 로드는 JSON 불리언만 인정' `
  ([regex]::Matches($guiSource, 'ConvertTo-StrictBoolean \$cfg\.ui\.(settingsOpen|logOpen)').Count) 2

# config.json 기본 키 (기본 config 에 있어야 자동 이전에서 보존됨)
$configJson = Get-Content (Join-Path $projectRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Case 'config: ui.settingsOpen 기본 false' ($configJson.ui.settingsOpen -is [bool] -and -not $configJson.ui.settingsOpen) $true
Assert-Case 'config: ui.logOpen 기본 false' ($configJson.ui.logOpen -is [bool] -and -not $configJson.ui.logOpen) $true

# 폭 560 확정 (2026-08-04 시안): 최소 폭 3곳(기본+접힘+열림) 일치 + 구 616 잔재 없음
Assert-Case '가드: 최소 폭 560 - 기본/접힘/열림 3곳' `
  ([regex]::Matches($guiSource, 'MinimumSize = New-Object System\.Drawing\.Size\(560,').Count) 3
Assert-Case '가드: 구 최소 폭 616 잔재 없음' `
  ([regex]::Matches($guiSource, 'Size\(616,').Count) 0
# 높이 881 = 2026-11-14 하단 줄 여백 수정(아래 9절 - 그 전에는 872)
Assert-Case '가드: 폼 폭 560' `
  ($guiSource -match '\$form\.Size = New-Object System\.Drawing\.Size\(560, 881\)') $true

# ── 8. v2.0.0 대분류(전투/생활) 신설 - 상세 Bottom 실측 3케이스 (리뷰 검증 조건) ──────
# 대분류 줄 +40 시프트로 DetailTop 210→250: 전투 기본 H=122 → Bottom 372 /
# 생활(채집·가공 공통) H=268 → Bottom 518 / 기존 최대 커스텀 H=296 → Bottom 546
$r = Get-TabToggleLayout -DetailBottom 372 -SettingsOpen $false -LogOpen $false @base
Assert-Case 'v2 시프트: 전투 기본(372) 토글 줄 Top' $r.TabRowTop 380
$r = Get-TabToggleLayout -DetailBottom 518 -SettingsOpen $true -LogOpen $false @base
Assert-Case 'v2 시프트: 생활(518) 설정 그룹 Top' $r.SettingsTop 566
$r = Get-TabToggleLayout -DetailBottom 546 -SettingsOpen $false -LogOpen $true @base
Assert-Case 'v2 시프트: 최대 커스텀(546) 로그 Top' $r.LogTop 594
# 시프트 배선: 상세 그룹이 실제로 (15,250) 으로 내려갔는지 + 대분류 버튼 줄 존재
Assert-Case 'v2 배선: grpContentDetail Top 250' `
  ($guiSource -match '\$grpContentDetail\.Location = New-Object System\.Drawing\.Point\(15, 250\)') $true
# 2026-08-15 기타 신설: 2버튼(254폭) → 3버튼(168폭, x 15/188/361)
Assert-Case 'v2 배선: 대분류 버튼 3개 (15,44)/(188,44)/(361,44)' `
  (($guiSource -match '\$btnCatBattle\.Location = New-Object System\.Drawing\.Point\(15, 44\)') -and
   ($guiSource -match '\$btnCatLife\.Location = New-Object System\.Drawing\.Point\(188, 44\)') -and
   ($guiSource -match '\$btnCatEtc\.Location = New-Object System\.Drawing\.Point\(361, 44\)')) $true

# ── 9. 하단 줄 버튼이 창 아래로 잘리지 않는다 (2026-11-14 하단 줄 여백 - 폼 높이 872 → 881) ─────────────
# 관측(2026-11-14 패널 그림 · 그 전 실기 그림 전부): 하단 줄의 버튼 셋(Log 폴더 열기 · 로그 지우기 · 해/달 아이콘)에 아래 테두리 줄이 없었습니다.
# 폼을 바깥 높이 872 로 만들면 클라이언트 높이가 872 - 비클라이언트 39 = 833 인데 하단 줄 Top 이 806 이라, 높이 28 인 버튼의 자리가 27 뿐이었습니다
# (2026-08-04 배치부터 - 위 진리표의 공통 입력 FooterGap 28 이 의도한 값이고 실제 값은 27). 사용자 결정 '아래 테두리를 살리고 그 아래 여백 8' → 폼 높이 881.
# 좌표와 배치 계산식은 그대로이고 하단 줄은 Bottom 앵커로 따라갑니다.
# 숫자는 소스의 생성 문장에서 읽습니다 - 줄 머리 고정 정규식이라 주석 속 숫자에 걸리지 않고, 문장이 없거나 둘 이상이면 아래 '읽기' 행이 먼저 실패합니다.
# 39 는 설계 시점 PC 의 비클라이언트 높이(제목줄 + 위아래 테두리)입니다 - 이 PC 의 실제 값으로는 아래 헤드리스 폼 행이 봅니다
function Get-SourceLineMatch {
  # 줄 머리 고정 정규식에 맞는 소스 문장이 정확히 1개일 때만 그 Match 를 돌려줍니다 (0개 · 2개 이상이면 $null - 호출부가 '읽기' 행에서 드러냄)
  param([string]$Pattern)
  $lineMatches = [regex]::Matches($script:guiSource, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($lineMatches.Count -eq 1) { return $lineMatches[0] }
  return $null
}
$footerMissing = @()
$formSizeMatch = Get-SourceLineMatch '^\$form\.Size = New-Object System\.Drawing\.Size\((\d+), (\d+)\)'
$formBorderMatch = Get-SourceLineMatch '^\$form\.FormBorderStyle = ''(\w+)'''
$formFontMatch = Get-SourceLineMatch '^\$form\.Font = New-Object System\.Drawing\.Font\(''([^'']+)'', (\d+)\)'
# 초기값 문장만 숫자로 시작합니다 - 실측 대입문($form.ClientSize.Height - $btnOpenLog.Top)은 걸리지 않습니다
$footerGapMatch = Get-SourceLineMatch '^\$script:footerGap = (\d+)\b'
if (-not $formSizeMatch) { $footerMissing += '폼 크기' }
if (-not $formBorderMatch) { $footerMissing += '폼 테두리' }
if (-not $formFontMatch) { $footerMissing += '폼 글꼴' }
if (-not $footerGapMatch) { $footerMissing += 'footerGap 초기값' }
# 하단 줄 컨트롤 여섯 (Log 폴더 열기 · 글자 크기 라벨 · 글자 크기 칸 · 로그 지우기 · 버전 라벨 · 새 버전 링크) - 형식 · 위치 · 크기 · 앵커
$footerNames = @('btnOpenLog', 'lblFontSize', 'numFontSize', 'btnClearLog', 'lblVersion', 'lnkUpdate')
$footerSpecs = @{}
foreach ($footerName in $footerNames) {
  $footerHead = '^' + [regex]::Escape('$' + $footerName)
  $footerTypeMatch = Get-SourceLineMatch ($footerHead + ' = New-Object System\.Windows\.Forms\.(\w+)\s*$')
  $footerLocationMatch = Get-SourceLineMatch ($footerHead + '\.Location = New-Object System\.Drawing\.Point\((\d+), (\d+)\)')
  $footerSizeMatch = Get-SourceLineMatch ($footerHead + '\.Size = New-Object System\.Drawing\.Size\((\d+), (\d+)\)')
  $footerAnchorMatch = Get-SourceLineMatch ($footerHead + '\.Anchor = (\[System\.Windows\.Forms\.AnchorStyles\]::\w+(?: -bor \[System\.Windows\.Forms\.AnchorStyles\]::\w+)*)\s*$')
  if (-not ($footerTypeMatch -and $footerLocationMatch -and $footerSizeMatch -and $footerAnchorMatch)) { $footerMissing += $footerName; continue }
  $footerSpecs[$footerName] = @{
    Type = $footerTypeMatch.Groups[1].Value
    X = [int]$footerLocationMatch.Groups[1].Value; Y = [int]$footerLocationMatch.Groups[2].Value
    W = [int]$footerSizeMatch.Groups[1].Value; H = [int]$footerSizeMatch.Groups[2].Value
    Anchor = $footerAnchorMatch.Groups[1].Value
  }
}
# 해/달 아이콘은 생성 함수 안에서 크기 · Top · 앵커를 정하고, 생성 호출문이 Top 을 'Log 폴더 열기' 의 Top 으로 넘깁니다 (함수 원문은 주석을 뺀 사본으로)
$iconFunctionCode = Remove-SourceComments -Text ([string](Get-SourceFunctionDefinitions -Path $guiPath -Names @('Initialize-ThemeToggleButton')))
$iconSizeMatches = [regex]::Matches($iconFunctionCode, '\$themeButton\.Size = New-Object System\.Drawing\.Size\((\d+), (\d+)\)')
$iconTopCount = [regex]::Matches($iconFunctionCode, '\$themeButton\.Top = \$Top\b').Count
$iconAnchorMatches = [regex]::Matches($iconFunctionCode, '\$themeButton\.Anchor = (\[System\.Windows\.Forms\.AnchorStyles\]::\w+(?: -bor \[System\.Windows\.Forms\.AnchorStyles\]::\w+)*)')
$iconCallMatch = Get-SourceLineMatch '^\$btnThemeToggle = Initialize-ThemeToggleButton\b[^\r\n]*-Top \$btnOpenLog\.Top\b'
if ($iconSizeMatches.Count -ne 1) { $footerMissing += '아이콘 크기' }
if ($iconAnchorMatches.Count -ne 1) { $footerMissing += '아이콘 앵커' }
Assert-Case '하단 줄: 읽기 - 폼 크기 · 테두리 · 글꼴 · footerGap 초기값 · 컨트롤 여섯의 형식/위치/크기/앵커 · 아이콘 크기/앵커 문장이 각 1개' ($footerMissing -join ',') ''
if ($footerMissing.Count -eq 0) {
  $formWidth = [int]$formSizeMatch.Groups[1].Value
  $formHeight = [int]$formSizeMatch.Groups[2].Value
  $footerGapInitial = [int]$footerGapMatch.Groups[1].Value
  $footerButton = $footerSpecs['btnOpenLog']
  $footerButtonBottom = $footerButton.Y + $footerButton.H
  Assert-Case '하단 줄: 폼 높이 - 39 - (버튼 Top + 높이) = 8 (버튼 아래 테두리까지 클라이언트 안 + 그 아래 여백 8)' `
    ($formHeight - 39 - $footerButtonBottom) 8
  Assert-Case '하단 줄: 폼 높이 - 39 - 버튼 Top = 36 = footerGap 초기값 (버튼 높이 28 + 아래 여백 8)' `
    ('{0}/{1}/{2}' -f ($formHeight - 39 - $footerButton.Y), $footerGapInitial, $footerButton.H) '36/36/28'
  # 나머지 다섯은 버튼 줄 안에 있어야 합니다 - 하나라도 버튼 아래 끝보다 내려가면 그 컨트롤이 잘립니다
  $footerOutside = @($footerNames | Where-Object { $_ -ne 'btnOpenLog' } | Where-Object {
      ($footerSpecs[$_].Y -lt $footerButton.Y) -or (($footerSpecs[$_].Y + $footerSpecs[$_].H) -gt $footerButtonBottom) } | ForEach-Object {
      '{0}({1}~{2})' -f $_, $footerSpecs[$_].Y, ($footerSpecs[$_].Y + $footerSpecs[$_].H) })
  Assert-Case '하단 줄: 다른 컨트롤 다섯의 Top ≥ 버튼 Top · 아래 끝 ≤ 버튼 아래 끝' ($footerOutside -join ',') ''
  Assert-Case '하단 줄: 해/달 아이콘 28x28(높이 ≤ 버튼 높이) · Top = 받은 인자 · 생성 호출문이 -Top $btnOpenLog.Top (버튼과 같은 줄)' `
    ('{0}x{1}/{2}/{3}/{4}' -f $iconSizeMatches[0].Groups[1].Value, $iconSizeMatches[0].Groups[2].Value, ([int]$iconSizeMatches[0].Groups[2].Value -le $footerButton.H),
      $iconTopCount, [bool]$iconCallMatch) '28x28/True/1/True'
  # Bottom 앵커 - 폼 높이가 상태마다 바뀌어도(Get-TabToggleLayout 의 ClientHeight) 하단 줄이 아래 끝에서 같은 거리로 따라가는 근거. Top 앵커가 섞이면 늘어납니다
  $footerAnchorTexts = @{}
  foreach ($footerName in $footerNames) { $footerAnchorTexts[$footerName] = $footerSpecs[$footerName].Anchor }
  $footerAnchorTexts['아이콘'] = $iconAnchorMatches[0].Groups[1].Value
  $footerAnchorBad = @($footerAnchorTexts.Keys | Sort-Object | Where-Object {
      ($footerAnchorTexts[$_] -notmatch '\[System\.Windows\.Forms\.AnchorStyles\]::Bottom\b') -or ($footerAnchorTexts[$_] -match '\[System\.Windows\.Forms\.AnchorStyles\]::Top\b') })
  Assert-Case '하단 줄: 컨트롤 여섯과 아이콘의 앵커 대입문에 Bottom 있음 · Top 없음' ($footerAnchorBad -join ',') ''

  # 헤드리스 폼(화면에 띄우지 않음): 제품과 같은 크기 · 테두리 · 글꼴의 폼에 소스에서 읽은 형식 · 위치 · 크기 · 앵커로 여섯 컨트롤과 해/달 아이콘을 만듭니다
  # (제품과 같은 순서 - 위치 → 크기 → 앵커 → 폼에 추가). 이 PC 의 실제 클라이언트 높이로 버튼이 잘리지 않는지와, 클라이언트 높이를 바꾼 뒤에도 아래 거리가
  # 그대로인지(앵커 보존)를 봅니다.
  # 2026-11-14 이 PC 실측(비클라이언트 39 · 클라이언트 842): 버튼 둘과 아이콘 8 · 라벨 둘과 링크 10 · 글자 크기 칸 10(지정 높이 24 가 아니라 글꼴이 정하는 실제 높이 23 이라
  # 809 + 23 = 832 - 설계 문서의 9 는 지정 높이로 센 값). 거리 값은 PC 의 비클라이언트 높이 · 글꼴에 따라 달라, 비클라이언트 높이가 설계 시점과 같은 39 일 때만 단언하고
  # 그 밖의 PC 에서는 INFO 로만 남깁니다(2026-11-14 내부 검토 - 값을 고정하는 행이 없어 라벨 · 링크의 세로 자리를 2px 옮겨도 통과했음)
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $footForm = New-Object System.Windows.Forms.Form
  try {
    $footForm.Size = New-Object System.Drawing.Size($formWidth, $formHeight)
    $footForm.FormBorderStyle = $formBorderMatch.Groups[1].Value
    $footForm.Font = New-Object System.Drawing.Font($formFontMatch.Groups[1].Value, [int]$formFontMatch.Groups[2].Value)
    $footControls = @{}
    foreach ($footerName in $footerNames) {
      $footSpec = $footerSpecs[$footerName]
      $footControl = New-Object ('System.Windows.Forms.' + $footSpec.Type)
      $footControl.Location = New-Object System.Drawing.Point($footSpec.X, $footSpec.Y)
      $footControl.Size = New-Object System.Drawing.Size($footSpec.W, $footSpec.H)
      $footControl.Anchor = Invoke-Expression $footSpec.Anchor
      $footForm.Controls.Add($footControl)
      $footControls[$footerName] = $footControl
    }
    # 해/달 아이콘도 같은 줄에 둡니다 - 크기 · 앵커는 생성 함수의 대입문에서 읽은 값, Top 은 생성 호출문대로 'Log 폴더 열기' 의 Top
    # (생성 함수와 같은 순서: 크기 → Top → 앵커 → 폼에 추가. 가로 자리는 제품에서 버전 글자 폭으로 정해져 여기서는 임의)
    $footIcon = New-Object System.Windows.Forms.Button
    $footIcon.Size = New-Object System.Drawing.Size([int]$iconSizeMatches[0].Groups[1].Value, [int]$iconSizeMatches[0].Groups[2].Value)
    $footIcon.Left = 400
    $footIcon.Top = $footControls['btnOpenLog'].Top
    $footIcon.Anchor = Invoke-Expression $iconAnchorMatches[0].Groups[1].Value
    $footForm.Controls.Add($footIcon)
    $footControls['아이콘'] = $footIcon
    $footAllNames = @($footerNames) + '아이콘'
    $footClientHeight = $footForm.ClientSize.Height
    $footDistances = @{}
    foreach ($footName in $footAllNames) { $footDistances[$footName] = $footClientHeight - $footControls[$footName].Bottom }
    "INFO 하단 줄(헤드리스): 바깥 {0}x{1} · 클라이언트 높이 {2} · 비클라이언트 {3} · 아래 거리 {4}" -f $footForm.Width, $footForm.Height, $footClientHeight, ($footForm.Height - $footClientHeight),
      ((@($footAllNames | ForEach-Object { '{0}={1}' -f $_, $footDistances[$_] })) -join ' ')
    Assert-Case '하단 줄(헤드리스): 테두리 Sizable · 이 PC 의 클라이언트 높이에서 버튼 둘과 아이콘의 아래 끝이 클라이언트 안(아래 여백 ≥ 0)' `
      ('{0}/{1}/{2}/{3}' -f $footForm.FormBorderStyle, ($footDistances['btnOpenLog'] -ge 0), ($footDistances['btnClearLog'] -ge 0), ($footDistances['아이콘'] -ge 0)) 'Sizable/True/True/True'
    # 설계가 적은 아래 거리(비클라이언트 39 기준): 버튼 둘과 아이콘 8 · 라벨 둘과 링크 10. 글자 크기 칸은 실제 높이가 글꼴로 정해져(이 PC 23) 10 입니다 - 높이를 함께 적어
    # 다른 글꼴 환경에서 갈리면 까닭이 드러나게 합니다
    if (($footForm.Height - $footClientHeight) -eq 39) {
      Assert-Case '하단 줄(헤드리스 · 비클라이언트 39): 아래 거리 - 버튼 둘 · 아이콘 8 / 라벨 둘 · 링크 10 / 글자 크기 칸 10(실제 높이 23)' `
        ('{0}/{1}/{2} · {3}/{4}/{5} · {6}(높이 {7})' -f $footDistances['btnOpenLog'], $footDistances['btnClearLog'], $footDistances['아이콘'],
          $footDistances['lblFontSize'], $footDistances['lblVersion'], $footDistances['lnkUpdate'], $footDistances['numFontSize'], $footControls['numFontSize'].Height) '8/8/8 · 10/10/10 · 10(높이 23)'
    } else {
      'INFO 하단 줄(헤드리스): 이 PC 의 비클라이언트 높이가 39 가 아니라 아래 거리 값(8 · 10)은 단언하지 않습니다'
    }
    # 접힘 화면처럼 클라이언트 높이를 줄입니다(배치 적용부가 하는 대입과 같은 꼴). 높이가 실제로 바뀌고 버튼이 따라 움직였는지도 함께 봅니다 - 바뀌지 않았다면 아래 거리 비교가 빈 비교입니다
    $footButtonTopBefore = $footControls['btnOpenLog'].Top
    $footForm.ClientSize = New-Object System.Drawing.Size($footForm.ClientSize.Width, ($footClientHeight - 434))
    $footClientHeightAfter = $footForm.ClientSize.Height
    $footMoved = @($footAllNames | Where-Object { ($footClientHeightAfter - $footControls[$_].Bottom) -ne $footDistances[$_] } | ForEach-Object {
        '{0}({1}→{2})' -f $_, $footDistances[$_], ($footClientHeightAfter - $footControls[$_].Bottom) })
    Assert-Case '하단 줄(헤드리스): 클라이언트 높이를 434 줄임 - 높이가 바뀌고 버튼이 그만큼 올라감' `
      ('{0}/{1}' -f ($footClientHeight - $footClientHeightAfter), ($footButtonTopBefore - $footControls['btnOpenLog'].Top)) '434/434'
    Assert-Case '하단 줄(헤드리스): 클라이언트 높이를 바꾼 뒤에도 컨트롤 여섯과 아이콘의 아래 거리가 처음과 같음(Bottom 앵커 보존)' ($footMoved -join ',') ''
  } finally { $footForm.Dispose() }

  # ── 10. 실제 값 FooterGap 36 의 대표 행 (2026-11-14) ─────────────────────────────────────────
  # 위 2~8절의 진리표는 FooterGap 28 을 입력으로 준 순수 계산이라 그대로 둡니다(계산식 불변). 여기서는 소스의 초기값(= 실제 값)을 넣어 두 가지를 봅니다.
  # (가) 관계식: 작업 영역 한도에 닿지 않는 네 조합에서 옛 실제 값 27(= 872 - 39 - 806) → 지금 값이면 ClientHeight · 최소 바깥 높이만 정확히 그 차이(9)만큼 커지고
  #      토글 줄 · 설정 · 로그의 Top 과 로그 높이 · 높이 잠금은 그대로입니다 (하단 줄 위쪽은 그대로이고 아래에 여백만 생김)
  $gapInputs = @{ NonClientHeight = 39; WorkAreaHeight = 1050; SettingsHeight = 150; LogViewHeight = 300 }
  $gapRows = foreach ($gapCase in @(@($false, $false), @($true, $false), @($false, $true), @($true, $true))) {
    $gapOld = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $gapCase[0] -LogOpen $gapCase[1] -FooterGap 27 @gapInputs
    $gapNew = Get-TabToggleLayout -DetailBottom 332 -SettingsOpen $gapCase[0] -LogOpen $gapCase[1] -FooterGap $footerGapInitial @gapInputs
    '{0}/{1}/{2}' -f ($gapNew.ClientHeight - $gapOld.ClientHeight), ($gapNew.MinOuterHeight - $gapOld.MinOuterHeight),
      (('{0},{1},{2},{3},{4}' -f $gapNew.TabRowTop, $gapNew.SettingsTop, $gapNew.LogTop, $gapNew.LogHeight, $gapNew.LockHeight) -ceq
        ('{0},{1},{2},{3},{4}' -f $gapOld.TabRowTop, $gapOld.SettingsTop, $gapOld.LogTop, $gapOld.LogHeight, $gapOld.LockHeight))
  }
  Assert-Case '실제 값: FooterGap 27 → 소스 초기값 - 네 조합(접힘 · 설정만 · 로그만 · 둘 다)의 ClientHeight · 최소 바깥 높이 +9, 그 밖은 그대로' `
    ((@($gapRows)) -join ' ') '9/9/True 9/9/True 9/9/True 9/9/True'
  # (나) 한도 사례(설계 리뷰 반영): 가장 긴 화면 = 생활 커스텀 + 설정 · 로그 펼침. 소스의 높이 식(updateCategoryPanels)으로 상세 묶음은 Top 250 + 높이 402
  #      (커스텀 카드 높이 26 → 스킬 줄 38 · 위치점 66 · 대상 제목 84 · 대상 줄 102 · 위치점 130 → 입력 줄 150 → 리스트 180 → 리스트 반복 줄 366 → + 36) = Bottom 652,
  #      생활의 설정 묶음 높이는 94 라 로그 Top = 652 + 8 + 32 + 8 + 94 + 8 = 802 입니다. 실기 그림에서 역산한 입력 '상세 Bottom 596 · 설정 150' 도 같은 로그 Top 입니다.
  #      1080p · 작업 표시줄 48(작업 영역 1032)에서 옛 값 27 이면 바깥 1026 으로 한도 안이었고, 지금 값이면 명목 1035 가 한도를 3 넘어 로그 창이 150 → 147 로 줄고
  #      바깥 높이가 1032 에 멈춥니다. 줄어든 147 은 그 실행 동안 기억됩니다(적용부가 로그 높이를 기억값으로 흡수) - 다음 배치에 147 을 넣어도 150 으로 돌아가지 않아야 합니다
  $limitInputs = @{ DetailBottom = 652; SettingsOpen = $true; LogOpen = $true; SettingsHeight = 94; NonClientHeight = 39 }
  $limitOld = Get-TabToggleLayout @limitInputs -LogViewHeight 150 -FooterGap 27 -WorkAreaHeight 1032
  Assert-Case '한도 사례: 옛 값 27 - 로그 150 · 바깥 1026 (한도 1032 안 - 설계가 적은 지금 창 높이)' `
    ('{0}/{1}/{2}' -f $limitOld.LogTop, $limitOld.LogHeight, ($limitOld.ClientHeight + 39)) '802/150/1026'
  $limitNew = Get-TabToggleLayout @limitInputs -LogViewHeight 150 -FooterGap $footerGapInitial -WorkAreaHeight 1032
  Assert-Case '한도 사례: 소스 초기값 - 로그 150 → 147 · ClientHeight 993 · 바깥 1032 (작업 영역 1032 에 멈춤)' `
    ('{0}/{1}/{2}/{3}' -f $limitNew.LogTop, $limitNew.LogHeight, $limitNew.ClientHeight, ($limitNew.ClientHeight + 39)) '802/147/993/1032'
  $limitAgain = Get-TabToggleLayout @limitInputs -LogViewHeight $limitNew.LogHeight -FooterGap $footerGapInitial -WorkAreaHeight 1032
  Assert-Case '한도 사례: 줄어든 147 을 다음 배치의 기억값으로 - 147 그대로 · ClientHeight 993 (150 으로 되돌아가지 않음)' `
    ('{0}/{1}' -f $limitAgain.LogHeight, $limitAgain.ClientHeight) '147/993'
  $limitWide = Get-TabToggleLayout @limitInputs -LogViewHeight 150 -FooterGap $footerGapInitial -WorkAreaHeight 1040
  Assert-Case '한도 사례: 작업 영역 1040 - 로그 150 그대로 · ClientHeight 996 · 바깥 1035 (한도 안)' `
    ('{0}/{1}/{2}' -f $limitWide.LogHeight, $limitWide.ClientHeight, ($limitWide.ClientHeight + 39)) '150/996/1035'
  $limitSurvey = Get-TabToggleLayout -DetailBottom 596 -SettingsOpen $true -LogOpen $true -SettingsHeight 150 -NonClientHeight 39 -LogViewHeight 150 -FooterGap $footerGapInitial -WorkAreaHeight 1032
  Assert-Case '한도 사례: 실기 그림 역산 입력(상세 Bottom 596 · 설정 150)도 같은 결과' `
    ('{0}/{1}/{2}' -f $limitSurvey.LogTop, $limitSurvey.LogHeight, $limitSurvey.ClientHeight) '802/147/993'
}

exit $fails
