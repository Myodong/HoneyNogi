# 커서 대피 지점 선택 진리표 (2026-08-09 제보 + 리뷰 적발).
#
# 제보: 물약 부족 팝업의 '닫기'를 눌러 닫았는데 팝업이 다시 뜨자 두 번째부터 못 닫음.
#
# ★ 기전 확정 (2026-08-09 실기): **게임이 자기 커서를 그리고, 그게 캡처에 찍혀 글자를 덮는다.**
#   커서를 '닫기' 위에 두면 판독이 'ESC 거래소0' 이 되어 **닫기가 통째로 사라진다(0/6)**.
#   창 밖으로 빼면 '(특주이 닫기 거래소0' 으로 100% 읽힌다(6/6).
#
# ※ 이 결론에 두 번 헛다리를 짚었다. 기록으로 남긴다:
#   - 중간 감사에서 "커서는 캡처에 안 찍힌다(기여분 0)"로 기각했는데, 그 측정들은
#     **커서가 게임 창 위에 없는 상태**(GetCursorInfo flags=1 = OS 커서)에서 잰 것이었다.
#     게임은 포인터가 자기 창 위에 와야 OS 커서를 숨기고(flags=0) 자기 커서를 그린다.
#   - 따라서 이 계열을 측정할 때는 **반드시 flags 를 함께 확인**할 것. flags=1 이면
#     게임 커서가 안 그려진 상태라 무엇을 재도 '영향 없음'이 나온다.
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
# ── 게이트 기준 (2026-08-09 실기 실측으로 확정) ──────────────────────────────
# 실측 4조합 × 6회 (물약 부족 팝업, 창 1272x717):
#   전면O + 커서 창밖    flags=1  6/6 (100%)  '(특주이 닫기 거래소0'
#   전면O + 커서 닫기 위 flags=0  0/6 (  0%)  'ESC 거래소0'      ← 닫기 소멸
#   전면X + 커서 닫기 위 flags=0  0/6 (  0%)  'ESC 거래소0'      ← 전면 아니어도 동일
#   전면X + 커서 창밖    flags=1  6/6 (100%)  '(특주이 닫기 거래소0'
# → 결정 변수는 **전면 여부가 아니라 커서가 게임 위에 있는가**. 게임은 포인터가 자기 창
#   위에 오면 OS 커서를 숨기고(flags=0) 자기 커서를 그리며, 그건 캡처에 그대로 찍혀 글자를
#   덮는다. 따라서 Test-GameForeground 게이트는 **틀렸다** - 전면이 아닐 때도 판독이 깨진다.
#   그렇다고 무조건 옮기면 사용자가 겹쳐 놓은 창에서 마우스를 못 쓴다.
#   WindowFromPoint 로 '커서 밑 창이 게임인가'를 보면 둘 다 만족한다.
$parkBodyEarly = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Move-CursorOutsideGame'))
Assert-Case '게이트: 커서 밑 창이 게임일 때만 대피' `
  ($parkBodyEarly -match 'WindowFromPoint\(\$underCursor\)') 'True'
Assert-Case '게이트: 루트 창을 게임과 대조(자식 창도 게임으로 인정)' `
  ($parkBodyEarly -match 'GetAncestor\(\$hitWindow, 2\) -ne \$Game\.MainWindowHandle') 'True'
Assert-Case '게이트: 전면 여부로 판단하지 않는다(전면X 에서도 판독이 깨짐)' `
  ((($parkBodyEarly -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") -match 'Test-GameForeground') 'False'
# ※ 유휴 검사는 쓰면 안 됩니다 - 우리 클릭(mouse_event)이 유휴를 0으로 리셋해서, 정작
#   클릭 직후 대피(제보 시나리오 그 자체)를 항상 막습니다(3차 점검 실측).
# 주석에는 '왜 쓰면 안 되는지'가 적혀 있으므로 주석을 뺀 코드로 검사합니다
$parkCodeOnly = (($parkBodyEarly -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '게이트: 유휴 검사는 쓰지 않는다(클릭 직후 대피를 스스로 막음)' `
  ($parkCodeOnly -match 'Get-UserIdleSeconds') 'False'
Assert-Case '배선: 커서 현재 위치를 읽어 넘김(이미 밖이면 무동작)' `
  ($workerRaw -match 'GetCursorPos\(\[ref\]\$cursor\)') 'True'
# ★ 6차: GetCursorPos 실패 3곳이 **전부 실패로 기록**돼야 합니다. 하나라도 조용히 return/false
#   로 빠지면 대피가 통째로 무동작인데 로그가 깨끗한, 가장 나쁜 형태가 됩니다 (이 계열은
#   이미 두 번 오래 못 찾았습니다 - 워커의 Forms 어셈블리 미로드, switch 의 $_ 훼손).
Assert-Case '실패기록: 진입 GetCursorPos 실패는 조용히 넘어가지 않는다' `
  ($parkCodeOnly -match 'if \(-not \[HoneyNogiInput\]::GetCursorPos\(\[ref\]\$underCursor\)\) \{ throw ') 'True'
Assert-Case '실패기록: 진입 검사가 try 안에 있다(공통 catch 로 감)' `
  ($parkCodeOnly -match '(?s)try \{[^}]*GetCursorPos\(\[ref\]\$underCursor\)') 'True'
Assert-Case '실패기록: 대피 후 확인 GetCursorPos 실패도 예외로' `
  ($parkCodeOnly -match 'if \(-not \[HoneyNogiInput\]::GetCursorPos\(\[ref\]\$after\)\) \{\s*\r?\n\s*throw ') 'True'
# 확인 실패가 -and 사슬에 묶여 있으면 API 실패가 곧 '조건 거짓' → 성공 경로로 떨어집니다
Assert-Case '실패기록: 확인을 -and 사슬에 묶지 않는다' `
  ($parkCodeOnly -match 'GetCursorPos\(\[ref\]\$after\) -and') 'False'
# 팝업 '탐색 전' 대피가 핵심입니다. 클릭 직후 대피만으로는 SetCursorPos 가 한 번 실패하거나
# 사용자가 커서를 다시 창 안에 두면 다음 팝업에서 원래 정체가 재현됩니다 (2026-08-09 리뷰).
# 그래서 '몇 곳에 있나'가 아니라 **팝업 함수 각각이 탐색 전에 대피하는가**를 봅니다.
# ※ 앵커는 **바로 다음 줄**로 묶습니다. `(?s)대피.*탐색` 같은 느슨한 패턴은 줄을 건너뛰어
#   짝을 잘못 맺기 때문에, 실제로 탐색 전 대피 한 곳을 지워도 통과했습니다(2026-08-09 변이
#   실험으로 확인). 개수도 `-ge` 가 아니라 **정확한 값**으로 고정합니다 - 늘리거나 줄일 때
#   이 숫자를 함께 고쳐야 리뷰에 걸립니다.
foreach ($popupFn in @('Invoke-PurchasePopupSweep', 'Invoke-AfterEntryKeys')) {
  $fnBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @($popupFn))
  Assert-Case "배선: $popupFn 은 탐색 **바로 앞**에서 대피" `
    ($fnBody -match 'Move-CursorOutsideGame -Game \$Game\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*\$\w+ = Find-GameTextPoint') 'True'
}
# 클리어 대기 루프는 함수가 아니라 본문 인라인이라 구매 팝업 블록을 직접 확인합니다
Assert-Case '배선: 클리어 대기 구매 팝업도 탐색 바로 앞에서 대피' `
  ($workerRaw -match 'Move-CursorOutsideGame -Game \$Game\r?\n\s*\$popupClosePoint = Find-GameTextPoint') 'True'
# ★ 클릭 **직후** 대피는 금지입니다 (2026-08-09 실기 실사고).
#   Click-ScreenPoint 는 mouse UP 뒤 지연 없이 반환합니다. 거기서 곧바로 커서를 빼면 게임이
#   프레임 루프에서 클릭을 처리할 때(16~33ms 뒤) 포인터가 이미 버튼 밖이라 **클릭이 무효화**
#   됩니다. 실기 로그에서 4초 간격으로 '닫기 클릭'만 7회 반복되고 팝업이 끝내 안 닫혔습니다.
#   가림 방지는 '탐색 전 대피'가 전부 담당하므로 클릭 직후 대피는 불필요하고 해롭습니다.
#   ※ 클릭 함수는 **두 가지**입니다 (2026-08-10 교차 리뷰 지적). 원래는 Click-ScreenPoint 만
#     검사해서, 카드 토글이 쓰는 Click-GamePoint 뒤에 대피를 넣어도 그대로 통과했습니다.
Assert-Case '배선: 클릭 직후에는 대피하지 않는다(클릭 무효화 방지)' `
  ($workerRaw -match 'Click-ScreenPoint[^\r\n]*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*Move-CursorOutsideGame') 'False'
Assert-Case '배선: Click-GamePoint 직후에도 대피하지 않는다' `
  ($workerRaw -match 'Click-GamePoint[^\r\n]*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*Move-CursorOutsideGame') 'False'
# 4곳 = 클리어 대기 루프 / 입장 대기 스윕 / 입장 직후 루프 / **그 루프의 연쇄 재확인**.
# 마지막 하나는 5차 점검에서 빠져 있던 것 - 클릭 직후 커서가 '닫기' 위에 남아 다음 팝업을
# 덮으므로, 재확인 앞에도 반드시 대피해야 한다(커서 위 판독 0/6).
# 8곳 = 전투 4곳(클리어 대기 / 입장 대기 스윕 / 입장 직후 루프 / 그 루프의 연쇄 재확인)
#      + 생활 4곳(창 열림 판정 / 팝업 **첫 판독** / 팝업 닫힘 재판독 2곳).
# ★ 생활이 통째로 빠져 있던 것이 7차의 high 결함이고, 그때 재판독 2곳만 넣어 **비교의
#   기준값인 첫 판독**이 남아 있던 것이 8차 결함입니다. 첫 판독이 커서에 가려지면
#   ①'연결 끊김'/'준비물 부족'을 아예 못 잡거나 ②안 닫혔는데 '닫았습니다'가 됩니다.
# 10곳 = 위 8곳 + **전투 판정 2곳**(카드 토글 버튼 OCR / 난이도 알약 픽셀 - 2026-08-10 실기).
# 12곳 = 위 10곳 + **옵션 지도 2곳**(보조 판정 지도 라벨 / 구역 카드 글자 탐색 -
#   2026-08-11 23:55 실사고: 예비 좌표 클릭 커서가 지도 2-1 라벨 위에 남아 오류 캡처
#   재현에서 커서 위 2-1 만 'IL?-1결'로 깨짐. 커서 없는 2-2/2-3 은 배율 6 정상).
Assert-Case '배선: 대피는 판독 직전에만 정확히 12곳' `
  ([regex]::Matches($workerRaw, '(?m)^\s*Move-CursorOutsideGame -Game \$Game\s*$').Count) 12
# 생활의 네 자리를 이름으로도 고정합니다 (개수만 맞추고 엉뚱한 데 넣는 것을 막음)
Assert-Case '배선: 생활 창 열림 판정이 판독 전에 대피' `
  ([bool]([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-LifeWindowOpen')) -match
    'Move-CursorOutsideGame -Game \$Game\r?\n\s*\$glyphHit = Get-LifeCloseGlyphHit')) 'True'
$dialogBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Close-LifeBlockingDialog'))
Assert-Case '배선: 생활 팝업 첫 판독도 판독 전에 대피(비교 기준값)' `
  ([bool]($dialogBody -match 'Move-CursorOutsideGame -Game \$Game\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*\$dialogText = ')) 'True'
Assert-Case '배선: 생활 팝업 닫힘 재판독 2곳이 판독 전에 대피' `
  ([regex]::Matches($dialogBody, 'Move-CursorOutsideGame -Game \$Game\r?\n\s*\$afterText = ').Count) 2
# 옵션 지도 2곳도 위치로 고정합니다 (2026-08-11 23:55 - 개수만 맞추고 엉뚱한 데 넣는 것 방지.
# 대피가 판독/탐색보다 **앞**이어야 커서가 라벨을 덮은 채 읽는 사고가 안 남습니다)
Assert-Case '배선: 옵션 지도 보조 판정이 판독 전에 대피' `
  ([bool]([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-DgOptObservedStage')) -match
    'Move-CursorOutsideGame -Game \$Game\r?\n\s*\$mapTexts = @\(\)')) 'True'
Assert-Case '배선: 옵션 구역 카드 글자 탐색이 탐색 전에 대피' `
  ([bool]([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-DgOptStageCardPoint')) -match
    'Move-CursorOutsideGame -Game \$Game\r?\n\s*foreach \(\$labelScale in \$labelScales\)')) 'True'

# ── ⑭ 전투 판정 2곳의 커서 가림 (2026-08-10 심층 커스텀 반복 실기 실사고) ────
# 클릭 지점이 **판정 대상의 한가운데**인 위젯들입니다. 클릭하면 커서가 바로 그 위에 남아
# 다음 판정을 오염시킵니다. 위 팝업 계열과 기전은 같지만 결과는 더 나쁩니다:
#   · 카드 토글: 버튼 글자 OCR 이 **6/6 실패** → '재확인 생략' → 호출부 커스텀 게이트가
#     반대 설정 입장을 막으려 exit 4. 실제로 심층 2회차가 이렇게 멈췄습니다.
#     실측(1908x1076, 화면 고정·커서만 이동): 커서가 버튼 위 0/6, 90px 아래 6/6 '도전'.
#   · 난이도 알약: 판독 실패가 아니라 **거짓 확인**입니다. 커서의 노란 몸통이 '밝고 채도
#     높은' 히트 조건을 그대로 만족해 비선택 알약에 히트를 얹습니다.
#     실측: '매우 어려움'(비선택) 커서 치움 0/27 → 비선택, 커서 위 3/27 → **선택됨**.
#     임계값 3 에 정확히 도달합니다. 선택하지도 않은 난이도로 그대로 입장하게 됩니다.
# 임계값을 올려 막지 않는 이유: 이번 오탐만 겨우 피할 뿐이고, 정상 선택이 2/18 까지
# 떨어졌던 이력(워커 5189~5194)을 깨 선확인 실패·불필요한 재클릭·Strict 정지를 부릅니다.
# 원인은 판정식이 아니라 화면에 섞인 외부 그래픽이므로 원인만 제거합니다.
# 개수만 세면 엉뚱한 자리에 넣어도 통과하므로 **판독보다 앞인지**를 순서로 못 박습니다.
function Test-ParkBeforeProbe {
  param([string]$Body, [string]$ProbePattern)
  $park = [regex]::Match($Body, '(?m)^\s*Move-CursorOutsideGame -Game \$Game\s*$')
  $probe = [regex]::Match($Body, $ProbePattern)
  if (-not $park.Success) { return '대피없음' }
  if (-not $probe.Success) { return '판독없음' }
  if ($park.Index -lt $probe.Index) { return '대피가앞' }
  return '판독이앞'
}
$pillBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-DifficultySelectedAt'))
# ※ $toggleBody 는 아래 ⑬에서도 쓰지만 여기가 먼저라 여기서 정의합니다 (미정의 변수로
#   검사하면 $null 을 상대로 단언해 전부 헛통과합니다 - PS 는 오류도 내지 않습니다).
$toggleBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Set-DgToggleCard'))
Assert-Case '카드: 대피가 정확히 1곳' `
  ([regex]::Matches($toggleBody, '(?m)^\s*Move-CursorOutsideGame -Game \$Game\s*$').Count) 1
# v10: 버튼 판독이 텍스트 → 단어 목록(Get-GameRegionOcrWords - 자기앵커 클릭용 좌표 포함)으로
# 바뀌었습니다. 대피-판독 순서 계약은 동일합니다.
Assert-Case '카드: 대피가 버튼 OCR 보다 앞' `
  (Test-ParkBeforeProbe -Body $toggleBody -ProbePattern 'Get-GameRegionOcrWords -Game \$Game -ReferenceX \$cardRegion') '대피가앞'
Assert-Case '카드: 대피가 픽셀 폴백보다 앞' `
  (Test-ParkBeforeProbe -Body $toggleBody -ProbePattern 'Get-GamePixel -Game \$Game -ReferenceX \(\$ClickPoint') '대피가앞'
# 판독 루프 **안**이어야 합니다. 함수 첫머리(for 밖)에 두면 클릭 후 회전이 안 걸립니다.
Assert-Case '카드: 대피가 setTry 루프 안(함수 첫머리 아님)' `
  ([bool]($toggleBody -match '(?s)for \(\$setTry = 1;[\s\S]{0,4000}?Move-CursorOutsideGame -Game \$Game')) 'True'
# 캡처 실패 대기 while 뒤여야 합니다 - 화면이 안 돌아온 상태에서 커서만 옮겨봐야 소용없고,
# while 안에 두면 캡처가 정상일 때(대다수) 아예 걸리지 않습니다.
Assert-Case '카드: 대피가 캡처 실패 대기 while 뒤' `
  (Test-ParkBeforeProbe -Body $toggleBody -ProbePattern '\$isSelected = \$false') '대피가앞'
Assert-Case '알약: 대피가 정확히 1곳' `
  ([regex]::Matches($pillBody, '(?m)^\s*Move-CursorOutsideGame -Game \$Game\s*$').Count) 1
Assert-Case '알약: 대피가 픽셀 표본 루프보다 앞' `
  (Test-ParkBeforeProbe -Body $pillBody -ProbePattern 'Get-GamePixel -Game \$Game -ReferenceX \(\$refX') '대피가앞'
# 이 함수 안에 클릭이 있으면 '클릭 직후 대피' 위험이 생깁니다 - 순수 판정 함수로 유지합니다
Assert-Case '알약: 판정 함수 안에 클릭이 없다' `
  ([bool]($pillBody -match 'Click-(GamePoint|ScreenPoint)')) 'False'
# 진단 문자열의 분모는 실제 표본 수(dy 9행 × dx 3열 = 27)여야 합니다. 그물을 넓힐 때
# 문자열만 옛 18 로 남아 제보 로그의 히트율을 실제보다 높게 보이게 했습니다.
$pillCode = (($pillBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
$pillDyCount = ([regex]::Match($pillCode, 'foreach \(\$dy in @\(([^)]*)\)\)').Groups[1].Value -split ',').Count
$pillDxCount = ([regex]::Match($pillCode, 'foreach \(\$dx in @\(([^)]*)\)\)').Groups[1].Value -split ',').Count
Assert-Case '알약: 진단 분모가 실제 표본 수와 일치' `
  ([bool]($pillCode -match ('\{2\}/' + ($pillDyCount * $pillDxCount) + ' '))) 'True'
# ★ Get-ChanceToggleState / Test-TabSelectedAt 에는 **일부러 넣지 않았습니다** (절대 규칙 8).
#   토글은 같은 실험에서 뒤집히지 않았습니다(켜짐 → 커서 위에서도 on). 구조적 이유가 있습니다:
#   커서는 핫스팟에서 오른쪽 아래로 뻗으므로 왼쪽 표본(-11)이 살아남고, 초록 한 점이면 즉시
#   'on' 이며, 노란 커서는 G > R+80 을 만족할 수 없어 off→on 오탐도 못 만듭니다.
#   탭은 해당 UI 가 화면에 없어 **실측을 못 했습니다** - 취약해 보인다는 이유만으로 고치지
#   않고 이슈 문서에 기록해 두었습니다. 실측에서 뒤집히면 그때 같은 방식으로 고칩니다.

# ── ⑬ 로그 정직성 (2026-08-09 실기) ──────────────────────────────────────────
# Click-ScreenPoint 는 커서 확인 실패 시 클릭을 **건너뜁니다**. 그런데 호출부가 무조건
# '닫기 클릭'이라고 기록해, 실기 로그만 보고는 "클릭했다는데 왜 안 닫혔지?"로 헛돌았습니다.
# 실제로 한 일을 그대로 써야 다음 진단이 로그 한 줄로 갈립니다.
$clickBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Click-ScreenPoint'))
Assert-Case '로그: 실제 클릭 여부를 플래그로 남긴다' `
  ([bool](($clickBody -match '\$script:lastClickPerformed = \$false') -and
          ($clickBody -match '\$script:lastClickPerformed = \$true'))) 'True'
Assert-Case '로그: 참 설정은 mouse_event 뒤에만' `
  ([bool]($clickBody -match 'mouse_event\(0x0004[\s\S]{0,120}\$script:lastClickPerformed = \$true')) 'True'
# 3곳 = 클리어 대기 루프의 일반 분기 + **부활 분기** + 입장 대기 스윕.
# 부활 분기는 5차 점검에서 빠져 있던 것 (형제 분기들과 계약이 달랐음).
Assert-Case '로그: 팝업 닫기 3곳이 건너뜀을 구분해 기록' `
  ([regex]::Matches($workerRaw, '커서 확인 실패로 닫기 클릭을 건너뜀').Count) 3
# ★ 카드 토글도 마찬가지입니다. 클릭을 건너뛰었는데 '눌렀다'로 기록하면 ①로그가 거짓이고
#   ②그 상태($script:dgToggleClicked)를 쓰는 소모량 잔상 판정이 '방금 전환했으니 잔상'이라며
#   교차 검증을 건너뜁니다 - 누르지도 않았는데 말입니다 (2026-08-09 5차 점검).
$toggleBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Set-DgToggleCard'))
# ★ 생활도 같은 계약입니다 (8차 점검에서 추가). 여기가 빠져 있어서 커서 확인 실패로 클릭을
#   못 보냈는데도 '창 닫기(X) 클릭' 으로 기록됐고, 뒤이은 '아직 안 닫힘' 로그와 겹쳐
#   "클릭은 나갔는데 게임이 안 먹었다"는 오진을 만들었습니다 - 5~7차가 전투에서 없앤 그것.
$lifeCloseBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Close-LifeOpenWindows'))
Assert-Case '로그: 생활 시작 정리도 실제 클릭일 때만 눌렀다고 기록' `
  ([bool]($lifeCloseBody -match '(?s)Invoke-LifeWindowCloseClick -Game \$Game.{0,600}?if \(\$script:lastClickPerformed\) \{')) 'True'
# 3곳 = 생활 2 + 고스트 등록 안내('나중에' 클릭 생략 - 2026-08-13 신규 화면 처리)
Assert-Case '로그: 생활 건너뜀도 사유를 남긴다' `
  ([regex]::Matches($workerRaw, '커서 확인이 안 돼 .{0,20}클릭을 건너뜀').Count) 3
Assert-Case '로그: 카드 토글도 실제 클릭일 때만 눌렀다고 기록' `
  ([bool]($toggleBody -match 'if \(\$script:lastClickPerformed\) \{[\s\S]{0,400}\$script:dgToggleClicked = \$true')) 'True'
Assert-Case '로그: 토글 건너뜀도 사유를 남긴다' `
  ([bool]($toggleBody -match '버튼 클릭을 건너뜀 \(커서 확인 실패\)')) 'True'
# ★ 8차 점검: 7차가 고친 '현재 상태로 진행합니다' 문구에는 앵커가 하나도 없어, 옛 거짓
#   문구로 되돌려도 회귀가 전부 통과했습니다. 이 문구는 커스텀 모드에서 거짓입니다 -
#   호출부가 소모량 교차 검증에 실패하면 반대 설정 입장을 막으려 곧바로 exit 4 로 정지합니다.
Assert-Case '로그: 토글 실패 문구가 호출부 결과를 단정하지 않는다' `
  ([bool]($toggleBody -match '이 상태 그대로 호출부가 판단합니다')) 'True'
Assert-Case '로그: 옛 단정 문구를 되살리지 않는다' `
  ([bool]($toggleBody -match '맞추지 못했습니다[^\r\n]*현재 상태로 진행합니다')) 'False'
# 반환값이 아니라 스크립트 변수여야 합니다 (PS 5.1 파이프라인 출력 오염 방지 - 호출부 80여 곳)
$clickCode = (($clickBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '로그: 반환값으로 흘리지 않는다(출력 오염 방지)' `
  ([bool]($clickCode -match '(?m)^\s*return \$(true|false)')) 'False'

# ── ⑪ 실행 가드: 함수 본문이 실제로 도는가 ────────────────────────────────────
# 위 ①~⑩은 전부 순수 함수 진리표 + 소스 문자열입니다. 그래서 Move-CursorOutsideGame 이
# 어셈블리 미로드로 **전 PC에서 100% 무동작**인 것을 46종 중 아무도 잡지 못했습니다
# (2026-08-09 배포 차단급). 타입 해석 전수 검사는 tests\test_type_availability.ps1 이
# 담당하고, 여기서는 대피 함수가 쓰는 타입이 워커 어셈블리 세트에 있는지만 못 박습니다.
$workerAsm = @([regex]::Matches($workerRaw, '(?m)^\s*Add-Type -AssemblyName (\S+)') | ForEach-Object { $_.Groups[1].Value })
$parkBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Move-CursorOutsideGame'))
if ($parkBody -match '\[System\.Windows\.Forms\.') {
  Assert-Case '실행: 대피가 WinForms 를 쓰면 워커가 그 어셈블리를 로드한다' `
    ([bool]($workerAsm -contains 'System.Windows.Forms')) 'True'
}
Assert-Case '실행: 대피 실패를 무음으로 삼키지 않는다(로그 필수)' `
  ([bool]($parkBody -match '커서 대피 실패')) 'True'
# 이동에 성공한 뒤에만 대기합니다. '이미 창 밖'이면 그 앞에서 return 하므로 폴링 비용 0.
Assert-Case '실행: 실제로 옮겼을 때만 프레임 대기(이미 창 밖이면 비용 0)' `
  ([bool]($parkBody -match '(?s)SetCursorPos.*Start-Sleep -Milliseconds 120')) 'True'
Assert-Case '실행: 대기가 park 판정($null 조기 return) 뒤에 온다' `
  ([bool]($parkBody -match '(?s)if \(\$null -eq \$park\) \{ return \}.*Start-Sleep -Milliseconds 120')) 'True'

# ── ⑫ catch 안 switch 의 $_ 덮어쓰기 (2026-08-09 3차 점검) ────────────────────
# PS 의 switch 는 블록 안에서 $_ 를 '현재 검사 중인 값'으로 덮어씁니다. 그래서 catch 안에서
# switch 를 쓰고 그 블록에서 $_.Exception.Message 를 읽으면 **빈 문자열**이 됩니다.
# 무음 죽음을 막으려고 넣은 경고가 정작 사유를 못 남기는 상태였습니다.
function Test-CatchDollarUnderscore {
  # 실제 동작을 재현해 '미리 담아야 한다'는 계약을 못 박습니다 (소스 가드만으로는 약함)
  param([switch]$CaptureFirst)
  $result = ''
  try { throw '원인메시지' } catch {
    if ($CaptureFirst) { $saved = $_.Exception.Message }
    switch ('warn') {
      'warn' { $result = $(if ($CaptureFirst) { $saved } else { $_.Exception.Message }) }
      default { }
    }
  }
  return $result
}
Assert-Case '함정: switch 안에서 $_ 를 읽으면 사유가 사라진다' (Test-CatchDollarUnderscore) ''
Assert-Case '함정: catch 진입 직후 담으면 사유가 남는다' (Test-CatchDollarUnderscore -CaptureFirst) '원인메시지'
Assert-Case '배선: 대피 catch 가 switch 전에 사유를 담는다' `
  ([bool]($parkBody -match 'catch \{[\s\S]{0,900}?\$parkError = \$_\.Exception\.Message[\s\S]{0,200}?switch \(')) 'True'
Assert-Case '배선: 경고 문구가 담아 둔 변수를 쓴다(switch 안 $_ 아님)' `
  ([bool]($parkBody -match '커서 대피 실패: \$parkError')) 'True'
# API 실패($false 반환)는 예외가 아니라 catch 로 안 잡힙니다 - 그냥 return 하면 또 무음입니다
Assert-Case '배선: GetWindowRect/GetCursorPos 실패도 사유로 남긴다' `
  ([bool](($parkBody -match 'GetWindowRect 실패') -and ($parkBody -match 'GetCursorPos 실패'))) 'True'
# SetCursorPos 도 예외가 아니라 $false 를 돌려줍니다 - 버리면 '대피 성공'이 화면 상태를
# 보증하지 못합니다. 이동 후 실제로 창 밖인지까지 확인해야 계약이 닫힙니다 (4차 점검).
Assert-Case '배선: SetCursorPos 반환값을 버리지 않는다' `
  ([bool]($parkBody -match 'if \(-not \[HoneyNogiInput\]::SetCursorPos')) 'True'
# ★ 7차 점검: 이 단언은 '창 안'이라는 낱말만 봐서 **주석에만 걸려도 통과**했습니다.
#   확인 코드를 통째로 지워도 초록이던 거짓 안심입니다. 주석 제거본으로 **판정식 자체**를
#   못 박습니다 (창 rect 네 변과의 비교가 실제로 코드에 있는가).
Assert-Case '배선: 대기 후 실제로 창 밖인지 확인한다' `
  ([bool](($parkCodeOnly -match '\$after\.X -ge \$rect\.Left') -and
          ($parkCodeOnly -match '\$after\.X -lt \$rect\.Right') -and
          ($parkCodeOnly -match '\$after\.Y -ge \$rect\.Top') -and
          ($parkCodeOnly -match '\$after\.Y -lt \$rect\.Bottom'))) 'True'
# ★ '창 안'이라고 다 우리 실패가 아닙니다. 실기 15분에 10회 나온 경고가 **전부 사용자가
#   마우스를 움직인 것**이었습니다(보고된 좌표가 매번 달랐고 대피 지점과 무관).
#   그걸 실패로 남기면 "대피가 자꾸 실패한다"는 오진을 다음 사람에게 물려줍니다.
Assert-Case '배선: 이동 전 자리 그대로일 때만 실패로 기록' `
  ([bool]($parkBody -match 'SetCursorPos 가 먹지 않음')) 'True'
# ★ 비교 기준은 **대피 지점이 아니라 이동 전 위치**여야 합니다. $park 는 Get-CursorParkPoint 가
#   '창 밖' 후보만 돌려주므로 구조상 항상 창 밖이라, '창 안 && $park±3px' 는 성립할 수 없는
#   조건이었고 그 throw 가 죽은 코드였습니다 (5차 점검 - 4차 수정이 만든 구멍).
Assert-Case '배선: 이동 전 위치($cursor)와 ±3px 비교' `
  ([bool]($parkBody -match 'Abs\(\$after\.X - \[int\]\$cursor\.X\) -le 3')) 'True'
Assert-Case '배선: 대피 지점($park)과 비교하지 않는다(죽은 가드 방지)' `
  ([bool]($parkBody -match 'Abs\(\$after\.X - \[int\]\$park\.X\)')) 'False'

# 진리표: 대피 후 커서 위치별 판정
function Get-ParkVerdict {
  param([int]$AfterX, [int]$AfterY, [int]$ParkX, [int]$ParkY,
        [int]$L, [int]$T, [int]$R, [int]$B)
  $inside = ($AfterX -ge $L -and $AfterX -lt $R -and $AfterY -ge $T -and $AfterY -lt $B)
  if (-not $inside) { return '성공' }
  if ([Math]::Abs($AfterX - $ParkX) -le 3 -and [Math]::Abs($AfterY - $ParkY) -le 3) { return '실패-경고' }
  return '사용자이동-무시'
}
$gw = @{ L = 648; T = 0; R = 1920; B = 717 }
Assert-Case '판정: 창 밖으로 나감 → 성공' `
  (Get-ParkVerdict 636 358 636 358 $gw.L $gw.T $gw.R $gw.B) '성공'
# 실기에서 실제로 보고된 좌표들 - 전부 사용자 이동이었다
foreach ($seen in @(@(1312, 535), @(1447, 609), @(1198, 638), @(1629, 382), @(1742, 569))) {
  Assert-Case "판정: 실기 관측 ($($seen[0]),$($seen[1])) → 사용자 이동" `
    (Get-ParkVerdict $seen[0] $seen[1] 636 358 $gw.L $gw.T $gw.R $gw.B) '사용자이동-무시'
}
# SetCursorPos 가 정말 안 먹은 경우(대피 지점이 창 안이 되는 배치)만 경고
Assert-Case '판정: 대피 지점 그대로인데 창 안 → 실패 경고' `
  (Get-ParkVerdict 700 358 700 358 $gw.L $gw.T $gw.R $gw.B) '실패-경고'
Assert-Case '판정: 대피 지점 ±3px 안이면 같은 자리로 봄' `
  (Get-ParkVerdict 702 360 700 358 $gw.L $gw.T $gw.R $gw.B) '실패-경고'

exit $fails
