# 회귀 테스트 일괄 실행기 - Windows PowerShell 5.1 로 실행하세요:
#   powershell -ExecutionPolicy Bypass -File tests\run_all_tests.ps1
# 각 test_*.ps1 은 판정 로직의 진리표 테스트로, FAIL 줄이 있거나 종료 코드가 0이 아니면 실패.
# 운영 판정 함수는 source_test_helpers.ps1로 본체 AST에서 직접 추출해 같은 구현을 검사합니다.
#
# ★ 2026-08-10 9차 점검에서 이 러너 자체의 구멍 두 개를 고쳤습니다:
#   ① 자식이 stderr 로 무언가를 뱉으면 `2>&1` 이 그것을 ErrorRecord 로 바꾸고,
#      $ErrorActionPreference='Stop' 이 그것을 **종료 오류**로 승격시켜 **러너가 통째로
#      중단**됐습니다. 그러면 남은 테스트는 '실행조차 안 된 채' 사라지는데 출력에는
#      그 사실이 남지 않습니다 - 회귀 스위트가 조용히 반쪽이 되는 최악의 형태입니다.
#      → 자식 실행 구간만 Continue 로 낮추고 try/catch 로 감싸, 죽은 테스트도 **실패로
#        계상하고 나머지를 계속** 돌립니다.
#   ② 총 개수를 고정하지 않아 **파일이 사라져도 '전부 통과'** 로 끝났습니다.
#      → 기대 개수를 못 박습니다. 테스트를 추가/삭제하면 이 숫자도 함께 고쳐야 합니다.
$ErrorActionPreference = 'Stop'
$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tests = @(Get-ChildItem -Path $testDir -Filter 'test_*.ps1' | Sort-Object Name)

# 기대 테스트 개수 (추가/삭제 시 함께 갱신). 숫자가 어긋나면 실패로 끝냅니다.
$expectedTestCount = 64   # 2026-08-16 +1: test_user_yield / 2026-08-17 +1: test_dg_party_reenter (v2.1.2)

$failedTests = @()
$erroredTests = @()
foreach ($t in $tests) {
  $out = $null
  $exit = 0
  $runError = ''
  try {
    # 자식 프로세스의 stderr 가 ErrorRecord 로 올라와도 러너를 죽이지 않게 이 구간만 낮춥니다
    $prevPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $t.FullName 2>&1
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevPreference
  } catch {
    $ErrorActionPreference = 'Stop'
    $runError = $_.Exception.Message
    $exit = -1
  }
  $hasFail = (@($out) | Where-Object { $_ -match '^FAIL' }).Count -gt 0
  if ($runError) {
    $erroredTests += $t.Name
    "== $($t.Name): 실행 실패 =="
    "  $runError"
    @($out) | ForEach-Object { "  $_" }
  } elseif ($exit -ne 0 -or $hasFail) {
    $failedTests += $t.Name
    "== $($t.Name): 실패 (exit $exit) =="
    @($out) | ForEach-Object { "  $_" }
  } else {
    "== $($t.Name): 통과 =="
  }
}
''
$countMismatch = ($tests.Count -ne $expectedTestCount)
if ($countMismatch) {
  # ${} 필수 - PS 5.1 은 '$expectedTestCount개' 를 그 이름의 변수로 읽어 빈 값이 됩니다
  # (이 프로젝트의 대표 함정. 실증 중에 그대로 밟았습니다 - 2026-08-10 9차 점검)
  "[경고] 테스트 파일 개수가 기대와 다릅니다: 발견 $($tests.Count)개 / 기대 ${expectedTestCount}개"
  '        (테스트를 추가·삭제했다면 run_all_tests.ps1 의 $expectedTestCount 를 함께 고쳐 주세요.'
  '         고치지 않으면 파일이 사라져도 전부 통과로 끝납니다 - 9차 점검에서 막은 구멍입니다.)'
}
$badCount = $failedTests.Count + $erroredTests.Count
if ($badCount -gt 0 -or $countMismatch) {
  $parts = @()
  if ($failedTests.Count -gt 0) { $parts += "실패 $($failedTests.Count)개 - $($failedTests -join ', ')" }
  if ($erroredTests.Count -gt 0) { $parts += "실행 실패 $($erroredTests.Count)개 - $($erroredTests -join ', ')" }
  if ($countMismatch) { $parts += "개수 불일치($($tests.Count)/$expectedTestCount)" }
  "결과: $($tests.Count)개 중 $($parts -join ' / ')"
  exit 1
}
"결과: $($tests.Count)개 전부 통과"
exit 0
