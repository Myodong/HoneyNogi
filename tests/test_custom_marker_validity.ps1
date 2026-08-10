# 완료 마커는 '파일이 있는가'가 아니라 '지금 항목의 유효한 소유자 마커인가'로 판단해야 한다
# (2026-08-09 6차 점검에서 신설).
#
# 무엇이 문제였나:
#   Clear-CustomMarkerFile 은 파일이 잠겨 삭제가 막히면 내용을 '{}' 로 덮어 **소유자 형식을
#   무효화**하고 성공으로 끝냅니다. 그게 그 폴백의 목적입니다. 그런데 종료 코드 처리부는
#   Test-Path 만 봤습니다. 그러면 남은 '{}' 파일이 '이번 판 클리어 확정'으로 읽혀,
#   **돌지도 않은 항목을 완료로 계상하고 건너뜁니다**(코드 4 경로) / **마무리 복구로
#   잘못 분기합니다**(코드 1 경로).
#
#   기존 잠금 테스트는 FileShare::Read 로 열어 삭제와 쓰기를 **둘 다** 막았기 때문에
#   '{}' 분기 자체가 한 번도 실행되지 않았습니다. 여기서는 FileShare::ReadWrite 로 열어
#   **삭제만 막고 쓰기는 허용**해 그 분기를 실제로 태웁니다.
$ErrorActionPreference = 'Stop'
$fails = 0

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw "GUI 파서 오류: $($parseErrors[0].Message)" }
foreach ($name in @('Format-CustomItemToken', 'Get-CustomFingerprint', 'Get-CustomOrderKey',
    'New-CustomMarkerOwnerJson', 'Read-CustomMarkerOwner', 'Test-CustomMarkerOwnerMatchesContext',
    'Test-CustomMarkerValidForCurrent', 'Get-CustomMarkerStaleFile', 'Clear-CustomMarkerFile')) {
  $fn = $ast.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true) | Select-Object -First 1
  if (-not $fn) { throw "본체 함수를 찾지 못했습니다: $name" }
  Invoke-Expression $fn.Extent.Text
}

$testRoot = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),
  ('honeynogi_marker_test_' + [guid]::NewGuid().ToString('N')))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
$customMarkerFile = [System.IO.Path]::Combine($testRoot, 'custom_done.marker')

# 현재 항목 컨텍스트를 고정합니다 (GUI 전역 상태를 끌어오지 않고 계약만 봅니다)
$items = @(
  [pscustomobject]@{ difficulty = '어려움'; stage = '1-3'; coin = $true; doubleLoot = $true },
  [pscustomobject]@{ difficulty = '일반'; stage = '2-1'; coin = $false; doubleLoot = $false }
)
$script:testContext = [pscustomobject]@{
  Items = $items; Order = $null; Lap = 1; Index = 0; Item = $items[0]
}
function Get-CustomCurrentContext { return $script:testContext }
$script:lastGuiLog = ''
function Add-GuiLog { param([string]$Message) $script:lastGuiLog = $Message }

try {
  # ── ① 유효한 소유자 마커는 인정 ─────────────────────────────────────────────
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context $script:testContext))
  Assert-Case '정상: 이번 항목의 마커면 유효' (Test-CustomMarkerValidForCurrent) $true

  # ── ② 다른 항목/바퀴의 마커는 거절 ──────────────────────────────────────────
  $otherContext = [pscustomobject]@{ Items = $items; Order = $null; Lap = 1; Index = 1; Item = $items[1] }
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context $otherContext))
  Assert-Case '거절: 다음 항목의 마커는 무효' (Test-CustomMarkerValidForCurrent) $false
  $nextLap = [pscustomobject]@{ Items = $items; Order = $null; Lap = 2; Index = 0; Item = $items[0] }
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context $nextLap))
  Assert-Case '거절: 다음 바퀴의 마커는 무효' (Test-CustomMarkerValidForCurrent) $false

  # ── ③ 파일이 없으면 당연히 무효 ─────────────────────────────────────────────
  Remove-Item -LiteralPath $customMarkerFile -Force
  Assert-Case '없음: 파일이 없으면 무효' (Test-CustomMarkerValidForCurrent) $false

  # ── ④ ★ '{}' 무효화 폴백이 남긴 파일은 완료로 계상되면 안 된다 ───────────────
  # ※ 이 상태를 **파일 잠금으로는 만들 수 없습니다.** 실측(2026-08-09, 공유 모드 10조합):
  #     공유 Read / Write / ReadWrite  → 삭제 X, Set-Content 도 X (IOException)
  #     공유 Delete / ReadWrite+Delete → 삭제 O (그러면 폴백에 안 들어감)
  #   즉 PS 5.1 의 Set-Content 는 남의 핸들이 DELETE 공유를 안 주면 쓰기도 실패합니다.
  #   그래서 '삭제 실패 + 쓰기 성공'은 잠금이 아니라 **ACL(삭제 거부·쓰기 허용)이나
  #   두 호출 사이에 잠금이 풀리는 타이밍**으로만 생깁니다 - 테스트로 재현하기엔 불안정합니다.
  #   폴백을 억지로 태우는 대신 **그 분기가 남기는 최종 상태**를 직접 만들어 검증합니다.
  #   방어의 본질은 '어떻게 그 파일이 생겼나'가 아니라 '그 파일을 완료로 세지 않는가'입니다.
  [System.IO.File]::WriteAllText($customMarkerFile, '{}')
  Assert-Case '폴백: Test-Path 는 참(옛 판정이 속던 지점)' (Test-Path -LiteralPath $customMarkerFile) $true
  Assert-Case '폴백: 소유자 판독은 null' ($null -eq (Read-CustomMarkerOwner)) $true
  # ★ 여기가 6차에서 닫은 구멍입니다. 파일은 있지만 완료로 계상하면 안 됩니다.
  Assert-Case '폴백: 유효 마커로 인정하지 않음' (Test-CustomMarkerValidForCurrent) $false

  # 잠금으로 둘 다 막히는 경우는 기존 계약(실패 반환 + 묘비)이 그대로여야 합니다
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context $script:testContext))
  $lock = [System.IO.File]::Open($customMarkerFile, [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try { $cleared = Clear-CustomMarkerFile -Path $customMarkerFile }
  finally { $lock.Dispose() }
  Assert-Case '잠금: 무효화 실패를 정직하게 반환' $cleared $false
  Assert-Case '잠금: 묘비 생성' (Test-Path -LiteralPath (Get-CustomMarkerStaleFile -Path $customMarkerFile)) $true
  Remove-Item -LiteralPath (Get-CustomMarkerStaleFile -Path $customMarkerFile) -Force -ErrorAction SilentlyContinue

  # ── ⑤ 부분 파일/구버전 형식도 거절 ──────────────────────────────────────────
  [System.IO.File]::WriteAllText($customMarkerFile, '2026-08-09 12:00:00')   # v1 타임스탬프 마커
  Assert-Case '거절: 구버전 타임스탬프 마커' (Test-CustomMarkerValidForCurrent) $false
  [System.IO.File]::WriteAllText($customMarkerFile, '{"version":2,"lap":1}') # 필수 필드 누락
  Assert-Case '거절: 필수 필드 누락' (Test-CustomMarkerValidForCurrent) $false
  [System.IO.File]::WriteAllText($customMarkerFile, '{ 깨진 json')
  Assert-Case '거절: 깨진 JSON' (Test-CustomMarkerValidForCurrent) $false

  # ── ⑤-2 ★ 판단 불가(컨텍스트 없음)와 무효를 구분한다 (7차 점검) ──────────────
  # Get-CustomCurrentContext 는 부를 때마다 config 를 디스크에서 다시 읽습니다. 그 읽기가
  # 한 번 실패하면 $null 입니다. 이걸 '무효'로 처리하면 **정당하게 끝낸 판을 안 세고 그
  # 항목을 한 번 더 돌립니다** = 재화 이중 소모. 6차 수정이 새로 만든 위험이라 여기서 막습니다.
  # 단, 판단 불가여도 **소유자 형식이 아닌 것('{}')은 여전히 거절**해야 합니다 - 안 그러면
  # 6차에서 닫은 구멍이 이 경로로 다시 열립니다.
  $savedContext = $script:testContext
  $script:testContext = $null
  $script:lastGuiLog = ''
  [System.IO.File]::WriteAllText($customMarkerFile, (New-CustomMarkerOwnerJson -Context $savedContext))
  Assert-Case '판단불가: 소유자 형식이면 인정(이중 소모 방지)' (Test-CustomMarkerValidForCurrent) $true
  Assert-Case '판단불가: 그 사실을 경고로 남긴다' `
    ([bool]($script:lastGuiLog -match '커스텀 진행 정보를 읽지 못해')) $true
  [System.IO.File]::WriteAllText($customMarkerFile, '{}')
  Assert-Case "판단불가: 그래도 '{}' 는 거절(6차 구멍 재개방 방지)" (Test-CustomMarkerValidForCurrent) $false
  [System.IO.File]::WriteAllText($customMarkerFile, '2026-08-09 12:00:00')
  Assert-Case '판단불가: 구버전 타임스탬프도 거절' (Test-CustomMarkerValidForCurrent) $false
  $script:testContext = $savedContext

  # ── ⑥ 배선: 종료 코드 처리부가 Test-Path 가 아니라 유효성으로 판단하는가 ─────
  $guiRaw = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
  Assert-Case '배선: 코드 4 완료 계상이 유효성으로 판단' `
    ($guiRaw -match '\$script:customActive -and -not \$script:customMarkerIgnore -and \(Test-CustomMarkerValidForCurrent\)') $true
  Assert-Case '배선: 코드 1 마무리 복구도 유효성으로 판단' `
    ($guiRaw -match '\(\(-not \$script:customMarkerIgnore\) -and \(Test-CustomMarkerValidForCurrent\)\)') $true
  # 종료 코드 처리부에 맨 Test-Path 판정이 남아 있으면 같은 구멍이 다시 열립니다
  Assert-Case '배선: 종료 코드 처리부에 맨 Test-Path 마커 판정 없음' `
    ([regex]::Matches($guiRaw, '(?:customMarkerIgnore\)? -and \(Test-Path -LiteralPath \$customMarkerFile\))').Count) 0
  # 이어가기 복구와 **같은 판정**을 써야 계상과 복구가 어긋나지 않습니다
  Assert-Case '배선: 이어가기 복구도 같은 소유자 판정을 사용' `
    ($guiRaw -match 'Test-CustomMarkerOwnerMatchesContext -Owner \$markerOwner -Context \$resumeContext') $true
  # ★ 시작 게이트도 '판단 불가'와 '불일치'를 구분해야 합니다 (2026-08-10 8차 점검).
  #   7차는 종료 코드 경로에만 그 구분을 넣었는데, 시작 게이트는 컨텍스트가 $null 이면
  #   '불일치'로 보고 **정당한 완료 마커를 디스크에서 지웁니다.** 종료 코드 경로는 계상만
  #   건너뛰고 마커는 남기지만 이쪽은 되돌릴 수 없어 더 파괴적입니다 - 이미 클리어한 판을
  #   처음부터 다시 돌아 재화를 이중 소모합니다.
  Assert-Case '배선: 시작 게이트가 컨텍스트 읽기를 재시도한다' `
    ($guiRaw -match '(?s)\$resumeContext = Get-CustomCurrentContext\s*\r?\n\s*for \(\$ctxTry = 1; \$ctxTry -le 3 -and -not \$resumeContext') $true
  Assert-Case '배선: 판단 불가면 마커를 지우지 않고 시작을 멈춘다' `
    ($guiRaw -match '(?s)if \(\$markerOwner -and -not \$resumeContext\) \{[\s\S]{0,400}?완료 기록을 지우지 않고 시작을 멈춥니다[\s\S]{0,200}?return') $true
  # 그 분기가 마커 폐기(Clear-CustomMarkerFile)보다 **앞**에 있어야 의미가 있습니다
  $gateIdx = $guiRaw.IndexOf('if ($markerOwner -and -not $resumeContext) {')
  $clearIdx = $guiRaw.IndexOf('현재 진행 위치와 맞지 않는 이전 완료 마커를 정리했습니다')
  Assert-Case '배선: 보호 분기가 마커 폐기보다 앞' `
    ([bool]($gateIdx -ge 0 -and $clearIdx -gt $gateIdx)) $true
} finally {
  Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit $fails
