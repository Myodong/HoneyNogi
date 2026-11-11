# 어비스 재입장 대기 · 보상 화면 '다시 하기'/'다른 던전 가기' 회귀 - 결론 순수 판정 진리표 · 대기 루프 행동 진리표 · 정적 배선 (구현 단위 ④ · ⑤b1~⑤b6 · 5b-8 - 2026-10~11)
#
# 배경(설계 v11 R5 대기 루프 골격 · 구현 명세 ④): 어비스 재입장 대기를 워커에 넣는 단위입니다 - 스크립트 상수 $abyssReclickQuietSeconds(무변화 창 Q -
#   config 아님) · 결론 순수 판정 Resolve-AbyssReentryVerdict · 대기 함수 Wait-AbyssReentry(결과 @{ Result; LastKind; PanelSeen } 하나). 첫 호출 = 이어받기
#   선분기 B2 단계(구현 단위 ⑤a - 동작 변화는 B2 판독 중 창 좌표 실패 하나) · 원 워커 B2·resume·폴백 ② 는 ⑤b·⑤c 입니다. 파일 이름은 설계 v10 의 계획 그대로입니다 - 파티장
#   쪽 재입장·보상 귀환 대기의 회귀를 이 파일이 모읍니다(설계 v11 R5 8절).
# 여기서 고정하는 계약(구현 명세 ④ 1.5·1.6·1.9·1.11):
#   회전 순서 - 서두(클릭 생략 메타 비움) → ① 동결(여러 줄 · 단독 줄 continue: 안전 확인 → 2초 → 이번 회전 탐침 → 탐침 표식) → ② 조작 양보 → ③ 탐침
#     복구 뒤 회전(스윕·판독 없이 마감만) → try { ④ 팝업 스윕(참이면 생략 사유 분류) → ⑤ 판독(하단 → 패널 → HUD → 추적기 → 필드 결과 켬의 필드 모양 회전만 선택 화면 → ESC 메뉴) } catch(창 좌표 throw 만) →
#     ⑥ 간접 양보 → ⑦ 유효성 → ⑧ 분류·던전 안 연속·패널 관측·필드 확정·계측 → 무변화 판정 → ⑨ 결론(같은 회전의 마감보다 먼저) → ⑩ 마감(파티원 시계 - 양보·캡처
#     실패 차분) → ⑫ 대기(굶김 0 · 복구 2초 · 그 밖 700ms). ⑪(클릭)은 없습니다(구현 단위 ⑥d 자리). 조작 생략·아직 캡처 실패 중인 회전은 마감을 확정하지
#     않습니다(규칙 4·15)
#   결론 우선순위(위가 이김) - 던전 안 2연속 'entered' > 목표 field ∧ 필드 모양 ∧ 필드 확정 'field' > 목표 reward ∧ 3버튼 'reward' > 목표 entry ∧ 필드 결과 ∧
#     필드 모양 ∧ 필드 확정 'field-cancelled'(구현 단위 5b-8) > 목표 entry ∧ 보고 ∧ 3버튼 ∧ 패널 관측 'cancelled' > 같은 꼴 ∧ 무변화 만료 'reclick' > ''(관측 지속).
#     waiter 는 목표 'entry' 를 넘기고, 필드 확정은 필드 결과 켬(-ReportFieldReturn - 원 워커 우연한 만남 '다시 하기' 대기)에서만 셉니다(설계 v11 R5 2.1·2.2 끊김 표)
#   마감 - 본 시계(-Clock 이면 그 hashtable 그대로 · 아니면 -LimitSeconds 새 시계) · 무변화 시계(늘 만듦 · 호출부터 조정 Q) · 던전 안 유예 시계(정지로
#     만들고 처음 미루는 회전에서 진행). -ResumeGrace 이고 본 시계가 지난 회전은 다섯 식으로 미룹니다 - 던전 안 첫 유예(연속당 한 번 · 상한 없음) · 그
#     연속의 연장(유예 시계 안) · 3버튼 창(보고 켬 · 무변화 창 안) · 첫 유효 회전 전(무변화 창 안) · 되돌림 뒤 창(유예 시계 안 - 정지면 그 회전에 처음 진행).
#     사용자 조작 양보 셋(② 게이트 · ④ 스윕 'yield' · ⑥ 간접 양보)이 살아 있는 던전 안 연속을 끊으면 그 연속이 쓴 유예 표식을 되돌리고 되돌림 뒤 창
#     표식을 세우며, ⑧ 이 유효 분류마다 그 표식을 비웁니다(사용자 결정 U-R5-4 (나))
#   창 좌표 throw - catch 하나가 캡처 실패 플래그 ∧ 원인 gameWindowGone ∧ 두 문구(공용 판독 run:3870 · 스윕 예비 좌표 클릭 run:2921) 정확 일치만 받아 다음
#     회전 동결로 보내고, 그 밖의 예외는 그대로 다시 던집니다(방어선 - 1차 차단은 구현 단위 ④′ 의 스윕 사전 동결 게이트)
# 방법(구현 명세 ④ 3.2):
#   - 원문 추출: 대기 함수·순수 판정·분류기와 그 서명 셋·파티원 시계 여섯·마감 조정 셋·캡처 성공 등록·누적·패널 서명 둘을 워커 원문 그대로 이 파일 최상위에서
#     정의합니다(사본 재구현 금지). 그 함수들이 부르는 워커 최상위 함수 중 이 파일이 모의·감시하지 않는 것은 의존 추출이 따라 올립니다 - 구현이 도움 함수를
#     더해도 행이 돌고, 정적 N4-P6(명령 집합)이 그 사실을 FAIL 로 알립니다. 워커에 대상 함수가 없으면 SKIP 이 아니라 'FAIL 준비' 로 끝납니다
#   - 이름 바꿔 올림: 안전 확인(exit 셋)·공용 스윕(exit 하나)은 exit 를 센티널 throw('__EXIT__N')로 바꿔 Invoke-Real* 로 올리고 같은 이름은 호출 기록 감시가
#     차지합니다. 선단언 전용으로 하단 프롬프트·패널 종류·추적기 원문 판정을, 굶김 예산 관측용으로 스윕 생략 사유 분류 원문을 같은 방식으로 올립니다
#   - 모의는 워커 원문의 param 블록 그대로 + 스텁 몸통(서명 대조로 확인) · 기록 모의(행마다 호출 0) · 닿으면 안 되는 함수(부르면 TEST-UNREACHABLE)
#   - 가상 시계(Get-Date·Start-Sleep 모의 - Ticks 단위, 가상 20000초 · 판독 5만 · 스윕 5만 · 조작 확인 5만 회를 넘으면 '__VTIMEOUT__') · 캡처 상태는 원문 변수 이름의 한 이름
#     공간이고 실패 등록만 모의합니다(원인 인자 - 원문 규칙 사본은 N4-P7 이 고정) · 조작 창 · 스윕 모의 종류(sent·cursor·ua-wait·ua-deleg·recover·fail-false·
#     fail-true·yield-false·yield-sent·rect-throw·yield-rect-throw·rect-click-throw·click-throw-noreg·gate-true·교대·실제)
#   - 판독 스텁은 화면 함수 층에서 시각표의 지금 화면으로 답합니다. 하단 판독문은 기존 회귀 파일의 실측 문자열 글자 그대로이고(아래 $SCREEN_TABLE 주석의
#     출처), 패널·프롬프트·추적기 판정값은 실측 문자열에서 원문 판정으로 선단언합니다. HUD 영역 실측 문자열은 tests\ 에 없어 판정값만 씁니다
#   - 기대값은 원문 루프가 낸 결과·시각·호출 수입니다. 시각·회전은 판독 회전 기록·사건 기록에서 계산하고(명세 3.2.8) 숫자를 다시 박지 않습니다(L 은 행
#     픽스처 · Q·W·스윕 한도·대기 값은 소스 캡처 · 회전 박자는 사건 기록의 Start-Sleep 길이)
# 행 계열: WA-P(결론 순수 판정 · 설계 v11 R5 8절 이름) + N4-L4 · WA-L(대기 루프 · 설계 이름 - 이 단위 몫 41행 + WA-L14′·WA-L17′ + 구현 리뷰의 WA-L14″) · N4-L(구현 명세 ④ 가 더한
#   대기 행) · R5-P(정적 · 설계 이름 - 이 단위 몫 P1~P8·P12·P14·P16) · N4-P(정적 · 명세가 더한 것 - P1~P10·P12~P14, P11 은 결번)
#   구현 단계 ⑤b1~⑤b6 이 더한 계열(절 머리에 상세): §6b RR · RD · OC · V · U · 정적 P5b(⑤b1) · §6c RB · 정적 P5c(⑤b2) · §9 OW · PM · WA-S · SW · OS · FB · SS · 정적 R6-P ·
#   R5-P · SEL · WAIT 의 other 몫(⑤b3) · §10 클릭 루프 · 원 워커 B2 · 폴백 ② 호출 E · RC 행 · 정적 P5d · R3 S · 관측 0 재생(⑤b4) · §11 본류 보상 화면 꼬리 T- · 정적 P5e(⑤b5) ·
#   §6b MX · 정적 P5b-9 · P5b-10 · §6c RB10~RB13 · 정적 P5c-5 · §10 정적 P5d-8 · §11 T-RS · T-X1 · T-MX · 정적 P5e-8~10(⑤b6 - 멈출 때와 다음 판 입장 방식이 다르거나 모를 때는
#   '나가기' → 필드, 같은 입장 방식의 다른 던전 · 난이도는 '다른 던전 가기')
#   구현 단위 5b-8(재매칭 패널 ESC 취소 → 필드 확정이면 곧바로 정지 - 구현 명세 5b-8 3절)이 더한 계열: §6 FC-P(필드 결과 열) · §7 FC-L · §8b 정적 FC-S ·
#   §10 FC-X · FC-J · 정적 FC-S15 · FC-S16 · FC-S19 (GUI 결합은 test_abyss_handoff_gui.ps1 FC-G · 보존 줄은 test_log_tail_offset.ps1)
#   구현 단계 ⑤c(재입장 재개) 5c-1 이 더한 계열: §6a RG(재개 유예 판정 순수 진리표) · 정적 RG-S · R5-P2 · R5-P14 갱신(구현 명세 ⑤c 3.2 (가) · 3.4)
#   ⑤c 5c-2(선분기 Role resume 열 · 재개 끝 'timeout' 까지 · 공유 정지 함수)가 고친 계수: N4-P2 · FC-S13 · FC-S14 · FC-S15~S17 · FC-S22 · P0 · P5d-1 · R6-P10 ·
#   §10 하니스의 대상 · 센티널 · 올림(Stop-AbyssReentryFieldCancelled) (구현 명세 ⑤c 3.2 (나) - 재개 워커 행은 test_abyss_resume_reentry.ps1)
#   ⑤c 5c-3(재평가 · 재클릭 · 멈춤 끝 · 끝(other) -ExitOnly)이 고친 계수: P5b-2 · R3 S2 · R3 S5 · P0 · P5d-1 · P5e-9 (구현 명세 ⑤c 3.2 (다) - P5e-9 는 재개 판단 줄이 같은 끝말을
#   하나 더해 같이 고침)
# 보관 캡처·OCR 엔진 없이 늘 돌아 SKIP 경로가 없습니다.
# 뒤 단위가 이 파일에 더할 자리(설계 v11 R5 8절 · 구현 명세 ④ 2.2-1):
#   ⑤ - WA-X3~X5·X12 · WA-S(S10 포함 - S10 에 클릭 경로 문구 변형 셋 · 두 번째 판독 실패 변형(④′ 뒤 공용 스윕 행)) · 정적 R5-P1·P2·P12·P16 의 두 클릭
#       루프 몫 · R5-P13 · 변이 R5-M36~M39 와 R5-M46·M47 의 두 클릭 루프 꼴 · N4-M4·M30·M31·M37 의 두 클릭 루프 꼴. 배선 갱신은 ⑤a 가 했습니다 - N4-P2(호출 1 =
#       선분기 B2 단계 · ⑤b·⑤c 가 호출 자리 수를 더함) · R5-P5·N4-P9·N4-P14 의 S2 대조 대상(선분기 S2 삭제 → 고정 접두·조각 상수 - 이 파일 $S2_PATTERN 과 동치 단언)
#       ⑤b 가 채운 몫(구현 단계 ⑤b1~⑤b5): 위 행·정적·변이의 두 클릭 루프 꼴(⑤b3 §9 '다른 던전 가기' 대기 · ⑤b4 §10 '다시 하기' 클릭 루프) · N4-P2 호출 3(⑤b4 - 폴백 ② 호출 E ·
#       원 워커 호출 B) · 배선 갱신 P5b-2 · P5b-4 · P5c-3 · P5c-4 · P0 · P5d-1 · P5d-2 · R3 S2 · S7(⑤b5 - 본류 보상 화면 꼬리의 자리 수 · ⓪ 대입). ⑤c 5c-1 이 P5b-4 · P5b-5 ·
#       R3 S7 의 ④ 승계 꼴을 채웠고, 5c-2 · 5c-3 이 재개 끝의 호출 자리(P0 · P5d-1 · P5b-2 · R3 S2 · R3 S5)를 더했습니다. resume 기동의 대기 행은
#       test_abyss_resume_reentry.ps1(⑲) 몫입니다(P5b-8 은 그대로 - 호출이 생긴 단계부터 그 호출 전부에 걸림)
#   ⑥d - WA-C(C7 포함) · WA-L31·L40·L42(목표 'field'·'reward' 행) · WA-E · WA-R(E5·R5 에 클릭 경로 문구 변형 셋 · 두 번째 판독 실패 변형) · WA-X14~X18 ·
#       정적 R5-P15·P17 · R5-P1·P2·P12·P16 의 ⑥d 두 클릭 루프 몫 · R5-P13(입장하기·준비 취소 몫) · R5-P4·P8·R5-P16·N4-P4·N4-P12 갱신 ·
#       FC-S19(대기 스위치 수 3 · 호출 B 인자 - -ChallengeFewMembers 가 붙으면) · FC-S22(끝(retry) 명령 허용 집합 - 파티장 경로가 명령을 더하면) 갱신 ·
#       변이 R5-M22~M24·M42~M45·M48·M50·M53(waiter 꼴)·M54~M65 와 R5-M39·M46·M47 의 ⑥d 클릭 루프 꼴 · N4-M4·M30·M31·M37 의 ⑥d 두 클릭 루프 꼴
using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$fails = 0

function Check-Equal {
    # 결과 한 줄 - 문자열로 비교합니다(대소문자 구분 -ceq - 명세 3.3). 실패는 'FAIL …' 줄 + 실패 수 +1 (러너가 'FAIL' 줄과 종료 코드로 집계)
    param([string]$Name, $Actual, $Expected)
    if ("$Actual" -ceq "$Expected") { "OK   $Name" }
    else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

function Check-True {
    # 복합 조건 단언 - 실패 줄에 실제 값(Detail)을 함께 남겨 원인을 바로 볼 수 있게 합니다
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { "OK   $Name" }
    else { "FAIL $Name ($Detail)"; $script:fails++ }
}

function Remove-CommentsByTokens {
    # 주석 뺀 사본 - 주석 토큰을 같은 길이 공백으로 바꿉니다(줄바꿈 보존 · 위치 그대로 - test_abyss_party_member.ps1 §0 과 같은 구현)
    param([string]$Text, $Tokens)
    $builder = New-Object System.Text.StringBuilder ($Text.Length)
    $position = 0
    foreach ($token in $Tokens) {
        if ($token.Kind -ne [TokenKind]::Comment) { continue }
        [void]$builder.Append($Text, $position, $token.Extent.StartOffset - $position)
        [void]$builder.Append(($token.Text -replace '[^\r\n]', ' '))
        $position = $token.Extent.EndOffset
    }
    [void]$builder.Append($Text, $position, $Text.Length - $position)
    return $builder.ToString()
}

# ── §1 준비: 워커 1회 파싱(토큰) · 주석 뺀 사본 · 최상위 함수 표 (fail-closed - 명세 2.2-2) ─────────────────────────────────────────
$workerTokens = $null
$workerParseErrors = $null
try {
    $workerAst = [Parser]::ParseFile($workerPath, [ref]$workerTokens, [ref]$workerParseErrors)
} catch {
    "FAIL 준비: 워커를 파싱하지 못했습니다 ($($_.Exception.Message))"
    exit 1
}
if (@($workerParseErrors).Count -gt 0) {
    "FAIL 준비: 워커 파서 오류 $(@($workerParseErrors).Count)건 - 첫 오류: $($workerParseErrors[0].Message)"
    exit 1
}
$workerText = $workerAst.Extent.Text
$workerCode = Remove-CommentsByTokens -Text $workerText -Tokens $workerTokens
$workerFunctions = @{}
foreach ($topStatement in $workerAst.EndBlock.Statements) {
    if (($topStatement -is [FunctionDefinitionAst]) -and (-not $workerFunctions.ContainsKey($topStatement.Name))) { $workerFunctions[$topStatement.Name] = $topStatement }
}

# ── AST 도움 함수 (소스 캡처 · 선단언 · 정적이 함께 씀) ──────────────────────────────────────────────────────────────
function Get-WorkerFunction {
    # 워커 최상위 함수 정의 AST - 없으면 throw (상수·문구 캡처와 정적 단언이 조용히 빈 값을 쓰지 않게)
    param([string]$Name)
    if (-not $workerFunctions.ContainsKey($Name)) { throw "워커 최상위 함수 $Name 을(를) 찾지 못했습니다" }
    return $workerFunctions[$Name]
}

function Get-NodeCode {
    # 노드의 주석 뺀 원문을 공백 정규화한 한 줄 (워커 사본 - 위치가 원문과 같음)
    param($Node)
    if ($null -eq $Node) { return '' }
    $nodeText = $workerCode.Substring($Node.Extent.StartOffset, $Node.Extent.EndOffset - $Node.Extent.StartOffset)
    return (($nodeText -replace '\s+', ' ').Trim())
}

function Get-InnerExpression {
    # 괄호 · 원소 하나 파이프라인 · 명령식 껍질을 벗깁니다 (뜻에 닿지 않는 표기 - 명세 3.5 '괄호 무관')
    param($Node)
    $current = $Node
    while ($null -ne $current) {
        if ($current -is [ParenExpressionAst]) { $current = $current.Pipeline; continue }
        if (($current -is [PipelineAst]) -and ($current.PipelineElements.Count -eq 1) -and ($current.PipelineElements[0] -is [CommandExpressionAst]) -and
            ($current.PipelineElements[0].Redirections.Count -eq 0)) { $current = $current.PipelineElements[0].Expression; continue }
        if (($current -is [CommandExpressionAst]) -and ($current.Redirections.Count -eq 0)) { $current = $current.Expression; continue }
        break
    }
    return $current
}

function Test-IsVariable {
    # 껍질을 벗긴 노드가 그 이름의 변수인지 (이름은 범위 접두 포함 - 'script:screenCaptureFailing' · 대소문자 무관)
    param($Node, [string]$Name)
    $inner = Get-InnerExpression $Node
    return (($inner -is [VariableExpressionAst]) -and ($inner.VariablePath.UserPath -eq $Name))
}

function Test-HasVariable {
    # 노드 아래에 그 이름의 변수를 읽는 자리가 있는지
    param($Node, [string]$Name)
    if ($null -eq $Node) { return $false }
    return (@($Node.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -eq $Name) }, $true)).Count -gt 0)
}

function Test-HasCommand {
    # 노드 아래에 그 이름의 명령 호출이 있는지
    param($Node, [string]$Name)
    if ($null -eq $Node) { return $false }
    return (@($Node.FindAll({ param($candidate) ($candidate -is [CommandAst]) -and ($candidate.GetCommandName() -eq $Name) }, $true)).Count -gt 0)
}

function Get-CommandNodes {
    # 노드 아래 그 이름의 명령 호출 전부 (열거용 - 호출부에서 @())
    param($Node, [string]$Name)
    return @($Node.FindAll({ param($candidate) ($candidate -is [CommandAst]) -and ($candidate.GetCommandName() -eq $Name) }, $true))
}

function Test-AstInsideFunction {
    # 노드가 함수 정의 안에 있는지 (같은 이름의 지역 대입을 최상위 상수로 잘못 잡지 않게)
    param($Node)
    for ($parentNode = $Node.Parent; $null -ne $parentNode; $parentNode = $parentNode.Parent) {
        if ($parentNode -is [FunctionDefinitionAst]) { return $true }
    }
    return $false
}

function Test-AstWithin {
    # 노드가 Ancestor 의 자손인지
    param($Node, $Ancestor)
    if ($null -eq $Ancestor) { return $false }
    for ($parentNode = $Node.Parent; $null -ne $parentNode; $parentNode = $parentNode.Parent) {
        if ([object]::ReferenceEquals($parentNode, $Ancestor)) { return $true }
    }
    return $false
}

function Get-EnclosingFunctionName {
    # 노드를 감싼 가장 안쪽 함수 이름 (최상위면 '')
    param($Node)
    for ($parentNode = $Node.Parent; $null -ne $parentNode; $parentNode = $parentNode.Parent) {
        if ($parentNode -is [FunctionDefinitionAst]) { return [string]$parentNode.Name }
    }
    return ''
}

function Get-ResolvedTypeName {
    # 형 이름의 해석된 CLR 형 전체 이름 (명세 3.5 N4-P13 - 철자가 아니라 해석된 형). 해석되지 않으면 소문자 이름(어느 허용 형과도 같지 않음)
    param($TypeName)
    try {
        $resolvedType = $TypeName.GetReflectionType()
        if ($null -ne $resolvedType) { return [string]$resolvedType.FullName }
    } catch {
        # 해석 실패 = 아래 소문자 이름으로 (허용 형 목록에 들지 않음)
    }
    return ([string]$TypeName.FullName).ToLowerInvariant()
}

$SYMMETRIC_OPERATORS = @('Ieq', 'Ine', 'Ceq', 'Cne')   # 피연산자 자리 무관 비교 (명세 3.5 N4-P13 '대칭 비교의 피연산자 자리 무관')
function ConvertTo-AstKey {
    # AST 구조 문자열 - 공백·줄 이음·주석·괄호 한 겹·따옴표 꼴·연산자와 변수 이름의 대소문자 · 대칭 비교의 피연산자 자리에 무관 (뜻에 닿는 구조만 남김)
    param($Node)
    $inner = Get-InnerExpression $Node
    if ($null -eq $inner) { return 'NULL' }
    if ($inner -is [AssignmentStatementAst]) { return ('Asg(' + (ConvertTo-AstKey $inner.Left) + '|' + $inner.Operator + '|' + (ConvertTo-AstKey $inner.Right) + ')') }
    if ($inner -is [BinaryExpressionAst]) {
        $operatorName = [string]$inner.Operator
        $leftKey = ConvertTo-AstKey $inner.Left
        $rightKey = ConvertTo-AstKey $inner.Right
        if (($SYMMETRIC_OPERATORS -contains $operatorName) -and ([string]::CompareOrdinal($leftKey, $rightKey) -gt 0)) { $swapKey = $leftKey; $leftKey = $rightKey; $rightKey = $swapKey }
        return ('Bin(' + $operatorName + '|' + $leftKey + '|' + $rightKey + ')')
    }
    if ($inner -is [UnaryExpressionAst]) {
        $tokenName = [string]$inner.TokenKind
        if ($tokenName -eq 'Exclaim') { $tokenName = 'Not' }
        return ('Un(' + $tokenName + '|' + (ConvertTo-AstKey $inner.Child) + ')')
    }
    if ($inner -is [ConvertExpressionAst]) { return ('Cv(' + (Get-ResolvedTypeName $inner.Type.TypeName) + '|' + (ConvertTo-AstKey $inner.Child) + ')') }
    if ($inner -is [VariableExpressionAst]) { return ('V(' + $inner.VariablePath.UserPath.ToLowerInvariant() + ')') }
    if ($inner -is [StringConstantExpressionAst]) { return ('S(' + $inner.Value + ')') }
    if ($inner -is [ConstantExpressionAst]) { return ('C(' + $inner.StaticType.Name + ':' + [string]$inner.Value + ')') }
    if ($inner -is [ExpandableStringExpressionAst]) { return ('X(' + $inner.Value + ')') }
    if ($inner -is [InvokeMemberExpressionAst]) {
        $argumentKeys = (@($inner.Arguments | ForEach-Object { ConvertTo-AstKey $_ })) -join ','
        return ('Inv(' + (ConvertTo-AstKey $inner.Expression) + '|' + $inner.Static + '|' + $inner.Member.Extent.Text.ToLowerInvariant() + '|' + $argumentKeys + ')')
    }
    if ($inner -is [MemberExpressionAst]) { return ('M(' + (ConvertTo-AstKey $inner.Expression) + '|' + $inner.Static + '|' + $inner.Member.Extent.Text.ToLowerInvariant() + ')') }
    if ($inner -is [ArrayExpressionAst]) { return ('Arr(' + (ConvertTo-AstKey $inner.SubExpression) + ')') }
    if ($inner -is [ArrayLiteralAst]) { return ('Lit(' + ((@($inner.Elements | ForEach-Object { ConvertTo-AstKey $_ })) -join ',') + ')') }
    if ($inner -is [SubExpressionAst]) { return ('Sub(' + (ConvertTo-AstKey $inner.SubExpression) + ')') }
    if ($inner -is [StatementBlockAst]) { return ('Blk(' + ((@($inner.Statements | ForEach-Object { ConvertTo-AstKey $_ })) -join ';') + ')') }
    if ($inner -is [PipelineAst]) { return ('Pipe(' + ((@($inner.PipelineElements | ForEach-Object { ConvertTo-AstKey $_ })) -join '>') + ')') }
    if ($inner -is [CommandAst]) {
        $elementKeys = @()
        for ($elementIndex = 0; $elementIndex -lt $inner.CommandElements.Count; $elementIndex++) {
            $element = $inner.CommandElements[$elementIndex]
            if ($element -is [CommandParameterAst]) {
                $parameterArgument = $(if ($null -ne $element.Argument) { ':' + (ConvertTo-AstKey $element.Argument) } else { '' })
                $elementKeys += ('P(' + $element.ParameterName.ToLowerInvariant() + $parameterArgument + ')')
            } elseif (($elementIndex -eq 0) -and ($element -is [StringConstantExpressionAst])) {
                $elementKeys += ('W(' + $element.Value.ToLowerInvariant() + ')')
            } else {
                $elementKeys += (ConvertTo-AstKey $element)
            }
        }
        return ('Cmd(' + ($elementKeys -join ' ') + ')')
    }
    if ($inner -is [TypeExpressionAst]) { return ('T(' + (Get-ResolvedTypeName $inner.TypeName) + ')') }
    if ($inner -is [ContinueStatementAst]) { return 'Continue' }
    if ($inner -is [BreakStatementAst]) { return 'Break' }
    return ('?' + $inner.GetType().Name + '(' + (($inner.Extent.Text -replace '\s+', ' ').Trim()) + ')')
}

function Get-OrLeaves {
    # -or 로 이은 잎들 (괄호 무관 - 열거용, 호출부에서 @())
    param($Node)
    $inner = Get-InnerExpression $Node
    if (($inner -is [BinaryExpressionAst]) -and ($inner.Operator -eq [TokenKind]::Or)) { return @(@(Get-OrLeaves $inner.Left) + @(Get-OrLeaves $inner.Right)) }
    return $inner
}

function Get-AndLeaves {
    # -and 로 이은 잎들 (괄호·묶음 무관 - 열거용, 호출부에서 @())
    param($Node)
    $inner = Get-InnerExpression $Node
    if (($inner -is [BinaryExpressionAst]) -and ($inner.Operator -eq [TokenKind]::And)) { return @(@(Get-AndLeaves $inner.Left) + @(Get-AndLeaves $inner.Right)) }
    return $inner
}

function Get-StringConstantList {
    # 상수 목록 - @('a', 'b') · ('a', 'b') · 'a', 'b' · 'a' 꼴의 문자열 상수만(변수·확장 문자열·명령·중첩 0). 아니면 $null. 단일 객체 반환(,배열 - 호출부는 @() 로 감싸지 않음)
    param($Node)
    $inner = Get-InnerExpression $Node
    if ($inner -is [ArrayExpressionAst]) {
        $innerStatements = @($inner.SubExpression.Statements)
        if ($innerStatements.Count -ne 1) { return $null }
        $inner = Get-InnerExpression $innerStatements[0]
        if ($inner -is [StringConstantExpressionAst]) { return , @([string]$inner.Value) }
        if (-not ($inner -is [ArrayLiteralAst])) { return $null }
    }
    if ($inner -is [ArrayLiteralAst]) {
        $listValues = @()
        foreach ($listElement in $inner.Elements) {
            $elementInner = Get-InnerExpression $listElement
            if (-not ($elementInner -is [StringConstantExpressionAst])) { return $null }
            $listValues += [string]$elementInner.Value
        }
        return , $listValues
    }
    if ($inner -is [StringConstantExpressionAst]) { return , @([string]$inner.Value) }
    return $null
}

function Test-ExactMatchSet {
    # 정확 일치 판정 (명세 3.5 R5-P16 ③ 계열) - -or 로만 이은 비교들이고 비교마다 주제와 문자열 상수의 -eq/-ceq(상수가 어느 쪽이든) · 상수 목록 -contains/
    # -ccontains 주제 · 주제 -in/-cin 상수 목록이며, 쓰인 상수 집합(중복·순서 무관)이 정확히 Want 이면 'OK'. 부분 일치·부정·그 밖 연산자·메서드는 거부(사유 문자열)
    param($Expression, [scriptblock]$IsSubject, [string[]]$Want)
    $usedValues = @()
    foreach ($leaf in @(Get-OrLeaves $Expression)) {
        if (-not ($leaf -is [BinaryExpressionAst])) { return ('잎=' + $leaf.GetType().Name) }
        $operatorName = [string]$leaf.Operator
        if (@('Ieq', 'Ceq') -contains $operatorName) {
            $leftInner = Get-InnerExpression $leaf.Left
            $rightInner = Get-InnerExpression $leaf.Right
            if ((& $IsSubject $leftInner) -and ($rightInner -is [StringConstantExpressionAst])) { $usedValues += [string]$rightInner.Value }
            elseif ((& $IsSubject $rightInner) -and ($leftInner -is [StringConstantExpressionAst])) { $usedValues += [string]$leftInner.Value }
            else { return 'eq 꼴 아님' }
        } elseif (@('Icontains', 'Ccontains') -contains $operatorName) {
            $constantList = Get-StringConstantList $leaf.Left
            if (($null -eq $constantList) -or (-not (& $IsSubject (Get-InnerExpression $leaf.Right)))) { return 'contains 꼴 아님' }
            $usedValues += $constantList
        } elseif (@('Iin', 'Cin') -contains $operatorName) {
            $constantList = Get-StringConstantList $leaf.Right
            if (($null -eq $constantList) -or (-not (& $IsSubject (Get-InnerExpression $leaf.Left)))) { return 'in 꼴 아님' }
            $usedValues += $constantList
        } else {
            return ('연산자=' + $operatorName)
        }
    }
    $usedSet = @($usedValues | Sort-Object -Unique -CaseSensitive)
    $wantSet = @($Want | Sort-Object -Unique -CaseSensitive)
    if (($usedSet -join "`n") -cne ($wantSet -join "`n")) { return ('상수 집합=[' + ($usedSet -join ' | ') + ']') }
    return 'OK'
}

function Get-DeclaredParameterNames {
    # 워커 함수의 선언 매개변수 이름 차례 (위치 인자 대응용) - 워커 함수가 아니면 빈 목록 (열거용 - 호출부에서 @())
    param([string]$FunctionName)
    if (-not $workerFunctions.ContainsKey($FunctionName)) { return @() }
    $declaredBlock = $workerFunctions[$FunctionName].Body.ParamBlock
    if ($null -eq $declaredBlock) { return @() }
    return @($declaredBlock.Parameters | ForEach-Object { [string]$_.Name.VariablePath.UserPath })
}

function Get-CommandArgument {
    # 명령 호출의 매개변수 인자 식 - '-이름 값' · '-이름:값' · 이름 없는 위치 인자(PositionalNames 차례 - 주지 않으면 그 명령이 워커 함수일 때 선언 차례).
    # 없으면 $null (명세 3.5 '인자 꼴 무관')
    param($Command, [string]$Name, [string[]]$PositionalNames = $null)
    $elements = @($Command.CommandElements)
    $positionalArguments = New-Object System.Collections.Generic.List[object]
    $foundArgument = $null
    $elementIndex = 1
    while ($elementIndex -lt $elements.Count) {
        $element = $elements[$elementIndex]
        if ($element -is [CommandParameterAst]) {
            $parameterArgument = $null
            if ($null -ne $element.Argument) { $parameterArgument = $element.Argument; $elementIndex++ }
            elseif (($elementIndex + 1 -lt $elements.Count) -and (-not ($elements[$elementIndex + 1] -is [CommandParameterAst]))) { $parameterArgument = $elements[$elementIndex + 1]; $elementIndex += 2 }
            else { $elementIndex++ }
            if (($null -eq $foundArgument) -and ($element.ParameterName -eq $Name)) { $foundArgument = $parameterArgument }
            continue
        }
        $positionalArguments.Add($element)
        $elementIndex++
    }
    if ($null -ne $foundArgument) { return $foundArgument }
    # 위치 차례 - $( ) 로 받으면 빈 배열이 $null 로 풀리므로 대입으로만 만듭니다 (PS 5.1)
    [string[]]$positionOrder = @()
    if ($null -ne $PositionalNames) { $positionOrder = @($PositionalNames) } else { $positionOrder = @(Get-DeclaredParameterNames -FunctionName $Command.GetCommandName()) }
    $position = [Array]::IndexOf($positionOrder, $Name)
    if (($position -ge 0) -and ($position -lt $positionalArguments.Count)) { return $positionalArguments[$position] }
    return $null
}

function Get-StatementCommand {
    # 문장이 명령 하나짜리 파이프라인이면 그 명령 (아니면 $null)
    param($Statement)
    if (($Statement -is [PipelineAst]) -and ($Statement.PipelineElements.Count -eq 1) -and ($Statement.PipelineElements[0] -is [CommandAst])) { return $Statement.PipelineElements[0] }
    return $null
}

function Get-HashtableStringValue {
    # 해시 리터럴에서 키의 문자열 상수 값 (없거나 상수가 아니면 $null)
    param($Table, [string]$Key)
    foreach ($pair in $Table.KeyValuePairs) {
        $keyNode = Get-InnerExpression $pair.Item1
        if (($keyNode -is [StringConstantExpressionAst]) -and ($keyNode.Value -eq $Key)) {
            $valueNode = Get-InnerExpression $pair.Item2
            if ($valueNode -is [StringConstantExpressionAst]) { return [string]$valueNode.Value }
        }
    }
    return $null
}

# ── §2 소스 캡처 (명세 2.2-3 · 3.2.1 - 상수 셋 · 영역 셋 · 던전 키워드 · 원인 둘 · throw 문구 둘 · 대기 값 · 스윕 안 양보 문맥) ─────────────────
# config 를 읽는 대입($rgAbyssMenu · $rgQuestTracker)은 Get-ConfigValue '기본값 반환' 모의와 $config = $null 위에서 평가합니다(test_abyss_party_member.ps1 §0 과 같음)
$config = $null
function Get-ConfigValue { param([object]$Root, [string[]]$Path, $Default) return $Default }
function Get-SourceAssignmentValue {
    # 워커 최상위(함수 밖) 첫 대입문의 우변을 평가해 돌려줍니다 (없으면 throw - 상수가 사라진 것 자체가 결함)
    param([string]$Name)
    $assignmentNodes = @($workerAst.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and ($candidate.Left.Extent.Text -eq ('$' + $Name)) }, $true) |
            Where-Object { -not (Test-AstInsideFunction $_) } | Sort-Object { $_.Extent.StartOffset })
    if ($assignmentNodes.Count -lt 1) { throw "워커 최상위(함수 밖)에서 `$$Name 대입문을 찾지 못했습니다" }
    return (Invoke-Expression $assignmentNodes[0].Right.Extent.Text)
}
try {
    $abyssReclickQuietSeconds = Get-SourceAssignmentValue 'abyssReclickQuietSeconds'
    $memberSweepStreakLimit = Get-SourceAssignmentValue 'memberSweepStreakLimit'
    $memberFieldSettleSeconds = Get-SourceAssignmentValue 'memberFieldSettleSeconds'
    $allDungeonKeywords = @(Get-SourceAssignmentValue 'allDungeonKeywords')       # 첫 대입(내장 목록) - 추적기 판독문을 원문 Test-InDungeonQuest 로 판정
    $rgQuestTracker = @(Get-SourceAssignmentValue 'rgQuestTracker')
    $rgAbyssMenu = @(Get-SourceAssignmentValue 'rgAbyssMenu')
    $rgClearScore = @(Get-SourceAssignmentValue 'rgClearScore')
} catch {
    "FAIL 준비: 소스 값 캡처 실패 ($($_.Exception.Message))"
    exit 1
}
# 무변화 창 상수가 없거나 0 이면 0초 시계가 되어 결과가 조용히 바뀝니다 (명세 3.2.1 끝 줄 - 준비 단계에서 끝냄)
if (($null -eq $abyssReclickQuietSeconds) -or (-not ($abyssReclickQuietSeconds -is [int])) -or ([int]$abyssReclickQuietSeconds -le 0)) {
    "FAIL 준비: `$abyssReclickQuietSeconds 캡처값이 양의 정수가 아닙니다 ([$abyssReclickQuietSeconds])"
    exit 1
}
$Q = [int]$abyssReclickQuietSeconds

try {
    # 원인 둘 - Get-CaptureFailInfo 의 'rect-failed' 갈래(run:3571~3576) · 함수 끝 return(run:3601~3604)
    $failInfoNode = Get-WorkerFunction 'Get-CaptureFailInfo'
    $rectFailedIfs = @($failInfoNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and ((Get-NodeCode $candidate.Clauses[0].Item1) -ceq "`$GameWindowIssue -eq 'rect-failed'") }, $true))
    if ($rectFailedIfs.Count -ne 1) { throw "Get-CaptureFailInfo 의 'rect-failed' 갈래가 $($rectFailedIfs.Count)개입니다(1개여야 함)" }
    $rectFailedReturn = @($rectFailedIfs[0].Clauses[0].Item2.Statements)[0]
    $otherReturn = @($failInfoNode.Body.EndBlock.Statements)[-1]
    if (-not (($rectFailedReturn -is [ReturnStatementAst]) -and ((Get-InnerExpression $rectFailedReturn.Pipeline) -is [HashtableAst]))) { throw "'rect-failed' 갈래 첫 문장이 해시 return 이 아닙니다" }
    if (-not (($otherReturn -is [ReturnStatementAst]) -and ((Get-InnerExpression $otherReturn.Pipeline) -is [HashtableAst]))) { throw 'Get-CaptureFailInfo 끝 문장이 해시 return 이 아닙니다' }
    $WINDOW_GONE_CAUSE = Get-HashtableStringValue -Table (Get-InnerExpression $rectFailedReturn.Pipeline) -Key 'Cause'
    $OTHER_CAUSE = Get-HashtableStringValue -Table (Get-InnerExpression $otherReturn.Pipeline) -Key 'Cause'
    if (-not $WINDOW_GONE_CAUSE -or -not $OTHER_CAUSE) { throw "원인 상수를 읽지 못했습니다 ([$WINDOW_GONE_CAUSE] / [$OTHER_CAUSE])" }

    # throw 문구 둘 - 판독 경로 Get-GameRegionCapture 의 창 사각형 실패 갈래(run:3869~3870 - 등록 뒤 스위치일 때만 throw) · 클릭 경로
    # Get-ScaledScreenPoint 의 창 좌표 실패(run:2920~2922 - 등록 없이 throw)
    $captureNode = Get-WorkerFunction 'Get-GameRegionCapture'
    $readThrowIfs = @($captureNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-IsVariable $candidate.Clauses[0].Item1 'ThrowOnWindowRectFailure') }, $true))
    if ($readThrowIfs.Count -ne 1) { throw "Get-GameRegionCapture 의 -ThrowOnWindowRectFailure 갈래가 $($readThrowIfs.Count)개입니다(1개여야 함)" }
    $readThrowStatement = @($readThrowIfs[0].Clauses[0].Item2.Statements)[0]
    if (-not (($readThrowStatement -is [ThrowStatementAst]) -and ((Get-InnerExpression $readThrowStatement.Pipeline) -is [StringConstantExpressionAst]))) { throw '판독 경로 throw 가 문자열 상수가 아닙니다' }
    $READ_PATH_MESSAGE = [string](Get-InnerExpression $readThrowStatement.Pipeline).Value
    $scaledPointNode = Get-WorkerFunction 'Get-ScaledScreenPoint'
    $clickRectIfs = @($scaledPointNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and
                (@($candidate.Clauses[0].Item1.FindAll({ param($member) ($member -is [InvokeMemberExpressionAst]) -and ($member.Member.Extent.Text -eq 'GetWindowRect') }, $true)).Count -gt 0) }, $true))
    if ($clickRectIfs.Count -ne 1) { throw "Get-ScaledScreenPoint 의 창 좌표 실패 갈래가 $($clickRectIfs.Count)개입니다(1개여야 함)" }
    $clickRectStatements = @($clickRectIfs[0].Clauses[0].Item2.Statements)
    if (($clickRectStatements.Count -ne 1) -or (-not ($clickRectStatements[0] -is [ThrowStatementAst])) -or
        (-not ((Get-InnerExpression $clickRectStatements[0].Pipeline) -is [StringConstantExpressionAst]))) { throw '클릭 경로 창 좌표 실패 갈래가 등록 없는 문자열 throw 하나가 아닙니다' }
    $CLICK_PATH_MESSAGE = [string](Get-InnerExpression $clickRectStatements[0].Pipeline).Value
    $THIRD_MESSAGE = 'X ' + $CLICK_PATH_MESSAGE   # 두 문구의 공통 꼬리를 품지만 어느 쪽도 아닌 셋째 문구 (N4-L3′ - 다시 박지 않고 캡처에서 만듦)

    # 선분기(Invoke-AbyssHandoffStart - ④ 무변경)의 대기 값 둘 - while 끝 기본 대기(run:15283 · R5-P1 ⑫ 앵커의 값)와 복구 회전 대기(run:15279~15281)
    $selectorNode = Get-WorkerFunction 'Invoke-AbyssHandoffStart'
    $selectorWhile = $selectorNode.Find({ param($candidate) $candidate -is [WhileStatementAst] }, $true)
    $selectorLastCommand = Get-StatementCommand (@($selectorWhile.Body.Statements)[-1])
    if (($null -eq $selectorLastCommand) -or ($selectorLastCommand.GetCommandName() -ne 'Start-Sleep')) { throw '선분기 while 끝 문장이 Start-Sleep 이 아닙니다' }
    $baseWaitArgument = Get-CommandArgument -Command $selectorLastCommand -Name 'Milliseconds' -PositionalNames @()
    if ($null -eq $baseWaitArgument) { throw '선분기 while 끝 대기에 -Milliseconds 가 없습니다' }
    $BASE_WAIT_KEY = ConvertTo-AstKey $baseWaitArgument
    $BASE_WAIT_MS = [int](Invoke-Expression $baseWaitArgument.Extent.Text)
    $selectorRecoveredIfs = @($selectorWhile.Body.Statements | Where-Object { ($_ -is [IfStatementAst]) -and (Test-IsVariable $_.Clauses[0].Item1 'turnRecovered') })
    if ($selectorRecoveredIfs.Count -ne 1) { throw "선분기 while 직속 복구 회전 if 가 $($selectorRecoveredIfs.Count)개입니다(1개여야 함)" }
    $recoveredWaitCommand = Get-StatementCommand (@($selectorRecoveredIfs[0].Clauses[0].Item2.Statements)[0])
    $recoveredWaitArgument = $(if ($null -ne $recoveredWaitCommand) { Get-CommandArgument -Command $recoveredWaitCommand -Name 'Seconds' -PositionalNames @('Seconds') } else { $null })
    if ($null -eq $recoveredWaitArgument) { throw '선분기 복구 회전 대기(Start-Sleep -Seconds)를 찾지 못했습니다' }
    $RECOVERED_WAIT_MS = [int](Invoke-Expression $recoveredWaitArgument.Extent.Text) * 1000

    # 스윕 안 양보 문맥 - 원문 구매 팝업 닫기의 Wait-UserYieldEnd -Context 상수(run:7661 - 'ua-wait' 모의가 같은 문맥으로 부름 · N4-L13′)
    $sweepYieldCalls = @(Get-CommandNodes -Node (Get-WorkerFunction 'Invoke-PurchasePopupSweep') -Name 'Wait-UserYieldEnd')
    if ($sweepYieldCalls.Count -ne 1) { throw "공용 스윕의 Wait-UserYieldEnd 호출이 $($sweepYieldCalls.Count)개입니다(1개여야 함)" }
    $sweepYieldContextNode = Get-InnerExpression (Get-CommandArgument -Command $sweepYieldCalls[0] -Name 'Context')
    if (-not ($sweepYieldContextNode -is [StringConstantExpressionAst])) { throw '공용 스윕의 양보 문맥이 문자열 상수가 아닙니다' }
    $SWEEP_YIELD_CONTEXT = [string]$sweepYieldContextNode.Value

    # 안전 확인의 F9 조기 종료 문턱(초) - 원문 run:3814 '((Get-Date) - $script:captureFailingSince).TotalSeconds -lt N' (WA-L30 (가) 의 기대)
    $safeStopThresholdNodes = @((Get-WorkerFunction 'Test-SafeStopDuringCaptureFail').FindAll({ param($candidate) ($candidate -is [BinaryExpressionAst]) -and
                ($candidate.Operator -eq [TokenKind]::Ilt) -and (Test-HasVariable $candidate.Left 'script:captureFailingSince') -and ($candidate.Right -is [ConstantExpressionAst]) }, $true))
    if ($safeStopThresholdNodes.Count -ne 1) { throw "안전 확인의 캡처 실패 지속 문턱이 $($safeStopThresholdNodes.Count)개입니다(1개여야 함)" }
    $SAFE_STOP_SECONDS = [double]$safeStopThresholdNodes[0].Right.Value
} catch {
    "FAIL 준비: 원문 구조 캡처 실패 ($($_.Exception.Message))"
    exit 1
}
"INFO 캡처: Q ${Q}초 · W ${memberFieldSettleSeconds}초 · 스윕 연속 한도 $memberSweepStreakLimit · 원인 $WINDOW_GONE_CAUSE/$OTHER_CAUSE · 기본 대기 ${BASE_WAIT_MS}ms · 복구 대기 ${RECOVERED_WAIT_MS}ms · 안전 확인 문턱 ${SAFE_STOP_SECONDS}초 · 판독 경로 문구 [$READ_PATH_MESSAGE] · 클릭 경로 문구 [$CLICK_PATH_MESSAGE]"

# ── §3 추출 · 감시 · 모의 (명세 3.2.1) ──────────────────────────────────────────────────────────────────────────
# 원문 그대로 올리는 함수 (사본 재구현 금지 - Get-SourceFunctionDefinitions 한 번으로 추출, 없는 이름은 예외 문구에 남음 - ③ 선례)
$ORIGINAL_FUNCTION_NAMES = @(
    'Wait-AbyssReentry', 'Resolve-AbyssReentryVerdict', 'Resolve-AbyssHandoffStartScreen', 'Test-AbyssFewMembersPopupText', 'Test-AbyssEntryWaitingText',
    'Test-AbyssRewardText', 'New-AbyssMemberClock', 'Update-AbyssMemberClockFreeze', 'Set-AbyssMemberClock', 'Suspend-AbyssMemberClock',
    'Resume-AbyssMemberClock', 'Test-AbyssMemberClockExpired', 'Get-FreezeAdjustedDeadline', 'Get-YieldAdjustedDeadline',
    'Invoke-UserYieldWithDeadline', 'Register-CaptureSuccess', 'Get-CaptureFailTotalMs', 'Test-AbyssReadyPanelText', 'Test-AbyssMatchingPanelText',
    'Step-AbyssFieldSettle',   # 필드 확정 걸음 - 대기 함수의 필드 결과 켬이 부름(구현 단위 5b-8 - 그 전에는 선분기만 불러 의존 추출이 묵시로 올림)
    'Resolve-AbyssResumeGrace')   # 재개 유예 판정 - 대기 함수 ⑩ 의 resume 유예 갈래가 부름 · §6a 진리표 RG 가 원문으로 돌림(구현 명세 ⑤c 2.4 · 2.5 · 3.4)
# 이름 바꿔 올리는 원문 (같은 이름은 아래 감시·모의가 차지). 앞 둘은 exit 센티널 치환 · 가운데 셋은 선단언 전용 · 끝은 스윕 생략 사유 분류 감시용
#   (명세 3.2.1 은 분류를 '원문 그대로' 로 적었습니다 - 이 파일은 같은 원문을 감시 뒤에 두어 회전마다 분류 결과를 기록합니다(WA-L13 'counted' 수 · WA-L14
#   '굶김 예산 미소모'). 감시는 받은 인자를 그대로 넘기고 결과를 그대로 돌려줘 동작이 같습니다)
$RENAMED_FUNCTIONS = [ordered]@{
    'Test-SafeStopDuringCaptureFail' = 'Invoke-RealTestSafeStopDuringCaptureFail'
    'Invoke-PurchasePopupSweep'      = 'Invoke-RealPurchasePopupSweep'
    'Test-InDungeonQuest'            = 'Invoke-RealTestInDungeonQuest'
    'Get-AbyssPanelKind'             = 'Invoke-RealGetAbyssPanelKind'
    'Test-DungeonClearPrompt'        = 'Invoke-RealTestDungeonClearPrompt'
    'Resolve-AbyssMemberSweepTurn'   = 'Invoke-RealResolveAbyssMemberSweepTurn'
}
$SENTINEL_FUNCTION_NAMES = @('Test-SafeStopDuringCaptureFail', 'Invoke-PurchasePopupSweep')
# 화면·입력·대기 모의 (원문 param 블록 + 스텁 몸통)
$STUB_MOCK_BODIES = [ordered]@{
    'Test-DungeonClearPrompt'    = 'return (Invoke-PromptStub -Game $Game)'
    'Get-AbyssPanelKind'         = 'return (Invoke-PanelStub -Game $Game)'
    'Test-HomeEndEscHud'         = 'return (Invoke-FlagStub -Game $Game -Name ''hud'' -Field ''Hud'')'
    'Test-InDungeonQuest'        = 'return (Invoke-FlagStub -Game $Game -Name ''quest'' -Field ''Quest'')'
    'Test-AbyssSelectionScreen'  = 'return (Invoke-FlagStub -Game $Game -Name ''selection'' -Field ''Selection'')'   # 구현 단위 5b-8 2.2-4a - 필드 결과 켬의 필드 모양 회전만 부름
    'Test-AbyssMenu'             = 'return (Invoke-FlagStub -Game $Game -Name ''menu'' -Field ''Menu'')'
    'Invoke-PurchasePopupSweep'  = 'return (Invoke-SweepStub -Game $Game)'
    'Test-CaptureRecovered'      = 'return (Invoke-ProbeStub -Game $Game)'
    'Test-UserRecentlyActive'    = 'return (Test-UserActiveStub)'
    'Wait-UserYieldEnd'          = 'Invoke-YieldStub -Game $Game -Context $Context'
    'Write-RunLog'               = '$script:rowLogs.Add([string]$Message)'
    'Test-GameRestartPopup'      = 'return [bool]$script:restartPopupMock'
    'Get-CaptureRecoveryMessage' = 'return ''[안내] 화면 캡처 복구 (모의)'''
    'Get-SessionStationName'     = 'return ''Console'''
}
# 선단언 전용 판독 둘 (영역 기준점별 지정 판독문 / 지정 하단 판독문) - 선단언 뒤 '닿으면 안 됨' 꼴로 다시 정의합니다
$PRE_ASSERT_MOCK_BODIES = [ordered]@{
    'Get-GameRegionOcrText' = '$regionKey = ''{0},{1}'' -f $ReferenceX, $ReferenceY; if ($script:preRegionTexts.ContainsKey($regionKey)) { return [string]$script:preRegionTexts[$regionKey] }; return '''''
    'Get-GameOcrText'       = 'return [string]$script:preBottomText'
}
# 기록 모의 - waiter 는 클릭·키·이벤트 정리·journal·시각 판단을 부르지 않습니다(행마다 호출 0 단언 - R5-P3·P4 를 행동으로도 봄)
$RECORD_MOCK_NAMES = @('Clear-EventOverlay', 'Click-GamePoint', 'Click-ScreenPoint', 'Focus-Game', 'Press-KeyOnce', 'Press-KeyVerified', 'Invoke-ClickUntil',
    'Invoke-AbyssExitClick', 'Return-ToAbyssSelection', 'Update-AbyssJournal', 'Read-AbyssJournal', 'Get-DgTimeVerdict')
# 닿으면 안 됨 - 실제 스윕의 그 밖 callee (WA-L29 는 재시작 팝업에서 끝나 닿지 않음)
$UNREACHABLE_NAMES = @('Move-CursorOutsideGame', 'Find-GameTextPoint', 'Close-QuestRewardScreen', 'Close-CoopMissionScreen', 'Close-CoopMissionBoardScreen',
    'Close-WeeklyCoopResetPopup', 'Close-NetworkUnstablePopup')
$CMDLET_MOCK_NAMES = @('Get-Date', 'Start-Sleep', 'Test-Path', 'Remove-Item')
$TEST_DEFINED_NAMES = @(@($STUB_MOCK_BODIES.Keys) + @($PRE_ASSERT_MOCK_BODIES.Keys) + $RECORD_MOCK_NAMES + $UNREACHABLE_NAMES + @($RENAMED_FUNCTIONS.Keys) + $CMDLET_MOCK_NAMES)

$sourceDefinitions = @()
try {
    $sourceDefinitions = @(Get-SourceFunctionDefinitions -Path $workerPath -Names $ORIGINAL_FUNCTION_NAMES)
} catch {
    "FAIL 준비: 워커에서 함수 원문을 추출하지 못했습니다 ($($_.Exception.Message))"
    exit 1
}
# 대기 함수·순수 판정은 exit 0 을 확인한 뒤 그대로 올립니다 - exit 가 있으면 같은 프로세스의 하니스가 끝나므로 준비 단계에서 멈춥니다(명세 3.2.1)
foreach ($targetName in @('Wait-AbyssReentry', 'Resolve-AbyssReentryVerdict', 'Resolve-AbyssResumeGrace')) {
    if (-not $workerFunctions.ContainsKey($targetName)) { "FAIL 준비: 워커 최상위에 $targetName 이(가) 없습니다"; exit 1 }
    $targetExits = @($workerFunctions[$targetName].FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count
    if ($targetExits -gt 0) { "FAIL 준비: $targetName 안에 exit ${targetExits}개 - 하니스를 같은 프로세스에서 돌릴 수 없습니다"; exit 1 }
}
foreach ($definition in $sourceDefinitions) { Invoke-Expression ([string]$definition) }

# 의존 추출 - 올린 함수들이 부르는 워커 최상위 함수 중 이 파일이 정의하지 않는 것 (구현이 도움 함수를 더해도 행이 돌게 - 그 사실은 정적 N4-P6 이 FAIL 로 알림)
$extractedNames = New-Object System.Collections.Generic.List[string]
foreach ($originalName in $ORIGINAL_FUNCTION_NAMES) { $extractedNames.Add($originalName) }
$dependencyQueue = New-Object System.Collections.Generic.Queue[string]
foreach ($queueName in @($ORIGINAL_FUNCTION_NAMES + @($RENAMED_FUNCTIONS.Keys))) { $dependencyQueue.Enqueue($queueName) }
$visitedNames = New-Object System.Collections.Generic.HashSet[string]
$extraDependencyNames = New-Object System.Collections.Generic.List[string]
while ($dependencyQueue.Count -gt 0) {
    $visitName = $dependencyQueue.Dequeue()
    if (-not $visitedNames.Add($visitName)) { continue }
    if (-not $workerFunctions.ContainsKey($visitName)) { continue }
    foreach ($calleeNode in $workerFunctions[$visitName].FindAll({ param($candidate) $candidate -is [CommandAst] }, $true)) {
        $calleeName = $calleeNode.GetCommandName()
        if ([string]::IsNullOrEmpty($calleeName)) { continue }
        if (($TEST_DEFINED_NAMES -contains $calleeName) -or $extractedNames.Contains($calleeName)) { continue }
        if (-not $workerFunctions.ContainsKey($calleeName)) { continue }
        $extractedNames.Add($calleeName)
        $extraDependencyNames.Add($calleeName)
        $dependencyQueue.Enqueue($calleeName)
    }
}
foreach ($extraName in $extraDependencyNames) { Invoke-Expression ([string]$workerFunctions[$extraName].Extent.Text) }
"INFO 원문 추출: $($ORIGINAL_FUNCTION_NAMES.Count)개 · 의존 추출로 더한 것 [$(@($extraDependencyNames) -join ', ')] · 이름 바꿔 올림 $($RENAMED_FUNCTIONS.Count)개"

function Convert-ExitSentinel {
    # exit 줄을 센티널 throw('__EXIT__N')로 바꿉니다 - 원본 ExitStatementAst 수 · 줄 단독 exit 수 · 치환 뒤 남은 수를 기록(아래에서 한꺼번에 단언 - 이 함수의
    # 출력이 곧 Invoke-Expression 에 넘길 정의 문자열이라 섞이면 안 됨 - test_abyss_party_member.ps1 §2 와 같은 구현)
    param([string]$Text, [string]$Label)
    $parseTokens = $null
    $parseErrors = $null
    $originalExitCount = @([Parser]::ParseInput($Text, [ref]$parseTokens, [ref]$parseErrors).FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count
    $lineExitCount = [regex]::Matches($Text, '(?m)^(\s*)exit (\d+)\s*$').Count
    $convertedText = $Text -replace '(?m)^(\s*)exit (\d+)\s*$', '$1throw "__EXIT__$2"'
    $remainingExitCount = @([Parser]::ParseInput($convertedText, [ref]$parseTokens, [ref]$parseErrors).FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count
    $script:sentinelChecks += , @($Label, $originalExitCount, $lineExitCount, $remainingExitCount)
    return $convertedText
}
$script:sentinelChecks = @()
foreach ($renameEntry in $RENAMED_FUNCTIONS.GetEnumerator()) {
    if (-not $workerFunctions.ContainsKey($renameEntry.Key)) { "FAIL 준비: 이름 바꿔 올릴 워커 함수 $($renameEntry.Key) 이(가) 없습니다"; exit 1 }
    $renameText = [string]$workerFunctions[$renameEntry.Key].Extent.Text
    if ($SENTINEL_FUNCTION_NAMES -contains $renameEntry.Key) { $renameText = Convert-ExitSentinel -Text $renameText -Label $renameEntry.Key }
    Invoke-Expression ($renameText -replace ('^function ' + [regex]::Escape($renameEntry.Key) + '\b'), ('function ' + $renameEntry.Value))
}

function New-MockDefinition {
    # 모의 정의 문자열 - 워커 원문의 param 블록 그대로 + 몸통 (서명이 늘 원문과 같음 - test_abyss_handoff_start.ps1 의 모의와 같은 방식)
    param([string]$Name, [string]$Body)
    if (-not $workerFunctions.ContainsKey($Name)) { throw "모의 대상 워커 함수 $Name 을(를) 찾지 못했습니다 (서명을 원문 param 블록에서 가져옴)" }
    $mockParamBlock = $workerFunctions[$Name].Body.ParamBlock
    $mockParamText = $(if ($null -ne $mockParamBlock) { $mockParamBlock.Extent.Text } else { '' })
    return ("function $Name {`r`n$mockParamText`r`n$Body`r`n}")
}
try {
    foreach ($stubEntry in $STUB_MOCK_BODIES.GetEnumerator()) { Invoke-Expression (New-MockDefinition -Name $stubEntry.Key -Body $stubEntry.Value) }
    foreach ($preEntry in $PRE_ASSERT_MOCK_BODIES.GetEnumerator()) { Invoke-Expression (New-MockDefinition -Name $preEntry.Key -Body $preEntry.Value) }
    foreach ($recordName in $RECORD_MOCK_NAMES) { Invoke-Expression (New-MockDefinition -Name $recordName -Body ("`$script:recordMockCalls['{0}'] = 1 + [int]`$script:recordMockCalls['{0}']" -f $recordName)) }
    foreach ($unreachableName in $UNREACHABLE_NAMES) { Invoke-Expression (New-MockDefinition -Name $unreachableName -Body ("throw 'TEST-UNREACHABLE: {0}'" -f $unreachableName)) }
    # 스윕 생략 사유 분류 감시 - 원문 param 블록 그대로 받아 실제 분류로 넘기고 결과의 Action 을 기록합니다
    Invoke-Expression (New-MockDefinition -Name 'Resolve-AbyssMemberSweepTurn' -Body '$sweepVerdict = Invoke-RealResolveAbyssMemberSweepTurn @PSBoundParameters; $script:sweepActions.Add([string]$sweepVerdict.Action); return $sweepVerdict')
} catch {
    "FAIL 준비: 모의 정의 실패 ($($_.Exception.Message))"
    exit 1
}

function Test-SafeStopDuringCaptureFail {
    # 안전 확인 감시 - 호출 수·시각을 기록하고 원문(센티널 치환본)으로 넘깁니다 (원문은 매개변수 없음 - 명세 3.2.1)
    $script:safeStopCalls++
    $script:currentReadRecord = $null
    Add-RowEvent -Kind 'safestop'
    Invoke-RealTestSafeStopDuringCaptureFail
}

# ── §4 하니스: 가상 시계 · 캡처 상태 모형 · 조작 주입 · 스윕 모의 · 판독 스텁 · 행 실행기 (명세 3.2.2~3.2.9) ────────────────────────────────
$ocrKoreanEngine = 'ko'                                     # 엔진 표식 (실제 OCR 없음 - 원문 판독 함수의 param 기본값이 읽음)
$safeStopFlagPath = 'HoneyNogi_reentry_safe_stop_test.flag'  # 안전 중지 파일 경로 표식 - 아래 Test-Path·Remove-Item 모의만 답함
$DEFAULT_YIELD_SECONDS = 3                                  # 조작 창 밖 양보 모의의 길이 (test_abyss_party_member.ps1 의 $script:yieldSeconds 와 같은 하니스 값)
$NEVER_ENDS_SECONDS = 1000000                               # 실패 창·스윕 창의 '끝없이' (가상 20000초 상한보다 김)
$TIME_EPSILON = 1e-6
$VIRTUAL_LIMIT_SECONDS = 20000
$CALL_LIMIT = 50000
$NOTICE_LINE_PREFIX = '[안내] 권장 인원 팝업 관측'           # 권장 인원 팝업 관측 안내 줄의 접두 (구현 명세 ④ 1.10 - test_log_tail_offset 보존 줄과 같은 접두)
$NOTICE_FULL_TEXT = '[안내] 권장 인원 팝업 관측(클릭 없음)'    # 그 줄 전체 (명세 1.10 의 제안 문구 - 정적 N4-P14)
$S2_LINE_PREFIX = '[어비스] 입장 계측'                         # 재입장 계측 줄(S2)을 고르는 접두
# S2 줄 정규식 - test_abyss_handoff_start.ps1 의 $S2_PATTERN 과 같은 꼴 (이름 묶음 u·f·part·s·b·w)
$S2_PATTERN = '^\[어비스\] 입장 계측 - 던전 안 2연속 앞 로딩\(알 수 없음\) (?<u>\d+)표본, 필드 모양 (?<f>\d+)표본(?<part>, 첫 필드 모양 표본부터 던전 안 (?<s>-?[0-9.]+)초)?, 관측 끊김 (?<b>\d+)회 \(필드 확정 폭 (?<w>[0-9.]+)초 계측 - 판정에 쓰지 않음\)$'

# 약어 → 화면 (명세 3.2.6 대응표). 하단 판독문은 실측 문자열 글자 그대로입니다 - 출처:
#   I  '&쇨죠돈출' cap_211244_025 (test_abyss_party_member.ps1:672 inside) · 추적기 판독문 $TRACKER_INSIDE_TEXT (같은 파일 :144 inside0929)
#   F  '' cap_210525_840 (:673 field) · 추적기 판독문 $TRACKER_FIELD_TEXT (:146 field0929)
#   U  '' 퇴장 로딩 cap_210521_682 (:679 loading)
#   R  09-18 3버튼 보상 (:182 reward3) · M 09-18 재매칭 패널 (:180 matching0918) · Rd cap_211944_558 (:171 ready211944) · E cap_212409_212 (:175 entry)
#   P  권장 인원 팝업 G4·G5·L2 (test_abyss_handoff_start.ps1:227 · 워커 Test-AbyssFewMembersPopupText 서명 주석의 실측) · S 09-21 S4 (:181 prompt)
#   Mn ESC 메뉴가 열린 채 공지사항 'Home' 배지가 HUD 로 읽힌 화면(워커 Test-AbyssMenu 2차 신호 주석의 2026-07-17 관측) · Sl 선택 화면 - 둘 다 판정값만
#      (구현 단위 5b-8 2.2-4a 의 두 판독 - 행 FC-L16 · FC-L17)
# 프롬프트·패널·추적기 값은 판정값이고 아래 선단언 ②③④ 가 실측 문자열에서 원문 판정으로 같은 값을 냄을 확인합니다. HUD 는 판정값만(tests\ 에 실측 문자열 없음)
$SCREEN_TABLE = [ordered]@{
    'I'  = @{ Bottom = '&쇨죠돈출'; Prompt = $false; Panel = 'none'; Hud = $true; Quest = $true }
    'F'  = @{ Bottom = ''; Prompt = $false; Panel = 'none'; Hud = $true; Quest = $false }
    'U'  = @{ Bottom = ''; Prompt = $false; Panel = 'none'; Hud = $false; Quest = $false }
    'R'  = @{ Bottom = '아이템을누르면상세정보테볼수있습니다나가기Space다세하기다른던전가기'; Prompt = $false; Panel = 'none'; Hud = $false; Quest = $false }
    'M'  = @{ Bottom = '사제아이템을누르면상세정보를7나가기'; Prompt = $false; Panel = 'matching'; Hud = $false; Quest = $false }
    'Rd' = @{ Bottom = '아이템을누르면상세정보를모든Space나가기'; Prompt = $false; Panel = 'ready'; Hud = $false; Quest = $false }
    'E'  = @{ Bottom = '아이템을누르면상세정보를수있습니다나가기입장대기중'; Prompt = $false; Panel = 'none'; Hud = $false; Quest = $false }
    'P'  = @{ Bottom = '㉬취소Space도전하기'; Prompt = $false; Panel = 'none'; Hud = $false; Quest = $false }
    'S'  = @{ Bottom = '화면을터치해주세요'; Prompt = $true; Panel = 'none'; Hud = $false; Quest = $false }
    'Mn' = @{ Bottom = ''; Prompt = $false; Panel = 'none'; Hud = $true; Quest = $false; Menu = $true }
    'Sl' = @{ Bottom = ''; Prompt = $false; Panel = 'none'; Hud = $true; Quest = $false; Selection = $true }
}
$SCREEN_KINDS = [ordered]@{ 'I' = 'inside'; 'F' = 'field'; 'U' = 'unknown'; 'R' = 'reward3'; 'M' = 'matching'; 'Rd' = 'ready'; 'E' = 'entry-waiting'; 'P' = 'popup'; 'S' = 'prompt'; 'Mn' = 'menu'; 'Sl' = 'selection' }
# 선단언 원료 - 패널 영역(abyssMenu 850,180,350,520 배율 4) 실측 판독문 · 추적기 영역 실측 판독문
$PANEL_TEXT_MATCHING = '빻지/입문근든플레이어가모이면자동입장합니다.00:00'                                             # 09-18 재매칭 1/4 (test_abyss_screen_signatures.ps1:70 $panelMenu1)
$PANEL_TEXT_READY = '박지/입문파티홍보패널100요동•X104,4385044화염술klülEl원이준비완료되면바로입장합니다.준비취소'      # 실기 -1 L1 (test_abyss_party_signatures.ps1:42 $menuLeaderL1)
$TRACKER_INSIDE_TEXT = '11:00뮈스트十-허상의정박지클리어•파티부활6회이내로글리어'                                      # cap_211244_025 (test_abyss_party_member.ps1:144)
$TRACKER_FIELD_TEXT = '추천밴스트十!목표]모험가길드의성기의회'                                                         # cap_210525_840 (같은 파일 :146)

# 가상 시계 - 판독은 시간을 쓰지 않고 Start-Sleep(① 2초 · ⑫ 700ms/2초)·양보·스윕 Gap 만 시계를 흘립니다 (Ticks 단위 - AddMilliseconds 정수 ms 반올림 회피)
function Get-VirtualTicks { return [long](($script:vclock - $script:caseStart).Ticks) }
function Get-VirtualElapsed { return ((Get-VirtualTicks) / 10000000.0) }   # TotalSeconds 는 3.5999… 오판 (test_abyss_return_loop.ps1 과 같은 이유)
function ConvertTo-Ticks { param([double]$Seconds) return [long][Math]::Round($Seconds * 10000000) }
function Step-VirtualClock {
    # 가상 시계를 흘립니다 - 가상 20000초를 넘으면 '__VTIMEOUT__' (마감을 못 보는 변이가 러너를 멈추지 않게)
    #   시계 훅($script:clockHooks)은 흘린 뒤 차례로 부릅니다 - §9 행만 세웁니다(OW28 · OS4r 의 일련번호 +1 → 되돌림, 구현 명세 ⑤b3 2.2). §7 행은 훅이 없어 동작 같음
    param([double]$Seconds)
    $script:vclock = $script:vclock.AddTicks((ConvertTo-Ticks $Seconds))
    if ((Get-VirtualElapsed) -gt $VIRTUAL_LIMIT_SECONDS) { throw '__VTIMEOUT__' }
    foreach ($clockHook in @($script:clockHooks)) { if ($null -ne $clockHook) { $null = & $clockHook } }
}
function Test-VirtualTimeIn {
    # 지금 가상 시각이 [From, Until) 안인지 (Ticks 비교)
    param([double]$From, [double]$Until)
    $nowTicks = Get-VirtualTicks
    return (($nowTicks -ge (ConvertTo-Ticks $From)) -and ($nowTicks -lt (ConvertTo-Ticks $Until)))
}

function Add-RowEvent {
    # 사건 기록 (순서 판정용 - 명세 3.2.8): 스윕(진입 시각) · 안전 확인 · 탐침(결과) · 양보(시작 시각·길이) · Start-Sleep(시각·길이)
    param([string]$Kind, $Ok = $null, $Ms = $null, $Length = $null)
    $script:rowEvents.Add([pscustomobject]@{ T = (Get-VirtualElapsed); Kind = $Kind; Ok = $Ok; Ms = $Ms; Length = $Length })
}

function Add-GameSeen {
    # N4-L5 - 판독 스텁 넷·스윕·탐침·양보가 받은 -Game 이 행이 넘긴 표식 객체와 같은지
    param([string]$Kind, $Game)
    $script:gameSeen.Add(('{0}:{1}' -f $Kind, [object]::ReferenceEquals($Game, $script:gameMarker)))
}

# Get-Date · Start-Sleep 모의 - waiter·시계·원문 성공 등록·안전 확인 모두 매개변수 없이 Get-Date 를 부릅니다. Start-Sleep 은 실제 위치 차례(-Seconds 먼저)
function Get-Date { return $script:vclock }
function Start-Sleep {
    param([int]$Seconds = 0, [int]$Milliseconds = 0)
    $sleepMs = $Seconds * 1000 + $Milliseconds
    $script:currentReadRecord = $null
    $script:turnFailSeen = $false
    Add-RowEvent -Kind 'sleep' -Ms $sleepMs
    Step-VirtualClock ($sleepMs / 1000.0)
}
# 원문 안전 확인의 F9 경로(run:3812·3815) - 하니스의 안전 중지 파일 표식만 답합니다 (test_abyss_party_member.ps1 과 같은 꼴)
function Test-Path {
    param($LiteralPath, $Path, $PathType)
    if ([string]$LiteralPath -eq $safeStopFlagPath) { return [bool]$script:safeStopFlagMock }
    return $false
}
function Remove-Item {
    param($LiteralPath, $Path, [switch]$Force, $ErrorAction)
    if ([string]$LiteralPath -eq $safeStopFlagPath) {
        $script:safeStopFlagMock = $false
        $script:safeStopRemoves++
    }
}

# 캡처 상태 모형 (명세 3.2.3 - 원문 변수 이름의 한 이름 공간). 성공 등록·누적은 원문 Register-CaptureSuccess·Get-CaptureFailTotalMs 이고 실패 등록만 모의합니다
#   (원문 Register-CaptureFailure 는 Get-CaptureFailInfo 가 세션 상태·[HoneyNogiInput] 을 불러 쓰지 않음). 원문 규칙 사본은 N4-P7 이 고정합니다
function Register-MockFail {
    # 실패 등록 모의 - 일련번호 +1 · 실패 시작이면 시작 시각 · 시작이거나 원인이 바뀌면 플래그·원인 갱신 (원문은 문구로 비교 - 두 원인의 문구가 1:1)
    param([string]$Cause = '')
    if (-not $Cause) { $Cause = $OTHER_CAUSE }
    $script:captureFailSerial++
    if (-not $script:screenCaptureFailing) {
        $script:captureFailingSince = Get-Date
        $script:failStarts.Add((Get-VirtualElapsed))
    }
    if ((-not $script:screenCaptureFailing) -or ($script:captureFailCause -ne $Cause)) {
        $script:screenCaptureFailing = $true
        $script:captureFailCause = $Cause
        $script:captureFailMessage = $Cause
    }
    $script:turnFailSeen = $true
    if ($null -ne $script:currentReadRecord) { $script:currentReadRecord.Fail = $true }
}
function Register-MockSuccess {
    # 성공 등록 = 원문 Register-CaptureSuccess. 실패가 끝나면 그 시각을 실패 구간 기록(사건 기록과 따로 둔 목록)에 남깁니다
    $wasFailing = [bool]$script:screenCaptureFailing
    Register-CaptureSuccess
    if ($wasFailing -and (-not $script:screenCaptureFailing)) { $script:failEnds.Add((Get-VirtualElapsed)) }
}
function Test-InFailWindow {
    # 지금이 실패 창 안인지 - 창 목록 [From, Until) · 주기 창(Start 부터 Period 마다 Length 초 - WA-L10 '끝없이')
    $nowTicks = Get-VirtualTicks
    foreach ($failWindow in $script:failWindows) { if (($nowTicks -ge $failWindow.FromTicks) -and ($nowTicks -lt $failWindow.UntilTicks)) { return $true } }
    if ($null -ne $script:failPeriodic) {
        $periodic = $script:failPeriodic
        if ($nowTicks -ge $periodic.StartTicks) {
            $phaseTicks = ($nowTicks - $periodic.StartTicks) % $periodic.PeriodTicks
            if ($phaseTicks -lt $periodic.LengthTicks) { return $true }
        }
    }
    return $false
}
function Invoke-CaptureAttempt {
    # 캡처 시도 한 번 (판독 스텁·탐침·스윕 첫 판독이 부름) - 실패 창 → 'other' 등록 · 거짓 / 교대(그 시각부터 판독 실패 · 탐침 성공) / 교대·패널 rect 전용(패널
    # 판독만 gameWindowGone 등록 → 판독 경로 문구 throw · 다른 판독·탐침 성공) / 같은 회전 복구(하단만 실패) / 훅(fail · failrect · rect · throw:<문구>) / 그 밖 → 성공
    param([string]$Name)
    $script:captureAttempts++
    if ($script:captureAttempts -gt $CALL_LIMIT) { throw '__VTIMEOUT__' }
    if (Test-InFailWindow) { Register-MockFail -Cause $OTHER_CAUSE; return $false }
    if (($script:alternateMode -ne '') -and ((Get-VirtualTicks) -ge (ConvertTo-Ticks $script:alternateFrom))) {
        if ($script:alternateMode -eq 'panelRect') {
            if ($Name -eq 'panel') { Register-MockFail -Cause $WINDOW_GONE_CAUSE; throw $READ_PATH_MESSAGE }
            Register-MockSuccess
            return $true
        }
        if ($script:alternateMode -eq 'sameTurn') {
            if ($Name -eq 'prompt') { Register-MockFail -Cause $OTHER_CAUSE; return $false }
        } else {
            if ($Name -eq 'probe') { Register-MockSuccess; return $true }
            Register-MockFail -Cause $OTHER_CAUSE
            return $false
        }
    }
    if ($null -ne $script:failHook) {
        $hookResult = "$(& $script:failHook $Name)"   # 훅이 아무것도 내지 않으면 [string](…) 은 $null 이라 확장 문자열로 받음 (PS 5.1)
        if ($hookResult -eq 'fail') { Register-MockFail -Cause $OTHER_CAUSE; return $false }
        if ($hookResult -eq 'failrect') { Register-MockFail -Cause $WINDOW_GONE_CAUSE; return $false }
        if ($hookResult -eq 'rect') { Register-MockFail -Cause $WINDOW_GONE_CAUSE; throw $READ_PATH_MESSAGE }
        if ($hookResult.StartsWith('throw:')) { throw $hookResult.Substring(6) }
    }
    Register-MockSuccess
    return $true
}

# 시각표 - 'X@a' 를 짝(약어, 시각)으로 받아 @{ At; S; Seq } 로 (한 칸 배열 풀림 회피 - 해시 · Seq 로 동률 안정)
function Set-ScreenPlan {
    param([object[]]$Pairs)
    if ((@($Pairs).Count % 2) -ne 0) { throw '시각표는 (약어, 시각) 짝이어야 합니다' }
    $planSteps = @()
    for ($pairIndex = 0; $pairIndex -lt @($Pairs).Count; $pairIndex += 2) {
        $screenKey = [string]$Pairs[$pairIndex]
        if (-not $SCREEN_TABLE.Contains($screenKey)) { throw "시각표의 약어 $screenKey 이(가) 대응표에 없습니다" }
        $planSteps += @{ AtTicks = (ConvertTo-Ticks ([double]$Pairs[$pairIndex + 1])); S = $screenKey; Seq = ($pairIndex / 2) }
    }
    $script:screenPlan = @($planSteps | Sort-Object @{ Expression = { $_.AtTicks } }, @{ Expression = { $_.Seq } })
}
function Get-ScreenNow {
    # 시각표의 지금 화면 - 시각 ≤ 지금인 마지막 단계 (첫 단계보다 이르면 첫 단계)
    $nowTicks = Get-VirtualTicks
    $screenKey = [string]$script:screenPlan[0].S
    foreach ($planStep in $script:screenPlan) { if ($planStep.AtTicks -le $nowTicks) { $screenKey = [string]$planStep.S } }
    return $screenKey
}
function Add-FailWindow { param([double]$From, [double]$Until) $script:failWindows.Add(@{ FromTicks = (ConvertTo-Ticks $From); UntilTicks = (ConvertTo-Ticks $Until) }) }
function Set-FailPeriodic { param([double]$Start, [double]$Period, [double]$Length) $script:failPeriodic = @{ StartTicks = (ConvertTo-Ticks $Start); PeriodTicks = (ConvertTo-Ticks $Period); LengthTicks = (ConvertTo-Ticks $Length) } }
function Set-CaptureAlternate { param([double]$From, [string]$Mode = 'normal') $script:alternateFrom = $From; $script:alternateMode = $Mode }
function Add-ActiveWindow { param([double]$From, [double]$Until) $script:activeWindows.Add(@{ From = $From; Until = $Until; FromTicks = (ConvertTo-Ticks $From); UntilTicks = (ConvertTo-Ticks $Until) }) }
function Get-ActiveWindowNow {
    # 지금을 덮는 조작 창 (없으면 $null)
    $nowTicks = Get-VirtualTicks
    foreach ($activeWindow in $script:activeWindows) { if (($nowTicks -ge $activeWindow.FromTicks) -and ($nowTicks -lt $activeWindow.UntilTicks)) { return $activeWindow } }
    return $null
}
function Set-SweepFrom {
    # 스윕 계획 하나를 더합니다 (명세 3.2.5 - test_abyss_party_member.ps1 Set-SweepFrom 의 -From -Kind -Gap -Count + -Until(창 끝) · -Message(throw 문구) ·
    # 계획 여러 개 - 지금 시각이 든 첫 계획 · 계획마다 횟수. -Count -1 = 영구). 클로저를 쓰지 않습니다(규칙 3). 행 시작에 비웁니다
    param([double]$From, [double]$Until = 1000000, [string]$Kind, [double]$Gap = 1.0, [int]$Count = -1, [switch]$Alternate, [string]$Message = '')
    $script:sweepPlans.Add(@{ FromTicks = (ConvertTo-Ticks $From); UntilTicks = (ConvertTo-Ticks $Until); Kind = $Kind; Gap = $Gap; Count = $Count; Alternate = [bool]$Alternate
            AlternateTurn = 0; AlternateFirstTrue = ($From -gt 0); Message = $Message })
}
function Get-ActiveSweepPlan {
    # 지금 시각이 든 첫 계획 (횟수가 남은 것) - 없으면 $null
    $nowTicks = Get-VirtualTicks
    foreach ($sweepPlan in $script:sweepPlans) {
        if (($nowTicks -ge $sweepPlan.FromTicks) -and ($nowTicks -lt $sweepPlan.UntilTicks) -and ([int]$sweepPlan.Count -ne 0)) { return $sweepPlan }
    }
    return $null
}

# 조작 주입 (명세 3.2.4) - 조작 창 [a, b) + 대기열(스윕 'ua-deleg' 가 다음 회전 1회를 세움)
function Test-UserActiveStub {
    # 행마다 호출 수를 셉니다 - 5만 회를 넘으면 '__VTIMEOUT__'. 게이트가 양보 없이 continue 하는 변이는 시계를 흘리지 않아(양보·대기 모의를 안 거침) 판독·스윕
    #   상한에 닿지 않고 러너를 멈춥니다(구현 리뷰 P3 - ② 의 Wait-UserYieldEnd 를 지운 사본이 WA-L3 에서 끝나지 않았음)
    $script:userActiveCalls++
    if ($script:userActiveCalls -gt $CALL_LIMIT) { throw '__VTIMEOUT__' }
    if ($script:activeQueue -gt 0) { $script:activeQueue--; return $true }
    return ($null -ne (Get-ActiveWindowNow))
}
function Invoke-YieldStub {
    # 양보 모의 - 창 안이면 창 끝까지, 밖이면 기본 길이만큼 시계를 흘리고 그만큼 양보 누적. 양보 시각·길이·실패 중 양보 수·받은 문맥·양보 끝 시각을 기록
    param($Game, [string]$Context)
    Add-GameSeen -Kind 'yield' -Game $Game
    $activeWindow = Get-ActiveWindowNow
    $yieldTicks = $(if ($null -ne $activeWindow) { $activeWindow.UntilTicks - (Get-VirtualTicks) } else { ConvertTo-Ticks $DEFAULT_YIELD_SECONDS })
    $yieldSeconds = $yieldTicks / 10000000.0
    $script:yieldCalls++
    $script:yieldContexts.Add([string]$Context)
    if ($script:screenCaptureFailing) { $script:yieldsWhileFailing++ }
    $script:currentReadRecord = $null
    $script:turnFailSeen = $false
    Add-RowEvent -Kind 'yield' -Length $yieldSeconds
    Step-VirtualClock $yieldSeconds
    $script:yieldEnds.Add((Get-VirtualElapsed))
    $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $yieldTicks / 10000.0
}

# 스윕 모의 (명세 3.2.5) - 진입 때 플래그 참이면 거짓(원문 run:7632) · 첫 판독 캡처 실패면 거짓(run:7642) · 계획이 없으면 거짓
function Set-SweepMeta {
    # 모의 스윕이 쓰는 클릭 메타 - 공통 단언 ③ 이 '모의 스윕이 쓴 값' 으로 봅니다
    param([bool]$Performed, [string]$SkipReason)
    $script:lastClickPerformed = $Performed
    $script:lastClickSkipReason = $SkipReason
    $script:skipWritten.Add($SkipReason)
}
function Invoke-SweepStub {
    param($Game)
    Add-GameSeen -Kind 'sweep' -Game $Game
    $script:sweepCalls++
    if ($script:sweepCalls -gt $CALL_LIMIT) { throw '__VTIMEOUT__' }
    $script:currentReadRecord = $null
    $script:turnFailSeen = $false
    $sweepEntryTime = Get-VirtualElapsed
    Add-RowEvent -Kind 'sweep'
    if ($script:useRealSweep) { return (Invoke-RealPurchasePopupSweep -Game $Game) }
    if ($script:screenCaptureFailing) { return $false }
    $activePlan = Get-ActiveSweepPlan
    if (($null -ne $activePlan) -and ($activePlan.Kind -eq 'rect-throw')) {
        # 스윕 첫 판독(재시작 팝업 run:7589)이 창 사각형 실패를 등록하고 판독 경로 문구를 던지는 꼴 (WA-L43 (다))
        if ([int]$activePlan.Count -gt 0) { $activePlan.Count = [int]$activePlan.Count - 1 }
        $script:sweepFired.Add([pscustomobject]@{ T = $sweepEntryTime; Kind = 'rect-throw' })
        Register-MockFail -Cause $WINDOW_GONE_CAUSE
        throw $READ_PATH_MESSAGE
    }
    if (-not (Invoke-CaptureAttempt -Name 'sweep')) { return $false }
    if ($null -eq $activePlan) { return $false }
    if ($activePlan.Alternate) {
        # 교대 (명세 3.2.5) - 창이 행 첫 호출부터면 1번째 거짓 · 2번째 참 …, From 을 주면 창 안 첫 호출이 참(WA-L33 (바) - @0 창 밖 거짓 · @0.7 참)
        $activePlan.AlternateTurn = [int]$activePlan.AlternateTurn + 1
        $alternateTrueParity = $(if ($activePlan.AlternateFirstTrue) { 1 } else { 0 })
        if (($activePlan.AlternateTurn % 2) -ne $alternateTrueParity) { return $false }
    }
    if ([int]$activePlan.Count -gt 0) { $activePlan.Count = [int]$activePlan.Count - 1 }
    $script:sweepFired.Add([pscustomobject]@{ T = $sweepEntryTime; Kind = [string]$activePlan.Kind })
    $gapSeconds = [double]$activePlan.Gap
    switch ([string]$activePlan.Kind) {
        'sent' { Step-VirtualClock $gapSeconds; Set-SweepMeta -Performed $true -SkipReason ''; return $true }
        'cursor' { Step-VirtualClock $gapSeconds; Set-SweepMeta -Performed $false -SkipReason 'cursor-not-ready'; return $true }
        'ua-wait' {
            # 원문 구매 팝업·주간 리셋 닫기(run:7659~7662 · 6847~6849) - 조작 생략 뒤 스윕 안에서 기다리고 참 (Gap 을 먼저 흘림 - 명세 3.2.5)
            Step-VirtualClock $gapSeconds
            Set-SweepMeta -Performed $false -SkipReason 'user-active'
            Wait-UserYieldEnd -Game $Game -Context $SWEEP_YIELD_CONTEXT
            return $true
        }
        'ua-deleg' {
            # 보상 '확인'·협동 완료·협동 창·네트워크(run:7611~7617 등) - 기다리지 않고 참, 다음 회전 게이트가 조작을 봄
            Step-VirtualClock $gapSeconds
            Set-SweepMeta -Performed $false -SkipReason 'user-active'
            $script:activeQueue = 1
            return $true
        }
        'recover' { Register-MockFail -Cause $OTHER_CAUSE; Step-VirtualClock $gapSeconds; Register-MockSuccess; Set-SweepMeta -Performed $false -SkipReason 'cursor-not-ready'; return $true }
        'fail-false' { Register-MockFail -Cause $OTHER_CAUSE; Step-VirtualClock $gapSeconds; return $false }
        'fail-true' { Register-MockFail -Cause $OTHER_CAUSE; Step-VirtualClock $gapSeconds; Set-SweepMeta -Performed $false -SkipReason 'cursor-not-ready'; return $true }
        'yield-false' {
            # 스윕 안 커서 대피 양보(run:7647 → 3322~3334 - 메타 없이 누적만) 뒤 팝업 없음
            Step-VirtualClock $gapSeconds
            $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $gapSeconds * 1000
            return $false
        }
        'yield-sent' {
            # 같은 꼴의 커서 대피 양보 뒤 팝업 닫기 전송(run:7652 꼴 - 분류 'counted')
            Step-VirtualClock $gapSeconds
            $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $gapSeconds * 1000
            Set-SweepMeta -Performed $true -SkipReason ''
            return $true
        }
        'yield-rect-throw' {
            # 커서 대피 양보 뒤 같은 스윕의 하단 판독(run:7673 → 3869~3870)이 창 사각형 실패를 등록하고 판독 경로 문구를 던짐 - 메타 쓰기 0
            Step-VirtualClock $gapSeconds
            $script:userYieldTotalMs = [double]$script:userYieldTotalMs + $gapSeconds * 1000
            Register-MockFail -Cause $WINDOW_GONE_CAUSE
            throw $READ_PATH_MESSAGE
        }
        'rect-click-throw' {
            # ④′ 전 주간 리셋 경로의 꼴(스위치 없는 두 번째 판독이 gameWindowGone 을 등록만 하고 예비 좌표 클릭이 클릭 경로 문구를 던짐) - ④′ 뒤 원문 경로는 없고 방어선 모의(게이트가 클릭 전에 끊음) - 메타 쓰기 0
            Register-MockFail -Cause $WINDOW_GONE_CAUSE
            if ([string]$activePlan.Message) { throw ([string]$activePlan.Message) }
            throw $CLICK_PATH_MESSAGE
        }
        'click-throw-noreg' {
            # 앞 스위치 판독이 성공한 뒤의 예비 좌표 클릭(run:7450 → 7451 꼴) - 등록 없이 클릭 경로 문구 throw (플래그 거짓) - 메타 쓰기 0
            throw $CLICK_PATH_MESSAGE
        }
        'gate-true' {
            # 주간 리셋 두 번째 판독의 캡처 실패 게이트(구현 단위 ④′ - 실패 등록 · 클릭 0 · 참) - gameWindowGone 등록 · 메타 쓰기 0 (구현 명세 ⑤b3 2.2 · 범위 ⑤-50 (라))
            Register-MockFail -Cause $WINDOW_GONE_CAUSE
            return $true
        }
    }
    throw "모의 스윕 종류 오류: $($activePlan.Kind)"
}

# 판독 스텁 (명세 3.2.6 - 화면 함수 층에서 시각표의 지금 화면으로 답함)
function Invoke-PromptStub {
    # 하단 - 판독 회전 기록 @{ T; S; Fail } 하나 (그 회전 스윕 호출부터 다음 대기 사건 사이에 실패 등록이 있으면 Fail 참) · 실패면 스태시 '' · 거짓 ·
    # rect throw 는 스태시 갱신 앞 (원문 run:5762 → 5767)
    param($Game)
    Add-GameSeen -Kind 'prompt' -Game $Game
    $screenKey = Get-ScreenNow
    $readRecord = [pscustomobject]@{ T = (Get-VirtualElapsed); S = $screenKey; Fail = [bool]$script:turnFailSeen }
    $script:readRecords.Add($readRecord)
    $script:currentReadRecord = $readRecord
    if (-not (Invoke-CaptureAttempt -Name 'prompt')) { $script:lastClearPromptText = ''; return $false }
    $script:lastClearPromptText = ([string]$SCREEN_TABLE[$screenKey].Bottom) -replace '\s', ''
    return [bool]$SCREEN_TABLE[$screenKey].Prompt
}
function Invoke-PanelStub {
    param($Game)
    Add-GameSeen -Kind 'panel' -Game $Game
    if (-not (Invoke-CaptureAttempt -Name 'panel')) { return 'none' }
    return [string]$SCREEN_TABLE[(Get-ScreenNow)].Panel
}
function Invoke-FlagStub {
    param($Game, [string]$Name, [string]$Field)
    Add-GameSeen -Kind $Name -Game $Game
    if (-not (Invoke-CaptureAttempt -Name $Name)) { return $false }
    return [bool]$SCREEN_TABLE[(Get-ScreenNow)][$Field]
}
function Invoke-ProbeStub {
    # 탐침 - 캡처 한 번 · 결과를 사건 기록에 (원문 Test-CaptureRecovered 는 성공이면 플래그의 부정)
    param($Game)
    Add-GameSeen -Kind 'probe' -Game $Game
    $script:probeCalls++
    $script:currentReadRecord = $null
    $script:turnFailSeen = $false
    $probeOk = [bool](Invoke-CaptureAttempt -Name 'probe')
    Add-RowEvent -Kind 'probe' -Ok $probeOk
    return ($probeOk -and (-not $script:screenCaptureFailing))
}

function Reset-ReentryRow {
    # 행 시작 상태 (명세 3.2.9) - 캡처·양보 상태와 앞 행이 세운 값을 비운 뒤 클릭 메타는 묵은 값으로 시작합니다(서두 비움을 행동으로 보려고 - 공통 단언 ③)
    $script:caseStart = [datetime]'2026-10-18 09:00:00'
    $script:vclock = $script:caseStart
    $script:screenCaptureFailing = $false
    $script:captureFailSerial = 0
    $script:captureFailCause = $null
    $script:captureFailingSince = $null
    $script:captureFailTotalMs = [double]0
    $script:captureFailMessage = $null
    $script:gameWindowMissingSince = $null
    $script:lastGoodStationName = $null
    $script:userYieldTotalMs = [double]0
    $script:gameProcess = $null                # 원문 안전 확인이 읽는 워커 전역 - WA-L30 (나) 의 모의가 뒤 행으로 새지 않게
    $script:useRealSweep = $false
    $script:restartPopupMock = $false
    $script:safeStopFlagMock = $false
    $script:safeStopRemoves = 0
    $script:sweepPlans = New-Object System.Collections.Generic.List[object]   # 교대 셈은 계획마다(AlternateTurn) - 계획을 새로 만들어 함께 비움
    $script:failWindows = New-Object System.Collections.Generic.List[object]
    $script:failPeriodic = $null
    $script:alternateMode = ''
    $script:alternateFrom = 0
    $script:failHook = $null
    $script:activeWindows = New-Object System.Collections.Generic.List[object]
    $script:activeQueue = 0
    $script:screenPlan = @(@{ AtTicks = 0; S = 'U'; Seq = 0 })
    $script:gameMarker = $null
    $script:rowLogs = New-Object System.Collections.Generic.List[string]
    $script:rowEvents = New-Object System.Collections.Generic.List[object]
    $script:readRecords = New-Object System.Collections.Generic.List[object]
    $script:currentReadRecord = $null
    $script:turnFailSeen = $false
    $script:failStarts = New-Object System.Collections.Generic.List[double]
    $script:failEnds = New-Object System.Collections.Generic.List[double]
    $script:yieldEnds = New-Object System.Collections.Generic.List[double]
    $script:yieldContexts = New-Object System.Collections.Generic.List[string]
    $script:skipWritten = New-Object System.Collections.Generic.List[string]
    $script:sweepFired = New-Object System.Collections.Generic.List[object]
    $script:sweepActions = New-Object System.Collections.Generic.List[string]
    $script:gameSeen = New-Object System.Collections.Generic.List[string]
    $script:captureAttempts = 0
    $script:sweepCalls = 0
    $script:userActiveCalls = 0
    $script:probeCalls = 0
    $script:safeStopCalls = 0
    $script:yieldCalls = 0
    $script:yieldsWhileFailing = 0
    $script:recordMockCalls = @{}
    $script:lastClickSkipReason = 'user-active'
    $script:lastClickPerformed = $false
    $script:lastClearPromptText = 'STALE'
}

function New-RemainingClock {
    # 남은 시간을 정한 흐르는 파티원 시계 (-Clock 행 - '남은 0' = Set-AbyssMemberClock -Milliseconds 0, 명세 3.4 WA-L25). 행 시작 상태 뒤에 만듭니다
    param([double]$Seconds)
    $remainingClock = New-AbyssMemberClock -LimitSeconds 300
    Set-AbyssMemberClock -Clock $remainingClock -Milliseconds ($Seconds * 1000)
    return $remainingClock
}

function Invoke-ReentryRow {
    # 행 실행기 (명세 3.2.7) - 결과·예외·기록을 묶어 돌려줍니다. 반환 수는 $null 이면 0 (@($null).Count 는 1), 기록 List 는 .ToArray()
    param([hashtable]$Arguments)
    $rowOutput = $null
    $rowError = ''
    try {
        $rowOutput = @(Wait-AbyssReentry @Arguments)
    } catch {
        $rowError = [string]$_.Exception.Message
    }
    $rowCount = $(if ($null -eq $rowOutput) { 0 } else { $rowOutput.Count })
    $firstOutput = $(if ($rowCount -eq 1) { $rowOutput[0] } else { $null })
    $rowKeys = ''
    $rowResult = ''
    $rowLastKind = ''
    $rowPanelSeen = $null
    if ($firstOutput -is [hashtable]) {
        $rowKeys = (@($firstOutput.Keys | ForEach-Object { [string]$_ } | Sort-Object) -join ',')
        $rowResult = [string]$firstOutput['Result']
        $rowLastKind = [string]$firstOutput['LastKind']
        $rowPanelSeen = $firstOutput['PanelSeen']
    }
    $logLines = $script:rowLogs.ToArray()
    return [pscustomobject]@{
        Result = $rowResult; LastKind = $rowLastKind; PanelSeen = $rowPanelSeen; Keys = $rowKeys; Count = $rowCount; Error = $rowError
        T = (Get-VirtualElapsed); Logs = $logLines
        S2 = @($logLines | Where-Object { $_.StartsWith($S2_LINE_PREFIX) })
        NoticeCount = @($logLines | Where-Object { $_.StartsWith($NOTICE_LINE_PREFIX) }).Count
        Events = $script:rowEvents.ToArray(); Reads = $script:readRecords.ToArray()
        FailStarts = $script:failStarts.ToArray(); FailEnds = $script:failEnds.ToArray(); YieldEnds = $script:yieldEnds.ToArray()
        YieldContexts = $script:yieldContexts.ToArray(); YieldTotalMs = [double]$script:userYieldTotalMs; FailTotalMs = [double](Get-CaptureFailTotalMs)
        SafeStops = $script:safeStopCalls; Probes = $script:probeCalls; Yields = $script:yieldCalls; YieldsWhileFailing = $script:yieldsWhileFailing
        SweepCalls = $script:sweepCalls; SweepFired = $script:sweepFired.ToArray(); SweepActions = $script:sweepActions.ToArray()
        RecordCalls = $script:recordMockCalls.Clone(); SkipEnd = [string]$script:lastClickSkipReason; SkipWritten = $script:skipWritten.ToArray()
        Flag = [bool]$script:screenCaptureFailing; Cause = [string]$script:captureFailCause; Serial = [int]$script:captureFailSerial
        GameSeen = $script:gameSeen.ToArray()
    }
}

# ── 기대값 계산 도움 (명세 3.2.8 - 숫자를 다시 박지 않고 기록에서) ──
function Format-Seconds { param($Value) if ($null -eq $Value) { return 'null' }; return ([Math]::Round([double]$Value, 2)).ToString([Globalization.CultureInfo]::InvariantCulture) }
function Get-RecordTimes {
    # 판독 회전 기록의 시각 목록 (열거용 - 호출부에서 @()) - Screen 그 약어만 · Clean 실패 없는 회전만 · Failed 실패 있는 회전만 · NotBefore ≥ · After > · Before <
    param($Row, [string]$Screen = '', [switch]$Clean, [switch]$Failed, $NotBefore = $null, $After = $null, $Before = $null)
    $recordTimes = @()
    foreach ($readRecord in @($Row.Reads)) {
        if ($Screen -and ($readRecord.S -cne $Screen)) { continue }
        if ($Clean -and $readRecord.Fail) { continue }
        if ($Failed -and (-not $readRecord.Fail)) { continue }
        if (($null -ne $NotBefore) -and ([double]$readRecord.T -lt ([double]$NotBefore - $TIME_EPSILON))) { continue }
        if (($null -ne $After) -and ([double]$readRecord.T -le ([double]$After + $TIME_EPSILON))) { continue }
        if (($null -ne $Before) -and ([double]$readRecord.T -ge ([double]$Before - $TIME_EPSILON))) { continue }
        $recordTimes += [double]$readRecord.T
    }
    return $recordTimes
}
function Get-NthTime {
    # 시각 목록의 n번째 (없으면 NaN - 어떤 비교도 거짓)
    param([object[]]$Times, [int]$N)
    $timeList = @($Times)
    if (($N -ge 1) -and ($timeList.Count -ge $N)) { return [double]$timeList[$N - 1] }
    return [double]::NaN
}
function Test-SameTime { param([double]$Left, [double]$Right) return ([Math]::Abs($Left - $Right) -lt $TIME_EPSILON) }
function Get-LastSleepSeconds {
    # 회전 박자 - 결론 회전 직전의 대기 사건 길이(사건 기록의 마지막 Start-Sleep 길이 - 0.7·2 를 다시 박지 않음)
    param($Row)
    $sleepEvents = @($Row.Events | Where-Object { $_.Kind -eq 'sleep' })
    if ($sleepEvents.Count -eq 0) { return [double]::NaN }
    return ([double]$sleepEvents[$sleepEvents.Count - 1].Ms / 1000.0)
}
function Test-DeadlineWindow {
    # D ≤ T < D + 회전 박자 (명세 3.2.8 '마감 시각')
    param($Row, [double]$Deadline)
    $beatSeconds = Get-LastSleepSeconds -Row $Row
    return (([double]$Row.T -ge ($Deadline - $TIME_EPSILON)) -and ([double]$Row.T -lt ($Deadline + $beatSeconds - $TIME_EPSILON)))
}
function Get-EventIndex {
    # 사건 기록에서 종류·시각이 맞는 첫 사건의 자리 (-1 = 없음)
    param($Row, [string]$Kind, $Time = $null, $Ok = $null)
    $eventList = @($Row.Events)
    for ($eventIndex = 0; $eventIndex -lt $eventList.Count; $eventIndex++) {
        $rowEvent = $eventList[$eventIndex]
        if ($rowEvent.Kind -ne $Kind) { continue }
        if (($null -ne $Time) -and (-not (Test-SameTime ([double]$rowEvent.T) ([double]$Time)))) { continue }
        if (($null -ne $Ok) -and ([bool]$rowEvent.Ok -ne [bool]$Ok)) { continue }
        return $eventIndex
    }
    return -1
}
function Get-EventKindAt {
    # 사건 기록의 그 자리 사건 종류 ('' = 범위 밖) - 대기 사건이면 'sleep:<ms>', 탐침이면 'probe:ok/fail'
    param($Row, [int]$Index)
    $eventList = @($Row.Events)
    if (($Index -lt 0) -or ($Index -ge $eventList.Count)) { return '' }
    $rowEvent = $eventList[$Index]
    if ($rowEvent.Kind -eq 'sleep') { return ('sleep:{0}' -f $rowEvent.Ms) }
    if ($rowEvent.Kind -eq 'probe') { return ('probe:{0}' -f $(if ($rowEvent.Ok) { 'ok' } else { 'fail' })) }
    return [string]$rowEvent.Kind
}
function Get-FirstProbeOkTime {
    param($Row)
    $probeIndex = Get-EventIndex -Row $Row -Kind 'probe' -Ok $true
    if ($probeIndex -lt 0) { return [double]::NaN }
    return [double]@($Row.Events)[$probeIndex].T
}
function Get-IndependentFailSum {
    # 실패 합의 독립 계산 (명세 3.2.8) - 실패 구간 기록(실패 시작 등록 → 실패 끝)의 합. NotBefore 를 주면 그 시각 이후에 시작한 구간만
    param($Row, $NotBefore = $null)
    $failSum = 0.0
    $pairCount = [Math]::Min(@($Row.FailStarts).Count, @($Row.FailEnds).Count)
    for ($pairIndex = 0; $pairIndex -lt $pairCount; $pairIndex++) {
        if (($null -ne $NotBefore) -and ([double]$Row.FailStarts[$pairIndex] -lt ([double]$NotBefore - $TIME_EPSILON))) { continue }
        $failSum += [double]$Row.FailEnds[$pairIndex] - [double]$Row.FailStarts[$pairIndex]
    }
    return $failSum
}
function Get-S2Facts {
    # 재입장 계측 줄(S2) - 줄 수 · 정규식 일치 · 이름 묶음 값 (u 로딩 · f 필드 모양 · part 첫 필드 모양 토막 · s 그 초 · b 관측 끊김)
    param($Row)
    $s2Lines = @($Row.S2)
    $s2Facts = [pscustomobject]@{ Count = $s2Lines.Count; Matched = $false; U = -1; F = -1; HasPart = $false; S = [double]::NaN; B = -1; Text = '' }
    if ($s2Lines.Count -ge 1) {
        $s2Facts.Text = [string]$s2Lines[0]
        $s2Match = [regex]::Match([string]$s2Lines[0], $S2_PATTERN)
        if ($s2Match.Success) {
            $s2Facts.Matched = $true
            $s2Facts.U = [int]$s2Match.Groups['u'].Value
            $s2Facts.F = [int]$s2Match.Groups['f'].Value
            $s2Facts.B = [int]$s2Match.Groups['b'].Value
            $s2Facts.HasPart = $s2Match.Groups['part'].Success
            if ($s2Match.Groups['s'].Success) { $s2Facts.S = [double]::Parse($s2Match.Groups['s'].Value, [Globalization.CultureInfo]::InvariantCulture) }
        }
    }
    return $s2Facts
}
# 구현 단위 5b-8 - 재입장 대기의 새 로그 두 줄(재매칭 패널 확인 안내 · 필드 확정 줄) · 2.2-4a 두 판독 호출 수 (§7 FC-L 행 · §8 정적이 씀)
$PANEL_NOTICE_TEXT = '[어비스] 재매칭 패널 확인 - 매칭이 끝나면 입장합니다'   # 명세 5b-8 1.6 ① 문구 (권장 인원 안내 $NOTICE_FULL_TEXT 와 같은 고정 사본 - 정적 N4-P14 · FC-S12)
$SETTLE_LINE_PREFIX = '[어비스] 던전 밖(HUD) 확인'                            # 필드 확정 줄(명세 1.6 ② - 선분기 확정 줄과 같은 꼴)을 고르는 접두
$SETTLE_PATTERN = '^\[어비스\] 던전 밖\(HUD\) 확인 - 필드 모양이 (?<w>[0-9.]+)초 이어졌습니다 \(첫 표본부터 (?<s>-?[0-9.]+)초, (?<n>\d+)표본\)$'
function Get-SettleFacts {
    # 필드 확정 줄 - 줄 수 · 정규식 일치 · w(W) · s(첫 표본부터 초) · n(표본 수) (Get-S2Facts 와 같은 꼴)
    param($Row)
    $settleLines = @($Row.Logs | Where-Object { $_.StartsWith($SETTLE_LINE_PREFIX, [StringComparison]::Ordinal) })
    $settleFacts = [pscustomobject]@{ Count = $settleLines.Count; Matched = $false; W = [double]::NaN; S = [double]::NaN; N = -1; Text = '' }
    if ($settleLines.Count -ge 1) {
        $settleFacts.Text = [string]$settleLines[0]
        $settleMatch = [regex]::Match($settleFacts.Text, $SETTLE_PATTERN)
        if ($settleMatch.Success) {
            $settleFacts.Matched = $true
            $settleFacts.W = [double]::Parse($settleMatch.Groups['w'].Value, [Globalization.CultureInfo]::InvariantCulture)
            $settleFacts.S = [double]::Parse($settleMatch.Groups['s'].Value, [Globalization.CultureInfo]::InvariantCulture)
            $settleFacts.N = [int]$settleMatch.Groups['n'].Value
        }
    }
    return $settleFacts
}
function Get-PanelNoticeCount { param($Row) return @($Row.Logs | Where-Object { $_ -ceq $PANEL_NOTICE_TEXT }).Count }
function Get-SettleExpectedT {
    # 확정 기대 시각 - 끊김 뒤 첫 실패 없는 F 판독(Start)부터 W(소스 캡처) 이상 지난 첫 실패 없는 F 판독 (W 정각 포함 - 원문 Step-AbyssFieldSettle 의 '-lt' 부정)
    param($Row, [double]$Start)
    return (Get-NthTime @(Get-RecordTimes $Row -Screen 'F' -Clean -NotBefore ($Start + [double]$memberFieldSettleSeconds)) 1)
}
function Test-SettleLine {
    # 필드 확정 줄 1 · 정규식 일치 · w = W · s = 확정 시각 − Start(한 자리) · n = Start ~ 확정(포함)의 실패 없는 F 판독 수
    param($Row, [double]$Start)
    $settleFacts = Get-SettleFacts $Row
    $expectSpan = [Math]::Round([double]$Row.T - $Start, 1)
    $expectCount = @(Get-RecordTimes $Row -Screen 'F' -Clean -NotBefore $Start | Where-Object { $_ -le ([double]$Row.T + $TIME_EPSILON) }).Count
    return (($settleFacts.Count -eq 1) -and $settleFacts.Matched -and ([Math]::Abs($settleFacts.W - [double]$memberFieldSettleSeconds) -lt $TIME_EPSILON) -and
        ([Math]::Abs($settleFacts.S - $expectSpan) -lt 0.01) -and ($settleFacts.N -eq $expectCount))
}
function Get-OverlayReadCount {
    # 2.2-4a 의 두 판독(선택 화면 'selection' · ESC 메뉴 'menu') 호출 수 - 판독 스텁이 남긴 -Game 기록(N4-L5)에서 셈
    param($Row, [string]$Name)
    return @($Row.GameSeen | Where-Object { ($_ -split ':')[0] -ceq $Name }).Count
}
function Format-RowDetail {
    # 실패 줄의 실제 값 - 결과·시각·판독 회전·사건·S2·호출 수 (판독·사건은 앞 40개)
    param($Row)
    $readText = (@($Row.Reads | Select-Object -First 40 | ForEach-Object { '{0}{1}{2}' -f (Format-Seconds $_.T), $_.S, $(if ($_.Fail) { '!' } else { '' }) }) -join ' ')
    $eventText = (@($Row.Events | Select-Object -First 40 | ForEach-Object {
                $eventSuffix = $(if ($_.Kind -eq 'sleep') { [string]$_.Ms } elseif ($_.Kind -eq 'probe') { $(if ($_.Ok) { 'ok' } else { 'fail' }) } elseif ($_.Kind -eq 'yield') { Format-Seconds $_.Length } else { '' })
                '{0} {1}{2}' -f (Format-Seconds $_.T), $_.Kind, $(if ($eventSuffix) { ' ' + $eventSuffix } else { '' }) }) -join ' | ')
    return ('결과={0}|{1}|{2} 수={3} 키=[{4}] 오류=[{5}] T={6} 판독=[{7}] 사건=[{8}] S2=[{9}] 양보={10}({11}ms) 실패합={12}ms 안전={13} 탐침={14} 스윕={15} 분류=[{16}]' -f
        $Row.Result, $Row.LastKind, $Row.PanelSeen, $Row.Count, $Row.Keys, $Row.Error, (Format-Seconds $Row.T), $readText, $eventText, (@($Row.S2) -join ' / '),
        $Row.Yields, [Math]::Round($Row.YieldTotalMs), [Math]::Round($Row.FailTotalMs), $Row.SafeStops, $Row.Probes, $Row.SweepCalls, (@($Row.SweepActions) -join ','))
}
function Check-RowCommon {
    # 공통 단언 (명세 3.2.9 - 모든 WA-L·N4-L 행): ① 기록 모의 호출 0 ② 반환 키 정확히 셋(반환한 행 - 반환은 정확히 하나) ③ 행 끝 클릭 메타 = '' 또는 그 행에서
    # 모의 스윕이 쓴 값 (묵은 'user-active' 로 시작 - 서두 비움의 행동 감시)
    param([string]$Name, $Row)
    $recordHits = @($RECORD_MOCK_NAMES | Where-Object { [int]$Row.RecordCalls[$_] -gt 0 } | ForEach-Object { '{0}={1}' -f $_, $Row.RecordCalls[$_] })
    $keysOk = ($Row.Count -eq 0) -or (($Row.Count -eq 1) -and ($Row.Keys -ceq 'LastKind,PanelSeen,Result'))
    $skipOk = ($Row.SkipEnd -ceq '') -or (@($Row.SkipWritten) -ccontains $Row.SkipEnd)
    Check-True "$Name 공통 단언 (기록 모의 호출 0 · 반환 키 정확히 셋 · 행 끝 클릭 메타 = '' 또는 모의 스윕이 쓴 값)" (($recordHits.Count -eq 0) -and $keysOk -and $skipOk) `
        ('기록 모의=[{0}] 반환 수={1} 키=[{2}] 메타 끝=[{3}] 모의 스윕이 쓴 메타=[{4}]' -f ($recordHits -join ','), $Row.Count, $Row.Keys, $Row.SkipEnd, (@($Row.SkipWritten) -join ','))
}

# 행 훅 (스크립트 범위 스크립트블록 - $script: 와 리터럴 시각만 읽음, 함수 안 GetNewClosure 금지 - 규칙 3)
$HOOK_PROMPT_FAIL_AT_0_7 = { param($Name) if (($Name -eq 'prompt') -and (Test-VirtualTimeIn 0.6 0.8)) { 'fail' } }                  # WA-L6 둘째 회전 하단만 실패
$HOOK_PROMPT_FAIL_AT_6_3 = { param($Name) if (($Name -eq 'prompt') -and (Test-VirtualTimeIn 6.2 6.4)) { 'fail' } }                  # WA-L32 @6.3 회전 하단 실패
$HOOK_PROMPT_FAIL_AT_3_0 = { param($Name) if (($Name -eq 'prompt') -and (Test-VirtualTimeIn 2.95 3.05)) { 'fail' } }                # N4-L18 양보 뒤 첫 회전(@3.0) 하단만 실패
$HOOK_HUD_RECT_AT_0_7 = { param($Name) if (($Name -eq 'hud') -and (Test-VirtualTimeIn 0.6 0.8)) { 'rect' } }                        # WA-L43 (가) 다음 회전 HUD throw
$HOOK_OTHER_THEN_HUD_RECT_AT_0_7 = { param($Name) if (Test-VirtualTimeIn 0.6 0.8) { if (($Name -eq 'prompt') -or ($Name -eq 'panel')) { 'fail' } elseif ($Name -eq 'hud') { 'rect' } } }   # WA-L43 (라)
$HOOK_PANEL_OTHER_ERROR_AT_0_7 = { param($Name) if (($Name -eq 'panel') -and (Test-VirtualTimeIn 0.6 0.8)) { 'throw:TEST-OTHER-ERROR' } }   # WA-L44 (가)
$HOOK_OTHER_THEN_PANEL_ERROR_AT_0_7 = { param($Name) if (Test-VirtualTimeIn 0.6 0.8) { if ($Name -eq 'prompt') { 'fail' } elseif ($Name -eq 'panel') { 'throw:TEST-OTHER-ERROR' } } }   # WA-L44 (나)
$OTHER_ERROR_TEXT = 'TEST-OTHER-ERROR'

# ── §3 끝: exit 센티널 단언 · 서명 대조 (행보다 먼저) ──
foreach ($sentinelCheck in $script:sentinelChecks) {
    Check-Equal "센티널($($sentinelCheck[0])): 원본 ExitStatementAst = 줄 단독 exit = 치환 수, 치환 뒤 ExitStatementAst 0" `
        ('{0}/{1}/{2}' -f $sentinelCheck[1], $sentinelCheck[2], $sentinelCheck[3]) ('{0}/{0}/0' -f $sentinelCheck[1])
}
Check-True '센티널: 안전 확인의 exit 는 셋(게임 종료 · 창 핸들 60초 · F9), 공용 스윕은 하나(재시작 안내)' `
    ((@($script:sentinelChecks | Where-Object { $_[0] -eq 'Test-SafeStopDuringCaptureFail' -and $_[1] -eq 3 }).Count -eq 1) -and (@($script:sentinelChecks | Where-Object { $_[0] -eq 'Invoke-PurchasePopupSweep' -and $_[1] -eq 1 }).Count -eq 1)) `
    ((@($script:sentinelChecks | ForEach-Object { '{0}={1}' -f $_[0], $_[1] })) -join ' · ')
function Get-ParamSignature {
    # 워커 원문 함수의 매개변수 서명 '타입 $이름, …' (test_abyss_handoff_start.ps1 과 같은 형식)
    param([string]$Name)
    if (-not $workerFunctions.ContainsKey($Name)) { return '(정의 없음)' }
    $signatureBlock = $workerFunctions[$Name].Body.ParamBlock
    if ($null -eq $signatureBlock) { return '(매개변수 없음)' }
    return (@($signatureBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}
function Get-LiveParamSignature {
    # 이 파일에 지금 정의된 함수(모의·감시)의 매개변수 서명 - 같은 형식
    param([string]$Name)
    $liveCommand = Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue
    if ($null -eq $liveCommand) { return '(정의 없음)' }
    $liveAst = $liveCommand.ScriptBlock.Ast
    $liveBlock = $(if ($liveAst -is [FunctionDefinitionAst]) { $liveAst.Body.ParamBlock } else { $liveAst.ParamBlock })
    if ($null -eq $liveBlock) { return '(매개변수 없음)' }
    return (@($liveBlock.Parameters | ForEach-Object { '{0} ${1}' -f $_.StaticType.Name, $_.Name.VariablePath.UserPath }) -join ', ')
}
$signatureNames = @(@($STUB_MOCK_BODIES.Keys) + @($PRE_ASSERT_MOCK_BODIES.Keys) + $RECORD_MOCK_NAMES + $UNREACHABLE_NAMES + @('Test-SafeStopDuringCaptureFail', 'Resolve-AbyssMemberSweepTurn'))
$signatureMismatches = @($signatureNames | Where-Object { (Get-LiveParamSignature $_) -cne (Get-ParamSignature $_) } | ForEach-Object { '{0}: 원문 [{1}] / 모의 [{2}]' -f $_, (Get-ParamSignature $_), (Get-LiveParamSignature $_) })
Check-True "서명 대조: 모의·감시 $($signatureNames.Count)개의 매개변수 서명 = 워커 원문" ($signatureMismatches.Count -eq 0) ($signatureMismatches -join ' · ')

# ── §5 선단언 (명세 3.2.6 ①~④ · N4-P7 - 하나라도 어긋나면 FAIL) ─────────────────────────────────────────────────────────
# ① 열한 약어 각각 원문 분류기가 대응표의 분류를 냄 (Mn · Sl 은 선택 화면 · 메뉴 판정값을 함께 넘김 - 구현 단위 5b-8)
$classifyActual = @(foreach ($screenKey in $SCREEN_TABLE.Keys) {
        $screenEntry = $SCREEN_TABLE[$screenKey]
        '{0}={1}' -f $screenKey, (Resolve-AbyssHandoffStartScreen -PromptVisible $screenEntry.Prompt -BottomText $screenEntry.Bottom -PanelKind $screenEntry.Panel -HudVisible $screenEntry.Hud -InDungeonQuest $screenEntry.Quest `
            -SelectionVisible ([bool]$screenEntry.Selection) -MenuVisible ([bool]$screenEntry.Menu))
    }) -join ' '
$classifyExpected = @(foreach ($screenKey in $SCREEN_KINDS.Keys) { '{0}={1}' -f $screenKey, $SCREEN_KINDS[$screenKey] }) -join ' '
Check-Equal '선단언 ① 열한 약어의 원문 분류 (Resolve-AbyssHandoffStartScreen - 판정값·실측 하단 판독문)' $classifyActual $classifyExpected
# ② 패널 - 원문 패널 종류 판정(서명 둘을 지남)이 실측 패널 판독문에 M 'matching' · Rd 'ready'
$panelRegionKey = '{0},{1}' -f $rgAbyssMenu[0], $rgAbyssMenu[1]
$script:preRegionTexts = @{ $panelRegionKey = $PANEL_TEXT_MATCHING }
$panelMatchingActual = Invoke-RealGetAbyssPanelKind -Game $null
$script:preRegionTexts = @{ $panelRegionKey = $PANEL_TEXT_READY }
$panelReadyActual = Invoke-RealGetAbyssPanelKind -Game $null
Check-Equal '선단언 ② 패널 - 원문 Get-AbyssPanelKind: 09-18 재매칭 판독문 → M 의 판정값 · 실기 -1 L1 준비 패널 판독문 → Rd 의 판정값' "M=$panelMatchingActual Rd=$panelReadyActual" ('M={0} Rd={1}' -f $SCREEN_TABLE['M'].Panel, $SCREEN_TABLE['Rd'].Panel)
# ③ 프롬프트 - 원문 하단 판정이 열한 하단 판독문 중 S 만 참 (점수 영역 판독은 '')
$promptActual = @(foreach ($screenKey in $SCREEN_TABLE.Keys) {
        $script:preBottomText = [string]$SCREEN_TABLE[$screenKey].Bottom
        $script:preRegionTexts = @{}
        '{0}={1}' -f $screenKey, [int][bool](Invoke-RealTestDungeonClearPrompt -Game $null)
    }) -join ' '
$promptExpected = @(foreach ($screenKey in $SCREEN_TABLE.Keys) { '{0}={1}' -f $screenKey, [int][bool]$SCREEN_TABLE[$screenKey].Prompt }) -join ' '
Check-Equal '선단언 ③ 프롬프트 - 원문 Test-DungeonClearPrompt: 열한 하단 판독문 중 S 만 참 (대응표 판정값과 같음)' $promptActual $promptExpected
# ④ 추적기 둘 - 원문 추적기 판정(내장 던전 키워드)이 던전 안 판독문 참 · 필드 판독문 거짓
$trackerRegionKey = '{0},{1}' -f $rgQuestTracker[0], $rgQuestTracker[1]
$script:preRegionTexts = @{ $trackerRegionKey = $TRACKER_INSIDE_TEXT }
$trackerInsideActual = [int][bool](Invoke-RealTestInDungeonQuest -Game $null)
$script:preRegionTexts = @{ $trackerRegionKey = $TRACKER_FIELD_TEXT }
$trackerFieldActual = [int][bool](Invoke-RealTestInDungeonQuest -Game $null)
Check-Equal '선단언 ④ 추적기 - 원문 Test-InDungeonQuest: cap_211244_025 판독문 → I 의 판정값 · cap_210525_840 판독문 → F 의 판정값' "I=$trackerInsideActual F=$trackerFieldActual" ('I={0} F={1}' -f [int]$SCREEN_TABLE['I'].Quest, [int]$SCREEN_TABLE['F'].Quest)
# 선단언 전용 판독 둘은 이제 '닿으면 안 됨' 꼴로 다시 정의합니다 (행에서는 판독 스텁 층이 먼저 받아 닿지 않음 - 명세 3.2.1)
foreach ($preName in @($PRE_ASSERT_MOCK_BODIES.Keys)) { Invoke-Expression (New-MockDefinition -Name $preName -Body ("throw 'TEST-UNREACHABLE: {0}'" -f $preName)) }

# N4-P7 - 캡처 모의의 전제(원문 규칙 사본, 명세 3.2.3): 원문이 바뀌면 FAIL → 위 Register-MockFail·Invoke-CaptureAttempt 를 같이 고칩니다
$failureNode = Get-WorkerFunction 'Register-CaptureFailure'
$serialIncrements = @($failureNode.FindAll({ param($candidate) ($candidate -is [UnaryExpressionAst]) -and ($candidate.TokenKind -eq [TokenKind]::PostfixPlusPlus) -and (Test-IsVariable $candidate.Child 'script:captureFailSerial') }, $true)).Count
$failureIfCodes = @($failureNode.FindAll({ param($candidate) $candidate -is [IfStatementAst] }, $true) | ForEach-Object { Get-NodeCode $_ })
$startTimeRule = @($failureIfCodes | Where-Object { $_ -ceq 'if (-not $script:screenCaptureFailing) { $script:captureFailingSince = Get-Date }' }).Count
$updateRule = @($failureIfCodes | Where-Object { $_ -ceq 'if (-not $script:screenCaptureFailing -or $failInfo.Message -ne $script:captureFailMessage) { $script:screenCaptureFailing = $true $script:captureFailMessage = $failInfo.Message $script:captureFailCause = $failInfo.Cause Write-RunLog $failInfo.Message }' }).Count
$successIfCodes = @((Get-WorkerFunction 'Register-CaptureSuccess').FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-IsVariable $candidate.Clauses[0].Item1 'script:screenCaptureFailing') }, $true) | ForEach-Object { Get-NodeCode $_ })
$successRule = @($successIfCodes | Where-Object { $_ -ceq 'if ($script:screenCaptureFailing) { if ($script:captureFailingSince) { $script:captureFailTotalMs = [double]$script:captureFailTotalMs + ((Get-Date) - $script:captureFailingSince).TotalMilliseconds } $script:screenCaptureFailing = $false Write-RunLog (Get-CaptureRecoveryMessage -FailCause $script:captureFailCause) $script:captureFailMessage = $null $script:captureFailCause = $null $script:captureFailingSince = $null $justRecovered = $true }' }).Count
$totalMsRule = @((Get-WorkerFunction 'Get-CaptureFailTotalMs').Body.EndBlock.Statements | ForEach-Object { Get-NodeCode $_ }) -join ' ; '
$rectCaptureIfs = @($captureNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and
            (@($candidate.Clauses[0].Item1.FindAll({ param($member) ($member -is [InvokeMemberExpressionAst]) -and ($member.Member.Extent.Text -eq 'GetWindowRect') }, $true)).Count -gt 0) }, $true))
$rectCaptureStatements = $(if ($rectCaptureIfs.Count -eq 1) { (@($rectCaptureIfs[0].Clauses[0].Item2.Statements | ForEach-Object { Get-NodeCode $_ })) -join ' ; ' } else { "갈래 $($rectCaptureIfs.Count)개" })
$rectCaptureExpected = "Register-CaptureFailure -GameWindowIssue 'rect-failed' ; if (`$ThrowOnWindowRectFailure) { throw '$READ_PATH_MESSAGE' } ; return `$null"
$n4p7Actual = '일련번호 +1={0} · 시작 시각 규칙={1} · 갱신 규칙={2} · 성공 누적·비움={3} · 누적 식=[{4}] · rect-failed → {5} · 끝 return → {6} · 창 사각형 실패 갈래=[{7}]' -f
$serialIncrements, $startTimeRule, $updateRule, $successRule, $totalMsRule, $WINDOW_GONE_CAUSE, $OTHER_CAUSE, $rectCaptureStatements
$n4p7Expected = '일련번호 +1=1 · 시작 시각 규칙=1 · 갱신 규칙=1 · 성공 누적·비움=1 · 누적 식=[{0}] · rect-failed → gameWindowGone · 끝 return → other · 창 사각형 실패 갈래=[{1}]' -f
'$total = [double]$script:captureFailTotalMs ; if ($script:screenCaptureFailing -and $script:captureFailingSince) { $total += ((Get-Date) - $script:captureFailingSince).TotalMilliseconds } ; return $total', $rectCaptureExpected
Check-Equal 'N4-P7 캡처 모의의 전제 - 원문 규칙 사본 (run:3700 일련번호 · 3713~3722 시작 시각·갱신 · 3736~3745 누적·비움 · 3762~3769 누적 식 · 3571~3576 rect-failed 원인 · 3601~3604 other · 3869~3870 등록 → throw)' $n4p7Actual $n4p7Expected

# ── §6 WA-P · N4-L4 · FC-P - 결론 우선순위 순수 진리표 (명세 3.3 · 5b-8 3.1 필드 결과 열 - 비교는 -ceq) ─────────────────────────────────────────────────────
# 열: 이름 · 분류 · 던전 안 연속 · 패널 관측 · 목표 · 보고 · 무변화 만료 · 필드 확정 · 필드 결과(구현 단위 5b-8) · 기대. 판정 함수가 단순 함수라 모르는 매개변수를 $args 로
#   삼키므로 열 수를 표 모양 단언으로 고정합니다(9열 행이 남으면 [bool] 묶기 예외로도 드러남)
$VERDICT_ROWS = @(
    @('WA-P1', 'inside', 2, $false, 'entry', $false, $false, $false, $false, 'entered'),
    @('WA-P2', 'inside', 1, $false, 'entry', $true, $true, $false, $false, ''),
    @('WA-P3', 'reward3', 0, $true, 'entry', $true, $false, $false, $false, 'cancelled'),
    @('WA-P4', 'reward3', 0, $false, 'entry', $true, $true, $false, $false, 'reclick'),
    @('WA-P5', 'reward3', 0, $false, 'entry', $true, $false, $false, $false, ''),
    @('WA-P6', 'reward3', 0, $true, 'entry', $false, $true, $false, $false, ''),
    @('WA-P7', 'reward3', 0, $true, 'entry', $true, $true, $false, $false, 'cancelled'),
    @('WA-P8', 'unknown', 0, $false, 'entry', $true, $true, $false, $false, ''),
    @('WA-P9', 'matching', 0, $true, 'entry', $true, $true, $false, $false, ''),
    @('WA-P10', 'field', 0, $false, 'entry', $true, $true, $true, $false, ''),                      # 필드 결과 끔 - 새 행과 스위치 하나만 다름(FC-P3 이 짝)
    @('WA-P11', 'reward3', 0, $false, 'reward', $false, $false, $false, $false, 'reward'),
    @('WA-P12', 'field', 0, $false, 'field', $false, $false, $true, $false, 'field'),
    @('WA-P13', 'inside', 2, $true, 'reward', $false, $false, $false, $false, 'entered'),
    @('WA-P14', 'reward3', 0, $true, 'field', $false, $false, $false, $false, ''),
    @('N4-L4', 'reward3', 0, $true, 'field', $true, $true, $false, $false, ''),                     # 필드 목표는 보고 켬이어도 3버튼 결론 없음 - 순위 5·6 의 목표 항
    @('FC-P1', 'field', 0, $true, 'entry', $true, $false, $true, $true, 'field-cancelled'),
    @('FC-P2', 'field', 0, $false, 'entry', $true, $false, $true, $true, 'field-cancelled'),        # 패널 관측 무관 (사용자 결정 U-5b8-1)
    @('FC-P3', 'field', 0, $false, 'entry', $true, $true, $true, $true, 'field-cancelled'),         # WA-P10 + 스위치
    @('FC-P4', 'field', 0, $false, 'entry', $false, $false, $true, $true, 'field-cancelled'),       # 보고 무관 (명세 2.1 - 순수 판정은 필드 결과만 봄)
    @('FC-P5', 'field', 0, $true, 'entry', $true, $false, $false, $true, ''),                       # 확정 아님
    @('FC-P6', 'unknown', 0, $true, 'entry', $true, $true, $true, $true, ''),
    @('FC-P7', 'inside', 1, $true, 'entry', $true, $true, $true, $true, ''),
    @('FC-P8', 'reward3', 0, $false, 'entry', $true, $false, $true, $true, ''),
    @('FC-P9', 'matching', 0, $true, 'entry', $true, $true, $true, $true, ''),
    @('FC-P10', 'field', 0, $true, 'field', $true, $false, $true, $true, 'field'),                  # 목표 field → 순위 2 그대로 (스위치가 다른 결론을 막지 않음)
    @('FC-P11', 'field', 0, $true, 'reward', $true, $false, $true, $true, ''),                      # 목표 reward
    @('FC-P12', 'field', 2, $true, 'entry', $true, $false, $true, $true, 'entered'),                # 입장이 이김
    @('FC-P13', 'reward3', 0, $true, 'entry', $true, $false, $true, $true, 'cancelled'),            # 3버튼 + 패널 + 스위치 → cancelled 그대로
    @('FC-P14', 'reward3', 0, $false, 'entry', $true, $true, $true, $true, 'reclick'),
    @('FC-P15', 'reward3', 0, $false, 'reward', $false, $false, $false, $true, 'reward'))
$verdictColumnProblems = @($VERDICT_ROWS | Where-Object { @($_).Count -ne 10 } | ForEach-Object { [string]$_[0] })
Check-True '§6 표 모양 - 모든 행 10열(이름 · 분류 · 연속 · 패널 · 목표 · 보고 · 무변화 · 확정 · 필드 결과 · 기대)' ($verdictColumnProblems.Count -eq 0) ($verdictColumnProblems -join ',')
foreach ($verdictRow in $VERDICT_ROWS) {
    $verdictActual = ''
    try {
        $verdictActual = [string](Resolve-AbyssReentryVerdict -Kind $verdictRow[1] -InsideStreak $verdictRow[2] -PanelSeen $verdictRow[3] -Target $verdictRow[4] `
                -ReportRewardReturn $verdictRow[5] -QuietExpired $verdictRow[6] -FieldSettled $verdictRow[7] -ReportFieldReturn $verdictRow[8])
    } catch {
        $verdictActual = 'THREW: ' + $_.Exception.Message
    }
    Check-Equal ("{0} 분류 {1} · 던전 안 연속 {2} · 패널 관측 {3} · 목표 {4} · 보고 {5} · 무변화 만료 {6} · 필드 확정 {7} · 필드 결과 {8} → '{9}'" -f $verdictRow) "[$verdictActual]" "[$($verdictRow[9])]"
}

# ── §6a 재개 유예 판정 Resolve-AbyssResumeGrace 진리표 RG (구현 명세 ⑤c 3.4 · 설계 v11 R5 4.3 ④ - 원문 실행 · 비교는 -ceq) ───────────────────────────────
# 열 = 이름 · Streak · Run · GraceRun · GraceOpen · QuietOpen · Report · LastKind · Reverted · 기대. 행마다 여덟 입력을 다 적습니다 - 줄여 적으면 기대가 바뀝니다('/ X 거짓' 꼴
#   변형을 RG1 에서 만들면 RG4 · RG7 · RG8 · RG10 · RG12 가 'inside-first', LastKind '' · Reverted 참으로 채우면 RG4 · RG5 가 'unread' · RG5 · RG7 · RG8 이 'reverted').
#   RG13 은 두 호출 자리에서 생기지 않는 입력(연속 1 ∧ 되돌림 표식)으로 첫 if 가 'reward' · 'reverted' 보다 앞이라는 판정식 꼴만 봅니다 - 다섯 if 의 차례는 정적 R5-P14 가
#   소스 차례로 고정하고, 두 호출 자리에서는 부르는 쪽 불변식으로 다섯 창이 서로 배타라 차례가 결과를 바꾸지 않습니다(명세 3.4 '차례')
$GRACE_ROWS = @(
    @('RG1', 1, 1, 0, $true, $true, $false, 'inside', $false, 'inside-first'),
    @('RG2', 1, 2, 0, $false, $false, $false, 'inside', $false, 'inside-first'),        # 상한 없음 - 시계 둘 다 닫힘
    @('RG3', 1, 1, 1, $true, $true, $false, 'inside', $false, 'inside-extend'),
    @('RG4', 1, 1, 1, $false, $true, $false, 'inside', $false, ''),
    @('RG5', 1, 2, 1, $true, $true, $false, 'inside', $false, ''),                     # 새 연속은 미루지 않음
    @('RG6', 0, 1, 0, $true, $true, $true, 'reward3', $false, 'reward'),
    @('RG7', 0, 1, 0, $true, $true, $false, 'reward3', $false, ''),
    @('RG8', 0, 1, 0, $true, $false, $true, 'reward3', $false, ''),
    @('RG9', 0, 0, 0, $true, $true, $false, '', $false, 'unread'),
    @('RG10', 0, 0, 0, $true, $false, $false, '', $false, ''),
    @('RG11', 0, 1, 0, $true, $true, $false, 'inside', $true, 'reverted'),
    @('RG12', 0, 1, 0, $false, $true, $false, 'inside', $true, ''),
    @('RG13', 1, 1, 0, $true, $true, $true, 'reward3', $true, 'inside-first'))         # 차례 꼴 표본 - 불변식 밖 입력 · 행동 계약 아님
# RG14 - 기다리는 상태 일곱(패널류 · 팝업 · 접힌 패널 · 알 수 없음 · S · 확정 전 필드 모양)은 무변화 창 · 보고가 열려 있어도 어느 창도 아닙니다
foreach ($waitingKind in @('ready', 'matching', 'popup', 'entry-waiting', 'unknown', 'prompt', 'field')) { $GRACE_ROWS += , @(('RG14 ' + $waitingKind), 0, 1, 0, $true, $true, $true, $waitingKind, $false, '') }
$graceColumnProblems = @($GRACE_ROWS | Where-Object { @($_).Count -ne 10 } | ForEach-Object { [string]$_[0] })
Check-True ('§6a 표 모양 - 모든 행 10열(이름 · 여덟 입력 · 기대) · 행 {0}(RG1~RG13 + RG14 일곱 = 20)' -f $GRACE_ROWS.Count) (($graceColumnProblems.Count -eq 0) -and ($GRACE_ROWS.Count -eq 20)) ($graceColumnProblems -join ',')
foreach ($graceRow in $GRACE_ROWS) {
    $graceActual = ''
    try {
        $graceActual = [string](Resolve-AbyssResumeGrace -InsideStreak $graceRow[1] -InsideRun $graceRow[2] -InsideGraceRun $graceRow[3] -InsideGraceOpen $graceRow[4] `
                -QuietOpen $graceRow[5] -ReportRewardReturn $graceRow[6] -LastKind $graceRow[7] -Reverted $graceRow[8])
    } catch {
        $graceActual = 'THREW: ' + $_.Exception.Message
    }
    Check-Equal ("{0} 연속 {1} · 번호 {2} · 쓴 번호 {3} · 유예 시계 안 {4} · 무변화 창 안 {5} · 보고 {6} · 마지막 분류 '{7}' · 되돌림 {8} → '{9}'" -f $graceRow) "[$graceActual]" "[$($graceRow[9])]"
}
# RG-S 순수 정적(주석 뺀 사본) - 명령 0 · 접두 변수($script: 등) 0 · return 6 · 반환 집합 (구현 명세 ⑤c 3.4 '정적'. 다섯 if 의 차례는 R5-P14 가 봄)
$graceNode = Get-WorkerFunction 'Resolve-AbyssResumeGrace'
$graceCommandCount = @($graceNode.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true)).Count
$graceQualifiedCount = @($graceNode.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and (-not $candidate.VariablePath.IsUnqualified) }, $true)).Count
$graceReturns = @($graceNode.FindAll({ param($candidate) $candidate -is [ReturnStatementAst] }, $true))
[string[]]$graceReturnValues = @($graceReturns | ForEach-Object {
        $returnConstants = @($_.FindAll({ param($candidate) $candidate -is [StringConstantExpressionAst] }, $true))
        $(if ($returnConstants.Count -eq 1) { [string]$returnConstants[0].Value } else { '(값)' })
    } | Sort-Object -Unique)
[Array]::Sort($graceReturnValues, [StringComparer]::Ordinal)
Check-Equal "RG-S 재개 유예 판정 순수 - 명령 0 · 접두 변수 0 · return 6 · 반환 집합 {'', inside-extend, inside-first, reverted, reward, unread}" `
    ('명령 {0} · 접두 변수 {1} · return {2} · 반환=[{3}]' -f $graceCommandCount, $graceQualifiedCount, $graceReturns.Count, ($graceReturnValues -join ',')) '명령 0 · 접두 변수 0 · return 6 · 반환=[,inside-extend,inside-first,reverted,reward,unread]'

# ── §6b ⑤b1 순수부 - 보상 결정 경로(RR) · 보상 결정(RD · MX) · '다른 던전 가기' 대기 분류(OC) · 시간 함수(V·U) · 정적(P5b) (구현 명세 ⑤b1 3절 · ⑤b6 3.1 · 3.2 - 비교는 -ceq) ──
# 원문 그대로 올립니다(사본 재구현 금지). 시간 재판단 행(U)은 블록 안에서만 실제 Get-DgTimeVerdict 를 올립니다 - 파일 최상위의 같은 이름은 waiter 의
# 호출 0 을 세는 기록 모의라 그대로 둡니다. 시계는 이 파일의 Get-Date 모의($script:vclock)를 씁니다
$PURE_5B1_NAMES = @('Test-AbyssRetryRoute', 'Resolve-AbyssRewardDecision', 'Resolve-AbyssOtherWaitScreen', 'Get-AbyssUntilTime', 'Update-AbyssRetryTimeVerdict',
    'Get-LifeUntilDeadline', 'ConvertFrom-AbyssCustomItemSpec')
try {
    foreach ($definition5b1 in @(Get-SourceFunctionDefinitions -Path $workerPath -Names $PURE_5B1_NAMES)) { Invoke-Expression ([string]$definition5b1) }
} catch {
    "FAIL 준비: ⑤b1 함수를 워커에서 추출하지 못했습니다 ($($_.Exception.Message))"
    exit 1
}

# RR - 경로 술어: 정리 전용 · 입장 방식 · 매칭 → 참 = '다시 하기' 경로 (설계 v11 R3 K21·K22 · R6 3.5 ③ · R4 U1)
$ROUTE_ROWS = @(
    @('RR1', $false, 'solo', '없음', $true),            # 커스텀 혼자하기 항목
    @('RR2', $false, 'solo', '우연한 만남', $true),     # 혼자하기 - config 매칭 라디오 값이 남아 있음
    @('RR3', $false, 'solo', '파티(파티원)', $true),    # 혼자하기 + 매칭 라디오 파티원 보존 (R3 5.1 U4)
    @('RR4', $false, 'party', '우연한 만남', $true),
    @('RR5', $false, 'party', '파티찾기', $false),      # 마지막 판도 나가기 (R4 U1 · R3 K21)
    @('RR6', $false, 'party', '파티(파티장)', $false),  # ⑥d 까지 옛 경로 (R3 K22)
    @('RR7', $false, 'party', 'xyz', $false),           # 모르는 매칭 - 본류 입장은 파티 찾기 갈래
    @('RR8', $true, 'solo', '없음', $false),            # 정리 전용 (R6 3.5 ③ · FB13)
    @('RR9', $true, 'party', '우연한 만남', $false))
foreach ($routeRow in $ROUTE_ROWS) {
    Check-Equal ("{0} 정리 전용 {1} · 방식 {2} · 매칭 {3} → {4}" -f $routeRow) ([string](Test-AbyssRetryRoute -CleanupOnly $routeRow[1] -Mode $routeRow[2] -Matching $routeRow[3])) ([string]$routeRow[4])
}

# RD - 보상 결정 (설계 v10 2.1(2) 순위 ①~⑥ = 코드 주석 ①·③·⑥~⑨ - 코드 ② 는 커스텀 관문이라 설계 ②~⑥ 이 코드 ③ · ⑥~⑨ · v11 R3 2.3·6.6 · dev:976 결정 매트릭스. 코드 ④ · ⑤ 는
#   구현 명세 ⑤b6 이 더한 입장 방식 순위 - 아래 MX). 항목은 워커 해석 함수로 실제 토큰에서 만듭니다. 기대 Action · Reason 은 계약 열거값입니다(구현 명세 ⑤b6 1.3 - 멈출 때 ① 과 다음 판
#   입장 방식이 다르거나 모를 때 ③~⑤ 는 exit = 옛 나가기 · 같은 입장 방식의 경계 · 던전·난이도 다름 · 소유자 없음 ⑥~⑧ 은 other)
$ITEM_A = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|어려움|허상의 정박지|우연한 만남'
$ITEM_SOLO = ConvertFrom-AbyssCustomItemSpec -Spec 'A|solo|어려움|허상의 정박지|없음'
$ITEM_DUNGEON = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|어려움|광기의 동굴|우연한 만남'
$ITEM_DIFFICULTY = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|입문|허상의 정박지|우연한 만남'
$ITEM_MATCHING = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|어려움|허상의 정박지|파티찾기'
$ITEM_GAME = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|게임 그대로|허상의 정박지|우연한 만남'   # 난이도 '게임 그대로' - 양쪽 다 이 글자일 때만 같음 (설계 09-21 B4 · B7)
$ITEM_SOLO_DUNGEON = ConvertFrom-AbyssCustomItemSpec -Spec 'A|solo|어려움|광기의 동굴|없음'
$ITEM_SOLO_DIFFICULTY = ConvertFrom-AbyssCustomItemSpec -Spec 'A|solo|매우 어려움|허상의 정박지|없음'
$ITEM_SOLO_RAW = ConvertFrom-AbyssCustomItemSpec -Spec 'A|solo|어려움|허상의 정박지|우연한 만남'     # 혼자하기 토큰에 매칭 칸이 남은 꼴 - 해석한 매칭은 '없음'
$ITEM_FIND_SPACED = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|어려움|허상의 정박지|파티 찾기'   # 공백 표기 - 해석한 매칭은 '파티찾기'($ITEM_MATCHING 과 같음)
$ITEM_LEADER = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|어려움|허상의 정박지|파티(파티장)'
# 같은 항목 행의 다음 쪽($NEXT_*)은 같은 토큰을 따로 해석한 객체입니다 - 운영의 지금 항목($script:customItem - HONEYNOGI_CUSTOM_ITEM)과
#   다음 항목($script:customNext - HONEYNOGI_CUSTOM_NEXT)은 따로 해석한 다른 객체라, 같은 객체를 넘기면 항목을 참조로 비교하는 변이가 지납니다
$NEXT_A = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|어려움|허상의 정박지|우연한 만남'
$NEXT_SOLO = ConvertFrom-AbyssCustomItemSpec -Spec 'A|solo|어려움|허상의 정박지|없음'
$NEXT_GAME = ConvertFrom-AbyssCustomItemSpec -Spec 'A|party|게임 그대로|허상의 정박지|우연한 만남'
if (@(@($ITEM_A, $ITEM_SOLO, $ITEM_DUNGEON, $ITEM_DIFFICULTY, $ITEM_MATCHING, $ITEM_GAME, $ITEM_SOLO_DUNGEON, $ITEM_SOLO_DIFFICULTY, $ITEM_SOLO_RAW, $ITEM_FIND_SPACED, $ITEM_LEADER,
            $NEXT_A, $NEXT_SOLO, $NEXT_GAME) | Where-Object { $null -eq $_ }).Count -gt 0) { 'FAIL 준비: ⑤b1 항목 토큰 해석 실패'; exit 1 }
# 열: 이름 · 안전 중지 · 마무리 · 마지막 판 · 시간 · 커스텀 · NEXT 있음 · NEXT 항목 · 지금 항목 · 경계 · NEXT_OWNER 해석 성공 · 기대 Action · 기대 Reason
$DECISION_ROWS = @(
    @('RD1', $false, $false, $false, '', $false, $false, $null, $null, $false, $false, 'retry', ''),                       # K1 · W1
    @('RD2', $false, $false, $false, 'continue', $false, $false, $null, $null, $false, $false, 'retry', ''),               # K2 · W3
    @('RD3', $false, $false, $false, 'last', $false, $false, $null, $null, $false, $false, 'exit', 'time'),                # K5 · W6
    @('RD4', $true, $false, $false, 'last', $false, $false, $null, $null, $false, $false, 'exit', 'safe-stop'),            # K10 · SS9
    @('RD5', $false, $true, $true, 'last', $false, $false, $null, $null, $false, $false, 'exit', 'finish-only'),           # K11 · W14
    @('RD6', $false, $false, $true, 'continue', $false, $false, $null, $null, $false, $false, 'exit', 'last-run'),         # R3 6.6 · SS6
    @('RD7', $false, $false, $true, 'last', $false, $false, $null, $null, $false, $false, 'exit', 'last-run'),             # R3 2.3 마지막 판 > 시간
    @('RD8', $true, $true, $true, '', $false, $false, $null, $null, $false, $false, 'exit', 'safe-stop'),                  # 안전 중지 > 마무리
    @('RD9', $false, $false, $false, '', $true, $true, $NEXT_A, $ITEM_A, $false, $true, 'retry', ''),                      # K13 · W15 · [A,A] 첫 항목
    @('RD9s', $false, $false, $false, '', $true, $true, $NEXT_SOLO, $ITEM_SOLO, $false, $true, 'retry', ''),               # 커스텀 혼자하기
    @('RD10', $false, $false, $false, '', $true, $true, $NEXT_A, $ITEM_A, $false, $false, 'other', 'next-owner-empty'),    # 바퀴 중간 소유자 빈 값·해석 실패 (바퀴 끝은 경계가 먼저 - U-⑤-2 (가) · 구현 명세 ⑤b5 B-5)
    @('RD11', $false, $false, $false, '', $true, $true, $NEXT_A, $ITEM_A, $true, $false, 'other', 'boundary'),             # 바퀴 끝(순차·랜덤·1항목 - 구현 명세 ⑤b5 B-5)
    @('RD12', $false, $false, $false, '', $true, $true, $ITEM_DUNGEON, $ITEM_A, $false, $true, 'other', 'item-change'),
    @('RD12s', $false, $false, $false, '', $true, $true, $ITEM_SOLO_DUNGEON, $ITEM_SOLO, $false, $true, 'other', 'item-change'),     # 혼자하기 다른 던전 (같은 입장 방식 - 구현 명세 ⑤b6 3.1)
    @('RD13', $false, $false, $false, '', $true, $true, $ITEM_DIFFICULTY, $ITEM_A, $false, $true, 'other', 'item-change'),
    @('RD13s', $false, $false, $false, '', $true, $true, $ITEM_SOLO_DIFFICULTY, $ITEM_SOLO, $false, $true, 'other', 'item-change'),  # 혼자하기 다른 난이도 (같은 입장 방식)
    @('RD14', $false, $false, $false, '', $true, $true, $ITEM_MATCHING, $ITEM_A, $false, $true, 'exit', 'entry-change'),   # 매칭만 다름(우연 → 파티 찾기) - 시작 게이트로 실게임 도달 0 · ⑤ 의 매칭 항 고정
    @('RD15', $false, $false, $false, '', $true, $true, $ITEM_A, $ITEM_SOLO, $false, $true, 'exit', 'entry-change'),       # 혼자 → 함께 · 우연(같은 던전 · 난이도 - 섞인 리스트의 실제 토큰)
    @('RD15r', $false, $false, $false, '', $true, $true, $ITEM_SOLO, $ITEM_A, $false, $true, 'exit', 'entry-change'),      # 우연 → 혼자(같은 던전 · 난이도)
    @('RD16', $false, $false, $false, '', $true, $true, $null, $ITEM_A, $false, $true, 'exit', 'next-invalid'),            # NEXT 손상 - 다음 판 입장 방식을 모름
    @('RD17', $false, $false, $false, '', $true, $false, $null, $ITEM_A, $false, $true, 'exit', 'entry-change'),           # NEXT 빈 값 - 다음 판 입장 방식을 모름 (GUI 는 늘 넣어 도달 0 · 명세 어-29 · 구현 명세 ⑤b6 B-11)
    @('RD18', $false, $false, $true, '', $true, $true, $NEXT_A, $ITEM_A, $false, $false, 'exit', 'last-run'),              # 마지막 바퀴 끝 항목
    @('RD19', $false, $true, $true, '', $true, $true, $ITEM_DUNGEON, $ITEM_A, $false, $false, 'exit', 'finish-only'),      # 커스텀 마무리 실행 (gui:9639~9649)
    @('RD20', $false, $false, $false, '', $true, $true, $null, $ITEM_A, $true, $false, 'exit', 'next-invalid'),            # 손상 > 경계
    @('RD21', $false, $false, $false, '', $true, $true, $ITEM_DUNGEON, $ITEM_A, $true, $false, 'other', 'boundary'),       # 경계 > 던전 다름 (같은 입장 방식)
    @('RD22', $false, $false, $false, '', $true, $true, $ITEM_DUNGEON, $ITEM_A, $false, $false, 'other', 'item-change'),   # 다름 > 소유자 빈 값·해석 실패
    @('RD23', $true, $false, $false, '', $true, $true, $NEXT_A, $ITEM_A, $false, $true, 'exit', 'safe-stop'),             # 순위 ① > 커스텀
    @('RD24', $false, $false, $false, '', $true, $true, $ITEM_A, $ITEM_GAME, $false, $true, 'other', 'item-change'),      # [게임 그대로, 어려움] - 지금 UI 가 우연히 같아도 다름 (B4)
    @('RD24r', $false, $false, $false, '', $true, $true, $ITEM_GAME, $ITEM_A, $false, $true, 'other', 'item-change'),     # [어려움, 게임 그대로] - 반대 방향
    @('RD25', $false, $false, $false, '', $true, $true, $NEXT_GAME, $ITEM_GAME, $false, $true, 'retry', ''))              # [게임 그대로, 게임 그대로] - 양쪽 다 그 글자면 같음
foreach ($decisionRow in $DECISION_ROWS) {
    $decision5b1 = Resolve-AbyssRewardDecision -SafeStopRequested $decisionRow[1] -FinishOnly $decisionRow[2] -LastRun $decisionRow[3] -TimeVerdict $decisionRow[4] `
        -CustomMode $decisionRow[5] -NextGiven $decisionRow[6] -NextItem $decisionRow[7] -CurrentItem $decisionRow[8] -NextBoundary $decisionRow[9] -NextOwnerGiven $decisionRow[10]
    Check-Equal ("{0} 안전 중지 {1} · 마무리 {2} · 마지막 판 {3} · 시간 '{4}' · 커스텀 {5} · NEXT 있음 {6} · 경계 {9} · 소유자 {10} → {11}/{12}" -f $decisionRow) `
        ('{0}/{1}' -f $decision5b1.Action, $decision5b1.Reason) ('{0}/{1}' -f $decisionRow[11], $decisionRow[12])
}
# MX - 섞기 허용 순위 (구현 명세 ⑤b6 1.3 ③~⑤ · 3.1 ④ RD - 사용자 결정 2026-10-26 밤: 혼자하기 ↔ 함께하기 · 우연한 만남 섞기 · 랜덤 진행의 섞인 바퀴 끝 = 필드). 위 RD 열 뒤에 '미정'
#   (-NextEntryUnknown = GUI 경계 신호 'mixed')을 하나 더합니다. 기대 = 계약 열거값 · 항목 = 워커 해석 함수로 만든 실제 토큰
# 열: 이름 · 안전 중지 · 마무리 · 마지막 판 · 시간 · 커스텀 · NEXT 있음 · NEXT 항목 · 지금 항목 · 경계 · NEXT_OWNER 해석 성공 · 미정 · 기대 Action · 기대 Reason
$DECISION_MIX_ROWS = @(
    @('MX2', $false, $false, $false, '', $true, $true, $ITEM_SOLO, $ITEM_A, $true, $false, $false, 'exit', 'entry-change'),          # 방식 다름 > 경계 (순차 섞인 리스트 바퀴 끝 - NEXT = 다음 바퀴 첫 칸)
    @('MX3', $false, $false, $false, '', $true, $true, $ITEM_DUNGEON, $ITEM_SOLO, $false, $true, $false, 'exit', 'entry-change'),    # 방식 다름 > 다른 던전
    @('MX4', $false, $false, $false, '', $true, $true, $ITEM_A, $ITEM_SOLO, $false, $false, $false, 'exit', 'entry-change'),         # 방식 다름 > 소유자 없음
    @('MX5', $false, $false, $false, '', $true, $true, $NEXT_A, $ITEM_A, $false, $false, $true, 'exit', 'next-unknown'),             # 미정 · NEXT 같은 항목 (랜덤 바퀴 끝 NEXT = 이번 순열 첫 칸이라 믿지 않음)
    @('MX6', $false, $false, $false, '', $true, $true, $ITEM_SOLO, $ITEM_A, $false, $false, $true, 'exit', 'next-unknown'),          # 미정 > 방식 다름
    @('MX7', $false, $false, $false, '', $true, $true, $null, $ITEM_A, $false, $false, $true, 'exit', 'next-invalid'),               # 손상 > 미정
    @('MX8', $false, $false, $true, '', $true, $true, $NEXT_A, $ITEM_A, $false, $false, $true, 'exit', 'last-run'),                  # 마지막 판 > 미정
    @('MX9', $true, $false, $false, '', $true, $true, $ITEM_SOLO, $ITEM_A, $false, $true, $false, 'exit', 'safe-stop'),              # 안전 중지 > 방식 다름
    @('MX10', $false, $false, $false, '', $false, $false, $null, $null, $false, $false, $true, 'retry', ''),                         # 비커스텀은 미정을 보지 않음
    @('MX11', $false, $false, $false, '', $true, $true, $ITEM_SOLO_RAW, $ITEM_SOLO, $false, $true, $false, 'retry', ''),             # 혼자하기 토큰의 매칭 칸이 달라도 같은 입장 방식 (해석이 '없음' 으로 정규화)
    @('MX12', $false, $false, $false, '', $true, $true, $ITEM_MATCHING, $ITEM_FIND_SPACED, $false, $true, $false, 'retry', ''),      # 파티 찾기 표기 둘(공백 유무)은 같은 입장 방식 (해석이 '파티찾기')
    @('MX13', $false, $false, $false, '', $true, $true, $ITEM_LEADER, $ITEM_A, $false, $true, $false, 'exit', 'entry-change'))      # 우연 → 파티장 - 시작 게이트로 실게임 도달 0 · 순위 고정
foreach ($mixRow in $DECISION_MIX_ROWS) {
    $decision5b6 = Resolve-AbyssRewardDecision -SafeStopRequested $mixRow[1] -FinishOnly $mixRow[2] -LastRun $mixRow[3] -TimeVerdict $mixRow[4] -CustomMode $mixRow[5] `
        -NextGiven $mixRow[6] -NextItem $mixRow[7] -CurrentItem $mixRow[8] -NextBoundary $mixRow[9] -NextOwnerGiven $mixRow[10] -NextEntryUnknown $mixRow[11]
    Check-Equal ("{0} 안전 중지 {1} · 마무리 {2} · 마지막 판 {3} · 시간 '{4}' · 커스텀 {5} · NEXT 있음 {6} · 경계 {9} · 소유자 {10} · 미정 {11} → {12}/{13}" -f $mixRow) `
        ('{0}/{1}' -f $decision5b6.Action, $decision5b6.Reason) ('{0}/{1}' -f $mixRow[12], $mixRow[13])
}
$decisionShape = Resolve-AbyssRewardDecision -SafeStopRequested $false -FinishOnly $false -LastRun $false -TimeVerdict '' -CustomMode $false -NextGiven $false -NextBoundary $false -NextOwnerGiven $false
Check-Equal 'RD-S 반환 = 해시 1개 · 키 Action,Reason' ('{0} · {1}' -f @($decisionShape).Count, ((@($decisionShape.Keys) | Sort-Object) -join ',')) '1 · Action,Reason'

# OC - '다른 던전 가기' 대기 분류 (설계 v11 R6 2.6·7.0). 하단 판독문은 위 $SCREEN_TABLE 의 실측 문자열 그대로(출처는 그 표의 주석)
# 열: 이름 · 하단 · 패널 · 선택 화면 · HUD · 추적기 · 메뉴 · 기대
$OTHER_SCREEN_ROWS = @(
    @('OC1', $SCREEN_TABLE['M'].Bottom, 'matching', $false, $false, $false, $false, 'panel'),
    @('OC1r', $SCREEN_TABLE['Rd'].Bottom, 'ready', $false, $false, $false, $false, 'panel'),
    @('OC2', $SCREEN_TABLE['E'].Bottom, 'none', $false, $false, $false, $false, 'panel'),
    @('OC2h', $SCREEN_TABLE['E'].Bottom, 'none', $false, $true, $true, $false, 'panel'),             # R6 순위 1 의 접힌 패널 항에 HUD 조건 없음 (명세 5절 B)
    @('OC3', $SCREEN_TABLE['R'].Bottom, 'none', $true, $false, $false, $false, 'selection'),         # selection > reward3 (R6-M12)
    @('OC3p', $SCREEN_TABLE['R'].Bottom, 'matching', $true, $false, $false, $false, 'panel'),        # panel > selection
    @('OC4', $SCREEN_TABLE['R'].Bottom, 'none', $false, $false, $false, $false, 'reward3'),
    @('OC5', $SCREEN_TABLE['R'].Bottom, 'none', $false, $true, $true, $false, 'inside'),             # reward3 의 'HUD 없음'
    @('OC5f', $SCREEN_TABLE['R'].Bottom, 'none', $false, $true, $false, $false, 'field'),
    @('OC6', $SCREEN_TABLE['F'].Bottom, 'none', $false, $true, $false, $false, 'field'),
    @('OC6i', $SCREEN_TABLE['I'].Bottom, 'none', $false, $true, $true, $false, 'inside'),
    @('OC7', $SCREEN_TABLE['U'].Bottom, 'none', $false, $false, $false, $true, 'menu'),
    @('OC7q', $SCREEN_TABLE['U'].Bottom, 'none', $false, $false, $true, $true, 'menu'),               # HUD 가 없으면 추적기를 보지 않음 - 앞 회전의 추적기 값이 남아도 inside 가 아님 (명세 1.3 · C-10)
    @('OC7r', $SCREEN_TABLE['R'].Bottom, 'none', $false, $false, $false, $true, 'reward3'),           # reward3 > menu
    @('OC7f', $SCREEN_TABLE['F'].Bottom, 'none', $false, $true, $false, $true, 'field'),             # field > menu
    @('OC8', $SCREEN_TABLE['U'].Bottom, 'none', $false, $false, $false, $false, 'unknown'),
    @('OC8q', $SCREEN_TABLE['U'].Bottom, 'none', $false, $false, $true, $false, 'unknown'),           # 같은 계약 - unknown 갈래
    @('OC8s', $SCREEN_TABLE['S'].Bottom, 'none', $false, $false, $false, $false, 'unknown'),          # S 는 이 대기의 분류 밖
    @('OC8p', $SCREEN_TABLE['P'].Bottom, 'none', $false, $false, $false, $false, 'unknown'))          # 권장 인원 팝업도 분류 밖
foreach ($otherRow in $OTHER_SCREEN_ROWS) {
    Check-Equal ("{0} 패널 {2} · 선택 {3} · HUD {4} · 추적기 {5} · 메뉴 {6} → {7}" -f $otherRow) `
        (Resolve-AbyssOtherWaitScreen -BottomText $otherRow[1] -PanelKind $otherRow[2] -SelectionVisible $otherRow[3] -HudVisible $otherRow[4] -InDungeonQuest $otherRow[5] -MenuVisible $otherRow[6]) $otherRow[7]
}
Check-Equal 'OC8d 메뉴 인자 생략 → unknown (-MenuVisible 기본 거짓 - 명세 1.3)' `
    (Resolve-AbyssOtherWaitScreen -BottomText $SCREEN_TABLE['U'].Bottom -PanelKind 'none' -SelectionVisible $false -HudVisible $false -InDungeonQuest $false) 'unknown'

# V - 지정 시각 읽기 Get-AbyssUntilTime (설계 v11 R3 5.2 V1·V6 + V2·V5 의 읽기 몫) · 경고 줄은 이 파일의 Write-RunLog 모의가 모음
$UNTIL_ROWS = @(
    @('V1', '', '(없음)', 0),
    @('V2', '2026-10-01 10:00', '2026-10-01 10:00', 0),
    @('V5', '2026-10-02 00:30', '2026-10-02 00:30', 0),
    @('V6', '2026-10-01 10.00', '(없음)', 1))
$savedUntilEnv = $env:HONEYNOGI_UNTIL_TIME
foreach ($untilRow in $UNTIL_ROWS) {
    $script:rowLogs = New-Object System.Collections.Generic.List[string]
    $env:HONEYNOGI_UNTIL_TIME = $untilRow[1]
    $untilValue = Get-AbyssUntilTime
    $untilText = $(if ($null -eq $untilValue) { '(없음)' } else { ([datetime]$untilValue).ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture) })
    $untilWarnings = @($script:rowLogs | Where-Object { $_.StartsWith('[경고] 지정 시간 값을 해석하지 못했습니다') }).Count
    Check-Equal ("{0} env '{1}' → {2} · 경고 {3}" -f $untilRow) ('{0} · {1}' -f $untilText, $untilWarnings) ('{0} · {1}' -f $untilRow[2], $untilRow[3])
}
$env:HONEYNOGI_UNTIL_TIME = $savedUntilEnv

# U - 시간 재판단 Update-AbyssRetryTimeVerdict (설계 v11 R3 6.6 '함수 단위' - Get-DgTimeVerdict 호출 1 · 결과를 대입하고 같은 값을 반환)
$REAL_TIME_VERDICT_TEXT = [string](Get-WorkerFunction 'Get-DgTimeVerdict').Extent.Text
$TIME_ROWS = @(
    @('U1', '2026-10-01 10:00', '2026-10-01 09:59:59', 'continue'),
    @('U2', '2026-10-01 10:00', '2026-10-01 10:00:00', 'last'),      # 같은 시각 포함 (-ge)
    @('U3', '', '2026-10-01 23:00:00', ''))                          # 지정 시각 없음·해석 실패
foreach ($timeRow in $TIME_ROWS) {
    $timeOutcome = & {
        Invoke-Expression $REAL_TIME_VERDICT_TEXT
        $script:abyssUntil = $(if ($timeRow[1]) { [datetime]$timeRow[1] } else { $null })
        $script:vclock = [datetime]$timeRow[2]
        $script:abyssRetryTimeVerdict = 'stale'
        $timeReturned = Update-AbyssRetryTimeVerdict
        '{0}|{1}' -f $timeReturned, $script:abyssRetryTimeVerdict
    }
    Check-Equal ("{0} 지정 {1} · 지금 {2} → 반환·대입 '{3}'" -f $timeRow) $timeOutcome ('{0}|{0}' -f $timeRow[3])
}
$spyCalls5b1 = New-Object System.Collections.Generic.List[string]
$spyOutcome5b1 = & {
    function Get-DgTimeVerdict { param($UntilTime = $null, [datetime]$Now) $spyCalls5b1.Add(('{0}|{1}' -f $UntilTime, $Now.ToString('HH:mm:ss'))); return 'SPY' }
    $script:abyssUntil = [datetime]'2026-10-01 10:00'
    $script:vclock = [datetime]'2026-10-01 09:30:15'
    $script:abyssRetryTimeVerdict = 'stale'
    $spyReturned5b1 = Update-AbyssRetryTimeVerdict
    '{0}|{1}' -f $spyReturned5b1, $script:abyssRetryTimeVerdict
}
Check-Equal 'U4 감시 - Get-DgTimeVerdict 호출 1 · 인자(지정 시각 · Get-Date) · 반환 = 대입 = 감시 값' ('{0} · {1} · {2}' -f $spyCalls5b1.Count, ($spyCalls5b1 -join ';'), $spyOutcome5b1) `
    ('1 · {0}|09:30:15 · SPY|SPY' -f ([datetime]'2026-10-01 10:00'))
$script:abyssUntil = $null; $script:abyssRetryTimeVerdict = $null

# P5b - 정적 (주석 뺀 사본 · AST)
# P5b-1 순수 셋 (명세 리뷰 1 P2-2 강화 · 확인 라운드 1 switch -File) - 명령 집합 · 이름 없는 명령·호출 연산자 0 · 접두 변수 0 · 바깥 변수 0 · 대입·증감 = 함수별 허용 목록 ·
#   메서드 호출 0 · 리디렉션 0 · 캐스트는 [string] 만 · 타입 리터럴 0 · exit·throw·try·trap·break·continue 0 · switch -File 0. 명령이 아닌 부작용(매개변수 객체 변경 · 정적 멤버 ·
#   파일 쓰기·읽기 · 동적 호출 · 부른 쪽 루프를 끊는 break)은 행의 결론을 바꾸지 않아 행이 못 잡습니다 - 이름 없는 바깥 변수 읽기와 같은 까닭(test_abyss_journal_store J15
#   선례). 대입의 범위는 이 파일 N4-P5 와 같습니다(멤버·인덱스 대상 · 증감 포함) · exit·throw·try 는 N4-P3 선례
$PURE_5B1_COMMANDS = [ordered]@{ 'Resolve-AbyssOtherWaitScreen' = 'Test-AbyssEntryWaitingText,Test-AbyssRewardText'; 'Resolve-AbyssRewardDecision' = ''; 'Test-AbyssRetryRoute' = '' }
$PURE_5B1_ASSIGNS = @{ 'Resolve-AbyssOtherWaitScreen' = ''; 'Resolve-AbyssRewardDecision' = '$sameEntry,$sameItem'; 'Test-AbyssRetryRoute' = '' }   # 결정의 $sameEntry = 입장 방식(방식 · 매칭) 같음 - 구현 명세 ⑤b6 1.3 ⑤
# ⑤b2 기록 확인 함수(P5c-1)도 이 표로 봅니다 - 같은 열한 칸 식을 한 곳에서 돌려 두 단계의 순수성 계약이 함께 움직입니다(구현 명세 ⑤b2 3.2 · 명세 리뷰 2 P2).
#   허용 목록 = 명령·대입 없음(캐스트는 공통 칸 그대로 [string] 만). [ordered] 표 끝에 덧붙여 출력은 넷째 줄 'P5b-1 Resolve-AbyssRewardBranch 순수 …' 입니다
$PURE_5B1_COMMANDS['Resolve-AbyssRewardBranch'] = ''
$PURE_5B1_ASSIGNS['Resolve-AbyssRewardBranch'] = ''
$PURE_5B1_INCREMENTS = @('PlusPlus', 'MinusMinus', 'PostfixPlusPlus', 'PostfixMinusMinus')
$PURE_5B1_FORMAT = '명령 [{0}] · 이름 없는·호출 연산자 [{1}] · 접두 변수 [{2}] · 바깥 변수 [{3}] · 대입 [{4}] · 메서드 [{5}] · 리디렉션 [{6}] · 캐스트 밖 [{7}] · 타입 리터럴 [{8}] · exit·throw·try·trap·break·continue {9} · switch -File {10}'
foreach ($pureEntry in $PURE_5B1_COMMANDS.GetEnumerator()) {
    $pureNode5b1 = Get-WorkerFunction $pureEntry.Key
    $pureCommands = @($pureNode5b1.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Sort-Object -Unique) -join ','
    # 이름 없는 명령(& (식) · . { } - 이름이 $null 이라 위 집합에서 빠짐) · 호출 연산자 붙은 명령(& 'Name')
    $pureDynamic = @($pureNode5b1.FindAll({ param($candidate) ($candidate -is [CommandAst]) -and ([string]::IsNullOrEmpty($candidate.GetCommandName()) -or ($candidate.InvocationOperator -ne [TokenKind]::Unknown)) }, $true) |
            ForEach-Object { Get-NodeCode $_ }) -join ','
    # 접두 변수 - 범위(script·global·local·private·using)·드라이브(env·variable·function·경로) 접두가 붙은 모든 변수 ($variable:x 는 부른 쪽 변수를 읽음)
    $pureQualified = @($pureNode5b1.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and (-not $candidate.VariablePath.IsUnqualified) }, $true) |
            ForEach-Object { $_.VariablePath.UserPath } | Sort-Object -Unique) -join ','
    # 바깥 변수 - 접두 없는 이름은 동적 범위로 스크립트·부른 쪽 변수를 읽습니다(행의 모의 문맥에는 그 이름이 없어 행이 빈 참). 매개변수 · 허용 대입 · $null/$true/$false 밖은 0
    $pureKnown5b1 = @{ 'null' = $true; 'true' = $true; 'false' = $true }
    foreach ($pureParameter in $pureNode5b1.FindAll({ param($candidate) $candidate -is [ParameterAst] }, $true)) { $pureKnown5b1[$pureParameter.Name.VariablePath.UserPath] = $true }
    foreach ($pureAllowed in @(([string]$PURE_5B1_ASSIGNS[$pureEntry.Key]) -split ',' | Where-Object { $_ })) { $pureKnown5b1[$pureAllowed.TrimStart('$')] = $true }
    $pureOuter = @($pureNode5b1.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and $candidate.VariablePath.IsUnqualified }, $true) |
            Where-Object { -not $pureKnown5b1.ContainsKey($_.VariablePath.UserPath) } | ForEach-Object { $_.VariablePath.UserPath } | Sort-Object -Unique) -join ','
    # 대입·증감 - 접두 없는 변수에 '=' 한 것만 '$이름', 나머지(멤버·인덱스·정적 멤버·형 붙은 좌변 · 복합 대입 · ++ --)는 글자 그대로 (허용 목록에 들지 않음)
    $pureAssigns = @($pureNode5b1.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -or (($candidate -is [UnaryExpressionAst]) -and ($PURE_5B1_INCREMENTS -contains [string]$candidate.TokenKind)) }, $true) |
            Sort-Object { $_.Extent.StartOffset } | ForEach-Object {
                if (($_ -is [AssignmentStatementAst]) -and ($_.Left -is [VariableExpressionAst]) -and $_.Left.VariablePath.IsUnqualified -and ($_.Operator -eq [TokenKind]::Equals)) { '$' + $_.Left.VariablePath.UserPath }
                elseif ($_ -is [AssignmentStatementAst]) { (Get-NodeCode $_.Left) + ' ' + [TokenTraits]::Text($_.Operator) }
                else { Get-NodeCode $_ }
            }) -join ','
    $pureMethods = @($pureNode5b1.FindAll({ param($candidate) $candidate -is [InvokeMemberExpressionAst] }, $true) | ForEach-Object { Get-NodeCode $_ }) -join ','
    $pureRedirections = @($pureNode5b1.FindAll({ param($candidate) $candidate -is [RedirectionAst] }, $true) | ForEach-Object { Get-NodeCode $_ }) -join ','
    $pureCasts = @($pureNode5b1.FindAll({ param($candidate) $candidate -is [ConvertExpressionAst] }, $true) | ForEach-Object { Get-ResolvedTypeName $_.Type.TypeName } |
            Where-Object { $_ -cne 'System.String' } | Sort-Object -Unique) -join ','
    $pureTypes = @($pureNode5b1.FindAll({ param($candidate) $candidate -is [TypeExpressionAst] }, $true) | ForEach-Object { Get-NodeCode $_ }) -join ','
    $pureExits = @($pureNode5b1.FindAll({ param($candidate) ($candidate -is [ExitStatementAst]) -or ($candidate -is [ThrowStatementAst]) -or ($candidate -is [TryStatementAst]) -or
                ($candidate -is [TrapStatementAst]) -or ($candidate -is [BreakStatementAst]) -or ($candidate -is [ContinueStatementAst]) }, $true)).Count
    # switch -File - 명령·메서드·캐스트·타입 리터럴 없이 파일을 읽습니다 (switch 문의 Flags 에 File)
    $pureSwitchFiles = @($pureNode5b1.FindAll({ param($candidate) ($candidate -is [SwitchStatementAst]) -and (($candidate.Flags -band [SwitchFlags]::File) -eq [SwitchFlags]::File) }, $true)).Count
    Check-Equal ("P5b-1 $($pureEntry.Key) 순수 - 명령 = [$($pureEntry.Value)] · 대입 = [$($PURE_5B1_ASSIGNS[$pureEntry.Key])] · 이름 없는·호출 연산자 · 접두 변수 · 바깥 변수 · " +
            "메서드 · 리디렉션 · [string] 밖 캐스트 · 타입 리터럴 · exit·throw·try·trap·break·continue · switch -File 0") `
        ($PURE_5B1_FORMAT -f $pureCommands, $pureDynamic, $pureQualified, $pureOuter, $pureAssigns, $pureMethods, $pureRedirections, $pureCasts, $pureTypes, $pureExits, $pureSwitchFiles) `
        ($PURE_5B1_FORMAT -f $pureEntry.Value, '', '', '', $PURE_5B1_ASSIGNS[$pureEntry.Key], '', '', '', '', 0, 0)
}
$NEW_5B1_NAMES = @('Test-AbyssRetryRoute', 'Resolve-AbyssRewardDecision', 'Resolve-AbyssOtherWaitScreen', 'Update-AbyssRetryTimeVerdict', 'Get-AbyssUntilTime')
# P5b-2 자리 수 (구현 명세 ⑤b3 3.4 · ⑤b4 3.4 · ⑤b5 3.4 · ⑤c 3.2 (다)) - 새 함수 다섯의 워커 안 호출과 그 자리(소스 차례 · 자리 '' = 본류 - 함수 밖): 분류 = '다른 던전 가기' 대기 1 ·
#   재판단 = '다시 하기' 클릭 루프 1 + 재개 끝 재평가 결정 인자 1(⑤c 5c-3) + 본류 보상 결정 인자 1 · 경로 술어 = 본류 1 · 보상 결정 = 재개 끝 재평가 1(⑤c 5c-3) + 본류 보상 화면 꼬리 1 ·
#   지정 시각 읽기 = 본류 자리7 1(⑤b5 W1 - 명세 3.4 표의 P5b-2 칸은 셋만 적었지만 읽기도 이 단계에서 0 → 1 이 됩니다 - 정적 P5e-4 가 그 자리를 따로 고정)
$P5B2_EXPECTED_SITES = [ordered]@{ 'Test-AbyssRetryRoute' = '1[]'; 'Resolve-AbyssRewardDecision' = '2[Complete-AbyssResumeWait,]'; 'Resolve-AbyssOtherWaitScreen' = '1[Wait-AbyssOtherSelection]';
    'Update-AbyssRetryTimeVerdict' = '3[Invoke-AbyssRetryClick,Complete-AbyssResumeWait,]'; 'Get-AbyssUntilTime' = '1[]' }
$p5b2Sites = @(foreach ($newName5b1 in $NEW_5B1_NAMES) { $siteNodes5b1 = @(Get-CommandNodes -Node $workerAst -Name $newName5b1); '{0}={1}[{2}]' -f $newName5b1, $siteNodes5b1.Count, ((@($siteNodes5b1 | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ',') }) -join ' · '
$p5b2Expected = @(foreach ($newName5b1 in $NEW_5B1_NAMES) { '{0}={1}' -f $newName5b1, $P5B2_EXPECTED_SITES[$newName5b1] }) -join ' · '
Check-Equal 'P5b-2 자리 수 - 새 함수 다섯의 워커 안 호출 = 분류 1(Wait-AbyssOtherSelection - ⑤b3) · 재판단 3(Invoke-AbyssRetryClick - ⑤b4 · Complete-AbyssResumeWait - ⑤c 5c-3 · 본류 - ⑤b5) · 보상 결정 2(재개 끝 - ⑤c 5c-3 · 본류) · 경로 술어 · 지정 시각 읽기 본류 1씩(⑤b5)' $p5b2Sites $p5b2Expected
[string[]]$verdictOwners5b1 = @(Get-CommandNodes -Node $workerAst -Name 'Get-DgTimeVerdict' | ForEach-Object { Get-EnclosingFunctionName $_ })
[Array]::Sort($verdictOwners5b1, [StringComparer]::Ordinal)
Check-Equal 'P5b-3 (R3 S1) Get-DgTimeVerdict 호출 소유자 = 던전 · 재판단 함수 각 1' ($verdictOwners5b1 -join ',') 'Invoke-NormalDungeonCycle,Update-AbyssRetryTimeVerdict'
$updateNode5b1 = Get-WorkerFunction 'Update-AbyssRetryTimeVerdict'
$updateBody5b1 = @($updateNode5b1.Body.EndBlock.Statements | ForEach-Object { Get-NodeCode $_ }) -join ' ; '
$updateEnv5b1 = @($updateNode5b1.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.DriveName -eq 'env') }, $true)).Count
$verdictAssignOwners5b1 = @($workerAst.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'script:abyssRetryTimeVerdict') }, $true) | ForEach-Object { Get-EnclosingFunctionName $_ }) -join ','
# (⑤b5 3.4 · ⑤c 2.10) 판단값 대입 = 이 함수 안 1 + 승계 함수 Set-AbyssResumeCommit 1(이 함수 바로 뒤) + 본류 보상 화면 꼬리 첫 문장 ⓪ 1(소스 차례 - 자리 '' = 본류)
Check-Equal 'P5b-4 (R3 S3 · S9) 재판단 함수 본문 = 두 문장 원문 · env 0 · 워커의 판단값 대입 = 이 함수 안 1 + 승계 함수 1(⑤c 2.10) + ⓪ 1(본류 꼬리 첫 문장 - ⑤b5)' `
    ('{0} · env {1} · 대입 [{2}]' -f $updateBody5b1, $updateEnv5b1, $verdictAssignOwners5b1) '$script:abyssRetryTimeVerdict = Get-DgTimeVerdict -UntilTime $script:abyssUntil -Now (Get-Date) ; return $script:abyssRetryTimeVerdict · env 0 · 대입 [Update-AbyssRetryTimeVerdict,Set-AbyssResumeCommit,]'
$untilUses5b1 = @($workerAst.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -eq 'script:abyssUntil') }, $true))
$untilOutside5b1 = @($untilUses5b1 | Where-Object {
        $untilUse = $_
        $isUntilArgument = ($untilUse.Parent -is [CommandAst]) -and ((Get-EnclosingFunctionName $untilUse) -eq 'Update-AbyssRetryTimeVerdict') -and
            (@($untilUse.Parent.CommandElements | Where-Object { ($_ -is [CommandParameterAst]) -and ($_.ParameterName -eq 'UntilTime') }).Count -eq 1)
        $isReadAssign = ($untilUse.Parent -is [AssignmentStatementAst]) -and [object]::ReferenceEquals($untilUse.Parent.Left, $untilUse) -and ((Get-NodeCode $untilUse.Parent.Right) -ceq 'Get-AbyssUntilTime')
        $isClockFormat = ($untilUse.Parent -is [InvokeMemberExpressionAst]) -and ($untilUse.Parent.Member.Extent.Text -eq 'ToString') -and ((@($untilUse.Parent.Arguments | ForEach-Object { $_.Extent.Text }) -join ',') -eq "'HH:mm'")
        # 승계 함수 안의 해석 성공 판정 - '$null -ne $script:abyssUntil' 이항식 꼴(구현 명세 ⑤c 2.10 · 3.2 (가) - 개수는 보지 않음, 승계 함수 본문은 5c-2 의 5C-S1)
        $isCommitTest = ($untilUse.Parent -is [BinaryExpressionAst]) -and ((Get-EnclosingFunctionName $untilUse) -eq 'Set-AbyssResumeCommit') -and
            ($untilUse.Parent.Operator -eq [TokenKind]::Ine) -and ((Get-NodeCode $untilUse.Parent.Left) -ceq '$null') -and [object]::ReferenceEquals($untilUse.Parent.Right, $untilUse)
        -not ($isUntilArgument -or $isReadAssign -or $isClockFormat -or $isCommitTest)
    }).Count
Check-Equal 'P5b-5 (R3 S5 - 지금 몫) $script:abyssUntil 사용 = 허용 꼴만 (재판단 -UntilTime · 읽기 대입 · HH:mm 서식 · 승계 함수의 $null -ne 이항식 - ⑤c 2.10)' ('사용 {0} · 허용 밖 {1}' -f $untilUses5b1.Count, $untilOutside5b1) ('사용 {0} · 허용 밖 0' -f $untilUses5b1.Count)
function Get-ReturnLiteralOrder {
    # 함수 안 return 문마다 마지막 문자열 상수(없으면 '(값)') - 순위 문장의 차례 (R6-P12 · 결정 사유 순서)
    param($FunctionNode)
    return (@($FunctionNode.Body.FindAll({ param($candidate) $candidate -is [ReturnStatementAst] }, $true) | Sort-Object { $_.Extent.StartOffset } | ForEach-Object {
                $returnStrings = @($_.FindAll({ param($candidate) $candidate -is [StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Value })
                if ($returnStrings.Count -eq 0) { '(값)' } else { $returnStrings[-1] }
            }) -join ',')
}
Check-Equal 'P5b-6 (R6-P12) 분류 순서 panel < selection < reward3 < inside < field < menu < unknown' (Get-ReturnLiteralOrder (Get-WorkerFunction 'Resolve-AbyssOtherWaitScreen')) 'panel,selection,reward3,inside,field,menu,unknown'
Check-Equal 'P5b-7 결정 사유 순서 (안전 중지 < 마무리 < 마지막 판 < 시간 < 비커스텀 retry < 손상 < 미정 < 입장 방식 다름 < 경계 < 던전·난이도 다름 < 소유자 빈 값·해석 실패 < retry - 구현 명세 ⑤b6 1.3)' `
    (Get-ReturnLiteralOrder (Get-WorkerFunction 'Resolve-AbyssRewardDecision')) 'safe-stop,finish-only,last-run,time,,next-invalid,next-unknown,entry-change,boundary,item-change,next-owner-empty,'
# P5b-8 - 분류 호출 인자 계약 (명세 리뷰 1 P2-1 · 확인 라운드 1): 워커 안 Resolve-AbyssOtherWaitScreen 호출마다 -SelectionVisible · -HudVisible · -InDungeonQuest 를
#   이름 그대로 명시하고 값은 상수가 아닙니다. 셋 다 [bool] 이라 빠뜨리거나 이름이 틀리면 조용히 거짓입니다 - HUD 를 빠뜨리면 실제 HUD 가 보여도 3버튼 문구만으로
#   reward3(클릭 게이트가 열림), 추적기를 빠뜨리면 던전 안이 field(오클릭 의심 감지를 놓침). 값은 같은 회전 판독값을 담은 변수·식이어야 하고, 상수(값의 부분 트리에
#   변수 - $true·$false·$null 밖 - 도 명령도 없음: $false · 0 · 'x' · ($false) · (-not $true) · [bool]0 꼴)는 문법상 명시여도 계약 충족이 아닙니다 - 선택 화면이 보이는
#   회전에 상수 $false 를 넘기면 reward3 입니다. 위치 인자·splat·줄임 이름은 명시로 치지 않습니다. 5b-1 은 호출 0 이라 빈 통과 - 5b-3·5b-4 가 호출을 더하면(P5b-2 자리 수
#   갱신) 그 호출 전부에 걸립니다
$OTHER_WAIT_ARGUMENTS_5B1 = @('SelectionVisible', 'HudVisible', 'InDungeonQuest')
function Test-ConstantArgument5b1 {
    # 값 노드의 부분 트리(노드 자신 포함)에 변수($true·$false·$null 밖)도 명령도 없으면 상수
    param($Node)
    return (@($Node.FindAll({ param($candidate) (($candidate -is [VariableExpressionAst]) -and (@('true', 'false', 'null') -notcontains $candidate.VariablePath.UserPath)) -or ($candidate -is [CommandAst]) }, $true)).Count -eq 0)
}
$otherWaitCalls5b1 = @(Get-CommandNodes -Node $workerAst -Name 'Resolve-AbyssOtherWaitScreen')
$otherWaitLacks5b1 = New-Object System.Collections.Generic.List[string]
$otherWaitConstants5b1 = New-Object System.Collections.Generic.List[string]
foreach ($otherWaitCall5b1 in $otherWaitCalls5b1) {
    $otherWaitElements = @($otherWaitCall5b1.CommandElements)
    $otherWaitLack = New-Object System.Collections.Generic.List[string]
    foreach ($otherWaitName in $OTHER_WAIT_ARGUMENTS_5B1) {
        # 이름 그대로(대소문자 무관)의 매개변수 원소 - 값은 콜론 꼴이면 그 인자, 띄어 쓴 꼴이면 다음 원소
        $otherWaitAt = -1
        for ($otherWaitIndex = 1; $otherWaitIndex -lt $otherWaitElements.Count; $otherWaitIndex++) {
            if (($otherWaitElements[$otherWaitIndex] -is [CommandParameterAst]) -and ($otherWaitElements[$otherWaitIndex].ParameterName -eq $otherWaitName)) { $otherWaitAt = $otherWaitIndex; break }
        }
        if ($otherWaitAt -lt 0) { $otherWaitLack.Add($otherWaitName); continue }
        $otherWaitValue = $otherWaitElements[$otherWaitAt].Argument
        if (($null -eq $otherWaitValue) -and (($otherWaitAt + 1) -lt $otherWaitElements.Count) -and -not ($otherWaitElements[$otherWaitAt + 1] -is [CommandParameterAst])) { $otherWaitValue = $otherWaitElements[$otherWaitAt + 1] }
        if ($null -eq $otherWaitValue) { $otherWaitConstants5b1.Add(('{0}행:{1}=(값 없음)' -f $otherWaitCall5b1.Extent.StartLineNumber, $otherWaitName)) }
        elseif (Test-ConstantArgument5b1 $otherWaitValue) { $otherWaitConstants5b1.Add(('{0}행:{1}={2}' -f $otherWaitCall5b1.Extent.StartLineNumber, $otherWaitName, (Get-NodeCode $otherWaitValue))) }
    }
    if ($otherWaitLack.Count -gt 0) { $otherWaitLacks5b1.Add(('{0}행:{1}' -f $otherWaitCall5b1.Extent.StartLineNumber, ($otherWaitLack -join '+'))) }
}
Check-Equal ('P5b-8 (리뷰 1 P2-1 · 확인 라운드 1) 분류 호출마다 -SelectionVisible · -HudVisible · -InDungeonQuest 이름 그대로 명시 · 값은 상수 아님 - 빠진 호출 0 · 상수 0 ' +
        '(위치 인자·splat·줄임 이름은 명시 아님 · 5b-1 은 호출 0)') `
    ('호출 {0} · 빠짐 [{1}] · 상수 [{2}]' -f $otherWaitCalls5b1.Count, ($otherWaitLacks5b1 -join ','), ($otherWaitConstants5b1 -join ',')) ('호출 {0} · 빠짐 [] · 상수 []' -f $otherWaitCalls5b1.Count)
# P5b-9 (구현 명세 ⑤b6 3.2 · 1.3) - 결정 return 의 Action 차례 (Reason 차례는 P5b-7). 기대 = 계약 열거값 · 차례 = 소스 캡처(return 문마다 해시 리터럴의 Action 상수)
function Get-ReturnHashOrder {
    # 함수 안 return 문마다 해시 리터럴(하나)의 그 키 문자열 상수 - 해시가 하나가 아니거나 값이 문자열 상수가 아니면 '(값)'
    param($FunctionNode, [string]$Key)
    return (@($FunctionNode.Body.FindAll({ param($candidate) $candidate -is [ReturnStatementAst] }, $true) | Sort-Object { $_.Extent.StartOffset } | ForEach-Object {
                $returnTables = @($_.FindAll({ param($candidate) $candidate -is [HashtableAst] }, $true))
                $returnValue = $(if ($returnTables.Count -eq 1) { Get-HashtableStringValue -Table $returnTables[0] -Key $Key } else { $null })
                if ($null -eq $returnValue) { '(값)' } else { $returnValue }
            }) -join ',')
}
Check-Equal 'P5b-9 결정 return 의 Action 차례 (① 안전 중지 · 마무리 · 마지막 판 · 시간 exit < ② 비커스텀 retry < ③ 손상 · ④ 미정 · ⑤ 입장 방식 다름 exit < ⑥ 경계 · ⑦ 던전·난이도 다름 · ⑧ 소유자 other < ⑨ retry)' `
    (Get-ReturnHashOrder (Get-WorkerFunction 'Resolve-AbyssRewardDecision') 'Action') 'exit,exit,exit,exit,retry,exit,exit,exit,other,other,other,retry'
# P5b-10 (구현 명세 ⑤b6 3.2 · 1.13) - 결정 매개변수 = 5b-5 열 개 그대로(차례 그대로) + NextEntryUnknown(열한 개) · 새 매개변수는 [bool] · 기본값 없음(규칙 3 - [ref] 아님 · 부르는 쪽이 bool 값을 넘김)
$decisionParams5b6 = @((Get-WorkerFunction 'Resolve-AbyssRewardDecision').Body.ParamBlock.Parameters)
$unknownParams5b6 = @($decisionParams5b6 | Where-Object { $_.Name.VariablePath.UserPath -ceq 'NextEntryUnknown' })
$unknownShape5b6 = "(NextEntryUnknown $($unknownParams5b6.Count)개)"
if ($unknownParams5b6.Count -eq 1) {
    $unknownTypes5b6 = (@($unknownParams5b6[0].Attributes | Where-Object { $_ -is [TypeConstraintAst] } | ForEach-Object { Get-ResolvedTypeName $_.TypeName })) -join ','
    $unknownShape5b6 = '형 [{0}] · 기본값 {1}' -f $unknownTypes5b6, $(if ($null -eq $unknownParams5b6[0].DefaultValue) { '없음' } else { Get-NodeCode $unknownParams5b6[0].DefaultValue })
}
Check-Equal 'P5b-10 결정 매개변수 = 5b-5 열 개 + NextEntryUnknown(열한 개 · 차례) · 새 매개변수 형 · 기본값' `
    ('{0} · {1}' -f ((@($decisionParams5b6 | ForEach-Object { $_.Name.VariablePath.UserPath })) -join ','), $unknownShape5b6) `
    'SafeStopRequested,FinishOnly,LastRun,TimeVerdict,CustomMode,NextGiven,NextItem,CurrentItem,NextBoundary,NextOwnerGiven,NextEntryUnknown · 형 [System.Boolean] · 기본값 없음'

# ── §6c ⑤b2 기록 확인 순수부 - 결정 × 완료 마커 × 클리어 기록 → 갈래(RB) · 정적(P5c-2~5) (구현 명세 ⑤b2 1.4·3.2 · ⑤b6 1.4 - 비교는 -ceq) ──
# 원문 그대로 올립니다(사본 재구현 금지). P5c-1(순수)은 §6b P5b-1 표의 한 줄입니다 - ⑤b1 P5b-1 과 같은 열한 칸 식을 한 곳에서 돌려 두 단계의 순수성 계약이
# 함께 움직이게 합니다(명세 리뷰 2 P2)
try {
    foreach ($definition5b2 in @(Get-SourceFunctionDefinitions -Path $workerPath -Names @('Resolve-AbyssRewardBranch'))) { Invoke-Expression ([string]$definition5b2) }
} catch {
    "FAIL 준비: ⑤b2 기록 확인 함수를 워커에서 추출하지 못했습니다 ($($_.Exception.Message))"
    exit 1
}
# RB - 열: 이름 · 결정 · 마커 · 클리어 기록(changed) · 기대 갈래 (설계 v10 2.1(1) ①② · B0 · 6.1 기록 시점 표 · v11 R6 1.1 B0 · 2.7 · 범위 기-18)
$BRANCH_ROWS = @(
    @('RB1', 'retry', $true, $true, 'retry'),            # dev:651 B0
    @('RB2', 'retry', $true, $false, 'legacy-exit'),     # 기록 실패(사용 중·손상·기록 실패·소유자 해석 실패) → 폴백 ② 옛 나가기 - 결정 retry 한정
    @('RB3', 'retry', $false, $true, 'other'),           # 마커 거짓 - retry 금지 → '다른 던전 가기'(기-18 · 명세 리뷰 1 A-1 (가))
    @('RB4', 'retry', $false, $false, 'other'),          # 마커가 기록보다 앞
    @('RB5', 'other', $true, $true, 'other'),
    @('RB6', 'other', $true, $false, 'other'),           # other 의 기록 실패는 그대로 other(R6 2.7 수용)
    @('RB7', 'other', $false, $true, 'other'),
    @('RB8', 'other', $false, $false, 'other'),
    @('RB9', '', $true, $true, 'other'),                  # 정의역 밖 결정 - retry 가 아니면 other
    @('RB10', 'exit', $true, $true, 'exit'),              # 구현 명세 ⑤b6 1.4 - 결정 exit(멈출 때 · 다음 판 입장 방식이 다르거나 모를 때)는 마커 · 기록 결과와 무관하게 옛 나가기(0순위)
    @('RB11', 'exit', $true, $false, 'exit'),
    @('RB12', 'exit', $false, $true, 'exit'),
    @('RB13', 'exit', $false, $false, 'exit'))
foreach ($branchRow in $BRANCH_ROWS) {
    $branchOut5b2 = @(Resolve-AbyssRewardBranch -Action $branchRow[1] -MarkerOk $branchRow[2] -ClearedOk $branchRow[3])
    Check-Equal ("{0} 결정 '{1}' · 마커 {2} · 클리어 기록 {3} → {4} (출력 1개)" -f $branchRow) ('{0}|{1}' -f $branchOut5b2.Count, ($branchOut5b2 -join ',')) ('1|' + $branchRow[4])
}
Check-Equal 'P5c-2 기록 확인 순서 (exit < retry 아님 < 마커 < 클리어 기록 < retry - 구현 명세 ⑤b6 1.4)' (Get-ReturnLiteralOrder (Get-WorkerFunction 'Resolve-AbyssRewardBranch')) 'exit,other,other,legacy-exit,retry'
$NEW_5B2_NAMES = @('Resolve-AbyssRewardBranch', 'Set-AbyssJournalRetryAttempt', 'Set-AbyssJournalRetryClicked', 'Set-AbyssJournalReentered')
# P5c-3 자리 수 (구현 명세 ⑤b4 3.4 · ⑤b5 3.4 - P5b-2 꼴) - 기록 확인 = 본류 보상 화면 꼬리 1(자리 '' = 본류) · 단계 기록 셋 = retry-attempt · retry-clicked 는 '다시 하기' 클릭 루프 1 ·
#   reentered 는 재입장 완료 끝 1
$p5c3Sites = @(foreach ($newName5b2 in $NEW_5B2_NAMES) { $siteNodes5b2 = @(Get-CommandNodes -Node $workerAst -Name $newName5b2); '{0}={1}[{2}]' -f $newName5b2, $siteNodes5b2.Count, ((@($siteNodes5b2 | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ',') }) -join ' · '
Check-Equal 'P5c-3 자리 수 - 기록 확인 본류 1(⑤b5) · 단계 기록 셋의 워커 안 호출과 자리 (retry-attempt · retry-clicked = 클릭 루프 · reentered = 재입장 완료 끝)' $p5c3Sites `
    'Resolve-AbyssRewardBranch=1[] · Set-AbyssJournalRetryAttempt=1[Invoke-AbyssRetryClick] · Set-AbyssJournalRetryClicked=1[Invoke-AbyssRetryClick] · Set-AbyssJournalReentered=1[Complete-AbyssInsideHandoff]'
# P5c-4 (⑤b5 3.4 · 명세 B-2 '한 자리') - 클리어 기록 3곳 = own 시작 분기 둘([void] · 인자 0 - 소스 앞쪽) + 본류 보상 화면 1(결정 · 다음 판 owner 를 실은 호출의 결과를 $clearedRecord 로
#   받음). 문장 = 호출을 품은 첫 블록 직속 문장(파이프라인 또는 대입)
$clearedShapes5b2 = @(Get-CommandNodes -Node $workerAst -Name 'Add-AbyssJournalClearedEntry' | ForEach-Object {
        $clearedStatement = $_.Parent
        while (($null -ne $clearedStatement) -and -not ((($clearedStatement -is [PipelineAst]) -or ($clearedStatement -is [AssignmentStatementAst])) -and ($clearedStatement.Parent -is [StatementBlockAst]))) { $clearedStatement = $clearedStatement.Parent }
        if ($null -eq $clearedStatement) { '(문장 없음)' } else { Get-NodeCode $clearedStatement }
    })
Check-Equal 'P5c-4 클리어 기록 호출 3곳 = own 시작 분기 둘 [void](Add-AbyssJournalClearedEntry) 인자 0 + 본류 1 $clearedRecord = … -Decision $clearedDecision -NextOwner $nextOwnerValue (⑤b5)' ($clearedShapes5b2 -join ' / ') `
    ('[void](Add-AbyssJournalClearedEntry) / [void](Add-AbyssJournalClearedEntry) / $clearedRecord = Add-AbyssJournalClearedEntry -Decision $clearedDecision -NextOwner $nextOwnerValue')
# P5c-5 (구현 명세 ⑤b6 3.2 · 1.4) - 기록 확인 첫 문장 = 결정 exit 0순위(멈출 때 · 다음 판 입장 방식이 다르거나 모를 때는 마커 · 클리어 기록 결과와 무관하게 옛 나가기)
$branchFirst5b6 = @((Get-WorkerFunction 'Resolve-AbyssRewardBranch').Body.EndBlock.Statements) | Select-Object -First 1
Check-Equal "P5c-5 기록 확인 첫 문장 = if (`$Action -eq 'exit') { return 'exit' }" (Get-NodeCode $branchFirst5b6) "if (`$Action -eq 'exit') { return 'exit' }"

# ── §7 WA-L · N4-L · FC-L - 대기 루프 행동 진리표 (명세 3.4 · 5b-8 3.2 - 픽스처 공통: L = 30(행이 적은 값 우선) · Q·W·한도는 캡처값 · 시각표 'X@a' · 실패·조작 창 [a, b)) ──────────
# WA-L1 - 준비 패널 → 로딩 → 던전 안 2연속 (S2 1 · 로딩 ≥ 1 · 필드 0 · 끊김 0 · 패널 관측 참)
Reset-ReentryRow; Set-ScreenPlan @('Rd', 0, 'U', 3, 'I', 9)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$s2 = Get-S2Facts $row
Check-True 'WA-L1 Rd@0 · U@3~8 · I@9 · I@9.7 → I 구간 둘째 유효 회전에 entered · S2 1(로딩 ≥ 1 · 필드 0 · 끊김 0) · PanelSeen 참' `
    (($row.Result -ceq 'entered') -and ($row.Count -eq 1) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 2)) -and ($row.PanelSeen -eq $true) -and
    ($s2.Count -eq 1) -and $s2.Matched -and ($s2.U -ge 1) -and ($s2.F -eq 0) -and ($s2.B -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'WA-L1' $row

# WA-L2 - 던전 안 표본 뒤 동결(캡처 실패 [0.5,5)) → 실패 창 뒤 첫 판독 회전에서 entered (동결 회전은 연속 유지 - J27)
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-FailWindow 0.5 5
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True 'WA-L2 I 지속 + 캡처 실패 [0.5,5) → 실패 창 뒤 첫 판독 회전에 entered · 안전 확인 ≥ 1 · 탐침 ≥ 1' `
    (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -NotBefore 5) 1)) -and ($row.SafeStops -ge 1) -and ($row.Probes -ge 1)) (Format-RowDetail $row)
Check-RowCommon 'WA-L2' $row

# WA-L3 - 조작 양보가 연속을 0 으로 · 양보 뒤 둘째 I 에서 entered · S2 끊김 1(② 게이트의 끊김 증분)
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-ActiveWindow 0.5 3
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$s2 = Get-S2Facts $row
Check-True 'WA-L3 I@0 · 조작 [0.5,3) · I · I → 조작 창 뒤 둘째 유효 회전에 entered · S2 1 · 관측 끊김 1' `
    (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean -NotBefore 3) 2)) -and ($s2.Count -eq 1) -and $s2.Matched -and ($s2.B -eq 1)) (Format-RowDetail $row)
Check-RowCommon 'WA-L3' $row

# WA-L4 - 스윕 참 1회전('sent' Gap 1)이 연속을 0 으로 · 스윕 뒤 둘째 I 에서 entered · S2 끊김 1(④ 스윕 참의 끊김 증분)
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'sent' -Gap 1 -Count 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$s2 = Get-S2Facts $row
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
Check-True "WA-L4 I@0 · 스윕 참 1회전('sent' Gap 1 @[0.5,1)) · I · I → 스윕 뒤 둘째 유효 회전에 entered · S2 1 · 관측 끊김 1" `
    (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean -After $firedTime) 2)) -and ($s2.Count -eq 1) -and $s2.Matched -and ($s2.B -eq 1)) (Format-RowDetail $row)
Check-RowCommon 'WA-L4' $row

# WA-L5 - 스윕 거짓 · 스윕 안 커서 대피 양보 +100ms('yield-false' Gap 0.1)가 ⑥ 에서 연속을 0 으로 → 셋째 유효 회전에 entered
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'yield-false' -Gap 0.1 -Count 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True "WA-L5 I@0 · 스윕 거짓 + 커서 대피 양보('yield-false' Gap 0.1) · I · I → 셋째 유효 회전(그 회전 표본이 새 연속 1)에 entered" `
    (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'WA-L5' $row

# WA-L6 - 판독 도중 실패 → 같은 회전 뒤 판독 복구(복구 회전은 연속 유지) → 둘째 유효 회전에 entered
Reset-ReentryRow; Set-ScreenPlan @('I', 0); $script:failHook = $HOOK_PROMPT_FAIL_AT_0_7
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True 'WA-L6 I@0 · 둘째 회전 하단만 실패(같은 회전 복구) · I → 복구 회전 다음 유효 회전(둘째 유효 회전)에 entered' `
    (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 2)) -and (@(Get-RecordTimes $row -Failed).Count -eq 1)) (Format-RowDetail $row)
Check-RowCommon 'WA-L6' $row

# WA-L7 - 재매칭 패널 지속 → 조정 마감 L 에 timeout · LastKind 'matching' · PanelSeen 참
Reset-ReentryRow; Set-ScreenPlan @('M', 0)
$rowLimit = 30
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L7 M 지속 → L ≤ T < L + 회전 박자에 timeout · LastKind matching · PanelSeen 참' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'matching') -and ($row.PanelSeen -eq $true) -and (Test-DeadlineWindow $row $rowLimit)) (Format-RowDetail $row)
Check-RowCommon 'WA-L7' $row

# WA-L8 - M 지속 + 조작 20초(@L−5~L+15) → 마감이 양보만큼 늦음(D = L + 양보) · 양보 1
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; Add-ActiveWindow ($rowLimit - 5) ($rowLimit + 15)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L8 M 지속 + 조작 [L−5, L+15) → D = L + 양보 기록 · D ≤ T < D + 박자에 timeout · 양보 1(양보 중 판정 0)' `
    (($row.Result -ceq 'timeout') -and ($row.Yields -eq 1) -and (Test-DeadlineWindow $row ($rowLimit + $row.YieldTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L8' $row

# WA-L9 - M 지속 + 캡처 실패 60초 [10,70) / 같은 실패 구간 안 조작 [20,40) 겹침 → D = L + 실패 합 · 겹친 조작은 더하지 않음(양보 0)
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; Add-FailWindow 10 70
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L9 M 지속 + 캡처 실패 [10,70) → D = L + 실패 합 · D ≤ T < D + 박자에 timeout' `
    (($row.Result -ceq 'timeout') -and ($row.FailTotalMs -gt 0) -and (Test-DeadlineWindow $row ($rowLimit + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L9' $row
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; Add-FailWindow 10 70; Add-ActiveWindow 20 40
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L9 둘째 판 - 실패 구간 안 조작 [20,40) 겹침 → 같은 D(L + 실패 합) · 양보 0' `
    (($row.Result -ceq 'timeout') -and ($row.Yields -eq 0) -and (Test-DeadlineWindow $row ($rowLimit + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L9 둘째 판' $row

# WA-L10 - M 지속 + 20초마다 실패 회전 1(3초) 끝없이 → timeout @(L + 실패 합) · VTIMEOUT 0 (J26 - 몇 번만 넣으면 동결 회전 시계 재설정 변이가 산다)
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; Set-FailPeriodic -Start 20 -Period 20 -Length 3
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L10 M 지속 + 실패 [20k, 20k+3) k = 1.. 끝없이 → D = L + 실패 합 · D ≤ T < D + 박자에 timeout · VTIMEOUT 0' `
    (($row.Result -ceq 'timeout') -and ($row.Error -ceq '') -and (Test-DeadlineWindow $row ($rowLimit + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L10' $row

# WA-L11 - 매 회전 판독 실패 → 다음 회전 탐침 복구(교대 @0.5~) → 탐침 복구 뒤 회전이 마감 → timeout 유한
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; Set-CaptureAlternate -From 0.5 -Mode 'normal'
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
$probeOkTimes = @($row.Events | Where-Object { ($_.Kind -eq 'probe') -and $_.Ok } | ForEach-Object { [double]$_.T })
Check-True 'WA-L11 교대 @0.5~ → 탐침 복구 뒤 회전(탐침 성공 시각)에 timeout · D = L + 실패 합 · D ≤ T < D + 박자 · 유한' `
    (($row.Result -ceq 'timeout') -and ($row.Error -ceq '') -and (@($probeOkTimes | Where-Object { Test-SameTime $_ $row.T }).Count -ge 1) -and (Test-DeadlineWindow $row ($rowLimit + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L11' $row

# WA-L12 - 매 회전 앞 판독 실패 → 같은 회전 뒤 판독 복구(같은 회전 복구 @0.5~) → 복구 회전이 마감 → timeout 유한
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; Set-CaptureAlternate -From 0.5 -Mode 'sameTurn'
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L12 같은 회전 복구 @0.5~ → 복구 회전(실패 있는 판독 회전)에 timeout · D = L + 실패 합 · D ≤ T < D + 박자 · 유한' `
    (($row.Result -ceq 'timeout') -and ($row.Error -ceq '') -and (@(Get-RecordTimes $row -Failed | Where-Object { Test-SameTime $_ $row.T }).Count -ge 1) -and (Test-DeadlineWindow $row ($rowLimit + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L12' $row

# WA-L13 - 스윕 참 지속(커서 미확인) → 'counted' (한도 − 1)번 → 굶김 → timeout @L · 굶김 회전 판독 0
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; $rowGap = 1; Set-SweepFrom -From 0 -Kind 'cursor' -Gap $rowGap
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
$firstStarved = [Array]::IndexOf([string[]]@($row.SweepActions), 'starved')
$countedBeforeStarved = $(if ($firstStarved -ge 0) { @(@($row.SweepActions)[0..($firstStarved)] | Where-Object { $_ -eq 'counted' }).Count } else { -1 })
Check-True "WA-L13 'cursor' Gap 1 지속 → 'counted' (한도 − 1)번 → 굶김 · L ≤ T < L + Gap 에 timeout · 판독 회전 기록 0 · LastKind '' · PanelSeen 거짓" `
    (($row.Result -ceq 'timeout') -and (@($row.Reads).Count -eq 0) -and ($row.LastKind -ceq '') -and ($row.PanelSeen -eq $false) -and ($countedBeforeStarved -eq ($memberSweepStreakLimit - 1)) -and
    ($row.T -ge ($rowLimit - $TIME_EPSILON)) -and ($row.T -lt ($rowLimit + $rowGap - $TIME_EPSILON))) (Format-RowDetail $row)
Check-RowCommon 'WA-L13' $row
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 2; $rowGap = 1.2; Set-SweepFrom -From 0 -Kind 'cursor' -Gap $rowGap
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
$sweepEntryTimes = @($row.Events | Where-Object { $_.Kind -eq 'sweep' } | ForEach-Object { [double]$_.T })
$lastSweepEntry = $(if ($sweepEntryTimes.Count -ge 1) { $sweepEntryTimes[$sweepEntryTimes.Count - 1] } else { [double]::NaN })
Check-True "WA-L13 둘째 판 - 'cursor' Gap 1.2 지속 · L 2(마감이 첫 굶김 회전 전에 지나 있음) → 스윕 호출 수 = 캡처한 한도 · T = 마지막 스윕 진입 + Gap · 판독 회전 기록 0 · LastKind '' · PanelSeen 거짓" `
    (($row.Result -ceq 'timeout') -and ($row.SweepCalls -eq $memberSweepStreakLimit) -and (Test-SameTime $row.T ($lastSweepEntry + $rowGap)) -and (@($row.Reads).Count -eq 0) -and ($row.LastKind -ceq '') -and ($row.PanelSeen -eq $false)) (Format-RowDetail $row)
Check-RowCommon 'WA-L13 둘째 판' $row

# WA-L14 - 스윕 참 30초(user-active - 위임 길) 뒤 M → 마감이 양보만큼 늦음(D = L + 양보 합) · 굶김 예산 미소모(굶김 회전 0)
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; Set-SweepFrom -From 0 -Until 30 -Kind 'ua-deleg' -Gap 0.5
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True "WA-L14 'ua-deleg' Gap 0.5 · [0,30) 뒤 M → D = L + 양보 합 · D ≤ T < D + 박자에 timeout · 굶김 회전 0(분류에 starved 0)" `
    (($row.Result -ceq 'timeout') -and ($row.Yields -ge 1) -and (@($row.SweepActions | Where-Object { $_ -eq 'starved' }).Count -eq 0) -and (Test-DeadlineWindow $row ($rowLimit + $row.YieldTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L14' $row

# WA-L14′ - 조정 마감이 지난 뒤 첫 스윕 참 회전이 'yield'(위임 길) → 그 회전은 마감을 확정하지 않음 → timeout 은 양보가 끝난 뒤 회전
Reset-ReentryRow; Set-ScreenPlan @('M', 0); Set-SweepFrom -From 2 -Until 2.5 -Kind 'ua-deleg' -Gap 0.5 -Count 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 2 }
Check-True "WA-L14′ M 지속 · 'ua-deleg' Gap 0.5 · [2,2.5) 1회 · L 2 → 양보 1 · T ≥ 첫 양보 끝에 timeout" `
    (($row.Result -ceq 'timeout') -and ($row.Yields -eq 1) -and (@($row.YieldEnds).Count -eq 1) -and ($row.T -ge ([double]$row.YieldEnds[0] - $TIME_EPSILON))) (Format-RowDetail $row)
Check-RowCommon 'WA-L14′' $row

# WA-L14″ - 조작 생략 스윕('yield')은 굶김 연속을 소모하지 않음(규칙 4 - 'user-active' 생략은 예산·시도 횟수 미소모, 구현 리뷰 P3). M 지속에서
#   'ua-deleg' (한도 − 1)회 뒤 'cursor' 1회 - 그 사이 유효 회전 0 → 분류 = yield × (한도 − 1) · counted(starved 0) → 'cursor' 다음 회전에 판독. 'yield' 회전에
#   연속을 더하는 변이는 그 'cursor' 회전이 starved 가 됩니다(WA-L14 는 끝까지 'yield' 뿐이라 - 분류 원문이 'yield' 를 굶김보다 먼저 돌려줌 - 갈리지 않음)
Reset-ReentryRow; Set-ScreenPlan @('M', 0); Set-SweepFrom -From 0 -Kind 'ua-deleg' -Gap 0.5 -Count ($memberSweepStreakLimit - 1); Set-SweepFrom -From 0 -Kind 'cursor' -Gap 1 -Count 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 30 }
$cursorFired = @($row.SweepFired | Where-Object { $_.Kind -eq 'cursor' })
$cursorFiredTime = $(if ($cursorFired.Count -eq 1) { [double]$cursorFired[0].T } else { [double]::NaN })
$cursorNextSweep = @($row.Events | Where-Object { ($_.Kind -eq 'sweep') -and ([double]$_.T -gt ($cursorFiredTime + $TIME_EPSILON)) } | Select-Object -First 1)   # 그 다음 회전의 스윕 진입
$cursorNextTurnTime = $(if ($cursorNextSweep.Count -eq 1) { [double]$cursorNextSweep[0].T } else { [double]::NaN })
$yieldThenCounted = (@(@('yield') * ($memberSweepStreakLimit - 1)) + @('counted')) -join ','
Check-True "WA-L14″ M 지속 · 'ua-deleg' (한도 − 1)회 → 'cursor' 1회(그 사이 유효 회전 0) → 분류 = yield × (한도 − 1) · counted(starved 0) · 양보 (한도 − 1) · 'cursor' 다음 회전에 첫 판독 · timeout · LastKind matching" `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'matching') -and ((@($row.SweepActions) -join ',') -ceq $yieldThenCounted) -and ($row.Yields -eq ($memberSweepStreakLimit - 1)) -and
    (@(Get-RecordTimes $row -Before $cursorFiredTime).Count -eq 0) -and (Test-SameTime (Get-NthTime @(Get-RecordTimes $row -After $cursorFiredTime) 1) $cursorNextTurnTime)) `
    ((Format-RowDetail $row) + (' 기대 분류=[{0}] · 다음 회전 {1}' -f $yieldThenCounted, (Format-Seconds $cursorNextTurnTime)))
Check-RowCommon 'WA-L14″' $row

# WA-L15 - 경계 회전(마감과 던전 안 2연속이 같은 회전)에서 결론이 먼저 → T = L 에 entered (L 은 회전 박자 정수배)
Reset-ReentryRow; $rowLimit = 28; Set-ScreenPlan @('M', 0, 'I', ($rowLimit - 0.8))
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L15 L 28 · M → I@27.2 → 마감 경계 회전 T = L 에 entered (결론이 같은 회전의 마감보다 먼저)' (($row.Result -ceq 'entered') -and (Test-SameTime $row.T $rowLimit)) (Format-RowDetail $row)
Check-RowCommon 'WA-L15' $row

# WA-L16 - (보고) 3버튼 지속 → 조정 Q 가 지난 첫 R 회전에 reclick · 반환 PanelSeen 거짓
Reset-ReentryRow; Set-ScreenPlan @('R', 0)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60; ReportRewardReturn = $true }
Check-True '(보고) WA-L16 R 지속 → Q ≤ T < Q + 박자에 reclick · PanelSeen 거짓' `
    (($row.Result -ceq 'reclick') -and ($row.PanelSeen -eq $false) -and (Test-DeadlineWindow $row $Q)) (Format-RowDetail $row)
Check-RowCommon 'WA-L16' $row

# WA-L17 - (보고) R@0~4 · M@5~19 · R@20~ → M 뒤 첫 R 유효 회전에 cancelled · reclick 0
Reset-ReentryRow; Set-ScreenPlan @('R', 0, 'M', 5, 'R', 20)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60; ReportRewardReturn = $true }
$lastMTime = Get-NthTime @(Get-RecordTimes $row -Screen 'M' -Clean) (@(Get-RecordTimes $row -Screen 'M' -Clean).Count)
Check-True '(보고) WA-L17 R@0~4 · M@5~19 · R@20~ → M 뒤 첫 R 유효 회전에 cancelled (reclick 0)' `
    (($row.Result -ceq 'cancelled') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'R' -Clean -After $lastMTime) 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L17' $row

# WA-L17′ - R5-M25 변형(문안 715) - 둘째 R 대신 U → 'cancelled' 1표본
Reset-ReentryRow; $rowSecondR = 20; $rowAfterR = 20.7; Set-ScreenPlan @('R', 0, 'M', 5, 'R', $rowSecondR, 'U', $rowAfterR)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60; ReportRewardReturn = $true }
Check-True "(보고) WA-L17′ R@0~4 · M@5~19 · R@20 · U@20.7 → 20 ≤ T < 20.7 에 cancelled (3버튼 1표본)" `
    (($row.Result -ceq 'cancelled') -and ($row.T -ge ($rowSecondR - $TIME_EPSILON)) -and ($row.T -lt ($rowAfterR - $TIME_EPSILON))) (Format-RowDetail $row)
Check-RowCommon 'WA-L17′' $row

# WA-L18 - (보고) 권장 인원 팝업 → 3버튼 → cancelled · 안내 1 / 같은 입력 · 보고 끔 → timeout · 안내 0
Reset-ReentryRow; Set-ScreenPlan @('U', 0, 'P', 1, 'R', 3)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60; ReportRewardReturn = $true }
Check-True '(보고) WA-L18 U@0 · P@1~2.4 · R@3 → 첫 R 에 cancelled · 권장 인원 팝업 관측 안내 1' `
    (($row.Result -ceq 'cancelled') -and ($row.NoticeCount -eq 1) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'R') 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L18' $row
Reset-ReentryRow; Set-ScreenPlan @('U', 0, 'P', 1, 'R', 3); $rowLimit = 60
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L18 보고 끔 - 같은 입력 → L ≤ T < L + 박자에 timeout · 안내 0' `
    (($row.Result -ceq 'timeout') -and ($row.NoticeCount -eq 0) -and (Test-DeadlineWindow $row $rowLimit)) (Format-RowDetail $row)
Check-RowCommon 'WA-L18 보고 끔' $row

# WA-L19 - (보고) R@0~4 · 조작 20초 [4,24) · R → reclick 이 조정 Q(벽시계 Q + 20)
Reset-ReentryRow; Set-ScreenPlan @('R', 0); Add-ActiveWindow 4 24
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 120; ReportRewardReturn = $true }
Check-True '(보고) WA-L19 R@0~4 · 조작 [4,24) · R → Q + 양보 ≤ T < + 박자에 reclick' `
    (($row.Result -ceq 'reclick') -and (Test-DeadlineWindow $row ($Q + $row.YieldTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L19' $row

# WA-L20 - (보고) R@0~4 · 캡처 실패 30초 [4,34) · R → reclick 이 조정 Q(벽시계 ≈ Q + 30)
Reset-ReentryRow; Set-ScreenPlan @('R', 0); Add-FailWindow 4 34
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 120; ReportRewardReturn = $true }
Check-True '(보고) WA-L20 R@0~4 · 캡처 실패 [4,34) · R → Q + 실패 합 ≤ T < + 박자에 reclick' `
    (($row.Result -ceq 'reclick') -and ($row.FailTotalMs -gt 0) -and (Test-DeadlineWindow $row ($Q + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'WA-L20' $row

# WA-L21 - (보고) R@0~(Q−1) · U@(Q−0.5)~40 · I · I → 무변화 만료 회전이 U → entered (reclick 0)
Reset-ReentryRow; Set-ScreenPlan @('R', 0, 'U', ($Q - 0.5), 'I', 40)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 120; ReportRewardReturn = $true }
Check-True '(보고) WA-L21 R@0 · U@(Q − 0.5) · I@40 · I → I 구간 둘째 유효 회전에 entered (무변화 만료 회전이 U 라 reclick 0)' `
    (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 2))) (Format-RowDetail $row)
Check-RowCommon 'WA-L21' $row

# WA-L22 - (보고 끔) 3버튼 지속 → timeout @L · LastKind 'reward3' · PanelSeen 거짓
Reset-ReentryRow; Set-ScreenPlan @('R', 0); $rowLimit = 30
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L22 (보고 끔) R 지속 → L ≤ T < L + 박자에 timeout · LastKind reward3 · PanelSeen 거짓' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'reward3') -and ($row.PanelSeen -eq $false) -and (Test-DeadlineWindow $row $rowLimit)) (Format-RowDetail $row)
Check-RowCommon 'WA-L22' $row

# WA-L23 - (보고) M@2 · 조작 [3,10) · R@11 → 패널 관측이 양보를 넘어 유지 → cancelled
Reset-ReentryRow; Set-ScreenPlan @('U', 0, 'M', 2, 'R', 11); Add-ActiveWindow 3 10
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 120; ReportRewardReturn = $true }
Check-True '(보고) WA-L23 U@0 · M@2 · 조작 [3,10) · R@11 → 첫 R 에 cancelled' `
    (($row.Result -ceq 'cancelled') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'R') 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L23' $row

# WA-L24 - -Clock(남은 100초) · M 지속 + 조작 [10,20) → 조정 100 에 timeout · 호출부 hashtable 의 Deadline·기준값 = waiter 안 조정(같은 객체) · -LimitSeconds 5 함께
Reset-ReentryRow; Set-ScreenPlan @('M', 0); Add-ActiveWindow 10 20; $rowClockSeconds = 100
$rowClock = New-AbyssMemberClock -LimitSeconds $rowClockSeconds
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 5; Clock = $rowClock }
$clockDeadlineSeconds = ([datetime]$rowClock.Deadline - $script:caseStart).TotalSeconds
$adjustedClockSeconds = $rowClockSeconds + $row.YieldTotalMs / 1000.0
Check-True 'WA-L24 -Clock(남은 100) · -LimitSeconds 5 · M 지속 · 조작 [10,20) → 반환 뒤 그 시계 Deadline = 시작 + 100 + 양보 · SeenYieldMs = 양보 ms · T ≥ 그 값에 timeout' `
    (($row.Result -ceq 'timeout') -and ($row.YieldTotalMs -gt 0) -and (Test-SameTime $clockDeadlineSeconds $adjustedClockSeconds) -and ([Math]::Abs([double]$rowClock.SeenYieldMs - $row.YieldTotalMs) -lt 0.5) -and
    ($row.T -ge ($adjustedClockSeconds - $TIME_EPSILON))) ((Format-RowDetail $row) + (' 시계 Deadline={0}초 SeenYieldMs={1}' -f (Format-Seconds $clockDeadlineSeconds), $rowClock.SeenYieldMs))
Check-RowCommon 'WA-L24' $row

# WA-L25 - -Clock(남은 0) · 유예 없음 · 첫 유효 U / I → 그 회전 timeout · 'unknown' / 'inside'
Reset-ReentryRow; Set-ScreenPlan @('U', 0)
$row = Invoke-ReentryRow @{ Game = $null; Clock = (New-RemainingClock 0) }
Check-True 'WA-L25 -Clock(남은 0) · 유예 없음 · U → 첫 유효 회전에 timeout · LastKind unknown' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'unknown') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L25' $row
Reset-ReentryRow; Set-ScreenPlan @('I', 0)
$row = Invoke-ReentryRow @{ Game = $null; Clock = (New-RemainingClock 0) }
Check-True 'WA-L25 둘째 판 - I → 첫 유효 회전에 timeout · LastKind inside' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'inside') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L25 둘째 판' $row

# WA-L26 - 필드 모양 20초(> W) · I · I → 필드 결론 0 · entered · S2 '필드 모양 n표본, 첫 필드 모양 표본부터 던전 안 s초' (n·s 는 기록에서)
Reset-ReentryRow; Set-ScreenPlan @('F', 0, 'I', 20)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$s2 = Get-S2Facts $row
$fieldSampleCount = @(Get-RecordTimes $row -Screen 'F' -Clean).Count
$fieldToInsideSeconds = [Math]::Round((Get-NthTime @(Get-RecordTimes $row -Screen 'I') 1) - (Get-NthTime @(Get-RecordTimes $row -Screen 'F') 1), 1)
Check-True 'WA-L26 F@0 · I@20 → entered(필드 결론 0) · S2 필드 모양 n표본(n = F 유효 회전 수) · 첫 필드 모양 토막 s = 첫 I − 첫 F (한 자리)' `
    (($row.Result -ceq 'entered') -and ($s2.Count -eq 1) -and $s2.Matched -and ($s2.F -eq $fieldSampleCount) -and $s2.HasPart -and ([Math]::Abs($s2.S - $fieldToInsideSeconds) -lt 0.01)) `
    ((Format-RowDetail $row) + (' 기대 n={0} s={1}' -f $fieldSampleCount, $fieldToInsideSeconds))
Check-RowCommon 'WA-L26' $row

# WA-L27 - 클리어 S 지속 → 관측 지속 → timeout · LastKind 'prompt'
Reset-ReentryRow; Set-ScreenPlan @('S', 0); $rowLimit = 30
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'WA-L27 S 지속 → L ≤ T < L + 박자에 timeout · LastKind prompt' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'prompt') -and (Test-DeadlineWindow $row $rowLimit)) (Format-RowDetail $row)
Check-RowCommon 'WA-L27' $row

# WA-L28 - 알 수 없음 45초 → 이벤트 정리 0 (기록 모의 0)
Reset-ReentryRow; Set-ScreenPlan @('U', 0)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 45 }
Check-True 'WA-L28 U 45초 → timeout · Clear-EventOverlay 0' (($row.Result -ceq 'timeout') -and ([int]$row.RecordCalls['Clear-EventOverlay'] -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'WA-L28' $row

# WA-L29 - 실제 스윕 + 재시작 팝업 모의 참 → 스윕 안 exit 4 센티널(원문 run:7635~7638) · 반환 0 · [완료] 줄 1
Reset-ReentryRow; Set-ScreenPlan @('U', 0); $script:useRealSweep = $true; $script:restartPopupMock = $true
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True 'WA-L29 실제 스윕 + Test-GameRestartPopup 모의 참 → __EXIT__4 · 반환 수 0 · [완료] 줄 1' `
    (($row.Error -ceq '__EXIT__4') -and ($row.Count -eq 0) -and (@($row.Logs | Where-Object { $_.StartsWith('[완료]') }).Count -eq 1)) (Format-RowDetail $row)
Check-RowCommon 'WA-L29' $row

# WA-L30 - 캡처 실패 [0, ∞) + F9 예약 → 원문 안전 확인의 exit 4 센티널(T ≥ 문턱) / 게임 프로세스 종료 → 같은 센티널
Reset-ReentryRow; Set-ScreenPlan @('U', 0); Add-FailWindow 0 $NEVER_ENDS_SECONDS; $script:safeStopFlagMock = $true
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 600 }
Check-True 'WA-L30 (가) 캡처 실패 [0, ∞) + 안전 중지 파일 모의 참 → 원문 안전 확인의 __EXIT__4 · T ≥ 캡처한 문턱(초)' `
    (($row.Error -ceq '__EXIT__4') -and ($row.Count -eq 0) -and ($row.T -ge ($SAFE_STOP_SECONDS - $TIME_EPSILON))) (Format-RowDetail $row)
Check-RowCommon 'WA-L30 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('U', 0); Add-FailWindow 0 $NEVER_ENDS_SECONDS
$script:gameProcess = [pscustomobject]@{ HasExited = $true; MainWindowHandle = [IntPtr]1 } | Add-Member -MemberType ScriptMethod -Name Refresh -Value { } -PassThru
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 600 }
Check-True 'WA-L30 (나) 캡처 실패 + $script:gameProcess 모의(HasExited 참 · Refresh) → 원문 안전 확인의 __EXIT__4' (($row.Error -ceq '__EXIT__4') -and ($row.Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'WA-L30 (나)' $row

# WA-L32 - (보고) R@0~4 · M@5 · 판독 도중 실패(@6.3 회전 하단) · R@7 → 패널 관측이 실패 회전을 넘어 유지 → cancelled
Reset-ReentryRow; Set-ScreenPlan @('R', 0, 'M', 5, 'R', 7); $script:failHook = $HOOK_PROMPT_FAIL_AT_6_3
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 120; ReportRewardReturn = $true }
$lastMTime = Get-NthTime @(Get-RecordTimes $row -Screen 'M') (@(Get-RecordTimes $row -Screen 'M').Count)
Check-True '(보고) WA-L32 R@0~4 · M@5 · 하단 실패 @6.3 회전 · R@7 → M 뒤 첫 R 에 cancelled (실패 회전을 넘어 유지)' `
    (($row.Result -ceq 'cancelled') -and (@(Get-RecordTimes $row -Failed).Count -ge 1) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'R' -After $lastMTime) 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L32' $row

# WA-L33 - -Clock(남은 0) + 유예 (보고) - 여덟 판
$graceArguments = @{ Game = $null; ReportRewardReturn = $true; ResumeGrace = $true }
Reset-ReentryRow; Set-ScreenPlan @('I', 0)
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) WA-L33 (가) -Clock(남은 0) · I · I → 둘째 I 에 entered' (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 2))) (Format-RowDetail $row)
Check-RowCommon 'WA-L33 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('I', 0, 'U', 0.5)
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) WA-L33 (나) I · U → U 회전에 timeout · LastKind unknown' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'unknown') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'U') 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L33 (나)' $row
Reset-ReentryRow; Set-ScreenPlan @('R', 0)
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) WA-L33 (다) R 지속 → 'timeout' 0 → Q ≤ T < Q + 박자에 reclick" (($row.Result -ceq 'reclick') -and (Test-DeadlineWindow $row $Q)) (Format-RowDetail $row)
Check-RowCommon 'WA-L33 (다)' $row
Reset-ReentryRow; Set-ScreenPlan @('M', 0)
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) WA-L33 (라) M → 첫 유효 회전에 timeout · LastKind matching (기다리는 상태는 미루지 않음)' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'matching') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L33 (라)' $row
Reset-ReentryRow; Set-ScreenPlan @('R', 0)
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0); PanelSeen = $true })
Check-True '(보고·유예·-PanelSeen) WA-L33 (마) R → 첫 R 에 cancelled' (($row.Result -ceq 'cancelled') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L33 (마)' $row
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Kind 'sent' -Gap 1 -Alternate
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
Check-True "(보고·유예) WA-L33 (바) I · 스윕 참('sent' Gap 1 교대 - 창 안 첫 호출이 참) · I … → 둘째 회전 = 스윕 참(판독 0) · 둘째 I 기록에 timeout(새 연속은 미루지 않음 - 유한) · 판독 회전 기록 2" `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'inside') -and (@($row.Reads).Count -eq 2) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 2)) -and
    (@(Get-RecordTimes $row | Where-Object { Test-SameTime $_ $firedTime }).Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'WA-L33 (바)' $row
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-FailWindow 0.5 3
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) WA-L33 (사) I · 동결 [0.5,3) · I → entered (탐침 복구 뒤 회전도 유예 시계 안에서 미룸 - J1)' `
    (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I' -Clean) 2))) (Format-RowDetail $row)
Check-RowCommon 'WA-L33 (사)' $row
Reset-ReentryRow; Set-ScreenPlan @('F', 0)
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) WA-L33 (아) F 지속 → 첫 유효 회전에 timeout · LastKind field' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'field') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 1))) (Format-RowDetail $row)
Check-RowCommon 'WA-L33 (아)' $row

# WA-L34 - -Clock(남은 5초) · (보고) R 지속 - 유예 있음 → Q 에 reclick / 없음 → @5 timeout 'reward3'
Reset-ReentryRow; Set-ScreenPlan @('R', 0); $rowClockSeconds = 5
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock $rowClockSeconds) })
Check-True '(보고·유예) WA-L34 -Clock(남은 5) · R 지속 → T ≥ Q 에 reclick' (($row.Result -ceq 'reclick') -and ($row.T -ge ($Q - $TIME_EPSILON))) (Format-RowDetail $row)
Check-RowCommon 'WA-L34' $row
Reset-ReentryRow; Set-ScreenPlan @('R', 0)
$row = Invoke-ReentryRow @{ Game = $null; ReportRewardReturn = $true; Clock = (New-RemainingClock $rowClockSeconds) }
Check-True '(보고) WA-L34 유예 없음 - -Clock(남은 5) · R 지속 → 5 ≤ T < 5 + 박자에 timeout · LastKind reward3' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'reward3') -and (Test-DeadlineWindow $row $rowClockSeconds)) (Format-RowDetail $row)
Check-RowCommon 'WA-L34 유예 없음' $row

# WA-L35 - M 지속 + 스윕 도중 실패 - (가) 끝나도 실패 중('freeze') → 그 회전 마감 확정 0 → 다음 회전 ① / (나) 스윕 안 복구('recovered') 매 회전 → timeout 유한
Reset-ReentryRow; Set-ScreenPlan @('M', 0); Set-SweepFrom -From 2 -Until 2.5 -Kind 'fail-true' -Gap 1 -Count 1; Add-FailWindow 2.5 6
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 2 }
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
$firedIndex = Get-EventIndex -Row $row -Kind 'sweep' -Time $firedTime
Check-True "WA-L35 (가) 'fail-true' 1회 @2.1 + 실패 창 [2.5,6) · L 2 → 그 스윕 사건 바로 다음 사건 = 안전 확인 · 첫 탐침 성공 시각(탐침 복구 뒤 회전)에 timeout" `
    (($row.Result -ceq 'timeout') -and ((Get-EventKindAt -Row $row -Index ($firedIndex + 1)) -ceq 'safestop') -and (Test-SameTime $row.T (Get-FirstProbeOkTime $row))) (Format-RowDetail $row)
Check-RowCommon 'WA-L35 (가)' $row
# (나) 는 앞 유효 회전(@0·0.7·1.4 - M)을 읽은 뒤 @2 부터 'recover' 를 켭니다(명세 3.4 스크래치 하니스와 같은 시작). 0초부터 켜면 판독 회전이 0 이라 'M 지속'
#   전제가 빠지고, 유효 회전에 닿아야 드러나는 변이(N4-M11 - 무변화 시계를 보고 켬 호출에서만 만듦)를 이 행이 놓칩니다(구현 리뷰 P2)
Reset-ReentryRow; Set-ScreenPlan @('M', 0); Set-SweepFrom -From 2 -Kind 'recover' -Gap 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 30 }
Check-True "WA-L35 (나) M 유효 회전 뒤 'recover' Gap 1 지속(@2~ 스윕 안 복구 매 회전) → 분류 recovered · timeout 유한 · LastKind matching" `
    (($row.Result -ceq 'timeout') -and ($row.Error -ceq '') -and ($row.LastKind -ceq 'matching') -and (@($row.SweepActions | Where-Object { $_ -eq 'recovered' }).Count -ge 1)) (Format-RowDetail $row)
Check-RowCommon 'WA-L35 (나)' $row

# WA-L36 - ① 탐침이 되살린 직후 조작 3초 → 게이트 먼저(양보 1) · 표식이 남아 양보 뒤 회전 = 탐침 복구 뒤 회전(스윕·판독 0) → 그다음 판독
Reset-ReentryRow; Set-ScreenPlan @('M', 0); Add-FailWindow 1 4; Add-ActiveWindow 5.39 8.39
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$yieldIndex = Get-EventIndex -Row $row -Kind 'yield'
$yieldEndTime = $(if (@($row.YieldEnds).Count -ge 1) { [double]$row.YieldEnds[0] } else { [double]::NaN })
Check-True "WA-L36 실패 [1,4) · 조작 [5.39,8.39) → 양보 1 · 양보 사건 바로 다음 사건 = 복구 대기(${RECOVERED_WAIT_MS}ms - 스윕·판독 0) · 그 뒤 판독" `
    (($row.Yields -eq 1) -and ((Get-EventKindAt -Row $row -Index ($yieldIndex + 1)) -ceq "sleep:$RECOVERED_WAIT_MS") -and (@(Get-RecordTimes $row -Clean -After $yieldEndTime).Count -ge 1)) (Format-RowDetail $row)
Check-RowCommon 'WA-L36' $row

# WA-L37 - I · U · I · I → 셋째(I - 연속 1) 결론 0 · 넷째 entered
Reset-ReentryRow; Set-ScreenPlan @('I', 0, 'U', 0.5, 'I', 1.2)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True 'WA-L37 I@0 · U@0.5 · I@1.2 → 넷째 유효 회전에 entered (셋째는 새 연속 1)' (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 4))) (Format-RowDetail $row)
Check-RowCommon 'WA-L37' $row

# WA-L38 - (보고) R@0~4 · U@4~6 · R@6~ → 무변화 창은 호출부터(알 수 없음 회전에서 다시 세지 않음) → 조정 Q 에 reclick
Reset-ReentryRow; Set-ScreenPlan @('R', 0, 'U', 4, 'R', 6)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60; ReportRewardReturn = $true }
Check-True '(보고) WA-L38 R@0~4 · U@4~6 · R@6~ → Q ≤ T < Q + 박자에 reclick' (($row.Result -ceq 'reclick') -and (Test-DeadlineWindow $row $Q)) (Format-RowDetail $row)
Check-RowCommon 'WA-L38' $row

# WA-L39 - M@0~5 · 그 뒤 교대 @5.5~ → timeout 유한 · LastKind 'matching' (굶김·복구·탐침 복구 뒤 회전의 timeout 도 앞 유효 분류)
Reset-ReentryRow; Set-ScreenPlan @('M', 0); Set-CaptureAlternate -From 5.5 -Mode 'normal'
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 30 }
Check-True 'WA-L39 M@0~5 · 교대 @5.5~ → timeout 유한 · LastKind matching' (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'matching') -and ($row.Error -ceq '')) (Format-RowDetail $row)
Check-RowCommon 'WA-L39' $row

# WA-L41 - (보고 · -PanelSeen 참) 첫 회전 조작 3초 → R 지속 → 양보 뒤 첫 R 에 cancelled (reclick 0)
Reset-ReentryRow; Set-ScreenPlan @('R', 0); $rowActiveUntil = 3; Add-ActiveWindow 0 $rowActiveUntil
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 120; ReportRewardReturn = $true; PanelSeen = $true }
Check-True '(보고·-PanelSeen 참) WA-L41 조작 [0,3) → R 지속 → 양보 뒤 첫 R(T = 조작 창 끝)에 cancelled' (($row.Result -ceq 'cancelled') -and (Test-SameTime $row.T $rowActiveUntil)) (Format-RowDetail $row)
Check-RowCommon 'WA-L41' $row

# WA-L43 - 창 사각형 실패 throw (넷 다 waiter 밖 예외 0)
Reset-ReentryRow; Set-ScreenPlan @('I', 0); $script:failHook = $HOOK_HUD_RECT_AT_0_7
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True 'WA-L43 (가) I@0 · 다음 회전 HUD 창 사각형 throw · 탐침 복구 · I → 실패 없는 판독 회전 기록의 둘째에 entered(받은 회전 연속 유지) · 안전 확인 ≥ 1 · 탐침 ≥ 1' `
    (($row.Result -ceq 'entered') -and ($row.Error -ceq '') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 2)) -and ($row.SafeStops -ge 1) -and ($row.Probes -ge 1)) (Format-RowDetail $row)
Check-RowCommon 'WA-L43 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30; Set-CaptureAlternate -From 0.5 -Mode 'panelRect'
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
$independentFailSum = Get-IndependentFailSum -Row $row
Check-True 'WA-L43 (나) M + 0.5초부터 교대·패널 rect 전용 → D = L + 실패 합 · D ≤ T < D + 박자에 timeout · matching · 실패 합(rect 등록 → 탐침 복구 독립 계산) > 0 = 원문 끝값(±0.05초)' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'matching') -and ($row.Error -ceq '') -and ($independentFailSum -gt 0) -and ([Math]::Abs($independentFailSum - $row.FailTotalMs / 1000.0) -le 0.05) -and
    (Test-DeadlineWindow $row ($rowLimit + $row.FailTotalMs / 1000.0))) ((Format-RowDetail $row) + (' 독립 실패 합={0}초' -f (Format-Seconds $independentFailSum)))
Check-RowCommon 'WA-L43 (나)' $row
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.6 -Until 0.8 -Kind 'rect-throw' -Count 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
$firedIndex = Get-EventIndex -Row $row -Kind 'sweep' -Time $firedTime
Check-True "WA-L43 (다) I@0 · @0.7 스윕 'rect-throw' 1회 · 탐침 복구 · I → 실패 없는 판독 회전 기록의 둘째에 entered · 그 회전 판독 0 · 그 스윕 사건 바로 다음 사건 = 안전 확인" `
    (($row.Result -ceq 'entered') -and ($row.Error -ceq '') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 2)) -and
    (@(Get-RecordTimes $row | Where-Object { Test-SameTime $_ $firedTime }).Count -eq 0) -and ((Get-EventKindAt -Row $row -Index ($firedIndex + 1)) -ceq 'safestop')) (Format-RowDetail $row)
Check-RowCommon 'WA-L43 (다)' $row
Reset-ReentryRow; Set-ScreenPlan @('I', 0); $script:failHook = $HOOK_OTHER_THEN_HUD_RECT_AT_0_7
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True "WA-L43 (라) 하단·패널이 'other' 등록 뒤 HUD 창 사각형 throw → (가) 와 같음 (원인이 gameWindowGone 으로 바뀌어 받음)" `
    (($row.Result -ceq 'entered') -and ($row.Error -ceq '') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 2))) (Format-RowDetail $row)
Check-RowCommon 'WA-L43 (라)' $row

# WA-L44 - 그 밖의 예외 - 같은 예외가 waiter 밖 · 반환 0
Reset-ReentryRow; Set-ScreenPlan @('I', 0); $script:failHook = $HOOK_PANEL_OTHER_ERROR_AT_0_7
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True "WA-L44 (가) 플래그 거짓 · 다른 예외 → 같은 예외가 waiter 밖 · 반환 0" (($row.Error -ceq $OTHER_ERROR_TEXT) -and ($row.Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'WA-L44 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('I', 0); $script:failHook = $HOOK_OTHER_THEN_PANEL_ERROR_AT_0_7
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True "WA-L44 (나) 'other' 등록(플래그 참) 뒤 다른 문구 → 같은 예외가 waiter 밖 · 반환 0" (($row.Error -ceq $OTHER_ERROR_TEXT) -and ($row.Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'WA-L44 (나)' $row

# N4-L1 - (J1) -Clock(남은 0) + 유예 · (보고) I@0 · 0.5초부터 교대 → timeout 유한 · 'inside' · T > 조정 Q (그때까지 미룸)
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-CaptureAlternate -From 0.5 -Mode 'normal'
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L1 I@0 · 교대 @0.5~ → timeout 유한 · LastKind inside · T ≥ 조정 Q(Q + 실패 합 - 첫 유예가 호출 첫 회전) · VTIMEOUT 0' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'inside') -and ($row.Error -ceq '') -and ($row.T -ge ($Q + $row.FailTotalMs / 1000.0 - $TIME_EPSILON))) (Format-RowDetail $row)
Check-RowCommon 'N4-L1' $row

# N4-L2 - (J2) -Clock(남은 0) + 유예 · (보고) R 지속 + 실패 [3,5) → 조정 Q 뒤 첫 R 에 reclick · timeout 0
Reset-ReentryRow; Set-ScreenPlan @('R', 0); Add-FailWindow 3 5
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L2 R 지속 + 실패 [3,5) → Q + 실패 합 ≤ T < + 박자에 reclick (timeout 0)' `
    (($row.Result -ceq 'reclick') -and ($row.FailTotalMs -gt 0) -and (Test-DeadlineWindow $row ($Q + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'N4-L2' $row

# N4-L3 - (J5 · B-4 (다)) I@0 · @0.7 스윕 'rect-click-throw' 1회(gameWindowGone 등록만 + 클릭 경로 문구) · 탐침 복구 · I → entered (받은 회전은 판정 0 → 다음 회전 ①)
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.6 -Until 0.8 -Kind 'rect-click-throw' -Count 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
$firedIndex = Get-EventIndex -Row $row -Kind 'sweep' -Time $firedTime
Check-True "N4-L3 I@0 · @0.7 스윕 'rect-click-throw'(클릭 경로 문구 · 플래그 참 · gameWindowGone) · 탐침 복구 · I → 실패 없는 판독 회전 기록의 둘째에 entered · waiter 밖 예외 0 · 안전 확인 ≥ 1 · 탐침 ≥ 1 · 그 회전 판독 0 · 그 스윕 사건 바로 다음 사건 = 안전 확인" `
    (($row.Result -ceq 'entered') -and ($row.Error -ceq '') -and ($row.SafeStops -ge 1) -and ($row.Probes -ge 1) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 2)) -and
    (@(Get-RecordTimes $row | Where-Object { Test-SameTime $_ $firedTime }).Count -eq 0) -and ((Get-EventKindAt -Row $row -Index ($firedIndex + 1)) -ceq 'safestop')) (Format-RowDetail $row)
Check-RowCommon 'N4-L3' $row

# N4-L3′ - N4-L3 과 같고 스윕 문구만 셋째 문구('X ' + 클릭 경로 캡처) → 같은 예외가 waiter 밖 (부분 일치 금지) · 행 끝 플래그 참 · 원인 gameWindowGone
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.6 -Until 0.8 -Kind 'rect-click-throw' -Count 1 -Message $THIRD_MESSAGE
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True "N4-L3′ 셋째 문구('X ' + 클릭 경로 문구) → 같은 예외가 waiter 밖 · 반환 0 · 행 끝 플래그 참 · 원인 $WINDOW_GONE_CAUSE" `
    (($row.Error -ceq $THIRD_MESSAGE) -and ($row.Count -eq 0) -and $row.Flag -and ($row.Cause -ceq $WINDOW_GONE_CAUSE)) (Format-RowDetail $row)
Check-RowCommon 'N4-L3′' $row

# N4-L3″ - I@0 · @0.7 스윕 'click-throw-noreg' 1회(첫 판독 성공 뒤 등록 없이 클릭 경로 문구) → 플래그 거짓이면 두 문구라도 다시 던짐
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.6 -Until 0.8 -Kind 'click-throw-noreg' -Count 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
Check-True "N4-L3″ 'click-throw-noreg'(플래그 거짓 · 클릭 경로 문구) → 같은 예외가 waiter 밖 · 반환 0 · 행 끝 플래그 거짓 · 실패 등록 0(일련번호 0)" `
    (($row.Error -ceq $CLICK_PATH_MESSAGE) -and ($row.Count -eq 0) -and (-not $row.Flag) -and ($row.Serial -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'N4-L3″' $row

# N4-L5 - -Game 표식 프로세스 · -Context 표식 문자열 · I@0 · 실패 [0.5,1) · 조작 [4,5) → entered · 일곱 함수가 받은 Game 이 모두 그 객체 · 게이트 양보의 문맥 = 표식
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-FailWindow 0.5 1; Add-ActiveWindow 4 5
$script:gameMarker = [System.Diagnostics.Process]::GetCurrentProcess()
$rowContextMark = 'N4-L5 문맥 표식'
$row = Invoke-ReentryRow @{ Game = $script:gameMarker; LimitSeconds = 60; Context = $rowContextMark }
$gameKinds = (@($row.GameSeen | ForEach-Object { ($_ -split ':')[0] } | Sort-Object -Unique) -join ',')
Check-True 'N4-L5 -Game 표식 · -Context 표식 · I@0 · 실패 [0.5,1) · 조작 [4,5) → entered · 판독 스텁 넷·스윕·탐침·양보가 받은 Game 이 모두 그 객체 · 게이트 양보 문맥 = 표식(1 이상 · 전부)' `
    (($row.Result -ceq 'entered') -and (@($row.GameSeen | Where-Object { $_ -like '*:False' }).Count -eq 0) -and ($gameKinds -ceq 'hud,panel,probe,prompt,quest,sweep,yield') -and
    (@($row.YieldContexts).Count -ge 1) -and (@($row.YieldContexts | Where-Object { $_ -cne $rowContextMark }).Count -eq 0)) ((Format-RowDetail $row) + (' Game 종류=[{0}] 문맥=[{1}]' -f $gameKinds, (@($row.YieldContexts) -join ',')))
Check-RowCommon 'N4-L5' $row

# N4-L6 - (J1) -Clock(남은 30) + 유예 · (보고) M@0 · U@25 · I@30 → 호출 뒤 조정 Q 가 이미 지난 첫 던전 안 표본도 첫 유예 → I 구간 둘째 유효 회전에 entered
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 25, 'I', 30); $rowClockSeconds = 30
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock $rowClockSeconds) })
Check-True '(보고·유예) N4-L6 -Clock(남은 30) · M@0 · U@25 · I@30 → I 구간 둘째 유효 회전에 entered · 첫 I 회전 시각 ≥ 본 시계 마감' `
    (($row.Result -ceq 'entered') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 2)) -and
    ((Get-NthTime @(Get-RecordTimes $row -Screen 'I') 1) -ge ($rowClockSeconds + ($row.YieldTotalMs + $row.FailTotalMs) / 1000.0 - $TIME_EPSILON))) (Format-RowDetail $row)
Check-RowCommon 'N4-L6' $row

# N4-L6′ - N4-L6 + 캡처 실패 [30.5, 33) → 연장은 첫 유예부터 센 유예 시계 안 → entered · 안전 확인 ≥ 1
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 25, 'I', 30); Add-FailWindow 30.5 33
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock $rowClockSeconds) })
Check-True '(보고·유예) N4-L6′ N4-L6 + 실패 [30.5,33) → 실패 없는 I 판독 회전 기록의 둘째에 entered · 안전 확인 ≥ 1' `
    (($row.Result -ceq 'entered') -and ($row.SafeStops -ge 1) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I' -Clean) 2))) (Format-RowDetail $row)
Check-RowCommon 'N4-L6′' $row

# N4-L7 - (J28) -Clock(남은 0) + 유예 · (보고) R 지속 + 캡처 실패 [0,2)(첫 유효 회전 전) → 조정 Q 뒤 첫 R 에 reclick · timeout 0
Reset-ReentryRow; Set-ScreenPlan @('R', 0); Add-FailWindow 0 2
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L7 R 지속 + 실패 [0,2) → 실패 합 > 0 · Q + 실패 합 ≤ T < + 박자에 reclick (timeout 0)' `
    (($row.Result -ceq 'reclick') -and ($row.FailTotalMs -gt 0) -and (Test-DeadlineWindow $row ($Q + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'N4-L7' $row

# N4-L7′ - N4-L7 의 R 대신 M → 첫 유효 회전에 timeout · 'matching' (기다리는 상태는 첫 유효 회전에서 끝남)
Reset-ReentryRow; Set-ScreenPlan @('M', 0); Add-FailWindow 0 2
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L7′ M 지속 + 실패 [0,2) → 실패 없는 판독 회전 기록의 첫째에 timeout · LastKind matching' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'matching') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 1))) (Format-RowDetail $row)
Check-RowCommon 'N4-L7′' $row

# N4-L8 - (B-12 (나)) -Clock(남은 0) + 유예 · (보고) I 지속 + 조작 [0.5,3)(② 게이트) → 첫 I 가 쓴 유예를 게이트가 되돌려 양보 뒤 새 연속이 다시 첫 유예 → entered
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-ActiveWindow 0.5 3
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L8 I 지속 + 조작 [0.5,3) → I 판독 회전 기록의 셋째에 entered · LastKind inside · 양보 1 · I 판독 회전 3' `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and (@(Get-RecordTimes $row -Screen 'I').Count -eq 3) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L8' $row

# N4-L9 - (1.7) (보고) 접힌 준비 패널 E@0~4 · R@5~ → 'entry-waiting' 도 패널 관측 → 첫 R 에 cancelled · reclick 0 · reward3 · PanelSeen 참
Reset-ReentryRow; Set-ScreenPlan @('E', 0, 'R', 5)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60; ReportRewardReturn = $true }
Check-True '(보고) N4-L9 E@0~4 · R@5~ → 첫 R 유효 회전에 cancelled · LastKind reward3 · PanelSeen 참 · 첫 E 표본 @0' `
    (($row.Result -ceq 'cancelled') -and ($row.LastKind -ceq 'reward3') -and ($row.PanelSeen -eq $true) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'R' -Clean) 1)) -and
    (Test-SameTime (Get-NthTime @(Get-RecordTimes $row -Screen 'E') 1) 0)) (Format-RowDetail $row)
Check-RowCommon 'N4-L9' $row

# N4-L10 - (J2) -Clock(남은 0) + 유예 · (보고) R@0 · 0.5초부터 캡처 교대 → 3버튼 창은 조정 Q 까지 → timeout 유한 · 'reward3'
Reset-ReentryRow; Set-ScreenPlan @('R', 0); Set-CaptureAlternate -From 0.5 -Mode 'normal'
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L10 R@0 · 교대 @0.5~ → 유효 회전은 @0 의 R 하나 · 무변화 창 D = Q + 실패 합 · D ≤ T < D + 박자에 timeout · reward3 · 실패 합 > 0 · VTIMEOUT 0' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'reward3') -and ($row.Error -ceq '') -and (@(Get-RecordTimes $row -Clean).Count -eq 1) -and ($row.FailTotalMs -gt 0) -and
    (Test-DeadlineWindow $row ($Q + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'N4-L10' $row

# N4-L11 - (J28) -Clock(남은 0) + 유예 · (보고) R 지속 · 0초부터 캡처 교대(유효 회전 0) → 첫 유효 회전 전 창도 조정 Q 까지 → timeout 유한 · LastKind ''
Reset-ReentryRow; Set-ScreenPlan @('R', 0); Set-CaptureAlternate -From 0 -Mode 'normal'
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) N4-L11 R 지속 · 교대 @0~ → 실패 없는 판독 회전 기록 0 · D = Q + 실패 합 · D ≤ T < D + 박자에 timeout · LastKind '' · 실패 합 > 0 · VTIMEOUT 0" `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq '') -and ($row.Error -ceq '') -and (@(Get-RecordTimes $row -Clean).Count -eq 0) -and ($row.FailTotalMs -gt 0) -and
    (Test-DeadlineWindow $row ($Q + $row.FailTotalMs / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'N4-L11' $row

# N4-L12 - (J4) I@0 · @0.7 스윕 'yield-rect-throw' 1회(커서 대피 양보 Gap 0.1 뒤 판독 경로 문구) · 탐침 복구 · I · I → 받은 회전도 ⑥ 을 지나 연속 0 → 셋째에 entered
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.6 -Until 0.8 -Kind 'yield-rect-throw' -Gap 0.1 -Count 1
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
$firedIndex = Get-EventIndex -Row $row -Kind 'sweep' -Time $firedTime
Check-True "N4-L12 I@0 · @0.7 'yield-rect-throw' · 탐침 복구 · I · I → 실패 없는 판독 회전 기록의 셋째에 entered · 그 스윕 사건 바로 다음 사건 = 안전 확인 · 양보 누적 > 0 · 게이트 양보 0" `
    (($row.Result -ceq 'entered') -and ($row.Error -ceq '') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3)) -and ((Get-EventKindAt -Row $row -Index ($firedIndex + 1)) -ceq 'safestop') -and
    ($row.YieldTotalMs -gt 0) -and ($row.Yields -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'N4-L12' $row

# N4-L13 - (B-12 · J29 ①) 유예 · (보고) I 지속 · 스윕 'ua-deleg' 1회 @[0.5,1)(Gap 0.5 - 기다리지 않고 참) → ④ 'yield' 가 첫 I 의 유예를 되돌림 → entered
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'ua-deleg' -Gap 0.5 -Count 1
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) N4-L13 I 지속 · 'ua-deleg' 1회 → I 판독 회전 기록의 셋째에 entered · LastKind inside · 양보 1(게이트) · 판독 회전 3" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and (@($row.Reads).Count -eq 3) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L13' $row

# N4-L13′ - N4-L13 의 스윕을 'ua-wait' 1회(Gap 0.1 뒤 스윕 안 양보 - 원문 구매 팝업 꼴) + 조작 [0.75,3) → ④ 'yield' 가 되돌림 → entered · 받은 문맥 = 스윕 문맥 하나
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'ua-wait' -Gap 0.1 -Count 1; Add-ActiveWindow 0.75 3
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) N4-L13′ I 지속 · 'ua-wait' 1회 + 조작 [0.75,3) → I 판독 회전 기록의 셋째에 entered · LastKind inside · 양보 1 · 받은 문맥 = 스윕 안 양보 문맥 하나(게이트 양보 0) · 판독 회전 3" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and ((@($row.YieldContexts) -join '|') -ceq $SWEEP_YIELD_CONTEXT) -and (@($row.Reads).Count -eq 3) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L13′' $row

# N4-L14 - (B-12 · J29 ①) 유예 · (보고) I 지속 · 'yield-false' 1회 @[0.5,1)(Gap 0.1) → ⑥ 이 되돌리고 그 회전 I 가 새 연속 → entered · 게이트 양보 0
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'yield-false' -Gap 0.1 -Count 1
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) N4-L14 I 지속 · 'yield-false' 1회 → I 판독 회전 기록의 셋째에 entered · LastKind inside · 게이트 양보 0 · 양보 누적 > 0 · 판독 회전 3" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 0) -and ($row.YieldTotalMs -gt 0) -and (@($row.Reads).Count -eq 3) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L14' $row

# N4-L15 - (B-12 · J29 ①②) 스윕 계획 셋 - 'yield-sent'(전송이 끊은 첫 연속은 그대로 한 번) → 'ua-deleg' → 'yield-false'(끊을 연속 없음) → timeout
Reset-ReentryRow; Set-ScreenPlan @('I', 0)
Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'yield-sent' -Gap 1 -Count 1
Set-SweepFrom -From 1.5 -Until 2.0 -Kind 'ua-deleg' -Gap 0.5 -Count 1
Set-SweepFrom -From 5.0 -Until 5.5 -Kind 'yield-false' -Gap 0.1 -Count 1
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) N4-L15 'yield-sent' @[0.5,1) → 'ua-deleg' @[1.5,2) → 'yield-false' @[5,5.5) → I 판독 회전 기록의 둘째에 timeout · LastKind inside · 양보 1(게이트) · 양보 누적 > 4초 · 스윕 호출 ≥ 4 · 판독 회전 2" `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and ($row.YieldTotalMs -gt 4000) -and ($row.SweepCalls -ge 4) -and (@($row.Reads).Count -eq 2) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 2))) (Format-RowDetail $row)
Check-RowCommon 'N4-L15' $row

# N4-L16 - (B-12) 유예 · (보고) I@0 · R@0.5 · I@1.2 → 'inside' 아닌 유효 분류가 끊은 연속의 유예는 그대로 한 번 → timeout 'inside' · 양보 0
Reset-ReentryRow; Set-ScreenPlan @('I', 0, 'R', 0.5, 'I', 1.2)
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L16 I@0 · R@0.5 · I@1.2 → I 판독 회전 기록의 둘째에 timeout · LastKind inside · 양보 0 · 첫 R 표본 > 0' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 0) -and ((Get-NthTime @(Get-RecordTimes $row -Screen 'R') 1) -gt 0) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 2))) (Format-RowDetail $row)
Check-RowCommon 'N4-L16' $row

# N4-L17 - (J29 ⑤) 유예 · (보고) I 지속 · 캡처 실패 [0.5,3) · 조작 [4.7,6)(탐침이 되살린 직후 조작) → 되돌림 뒤 창이 탐침 복구 뒤 회전을 미룸 → entered
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-FailWindow 0.5 3; Add-ActiveWindow 4.7 6
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
$yieldIndex = Get-EventIndex -Row $row -Kind 'yield'
Check-True "(보고·유예) N4-L17 I 지속 · 실패 [0.5,3) · 조작 [4.7,6) → 실패 없는 판독 회전 기록의 셋째에 entered · LastKind inside · 양보 1 · 양보 바로 앞 사건 = 탐침 성공 · 바로 다음 = 복구 대기" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and ((Get-EventKindAt -Row $row -Index ($yieldIndex - 1)) -ceq 'probe:ok') -and
    ((Get-EventKindAt -Row $row -Index ($yieldIndex + 1)) -ceq "sleep:$RECOVERED_WAIT_MS") -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L17' $row

# N4-L18 - (J29 ⑤) 유예 · (보고) I 지속 · 조작 [0.5,3) · 양보 뒤 첫 회전(@3.0) 하단만 실패·같은 회전 복구(⑦ 복구 회전) → entered · 안전 확인 0
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-ActiveWindow 0.5 3; $script:failHook = $HOOK_PROMPT_FAIL_AT_3_0
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L18 I 지속 · 조작 [0.5,3) · @3.0 회전 하단만 실패(같은 회전 복구) → 실패 없는 판독 회전 기록의 셋째에 entered · inside · 양보 1 · 실패 있는 판독 회전 1 · 안전 확인 0' `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and (@(Get-RecordTimes $row -Failed).Count -eq 1) -and ($row.SafeStops -eq 0) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L18' $row

# N4-L19 - (J29 ⑤) 유예 · (보고) I 지속 · 'ua-deleg' 1회 @[0.5,1) · 캡처 실패 [4.2,6)(다음 회전 게이트 양보 뒤) → entered · 양보 1 · 안전 확인 ≥ 1
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'ua-deleg' -Gap 0.5 -Count 1; Add-FailWindow 4.2 6
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) N4-L19 I 지속 · 'ua-deleg' 1회 · 실패 [4.2,6) → 실패 없는 판독 회전 기록의 셋째에 entered · inside · 양보 1 · 안전 확인 ≥ 1" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and ($row.SafeStops -ge 1) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L19' $row

# N4-L20 - (J29 ⑤) 유예 · (보고) I 지속 · 'yield-false' 1회 @[0.5,1) · 캡처 실패 [0.75,3)(그 회전 판독부터) → entered · 게이트 양보 0 · 양보 누적 > 0 · 안전 확인 ≥ 1
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'yield-false' -Gap 0.1 -Count 1; Add-FailWindow 0.75 3
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) N4-L20 I 지속 · 'yield-false' 1회 · 실패 [0.75,3) → 실패 없는 판독 회전 기록의 셋째에 entered · inside · 게이트 양보 0 · 양보 누적 > 0 · 안전 확인 ≥ 1" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 0) -and ($row.YieldTotalMs -gt 0) -and ($row.SafeStops -ge 1) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L20' $row

# N4-L21 - (J29 ⑤) 유예 · (보고) N4-L12 의 입력 → 받은 창 좌표 throw 회전도 ⑥ 이 되돌림 → entered · waiter 밖 예외 0 · 게이트 양보 0 · 양보 누적 > 0
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.6 -Until 0.8 -Kind 'yield-rect-throw' -Gap 0.1 -Count 1
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
$firedIndex = Get-EventIndex -Row $row -Kind 'sweep' -Time $firedTime
Check-True "(보고·유예) N4-L21 I@0 · @0.7 'yield-rect-throw' → 실패 없는 판독 회전 기록의 셋째에 entered · inside · waiter 밖 예외 0 · 게이트 양보 0 · 양보 누적 > 0 · 그 스윕 사건 바로 다음 사건 = 안전 확인" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Error -ceq '') -and ($row.Yields -eq 0) -and ($row.YieldTotalMs -gt 0) -and
    ((Get-EventKindAt -Row $row -Index ($firedIndex + 1)) -ceq 'safestop') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L21' $row

# N4-L22 - (J29 ⑤ 유한) 유예 · (보고) I@0 · 조작 [0.5,3) · 3초부터 캡처 교대(새 유효 표본이 끝내 오지 않음) → 다섯째 식은 유예 시계(조정 Q)까지만 → timeout 유한
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-ActiveWindow 0.5 3; Set-CaptureAlternate -From 3.0 -Mode 'normal'
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True '(보고·유예) N4-L22 I@0 · 조작 [0.5,3) · 교대 @3~ → 유예 시계 D = Q + 양보 합 + 실패 합(첫 유예가 호출 첫 회전) · D ≤ T < D + 박자에 timeout · inside · 양보 1 · 실패 합 > 0 · VTIMEOUT 0' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'inside') -and ($row.Error -ceq '') -and ($row.Yields -eq 1) -and ($row.FailTotalMs -gt 0) -and
    (Test-DeadlineWindow $row ($Q + ($row.YieldTotalMs + $row.FailTotalMs) / 1000.0))) (Format-RowDetail $row)
Check-RowCommon 'N4-L22' $row

# N4-L23 - (J29 ⑤ 비움) 유예 · (보고) I 지속 · 조작 [0.5,3) · 스윕 'sent' 1회 @[3.5,4)(되돌림 뒤 새 연속을 전송이 끊음) → '한 번' → timeout 'inside'
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-ActiveWindow 0.5 3; Set-SweepFrom -From 3.5 -Until 4.0 -Kind 'sent' -Gap 1 -Count 1
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0) })
Check-True "(보고·유예) N4-L23 I 지속 · 조작 [0.5,3) · 'sent' 1회 @[3.5,4) → I 판독 회전 기록의 셋째에 timeout · LastKind inside · 양보 1 · I 판독 회전 3" `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and (@(Get-RecordTimes $row -Screen 'I').Count -eq 3) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L23' $row

# N4-L24 - (J29 ⑥) -Clock(남은 0.5 - 첫 I 회전엔 본 시계가 남아 유예를 쓰지 않음) + 유예 · (보고) I 지속 · 실패 [0.5,3) · 조작 [4.7,6) → entered
$rowClockSeconds = 0.5
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-FailWindow 0.5 3; Add-ActiveWindow 4.7 6
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock $rowClockSeconds) })
$yieldIndex = Get-EventIndex -Row $row -Kind 'yield'
Check-True "(보고·유예) N4-L24 -Clock(남은 0.5) · I 지속 · 실패 [0.5,3) · 조작 [4.7,6) → 실패 없는 판독 회전 기록의 셋째에 entered · inside · 양보 1 · 양보 바로 앞 = 탐침 성공 · 바로 다음 = 복구 대기" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and ((Get-EventKindAt -Row $row -Index ($yieldIndex - 1)) -ceq 'probe:ok') -and
    ((Get-EventKindAt -Row $row -Index ($yieldIndex + 1)) -ceq "sleep:$RECOVERED_WAIT_MS") -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L24' $row

# N4-L25 - (J29 ⑥) -Clock(남은 0.5) + 유예 · (보고) I 지속 · 'ua-deleg' 1회 @[0.5,1) · 실패 [4.2,6) → entered · 양보 1 · 안전 확인 ≥ 1
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'ua-deleg' -Gap 0.5 -Count 1; Add-FailWindow 4.2 6
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock $rowClockSeconds) })
Check-True "(보고·유예) N4-L25 -Clock(남은 0.5) · I 지속 · 'ua-deleg' 1회 · 실패 [4.2,6) → 실패 없는 판독 회전 기록의 셋째에 entered · inside · 양보 1 · 안전 확인 ≥ 1" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and ($row.SafeStops -ge 1) -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L25' $row

# N4-L26 - (J29 ⑥) -Clock(남은 0.5) + 유예 · (보고) I 지속 · 'yield-false' 1회 @[0.5,1) · 실패 [0.75,3) → entered · 게이트 양보 0 · 양보 누적 > 0 · 안전 확인 ≥ 1
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Set-SweepFrom -From 0.5 -Until 1.0 -Kind 'yield-false' -Gap 0.1 -Count 1; Add-FailWindow 0.75 3
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock $rowClockSeconds) })
Check-True "(보고·유예) N4-L26 -Clock(남은 0.5) · I 지속 · 'yield-false' 1회 · 실패 [0.75,3) → 실패 없는 판독 회전 기록의 셋째에 entered · inside · 게이트 양보 0 · 양보 누적 > 0 · 안전 확인 ≥ 1" `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 0) -and ($row.YieldTotalMs -gt 0) -and ($row.SafeStops -ge 1) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 3))) (Format-RowDetail $row)
Check-RowCommon 'N4-L26' $row

# N4-L27 - (J29 ⑥ 유한) -Clock(남은 0.5) + 유예 · (보고) I@0 · 조작 [0.5,3) · 3초부터 캡처 교대 → 다섯째 식 갈래가 처음 미룬 회전에 정지 유예 시계를 진행 → timeout 유한
Reset-ReentryRow; Set-ScreenPlan @('I', 0); Add-ActiveWindow 0.5 3; Set-CaptureAlternate -From 3.0 -Mode 'normal'
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock $rowClockSeconds) })
$firstDeferTime = Get-FirstProbeOkTime $row
$laterFailSum = Get-IndependentFailSum -Row $row -NotBefore $firstDeferTime
Check-True '(보고·유예) N4-L27 -Clock(남은 0.5) · I@0 · 조작 [0.5,3) · 교대 @3~ → 유예 시계 D = 첫 탐침 성공 시각 + Q + 그 뒤 실패 합 · D ≤ T < D + 박자에 timeout · inside · 양보 1 · 그 실패 합 > 0 · VTIMEOUT 0' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'inside') -and ($row.Error -ceq '') -and ($row.Yields -eq 1) -and ($laterFailSum -gt 0) -and
    (Test-DeadlineWindow $row ($firstDeferTime + $Q + $laterFailSum))) ((Format-RowDetail $row) + (' 첫 미룸={0} 그 뒤 실패 합={1}' -f (Format-Seconds $firstDeferTime), (Format-Seconds $laterFailSum)))
Check-RowCommon 'N4-L27' $row

# N4-L28 - (J29 ⑥ 유예 시계 진행 자리) -Clock(남은 15) + 유예 · (보고) I@0 · 조작 [0.5,3) · U@3 · I@17.5 · 실패 [18,20) → 조작 순간에는 유예 시계를 진행시키지 않음 → entered
$rowClockSeconds = 15
Reset-ReentryRow; Set-ScreenPlan @('I', 0, 'U', 3, 'I', 17.5); Add-ActiveWindow 0.5 3; Add-FailWindow 18.0 20
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock $rowClockSeconds) })
$cleanInsideTimes = @(Get-RecordTimes $row -Screen 'I' -Clean)
Check-True '(보고·유예) N4-L28 -Clock(남은 15) · I@0 · 조작 [0.5,3) · U@3 · I@17.5 · 실패 [18,20) → 실패 없는 I 판독 회전 기록의 셋째에 entered · 그 둘째(첫 유예 회전) ≥ 본 시계 마감(15 + 양보 합) · inside · 양보 1 · 안전 확인 ≥ 1 · 알 수 없음 유효 표본 ≥ 1' `
    (($row.Result -ceq 'entered') -and ($row.LastKind -ceq 'inside') -and ($row.Yields -eq 1) -and ($row.SafeStops -ge 1) -and (@(Get-RecordTimes $row -Screen 'U' -Clean).Count -ge 1) -and
    ($cleanInsideTimes.Count -eq 3) -and (Test-SameTime $row.T (Get-NthTime $cleanInsideTimes 3)) -and ((Get-NthTime $cleanInsideTimes 2) -ge ($rowClockSeconds + $row.YieldTotalMs / 1000.0 - $TIME_EPSILON))) (Format-RowDetail $row)
Check-RowCommon 'N4-L28' $row

# N4-L29 - (J10) U@0 · 캡처 실패 [0.5,3) · I@6 → entered · S2 관측 끊김 1회 (⑧ 계측이 실패 뒤 첫 유효 회전에서 한 번 세고 일련번호를 갱신)
Reset-ReentryRow; Set-ScreenPlan @('U', 0, 'I', 6); Add-FailWindow 0.5 3
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$s2 = Get-S2Facts $row
Check-True 'N4-L29 U@0 · 실패 [0.5,3) · I@6 → 실패 없는 I 판독 회전 기록의 둘째에 entered · S2 1(로딩 ≥ 1 · 필드 0 · 관측 끊김 1) · 안전 확인 ≥ 1 · 탐침 ≥ 1' `
    (($row.Result -ceq 'entered') -and ($row.Error -ceq '') -and ($row.SafeStops -ge 1) -and ($row.Probes -ge 1) -and (@(Get-RecordTimes $row -Screen 'I' -Clean).Count -eq 2) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I' -Clean) 2)) -and ($s2.Count -eq 1) -and $s2.Matched -and ($s2.U -ge 1) -and ($s2.F -eq 0) -and ($s2.B -eq 1)) (Format-RowDetail $row)
Check-RowCommon 'N4-L29' $row

# N4-L30 - (J10 다른 화면 비움) 끊김·U 누적 → 다른 화면 M → U → I·I → 최종 S2 = 다른 화면 뒤 표본만 / 둘째 판 F 누적 → M → U → I·I (필드 두 대입)
Reset-ReentryRow; Set-ScreenPlan @('U', 0, 'M', 7, 'U', 8, 'I', 8.5); Add-FailWindow 0.5 3
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$s2 = Get-S2Facts $row
$cleanMTimes = @(Get-RecordTimes $row -Screen 'M' -Clean)
$lastMTime = Get-NthTime $cleanMTimes $cleanMTimes.Count
$afterMUnknown = @(Get-RecordTimes $row -Screen 'U' -Clean -After $lastMTime).Count
$cleanInsideTimes = @(Get-RecordTimes $row -Screen 'I' -Clean)
Check-True 'N4-L30 U@0 · 실패 [0.5,3) · M@7 · U@8 · I@8.5 → 실패 없는 I 판독 회전 기록의 둘째(첫 I 는 마지막 M 뒤)에 entered · S2 1 · u = 마지막 M 뒤 실패 없는 U 수 · f 0 · b 0 · 앞 구간 전제(마지막 M 앞 U ≥ 1 · 실패 있는 판독 회전 ≥ 1) · 안전 확인 ≥ 1 · 탐침 ≥ 1' `
    (($row.Result -ceq 'entered') -and ($row.Error -ceq '') -and ($row.SafeStops -ge 1) -and ($row.Probes -ge 1) -and ($cleanMTimes.Count -ge 1) -and
    (@(Get-RecordTimes $row -Screen 'U' -Clean -Before $lastMTime).Count -ge 1) -and (@(Get-RecordTimes $row -Failed -Before $lastMTime).Count -ge 1) -and ($afterMUnknown -ge 1) -and
    ($cleanInsideTimes.Count -eq 2) -and ((Get-NthTime $cleanInsideTimes 1) -gt $lastMTime) -and (Test-SameTime $row.T (Get-NthTime $cleanInsideTimes 2)) -and
    ($s2.Count -eq 1) -and $s2.Matched -and ($s2.U -eq $afterMUnknown) -and ($s2.F -eq 0) -and ($s2.B -eq 0)) ((Format-RowDetail $row) + (' 기대 u={0}' -f $afterMUnknown))
Check-RowCommon 'N4-L30' $row
Reset-ReentryRow; Set-ScreenPlan @('F', 0, 'M', 2, 'U', 2.5, 'I', 3)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60 }
$s2 = Get-S2Facts $row
$cleanMTimes = @(Get-RecordTimes $row -Screen 'M' -Clean)
$lastMTime = Get-NthTime $cleanMTimes $cleanMTimes.Count
$afterMUnknown = @(Get-RecordTimes $row -Screen 'U' -Clean -After $lastMTime).Count
$cleanInsideTimes = @(Get-RecordTimes $row -Screen 'I' -Clean)
Check-True 'N4-L30 둘째 판 F@0 · M@2 · U@2.5 · I@3 → 실패 없는 I 판독 회전 기록의 둘째(첫 I 는 마지막 M 뒤)에 entered · S2 1 · u = 마지막 M 뒤 U 수 · f 0 · 첫 필드 모양 토막 없음 · b 0 · 앞 구간 전제(마지막 M 앞 F ≥ 1 · 뒤 F 0)' `
    (($row.Result -ceq 'entered') -and ($row.Error -ceq '') -and ($cleanMTimes.Count -ge 1) -and (@(Get-RecordTimes $row -Screen 'F' -Clean -Before $lastMTime).Count -ge 1) -and
    (@(Get-RecordTimes $row -Screen 'F' -Clean -After $lastMTime).Count -eq 0) -and ($afterMUnknown -ge 1) -and ($cleanInsideTimes.Count -eq 2) -and ((Get-NthTime $cleanInsideTimes 1) -gt $lastMTime) -and
    (Test-SameTime $row.T (Get-NthTime $cleanInsideTimes 2)) -and ($s2.Count -eq 1) -and $s2.Matched -and ($s2.U -eq $afterMUnknown) -and ($s2.F -eq 0) -and (-not $s2.HasPart) -and ($s2.B -eq 0)) `
    ((Format-RowDetail $row) + (' 기대 u={0}' -f $afterMUnknown))
Check-RowCommon 'N4-L30 둘째 판' $row

# ── 구현 단위 5b-8 FC-L - 필드 결과 켬(-ReportFieldReturn) 대기 루프 행 (명세 5b-8 1절 · 3.2 · 3.7a · 설계 v11 R5 2.1·2.2 끊김 표). 확정 시각은 판독 기록과 W(소스 캡처)에서 셉니다 ──
$fieldArguments = @{ Game = $null; LimitSeconds = 60; ReportRewardReturn = $true; ReportFieldReturn = $true }   # 원 워커 우연한 만남 '다시 하기' 대기(호출 B)의 두 스위치
$rowBeat = $BASE_WAIT_MS / 1000.0
$rowSpan = [Math]::Ceiling([double]$memberFieldSettleSeconds / $rowBeat - $TIME_EPSILON) * $rowBeat   # W 를 박자로 올린 확정 폭 (FC-L12 의 시각표만 씀)

# FC-L1 - 재매칭 패널 M@0 · 로딩 U@2.05 · 필드 모양 F@5.05 지속(10-28 1-I ② 꼴) → 첫 F 부터 W 이상인 첫 F 회전에 field-cancelled
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 2.05, 'F', 5.05)
$row = Invoke-ReentryRow $fieldArguments
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean) 1
$settleFacts = Get-SettleFacts $row
Check-True "(보고·필드 결과) FC-L1 M@0 · U@2.05 · F@5.05 지속 → 첫 F 표본부터 W 이상 지난 첫 F 회전에 field-cancelled · LastKind field · PanelSeen 참 · 확정 줄 1(w = W · s · n) · 줄 = [패널 확인, 확정 줄] · S2 0" `
    (($row.Result -ceq 'field-cancelled') -and ($row.LastKind -ceq 'field') -and ($row.PanelSeen -eq $true) -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and
    (Test-SettleLine -Row $row -Start $fieldStart) -and (@($row.S2).Count -eq 0) -and ((@($row.Logs) -join '|') -ceq ($PANEL_NOTICE_TEXT + '|' + $settleFacts.Text))) `
    ((Format-RowDetail $row) + (' 확정 줄=[{0}]' -f $settleFacts.Text))
Check-RowCommon 'FC-L1' $row

# FC-L2 - FC-L1 의 입력 · 필드 결과 끔(보고만 - HEAD 호출 B 그대로) → L 에 timeout · LastKind field · 확정 줄 0 / FC-L18 - 같은 행에서 선택 화면 · 메뉴 판독 0(필드 결과 끔은 지금과 같음)
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 2.05, 'F', 5.05); $rowLimit = 60
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit; ReportRewardReturn = $true }
Check-True '(보고) FC-L2 FC-L1 의 입력 · 필드 결과 끔 → L ≤ T < L + 박자에 timeout · LastKind field · PanelSeen 참 · 확정 줄 0' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'field') -and ($row.PanelSeen -eq $true) -and (Test-DeadlineWindow $row $rowLimit) -and ((Get-SettleFacts $row).Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'FC-L2' $row
Check-True '(보고) FC-L18 FC-L2 의 행 - 필드 결과 끔이면 필드 모양 회전에도 선택 화면 · 메뉴 판독 0 (2.2-4a 는 필드 결과 켬만)' `
    (((Get-OverlayReadCount $row 'selection') -eq 0) -and ((Get-OverlayReadCount $row 'menu') -eq 0) -and (@(Get-RecordTimes $row -Screen 'F').Count -ge 1)) `
    ((Format-RowDetail $row) + (' 판독 selection={0} menu={1}' -f (Get-OverlayReadCount $row 'selection'), (Get-OverlayReadCount $row 'menu')))

# FC-L3 - 패널을 한 번도 못 봄 (가) U@0 · F@3.05 / (나) 10-28 1차 판 꼴: 첫 회전 조작 [0,3) 동안 M 이 지나감(M@0 · U@2.05 · F@6.05) → 둘 다 field-cancelled · PanelSeen 거짓 · 패널 확인 0
Reset-ReentryRow; Set-ScreenPlan @('U', 0, 'F', 3.05)
$row = Invoke-ReentryRow $fieldArguments
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean) 1
Check-True '(보고·필드 결과) FC-L3 (가) U@0 · F@3.05 → 첫 F 부터 W 뒤 field-cancelled · PanelSeen 거짓 · 패널 확인 0 · 확정 줄 1 (사용자 결정 U-5b8-1 - 패널 관측과 무관)' `
    (($row.Result -ceq 'field-cancelled') -and ($row.PanelSeen -eq $false) -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and ((Get-PanelNoticeCount $row) -eq 0) -and
    (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L3 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 2.05, 'F', 6.05); Add-ActiveWindow 0 3
$row = Invoke-ReentryRow $fieldArguments
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean) 1
Check-True '(보고·필드 결과) FC-L3 (나) 첫 회전 조작 [0,3) · M@0~2 · U@2.05 · F@6.05 → M 판독 0 · 양보 1 · 첫 F 부터 W 뒤 field-cancelled · PanelSeen 거짓 · 패널 확인 0' `
    (($row.Result -ceq 'field-cancelled') -and ($row.PanelSeen -eq $false) -and ($row.Yields -eq 1) -and (@(Get-RecordTimes $row -Screen 'M').Count -eq 0) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and ((Get-PanelNoticeCount $row) -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'FC-L3 (나)' $row

# FC-L4 - 10-28 1차 판 재생(클릭 기준 양보 [2,5)·[9,13)·[21,36) - run_20261028_h21m01s11.log 20:55:50~56:24 · M@0 · U@3.55(관측기 이멘마하 +4) · F@7.95) → 둘째 양보 끝부터 W 뒤
#   field-cancelled · 셋째 양보 전에 끝남
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 3.55, 'F', 7.95); Add-ActiveWindow 2 5; Add-ActiveWindow 9 13; Add-ActiveWindow 21 36
$row = Invoke-ReentryRow $fieldArguments
$lastYieldEnd = $(if (@($row.YieldEnds).Count -ge 1) { [double]@($row.YieldEnds)[-1] } else { [double]::NaN })
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -NotBefore $lastYieldEnd) 1
Check-True '(보고·필드 결과) FC-L4 10-28 1차 꼴 - 양보 [2,5)·[9,13)·[21,36) · M@0 · U@3.55 · F@7.95 → 양보 2(셋째 전 끝) · 마지막 양보 끝 뒤 첫 F 부터 W 뒤 field-cancelled · 앞 F(양보 앞) ≥ 1 · 확정 줄 n = 마지막 양보 뒤 F 수 · 패널 확인 1' `
    (($row.Result -ceq 'field-cancelled') -and ($row.Yields -eq 2) -and (@(Get-RecordTimes $row -Screen 'F' -Clean -Before $lastYieldEnd).Count -ge 1) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and (Test-SettleLine -Row $row -Start $fieldStart) -and ((Get-PanelNoticeCount $row) -eq 1)) (Format-RowDetail $row)
Check-RowCommon 'FC-L4' $row

# FC-L4″ - 10-28 2차 판 재생(클릭 기준 양보 [4,6)·[10,21)·[111,115) - run_20261028_h21m15s22.log 21:10:08~21:11:59 · M@0 · U@4.55(관측기 이멘마하 +5.5) · F@9.45) → 둘째 양보 끝부터 W 뒤
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 4.55, 'F', 9.45); Add-ActiveWindow 4 6; Add-ActiveWindow 10 21; Add-ActiveWindow 111 115
$row = Invoke-ReentryRow $fieldArguments
$lastYieldEnd = $(if (@($row.YieldEnds).Count -ge 1) { [double]@($row.YieldEnds)[-1] } else { [double]::NaN })
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -NotBefore $lastYieldEnd) 1
Check-True '(보고·필드 결과) FC-L4″ 10-28 2차 꼴 - 양보 [4,6)·[10,21)·[111,115) · M@0 · U@4.55 · F@9.45 → 양보 2 · 마지막 양보 끝 뒤 첫 F 부터 W 뒤 field-cancelled · 양보 앞 F ≥ 1' `
    (($row.Result -ceq 'field-cancelled') -and ($row.Yields -eq 2) -and (@(Get-RecordTimes $row -Screen 'F' -Clean -Before $lastYieldEnd).Count -ge 1) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L4″' $row

# FC-L4′ (고치기 전 재현의 대기 몫) - FC-L4 의 입력 · 필드 결과 끔 → 양보 셋 모두 · D = L + 양보 합에 timeout · LastKind field (HEAD 10-28: 300초 + 양보 22초)
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 3.55, 'F', 7.95); Add-ActiveWindow 2 5; Add-ActiveWindow 9 13; Add-ActiveWindow 21 36; $rowLimit = 60
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit; ReportRewardReturn = $true }
Check-True '(보고) FC-L4′ FC-L4 의 입력 · 필드 결과 끔 → 양보 3 · D = L + 양보 합 · D ≤ T < D + 박자에 timeout · LastKind field · 확정 줄 0' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'field') -and ($row.Yields -eq 3) -and (Test-DeadlineWindow $row ($rowLimit + $row.YieldTotalMs / 1000.0)) -and ((Get-SettleFacts $row).Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'FC-L4′' $row

# FC-L5 - 양보 셋이 모두 F 를 끊는 꼴(3·4·15초 - [2,5)·[9,13)·[17,32) · M@0 · U@1.05 · F@3.05) → 마지막 양보 끝 뒤 첫 F 부터 W 뒤 field-cancelled · 확정 줄 n 은 마지막 연속만(계측 $runField 아님)
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 1.05, 'F', 3.05); Add-ActiveWindow 2 5; Add-ActiveWindow 9 13; Add-ActiveWindow 17 32
$row = Invoke-ReentryRow $fieldArguments
$yieldEndTimes = @($row.YieldEnds)
$lastYieldEnd = $(if ($yieldEndTimes.Count -ge 1) { [double]$yieldEndTimes[-1] } else { [double]::NaN })
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -NotBefore $lastYieldEnd) 1
$runsBetween = $(if ($yieldEndTimes.Count -ge 2) { @(Get-RecordTimes $row -Screen 'F' -Clean -NotBefore $yieldEndTimes[0] -Before $yieldEndTimes[1]).Count } else { -1 })
Check-True '(보고·필드 결과) FC-L5 양보 [2,5)·[9,13)·[17,32) 가 F 연속(각 W 미만)을 끊음 → 양보 3 · 양보 사이 F ≥ 2 · 마지막 양보 끝 뒤 첫 F 부터 W 뒤 field-cancelled · 확정 줄 n = 마지막 연속 수' `
    (($row.Result -ceq 'field-cancelled') -and ($row.Yields -eq 3) -and ($runsBetween -ge 2) -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and
    (Test-SettleLine -Row $row -Start $fieldStart)) ((Format-RowDetail $row) + (' 양보 사이 F={0}' -f $runsBetween))
Check-RowCommon 'FC-L5' $row

# FC-L6 - ⑥ 간접 양보(WA-L42 꼴 - F 지속 · @1.4 회전 스윕 'yield-false' Gap 3) → 그 회전 표본이 양보 뒤 새 시각에서 1표본 → 그 시각 + W 뒤 field-cancelled · 게이트 양보 0
Reset-ReentryRow; Set-ScreenPlan @('F', 0); Set-SweepFrom -From 1.35 -Until 1.45 -Kind 'yield-false' -Gap 3 -Count 1
$row = Invoke-ReentryRow $fieldArguments
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $firedTime) 1
Check-True "(보고·필드 결과) FC-L6 F 지속 · @1.4 'yield-false' Gap 3 → 그 회전 판독 = 스윕 진입 + 3(양보 뒤 새 시각) · 그 시각부터 W 뒤 field-cancelled · 게이트 양보 0 · 양보 누적 > 0 · 앞 F ≥ 1 · 확정 줄 s·n 은 양보 뒤 표본부터" `
    (($row.Result -ceq 'field-cancelled') -and ($row.Yields -eq 0) -and ($row.YieldTotalMs -gt 0) -and (@(Get-RecordTimes $row -Screen 'F' -Clean -Before $firedTime).Count -ge 1) -and
    ($fieldStart -gt ($firedTime + $TIME_EPSILON)) -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L6' $row

# FC-L7 - 동결 (가) F 지속 + 캡처 실패 [3,5) → 실패 끝 뒤 첫 F 부터 W 뒤 / (나) 실패 [0,2) · L 9 → 명목 마감 L 뒤에 field-cancelled (실패 시간이 마감에서 빠짐 - 규칙 15)
Reset-ReentryRow; Set-ScreenPlan @('F', 0); Add-FailWindow 3 5
$row = Invoke-ReentryRow $fieldArguments
$failEnd = $(if (@($row.FailEnds).Count -ge 1) { [double]$row.FailEnds[0] } else { [double]::NaN })
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $failEnd) 1
Check-True '(보고·필드 결과) FC-L7 (가) F 지속 + 실패 [3,5) → 안전 확인 ≥ 1 · 탐침 ≥ 1 · 실패 합 > 0 · 실패 앞 F ≥ 1 · 실패 끝 뒤 첫 F 부터 W 뒤 field-cancelled · 확정 줄 n 은 실패 뒤 F 만' `
    (($row.Result -ceq 'field-cancelled') -and ($row.SafeStops -ge 1) -and ($row.Probes -ge 1) -and ($row.FailTotalMs -gt 0) -and (@(Get-RecordTimes $row -Screen 'F' -Clean -Before $failEnd).Count -ge 1) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L7 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('F', 0); Add-FailWindow 0 2; $rowLimit = 9
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit; ReportRewardReturn = $true; ReportFieldReturn = $true }
$failEnd = $(if (@($row.FailEnds).Count -ge 1) { [double]$row.FailEnds[0] } else { [double]::NaN })
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $failEnd) 1
Check-True '(보고·필드 결과) FC-L7 (나) 실패 [0,2) · L 9 → L < T < L + 실패 합에 field-cancelled (실패 끝 뒤 첫 F 부터 W 뒤)' `
    (($row.Result -ceq 'field-cancelled') -and ($row.T -gt ($rowLimit + $TIME_EPSILON)) -and ($row.T -lt ($rowLimit + $row.FailTotalMs / 1000.0 - $TIME_EPSILON)) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart))) (Format-RowDetail $row)
Check-RowCommon 'FC-L7 (나)' $row

# FC-L8 - 스윕 참 1회전('sent' Gap 1 @2.8 → 'counted') → 스윕 뒤 첫 F 부터 W 뒤 field-cancelled
Reset-ReentryRow; Set-ScreenPlan @('F', 0); Set-SweepFrom -From 2.75 -Until 2.85 -Kind 'sent' -Gap 1 -Count 1
$row = Invoke-ReentryRow $fieldArguments
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $firedTime) 1
Check-True "(보고·필드 결과) FC-L8 F 지속 · 'sent' Gap 1 @2.8 → 분류 counted · 스윕 앞 F ≥ 1 · 스윕 뒤 첫 F 부터 W 뒤 field-cancelled" `
    (($row.Result -ceq 'field-cancelled') -and (@($row.SweepActions) -ccontains 'counted') -and (@(Get-RecordTimes $row -Screen 'F' -Clean -Before $firedTime).Count -ge 1) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L8' $row

# FC-L9 - (가) ⑦ 같은 회전 복구가 확정될 회전(@6.3)에 남 → 그 회전 확정 0 · 복구 뒤 첫 F 부터 W 뒤 / (나) 스윕 안 복구('recover' @2.8 → 'recovered') → 복구 뒤 첫 F 부터 W 뒤
Reset-ReentryRow; Set-ScreenPlan @('F', 0); $script:failHook = $HOOK_PROMPT_FAIL_AT_6_3
$row = Invoke-ReentryRow $fieldArguments
$failedTime = Get-NthTime @(Get-RecordTimes $row -Failed) 1
$firstFieldTime = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean) 1
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $failedTime) 1
Check-True '(보고·필드 결과) FC-L9 (가) F 지속 · @6.3 회전 하단만 실패(⑦ 복구 회전) → 그 회전 ≥ 첫 F + W(확정될 회전이었음) · 실패 회전 1 · 복구 뒤 첫 F 부터 W 뒤 field-cancelled' `
    (($row.Result -ceq 'field-cancelled') -and (@(Get-RecordTimes $row -Failed).Count -eq 1) -and ($failedTime -ge ($firstFieldTime + [double]$memberFieldSettleSeconds - $TIME_EPSILON)) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L9 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('F', 0); Set-SweepFrom -From 2.75 -Until 2.85 -Kind 'recover' -Gap 1 -Count 1
$row = Invoke-ReentryRow $fieldArguments
$firedTime = $(if (@($row.SweepFired).Count -ge 1) { [double]$row.SweepFired[0].T } else { [double]::NaN })
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $firedTime) 1
Check-True "(보고·필드 결과) FC-L9 (나) F 지속 · 'recover' Gap 1 @2.8 → 분류 recovered · 복구 뒤 첫 F 부터 W 뒤 field-cancelled" `
    (($row.Result -ceq 'field-cancelled') -and (@($row.SweepActions) -ccontains 'recovered') -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and
    (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L9 (나)' $row

# FC-L10 - (가) 입장 과도: F@0 · I@(W − 0.1) → 확정 0 · I 둘째에 entered · S2(f = F 수 · s = 첫 I − 첫 F) / (나) WA-L26 꼴 + 필드 결과 켬: F@0 · I@20 → W 뒤 field-cancelled
#   (I 판독 0 - 명세 7절 위험(필드 모양이 끊김 없이 W 이어지면 새 판에 들어간 캐릭터를 두고 정지)을 행으로 고정)
Reset-ReentryRow; Set-ScreenPlan @('F', 0, 'I', ([double]$memberFieldSettleSeconds - 0.1))
$row = Invoke-ReentryRow $fieldArguments
$s2 = Get-S2Facts $row
$fieldTimes = @(Get-RecordTimes $row -Screen 'F' -Clean)
$fieldToInsideSeconds = [Math]::Round((Get-NthTime @(Get-RecordTimes $row -Screen 'I') 1) - (Get-NthTime $fieldTimes 1), 1)
Check-True '(보고·필드 결과) FC-L10 (가) F@0 · I@(W−0.1) → 마지막 F − 첫 F < W · I 판독 둘째에 entered · 확정 줄 0 · S2 1(f = F 수 · s = 첫 I − 첫 F)' `
    (($row.Result -ceq 'entered') -and ((Get-NthTime $fieldTimes $fieldTimes.Count) - (Get-NthTime $fieldTimes 1) -lt [double]$memberFieldSettleSeconds) -and
    (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'I') 2)) -and ((Get-SettleFacts $row).Count -eq 0) -and ($s2.Count -eq 1) -and $s2.Matched -and ($s2.F -eq $fieldTimes.Count) -and
    $s2.HasPart -and ([Math]::Abs($s2.S - $fieldToInsideSeconds) -lt 0.01)) (Format-RowDetail $row)
Check-RowCommon 'FC-L10 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('F', 0, 'I', 20)
$row = Invoke-ReentryRow $fieldArguments
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean) 1
Check-True '(보고·필드 결과) FC-L10 (나) WA-L26 입력(F@0 · I@20) + 필드 결과 켬 → 첫 F 부터 W 뒤 field-cancelled · I 판독 0 · S2 0' `
    (($row.Result -ceq 'field-cancelled') -and (@(Get-RecordTimes $row -Screen 'I').Count -eq 0) -and (@($row.S2).Count -eq 0) -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart))) (Format-RowDetail $row)
Check-RowCommon 'FC-L10 (나)' $row

# FC-L11 - (가) 보스 이펙트 꼴: 회전마다 F/I 교대(교대점은 박자 가운데) · L 30 → 확정 0 · 입장 0 · L 에 timeout / (나) F@0 · U@2.05 · F@4.05 → U 뒤 첫 F 부터 W 뒤
$rowLimit = 30
$alternatePlan = @()
for ($alternateIndex = 0; ($alternateIndex * $rowBeat) -le ($rowLimit + 2 * $rowBeat); $alternateIndex++) {
    $alternatePlan += $(if (($alternateIndex % 2) -eq 0) { 'F' } else { 'I' })
    $alternatePlan += [Math]::Max([double]0, $alternateIndex * $rowBeat - $rowBeat / 2)   # [double] 필수 - 첫 인자가 int 면 PS 5.1 이 Max(int,int) 를 골라 0.35 → 0 으로 반올림
}
Reset-ReentryRow; Set-ScreenPlan $alternatePlan
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit; ReportRewardReturn = $true; ReportFieldReturn = $true }
$lastReadKind = $(if (@($row.Reads).Count -ge 1) { [string]$SCREEN_KINDS[[string]@($row.Reads)[-1].S] } else { '' })
Check-True '(보고·필드 결과) FC-L11 (가) F/I 회전 교대 · L 30 → L ≤ T < L + 박자에 timeout · LastKind = 마지막 판독 분류 · 확정 줄 0 · S2 0 · F ≥ 2 · I ≥ 2' `
    (($row.Result -ceq 'timeout') -and (Test-DeadlineWindow $row $rowLimit) -and ($row.LastKind -ceq $lastReadKind) -and ((Get-SettleFacts $row).Count -eq 0) -and (@($row.S2).Count -eq 0) -and
    (@(Get-RecordTimes $row -Screen 'F' -Clean).Count -ge 2) -and (@(Get-RecordTimes $row -Screen 'I' -Clean).Count -ge 2)) (Format-RowDetail $row)
Check-RowCommon 'FC-L11 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('F', 0, 'U', 2.05, 'F', 4.05)
$row = Invoke-ReentryRow $fieldArguments
$unknownTimes = @(Get-RecordTimes $row -Screen 'U' -Clean)
$lastUnknown = Get-NthTime $unknownTimes $unknownTimes.Count
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $lastUnknown) 1
Check-True '(보고·필드 결과) FC-L11 (나) F@0 · U@2.05 · F@4.05 → U 앞 F ≥ 1 · 마지막 U 뒤 첫 F 부터 W 뒤 field-cancelled' `
    (($row.Result -ceq 'field-cancelled') -and (@(Get-RecordTimes $row -Screen 'F' -Clean -Before $lastUnknown).Count -ge 1) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L11 (나)' $row

# FC-L12 - 마감 경계(WA-L15 꼴): L 28(박자 정수배) · 확정 회전 = 마감 회전 → T = L 에 field-cancelled (⑨ 가 같은 회전 ⑩ 보다 먼저)
$rowLimit = 28
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'F', ($rowLimit - $rowSpan - $rowBeat / 2))
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit; ReportRewardReturn = $true; ReportFieldReturn = $true }
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean) 1
Check-True '(보고·필드 결과) FC-L12 L 28 · M@0 · F@(L − 확정 폭 − 반 박자) → 마감 경계 회전 T = L 에 field-cancelled (= 첫 F 부터 W 뒤)' `
    (($row.Result -ceq 'field-cancelled') -and (Test-SameTime $row.T $rowLimit) -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart))) (Format-RowDetail $row)
Check-RowCommon 'FC-L12' $row

# FC-L13 - 재매칭 패널 확인 1회 (보고 켬 · 패널류 ready·matching·entry-waiting 첫 회전 - 판정 무관 관측 줄)
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'Rd', 2.05, 'M', 4.05, 'R', 6.05)
$row = Invoke-ReentryRow $fieldArguments
Check-True '(보고·필드 결과) FC-L13 (가) M@0 · Rd@2.05 · M@4.05 · R@6.05 → 첫 R 에 cancelled · 줄 = [패널 확인] 하나' `
    (($row.Result -ceq 'cancelled') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Screen 'R') 1)) -and ((@($row.Logs) -join '|') -ceq $PANEL_NOTICE_TEXT)) (Format-RowDetail $row)
Check-RowCommon 'FC-L13 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('E', 0, 'R', 3.05)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60; ReportRewardReturn = $true }
Check-True '(보고) FC-L13 (나) E@0 · R@3.05 → cancelled · 패널 확인 1 (접힌 준비 패널도 패널류)' (($row.Result -ceq 'cancelled') -and ((Get-PanelNoticeCount $row) -eq 1)) (Format-RowDetail $row)
Check-RowCommon 'FC-L13 (나)' $row
Reset-ReentryRow; Set-ScreenPlan @('U', 0, 'P', 1.05, 'R', 3.05)
$row = Invoke-ReentryRow $fieldArguments
Check-True '(보고·필드 결과) FC-L13 (다) U@0 · P@1.05 · R@3.05 → cancelled · 팝업 안내 1 · 패널 확인 0 (팝업은 패널 관측이지만 안내 대상 아님)' `
    (($row.Result -ceq 'cancelled') -and ($row.NoticeCount -eq 1) -and ((Get-PanelNoticeCount $row) -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'FC-L13 (다)' $row
Reset-ReentryRow; Set-ScreenPlan @('M', 0); $rowLimit = 30
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit }
Check-True 'FC-L13 (라) 보고 끔 · M 지속 → timeout · 패널 확인 0 · 줄 0' (($row.Result -ceq 'timeout') -and ((Get-PanelNoticeCount $row) -eq 0) -and (@($row.Logs).Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'FC-L13 (라)' $row
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'F', 3.05)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 60; ReportFieldReturn = $true }
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean) 1
Check-True '(필드 결과만) FC-L13 (마) 보고 끔 · 필드 결과 켬 · M@0 · F@3.05 → 첫 F 부터 W 뒤 field-cancelled · 패널 확인 0 (안내는 보고 켬 호출 몫) · 확정 줄 1' `
    (($row.Result -ceq 'field-cancelled') -and ((Get-PanelNoticeCount $row) -eq 0) -and ((Get-SettleFacts $row).Count -eq 1) -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart))) (Format-RowDetail $row)
Check-RowCommon 'FC-L13 (마)' $row
Reset-ReentryRow; Set-ScreenPlan @('R', 0); Add-ActiveWindow 0 3
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = 120; ReportRewardReturn = $true; PanelSeen = $true; ReportFieldReturn = $true }
Check-True '(보고·필드 결과·-PanelSeen 참) FC-L13 (바) WA-L41 꼴 → cancelled · 패널 확인 0 (입력 PanelSeen 은 안내하지 않음 - 이 호출에서 읽은 패널류만)' `
    (($row.Result -ceq 'cancelled') -and ((Get-PanelNoticeCount $row) -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'FC-L13 (바)' $row
Reset-ReentryRow; Set-ScreenPlan @('Rd', 0, 'R', 3.05)
$row = Invoke-ReentryRow $fieldArguments
Check-True '(보고·필드 결과) FC-L13 (사) Rd@0 · R@3.05 → cancelled · 패널 확인 1 (준비 패널이 첫 패널류여도 안내 대상)' (($row.Result -ceq 'cancelled') -and ((Get-PanelNoticeCount $row) -eq 1)) (Format-RowDetail $row)
Check-RowCommon 'FC-L13 (사)' $row

# FC-L14 - (보고·유예·필드 결과) -Clock(남은 0) · F 지속 → 첫 유효 회전 timeout (확정 전 필드 모양은 유예하지 않음 - WA-L33 (아) 와 같음)
Reset-ReentryRow; Set-ScreenPlan @('F', 0)
$row = Invoke-ReentryRow ($graceArguments + @{ Clock = (New-RemainingClock 0); ReportFieldReturn = $true })
Check-True '(보고·유예·필드 결과) FC-L14 -Clock(남은 0) · F 지속 → 첫 유효 회전에 timeout · LastKind field · 확정 줄 0' `
    (($row.Result -ceq 'timeout') -and ($row.LastKind -ceq 'field') -and (Test-SameTime $row.T (Get-NthTime @(Get-RecordTimes $row -Clean) 1)) -and ((Get-SettleFacts $row).Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'FC-L14' $row

# FC-L15 - (보고·필드 결과) R 지속 → Q 에 reclick (WA-L16 과 같음 - 새 스위치가 3버튼 갈래를 바꾸지 않음)
Reset-ReentryRow; Set-ScreenPlan @('R', 0)
$row = Invoke-ReentryRow $fieldArguments
Check-True '(보고·필드 결과) FC-L15 R 지속 → Q ≤ T < Q + 박자에 reclick · 줄 0' (($row.Result -ceq 'reclick') -and (Test-DeadlineWindow $row $Q) -and (@($row.Logs).Count -eq 0)) (Format-RowDetail $row)
Check-RowCommon 'FC-L15' $row

# FC-L16 - (2.2-4a · 설계 리뷰 P2) ESC 메뉴가 열린 채 'Home' 배지가 HUD 로 읽힌 화면(Mn - 앞 분류 'field' → 선택 화면 거짓 · 메뉴 참 → 'menu')은 필드 모양이 아님:
#   (가) F@0 · Mn@3.05 지속 · L 30 → 확정 0 · L 에 timeout · LastKind menu / (나) F@0 · Mn@3.05 · F@9.05 → 메뉴가 연속을 끊고 메뉴 뒤 첫 F 부터 W 뒤 field-cancelled
$rowLimit = 30
Reset-ReentryRow; Set-ScreenPlan @('F', 0, 'Mn', 3.05)
$row = Invoke-ReentryRow @{ Game = $null; LimitSeconds = $rowLimit; ReportRewardReturn = $true; ReportFieldReturn = $true }
Check-True '(보고·필드 결과) FC-L16 (가) F@0 · Mn@3.05 지속 · L 30 → L ≤ T < L + 박자에 timeout · LastKind menu · 확정 줄 0 · 메뉴 판독 ≥ 1 (메뉴 동안 정지하지 않음)' `
    (($row.Result -ceq 'timeout') -and (Test-DeadlineWindow $row $rowLimit) -and ($row.LastKind -ceq 'menu') -and ((Get-SettleFacts $row).Count -eq 0) -and ((Get-OverlayReadCount $row 'menu') -ge 1)) (Format-RowDetail $row)
Check-RowCommon 'FC-L16 (가)' $row
Reset-ReentryRow; Set-ScreenPlan @('F', 0, 'Mn', 3.05, 'F', 9.05)
$row = Invoke-ReentryRow $fieldArguments
$menuTimes = @(Get-RecordTimes $row -Screen 'Mn' -Clean)
$lastMenu = Get-NthTime $menuTimes $menuTimes.Count
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $lastMenu) 1
Check-True '(보고·필드 결과) FC-L16 (나) F@0 · Mn@3.05 · F@9.05 → 메뉴 앞 F ≥ 1 · 메뉴 판독 회전 ≥ 1 · 마지막 메뉴 뒤 첫 F 부터 W 뒤 field-cancelled · 확정 줄 n 은 메뉴 뒤 F 만' `
    (($row.Result -ceq 'field-cancelled') -and (@(Get-RecordTimes $row -Screen 'F' -Clean -Before $lastMenu).Count -ge 1) -and ($menuTimes.Count -ge 1) -and
    (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and (Test-SettleLine -Row $row -Start $fieldStart)) (Format-RowDetail $row)
Check-RowCommon 'FC-L16 (나)' $row

# FC-L17 - (2.2-4a) 선택 화면(Sl - 앞 분류 'field' → 선택 화면 참 → 'selection' · 메뉴는 읽지 않음)도 연속을 끊음: F@0 · Sl@3.05 · F@9.05 → 선택 화면 뒤 첫 F 부터 W 뒤 field-cancelled ·
#   선택 화면 판독 = F + Sl 판독 회전 · 메뉴 판독 = F 판독 회전(선택 화면 참이면 메뉴를 읽지 않음)
Reset-ReentryRow; Set-ScreenPlan @('F', 0, 'Sl', 3.05, 'F', 9.05)
$row = Invoke-ReentryRow $fieldArguments
$selectionTimes = @(Get-RecordTimes $row -Screen 'Sl' -Clean)
$lastSelection = Get-NthTime $selectionTimes $selectionTimes.Count
$fieldStart = Get-NthTime @(Get-RecordTimes $row -Screen 'F' -Clean -After $lastSelection) 1
$fieldReadCount = @(Get-RecordTimes $row -Screen 'F').Count
Check-True '(보고·필드 결과) FC-L17 F@0 · Sl@3.05 · F@9.05 → 선택 화면 판독 회전 ≥ 1 · 마지막 선택 화면 뒤 첫 F 부터 W 뒤 field-cancelled · 선택 화면 판독 = F + Sl 회전 · 메뉴 판독 = F 회전' `
    (($row.Result -ceq 'field-cancelled') -and ($selectionTimes.Count -ge 1) -and (Test-SameTime $row.T (Get-SettleExpectedT -Row $row -Start $fieldStart)) -and
    ((Get-OverlayReadCount $row 'selection') -eq ($fieldReadCount + $selectionTimes.Count)) -and ((Get-OverlayReadCount $row 'menu') -eq $fieldReadCount)) `
    ((Format-RowDetail $row) + (' 판독 selection={0} menu={1} F 회전={2}' -f (Get-OverlayReadCount $row 'selection'), (Get-OverlayReadCount $row 'menu'), $fieldReadCount))
Check-RowCommon 'FC-L17' $row

# FC-L19 - (2.2-4a 설계 합의 - 'unknown' 회전은 읽지 않음) 필드 결과 켬 · M@0 · U@2.05 · I@4.05 → entered · 선택 화면 · 메뉴 판독 0 (패널 · 로딩 · 던전 안 회전은 앞 분류가 'field' 아님)
Reset-ReentryRow; Set-ScreenPlan @('M', 0, 'U', 2.05, 'I', 4.05)
$row = Invoke-ReentryRow $fieldArguments
Check-True '(보고·필드 결과) FC-L19 M@0 · U@2.05 · I@4.05 → entered · U 판독 ≥ 1 · 선택 화면 · 메뉴 판독 0' `
    (($row.Result -ceq 'entered') -and (@(Get-RecordTimes $row -Screen 'U' -Clean).Count -ge 1) -and ((Get-OverlayReadCount $row 'selection') -eq 0) -and ((Get-OverlayReadCount $row 'menu') -eq 0)) `
    ((Format-RowDetail $row) + (' 판독 selection={0} menu={1}' -f (Get-OverlayReadCount $row 'selection'), (Get-OverlayReadCount $row 'menu')))
Check-RowCommon 'FC-L19' $row

# ── §8 정적 (명세 3.5 - 주석 제거 사본 · AST · 뜻 판정. R5-P14 다섯 식(구현 명세 ⑤c 부터 재개 유예 판정 Resolve-AbyssResumeGrace 의 if 다섯 · 소스 차례) · R5-P2 Resume 자리 · N4-P10 생성 두 문장 · R5-P7 우변 '0' 은 구현 형상 계약 -
#    같은 뜻의 다른 꼴을 택하면 그 단언을 구현과 함께 갱신) ───────────────────────────────────────────────────────────────────────────
$waiterNode = $workerFunctions['Wait-AbyssReentry']
$verdictNode = $workerFunctions['Resolve-AbyssReentryVerdict']
$waiterCode = Get-NodeCode $waiterNode
$waiterWhiles = @($waiterNode.FindAll({ param($candidate) $candidate -is [WhileStatementAst] }, $true))
$waiterWhile = $(if ($waiterWhiles.Count -ge 1) { $waiterWhiles[0] } else { $null })
$whileStart = $(if ($null -ne $waiterWhile) { $waiterWhile.Extent.StartOffset } else { [int]::MaxValue })
function Test-InsideWhile { param($Node) return (($null -ne $waiterWhile) -and (Test-AstWithin -Node $Node -Ancestor $waiterWhile)) }
function Test-BeforeWhile { param($Node) return ($Node.Extent.EndOffset -le $whileStart) }

# 대표 노드들 - 정적 단언이 함께 씁니다
$IS_MESSAGE_SUBJECT = { param($Node) ($Node -is [MemberExpressionAst]) -and (-not ($Node -is [InvokeMemberExpressionAst])) -and (-not $Node.Static) -and ($Node.Member.Extent.Text -eq 'Message') -and
    ($Node.Expression -is [MemberExpressionAst]) -and (-not ($Node.Expression -is [InvokeMemberExpressionAst])) -and ($Node.Expression.Member.Extent.Text -eq 'Exception') -and
    ($Node.Expression.Expression -is [VariableExpressionAst]) -and (@('_', 'PSItem') -contains $Node.Expression.Expression.VariablePath.UserPath) }
$IS_ACTION_SUBJECT = { param($Node) ($Node -is [MemberExpressionAst]) -and (-not ($Node -is [InvokeMemberExpressionAst])) -and (-not $Node.Static) -and ($Node.Member.Extent.Text -eq 'Action') -and
    ($Node.Expression -is [VariableExpressionAst]) -and ($Node.Expression.VariablePath.UserPath -eq 'sweepTurn') }
$IS_CAUSE_SUBJECT = { param($Node) ($Node -is [VariableExpressionAst]) -and ($Node.VariablePath.UserPath -eq 'script:captureFailCause') }
$IS_SCREEN_SUBJECT = { param($Node) ($Node -is [VariableExpressionAst]) -and ($Node.VariablePath.UserPath -eq 'screen') }
function Get-ValidityElseBlock {
    # ⑦ 유효성 if(조건이 플래그와 $turnSerial 을 함께 읽고 else 가 있는 if)의 else 블록 - 하나가 아니면 $null
    $validityIfs = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-HasVariable $candidate.Clauses[0].Item1 'script:screenCaptureFailing') -and
                (Test-HasVariable $candidate.Clauses[0].Item1 'turnSerial') -and ($null -ne $candidate.ElseClause) }, $true))
    if ($validityIfs.Count -ne 1) { return $null }
    return $validityIfs[0].ElseClause
}
function Test-LiveStreakCondition {
    # 살아 있는 연속 - $insideStreak -gt 0 (0 -lt $insideStreak 도)
    param($Node)
    $inner = Get-InnerExpression $Node
    if (-not ($inner -is [BinaryExpressionAst])) { return $false }
    $operatorName = [string]$inner.Operator
    if ((@('Igt', 'Cgt') -contains $operatorName) -and (Test-IsVariable $inner.Left 'insideStreak') -and ((ConvertTo-AstKey $inner.Right) -ceq 'C(Int32:0)')) { return $true }
    if ((@('Ilt', 'Clt') -contains $operatorName) -and ((ConvertTo-AstKey $inner.Left) -ceq 'C(Int32:0)') -and (Test-IsVariable $inner.Right 'insideStreak')) { return $true }
    return $false
}
function Get-RevertKind {
    # 되돌림 if 의 꼴 - 'gate'(조건 = 살아 있는 연속 하나) / 'sweep'(-and 잎 둘 = Action 'yield' 정확 일치 + 살아 있는 연속) / '' · 본문 = 대입 둘
    # ($insideGraceRun ← 상수 0 · $insideGraceReverted ← $true, 순서·';' 무관) · elseif·else 0
    param($IfNode)
    if (($IfNode.Clauses.Count -ne 1) -or ($null -ne $IfNode.ElseClause)) { return '' }
    $bodyStatements = @($IfNode.Clauses[0].Item2.Statements)
    if ($bodyStatements.Count -ne 2) { return '' }
    $assignmentPairs = @($bodyStatements | ForEach-Object { if (($_ -is [AssignmentStatementAst]) -and ($_.Operator -eq [TokenKind]::Equals)) { (ConvertTo-AstKey $_.Left) + '=' + (ConvertTo-AstKey $_.Right) } else { '?' } } | Sort-Object)
    if (($assignmentPairs -join ';') -cne 'V(insidegracereverted)=V(true);V(insidegracerun)=C(Int32:0)') { return '' }
    $conditionLeaves = @(Get-AndLeaves $IfNode.Clauses[0].Item1)
    if (($conditionLeaves.Count -eq 1) -and (Test-LiveStreakCondition $conditionLeaves[0])) { return 'gate' }
    if ($conditionLeaves.Count -eq 2) {
        $yieldLeaves = @($conditionLeaves | Where-Object { (Test-ExactMatchSet -Expression $_ -IsSubject $IS_ACTION_SUBJECT -Want @('yield')) -ceq 'OK' }).Count
        $liveLeaves = @($conditionLeaves | Where-Object { Test-LiveStreakCondition $_ }).Count
        if (($yieldLeaves -eq 1) -and ($liveLeaves -eq 1)) { return 'sweep' }
    }
    return ''
}
function Get-GraceChain {
    # ⑩ 의 resume 유예 갈래 - if ($ResumeGrace) 하나(없으면 $null). 판정식은 구현 명세 ⑤c 부터 Resolve-AbyssResumeGrace 의 if 다섯이라 갈래 안 체인은 보지 않습니다(R5-P14 · R5-P2)
    $graceIfs = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-IsVariable $candidate.Clauses[0].Item1 'ResumeGrace') }, $true))
    $graceIf = $(if ($graceIfs.Count -eq 1) { $graceIfs[0] } else { $null })
    return [pscustomobject]@{ GraceIfCount = $graceIfs.Count; GraceIf = $graceIf }
}
function Get-LineCode {
    # 노드가 시작하는 줄의 주석 뺀 원문 (단독 줄 판정용)
    param($Node)
    $lineStart = $workerCode.LastIndexOf("`n", [Math]::Max(0, $Node.Extent.StartOffset - 1)) + 1
    $lineEnd = $workerCode.IndexOf("`n", $Node.Extent.StartOffset)
    if ($lineEnd -lt 0) { $lineEnd = $workerCode.Length }
    return $workerCode.Substring($lineStart, $lineEnd - $lineStart).Trim()
}

# R5-P1 - 회전 순서(뜻): 의미 앵커 열넷이 평가 순서로 증가 · 동결 블록 = 원문 다섯 요소
$R5P1_ANCHORS = @(
    @{ Label = '서두 메타 비움'; Match = { param($Node) ($Node -is [AssignmentStatementAst]) -and (Test-IsVariable $Node.Left 'script:lastClickSkipReason') } },
    @{ Label = '① 동결'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-IsVariable $Node.Clauses[0].Item1 'script:screenCaptureFailing') } },
    @{ Label = '② 양보'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasCommand $Node.Clauses[0].Item1 'Test-UserRecentlyActive') } },
    @{ Label = '③ 탐침 복구 뒤'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-IsVariable $Node.Clauses[0].Item1 'probeRecovered') } },
    @{ Label = '④ 스윕 분류'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Resolve-AbyssMemberSweepTurn') } },
    @{ Label = '⑤ 판독'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Test-DungeonClearPrompt') } },
    @{ Label = 'catch'; Match = { param($Node) $Node -is [CatchClauseAst] } },
    @{ Label = '⑥ 간접 양보'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasVariable $Node.Clauses[0].Item1 'script:userYieldTotalMs') -and (Test-HasVariable $Node.Clauses[0].Item1 'turnYieldMs') } },
    @{ Label = '⑦ 유효성'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasVariable $Node.Clauses[0].Item1 'script:screenCaptureFailing') -and (Test-HasVariable $Node.Clauses[0].Item1 'turnSerial') } },
    @{ Label = '⑧ 분류'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Resolve-AbyssHandoffStartScreen') } },
    @{ Label = '무변화 판정'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Test-AbyssMemberClockExpired') -and (Test-IsVariable (Get-CommandArgument -Command $Node -Name 'Clock') 'quietClock') } },
    @{ Label = '⑨ 결론'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Resolve-AbyssReentryVerdict') } },
    @{ Label = '⑩ 마감'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Test-AbyssMemberClockExpired') -and (Test-IsVariable (Get-CommandArgument -Command $Node -Name 'Clock') 'reentryClock') } },
    @{ Label = '⑫ 기본 대기'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Start-Sleep') -and ($null -ne (Get-CommandArgument -Command $Node -Name 'Milliseconds' -PositionalNames @())) -and
            ((ConvertTo-AstKey (Get-CommandArgument -Command $Node -Name 'Milliseconds' -PositionalNames @())) -ceq $BASE_WAIT_KEY) } })
function Get-EvaluationKey {
    # 평가 위치 (명세 3.5 R5-P1) - 명령·대입·그 밖 식 = 노드 끝(다른 명령의 인자식 안 앵커는 그 부모 명령보다 먼저) · if = 첫 절 조건의 끝(조건 안 노드보다 뒤 ·
    # 본문보다 앞) · catch 절 = 절 시작(try 본문 뒤)
    param($Node)
    if ($Node -is [IfStatementAst]) { return ([long]$Node.Clauses[0].Item1.Extent.EndOffset * 2 + 1) }
    if ($Node -is [CatchClauseAst]) { return ([long]$Node.Extent.StartOffset * 2) }
    return ([long]$Node.Extent.EndOffset * 2)
}
function Get-R5P1Problems {
    # 어긋난 점 목록 (열거용 - 호출부에서 @())
    $problemList = New-Object System.Collections.Generic.List[string]
    if ($null -eq $waiterWhile) { $problemList.Add('while 없음'); return $problemList.ToArray() }
    $keyedNodes = @(foreach ($bodyNode in @($waiterWhile.Body.FindAll({ param($candidate) $true }, $true))) { [pscustomobject]@{ Key = (Get-EvaluationKey $bodyNode); Start = $bodyNode.Extent.StartOffset; Node = $bodyNode } })
    $keyedNodes = @($keyedNodes | Sort-Object Key, Start)
    $previousKey = [long]-1
    $freezeIf = $null
    foreach ($anchor in $R5P1_ANCHORS) {
        $anchorHit = $null
        foreach ($keyedNode in $keyedNodes) {
            if (($keyedNode.Key -gt $previousKey) -and (& $anchor.Match $keyedNode.Node)) { $anchorHit = $keyedNode; break }
        }
        if ($null -eq $anchorHit) { $problemList.Add("빠짐·순서[$($anchor.Label)]"); return $problemList.ToArray() }
        if ($anchor.Label -eq '① 동결') { $freezeIf = $anchorHit.Node }
        $previousKey = $anchorHit.Key
    }
    # 동결 블록 = 원문 다섯 요소(안전 확인 · Start-Sleep · [void] 탐침(-Game $Game) · 탐침 표식(플래그의 부정) · 단독 줄 continue) · 절 1 · elseif·else 0
    if (($freezeIf.Clauses.Count -ne 1) -or ($null -ne $freezeIf.ElseClause)) { $problemList.Add('동결 elseif/else') }
    $freezeStatements = @($freezeIf.Clauses[0].Item2.Statements)
    if ($freezeStatements.Count -ne 5) { $problemList.Add("동결 문장 수 $($freezeStatements.Count)"); return $problemList.ToArray() }
    $safeStopCommand = Get-StatementCommand $freezeStatements[0]
    if (($null -eq $safeStopCommand) -or ($safeStopCommand.GetCommandName() -ne 'Test-SafeStopDuringCaptureFail')) { $problemList.Add('동결 1(안전 확인)') }
    $sleepCommand = Get-StatementCommand $freezeStatements[1]
    if (($null -eq $sleepCommand) -or ($sleepCommand.GetCommandName() -ne 'Start-Sleep')) { $problemList.Add('동결 2(Start-Sleep)') }
    $probeOk = $false
    $voidNode = Get-InnerExpression $freezeStatements[2]
    if (($voidNode -is [ConvertExpressionAst]) -and ((Get-ResolvedTypeName $voidNode.Type.TypeName) -eq 'System.Void')) {
        $probePipeline = Get-InnerExpression $voidNode.Child
        if (($probePipeline -is [PipelineAst]) -and ($probePipeline.PipelineElements.Count -eq 1) -and ($probePipeline.PipelineElements[0] -is [CommandAst]) -and
            ($probePipeline.PipelineElements[0].GetCommandName() -eq 'Test-CaptureRecovered') -and (Test-IsVariable (Get-CommandArgument -Command $probePipeline.PipelineElements[0] -Name 'Game') 'Game')) { $probeOk = $true }
    }
    if (-not $probeOk) { $problemList.Add('동결 3([void] 탐침)') }
    if (-not (($freezeStatements[3] -is [AssignmentStatementAst]) -and (Test-IsVariable $freezeStatements[3].Left 'probeRecovered') -and ((ConvertTo-AstKey $freezeStatements[3].Right) -ceq 'Un(Not|V(script:screencapturefailing))'))) { $problemList.Add('동결 4(탐침 표식)') }
    if (-not (($freezeStatements[4] -is [ContinueStatementAst]) -and ($null -eq $freezeStatements[4].Label) -and ((Get-LineCode $freezeStatements[4]) -ceq 'continue'))) { $problemList.Add('동결 5(단독 줄 continue)') }
    return $problemList.ToArray()
}
$r5p1Problems = @(Get-R5P1Problems)
Check-True 'R5-P1 회전 순서(뜻 - 평가 순서): 서두 메타 비움 < ① 동결 < ② 양보 < ③ 탐침 복구 뒤 < ④ 스윕 분류 < ⑤ 판독 < catch < ⑥ 간접 양보 < ⑦ 유효성 < ⑧ 분류 < 무변화 판정 < ⑨ 결론 < ⑩ 마감 < ⑫ 기본 대기(선분기 while 끝 대기 값) · 동결 블록 = 원문 다섯 요소' `
    ($r5p1Problems.Count -eq 0) ($r5p1Problems -join ' · ')

# R5-P2 - 시계: New-AbyssMemberClock 3(본 시계 식 안 · 무변화 · 정지 유예) 모두 while 앞 · while 안 Set·Suspend·마감 조정 함수·AddSeconds·AddMilliseconds 0 ·
#   while 안 Resume 1 = resume 유예 갈래의 두 잎 if(조건 = 'inside-first' ∨ 'reverted' 창 · 본문 = 그 한 문장) · 인자 글자 (구현 명세 ⑤c 2.5 · 3.2 (가) - 갈래 안 체인 · $graceHold 자리는 보지 않음)
$clockNewNodes = @(Get-CommandNodes -Node $waiterNode -Name 'New-AbyssMemberClock')
$clockNewTargets = @($clockNewNodes | ForEach-Object {
        $ownerNode = $_.Parent
        while (($null -ne $ownerNode) -and (-not ($ownerNode -is [AssignmentStatementAst]))) { $ownerNode = $ownerNode.Parent }
        $targetText = $(if ($null -ne $ownerNode) { [string](Get-InnerExpression $ownerNode.Left).VariablePath.UserPath } else { '?' })
        $pausedText = $(if (@($_.CommandElements | Where-Object { ($_ -is [CommandParameterAst]) -and ($_.ParameterName -eq 'Paused') }).Count -gt 0) { '(정지)' } else { '' })
        $targetText + $pausedText
    } | Sort-Object)
$clockNewBeforeWhile = @($clockNewNodes | Where-Object { Test-BeforeWhile $_ }).Count
$whileForbiddenCommands = $(if ($null -ne $waiterWhile) { @($waiterWhile.FindAll({ param($candidate) ($candidate -is [CommandAst]) -and
                (@('Set-AbyssMemberClock', 'Suspend-AbyssMemberClock', 'Get-YieldAdjustedDeadline', 'Invoke-UserYieldWithDeadline', 'New-AbyssMemberClock') -contains $candidate.GetCommandName()) }, $true)).Count } else { -1 })
$whileAddCalls = $(if ($null -ne $waiterWhile) { @($waiterWhile.FindAll({ param($candidate) ($candidate -is [InvokeMemberExpressionAst]) -and (@('AddSeconds', 'AddMilliseconds') -contains $candidate.Member.Extent.Text) }, $true)).Count } else { -1 })
$resumeNodes = $(if ($null -ne $waiterWhile) { @(Get-CommandNodes -Node $waiterWhile -Name 'Resume-AbyssMemberClock') } else { @() })
$graceChain = Get-GraceChain
$resumeSites = @($resumeNodes | ForEach-Object {
        $resumeIf = $_.Parent
        while (($null -ne $resumeIf) -and -not ($resumeIf -is [IfStatementAst])) { $resumeIf = $resumeIf.Parent }
        if ($null -eq $resumeIf) { '(if 밖) ' + (Get-NodeCode $_) }
        else {
            $resumeInGrace = ($null -ne $graceChain.GraceIf) -and (Test-AstWithin -Node $resumeIf -Ancestor $graceChain.GraceIf.Clauses[0].Item2)
            '{0} ⇐ {1} · 본문 {2}문장 · 절 {3} · 유예 갈래 안 {4}' -f (Get-NodeCode $_), (Get-NodeCode $resumeIf.Clauses[0].Item1), @($resumeIf.Clauses[0].Item2.Statements).Count, $resumeIf.Clauses.Count, $resumeInGrace
        }
    })
$r5p2Actual = '생성=[{0}] while 앞 {1} · while 안 금지 명령 {2} · Add* {3} · while 안 Resume {4} · 자리=[{5}]' -f ($clockNewTargets -join ','), $clockNewBeforeWhile, $whileForbiddenCommands, $whileAddCalls, $resumeNodes.Count, ($resumeSites -join ' | ')
$r5p2Expected = "생성=[insideGraceClock(정지),quietClock,reentryClock] while 앞 3 · while 안 금지 명령 0 · Add* 0 · while 안 Resume 1 · 자리=[Resume-AbyssMemberClock -Clock `$insideGraceClock ⇐ (`$graceWindow -eq 'inside-first') -or (`$graceWindow -eq 'reverted') · 본문 1문장 · 절 1 · 유예 갈래 안 True]"
Check-Equal 'R5-P2 시계 - 생성 3(본 시계 식 안 · 무변화 · 정지 유예) 모두 while 앞 · while 안 Set·Suspend·마감 조정·생성·AddSeconds·AddMilliseconds 0 · while 안 Resume 1(⑩ resume 유예 갈래의 두 잎 if - inside-first ∨ reverted, 인자 -Clock $insideGraceClock - 구현 명세 ⑤c 2.5)' $r5p2Actual $r5p2Expected

# R5-P3·R5-P4 - 관찰 전용: 이벤트 정리·X 후보·키·클릭 루프·나가기·복귀·안전 중지 파일·시간 지정·journal·클릭 0 · exit 0
$R5P3_PATTERNS = [ordered]@{
    'Clear-EventOverlay' = '(?<![\w-])Clear-EventOverlay(?![\w-])'; '$xCandidates' = '\$xCandidates\b'; 'Press-KeyOnce' = '(?<![\w-])Press-KeyOnce(?![\w-])'
    'Press-KeyVerified' = '(?<![\w-])Press-KeyVerified(?![\w-])'; 'Invoke-ClickUntil' = '(?<![\w-])Invoke-ClickUntil(?![\w-])'; 'Invoke-AbyssExitClick' = '(?<![\w-])Invoke-AbyssExitClick(?![\w-])'
    'Return-ToAbyssSelection' = '(?<![\w-])Return-ToAbyssSelection(?![\w-])'; '$safeStopFlagPath' = '\$safeStopFlagPath\b'; 'HONEYNOGI_UNTIL_TIME' = 'HONEYNOGI_UNTIL_TIME'
    '$script:abyssUntil' = '\$script:abyssUntil\b'; 'Get-DgTimeVerdict' = '(?<![\w-])Get-DgTimeVerdict(?![\w-])'; 'Update-AbyssJournal' = '(?<![\w-])Update-AbyssJournal(?![\w-])'
    'Read-AbyssJournal' = '(?<![\w-])Read-AbyssJournal(?![\w-])'
}
$r5p3Hits = @($R5P3_PATTERNS.Keys | Where-Object { [regex]::IsMatch($waiterCode, $R5P3_PATTERNS[$_], [Text.RegularExpressions.RegexOptions]::IgnoreCase) })
$waiterExitCount = @($waiterNode.FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count
Check-Equal 'R5-P3 waiter 안 Clear-EventOverlay · $xCandidates · Press-KeyOnce · Press-KeyVerified · Invoke-ClickUntil · Invoke-AbyssExitClick · Return-ToAbyssSelection · $safeStopFlagPath · HONEYNOGI_UNTIL_TIME · $script:abyssUntil · Get-DgTimeVerdict · Update-AbyssJournal · Read-AbyssJournal 0 · exit 0 (주석 뺀 사본)' `
    ('걸린 것=[{0}] · exit={1}' -f ($r5p3Hits -join ','), $waiterExitCount) '걸린 것=[] · exit=0'
$r5p4Hits = @(@('Click-GamePoint', 'Click-ScreenPoint') | Where-Object { [regex]::IsMatch($waiterCode, ('(?<![\w-])' + [regex]::Escape($_) + '(?![\w-])'), [Text.RegularExpressions.RegexOptions]::IgnoreCase) })
Check-Equal 'R5-P4 waiter 안 Click-GamePoint · Click-ScreenPoint 0 (관찰 전용 - 클릭은 구현 단위 ⑥d 의 ⑪)' ('걸린 것=[{0}]' -f ($r5p4Hits -join ',')) '걸린 것=[]'

# S2 고정 문구(설계 v11 R4 3.7 글자 - test_abyss_handoff_start.ps1 의 $S2_PATTERN · test_after_entry_at_most_once.ps1 의 S2 접두와 같은 글자) - R5-P5 · N4-P9 ·
#   N4-P14 의 대조 대상. 구현 단위 ⑤a 부터 선분기 S2 가 없어 소스 캡처 대상이 대기 함수 자신뿐이라 고정 상수로 둡니다. 접두·조각은 이 파일의 고정 $S2_PATTERN
#   과 한 줄 동치 단언으로 묶습니다(파생 안 함 - 고정 사본 둘이 서로 어긋나지 않게, 구현 명세 ⑤a 2.3). 채움 다섯은 워커 변수 이름이라 정규식 밖 - N4-P9 가 워커와 대조
$S2_PREFIX = '[어비스] 입장 계측 - 던전 안 2연속 앞 로딩(알 수 없음)'
$S2_FIXED_FRAGMENTS = @('[어비스] 입장 계측 - 던전 안 2연속 앞 로딩(알 수 없음) ', '표본, 필드 모양 ', '표본', ', 관측 끊김 ', '회 (필드 확정 폭 ', '초 계측 - 판정에 쓰지 않음)')
$S2_FIXED_FILLS = @('entryunknown', 'entryfield', 'entryfieldpart', 'entrybreaks', 'memberfieldsettleseconds')
Check-True 'S2 고정 상수 ≡ $S2_PATTERN - 고정 조각 여섯 사이에 표본 채움(0 · 0 · 없음 · 0 · 6)을 끼운 줄이 정규식에 맞고 조각 수 6 · 접두 = 첫 조각의 앞 (파생 안 함)' `
    (($S2_FIXED_FRAGMENTS.Count -eq 6) -and $S2_FIXED_FRAGMENTS[0].StartsWith($S2_PREFIX) -and [regex]::IsMatch((@($S2_FIXED_FRAGMENTS[0], '0', $S2_FIXED_FRAGMENTS[1], '0', $S2_FIXED_FRAGMENTS[2], '', $S2_FIXED_FRAGMENTS[3], '0', $S2_FIXED_FRAGMENTS[4], '6', $S2_FIXED_FRAGMENTS[5]) -join ''), $S2_PATTERN)) `
    ("조각 $($S2_FIXED_FRAGMENTS.Count)개 · 접두=[$S2_PREFIX]")
$workerS2Nodes = @(Get-CommandNodes -Node $workerAst -Name 'Write-RunLog' | Where-Object { (@($_.CommandElements).Count -ge 2) -and ($_.CommandElements[1] -is [ExpandableStringExpressionAst]) -and ([string]$_.CommandElements[1].Value).StartsWith($S2_PREFIX) })
Check-True '정적 전제: 워커 S2 확장 문자열 = 정확히 1 · 자리 = Wait-AbyssReentry (선분기 S2 0 - ⑤a)' (($workerS2Nodes.Count -eq 1) -and ((Get-EnclosingFunctionName $workerS2Nodes[0]) -eq 'Wait-AbyssReentry')) ("S2 {0}개 · 자리=[{1}]" -f $workerS2Nodes.Count, ((@($workerS2Nodes | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ','))

# R5-P5 - S2: Write-RunLog 확장 문자열 '[어비스] 입장 계측 - 던전 안 2연속 앞 로딩(알 수 없음)' 1 · 그 밖 꼴 0 · 그 줄의 변수(memberFieldSettleSeconds 제외)가 if·loop 조건에 0
$waiterLogNodes = @(Get-CommandNodes -Node $waiterNode -Name 'Write-RunLog')
$s2ExpandableNodes = @($waiterLogNodes | Where-Object { (@($_.CommandElements).Count -ge 2) -and ($_.CommandElements[1] -is [ExpandableStringExpressionAst]) -and ($S2_PREFIX.Length -gt 0) -and ([string]$_.CommandElements[1].Value).StartsWith($S2_PREFIX) })
$s2OtherForms = @($waiterNode.FindAll({ param($candidate) (($candidate -is [StringConstantExpressionAst]) -or ($candidate -is [ExpandableStringExpressionAst])) -and ([string]$candidate.Value).Contains('입장 계측') }, $true)).Count - $s2ExpandableNodes.Count
$s2Variables = $(if ($s2ExpandableNodes.Count -eq 1) { @($s2ExpandableNodes[0].CommandElements[1].FindAll({ param($candidate) $candidate -is [VariableExpressionAst] }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Where-Object { $_ -ne 'memberFieldSettleSeconds' } | Sort-Object -Unique) } else { @() })
$conditionNodes = @(foreach ($conditionOwner in $waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -or ($candidate -is [LoopStatementAst]) }, $true)) {
        if ($conditionOwner -is [IfStatementAst]) { foreach ($ownerClause in $conditionOwner.Clauses) { $ownerClause.Item1 } } elseif ($null -ne $conditionOwner.Condition) { $conditionOwner.Condition }
    })
$s2VariablesInConditions = @($s2Variables | Where-Object { $variableName = $_; @($conditionNodes | Where-Object { Test-HasVariable $_ $variableName }).Count -gt 0 })
Check-Equal 'R5-P5 S2 - Write-RunLog 확장 문자열(S2 고정 접두) 1 · 그 밖 꼴 0 · 그 줄의 계측 변수(memberFieldSettleSeconds 제외)가 waiter 의 if·loop 조건에 0' `
    ('S2 확장 {0} · 그 밖 {1} · 변수 {2}개 · 조건 안=[{3}]' -f $s2ExpandableNodes.Count, $s2OtherForms, $s2Variables.Count, ($s2VariablesInConditions -join ',')) ('S2 확장 1 · 그 밖 0 · 변수 {0}개 · 조건 안=[]' -f $s2Variables.Count)

# R5-P6 - 패널 관측: $panelObserved 대입 = 우변 $PanelSeen 1(while 앞) · $true 1(패널류 if 안) · 그 밖 0 · 그 if 조건 = $screen 과 상수의 정확 일치 · 집합 정확히 넷
$panelAssignments = @($waiterNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'panelObserved') }, $true))
$panelBefore = @($panelAssignments | Where-Object { Test-BeforeWhile $_ })
$panelInside = @($panelAssignments | Where-Object { -not (Test-BeforeWhile $_) })
$panelConditionResult = '갈래 없음'
if (($panelInside.Count -eq 1) -and (Test-IsVariable $panelInside[0].Right 'true')) {
    $panelIfNode = $panelInside[0].Parent
    while (($null -ne $panelIfNode) -and (-not ($panelIfNode -is [IfStatementAst]))) { $panelIfNode = $panelIfNode.Parent }
    if ($null -ne $panelIfNode) { $panelConditionResult = Test-ExactMatchSet -Expression $panelIfNode.Clauses[0].Item1 -IsSubject $IS_SCREEN_SUBJECT -Want @('popup', 'ready', 'matching', 'entry-waiting') }
}
Check-Equal "R5-P6 패널 관측 - `$panelObserved 대입 = while 앞 `$PanelSeen 1 · while 안 `$true 1 · 그 밖 0 · 그 if 조건 = `$screen 과 상수 정확 일치 · 집합 {popup, ready, matching, entry-waiting}" `
    ('앞 {0}({1}) · 안 {2} · 조건={3}' -f $panelBefore.Count, ((@($panelBefore | ForEach-Object { [int](Test-IsVariable $_.Right 'PanelSeen') }) -join '')), $panelInside.Count, $panelConditionResult) '앞 1(1) · 안 1 · 조건=OK'

# R5-P7 - while 본문 안 $insideStreak = 0 대입 4(② 게이트 블록 · ④ 스윕 if 본문 · ⑥ 블록 · ⑧ 'inside' else) · ① 블록 · ⑦ 복구 갈래 · catch 안 0 (우변 '0' 글자 - 구현 형상 계약)
$streakZeroNodes = $(if ($null -ne $waiterWhile) { @($waiterWhile.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'insideStreak') -and ($candidate.Right.Extent.Text -eq '0') }, $true)) } else { @() })
function Get-ZeroCountUnder { param($Node) if ($null -eq $Node) { return -1 }; return @($streakZeroNodes | Where-Object { Test-AstWithin -Node $_ -Ancestor $Node }).Count }
$gateIfNode = $(if ($null -ne $waiterWhile) { @($waiterWhile.Body.Statements | Where-Object { ($_ -is [IfStatementAst]) -and (Test-HasCommand $_.Clauses[0].Item1 'Test-UserRecentlyActive') }) | Select-Object -First 1 } else { $null })
$sweepIfNode = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-HasCommand $candidate.Clauses[0].Item1 'Invoke-PurchasePopupSweep') }, $true)) | Select-Object -First 1
$sixthIfNode = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-HasVariable $candidate.Clauses[0].Item1 'script:userYieldTotalMs') -and (Test-HasVariable $candidate.Clauses[0].Item1 'turnYieldMs') }, $true)) | Select-Object -First 1
$insideIfNode = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and ((Test-ExactMatchSet -Expression $candidate.Clauses[0].Item1 -IsSubject $IS_SCREEN_SUBJECT -Want @('inside')) -ceq 'OK') -and ($null -ne $candidate.ElseClause) }, $true)) | Select-Object -First 1
$freezeIfNode = $(if ($null -ne $waiterWhile) { @($waiterWhile.Body.Statements | Where-Object { ($_ -is [IfStatementAst]) -and (Test-IsVariable $_.Clauses[0].Item1 'script:screenCaptureFailing') }) | Select-Object -First 1 } else { $null })
$validityIfNode = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-HasVariable $candidate.Clauses[0].Item1 'script:screenCaptureFailing') -and (Test-HasVariable $candidate.Clauses[0].Item1 'turnSerial') }, $true)) | Select-Object -First 1
$catchBodies = @($waiterNode.FindAll({ param($candidate) $candidate -is [CatchClauseAst] }, $true))
$r5p7Actual = '합 {0} · ② {1} · ④ {2} · ⑥ {3} · ⑧ else {4} · ① {5} · ⑦ 복구 {6} · catch {7}' -f $streakZeroNodes.Count,
(Get-ZeroCountUnder $(if ($null -ne $gateIfNode) { $gateIfNode.Clauses[0].Item2 } else { $null })),
(Get-ZeroCountUnder $(if ($null -ne $sweepIfNode) { $sweepIfNode.Clauses[0].Item2 } else { $null })),
(Get-ZeroCountUnder $(if ($null -ne $sixthIfNode) { $sixthIfNode.Clauses[0].Item2 } else { $null })),
(Get-ZeroCountUnder $(if ($null -ne $insideIfNode) { $insideIfNode.ElseClause } else { $null })),
(Get-ZeroCountUnder $(if ($null -ne $freezeIfNode) { $freezeIfNode.Clauses[0].Item2 } else { $null })),
(Get-ZeroCountUnder $(if ($null -ne $validityIfNode) { $validityIfNode.Clauses[0].Item2 } else { $null })),
(@($catchBodies | ForEach-Object { Get-ZeroCountUnder $_.Body }) | Measure-Object -Sum).Sum
Check-Equal "R5-P7 while 본문 안 `$insideStreak = 0 대입 4(② 게이트 · ④ 스윕 참 분기 · ⑥ 간접 양보 · ⑧ 'inside' 아닌 갈래) · ① 동결 블록 · ⑦ 복구 갈래 · catch 안 0" $r5p7Actual '합 4 · ② 1 · ④ 1 · ⑥ 1 · ⑧ else 1 · ① 0 · ⑦ 복구 0 · catch 0'

# R5-P8 - 선택 화면 · ESC 메뉴는 필드 결과 켬의 필드 모양 회전만 읽음(구현 단위 5b-8 2.2-4a - 설계 리뷰 P2 · 합의: 'unknown' 회전 · 상세는 읽지 않음). 판독 명령 각 1 · 상세 0 ·
#   분류 호출 2(앞 분류는 세 신호 없이 · ⑧ 분류만 -SelectionVisible · -MenuVisible) · 두 판독을 감싼 if 조건(안쪽부터 - ⑤ 판독 if 까지, else 면 'else <첫 절 조건>')
function Get-EnclosingIfConditions {
    # 노드를 감싼 if 절 조건 글자(안쪽부터, Stop 노드 앞까지) - 노드가 첫 절들에 있으면 그 절 조건, else 블록에 있으면 'else <첫 절 조건>'
    param($Node, $Stop)
    $conditionCodes = @()
    $childNode = $Node
    for ($parentNode = $Node.Parent; ($null -ne $parentNode) -and (-not [object]::ReferenceEquals($parentNode, $Stop)); $parentNode = $parentNode.Parent) {
        if ($parentNode -is [IfStatementAst]) {
            foreach ($ifClause in $parentNode.Clauses) {
                if ([object]::ReferenceEquals($ifClause.Item2, $childNode)) { $conditionCodes += (Get-NodeCode $ifClause.Item1) }
            }
            if ([object]::ReferenceEquals($parentNode.ElseClause, $childNode)) { $conditionCodes += ('else ' + (Get-NodeCode $parentNode.Clauses[0].Item1)) }
        }
        $childNode = $parentNode
    }
    return $conditionCodes
}
$r5p8Commands = @(@('Test-AbyssSelectionScreen', 'Test-AbyssMenu', 'Test-AbyssKnownDetailScreen') | ForEach-Object { '{0}={1}' -f $_, @(Get-CommandNodes -Node $waiterNode -Name $_).Count })
$classifyCalls = @(Get-CommandNodes -Node $waiterNode -Name 'Resolve-AbyssHandoffStartScreen' | Sort-Object { $_.Extent.StartOffset })
$classifyExtraParameters = @($classifyCalls | ForEach-Object { ((@($_.CommandElements | Where-Object { ($_ -is [CommandParameterAst]) -and (@('SelectionVisible', 'MenuVisible', 'DetailVisible') -contains $_.ParameterName) } | ForEach-Object { $_.ParameterName })) -join '+') })
$r5p8Guards = @(foreach ($r5p8Name in @('Test-AbyssSelectionScreen', 'Test-AbyssMenu')) {
        foreach ($r5p8Call in @(Get-CommandNodes -Node $waiterNode -Name $r5p8Name)) { '{0}: {1}' -f $r5p8Name, ((@(Get-EnclosingIfConditions -Node $r5p8Call -Stop $waiterNode)) -join ' < ') }
    })
Check-Equal 'R5-P8 선택 화면 · ESC 메뉴 판독 = 필드 결과 켬 · 필드 모양 회전만(상세 0) · 분류 호출 2(앞 분류 세 신호 없음 · ⑧ 두 신호) · 두 판독을 감싼 if 조건(안쪽부터)' `
    ('명령=[{0}] · 분류 호출 {1} · 선택 화면 셋 인자=[{2}] · 감싼 조건=[{3}]' -f ($r5p8Commands -join ','), $classifyCalls.Count, ($classifyExtraParameters -join ' / '), ($r5p8Guards -join ' / ')) `
    ("명령=[Test-AbyssSelectionScreen=1,Test-AbyssMenu=1,Test-AbyssKnownDetailScreen=0] · 분류 호출 2 · 선택 화면 셋 인자=[ / SelectionVisible+MenuVisible] · 감싼 조건=[" +
        "Test-AbyssSelectionScreen: `$earlyScreen -eq 'field' < `$ReportFieldReturn < (-not `$sweepStarved) -and (-not `$turnRecovered) / " +
        "Test-AbyssMenu: -not `$selectionNow < `$earlyScreen -eq 'field' < `$ReportFieldReturn < (-not `$sweepStarved) -and (-not `$turnRecovered)]")

# R5-P12 - while 직속 if 중 첫 절 조건이 정확히 플래그이고 한 줄인 것 0 · 정확 조건 if-continue 는 ① 하나 (절 수 / 줄 머리 continue 절 수 / 정확 조건 while)
$exactClauseCount = 0; $spinClauseCount = 0
foreach ($ifNode in @($waiterNode.FindAll({ param($candidate) $candidate -is [IfStatementAst] }, $true))) {
    foreach ($ifClause in $ifNode.Clauses) {
        if ((Get-NodeCode $ifClause.Item1) -match '^\(?\$script:screenCaptureFailing\)?$') {
            $exactClauseCount++
            if ($ifClause.Item2.Extent.Text -match '(?m)^\s*continue\b') { $spinClauseCount++ }
        }
    }
}
$exactWhileCount = @($waiterNode.FindAll({ param($candidate) ($candidate -is [WhileStatementAst]) -and ((Get-NodeCode $candidate.Condition) -match '^\(?\$script:screenCaptureFailing\)?$') }, $true)).Count
$oneLineFlagIfs = $(if ($null -ne $waiterWhile) { @($waiterWhile.Body.Statements | Where-Object { ($_ -is [IfStatementAst]) -and (Test-IsVariable $_.Clauses[0].Item1 'script:screenCaptureFailing') -and ($_.Extent.StartLineNumber -eq $_.Extent.EndLineNumber) }).Count } else { -1 })
Check-Equal 'R5-P12 회전 수준 한 줄 동결 if 0 · 정확 조건 if 는 ① 하나(정확 조건 절 / 줄 머리 continue 절 / 정확 조건 while = 1/1/0)' ('{0}/{1}/{2} · 한 줄 {3}' -f $exactClauseCount, $spinClauseCount, $exactWhileCount, $oneLineFlagIfs) '1/1/0 · 한 줄 0'

# R5-P14 - resume 유예: $ResumeGrace 참조 = param 블록 밖 1(⑩ 마감 if 안) · 그 갈래의 판정 호출 Resolve-AbyssResumeGrace 1 · 판정식 = Resolve-AbyssResumeGrace 본문 직속 if 다섯
#   (각 절 1 · else 0 · 조건 글자를 소스 차례로 이어 견줌 - 정렬 · 집합 비교 금지: 다섯 if 의 차례를 고정하는 단언은 이것뿐, 구현 명세 ⑤c 3.2 (가) · 5C-M33b - 구현 형상 계약) ·
#   기다리는 화면 문자열 0(갈래 · 판정식 둘 다)
$R5P14_EXPRESSIONS = @(
    '($InsideStreak -eq 1) -and ($InsideGraceRun -eq 0)',
    '($InsideStreak -eq 1) -and ($InsideGraceRun -eq $InsideRun) -and $InsideGraceOpen',
    "`$QuietOpen -and `$ReportRewardReturn -and (`$LastKind -eq 'reward3')",
    "`$QuietOpen -and (`$LastKind -eq '')",
    '$Reverted -and $InsideGraceOpen')
$resumeGraceReferences = @($waiterNode.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -eq 'ResumeGrace') }, $true) |
        Where-Object { -not (Test-AstWithin -Node $_ -Ancestor $waiterNode.Body.ParamBlock) })
$deadlineIfNode = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (@($candidate.Clauses[0].Item1.FindAll({ param($commandNode) ($commandNode -is [CommandAst]) -and
                    ($commandNode.GetCommandName() -eq 'Test-AbyssMemberClockExpired') -and (Test-IsVariable (Get-CommandArgument -Command $commandNode -Name 'Clock') 'reentryClock') }, $true)).Count -gt 0) }, $true)) | Select-Object -First 1
$referencesInDeadline = @($resumeGraceReferences | Where-Object { ($null -ne $deadlineIfNode) -and (Test-AstWithin -Node $_ -Ancestor $deadlineIfNode.Clauses[0].Item2) }).Count
$graceJudgeNode = Get-WorkerFunction 'Resolve-AbyssResumeGrace'
$graceJudgeIfs = @($graceJudgeNode.Body.EndBlock.Statements | Where-Object { $_ -is [IfStatementAst] })
$chainConditions = @($graceJudgeIfs | ForEach-Object { Get-NodeCode $_.Clauses[0].Item1 })
$chainClauses = (@($graceJudgeIfs | ForEach-Object { $_.Clauses.Count })) -join ','
$chainElse = @($graceJudgeIfs | Where-Object { $null -ne $_.ElseClause }).Count
$graceJudgeCalls = $(if ($null -ne $graceChain.GraceIf) { @(Get-CommandNodes -Node $graceChain.GraceIf.Clauses[0].Item2 -Name 'Resolve-AbyssResumeGrace').Count } else { -1 })
$waitingStrings = @(@($(if ($null -ne $graceChain.GraceIf) { $graceChain.GraceIf.Clauses[0].Item2 } else { $null }), $graceJudgeNode) | Where-Object { $null -ne $_ } |
        ForEach-Object { $_.FindAll({ param($candidate) $candidate -is [StringConstantExpressionAst] }, $true) } | ForEach-Object { [string]$_.Value } |
        Where-Object { @('ready', 'matching', 'popup', 'entry-waiting', 'unknown', 'prompt', 'field') -contains $_ })
Check-Equal 'R5-P14 resume 유예 - $ResumeGrace 참조 param 밖 1(⑩ 마감 if 안) · 갈래 1 · 그 갈래 판정 호출 1 · 판정식 Resolve-AbyssResumeGrace 직속 if 다섯(던전 안 첫 유예 · 연장 · 3버튼 · 첫 유효 회전 전 · 되돌림 뒤 창 - 정규화 글자 · 소스 차례) · 각 절 1 · else 0 · 기다리는 화면 문자열 0' `
    ('참조 {0}(마감 if 안 {1}) · 갈래 {2} · 판정 호출 {3} · 절=[{4}] · 식=[{5}] · else {6} · 문자열=[{7}]' -f $resumeGraceReferences.Count, $referencesInDeadline, $graceChain.GraceIfCount, $graceJudgeCalls, $chainClauses, ($chainConditions -join ' || '), $chainElse, ($waitingStrings -join ',')) `
    ('참조 1(마감 if 안 1) · 갈래 1 · 판정 호출 1 · 절=[1,1,1,1,1] · 식=[{0}] · else 0 · 문자열=[]' -f ($R5P14_EXPRESSIONS -join ' || '))
# R5-P14 되돌림 표식 대입 사실 - $insideGraceReverted = while 앞 $false 1 · while 안 $true 3(되돌림 if 본문 - ②·⑥ 살아 있는 연속 둘 · ④ 'yield' 조건 하나) ·
#   while 안 $false 1(⑦ else 블록 안 · 바로 앞 문장 $lastKind = $screen) · 그 밖 0
$flagAssignments = @($waiterNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'insideGraceReverted') }, $true))
$flagBefore = @($flagAssignments | Where-Object { Test-BeforeWhile $_ })
$flagLoop = @($flagAssignments | Where-Object { -not (Test-BeforeWhile $_) })
$flagLoopTrue = @($flagLoop | Where-Object { Test-IsVariable $_.Right 'true' })
$flagLoopFalse = @($flagLoop | Where-Object { Test-IsVariable $_.Right 'false' })
# 참 대입 셋의 자리(② 게이트 블록 · ④ 스윕 참 분기 · ⑥ 간접 양보 블록 - 명세 3.5 R5-P14)와 그 되돌림 if 의 꼴(gate · sweep)을 함께 봅니다
$REVERT_SITE_ORDER = [string[]]@('②', '④', '⑥', '?')
$revertSites = @($flagLoopTrue | ForEach-Object {
        $revertIf = $_.Parent.Parent
        $revertKind = $(if ($revertIf -is [IfStatementAst]) { Get-RevertKind $revertIf } else { '?' })
        $revertSite = '?'
        if (($null -ne $gateIfNode) -and (Test-AstWithin -Node $_ -Ancestor $gateIfNode.Clauses[0].Item2)) { $revertSite = '②' }
        elseif (($null -ne $sweepIfNode) -and (Test-AstWithin -Node $_ -Ancestor $sweepIfNode.Clauses[0].Item2)) { $revertSite = '④' }
        elseif (($null -ne $sixthIfNode) -and (Test-AstWithin -Node $_ -Ancestor $sixthIfNode.Clauses[0].Item2)) { $revertSite = '⑥' }
        $revertSite + $revertKind
    })
$revertKinds = @($revertSites | Sort-Object { [Array]::IndexOf($REVERT_SITE_ORDER, $_.Substring(0, 1)) }, { $_ })
$clearSite = '없음'
if ($flagLoopFalse.Count -eq 1) {
    $clearBlock = $flagLoopFalse[0].Parent
    $validityElse = Get-ValidityElseBlock
    $clearStatements = @($clearBlock.Statements)
    $clearIndex = [Array]::IndexOf($clearStatements, $flagLoopFalse[0])
    $clearSite = ('⑦ else={0} · 앞 문장=[{1}]' -f ([object]::ReferenceEquals($validityElse, $clearBlock)), $(if ($clearIndex -ge 1) { Get-NodeCode $clearStatements[$clearIndex - 1] } else { '' }))
}
Check-Equal "R5-P14 되돌림 표식 대입 사실 - `$insideGraceReverted 대입 = while 앞 `$false 1 · while 안 `$true 3(② 게이트·⑥ 간접 양보의 gate 둘 · ④ 스윕 분기의 sweep 하나 - 자리와 조건·본문 뜻) · while 안 `$false 1(⑦ else · 바로 앞 `$lastKind = `$screen) · 그 밖 0" `
    ('앞 {0}({1}) · 안 참 {2}=[{3}] · 안 거짓 {4} · 그 밖 {5} · 비움 자리=[{6}]' -f $flagBefore.Count, ((@($flagBefore | ForEach-Object { [int](Test-IsVariable $_.Right 'false') })) -join ''), $flagLoopTrue.Count, ($revertKinds -join ','),
        $flagLoopFalse.Count, ($flagLoop.Count - $flagLoopTrue.Count - $flagLoopFalse.Count), $clearSite) '앞 1(1) · 안 참 3=[②gate,④sweep,⑥gate] · 안 거짓 1 · 그 밖 0 · 비움 자리=[⑦ else=True · 앞 문장=[$lastKind = $screen]]'

# R5-P16 - 창 좌표 throw 제한 catch: try 1 · catch 절 1 · 형식 0 · try 본문 = ④ 스윕 if + ⑤ 판독 if · catch 안 if 1(본문 = 단독 throw · elseif·else 0) · catch 안 대입·명령·
#   continue·break·return 0 · 조건 = 단항 부정 하나 아래 -and 잎 셋 = {플래그 · 원인 정확 일치 {캡처값} · 메시지 정확 일치 {두 캡처값}} 일대일(순서 무관) · 부분 일치·메서드 0
function Get-WindowCatchProblems {
    # 한 try 의 창 좌표 throw 제한 catch 판정(R5-P16 의 catch 몫 - §9 '다른 던전 가기' 대기의 try 둘도 이 함수로 봄, 구현 명세 ⑤b3 3.2): catch 절 1 · 형식 0 ·
    #   catch 안 if 1(단독 throw · elseif·else 0) · 대입·명령·continue·break·return 0 · 조건 = 단항 부정 하나 아래 -and 잎 셋 = {플래그 · 원인 · 메시지} 일대일(순서 무관)
    param($TryNode)
    $problemList = New-Object System.Collections.Generic.List[string]
    if ($TryNode.CatchClauses.Count -ne 1) { $problemList.Add("catch 절 $($TryNode.CatchClauses.Count)개"); return $problemList.ToArray() }
    $catchClause = $TryNode.CatchClauses[0]
    if ($catchClause.CatchTypes.Count -ne 0) { $problemList.Add("catch 형식 $($catchClause.CatchTypes.Count)개") }
    $catchIfs = @($catchClause.Body.FindAll({ param($candidate) $candidate -is [IfStatementAst] }, $true))
    if ($catchIfs.Count -ne 1) { $problemList.Add("catch 안 if $($catchIfs.Count)개"); return $problemList.ToArray() }
    $catchIf = $catchIfs[0]
    if (($null -ne $catchIf.ElseClause) -or ($catchIf.Clauses.Count -ne 1)) { $problemList.Add('catch if 의 elseif/else') }
    $catchIfBody = @($catchIf.Clauses[0].Item2.Statements)
    if (($catchIfBody.Count -ne 1) -or (-not ($catchIfBody[0] -is [ThrowStatementAst])) -or ($null -ne $catchIfBody[0].Pipeline)) { $problemList.Add('catch if 본문이 단독 throw 하나가 아님') }
    $catchJumps = @($catchClause.Body.FindAll({ param($candidate) ($candidate -is [ContinueStatementAst]) -or ($candidate -is [BreakStatementAst]) -or ($candidate -is [ReturnStatementAst]) }, $true)).Count
    $catchAssignments = @($catchClause.Body.FindAll({ param($candidate) $candidate -is [AssignmentStatementAst] }, $true)).Count
    $catchCommands = @($catchClause.Body.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true)).Count
    if (($catchJumps -ne 0) -or ($catchAssignments -ne 0) -or ($catchCommands -ne 0)) { $problemList.Add("catch 안 continue·break·return $catchJumps · 대입 $catchAssignments · 명령 $catchCommands") }
    $catchCondition = Get-InnerExpression $catchIf.Clauses[0].Item1
    if (-not (($catchCondition -is [UnaryExpressionAst]) -and (@('Not', 'Exclaim') -contains [string]$catchCondition.TokenKind))) { $problemList.Add('조건이 단항 부정이 아님'); return $problemList.ToArray() }
    $methodCalls = @($catchCondition.FindAll({ param($candidate) $candidate -is [InvokeMemberExpressionAst] }, $true)).Count
    $notCount = @($catchCondition.FindAll({ param($candidate) ($candidate -is [UnaryExpressionAst]) -and (@('Not', 'Exclaim') -contains [string]$candidate.TokenKind) }, $true)).Count
    $partialOperators = @($catchCondition.FindAll({ param($candidate) ($candidate -is [BinaryExpressionAst]) -and ([string]$candidate.Operator -match '^(I|C)(not)?(like|match)$|^(I|C)(replace|split)$') }, $true)).Count
    if ($methodCalls -ne 0) { $problemList.Add("조건 안 메서드 호출 $methodCalls") }
    if ($notCount -ne 1) { $problemList.Add("조건 안 단항 부정 $notCount") }
    if ($partialOperators -ne 0) { $problemList.Add("부분 일치 연산자 $partialOperators") }
    $conditionTerms = @(Get-AndLeaves $catchCondition.Child)
    if ($conditionTerms.Count -ne 3) { $problemList.Add("-and 잎 $($conditionTerms.Count)개"); return $problemList.ToArray() }
    $termCategories = @(foreach ($conditionTerm in $conditionTerms) {
            if (Test-IsVariable $conditionTerm 'script:screenCaptureFailing') { 'F' }
            elseif ((Test-ExactMatchSet -Expression $conditionTerm -IsSubject $IS_CAUSE_SUBJECT -Want @($WINDOW_GONE_CAUSE)) -ceq 'OK') { 'C' }
            else {
                $messageResult = Test-ExactMatchSet -Expression $conditionTerm -IsSubject $IS_MESSAGE_SUBJECT -Want @($READ_PATH_MESSAGE, $CLICK_PATH_MESSAGE)
                $(if ($messageResult -ceq 'OK') { 'M' } else { '?' + $messageResult })
            }
        })
    if ((@($termCategories | Sort-Object) -join ',') -cne 'C,F,M') { $problemList.Add('잎=[' + ($termCategories -join ',') + ']') }
    return $problemList.ToArray()
}
function Get-R5P16Problems {
    $problemList = New-Object System.Collections.Generic.List[string]
    $tryNodes = @($waiterNode.FindAll({ param($candidate) $candidate -is [TryStatementAst] }, $true))
    if ($tryNodes.Count -ne 1) { $problemList.Add("try $($tryNodes.Count)개"); return $problemList.ToArray() }
    $tryNode = $tryNodes[0]
    $tryStatements = @($tryNode.Body.Statements)
    if (($tryStatements.Count -ne 2) -or (-not ($tryStatements[0] -is [IfStatementAst])) -or (-not (Test-HasCommand $tryStatements[0].Clauses[0].Item1 'Invoke-PurchasePopupSweep')) -or
        (-not ($tryStatements[1] -is [IfStatementAst])) -or (-not (Test-HasCommand $tryStatements[1].Clauses[0].Item2 'Test-DungeonClearPrompt'))) { $problemList.Add("try 본문 = ④ 스윕 if + ⑤ 판독 if 가 아님(문장 $($tryStatements.Count)개)") }
    foreach ($catchProblem in @(Get-WindowCatchProblems -TryNode $tryNode)) { $problemList.Add($catchProblem) }
    return $problemList.ToArray()
}
$r5p16Problems = @(Get-R5P16Problems)
Check-True "R5-P16 창 좌표 throw 제한 catch - try 1 · catch 절 1 · 형식 0 · try 본문 = ④ 스윕 if + ⑤ 판독 if · catch 안 if 1(단독 throw) · 대입·명령·continue·break·return 0 · 조건 = -not(플래그 ∧ 원인 = $WINDOW_GONE_CAUSE ∧ 메시지 ∈ 두 캡처 문구 - 정확 일치 · 순서 무관)" `
    ($r5p16Problems.Count -eq 0) ($r5p16Problems -join ' · ')

# N4-P1 - $abyssReclickQuietSeconds: 최상위 대입 1 · 함수 안 0 · 우변 명령 0 · 값 10 (계약값 고정 - 바꾸려면 설계 재합의 · 측정은 ⑤ 실기 R5-2)
$quietAssignments = @($workerAst.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and ((Get-InnerExpression $candidate.Left) -is [VariableExpressionAst]) -and
            (((Get-InnerExpression $candidate.Left).VariablePath.UserPath -replace '^.*:', '') -eq 'abyssReclickQuietSeconds') }, $true))
$quietTopLevel = @($quietAssignments | Where-Object { -not (Test-AstInsideFunction $_) })
$quietInFunctions = @($quietAssignments | Where-Object { Test-AstInsideFunction $_ })
$quietRightCommands = $(if ($quietTopLevel.Count -ge 1) { @($quietTopLevel[0].Right.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true)).Count } else { -1 })
Check-Equal 'N4-P1 $abyssReclickQuietSeconds - 최상위 대입 1 · 함수 안 0 · 우변 명령 0(config 읽기 0) · 값 10 (계약값 고정 - 설계 v10 의 10초, 측정은 ⑤ 실기)' `
    ('최상위 {0} · 함수 안 {1} · 우변 명령 {2} · 값 {3}' -f $quietTopLevel.Count, $quietInFunctions.Count, $quietRightCommands, $abyssReclickQuietSeconds) '최상위 1 · 함수 안 0 · 우변 명령 0 · 값 10'

# N4-P2 - 배선(⑤a · ⑤b4 · ⑤c): 워커의 Wait-AbyssReentry 호출 4(자리 = 이어받기 선분기 2 - Role resume 의 호출 C(⑤c 5c-2) · B2 단계 / '다른 던전 가기' 끝 함수 - 폴백 ② 호출 E /
#   '다시 하기' 끝 함수 - 원 워커 호출 B) · Resolve-AbyssReentryVerdict 호출 1(자리 = Wait-AbyssReentry 안)
$waiterCallNodes = @(Get-CommandNodes -Node $workerAst -Name 'Wait-AbyssReentry')
$verdictCallNodes = @(Get-CommandNodes -Node $workerAst -Name 'Resolve-AbyssReentryVerdict')
Check-Equal 'N4-P2 배선(⑤a · ⑤b4 · ⑤c) - 워커의 Wait-AbyssReentry 호출 4(자리 = Invoke-AbyssHandoffStart 2(호출 C · B2) · Complete-AbyssOtherSelection · Complete-AbyssRetrySelection) · Resolve-AbyssReentryVerdict 호출 1(자리 = Wait-AbyssReentry 안)' `
    ('대기 함수 호출 {0}=[{1}] · 순수 판정 호출 {2} · 자리=[{3}]' -f $waiterCallNodes.Count, ((@($waiterCallNodes | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ','), $verdictCallNodes.Count, ((@($verdictCallNodes | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ',')) '대기 함수 호출 4=[Invoke-AbyssHandoffStart,Invoke-AbyssHandoffStart,Complete-AbyssOtherSelection,Complete-AbyssRetrySelection] · 순수 판정 호출 1 · 자리=[Wait-AbyssReentry]'

# N4-P3 - 순수 판정: 명령 0 · $script: 0 · exit·throw·try 0 · return 7 · 반환 문자열 = {entered, field, reward, field-cancelled(구현 단위 5b-8), cancelled, reclick, ''} ·
#   -Target ValidateSet = {entry, reward, field}
$verdictCommands = @($verdictNode.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true)).Count
$verdictScriptVariables = @($verdictNode.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -like 'script:*') }, $true)).Count
$verdictExits = @($verdictNode.FindAll({ param($candidate) ($candidate -is [ExitStatementAst]) -or ($candidate -is [ThrowStatementAst]) -or ($candidate -is [TryStatementAst]) }, $true)).Count
$verdictReturns = @($verdictNode.FindAll({ param($candidate) $candidate -is [ReturnStatementAst] }, $true))
$verdictReturnValues = @($verdictReturns | ForEach-Object { $returnInner = Get-InnerExpression $_.Pipeline; $(if ($returnInner -is [StringConstantExpressionAst]) { "'" + $returnInner.Value + "'" } else { '?' }) } | Sort-Object -Unique -CaseSensitive)
$targetParameter = $(if ($null -ne $verdictNode.Body.ParamBlock) { @($verdictNode.Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Target' }) | Select-Object -First 1 } else { $null })
$validateSetValues = $(if ($null -ne $targetParameter) { @($targetParameter.Attributes | Where-Object { ($_ -is [AttributeAst]) -and ($_.TypeName.Name -eq 'ValidateSet') } | ForEach-Object { $_.PositionalArguments } | ForEach-Object { [string]$_.Value } | Sort-Object -CaseSensitive) } else { @() })
Check-Equal "N4-P3 순수 판정 - 명령 0 · `$script: 0 · exit·throw·try 0 · return 7 · 반환 문자열 집합 · -Target ValidateSet = {entry, reward, field}" `
    ('명령 {0} · script {1} · exit/throw/try {2} · return {3} · 반환=[{4}] · ValidateSet=[{5}]' -f $verdictCommands, $verdictScriptVariables, $verdictExits, $verdictReturns.Count, ($verdictReturnValues -join ','), ($validateSetValues -join ',')) `
    ('명령 0 · script 0 · exit/throw/try 0 · return 7 · 반환=[{0}] · ValidateSet=[{1}]' -f ((@("''", "'cancelled'", "'entered'", "'field'", "'field-cancelled'", "'reclick'", "'reward'") | Sort-Object -Unique -CaseSensitive) -join ','), ((@('entry', 'field', 'reward') | Sort-Object -CaseSensitive) -join ','))

# N4-P4 - waiter 매개변수 이름 차례 = Game·LimitSeconds·Clock·Context·ReportRewardReturn·ReportFieldReturn(구현 단위 5b-8)·PanelSeen·ResumeGrace · $Clock 타입 없음 · [ref] 0
#   (⑥d 가 Target·ChallengeFewMembers 를 더할 때 갱신)
$waiterParameters = $(if ($null -ne $waiterNode.Body.ParamBlock) { @($waiterNode.Body.ParamBlock.Parameters) } else { @() })
$waiterParameterNames = @($waiterParameters | ForEach-Object { [string]$_.Name.VariablePath.UserPath }) -join ','
$clockParameter = @($waiterParameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Clock' }) | Select-Object -First 1
$clockTypeConstraints = $(if ($null -ne $clockParameter) { @($clockParameter.Attributes | Where-Object { $_ -is [TypeConstraintAst] }).Count } else { -1 })
$refConstraints = @($waiterParameters | ForEach-Object { $_.Attributes } | Where-Object { ($_ -is [TypeConstraintAst]) -and ($_.TypeName.Name -eq 'ref') }).Count
Check-Equal 'N4-P4 waiter 매개변수 = Game·LimitSeconds·Clock·Context·ReportRewardReturn·ReportFieldReturn·PanelSeen·ResumeGrace · $Clock 타입 없음 · [ref] 0' `
    ('이름=[{0}] · Clock 타입 {1} · ref {2}' -f $waiterParameterNames, $clockTypeConstraints, $refConstraints) '이름=[Game,LimitSeconds,Clock,Context,ReportRewardReturn,ReportFieldReturn,PanelSeen,ResumeGrace] · Clock 타입 0 · ref 0'

# N4-P5 - waiter 안 $script: 대입 = 정확히 1 - 대상 $script:lastClickSkipReason · 우변 빈 문자열 상수(따옴표 꼴·괄호 무관). 대입은 대상의 맨 앞 변수가
#   $script: 범위인 대입문(멤버·인덱스 대상 포함)과 증감(++ · --)을 함께 셉니다 - 워커 전역 상태를 바꾸는 꼴이면 문법이 달라도 같은 대입입니다
function Get-AssignedScriptVariable {
    # 대입·증감 대상 식의 맨 앞 변수(멤버·인덱스를 벗김)가 $script: 범위면 그 노드 (아니면 $null)
    param($Target)
    $baseNode = Get-InnerExpression $Target
    while ((($baseNode -is [MemberExpressionAst]) -and (-not ($baseNode -is [InvokeMemberExpressionAst]))) -or ($baseNode -is [IndexExpressionAst])) {
        $baseNode = Get-InnerExpression $(if ($baseNode -is [IndexExpressionAst]) { $baseNode.Target } else { $baseNode.Expression })
    }
    if (($baseNode -is [VariableExpressionAst]) -and ($baseNode.VariablePath.UserPath -like 'script:*')) { return $baseNode }
    return $null
}
$INCREMENT_TOKENS = @('PlusPlus', 'MinusMinus', 'PostfixPlusPlus', 'PostfixMinusMinus')
$scriptAssignments = @($waiterNode.FindAll({ param($candidate)
            (($candidate -is [AssignmentStatementAst]) -and ($null -ne (Get-AssignedScriptVariable $candidate.Left))) -or
            (($candidate -is [UnaryExpressionAst]) -and ($INCREMENT_TOKENS -contains [string]$candidate.TokenKind) -and ($null -ne (Get-AssignedScriptVariable $candidate.Child))) }, $true))
$scriptAssignmentOk = ($scriptAssignments.Count -eq 1) -and ($scriptAssignments[0] -is [AssignmentStatementAst]) -and (Test-IsVariable $scriptAssignments[0].Left 'script:lastClickSkipReason') -and
($scriptAssignments[0].Operator -eq [TokenKind]::Equals) -and
((Get-InnerExpression $scriptAssignments[0].Right) -is [StringConstantExpressionAst]) -and ([string](Get-InnerExpression $scriptAssignments[0].Right).Value -ceq '')
Check-True "N4-P5 waiter 안 `$script: 대입 = 정확히 1 (`$script:lastClickSkipReason ← 빈 문자열 상수)" $scriptAssignmentOk ((@($scriptAssignments | ForEach-Object { Get-NodeCode $_ })) -join ' | ')

# N4-P6 - waiter 명령 이름 집합 = 정확히 25 (구현 단위 5b-8 이 Step-AbyssFieldSettle · Test-AbyssSelectionScreen · Test-AbyssMenu 를, ⑤c 가 Resolve-AbyssResumeGrace 를 더함 - 허용 집합의 원본 - 구현이 도움 함수를 더하면 이 행과 명세 3.2.1 표 아래 첫 줄을 함께) · 순수 판정 0
$WAITER_COMMANDS_EXPECTED = @('ForEach-Object', 'Get-AbyssPanelKind', 'Get-Date', 'Invoke-PurchasePopupSweep', 'New-AbyssMemberClock', 'Resolve-AbyssHandoffStartScreen',
    'Resolve-AbyssMemberSweepTurn', 'Resolve-AbyssReentryVerdict', 'Resume-AbyssMemberClock', 'Select-Object', 'Start-Sleep', 'Test-AbyssMemberClockExpired',
    'Test-CaptureRecovered', 'Test-DungeonClearPrompt', 'Test-HomeEndEscHud', 'Test-InDungeonQuest', 'Test-SafeStopDuringCaptureFail', 'Test-UserRecentlyActive',
    'Wait-UserYieldEnd', 'Where-Object', 'Write-RunLog', 'Step-AbyssFieldSettle', 'Test-AbyssSelectionScreen', 'Test-AbyssMenu', 'Resolve-AbyssResumeGrace')
$waiterCommandSet = @($waiterNode.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true) | ForEach-Object { [string]$_.GetCommandName() } | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
$expectedCommandSet = @($WAITER_COMMANDS_EXPECTED | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
Check-Equal "N4-P6 waiter 명령 이름 집합 = 정확히 $($WAITER_COMMANDS_EXPECTED.Count)개(허용 집합) · 순수 판정 명령 0" `
    ('waiter=[{0}] · 순수 판정 {1}' -f ($waiterCommandSet -join ','), $verdictCommands) ('waiter=[{0}] · 순수 판정 0' -f ($expectedCommandSet -join ','))

# N4-P8 - return 1(함수 본문 끝 문장 · 해시 리터럴 키 {Result, LastKind, PanelSeen}) · break 2(while 본문 안 · 사이에 다른 루프·switch 0) · while 1($true)
$waiterReturns = @($waiterNode.FindAll({ param($candidate) $candidate -is [ReturnStatementAst] }, $true))
$lastWaiterStatement = @($waiterNode.Body.EndBlock.Statements)[-1]
$returnTable = $(if (($waiterReturns.Count -eq 1) -and [object]::ReferenceEquals($waiterReturns[0], $lastWaiterStatement)) { Get-InnerExpression $waiterReturns[0].Pipeline } else { $null })
$returnKeys = $(if ($returnTable -is [HashtableAst]) { (@($returnTable.KeyValuePairs | ForEach-Object { [string](Get-InnerExpression $_.Item1).Value } | Sort-Object)) -join ',' } else { '해시 아님' })
$breakNodes = @($waiterNode.FindAll({ param($candidate) $candidate -is [BreakStatementAst] }, $true))
$breakProblems = @($breakNodes | Where-Object {
        $breakParent = $_.Parent
        $blocked = $false
        while (($null -ne $breakParent) -and (-not [object]::ReferenceEquals($breakParent, $waiterWhile))) {
            if (($breakParent -is [LoopStatementAst]) -or ($breakParent -is [SwitchStatementAst])) { $blocked = $true }
            $breakParent = $breakParent.Parent
        }
        $blocked -or ($null -eq $breakParent)
    }).Count
Check-Equal 'N4-P8 return 1(함수 본문 끝 문장 · 해시 키 {Result, LastKind, PanelSeen}) · break 2(while 안 · 사이 루프·switch 0) · while 1($true)' `
    ('return {0} · 키=[{1}] · break {2}(어긋남 {3}) · while {4}({5})' -f $waiterReturns.Count, $returnKeys, $breakNodes.Count, $breakProblems, $waiterWhiles.Count, $(if ($null -ne $waiterWhile) { Get-NodeCode $waiterWhile.Condition } else { '' })) `
    'return 1 · 키=[LastKind,PanelSeen,Result] · break 2(어긋남 0) · while 1($true)'

# N4-P9 - S2 글자·채움 대응(뜻): waiter S2 를 채움 자리로 자른 고정 조각 열 = S2 고정 조각 열(-ceq · 여섯) · i 번째 채움 변수 이름 = 고정 채움 i 번째(다섯 · 대소문자
#   무관). 구현 단위 ⑤a 부터 선분기 S2 가 없어 대조 대상이 고정 문구 상수입니다(설계 R4 3.7 - 위 '정적 전제' 의 상수)
function Get-FillName {
    # 채움 하나가 가리키는 변수 이름 - ${x} · $x · $($x) (그 밖의 식은 '<식>')
    param($Nested)
    if ($Nested -is [VariableExpressionAst]) { return $Nested.VariablePath.UserPath.ToLowerInvariant() }
    if ($Nested -is [SubExpressionAst]) {
        $subStatements = @($Nested.SubExpression.Statements)
        if ($subStatements.Count -eq 1) { $subInner = Get-InnerExpression $subStatements[0]; if ($subInner -is [VariableExpressionAst]) { return $subInner.VariablePath.UserPath.ToLowerInvariant() } }
    }
    return '<식>'
}
function Get-S2Parts {
    # 확장 문자열을 채움 자리로 자른 고정 조각 열과 채움 이름 열
    param($StringNode)
    $rawText = $StringNode.Extent.Text
    $baseOffset = $StringNode.Extent.StartOffset
    $fragments = New-Object System.Collections.Generic.List[string]
    $fills = New-Object System.Collections.Generic.List[string]
    $cursor = 1
    foreach ($nested in @($StringNode.NestedExpressions | Sort-Object { $_.Extent.StartOffset })) {
        $nestedStart = $nested.Extent.StartOffset - $baseOffset
        $fragments.Add($rawText.Substring($cursor, $nestedStart - $cursor))
        $fills.Add((Get-FillName $nested))
        $cursor = $nested.Extent.EndOffset - $baseOffset
    }
    $fragments.Add($rawText.Substring($cursor, $rawText.Length - 1 - $cursor))
    return [pscustomobject]@{ Fragments = $fragments.ToArray(); Fills = $fills.ToArray() }
}
$n4p9Actual = 'S2 없음'
if ($s2ExpandableNodes.Count -eq 1) {
    $waiterParts = Get-S2Parts $s2ExpandableNodes[0].CommandElements[1]
    $fragmentMismatches = @()
    if ($waiterParts.Fragments.Count -ne $S2_FIXED_FRAGMENTS.Count) { $fragmentMismatches += "조각 수 $($waiterParts.Fragments.Count)" }
    else { for ($fragmentIndex = 0; $fragmentIndex -lt $S2_FIXED_FRAGMENTS.Count; $fragmentIndex++) { if ($waiterParts.Fragments[$fragmentIndex] -cne $S2_FIXED_FRAGMENTS[$fragmentIndex]) { $fragmentMismatches += "조각$fragmentIndex" } } }
    $n4p9Actual = '조각 {0}개 어긋남=[{1}] · 채움=[{2}]' -f $waiterParts.Fragments.Count, ($fragmentMismatches -join ','), ($waiterParts.Fills -join ',')
}
$n4p9Expected = '조각 {0}개 어긋남=[] · 채움=[{1}]' -f $S2_FIXED_FRAGMENTS.Count, ($S2_FIXED_FILLS -join ',')
Check-Equal 'N4-P9 S2 글자·채움 대응(⑤a) - waiter S2 고정 조각 열 = 고정 문구(설계 R4 3.7) 조각 열(-ceq · 여섯) · 채움 변수 이름 차례 = 고정 채움(entryUnknown·entryField·entryFieldPart·entryBreaks·memberFieldSettleSeconds)' $n4p9Actual $n4p9Expected

# N4-P10 - 무변화·정지 유예 시계 생성 두 문장(정규화 글자 - 구현 형상 계약) 각 1 · 둘 다 while 앞 · 함수 본문 직속(무조건 생성)
$N4P10_STATEMENTS = @('$quietClock = New-AbyssMemberClock -LimitSeconds $abyssReclickQuietSeconds', '$insideGraceClock = New-AbyssMemberClock -LimitSeconds $abyssReclickQuietSeconds -Paused')
$n4p10Facts = @(foreach ($expectedStatement in $N4P10_STATEMENTS) {
        $statementMatches = @($waiterNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and ((Get-NodeCode $candidate) -ceq $expectedStatement) }, $true))
        $directBefore = @($statementMatches | Where-Object { ([object]::ReferenceEquals($_.Parent, $waiterNode.Body.EndBlock)) -and (Test-BeforeWhile $_) }).Count
        '{0}={1}/{2}' -f ($expectedStatement.Split('=')[0].Trim()), $statementMatches.Count, $directBefore
    }) -join ' · '
Check-Equal 'N4-P10 무변화 시계·정지 유예 시계 생성 문장 각 1 · 함수 본문 직속(조건 안 0) · while 앞' $n4p10Facts '$quietClock=1/1 · $insideGraceClock=1/1'

# N4-P12 - 일곱 호출의 -Game 인자 = 변수 $Game(인자 꼴 무관) · Wait-UserYieldEnd 의 -Context 인자 = 변수 $Context 1
$N4P12_COMMANDS = @('Test-CaptureRecovered', 'Wait-UserYieldEnd', 'Invoke-PurchasePopupSweep', 'Test-DungeonClearPrompt', 'Get-AbyssPanelKind', 'Test-HomeEndEscHud', 'Test-InDungeonQuest')
$gameArgumentCalls = @($waiterNode.FindAll({ param($candidate) ($candidate -is [CommandAst]) -and ($N4P12_COMMANDS -contains $candidate.GetCommandName()) }, $true))
$gameArgumentProblems = @($gameArgumentCalls | Where-Object { -not (Test-IsVariable (Get-CommandArgument -Command $_ -Name 'Game') 'Game') } | ForEach-Object { $_.GetCommandName() })
$contextCalls = @($gameArgumentCalls | Where-Object { $_.GetCommandName() -eq 'Wait-UserYieldEnd' })
$contextOk = ($contextCalls.Count -eq 1) -and (Test-IsVariable (Get-CommandArgument -Command $contextCalls[0] -Name 'Context') 'Context')
Check-Equal 'N4-P12 Test-CaptureRecovered · Wait-UserYieldEnd · Invoke-PurchasePopupSweep · Test-DungeonClearPrompt · Get-AbyssPanelKind · Test-HomeEndEscHud · Test-InDungeonQuest 호출 7 모두 -Game = $Game · Wait-UserYieldEnd -Context = $Context 1' `
    ('호출 {0} · -Game 어긋남=[{1}] · 문맥 {2}' -f $gameArgumentCalls.Count, ($gameArgumentProblems -join ','), $contextOk) '호출 7 · -Game 어긋남=[] · 문맥 True'

# N4-P13 - 스윕 참 분기 사실(뜻): 분기 if 1 · continue 1(조건 = Action 정확 일치 {freeze, yield, counted}) · exit·return·break 0 · 굶김·복구 대입 각 1(Action 정확 일치) ·
#   분기 안 마감 판정 0 · 분기 안 $insideStreak 대입 = 상수 0 하나 · 분류 호출 1(매개변수·값 = 선분기 run:15104~15105 - 대칭 비교 무관) · 되돌림 if 1('yield' ∧ 살아 있는 연속,
#   본문 둘) · 직속 문장 차례 분류 < 되돌림 < 연속 0 < continue if · 연속 수 대입 = .Streak(해석된 형 Int32·Int64 한 겹까지) 1 + ⑦ else 직속 상수 0 1 · 루프 앞 상수 0 1
function Get-ParameterMap {
    # 명령 호출의 매개변수 이름 → 값 식 구조 문자열 (위치 인자는 따로) - 매개변수 순서·줄 이음·인자 꼴 무관
    param($Command)
    $parameterMap = @{}
    $positionalKeys = New-Object System.Collections.Generic.List[string]
    $elements = @($Command.CommandElements)
    $elementIndex = 1
    while ($elementIndex -lt $elements.Count) {
        $element = $elements[$elementIndex]
        if ($element -is [CommandParameterAst]) {
            $parameterName = $element.ParameterName.ToLowerInvariant()
            if ($null -ne $element.Argument) { $parameterMap[$parameterName] = ConvertTo-AstKey $element.Argument; $elementIndex++ }
            elseif (($elementIndex + 1 -lt $elements.Count) -and (-not ($elements[$elementIndex + 1] -is [CommandParameterAst]))) { $parameterMap[$parameterName] = ConvertTo-AstKey $elements[$elementIndex + 1]; $elementIndex += 2 }
            else { $parameterMap[$parameterName] = 'SWITCH'; $elementIndex++ }
        } else {
            $positionalKeys.Add((ConvertTo-AstKey $element))
            $elementIndex++
        }
    }
    return [pscustomobject]@{ Map = $parameterMap; Positional = ($positionalKeys.ToArray() -join '|') }
}
function Test-SameParameterMap {
    param($Left, $Right)
    if ($Left.Positional -cne $Right.Positional) { return $false }
    $leftKeys = @($Left.Map.Keys | Sort-Object)
    $rightKeys = @($Right.Map.Keys | Sort-Object)
    if (($leftKeys -join ',') -cne ($rightKeys -join ',')) { return $false }
    foreach ($mapKey in $leftKeys) { if ($Left.Map[$mapKey] -cne $Right.Map[$mapKey]) { return $false } }
    return $true
}
function Test-StreakRead {
    # 연속 수 대입 우변 = $sweepTurn.Streak (해석된 CLR 형이 System.Int32·System.Int64 인 변환 한 겹까지 · 괄호 무관)
    param($Right)
    $inner = Get-InnerExpression $Right
    if ($inner -is [ConvertExpressionAst]) {
        if (@('System.Int32', 'System.Int64') -notcontains (Get-ResolvedTypeName $inner.Type.TypeName)) { return $false }
        $inner = Get-InnerExpression $inner.Child
    }
    return (($inner -is [MemberExpressionAst]) -and (-not ($inner -is [InvokeMemberExpressionAst])) -and (-not $inner.Static) -and ($inner.Member.Extent.Text -eq 'Streak') -and (Test-IsVariable $inner.Expression 'sweepTurn'))
}
function Get-N4P13Problems {
    $problemList = New-Object System.Collections.Generic.List[string]
    $branchIfs = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-HasCommand $candidate.Clauses[0].Item1 'Invoke-PurchasePopupSweep') }, $true))
    if ($branchIfs.Count -ne 1) { $problemList.Add("스윕 분기 if $($branchIfs.Count)개"); return $problemList.ToArray() }
    $branchBody = $branchIfs[0].Clauses[0].Item2
    $continueNodes = @($branchBody.FindAll({ param($candidate) $candidate -is [ContinueStatementAst] }, $true))
    $continueIf = $null
    if ($continueNodes.Count -ne 1) { $problemList.Add("continue $($continueNodes.Count)개") }
    else {
        $continueIf = $continueNodes[0].Parent
        while (($null -ne $continueIf) -and (-not ($continueIf -is [IfStatementAst]))) { $continueIf = $continueIf.Parent }
        $continueResult = $(if ($null -ne $continueIf) { Test-ExactMatchSet -Expression $continueIf.Clauses[0].Item1 -IsSubject $IS_ACTION_SUBJECT -Want @('freeze', 'yield', 'counted') } else { 'if 없음' })
        if ($continueResult -cne 'OK') { $problemList.Add('continue 조건:' + $continueResult) }
    }
    $leaveCount = @($branchBody.FindAll({ param($candidate) ($candidate -is [ExitStatementAst]) -or ($candidate -is [ReturnStatementAst]) -or ($candidate -is [BreakStatementAst]) }, $true)).Count
    if ($leaveCount -ne 0) { $problemList.Add("exit·return·break $leaveCount") }
    foreach ($actionPair in @(@('sweepStarved', 'starved'), @('turnRecovered', 'recovered'))) {
        $actionAssignments = @($branchBody.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left $actionPair[0]) }, $true))
        if ($actionAssignments.Count -ne 1) { $problemList.Add("$($actionPair[0]) 대입 $($actionAssignments.Count)") }
        else {
            $actionResult = Test-ExactMatchSet -Expression $actionAssignments[0].Right -IsSubject $IS_ACTION_SUBJECT -Want @($actionPair[1])
            if ($actionResult -cne 'OK') { $problemList.Add("$($actionPair[0]):" + $actionResult) }
        }
    }
    if (Test-HasCommand $branchBody 'Test-AbyssMemberClockExpired') { $problemList.Add('분기 안 마감 판정') }
    $branchStreakAssignments = @($branchBody.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'insideStreak') }, $true))
    if (($branchStreakAssignments.Count -ne 1) -or ((ConvertTo-AstKey $branchStreakAssignments[0].Right) -cne 'C(Int32:0)')) { $problemList.Add("분기 안 연속 대입 $($branchStreakAssignments.Count)") }
    $selectorSweepCalls = @(Get-CommandNodes -Node $selectorNode -Name 'Resolve-AbyssMemberSweepTurn')
    $branchSweepCalls = @(Get-CommandNodes -Node $branchBody -Name 'Resolve-AbyssMemberSweepTurn')
    if (($selectorSweepCalls.Count -ne 1) -or ($branchSweepCalls.Count -ne 1) -or (-not (Test-SameParameterMap (Get-ParameterMap $branchSweepCalls[0]) (Get-ParameterMap $selectorSweepCalls[0])))) { $problemList.Add('분류 호출 인자 ≠ 선분기') }
    $branchStatements = @($branchBody.Statements)
    $revertIfs = @($branchStatements | Where-Object { ($_ -is [IfStatementAst]) -and (@($_.Clauses[0].Item2.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'insideGraceRun') }, $true)).Count -gt 0) })
    if ($revertIfs.Count -ne 1) { $problemList.Add("되돌림 if $($revertIfs.Count)개") }
    else {
        if ((Get-RevertKind $revertIfs[0]) -cne 'sweep') { $problemList.Add('되돌림 if 꼴=[' + (Get-NodeCode $revertIfs[0]) + ']') }
        $classifyIndex = -1; $zeroIndex = -1
        for ($statementIndex = 0; $statementIndex -lt $branchStatements.Count; $statementIndex++) {
            if (($classifyIndex -lt 0) -and ($branchStatements[$statementIndex] -is [AssignmentStatementAst]) -and (Test-IsVariable $branchStatements[$statementIndex].Left 'sweepTurn')) { $classifyIndex = $statementIndex }
            if (($zeroIndex -lt 0) -and ($branchStatements[$statementIndex] -is [AssignmentStatementAst]) -and (Test-IsVariable $branchStatements[$statementIndex].Left 'insideStreak')) { $zeroIndex = $statementIndex }
        }
        $revertIndex = [Array]::IndexOf($branchStatements, $revertIfs[0])
        $continueIndex = $(if ($null -ne $continueIf) { [Array]::IndexOf($branchStatements, $continueIf) } else { -1 })
        if (-not (($classifyIndex -ge 0) -and ($classifyIndex -lt $revertIndex) -and ($revertIndex -lt $zeroIndex) -and ($zeroIndex -lt $continueIndex))) { $problemList.Add("차례 분류 $classifyIndex · 되돌림 $revertIndex · 연속 0 $zeroIndex · continue $continueIndex") }
    }
    $loopStreakAssignments = $(if ($null -ne $waiterWhile) { @($waiterWhile.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'sweepStreak') }, $true)) } else { @() })
    $readAssignments = @($loopStreakAssignments | Where-Object { Test-StreakRead $_.Right })
    $zeroAssignments = @($loopStreakAssignments | Where-Object { (ConvertTo-AstKey $_.Right) -ceq 'C(Int32:0)' })
    if (($loopStreakAssignments.Count -ne 2) -or ($readAssignments.Count -ne 1) -or ($zeroAssignments.Count -ne 1)) { $problemList.Add("while 안 연속 수 대입 $($loopStreakAssignments.Count)(.Streak $($readAssignments.Count) · 0 $($zeroAssignments.Count))") }
    if (($readAssignments.Count -ge 1) -and (-not (Test-AstWithin -Node $readAssignments[0] -Ancestor $branchBody))) { $problemList.Add('.Streak 대입이 분기 밖') }
    $validityElse = Get-ValidityElseBlock
    $zeroPlaceOk = $false
    if (($null -ne $validityElse) -and ($zeroAssignments.Count -eq 1)) {
        $elseStatements = @($validityElse.Statements)
        $zeroPosition = [Array]::IndexOf($elseStatements, $zeroAssignments[0])
        if ($zeroPosition -ge 0) {
            $firstReader = -1
            for ($statementIndex = 0; $statementIndex -lt $elseStatements.Count; $statementIndex++) {
                if ($statementIndex -eq $zeroPosition) { continue }
                $readerCount = @($elseStatements[$statementIndex].FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -eq 'sweepStreak') -and
                            (-not (($candidate.Parent -is [AssignmentStatementAst]) -and [object]::ReferenceEquals($candidate.Parent.Left, $candidate))) }, $true)).Count
                if ($readerCount -gt 0) { $firstReader = $statementIndex; break }
            }
            $zeroPlaceOk = ($firstReader -lt 0) -or ($zeroPosition -lt $firstReader)
        }
    }
    if (-not $zeroPlaceOk) { $problemList.Add('상수 0 이 ⑦ else 블록 직속이 아님') }
    $preLoopAssignments = @($waiterNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'sweepStreak') -and (Test-BeforeWhile $candidate) }, $true))
    if (($preLoopAssignments.Count -ne 1) -or ((ConvertTo-AstKey $preLoopAssignments[0].Right) -cne 'C(Int32:0)')) { $problemList.Add("루프 앞 연속 수 초기화 $($preLoopAssignments.Count)") }
    return $problemList.ToArray()
}
$n4p13Problems = @(Get-N4P13Problems)
Check-True "N4-P13 스윕 참 분기 사실(뜻) - continue 조건 {freeze, yield, counted} · 굶김·복구 대입 · 분기 안 마감 판정 0 · 연속 0 하나 · 분류 인자 = 선분기 · 되돌림 if('yield' ∧ 살아 있는 연속 · 본문 둘) · 차례 분류 < 되돌림 < 연속 0 < continue · 연속 수 대입 .Streak 1 + ⑦ else 상수 0 1 · 루프 앞 0 1" `
    ($n4p13Problems.Count -eq 0) ($n4p13Problems -join ' · ')

# N4-P14 - waiter 안 Write-RunLog = 정확히 4 · 모두 인자 하나 - S2 확장 문자열(S2 고정 접두) 1 · 권장 인원 팝업 관측 안내 상수 1 · 재매칭 패널 확인 안내 상수 1 ·
#   필드 확정 확장 문자열(필드 확정 접두) 1 · 그 밖 0 (뒤 둘은 구현 단위 5b-8)
$logKinds = @($waiterLogNodes | ForEach-Object {
        $logElements = @($_.CommandElements)
        if ($logElements.Count -ne 2) { "인자 $($logElements.Count - 1)개" }
        elseif (($logElements[1] -is [ExpandableStringExpressionAst]) -and ($S2_PREFIX.Length -gt 0) -and ([string]$logElements[1].Value).StartsWith($S2_PREFIX)) { 'S2' }
        elseif (($logElements[1] -is [StringConstantExpressionAst]) -and ([string]$logElements[1].Value -ceq $NOTICE_FULL_TEXT)) { '안내' }
        elseif (($logElements[1] -is [StringConstantExpressionAst]) -and ([string]$logElements[1].Value -ceq $PANEL_NOTICE_TEXT)) { '패널' }
        elseif (($logElements[1] -is [ExpandableStringExpressionAst]) -and ([string]$logElements[1].Value).StartsWith($SETTLE_LINE_PREFIX, [StringComparison]::Ordinal)) { '필드 확정' }
        else { '그 밖' }
    } | Sort-Object)
Check-Equal "N4-P14 waiter 안 Write-RunLog = 정확히 4 · 인자 하나씩 - S2 확장 문자열 1 · '$NOTICE_FULL_TEXT' 1 · '$PANEL_NOTICE_TEXT' 1 · 필드 확정 줄 1 · 그 밖 0 (결과 줄은 호출부 문구)" `
    ('Write-RunLog {0} = [{1}]' -f $waiterLogNodes.Count, ($logKinds -join ',')) ('Write-RunLog 4 = [{0}]' -f ((@('S2', '안내', '패널', '필드 확정') | Sort-Object) -join ','))

# ── §8b 구현 단위 5b-8 정적 FC-S (명세 5b-8 3.3 · 3.7a - 주석 뺀 사본 · AST). 행이 못 잡는 등가 변이와 배선 꼴을 고정합니다 - 같은 뜻의 다른 꼴을 택하면 구현과 함께 갱신.
#    끝(retry) 갈래 · exit · 재생 사본은 §10 정적(FC-S15 · FC-S16 · FC-S19) ──
function Get-AndLeafCodes {
    # -and 로 이은 조건의 잎 글자 (괄호를 벗김 - 순서 무관 비교용, 열거용)
    param($Node)
    $innerNode = Get-InnerExpression $Node
    if (($innerNode -is [BinaryExpressionAst]) -and ($innerNode.Operator -eq [TokenKind]::And)) { return @(@(Get-AndLeafCodes $innerNode.Left) + @(Get-AndLeafCodes $innerNode.Right)) }
    return @(Get-NodeCode $innerNode)
}
function Get-ParameterArgumentCode {
    # 명령 호출에서 그 매개변수의 값 글자 (콜론 꼴 · 띄어 쓴 꼴 - 없으면 '(없음)', 값 없는 스위치면 '(스위치)')
    param($Command, [string]$Name)
    $commandElements = @($Command.CommandElements)
    for ($elementIndex = 1; $elementIndex -lt $commandElements.Count; $elementIndex++) {
        $element = $commandElements[$elementIndex]
        if (($element -is [CommandParameterAst]) -and ($element.ParameterName -eq $Name)) {
            if ($null -ne $element.Argument) { return (Get-NodeCode $element.Argument) }
            if (($elementIndex + 1 -lt $commandElements.Count) -and (-not ($commandElements[$elementIndex + 1] -is [CommandParameterAst]))) { return (Get-NodeCode $commandElements[$elementIndex + 1]) }
            return '(스위치)'
        }
    }
    return '(없음)'
}
function Get-StatementHead {
    # 문장 머리 - if 면 'if <첫 절 조건>', 대입이면 대상 변수 이름, 그 밖은 문장 글자
    param($Statement)
    if ($Statement -is [IfStatementAst]) { return ('if ' + (Get-NodeCode $Statement.Clauses[0].Item1)) }
    if ($Statement -is [AssignmentStatementAst]) {
        $assignedNode = Get-InnerExpression $Statement.Left
        if ($assignedNode -is [VariableExpressionAst]) { return [string]$assignedNode.VariablePath.UserPath }
    }
    return (Get-NodeCode $Statement)
}
$fcWaiterWhile = $waiterNode.Find({ param($candidate) $candidate -is [WhileStatementAst] }, $true)
$fcWhileCodes = @($fcWaiterWhile.Body.Statements | ForEach-Object { Get-NodeCode $_ })

# FC-S1 (2.1) - 순수 판정 새 행: 'field-cancelled' 행 하나 · 절 1 · else 0 · 조건 -and 잎 넷 일대일(순서 무관 - 목표 entry · 필드 결과 · 분류 field · 필드 확정. 패널 관측 · 보고 ·
#   무변화 · 던전 안 연속을 보지 않음 - 사용자 결정 U-5b8-1) · 본문 직속 if 차례(return 글자)
$fcVerdictIfs = @($verdictNode.Body.EndBlock.Statements | Where-Object { $_ -is [IfStatementAst] })
$fcVerdictOrder = (@($fcVerdictIfs | ForEach-Object {
            $fcFirstStatement = @($_.Clauses[0].Item2.Statements)[0]
            $fcReturnInner = $(if ($fcFirstStatement -is [ReturnStatementAst]) { Get-InnerExpression $fcFirstStatement.Pipeline } else { $null })
            $(if ($fcReturnInner -is [StringConstantExpressionAst]) { [string]$fcReturnInner.Value } else { '?' })
        })) -join ' < '
$fcNewRows = @($fcVerdictIfs | Where-Object { (Get-NodeCode $_.Clauses[0].Item2) -ceq "{ return 'field-cancelled' }" })
$fcNewRowText = '(행 {0})' -f $fcNewRows.Count
if ($fcNewRows.Count -eq 1) {
    $fcNewRowText = '절 {0} · else {1} · 잎=[{2}]' -f $fcNewRows[0].Clauses.Count, [int]($null -ne $fcNewRows[0].ElseClause), ((@(Get-AndLeafCodes $fcNewRows[0].Clauses[0].Item1 | Sort-Object -CaseSensitive)) -join ' & ')
}
$fcNewRowLeaves = (@(@('$Target -eq ''entry''', '$ReportFieldReturn', '$Kind -eq ''field''', '$FieldSettled') | Sort-Object -CaseSensitive)) -join ' & '
Check-Equal "FC-S1 순수 판정 새 행 - 'field-cancelled' 행 하나 · 절 1 · else 0 · 잎 넷(목표 entry · 필드 결과 · 분류 field · 필드 확정) · 본문 직속 if 차례" `
    ('{0} · 차례=[{1}]' -f $fcNewRowText, $fcVerdictOrder) ('절 1 · else 0 · 잎=[{0}] · 차례=[entered < field < reward < field-cancelled < cancelled < reclick]' -f $fcNewRowLeaves)

# FC-S2 · FC-S3 (2.1 · 2.2-1) - ReportFieldReturn 매개변수: 순수 판정 [bool](띄어 쓴 값도 묶임) · 대기 [switch](호출 B 는 콜론 꼴) · 기본값 없음 · 자리 = ReportRewardReturn 바로 뒤
$fcParamShape = (@(foreach ($fcOwner in @($verdictNode, $waiterNode)) {
            $fcParams = @($fcOwner.Body.ParamBlock.Parameters)
            $fcNames = [string[]]@($fcParams | ForEach-Object { [string]$_.Name.VariablePath.UserPath })
            $fcAt = [Array]::IndexOf($fcNames, 'ReportFieldReturn')
            $(if ($fcAt -lt 1) { '{0}:자리 {1}' -f $fcOwner.Name, $fcAt } else { '{0}:{1}/기본값 {2}/앞 {3}' -f $fcOwner.Name, $fcParams[$fcAt].StaticType.Name, [int]($null -ne $fcParams[$fcAt].DefaultValue), $fcNames[$fcAt - 1] })
        })) -join ' · '
Check-Equal 'FC-S2 · FC-S3 ReportFieldReturn 매개변수 - 순수 판정 [bool] · 대기 [switch] · 기본값 없음 · 자리 = ReportRewardReturn 바로 뒤' $fcParamShape `
    'Resolve-AbyssReentryVerdict:Boolean/기본값 0/앞 ReportRewardReturn · Wait-AbyssReentry:SwitchParameter/기본값 0/앞 ReportRewardReturn'

# FC-S4 (2.2-3 · 4 · 4a · 6 · 8) - 새 상태 변수의 대입 수 · 함수 직속 초기화(while 앞 - 이어받기 · 표본 시각 · 확정 결과는 회전마다라 직속 0) · 초기값
#   while 앞만 셉니다 - StrictMode 가 없어 초기화를 while 뒤로 옮겨도 미정의 = $null 로 동작이 같아 행이 못 잡음(변이 M82 - 구현 리뷰 2/2 의 3/5)
$FC_STATE_NAMES = @('panelNoticed', 'settleState', 'settleNext', 'settleAlive', 'fieldAt', 'selectionNow', 'menuNow', 'earlyScreen', 'fieldSettled', 'settlePrevious', 'settleSpan', 'settleCount')
$fcAssignNames = @($waiterNode.FindAll({ param($candidate) $candidate -is [AssignmentStatementAst] }, $true) | ForEach-Object { $fcLeft = Get-InnerExpression $_.Left; $(if ($fcLeft -is [VariableExpressionAst]) { [string]$fcLeft.VariablePath.UserPath } else { '' }) })
$fcAssignText = (@(foreach ($fcName in $FC_STATE_NAMES) { '{0}={1}' -f $fcName, @($fcAssignNames | Where-Object { $_ -ceq $fcName }).Count })) -join ' '
$fcInitStatements = @($waiterNode.Body.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and (Test-BeforeWhile $_) })
$fcInitNames = @($fcInitStatements | ForEach-Object { Get-StatementHead $_ })
$fcInitText = (@(foreach ($fcName in @('panelNoticed', 'settleState', 'settleNext', 'settleAlive', 'fieldAt', 'fieldSettled')) { '{0}={1}' -f $fcName, @($fcInitNames | Where-Object { $_ -ceq $fcName }).Count })) -join ' '
$fcInitCodes = @($fcInitStatements | ForEach-Object { Get-NodeCode $_ })
$fcInitValues = (@(@('$panelNoticed = $false', '$settleState = $null', '$settleNext = $false') | ForEach-Object { [int]($fcInitCodes -ccontains $_) })) -join ''
Check-Equal 'FC-S4 새 상태 변수 대입 수 · 함수 직속 while 앞 초기화(패널 안내 표식 · 확정 상태 · 이어받기 표식만) · 초기값' ('대입=[{0}] · 함수 직속 while 앞=[{1}] · 초기값 {2}' -f $fcAssignText, $fcInitText, $fcInitValues) `
    '대입=[panelNoticed=2 settleState=2 settleNext=3 settleAlive=2 fieldAt=2 selectionNow=2 menuNow=2 earlyScreen=1 fieldSettled=2 settlePrevious=1 settleSpan=1 settleCount=1] · 함수 직속 while 앞=[panelNoticed=1 settleState=1 settleNext=1 settleAlive=0 fieldAt=0 fieldSettled=0] · 초기값 111'

# FC-S5 (2.2-4 · R5 2.2) - 서두 이어받기: 메타 비움 바로 뒤 두 문장 = 선분기 while 의 같은 두 문장(소스 캡처) · 정확히 1 · ① 동결 if 앞(동결 회전이 continue 로 건너뛰면 연속이 안 끊김)
$fcSkipAt = [Array]::IndexOf([string[]]$fcWhileCodes, '$script:lastClickSkipReason = ''''')
$fcFreezeAt = -1
for ($fcIndex = 0; $fcIndex -lt $fcWhileCodes.Count; $fcIndex++) { if ($fcWhileCodes[$fcIndex].StartsWith('if ($script:screenCaptureFailing) {', [StringComparison]::Ordinal)) { $fcFreezeAt = $fcIndex; break } }
$fcCarryText = $(if (($fcSkipAt -ge 0) -and ($fcSkipAt + 2 -lt $fcWhileCodes.Count)) { '{0} | {1}' -f $fcWhileCodes[$fcSkipAt + 1], $fcWhileCodes[$fcSkipAt + 2] } else { '(메타 비움 줄 없음)' })
$fcSelectorCodes = @($selectorWhile.Body.Statements | ForEach-Object { Get-NodeCode $_ })
$fcSelectorSkipAt = [Array]::IndexOf([string[]]$fcSelectorCodes, '$script:lastClickSkipReason = ''''')
$fcSelectorCarry = $(if (($fcSelectorSkipAt -ge 0) -and ($fcSelectorSkipAt + 2 -lt $fcSelectorCodes.Count)) { '{0} | {1}' -f $fcSelectorCodes[$fcSelectorSkipAt + 1], $fcSelectorCodes[$fcSelectorSkipAt + 2] } else { '(선분기 메타 비움 줄 없음)' })
$fcCarryCount = @($fcWhileCodes | Where-Object { $_ -ceq '$settleAlive = $settleNext' }).Count
Check-Equal "FC-S5 서두 이어받기 - 메타 비움 바로 뒤 두 문장 = 선분기의 두 문장(소스 캡처) · while 직속 '`$settleAlive = `$settleNext' 1 · ① 동결 if 앞" `
    ('{0} · 개수 {1} · 동결 if 앞 {2}' -f $fcCarryText, $fcCarryCount, (($fcSkipAt -ge 0) -and ($fcFreezeAt -gt ($fcSkipAt + 2)))) ('{0} · 개수 1 · 동결 if 앞 True' -f $fcSelectorCarry)

# FC-S6 (2.2-4 · 5) - $fieldAt 대입 정확히 2: 서두($turnStart = Get-Date 바로 뒤 $fieldAt = $turnStart) · ⑥ 간접 양보(Get-Date - 가상 시계 모의를 지나는 꼴)
$fcFieldAtCodes = @($waiterNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'fieldAt') }, $true) | ForEach-Object { Get-NodeCode $_ })
$fcTurnStartAt = [Array]::IndexOf([string[]]$fcWhileCodes, '$turnStart = Get-Date')
$fcFieldAtAfterTurn = $(if (($fcTurnStartAt -ge 0) -and ($fcTurnStartAt + 1 -lt $fcWhileCodes.Count)) { $fcWhileCodes[$fcTurnStartAt + 1] } else { '(없음)' })
Check-Equal "FC-S6 `$fieldAt 대입 정확히 2 - 서두(`$turnStart = Get-Date 바로 뒤) · ⑥ 간접 양보(Get-Date)" ('{0} · 서두 다음 문장 [{1}]' -f ($fcFieldAtCodes -join ' | '), $fcFieldAtAfterTurn) `
    '$fieldAt = $turnStart | $fieldAt = Get-Date · 서두 다음 문장 [$fieldAt = $turnStart]'

# FC-S7 (2.2-5 · R5 2.1 ⑥) - ⑥ 간접 양보 갈래 하나 · 본문 = 되돌림 if · 던전 안 연속 끊음 · 필드 연속 끊음 · 필드 표본 시각 = 양보 뒤 (선분기는 필드 연속을 끊지 않음 - ⑱′ WA-F7)
$fcIndirectIfs = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and ((Get-NodeCode $candidate.Clauses[0].Item1) -ceq '[double]$script:userYieldTotalMs -ne $turnYieldMs') }, $true))
$fcIndirectBody = $(if ($fcIndirectIfs.Count -eq 1) { (@($fcIndirectIfs[0].Clauses[0].Item2.Statements | ForEach-Object { Get-NodeCode $_ })) -join ' ; ' } else { '(⑥ if {0}개)' -f $fcIndirectIfs.Count })
Check-Equal 'FC-S7 ⑥ 간접 양보 본문 - 되돌림 if · 던전 안 연속 끊음 · 필드 연속 끊음 · 필드 표본 시각 = 양보 뒤 새 시각' $fcIndirectBody `
    'if ($insideStreak -gt 0) { $insideGraceRun = 0; $insideGraceReverted = $true } ; $insideStreak = 0 ; $settleAlive = $false ; $fieldAt = Get-Date'

# FC-S8 (2.2-6) - Step-AbyssFieldSettle 호출 하나 = 선분기 호출에서 -TurnStart 만 $fieldAt(소스 캡처) · 감싼 조건(필드 if · ⑦ 유효 else · ⑥~⑨ if) · 평가 차례 ⑧ 분류 < Step < ⑨ 결론
$fcStepCalls = @(Get-CommandNodes -Node $waiterNode -Name 'Step-AbyssFieldSettle')
$fcSelectorStep = @(Get-CommandNodes -Node $selectorNode -Name 'Step-AbyssFieldSettle')
$fcStepExpected = $(if ($fcSelectorStep.Count -eq 1) { (Get-NodeCode $fcSelectorStep[0]).Replace('-TurnStart $turnStart', '-TurnStart $fieldAt') } else { '(선분기 Step {0})' -f $fcSelectorStep.Count })
$fcVerdictCalls = @(Get-CommandNodes -Node $waiterNode -Name 'Resolve-AbyssReentryVerdict')
$fcStepText = '(Step {0})' -f $fcStepCalls.Count
if ($fcStepCalls.Count -eq 1) {
    $fcStepText = '{0} · 감싼 조건=[{1}] · ⑧ 분류 < Step < ⑨ 결론 {2}' -f (Get-NodeCode $fcStepCalls[0]), ((@(Get-EnclosingIfConditions -Node $fcStepCalls[0] -Stop $waiterNode)) -join ' < '),
    (($classifyCalls.Count -eq 2) -and ($fcVerdictCalls.Count -eq 1) -and ($classifyCalls[1].Extent.StartOffset -lt $fcStepCalls[0].Extent.StartOffset) -and ($fcStepCalls[0].Extent.StartOffset -lt $fcVerdictCalls[0].Extent.StartOffset))
}
Check-Equal 'FC-S8 Step 호출 하나 = 선분기 호출에서 -TurnStart 만 $fieldAt · 감싼 조건(필드 결과 켬 ∧ 필드 모양 · ⑦ 유효 else · ⑥~⑨ if) · ⑧ 분류 < Step < ⑨ 결론' $fcStepText `
    ("{0} · 감싼 조건=[`$ReportFieldReturn -and (`$screen -eq 'field') < else `$script:screenCaptureFailing -or `$script:captureFailSerial -ne `$turnSerial < (-not `$sweepStarved) -and (-not `$turnRecovered)] · ⑧ 분류 < Step < ⑨ 결론 True" -f $fcStepExpected)

# FC-S9 (2.2-7) - ⑨ 결론 호출 인자(매개변수마다 - 줄 이음 무관) · $fieldSettled 대입 둘(유효 회전마다 거짓 · 필드 if 안 확정)
$fcVerdictArgs = $(if ($fcVerdictCalls.Count -eq 1) { (@(@('Kind', 'InsideStreak', 'PanelSeen', 'Target', 'ReportRewardReturn', 'ReportFieldReturn', 'QuietExpired', 'FieldSettled') | ForEach-Object { '{0}={1}' -f $_, (Get-ParameterArgumentCode $fcVerdictCalls[0] $_) })) -join ' ' } else { '(⑨ 호출 {0})' -f $fcVerdictCalls.Count })
$fcFieldSettledCodes = (@($waiterNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'fieldSettled') }, $true) | ForEach-Object { Get-NodeCode $_ })) -join ' | '
Check-Equal 'FC-S9 ⑨ 결론 호출 인자 - 필드 결과 = ([bool]$ReportFieldReturn) · 필드 확정 = $fieldSettled · 목표 entry · $fieldSettled 대입 둘' ('{0} · 대입=[{1}]' -f $fcVerdictArgs, $fcFieldSettledCodes) `
    ("Kind=`$screen InsideStreak=`$insideStreak PanelSeen=`$panelObserved Target='entry' ReportRewardReturn=([bool]`$ReportRewardReturn) ReportFieldReturn=([bool]`$ReportFieldReturn) QuietExpired=`$quietExpired FieldSettled=`$fieldSettled · 대입=[`$fieldSettled = `$false | `$fieldSettled = [bool]`$settleState.Confirmed]")

# FC-S10 (2.2-6) - 필드 if 하나: 바로 앞 문장 = '$fieldSettled = $false' · 본문 차례 = 앞 상태(끊김이면 $null) → Step → 확정 결과 → 미확정이면 이어받기 표식 · 절 1 · else 0
$fcFieldIfs = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and ((Get-NodeCode $candidate.Clauses[0].Item1) -ceq '$ReportFieldReturn -and ($screen -eq ''field'')') }, $true))
$fcFieldIfText = '(필드 if {0})' -f $fcFieldIfs.Count
if ($fcFieldIfs.Count -eq 1) {
    $fcSiblings = @($fcFieldIfs[0].Parent.Statements)
    $fcFieldIfIndex = [Array]::IndexOf($fcSiblings, $fcFieldIfs[0])
    $fcFieldIfText = '앞 문장 [{0}] · 본문 [{1}] · 절 {2} · else {3}' -f $(if ($fcFieldIfIndex -ge 1) { Get-NodeCode $fcSiblings[$fcFieldIfIndex - 1] } else { '' }),
    ((@($fcFieldIfs[0].Clauses[0].Item2.Statements | ForEach-Object { Get-NodeCode $_ })) -join ' ; '), $fcFieldIfs[0].Clauses.Count, [int]($null -ne $fcFieldIfs[0].ElseClause)
}
Check-Equal 'FC-S10 필드 if - 앞 문장 = 확정 결과 거짓 · 본문 차례(앞 상태 → Step → 확정 결과 → 미확정이면 이어받기 표식) · 절 1 · else 0' $fcFieldIfText `
    ('앞 문장 [$fieldSettled = $false] · 본문 [$settlePrevious = $(if ($settleAlive) {{ $settleState }} else {{ $null }}) ; $settleState = {0} ; $fieldSettled = [bool]$settleState.Confirmed ; if (-not $fieldSettled) {{ $settleNext = $true }}] · 절 1 · else 0' -f $fcStepExpected)

# FC-S11 (2.2-8) - 필드 확정 줄 하나: 고정 조각 · 채움(W 변수 · settleSpan · settleCount - 숫자 박기 0) · 감싼 조건(결과 'field-cancelled') · settleSpan 우변(확정 회전 표본 시각 기준)
$fcSettleLogs = @($waiterLogNodes | Where-Object { (@($_.CommandElements).Count -eq 2) -and ($_.CommandElements[1] -is [ExpandableStringExpressionAst]) -and ([string]$_.CommandElements[1].Value).StartsWith($SETTLE_LINE_PREFIX, [StringComparison]::Ordinal) })
$fcSettleText = '(확정 줄 {0})' -f $fcSettleLogs.Count
if ($fcSettleLogs.Count -eq 1) {
    $fcSettleParts = Get-S2Parts $fcSettleLogs[0].CommandElements[1]
    $fcSpanCodes = (@($waiterNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'settleSpan') }, $true) | ForEach-Object { Get-NodeCode $_.Right })) -join ' | '
    $fcSettleText = '조각=[{0}] · 채움=[{1}] · 감싼 조건=[{2}] · settleSpan=[{3}]' -f ($fcSettleParts.Fragments -join '|'), ($fcSettleParts.Fills -join ','),
    ((@(Get-EnclosingIfConditions -Node $fcSettleLogs[0] -Stop $waiterNode)) -join ' < '), $fcSpanCodes
}
Check-Equal "FC-S11 필드 확정 줄 - 고정 조각 · 채움 셋(숫자 박기 0) · 감싼 조건(결과 'field-cancelled' · ⑦ 유효 else · ⑥~⑨ if) · settleSpan 우변" $fcSettleText `
    ("조각=[[어비스] 던전 밖(HUD) 확인 - 필드 모양이 |초 이어졌습니다 (첫 표본부터 |초, |표본)] · 채움=[memberfieldsettleseconds,settlespan,settlecount] · 감싼 조건=[`$result -eq 'field-cancelled' < " +
        "else `$script:screenCaptureFailing -or `$script:captureFailSerial -ne `$turnSerial < (-not `$sweepStarved) -and (-not `$turnRecovered)] · settleSpan=[[Math]::Round((`$fieldAt - [datetime]`$settleState.Since).TotalSeconds, 1)]")

# FC-S12 (2.2-6 · 1.6 ①) - 재매칭 패널 확인 안내 하나: 감싼 if 잎 셋(보고 켬 · 1회 표식 · 패널류 셋 - 팝업 제외) · 본문 = 표식 → 안내 · 앞 둘 = 패널 관측 if · 권장 인원 안내 if · 뒤 = 확정 결과 거짓
$fcPanelLogs = @($waiterLogNodes | Where-Object { (@($_.CommandElements).Count -eq 2) -and ($_.CommandElements[1] -is [StringConstantExpressionAst]) -and ([string]$_.CommandElements[1].Value -ceq $PANEL_NOTICE_TEXT) })
$fcPanelText = '(패널 안내 {0})' -f $fcPanelLogs.Count
if ($fcPanelLogs.Count -eq 1) {
    $fcPanelIf = $fcPanelLogs[0].Parent
    while (($null -ne $fcPanelIf) -and (-not ($fcPanelIf -is [IfStatementAst]))) { $fcPanelIf = $fcPanelIf.Parent }
    $fcPanelSiblings = @($fcPanelIf.Parent.Statements)
    $fcPanelAt = [Array]::IndexOf($fcPanelSiblings, $fcPanelIf)
    $fcPanelText = '잎=[{0}] · 본문=[{1}] · 앞 둘=[{2} / {3}] · 뒤=[{4}]' -f ((@(Get-AndLeafCodes $fcPanelIf.Clauses[0].Item1 | Sort-Object -CaseSensitive)) -join ' & '),
    ((@($fcPanelIf.Clauses[0].Item2.Statements | ForEach-Object { Get-NodeCode $_ })) -join ' ; '), (Get-StatementHead $fcPanelSiblings[$fcPanelAt - 2]), (Get-StatementHead $fcPanelSiblings[$fcPanelAt - 1]),
    (Get-StatementHead $fcPanelSiblings[$fcPanelAt + 1])
}
$fcPanelLeaves = (@(@('$ReportRewardReturn', '-not $panelNoticed', "@('ready', 'matching', 'entry-waiting') -contains `$screen") | Sort-Object -CaseSensitive)) -join ' & '
Check-Equal 'FC-S12 재매칭 패널 확인 안내 - 잎 셋(보고 켬 · 1회 표식 · 패널류 셋) · 본문 = 표식 → 안내 · 앞 둘 = 패널 관측 if · 권장 인원 안내 if · 뒤 = 확정 결과 거짓' $fcPanelText `
    ("잎=[{0}] · 본문=[`$panelNoticed = `$true ; Write-RunLog '{1}'] · 앞 둘=[if @('popup', 'ready', 'matching', 'entry-waiting') -contains `$screen / if `$ReportRewardReturn -and (`$screen -eq 'popup') -and (-not `$popupNoticed)] · 뒤=[fieldSettled]" -f $fcPanelLeaves, $PANEL_NOTICE_TEXT)

# FC-S13 (2.3-1 · 0.4) - 재입장 대기 호출의 필드 결과 스위치: 끝(retry) 호출 B 1 · 콜론 꼴(띄어 쓰면 스위치가 늘 켜지고 괄호 값이 위치 인자 $Clock 으로 묶임 - PS 5.1 실측) · 인자 =
#   모드 예산 식(Get-AbyssReentryLimitSeconds 첫 if 조건)의 -eq → -ne(소스 캡처) · 선분기 호출 C(⑤c 5c-2 - Role resume)는 호출 B 와 같은 식 · 끝(other) 호출 E · 선분기 B2 는 0
$fcSwitchShape = (@(foreach ($fcCaller in @('Complete-AbyssRetrySelection', 'Complete-AbyssOtherSelection', 'Invoke-AbyssHandoffStart')) {
            $fcCalls = @(Get-CommandNodes -Node (Get-WorkerFunction $fcCaller) -Name 'Wait-AbyssReentry')
            $fcSwitchParams = @($fcCalls | ForEach-Object { $_.CommandElements } | Where-Object { ($_ -is [CommandParameterAst]) -and ($_.ParameterName -eq 'ReportFieldReturn') })
            '{0}:{1}/{2}[{3}]' -f $fcCaller, $fcCalls.Count, $fcSwitchParams.Count, ((@($fcSwitchParams | ForEach-Object { $(if ($null -ne $_.Argument) { Get-NodeCode (Get-InnerExpression $_.Argument) } else { '(콜론 인자 없음)' }) })) -join ',')
        })) -join ' · '
$fcModeIfs = @((Get-WorkerFunction 'Get-AbyssReentryLimitSeconds').FindAll({ param($candidate) $candidate -is [IfStatementAst] }, $true))
$fcModeCondition = $(if ($fcModeIfs.Count -ge 1) { Get-NodeCode $fcModeIfs[0].Clauses[0].Item1 } else { '(모드 if 없음)' })
Check-Equal 'FC-S13 재입장 대기 호출의 필드 결과 스위치 - 끝(retry) 호출 B 1 · 콜론 꼴 · 인자 = 모드 예산 식의 -ne · 선분기 호출 C 1(⑤c - 같은 식) · 끝(other) 호출 E 0 · 선분기 B2 0' $fcSwitchShape `
    ('Complete-AbyssRetrySelection:1/1[{0}] · Complete-AbyssOtherSelection:1/0[] · Invoke-AbyssHandoffStart:2/1[{0}]' -f $fcModeCondition.Replace(' -eq ', ' -ne '))

# FC-S14 - 이름 있는 인자 ⊆ 피호출 param (전체 이름 - 대기 · 순수 판정 · Step · 재개 유예 판정 · 재개 끝(⑤c)이 모두 단순 함수라 모르는 이름이 오류 없이 $args 로 사라짐 - PS 5.1 실측)
$fcCallees = @('Wait-AbyssReentry', 'Resolve-AbyssReentryVerdict', 'Step-AbyssFieldSettle', 'Resolve-AbyssResumeGrace', 'Complete-AbyssResumeWait')
$fcUnknownNames = @(foreach ($fcCallee in $fcCallees) {
        $fcDeclared = @((Get-WorkerFunction $fcCallee).Body.ParamBlock.Parameters | ForEach-Object { [string]$_.Name.VariablePath.UserPath })
        foreach ($fcCall in @(Get-CommandNodes -Node $workerAst -Name $fcCallee)) {
            foreach ($fcParam in @($fcCall.CommandElements | Where-Object { $_ -is [CommandParameterAst] })) {
                if (-not ($fcDeclared -contains $fcParam.ParameterName)) { '{0}@{1}: -{2}' -f $fcCallee, (Get-EnclosingFunctionName $fcCall), $fcParam.ParameterName }
            }
        }
    })
$fcCallCount = (@(foreach ($fcCallee in $fcCallees) { '{0} {1}' -f $fcCallee, @(Get-CommandNodes -Node $workerAst -Name $fcCallee).Count })) -join ' · '
Check-True ('FC-S14 이름 있는 인자 ⊆ 피호출 param(전체 이름) - 호출 {0}' -f $fcCallCount) ($fcUnknownNames.Count -eq 0) ($fcUnknownNames -join ' · ')

# FC-S17 - 'field-cancelled' 철자 정확히 4곳(판정 return · 대기 확정 줄 if · 끝(retry) 갈래 · 재개 끝 갈래(⑤c 5c-2)) · 'field' 와 'cancel' 이 함께 든 다른 문자열 0 (한 곳만 틀리면 끝 갈래에 안 걸리고 재클릭 꼬리를 탐)
$fcSpellNodes = @($workerAst.FindAll({ param($candidate) ($candidate -is [StringConstantExpressionAst]) -and ([string]$candidate.Value -ceq 'field-cancelled') }, $true))
$fcSpellOwners = (@($fcSpellNodes | ForEach-Object { Get-EnclosingFunctionName $_ } | Sort-Object -CaseSensitive)) -join ','
$fcLookalike = @($workerAst.FindAll({ param($candidate) ($candidate -is [StringConstantExpressionAst]) -and ([string]$candidate.Value -cne 'field-cancelled') -and ([string]$candidate.Value).Contains('field') -and ([string]$candidate.Value).Contains('cancel') }, $true) | ForEach-Object { [string]$_.Value })
Check-Equal "FC-S17 'field-cancelled' 철자 4곳 · 닮은 글자 0" ('{0} [{1}] · 닮은 글자 [{2}]' -f $fcSpellNodes.Count, $fcSpellOwners, ($fcLookalike -join ',')) `
    ('4 [{0}] · 닮은 글자 []' -f ((@('Complete-AbyssResumeWait', 'Complete-AbyssRetrySelection', 'Resolve-AbyssReentryVerdict', 'Wait-AbyssReentry') | Sort-Object -CaseSensitive) -join ','))

# FC-S18 - 계측 변수(run* · entry*)가 대기 함수의 if · while 조건 · Step · ⑨ 인자에 0 (로그 전용 - 필드 확정은 Step 상태만. 계측 $runField 는 끊김에서 안 비워짐)
$fcGuardNodes = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -or ($candidate -is [WhileStatementAst]) }, $true) | ForEach-Object {
        if ($_ -is [IfStatementAst]) { foreach ($fcClause in $_.Clauses) { $fcClause.Item1 } } else { $_.Condition }
    })
$fcGuardNodes += @($fcStepCalls) + @($fcVerdictCalls)
$fcRunVariables = @($fcGuardNodes | ForEach-Object { $_.FindAll({ param($candidate) $candidate -is [VariableExpressionAst] }, $true) } | ForEach-Object { [string]$_.VariablePath.UserPath } |
    Where-Object { ($_ -like 'run*') -or ($_ -like 'entry*') } | Sort-Object -Unique)
Check-Equal 'FC-S18 계측 변수(run* · entry*) - 대기 함수의 if · while 조건 · Step · ⑨ 인자에 0' ('[{0}]' -f ($fcRunVariables -join ',')) '[]'

# FC-S20 - Step-AbyssFieldSettle 호출 자리 = 선분기 1 · 재입장 대기 1 정확히
$fcStepOwners = (@(Get-CommandNodes -Node $workerAst -Name 'Step-AbyssFieldSettle' | ForEach-Object { Get-EnclosingFunctionName $_ } | Sort-Object -CaseSensitive)) -join ','
Check-Equal 'FC-S20 Step-AbyssFieldSettle 호출 자리 = 선분기 1 · 재입장 대기 1' $fcStepOwners ((@('Invoke-AbyssHandoffStart', 'Wait-AbyssReentry') | Sort-Object -CaseSensitive) -join ',')

# FC-S21 (2.2-4a) - ⑤ 판독 if(try 안 · ⑥ 앞) 차례: 하단 · 패널 · HUD · 추적기 · 두 판독 초기화 · 필드 결과 if(앞 분류 = 세 신호 없는 분류 · 'field' 일 때 선택 화면 → 거짓이면 메뉴)
$fcWaiterTry = @($fcWaiterWhile.Body.Statements | Where-Object { $_ -is [TryStatementAst] })
$fcReadIf = @($(if ($fcWaiterTry.Count -eq 1) { @($fcWaiterTry[0].Body.Statements | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-NodeCode $_.Clauses[0].Item1) -ceq '(-not $sweepStarved) -and (-not $turnRecovered)') }) }))
$fcReadShape = '(try {0} · ⑤ 판독 if {1})' -f $fcWaiterTry.Count, $fcReadIf.Count
if ($fcReadIf.Count -eq 1) {
    $fcReadStatements = @($fcReadIf[0].Clauses[0].Item2.Statements)
    $fcSwitchIf = @($fcReadStatements | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-NodeCode $_.Clauses[0].Item1) -ceq '$ReportFieldReturn') })
    $fcSwitchBody = $(if ($fcSwitchIf.Count -eq 1) { (@($fcSwitchIf[0].Clauses[0].Item2.Statements | ForEach-Object { Get-NodeCode $_ })) -join ' ; ' } else { '(필드 결과 if {0})' -f $fcSwitchIf.Count })
    $fcReadShape = '차례=[{0}] · 필드 결과 if=[{1}]' -f ((@($fcReadStatements | ForEach-Object { Get-StatementHead $_ })) -join ','), $fcSwitchBody
}
Check-Equal "FC-S21 ⑤ 판독 if(try 안) 차례 · 필드 결과 if(앞 분류 · 'field' 일 때 선택 화면 → 메뉴 · 상세 없음)" $fcReadShape `
    ("차례=[promptNow,bottomText,panelKind,hudNow,questNow,selectionNow,menuNow,if `$ReportFieldReturn] · 필드 결과 if=[`$earlyScreen = Resolve-AbyssHandoffStartScreen -PromptVisible `$promptNow -BottomText `$bottomText " +
        "-PanelKind `$panelKind -HudVisible `$hudNow -InDungeonQuest `$questNow ; if (`$earlyScreen -eq 'field') { `$selectionNow = Test-AbyssSelectionScreen -Game `$Game if (-not `$selectionNow) { `$menuNow = Test-AbyssMenu -Game `$Game } }]")

# ── §9 ⑤b3 '다른 던전 가기' 대기 · 끝 함수 - 행(대기 66 · 끝 33) · 정적(R6-P · R5-P · SEL · WAIT 의 other 몫 22) (구현 명세 ⑤b3 2.2 · 3.1 · 3.2 - 비교는 -ceq) ──
# 대상(구현 명세 ⑤b3 1.2 · 1.3): Wait-AbyssOtherSelection(대기 - 결과 @{ Result; Sends; LastKind }) · Complete-AbyssOtherSelection(끝 - ReadySelection · 정지 끝 B ·
#   폴백 ②③). 워커 안 호출은 끝 함수의 대기 1뿐입니다(본류 배선은 5b-5 - 아래 정적 P0). 원문을 그대로 올립니다(사본 재구현 금지) - 대기는 exit 0 을 확인한 뒤
#   그대로, 끝 함수는 exit 를 센티널 throw('__EXIT__N')로 바꿔 올립니다. 둘 중 하나라도 워커에 없으면 'FAIL 준비' 로 끝납니다(§9 의 행·정적이 돌지 않음 - 명세 0.4)
# 하니스(명세 2.2): §4 의 가상 시계(Get-Date · Start-Sleep · Step-VirtualClock - 시계 훅은 OW28 · OS4r 의 일련번호 +1 → 되돌림 몫) · 캡처 상태 모형(Register-MockFail ·
#   원문 Register-CaptureSuccess · 실패 창 · 주기 실패 창) · 조작 창(Test-UserRecentlyActive · Wait-UserYieldEnd 모의 - 0ms 양보만 이 절이 감쌈) · 스윕 모의
#   (Set-SweepFrom - 'sent' · 'recover' · 'rect-click-throw' · 'click-throw-noreg' + 새 'gate-true') · 탐침 · 안전 확인(원문 센티널) · 스윕 분류 감시 · 안전 중지 파일
#   모의를 그대로 씁니다. 이 절이 더하는 것 = 판독 스텁 다섯(짝 · HUD · 추적기 · 선택 화면 · 패널 - 판독마다 가상 0.05초 · §9 시각표 · 판독 훅) · 클릭 기록 스텁
#   (전송 수 · 좌표 · 전송 뒤 화면 전이 · 'user-active'/'cursor-not-ready' 주입) · 끝 함수용 기록 스텁(대기 결과 · 헬퍼 · 복귀 루프 · 진단). 마감 L = $timeoutAbyssSelect ·
#   헬퍼 부모 예산 · 두 창 좌표 문구는 소스 캡처이고 행의 마감 시각은 모두 L 에서 계산합니다(숫자 재기입 없음 - 규칙 9). 행 이름 = 시제품 하니스 v4 의 이름
#   (괄호 = 설계 v11 R6 이름 - 명세 3.1). 판독 훅 · 시계 훅은 스크립트 범위 스크립트블록이고 $script: 와 리터럴 · 스크립트 상수만 읽습니다(GetNewClosure 금지 - 규칙 3)
foreach ($otherTargetName in @('Wait-AbyssOtherSelection', 'Complete-AbyssOtherSelection')) {
    if (-not $workerFunctions.ContainsKey($otherTargetName)) { "FAIL 준비: 워커 최상위에 $otherTargetName 이(가) 없습니다 (구현 명세 ⑤b3 2.1)"; exit 1 }
}
$otherWaitNode = $workerFunctions['Wait-AbyssOtherSelection']
$otherFinishNode = $workerFunctions['Complete-AbyssOtherSelection']
$otherWaitExits = @($otherWaitNode.FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count
if ($otherWaitExits -gt 0) { "FAIL 준비: Wait-AbyssOtherSelection 안에 exit ${otherWaitExits}개 - 하니스를 같은 프로세스에서 돌릴 수 없습니다"; exit 1 }

# 상수 - 워커 최상위 대입을 config 기본값으로 평가합니다(Get-ConfigInteger 는 기본값 반환 모의 - §2 의 Get-ConfigValue 모의와 같은 뜻 · test_abyss_handoff_start 선례)
try {
    Invoke-Expression (New-MockDefinition -Name 'Get-ConfigInteger' -Body 'return $Default')
    $timeoutAbyssSelect = [int](Get-SourceAssignmentValue 'timeoutAbyssSelect')
    $timeoutHud = [int](Get-SourceAssignmentValue 'timeoutHud')
    $timeoutAbyssMenu = [int](Get-SourceAssignmentValue 'timeoutAbyssMenu')
} catch {
    "FAIL 준비: ⑤b3 상수 캡처 실패 ($($_.Exception.Message))"
    exit 1
}
$OTHER_WAIT_LIMIT = $timeoutAbyssSelect                                        # L - 대기 마감(진입부터 · 전송마다 다시)
$OTHER_HELPER_BUDGET = $timeoutHud + $timeoutAbyssMenu + $timeoutAbyssSelect   # 폴백 ② 헬퍼 부모 마감(초) - 끝 함수 원문 식의 세 상수 합
# L 의 행 설계 범위 (명세 리뷰 2 P3 - 숨은 경계). 행의 마감 시각은 L 에서 만들지만, 입력 시각 몇은 확인 창(전송 뒤 2초 + 1초×6 - 하니스 판독 포함 끝 = 전송 + 8.3초)
#   뒤의 바깥 회전에 고정돼 있고(전송 뒤 8.32 ~ 10초 · OW26 둘째 3버튼 9.9초 · OW20 조작 [3, 23) · 실패 [30, 60)), 상한 몇은 고정이거나 L 에 비례해 쌓이는 캡처
#   실패 차분에 걸립니다(WA-S1 · WA-S3 T < 100 · WA-S2 T < 200 · SW7 · OS5 [L, L + 3)). 정수 L 을 하나씩 바꿔 잰 범위(범위 안 모든 정수에서 행 전부 통과 - 10 에서
#   OW26 · OW20, 8 에서 열 행, 37 에서 SW7 FAIL) 밖이면 행이 확인 창 뒤 회전보다 짧은 마감이나 상한 밖 시각을 보므로 FAIL 준비로 끝냅니다. 기본값이 범위를
#   벗어나게 바뀌면 그 행들의 시각을 L 에서 다시 만들고 범위를 다시 잽니다
$OTHER_WAIT_LIMIT_MIN = 11
$OTHER_WAIT_LIMIT_MAX = 36
if (($OTHER_WAIT_LIMIT -lt $OTHER_WAIT_LIMIT_MIN) -or ($OTHER_WAIT_LIMIT -gt $OTHER_WAIT_LIMIT_MAX)) {
    "FAIL 준비: ⑤b3 마감 L(`$timeoutAbyssSelect 기본값) ${OTHER_WAIT_LIMIT}초가 §9 행 설계 범위 [${OTHER_WAIT_LIMIT_MIN}, ${OTHER_WAIT_LIMIT_MAX}]초 밖입니다 - 확인 창 뒤 바깥 회전 · 고정 상한 행이 경계를 보지 못합니다 (구현 명세 ⑤b3 3.1 · 명세 리뷰 2 P3)"
    exit 1
}
# 대기 값의 기대 (정적 WAIT - 구현 리뷰 B P3 · 명세 1.2 ① · ⑫). 동결 · 복구 · 기본 대기는 같은 골격인 선분기(Invoke-AbyssHandoffStart) 원문의 같은 자리 값입니다
#   (소스 캡처 - 복구 · 기본은 §2 의 $RECOVERED_WAIT_MS · $BASE_WAIT_MS, 동결은 여기서 그 동결 블록의 Start-Sleep). 짝 재판독은 이 대기에만 있는 갈래라 캡처할
#   다른 원문이 없어 계약 값입니다(범위 ⑤-23 '1초 재판독' · 설계 v11 R6 2.5 - 대기 함수 자신에서 캡처하면 변이를 따라 움직임)
function Get-OtherSleepText {
    # 문장 글자 - Start-Sleep 하나(-Seconds 또는 -Milliseconds 숫자 상수 하나 · 그 밖 인자 0)면 'Nms', 레이블 없는 continue 면 'continue', 그 밖은 주석 뺀 글자를 괄호로
    param($Statement)
    $sleepCommand = Get-StatementCommand $Statement
    if (($null -ne $sleepCommand) -and ($sleepCommand.GetCommandName() -eq 'Start-Sleep') -and (@($sleepCommand.CommandElements).Count -le 3)) {
        $secondsArgument = Get-CommandArgument -Command $sleepCommand -Name 'Seconds' -PositionalNames @('Seconds')
        $millisecondsArgument = Get-CommandArgument -Command $sleepCommand -Name 'Milliseconds' -PositionalNames @()
        $sleepArgument = $(if ($null -eq $millisecondsArgument) { $secondsArgument } elseif ($null -eq $secondsArgument) { $millisecondsArgument } else { $null })
        $sleepScale = $(if ($null -eq $millisecondsArgument) { 1000 } else { 1 })
        $sleepValue = Get-InnerExpression $sleepArgument
        if (($sleepValue -is [ConstantExpressionAst]) -and (($sleepValue.Value -is [int]) -or ($sleepValue.Value -is [long]) -or ($sleepValue.Value -is [double]))) {
            return ('{0}ms' -f ([double]$sleepValue.Value * $sleepScale))
        }
    }
    if (($Statement -is [ContinueStatementAst]) -and ($null -eq $Statement.Label)) { return 'continue' }
    return ('(' + (Get-NodeCode $Statement) + ')')
}
$OTHER_PAIR_RECHECK_MS = 1000   # 짝 재판독 대기(계약 1초 - 위 주석)
$selectorFreezeIfs5b3 = @($selectorWhile.Body.Statements | Where-Object { ($_ -is [IfStatementAst]) -and (Test-IsVariable $_.Clauses[0].Item1 'script:screenCaptureFailing') })
$selectorFreezeWaits5b3 = @(foreach ($selectorFreezeIf5b3 in $selectorFreezeIfs5b3) {
        foreach ($selectorFreezeStatement5b3 in @($selectorFreezeIf5b3.Clauses[0].Item2.Statements)) {
            $selectorFreezeCommand5b3 = Get-StatementCommand $selectorFreezeStatement5b3
            if (($null -ne $selectorFreezeCommand5b3) -and ($selectorFreezeCommand5b3.GetCommandName() -eq 'Start-Sleep')) { Get-OtherSleepText $selectorFreezeStatement5b3 }
        }
    })
if (($selectorFreezeIfs5b3.Count -ne 1) -or ($selectorFreezeWaits5b3.Count -ne 1) -or (-not ([string]$selectorFreezeWaits5b3[0] -match '^\d+ms$'))) {
    "FAIL 준비: 선분기 동결 블록의 대기를 캡처하지 못했습니다 (동결 if $($selectorFreezeIfs5b3.Count)개 · 대기 [$($selectorFreezeWaits5b3 -join ', ')] - 정적 WAIT 의 기대 · 구현 리뷰 B P3)"
    exit 1
}
$OTHER_FREEZE_WAIT_TEXT = [string]$selectorFreezeWaits5b3[0]

# 원문 올림 - 출처 판정은 원문 그대로 · 대기는 원문 그대로(위에서 exit 0 확인) · 끝 함수는 exit 센티널 치환본(§3 Convert-ExitSentinel - 줄 단독 exit 만 치환)
try {
    foreach ($definition5b3 in @(Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-AbyssSelectionProvenance', 'Wait-AbyssOtherSelection'))) { Invoke-Expression ([string]$definition5b3) }
} catch {
    "FAIL 준비: ⑤b3 함수를 워커에서 추출하지 못했습니다 ($($_.Exception.Message))"
    exit 1
}
$otherFinishDefinition = Convert-ExitSentinel -Text ([string]$otherFinishNode.Extent.Text) -Label 'Complete-AbyssOtherSelection'
$otherFinishSentinel = $script:sentinelChecks[$script:sentinelChecks.Count - 1]
if (($otherFinishSentinel[1] -lt 1) -or ($otherFinishSentinel[2] -ne $otherFinishSentinel[1]) -or ($otherFinishSentinel[3] -ne 0)) {
    "FAIL 준비: Complete-AbyssOtherSelection exit 센티널 - 원본 ExitStatementAst $($otherFinishSentinel[1]) · 줄 단독 $($otherFinishSentinel[2]) · 치환 뒤 $($otherFinishSentinel[3]) (모두 줄 단독이어야 함 - 명세 1.3)"
    exit 1
}

# 화면 약어 → 판독값 (명세 2.2). 하단 판독문은 §4 $SCREEN_TABLE 의 실측 문자열 그대로(R · M · E · I · F · U)이거나 그 문자열에서 조각 하나를 뺀 변형입니다
#   (Rn = R 의 '다른던전가기' 뺌 - 3버튼 · 점 없음 / Rx = R 의 '나가기' 뺌 - 점 있음 · 서명 거짓). 'S' 는 이 절에서 선택 화면(보상 위 오버레이 - 재생 기록의 하단 '')이고
#   §4 의 'S'(화면 터치 프롬프트)와 다릅니다. RS = 3버튼 + 선택 화면 플레이크 · SE = 하단은 접힌 준비 패널 서명인데 선택 화면 판독은 양성(전이 회전). Other = 그 판독의
#   '다른 던전 가기' 점 있음 · Retry = '다시 하기' 점 있음(대기는 읽지 않음 - 반환 꼴만)
$OTHER_WAIT_SCREENS = [ordered]@{
    'R'  = @{ Bottom = $SCREEN_TABLE['R'].Bottom; Retry = $true; Other = $true; Hud = $false; Quest = $false; Selection = $false; Panel = 'none' }
    'Rn' = @{ Bottom = $SCREEN_TABLE['R'].Bottom.Replace('다른던전가기', ''); Retry = $true; Other = $false; Hud = $false; Quest = $false; Selection = $false; Panel = 'none' }
    'Rx' = @{ Bottom = $SCREEN_TABLE['R'].Bottom.Replace('나가기', ''); Retry = $true; Other = $true; Hud = $false; Quest = $false; Selection = $false; Panel = 'none' }
    'RS' = @{ Bottom = $SCREEN_TABLE['R'].Bottom; Retry = $true; Other = $true; Hud = $false; Quest = $false; Selection = $true; Panel = 'none' }
    'M'  = @{ Bottom = $SCREEN_TABLE['M'].Bottom; Retry = $false; Other = $false; Hud = $false; Quest = $false; Selection = $false; Panel = 'matching' }
    'SE' = @{ Bottom = $SCREEN_TABLE['E'].Bottom; Retry = $false; Other = $false; Hud = $false; Quest = $false; Selection = $true; Panel = 'none' }
    'S'  = @{ Bottom = ''; Retry = $false; Other = $false; Hud = $false; Quest = $false; Selection = $true; Panel = 'none' }
    'I'  = @{ Bottom = $SCREEN_TABLE['I'].Bottom; Retry = $false; Other = $false; Hud = $true; Quest = $true; Selection = $false; Panel = 'none' }
    'F'  = @{ Bottom = $SCREEN_TABLE['F'].Bottom; Retry = $false; Other = $false; Hud = $true; Quest = $false; Selection = $false; Panel = 'none' }
    'U'  = @{ Bottom = $SCREEN_TABLE['U'].Bottom; Retry = $false; Other = $false; Hud = $false; Quest = $false; Selection = $false; Panel = 'none' }
}
$OTHER_WAIT_KINDS = [ordered]@{ 'R' = 'reward3'; 'Rn' = 'reward3'; 'Rx' = 'unknown'; 'RS' = 'selection'; 'M' = 'panel'; 'SE' = 'panel'; 'S' = 'selection'; 'I' = 'inside'; 'F' = 'field'; 'U' = 'unknown' }
# 대응표 확인(준비 - 행이 가정하는 분류를 원문 분류 함수가 냄)
$otherKindsActual = @(foreach ($screenKey in $OTHER_WAIT_SCREENS.Keys) {
        $screenEntry = $OTHER_WAIT_SCREENS[$screenKey]
        '{0}={1}' -f $screenKey, (Resolve-AbyssOtherWaitScreen -BottomText $screenEntry.Bottom -PanelKind $screenEntry.Panel -SelectionVisible $screenEntry.Selection -HudVisible $screenEntry.Hud -InDungeonQuest $screenEntry.Quest)
    }) -join ' '
$otherKindsExpected = @(foreach ($screenKey in $OTHER_WAIT_KINDS.Keys) { '{0}={1}' -f $screenKey, $OTHER_WAIT_KINDS[$screenKey] }) -join ' '
if ($otherKindsActual -cne $otherKindsExpected) { "FAIL 준비: §9 화면 대응표의 원문 분류가 어긋납니다 (실제 [$otherKindsActual] / 기대 [$otherKindsExpected])"; exit 1 }

$OTHER_WAIT_READ_SECONDS = 0.05                     # 판독 한 번의 가상 시간 - 확인 창 끝(전송 + 2 + 6 × (1 + 판독))이 이 값에서 나옴
$OTHER_WAIT_DEFAULT_POINTS = @(,@(0, 778, 654))     # '다른 던전 가기' 점(기준 좌표) - 시각부터 (x, y) · 09-18 보관 프레임의 3버튼 점
$OTHER_WAIT_RETRY_POINT = @(636, 654)               # '다시 하기' 점(반환 꼴만 - 대기는 Retry 를 읽지 않음)
$OTHER_WAIT_OTHER_ERROR = $OTHER_ERROR_TEXT         # 판독 훅 'other-throw' - 등록 없는 다른 예외 (§7 WA-L44 와 같은 글자)
$OTHER_WAIT_THIRD_ERROR = 'TEST-THIRD-ERROR'        # 판독 훅 'rect-other' - gameWindowGone 등록 뒤 두 문구가 아닌 예외
$OTHER_PAIR_NOTICE_PREFIX = "[어비스] 보상 화면에서 '다른 던전 가기' 글자를 찾지 못했습니다 - 1초 뒤 다시 읽습니다 (판독: '"   # 짝 없음 첫 회 안내(명세 1.2 로그 · B-8) - '(판독: …)' 꼬리 앞까지의 글자
# 이벤트 정리 · ESC 의 기록 모의 (OW18 - 설계 v11 R6 7.1 OW18 'X·ESC 0' · R6-P6 · R6-M20 · 명세 리뷰 2 P2). 넷 중 Clear-EventOverlay 와 키 둘은 §3 기록 모의이고
#   Invoke-EventSkipOrConfirm 은 이 절이 같은 몸통의 기록 모의로 둡니다(아래 모의 정의). 닫기(X) 후보 클릭은 클릭 스텁(전송 · 클릭 시도)이 셉니다
$OTHER_EVENT_CALL_NAMES = @('Clear-EventOverlay', 'Invoke-EventSkipOrConfirm', 'Press-KeyOnce', 'Press-KeyVerified')
# 확인 창 판독 지연(OW19 · OS1) - 확인 창 끝 = 전송 + 2 + 6 × (1 + 판독 + 지연) = 전송 + L + 0.5 가 되게 L 에서 계산합니다(마감 경계 회전의 성공 먼저)
$OW19_DELAY_SECONDS = ($OTHER_WAIT_LIMIT + 0.5 - 2 - 6 * (1 + $OTHER_WAIT_READ_SECONDS)) / 6

# §9 시각표 - (시각, 약어) 단계 목록. 전송 뒤 전이는 클릭 스텁이 그 전송 시각 + 상대 시각으로 더합니다
function Add-OtherWaitPlan {
    param([double]$At, [string]$Screen)
    if (-not $OTHER_WAIT_SCREENS.Contains($Screen)) { throw "§9 시각표의 약어 $Screen 이(가) 대응표에 없습니다" }
    $script:otherWaitPlanSeq++
    $script:otherWaitPlan = @(@(@($script:otherWaitPlan) + @(@{ AtTicks = (ConvertTo-Ticks $At); S = $Screen; Seq = $script:otherWaitPlanSeq })) |
            Sort-Object @{ Expression = { $_.AtTicks } }, @{ Expression = { $_.Seq } })
}
function Get-OtherWaitScreenNow {
    # 지금 화면 - 시각 ≤ 지금인 마지막 단계 (첫 단계보다 이르면 'U')
    $nowTicks = Get-VirtualTicks
    $screenKey = 'U'
    foreach ($planStep in @($script:otherWaitPlan)) { if ($planStep.AtTicks -le $nowTicks) { $screenKey = [string]$planStep.S } }
    return $screenKey
}
function Get-OtherWaitPointNow {
    # 지금의 '다른 던전 가기' 점 - 시각 ≤ 지금인 마지막 (x, y) (OW12 - 양보 중 점이 옮겨 감)
    $nowTicks = Get-VirtualTicks
    $pointNow = @($script:otherWaitPoints)[0]
    foreach ($pointStep in @($script:otherWaitPoints)) { if ((ConvertTo-Ticks ([double]$pointStep[0])) -le $nowTicks) { $pointNow = $pointStep } }
    return @{ X = [int]$pointNow[1]; Y = [int]$pointNow[2] }
}
function Invoke-OtherWaitRead {
    # 판독 한 번(판독 스텁 다섯의 공통 몸통): 가상 0.05초 · 판독 기록 · 판정(행 판독 훅 > 실패 창) · 캡처 등록 → 지금 화면 약어(실패면 $null).
    #   훅 판정 - 'fail'(원인 other 등록 · 실패) · 'rect'(gameWindowGone 등록 → 짝은 실패 반환(원문 짝 판독은 throw 없음 - Text '') · 그 밖은 판독 경로 문구 throw) ·
    #   'other-throw'(등록 없는 다른 예외) · 'rect-other'(gameWindowGone 등록 → 셋째 예외) · 'msg-othercause'(원인 other 등록 → 판독 경로 문구 throw) · 그 밖 = 성공
    param([string]$Name)
    $script:captureAttempts++
    if ($script:captureAttempts -gt $CALL_LIMIT) { throw '__VTIMEOUT__' }
    Step-VirtualClock $OTHER_WAIT_READ_SECONDS
    $script:otherWaitReads.Add([pscustomobject]@{ T = (Get-VirtualElapsed); Name = $Name })
    $script:otherWaitPrevRead = $Name
    $readVerdict = ''
    if ($null -ne $script:otherWaitReadHook) { $readVerdict = "$(& $script:otherWaitReadHook $Name)" }
    elseif (Test-InFailWindow) { $readVerdict = 'fail' }
    if ($readVerdict -eq 'fail') { Register-MockFail -Cause $OTHER_CAUSE; return $null }
    if ($readVerdict -eq 'rect') {
        Register-MockFail -Cause $WINDOW_GONE_CAUSE
        if ($Name -eq 'pair') { return $null }
        throw $READ_PATH_MESSAGE
    }
    if ($readVerdict -eq 'other-throw') { throw $OTHER_WAIT_OTHER_ERROR }
    if ($readVerdict -eq 'rect-other') { Register-MockFail -Cause $WINDOW_GONE_CAUSE; throw $OTHER_WAIT_THIRD_ERROR }
    if ($readVerdict -eq 'msg-othercause') { Register-MockFail -Cause $OTHER_CAUSE; throw $READ_PATH_MESSAGE }
    Register-MockSuccess
    return (Get-OtherWaitScreenNow)
}
function Invoke-OtherPairStub {
    # 짝 판독 - @{ Text; Retry; Other } (캡처 실패면 Text '' · 두 점 $null - 원문 Find-AbyssRewardButtonPair 의 반환 꼴)
    $screenKey = Invoke-OtherWaitRead -Name 'pair'
    if ($null -eq $screenKey) { return @{ Text = ''; Retry = $null; Other = $null } }
    $screenEntry = $OTHER_WAIT_SCREENS[$screenKey]
    $retryPoint = $null
    if ($screenEntry.Retry) { $retryPoint = @{ X = $OTHER_WAIT_RETRY_POINT[0]; Y = $OTHER_WAIT_RETRY_POINT[1] } }
    $otherPoint = $null
    if ($screenEntry.Other) { $otherPoint = Get-OtherWaitPointNow }
    return @{ Text = [string]$screenEntry.Bottom; Retry = $retryPoint; Other = $otherPoint }
}
function Invoke-OtherFlagStub {
    # HUD · 추적기 판독 - 캡처 실패면 거짓
    param([string]$Name, [string]$Field)
    $screenKey = Invoke-OtherWaitRead -Name $Name
    return (($null -ne $screenKey) -and [bool]$OTHER_WAIT_SCREENS[$screenKey][$Field])
}
function Invoke-OtherSelectionStub {
    # 선택 화면 판독 - 행 선택 화면 훅(판독 직전) · 양성 판독 수 기록(OS5) · 캡처 실패면 거짓(원문 Test-AbyssSelectionScreen 과 같음)
    if ($null -ne $script:otherWaitSelectionHook) { $null = & $script:otherWaitSelectionHook }
    $screenKey = Invoke-OtherWaitRead -Name 'selection'
    $selectionSeen = ($null -ne $screenKey) -and [bool]$OTHER_WAIT_SCREENS[$screenKey].Selection
    if ($selectionSeen) { $script:otherWaitSelectionTrue++ }
    return $selectionSeen
}
function Invoke-OtherPanelStub {
    # 패널 종류 - 행 패널 덮어쓰기(WA-S9 · OS3m - 판독은 그대로 한 번) · 캡처 실패면 'none'(원문 Get-AbyssPanelKind 와 같음)
    if ($null -ne $script:otherWaitPanelOverride) {
        $overrideKind = "$(& $script:otherWaitPanelOverride)"
        if ($overrideKind) { $null = Invoke-OtherWaitRead -Name 'panel'; return $overrideKind }
    }
    $screenKey = Invoke-OtherWaitRead -Name 'panel'
    if ($null -eq $screenKey) { return 'none' }
    return [string]$OTHER_WAIT_SCREENS[$screenKey].Panel
}
function Invoke-OtherClickStub {
    # 클릭 기록 - 조작 창 안이면 'user-active' 생략 · 커서 미확인 주입이 남았으면 'cursor-not-ready' 생략 · 그 밖은 전송(메타 둘을 씀) → 그 전송 번호의 화면 전이를 시각표에
    param([int]$ReferenceX, [int]$ReferenceY)
    $script:otherWaitClickTries++
    if ($null -ne (Get-ActiveWindowNow)) { $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'user-active'; return }
    if ($script:otherWaitCursorMisses -gt 0) { $script:otherWaitCursorMisses--; $script:lastClickPerformed = $false; $script:lastClickSkipReason = 'cursor-not-ready'; return }
    $script:lastClickPerformed = $true
    $script:lastClickSkipReason = ''
    $script:otherWaitClicks.Add([pscustomobject]@{ T = (Get-VirtualElapsed); X = $ReferenceX; Y = $ReferenceY })
    $sendIndex = $script:otherWaitClicks.Count
    if ($script:otherWaitOnSend.ContainsKey($sendIndex)) {
        foreach ($sendStep in @($script:otherWaitOnSend[$sendIndex])) { Add-OtherWaitPlan -At ((Get-VirtualElapsed) + [double]$sendStep[0]) -Screen ([string]$sendStep[1]) }
    }
}
function Invoke-OtherExitClickStub {
    # 끝 함수 행의 나가기 헬퍼 - 부모 마감까지 남은 초 기록 · 행이 정한 결과(또는 헬퍼 안 exit 센티널)
    param($ParentDeadline)
    $script:otherWaitHelperCalls.Add([string][Math]::Round(([datetime]$ParentDeadline - $script:vclock).TotalSeconds))
    if ($null -ne $script:otherWaitHelperExit) { throw ('__EXIT__' + $script:otherWaitHelperExit) }
    return @{ Result = $script:otherWaitHelperResult; FrozenMs = 0 }
}
function Invoke-OtherReturnStub {
    # 끝 함수 행의 복귀 루프 - 안전 중지 종료 코드 | 열쇠 항목 닫기 사유 기록
    param([int]$SafeStopExitCode, [string]$LeaveEntryReason)
    $script:otherWaitReturnCalls.Add(('{0}|{1}' -f $SafeStopExitCode, $LeaveEntryReason))
}
# 모의 정의 - 원문 param 블록 그대로 + 스텁 몸통 (§3 New-MockDefinition). §7 행이 끝난 뒤라 §3 의 같은 이름 모의·기록 모의를 이 절의 스텁으로 바꿉니다
$OTHER_WAIT_STUB_BODIES = [ordered]@{
    'Find-AbyssRewardButtonPair' = 'return (Invoke-OtherPairStub)'
    'Test-HomeEndEscHud'         = 'return (Invoke-OtherFlagStub -Name ''hud'' -Field ''Hud'')'
    'Test-InDungeonQuest'        = 'return (Invoke-OtherFlagStub -Name ''quest'' -Field ''Quest'')'
    'Test-AbyssSelectionScreen'  = 'return (Invoke-OtherSelectionStub)'
    'Get-AbyssPanelKind'         = 'return (Invoke-OtherPanelStub)'
    'Click-GamePoint'            = 'Invoke-OtherClickStub -ReferenceX $ReferenceX -ReferenceY $ReferenceY'
    'Wait-UserYieldEnd'          = '$yieldTotalBefore = [double]$script:userYieldTotalMs; Invoke-YieldStub -Game $Game -Context $Context; if ($script:otherWaitZeroYield) { $script:userYieldTotalMs = $yieldTotalBefore }'
    'Write-LifeDiagnostics'      = '$script:otherWaitDiagnostics.Add([string]$Context)'
    'Invoke-AbyssExitClick'      = 'return (Invoke-OtherExitClickStub -ParentDeadline $ParentDeadline)'
    'Return-ToAbyssSelection'    = 'Invoke-OtherReturnStub -SafeStopExitCode $SafeStopExitCode -LeaveEntryReason $LeaveEntryReason'
    'Invoke-EventSkipOrConfirm'  = '$script:recordMockCalls[''Invoke-EventSkipOrConfirm''] = 1 + [int]$script:recordMockCalls[''Invoke-EventSkipOrConfirm'']'
}
try {
    foreach ($otherStubEntry in $OTHER_WAIT_STUB_BODIES.GetEnumerator()) { Invoke-Expression (New-MockDefinition -Name $otherStubEntry.Key -Body $otherStubEntry.Value) }
} catch {
    "FAIL 준비: ⑤b3 모의 정의 실패 ($($_.Exception.Message))"
    exit 1
}

function Reset-OtherWaitRow {
    # 행 시작 상태 - §4 의 행 시작(캡처 · 양보 · 스윕 · 실패 창 · 조작 창 · 기록 · 묵은 클릭 메타)을 그대로 쓰고 §9 상태를 비운 뒤 행 명세를 세웁니다
    param([hashtable]$Spec)
    Reset-ReentryRow
    $script:otherWaitPlan = @()
    $script:otherWaitPlanSeq = 0
    foreach ($planStep in @($Spec.Timeline)) { if ($null -ne $planStep) { Add-OtherWaitPlan -At ([double]$planStep[0]) -Screen ([string]$planStep[1]) } }
    # 배열·해시는 $( ) 로 받지 않고 대입으로만 (원소 하나짜리 점 목록이 풀리지 않게 - PS 5.1)
    if ($null -ne $Spec.OnSend) { $script:otherWaitOnSend = $Spec.OnSend } else { $script:otherWaitOnSend = @{} }
    if ($null -ne $Spec.Points) { $script:otherWaitPoints = $Spec.Points } else { $script:otherWaitPoints = $OTHER_WAIT_DEFAULT_POINTS }
    foreach ($failWindow in @($Spec.Fail)) { if ($null -ne $failWindow) { Add-FailWindow ([double]$failWindow[0]) ([double]$failWindow[1]) } }
    if ($null -ne $Spec.FailPeriodic) { Set-FailPeriodic ([double]$Spec.FailPeriodic[0]) ([double]$Spec.FailPeriodic[1]) ([double]$Spec.FailPeriodic[2]) }
    foreach ($activeWindow in @($Spec.Active)) { if ($null -ne $activeWindow) { Add-ActiveWindow ([double]$activeWindow[0]) ([double]$activeWindow[1]) } }
    foreach ($sweepPlan in @($Spec.Sweep)) { if ($null -ne $sweepPlan) { Set-SweepFrom @sweepPlan } }
    $script:otherWaitCursorMisses = [int]$Spec.CursorMisses
    $script:otherWaitReadHook = $Spec.ReadHook
    $script:otherWaitSelectionHook = $Spec.SelectionHook
    $script:otherWaitPanelOverride = $Spec.PanelOverride
    $script:clockHooks = @(@($Spec.TimeHooks) | Where-Object { $null -ne $_ })
    $script:otherWaitZeroYield = [bool]$Spec.ZeroYield
    $script:safeStopFlagMock = [bool]$Spec.F9
    $script:otherWaitClicks = New-Object System.Collections.Generic.List[object]
    $script:otherWaitReads = New-Object System.Collections.Generic.List[object]
    $script:otherWaitDiagnostics = New-Object System.Collections.Generic.List[string]
    $script:otherWaitHelperCalls = New-Object System.Collections.Generic.List[string]
    $script:otherWaitReturnCalls = New-Object System.Collections.Generic.List[string]
    $script:otherWaitClickTries = 0
    $script:otherWaitSelectionTrue = 0
    $script:otherWaitPrevRead = ''
    # 행 훅 상태 (훅이 $script: 로만 읽고 씀)
    $script:otherHookBumped = $false
    $script:otherHookRestoreAt = $null
    $script:otherHookThrown = $false
    $script:otherHookOnce = $false
    $script:otherHookFailAt = $null
    $script:otherHookPairCount = 0
}
function Get-OtherEventCalls {
    # 이벤트 정리 · ESC 기록 모의의 호출 합 (OW18 - $OTHER_EVENT_CALL_NAMES)
    $eventCalls = 0
    foreach ($eventName in $OTHER_EVENT_CALL_NAMES) { $eventCalls += [int]$script:recordMockCalls[$eventName] }
    return $eventCalls
}
function Invoke-OtherWaitRow {
    # 대기 행 실행기 - 결과(반환 하나 · 키 셋이 아니면 'OUT:' · 예외면 'ERR:문구') · 기록을 묶어 돌려줍니다
    param([hashtable]$Spec)
    Reset-OtherWaitRow -Spec $Spec
    $waitOutput = @()
    $waitError = ''
    try { $waitOutput = @(Wait-AbyssOtherSelection -Game $null) } catch { $waitError = [string]$_.Exception.Message }
    $waitResult = ''
    $waitSends = -1
    $waitLast = ''
    if ($waitError) { $waitResult = 'ERR:' + $waitError }
    elseif (($waitOutput.Count -eq 1) -and ($waitOutput[0] -is [hashtable]) -and ((@($waitOutput[0].Keys | ForEach-Object { [string]$_ } | Sort-Object) -join ',') -ceq 'LastKind,Result,Sends')) {
        $waitResult = [string]$waitOutput[0]['Result']
        $waitSends = [int]$waitOutput[0]['Sends']
        $waitLast = [string]$waitOutput[0]['LastKind']
    } else { $waitResult = 'OUT:' + $waitOutput.Count }
    return [pscustomobject]@{
        Result = $waitResult; Sends = $waitSends; LastKind = $waitLast; T = (Get-VirtualElapsed); Clicks = $script:otherWaitClicks.ToArray()
        Yields = $script:yieldCalls; Unproven = @($script:rowLogs | Where-Object { $_.Contains('출처 없음') }).Count; Probes = $script:probeCalls; Safe = $script:safeStopCalls
        PairTimes = @($script:otherWaitReads | Where-Object { $_.Name -eq 'pair' } | ForEach-Object { [double]$_.T }); SelectionTrue = $script:otherWaitSelectionTrue
        FailAt = $script:otherHookFailAt; ClickTries = $script:otherWaitClickTries; EventCalls = (Get-OtherEventCalls)
        PairNotices = @($script:rowLogs | Where-Object { $_.StartsWith($OTHER_PAIR_NOTICE_PREFIX, [StringComparison]::Ordinal) }).Count
    }
}
function Get-OtherWaitFirstClick { param($Row) if (@($Row.Clicks).Count -lt 1) { return [double]-1 }; return [double]@($Row.Clicks)[0].T }
function Get-OtherWaitPairGap {
    # 첫 미검출 짝 판독(시각 ≥ MissAt 의 첫 짝 판독)과 그다음 짝 판독 사이 (짝 재판독 1초 - 범위 ⑤-23 · 설계 v11 R6 2.5)
    param($Row, [double]$MissAt)
    $pairTimes = @($Row.PairTimes)
    for ($pairIndex = 0; $pairIndex -lt ($pairTimes.Count - 1); $pairIndex++) { if ($pairTimes[$pairIndex] -ge $MissAt) { return ($pairTimes[$pairIndex + 1] - $pairTimes[$pairIndex]) } }
    return [double]-1
}
function Format-OtherWaitRow {
    param($Row)
    $clickText = (@($Row.Clicks | ForEach-Object { '{0}@{1},{2}' -f (Format-Seconds $_.T), $_.X, $_.Y }) -join ' ')
    return ('결과={0} 전송={1} 마지막={2} T={3} 클릭=[{4}] 양보={5} 출처 없음 안내={6} 탐침={7} 안전 확인={8} 선택 양성 판독={9} 짝 판독=[{10}] 클릭 시도={11} 짝 없음 안내={12} 이벤트 정리·ESC={13}' -f
        $Row.Result, $Row.Sends, $Row.LastKind, (Format-Seconds $Row.T), $clickText, $Row.Yields, $Row.Unproven, $Row.Probes, $Row.Safe, $Row.SelectionTrue,
        ((@($Row.PairTimes | Select-Object -First 12 | ForEach-Object { Format-Seconds $_ })) -join ' '), $Row.ClickTries, $Row.PairNotices, $Row.EventCalls)
}

# 행 훅 (스크립트 범위 - $script: · 리터럴 · 스크립트 상수만 읽음)
$OTHER_HOOK_SELECTION_DELAY = { if (($script:otherWaitClicks.Count -ge 1) -and (@('hud', 'quest') -notcontains $script:otherWaitPrevRead)) { Step-VirtualClock $OW19_DELAY_SECONDS } }   # 확인 창 판독 지연(바깥 회전 판독은 그대로)
$OTHER_HOOK_PAIR_FAIL_ONCE_AFTER_SEND = { param($Name) if (($Name -eq 'pair') -and ($script:otherWaitClicks.Count -ge 1) -and (-not $script:otherHookThrown)) { $script:otherHookThrown = $true; $script:otherHookFailAt = Get-VirtualElapsed; 'fail' } }

# ── §9 행 - 대기 66 (명세 3.1: OW · PM · WA-S · SW · OS). 시각표 'X@a' = (a, 'X') · 전송 뒤 전이 OnSend = @{ 전송 번호 = (전송 뒤 초, 약어) … } ──
$OTHER_WAIT_ROWS = [ordered]@{
    # 출처 · 확인 창
    'OW1'    = @{ Desc = 'R@0 · 전송 뒤 3초 S → confirmed · 전송 1 · 양보 0'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) } }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ($Row.Yields -eq 0) } }
    'OW2'    = @{ Desc = '확인 창 안 조작 [0.3, 2.5) → 게이트 밖이라 양보 0 · confirmed'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; Active = @(,@(0.3, 2.5)) }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Yields -eq 0) } }
    'OW3'    = @{ Desc = '발급 뒤 확인 창 안 캡처 실패 [2.2, 5.2) → 동결이 출처 폐기 → 전송 뒤 6초 S 는 출처 없음 · unconfirmed · 안내 1 · 전송 1'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(6, 'S')) }; Fail = @(,@(2.2, 5.2)) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Unproven -eq 1) -and ($Row.Sends -eq 1) } }
    'OW4'    = @{ Desc = '확인 창 판독 같은 호출 안 일련번호 +1(판독 직전 값 기준) → confirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }
            SelectionHook = { if (($script:otherWaitClicks.Count -ge 1) -and (-not $script:otherHookBumped) -and ((Get-VirtualElapsed) -ge 3.0) -and (@('hud', 'quest') -notcontains $script:otherWaitPrevRead)) { $script:otherHookBumped = $true; $script:captureFailSerial++ } } }
        Expect = { param($Row) $Row.Result -ceq 'confirmed' } }
    'OW5'    = @{ Desc = '확인 창 음성 뒤 바깥 비선택(U) → 출처 폐기 · 전송 뒤 9.5초 S 는 unconfirmed'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(9.5, 'S')) } }
        Expect = { param($Row) $Row.Result -ceq 'unconfirmed' } }
    'OW5c'   = @{ Desc = '(OW5′) 확인 창 1~5회 음성 → 6회째 S → confirmed · 확인 창 안(전송 + 8.6 전 · 전송 뒤 바깥 회전 짝 판독 0)'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(7.4, 'S')) } }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ($Row.T -lt 8.6) -and (@($Row.PairTimes).Count -eq 1) } }
    'OW5b'   = @{ Desc = '(OW5″) 확인 창이 끝난 바로 뒤 바깥 회전의 S → 출처 유효 · confirmed'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'S')) } }
        Expect = { param($Row) $Row.Result -ceq 'confirmed' } }
    'OW6'    = @{ Desc = '확인 창 끝 무렵 조작 [8.45, 10) → 바깥 게이트 양보가 출처 폐기 · unconfirmed · 양보 ≥ 1'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(9.5, 'S')) }; Active = @(,@(8.45, 10.0)) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Yields -ge 1) } }
    'OW6b'   = @{ Desc = '(OW6′) 같은 조작이 0ms 양보(누적 차분 0) → 게이트의 명시 폐기만이 거부 · unconfirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(9.5, 'S')) }; Active = @(,@(8.45, 10.0)); ZeroYield = $true }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Yields -ge 1) } }
    'OW19'   = @{ Desc = '확인 창 판독 지연(끝 = 전송 + L + 0.5) · 전송 + L + 0.52 의 S → 마감 경계 회전의 성공 먼저 · confirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(($OTHER_WAIT_LIMIT + 0.52), 'S')) }; SelectionHook = $OTHER_HOOK_SELECTION_DELAY }
        Expect = { param($Row) $Row.Result -ceq 'confirmed' } }
    'OW25'   = @{ Desc = '확인 창 첫 판독 직전 양보 누적 +100ms(게이트 밖 양보) → 출처 거부 · unconfirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'S')) }
            SelectionHook = { if (($script:otherWaitClicks.Count -ge 1) -and (-not $script:otherHookBumped)) { $script:otherHookBumped = $true; $script:userYieldTotalMs = [double]$script:userYieldTotalMs + 100 } } }
        Expect = { param($Row) $Row.Result -ceq 'unconfirmed' } }
    'OW28'   = @{ Desc = '확인 창 안 일련번호 +1 → 판독 중 되돌림 → 확인 창 출처 거짓의 명시 폐기가 뒤 회전의 선택 화면을 거부 · unconfirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3.0, 'S')) }
            TimeHooks = @({ if (($script:otherWaitClicks.Count -ge 1) -and (-not $script:otherHookBumped) -and ((Get-VirtualElapsed) -ge 3.1)) { $script:otherHookBumped = $true; $script:captureFailSerial++; $script:otherHookRestoreAt = (Get-VirtualElapsed) + 0.02 }
                    elseif (($null -ne $script:otherHookRestoreAt) -and ((Get-VirtualElapsed) -ge $script:otherHookRestoreAt)) { $script:captureFailSerial--; $script:otherHookRestoreAt = $null } }) }
        Expect = { param($Row) $Row.Result -ceq 'unconfirmed' } }
    # 재클릭 · 짝
    'OW7'    = @{ Desc = '첫 전송 뒤 R 그대로 → 확인 창 뒤 재클릭 1 → 둘째 전송 뒤 S · confirmed · 전송 2 · 전송 간격 ≥ 확인 창 8초'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 2 = @(,@(3, 'S')) } }
        Expect = { param($Row) $sendTimes = @($Row.Clicks | ForEach-Object { [double]$_.T }); ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 2) -and ($sendTimes.Count -eq 2) -and (($sendTimes[1] - $sendTimes[0]) -ge 8) } }
    'OW8'    = @{ Desc = 'R 지속 → 재클릭 상한 → reward · 전송 2'; Spec = @{ Timeline = @(,@(0, 'R')) }
        Expect = { param($Row) ($Row.Result -ceq 'reward') -and ($Row.Sends -eq 2) } }
    'OW9'    = @{ Desc = 'Rn@0 · R@0.4 → 첫 미검출 뒤 짝 재판독 ≥ 1초 → confirmed · 전송 1'; Spec = @{ Timeline = @(@(0, 'Rn'), @(0.4, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) } }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ((Get-OtherWaitPairGap $Row 0) -ge 1.0) } }
    'OW10'   = @{ Desc = 'Rn 지속 → 짝 없음 2회 → no-pair · 전송 0 · 클릭 0 · 짝 없음 안내 1(첫 회만)'; Spec = @{ Timeline = @(,@(0, 'Rn')) }
        Expect = { param($Row) ($Row.Result -ceq 'no-pair') -and ($Row.Sends -eq 0) -and (@($Row.Clicks).Count -eq 0) -and ($Row.PairNotices -eq 1) } }
    'OW11'   = @{ Desc = 'Rn@0 · R@3 · 캡처 실패 [0.5, 2.9) → 실패 회전은 짝 재판독에 미산입 → confirmed · 전송 1'
        Spec = @{ Timeline = @(@(0, 'Rn'), @(3, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; Fail = @(,@(0.5, 2.9)) }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) } }
    'PM1'    = @{ Desc = 'Rn · U · Rn · R → 다른 유효 분류가 짝 없음 셈을 비움 → confirmed · 전송 1 · 짝 없음 안내 2(비운 뒤 다시 첫 회)'
        Spec = @{ Timeline = @(@(0, 'Rn'), @(0.5, 'U'), @(2.0, 'Rn'), @(3.0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) } }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ($Row.PairNotices -eq 2) } }
    'OW23'   = @{ Desc = 'RS(3버튼 + 선택 화면 플레이크) 지속 → 클릭 0 · unconfirmed'; Spec = @{ Timeline = @(,@(0, 'RS')) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and (@($Row.Clicks).Count -eq 0) } }
    'OW24'   = @{ Desc = 'Rx(점 있음 · 서명 거짓)@0 · R@2 → 서명 거짓 회전 클릭 0 · 첫 클릭 ≥ 2 · confirmed'; Spec = @{ Timeline = @(@(0, 'Rx'), @(2, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) } }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ((Get-OtherWaitFirstClick $Row) -ge 2) } }
    'OW26'   = @{ Desc = '재클릭이 마감을 다시 셈 → 둘째 전송 + L 에 unconfirmed · 전송 2'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(9.9, 'R')); 2 = @(,@(0.01, 'U')) } }
        Expect = { param($Row) $sendTimes = @($Row.Clicks | ForEach-Object { [double]$_.T }); ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 2) -and ($sendTimes.Count -eq 2) -and ($Row.T -ge ($sendTimes[1] + $OTHER_WAIT_LIMIT)) -and ($Row.T -lt ($sendTimes[1] + $OTHER_WAIT_LIMIT + 1.5)) } }
    # 규칙 4
    'OW12'   = @{ Desc = '조작 [0.2, 4) 중 클릭 생략 → 양보 뒤 새 판독의 옮긴 점(781,657)으로 전송 · confirmed · 양보 ≥ 1'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; Active = @(,@(0.2, 4)); Points = @(@(0, 778, 654), @(3.5, 781, 657)) }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and (@($Row.Clicks).Count -eq 1) -and (@($Row.Clicks)[0].X -eq 781) -and (@($Row.Clicks)[0].Y -eq 657) -and ($Row.Yields -ge 1) } }
    'OW12b'  = @{ Desc = '(OW12′) 생략 회전은 발급 0 → 뒤 S 는 출처 없음 · unconfirmed · 전송 0 · 안내 1'; Spec = @{ Timeline = @(@(0, 'R'), @(1.5, 'S')); Active = @(,@(0.18, 3.0)) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 0) -and ($Row.Unproven -eq 1) } }
    'OW12d'  = @{ Desc = "'user-active' 생략 3회는 커서 예산 미소모 → 넷째에 전송 · confirmed · 양보 3"
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; Active = @(@(0.18, 0.3), @(0.48, 0.6), @(0.78, 0.9)) }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ($Row.Yields -eq 3) } }
    'OW12c'  = @{ Desc = "(OW12″ 'unknown') 전송 0 · U 지속 → 진입 + L 에 unconfirmed · 클릭 0"; Spec = @{ Timeline = @(,@(0, 'U')) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 0) -and (@($Row.Clicks).Count -eq 0) -and ($Row.T -ge $OTHER_WAIT_LIMIT) -and ($Row.T -lt ($OTHER_WAIT_LIMIT + 1)) } }
    'OW12cM' = @{ Desc = "(OW12″ 'panel') 전송 0 · M 지속 → 진입 + L 에 unconfirmed · 마지막 panel"; Spec = @{ Timeline = @(,@(0, 'M')) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 0) -and (@($Row.Clicks).Count -eq 0) -and ($Row.LastKind -ceq 'panel') -and ($Row.T -ge $OTHER_WAIT_LIMIT) -and ($Row.T -lt ($OTHER_WAIT_LIMIT + 1)) } }
    'OW12cS' = @{ Desc = "(OW12″ 출처 없는 'selection') 전송 0 · S 지속 → 진입 + L 에 unconfirmed · 안내 1"; Spec = @{ Timeline = @(,@(0, 'S')) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 0) -and (@($Row.Clicks).Count -eq 0) -and ($Row.Unproven -eq 1) -and ($Row.T -ge $OTHER_WAIT_LIMIT) -and ($Row.T -lt ($OTHER_WAIT_LIMIT + 1)) } }
    'OW13'   = @{ Desc = '커서 미확인 3회 → skipped · 전송 0 · 클릭 시도 3(예산 경계 - 명세 1.2 ⑪)'; Spec = @{ Timeline = @(,@(0, 'R')); CursorMisses = 3 }
        Expect = { param($Row) ($Row.Result -ceq 'skipped') -and ($Row.Sends -eq 0) -and ($Row.ClickTries -eq 3) } }
    'OW13b'  = @{ Desc = '(OW13′) 커서 미확인 1회 뒤 S → 발급 0 · unconfirmed · 안내 1'; Spec = @{ Timeline = @(@(0, 'R'), @(0.5, 'S')); CursorMisses = 1 }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 0) -and ($Row.Unproven -eq 1) } }
    # 던전 안 · 패널
    'OW14'   = @{ Desc = '전송 뒤 던전 안 2연속 → inside · 전송 1'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(0.5, 'I')) } }
        Expect = { param($Row) ($Row.Result -ceq 'inside') -and ($Row.Sends -eq 1) } }
    'OW14b'  = @{ Desc = '(OW14′) 전송 0 · 던전 안 2연속 → inside'; Spec = @{ Timeline = @(,@(0, 'I')) }
        Expect = { param($Row) ($Row.Result -ceq 'inside') -and ($Row.Sends -eq 0) } }
    'OW15'   = @{ Desc = '던전 안 1표본 뒤 S → 1표본은 결론 0 · 비선택 폐기 → unconfirmed'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'I'), @(9.2, 'S')) } }
        Expect = { param($Row) $Row.Result -ceq 'unconfirmed' } }
    'OW16'   = @{ Desc = 'I 표본 → 동결 [0.3, 3.0) 은 연속 유지 → 복구 뒤 I → inside'; Spec = @{ Timeline = @(@(0, 'I'), @(5.5, 'U')); Fail = @(,@(0.3, 3.0)) }
        Expect = { param($Row) $Row.Result -ceq 'inside' } }
    'OW17'   = @{ Desc = '전송 뒤 M(패널) → 클릭 0 · 폐기 · unconfirmed · 전송 1'; Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(0.5, 'M')) } }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 1) } }
    'OW18'   = @{ Desc = '출처 없는 S 지속 → 클릭 0 · 이벤트 정리·ESC 호출 0(X·ESC 0 - 설계 v11 R6 OW18 · R6-M20) · 안내 1 · unconfirmed'; Spec = @{ Timeline = @(,@(0, 'S')) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Unproven -eq 1) -and (@($Row.Clicks).Count -eq 0) -and ($Row.EventCalls -eq 0) } }
    'OW27'   = @{ Desc = 'I · 조작 양보 [0.4, 1.5) · I · U → 양보가 연속을 끊어 inside 0 · unconfirmed'; Spec = @{ Timeline = @(@(0, 'I'), @(2.5, 'U')); Active = @(,@(0.4, 1.5)) }
        Expect = { param($Row) $Row.Result -ceq 'unconfirmed' } }
    'OW27s'  = @{ Desc = '(OW27 둘째 변형) I · 스윕 참(counted) · I · U → 스윕 참이 연속을 끊어 inside 0 · unconfirmed'
        Spec = @{ Timeline = @(@(0, 'I'), @(1.5, 'U')); Sweep = @(@{ From = 0.4; Kind = 'sent'; Gap = 0; Count = 1 }) }
        Expect = { param($Row) $Row.Result -ceq 'unconfirmed' } }
    # 마감 · 동결 · catch
    'OW20'   = @{ Desc = '조작 20초 [3, 23) + 캡처 실패 30초 [30, 60) → 마감 = L + 둘 → [L + 49.5, L + 53) 에 unconfirmed'
        Spec = @{ Timeline = @(,@(0, 'U')); Active = @(,@(3, 23)); Fail = @(,@(30, 60)) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.T -ge ($OTHER_WAIT_LIMIT + 49.5)) -and ($Row.T -lt ($OTHER_WAIT_LIMIT + 53)) } }
    'OW21'   = @{ Desc = '캡처 실패 지속 + F9 예약 → 원문 안전 확인의 코드 4 센티널'; Spec = @{ Timeline = @(,@(0, 'U')); Fail = @(,@(0.1, $NEVER_ENDS_SECONDS)); F9 = $true }
        Expect = { param($Row) $Row.Result -ceq 'ERR:__EXIT__4' } }
    'WA-S1'  = @{ Desc = '섞인 실패(5초마다 2초 실패) → 유한 · unconfirmed · T < 100'; Spec = @{ Timeline = @(,@(0, 'U')); FailPeriodic = @(5, 5, 2) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.T -lt 100) } }
    'WA-S2'  = @{ Desc = '교대 실패(판독 늘 실패 · 탐침 늘 성공) → 탐침 복구 뒤 회전이 마감을 봄 · unconfirmed · T < 200'; Spec = @{ Timeline = @(,@(0, 'U')); ReadHook = { param($Name) 'fail' } }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.T -lt 200) } }
    'WA-S3'  = @{ Desc = '같은 회전 복구(짝 판독만 실패) 지속 → 복구 회전이 마감을 봄 · 클릭 0 · unconfirmed · T < 100'
        Spec = @{ Timeline = @(,@(0, 'R')); ReadHook = { param($Name) if ($Name -eq 'pair') { 'fail' } } }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and (@($Row.Clicks).Count -eq 0) -and ($Row.T -lt 100) } }
    'WA-S4'  = @{ Desc = '동결 60초 [0.01, 60) → 동결 중 클릭·확정 0 · 2초 간격 탐침(≤ 32) · 안전 확인 ≥ 1 · 복구 뒤 전송 · confirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; Fail = @(,@(0.01, 60)) }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Probes -ge 1) -and ($Row.Probes -le 32) -and ($Row.Safe -ge 1) -and ((Get-OtherWaitFirstClick $Row) -ge 60) } }
    'WA-S9'  = @{ Desc = '짝과 패널 판독 사이 [0.12, 0.6) 에 패널(matching) → 그 회전 클릭 0 · 첫 클릭 ≥ 0.6 · confirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; PanelOverride = { if (((Get-VirtualElapsed) -ge 0.12) -and ((Get-VirtualElapsed) -lt 0.6)) { 'matching' } } }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ((Get-OtherWaitFirstClick $Row) -ge 0.6) } }
    'WA-S10a' = @{ Desc = '((가)) 패널 판독의 창 좌표 throw(판독 경로 문구 ∧ 플래그 ∧ gameWindowGone) → 받음 → 동결 · 탐침 → 복구 뒤 전송 · confirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; ReadHook = { param($Name) if (($Name -eq 'panel') -and ((Get-VirtualElapsed) -lt 0.5)) { 'rect' } } }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Probes -ge 1) } }
    'WA-S10b' = @{ Desc = '((나)) HUD 판독의 등록 없는 다른 예외 → 밖으로'; Spec = @{ Timeline = @(,@(0, 'R')); ReadHook = { param($Name) if ($Name -eq 'hud') { 'other-throw' } } }
        Expect = { param($Row) $Row.Result -ceq ('ERR:' + $OTHER_WAIT_OTHER_ERROR) } }
    'WA-S10c' = @{ Desc = '((다)) 확인 창 판독의 창 좌표 throw → 확인 창 catch 가 한 줄과 같게 받음 → unconfirmed · 전송 1 · 탐침 ≥ 1'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(2.5, 'S')) }
            ReadHook = { param($Name) if (($Name -eq 'selection') -and ($script:otherWaitClicks.Count -ge 1) -and (-not $script:otherHookThrown)) { $script:otherHookThrown = $true; 'rect' } } }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 1) -and ($Row.Probes -ge 1) } }
    'WA-S10d' = @{ Desc = '((라)) 패널 판독 gameWindowGone 등록 뒤 두 문구가 아닌 예외 → 밖으로'; Spec = @{ Timeline = @(,@(0, 'R')); ReadHook = { param($Name) if ($Name -eq 'panel') { 'rect-other' } } }
        Expect = { param($Row) $Row.Result -ceq ('ERR:' + $OTHER_WAIT_THIRD_ERROR) } }
    'WA-S10e' = @{ Desc = '((마)) 판독 경로 문구지만 원인 other → 밖으로'; Spec = @{ Timeline = @(,@(0, 'R')); ReadHook = { param($Name) if ($Name -eq 'panel') { 'msg-othercause' } } }
        Expect = { param($Row) $Row.Result -ceq ('ERR:' + $READ_PATH_MESSAGE) } }
    # 스윕 갈래 (R5 8.5 WA-S10 의 ④ 스윕 몫 · 범위 ⑤-50 (라) · R6 2.11 ③)
    'SW1'    = @{ Desc = "스윕 참(전송) 지속 → 셋째부터 굶김 회전이 마감을 봄 → [L, L + 3) 에 unconfirmed"; Spec = @{ Timeline = @(,@(0, 'U')); Sweep = @(@{ From = 0; Kind = 'sent'; Gap = 1.0 }) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.T -ge $OTHER_WAIT_LIMIT) -and ($Row.T -lt ($OTHER_WAIT_LIMIT + 3)) } }
    'SW2'    = @{ Desc = '((가)) 스윕 예비 좌표 클릭 경로 문구 ∧ 플래그 ∧ gameWindowGone → 받음 → 동결(안전 확인 · 탐침) → 복구 뒤 새 판독으로 전송 · confirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; Sweep = @(@{ From = 0; Kind = 'rect-click-throw'; Count = 1 }) }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ($Row.Safe -ge 1) -and ($Row.Probes -ge 1) -and ((Get-OtherWaitFirstClick $Row) -ge 2) } }
    'SW5'    = @{ Desc = "((나)) 셋째 문구('X ' + 클릭 경로 문구 - 공통 꼬리를 품음) ∧ 플래그 ∧ gameWindowGone → 밖으로"
        Spec = @{ Timeline = @(,@(0, 'R')); Sweep = @(@{ From = 0; Kind = 'rect-click-throw'; Message = $THIRD_MESSAGE }) }
        Expect = { param($Row) $Row.Result -ceq ('ERR:' + $THIRD_MESSAGE) } }
    'SW3'    = @{ Desc = '((다)) 플래그 거짓의 클릭 경로 문구 → 밖으로'; Spec = @{ Timeline = @(,@(0, 'R')); Sweep = @(@{ From = 0; Kind = 'click-throw-noreg' }) }
        Expect = { param($Row) $Row.Result -ceq ('ERR:' + $CLICK_PATH_MESSAGE) } }
    'SW6a'   = @{ Desc = "((라)) 'gate-true'(실패 등록 · 메타 0 · 참) → 그 회전 클릭 0 → freeze → 동결 → 복구 뒤 전송 · confirmed"
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(3, 'S')) }; Sweep = @(@{ From = 0; Kind = 'gate-true'; Count = 1 }) }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ($Row.Safe -ge 1) -and ($Row.Probes -ge 1) -and ((Get-OtherWaitFirstClick $Row) -ge 4) } }
    'SW6b'   = @{ Desc = "((라)) I · 'gate-true' freeze · I · U → freeze 회전도 던전 안 연속 0 · unconfirmed"
        Spec = @{ Timeline = @(@(0, 'I'), @(5.6, 'U')); Sweep = @(@{ From = 0.4; Kind = 'gate-true'; Count = 1 }) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 0) -and ($Row.Safe -ge 1) } }
    'SW7'    = @{ Desc = "스윕 'recovered' 지속(스윕 안 실패 → 같은 호출 복구 · 커서 미확인) → 복구 회전이 마감을 봄 → [L, L + 3) 에 unconfirmed"
        Spec = @{ Timeline = @(,@(0, 'U')); Sweep = @(@{ From = 0; Kind = 'recover'; Gap = 0.1 }) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 0) -and ($Row.T -ge $OTHER_WAIT_LIMIT) -and ($Row.T -lt ($OTHER_WAIT_LIMIT + 3)) } }
    'SW4'    = @{ Desc = '전송 → 확인 창 음성 → 바깥 회전 스윕 참(전송) → S → 스윕 참 = 출처 폐기 · unconfirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'S')) }; Sweep = @(@{ From = 8.4; Kind = 'sent'; Gap = 1.0; Count = 1 }) }
        Expect = { param($Row) $Row.Result -ceq 'unconfirmed' } }
    # 선택 양성 예외 (명세 리뷰 1 P2 · 설계 v11 R6 2.4 - 같은 판독 단계 안의 같은 회전 실패 허용 · 성공이 마감보다 먼저)
    'OS0'    = @{ Desc = '확인 창 음성 뒤 바깥 회전의 짝 판독만 실패 → 같은 회전 선택 양성 → confirmed(실패 판독 뒤 0.5초 안 · 동결 0 · 안내 0)'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'S')) }; ReadHook = $OTHER_HOOK_PAIR_FAIL_ONCE_AFTER_SEND }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ($Row.Probes -eq 0) -and ($Row.Safe -eq 0) -and ($Row.Unproven -eq 0) -and ($null -ne $Row.FailAt) -and
            (($Row.T - [double]$Row.FailAt) -lt 0.5) -and ($Row.T -lt ((Get-OtherWaitFirstClick $Row) + $OTHER_WAIT_LIMIT)) } }
    'OS1'    = @{ Desc = '(RLP4(b) 와 같은 뜻) OW19 배치 + 마감 경계 회전의 짝 판독 실패 → 선택 양성 · 출처 유효 → confirmed(전송 + L 뒤)'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(($OTHER_WAIT_LIMIT + 0.52), 'S')) }; SelectionHook = $OTHER_HOOK_SELECTION_DELAY; ReadHook = $OTHER_HOOK_PAIR_FAIL_ONCE_AFTER_SEND }
        Expect = { param($Row) ($Row.Result -ceq 'confirmed') -and ($Row.Sends -eq 1) -and ($Row.Probes -eq 0) -and ($null -ne $Row.FailAt) -and (($Row.T - [double]$Row.FailAt) -lt 0.5) -and
            ($Row.T -ge ((Get-OtherWaitFirstClick $Row) + $OTHER_WAIT_LIMIT)) } }
    'OS2'    = @{ Desc = '선택 화면 양성 회전의 패널 판독(회전 마지막) 실패 → 그 회전 확정 0 → 동결(안전 확인 · 탐침) → unconfirmed · 안내 1'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'S')) }
            ReadHook = { param($Name) if (($Name -eq 'panel') -and ($script:otherWaitClicks.Count -ge 1) -and (-not $script:otherHookThrown)) { $script:otherHookThrown = $true; 'fail' } } }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 1) -and ($Row.Safe -ge 1) -and ($Row.Probes -ge 1) -and ($Row.Unproven -eq 1) } }
    'OS3m'   = @{ Desc = "선택 화면 양성 ∧ 패널 종류 matching(분류 순위 1 첫 항) → 확정 0 · 'panel' 폐기 → unconfirmed · 안내 1"
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'S')) }
            PanelOverride = { if (($script:otherWaitClicks.Count -ge 1) -and (-not $script:otherHookOnce)) { $script:otherHookOnce = $true; 'matching' } } }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 1) -and ($Row.Unproven -eq 1) } }
    'OS3e'   = @{ Desc = "SE(하단 접힌 준비 패널 서명 · 선택 화면 양성 - 분류 순위 1 둘째 항) → 확정 0 · 'panel' 폐기 → unconfirmed · 안내 1"
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'SE'), @(8.9, 'S')) } }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 1) -and ($Row.Unproven -eq 1) } }
    'OS4f'   = @{ Desc = '확인 창 안 실패 → 동결 → 탐침 복구 → 선택 화면 회전의 짝 판독 실패(복구 회전) · 출처 거짓 → 확정 0 · 명시 폐기 · 안내 1 · 마지막 selection · [전송 + L, 전송 + 2L)'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(6, 'S')) }; Fail = @(,@(2.2, 5.2))
            ReadHook = { param($Name) if (Test-InFailWindow) { 'fail' } elseif (($Name -eq 'pair') -and ($script:probeCalls -ge 1) -and (-not $script:otherHookThrown)) { $script:otherHookThrown = $true; $script:otherHookFailAt = Get-VirtualElapsed; 'fail' } } }
        Expect = { param($Row) $sendAt = Get-OtherWaitFirstClick $Row; ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 1) -and ($Row.Unproven -eq 1) -and ($Row.LastKind -ceq 'selection') -and ($null -ne $Row.FailAt) -and
            ($Row.T -ge ($sendAt + $OTHER_WAIT_LIMIT)) -and ($Row.T -lt ($sendAt + 2 * $OTHER_WAIT_LIMIT)) } }
    'OS4y'   = @{ Desc = '0ms 양보 → 유효 회전 선택 양성 · 출처 거짓 → 확정 0 · 명시 폐기 · 안내 1 · 마지막 selection · [전송 + L, + 1)'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(9.5, 'S')) }; Active = @(,@(8.45, 10.0)); ZeroYield = $true }
        Expect = { param($Row) $sendAt = Get-OtherWaitFirstClick $Row; ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 1) -and ($Row.Yields -eq 1) -and ($Row.Unproven -eq 1) -and ($Row.LastKind -ceq 'selection') -and
            ($Row.T -ge ($sendAt + $OTHER_WAIT_LIMIT)) -and ($Row.T -lt ($sendAt + $OTHER_WAIT_LIMIT + 1)) } }
    'OS4r'   = @{ Desc = '확인 창 끝 일련번호 +1(등록 없음) → 바깥 회전 선택 양성 · 출처 거짓 → 명시 폐기 → 다음 회전 서두 전 되돌림 → 그 회전 선택 양성이어도 확정 0 · unconfirmed'
        Spec = @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(@(0.01, 'U'), @(8.32, 'S')) }
            TimeHooks = @({ if (($script:otherWaitClicks.Count -ge 1) -and (-not $script:otherHookBumped) -and ((Get-VirtualElapsed) -ge 8.48)) { $script:otherHookBumped = $true; $script:captureFailSerial++; $script:otherHookRestoreAt = (Get-VirtualElapsed) + 0.25 }
                    elseif (($null -ne $script:otherHookRestoreAt) -and ((Get-VirtualElapsed) -ge $script:otherHookRestoreAt)) { $script:captureFailSerial--; $script:otherHookRestoreAt = $null } }) }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 1) -and ($Row.Unproven -eq 1) } }
    'OS5'    = @{ Desc = '출처 없는 S 가 복구 회전(짝 판독 실패)과 유효 회전에 번갈아 → 안내 1 · 확정 0 · 선택 양성 판독 ≥ 4 · [L, L + 3) 에 unconfirmed'
        Spec = @{ Timeline = @(,@(0, 'S')); ReadHook = { param($Name) if ($Name -eq 'pair') { $script:otherHookPairCount++; if (($script:otherHookPairCount % 2) -eq 1) { 'fail' } } } }
        Expect = { param($Row) ($Row.Result -ceq 'unconfirmed') -and ($Row.Sends -eq 0) -and ($Row.Unproven -eq 1) -and ($Row.SelectionTrue -ge 4) -and ($Row.T -ge $OTHER_WAIT_LIMIT) -and ($Row.T -lt ($OTHER_WAIT_LIMIT + 3)) } }
}
"INFO ⑤b3: L ${OTHER_WAIT_LIMIT}초(행 설계 범위 [${OTHER_WAIT_LIMIT_MIN}, ${OTHER_WAIT_LIMIT_MAX}]) · 헬퍼 부모 예산 ${OTHER_HELPER_BUDGET}초 · 확인 창 판독 지연(OW19 · OS1) $(Format-Seconds $OW19_DELAY_SECONDS)초 · 대기 행 $($OTHER_WAIT_ROWS.Count)"
foreach ($otherRowName in $OTHER_WAIT_ROWS.Keys) {
    $otherRowEntry = $OTHER_WAIT_ROWS[$otherRowName]
    $otherRow = Invoke-OtherWaitRow -Spec $otherRowEntry.Spec
    $otherRowOk = $false
    try { $otherRowOk = [bool](& $otherRowEntry.Expect $otherRow) } catch { $otherRowOk = $false }
    Check-True ('{0} {1}' -f $otherRowName, $otherRowEntry.Desc) $otherRowOk (Format-OtherWaitRow $otherRow)
}

# ── §9 행 - 끝 33 (FB · SS 의 워커 쪽 - 대기는 결과 스텁(끝의 SS3-real · SS3-real-win 만 원문 대기) · 헬퍼 · 복귀 루프 · 진단은 기록 스텁 · 안전 중지 파일은 §4 모의) ──
Invoke-Expression $otherFinishDefinition
Invoke-Expression (New-MockDefinition -Name 'Wait-AbyssOtherSelection' -Body '$script:otherWaitStubCalls++; if ($script:otherWaitFlagDuringWait) { $script:safeStopFlagMock = $true }; return $script:otherWaitStubResult')
$otherSignatureNames = @(@($OTHER_WAIT_STUB_BODIES.Keys) + @('Wait-AbyssOtherSelection', 'Get-ConfigInteger'))
$otherSignatureMismatches = @($otherSignatureNames | Where-Object { (Get-LiveParamSignature $_) -cne (Get-ParamSignature $_) } | ForEach-Object { '{0}: 원문 [{1}] / 모의 [{2}]' -f $_, (Get-ParamSignature $_), (Get-LiveParamSignature $_) })
if ($otherSignatureMismatches.Count -gt 0) { "FAIL 준비: ⑤b3 모의 서명이 워커 원문과 다릅니다 ($($otherSignatureMismatches -join ' · '))"; exit 1 }
# 끝맺음 생략 표지 (구현 리뷰 B P2) - 행의 끝맺음 열이 이 값이면 실행기가 원문 끝 함수를 -Ending 없이 불러 원문 기본값을 탑니다(행 FB-ending-default)
$OTHER_ENDING_OMITTED = '(생략 - 원문 기본값)'
function Invoke-OtherFinishRow {
    # 끝 함수 행 실행기 - exit 센티널 · 헬퍼 부모 마감(남은 초) · 복귀 루프(종료 코드|닫기 사유) · 예약 소비 수 · 진단 수 · 대기 호출 수 · 마지막 로그
    param([hashtable]$Wait, [string]$Ending = 'ready', [bool]$Flag = $false, [bool]$FlagDuringWait = $false, [string]$HelperResult = 'clicked', $HelperExit = $null)
    Reset-OtherWaitRow -Spec @{}
    $script:safeStopFlagMock = $Flag
    $script:otherWaitFlagDuringWait = $FlagDuringWait
    $script:otherWaitStubCalls = 0
    $script:otherWaitStubResult = $Wait
    $script:otherWaitHelperResult = $HelperResult
    $script:otherWaitHelperExit = $HelperExit
    $finishError = ''
    try {
        # 생략 표지면 -Ending 을 넘기지 않습니다(원문 기본값 - 구현 리뷰 B P2). 그 밖은 그 값을 그대로 넘깁니다(집합 밖 값은 매개변수 검증 오류 - FB-ending-typo)
        if ($Ending -ceq $OTHER_ENDING_OMITTED) { $null = Complete-AbyssOtherSelection -Game $null }
        else { $null = Complete-AbyssOtherSelection -Game $null -Ending $Ending }
    } catch { $finishError = [string]$_.Exception.Message }
    $lastLog = $(if ($script:rowLogs.Count -gt 0) { [string]$script:rowLogs[$script:rowLogs.Count - 1] } else { '' })
    return [pscustomobject]@{ Exit = $finishError; Helper = ($script:otherWaitHelperCalls -join ','); Return = ($script:otherWaitReturnCalls -join ','); Removed = $script:safeStopRemoves
        Diags = $script:otherWaitDiagnostics.Count; WaitCalls = $script:otherWaitStubCalls; Last = $lastLog
        Fallback = (@($script:rowLogs | Where-Object { $_.StartsWith('[어비스] ', [StringComparison]::Ordinal) }) -join ' || ') }
}
# 기대 문구 - 구현 명세 ⑤b3 1.3 의 글자 (두 '[완료]' 는 지금 문구 그대로 - wt″:14794 · 20608)
$OTHER_DONE_READY = '[완료] 어비스 선택 화면 복귀 완료'
$OTHER_DONE_SAFE_STOP = '[완료] 안전 중지 예약 확인 - 선택 화면 복귀 완료 시점에서 회차를 마칩니다'
$OTHER_DONE_CANCELLED = "[완료] 재매칭이 취소돼 '다시 하기'를 다시 누르지 않고 어비스 선택 화면에서 멈춥니다"
$OTHER_DONE_INSIDE_SENT = "[완료] '다른 던전 가기' 뒤 던전 안이 확인됐습니다 - '다시 하기' 오클릭이 의심돼 정지합니다 (새 판은 입장 직후 키 없이 시작됐을 수 있습니다). 화면을 확인해 주세요"
$OTHER_DONE_INSIDE_NOSEND = "[완료] '다른 던전 가기' 를 누르기 전에 던전 안이 확인돼 정지합니다 (누르지 않음 - 새 판은 입장 직후 키 없이 시작됐을 수 있습니다). 화면을 확인해 주세요"
# 'unconfirmed' 두 문구(구현 명세 ⑤b5 W6 · 1.4 - ⑤b3 C-3 · ⑤b4 리뷰 2 확인의 넘김): 전송 ≥ 1 은 끝에 오버레이 안내(관측 0 O-4 - 워커가 연 선택 화면은 보상 화면 위
#   오버레이라 X·ESC 로 닫으면 보상 화면) · 전송 0 은 '다시 하기' 전송 0 문구($RETRY_DONE_UNCONFIRMED_NOSEND)와 같은 짜임(옛 '보상 화면이 아닌 화면이 이어져' 는
#   마감 회전이 보상 화면이면 사실과 어긋남 - 5b-4 의 같은 정정)
$OTHER_DONE_UNCONFIRMED_SENT = "[완료] '다른 던전 가기' 뒤 워커가 연 것으로 확인되는 어비스 선택 화면을 보지 못해 멈춥니다 (누르지 않음). 화면을 확인하고 다시 시작해 주세요 - 어비스 선택 화면이 열려 있으면 닫지 말고 그대로 시작해 주세요 (닫으면 보상 화면으로 돌아갑니다)"
$OTHER_DONE_UNCONFIRMED_NOSEND = "[완료] '다른 던전 가기' 를 누르려 했지만 이번 클릭을 보내지 못한 채 확인 대기 시간이 지나 멈춥니다 (누르지 않음). 화면을 확인하고 다시 시작해 주세요"
$OTHER_FALLBACK_NOPAIR = "[어비스] '다른 던전 가기' 글자를 찾지 못해 보상 화면 '나가기' 로 선택 화면에 돌아갑니다"
$OTHER_FALLBACK_REWARD = "[어비스] 누른 뒤에도 보상 화면이 그대로라 보상 화면 '나가기' 로 선택 화면에 돌아갑니다"
$OTHER_FALLBACK_SKIPPED = "[어비스] 커서 미확인으로 누르지 못해 보상 화면 '나가기' 로 선택 화면에 돌아갑니다"
$OTHER_FALLBACK_LINES = @{ 'no-pair' = $OTHER_FALLBACK_NOPAIR; 'reward' = $OTHER_FALLBACK_REWARD; 'skipped' = $OTHER_FALLBACK_SKIPPED }   # 폴백 ② 진입 줄 - 대기 결과별 사유(명세 1.3 B-8)
# 두 '[완료]' 기대 문구는 지금 문구 그대로라(명세 1.3 · 설계 v11 R6 5.1) 끝 함수 밖(복귀 루프 · 본류 끝 줄)에도 같은 글자 상수가 있어야 합니다 - 어긋나면 여기서 멈춥니다
$otherSharedDoneConstants = @($workerAst.FindAll({ param($candidate) ($candidate -is [StringConstantExpressionAst]) -and ([string]$candidate.Value).StartsWith('[완료] ', [StringComparison]::Ordinal) }, $true))
foreach ($sharedDoneText in @($OTHER_DONE_READY, $OTHER_DONE_SAFE_STOP)) {
    $sharedDoneOutside = @($otherSharedDoneConstants | Where-Object { ([string]$_.Value -ceq $sharedDoneText) -and (-not (Test-AstWithin -Node $_ -Ancestor $otherFinishNode)) }).Count
    if ($sharedDoneOutside -lt 1) { "FAIL 준비: 기대 문구 '$sharedDoneText' 가 끝 함수 밖(복귀 루프 · 본류 끝 줄)에 없습니다 - 끝 함수의 두 '[완료]' 는 지금 문구 그대로여야 합니다 (구현 명세 ⑤b3 1.3)"; exit 1 }
}
# 열: 이름 · 설명 · 대기 결과 · 끝맺음(생략 표지면 -Ending 없이 부름) · 예약(앞) · 예약(대기 안) · 헬퍼 결과 · 헬퍼 안 exit · 기대(헬퍼를 부른 행 = exit|부모 마감|복귀 루프|소비|
#   진단|마지막 줄 · 부르지 않은 행 = exit|복귀 루프|소비|진단|마지막 줄). 대기 결과가 폴백 ② 셋('no-pair' · 'reward' · 'skipped')인 행은 끝에 '|폴백 줄=' + 그 행의
#   '[어비스]' 줄(하나)을 더해 사유 글자까지 대조합니다. 끝 다섯 행(구현 리뷰 B P2): 정지 끝 B(rematch-cancelled) × 'inside' / 'unconfirmed' × 전송 1 / 0 은 명세 1.3 표
#   'B 도 같음' 이라 기대가 같은 대기 결과의 ready 행(FB8 · FB8′ · SS3 · FB9)과 같은 글자이고 예약을 둬 소비 0 을 봅니다 · FB-ending-default 는 -Ending 을 생략해
#   원문 기본값이 ReadySelection 인지 봅니다(기대 = SS1 과 같은 글자 - 예약이 있어야 ready 와 B 가 소비 · 문구 · 코드로 갈림)
$OTHER_FINISH_ROWS = @(
    @('FB-confirmed', "(기본) 'confirmed' · ready · 예약 없음 → 복귀 완료 · 코드 0", @{ Result = 'confirmed'; Sends = 1 }, 'ready', $false, $false, 'clicked', $null, ("__EXIT__0||0|0|$OTHER_DONE_READY")),
    @('SS1', "'confirmed' · ready · 예약 → 소비 1 · 안전 중지 문구 · 코드 0", @{ Result = 'confirmed'; Sends = 1 }, 'ready', $true, $false, 'clicked', $null, ("__EXIT__0||1|0|$OTHER_DONE_SAFE_STOP")),
    @('SS2', "예약이 대기 중(확인 전)에 생김 → 'confirmed' 뒤 소비 1 · 코드 0", @{ Result = 'confirmed'; Sends = 2 }, 'ready', $false, $true, 'clicked', $null, ("__EXIT__0||1|0|$OTHER_DONE_SAFE_STOP")),
    @('SS3', "'unconfirmed' · 예약 → 소비 0 · 진단 1 · 코드 4", @{ Result = 'unconfirmed'; Sends = 1 }, 'ready', $true, $false, 'clicked', $null, ("__EXIT__4||0|1|$OTHER_DONE_UNCONFIRMED_SENT")),
    @('SS4', "'no-pair' · ready · 예약 → 끝 함수 소비 0 · 헬퍼 → 복귀 루프(코드 0) · 코드 0", @{ Result = 'no-pair'; Sends = 0 }, 'ready', $true, $false, 'clicked', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB8', "'inside' · 전송 1 → 진단 1 · 오클릭 의심 문구 · 코드 4", @{ Result = 'inside'; Sends = 1 }, 'ready', $false, $false, 'clicked', $null, ("__EXIT__4||0|1|$OTHER_DONE_INSIDE_SENT")),
    @('FB8′', "'inside' · 전송 0 → 진단 1 · 누르기 전 문구 · 코드 4", @{ Result = 'inside'; Sends = 0 }, 'ready', $false, $false, 'clicked', $null, ("__EXIT__4||0|1|$OTHER_DONE_INSIDE_NOSEND")),
    @('FB9', "'unconfirmed' · 전송 0 → 진단 1 · 누르지 못한 문구 · 코드 4", @{ Result = 'unconfirmed'; Sends = 0 }, 'ready', $false, $false, 'clicked', $null, ("__EXIT__4||0|1|$OTHER_DONE_UNCONFIRMED_NOSEND")),
    @('FB1', "'no-pair' · 헬퍼 'clicked' → 복귀 루프(코드 0 · 닫기 사유 빈 값) · 코드 0", @{ Result = 'no-pair'; Sends = 0 }, 'ready', $false, $false, 'clicked', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB2', "'reward' · 헬퍼 'gone' → 복귀 루프 · 코드 0", @{ Result = 'reward'; Sends = 2 }, 'ready', $false, $false, 'gone', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB4', "'reward' · 헬퍼 'matching' → 복귀 루프 · 코드 0", @{ Result = 'reward'; Sends = 2 }, 'ready', $false, $false, 'matching', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB5', "'no-pair' · 헬퍼 'selection' → 복귀 루프 · 코드 0", @{ Result = 'no-pair'; Sends = 0 }, 'ready', $false, $false, 'selection', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB6', "'reward' · 헬퍼 'expired' → 복귀 루프 · 코드 0", @{ Result = 'reward'; Sends = 2 }, 'ready', $false, $false, 'expired', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB7', "'no-pair' · 헬퍼 안 exit 4 → 그대로(복귀 루프 0)", @{ Result = 'no-pair'; Sends = 0 }, 'ready', $false, $false, 'clicked', 4, ("__EXIT__4|$OTHER_HELPER_BUDGET||0|0|$OTHER_FALLBACK_NOPAIR")),
    @('FB15', "'no-pair' · 헬퍼 'skipped' → 복귀 루프 · 코드 0", @{ Result = 'no-pair'; Sends = 0 }, 'ready', $false, $false, 'skipped', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB15w', "대기 'skipped' → 폴백 ②(헬퍼 → 복귀 루프) · 코드 0", @{ Result = 'skipped'; Sends = 0 }, 'ready', $false, $false, 'clicked', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB17a', "'reward' · 헬퍼 'ready-panel' → 복귀 루프 · 코드 0", @{ Result = 'reward'; Sends = 2 }, 'ready', $false, $false, 'ready-panel', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB17b', "'no-pair' · 헬퍼 'entry-waiting' → 복귀 루프 · 코드 0", @{ Result = 'no-pair'; Sends = 0 }, 'ready', $false, $false, 'entry-waiting', $null, ("__EXIT__0|$OTHER_HELPER_BUDGET|0||0|0|$OTHER_DONE_READY")),
    @('FB10', "rematch-cancelled · 'confirmed' → 재매칭 취소 문구 · 코드 4", @{ Result = 'confirmed'; Sends = 1 }, 'rematch-cancelled', $false, $false, 'clicked', $null, ("__EXIT__4||0|0|$OTHER_DONE_CANCELLED")),
    @('FB10′', "rematch-cancelled · 'confirmed' · 예약 → 소비 0 · 코드 4", @{ Result = 'confirmed'; Sends = 1 }, 'rematch-cancelled', $true, $false, 'clicked', $null, ("__EXIT__4||0|0|$OTHER_DONE_CANCELLED")),
    @('FB11', "rematch-cancelled · 'no-pair' · 헬퍼 'clicked' → 복귀 루프(코드 4) → 재매칭 취소 문구 · 코드 4", @{ Result = 'no-pair'; Sends = 0 }, 'rematch-cancelled', $false, $false, 'clicked', $null, ("__EXIT__4|$OTHER_HELPER_BUDGET|4||0|0|$OTHER_DONE_CANCELLED")),
    @('FB19a', "rematch-cancelled · 헬퍼 'selection' → 복귀 루프(코드 4) · 코드 4", @{ Result = 'no-pair'; Sends = 0 }, 'rematch-cancelled', $false, $false, 'selection', $null, ("__EXIT__4|$OTHER_HELPER_BUDGET|4||0|0|$OTHER_DONE_CANCELLED")),
    @('FB19b', "rematch-cancelled · 헬퍼 'expired' → 복귀 루프(코드 4) · 코드 4", @{ Result = 'reward'; Sends = 2 }, 'rematch-cancelled', $false, $false, 'expired', $null, ("__EXIT__4|$OTHER_HELPER_BUDGET|4||0|0|$OTHER_DONE_CANCELLED")),
    @('FB19c', "rematch-cancelled · 대기 'skipped' · 헬퍼 'skipped' → 복귀 루프(코드 4) · 코드 4", @{ Result = 'skipped'; Sends = 0 }, 'rematch-cancelled', $false, $false, 'skipped', $null, ("__EXIT__4|$OTHER_HELPER_BUDGET|4||0|0|$OTHER_DONE_CANCELLED")),
    @('FB19d', "rematch-cancelled · 대기 'skipped' · 헬퍼 'gone' → 복귀 루프(코드 4) · 코드 4", @{ Result = 'skipped'; Sends = 0 }, 'rematch-cancelled', $false, $false, 'gone', $null, ("__EXIT__4|$OTHER_HELPER_BUDGET|4||0|0|$OTHER_DONE_CANCELLED")),
    @('FB-B-inside-sent', "rematch-cancelled · 'inside' · 전송 1 · 예약 → ready 와 같음(진단 1 · 오클릭 의심 문구 · 소비 0 · 코드 4)", @{ Result = 'inside'; Sends = 1 }, 'rematch-cancelled', $true, $false, 'clicked', $null, ("__EXIT__4||0|1|$OTHER_DONE_INSIDE_SENT")),
    @('FB-B-inside-nosend', "rematch-cancelled · 'inside' · 전송 0 · 예약 → ready 와 같음(진단 1 · 누르기 전 문구 · 소비 0 · 코드 4)", @{ Result = 'inside'; Sends = 0 }, 'rematch-cancelled', $true, $false, 'clicked', $null, ("__EXIT__4||0|1|$OTHER_DONE_INSIDE_NOSEND")),
    @('FB-B-unconfirmed-sent', "rematch-cancelled · 'unconfirmed' · 전송 1 · 예약 → ready 와 같음(진단 1 · 전송 뒤 미확인 문구 · 소비 0 · 코드 4)", @{ Result = 'unconfirmed'; Sends = 1 }, 'rematch-cancelled', $true, $false, 'clicked', $null, ("__EXIT__4||0|1|$OTHER_DONE_UNCONFIRMED_SENT")),
    @('FB-B-unconfirmed-nosend', "rematch-cancelled · 'unconfirmed' · 전송 0 · 예약 → ready 와 같음(진단 1 · 누르지 못한 문구 · 소비 0 · 코드 4)", @{ Result = 'unconfirmed'; Sends = 0 }, 'rematch-cancelled', $true, $false, 'clicked', $null, ("__EXIT__4||0|1|$OTHER_DONE_UNCONFIRMED_NOSEND")),
    @('FB-ending-default', "-Ending 생략(원문 기본값) · 'confirmed' · 예약 → ready 와 같음(소비 1 · 안전 중지 문구 · 코드 0)", @{ Result = 'confirmed'; Sends = 1 }, $OTHER_ENDING_OMITTED, $true, $false, 'clicked', $null, ("__EXIT__0||1|0|$OTHER_DONE_SAFE_STOP")))
foreach ($otherFinishRow in $OTHER_FINISH_ROWS) {
    $finishOutcome = Invoke-OtherFinishRow -Wait $otherFinishRow[2] -Ending $otherFinishRow[3] -Flag $otherFinishRow[4] -FlagDuringWait $otherFinishRow[5] -HelperResult $otherFinishRow[6] -HelperExit $otherFinishRow[7]
    $finishActual = $(if ($finishOutcome.Helper -eq '') { '{0}|{1}|{2}|{3}|{4}' -f $finishOutcome.Exit, $finishOutcome.Return, $finishOutcome.Removed, $finishOutcome.Diags, $finishOutcome.Last }
        else { '{0}|{1}|{2}|{3}|{4}|{5}' -f $finishOutcome.Exit, $finishOutcome.Helper, $finishOutcome.Return, $finishOutcome.Removed, $finishOutcome.Diags, $finishOutcome.Last })
    $finishExpected = [string]$otherFinishRow[8]
    $fallbackWant = $OTHER_FALLBACK_LINES[[string]$otherFinishRow[2].Result]
    if ($null -ne $fallbackWant) { $finishActual += ('|폴백 줄=' + $finishOutcome.Fallback); $finishExpected += ('|폴백 줄=' + $fallbackWant) }
    Check-Equal ('{0} {1}' -f $otherFinishRow[0], $otherFinishRow[1]) $finishActual $finishExpected
}
# FB-ending-typo (내부 검토 P3-5) - 값 집합 밖 끝맺음('rematch-canceled' 오타)은 대기를 부르기 전 매개변수 검증 오류(조용히 'ready' 로 가 exit 0 · 소비 · 다음 판이 되지 않음)
$typoOutcome = Invoke-OtherFinishRow -Wait @{ Result = 'confirmed'; Sends = 1 } -Ending 'rematch-canceled' -Flag $true
Check-Equal 'FB-ending-typo 집합 밖 끝맺음 → 대기 호출 0 · exit 센티널 0 · 소비 0 (대기 호출 / 센티널 / 소비)' ('{0}/{1}/{2}' -f $typoOutcome.WaitCalls, $typoOutcome.Exit.StartsWith('__EXIT__'), $typoOutcome.Removed) '0/False/0'
# SS3-real (명세 리뷰 2 P2 · 설계 v11 R6 7.3 SS3 · 5.1 · 변이 R6-M6) - 위 SS3 은 대기를 결과 스텁으로 두어 대기 안(확인 전)의 소비를 보지 못합니다. 여기서는 대기
#   원문을 감시 뒤에 올려(이름 바꿔 올림 - §3 Resolve-AbyssMemberSweepTurn 감시와 같은 꼴) 실제 대기 → 끝 함수를 지나게 하고, 대기가 돌아온 순간(결과 확정 ·
#   끝 함수의 소비 갈래 전)과 끝 함수 exit 뒤 두 시점에서 예약 소비 0 · 예약 그대로를 봅니다. 입력 = OW3 꼴(전송 → 확인 창 안 캡처 실패 → 동결 · 안전 확인
#   (예약 있음 · 실패 120초 전) → 복구 뒤 출처 없는 선택 화면 → 마감 'unconfirmed') + 대기 진입 전부터 예약 - 대기 진입 · 전송 뒤 · 확인 창 고리 · 동결 · 바깥
#   선택 화면을 지나는 판입니다(확인 창은 첫 판독이 캡처 실패 · 나머지 한 줄 동결이라 선택 갈래는 지나지 않습니다 - 선택 갈래는 아래 SS3-real-win).
#   'confirmed' ∧ ready 의 소비 1 은 SS1 · SS2 몫입니다(설계 v11 R6 5.1 '확인이 없으면 소비하지 않는다')
Invoke-Expression (([string]$otherWaitNode.Extent.Text) -replace '^function Wait-AbyssOtherSelection\b', 'function Invoke-RealWaitAbyssOtherSelection')
Invoke-Expression (New-MockDefinition -Name 'Wait-AbyssOtherSelection' -Body '$realWait = Invoke-RealWaitAbyssOtherSelection @PSBoundParameters; $script:otherRealWaitEnd = (''{0}/{1}/{2}/{3}'' -f [string]$realWait.Result, [int]$realWait.Sends, $script:safeStopRemoves, [bool]$script:safeStopFlagMock); return $realWait')
Reset-OtherWaitRow -Spec @{ Timeline = @(,@(0, 'R')); OnSend = @{ 1 = @(,@(6, 'S')) }; Fail = @(,@(2.2, 5.2)); F9 = $true }
$script:otherRealWaitEnd = '(대기 반환 없음)'
$realFinishError = ''
try { $null = Complete-AbyssOtherSelection -Game $null -Ending 'ready' } catch { $realFinishError = [string]$_.Exception.Message }
$realFinishLast = $(if ($script:rowLogs.Count -gt 0) { [string]$script:rowLogs[$script:rowLogs.Count - 1] } else { '' })
Check-Equal 'SS3-real 예약 + 원문 대기 unconfirmed(OW3 꼴) → 대기 끝(결과/전송/소비/예약) · 끝 함수(exit|소비/예약|진단|마지막 줄) - 확인 전 소비 0 · 예약 그대로' `
    ('{0} · {1}|{2}/{3}|{4}|{5}' -f $script:otherRealWaitEnd, $realFinishError, $script:safeStopRemoves, [bool]$script:safeStopFlagMock, $script:otherWaitDiagnostics.Count, $realFinishLast) `
    ('unconfirmed/1/0/True · __EXIT__4|0/True|1|' + $OTHER_DONE_UNCONFIRMED_SENT)
# SS3-real-win (명세 리뷰 2 확인 라운드 P2 · 설계 v11 R6 7.3 SS3 · 5.1 · 변이 R6-M6 확인 창 선택 갈래) - 위 SS3-real 과 같은 감시(올린 원문 대기 · 같은 두 시점)이고
#   입력만 OW28 꼴입니다(대기 행 표 OW28 의 명세 그대로 + 대기 진입 전부터 예약): 전송 → 확인 창의 선택 화면 판독 앞 일련번호 +1 → 판독 중 되돌림 → 확인 창 선택 갈래의
#   출처 판정 거짓 → 명시 폐기 · break → 바깥 회전의 출처 없는 선택 화면 → 마감 'unconfirmed'. 확인 창 선택 갈래(if ($confirmSelection) 안 · 출처 판정 앞)를
#   지나는 판이라 그 자리의 소비를 봅니다 - 기대는 SS3-real 과 같습니다(확인 전 소비 0 · 예약 그대로 · 'unconfirmed' 의 끝 함수 소비 0)
$otherWindowRealSpec = $OTHER_WAIT_ROWS['OW28'].Spec.Clone()
$otherWindowRealSpec['F9'] = $true
Reset-OtherWaitRow -Spec $otherWindowRealSpec
$script:otherRealWaitEnd = '(대기 반환 없음)'
$realFinishError = ''
try { $null = Complete-AbyssOtherSelection -Game $null -Ending 'ready' } catch { $realFinishError = [string]$_.Exception.Message }
$realFinishLast = $(if ($script:rowLogs.Count -gt 0) { [string]$script:rowLogs[$script:rowLogs.Count - 1] } else { '' })
Check-Equal 'SS3-real-win 예약 + 원문 대기 unconfirmed(OW28 꼴 - 확인 창 선택 갈래의 출처 거짓 폐기) → 대기 끝(결과/전송/소비/예약) · 끝 함수(exit|소비/예약|진단|마지막 줄) - 확인 전 소비 0 · 예약 그대로' `
    ('{0} · {1}|{2}/{3}|{4}|{5}' -f $script:otherRealWaitEnd, $realFinishError, $script:safeStopRemoves, [bool]$script:safeStopFlagMock, $script:otherWaitDiagnostics.Count, $realFinishLast) `
    ('unconfirmed/1/0/True · __EXIT__4|0/True|1|' + $OTHER_DONE_UNCONFIRMED_SENT)

# ── §9 정적 (명세 3.2 - 주석 뺀 사본 · AST · 22줄) ──
$otherWaitWhile = @($otherWaitNode.FindAll({ param($candidate) $candidate -is [WhileStatementAst] }, $true)) | Select-Object -First 1
$otherWaitText = $workerCode.Substring($otherWaitNode.Extent.StartOffset, $otherWaitNode.Extent.EndOffset - $otherWaitNode.Extent.StartOffset)       # 주석 뺀 원문(줄 구조 그대로)
$otherFinishText = $workerCode.Substring($otherFinishNode.Extent.StartOffset, $otherFinishNode.Extent.EndOffset - $otherFinishNode.Extent.StartOffset)
function Get-OtherFlatCode {
    # 주석 뺀 한 줄(Get-NodeCode)에서 줄 이음(` + 줄바꿈)을 공백 하나로 - 두 줄로 쓴 출처 판정 호출을 한 줄 글자로 대조
    param($Node)
    return ((Get-NodeCode $Node) -replace ' ?` ', ' ')
}
function Get-OtherAncestorIfs {
    # 노드를 감싼 if 문들 (안쪽부터 - 열거용, 호출부에서 @())
    param($Node)
    $ancestorIfs = @()
    for ($parentNode = $Node.Parent; $null -ne $parentNode; $parentNode = $parentNode.Parent) { if ($parentNode -is [IfStatementAst]) { $ancestorIfs += $parentNode } }
    return $ancestorIfs
}
$IS_OTHER_RESULT_SUBJECT = { param($Node) ($Node -is [VariableExpressionAst]) -and ($Node.VariablePath.UserPath -eq 'otherResult') }
$OTHER_VALIDITY_CODE = '$script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial'
$OTHER_PROVENANCE_FORMAT = 'Test-AbyssSelectionProvenance -Expected $otherExpected -ExpectedSerial $otherExpectedSerial -ExpectedYieldMs $otherExpectedYieldMs -ReferenceSerial {0} -YieldMs ([double]$script:userYieldTotalMs)'
# 선택 양성 예외 조건 - 패널 항은 분류 함수 순위 1('panel') if 의 조건 글자(소스 캡처)에서 인자 이름만 이 회전 판독 변수로 바꾼 것 (명세 3.2 SEL-1)
$otherRank1Ifs = @((Get-WorkerFunction 'Resolve-AbyssOtherWaitScreen').Body.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (@($candidate.Clauses[0].Item2.Statements).Count -eq 1) -and
            ((Get-NodeCode $candidate.Clauses[0].Item2.Statements[0]) -ceq "return 'panel'") }, $true))
$otherPanelCondition = $(if ($otherRank1Ifs.Count -eq 1) { (Get-NodeCode $otherRank1Ifs[0].Clauses[0].Item1).Replace('$PanelKind', '$panelKind').Replace('-Text $BottomText', '-Text ([string]$pairRead.Text)') } else { "(순위 1 if $($otherRank1Ifs.Count)개)" })
$OTHER_EXCEPTION_CODE = '$selectionNow -and (-not (' + $otherPanelCondition + ')) -and (-not $script:screenCaptureFailing)'

# P0 - 호출: 대기 = 끝 함수 안 1 · 끝 함수 = 끝(retry) 3 + 재개 끝 2 + 본류 1 (구현 명세 ⑤b4 3.4 · ⑤b5 · ⑤c)
$otherWaitOwners = @(Get-CommandNodes -Node $workerAst -Name 'Wait-AbyssOtherSelection' | ForEach-Object { Get-EnclosingFunctionName $_ }) -join ','
# (⑤b5 3.4 · ⑤c 5c-2 · 5c-3) Complete-AbyssOtherSelection 6 = 끝(retry) 3 + 재개 끝 2('cancelled' 갈래 - 5c-2 · 'record-failed' 의 -ExitOnly - 5c-3) + 본류 보상 화면 꼬리의 'other' 갈래 1
#   (소스 차례 - 재개 끝은 끝(retry) 뒤 · 본류 앞, 자리 '' = 본류)
Check-Equal 'P0(⑤b3) 워커 안 호출 - Wait-AbyssOtherSelection 자리 = Complete-AbyssOtherSelection 1 · Complete-AbyssOtherSelection 6(자리 = Complete-AbyssRetrySelection 3 - ⑤b4 · Complete-AbyssResumeWait 2 - ⑤c(cancelled 5c-2 · record-failed 5c-3 - -ExitOnly 는 ⑲ RCK3 · RCK4 행) · 본류 1 - ⑤b5)' `
    ('{0} / {1}=[{2}]' -f $otherWaitOwners, @(Get-CommandNodes -Node $workerAst -Name 'Complete-AbyssOtherSelection').Count, ((@(Get-CommandNodes -Node $workerAst -Name 'Complete-AbyssOtherSelection' | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ',')) `
    'Complete-AbyssOtherSelection / 6=[Complete-AbyssRetrySelection,Complete-AbyssRetrySelection,Complete-AbyssRetrySelection,Complete-AbyssResumeWait,Complete-AbyssResumeWait,]'

# R6-P1 - 출처 발급 `$otherExpected = `$true 1: 전송 갈래(if `$script:lastClickPerformed) 안 · 그 if 의 바로 앞 형제 = 클릭 · 'reward3' 클릭 갈래 안
$otherIssueNodes = @($otherWaitNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'otherExpected') -and (Test-IsVariable $candidate.Right 'true') }, $true))
$otherIssueOk = $false
if ($otherIssueNodes.Count -eq 1) {
    $issueIfs = @(Get-OtherAncestorIfs $otherIssueNodes[0])
    $performedIf = @($issueIfs | Where-Object { Test-IsVariable $_.Clauses[0].Item1 'script:lastClickPerformed' }) | Select-Object -First 1
    $rewardIf = @($issueIfs | Where-Object { $rewardLeaves = @(Get-AndLeaves $_.Clauses[0].Item1); @($rewardLeaves | Where-Object { (Test-ExactMatchSet -Expression $_ -IsSubject $IS_SCREEN_SUBJECT -Want @('reward3')) -ceq 'OK' }).Count -eq 1 }) | Select-Object -First 1
    if (($null -ne $performedIf) -and ($null -ne $rewardIf)) {
        $performedSiblings = @($performedIf.Parent.Statements)
        $performedAt = [Array]::IndexOf($performedSiblings, $performedIf)
        $performedPrevious = $(if ($performedAt -ge 1) { Get-StatementCommand $performedSiblings[$performedAt - 1] } else { $null })
        $otherIssueOk = ($null -ne $performedPrevious) -and ($performedPrevious.GetCommandName() -eq 'Click-GamePoint') -and (Test-AstWithin -Node $performedIf -Ancestor $rewardIf)
    }
}
Check-True "R6-P1(⑤b3) 출처 발급 1 - 전송 갈래(if `$script:lastClickPerformed) 안 · 그 if 바로 앞 형제 = 클릭 · 'reward3' 클릭 갈래 안" $otherIssueOk ("발급 {0}개" -f $otherIssueNodes.Count)

# R6-P2 - 클릭 1: 메타 비움 → Focus-Game → 클릭(같은 회전 짝 판독의 점)
$otherClickNodes = @(@(Get-CommandNodes -Node $otherWaitNode -Name 'Click-GamePoint') + @(Get-CommandNodes -Node $otherWaitNode -Name 'Click-ScreenPoint'))
$otherClickOk = $false
if ($otherClickNodes.Count -eq 1) {
    $clickStatement = $otherClickNodes[0].Parent
    $clickSiblings = @($clickStatement.Parent.Statements)
    $clickAt = [Array]::IndexOf($clickSiblings, $clickStatement)
    $focusCommand = $(if ($clickAt -ge 1) { Get-StatementCommand $clickSiblings[$clickAt - 1] } else { $null })
    $otherClickOk = ($clickAt -ge 2) -and ((Get-NodeCode $clickSiblings[$clickAt - 2]) -ceq "`$script:lastClickSkipReason = ''") -and ($null -ne $focusCommand) -and ($focusCommand.GetCommandName() -eq 'Focus-Game') -and
        ((Get-NodeCode $otherClickNodes[0]) -ceq 'Click-GamePoint -Game $Game -ReferenceX $pairRead.Other.X -ReferenceY $pairRead.Other.Y')
}
Check-True 'R6-P2(⑤b3) 클릭 1 - 메타 비움 → Focus-Game → Click-GamePoint(같은 회전 짝 판독의 점)' $otherClickOk ((@($otherClickNodes | ForEach-Object { Get-NodeCode $_ })) -join ' | ')

# R5-P2 - 시계: New 1(루프 밖) · Set 1(전송 갈래) · Suspend·Resume·마감 조정 셋 0 · AddSeconds·AddMilliseconds 0
$otherNewClocks = @(Get-CommandNodes -Node $otherWaitNode -Name 'New-AbyssMemberClock')
$otherNewInLoop = @($otherNewClocks | Where-Object { Test-AstWithin -Node $_ -Ancestor $otherWaitWhile }).Count
$otherSetClocks = @(Get-CommandNodes -Node $otherWaitNode -Name 'Set-AbyssMemberClock')
$otherSetInSend = @($otherSetClocks | Where-Object { @(Get-OtherAncestorIfs $_ | Where-Object { Test-IsVariable $_.Clauses[0].Item1 'script:lastClickPerformed' }).Count -eq 1 }).Count
$otherForbiddenClock = @(@('Suspend-AbyssMemberClock', 'Resume-AbyssMemberClock', 'Get-YieldAdjustedDeadline', 'Invoke-UserYieldWithDeadline', 'Get-FreezeAdjustedDeadline') | Where-Object { Test-HasCommand $otherWaitNode $_ })
$otherAddCalls = @($otherWaitNode.FindAll({ param($candidate) ($candidate -is [InvokeMemberExpressionAst]) -and (@('AddSeconds', 'AddMilliseconds') -contains $candidate.Member.Extent.Text) }, $true)).Count
Check-Equal 'R5-P2(⑤b3) 시계 - New 1 · 루프 안 New 0 · Set 1 · 전송 갈래 Set 1 · 금지 명령 [] · AddSeconds·AddMilliseconds 0' `
    ('{0}/{1}/{2}/{3}/[{4}]/{5}' -f $otherNewClocks.Count, $otherNewInLoop, $otherSetClocks.Count, $otherSetInSend, ($otherForbiddenClock -join ','), $otherAddCalls) '1/0/1/1/[]/0'

# R6-P3 - 대기 안 출처 판정 = 바깥(선택 양성 예외 - 회전 서두 기준) + 확인 창(판독 직전 기준) 인자 글자 · 워커 전체 4
$otherProvenanceTexts = @(Get-CommandNodes -Node $otherWaitNode -Name 'Test-AbyssSelectionProvenance' | ForEach-Object { Get-OtherFlatCode $_ } | Sort-Object)
$otherProvenanceWant = @(($OTHER_PROVENANCE_FORMAT -f '$turnSerial'), ($OTHER_PROVENANCE_FORMAT -f '$confirmSerial')) | Sort-Object
Check-Equal 'R6-P3(⑤b3) 출처 판정 - 대기 안 바깥(-ReferenceSerial $turnSerial) + 확인 창(-ReferenceSerial $confirmSerial) 인자 글자 · 워커 전체 4' `
    ('{0} | {1}' -f ($otherProvenanceTexts -join ' ## '), @(Get-CommandNodes -Node $workerAst -Name 'Test-AbyssSelectionProvenance').Count) ('{0} | 4' -f ($otherProvenanceWant -join ' ## '))

# R6-P4 - 출처 폐기 `$otherExpected = `$false 여덟 자리(AST 소유 - 명세 3.2 표)가 각 1 · 그 밖 0. 출처 거짓 두 자리는 바로 앞 형제가 그 단계의 출처 판정 if,
#   비선택 통합은 그 if 의 자리까지(⑦ 유효성 if 의 else 블록 직속 · 같은 블록의 ⑧ 분류 대입 뒤 - 확인 라운드 전 적대 검증 보강), 확인 창 출처 거짓은 바로 뒤
#   레이블 없는 break 로 블록이 끝나는 것까지(명세 1.7 ① - 구현 내부 검토 반영)
function Get-OtherDiscardPlace {
    param($Node)
    $ownerBlock = $Node.Parent
    if ($ownerBlock -is [NamedBlockAst]) {
        $ownerStatements = @($ownerBlock.Statements)
        $nodeAt = [Array]::IndexOf($ownerStatements, $Node)
        $whileAt = [Array]::IndexOf($ownerStatements, $otherWaitWhile)
        if ([object]::ReferenceEquals($ownerBlock, $otherWaitNode.Body.EndBlock) -and ($whileAt -ge 0) -and ($nodeAt -ge 0) -and ($nodeAt -lt $whileAt)) { return 'init' }
        return 'other:named-block'
    }
    if (-not (($ownerBlock -is [StatementBlockAst]) -and ($ownerBlock.Parent -is [IfStatementAst]))) { return ('other:' + $ownerBlock.GetType().Name) }
    $ownerIf = $ownerBlock.Parent
    $ownerClauses = @($ownerIf.Clauses | Where-Object { [object]::ReferenceEquals($_.Item2, $ownerBlock) })
    if ($ownerClauses.Count -ne 1) { return 'other:else' }
    $ownerCondition = Get-OtherFlatCode $ownerClauses[0].Item1
    $blockStatements = @($ownerBlock.Statements)
    $nodeAt = [Array]::IndexOf($blockStatements, $Node)
    $previousCondition = $(if (($nodeAt -ge 1) -and ($blockStatements[$nodeAt - 1] -is [IfStatementAst])) { Get-OtherFlatCode $blockStatements[$nodeAt - 1].Clauses[0].Item1 } else { '' })
    if ($ownerCondition -ceq '$script:screenCaptureFailing') { if ($ownerIf.Extent.StartLineNumber -ne $ownerIf.Extent.EndLineNumber) { return 'freeze' }; return 'other:one-line-freeze' }
    if ($ownerCondition -ceq 'Test-UserRecentlyActive') { return 'gate' }
    if ($ownerCondition -ceq '(-not $turnRecovered) -and (Invoke-PurchasePopupSweep -Game $Game)') { return 'sweep' }
    if ($ownerCondition -ceq "`$screen -ne 'selection'") {
        $placeBlock = $ownerIf.Parent
        $placeOk = ($placeBlock -is [StatementBlockAst]) -and ($placeBlock.Parent -is [IfStatementAst]) -and ([object]::ReferenceEquals($placeBlock.Parent.ElseClause, $placeBlock)) -and
            ((Get-OtherFlatCode $placeBlock.Parent.Clauses[0].Item1) -ceq $OTHER_VALIDITY_CODE)
        if ($placeOk) {
            $placeStatements = @($placeBlock.Statements)
            $ownerIfAt = [Array]::IndexOf($placeStatements, $ownerIf)
            $classifyAt = -1
            for ($statementIndex = 0; $statementIndex -lt $placeStatements.Count; $statementIndex++) {
                $placeStatement = $placeStatements[$statementIndex]
                if (($placeStatement -is [AssignmentStatementAst]) -and (Test-IsVariable $placeStatement.Left 'screen') -and (Test-HasCommand $placeStatement.Right 'Resolve-AbyssOtherWaitScreen')) { $classifyAt = $statementIndex; break }
            }
            if (($classifyAt -ge 0) -and ($ownerIfAt -gt $classifyAt)) { return 'non-selection' }
        }
        return 'other:non-selection-outside-8'
    }
    if ($ownerCondition -ceq "`$script:lastClickSkipReason -eq 'user-active'") { return 'skip-yield' }
    if ($ownerCondition -ceq '$confirmSelection') {
        if ($previousCondition -cne ($OTHER_PROVENANCE_FORMAT -f '$confirmSerial')) { return 'other:window-not-after-provenance' }
        # 바로 뒤 = 레이블 없는 break 로 그 블록이 끝남(명세 1.7 ① - 확인 창 출처 거짓은 남은 시도 없이 바깥 회전으로 · 내부 검토 반영, 행동이 거의 같아 행이 못 봄)
        if ((($nodeAt + 2) -eq $blockStatements.Count) -and ($blockStatements[$nodeAt + 1] -is [BreakStatementAst]) -and ($null -eq $blockStatements[$nodeAt + 1].Label)) { return 'window-provenance-false' }
        return 'other:window-no-break'
    }
    if ($ownerCondition -ceq $OTHER_EXCEPTION_CODE) { if ($previousCondition -ceq ($OTHER_PROVENANCE_FORMAT -f '$turnSerial')) { return 'outer-provenance-false' }; return 'other:outer-not-after-provenance' }
    return ('other:' + $ownerCondition)
}
$otherDiscardNodes = @($otherWaitNode.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'otherExpected') -and (Test-IsVariable $candidate.Right 'false') }, $true))
$OTHER_DISCARD_PLACES = @('init', 'freeze', 'gate', 'sweep', 'non-selection', 'outer-provenance-false', 'window-provenance-false', 'skip-yield')
$otherPlaces = @($otherDiscardNodes | ForEach-Object { Get-OtherDiscardPlace $_ })
$otherPlaceReport = @(foreach ($placeName in $OTHER_DISCARD_PLACES) { '{0}={1}' -f $placeName, @($otherPlaces | Where-Object { $_ -ceq $placeName }).Count }) +
    @('other=' + @($otherPlaces | Where-Object { $OTHER_DISCARD_PLACES -cnotcontains $_ }).Count)
Check-Equal 'R6-P4(⑤b3) 출처 폐기 여덟 자리(AST 소유) - 초기화 · 동결 · 서두 양보 · 스윕 참 · 비선택 통합(⑦ else 직속 · ⑧ 분류 대입 뒤) · 바깥 출처 거짓(선택 양성 예외) · 확인 창 출처 거짓(뒤 break 로 블록 끝) · 클릭 생략 뒤 양보 각 1 · 그 밖 0' `
    (($otherPlaceReport -join ' ') + $(if (@($otherPlaces | Where-Object { $OTHER_DISCARD_PLACES -cnotcontains $_ }).Count -gt 0) { ' [' + ((@($otherPlaces | Where-Object { $OTHER_DISCARD_PLACES -cnotcontains $_ })) -join ' | ') + ']' } else { '' })) `
    'init=1 freeze=1 gate=1 sweep=1 non-selection=1 outer-provenance-false=1 window-provenance-false=1 skip-yield=1 other=0'

# SEL-1 · SEL-2 - 선택 양성 예외(명세 리뷰 1 P2) = 바깥 회전의 유일한 선택 화면 결론 자리
$otherExceptionIfs = @($otherWaitNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-HasVariable $candidate.Clauses[0].Item1 'selectionNow') }, $true))
$sel1Parts = @()
$sel2Parts = @()
if ($otherExceptionIfs.Count -eq 1) {
    $exceptionIf = $otherExceptionIfs[0]
    $exceptionSiblings = @($exceptionIf.Parent.Statements)
    $exceptionAt = [Array]::IndexOf($exceptionSiblings, $exceptionIf)
    $previousIsSixth = ($exceptionAt -ge 1) -and ($exceptionSiblings[$exceptionAt - 1] -is [IfStatementAst]) -and ((Get-OtherFlatCode $exceptionSiblings[$exceptionAt - 1].Clauses[0].Item1) -ceq '[double]$script:userYieldTotalMs -ne $turnYieldMs')
    $nextIsSeventh = ($exceptionAt -ge 0) -and (($exceptionAt + 1) -lt $exceptionSiblings.Count) -and ($exceptionSiblings[$exceptionAt + 1] -is [IfStatementAst]) -and
        ((Get-OtherFlatCode $exceptionSiblings[$exceptionAt + 1].Clauses[0].Item1) -ceq $OTHER_VALIDITY_CODE)
    $sel1Parts += ('조건=' + ((Get-OtherFlatCode $exceptionIf.Clauses[0].Item1) -ceq $OTHER_EXCEPTION_CODE))
    $sel1Parts += ('else없음=' + (($exceptionIf.Clauses.Count -eq 1) -and ($null -eq $exceptionIf.ElseClause)))
    $sel1Parts += ('⑥뒤⑦앞=' + ($previousIsSixth -and $nextIsSeventh))
    $exceptionBody = @($exceptionIf.Clauses[0].Item2.Statements)
    $bodyProvenance = ($exceptionBody.Count -ge 1) -and ($exceptionBody[0] -is [IfStatementAst]) -and ((Get-OtherFlatCode $exceptionBody[0].Clauses[0].Item1) -ceq ($OTHER_PROVENANCE_FORMAT -f '$turnSerial')) -and
        ($exceptionBody[0].Clauses.Count -eq 1) -and ($null -eq $exceptionBody[0].ElseClause) -and (@($exceptionBody[0].Clauses[0].Item2.Statements).Count -eq 1) -and
        ((Get-NodeCode $exceptionBody[0].Clauses[0].Item2.Statements[0]) -ceq "return @{ Result = 'confirmed'; Sends = `$otherSends; LastKind = 'selection' }")
    $bodyDiscard = ($exceptionBody.Count -ge 2) -and ((Get-NodeCode $exceptionBody[1]) -ceq '$otherExpected = $false')
    $bodyNotice = ($exceptionBody.Count -eq 3) -and ($exceptionBody[2] -is [IfStatementAst]) -and ((Get-OtherFlatCode $exceptionBody[2].Clauses[0].Item1) -ceq '-not $otherUnprovenLogged') -and ($null -eq $exceptionBody[2].ElseClause) -and
        (@($exceptionBody[2].Clauses[0].Item2.Statements).Count -eq 2) -and ((Get-NodeCode $exceptionBody[2].Clauses[0].Item2.Statements[0]) -ceq '$otherUnprovenLogged = $true') -and
        ($null -ne (Get-StatementCommand $exceptionBody[2].Clauses[0].Item2.Statements[1])) -and ((Get-StatementCommand $exceptionBody[2].Clauses[0].Item2.Statements[1]).GetCommandName() -eq 'Write-RunLog') -and
        ((Get-NodeCode $exceptionBody[2].Clauses[0].Item2.Statements[1]).Contains('(출처 없음)'))
    $bodyJumps = @($exceptionIf.FindAll({ param($candidate) ($candidate -is [ContinueStatementAst]) -or ($candidate -is [BreakStatementAst]) }, $true)).Count
    $sel2Parts += ('출처참confirmed=' + $bodyProvenance)
    $sel2Parts += ('명시폐기=' + $bodyDiscard)
    $sel2Parts += ('안내1회=' + $bodyNotice)
    $sel2Parts += ('continue·break=' + $bodyJumps)
} else {
    $sel1Parts += ('예외 if ' + $otherExceptionIfs.Count + '개')
    $sel2Parts += ('예외 if ' + $otherExceptionIfs.Count + '개')
}
$otherNinthSelection = @($otherWaitNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (@($candidate.Clauses | Where-Object { (Test-ExactMatchSet -Expression $_.Item1 -IsSubject $IS_SCREEN_SUBJECT -Want @('selection')) -ceq 'OK' }).Count -gt 0) }, $true)).Count
$otherNoticeLiterals = @($otherWaitNode.FindAll({ param($candidate) (($candidate -is [StringConstantExpressionAst]) -or ($candidate -is [ExpandableStringExpressionAst])) -and ([string]$candidate.Value).Contains('(출처 없음)') }, $true)).Count
$sel2Parts += ('⑨selection갈래=' + $otherNinthSelection)
$sel2Parts += ('안내글자=' + $otherNoticeLiterals)
Check-Equal 'SEL-1(⑤b3) 선택 양성 예외 if 1 - 조건 세 항 글자(선택 화면 · 분류 순위 1 조건의 부정(소스 캡처) · 지금 실패 아님) · else 0 · ⑥ 간접 양보 if 바로 뒤 · ⑦ 유효성 if 바로 앞 형제' ($sel1Parts -join ' ') '조건=True else없음=True ⑥뒤⑦앞=True'
Check-Equal "SEL-2(⑤b3) 예외 본문 셋 - 출처(-ReferenceSerial `$turnSerial) 참 → confirmed 반환 · 명시 폐기 · 안내 1회 · continue·break 0 · ⑨ 'selection' 갈래 0 · 출처 없음 글자 1" ($sel2Parts -join ' ') `
    '출처참confirmed=True 명시폐기=True 안내1회=True continue·break=0 ⑨selection갈래=0 안내글자=1'

# R6-P5 - 안전 중지 예약: 대기 0 · 끝 함수 Remove-Item 1(대기 결과 'confirmed' 갈래 안)
$otherRemoveNodes = @(Get-CommandNodes -Node $otherFinishNode -Name 'Remove-Item')
$otherRemoveOk = ($otherRemoveNodes.Count -eq 1) -and (@(Get-OtherAncestorIfs $otherRemoveNodes[0] | Where-Object { (Test-ExactMatchSet -Expression $_.Clauses[0].Item1 -IsSubject $IS_OTHER_RESULT_SUBJECT -Want @('confirmed')) -ceq 'OK' }).Count -eq 1)
Check-Equal "R6-P5(⑤b3) 안전 중지 예약 - 대기 안 `$safeStopFlagPath 0 / 끝 함수 Remove-Item 1('confirmed' 갈래 안)" ('{0}/{1}' -f [regex]::Matches($otherWaitText, '\$safeStopFlagPath\b').Count, $otherRemoveOk) '0/True'

# R6-P6 - 금지: 대기(이벤트 정리 · 키 · 클릭 루프 · 헬퍼 · 복귀 루프 · journal · exit · 닫기(X) 후보) · 끝 함수(이벤트 정리 · 키 · 클릭 루프 · 클릭 · journal)
$OTHER_WAIT_FORBIDDEN = @('Clear-EventOverlay', 'Invoke-EventSkipOrConfirm', 'Press-KeyOnce', 'Press-KeyVerified', 'Invoke-ClickUntil', 'Invoke-AbyssExitClick', 'Return-ToAbyssSelection', 'Update-AbyssJournal', 'Read-AbyssJournal')
$OTHER_FINISH_FORBIDDEN = @('Clear-EventOverlay', 'Invoke-EventSkipOrConfirm', 'Press-KeyOnce', 'Press-KeyVerified', 'Invoke-ClickUntil', 'Click-GamePoint', 'Click-ScreenPoint', 'Update-AbyssJournal', 'Read-AbyssJournal')
Check-Equal 'R6-P6(⑤b3) 금지 - 대기 [명령]/exit/$xCandidates · 끝 함수 [명령]' `
    ('[{0}]/{1}/{2} · [{3}]' -f ((@($OTHER_WAIT_FORBIDDEN | Where-Object { Test-HasCommand $otherWaitNode $_ })) -join ','), @($otherWaitNode.FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count,
        [regex]::Matches($otherWaitText, '\$xCandidates\b').Count, ((@($OTHER_FINISH_FORBIDDEN | Where-Object { Test-HasCommand $otherFinishNode $_ })) -join ',')) '[]/0/0 · []'

# R6-P7 - 시각 읽기 0(지정 시각 env · $script:abyssUntil · 시간 판단 둘 - 결정·시간 줄은 5b-5)
$OTHER_TIME_PATTERN = 'HONEYNOGI_UNTIL_TIME|\$script:abyssUntil\b|(?<![\w-])Get-DgTimeVerdict(?![\w-])|(?<![\w-])Update-AbyssRetryTimeVerdict(?![\w-])'
Check-Equal 'R6-P7(⑤b3) 시각 읽기 - 대기 / 끝 함수 0' ('{0}/{1}' -f [regex]::Matches($otherWaitText, $OTHER_TIME_PATTERN, [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count,
        [regex]::Matches($otherFinishText, $OTHER_TIME_PATTERN, [Text.RegularExpressions.RegexOptions]::IgnoreCase).Count) '0/0'

# R6-P8 - 복귀 루프 매개변수 무변경
Check-Equal 'R6-P8(⑤b3) Return-ToAbyssSelection 매개변수 = Game · SafeStopExitCode · LeaveEntryReason' ((Get-DeclaredParameterNames -FunctionName 'Return-ToAbyssSelection') -join ',') 'Game,SafeStopExitCode,LeaveEntryReason'

# R6-P10 - post-clear 표지 새 글자 0 (워커 전체: ' (post-clear)' 문자열 0 - 그 꼬리를 담은 마지막 줄(재개 꺼짐 정지 S19)이 ⑤c 5c-2 에서 없어짐 · 'post-clear-stop' 1 - 지금 그대로 ·
#   $script:postClearCommitted 0)
$postClearStrings = @($workerAst.FindAll({ param($candidate) (($candidate -is [StringConstantExpressionAst]) -or ($candidate -is [ExpandableStringExpressionAst])) -and ([string]$candidate.Value).Contains(' (post-clear)') }, $true)).Count
$postClearStops = @($workerAst.FindAll({ param($candidate) ($candidate -is [StringConstantExpressionAst]) -and ([string]$candidate.Value -ceq 'post-clear-stop') }, $true)).Count
$postClearFlags = @($workerAst.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -eq 'script:postClearCommitted') }, $true)).Count
Check-Equal "R6-P10(⑤b3) ' (post-clear)' 문자열 / 'post-clear-stop' 글자 / `$script:postClearCommitted" ('{0}/{1}/{2}' -f $postClearStrings, $postClearStops, $postClearFlags) '0/1/0'

# R6-P13 - 복구 기동 갈래 둘(Consume-Handoff 의 복구 선행 if · 본류 복구 시작 선택 화면 if) 안 journal 읽기·쓰기 0 (사용자 결정 U-R6-1 (가))
$recoveryIfs5b3 = @((Get-WorkerFunction 'Consume-Handoff').FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-IsVariable $candidate.Clauses[0].Item1 'script:customRecoveryOnly') }, $true))
$recoveryStartIfs5b3 = @($workerAst.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and ((Get-NodeCode $candidate.Clauses[0].Item1) -ceq '$script:customRecoveryOnly -and (Test-AbyssSelectionScreen -Game $game)') }, $true))
$journalInRecovery5b3 = 0
foreach ($recoveryIf5b3 in @($recoveryIfs5b3 + $recoveryStartIfs5b3)) { foreach ($journalName5b3 in @('Read-AbyssJournal', 'Update-AbyssJournal')) { $journalInRecovery5b3 += @(Get-CommandNodes -Node $recoveryIf5b3.Clauses[0].Item2 -Name $journalName5b3).Count } }
Check-Equal 'R6-P13(⑤b3) 복구 갈래(Consume-Handoff / 복구 시작 선택 화면) 찾음 · 그 안 journal 읽기·쓰기' ('{0}/{1}/{2}' -f $recoveryIfs5b3.Count, $recoveryStartIfs5b3.Count, $journalInRecovery5b3) '1/1/0'

# R5-P1 - 회전 순서(뜻 - 평가 순서 · §8 Get-EvaluationKey): 앵커 열여섯이 평가 순서로 증가 · 동결 블록 = 원문 여섯 문장
$OTHER_R5P1_ANCHORS = @(
    @{ Label = '서두 메타 비움'; Match = { param($Node) ($Node -is [AssignmentStatementAst]) -and (Test-IsVariable $Node.Left 'script:lastClickSkipReason') } },
    @{ Label = '① 동결'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-IsVariable $Node.Clauses[0].Item1 'script:screenCaptureFailing') } },
    @{ Label = '② 양보'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasCommand $Node.Clauses[0].Item1 'Test-UserRecentlyActive') } },
    @{ Label = '③ 탐침 복구 뒤'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-IsVariable $Node.Clauses[0].Item1 'probeRecovered') } },
    @{ Label = '④ 스윕 분류'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Resolve-AbyssMemberSweepTurn') } },
    @{ Label = '⑤ 짝 판독'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Find-AbyssRewardButtonPair') } },
    @{ Label = '⑤ 패널 판독'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Get-AbyssPanelKind') } },
    @{ Label = 'catch'; Match = { param($Node) $Node -is [CatchClauseAst] } },
    @{ Label = '⑥ 간접 양보'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasVariable $Node.Clauses[0].Item1 'script:userYieldTotalMs') -and (Test-HasVariable $Node.Clauses[0].Item1 'turnYieldMs') } },
    @{ Label = '선택 양성 예외'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasVariable $Node.Clauses[0].Item1 'selectionNow') } },
    @{ Label = '바깥 출처 판정'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Test-AbyssSelectionProvenance') -and (Test-IsVariable (Get-CommandArgument -Command $Node -Name 'ReferenceSerial') 'turnSerial') } },
    @{ Label = '⑦ 유효성'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasVariable $Node.Clauses[0].Item1 'script:screenCaptureFailing') -and (Test-HasVariable $Node.Clauses[0].Item1 'turnSerial') } },
    @{ Label = '⑧ 분류'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Resolve-AbyssOtherWaitScreen') } },
    @{ Label = '⑩ 마감'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Test-AbyssMemberClockExpired') -and (Test-IsVariable (Get-CommandArgument -Command $Node -Name 'Clock') 'selectClock') } },
    @{ Label = '⑪ 클릭'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Click-GamePoint') } },
    @{ Label = '⑫ 기본 대기'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Start-Sleep') -and ($null -ne (Get-CommandArgument -Command $Node -Name 'Milliseconds' -PositionalNames @())) -and
            ((ConvertTo-AstKey (Get-CommandArgument -Command $Node -Name 'Milliseconds' -PositionalNames @())) -ceq $BASE_WAIT_KEY) } })
function Get-OtherR5P1Problems {
    # 어긋난 점 목록 (열거용 - 호출부에서 @()) - §8 Get-R5P1Problems 꼴(평가 순서 키 · 동결 블록 원문 요소)
    $problemList = New-Object System.Collections.Generic.List[string]
    if ($null -eq $otherWaitWhile) { $problemList.Add('while 없음'); return $problemList.ToArray() }
    $keyedNodes = @(foreach ($bodyNode in @($otherWaitWhile.Body.FindAll({ param($candidate) $true }, $true))) { [pscustomobject]@{ Key = (Get-EvaluationKey $bodyNode); Start = $bodyNode.Extent.StartOffset; Node = $bodyNode } })
    $keyedNodes = @($keyedNodes | Sort-Object Key, Start)
    $previousKey = [long]-1
    $freezeIf = $null
    foreach ($anchor in $OTHER_R5P1_ANCHORS) {
        $anchorHit = $null
        foreach ($keyedNode in $keyedNodes) { if (($keyedNode.Key -gt $previousKey) -and (& $anchor.Match $keyedNode.Node)) { $anchorHit = $keyedNode; break } }
        if ($null -eq $anchorHit) { $problemList.Add("빠짐·순서[$($anchor.Label)]"); return $problemList.ToArray() }
        if ($anchor.Label -eq '① 동결') { $freezeIf = $anchorHit.Node }
        $previousKey = $anchorHit.Key
    }
    # 동결 블록 = 원문 여섯 문장(출처 폐기 · 안전 확인 · Start-Sleep · [void] 탐침(-Game $Game) · 탐침 표식(플래그의 부정) · 단독 줄 continue) · 절 1 · elseif·else 0
    if (($freezeIf.Clauses.Count -ne 1) -or ($null -ne $freezeIf.ElseClause)) { $problemList.Add('동결 elseif/else') }
    $freezeStatements = @($freezeIf.Clauses[0].Item2.Statements)
    if ($freezeStatements.Count -ne 6) { $problemList.Add("동결 문장 수 $($freezeStatements.Count)"); return $problemList.ToArray() }
    if (-not (($freezeStatements[0] -is [AssignmentStatementAst]) -and (Test-IsVariable $freezeStatements[0].Left 'otherExpected') -and (Test-IsVariable $freezeStatements[0].Right 'false'))) { $problemList.Add('동결 1(출처 폐기)') }
    $safeStopCommand = Get-StatementCommand $freezeStatements[1]
    if (($null -eq $safeStopCommand) -or ($safeStopCommand.GetCommandName() -ne 'Test-SafeStopDuringCaptureFail')) { $problemList.Add('동결 2(안전 확인)') }
    $sleepCommand = Get-StatementCommand $freezeStatements[2]
    if (($null -eq $sleepCommand) -or ($sleepCommand.GetCommandName() -ne 'Start-Sleep')) { $problemList.Add('동결 3(Start-Sleep)') }
    $probeOk = $false
    $voidNode = Get-InnerExpression $freezeStatements[3]
    if (($voidNode -is [ConvertExpressionAst]) -and ((Get-ResolvedTypeName $voidNode.Type.TypeName) -eq 'System.Void')) {
        $probePipeline = Get-InnerExpression $voidNode.Child
        if (($probePipeline -is [PipelineAst]) -and ($probePipeline.PipelineElements.Count -eq 1) -and ($probePipeline.PipelineElements[0] -is [CommandAst]) -and
            ($probePipeline.PipelineElements[0].GetCommandName() -eq 'Test-CaptureRecovered') -and (Test-IsVariable (Get-CommandArgument -Command $probePipeline.PipelineElements[0] -Name 'Game') 'Game')) { $probeOk = $true }
    }
    if (-not $probeOk) { $problemList.Add('동결 4([void] 탐침)') }
    if (-not (($freezeStatements[4] -is [AssignmentStatementAst]) -and (Test-IsVariable $freezeStatements[4].Left 'probeRecovered') -and ((ConvertTo-AstKey $freezeStatements[4].Right) -ceq 'Un(Not|V(script:screencapturefailing))'))) { $problemList.Add('동결 5(탐침 표식)') }
    if (-not (($freezeStatements[5] -is [ContinueStatementAst]) -and ($null -eq $freezeStatements[5].Label) -and ((Get-LineCode $freezeStatements[5]) -ceq 'continue'))) { $problemList.Add('동결 6(단독 줄 continue)') }
    return $problemList.ToArray()
}
$otherR5P1Problems = @(Get-OtherR5P1Problems)
Check-True 'R5-P1(⑤b3) 회전 순서(뜻 - 평가 순서): 서두 메타 비움 < ① 동결 < ② 양보 < ③ 탐침 복구 뒤 < ④ 스윕 분류 < ⑤ 짝 < 패널 < catch < ⑥ 간접 양보 < 선택 양성 예외 < 바깥 출처 판정(-ReferenceSerial $turnSerial) < ⑦ 유효성 < ⑧ 분류 < ⑩ 마감 < ⑪ 클릭 < ⑫ 기본 대기 · 동결 블록 = 원문 여섯 문장' `
    ($otherR5P1Problems.Count -eq 0) ($otherR5P1Problems -join ' · ')

# WAIT - 대기 값 정확 고정 (구현 리뷰 B P3 · 명세 1.2 ① · ⑫). R5-P1 은 ⑫ 기본 대기만 값으로 보고(앵커) 동결 블록의 대기는 이름만 봐서, 굶김 회전의 700ms 대기(근사
#   동치 RV-S1)나 더 긴 동결 · 복구 · 짝 재판독 대기를 행 · 정적이 못 가렸습니다. 여기서 ① 동결 블록(while 직속 여러 줄 if)의 Start-Sleep 과 ⑫ while 끝 네 문장(굶김 =
#   대기 없이 continue → 복구 → 짝 재판독 → 기본)의 차례 · 갈래 조건 · 인자 값(ms - Get-OtherSleepText)을 글자로 대조합니다. 굶김 · 복구 · 짝 재판독 회전은 서로 배타라
#   셋의 차례를 바꿔도 행동이 같아 행이 못 보는 몫입니다. 기대 = 선분기 원문 값(동결 · 복구 · 기본) · 계약 1초(짝 재판독) - §9 준비의 주석
function Get-OtherWaitShape {
    # 대기 함수의 ① 동결 대기 · ⑫ while 끝 네 문장을 한 줄 글자로
    if ($null -eq $otherWaitWhile) { return '(while 없음)' }
    $loopStatements = @($otherWaitWhile.Body.Statements)
    $freezeIfs = @($loopStatements | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-OtherFlatCode $_.Clauses[0].Item1) -ceq '$script:screenCaptureFailing') })
    $freezeText = "(동결 if $($freezeIfs.Count)개)"
    if ($freezeIfs.Count -eq 1) {
        $freezeSleeps = @(foreach ($freezeStatement in @($freezeIfs[0].Clauses[0].Item2.Statements)) {
                $freezeCommand = Get-StatementCommand $freezeStatement
                if (($null -ne $freezeCommand) -and ($freezeCommand.GetCommandName() -eq 'Start-Sleep')) { Get-OtherSleepText $freezeStatement }
            })
        $freezeText = $freezeSleeps -join '; '
    }
    if ($loopStatements.Count -lt 4) { return ('① 동결 {{ {0} }} · ⑫ (while 문장 {1}개)' -f $freezeText, $loopStatements.Count) }
    $tailParts = @()
    foreach ($tailStatement in @($loopStatements[($loopStatements.Count - 4)..($loopStatements.Count - 1)])) {
        if ($tailStatement -is [IfStatementAst]) {
            $tailBody = (@($tailStatement.Clauses[0].Item2.Statements | ForEach-Object { Get-OtherSleepText $_ })) -join '; '
            $tailElse = $(if (($tailStatement.Clauses.Count -ne 1) -or ($null -ne $tailStatement.ElseClause)) { ' + elseif/else' } else { '' })
            $tailParts += ('if ({0}) {{ {1} }}{2}' -f (Get-OtherFlatCode $tailStatement.Clauses[0].Item1), $tailBody, $tailElse)
        } else {
            $tailParts += (Get-OtherSleepText $tailStatement)
        }
    }
    return ('① 동결 {{ {0} }} · ⑫ {1}' -f $freezeText, ($tailParts -join ' · '))
}
$otherWaitShapeWant = '① 동결 {{ {0} }} · ⑫ if ($sweepStarved) {{ continue }} · if ($turnRecovered) {{ {1}ms; continue }} · if ($pairRecheck) {{ {2}ms; continue }} · {3}ms' -f
    $OTHER_FREEZE_WAIT_TEXT, $RECOVERED_WAIT_MS, $OTHER_PAIR_RECHECK_MS, $BASE_WAIT_MS
Check-Equal 'WAIT(⑤b3) 대기 값 - ① 동결 블록 Start-Sleep = 선분기 동결 대기 · ⑫ while 끝 네 문장 = 굶김 continue(대기 0) → 복구(선분기 복구 대기) → 짝 재판독(계약 1초) → 기본(선분기 기본 대기) - 차례 · 갈래 조건 · 인자 값(ms)' `
    (Get-OtherWaitShape) $otherWaitShapeWant

# WAIT-N - 대기 함수 안 Start-Sleep 의 수 · 자리 (구현 리뷰 B 확인 라운드 P3 · 명세 1.2 의 대기 자리). WAIT 는 ① 동결 블록과 while 끝 네 문장만 봐서, 그 밖 자리에
#   더한 대기(⑪ 블록 뒤 ⑫ 앞 단독 대기 · 굶김 회전 대기를 ⑫ 앞 새 if 로 옮긴 꼴 - RV-S1 과 같은 행동 · 회전 서두 · 유효 회전 블록 안)를 행 · 정적이 못 가려 ⑫ 대기
#   계약(굶김 0 · 그 밖 700ms - 유효 회전 블록 안은 굶김 회전에서 돌지 않아 그 밖 700ms 쪽)을 우회할 수 있었습니다. 여기서 대기 함수 안 Start-Sleep 명령(AST)을 모두 세어 자리로 나눕니다 - ① 동결 = while 직속 여러 줄 동결 if 안 · ⑪ 확인 창 = 전송
#   갈래(if $script:lastClickPerformed) 안 · ⑫ 대기 = while 끝 네 문장(WAIT 와 같은 자리) · 지정 자리 밖 = 그 나머지. 기대 = 명세 1.2 의 자리별 수(① 2초 1 · 확인 창
#   2초 + 1초×6 고리 2 · ⑫ 복구 2초 · 짝 재판독 1초 · 기본 700ms 3 - 굶김 0) - 계약 수라 소스 캡처하지 않습니다(OW13 의 3 과 같은 이유). 값(ms) · ⑫ 차례 · 조건은 WAIT 가 봅니다
function Get-OtherSleepPlace {
    # Start-Sleep 명령 하나의 자리 이름 (위 주석의 뜻 - 대기 함수 while 직속 문장으로 올라가 가름)
    param($SleepNode)
    if ($null -eq $otherWaitWhile) { return '지정 자리 밖' }
    $loopStatements = @($otherWaitWhile.Body.Statements)
    $topStatement = $null
    for ($currentNode = $SleepNode; $null -ne $currentNode.Parent; $currentNode = $currentNode.Parent) {
        if ([object]::ReferenceEquals($currentNode.Parent, $otherWaitWhile.Body)) { $topStatement = $currentNode; break }
    }
    if ($null -eq $topStatement) { return '지정 자리 밖' }
    if (($topStatement -is [IfStatementAst]) -and ((Get-OtherFlatCode $topStatement.Clauses[0].Item1) -ceq '$script:screenCaptureFailing') -and
        ($topStatement.Extent.StartLineNumber -ne $topStatement.Extent.EndLineNumber)) { return '① 동결' }
    if (@(Get-OtherAncestorIfs $SleepNode | Where-Object { Test-IsVariable $_.Clauses[0].Item1 'script:lastClickPerformed' }).Count -gt 0) { return '⑪ 확인 창' }
    if (($loopStatements.Count -ge 4) -and ([Array]::IndexOf($loopStatements, $topStatement) -ge ($loopStatements.Count - 4))) { return '⑫ 대기' }
    return '지정 자리 밖'
}
$OTHER_SLEEP_PLACE_NAMES = @('① 동결', '⑪ 확인 창', '⑫ 대기', '지정 자리 밖')
$otherSleepNodes = @(Get-CommandNodes -Node $otherWaitNode -Name 'Start-Sleep')
$otherSleepPlaces = @($otherSleepNodes | ForEach-Object { Get-OtherSleepPlace $_ })
$otherSleepOutside = @(for ($sleepIndex = 0; $sleepIndex -lt $otherSleepNodes.Count; $sleepIndex++) { if ($otherSleepPlaces[$sleepIndex] -ceq '지정 자리 밖') { Get-NodeCode $otherSleepNodes[$sleepIndex] } })
$otherSleepReport = ('{0} = {1}' -f $otherSleepNodes.Count, ((@(foreach ($sleepPlaceName in $OTHER_SLEEP_PLACE_NAMES) { '{0} {1}' -f $sleepPlaceName, @($otherSleepPlaces | Where-Object { $_ -ceq $sleepPlaceName }).Count })) -join ' · ')) +
    $(if ($otherSleepOutside.Count -gt 0) { ' [' + ($otherSleepOutside -join ' | ') + ']' } else { '' })
Check-Equal 'WAIT-N(⑤b3) 대기 함수 안 Start-Sleep = 6 - 명세 1.2 의 대기 자리: ① 동결(2초) 1 · ⑪ 확인 창(전송 뒤 2초 + 1초×6 고리) 2 · ⑫ 대기(복구 2초 · 짝 재판독 1초 · 기본 700ms · 굶김 0) 3 · 지정 자리 밖 0' `
    $otherSleepReport '6 = ① 동결 1 · ⑪ 확인 창 2 · ⑫ 대기 3 · 지정 자리 밖 0'

# R5-P12 - 한 줄 동결 if 는 확인 창(foreach 1..6) 안 1뿐 (회전 수준 동결은 위 여러 줄 블록 - stall 계수)
$otherConfirmLoops = @($otherWaitNode.FindAll({ param($candidate) ($candidate -is [ForEachStatementAst]) -and ((Get-NodeCode $candidate.Condition) -ceq '1..6') }, $true))
$otherOneLineFreeze = @($otherWaitNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-IsVariable $candidate.Clauses[0].Item1 'script:screenCaptureFailing') -and ($candidate.Extent.StartLineNumber -eq $candidate.Extent.EndLineNumber) }, $true))
Check-Equal 'R5-P12(⑤b3) 한 줄 동결 if = 확인 창(foreach 1..6) 안 1 (확인 창 / 한 줄 if / 그 안)' `
    ('{0}/{1}/{2}' -f $otherConfirmLoops.Count, $otherOneLineFreeze.Count, (($otherConfirmLoops.Count -eq 1) -and ($otherOneLineFreeze.Count -eq 1) -and (Test-AstWithin -Node $otherOneLineFreeze[0] -Ancestor $otherConfirmLoops[0]))) '1/1/True'

# R5-P13 - 짝 < 패널 < 클릭 · 패널과 클릭 사이 판독 0 (주석 뺀 회전 본문)
$otherLoopText = $workerCode.Substring($otherWaitWhile.Body.Extent.StartOffset, $otherWaitWhile.Body.Extent.EndOffset - $otherWaitWhile.Body.Extent.StartOffset)
$OTHER_READ_NAMES = 'Find-AbyssRewardButtonPair|Test-HomeEndEscHud|Test-InDungeonQuest|Test-AbyssSelectionScreen|Get-AbyssPanelKind|Invoke-PurchasePopupSweep|Test-CaptureRecovered|Get-GameRegionOcrText|Get-GameOcrText|Get-GameRegionOcrWords|Find-GameTextPoint|Test-ExitButton|Test-AbyssMenu'
$otherPairAt = $otherLoopText.IndexOf('Find-AbyssRewardButtonPair', [StringComparison]::Ordinal)
$otherPanelAt = $otherLoopText.IndexOf('Get-AbyssPanelKind', [StringComparison]::Ordinal)
$otherClickAt = $otherLoopText.IndexOf('Click-GamePoint', [StringComparison]::Ordinal)
$otherReadsBetween = $(if (($otherPanelAt -ge 0) -and ($otherClickAt -gt $otherPanelAt)) { [regex]::Matches($otherLoopText.Substring($otherPanelAt + 'Get-AbyssPanelKind'.Length, $otherClickAt - $otherPanelAt - 'Get-AbyssPanelKind'.Length), $OTHER_READ_NAMES).Count } else { -1 })
Check-Equal 'R5-P13(⑤b3) 짝 < 패널 < 클릭 / 패널과 클릭 사이 판독' ('{0}/{1}' -f (($otherPairAt -ge 0) -and ($otherPairAt -lt $otherPanelAt) -and ($otherPanelAt -lt $otherClickAt)), $otherReadsBetween) 'True/0'

# R5-P16 - 창 좌표 throw 제한 catch: try 2 · 각 catch 판정 = §8 Get-WindowCatchProblems(절 1 · 형식 0 · 단독 throw · 잎 셋 - 두 캡처 문구 정확 일치) ·
#   try 본문 모양 - 회전 try = ④ 스윕 if + ⑤ 판독 if(스윕 if 를 try 밖으로 옮기면 스윕의 창 좌표 throw 가 catch 를 벗어남) · 확인 창 try = 선택 화면 판독 대입 1
function Get-OtherR5P16Problems {
    $problemList = New-Object System.Collections.Generic.List[string]
    $tryNodes = @($otherWaitNode.FindAll({ param($candidate) $candidate -is [TryStatementAst] }, $true) | Sort-Object { $_.Extent.StartOffset })
    if ($tryNodes.Count -ne 2) { $problemList.Add("try $($tryNodes.Count)개"); return $problemList.ToArray() }
    $turnStatements = @($tryNodes[0].Body.Statements)
    if (($turnStatements.Count -ne 2) -or (-not ($turnStatements[0] -is [IfStatementAst])) -or (-not (Test-HasCommand $turnStatements[0].Clauses[0].Item1 'Invoke-PurchasePopupSweep')) -or
        (-not ($turnStatements[1] -is [IfStatementAst])) -or (-not (Test-HasCommand $turnStatements[1].Clauses[0].Item2 'Find-AbyssRewardButtonPair'))) { $problemList.Add("회전 try 본문 = ④ 스윕 if + ⑤ 판독 if 가 아님(문장 $($turnStatements.Count)개)") }
    $windowStatements = @($tryNodes[1].Body.Statements)
    if (($windowStatements.Count -ne 1) -or (-not ($windowStatements[0] -is [AssignmentStatementAst])) -or (-not (Test-IsVariable $windowStatements[0].Left 'confirmSelection')) -or
        (-not (Test-HasCommand $windowStatements[0].Right 'Test-AbyssSelectionScreen'))) { $problemList.Add("확인 창 try 본문 = 선택 화면 판독 대입 하나가 아님(문장 $($windowStatements.Count)개)") }
    for ($tryIndex = 0; $tryIndex -lt 2; $tryIndex++) { foreach ($catchProblem in @(Get-WindowCatchProblems -TryNode $tryNodes[$tryIndex])) { $problemList.Add(('try{0} {1}' -f ($tryIndex + 1), $catchProblem)) } }
    return $problemList.ToArray()
}
$otherR5P16Problems = @(Get-OtherR5P16Problems)
Check-True "R5-P16(⑤b3) 창 좌표 throw 제한 catch - try 2 · 회전 try 본문 = ④ 스윕 if + ⑤ 판독 if · 확인 창 try 본문 = 선택 화면 판독 대입 1 · 각 catch 절 1 · 형식 0 · 단독 throw · 조건 = -not(플래그 ∧ 원인 = $WINDOW_GONE_CAUSE ∧ 메시지 ∈ 두 캡처 문구)" `
    ($otherR5P16Problems.Count -eq 0) ($otherR5P16Problems -join ' · ')

# PT4 · P5b-2 자리 - 짝 판독을 부르는 곳 = '다른 던전 가기' 대기 · '다시 하기' 클릭 루프(구현 명세 ⑤b4 3.4) · 분류 함수를 부르는 곳 = 대기 1
Check-Equal 'PT4 · P5b-2(⑤b3) 자리 - Find-AbyssRewardButtonPair / Resolve-AbyssOtherWaitScreen 를 부르는 함수' `
    ('{0} / {1}' -f ((@(Get-CommandNodes -Node $workerAst -Name 'Find-AbyssRewardButtonPair' | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ','),
        ((@(Get-CommandNodes -Node $workerAst -Name 'Resolve-AbyssOtherWaitScreen' | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ',')) 'Wait-AbyssOtherSelection,Invoke-AbyssRetryClick / Wait-AbyssOtherSelection'

# -Ending 매개변수 (내부 검토 P3-5 · 구현 리뷰 B P2 - 선례 Resolve-AbyssReentryVerdict -Target): 형 [string] · 기본값 'ready'(생략 호출 = ReadySelection - 행 FB-ending-default) ·
#   ValidateSet {ready, rematch-cancelled}(집합 밖 = 매개변수 검증 오류 - 행 FB-ending-typo) - ⑥d 가 'member-timeout' 을 더할 때 넓힘. 형 삭제 · 기본값 삭제는 늘 'ready'
#   와 같은 갈래를 타 행이 못 가리므로 선언 글자로 봅니다(명세 1.3 끝맺음 값)
$endingParameters5b3 = @($otherFinishNode.Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Ending' })
$endingDeclaration5b3 = "(매개변수 $($endingParameters5b3.Count)개)"
if ($endingParameters5b3.Count -eq 1) {
    $endingTypes5b3 = (@($endingParameters5b3[0].Attributes | Where-Object { $_ -is [TypeConstraintAst] } | ForEach-Object { Get-ResolvedTypeName $_.TypeName })) -join ','
    $endingDefaultNode5b3 = Get-InnerExpression $endingParameters5b3[0].DefaultValue
    $endingDefault5b3 = $(if ($endingDefaultNode5b3 -is [StringConstantExpressionAst]) { "'" + [string]$endingDefaultNode5b3.Value + "'" } elseif ($null -eq $endingDefaultNode5b3) { '(없음)' } else { '(상수 아님: ' + (Get-NodeCode $endingDefaultNode5b3) + ')' })
    $endingValues5b3 = (@($endingParameters5b3[0].Attributes | Where-Object { ($_ -is [AttributeAst]) -and ($_.TypeName.Name -eq 'ValidateSet') } | ForEach-Object { (@($_.PositionalArguments | ForEach-Object { [string]$_.Value } | Sort-Object -CaseSensitive)) -join ',' })) -join ';'
    $endingDeclaration5b3 = '[{0}] = {1} · ValidateSet {{{2}}}' -f $endingTypes5b3, $endingDefault5b3, $endingValues5b3
}
Check-Equal "-Ending 매개변수(⑤b3) - Complete-AbyssOtherSelection 의 Ending = [string] 형 · 기본값 'ready' · ValidateSet {ready, rematch-cancelled}" $endingDeclaration5b3 "[System.String] = 'ready' · ValidateSet {ready,rematch-cancelled}"


# ── §10 ⑤b4 '다시 하기' 클릭 루프 · 원 워커 재입장 대기(호출 B) · 재입장 완료 11/0 · 'none' 행 · 폴백 ② 호출 E - 행 · 정적 · 관측 0 재생 (구현 명세 ⑤b4 2.2 · 3.1 · 3.2 · 3.5 - 비교는 -ceq) ──
# 대상(구현 명세 ⑤b4 1.2~1.5): Get-AbyssReentryLimitSeconds(모드 예산) · Invoke-AbyssRetryClick(클릭 루프 - 결과 @{ Result; LastKind }) · Complete-AbyssRetrySelection(끝 -
#   'record-failed' · 클릭 직전 재검사의 'safe-stop' · 'last' 를 반환(구현 명세 ⑤b6 1.6 - 본류가 옛 나가기) · 나머지 exit) · Complete-AbyssInsideHandoff(재입장 완료 11/0) · Stop-AbyssReentryTimeout('none' 행 코드 4) · Stop-AbyssReentryFieldCancelled(필드 취소 끝 코드 4 - ⑤c 5c-2 가 끝(retry) 'field-cancelled' 갈래에서 옮긴 공유 정지 함수) · Complete-AbyssOtherSelection 넓힘(-Nonce ·
#   폴백 ② 의 패널 셋 ∧ 재입장 요청 판 → 호출 E). 워커 안 호출은 끝(retry) 안과 끝(other) 안뿐입니다(본류 배선은 5b-5 - 아래 정적 P5d-1). 원문을 그대로 올립니다(사본 재구현
#   금지) - exit 가 있는 넷은 exit 센티널 치환본(§3 Convert-ExitSentinel - 줄 단독 exit 만)이고 클릭 루프 · 모드 예산은 exit 0 을 확인한 뒤 그대로 올립니다. 여섯 중 하나라도
#   워커에 없으면 'FAIL 준비' 로 끝납니다(§10 의 행 · 정적이 돌지 않음 - 명세 0.4)
# 하니스(명세 2.2): §4 의 가상 시계(Ticks · 시계 훅) · 캡처 상태 모형(Register-MockFail · 원문 Register-CaptureSuccess · 실패 창 · 주기 실패 창) · 조작 창(Test-UserRecentlyActive ·
#   Wait-UserYieldEnd 모의) · 스윕 모의(Set-SweepFrom - 'sent' · 'recover' · 'rect-click-throw' · 'click-throw-noreg' · 'gate-true') · 탐침 · 안전 확인(원문 센티널) · 안전 중지 파일 모의와
#   §9 의 끝 함수(센티널 치환본) · 헬퍼 · 복귀 루프 · 진단 기록 스텁을 그대로 씁니다. 이 절이 더하는 것 = 판독 스텁 여섯(짝 · 하단 · HUD · 추적기 · 선택 화면 · 패널 - 한 화면 표로
#   클릭 루프 · 원문 재입장 대기 · 원문 '다른 던전 가기' 대기가 같은 화면을 읽음 · 판독 비용은 아래 상수) · 클릭 기록 스텁(부른 루프로 retry/other 를 가름 · 전송마다 화면 전이 ·
#   'user-active' · 'cursor-not-ready' 주입) · 포커스 기록 · 완료 기록(journal - 단계 쓰기 셋 · 저장소 묶음 원문 + 행마다 임시 폴더의 실제 파일 · 저장 경계 감시가 호출을 기록하고
#   'locked'/'expect-failed' 만 주입 · 실제 쓰기 직후 시계 훅 - K4 · 아래 '완료 기록' 문단) · Wait-AbyssReentry(행마다 결과 스텁 또는
#   원문 - 이름 바꿔 올림) · '다른 던전 가기' 대기(결과 스텁 또는 원문) · Get-DgTimeVerdict · Update-AbyssRetryTimeVerdict 감시(원문으로 넘김 - 호출 수). 행의 시각은 사건 구동이고
#   (설계 v11 R3 6.6 '시계는 사건 구동'), 마감 L · 모드 예산 · 짝 재판독 대기는 소스 캡처입니다(숫자 재기입 없음 - 규칙 9). 행 이름 = 시제품 연기 시험(⑤b4 시제품 mod5)의
#   이름 · 설계 이름(R3 K · R1 W · R5 WA · R6 FB/SS) · 명세가 더한 이름(RC · RP · UP · UQ). 판독 훅 · 시계 훅은 스크립트 범위 스크립트블록이고 $script: 와 리터럴 · 스크립트
#   상수만 읽습니다(GetNewClosure 금지 - 규칙 3)
$RETRY_TARGET_NAMES = @('Get-AbyssReentryLimitSeconds', 'Invoke-AbyssRetryClick', 'Complete-AbyssRetrySelection', 'Complete-AbyssInsideHandoff', 'Stop-AbyssReentryTimeout',
    'Stop-AbyssReentryFieldCancelled')   # 마지막 = 재입장 대기 필드 취소의 공유 정지 함수(⑤c 5c-2 - 끝(retry) 'field-cancelled' 갈래가 부름)
foreach ($retryTargetName in $RETRY_TARGET_NAMES) {
    if (-not $workerFunctions.ContainsKey($retryTargetName)) { "FAIL 준비: 워커 최상위에 $retryTargetName 이(가) 없습니다 (구현 명세 ⑤b4 2.1)"; exit 1 }
}
foreach ($retryNoExitName in @('Get-AbyssReentryLimitSeconds', 'Invoke-AbyssRetryClick')) {
    $retryNoExitCount = @($workerFunctions[$retryNoExitName].FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count
    if ($retryNoExitCount -gt 0) { "FAIL 준비: $retryNoExitName 안에 exit ${retryNoExitCount}개 - 하니스를 같은 프로세스에서 돌릴 수 없습니다 (구현 명세 ⑤b4 1.2 끝)"; exit 1 }
}
$retryClickNode = $workerFunctions['Invoke-AbyssRetryClick']
$retryFinishNode = $workerFunctions['Complete-AbyssRetrySelection']
$retryInsideNode = $workerFunctions['Complete-AbyssInsideHandoff']
$retryNoneNode = $workerFunctions['Stop-AbyssReentryTimeout']
$retryFieldCancelNode = $workerFunctions['Stop-AbyssReentryFieldCancelled']
$retryLimitNode = $workerFunctions['Get-AbyssReentryLimitSeconds']

# 상수 - 워커 최상위 대입을 config 기본값으로 평가합니다(Get-ConfigInteger 기본값 반환 모의 - §9 와 같음). 마감 L 은 §9 의 캡처를 그대로 씁니다
try {
    $timeoutEntry = [int](Get-SourceAssignmentValue 'timeoutEntry')
    $timeoutPartyMatch = [int](Get-SourceAssignmentValue 'timeoutPartyMatch')
} catch {
    "FAIL 준비: ⑤b4 상수 캡처 실패 ($($_.Exception.Message))"
    exit 1
}
$RETRY_L = $OTHER_WAIT_LIMIT   # 클릭 루프 마감 L = $timeoutAbyssSelect (§9 캡처 · 행 설계 범위 [11, 36] 준비 게이트를 함께 지남)
# 짝 재판독 대기 (명세 3.2 'RC1a 간격 기대의 출처' - 명세 리뷰 1 확인 질문 ①): 같은 계약 꼴의 다른 원문인 '다른 던전 가기' 대기의 ⑫ 재판독에서 캡처합니다.
#   함수 첫 while 의 직속 if ($pairRecheck) 하나 · 그 안 Start-Sleep 하나의 -Seconds/-Milliseconds 상수 - 정확히 하나가 아니면 'FAIL 준비'. 클릭 루프 자신에서 캡처하면 워커가
#   캡처 원천이자 변이 대상이라 간격 기대가 값 변이를 따라 움직입니다(1100ms 꼴은 WAIT 만 잡음 - ④:3062~3064 와 같은 이유)
function Get-RetryRecheckWaitMs {
    param($FunctionNode)
    $captureWhile = @($FunctionNode.FindAll({ param($candidate) $candidate -is [WhileStatementAst] }, $true)) | Select-Object -First 1
    if ($null -eq $captureWhile) { return $null }
    $recheckIfs = @($captureWhile.Body.Statements | Where-Object { ($_ -is [IfStatementAst]) -and (Test-IsVariable $_.Clauses[0].Item1 'pairRecheck') })
    if ($recheckIfs.Count -ne 1) { return $null }
    $recheckSleeps = @(Get-CommandNodes -Node $recheckIfs[0] -Name 'Start-Sleep')
    if ($recheckSleeps.Count -ne 1) { return $null }
    $recheckText = Get-OtherSleepText $recheckSleeps[0].Parent
    if (-not ($recheckText -match '^(\d+(\.\d+)?)ms$')) { return $null }
    return [double]$Matches[1]
}
$RETRY_RECHECK_WAIT_MS = Get-RetryRecheckWaitMs (Get-WorkerFunction 'Wait-AbyssOtherSelection')
if ($null -eq $RETRY_RECHECK_WAIT_MS) { "FAIL 준비: '다른 던전 가기' 대기 ⑫ 의 짝 재판독 대기를 캡처하지 못했습니다 (if (`$pairRecheck) 하나 · Start-Sleep 상수 하나 - 명세 3.2 'RC1a 간격 기대의 출처')"; exit 1 }

# 하니스 판독 비용(초) - 시제품 연기 시험(⑤b4 mod5 하니스)의 모의 비용과 같은 값입니다. 행의 시각표 · RC1a 의 회전 비용 기대 · 경계 행의 마감 판정 시각이 이 표 하나를 씁니다
$RETRY_COST = @{ sweep = 0.1; prompt = 0.05; panel = 0.08; hud = 0.04; quest = 0.02; selection = 0.06; menu = 0.06; pair = 0.04; focus = 0.5; click = 0.45 }   # menu = 구현 단위 5b-8 2.2-4a(선택 화면과 같은 하니스 값)
# 클릭 루프 첫 시도의 재판단 시각(진입부터) = 스윕 → 짝 → HUD(거짓이면 추적기 0) → 패널 → 포커스 (기록 · 재검사 · 재판단은 비용 0) - K 행의 지정 시각을 이 값에서 잽니다
$RETRY_FIRST_JUDGE = $RETRY_COST.sweep + $RETRY_COST.pair + $RETRY_COST.hud + $RETRY_COST.panel + $RETRY_COST.focus
# RC1a 의 회전 비용 = 짝 판독 → HUD · 패널 → [⑫ 재판독 대기] → 다음 회전 스윕 → 짝 판독 (짝 판독 시각은 판독 시작 · 양보 검사와 줄은 비용 0)
$RETRY_RC1A_TURN_COST = $RETRY_COST.pair + $RETRY_COST.hud + $RETRY_COST.panel + $RETRY_COST.sweep
# 경계 행(RC1g · RC1h)의 마감 판정 시각 = 그 회전 짝 판독 시작 + 짝 · HUD · 패널 (⑧ · ⑨ · ⑩ 은 비용 0)
$RETRY_TURN_CHECK_OFFSET = $RETRY_COST.pair + $RETRY_COST.hud + $RETRY_COST.panel
# 경계 행(RC1g · RC1h)의 Rr 시작 = U 회전 박자(스윕 → 짝 → HUD → 패널 → ⑫ 기본 대기 - 비용 상수 + 선분기 소스 캡처 기본 대기)로 잰 마감 회전(그 회전 마감 판정 ≥ L 인
#   첫 회전 k)의 짝 판독 바로 앞(RC1h) / 그 앞 회전(k - 1)의 짝 판독 바로 앞(RC1g). L 에서 고정 거리(L - 1 · L)로 두면 회전 박자와 L 의 상대 위치가 L 마다 달라
#   정수 L 27~30 에서 경계를 벗어났습니다(명세 2.2 의 정수 L 전수 확인 11~36 - 행 전제 단언 Test-RetryDeadlineTurnPair 는 그대로)
$RETRY_U_TURN = $RETRY_COST.sweep + $RETRY_COST.pair + $RETRY_COST.hud + $RETRY_COST.panel + ($BASE_WAIT_MS / 1000.0)
$retryDeadlineTurn = [int][Math]::Ceiling((($RETRY_L - $RETRY_COST.sweep - $RETRY_TURN_CHECK_OFFSET) / $RETRY_U_TURN) - 1e-9)
$RETRY_RC1H_AT = $retryDeadlineTurn * $RETRY_U_TURN + $RETRY_COST.sweep - 0.01
$RETRY_RC1G_AT = ($retryDeadlineTurn - 1) * $RETRY_U_TURN + $RETRY_COST.sweep - 0.01
$RETRY_NONCE = '7c9e6679-7425-40de-944b-e07fc1f90ae7'   # 행의 클리어 기록 nonce (GUID 'D' 꼴)
$RETRY_OLDER_NONCE = '1b4e28ba-2fa1-41d2-883f-0016d3cca427'   # 씨앗 journal 의 지난 판 항목 nonce (그 항목은 어느 행에서도 그대로여야 함)
$RETRY_JOURNAL_SEED_SEQ = 5                                   # 씨앗 journal 의 seq (실제 쓰기 하나마다 +1 - 저장소 원문)

# 기대 문구 - 구현 명세 ⑤b4 0.3 · 1.2~1.4 의 글자 (재입장 완료 줄은 설계 v11 R1 2.2 원문 · 'none' 둘은 R6 3.5 ② 원문 · 시간 줄 ③ 은 R3 3.7 원문 · 직전 판단 줄 ②(안전 중지 ·
#   지정 시각)는 클릭 루프 원문 캡처 - 구현 명세 ⑤b6 3.4. 그 끝말 '나가기'로 던전 밖에 나와 마칩니다 · '다른 던전 가기' 0 은 정적 P5e-9 가 고정)
$RETRY_LINE_CLICK_FORMAT = "[어비스] '다시 하기' 클릭 - 글자 탐색 기준좌표 ({0},{1})"
$RETRY_LINE_MISS_FIRST_PREFIX = "[어비스] 보상 화면에서 '다시 하기' 글자를 찾지 못했습니다 - 1초 뒤 다시 읽습니다 (판독: '"
$RETRY_LINE_MISS_END_PREFIX = "[어비스] 보상 화면에서 '다시 하기' 글자를 찾지 못했습니다 - '다른 던전 가기' 로 선택 화면에서 마칩니다 (판독: '"
$RETRY_LINE_CURSOR = "[어비스] 커서 미확인으로 '다시 하기' 를 누르지 못해 '다른 던전 가기' 로 선택 화면에서 마칩니다"
$retryJudgeNodes = @((Get-WorkerFunction 'Invoke-AbyssRetryClick').FindAll({ param($candidate) (($candidate -is [StringConstantExpressionAst]) -or ($candidate -is [ExpandableStringExpressionAst])) -and
            ([string]$candidate.Value).StartsWith("[어비스] '다시 하기' 직전 판단: ", [StringComparison]::Ordinal) }, $true))
$retryJudgeSafe = @($retryJudgeNodes | Where-Object { ([string]$_.Value).StartsWith("[어비스] '다시 하기' 직전 판단: 안전 중지 ", [StringComparison]::Ordinal) })
$retryJudgeLast = @($retryJudgeNodes | Where-Object { ($_ -is [ExpandableStringExpressionAst]) -and (@($_.NestedExpressions).Count -eq 1) -and ([string]$_.Value).StartsWith("[어비스] '다시 하기' 직전 판단: 지정 시간 ", [StringComparison]::Ordinal) })
if (($retryJudgeSafe.Count -ne 1) -or ($retryJudgeLast.Count -ne 1)) { "FAIL 준비: '다시 하기' 직전 판단 줄 캡처 실패 (안전 중지 $($retryJudgeSafe.Count)개 · 지정 시각 $($retryJudgeLast.Count)개 - 1개씩이어야 함 · 구현 명세 ⑤b6 3.4)"; exit 1 }
$RETRY_LINE_SAFE = [string]$retryJudgeSafe[0].Value
$RETRY_LINE_LAST_FORMAT = ([string]$retryJudgeLast[0].Value).Replace([string]$retryJudgeLast[0].NestedExpressions[0].Extent.Text, '{0}')
$RETRY_LINE_CONTINUE_FORMAT = "[어비스] 지정 시간 {0} 전에 '다시 하기'로 이어 가기로 정했습니다 - 다음 판에 들어갔고 다음 워커가 이어받습니다"
$RETRY_LINE_RECLICK = "[어비스] '다시 하기' 뒤 보상 화면이 그대로라 한 번 더 누릅니다"
$RETRY_LINE_TWICE = "[어비스] '다시 하기' 를 두 번 눌러도 보상 화면이 그대로입니다 - '다른 던전 가기' 로 선택 화면에서 마칩니다"
# 'unconfirmed' 두 문구(명세 1.3 · B-3 - 전송 0 / 재클릭 호출). 전송 0 문구는 명세 리뷰 2 P3 로 '보상 화면이 아닌 화면이 이어져' → '이번 클릭을 보내지 못한 채 확인 대기 시간이
#   지나'(RC1h - 첫 결측이 마감 회전이면 그 회전은 보상 화면이라 옛 글자가 사실과 어긋남). RC2a · RC1h 는 전송 0 문구 그대로를, RC2b 는 재클릭 호출 문구 그대로를 마지막 줄로 봅니다
$RETRY_DONE_UNCONFIRMED_NOSEND = "[완료] '다시 하기' 를 누르려 했지만 이번 클릭을 보내지 못한 채 확인 대기 시간이 지나 멈춥니다 (누르지 않음). 화면을 확인하고 다시 시작해 주세요"
$RETRY_DONE_UNCONFIRMED_RESEND = "[완료] '다시 하기' 를 한 번 더 누르려 했지만 이번 클릭을 보내지 못한 채 확인 대기 시간이 지나 멈춥니다 (누르지 않음 - 앞서 누른 '다시 하기' 로 새 판이 입장 직후 키 없이 시작됐을 수 있으니 화면을 확인해 주세요)"
$RETRY_IH_BODY = "[완료] '다시 하기' 재입장 확인 - 직전 판을 회차로 계상, 다음 실행이 이 판을 이어받습니다"
$RETRY_IH_LINE = $RETRY_IH_BODY + (' [terminal=InsideHandoff nonce={0}]' -f $RETRY_NONCE)
$RETRY_NONE_SOLO = "[완료] '다시 하기' 뒤 ${timeoutEntry}초 안에 입장을 확인하지 못해 정지합니다 (누르지 않음 - 늦게 입장하면 입장 직후 키 없이 던전에 들어갈 수 있으니 화면을 확인해 주세요)"
$RETRY_NONE_PARTY = "[완료] '다시 하기' 뒤 ${timeoutPartyMatch}초 안에 입장을 확인하지 못했습니다 - 매칭 취소·나가기 없이 정지합니다 (매칭이 끝나면 입장 직후 키 없이 던전에 들어갈 수 있으니 화면을 확인해 주세요)"
# 구현 단위 5b-8 - 재매칭 ESC 취소 정지 줄(공유 정지 함수 원문 - ⑤c 5c-2 가 끝(retry) 갈래에서 옮김) · 재입장 대기의 재매칭 패널 확인 안내(원문)를 소스에서 캡처합니다(규칙 9). 정확히 하나가 아니면 준비를 멈추지 않고
#   '(소스에 없음 N)' 으로 두고 정적 FC-S15 가 FAIL 로 알립니다 - 공유 정지 함수가 없는 워커(⑤c 5c-2 전)는 위 대상 확인에서 'FAIL 준비' 로 먼저 멈춥니다
$retryFieldDoneNodes = @((Get-WorkerFunction 'Stop-AbyssReentryFieldCancelled').FindAll({ param($candidate) (($candidate -is [StringConstantExpressionAst]) -or ($candidate -is [ExpandableStringExpressionAst])) -and
            ([string]$candidate.Value).StartsWith('[완료] 재매칭이 취소돼 필드로', [StringComparison]::Ordinal) }, $true))
$RETRY_DONE_FIELD_CANCELLED = $(if ($retryFieldDoneNodes.Count -eq 1) { [string]$retryFieldDoneNodes[0].Value } else { '(소스에 없음 {0})' -f $retryFieldDoneNodes.Count })
$retryPanelNoticeNodes = @((Get-WorkerFunction 'Wait-AbyssReentry').FindAll({ param($candidate) ($candidate -is [StringConstantExpressionAst]) -and
            ([string]$candidate.Value).StartsWith('[어비스] 재매칭 패널 확인', [StringComparison]::Ordinal) }, $true))
$RETRY_LINE_PANEL_NOTICE = $(if ($retryPanelNoticeNodes.Count -eq 1) { [string]$retryPanelNoticeNodes[0].Value } else { '(소스에 없음 {0})' -f $retryPanelNoticeNodes.Count })
# 단계 쓰기 원문이 저장 실패에 남기는 [경고] 줄(설계 R2 3.6 낱말 - 'expect-failed' = 기록 실패 · 'locked' = 파일 사용 중. 글자는 test_abyss_journal_store.ps1 의
#   $REENTERED_FAIL_FORMAT · $RETRY_CLICKED_FAIL_FORMAT 과 같음) - W13(reentered 'expect-failed' 주입) · RC12(retry-clicked 'locked' 주입)
$RETRY_REENTERED_FAIL_LINE = '[경고] 재입장 완료 기록을 저장하지 못했습니다 (기록 실패) - 재입장 완료 줄을 남기고 이어 갑니다'
$RETRY_CLICKED_FAIL_LINE = '[경고] 재입장 클릭 기록을 저장하지 못했습니다 (파일 사용 중) - 재입장 확인을 계속합니다'
# 재입장 완료 줄의 기대 글자 = test_abyss_handoff_gui.ps1 의 $IH_BODY (GUI 판별이 고정한 워커 문구 - 명세 2.2 준비 단언). 그 파일의 최상위 대입 상수를 읽어 대조합니다
$retryGuiTestPath = Join-Path $PSScriptRoot 'test_abyss_handoff_gui.ps1'
$retryGuiBody = $null
try {
    $retryGuiTokens = $null; $retryGuiErrors = $null
    $retryGuiAst = [Parser]::ParseFile($retryGuiTestPath, [ref]$retryGuiTokens, [ref]$retryGuiErrors)
    $retryGuiAssign = @($retryGuiAst.EndBlock.Statements | Where-Object { ($_ -is [AssignmentStatementAst]) -and (Test-IsVariable $_.Left 'IH_BODY') }) | Select-Object -First 1
    if ($null -ne $retryGuiAssign) {
        $retryGuiValue = Get-InnerExpression $retryGuiAssign.Right
        if (($retryGuiValue -is [StringConstantExpressionAst]) -or ($retryGuiValue -is [ExpandableStringExpressionAst])) { $retryGuiBody = [string]$retryGuiValue.Value }
    }
} catch {
    $retryGuiBody = $null
}
if ($retryGuiBody -cne $RETRY_IH_BODY) { "FAIL 준비: 재입장 완료 줄 기대 글자가 test_abyss_handoff_gui.ps1 의 `$IH_BODY 와 다릅니다 ([$retryGuiBody] / [$RETRY_IH_BODY] - 명세 2.2)"; exit 1 }

# 원문 올림 - 감시 둘(Get-DgTimeVerdict · Update-AbyssRetryTimeVerdict)의 원문은 이름 바꿔 올리고, 같은 이름은 호출 수를 세는 감시가 차지합니다. Wait-AbyssReentry · '다른 던전 가기'
#   대기 · 클릭 루프도 이름 바꿔 올리고 같은 이름은 행 스텁/원문을 고르는 감시가 차지합니다(⑤b3 SS3-real 꼴). 끝 함수 셋은 센티널 치환본입니다
$RETRY_RENAMED = [ordered]@{
    'Get-DgTimeVerdict'            = 'Invoke-RealGetDgTimeVerdict'
    'Update-AbyssRetryTimeVerdict' = 'Invoke-RealUpdateAbyssRetryTimeVerdict'
    'Wait-AbyssReentry'            = 'Invoke-RealWaitAbyssReentry'
    'Invoke-AbyssRetryClick'       = 'Invoke-RealAbyssRetryClick'
}
try {
    foreach ($retryRenameEntry in $RETRY_RENAMED.GetEnumerator()) {
        Invoke-Expression (([string]$workerFunctions[$retryRenameEntry.Key].Extent.Text) -replace ('^function ' + [regex]::Escape($retryRenameEntry.Key) + '\b'), ('function ' + $retryRenameEntry.Value))
    }
    Invoke-Expression ([string]$retryLimitNode.Extent.Text)
} catch {
    "FAIL 준비: ⑤b4 함수를 워커에서 올리지 못했습니다 ($($_.Exception.Message))"
    exit 1
}
$retrySentinelStart = $script:sentinelChecks.Count
$retryFinishDefinition = Convert-ExitSentinel -Text ([string]$retryFinishNode.Extent.Text) -Label 'Complete-AbyssRetrySelection'
$retryInsideDefinition = Convert-ExitSentinel -Text ([string]$retryInsideNode.Extent.Text) -Label 'Complete-AbyssInsideHandoff'
$retryNoneDefinition = Convert-ExitSentinel -Text ([string]$retryNoneNode.Extent.Text) -Label 'Stop-AbyssReentryTimeout'
$retryFieldCancelDefinition = Convert-ExitSentinel -Text ([string]$retryFieldCancelNode.Extent.Text) -Label 'Stop-AbyssReentryFieldCancelled'
foreach ($retrySentinel in @($script:sentinelChecks[$retrySentinelStart..($script:sentinelChecks.Count - 1)])) {
    if (($retrySentinel[1] -lt 1) -or ($retrySentinel[2] -ne $retrySentinel[1]) -or ($retrySentinel[3] -ne 0)) {
        "FAIL 준비: $($retrySentinel[0]) exit 센티널 - 원본 ExitStatementAst $($retrySentinel[1]) · 줄 단독 $($retrySentinel[2]) · 치환 뒤 $($retrySentinel[3]) (모두 줄 단독이어야 함 - 명세 1.4 · R5 2.1 끝)"
        exit 1
    }
}
Invoke-Expression $retryFinishDefinition
Invoke-Expression $retryInsideDefinition
Invoke-Expression $retryNoneDefinition
Invoke-Expression $retryFieldCancelDefinition

# 화면 약어 → 판독값 (명세 2.2). 하단 판독문은 §4 $SCREEN_TABLE 의 실측 문자열 그대로(R · M · I · U)이거나 그 문자열에서 조각 하나를 뺀 변형입니다
#   (Rr = R 의 '다세하기' 뺌 - 3버튼 서명 참 · '다시 하기' 점 없음 · '다른 던전 가기' 점 있음). S = 선택 화면(보상 위 오버레이 - 하단 '' · §9 의 S 와 같음).
#   Retry · Other = 그 판독의 두 점 있음(점은 §9 의 3버튼 점 - 09-18 보관 프레임). 클릭 루프 · 재입장 대기 · '다른 던전 가기' 대기가 한 표를 읽습니다.
#   F = 필드 모양(HUD 만 - §4 F cap_210525_840 · 구현 단위 5b-8 FC-X 행)
$RETRY_SCREENS = [ordered]@{
    'R'  = @{ Bottom = $SCREEN_TABLE['R'].Bottom; Retry = $true; Other = $true; Prompt = $false; Panel = 'none'; Hud = $false; Quest = $false; Selection = $false }
    'Rr' = @{ Bottom = $SCREEN_TABLE['R'].Bottom.Replace('다세하기', ''); Retry = $false; Other = $true; Prompt = $false; Panel = 'none'; Hud = $false; Quest = $false; Selection = $false }
    'M'  = @{ Bottom = $SCREEN_TABLE['M'].Bottom; Retry = $false; Other = $false; Prompt = $false; Panel = 'matching'; Hud = $false; Quest = $false; Selection = $false }
    'I'  = @{ Bottom = $SCREEN_TABLE['I'].Bottom; Retry = $false; Other = $false; Prompt = $false; Panel = 'none'; Hud = $true; Quest = $true; Selection = $false }
    'F'  = @{ Bottom = $SCREEN_TABLE['F'].Bottom; Retry = $false; Other = $false; Prompt = $false; Panel = 'none'; Hud = $true; Quest = $false; Selection = $false }
    'U'  = @{ Bottom = $SCREEN_TABLE['U'].Bottom; Retry = $false; Other = $false; Prompt = $false; Panel = 'none'; Hud = $false; Quest = $false; Selection = $false }
    'S'  = @{ Bottom = ''; Retry = $false; Other = $false; Prompt = $false; Panel = 'none'; Hud = $false; Quest = $false; Selection = $true }
}
$RETRY_RETRY_POINT = @{ X = $OTHER_WAIT_RETRY_POINT[0]; Y = $OTHER_WAIT_RETRY_POINT[1] }
$RETRY_OTHER_POINT = @{ X = [int]$OTHER_WAIT_DEFAULT_POINTS[0][1]; Y = [int]$OTHER_WAIT_DEFAULT_POINTS[0][2] }
# 대응표 확인(준비 - 행이 가정하는 분류를 원문 분류 함수가 냄): 클릭 루프 · 재입장 대기 = Resolve-AbyssHandoffStartScreen(클릭 루프는 S 거짓 · 하단 = 짝 판독문) ·
#   '다른 던전 가기' 대기 = Resolve-AbyssOtherWaitScreen
$RETRY_SCREEN_KINDS = [ordered]@{ 'R' = 'reward3/reward3'; 'Rr' = 'reward3/reward3'; 'M' = 'matching/panel'; 'I' = 'inside/inside'; 'F' = 'field/field'; 'U' = 'unknown/unknown'; 'S' = 'unknown/selection' }
$retryKindsActual = @(foreach ($retryScreenKey in $RETRY_SCREENS.Keys) {
        $retryScreenEntry = $RETRY_SCREENS[$retryScreenKey]
        '{0}={1}/{2}' -f $retryScreenKey, (Resolve-AbyssHandoffStartScreen -PromptVisible $false -BottomText $retryScreenEntry.Bottom -PanelKind $retryScreenEntry.Panel -HudVisible $retryScreenEntry.Hud -InDungeonQuest $retryScreenEntry.Quest),
        (Resolve-AbyssOtherWaitScreen -BottomText $retryScreenEntry.Bottom -PanelKind $retryScreenEntry.Panel -SelectionVisible $retryScreenEntry.Selection -HudVisible $retryScreenEntry.Hud -InDungeonQuest $retryScreenEntry.Quest)
    }) -join ' '
$retryKindsExpected = @(foreach ($retryScreenKey in $RETRY_SCREEN_KINDS.Keys) { '{0}={1}' -f $retryScreenKey, $RETRY_SCREEN_KINDS[$retryScreenKey] }) -join ' '
if ($retryKindsActual -cne $retryKindsExpected) { "FAIL 준비: §10 화면 대응표의 원문 분류가 어긋납니다 (실제 [$retryKindsActual] / 기대 [$retryKindsExpected])"; exit 1 }

# 화면 출처 - 합성 행은 시각표(약어), 재생 행은 관측 0 전이 표의 프레임(아래 재생 절)입니다. 지금 화면 = 시각 ≤ 지금인 마지막 단계(첫 단계보다 이르면 'U')
function Add-RetryPlan {
    param([double]$At, [string]$Screen)
    if (-not $RETRY_SCREENS.Contains($Screen)) { throw "§10 시각표의 약어 $Screen 이(가) 대응표에 없습니다" }
    $script:retryPlanSeq++
    $script:retryPlan = @(@(@($script:retryPlan) + @(@{ AtTicks = (ConvertTo-Ticks $At); S = $Screen; Seq = $script:retryPlanSeq })) |
            Sort-Object @{ Expression = { $_.AtTicks } }, @{ Expression = { $_.Seq } })
}
function Get-RetryScreenNow {
    # 지금 화면의 판독값 (@{ Key; Bottom; Retry(점|$null); Other(점|$null); Prompt; Panel; Hud; Quest; Selection; Sweep; Frame })
    if ($script:retryReplay) { return (Get-RetryReplayFrame -At $script:vclock) }
    $nowTicks = Get-VirtualTicks
    $screenKey = 'U'
    foreach ($planStep in @($script:retryPlan)) { if ($planStep.AtTicks -le $nowTicks) { $screenKey = [string]$planStep.S } }
    $screenEntry = $RETRY_SCREENS[$screenKey]
    return @{ Key = $screenKey; Bottom = [string]$screenEntry.Bottom; Retry = $(if ($screenEntry.Retry) { $RETRY_RETRY_POINT } else { $null }); Other = $(if ($screenEntry.Other) { $RETRY_OTHER_POINT } else { $null })
        Prompt = [bool]$screenEntry.Prompt; Panel = [string]$screenEntry.Panel; Hud = [bool]$screenEntry.Hud; Quest = [bool]$screenEntry.Quest; Selection = [bool]$screenEntry.Selection; Sweep = $false; Frame = $screenKey }
}
function Get-RetryReadCost {
    # 판독 한 번의 가상 시간(초) - 합성 행은 $RETRY_COST, 재생 행은 전이 표 머리의 판독 비용 중앙값 × 배수 + 캡처 몫
    param([string]$Kind)
    if ($script:retryReplay) { return ((([double]$RETRY_REPLAY_MEDIAN_MS[$Kind]) * $script:retryReplayFactor + $script:retryReplayCaptureMs) / 1000.0) }
    return [double]$RETRY_COST[$Kind]
}
function Invoke-RetryRead {
    # 판독 한 번(판독 스텁 여섯의 공통 몸통): 화면은 판독 시작 시각의 것 · 판독 기록 · 판정(행 판독 훅 > 실패 창 · 판독 시작 시각) · 비용만큼 시계 → 캡처 등록 → 화면(실패면 $null).
    #   훅 판정 - 'fail'(원인 other 등록) · 'rect'(gameWindowGone 등록 → 짝은 실패 반환(원문 짝 판독은 throw 없음) · 그 밖은 판독 경로 문구 throw) · 'other-throw'(등록 없는
    #   다른 예외) · 'rect-other'(gameWindowGone 등록 → 셋째 예외) · 'msg-othercause'(원인 other 등록 → 판독 경로 문구 throw) - §9 판독 훅과 같은 뜻
    param([string]$Name)
    $script:captureAttempts++
    if ($script:captureAttempts -gt $CALL_LIMIT) { throw '__VTIMEOUT__' }
    $readStart = Get-VirtualElapsed
    $readScreen = Get-RetryScreenNow
    $readVerdict = ''
    if ($null -ne $script:retryReadHook) { $readVerdict = "$(& $script:retryReadHook $Name)" }
    elseif (Test-InFailWindow) { $readVerdict = 'fail' }
    Step-VirtualClock (Get-RetryReadCost $Name)
    $script:retryReads.Add([pscustomobject]@{ T = $readStart; Name = $Name; Frame = [string]$readScreen.Frame; Class = [string]$readScreen.Class; InClick = ($script:retryInClick -gt 0); InWaiter = ($script:retryInWaiter -gt 0) })
    if ($readVerdict -eq 'fail') { Register-MockFail -Cause $OTHER_CAUSE; return $null }
    if ($readVerdict -eq 'rect') {
        Register-MockFail -Cause $WINDOW_GONE_CAUSE
        if ($Name -eq 'pair') { return $null }
        throw $READ_PATH_MESSAGE
    }
    if ($readVerdict -eq 'other-throw') { throw $OTHER_WAIT_OTHER_ERROR }
    if ($readVerdict -eq 'rect-other') { Register-MockFail -Cause $WINDOW_GONE_CAUSE; throw $OTHER_WAIT_THIRD_ERROR }
    if ($readVerdict -eq 'msg-othercause') { Register-MockFail -Cause $OTHER_CAUSE; throw $READ_PATH_MESSAGE }
    Register-MockSuccess
    return $readScreen
}
function Invoke-RetryPairStub {
    # 짝 판독 - @{ Text; Retry; Other } (캡처 실패면 Text '' · 두 점 $null - 원문 Find-AbyssRewardButtonPair 의 반환 꼴). 짝 판독 번호 덮어쓰기(RC1f · RC7 - 시제품 연기 시험의
    #   -PairReadScreens 꼴: 행 전체 짝 판독의 n 번째를 그 약어 화면으로)
    $script:retryPairCount++
    $pairScreen = Invoke-RetryRead -Name 'pair'
    if ($null -eq $pairScreen) { return @{ Text = ''; Retry = $null; Other = $null } }
    if ($script:retryPairOverride.ContainsKey($script:retryPairCount)) {
        $overrideEntry = $RETRY_SCREENS[[string]$script:retryPairOverride[$script:retryPairCount]]
        return @{ Text = [string]$overrideEntry.Bottom; Retry = $(if ($overrideEntry.Retry) { $RETRY_RETRY_POINT } else { $null }); Other = $(if ($overrideEntry.Other) { $RETRY_OTHER_POINT } else { $null }) }
    }
    return @{ Text = [string]$pairScreen.Bottom; Retry = $pairScreen.Retry; Other = $pairScreen.Other }
}
function Invoke-RetryPromptStub {
    # 하단(재입장 대기 ⑤ 첫 판독) - 스태시 갱신(캡처 실패면 '') · S 판정 (원문 Test-DungeonClearPrompt 의 꼴)
    $promptScreen = Invoke-RetryRead -Name 'prompt'
    if ($null -eq $promptScreen) { $script:lastClearPromptText = ''; return $false }
    $script:lastClearPromptText = ([string]$promptScreen.Bottom) -replace '\s', ''
    $script:retryWaiterFrame = [string]$promptScreen.Frame
    $script:retryWaiterFrameClass = [string]$promptScreen.Class
    return [bool]$promptScreen.Prompt
}
function Invoke-RetryFlagStub {
    # HUD · 추적기 · 선택 화면 판독 - 캡처 실패면 거짓
    param([string]$Name, [string]$Field)
    $flagScreen = Invoke-RetryRead -Name $Name
    return (($null -ne $flagScreen) -and [bool]$flagScreen[$Field])
}
function Invoke-RetryPanelStub {
    # 패널 종류 - 행 패널 덮어쓰기(WA-S9 - 판독은 그대로 한 번 · 덮어쓰기는 판독 시작 시각에 판정) · 캡처 실패면 'none'(원문 Get-AbyssPanelKind 와 같음)
    $overrideKind = ''
    if ($null -ne $script:retryPanelOverride) { $overrideKind = "$(& $script:retryPanelOverride)" }
    $panelScreen = Invoke-RetryRead -Name 'panel'
    if ($overrideKind) { return $overrideKind }
    if ($null -eq $panelScreen) { return 'none' }
    return [string]$panelScreen.Panel
}
function Invoke-RetrySweepWrap {
    # 공용 스윕 - 합성 행은 §4 스윕 모의(실패 창 · 계획 - 판독 시작에 캡처 시도) 뒤 스윕 비용, 재생 행은 프레임의 스윕 참(퀘스트 보상 팝업 '확인' 모형 - 재생 틀과 같은 꼴)
    param($Game)
    if ($script:retryReplay) { return (Invoke-RetryReplaySweep) }
    $sweepResult = Invoke-SweepStub -Game $Game
    Step-VirtualClock $RETRY_COST.sweep
    return $sweepResult
}
function Invoke-RetryClickStub {
    # 클릭 기록 - 행 주입 순서(ClickOutcomes) > 조작 창 안이면 'user-active' 생략 > 커서 미확인 주입이 남았으면 'cursor-not-ready' 생략 > 전송(메타 둘을 씀) · 클릭 비용 ·
    #   부른 루프(클릭 루프 = retry · '다른 던전 가기' 대기 = other)로 갈라 그 전송 번호의 화면 전이를 시각표에 · retry 전송 뒤 예약 주입(WA-X3′ · K18 꼴)
    param([int]$ReferenceX, [int]$ReferenceY)
    $clickKind = $(if ($script:retryInClick -gt 0) { 'retry' } elseif ($script:retryInOther -gt 0) { 'other' } else { 'unknown' })
    $script:retryClickTries.Add([pscustomobject]@{ T = (Get-VirtualElapsed); Kind = $clickKind })
    Add-RetryEvent -Kind 'click'
    $clickOutcome = ''
    if ($script:retryClickOutcomes.Count -gt 0) { $clickOutcome = [string]$script:retryClickOutcomes[0]; $script:retryClickOutcomes.RemoveAt(0) }
    elseif ($null -ne (Get-ActiveWindowNow)) { $clickOutcome = 'user-active' }
    elseif ($script:retryCursorMisses -gt 0) { $script:retryCursorMisses--; $clickOutcome = 'cursor-not-ready' }
    else { $clickOutcome = 'sent' }
    Step-VirtualClock $RETRY_COST.click
    if ($clickOutcome -ne 'sent') { $script:lastClickPerformed = $false; $script:lastClickSkipReason = $clickOutcome; return }
    $script:lastClickPerformed = $true
    $script:lastClickSkipReason = ''
    $script:retryClicks.Add([pscustomobject]@{ T = (Get-VirtualElapsed); Kind = $clickKind; X = $ReferenceX; Y = $ReferenceY })
    $sendIndex = @($script:retryClicks | Where-Object { $_.Kind -eq $clickKind }).Count
    $sendTable = $(if ($clickKind -eq 'retry') { $script:retryOnRetrySend } else { $script:retryOnOtherSend })
    $sendSteps = $null
    if ($sendTable.ContainsKey($sendIndex)) { $sendSteps = $sendTable[$sendIndex] }
    elseif ($clickKind -eq 'other') { $sendSteps = $RETRY_OTHER_SEND_DEFAULT }
    foreach ($sendStep in @($sendSteps)) { if ($null -ne $sendStep) { Add-RetryPlan -At ((Get-VirtualElapsed) + [double]$sendStep[0]) -Screen ([string]$sendStep[1]) } }
    if (($clickKind -eq 'retry') -and ($script:retryF9OnRetrySend -eq $sendIndex)) { $script:safeStopFlagMock = $true }
}
$RETRY_OTHER_SEND_DEFAULT = @(,@(1.0, 'S'))   # '다른 던전 가기' 전송 뒤 1초에 선택 화면(시제품 연기 시험과 같은 전이 - 확인 창 첫 판독이 봄)
function Add-RetryEvent {
    # 사건 기록 (차례 판정 - RC6 · K 행): focus · attempt · safecheck · update · click · yield
    param([string]$Kind)
    $script:retryEvents.Add([pscustomobject]@{ T = (Get-VirtualElapsed); Kind = $Kind; InClick = ($script:retryInClick -gt 0) })
}
# 완료 기록(journal - 명세 2.2 · 설계 v11 R3 6.6 'journal 은 임시 폴더 실제 파일 · 실제 쓰기 직후 시계 훅' · 명세 리뷰 2 P2): 단계 쓰기 셋(retry-attempt · retry-clicked ·
#   reentered)과 저장소 묶음은 워커 원문 그대로이고, 행마다 임시 폴더의 새 실제 파일에 씁니다. 저장 경계 = Update-AbyssJournal - 같은 이름 감시(아래 모의 정의)가 차지하고 원문은
#   이름 바꿔 올립니다(Invoke-RealUpdateAbyssJournal). 감시는 부른 단계 쓰기 함수 · 받은 -Nonce · 가상 시각을 기록하고, 행이 그 단계에 주입한 'locked' / 'expect-failed' 만
#   파일을 건드리지 않고 그 태그로 돌려주며(그 밖 태그 주입은 하니스 오류 - 'changed' 는 실제 쓰기만), 아니면 원문 저장소가 실제로 쓴 직후 행의 시계 훅(AfterWrite - 단계별
#   초)이 가상 시계를 옮깁니다(K4 - 첫 retry-attempt 기록의 잠금 대기가 지정 시각을 넘김). 행은 파일 상태와 호출 수를 함께 봅니다(아래 J 행 · J0)
function Invoke-RetryStoreCall {
    # 저장 경계 감시 - 호출 스택 [2] = Update-AbyssJournal 을 부른 단계 쓰기 원문(감시 → 이 함수). 기록 시각 = 단계 쓰기 원문이 기록 시각으로 쓴 값(사이에 시계가 움직이지 않음)
    param($Bound)
    $writerFrame = @(Get-PSCallStack)[2]
    $writerName = [string]$writerFrame.FunctionName
    $storeStage = '?' + $writerName
    if ($writerName -ceq 'Set-AbyssJournalRetryAttempt') { $storeStage = 'retry-attempt' }
    elseif ($writerName -ceq 'Set-AbyssJournalRetryClicked') { $storeStage = 'retry-clicked' }
    elseif ($writerName -ceq 'Set-AbyssJournalReentered') { $storeStage = 'reentered' }
    $nonceSeen = $null
    if (($null -ne $writerFrame.InvocationInfo) -and $writerFrame.InvocationInfo.BoundParameters.ContainsKey('Nonce')) { $nonceSeen = [string]$writerFrame.InvocationInfo.BoundParameters['Nonce'] }
    $storeRecord = [pscustomobject]@{ T = (Get-VirtualElapsed); Stage = $storeStage; Nonce = $nonceSeen; At = (Get-Date).ToString('o'); Tag = ''; Injected = $false }
    $script:retryJournal.Add($storeRecord)
    if ($storeStage -eq 'retry-attempt') { Add-RetryEvent -Kind 'attempt' }
    if ($script:retryStoreInject.ContainsKey($storeStage) -and ($script:retryStoreInject[$storeStage].Count -gt 0)) {
        $injectTag = [string]$script:retryStoreInject[$storeStage][0]
        $script:retryStoreInject[$storeStage].RemoveAt(0)
        if (@('locked', 'expect-failed') -cnotcontains $injectTag) { throw "TEST: 저장 경계 주입은 'locked' · 'expect-failed' 만입니다 ($storeStage - $injectTag)" }
        $storeRecord.Tag = $injectTag
        $storeRecord.Injected = $true
        $script:retryStoreInjected++
        return @{ Tag = $injectTag; Warnings = @() }
    }
    $script:retryStoreDepth++
    try {
        $storeOut = Invoke-RealUpdateAbyssJournal @Bound
    } finally {
        $script:retryStoreDepth--
    }
    $storeRecord.Tag = [string]$storeOut.Tag
    $script:retryStoreWrites++
    if ($script:retryAfterWrite.ContainsKey($storeStage)) { Step-VirtualClock ([double]$script:retryAfterWrite[$storeStage]) }
    return $storeOut
}
function Write-RetryJournalSeed {
    # 행의 씨앗 journal(실제 파일) - 지난 판 항목(다른 nonce · reentered · done - 어느 행에서도 그대로여야 함) + 이 판 항목(행 nonce · 씨앗 단계). 항목은 원문 New-AbyssJournalEntry
    #   기본값 위에 비커스텀 retry 판의 클리어 기록 꼴(owner · nextOwner { runId } · decision retry · at.cleared)이고 씨앗 단계가 retry-attempt 면 그 기록까지 온 꼴(attempts 1 ·
    #   at.retryAttempt - test_abyss_journal_store.ps1 New-StageEntryJson 과 같은 값 표). 직렬화는 원문 ConvertTo-AbyssJournalText · UTF-8 BOM(저장소 임시 파일과 같은 인코딩)
    param([string]$Path, [string]$Stage)
    $seedTime = (Get-Date).ToString('o')
    $olderEntry = New-AbyssJournalEntry -Stage 'reentered'
    $olderEntry.nonce = $RETRY_OLDER_NONCE
    $olderEntry.runId = 'run-s10'
    $olderEntry.owner = [pscustomobject]@{ runId = 'run-s10' }
    $olderEntry.nextOwner = [pscustomobject]@{ runId = 'run-s10' }
    $olderEntry.decision = 'retry'
    $olderEntry.launchState = 'done'
    $olderEntry.attempts = 1
    $olderEntry.retryClicks = 1
    $olderEntry.at.cleared = $seedTime
    $olderEntry.at.retryAttempt = $seedTime
    $olderEntry.at.retryClicked = $seedTime
    $olderEntry.at.reentered = $seedTime
    $rowEntry = New-AbyssJournalEntry -Stage $Stage
    $rowEntry.nonce = $RETRY_NONCE
    $rowEntry.runId = 'run-s10'
    $rowEntry.owner = [pscustomobject]@{ runId = 'run-s10' }
    $rowEntry.nextOwner = [pscustomobject]@{ runId = 'run-s10' }
    $rowEntry.decision = 'retry'
    $rowEntry.at.cleared = $seedTime
    if ($Stage -ne 'cleared') { $rowEntry.attempts = 1; $rowEntry.at.retryAttempt = $seedTime }
    $seedJournal = New-AbyssJournalEmpty
    $seedJournal.seq = $RETRY_JOURNAL_SEED_SEQ
    $seedJournal.savedAt = $seedTime
    $seedJournal.entries = @($olderEntry, $rowEntry)
    [IO.File]::WriteAllText($Path, (ConvertTo-AbyssJournalText -Journal $seedJournal), (New-Object System.Text.UTF8Encoding($true)))
}
function Get-RetryJournalState {
    # 지금 행 폴더의 완료 기록 상태 - 본 파일을 그대로 파싱(저장소를 거치지 않음 - 읽기 복구 쓰기 0) · 이 판 항목 · 지난 판 항목 글자 · 항목 수 · 직전본 · 잠금 · 임시본
    $journalState = [pscustomobject]@{ Seq = [long]-1; SavedAt = ''; EntryCount = -1; Target = $null; OlderJson = ''; HasBak = $false; Leftovers = 0; Error = '' }
    try {
        $stateText = ([IO.File]::ReadAllText($script:abyssJournalPath, [Text.Encoding]::UTF8)).TrimStart([char]0xFEFF)
        $stateJournal = ConvertFrom-Json -InputObject $stateText
        $journalState.Seq = [long]$stateJournal.seq
        $journalState.SavedAt = [string]$stateJournal.savedAt
        $stateEntries = @($stateJournal.entries)
        $journalState.EntryCount = $stateEntries.Count
        $journalState.Target = @($stateEntries | Where-Object { [string]$_.nonce -ceq $RETRY_NONCE }) | Select-Object -First 1
        $olderEntries = @($stateEntries | Where-Object { [string]$_.nonce -ceq $RETRY_OLDER_NONCE })
        $journalState.OlderJson = $(if ($olderEntries.Count -eq 1) { ConvertTo-Json -InputObject $olderEntries[0] -Depth 10 -Compress } else { "(지난 판 항목 $($olderEntries.Count))" })
    } catch {
        $journalState.Error = [string]$_.Exception.Message
    }
    $journalState.HasBak = [IO.File]::Exists($script:abyssJournalPath + '.bak')
    $journalState.Leftovers = @([IO.Directory]::GetFiles($script:retryJournalDir) | Where-Object { @('abyss_handoff.json', 'abyss_handoff.json.bak') -cnotcontains [IO.Path]::GetFileName($_) }).Count
    return $journalState
}
function Format-RetryJournal {
    # J 행 글자 - '저장 경계 호출(단계:태그 - * = 행이 주입) | 이 판 항목 단계/attempts/retryClicks | seq N'
    param($State, $Records)
    $callText = $(if (@($Records).Count -gt 0) { (@($Records | ForEach-Object { '{0}:{1}{2}' -f $_.Stage, $_.Tag, $(if ($_.Injected) { '*' } else { '' }) })) -join ' ' } else { '(호출 0)' })
    $targetText = $(if ($null -ne $State.Target) { '{0}/{1}/{2}' -f $State.Target.stage, $State.Target.attempts, $State.Target.retryClicks } else { '(항목 없음)' })
    return ('{0} | {1} | seq {2}' -f $callText, $targetText, $State.Seq)
}
function Get-RetryJournalProblems {
    # J0 - 파일 상태 = 저장 경계 호출 기록 (열거용 - 호출부에서 @()): 실제 쓰기의 'changed' 만 파일을 바꿈(주입 · 그 밖 태그는 무변경) → seq = 씨앗 + changed 수 · savedAt = 마지막
    #   changed 호출의 가상 시각(실제 쓰기 직후 시계 훅이 쓰기 뒤라는 것 - 훅이 쓰기 앞이면 그만큼 늦음) · 이 판 항목 단계 = 마지막 changed 의 단계 · attempts / retryClicks = 씨앗 +
    #   그 단계 changed 수 · at.retryAttempt · retryClicked · reentered = 그 단계 마지막 changed 의 가상 시각(없으면 씨앗 값) · 이 판 항목의 그 밖 필드와 지난 판 항목은 씨앗 그대로 ·
    #   항목 2 · 잠금 · 임시본 0 · 직전본은 changed 가 있을 때만(File.Replace)
    param($Seed, $State, $Records)
    $problemList = New-Object System.Collections.Generic.List[string]
    if ($State.Error) { $problemList.Add('읽기 ' + $State.Error); return $problemList.ToArray() }
    $changedRecords = @($Records | Where-Object { (-not $_.Injected) -and ($_.Tag -ceq 'changed') })
    $lastChanged = $(if ($changedRecords.Count -gt 0) { $changedRecords[$changedRecords.Count - 1] } else { $null })
    if ($State.Seq -ne ($Seed.Seq + $changedRecords.Count)) { $problemList.Add(('seq {0} ≠ {1}' -f $State.Seq, ($Seed.Seq + $changedRecords.Count))) }
    $wantSavedAt = $(if ($null -ne $lastChanged) { [string]$lastChanged.At } else { [string]$Seed.SavedAt })
    if ($State.SavedAt -cne $wantSavedAt) { $problemList.Add(('savedAt {0} ≠ {1}' -f $State.SavedAt, $wantSavedAt)) }
    if ($State.EntryCount -ne 2) { $problemList.Add(('항목 {0}' -f $State.EntryCount)) }
    if ($State.OlderJson -cne $Seed.OlderJson) { $problemList.Add('지난 판 항목 바뀜') }
    if ($State.Leftovers -ne 0) { $problemList.Add(('잠금 · 임시본 {0}' -f $State.Leftovers)) }
    if ($State.HasBak -ne ($changedRecords.Count -gt 0)) { $problemList.Add(('직전본 {0}' -f $State.HasBak)) }
    if (($null -eq $State.Target) -or ($null -eq $Seed.Target)) { $problemList.Add('이 판 항목 없음'); return $problemList.ToArray() }
    $wantStage = $(if ($null -ne $lastChanged) { [string]$lastChanged.Stage } else { [string]$Seed.Target.stage })
    if ([string]$State.Target.stage -cne $wantStage) { $problemList.Add(('단계 {0} ≠ {1}' -f $State.Target.stage, $wantStage)) }
    $wantAttempts = [int]$Seed.Target.attempts + @($changedRecords | Where-Object { $_.Stage -eq 'retry-attempt' }).Count
    $wantClicks = [int]$Seed.Target.retryClicks + @($changedRecords | Where-Object { $_.Stage -eq 'retry-clicked' }).Count
    if (([int]$State.Target.attempts -ne $wantAttempts) -or ([int]$State.Target.retryClicks -ne $wantClicks)) { $problemList.Add(('횟수 {0}/{1} ≠ {2}/{3}' -f $State.Target.attempts, $State.Target.retryClicks, $wantAttempts, $wantClicks)) }
    foreach ($timeField in @(@('retry-attempt', 'retryAttempt'), @('retry-clicked', 'retryClicked'), @('reentered', 'reentered'))) {
        $fieldChanged = @($changedRecords | Where-Object { $_.Stage -eq $timeField[0] })
        $wantAt = $(if ($fieldChanged.Count -gt 0) { [string]$fieldChanged[$fieldChanged.Count - 1].At } else { [string]$Seed.Target.at.($timeField[1]) })
        if ([string]$State.Target.at.($timeField[1]) -cne $wantAt) { $problemList.Add(('at.{0} {1} ≠ {2}' -f $timeField[1], $State.Target.at.($timeField[1]), $wantAt)) }
    }
    $expectTarget = ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $Seed.Target -Depth 10 -Compress)
    foreach ($copyField in @('stage', 'attempts', 'retryClicks')) { $expectTarget.$copyField = $State.Target.$copyField }
    foreach ($copyAt in @('retryAttempt', 'retryClicked', 'reentered')) { $expectTarget.at.$copyAt = $State.Target.at.$copyAt }
    if ((ConvertTo-Json -InputObject $State.Target -Depth 10 -Compress) -cne (ConvertTo-Json -InputObject $expectTarget -Depth 10 -Compress)) { $problemList.Add('이 판 항목의 그 밖 필드 바뀜') }
    return $problemList.ToArray()
}
function Invoke-RetryReentryCall {
    # Wait-AbyssReentry 감시 - 호출 기록(시각 · 한도 · 보고 · 문맥) · 행 결과 스텁(차례대로 - Advance 초만큼 시계 · SetF9 이면 예약) 또는 원문(이름 바꿔 올린 대기)
    param($Bound)
    $reentryRecord = [pscustomobject]@{ T = (Get-VirtualElapsed); Limit = [int]$Bound['LimitSeconds']; Report = [bool]$Bound['ReportRewardReturn']; ReportField = [bool]$Bound['ReportFieldReturn']; Context = [string]$Bound['Context']; Result = ''; End = $null }
    $script:retryReentryCalls.Add($reentryRecord)
    if ($null -ne $script:retryReentryStubs) {
        if ($script:retryReentryStubs.Count -lt 1) { throw 'TEST: 재입장 대기 결과 스텁이 모자랍니다' }
        $reentryStub = $script:retryReentryStubs[0]
        $script:retryReentryStubs.RemoveAt(0)
        if ($null -ne $reentryStub.Advance) { Step-VirtualClock ([double]$reentryStub.Advance) }
        if ([bool]$reentryStub.SetF9) { $script:safeStopFlagMock = $true }
        $reentryRecord.Result = [string]$reentryStub.Result
        $reentryRecord.End = Get-VirtualElapsed
        return @{ Result = [string]$reentryStub.Result; LastKind = [string]$reentryStub.LastKind; PanelSeen = [bool]$reentryStub.PanelSeen }
    }
    $script:retryInWaiter++
    try {
        $reentryOut = Invoke-RealWaitAbyssReentry @Bound
    } finally {
        $script:retryInWaiter--
    }
    $reentryRecord.Result = [string]$reentryOut.Result
    $reentryRecord.End = Get-VirtualElapsed
    return $reentryOut
}
function Invoke-RetryOtherWaitCall {
    # '다른 던전 가기' 대기 감시 - 호출 수 · 행 결과 스텁 또는 원문(§9 의 이름 바꿔 올린 대기)
    param($Bound)
    $script:retryOtherWaitCalls++
    if ($null -ne $script:retryOtherStub) { return $script:retryOtherStub }
    $script:retryInOther++
    try {
        return (Invoke-RealWaitAbyssOtherSelection @Bound)
    } finally {
        $script:retryInOther--
    }
}
function Invoke-RetryClickLoopCall {
    # 클릭 루프 감시 - 호출 수 · '클릭 루프 안' 표식(짝 판독 · 클릭 기록이 부른 루프를 가름) · 원문으로 넘김
    param($Bound)
    $script:retryClickLoopCalls++
    $script:retryInClick++
    try {
        return (Invoke-RealAbyssRetryClick @Bound)
    } finally {
        $script:retryInClick--
    }
}
function Invoke-RetryTestPathStub {
    # 안전 중지 파일 확인 - 클릭 루프 안 확인을 사건으로 기록 (§4 모의와 같은 답)
    param($LiteralPath)
    # 클릭 루프가 직접 부른 확인만 사건으로 (동결 블록의 원문 안전 확인이 부른 것은 빼고 - 호출 스택 [2] = Test-Path 를 부른 함수)
    if ((@(Get-PSCallStack).Count -ge 3) -and ([string](Get-PSCallStack)[2].FunctionName -ceq 'Invoke-RealAbyssRetryClick')) { Add-RetryEvent -Kind 'safecheck' }
    if ([string]$LiteralPath -eq $safeStopFlagPath) { return [bool]$script:safeStopFlagMock }
    return $false
}
# 완료 기록 원문 올림 - 단계 쓰기 셋 · 저장소 묶음(사본 재구현 금지). 저장 경계 Update-AbyssJournal 은 이름 바꿔 올리고 같은 이름은 아래 모의 정의의 감시가 차지합니다(§3 의
#   기록 모의를 바꿈). 올린 함수가 부르는 워커 함수는 이 목록 · 저장 경계 · Write-RunLog(§3 모의)뿐이어야 합니다 - 그 밖이 생기면 'FAIL 준비'(목록을 함께 손볼 것). 단계 쓰기
#   원문의 클로저(Expect · Mutator)가 부르는 Set-AbyssJournalProperty 는 최상위 정의만 보이므로 여기(최상위)에서 올립니다(test_abyss_journal_store.ps1 머리 주석과 같은 이유)
$RETRY_JOURNAL_NAMES = @('Set-AbyssJournalRetryAttempt', 'Set-AbyssJournalRetryClicked', 'Set-AbyssJournalReentered', 'New-AbyssJournalEmpty', 'New-AbyssJournalEntry',
    'Get-AbyssJournalTimeText', 'Set-AbyssJournalProperty', 'Test-AbyssJournalShape', 'ConvertTo-AbyssJournalNormalized', 'ConvertTo-AbyssJournalText', 'New-AbyssJournalTempPath',
    'Write-AbyssJournalTempFile', 'Remove-AbyssJournalFileQuietly', 'Step-AbyssJournalBudget', 'Open-AbyssJournalLock', 'Read-AbyssJournalCandidate', 'Read-AbyssJournalUnlocked',
    'Read-AbyssJournalHeld')
$retryJournalKnown = @($RETRY_JOURNAL_NAMES + @('Update-AbyssJournal', 'Write-RunLog'))
$retryJournalOutside = @(foreach ($journalName in @($RETRY_JOURNAL_NAMES + @('Update-AbyssJournal'))) {
        if (-not $workerFunctions.ContainsKey($journalName)) { "$journalName(워커에 없음)"; continue }
        foreach ($journalCallee in $workerFunctions[$journalName].FindAll({ param($candidate) $candidate -is [CommandAst] }, $true)) {
            $journalCalleeName = [string]$journalCallee.GetCommandName()
            if ($workerFunctions.ContainsKey($journalCalleeName) -and ($retryJournalKnown -notcontains $journalCalleeName)) { '{0}→{1}' -f $journalName, $journalCalleeName }
        }
    })
if ($retryJournalOutside.Count -gt 0) { "FAIL 준비: ⑤b4 완료 기록 원문이 목록 밖 워커 함수를 부릅니다 ($($retryJournalOutside -join ' · ') - 명세 2.2)"; exit 1 }
try {
    foreach ($journalName in $RETRY_JOURNAL_NAMES) { Invoke-Expression ([string]$workerFunctions[$journalName].Extent.Text) }
    Invoke-Expression (([string]$workerFunctions['Update-AbyssJournal'].Extent.Text) -replace '^function Update-AbyssJournal\b', 'function Invoke-RealUpdateAbyssJournal')
} catch {
    "FAIL 준비: ⑤b4 완료 기록 원문을 올리지 못했습니다 ($($_.Exception.Message))"
    exit 1
}
$script:retryStoreDepth = 0
$script:retryStoreSleeps = 0
$script:retryStoreWrites = 0
$script:retryStoreInjected = 0
$script:retryStoreInject = @{}
$script:retryAfterWrite = @{}
# 저장소 원문의 재시도 대기(Step-AbyssJournalBudget 50ms)는 가상 시계 밖입니다 - 저장 경계 감시 안(원문 저장소 실행 중)의 Start-Sleep 은 실제로 자고(셈만) 가상 시계 · 사건 기록을
#   건드리지 않습니다. 그 밖은 §4 모의 그대로(§4 의 몸통으로 넘김 - 동작 같음)
$RETRY_BASE_START_SLEEP = ${function:Start-Sleep}
function Start-Sleep {
    param([int]$Seconds = 0, [int]$Milliseconds = 0)
    if ($script:retryStoreDepth -gt 0) {
        $script:retryStoreSleeps++
        Microsoft.PowerShell.Utility\Start-Sleep -Milliseconds ($Seconds * 1000 + $Milliseconds)
        return
    }
    & $RETRY_BASE_START_SLEEP -Seconds $Seconds -Milliseconds $Milliseconds
}
# 행마다 새 폴더(임시 폴더 아래 이 실행 전용 - 끝에서 지움)
$RETRY_JOURNAL_ROOT = Join-Path ([IO.Path]::GetTempPath()) ('honeynogi_s10_journal_' + [guid]::NewGuid().ToString('N'))
$script:retryRowSerial = 0
try {
    [void][IO.Directory]::CreateDirectory($RETRY_JOURNAL_ROOT)
} catch {
    "FAIL 준비: ⑤b4 완료 기록 임시 폴더를 만들지 못했습니다 ($($_.Exception.Message))"
    exit 1
}
# 모의 정의 - 원문 param 블록 그대로 + 스텁 몸통 (§3 New-MockDefinition). §9 행이 끝난 뒤라 같은 이름의 §3 · §9 모의를 이 절의 스텁으로 바꿉니다
$RETRY_STUB_BODIES = [ordered]@{
    'Find-AbyssRewardButtonPair'   = 'return (Invoke-RetryPairStub)'
    'Test-DungeonClearPrompt'      = 'return (Invoke-RetryPromptStub)'
    'Test-HomeEndEscHud'           = 'return (Invoke-RetryFlagStub -Name ''hud'' -Field ''Hud'')'
    'Test-InDungeonQuest'          = 'return (Invoke-RetryFlagStub -Name ''quest'' -Field ''Quest'')'
    'Test-AbyssSelectionScreen'    = 'return (Invoke-RetryFlagStub -Name ''selection'' -Field ''Selection'')'
    'Test-AbyssMenu'               = 'return (Invoke-RetryFlagStub -Name ''menu'' -Field ''Menu'')'   # 구현 단위 5b-8 2.2-4a (필드 결과 켬의 필드 모양 회전만)
    'Get-AbyssPanelKind'           = 'return (Invoke-RetryPanelStub)'
    'Invoke-PurchasePopupSweep'    = 'return (Invoke-RetrySweepWrap -Game $Game)'
    'Click-GamePoint'              = 'Invoke-RetryClickStub -ReferenceX $ReferenceX -ReferenceY $ReferenceY'
    'Focus-Game'                   = 'Add-RetryEvent -Kind ''focus''; Step-VirtualClock $RETRY_COST.focus'
    'Wait-UserYieldEnd'            = 'Add-RetryEvent -Kind ''yield''; Invoke-YieldStub -Game $Game -Context $Context'
    'Update-AbyssJournal'          = 'return (Invoke-RetryStoreCall -Bound $PSBoundParameters)'
    'Wait-AbyssReentry'            = 'return (Invoke-RetryReentryCall -Bound $PSBoundParameters)'
    'Wait-AbyssOtherSelection'     = 'return (Invoke-RetryOtherWaitCall -Bound $PSBoundParameters)'
    'Invoke-AbyssRetryClick'       = 'return (Invoke-RetryClickLoopCall -Bound $PSBoundParameters)'
    'Get-DgTimeVerdict'            = '$script:retryDgCalls++; return (Invoke-RealGetDgTimeVerdict -UntilTime $UntilTime -Now $Now)'
    'Update-AbyssRetryTimeVerdict' = '$script:retryUpdateCalls++; Add-RetryEvent -Kind ''update''; return (Invoke-RealUpdateAbyssRetryTimeVerdict)'
}
try {
    foreach ($retryStubEntry in $RETRY_STUB_BODIES.GetEnumerator()) { Invoke-Expression (New-MockDefinition -Name $retryStubEntry.Key -Body $retryStubEntry.Value) }
} catch {
    "FAIL 준비: ⑤b4 모의 정의 실패 ($($_.Exception.Message))"
    exit 1
}
function Test-Path {
    param($LiteralPath, $Path, $PathType)
    return (Invoke-RetryTestPathStub -LiteralPath $LiteralPath)
}
$retrySignatureMismatches = @(@($RETRY_STUB_BODIES.Keys) | Where-Object { (Get-LiveParamSignature $_) -cne (Get-ParamSignature $_) } | ForEach-Object { '{0}: 원문 [{1}] / 모의 [{2}]' -f $_, (Get-ParamSignature $_), (Get-LiveParamSignature $_) })
if ($retrySignatureMismatches.Count -gt 0) { "FAIL 준비: ⑤b4 모의 서명이 워커 원문과 다릅니다 ($($retrySignatureMismatches -join ' · '))"; exit 1 }
# 준비 단언 - 씨앗 journal 이 저장소 원문의 읽기 규칙상 유효(본 파일 채택 (a) · 항목 2 · 이 판 항목 cleared): 행의 실제 파일이 원문 저장소가 읽는 꼴인지
$script:retryJournalDir = Join-Path $RETRY_JOURNAL_ROOT 'seedcheck'
[void][IO.Directory]::CreateDirectory($script:retryJournalDir)
$script:abyssJournalPath = Join-Path $script:retryJournalDir 'abyss_handoff.json'
Write-RetryJournalSeed -Path $script:abyssJournalPath -Stage 'cleared'
$retrySeedRead = Read-AbyssJournalUnlocked -Path $script:abyssJournalPath
$retrySeedShape = '{0}/{1}/{2}/{3}' -f $retrySeedRead.Status, $retrySeedRead.Branch, @($retrySeedRead.Journal.entries).Count, ((@($retrySeedRead.Journal.entries | Where-Object { [string]$_.nonce -ceq $RETRY_NONCE }) | ForEach-Object { [string]$_.stage }) -join ',')
if ($retrySeedShape -cne 'ok/a/2/cleared') { "FAIL 준비: ⑤b4 씨앗 journal 이 저장소 원문 읽기 규칙과 맞지 않습니다 ($retrySeedShape - 기대 ok/a/2/cleared)"; exit 1 }
function Reset-RetryRow {
    # 행 시작 상태 - §4 · §9 의 행 시작(캡처 · 양보 · 스윕 · 실패 창 · 조작 창 · 기록 · 묵은 클릭 메타 · 헬퍼 · 복귀 루프 · 진단)을 그대로 쓰고 §10 상태를 비운 뒤 행 명세를 세웁니다.
    #   ⓪ 의 셋(판단값 · commit 표지 · 첫 시도 표식)과 지정 시각 · 이어받기 역할은 5b-5 자리라 행 입력입니다(앞 행 값이 새지 않게 매 행 다시 둠 - 명세 2.2)
    param([hashtable]$Spec)
    Reset-OtherWaitRow -Spec @{}
    if ($Spec.Start) { $script:caseStart = [datetime]$Spec.Start; $script:vclock = $script:caseStart }
    $script:retryReplay = $false
    $script:retryPlan = @()
    $script:retryPlanSeq = 0
    foreach ($planStep in @($Spec.Timeline)) { if ($null -ne $planStep) { Add-RetryPlan -At ([double]$planStep[0]) -Screen ([string]$planStep[1]) } }
    # 배열·해시는 $( ) 로 받지 않고 대입으로만 (원소 하나짜리 단계 목록이 풀리지 않게 - PS 5.1)
    if ($null -ne $Spec.RetrySend) { $script:retryOnRetrySend = $Spec.RetrySend } else { $script:retryOnRetrySend = @{} }
    if ($null -ne $Spec.OtherSend) { $script:retryOnOtherSend = $Spec.OtherSend } else { $script:retryOnOtherSend = @{} }
    if ($null -ne $Spec.PairReadScreens) { $script:retryPairOverride = $Spec.PairReadScreens } else { $script:retryPairOverride = @{} }
    foreach ($failWindow in @($Spec.Fail)) { if ($null -ne $failWindow) { Add-FailWindow ([double]$failWindow[0]) ([double]$failWindow[1]) } }
    if ($null -ne $Spec.FailPeriodic) { Set-FailPeriodic ([double]$Spec.FailPeriodic[0]) ([double]$Spec.FailPeriodic[1]) ([double]$Spec.FailPeriodic[2]) }
    foreach ($activeWindow in @($Spec.Active)) { if ($null -ne $activeWindow) { Add-ActiveWindow ([double]$activeWindow[0]) ([double]$activeWindow[1]) } }
    foreach ($sweepPlan in @($Spec.Sweep)) { if ($null -ne $sweepPlan) { Set-SweepFrom @sweepPlan } }
    $script:retryClickOutcomes = New-Object System.Collections.ArrayList
    foreach ($clickOutcome in @($Spec.ClickOutcomes)) { if ($null -ne $clickOutcome) { [void]$script:retryClickOutcomes.Add([string]$clickOutcome) } }
    $script:retryCursorMisses = [int]$Spec.CursorMisses
    # 완료 기록 - 저장 경계 주입(StoreInject = @{ 단계 = 태그 차례 } - 'locked' · 'expect-failed' 만) · 실제 쓰기 직후 시계 훅(AfterWrite = @{ 단계 = 초 })
    $script:retryStoreInject = @{}
    if ($null -ne $Spec.StoreInject) {
        foreach ($injectStage in @($Spec.StoreInject.Keys)) {
            $injectList = New-Object System.Collections.ArrayList
            foreach ($injectTag in @($Spec.StoreInject[$injectStage])) { if ($null -ne $injectTag) { [void]$injectList.Add([string]$injectTag) } }
            $script:retryStoreInject[[string]$injectStage] = $injectList
        }
    }
    $script:retryAfterWrite = @{}
    if ($null -ne $Spec.AfterWrite) { foreach ($writeStage in @($Spec.AfterWrite.Keys)) { $script:retryAfterWrite[[string]$writeStage] = [double]$Spec.AfterWrite[$writeStage] } }
    $script:retryReadHook = $Spec.ReadHook
    $script:retryPanelOverride = $Spec.PanelOverride
    $script:clockHooks = @(@($Spec.TimeHooks) | Where-Object { $null -ne $_ })
    $script:retryF9OnRetrySend = [int]$Spec.F9OnRetrySend
    if ($null -ne $Spec.ReentryStubs) {
        $script:retryReentryStubs = New-Object System.Collections.ArrayList
        foreach ($reentryStub in @($Spec.ReentryStubs)) { [void]$script:retryReentryStubs.Add($reentryStub) }
    } else { $script:retryReentryStubs = $null }
    $script:retryOtherStub = $Spec.OtherStub
    $script:otherWaitHelperResult = $(if ($Spec.HelperResult) { [string]$Spec.HelperResult } else { 'clicked' })
    $script:otherWaitHelperExit = $null
    $script:safeStopFlagMock = [bool]$Spec.F9
    # ⓪ (행 입력 - 5b-5 의 실제 자리가 다시 돌림)
    $script:dungeonMode = $(if ($Spec.Mode) { [string]$Spec.Mode } else { 'solo' })
    # 다시 하기 경로의 운용 전제 - 함께하기 판은 매칭이 늘 '우연한 만남'(Test-AbyssRetryRoute). 이 절이 도는 함수는 이 값을 읽지 않지만, 그 전제로 가드한 코드도 행이
    #   실행하게 세웁니다(구현 리뷰 2/2 의 4/5 독립 검토 - 세우지 않던 판은 우연한 만남 가드 + 리터럴 없는 조건의 break · 추가 '[완료]' 줄 · 결과 재대입이 ④ 를 통과, 변이 M86~M88)
    $script:abyssMatching = $(if ($script:dungeonMode -eq 'party') { '우연한 만남' } else { '' })
    $script:abyssRetryTimeVerdict = [string]$Spec.Verdict0
    $script:abyssRetryCommitted = $false
    $script:abyssRetryAttemptRecorded = [bool]$Spec.Recorded0
    $script:abyssUntil = $(if ($null -ne $Spec.UntilAt) { [datetime]$Spec.UntilAt } elseif ($null -ne $Spec.Until) { $script:caseStart.AddTicks((ConvertTo-Ticks ([double]$Spec.Until))) } else { $null })
    $script:handoff = @{ Role = $(if ($Spec.Role) { [string]$Spec.Role } else { 'none' }); Nonce = '' }
    # 완료 기록 씨앗 - 행마다 새 폴더의 실제 파일. 씨앗 단계 = 원 워커의 전제(이 판의 클리어 기록 'cleared') / 끝(other) 들머리에서 이 워커의 retry-attempt 기록이 있다고 둔 행
    #   (Recorded0) · 이어받기 재개(Role resume)는 retry-attempt 까지 온 항목(그 행의 재입장 완료 기록이 원문 -Expect 를 지남)
    $seedStage = $(if ([bool]$Spec.Recorded0 -or ([string]$Spec.Role -eq 'resume')) { 'retry-attempt' } else { 'cleared' })
    $script:retryRowSerial++
    $script:retryJournalDir = Join-Path $RETRY_JOURNAL_ROOT ('row{0:D4}' -f $script:retryRowSerial)
    [void][IO.Directory]::CreateDirectory($script:retryJournalDir)
    $script:abyssJournalPath = Join-Path $script:retryJournalDir 'abyss_handoff.json'
    Write-RetryJournalSeed -Path $script:abyssJournalPath -Stage $seedStage
    $script:retryJournalSeedState = Get-RetryJournalState
    # 기록
    $script:retryReads = New-Object System.Collections.Generic.List[object]
    $script:retryClicks = New-Object System.Collections.Generic.List[object]
    $script:retryClickTries = New-Object System.Collections.Generic.List[object]
    $script:retryJournal = New-Object System.Collections.Generic.List[object]
    $script:retryEvents = New-Object System.Collections.Generic.List[object]
    $script:retryReentryCalls = New-Object System.Collections.Generic.List[object]
    $script:retryOtherWaitCalls = 0
    $script:retryClickLoopCalls = 0
    $script:retryDgCalls = 0
    $script:retryUpdateCalls = 0
    $script:retryPairCount = 0
    $script:retryInClick = 0
    $script:retryInOther = 0
    $script:retryInWaiter = 0
    $script:retryWaiterFrame = ''
    $script:retryWaiterFrameClass = ''
    $script:retryWaiterSamples = New-Object System.Collections.Generic.List[object]
    $script:retryHookDone = $false
}
function Invoke-RetryRow {
    # 행 실행기 - 들머리(retry = 끝(retry) · other = 끝(other) · click = 클릭 루프만) · 결과(반환 · exit 센티널 · 그 밖 예외)와 기록을 묶어 돌려줍니다
    param([hashtable]$Spec)
    Reset-RetryRow -Spec $Spec
    $rowExit = ''
    $rowError = ''
    $rowReturn = ''
    $rowClickResult = ''
    $rowClickLast = ''
    $rowShape = ''
    $entry = $(if ($Spec.Entry) { [string]$Spec.Entry } else { 'retry' })
    try {
        if ($entry -eq 'retry') {
            $retryOut = @(Complete-AbyssRetrySelection -Game $null -Nonce $RETRY_NONCE)
            $rowReturn = ($retryOut | ForEach-Object { [string]$_ }) -join ','
        } elseif ($entry -eq 'other') {
            $ending = $(if ($Spec.Ending) { [string]$Spec.Ending } else { 'ready' })
            $null = Complete-AbyssOtherSelection -Game $null -Ending $ending -Nonce $RETRY_NONCE
        } else {
            $clickOut = @(Invoke-AbyssRetryClick -Game $null -Nonce $RETRY_NONCE)
            if (($clickOut.Count -eq 1) -and ($clickOut[0] -is [hashtable])) {
                $rowShape = (@($clickOut[0].Keys | ForEach-Object { [string]$_ } | Sort-Object) -join ',')
                $rowClickResult = [string]$clickOut[0]['Result']
                $rowClickLast = [string]$clickOut[0]['LastKind']
            } else { $rowClickResult = 'OUT:' + $clickOut.Count }
        }
    } catch {
        $caught = [string]$_.Exception.Message
        if ($caught.StartsWith('__EXIT__')) { $rowExit = $caught } else { $rowError = $caught }
    }
    $rowLogs = $script:rowLogs.ToArray()
    $lastLog = $(if ($rowLogs.Count -gt 0) { [string]$rowLogs[$rowLogs.Count - 1] } else { '' })
    $journalState = Get-RetryJournalState
    $journalRecords = $script:retryJournal.ToArray()
    return [pscustomobject]@{
        JournalText = (Format-RetryJournal -State $journalState -Records $journalRecords); JournalProblems = @(Get-RetryJournalProblems -Seed $script:retryJournalSeedState -State $journalState -Records $journalRecords)
        Exit = $rowExit; Error = $rowError; Return = $rowReturn; Click = $rowClickResult; ClickLast = $rowClickLast; Shape = $rowShape; T = (Get-VirtualElapsed)
        Logs = $rowLogs; Last = $lastLog
        Clicks = $script:retryClicks.ToArray(); RetrySends = @($script:retryClicks | Where-Object { $_.Kind -eq 'retry' }).Count; OtherSends = @($script:retryClicks | Where-Object { $_.Kind -eq 'other' }).Count
        RetryTries = @($script:retryClickTries | Where-Object { $_.Kind -eq 'retry' }).Count
        Attempts = @($script:retryJournal | Where-Object { $_.Stage -eq 'retry-attempt' }).Count; Clickeds = @($script:retryJournal | Where-Object { $_.Stage -eq 'retry-clicked' }).Count
        Reentereds = @($script:retryJournal | Where-Object { $_.Stage -eq 'reentered' }).Count; Journal = $script:retryJournal.ToArray()
        Reentry = $script:retryReentryCalls.ToArray(); OtherWaits = $script:retryOtherWaitCalls; ClickLoops = $script:retryClickLoopCalls
        DgCalls = $script:retryDgCalls; UpdateCalls = $script:retryUpdateCalls; Events = $script:retryEvents.ToArray()
        Diags = $script:otherWaitDiagnostics.Count; Helper = $script:otherWaitHelperCalls.Count; Return2 = ($script:otherWaitReturnCalls -join ',')
        Removed = $script:safeStopRemoves; FlagEnd = [bool]$script:safeStopFlagMock
        Yields = $script:yieldCalls; Probes = $script:probeCalls; Safe = $script:safeStopCalls; FailMs = [double](Get-CaptureFailTotalMs)
        PairTimes = @($script:retryReads | Where-Object { $_.Name -eq 'pair' } | ForEach-Object { [double]$_.T })
        ClickPairTimes = @($script:retryReads | Where-Object { ($_.Name -eq 'pair') -and $_.InClick } | ForEach-Object { [double]$_.T })
        MissFirst = @($rowLogs | Where-Object { $_.StartsWith($RETRY_LINE_MISS_FIRST_PREFIX, [StringComparison]::Ordinal) }).Count
        MissEnd = @($rowLogs | Where-Object { $_.StartsWith($RETRY_LINE_MISS_END_PREFIX, [StringComparison]::Ordinal) }).Count
        Reclicks = @($rowLogs | Where-Object { $_ -ceq $RETRY_LINE_RECLICK }).Count; Twice = @($rowLogs | Where-Object { $_ -ceq $RETRY_LINE_TWICE }).Count
        CursorLines = @($rowLogs | Where-Object { $_ -ceq $RETRY_LINE_CURSOR }).Count; SafeLines = @($rowLogs | Where-Object { $_ -ceq $RETRY_LINE_SAFE }).Count
        LastLines = @($rowLogs | Where-Object { $_.StartsWith("[어비스] '다시 하기' 직전 판단: 지정 시간 ", [StringComparison]::Ordinal) }).Count
        ContinueLines = @($rowLogs | Where-Object { $_.StartsWith('[어비스] 지정 시간 ', [StringComparison]::Ordinal) -and $_.Contains("전에 '다시 하기'로 이어 가기로 정했습니다") }).Count
        IhLines = @($rowLogs | Where-Object { $_.Contains('[terminal=InsideHandoff') }).Count
        PanelLines = @($rowLogs | Where-Object { $_ -ceq $RETRY_LINE_PANEL_NOTICE }).Count                       # 구현 단위 5b-8 - 재매칭 패널 확인 안내
        SettleLines = @($rowLogs | Where-Object { $_ -cmatch $SETTLE_PATTERN }).Count                             # 필드 확정 줄
        DoneLines = @($rowLogs | Where-Object { $_.StartsWith('[완료]', [StringComparison]::Ordinal) }).Count      # '[완료]' 줄 총수(구현 리뷰 2/2 의 4/5 - 정지 끝은 정지 줄 하나)
        Inputs = (Get-OtherEventCalls) + [int]$script:recordMockCalls['Click-ScreenPoint'] + [int]$script:recordMockCalls['Invoke-ClickUntil']   # 키 · 이벤트 정리 · 화면 좌표 클릭 · 클릭 반복(게임 좌표 클릭은 Clicks)
        WaiterHud = @($script:retryReads | Where-Object { $_.InWaiter -and ($_.Name -eq 'hud') } | ForEach-Object { [pscustomobject]@{ T = [double]$_.T; Frame = [string]$_.Frame } })
    }
}
function Format-RetryRow {
    param($Row)
    $clickText = (@($Row.Clicks | ForEach-Object { '{0}({1},{2})@{3}' -f $_.Kind, $_.X, $_.Y, (Format-Seconds $_.T) }) -join ' ')
    $reentryText = (@($Row.Reentry | ForEach-Object { '{0}/{1}{2}{3}@{4}' -f $_.Result, $_.Limit, $(if ($_.Report) { '(보고)' } else { '' }), $(if ($_.ReportField) { '(필드)' } else { '' }), (Format-Seconds $_.T) }) -join ' ')
    $eventText = (@($Row.Events | Select-Object -First 24 | ForEach-Object { '{0}{1}' -f $_.Kind, $(if ($_.InClick) { '' } else { '°' }) }) -join ',')
    return ('exit={0} 오류=[{1}] 반환=[{2}] 클릭 루프=[{3}|{4}|{5}] T={6} 클릭=[{7}] retry 시도={8} 기록 a/c/r={9}/{10}/{11} 재입장 대기=[{12}] other 대기={13} Dg={14} 재판단={15} 진단={16} 헬퍼={17} 복귀=[{18}] 소비={19} 예약 끝={20} 양보={21} 탐침={22} 안전={23} 짝 판독=[{24}] 첫 줄={25} 짝 없음 줄={26} 사건=[{27}] 마지막=[{28}] 완료 기록=[{29}] [완료] 줄={30} 입력={31} 패널 줄={32} 확정 줄={33}' -f
        $Row.Exit, $Row.Error, $Row.Return, $Row.Click, $Row.ClickLast, $Row.Shape, (Format-Seconds $Row.T), $clickText, $Row.RetryTries, $Row.Attempts, $Row.Clickeds, $Row.Reentereds,
        $reentryText, $Row.OtherWaits, $Row.DgCalls, $Row.UpdateCalls, $Row.Diags, $Row.Helper, $Row.Return2, $Row.Removed, $Row.FlagEnd, $Row.Yields, $Row.Probes, $Row.Safe,
        ((@($Row.PairTimes | Select-Object -First 14 | ForEach-Object { Format-Seconds $_ })) -join ' '), $Row.MissFirst, $Row.MissEnd, $eventText, $Row.Last, $Row.JournalText,
        $Row.DoneLines, $Row.Inputs, $Row.PanelLines, $Row.SettleLines)   # 뒤 넷 - 구현 단위 5b-8 행 결과(구현 리뷰 2/2 의 4/5 독립 검토 - 실패 줄에서 원인이 보이게)
}
function Get-RetryClickText { param($Row) return ((@($Row.Clicks | ForEach-Object { '{0}({1},{2})' -f $_.Kind, $_.X, $_.Y })) -join ',') }
function Get-RetryFirstClick { param($Row, [string]$Kind = 'retry') $kindClicks = @($Row.Clicks | Where-Object { $_.Kind -eq $Kind }); if ($kindClicks.Count -lt 1) { return [double]-1 }; return [double]$kindClicks[0].T }
function Get-RetryUntilClock { param($Row) return $script:abyssUntil }
function Test-RetryNonce {
    # RC8 - 기록 셋의 nonce 와 재입장 완료 줄의 nonce 가 행 nonce 와 같음
    param($Row)
    return ((@($Row.Journal | Where-Object { $_.Nonce -cne $RETRY_NONCE }).Count -eq 0) -and (@($Row.Logs | Where-Object { $_.Contains('[terminal=InsideHandoff') -and (-not $_.EndsWith(('nonce=' + $RETRY_NONCE + ']'), [StringComparison]::Ordinal)) }).Count -eq 0))
}
function Test-RetryDeadlineTurnPair {
    # 경계 행 전제(RC1g · RC1h): 클릭 루프의 마지막 짝 판독 회전이 마감 회전(그 회전 마감 판정 ≥ L)이고 그 앞 짝 판독 회전은 마감 전(< L) - 하니스 비용 상수 · 소스 캡처 L 로 셈
    param($Row)
    $clickPairTimes = @($Row.ClickPairTimes)
    if ($clickPairTimes.Count -lt 2) { return $false }
    $beforeLast = [double]$clickPairTimes[$clickPairTimes.Count - 2] + $RETRY_TURN_CHECK_OFFSET
    $lastCheck = [double]$clickPairTimes[$clickPairTimes.Count - 1] + $RETRY_TURN_CHECK_OFFSET
    return (($beforeLast -lt ($RETRY_L - $TIME_EPSILON)) -and ($lastCheck -ge ($RETRY_L - $TIME_EPSILON)))
}
# 구현 단위 5b-8 FC-X 행 도움 - 첫 retry 전송 시각(행 전제 - 첫 시도 재판단 + 클릭 비용 · 행이 Get-RetryFirstClick 으로 확인) · 10-28 1-I ② 1차 판(20:55:48 '다시 하기' -
#   run_20261028_h21m01s11.log:44-52)의 조작 양보 셋(+2~+5 · +9~+13 · +21~+36초)을 전송 기준 조작 창으로
$RETRY_FIELD_CLICK_AT = $RETRY_FIRST_JUDGE + $RETRY_COST.click
$RETRY_FIELD_INCIDENT_ACTIVE = @(@(($RETRY_FIELD_CLICK_AT + 2), ($RETRY_FIELD_CLICK_AT + 5)), @(($RETRY_FIELD_CLICK_AT + 9), ($RETRY_FIELD_CLICK_AT + 13)), @(($RETRY_FIELD_CLICK_AT + 21), ($RETRY_FIELD_CLICK_AT + 36)))
function Test-RetryFieldSettleLine {
    # 필드 확정 줄 대조: 줄 하나 · 꼴 · W = 소스 캡처 · 표본 수 = 대기 함수 F 화면 HUD 판독 중 After 뒤 것 · 첫 표본부터 초 = 그 연속 첫 · 끝 HUD 판독 시각 차(회전 안 HUD 앞 판독 비용이
    #   같아 회전 시작 차와 같음 - 한 자리 반올림 0.05 안) · 끝 표본에서 처음 W 이상(끝 앞 표본은 W 미만)
    param($Row, [double]$After = -1)
    $settleLines = @($Row.Logs | Where-Object { $_ -cmatch $SETTLE_PATTERN })
    if ($settleLines.Count -ne 1) { return $false }
    $settleMatch = [regex]::Match([string]$settleLines[0], $SETTLE_PATTERN)
    $fieldHudTimes = @($Row.WaiterHud | Where-Object { ($_.Frame -ceq 'F') -and ($_.T -ge ($After - $TIME_EPSILON)) } | ForEach-Object { [double]$_.T })
    if ($fieldHudTimes.Count -lt 2) { return $false }
    $spanLast = $fieldHudTimes[$fieldHudTimes.Count - 1] - $fieldHudTimes[0]
    $spanBefore = $fieldHudTimes[$fieldHudTimes.Count - 2] - $fieldHudTimes[0]
    $settleWidth = [double]::Parse($settleMatch.Groups['w'].Value, [Globalization.CultureInfo]::InvariantCulture)
    $settleSpanText = [double]::Parse($settleMatch.Groups['s'].Value, [Globalization.CultureInfo]::InvariantCulture)
    return (([Math]::Abs($settleWidth - [double]$memberFieldSettleSeconds) -lt $TIME_EPSILON) -and ([int]$settleMatch.Groups['n'].Value -eq $fieldHudTimes.Count) -and
        ([Math]::Abs($settleSpanText - $spanLast) -le (0.05 + $TIME_EPSILON)) -and ($spanLast -ge ($memberFieldSettleSeconds - $TIME_EPSILON)) -and ($spanBefore -lt ($memberFieldSettleSeconds - $TIME_EPSILON)))
}
function Get-RetryEventOrder {
    # 클릭 루프 안 첫 시도의 사건 차례 (focus · attempt · safecheck · update · click 의 첫 등장 차례)
    param($Row)
    $seenKinds = New-Object System.Collections.Generic.List[string]
    foreach ($rowEvent in @($Row.Events)) {
        if (-not $rowEvent.InClick) { continue }
        if (@('focus', 'attempt', 'safecheck', 'update', 'click') -notcontains $rowEvent.Kind) { continue }
        if (-not $seenKinds.Contains([string]$rowEvent.Kind)) { $seenKinds.Add([string]$rowEvent.Kind) }
    }
    return ($seenKinds.ToArray() -join '<')
}

# 행 훅 (스크립트 범위 - $script: · 리터럴 · 스크립트 상수만 읽음)
# 첫 결측 줄 뒤 첫 시계 진행(⑫ 짝 재판독 대기)이 끝나는 순간 캡처가 끊김(다음 회전 서두 = ① 동결) - 한 번만 (RC1d · 시제품 연기 시험 -FailOnRecheck 꼴)
$RETRY_HOOK_FAIL_AFTER_FIRST_MISS = { if ((-not $script:retryHookDone) -and (@($script:rowLogs | Where-Object { $_.StartsWith($RETRY_LINE_MISS_FIRST_PREFIX, [StringComparison]::Ordinal) }).Count -ge 1)) { $script:retryHookDone = $true; Register-MockFail -Cause $OTHER_CAUSE } }
# 같은 자리에서 다음 회전 서두 조작 게이트 1회 참(RC1e · 시제품 연기 시험 -ActiveAtCall 2 꼴 - §4 조작 대기열)
$RETRY_HOOK_ACTIVE_AFTER_FIRST_MISS = { if ((-not $script:retryHookDone) -and (@($script:rowLogs | Where-Object { $_.StartsWith($RETRY_LINE_MISS_FIRST_PREFIX, [StringComparison]::Ordinal) }).Count -ge 1)) { $script:retryHookDone = $true; $script:activeQueue = 1 } }
# 첫 retry 시도의 조작 양보 중(가상 3초)에 안전 중지 예약(K17)
$RETRY_HOOK_F9_DURING_YIELD = { if ((-not $script:retryHookDone) -and ($script:yieldCalls -ge 1) -and ((Get-VirtualElapsed) -ge 3.0)) { $script:retryHookDone = $true; $script:safeStopFlagMock = $true } }
# ── §10 행 (명세 3.1 - 클릭 루프 골격 · 스윕 갈래 · 클릭 자리·시간 · 원 워커 B2 · 폴백 ② 호출 E · 명세가 더한 RC). 시각표 'X@a' = (a, 'X') · 전송 뒤 전이 RetrySend = @{ 전송 번호 = (전송 뒤 초, 약어) … } ──
#   K 행의 지정 시각 T 는 첫 시도 재판단 시각($RETRY_FIRST_JUDGE - 비용 상수의 합)에서 잽니다. 재입장 대기는 ReentryStubs(결과 스텁 - 차례대로) 가 없으면 원문입니다
$RETRY_ENTER = @(@(1, 'U'), @(4, 'I'))   # '다시 하기' 전송 뒤 로딩 → 던전 안 (원문 재입장 대기가 던전 안 2연속을 봄)
$RETRY_STUB_ENTERED = @{ Result = 'entered'; LastKind = 'inside'; PanelSeen = $false }
$RETRY_OTHER_NOPAIR = @{ Result = 'no-pair'; Sends = 0; LastKind = 'reward3' }   # 폴백 ② 행의 '다른 던전 가기' 대기 결과 스텁(맥락 A·B 의 들머리 - ⑤b3 §9 끝 행 꼴)
$RETRY_ROWS = [ordered]@{
    # 클릭 루프 골격 (설계 v11 R5 8.5 - 들머리 = 클릭 루프만)
    'WA-S5a' = @{ Desc = "섞인 실패(5초마다 2초) · 'reward3' 없음(U) → 'unconfirmed' 유한 · 클릭 0 · T < 100 · 반환 LastKind 'unknown'"; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'U')); FailPeriodic = @(5, 5, 2) }
        Expect = { param($Row) ($Row.Click -ceq 'unconfirmed') -and (@($Row.Clicks).Count -eq 0) -and ($Row.T -lt 100) -and ($Row.Error -ceq '') -and ($Row.ClickLast -ceq 'unknown') } }
    'WA-S5b' = @{ Desc = "교대 실패(판독 늘 실패 · 탐침 늘 성공) · U → 탐침 복구 뒤 회전이 마감을 봄 · 'unconfirmed' · T < 200 · 클릭 0"; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'U')); ReadHook = { param($Name) 'fail' } }
        Expect = { param($Row) ($Row.Click -ceq 'unconfirmed') -and (@($Row.Clicks).Count -eq 0) -and ($Row.T -lt 200) } }
    'WA-S5c' = @{ Desc = "같은 회전 복구(짝 판독만 실패) 지속 · U → 복구 회전이 마감을 봄 · 'unconfirmed' · 클릭 0 · T < 100"; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'U')); ReadHook = { param($Name) if ($Name -eq 'pair') { 'fail' } } }
        Expect = { param($Row) ($Row.Click -ceq 'unconfirmed') -and (@($Row.Clicks).Count -eq 0) -and ($Row.T -lt 100) } }
    'WA-S6'  = @{ Desc = "3버튼 + 캡처 실패 60초 [0.01, 60) → 동결 중 클릭·마감·재판단 0 · 탐침 ≤ 32 · 안전 확인 ≥ 1 → 복구 뒤 'sent' (첫 클릭 ≥ 60 · 재판단 1)"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); Fail = @(,@(0.01, 60)); Until = 1000; Verdict0 = 'continue' }
        Expect = { param($Row) ($Row.Click -ceq 'sent') -and ((Get-RetryFirstClick $Row) -ge 60) -and ($Row.Probes -ge 1) -and ($Row.Probes -le 32) -and ($Row.Safe -ge 1) -and ($Row.UpdateCalls -eq 1) -and ($Row.RetryTries -eq 1) } }
    'WA-S7'  = @{ Desc = "'user-active' 생략 5회 뒤 'cursor-not-ready' 2회 → 커서 예산은 생략에 안 듦 → 여덟째 시도 'sent' · 양보 5 · 생략과 전송 사이 짝 판독 ≥ 1(옛 좌표 0)"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); ClickOutcomes = @('user-active', 'user-active', 'user-active', 'user-active', 'user-active', 'cursor-not-ready', 'cursor-not-ready') }
        Expect = { param($Row) $yieldTimes = @($Row.Events | Where-Object { $_.Kind -eq 'yield' } | ForEach-Object { [double]$_.T }); $sendAt = Get-RetryFirstClick $Row
            ($Row.Click -ceq 'sent') -and ($Row.Yields -eq 5) -and ($Row.RetryTries -eq 8) -and ($Row.RetrySends -eq 1) -and ($Row.Attempts -eq 1) -and ($yieldTimes.Count -eq 5) -and
            (@($Row.ClickPairTimes | Where-Object { ($_ -gt $yieldTimes[$yieldTimes.Count - 1]) -and ($_ -lt $sendAt) }).Count -ge 1) } }
    'WA-S8'  = @{ Desc = "커서 미확인 3회 → 'skipped' · 시도 3 · 전송 0 · 커서 미확인 사유 줄 1 · 반환 LastKind 'reward3'"; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); CursorMisses = 3 }
        Expect = { param($Row) ($Row.Click -ceq 'skipped') -and ($Row.RetryTries -eq 3) -and ($Row.RetrySends -eq 0) -and ($Row.CursorLines -eq 1) -and ($Row.ClickLast -ceq 'reward3') } }
    'WA-S9'  = @{ Desc = "짝 판독 뒤 · 패널 판독 앞 [0.15, 0.6) 에 패널(matching) → 그 회전 클릭 0(첫 클릭 앞 짝 판독 ≥ 2 - 다음 회전의 새 판독으로 누름) · 첫 클릭 ≥ 0.6 · 'sent'"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); PanelOverride = { if (((Get-VirtualElapsed) -ge 0.15) -and ((Get-VirtualElapsed) -lt 0.6)) { 'matching' } } }
        Expect = { param($Row) $firstClickAt = Get-RetryFirstClick $Row; ($Row.Click -ceq 'sent') -and ($firstClickAt -ge 0.6) -and (@($Row.ClickPairTimes | Where-Object { $_ -lt $firstClickAt }).Count -ge 2) } }
    'WA-S10a' = @{ Desc = "((가)) 패널 판독의 창 좌표 throw(판독 경로 문구 ∧ 플래그 ∧ gameWindowGone) → 받음 → 동결 · 탐침 → 복구 뒤 새 판독으로 'sent'"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); ReadHook = { param($Name) if (($Name -eq 'panel') -and ((Get-VirtualElapsed) -lt 0.5)) { 'rect' } } }
        Expect = { param($Row) ($Row.Click -ceq 'sent') -and ($Row.Probes -ge 1) -and ((Get-RetryFirstClick $Row) -ge 2) } }
    'WA-S10b' = @{ Desc = '((나)) HUD 판독의 등록 없는 다른 예외 → 밖으로'; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); ReadHook = { param($Name) if ($Name -eq 'hud') { 'other-throw' } } }
        Expect = { param($Row) $Row.Error -ceq $OTHER_WAIT_OTHER_ERROR } }
    'WA-S10d' = @{ Desc = '((라)) 패널 판독 gameWindowGone 등록 뒤 두 문구가 아닌 예외 → 밖으로'; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); ReadHook = { param($Name) if ($Name -eq 'panel') { 'rect-other' } } }
        Expect = { param($Row) $Row.Error -ceq $OTHER_WAIT_THIRD_ERROR } }
    'WA-S10e' = @{ Desc = '((마)) 판독 경로 문구지만 원인 other → 밖으로'; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); ReadHook = { param($Name) if ($Name -eq 'panel') { 'msg-othercause' } } }
        Expect = { param($Row) $Row.Error -ceq $READ_PATH_MESSAGE } }
    # 서두 판독값 비움 (명세 1.2 서두 · 1.7 규칙 4 · 15) - 판독 없는 회전(탐침 복구 뒤 · 스윕 복구 · 같은 회전 복구)은 직전 회전의 분류 · 점으로 누르지 않고 다음 회전의 새 판독으로 누름
    'WA-S11a' = @{ Desc = "커서 미확인 1회 → 다음 회전 스윕 'gate-true'(동결) → 탐침 복구 뒤 회전(판독 없음)은 누르지 않음 → 새 판독으로 'sent' · 시도 2 · 첫 전송 앞 짝 판독 ≥ 2"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); CursorMisses = 1; Sweep = @(@{ From = 0.5; Kind = 'gate-true'; Count = 1 }) }
        Expect = { param($Row) $sendAt = Get-RetryFirstClick $Row; ($Row.Click -ceq 'sent') -and ($Row.RetryTries -eq 2) -and ($Row.Probes -ge 1) -and (@($Row.ClickPairTimes | Where-Object { $_ -lt $sendAt }).Count -ge 2) } }
    'WA-S11b' = @{ Desc = "'user-active' 생략 1회 → 다음 회전 스윕 'recover'(같은 호출 복구 - 복구 회전 · 판독 없음)는 누르지 않음 → 새 판독으로 'sent' · 시도 2 · 양보 1 · 첫 전송 앞 짝 판독 ≥ 2"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); ClickOutcomes = @('user-active'); Sweep = @(@{ From = 0.5; Kind = 'recover'; Count = 1 }) }
        Expect = { param($Row) $sendAt = Get-RetryFirstClick $Row; ($Row.Click -ceq 'sent') -and ($Row.RetryTries -eq 2) -and ($Row.Yields -eq 1) -and (@($Row.ClickPairTimes | Where-Object { $_ -lt $sendAt }).Count -ge 2) } }
    'WA-S11c' = @{ Desc = "커서 미확인 1회 → 다음 회전 HUD 판독만 실패(같은 회전 복구 - 그 회전 짝 판독은 있음)는 분류 없이 누르지 않음 → 다음 회전 새 판독 · 분류로 'sent' · 시도 2 · 첫 전송 앞 짝 판독 ≥ 3"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); CursorMisses = 1; ReadHook = { param($Name) if (($Name -eq 'hud') -and (@($script:retryReads | Where-Object { $_.Name -eq 'hud' }).Count -eq 1)) { 'fail' } } }
        Expect = { param($Row) $sendAt = Get-RetryFirstClick $Row; ($Row.Click -ceq 'sent') -and ($Row.RetryTries -eq 2) -and (@($Row.ClickPairTimes | Where-Object { $_ -lt $sendAt }).Count -ge 3) } }
    # 스윕 갈래 - 클릭 루프 판 (구현 명세 ⑤b3 3.1 SW · 범위 ⑤-50 · R6 2.11 ③)
    'SW1r'   = @{ Desc = "스윕 참(전송) 지속 → 셋째부터 굶김 회전이 마감을 봄 → [L, L + 3) 에 'unconfirmed' · 클릭 0"; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'U')); Sweep = @(@{ From = 0; Kind = 'sent'; Gap = 1.0 }) }
        Expect = { param($Row) ($Row.Click -ceq 'unconfirmed') -and (@($Row.Clicks).Count -eq 0) -and ($Row.T -ge $RETRY_L) -and ($Row.T -lt ($RETRY_L + 3)) } }
    'SW2r'   = @{ Desc = "((가)) 스윕 예비 좌표 클릭 경로 문구 ∧ 플래그 ∧ gameWindowGone → 받음 → 동결(안전 확인 · 탐침) → 복구 뒤 새 판독으로 'sent'"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); Sweep = @(@{ From = 0; Kind = 'rect-click-throw'; Count = 1 }) }
        Expect = { param($Row) ($Row.Click -ceq 'sent') -and ($Row.Safe -ge 1) -and ($Row.Probes -ge 1) -and ((Get-RetryFirstClick $Row) -ge 2) } }
    'SW5r'   = @{ Desc = "((나)) 셋째 문구('X ' + 클릭 경로 문구) ∧ 플래그 ∧ gameWindowGone → 밖으로"; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); Sweep = @(@{ From = 0; Kind = 'rect-click-throw'; Message = $THIRD_MESSAGE }) }
        Expect = { param($Row) $Row.Error -ceq $THIRD_MESSAGE } }
    'SW3r'   = @{ Desc = '((다)) 플래그 거짓의 클릭 경로 문구 → 밖으로'; Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); Sweep = @(@{ From = 0; Kind = 'click-throw-noreg' }) }
        Expect = { param($Row) $Row.Error -ceq $CLICK_PATH_MESSAGE } }
    'SW6ar'  = @{ Desc = "((라)) 'gate-true'(실패 등록 · 메타 0 · 참) → 그 회전 클릭 0 → freeze → 동결 → 복구 뒤 'sent' (첫 클릭 ≥ 4)"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'R')); Sweep = @(@{ From = 0; Kind = 'gate-true'; Count = 1 }) }
        Expect = { param($Row) ($Row.Click -ceq 'sent') -and ($Row.Safe -ge 1) -and ($Row.Probes -ge 1) -and ((Get-RetryFirstClick $Row) -ge 4) } }
    'SW6br'  = @{ Desc = "((라)) Rr · 둘째 회전 'gate-true' freeze → 동결 · 탐침 복구 뒤 회전은 짝 없음 셈을 세지도 비우지도 않음 → 다음 Rr 이 둘째 결측 → 'no-pair' (첫 줄 1 · 짝 없음 줄 1) · 반환 LastKind 'reward3'"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'Rr')); Sweep = @(@{ From = 1.0; Kind = 'gate-true'; Count = 1 }) }
        Expect = { param($Row) ($Row.Click -ceq 'no-pair') -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 1) -and ($Row.Safe -ge 1) -and (@($Row.ClickPairTimes).Count -eq 2) -and ($Row.ClickLast -ceq 'reward3') } }
    'SW7r'   = @{ Desc = "스윕 'recovered' 지속(스윕 안 실패 → 같은 호출 복구 · 커서 미확인) → 복구 회전이 마감을 봄 → [L + 캡처 실패 누적, L + 캡처 실패 누적 + 3) 에 'unconfirmed' · 클릭 0 (클릭 루프 시계는 실패 차분만큼 마감을 미룸 - 아래 끝도 그 몫까지 · L 이 커도 같은 꼴)"
        Spec = @{ Entry = 'click'; Timeline = @(,@(0, 'U')); Sweep = @(@{ From = 0; Kind = 'recover'; Gap = 0.1 }) }
        Expect = { param($Row) ($Row.Click -ceq 'unconfirmed') -and (@($Row.Clicks).Count -eq 0) -and ($Row.T -ge ($RETRY_L + ($Row.FailMs / 1000.0) - $TIME_EPSILON)) -and ($Row.T -lt ($RETRY_L + ($Row.FailMs / 1000.0) + 3)) } }
    # 클릭 자리 · 시간 (설계 v11 R3 5.3 · R1 5.3 - R1 짝은 같은 행). 들머리 = 끝(retry)
    'K1'     = @{ Desc = "(W1) 시간 지정 아님 → 'sent' → 재입장 'entered' → 재입장 완료 끝 · 코드 0 · 시간 줄 0 · 기록 셋 각 1 · 재판단 1"
        Spec = @{ Timeline = @(,@(0, 'R')); ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $RETRY_IH_LINE) -and ($Row.RetrySends -eq 1) -and ($Row.Attempts -eq 1) -and ($Row.Clickeds -eq 1) -and ($Row.Reentereds -eq 1) -and
            ($Row.ContinueLines -eq 0) -and ($Row.LastLines -eq 0) -and ($Row.UpdateCalls -eq 1) -and ($Row.DgCalls -eq 1) -and (@($Row.Reentry).Count -eq 1) -and @($Row.Reentry)[0].Report } }
    'K2'     = @{ Desc = "(W3) 첫 시도 T−59 'continue' → 'sent' → 'entered' → 시간 줄 ③ 1 · 코드 11"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 59); Verdict0 = 'continue'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__11') -and ($Row.Last -ceq $RETRY_IH_LINE) -and ($Row.ContinueLines -eq 1) -and (@($Row.Logs) -ccontains ($RETRY_LINE_CONTINUE_FORMAT -f $script:abyssUntil.ToString('HH:mm'))) -and ($Row.RetrySends -eq 1) } }
    'K3'     = @{ Desc = "(W4) 첫 시도 T−1 'user-active' → 양보가 T+5 에 끝남 → 재진입 재판단 'last' → 전송 0 · 시간 줄 ② · 'last' 반환(본류가 옛 나가기 - 구현 명세 ⑤b6) · other 대기 0 · 예약 소비 0 · retry-attempt 1 · 재판단 2"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 1); Verdict0 = 'continue'; Active = @(,@(($RETRY_FIRST_JUDGE - 0.1), ($RETRY_FIRST_JUDGE + 6))) }
        Expect = { param($Row) ($Row.Exit -ceq '') -and ($Row.Error -ceq '') -and ($Row.Return -ceq 'last') -and ($Row.Last -ceq ($RETRY_LINE_LAST_FORMAT -f $script:abyssUntil.ToString('HH:mm'))) -and ($Row.RetrySends -eq 0) -and
            ($Row.OtherSends -eq 0) -and ($Row.OtherWaits -eq 0) -and ($Row.Attempts -eq 1) -and ($Row.Yields -ge 1) -and ($Row.UpdateCalls -eq 2) -and ($Row.LastLines -eq 1) -and ($Row.ContinueLines -eq 0) -and
            (@($Row.Reentry).Count -eq 0) -and ($Row.Removed -eq 0) } }
    'K4'     = @{ Desc = "첫 retry-attempt 기록(잠금 대기)이 T−0.1 → T+0.2 → 기록 뒤 재판단 'last' → 전송 0 · 시간 줄 ② · 'last' 반환(본류가 옛 나가기 - 구현 명세 ⑤b6) · other 대기 0 (재판단이 기록 앞이면 'continue' → 11 - R3-M17. 실제 파일에 쓴 직후 시계 훅)"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 0.1); Verdict0 = 'continue'; AfterWrite = @{ 'retry-attempt' = 0.3 } }
        Expect = { param($Row) ($Row.Exit -ceq '') -and ($Row.Error -ceq '') -and ($Row.Return -ceq 'last') -and ($Row.Last -ceq ($RETRY_LINE_LAST_FORMAT -f $script:abyssUntil.ToString('HH:mm'))) -and ($Row.RetrySends -eq 0) -and
            ($Row.OtherWaits -eq 0) -and ($Row.Attempts -eq 1) -and ($Row.LastLines -eq 1) -and ($Row.UpdateCalls -eq 1) -and ($Row.Removed -eq 0) } }
    'K6'     = @{ Desc = "첫 시도 'cursor-not-ready' · 둘째 T−29 전송 → 'continue' 둘 · 'entered' · 코드 11 · 시도 2 · 재판단 2 · 커서 사유 줄 0"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 30); Verdict0 = 'continue'; CursorMisses = 1; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__11') -and ($Row.RetryTries -eq 2) -and ($Row.RetrySends -eq 1) -and ($Row.UpdateCalls -eq 2) -and ($Row.Attempts -eq 1) -and ($Row.CursorLines -eq 0) -and ($Row.ContinueLines -eq 1) } }
    'K7'     = @{ Desc = "첫 시도 'cursor-not-ready'(T−1.5) · 둘째 시도 재판단이 T 뒤 → 'last'(클릭 시도 1) · 전송 0 · 'last' 반환(본류가 옛 나가기 - 구현 명세 ⑤b6) · other 대기 0 · 재판단 2"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 1.5); Verdict0 = 'continue'; CursorMisses = 1 }
        Expect = { param($Row) ($Row.Exit -ceq '') -and ($Row.Error -ceq '') -and ($Row.Return -ceq 'last') -and ($Row.Last -ceq ($RETRY_LINE_LAST_FORMAT -f $script:abyssUntil.ToString('HH:mm'))) -and ($Row.RetrySends -eq 0) -and
            ($Row.RetryTries -eq 1) -and ($Row.OtherWaits -eq 0) -and ($Row.UpdateCalls -eq 2) -and ($Row.LastLines -eq 1) -and ($Row.Attempts -eq 1) -and ($Row.Removed -eq 0) } }
    'K8'     = @{ Desc = "(W5) 우연한 만남 · commit T−1 → 매칭(M) → T+120 입장 → 원문 재입장 대기(모드 예산 300) 'entered' · 코드 11 · commit 뒤 Get-DgTimeVerdict 0(합 1)"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 1); Verdict0 = 'continue'; RetrySend = @{ 1 = @(@(0.5, 'M'), @(121, 'U'), @(122, 'I')) } }
        Expect = { param($Row) $reentryCall = @($Row.Reentry)[0]
            ($Row.Exit -ceq '__EXIT__11') -and ($Row.ContinueLines -eq 1) -and ($Row.DgCalls -eq 1) -and ($Row.UpdateCalls -eq 1) -and (@($Row.Reentry).Count -eq 1) -and ($reentryCall.Limit -eq $timeoutPartyMatch) -and
            $reentryCall.Report -and ($reentryCall.Result -ceq 'entered') -and ([double]$reentryCall.End -ge ($RETRY_FIRST_JUDGE + 1 + 120)) } }
    'K9'     = @{ Desc = "(W12) commit T−1 → B2 재클릭 요청(T+9) → 재클릭이 재검사를 건너뜀(재판단 · Get-DgTimeVerdict 합 1) → 'entered' · 코드 11 · 한 번 더 줄 1"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 1); Verdict0 = 'continue'; ReentryStubs = @(@{ Result = 'reclick'; LastKind = 'reward3'; Advance = 10 }, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__11') -and ($Row.RetrySends -eq 2) -and ($Row.Reclicks -eq 1) -and ($Row.UpdateCalls -eq 1) -and ($Row.DgCalls -eq 1) -and ($Row.Attempts -eq 1) -and ($Row.Clickeds -eq 2) -and ($Row.ContinueLines -eq 1) } }
    'K14'    = @{ Desc = "자정 넘김 - T = 10-02 00:30 · 보상 10-01 23:59 → 'continue' → 'entered' · 코드 11 · 시간 줄 ③ '00:30'"
        Spec = @{ Start = '2026-10-01 23:59:00'; UntilAt = '2026-10-02 00:30:00'; Timeline = @(,@(0, 'R')); Verdict0 = 'continue'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__11') -and (@($Row.Logs) -ccontains ($RETRY_LINE_CONTINUE_FORMAT -f '00:30')) } }
    'K15a'   = @{ Desc = "commit 뒤 B2 'timeout' → 'none' 행 코드 4 · 시간 줄 ③ 0 · 11 0"; Spec = @{ Timeline = @(,@(0, 'R')); Until = 1000; Verdict0 = 'continue'; ReentryStubs = @(, @{ Result = 'timeout'; LastKind = 'unknown' }) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.ContinueLines -eq 0) -and ($Row.IhLines -eq 0) } }
    'K15b'   = @{ Desc = "commit 뒤 B2 'cancelled' → '다른 던전 가기' rematch-cancelled · 코드 4 · 시간 줄 ③ 0 · 11 0"; Spec = @{ Timeline = @(,@(0, 'R')); Until = 1000; Verdict0 = 'continue'; ReentryStubs = @(, @{ Result = 'cancelled'; LastKind = 'reward3'; PanelSeen = $true }) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $OTHER_DONE_CANCELLED) -and ($Row.ContinueLines -eq 0) -and ($Row.IhLines -eq 0) } }
    'K15c'   = @{ Desc = "commit 뒤 'reclick' 두 번 → 폴백 ① 복귀 완료 · 코드 0 · 시간 줄 ③ 0 · 11 0"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = 1000; Verdict0 = 'continue'; ReentryStubs = @(@{ Result = 'reclick'; LastKind = 'reward3' }, @{ Result = 'reclick'; LastKind = 'reward3' }) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $OTHER_DONE_READY) -and ($Row.ContinueLines -eq 0) -and ($Row.IhLines -eq 0) } }
    'K16'    = @{ Desc = "보상 T−10 · 첫 시도 전 캡처 실패 [0.01, 40) → 동결 중 판단 0 → 복구 뒤 기록 → 재판단 'last' · 전송 0 · 'last' 반환(본류가 옛 나가기 - 구현 명세 ⑤b6) · other 대기 0 · 재판단 1"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = 10; Verdict0 = 'continue'; Fail = @(,@(0.01, 40)) }
        Expect = { param($Row) $attemptAt = @($Row.Events | Where-Object { $_.Kind -eq 'attempt' } | ForEach-Object { [double]$_.T }); $updateAt = @($Row.Events | Where-Object { $_.Kind -eq 'update' } | ForEach-Object { [double]$_.T })
            ($Row.Exit -ceq '') -and ($Row.Error -ceq '') -and ($Row.Return -ceq 'last') -and ($Row.Last -ceq ($RETRY_LINE_LAST_FORMAT -f $script:abyssUntil.ToString('HH:mm'))) -and ($Row.RetrySends -eq 0) -and
            ($Row.OtherWaits -eq 0) -and ($Row.UpdateCalls -eq 1) -and ($Row.Attempts -eq 1) -and ($Row.LastLines -eq 1) -and ($Row.Safe -ge 1) -and ($Row.Removed -eq 0) -and
            ($attemptAt.Count -eq 1) -and ($attemptAt[0] -ge 40) -and ($updateAt.Count -eq 1) -and ($updateAt[0] -ge $attemptAt[0]) } }
    'K17'    = @{ Desc = "(W16) 첫 시도 'user-active' → 양보 중 F9 → 재진입 재검사 = 안전 중지(재판단보다 앞) → 전송 0 · 안전 중지 줄 1 · 시간 줄 0 · 'safe-stop' 반환(본류가 옛 나가기 - 구현 명세 ⑤b6) · other 대기 0 · 예약 그대로(소비 0)"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 1); Verdict0 = 'continue'; Active = @(,@(($RETRY_FIRST_JUDGE - 0.1), ($RETRY_FIRST_JUDGE + 6))); TimeHooks = @(, $RETRY_HOOK_F9_DURING_YIELD) }
        Expect = { param($Row) ($Row.Exit -ceq '') -and ($Row.Error -ceq '') -and ($Row.Return -ceq 'safe-stop') -and ($Row.Last -ceq $RETRY_LINE_SAFE) -and ($Row.RetrySends -eq 0) -and ($Row.OtherWaits -eq 0) -and
            ($Row.SafeLines -eq 1) -and ($Row.LastLines -eq 0) -and ($Row.UpdateCalls -eq 1) -and ($Row.Removed -eq 0) -and $Row.FlagEnd } }
    'K18'    = @{ Desc = "(W17) commit T−1 → B2 대기 중 F9 → 재클릭 요청 → 재클릭(commit 뒤 - 안전 중지도 보지 않음) → 'entered' · 코드 11 · 예약 그대로(소비 0)"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 1); Verdict0 = 'continue'; ReentryStubs = @(@{ Result = 'reclick'; LastKind = 'reward3'; Advance = 10; SetF9 = $true }, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__11') -and ($Row.RetrySends -eq 2) -and ($Row.SafeLines -eq 0) -and $Row.FlagEnd -and ($Row.Removed -eq 0) -and ($Row.UpdateCalls -eq 1) } }
    'W13'    = @{ Desc = "reentered 기록 실패('expect-failed' 주입) → 재입장 완료 줄 그대로 · 코드 11 (원문의 실패 [경고] 줄이 완료 줄 앞)"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 59); Verdict0 = 'continue'; ReentryStubs = @(, $RETRY_STUB_ENTERED); StoreInject = @{ 'reentered' = @('expect-failed') } }
        Expect = { param($Row) $logList = @($Row.Logs); ($Row.Exit -ceq '__EXIT__11') -and ($Row.Last -ceq $RETRY_IH_LINE) -and ([Array]::IndexOf($logList, $RETRY_REENTERED_FAIL_LINE) -ge 0) -and
            ([Array]::IndexOf($logList, $RETRY_REENTERED_FAIL_LINE) -lt [Array]::IndexOf($logList, $RETRY_IH_LINE)) } }
    # 원 워커 B2 (설계 v11 R5 8.4 · R6 3.5 ① · 5.1 · 7.2)
    'WA-X3'  = @{ Desc = "(K19 · FB10 의 retry 몫) 원문 대기 · commit T−1 → B2 패널(M) → 사용자 취소 → 3버튼 → 'cancelled' → 재클릭 0 → rematch-cancelled · 코드 4 · retry 전송 총 1 · other 1 · 예약 소비 0"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 1); Verdict0 = 'continue'; RetrySend = @{ 1 = @(@(0.5, 'M'), @(6, 'R')) } }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $OTHER_DONE_CANCELLED) -and ($Row.RetrySends -eq 1) -and ($Row.OtherSends -eq 1) -and ($Row.Reclicks -eq 0) -and ($Row.Removed -eq 0) -and
            ($Row.IhLines -eq 0) -and (@($Row.Reentry).Count -eq 1) -and (@($Row.Reentry)[0].Result -ceq 'cancelled') } }
    'WA-X3′' = @{ Desc = "WA-X3 들머리 + commit 뒤 예약 → 끝 같음(rematch-cancelled · 코드 4) · 예약 그대로(정지 끝 맥락은 소비하지 않음 - R6 5.1)"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); Until = ($RETRY_FIRST_JUDGE + 1); Verdict0 = 'continue'; RetrySend = @{ 1 = @(@(0.5, 'M'), @(6, 'R')) }; F9OnRetrySend = 1 }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $OTHER_DONE_CANCELLED) -and ($Row.RetrySends -eq 1) -and ($Row.Removed -eq 0) -and $Row.FlagEnd } }
    'WA-X4'  = @{ Desc = "원문 대기 · R 10초(클릭 무반응) → 'reclick' → 재클릭 1(commit 뒤 - 재판단 0) → 둘째 대기 'entered' · 코드 11 · retry-attempt 1"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = 1000; Verdict0 = 'continue'; RetrySend = @{ 2 = $RETRY_ENTER } }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__11') -and ($Row.RetrySends -eq 2) -and ($Row.Reclicks -eq 1) -and ($Row.Attempts -eq 1) -and ($Row.UpdateCalls -eq 1) -and (@($Row.Reentry).Count -eq 2) -and
            (@($Row.Reentry | Where-Object { $_.Report }).Count -eq 2) } }
    'WA-X5'  = @{ Desc = "원문 대기 · 'reclick' 두 번 → 상한(판당 전송 2) → '두 번 눌러도' 줄 → 폴백 ① 복귀 완료 · 코드 0"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = 1000; Verdict0 = 'continue' }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $OTHER_DONE_READY) -and ($Row.RetrySends -eq 2) -and ($Row.Reclicks -eq 1) -and ($Row.Twice -eq 1) -and ($Row.OtherSends -eq 1) } }
    'WA-X12' = @{ Desc = "(K20) 첫 시도 retry-attempt 기록 실패('locked') → 'record-failed' 반환(옛 나가기는 부르는 쪽) · 재판단 0 · 전송 0 · 시간 줄 0 · exit 0"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = 1000; Verdict0 = 'continue'; StoreInject = @{ 'retry-attempt' = @('locked') } }
        Expect = { param($Row) ($Row.Exit -ceq '') -and ($Row.Error -ceq '') -and ($Row.Return -ceq 'record-failed') -and ($Row.RetrySends -eq 0) -and ($Row.RetryTries -eq 0) -and ($Row.UpdateCalls -eq 0) -and
            ($Row.Attempts -eq 1) -and ($Row.LastLines -eq 0) -and ($Row.ContinueLines -eq 0) } }
    'FB12'   = @{ Desc = "우연한 만남 B2 'timeout' → 끝에서 클릭 0(전체 클릭 = retry 전송 1) · 진단 1 · 우연한 만남 문구(`${timeoutPartyMatch}) · 코드 4"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); ReentryStubs = @(, @{ Result = 'timeout'; LastKind = 'matching' }) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_NONE_PARTY) -and ($Row.Diags -eq 1) -and ($Row.Helper -eq 0) -and ($Row.OtherSends -eq 0) -and ($Row.RetrySends -eq 1) -and (@($Row.Clicks).Count -eq 1) } }
    'FB12′'  = @{ Desc = "혼자하기 B2 'timeout' → 끝에서 클릭 0(전체 클릭 = retry 전송 1) · 진단 1 · 혼자하기 문구(`${timeoutEntry} · 매칭 낱말 0) · 코드 4"
        Spec = @{ Timeline = @(,@(0, 'R')); ReentryStubs = @(, @{ Result = 'timeout'; LastKind = 'unknown' }) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_NONE_SOLO) -and (-not $Row.Last.Contains('매칭')) -and ($Row.Diags -eq 1) -and ($Row.Helper -eq 0) -and ($Row.OtherSends -eq 0) -and ($Row.RetrySends -eq 1) -and (@($Row.Clicks).Count -eq 1) } }
    # 폴백 ② 호출 E (설계 v11 R6 3.3 · 7.2 · 7.3 · 구현 명세 ⑤b3 C-1). 들머리 = 끝(other) · 대기 결과 스텁 'no-pair'(맥락 A·B) · 헬퍼 결과 스텁 · 재입장 대기 결과 스텁
    'FB3'    = @{ Desc = "A · 이 워커 retry-attempt 기록 있음 · 헬퍼 'matching' → B2 1(보고 끔 · 모드 예산) → 'entered' → reentered · 재입장 완료 끝 · 코드 0 · 복귀 루프 0"
        Spec = @{ Entry = 'other'; Recorded0 = $true; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $RETRY_IH_LINE) -and (@($Row.Reentry).Count -eq 1) -and (-not @($Row.Reentry)[0].Report) -and ($Row.Reentereds -eq 1) -and ($Row.Return2 -ceq '') } }
    'FB4'    = @{ Desc = "A · retry-attempt 없음 · 헬퍼 'matching' → B2 0 · 복귀 루프 1(코드 0) · 복귀 완료 · 코드 0"
        Spec = @{ Entry = 'other'; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching' }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $OTHER_DONE_READY) -and (@($Row.Reentry).Count -eq 0) -and ($Row.Return2 -ceq '0|') } }
    'FB16a'  = @{ Desc = "A · retry-attempt 있음 · 헬퍼 'ready-panel' → B2 1 → 'entered' · 코드 0"; Spec = @{ Entry = 'other'; Recorded0 = $true; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'ready-panel'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $RETRY_IH_LINE) -and (@($Row.Reentry).Count -eq 1) -and ($Row.Return2 -ceq '') } }
    'FB16b'  = @{ Desc = "A · retry-attempt 있음 · 헬퍼 'entry-waiting' → B2 1 → 'entered' · 코드 0"; Spec = @{ Entry = 'other'; Recorded0 = $true; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'entry-waiting'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $RETRY_IH_LINE) -and (@($Row.Reentry).Count -eq 1) -and ($Row.Return2 -ceq '') } }
    'FB17a'  = @{ Desc = "A · retry-attempt 없음 · 헬퍼 'ready-panel' → B2 0 · 복귀 루프 1 · 코드 0"; Spec = @{ Entry = 'other'; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'ready-panel' }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $OTHER_DONE_READY) -and (@($Row.Reentry).Count -eq 0) -and ($Row.Return2 -ceq '0|') } }
    'FB17b'  = @{ Desc = "A · retry-attempt 없음 · 헬퍼 'entry-waiting' → B2 0 · 복귀 루프 1 · 코드 0"; Spec = @{ Entry = 'other'; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'entry-waiting' }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $OTHER_DONE_READY) -and (@($Row.Reentry).Count -eq 0) -and ($Row.Return2 -ceq '0|') } }
    'FB20a'  = @{ Desc = "B(rematch-cancelled) · retry-attempt 있음 · 헬퍼 'matching' → B2 1 → 'entered' → 재입장 완료 끝 · 코드 0"
        Spec = @{ Entry = 'other'; Ending = 'rematch-cancelled'; Recorded0 = $true; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $RETRY_IH_LINE) -and (@($Row.Reentry).Count -eq 1) -and ($Row.Return2 -ceq '') } }
    'FB20b'  = @{ Desc = "B(rematch-cancelled) · retry-attempt 없음 · 헬퍼 'matching' → B2 0 · 복귀 루프(코드 4) → 재매칭 취소 문구 · 코드 4"
        Spec = @{ Entry = 'other'; Ending = 'rematch-cancelled'; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching' }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $OTHER_DONE_CANCELLED) -and (@($Row.Reentry).Count -eq 0) -and ($Row.Return2 -ceq '4|') } }
    'SS10'   = @{ Desc = "예약 + 'reward' → 헬퍼 'matching'(retry-attempt 있음) → B2 'entered' → 대기·호출부·B2 삭제 0(예약 그대로) · reentered · 코드 11 · 복귀 루프 0"
        Spec = @{ Entry = 'other'; Recorded0 = $true; Verdict0 = 'continue'; Until = 1000; F9 = $true; OtherStub = @{ Result = 'reward'; Sends = 2; LastKind = 'reward3' }; HelperResult = 'matching'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__11') -and ($Row.Removed -eq 0) -and $Row.FlagEnd -and ($Row.Reentereds -eq 1) -and ($Row.Return2 -ceq '') -and ($Row.Last -ceq $RETRY_IH_LINE) } }
    'SS11'   = @{ Desc = "SS10 들머리 → B2 'timeout' → 'none' 행 코드 4 · 삭제 0(예약 그대로)"
        Spec = @{ Entry = 'other'; Recorded0 = $true; Verdict0 = 'continue'; Until = 1000; F9 = $true; OtherStub = @{ Result = 'reward'; Sends = 2; LastKind = 'reward3' }; HelperResult = 'matching'; ReentryStubs = @(, @{ Result = 'timeout'; LastKind = 'unknown' }) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Removed -eq 0) -and $Row.FlagEnd -and ($Row.Last -ceq $RETRY_NONE_SOLO) -and ($Row.Return2 -ceq '') } }
    'RC10'   = @{ Desc = "(함수 단위 - R6-P9 의 Role resume 항) 표식 거짓 · Role 'resume' · 헬퍼 'matching' → B2 1 → 'entered' → 재입장 완료 끝 · 코드 0"
        Spec = @{ Entry = 'other'; Role = 'resume'; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $RETRY_IH_LINE) -and (@($Row.Reentry).Count -eq 1) -and ($Row.Return2 -ceq '') } }
    # 명세가 더한 RC - 짝 없음 재판독(U-⑤-3 (나)) 여덟 · 그 밖. 시각표는 시제품 연기 시험(mod5 하니스)과 같은 비용 상수에서 같은 값
    'RC1a'   = @{ Desc = "Rr@0 · R@1.2 → 첫 결측(첫 줄 1) → 둘째 유효 회전 Retry → 'sent' · 짝 판독 2 · 간격 = 재판독 대기(소스 캡처) + 회전 비용(정확히)"
        Spec = @{ Timeline = @(@(0, 'Rr'), @(1.2, 'R')); ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) $pairTimes = @($Row.ClickPairTimes)
            ($Row.Exit -ceq '__EXIT__0') -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 0) -and ((Get-RetryClickText $Row) -ceq 'retry(636,654)') -and ($Row.Attempts -eq 1) -and ($pairTimes.Count -eq 2) -and
            ([Math]::Abs((1000 * ($pairTimes[1] - $pairTimes[0])) - ($RETRY_RECHECK_WAIT_MS + 1000 * $RETRY_RC1A_TURN_COST)) -lt 0.5) } }
    'RC1b'   = @{ Desc = "Rr 지속 → 두 번 결측 → 첫 줄 1 · 짝 없음 줄 1 · 'no-pair' → 폴백 ① other 클릭 · 복귀 완료 · 코드 0 · retry-attempt 0"; Spec = @{ Timeline = @(,@(0, 'Rr')) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $OTHER_DONE_READY) -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 1) -and ((Get-RetryClickText $Row) -ceq 'other(778,654)') -and ($Row.Attempts -eq 0) } }
    'RC1c'   = @{ Desc = "Rr@0 · U@1.3 · Rr@2.0 · R@3.0 → 다른 유효 분류가 셈을 비움 → 첫 줄 2 · 짝 없음 줄 0 · 'sent' · 짝 판독 4"
        Spec = @{ Timeline = @(@(0, 'Rr'), @(1.3, 'U'), @(2.0, 'Rr'), @(3.0, 'R')); ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.MissFirst -eq 2) -and ($Row.MissEnd -eq 0) -and ((Get-RetryClickText $Row) -ceq 'retry(636,654)') -and (@($Row.ClickPairTimes).Count -eq 4) } }
    'RC1d'   = @{ Desc = "Rr@0 · R@2.0 · 첫 줄 뒤 재판독 대기 끝에 캡처 실패 → 동결 · 탐침 복구 뒤 회전(미산입) → Retry 'sent' · 짝 판독 2"
        Spec = @{ Timeline = @(@(0, 'Rr'), @(2.0, 'R')); TimeHooks = @(, $RETRY_HOOK_FAIL_AFTER_FIRST_MISS); ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Probes -ge 1) -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 0) -and ((Get-RetryClickText $Row) -ceq 'retry(636,654)') -and (@($Row.ClickPairTimes).Count -eq 2) } }
    'RC1e'   = @{ Desc = "Rr@0 · R@2.0 · 첫 줄 뒤 다음 회전 조작 양보(미산입) → Retry 'sent' · 양보 1 · 짝 판독 2"
        Spec = @{ Timeline = @(@(0, 'Rr'), @(2.0, 'R')); TimeHooks = @(, $RETRY_HOOK_ACTIVE_AFTER_FIRST_MISS); ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Yields -eq 1) -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 0) -and ((Get-RetryClickText $Row) -ceq 'retry(636,654)') -and (@($Row.ClickPairTimes).Count -eq 2) } }
    'RC1f'   = @{ Desc = "원문 대기 · 'reclick' 둘째 호출의 첫 결측(짝 판독 2 번째 = Rr) → 재판독 → 'sent' → 'entered' · 코드 11 · 셈은 호출마다 0 · retry-attempt 1 · 재판단 1"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = 60; Verdict0 = 'continue'; PairReadScreens = @{ 2 = 'Rr' }; RetrySend = @{ 2 = $RETRY_ENTER } }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__11') -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 0) -and ((Get-RetryClickText $Row) -ceq 'retry(636,654),retry(636,654)') -and ($Row.Attempts -eq 1) -and ($Row.UpdateCalls -eq 1) } }
    'RC1g'   = @{ Desc = "U 지속 · 마감 회전 앞 회전의 짝 판독 바로 앞부터 Rr(회전 박자로 잼) → 첫 결측은 마감 전 회전 · 둘째 결측 = 마감 회전 → ⑨ 가 ⑩ 보다 먼저 'no-pair' → 폴백 ① · 코드 0 · 진단 0 (행 전제: 마지막 두 짝 판독 회전의 마감 판정 < L ≤)"
        Spec = @{ Timeline = @(@(0, 'U'), @($RETRY_RC1G_AT, 'Rr')) }
        Expect = { param($Row) (Test-RetryDeadlineTurnPair $Row) -and ($Row.Exit -ceq '__EXIT__0') -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 1) -and ((Get-RetryClickText $Row) -ceq 'other(778,654)') -and
            ($Row.Attempts -eq 0) -and ($Row.Diags -eq 0) -and ($Row.Last -ceq $OTHER_DONE_READY) } }
    'RC1h'   = @{ Desc = "U 지속 · 마감 회전의 짝 판독 바로 앞부터 Rr(회전 박자로 잼) → 첫 결측 = 마감 회전 → 첫 줄 1(⑨ 표식이 ⑩ 앞) · 재판독 0 · 'unconfirmed' → 진단 1 · 전송 0 문구 · 코드 4 (같은 행 전제)"
        Spec = @{ Timeline = @(@(0, 'U'), @($RETRY_RC1H_AT, 'Rr')) }
        Expect = { param($Row) (Test-RetryDeadlineTurnPair $Row) -and ($Row.Exit -ceq '__EXIT__4') -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 0) -and (@($Row.Clicks).Count -eq 0) -and ($Row.Attempts -eq 0) -and
            ($Row.Diags -eq 1) -and ($Row.Last -ceq $RETRY_DONE_UNCONFIRMED_NOSEND) } }
    'RC2a'   = @{ Desc = "'unconfirmed'(보상 아님 L) → 진단 1 · 전송 0 문구 · 코드 4"; Spec = @{ Timeline = @(,@(0, 'U')) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_DONE_UNCONFIRMED_NOSEND) -and ($Row.Diags -eq 1) -and ($Row.RetrySends -eq 0) } }
    'RC2b'   = @{ Desc = "'reclick' 둘째 호출이 'unconfirmed'(전송 뒤 U) → 진단 1 · 재클릭 호출 문구 · 코드 4"
        Spec = @{ Timeline = @(,@(0, 'R')); RetrySend = @{ 1 = @(,@(0, 'U')) }; ReentryStubs = @(, @{ Result = 'reclick'; LastKind = 'reward3' }) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_DONE_UNCONFIRMED_RESEND) -and ($Row.Diags -eq 1) -and ($Row.RetrySends -eq 1) -and ($Row.Reclicks -eq 1) } }
    'RC3'    = @{ Desc = "'skipped'(커서 미확인 3) → 커서 미확인 사유 줄 1 → 폴백 ① other 클릭 · 복귀 완료 · 코드 0"; Spec = @{ Timeline = @(,@(0, 'R')); CursorMisses = 3 }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $OTHER_DONE_READY) -and ($Row.CursorLines -eq 1) -and ($Row.RetrySends -eq 0) -and ($Row.OtherSends -eq 1) } }
    'RC4'    = @{ Desc = "클릭 직전 안전 중지 → 안전 중지 줄 1 · 'safe-stop' 반환(본류가 옛 나가기 - 구현 명세 ⑤b6) · other 대기 0 · 예약 그대로(소비 0) · 시간 줄 0 · 재판단 0"
        Spec = @{ Timeline = @(,@(0, 'R')); F9 = $true; Until = 1000; Verdict0 = 'continue' }
        Expect = { param($Row) ($Row.Exit -ceq '') -and ($Row.Error -ceq '') -and ($Row.Return -ceq 'safe-stop') -and ($Row.Last -ceq $RETRY_LINE_SAFE) -and ($Row.SafeLines -eq 1) -and ($Row.Removed -eq 0) -and $Row.FlagEnd -and
            ($Row.OtherWaits -eq 0) -and ($Row.LastLines -eq 0) -and ($Row.ContinueLines -eq 0) -and ($Row.UpdateCalls -eq 0) -and ($Row.RetrySends -eq 0) } }
    'RC5a'   = @{ Desc = "모드 예산 - 호출 B · 혼자하기 → -LimitSeconds = `$timeoutEntry(소스 캡처) · 필드 결과 끔(5b-8)"; Spec = @{ Timeline = @(,@(0, 'R')); ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) (@($Row.Reentry).Count -eq 1) -and (@($Row.Reentry)[0].Limit -eq $timeoutEntry) -and @($Row.Reentry)[0].Report -and (-not @($Row.Reentry)[0].ReportField) } }
    'RC5b'   = @{ Desc = "모드 예산 - 호출 B · 우연한 만남 → -LimitSeconds = `$timeoutPartyMatch(소스 캡처) · 필드 결과 켬(5b-8)"; Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) (@($Row.Reentry).Count -eq 1) -and (@($Row.Reentry)[0].Limit -eq $timeoutPartyMatch) -and @($Row.Reentry)[0].Report -and @($Row.Reentry)[0].ReportField } }
    'RC5c'   = @{ Desc = "모드 예산 - 호출 E · 혼자하기 → `$timeoutEntry · 보고 끔"; Spec = @{ Entry = 'other'; Recorded0 = $true; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) (@($Row.Reentry).Count -eq 1) -and (@($Row.Reentry)[0].Limit -eq $timeoutEntry) -and (-not @($Row.Reentry)[0].Report) -and (-not @($Row.Reentry)[0].ReportField) } }
    'RC5d'   = @{ Desc = "모드 예산 - 호출 E · 우연한 만남 → `$timeoutPartyMatch · 보고 끔"; Spec = @{ Mode = 'party'; Entry = 'other'; Recorded0 = $true; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) (@($Row.Reentry).Count -eq 1) -and (@($Row.Reentry)[0].Limit -eq $timeoutPartyMatch) -and (-not @($Row.Reentry)[0].Report) -and (-not @($Row.Reentry)[0].ReportField) } }
    'RC6'    = @{ Desc = '첫 시도 사건 차례 = 포커스 < 기록 < 안전 중지 확인 < 재판단 < 클릭 (R3 S6 · R5 2.3 ④)'; Spec = @{ Timeline = @(,@(0, 'R')); Until = 60; Verdict0 = 'continue'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) (Get-RetryEventOrder $Row) -ceq 'focus<attempt<safecheck<update<click' } }
    'RC7'    = @{ Desc = "원문 대기 · 'reclick' 둘째 호출의 짝 판독 2 · 3 번째 = Rr → 그 호출 안 결측 두 번(첫 줄 1 · 짝 없음 줄 1) → 'no-pair' → 폴백 ① · 코드 0 · 그 호출의 기록 · 재판단 0"
        Spec = @{ Timeline = @(,@(0, 'R')); Until = 60; Verdict0 = 'continue'; PairReadScreens = @{ 2 = 'Rr'; 3 = 'Rr' } }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.MissFirst -eq 1) -and ($Row.MissEnd -eq 1) -and ((Get-RetryClickText $Row) -ceq 'retry(636,654),other(778,654)') -and ($Row.Attempts -eq 1) -and ($Row.UpdateCalls -eq 1) } }
    'RC8'    = @{ Desc = '-Nonce 가 기록 셋 · 재입장 완료 줄에 같은 값'; Spec = @{ Timeline = @(,@(0, 'R')); ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Attempts -eq 1) -and ($Row.Clickeds -eq 1) -and ($Row.Reentereds -eq 1) -and ($Row.IhLines -eq 1) -and (Test-RetryNonce $Row) } }
    # 완료 기록 실제 파일 행 (명세 리뷰 2 P2 - 저장 경계 주입 · 끝 함수 사이 -Nonce 전달)
    'RC12'   = @{ Desc = "retry-clicked 기록 실패('locked' 주입) → 원문 [경고] 1 · 'sent' 그대로 → 재입장 대기 'entered' → 재입장 완료(reentered 는 retry-attempt 단계에서 - 원문 -Expect) · 코드 0"
        Spec = @{ Timeline = @(,@(0, 'R')); ReentryStubs = @(, $RETRY_STUB_ENTERED); StoreInject = @{ 'retry-clicked' = @('locked') } }
        Expect = { param($Row) $logList = @($Row.Logs); ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $RETRY_IH_LINE) -and ($Row.RetrySends -eq 1) -and ($Row.Clickeds -eq 1) -and ($Row.Reentereds -eq 1) -and
            (@($logList | Where-Object { $_ -ceq $RETRY_CLICKED_FAIL_LINE }).Count -eq 1) -and ([Array]::IndexOf($logList, $RETRY_CLICKED_FAIL_LINE) -lt [Array]::IndexOf($logList, $RETRY_IH_LINE)) } }
    'RV-NONCE1' = @{ Desc = "(-Nonce 행 꼴) 'skipped'(커서 미확인 3) → 폴백 ① 끝(other) → 대기 'no-pair' → 헬퍼 'matching' → 호출 E 'entered' → 재입장 완료 기록 · 완료 줄의 nonce = 행 nonce (끝(retry) 안 끝(other) 호출에 -Nonce 가 빠지면 완료 줄 'nonce=]' · 재입장 완료 기록 'expect-failed')"
        Spec = @{ Timeline = @(,@(0, 'R')); CursorMisses = 3; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching'; ReentryStubs = @(, $RETRY_STUB_ENTERED) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__0') -and ($Row.Last -ceq $RETRY_IH_LINE) -and ($Row.CursorLines -eq 1) -and ($Row.RetrySends -eq 0) -and ($Row.Helper -eq 1) -and
            (@($Row.Reentry).Count -eq 1) -and (-not @($Row.Reentry)[0].Report) -and ($Row.Reentereds -eq 1) -and (Test-RetryNonce $Row) } }
    # 구현 단위 5b-8 FC-X - 재매칭 패널 ESC 취소 → 필드 확정 'field-cancelled' (명세 5b-8 1 · 2.3 · 3.4). 원문 대기 행의 W 는 소스 캡처, 필드 확정 줄의 표본 수 · 초는 판독 기록에서 셈
    #   'field-cancelled' 끝 행(X1 · X2 · X3 · X5 · X7)은 '[완료]' 줄 1 · 입력(키 · 이벤트 정리 · 화면 좌표 클릭 · 클릭 반복) 0 도 봅니다 - 1절 4항 끝(구현 리뷰 2/2 의 4/5 · 변이 M83 · M85)
    'FC-X1'  = @{ Desc = "(K15b 꼴) commit 뒤 호출 B 'field-cancelled' → 입력 0(클릭 · 키 · 이벤트 정리) · 정지 줄(소스 캡처 - '[완료]' 줄은 그 하나) · 코드 4 · 시간 줄 ③ 0 · 11 0 · '다른 던전 가기' 대기 0 · 진단 · 헬퍼 · 복귀 0 · 예약 소비 0 · 필드 결과 켬(우연한 만남)"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); Until = 1000; Verdict0 = 'continue'; ReentryStubs = @(, @{ Result = 'field-cancelled'; LastKind = 'field'; PanelSeen = $true }) }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_DONE_FIELD_CANCELLED) -and ($Row.DoneLines -eq 1) -and ($Row.Inputs -eq 0) -and ($Row.ContinueLines -eq 0) -and ($Row.IhLines -eq 0) -and ($Row.OtherWaits -eq 0) -and
            ($Row.OtherSends -eq 0) -and ($Row.RetrySends -eq 1) -and ($Row.Reclicks -eq 0) -and ($Row.Diags -eq 0) -and ($Row.Helper -eq 0) -and ($Row.Return2 -ceq '') -and ($Row.Removed -eq 0) -and
            (@($Row.Reentry).Count -eq 1) -and @($Row.Reentry)[0].Report -and @($Row.Reentry)[0].ReportField } }
    'FC-X2'  = @{ Desc = "(U-5b8-1 · 1-I ② 꼴) 원문 대기 · 우연한 만남 · 재매칭 패널(M) → 로딩(U) → 필드 모양(F) 지속 → 필드 확정(W 소스 캡처 - 첫 F 표본부터 W 를 처음 넘긴 회전) 'field-cancelled' → 입력 0 · 정지 줄 · 코드 4 · retry 전송 총 1 · other 0 · 진단 0 · 패널 확인 줄 1 · 필드 확정 줄 1(마지막 앞 줄)"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); RetrySend = @{ 1 = @(@(0.5, 'M'), @(4.5, 'U'), @(9.5, 'F')) } }
        Expect = { param($Row) $reentryCall = @($Row.Reentry)[0]; $logList = @($Row.Logs)
            ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_DONE_FIELD_CANCELLED) -and ($Row.DoneLines -eq 1) -and ($Row.Inputs -eq 0) -and ($Row.RetrySends -eq 1) -and ($Row.OtherSends -eq 0) -and ($Row.OtherWaits -eq 0) -and ($Row.Reclicks -eq 0) -and
            ($Row.Diags -eq 0) -and ($Row.Helper -eq 0) -and ($Row.Return2 -ceq '') -and ($Row.Removed -eq 0) -and ($Row.IhLines -eq 0) -and ($Row.ContinueLines -eq 0) -and (@($Row.Reentry).Count -eq 1) -and
            ($reentryCall.Result -ceq 'field-cancelled') -and $reentryCall.Report -and $reentryCall.ReportField -and ($reentryCall.Limit -eq $timeoutPartyMatch) -and ($Row.PanelLines -eq 1) -and ($Row.SettleLines -eq 1) -and
            ($logList.Count -ge 2) -and ([string]$logList[$logList.Count - 2] -cmatch $SETTLE_PATTERN) -and (Test-RetryFieldSettleLine $Row) } }
    'FC-X3'  = @{ Desc = "FC-X2 들머리 + 전송 뒤 예약(F9 - WA-X3′ 꼴) → 끝 같음('field-cancelled' 정지 줄 · 코드 4) · 예약 그대로(정지 끝은 소비하지 않음 - GUI 가 코드 4 정지에서 지움) · 안전 중지 확인 줄 0"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); RetrySend = @{ 1 = @(@(0.5, 'M'), @(4.5, 'U'), @(9.5, 'F')) }; F9OnRetrySend = 1 }
        Expect = { param($Row) ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_DONE_FIELD_CANCELLED) -and ($Row.DoneLines -eq 1) -and ($Row.Inputs -eq 0) -and ($Row.RetrySends -eq 1) -and ($Row.OtherSends -eq 0) -and ($Row.Removed -eq 0) -and $Row.FlagEnd -and
            ($Row.Diags -eq 0) -and (@($Row.Logs | Where-Object { $_.StartsWith('[완료] 안전 중지 예약 확인', [StringComparison]::Ordinal) }).Count -eq 0) -and (@($Row.Reentry)[0].Result -ceq 'field-cancelled') } }
    'FC-X4'  = @{ Desc = "(U-5b8-1 혼자하기 제외) 원문 대기 · 혼자하기 · 전송 뒤 로딩(U) → 필드 모양(F) 지속 → 필드 결과 끔 → 모드 예산(`$timeoutEntry 소스 캡처) 뒤 'timeout' · 'none' 행 혼자하기 문구 · 진단 1 · 필드 확정 줄 0 · 패널 확인 줄 0"
        Spec = @{ Timeline = @(,@(0, 'R')); RetrySend = @{ 1 = @(@(1, 'U'), @(4, 'F')) } }
        Expect = { param($Row) $reentryCall = @($Row.Reentry)[0]; $waitSeconds = [double]$reentryCall.End - [double]$reentryCall.T
            ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_NONE_SOLO) -and ($Row.Diags -eq 1) -and ($Row.RetrySends -eq 1) -and ($Row.OtherSends -eq 0) -and (@($Row.Reentry).Count -eq 1) -and
            ($reentryCall.Result -ceq 'timeout') -and $reentryCall.Report -and (-not $reentryCall.ReportField) -and ($reentryCall.Limit -eq $timeoutEntry) -and
            ($waitSeconds -ge ($timeoutEntry - $TIME_EPSILON)) -and ($waitSeconds -lt ($timeoutEntry + 2)) -and ($Row.SettleLines -eq 0) -and ($Row.PanelLines -eq 0) } }
    'FC-X5'  = @{ Desc = "(U-5b8-1 '패널 관측과 무관' · 근거 0.3 ① 패널을 못 본 ESC) 원문 대기 · 우연한 만남 · 전송 뒤 패널 표본 없이 로딩(U) → 필드 모양(F) 지속 → 'field-cancelled' · 같은 끝 · 패널 확인 줄 0 · 필드 확정 줄 1"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); RetrySend = @{ 1 = @(@(0.5, 'U'), @(2.5, 'F')) } }
        Expect = { param($Row) $reentryCall = @($Row.Reentry)[0]
            ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_DONE_FIELD_CANCELLED) -and ($Row.DoneLines -eq 1) -and ($Row.Inputs -eq 0) -and ($reentryCall.Result -ceq 'field-cancelled') -and ($Row.PanelLines -eq 0) -and ($Row.SettleLines -eq 1) -and
            ($Row.RetrySends -eq 1) -and ($Row.OtherSends -eq 0) -and ($Row.Diags -eq 0) -and (Test-RetryFieldSettleLine $Row) } }
    'FC-X6'  = @{ Desc = "(명세 0.4 보고 끔 호출 그대로) 폴백 ② 호출 E · 우연한 만남 · 원문 대기 · 재매칭 패널(M) → 필드 모양(F) 지속 → 필드 결과 끔이라 확정이 결론 아님 → 모드 예산(`$timeoutPartyMatch) 뒤 'timeout' · 'none' 행 우연한 만남 문구 · 진단 1 · 패널 확인 줄 0(보고 끔) · 필드 확정 줄 0"
        Spec = @{ Mode = 'party'; Entry = 'other'; Recorded0 = $true; OtherStub = $RETRY_OTHER_NOPAIR; HelperResult = 'matching'; Timeline = @(@(0, 'M'), @(5, 'F')) }
        Expect = { param($Row) $reentryCall = @($Row.Reentry)[0]
            ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_NONE_PARTY) -and ($Row.Diags -eq 1) -and (@($Row.Reentry).Count -eq 1) -and (-not $reentryCall.Report) -and (-not $reentryCall.ReportField) -and
            ($reentryCall.Result -ceq 'timeout') -and (([double]$reentryCall.End - [double]$reentryCall.T) -ge ($timeoutPartyMatch - $TIME_EPSILON)) -and ($Row.PanelLines -eq 0) -and ($Row.SettleLines -eq 0) } }
    'FC-X7'  = @{ Desc = "(1-I ② 1차 재현 - 사고 케이스 · run_20261028_h21m01s11.log:44-54) 패널 +0.3 · 로딩 +3 · 필드 모양 +8 + 그 판의 조작 양보 셋(+2~+5 · +9~+13 · +21~+36) → ② 양보가 필드 연속을 끊고 양보 끝부터 다시 W → 'field-cancelled' (양보 시간은 W 에 들지 않음 - 규칙 4). 고치기 전 워커는 300 + 양보 합 뒤 'none' 행(실기 323초 꼴)"
        Spec = @{ Mode = 'party'; Timeline = @(,@(0, 'R')); RetrySend = @{ 1 = @(@(0.3, 'M'), @(3, 'U'), @(8, 'F')) }; Active = $RETRY_FIELD_INCIDENT_ACTIVE }
        Expect = { param($Row) $reentryCall = @($Row.Reentry)[0]; $endAt = [double]$reentryCall.End
            $activeEnds = @($RETRY_FIELD_INCIDENT_ACTIVE | Where-Object { [double]$_[0] -lt $endAt } | ForEach-Object { [double]$_[1] })
            $lastActiveEnd = $(if ($activeEnds.Count -gt 0) { [double]($activeEnds | Measure-Object -Maximum).Maximum } else { [double]-1 })
            ([Math]::Abs((Get-RetryFirstClick $Row) - $RETRY_FIELD_CLICK_AT) -lt $TIME_EPSILON) -and ($Row.Exit -ceq '__EXIT__4') -and ($Row.Last -ceq $RETRY_DONE_FIELD_CANCELLED) -and ($Row.DoneLines -eq 1) -and ($Row.Inputs -eq 0) -and
            ($reentryCall.Result -ceq 'field-cancelled') -and ($Row.Yields -eq $activeEnds.Count) -and (($endAt - $lastActiveEnd) -ge $memberFieldSettleSeconds) -and ($Row.PanelLines -eq 1) -and
            (Test-RetryFieldSettleLine $Row -After $lastActiveEnd) } }
}
"INFO ⑤b4: L ${RETRY_L}초 · 모드 예산 혼자하기 ${timeoutEntry}초 / 우연한 만남 ${timeoutPartyMatch}초 · 짝 재판독 대기(other 대기 ⑫ 캡처) ${RETRY_RECHECK_WAIT_MS}ms · 첫 시도 재판단 $(Format-Seconds $RETRY_FIRST_JUDGE)초 · 행 $($RETRY_ROWS.Count) · 경계 행 Rr 시작 RC1g $(Format-Seconds $RETRY_RC1G_AT)초 / RC1h $(Format-Seconds $RETRY_RC1H_AT)초 (마감 회전 $retryDeadlineTurn)"
$retryRowResults = @{}
foreach ($retryRowName in $RETRY_ROWS.Keys) {
    $retryRowEntry = $RETRY_ROWS[$retryRowName]
    $retryRow = Invoke-RetryRow -Spec $retryRowEntry.Spec
    $retryRowResults[$retryRowName] = $retryRow
    $retryRowOk = $false
    try { $retryRowOk = [bool](& $retryRowEntry.Expect $retryRow) } catch { $retryRowOk = $false }
    Check-True ('{0} {1}' -f $retryRowName, $retryRowEntry.Desc) $retryRowOk (Format-RetryRow $retryRow)
}
# RC9 (W-M6 의 잡는 행) - 재입장 완료 줄은 코드 0 · 11 이 같은 글자($IH_BODY + 표지 꼬리) - K1(0) · K2(11) 의 마지막 줄
Check-Equal 'RC9 재입장 완료 줄 = $IH_BODY + 꼬리 - 코드 0(K1) · 11(K2) 같은 글자 (exit/마지막 줄)' `
    ('{0}/{1} · {2}/{3}' -f $retryRowResults['K1'].Exit, $retryRowResults['K1'].Last, $retryRowResults['K2'].Exit, $retryRowResults['K2'].Last) ('__EXIT__0/{0} · __EXIT__11/{0}' -f $RETRY_IH_LINE)
# RC11 - 클릭 루프 반환 꼴(명세 1.2 · 1.7 - hashtable 하나 @{ Result; LastKind }): 들머리 click 이고 예외 없이 끝난 행 전부. 결과별 LastKind 값은 WA-S5a('unconfirmed') ·
#   WA-S8('skipped') · SW6br('no-pair') 행이 봅니다('unconfirmed' 의 값이 마지막 유효 분류인지 그 회전 분류인지는 행이 가르지 않음 - 마감 판정이 유효 회전에 떨어짐)
$retryShapeRows = @(foreach ($retryRowName in $RETRY_ROWS.Keys) { if (([string]$RETRY_ROWS[$retryRowName].Spec.Entry -eq 'click') -and ($retryRowResults[$retryRowName].Error -ceq '')) { '{0}={1}' -f $retryRowName, $retryRowResults[$retryRowName].Shape } })
$retryShapeBad = @($retryShapeRows | Where-Object { -not $_.EndsWith('=LastKind,Result', [StringComparison]::Ordinal) })
Check-True ('RC11 클릭 루프 반환 꼴 = hashtable 하나 @{{ Result; LastKind }} - 들머리 click · 예외 없는 행 {0} 전부' -f $retryShapeRows.Count) (($retryShapeRows.Count -ge 1) -and ($retryShapeBad.Count -eq 0)) ($retryShapeBad -join ' · ')
# J - 행별 완료 기록(명세 리뷰 2 P2 - 실제 파일의 상태와 저장 경계 호출 수를 함께): '저장 경계 호출(단계:태그 - * = 행이 주입) | 이 판 항목 단계/attempts/retryClicks | seq N'.
#   씨앗 = seq 5 · 이 판 항목 cleared(끝(other) 들머리의 Recorded0 · Role resume 행은 retry-attempt · attempts 1). 실제 쓰기의 'changed' 하나마다 seq +1 · 주입은 파일 무변경
$RETRY_JOURNAL_EXPECT = [ordered]@{
    'K1'        = 'retry-attempt:changed retry-clicked:changed reentered:changed | reentered/1/1 | seq 8'
    'K3'        = 'retry-attempt:changed | retry-attempt/1/0 | seq 6'
    'K4'        = 'retry-attempt:changed | retry-attempt/1/0 | seq 6'
    'K9'        = 'retry-attempt:changed retry-clicked:changed retry-clicked:changed reentered:changed | reentered/1/2 | seq 9'
    'K15b'      = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'WA-S7'     = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'WA-X4'     = 'retry-attempt:changed retry-clicked:changed retry-clicked:changed reentered:changed | reentered/1/2 | seq 9'
    'WA-X5'     = 'retry-attempt:changed retry-clicked:changed retry-clicked:changed | retry-clicked/1/2 | seq 8'
    'WA-X12'    = 'retry-attempt:locked* | cleared/0/0 | seq 5'
    'W13'       = 'retry-attempt:changed retry-clicked:changed reentered:expect-failed* | retry-clicked/1/1 | seq 7'
    'FB12'      = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'FB3'       = 'reentered:changed | reentered/1/0 | seq 6'
    'FB4'       = '(호출 0) | cleared/0/0 | seq 5'
    'SS10'      = 'reentered:changed | reentered/1/0 | seq 6'
    'RC10'      = 'reentered:changed | reentered/1/0 | seq 6'
    'RC1b'      = '(호출 0) | cleared/0/0 | seq 5'
    'RC2b'      = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'RC8'       = 'retry-attempt:changed retry-clicked:changed reentered:changed | reentered/1/1 | seq 8'
    'RC12'      = 'retry-attempt:changed retry-clicked:locked* reentered:changed | reentered/1/0 | seq 7'
    'RV-NONCE1' = 'retry-attempt:changed reentered:changed | reentered/1/0 | seq 7'
    # 구현 단위 5b-8 FC-J1~J7 - 'field-cancelled' 끝은 클릭 뒤 기록 그대로(reentered · 추가 retry-clicked · 새 단계값 0) · 호출 E 행(FC-X6)은 씨앗 그대로 · 쓰기 0
    'FC-X1'     = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'FC-X2'     = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'FC-X3'     = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'FC-X4'     = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'FC-X5'     = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
    'FC-X6'     = '(호출 0) | retry-attempt/1/0 | seq 5'
    'FC-X7'     = 'retry-attempt:changed retry-clicked:changed | retry-clicked/1/1 | seq 7'
}
foreach ($journalRowName in $RETRY_JOURNAL_EXPECT.Keys) {
    Check-Equal ('J-{0} 완료 기록(실제 파일) - 저장 경계 호출(단계:태그 · * 주입) | 이 판 항목 단계/attempts/retryClicks | seq' -f $journalRowName) $retryRowResults[$journalRowName].JournalText $RETRY_JOURNAL_EXPECT[$journalRowName]
}
# J0 - §10 행 전부: 파일 상태 = 저장 경계 호출 기록(Get-RetryJournalProblems - seq · savedAt(쓰기 직후 훅) · 단계 · 횟수 · 시각 · 그 밖 필드 · 지난 판 항목 · 항목 2 · 잠금 · 임시본 · 직전본)
$retryJournalBad = @(foreach ($retryRowName in $RETRY_ROWS.Keys) { foreach ($journalProblem in @($retryRowResults[$retryRowName].JournalProblems)) { '{0}: {1}' -f $retryRowName, $journalProblem } })
Check-True ('J0 §10 행 {0} 전부 - 완료 기록 파일 상태 = 저장 경계 호출 기록(실제 쓰기의 changed 만 바꿈 · seq · savedAt · 단계 · 횟수 · 시각 · 그 밖 필드 · 지난 판 항목 · 잠금 · 임시본 · 직전본)' -f $RETRY_ROWS.Count) `
    ($retryJournalBad.Count -eq 0) (($retryJournalBad | Select-Object -First 6) -join ' · ')
# ── §10 정적 (명세 3.2 - 주석 뺀 사본 · AST) ──
$retryClickWhile = @($retryClickNode.FindAll({ param($candidate) $candidate -is [WhileStatementAst] }, $true)) | Select-Object -First 1
$retryClickLoopStatements = $(if ($null -ne $retryClickWhile) { @($retryClickWhile.Body.Statements) } else { @() })
$RETRY_MISS_CONDITION = "(`$screen -eq 'reward3') -and (`$null -eq `$pairRead.Retry)"
$RETRY_CLICK_CONDITION = "(`$screen -eq 'reward3') -and (`$null -ne `$pairRead.Retry)"
$RETRY_RESET_CONDITION = '-not ' + '(' + $RETRY_MISS_CONDITION + ')'
$RETRY_VALIDITY_CODE = '$script:screenCaptureFailing -or $script:captureFailSerial -ne $turnSerial'

# R5-P1(⑤b4) - 회전 순서(뜻 - 평가 순서 · §8 Get-EvaluationKey): 앵커가 평가 순서로 증가 · 동결 블록 = 원문 다섯 문장(other 대기의 여섯에서 출처 폐기를 뺀 꼴) · ⑥ 앵커 없음(명세 어-56).
#   ⑨ 앵커 = 짝 없음 결론 if(조건 정확 일치) - 같은 회전 ⑩ 마감보다 먼저(명세 리뷰 1 확인 · 어-64). other 대기 판에 없는 앵커입니다
#   서두 판독값 비움 앵커 둘($screen = '' · $pairRead = $null - 명세 1.2 서두 · 1.7 규칙 4)도 other 대기 판에 없습니다 - 판독 없는 회전이 옛 분류 · 옛 점으로 누르지 않는 자리(행 WA-S11a~c)
$RETRY_R5P1_ANCHORS = @(
    @{ Label = '서두 메타 비움'; Match = { param($Node) ($Node -is [AssignmentStatementAst]) -and (Test-IsVariable $Node.Left 'script:lastClickSkipReason') } },
    @{ Label = '서두 분류 비움'; Match = { param($Node) ($Node -is [AssignmentStatementAst]) -and (Test-IsVariable $Node.Left 'screen') -and ((Get-NodeCode $Node.Right) -ceq "''") } },
    @{ Label = '서두 짝 판독 비움'; Match = { param($Node) ($Node -is [AssignmentStatementAst]) -and (Test-IsVariable $Node.Left 'pairRead') -and ((Get-NodeCode $Node.Right) -ceq '$null') } },
    @{ Label = '① 동결'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-IsVariable $Node.Clauses[0].Item1 'script:screenCaptureFailing') } },
    @{ Label = '② 양보'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasCommand $Node.Clauses[0].Item1 'Test-UserRecentlyActive') } },
    @{ Label = '③ 탐침 복구 뒤'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-IsVariable $Node.Clauses[0].Item1 'probeRecovered') } },
    @{ Label = '④ 스윕 분류'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Resolve-AbyssMemberSweepTurn') } },
    @{ Label = '⑤ 짝 판독'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Find-AbyssRewardButtonPair') } },
    @{ Label = '⑤ 패널 판독'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Get-AbyssPanelKind') } },
    @{ Label = 'catch'; Match = { param($Node) $Node -is [CatchClauseAst] } },
    @{ Label = '⑦ 유효성'; Match = { param($Node) ($Node -is [IfStatementAst]) -and (Test-HasVariable $Node.Clauses[0].Item1 'script:screenCaptureFailing') -and (Test-HasVariable $Node.Clauses[0].Item1 'turnSerial') } },
    @{ Label = '⑧ 분류'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Resolve-AbyssHandoffStartScreen') } },
    @{ Label = '⑨ 짝 없음 결론'; Match = { param($Node) ($Node -is [IfStatementAst]) -and ((Get-OtherFlatCode $Node.Clauses[0].Item1) -ceq $RETRY_MISS_CONDITION) } },
    @{ Label = '⑩ 마감'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Test-AbyssMemberClockExpired') -and (Test-IsVariable (Get-CommandArgument -Command $Node -Name 'Clock') 'clickClock') } },
    @{ Label = '⑪ 클릭'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Click-GamePoint') } },
    @{ Label = '⑫ 기본 대기'; Match = { param($Node) ($Node -is [CommandAst]) -and ($Node.GetCommandName() -eq 'Start-Sleep') -and ($null -ne (Get-CommandArgument -Command $Node -Name 'Milliseconds' -PositionalNames @())) -and
            ((ConvertTo-AstKey (Get-CommandArgument -Command $Node -Name 'Milliseconds' -PositionalNames @())) -ceq $BASE_WAIT_KEY) } })
function Get-RetryR5P1Problems {
    # 어긋난 점 목록 (열거용 - 호출부에서 @()) - §8 Get-R5P1Problems 꼴(평가 순서 키 · 동결 블록 원문 요소)
    $problemList = New-Object System.Collections.Generic.List[string]
    if ($null -eq $retryClickWhile) { $problemList.Add('while 없음'); return $problemList.ToArray() }
    $keyedNodes = @(foreach ($bodyNode in @($retryClickWhile.Body.FindAll({ param($candidate) $true }, $true))) { [pscustomobject]@{ Key = (Get-EvaluationKey $bodyNode); Start = $bodyNode.Extent.StartOffset; Node = $bodyNode } })
    $keyedNodes = @($keyedNodes | Sort-Object Key, Start)
    $previousKey = [long]-1
    $freezeIf = $null
    foreach ($anchor in $RETRY_R5P1_ANCHORS) {
        $anchorHit = $null
        foreach ($keyedNode in $keyedNodes) { if (($keyedNode.Key -gt $previousKey) -and (& $anchor.Match $keyedNode.Node)) { $anchorHit = $keyedNode; break } }
        if ($null -eq $anchorHit) { $problemList.Add("빠짐·순서[$($anchor.Label)]"); return $problemList.ToArray() }
        if ($anchor.Label -eq '① 동결') { $freezeIf = $anchorHit.Node }
        $previousKey = $anchorHit.Key
    }
    # 동결 블록 = 원문 다섯 문장(안전 확인 · Start-Sleep · [void] 탐침(-Game $Game) · 탐침 표식(플래그의 부정) · 단독 줄 continue) · 절 1 · elseif·else 0
    if (($freezeIf.Clauses.Count -ne 1) -or ($null -ne $freezeIf.ElseClause)) { $problemList.Add('동결 elseif/else') }
    $freezeStatements = @($freezeIf.Clauses[0].Item2.Statements)
    if ($freezeStatements.Count -ne 5) { $problemList.Add("동결 문장 수 $($freezeStatements.Count)"); return $problemList.ToArray() }
    $safeStopCommand = Get-StatementCommand $freezeStatements[0]
    if (($null -eq $safeStopCommand) -or ($safeStopCommand.GetCommandName() -ne 'Test-SafeStopDuringCaptureFail')) { $problemList.Add('동결 1(안전 확인)') }
    $sleepCommand = Get-StatementCommand $freezeStatements[1]
    if (($null -eq $sleepCommand) -or ($sleepCommand.GetCommandName() -ne 'Start-Sleep')) { $problemList.Add('동결 2(Start-Sleep)') }
    $probeOk = $false
    $voidNode = Get-InnerExpression $freezeStatements[2]
    if (($voidNode -is [ConvertExpressionAst]) -and ((Get-ResolvedTypeName $voidNode.Type.TypeName) -eq 'System.Void')) {
        $probePipeline = Get-InnerExpression $voidNode.Child
        if (($probePipeline -is [PipelineAst]) -and ($probePipeline.PipelineElements.Count -eq 1) -and ($probePipeline.PipelineElements[0] -is [CommandAst]) -and
            ($probePipeline.PipelineElements[0].GetCommandName() -eq 'Test-CaptureRecovered') -and (Test-IsVariable (Get-CommandArgument -Command $probePipeline.PipelineElements[0] -Name 'Game') 'Game')) { $probeOk = $true }
    }
    if (-not $probeOk) { $problemList.Add('동결 3([void] 탐침)') }
    if (-not (($freezeStatements[3] -is [AssignmentStatementAst]) -and (Test-IsVariable $freezeStatements[3].Left 'probeRecovered') -and ((ConvertTo-AstKey $freezeStatements[3].Right) -ceq 'Un(Not|V(script:screencapturefailing))'))) { $problemList.Add('동결 4(탐침 표식)') }
    if (-not (($freezeStatements[4] -is [ContinueStatementAst]) -and ($null -eq $freezeStatements[4].Label) -and ((Get-LineCode $freezeStatements[4]) -ceq 'continue'))) { $problemList.Add('동결 5(단독 줄 continue)') }
    return $problemList.ToArray()
}
$retryR5P1Problems = @(Get-RetryR5P1Problems)
Check-True 'R5-P1(⑤b4) 회전 순서(뜻 - 평가 순서): 서두 메타 비움 < 서두 판독값 비움(분류 · 짝) < ① 동결 < ② 양보 < ③ 탐침 복구 뒤 < ④ 스윕 분류 < ⑤ 짝 < 패널 < catch < ⑦ 유효성 < ⑧ 분류 < ⑨ 짝 없음 결론(조건 정확 일치) < ⑩ 마감($clickClock) < ⑪ 클릭 < ⑫ 기본 대기 · 동결 블록 = 원문 다섯 문장 · ⑥ 앵커 없음' `
    ($retryR5P1Problems.Count -eq 0) ($retryR5P1Problems -join ' · ')

# R5-P2(⑤b4) - 시계: New 1(루프 밖) · 루프 안 Set·Suspend·Resume·마감 조정 셋 0 · AddSeconds·AddMilliseconds 0
$retryNewClocks = @(Get-CommandNodes -Node $retryClickNode -Name 'New-AbyssMemberClock')
$retryNewInLoop = @($retryNewClocks | Where-Object { Test-AstWithin -Node $_ -Ancestor $retryClickWhile }).Count
$retryForbiddenClock = @(@('Set-AbyssMemberClock', 'Suspend-AbyssMemberClock', 'Resume-AbyssMemberClock', 'Get-YieldAdjustedDeadline', 'Invoke-UserYieldWithDeadline', 'Get-FreezeAdjustedDeadline') | Where-Object { Test-HasCommand $retryClickNode $_ })
$retryAddCalls = @($retryClickNode.FindAll({ param($candidate) ($candidate -is [InvokeMemberExpressionAst]) -and (@('AddSeconds', 'AddMilliseconds') -contains $candidate.Member.Extent.Text) }, $true)).Count
Check-Equal 'R5-P2(⑤b4) 시계 - New 1 · 루프 안 New 0 · 금지 명령(Set · Suspend · Resume · 마감 조정 셋) [] · AddSeconds·AddMilliseconds 0' `
    ('{0}/{1}/[{2}]/{3}' -f $retryNewClocks.Count, $retryNewInLoop, ($retryForbiddenClock -join ','), $retryAddCalls) '1/0/[]/0'

# R5-P12(⑤b4) - 회전 수준 한 줄 동결 if 0 (while 직속 · 조건 = 플래그 정확히 · 한 줄)
$retryOneLineFreeze = @($retryClickLoopStatements | Where-Object { ($_ -is [IfStatementAst]) -and (Test-IsVariable $_.Clauses[0].Item1 'script:screenCaptureFailing') -and ($_.Extent.StartLineNumber -eq $_.Extent.EndLineNumber) }).Count
$retryAnyOneLineFreeze = @($retryClickNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-IsVariable $candidate.Clauses[0].Item1 'script:screenCaptureFailing') -and ($candidate.Extent.StartLineNumber -eq $candidate.Extent.EndLineNumber) }, $true)).Count
Check-Equal 'R5-P12(⑤b4) 한 줄 동결 if - while 직속 / 함수 전체' ('{0}/{1}' -f $retryOneLineFreeze, $retryAnyOneLineFreeze) '0/0'

# R5-P13(⑤b4) - 짝 < 패널 < 클릭 · 패널과 클릭 사이 화면 판독 0 (주석 뺀 회전 본문)
$retryLoopText = $workerCode.Substring($retryClickWhile.Body.Extent.StartOffset, $retryClickWhile.Body.Extent.EndOffset - $retryClickWhile.Body.Extent.StartOffset)
$retryPairAt = $retryLoopText.IndexOf('Find-AbyssRewardButtonPair', [StringComparison]::Ordinal)
$retryPanelAt = $retryLoopText.IndexOf('Get-AbyssPanelKind', [StringComparison]::Ordinal)
$retryClickAt = $retryLoopText.IndexOf('Click-GamePoint', [StringComparison]::Ordinal)
$retryReadsBetween = $(if (($retryPanelAt -ge 0) -and ($retryClickAt -gt $retryPanelAt)) { [regex]::Matches($retryLoopText.Substring($retryPanelAt + 'Get-AbyssPanelKind'.Length, $retryClickAt - $retryPanelAt - 'Get-AbyssPanelKind'.Length), $OTHER_READ_NAMES).Count } else { -1 })
Check-Equal 'R5-P13(⑤b4) 짝 < 패널 < 클릭 / 패널과 클릭 사이 판독' ('{0}/{1}' -f (($retryPairAt -ge 0) -and ($retryPairAt -lt $retryPanelAt) -and ($retryPanelAt -lt $retryClickAt)), $retryReadsBetween) 'True/0'

# R5-P16(⑤b4) - 창 좌표 throw 제한 catch: try 1 · try 본문 = ④ 스윕 if + ⑤ 판독 if · catch 판정 = §8 Get-WindowCatchProblems(절 1 · 형식 0 · 단독 throw · 잎 셋 정확 일치)
function Get-RetryR5P16Problems {
    $problemList = New-Object System.Collections.Generic.List[string]
    $tryNodes = @($retryClickNode.FindAll({ param($candidate) $candidate -is [TryStatementAst] }, $true))
    if ($tryNodes.Count -ne 1) { $problemList.Add("try $($tryNodes.Count)개"); return $problemList.ToArray() }
    $turnStatements = @($tryNodes[0].Body.Statements)
    if (($turnStatements.Count -ne 2) -or (-not ($turnStatements[0] -is [IfStatementAst])) -or (-not (Test-HasCommand $turnStatements[0].Clauses[0].Item1 'Invoke-PurchasePopupSweep')) -or
        (-not ($turnStatements[1] -is [IfStatementAst])) -or (-not (Test-HasCommand $turnStatements[1].Clauses[0].Item2 'Find-AbyssRewardButtonPair'))) { $problemList.Add("try 본문 = ④ 스윕 if + ⑤ 판독 if 가 아님(문장 $($turnStatements.Count)개)") }
    foreach ($catchProblem in @(Get-WindowCatchProblems -TryNode $tryNodes[0])) { $problemList.Add($catchProblem) }
    return $problemList.ToArray()
}
$retryR5P16Problems = @(Get-RetryR5P16Problems)
Check-True "R5-P16(⑤b4) 창 좌표 throw 제한 catch - try 1 · try 본문 = ④ 스윕 if + ⑤ 판독 if · catch 절 1 · 형식 0 · 단독 throw · 조건 = -not(플래그 ∧ 원인 = $WINDOW_GONE_CAUSE ∧ 메시지 ∈ 두 캡처 문구)" `
    ($retryR5P16Problems.Count -eq 0) ($retryR5P16Problems -join ' · ')

# WAIT(⑤b4) - 대기 값 정확 고정 (명세 3.2 · B-15 - ⑤b3 WAIT 꼴): ① 동결 블록 Start-Sleep = 선분기 동결 대기 · ⑫ while 끝 네 문장 = 굶김 continue → 복구(선분기 복구 대기) →
#   짝 재판독(계약 1초 - 소스 캡처 아님: 클릭 루프 자신에서 캡처하면 값 변이를 따라 움직임 · ④:3062~3064 와 같은 이유) → 기본(선분기 기본 대기)
function Get-RetryWaitShape {
    if ($null -eq $retryClickWhile) { return '(while 없음)' }
    $loopStatements = @($retryClickWhile.Body.Statements)
    $freezeIfs = @($loopStatements | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-OtherFlatCode $_.Clauses[0].Item1) -ceq '$script:screenCaptureFailing') })
    $freezeText = "(동결 if $($freezeIfs.Count)개)"
    if ($freezeIfs.Count -eq 1) {
        $freezeSleeps = @(foreach ($freezeStatement in @($freezeIfs[0].Clauses[0].Item2.Statements)) {
                $freezeCommand = Get-StatementCommand $freezeStatement
                if (($null -ne $freezeCommand) -and ($freezeCommand.GetCommandName() -eq 'Start-Sleep')) { Get-OtherSleepText $freezeStatement }
            })
        $freezeText = $freezeSleeps -join '; '
    }
    if ($loopStatements.Count -lt 4) { return ('① 동결 {{ {0} }} · ⑫ (while 문장 {1}개)' -f $freezeText, $loopStatements.Count) }
    $tailParts = @()
    foreach ($tailStatement in @($loopStatements[($loopStatements.Count - 4)..($loopStatements.Count - 1)])) {
        if ($tailStatement -is [IfStatementAst]) {
            $tailBody = (@($tailStatement.Clauses[0].Item2.Statements | ForEach-Object { Get-OtherSleepText $_ })) -join '; '
            $tailElse = $(if (($tailStatement.Clauses.Count -ne 1) -or ($null -ne $tailStatement.ElseClause)) { ' + elseif/else' } else { '' })
            $tailParts += ('if ({0}) {{ {1} }}{2}' -f (Get-OtherFlatCode $tailStatement.Clauses[0].Item1), $tailBody, $tailElse)
        } else {
            $tailParts += (Get-OtherSleepText $tailStatement)
        }
    }
    return ('① 동결 {{ {0} }} · ⑫ {1}' -f $freezeText, ($tailParts -join ' · '))
}
Check-Equal 'WAIT(⑤b4) 대기 값 - ① 동결 블록 Start-Sleep = 선분기 동결 대기 · ⑫ while 끝 네 문장 = 굶김 continue(대기 0) → 복구(선분기 복구 대기) → 짝 재판독(계약 1초) → 기본(선분기 기본 대기) - 차례 · 갈래 조건 · 인자 값(ms)' `
    (Get-RetryWaitShape) $otherWaitShapeWant

# WAIT-N(⑤b4) - 클릭 루프 안 Start-Sleep = 4: ① 동결 1 · ⑫ 대기 3 · 지정 자리 밖 0 (확인 창 없음 - 명세 3.2)
function Get-RetrySleepPlace {
    param($SleepNode)
    if ($null -eq $retryClickWhile) { return '지정 자리 밖' }
    $loopStatements = @($retryClickWhile.Body.Statements)
    $topStatement = $null
    for ($currentNode = $SleepNode; $null -ne $currentNode.Parent; $currentNode = $currentNode.Parent) {
        if ([object]::ReferenceEquals($currentNode.Parent, $retryClickWhile.Body)) { $topStatement = $currentNode; break }
    }
    if ($null -eq $topStatement) { return '지정 자리 밖' }
    if (($topStatement -is [IfStatementAst]) -and ((Get-OtherFlatCode $topStatement.Clauses[0].Item1) -ceq '$script:screenCaptureFailing') -and
        ($topStatement.Extent.StartLineNumber -ne $topStatement.Extent.EndLineNumber)) { return '① 동결' }
    if (($loopStatements.Count -ge 4) -and ([Array]::IndexOf($loopStatements, $topStatement) -ge ($loopStatements.Count - 4))) { return '⑫ 대기' }
    return '지정 자리 밖'
}
$RETRY_SLEEP_PLACE_NAMES = @('① 동결', '⑫ 대기', '지정 자리 밖')
$retrySleepNodes = @(Get-CommandNodes -Node $retryClickNode -Name 'Start-Sleep')
$retrySleepPlaces = @($retrySleepNodes | ForEach-Object { Get-RetrySleepPlace $_ })
$retrySleepOutside = @(for ($sleepIndex = 0; $sleepIndex -lt $retrySleepNodes.Count; $sleepIndex++) { if ($retrySleepPlaces[$sleepIndex] -ceq '지정 자리 밖') { Get-NodeCode $retrySleepNodes[$sleepIndex] } })
$retrySleepReport = ('{0} = {1}' -f $retrySleepNodes.Count, ((@(foreach ($sleepPlaceName in $RETRY_SLEEP_PLACE_NAMES) { '{0} {1}' -f $sleepPlaceName, @($retrySleepPlaces | Where-Object { $_ -ceq $sleepPlaceName }).Count })) -join ' · ')) +
    $(if ($retrySleepOutside.Count -gt 0) { ' [' + ($retrySleepOutside -join ' | ') + ']' } else { '' })
Check-Equal 'WAIT-N(⑤b4) 클릭 루프 안 Start-Sleep = 4 - ① 동결(2초) 1 · ⑫ 대기(복구 2초 · 짝 재판독 1초 · 기본 700ms · 굶김 0) 3 · 지정 자리 밖 0' $retrySleepReport '4 = ① 동결 1 · ⑫ 대기 3 · 지정 자리 밖 0'

# P5d-7 - 짝 없음 재판독 자리 (명세 3.2 · 시제품 판 RC-P1~P4)
$retryValidityIf = @($retryClickNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and ((Get-OtherFlatCode $candidate.Clauses[0].Item1) -ceq $RETRY_VALIDITY_CODE) -and ($null -ne $candidate.ElseClause) }, $true)) | Select-Object -First 1
$retryMissIfs = @($retryClickNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and ((Get-OtherFlatCode $candidate.Clauses[0].Item1) -ceq $RETRY_MISS_CONDITION) }, $true))
$retryMissIf = $(if ($retryMissIfs.Count -eq 1) { $retryMissIfs[0] } else { $null })
function Get-RetryTopStatement { param($Node) for ($currentNode = $Node; $null -ne $currentNode.Parent; $currentNode = $currentNode.Parent) { if ([object]::ReferenceEquals($currentNode.Parent, $retryClickWhile.Body)) { return $currentNode } }; return $null }
function Get-RetryVariablePlace {
    # 변수 자리 - init(while 밖) · miss(짝 없음 if 안) · valid(⑦ 유효 갈래 else 안 - 짝 없음 if 밖) · prologue(while 직속 대입) · wait12(⑫ 네 문장) · 그 밖 elsewhere
    param($Node)
    $topStatement = Get-RetryTopStatement $Node
    if ($null -eq $topStatement) { return 'init' }
    if (($null -ne $retryMissIf) -and (Test-AstWithin -Node $Node -Ancestor $retryMissIf)) { return 'miss' }
    if (($null -ne $retryValidityIf) -and (Test-AstWithin -Node $Node -Ancestor $retryValidityIf.ElseClause)) { return 'valid' }
    if ($topStatement -is [AssignmentStatementAst]) { return 'prologue' }
    if ([Array]::IndexOf($retryClickLoopStatements, $topStatement) -ge ($retryClickLoopStatements.Count - 4)) { return 'wait12' }
    return 'elsewhere'
}
function Get-RetryVariableReport {
    param([string]$Name)
    $variableNodes = @($retryClickNode.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -eq $Name) }, $true))
    $variableParts = foreach ($variableNode in $variableNodes) {
        $variableRole = $(if (($variableNode.Parent -is [AssignmentStatementAst]) -and [object]::ReferenceEquals($variableNode.Parent.Left, $variableNode)) { '=' + (Get-NodeCode $variableNode.Parent.Right) } else { 'read' })
        '{0}:{1}' -f (Get-RetryVariablePlace $variableNode), $variableRole
    }
    return ((@($variableParts) | Sort-Object) -join ' · ')
}
# ① 셈($pairMisses) - 루프 앞 = 0 · ⑦ 유효 갈래 비움 = 0(조건 정확 일치는 ④ 의 차례에서) · 짝 없음 if 의 읽기 · = 1 / 그 밖 0
Check-Equal 'P5d-7 ① 짝 없음 셈 $pairMisses 자리 = 루프 앞 = 0 · ⑦ 유효 갈래 = 0 · 짝 없음 갈래의 읽기 · = 1 (동결 · 양보 블록 안 0)' (Get-RetryVariableReport 'pairMisses') 'init:=0 · miss:=1 · miss:read · valid:=0'
# ② 재판독 표식($pairRecheck) - 서두 = $false · 짝 없음 갈래 = $true · ⑫ 읽기
Check-Equal 'P5d-7 ② 짝 재판독 표식 $pairRecheck 자리 = 서두 = $false · 짝 없음 갈래 = $true · ⑫ 읽기' (Get-RetryVariableReport 'pairRecheck') 'miss:=$true · prologue:=$false · wait12:read'
# ③ 짝 없음 갈래 안 차례 - 둘째 결측 if(짝 없음 줄 · 'no-pair' 반환) < 셈 1 < 표식 < 첫 결측 줄
$retryMissOrder = $(if ($null -ne $retryMissIf) {
        (@($retryMissIf.Clauses[0].Item2.Statements | ForEach-Object {
                    $missStatement = $_
                    if ($missStatement -is [IfStatementAst]) {
                        $innerParts = @($missStatement.Clauses[0].Item2.Statements | ForEach-Object {
                                $innerCommand = Get-StatementCommand $_
                                if (($null -ne $innerCommand) -and ($innerCommand.GetCommandName() -eq 'Write-RunLog')) { 'log(' + $(if ((Get-NodeCode $_).Contains("'다른 던전 가기' 로 선택 화면에서 마칩니다")) { '마칩니다' } else { '?' }) + ')' }
                                elseif ($_ -is [ReturnStatementAst]) { 'return ' + $(if ((Get-NodeCode $_) -ceq "return @{ Result = 'no-pair'; LastKind = `$screen }") { 'no-pair' } else { '?' }) }
                                else { Get-NodeCode $_ }
                            })
                        'if ({0}) {{ {1} }}' -f (Get-OtherFlatCode $missStatement.Clauses[0].Item1), ($innerParts -join '; ')
                    } else {
                        $missCommand = Get-StatementCommand $missStatement
                        if (($null -ne $missCommand) -and ($missCommand.GetCommandName() -eq 'Write-RunLog')) { 'log(' + $(if ((Get-NodeCode $missStatement).Contains('1초 뒤 다시 읽습니다')) { '1초 뒤' } else { '?' }) + ')' }
                        else { Get-NodeCode $missStatement }
                    }
                })) -join ' < '
    } else { "(짝 없음 if $($retryMissIfs.Count)개)" })
Check-Equal 'P5d-7 ③ 짝 없음 갈래 안 차례 = 둘째 결측 if(짝 없음 줄 · no-pair) < 셈 1 < 표식 < 첫 결측 줄' $retryMissOrder 'if ($pairMisses -ge 1) { log(마칩니다); return no-pair } < $pairMisses = 1 < $pairRecheck = $true < log(1초 뒤)'
# ④ ⑨ 자리 - 짝 없음 if 는 ⑦ 유효 갈래(else) 직속의 마지막 문장 · 그 갈래 차례 = ⑧ 분류 대입 < 셈 비움 if(조건 정확 일치) < 짝 없음 if / while 직속 차례 = (⑦ 을 품은) 판독 회전 if < ⑩ 마감 if <
#   클릭 if(조건 정확 일치) < ⑫ 네 문장 - 결론이 같은 회전의 마감보다 먼저(명세 리뷰 1 확인 · 어-64)
$retryValidStatements = $(if (($null -ne $retryValidityIf) -and ($null -ne $retryValidityIf.ElseClause)) { @($retryValidityIf.ElseClause.Statements) } else { @() })
$retryScreenAt = -1; $retryResetAt = -1
for ($validIndex = 0; $validIndex -lt $retryValidStatements.Count; $validIndex++) {
    $validStatement = $retryValidStatements[$validIndex]
    if (($validStatement -is [AssignmentStatementAst]) -and (Test-IsVariable $validStatement.Left 'screen') -and (Test-HasCommand $validStatement.Right 'Resolve-AbyssHandoffStartScreen')) { $retryScreenAt = $validIndex }
    if (($validStatement -is [IfStatementAst]) -and ((Get-OtherFlatCode $validStatement.Clauses[0].Item1) -ceq $RETRY_RESET_CONDITION)) { $retryResetAt = $validIndex }
}
$retryMissAt = $(if ($null -ne $retryMissIf) { [Array]::IndexOf($retryValidStatements, $retryMissIf) } else { -1 })
$retryOuterAt = $(if ($null -ne $retryValidityIf) { [Array]::IndexOf($retryClickLoopStatements, (Get-RetryTopStatement $retryValidityIf)) } else { -1 })
$retryDeadlineAt = -1
for ($loopIndex = 0; $loopIndex -lt $retryClickLoopStatements.Count; $loopIndex++) {
    $loopStatement = $retryClickLoopStatements[$loopIndex]
    if (($loopStatement -is [IfStatementAst]) -and (Test-HasCommand $loopStatement.Clauses[0].Item1 'Test-AbyssMemberClockExpired')) { $retryDeadlineAt = $loopIndex }
}
$retryClickIfAt = -1
for ($loopIndex = 0; $loopIndex -lt $retryClickLoopStatements.Count; $loopIndex++) {
    $loopStatement = $retryClickLoopStatements[$loopIndex]
    if (($loopStatement -is [IfStatementAst]) -and ((Get-OtherFlatCode $loopStatement.Clauses[0].Item1) -ceq $RETRY_CLICK_CONDITION)) { $retryClickIfAt = $loopIndex }
}
$retryTailAt = $retryClickLoopStatements.Count - 4
$retryP4Ok = ($retryScreenAt -ge 0) -and ($retryScreenAt -lt $retryResetAt) -and ($retryResetAt -lt $retryMissAt) -and ($retryMissAt -eq ($retryValidStatements.Count - 1)) -and
    ($retryOuterAt -ge 0) -and ($retryOuterAt -lt $retryDeadlineAt) -and ($retryDeadlineAt -lt $retryClickIfAt) -and ($retryClickIfAt -lt $retryTailAt)
Check-True 'P5d-7 ④ ⑨ 자리 - 짝 없음 if = ⑦ 유효 갈래 직속 마지막(⑧ 분류 < 셈 비움 < 짝 없음 if) · while 직속 판독 회전 if < ⑩ 마감 if < 클릭 if < ⑫ (같은 회전의 마감보다 먼저 - 어-64)' $retryP4Ok `
    ('⑦ 유효 갈래[⑧ {0} < 셈 비움 {1} < 짝 없음 if {2} / 문장 {3}] · while[판독 회전 if {4} < ⑩ {5} < 클릭 if {6} < ⑫ {7}]' -f $retryScreenAt, $retryResetAt, $retryMissAt, $retryValidStatements.Count, $retryOuterAt, $retryDeadlineAt, $retryClickIfAt, $retryTailAt)

# R3 S2 · S6 · S7 · S10 - 클릭 자리 (설계 v11 R3 6.6 - 5b-4 몫)
$retryClickIfNode = $(if ($retryClickIfAt -ge 0) { $retryClickLoopStatements[$retryClickIfAt] } else { $null })
$retryClickIfBody = $(if ($null -ne $retryClickIfNode) { @($retryClickIfNode.Clauses[0].Item2.Statements) } else { @() })
$retryCommitIfAt = -1; $retryAttemptIfAt = -1
for ($bodyIndex = 0; $bodyIndex -lt $retryClickIfBody.Count; $bodyIndex++) {
    $bodyStatement = $retryClickIfBody[$bodyIndex]
    if (($bodyStatement -is [IfStatementAst]) -and ((Get-OtherFlatCode $bodyStatement.Clauses[0].Item1) -ceq '-not $script:abyssRetryCommitted')) { $retryCommitIfAt = $bodyIndex }
    if (($bodyStatement -is [IfStatementAst]) -and ((Get-OtherFlatCode $bodyStatement.Clauses[0].Item1) -ceq '-not $script:abyssRetryAttemptRecorded')) { $retryAttemptIfAt = $bodyIndex }
}
$retryAfterCommit = $(if (($retryCommitIfAt -ge 0) -and (($retryCommitIfAt + 1) -lt $retryClickIfBody.Count)) { Get-NodeCode $retryClickIfBody[$retryCommitIfAt + 1] } else { '(없음)' })
$retryCommitBody = $(if ($retryCommitIfAt -ge 0) { @($retryClickIfBody[$retryCommitIfAt].Clauses[0].Item2.Statements) } else { @() })
$retryCommitShape = (@($retryCommitBody | ForEach-Object { if ($_ -is [IfStatementAst]) { $commitCondition = Get-OtherFlatCode $_.Clauses[0].Item1; $(if ($commitCondition -ceq 'Test-Path -LiteralPath $safeStopFlagPath') { '안전 중지' } elseif ($commitCondition -ceq "(Update-AbyssRetryTimeVerdict) -eq 'last'") { '재판단' } else { '?' + $commitCondition }) } else { '?' + (Get-NodeCode $_) } })) -join ' < '
$retryUpdateOwners = @(Get-CommandNodes -Node $workerAst -Name 'Update-AbyssRetryTimeVerdict' | ForEach-Object { Get-EnclosingFunctionName $_ })
$retryUpdateInCommit = @(Get-CommandNodes -Node $retryClickNode -Name 'Update-AbyssRetryTimeVerdict' | Where-Object { ($retryCommitIfAt -ge 0) -and (Test-AstWithin -Node $_ -Ancestor $retryClickIfBody[$retryCommitIfAt]) }).Count
# (⑤b5 3.4) 본류 몫 = 보상 결정 ① - 본류 보상 화면 꼬리의 첫 if ($retryRoute) 안에서 Resolve-AbyssRewardDecision 의 -TimeVerdict 인자 그 자체(괄호 안 파이프라인의 유일한 원소)
$retryUpdateMainNodes = @(Get-CommandNodes -Node $workerAst -Name 'Update-AbyssRetryTimeVerdict' | Where-Object { (Get-EnclosingFunctionName $_) -eq '' })
$retryUpdateInDecision = @($retryUpdateMainNodes | Where-Object {
        $updateNode = $_
        $decisionCall = $updateNode.Parent
        while (($null -ne $decisionCall) -and -not ($decisionCall -is [CommandAst])) { $decisionCall = $decisionCall.Parent }
        $timeArgument = $(if (($null -ne $decisionCall) -and ($decisionCall.GetCommandName() -eq 'Resolve-AbyssRewardDecision')) { Get-InnerExpression (Get-CommandArgument -Command $decisionCall -Name 'TimeVerdict' -PositionalNames @()) } else { $null })
        ($timeArgument -is [PipelineAst]) -and ($timeArgument.PipelineElements.Count -eq 1) -and [object]::ReferenceEquals($timeArgument.PipelineElements[0], $updateNode) -and
            (@(Get-OtherAncestorIfs $updateNode | Where-Object { (Get-OtherFlatCode $_.Clauses[0].Item1) -ceq '$retryRoute' }).Count -eq 1)
    }).Count
Check-Equal 'R3 S2 Update-AbyssRetryTimeVerdict 호출 = 클릭 루프 1(commit 표지 거짓 갈래 안 - 5b-4) + 재개 끝 1(소유자 - 재평가 결정 -TimeVerdict 인자 자리는 ⑲ 5C-S3 · ⑤c 5c-3) + 본류 1(if ($retryRoute) 안 보상 결정 -TimeVerdict 인자 - ⑤b5)' `
    ('{0} · 갈래 안 {1} · 본류 결정 인자 {2}/{3}' -f ($retryUpdateOwners -join ','), $retryUpdateInCommit, $retryUpdateInDecision, $retryUpdateMainNodes.Count) 'Invoke-AbyssRetryClick,Complete-AbyssResumeWait, · 갈래 안 1 · 본류 결정 인자 1/1'
Check-Equal 'R3 S6 클릭 자리 차례 - 첫 시도 기록 if < commit 표지 거짓 갈래(안전 중지 < 재판단) < 바로 다음 문장 retry Click-GamePoint(사이 문장 0)' `
    ('기록<갈래={0} · 갈래[{1}] · 다음 = {2}' -f (($retryAttemptIfAt -ge 0) -and ($retryAttemptIfAt -lt $retryCommitIfAt)), $retryCommitShape, $retryAfterCommit) `
    '기록<갈래=True · 갈래[안전 중지 < 재판단] · 다음 = Click-GamePoint -Game $Game -ReferenceX $pairRead.Retry.X -ReferenceY $pairRead.Retry.Y'
$retryCommitAssigns = @($workerAst.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'script:abyssRetryCommitted') }, $true))
$retryCommitFirst = @($retryCommitAssigns | Where-Object {
        $commitAssign = $_
        $ownerBlock = $commitAssign.Parent
        ($ownerBlock -is [StatementBlockAst]) -and ($ownerBlock.Parent -is [IfStatementAst]) -and (Test-IsVariable $ownerBlock.Parent.Clauses[0].Item1 'script:lastClickPerformed') -and
            [object]::ReferenceEquals(@($ownerBlock.Statements)[0], $commitAssign) -and (Test-IsVariable $commitAssign.Right 'true')
    }).Count
# (⑤b5 3.4 · ⑤c 2.10) 대입 3 = 참 2(전송 확인 if 의 첫 문장 · 승계 함수 Set-AbyssResumeCommit) + 거짓 1(본류 보상 화면 꼬리 첫 문장 ⓪ - 자리 '' = 본류 · 우변 $false).
#   이 단언은 참 대입 수와 전송 확인 if 첫 문장만 봅니다 - 승계 함수 안의 자리(조건 없는 본문 문장)는 5c-2 의 5C-S1 이 고정합니다
$retryCommitTrue = @($retryCommitAssigns | Where-Object { Test-IsVariable $_.Right 'true' }).Count
$retryCommitZero = @($retryCommitAssigns | Where-Object { ((Get-EnclosingFunctionName $_) -eq '') -and (Test-IsVariable $_.Right 'false') }).Count
Check-Equal 'R3 S7 commit 표지 대입 = 워커 전체 3 · 참 2(그중 전송 확인 if($script:lastClickPerformed) 의 첫 문장 1 - 나머지 하나는 승계 함수, 그 자리는 5C-S1) · 거짓 1 = 본류 ⓪(⑤b5)' `
    ('{0} · 참 {1}/{2} · 본류 ⓪ 거짓 {3}' -f $retryCommitAssigns.Count, $retryCommitTrue, $retryCommitFirst, $retryCommitZero) '3 · 참 2/1 · 본류 ⓪ 거짓 1'
$retryClickSites = @(Get-CommandNodes -Node $workerAst -Name 'Click-GamePoint' | Where-Object { (Get-NodeCode (Get-CommandArgument -Command $_ -Name 'ReferenceX' -PositionalNames @())) -ceq '$pairRead.Retry.X' })
Check-Equal "R3 S10 retry 짝 클릭(Click-GamePoint -ReferenceX `$pairRead.Retry.X) = 워커 전체 1 · 자리 = 클릭 루프" ('{0} · {1}' -f $retryClickSites.Count, ((@($retryClickSites | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ',')) '1 · Invoke-AbyssRetryClick'
# R3 S5 · S8 ②③ - $script:abyssUntil 은 새 함수에서 HH:mm 서식(줄 ②③)으로만 · 줄 ② = 클릭 루프 'last' 갈래 안 1 · 줄 ③ = 재입장 완료 끝의 [완료] 줄 앞 1 ·
#   재개 끝 1(재개 판단 'time' 사유 - ⑤c 5c-3)
$retryUntilUses = @(foreach ($retryFunctionName in @('Invoke-AbyssRetryClick', 'Complete-AbyssRetrySelection', 'Complete-AbyssInsideHandoff', 'Stop-AbyssReentryTimeout', 'Get-AbyssReentryLimitSeconds', 'Complete-AbyssOtherSelection', 'Complete-AbyssResumeWait')) {
        foreach ($untilUse in @((Get-WorkerFunction $retryFunctionName).FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -eq 'script:abyssUntil') }, $true))) {
            $isClockFormat = ($untilUse.Parent -is [InvokeMemberExpressionAst]) -and ($untilUse.Parent.Member.Extent.Text -eq 'ToString') -and ((@($untilUse.Parent.Arguments | ForEach-Object { $_.Extent.Text }) -join ',') -eq "'HH:mm'")
            '{0}:{1}' -f $retryFunctionName, $(if ($isClockFormat) { 'HH:mm' } else { 'other' })
        }
    })
Check-Equal 'R3 S5(5b-4 몫 · ⑤c 5c-3) 새 함수 · 넓힌 끝 함수의 $script:abyssUntil 사용 = HH:mm 서식뿐 (클릭 루프 1 · 재입장 완료 끝 1 · 재개 끝 1 - 재개 판단 time 사유)' (($retryUntilUses | Sort-Object) -join ' · ') 'Complete-AbyssInsideHandoff:HH:mm · Complete-AbyssResumeWait:HH:mm · Invoke-AbyssRetryClick:HH:mm'
$retryLineTwoNodes = @($workerAst.FindAll({ param($candidate) ($candidate -is [ExpandableStringExpressionAst]) -and ([string]$candidate.Value).StartsWith("[어비스] '다시 하기' 직전 판단: 지정 시간 ", [StringComparison]::Ordinal) }, $true))
$retryLineThreeNodes = @($workerAst.FindAll({ param($candidate) ($candidate -is [ExpandableStringExpressionAst]) -and ([string]$candidate.Value).StartsWith('[어비스] 지정 시간 ', [StringComparison]::Ordinal) -and ([string]$candidate.Value).Contains("전에 '다시 하기'로 이어 가기로 정했습니다") }, $true))
$retryLineTwoInLast = @($retryLineTwoNodes | Where-Object { @(Get-OtherAncestorIfs $_ | Where-Object { (Get-OtherFlatCode $_.Clauses[0].Item1) -ceq "(Update-AbyssRetryTimeVerdict) -eq 'last'" }).Count -eq 1 }).Count
$retryInsideStatements = @($retryInsideNode.Body.EndBlock.Statements)
$retryDoneAt = -1; $retryLineThreeAt = -1
for ($insideIndex = 0; $insideIndex -lt $retryInsideStatements.Count; $insideIndex++) {
    $insideStatement = $retryInsideStatements[$insideIndex]
    if ((Get-NodeCode $insideStatement).Contains('[terminal=InsideHandoff')) { $retryDoneAt = $insideIndex }
    if ((@($retryLineThreeNodes | Where-Object { Test-AstWithin -Node $_ -Ancestor $insideStatement }).Count -gt 0) -and ($retryLineThreeAt -lt 0)) { $retryLineThreeAt = $insideIndex }
}
Check-Equal 'R3 S8 ②③ - 줄 ② 워커 전체 1 · 클릭 루프의 재판단 last 갈래 안 / 줄 ③ 워커 전체 1 · 재입장 완료 끝 [완료] 줄 앞 (②자리/③자리 · ③ < 완료 줄)' `
    ('{0}/{1}:{2} · {3}/{4} · {5}' -f $retryLineTwoNodes.Count, $retryLineTwoInLast, ((@($retryLineTwoNodes | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ','), $retryLineThreeNodes.Count,
        ((@($retryLineThreeNodes | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ','), (($retryLineThreeAt -ge 0) -and ($retryLineThreeAt -lt $retryDoneAt))) '1/1:Invoke-AbyssRetryClick · 1/Complete-AbyssInsideHandoff · True'

# R1 6.4 - 재입장 완료 끝: 'continue' if 본문 = exit 11 하나 · 다음 문장 exit 0 · 차례 = reentered 기록 < [완료] … [terminal=InsideHandoff 줄 < exit · 그 구간 Get-Date · Get-DgTimeVerdict 0 ·
#   어비스 몫 exit 11 은 이 한 곳(던전 · 파티원 11 은 그대로 - exit 11 의 소유 함수 집합)
$retryInsideCodes = @($retryInsideStatements | ForEach-Object { Get-NodeCode $_ })
$retryReenteredAt = -1
for ($insideIndex = 0; $insideIndex -lt $retryInsideStatements.Count; $insideIndex++) { if ((Get-NodeCode $retryInsideStatements[$insideIndex]) -ceq 'Set-AbyssJournalReentered -Nonce $Nonce') { $retryReenteredAt = $insideIndex } }
$retryContinueIfAt = -1
for ($insideIndex = 0; $insideIndex -lt $retryInsideStatements.Count; $insideIndex++) {
    $insideStatement = $retryInsideStatements[$insideIndex]
    if (($insideStatement -is [IfStatementAst]) -and ($insideIndex -gt $retryDoneAt) -and ((Get-OtherFlatCode $insideStatement.Clauses[0].Item1) -ceq "`$script:abyssRetryTimeVerdict -eq 'continue'")) { $retryContinueIfAt = $insideIndex }
}
$retryContinueBody = $(if ($retryContinueIfAt -ge 0) { ((@($retryInsideStatements[$retryContinueIfAt].Clauses[0].Item2.Statements | ForEach-Object { Get-NodeCode $_ })) -join ' ; ') + $(if ($null -ne $retryInsideStatements[$retryContinueIfAt].ElseClause) { ' + else' } else { '' }) } else { '(없음)' })
$retryAfterContinue = $(if (($retryContinueIfAt -ge 0) -and (($retryContinueIfAt + 1) -lt $retryInsideStatements.Count)) { Get-NodeCode $retryInsideStatements[$retryContinueIfAt + 1] } else { '(없음)' })
$retryTailNodes = $(if ($retryDoneAt -ge 0) { @($retryInsideStatements[$retryDoneAt..($retryInsideStatements.Count - 1)]) } else { @() })
$retryTailClock = @($retryTailNodes | ForEach-Object { @(Get-CommandNodes -Node $_ -Name 'Get-Date').Count + @(Get-CommandNodes -Node $_ -Name 'Get-DgTimeVerdict').Count } | Measure-Object -Sum).Sum
$retryExitElevenOwners = @($workerAst.FindAll({ param($candidate) ($candidate -is [ExitStatementAst]) -and ($null -ne $candidate.Pipeline) -and ((Get-NodeCode $candidate.Pipeline) -ceq '11') }, $true) | ForEach-Object { Get-EnclosingFunctionName $_ })
$retryExitElevenSet = ((@($retryExitElevenOwners | Sort-Object -Unique)) -join ',')
$retryExitElevenInside = @($retryExitElevenOwners | Where-Object { $_ -ceq 'Complete-AbyssInsideHandoff' }).Count
Check-Equal "R1 6.4 재입장 완료 끝 - 'continue' if 본문 = exit 11 · 다음 = exit 0 · reentered 기록 < [완료] 줄 < exit · 그 구간 Get-Date·Get-DgTimeVerdict 0 · exit 11 소유 = {재입장 완료 끝 1 · 파티원 · 던전}" `
    ('{0} / {1} / {2} / 시각 {3} / {4}·{5}' -f $retryContinueBody, $retryAfterContinue, (($retryReenteredAt -ge 0) -and ($retryReenteredAt -lt $retryDoneAt) -and ($retryDoneAt -lt $retryContinueIfAt)), $retryTailClock, $retryExitElevenSet, $retryExitElevenInside) `
    'exit 11 / exit 0 / True / 시각 0 / Complete-AbyssInsideHandoff,Invoke-AbyssPartyMemberCycle,Invoke-NormalDungeonCycle·1'

# R5-P10 - 모드 예산 한 함수: 정의 1 · 재입장 대기 호출(끝 둘)의 -LimitSeconds = 그 함수 결과(리터럴 0) · 'none' 행 두 문구의 초 변수 = 같은 갈래(혼자하기 = $timeoutEntry · 그 밖 $timeoutPartyMatch)
$retryLimitDefinitions = @($workerAst.FindAll({ param($candidate) ($candidate -is [FunctionDefinitionAst]) -and ($candidate.Name -eq 'Get-AbyssReentryLimitSeconds') }, $true)).Count
$retryLimitBody = (@($retryLimitNode.Body.EndBlock.Statements | ForEach-Object { Get-NodeCode $_ })) -join ' ; '
$retryLimitArgs = @(foreach ($limitOwner in @('Complete-AbyssRetrySelection', 'Complete-AbyssOtherSelection')) {
        foreach ($limitCall in @(Get-CommandNodes -Node (Get-WorkerFunction $limitOwner) -Name 'Wait-AbyssReentry')) { '{0}:{1}' -f $limitOwner, (Get-NodeCode (Get-CommandArgument -Command $limitCall -Name 'LimitSeconds' -PositionalNames @())) }
    })
$retryNoneIf = @($retryNoneNode.Body.EndBlock.Statements | Where-Object { $_ -is [IfStatementAst] }) | Select-Object -First 1
$retryNoneShape = $(if ($null -ne $retryNoneIf) {
        $noneSoloVars = @($retryNoneIf.Clauses[0].Item2.FindAll({ param($candidate) $candidate -is [VariableExpressionAst] }, $true) | ForEach-Object { $_.VariablePath.UserPath } | Sort-Object -Unique) -join ','
        $noneAfter = @($retryNoneNode.Body.EndBlock.Statements | Where-Object { $_.Extent.StartOffset -gt $retryNoneIf.Extent.EndOffset })
        $nonePartyVars = @($noneAfter | ForEach-Object { $_.FindAll({ param($candidate) $candidate -is [VariableExpressionAst] }, $true) } | ForEach-Object { $_.VariablePath.UserPath } | Sort-Object -Unique) -join ','
        '{0} → [{1}] / 그 밖 [{2}]' -f (Get-OtherFlatCode $retryNoneIf.Clauses[0].Item1), $noneSoloVars, $nonePartyVars
    } else { '(갈래 없음)' })
Check-Equal "R5-P10 모드 예산 - 정의 1 · 본문 · 재입장 대기 호출의 -LimitSeconds = (Get-AbyssReentryLimitSeconds) · 'none' 행 갈래와 초 변수" `
    ('{0} · {1} · [{2}] · {3}' -f $retryLimitDefinitions, $retryLimitBody, (($retryLimitArgs | Sort-Object) -join ' | '), $retryNoneShape) `
    ("1 · if (`$dungeonMode -eq 'solo') { return `$timeoutEntry } ; return `$timeoutPartyMatch · [Complete-AbyssOtherSelection:(Get-AbyssReentryLimitSeconds) | Complete-AbyssRetrySelection:(Get-AbyssReentryLimitSeconds)] · `$dungeonMode -eq 'solo' → [timeoutEntry] / 그 밖 [timeoutPartyMatch]")

# R6-P9 - 폴백 ② 의 호출 E 갈래: 조건 = (패널 셋 정확 일치 -contains [string]$exitClick.Result) ∧ (retry-attempt 표식 ∨ Role resume) 두 항 · 그 갈래 안 $safeStopFlagPath 0 (SS10 짝)
$retryCallEIfs = @($otherFinishNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-HasVariable $candidate.Clauses[0].Item1 'exitClick') }, $true))
$retryCallEReport = '(갈래 없음)'
if ($retryCallEIfs.Count -eq 1) {
    $callELeaves = @(Get-AndLeaves $retryCallEIfs[0].Clauses[0].Item1)
    $callEPanel = @($callELeaves | Where-Object { $_ -is [BinaryExpressionAst] -and (@('Icontains', 'Ccontains') -contains [string]$_.Operator) })
    $callEPanelSet = $(if ($callEPanel.Count -eq 1) { $panelList = Get-StringConstantList $callEPanel[0].Left; $(if ($null -ne $panelList) { (@($panelList) | Sort-Object) -join ',' } else { '(상수 목록 아님)' }) + ' ∋ ' + (Get-NodeCode $callEPanel[0].Right) } else { "(contains 잎 $($callEPanel.Count)개)" })
    $callEOrLeaves = @($callELeaves | Where-Object { -not ($_ -is [BinaryExpressionAst] -and (@('Icontains', 'Ccontains') -contains [string]$_.Operator)) } | ForEach-Object { (@(Get-OrLeaves $_ | ForEach-Object { Get-NodeCode $_ })) -join ' ∨ ' })
    $callESafe = [regex]::Matches((Get-NodeCode $retryCallEIfs[0].Clauses[0].Item2), '\$safeStopFlagPath\b').Count
    $retryCallEReport = '잎 {0} · 패널 [{1}] · 둘째 [{2}] · 갈래 안 예약 {3}' -f $callELeaves.Count, $callEPanelSet, ($callEOrLeaves -join ' / '), $callESafe
}
Check-Equal 'R6-P9 폴백 ② 호출 E 조건 = 패널 셋 모두(matching 하나 아님) ∧ (retry-attempt 표식 ∨ Role resume) · 그 갈래 안 안전 중지 예약 0' $retryCallEReport `
    "잎 2 · 패널 [entry-waiting,matching,ready-panel ∋ [string]`$exitClick.Result] · 둘째 [`$script:abyssRetryAttemptRecorded ∨ [string]`$script:handoff.Role -eq 'resume'] · 갈래 안 예약 0"

# P5d-0 - 클릭 루프의 분류 호출 1 · 인자 = -PromptVisible $false(상수 - S 를 읽지 않음) + 네 판독 변수 그대로 · -SelectionVisible · -MenuVisible · -DetailVisible 0
$retryClassifyCalls = @(Get-CommandNodes -Node $retryClickNode -Name 'Resolve-AbyssHandoffStartScreen')
Check-Equal 'P5d-0 클릭 루프 분류 호출 1 = -PromptVisible $false · 하단 = 짝 판독문 · 패널 · HUD · 추적기 변수 그대로 · 선택 화면·메뉴·상세 인자 0' `
    ('{0} · {1}' -f $retryClassifyCalls.Count, ((@($retryClassifyCalls | ForEach-Object { Get-NodeCode $_ })) -join ' | ')) `
    '1 · Resolve-AbyssHandoffStartScreen -PromptVisible $false -BottomText ([string]$pairRead.Text) -PanelKind $panelKind -HudVisible $hudNow -InDungeonQuest $questNow'

# P5d-1 - 새 함수 다섯 · 넓힌 끝 함수의 호출 자리 (⑤b5 3.4 - 두 끝 함수만 본류 보상 화면 꼬리에서 1씩: 'other' 갈래 · 'retry' 갈래. 나머지는 본류 0 그대로.
#   ⑤c 5c-1 - 재개 시계 New-AbyssResumeClock 이 모드 예산을 부름. 5c-2 - 선분기(던전 안 2연속 · ⑩ 재개 시계)와 재개 끝('entered' · 'cancelled' · 'timeout')이 재입장 완료 · none 행 ·
#   끝(other)을 부름. 5c-3 - 재개 끝이 끝(retry)(재클릭)과 'record-failed' 의 끝(other) -ExitOnly 를 부름 - 구현 명세 ⑤c 3.2 (가)~(다))
$RETRY_SITE_NAMES = @('Get-AbyssReentryLimitSeconds', 'Invoke-AbyssRetryClick', 'Complete-AbyssInsideHandoff', 'Stop-AbyssReentryTimeout', 'Complete-AbyssOtherSelection', 'Complete-AbyssRetrySelection')
$retrySiteReport = @(foreach ($siteName in $RETRY_SITE_NAMES) { $siteNodes = @(Get-CommandNodes -Node $workerAst -Name $siteName); '{0}={1}[{2}]' -f $siteName, $siteNodes.Count, ((@($siteNodes | ForEach-Object { $siteOwner = Get-EnclosingFunctionName $_; $(if ($siteOwner) { $siteOwner } else { '(본류)' }) } | Sort-Object)) -join ',') }) -join ' · '
Check-Equal 'P5d-1 새 함수 · 넓힌 끝 함수의 호출 자리 (모드 예산 3(끝 둘 + 재개 시계 - ⑤c) · 클릭 루프 1 · 재입장 완료 4 · none 행 4(끝 둘 + 선분기 · 재개 끝 - ⑤c 5c-2) · 끝(other) = 끝(retry) 3 + 재개 끝 2 + 본류 1 · 끝(retry) = 재개 끝 1 + 본류 1 - ⑤b5 · ⑤c 5c-3)' $retrySiteReport `
    ('Get-AbyssReentryLimitSeconds=3[Complete-AbyssOtherSelection,Complete-AbyssRetrySelection,New-AbyssResumeClock] · Invoke-AbyssRetryClick=1[Complete-AbyssRetrySelection] · ' +
        'Complete-AbyssInsideHandoff=4[Complete-AbyssOtherSelection,Complete-AbyssResumeWait,Complete-AbyssRetrySelection,Invoke-AbyssHandoffStart] · ' +
        'Stop-AbyssReentryTimeout=4[Complete-AbyssOtherSelection,Complete-AbyssResumeWait,Complete-AbyssRetrySelection,Invoke-AbyssHandoffStart] · ' +
        'Complete-AbyssOtherSelection=6[(본류),Complete-AbyssResumeWait,Complete-AbyssResumeWait,Complete-AbyssRetrySelection,Complete-AbyssRetrySelection,Complete-AbyssRetrySelection] · Complete-AbyssRetrySelection=2[(본류),Complete-AbyssResumeWait]')

# P5d-2 - 첫 시도 표식 $script:abyssRetryAttemptRecorded 대입 = 클릭 루프 안 $true 1 + 본류 보상 화면 꼬리 첫 문장 ⓪ 의 $false 1(⑤b5 - 소스 차례 · 자리 '' = 본류)
$retryRecordedAssigns = @($workerAst.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'script:abyssRetryAttemptRecorded') }, $true) | ForEach-Object { '{0}:{1}' -f (Get-EnclosingFunctionName $_), (Get-NodeCode $_.Right) })
Check-Equal 'P5d-2 $script:abyssRetryAttemptRecorded 대입 = 클릭 루프 안 $true 1 · 본류 ⓪ $false 1(⑤b5)' ($retryRecordedAssigns -join ' · ') 'Invoke-AbyssRetryClick:$true · :$false'

# P5d-3 - 끝(retry)의 return = 'record-failed' 1 + 클릭 직전 재검사 값('safe-stop' · 'last') 1(구현 명세 ⑤b6 1.6 - 본류가 옛 나가기) · 끝(other) · 재입장 완료 · 'none' 행 마지막 문장 = exit
#   (그 밖에 본류로 돌아오는 길 0 - 차례는 P5d-8)
$retryFinishReturns = @($retryFinishNode.FindAll({ param($candidate) $candidate -is [ReturnStatementAst] }, $true) | ForEach-Object { Get-NodeCode $_ })
$retryLastExits = @(foreach ($lastName in @('Complete-AbyssOtherSelection', 'Complete-AbyssInsideHandoff', 'Stop-AbyssReentryTimeout')) { $lastStatement = @((Get-WorkerFunction $lastName).Body.EndBlock.Statements)[-1]; '{0}:{1}' -f $lastName, $(if ($lastStatement -is [ExitStatementAst]) { Get-NodeCode $lastStatement } else { '(exit 아님)' }) })
Check-Equal "P5d-3 끝(retry) return = 'record-failed' 1 · 클릭 직전 재검사 값 1(⑤b6) · 끝(other) · 재입장 완료 · none 행의 마지막 문장 = exit" ('{0} · {1}' -f ($retryFinishReturns -join ' | '), ($retryLastExits -join ' · ')) `
    "return 'record-failed' | return `$retryResult · Complete-AbyssOtherSelection:exit 0 · Complete-AbyssInsideHandoff:exit 0 · Stop-AbyssReentryTimeout:exit 4"

# P5d-4 - 클릭 루프 안 Test-Path -LiteralPath $safeStopFlagPath 1(commit 표지 거짓 갈래 안 - R5 2.8 의 유일한 허용 자리) · Remove-Item 0
$retryTestPaths = @(Get-CommandNodes -Node $retryClickNode -Name 'Test-Path')
$retryTestPathInCommit = @($retryTestPaths | Where-Object { ($retryCommitIfAt -ge 0) -and (Test-AstWithin -Node $_ -Ancestor $retryClickIfBody[$retryCommitIfAt]) -and ((Get-NodeCode $_) -ceq 'Test-Path -LiteralPath $safeStopFlagPath') }).Count
Check-Equal 'P5d-4 클릭 루프 Test-Path(예약) 1 · commit 표지 거짓 갈래 안 1 · Remove-Item 0' ('{0}/{1}/{2}' -f $retryTestPaths.Count, $retryTestPathInCommit, @(Get-CommandNodes -Node $retryClickNode -Name 'Remove-Item').Count) '1/1/0'

# P5d-5 - Wait-AbyssReentry 호출의 보고 스위치 - 끝(retry) 안 1 · -ReportRewardReturn 있음(호출 B) / 끝(other) 안 1 · 없음(호출 E - 설계 v11 R5 3.1 · 3.6 · 범위 ⑤-21)
$retryReportShape = @(foreach ($reportOwner in @('Complete-AbyssRetrySelection', 'Complete-AbyssOtherSelection')) {
        $reportCalls = @(Get-CommandNodes -Node (Get-WorkerFunction $reportOwner) -Name 'Wait-AbyssReentry')
        '{0}:{1}/{2}' -f $reportOwner, $reportCalls.Count, @($reportCalls | Where-Object { @($_.CommandElements | Where-Object { ($_ -is [CommandParameterAst]) -and ($_.ParameterName -eq 'ReportRewardReturn') }).Count -gt 0 }).Count
    }) -join ' · '
Check-Equal 'P5d-5 재입장 대기 호출 / 보고 켬 - 끝(retry) 1/1 (호출 B) · 끝(other) 1/0 (호출 E)' $retryReportShape 'Complete-AbyssRetrySelection:1/1 · Complete-AbyssOtherSelection:1/0'

# P5d-6 - 끝(retry) 안 끝(other) 호출 3 의 -Ending = 'ready' 2 · 'rematch-cancelled' 1 - 'rematch-cancelled' 호출은 대기 결과 'cancelled' 갈래 안(설계 v11 R6 3.5 ①) · 셋 다 -Nonce $Nonce
#   (호출 E 의 재입장 완료 기록 · 완료 줄 nonce 가 이 인자에서 옵니다 - 매개변수 기본값 '' 라 빠뜨려도 조용히 지나가 완료 줄이 'nonce=]' 가 됨)
$retryEndingCalls = @(Get-CommandNodes -Node $retryFinishNode -Name 'Complete-AbyssOtherSelection' | ForEach-Object {
        $endingValue = Get-InnerExpression (Get-CommandArgument -Command $_ -Name 'Ending' -PositionalNames @())
        $endingText = $(if ($endingValue -is [StringConstantExpressionAst]) { [string]$endingValue.Value } elseif ($null -eq $endingValue) { '(생략)' } else { '(상수 아님)' })
        $nonceText = $(if (Test-IsVariable (Get-CommandArgument -Command $_ -Name 'Nonce' -PositionalNames @()) 'Nonce') { '+nonce' } else { '+(nonce 아님)' })
        $inCancelled = @(Get-OtherAncestorIfs $_ | Where-Object { (Get-OtherFlatCode $_.Clauses[0].Item1) -ceq "`$reentryResult -eq 'cancelled'" }).Count -gt 0
        '{0}{1}{2}' -f $endingText, $nonceText, $(if ($inCancelled) { '@cancelled' } else { '' })
    } | Sort-Object)
Check-Equal "P5d-6 끝(retry) 안 끝(other) 호출 -Ending = ready 2 · rematch-cancelled 1('cancelled' 갈래 안) · 셋 다 -Nonce `$Nonce" ($retryEndingCalls -join ',') 'ready+nonce,ready+nonce,rematch-cancelled+nonce@cancelled'

# P5d-8 (구현 명세 ⑤b6 3.2 · 1.6) - 끝(retry) while 직속의 클릭 루프 결과 분기 차례 = 'record-failed' 반환 < 'safe-stop'·'last' 반환(return $retryResult - 본류가 옛 나가기) < 'unconfirmed' 정지 <
#   폴백 ①(-ne 'sent' → '다른 던전 가기'). 두 값이 폴백 ① 뒤로 가면 멈출 때도 '다른 던전 가기' 로 끝납니다(행으로는 K3 · K4 · K7 · K16 · K17 · RC4)
$retryFinishWhile = @($retryFinishNode.FindAll({ param($candidate) $candidate -is [WhileStatementAst] }, $true)) | Select-Object -First 1
$retryFinishOrder = '(while 없음)'
if ($null -ne $retryFinishWhile) {
    $retryFinishOrder = (@($retryFinishWhile.Body.Statements | Where-Object { $_ -is [IfStatementAst] } | ForEach-Object {
                $finishCondition = Get-NodeCode $_.Clauses[0].Item1
                $finishBody = (@($_.Clauses[0].Item2.Statements | ForEach-Object { Get-NodeCode $_ })) -join ' ; '
                if ($finishCondition -ceq "`$retryResult -eq 'record-failed'") { 'record-failed[' + $finishBody + ']' }
                elseif ($finishCondition -ceq "(`$retryResult -eq 'safe-stop') -or (`$retryResult -eq 'last')") { 'safe-stop·last[' + $finishBody + ']' }
                elseif ($finishCondition -ceq "`$retryResult -eq 'unconfirmed'") { 'unconfirmed' }
                elseif ($finishCondition -ceq "`$retryResult -ne 'sent'") { '폴백 ①' }
            })) -join ' < '
}
Check-Equal "P5d-8 끝(retry) 클릭 루프 결과 분기 차례 = record-failed 반환 < safe-stop·last 반환 < unconfirmed < 폴백 ① (-ne 'sent')" $retryFinishOrder `
    "record-failed[return 'record-failed'] < safe-stop·last[return `$retryResult] < unconfirmed < 폴백 ①"

# FC-S15 (구현 단위 5b-8 2.3-2 · U-5b8-2 · ⑤c 5c-2) - 끝(retry) while 직속 재입장 결과 if 차례 · 본문(명령 이름 · exit) - 'field-cancelled' 갈래 = 공유 정지 함수 Stop-AbyssReentryFieldCancelled
#   한 문장 · 그 함수 몸통 = 끝 블록 직속 'Write-RunLog ; exit 4'(⑤c 5c-2 가 몸통을 끝(retry) 밖으로 옮김 - 몸통 글자는 이 단언이 렌더로 보고, 입력 · 진단 · 기록 · 예약 ·
#   다른 끝 0 의 행동은 FC-X(비커스텀)가 봄. 커스텀 가드로 더한 명령 · 대입은 FC-S22 허용 집합(끝(retry) 노드만 셈)과 FC-X 를 지나므로 이 렌더가 막음 - 변이 M84 꼴) ·
#   정지 줄 = 사용자 결정 글자(고정 사본 - 행은 소스 캡처를
#   따라가므로 글자 변이는 이 단언만 잡음) · 공유 정지 함수 안 1 · 워커 전체 1 · 사유 80자 안(GUI 코드 4
#   상태줄은 사유를 80자에서 자름) · 표지 꼬리 0
$FC_FIELD_CANCEL_DONE = "[완료] 재매칭이 취소돼 필드로 나왔습니다 - '다시 하기'를 다시 누르지 않고 멈춥니다"   # 사용자 결정 U-5b8-2 (2026-11-01)
$fcResultOrder = '(while 없음)'
if ($null -ne $retryFinishWhile) {
    $fcResultOrder = (@($retryFinishWhile.Body.Statements | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-NodeCode $_.Clauses[0].Item1) -cmatch '^\$reentryResult -eq ''[a-z-]+''$') } | ForEach-Object {
                $fcResultName = [regex]::Match((Get-NodeCode $_.Clauses[0].Item1), '''([a-z-]+)''').Groups[1].Value
                $fcResultBody = (@($_.Clauses[0].Item2.Statements | ForEach-Object { $fcBodyCommand = Get-StatementCommand $_; $(if ($_ -is [ExitStatementAst]) { Get-NodeCode $_ } elseif ($null -ne $fcBodyCommand) { $fcBodyCommand.GetCommandName() } else { '(명령 아님)' }) })) -join ' ; '
                '{0}[{1}]' -f $fcResultName, $fcResultBody
            })) -join ' < '
}
$fcDoneWorkerCount = @($workerAst.FindAll({ param($candidate) ($candidate -is [StringConstantExpressionAst]) -and ([string]$candidate.Value -ceq $FC_FIELD_CANCEL_DONE) }, $true)).Count
# 공유 정지 함수 몸통 - 끝 블록 직속 문장을 위 갈래 본문과 같은 렌더로(명령 이름 · exit · 그 밖 '(명령 아님)' - 커스텀 가드 if 도 '(명령 아님)' 으로 드러남)
$fcFieldCancelBody = (@($retryFieldCancelNode.Body.EndBlock.Statements | ForEach-Object { $fcBodyCommand = Get-StatementCommand $_; $(if ($_ -is [ExitStatementAst]) { Get-NodeCode $_ } elseif ($null -ne $fcBodyCommand) { $fcBodyCommand.GetCommandName() } else { '(명령 아님)' }) })) -join ' ; '
Check-Equal 'FC-S15 끝(retry) 재입장 결과 갈래 차례 · 본문 · 정지 줄 = U-5b8-2 글자(공유 정지 함수 안 1 · 워커 전체 1) · 사유 80자 안 · 표지 꼬리 0 · 공유 정지 함수 몸통' `
    ('{0} · 정지 줄 {1}/{2} · 글자 일치 {3} · 80자 안 {4} · 꼬리 {5} · 몸통 [{6}]' -f $fcResultOrder, $retryFieldDoneNodes.Count, $fcDoneWorkerCount, ($RETRY_DONE_FIELD_CANCELLED -ceq $FC_FIELD_CANCEL_DONE),
        (($RETRY_DONE_FIELD_CANCELLED.Length - '[완료] '.Length) -le 80), [int]$RETRY_DONE_FIELD_CANCELLED.Contains('[terminal='), $fcFieldCancelBody) `
    'entered[Complete-AbyssInsideHandoff] < cancelled[Complete-AbyssOtherSelection] < field-cancelled[Stop-AbyssReentryFieldCancelled] < timeout[Stop-AbyssReentryTimeout] · 정지 줄 1/1 · 글자 일치 True · 80자 안 True · 꼬리 0 · 몸통 [Write-RunLog ; exit 4]'

# FC-S16 (2.4 · ⑤c 5c-2) - 끝(retry) exit = 정확히 1 · 줄 단독 'exit 4' · 자리 = 'unconfirmed' 갈래 ('field-cancelled' 갈래의 exit 는 ⑤c 5c-2 에서 공유 정지 함수로 옮김) (§10 센티널 준비
#   게이트(줄 단독)의 사실을 이름 있는 단언으로)
$fcRetryExits = @($retryFinishNode.FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true))
$fcRetryExitText = (@($fcRetryExits | ForEach-Object { '{0}@{1}' -f (Get-LineCode $_), (@(Get-EnclosingIfConditions -Node $_ -Stop $retryFinishNode) | Select-Object -First 1) })) -join ' / '
Check-Equal "FC-S16 끝(retry) exit 1 · 줄 단독 'exit 4' · 자리 = 'unconfirmed' 갈래" $fcRetryExitText "exit 4@`$retryResult -eq 'unconfirmed'"

# FC-S22 (1절 4항 끝 · 구현 리뷰 2/2 의 4/5) - 끝(retry) 명령 이름 집합 = 정확히 9 (허용 집합 - N4-P6 꼴 · ⑤c 5c-2 가 공유 정지 함수를 더함 - 그 함수 몸통은 끝(retry) 노드 밖이라 FC-S15 의 렌더 칸이 봄). FC-S15 는 정확 조건 갈래만 보고 FC-X 행은 비커스텀이라
#   'field-cancelled' 갈래 밖에 다른 꼴 조건(StartsWith · -like)이나 커스텀 가드로 더한 키 · 마커 · 기록 · 예약 명령이 빠져나갔음(변이 M83 · M84). 끝(retry)에 명령을 더하면 이 행과 명세 3.3 을 함께
$RETRY_FINISH_COMMANDS_EXPECTED = @('Complete-AbyssInsideHandoff', 'Complete-AbyssOtherSelection', 'Get-AbyssReentryLimitSeconds', 'Invoke-AbyssRetryClick', 'Stop-AbyssReentryTimeout',
    'Stop-AbyssReentryFieldCancelled', 'Wait-AbyssReentry', 'Write-LifeDiagnostics', 'Write-RunLog')   # 공유 정지 함수 = ⑤c 5c-2 ('field-cancelled' 갈래)
$fcRetryCommandSet = @($retryFinishNode.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true) | ForEach-Object { [string]$_.GetCommandName() } | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
$fcRetryCommandUnnamed = @($retryFinishNode.FindAll({ param($candidate) ($candidate -is [CommandAst]) -and (-not $candidate.GetCommandName()) }, $true)).Count
Check-Equal "FC-S22 끝(retry) 명령 이름 집합 = 정확히 $($RETRY_FINISH_COMMANDS_EXPECTED.Count)개(허용 집합) · 이름 없는 호출(& `$식) 0" `
    ('[{0}] · 이름 없음 {1}' -f ($fcRetryCommandSet -join ','), $fcRetryCommandUnnamed) ('[{0}] · 이름 없음 0' -f ((@($RETRY_FINISH_COMMANDS_EXPECTED | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)) -join ','))

# FC-S19 (3.4 재생 들머리) - 이 파일 재생 실행(Invoke-RetryReplayRun)의 재입장 대기 호출 인자(Game 제외) = 워커 끝(retry) 호출 B 의 인자 (재생이 새 판정을 우회하지 않게 - 이 파일을 파싱)
function Get-CallArgumentTexts {
    # 명령 호출의 매개변수 이름=값 글자 (그 노드가 든 원문 기준 · 공백 정규화 · Game 제외 · 정렬). 스위치(피호출 원문의 [switch] 매개변수)는 콜론 값만 값으로 받고 그 밖의
    #   매개변수는 다음 요소를 값으로 받습니다. 남은 위치 인자는 '(위치)=글자' 로 셉니다 - PS 5.1 은 위치 인자를 선언 차례의 빈 매개변수(여기선 $Clock)에 묶고, 공백 꼴
    #   스위치 값도 위치 인자입니다(명세 3.3 묶기 실측 · 구현 리뷰 2/2 의 4/5 - 변이 T1 · T2)
    param($Command, [string[]]$SwitchNames = @())
    $argumentTexts = New-Object System.Collections.Generic.List[string]
    $commandElements = @($Command.CommandElements)
    for ($elementIndex = 1; $elementIndex -lt $commandElements.Count; $elementIndex++) {
        $element = $commandElements[$elementIndex]
        if (-not ($element -is [CommandParameterAst])) { $argumentTexts.Add(('(위치)={0}' -f (($element.Extent.Text -replace '\s+', ' ').Trim()))); continue }
        $valueText = '(스위치)'
        if ($null -ne $element.Argument) { $valueText = $element.Argument.Extent.Text }
        elseif (($SwitchNames -notcontains $element.ParameterName) -and ($elementIndex + 1 -lt $commandElements.Count) -and (-not ($commandElements[$elementIndex + 1] -is [CommandParameterAst]))) {
            $valueText = $commandElements[$elementIndex + 1].Extent.Text
            $elementIndex++
        }
        if ($element.ParameterName -ne 'Game') { $argumentTexts.Add(('{0}={1}' -f $element.ParameterName, (($valueText -replace '\s+', ' ').Trim()))) }
    }
    return ((@($argumentTexts) | Sort-Object -CaseSensitive) -join ' ')
}
$fcReentrySwitches = @($workerFunctions['Wait-AbyssReentry'].Body.ParamBlock.Parameters | Where-Object { $_.StaticType -eq [switch] } | ForEach-Object { [string]$_.Name.VariablePath.UserPath })
$fcSelfAst = [Parser]::ParseFile($PSCommandPath, [ref]$null, [ref]$null)
$fcReplayFunctions = @($fcSelfAst.FindAll({ param($candidate) ($candidate -is [FunctionDefinitionAst]) -and ($candidate.Name -eq 'Invoke-RetryReplayRun') }, $true))
$fcReplayCalls = @($(if ($fcReplayFunctions.Count -eq 1) { @($fcReplayFunctions[0].FindAll({ param($candidate) ($candidate -is [CommandAst]) -and ($candidate.GetCommandName() -eq 'Wait-AbyssReentry') }, $true)) }))
$fcCallBNodes = @(Get-CommandNodes -Node $retryFinishNode -Name 'Wait-AbyssReentry')
Check-Equal 'FC-S19 재생 실행의 재입장 대기 호출 인자(Game 제외 · 위치 인자 포함) = 워커 끝(retry) 호출 B 인자 - 재생 함수 1 · 호출 각 1 · 대기 스위치 3' `
    ('재생 함수 {0} · 호출 {1} · 스위치 {2} · {3}' -f $fcReplayFunctions.Count, $fcReplayCalls.Count, $fcReentrySwitches.Count, $(if ($fcReplayCalls.Count -eq 1) { Get-CallArgumentTexts $fcReplayCalls[0] -SwitchNames $fcReentrySwitches } else { '' })) `
    ('재생 함수 1 · 호출 1 · 스위치 3 · {0}' -f $(if ($fcCallBNodes.Count -eq 1) { Get-CallArgumentTexts $fcCallBNodes[0] -SwitchNames $fcReentrySwitches } else { '(호출 B {0})' -f $fcCallBNodes.Count }))
# ── §10 관측 0 재생 (명세 3.5 · B-13 - 범위 ⑤-57 재생 틀의 회귀 몫 · OCR 0 · 늘 돎) ──
# 전이 표 = 관측 0(2026-10-24 · 1272 창) 프레임을 워커 원문 판독 함수로 읽은 값(짝 판독문 = 하단 판독문 · 두 점 · S · 패널 종류 · HUD · 추적기 · 스윕 참)과 그 프레임의 원문 분류
#   (재입장 대기 꼴 - 표를 지을 때의 값으로 고정: 재생 행의 결정 표본 대조용)입니다. 1908 · 창 DPI 144 결측 두 판(⑥e frames2 - 버튼이 올라오는 중 '다시' 누락)의 첫 프레임과
#   다 올라온 무커서 프레임(같은 렌더 - 재생 A′ 의 화면 모형 M1′: 다음 저장 시각부터 그 값)을 더했습니다. 줄 종류(탭 구분): M = 판독 비용 중앙값(ms - 재생 비용 모형 = 중앙값 ×
#   배수 + 캡처 몫) · T = 전이 일곱(이름 · 프레임 묶음 · 모드 · 클릭 구간 아래 끝 · 열림 · 위 끝 · 열림 · 첫 변화 · 기대 - 클릭 구간은 재생 B 근거 interval_evidence) · U = 보상 화면 여덟
#   (첫 3버튼 프레임 t0) · Q = 1908 결측 두 판(t0 · 다음 저장 프레임) · F = 프레임(묶음 · 시각 · 보관 파일(던전이미지\어비스 기준) · 판독값 · 분류). 캐릭터 이름 없음.
#   표가 프레임과 어긋나지 않는지는 tests\test_abyss_party_signatures.ps1 의 대조 절이 보관 프레임을 원문 판독으로 다시 읽어 지킵니다(보관 프레임이 없으면 그 절만 SKIP).
#   판독문은 진리표 자산입니다(규칙 문서 '실기 검증' 5)
# 표의 manifest (명세 리뷰 2 P3 - 표와 따로 둔 글자 · 탭 구분): 재생 행 이름 · 프레임 묶음 · 첫 프레임 시각 · 끝 프레임 시각 · 정확한 F 줄 수. 아래 'RP 완전성(manifest)' 이 표의
#   T · U · Q 줄(행 이름 → 묶음)과 F 줄의 묶음 덩어리(나온 차례 · 첫 · 끝 시각 · 줄 수)를 이 글자와 정확히 대조합니다 - 묶음 누락 · 군더더기 · 덩어리 차례 · 다른 묶음에 끼어든 줄 ·
#   줄 수 · 첫 · 끝 프레임 차이가 FAIL(묶음 안 시각 역순 · 중복은 표 읽기 준비 단언이 'FAIL 준비'). tests\test_abyss_party_signatures.ps1 3-1 이 같은 대조를 따로 짠 코드로 돌립니다
#   (보관 프레임 · OCR 없이 늘 - 그 파일 2절의 SKIP 앞). 표를 고칠 때는 이 글자를 함께 고칩니다(줄 수 · 첫 · 끝이 바뀐 근거를 남길 것)
$RETRY_REPLAY_MANIFEST = @'
RP1	R1	13:18:40.578	13:19:11.859	34
RP2	R2	13:22:30.140	13:23:05.954	52
RP3	R3	13:28:39.890	13:28:54.547	31
RP4	T1	13:47:17.360	13:47:58.859	32
RP5	T2	13:52:46.360	13:53:22.672	44
RP6	T3	13:56:52.516	13:57:30.642	30
RP7	O3	14:04:48.828	14:04:56.953	19
UP1	R1u	13:18:34.704	13:18:50.890	4
UP2	R2u	13:22:30.140	13:22:43.202	2
UP3	R3u	13:27:55.547	13:28:16.171	3
UP4	R4u	13:32:13.548	13:32:33.828	2
UP5	T1u	13:46:53.922	13:47:14.234	2
UP6	T2u	13:52:01.640	13:52:21.921	2
UP7	T3u	13:56:11.546	13:56:32.204	3
UP8	T4u	14:00:57.141	14:01:17.453	2
UQ1	Q1	13:35:55.744	13:36:00.744	3
UQ2	Q2	14:34:17.989	14:34:22.989	3
'@
$RETRY_REPLAY_TABLE = @'
M	pair	18	prompt	30	panel	107	hud	26	quest	22	sweep	70
T	RP1	R1	solo	13:18:59.827	open	13:19:00.173	closed	13:19:00.173	entered
T	RP2	R2	solo	13:22:41.709	open	13:22:42.760	closed	13:22:43.202	entered|EOD
T	RP3	R3	solo	13:28:40.643	open	13:28:41.266	open	13:28:41.266	entered
T	RP4	T1	party	13:47:33.359	open	13:47:33.891	closed	13:47:33.891	entered
T	RP5	T2	party	13:52:52.235	open	13:52:52.547	closed	13:52:52.547	entered
T	RP6	T3	party	13:57:00.765	open	13:57:01.140	closed	13:57:01.140	entered
T	RP7	O3	party	14:04:49.609	open	14:04:49.796	closed	14:04:49.890	cancelled
U	UP1	R1u	13:18:34.704
U	UP2	R2u	13:22:30.140
U	UP3	R3u	13:27:55.547
U	UP4	R4u	13:32:13.548
U	UP5	T1u	13:46:53.922
U	UP6	T2u	13:52:01.640
U	UP7	T3u	13:56:11.546
U	UP8	T4u	14:00:57.141
Q	UQ1	Q1	13:35:55.744	13:35:56.865
Q	UQ2	Q2	14:34:17.989	14:34:19.083
F	set	time	file	bottom	retry	other	prompt	panel	hud	quest	sweep	class
F	R1	13:18:40.578	20261024_관측0_다시하기\frames\cap_131840_578_1272x717.png	아이템을누르면상세정보를볼수».*|다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1	13:18:50.890	20261024_관측0_다시하기\frames\cap_131850_890_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1	13:18:51.235	20261024_관측0_다시하기\frames\cap_131851_235_1272x717.png	뗌을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1	13:18:52.609	20261024_관측0_다시하기\frames\cap_131852_609_1272x717.png	아에나가기르면상세정보를볼수있습니다Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1	13:18:52.953	20261024_관측0_다시하기\frames\cap_131852_953_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔öf다른던전가기	null	778,654	False	none	False	False	False	reward3
F	R1	13:18:53.297	20261024_관측0_다시하기\frames\cap_131853_297_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다세하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1	13:18:59.484	20261024_관측0_다시하기\frames\cap_131859_484_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1	13:18:59.827	20261024_관측0_다시하기\frames\cap_131859_827_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다세하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1	13:19:00.173	20261024_관측0_다시하기\frames\cap_131900_173_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다心6기다른던전가기	null	778,654	False	none	False	False	False	reward3
F	R1	13:19:00.516	20261024_관측0_다시하기\frames\cap_131900_516_1272x717.png		null	null	False	none	False	False	False	unknown
F	R1	13:19:00.859	20261024_관측0_다시하기\frames\cap_131900_859_1272x717.png		null	null	False	none	False	False	False	unknown
F	R1	13:19:03.609	20261024_관측0_다시하기\frames\cap_131903_609_1272x717.png	(다”5별-	null	null	False	none	False	True	False	unknown
F	R1	13:19:03.984	20261024_관측0_다시하기\frames\cap_131903_984_1272x717.png	`료가은역서jf晉	null	null	False	none	True	True	False	inside
F	R1	13:19:04.361	20261024_관측0_다시하기\frames\cap_131904_361_1272x717.png	21140펄실(결	null	null	False	none	True	True	False	inside
F	R1	13:19:04.734	20261024_관측0_다시하기\frames\cap_131904_734_1272x717.png		null	null	False	none	True	True	False	inside
F	R1	13:19:05.109	20261024_관측0_다시하기\frames\cap_131905_109_1272x717.png	2`르혘〕펄출)(결	null	null	False	none	True	True	False	inside
F	R1	13:19:05.484	20261024_관측0_다시하기\frames\cap_131905_484_1272x717.png		null	null	False	none	True	True	False	inside
F	R1	13:19:05.858	20261024_관측0_다시하기\frames\cap_131905_858_1272x717.png	`결5〕*류쉬(결	null	null	False	none	True	True	False	inside
F	R1	13:19:06.234	20261024_관측0_다시하기\frames\cap_131906_234_1272x717.png		null	null	False	none	True	True	False	inside
F	R1	13:19:06.609	20261024_관측0_다시하기\frames\cap_131906_609_1272x717.png		null	null	False	none	True	True	False	inside
F	R1	13:19:06.984	20261024_관측0_다시하기\frames\cap_131906_984_1272x717.png		null	null	False	none	True	True	False	inside
F	R1	13:19:07.360	20261024_관측0_다시하기\frames\cap_131907_360_1272x717.png		null	null	False	none	True	True	False	inside
F	R1	13:19:07.735	20261024_관측0_다시하기\frames\cap_131907_735_1272x717.png		null	null	False	none	True	True	False	inside
F	R1	13:19:08.111	20261024_관측0_다시하기\frames\cap_131908_111_1272x717.png		null	null	False	none	True	True	False	inside
F	R1	13:19:08.485	20261024_관측0_다시하기\frames\cap_131908_485_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:08.860	20261024_관측0_다시하기\frames\cap_131908_860_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:09.235	20261024_관측0_다시하기\frames\cap_131909_235_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:09.609	20261024_관측0_다시하기\frames\cap_131909_609_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:09.985	20261024_관측0_다시하기\frames\cap_131909_985_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:10.362	20261024_관측0_다시하기\frames\cap_131910_362_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:10.735	20261024_관측0_다시하기\frames\cap_131910_735_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:11.110	20261024_관측0_다시하기\frames\cap_131911_110_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:11.485	20261024_관측0_다시하기\frames\cap_131911_485_1272x717.png		null	null	False	none	False	True	False	unknown
F	R1	13:19:11.859	20261024_관측0_다시하기\frames\cap_131911_859_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:30.140	20261024_관측0_다시하기\frames\cap_132230_140_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,655	False	none	False	False	False	reward3
F	R2	13:22:43.202	20261024_관측0_다시하기\frames\cap_132243_202_1272x717.png		null	null	False	none	False	False	False	unknown
F	R2	13:22:43.550	20261024_관측0_다시하기\frames\cap_132243_550_1272x717.png		null	null	False	none	False	False	False	unknown
F	R2	13:22:46.298	20261024_관측0_다시하기\frames\cap_132246_298_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:46.672	20261024_관측0_다시하기\frames\cap_132246_672_1272x717.png		null	null	False	none	True	True	False	inside
F	R2	13:22:47.048	20261024_관측0_다시하기\frames\cap_132247_048_1272x717.png	2&*류수?표출	null	null	False	none	True	True	False	inside
F	R2	13:22:47.422	20261024_관측0_다시하기\frames\cap_132247_422_1272x717.png	Ⅰ~芩돈출	null	null	False	none	True	True	False	inside
F	R2	13:22:47.796	20261024_관측0_다시하기\frames\cap_132247_796_1272x717.png	2결돈〕If류羚)(결	null	null	False	none	True	True	False	inside
F	R2	13:22:48.173	20261024_관측0_다시하기\frames\cap_132248_173_1272x717.png	5,竺	null	null	False	none	True	True	False	inside
F	R2	13:22:48.546	20261024_관측0_다시하기\frames\cap_132248_546_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:48.923	20261024_관측0_다시하기\frames\cap_132248_923_1272x717.png	결춀꾜+쉬(결	null	null	False	none	False	True	False	unknown
F	R2	13:22:49.298	20261024_관측0_다시하기\frames\cap_132249_298_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:49.673	20261024_관측0_다시하기\frames\cap_132249_673_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:50.047	20261024_관측0_다시하기\frames\cap_132250_047_1272x717.png	『고교t는	null	null	False	none	False	True	False	unknown
F	R2	13:22:50.422	20261024_관측0_다시하기\frames\cap_132250_422_1272x717.png	XXXXXXXXXXXXX•XXXXXXXXXXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXX:•'XXXXXXXXXXXXXXXXXXxx`ÄXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXÄ`::•:•,!XXXXXXXXXXXXXXXX:•:XXXXXXXXXXXXX:(XXXXXXXXXXXXXXXXÄ•XXXXXXXXXXXXXXX:•:•,:XXX(XXXXXXXXXXXXXY'XXXXXXXXXXY(XXXXXXXXXYCXXXXXXXXXY4XXXXXXXXXYCXXXXXXXXXY(XXXXXXXXXYCXXXXXXXXXXXXXXXXXXX•XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX-4XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXÄ•〈XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.`XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX1•XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX•:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:“렛XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:•XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:•XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXX•XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:•XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:•XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX••:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX(XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX•(XXXXXXXXXXXXXXXX•XXXXXXXXXXXXXXXXXXXXXXXXXX'XXXXXXXXXXXXXXXXXXXXXXXXX•XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX	null	null	False	none	False	True	False	unknown
F	R2	13:22:50.798	20261024_관측0_다시하기\frames\cap_132250_798_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:51.173	20261024_관측0_다시하기\frames\cap_132251_173_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:51.547	20261024_관측0_다시하기\frames\cap_132251_547_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:51.922	20261024_관측0_다시하기\frames\cap_132251_922_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:52.299	20261024_관측0_다시하기\frames\cap_132252_299_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:52.672	20261024_관측0_다시하기\frames\cap_132252_672_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:53.047	20261024_관측0_다시하기\frames\cap_132253_047_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:53.423	20261024_관측0_다시하기\frames\cap_132253_423_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:53.797	20261024_관측0_다시하기\frames\cap_132253_797_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:54.172	20261024_관측0_다시하기\frames\cap_132254_172_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:54.548	20261024_관측0_다시하기\frames\cap_132254_548_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:54.922	20261024_관측0_다시하기\frames\cap_132254_922_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:55.297	20261024_관측0_다시하기\frames\cap_132255_297_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:55.672	20261024_관측0_다시하기\frames\cap_132255_672_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:56.047	20261024_관측0_다시하기\frames\cap_132256_047_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:57.078	20261024_관측0_다시하기\frames\cap_132257_078_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:58.140	20261024_관측0_다시하기\frames\cap_132258_140_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:58.484	20261024_관측0_다시하기\frames\cap_132258_484_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:58.859	20261024_관측0_다시하기\frames\cap_132258_859_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:59.235	20261024_관측0_다시하기\frames\cap_132259_235_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:22:59.609	20261024_관측0_다시하기\frames\cap_132259_609_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:00.329	20261024_관측0_다시하기\frames\cap_132300_329_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:00.704	20261024_관측0_다시하기\frames\cap_132300_704_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:01.078	20261024_관측0_다시하기\frames\cap_132301_078_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:01.454	20261024_관측0_다시하기\frames\cap_132301_454_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:01.828	20261024_관측0_다시하기\frames\cap_132301_828_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:02.203	20261024_관측0_다시하기\frames\cap_132302_203_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:02.580	20261024_관측0_다시하기\frames\cap_132302_580_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:02.954	20261024_관측0_다시하기\frames\cap_132302_954_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:03.329	20261024_관측0_다시하기\frames\cap_132303_329_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:03.703	20261024_관측0_다시하기\frames\cap_132303_703_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:04.079	20261024_관측0_다시하기\frames\cap_132304_079_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:04.454	20261024_관측0_다시하기\frames\cap_132304_454_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:04.829	20261024_관측0_다시하기\frames\cap_132304_829_1272x717.png		null	null	False	none	False	True	False	unknown
F	R2	13:23:05.202	20261024_관측0_다시하기\frames\cap_132305_202_1272x717.png	-+30	null	null	False	none	False	True	False	unknown
F	R2	13:23:05.579	20261024_관측0_다시하기\frames\cap_132305_579_1272x717.png	주특특횪까O	null	null	False	none	False	True	False	unknown
F	R2	13:23:05.954	20261024_관측0_다시하기\frames\cap_132305_954_1272x717.png	”특특횪결O	null	null	False	none	False	True	False	unknown
F	R3	13:28:39.890	20261024_관측0_다시하기\frames\cap_132839_890_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다하기다른던전가기	null	778,654	False	none	False	False	False	reward3
F	R3	13:28:41.266	20261024_관측0_다시하기\frames\cap_132841_266_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3	13:28:41.609	20261024_관측0_다시하기\frames\cap_132841_609_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3	13:28:41.953	20261024_관측0_다시하기\frames\cap_132841_953_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3	13:28:42.641	20261024_관측0_다시하기\frames\cap_132842_641_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3	13:28:44.359	20261024_관측0_다시하기\frames\cap_132844_359_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3	13:28:44.734	20261024_관측0_다시하기\frames\cap_132844_734_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3	13:28:45.109	20261024_관측0_다시하기\frames\cap_132845_109_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3	13:28:45.485	20261024_관측0_다시하기\frames\cap_132845_485_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3	13:28:45.828	20261024_관측0_다시하기\frames\cap_132845_828_1272x717.png	아이템을누르면상세성보를볼수있습니다확인	null	null	False	none	False	False	True	unknown
F	R3	13:28:46.172	20261024_관측0_다시하기\frames\cap_132846_172_1272x717.png	아이템을누르면상세정보를수있습니다확인	null	null	False	none	False	False	True	unknown
F	R3	13:28:46.515	20261024_관측0_다시하기\frames\cap_132846_515_1272x717.png	아이템을누르면상세성보를몰수있습니다확인	null	null	False	none	False	False	True	unknown
F	R3	13:28:46.859	20261024_관측0_다시하기\frames\cap_132846_859_1272x717.png	아이템을누르면상세성보를몰수있습니다확인	null	null	False	none	False	False	True	unknown
F	R3	13:28:47.547	20261024_관측0_다시하기\frames\cap_132847_547_1272x717.png	아이템을누르면상세성보를몰수있습니다확인	null	null	False	none	False	False	True	unknown
F	R3	13:28:47.894	20261024_관측0_다시하기\frames\cap_132847_894_1272x717.png		null	null	False	none	False	True	False	unknown
F	R3	13:28:48.266	20261024_관측0_다시하기\frames\cap_132848_266_1272x717.png	는7月신Ct!	null	null	False	none	True	True	False	inside
F	R3	13:28:48.610	20261024_관측0_다시하기\frames\cap_132848_610_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:48.984	20261024_관측0_다시하기\frames\cap_132848_984_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:49.359	20261024_관측0_다시하기\frames\cap_132849_359_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:49.735	20261024_관측0_다시하기\frames\cap_132849_735_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:50.109	20261024_관측0_다시하기\frames\cap_132850_109_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:50.485	20261024_관측0_다시하기\frames\cap_132850_485_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:50.859	20261024_관측0_다시하기\frames\cap_132850_859_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:51.235	20261024_관측0_다시하기\frames\cap_132851_235_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:51.610	20261024_관측0_다시하기\frames\cap_132851_610_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:51.985	20261024_관측0_다시하기\frames\cap_132851_985_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:52.359	20261024_관측0_다시하기\frames\cap_132852_359_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:52.734	20261024_관측0_다시하기\frames\cap_132852_734_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:53.110	20261024_관측0_다시하기\frames\cap_132853_110_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:54.173	20261024_관측0_다시하기\frames\cap_132854_173_1272x717.png		null	null	False	none	True	True	False	inside
F	R3	13:28:54.547	20261024_관측0_다시하기\frames\cap_132854_547_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:17.360	20261024_관측0_다시하기\frames\cap_134717_360_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다셔하기다른던전)7	636,654	780,654	False	none	False	False	False	reward3
F	T1	13:47:33.891	20261024_관측0_다시하기\frames\cap_134733_891_1272x717.png	나가기100아이템을누르면상세정보를볼우연한사제	null	null	False	none	False	False	False	unknown
F	T1	13:47:34.235	20261024_관측0_다시하기\frames\cap_134734_235_1272x717.png	사제아이템을누르면상세정보를나가기	null	null	False	matching	False	False	False	matching
F	T1	13:47:36.986	20261024_관측0_다시하기\frames\cap_134736_986_1272x717.png	사제0田l민그누르면삼세정보를	null	null	False	matching	False	False	False	matching
F	T1	13:47:37.359	20261024_관측0_다시하기\frames\cap_134737_359_1272x717.png	사제0田l민그누르면삼세정보를	null	null	False	matching	False	False	False	matching
F	T1	13:47:40.109	20261024_관측0_다시하기\frames\cap_134740_109_1272x717.png	사제0田l민그누르면삼세정보를	null	null	False	matching	False	False	False	matching
F	T1	13:47:45.267	20261024_관측0_다시하기\frames\cap_134745_267_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T1	13:47:45.609	20261024_관측0_다시하기\frames\cap_134745_609_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T1	13:47:46.297	20261024_관측0_다시하기\frames\cap_134746_297_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T1	13:47:46.640	20261024_관측0_다시하기\frames\cap_134746_640_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T1	13:47:48.017	20261024_관측0_다시하기\frames\cap_134748_017_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T1	13:47:48.360	20261024_관측0_다시하기\frames\cap_134748_360_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T1	13:47:48.734	20261024_관측0_다시하기\frames\cap_134748_734_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T1	13:47:49.422	20261024_관측0_다시하기\frames\cap_134749_422_1272x717.png		null	null	False	none	False	False	False	unknown
F	T1	13:47:49.765	20261024_관측0_다시하기\frames\cap_134749_765_1272x717.png		null	null	False	none	False	False	False	unknown
F	T1	13:47:52.859	20261024_관측0_다시하기\frames\cap_134752_859_1272x717.png		null	null	False	none	False	True	False	unknown
F	T1	13:47:53.235	20261024_관측0_다시하기\frames\cap_134753_235_1272x717.png	5	null	null	False	none	True	True	False	inside
F	T1	13:47:53.610	20261024_관측0_다시하기\frames\cap_134753_610_1272x717.png	`&가쇨전&좋	null	null	False	none	True	True	False	inside
F	T1	13:47:53.985	20261024_관측0_다시하기\frames\cap_134753_985_1272x717.png	르目가쇨爸&춬	null	null	False	none	True	True	False	inside
F	T1	13:47:54.360	20261024_관측0_다시하기\frames\cap_134754_360_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:54.735	20261024_관측0_다시하기\frames\cap_134754_735_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:55.110	20261024_관측0_다시하기\frames\cap_134755_110_1272x717.png	\결5〕*류쉬(결	null	null	False	none	True	True	False	inside
F	T1	13:47:55.485	20261024_관측0_다시하기\frames\cap_134755_485_1272x717.png	\결춀〕털신돈출	null	null	False	none	True	True	False	inside
F	T1	13:47:55.861	20261024_관측0_다시하기\frames\cap_134755_861_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:56.234	20261024_관측0_다시하기\frames\cap_134756_234_1272x717.png	는)게신나.	null	null	False	none	True	True	False	inside
F	T1	13:47:56.609	20261024_관측0_다시하기\frames\cap_134756_609_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:56.984	20261024_관측0_다시하기\frames\cap_134756_984_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:57.360	20261024_관측0_다시하기\frames\cap_134757_360_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:57.735	20261024_관측0_다시하기\frames\cap_134757_735_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:58.110	20261024_관측0_다시하기\frames\cap_134758_110_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:58.485	20261024_관측0_다시하기\frames\cap_134758_485_1272x717.png		null	null	False	none	True	True	False	inside
F	T1	13:47:58.859	20261024_관측0_다시하기\frames\cap_134758_859_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:52:46.360	20261024_관측0_다시하기\frames\cap_135246_360_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	T2	13:52:52.547	20261024_관측0_다시하기\frames\cap_135252_547_1272x717.png	나가기아이템을누르면상세정보를볼사제으01한	null	null	False	matching	False	False	False	matching
F	T2	13:52:52.890	20261024_관측0_다시하기\frames\cap_135252_890_1272x717.png	사제아이템을누르면상세정보를	null	null	False	matching	False	False	False	matching
F	T2	13:52:53.235	20261024_관측0_다시하기\frames\cap_135253_235_1272x717.png	사제0田l민그누르면삼세정보를	null	null	False	matching	False	False	False	matching
F	T2	13:52:54.952	20261024_관측0_다시하기\frames\cap_135254_952_1272x717.png	사제0田l{匕'그누르면삼세점보」	null	null	False	matching	False	False	False	matching
F	T2	13:52:59.423	20261024_관측0_다시하기\frames\cap_135259_423_1272x717.png	사제0田l{匕'그누르면삼세점보」	null	null	False	matching	False	False	False	matching
F	T2	13:53:04.609	20261024_관측0_다시하기\frames\cap_135304_609_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T2	13:53:04.953	20261024_관측0_다시하기\frames\cap_135304_953_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T2	13:53:05.640	20261024_관측0_다시하기\frames\cap_135305_640_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T2	13:53:05.984	20261024_관측0_다시하기\frames\cap_135305_984_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T2	13:53:06.329	20261024_관측0_다시하기\frames\cap_135306_329_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T2	13:53:06.672	20261024_관측0_다시하기\frames\cap_135306_672_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T2	13:53:07.016	20261024_관측0_다시하기\frames\cap_135307_016_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T2	13:53:08.734	20261024_관측0_다시하기\frames\cap_135308_734_1272x717.png		null	null	False	none	False	False	False	unknown
F	T2	13:53:09.078	20261024_관측0_다시하기\frames\cap_135309_078_1272x717.png		null	null	False	none	False	False	False	unknown
F	T2	13:53:12.172	20261024_관측0_다시하기\frames\cap_135312_172_1272x717.png		null	null	False	none	False	True	False	unknown
F	T2	13:53:12.548	20261024_관측0_다시하기\frames\cap_135312_548_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:12.923	20261024_관측0_다시하기\frames\cap_135312_923_1272x717.png	국퉄덤~	null	null	False	none	True	True	False	inside
F	T2	13:53:13.298	20261024_관측0_다시하기\frames\cap_135313_298_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:13.673	20261024_관측0_다시하기\frames\cap_135313_673_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:14.047	20261024_관측0_다시하기\frames\cap_135314_047_1272x717.png	느7月신L}!	null	null	False	none	True	True	False	inside
F	T2	13:53:14.422	20261024_관측0_다시하기\frames\cap_135314_422_1272x717.png	±Jhé!Ct!	null	null	False	none	True	True	False	inside
F	T2	13:53:14.797	20261024_관측0_다시하기\frames\cap_135314_797_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:15.172	20261024_관측0_다시하기\frames\cap_135315_172_1272x717.png	『는)게신ct,	null	null	False	none	True	True	False	inside
F	T2	13:53:15.548	20261024_관측0_다시하기\frames\cap_135315_548_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:15.923	20261024_관측0_다시하기\frames\cap_135315_923_1272x717.png		null	null	False	none	True	False	False	field
F	T2	13:53:16.297	20261024_관측0_다시하기\frames\cap_135316_297_1272x717.png	『느껴신LtJ	null	null	False	none	True	False	False	field
F	T2	13:53:16.672	20261024_관측0_다시하기\frames\cap_135316_672_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:17.046	20261024_관측0_다시하기\frames\cap_135317_046_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:17.422	20261024_관측0_다시하기\frames\cap_135317_422_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:17.797	20261024_관측0_다시하기\frames\cap_135317_797_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:18.173	20261024_관측0_다시하기\frames\cap_135318_173_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:18.548	20261024_관측0_다시하기\frames\cap_135318_548_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:18.922	20261024_관측0_다시하기\frames\cap_135318_922_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:19.297	20261024_관측0_다시하기\frames\cap_135319_297_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:19.672	20261024_관측0_다시하기\frames\cap_135319_672_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:20.047	20261024_관측0_다시하기\frames\cap_135320_047_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:20.422	20261024_관측0_다시하기\frames\cap_135320_422_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:20.797	20261024_관측0_다시하기\frames\cap_135320_797_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:21.172	20261024_관측0_다시하기\frames\cap_135321_172_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:21.548	20261024_관측0_다시하기\frames\cap_135321_548_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:21.922	20261024_관측0_다시하기\frames\cap_135321_922_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:22.297	20261024_관측0_다시하기\frames\cap_135322_297_1272x717.png		null	null	False	none	True	True	False	inside
F	T2	13:53:22.672	20261024_관측0_다시하기\frames\cap_135322_672_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:56:52.516	20261024_관측0_다시하기\frames\cap_135652_516_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	T3	13:57:01.140	20261024_관측0_다시하기\frames\cap_135701_140_1272x717.png	나가기아이템을누르면상세정보를볼수있습니다연한만남찾는중	null	null	False	none	False	False	False	unknown
F	T3	13:57:01.485	20261024_관측0_다시하기\frames\cap_135701_485_1272x717.png	아이템을누르면상세정보를•鏖사제나가기	null	null	False	matching	False	False	False	matching
F	T3	13:57:04.577	20261024_관측0_다시하기\frames\cap_135704_577_1272x717.png	사제0田l{匕'그누르면삼세정보」	null	null	False	matching	False	False	False	matching
F	T3	13:57:10.765	20261024_관측0_다시하기\frames\cap_135710_765_1272x717.png	사제0田l{匕'그누르면삼세정보」	null	null	False	matching	False	False	False	matching
F	T3	13:57:12.172	20261024_관측0_다시하기\frames\cap_135712_172_1272x717.png	사제0田l{匕'그누르면삼세정보」	null	null	False	matching	False	False	False	matching
F	T3	13:57:17.328	20261024_관측0_다시하기\frames\cap_135717_328_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T3	13:57:17.702	20261024_관측0_다시하기\frames\cap_135717_702_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T3	13:57:18.734	20261024_관측0_다시하기\frames\cap_135718_734_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T3	13:57:20.109	20261024_관측0_다시하기\frames\cap_135720_109_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T3	13:57:20.452	20261024_관측0_다시하기\frames\cap_135720_452_1272x717.png	사제	null	null	False	matching	False	False	False	matching
F	T3	13:57:21.484	20261024_관측0_다시하기\frames\cap_135721_484_1272x717.png		null	null	False	none	False	False	False	unknown
F	T3	13:57:21.860	20261024_관측0_다시하기\frames\cap_135721_860_1272x717.png		null	null	False	none	False	False	False	unknown
F	T3	13:57:24.641	20261024_관측0_다시하기\frames\cap_135724_641_1272x717.png		null	null	False	none	False	False	False	unknown
F	T3	13:57:25.016	20261024_관측0_다시하기\frames\cap_135725_016_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:25.390	20261024_관측0_다시하기\frames\cap_135725_390_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:25.766	20261024_관측0_다시하기\frames\cap_135725_766_1272x717.png	`국&惢죠)(결	null	null	False	none	True	True	False	inside
F	T3	13:57:26.141	20261024_관측0_다시하기\frames\cap_135726_141_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:26.515	20261024_관측0_다시하기\frames\cap_135726_515_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:26.891	20261024_관측0_다시하기\frames\cap_135726_891_1272x717.png	s결5〕*류쉬f,출	null	null	False	none	True	True	False	inside
F	T3	13:57:27.266	20261024_관측0_다시하기\frames\cap_135727_266_1272x717.png	s?춀〕펄芩&출	null	null	False	none	True	True	False	inside
F	T3	13:57:27.640	20261024_관측0_다시하기\frames\cap_135727_640_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:28.016	20261024_관측0_다시하기\frames\cap_135728_016_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:28.392	20261024_관측0_다시하기\frames\cap_135728_392_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:28.766	20261024_관측0_다시하기\frames\cap_135728_766_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:29.141	20261024_관측0_다시하기\frames\cap_135729_141_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:29.516	20261024_관측0_다시하기\frames\cap_135729_516_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:29.891	20261024_관측0_다시하기\frames\cap_135729_891_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:30.266	20261024_관측0_다시하기\frames\cap_135730_266_1272x717.png		null	null	False	none	True	True	False	inside
F	T3	13:57:30.642	20261024_관측0_다시하기\frames\cap_135730_642_1272x717.png		null	null	False	none	True	True	False	inside
F	O3	14:04:48.828	20261024_관측0_다시하기\frames\cap_140448_828_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기SpaceC}Å-기다른던전가기	null	778,654	False	none	False	False	False	reward3
F	O3	14:04:49.890	20261024_관측0_다시하기\frames\cap_140449_890_1272x717.png	아이템을누르면상세정보를불나가기사제	null	null	False	matching	False	False	False	matching
F	O3	14:04:50.266	20261024_관측0_다시하기\frames\cap_140450_266_1272x717.png	사제0田l邕:그누르면상세점보」	null	null	False	matching	False	False	False	matching
F	O3	14:04:50.609	20261024_관측0_다시하기\frames\cap_140450_609_1272x717.png	사제0田l드匕:그누르면삼세성보」	null	null	False	matching	False	False	False	matching
F	O3	14:04:50.952	20261024_관측0_다시하기\frames\cap_140450_952_1272x717.png	사제0田l드匕:그누르면삼세성보」	null	null	False	matching	False	False	False	matching
F	O3	14:04:51.984	20261024_관측0_다시하기\frames\cap_140451_984_1272x717.png	사제0田l드匕:그누르면삼세성보」	null	null	False	matching	False	False	False	matching
F	O3	14:04:52.390	20261024_관측0_다시하기\frames\cap_140452_390_1272x717.png	사제아이템을누르면상세정보」	null	null	False	matching	False	False	False	matching
F	O3	14:04:52.736	20261024_관측0_다시하기\frames\cap_140452_736_1272x717.png	나가기아이템을누르면상세정보를볼수있습니다만남찾는중	null	null	False	none	False	False	False	unknown
F	O3	14:04:53.452	20261024_관측0_다시하기\frames\cap_140453_452_1272x717.png	나가기아이템을누르면상세정보를볼0(겨가부꼼사제	null	null	False	none	False	False	False	unknown
F	O3	14:04:53.796	20261024_관측0_다시하기\frames\cap_140453_796_1272x717.png	사제OI이템그누르면상세정보를[그나가기	null	null	False	matching	False	False	False	matching
F	O3	14:04:54.141	20261024_관측0_다시하기\frames\cap_140454_141_1272x717.png	사제0田l邕:그누르면상세성보」	null	null	False	matching	False	False	False	matching
F	O3	14:04:54.484	20261024_관측0_다시하기\frames\cap_140454_484_1272x717.png	사제0田l드匕:그누르면삼세성보」	null	null	False	matching	False	False	False	matching
F	O3	14:04:54.828	20261024_관측0_다시하기\frames\cap_140454_828_1272x717.png	사제0田l드匕:그누르면삼세성보」	null	null	False	matching	False	False	False	matching
F	O3	14:04:55.173	20261024_관측0_다시하기\frames\cap_140455_173_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기	636,654	777,654	False	none	False	False	False	reward3
F	O3	14:04:55.516	20261024_관측0_다시하기\frames\cap_140455_516_1272x717.png	아이템을누르면상세정보를볼수있습니C나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	O3	14:04:55.890	20261024_관측0_다시하기\frames\cap_140455_890_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다세하기十른던전가기	636,654	null	False	none	False	False	False	reward3
F	O3	14:04:56.235	20261024_관측0_다시하기\frames\cap_140456_235_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다세기다른던전가기	null	778,654	False	none	False	False	False	reward3
F	O3	14:04:56.609	20261024_관측0_다시하기\frames\cap_140456_609_1272x717.png	아이템•나가기면상세정보를볼수있습니다Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	O3	14:04:56.953	20261024_관측0_다시하기\frames\cap_140456_953_1272x717.png	아이템-나가기-상세정보를볼수있습니다Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1u	13:18:34.704	20261024_관측0_다시하기\frames\cap_131834_704_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다세하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1u	13:18:39.859	20261024_관측0_다시하기\frames\cap_131839_859_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1u	13:18:40.578	20261024_관측0_다시하기\frames\cap_131840_578_1272x717.png	아이템을누르면상세정보를볼수».*|다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R1u	13:18:50.890	20261024_관측0_다시하기\frames\cap_131850_890_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R2u	13:22:30.140	20261024_관측0_다시하기\frames\cap_132230_140_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,655	False	none	False	False	False	reward3
F	R2u	13:22:43.202	20261024_관측0_다시하기\frames\cap_132243_202_1272x717.png		null	null	False	none	False	False	False	unknown
F	R3u	13:27:55.547	20261024_관측0_다시하기\frames\cap_132755_547_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다셔하기다른던전가기	636,664	778,664	False	none	False	False	False	reward3
F	R3u	13:27:55.889	20261024_관측0_다시하기\frames\cap_132755_889_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R3u	13:28:16.171	20261024_관측0_다시하기\frames\cap_132816_171_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	R4u	13:32:13.548	20261024_관측0_다시하기\frames\cap_133213_548_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다세하기다른던전가기	636,656	778,656	False	none	False	False	False	reward3
F	R4u	13:32:33.828	20261024_관측0_다시하기\frames\cap_133233_828_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	T1u	13:46:53.922	20261024_관측0_다시하기\frames\cap_134653_922_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다시하기다른던전가기	636,655	778,655	False	none	False	False	False	reward3
F	T1u	13:47:14.234	20261024_관측0_다시하기\frames\cap_134714_234_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	T2u	13:52:01.640	20261024_관측0_다시하기\frames\cap_135201_640_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다시하기다른던전가기	636,655	778,655	False	none	False	False	False	reward3
F	T2u	13:52:21.921	20261024_관측0_다시하기\frames\cap_135221_921_1272x717.png	아이템을누르면상세정보를수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	T3u	13:56:11.546	20261024_관측0_다시하기\frames\cap_135611_546_1272x717.png	아이템을누르면상세정보n볼수있습니다나가기Space다셔하기다른던전가기	636,664	778,664	False	none	False	False	False	reward3
F	T3u	13:56:11.891	20261024_관측0_다시하기\frames\cap_135611_891_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	T3u	13:56:32.204	20261024_관측0_다시하기\frames\cap_135632_204_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	T4u	14:00:57.141	20261024_관측0_다시하기\frames\cap_140057_141_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,657	778,657	False	none	False	False	False	reward3
F	T4u	14:01:17.453	20261024_관측0_다시하기\frames\cap_140117_453_1272x717.png	아이템을누르면상세정보를볼수있습니다나가기Space다셔하기다른던전가기	636,654	778,654	False	none	False	False	False	reward3
F	Q1	13:35:55.744	20261001_⑥e_실기\frames2\cap_133555_744_1908x1076.png	아이템을누르면상세정보를볼수있습니다SC나가기Space하기다른던전가기	null	765,662	False	none	False	False	False	reward3
F	Q1	13:35:56.865	20261001_⑥e_실기\frames2\cap_132837_833_1908x1076.png	아이템을누르면상세정보를볼수있습니다SC나가기Space다셔하기다른던전가기	636,660	765,660	False	none	False	False	False	reward3
F	Q1	13:36:00.744	20261001_⑥e_실기\frames2\cap_132837_833_1908x1076.png	아이템을누르면상세정보를볼수있습니다SC나가기Space다셔하기다른던전가기	636,660	765,660	False	none	False	False	False	reward3
F	Q2	14:34:17.989	20261001_⑥e_실기\frames2\cap_143417_989_1908x1076.png	아이템을누르면상세정보를볼수있습니다SC나가기Space하기다른던전가기	null	765,664	False	none	False	False	False	reward3
F	Q2	14:34:19.083	20261001_⑥e_실기\frames2\cap_132837_833_1908x1076.png	아이템을누르면상세정보를볼수있습니다SC나가기Space다셔하기다른던전가기	636,660	765,660	False	none	False	False	False	reward3
F	Q2	14:34:22.989	20261001_⑥e_실기\frames2\cap_132837_833_1908x1076.png	아이템을누르면상세정보를볼수있습니다SC나가기Space다셔하기다른던전가기	636,660	765,660	False	none	False	False	False	reward3
'@
# 표 읽기 · 열 꼴 (준비 단언 - 어긋나면 'FAIL 준비': 명세 2.2 '관측 0 전이 표의 열 꼴')
$RETRY_REPLAY_FRAME_COLUMNS = @('F', 'set', 'time', 'file', 'bottom', 'retry', 'other', 'prompt', 'panel', 'hud', 'quest', 'sweep', 'class')
$RETRY_REPLAY_KINDS = @('pair', 'prompt', 'panel', 'hud', 'quest', 'sweep')
$RETRY_REPLAY_CLASSES = @('popup', 'ready', 'matching', 'entry-waiting', 'prompt', 'inside', 'reward3', 'field', 'unknown')
$RETRY_REPLAY_DAY = [datetime]'2026-10-24'
$RETRY_REPLAY_MEDIAN_MS = @{}
$RETRY_REPLAY_TRANSITIONS = [ordered]@{}
$RETRY_REPLAY_REWARDS = [ordered]@{}
$RETRY_REPLAY_MISSES = [ordered]@{}
$RETRY_REPLAY_SETS = @{}
$retryReplayLists = @{}
$retryTableProblems = New-Object System.Collections.Generic.List[string]
$retryTableHeaderSeen = $false
function ConvertTo-RetryReplayPoint { param([string]$Text) if ($Text -ceq 'null') { return $null }; $pointParts = $Text -split ','; return @{ X = [int]$pointParts[0]; Y = [int]$pointParts[1] } }
foreach ($tableLine in @($RETRY_REPLAY_TABLE -split "`r?`n" | Where-Object { $_ -ne '' })) {
    $tableCells = @($tableLine -split "`t")
    switch ($tableCells[0]) {
        'M' {
            if ($tableCells.Count -ne 13) { $retryTableProblems.Add("M 칸 $($tableCells.Count)"); break }
            for ($cellIndex = 1; $cellIndex -lt 13; $cellIndex += 2) { $RETRY_REPLAY_MEDIAN_MS[[string]$tableCells[$cellIndex]] = [double]$tableCells[$cellIndex + 1] }
        }
        'T' {
            if (($tableCells.Count -ne 10) -or (@('solo', 'party') -notcontains $tableCells[3]) -or (@('open', 'closed') -notcontains $tableCells[5]) -or (@('open', 'closed') -notcontains $tableCells[7])) { $retryTableProblems.Add("T 꼴: $tableLine"); break }
            $RETRY_REPLAY_TRANSITIONS[[string]$tableCells[1]] = [pscustomobject]@{ Name = [string]$tableCells[1]; Set = [string]$tableCells[2]; Mode = [string]$tableCells[3]; Lo = $RETRY_REPLAY_DAY + [timespan]::Parse($tableCells[4]); LoOpen = ($tableCells[5] -ceq 'open')
                Hi = $RETRY_REPLAY_DAY + [timespan]::Parse($tableCells[6]); HiOpen = ($tableCells[7] -ceq 'open'); First = $RETRY_REPLAY_DAY + [timespan]::Parse($tableCells[8]); Expect = @(([string]$tableCells[9]) -split '\|') }
        }
        'U' {
            if ($tableCells.Count -ne 4) { $retryTableProblems.Add("U 꼴: $tableLine"); break }
            $RETRY_REPLAY_REWARDS[[string]$tableCells[1]] = [pscustomobject]@{ Name = [string]$tableCells[1]; Set = [string]$tableCells[2]; T0 = $RETRY_REPLAY_DAY + [timespan]::Parse($tableCells[3]) }
        }
        'Q' {
            if ($tableCells.Count -ne 5) { $retryTableProblems.Add("Q 꼴: $tableLine"); break }
            $RETRY_REPLAY_MISSES[[string]$tableCells[1]] = [pscustomobject]@{ Name = [string]$tableCells[1]; Set = [string]$tableCells[2]; T0 = $RETRY_REPLAY_DAY + [timespan]::Parse($tableCells[3]); Next = $RETRY_REPLAY_DAY + [timespan]::Parse($tableCells[4]) }
        }
        'F' {
            if (-not $retryTableHeaderSeen) {
                $retryTableHeaderSeen = $true
                if (($tableCells -join ',') -cne ($RETRY_REPLAY_FRAME_COLUMNS -join ',')) { $retryTableProblems.Add("F 머리 [$($tableCells -join ',')]") }
                break
            }
            $cellsOk = ($tableCells.Count -eq 13) -and ($tableCells[5] -cmatch '^(null|\d+,\d+)$') -and ($tableCells[6] -cmatch '^(null|\d+,\d+)$') -and
                (@($tableCells[7], $tableCells[9], $tableCells[10], $tableCells[11]) | Where-Object { @('True', 'False') -cnotcontains $_ }).Count -eq 0 -and
                (@('none', 'ready', 'matching') -ccontains $tableCells[8]) -and ($RETRY_REPLAY_CLASSES -ccontains $tableCells[12]) -and ($tableCells[3] -cmatch '\.png$')
            if (-not $cellsOk) { $retryTableProblems.Add("F 꼴: $tableLine"); break }
            if (-not $retryReplayLists.ContainsKey([string]$tableCells[1])) { $retryReplayLists[[string]$tableCells[1]] = New-Object System.Collections.Generic.List[object] }
            $frameAt = $RETRY_REPLAY_DAY + [timespan]::Parse($tableCells[2])
            $retryReplayLists[[string]$tableCells[1]].Add(@{ Ticks = $frameAt.Ticks; Frame = [string]$tableCells[2]; File = [string]$tableCells[3]; Key = ''; Bottom = [string]$tableCells[4]
                    Retry = (ConvertTo-RetryReplayPoint $tableCells[5]); Other = (ConvertTo-RetryReplayPoint $tableCells[6]); Prompt = ($tableCells[7] -ceq 'True'); Panel = [string]$tableCells[8]
                    Hud = ($tableCells[9] -ceq 'True'); Quest = ($tableCells[10] -ceq 'True'); Selection = $false; Sweep = ($tableCells[11] -ceq 'True'); Class = [string]$tableCells[12] })
        }
        default { $retryTableProblems.Add("모르는 줄: $tableLine") }
    }
}
# 묶음 = 배열 (List 를 그대로 두면 PS 5.1 의 @() 가 인수 형식 오류를 냄 - 배열로 한 번 바꿔 둠)
foreach ($replayListName in @($retryReplayLists.Keys)) { $RETRY_REPLAY_SETS[$replayListName] = $retryReplayLists[$replayListName].ToArray() }
foreach ($medianKind in $RETRY_REPLAY_KINDS) { if (-not $RETRY_REPLAY_MEDIAN_MS.ContainsKey($medianKind)) { $retryTableProblems.Add("M 에 $medianKind 없음") } }
foreach ($replayEntry in @(@($RETRY_REPLAY_TRANSITIONS.Values) + @($RETRY_REPLAY_REWARDS.Values) + @($RETRY_REPLAY_MISSES.Values))) { if (-not $RETRY_REPLAY_SETS.ContainsKey($replayEntry.Set)) { $retryTableProblems.Add("$($replayEntry.Name) 의 프레임 묶음 $($replayEntry.Set) 없음") } }
foreach ($replaySetName in @($RETRY_REPLAY_SETS.Keys)) {
    $setFrames = @($RETRY_REPLAY_SETS[$replaySetName])
    for ($frameIndex = 1; $frameIndex -lt $setFrames.Count; $frameIndex++) { if ($setFrames[$frameIndex].Ticks -le $setFrames[$frameIndex - 1].Ticks) { $retryTableProblems.Add("$replaySetName 프레임 시각이 차례가 아님: $($setFrames[$frameIndex].Frame)") } }
}
if (($RETRY_REPLAY_TRANSITIONS.Count -ne 7) -or ($RETRY_REPLAY_REWARDS.Count -ne 8) -or ($RETRY_REPLAY_MISSES.Count -ne 2)) { $retryTableProblems.Add("줄 수 T $($RETRY_REPLAY_TRANSITIONS.Count) · U $($RETRY_REPLAY_REWARDS.Count) · Q $($RETRY_REPLAY_MISSES.Count) (기대 7 · 8 · 2)") }
if (-not $retryTableHeaderSeen) { $retryTableProblems.Add('F 머리 없음') }
if ($retryTableProblems.Count -gt 0) { "FAIL 준비: 관측 0 전이 표의 열 꼴이 어긋납니다 ($(($retryTableProblems | Select-Object -First 5) -join ' · ') - 명세 2.2 · 3.5)"; exit 1 }
# RP 완전성(manifest) - 명세 리뷰 2 P3: 표에서 지은 글자 = F 줄을 나온 차례대로 묶음 덩어리(같은 묶음이 이어진 줄들)로 끊어 덩어리마다 '그 묶음을 쓰는 T · U · Q 행 이름(없으면 ? ·
#   여럿이면 +) 묶음 첫 끝 줄 수'. manifest 와 정확히 같아야 합니다 - 묶음 누락 · 군더더기 · 덩어리 차례 · 다른 묶음에 끼어든 줄(덩어리가 늚) · 줄 수 · 첫 · 끝 프레임 차이가 FAIL.
#   manifest 줄 꼴이 어긋나면 'FAIL 준비'
$retryManifestLines = @($RETRY_REPLAY_MANIFEST -split "`r?`n" | Where-Object { $_ -ne '' })
$retryManifestBad = @($retryManifestLines | Where-Object { -not ($_ -cmatch '^(RP|UP|UQ)\d+\t\S+\t\d{2}:\d{2}:\d{2}\.\d{3}\t\d{2}:\d{2}:\d{2}\.\d{3}\t\d+$') })
if (($retryManifestLines.Count -lt 1) -or ($retryManifestBad.Count -gt 0)) { "FAIL 준비: 관측 0 전이 표 manifest 의 줄 꼴이 어긋납니다 ($(($retryManifestBad | Select-Object -First 3) -join ' · ') - 명세 리뷰 2 P3)"; exit 1 }
$retrySetNames = @{}
foreach ($replayEntry in @(@($RETRY_REPLAY_TRANSITIONS.Values) + @($RETRY_REPLAY_REWARDS.Values) + @($RETRY_REPLAY_MISSES.Values))) {
    if (-not $retrySetNames.ContainsKey($replayEntry.Set)) { $retrySetNames[$replayEntry.Set] = New-Object System.Collections.Generic.List[string] }
    $retrySetNames[$replayEntry.Set].Add([string]$replayEntry.Name)
}
function Get-RetryTableBlockText {
    # 묶음 덩어리 한 줄 - '행 이름 묶음 첫 끝 줄 수' (manifest 와 같은 꼴 · 칸 사이 공백)
    param([string]$SetName, [string]$First, [string]$Last, [int]$Rows)
    $blockNames = $(if ($retrySetNames.ContainsKey($SetName)) { $retrySetNames[$SetName].ToArray() -join '+' } else { '?' })
    return ('{0} {1} {2} {3} {4}' -f $blockNames, $SetName, $First, $Last, $Rows)
}
$retryTableBlocks = New-Object System.Collections.Generic.List[string]
$retryBlockSet = $null; $retryBlockFirst = ''; $retryBlockLast = ''; $retryBlockRows = 0
foreach ($tableLine in @($RETRY_REPLAY_TABLE -split "`r?`n" | Where-Object { $_.StartsWith("F`t") })) {
    $tableCells = @($tableLine -split "`t")
    if ($tableCells[1] -ceq 'set') { continue }
    if ($tableCells[1] -cne $retryBlockSet) {
        if ($null -ne $retryBlockSet) { $retryTableBlocks.Add((Get-RetryTableBlockText -SetName $retryBlockSet -First $retryBlockFirst -Last $retryBlockLast -Rows $retryBlockRows)) }
        $retryBlockSet = [string]$tableCells[1]; $retryBlockFirst = [string]$tableCells[2]; $retryBlockRows = 0
    }
    $retryBlockLast = [string]$tableCells[2]
    $retryBlockRows++
}
if ($null -ne $retryBlockSet) { $retryTableBlocks.Add((Get-RetryTableBlockText -SetName $retryBlockSet -First $retryBlockFirst -Last $retryBlockLast -Rows $retryBlockRows)) }
Check-Equal ('RP 완전성(manifest) - 표의 프레임 묶음 덩어리(행 이름 · 묶음 · 첫 · 끝 프레임 · 줄 수 - 나온 차례) = 표와 따로 둔 manifest {0}줄 (누락 · 군더더기 · 차례 · 끼어든 줄 · 줄 수 차이 0)' -f $retryManifestLines.Count) `
    ($retryTableBlocks.ToArray() -join ' / ') ((@($retryManifestLines | ForEach-Object { $_ -replace "`t", ' ' })) -join ' / ')

function Get-RetryReplayFrame {
    # 그 가상 시각에 보이던 프레임 = 그 묶음 안에서 시각 이하 마지막 프레임 (묶음 끝 + 0.5초를 넘으면 '__EOD__' = 자료 끝 · 재생 틀과 같은 꼴).
    #   팝업 닫힘 모형: 스윕 클릭 뒤 닫힘 시각이 지난 조회에서 스윕 참 프레임이면 팝업이 끝난 첫 프레임
    param([datetime]$At)
    $frameList = $script:retryReplayFrames
    $atTicks = $At.Ticks
    if ($atTicks -gt ($frameList[$frameList.Count - 1].Ticks + (ConvertTo-Ticks 0.5))) { throw '__EOD__' }
    $low = 0; $high = $frameList.Count - 1; $found = -1
    while ($low -le $high) { $middle = [int][Math]::Floor(($low + $high) / 2); if ($frameList[$middle].Ticks -le $atTicks) { $found = $middle; $low = $middle + 1 } else { $high = $middle - 1 } }
    if ($found -lt 0) { throw 'TEST: 재생 묶음 첫 프레임보다 이른 조회' }
    if (($null -ne $script:retryPopupClosedAt) -and ($At -ge $script:retryPopupClosedAt) -and $frameList[$found].Sweep) {
        while (($found -lt ($frameList.Count - 1)) -and $frameList[$found].Sweep) { $found++ }
    }
    return $frameList[$found]
}
function Invoke-RetryReplaySweep {
    # 재생 스윕 - 프레임의 스윕 참이면 퀘스트 보상 '확인' 클릭 450ms · 그 0.35초 뒤 팝업 닫힘 · 원문 1초 대기 · 전송 메타 (재생 틀 replay_r5_2a 와 같은 모형 [추정])
    $sweepFrame = Get-RetryReplayFrame -At $script:vclock
    Step-VirtualClock (Get-RetryReadCost 'sweep')
    if (-not $sweepFrame.Sweep) { return $false }
    $script:retryReplaySweeps++
    Step-VirtualClock 0.45
    if ($null -eq $script:retryPopupClosedAt) { $script:retryPopupClosedAt = $script:vclock.AddMilliseconds(350) }
    Step-VirtualClock 1.0
    $script:lastClickPerformed = $true
    $script:lastClickSkipReason = ''
    return $true
}
# 재입장 대기 표본 감시 - 원문 결론 판정을 이름 바꿔 올리고 같은 이름은 대기 안 결론(⑨ - 유효 회전마다 한 번, -Kind = 그 회전 ⑧ 분류)마다 (그 회전 하단 판독 프레임 · 원문 분류 ·
#   표의 고정 분류)를 기록하는 감시가 차지합니다. 분류기가 아니라 결론을 봅니다 - 필드 결과 켬의 앞 분류(세 신호 없이 부름)가 표본으로 두 번 세어지지 않고 ⑧ 분류 호출의
#   인자 꼴과 무관(구현 리뷰 2/2 의 4/5 - 분류기 감시를 -MenuVisible 로 거르던 판은 HEAD 워커에서 RP1~RP7 이 결과는 맞는데 '표본 0' 으로 FAIL. ⑧ 인자 누락은 M75 를 FC-L16 · L17 · R5-P8 이 잡음)
#   원문 분류기의 이름 바꾼 사본은 그대로 올립니다 - 아래 'RP 전제'(표 고정 분류 = 원문 분류)가 부름
try {
    Invoke-Expression (([string]$workerFunctions['Resolve-AbyssHandoffStartScreen'].Extent.Text) -replace '^function Resolve-AbyssHandoffStartScreen\b', 'function Invoke-RealResolveAbyssHandoffStartScreen')
    Invoke-Expression (([string]$workerFunctions['Resolve-AbyssReentryVerdict'].Extent.Text) -replace '^function Resolve-AbyssReentryVerdict\b', 'function Invoke-RealResolveAbyssReentryVerdict')
    Invoke-Expression (New-MockDefinition -Name 'Resolve-AbyssReentryVerdict' -Body 'if ($script:retryInWaiter -gt 0) { $script:retryWaiterSamples.Add([pscustomobject]@{ T = (Get-VirtualElapsed); Frame = $script:retryWaiterFrame; Live = [string]$Kind; Frozen = $script:retryWaiterFrameClass; LastFrozen = [string]$script:retryReads[$script:retryReads.Count - 1].Class }) }; return (Invoke-RealResolveAbyssReentryVerdict @PSBoundParameters)')
} catch {
    "FAIL 준비: ⑤b4 재생 결론 감시 정의 실패 ($($_.Exception.Message))"
    exit 1
}
if ((Get-LiveParamSignature 'Resolve-AbyssReentryVerdict') -cne (Get-ParamSignature 'Resolve-AbyssReentryVerdict')) { "FAIL 준비: 결론 감시 서명이 워커 원문과 다릅니다"; exit 1 }
function Invoke-RetryReplayRun {
    # 재생 한 번 - 묶음 · 시작 시각 · 모드 · 비용 모형(중앙값 × 배수 + 캡처 ms) · 들머리(waiter = 원문 재입장 대기 호출 B 꼴 · click = 클릭 루프). 결과 'EOD' = 자료 끝
    param([string]$Set, [datetime]$StartAt, [string]$Mode, [double]$Factor, [double]$CaptureMs, [string]$Entry)
    Reset-RetryRow -Spec @{ Mode = $Mode }
    $script:caseStart = $StartAt
    $script:vclock = $StartAt
    $script:retryReplay = $true
    $script:retryReplayFrames = $RETRY_REPLAY_SETS[$Set]
    $script:retryReplayFactor = $Factor
    $script:retryReplayCaptureMs = $CaptureMs
    $script:retryPopupClosedAt = $null
    $script:retryReplaySweeps = 0
    $replayResult = ''
    try {
        if ($Entry -eq 'waiter') { $replayOut = Wait-AbyssReentry -Game $null -LimitSeconds (Get-AbyssReentryLimitSeconds) -Context "'다시 하기' 뒤 입장 대기" -ReportRewardReturn -ReportFieldReturn:($dungeonMode -ne 'solo') }
        else { $replayOut = Invoke-AbyssRetryClick -Game $null -Nonce $RETRY_NONCE }
        $replayResult = [string]$replayOut.Result
    } catch {
        $replayMessage = [string]$_.Exception.Message
        $replayResult = $(if ($replayMessage -ceq '__EOD__') { 'EOD' } else { 'ERR:' + $replayMessage })
    } finally {
        $script:retryReplay = $false
    }
    # 완료 기록 - 재생 실행도 행마다 실제 파일(클릭 루프 들머리는 retry-attempt · retry-clicked 를 씀) - J0r 이 실행 전부를 모아 봅니다
    $script:retryReplayRunCount++
    foreach ($journalProblem in @(Get-RetryJournalProblems -Seed $script:retryJournalSeedState -State (Get-RetryJournalState) -Records $script:retryJournal.ToArray())) { $script:retryReplayJournalBad.Add(('{0}@{1}: {2}' -f $Set, $StartAt.ToString('HH:mm:ss.fff'), $journalProblem)) }
    $replaySamples = $script:retryWaiterSamples.ToArray()
    $panelAt = -1
    for ($sampleIndex = 0; $sampleIndex -lt $replaySamples.Count; $sampleIndex++) { if (@('popup', 'ready', 'matching', 'entry-waiting') -contains $replaySamples[$sampleIndex].Live) { $panelAt = $sampleIndex; break } }
    $rewardAfterPanel = $(if ($panelAt -ge 0) { @($replaySamples[($panelAt + 1)..($replaySamples.Count)] | Where-Object { ($null -ne $_) -and ($_.Live -ceq 'reward3') }).Count } else { 0 })
    return [pscustomobject]@{ Result = $replayResult; T = (Get-VirtualElapsed); Samples = $replaySamples; PanelAt = $panelAt; RewardAfterPanel = $rewardAfterPanel; Clicks = $script:retryClicks.ToArray()
        ClickReads = @($script:retryReads | Where-Object { ($_.Name -eq 'pair') -and $_.InClick }); Sweeps = $script:retryReplaySweeps
        MissFirst = @($script:rowLogs | Where-Object { $_.StartsWith($RETRY_LINE_MISS_FIRST_PREFIX, [StringComparison]::Ordinal) }).Count
        MissEnd = @($script:rowLogs | Where-Object { $_.StartsWith($RETRY_LINE_MISS_END_PREFIX, [StringComparison]::Ordinal) }).Count }
}
function Get-RetryClickGrid {
    # 클릭 구간 두 점 - 아래 끝(열린 끝이면 + 1ms) · 위 끝(열린 끝이면 − 1ms) (재생 B 격자의 양 끝)
    param($Transition)
    return @($(if ($Transition.LoOpen) { $Transition.Lo.AddMilliseconds(1) } else { $Transition.Lo }), $(if ($Transition.HiOpen) { $Transition.Hi.AddMilliseconds(-1) } else { $Transition.Hi }))
}
function Format-RetryReplayRun {
    param($Run)
    $sampleText = (@($Run.Samples | ForEach-Object { '{0}:{1}/{2}/{3}' -f $_.Frame, $_.Live, $_.Frozen, $_.LastFrozen }) | Select-Object -Last 6) -join ' '
    return ('결과={0} T={1} 패널 자리={2} 패널 뒤 reward3={3} 표본 {4}[…{5}]' -f $Run.Result, (Format-Seconds $Run.T), $Run.PanelAt, $Run.RewardAfterPanel, @($Run.Samples).Count, $sampleText)
}
function Test-RetryReplayDecision {
    # 결정 표본 대조 - 'entered' = 마지막 두 표본(회전마다 분류 하나)이 inside(던전 안 2연속 - 한 회전의 판독 넷은 프레임이 바뀌는 순간 서로 다른 프레임을 읽을 수 있어 원문 분류로 셈)이고
    #   결정 표본의 마지막 판독(추적기) 프레임이 표에서 던전 안(고정 분류 inside) · 'cancelled' = 마지막 표본의 하단 판독 프레임이 표에서 3버튼(고정 분류 reward3 - 취소 뒤 첫 3버튼)이고
    #   패널 뒤 첫 reward3 표본(패널 뒤 reward3 = 그 하나) · 'EOD' = 결론 없음 · 셋 다 패널 뒤 'reward3' 은 결정 표본뿐(정상 전이는 0 - R5-2a)
    param($Run)
    $runSamples = @($Run.Samples)
    switch ($Run.Result) {
        'entered' { return (($runSamples.Count -ge 2) -and ($runSamples[$runSamples.Count - 1].Live -ceq 'inside') -and ($runSamples[$runSamples.Count - 2].Live -ceq 'inside') -and ($runSamples[$runSamples.Count - 1].LastFrozen -ceq 'inside') -and ($Run.RewardAfterPanel -eq 0)) }
        'cancelled' { return (($runSamples.Count -ge 1) -and ($Run.PanelAt -ge 0) -and ($runSamples[$runSamples.Count - 1].Frozen -ceq 'reward3') -and ($Run.RewardAfterPanel -eq 1)) }
        'EOD' { return ($Run.RewardAfterPanel -eq 0) }
    }
    return $false
}
# RP1~RP7 - 전이 일곱: 대기 시작 = 클릭 구간 두 점 + 지연(0.05 · 1.45초 - 재생 B 지연 격자의 양 끝) · 비용 모형 둘(×1 + 30 · ×4 + 120ms) = 전이마다 8 실행. 기대 = 결과 ∈ 표의 기대
#   (RP2 = 'entered' 또는 자료 끝 - 채팅 입력창 구간) · 결정 표본 · 패널 뒤 'reward3' = 결정 표본뿐 · 'reclick' · 'cancelled'(O-3 밖) 0
$RETRY_REPLAY_DELAYS = @(0.05, 1.45)
$RETRY_REPLAY_FACTORS = @(@(1, 30), @(4, 120))
$retryReplayTallies = New-Object System.Collections.Generic.List[string]
$script:retryReplayRunCount = 0
$script:retryReplayJournalBad = New-Object System.Collections.Generic.List[string]
foreach ($replayTransition in $RETRY_REPLAY_TRANSITIONS.Values) {
    $transitionRuns = New-Object System.Collections.Generic.List[object]
    foreach ($clickAt in (Get-RetryClickGrid $replayTransition)) { foreach ($replayDelay in $RETRY_REPLAY_DELAYS) { foreach ($replayFactor in $RETRY_REPLAY_FACTORS) {
                $transitionRuns.Add((Invoke-RetryReplayRun -Set $replayTransition.Set -StartAt $clickAt.AddSeconds($replayDelay) -Mode $replayTransition.Mode -Factor $replayFactor[0] -CaptureMs $replayFactor[1] -Entry 'waiter'))
            } } }
    $badRuns = @($transitionRuns | Where-Object { ($replayTransition.Expect -cnotcontains $_.Result) -or (-not (Test-RetryReplayDecision $_)) })
    $resultTally = (@($transitionRuns | Group-Object Result | Sort-Object Name | ForEach-Object { '{0}={1}' -f $_.Name, $_.Count })) -join ','
    $decidedTimes = @($transitionRuns | Where-Object { $_.Result -cne 'EOD' } | ForEach-Object { [double]$_.T } | Sort-Object)
    $retryReplayTallies.Add(('{0} {1}{2}' -f $replayTransition.Name, $resultTally, $(if ($decidedTimes.Count -gt 0) { ' 결론 {0}~{1}초' -f (Format-Seconds $decidedTimes[0]), (Format-Seconds $decidedTimes[$decidedTimes.Count - 1]) } else { '' })))
    Check-True ("{0} 관측 0 전이 {1}({2}) · 클릭 구간 두 점 × 지연 둘 × 비용 둘 = {3} 실행 → 결과 ∈ [{4}] · 결정 표본(고정 분류) · 패널 뒤 'reward3' 은 결정 표본뿐 · reclick 0" -f $replayTransition.Name, $replayTransition.Set, $replayTransition.Mode, $transitionRuns.Count, ($replayTransition.Expect -join ' | ')) `
        ($badRuns.Count -eq 0) ('결과 [{0}] · 어긋난 실행 {1} · 첫 어긋남 {2}' -f $resultTally, $badRuns.Count, $(if ($badRuns.Count -gt 0) { Format-RetryReplayRun $badRuns[0] } else { '' }))
}
"INFO ⑤b4 재생(대기 시작 → 결론 가상 시간): $($retryReplayTallies -join ' / ')"
# RP8 - 대조(틀이 'reclick' 을 낼 수 있음 · 작성 판의 '첫 변화 − d' 시작): O-1 R1 을 첫 변화 11초 앞에서 시작 → 'reclick' / 5초 앞 → 'entered' (무변화 창 10초와 클릭 → 첫 변화 여유)
$rp8Transition = $RETRY_REPLAY_TRANSITIONS['RP1']
$rp8Early = Invoke-RetryReplayRun -Set $rp8Transition.Set -StartAt $rp8Transition.First.AddSeconds(-11) -Mode $rp8Transition.Mode -Factor 1 -CaptureMs 30 -Entry 'waiter'
$rp8Late = Invoke-RetryReplayRun -Set $rp8Transition.Set -StartAt $rp8Transition.First.AddSeconds(-5) -Mode $rp8Transition.Mode -Factor 1 -CaptureMs 30 -Entry 'waiter'
Check-Equal "RP8 대조 - O-1 R1 대기 시작 = 첫 변화 − 11초 → reclick (≥ 무변화 창 · 패널 관측 0) / − 5초 → entered" ('{0}@{1}/{2} · {3}' -f $rp8Early.Result, [int]($rp8Early.T -ge $Q), $rp8Early.PanelAt, $rp8Late.Result) 'reclick@1/-1 · entered'
# UP1~UP8 - 보상 화면 여덟: 클릭 루프 시작 = t0 + δ(0.3~8.0초 · 0.1 간격 - 3버튼 확인 · 마커 · 클리어 기록 · 스윕 시간을 덮음) · 비용 ×1 + 30 → 첫 회전 'sent' · 짝 판독 1 · 첫 줄 0 ·
#   누른 점 = 그 판독 프레임의 '다시 하기' 점 (U-⑤-3 1272 결측 0 - 명세 3.5)
foreach ($replayReward in $RETRY_REPLAY_REWARDS.Values) {
    $rewardRuns = New-Object System.Collections.Generic.List[object]
    foreach ($deltaStep in 3..80) {
        $rewardRun = Invoke-RetryReplayRun -Set $replayReward.Set -StartAt $replayReward.T0.AddSeconds($deltaStep / 10.0) -Mode 'solo' -Factor 1 -CaptureMs 30 -Entry 'click'
        $rewardRun | Add-Member -NotePropertyName Delta -NotePropertyValue ($deltaStep / 10.0)
        $rewardRuns.Add($rewardRun)
    }
    $badRewards = @($rewardRuns | Where-Object {
            $firstReadName = $(if (@($_.ClickReads).Count -ge 1) { [string]@($_.ClickReads)[0].Frame } else { '' })
            $readFrame = @($RETRY_REPLAY_SETS[$replayReward.Set] | Where-Object { $_.Frame -ceq $firstReadName })
            $readPoint = $(if ($readFrame.Count -eq 1) { $readFrame[0].Retry } else { $null })
            -not (($_.Result -ceq 'sent') -and (@($_.ClickReads).Count -eq 1) -and ($_.MissFirst -eq 0) -and (@($_.Clicks).Count -eq 1) -and ($null -ne $readPoint) -and
                (@($_.Clicks)[0].X -eq $readPoint.X) -and (@($_.Clicks)[0].Y -eq $readPoint.Y))
        })
    $pointTally = (@($rewardRuns | ForEach-Object { if (@($_.Clicks).Count -ge 1) { '{0},{1}' -f @($_.Clicks)[0].X, @($_.Clicks)[0].Y } else { 'none' } } | Group-Object | Sort-Object Name | ForEach-Object { '({0})x{1}' -f $_.Name, $_.Count })) -join ' '
    Check-True ("{0} 보상 화면 {1}(t0 {2}) · δ 0.3~8.0초 78 실행 → 첫 회전 'sent' · 짝 판독 1 · 짝 없음 첫 줄 0 · 누른 점 = 그 판독 프레임의 '다시 하기' 점" -f $replayReward.Name, $replayReward.Set, $replayReward.T0.ToString('HH:mm:ss.fff')) `
        ($badRewards.Count -eq 0) ('점 [{0}] · 어긋난 실행 {1}{2}' -f $pointTally, $badRewards.Count, $(if ($badRewards.Count -gt 0) { ' · 첫 어긋남 δ={0} 결과={1} 짝 판독={2} 첫 줄={3}' -f $badRewards[0].Delta, $badRewards[0].Result, @($badRewards[0].ClickReads).Count, $badRewards[0].MissFirst } else { '' }))
}
# UQ1 · UQ2 - 1908 · 창 DPI 144 결측 두 판: 첫 짝 판독 시각 = t0 + Δ(아래 끝 0.268 · PC 최소 0.484 · ×1 + 30 0.560 · PC 중앙 0.579 · ×2 + 60 0.994초 - 재생 A 모형) · 비용 ×1 + 30 →
#   첫 판독 = t0 프레임(Retry 없음) → 짝 없음 첫 줄 1 → 재판독(⑫ 1초) → 둘째 판독 = 다 올라온 무커서 프레임 → 'sent' · 그 점 (재생 A′ 의 화면 모형 M1′ - 효과는 [추정] · 실기 ③-3 이 봄)
$RETRY_REPLAY_MISS_DELTAS = @(0.268, 0.484, 0.560, 0.579, 0.994)
foreach ($replayMiss in $RETRY_REPLAY_MISSES.Values) {
    $missRuns = New-Object System.Collections.Generic.List[object]
    $sweepCostSeconds = ([double]$RETRY_REPLAY_MEDIAN_MS['sweep'] + 30) / 1000.0
    foreach ($missDelta in $RETRY_REPLAY_MISS_DELTAS) {
        $missRun = Invoke-RetryReplayRun -Set $replayMiss.Set -StartAt $replayMiss.T0.AddSeconds($missDelta - $sweepCostSeconds) -Mode 'solo' -Factor 1 -CaptureMs 30 -Entry 'click'
        $missRun | Add-Member -NotePropertyName Delta -NotePropertyValue $missDelta
        $missRuns.Add($missRun)
    }
    $missFrames = @($RETRY_REPLAY_SETS[$replayMiss.Set])
    $firstFrame = @($missFrames | Where-Object { $_.Ticks -eq $replayMiss.T0.Ticks })
    $nextFrame = @($missFrames | Where-Object { $_.Ticks -eq $replayMiss.Next.Ticks })
    $badMisses = @($missRuns | Where-Object {
            $missReads = @($_.ClickReads)
            -not (($firstFrame.Count -eq 1) -and ($nextFrame.Count -eq 1) -and ($null -eq $firstFrame[0].Retry) -and ($null -ne $nextFrame[0].Retry) -and ($_.Result -ceq 'sent') -and ($missReads.Count -eq 2) -and
                ($missReads[0].Frame -ceq $firstFrame[0].Frame) -and ($missReads[1].Frame -ceq $nextFrame[0].Frame) -and ($_.MissFirst -eq 1) -and ($_.MissEnd -eq 0) -and (@($_.Clicks).Count -eq 1) -and
                (@($_.Clicks)[0].X -eq $nextFrame[0].Retry.X) -and (@($_.Clicks)[0].Y -eq $nextFrame[0].Retry.Y))
        })
    Check-True ("{0} 1908 결측 판 {1}(t0 {2}) · 첫 짝 판독 t0 + Δ 다섯 → 첫 판독 결측(첫 줄 1) → 둘째 판독 다 올라온 무커서 프레임(다음 저장 {3}) → 'sent' 그 점 · 짝 없음 줄 0" -f $replayMiss.Name, $replayMiss.Set, $replayMiss.T0.ToString('HH:mm:ss.fff'), $replayMiss.Next.ToString('HH:mm:ss.fff')) `
        ($badMisses.Count -eq 0) ('어긋난 실행 {0}{1}' -f $badMisses.Count, $(if ($badMisses.Count -gt 0) { ' · 첫 어긋남 Δ={0} 결과={1} 판독=[{2}] 첫 줄={3} 짝 없음 줄={4} 클릭=[{5}]' -f $badMisses[0].Delta, $badMisses[0].Result, ((@($badMisses[0].ClickReads | ForEach-Object { $_.Frame })) -join ','), $badMisses[0].MissFirst, $badMisses[0].MissEnd, ((@($badMisses[0].Clicks | ForEach-Object { '{0},{1}' -f $_.X, $_.Y })) -join ' ') } else { '' }))
}
# 표 고정 분류 = 원문 분류(재입장 대기 꼴 - S · 하단 · 패널 · HUD · 추적기(HUD 참일 때만)) - 분류기가 바뀌면 여기서 FAIL (결정 표본 대조의 전제)
$retryFrozenMismatches = @(foreach ($replaySetName in @($RETRY_REPLAY_SETS.Keys | Sort-Object)) {
        foreach ($replayFrame in @($RETRY_REPLAY_SETS[$replaySetName])) {
            $liveClass = Invoke-RealResolveAbyssHandoffStartScreen -PromptVisible $replayFrame.Prompt -BottomText $replayFrame.Bottom -PanelKind $replayFrame.Panel -HudVisible $replayFrame.Hud -InDungeonQuest ($replayFrame.Hud -and $replayFrame.Quest)
            if ($liveClass -cne $replayFrame.Class) { '{0}@{1}:{2}≠{3}' -f $replaySetName, $replayFrame.Frame, $liveClass, $replayFrame.Class }
        }
    })
Check-True "RP 전제 - 전이 표의 고정 분류 = 원문 분류기(Resolve-AbyssHandoffStartScreen)가 그 판독값에 내는 분류 (프레임 $(@($RETRY_REPLAY_SETS.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum)장)" ($retryFrozenMismatches.Count -eq 0) (($retryFrozenMismatches | Select-Object -First 6) -join ' · ')
# J0r - 관측 0 재생 실행 전부(RP · RP8 · UP · UQ): 완료 기록 파일 상태 = 저장 경계 호출 기록(J0 과 같은 대조)
Check-True ('J0r 관측 0 재생 실행 {0} 전부 - 완료 기록 파일 상태 = 저장 경계 호출 기록(J0 과 같은 대조)' -f $script:retryReplayRunCount) (($script:retryReplayRunCount -ge 1) -and ($script:retryReplayJournalBad.Count -eq 0)) `
    (($script:retryReplayJournalBad | Select-Object -First 6) -join ' · ')
"INFO ⑤b4 완료 기록(실제 파일): 행 $($RETRY_ROWS.Count) · 재생 실행 $($script:retryReplayRunCount) · 원문 저장소 실제 쓰기 $($script:retryStoreWrites) · 저장 경계 주입 $($script:retryStoreInjected) · 저장소 재시도 대기 $($script:retryStoreSleeps)"
try { [IO.Directory]::Delete($RETRY_JOURNAL_ROOT, $true) } catch { "INFO ⑤b4 완료 기록 임시 폴더를 지우지 못했습니다 ($($_.Exception.Message))" }

# ── §11 ⑤b5 본류 보상 화면 꼬리 - 행 32(T- · ⑤b6 이 T-RS1 · T-RS2 · T-X1 · T-MX1~T-MX3 을 더함) · 정적 P5e-1~10 (구현 명세 ⑤b5 3.1 ④ §11 · 3.2 · ⑤b6 3.1 · 3.2 · 3.4 - 비교는 -ceq) ──
# 하니스(설계 v11 R3 6.6 하니스 조건 - 술어를 모의하지 않음): 워커 원문에서 ① 모드 읽기 문장(최상위 연속 문장 - config 읽기 dungeons.mode · dungeons.matching · 옛
#   partyState · '파티원' 별칭과 커스텀 항목 덮어쓰기) ② 자리7 지정 시각 읽기 if ③ 본류 try 의 ⓪ ~ try 끝 ④ 'left' if 를 AST 로 잘라 exit 토큰을 센티널 함수로 바꾼
#   사본을 행 함수 안에서 점소싱합니다(규칙 3). 모드 입력은 비커스텀 행 = config 모의(Get-ConfigValue) · 커스텀 행 = 행의 항목 토큰을 진짜 ConvertFrom-AbyssCustomItemSpec 으로
#   해석한 $script:abyssCustomPreparsed(워커의 같은 식 - $script:customItem 도 같은 값)이고 ① 을 지나 $dungeonMode · $abyssMatching 이 생깁니다(커스텀 행은 항목 값이 덮음).
#   진짜(워커 원문을 이 절에서 다시 올림): 경로 술어 · 보상 결정 · 기록 확인 · 재판단 · Get-DgTimeVerdict · Get-AbyssUntilTime · Get-LifeUntilDeadline · owner 해석 ·
#   항목 토큰 해석. 모의(원문 param 블록 그대로 - New-MockDefinition · 행 함수 범위 안에서만): Write-RunLog · 완료 마커(반환 bool) · 클리어 기록(Decision · NextOwner 기록 ·
#   태그) · 두 끝 함수(retry = 'record-failed' · 클릭 직전 재검사의 'safe-stop' · 'last' 반환(구현 명세 ⑤b6 1.6) 또는 exit 센티널 / other = exit 0) · 나가기 헬퍼 · 복귀 루프 ·
#   Get-ConfigValue · Test-Path · Get-Date. 결정 · 재판단 · 시간 판단 · 읽기는 원문을 감싼 감시로 호출 수를 셉니다('판단 0' 은 Get-Date 수로 재지 않음 - R3 6.6). 기대 줄은
#   꼬리 · 'left' · 해석 함수 안 문자열 상수를 AST 로 캡처합니다(결정 줄의 원인 조각 switch 셋은 대입 대상 이름 $otherCause · $exitCause · $moveCause 로 고르고, 'exit' 갈래의
#   조각은 그 사유의 뜻 구절도 봅니다 - 구현 명세 ⑤b6 3.4). 행 이름은 이 파일의 기존 이름(§10 K1 · K2 · §6b U1 · §6c RB2 · RB3 · §9 SEL-1)과 겹치지 않게 'T-' 를 붙입니다
#   (구현 명세 ⑤b5 내부 검토 P3-4)
$t11Problems = New-Object System.Collections.Generic.List[string]
$T11_EXIT_PREFIX = 'T11-EXIT:'
$T11_SAFE_STOP_PATH = 'X:\honeynogi-test\safe_stop.flag'   # 행의 안전 중지 예약 파일 자리(Test-Path 모의가 이 경로만 행 값으로 답함)
$T11_T = [datetime]'2026-10-01 10:00'                       # 행의 지정 시각 T
$T11_UNTIL_TEXT = $T11_T.ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
$T11_TOKEN_A = 'A|solo|어려움|허상의 정박지|없음'
$T11_TOKEN_B = 'A|solo|어려움|광기의 동굴|없음'
$T11_TOKEN_P = 'A|party|어려움|허상의 정박지|우연한 만남'     # 섞인 리스트의 다른 입장 방식 항목(같은 던전 · 난이도 - 구현 명세 ⑤b6 T-MX)
# 다음 판 owner(같은 바퀴 index 1 · 세대 2 - GUI 직렬화 모양 version 3) · 그 5필드의 기록 모양(세대는 항목의 형제 필드라 nextOwner 에 없음 - 구현 명세 ⑤b2 1.2)
$T11_OWNER_NEXT = '{"version":3,"fingerprint":"FP","orderKey":"","lap":1,"index":1,"item":"' + $T11_TOKEN_A + '","generation":2}'
$T11_OWNER_NEXT_P = '{"version":3,"fingerprint":"FP","orderKey":"","lap":1,"index":1,"item":"' + $T11_TOKEN_P + '","generation":2}'   # 다음 칸이 다른 입장 방식 항목인 판
$T11_OWNER_NEXT_FIELDS = 'fingerprint=FP,orderKey=,lap=1,index=1,item=' + $T11_TOKEN_A
$T11_NONCE = 'N-1'                                           # 클리어 기록 모의가 changed 일 때 돌려주는 nonce
$T11_RUN_ID = 'RUN-1'

# 추출 - 본류 try(최상위 try 중 '$game = Get-GameProcess' 를 품은 것)의 몸통 문장 · 최상위 문장
$t11MainTries = @($workerAst.EndBlock.Statements | Where-Object { ($_ -is [TryStatementAst]) -and $_.Body.Extent.Text.Contains('$game = Get-GameProcess') })
$t11Body = @()
if ($t11MainTries.Count -eq 1) { $t11Body = @($t11MainTries[0].Body.Statements) } else { $t11Problems.Add("본류 try $($t11MainTries.Count)개(1개여야 함)") }
$t11ZeroAt = -1; $t11ReadAt = -1; $t11LeftAt = -1
for ($t11Index = 0; $t11Index -lt $t11Body.Count; $t11Index++) {
    $t11Statement = $t11Body[$t11Index]
    if (($t11ZeroAt -lt 0) -and ((Get-NodeCode $t11Statement) -ceq "`$script:abyssRetryTimeVerdict = ''")) { $t11ZeroAt = $t11Index }
    if (($t11Statement -is [IfStatementAst]) -and ((Get-NodeCode $t11Statement.Clauses[0].Item1) -ceq "`$contentCategory -eq 'abyss'") -and (Test-HasCommand $t11Statement 'Get-AbyssUntilTime')) { $t11ReadAt = $t11Index }
    if (($t11Statement -is [IfStatementAst]) -and ((Get-NodeCode $t11Statement.Clauses[0].Item1) -ceq "`$clearOutcome -eq 'left'")) { $t11LeftAt = $t11Index }
}
$t11Top = @($workerAst.EndBlock.Statements)
$t11ModeFrom = -1; $t11ModeTo = -1
for ($t11Index = 0; $t11Index -lt $t11Top.Count; $t11Index++) {
    $t11Statement = $t11Top[$t11Index]
    if (($t11ModeFrom -lt 0) -and ($t11Statement -is [AssignmentStatementAst]) -and (Test-IsVariable $t11Statement.Left 'dungeonMode') -and (Get-NodeCode $t11Statement.Right).Contains("@('dungeons', 'mode')")) { $t11ModeFrom = $t11Index }
    if (($t11ModeFrom -ge 0) -and ($t11ModeTo -lt 0) -and ($t11Statement -is [IfStatementAst]) -and ((Get-NodeCode $t11Statement.Clauses[0].Item1) -ceq '$script:abyssCustomPreparsed') -and
        (@($t11Statement.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'dungeonMode') }, $true)).Count -gt 0)) { $t11ModeTo = $t11Index }
}
foreach ($t11Anchor in @(@('꼬리 첫 문장 ⓪', $t11ZeroAt), @('자리7 읽기 if', $t11ReadAt), @("'left' if", $t11LeftAt), @('모드 읽기 첫 문장', $t11ModeFrom), @('커스텀 항목 덮어쓰기 if', $t11ModeTo))) {
    if ($t11Anchor[1] -lt 0) { $t11Problems.Add("앵커 없음: $($t11Anchor[0])") }
}
function Convert-T11ExitTokens {
    # exit 토큰을 뒤에서부터 Stop-T11Exit 호출로 바꿉니다(워커를 끝내는 대신 종료 코드를 실은 예외 - ⑯ Stop-WorkerTailExit 와 같은 꼴). 원본 exit 문 수 = 바꾼 수 · 바꾼 뒤 0
    param([string]$Text)
    $exitTokens = $null; $exitErrors = $null
    $exitStatements = @([Parser]::ParseInput($Text, [ref]$exitTokens, [ref]$exitErrors).FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count
    $exitList = @($exitTokens | Where-Object { $_.Kind -eq [TokenKind]::Exit } | Sort-Object { $_.Extent.StartOffset } -Descending)
    foreach ($exitToken in $exitList) { $Text = $Text.Substring(0, $exitToken.Extent.StartOffset) + 'Stop-T11Exit' + $Text.Substring($exitToken.Extent.EndOffset) }
    $afterTokens = $null; $afterErrors = $null
    $afterStatements = @([Parser]::ParseInput($Text, [ref]$afterTokens, [ref]$afterErrors).FindAll({ param($candidate) $candidate -is [ExitStatementAst] }, $true)).Count
    return [pscustomobject]@{ Text = $Text; Statements = $exitStatements; Replaced = $exitList.Count; Remaining = $afterStatements; Errors = @($afterErrors).Count }
}
$T11_TAIL_BLOCK = $null; $T11_LEFT_BLOCK = $null; $T11_READ_BLOCK = $null; $T11_MODE_BLOCK = $null
$t11TailStatements = @(); $t11LeftStatement = $null
if ($t11Problems.Count -eq 0) {
    $t11TailStatements = @($t11Body[$t11ZeroAt..($t11Body.Count - 1)])
    $t11LeftStatement = $t11Body[$t11LeftAt]
    $t11TailConversion = Convert-T11ExitTokens -Text ((@($t11TailStatements | ForEach-Object { $_.Extent.Text })) -join "`r`n")
    $t11LeftConversion = Convert-T11ExitTokens -Text $t11LeftStatement.Extent.Text
    Check-Equal 'T-준비 꼬리 · left 사본 - exit 문 수 = 바꾼 토큰 수 · 바꾼 뒤 exit 문 0 · 파서 오류 0 (꼬리 / left)' `
        ('{0}={1}/{2}/{3} · {4}={5}/{6}/{7}' -f $t11TailConversion.Statements, $t11TailConversion.Replaced, $t11TailConversion.Remaining, $t11TailConversion.Errors,
            $t11LeftConversion.Statements, $t11LeftConversion.Replaced, $t11LeftConversion.Remaining, $t11LeftConversion.Errors) `
        ('{0}={0}/0/0 · {1}={1}/0/0' -f $t11TailConversion.Statements, $t11LeftConversion.Statements)
    $T11_TAIL_BLOCK = [scriptblock]::Create($t11TailConversion.Text)
    $T11_LEFT_BLOCK = [scriptblock]::Create($t11LeftConversion.Text)
    $T11_READ_BLOCK = [scriptblock]::Create($t11Body[$t11ReadAt].Extent.Text)
    $T11_MODE_BLOCK = [scriptblock]::Create((@($t11Top[$t11ModeFrom..$t11ModeTo] | ForEach-Object { $_.Extent.Text })) -join "`r`n")
    "INFO ⑤b5 §11 꼬리 문장 $($t11TailStatements.Count)개(워커 $($t11TailStatements[0].Extent.StartLineNumber)~$($t11TailStatements[-1].Extent.EndLineNumber)줄) · 읽기 $($t11Body[$t11ReadAt].Extent.StartLineNumber)줄 · left $($t11LeftStatement.Extent.StartLineNumber)줄 · 모드 읽기 최상위 문장 $($t11ModeTo - $t11ModeFrom + 1)개($($t11Top[$t11ModeFrom].Extent.StartLineNumber)~$($t11Top[$t11ModeTo].Extent.EndLineNumber)줄)"
} else {
    "FAIL 준비: ⑤b5 §11 추출 실패 ($($t11Problems -join ' · '))"
    $script:fails++
}

# 진짜 - 워커 원문을 다시 올립니다(앞 절의 감시·모의가 같은 이름을 가렸을 수 있음). 감시 셋(결정 · 재판단 · 시간 판단 · 읽기)은 원문을 Invoke-T11Real* 로 올리고 같은 이름은
#   행 함수 안의 감시가 차지합니다(원문 재판단이 부르는 Get-DgTimeVerdict 도 동적 범위로 그 감시에 닿음)
try {
    foreach ($t11Definition in @(Get-SourceFunctionDefinitions -Path $workerPath -Names @('Test-AbyssRetryRoute', 'Resolve-AbyssRewardBranch', 'Get-LifeUntilDeadline', 'ConvertFrom-AbyssCustomItemSpec', 'ConvertTo-AbyssJournalOwner'))) {
        Invoke-Expression ([string]$t11Definition)
    }
    $T11_REAL_RENAMES = [ordered]@{ 'Resolve-AbyssRewardDecision' = 'Invoke-T11RealRewardDecision'; 'Update-AbyssRetryTimeVerdict' = 'Invoke-T11RealUpdateTimeVerdict'
        'Get-DgTimeVerdict' = 'Invoke-T11RealDgTimeVerdict'; 'Get-AbyssUntilTime' = 'Invoke-T11RealGetAbyssUntilTime' }
    foreach ($t11Rename in $T11_REAL_RENAMES.GetEnumerator()) {
        Invoke-Expression (([string](Get-WorkerFunction $t11Rename.Key).Extent.Text) -replace ('^function ' + [regex]::Escape($t11Rename.Key) + '\b'), ('function ' + $t11Rename.Value))
    }
} catch {
    "FAIL 준비: ⑤b5 §11 원문 함수를 올리지 못했습니다 ($($_.Exception.Message))"
    $script:fails++
}
# 모의 - 원문 param 블록 그대로(New-MockDefinition) + 스텁 몸통. 행 함수가 매 행 자기 범위 안에서 정의합니다(파일 최상위의 앞 절 모의는 그대로 둠)
$T11_MOCK_BODIES = [ordered]@{
    'Write-RunLog'                 = '$script:t11Logs.Add([string]$Message)'
    'Write-CustomClearMarker'      = '$script:t11Count.Marker++; return [bool]$script:t11MarkerResult'
    'Add-AbyssJournalClearedEntry' = 'return (Invoke-T11ClearedRecord -Decision $Decision -NextOwner $NextOwner)'
    'Complete-AbyssRetrySelection' = '$script:t11Calls.Add(''retry:'' + $Nonce); if (@(''record-failed'', ''safe-stop'', ''last'') -ccontains $script:t11RetryEnd) { return $script:t11RetryEnd }; Stop-T11Exit ([int]$script:t11RetryEnd)'
    'Complete-AbyssOtherSelection' = '$script:t11Calls.Add(''other:'' + $Ending); Stop-T11Exit 0'
    'Invoke-AbyssExitClick'        = '$script:t11Calls.Add(''exitclick''); return ''gone'''
    'Return-ToAbyssSelection'      = '$script:t11Calls.Add((''return:{0}/{1}'' -f $SafeStopExitCode, $LeaveEntryReason))'
    'Get-ConfigValue'              = '$configKey = $Path -join ''.''; if ($script:t11Config.ContainsKey($configKey)) { return $script:t11Config[$configKey] }; return $Default'
    'Resolve-AbyssRewardDecision'  = '$script:t11Count.Decision++; return (Invoke-T11RealRewardDecision @PSBoundParameters)'
    'Update-AbyssRetryTimeVerdict' = '$script:t11Count.Update++; return (Invoke-T11RealUpdateTimeVerdict)'
    'Get-DgTimeVerdict'            = '$script:t11Count.Dg++; return (Invoke-T11RealDgTimeVerdict -UntilTime $UntilTime -Now $Now)'
    'Get-AbyssUntilTime'           = '$script:t11Count.Until++; return (Invoke-T11RealGetAbyssUntilTime)'
}
$T11_DEFINITIONS = @()
try {
    $T11_DEFINITIONS = @(foreach ($t11Mock in $T11_MOCK_BODIES.GetEnumerator()) { New-MockDefinition -Name $t11Mock.Key -Body $t11Mock.Value }) + @(
        'function Test-Path { param($LiteralPath, $Path, $PathType) if ([string]$LiteralPath -ceq $T11_SAFE_STOP_PATH) { return [bool]$script:t11SafeStop }; return $false }',
        'function Get-Date { return $script:t11Now }',
        'function Stop-T11Exit { param([int]$Code) throw ($T11_EXIT_PREFIX + $Code) }')
} catch {
    "FAIL 준비: ⑤b5 §11 모의 정의 실패 ($($_.Exception.Message))"
    $script:fails++
}
# 서명 대조 - 모의 정의의 param 블록 = 워커 원문 param 블록(같은 글자 - New-MockDefinition 이 원문을 복사하므로 원문 이름이 바뀌면 준비에서 멈춤)
$t11SignatureBad = @(foreach ($t11Mock in $T11_MOCK_BODIES.Keys) {
        $t11MockAst = @([Parser]::ParseInput((New-MockDefinition -Name $t11Mock -Body ''), [ref]$null, [ref]$null).FindAll({ param($candidate) $candidate -is [FunctionDefinitionAst] }, $true))[0]
        $t11MockParams = $(if ($null -ne $t11MockAst.Body.ParamBlock) { $t11MockAst.Body.ParamBlock.Extent.Text } else { '' })
        $t11WorkerParams = $(if ($null -ne (Get-WorkerFunction $t11Mock).Body.ParamBlock) { (Get-WorkerFunction $t11Mock).Body.ParamBlock.Extent.Text } else { '' })
        if ($t11MockParams -cne $t11WorkerParams) { $t11Mock }
    })
Check-Equal "T-준비 모의 $($T11_MOCK_BODIES.Count)개의 param 블록 = 워커 원문 (어긋난 이름)" ($t11SignatureBad -join ',') ''

function Invoke-T11ClearedRecord {
    # 클리어 기록 모의의 몸통 - 결정 · 다음 판 owner(필드 이름=값 - 없으면 '(없음)')를 적고 행의 태그로 답합니다(changed 면 nonce N-1)
    param([string]$Decision, $NextOwner)
    $ownerText = '(없음)'
    if ($null -ne $NextOwner) { $ownerText = (@($NextOwner.PSObject.Properties | ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }) -join ',') }
    $script:t11Cleared.Add(('{0}/{1}' -f $Decision, $ownerText))
    if ($script:t11ClearedTag -ceq 'changed') { return @{ Tag = 'changed'; Nonce = $T11_NONCE } }
    return @{ Tag = $script:t11ClearedTag; Nonce = '' }
}

$T11_ROW_FORMAT = 'exit {0} | until {1} | calls [{2}] | cleared [{3}] | marker {4} | dec {5} upd {6} dg {7} read {8} | zero {9}/{10}/{11} | logs [{12}]'
function Invoke-T11Row {
    # 한 행 - 모의 정의(이 함수 범위) → env · 상태 → ① 모드 읽기 → ② 읽기 → (꼬리 또는 left) 점소싱 → 결과 한 줄. 점소싱한 원문의 대입은 이 함수 범위에 남습니다(규칙 3)
    param([hashtable]$Row)
    foreach ($t11Definition in $T11_DEFINITIONS) { Invoke-Expression $t11Definition }
    $script:t11Logs = New-Object System.Collections.Generic.List[string]
    $script:t11Calls = New-Object System.Collections.Generic.List[string]
    $script:t11Cleared = New-Object System.Collections.Generic.List[string]
    $script:t11Count = @{ Marker = 0; Decision = 0; Update = 0; Dg = 0; Until = 0 }
    $script:t11MarkerResult = $(if ($Row.ContainsKey('Marker')) { [bool]$Row.Marker } else { $true })
    $script:t11ClearedTag = $(if ($Row.ClearedTag) { [string]$Row.ClearedTag } else { 'changed' })
    $script:t11RetryEnd = $(if ($Row.RetryEnd) { [string]$Row.RetryEnd } else { '0' })
    $script:t11SafeStop = [bool]$Row.SafeStop
    $script:t11Now = $(if ($Row.ContainsKey('Now')) { [datetime]$Row.Now } else { $T11_T.AddSeconds(-60) })
    $script:t11Config = @{}
    $env:HONEYNOGI_UNTIL_TIME = [string]$Row.Until
    $env:HONEYNOGI_CUSTOM_NEXT = [string]$Row.Next
    $env:HONEYNOGI_CUSTOM_NEXT_OWNER = [string]$Row.NextOwner
    $env:HONEYNOGI_CUSTOM_NEXT_BOUNDARY = [string]$Row.Boundary
    # 모드 입력 - 비커스텀 = config 두 키 / 커스텀 = 항목 토큰의 진짜 해석(워커의 같은 식)
    $script:abyssCustomPreparsed = $null
    $script:customItem = $null
    $script:customNext = $null
    if ($Row.ItemToken) {
        $script:abyssCustomPreparsed = ConvertFrom-AbyssCustomItemSpec -Spec ([string]$Row.ItemToken)
        $script:customItem = $script:abyssCustomPreparsed
        $script:customNext = ConvertFrom-AbyssCustomItemSpec -Spec ([string]$env:HONEYNOGI_CUSTOM_NEXT)
    } else {
        $script:t11Config['dungeons.mode'] = [string]$Row.Mode
        $script:t11Config['dungeons.matching'] = [string]$Row.Matching
    }
    $config = $null
    $dungeonMode = '(모드 읽기 전)'
    $abyssMatching = '(모드 읽기 전)'
    . $T11_MODE_BLOCK
    $contentCategory = 'abyss'
    $script:abyssUntil = $null
    . $T11_READ_BLOCK
    $untilText = $(if ($null -eq $script:abyssUntil) { '(null)' } else { ([datetime]$script:abyssUntil).ToString('yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture) })
    $script:customMode = [bool]$Row.ItemToken
    $script:customCleanupOnly = [bool]$Row.Cleanup
    $script:finishOnly = [bool]$Row.FinishOnly
    $script:dgLastRun = [bool]$Row.LastRun
    $script:abyssRunId = $T11_RUN_ID
    $script:abyssLeaveCause = ''
    $script:abyssRetryTimeVerdict = 'stale'; $script:abyssRetryCommitted = 'stale'; $script:abyssRetryAttemptRecorded = 'stale'
    $clearOutcome = $(if ($Row.Outcome) { [string]$Row.Outcome } else { 'clear' })
    $game = $null
    $timeoutHud = 30; $timeoutAbyssMenu = 30; $timeoutAbyssSelect = 15
    $safeStopFlagPath = $T11_SAFE_STOP_PATH
    $t11Exit = '(end)'
    $t11Block = $(if ($clearOutcome -ceq 'left') { $T11_LEFT_BLOCK } else { $T11_TAIL_BLOCK })
    try { $null = . $t11Block } catch {
        $t11Message = [string]$_.Exception.Message
        if ($t11Message.StartsWith($T11_EXIT_PREFIX, [StringComparison]::Ordinal)) { $t11Exit = $t11Message.Substring($T11_EXIT_PREFIX.Length) } else { $t11Exit = 'ERR:' + $t11Message }
    }
    return ($T11_ROW_FORMAT -f $t11Exit, $untilText, ($script:t11Calls -join ' '), ($script:t11Cleared -join ' '), $script:t11Count.Marker, $script:t11Count.Decision,
        $script:t11Count.Update, $script:t11Count.Dg, $script:t11Count.Until, $script:abyssRetryTimeVerdict, $script:abyssRetryCommitted, $script:abyssRetryAttemptRecorded, ($script:t11Logs -join ' || '))
}

# 기대 줄 - 소스 캡처(꼬리 · left · 지정 시각 해석 함수의 문자열 상수)
function Get-T11String {
    # 노드들 아래 문자열 상수(StringConstant · ExpandableString) 중 -Prefix 로 시작하고 -Contains 를 품은 것 정확히 1개 (없거나 여럿이면 throw - 문구가 사라진 것 자체가 결함)
    param([object[]]$Nodes, [string]$Prefix, [string]$Contains = '')
    $t11Found = @(foreach ($t11Node in $Nodes) {
            $t11Node.FindAll({ param($candidate) (($candidate -is [StringConstantExpressionAst]) -or ($candidate -is [ExpandableStringExpressionAst])) -and
                    ([string]$candidate.Value).StartsWith($Prefix, [StringComparison]::Ordinal) -and ([string]$candidate.Value).Contains($Contains) }, $true)
        })
    if ($t11Found.Count -ne 1) { throw ("문구 '{0}…{1}' 가 {2}개입니다(1개여야 함)" -f $Prefix, $Contains, $t11Found.Count) }
    return $t11Found[0]
}
$T11_LINES = @{}
# 원인 조각 표 셋은 캡처 앞에 빈 표로 둡니다 - 추출 · 캡처가 실패한 워커(꼬리 ⓪ · 읽기 if 를 바꾼 변이 등)에서도 아래 행 표 만들기가 멈추지 않고(행은 준비 검사로 돌지
# 않음) 정적 P5e 가 이름으로 잡습니다(구현 명세 ⑤b5 3.3 'MW3 · MW6 → P5e-4 · P5e-1'). 표 = 'other' 갈래 $otherCause · 'exit' 갈래의 멈춤 $exitCause · 이어 감 $moveCause(구현 명세 ⑤b6 1.5)
$T11_CAUSES = @{}
$T11_EXIT_CAUSES = @{}
$T11_MOVE_CAUSES = @{}
try {
    $t11TimeNode = Get-T11String -Nodes $t11TailStatements -Prefix '[어비스] 지정 시간 ' -Contains '이번 판을 마지막으로'
    $T11_LINES['TimeFormat'] = ([string]$t11TimeNode.Value).Replace([string]$t11TimeNode.NestedExpressions[0].Extent.Text, '{0}')
    $T11_LINES['CauseFormat'] = ([string](Get-T11String -Nodes $t11TailStatements -Prefix '[어비스] ' -Contains '${otherCause}').Value).Replace('${otherCause}', '{0}')
    $T11_LINES['Marker'] = [string](Get-T11String -Nodes $t11TailStatements -Prefix '[어비스] 완료 마커를').Value
    $T11_LINES['Legacy'] = [string](Get-T11String -Nodes $t11TailStatements -Prefix '[어비스] 완료 기록을').Value
    $T11_LINES['RecordFailed'] = [string](Get-T11String -Nodes $t11TailStatements -Prefix '[경고] 재입장 요청 기록을').Value
    $T11_LINES['Done'] = [string](Get-T11String -Nodes $t11TailStatements -Prefix '[완료] 어비스 선택 화면 복귀 완료').Value
    $T11_LINES['LeftFinishFormat'] = ([string](Get-T11String -Nodes @($t11LeftStatement) -Prefix '[완료] ' -Contains '마무리 실행이라').Value).Replace('${leaveCause}', '{0}')
    $T11_LINES['LeftPrepFormat'] = ([string](Get-T11String -Nodes @($t11LeftStatement) -Prefix '[완료] ' -Contains '준비 실행').Value).Replace('${leaveCause}', '{0}')
    $t11CauseAssign = @($t11LeftStatement.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'leaveCause') }, $true))
    $T11_LINES['LeaveCause'] = [string](@($t11CauseAssign[0].FindAll({ param($candidate) $candidate -is [StringConstantExpressionAst] }, $true))[-1].Value)
    $T11_LINES['UntilWarnFormat'] = ([string](Get-T11String -Nodes @(Get-WorkerFunction 'Get-LifeUntilDeadline') -Prefix '[경고] 지정 시간 값을 해석하지 못했습니다').Value).Replace('$Raw', '{0}')
    # 결정 사유 → 원인 조각(꼬리의 switch 셋 - 대입 대상 이름으로 고릅니다 · 키 · 값 모두 문자열 상수 - 구현 명세 ⑤b6 3.4). ⑤b6 이 더한 캡처(멈춤 · 이어 감 조각 · 두 줄 형식)는
    #   앞의 캡처 뒤에 둡니다 - 그것이 없는 워커(고치기 전 · 변이)에서도 앞의 캡처는 남아 그 갈래의 행만 FAIL 합니다
    foreach ($t11CauseTarget in @(@('$otherCause', $T11_CAUSES), @('$exitCause', $T11_EXIT_CAUSES), @('$moveCause', $T11_MOVE_CAUSES))) {
        $t11CauseSwitch = @(foreach ($t11Node in $t11TailStatements) {
                $t11Node.FindAll({ param($candidate) ($candidate -is [SwitchStatementAst]) -and ((Get-NodeCode $candidate.Condition) -ceq '[string]$rewardDecision.Reason') -and
                        ($candidate.Parent -is [AssignmentStatementAst]) -and ($candidate.Parent.Left.Extent.Text -ceq $t11CauseTarget[0]) }, $true)
            })
        if ($t11CauseSwitch.Count -ne 1) { throw "결정 사유 switch($($t11CauseTarget[0])) 가 $($t11CauseSwitch.Count)개입니다(1개여야 함)" }
        foreach ($t11Clause in $t11CauseSwitch[0].Clauses) { $t11CauseTarget[1][[string]$t11Clause.Item1.Value] = [string](@($t11Clause.Item2.FindAll({ param($candidate) $candidate -is [StringConstantExpressionAst] }, $true))[0].Value) }
    }
    $T11_LINES['ExitCauseFormat'] = ([string](Get-T11String -Nodes $t11TailStatements -Prefix '[어비스] ${exitCause} ' -Contains '마칩니다').Value).Replace('${exitCause}', '{0}')
    # 이어 감 줄 형식은 맨 뒤에 - 그 줄의 뜻 구절 '다음 항목으로' 로 고르므로 끝말을 바꾼 워커에서는 여기서만 멈추고(앞 캡처는 남음) 이어 감 행(T-C5 · T-MX)이 FAIL 합니다
    $T11_LINES['MoveCauseFormat'] = ([string](Get-T11String -Nodes $t11TailStatements -Prefix '[어비스] ${moveCause} ' -Contains '다음 항목으로').Value).Replace('${moveCause}', '{0}')
} catch {
    "FAIL 준비: ⑤b5 §11 기대 줄 캡처 실패 ($($_.Exception.Message))"
    $script:fails++
}
function Get-T11Cause { param([string]$Reason) return ($T11_LINES['CauseFormat'] -f $T11_CAUSES[$Reason]) }
# 'exit' 갈래 결정 줄 - 캡처한 조각이 그 사유의 뜻 구절을 품을 때만 형식에 넣습니다. 조각만 캡처하면 두 사유의 조각을 맞바꾼 워커를 기대가 같이 따라가므로 사유마다 뜻을 봅니다
#   (구현 명세 ⑤b6 1.5 문구의 뜻 - 멈춤 셋 · 이어 감 셋. 뜻 구절이 없으면 어느 줄과도 같지 않은 표지를 돌려 그 행이 FAIL)
$T11_CAUSE_MEANINGS = @{ 'safe-stop' = '안전 중지'; 'finish-only' = '마무리'; 'last-run' = '마지막 판'; 'next-invalid' = '읽지 못해'; 'next-unknown' = '알 수 없어'; 'entry-change' = '입장 방식이 달라' }
function Get-T11CauseLine {
    param([string]$Format, [hashtable]$Table, [string]$Reason)
    $causeFragment = [string]$Table[$Reason]
    if (-not $causeFragment.Contains([string]$T11_CAUSE_MEANINGS[$Reason])) { return ('(원인 조각에 뜻 구절 없음: {0} [{1}])' -f $Reason, $causeFragment) }
    return ($Format -f $causeFragment)
}
function Get-T11ExitCause { param([string]$Reason) return (Get-T11CauseLine -Format $T11_LINES['ExitCauseFormat'] -Table $T11_EXIT_CAUSES -Reason $Reason) }
function Get-T11MoveCause { param([string]$Reason) return (Get-T11CauseLine -Format $T11_LINES['MoveCauseFormat'] -Table $T11_MOVE_CAUSES -Reason $Reason) }
$T11_LINE_TIME = $T11_LINES['TimeFormat'] -f $T11_T.ToString('HH:mm', [Globalization.CultureInfo]::InvariantCulture)
$T11_LINE_UNTIL_WARN = $T11_LINES['UntilWarnFormat'] -f '2026-10-01 10.00'

# 행 - 입력(Mode · Matching = config / ItemToken = 커스텀 항목 토큰 - 키 이름 'Item' 은 해시 표의 인덱서 속성과 겹쳐 쓰지 않음 · Until · Now · SafeStop · FinishOnly · LastRun · Next · NextOwner · Boundary · Cleanup · Marker · ClearedTag ·
#   RetryEnd · Outcome) · 기대(구현 명세 ⑤b5 3.1 표 · ⑤b6 3.1 · 3.4 · 설계 v11 R3 K1~K22 · R6 · R1 2.4 · R2 M4). 기대 줄은 위 캡처. 멈출 때(안전 중지 · 마무리 실행 · 마지막 판 ·
#   지정 시각)와 다음 판 입장 방식이 다르거나 모를 때(손상 · 미정 · 방식 다름)는 'exit' - 결정 줄 하나 뒤 옛 나가기(헬퍼 → 복귀 → [완료]) · 기록 exit(구현 명세 ⑤b6 1.2 · 1.5)
$t11RetryRow = 'exit 0 | until (null) | calls [retry:N-1] | cleared [retry/runId=RUN-1] | marker 0 | dec 1 upd 1 dg 1 read 1 | zero /False/False | logs []'
$t11OtherFormat = 'exit 0 | until {0} | calls [other:ready] | cleared [{1}] | marker {2} | dec 1 upd 1 dg 1 read 1 | zero {3}/False/False | logs [{4}]'
$t11ExitFormat = 'exit (end) | until {0} | calls [exitclick return:0/] | cleared [exit/(없음)] | marker {1} | dec 1 upd 1 dg 1 read 1 | zero {2}/False/False | logs [{3} || {4}]'
$t11LegacyFormat = 'exit (end) | until {0} | calls [{1}] | cleared [{2}] | marker 0 | dec {3} upd {3} dg {3} read 1 | zero /False/False | logs [{4}]'
$T11_ROWS = [ordered]@{
    'T-K1 혼자하기 · 지정 시각 없음 → retry 1(nonce = 기록 반환) · 기록 retry · runId · 재판단 1 · 판단값 '''''                = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남' }; Expect = $t11RetryRow }
    'T-K2 혼자하기 · T−60 → retry · 판단값 continue'                                                                         = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Until = $T11_UNTIL_TEXT }
        Expect = ('exit 0 | until {0} | calls [retry:N-1] | cleared [retry/runId=RUN-1] | marker 0 | dec 1 upd 1 dg 1 read 1 | zero continue/False/False | logs []' -f $T11_UNTIL_TEXT) }
    'T-K5 혼자하기 · 보상 결정 = T 정각 → exit(옛 나가기) · 기록 exit · 시간 줄 ① · 판단값 last'                             = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Until = $T11_UNTIL_TEXT; Now = $T11_T }
        Expect = ($t11ExitFormat -f $T11_UNTIL_TEXT, 0, 'last', $T11_LINE_TIME, $T11_LINES['Done']) }
    'T-K10 예약 + T 지남 → exit(옛 나가기) · 안전 중지 줄(시간 줄 0)'                                                       = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Until = $T11_UNTIL_TEXT; Now = $T11_T.AddSeconds(5); SafeStop = $true }
        Expect = ($t11ExitFormat -f $T11_UNTIL_TEXT, 0, 'last', (Get-T11ExitCause 'safe-stop'), $T11_LINES['Done']) }
    'T-K11 마무리 실행 + 마지막 판 + T+60 → exit(옛 나가기) · 마무리 줄(시간 줄 0)'                                           = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Until = $T11_UNTIL_TEXT; Now = $T11_T.AddSeconds(60); FinishOnly = $true; LastRun = $true }
        Expect = ($t11ExitFormat -f $T11_UNTIL_TEXT, 0, 'last', (Get-T11ExitCause 'finish-only'), $T11_LINES['Done']) }
    'T-K11s 마무리 실행 + 마지막 판 + 예약 남음(F9 가 commit 뒤) → exit(옛 나가기) · 안전 중지 줄 · 마무리 줄 0(순위 ①)'      = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; FinishOnly = $true; LastRun = $true; SafeStop = $true }
        Expect = ($t11ExitFormat -f '(null)', 0, '', (Get-T11ExitCause 'safe-stop'), $T11_LINES['Done']) }
    'T-K12 지정 시각 해석 실패 → [경고] 1(읽기 1) · 판단값 '''' · retry'                                                      = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Until = '2026-10-01 10.00' }
        Expect = ('exit 0 | until (null) | calls [retry:N-1] | cleared [retry/runId=RUN-1] | marker 0 | dec 1 upd 1 dg 1 read 1 | zero /False/False | logs [{0}]' -f $T11_LINE_UNTIL_WARN) }
    'T-K13 커스텀 같은 항목 + NEXT_OWNER → retry · 기록 nextOwner 5필드(세대 없음) · 마커 1'                                = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_A; NextOwner = $T11_OWNER_NEXT }
        Expect = ('exit 0 | until (null) | calls [retry:N-1] | cleared [retry/{0}] | marker 1 | dec 1 upd 1 dg 1 read 1 | zero /False/False | logs []' -f $T11_OWNER_NEXT_FIELDS) }
    'T-K21 파티 찾기(config) + T+60 → 옛 나가기(헬퍼 1 · 복귀 안전 중지 코드 0) · 기록 exit · 읽기 1 · until = T · 결정 · 재판단 · 시간 판단 0'   = @{ Spec = @{ Mode = 'party'; Matching = '파티찾기'; Until = $T11_UNTIL_TEXT; Now = $T11_T.AddSeconds(60) }
        Expect = ($t11LegacyFormat -f $T11_UNTIL_TEXT, 'exitclick return:0/', 'exit/(없음)', 0, $T11_LINES['Done']) }
    'T-K22 파티장(config) + T+60 → 옛 나가기 · 기록 exit · 읽기 1 · until = T · 결정 · 재판단 · 시간 판단 0'                 = @{ Spec = @{ Mode = 'party'; Matching = '파티(파티장)'; Until = $T11_UNTIL_TEXT; Now = $T11_T.AddSeconds(60) }
        Expect = ($t11LegacyFormat -f $T11_UNTIL_TEXT, 'exitclick return:0/', 'exit/(없음)', 0, $T11_LINES['Done']) }
    'T-U1 우연한 만남(config) → retry'                                                                                    = @{ Spec = @{ Mode = 'party'; Matching = '우연한 만남' }; Expect = $t11RetryRow }
    'T-SS6w 마지막 판(워커 쪽) → exit(옛 나가기) · 마지막 판 줄'                                                          = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; LastRun = $true }
        Expect = ($t11ExitFormat -f '(null)', 0, '', (Get-T11ExitCause 'last-run'), $T11_LINES['Done']) }
    'T-C1 커스텀 바퀴 끝(BOUNDARY 1 · OWNER 빈) → other · 경계 줄'                                                       = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_A; NextOwner = ''; Boundary = '1' }
        Expect = ($t11OtherFormat -f '(null)', 'other/(없음)', 1, '', (Get-T11Cause 'boundary')) }
    'T-C2 커스텀 다른 항목 → other · 다름 줄'                                                                             = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_B; NextOwner = $T11_OWNER_NEXT }
        Expect = ($t11OtherFormat -f '(null)', 'other/(없음)', 1, '', (Get-T11Cause 'item-change')) }
    'T-C3 커스텀 OWNER 빈 값(경계 아님) → other · 소유자 줄'                                                              = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_A; NextOwner = '' }
        Expect = ($t11OtherFormat -f '(null)', 'other/(없음)', 1, '', (Get-T11Cause 'next-owner-empty')) }
    'T-C4 커스텀 OWNER 해석 실패 → other · 소유자 줄'                                                                     = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_A; NextOwner = 'not json' }
        Expect = ($t11OtherFormat -f '(null)', 'other/(없음)', 1, '', (Get-T11Cause 'next-owner-empty')) }
    'T-C5 커스텀 NEXT 손상 → exit(옛 나가기 - 이어 감) · 기록 exit · 마커 1 · 손상 줄'                                    = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = 'garbage'; NextOwner = $T11_OWNER_NEXT }
        Expect = ($t11ExitFormat -f '(null)', 1, '', (Get-T11MoveCause 'next-invalid'), $T11_LINES['Done']) }
    'T-RB2 retry · 클리어 기록 locked → legacy 줄 → 옛 나가기'                                                            = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; ClearedTag = 'locked' }
        Expect = ($t11LegacyFormat -f '(null)', 'exitclick return:0/', 'retry/runId=RUN-1', 1, ($T11_LINES['Legacy'] + ' || ' + $T11_LINES['Done'])) }
    'T-RB3 커스텀 retry · 마커 거짓 → 마커 줄 → other'                                                                    = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_A; NextOwner = $T11_OWNER_NEXT; Marker = $false }
        Expect = ($t11OtherFormat -f '(null)', ('retry/' + $T11_OWNER_NEXT_FIELDS), 1, '', $T11_LINES['Marker']) }
    'T-RF retry · 재입장 요청 기록 실패(record-failed) → retry 1 뒤 [경고] → 옛 나가기'                                     = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; RetryEnd = 'record-failed' }
        Expect = ($t11LegacyFormat -f '(null)', 'retry:N-1 exitclick return:0/', 'retry/runId=RUN-1', 1, ($T11_LINES['RecordFailed'] + ' || ' + $T11_LINES['Done'])) }
    'T-IH11 retry · 재입장 완료 11 → exit 11 · 판단값 continue'                                                           = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Until = $T11_UNTIL_TEXT; RetryEnd = '11' }
        Expect = ('exit 11 | until {0} | calls [retry:N-1] | cleared [retry/runId=RUN-1] | marker 0 | dec 1 upd 1 dg 1 read 1 | zero continue/False/False | logs []' -f $T11_UNTIL_TEXT) }
    'T-FB13 커스텀 정리 전용 → 헬퍼 → 복귀 10 · cleanup-only · 기록 0 · 결정 0 · exit 10'                                  = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_A; NextOwner = $T11_OWNER_NEXT; Cleanup = $true }
        Expect = ('exit 10 | until (null) | calls [exitclick return:10/cleanup-only] | cleared [] | marker 0 | dec 0 upd 0 dg 0 read 1 | zero /False/False | logs [{0}]' -f $T11_LINES['Done']) }
    'T-RW 보상 화면 결과(reward) = clear 와 같음'                                                                          = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Outcome = 'reward' }; Expect = $t11RetryRow }
    'T-SEL 증거 없는 결과(selection) → 기록 0 · 결정 0 · 옛 나가기'                                                        = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Outcome = 'selection' }
        Expect = ('exit (end) | until (null) | calls [exitclick return:0/] | cleared [] | marker 0 | dec 0 upd 0 dg 0 read 1 | zero /False/False | logs [{0}]' -f $T11_LINES['Done']) }
    'T-L1 left · 마무리 실행 아님 → 복귀 10 · 준비 실행 줄 · exit 10 (⓪ 값 그대로 - 꼬리 앞에서 끝)'                       = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Outcome = 'left' }
        Expect = ('exit 10 | until (null) | calls [return:10/abandoned-death-exit] | cleared [] | marker 0 | dec 0 upd 0 dg 0 read 1 | zero stale/stale/stale | logs [{0}]' -f ($T11_LINES['LeftPrepFormat'] -f $T11_LINES['LeaveCause'])) }
    'T-L2 left · 마무리 실행 → 복귀 4 · 마무리 줄 · exit 4 (⓪ 값 그대로)'                                                  = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Outcome = 'left'; FinishOnly = $true }
        Expect = ('exit 4 | until (null) | calls [return:4/abandoned-death-exit] | cleared [] | marker 0 | dec 0 upd 0 dg 0 read 1 | zero stale/stale/stale | logs [{0}]' -f ($T11_LINES['LeftFinishFormat'] -f $T11_LINES['LeaveCause'])) }
    # 구현 명세 ⑤b6 3.1 ④ §11 - 끝(retry) 의 클릭 직전 재검사 값 · exit 0순위 · 섞인 리스트의 입장 방식 바뀜(이어 감)
    'T-RS1 retry · 끝(retry) 클릭 직전 재검사 안전 중지(safe-stop 반환) → 옛 나가기 · 본류 결정 줄 0 · 기록 retry'          = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; RetryEnd = 'safe-stop' }
        Expect = ($t11LegacyFormat -f '(null)', 'retry:N-1 exitclick return:0/', 'retry/runId=RUN-1', 1, $T11_LINES['Done']) }
    'T-RS2 retry · T−60 · 끝(retry) 클릭 직전 재검사 지정 시각(last 반환) → 옛 나가기 · 본류 결정 줄 0 · 판단값 continue'   = @{ Spec = @{ Mode = 'solo'; Matching = '우연한 만남'; Until = $T11_UNTIL_TEXT; RetryEnd = 'last' }
        Expect = ('exit (end) | until {0} | calls [retry:N-1 exitclick return:0/] | cleared [retry/runId=RUN-1] | marker 0 | dec 1 upd 1 dg 1 read 1 | zero continue/False/False | logs [{1}]' -f $T11_UNTIL_TEXT, $T11_LINES['Done']) }
    'T-X1 커스텀 마지막 바퀴 끝 + 마커 쓰기 실패 → exit 0순위(마커 줄 0) · 옛 나가기 · 기록 exit · 마지막 판 줄'              = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_A; NextOwner = ''; Boundary = '1'; LastRun = $true; Marker = $false }
        Expect = ($t11ExitFormat -f '(null)', 1, '', (Get-T11ExitCause 'last-run'), $T11_LINES['Done']) }
    'T-MX1 커스텀 혼자하기 + NEXT 우연한 만남(같은 던전 · 난이도) → exit(이어 감) · 기록 exit · 마커 1 · 입장 방식 다름 줄'    = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_P; NextOwner = $T11_OWNER_NEXT_P }
        Expect = ($t11ExitFormat -f '(null)', 1, '', (Get-T11MoveCause 'entry-change'), $T11_LINES['Done']) }
    'T-MX2 커스텀 경계 신호 mixed(랜덤 진행 섞인 바퀴 끝 · NEXT 같은 방식) → exit(이어 감) · 미정 줄'                        = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_B; NextOwner = ''; Boundary = 'mixed' }
        Expect = ($t11ExitFormat -f '(null)', 1, '', (Get-T11MoveCause 'next-unknown'), $T11_LINES['Done']) }
    'T-MX3 커스텀 순차 바퀴 끝(경계 1) + NEXT 다른 입장 방식 → exit(이어 감 - 방식 비교가 경계보다 먼저) · 입장 방식 다름 줄' = @{ Spec = @{ ItemToken = $T11_TOKEN_A; Next = $T11_TOKEN_P; NextOwner = ''; Boundary = '1' }
        Expect = ($t11ExitFormat -f '(null)', 1, '', (Get-T11MoveCause 'entry-change'), $T11_LINES['Done']) }
}
$t11SavedEnv = @{}
foreach ($t11EnvName in @('HONEYNOGI_UNTIL_TIME', 'HONEYNOGI_CUSTOM_NEXT', 'HONEYNOGI_CUSTOM_NEXT_OWNER', 'HONEYNOGI_CUSTOM_NEXT_BOUNDARY')) { $t11SavedEnv[$t11EnvName] = [Environment]::GetEnvironmentVariable($t11EnvName, 'Process') }
if ($null -ne $T11_TAIL_BLOCK) {
    foreach ($t11RowName in $T11_ROWS.Keys) {
        $t11Actual = '(행 예외)'
        try { $t11Actual = Invoke-T11Row -Row $T11_ROWS[$t11RowName].Spec } catch { $t11Actual = '(행 예외) ' + $_.Exception.Message }
        Check-Equal $t11RowName $t11Actual $T11_ROWS[$t11RowName].Expect
    }
}
foreach ($t11EnvName in $t11SavedEnv.Keys) { [Environment]::SetEnvironmentVariable($t11EnvName, $t11SavedEnv[$t11EnvName], 'Process') }
$script:abyssCustomPreparsed = $null; $script:customItem = $null; $script:customNext = $null; $script:customMode = $false; $script:abyssUntil = $null

# ── §11 정적 P5e (구현 명세 ⑤b5 3.2 · ⑤b6 3.2 - 주석 뺀 사본 · AST) ──
# P5e-1 - 본류 꼬리 문장 차례(갈래 없는 문장 단위): ⓪ 셋(꼬리 첫 문장 - 바로 앞 = 클리어 화면 터치 if) → 경로 → 결정 · owner 비움 → if 경로(결정) → 마커 기본 → 마커 if →
#   기록 비움 → 기록 if → if 경로(갈래) → 헬퍼 → 복귀 → [완료] → 정리 전용 exit 10
function Get-T11TailLabel {
    param($Statement)
    $statementCode = Get-NodeCode $Statement
    if ($Statement -is [AssignmentStatementAst]) {
        $rightCode = Get-NodeCode $Statement.Right
        if ((Test-IsVariable $Statement.Left 'script:abyssRetryTimeVerdict') -and ($rightCode -ceq "''")) { return '⓪판단값' }
        if ((Test-IsVariable $Statement.Left 'script:abyssRetryCommitted') -and ($rightCode -ceq '$false')) { return '⓪commit' }
        if ((Test-IsVariable $Statement.Left 'script:abyssRetryAttemptRecorded') -and ($rightCode -ceq '$false')) { return '⓪표식' }
        if (Test-IsVariable $Statement.Left 'retryRoute') { return '경로' }
        if ((Test-IsVariable $Statement.Left 'rewardDecision') -and ($rightCode -ceq '$null')) { return '결정 비움' }
        if ((Test-IsVariable $Statement.Left 'nextOwnerParsed') -and ($rightCode -ceq '$null')) { return 'owner 비움' }
        if ((Test-IsVariable $Statement.Left 'markerOk') -and ($rightCode -ceq '$true')) { return '마커 기본' }
        if ((Test-IsVariable $Statement.Left 'clearedRecord') -and ($rightCode -ceq '$null')) { return '기록 비움' }
    }
    if ($Statement -is [IfStatementAst]) {
        $conditionCode = Get-NodeCode $Statement.Clauses[0].Item1
        if (($conditionCode -ceq '$retryRoute') -and (Test-HasCommand $Statement 'Resolve-AbyssRewardDecision')) { return 'if 경로(결정)' }
        if (($conditionCode -ceq '$retryRoute') -and (Test-HasCommand $Statement 'Resolve-AbyssRewardBranch')) { return 'if 경로(갈래)' }
        if (Test-HasCommand $Statement 'Write-CustomClearMarker') { return '마커 if' }
        if ((Test-HasCommand $Statement 'Add-AbyssJournalClearedEntry') -and $conditionCode.Contains('$clearOutcome')) { return '기록 if' }
        if ($statementCode -ceq 'if ($script:customMode -and $script:customCleanupOnly) { exit 10 }') { return '정리 전용 exit 10' }
    }
    if ($statementCode.StartsWith('[void](Invoke-AbyssExitClick ', [StringComparison]::Ordinal)) { return '헬퍼' }
    if ($statementCode.StartsWith('Return-ToAbyssSelection ', [StringComparison]::Ordinal)) { return '복귀' }
    if ($statementCode -ceq "Write-RunLog '[완료] 어비스 선택 화면 복귀 완료'") { return '[완료]' }
    return ('?' + $statementCode)
}
$t11Labels = @($t11TailStatements | ForEach-Object { Get-T11TailLabel $_ })
$t11BeforeZero = '(없음)'
if ($t11ZeroAt -ge 1) {
    $t11BeforeNode = $t11Body[$t11ZeroAt - 1]
    $t11BeforeZero = $(if ($t11BeforeNode -is [IfStatementAst]) { Get-NodeCode $t11BeforeNode.Clauses[0].Item1 } else { '?' + (Get-NodeCode $t11BeforeNode) })
}
Check-Equal 'P5e-1 본류 꼬리 문장 차례 = ⓪ 셋(꼬리 첫 문장 · 바로 앞 = 클리어 화면 터치 if) → 경로 → 결정 · owner 비움 → if 경로(결정) → 마커 기본 → 마커 if → 기록 비움 → 기록 if → if 경로(갈래) → 헬퍼 → 복귀 → [완료] → 정리 전용 exit 10' `
    ('앞 [{0}] · {1}' -f $t11BeforeZero, ($t11Labels -join ' → ')) `
    ("앞 [`$clearOutcome -eq 'clear'] · ⓪판단값 → ⓪commit → ⓪표식 → 경로 → 결정 비움 → owner 비움 → if 경로(결정) → 마커 기본 → 마커 if → 기록 비움 → 기록 if → if 경로(갈래) → 헬퍼 → 복귀 → [완료] → 정리 전용 exit 10")

# P5e-2 - 경로 대입 원문 · 결정 · owner 해석(본류)은 첫 if ($retryRoute) 안에만 · 재판단(본류)은 결정의 -TimeVerdict 인자 그 자체(R3-M20 · R3-M11 · MW1 · MW13)
$t11RouteAssigns = @($t11TailStatements | Where-Object { ($_ -is [AssignmentStatementAst]) -and (Test-IsVariable $_.Left 'retryRoute') })
$t11RouteCode = $(if ($t11RouteAssigns.Count -eq 1) { Get-NodeCode $t11RouteAssigns[0].Right } else { "(경로 대입 $($t11RouteAssigns.Count)개)" })
$t11FirstRouteIf = @($t11TailStatements | Where-Object { ($_ -is [IfStatementAst]) -and ((Get-T11TailLabel $_) -ceq 'if 경로(결정)') }) | Select-Object -First 1
function Get-T11MainSites {
    # 워커 본류(함수 밖) 그 이름 호출 수 · 그중 첫 if ($retryRoute) 안 수
    param([string]$Name)
    $mainSites = @(Get-CommandNodes -Node $workerAst -Name $Name | Where-Object { (Get-EnclosingFunctionName $_) -eq '' })
    return ('{0}/{1}' -f $mainSites.Count, @($mainSites | Where-Object { Test-AstWithin -Node $_ -Ancestor $t11FirstRouteIf }).Count)
}
$t11UpdateInDecision = @(Get-CommandNodes -Node $workerAst -Name 'Update-AbyssRetryTimeVerdict' | Where-Object { (Get-EnclosingFunctionName $_) -eq '' } | Where-Object {
        $t11UpdateNode = $_
        $t11DecisionCall = $t11UpdateNode.Parent
        while (($null -ne $t11DecisionCall) -and -not ($t11DecisionCall -is [CommandAst])) { $t11DecisionCall = $t11DecisionCall.Parent }
        $t11TimeArgument = $(if (($null -ne $t11DecisionCall) -and ($t11DecisionCall.GetCommandName() -eq 'Resolve-AbyssRewardDecision')) { Get-InnerExpression (Get-CommandArgument -Command $t11DecisionCall -Name 'TimeVerdict' -PositionalNames @()) } else { $null })
        ($t11TimeArgument -is [PipelineAst]) -and ($t11TimeArgument.PipelineElements.Count -eq 1) -and [object]::ReferenceEquals($t11TimeArgument.PipelineElements[0], $t11UpdateNode)
    }).Count
Check-Equal 'P5e-2 경로 대입 원문 · 본류 결정 / owner 해석 / 재판단 = 호출 수/첫 if ($retryRoute) 안 · 재판단 = 결정의 -TimeVerdict 인자 그 자체' `
    ('{0} · 결정 {1} · owner {2} · 재판단 {3} · 인자 {4}' -f $t11RouteCode, (Get-T11MainSites 'Resolve-AbyssRewardDecision'), (Get-T11MainSites 'ConvertTo-AbyssJournalOwner'), (Get-T11MainSites 'Update-AbyssRetryTimeVerdict'), $t11UpdateInDecision) `
    ("(`$clearOutcome -eq 'clear' -or `$clearOutcome -eq 'reward') -and (Test-AbyssRetryRoute -CleanupOnly ([bool](`$script:customMode -and `$script:customCleanupOnly)) -Mode `$dungeonMode -Matching `$abyssMatching) · 결정 1/1 · owner 1/1 · 재판단 1/1 · 인자 1")

# P5e-3 (E06) - 결정 호출 인자 11(구현 명세 ⑤b6 W6 - -NextEntryUnknown 하나 더) · 갈래 3 · 경로 3 이 원문 매개변수 이름 그대로(줄임 0 · 위치 인자 0 · 중복 0) · -TimeVerdict 값 =
#   (Update-AbyssRetryTimeVerdict) (MW11)
function Get-T11ArgumentShape {
    # 본류 호출 1곳의 이름 붙은 인자 목록 대조 → '이름 수/원문 매개변수와 같음/위치 인자 수/중복 수'
    param([string]$Name)
    $mainCalls = @(Get-CommandNodes -Node $workerAst -Name $Name | Where-Object { (Get-EnclosingFunctionName $_) -eq '' })
    if ($mainCalls.Count -ne 1) { return "(본류 호출 $($mainCalls.Count)개)" }
    $callElements = @($mainCalls[0].CommandElements | Select-Object -Skip 1)
    $namedParameters = @($callElements | Where-Object { $_ -is [CommandParameterAst] } | ForEach-Object { $_.ParameterName })
    $positionalCount = 0
    for ($elementIndex = 0; $elementIndex -lt $callElements.Count; $elementIndex++) {
        $element = $callElements[$elementIndex]
        if ($element -is [CommandParameterAst]) { if ($null -eq $element.Argument) { $elementIndex++ }; continue }
        $positionalCount++
    }
    [string[]]$declaredNames = @((Get-WorkerFunction $Name).Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    [string[]]$sortedNamed = @($namedParameters); [Array]::Sort($sortedNamed, [StringComparer]::Ordinal)
    [Array]::Sort($declaredNames, [StringComparer]::Ordinal)
    $duplicateCount = $namedParameters.Count - @($namedParameters | Sort-Object -Unique).Count
    return ('{0}/{1}/{2}/{3}' -f $namedParameters.Count, (($sortedNamed -join ',') -ceq ($declaredNames -join ',')), $positionalCount, $duplicateCount)
}
$t11DecisionCalls = @(Get-CommandNodes -Node $workerAst -Name 'Resolve-AbyssRewardDecision' | Where-Object { (Get-EnclosingFunctionName $_) -eq '' })
$t11TimeValue = $(if ($t11DecisionCalls.Count -eq 1) { Get-NodeCode (Get-CommandArgument -Command $t11DecisionCalls[0] -Name 'TimeVerdict' -PositionalNames @()) } else { '(결정 호출 없음)' })
Check-Equal 'P5e-3 (E06) 본류 결정 · 갈래 · 경로 호출의 이름 붙은 인자 수/원문 매개변수와 같음/위치 인자/중복 · -TimeVerdict 값' `
    ('결정 {0} · 갈래 {1} · 경로 {2} · -TimeVerdict {3}' -f (Get-T11ArgumentShape 'Resolve-AbyssRewardDecision'), (Get-T11ArgumentShape 'Resolve-AbyssRewardBranch'), (Get-T11ArgumentShape 'Test-AbyssRetryRoute'), $t11TimeValue) `
    '결정 11/True/0/0 · 갈래 3/True/0/0 · 경로 3/True/0/0 · -TimeVerdict (Update-AbyssRetryTimeVerdict)'

# P5e-4 (R3 S4) - 지정 시각 읽기 = Get-AbyssUntilTime 호출 워커 전체 1 · 그 호출은 본류 try 직속 if(조건 원문 정확히 $contentCategory -eq 'abyss' · 문장 1) 안 · 차례 = 파티원 디스패치
#   if ($abyssPartyMemberRun) < 읽기 if < 2.1 블록(Consume-Handoff) < if (Clear-EventOverlay -Game $game) (MW3 · R3-M22 · R3-M19 · R3-M10)
function Get-T11BodyIndex {
    # 본류 try 직속 문장 중 조건(스크립트 블록)을 만족하는 첫 문장의 자리 (없으면 -1)
    param([scriptblock]$Match)
    for ($bodyIndex = 0; $bodyIndex -lt $t11Body.Count; $bodyIndex++) { if (& $Match $t11Body[$bodyIndex]) { return $bodyIndex } }
    return -1
}
$t11UntilCalls = @(Get-CommandNodes -Node $workerAst -Name 'Get-AbyssUntilTime')
$t11ReadShape = '(읽기 if 없음)'
if ($t11ReadAt -ge 0) {
    $t11ReadIf = $t11Body[$t11ReadAt]
    $t11ReadShape = '{0} · 절 {1} · 문장 {2} · {3}' -f (Get-NodeCode $t11ReadIf.Clauses[0].Item1), $t11ReadIf.Clauses.Count, @($t11ReadIf.Clauses[0].Item2.Statements).Count, (Get-NodeCode $t11ReadIf.Clauses[0].Item2.Statements[0])
}
$t11MemberAt = Get-T11BodyIndex { param($Statement) ($Statement -is [IfStatementAst]) -and ((Get-NodeCode $Statement.Clauses[0].Item1) -ceq '$abyssPartyMemberRun') }
$t11HandoffAt = Get-T11BodyIndex { param($Statement) ($Statement -is [IfStatementAst]) -and (Test-HasCommand $Statement 'Consume-Handoff') }
$t11OverlayAt = Get-T11BodyIndex { param($Statement) ($Statement -is [IfStatementAst]) -and ((Get-NodeCode $Statement.Clauses[0].Item1) -ceq 'Clear-EventOverlay -Game $game') }
Check-Equal 'P5e-4 (R3 S4) 읽기 호출 워커 전체 수 · 그 호출의 본류 직속 if(조건 · 절 · 문장 · 대입) · 차례 파티원 디스패치 < 읽기 < 2.1 블록 < 이벤트 정리' `
    ('호출 {0} · {1} · 차례 {2}' -f $t11UntilCalls.Count, $t11ReadShape, (($t11MemberAt -ge 0) -and ($t11MemberAt -lt $t11ReadAt) -and ($t11ReadAt -lt $t11HandoffAt) -and ($t11HandoffAt -lt $t11OverlayAt))) `
    ("호출 1 · `$contentCategory -eq 'abyss' · 절 1 · 문장 1 · `$script:abyssUntil = Get-AbyssUntilTime · 차례 True")

# P5e-5 - 기록의 nextOwner 갈래: 기록 if 안 $nextOwnerValue 대입 = 기본 $null(기록 if 직속) · 커스텀 $nextOwnerParsed.Owner · 비커스텀 [pscustomobject]@{ runId = [string]$script:abyssRunId }
#   (구현 명세 ⑤b5 1.2 글자 그대로) - 뒤 둘은 if ($clearedDecision -eq 'retry') 안이고 그 if 는 if ($retryRoute) 안 (MW14)
function Get-T11ClauseChain {
    # 노드를 감싼 if 갈래들(안쪽부터) - 그 노드를 품은 절의 조건 원문(공백 정규화) · else 절이면 'else' · -Stop 노드에 닿으면(그 노드는 빼고) 멈춤 (열거용 - 호출부에서 @())
    param($Node, $Stop = $null)
    $chain = @()
    for ($parentNode = $Node.Parent; ($null -ne $parentNode) -and (-not [object]::ReferenceEquals($parentNode, $Stop)); $parentNode = $parentNode.Parent) {
        if (-not ($parentNode -is [IfStatementAst])) { continue }
        $clauseText = $null
        foreach ($clause in $parentNode.Clauses) {
            if (($clause.Item2.Extent.StartOffset -le $Node.Extent.StartOffset) -and ($clause.Item2.Extent.EndOffset -ge $Node.Extent.EndOffset)) { $clauseText = Get-NodeCode $clause.Item1 }
        }
        if (($null -eq $clauseText) -and ($null -ne $parentNode.ElseClause) -and ($parentNode.ElseClause.Extent.StartOffset -le $Node.Extent.StartOffset) -and ($parentNode.ElseClause.Extent.EndOffset -ge $Node.Extent.EndOffset)) { $clauseText = 'else' }
        if ($null -ne $clauseText) { $chain += $clauseText }
    }
    return $chain
}
$t11RecordIf = @($t11TailStatements | Where-Object { (Get-T11TailLabel $_) -ceq '기록 if' }) | Select-Object -First 1
$t11OwnerShapes = @()
if ($null -ne $t11RecordIf) {
    $t11OwnerShapes = @($t11RecordIf.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and (Test-IsVariable $candidate.Left 'nextOwnerValue') }, $true) | ForEach-Object {
            '{0} @ [{1}]' -f (Get-NodeCode $_.Right), ((@(Get-T11ClauseChain -Node $_ -Stop $t11RecordIf)) -join ' < ')
        })
}
Check-Equal 'P5e-5 기록 if 안 $nextOwnerValue 대입(값 @ 감싼 갈래 - 안쪽부터, 기록 if 자신은 뺌) = 기본 $null · 커스텀 5필드 · 비커스텀 runId (retry 일 때만)' ($t11OwnerShapes -join ' || ') `
    ('$null @ [] || $nextOwnerParsed.Owner @ [$script:customMode < $clearedDecision -eq ''retry'' < $retryRoute] || [pscustomobject]@{ runId = [string]$script:abyssRunId } @ [else < $clearedDecision -eq ''retry'' < $retryRoute]')

# P5e-6 - GUI Get-CustomNextHandoffEnv 순수(P5b-1 꼴의 요점 - 명령 = 직렬화 · owner 두 함수 + 바퀴 끝 입장 방식 키의 토큰 직렬화 · 중복 제거(구현 명세 ⑤b6 G10 'mixed') · 대입 = 접두 없는
#   지역 · 접두 변수 0 · exit·throw·try 0) · Start-NextCycle 안 호출 1(-Context $customContext) · NEXT env 대입 둘(Start-NextCycle 안 각 1 · GUI 전체 각 1) · Clear-CustomEnv 목록 둘
#   (생산 경로 빠짐 - GUI 변이 셋)
$t11GuiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$t11GuiTokens = $null; $t11GuiErrors = $null
$t11GuiAst = [Parser]::ParseFile($t11GuiPath, [ref]$t11GuiTokens, [ref]$t11GuiErrors)
$t11GuiFunctions = @{}
foreach ($t11GuiTop in $t11GuiAst.EndBlock.Statements) { if ($t11GuiTop -is [FunctionDefinitionAst]) { $t11GuiFunctions[$t11GuiTop.Name] = $t11GuiTop } }
$t11Pure = '(함수 없음)'
if ($t11GuiFunctions.ContainsKey('Get-CustomNextHandoffEnv')) {
    $t11PureNode = $t11GuiFunctions['Get-CustomNextHandoffEnv']
    $t11PureCommands = @($t11PureNode.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() } | Sort-Object -Unique) -join ','
    $t11PureQualified = @($t11PureNode.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and (-not $candidate.VariablePath.IsUnqualified) }, $true)).Count
    $t11PureAssigns = @($t11PureNode.FindAll({ param($candidate) $candidate -is [AssignmentStatementAst] }, $true) | ForEach-Object {
            if (($_.Left -is [VariableExpressionAst]) -and $_.Left.VariablePath.IsUnqualified) { '$' + $_.Left.VariablePath.UserPath } else { 'X:' + $_.Left.Extent.Text } } | Sort-Object -Unique) -join ','
    $t11PureExits = @($t11PureNode.FindAll({ param($candidate) ($candidate -is [ExitStatementAst]) -or ($candidate -is [ThrowStatementAst]) -or ($candidate -is [TryStatementAst]) }, $true)).Count
    $t11Pure = '명령 [{0}] · 접두 변수 {1} · 대입 [{2}] · exit·throw·try {3}' -f $t11PureCommands, $t11PureQualified, $t11PureAssigns, $t11PureExits
}
$t11NextCycle = $t11GuiFunctions['Start-NextCycle']
$t11NextCalls = $(if ($null -ne $t11NextCycle) { @($t11NextCycle.FindAll({ param($candidate) ($candidate -is [CommandAst]) -and ($candidate.GetCommandName() -eq 'Get-CustomNextHandoffEnv') }, $true) | ForEach-Object { ($_.Extent.Text -replace '\s+', ' ').Trim() }) -join ' | ' } else { '(Start-NextCycle 없음)' })
$t11EnvAssigns = @(foreach ($t11EnvTarget in @('HONEYNOGI_CUSTOM_NEXT_OWNER', 'HONEYNOGI_CUSTOM_NEXT_BOUNDARY')) {
        $t11EnvNodes = @($t11GuiAst.FindAll({ param($candidate) ($candidate -is [AssignmentStatementAst]) -and ($candidate.Left.Extent.Text -eq ('$env:' + $t11EnvTarget)) }, $true))
        '{0} {1}/{2}' -f $t11EnvTarget, $t11EnvNodes.Count, @($t11EnvNodes | Where-Object { ($null -ne $t11NextCycle) -and (Test-AstWithin -Node $_ -Ancestor $t11NextCycle) }).Count
    }) -join ' · '
$t11ClearList = '(Clear-CustomEnv 없음)'
if ($t11GuiFunctions.ContainsKey('Clear-CustomEnv')) {
    $t11ClearStrings = @($t11GuiFunctions['Clear-CustomEnv'].FindAll({ param($candidate) $candidate -is [StringConstantExpressionAst] }, $true) | ForEach-Object { [string]$_.Value })
    $t11ClearList = '{0}/{1}' -f [int]($t11ClearStrings -ccontains 'HONEYNOGI_CUSTOM_NEXT_OWNER'), [int]($t11ClearStrings -ccontains 'HONEYNOGI_CUSTOM_NEXT_BOUNDARY')
}
Check-Equal 'P5e-6 GUI 다음 판 env 순수 함수 · Start-NextCycle 호출 · NEXT env 대입(GUI 전체/Start-NextCycle 안) · Clear-CustomEnv 목록(NEXT_OWNER/NEXT_BOUNDARY)' `
    ('{0} || 호출 [{1}] || {2} || 지움 {3}' -f $t11Pure, $t11NextCalls, $t11EnvAssigns, $t11ClearList) `
    ('명령 [ConvertTo-CustomMarkerOwnerJson,Format-CustomItemToken,Get-CustomCanonicalOwner,Select-Object] · 접두 변수 0 · 대입 [$entryKindCount,$entryKindList,$entryParts,$nextContext,$nextIndex] · ' +
        'exit·throw·try 0 || 호출 [Get-CustomNextHandoffEnv -Context $customContext] || ' +
        'HONEYNOGI_CUSTOM_NEXT_OWNER 1/1 · HONEYNOGI_CUSTOM_NEXT_BOUNDARY 1/1 || 지움 1/1')

# P5e-7 (R3 S8 ①) - 시간 줄 ①(설계 v11 R3 3.7 ① 원문에서 끝 동작 자리만 구현 명세 ⑤b6 1.5 문안('나가기'로 던전 밖에 나와 마칩니다 - 부록 C C-7)으로 바꾼 글자 · HH:mm 자리 =
#   $($script:abyssUntil.ToString('HH:mm'))) 워커 전체 1 · 자리 = if ($retryRoute) → elseif ($rewardBranch -eq 'exit') → if ($rewardDecision.Reason -eq 'time') 갈래 안(안쪽 갈래가 시간 사유
#   조건 그 자체 - ④:5379~5399 의 ②③ 과 짝 · MW12 · MW16)
$R3_LINE_ONE = "[어비스] 지정 시간 HH:mm 도달 - 이번 판을 마지막으로 '나가기'로 던전 밖에 나와 마칩니다"   # 설계 v11 R3 3.7 ① 원문 · 끝 동작 자리 = 구현 명세 ⑤b6 1.5
$t11LineOneWant = $R3_LINE_ONE.Replace('HH:mm', '$($script:abyssUntil.ToString(''HH:mm''))')
$t11LineOneNodes = @($workerAst.FindAll({ param($candidate) ($candidate -is [ExpandableStringExpressionAst]) -and ([string]$candidate.Value).StartsWith('[어비스] 지정 시간 ', [StringComparison]::Ordinal) -and ([string]$candidate.Value).Contains('이번 판을 마지막으로') }, $true))
$t11LineOneShapes = @(foreach ($t11LineNode in $t11LineOneNodes) {
        '{0} @ [{1}]' -f [int]([string]$t11LineNode.Value -ceq $t11LineOneWant), ((@(Get-T11ClauseChain -Node $t11LineNode)) -join ' < ')
    })
Check-Equal 'P5e-7 (R3 S8 ①) 시간 줄 ① 워커 전체 수 · 원문 같음 @ 감싼 갈래 조건(안쪽부터 - 시간 사유 < exit 갈래 < 경로 if)' ('{0} · {1}' -f $t11LineOneNodes.Count, ($t11LineOneShapes -join ' || ')) `
    ("1 · 1 @ [`$rewardDecision.Reason -eq 'time' < `$rewardBranch -eq 'exit' < `$retryRoute]")

# P5e-8 (구현 명세 ⑤b6 3.2 · 1.5) - 결정 줄 원인 조각 switch 셋의 키(대입 대상 이름으로 고름 - 워커 전체에 하나씩): 'other' 갈래 $otherCause = 같은 입장 방식으로 '다른 던전 가기' 하는 사유만 ·
#   'exit' 갈래의 멈춤 $exitCause · 이어 감 $moveCause (other 에 멈춤 · 이어 감 사유가 남거나 exit 쪽 키가 빠지면 결정 줄 원인이 빈칸)
function Get-T11CauseKeys {
    param([string]$Target)
    $causeSwitches = @($workerAst.FindAll({ param($candidate) ($candidate -is [SwitchStatementAst]) -and ((Get-NodeCode $candidate.Condition) -ceq '[string]$rewardDecision.Reason') -and
                ($candidate.Parent -is [AssignmentStatementAst]) -and ($candidate.Parent.Left.Extent.Text -ceq $Target) }, $true))
    if ($causeSwitches.Count -ne 1) { return "(switch $($causeSwitches.Count)개)" }
    return ((@($causeSwitches[0].Clauses | ForEach-Object { [string]$_.Item1.Value })) -join ',')
}
Check-Equal 'P5e-8 결정 줄 원인 조각 키 - $otherCause(다른 던전 가기) · $exitCause(멈춤) · $moveCause(이어 감)' `
    ('{0} · {1} · {2}' -f (Get-T11CauseKeys '$otherCause'), (Get-T11CauseKeys '$exitCause'), (Get-T11CauseKeys '$moveCause')) `
    'boundary,item-change,next-owner-empty · safe-stop,finish-only,last-run · next-invalid,next-unknown,entry-change'

# P5e-9 (구현 명세 ⑤b6 3.2 · 1.5) - 어비스 결정 줄 끝말(명세 1.5 의 A급 문구 - 행(T-)은 줄 글자를 소스에서 캡처하므로 끝말을 바꾼 워커는 이 정적이 잡습니다):
#   '나가기'로 던전 밖에 나와 마칩니다 = 5(시간 1 · 멈춤 원인 1 · 직전 판단 2 · 재개 판단 1 - ⑤c 5c-3) · '나가기'로 던전 밖에 나와 다음 항목으로 넘어갑니다 = 1(이어 감 원인 ${moveCause}) · 'exit' 갈래 1 · 그 안
#   if ($moveCause) 1(참 갈래 = 이어 감 줄 · else = 멈춤 원인 줄) · 어비스 줄의 '나가기'로 필드에 나와 마칩니다 0 · 던전 14-T 시간 줄의 '필드에 나와' 1(그대로) · '다른 던전 가기' 가 든 직전 판단 줄 0
$T11_END_STOP = "'나가기'로 던전 밖에 나와 마칩니다"
$T11_END_MOVE = "'나가기'로 던전 밖에 나와 다음 항목으로 넘어갑니다"
$T11_END_FIELD = "'나가기'로 필드에 나와 마칩니다"
$t11WorkerStrings = @($workerAst.FindAll({ param($candidate) ($candidate -is [StringConstantExpressionAst]) -or ($candidate -is [ExpandableStringExpressionAst]) }, $true))
$t11AbyssStrings = @($t11WorkerStrings | Where-Object { ([string]$_.Value).StartsWith('[어비스]', [StringComparison]::Ordinal) })
$t11StopLines = @($t11AbyssStrings | Where-Object { ([string]$_.Value).EndsWith($T11_END_STOP, [StringComparison]::Ordinal) })
$t11StopTime = @($t11StopLines | Where-Object { ([string]$_.Value).StartsWith('[어비스] 지정 시간 ', [StringComparison]::Ordinal) }).Count
$t11StopCauseLines = @($t11StopLines | Where-Object { ([string]$_.Value).StartsWith('[어비스] ${exitCause} ', [StringComparison]::Ordinal) })
$t11StopJudge = @($t11StopLines | Where-Object { ([string]$_.Value).StartsWith("[어비스] '다시 하기' 직전 판단: ", [StringComparison]::Ordinal) }).Count
$t11StopResume = @($t11StopLines | Where-Object { ([string]$_.Value).StartsWith('[어비스] 재개 판단: ', [StringComparison]::Ordinal) }).Count   # 재개 끝 재평가의 멈춤 줄(⑤c 5c-3)
$t11MoveLines = @($t11AbyssStrings | Where-Object { ([string]$_.Value).EndsWith($T11_END_MOVE, [StringComparison]::Ordinal) })
$t11MoveCauseLines = @($t11MoveLines | Where-Object { ([string]$_.Value).StartsWith('[어비스] ${moveCause} ', [StringComparison]::Ordinal) })
$t11FieldAbyss = @($t11AbyssStrings | Where-Object { ([string]$_.Value).Contains($T11_END_FIELD) }).Count
$t11FieldDungeon = @($t11WorkerStrings | Where-Object { ([string]$_.Value).StartsWith('$($script:contentTag) 지정 시간 ', [StringComparison]::Ordinal) -and ([string]$_.Value).Contains($T11_END_FIELD) }).Count
$t11JudgeOther = @($t11AbyssStrings | Where-Object { ([string]$_.Value).StartsWith("[어비스] '다시 하기' 직전 판단: ", [StringComparison]::Ordinal) -and ([string]$_.Value).Contains("'다른 던전 가기'") }).Count
# 'exit' 갈래 = 워커 안 if · elseif 절 중 조건이 $rewardBranch -eq 'exit' 인 절의 몸통 · 그 안 if ($moveCause) 의 참 갈래 · else 에 든 줄
$t11ExitBodies = @($workerAst.FindAll({ param($candidate) $candidate -is [IfStatementAst] }, $true) | ForEach-Object {
        foreach ($t11IfClause in $_.Clauses) { if ($t11IfClause.Item1.Extent.Text.Contains('$rewardBranch') -and ((Get-NodeCode $t11IfClause.Item1) -ceq "`$rewardBranch -eq 'exit'")) { $t11IfClause.Item2 } }
    })
$t11MoveIfShape = '(exit 갈래 1개가 아님)'
if ($t11ExitBodies.Count -eq 1) {
    $t11MoveIfs = @($t11ExitBodies[0].FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and ((Get-NodeCode $candidate.Clauses[0].Item1) -ceq '$moveCause') }, $true))
    $t11MoveIfShape = 'if ($moveCause) {0}' -f $t11MoveIfs.Count
    if ($t11MoveIfs.Count -eq 1) {
        $t11MoveInThen = @($t11MoveCauseLines | Where-Object { Test-AstWithin -Node $_ -Ancestor $t11MoveIfs[0].Clauses[0].Item2 }).Count
        $t11StopInElse = $(if ($null -ne $t11MoveIfs[0].ElseClause) { @($t11StopCauseLines | Where-Object { Test-AstWithin -Node $_ -Ancestor $t11MoveIfs[0].ElseClause }).Count } else { 0 })
        $t11MoveIfShape += (' · 참 갈래 이어 감 줄 {0} · else 멈춤 원인 줄 {1}' -f $t11MoveInThen, $t11StopInElse)
    }
}
Check-Equal "P5e-9 어비스 결정 줄 끝말 - 마칩니다(시간 · 멈춤 원인 · 직전 판단 · 재개 판단) · 넘어갑니다(이어 감 원인) · exit 갈래 · 그 안 if (`$moveCause) · 어비스 '필드에 나와' 0 · 던전 14-T '필드에 나와' 1 · 직전 판단 '다른 던전 가기' 0" `
    ('마칩니다 {0}(시간 {1} · 멈춤 원인 {2} · 직전 판단 {3} · 재개 판단 {11}) · 넘어갑니다 {4}(이어 감 원인 {5}) · exit 갈래 {6} · {7} · 어비스 필드에 나와 {8} · 던전 14-T 필드에 나와 {9} · 직전 판단 다른 던전 가기 {10}' -f
        $t11StopLines.Count, $t11StopTime, $t11StopCauseLines.Count, $t11StopJudge, $t11MoveLines.Count, $t11MoveCauseLines.Count, $t11ExitBodies.Count, $t11MoveIfShape, $t11FieldAbyss, $t11FieldDungeon, $t11JudgeOther, $t11StopResume) `
    '마칩니다 5(시간 1 · 멈춤 원인 1 · 직전 판단 2 · 재개 판단 1) · 넘어갑니다 1(이어 감 원인 1) · exit 갈래 1 · if ($moveCause) 1 · 참 갈래 이어 감 줄 1 · else 멈춤 원인 줄 1 · 어비스 필드에 나와 0 · 던전 14-T 필드에 나와 1 · 직전 판단 다른 던전 가기 0'

# P5e-10 (CT · 구현 명세 ⑤b6 3.2 · 1.10) - GUI ↔ 워커 경계 신호 계약: GUI Get-CustomNextHandoffEnv 안 입장 방식 미정 글자(문자열 상수 'mixed') 1 · 워커의 -NextEntryUnknown 인자 1(워커 전체) ·
#   그 인자 = [string]$env:HONEYNOGI_CUSTOM_NEXT_BOUNDARY -eq '<GUI 글자>' (두 글자를 양쪽 소스에서 캡처해 대조 - 한쪽만 바꾸면 미정 신호가 끊겨 섞인 바퀴 끝이 '다른 던전 가기' 로 감)
$t11MixedConsts = $(if ($t11GuiFunctions.ContainsKey('Get-CustomNextHandoffEnv')) { @($t11GuiFunctions['Get-CustomNextHandoffEnv'].FindAll({ param($candidate) ($candidate -is [StringConstantExpressionAst]) -and ($candidate.Value -ceq 'mixed') }, $true)) } else { @() })
$t11UnknownParams = @($workerAst.FindAll({ param($candidate) ($candidate -is [CommandParameterAst]) -and ($candidate.ParameterName -eq 'NextEntryUnknown') }, $true))
$t11UnknownShape = '(본류 결정 호출 1개 · GUI 글자 1개가 아님)'
if (($t11DecisionCalls.Count -eq 1) -and (@($t11MixedConsts).Count -eq 1)) {
    $t11UnknownValue = Get-InnerExpression (Get-CommandArgument -Command $t11DecisionCalls[0] -Name 'NextEntryUnknown' -PositionalNames @())
    $t11UnknownRight = $(if ($t11UnknownValue -is [BinaryExpressionAst]) { Get-InnerExpression $t11UnknownValue.Right } else { $null })
    $t11UnknownShape = '{0}' -f (($t11UnknownValue -is [BinaryExpressionAst]) -and ([string]$t11UnknownValue.Operator -eq 'Ieq') -and ((Get-NodeCode $t11UnknownValue.Left) -ceq '[string]$env:HONEYNOGI_CUSTOM_NEXT_BOUNDARY') -and
        ($t11UnknownRight -is [StringConstantExpressionAst]) -and ([string]$t11UnknownRight.Value -ceq [string]@($t11MixedConsts)[0].Value))
}
Check-Equal "P5e-10 (CT) GUI 경계 함수의 미정 글자 1 · 워커 -NextEntryUnknown 인자 1 · 그 인자 = [string]`$env:HONEYNOGI_CUSTOM_NEXT_BOUNDARY -eq '<GUI 글자>'" `
    ('GUI {0} · 워커 {1} · 같은 글자 {2}' -f @($t11MixedConsts).Count, $t11UnknownParams.Count, $t11UnknownShape) 'GUI 1 · 워커 1 · 같은 글자 True'

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
