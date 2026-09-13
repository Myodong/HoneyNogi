# 테스트가 운영 스크립트의 순수 함수를 직접 실행하기 위한 AST 추출 헬퍼입니다.

function Get-SourceFunctionDefinitions {
  param(
    [string]$Path,
    [string[]]$Names
  )

  $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  $tokens = $null; $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($resolved, [ref]$tokens, [ref]$errors)
  if ($errors.Count -gt 0) {
    throw "소스 파서 오류($resolved): $($errors[0].Message)"
  }
  foreach ($name in $Names) {
    $functionAst = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
      }, $true) | Select-Object -First 1
    if (-not $functionAst) { throw "소스 함수를 찾지 못했습니다: $name ($resolved)" }
    [string]$functionAst.Extent.Text
  }
}

function Remove-SourceComments {
  # 소스 문자열 단언용 '주석 뺀 사본' (2026-09-13 신설). 주석에만 걸리는 단언을 막기 위해 주석 토큰을
  # 같은 길이의 공백으로 치환합니다 - 나머지 텍스트의 위치·줄 구조는 그대로라 기존 정규식이 그대로 먹습니다.
  param([string]$Text)
  $tokens = $null; $errors = $null
  [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors) | Out-Null
  $builder = New-Object System.Text.StringBuilder $Text
  foreach ($token in $tokens) {
    if ($token.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment) {
      $start = $token.Extent.StartOffset
      $length = $token.Extent.EndOffset - $start
      [void]$builder.Remove($start, $length).Insert($start, ($token.Text -replace '[^\r\n]', ' '))   # CR/LF 보존 - 다중행 주석의 줄 수 유지 (구현 리뷰 지적)
    }
  }
  return $builder.ToString()
}
