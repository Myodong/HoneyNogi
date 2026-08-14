# GUI 로그 증분 읽기가 한글 경계·미완성 줄·파일 재생성을 안전하게 처리하는지 검사합니다.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'source_test_helpers.ps1')
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'mabinogi_gui.ps1'
Invoke-Expression ((Get-SourceFunctionDefinitions -Path $guiPath -Names @('Read-NewLogLines', 'Convert-WorkerLogLineForGui')) -join "`n")

$fails = 0
function Check-Equal {
  param([string]$Name, $Actual, $Expected)
  if ($Actual -eq $Expected) { "OK   $Name" }
  else { "FAIL $Name (actual=$Actual expected=$Expected)"; $script:fails++ }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ("honeynogi_log_tail_{0}.log" -f [guid]::NewGuid().ToString('N'))
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
try {
  $complete = $utf8Bom.GetBytes("첫 줄`r`n")
  $second = $utf8NoBom.GetBytes("둘째 줄`r`n")
  $partialLength = [Math]::Max(1, $second.Length - 2)
  $initial = New-Object byte[] ($complete.Length + $partialLength)
  [Array]::Copy($complete, 0, $initial, 0, $complete.Length)
  [Array]::Copy($second, 0, $initial, $complete.Length, $partialLength)
  [IO.File]::WriteAllBytes($temp, $initial)

  [long]$offset = 0
  $first = @(Read-NewLogLines -Path $temp -Offset ([ref]$offset))
  Check-Equal '완성된 첫 한글 줄만 반환' ($first -join '|') '첫 줄'
  Check-Equal '미완성 줄 앞까지만 오프셋 이동' $offset $complete.Length

  $stream = [IO.File]::Open($temp, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
  try { $stream.Write($second, $partialLength, ($second.Length - $partialLength)) }
  finally { $stream.Dispose() }
  $secondRead = @(Read-NewLogLines -Path $temp -Offset ([ref]$offset))
  Check-Equal '한글 바이트가 완성된 뒤 둘째 줄 반환' ($secondRead -join '|') '둘째 줄'
  $none = @(Read-NewLogLines -Path $temp -Offset ([ref]$offset))
  Check-Equal '이미 읽은 줄을 중복 반환하지 않음' $none.Count 0

  [IO.File]::WriteAllText($temp, "새 파일`r`n", $utf8Bom)
  $resetRead = @(Read-NewLogLines -Path $temp -Offset ([ref]$offset))
  Check-Equal '파일이 짧아지면 처음부터 다시 읽음' ($resetRead -join '|') '새 파일'
} finally {
  Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}

# ── 배열 풀림 계약 (2026-08-09 감사) ────────────────────────────────────────
# 위 케이스들은 전부 테스트가 **스스로 @() 로 감싸** 호출하고 있어, 호출부가 감싸지 않는
# 계약 위반을 원리상 검출할 수 없었습니다. 실제로 GUI 타이머의 두 호출부가 감싸지 않아
# 새 줄이 1줄뿐인 틱마다 그 줄이 통째로 사라지고 [완료] 사유 수집도 실패했습니다.
# 여기서는 (a) 감싸지 않으면 정말 문자열로 풀린다는 것과 (b) GUI 호출부가 감쌌다는 것을
# 각각 못 박습니다.
$temp2 = Join-Path ([IO.Path]::GetTempPath()) ("honeynogi_log_unroll_{0}.log" -f [guid]::NewGuid().ToString('N'))
try {
  # (1) 1줄 - PS 5.1 파이프라인에서 문자열로 풀립니다 (실사고 지점)
  [IO.File]::WriteAllText($temp2, "10:00:00 [던전] 한 줄`r`n", $utf8Bom)
  [long]$off2 = 0
  $rawOne = Read-NewLogLines -Path $temp2 -Offset ([ref]$off2)
  Check-Equal '풀림 계약: 1줄 반환은 감싸지 않으면 string' ($rawOne -is [string]) $true
  Check-Equal '풀림 계약: 감싸지 않은 인덱스는 첫 글자(사고 증상)' ([string]$rawOne[0]) '1'
  Check-Equal '풀림 계약: @() 로 감싸면 줄 1개' (@($rawOne).Count) 1
  Check-Equal '풀림 계약: @() 로 감싼 인덱스는 줄 전체' (@($rawOne)[0]) '10:00:00 [던전] 한 줄'

  # (2) 2줄 - 감싸지 않아도 배열 (그래서 이 사고가 1줄 틱에서만 조용히 났습니다)
  [IO.File]::WriteAllText($temp2, "10:00:00 첫 줄`r`n10:00:01 둘째 줄`r`n", $utf8Bom)
  [long]$off3 = 0
  $rawTwo = Read-NewLogLines -Path $temp2 -Offset ([ref]$off3)
  Check-Equal '풀림 계약: 2줄이면 감싸지 않아도 배열' ($rawTwo -is [object[]]) $true

  # (3) 0줄 - 호출을 직접 감싸면 0개 (변수에 담은 뒤 감싸면 @($null)=1 이 되므로 주의)
  [long]$off4 = 0
  Check-Equal '풀림 계약: 새 줄 없으면 감싼 결과 0개' `
    (@(Read-NewLogLines -Path $temp2 -Offset ([ref]$off3)).Count) 0
} finally {
  Remove-Item -LiteralPath $temp2 -Force -ErrorAction SilentlyContinue
}

$guiRaw = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
# 호출부 계약: 4곳(타이머의 기본/복구 로그 + 종료 마무리의 기본/복구 로그) 전부 @() 로
# 감싸야 합니다. 감사 당시 종료 마무리 2곳은 이미 감싸져 있었고 타이머 2곳만 빠져 있었습니다.
Check-Equal 'GUI: Read-NewLogLines 호출 4곳 모두 @() 로 감쌈' `
  ([regex]::Matches($guiRaw, '@\(Read-NewLogLines ').Count) 4
Check-Equal 'GUI: 감싸지 않은 Read-NewLogLines 대입 없음' `
  ([regex]::Matches($guiRaw, '=\s*Read-NewLogLines ').Count) 0
if ($guiRaw.Contains('\[설정\]|\[준비\]\s*게임 확인:\s*PID')) {
  'OK   회차별 게임 PID는 파일에만 남기고 GUI에서 숨김'
} else {
  'FAIL 회차별 게임 PID GUI 필터가 없습니다'
  $fails++
}
if ($guiRaw.Contains('^\[\d{4}-\d{2}-\d{2}\]\s*자동화 로그\s*\(시작')) {
  'OK   자동화 로그 날짜/시작 시각 머리글은 파일에만 남기고 GUI에서 숨김'
} else {
  'FAIL 자동화 로그 날짜/시작 시각 머리글 GUI 필터가 없습니다'
  $fails++
}
Check-Equal 'GUI: 숫자 단독 노이즈 줄 숨김' `
  (Convert-WorkerLogLineForGui '1' $false) $null
# 소멸 판정 계측은 화면 숨김·파일 보존 (2026-08-15 사용자 피드백 - [설정] 줄과 같은 방식)
Check-Equal 'GUI: 소멸 판정 계측 줄 숨김' `
  (Convert-WorkerLogLineForGui "12:00:00 [진단] 소멸 판정 1/3 - 좁은 'x' / 넓은 'y' / HUD 보임" $false) $null
Check-Equal 'GUI: 소멸 판정 근거 캡처 줄 숨김' `
  (Convert-WorkerLogLineForGui '12:00:00 [진단] 소멸 판정 근거 - 화면 캡처 저장: C:\x.png' $false) $null
Check-Equal 'GUI: 오류 경로 [진단] 줄은 계속 표시' `
  ([bool](Convert-WorkerLogLineForGui '12:00:00 [진단] 채집 대상 미발견 - 상세 영역 판독: ''x''' $false)) $true

$workerPath = Join-Path $root 'mabinogi_run_once.ps1'
$workerRaw = Get-Content -LiteralPath $workerPath -Raw -Encoding UTF8
Check-Equal '오류 이미지·로그가 동일한 시각 기본 이름 공유' `
  ($workerRaw.Contains('$diagBaseName = "error_$diagStamp"') -and
   $workerRaw.Contains('Join-Path $logDir "$diagBaseName.png"') -and
   $workerRaw.Contains('Join-Path $logDir "$diagBaseName.log"')) $true
$matchingNotice = "[안내] '커스텀 반복'은 설정과 무관하게 '우연한 만남'으로 진행합니다."
# 2026-07-28 심층던전 추가: 던전/심층 커스텀 시작 분기가 각각 1회씩 기록 (소스 2곳,
# 실행 시에는 카테고리별로 한 번만 출력됨)
Check-Equal '커스텀 매칭 안내는 GUI 시작 시 한 번만 기록' `
  ([regex]::Matches($guiRaw, [regex]::Escape($matchingNotice)).Count) 2
Check-Equal '커스텀 시작 안내에서 불필요한 던전 구분 설명 제거' `
  ($guiRaw.Contains("Add-GuiLog '[안내] 커스텀 반복: 시작 시 열어 둔 던전 하나에서 리스트 순서대로 동작합니다.'")) $true
Check-Equal '커스텀 시작 안내의 이전 괄호 문구 제거' `
  ($guiRaw.Contains('리스트 순서대로 동작합니다 (리스트에 던전 구분 없음).')) $false
Check-Equal '불필요한 커스텀 은동전 소모 시작 안내 제거' `
  ($guiRaw.Contains("Add-GuiLog '[안내] 커스텀 반복: 은동전 항목은 실제로 은동전이 소모됩니다.'")) $false
Check-Equal 'GUI 커스텀 시작 로그를 회차와 항목 번호 한 줄로 통합' `
  ($guiRaw.Contains('Add-GuiLog "=== ${cycleNumber}회차 시작($($customContext.Index + 1)/$($customContext.Total)) ==="')) $true
Check-Equal '이전 커스텀 항목 시작 별도 로그 제거' `
  ($guiRaw.Contains('Add-GuiLog "[커스텀] $($customContext.Position) 항목 시작"')) $false
Check-Equal '워커의 중복 커스텀 항목 시작 로그 제거' `
  ($workerRaw.Contains('Write-RunLog "[커스텀] $customPosLabel 항목 시작 -')) $false
Check-Equal '워커의 회차별 커스텀 매칭 안내 제거' `
  ($workerRaw.Contains('Write-RunLog "[커스텀] 매칭은 설정과 무관하게 ''우연한 만남''으로 진행합니다')) $false
# 2026-07-28 심층던전 추가: 시작 태그가 모드 변수([던전]/[심층] = $script:contentTag)로 바뀜
Check-Equal '던전 시작 로그는 간결한 항목 라벨과 매칭만 표시' `
  ($workerRaw.Contains('Write-RunLog "$($script:contentTag) 자동화 시작: $(Format-CustomItemLabel -Item $dungeonRunItem), 매칭 ''$ndMatching''"')) $true
Check-Equal '던전 선택 로그는 스테이지 대신 구역으로 표시' `
  ($workerRaw.Contains('Write-RunLog "[던전] 구역 $ndStage 선택 확인 (진입 버튼: ${stageFloor}층 ${stageArea}구역 진입)"')) $true
Check-Equal '던전 공물 소모량 확인 로그 간소화' `
  ($workerRaw.Contains('Write-RunLog "[던전] 공물 소모량 ${actualCost}개 확인"')) $true
Check-Equal '던전 우연한 만남 토글 끔 로그 간소화' `
  ($workerRaw.Contains('Write-RunLog "[던전] ''우연한 만남'' 토글 끔"')) $true
Check-Equal '원본 로그에서도 콘텐츠 단계 번호 제거' `
  ([regex]::Matches($workerRaw, '\[(?:던전|사냥터|어비스|파티원)\]\s*\d+\.').Count) 0

# 원본 파일 로그는 유지하면서 GUI에서만 숨기거나 요약하는 규칙을 실제 운영 함수로 검증합니다.
Check-Equal 'GUI: 우연한 만남 적용 성공 로그 숨김' `
  (Convert-WorkerLogLineForGui "10:00:00 [던전] '우연한 만남' 토글 켜짐 확인" $true) $null
Check-Equal 'GUI: 우연한 만남 실패 경고는 유지' `
  (Convert-WorkerLogLineForGui "10:00:00 [경고] '우연한 만남' 토글이 켜진 것을 확인하지 못했습니다" $true) `
  "10:00:00 [경고] '우연한 만남' 토글이 켜진 것을 확인하지 못했습니다"
Check-Equal 'GUI: 난이도 클릭 세부 로그 숨김' `
  (Convert-WorkerLogLineForGui "10:00:00 [던전] 난이도 '어려움' 클릭" $true) $null
Check-Equal 'GUI: 구역 선택 확인은 유지' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 구역 1-2 선택 확인' $true) `
  '10:00:00 [던전] 구역 1-2 선택 확인'
Check-Equal 'GUI: 카드별 설정 성공 로그 숨김' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 은동전(소탕) = 사용(선택됨) 확인' $true) $null
Check-Equal 'GUI: 최종 공물 소모량 확인은 유지' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 공물 소모량 20개 확인' $true) `
  '10:00:00 [던전] 공물 소모량 20개 확인'
Check-Equal 'GUI: 입장하기 클릭만 숨김' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 입장하기 클릭' $true) $null
Check-Equal 'GUI: 입장 완료는 유지' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 던전 입장 완료 감지' $true) `
  '10:00:00 [던전] 던전 입장 완료 감지'
Check-Equal 'GUI: 클리어 대기 세부 로그 숨김' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 던전 클리어 화면 감지 대기 시작' $true) $null
Check-Equal 'GUI: 클리어 동작을 완료 요약으로 변환' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 던전 클리어 - 화면 터치' $true) `
  '10:00:00 [던전] 클리어 완료'
Check-Equal 'GUI: 결과 화면 상세를 확인 요약으로 변환' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 결과 화면 확인 (나가기 / 다시 하기)' $true) `
  '10:00:00 [던전] 결과 화면 확인'
Check-Equal 'GUI: 커스텀 완료 마커 내부 로그 숨김' `
  (Convert-WorkerLogLineForGui '10:00:00 [커스텀] 완료 마커 기록 (결과 화면 도달)' $true) $null
Check-Equal 'GUI: 비커스텀 워커 회차 완료 내용 유지' `
  (Convert-WorkerLogLineForGui '10:00:00 [던전] 다시 하기 → 옵션 화면 복귀 - 회차 완료' $false) `
  '10:00:00 [던전] 다시 하기 → 옵션 화면 복귀 - 회차 완료'
Check-Equal 'GUI: 커스텀 복구 세부 로그 숨김' `
  (Convert-WorkerLogLineForGui '10:00:00 [커스텀] 1바퀴째 1/5번 완료 항목 마무리 복구 - 어려움 1-2' $true) $null

# ── 진단 꼬리 제거 (2026-08-11 사용자 요청) - 파일 원본은 그대로, 화면 표시에서만 지움 ──
# 아래는 전부 당일 실사용/실측 로그의 원문입니다 (재현 가능한 자산)
Check-Equal 'GUI: Y= 꼬리 제거' `
  (Convert-WorkerLogLineForGui "15:52:51 [생활] '굵은 나무' 이 현재 화면에 있어 스크롤 없이 선택합니다 (Y=575, 근거 text)" $false) `
  "15:52:51 [생활] '굵은 나무' 이 현재 화면에 있어 스크롤 없이 선택합니다"
Check-Equal 'GUI: 링크 탐색 꼬리 제거 - 중간 괄호(제목)는 보존' `
  (Convert-WorkerLogLineForGui "15:52:53 [생활] 대상 '굵은 나무' 상세 확인 (제목 '굵은나무') - '가까운 위치 찾기' 클릭 (링크 탐색 530,390)" $false) `
  "15:52:53 [생활] 대상 '굵은 나무' 상세 확인 (제목 '굵은나무') - '가까운 위치 찾기' 클릭"
Check-Equal 'GUI: 판독 꼬리 제거' `
  (Convert-WorkerLogLineForGui '15:52:40 [생활] 목록이 이미 최상단입니다 - 정렬 생략 (판독: 나무베기|벌목도끼로나무를베어)' $false) `
  '15:52:40 [생활] 목록이 이미 최상단입니다 - 정렬 생략'
Check-Equal 'GUI: 표본 꼬리 제거 (경고 문구에도 적용)' `
  (Convert-WorkerLogLineForGui "15:41:54 [경고] 난이도 '어려움' 선택 강조를 확인하지 못했습니다 - 현재 상태로 진행합니다 (표본: 기준(721,121) 0/27 [-18:56/7])" $false) `
  "15:41:54 [경고] 난이도 '어려움' 선택 강조를 확인하지 못했습니다 - 현재 상태로 진행합니다"
Check-Equal 'GUI: 화면좌표 꼬리 제거' `
  (Convert-WorkerLogLineForGui '15:00:00 [어비스] 어비스 메뉴 클릭 (글자 탐색 화면좌표 971,531)' $false) `
  '15:00:00 [어비스] 어비스 메뉴 클릭'
Check-Equal 'GUI: 순서 추정(Y=) 꼬리 제거' `
  (Convert-WorkerLogLineForGui "12:00:13 [생활] '거미줄 뭉치' 행을 목록 순서로 추정했습니다 (Y=680 - 이름 판독 실패 보완)" $false) `
  "12:00:13 [생활] '거미줄 뭉치' 행을 목록 순서로 추정했습니다"
Check-Equal 'GUI: 진단 아닌 끝 괄호는 보존 (사용자 안내 문구)' `
  (Convert-WorkerLogLineForGui '15:00:00 [완료] 채집 1사이클 완료 - 나무 베기 / 굵은 나무 10개 (이번 사이클은 회차로 세지 않음)' $false) `
  '15:00:00 [완료] 채집 1사이클 완료 - 나무 베기 / 굵은 나무 10개 (이번 사이클은 회차로 세지 않음)'
Check-Equal 'GUI: 커스텀 완료는 위치 포함 한 줄' `
  ($guiRaw.Contains('Add-GuiLog "[커스텀] $($finishedContext.Position) 항목 완료"')) $true
Check-Equal 'GUI: 커스텀 복구 시작 문구 통일' `
  ([regex]::Matches($guiRaw, [regex]::Escape("Add-GuiLog '[커스텀] 이전 완료 항목의 마무리를 복구합니다.'")).Count) 2
Check-Equal 'GUI: 커스텀 복구 완료 문구 통일' `
  ($guiRaw.Contains("Add-GuiLog '[커스텀] 마무리 복구 완료 - 다음 항목으로 진행합니다.'")) $true
exit $fails
