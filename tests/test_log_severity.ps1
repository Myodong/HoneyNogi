# 워커 로그 → GUI 심각도 분류 계약 (2026-08-09 6차 점검에서 신설).
#
# 왜 필요한가: GUI 는 태그를 못 찾으면 '실패'라는 **낱말**만 보고 그 줄을 빨강 + 오류 배지로
# 올립니다. 그런데 워커의 정상 폴백 로그에는 '확인 실패', '판독 실패', '전면화 실패' 같은
# 표현이 자연스럽게 들어갑니다. 5차에서 '태그 우선'으로 고쳤지만 심각도 태그 7종만 앞세워서
# 도메인 태그([던전]/[생활]/…)만 달린 줄이 그대로 샜고, 6차 AST 전수 스캔에서 **7줄**이
# 여전히 오류로 새는 것을 확인했습니다. 로그를 정직하게 쓸수록 오류 배지가 부푸는 구조라
# 사용자가 진짜 오류를 놓치게 됩니다.
#
# 이 테스트는 낱말을 하나씩 고치는 대신 **분류 규칙 자체**를 감시합니다:
#   ① GUI Add-ColoredLogLine 의 분기 규칙을 **소스에서 그대로 뽑아** 적용합니다(사본 금지).
#   ② 워커의 Write-RunLog 문자열 리터럴을 AST 로 전수 수집합니다.
#   ③ 그중 '오류'로 분류되는 줄은 반드시 [오류] 태그를 달고 있어야 합니다.
#   ④ 워커가 실제로 쓰는 선두 태그가 GUI 규칙에 전부 등장해야 합니다(새 태그 누락 감시).
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$workerPath = Join-Path $projectRoot 'mabinogi_run_once.ps1'
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

# ── ① GUI 분류 규칙을 소스에서 추출 ─────────────────────────────────────────
# 진리표를 테스트 안에 다시 박으면 소스가 바뀌어도 안 움직입니다(5차 변이 검증의 교훈).
$guiBody = [string](Get-SourceFunctionDefinitions -Path $guiPath -Names @('Add-ColoredLogLine'))
$branchMatches = @([regex]::Matches($guiBody, "(?:if|elseif) \(\`$Text -match '([^']+)'\) \{"))
$rules = @()
for ($i = 0; $i -lt $branchMatches.Count; $i++) {
  $start = $branchMatches[$i].Index + $branchMatches[$i].Length
  $end = if ($i + 1 -lt $branchMatches.Count) { $branchMatches[$i + 1].Index } else { $guiBody.Length }
  $rules += , @{
    Pattern  = $branchMatches[$i].Groups[1].Value
    Severity = $(if ($guiBody.Substring($start, $end - $start) -match "\`$severity = 'error'") { 'error' }
                 elseif ($guiBody.Substring($start, $end - $start) -match "\`$severity = 'warn'") { 'warn' }
                 else { '' })
  }
}
Assert-Case '규칙 추출: 분기 개수(태그 5 + 도메인 1 + 낱말 1)' $rules.Count 7

function Get-LineSeverity {
  # GUI 와 같은 순서로 첫 일치 분기를 채택합니다.
  param([string]$Text)
  foreach ($rule in $rules) {
    if ($Text -match $rule.Pattern) { return $rule.Severity }
  }
  return ''
}

# 규칙 추출이 제대로 됐는지 먼저 확인 (추출이 비면 아래 전수 검사가 무조건 통과해 버립니다)
Assert-Case '대조: [오류] 줄은 error' (Get-LineSeverity '12:00:00 [오류] 무언가 터짐') 'error'
Assert-Case '대조: [경고] 줄은 warn' (Get-LineSeverity '12:00:00 [경고] 조심') 'warn'
Assert-Case '대조: 태그 없는 실패 줄은 error' (Get-LineSeverity '12:00:00 진행 상황 저장 실패') 'error'
Assert-Case '대조: 태그 없는 오류 종료 줄은 error' (Get-LineSeverity '12:00:00 워커가 오류 종료(코드 1)') 'error'
Assert-Case '대조: [안내] + 실패는 error 아님' `
  (Get-LineSeverity '12:00:00 [안내] 커서 위치 확인이 정상으로 돌아왔습니다 (확인 실패 3회 생략)') ''
Assert-Case '대조: 도메인 태그 + 실패는 error 아님' `
  (Get-LineSeverity '12:00:00 [생활] 목록 스크롤: 게임 전면화 실패로 건너뜀') ''

# ── ② 워커의 Write-RunLog 문자열 리터럴 전수 수집 ────────────────────────────
$workerSource = [IO.File]::ReadAllText($workerPath)
$parseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseInput($workerSource, [ref]$null, [ref]$parseErrors)
Assert-Case '워커 파싱 오류 없음' $parseErrors.Count 0
$logCalls = @($workerAst.FindAll({
  param($node)
  $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Write-RunLog'
}, $true))
Assert-Case '워커 Write-RunLog 호출을 실제로 수집' ([bool]($logCalls.Count -gt 300)) 'True'

# 워커 로그의 절반가량은 `"$($script:contentTag) …"` 로 시작합니다. 정적으로는 선두가 태그로
# 안 보이지만 **실행 시에는 반드시 도메인 태그**입니다. 그 사실 자체를 소스에서 확인한 뒤
# 대표값으로 치환해야 이 검사가 실제 화면과 같은 것을 봅니다 (치환을 빼면 4줄이 오탐).
$contentTagValues = @([regex]::Matches($workerSource, "contentTag = (?:\`$\(if \([^)]*\) \{ )?'(\[[^']+\])'") |
  ForEach-Object { $_.Groups[1].Value })
$contentTagValues += @([regex]::Matches($workerSource, "contentTag = \`$\(if \([^)]*\) \{ '\[[^']+\]' \} else \{ '(\[[^']+\])' \}") |
  ForEach-Object { $_.Groups[1].Value })
$contentTagValues = @($contentTagValues | Sort-Object -Unique)
Assert-Case 'contentTag 값을 소스에서 수집' ($contentTagValues -join ',') '[던전],[사냥터],[심층],[어비스]'

$literals = @()
foreach ($call in $logCalls) {
  foreach ($element in $call.CommandElements) {
    if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
        $element -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
      # 대표값 하나로 치환합니다 - 네 값 모두 도메인 태그라 분류 결과가 같습니다(위에서 확인).
      $text = $element.Value -replace '\$\(\$script:contentTag\)', $contentTagValues[0]
      $literals += , @{ Line = $element.Extent.StartLineNumber; Text = $text }
    }
  }
}
# 치환이 실제로 일어났는지 (정규식이 어긋나면 조용히 0건이 되고 검사가 무력해집니다)
Assert-Case '치환: contentTag 선두 줄이 도메인 태그로 보임' `
  ([bool](@($literals | Where-Object { $_.Text -like '[[]던전[]] *' }).Count -gt 30)) 'True'

# ── ③ '오류'로 칠해지는 줄은 [오류] 태그를 달고 있어야 한다 ───────────────────
$leaked = @()
foreach ($literal in $literals) {
  if ((Get-LineSeverity $literal.Text) -eq 'error' -and $literal.Text -notmatch '\[오류\]') {
    $leaked += ('{0}행: {1}' -f $literal.Line, $literal.Text)
  }
}
if ($leaked.Count -gt 0) { $leaked | ForEach-Object { "     └ $_" } }
Assert-Case '정상 로그가 오류로 새지 않음(전수)' $leaked.Count 0

# ── ④ 워커가 쓰는 선두 태그를 GUI 규칙이 전부 알고 있는가 ─────────────────────
# 새 콘텐츠 태그를 추가하면서 GUI 목록을 안 고치면 그 순간부터 또 샙니다.
$workerTags = @{}
foreach ($literal in $literals) {
  if ($literal.Text -match '^\[([^\]]{1,8})\]') { $workerTags[$Matches[1]] = $true }
}
# 심각도 태그는 제외합니다 - [오류] 는 오류로 분류되는 게 정상입니다.
$severityTags = @('오류', '경고', '안내', '진단', '중단', '완료', '준비')
$unknownTags = @()
foreach ($tag in ($workerTags.Keys | Sort-Object)) {
  if ($severityTags -contains $tag) { continue }
  # '[태그] … 실패' 를 넣었을 때 오류로 분류되면 GUI 가 그 태그를 모른다는 뜻입니다.
  if ((Get-LineSeverity ("[$tag] 무언가 판독 실패")) -eq 'error') { $unknownTags += $tag }
}
if ($unknownTags.Count -gt 0) { "     └ GUI 가 모르는 태그: $($unknownTags -join ', ')" }
Assert-Case '워커 선두 태그를 GUI 가 전부 인지' $unknownTags.Count 0
Assert-Case '수집된 워커 선두 태그 수(참고)' ([bool]($workerTags.Count -ge 14)) 'True'

exit $fails
