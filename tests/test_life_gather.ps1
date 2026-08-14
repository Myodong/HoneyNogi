# 생활(채집) 워커 판정 진리표 + 사이클 시뮬레이션 + 배선 가드 (v2.0.0 - 2026-08-05)
# 실측 근거: 던전이미지\생활\흐름캡처 9장 오프라인 OCR 재현(전체 통과)에서 얻은
# 실제 판독 문자열을 진리표 입력으로 사용합니다 (깨짐 사례 포함).
$fails = 0

$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── 본체에서 순수 판정 함수/데이터 추출 ──
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath `
    -Names @('Get-LifeNormalizedName', 'Test-LifeNameMatches', 'Get-LifeRepairedTexts', 'Get-LifeQuestOwner', 'Test-LifeBodyNameAmbiguous', 'Get-LifeDetailVerdict', 'Get-LifeDetailTitleFromWords', 'Get-LifeDetailLabelIndex', 'Test-LifeDetailHasLabel', 'Get-LifeTitleFromDetailText', 'Get-LifeTitleVerdictFromDetail', 'Get-LifeConsensusVerdict', 'Get-LifeProgressValue', 'Get-LifeQuestGoalValue', 'Get-LifeQuestGoalConsensus', 'Get-LifeTitleStripRegion', 'Test-LifeTitleNameMatches', 'Get-LifeTitleVerdict', 'Get-LifeRequiredLevel', 'Test-CaptureRecovered', 'Format-LifeMissingItemNotice', 'Select-LifeFindNearestWord', 'Test-LifeQuestFragments', 'Get-LifeQuestConceptHits', 'Get-LifeQuestOwnerText', 'Get-LifeQuestState', 'Get-LifeQuestCountText', 'Get-LifeTargetRows', 'Get-LifeTargetRowByOrder', 'Find-LifeTargetScan', 'Test-LifeListAtTop', 'Test-LifeTitleExplicitVariant', 'Test-LifeWindowClosePixels')) {
  Invoke-Expression $definition
}
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$config = $null
$sourceAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$null)
foreach ($varName in @('lifeSkillMenuTable', 'lifeTargetVariants', 'lifeTitleVariants', 'lifeNameRepairPairs', 'lifeDetailLabelFragments', 'lifeDetailLabelMaxIndex', 'lifeDetailDescSignatures', 'rgLifeStats', 'rgLifeTargetList', 'rgLifeDetail', 'rgLifeQuestTracker', 'rgLifeQuestWide', 'lifeListRowGap', 'lifeListFirstRowY')) {
  $assign = $sourceAst.Find({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      ($node.Left.Extent.Text -eq ('$' + $varName))
    }, $true)
  if (-not $assign) { "FAIL 본체에서 `$$varName 정의를 찾지 못했습니다"; $fails++; continue }
  Invoke-Expression $assign.Extent.Text
}
$ocrKoreanEngine = $null

# ── ① 대상 이름 매칭 진리표 (공백 제거 정확 일치 + 실측 이형) ──
Assert-Case '이름: 정확 일치' (Test-LifeNameMatches -RowText '사과나무' -TargetName '사과나무') 'True'
Assert-Case '이름: 공백 정규화 (설정 쪽 공백)' (Test-LifeNameMatches -RowText '사과나무' -TargetName '사과 나무') 'True'
Assert-Case '이름: 실측 이형 읽힌거미줄→얽힌 거미줄' (Test-LifeNameMatches -RowText '읽힌거미줄' -TargetName '얽힌 거미줄') 'True'
Assert-Case '이름: 실측 이형 읽힌거미좋 (s5)' (Test-LifeNameMatches -RowText '읽힌거미좋' -TargetName '얽힌거미줄') 'True'
Assert-Case '이름: 실측 이형 ÅI과나무 (s3)' (Test-LifeNameMatches -RowText 'ÅI과나무' -TargetName '사과나무') 'True'
Assert-Case '이름: 다른 대상 거부' (Test-LifeNameMatches -RowText '차나무' -TargetName '사과나무') 'False'
Assert-Case '이름: 부분 일치 거부 (정확 일치 요구)' (Test-LifeNameMatches -RowText '사과나무숲' -TargetName '사과나무') 'False'
Assert-Case '이름: 빈 행 거부' (Test-LifeNameMatches -RowText '' -TargetName '사과나무') 'False'

# ── ①a 퀘스트 트래커 소유 판정 (2026-08-07 감사) ──
# 단순 부분 문자열 비교는 형제 대상을 자기 것으로 인수합니다. 실제 피해가 양방향이라 위험합니다:
#  '우물' 퀘스트를 목표 '물' 이 인수 → 빈 사이클을 완료로 계상
#  자기 퀘스트를 못 알아보면 → 3분 대기 후 exit 4 로 무인 반복 전체 정지
$dailyOrderQ = @('둥지', '거미줄', '물', '우물', '젖소', '사과 나무', '차나무', '거미줄 뭉치', '헤이즐넛', '얽힌 거미줄')
$woodOrderQ = @('나무', '뾰족 나무', '굵은 나무', '쓸 만한 나무', '갑옷 나무', '어스름 나무', '벼락 나무', '흰 껍질 나무')
$insectOrderQ = @('빛 무리', '설원 빛 무리', '곤충 무리', '고요한 빛 무리', '따스한 빛 무리', '차가운 빛 무리', '삭막한 곤충 무리', '황폐한 곤충 무리', '일렁이는 빛 무리')
Assert-Case '소유: 우물 퀘스트는 우물 (목표 물이 가로채면 안 됨)' `
  (Get-LifeQuestOwner -QuestText '채집 장소 탐색 우물 채집 0/1' -Order $dailyOrderQ) '우물'
Assert-Case '소유: 물 퀘스트는 물' (Get-LifeQuestOwner -QuestText '채집 장소 탐색 물 채집 0/1' -Order $dailyOrderQ) '물'
Assert-Case '소유: 얽힌 거미줄은 거미줄이 아님 (긴 이름 우선)' `
  (Get-LifeQuestOwner -QuestText '채집 장소 탐색 얽힌 거미줄 채집 2/10' -Order $dailyOrderQ) '얽힌 거미줄'
Assert-Case '소유: 거미줄 뭉치도 거미줄이 아님' `
  (Get-LifeQuestOwner -QuestText '채집 장소 탐색 거미줄 뭉치 채집 2/10' -Order $dailyOrderQ) '거미줄 뭉치'
Assert-Case '소유: 뾰족 나무는 나무가 아님' `
  (Get-LifeQuestOwner -QuestText '채집 장소 탐색 뾰족 나무 채집 1/10' -Order $woodOrderQ) '뾰족 나무'
Assert-Case '소유: 깨진 이름도 공통 치환으로 인식 (빛부리 → 빛 무리)' `
  (Get-LifeQuestOwner -QuestText '채집 장소 탐색 빛부리 채집 4/10' -Order $insectOrderQ) '빛 무리'
Assert-Case '소유: 복합 깨짐 (황폐한곤춤부리)' `
  (Get-LifeQuestOwner -QuestText '채집 장소 탐색 황폐한곤춤부리 채집 4/10' -Order $insectOrderQ) '황폐한 곤충 무리'
Assert-Case '소유: 등록된 이형 (등지 → 둥지)' `
  (Get-LifeQuestOwner -QuestText '채집 장소 탐색 등지 채집 0/10' -Order $dailyOrderQ) '둥지'
Assert-Case '소유: 이름이 통째로 깨지면 미확정 (빈 문자열)' `
  (Get-LifeQuestOwner -QuestText '채집 장소 탐색 丁亞 채집 0/10' -Order $dailyOrderQ) ''
Assert-Case '소유: 빈 판독은 미확정' (Get-LifeQuestOwner -QuestText '' -Order $dailyOrderQ) ''
Assert-Case '치환사본: 원문 + 규칙별 + 전부적용' `
  ((Get-LifeRepairedTexts -Text '황폐한곤춤부리') -join '|') '황폐한곤춤부리|황폐한곤춤무리|황폐한곤충부리|황폐한곤충무리'

# ── ①b 상세 팝업 판정 진리표 (2차 실기 22:51 실측: '채집물' → '자|집물' 깨짐) ──
Assert-Case '상세: 시연 정상 판독 → match' (Get-LifeDetailVerdict -DetailText '사과나무채집물일상채집레벨1이상달콤한' -TargetName '사과 나무') 'match'
Assert-Case "상세: 실기 깨짐 '자|집물' → match (잔여 2자 흡수)" (Get-LifeDetailVerdict -DetailText '사과나무자|집물일상채집레벨1이상' -TargetName '사과나무') 'match'
Assert-Case "상세: 깨짐 '재집물' → match (잔여 1자 흡수)" (Get-LifeDetailVerdict -DetailText '사과나무재집물일상재집' -TargetName '사과나무') 'match'
Assert-Case '상세: 다른 대상 팝업 → wrong-target' (Get-LifeDetailVerdict -DetailText '차나무채집물일상채집레벨10이상' -TargetName '사과나무') 'wrong-target'
Assert-Case '상세: 긴 이름 다른 대상은 접두로 오인 금지 (2자 제한)' (Get-LifeDetailVerdict -DetailText '거미줄뭉치채집물일상채집' -TargetName '거미줄') 'wrong-target'
# 목록 대조 판정 (2026-08-06 라운드 3: '화살꽃'→'호b살꽃' 이 한글비율 0.8 경계에 걸려
# 오클릭 오판 → 목록에 실제로 있는 다른 대상과 일치할 때만 wrong-target)
$herbOrder = @('허브', '블러디 허브', '화살꽃', '마나 허브', '새록 버섯')
Assert-Case "상세: 깨진 제목 '호b살꽃' + 목록 대조 → match (이형 등록분)" `
  (Get-LifeDetailVerdict -DetailText '호b살꽃채집물약초채집레벨1이상화살것모양의노란꽃.' -TargetName '화살꽃' -Order $herbOrder) 'match'
# 리뷰 블로커 반례: 라벨 '집물' 때문에 1글자 대상 '물'이 모든 팝업과 일치하던 사고
$dailyOrder = @('둥지', '거미줄', '물', '우물', '젖소', '사과 나무', '차나무', '거미줄 뭉치', '헤이즐넛', '얽힌 거미줄')
Assert-Case "상세: 목표 '물' + 젖소 팝업 → wrong-target (본문 구제 오작동 방지)" `
  (Get-LifeDetailVerdict -DetailText '젖소채집물일상채집레벨1이상얼룩덜룩한무늬가특징인젖소.' -TargetName '물' -Order $dailyOrder) 'wrong-target'
Assert-Case "상세: 목표 '물' + 우물 팝업 → wrong-target" `
  (Get-LifeDetailVerdict -DetailText '우물채집물일상채집레벨1이상깨끗한지하수를모아둔곳.' -TargetName '물' -Order $dailyOrder) 'wrong-target'
Assert-Case "상세: 목표 '거미줄' + 거미줄 뭉치 팝업 → wrong-target (접두 축소 오인 방지)" `
  (Get-LifeDetailVerdict -DetailText '거미줄뭉치채집물일상채집레벨1이상' -TargetName '거미줄' -Order $dailyOrder) 'wrong-target'
Assert-Case "상세: 목표 '물' + 물 팝업 → match" `
  (Get-LifeDetailVerdict -DetailText '물채집물일상채집레벨1이상깨끗한물.' -TargetName '물' -Order $dailyOrder) 'match'
# ②.5 설명문 시그니처 (2026-08-14 네이티브 1908 실사고 - 물 3회전 소진): 제목이 통째로
# 소실된 물 팝업을 설명문 고유 조각('마실수있는맑은물')으로 확정한다. 실측 판독 원문 그대로.
Assert-Case "상세: 실측 제목 소실 물 팝업 → match (설명문 시그니처)" `
  (Get-LifeDetailVerdict -DetailText '0채집물일상채집레벨1이상마실수있는맑은물.빈병으로물을뜰수있다.가까운위치찾기0' -TargetName '물' -Order $dailyOrder) 'match'
# 오탐 가드: '빈병으로물을뜰수있다'는 우물 실측 설명에도 있어 시그니처로 등록하면 안 된다.
# 등록 조각을 그쪽으로 바꾸면 이 케이스가 잡는다 (우물 팝업이 목표 '물'에 match 가 됨).
Assert-Case "상세: 제목 깨진 우물 팝업 + 목표 '물' → unreadable (빈병 조각 미등록 가드)" `
  (Get-LifeDetailVerdict -DetailText '丁亞치|집물일상채집레벨1이상깨끗한지하수를모아둔곳.빈병으로물을뜰수있다.' -TargetName '물' -Order $dailyOrder) 'unreadable'
# ① 우선순위 가드: 또렷한 다른 제목은 시그니처보다 먼저 차단돼야 한다 (합성 문자열 -
# 시그니처 검사가 ① 앞으로 이동하는 변이를 잡기 위한 순서 계약)
Assert-Case "상세: 또렷한 우물 제목 + 본문에 물 시그니처 → wrong-target (① 우선)" `
  (Get-LifeDetailVerdict -DetailText '우물채집물일상채집레벨1이상마실수있는맑은물.' -TargetName '물' -Order $dailyOrder) 'wrong-target'
# 교차 가드: 시그니처는 등록 대상('물')에만 효력 - 물 팝업이 목표 '우물'을 통과시키지 않는다
Assert-Case "상세: 제목 소실 물 팝업 + 목표 '우물' → unreadable (시그니처 교차 오염 없음)" `
  (Get-LifeDetailVerdict -DetailText '0채집물일상채집레벨1이상마실수있는맑은물.빈병으로물을뜰수있다.가까운위치찾기0' -TargetName '우물' -Order $dailyOrder) 'unreadable'
# 우물 시그니처 (2026-08-14 18:26 실사고 - 근거 index + 제목 소실 + 스킬명 '일상치1집' 깨짐
# 으로 3회전 소진). 판독 원문 그대로 - 시그니처('깨끗한지하수를모아둔곳')가 우물을 확정한다.
Assert-Case "상세: 실측 제목 소실 우물 팝업 → match (설명문 시그니처)" `
  (Get-LifeDetailVerdict -DetailText '채집물일상치1집레벨1이상깨끗한지하수를모아둔곳.빈병으로물을뜰수있다.가까운위치찾기' -TargetName '우물' -Order $dailyOrder) 'match'
Assert-Case "상세: 같은 우물 팝업 + 목표 '물' → unreadable (교차 오염 없음)" `
  (Get-LifeDetailVerdict -DetailText '채집물일상치1집레벨1이상깨끗한지하수를모아둔곳.빈병으로물을뜰수있다.가까운위치찾기' -TargetName '물' -Order $dailyOrder) 'unreadable'
Assert-Case "상세: 목표 '거미줄' + 거미줄 팝업 → match" `
  (Get-LifeDetailVerdict -DetailText '거미줄채집물일상채집레벨1이상' -TargetName '거미줄' -Order $dailyOrder) 'match'
Assert-Case '상세: 목록의 다른 대상과 일치 → wrong-target' `
  (Get-LifeDetailVerdict -DetailText '마나허브채집물약초채집레벨1이상' -TargetName '화살꽃' -Order $herbOrder) 'wrong-target'
Assert-Case '상세: 목록 밖 깨짐 제목 → unreadable (확정 보류)' `
  (Get-LifeDetailVerdict -DetailText '샤OO초채집물약초채집' -TargetName '화살꽃' -Order $herbOrder) 'unreadable'
# 제목 깨짐 vs 오클릭 구분 (전수 배치 01:04 실측 - 깨진 제목을 오클릭으로 확정하던 사고)
# 2026-08-14 계약 변화: 아래 문자열은 진짜 우물 팝업 판독이라 시그니처 등록 후 match 가
# 정답이 됐다 (원래 목적 = 깨진 제목을 오클릭으로 '확정'하지 않는 것 - wrong-target 만
# 아니면 지켜짐. unreadable 시절보다 강한 판정)
Assert-Case "상세: 실기 깨짐 '丁亞'(한글 0자) → match (시그니처, 오클릭 확정 아님)" `
  (Get-LifeDetailVerdict -DetailText '丁亞치|집물일상채집레벨1이상깨끗한지하수를모아둔곳.빈병으로물을뜰수있다.' -TargetName '우물') 'match'
Assert-Case "상세: 실기 깨짐 'C0자' 이지만 본문에 '젖소' → match (본문 구제)" `
  (Get-LifeDetailVerdict -DetailText 'C0자|집물일상새집레벨1이상얼룩덜룩한무늬)특징인젖소.빈병으로신선한우유를' -TargetName '젖소') 'match'
Assert-Case '상세: 한 글자 제목 → unreadable (오클릭 확정 보류)' (Get-LifeDetailVerdict -DetailText '亞집물일상채집' -TargetName '우물') 'unreadable'
Assert-Case '상세: 또렷한 한글 제목 + 본문 무관 → wrong-target 유지' `
  (Get-LifeDetailVerdict -DetailText '얼음채집물광석캐기레벨1이상차가운얼음덩어리.' -TargetName '석탄 광맥') 'wrong-target'
Assert-Case '상세: 긴 이름 + 깨짐도 자기 대상은 match' (Get-LifeDetailVerdict -DetailText '거미줄뭉치자|집물일상채집' -TargetName '거미줄 뭉치') 'match'
Assert-Case "상세: 실기 깨짐 '혼!껍질나무' (흰→혼! + 자| 잔여) → match" (Get-LifeDetailVerdict -DetailText '혼!껍질나무자|집물나무베기레벨32이상' -TargetName '흰 껍질 나무') 'match'
Assert-Case '상세: 라벨 없음(팝업 미표시) → no-label' (Get-LifeDetailVerdict -DetailText '' -TargetName '사과나무') 'no-label'

# ── ①b-1 본문 근거의 모호성 (2026-08-07 감사 high) ──
# 팝업 본문은 '이름 → 채집물 → 스킬명 레벨 N 이상 → 설명' 이라 **항상 스킬 이름**이 들어갑니다.
# 목표가 스킬명의 일부이거나 다른 대상이 목표를 통째로 품으면 본문 포함은 아무것도 증명 못 함.
$woodOrder = @('나무', '뾰족 나무', '굵은 나무', '쓸 만한 나무', '갑옷 나무', '어스름 나무', '벼락 나무', '흰 껍질 나무')
$miningOrder = @('광맥', '철 광맥', '얼음', '석탄 광맥', '동 광맥', '백동 광맥', '은 광맥', '운철 광맥', '백금 광맥')
$insectOrder = @('빛 무리', '설원 빛 무리', '곤충 무리', '고요한 빛 무리', '따스한 빛 무리', '차가운 빛 무리', '삭막한 곤충 무리', '황폐한 곤충 무리', '일렁이는 빛 무리')
Assert-Case "모호성: '나무'는 스킬명 '나무 베기'에 포함 → 모호" `
  (Test-LifeBodyNameAmbiguous -Name '나무' -Order $woodOrder -SkillName '나무 베기') 'True'
Assert-Case "모호성: '광맥'은 다른 대상('철 광맥')이 품음 → 모호" `
  (Test-LifeBodyNameAmbiguous -Name '광맥' -Order $miningOrder -SkillName '광석 캐기') 'True'
Assert-Case "모호성: '빛 무리'는 '설원 빛 무리'가 품음 → 모호" `
  (Test-LifeBodyNameAmbiguous -Name '빛 무리' -Order $insectOrder -SkillName '곤충 채집') 'True'
Assert-Case "모호성: '거미줄'은 '거미줄 뭉치'가 품음 → 모호" `
  (Test-LifeBodyNameAmbiguous -Name '거미줄' -Order $dailyOrder -SkillName '일상 채집') 'True'
Assert-Case "모호성: '젖소'는 누구도 품지 않음 → 본문 근거 사용 가능" `
  (Test-LifeBodyNameAmbiguous -Name '젖소' -Order $dailyOrder -SkillName '일상 채집') 'False'
Assert-Case "모호성: '흰 껍질 나무'는 고유 → 사용 가능" `
  (Test-LifeBodyNameAmbiguous -Name '흰 껍질 나무' -Order $woodOrder -SkillName '나무 베기') 'False'
Assert-Case "모호성: 1글자('물')는 항상 모호" (Test-LifeBodyNameAmbiguous -Name '물' -Order $dailyOrder) 'True'
Assert-Case "모호성: 수식어 '백동'은 다른 대상에 없음 → 사용 가능 (SelfName 로 자기 제외)" `
  (Test-LifeBodyNameAmbiguous -Name '백동' -Order $miningOrder -SkillName '광석 캐기' -SelfName '백동 광맥') 'False'
# 실제 판정에 반영됐는지 (본문에 스킬명이 있어도 '나무'로는 통과하면 안 됨)
Assert-Case "상세: 목표 '나무' + 깨진 제목 + 본문 스킬명 → unreadable (본문 구제 금지)" `
  (Get-LifeDetailVerdict -DetailText '뾰@족나무자|집물나무베기레벨1이상뾰족한가시가있는나무.' -TargetName '나무' `
    -Order $woodOrder -SkillName '나무 베기') 'unreadable'
Assert-Case "상세: 목표 '나무' + 또렷한 다른 대상 제목 → wrong-target" `
  (Get-LifeDetailVerdict -DetailText '뾰족나무채집물나무베기레벨1이상' -TargetName '나무' `
    -Order $woodOrder -SkillName '나무 베기') 'wrong-target'
# 자기 팝업이 2자 깎여 다른 대상으로 확정되던 반례 ('채' 가 사라져 제목이 정확히 '거미줄뭉치')
Assert-Case "상세: '거미줄뭉치' 제목 + 목표 '거미줄 뭉치' → match (깎지 않은 일치 우선)" `
  (Get-LifeDetailVerdict -DetailText '거미줄뭉치집물일상채집레벨1이상' -TargetName '거미줄 뭉치' -Order $dailyOrder) 'match'
Assert-Case '상세: 무관 화면 판독 → no-label' (Get-LifeDetailVerdict -DetailText '양털깎기추수호미질' -TargetName '사과나무') 'no-label'

# ── ①b-2 요구 스킬 레벨 추출 (퀘스트 미생성 원인 안내 - 2026-08-07 곤충 실사고) ──
# 링크를 눌러도 퀘스트가 안 생기는 원인이 화면에만 남던 문제. 상세 팝업의 '레벨 N 이상'을
# 실패 안내에 붙입니다. '이상'은 OCR 이 자주 깨져('이실h1') 숫자까지만 신뢰합니다.
Assert-Case '요구레벨: 실기 판독(일렁이는 빛 무리, 이상 깨짐) → 27' `
  (Get-LifeRequiredLevel -DetailText '일렁이는빛무리자|집물(곤충채집레벨27이실h1창백한산깊은곳에서발견되는곤충무리.') 27
Assert-Case '요구레벨: 정상 판독 → 1' (Get-LifeRequiredLevel -DetailText '감자자|집물호미질레벨1이상채소밭에서쑥쑥자라는작물') 1
Assert-Case '요구레벨: 두 자리 → 32' (Get-LifeRequiredLevel -DetailText '혼!껍질나무자|집물나무베기레벨32이상') 32
Assert-Case '요구레벨: 공백 포함 원문 → 30' (Get-LifeRequiredLevel -DetailText '얽힌 거미줄 채집물 일상 채집 레벨 30 이상') 30
Assert-Case '요구레벨: 레벨 표기 없음 → 0 (안내 생략)' (Get-LifeRequiredLevel -DetailText '거미줄채집물일상채집깨끗한물.') 0
Assert-Case '요구레벨: 빈 문자열 → 0' (Get-LifeRequiredLevel -DetailText '') 0
Assert-Case '요구레벨: 숫자 없는 깨짐 → 0' (Get-LifeRequiredLevel -DetailText '감자자|집물호미질레벨l이상') 0
Assert-Case '요구레벨: 비상식적 값(판독 합성 251) → 0' `
  (Get-LifeRequiredLevel -DetailText '일렁이는빛무리채집물곤충채집레벨2512이상') 0
# 라벨('집물') 뒤에서만 찾습니다 - 라벨이 없으면 상세 팝업이 아니거나 판독이 깨진 것
Assert-Case '요구레벨: 라벨 없음 → 0 (상세 팝업 근거 없음)' (Get-LifeRequiredLevel -DetailText '곤충채집레벨27이상') 0
Assert-Case '요구레벨: 라벨 앞의 숫자는 무시' (Get-LifeRequiredLevel -DetailText '레벨99채집물호미질레벨1이상') 1
Assert-Case '요구레벨: 서로 다른 값 2개 → 0 (확신 불가)' `
  (Get-LifeRequiredLevel -DetailText '감자채집물호미질레벨1이상밭레벨5이상에서자란다') 0
Assert-Case '요구레벨: 같은 값 반복 → 그 값' `
  (Get-LifeRequiredLevel -DetailText '감자채집물호미질레벨1이상호미질레벨1이상') 1
# 긴 숫자의 앞 세 자리만 잘라 읽지 않아야 합니다 (상한 검사만으로는 1000→100 을 못 막음)
Assert-Case '요구레벨: 레벨1000 → 0 (접두부 절단 금지)' (Get-LifeRequiredLevel -DetailText '감자채집물호미질레벨1000이상') 0
Assert-Case '요구레벨: 레벨0999 → 0 (접두부 절단 금지)' (Get-LifeRequiredLevel -DetailText '감자채집물호미질레벨0999이상') 0

# ── ①b-3 캡처 복구 탐침 (2026-08-07 실사고의 근본 원인 - 리뷰 지적) ──
# Get-GameRegionCapture 는 Bitmap 이 아니라 'Bitmap 속성을 가진 래퍼'를 돌려줍니다.
# 래퍼에 Dispose 를 부르면 복구되는 순간에만 예외가 터져 실기에서 늦게 드러납니다.
$script:probeDisposed = $false
$script:probeReturnsNull = $false
function Get-GameRegionCapture {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight,
    [int]$Scale, [switch]$BinaryWhiteText, [switch]$ThrowOnWindowRectFailure)
  if ($script:probeReturnsNull) { return $null }        # 캡처 실패 = null 반환 + 플래그 유지
  $script:screenCaptureFailing = $false                 # 운영 함수의 Register-CaptureSuccess 대응
  $fakeBitmap = New-Object psobject
  $fakeBitmap | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $script:probeDisposed = $true }
  return [pscustomobject]@{ Bitmap = $fakeBitmap; Scale = $Scale }
}
$script:screenCaptureFailing = $true
$probeVerdict = Test-CaptureRecovered -Game $null
Assert-Case '탐침: 캡처 성공 → 복구됨(True)' $probeVerdict 'True'
Assert-Case '탐침: 래퍼의 Bitmap 을 Dispose (래퍼 자체 아님)' $script:probeDisposed 'True'
$script:probeReturnsNull = $true
$script:probeDisposed = $false
$script:screenCaptureFailing = $true
$probeVerdict = Test-CaptureRecovered -Game $null
Assert-Case '탐침: 캡처 실패(null) → 미복구(False), 예외 없음' $probeVerdict 'False'
Assert-Case '탐침: null 이면 Dispose 시도 안 함' $script:probeDisposed 'False'
# GetWindowRect 실패 경로는 $null 만 돌려주고 플래그를 세우지 않습니다 - 플래그만 보면
# '정상'으로 통과해 클릭 직전 게이트가 뚫립니다 (2026-08-07 리뷰 지적)
$script:screenCaptureFailing = $false
$probeVerdict = Test-CaptureRecovered -Game $null
Assert-Case '탐침: 캡처 null + 플래그 정상 → False (창 좌표 실패 경로)' $probeVerdict 'False'
$script:probeReturnsNull = $false
$script:screenCaptureFailing = $false

# ── ①b-4 준비물 부족 품목 안내 (2026-08-07 실측: 곤충 채집망 소진) ──
# 고정 문구 '(빈 병 등)' 로는 무엇을 사야 할지 알 수 없어 팝업의 품목 줄을 그대로 옮깁니다.
Assert-Case '품목: 실측 판독(곤충 채집망 소진)' `
  (Format-LifeMissingItemNotice -ItemText '입문용 곤충 채집망 0 / 1') ' (필요: 입문용 곤충 채집망)'
Assert-Case '품목: 빈 병 (수량 붙임 표기)' (Format-LifeMissingItemNotice -ItemText '빈 병 0/1') ' (필요: 빈 병)'
Assert-Case '품목: 수량만 판독 → 조각 없음' (Format-LifeMissingItemNotice -ItemText '0 / 1') ''
Assert-Case '품목: 빈 판독 → 조각 없음' (Format-LifeMissingItemNotice -ItemText '') ''
Assert-Case '품목: 공백만 → 조각 없음' (Format-LifeMissingItemNotice -ItemText '   ') ''
Assert-Case '품목: 한 글자 판독 → 조각 없음 (틀린 이름 방지)' (Format-LifeMissingItemNotice -ItemText '병 0/1') ''

# ── ①b-5 클릭 직전 같은 프레임 제목 재확인 (2026-08-07 사용자 제안) ──
# 링크를 찾은 판독에는 팝업 제목도 들어 있습니다. 제목 검증과 클릭이 다른 캡처면
# 그 사이에 팝업이 바뀌어도 못 막습니다. 실측 배치: 제목 y191 / 링크 y350~411.
$linkFrameWords = @(
  @{ Text = '뾰족'; X = 470; Y = 191 }, @{ Text = '나무'; X = 520; Y = 191 },
  @{ Text = '채집물'; X = 462; Y = 218 },
  @{ Text = '가까운'; X = 490; Y = 411 }, @{ Text = '위치'; X = 528; Y = 411 }, @{ Text = '찾기'; X = 560; Y = 411 }
)
Assert-Case '클릭직전: 최상단 행만 제목으로 추출' (Get-LifeDetailTitleFromWords -Words $linkFrameWords) '뾰족나무'
Assert-Case '클릭직전: 빈 판독 → 빈 제목 (재확인 생략)' (Get-LifeDetailTitleFromWords -Words @()) ''
# 이름 줄이 통째로 안 읽히면 최상단 행이 라벨이 됩니다 (실측 전수: 물·우물·젖소·추수 4건)
Assert-Case '클릭직전: 최상단이 라벨 채집물 → 빈 제목' `
  (Get-LifeDetailTitleFromWords -Words @(@{ Text = '채집물'; X = 462; Y = 218 }, @{ Text = '가까운'; X = 490; Y = 411 })) ''
Assert-Case "클릭직전: 라벨 깨짐 '자|집물' 도 빈 제목" `
  (Get-LifeDetailTitleFromWords -Words @(@{ Text = '자|집물'; X = 462; Y = 218 }, @{ Text = '위치찾기'; X = 530; Y = 411 })) ''
Assert-Case "클릭직전: 라벨이 제목으로 잡혀도 차단하지 않음 (unknown)" `
  (Get-LifeTitleVerdict -Title (Get-LifeDetailTitleFromWords -Words @(@{ Text = '채집물'; X = 462; Y = 218 })) -TargetName '물' -Order $dailyOrder) 'unknown'
Assert-Case '클릭직전: 같은 행 오차 ±14px 까지 묶음' `
  (Get-LifeDetailTitleFromWords -Words @(@{ Text = '설원'; X = 460; Y = 190 }, @{ Text = '빛무리'; X = 520; Y = 203 }, @{ Text = '채집물'; X = 462; Y = 230 })) '설원빛무리'
# 판정은 전용 함수로 - 상세 판정식의 '꼬리 2자 trim'을 그대로 쓰면 정상 팝업을 오차단합니다
# (리뷰 재현: '거미줄XX' → 2자 깎여 '거미줄' → 목표 '거미줄 뭉치' 차단)
Assert-Case '클릭직전: 다른 대상 제목 → other (클릭 차단)' `
  (Get-LifeTitleVerdict -Title '뾰족나무' -TargetName '굵은 나무' -Order $woodOrder) 'other'
Assert-Case '클릭직전: 자기 대상 제목 → mine (통과)' `
  (Get-LifeTitleVerdict -Title '뾰족나무' -TargetName '뾰족 나무' -Order $woodOrder) 'mine'
Assert-Case '클릭직전: 깨진 제목 → unknown (막지 않음)' `
  (Get-LifeTitleVerdict -Title '뾰@족나+' -TargetName '뾰족 나무' -Order $woodOrder) 'unknown'
Assert-Case '클릭직전: 빈 제목 → unknown' (Get-LifeTitleVerdict -Title '' -TargetName '뾰족 나무' -Order $woodOrder) 'unknown'
# 복합 이름의 앞 낱말이 누락돼 일부만 읽힌 경우는 오차단 금지 (fail-open)
Assert-Case "클릭직전: '뾰족 나무' 목표에 제목 '나무' → unknown (일부 판독 가능성)" `
  (Get-LifeTitleVerdict -Title '나무' -TargetName '뾰족 나무' -Order $woodOrder) 'unknown'
Assert-Case "클릭직전: '철 광맥' 목표에 제목 '광맥' → unknown" `
  (Get-LifeTitleVerdict -Title '광맥' -TargetName '철 광맥' -Order $miningOrder) 'unknown'
Assert-Case "클릭직전: '거미줄 뭉치' 목표에 제목 '거미줄' → unknown (trim 오차단 방지)" `
  (Get-LifeTitleVerdict -Title '거미줄' -TargetName '거미줄 뭉치' -Order $dailyOrder) 'unknown'
# 반대 방향은 확정 차단 - 짧은 목표인데 긴 형제 이름이 읽혔으면 오클릭이 맞습니다
Assert-Case "클릭직전: '거미줄' 목표에 제목 '거미줄뭉치' → other (오클릭 확정)" `
  (Get-LifeTitleVerdict -Title '거미줄뭉치' -TargetName '거미줄' -Order $dailyOrder) 'other'
Assert-Case "클릭직전: '나무' 목표에 제목 '뾰족나무' → other" `
  (Get-LifeTitleVerdict -Title '뾰족나무' -TargetName '나무' -Order $woodOrder) 'other'
# 이형·공통 치환도 자기 것으로 인정 (실측 깨짐)
Assert-Case "클릭직전: 이형 '혼!껍질나무' → mine" `
  (Get-LifeTitleVerdict -Title '혼!껍질나무' -TargetName '흰 껍질 나무' -Order $woodOrder) 'mine'
Assert-Case "클릭직전: 공통 치환 '설원빛부리' → mine" `
  (Get-LifeTitleVerdict -Title '설원빛부리' -TargetName '설원 빛 무리' -Order $insectOrder) 'mine'

# 링크 판독으로 못 정하면 상세 영역 s3→s4, 그래도 안 되면 제목 띠 s4/s5/s6 (2026-08-08 실측:
# 넓은 영역 저배율로는 아예 안 읽히는 이름이 좁은 띠 고배율에서 읽힘)
Assert-Case '클릭직전: 상세 판독에서 제목부 절단 (라벨 잔여 포함)' (Get-LifeTitleFromDetailText -DetailText '으광맥채집물광석캐기레벨1이상') '으광맥채'
# 라벨 잔여('채'/'자|')를 깎으며 판정 - 임의 축약이 아니라 근거 있는 절단
Assert-Case "클릭직전(상세): '으광맥채' → mine (이형 + 잔여 1자)" `
  (Get-LifeTitleVerdictFromDetail -DetailText '으광맥채집물광석캐기레벨1이상' -TargetName '은 광맥' -Order $miningOrder) 'mine'
Assert-Case "클릭직전(상세): '헤이즐넛자|' → mine (잔여 2자)" `
  (Get-LifeTitleVerdictFromDetail -DetailText '헤이즐넛자|집물일상채집' -TargetName '헤이즐넛' -Order $dailyOrder) 'mine'
Assert-Case "클릭직전(상세): 다른 대상 → other (차단)" `
  (Get-LifeTitleVerdictFromDetail -DetailText '거미줄뭉치채집물일상채집' -TargetName '거미줄' -Order $dailyOrder) 'other'
Assert-Case "클릭직전(상세): 자기 대상 긴 이름 → mine" `
  (Get-LifeTitleVerdictFromDetail -DetailText '거미줄뭉치채집물일상채집' -TargetName '거미줄 뭉치' -Order $dailyOrder) 'mine'
Assert-Case "클릭직전(상세): 일부만 읽힘('나무채') + 목표 '뾰족 나무' → unknown (오차단 금지)" `
  (Get-LifeTitleVerdictFromDetail -DetailText '나무채집물나무베기레벨1이상' -TargetName '뾰족 나무' -Order $woodOrder) 'unknown'
Assert-Case '클릭직전(상세): 라벨 없음 → unknown' `
  (Get-LifeTitleVerdictFromDetail -DetailText '알수없는화면' -TargetName '감자' -Order @('감자')) 'unknown'
Assert-Case "클릭직전: 라벨 깨짐 '자|집물' 도 절단" (Get-LifeTitleFromDetailText -DetailText '헤이즐넛자|집물일상채집') '헤이즐넛자|'
Assert-Case '클릭직전: 라벨 없으면 빈 값 (재확인 생략)' (Get-LifeTitleFromDetailText -DetailText '알수없는화면') ''
Assert-Case '클릭직전: 라벨이 맨 앞이면 빈 값 (제목 없음)' (Get-LifeTitleFromDetailText -DetailText '집물광석캐기') ''
Assert-Case "클릭직전: 제목 '으광맥'(이형) → mine" `
  (Get-LifeTitleVerdict -Title '으광맥' -TargetName '은 광맥' -Order $miningOrder) 'mine'
# 두 배율 합의 (한 배율의 깨짐이 곧 오차단이 되지 않도록)
Assert-Case '합의: 둘 다 other → other (차단)' (Get-LifeConsensusVerdict -Verdicts @('other', 'other')) 'other'
Assert-Case '합의: other + mine 엇갈림 → unknown' (Get-LifeConsensusVerdict -Verdicts @('other', 'mine')) 'unknown'
Assert-Case '합의: mine + unknown → mine' (Get-LifeConsensusVerdict -Verdicts @('mine', 'unknown')) 'mine'
Assert-Case '합의: other 단독 → unknown (차단 보류)' (Get-LifeConsensusVerdict -Verdicts @('other', 'unknown')) 'unknown'
Assert-Case '합의: 전부 unknown → unknown' (Get-LifeConsensusVerdict -Verdicts @('unknown', 'unknown')) 'unknown'
Assert-Case '합의: 빈 입력 → unknown' (Get-LifeConsensusVerdict -Verdicts @()) 'unknown'
# 제목 띠 영역 = 라벨 행 기준 역산 (팝업이 세로 중앙 정렬이라 제목 Y 가 고정이 아님)
Assert-Case '제목띠: 라벨 y218 → 띠 (440,174,300,36)' `
  ((Get-LifeTitleStripRegion -Words @(@{ Text = '채집물'; X = 462; Y = 218 })) -join ',') '440,174,300,36'
Assert-Case '제목띠: 라벨 y240(제목 y213) 도 따라 이동' `
  ((Get-LifeTitleStripRegion -Words @(@{ Text = '자|집물'; X = 462; Y = 240 })) -join ',') '440,196,300,36'
Assert-Case '제목띠: 라벨 없으면 null (재확인 생략)' `
  ([bool]($null -eq (Get-LifeTitleStripRegion -Words @(@{ Text = '가까운'; X = 490; Y = 411 })))) 'True'
# ── 진행 값 추출 (2026-08-08 설계 변경: 한도를 '총 시간'이 아니라 '진행이 멈춘 시간'으로) ──
# 분모는 목표값으로 **곧바로 믿지 않습니다**('0/0','2/1' 실측) - 목표는 아래 합의로 정합니다.
# 다만 양수로 읽힌 분모는 **그 프레임 자체의 모순**('분자 > 분모')을 걸러내는 데 씁니다.
#
# ★ 2026-08-10 실기 실사고 (나무 베기, 목표 10): 두 번째 판독이 '41/10' 으로 나왔는데
#   교차 검사가 없어 41이 $progressMaxCount 에 박혔습니다. 그 하나로 ①진행 없음 타이머가
#   영영 리셋되지 않고(느린 대상이면 조건부 정지) ②완료 로그가 '(마지막 판독 41개)' 로
#   나갔습니다(목표 합의값 10은 정확했지만 `10 -ge 41` 이 거짓이라 폴백으로 떨어짐).
Assert-Case '진행값: 6/10 → 6' (Get-LifeProgressValue -CountText '6/10') 6
Assert-Case '진행값: 공백 포함 표기' (Get-LifeProgressValue -CountText ' 3 / 10 ') 3
Assert-Case '진행값: 10/10 (경계 - 같으면 유효)' (Get-LifeProgressValue -CountText '10/10') 10
Assert-Case '진행값: 0/0 (분모 0 - 검사 불가) 도 분자 사용' (Get-LifeProgressValue -CountText '0/0') 0
Assert-Case '진행값: 3/0 (분모만 깨짐) 도 분자 사용 - 실측' (Get-LifeProgressValue -CountText '3/0') 3
# ↓ 2026-08-10 이전에는 '2/1 → 2' 였습니다. 분자만 보면 맞는 값이지만, 같은 규칙이
#   '41/10' 도 통과시켜 실사고가 났습니다. 모순 프레임은 방향을 가리지 않고 버립니다
#   (실측에서 2/1 직후 2/10 이 오므로 잃는 것이 없었습니다).
Assert-Case '진행값: 2/1 (분자>분모 모순) → -1' (Get-LifeProgressValue -CountText '2/1') -1
Assert-Case '진행값: 41/10 (실사고 원문) → -1' (Get-LifeProgressValue -CountText '41/10') -1
Assert-Case '진행값: 6/1 (실측 모순) → -1' (Get-LifeProgressValue -CountText '6/1') -1
Assert-Case '진행값: 판독 없음 → -1' (Get-LifeProgressValue -CountText '') -1
Assert-Case '진행값: 수량 아님 → -1' (Get-LifeProgressValue -CountText '채집 장소 탐색') -1

# ── 실측 시퀀스 전체를 흘려 보기 (2026-08-10 20:51~20:54 로그 원문 20건, 목표 10) ──
# 개별 진리표만으로는 '오염된 최댓값이 타이머를 얼려 버린다'는 사고를 재현하지 못합니다.
# 호출부(mabinogi_run_once.ps1 10099~)의 최댓값·리셋 규칙을 그대로 흉내 내 단언합니다.
$measuredReads = @('1/10', '41/10', '1/10', '2/10', '2/1', '2/10', '2/1', '3/10', '3/0', '3/10',
                   '3/1', '3/10', '4/10', '5/10', '6/1', '6/10', '4/10', '7/10', '8/10', '9/10')
$simMax = -1
$simResets = 0
$simGoalCounts = @{}
foreach ($read in $measuredReads) {
  $v = Get-LifeProgressValue -CountText $read
  if ($v -gt $simMax) { $simMax = $v; $simResets++ }      # 호출부: 최댓값 갱신 시에만 deadline 재설정
  $g = Get-LifeQuestGoalValue -CountText $read
  if ($g -gt 0) {
    if (-not $simGoalCounts.ContainsKey($g)) { $simGoalCounts[$g] = 0 }
    $simGoalCounts[$g] = [int]$simGoalCounts[$g] + 1
  }
}
Assert-Case '실측 시퀀스: 최종 최댓값이 9 (41에 오염되지 않음)' $simMax 9
Assert-Case '실측 시퀀스: 진행으로 인한 타이머 리셋 9회' $simResets 9
Assert-Case '실측 시퀀스: 목표 합의는 10' (Get-LifeQuestGoalConsensus -GoalCounts $simGoalCounts) 10
# 완료 로그 게이트(본체 10141~)를 그대로 재현 - 이 게이트 자체는 옳고, 분자 오염만 문제였습니다
$simGoal = Get-LifeQuestGoalConsensus -GoalCounts $simGoalCounts
$simDone = $(if ($simGoal -gt 0 -and $simGoal -ge $simMax) { "${simGoal}개" } else { "(마지막 판독 ${simMax}개)" })
Assert-Case '실측 시퀀스: 완료 로그가 목표 개수를 쓴다' $simDone '10개'
# 수정 전 재현 - 분자 교차 검사가 없으면 41이 박혀 완료 로그가 뒤집힙니다
$brokenMax = -1
foreach ($read in $measuredReads) {
  if ($read -match '(\d{1,3})/(\d{1,3})') { $n = [int]$Matches[1]; if ($n -gt $brokenMax) { $brokenMax = $n } }
}
Assert-Case '수정 전 재현: 교차 검사가 없으면 최댓값이 41' $brokenMax 41
Assert-Case '수정 전 재현: 그때 완료 로그는 41개로 나갔다' `
  ($(if ($simGoal -gt 0 -and $simGoal -ge $brokenMax) { "${simGoal}개" } else { "(마지막 판독 ${brokenMax}개)" })) '(마지막 판독 41개)'

# ── 수량 추출: **마지막** 매치를 취한다 (2026-08-10 실기) ──────────────────────
# 제목 '채집 장소 탐색' 이 깨지면서 판독문 **앞부분**에 숫자 조각이 생깁니다. 첫 매치를
# 취하면 그 노이즈가 진짜 수량을 밀어냅니다 - 실기에서 41/10(실제 1), 40/10(실제 0),
# 1146/10(실제 5)이 나왔습니다. 진짜 수량은 제목 뒤라 **항상 맨 뒤**입니다.
# 본체는 OCR 을 타므로 여기서는 같은 규칙을 순수 함수로 재현해 진리표를 고정합니다.
function Get-CountTextFromRead {
  param([string]$QuestText)
  $m = [regex]::Matches([string]$QuestText, '(\d+)\s*/\s*(\d+)')
  if ($m.Count -gt 0) {
    $last = $m[$m.Count - 1]
    return ('{0}/{1}' -f $last.Groups[1].Value, $last.Groups[2].Value)
  }
  return ''
}
# 오늘 실측한 배율별 판독 원문 (같은 캡처, 실제 4/10) - 앞 조각이 매번 다르게 생깁니다
Assert-Case '추출 s2 실측: 앞의 41/ 을 넘기고 4/10' `
  (Get-CountTextFromRead -QuestText "채집장소타색•f41/:;:')•로!결결§치재테4/10") '4/10'
Assert-Case '추출 s3 실측: 앞의 11/ 을 넘기고 4/10' `
  (Get-CountTextFromRead -QuestText "수해집장소다색쥐T11/``,Qb'')•기구!람전믕치채寸4/10") '4/10'
Assert-Case '추출 s5 실측: 4/10' `
  (Get-CountTextFromRead -QuestText '+해집장소타색4d국t」蜃최처寸4/10') '4/10'
Assert-Case '추출 s6 실측: 4/10' `
  (Get-CountTextFromRead -QuestText '채집장소타색?한曇긔卍빈4/10') '4/10'
# 실사고 원문 형태 - 노이즈가 온전한 N/N 이면 첫 매치는 그걸 잡습니다
Assert-Case '추출: 앞 노이즈가 41/10 이어도 뒤의 1/10 채택' `
  (Get-CountTextFromRead -QuestText '채집장소탐색41/10거미줄뭉치채집1/10') '1/10'
Assert-Case '추출: 1146/10 노이즈도 뒤의 5/10 채택' `
  (Get-CountTextFromRead -QuestText '채집장소탐색1146/10나무채집5/10') '5/10'
# 정상 화면은 매치가 하나뿐이라 첫/마지막이 같습니다 (저장소 흐름 캡처 12건 전수 확인)
Assert-Case '추출: 매치 1개면 그대로' (Get-CountTextFromRead -QuestText '채집장소탐색나무채집7/10') '7/10'
Assert-Case '추출: 공백 포함' (Get-CountTextFromRead -QuestText '나무 채집 3 / 10') '3/10'
Assert-Case '추출: 수량 없으면 빈 문자열' (Get-CountTextFromRead -QuestText '채집장소탐색') ''
# 수량 뒤에 시간 표기가 붙어도 N/N 이 아니면 영향 없음
Assert-Case '추출: 뒤에 시간 문구가 붙어도 안전' `
  (Get-CountTextFromRead -QuestText '나무채집4/10ⓒ7시간남음') '4/10'

# ── 진행 로그 게이트: 최댓값 갱신 시에만 남긴다 (2026-08-10 사용자 요청) ───────
# "9/10 이면 1번만 제대로 나왔으면 좋겠다" - 예전에는 판독 문자열 전체를 비교해서
# 분모만 흔들려도('9/10'→'9/1'→'9/10') 세 줄이 찍혔습니다. 분자가 아래로 흔들리는
# 경우('6/10'→'4/10'→'6/10')도 마찬가지였습니다.
function Get-ProgressLogLines {
  param([string[]]$Reads)
  $max = -1
  $lines = @()
  foreach ($r in $Reads) {
    $v = Get-LifeProgressValue -CountText $r
    if ($v -gt $max) { $max = $v; if ($r) { $lines += $r } }
  }
  if ($lines.Count -eq 0) { return '(로그 없음)' }
  return ($lines -join ' | ')
}
Assert-Case '로그: 9/10 → 9/1 → 9/10 은 한 줄 (사용자 요청 그 케이스)' `
  (Get-ProgressLogLines -Reads @('9/10', '9/1', '9/10')) '9/10'
Assert-Case '로그: 3/10 → 3/0 → 3/10 도 한 줄' `
  (Get-ProgressLogLines -Reads @('3/10', '3/0', '3/10')) '3/10'
Assert-Case '로그: 분자 하락 노이즈도 한 줄로 흡수' `
  (Get-ProgressLogLines -Reads @('6/10', '4/10', '6/10', '7/10')) '6/10 | 7/10'
Assert-Case '로그: 모순 프레임은 아예 안 찍힌다' `
  (Get-ProgressLogLines -Reads @('41/10', '1/10')) '1/10'
Assert-Case '로그: 진행 한 개당 정확히 한 줄' `
  (Get-ProgressLogLines -Reads @('0/10', '0/1', '1/10', '1/10', '2/10')) '0/10 | 1/10 | 2/10'
# 오늘 실측 20건을 그대로 흘리면 0~9 열 줄만 남아야 합니다(41 은 걸러짐)
Assert-Case '로그: 실측 20건 → 진행 값이 바뀐 만큼만' `
  ((Get-ProgressLogLines -Reads $measuredReads) -split ' \| ').Count 9

# ── 배선 가드: 위 진리표는 **사본 함수**라 본체를 안 봅니다 ────────────────────
# ★ 2026-08-10 변이 검증에서 이 구멍이 드러났습니다. 본체를 '첫 매치'로 되돌리고 로그
#   게이트를 -ne 로 바꿔도 위 단언들은 전부 초록이었습니다(사본만 검사하므로).
#   `Get-LifeQuestCountText` 는 OCR 을 타서 단독 실행이 안 되므로 소스로 못 박습니다.
$countBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-LifeQuestCountText'))
$countCode = (($countBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 추출이 Matches(전체)를 쓴다' `
  ([bool]($countCode -match '\[regex\]::Matches\(\[string\]\$questText')) 'True'
Assert-Case '배선: 추출이 **마지막** 매치를 취한다' `
  ([bool]($countCode -match '\$countMatches\[\$countMatches\.Count - 1\]')) 'True'
Assert-Case '배선: 첫 매치(Match/인덱스 0)로 되돌아가지 않는다' `
  ([bool](($countCode -match '\[regex\]::Match\(\[string\]\$questText') -or
          ($countCode -match '\$countMatches\[0\]'))) 'False'
# 로그 두 곳이 '최댓값 갱신' 게이트 안에 있는지 (문자열 비교로 되돌아가면 실사고 재발)
$workerRaw = [IO.File]::ReadAllText($workerPath)
Assert-Case '배선: 내 채집 로그가 최댓값 갱신 블록 안' `
  ([bool]($workerRaw -match '(?s)if \(\$countValue -gt \$progressMaxCount\) \{[^}]{0,400}Write-RunLog "\[생활\] 채집 진행: \$countText"')) 'True'
Assert-Case '배선: 이전 채집 로그도 최댓값 갱신 블록 안' `
  ([bool]($workerRaw -match '(?s)if \(\$otherCountValue -gt \$otherProgressMax\) \{[^}]{0,300}Write-RunLog "\[생활\] 이전 채집 진행 중: \$otherCount"')) 'True'
# 옛 '마지막 판독 문자열' 비교 방식으로 되돌아가지 않는지
Assert-Case '배선: 문자열 비교 중복 제거를 되살리지 않는다' `
  ([bool](($workerRaw -match '\$countText -ne \$lastCountText') -or
          ($workerRaw -match '\$otherCount -ne \$otherLastCount'))) 'False'
# 초기값이 -1 이어야 첫 판독(0개)도 한 줄 남습니다 - 0 으로 두면 '0/10' 이 사라집니다
Assert-Case '배선: 진행 최댓값 초기값 -1' `
  ([bool]($workerRaw -match '(?m)^\s*\$progressMaxCount = -1\s*$')) 'True'
Assert-Case '배선: 이전 채집 최댓값 초기값 -1' `
  ([bool]($workerRaw -match '(?m)^\s*\$otherProgressMax = -1\s*$')) 'True'

# ── 시간 지정 모드: 워커가 목표 시각에 사이클 중에도 끊는다 (2026-08-11 실측 ① 대응) ──
# 실측: GUI 는 사이클이 끝나야 시간을 봐서 목표 10:46 을 2분 24초 넘김(10:48:24 완료).
# 수정: GUI 가 생활+시간 지정일 때만 HONEYNOGI_UNTIL_TIME(yyyy-MM-dd HH:mm)을 전달하고,
# 워커의 생활 장기 대기 루프들이 Test-LifeUntilReached 로 도달 즉시 exit 4.

# (a) 파싱 진리표 - Get-LifeUntilDeadline 은 순수(경고 로그 제외)
if (-not (Get-Command Write-RunLog -ErrorAction SilentlyContinue)) { function Write-RunLog { param($m) } }
foreach ($definition in Get-SourceFunctionDefinitions -Path $workerPath -Names @('Get-LifeUntilDeadline')) {
  . ([scriptblock]::Create($definition))
}
Assert-Case '지정시간 파싱: 정상 전체 타임스탬프' `
  ((Get-LifeUntilDeadline -Raw '2026-08-11 10:46').ToString('yyyy-MM-dd HH:mm')) '2026-08-11 10:46'
Assert-Case '지정시간 파싱: 자정 넘김(다음날 날짜)도 그대로' `
  ((Get-LifeUntilDeadline -Raw '2026-08-12 00:30').ToString('yyyy-MM-dd HH:mm')) '2026-08-12 00:30'
Assert-Case '지정시간 파싱: 빈 값은 제한 없음' ($null -eq (Get-LifeUntilDeadline -Raw '')) $true
Assert-Case '지정시간 파싱: 공백만도 제한 없음' ($null -eq (Get-LifeUntilDeadline -Raw '   ')) $true
Assert-Case '지정시간 파싱: HH:mm 만은 형식 오류 - fail-open' `
  ($null -eq (Get-LifeUntilDeadline -Raw '10:46')) $true
Assert-Case '지정시간 파싱: 쓰레기 값도 fail-open' `
  ($null -eq (Get-LifeUntilDeadline -Raw 'abc')) $true
Assert-Case '지정시간 파싱: 앞뒤 공백 허용' `
  ((Get-LifeUntilDeadline -Raw ' 2026-08-11 10:46 ').ToString('HH:mm')) '10:46'

# (b) 워커 배선 - 검사 함수 계약과 호출 지점
$untilBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-LifeUntilReached'))
$untilCode = (($untilBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선(지정시간): 도달 판정은 -ge (같은 시각 포함)' `
  ([bool]($untilCode -match '-ge \$script:lifeUntilDeadline')) 'True'
Assert-Case '배선(지정시간): 도달 시 exit 4 (사이클 미계상)' `
  ([bool]($untilCode -match 'exit 4')) 'True'
Assert-Case '배선(지정시간): 사유 문구에 지정 시간 표기' `
  ([bool]($untilCode -match '지정 시간\(\{0\}\) 도달')) 'True'
# 호출 지점: 시작 직후 1 + 초기 확인 + 이전 채집 대기 + 메뉴 재시도 + 캡처 대기 + 생성 확인
# + 메인 대기 = 7곳 (정확 개수 - 줄이면 그 대기에서 목표를 넘김)
Assert-Case '배선(지정시간): 검사 호출 7곳' `
  (@([regex]::Matches($workerRaw, '(?m)^\s*Test-LifeUntilReached')).Count) 7
# 메인 대기 루프에서 until 검사가 절대 상한 검사보다 앞 (사유 우선 계약)
Assert-Case '배선(지정시간): 메인 루프에서 지정 시간이 절대 상한보다 먼저' `
  ([bool]($workerRaw -match '(?s)while \(\$true\) \{[^}]{0,400}Test-LifeUntilReached[^}]{0,400}-gt \$hardDeadline')) 'True'
# 메뉴 시퀀스에는 사이클 한도와 지정 시간 중 이른 쪽을 넘긴다 (내부 입력 직전 검사가 이 값을 봄)
Assert-Case '배선(지정시간): 메뉴 한도 = min(사이클, 지정시간) 계산' `
  ([bool]($workerRaw -match '\$lifeMenuDeadline = \$script:lifeUntilDeadline')) 'True'
Assert-Case '배선(지정시간): 메뉴 호출이 clamp 된 한도를 사용' `
  ([bool]($workerRaw -match 'Invoke-LifeMenuSequence[^\r\n]+-Deadline \$lifeMenuDeadline')) 'True'
Assert-Case '배선(지정시간): 옛 사이클 한도 직접 전달이 남아 있지 않다' `
  ([bool]($workerRaw -match 'Invoke-LifeMenuSequence[^\r\n]+-Deadline \$cycleDeadline')) 'False'
# 메뉴 시퀀스 입력 직전 가드 (교차 리뷰 - C 입력/스킬 셀 클릭 앞)
Assert-Case '배선(지정시간): C 입력 직전 한도 재검사' `
  ([bool]($workerRaw -match '(?s)-gt \$Deadline\) \{ Write-RunLog[^\r\n]+메뉴 진행 중단[^\r\n]+\}\r?\n\s*if \(-not \(Press-LifeMenuKey')) 'True'
Assert-Case '배선(지정시간): 스킬 셀 클릭 직전 한도 재검사' `
  ([bool]($workerRaw -match '(?s)-gt \$Deadline\) \{ Write-RunLog[^\r\n]+메뉴 진행 중단[^\r\n]+\}\r?\n\s*Focus-Game -Game \$Game\r?\n\s*Click-GamePoint -Game \$Game -ReferenceX \(\[int\]\$SkillEntry\.Cell\[0\]\)')) 'True'

# (c) GUI 배선 - env 전달 조건과 초 정규화
$guiRaw = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_gui.ps1'))
Assert-Case '배선(지정시간 GUI): 매 회차 env 먼저 초기화' `
  ([bool]($guiRaw -match "(?m)^\s*\`$env:HONEYNOGI_UNTIL_TIME = ''")) 'True'
Assert-Case '배선(지정시간 GUI): 생활 + 시간 지정일 때만 설정' `
  ([bool]($guiRaw -match "targetTime\) -and \(\`$script:mainCategory -eq 'life'\)")) 'True'
Assert-Case '배선(지정시간 GUI): 전체 타임스탬프 형식으로 전달' `
  ([bool]($guiRaw -match "HONEYNOGI_UNTIL_TIME = \`$script:targetTime\.ToString\('yyyy-MM-dd HH:mm'\)")) 'True'
Assert-Case '배선(지정시간 GUI): DateTimePicker 숨은 초 정규화' `
  ([bool]($guiRaw -match 'AddHours\(\$untilTod\.Hours\)\.AddMinutes\(\$untilTod\.Minutes\)')) 'True'
Assert-Case '배선(지정시간 GUI): 옛 TimeOfDay 직접 덧셈이 남아 있지 않다' `
  ([bool]($guiRaw -match '\(Get-Date\)\.Date\.Add\(\$dtpUntil\.Value\.TimeOfDay\)')) 'False'
# 시간 지정과 커스텀은 상호 배타 - 이 불변식이 깨지면 커스텀 완료 마커 계상 경로와 충돌 (리뷰)
Assert-Case '배선(지정시간 GUI): 커스텀 활성 시 targetTime 강제 해제 유지' `
  ([bool]($guiRaw -match 'customActive\) \{ \$script:targetCycles = 0; \$script:targetTime = \$null \}')) 'True'
# ── 목표 개수(분모) 추출/합의 (2026-08-08 사용자 제보: 완료 로그가 '9개' 로 나옴) ──
# 마지막 개를 채우는 순간 트래커가 사라져 3초 폴링이 그 프레임을 놓칩니다. 그래서 완료
# 로그에는 '마지막으로 본 수량'이 아니라 '목표 개수'를 적습니다.
Assert-Case '목표: 6/10 → 10' (Get-LifeQuestGoalValue -CountText '6/10') 10
Assert-Case '목표: 공백 포함' (Get-LifeQuestGoalValue -CountText ' 9 / 10 ') 10
Assert-Case '목표: 분모가 분자보다 작으면 버림 (2/1 실측 깨짐)' (Get-LifeQuestGoalValue -CountText '2/1') 0
Assert-Case '목표: 0/0 깨짐 → 0' (Get-LifeQuestGoalValue -CountText '0/0') 0
Assert-Case '목표: 0/1 은 유효 (분자 0 이하 아님)' (Get-LifeQuestGoalValue -CountText '0/1') 1
Assert-Case '목표: 판독 없음 → 0' (Get-LifeQuestGoalValue -CountText '') 0
# 한 회차 판독은 못 믿으므로 가장 많이 본 분모를 채택 (동률이면 큰 값 - 깨짐은 작게 나옴)
Assert-Case '목표합의: 10 을 5회, 1 을 1회 → 10' (Get-LifeQuestGoalConsensus -GoalCounts @{ 10 = 5; 1 = 1 }) 10
Assert-Case '목표합의: 동률이면 큰 값' (Get-LifeQuestGoalConsensus -GoalCounts @{ 10 = 2; 1 = 2 }) 10
Assert-Case '목표합의: 비어 있으면 0' (Get-LifeQuestGoalConsensus -GoalCounts @{}) 0
Assert-Case '목표합의: null 이면 0' (Get-LifeQuestGoalConsensus -GoalCounts $null) 0
# ── ①c '가까운 위치 찾기' 링크 단어 선택 (본문 '가까운' 오클릭 방지 - 리뷰 조건) ──
# 실측 배치: 링크 y 는 대상별로 다름 (둥지 ~350 / 사과나무 411) → 좌표 아닌 글자 탐색
$linkRow = @(
  @{ Text = '가까운'; X = 490; Y = 350 },
  @{ Text = '위치'; X = 528; Y = 351 },
  @{ Text = '찾기'; X = 560; Y = 350 }
)
$picked = Select-LifeFindNearestWord -Words $linkRow
Assert-Case '링크: 단일 링크 행 → 행 가로 중앙 선택' ('{0},{1}' -f $picked.X, $picked.Y) '525,350'
# 실기 깨짐: '가까운'이 '가7)}운'으로 읽혀도 '위치찾기' 조각으로 링크 행을 찾아야 함 (라운드 5)
$brokenLink = @(
  @{ Text = '가7)}운'; X = 486; Y = 411 },
  @{ Text = '위치찾기'; X = 546; Y = 411 }
)
$picked = Select-LifeFindNearestWord -Words $brokenLink
Assert-Case "링크: '가까운' 깨짐도 '위치찾기'로 검출" ('{0},{1}' -f $picked.X, $picked.Y) '516,411'
# 설명 본문에 '가까운'이 있어도 링크 행만 채택 (같은 행 결합 문구로 판별)
$linkWithBody = @(
  @{ Text = '가까운'; X = 470; Y = 300 },
  @{ Text = '숲에서'; X = 520; Y = 301 },
  @{ Text = '가까운'; X = 490; Y = 411 },
  @{ Text = '위치'; X = 528; Y = 411 },
  @{ Text = '찾기'; X = 560; Y = 412 }
)
$picked = Select-LifeFindNearestWord -Words $linkWithBody
Assert-Case '링크: 본문 가까운 무시하고 링크 행 선택' ('{0},{1}' -f $picked.X, $picked.Y) '525,411'
# 격자 추론 대상의 본문 구제: 이름 전체가 없어도 고유 수식어로 확인 (백동 광맥 실측)
$miningOrder = @('광맥', '철 광맥', '얼음', '석탄 광맥', '동 광맥', '백동 광맥', '은 광맥')
Assert-Case "상세: 깨진 제목 + 본문 '백동' 수식어 → match" `
  (Get-LifeDetailVerdict -DetailText 'BHE고十臼H자|집물광석개기레벨20이상백동이섞인단단한돌무더기.곡괭이로백동광석을갤수있다.' -TargetName '백동 광맥' -Order $miningOrder) 'match'
Assert-Case "상세: 수식어가 다른 대상에도 들어가면 인정 안 함 ('동' → 백동/동 모호)" `
  (Get-LifeDetailVerdict -DetailText 'X자|집물광석개기레벨1이상동이섞인돌무더기.' -TargetName '동 광맥' -Order $miningOrder) 'unreadable'
# ── 2026-08-12 실사고 (타 PC 1908 창, 동 광맥) 진리표 ──
# 그 창의 상세 판독은 제목을 통째로 놓쳐 '채집물…'로 시작 (관측 5회 전부) → 상세 단독으로는
# 구조적으로 unreadable 이 정답 (아래 고정 - 본문 '동이섞인/동광석'은 백동 본문에도 부분
# 문자열로 들어가 판별력 없음). 구제는 클릭 프레임 링크 제목의 명시 이형 게이트가 담당.
Assert-Case '상세: 실사고 전문(제목 소실) → unreadable (상세 단독 판단 불가 고정)' `
  (Get-LifeDetailVerdict -DetailText '채집물광석개기레벨10이상동이섞인단단한돌무더기.곡괭이로동광석을갤수있다.[사냥터]여신의뜰,구름황야가까운위치찾기0' -TargetName '동 광맥' -Order $miningOrder) 'unreadable'
# 명시 이형 게이트 (약한 order 회전 전용): 제목 전용 이형 표와 정확 일치할 때만 진행 허용.
# 넓은 mine(정식 이름 포함)을 금지하는 이유 - 백동 광맥 팝업이 '백' 손실로 '동광맥'으로
# 읽히면 목표 '동 광맥'에 mine 이 되는 손실 오독 충돌 (교차 리뷰 반례).
Assert-Case "명시 이형: 실측 '도과DH' → 동 광맥 진행 허용" (Test-LifeTitleExplicitVariant -Title '도과DH' -TargetName '동 광맥') 'True'
Assert-Case "명시 이형: 정식 이름 '동광맥'은 불허 (손실 오독 충돌 배제)" `
  (Test-LifeTitleExplicitVariant -Title '동광맥' -TargetName '동 광맥') 'False'
Assert-Case "명시 이형: 타 대상 이형 'BHE고十DH'(백동)는 불허" (Test-LifeTitleExplicitVariant -Title 'BHE고十DH' -TargetName '동 광맥') 'False'
Assert-Case "명시 이형: '도과DH'를 은 광맥 목표로는 불허" (Test-LifeTitleExplicitVariant -Title '도과DH' -TargetName '은 광맥') 'False'
Assert-Case '명시 이형: 이형 미등록 대상은 항상 불허' (Test-LifeTitleExplicitVariant -Title '둥지' -TargetName '둥지') 'False'
Assert-Case '링크: 후보 없음 → null' ($null -eq (Select-LifeFindNearestWord -Words @(@{ Text = '설명'; X = 500; Y = 300 }))) 'True'
# 링크처럼 보이는 행이 2개면 판단 보류 (오클릭 방지 - 재시도)
$linkTwice = @(
  @{ Text = '가까운'; X = 490; Y = 350 }, @{ Text = '위치'; X = 528; Y = 350 }, @{ Text = '찾기'; X = 560; Y = 350 },
  @{ Text = '가까운'; X = 490; Y = 411 }, @{ Text = '위치'; X = 528; Y = 411 }, @{ Text = '찾기'; X = 560; Y = 411 }
)
Assert-Case '링크: 후보 2개 → null (단일 후보만 클릭)' ($null -eq (Select-LifeFindNearestWord -Words $linkTwice)) 'True'
Assert-Case '링크: 빈 판독 → null' ($null -eq (Select-LifeFindNearestWord -Words @())) 'True'

# ── ② 퀘스트 상태 진리표 (실측 판독 문자열 - 트래커 OCR/HUD 스텁) ──
# 스텁은 **영역 인지형**입니다 (2026-08-09 감사). 예전 스텁은 ROI 인자를 버리고 항상 같은
# 문자열을 돌려줘서, 좁은 판독 → 넓은 판독 2단 구조와 전면화 후 재판독이 통째로 삭제되거나
# 인자가 뒤바뀌어도 회귀가 전부 초록이었습니다. 예상 밖 ROI 는 조용한 기본값 대신 FAIL 을
# 냅니다 - 배선이 바뀌면 테스트가 먼저 알아야 합니다.
function Get-GameRegionOcrText {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale, $Engine)
  # ROI 는 **4튜플 전체**를 비교합니다. X/Y 만 보면 폭·높이가 잘못 넘어가도 통과합니다.
  $roi = ('{0},{1},{2},{3}' -f $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight)
  $roiTag = ''
  if ($roi -eq (($rgLifeQuestTracker -join ','))) { $roiTag = 'narrow' }
  elseif ($roi -eq (($rgLifeQuestWide -join ','))) { $roiTag = 'wide' }
  else {
    "FAIL 퀘스트 OCR 스텁: 예상 밖 ROI ($roi) - 좁은/넓은 판독 배선 확인 필요"
    $script:fails++
    return ''
  }
  if ($Scale -ne 3) {
    "FAIL 퀘스트 OCR 스텁: 예상 밖 배율 ($Scale) - 퀘스트 판독은 스케일 3 계약"
    $script:fails++
  }
  $script:questOcrCalls += $roiTag
  # 게임이 뒤에 있으면 화면에 보이는 건 남의 창입니다 - 어느 영역을 읽어도 그 창 글자가 나옵니다
  if ((-not $script:mockGameFront) -and -not [string]::IsNullOrEmpty($script:mockCoveredText)) {
    return [string]$script:mockCoveredText
  }
  if ($roiTag -eq 'narrow') { return [string]$script:mockQuestTextNarrow }
  return [string]$script:mockQuestTextWide
}
$script:questOcrCalls = @()
$script:mockCoveredText = ''
function Set-MockQuestText {
  # Wide 를 생략하면 두 영역이 같은 글자를 돌려줍니다 (기존 진리표와 동일한 조건).
  # '가려짐' 글자는 매번 초기화합니다 (앞 케이스가 뒤 케이스에 새지 않도록).
  param([string]$Narrow, $Wide = $null)
  $script:mockQuestTextNarrow = $Narrow
  $script:mockQuestTextWide = $(if ($null -eq $Wide) { $Narrow } else { [string]$Wide })
  $script:mockCoveredText = ''
}
function Test-HomeEndEscHud { param($Game) return [bool]$script:mockHudVisible }
# 판독 전 전면 확인/전면화 계약용 스텁 (2026-08-07 - 실기에서는 다른 창이 게임을 덮었는지 확인)
function Test-GameForeground { param($Game) return [bool]$script:mockGameFront }
function Focus-Game { param($Game) }   # 전면화 성공 여부는 mockGameFront 로 제어
$script:mockGameFront = $true
$script:screenCaptureFailing = $false

function Invoke-QuestStateCase {
  param([string]$Text, [bool]$Hud, [bool]$CaptureFailing = $false, $WideText = $null)
  Set-MockQuestText -Narrow $Text -Wide $WideText
  $script:mockHudVisible = $Hud
  $script:screenCaptureFailing = $CaptureFailing
  $script:questOcrCalls = @()
  $result = Get-LifeQuestState -Game $null
  $script:screenCaptureFailing = $false
  return $result
}
Assert-Case '퀘스트: 생성 직후 실측 (4번 캡처)' (Invoke-QuestStateCase '•채집 장소 탐색 •사과 나부 채집 0/10' $true) 'present'
Assert-Case "퀘스트: '탐색' 누락 실측 (5b)" (Invoke-QuestStateCase '채집 장소 •사과 나구 채집 4/10' $false) 'present'
Assert-Case '퀘스트: 종료 후 실측 (6번) + HUD → absent' (Invoke-QuestStateCase '표] 모험가 길드의 정기 의뢰 (기 •심층 던전 들리어 0/3' $true) 'absent'
Assert-Case '퀘스트: 종료 텍스트 + HUD 없음 → unknown (부재 오판 방지)' (Invoke-QuestStateCase '표] 모험가 길드의 정기 의뢰' $false) 'unknown'
Assert-Case '퀘스트: 빈 판독 + HUD → absent' (Invoke-QuestStateCase '' $true) 'absent'
Assert-Case '퀘스트: 빈 판독 + HUD 없음 → unknown' (Invoke-QuestStateCase '' $false) 'unknown'
Assert-Case '퀘스트: 캡처 실패 중 → unknown (텍스트 무관)' (Invoke-QuestStateCase '•채집 장소 탐색' $true $true) 'unknown'
# 2026-08-14 계약 반전: '채집 N/M'은 채집(정지) 단계 트래커의 콤팩트 목표줄 그 자체다
# (계측 실측 19:18:44 '채집0/10:즤뇨…' - 이름이 통째로 깨진 채 퀘스트 생존 중). 구 계약
# (2조각 요구)은 이 줄을 absent 로 봐서 진행 중 오완료를 만들었다 - present 가 정답.
Assert-Case "퀘스트: 콤팩트 목표줄('채집 N/M') → present (2026-08-14 반전)" (Invoke-QuestStateCase '채집 0/10' $true) 'present'
# 3조각(채집/장소/탐색) 중 2개면 present - 한 조각이 깨져도 놓치지 않음 (2026-08-07 사용자 지적)
Assert-Case '퀘스트: 탐색 깨짐 실측 (채집+장소만) → present' (Invoke-QuestStateCase '채집 장소 탐 •백금 광맥 채집 010' $true) 'present'
Assert-Case "퀘스트: '채집' 깨짐 + 장소/탐색 → present" (Invoke-QuestStateCase '차||집 장소 탐색' $true) 'present'
Assert-Case "퀘스트: '장소' 깨짐 + 채집/탐색 → present" (Invoke-QuestStateCase '채집 잠소 탐색 사과나무' $true) 'present'
Assert-Case "퀘스트: '탐색' 한 조각만 → present 아님" (Invoke-QuestStateCase '탐색 0/3' $true) 'absent'
# 순수 판정 단독 진리표
Assert-Case '조각: 채집+장소 → true' (Test-LifeQuestFragments -QuestText '•채집 장소 •사과 나부 채집 0/10') 'True'
Assert-Case '조각: 주간 목표 문구 → false' (Test-LifeQuestFragments -QuestText '표] 모험가 길드의 정기 의뢰 •심층 던전 클리어 0/3') 'False'
Assert-Case '조각: 빈 문자열 → false' (Test-LifeQuestFragments -QuestText '') 'False'
# 2026-08-14 네이티브 계측 실측: 채집(정지) 단계 트래커는 제목줄 없이 '{대상}채집 N/M' 만
# 남는다 - 조각 2-of-3 이 구조적으로 불가능해 진행 중 오완료(사과나무 6/10·헤이즐넛 0/10).
# 아래 present 4건은 실사고 판독 원문 그대로
Assert-Case '조각: 콤팩트 목표줄(분모 소실) → true' (Test-LifeQuestFragments -QuestText '7•둥지채집0/[주간목표]모험가길두의정기의뢰(2)') 'True'
Assert-Case '조각: 콤팩트 목표줄(이름 깨짐) → true' (Test-LifeQuestFragments -QuestText '들자채집0/10[주간목표]모험가길드의정기의뢰(2)') 'True'
Assert-Case "조각: '집→칩' 깨짐 + 분자/분모 → true" (Test-LifeQuestFragments -QuestText "연')辱나阜자|칩9/10/*晷넣츄보冒가길4의정기호로(2,") 'True'
Assert-Case '조각: 이동 안내 → true' (Test-LifeQuestFragments -QuestText '목적지로이동•길을찾는중••。卜소탐색+목喜1구험)결-」정기의뢰') 'True'
# 오탐 가드: 진성 부재 판독(퀘스트가 정말 없는 트래커 - 길드/이벤트 줄만)은 absent 유지
Assert-Case '조각: 진성 부재(길드 하위 N/M) → false' (Test-LifeQuestFragments -QuestText '[주간목표]모험가길드의정기의뢰(2)던전클리어0/5사냥터클리어4/5') 'False'
Assert-Case '조각: 진성 부재(이벤트 줄) → false' (Test-LifeQuestFragments -QuestText '달걀을지켜라!12일남음시원한여름을보내는법C33일남음마음을전합니다19회=') 'False'
Assert-Case "조각: 같은 개념 이형 중복은 1점 ('채집해집') → false" (Test-LifeQuestFragments -QuestText '채집해집') 'False'
# 소유자 증거 분리 (Codex 반례): 콤팩트 줄 뒤 주간 목표 줄의 긴 이름을 소유자로 집으면 안 됨
Assert-Case '소유 범위: 콤팩트 목표줄까지만 → 나무' `
  (Get-LifeQuestOwner -QuestText (Get-LifeQuestOwnerText -QuestText '•나무채집0/10[주간목표]뾰족나무') -Order @('나무', '뾰족 나무')) '나무'
Assert-Case '소유 범위: 이동 안내만으로는 미확정 (이름 근거 없음)' `
  (Get-LifeQuestOwnerText -QuestText '목적지로이동[주간목표]뾰족나무') ''
Assert-Case '소유 범위: 제목줄 형태는 전체 유지 (기존 계약)' `
  (Get-LifeQuestOwner -QuestText (Get-LifeQuestOwnerText -QuestText '채집 장소 탐색 우물 채집 3/10') -Order @('물', '우물')) '우물'
# ── ②a 좁은 판독 → 넓은 판독 2단 구조 (2026-08-09 감사 - 이전 스텁으로는 검증 불가였음) ──
# 실사고: 획득 경험치 배지가 첫 줄(좁은 ROI)을 덮고 퀘스트는 아래로 밀렸는데, 좁은 판독만
# 보고 '없음'으로 확정해 진행 중인 채집을 완료로 처리했습니다.
Assert-Case '2단: 좁은 판독은 배지, 넓은 판독에 퀘스트 → present' `
  (Invoke-QuestStateCase '획득 경험치 +1,250' $true -WideText '•채집 장소 탐색 •사과 나무 채집 3/10') 'present'
Assert-Case '2단: 넓은 판독까지 없고 HUD 있으면 absent' `
  (Invoke-QuestStateCase '획득 경험치 +1,250' $true -WideText '표] 모험가 길드의 정기 의뢰') 'absent'
Assert-Case '2단: 위 present 케이스는 두 영역을 모두 읽었음' `
  (($script:questOcrCalls -join ',')) 'narrow,wide'
# 좁은 판독에서 이미 보이면 넓은 판독은 부르지 않습니다 (불필요한 캡처 비용 방지)
Invoke-QuestStateCase '•채집 장소 탐색 0/10' $true | Out-Null
Assert-Case '2단: 좁은 판독 성공이면 넓은 판독 생략' (($script:questOcrCalls -join ',')) 'narrow'

# 다른 창이 게임을 덮은 상태: 판독이 남의 창 글자여도 '없음'으로 확정하면 안 됨 (2026-08-07 실사고)
$script:mockGameFront = $false
# 게임 안에는 퀘스트가 멀쩡히 있는데(narrow) 화면은 다른 창이 덮은 상태 - 여기서 absent 로
# 확정하면 남의 채집을 망칩니다 (present 우선 비대칭 계약)
Set-MockQuestText -Narrow '•채집 장소 탐색 •사과 나무 채집 3/10'
$script:mockCoveredText = 'mabinogi_gui.ps1 GroupBox Label CheckBox RadioButton commit origin/main'
$script:mockHudVisible = $true
Assert-Case '퀘스트: 게임이 뒤에 있고 전면화도 실패 → unknown (완료로 안 셈)' (Get-LifeQuestState -Game $null) 'unknown'

# ②b 전면화 성공 후 재판독 (Focus-Game 이 실제로 전면화에 성공한 경우 - 본체 8178~8183).
# 예전 스텁은 이 경로를 한 번도 밟지 않아, 재판독 두 줄을 지워도 회귀가 초록이었습니다.
function Focus-Game { param($Game) $script:mockGameFront = $true }
$script:mockGameFront = $false
Set-MockQuestText -Narrow '' -Wide '•채집 장소 탐색 •백금 광맥 채집 2/10'
$script:mockCoveredText = '설정 저장 빌드 로그 커밋'
$script:questOcrCalls = @()
Assert-Case '전면화: 성공 후 재판독에서 퀘스트 발견 → present' (Get-LifeQuestState -Game $null) 'present'
Assert-Case '전면화: 재판독도 좁은→넓은 순서 (총 4회 판독)' `
  (($script:questOcrCalls -join ',')) 'narrow,wide,narrow,wide'
$script:mockGameFront = $false
Set-MockQuestText -Narrow '' -Wide ''
$script:mockCoveredText = '설정 저장 빌드 로그 커밋'
$script:mockHudVisible = $true
Assert-Case '전면화: 성공했는데 재판독도 비면 HUD 근거로 absent' (Get-LifeQuestState -Game $null) 'absent'
function Focus-Game { param($Game) }   # 원래 계약(전면화 성공 여부는 mockGameFront 로 제어)으로 복구
$script:mockGameFront = $true
$script:mockCoveredText = ''

# ── ③ 카운트 추출 (로그 보조) ──
Set-MockQuestText -Narrow '채집 장소 • 사과 나구 채집 4/10'
Assert-Case '카운트: 실측 4/10' (Get-LifeQuestCountText -Game $null) '4/10'
Set-MockQuestText -Narrow '모험가 길드의 정기 의뢰'
Assert-Case '카운트: 숫자 없음 → 빈 문자열' (Get-LifeQuestCountText -Game $null) ''

# ── ④ 대상 목록 행 조합 / 다중 스케일 탐색 (단어 OCR 스텁) ──
$script:wordsByScale = @{}
function Get-GameRegionOcrWords {
  param($Game, [int]$ReferenceX, [int]$ReferenceY, [int]$RegionWidth, [int]$RegionHeight, [int]$Scale, $Engine)
  if ($script:wordsByScale.ContainsKey([int]$Scale)) { return $script:wordsByScale[[int]$Scale] }
  return @()
}
# 행 조합: 같은 행(Y ±14)의 조각을 순서대로 붙이고, Lv 열(x>=1100)은 제외
$script:wordsByScale = @{
  4 = @(
    @{ Text = '사과'; X = 900; Y = 280 },
    @{ Text = '나무'; X = 958; Y = 281 },
    @{ Text = 'Lv.1'; X = 1150; Y = 280 },
    @{ Text = '차나무'; X = 930; Y = 371 }
  )
}
$rows = @(Get-LifeTargetRows -Game $null -Scale 4)
Assert-Case '행 조합: 행 수 (Lv 열 제외 후 2행)' $rows.Count '2'
Assert-Case '행 조합: 조각 결합 + Lv 미포함' ([string]$rows[0].Text) '사과나무'
Assert-Case '행 조합: 두 번째 행 분리 (Y 간격 90)' ('{0}@{1}' -f $rows[1].Text, $rows[1].Y) '차나무@371'
# GUI 실기 23:24 실사고: '뾰족 나무'의 두 단어가 Y 중심 1~2px 차이로 전역 정렬에서 뒤집혀
# '나무뾰족'으로 조합 → 정확 일치 전부 실패. 행 내 X 재정렬 계약 진리표
$script:wordsByScale = @{ 4 = @(
    @{ Text = '나무'; X = 880; Y = 304 },
    @{ Text = '뾰족'; X = 840; Y = 306 }
  ) }
$rows = @(Get-LifeTargetRows -Game $null -Scale 4)
Assert-Case '행 조합: Y 어긋난 두 단어도 행 내 X 순서로 결합 (실사고 재현)' ([string]$rows[0].Text) '뾰족나무'
Assert-Case "이름: 실측 이형 흰껍질나부 (나무→나부 깨짐)" (Test-LifeNameMatches -RowText '흰껍질나부' -TargetName '흰 껍질 나무') 'True'
# '나무→나부' 공통 규칙: 이형 미등록 대상도 판독 치환 사본으로 매칭 (리뷰 - 일부 등록의 빈틈)
Assert-Case "이름: 공통 규칙 뾰족나부 → 뾰족 나무" (Test-LifeNameMatches -RowText '뾰족나부' -TargetName '뾰족 나무') 'True'
Assert-Case "이름: 공통 규칙 나부 → 나무" (Test-LifeNameMatches -RowText '나부' -TargetName '나무') 'True'
Assert-Case "이름: 공통 규칙 오탐 방지 (차나부 ≠ 사과나무)" (Test-LifeNameMatches -RowText '차나부' -TargetName '사과나무') 'False'
Assert-Case "이름: 공통 규칙 + 이형 조합 (ÅI과나부 → 사과나무 이형)" (Test-LifeNameMatches -RowText 'ÅI과나부' -TargetName '사과 나무') 'True'
# 광석 계열 실측 깨짐 (2026-08-07 라운드 18: '운철'→'문철' 로 미발견)
Assert-Case "이름: 실측 이형 문철광맥 → 운철 광맥" (Test-LifeNameMatches -RowText '문철광맥' -TargetName '운철 광맥') 'True'
Assert-Case "이름: 실측 이형 으광맥 → 은 광맥" (Test-LifeNameMatches -RowText '으광맥' -TargetName '은 광맥') 'True'
Assert-Case "이름: 광석 이형이 다른 대상으로 번지지 않음" (Test-LifeNameMatches -RowText '문철광맥' -TargetName '은 광맥') 'False'
# 아래 탐색 케이스들이 쓰는 원래 모의 데이터 복원
$script:wordsByScale = @{
  4 = @(
    @{ Text = '사과'; X = 900; Y = 280 },
    @{ Text = '나무'; X = 958; Y = 281 },
    @{ Text = 'Lv.1'; X = 1150; Y = 280 },
    @{ Text = '차나무'; X = 930; Y = 371 }
  )
}
# 탐색 스캔 계약 (2026-08-06 속도 개선): s4→s5 판독 1벌로 찾기+행 증거(Rows) 동시 반환
$scan = Find-LifeTargetScan -Game $null -TargetName '사과나무'
Assert-Case '탐색: s4 에서 사과나무 → Y=280 + Rows 공유(2행)' ('{0}/r{1}' -f $scan.Y, @($scan.Rows).Count) '280/r2'
# 다중 스케일 폴백: s4 판독 실패(빈) → s5 에서 발견, Rows 는 첫 성공 스케일(s5) 결과
$script:wordsByScale = @{ 5 = @(@{ Text = '사과나무'; X = 930; Y = 282 }) }
$scan = Find-LifeTargetScan -Game $null -TargetName '사과나무'
Assert-Case '탐색: s4 실패 → s5 폴백' ('{0}/r{1}' -f $scan.Y, @($scan.Rows).Count) '282/r1'
# 이형 행도 탐색 성공
$script:wordsByScale = @{ 4 = @(@{ Text = '읽힌거미줄'; X = 930; Y = 642 }) }
Assert-Case '탐색: 이형 행(읽힌거미줄) → 얽힌 거미줄 매칭' ((Find-LifeTargetScan -Game $null -TargetName '얽힌 거미줄').Y) '642'
# 미발견 → Y=$null + 행 증거는 유지 (호출부가 끝 판정/스크롤에 사용)
$script:wordsByScale = @{ 4 = @(@{ Text = '차나무'; X = 930; Y = 371 }) }
$scan = Find-LifeTargetScan -Game $null -TargetName '사과나무'
Assert-Case '탐색: 미발견 → Y null + 행 증거 유지' ('{0}/r{1}' -f ($null -eq $scan.Y), @($scan.Rows).Count) 'True/r1'
# 전 스케일 빈 판독 → Rows 0 (호출부 탐색 중단 근거)
$script:wordsByScale = @{}
$scan = Find-LifeTargetScan -Game $null -TargetName '사과나무'
Assert-Case '탐색: 판독 전멸 → Rows 0' (@($scan.Rows).Count) '0'
# 순서 기반 위치 계산 (추수 밀/콩/쌀처럼 이름이 전혀 안 읽히는 대상 - 2026-08-07 실측)
$harvestOrder = @('밀', '옥수수', '콩', '쌀', '귀리')
$scan = Find-LifeTargetScan -Game $null -TargetName '밀' -Order $harvestOrder -FreshList
Assert-Case '탐색: 최상단 직후 순서 계산 - 밀(1번째) → y394' ('{0}/{1}' -f $scan.Y, $scan.Source) '394/index'
$scan = Find-LifeTargetScan -Game $null -TargetName '쌀' -Order $harvestOrder -FreshList
Assert-Case '탐색: 순서 계산 - 쌀(4번째) → y664' ('{0}/{1}' -f $scan.Y, $scan.Source) '664/index'
# FreshList 가 아니면(스크롤 뒤) 순서 계산 금지 - 첫 행 기준이 맞지 않음
$scan = Find-LifeTargetScan -Game $null -TargetName '밀' -Order $harvestOrder
Assert-Case '탐색: 스크롤 후에는 순서 계산 금지 → null' ($null -eq $scan.Y) 'True'
# 화면 밖(6번째 이상)은 계산해도 클릭 불가 → null
$scan = Find-LifeTargetScan -Game $null -TargetName '귀리' -Order $harvestOrder -FreshList
Assert-Case '탐색: 5번째(귀리) → y754 는 목록 밖이라 null' ($null -eq $scan.Y) 'True'

# ── ④b 목록 순서 격자 추론 (2026-08-06: WinRT OCR 이 1글자 '물'을 전 스케일에서 놓침) ──
$daily = @('둥지', '거미줄', '물', '우물', '젖소', '사과 나무', '차나무', '거미줄 뭉치', '헤이즐넛', '얽힌 거미줄')
# 실측 판독(01_초기 캡처): 둥지@394, 거미줄@484, 우물@665 - 물@574 만 누락
$realRows = @(@{ Text = '둥지'; Y = 394 }, @{ Text = '거미줄'; Y = 484 }, @{ Text = '우물'; Y = 665 })
$waterEstimate = Get-LifeTargetRowByOrder -Rows $realRows -Order $daily -TargetName '물'
Assert-Case '격자: 실측 누락 행(물) 추론 → 574 + 앵커 3개(강한 신뢰도)' ('{0}/a{1}' -f $waterEstimate.Y, $waterEstimate.AnchorCount) '574/a3'
Assert-Case '격자: 판독된 대상은 그대로 (우물)' ((Get-LifeTargetRowByOrder -Rows $realRows -Order $daily -TargetName '우물').Y) '665'
# 앵커 2개면 약한 추론 (상세 제목 확인 없이는 진행 금지 계약)
$twoAnchors = @(@{ Text = '둥지'; Y = 394 }, @{ Text = '거미줄'; Y = 484 })
Assert-Case '격자: 앵커 2개 → 약한 추론 표시' ((Get-LifeTargetRowByOrder -Rows $twoAnchors -Order $daily -TargetName '물').AnchorCount) '2'
# 아이콘 조각이 붙은 행('4거미줄')도 앵커로 인정해야 신뢰도가 확보됨 (라운드 7 실측)
$noisyRows = @(@{ Text = '등지'; Y = 394 }, @{ Text = '4거미줄'; Y = 484 }, @{ Text = '우물'; Y = 665 })
$noisyEstimate = Get-LifeTargetRowByOrder -Rows $noisyRows -Order $daily -TargetName '물'
Assert-Case '격자: 잡음 섞인 행도 앵커 인정 → 앵커 3개' ('{0}/a{1}' -f $noisyEstimate.Y, $noisyEstimate.AnchorCount) '574/a3'
# ── 최상단 판정 (Test-LifeListAtTop - 2026-08-12 실사고: 첫 항목 '광맥'이 '과D테'로
#    깨지는 창에서 이름 근거가 죽어 매 회전 헛드래그 → 앵커 기하 근거 추가) ──
$miningOrderFull = @('광맥', '철 광맥', '얼음', '석탄 광맥', '동 광맥', '백동 광맥', '은 광맥', '운철 광맥', '백금 광맥')
$topSceneRows = @(
  @{ Text = '광석캐기'; Y = 178 }, @{ Text = '곡괭이로광맥을개서쓸만한광석을찾습니다.'; Y = 212 },
  @{ Text = 'Lv.3730,342'; Y = 316 },
  @{ Text = '과D테'; Y = 394 }, @{ Text = '철광맥'; Y = 484 }, @{ Text = '어므'; Y = 574 }, @{ Text = '석탄광맥'; Y = 664 })
Assert-Case '최상단: 실사고 배치(헤더 3행 포함, 첫 항목 오독) → 앵커 기하로 인정' `
  (Test-LifeListAtTop -Rows $topSceneRows -Order $miningOrderFull) 'True'
# ↑ 이 케이스가 헤더 필터 회귀를 잡는다: 설명 행 '…광맥을…'(Y212)을 안 거르면 포함 매칭
#   앵커(idx0@212)가 간격 사슬을 깨 추론 전체가 null → false 가 된다 (교차 리뷰 반례).
Assert-Case '최상단: 한 행 스크롤 화면 → 거짓 (역산 원점 304)' `
  (Test-LifeListAtTop -Rows @(@{ Text = '철광맥'; Y = 394 }, @{ Text = '석탄광맥'; Y = 574 }) -Order $miningOrderFull) 'False'
Assert-Case '최상단: 첫 항목이 정상 판독되면 이름 근거로 참' `
  (Test-LifeListAtTop -Rows @(@{ Text = '광맥'; Y = 394 }) -Order $miningOrderFull) 'True'
Assert-Case '최상단: 경계 - 역산 원점 382(-12)는 참' `
  (Test-LifeListAtTop -Rows @(@{ Text = '철광맥'; Y = 472 }, @{ Text = '석탄광맥'; Y = 652 }) -Order $miningOrderFull) 'True'
Assert-Case '최상단: 경계 - 역산 원점 381(-13)은 거짓' `
  (Test-LifeListAtTop -Rows @(@{ Text = '철광맥'; Y = 471 }, @{ Text = '석탄광맥'; Y = 651 }) -Order $miningOrderFull) 'False'
Assert-Case '최상단: Order 없음 → 거짓' (Test-LifeListAtTop -Rows $topSceneRows -Order @()) 'False'

# 포함 매칭이 긴 이름 우선이어야 '거미줄 뭉치'가 '거미줄'로 잡히지 않음
$bundleRows = @(@{ Text = '거미줄뭉치'; Y = 461 }, @{ Text = '헤이즐넛'; Y = 551 })
Assert-Case '격자: 거미줄 뭉치 행은 뭉치로 인식 (앞 항목 추론 정확)' `
  ((Get-LifeTargetRowByOrder -Rows $bundleRows -Order $daily -TargetName '차나무').Y) '371'
# 앵커 1개면 추론 금지 (오클릭 방지)
Assert-Case '격자: 앵커 1개 → null' ($null -eq (Get-LifeTargetRowByOrder -Rows @(@{ Text = '둥지'; Y = 394 }) -Order $daily -TargetName '물')) 'True'
# 간격 불일치(스크롤 중 판독 등) → 추론 금지
$badRows = @(@{ Text = '둥지'; Y = 394 }, @{ Text = '거미줄'; Y = 520 })
Assert-Case '격자: 간격 불일치 → null' ($null -eq (Get-LifeTargetRowByOrder -Rows $badRows -Order $daily -TargetName '물')) 'True'
# 화면 밖 추론 → null (스크롤 필요)
$topRows = @(@{ Text = '둥지'; Y = 200 }, @{ Text = '거미줄'; Y = 290 })
Assert-Case '격자: 화면 밖(위) 추론 → null' ($null -eq (Get-LifeTargetRowByOrder -Rows $topRows -Order $daily -TargetName '얽힌 거미줄')) 'True'
# 이형 판독 앵커도 인정 (읽힌거미줄 → 얽힌 거미줄)
$variantRows = @(@{ Text = '헤이즐넛'; Y = 460 }, @{ Text = '읽힌거미줄'; Y = 550 })
Assert-Case '격자: 이형 앵커로 앞 항목 추론 (거미줄 뭉치)' ((Get-LifeTargetRowByOrder -Rows $variantRows -Order $daily -TargetName '거미줄 뭉치').Y) '370'
Assert-Case '격자: 목록에 없는 대상 → null' ($null -eq (Get-LifeTargetRowByOrder -Rows $realRows -Order $daily -TargetName '광맥')) 'True'

# ── ④c 생활 창 X 픽셀 판별 진리표 (흐름캡처 6장 실측 색상) ──
function New-PixelColor { param([int]$R, [int]$G, [int]$B) return [System.Drawing.Color]::FromArgb($R, $G, $B) }
Add-Type -AssemblyName System.Drawing
# 캡처 1 (내정보): 교차점 흰색 + 여백 남색 → 열림
Assert-Case '창판별: 내정보(캡처1) → 열림' (Test-LifeWindowClosePixels `
  -CrossA (New-PixelColor 250 249 254) -CrossB (New-PixelColor 255 255 251) `
  -SideA (New-PixelColor 12 23 45) -SideB (New-PixelColor 13 24 44)) 'True'
# 캡처 2 (생활 스킬창): 교차점 흰색 + 여백 검정 → 열림
Assert-Case '창판별: 스킬창(캡처2) → 열림' (Test-LifeWindowClosePixels `
  -CrossA (New-PixelColor 255 255 255) -CrossB (New-PixelColor 255 255 255) `
  -SideA (New-PixelColor 1 2 6) -SideB (New-PixelColor 1 2 6)) 'True'
# 캡처 4 (필드 - 미니맵): 교차점 한 점 어두움 + 여백 밝음 → 닫힘 (이중 탈락)
Assert-Case '창판별: 필드(캡처4) → 닫힘' (Test-LifeWindowClosePixels `
  -CrossA (New-PixelColor 35 44 43) -CrossB (New-PixelColor 252 255 255) `
  -SideA (New-PixelColor 135 141 77) -SideB (New-PixelColor 40 48 51)) 'False'
# 캡처 5 (필드 - 초록 지형): 전부 초록 → 닫힘
Assert-Case '창판별: 필드(캡처5) → 닫힘' (Test-LifeWindowClosePixels `
  -CrossA (New-PixelColor 171 209 96) -CrossB (New-PixelColor 168 206 95) `
  -SideA (New-PixelColor 170 209 100) -SideB (New-PixelColor 19 42 34)) 'False'
# 2차 실기 22:51:46 (미선택 스킬창 - 반투명 배경에 필드 비침, 여백 G103): 상대 대비로 열림
Assert-Case '창판별: 미선택 스킬창(실기 s46 - 비침 배경) → 열림' (Test-LifeWindowClosePixels `
  -CrossA (New-PixelColor 255 255 255) -CrossB (New-PixelColor 255 255 255) `
  -SideA (New-PixelColor 49 96 62) -SideB (New-PixelColor 52 103 67)) 'True'
# 2차 실기 22:51:19 (필드 - 창 닫힌 직후): 교차점부터 어긋남 → 닫힘
Assert-Case '창판별: 필드(실기 s19) → 닫힘' (Test-LifeWindowClosePixels `
  -CrossA (New-PixelColor 65 118 46) -CrossB (New-PixelColor 49 118 49) `
  -SideA (New-PixelColor 158 200 84) -SideB (New-PixelColor 45 52 57)) 'False'
# 경계: 교차점만 밝고 여백도 밝음 (흰 화면 전체) → 닫힘 (상대 대비 요구)
Assert-Case '창판별: 전체 흰 화면 → 닫힘' (Test-LifeWindowClosePixels `
  -CrossA (New-PixelColor 255 255 255) -CrossB (New-PixelColor 255 255 255) `
  -SideA (New-PixelColor 255 255 255) -SideB (New-PixelColor 255 255 255)) 'False'

# ── ⑤ 사이클 시뮬레이션 (자식 프로세스 - 종료 코드 x 호출 궤적 매트릭스) ──
$simPath = Join-Path $PSScriptRoot 'sim_life_cycle.ps1'
function Invoke-CycleSim {
  param([string]$Scenario)
  $simOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $simPath -Scenario $Scenario 2>&1
  return @{
    Exit = $LASTEXITCODE
    Menu = @($simOut | Where-Object { "$_" -match '^MENU#' }).Count
    State = @($simOut | Where-Object { "$_" -match '^STATE#' }).Count
    Out = $simOut
  }
}
$sim = Invoke-CycleSim 'unsupported-skill'
Assert-Case '사이클: 미지원 스킬(낚시) → exit 4, 메뉴 미진입' ('{0}/m{1}' -f $sim.Exit, $sim.Menu) '4/m0'
$sim = Invoke-CycleSim 'process-content'
Assert-Case '사이클: 가공 콘텐츠 → exit 4' $sim.Exit '4'
$sim = Invoke-CycleSim 'menu-fail'
Assert-Case '사이클: 메뉴 3회 실패 → exit 4 (재시도 3회 소진)' ('{0}/m{1}' -f $sim.Exit, $sim.Menu) '4/m3'
# STATE 수 = 초기 확인분 + 생성 확인분 + 대기 판독분 (완료 판정 전 전면화 재확인은 제거됨)
$sim = Invoke-CycleSim 'happy'
Assert-Case '사이클: 정상 (초기 3회 + 생성 확인 2회 + absent 3연속) → exit 0' ('{0}/m{1}/s{2}' -f $sim.Exit, $sim.Menu, $sim.State) '0/m1/s8'
$sim = Invoke-CycleSim 'confirm-retry'
Assert-Case '사이클: 생성 미확인 → 메뉴 재시도 후 성공 → exit 0' ('{0}/m{1}/s{2}' -f $sim.Exit, $sim.Menu, $sim.State) '0/m2/s16'
$sim = Invoke-CycleSim 'resume'
Assert-Case '사이클: 기존 퀘스트 이어가기 (메뉴 생략) → exit 0' ('{0}/m{1}/s{2}' -f $sim.Exit, $sim.Menu, $sim.State) '0/m0/s4'
# 형제 대상 퀘스트를 자기 것으로 인수하면 안 됨 (빈 사이클을 완료로 계상 - 2026-08-07 감사)
# 2026-08-08 실사고: 마지막 개를 채우는 순간 트래커가 사라져 폴링이 '10/10' 을 못 봅니다.
# 마지막 판독이 '9/10' 이어도 완료 로그에는 목표 개수 10 이 찍혀야 합니다.
$sim = Invoke-CycleSim 'goal-count'
Assert-Case '사이클: 마지막 판독 9/10 이어도 완료 로그는 목표 10개' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '1사이클 완료 - 일상 채집 / 사과나무 10개' }).Count -ge 1)) 'True'
Assert-Case '사이클: 분모 노이즈(0/1)가 섞여도 합의로 10 채택' ($sim.Exit) '0'
# 분모를 한 번도 못 읽으면 목표를 단정하지 않고 '마지막 판독'임을 밝힙니다
$sim = Invoke-CycleSim 'goal-unknown'
Assert-Case '사이클: 목표를 못 읽으면 마지막 판독으로 표기' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '마지막 판독 2개' }).Count -ge 1)) 'True'
$sim = Invoke-CycleSim 'resume-sibling'
Assert-Case "사이클: '우물' 퀘스트를 목표 '물' 이 인수하지 않음 (대기 후 메뉴 진행)" ('{0}/m{1}' -f $sim.Exit, $sim.Menu) '0/m1'
Assert-Case '사이클: 다른 대상 대기 로그' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '다른 대상의 채집이 진행 중' }).Count -ge 1)) 'True'
# 2026-08-14 실사고 (계약 반전): 이름 미확정 잔존 퀘스트를 '내 것'으로 인수해 그 소멸만으로
# 빈 사이클 3건을 완료로 계상. 이제 미확정은 '다른 대상'과 동일 - 대기 후 메뉴로 새로 시작
$sim = Invoke-CycleSim 'resume-unreadable'
Assert-Case '사이클: 이름 미확정 잔존은 인수하지 않음 - 대기 후 메뉴로 새로 시작 → exit 0' ('{0}/m{1}' -f $sim.Exit, $sim.Menu) '0/m1'
Assert-Case '사이클: 미확정 잔존 안내 로그 (새로 시작 방침 명시)' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '끝나기를 기다린 뒤 새로 시작합니다' }).Count -ge 1)) 'True'
$sim = Invoke-CycleSim 'resume-unreadable-stuck'
Assert-Case '사이클: 미확정 잔존이 안 끝나면 메뉴 미진입 조건부 정지 → exit 4 (명시적 안전 정지 계약 - Codex 합의)' `
  ('{0}/m{1}' -f $sim.Exit, $sim.Menu) '4/m0'
# 게임플레이 화면을 확정 못 하면 입력하지 않고 정지 (로딩/다른 화면에서 메뉴를 열면 사고)
$sim = Invoke-CycleSim 'start-unknown'
Assert-Case '사이클: 초기 확인이 전부 unknown → exit 4, 메뉴 미진입' ('{0}/m{1}' -f $sim.Exit, $sim.Menu) '4/m0'
$sim = Invoke-CycleSim 'unknown-reset'
Assert-Case '사이클: unknown 이 absent 연속 카운트를 리셋' ('{0}/s{1}' -f $sim.Exit, $sim.State) '0/s7'
$sim = Invoke-CycleSim 'deadline'
Assert-Case '사이클: 한도 초과 → exit 4' $sim.Exit '4'
Assert-Case '사이클: 한도 초과 안내는 진행 없음을 밝힘' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '채집 진행이 .*초 동안 없었습니다' }).Count -ge 1)) 'True'
# 2026-08-07 실사고: 채집 3/10 진행 중 RDP 창 최소화로 16분간 캡처 실패 → 한도 초과.
# 로그에는 '채집 대기를 늘려 주세요'만 남아 원인을 오인했습니다 (실제로는 화면 미표시)
# 진행이 있으면 총 시간이 한도를 넘어도 자르지 않습니다 (2026-08-08 사용자 지적: "잘 캐고
# 있는데 왜 잘리나"). 진행 인정이 빠지면 아래는 exit 4 로 떨어집니다.
$sim = Invoke-CycleSim 'progress-extends'
Assert-Case '사이클: 수량이 늘면 한도를 다시 재고 완료 → exit 0' $sim.Exit '0'
# 판독 노이즈('6→0→6')는 진행이 아님 - 본 적 있는 최댓값만 기준
$sim = Invoke-CycleSim 'progress-noise-not-extends'
Assert-Case '사이클: 수량 노이즈는 한도를 되살리지 않음 → exit 4' $sim.Exit '4'
Assert-Case '사이클: 정지 안내에 마지막 진행 수량 표기' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '마지막 진행 6개' }).Count -ge 1)) 'True'
# 절대 상한(무인 백스톱) - 수량이 계속 올라도 결국 멈춥니다
$sim = Invoke-CycleSim 'hard-cap'
Assert-Case '사이클: 절대 상한 초과 → exit 4' $sim.Exit '4'
Assert-Case '사이클: 절대 상한 안내는 진행이 있었음을 밝힘' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '절대 상한' }).Count -ge 1)) 'True'
$sim = Invoke-CycleSim 'deadline-capture-fail'
Assert-Case '사이클: 캡처 실패 중 한도 초과 → exit 4' $sim.Exit '4'
Assert-Case '사이클: 캡처 실패 중 한도 초과는 화면 원인으로 안내' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '화면이 그려지지 않는' }).Count -ge 1)) 'True'
Assert-Case '사이클: 캡처 실패 중 한도 초과에 채집 대기 안내 금지 (원인 오인 방지)' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '채집 진행이 .*초 동안 없었습니다' }).Count -eq 0)) 'True'
# 2026-08-07 실사고: 곤충 채집 '일렁이는 빛 무리'(레벨 27 이상, 캐릭터 25)가 링크를 눌러도
# 퀘스트가 안 생겨 3회 소진 - 원인이 화면에만 남아 로그로는 알 수 없었습니다
$sim = Invoke-CycleSim 'menu-fail-level'
# s26 = 초기 확인 2회 + (생성 확인 8회 x 3회차) - 확인 회수가 줄면 여기서 잡힙니다
Assert-Case '사이클: 링크까지 성공했는데 퀘스트 미생성 3회 → exit 4' ('{0}/m{1}/s{2}' -f $sim.Exit, $sim.Menu, $sim.State) '4/m3/s26'
Assert-Case '사이클: 레벨 미달 추정 시 안내에 요구 레벨 포함' `
  ([bool](@($sim.Out | Where-Object { "$_" -match "곤충 채집 레벨 27 이상" }).Count -ge 1)) 'True'
# 캡처 실패 복구 탐침 (2026-08-07 실사고의 근본 원인 - 리뷰 지적):
# 대기 지점들이 캡처를 아예 시도하지 않아 화면이 돌아와도 플래그가 안 풀렸습니다.
# 탐침이 빠지면 아래는 exit 0 이 아니라 exit 4(한도 초과)가 됩니다.
$sim = Invoke-CycleSim 'capture-recover'
Assert-Case '사이클: 캡처 실패 후 복구되면 이어서 완료 → exit 0' $sim.Exit '0'
Assert-Case '사이클: 복구까지 캡처 탐침 정확히 2회 (일회성 장애)' `
  (@($sim.Out | Where-Object { "$_" -match '^PROBE#' }).Count) '2'
# 지정 시간(시간 지정 모드) 동작 시나리오 (2026-08-11 실측 ① 대응 - 배선 가드는 위 별도 섹션)
$sim = Invoke-CycleSim 'until-expired'
Assert-Case '사이클: 지정 시간이 이미 지나면 즉시 exit 4, 메뉴 미진입' ('{0}/m{1}' -f $sim.Exit, $sim.Menu) '4/m0'
Assert-Case '사이클: 지정 시간 사유 로그 (시작 즉시)' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '지정 시간\(00:00\) 도달' }).Count -ge 1)) 'True'
$sim = Invoke-CycleSim 'until-mid-wait'
Assert-Case '사이클: 채집 대기 중 지정 시간 도달 → exit 4' ($sim.Exit) '4'
Assert-Case '사이클: 대기 중 도달 사유가 한도가 아니라 지정 시간' `
  ([bool](@($sim.Out | Where-Object { "$_" -match '지정 시간\(00:01\) 도달' }).Count -ge 1)) 'True'

# ── ⑥ 스킬 테이블/이형 데이터 가드 ──
$expectedSkillKeys = @('daily', 'wood', 'mining', 'herb', 'wool', 'harvest', 'hoe', 'insect')
Assert-Case '테이블: 지원 8종 (2026-08-07 양털·추수·호미질·곤충 추가)' (($lifeSkillMenuTable.Keys | Sort-Object) -join ',') (($expectedSkillKeys | Sort-Object) -join ',')
Assert-Case '테이블: 8열 그리드 5~8번째 셀 (실측 755/884/1014/1143)' `
  ('{0},{1},{2},{3}' -f $lifeSkillMenuTable['wool'].Cell[0], $lifeSkillMenuTable['harvest'].Cell[0], `
    $lifeSkillMenuTable['hoe'].Cell[0], $lifeSkillMenuTable['insect'].Cell[0]) '755,884,1014,1143'
# '무리'→'부리' 공통 깨짐 (곤충 채집 실측 - 설원빛부리/고요한빛부리)
Assert-Case "이름: 공통 규칙 설원빛부리 → 설원 빛 무리" (Test-LifeNameMatches -RowText '설원빛부리' -TargetName '설원 빛 무리') 'True'
Assert-Case "이름: 공통 규칙 고요한빛부리 → 고요한 빛 무리" (Test-LifeNameMatches -RowText '고요한빛부리' -TargetName '고요한 빛 무리') 'True'
# 한 행에 깨짐이 둘 겹치는 실측 (황폐한곤춤부리 = 곤춤 + 부리) - 개별 치환만으로는 못 잡음
Assert-Case "이름: 복합 깨짐 황폐한곤춤부리 → 황폐한 곤충 무리" (Test-LifeNameMatches -RowText '황폐한곤춤부리' -TargetName '황폐한 곤충 무리') 'True'
Assert-Case "이름: 단일 깨짐 삭막한곤충부리 → 삭막한 곤충 무리" (Test-LifeNameMatches -RowText '삭막한곤충부리' -TargetName '삭막한 곤충 무리') 'True'
Assert-Case "이름: 복합 치환이 다른 대상까지 통과시키지 않음" (Test-LifeNameMatches -RowText '황폐한곤춤부리' -TargetName '삭막한 곤충 무리') 'False'
# '벼'→'斟'(한자) 실측 (2026-08-14 네이티브 1908 - 나무 베기 스크롤 탐색이 목록 끝까지 미발견)
Assert-Case "이름: 이형 斟락나무 → 벼락 나무" (Test-LifeNameMatches -RowText '斟락나무' -TargetName '벼락 나무') 'True'
Assert-Case "이름: 斟락나무가 다른 나무를 통과시키지 않음" (Test-LifeNameMatches -RowText '斟락나무' -TargetName '어스름 나무') 'False'
# '일렁'→'일럼' 실측 (2026-08-08 레벨 해금 후 첫 시도에서 발견 - s3~s6 전 배율에서 일관)
Assert-Case "이름: 공통 규칙 일럼이는빛무리 → 일렁이는 빛 무리" (Test-LifeNameMatches -RowText '일럼이는빛무리' -TargetName '일렁이는 빛 무리') 'True'
Assert-Case "이름: 복합(일럼+부리) → 일렁이는 빛 무리" (Test-LifeNameMatches -RowText '일럼이는빛부리' -TargetName '일렁이는 빛 무리') 'True'
Assert-Case "이름: '일럼' 치환이 다른 대상을 통과시키지 않음" (Test-LifeNameMatches -RowText '일럼이는빛무리' -TargetName '빛 무리') 'False'
# 약초 Sig 의 '버섯'은 호미질 '개암 버섯' 추가로 더는 고유 조각이 아님 (오확정 위험)
Assert-Case '테이블: 약초 Sig 에 버섯 없음 (호미질과 겹침)' `
  ([bool](@($lifeSkillMenuTable['herb'].Sig) -contains '버섯')) 'False'
# 각 스킬의 Sig 조각이 다른 스킬의 대상 이름에 들어 있으면 오확정 위험 - 전 조합 대조
$sigCollisions = @()
foreach ($skillKey in $lifeSkillMenuTable.Keys) {
  foreach ($sigPiece in @($lifeSkillMenuTable[$skillKey].Sig)) {
    foreach ($otherKey in $lifeSkillMenuTable.Keys) {
      if ($otherKey -eq $skillKey) { continue }
      foreach ($otherTarget in @($lifeSkillMenuTable[$otherKey].Order)) {
        if ((Get-LifeNormalizedName $otherTarget).Contains($sigPiece)) { $sigCollisions += "$skillKey/$sigPiece↔$otherKey/$otherTarget" }
      }
    }
  }
}
Assert-Case '테이블: Sig 조각이 다른 스킬 대상과 겹치지 않음' ($sigCollisions -join ' | ') ''
# 이형 표 충돌 대조 (2026-08-08 실측 제목 이형 13건은 별도 표로 분리 - 깨짐 문자열을 그대로 등록했으므로
# 하나의 이형이 두 대상을 가리키거나, 다른 대상의 정식 이름과 겹치면 오채집으로 직결)
$variantOwners = @{}
$variantCollisions = @()
$allTargetNames = @()
foreach ($skillKey in $lifeSkillMenuTable.Keys) {
  foreach ($targetName in @($lifeSkillMenuTable[$skillKey].Order)) { $allTargetNames += , (Get-LifeNormalizedName $targetName) }
}
foreach ($canonical in $lifeTargetVariants.Keys) {
  foreach ($variant in @($lifeTargetVariants[$canonical])) {
    if ($variantOwners.ContainsKey($variant)) { $variantCollisions += "$variant → $($variantOwners[$variant]) / $canonical" }
    else { $variantOwners[$variant] = $canonical }
    if ($allTargetNames -contains $variant) { $variantCollisions += "$variant 는 다른 대상의 정식 이름" }
  }
}
Assert-Case '테이블: 이형 하나가 두 대상을 가리키지 않음' ($variantCollisions -join ' | ') ''
# 제목 전용 이형은 공용 표를 오염시키면 안 됩니다 - 목록 행 선택과 퀘스트 소유 판정이
# 공용 표를 쓰는데, 퀘스트 쪽은 Contains 비교라 깨짐 문자열이 섞이면 오클릭/오인수가 됩니다
$titleOnlyLeak = @()
foreach ($canonical in $lifeTitleVariants.Keys) {
  foreach ($variant in @($lifeTitleVariants[$canonical])) {
    # 자기 대상과도, 다른 어떤 대상과도 공용 매칭에 걸리면 안 됩니다 (공용 표 오염 = 오클릭)
    foreach ($anyTarget in $allTargetNames) {
      if (Test-LifeNameMatches -RowText $variant -TargetName $anyTarget) { $titleOnlyLeak += "$variant ↔ $anyTarget" }
    }
    # 제목 매칭에서는 반드시 자기 대상 하나만 걸려야 합니다
    $titleHits = @()
    foreach ($anyTarget in $allTargetNames) {
      if (Test-LifeTitleNameMatches -Title $variant -TargetName $anyTarget) { $titleHits += $anyTarget }
    }
    if (($titleHits -join ',') -ne $canonical) { $titleOnlyLeak += "$variant → [$($titleHits -join ',')] 기대 [$canonical]" }
  }
}
Assert-Case '분리: 제목 이형이 공용 매칭에 새지 않고, 제목 매칭에서 자기 대상만 걸림' ($titleOnlyLeak -join ' | ') ''
$titleVariantCollisions = @()
$titleVariantOwners = @{}
foreach ($canonical in $lifeTitleVariants.Keys) {
  foreach ($variant in @($lifeTitleVariants[$canonical])) {
    if ($titleVariantOwners.ContainsKey($variant)) { $titleVariantCollisions += "$variant → $($titleVariantOwners[$variant]) / $canonical" }
    else { $titleVariantOwners[$variant] = $canonical }
    if ($allTargetNames -contains $variant) { $titleVariantCollisions += "$variant 는 다른 대상의 정식 이름" }
  }
}
Assert-Case '테이블: 제목 이형 하나가 두 대상을 가리키지 않음' ($titleVariantCollisions -join ' | ') ''
# 실측 이형이 실제로 자기 대상으로 매칭되는지 (등록만 하고 규칙에 안 걸리면 무의미)
foreach ($variantCase in @(
    @('헤OI즐넛', '헤이즐넛'), @('H*락나무', '벼락 나무'), @('호발꽃', '화살꽃'),
    @('고十OH', '광맥'), @('으과DH', '은 광맥'), @('A-IEY광DH', '석탄 광맥'),
    @('도과DH', '동 광맥'), @('BHE고十DH', '백동 광맥'), @('BHZ고十DH', '백금 광맥'),
    @('고스0', '곱슬 양'), @('04기르0', '먹구름 양'), @('=츹', '끈기 풀'), @('0홀', '양'))) {
  Assert-Case "제목이형(실측): '$($variantCase[0])' → $($variantCase[1])" `
    (Test-LifeTitleNameMatches -Title $variantCase[0] -TargetName $variantCase[1]) 'True'
}
Assert-Case "이름: 무리 규칙이 다른 대상으로 번지지 않음" (Test-LifeNameMatches -RowText '설원빛부리' -TargetName '곤충 무리') 'False'
Assert-Case "이름: 실측 이형 파스님 → 파스닙" (Test-LifeNameMatches -RowText '파스님' -TargetName '파스닙') 'True'
Assert-Case '테이블: 추수 Order 는 밀→귀리 순서 (인덱스 계산 근거)' `
  ((@($lifeSkillMenuTable['harvest'].Order) -join ',')) '밀,옥수수,콩,쌀,귀리'
foreach ($skillKey in $expectedSkillKeys) {
  $entry = $lifeSkillMenuTable[$skillKey]
  $cellOk = (@($entry.Cell).Count -eq 2 -and [int]$entry.Cell[0] -gt 0 -and [int]$entry.Cell[0] -lt 1272 -and
             [int]$entry.Cell[1] -gt 0 -and [int]$entry.Cell[1] -lt 717)
  Assert-Case "테이블: $skillKey 셀 좌표/시그니처 유효" ('{0}/{1}' -f $cellOk, (@($entry.Sig).Count -ge 2)) 'True/True'
}
foreach ($variantKey in $lifeTargetVariants.Keys) {
  Assert-Case "이형: '$variantKey' 정규화(공백 없음) + 배열" ('{0}/{1}' -f ($variantKey -notmatch '\s'), (@($lifeTargetVariants[$variantKey]).Count -ge 1)) 'True/True'
}

# ── ⑦ 배선/설정 가드 (소스 텍스트 + config + GUI) ──
$workerText = [IO.File]::ReadAllText($workerPath)
Assert-Case '배선: 메인 흐름 life 분기 존재' ($workerText -match "if \(\`$mainCategory -eq 'life'\) \{\s*\r?\n\s*Invoke-LifeGatherCycle -Game \`$game") 'True'
# 생활 분기는 Clear-EventOverlay(생활 창을 알 수 없는 화면으로 오판 가능)보다 앞이어야 함 - 리뷰 조건
$lifeBranchIndex = $workerText.IndexOf('Invoke-LifeGatherCycle -Game $game')
$eventOverlayIndex = $workerText.IndexOf('if (Clear-EventOverlay -Game $game)')
Assert-Case '배선: 생활 분기가 메인 이벤트 정리보다 앞' (($lifeBranchIndex -ge 0) -and ($eventOverlayIndex -gt $lifeBranchIndex)) 'True'
Assert-Case '배선: 사이클 초입 생활 창 정리 → 이벤트 정리 순서' ($workerText -match '\[void\]\(Close-LifeOpenWindows -Game \$Game\)\s*\r?\n\s*\[void\]\(Clear-EventOverlay -Game \$Game\)') 'True'
# 초기 확인 루프에도 팝업 방어를 넣었습니다 - 공지 게시판이 트래커를 가리면 진행 중인 채집을
# absent 로 확정해 메뉴를 열어 버렸습니다 (2026-08-07 감사)
Assert-Case '배선: 생활 공지 게시판 팝업 처리 3곳(초기 확인+메뉴 루프+대기 루프)' ([regex]::Matches($workerText, "\[생활\] 공지 게시판 팝업 감지").Count) '3'
# 완료 로그에 무엇을 캤는지 남깁니다 (2026-08-08 사용자 요청 - 여러 대상을 번갈아 돌리면
# 로그만 봐서는 구분이 안 됨). 수량은 '본 적 있는 최댓값'이라 마지막 판독 노이즈에 안 흔들림
Assert-Case '배선: 완료 로그에 스킬·대상·수량 표기' `
  ([bool]($workerText -match "\[완료\] 채집 1사이클 완료 - \`$\(\[string\]\`$skillEntry\.Name\) / \`$lifeTargetName\`$\{doneCount\}")) 'True'
# 완료 수량은 '마지막으로 본 수량'이 아니라 '목표 개수'입니다 - 마지막 개를 채우는 순간
# 트래커가 사라져 폴링이 그 프레임을 놓치기 때문 (2026-08-08 사용자 제보: '9개' 로 표기)
Assert-Case '배선: 완료 수량은 목표 개수(분모) 합의 기준' `
  ([bool]($workerText -match '\$goalCount = Get-LifeQuestGoalConsensus -GoalCounts \$progressGoalCounts')) 'True'
Assert-Case '배선: 목표를 못 읽으면 마지막 판독임을 밝힘' `
  ([bool]($workerText -match '마지막 판독 \$\{progressMaxCount\}개')) 'True'
# 한도는 '진행이 멈춘 시간' - 수량이 늘면 다시 잽니다 + 절대 상한 백스톱
Assert-Case '배선: 수량 최댓값 갱신 시 한도 재설정' `
  ([bool]($workerText -match "\`$progressMaxCount = \`$countValue\s*\r?\n\s*\`$progressDeadline = \(Get-Date\)\.AddSeconds\(\`$lifeGatherWait\)")) 'True'
Assert-Case '배선: 절대 상한 3600초 백스톱' ([bool]($workerText -match '\$lifeGatherHardCapSeconds = 3600')) 'True'
Assert-Case '배선: 캡처 실패 대기에도 사이클 한도 적용' ($workerText.Contains('화면 캡처 실패가 지속돼 사이클 한도')) 'True'
# 캡처 실패 중 대기하는 지점은 전부 복구 탐침을 돌려야 합니다 (초기 확인 / 이전 퀘스트 대기 /
# 메뉴 캡처 대기 / 채집 대기 4곳). 하나라도 빠지면 그 경로는 복구를 영영 감지 못 합니다
# 9곳 = 생활 5곳(사이클 4 + Wait-LifeCaptureAlive 1) + 던전·사냥터 4곳.
# ★ 뒤의 4곳은 2026-08-09 7차 점검에서 발견한 **기존 자기 잠금**입니다. 전부 회전을
#   Start-Sleep 으로 시작해 캡처 실패 시 continue 하는데, 그러면 그 회전에 캡처 시도가 0이라
#   플래그가 영영 안 풀리고 바로 다음 줄이 한도를 40초로 되돌려 무한 회전이었습니다
#   (채집에서 2026-08-07 에 고친 것과 같은 형태가 던전/사냥터에 남아 있었음).
Assert-Case '배선: 캡처 실패 대기 복구 탐침 11곳 (생활 5 + 던전·사냥터 4 + 어비스 파티원 1 + 검증 종료 루프 1)' `
  ([regex]::Matches($workerText, '\[void\]\(Test-CaptureRecovered -Game \$Game\)').Count) '11'
# 메뉴 시퀀스의 판독+입력 구간(목록 정렬 / 대상 탐색)도 캡처가 살아 있을 때만 진행해야 합니다.
# 없으면 0행 판독을 '목록 소멸'로 오인해 미발견 정지(exit 4)로 직행합니다 (2026-08-07 감사 high)
Assert-Case '배선: 판독 앞 캡처 생존 대기 3곳(빠른 확인/정렬/탐색)' `
  ([regex]::Matches($workerText, 'Wait-LifeCaptureAlive -Game \$Game -Deadline \$Deadline').Count) '3'
# 클릭 직전에는 플래그를 믿지 말고 새로 캡처해야 합니다 - 판독 후 화면이 멈추면 플래그는
# 정상으로 남아 있어 안 보이는 곳을 누르게 됩니다 (2026-08-07 리뷰 지적)
# 깊은 재확인이 돌았으면 '마지막 프레임'에서 링크·제목을 다시 얻고 첫 프레임과 같은 팝업인지
# 확인해야 합니다 - 좌표만 갱신하면 'A 팝업 판정으로 B 팝업 클릭' 이 됩니다 (리뷰 지적)
Assert-Case '배선: 깊은 재확인 후 마지막 프레임에서 링크 재취득' `
  ([bool]($workerText -match 'if \(\$deepRecheckDone\) \{[\s\S]{0,900}Select-LifeFindNearestWord -Words \$linkWords')) 'True'
Assert-Case '배선: 마지막 프레임이 첫 프레임과 같은 팝업인지 확인 (제목 + 링크 Y)' `
  ([bool]($workerText -match "\`$finalFrameTitle -ne \`$firstFrameTitle[\s\S]{0,120}\`$firstFrameLinkY\) -gt 6")) 'True'
Assert-Case '배선: 클릭 직전 재확인 루프에도 사이클 한도 검사' `
  ([regex]::Matches($workerText, '사이클 한도 초과 - (클릭 직전 재확인|제목 띠 재확인) 중단').Count) '2'
Assert-Case '배선: 대상 행 클릭 직전 능동 캡처 확인 (플래그 신뢰 금지)' `
  ([bool]($workerText -match "if \(-not \(Test-CaptureRecovered -Game \`$Game\)\) \{[\s\S]{0,200}대상 행 클릭 직전에 화면이 멈췄습니다")) 'True'
# 소유 판정은 '그 판독이 채집 퀘스트 줄일 때만' 돕니다 - 좁은 영역에 다른 퀘스트 줄이
# 들어와 있으면 그 이름을 소유자로 집어 남의 퀘스트로 오판합니다
Assert-Case '배선: 소유 판정 전 퀘스트 줄 확인 2곳(초기/잔여)' `
  ([regex]::Matches($workerText, 'Test-LifeQuestFragments -QuestText \$\w+QuestText').Count) '2'
Assert-Case '배선: 대상 미발견 확정 전에 캡처 실패 여부 확인 (exit 4 오발동 방지)' `
  ([bool]($workerText -match "if \(\`$script:screenCaptureFailing\) \{\s*\r?\n\s*Write-RunLog '\[생활\] 화면이 그려지지 않아 대상 목록을")) 'True'
# 요구 레벨은 '이 대상의 상세로 확정된 뒤'에만 저장하고, 안내 시점에 대상을 다시 대조합니다
Assert-Case '배선: 요구 레벨 저장은 상세 확정 이후' `
  ([bool]($workerText -match "상세 팝업을 확인하지 못했습니다[\s\S]{0,600}?\`$script:lifeLastDetail = @\{")) 'True'
Assert-Case '배선: 요구 레벨 안내 전 대상 재대조' `
  ([bool]($workerText -match "\`$detailRecord.Target\) -eq \(\[string\]\`$lifeTargetName\)")) 'True'
Assert-Case '배선: 상세 팝업 판정이 순수 함수 경유(깨짐 대응 + 제목 대조)' ($workerText -match 'Get-LifeDetailVerdict -DetailText \$detailText -TargetName \$TargetName') 'True'
Assert-Case '배선: 상세 판독 s3→s4 사다리 (한 스케일 깨짐으로 wrong 확정 금지)' ($workerText -match 'foreach \(\$detailScale in @\(3, 4\)\)') 'True'
# 라벨 앵커는 2026-08-09 제보('채집물'->'채집묻')로 단일 진입점으로 모았습니다.
# 이 앵커 하나가 제목부 절단·요구 레벨·팝업 인식을 전부 좌우하므로, 리터럴이 다시
# 흩어지지 않게 '직접 참조 0건 + 진입점 경유'를 함께 못 박습니다.
Assert-Case '배선: 시작 정리 팝업 검출이 라벨 진입점 경유' `
  ($workerText -match "if \(Test-LifeDetailHasLabel -Text \`$detailText\)") 'True'
# 주석에는 설명용으로 '집물' 이 여러 번 나오므로 주석 줄을 걷어내고 **실제 코드만** 셉니다
$workerCodeOnly = (@($workerText -split "`n") | Where-Object { $_.TrimStart() -notlike '#*' }) -join "`n"
Assert-Case "배선: 라벨 리터럴 직접 참조 없음 (조각 배열 선언 1곳만)" `
  ([regex]::Matches($workerCodeOnly, "'집물'").Count) '1'
Assert-Case '배선: 라벨 조각에 실측 깨짐 포함' `
  ($workerText.Contains("`$lifeDetailLabelFragments = @('집물', '집묻')")) 'True'
Assert-Case '배선: 라벨 탐색이 가장 앞 조각 채택' `
  ($workerText -match "function Get-LifeDetailLabelIndex[\s\S]{0,600}?\`$found -lt \`$best") 'True'
# 판정: 깨진 라벨에서도 제목부가 잘리고 대상이 확정돼야 한다 (제보 원문)
$reportDetail = '문철광맥채집묻광석개기레豊30이상문철이섞인단단한드무더기.곡생OI로문철광석을수있다.[人}는,;테센마이평원가까운위치찾기41수'
Assert-Case "라벨: '채집묻' 깨짐에서도 제목부 절단" `
  (Get-LifeTitleFromDetailText -DetailText $reportDetail) '문철광맥채'
Assert-Case "라벨: '채집묻' 깨짐에서도 대상 확정 (제보 재현)" `
  (Get-LifeTitleVerdictFromDetail -DetailText $reportDetail -TargetName '운철 광맥') 'mine'
Assert-Case "라벨: '레벨'이 '레豊'로 깨져도 요구 레벨 판독" `
  (Get-LifeRequiredLevel -DetailText $reportDetail) '30'
Assert-Case '라벨: 라벨이 아예 없으면 -1 (팝업 아님)' `
  (Get-LifeDetailLabelIndex -Text '아무의미없는문자열') '-1'
# 아래 3건은 2026-08-09 교차 리뷰가 제시한 반례입니다. 전부 '조용히 엉뚱한 값을 확정'하는
# 종류라 로그만 보고는 못 잡습니다.
# ① 진짜 라벨을 놓친 뒤 설명 본문의 같은 조각을 라벨로 인정하면 제목이 통째로 잘못 잘립니다
Assert-Case '라벨: 위치 상한 밖의 조각은 라벨로 보지 않음 (오클릭 확정 방지)' `
  (Get-LifeDetailLabelIndex -Text '운철광맥채집들광석캐기레벨30이상설명집묻뒤') '-1'
Assert-Case '라벨: 상한 밖이면 제목부도 빈 값' `
  (Get-LifeTitleFromDetailText -DetailText '운철광맥채집들광석캐기레벨30이상설명집묻뒤') ''
# ② 요구 레벨은 라벨 바로 뒤만 봐야 합니다 - 설명 속 숫자를 요구치로 오독하면 사용자가 오판
Assert-Case '레벨: 진짜 요구치가 깨졌으면 설명 속 숫자를 쓰지 않음' `
  (Get-LifeRequiredLevel -DetailText '감자채집물호미질레X1이상설명설명설명설명설명설명설명설명레豊30') '0'
# ③ 제목 띠는 라벨 후보 중 가장 위를 써야 합니다 (단어 열거 순서는 보장되지 않음)
$stripWords = @(
  [pscustomobject]@{ Text = '설명집물비슷'; Y = 330 }
  [pscustomobject]@{ Text = '채집물';       Y = 218 }
)
Assert-Case '제목 띠: 라벨 후보 중 최소 Y 채택' `
  ((Get-LifeTitleStripRegion -Words $stripWords) -join ',') '440,174,300,36'
Assert-Case "배선: '생활 스킬' 클릭 후 화면 전환 확인 게이트" ($workerText.Contains("'생활 스킬' 화면 전환을 확인하지 못했습니다")) 'True'
Assert-Case '배선: 휠 전 게임 전면 확인' ($workerText -match 'function Invoke-LifeListScroll[\s\S]{0,700}Test-GameForeground -Game \$Game') 'True'
# 2차 리뷰 반영 계약 (리뷰): deadline 하드 상한 + 캡처 실패 판독 무효 + 휠 증거
Assert-Case '배선: deadline 은 준비 정리(이벤트 스킵) 뒤에 생성' ($workerText -match '\[void\]\(Clear-EventOverlay -Game \$Game\)[\s\S]{0,500}\$cycleDeadline = \(Get-Date\)\.AddSeconds') 'True'
Assert-Case '배선: 생성 확인 루프에도 deadline 우선' ($workerText -match 'foreach \(\$confirmTry in 1\.\.8\) \{\s*\r?\n\s*Test-LifeUntilReached\s*\r?\n\s*if \(\(Get-Date\) -gt \$cycleDeadline\) \{ break \}') 'True'
Assert-Case '배선: C 입력 전 판독 후 캡처 플래그 재확인' ($workerText -match '\$infoAlreadyOpen = Test-LifeInfoScreen -Game \$Game\s*\r?\n\s*if \(\$script:screenCaptureFailing\) \{ return \$false \}') 'True'
Assert-Case '배선: 전환 확인 판독 후 캡처 플래그 재확인' ($workerText -match '\$infoStillVisible = Test-LifeInfoScreen -Game \$Game[\s\S]{0,400}if \(\$script:screenCaptureFailing\) \{ continue \}') 'True'
Assert-Case '배선: 훑기 판독 1벌 공유(찾기+행 증거) + 목록 순서 전달' `
  (($workerText -match '\$scanResult = Find-LifeTargetScan -Game \$Game -TargetName \$TargetName -Order @\(\$SkillEntry\.Order\)') -and
   ($workerText -match '\$visibleRows = @\(\$scanResult\.Rows\)')) 'True'
# 드래그 전환 (2026-08-06 실험: 휠은 이 목록에서 위 방향 무효 - 양 끝 대상 미발견 원인)
Assert-Case '배선: 목록 스크롤은 드래그 (휠 mouse_event 0x0800 미사용)' `
  (($workerText -match 'function Invoke-LifeListScroll[\s\S]{0,4000}mouse_event\(0x0002[\s\S]{0,1500}mouse_event\(0x0004') -and
   (-not ($workerText -match 'function Invoke-LifeListScroll[\s\S]{0,4000}mouse_event\(0x0800'))) 'True'
# ★ 8차 점검: 두 번째 조건 '플링(관성) 방지'는 소스의 **줄 끝 주석에만** 있었습니다.
#   즉 '정지 후 떼기'(mouse-up 전 250ms 정지) 절반은 어떤 테스트도 지키지 않았고, 그게
#   빠지면 관성 스크롤이나 같은 자리 down-up 이 되어 대상 목록에서 **항목 클릭 오인**이
#   납니다(그 주석이 명시한 위험). 주석이 아니라 **코드 순서**로 못 박습니다.
$dragBody = [string](Get-SourceFunctionDefinitions -Path $workerPath -Names @('Invoke-LifeListScroll'))
$dragCode = (($dragBody -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Assert-Case '배선: 드래그는 중간 단계 이동 + 정지 후 떼기 (클릭 오인/관성 방지)' `
  ([bool]($dragCode -match '(?s)foreach \(\$moveStep in 1\.\.16\)[\s\S]{0,400}SetCursorPos\(\$stepX, \$stepY\)[\s\S]{0,200}\}\s*\r?\n\s*Start-Sleep -Milliseconds 250')) 'True'
Assert-Case '배선: 정지 후에 버튼을 뗀다(mouse-up 이 정지보다 뒤)' `
  ([bool]($dragCode.IndexOf('Start-Sleep -Milliseconds 250') -ge 0 -and
          $dragCode.IndexOf('mouse_event(0x0004') -gt $dragCode.IndexOf('Start-Sleep -Milliseconds 250'))) 'True'
# 4종 전부 목록 순서 데이터 보유 (격자 추론 전제)
foreach ($orderKey in @('daily', 'wood', 'mining', 'herb')) {
  Assert-Case "테이블: $orderKey Order 목록 보유" (@($lifeSkillMenuTable[$orderKey].Order).Count -ge 8) 'True'
}
Assert-Case '테이블: daily Order 가 실제 목록 순서(물 3번째)' ([string]$lifeSkillMenuTable['daily'].Order[2]) '물'
# 진행 차단 모달 처리 (준비물 부족 = 조건부 정지 / 오류 팝업 = 닫고 계속)
Assert-Case '배선: 차단 모달 소함수 + 메뉴 루프 배선' `
  (($workerText -match 'function Close-LifeBlockingDialog') -and
   ($workerText -match '\$dialogState = Close-LifeBlockingDialog -Game \$Game') -and
   ($workerText -match "if \(\`$dialogState -eq 'material'\)[\s\S]{0,300}exit 4")) 'True'
# 서버 연결 끊김 (2026-08-06 라운드 4: 끊긴 채 3회차가 각 600초 소진 → 가방 가득 오인)
Assert-Case '배선: 서버 연결 끊김 감지 → 메뉴/대기 양쪽에서 즉시 정지' `
  (([regex]::Matches($workerText, "-eq 'disconnected'\) \{").Count -ge 2) -and
   ($workerText -match "게임 서버 연결이 끊어졌습니다 - 재접속 후 다시 시작")) 'True'
Assert-Case '배선: 대기 루프는 퀘스트 미표시 또는 5회차마다 모달 확인 (모달 뒤 트래커 대비)' `
  ($workerText -match "if \(\`$questState -ne 'present' -or \(\`$waitPollCount % 5\) -eq 0\)") 'True'
# 리뷰 4차 리뷰 반영 계약
Assert-Case '배선: 초기 퀘스트 판정 전에 연결 끊김 확인' `
  ($workerText -match "if \(\(Close-LifeBlockingDialog -Game \`$Game\) -eq 'disconnected'\)[\s\S]{0,900}\`$initialState = 'unknown'") 'True'
Assert-Case '배선: 퀘스트 생성 실패 직후에도 disconnected 처리' `
  ($workerText -match "\`$questFailDialog = Close-LifeBlockingDialog[\s\S]{0,300}-eq 'disconnected'") 'True'
Assert-Case '배선: 드래그 mouse-up 은 finally + 이동 검증' `
  (($workerText -match 'finally \{\s*\r?\n\s*\[HoneyNogiInput\]::mouse_event\(0x0004') -and
   ($workerText -match '\$dragMoved = \$true')) 'True'
Assert-Case '배선: 모달 닫기 버튼은 하단 밴드 우선 + 예비 좌표는 팝업 확정 후에만' `
  (($workerText -match '\$buttonBand = @\(400, 560, 480, 120\)') -and
   ($workerText -match 'if \(\$closePoint\) \{\s*\r?\n\s*Click-ScreenPoint')) 'True'
Assert-Case '배선: 최상단 정렬/탐색 스크롤 직전 deadline 재검사' `
  ([regex]::Matches($workerText, '\(Get-Date\) -gt \$Deadline').Count -ge 6) 'True'
# 화면에 이미 보이면 스크롤 0회로 즉시 클릭 (2026-08-06 사용자 관찰 - 상단 대상도 매번 정렬)
Assert-Case '배선: 현재 화면 우선 탐색 → 못 찾을 때만 최상단 정렬' `
  (($workerText -match '\$quickScan = Find-LifeTargetScan -Game \$Game -TargetName \$TargetName -Order @\(\$SkillEntry\.Order\)') -and
   ($workerText -match '스크롤 없이 선택합니다') -and
   ($workerText -match 'if \(\$null -eq \$targetRowY\) \{[\s\S]{0,400}\$topRows = @\(\$quickScan\.Rows\)')) 'True'
# 이미 최상단이면 정렬 드래그 0회 (사용자 지적: 최상단에서도 확인 목적으로 2번씩 끌던 낭비.
# 2026-08-12: 이름 단독 근거 → Test-LifeListAtTop(이름+앵커 기하)으로 교체 - 첫 항목이
# '과D테'로 깨지는 창에서 매 회전 헛드래그 1회(~2초)가 나던 실사고 대응)
Assert-Case '배선: 최상단 판정(이름+기하)이 정렬 생략과 도달 조기 종료 양쪽에 배선' `
  (($workerText -match '\$alreadyAtTop = Test-LifeListAtTop -Rows \$topRows -Order @\(\$SkillEntry\.Order\)') -and
   ($workerText -match '목록이 이미 최상단입니다 - 정렬 생략') -and
   ($workerText -match 'if \(Test-LifeListAtTop -Rows \$topRows -Order @\(\$SkillEntry\.Order\)\) \{ \$topRowsKey = \$currentTopKey; break \}')) 'True'
Assert-Case '배선: 탐색은 목록 끝 도달 판정 + 안전 상한 12회 (고정 회수 아님)' `
  (($workerText -match 'while \(\$scrollStep -lt 11\)') -and
   ($workerText -match 'if \(\$lastScrollSent -and \(\$rowsKey -eq \$previousRowsKey\)\)')) 'True'
# 2차 교차 리뷰 반영 계약
Assert-Case '배선: 스크롤 수행 여부 반환 + 끝 판정에 반영' `
  (($workerText -match 'function Invoke-LifeListScroll[\s\S]{0,4500}return \$true') -and
   ($workerText -match '\$lastScrollSent = \[bool\]\(Invoke-LifeListScroll -Game \$Game -Steps -1\)')) 'True'
Assert-Case '배선: 탐색 마지막 회차 휠 생략' ($workerText -match 'if \(\$scrollStep -eq 11\) \{ break \}') 'True'
Assert-Case '배선: 상세 wrong 확정은 두 스케일 합의 (wrongCount 2)' ($workerText -match 'if \(\$detailWrongCount -ge 2\)') 'True'
# 메뉴 시퀀스 내부 deadline (3차 교차 리뷰: 한도 초과 후 클릭 진행 금지 - 특히 찾기 입력)
Assert-Case '배선: 메뉴 시퀀스가 Deadline 을 받아 내부 검사 4곳+' `
  (($workerText -match 'Invoke-LifeMenuSequence -Game \$Game -SkillEntry \$skillEntry -TargetName \$lifeTargetName -Deadline \$lifeMenuDeadline') -and
   (([regex]::Matches($workerText, '\(Get-Date\) -gt \$Deadline')).Count -ge 4)) 'True'
Assert-Case "배선: '가까운 위치 찾기' 링크는 글자 탐색으로만 클릭 (고정 좌표 폴백 금지)" `
  (($workerText -match 'Select-LifeFindNearestWord -Words \$linkWords') -and
   ($workerText -match "링크를 찾지 못했습니다 - 이번 회전 중단") -and
   (-not $workerText.Contains('ptLifeFindNearest'))) 'True'
Assert-Case '배선: 링크 클릭 직전 deadline 재검사 (OCR/전면화 시간 반영)' `
  ($workerText -match 'Select-LifeFindNearestWord[\s\S]{0,6000}\(Get-Date\) -gt \$Deadline[\s\S]{0,300}Click-GamePoint -Game \$Game -ReferenceX \(\[int\]\$linkWord\.X\)') 'True'
# 링크 클릭 후 고정 1500ms 는 제거 (2026-08-12): 생성 확인 루프가 첫 판독 전에 또 1500ms 를
# 자는 이중 대기였음 - present 2회 계약과 판독 간격은 루프 쪽이 그대로 담당
Assert-Case '배선: 링크 클릭 후 고정 대기 없음 (생성 확인 루프 선행 대기가 담당)' `
  ($workerText -match 'Click-GamePoint -Game \$Game -ReferenceX \(\[int\]\$linkWord\.X\) -ReferenceY \(\[int\]\$linkWord\.Y\)\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*return \$true') 'True'
Assert-Case '배선: 상세 unreadable 2회는 행 매칭 근거로 진행 (오클릭 확정 아님)' `
  ($workerText -match 'if \(\$detailUnreadableCount -ge 2\)') 'True'
# 격자 신뢰도 계약 (라운드 6 + 2026-08-12 개정): order-strong 만 즉시 통과. 약한 order 는
# 즉시 거부 대신 '클릭 프레임의 링크 제목 = 목표의 제목 전용 이형 정확 일치' 게이트로 이관
# (동 광맥 실사고: 상세 판독이 제목을 통째로 놓치는 창에서 order 회전 전패 → 조건부 정지.
# 링크 판독의 '도과DH'는 성공 회전 3회 전부 관측된 작동 증거)
Assert-Case '배선: 약한 추론(order)은 링크 제목 게이트로 이관 (즉시 수용 금지)' `
  (($workerText -match "if \(\`$targetRowSource -eq 'order'\) \{[\s\S]{0,1800}\`$requireLinkTitleMine = \`$true") -and
   ($workerText -match "if \(\`$targetRowSource -eq 'order-strong'\)[\s\S]{0,400}\`$detailOk = \`$true")) 'True'
Assert-Case '배선: 링크 제목 게이트 - 명시 이형 판정으로만, 불일치 시 회전 중단' `
  (($workerText -match 'if \(\$requireLinkTitleMine\) \{\s*\r?\n\s*if \(-not \(Test-LifeTitleExplicitVariant -Title \$linkTitle -TargetName \$TargetName\)\)[\s\S]{0,400}return \$false') -and
   ($workerText -match '등록 이형과 일치하지 않습니다')) 'True'
Assert-Case '배선: 게이트 플래그는 상세 검증 시작 시 항상 초기화' `
  ($workerText -match '\$requireLinkTitleMine = \$false') 'True'
Assert-Case '배선: 모달 닫기 실패 시 예비 좌표 2곳 시도 + 닫힘 재확인' `
  (($workerText -match '닫기 버튼 글자를 못 읽어 실측 좌표로') -and
   ($workerText -match 'Click-GamePoint -Game \$Game -ReferenceX 636 -ReferenceY 453')) 'True'
# 다른 대상 퀘스트가 남아 새 퀘스트 생성이 막히는 게임 제약 (라운드 7 실측)
# ★ 10차: 8차에서 고친 '채집 **도중** 준비물 소진 → 즉시 exit 4' 계약에 테스트가 없어
#   되돌려도 전부 통과했습니다. 되돌리면 수량이 안 늘어나는 채로 진행 없음 한도(권장 1200초)를
#   태운 뒤 "'채집 대기'를 늘려 주세요"라는 **정반대 안내**로 끝납니다.
Assert-Case '배선: 채집 대기 중 준비물 소진은 즉시 조건 정지(품목 안내 포함)' `
  ([bool]($workerText -match "(?s)\`$waitDialogState -eq 'material'[\s\S]{0,400}?채집 중에 준비물이 떨어졌습니다[\s\S]{0,200}?Format-LifeMissingItemNotice[\s\S]{0,120}?exit 4")) 'True'
Assert-Case '배선: 준비물 소진을 continue 로 흘려보내지 않는다' `
  ([bool]($workerText -match "(?s)\`$waitDialogState -eq 'material'[\s\S]{0,400}?exit 4[\s\S]{0,200}?\`$waitDialogState -ne 'none'")) 'True'
Assert-Case '배선: 잔여 타 대상 퀘스트면 재시도 대신 안내 정지' `
  ($workerText -match '\$leftoverIsOther[\s\S]{0,300}다른 채집 퀘스트가 진행 중이라[\s\S]{0,120}exit 4') 'True'
# 시작 시점에 다른 대상 채집이 진행 중이면 메뉴를 아예 열지 않는다 (사용자 실기 관찰:
# 이동 중인데 다른 대상을 눌러 진행 중인 채집을 방해)
# 트래커가 잠깐 가려져 '없음'으로 오판하면 남의 채집을 방해 (2026-08-07 사용자 지적)
Assert-Case '배선: 초기 퀘스트 확인은 전면화 + 확정될 때까지 판독 (present 우선, 로딩 대기)' `
  (($workerText -match 'Focus-Game -Game \$Game\s*\r?\n\s*Start-Sleep -Milliseconds 700\s*\r?\n\s*\$initialState') -and
   # 거리 상한 대신 **순서**로 봅니다. 주석이 늘 때마다 숫자를 올려야 하는 단언은 결국
   # 느슨해지고(7차에 실제로 터짐), 여기서 지키려는 계약은 '같은 루프 안에서 present 를
   # 확정한다' 이지 '몇 글자 안에' 가 아닙니다.
   ($workerText.IndexOf('while ($initialProbes -lt 20)') -ge 0 -and
    $workerText.IndexOf("if (`$probeState -eq 'present') { `$initialState = 'present'; break }") -gt
      $workerText.IndexOf('while ($initialProbes -lt 20)')) -and
   ($workerText -match '맵 이동/로딩 추정')) 'True'
# 캡처 실패·팝업 정리 회차는 판독 예산(20회)을 소모하면 안 됩니다 - 소모하면 잠깐의 화면 정지가
# 예산을 다 태우고 'unknown' 인 채 메뉴를 열어 진행 중인 채집을 방해합니다 (2026-08-07 감사)
Assert-Case '배선: 초기 확인 예산은 실제 판독에서만 소모' `
  ([bool]($workerText -match '\$initialProbes\+\+\s*\r?\n\s*\$probeState = Get-LifeQuestState')) 'True'
Assert-Case '배선: 이전 채집 대기 예산도 실제 판독에서만 소모' `
  ([bool]($workerText -match 'while \(\$otherWaitProbes -lt 60\)')) 'True'
# 로딩 화면(unknown)을 '없음'으로 세면 이동 중 다른 대상을 누름 (2026-08-07 사용자 지적)
Assert-Case '배선: 소멸 판정은 absent 일 때만 카운트 (로딩 unknown 은 보류)' `
  (($workerText -match "if \(\`$otherProbe -ne 'absent'\) \{") -and
   ($workerText -match '소멸 판정 보류')) 'True'
# 판독 전 전면화 검증 (다른 창이 트래커를 가리면 완료 오판 - 2026-08-07 사용자 지적)
# 다른 창이 게임을 덮으면 판독은 남의 창 글자를, 클릭은 엉뚱한 곳을 향함 (2026-08-07 실사고)
# 전면화는 '퀘스트가 안 읽혔을 때만' (읽히면 게임 화면이라는 증거 - 사용자 지시)
Assert-Case '배선: 판독 먼저 → 안 읽힐 때만 전면화 후 재판독 → 그래도 안 되면 unknown' `
  ($workerText -match 'function Get-LifeQuestState[\s\S]{0,2200}Test-LifeQuestFragments[\s\S]{0,1400}if \(-not \(Test-GameForeground -Game \$Game\)\) \{\s*\r?\n\s*Focus-Game -Game \$Game[\s\S]{0,2200}if \(Test-HomeEndEscHud -Game \$Game\) \{ \$script:lifeQuestStateEvidence\.Hud = ''HUD 보임''; return ''absent'' \}') 'True'
# 2026-08-14 실사고 대응: 소멸 판정에 실제 쓰인 판독 원문을 보존·기록한다 (재발 시 원인 확정용)
Assert-Case '배선: 소멸 판정 근거 보존 (판정 원문 로그 + 1회차 캡처)' `
  (($workerText -match '\$script:lifeQuestStateEvidence = @\{ Narrow') -and
   ($workerText -match '소멸 판정 \{0\}/3') -and
   ($workerText -match "if \(\`$absentStreak -eq 1\) \{ Write-LifeDiagnostics -Game \`$Game -Context '소멸 판정 근거' -CaptureOnly \}")) 'True'
Assert-Case '배선: 메뉴 시퀀스·링크 클릭 전 전면 확인 소함수' `
  (($workerText -match 'function Confirm-LifeGameFront') -and
   ([regex]::Matches($workerText, 'Confirm-LifeGameFront -Game \$Game').Count -ge 2)) 'True'
# 판독 중에는 전면화하지 않되(가려지지도 않았는데 게임이 튀어나옴), '완료를 확정하는
# 순간'에만 전면 여부를 확인합니다 - 이미 전면이면 아무 동작 없음 (2026-08-07 사용자 지적)
Assert-Case '배선: 완료 확정 직전에만 전면 확인 + 재판독으로 취소 가능' `
  (($workerText -match "if \(\`$absentStreak -ge 3\) \{\s*\r?\n[\s\S]{0,500}if \(-not \(Test-GameForeground -Game \`$Game\)\)[\s\S]{0,400}완료 판정 취소") -and
   ($workerText -match "\`$otherGoneStreak -ge 2 -and -not \(Test-GameForeground -Game \`$Game\)")) 'True'
Assert-Case '배선: 시작 시 타 대상 채집이 끝나기를 대기 (메뉴 진입 금지 + 한도 내)' `
  (($workerText -match '다른 대상의 채집이 진행 중입니다[\s\S]{0,200}끝나기를 기다립니다') -and
   ($workerText -match '진행 중이던 다른 채집이 끝나지 않아[\s\S]{0,120}exit 4')) 'True'
# 소멸 확정도 연속 3회 (1회 판독 확정은 트래커 가림에 그대로 당함 - 2026-08-07 실기)
Assert-Case '배선: 타 대상 채집 소멸 판정은 연속 3회 확인' `
  (($workerText -match '\$otherGoneStreak = 0') -and
   ($workerText -match 'if \(\$otherGoneStreak -ge 3\) \{ \$otherQuestGone = \$true; break \}')) 'True'
# 대기 중 남은 수량 표시 + 확인 간격 3초 (사용자 요청: 9/10 이면 곧 끝나는 걸 알 수 있게)
Assert-Case '배선: 이전 채집 대기 중 수량 로그 + 3초 간격' `
  (($workerText -match '이전 채집 진행 중: \$otherCount') -and
   ($workerText -match 'while \(\$otherWaitProbes -lt 60\)[\s\S]{0,200}Start-Sleep -Seconds 3')) 'True'
Assert-Case '배선: gatherWaitSeconds 계약 600(60~3600)' ($workerText.Contains("@('life', 'gatherWaitSeconds') 600 60 3600")) 'True'
Assert-Case "배선: [설정] 스냅샷에 'life' 섹션 포함" ($workerText.Contains("'huntingGround', 'life', 'timeoutsSeconds'")) 'True'
Assert-Case '배선: 생성 확인 present 2회 요구' ($workerText.Contains('$presentCount -ge 2')) 'True'
Assert-Case '배선: 소멸 확정 absent 3연속 요구' ($workerText.Contains('$absentStreak -ge 3')) 'True'
$configJson = Get-Content (Join-Path $projectRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Case 'config: mainCategory 기본 battle' ([string]$configJson.mainCategory) 'battle'
Assert-Case 'config: life.gatherWaitSeconds 600' ([int]$configJson.life.gatherWaitSeconds) '600'
$guiText = [IO.File]::ReadAllText((Join-Path $projectRoot 'mabinogi_gui.ps1'))
# '채집 대기'는 의미가 바뀐 설정이라 이전 시 보존하지 않고 기본값으로 되돌립니다 (schema 6)
# '가방 가득 시' / '도구 내구도 소진 시' 옵션 제거 (2026-08-08 사용자 판단):
# 두 상황 모두 게임이 스스로 채집을 멈추므로 '계속 진행'이라는 선택지가 성립하지 않고,
# 워커는 이 값을 읽은 적조차 없었습니다 - 고를 수 있게 두면 동작하는 것처럼 오해만 됩니다.
Assert-Case 'GUI: 가방/도구 옵션 컨트롤 없음' `
  ([regex]::Matches($guiText, 'rbLifeBag|rbLifeTool|pnlLifeBag|pnlLifeTool').Count) '0'
Assert-Case 'GUI: config 저장에도 bagFull/toolWorn 없음' `
  ([regex]::Matches($guiText, 'bagFull|toolWorn').Count) '0'
Assert-Case '워커: bagFull/toolWorn 참조 없음 (원래도 안 읽었음)' `
  ([regex]::Matches($workerText, 'bagFull|toolWorn').Count) '0'
Assert-Case '워커: 시작 안내에서 미감지 문구 제거' `
  ([bool]($workerText -match '가방/도구 소진은 아직 감지하지 않습니다')) 'False'
# 준비물 부족 '감지'는 옵션이 아니라 안내이므로 그대로 둡니다 (필요 아이템 이름을 로그에 남김)
Assert-Case '워커: 준비물 부족 감지·안내는 유지' `
  ([bool]($workerText -match "채집에 필요한 준비물이 없습니다\`$\(Format-LifeMissingItemNotice")) 'True'
Assert-Case 'GUI: 이전 특례로 gatherWaitSeconds 를 600 으로 복귀' `
  ([bool]($guiText -match "\`$usrSchema -lt 6[\s\S]{0,400}\`$def\.life\.gatherWaitSeconds = 600")) 'True'
Assert-Case 'GUI: 되돌림 안내 로그 존재' ([bool]($guiText -match "기본값 600초로 되돌렸습니다")) 'True'
Assert-Case 'GUI: 진행 없음 라벨 (총 시간 아님을 드러냄)' ([bool]($guiText -match "'진행 없음\(초\):'")) 'True'
Assert-Case 'GUI: numGatherWait 기본 600' ($guiText.Contains('$numGatherWait.Value = 600')) 'True'
Assert-Case 'GUI: numGatherWait 최소 60 (워커 계약 일치)' ($guiText.Contains('$numGatherWait.Minimum = 60')) 'True'
# 생활 시작 시 전투 하위 상태(숨겨진 라디오/커스텀 체크) 누출 방지 (2026-08-06 00:06 실기
# 제보: 생활 시작인데 혼합 리스트 안내 표시 - 커스텀 시작 경로도 함께 타던 구멍)
# 2026-08-08 생활 채집 커스텀 신설: 전투 경로는 여전히 생활에서 배제하고, 생활은 '채집 +
# 커스텀' 조합일 때만 별도 플래그로 켭니다 (가공은 리스트가 없어 제외)
Assert-Case 'GUI: 커스텀 시작 판정에 생활 게이트(전투 경로는 여전히 배제)' `
  ([bool]($guiText -match '\$isCustomStart = \(\$isLifeCustomStart -or\s+\(\$rbCustomRepeat\.Checked -and -not \$rbCatHunting\.Checked -and -not \$isLifeStart\)\)')) 'True'
Assert-Case 'GUI: 생활 커스텀은 채집일 때만' `
  ($guiText.Contains('$isLifeCustomStart = ($isLifeStart -and $rbCustomRepeat.Checked -and $rbLifeGather.Checked)')) 'True'
Assert-Case 'GUI: 던전/심층 시작 안내에 생활 게이트 2곳' `
  ((([regex]::Matches($guiText, '\$rbCatDungeon\.Checked -and -not \$isLifeStart')).Count -ge 1) -and
   (([regex]::Matches($guiText, '\$rbCatDeep\.Checked -and -not \$isLifeStart')).Count -ge 1)) 'True'
Assert-Case 'GUI: 혼합 잠금 안내는 생활에서 억제 2곳(잠금/해제)' `
  ([regex]::Matches($guiText, "if \(\`$script:mainCategory -ne 'life'\) \{\s*\r?\n\s*Add-GuiLog").Count) '2'
Assert-Case 'GUI: 생활 시작 전용 안내 존재' ($guiText.Contains('[안내] 채집 자동화: 캐릭터가 필드에 있으면')) 'True'
# 시간 지정/사유 폴백의 전투 설정 누출 방지 (2차 교차 리뷰)
Assert-Case 'GUI: 시간 지정 예상치가 대분류별 (생활=채집 대기)' `
  (($guiText -match "if \(\`$script:mainCategory -eq 'life'\) \{ return \[int\]\`$numGatherWait\.Value \}") -and
   ($guiText -match '\(Get-Date\)\.AddSeconds\(\(Get-CycleWaitSecondsForEstimate\)\)')) 'True'
Assert-Case 'GUI: 코드 4 사유 폴백에 생활 분기 (숨겨진 전투 라디오 미참조)' `
  ($guiText.Contains('조건 충족으로 정지 - 채집 시간 초과/미지원 항목 등')) 'True'
# 안전 중지 안내가 생활에서도 '던전에서 나오면'이라고 떴습니다 (2026-08-08 사용자 지적).
# 전투는 워커가 결과 화면에서 나가기를 눌러 조기 종료하지만, 생활에는 그런 지점이 없어
# (채집을 중간에 버리면 퀘스트만 날아감) 진행 중인 채집을 마친 뒤 GUI 가 다음 사이클을
# 시작하지 않는 방식입니다 - 안내 문구가 그 차이를 그대로 말해야 합니다.
Assert-Case 'GUI: 안전 중지 안내가 대분류별로 갈림' `
  ([bool]($guiText -match "if \(\`$script:mainCategory -eq 'life'\) \{[\s\S]{0,300}?이번 채집을 마치면 멈춥니다[\s\S]{0,400}?\} else \{[\s\S]{0,300}?던전에서 나오는 대로 멈춥니다")) 'True'
Assert-Case 'GUI: 생활 안전 중지 로그가 소요 시간까지 안내' `
  ($guiText.Contains('진행 중인 채집을 끝까지 마친 뒤 다음 사이클을 시작하지 않습니다')) 'True'
Assert-Case 'GUI: 전투 안전 중지 문구는 그대로 유지' `
  ($guiText.Contains('안전 중지 예약: 던전에서 나와 밖이 확인되면 멈춥니다. (버튼을 다시 누르면 취소)')) 'True'
# 설정 그룹 공용 버튼 3개는 양 대분류 모두 아래 가로 1줄 (2026-08-13 시안 확정 - 전투는
# 체크 4개를 가로 2줄로 압축하고 클리어 대기 줄을 자동부활 오른쪽으로 옮겨 높이 150 유지.
# 대분류별 차이는 버튼 y뿐: 전투 110 / 생활 56. 크기는 선언부에서 158x28 단일)
Assert-Case 'GUI: 전투도 아래 가로 한 줄(y110, 15/183/351 - 2026-08-13 시안)' `
  ([bool]($guiText -match "else \{\s*\r?\n\s*\`$btnRecommendedWindow\.Location = New-Object System\.Drawing\.Point\(15, 110\)\s*\r?\n\s*\`$btnAlwaysOn\.Location = New-Object System\.Drawing\.Point\(183, 110\)\s*\r?\n\s*\`$btnSave\.Location = New-Object System\.Drawing\.Point\(351, 110\)")) 'True'
Assert-Case 'GUI: 생활 전환 시 아래 가로 한 줄(y56, 15/183/351)' `
  ([bool]($guiText -match "if \(\`$isLife\) \{\s*\r?\n\s*\`$btnRecommendedWindow\.Location = New-Object System\.Drawing\.Point\(15, 56\)\s*\r?\n\s*\`$btnAlwaysOn\.Location = New-Object System\.Drawing\.Point\(183, 56\)\s*\r?\n\s*\`$btnSave\.Location = New-Object System\.Drawing\.Point\(351, 56\)")) 'True'
Assert-Case 'GUI: 버튼 크기 158x28 단일 (구 108x30 잔존 없음)' `
  (($guiText.Contains('$btnSave.Size = New-Object System.Drawing.Size(158, 28)')) -and
   (-not $guiText.Contains('System.Drawing.Size(108, 30)'))) 'True'
Assert-Case 'GUI: 전투 체크 가로 배치 (음식 183,25 / 어시스트 351,25 / 부활 15,52)' `
  (($guiText.Contains('$chkFood.Location = New-Object System.Drawing.Point(183, 25)')) -and
   ($guiText.Contains('$chkAssist.Location = New-Object System.Drawing.Point(351, 25)')) -and
   ($guiText.Contains('$chkRevive.Location = New-Object System.Drawing.Point(15, 52)'))) 'True'
Assert-Case 'GUI: 클리어 대기 줄이 자동부활 오른쪽 (숫자 333,50)' `
  ($guiText.Contains('$numClearWait.Location = New-Object System.Drawing.Point(333, 50)')) 'True'
Assert-Case 'GUI: 설정 그룹 높이도 대분류별 (생활 94 / 전투 150)' `
  (($guiText.Contains('$grpSettings.Height = 94')) -and ($guiText.Contains('$grpSettings.Height = 150'))) 'True'
Assert-Case 'GUI: 저장 안내 라벨도 함께 이동 (버튼 줄과 겹침 방지 - 2026-08-13: 전투는 353,88)' `
  (($guiText.Contains('$lblSaveInfo.Location = New-Object System.Drawing.Point(350, 28)')) -and
   ([regex]::Matches($guiText, '\$lblSaveInfo\.Location = New-Object System\.Drawing\.Point\(353, 88\)').Count -eq 2)) 'True'
# '적용된 설정' 팝업이 시작 게이트와 같은 지원 목록을 보게 (함수 지역 변수였을 때 못 읽어
# 낚시도 지원되는 것처럼 보였습니다 - 2026-08-08)
Assert-Case 'GUI: 지원 스킬 목록이 script 스코프 단일 선언' `
  ([regex]::Matches($guiText, '\$script:lifeSupportedSkillIds = @\(').Count) '1'
Assert-Case 'GUI: 시작 게이트와 팝업이 같은 목록 참조 (+커스텀 추가/시작 게이트)' `
  ([regex]::Matches($guiText, '\$script:lifeSupportedSkillIds -(not)?contains').Count) '4'
Assert-Case 'GUI: 준비 중 안내는 미지원 항목에만' `
  (($guiText.Contains(' - 콘텐츠: 가공 (아직 지원하지 않습니다 - 시작할 수 없음)')) -and
   ([bool]($guiText -match "\`$lifeLines\.Add\('\[생활 설정\]'\)"))) 'True'

exit $fails
