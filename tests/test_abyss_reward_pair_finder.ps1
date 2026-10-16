# 어비스 보상 화면 짝 찾기 - '다시 하기'·'다른 던전 가기' 글자 짝 진리표 (구현 단위 ③ - 2026-10)
#
# 배경(설계 v11 R6 6.2 · 설계 v10 8절 ⑤ 행): 3버튼 보상 화면('[ESC] 나가기' / '[Space] 다시 하기' / '다른 던전 가기')의 두 버튼은 고정 좌표가
# 아니라 판독한 글자 자리를 눌러야 합니다 - 같은 버튼이 렌더(1272 · 1270 · 1276 콘솔 전환 · 1908 두 렌더)와 등장 슬라이드에 따라 몇~십여 px 움직입니다.
# 이 단위는 워커에 판독 함수 둘(순수 Select-AbyssRewardButtonPair -Words · 화면 Find-AbyssRewardButtonPair -Game)과 판별 상수 셋
# ($abyssRetryPairBandX · $abyssOtherPairBandX · $abyssPairMaxDy - config 아닌 스크립트 상수)만 넣습니다. 호출자는 0 이고(첫 호출자는 다음 단위 ⑤)
# 동작 변화도 0 입니다.
# 여기서 고정하는 계약(명세 1.5):
#   G1 Retry 머리 = '다시'·'다세'·'다셔' 를 담은 단어, 머리 X 가 retry 대역 안
#   G2 Retry 꼬리 = '하기' 를 담은 다른 단어 - 꼬리 X > 머리 X · 꼬리 X ≤ 대역 끝 · |꼬리 Y - 머리 Y| ≤ dY 한도. 짝의 두 단어가 모두 대역 안이어야
#      합니다(네트워크 불안정 팝업 '다시 시도하기' 는 '다세'@702 가 대역 안, '시도하기'@763 이 밖 - PN11·PN12)
#   G3 Other = 머리 '다른' · 꼬리 '던전' · other 대역 · 같은 꼴
#   G4 후보가 여럿이면 머리 X 최소 → 꼬리 X 최소 → 목록 앞    G5 클릭점 = 두 단어 중심의 중점 (X·Y 각각 [Math]::Round 기본 = 짝수 쪽 - 635.5 → 636)
#   G6 쓰지 않는 것 - '가기'('나가기' 와 겹침) · 한 단어로 붙은 판독 · 관측 깨짐 조각('다' · 'Ⅸl하기' · '다르'·'더전' · '다'+'전가기' - 커서 가림)
#   G7 빈 목록·$null → 둘 다 null (고정 좌표로 채우지 않음)
#   화면 함수 - Test-ExitButton·Find-AbyssExitButtonPoint 와 같은 영역(clearAndExitText)·배율 3·ko 엔진의 한 판독 → @{ Text; Retry; Other }
#      (키 정확히 셋, Text = 단어를 이어 붙이고 공백 제거). 캡처 실패면 Text '' · 두 점 null 이고, 실패인지는 호출부가 캡처 실패 플래그·일련번호로
#      봅니다(규칙 15 - 이 함수는 플래그를 읽지도 풀지도 않음). 점은 기준 좌표(1272x717)라 호출부는 Click-GamePoint 로 누릅니다.
# 단어 목록의 출처: 던전이미지\ 아래 보관 프레임(경로는 각 목록 위 주석)을 워커와 같은 경로(clearAndExitText (430,570,420,125) · 배율 3 · ko)로
#   읽은 실측 문자열과 기준 좌표를 글자·좌표 그대로 옮겼습니다(명세 부록 B.1 - 같은 모델의 사본이 아니라 판독). 경계 행(PB)만 PF1 목록을 소스 상수
#   자리로 옮긴 합성이라, 상수가 바뀌면 PB 는 따라 움직이고 관측 행(PF·PH·PN·PX)은 관측에 묶여 남습니다.
# 행: PF 짝 둘 · PH 한쪽만(관측 결측) · PN 짝 없음(다른 화면·대역 밖 - 오탐 검증) · PX 서명 거짓·짝 있음 · PB 경계 · PK 화면 함수 계약(기록 스텁) · PT 정적
# 보관 캡처·OCR 엔진 없이 늘 돌아 SKIP 경로가 없습니다 - 보관 프레임 재생 단언은 tests\test_abyss_party_signatures.ps1 (④ 짝 찾기)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
$fails = 0

function Check-Equal {
    # 결과 한 줄 - 문자열로 비교합니다(대소문자 구분). 실패는 'FAIL …' 줄 + 실패 수 +1 (러너가 'FAIL' 줄과 종료 코드로 집계)
    param([string]$Name, $Actual, $Expected)
    if ("$Actual" -ceq "$Expected") { "OK   $Name" }
    else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

# ── 0. 준비: 워커 파싱 · 운영 함수 원문 추출 · 상수 대입문 캡처 (사본 재구현 금지) ─────────────────────────────
# 워커를 한 번 파싱해 AST 와 주석 뺀 사본을 같은 오프셋으로 씁니다 (Remove-SourceComments 는 주석을 같은 길이 공백으로 바꿈 - test_abyss_menu_icon 과 같은 방식)
$workerText = [IO.File]::ReadAllText($workerPath)
$workerTokens = $null; $workerParseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseInput($workerText, [ref]$workerTokens, [ref]$workerParseErrors)
if ($workerParseErrors.Count -gt 0) { "FAIL 준비: 워커 파싱 오류 $($workerParseErrors.Count)건 - 첫 오류: $($workerParseErrors[0].Message)"; exit 1 }
$workerCode = Remove-SourceComments -Text $workerText

# 시험 대상 두 함수 + 3버튼 서명(⑤ 가 같은 판독문으로 보는 Test-AbyssRewardText)을 소스 원문 그대로 실행합니다 - 못 찾으면 FAIL 로 끝냅니다
# (한 번의 호출로 추출 - 워커 2만 줄을 이름마다 다시 파싱하지 않음. 없는 함수 이름은 예외 문구에 남음)
$TARGET_FUNCTIONS = @('Select-AbyssRewardButtonPair', 'Find-AbyssRewardButtonPair')
$sourceDefinitions = @()
try {
    $sourceDefinitions = @(Get-SourceFunctionDefinitions -Path $workerPath -Names @($TARGET_FUNCTIONS + 'Test-AbyssRewardText'))
} catch {
    "FAIL 준비: 워커에서 함수 원문을 추출하지 못했습니다 ($($_.Exception.Message))"
    exit 1
}
foreach ($definition in $sourceDefinitions) { Invoke-Expression ([string]$definition) }

# 함수 정의 AST (같은 이름이면 첫 정의 - Get-SourceFunctionDefinitions 와 같은 선택)
$functionAsts = @{}
foreach ($functionAst in $workerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    if (-not $functionAsts.ContainsKey($functionAst.Name)) { $functionAsts[$functionAst.Name] = $functionAst }
}

function Get-FunctionCode {
    # 함수 정의의 주석 뺀 사본 - 전체 사본을 AST 범위로 잘라 냅니다 (같은 원문을 파싱했으므로 오프셋이 같음)
    param([string]$Name)
    if (-not $functionAsts.ContainsKey($Name)) { throw "워커에서 함수를 찾지 못했습니다: $Name" }
    $extent = $functionAsts[$Name].Extent
    return $workerCode.Substring($extent.StartOffset, $extent.EndOffset - $extent.StartOffset)
}
function Get-NodeCode {
    # AST 노드 하나의 주석 뺀 사본 (명령 한 개의 인자 단언용)
    param($Node)
    return $workerCode.Substring($Node.Extent.StartOffset, $Node.Extent.EndOffset - $Node.Extent.StartOffset)
}
function Get-EnclosingFunctionName {
    # 노드를 감싼 가장 안쪽 함수 이름 (최상위면 '')
    param($Node)
    $parentNode = $Node.Parent
    while ($null -ne $parentNode) {
        if ($parentNode -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return [string]$parentNode.Name }
        $parentNode = $parentNode.Parent
    }
    return ''
}
function Get-AssignedVariableName {
    # 대입문 왼쪽 변수 이름 - 범위 접두('script:' 등)는 뗍니다 (함수 안에서 $script:상수 를 바꾸는 대입도 같은 이름으로 셈)
    param($AssignmentAst)
    $left = $AssignmentAst.Left
    while ($left -is [System.Management.Automation.Language.AttributedExpressionAst]) { $left = $left.Child }   # [int]$x = … 꼴
    if ($left -is [System.Management.Automation.Language.VariableExpressionAst]) { return ($left.VariablePath.UserPath -replace '^.*:', '') }
    return ''
}
function Get-CommandNames {
    # 노드 아래 명령 호출 이름 전부 (열거용 - 호출부에서 @() 로 모음)
    param($Root)
    return @($Root.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { [string]$_.GetCommandName() })
}

# 상수 셋과 하단 영역은 워커 최상위(함수 밖) 대입문을 그대로 실행해 캡처합니다 (config 미정의 → 기본값 - test_abyss_party_signatures 와 같은 모의).
# 못 찾으면 FAIL 로 끝냅니다. 대입 개수·우변 모양(config 읽기 없음)은 PT5 가 따로 단언합니다
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
$allAssignments = @($workerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))
foreach ($variableName in @('abyssRetryPairBandX', 'abyssOtherPairBandX', 'abyssPairMaxDy', 'rgClearExit')) {
    $topAssignments = @($allAssignments | Where-Object { ((Get-AssignedVariableName $_) -eq $variableName) -and ((Get-EnclosingFunctionName $_) -eq '') })
    if ($topAssignments.Count -lt 1) { "FAIL 준비: 워커 최상위(함수 밖)에서 `$$variableName 대입문을 찾지 못했습니다"; exit 1 }
    Invoke-Expression $topAssignments[0].Extent.Text
}
# 화면 함수가 넘기는 엔진을 확인하는 표식 값 (실제 OCR 엔진 없음 - PK1). 영어 엔진도 다른 표식이라 엔진을 바꾸면 PK1 이 걸립니다
$ocrKoreanEngine = 'ko-engine-marker'
$ocrEnglishEngine = 'en-engine-marker'
$script:screenCaptureFailing = $false
$script:captureFailSerial = 0

# ── 단어 헬퍼 · 판정 헬퍼 ─────────────────────────────────────────────────────────
function W {
    # 판독 단어 한 개 = Get-GameRegionOcrWords 가 돌려주는 모양 그대로 @{ Text; X; Y } (기준 좌표)
    param([string]$Text, [int]$X, [int]$Y = 654)
    @{ Text = $Text; X = $X; Y = $Y }
}
function Format-PairPoint {
    # 점 → 'X,Y', 없음 → 'null'
    param($Point)
    if ($null -eq $Point) { return 'null' }
    return ('{0},{1}' -f $Point.X, $Point.Y)
}
function Get-PairText {
    # 순수 판정 한 번 → 'Retry / Other'. 예외는 'THREW: …' 로 돌려 그 행만 FAIL 로 남깁니다
    param([object[]]$Words)
    try {
        $pair = Select-AbyssRewardButtonPair -Words $Words
        return ('{0} / {1}' -f (Format-PairPoint $pair.Retry), (Format-PairPoint $pair.Other))
    } catch {
        return ('THREW: ' + $_.Exception.Message)
    }
}
function Get-PairPresence {
    # 순수 판정 한 번 → 한 종류(Retry · Other)의 점 유무만 'point' / 'null' (경계 행 - 좌표 값은 PF 행이 봄)
    param([object[]]$Words, [string]$Kind)
    try {
        $pair = Select-AbyssRewardButtonPair -Words $Words
        if ($null -eq $pair.$Kind) { return 'null' }
        return 'point'
    } catch {
        return ('THREW: ' + $_.Exception.Message)
    }
}
function Join-WordText {
    # 판독문 = 단어 Text 를 공백 없이 이어 붙인 문자열 (부록 B.1 의 정의 - 서명 판정의 입력)
    param([object[]]$Words)
    if (-not $Words) { return '' }
    return ((@($Words | ForEach-Object { [string]$_.Text }) -join '') -replace '\s', '')
}
function Copy-WordsWithChange {
    # 경계 합성: 단어 목록을 복제하고 Text 가 같은 단어 하나의 X·Y 만 바꿉니다 (해시테이블은 참조형이라 원본 PF1 목록을 지키려고 복제).
    # 바꿀 단어가 정확히 1개가 아니면 합성이 틀린 것이므로 throw 합니다 (테스트 자체의 오류 - 러너가 실패로 계상)
    param([object[]]$Words, [string]$Text, $X = $null, $Y = $null)
    $changedCount = 0
    $copies = foreach ($word in $Words) {
        $clone = @{ Text = $word.Text; X = $word.X; Y = $word.Y }
        if ($word.Text -ceq $Text) {
            if ($null -ne $X) { $clone.X = [int]$X }
            if ($null -ne $Y) { $clone.Y = [int]$Y }
            $changedCount++
        }
        $clone
    }
    if ($changedCount -ne 1) { throw "경계 합성: '$Text' 단어가 정확히 1개가 아닙니다 ($changedCount)" }
    return $copies
}

# ── 단어 목록 (명세 부록 B.1 - 배율 3 ko · clearAndExitText 판독 그대로, 단어@(X,Y) = 기준 좌표) ──────────────────────
# 경로는 던전이미지\ 기준. P4L = 어비스\20260921_파티장4인_토글ON풀파티_다시하기_팝업없음_보상화면대기_준비패널_실측 ·
# P2L = 어비스\20260921_파티장2인_다시하기_인원부족팝업_다른던전가기_상세2버튼_실측 · P4M = 어비스\20260921_파티원4인_준비완료버튼_필드_보상화면_파티장나가기뒤_나가기수동_실측 ·
# P4O = 어비스\20260921_파티장4인_토글OFF_입장하기_파티패널준비취소_다른던전가기2회_실측 · LIVE = 어비스\20260926_준비패널4인_준비취소_나가기_수동실측 ·
# S18 = 어비스\20260918_다시하기_다른던전가기_실측\session_232038 · K2 = 어비스\20261008_메뉴아이콘_실기3_2차\frames (콘솔 전환 - 1276x719 창 재구성) ·
# K1 = 어비스\20261008_메뉴아이콘_실기3_콘솔전환\frames · E6 = 어비스\20261001_⑥e_실기
# PF1 · PR2 - P4L\cap_211713_987_1272x717.png (D2) · 1272
$wordsPF1 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '를' 687 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 475 654), (W 'Space' 577 630), (W '다세' 614 654), (W '하기' 657 654), (W '다른' 761 654), (W '던전' 796 654), (W '가기' 832 654))
# PF2 · PR2 - P4L\cap_211718_175_1272x717.png (D1) · 1272
$wordsPF2 = @((W '나가기' 475 654), (W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 653 591), (W 'Space' 577 630), (W '다세' 614 654), (W '하기' 657 654), (W '人있습니다' 733 591), (W '다른' 761 654), (W '던전' 796 654), (W '가기' 832 654))
# PF3 · PR2 - LIVE\cap_230054_361_1272x717.png (L2-pre) · 1272
$wordsPF3 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 475 654), (W 'Space' 577 630), (W '다셔' 614 654), (W '하기' 657 654), (W '다른' 761 654), (W '던전' 796 654), (W '가기' 832 654))
# PF4 - 어비스\20260918_보상화면_3버튼_나가기_다시하기_다른던전가기_1270x702.png · 1270x702
$wordsPF4 = @((W '아이템을' 533 591), (W '누르면' 582 591), (W '상세' 619 591), (W '정보테' 656 591), (W '볼' 686 591), (W '수' 703 591), (W '있습니다' 740 591), (W '나가기' 478 654), (W 'Space' 579 630), (W '다세' 615 654), (W '하기' 657 654), (W '다른' 759 654), (W '던전' 794 654), (W '가기' 829 654))
# PF5 - K2\cap_092019_589_1914x1079.png (재구성 1276x719) · 콘솔 전환
$wordsPF5 = @((W '아이템을' 533 590), (W '누르면' 583 591), (W '상세' 619 590), (W '정보코' 656 591), (W '볼' 686 591), (W '수' 703 591), (W '있습니다' 739 590), (W '나가기' 479 652), (W 'Space' 579 628), (W '다세' 615 652), (W '하기' 657 652), (W '다른' 758 652), (W '던전' 793 652), (W '가기' 828 652))
# PF6 · PR5 - K1\cap_090150_009_1908x1076.png · 1908 DPI 96
$wordsPF6 = @((W '아이템을' 539 604), (W '누르면' 586 604), (W '상세' 620 604), (W '정보를' 654 604), (W '볼' 683 604), (W '수' 698 604), (W '있습니다' 733 604), (W 'iC' 434 638), (W '나가기' 488 662), (W 'Space' 582 639), (W '다시' 616 662), (W '하기' 655 662), (W '다른' 750 662), (W '던전' 784 662), (W '가기' 816 662))
# PF7 · PR5 - E6\frames2\cap_132837_833_1908x1076.png · 1908 DPI 144
$wordsPF7 = @((W '아이템을' 541 604), (W '누르면' 586 604), (W '상세' 620 604), (W '정보를' 654 604), (W '볼' 682 604), (W '수' 697 604), (W '있습니다' 732 604), (W 'SC' 436 638), (W '나가기' 491 660), (W 'Space' 583 638), (W '다셔' 616 660), (W '하기' 655 660), (W '다른' 749 660), (W '던전' 781 660), (W '가기' 813 660))
# PF8 - P2L\cap_183204_455_1272x717.png · 1272(슬라이드)
$wordsPF8 = @((W '아이템을' 530 616), (W '누르면' 581 616), (W '상세' 618 616), (W '정보를' 656 616), (W '수' 704 616), (W '있습니다' 742 616), (W '나가기' 475 679), (W 'Space' 577 655), (W '다세' 614 679), (W '하기' 657 679), (W '다른' 761 680), (W '던전' 796 679), (W '가기' 832 679))
# PF9 - P2L\cap_183209_768_1272x717.png · 1272
$wordsPF9 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 475 654), (W 'Space' 577 630), (W '다세' 614 654), (W '하기' 657 654), (W '다른' 762 654), (W '던전' 796 654), (W '가)' 828 654))
# PH1 · PR2 - P2L\cap_182611_831_1272x717.png (G3) · 1272
$wordsPH1 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '를' 687 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 475 654), (W 'Space' 577 630), (W '하기' 657 654), (W '다른' 761 654), (W '던전' 796 654), (W '가기' 832 654))
# PH2 - S18\frame_232120_187_chg.png · 1272
$wordsPH2 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '를' 687 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 475 654), (W 'Space' 577 630), (W '다' 605 654), (W '하기' 657 654), (W '다른' 761 654), (W '던전' 796 654), (W '가기' 832 654))
# PH3 - P4O\cap_203453_300_1272x717.png · 1272
$wordsPH3 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 475 654), (W 'Space' 577 630), (W 'Ⅸl하기' 642 654), (W '다른' 761 654), (W '던전' 796 654), (W '가기' 832 654))
# PH4 · PR2 - LIVE\cap_230444_675_1272x717.png (L4) · 1272
$wordsPH4 = @((W '나가기' 475 654), (W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W 'Space' 577 630), (W '다세' 614 654), (W '하기' 657 654), (W '던전' 796 654), (W '가기' 833 654))
# PH5 - S18\frame_232511_842_chg.png · 1272
$wordsPH5 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 475 654), (W 'Space' 577 630), (W '다세' 614 654), (W '하기' 657 654), (W '다르' 760 654), (W '더전' 796 654), (W '가기' 833 654))
# PH6 - S18\frame_232512_905_chg.png · 1272
$wordsPH6 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 475 654), (W 'Space' 577 630), (W '다세' 614 654), (W '하기' 657 654), (W '다' 754 655), (W '전가기' 822 654))
# PH7 - E6\frames2\cap_143417_989_1908x1076.png · 1908 DPI 144
$wordsPH7 = @((W '아이템을' 541 607), (W '누르면' 586 607), (W '상세' 620 607), (W '정보를' 654 607), (W '볼' 682 607), (W '수' 697 607), (W '있습니다' 732 607), (W 'SC' 436 641), (W '나가기' 491 664), (W 'Space' 583 642), (W '하기' 655 664), (W '다른' 749 664), (W '던전' 781 664), (W '가기' 813 664))
# PN1 - P4M\cap_212549_580_1272x717.png (A1) · 1272
$wordsPN1 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 515 654), (W '파티장' 714 654), (W '선택' 765 654), (W '대기' 808 654))
# PN2 - LIVE\cap_230558_237_1272x717.png (L5f) · 1272
$wordsPN2 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나가기' 492 654), (W '입장' 700 654), (W '대기' 743 654), (W '중' 776 654))
# PN3 - P4M\cap_212550_642_1272x717.png (B1) · 1272
$wordsPN3 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '7' 687 591), (W 'Space' 749 631), (W '나가기' 492 654))
# PN4 - P4L\cap_211722_423_1272x717.png (C1) · 1272
$wordsPN4 = @((W '0田l들1을' 530 591), (W '누르면' 581 591), (W '상)(Ⅱ' 618 591), (W '정보를' 656 591), (W '모든' 839 597))
# PN5 - 어비스\20260918_다시하기_01_클릭직후_우연한만남패널_1of4_1272x717.png · 1272
$wordsPN5 = @((W '사제' 795 584), (W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '7' 687 591), (W '나가기' 492 654))
# PN6 - P2L\cap_182613_955_1272x717.png (G4) · 1272
$wordsPN6 = @((W '㉬' 486 618), (W '취소' 529 618), (W 'Space' 655 594), (W '도전하기' 742 618))
# PN7 - LIVE\cap_230532_362_1272x717.png (L5+1) · 1272
$wordsPN7 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '저曰曇' 656 592), (W '한수' 696 591), (W '있습니다' 742 591), (W '3다취소' 510 631), (W '나가기' 492 654), (W '도전하기' 742 631))
# PN8 - 어비스\20260918_다른던전가기_01b_카드클릭후_상세화면_광기의동굴_함께하기_1272x717.png (S1b) · 1272
$wordsPN8 = @((W '428' 445 605), (W 'Space' 761 629), (W '1,000' 466 648))
# PN9 - K1\cap_090147_790_1908x1076.png · 1908 DPI 96
$wordsPN9 = @((W '화면을' 576 656), (W '터치öH' 636 656), (W '주세요' 695 656))
# PN10 - 어비스\20260918_다른던전가기_01_어비스선택오버레이_3카드_X_1272x717.png (S1) · P2L\cap_183211_892 (O3) · P2L\cap_182609_705 (G2) · 어비스\20260921_파티원2인_자동준비패널_보상화면_파티장선택대기_필드이동_실측\cap_185218_142 (F1) · 1272
$wordsPN10 = @()
# PN11 · PR4′ - 공통\20260917_Log폴더_덮어쓰기_보존_원본사본\error_20260902_h02m53s39.png (02:52:09·02:55:08 두 장도 같음) · 1272
$wordsPN11 = @((W '시작' 489 618), (W '화면으로' 550 618), (W 'Space' 655 594), (W '다세' 702 618), (W '시도하기' 763 618))
# PN12 - 어시스트\네트워크불안정_다시시도_1810.png · 1810x1020
$wordsPN12 = @((W '시작' 488 619), (W '화면으로' 550 619), (W 'Space' 655 594), (W '다셔' 702 619), (W 'kl도하기' 764 619))
# PN13 - 심층던전\20260911_심층결과화면_다시하기_미탐지_1908\error_20260911_h12m17s58.png · 1908(심층 결과)
$wordsPN13 = @((W '아이템을' 531 592), (W '누르면' 581 592), (W '상세' 618 592), (W '정보를' 656 592), (W '目' 687 592), (W '수' 704 592), (W '있습니다' 742 592), (W '나가기' 515 655), (W '다셔' 735 655), (W '하기' 778 655))
# PN14 - S18\frame_232503_344_chg.png (frame_232604_906 도 같음) · 1272(탐색기가 가림)
$wordsPN14 = @((W '202(' 834 594), (W '20260918-다시' 489 610), (W '화기-06-던전내' 488 625), (W 'HUD' 464 654), (W '1272x7...' 507 654), (W '20260918-보상' 607 610), (W '화면-3버튼-나가' 607 625), (W '기-다시하기-다' 607 640), (W '른던전가기-12..' 605 655), (W '20260918-보상' 725 610), (W '화면-화단버튼-' 725 625), (W '확대x2.png' 725 640))
# PN15 - E6\frames_2인_실기1\cap_203439_510_1272x717.png · 1272(컨트롤 패널 글이 가림)
$wordsPN15 = @((W '1' 434 610), (W '필요)' 468 610), (W '|(파티장)' 466 629), (W ',으로' 526 628), (W '자동화를' 586 629), (W '2판' 641 629), (W '들립니다.' 699 629), (W '이' 754 629), (W 'pc는' 790 629), (W '그대' 832 629), (W '다시' 484 648), (W '입장할' 534 648), (W '때,' 579 648), (W '보상' 618 648), (W '화면에' 668 648), (W '남은' 718 648), (W '이' 751 648), (W 'pc에' 786 648), (W '준비' 829 648))
# PN16 - E6\frames_2인_실기1\cap_214010_416_1272x717.png · 1272
$wordsPN16 = @((W '패하기' 455 660), (W '선물하기' 586 660), (W '메치지' 716 660), (W '보내기' 768 660))
# PN17 - E6\frames2\cap_151823_863_1908x1076.png · 1908 DPI 144
$wordsPN17 = @((W 'ESC' 481 651), (W '배가' 594 591), (W '고파온다!' 656 591), (W '6' 556 670), (W '지리누에å|尸매하기' 709 660))
# PX1 - P4L\cap_212020_861_1272x717.png · 1272
$wordsPX1 = @((W '아이템을' 530 591), (W '누르면' 581 591), (W '상세' 618 591), (W '정보를' 656 591), (W '수' 704 591), (W '있습니다' 742 591), (W '나)' 462 654), (W '기' 494 654), (W 'Space' 577 630), (W '다세' 614 654), (W '하기' 657 654), (W '다른' 761 654), (W '던전' 796 654), (W '가기' 832 654))
# PX2 - K1\cap_085849_011_1908x1076.png · 1908 DPI 96
$wordsPX2 = @((W '아이템을' 539 604), (W '누르면' 586 604), (W '상세' 620 604), (W '정보를' 654 604), (W '볼' 683 604), (W '수' 698 604), (W '있습니다' 733 604), (W 'iC' 434 638), (W 'Space' 582 639), (W '다시' 616 662), (W '하기' 655 662), (W '다른' 750 662), (W '던전' 784 662), (W '가기' 816 662))
# PX3 - K2\cap_091548_366_1914x1079.png (재구성 1276x719) · 콘솔 전환
$wordsPX3 = @((W '아이템을' 533 591), (W '누르면' 583 591), (W '상세' 619 590), (W '정보旦' 656 591), (W '볼' 686 591), (W '수' 703 591), (W '있습니다' 740 591), (W 'Space' 579 628), (W '다세' 615 652), (W '하기' 657 652), (W '다른' 758 652), (W '던전' 793 652), (W '가기' 828 652))
# PF1 판독문 (부록 B.1 의 예 그대로 - 09-26 판독문표 D2 행과 같음)
$PF1_TEXT = '아이템을누르면상세정보를를수있습니다나가기Space다세하기다른던전가기'

# ── 1. PF 짝 둘 (관측) ─────────────────────────────────────────────────────────────
Check-Equal 'PF1 D2 (09-21 P4L · 1272) → (636,654)·(778,654) - 설계 관측값 · 반올림 635.5→636 · 778.5→778' (Get-PairText $wordsPF1) '636,654 / 778,654'
Check-Equal "PF2 D1 (1272 - 단어 순서 뒤섞임: '나가기' 가 맨 앞 · '人있습니다' 끼어듦) → (636,654)·(778,654) - 목록 순서 무관" (Get-PairText $wordsPF2) '636,654 / 778,654'
Check-Equal "PF3 L2-pre (실기 -1 · 1272 - '다셔') → (636,654)·(778,654) - 조각 '다셔'" (Get-PairText $wordsPF3) '636,654 / 778,654'
Check-Equal 'PF4 1270x702 (09-18 21:02) → (636,654)·(776,654) - 776.5→776' (Get-PairText $wordsPF4) '636,654 / 776,654'
Check-Equal 'PF5 콘솔 전환 재구성 1276x719 (10-08 cap_092019_589) → (636,652)·(776,652) - 775.5→776' (Get-PairText $wordsPF5) '636,652 / 776,652'
Check-Equal "PF6 1908 창 DPI 96 (10-08 cap_090150_009 - '다시') → (636,662)·(767,662) - 조각 '다시' · 렌더" (Get-PairText $wordsPF6) '636,662 / 767,662'
Check-Equal "PF7 1908 창 DPI 144 (10-01 ⑥e frames2 cap_132837_833 - '다셔') → (636,660)·(765,660) - 렌더" (Get-PairText $wordsPF7) '636,660 / 765,660'
Check-Equal "PF8 등장 슬라이드 중 (09-21 P2L cap_183204_455 - '다른'@680 · '던전'@679) → (636,679)·(778,680) - dY 1 · Y 679.5→680" (Get-PairText $wordsPF8) '636,679 / 778,680'
Check-Equal "PF9 09-21 P2L cap_183209_768 ('다른'@762 · '가)'@828) → (636,654)·(779,654) - '가기' 와 무관" (Get-PairText $wordsPF9) '636,654 / 779,654'

# ── 2. PH 한쪽만 (관측 결측 - PH1~PH6 은 게임이 그린 커서가 그 버튼 글자를 가림, PH7 은 커서 없는 보상 화면 첫 프레임) ─────────
Check-Equal "PH1 G3 (09-21 P2L - 'Space 하기', '다시' 탈락 · 커서가 '다시' 위) → Retry null · Other (778,654)" (Get-PairText $wordsPH1) 'null / 778,654'
Check-Equal "PH2 09-18 frame_232120_187 ('다'@605 + 하기) → Retry null · Other (778,654) - '다' 단독은 머리가 아님" (Get-PairText $wordsPH2) 'null / 778,654'
Check-Equal "PH3 09-21 P4O cap_203453_300 ('Ⅸl하기'@642) → Retry null · Other (778,654) - 깨짐 조각 미채택" (Get-PairText $wordsPH3) 'null / 778,654'
Check-Equal "PH4 L4 (실기 -1 - '다른' 탈락: 던전@796 가기@833) → Retry (636,654) · Other null - 단독 단어 미채택" (Get-PairText $wordsPH4) '636,654 / null'
Check-Equal "PH5 09-18 frame_232511_842 ('다르'@760 '더전'@796) → Retry (636,654) · Other null - 깨짐 조각 미채택" (Get-PairText $wordsPH5) '636,654 / null'
Check-Equal "PH6 09-18 frame_232512_905 ('다'@754 '전가기'@822) → Retry (636,654) · Other null - 깨짐 조각 미채택" (Get-PairText $wordsPH6) '636,654 / null'
Check-Equal "PH7 ⑥e frames2 cap_143417_989 (1908 DPI 144 보상 화면 첫 프레임 · 커서 없음 - '하기' 만) → Retry null · Other (765,664) - 머리 단어 자체가 없음" (Get-PairText $wordsPH7) 'null / 765,664'

# ── 3. PN 짝 없음 (관측 - 다른 화면 · 대역 밖, 오탐 검증) ─────────────────────────────────────────
Check-Equal "PN1 A1 파티원 보상 2버튼 (09-21 P4M - '나가기' + '파티장 선택 대기') → 짝 없음 - 파티장@714 선택@765 대기@808 은 조각 아님" (Get-PairText $wordsPN1) 'null / null'
Check-Equal "PN2 L5f 접힌 준비 패널 (실기 -1 - '나가기' + '입장 대기 중') → 짝 없음" (Get-PairText $wordsPN2) 'null / null'
Check-Equal "PN3 B1 보상 위 준비 패널 (09-21 P4M - '나가기'@492 만) → 짝 없음" (Get-PairText $wordsPN3) 'null / null'
Check-Equal 'PN4 C1 패널 행 소실 (09-21 P4L) → 짝 없음' (Get-PairText $wordsPN4) 'null / null'
Check-Equal "PN5 09-18 다시하기_01 재매칭 패널 1/4 ('사제…7나가기') → 짝 없음" (Get-PairText $wordsPN5) 'null / null'
Check-Equal "PN6 G4 권장 인원 팝업 (09-21 P2L - '도전하기'@742) → 짝 없음 - 꼬리 조각만 있고 머리 없음" (Get-PairText $wordsPN6) 'null / null'
Check-Equal "PN7 L5+1 팝업 소멸 중 (실기 -1 - '3다취소'@510) → 짝 없음 - '3다취소' 는 머리가 아님" (Get-PairText $wordsPN7) 'null / null'
Check-Equal 'PN8 S1b 상세 화면 (09-18) → 짝 없음' (Get-PairText $wordsPN8) 'null / null'
Check-Equal 'PN9 1908 DPI 96 클리어 문구 (10-08 cap_090147_790) → 짝 없음' (Get-PairText $wordsPN9) 'null / null'
Check-Equal "PN10 빈 판독 (선택 오버레이 S1·O3 · G2 · F1 - 캡처 성공 · 판독 '') → 짝 없음 (빈 판독은 캡처 실패가 아님 - PK4)" (Get-PairText $wordsPN10) 'null / null'
Check-Equal "PN11 네트워크 불안정 팝업 1272 (09-02 error_20260902_h02m53s39 - 다세@702 시도하기@763) → 짝 없음 - 머리는 대역 안 · 꼬리는 대역 밖 ('다시 시도하기')" (Get-PairText $wordsPN11) 'null / null'
Check-Equal "PN12 네트워크 불안정 팝업 1810 (어시스트 - 다셔@702 kl도하기@764) → 짝 없음 - 꼬리 대역 밖" (Get-PairText $wordsPN12) 'null / null'
Check-Equal "PN13 심층 결과 2버튼 (09-11 1908 - 다셔@735 하기@778) → 짝 없음 · 3버튼 서명은 참 ('나가기'+'다셔'+'하기' - ⑤ 분류 reward3 → no-pair → 폴백)" ('{0} | 서명 {1}' -f (Get-PairText $wordsPN13), (Test-AbyssRewardText -Text (Join-WordText $wordsPN13))) 'null / null | 서명 True'
Check-Equal "PN14 탐색기가 게임 창을 가림 (09-18 frame_232503_344 - 20260918-다시@(489,610) · 기-다시하기-다@(607,640)) → 짝 없음 · 서명은 참 (머리 대역 밖 · 붙은 단어 미채택)" ('{0} | 서명 {1}' -f (Get-PairText $wordsPN14), (Test-AbyssRewardText -Text (Join-WordText $wordsPN14))) 'null / null | 서명 True'
Check-Equal "PN15 컨트롤 패널 설명문이 가림 (10-01 ⑥e frames_2인_실기1 - 다시@484) → 짝 없음 - 머리 대역 밖 · 꼬리 없음" (Get-PairText $wordsPN15) 'null / null'
Check-Equal "PN16 선물 창 (10-01 ⑥e frames_2인_실기1 - 선물하기@586) → 짝 없음 - 꼬리 조각만 대역 안 · 머리 없음" (Get-PairText $wordsPN16) 'null / null'
Check-Equal "PN17 음식 구매 팝업 (10-01 ⑥e frames2 · 1908 - …매하기@709) → 짝 없음 - 꼬리 조각만 대역 안 · 머리 없음" (Get-PairText $wordsPN17) 'null / null'

# ── 4. PX 서명 거짓 · 짝 있음 (관측 - '나가기' 를 누른 직후 커서가 그 위: 짝은 서명을 보지 않음) ────────────────────────
Check-Equal "PX1 09-21 P4L cap_212020_861 ('나)'@462 '기'@494) → (636,654)·(778,654) · 서명 거짓" ('{0} | 서명 {1}' -f (Get-PairText $wordsPX1), (Test-AbyssRewardText -Text (Join-WordText $wordsPX1))) '636,654 / 778,654 | 서명 False'
Check-Equal "PX2 1908 DPI 96 cap_085849_011 ('나가기' 없음 - '다시') → (636,662)·(767,662) · 서명 거짓" ('{0} | 서명 {1}' -f (Get-PairText $wordsPX2), (Test-AbyssRewardText -Text (Join-WordText $wordsPX2))) '636,662 / 767,662 | 서명 False'
Check-Equal "PX3 콘솔 전환 재구성 cap_091548_366 ('나가기' 없음) → (636,652)·(776,652) · 서명 거짓" ('{0} | 서명 {1}' -f (Get-PairText $wordsPX3), (Test-AbyssRewardText -Text (Join-WordText $wordsPX3))) '636,652 / 776,652 | 서명 False'

# ── 5. PB 경계 (합성 - PF1 단어 목록을 소스 상수 자리로 옮김. 숫자를 다시 박지 않고 소스 값을 따라감) ────────────────────────
$retryBandStart = [int]$abyssRetryPairBandX[0]; $retryBandEnd = [int]$abyssRetryPairBandX[1]
$otherBandStart = [int]$abyssOtherPairBandX[0]; $otherBandEnd = [int]$abyssOtherPairBandX[1]
$pairMaxDy = [int]$abyssPairMaxDy
$retryHeadY = [int](@($wordsPF1 | Where-Object { $_.Text -ceq '다세' })[0].Y)
$otherHeadY = [int](@($wordsPF1 | Where-Object { $_.Text -ceq '다른' })[0].Y)
$pb1 = '{0}/{1}' -f (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '다세' -X $retryBandStart) 'Retry'), (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '다세' -X ($retryBandStart - 1)) 'Retry')
Check-Equal "PB1 Retry 머리 X = 대역 시작(${retryBandStart}) → 점 / 시작-1 → null (꼬리 X 그대로)" $pb1 'point/null'
$pb2 = '{0}/{1}' -f (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '하기' -X $retryBandEnd) 'Retry'), (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '하기' -X ($retryBandEnd + 1)) 'Retry')
Check-Equal "PB2 Retry 꼬리 X = 대역 끝(${retryBandEnd}) → 점 / 끝+1 → null (PN11 의 합성 짝 - 꼬리도 대역 안이어야 함)" $pb2 'point/null'
$pb3Head = '{0}/{1}' -f (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '다른' -X $otherBandStart) 'Other'), (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '다른' -X ($otherBandStart - 1)) 'Other')
$pb3Tail = '{0}/{1}' -f (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '던전' -X $otherBandEnd) 'Other'), (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '던전' -X ($otherBandEnd + 1)) 'Other')
Check-Equal "PB3 Other 머리 X = 대역 시작(${otherBandStart}) 점 / -1 null · 꼬리 X = 대역 끝(${otherBandEnd}) 점 / +1 null" ('머리 {0} · 꼬리 {1}' -f $pb3Head, $pb3Tail) '머리 point/null · 꼬리 point/null'
# 꼬리가 머리 아래(+)·위(-) 두 방향 - 한도는 |꼬리 Y - 머리 Y| 절댓값입니다(G2). 한쪽 방향만 재는 구현이 통과하지 않도록 위쪽도 봅니다
$pb4RetryDown = '{0}/{1}' -f (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '하기' -Y ($retryHeadY + $pairMaxDy)) 'Retry'), (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '하기' -Y ($retryHeadY + $pairMaxDy + 1)) 'Retry')
$pb4RetryUp = '{0}/{1}' -f (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '하기' -Y ($retryHeadY - $pairMaxDy)) 'Retry'), (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '하기' -Y ($retryHeadY - $pairMaxDy - 1)) 'Retry')
$pb4OtherDown = '{0}/{1}' -f (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '던전' -Y ($otherHeadY + $pairMaxDy)) 'Other'), (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '던전' -Y ($otherHeadY + $pairMaxDy + 1)) 'Other')
$pb4OtherUp = '{0}/{1}' -f (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '던전' -Y ($otherHeadY - $pairMaxDy)) 'Other'), (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '던전' -Y ($otherHeadY - $pairMaxDy - 1)) 'Other')
Check-Equal "PB4 꼬리 Y = 머리 Y ± dY 한도(${pairMaxDy}) → 점 / ±(한도+1) → null (Retry · Other 각각, 꼬리가 머리 아래·위 모두 - 점의 좌표 값은 PF·PB10 행이 봄)" ('Retry 아래 {0} · 위 {1} · Other 아래 {2} · 위 {3}' -f $pb4RetryDown, $pb4RetryUp, $pb4OtherDown, $pb4OtherUp) 'Retry 아래 point/null · 위 point/null · Other 아래 point/null · 위 point/null'
Check-Equal "PB5 꼬리가 머리 왼쪽 (하기@600 · 다세@614) → Retry null (꼬리 X > 머리 X - G2)" (Get-PairPresence (Copy-WordsWithChange $wordsPF1 '하기' -X 600) 'Retry') 'null'
Check-Equal "PB6a '가기' 만 → 둘 다 null ('가기' 는 어휘가 아님 - '나가기' 와 겹침)" (Get-PairText @((W '가기' 832 654))) 'null / null'
Check-Equal "PB6b '던전'·'가기' 만 (L4 꼴 - 머리 '다른' 없음) → 둘 다 null (단독 단어 미채택)" (Get-PairText @((W '던전' 796 654), (W '가기' 833 654))) 'null / null'
Check-Equal "PB6c '나가기' 만 → 둘 다 null" (Get-PairText @((W '나가기' 475 654))) 'null / null'
$wordsPB7 = @($wordsPF1 | Where-Object { @('다세', '하기', '다른', '던전') -notcontains $_.Text }) + @((W '다세하기' 636 654), (W '다른던전' 778 654))
Check-Equal "PB7 붙은 단어 '다세하기'@636 · '다른던전'@778 (각각 한 단어 · 대역 안) → 둘 다 null (꼬리는 머리 오른쪽의 다른 단어 - 붙은 판독 관측 0)" (Get-PairText $wordsPB7) 'null / null'
# 후보 여럿 (미관측 - 결정성만 고정, G4 '머리 X 최소 → 꼬리 X 최소 → 목록 앞'): 같은 후보를 두 순서로 넣습니다. 명세 순서(고를 쌍이 목록 앞)는
# '비교 없이 마지막 후보 채택'·동률 비교 -le 를, 반대 순서(고를 쌍이 목록 뒤)는 '첫 후보 채택' 을 잡습니다 - 한 순서만으로는 G4 가 고정되지 않습니다.
# 두 순서 모두 '오른쪽 머리 우선'·'큰 꼬리 우선' 을 잡고, 셋째 단계(머리·꼬리 X 가 모두 같으면 목록 앞 - 엄격 비교)는 PB8c 가 봅니다
$pb8aSpecOrder = Get-PairText @((W '다시' 600 654), (W '다세' 620 654), (W '하기' 660 654))
$pb8aReversed = Get-PairText @((W '다세' 620 654), (W '다시' 600 654), (W '하기' 660 654))
Check-Equal 'PB8a 머리 둘 (다시@600 · 다세@620) + 하기@660 → 머리 X 최소 쌍 (630,654) - 명세 순서 | 목록 순서 반대' ('{0} | {1}' -f $pb8aSpecOrder, $pb8aReversed) '630,654 / null | 630,654 / null'
$pb8bSpecOrder = Get-PairText @((W '다세' 614 654), (W '하기' 650 654), (W '하기' 700 654))
$pb8bReversed = Get-PairText @((W '다세' 614 654), (W '하기' 700 654), (W '하기' 650 654))
Check-Equal 'PB8b 꼬리 둘 (하기@650 · 하기@700) + 다세@614 → 꼬리 X 최소 쌍 (632,654) - 명세 순서 | 목록 순서 반대' ('{0} | {1}' -f $pb8bSpecOrder, $pb8bReversed) '632,654 / null | 632,654 / null'
Check-Equal 'PB8c 머리·꼬리 X 가 같은 두 쌍 (다세@(614,654) + 하기@(657,654) · 하기@(657,660)) → 목록 앞 쌍 (636,654) - G4 셋째 단계 · 엄격 비교 (-le 면 뒤 쌍 (636,657))' (Get-PairText @((W '다세' 614 654), (W '하기' 657 654), (W '하기' 657 660))) '636,654 / null'
Check-Equal 'PB9 빈 목록 @() · $null → 둘 다 null (고정 좌표로 채우지 않음 - G7)' ('{0} | {1}' -f (Get-PairText @()), (Get-PairText $null)) 'null / null | null / null'
# 클릭점 Y (G5 - 두 단어 중심 Y 의 중점, [Math]::Round 기본 = 짝수 쪽): 관측 행은 머리·꼬리 Y 가 같거나(PF1~PF7·PF9) 중점 679.5 가 짝수 쪽으로 머리 Y 680 과
# 같아(PF8) 'Y = 머리 Y'·'큰 쪽'·'AwayFromZero' 를 가르지 못합니다 - PF1 목록의 '하기'·'던전' Y 만 옮긴 합성 두 칸으로 고정합니다.
# 꼬리를 머리보다 2·1 만 옮겨, PT6② 가 허용하는 어떤 dY 한도(관측 최대 1 초과)에서도 짝이 섭니다 (상수와 무관한 고정 좌표 - PB5·PB7·PB8 과 같은 꼴)
$pb10Midpoint = Get-PairText (Copy-WordsWithChange (Copy-WordsWithChange $wordsPF1 '하기' -Y 656) '던전' -Y 656)
$pb10HalfStep = Get-PairText (Copy-WordsWithChange (Copy-WordsWithChange $wordsPF1 '하기' -Y 655) '던전' -Y 655)
Check-Equal "PB10 클릭점 Y = 두 단어 중심 Y 의 중점 - 꼬리 Y 656 (머리 654) → 655 (머리 Y·꼬리 Y·큰 쪽과 다름) | 꼬리 Y 655 → 654.5→654 짝수 쪽 (AwayFromZero·올림이면 655)" ('{0} | {1}' -f $pb10Midpoint, $pb10HalfStep) '636,655 / 778,655 | 636,654 / 778,654'
# 조각을 '담은' 단어 (G1·G2·G3 Contains - 3버튼 서명 Test-AbyssRewardText 와 같은 판별): 짝이 서는 관측 단어는 조각과 글자가 똑같아(다세·다시·다셔·하기·다른·던전)
# '완전 일치'·'앞 일치(StartsWith)'·'뒤 일치(EndsWith)' 비교를 가르지 못합니다 - 같은 영역에서 괄호가 단어 앞뒤에 붙어 읽힌 관측
# ('가)'@828 PF9 · '나)'@462 PX1 · '|(파티장)'@466 PN15) 꼴로 PF1 의 네 단어에 괄호를 붙인 합성 (머리 둘·꼬리 둘 각각 하나는 앞에, 하나는 뒤에 붙임)
$wordsPB11 = @($wordsPF1 | Where-Object { @('다세', '하기', '다른', '던전') -notcontains $_.Text }) + @((W '다세)' 614 654), (W '(하기' 657 654), (W '(다른' 761 654), (W '던전)' 796 654))
Check-Equal "PB11 조각을 담은 단어 '다세)'·'(하기'·'(다른'·'던전)' (괄호가 붙은 판독 꼴) → (636,654)·(778,654) - 완전 일치·앞 일치·뒤 일치 비교면 한쪽 이상 null" (Get-PairText $wordsPB11) '636,654 / 778,654'

# ── 6. PK 화면 함수 계약 (Get-GameRegionOcrWords 기록 스텁 - 프레임·OCR 엔진 없음) ───────────────────────────
function Get-GameRegionOcrWords {
    # 기록 스텁: 화면 함수가 넘긴 인자를 남기고, 모드에 따라 캡처 성공(단어 목록) 또는 캡처 실패를 흉내 냅니다.
    # 캡처 실패는 운영 캡처 계층(Get-GameRegionCapture → Register-CaptureFailure)이 남기는 표식 그대로 - 일련번호 +1 · 플래그 참 · 빈 배열
    param($Game, $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight, $Scale, $Engine)
    $script:stubCalls++
    $script:stubGame = $Game
    $script:stubRegion = '{0},{1},{2},{3}' -f $ReferenceX, $ReferenceY, $RegionWidth, $RegionHeight
    $script:stubScale = $Scale
    $script:stubEngine = $Engine
    if ($script:stubMode -eq 'capture-fail') {
        $script:captureFailSerial++
        $script:screenCaptureFailing = $true
        return @()
    }
    return $script:stubWords
}
function Reset-StubCase {
    # 케이스마다 스텁 기록·모드·캡처 실패 표식을 처음 상태로
    param([string]$Mode = 'words', [object[]]$Words = @())
    $script:stubMode = $Mode; $script:stubWords = @($Words)
    $script:stubCalls = 0; $script:stubGame = $null; $script:stubRegion = ''; $script:stubScale = $null; $script:stubEngine = $null
    $script:screenCaptureFailing = $false; $script:captureFailSerial = 0; $script:screenThrew = ''
}
function Invoke-ScreenPair {
    # 화면 함수 한 번 - 예외는 $script:screenThrew 에 남기고 $null 을 돌려 그 행만 FAIL 로 남깁니다
    param($Game)
    try { return (Find-AbyssRewardButtonPair -Game $Game) }
    catch { $script:screenThrew = $_.Exception.Message; return $null }
}
function Get-ResultShape {
    # 반환 모양 - 해시테이블 하나면 정렬한 키 목록, 아니면 무엇인지
    param($Result)
    if ($null -eq $Result) { return ('반환 없음 (예외: ' + $script:screenThrew + ')') }
    if ($Result -is [System.Array]) { return ('배열 {0}개' -f $Result.Count) }
    if (-not ($Result -is [System.Collections.IDictionary])) { return ('해시테이블 아님 ({0})' -f $Result.GetType().FullName) }
    return ('hashtable keys=' + ((@($Result.Keys | ForEach-Object { [string]$_ }) | Sort-Object) -join ','))
}
function Format-ScreenResult {
    # 반환 값 - Text 와 두 점
    param($Result)
    if ($null -eq $Result) { return ('반환 없음 (예외: ' + $script:screenThrew + ')') }
    return ("text='{0}' · {1} / {2}" -f $Result.Text, (Format-PairPoint $Result.Retry), (Format-PairPoint $Result.Other))
}

# PK1. 받은 인자 - 비-null 표식 객체(게임 프로세스 자리)를 넘겨 같은 객체가 판독까지 가는지, 영역·배율·엔진이 Test-ExitButton 과 같은지
$gameMarker = New-Object System.Diagnostics.Process
Reset-StubCase -Words $wordsPF1
[void](Invoke-ScreenPair -Game $gameMarker)
$pk1Actual = '호출={0} · 같은 Game={1} · 영역={2} · 배율={3} · 엔진={4} · 예외=[{5}]' -f $script:stubCalls, ([object]::ReferenceEquals($script:stubGame, $gameMarker)), $script:stubRegion, $script:stubScale, $script:stubEngine, $script:screenThrew
$pk1Expected = '호출=1 · 같은 Game=True · 영역={0} · 배율=3 · 엔진={1} · 예외=[]' -f ($rgClearExit -join ','), $ocrKoreanEngine
Check-Equal 'PK1 판독 1회 · 넘긴 Game 객체 그대로 · 영역 = clearAndExitText (소스 캡처) · 배율 3 · ko 엔진 (인자를 무시하거나 $null 로 고정하면 FAIL)' $pk1Actual $pk1Expected
$gameMarker.Dispose()

# PK2. 캡처 성공 (PF1 단어) - 반환 키 정확히 셋 · Text = PF1 판독문 · 짝
Reset-StubCase -Words $wordsPF1
$pk2 = Invoke-ScreenPair -Game $null
Check-Equal 'PK2 반환 = 해시테이블 하나 · 키 정확히 셋 Text·Retry·Other (상태 키 없음 - 상태는 호출부가 플래그·일련번호로 읽음)' (Get-ResultShape $pk2) 'hashtable keys=Other,Retry,Text'
Check-Equal 'PK2 Text = PF1 판독문 · 짝 (636,654)·(778,654)' (Format-ScreenResult $pk2) ("text='{0}' · 636,654 / 778,654" -f $PF1_TEXT)

# PK3. 캡처 실패 - 스텁이 일련번호 +1 · 플래그 참 · 빈 배열 → Text '' · null · null, 함수 뒤에도 플래그 참 · 일련번호 1 그대로 (읽거나 풀지 않음)
Reset-StubCase -Mode 'capture-fail'
$pk3 = Invoke-ScreenPair -Game $null
$pk3Actual = '{0} · {1} · 플래그={2} · 일련번호={3}' -f (Get-ResultShape $pk3), (Format-ScreenResult $pk3), $script:screenCaptureFailing, $script:captureFailSerial
Check-Equal "PK3 캡처 실패 → Text '' · null · null, 함수 뒤 플래그 참 그대로 · 일련번호 +1 그대로 (화면 함수는 플래그를 읽거나 풀지 않음 - 규칙 15)" $pk3Actual "hashtable keys=Other,Retry,Text · text='' · null / null · 플래그=True · 일련번호=1"

# PK4. 캡처 성공 · 단어 0 - 반환은 PK3 과 같고 플래그 거짓 · 일련번호 그대로: 반환만으로는 구분할 수 없고 구분은 플래그·일련번호뿐
Reset-StubCase -Words @()
$pk4 = Invoke-ScreenPair -Game $null
$pk4Same = (((Get-ResultShape $pk4) + (Format-ScreenResult $pk4)) -ceq ((Get-ResultShape $pk3) + (Format-ScreenResult $pk3)))
$pk4Actual = '{0} · PK3 과 같음={1} · 플래그={2} · 일련번호={3}' -f (Format-ScreenResult $pk4), $pk4Same, $script:screenCaptureFailing, $script:captureFailSerial
Check-Equal 'PK4 캡처 성공 · 단어 0 → 반환이 PK3 과 같음 · 플래그 거짓 · 일련번호 0 그대로 (빈 판독과 캡처 실패의 구분은 플래그·일련번호뿐)' $pk4Actual "text='' · null / null · PK3 과 같음=True · 플래그=False · 일련번호=0"

# PK5. 단어 Text 에 공백 - Text 는 단어를 이어 붙이고 공백을 지운 문자열 (워커 Find-AbyssExitButtonPoint 와 같은 식)
Reset-StubCase -Words @((W '다 세' 614 654), (W ' 하기' 657 654), (W '다른' 761 654), (W '던전 ' 796 654))
$pk5 = Invoke-ScreenPair -Game $null
Check-Equal "PK5 단어 Text 에 공백 ('다 세' · ' 하기' · '던전 ') → Text = 공백 제거 이어 붙임" $(if ($null -ne $pk5) { [string]$pk5.Text } else { Get-ResultShape $pk5 }) '다세하기다른던전'

# PK6. 반환 Text 를 실제 3버튼 서명에 - ⑤ 는 같은 판독문으로 서명을 봅니다 (PF1 참 · 파티원 보상 PN1 거짓)
Reset-StubCase -Words $wordsPN1
$pk6Member = Invoke-ScreenPair -Game $null
Check-Equal 'PK6 PK2 · PN1 의 반환 Text → 실제 Test-AbyssRewardText 참 · 거짓 (⑤ 가 같은 판독문으로 서명을 봄)' ('{0}/{1}' -f (Test-AbyssRewardText -Text ([string]$pk2.Text)), (Test-AbyssRewardText -Text ([string]$pk6Member.Text))) 'True/False'

# ── 7. PT 정적 (주석 뺀 사본 · AST) ───────────────────────────────────────────────────────
$findAst = $functionAsts['Find-AbyssRewardButtonPair']
$selectAst = $functionAsts['Select-AbyssRewardButtonPair']
$findCode = Get-FunctionCode 'Find-AbyssRewardButtonPair'

# PT1. 화면 함수의 판독 = Get-GameRegionOcrWords 한 번 (clearAndExitText · 배율 3 · ko · 받은 Game 그대로) + 순수 판정 한 번, 다른 판독 경로 없음
$findCommands = @(Get-CommandNames $findAst)
$ocrWordsCalls = @($findAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Get-GameRegionOcrWords') }, $true))
$ocrWordsCount = @($findCommands | Where-Object { $_ -eq 'Get-GameRegionOcrWords' }).Count
$selectCallCount = @($findCommands | Where-Object { $_ -eq 'Select-AbyssRewardButtonPair' }).Count
$otherReadCount = @($findCommands | Where-Object { @('Get-GameOcrText', 'Get-GameRegionOcrText', 'Find-GameTextPoint') -contains $_ }).Count
$regionScaleOk = [bool]($findCode -match 'rgClearExit\[0\][\s\S]{0,200}-Scale 3(?!\d)')
$engineOk = [bool]($findCode -match '-Engine \$ocrKoreanEngine\b')
$gameArgOk = $(if ($ocrWordsCalls.Count -ge 1) { [bool]((Get-NodeCode $ocrWordsCalls[0]) -match '-Game[:\s]+\$Game\b') } else { $false })
$pt1Actual = '판독 단어={0} · 순수 판정={1} · 다른 판독={2} · 영역→배율 3={3} · 엔진={4} · -Game={5}' -f $ocrWordsCount, $selectCallCount, $otherReadCount, $regionScaleOk, $engineOk, $gameArgOk
Check-Equal 'PT1 Find-AbyssRewardButtonPair: Get-GameRegionOcrWords 1 · Select-AbyssRewardButtonPair 1 · Get-GameOcrText·Get-GameRegionOcrText·Find-GameTextPoint 0 · rgClearExit[0]…-Scale 3 · -Engine $ocrKoreanEngine · -Game $Game' $pt1Actual '판독 단어=1 · 순수 판정=1 · 다른 판독=0 · 영역→배율 3=True · 엔진=True · -Game=True'

# PT2. 두 함수 모두 클릭·대기·로그·전면화·캡처 표식·정렬·커서 대피(호출부 몫) 0, 캡처 실패 플래그·일련번호 변수 0, exit·throw·try 0
$FORBIDDEN_COMMANDS = @('Click-GamePoint', 'Click-ScreenPoint', 'Write-RunLog', 'Start-Sleep', 'sleep', 'Focus-Game', 'Register-CaptureFailure', 'Register-CaptureSuccess',
    'Test-CaptureRecovered', 'Test-SafeStopDuringCaptureFail', 'Sort-Object', 'sort', 'Move-CursorOutsideGame')
$CAPTURE_STATE_VARIABLES = @('screenCaptureFailing', 'captureFailSerial')
foreach ($functionName in $TARGET_FUNCTIONS) {
    $targetAst = $functionAsts[$functionName]
    $forbiddenUsed = @(Get-CommandNames $targetAst | Where-Object { $FORBIDDEN_COMMANDS -contains $_ } | Sort-Object -Unique)
    $stateVariableCount = @($targetAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.VariableExpressionAst]) -and ($CAPTURE_STATE_VARIABLES -contains ($node.VariablePath.UserPath -replace '^.*:', '')) }, $true)).Count
    $exitCount = @($targetAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.ExitStatementAst] }, $true)).Count
    $throwCount = @($targetAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)).Count
    $tryCount = @($targetAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.TryStatementAst] }, $true)).Count
    $pt2Actual = '금지 명령=[{0}] · 캡처 표식 변수={1} · exit={2} · throw={3} · try={4}' -f ($forbiddenUsed -join ','), $stateVariableCount, $exitCount, $throwCount, $tryCount
    Check-Equal "PT2 ${functionName}: 클릭·대기·로그·전면화·캡처 등록/해제/탐침·안전 확인·Sort-Object·커서 대피 0 · 캡처 실패 플래그·일련번호 0 · exit·throw·try 0" $pt2Actual '금지 명령=[] · 캡처 표식 변수=0 · exit=0 · throw=0 · try=0'
}

# PT3. 순수 판정의 어휘 - 머리·꼬리 조각 여섯은 문자열 상수로 있고, '가기' 를 담은 문자열은 없음 ('나가기' 충돌)
$selectStrings = @($selectAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { [string]$_.Value })
$selectExpandableStrings = @($selectAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst] }, $true) | ForEach-Object { [string]$_.Value })
$missingFragments = @(@('다시', '다세', '다셔', '하기', '다른', '던전') | Where-Object { $selectStrings -cnotcontains $_ })
$gagiStringCount = @(@($selectStrings + $selectExpandableStrings) | Where-Object { $_.Contains('가기') }).Count
Check-Equal "PT3 Select-AbyssRewardButtonPair 문자열 상수: '다시'·'다세'·'다셔'·'하기'·'다른'·'던전' 각 1 이상 · '가기' 0" ('없는 조각=[{0}] · 가기 문자열={1}' -f ($missingFragments -join ','), $gagiStringCount) '없는 조각=[] · 가기 문자열=0'

# PT4. 배선 0 - 화면 함수를 부르는 곳이 워커에 없고, 순수 판정은 화면 함수 안 한 곳에서만 부름 (⑤ 가 배선하면 ⑤ 명세가 이 단언을 갱신)
$findCallNodes = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Find-AbyssRewardButtonPair') }, $true))
$selectCallNodes = @($workerAst.FindAll({ param($node) ($node -is [System.Management.Automation.Language.CommandAst]) -and ($node.GetCommandName() -eq 'Select-AbyssRewardButtonPair') }, $true))
$selectCallHomes = @($selectCallNodes | ForEach-Object { Get-EnclosingFunctionName $_ }) -join ','
Check-Equal 'PT4 배선 0: 워커의 Find-AbyssRewardButtonPair 호출 0 · Select-AbyssRewardButtonPair 호출 1 (자리 = Find-AbyssRewardButtonPair 안)' ('화면 함수 호출={0} · 순수 판정 호출={1} · 자리=[{2}]' -f $findCallNodes.Count, $selectCallNodes.Count, $selectCallHomes) '화면 함수 호출=0 · 순수 판정 호출=1 · 자리=[Find-AbyssRewardButtonPair]'

# PT5. 상수 셋 - 최상위 대입 각 정확히 1 · 함수 안 대입 0 · 우변에 명령 0 · config 변수 0 (스크립트 상수 - coordsVersion·configSchemaVersion 무관), 두 대역은 겹치지 않음
$constantReport = foreach ($constantName in @('abyssRetryPairBandX', 'abyssOtherPairBandX', 'abyssPairMaxDy')) {
    $constantAssignments = @($allAssignments | Where-Object { (Get-AssignedVariableName $_) -eq $constantName })
    $topLevel = @($constantAssignments | Where-Object { (Get-EnclosingFunctionName $_) -eq '' })
    $insideFunction = @($constantAssignments | Where-Object { (Get-EnclosingFunctionName $_) -ne '' })
    $rightCommands = $(if ($topLevel.Count -ge 1) { @($topLevel[0].Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)).Count } else { -1 })
    $rightConfig = $(if ($topLevel.Count -ge 1) { @($topLevel[0].Right.FindAll({ param($node) ($node -is [System.Management.Automation.Language.VariableExpressionAst]) -and (($node.VariablePath.UserPath -replace '^.*:', '') -eq 'config') }, $true)).Count } else { -1 })
    '{0} 최상위={1} 함수안={2} 우변명령={3} config={4}' -f $constantName, $topLevel.Count, $insideFunction.Count, $rightCommands, $rightConfig
}
$constantExpected = @('abyssRetryPairBandX', 'abyssOtherPairBandX', 'abyssPairMaxDy') | ForEach-Object { '{0} 최상위=1 함수안=0 우변명령=0 config=0' -f $_ }
Check-Equal 'PT5 상수 셋: 최상위 대입 각 1 · 함수 안 대입 0 · 우변 명령 0 (Get-ConfigValue 등 config 읽기 없음)' (@($constantReport) -join ' | ') (@($constantExpected) -join ' | ')
Check-Equal 'PT5 retry 대역 끝 < other 대역 시작 (두 대역이 겹치지 않음)' ('{0} < {1} = {2}' -f $retryBandEnd, $otherBandStart, ($retryBandEnd -lt $otherBandStart)) ('{0} < {1} = True' -f $retryBandEnd, $otherBandStart)

# PT6. 상수 계약 - ① 계약값 고정 (의도된 걸림 장치 - 바꾸려면 설계 재합의) ② 측정 분리 (경계 숫자는 보관 프레임 재생의 측정값 - 명세 1.8)
Check-Equal 'PT6① 계약값 고정 - retry 대역 560~710 / other 대역 720~880 / dY 한도 30 (설계 판별 gate 값. 바꾸면 여기서 걸리는 것이 의도 - 설계 재합의 필요)' ('{0} / {1} / {2}' -f ($abyssRetryPairBandX -join ','), ($abyssOtherPairBandX -join ','), $abyssPairMaxDy) '560,710 / 720,880 / 30'
$OBSERVED_RETRY_HEAD_X = @(614, 616)      # '다시|다세|다셔' 중심 X (1272 · 1270 · 1276 콘솔 전환 · 1908 두 렌더)
$OBSERVED_RETRY_TAIL_X = @(655, 657)      # '하기'
$OBSERVED_OTHER_HEAD_X = @(749, 762)      # '다른'
$OBSERVED_OTHER_TAIL_X = @(781, 796)      # '던전'
$OBSERVED_PAIR_DY_MAX = 1                 # 관측 짝 두 단어의 Y 차 최대 (등장 슬라이드 중 PF8)
$OBSERVED_LINE_GAP_MIN = 56               # 안내문 줄('…있습니다')과 버튼 줄의 Y 차 최소 (1908 DPI 144 PF7)
$OBSERVED_NETWORK_TAIL_X_MIN = 763        # 네트워크 불안정 팝업 '시도하기' 중심 X (PN11 763 · PN12 764)
$retryCovers = ($retryBandStart -le $OBSERVED_RETRY_HEAD_X[0]) -and ($OBSERVED_RETRY_TAIL_X[1] -le $retryBandEnd)
$otherCovers = ($otherBandStart -le $OBSERVED_OTHER_HEAD_X[0]) -and ($OBSERVED_OTHER_TAIL_X[1] -le $otherBandEnd)
$dyBetween = ($OBSERVED_PAIR_DY_MAX -lt $pairMaxDy) -and ($pairMaxDy -lt $OBSERVED_LINE_GAP_MIN)
$networkOutside = ($OBSERVED_NETWORK_TAIL_X_MIN -gt $retryBandEnd)
Check-Equal ('PT6② 측정 분리 - 관측 머리·꼬리(retry {0}~{1}·{2}~{3} / other {4}~{5}·{6}~{7})가 대역 안 · 관측 짝 dY 최대 {8} < dY 한도 < 안내문 줄과 버튼 줄 차 최소 {9} · 네트워크 팝업 꼬리 {10} > retry 대역 끝' -f
    $OBSERVED_RETRY_HEAD_X[0], $OBSERVED_RETRY_HEAD_X[1], $OBSERVED_RETRY_TAIL_X[0], $OBSERVED_RETRY_TAIL_X[1], $OBSERVED_OTHER_HEAD_X[0], $OBSERVED_OTHER_HEAD_X[1],
    $OBSERVED_OTHER_TAIL_X[0], $OBSERVED_OTHER_TAIL_X[1], $OBSERVED_PAIR_DY_MAX, $OBSERVED_LINE_GAP_MIN, $OBSERVED_NETWORK_TAIL_X_MIN) `
    ('retry={0} · other={1} · dY={2} · 네트워크 팝업={3}' -f $retryCovers, $otherCovers, $dyBetween, $networkOutside) 'retry=True · other=True · dY=True · 네트워크 팝업=True'
# 측정값의 출처 확인 - 위 측정값이 이 파일의 3버튼 보상 단어 목록(PF·PH·PX)에서 나온 범위와 같은지 (목록을 더하거나 고치면 측정값도 함께 고칩니다)
$rewardWordLists = @($wordsPF1, $wordsPF2, $wordsPF3, $wordsPF4, $wordsPF5, $wordsPF6, $wordsPF7, $wordsPF8, $wordsPF9,
    $wordsPH1, $wordsPH2, $wordsPH3, $wordsPH4, $wordsPH5, $wordsPH6, $wordsPH7, $wordsPX1, $wordsPX2, $wordsPX3)
$retryHeadXs = @(); $retryTailXs = @(); $otherHeadXs = @(); $otherTailXs = @(); $pairDys = @(); $lineGaps = @()
foreach ($rewardWords in $rewardWordLists) {
    $retryHeads = @($rewardWords | Where-Object { @('다시', '다세', '다셔') -contains $_.Text })
    $retryTails = @($rewardWords | Where-Object { $_.Text -ceq '하기' })
    $otherHeads = @($rewardWords | Where-Object { $_.Text -ceq '다른' })
    $otherTails = @($rewardWords | Where-Object { $_.Text -ceq '던전' })
    $retryHeadXs += @($retryHeads | ForEach-Object { [int]$_.X }); $retryTailXs += @($retryTails | ForEach-Object { [int]$_.X })
    $otherHeadXs += @($otherHeads | ForEach-Object { [int]$_.X }); $otherTailXs += @($otherTails | ForEach-Object { [int]$_.X })
    if ($retryHeads.Count -eq 1 -and $retryTails.Count -eq 1) { $pairDys += [Math]::Abs([int]$retryTails[0].Y - [int]$retryHeads[0].Y) }
    if ($otherHeads.Count -eq 1 -and $otherTails.Count -eq 1) { $pairDys += [Math]::Abs([int]$otherTails[0].Y - [int]$otherHeads[0].Y) }
    $guideYs = @($rewardWords | Where-Object { ([string]$_.Text).Contains('있습니다') } | ForEach-Object { [int]$_.Y })
    $buttonYs = @(@($retryHeads + $retryTails + $otherHeads + $otherTails) | ForEach-Object { [int]$_.Y })
    if ($guideYs.Count -ge 1 -and $buttonYs.Count -ge 1) { $lineGaps += (($buttonYs | Measure-Object -Minimum).Minimum - ($guideYs | Measure-Object -Maximum).Maximum) }
}
$measuredText = 'retry 머리 {0}~{1} · 꼬리 {2}~{3} / other 머리 {4}~{5} · 꼬리 {6}~{7} / 짝 dY 최대 {8} / 줄 차 최소 {9}' -f
    ($retryHeadXs | Measure-Object -Minimum).Minimum, ($retryHeadXs | Measure-Object -Maximum).Maximum, ($retryTailXs | Measure-Object -Minimum).Minimum, ($retryTailXs | Measure-Object -Maximum).Maximum,
    ($otherHeadXs | Measure-Object -Minimum).Minimum, ($otherHeadXs | Measure-Object -Maximum).Maximum, ($otherTailXs | Measure-Object -Minimum).Minimum, ($otherTailXs | Measure-Object -Maximum).Maximum,
    ($pairDys | Measure-Object -Maximum).Maximum, ($lineGaps | Measure-Object -Minimum).Minimum
$observedText = 'retry 머리 {0}~{1} · 꼬리 {2}~{3} / other 머리 {4}~{5} · 꼬리 {6}~{7} / 짝 dY 최대 {8} / 줄 차 최소 {9}' -f
    $OBSERVED_RETRY_HEAD_X[0], $OBSERVED_RETRY_HEAD_X[1], $OBSERVED_RETRY_TAIL_X[0], $OBSERVED_RETRY_TAIL_X[1], $OBSERVED_OTHER_HEAD_X[0], $OBSERVED_OTHER_HEAD_X[1],
    $OBSERVED_OTHER_TAIL_X[0], $OBSERVED_OTHER_TAIL_X[1], $OBSERVED_PAIR_DY_MAX, $OBSERVED_LINE_GAP_MIN
Check-Equal 'PT6② 측정값 출처 - 3버튼 보상 단어 목록 19개(PF·PH·PX)의 머리·꼬리 X 범위 · 짝 dY 최대 · 줄 차 최소 = 위 측정값' $measuredText $observedText

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
