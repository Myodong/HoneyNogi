# ASSIST 자동 켜기 진리표 + 비전투 캡처 오탐 스윕 (2026-07-28 실측 기반)
# 본체: mabinogi_run_once.ps1 Get-AssistStateFromColors (Get-AssistState 의 순수 분류부)
# 실측 (1272x717, 토글 필 y=513 / L=1209 M=1216 R=1228):
#  꺼짐 = L 흰 점(255,255,255) + M/R 회색(78~100) / 켜짐 분홍(클래스 특화) = (206,64,96)
#  켜짐 초록(일반) = (13,179,118). 캡처: 던전이미지\어시스트\ 4장.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Get-AssistStateFromColors')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

function New-Color { param([int]$R, [int]$G, [int]$B) [pscustomobject]@{ R = $R; G = $G; B = $B } }

# ── 1. 실측 3상태 ───────────────────────────────────────────────────────────
$white = New-Color 255 255 255
$grey1 = New-Color 85 93 100
$grey2 = New-Color 78 84 95
$pink  = New-Color 206 64 96
$green = New-Color 13 179 118
$bgPurple = New-Color 42 35 72

Assert-Case '꺼짐: 실측(흰 점 + 회색 필)' (Get-AssistStateFromColors -Left $white -Mid $grey1 -Right $grey1) 'off'
Assert-Case '꺼짐: 회색 변형(78,84,95)' (Get-AssistStateFromColors -Left $white -Mid $grey2 -Right $grey1) 'off'
Assert-Case '켜짐: 분홍(클래스 특화) - R점은 흰 점이어도 무관' (Get-AssistStateFromColors -Left $pink -Mid $pink -Right $white) 'on'
Assert-Case '켜짐: 분홍 - R점 그대로 분홍이어도 on' (Get-AssistStateFromColors -Left $pink -Mid $pink -Right $pink) 'on'
Assert-Case '켜짐: 초록(일반) 실측' (Get-AssistStateFromColors -Left $green -Mid $green -Right (New-Color 61 52 105)) 'on'

# ── 2. unknown (오입력 방지 - 꺼짐/켜짐 패턴 밖은 전부 무동작) ──────────────
Assert-Case '불명: 혼합색(분홍+초록)은 켜짐 불인정' (Get-AssistStateFromColors -Left $pink -Mid $green -Right $white) 'unknown'
Assert-Case '불명: 전부 회색(점 없음)' (Get-AssistStateFromColors -Left $grey1 -Mid $grey1 -Right $grey1) 'unknown'
Assert-Case '불명: 전부 흰색(밝은 화면)' (Get-AssistStateFromColors -Left $white -Mid $white -Right $white) 'unknown'
Assert-Case '불명: 배경 보라(토글 없음 실측)' (Get-AssistStateFromColors -Left $bgPurple -Mid $bgPurple -Right $bgPurple) 'unknown'
Assert-Case '불명: 흰 점 + 회색 + 분홍(오른쪽 비회색)' (Get-AssistStateFromColors -Left $white -Mid $grey1 -Right $pink) 'unknown'
Assert-Case '불명: 흰 점 왼쪽인데 가운데도 흰색' (Get-AssistStateFromColors -Left $white -Mid $white -Right $grey1) 'unknown'
Assert-Case '불명: 노란 스킬 버튼 가정(230,200,80)' (Get-AssistStateFromColors -Left (New-Color 230 200 80) -Mid (New-Color 230 200 80) -Right (New-Color 230 200 80)) 'unknown'
Assert-Case '불명: 검정(로딩 화면)' (Get-AssistStateFromColors -Left (New-Color 5 5 5) -Mid (New-Color 5 5 5) -Right (New-Color 5 5 5)) 'unknown'

# ── 3. 실측 캡처 판독 (어시스트 4장 = 기대 상태, 비전투 85장 = 'off' 금지) ──
Add-Type -AssemblyName System.Drawing
function Get-CaptureAssistState {
  param([string]$Path)
  $bmp = [System.Drawing.Bitmap]::FromFile($Path)
  try {
    if ($bmp.Width -ne 1272 -or $bmp.Height -ne 717) { return 'skip' }   # 기준 크기 외 캡처는 좌표 불일치
    $left = $bmp.GetPixel(1209, 513); $mid = $bmp.GetPixel(1216, 513); $right = $bmp.GetPixel(1228, 513)
    return (Get-AssistStateFromColors -Left $left -Mid $mid -Right $right)
  } finally { $bmp.Dispose() }
}

$assistDir = Join-Path $projectRoot '던전이미지\어시스트'
if (Test-Path -LiteralPath $assistDir) {
  Assert-Case '캡처: assist_상태1(꺼짐)' (Get-CaptureAssistState (Join-Path $assistDir 'assist_상태1.png')) 'off'
  Assert-Case '캡처: assist_상태2(꺼짐)' (Get-CaptureAssistState (Join-Path $assistDir 'assist_상태2.png')) 'off'
  Assert-Case '캡처: assist_켜짐(분홍)' (Get-CaptureAssistState (Join-Path $assistDir 'assist_켜짐.png')) 'on'
  Assert-Case '캡처: assist_켜짐_초록' (Get-CaptureAssistState (Join-Path $assistDir 'assist_켜짐_초록.png')) 'on'
} else {
  "SKIP 어시스트 실측 캡처 폴더 없음: $assistDir"
}

# 비전투 화면(던전/심층 선택·옵션 캡처 전수)에서 'off' 판정 = H 오입력 트리거이므로 0건이어야 함
# ('on'/'unknown'은 무동작이라 허용 - Codex 오탐 검증 요구)
$sweepDirs = @((Join-Path $projectRoot '던전이미지\던전'), (Join-Path $projectRoot '던전이미지\심층던전'))
$sweepTotal = 0
$sweepOffHits = @()
foreach ($sweepDir in $sweepDirs) {
  if (-not (Test-Path -LiteralPath $sweepDir)) { continue }
  foreach ($png in (Get-ChildItem -LiteralPath $sweepDir -Filter '*.png')) {
    $sweepState = Get-CaptureAssistState $png.FullName
    if ($sweepState -eq 'skip') { continue }
    $sweepTotal++
    if ($sweepState -eq 'off') { $sweepOffHits += $png.Name }
  }
}
Assert-Case "비전투 캡처 ${sweepTotal}장 스윕: 'off' 오탐 0건" ($sweepOffHits.Count) 0
foreach ($offHit in $sweepOffHits) { "FAIL 오탐 캡처: $offHit"; }

# ── 4. 배선 가드 ────────────────────────────────────────────────────────────
$workerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '배선(워커): 클리어 대기 루프에 ASSIST 감시' `
  ($workerSource -match 'if \(\$assistAutoOn -and -not \$script:screenCaptureFailing\)[\s\S]{0,200}Get-AssistState -Game') $true
Assert-Case '배선(워커): off 일 때만 키 입력' `
  ($workerSource -match "assistState -eq 'off'[\s\S]{0,700}Press-KeyOnce -VirtualKey \(\[byte\]\`$assistKey\)") $true
Assert-Case '배선(워커): assist 설정 로드(기본 켬/H키)' `
  ($workerSource -match "@\('assist', 'autoEnable'\) \`$true" -and $workerSource -match "@\('assist', 'key'\) 72") $true
$guiSource = Get-Content -LiteralPath (Join-Path $projectRoot 'mabinogi_gui.ps1') -Raw -Encoding UTF8
Assert-Case '배선(GUI): 체크박스 저장/로드' `
  (($guiSource -match '\$cfg\.assist\.autoEnable = \[bool\]\$chkAssist\.Checked') -and
   ($guiSource -match '\$chkAssist\.Checked = ConvertTo-StrictBoolean \$cfg\.assist\.autoEnable')) $true
Assert-Case '배선(GUI): 마이그레이션 섹션 목록에 assist' ($guiSource -match "'deepCustomRepeat', 'lifeCustomRepeat', 'assist', 'life'\)") $true   # v2.0.0: life 섹션 + 생활 커스텀 섹션 추가

exit $fails
