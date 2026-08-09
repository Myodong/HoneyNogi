# 커서 대피 지점 선택 진리표 (2026-08-09 제보 + 리뷰 적발).
#
# 제보: 물약 부족 팝업의 '닫기'를 눌러 닫았는데, 게임이 커서를 직접 그리기 때문에 커서가
# '닫기' 글자 위에 남아 팝업이 다시 떴을 때 그 글자를 가려 영영 못 닫음.
# 리뷰 적발: 첫 구현은 좌/우 바깥만 고정 여백 12px 로 봐서, **권장 크기 1908x1076 을
# 1920x1080 화면 (0,0) 에 띄운 대표 배치에서 아무 동작도 하지 않았습니다** (왼쪽은 화면 밖,
# 오른쪽은 여백이 12px 미만). 그래서 이 진리표는 그 배치를 1급 케이스로 고정합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
Invoke-Expression ((Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-CursorParkPoint')) -join "`n")

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}
function New-Screen { param([int]$L, [int]$T, [int]$R, [int]$B) return @{ Left = $L; Top = $T; Right = $R; Bottom = $B } }
function Format-Park {
  param($Point)
  if ($null -eq $Point) { return '(이동 없음)' }
  return ('{0},{1}' -f $Point.X, $Point.Y)
}
# 대피 지점이 정말 '창 밖 + 화면 안'인지 확인하는 공용 검사 (좌표를 외우지 않고 성질로 검증)
function Test-ParkValid {
  param($Point, [int]$L, [int]$T, [int]$R, [int]$B, [object[]]$Screens)
  if ($null -eq $Point) { return 'null' }
  $insideGame = ($Point.X -ge $L -and $Point.X -lt $R -and $Point.Y -ge $T -and $Point.Y -lt $B)
  if ($insideGame) { return '창안(실패)' }
  foreach ($s in $Screens) {
    if ($Point.X -ge $s.Left -and $Point.X -le ($s.Right - 1) -and
        $Point.Y -ge $s.Top -and $Point.Y -le ($s.Bottom - 1)) { return '창밖+화면안' }
  }
  return '화면밖(실패)'
}

$fhd = @(New-Screen 0 0 1920 1080)

# ── ① 대표 배치: 권장 1908x1076 창 @ (0,0), 1920x1080 화면 ──────────────────
# 왼쪽 바깥(-12)은 화면 밖, 오른쪽 여백은 12px 미만(1908~1919) → 화면 경계로 잘라 1919 채택
$park = Get-CursorParkPoint -Left 0 -Top 0 -Right 1908 -Bottom 1076 -Screens $fhd -CursorX 900 -CursorY 500
Assert-Case '권장 1908x1076@(0,0): 대피 지점이 나온다' (Format-Park $park) '1919,538'
Assert-Case '권장 1908x1076@(0,0): 창 밖 + 화면 안' `
  (Test-ParkValid -Point $park -L 0 -T 0 -R 1908 -B 1076 -Screens $fhd) '창밖+화면안'

# ── ② 권장 1272x717 창 (여유가 넉넉한 일반 배치) ────────────────────────────
$park = Get-CursorParkPoint -Left 100 -Top 100 -Right 1372 -Bottom 817 -Screens $fhd -CursorX 700 -CursorY 400
Assert-Case '1272x717@(100,100): 왼쪽 바깥 우선' (Format-Park $park) '88,458'

# ── ③ 창이 화면 왼쪽 끝에 붙은 경우 → 오른쪽으로 ────────────────────────────
$park = Get-CursorParkPoint -Left 0 -Top 100 -Right 1272 -Bottom 817 -Screens $fhd -CursorX 600 -CursorY 400
Assert-Case '좌측 끝 밀착: 오른쪽 바깥 채택' (Format-Park $park) '1284,458'

# ── ④ 좌우가 모두 막히고 아래만 남은 경우 ───────────────────────────────────
# 폭은 화면을 꽉 채우고 높이만 여유가 있는 창 (아래 여백 200px)
$park = Get-CursorParkPoint -Left 0 -Top 0 -Right 1920 -Bottom 880 -Screens $fhd -CursorX 900 -CursorY 400
Assert-Case '좌우 막힘: 아래쪽 바깥 채택' (Format-Park $park) '960,892'
Assert-Case '좌우 막힘: 창 밖 + 화면 안' `
  (Test-ParkValid -Point $park -L 0 -T 0 -R 1920 -B 880 -Screens $fhd) '창밖+화면안'

# ── ⑤ 좌우/아래가 막히고 위만 남은 경우 ─────────────────────────────────────
$park = Get-CursorParkPoint -Left 0 -Top 200 -Right 1920 -Bottom 1080 -Screens $fhd -CursorX 900 -CursorY 600
Assert-Case '아래까지 막힘: 위쪽 바깥 채택' (Format-Park $park) '960,188'

# ── ⑥ 진짜 전체 화면이면 옮길 곳이 없다 (억지로 옮기면 다른 것을 가림) ──────
$park = Get-CursorParkPoint -Left 0 -Top 0 -Right 1920 -Bottom 1080 -Screens $fhd -CursorX 900 -CursorY 500
Assert-Case '전체 화면: 이동 없음' (Format-Park $park) '(이동 없음)'

# ── ⑦ 커서가 이미 창 밖이면 건드리지 않는다 ─────────────────────────────────
# 팝업 스윕은 400ms 주기로 돕니다. 매번 커서를 끌어오면 사용자가 다른 창에서 마우스를
# 쓰지 못합니다. 가림은 커서가 창 안에 있을 때만 생기므로 그때만 옮깁니다.
$park = Get-CursorParkPoint -Left 100 -Top 100 -Right 1372 -Bottom 817 -Screens $fhd -CursorX 1700 -CursorY 900
Assert-Case '커서가 이미 창 밖: 이동 없음' (Format-Park $park) '(이동 없음)'
$park = Get-CursorParkPoint -Left 100 -Top 100 -Right 1372 -Bottom 817 -Screens $fhd -CursorX 100 -CursorY 100
Assert-Case '커서가 창 좌상단 모서리(포함): 대피함' (Format-Park $park) '88,458'
$park = Get-CursorParkPoint -Left 100 -Top 100 -Right 1372 -Bottom 817 -Screens $fhd -CursorX 1372 -CursorY 400
Assert-Case '커서가 우측 경계 바로 밖(Right 는 배타): 이동 없음' (Format-Park $park) '(이동 없음)'

# ── ⑧ 멀티 모니터: 게임 화면이 꽉 찼어도 옆 모니터 여유를 쓴다 ──────────────
$dual = @((New-Screen 0 0 1920 1080), (New-Screen 1920 0 3840 1080))
$park = Get-CursorParkPoint -Left 0 -Top 0 -Right 1920 -Bottom 1080 -Screens $dual -CursorX 900 -CursorY 500
Assert-Case '듀얼: 전체 화면 게임도 옆 모니터로 대피' (Format-Park $park) '1920,540'
Assert-Case '듀얼: 창 밖 + 화면 안' `
  (Test-ParkValid -Point $park -L 0 -T 0 -R 1920 -B 1080 -Screens $dual) '창밖+화면안'
# 왼쪽에 붙은 보조 모니터(음수 좌표)도 동일하게 동작
$leftDual = @((New-Screen 0 0 1920 1080), (New-Screen -1920 0 0 1080))
$park = Get-CursorParkPoint -Left 0 -Top 0 -Right 1920 -Bottom 1080 -Screens $leftDual -CursorX 900 -CursorY 500
Assert-Case '듀얼(왼쪽 보조): 음수 좌표 모니터로 대피' (Format-Park $park) '-12,540'
Assert-Case '듀얼(왼쪽 보조): 창 밖 + 화면 안' `
  (Test-ParkValid -Point $park -L 0 -T 0 -R 1920 -B 1080 -Screens $leftDual) '창밖+화면안'

# ── ⑨ 방어: 비정상 입력 ─────────────────────────────────────────────────────
Assert-Case '빈 창(폭 0): 이동 없음' `
  (Format-Park (Get-CursorParkPoint -Left 5 -Top 5 -Right 5 -Bottom 500 -Screens $fhd -CursorX 5 -CursorY 100)) '(이동 없음)'
Assert-Case '화면 목록 비었음: 이동 없음' `
  (Format-Park (Get-CursorParkPoint -Left 100 -Top 100 -Right 500 -Bottom 500 -Screens @() -CursorX 200 -CursorY 200)) '(이동 없음)'

# ── ⑩ 배선 가드: 제보 시나리오(팝업 재출현) 경로에 대피가 실제로 걸려 있는가 ──
$workerRaw = [IO.File]::ReadAllText($workerPath)
Assert-Case '배선: 대피 호출이 순수 판정 함수를 경유' `
  ($workerRaw -match 'Get-CursorParkPoint -Left \$rect\.Left') 'True'
Assert-Case '배선: 커서 현재 위치를 읽어 넘김(이미 밖이면 무동작)' `
  ($workerRaw -match 'GetCursorPos\(\[ref\]\$cursor\)') 'True'
# 팝업 '탐색 전' 대피가 핵심입니다. 클릭 직후 대피만으로는 SetCursorPos 가 한 번 실패하거나
# 사용자가 커서를 다시 창 안에 두면 다음 팝업에서 원래 정체가 재현됩니다 (2026-08-09 리뷰).
# 그래서 '몇 곳에 있나'가 아니라 **팝업 함수 각각이 탐색 전에 대피하는가**를 봅니다.
foreach ($popupFn in @('Invoke-PurchasePopupSweep', 'Invoke-AfterEntryKeys')) {
  $fnBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($popupFn))
  Assert-Case "배선: $popupFn 은 탐색 전에 대피" `
    ($fnBody -match '(?s)Move-CursorOutsideGame -Game \$Game.*Find-GameTextPoint') 'True'
}
# 클리어 대기 루프는 함수가 아니라 본문 인라인이라 구매 팝업 블록을 직접 확인합니다
Assert-Case '배선: 클리어 대기 구매 팝업도 탐색 전에 대피' `
  ($workerRaw -match '(?s)Move-CursorOutsideGame -Game \$Game\r?\n\s*\$popupClosePoint = Find-GameTextPoint') 'True'
Assert-Case '배선: 클릭 직후 대피도 유지(커서가 닫기 위에 남지 않게)' `
  ($workerRaw -match '(?s)Click-ScreenPoint -X \$popupClosePoint\.X[^\r\n]*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*Move-CursorOutsideGame') 'True'
Assert-Case '배선: 대피 호출 4곳 이상' `
  ([regex]::Matches($workerRaw, '(?m)^\s*Move-CursorOutsideGame -Game \$Game').Count -ge 4) 'True'

exit $fails
