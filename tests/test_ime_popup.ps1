# IME 팝업 가림 대응 진리표 + 배선 가드 (2026-07-29 00:20 실기 사고)
# 본체: mabinogi_run_once.ps1 - Test-ImeOverlayText / Invoke-ClickUntil 예비 지점 / 입장 루프 팝업 대기
# 판별식 실측 검증: 보관+오류 캡처 103장 오프라인 OCR 스윕에서 팝업 실존 3장만 판정(오탐 0)
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-ImeOverlayText')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 1. 판별식 진리표 (참 케이스 = 실측 OCR 원문/이형) ─────────────────────────
$imeCases = @(
  @{ N = '오류 캡처 원문(00:20)';   T = '한국어Microsoft입력기입력방법을전환하己1면Windows기+스페이스를누르세요.'; E = $true }
  @{ N = '보관 캡처 원문(페카)';    T = '한국어Microsoft입력기입력방법을전환하러면Windows기+스페이스를누르세요.'; E = $true }
  @{ N = '진단 OCR 원문(Space 혼입)'; T = 'SpaceMicrosoft입력기심층1층입력방법을전환하러면Windows기+스페이스'; E = $true }
  @{ N = '부분: 상단 줄만';         T = '한국어Microsoft입력기';           E = $true }
  @{ N = '부분: 안내문만';          T = '입력방법을전환하려면';             E = $true }
  @{ N = '부분: 단축키 줄만';       T = 'Windows키+스페이스를누르세요';     E = $true }
  # 거짓 케이스: 게임 버튼/화면 정상 문자열 (조각 단독은 오탐 방지를 위해 불인정 - 리뷰 계약)
  @{ N = '진입 버튼 정상';          T = '1층2구역진입';                     E = $false }
  @{ N = '심층 진입 버튼';          T = '심층1층2구역진입';                 E = $false }
  @{ N = '입장하기+소모량 이형';    T = '71입장하기';                       E = $false }
  @{ N = '파티 찾기';               T = '파티찾기';                         E = $false }
  @{ N = '조각 단독(스페이스)은 불인정'; T = '스페이스를누르세요';          E = $false }
  @{ N = '조각 단독(입력)은 불인정'; T = '입력하기';                        E = $false }
  @{ N = '빈 판독';                 T = '';                                 E = $false }
)
foreach ($case in $imeCases) {
  Assert-Case $case.N (Test-ImeOverlayText -Text $case.T) $case.E
}

# ── 2. 배선 가드 (워커 원문 검사) ─────────────────────────────────────────────
$workerSource = [IO.File]::ReadAllText($workerPath)

# Invoke-ClickUntil이 예비 지점 계약을 갖고, 예비 클릭은 원래 지점 클릭과 배타(elseif)여야 함
Assert-Case '배선: Invoke-ClickUntil 예비 파라미터' `
  (($workerSource -match '\[int\[\]\]\$FallbackPoint') -and ($workerSource -match '\[scriptblock\]\$FallbackCondition')) $true
Assert-Case '배선: 예비 클릭은 사이클당 1클릭 유지(elseif)' `
  ($workerSource -match 'elseif \(\$null -ne \$FallbackPoint') $true

# 선택→옵션 전환 콜사이트 3곳 전부 예비 지점 + 선택 화면 제목 게이트 (옵션 화면의 같은
# 자리는 '파티 찾기' 초록 버튼이라 제목 게이트 없는 예비 클릭은 금지 - 65장 픽셀 실측)
$fallbackSites = [regex]::Matches($workerSource,
  '-FallbackPoint \$ptDgStageEnterLeft -FallbackCondition \{[\s\S]{0,400}?Test-DgImePopupVisible[\s\S]{0,200}?Test-DgSelectionTitle')
Assert-Case '배선: 진입 전환 3곳 예비 지점 + 제목 게이트' ($fallbackSites.Count -ge 3) $true

# 좌표/영역 정의 (하드코딩 - coordsVersion 무관)
Assert-Case '배선: 예비 클릭 지점 정의' ($workerSource -match '\$ptDgStageEnterLeft = @\(770, 655\)') $true
Assert-Case '배선: 팝업 전용 판독 영역 정의' ($workerSource -match '\$rgImePopup = @\(905, 610, 360, 95\)') $true

# 입장 재시도 루프(던전+사냥터)의 팝업 대기: 시도 미계상($enterTry--) + 40초 한도 안전 정지.
# 팝업 중에는 재화 부족 폴백을 평가하지 않아야 함 (부족 오판 소탕 해제 방지 - 리뷰 계약)
# 2026-08-01 전수 점검: 클릭 '전' 사전 게이트 추가(가려진 좌표를 확인 없이 재클릭하지 않기
# 위한 재클릭 정책 준수) - 던전/사냥터 각 사전+사후 4곳 + 사냥터 '소탕만 계속' 폴백 바퀴
# 미계상 1곳(마지막 회전에서 발견돼도 재입장 보장 - 교차 리뷰) = 총 5곳
Assert-Case '배선: 입장 루프 팝업/폴백 시도 미계상 5곳' `
  ([regex]::Matches($workerSource, '\$enterTry--').Count -eq 5) $true
Assert-Case '배선: 팝업 대기 40초 한도 안전 정지' `
  ([regex]::Matches($workerSource, '\$imePopupWaitTotal -ge 40').Count -eq 4) $true

# 소모량 판독의 팝업 선차단 (00:48 실사고: 팝업 글자 오독 '전환하己1면'의 '1'이 소모량으로
# 잡혀 10초 내내 '1' → 미사용 항목 오정지): Get-DgTributeCost는 팝업 중 판독 불가($null)
# + $script:dgCostImeBlocked 표시. 역방향 경로는 팝업 중 판정하지 않고 대기(시도 미계상)
Assert-Case '배선: Get-DgTributeCost 팝업 선차단' `
  ($workerSource -match 'Test-DgImePopupVisible -Game \$Game\)\s*\{\s*\$script:dgCostImeBlocked = \$true\s*return \$null') $true
# 01:45 실기 확정: '1' 지속의 원인은 게임이 소탕 카드를 끈 뒤에도 소모량 표시를 13초+
# 남겨두는 표시 지연 (커서 파킹으로도 재현 → 호버 이론 반증, 파킹 제거 - 리뷰 지시).
# 대응: 방금 우리가 클릭해 '도전' 전환을 카드 글자로 확인한 경우 소모량 교차 검증 생략
Assert-Case '배선: 소모량 판독에 커서 파킹 없음(반증 후 제거)' `
  ($workerSource -notmatch 'function Get-DgTributeCost[\s\S]{0,2400}?SetCursorPos') $true
Assert-Case '배선: Set-DgToggleCard 클릭 플래그(매 호출 초기화+클릭 시 참)' `
  (($workerSource -match '\$script:dgToggleClicked = \$false') -and
   ($workerSource -match '\$clicked = \$true\s*\$script:dgToggleClicked = \$true')) $true
Assert-Case '배선: 전환 직후 역방향 생략 2곳(던전/사냥터)' `
  (([regex]::Matches($workerSource, '소모량 표시 검증 생략').Count -eq 2) -and
   ([regex]::Matches($workerSource, '\$coinToggleClicked = \$script:dgToggleClicked').Count -eq 2) -and
   # 2026-08-09 감사: 생략 조건에 '상태를 실제로 재판독함'($coinToggleRechecked)을 추가.
   # Set-DgToggleCard 의 $true 는 클릭 후 판독 실패('재확인 생략')일 때도 나오므로,
   # Ok 만으로 생략하면 검증 없이 넘어가는 셈이었습니다.
   ([regex]::Matches($workerSource, 'if \(\$coinToggleClicked -and \$coinToggleOk -and \$coinToggleRechecked\)').Count -eq 2)) $true
Assert-Case '배선: 역방향 루프 팝업 대기 2곳(던전/사냥터, 시도 미계상)' `
  (([regex]::Matches($workerSource, '\$imeOffWaitTotal -ge 40').Count -eq 2) -and
   ([regex]::Matches($workerSource, '\$offTry--').Count -eq 2)) $true
Assert-Case '배선: 역방향 트리거 팝업 건너뜀 안내 2곳' `
  ([regex]::Matches($workerSource, '소모량 역방향 확인을 건너뜁니다').Count -eq 2) $true

# '부족 추정' 해제 금지 계약 (리뷰): 잔량을 못 읽으면 소탕/더블 루팅을 추정으로 풀지 않고
# 안전 정지. 잔량이 실제로 읽힌 증거 기반 분기($null -ne $retryBalance)만 남아야 함
# (07-28 23:49 실사고: 공물 2개 보유인데 '부족 추정' 소탕 해제 후 진행)
Assert-Case '배선: 잔량 미판독 추정 해제 분기 없음' `
  ($workerSource -notmatch '\$null -eq \$retryBalance -and') $true
Assert-Case '배선: 입장 실패 문구에 부족 추정 없음' `
  ($workerSource -notmatch '입장 안 됨\(.{0,12}부족 추정\)') $true
# 2026-07-30 01:42 실기: 소탕 사용 + 잔량 미판독 + 입장 거부 조합은 오류(throw) 대신
# 코드 4 안내 정지 (임의 해제 없음 - 문구·종료 코드만. 잔량 읽힌 증거 분기·기타 원인
# throw 는 유지)
Assert-Case '배선: 소탕+잔량 미판독 입장 거부 = 코드 4 안내 정지' `
  ($workerSource -match 'if \(\$effectiveCoin -and \$null -eq \$finalBalance\)[\s\S]{0,900}?부족으로 보입니다[\s\S]{0,200}?exit 4') $true

if ($fails -gt 0) { "총 $fails 건 실패"; exit 1 }
'전체 통과'
exit 0
