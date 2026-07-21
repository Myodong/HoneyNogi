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
