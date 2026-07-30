# 입장 직후 키 입력 전 구매 팝업 사전 처리 - 소스 계약 (2026-07-28 실기: 물약 부족 입장 시
# 팝업이 먼저 떠 B(음식) 키가 먹히던 문제. 본체: mabinogi_run_once.ps1 Invoke-AfterEntryKeys)
# (2026-07-30 추가) 협동 미션 완료 전체 화면 자동 닫기 배선 가드는 파일 끝에 있습니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$functionText = @(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Invoke-AfterEntryKeys'))[0]

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# 팝업 사전 처리가 키 입력보다 먼저 있어야 함 (닫기 탐색 위치 < 첫 Press-KeyOnce 위치)
$popupSearchIndex = $functionText.IndexOf("-SearchText '닫기'")
$keyPressIndex = $functionText.IndexOf('Press-KeyOnce')
Assert-Case '계약: 닫기 탐색이 존재' ($popupSearchIndex -ge 0) $true
Assert-Case '계약: 키 입력이 존재' ($keyPressIndex -ge 0) $true
Assert-Case '계약: 닫기 탐색이 키 입력보다 먼저' ($popupSearchIndex -lt $keyPressIndex) $true

# 확인 최대 4회 = 닫기 최대 3회 + 마지막 재확인 (무팝업이면 OCR 1회 - Codex 합의 계약)
Assert-Case '계약: 확인 루프 상한 4회' ($functionText -match '\$popupTry -le 4') $true
Assert-Case '계약: 4회째는 클릭 없이 잔존 판정만' ($functionText -match '\$popupTry -ge 4[\s\S]{0,80}break') $true

# 캡처 실패 중에는 사전 처리를 건너뛰고 키 입력 (실패를 팝업 잔존으로 오인 금지 - Codex 지적)
Assert-Case '계약: 캡처 실패 가드' ($functionText -match 'if \(-not \$script:screenCaptureFailing\)') $true

# 키 입력 루프는 1개 그대로 (재입력 금지 - B 이중 입력은 음식 중복 소모 위험)
Assert-Case '계약: Press-KeyOnce 는 1곳뿐' ([regex]::Matches($functionText, 'Press-KeyOnce').Count) 1
Assert-Case '계약: 잔존 시 경고 후 진행' ($functionText -match '\[경고\] 구매 팝업이 닫히지 않습니다') $true

# ── 협동 미션 완료 전체 화면 자동 닫기 (2026-07-30 캡처 실측) ──────────────────
# 제목('협동 미션 완료')은 OCR이 '협동1/四완로'로 깨져 사용 불가 → 이 화면 전용 부제 조각
# ('우편으로'+'전송' / '캐릭터가위치한')으로 감지. 확인 버튼은 퀘스트 보상과 같은 자리 재사용.
# 검증: 대상 캡처 감지 성공 + 보관 캡처 92장 오탐 0 (오프라인 스윕)
$sweepSource = [string]@(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Invoke-PurchasePopupSweep'))[0]
Assert-Case '협동: 스윕 함수 추출' ($sweepSource.Length -gt 0) $true
Assert-Case '협동: 부제 영역(360,285,560,35) 판독' `
  ($sweepSource -match '-ReferenceX 360 -ReferenceY 285[\s\S]{0,120}-RegionWidth 560 -RegionHeight 35') $true
Assert-Case '협동: 부제 조각 조건(우편으로+전송 / 캐릭터가위치한)' `
  ($sweepSource -match "우편으로'\)[\s\S]{0,60}전송'\)[\s\S]{0,80}캐릭터가위치한'\)") $true
Assert-Case '협동: 확인 버튼 영역 재사용 + 클릭 후 true' `
  ($sweepSource -match '협동 미션 완료 화면 감지[\s\S]{0,120}return \$true') $true
# 제목 조각을 감지에 쓰지 않아야 함 (OCR 깨짐 실측 - '협동 미션 완료' 문자열 매칭 금지)
Assert-Case '협동: 깨지는 제목 조각은 감지에 미사용' `
  ($sweepSource -notmatch "Contains\('협동미션완료'\)") $true

exit $fails
