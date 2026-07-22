# config 좌표 배열/정수 범위 검증 - 워커 본체 함수를 직접 실행합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
foreach ($definition in Get-SourceFunctionDefinitions -Path (Join-Path $root 'mabinogi_run_once.ps1') `
    -Names @('Add-ConfigValidationWarning', 'Resolve-ConfigCoordinateArray',
      'Get-ConfigValue', 'Resolve-ConfigInteger', 'Get-ConfigInteger',
      'Resolve-ConfigBoolean', 'Get-ConfigBoolean')) {
  Invoke-Expression $definition
}

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

$script:configValidationWarnings = @()
$script:configCoordinateWidth = 1272
$script:configCoordinateHeight = 717

Assert-Case '좌표: 정상 점' ((@(Resolve-ConfigCoordinateArray @(100,200) @(1,2) point 'p' 1272 717)) -join ',') '100,200'
Assert-Case '좌표: 개수 부족은 기본값' ((@(Resolve-ConfigCoordinateArray @(100) @(1,2) point 'p1' 1272 717)) -join ',') '1,2'
Assert-Case '좌표: 숫자 문자열은 기본값' ((@(Resolve-ConfigCoordinateArray @('100',200) @(3,4) point 'p2' 1272 717)) -join ',') '3,4'
Assert-Case '좌표: 화면 밖 점은 기본값' ((@(Resolve-ConfigCoordinateArray @(1273,200) @(5,6) point 'p3' 1272 717)) -join ',') '5,6'
Assert-Case '영역: 정상 영역' ((@(Resolve-ConfigCoordinateArray @(0,0,1272,717) @(1,2,3,4) region 'r' 1272 717)) -join ',') '0,0,1272,717'
Assert-Case '영역: 폭 0은 기본값' ((@(Resolve-ConfigCoordinateArray @(10,10,0,20) @(1,2,3,4) region 'r1' 1272 717)) -join ',') '1,2,3,4'
Assert-Case '영역: 우측 경계 초과는 기본값' ((@(Resolve-ConfigCoordinateArray @(1200,10,100,20) @(5,6,7,8) region 'r2' 1272 717)) -join ',') '5,6,7,8'

$cfg = [pscustomobject]@{
  clickPoints = [pscustomobject]@{ good = @(50,60); bad = @(1) }
  ocrRegions = [pscustomobject]@{ good = @(10,20,30,40); bad = @(-1,20,30,40) }
  timeoutsSeconds = [pscustomobject]@{ ok = 30; negative = -1; text = '30'; fraction = 1.5 }
  flags = [pscustomobject]@{ on = $true; off = $false; textFalse = 'false'; number = 0 }
}
Assert-Case 'Get-ConfigValue: 정상 클릭 좌표' ((@(Get-ConfigValue $cfg @('clickPoints','good') @(9,9))) -join ',') '50,60'
Assert-Case 'Get-ConfigValue: 손상 클릭 좌표 폴백' ((@(Get-ConfigValue $cfg @('clickPoints','bad') @(9,9))) -join ',') '9,9'
Assert-Case 'Get-ConfigValue: 정상 OCR 영역' ((@(Get-ConfigValue $cfg @('ocrRegions','good') @(9,9,9,9))) -join ',') '10,20,30,40'
Assert-Case 'Get-ConfigValue: 손상 OCR 영역 폴백' ((@(Get-ConfigValue $cfg @('ocrRegions','bad') @(9,9,9,9))) -join ',') '9,9,9,9'
Assert-Case '정수: 정상 범위' (Get-ConfigInteger $cfg @('timeoutsSeconds','ok') 15 1 600) 30
Assert-Case '정수: 음수 폴백' (Get-ConfigInteger $cfg @('timeoutsSeconds','negative') 15 1 600) 15
Assert-Case '정수: 문자열 폴백' (Get-ConfigInteger $cfg @('timeoutsSeconds','text') 15 1 600) 15
Assert-Case '정수: 소수 폴백' (Get-ConfigInteger $cfg @('timeoutsSeconds','fraction') 15 1 600) 15
Assert-Case '정수: Int32 초과도 예외 없이 폴백' `
  (Resolve-ConfigInteger ([double]::MaxValue) 15 1 600 'huge') 15
Assert-Case '불리언: true 유지' (Get-ConfigBoolean $cfg @('flags','on') $false) $true
Assert-Case '불리언: false 유지' (Get-ConfigBoolean $cfg @('flags','off') $true) $false
Assert-Case '불리언: 문자열 false를 참으로 오인하지 않고 폴백' `
  (Get-ConfigBoolean $cfg @('flags','textFalse') $false) $false
Assert-Case '불리언: 숫자를 불리언으로 오인하지 않고 폴백' `
  (Get-ConfigBoolean $cfg @('flags','number') $true) $true
Assert-Case '경고: 손상 값 기록됨' ($script:configValidationWarnings.Count -ge 11) $true

# 사용자 편집 가능 설정은 원시 형 변환을 우회하지 않는다는 호출부 계약도 함께 고정합니다.
$workerSource = Get-Content -LiteralPath (Join-Path $root 'mabinogi_run_once.ps1') -Raw -Encoding UTF8
Assert-Case '호출부: Get-ConfigValue 직접 int 변환 없음' `
  ([regex]::Matches($workerSource, '\[int\]\s*\(\s*Get-ConfigValue').Count) 0
Assert-Case '호출부: Get-ConfigValue 직접 bool 변환 없음' `
  ([regex]::Matches($workerSource, '\[bool\]\s*\(\s*Get-ConfigValue').Count) 0
Assert-Case '호출부: afterEntry enabled 직접 bool 변환 없음' `
  ([regex]::Matches($workerSource, '\[bool\]\s*\$entry\.enabled').Count) 0

exit $fails
