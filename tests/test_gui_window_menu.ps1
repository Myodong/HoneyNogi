# 권장 창 모드 크기 선택 메뉴 (2026-08-13 시안 확정 - 자동 결정 → 사용자 선택) 진리표+배선
# 본체: mabinogi_gui.ps1 Get-RecommendedSizeMatch(체크 표시 판정) / 메뉴·클릭·헬퍼 배선.
# 배경: 제목 열화 계열 실사고 전부가 1908 창(실효 배율 = 배율/1.5)이라 1272 를 (추천)으로
# 표기하고 사용자가 고르게 함. 모니터보다 큰 크기는 적용 거부(fail-closed - 사용자 확정).
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path $guiPath -Names @('Get-RecommendedSizeMatch')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 1. 현재 크기 체크 표시 판정 (±6px - 정상 상태는 정확 일치, 이웃 크기와 구분) ──
Assert-Case '매치: 1272x717 정확' (Get-RecommendedSizeMatch -PhysicalWidth 1272 -PhysicalHeight 717) '1272'
Assert-Case '매치: 1274x715 허용 오차 안' (Get-RecommendedSizeMatch -PhysicalWidth 1274 -PhysicalHeight 715) '1272'
Assert-Case '매치: 1280x720(이웃 크기)은 불일치 - 폭 차 8px 로 구분' (Get-RecommendedSizeMatch -PhysicalWidth 1280 -PhysicalHeight 720) ''
Assert-Case '매치: 1908x1076 정확' (Get-RecommendedSizeMatch -PhysicalWidth 1908 -PhysicalHeight 1076) '1908'
Assert-Case '매치: 1902x1071 허용 오차 안' (Get-RecommendedSizeMatch -PhysicalWidth 1902 -PhysicalHeight 1071) '1908'
Assert-Case '매치: 1265x717 은 불일치 (7px 초과)' (Get-RecommendedSizeMatch -PhysicalWidth 1265 -PhysicalHeight 717) ''
Assert-Case '매치: 판독 실패(0x0)는 불일치' (Get-RecommendedSizeMatch -PhysicalWidth 0 -PhysicalHeight 0) ''

# ── 2. 배선 가드 (메뉴/클릭/헬퍼 계약) ──
$guiSource = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
Assert-Case '배선: 버튼 텍스트에 드롭다운 표시(▾)' ($guiSource -match "\.Text = '권장 창 모드 ▾'") $true
Assert-Case '배선: 메뉴 항목 - 1272 (추천)' ($guiSource -match "'1272 x 717   \(추천\)'") $true
Assert-Case '배선: 메뉴 항목 - 1908 (큰 모니터용)' ($guiSource -match "'1908 x 1076  \(큰 모니터용\)'") $true
Assert-Case '배선: 1272 클릭 → 명시 크기로 적용' ($guiSource -match 'Apply-RecommendedWindowSize -Width 1272 -Height 717') $true
Assert-Case '배선: 1908 클릭 → 명시 크기로 적용' ($guiSource -match 'Apply-RecommendedWindowSize -Width 1908 -Height 1076') $true
Assert-Case '배선: 버튼 클릭은 메뉴 열기 (직접 적용 아님)' `
  (($guiSource -match '\$menuRecommendedWindow\.Show\(\$btnRecommendedWindow') -and
   ($guiSource -notmatch '\$btnRecommendedWindow\.Add_Click\(\{\s*\r?\n\s*Apply-RecommendedWindowSize\s*\r?\n')) $true
Assert-Case '배선: 메뉴 열 때마다 현재 크기 체크 갱신' `
  ($guiSource -match '(?s)Add_Opening\(\{[\s\S]{0,400}Get-GameWindowPhysicalSize[\s\S]{0,200}Get-RecommendedSizeMatch') $true
Assert-Case '배선: 헬퍼 - 모니터보다 크면 적용 거부(too-big)' `
  ($guiSource -match 'if \(`\$tw -gt `\$ww -or `\$th -gt `\$wh\)[^\r\n]*too-big') $true
Assert-Case '배선: 헬퍼 - 게임 없음 결과(no-game) 기록' ($guiSource -match "Value 'no-game'") $true
Assert-Case '배선: 결과 타이머가 성공/거부/미적용/게임 없음을 로그로 안내' `
  (($guiSource -match '크기 변경 완료') -and ($guiSource -match '모니터 작업 영역보다 큽니다') -and
   ($guiSource -match '적용되지 않았습니다') -and ($guiSource -match '게임 실행 후 다시 눌러')) $true
# ── 3. 교차 리뷰 보완 계약 (2026-08-13) ──
Assert-Case '배선: 실행 중 리사이즈 금지 - 버튼과 항목 클릭 이중 가드' `
  (([regex]::Matches($guiSource, 'Test-ResizeBlockedByRunning')).Count -ge 4) $true
Assert-Case '배선: 결과 타이머 틱 전체 try/catch (모달 오류창 방지 계약)' `
  ($guiSource -match '(?s)timerResizeResult\.Add_Tick\(\{\s*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*try \{') $true
Assert-Case '배선: 결과 파일은 요청별 GUID 발급 (낡은 결과 소비 방지)' `
  ($guiSource -match "'honeynogi_resize_' \+ \[guid\]::NewGuid\(\)") $true
Assert-Case '배선: 헬퍼 작업 영역은 게임 창이 있는 모니터 기준 (MonitorFromWindow)' `
  (($guiSource -match 'MonitorFromWindow\(`\$p\.MainWindowHandle, 2\)') -and ($guiSource -match 'GetMonitorInfo')) $true
Assert-Case '배선: 헬퍼가 적용 결과를 재측정해 ok/failed 판정 (거짓 성공 방지)' `
  (($guiSource -match '`\$aw -eq `\$tw -and `\$ah -eq `\$th') -and ($guiSource -match "'failed ' \+ ")) $true
Assert-Case '배선: 종료 정리 목록에 결과 타이머 포함' `
  ($guiSource -match '\$script:lifeSlideTimer, \$script:timerResizeResult\)') $true
Assert-Case '배선: 리사이즈 진행 중 시작 금지 (pending 게이트가 시작 버튼에)' `
  ($guiSource -match '(?s)if \(\$script:resizePending\) \{\s*\r?\n\s*Add-GuiLog[^\r\n]*끝난 뒤 시작') $true
Assert-Case '배선: pending 은 타이머의 모든 종료 경로에서 해제 (결과/타임아웃/예외 3곳)' `
  (([regex]::Matches($guiSource, '\$script:resizePending = \$false')).Count -ge 4) $true
Assert-Case '배선: 결과 경로의 작은따옴표 이스케이프 (헬퍼 구문 오류 방지)' `
  ($guiSource -match "\.Replace\(`"'`", `"''`"\)") $true

if ($fails -gt 0) { Write-Output "FAIL 합계: $fails"; exit 1 }
Write-Output '전체 통과'
exit 0
