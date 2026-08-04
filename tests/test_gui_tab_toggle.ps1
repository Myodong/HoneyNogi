# GUI 탭 토글(설정/로그 표시) 레이아웃 진리표 + 배선 가드 (2026-08-04 시안 확정, Codex 합의)
# 본체: mabinogi_gui.ps1 - 순수 계산 Get-TabToggleLayout + updateCategoryPanels 적용부
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiSource = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_gui.ps1'))

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

# ── 3. 핵심 계약: 설정을 접으면 폼도 함께 줄어듦 (총높이가 아니라 뷰포트 기억 - Codex 지적) ──
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
  ($guiSource -match '\$form\.MinimumSize = New-Object System\.Drawing\.Size\(616, \$form\.Height\)[\s\S]{0,400}\$form\.MaximumSize = New-Object System\.Drawing\.Size\(65535, \$form\.Height\)') $true
Assert-Case '가드: MaximumSize 가로 0 사용 없음' `
  ([regex]::Matches($guiSource, 'MaximumSize = New-Object System\.Drawing\.Size\(0,').Count) 0
Assert-Case '가드: 잠금 전 최대화 해제' `
  ($guiSource -match 'LockHeight -and \$form\.WindowState -ne ''Normal''\) \{ \$form\.WindowState = ''Normal'' \}') $true
Assert-Case '가드: 뷰포트 흡수는 직전 열림 상태에서만(3상태 전이)' `
  ($guiSource -match 'if \(\$script:logLayoutOpen -eq \$true\) \{ \$script:logViewHeight = \[Math\]::Max\(100, \[int\]\$txtLog\.Height\) \}') $true
Assert-Case '가드: 배지는 논리 상태(Checked) 기반 - Visible 금지' `
  ($guiSource -match 'if \(-not \$chkTabLog\.Checked\) \{\s+if \(\$severity') $true
Assert-Case '가드: 접힘 중 ScrollToCaret 생략' `
  ($guiSource -match 'return   # 접힘 중에는 ScrollToCaret 생략') $true
Assert-Case '가드: 로그 지우기 시 배지 리셋' `
  ($guiSource -match '\$txtLog\.Clear\(\)[\s\S]{0,400}Reset-LogTabBadge') $true
Assert-Case '가드: 토글 커스텀 배경색 확실 적용 2곳' `
  ([regex]::Matches($guiSource, 'UseVisualStyleBackColor = \$false').Count) 2
Assert-Case '가드: 하단 줄 간격 실측' `
  ($guiSource -match '\$script:footerGap = \$form\.ClientSize\.Height - \$btnOpenLog\.Top') $true
# 로그 전용 하단 컨트롤은 로그 열림에 연동 (2026-08-04 추가 요청 - Log 폴더 열기는 항상 유지)
Assert-Case '가드: 로그 접힘 시 글자 크기/지우기 숨김 3건' `
  ([regex]::Matches($guiSource, '\$(lblFontSize|numFontSize|btnClearLog)\.Visible = \(\$tabLayout\.LogTop -ge 0\)').Count) 3
Assert-Case '가드: 토글 상태 저장 2경로(즉시+시작 시 병합)' `
  ([regex]::Matches($guiSource, "@\('settingsOpen', \[bool\]\`$chkTabSettings\.Checked\)").Count) 2
Assert-Case '가드: 로드는 JSON 불리언만 인정' `
  ([regex]::Matches($guiSource, 'ConvertTo-StrictBoolean \$cfg\.ui\.(settingsOpen|logOpen)').Count) 2

# config.json 기본 키 (기본 config 에 있어야 자동 이전에서 보존됨)
$configJson = Get-Content (Join-Path $projectRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Case 'config: ui.settingsOpen 기본 false' ($configJson.ui.settingsOpen -is [bool] -and -not $configJson.ui.settingsOpen) $true
Assert-Case 'config: ui.logOpen 기본 false' ($configJson.ui.logOpen -is [bool] -and -not $configJson.ui.logOpen) $true

exit $fails
