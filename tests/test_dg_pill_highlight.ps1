# 난이도 알약 강조 판정 (v2.1.2 - 2026-08-20 신설) 실사고 캡처 재현 + 배선 가드
# 실사고(09:07~09:10, 1908 네이티브 심층 선택 화면): 선택 강조가 '노란 채움'이 아니라
# **노란 테두리 + 어두운 채움**이라 dx 3열 그물이 테두리를 2/27밖에 못 잡아, 이미 선택된
# '어려움' 알약을 미선택으로 오판 → 오난이도 방지 fail-closed 3회차 연속 정지.
# 수정: dx 3열(-12,0,12) → 7열 촘촘화 (색 조건·문턱 ≥3 불변 - 표본 추가라 기존 통과 화면은
# 단조성으로 계속 통과. Codex 교차검증: 보관 캡처 85장 비선택 0/63·선택 12~25/63·경계 없음).
# ★ 이 테스트는 그물 배열을 **소스에서 캡처**해 재샘플링합니다 - 그물을 3열로 되돌리면
#   실사고 캡처에서 2히트(<3)가 되어 자동으로 실패합니다 (자체 변이 가드).
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$workerText = [IO.File]::ReadAllText($workerPath)

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}" -f $Name }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 소스에서 판정 그물·색 조건·문턱 캡처 (사본 진리표 금지 규칙) ──
$pillBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-DifficultySelectedAt'))
$pillCode = (($pillBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
$dyList = @(([regex]::Match($pillCode, 'foreach \(\$dy in @\(([^)]*)\)\)').Groups[1].Value -split ',') | ForEach-Object { [int]$_.Trim() })
$dxList = @(([regex]::Match($pillCode, 'foreach \(\$dx in @\(([^)]*)\)\)').Groups[1].Value -split ',') | ForEach-Object { [int]$_.Trim() })
Assert-Case '그물: dy 9행 유지' $dyList.Count 9
Assert-Case '그물: dx 7열 (2026-08-20 촘촘화 - 테두리형 강조 대응)' $dxList.Count 7
Assert-Case '그물: X 외연 ±12 불변 (오탐면 미확대)' (($dxList | Measure-Object -Minimum -Maximum | ForEach-Object { '{0}~{1}' -f $_.Minimum, $_.Maximum })) '-12~12'
Assert-Case '판정: 색 조건(밝기 150/채도 60)·문턱(3+) 불변' `
  (($pillCode.Contains('-gt 150') -and $pillCode.Contains('-gt 60')) -and ($pillCode -match 'return \(\$hits -ge 3\)')) 'True'
Assert-Case '진단: 분모 63 (실제 표본 수와 일치 - 상세는 test_cursor_park)' ($pillCode.Contains('/63 ')) 'True'

# ── 실사고 캡처 재현: 소스 그물 그대로 재샘플링 ──
$refW = 1272.0; $refH = 717.0
$refX = 80; $refY = 195   # 실사고 로그의 기준점 (클릭 지점의 1272 환산)
$capPath = Join-Path $projectRoot '던전이미지\던전\20260820_심층선택_어려움알약선택됨_1908.png'
$cap = [System.Drawing.Bitmap]::FromFile($capPath)
$hits = 0
foreach ($dy in $dyList) {
  foreach ($dx in $dxList) {
    $px = [int][Math]::Round(($refX + $dx) * $cap.Width / $refW)
    $py = [int][Math]::Round(($refY + $dy) * $cap.Height / $refH)
    if ($px -lt 0 -or $py -lt 0 -or $px -ge $cap.Width -or $py -ge $cap.Height) { continue }
    $c = $cap.GetPixel($px, $py)
    $chMax = [Math]::Max([int]$c.R, [Math]::Max([int]$c.G, [int]$c.B))
    $chMin = [Math]::Min([int]$c.R, [Math]::Min([int]$c.G, [int]$c.B))
    if ($chMax -gt 150 -and ($chMax - $chMin) -gt 60) { $hits++ }
  }
}
"  (실사고 캡처 히트: $hits / $($dyList.Count * $dxList.Count))"
Assert-Case '재현: 실사고 캡처(선택된 알약)가 문턱(3+) 통과' ($hits -ge 3) 'True'
# 음성: 어두운 패널 지점 / 탭 흰 글자 지점 - 같은 그물·조건으로 0히트여야 함 (오탐면 검증)
foreach ($negCase in @(@('어두운 패널 (80,240)', 80, 240), @('탭 흰 글자 (75,130)', 75, 130))) {
  $negHits = 0
  foreach ($dy in $dyList) {
    foreach ($dx in $dxList) {
      $px = [int][Math]::Round(([int]$negCase[1] + $dx) * $cap.Width / $refW)
      $py = [int][Math]::Round(([int]$negCase[2] + $dy) * $cap.Height / $refH)
      if ($px -lt 0 -or $py -lt 0 -or $px -ge $cap.Width -or $py -ge $cap.Height) { continue }
      $c = $cap.GetPixel($px, $py)
      $chMax = [Math]::Max([int]$c.R, [Math]::Max([int]$c.G, [int]$c.B))
      $chMin = [Math]::Min([int]$c.R, [Math]::Min([int]$c.G, [int]$c.B))
      if ($chMax -gt 150 -and ($chMax - $chMin) -gt 60) { $negHits++ }
    }
  }
  Assert-Case ('음성: {0} → 0히트' -f $negCase[0]) $negHits 0
}
$cap.Dispose()

exit $fails
