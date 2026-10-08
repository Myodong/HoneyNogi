# 아이콘 자산 일치 진리표 (2026-10 ESC 메뉴 '어비스' 아이콘 폴백 + 아이콘 폴더 - 설계 v2 10.1 A1~A7, 설계 리뷰 ② P2-1 반영)
#
# 워커가 쓰는 '어비스' 아이콘은 스크립트 안 base64 사본($script:workerIconB64)이고 원본은 icons\<키>.png 입니다 - exe 는 이미지 파일을
# 추출하지 않으므로 GUI 생활 아이콘처럼 사본을 둡니다. 원본만 바꾸고 사본을 안 고치면 exe 가 옛 그림으로 배포되고, base64 를 손으로
# 옮기면 조용히 깨집니다(2026-08-05 GUI 아이콘 5종 손 전사 손상). 빌드 검사(build_exe.ps1 의 아이콘 사본 일치 검사)와 같은 규칙을
# 새 클론·다른 PC 에서도 돌게 고정합니다:
#   A1 워커 표 - 빌드 검사와 같은 AST·토큰 규칙: 주석 뺀 토큰에서 'workerIconB64' 글자 정확히 2곳, 변수 참조 2개 = 정의 1
#      ($script:workerIconB64 = @{...} 의 왼쪽) + 양성 허용 읽기 1(Initialize-AbyssMenuIconTemplates 안
#      [Convert]::FromBase64String([string]$script:workerIconB64['abyssMenu']) 의 인자 그 자체), 우변 해시 리터럴, 값은 파이프라인 요소
#      1개의 문자열 상수. 정규식으로 읽으면 주석 속 정상 사본·뒤쪽 재대입·별칭 쓰기·값 파이프라인 변형이 통과합니다(설계 리뷰 P2).
#      각 키의 해독 바이트 = icons\<키>.png, 해독 이미지가 열리고 알파>0 화소가 있음. 어긋나면 워커에 붙일 올바른 줄을 출력합니다
#   A2 GUI 표($script:lifeSkillIconB64) - 실행 정의 1곳·값 규칙·각 키의 해독 바이트 = icons\<키>.png (참조 허용 목록은 워커 표에만 -
#      GUI 표는 빌드 검사 대상이 아니고 여러 곳에서 읽힘. 크기·실디코드 가드는 test_audit_fixes)
#   A3 icons\ 파일 집합 = {app.ico} ∪ 워커 키 ∪ GUI 키 - 고아·누락 FAIL, 두 표의 키가 겹치면 FAIL ('맵 키 = 파일 이름' 규칙)
#   A4 app.ico 는 루트가 아니라 icons\ 에 있고 ICO 머리(00 00 01 00)
#   A5 (build\build_exe.ps1 없으면 SKIP - 로컬 전용) 빌드 아이콘 경로 icons\app.ico 2곳·옛 루트 경로 0곳·아이콘 사본 검사 블록 1곳
#   A6 (build\launcher.cs 없으면 SKIP - 로컬 전용) 런처가 리소스 app.ico 를 그대로 추출 (리소스 이름 유지 - 런처 무변경)
#   A7 저장소에서 직접 실행한 GUI 의 창 아이콘: 'app.ico'(exe 추출본) 다음 'icons\app.ico' 순서
# base64 비교는 문자열이 아니라 해독 바이트로 합니다 - PowerShell 의 -eq/-ne 는 대소문자를 무시해 값이 다른 글자('A' ↔ 'a')를 같다고 봅니다.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing
$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ("$Actual" -eq "$Expected") { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}
function Check-True {
  param([string]$Name, [bool]$Condition, [string]$Detail)
  if ($Condition) { "OK   $Name" }
  else { "FAIL $Name ($Detail)"; $script:fails++ }
}

# 경로는 저장소 루트 기준 절대 경로 - .NET 상대 경로는 셸 위치(Set-Location)를 따르지 않습니다 (설계 v2 5.5)
$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
$guiPath = Join-Path $root 'mabinogi_gui.ps1'
$iconDir = Join-Path $root 'icons'
$buildPath = Join-Path $root 'build\build_exe.ps1'
$launcherPath = Join-Path $root 'build\launcher.cs'

function Test-ByteArrayEqual {
  # 두 바이트 배열이 같은지 (길이 + 모든 바이트). 한쪽이 없으면(해독 실패 등) 다르다고 봅니다
  param([byte[]]$Left, [byte[]]$Right)
  if ($null -eq $Left -or $null -eq $Right -or $Left.Length -ne $Right.Length) { return $false }
  for ($byteIndex = 0; $byteIndex -lt $Left.Length; $byteIndex++) {
    if ($Left[$byteIndex] -ne $Right[$byteIndex]) { return $false }
  }
  return $true
}

function Get-AlphaPixelCount {
  # PNG 바이트를 이미지로 열어 알파>0 화소 수를 셉니다. 열리지 않으면 -1 을 돌려줍니다(호출부 단언이 그 값을 실패로 보고)
  param([byte[]]$Bytes)
  if ($null -eq $Bytes) { return -1 }
  $imageStream = $null; $decodedImage = $null; $decodedBitmap = $null
  try {
    $imageStream = New-Object System.IO.MemoryStream(, $Bytes)
    $decodedImage = [System.Drawing.Image]::FromStream($imageStream)
    # FromStream 은 스트림 수명에 묶이므로 Bitmap 사본으로 셉니다 (워커·GUI 아이콘 해독과 같은 계약)
    $decodedBitmap = New-Object System.Drawing.Bitmap($decodedImage)
    $alphaCount = 0
    for ($pixelY = 0; $pixelY -lt $decodedBitmap.Height; $pixelY++) {
      for ($pixelX = 0; $pixelX -lt $decodedBitmap.Width; $pixelX++) {
        if ($decodedBitmap.GetPixel($pixelX, $pixelY).A -gt 0) { $alphaCount++ }
      }
    }
    return $alphaCount
  } catch {
    return -1
  } finally {
    if ($decodedBitmap) { $decodedBitmap.Dispose() }
    if ($decodedImage) { $decodedImage.Dispose() }
    if ($imageStream) { $imageStream.Dispose() }
  }
}

function Get-HashtableStringEntries {
  # 해시 리터럴(@{...})의 항목을 읽습니다 - 키는 문자열 상수, 값은 파이프라인 요소 1개의 문자열 상수여야 합니다
  # ('정상' | ForEach-Object { '다른' } 같은 값 변형은 실행 값이 리터럴과 달라 거부 - 설계 리뷰 P2 재확인). 규칙에 어긋난 항목은 Bad 에 모읍니다
  param($HashtableAst)
  $goodEntries = New-Object System.Collections.Generic.List[object]
  $badEntries = New-Object System.Collections.Generic.List[string]
  foreach ($pair in $HashtableAst.KeyValuePairs) {
    $valueOk = ($pair.Item2 -is [System.Management.Automation.Language.PipelineAst]) -and ($pair.Item2.PipelineElements.Count -eq 1) -and
      ($pair.Item2.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst]) -and
      ($pair.Item2.PipelineElements[0].Expression -is [System.Management.Automation.Language.StringConstantExpressionAst])
    if (($pair.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and $valueOk) {
      $goodEntries.Add([pscustomobject]@{ Name = [string]$pair.Item1.Value; Base64 = [string]$pair.Item2.PipelineElements[0].Expression.Value })
    } else {
      $badEntries.Add([string]$pair.Item1.Extent.Text)
    }
  }
  return [pscustomobject]@{ Entries = $goodEntries.ToArray(); Bad = $badEntries.ToArray() }
}

function Test-AllowedWorkerIconRead {
  # 워커 표 읽기의 양성 허용 한 모양 - [Convert]::FromBase64String([string]$script:workerIconB64['abyssMenu']) 의 인자 그 자체이고
  # Initialize-AbyssMenuIconTemplates 안 (조상 경로 Index → Convert([string]) → FromBase64String 인자 1개 고정. 빌드 검사와 같은 규칙 -
  # 괄호·형변환으로 감싼 좌변 대입 같은 변형은 경로가 달라 거부됩니다, 설계 리뷰 P2 재확인)
  param($Variable)
  $readIndex = $Variable.Parent
  $readCast = $(if ($readIndex) { $readIndex.Parent })
  $readCall = $(if ($readCast) { $readCast.Parent })
  $readFunction = $readCall
  while ($readFunction -and -not ($readFunction -is [System.Management.Automation.Language.FunctionDefinitionAst])) { $readFunction = $readFunction.Parent }
  # 변수 이름·범위, 인덱스 문자열 상수, 정적 [Convert] 호출까지 고정 - 키 오타·$global: 범위·다른 형의 FromBase64String 거부 (구현 리뷰 P2)
  return [bool](($Variable.Extent.Text -eq '$script:workerIconB64') -and
    ($readIndex -is [System.Management.Automation.Language.IndexExpressionAst]) -and ($readIndex.Target -eq $Variable) -and ($readIndex.Index -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and
    ($readCast -is [System.Management.Automation.Language.ConvertExpressionAst]) -and ($readCast.Child -eq $readIndex) -and ($readCast.Type.TypeName.Name -eq 'string') -and
    ($readCall -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) -and ($readCall.Member.Extent.Text -eq 'FromBase64String') -and $readCall.Static -and
    ($readCall.Expression -is [System.Management.Automation.Language.TypeExpressionAst]) -and (@('Convert', 'System.Convert') -contains $readCall.Expression.TypeName.FullName) -and
    ($readCall.Arguments.Count -eq 1) -and ($readCall.Arguments[0] -eq $readCast) -and
    $readFunction -and ($readFunction.Name -eq 'Initialize-AbyssMenuIconTemplates'))
}

function Test-IconEntriesAgainstFiles {
  # 표 항목마다 해독 바이트 = icons\<키>.png 인지 봅니다. 다르면 붙일 올바른 줄(파일 바이트의 base64)을 출력합니다 - 손으로 옮기지 말 것.
  # 이미지 단언(알파>0 화소)은 워커 표에만 둡니다 (GUI 표의 크기·실디코드는 test_audit_fixes 가 지킴)
  param([string]$Label, [object[]]$Entries, [string]$FixHint, [switch]$CheckImage)
  foreach ($entry in $Entries) {
    $pngPath = Join-Path $iconDir ($entry.Name + '.png')
    if (-not (Test-Path -LiteralPath $pngPath)) {
      "FAIL $Label $($entry.Name): 원본 icons\$($entry.Name).png 가 없습니다 ('맵 키 = 파일 이름' 규칙 - 키 이름을 바꿨다면 파일 이름도 함께)"
      $script:fails++
      continue
    }
    $fileBytes = [IO.File]::ReadAllBytes($pngPath)
    $decodedBytes = $null
    try { $decodedBytes = [Convert]::FromBase64String($entry.Base64) } catch { $decodedBytes = $null }
    if (Test-ByteArrayEqual -Left $decodedBytes -Right $fileBytes) {
      "OK   $Label $($entry.Name): 해독 바이트 = icons\$($entry.Name).png ($($fileBytes.Length) B)"
    } else {
      "FAIL $Label $($entry.Name): base64 해독 바이트가 icons\$($entry.Name).png 와 다릅니다 - $FixHint"
      "  $($entry.Name) = '$([Convert]::ToBase64String($fileBytes))'"
      $script:fails++
    }
    if ($CheckImage) {
      # 기대값(화소 수)은 숫자를 박지 않고 원본 파일에서 계산합니다
      $alphaExpected = Get-AlphaPixelCount -Bytes $fileBytes
      $alphaDecoded = Get-AlphaPixelCount -Bytes $decodedBytes
      Check-True "$Label $($entry.Name): 해독 이미지가 열리고 알파>0 화소 수가 원본 파일과 같음(1 이상)" (($alphaDecoded -eq $alphaExpected) -and ($alphaExpected -ge 1)) `
        ("해독본 {0}, 원본 {1} (-1 = 이미지로 열리지 않음)" -f $alphaDecoded, $alphaExpected)
    }
  }
}

# ── A1. 워커 아이콘 표 ($script:workerIconB64) ──
$workerText = [IO.File]::ReadAllText($workerPath)
$workerTokens = $null; $workerParseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseInput($workerText, [ref]$workerTokens, [ref]$workerParseErrors)
Check-Equal 'A1 전제: 워커 파싱 오류 0건' $workerParseErrors.Count 0
$iconTokenCount = 0
foreach ($token in $workerTokens) {
  if ($token.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment -and $token.Text -match 'workerIconB64') { $iconTokenCount++ }
}
$iconVariables = @($workerAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.VariableExpressionAst] -and $node.VariablePath.UserPath -match 'workerIconB64' }, $true))
$iconDefinitions = @($iconVariables | Where-Object { $_.Parent -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Parent.Left -eq $_ -and $_.Extent.Text -eq '$script:workerIconB64' -and $_.Parent.Operator -eq [System.Management.Automation.Language.TokenKind]::Equals })
$iconReads = @($iconVariables | Where-Object { Test-AllowedWorkerIconRead -Variable $_ })
# 별칭 변수로 넘기기·Set-Variable·variable: 경로·함수 안 재대입은 이 글자를 한 번 더 써서, 감싼 좌변 대입은 허용 읽기 경로가 달라서 여기서 걸립니다
Check-Equal "A1 규칙: 주석 뺀 토큰의 'workerIconB64' 글자 2곳, 변수 참조 2개 = 정의 1(`$script:workerIconB64 = @{...}) + 허용 읽기 1(Initialize-AbyssMenuIconTemplates 의 FromBase64String 인자) - 빌드 검사와 같은 규칙" `
  ('글자 {0}, 변수 {1}, 정의 {2}, 읽기 {3}' -f $iconTokenCount, $iconVariables.Count, $iconDefinitions.Count, $iconReads.Count) '글자 2, 변수 2, 정의 1, 읽기 1'
$workerEntries = @()
if ($iconDefinitions.Count -eq 1) {
  $workerTable = $iconDefinitions[0].Parent.Right
  $workerTableIsHash = ($workerTable -is [System.Management.Automation.Language.CommandExpressionAst]) -and ($workerTable.Expression -is [System.Management.Automation.Language.HashtableAst])
  Check-Equal 'A1 규칙: 정의의 우변이 해시 리터럴(@{...})' $workerTableIsHash $true
  if ($workerTableIsHash) {
    $workerRead = Get-HashtableStringEntries -HashtableAst $workerTable.Expression
    $workerEntries = @($workerRead.Entries)
    Check-Equal 'A1 규칙: 표의 모든 항목이 키 문자열 상수 + 값 문자열 상수 하나(파이프라인 요소 1개)' ($workerRead.Bad -join ', ') ''
  }
}
Check-True 'A1 규칙: 워커 표에 항목이 1개 이상' ($workerEntries.Count -ge 1) "항목 $($workerEntries.Count)개"
# 읽는 키 = 표의 키 - 키 이름을 한쪽만 바꾸면(오타 포함) 원본 PNG 와 표가 맞아도 실행 때 없는 키를 읽습니다 (구현 리뷰 P2, 빌드 검사와 같은 규칙)
$iconReadKey = $(if ($iconReads.Count -eq 1) { [string]$iconReads[0].Parent.Index.Value } else { '(읽기 없음)' })
Check-True 'A1 규칙: 허용 읽기의 키 = 워커 표의 키 (대소문자 구분 -ceq, 표 키 1개)' (($workerEntries.Count -eq 1) -and ([string]$workerEntries[0].Name -ceq $iconReadKey)) `
  ('표 키 {0} / 읽는 키 {1}' -f (@($workerEntries | ForEach-Object { $_.Name }) -join ', '), $iconReadKey)
Test-IconEntriesAgainstFiles -Label 'A1 워커' -Entries $workerEntries -CheckImage `
  -FixHint '워커 mabinogi_run_once.ps1 의 $script:workerIconB64 표에서 그 줄을 아래 줄로 바꾸세요 (손으로 옮기지 말 것 - 빌드 검사도 같은 줄을 출력)'

# ── A2. GUI 아이콘 표 ($script:lifeSkillIconB64) ──
$guiText = [IO.File]::ReadAllText($guiPath)
$guiTokens = $null; $guiParseErrors = $null
$guiAst = [System.Management.Automation.Language.Parser]::ParseInput($guiText, [ref]$guiTokens, [ref]$guiParseErrors)
Check-Equal 'A2 전제: GUI 파싱 오류 0건' $guiParseErrors.Count 0
# 표를 바꾸는 대입 = 왼쪽(인덱스·멤버 쓰기 포함)에 이 변수가 나오는 대입문 전부 - 정의 1곳만 있어야 실행 값이 리터럴과 같습니다
$guiMapPattern = '(^|:)lifeSkillIconB64$'
$guiMapAssignments = @($guiAst.FindAll({
      param($node)
      ($node -is [System.Management.Automation.Language.AssignmentStatementAst]) -and
      (@($node.Left.FindAll({ param($inner) ($inner -is [System.Management.Automation.Language.VariableExpressionAst]) -and ($inner.VariablePath.UserPath -match $guiMapPattern) }, $true)).Count -gt 0)
    }, $true))
$guiDefinitionOk = ($guiMapAssignments.Count -eq 1) -and ($guiMapAssignments[0].Left.Extent.Text -eq '$script:lifeSkillIconB64') -and
  ($guiMapAssignments[0].Operator -eq [System.Management.Automation.Language.TokenKind]::Equals)
Check-True 'A2 규칙: GUI 표($script:lifeSkillIconB64)를 바꾸는 대입은 실행 정의 1곳뿐' $guiDefinitionOk `
  ('대입 {0}곳: {1}' -f $guiMapAssignments.Count, (($guiMapAssignments | ForEach-Object { $_.Left.Extent.Text + ' ' + $_.Operator }) -join ' / '))
$guiEntries = @()
if ($guiDefinitionOk) {
  $guiTable = $guiMapAssignments[0].Right
  $guiTableIsHash = ($guiTable -is [System.Management.Automation.Language.CommandExpressionAst]) -and ($guiTable.Expression -is [System.Management.Automation.Language.HashtableAst])
  Check-Equal 'A2 규칙: 정의의 우변이 해시 리터럴(@{...})' $guiTableIsHash $true
  if ($guiTableIsHash) {
    $guiRead = Get-HashtableStringEntries -HashtableAst $guiTable.Expression
    $guiEntries = @($guiRead.Entries)
    Check-Equal 'A2 규칙: 표의 모든 항목이 키 문자열 상수 + 값 문자열 상수 하나(파이프라인 요소 1개)' ($guiRead.Bad -join ', ') ''
  }
}
Check-True "A2 규칙: GUI 표에 항목이 1개 이상 (생활 9 + 대분류 3 - 지금 $($guiEntries.Count)개)" ($guiEntries.Count -ge 1) "항목 $($guiEntries.Count)개"
Test-IconEntriesAgainstFiles -Label 'A2 GUI' -Entries $guiEntries `
  -FixHint 'PNG 가 맞으면 mabinogi_gui.ps1 의 $script:lifeSkillIconB64 표에서 그 줄을 아래 줄로, GUI 가 맞으면 그 base64 해독 바이트로 icons\<키>.png 를 다시 저장하세요'

# ── A3. icons\ 파일 집합 ──
if (-not (Test-Path -LiteralPath $iconDir)) {
  "FAIL A3: icons 폴더가 없습니다 ($iconDir)"
  $fails++
} else {
  $workerKeys = @($workerEntries | ForEach-Object { $_.Name })
  $guiKeys = @($guiEntries | ForEach-Object { $_.Name })
  # 파일 시스템은 대소문자를 가리지 않으므로 겹침은 대소문자 무시(-contains)로 봅니다 - 한 파일을 두 표가 차지하면 한쪽 원본이 덮입니다
  $overlapKeys = @($workerKeys | Where-Object { $guiKeys -contains $_ })
  Check-Equal 'A3: 워커·GUI 두 표의 키가 겹치지 않음' ($overlapKeys -join ', ') ''
  $expectedFiles = @(@('app.ico') + @($workerKeys | ForEach-Object { $_ + '.png' }) + @($guiKeys | ForEach-Object { $_ + '.png' }))
  $actualFiles = @(Get-ChildItem -LiteralPath $iconDir -File | ForEach-Object { $_.Name })
  # 이름 규칙('맵 키 = 파일 이름')은 대소문자까지 그대로 봅니다
  $orphanFiles = @($actualFiles | Where-Object { $expectedFiles -cnotcontains $_ } | Sort-Object)
  $missingFiles = @($expectedFiles | Where-Object { $actualFiles -cnotcontains $_ } | Sort-Object)
  Check-Equal 'A3: icons\ 고아 파일 0 (app.ico·두 표의 키 밖 파일)' ($orphanFiles -join ', ') ''
  Check-Equal "A3: icons\ 누락 파일 0 (app.ico + 워커 $($workerKeys.Count)키 + GUI $($guiKeys.Count)키)" ($missingFiles -join ', ') ''
}

# ── A4. app.ico 자리 ──
Check-Equal 'A4: 저장소 루트에 app.ico 없음 (icons\ 로 이동 - 설계 v2 5.6)' (Test-Path -LiteralPath (Join-Path $root 'app.ico')) $false
$icoHead = '(없음)'
$icoPath = Join-Path $iconDir 'app.ico'
if (Test-Path -LiteralPath $icoPath) {
  $icoBytes = [IO.File]::ReadAllBytes($icoPath)
  $icoHead = $(if ($icoBytes.Length -ge 4) { ($icoBytes[0..3] | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' } else { "($($icoBytes.Length) B)" })
}
Check-Equal 'A4: icons\app.ico 있음 + ICO 머리 00 00 01 00' $icoHead '00 00 01 00'

# ── A5. 빌드 스크립트 (로컬 전용 - 없으면 SKIP) ──
if (-not (Test-Path -LiteralPath $buildPath)) {
  "SKIP A5: build\build_exe.ps1 이 없어 빌드 아이콘 경로 검사를 건너뜁니다 (로컬 전용 파일 - 개발 PC 외): $buildPath"
} else {
  $buildCode = Remove-SourceComments -Text ([IO.File]::ReadAllText($buildPath))
  $failsBeforeBuild = $fails
  Check-Equal 'A5: 빌드 exe 아이콘 /win32icon:$root\icons\app.ico 1곳' ([regex]::Matches($buildCode, [regex]::Escape('/win32icon:$root\icons\app.ico')).Count) 1
  Check-Equal 'A5: 빌드 리소스 /resource:$root\icons\app.ico,app.ico 1곳 (리소스 이름 app.ico 그대로 - 런처 무변경)' ([regex]::Matches($buildCode, [regex]::Escape('/resource:$root\icons\app.ico,app.ico')).Count) 1
  Check-Equal 'A5: 옛 루트 경로 $root\app.ico 0곳' ([regex]::Matches($buildCode, [regex]::Escape('$root\app.ico')).Count) 0
  # 아이콘 사본 검사 블록: icons 를 Join-Path 하고, 워커 원문에서 $script:workerIconB64 정의를 찾아 읽고, 원본 바이트의 base64 와 비교 - 컴파일(csc) 앞 1곳
  $iconJoinMatches = [regex]::Matches($buildCode, [regex]::Escape('Join-Path $root ''icons'''))
  # 정의 글자는 1곳 이상(정의 찾기 + 읽기 변수 이름 고정 - 구현 리뷰 P2) - 순서는 첫 등장으로 봅니다
  $definitionReadMatches = [regex]::Matches($buildCode, [regex]::Escape('''$script:workerIconB64'''))
  $compareMatches = [regex]::Matches($buildCode, [regex]::Escape('[Convert]::ToBase64String([IO.File]::ReadAllBytes('))
  $compileMatch = [regex]::Match($buildCode, '&\s*\$csc\b')
  $blockOk = ($iconJoinMatches.Count -eq 1) -and ($definitionReadMatches.Count -ge 1) -and ($compareMatches.Count -eq 1) -and $compileMatch.Success -and
    ($iconJoinMatches[0].Index -lt $definitionReadMatches[0].Index) -and ($definitionReadMatches[0].Index -lt $compareMatches[0].Index) -and
    ($compareMatches[0].Index -lt $compileMatch.Index)
  Check-True 'A5: 아이콘 사본 검사 블록 1곳 - icons 를 Join-Path 하고 워커의 $script:workerIconB64 정의를 읽어 원본 바이트와 비교, 컴파일(csc) 앞 (설계 v2 5.4)' $blockOk `
    ('icons Join-Path {0}곳, 정의 읽기 {1}곳, 바이트 비교 {2}곳, csc 호출 {3}' -f $iconJoinMatches.Count, $definitionReadMatches.Count, $compareMatches.Count, $compileMatch.Success)
  # 비교는 대소문자 구분(-cne)이어야 합니다 - 기본 -ne 는 base64 한 글자의 대소문자만 바뀐 사본을 통과시킵니다(해독 바이트는 다름, 구현 검증 재현)
  Check-Equal 'A5: 아이콘 사본 비교는 대소문자 구분 -cne 1곳, 대소문자 무시 -ne 0곳' ('{0}/{1}' -f [regex]::Matches($buildCode, '-cne\s+\$workerIconEntry\.Base64').Count, [regex]::Matches($buildCode, '\s-ne\s+\$workerIconEntry\.Base64').Count) '1/0'
  if ($fails -gt $failsBeforeBuild) {
    '  빌드 스크립트 사본이 아이콘 폴더 이동 전 판일 수 있습니다 - 개발 PC 보관본으로 갱신하세요 (build\ 는 로컬 전용이라 git 이력이 없음, 설계 v2 5.4 B4)'
  }
}

# ── A6. 런처 (로컬 전용 - 없으면 SKIP) ──
if (-not (Test-Path -LiteralPath $launcherPath)) {
  "SKIP A6: build\launcher.cs 가 없어 런처 app.ico 추출 검사를 건너뜁니다 (로컬 전용 파일 - 개발 PC 외): $launcherPath"
} else {
  $launcherText = [IO.File]::ReadAllText($launcherPath)
  Check-Equal 'A6: 런처가 리소스 app.ico 를 그대로 추출 Extract("app.ico", Path.Combine(dir, "app.ico"), true) 1곳 (리소스 이름 유지 - 런처 무변경)' `
    ([regex]::Matches($launcherText, [regex]::Escape('Extract("app.ico", Path.Combine(dir, "app.ico"), true)')).Count) 1
}

# ── A7. 저장소 직접 실행 GUI 의 창 아이콘 순서 (주석 뺀 사본) ──
$guiCode = Remove-SourceComments -Text $guiText
$primaryIconLine = '$appIconPath = Join-Path $scriptRoot ''app.ico'''
$fallbackIconLine = 'if (-not (Test-Path -LiteralPath $appIconPath)) { $appIconPath = Join-Path $scriptRoot ''icons\app.ico'' }'
$loadIconLine = 'if (Test-Path -LiteralPath $appIconPath) {'
$createIconLine = 'New-Object System.Drawing.Icon($appIconPath)'
$iconLineCounts = @($primaryIconLine, $fallbackIconLine, $loadIconLine, $createIconLine | ForEach-Object { [regex]::Matches($guiCode, [regex]::Escape($_)).Count })
$primaryAt = $guiCode.IndexOf($primaryIconLine); $fallbackAt = $guiCode.IndexOf($fallbackIconLine)
$loadAt = $guiCode.IndexOf($loadIconLine); $createAt = $guiCode.IndexOf($createIconLine)
Check-True "A7: GUI 창 아이콘은 'app.ico'(exe 추출본) → 없으면 'icons\app.ico'(저장소 직접 실행) → 있으면 로드, 각 1곳 (설계 v2 7.5, Q2)" `
  ((($iconLineCounts -join ',') -eq '1,1,1,1') -and ($primaryAt -ge 0) -and ($primaryAt -lt $fallbackAt) -and ($fallbackAt -lt $loadAt) -and ($loadAt -lt $createAt)) `
  ('개수 {0}, 위치 {1}/{2}/{3}/{4}' -f ($iconLineCounts -join ','), $primaryAt, $fallbackAt, $loadAt, $createAt)

if ($fails -gt 0) { "FAIL: $fails 건"; exit 1 }
"OK: 전부 통과"
exit 0
