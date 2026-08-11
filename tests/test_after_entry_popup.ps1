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
$keyPressIndex = $functionText.IndexOf('Press-KeyVerified')   # 2026-08-11 ④: 검증 입력으로 격상
Assert-Case '계약: 닫기 탐색이 존재' ($popupSearchIndex -ge 0) $true
Assert-Case '계약: 키 입력이 존재' ($keyPressIndex -ge 0) $true
Assert-Case '계약: 닫기 탐색이 키 입력보다 먼저' ($popupSearchIndex -lt $keyPressIndex) $true

# 확인 최대 4회 = 닫기 최대 3회 + 마지막 재확인 (무팝업이면 OCR 1회 - 설계 합의 계약)
Assert-Case '계약: 확인 루프 상한 4회' ($functionText -match '\$popupTry -le 4') $true
Assert-Case '계약: 4회째는 클릭 없이 잔존 판정만' ($functionText -match '\$popupTry -ge 4[\s\S]{0,80}break') $true

# 캡처 실패 중에는 사전 처리를 건너뛰고 키 입력 (실패를 팝업 잔존으로 오인 금지 - 리뷰 지적)
Assert-Case '계약: 캡처 실패 가드' ($functionText -match 'if \(-not \$script:screenCaptureFailing\)') $true

# 키 입력 루프는 1개 그대로 (재입력 금지 - B 이중 입력은 음식 중복 소모 위험)
Assert-Case '계약: 검증 키 입력 1곳 + 직접 Press-KeyOnce 0곳' ('{0}/{1}' -f [regex]::Matches($functionText, 'Press-KeyVerified').Count, [regex]::Matches($functionText, 'Press-KeyOnce').Count) '1/0'
# 7차: 잔존 경고에 **실제 닫은 횟수**를 함께 적습니다. 3회 전부 성공했는데도 남았다면 그건
# 클릭 불량이 아니라 연쇄가 길었던 것인데, 옛 문구는 둘을 구분하지 못해 진단이 헛돌았습니다.
Assert-Case '계약: 잔존 시 경고 후 진행' ($functionText -match '\[경고\] 닫기 클릭 .*뒤에도 구매 팝업이 남아 있습니다') $true
Assert-Case '계약: 잔존 경고에 실제 클릭 횟수를 적는다' ($functionText -match '\$\{entryPopupClicks\}회 뒤에도') $true
# 클릭을 한 번도 못 보낸 잔존은 사유를 구분해 남깁니다 (예전엔 그 경우가 통째로 침묵이었음)
Assert-Case '계약: 클릭 0회 잔존도 알린다' ($functionText -match '닫기 클릭을 한 번도 보내지 못했습니다') $true

# ── 협동 미션 완료 전체 화면 자동 닫기 (2026-07-30 캡처 실측) ──────────────────
# 제목('협동 미션 완료')은 OCR이 '협동1/四완로'로 깨져 사용 불가 → 이 화면 전용 부제 조각
# ('우편으로'+'전송' / '캐릭터가위치한')으로 감지. 확인 버튼은 퀘스트 보상과 같은 자리 재사용.
# 검증: 대상 캡처 감지 성공 + 보관 캡처 92장 오탐 0 (오프라인 스윕)
$coopSource = [string]@(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
    -Names @('Close-CoopMissionScreen'))[0]
Assert-Case '협동: 공용 소함수 존재' ($coopSource.Length -gt 0) $true
Assert-Case '협동: 부제 영역(360,285,560,35) 판독' `
  ($coopSource -match '-ReferenceX 360 -ReferenceY 285[\s\S]{0,120}-RegionWidth 560 -RegionHeight 35') $true
Assert-Case '협동: 부제 조각 조건(우편으로+전송 / 캐릭터가위치한)' `
  ($coopSource -match "우편으로'\)[\s\S]{0,60}전송'\)[\s\S]{0,80}캐릭터가위치한'\)") $true
Assert-Case '협동: 확인 버튼 영역 재사용 + 클릭 후 true' `
  ($coopSource -match '협동 미션 완료 화면 감지[\s\S]{0,120}return \$true') $true
# 제목 조각을 감지에 쓰지 않아야 함 (OCR 깨짐 실측 - '협동 미션 완료' 문자열 매칭 금지)
Assert-Case '협동: 깨지는 제목 조각은 감지에 미사용' `
  ($coopSource -notmatch "Contains\('협동미션완료'\)") $true

# 2026-07-31 점검: 협동 미션은 몬스터 처치 누적으로 완료되므로 전투/클리어 대기 중에 뜰
# 확률이 가장 높은데, 클리어 대기 루프는 입장용 팝업 스윕을 쓰지 않아 사각지대였음
# → 입장 대기(스윕)와 클리어 대기 루프가 같은 소함수를 공용해야 함 (리뷰 조건)
$workerAll = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_run_once.ps1'))
Assert-Case '협동: 스윕이 공용 소함수를 호출' `
  ([bool]([regex]::Match($workerAll, 'function Invoke-PurchasePopupSweep[\s\S]*?\r?\n\}').Value -match
    'if \(Close-CoopMissionScreen -Game \$Game\) \{ return \$true \}')) $true
Assert-Case '협동: 클리어 대기 루프에도 배선(반환값 소비 + continue)' `
  ([bool]([string]@(Get-SourceFunctionDefinitions -Path (Join-Path $projectRoot 'mabinogi_run_once.ps1') `
        -Names @('Wait-ForDungeonClearScreen'))[0] -match
    'if \(Close-CoopMissionScreen -Game \$Game\) \{ continue \}')) $true
Assert-Case '협동: 호출 2곳(스윕 + 클리어 대기)' `
  ([regex]::Matches($workerAll, 'Close-CoopMissionScreen -Game').Count) 2

# ── v1.2.1 (2026-08-01 실사고): 확인 버튼 다중 스케일 + 실측 좌표 폴백 + 시작 전 스윕 ──
# 기본 s3 이 확인 버튼을 '>poce'/'할인'으로 깨뜨려 두 밤 연속 라이브 미감지 (오류 캡처 재현
# 확정 - s4 정상). 실패 시 로그 없이 포기하던 구조도 폴백+로그로 보강.
Assert-Case '협동: 확인 버튼 다중 스케일(3,4,5)' `
  ($coopSource -match "foreach \(\`$coopBtnScale in @\(3, 4, 5\)\)") $true
Assert-Case '협동: 폴백은 부제 재확인 후 실측 좌표(636,654)' `
  ($coopSource -match '\$coopRecheck[\s\S]{0,400}실측 좌표로 클릭[\s\S]{0,200}-ReferenceX 636 -ReferenceY 654') $true
# 시작 화면 판정 전 팝업 스윕 (재시도 워커 즉사 → 자가 복구 전환): 던전/심층 + 사냥터 +
# 메인 공통 = 3곳, '닫은 경우에만 1.2초 대기, 최대 2회' 계약
Assert-Case '시작 스윕: 3곳(던전·사냥터·메인 공통)' `
  ([regex]::Matches($workerAll, 'if \(-not \(Invoke-PurchasePopupSweep -Game \$[Gg]ame\)\) \{ break \}\s+Start-Sleep -Milliseconds 1200').Count) 3
Assert-Case '시작 스윕: 던전 사이클 제목 첫 판독보다 앞' `
  ([bool]([regex]::Match($workerAll, 'function Invoke-NormalDungeonCycle[\s\S]{0,4200}').Value -match
    'Invoke-PurchasePopupSweep[\s\S]{0,300}\$titleText = & \$readDgTitle')) $true

exit $fails
