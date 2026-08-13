# 던전 구역 지도 4유형 좌표 체계 진리표 (2026-07-24 확정 실측 40장 기반)
# 본체: mabinogi_run_once.ps1 - 던전 ID 판별 / 유형 매핑 / 선택·옵션 템플릿 / 카드 색 판별
# 데이터 표는 AST로 본체에서 직접 추출해 사본 불일치를 방지합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Get-DgDungeonIdFromTitle', 'Test-DgCardColor', 'Get-DgSelStagePoint', 'Get-DgOptStageFallbackPoint',
             'Select-DgDifficultyWord', 'Resolve-DgObservedStage', 'Test-DgSelectionTitle', 'Select-DgChanceToggleAnchor')) {
  Invoke-Expression $definition
}
# 본체의 데이터 표를 AST 로 추출 (변수 사본을 수작업으로 복제하지 않음 - 값 자체가 진리표)
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
foreach ($varName in @('dgFocusShiftY', 'dgLayoutTable', 'dgNamePatterns', 'dgSelStagePoints', 'dgOptStagePoints', 'ddNamePatterns')) {
  $assign = $sourceAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $varName))
    }, $true)
  if (-not $assign) { "FAIL 본체에서 `$$varName 정의를 찾지 못했습니다"; exit 1 }
  Invoke-Expression $assign.Extent.Text
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 1. 던전 ID 판별 (오독 이형 = 실측 문자열) ────────────────────────────────
$idCases = @(
  @{ N = '선택 화면 정상';        T = '룬다 던전';        E = '룬다' }
  @{ N = '룬다 오독(로다)';       T = '로다1층3구역';     E = '룬다' }
  @{ N = '룬다 오독(른다, 실기)'; T = '|른다2층2구역';    E = '룬다' }
  @{ N = '룬다 오독(분다, 실기)'; T = '분다던전';         E = '룬다' }
  @{ N = '룬다 오독(닡다, 실기)'; T = '닡다1층2구역';     E = '룬다' }
  @{ N = '피오드 오독(사고 원문)'; T = '피오듸층3구역';    E = '피오드' }
  @{ N = '페론 오독(페로)';       T = '페로고분1층3구역'; E = '페론고분' }
  @{ N = '페카 옵션 제목';        T = '페카고분1층3구역'; E = '페카고분' }
  @{ N = '바리 1광구';            T = '바리1광구';        E = '바리1광구' }
  @{ N = '바리 2광구 옵션';       T = '바리2광구1층1구역'; E = '바리2광구' }
  @{ N = '바리 광구 숫자 소실 = 불명'; T = '바리광구';    E = '' }
  @{ N = '마스';                  T = '마스1층1구역';     E = '마스던전' }
  @{ N = '라비';                  T = '라비 던전';        E = '라비던전' }
  @{ N = '알비';                  T = '알비 던전';        E = '알비던전' }
  @{ N = '키아';                  T = '키아1층1구역';     E = '키아던전' }
  @{ N = '미등록 던전';           T = '글라스기브넨던전'; E = '' }
  @{ N = '빈 제목';               T = '';                 E = '' }
  @{ N = '다중 매칭 = 불명';      T = '라비알비';         E = '' }
  @{ N = '룬다 오독(눛나, 실기)'; T = '눛나던전';         E = '룬다' }
  @{ N = '피오드 오독(깨오, 실기)'; T = '깨오드1층1구역'; E = '피오드' }
  @{ N = '피오드 오독(오드만 생존)'; T = '오드1층3구역';  E = '피오드' }
  @{ N = '페카 오독(패가, 실기)'; T = '패가고분';         E = '페카고분' }
  @{ N = '페론 오독(페혼, 실기)'; T = '페혼고분1층1구역'; E = '페론고분' }
  @{ N = '페론 오독(페붇, 실기)'; T = '페붇고분1층2구역'; E = '페론고분' }
  @{ N = '바리오드 = 오드+바리 다중 매칭 불명'; T = '바리오드'; E = '' }
  @{ N = '마스 오독(마싀 = 마스+1층 합침, 실기)'; T = '〈마싀층2구역'; E = '마스던전' }
  @{ N = '라비 오독(라바, 실기)'; T = '라바2층1구역'; E = '라비던전' }
  @{ N = '키아 오독(기아, 실기)'; T = '기아2츰1구역'; E = '키아던전' }
  @{ N = '룬다 오독(실다, 실기 08-12)'; T = '실다2층3구역'; E = '룬다' }
  @{ N = '실다+오드 다중 매칭 불명'; T = '실다오드'; E = '' }
  # v9 (2026-08-13 네이티브 1908 실측 - 제목 영역 상단 확장 스윕에서 관측된 이형 등록)
  @{ N = '페카 오독(메카고분, 네이티브 1908 실측 3회)'; T = '메카고분0°°=='; E = '페카고분' }
  @{ N = '페카 오독(涎분 뭉개짐, 실측)'; T = '〈페,涎분2층1구역'; E = '페카고분' }
  @{ N = '메카 단독은 미등록(관측 전부 메카고분 형태 - 확장 안 함)'; T = '메카'; E = '' }
  @{ N = '페론 오독(페붙고분, 실측)'; T = '〈페붙고분1층1구역'; E = '페론고분' }
)
foreach ($case in $idCases) {
  Assert-Case "ID: $($case.N)" ([string](Get-DgDungeonIdFromTitle -TitleText $case.T)) $case.E
}
# 심층 모드 ID 판별 (본체의 deep 치환과 동일하게 테이블을 바꿔 판정)
$savedNamePatterns = $dgNamePatterns
$dgNamePatterns = $ddNamePatterns
Assert-Case 'ID(심층): 마스 오독(파스, 실기 21:52)' ([string](Get-DgDungeonIdFromTitle -TitleText '파스던전')) '마스던전'
Assert-Case 'ID(심층): 파스 + 층구역 제목' ([string](Get-DgDungeonIdFromTitle -TitleText '파스1층2구역')) '마스던전'
Assert-Case 'ID(심층): 페카 涎분 뭉개짐 (01:41 실사고 원문)' ([string](Get-DgDungeonIdFromTitle -TitleText '표119涎분긬증2증3구역')) '페카고분'
$dgNamePatterns = $savedNamePatterns

# ── '우연한 만남' 토글 라벨 앵커 (2026-08-13 19:15 실사고 - 고정점 폐기, 자기앵커) ──
# 실측: 1272 '만남'(1137,416)→토글(1180,416) / 네이티브1908 '만남'(1095,441)→토글(1136,443)
$anchorMannam = Select-DgChanceToggleAnchor -Words @(@{ Text = '우연한'; X = 1095; Y = 441 }, @{ Text = '만남'; X = 1137; Y = 416 })
Assert-Case '토글 앵커: 만남 1순위 +(42,1)' ('{0},{1}' -f $anchorMannam.X, $anchorMannam.Y) '1179,417'
$anchorUyeon = Select-DgChanceToggleAnchor -Words @(@{ Text = '우연한'; X = 1095; Y = 441 })
Assert-Case '토글 앵커: 만남 없으면 우연한 2순위 +(82,2)' ('{0},{1}' -f $anchorUyeon.X, $anchorUyeon.Y) '1177,443'
# 합쳐진 단어 3순위 (키아던전_옵션1층 실측 - 중심 (1112,416)→토글 (1180,416), 오프셋 64)
$anchorMerged = Select-DgChanceToggleAnchor -Words @(@{ Text = '우연한만남'; X = 1112; Y = 416 })
Assert-Case '토글 앵커: 합쳐진 단어(우연한만남) 3순위 +(64,1)' ('{0},{1}' -f $anchorMerged.X, $anchorMerged.Y) '1176,417'
Assert-Case '토글 앵커: 분리 단어가 있으면 만남 우선 (합침보다 정밀)' `
  ('{0}' -f ([string](Select-DgChanceToggleAnchor -Words @(@{ Text = '우연한만남'; X = 1112; Y = 416 }, @{ Text = '만남'; X = 1137; Y = 416 })).X)) '1179'
Assert-Case '토글 앵커: 단어 없음 = null (호출부 fail-closed)' `
  ($null -eq (Select-DgChanceToggleAnchor -Words @())) $true
Assert-Case '토글 앵커: 오독 합침(후연한만남)은 미등록 - 다른 배율이 구제 (s2 실측)' `
  ($null -eq (Select-DgChanceToggleAnchor -Words @(@{ Text = '후연한만남'; X = 1113; Y = 415 }))) $true

# ── 1b. 선택 화면 제목 판정 (2026-07-25 실기: '페카 고분' 제목에 '던전'이 없어
#        시작 전 정리가 선택 화면을 알 수 없는 화면으로 오인 - 고분·광구·ID 매칭 추가) ──
$selTitleCases = @(
  @{ N = '일반 던전 선택';        T = '글라스기브넨던전'; E = $true }
  @{ N = '피오드 계열(오드)';     T = '바리오드';         E = $true }
  @{ N = '페카 고분 (사고 재현)'; T = '페카 고분';        E = $true }
  @{ N = '페론 고분';             T = '페론고분';         E = $true }
  @{ N = '바리 1광구';            T = '바리 1광구';       E = $true }
  @{ N = '던전 글자 깨짐 + ID 매칭'; T = '키아';          E = $true }
  @{ N = '룬다 오독(눛나) 던전 조각'; T = '눛나던전';     E = $true }
  @{ N = '옵션 화면은 선택 아님'; T = '1층3구역';         E = $false }
  @{ N = '오드 포함 옵션도 선택 아님'; T = '피오드1층1구역'; E = $false }
  @{ N = '구역 깨진 옵션도 층으로 제외 (리뷰 지적)'; T = '페카고분1층3구멱'; E = $false }
  @{ N = '광구 옵션 구역 깨짐도 제외'; T = '바리1광구2층3구멱'; E = $false }
  @{ N = '필드 오독';             T = '.크협크집';        E = $false }
  @{ N = '빈 제목';               T = '';                 E = $false }
  # 2026-07-28 21:58 실기: 심층 전용 던전은 던전 모드 이름 테이블에 없어 미인식 →
  # 탭 자동 전환 게이트 도달 불가 → 심층 이름 조각을 모드 무관 인정
  @{ N = '심층 전용: 북쪽 폐허';   T = '북쪽폐허';         E = $true }
  @{ N = '심층 전용: 북쪽 오독(폐하, 실기)'; T = '북쪽폐하'; E = $true }
  @{ N = '심층 전용: 남쪽 폐허';   T = '남쪽폐허';         E = $true }
  @{ N = '심층 옵션 제목은 여전히 선택 아님'; T = '북쪽폐하심층2층3구역'; E = $false }
  @{ N = '실다 옵션 제목도 선택 아님 (08-12 실측 문자열)'; T = '실다2층3구역'; E = $false }
  # 08-13 00:51 실사고 문서화: 구역이 통째로 죽은 옵션 제목은 '고분' 조각 때문에 선택
  # 화면으로 **오판된다** - 이게 참이라서 시작 판정의 진입 버튼('입장하기') probe 무효화가
  # 필요하다 (워커 $optionsByProbe). 이 단언이 거짓이 되면 그 무효화의 근거가 사라진 것.
  @{ N = '죽은 옵션 제목(메카고분0°°==)은 선택으로 오판됨 (probe 무효화 근거)'; T = '메카고분0°°=='; E = $true }
)
foreach ($case in $selTitleCases) {
  Assert-Case "선택제목: $($case.N)" (Test-DgSelectionTitle -TitleText $case.T) $case.E
}

# ── 1c. 2026-08-12 실사고의 ID→배치→예비 좌표 연결 계약 (실측 진리표) ─────────
# 사슬: '실다2층3구역' 오독으로 ID 불명 → 배치표 차단 → 라벨 탐색 전멸(s4/6/8) →
# fail-closed 정지. '실다' 등록으로 ID=룬다가 서면 아래 연결이 좌표까지 이어져야 한다.
# 기대값은 소스 사본이 아니라 **캡처 실측**이다: 오류 캡처 s10 재생에서 2-2 라벨 중심
# (875,239) - 예비 좌표 (874,238)와 일치 확인. 배치·좌표를 바꾸면 이 실측과 어긋난다.
Assert-Case '연결: 룬다 2층 배치 = CR (실측 배치표)' ([string]$dgLayoutTable['룬다'][1]) 'CR'
$crFallback = Get-DgOptStageFallbackPoint -Stage '2-2' -LayoutType 'CR'
Assert-Case '연결: CR 2-2 예비 좌표 = 874,238 (08-12 캡처 s10 실측 875,239와 일치)' `
  ('{0},{1}' -f $crFallback.X, $crFallback.Y) '874,238'

# ── 1d. 옵션 라벨 탐색 배율 배선 (2026-08-12 - s4/6/8 전멸 프레임 실측으로 s10 추가) ──
# s10은 일반 던전 한정: 심층은 라벨 발견 시 카드 픽셀 검증을 생략하는 계약이라 오탐이
# 곧 오클릭 - 픽셀 게이트 없는 경로는 실측 없이 넓히지 않는다 (교차 리뷰 합의).
$cardCode = ((([string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-DgOptStageCardPoint'))) `
    -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 옵션 라벨 탐색 기본 배율 4·6·8' ($cardCode -match '\$labelScales = @\(4, 6, 8\)') $true
Assert-Case '배선: s10은 일반 던전 한정 (심층 제외 - 픽셀 게이트 없음)' `
  ($cardCode -match 'if \(-not \$deepMode\) \{ \$labelScales \+= 10 \}') $true

# ── 2. 던전·층 → 유형 매핑 (40장 3중 교차 검증 결과 그대로) ─────────────────
$layoutCases = @(
  @{ D = '룬다';      F = @('A', 'CR') }
  @{ D = '피오드';    F = @('B', 'A') }
  @{ D = '페카고분';  F = @('B', 'A') }
  @{ D = '페론고분';  F = @('CR', 'A') }
  @{ D = '바리1광구'; F = @('A', 'B') }
  @{ D = '바리2광구'; F = @('B', 'A') }
  @{ D = '마스던전';  F = @('B', 'CN') }
  @{ D = '라비던전';  F = @('A', 'A') }
  @{ D = '알비던전';  F = @('A', 'B') }
  @{ D = '키아던전';  F = @('CR', 'A') }
)
Assert-Case '매핑 던전 수' $dgLayoutTable.Keys.Count 10
foreach ($case in $layoutCases) {
  Assert-Case "매핑 $($case.D) 1층" ($dgLayoutTable[$case.D][0]) $case.F[0]
  Assert-Case "매핑 $($case.D) 2층" ($dgLayoutTable[$case.D][1]) $case.F[1]
}

# ── 3. 선택 화면 템플릿 + 포커스 밀림 (1층 포커스 기준, 2층 포커스 = -29) ────
Assert-Case '포커스 밀림 상수' $dgFocusShiftY 29
$selCases = @(
  @{ N = 'A형 1-1 (1층 포커스)';  T = 'A';  S = '1-1'; F = 1; X = 206; Y = 425 }
  @{ N = 'A형 1-1 (2층 포커스)';  T = 'A';  S = '1-1'; F = 2; X = 206; Y = 396 }
  @{ N = 'A형 2-2 (사고 라벨 위치)'; T = 'A'; S = '2-2'; F = 1; X = 293; Y = 668 }
  @{ N = 'B형 1-2';               T = 'B';  S = '1-2'; F = 1; X = 293; Y = 338 }
  @{ N = 'CR형 1-2 = 위 카드';    T = 'CR'; S = '1-2'; F = 1; X = 249; Y = 337 }
  @{ N = 'CR형 1-1 = 아래 카드';  T = 'CR'; S = '1-1'; F = 1; X = 249; Y = 425 }
  @{ N = 'CN형 2-1 = 위 카드 (마스)'; T = 'CN'; S = '2-1'; F = 1; X = 249; Y = 580 }
  @{ N = 'CN형 2-2 = 아래 카드 (2층 포커스)'; T = 'CN'; S = '2-2'; F = 2; X = 249; Y = 638 }
  @{ N = 'CR형 2-3 대카드';       T = 'CR'; S = '2-3'; F = 1; X = 353; Y = 637 }
)
foreach ($case in $selCases) {
  $point = Get-DgSelStagePoint -LayoutType $case.T -Stage $case.S -FocusFloor $case.F
  Assert-Case "$($case.N): X" $point[0] $case.X
  Assert-Case "$($case.N): Y" $point[1] $case.Y
}
Assert-Case '선택: 유형 없음 = 좌표 없음' ($null -eq (Get-DgSelStagePoint -LayoutType '' -Stage '1-1' -FocusFloor 1)) $true
Assert-Case '선택: 모르는 구역 = 좌표 없음' ($null -eq (Get-DgSelStagePoint -LayoutType 'A' -Stage '3-1' -FocusFloor 1)) $true

# ── 4. 카드 색 판별식 (40장 픽셀 실측: 포커스 카드 300/300 + 딤 카드 300/300 통과,
#       빈 공간·패널 배경 오탐 0/120 - 비포커스 패널 딤 카드까지 포함해 보정) ─────
$colorCases = @(
  @{ N = '카드 남색 평균';        R = 57;  G = 62;  B = 111; E = $true }
  @{ N = '카드 남색 최저 경계';   R = 42;  G = 39;  B = 69;  E = $true }
  @{ N = '선택 카드 밝은 내부';   R = 85;  G = 93;  B = 147; E = $true }
  @{ N = '비포커스 딤 카드 최저 (룬다 2-1)'; R = 30; G = 30; B = 52; E = $true }
  @{ N = '비포커스 딤 대카드 (피오드 2-3)';  R = 34; G = 35; B = 56; E = $true }
  @{ N = '어두운 배경(장면)';     R = 29;  G = 29;  B = 33;  E = $false }
  @{ N = '밝은 회색(장면)';       R = 147; G = 147; B = 147; E = $false }
  @{ N = '보라 포커스 패널 배경'; R = 39;  G = 11;  B = 87;  E = $false }
  @{ N = '보라 패널 배경 밝은 쪽 (알비)'; R = 54; G = 6; B = 128; E = $false }
  @{ N = '금색 선택 브래킷';      R = 239; G = 174; B = 66;  E = $false }
  @{ N = '완전 검정';             R = 0;   G = 0;   B = 0;   E = $false }
)
foreach ($case in $colorCases) {
  Assert-Case "색: $($case.N)" (Test-DgCardColor -R $case.R -G $case.G -B $case.B) $case.E
}

# ── 4b. 난이도 알약 단어 선택 (오채택 방지 - 좌표는 옵션/선택 화면 실측값) ────
$pillOpt3 = @(
  @{ Text = '일반'; X = 652; Y = 120 }, @{ Text = '어려움'; X = 724; Y = 120 },
  @{ Text = '매우'; X = 796; Y = 120 }, @{ Text = '어려움'; X = 841; Y = 120 }
)
$pillBrokenSolo = @(
  @{ Text = '일반'; X = 652; Y = 120 },
  @{ Text = '매우'; X = 796; Y = 120 }, @{ Text = '어려움'; X = 841; Y = 120 }
)
$pillTwoTier = @(@{ Text = '일반'; X = 652; Y = 120 }, @{ Text = '어려움'; X = 724; Y = 120 })
$pillSel3 = @(
  @{ Text = '일반'; X = 69; Y = 186 }, @{ Text = '어려움'; X = 140; Y = 186 },
  @{ Text = '매우'; X = 206; Y = 186 }, @{ Text = '어려움'; X = 252; Y = 186 }
)
$w = Select-DgDifficultyWord -Words $pillOpt3 -Key '어려움'
Assert-Case '알약: 3단계에서 어려움 = 단독 알약' "$($w.X)" '724'
$w = Select-DgDifficultyWord -Words $pillOpt3 -Key '매우어려움'
Assert-Case "알약: 매우어려움 = '매우' 단어" "$($w.X)" '796'
$w = Select-DgDifficultyWord -Words $pillOpt3 -Key '일반'
Assert-Case '알약: 일반 정확 일치' "$($w.X)" '652'
Assert-Case '알약: 단독 어려움 깨짐 → 매우 뒷단어 오채택 금지' `
  ($null -eq (Select-DgDifficultyWord -Words $pillBrokenSolo -Key '어려움')) $true
Assert-Case '알약: 2단계 던전에서 매우어려움 없음' `
  ($null -eq (Select-DgDifficultyWord -Words $pillTwoTier -Key '매우어려움')) $true
$w = Select-DgDifficultyWord -Words $pillSel3 -Key '어려움'
Assert-Case '알약: 선택 화면 3단계에서 어려움 = 단독 알약' "$($w.X)" '140'
# 기준 토큰(앵커) 규칙: '일반'/'매우'가 하나도 안 읽히면 '어려움' 단독 채택 금지 (리뷰 2차 리뷰)
Assert-Case '알약: 일반+뒷단어만 읽힘 → 앵커 범위 밖이라 채택 금지' `
  ($null -eq (Select-DgDifficultyWord -Words @(@{ Text = '일반'; X = 652; Y = 120 }, @{ Text = '어려움'; X = 841; Y = 120 }) -Key '어려움')) $true
Assert-Case '알약: 어려움 한 단어만 읽힘 → 앵커 없어 채택 금지' `
  ($null -eq (Select-DgDifficultyWord -Words @(@{ Text = '어려움'; X = 724; Y = 120 }) -Key '어려움')) $true
$w = Select-DgDifficultyWord -Words @(@{ Text = '매우'; X = 796; Y = 120 }, @{ Text = '어려움'; X = 724; Y = 120 }) -Key '어려움'
Assert-Case '알약: 매우가 보이고 짝이 아니면 단독 알약으로 채택' "$($w.X)" '724'
# 표준 위치(HardX) 검증 - 어려움 선택 상태에서 '일반'이 흐릿해 안 읽히는 실사고 대응 (2026-07-25)
$w = Select-DgDifficultyWord -Words @(@{ Text = '어려움'; X = 724; Y = 120 }) -Key '어려움' -HardX 724
Assert-Case '알약: 앵커 없어도 표준 자리(옵션 724)면 채택 (피오드 실사고)' "$($w.X)" '724'
Assert-Case '알약: 표준 자리 밖(매우 뒷단어 841)은 HardX 로도 채택 금지' `
  ($null -eq (Select-DgDifficultyWord -Words @(@{ Text = '어려움'; X = 841; Y = 120 }) -Key '어려움' -HardX 724)) $true
$w = Select-DgDifficultyWord -Words @(@{ Text = '어려움'; X = 140; Y = 186 }) -Key '어려움' -HardX 140
Assert-Case '알약: 선택 화면 표준 자리(140)도 동일 규칙' "$($w.X)" '140'
Assert-Case '알약: HardX 있어도 매우 짝 제외가 우선' `
  ($null -eq (Select-DgDifficultyWord -Words @(@{ Text = '매우'; X = 700; Y = 120 }, @{ Text = '어려움'; X = 745; Y = 120 }) -Key '어려움' -HardX 724)) $true
# 깨짐 이형 '이려움' (2026-07-29 20:02 키아 심층 실기: 매우 어려움 미해금이라 알약 1개+앵커
# 없음 화면에서 스케일 3 OCR이 '이려움'으로 깨져 3회 전부 탈락 → 이형 허용, 가드는 동일 적용)
$w = Select-DgDifficultyWord -Words @(@{ Text = '이려움'; X = 662; Y = 120 }) -Key '어려움' -HardX 660
Assert-Case '알약: 이려움 깨짐도 표준 자리(심층 옵션 660)면 채택 (키아 실사고)' "$($w.X)" '662'
Assert-Case '알약: 이려움이 매우 짝이면 여전히 제외' `
  ($null -eq (Select-DgDifficultyWord -Words @(@{ Text = '매우'; X = 700; Y = 120 }, @{ Text = '이려움'; X = 745; Y = 120 }) -Key '어려움' -HardX 724)) $true
Assert-Case '알약: 이려움도 표준 자리 밖이면 채택 금지' `
  ($null -eq (Select-DgDifficultyWord -Words @(@{ Text = '이려움'; X = 841; Y = 120 }) -Key '어려움' -HardX 660)) $true
Assert-Case '알약: 이려움 이형은 어려움 Key 전용 (일반 Key 에는 불인정)' `
  ($null -eq (Select-DgDifficultyWord -Words @(@{ Text = '이려움'; X = 652; Y = 120 }) -Key '일반')) $true
# 스케일별 추가 이형 (2026-07-29 20:17 페카 실기 - s4 '이컪움'/s5 '이컪울', 선택 화면 실측)
$w = Select-DgDifficultyWord -Words @(@{ Text = '이컪움'; X = 77; Y = 186 }) -Key '어려움' -HardX 78
Assert-Case '알약: 이컪움(s4) 깨짐도 표준 자리(심층 선택 78)면 채택 (페카 실사고)' "$($w.X)" '77'
$w = Select-DgDifficultyWord -Words @(@{ Text = '이컪울'; X = 77; Y = 186 }) -Key '어려움' -HardX 78
Assert-Case '알약: 이컪울(s5) 깨짐도 표준 자리면 채택' "$($w.X)" '77'
Assert-Case '알약: 이컪움도 표준 자리 밖이면 채택 금지' `
  ($null -eq (Select-DgDifficultyWord -Words @(@{ Text = '이컪움'; X = 841; Y = 120 }) -Key '어려움' -HardX 660)) $true
# 다중 스케일 배선: Find-DgDifficultyPoint 가 4→3→5 순서 + '어려움' 한정 s2 최종 폴백
# (2026-08-03 08:50 실사고: 1908 창 실효 배율 저하로 s4/s3/s5 전멸 - s2만 정상 판독.
#  s2는 위치 게이트가 있는 '어려움' 키에만 추가 - 보수 조건)
$workerSource = [IO.File]::ReadAllText($workerPath)
Assert-Case '배선: 알약 탐색 다중 스케일(4,3,5) 사다리' `
  ($workerSource -match '\$pillScales = @\(4, 3, 5\)') $true
Assert-Case '배선: 어려움 키 한정 s2 최종 폴백 (1908 실사고)' `
  ($workerSource -match "if \(\`$key -eq '어려움'\) \{ \`$pillScales \+= 2 \}") $true
Assert-Case '배선: 사다리 변수로 재시도 순회' `
  ($workerSource -match 'foreach \(\$pillScale in \$pillScales\)') $true

# ── 4c. 옵션 제목 보조 판정 (피오듸층3구역 실사고 재현) ──────────────────────
Assert-Case '보조: 사고 원문 제목 + 1층 라벨 2개' `
  ([string](Resolve-DgObservedStage -MapTexts @('1-1', '1-2', '1-3') -TitleText '피오듸층3구역')) '1-3'
Assert-Case '보조: 라벨 1개뿐이면 층 확정 금지' `
  ($null -eq (Resolve-DgObservedStage -MapTexts @('2-3') -TitleText '2층3구역')) $true
Assert-Case '보조: 같은 라벨 두 배율 합의는 인정' `
  ([string](Resolve-DgObservedStage -MapTexts @('2-3', '2-3') -TitleText '피오드2층3구역')) '2-3'
Assert-Case '보조: 층 혼재는 불명' `
  ($null -eq (Resolve-DgObservedStage -MapTexts @('1-1', '2-3') -TitleText '1층3구역')) $true
Assert-Case '보조: 제목에 구역 숫자 없으면 불명' `
  ($null -eq (Resolve-DgObservedStage -MapTexts @('1-1', '1-2') -TitleText '피오드')) $true
Assert-Case '보조: 공물 숫자가 붙어도 마지막 구역 숫자 사용' `
  ([string](Resolve-DgObservedStage -MapTexts @('1-2', '1-1') -TitleText '11층3구역')) '1-3'

# ── 4d. 본체 소스 계약 확인 ──────────────────────────────────────────────────
$workerSource = Get-Content -LiteralPath $workerPath -Raw -Encoding UTF8
Assert-Case "2단계 던전의 '매우 어려움' 시작 차단 존재" `
  ($workerSource.Contains("난이도가 없습니다")) $true
Assert-Case '난이도 클릭 3개 사이트 모두 단어 판정 사용' `
  ([regex]::Matches($workerSource, 'Find-DgDifficultyPoint -Game').Count -ge 3) $true
Assert-Case '커스텀 시작 분기도 제목 불명확 시 보조 판정 사용 (피오듸층 실기 재발 방지)' `
  ($workerSource -match "elseif \(\`$titleMatch -eq 'unclear'\)[\s\S]{0,900}Get-DgOptObservedStage") $true
Assert-Case '미등록 세로형도 대카드(구역 3)는 진행 (페론 실기 과잉 정지 방지)' `
  ($workerSource.Contains('순서 무관 위치라 진행')) $true

# ── 5. 선택↔옵션 템플릿 정합성: 유형·구역 키 완비 ───────────────────────────
foreach ($layoutKey in @('A', 'B', 'CR', 'CN')) {
  Assert-Case "선택 템플릿 $layoutKey 구역 수" $dgSelStagePoints[$layoutKey].Keys.Count 6
  Assert-Case "옵션 템플릿 $layoutKey 구역 수" $dgOptStagePoints[$layoutKey].Keys.Count 3
}
# 매핑이 가리키는 유형이 템플릿에 모두 존재해야 합니다
$missingTypes = 0
foreach ($dungeonKey in $dgLayoutTable.Keys) {
  foreach ($layoutType in $dgLayoutTable[$dungeonKey]) {
    if (-not $dgSelStagePoints.ContainsKey($layoutType)) { $missingTypes++ }
    if (-not $dgOptStagePoints.ContainsKey($layoutType)) { $missingTypes++ }
  }
}
Assert-Case '매핑 유형이 템플릿에 전부 존재' $missingTypes 0

exit $fails
