# 어비스 재입장 대기 회귀 - 결론 순수 판정 진리표 · 대기 루프 행동 진리표 · 정적 배선 (구현 단위 ④ - 2026-10)
#
# 배경(설계 v11 R5 대기 루프 골격 · 구현 명세 ④): 어비스 재입장 대기를 워커에 넣는 단위입니다 - 스크립트 상수 $abyssReclickQuietSeconds(무변화 창 Q -
#   config 아님) · 결론 순수 판정 Resolve-AbyssReentryVerdict · 대기 함수 Wait-AbyssReentry(결과 @{ Result; LastKind; PanelSeen } 하나). 워커 안 호출은 0 이고
#   (첫 호출자는 구현 단위 ⑤ - 선분기 B2 단계 교체 · 원 워커 B2 · resume · 폴백 ②) 동작 변화도 0 입니다. 파일 이름은 설계 v10 의 계획 그대로입니다 - 파티장
#   쪽 재입장·보상 귀환 대기의 회귀를 이 파일이 모읍니다(설계 v11 R5 8절).
# 여기서 고정하는 계약(구현 명세 ④ 1.5·1.6·1.9·1.11):
#   회전 순서 - 서두(클릭 생략 메타 비움) → ① 동결(여러 줄 · 단독 줄 continue: 안전 확인 → 2초 → 이번 회전 탐침 → 탐침 표식) → ② 조작 양보 → ③ 탐침
#     복구 뒤 회전(스윕·판독 없이 마감만) → try { ④ 팝업 스윕(참이면 생략 사유 분류) → ⑤ 판독(하단 → 패널 → HUD → 추적기) } catch(창 좌표 throw 만) →
#     ⑥ 간접 양보 → ⑦ 유효성 → ⑧ 분류·던전 안 연속·패널 관측·계측 → 무변화 판정 → ⑨ 결론(같은 회전의 마감보다 먼저) → ⑩ 마감(파티원 시계 - 양보·캡처
#     실패 차분) → ⑫ 대기(굶김 0 · 복구 2초 · 그 밖 700ms). ⑪(클릭)은 없습니다(구현 단위 ⑥d 자리). 조작 생략·아직 캡처 실패 중인 회전은 마감을 확정하지
#     않습니다(규칙 4·15)
#   결론 우선순위(위가 이김) - 던전 안 2연속 'entered' > 목표 field ∧ 필드 모양 ∧ 필드 확정 'field' > 목표 reward ∧ 3버튼 'reward' > 목표 entry ∧ 보고 ∧
#     3버튼 ∧ 패널 관측 'cancelled' > 같은 꼴 ∧ 무변화 만료 'reclick' > ''(관측 지속). waiter 는 목표 'entry' · 필드 확정 거짓을 넘깁니다
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
#     fail-true·yield-false·yield-sent·rect-throw·yield-rect-throw·rect-click-throw·click-throw-noreg·교대·실제)
#   - 판독 스텁은 화면 함수 층에서 시각표의 지금 화면으로 답합니다. 하단 판독문은 기존 회귀 파일의 실측 문자열 글자 그대로이고(아래 $SCREEN_TABLE 주석의
#     출처), 패널·프롬프트·추적기 판정값은 실측 문자열에서 원문 판정으로 선단언합니다. HUD 영역 실측 문자열은 tests\ 에 없어 판정값만 씁니다
#   - 기대값은 원문 루프가 낸 결과·시각·호출 수입니다. 시각·회전은 판독 회전 기록·사건 기록에서 계산하고(명세 3.2.8) 숫자를 다시 박지 않습니다(L 은 행
#     픽스처 · Q·W·스윕 한도·대기 값은 소스 캡처 · 회전 박자는 사건 기록의 Start-Sleep 길이)
# 행 계열: WA-P(결론 순수 판정 · 설계 v11 R5 8절 이름) + N4-L4 · WA-L(대기 루프 · 설계 이름 - 이 단위 몫 41행 + WA-L14′·WA-L17′ + 구현 리뷰의 WA-L14″) · N4-L(구현 명세 ④ 가 더한
#   대기 행) · R5-P(정적 · 설계 이름 - 이 단위 몫 P1~P8·P12·P14·P16) · N4-P(정적 · 명세가 더한 것 - P1~P10·P12~P14, P11 은 결번)
# 보관 캡처·OCR 엔진 없이 늘 돌아 SKIP 경로가 없습니다.
# 뒤 단위가 이 파일에 더할 자리(설계 v11 R5 8절 · 구현 명세 ④ 2.2-1):
#   ⑤ - WA-X3~X5·X12 · WA-S(S10 포함 - S10 에 클릭 경로 문구 변형 셋 · 두 번째 판독 실패 변형(④′ 뒤 공용 스윕 행)) · 정적 R5-P1·P2·P12·P16 의 두 클릭
#       루프 몫 · R5-P13 · 변이 R5-M36~M39 와 R5-M46·M47 의 두 클릭 루프 꼴 · N4-M4·M30·M31·M37 의 두 클릭 루프 꼴. 배선 때 N4-P2(호출 0 → 호출 자리 수) ·
#       R5-P5 '선분기 S2 0' · N4-P9·N4-P14 의 S2 대조 대상(선분기 S2 를 지우면 고정 조각·접두로)을 함께 갱신합니다
#   ⑥d - WA-C(C7 포함) · WA-L31·L40·L42(목표 'field'·'reward' 행) · WA-E · WA-R(E5·R5 에 클릭 경로 문구 변형 셋 · 두 번째 판독 실패 변형) · WA-X14~X18 ·
#       정적 R5-P15·P17 · R5-P1·P2·P12·P16 의 ⑥d 두 클릭 루프 몫 · R5-P13(입장하기·준비 취소 몫) · R5-P4·P8·R5-P16·N4-P4·N4-P12 갱신 ·
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
    'Invoke-UserYieldWithDeadline', 'Register-CaptureSuccess', 'Get-CaptureFailTotalMs', 'Test-AbyssReadyPanelText', 'Test-AbyssMatchingPanelText')
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
foreach ($targetName in @('Wait-AbyssReentry', 'Resolve-AbyssReentryVerdict')) {
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
}
$SCREEN_KINDS = [ordered]@{ 'I' = 'inside'; 'F' = 'field'; 'U' = 'unknown'; 'R' = 'reward3'; 'M' = 'matching'; 'Rd' = 'ready'; 'E' = 'entry-waiting'; 'P' = 'popup'; 'S' = 'prompt' }
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
    param([double]$Seconds)
    $script:vclock = $script:vclock.AddTicks((ConvertTo-Ticks $Seconds))
    if ((Get-VirtualElapsed) -gt $VIRTUAL_LIMIT_SECONDS) { throw '__VTIMEOUT__' }
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
# ① 아홉 약어 각각 원문 분류기가 대응표의 분류를 냄
$classifyActual = @(foreach ($screenKey in $SCREEN_TABLE.Keys) {
        $screenEntry = $SCREEN_TABLE[$screenKey]
        '{0}={1}' -f $screenKey, (Resolve-AbyssHandoffStartScreen -PromptVisible $screenEntry.Prompt -BottomText $screenEntry.Bottom -PanelKind $screenEntry.Panel -HudVisible $screenEntry.Hud -InDungeonQuest $screenEntry.Quest)
    }) -join ' '
$classifyExpected = @(foreach ($screenKey in $SCREEN_KINDS.Keys) { '{0}={1}' -f $screenKey, $SCREEN_KINDS[$screenKey] }) -join ' '
Check-Equal '선단언 ① 아홉 약어의 원문 분류 (Resolve-AbyssHandoffStartScreen - 판정값·실측 하단 판독문)' $classifyActual $classifyExpected
# ② 패널 - 원문 패널 종류 판정(서명 둘을 지남)이 실측 패널 판독문에 M 'matching' · Rd 'ready'
$panelRegionKey = '{0},{1}' -f $rgAbyssMenu[0], $rgAbyssMenu[1]
$script:preRegionTexts = @{ $panelRegionKey = $PANEL_TEXT_MATCHING }
$panelMatchingActual = Invoke-RealGetAbyssPanelKind -Game $null
$script:preRegionTexts = @{ $panelRegionKey = $PANEL_TEXT_READY }
$panelReadyActual = Invoke-RealGetAbyssPanelKind -Game $null
Check-Equal '선단언 ② 패널 - 원문 Get-AbyssPanelKind: 09-18 재매칭 판독문 → M 의 판정값 · 실기 -1 L1 준비 패널 판독문 → Rd 의 판정값' "M=$panelMatchingActual Rd=$panelReadyActual" ('M={0} Rd={1}' -f $SCREEN_TABLE['M'].Panel, $SCREEN_TABLE['Rd'].Panel)
# ③ 프롬프트 - 원문 하단 판정이 아홉 하단 판독문 중 S 만 참 (점수 영역 판독은 '')
$promptActual = @(foreach ($screenKey in $SCREEN_TABLE.Keys) {
        $script:preBottomText = [string]$SCREEN_TABLE[$screenKey].Bottom
        $script:preRegionTexts = @{}
        '{0}={1}' -f $screenKey, [int][bool](Invoke-RealTestDungeonClearPrompt -Game $null)
    }) -join ' '
$promptExpected = @(foreach ($screenKey in $SCREEN_TABLE.Keys) { '{0}={1}' -f $screenKey, [int][bool]$SCREEN_TABLE[$screenKey].Prompt }) -join ' '
Check-Equal '선단언 ③ 프롬프트 - 원문 Test-DungeonClearPrompt: 아홉 하단 판독문 중 S 만 참 (대응표 판정값과 같음)' $promptActual $promptExpected
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

# ── §6 WA-P · N4-L4 - 결론 우선순위 순수 진리표 (명세 3.3 - 비교는 -ceq) ─────────────────────────────────────────────────────
$VERDICT_ROWS = @(
    @('WA-P1', 'inside', 2, $false, 'entry', $false, $false, $false, 'entered'),
    @('WA-P2', 'inside', 1, $false, 'entry', $true, $true, $false, ''),
    @('WA-P3', 'reward3', 0, $true, 'entry', $true, $false, $false, 'cancelled'),
    @('WA-P4', 'reward3', 0, $false, 'entry', $true, $true, $false, 'reclick'),
    @('WA-P5', 'reward3', 0, $false, 'entry', $true, $false, $false, ''),
    @('WA-P6', 'reward3', 0, $true, 'entry', $false, $true, $false, ''),
    @('WA-P7', 'reward3', 0, $true, 'entry', $true, $true, $false, 'cancelled'),
    @('WA-P8', 'unknown', 0, $false, 'entry', $true, $true, $false, ''),
    @('WA-P9', 'matching', 0, $true, 'entry', $true, $true, $false, ''),
    @('WA-P10', 'field', 0, $false, 'entry', $true, $true, $true, ''),
    @('WA-P11', 'reward3', 0, $false, 'reward', $false, $false, $false, 'reward'),
    @('WA-P12', 'field', 0, $false, 'field', $false, $false, $true, 'field'),
    @('WA-P13', 'inside', 2, $true, 'reward', $false, $false, $false, 'entered'),
    @('WA-P14', 'reward3', 0, $true, 'field', $false, $false, $false, ''),
    @('N4-L4', 'reward3', 0, $true, 'field', $true, $true, $false, ''))   # 필드 목표는 보고 켬이어도 3버튼 결론 없음 - 순위 4·5 의 목표 항
foreach ($verdictRow in $VERDICT_ROWS) {
    $verdictActual = ''
    try {
        $verdictActual = [string](Resolve-AbyssReentryVerdict -Kind $verdictRow[1] -InsideStreak $verdictRow[2] -PanelSeen $verdictRow[3] -Target $verdictRow[4] `
                -ReportRewardReturn $verdictRow[5] -QuietExpired $verdictRow[6] -FieldSettled $verdictRow[7])
    } catch {
        $verdictActual = 'THREW: ' + $_.Exception.Message
    }
    Check-Equal ("{0} 분류 {1} · 던전 안 연속 {2} · 패널 관측 {3} · 목표 {4} · 보고 {5} · 무변화 만료 {6} · 필드 확정 {7} → '{8}'" -f $verdictRow) "[$verdictActual]" "[$($verdictRow[8])]"
}

# ── §7 WA-L · N4-L - 대기 루프 행동 진리표 (명세 3.4 - 픽스처 공통: L = 30(행이 적은 값 우선) · Q·W·한도는 캡처값 · 시각표 'X@a' · 실패·조작 창 [a, b)) ──────────
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

# ── §8 정적 (명세 3.5 - 주석 제거 사본 · AST · 뜻 판정. R5-P14 다섯 식 · R5-P2 Resume 인자 · N4-P10 생성 두 문장 · R5-P7 우변 '0' 은 구현 형상 계약 -
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
    # ⑩ 의 resume 유예 갈래 - if ($ResumeGrace) 하나와 그 본문의 다섯 절 if (없으면 $null 들)
    $graceIfs = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (Test-IsVariable $candidate.Clauses[0].Item1 'ResumeGrace') }, $true))
    $graceIf = $(if ($graceIfs.Count -eq 1) { $graceIfs[0] } else { $null })
    $chainIf = $null
    if ($null -ne $graceIf) {
        $chainIfs = @($graceIf.Clauses[0].Item2.Statements | Where-Object { $_ -is [IfStatementAst] })
        if ($chainIfs.Count -eq 1) { $chainIf = $chainIfs[0] }
    }
    return [pscustomobject]@{ GraceIfCount = $graceIfs.Count; GraceIf = $graceIf; Chain = $chainIf }
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
#   while 안 Resume 2 = 첫 유예 갈래($insideGraceRun = $insideRun 다음 · $graceHold = $true 앞) · 되돌림 뒤 창 갈래 첫 문장(그다음 $graceHold = $true) · 인자 글자
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
$resumeSites = @()
if (($null -ne $graceChain.Chain) -and ($graceChain.Chain.Clauses.Count -eq 5)) {
    $firstGraceStatements = @($graceChain.Chain.Clauses[0].Item2.Statements)
    $firstRunIndex = -1; $firstResumeIndex = -1; $firstHoldIndex = -1
    for ($statementIndex = 0; $statementIndex -lt $firstGraceStatements.Count; $statementIndex++) {
        $graceStatement = $firstGraceStatements[$statementIndex]
        if (($graceStatement -is [AssignmentStatementAst]) -and (Test-IsVariable $graceStatement.Left 'insideGraceRun') -and (Test-IsVariable $graceStatement.Right 'insideRun')) { $firstRunIndex = $statementIndex }
        if (($null -ne (Get-StatementCommand $graceStatement)) -and ((Get-StatementCommand $graceStatement).GetCommandName() -eq 'Resume-AbyssMemberClock')) { $firstResumeIndex = $statementIndex }
        if (($graceStatement -is [AssignmentStatementAst]) -and (Test-IsVariable $graceStatement.Left 'graceHold') -and (Test-IsVariable $graceStatement.Right 'true')) { $firstHoldIndex = $statementIndex }
    }
    if (($firstRunIndex -ge 0) -and ($firstRunIndex -lt $firstResumeIndex) -and ($firstResumeIndex -lt $firstHoldIndex)) { $resumeSites += ('첫유예:' + (Get-NodeCode $firstGraceStatements[$firstResumeIndex])) }
    $revertWindowStatements = @($graceChain.Chain.Clauses[4].Item2.Statements)
    if (($revertWindowStatements.Count -ge 2) -and ($null -ne (Get-StatementCommand $revertWindowStatements[0])) -and ((Get-StatementCommand $revertWindowStatements[0]).GetCommandName() -eq 'Resume-AbyssMemberClock') -and
        ($revertWindowStatements[1] -is [AssignmentStatementAst]) -and (Test-IsVariable $revertWindowStatements[1].Left 'graceHold') -and (Test-IsVariable $revertWindowStatements[1].Right 'true')) {
        $resumeSites += ('되돌림뒤창:' + (Get-NodeCode $revertWindowStatements[0]))
    }
}
$r5p2Actual = '생성=[{0}] while 앞 {1} · while 안 금지 명령 {2} · Add* {3} · while 안 Resume {4} · 자리=[{5}]' -f ($clockNewTargets -join ','), $clockNewBeforeWhile, $whileForbiddenCommands, $whileAddCalls, $resumeNodes.Count, ($resumeSites -join ' | ')
$r5p2Expected = '생성=[insideGraceClock(정지),quietClock,reentryClock] while 앞 3 · while 안 금지 명령 0 · Add* 0 · while 안 Resume 2 · 자리=[첫유예:Resume-AbyssMemberClock -Clock $insideGraceClock | 되돌림뒤창:Resume-AbyssMemberClock -Clock $insideGraceClock]'
Check-Equal 'R5-P2 시계 - 생성 3(본 시계 식 안 · 무변화 · 정지 유예) 모두 while 앞 · while 안 Set·Suspend·마감 조정·생성·AddSeconds·AddMilliseconds 0 · while 안 Resume 2(⑩ 첫 유예 갈래 · 되돌림 뒤 창 갈래 첫 문장, 인자 -Clock $insideGraceClock)' $r5p2Actual $r5p2Expected

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

# 선분기 S2(run:15179 - 소스 캡처) - R5-P5 · N4-P9 · N4-P14 의 대조 대상
$selectorS2Nodes = @(Get-CommandNodes -Node $selectorNode -Name 'Write-RunLog' | Where-Object { (@($_.CommandElements).Count -ge 2) -and ($_.CommandElements[1] -is [ExpandableStringExpressionAst]) -and ([string]$_.CommandElements[1].Value).Contains('2연속 앞 로딩') })
$selectorS2Value = $(if ($selectorS2Nodes.Count -eq 1) { [string]$selectorS2Nodes[0].CommandElements[1].Value } else { '' })
$S2_PREFIX = $(if ($selectorS2Value.IndexOf(')') -ge 0) { $selectorS2Value.Substring(0, $selectorS2Value.IndexOf(')') + 1) } else { '' })   # '[어비스] 입장 계측 - 던전 안 2연속 앞 로딩(알 수 없음)'
Check-True '정적 전제: 선분기 S2 확장 문자열이 정확히 하나 · 접두 캡처' (($selectorS2Nodes.Count -eq 1) -and ($S2_PREFIX.Length -gt 0) -and $S2_PREFIX.StartsWith($S2_LINE_PREFIX)) ("선분기 S2 $($selectorS2Nodes.Count)개 · 접두=[$S2_PREFIX]")

# R5-P5 - S2: Write-RunLog 확장 문자열 '[어비스] 입장 계측 - 던전 안 2연속 앞 로딩(알 수 없음)' 1 · 그 밖 꼴 0 · 그 줄의 변수(memberFieldSettleSeconds 제외)가 if·loop 조건에 0
$waiterLogNodes = @(Get-CommandNodes -Node $waiterNode -Name 'Write-RunLog')
$s2ExpandableNodes = @($waiterLogNodes | Where-Object { (@($_.CommandElements).Count -ge 2) -and ($_.CommandElements[1] -is [ExpandableStringExpressionAst]) -and ($S2_PREFIX.Length -gt 0) -and ([string]$_.CommandElements[1].Value).StartsWith($S2_PREFIX) })
$s2OtherForms = @($waiterNode.FindAll({ param($candidate) (($candidate -is [StringConstantExpressionAst]) -or ($candidate -is [ExpandableStringExpressionAst])) -and ([string]$candidate.Value).Contains('입장 계측') }, $true)).Count - $s2ExpandableNodes.Count
$s2Variables = $(if ($s2ExpandableNodes.Count -eq 1) { @($s2ExpandableNodes[0].CommandElements[1].FindAll({ param($candidate) $candidate -is [VariableExpressionAst] }, $true) | ForEach-Object { [string]$_.VariablePath.UserPath } | Where-Object { $_ -ne 'memberFieldSettleSeconds' } | Sort-Object -Unique) } else { @() })
$conditionNodes = @(foreach ($conditionOwner in $waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -or ($candidate -is [LoopStatementAst]) }, $true)) {
        if ($conditionOwner -is [IfStatementAst]) { foreach ($ownerClause in $conditionOwner.Clauses) { $ownerClause.Item1 } } elseif ($null -ne $conditionOwner.Condition) { $conditionOwner.Condition }
    })
$s2VariablesInConditions = @($s2Variables | Where-Object { $variableName = $_; @($conditionNodes | Where-Object { Test-HasVariable $_ $variableName }).Count -gt 0 })
Check-Equal 'R5-P5 S2 - Write-RunLog 확장 문자열(선분기 S2 접두) 1 · 그 밖 꼴 0 · 그 줄의 계측 변수(memberFieldSettleSeconds 제외)가 waiter 의 if·loop 조건에 0' `
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

# R5-P8 - 선택 화면·메뉴·상세 판독 0 · 분류 호출에 -SelectionVisible·-MenuVisible·-DetailVisible 0 (그 셋은 구현 단위 ⑥d 의 'field' 목표)
$r5p8Commands = @(@('Test-AbyssSelectionScreen', 'Test-AbyssMenu', 'Test-AbyssKnownDetailScreen') | Where-Object { Test-HasCommand $waiterNode $_ })
$classifyCalls = @(Get-CommandNodes -Node $waiterNode -Name 'Resolve-AbyssHandoffStartScreen')
$classifyExtraParameters = @($classifyCalls | ForEach-Object { $_.CommandElements } | Where-Object { ($_ -is [CommandParameterAst]) -and (@('SelectionVisible', 'MenuVisible', 'DetailVisible') -contains $_.ParameterName) } | ForEach-Object { $_.ParameterName })
Check-Equal 'R5-P8 Test-AbyssSelectionScreen · Test-AbyssMenu · Test-AbyssKnownDetailScreen 0 · 분류 호출에 -SelectionVisible·-MenuVisible·-DetailVisible 0' `
    ('명령=[{0}] · 분류 호출 {1} · 선택 화면 셋 인자=[{2}]' -f ($r5p8Commands -join ','), $classifyCalls.Count, ($classifyExtraParameters -join ',')) '명령=[] · 분류 호출 1 · 선택 화면 셋 인자=[]'

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

# R5-P14 - resume 유예: $ResumeGrace 참조 = param 블록 밖 1(⑩ 마감 if 안) · 그 갈래의 다섯 식(정규화 글자 · 순서 - 구현 형상 계약) · else 0 · 기다리는 화면 문자열 0
$R5P14_EXPRESSIONS = @(
    '($insideStreak -eq 1) -and ($insideGraceRun -eq 0)',
    '($insideStreak -eq 1) -and ($insideGraceRun -eq $insideRun) -and (-not (Test-AbyssMemberClockExpired -Clock $insideGraceClock))',
    "`$quietOpen -and `$ReportRewardReturn -and (`$lastKind -eq 'reward3')",
    "`$quietOpen -and (`$lastKind -eq '')",
    '$insideGraceReverted -and (-not (Test-AbyssMemberClockExpired -Clock $insideGraceClock))')
$resumeGraceReferences = @($waiterNode.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -eq 'ResumeGrace') }, $true) |
        Where-Object { -not (Test-AstWithin -Node $_ -Ancestor $waiterNode.Body.ParamBlock) })
$deadlineIfNode = @($waiterNode.FindAll({ param($candidate) ($candidate -is [IfStatementAst]) -and (@($candidate.Clauses[0].Item1.FindAll({ param($commandNode) ($commandNode -is [CommandAst]) -and
                    ($commandNode.GetCommandName() -eq 'Test-AbyssMemberClockExpired') -and (Test-IsVariable (Get-CommandArgument -Command $commandNode -Name 'Clock') 'reentryClock') }, $true)).Count -gt 0) }, $true)) | Select-Object -First 1
$referencesInDeadline = @($resumeGraceReferences | Where-Object { ($null -ne $deadlineIfNode) -and (Test-AstWithin -Node $_ -Ancestor $deadlineIfNode.Clauses[0].Item2) }).Count
$chainConditions = $(if ($null -ne $graceChain.Chain) { @($graceChain.Chain.Clauses | ForEach-Object { Get-NodeCode $_.Item1 }) } else { @() })
$chainElse = $(if ($null -ne $graceChain.Chain) { [int]($null -ne $graceChain.Chain.ElseClause) } else { -1 })
$waitingStrings = $(if ($null -ne $graceChain.GraceIf) { @($graceChain.GraceIf.Clauses[0].Item2.FindAll({ param($candidate) $candidate -is [StringConstantExpressionAst] }, $true) | ForEach-Object { [string]$_.Value } |
            Where-Object { @('ready', 'matching', 'popup', 'entry-waiting', 'unknown', 'prompt', 'field') -contains $_ }) } else { @('갈래 없음') })
Check-Equal 'R5-P14 resume 유예 - $ResumeGrace 참조 param 밖 1(⑩ 마감 if 안) · 그 갈래 다섯 식(던전 안 첫 유예 · 연장 · 3버튼 · 첫 유효 회전 전 · 되돌림 뒤 창 - 정규화 글자·순서) · else 0 · 기다리는 화면 문자열 0' `
    ('참조 {0}(마감 if 안 {1}) · 갈래 {2} · 식=[{3}] · else {4} · 문자열=[{5}]' -f $resumeGraceReferences.Count, $referencesInDeadline, $graceChain.GraceIfCount, ($chainConditions -join ' || '), $chainElse, ($waitingStrings -join ',')) `
    ('참조 1(마감 if 안 1) · 갈래 1 · 식=[{0}] · else 0 · 문자열=[]' -f ($R5P14_EXPRESSIONS -join ' || '))
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
function Get-R5P16Problems {
    $problemList = New-Object System.Collections.Generic.List[string]
    $tryNodes = @($waiterNode.FindAll({ param($candidate) $candidate -is [TryStatementAst] }, $true))
    if ($tryNodes.Count -ne 1) { $problemList.Add("try $($tryNodes.Count)개"); return $problemList.ToArray() }
    $tryNode = $tryNodes[0]
    if ($tryNode.CatchClauses.Count -ne 1) { $problemList.Add("catch 절 $($tryNode.CatchClauses.Count)개"); return $problemList.ToArray() }
    $catchClause = $tryNode.CatchClauses[0]
    if ($catchClause.CatchTypes.Count -ne 0) { $problemList.Add("catch 형식 $($catchClause.CatchTypes.Count)개") }
    $tryStatements = @($tryNode.Body.Statements)
    if (($tryStatements.Count -ne 2) -or (-not ($tryStatements[0] -is [IfStatementAst])) -or (-not (Test-HasCommand $tryStatements[0].Clauses[0].Item1 'Invoke-PurchasePopupSweep')) -or
        (-not ($tryStatements[1] -is [IfStatementAst])) -or (-not (Test-HasCommand $tryStatements[1].Clauses[0].Item2 'Test-DungeonClearPrompt'))) { $problemList.Add("try 본문 = ④ 스윕 if + ⑤ 판독 if 가 아님(문장 $($tryStatements.Count)개)") }
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

# N4-P2 - 배선 0: 워커의 Wait-AbyssReentry 호출 0 · Resolve-AbyssReentryVerdict 호출 1(자리 = Wait-AbyssReentry 안) - ⑤ 가 갱신
$waiterCallNodes = @(Get-CommandNodes -Node $workerAst -Name 'Wait-AbyssReentry')
$verdictCallNodes = @(Get-CommandNodes -Node $workerAst -Name 'Resolve-AbyssReentryVerdict')
Check-Equal 'N4-P2 배선 0 - 워커의 Wait-AbyssReentry 호출 0 · Resolve-AbyssReentryVerdict 호출 1(자리 = Wait-AbyssReentry 안)' `
    ('대기 함수 호출 {0} · 순수 판정 호출 {1} · 자리=[{2}]' -f $waiterCallNodes.Count, $verdictCallNodes.Count, ((@($verdictCallNodes | ForEach-Object { Get-EnclosingFunctionName $_ })) -join ',')) '대기 함수 호출 0 · 순수 판정 호출 1 · 자리=[Wait-AbyssReentry]'

# N4-P3 - 순수 판정: 명령 0 · $script: 0 · exit·throw·try 0 · return 6 · 반환 문자열 = {entered, field, reward, cancelled, reclick, ''} · -Target ValidateSet = {entry, reward, field}
$verdictCommands = @($verdictNode.FindAll({ param($candidate) $candidate -is [CommandAst] }, $true)).Count
$verdictScriptVariables = @($verdictNode.FindAll({ param($candidate) ($candidate -is [VariableExpressionAst]) -and ($candidate.VariablePath.UserPath -like 'script:*') }, $true)).Count
$verdictExits = @($verdictNode.FindAll({ param($candidate) ($candidate -is [ExitStatementAst]) -or ($candidate -is [ThrowStatementAst]) -or ($candidate -is [TryStatementAst]) }, $true)).Count
$verdictReturns = @($verdictNode.FindAll({ param($candidate) $candidate -is [ReturnStatementAst] }, $true))
$verdictReturnValues = @($verdictReturns | ForEach-Object { $returnInner = Get-InnerExpression $_.Pipeline; $(if ($returnInner -is [StringConstantExpressionAst]) { "'" + $returnInner.Value + "'" } else { '?' }) } | Sort-Object -Unique -CaseSensitive)
$targetParameter = $(if ($null -ne $verdictNode.Body.ParamBlock) { @($verdictNode.Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Target' }) | Select-Object -First 1 } else { $null })
$validateSetValues = $(if ($null -ne $targetParameter) { @($targetParameter.Attributes | Where-Object { ($_ -is [AttributeAst]) -and ($_.TypeName.Name -eq 'ValidateSet') } | ForEach-Object { $_.PositionalArguments } | ForEach-Object { [string]$_.Value } | Sort-Object -CaseSensitive) } else { @() })
Check-Equal "N4-P3 순수 판정 - 명령 0 · `$script: 0 · exit·throw·try 0 · return 6 · 반환 문자열 집합 · -Target ValidateSet = {entry, reward, field}" `
    ('명령 {0} · script {1} · exit/throw/try {2} · return {3} · 반환=[{4}] · ValidateSet=[{5}]' -f $verdictCommands, $verdictScriptVariables, $verdictExits, $verdictReturns.Count, ($verdictReturnValues -join ','), ($validateSetValues -join ',')) `
    ('명령 0 · script 0 · exit/throw/try 0 · return 6 · 반환=[{0}] · ValidateSet=[{1}]' -f ((@("''", "'cancelled'", "'entered'", "'field'", "'reclick'", "'reward'") | Sort-Object -Unique -CaseSensitive) -join ','), ((@('entry', 'field', 'reward') | Sort-Object -CaseSensitive) -join ','))

# N4-P4 - waiter 매개변수 이름 차례 = Game·LimitSeconds·Clock·Context·ReportRewardReturn·PanelSeen·ResumeGrace · $Clock 타입 없음 · [ref] 0 (⑥d 가 Target·ChallengeFewMembers 를 더할 때 갱신)
$waiterParameters = $(if ($null -ne $waiterNode.Body.ParamBlock) { @($waiterNode.Body.ParamBlock.Parameters) } else { @() })
$waiterParameterNames = @($waiterParameters | ForEach-Object { [string]$_.Name.VariablePath.UserPath }) -join ','
$clockParameter = @($waiterParameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Clock' }) | Select-Object -First 1
$clockTypeConstraints = $(if ($null -ne $clockParameter) { @($clockParameter.Attributes | Where-Object { $_ -is [TypeConstraintAst] }).Count } else { -1 })
$refConstraints = @($waiterParameters | ForEach-Object { $_.Attributes } | Where-Object { ($_ -is [TypeConstraintAst]) -and ($_.TypeName.Name -eq 'ref') }).Count
Check-Equal 'N4-P4 waiter 매개변수 = Game·LimitSeconds·Clock·Context·ReportRewardReturn·PanelSeen·ResumeGrace · $Clock 타입 없음 · [ref] 0' `
    ('이름=[{0}] · Clock 타입 {1} · ref {2}' -f $waiterParameterNames, $clockTypeConstraints, $refConstraints) '이름=[Game,LimitSeconds,Clock,Context,ReportRewardReturn,PanelSeen,ResumeGrace] · Clock 타입 0 · ref 0'

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

# N4-P6 - waiter 명령 이름 집합 = 정확히 21 (허용 집합의 원본 - 구현이 도움 함수를 더하면 이 행과 명세 3.2.1 표 아래 첫 줄을 함께) · 순수 판정 0
$WAITER_COMMANDS_EXPECTED = @('ForEach-Object', 'Get-AbyssPanelKind', 'Get-Date', 'Invoke-PurchasePopupSweep', 'New-AbyssMemberClock', 'Resolve-AbyssHandoffStartScreen',
    'Resolve-AbyssMemberSweepTurn', 'Resolve-AbyssReentryVerdict', 'Resume-AbyssMemberClock', 'Select-Object', 'Start-Sleep', 'Test-AbyssMemberClockExpired',
    'Test-CaptureRecovered', 'Test-DungeonClearPrompt', 'Test-HomeEndEscHud', 'Test-InDungeonQuest', 'Test-SafeStopDuringCaptureFail', 'Test-UserRecentlyActive',
    'Wait-UserYieldEnd', 'Where-Object', 'Write-RunLog')
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

# N4-P9 - S2 글자·채움 대응(뜻): waiter S2 를 채움 자리로 자른 고정 조각 열 = 선분기 S2 조각 열(-ceq · 여섯) · i 번째 채움 변수 이름 = 선분기 i 번째(다섯 · 대소문자 무관)
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
$n4p9Expected = '선분기 S2 없음'
if (($selectorS2Nodes.Count -eq 1) -and ($s2ExpandableNodes.Count -eq 1)) {
    $selectorParts = Get-S2Parts $selectorS2Nodes[0].CommandElements[1]
    $waiterParts = Get-S2Parts $s2ExpandableNodes[0].CommandElements[1]
    $fragmentMismatches = @()
    if ($waiterParts.Fragments.Count -ne $selectorParts.Fragments.Count) { $fragmentMismatches += "조각 수 $($waiterParts.Fragments.Count)" }
    else { for ($fragmentIndex = 0; $fragmentIndex -lt $selectorParts.Fragments.Count; $fragmentIndex++) { if ($waiterParts.Fragments[$fragmentIndex] -cne $selectorParts.Fragments[$fragmentIndex]) { $fragmentMismatches += "조각$fragmentIndex" } } }
    $n4p9Actual = '조각 {0}개 어긋남=[{1}] · 채움=[{2}]' -f $waiterParts.Fragments.Count, ($fragmentMismatches -join ','), ($waiterParts.Fills -join ',')
    $n4p9Expected = '조각 {0}개 어긋남=[] · 채움=[{1}]' -f $selectorParts.Fragments.Count, ($selectorParts.Fills -join ',')
}
Check-Equal 'N4-P9 S2 글자·채움 대응 - waiter S2 고정 조각 열 = 선분기 S2(run:15179 소스 캡처) 조각 열(-ceq) · 채움 변수 이름 차례 = 선분기 (entryUnknown·entryField·entryFieldPart·entryBreaks·memberFieldSettleSeconds)' $n4p9Actual $n4p9Expected

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

# N4-P14 - waiter 안 Write-RunLog = 정확히 2 · 둘 다 인자 하나 - S2 확장 문자열(선분기 S2 접두) 1 · 권장 인원 팝업 관측 안내 상수 1 · 그 밖 0
$logKinds = @($waiterLogNodes | ForEach-Object {
        $logElements = @($_.CommandElements)
        if ($logElements.Count -ne 2) { "인자 $($logElements.Count - 1)개" }
        elseif (($logElements[1] -is [ExpandableStringExpressionAst]) -and ($S2_PREFIX.Length -gt 0) -and ([string]$logElements[1].Value).StartsWith($S2_PREFIX)) { 'S2' }
        elseif (($logElements[1] -is [StringConstantExpressionAst]) -and ([string]$logElements[1].Value -ceq $NOTICE_FULL_TEXT)) { '안내' }
        else { '그 밖' }
    } | Sort-Object)
Check-Equal "N4-P14 waiter 안 Write-RunLog = 정확히 2 · 인자 하나씩 - S2 확장 문자열 1 · '$NOTICE_FULL_TEXT' 1 · 그 밖 0 (결과 줄은 호출부 문구)" ('Write-RunLog {0} = [{1}]' -f $waiterLogNodes.Count, ($logKinds -join ',')) 'Write-RunLog 2 = [S2,안내]'

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
