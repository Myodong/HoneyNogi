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
# 호출부 계약: 4곳(타이머 통상 tail 의 기본/복구 로그 + 종료 처리 공통 최종 수집 Invoke-ExitLogFinalCollect 의 기본/복구 로그) 전부
# @() 로 감싸야 합니다. 감사 당시 종료 마무리 2곳은 이미 감싸져 있었고 타이머 2곳만 빠져 있었습니다. 원문(주석 포함)을 세므로 GUI 의
# 새 주석에는 그 호출 조각을 쓰지 않습니다 (구현 명세 ① 2.0 체크리스트 11).
Check-Equal 'GUI: Read-NewLogLines 호출 4곳 모두 @() 로 감쌈 (2026-09-25 코드 10 분기의 잔여 수집 추가로 4→5, 복구 로그 수집 추가로 6, 2026-10-09 코드 10·코드 4 사본을 공통 최종 수집의 출처별 2곳으로 합쳐 4)' `
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
# [진단] 줄은 전체 화면 숨김·파일 보존 (2026-08-15 사용자 피드백 2회 - 소멸 판정 한정에서
# 확대. 화면에는 [오류]/[경고]/[완료] 요약이 남는다)
Check-Equal 'GUI: 소멸 판정 계측 줄 숨김' `
  (Convert-WorkerLogLineForGui "12:00:00 [진단] 소멸 판정 1/3 - 좁은 'x' / 넓은 'y' / HUD 보임" $false) $null
Check-Equal 'GUI: 소멸 판정 근거 캡처 줄 숨김' `
  (Convert-WorkerLogLineForGui '12:00:00 [진단] 소멸 판정 근거 - 화면 캡처 저장: C:\x.png' $false) $null
Check-Equal 'GUI: 오류 경로 [진단] 줄도 숨김 (2026-08-15 계약 반전)' `
  (Convert-WorkerLogLineForGui '12:00:00 [진단] 채집 대상 미발견 - 상세 영역 판독: ''x''' $false) $null
Check-Equal 'GUI: 메시지 중간에 인용된 [진단] 문자열은 숨기지 않음 (태그 앵커링)' `
  ([bool](Convert-WorkerLogLineForGui '12:00:00 [오류] 어떤 문제 - 자세한 내용은 [진단] 줄 참고' $false)) $true
Check-Equal 'GUI: 오류/완료 요약 줄은 계속 표시' `
  ([bool](Convert-WorkerLogLineForGui '12:00:00 [완료] 채집 대상 미발견 - 조건부 정지' $false)) $true

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
# v2.1.6 태그 동적화 전수 가드: Write-RunLog 의 '[던전]' 리터럴 태그는 0곳이어야 한다
# (공용 흐름 76곳 일괄 전환 - 새 로그가 리터럴로 들어오면 심층 회차에 [던전]으로 찍히는
# 회귀. LogTag 기본값·태그 판정식·contentTag 대입은 Write-RunLog 가 아니라 안 걸림)
Check-Equal '워커: Write-RunLog [던전] 리터럴 잔존 0곳' `
  ([regex]::Matches($workerRaw, 'Write-RunLog\s+["'']\[던전\]').Count) 0
# LogTag/LogPrefix 파라미터로 리터럴이 재유입되는 변이도 차단 (Codex 지적 - 위 가드의 사각)
Check-Equal '워커: -LogTag/-LogPrefix [던전] 리터럴 잔존 0곳' `
  ([regex]::Matches($workerRaw, "-Log(Tag|Prefix)\s+'\[던전\]").Count) 0
# v2.1.6 태그 동적화: 아래 3곳도 [던전] 리터럴 → $script:contentTag (심층 [심층] 교정)
Check-Equal '던전 선택 로그는 스테이지 대신 구역으로 표시' `
  ($workerRaw.Contains('Write-RunLog "$($script:contentTag) 구역 $ndStage 선택 확인 (진입 버튼: ${stageFloor}층 ${stageArea}구역 진입)"')) $true
Check-Equal '던전 공물 소모량 확인 로그 간소화' `
  ($workerRaw.Contains('Write-RunLog "$($script:contentTag) 공물 소모량 ${actualCost}개 확인"')) $true
Check-Equal '던전 우연한 만남 토글 끔 로그 간소화' `
  ($workerRaw.Contains('Write-RunLog "$($script:contentTag) ''우연한 만남'' 토글 끔"')) $true
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

# ── v2.1.6 태그 동적화 (2026-09-07): 심층 회차가 공용 흐름에서 [심층] 태그로 찍히게 되어
# GUI 생략/요약 필터도 두 태그를 받는다 - 요약 반환은 매치된 태그를 그대로 따라야 한다 ──
Check-Equal 'GUI: 심층 - 클리어 동작을 완료 요약으로 변환(태그 보존)' `
  (Convert-WorkerLogLineForGui '10:00:00 [심층] 던전 클리어 - 화면 터치' $true) `
  '10:00:00 [심층] 클리어 완료'
Check-Equal 'GUI: 심층 - 결과 화면 상세를 확인 요약으로 변환(태그 보존)' `
  (Convert-WorkerLogLineForGui '10:00:00 [심층] 결과 화면 확인 (나가기 / 다시 하기)' $true) `
  '10:00:00 [심층] 결과 화면 확인'
Check-Equal 'GUI: 심층 - 마족공물 카드 설정 성공 로그 숨김' `
  (Convert-WorkerLogLineForGui '10:00:00 [심층] 마족공물(소탕) = 미사용(도전) 확인' $true) $null
Check-Equal 'GUI: 심층 - 입장하기 클릭 숨김' `
  (Convert-WorkerLogLineForGui '10:00:00 [심층] 입장하기 클릭' $true) $null
Check-Equal 'GUI: 심층 - 비커스텀 회차 완료 내용 유지' `
  (Convert-WorkerLogLineForGui '10:00:00 [심층] 다시 하기 → 옵션 화면 복귀 - 회차 완료' $false) `
  '10:00:00 [심층] 다시 하기 → 옵션 화면 복귀 - 회차 완료'

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
# ESC 메뉴 '어비스' 아이콘 폴백 (2026-10-07 설계 v2 6.1 - 워커 문구 그대로, 수치는 설계 부록 V-2 의 P1 표본·실기 전이라 실로그 원문이 아님).
# 클릭 줄의 탐색 출처가 '아이콘 탐색' 이 되고, 찾음·미발견 줄은 ' (판독: ' 꼬리를 붙입니다 - 미발견 줄은 첫 ' (' 가 ' (3)' 이라
# 키워드가 아니므로 다음 ' (판독: ' 부터 지워져 '재시도 (3)' 이 남아야 합니다 (GUI 키워드 '아이콘 탐색 ' 을 지우면 첫 예시가 실패 - 변이 V16)
Check-Equal 'GUI: 아이콘 탐색 화면좌표 꼬리 제거' `
  (Convert-WorkerLogLineForGui '15:00:00 [어비스] 어비스 메뉴 클릭 (아이콘 탐색 화면좌표 1621,392)' $false) `
  '15:00:00 [어비스] 어비스 메뉴 클릭'
Check-Equal 'GUI: 아이콘 찾음 줄의 판독 꼬리 제거 (필드 확정 때 추적기·메뉴 판정 신호 포함)' `
  (Convert-WorkerLogLineForGui "15:00:00 [어비스] 메뉴의 '어비스' 글자가 읽히지 않아 아이콘으로 찾았습니다 (판독: 일치도 0.913, 2등 0.500, 크기 30, 아이콘 중심 975,363, 창 1272x717·DPI 96, 0.60초 - 첫 사용 준비 포함, 필드 확정 때 추적기 '[주간목표]모험가길드의정기의뢰(2)', 메뉴 판정 신호 exit-label)" $false) `
  "15:00:00 [어비스] 메뉴의 '어비스' 글자가 읽히지 않아 아이콘으로 찾았습니다"
Check-Equal 'GUI: 미발견 줄의 아이콘 판독 꼬리 제거 - 재시도 횟수 괄호는 보존' `
  (Convert-WorkerLogLineForGui "15:00:00 [어비스] 메뉴에서 '어비스' 글자를 찾지 못했습니다 - 재시도 (3) (판독: 아이콘 일치도 0.612, 2등 0.590, 크기 28 - 기준 미달, 창 1272x717·DPI 96)" $false) `
  "15:00:00 [어비스] 메뉴에서 '어비스' 글자를 찾지 못했습니다 - 재시도 (3)"
Check-Equal "GUI: 미발견 줄의 '아이콘 탐색 안 함' 꼬리 제거 (1차 신호 회전 - 재시도 횟수 괄호는 보존)" `
  (Convert-WorkerLogLineForGui "15:00:00 [어비스] 메뉴에서 '어비스' 글자를 찾지 못했습니다 - 재시도 (3) (판독: 아이콘 탐색 안 함 - 메뉴 판정에서 '어비스' 글자 조각이 읽힌 회전)" $false) `
  "15:00:00 [어비스] 메뉴에서 '어비스' 글자를 찾지 못했습니다 - 재시도 (3)"
Check-Equal 'GUI: 순서 추정(Y=) 꼬리 제거' `
  (Convert-WorkerLogLineForGui "12:00:13 [생활] '거미줄 뭉치' 행을 목록 순서로 추정했습니다 (Y=680 - 이름 판독 실패 보완)" $false) `
  "12:00:13 [생활] '거미줄 뭉치' 행을 목록 순서로 추정했습니다"

# ── 클릭 지점 '기준좌표 (x,y)' 꼬리 제거 (2026-10-02 사용자 요청) - 파일 원본은 그대로, 화면에서만 지움 ──
# 실사용/실기 로그 원문 (첫 줄 = 사용자 제보 원문)
Check-Equal 'GUI: 글자 탐색 기준좌표 꼬리 제거 (어비스 나가기 - 사용자 제보 원문)' `
  (Convert-WorkerLogLineForGui '09:24:25 [어비스] 나가기 클릭 - 글자 탐색 기준좌표 (491,662)' $false) `
  '09:24:25 [어비스] 나가기 클릭'
Check-Equal 'GUI: 글자 탐색 기준좌표 꼬리 제거 (파티원 나가기)' `
  (Convert-WorkerLogLineForGui '21:05:20 [파티원] 나가기 클릭 - 글자 탐색 기준좌표 (515,654)' $false) `
  '21:05:20 [파티원] 나가기 클릭'
Check-Equal "GUI: 괄호 안 기준좌표만 제거하고 횟수는 보존 ('입장 대기 중' 다시 펼침)" `
  (Convert-WorkerLogLineForGui "20:47:30 [파티원] 접힌 준비 패널 다시 펼침 - '입장 대기 중' 클릭 (1/2, 기준좌표 (743,654))" $false) `
  "20:47:30 [파티원] 접힌 준비 패널 다시 펼침 - '입장 대기 중' 클릭 (1/2)"
# 과잉 제거 방지: 좌표 숫자가 없는 '예비 좌표' 안내(실로그 원문)는 그대로, 줄 끝이 아닌 기준좌표(근접 변형 -
# 끝 앵커·괄호 닫힘 조건을 지키는지)도 그대로
Check-Equal 'GUI: 예비 좌표 안내는 보존' `
  (Convert-WorkerLogLineForGui '15:08:27 [커스텀] 구역 1-1 카드 클릭 - 예비 좌표 (시도 1/3)' $false) `
  '15:08:27 [커스텀] 구역 1-1 카드 클릭 - 예비 좌표 (시도 1/3)'
Check-Equal 'GUI: 줄 끝이 아닌 기준좌표 꼬리는 보존 (근접 변형)' `
  (Convert-WorkerLogLineForGui '12:00:00 [어비스] 나가기 클릭 - 글자 탐색 기준좌표 (1,2) 후속문구' $false) `
  '12:00:00 [어비스] 나가기 클릭 - 글자 탐색 기준좌표 (1,2) 후속문구'
Check-Equal 'GUI: 괄호가 줄 끝에서 닫히지 않는 기준좌표는 보존 (근접 변형)' `
  (Convert-WorkerLogLineForGui '12:00:00 [파티원] 다시 펼침 (1/2, 기준좌표 (1,2)) 후속문구' $false) `
  '12:00:00 [파티원] 다시 펼침 (1/2, 기준좌표 (1,2)) 후속문구'

# 워커 소스 전수 가드: '기준좌표' 를 담은 워커 문자열을 AST 로 모두 찾아 정확히 아래 4곳의 Write-RunLog 첫 인자인지,
# 소속 함수와 템플릿이 그대로인지 고정하고, 표본 값으로 펼친 원문(필터 전)과 화면 표시(필터 뒤)를 둘 다 정확
# 일치로 단언합니다 - 실측이 없는 모양(퇴장 절차의 패널 다시 펼침)도 소스에서 잡고, 새 정적 '기준좌표' 문자열이
# 생기거나 문구·따옴표·변수 이름이 바뀌면 여기서 실패합니다 (그때는 화면 표시를 다시 확인한 뒤 기대값을 갱신할 것).
# 철자를 바꾸거나('기준 좌표') 문자열을 나눠 조립한 새 좌표 꼬리는 못 잡으니, 그런 문구를 새로 찍으면 이 목록과
# GUI 필터를 함께 손볼 것.
$workerParseErrors = $null
$workerAst = [System.Management.Automation.Language.Parser]::ParseFile($workerPath, [ref]$null, [ref]$workerParseErrors)
Check-Equal '워커: 파서 오류 0건 (기준좌표 가드 전제)' (@($workerParseErrors).Count) 0
$coordExpected = @(
  @{ Function = 'Invoke-AbyssExitClick'
     Template = '$LogPrefix $Context - 글자 탐색 기준좌표 ($($read.Point.X),$($read.Point.Y))' }
  @{ Function = 'Invoke-AbyssMemberLeave'
     Template = '[파티원] 나가기 클릭 - 글자 탐색 기준좌표 ($($leaveWord.X),$($leaveWord.Y))' }
  @{ Function = 'Invoke-AbyssMemberLeave'
     Template = '[파티원] 접힌 준비 패널 다시 펼침(퇴장 절차 - 준비 상태 확인, ${probeSends}/2) - 기준좌표 ($($probeAnchor.X),$($probeAnchor.Y))' }
  @{ Function = 'Invoke-AbyssPartyMemberCycle'
     Template = '[파티원] 접힌 준비 패널 다시 펼침 - ''입장 대기 중'' 클릭 (${reexpandSends}/2, 기준좌표 ($($reexpandAnchor.X),$($reexpandAnchor.Y)))' }
)
$coordNodes = @($workerAst.FindAll({ param($node)
      ($node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
       $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -and
      $node.Value.Contains('기준좌표') }, $true))
$coordActual = @(foreach ($coordNode in $coordNodes) {
    $owner = $coordNode.Parent
    $isFirstArg = ($owner -is [System.Management.Automation.Language.CommandAst] -and
                   $owner.GetCommandName() -eq 'Write-RunLog' -and $owner.CommandElements.Count -ge 2 -and
                   [object]::ReferenceEquals($owner.CommandElements[1], $coordNode))
    $ownerFunction = $coordNode.Parent
    while ($ownerFunction -and -not ($ownerFunction -is [System.Management.Automation.Language.FunctionDefinitionAst])) {
      $ownerFunction = $ownerFunction.Parent
    }
    $ownerName = $(if ($ownerFunction) { $ownerFunction.Name } else { '(최상위)' })
    '{0}|{1}|{2}' -f $isFirstArg, $ownerName, $coordNode.Extent.Text
  })
# 소스 토큰 원문(Extent.Text)으로 비교합니다 - .Value 는 바깥 따옴표("…"/'…')나 `$ 이스케이프가 달라도 같게 나와
# 확장 여부가 바뀐 변이를 놓칩니다 (구현 리뷰 P2). 네 곳 모두 큰따옴표 확장 문자열입니다.
$coordWant = @(foreach ($coordItem in $coordExpected) { 'True|{0}|"{1}"' -f $coordItem.Function, $coordItem.Template })
Check-Equal "워커: '기준좌표' 문자열 = Write-RunLog 첫 인자 4곳 (소속 함수·템플릿 그대로)" `
  ((@($coordActual) | Sort-Object) -join "`n") ((@($coordWant) | Sort-Object) -join "`n")
$read = @{ Point = @{ X = 491; Y = 662 } }
$leaveWord = @{ X = 515; Y = 654 }
$probeSends = 1
$probeAnchor = @{ X = 743; Y = 654 }
$reexpandSends = 2
$reexpandAnchor = @{ X = 0; Y = 0 }   # 좌표는 0 이상 정수 - (0,0) 도 지워져야 함
$coordRenderCases = @(
  @{ Index = 0; LogPrefix = '[어비스]'; Context = '나가기 클릭'
     Raw = '[어비스] 나가기 클릭 - 글자 탐색 기준좌표 (491,662)'
     Shown = '[어비스] 나가기 클릭' }
  @{ Index = 0; LogPrefix = '[어비스]'; Context = '나가기 클릭 (복구 재시도)'
     Raw = '[어비스] 나가기 클릭 (복구 재시도) - 글자 탐색 기준좌표 (491,662)'
     Shown = '[어비스] 나가기 클릭 (복구 재시도)' }
  @{ Index = 1; LogPrefix = ''; Context = ''
     Raw = '[파티원] 나가기 클릭 - 글자 탐색 기준좌표 (515,654)'
     Shown = '[파티원] 나가기 클릭' }
  @{ Index = 2; LogPrefix = ''; Context = ''
     Raw = '[파티원] 접힌 준비 패널 다시 펼침(퇴장 절차 - 준비 상태 확인, 1/2) - 기준좌표 (743,654)'
     Shown = '[파티원] 접힌 준비 패널 다시 펼침(퇴장 절차 - 준비 상태 확인, 1/2)' }
  @{ Index = 3; LogPrefix = ''; Context = ''
     Raw = '[파티원] 접힌 준비 패널 다시 펼침 - ''입장 대기 중'' 클릭 (2/2, 기준좌표 (0,0))'
     Shown = '[파티원] 접힌 준비 패널 다시 펼침 - ''입장 대기 중'' 클릭 (2/2)' }
)
foreach ($coordCase in $coordRenderCases) {
  $LogPrefix = $coordCase.LogPrefix
  $Context = $coordCase.Context
  $coordRendered = $ExecutionContext.InvokeCommand.ExpandString($coordExpected[$coordCase.Index].Template)
  Check-Equal ('워커 템플릿 펼침: {0}' -f $coordCase.Raw) $coordRendered $coordCase.Raw
  Check-Equal ('GUI: 기준좌표 꼬리 제거 (소스 템플릿): {0}' -f $coordCase.Shown) `
    (Convert-WorkerLogLineForGui ('12:00:00 ' + $coordRendered) $false) ('12:00:00 ' + $coordCase.Shown)
}

# ── 좌표·개발자 메모 정리 2차 (2026-10-02 사용자 확정) - 파일 원본은 그대로, 화면에서만 정리 ──
# ① 닫기(X) 후보 좌표 ② '(호출부가 오류 처리…)' ③ 커서 대피 실패의 좌표·반복 안내(+ 클릭 보류·목록 스크롤 좌표)
# ④ 게임 창 정보의 위치 ⑤ 게임 창 정렬 → 크기 조정/위치 조정. 전부 실사용·실기 로그 원문이고, 앞 11줄은 바뀌는 줄,
# 뒤 3줄은 같은 낱말('목표'·'연속 실패 중에는 …'·'호출부')이 든 다른 문구라 그대로여야 하는 줄입니다.
$tidyRealCases = @(
  @('22:19:26 [안내] 알 수 없는 화면 - 닫기(X) 후보(1229,67) 클릭 시도 (15/20)',
    '22:19:26 [안내] 알 수 없는 화면 - 닫기(X) 클릭 시도 (15/20)'),
  @('22:17:50 [안내] 복귀 중 알 수 없는 화면 20초 지속 - 닫기(X) 후보(1229,67) 클릭',
    '22:17:50 [안내] 복귀 중 알 수 없는 화면 20초 지속 - 닫기(X) 클릭'),
  @("09:06:35 [경고] 난이도 '어려움' 선택 강조를 확인하지 못했습니다 (호출부가 오류 처리, 표본: 기준(80,195) 2/27 [-18:66/44 -14:95/66 -10:112/79 -6:221/160 0:82/56 6:123/86 10:20/15 14:19/13 18:16/11])",
    "09:06:35 [경고] 난이도 '어려움' 선택 강조를 확인하지 못했습니다"),
  @("19:43:32 [경고] 옵션 화면에서 난이도 '어려움' 글자를 3회 모두 찾지 못했습니다 (호출부가 오류 처리)",
    "19:43:32 [경고] 옵션 화면에서 난이도 '어려움' 글자를 3회 모두 찾지 못했습니다"),
  @('22:13:29 [경고] 커서 대피 실패: SetCursorPos 가 먹지 않음 - 커서가 이동 전 자리(1153,954)에 그대로입니다 - 팝업 글자가 커서에 가려질 수 있습니다 (연속 실패 중에는 이 경고를 반복하지 않습니다)',
    '22:13:29 [경고] 커서 대피 실패: SetCursorPos 가 먹지 않음 - 커서가 이동 전 자리에 그대로입니다 - 팝업 글자가 커서에 가려질 수 있습니다'),
  @('11:19:29 [경고] 커서 대피 실패: GetCursorPos 실패 (커서 밑 창 확인 단계) - 팝업 글자가 커서에 가려질 수 있습니다 (연속 실패 중에는 이 경고를 반복하지 않습니다)',
    '11:19:29 [경고] 커서 대피 실패: GetCursorPos 실패 (커서 밑 창 확인 단계) - 팝업 글자가 커서에 가려질 수 있습니다'),
  @('17:43:00 [준비] 게임 창 정보: 1272x717@(645,7), 클라이언트 1256x678, 제목줄·테두리 39px, 창 DPI 96, 모니터 DPI 96 (100%)',
    '17:43:00 [준비] 게임 창 정보: 1272x717, 클라이언트 1256x678, 제목줄·테두리 39px, 창 DPI 96, 모니터 DPI 96 (100%)'),
  @('23:15:36 [준비] 게임 창 정렬(nearest): 1243x702@(1326,706) -> 1272x717@(1288,675)',
    '23:15:36 [준비] 게임 창 크기 조정: 1243x702 -> 1272x717'),
  @('23:42:54 [준비] 게임 창 정렬(nearest): 1038x717@(-7,10) -> 1024x577@(0,10)',
    '23:42:54 [준비] 게임 창 크기 조정: 1038x717 -> 1024x577'),
  @('02:45:47 [준비] 게임 창 정렬(nearest): 1272x717@(-11,2) -> 1272x717@(0,2)',
    '02:45:47 [준비] 게임 창 위치 조정: 1272x717'),
  @('01:00:34 [준비] 게임 창 정렬(nearest): 1273x718@(648,15) -> 1273x718@(647,15)',
    '01:00:34 [준비] 게임 창 위치 조정: 1273x718'),
  @('21:27:08 [기타] 고양이 상인 - 냥코인 뽑기 시작 (목표 99,999,998개 / 골드 상한 20,000)',
    '21:27:08 [기타] 고양이 상인 - 냥코인 뽑기 시작 (목표 99,999,998개 / 골드 상한 20,000)'),
  @('15:15:45 [완료] 목표 냥코인 도달 - 잔량 10,089,217개 (목표 10,000,000개, 구매 110회)',
    '15:15:45 [완료] 목표 냥코인 도달 - 잔량 10,089,217개 (목표 10,000,000개, 구매 110회)'),
  @('09:44:30 [경고] 게임 창 전면화를 두 번 시도했지만 실제 전면 루트 창으로 확인되지 않았습니다 - 입력 여부는 호출부가 결정합니다 (검증 입력은 건너뛰고, 그 외에는 기존대로 진행. 연속 실패 중에는 이 경고를 반복하지 않습니다)',
    '09:44:30 [경고] 게임 창 전면화를 두 번 시도했지만 실제 전면 루트 창으로 확인되지 않았습니다 - 입력 여부는 호출부가 결정합니다 (검증 입력은 건너뛰고, 그 외에는 기존대로 진행. 연속 실패 중에는 이 경고를 반복하지 않습니다)')
)
foreach ($tidyCase in $tidyRealCases) {
  Check-Equal ('GUI 정리(실로그): {0}' -f $tidyCase[1]) (Convert-WorkerLogLineForGui $tidyCase[0] $false) $tidyCase[1]
}
# 근접 변형 - 그대로여야 함: ③ 의 세 안쪽 패턴이 다 들어 있지만 커서 대피 줄이 아닌 줄(태그 위치 가드), 다른 줄 안에 인용된
# 커서 대피 문구, ③·② 의 끝 괄호 뒤에 글이 더 붙은 줄(끝 앵커)
$tidyKeepCases = @(
  '12:00:00 [경고] 다른 경고: 이동 전 자리(1,2)에 있음 - SetCursorPos 실패 (목표 3,4) (연속 실패 중에는 이 경고를 반복하지 않습니다)',
  '12:00:00 [안내] 인용: [경고] 커서 대피 실패: SetCursorPos 실패 (목표 3,4) (연속 실패 중에는 이 경고를 반복하지 않습니다)',
  '12:00:00 [경고] 커서 대피 실패: GetWindowRect 실패 - 팝업 글자가 커서에 가려질 수 있습니다 (연속 실패 중에는 이 경고를 반복하지 않습니다) 후속문구',
  "12:00:00 [경고] 옵션 화면에서 난이도 '어려움' 글자를 3회 모두 찾지 못했습니다 (호출부가 오류 처리) 후속문구"
)
foreach ($tidyKeep in $tidyKeepCases) {
  Check-Equal ('GUI 정리(보존 근접 변형): {0}' -f $tidyKeep) (Convert-WorkerLogLineForGui $tidyKeep $false) $tidyKeep
}

# 워커 소스 전수 가드 (기준좌표 가드와 같은 방식): 문구 열쇠별로 그 문구를 담은 워커 문자열 노드 집합 =
# '역할|소속 함수|소스 토큰 원문' 기대 집합. 역할 = log(Write-RunLog 첫 인자) / throw(throw 문) / other.
# 철자를 바꾸거나 나눠 조립한 새 문구는 못 잡으니, 그런 문구를 새로 찍으면 이 목록과 GUI 필터를 함께 손볼 것.
$tidyFingerprintText = @'
X1|닫기(X) 후보(|log|Clear-EventOverlay|"[안내] 알 수 없는 화면 - 닫기(X) 후보($($xPick[0]),$($xPick[1])) 클릭 시도 ($attempt/$maxAttempts)"
X2|닫기(X) 후보(|log|Return-ToAbyssSelection|"[안내] 복귀 중 알 수 없는 화면 20초 지속 - 닫기(X) 후보($($xPick[0]),$($xPick[1])) 클릭"
X3|닫기(X) 후보(|log|Return-ToAbyssSelection|"[안내] 복귀 중 닫기(X) 후보($($xPick[0]),$($xPick[1])) 클릭을 건너뜀 (커서 미확인) - 다음 후보로"
H1|호출부가 오류 처리|log|Confirm-DifficultySelected|"[경고] 난이도 '$Label' 선택 강조를 확인하지 못했습니다 (호출부가 오류 처리, 표본: $($script:lastPillProbe))"
H2|호출부가 오류 처리|log|Set-DgOptionDifficulty|"[경고] 옵션 화면에서 난이도 '$Label' 글자를 3회 모두 찾지 못했습니다 (호출부가 오류 처리)"
H3|호출부가 오류 처리|log|Set-DgOptionDifficulty|"[경고] 난이도 '$Label' 선택 강조를 확인하지 못했습니다 (호출부가 오류 처리, 표본: $($script:lastPillProbe))"
C1|커서 대피 실패|log|Move-CursorOutsideGame|"[경고] 커서 대피 실패: $parkError - 팝업 글자가 커서에 가려질 수 있습니다 (연속 실패 중에는 이 경고를 반복하지 않습니다)"
C2|이동 전 자리(|throw|Move-CursorOutsideGame|"SetCursorPos 가 먹지 않음 - 커서가 이동 전 자리($($cursor.X),$($cursor.Y))에 그대로입니다"
C3|SetCursorPos 실패 (목표 |throw|Move-CursorOutsideGame|"SetCursorPos 실패 (목표 $($park.X),$($park.Y))"
C4|연속 실패해 목표(|log|Click-ScreenPoint|"[경고] 커서 위치 확인이 ${cursorStreakNow}회 연속 실패해 목표(${X},${Y}) 클릭을 계속 보류하고 있습니다 - 마우스를 조작 중이면 잠시 놓아 주세요 (이후 연속 실패는 기록을 생략합니다)"
C5|커서를 시작 지점(|log|Invoke-LifeListScroll|"[생활] 목록 스크롤: 커서를 시작 지점($([int]$fromPoint.X),$([int]$fromPoint.Y))으로 확인하지 못해 건너뜀"
W1|게임 창 정보: |log|(최상위)|"[준비] 게임 창 정보: ${infoW}x${infoH}@($($infoRect.Left),$($infoRect.Top)), 클라이언트 $infoClient, 제목줄·테두리 $infoTitleBar, 창 DPI $infoWindowDpi, 모니터 DPI $infoMonitorDpi"
W2|게임 창 정보: |log|(최상위)|'[준비] 게임 창 정보: 측정 불가 (GetWindowRect 실패)'
W3|게임 창 정보: |log|(최상위)|"[준비] 게임 창 정보: 측정 불가 ($($_.Exception.Message))"
W4|게임 창 정렬(|log|(최상위)|"[준비] 게임 창 정렬($windowMode): ${currentWidth}x${currentHeight}@($currentX,$currentY) -> ${targetWidth}x${targetHeight}@($targetX,$targetY)"
A1|자동 입장)|log|(최상위)|'[어비스] 입장하기 클릭 - 파티원 대기 (모이면 자동 입장)'
A2|자동 입장)|log|(최상위)|'[어비스] 파티원 준비 대기 중... (전원 준비되면 자동 입장)'
A3|자동 입장)|log|(최상위)|'[어비스] 파티 매칭 대기 중... (끝나면 자동 입장)'
P1|(입장 대기 중|log|Invoke-PurchasePopupSweep|'[안내] 구매 팝업 감지 - 닫기 클릭 (입장 대기 중)'
P2|(입장 대기 중|log|Invoke-PurchasePopupSweep|'[안내] 구매 팝업 감지 - 커서 확인 실패로 닫기 클릭을 건너뜀 (입장 대기 중, 다음 감지에서 재시도)'
K1|클리어 문구(화면을 터치)|log|Wait-ForDungeonClearScreen|"$($script:contentTag) 클리어 문구(화면을 터치) 감지"
Y1|사용자 입력 감지(|log|Wait-UserYieldEnd|"[안내] 사용자 입력 감지($($script:lastUserInputKind)) - 조작이 끝날 때까지 ${Context}${particle} 멈추고 기다립니다"
Y2|사용자 입력 감지(|log|Click-ScreenPoint|"[안내] 사용자 입력 감지($($script:lastUserInputKind)) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)"
Y3|사용자 입력 감지(|log|Move-CursorOutsideGame|"[안내] 사용자 입력 감지($($script:lastUserInputKind)) - 조작이 끝날 때까지 자동화를 잠시 양보합니다"
Y4|사용자 조작 종료 - |log|Wait-UserYieldEnd|"[안내] 사용자 조작 종료 - ${Context}${particle} 다시 진행합니다 ($([int]$yieldClock.Elapsed.TotalSeconds)초 양보)"
'@
$tidyById = [ordered]@{}
foreach ($tidyRow in ($tidyFingerprintText -split "`r?`n" | Where-Object { $_ })) {
  $tidyParts = $tidyRow.Split([char[]]@('|'), 5)
  $tidyById[$tidyParts[0]] = @{ Phrase = $tidyParts[1]; Role = $tidyParts[2]; Function = $tidyParts[3]; Extent = $tidyParts[4] }
}
function Get-TidyNodeFingerprint {
  param($Node)
  $owner = $Node.Parent
  $role = 'other'
  if ($owner -is [System.Management.Automation.Language.CommandAst] -and $owner.GetCommandName() -eq 'Write-RunLog' -and
      $owner.CommandElements.Count -ge 2 -and [object]::ReferenceEquals($owner.CommandElements[1], $Node)) {
    $role = 'log'
  } elseif ($owner -is [System.Management.Automation.Language.CommandExpressionAst] -and
            $owner.Parent -is [System.Management.Automation.Language.PipelineAst] -and
            $owner.Parent.Parent -is [System.Management.Automation.Language.ThrowStatementAst]) {
    $role = 'throw'
  }
  $ownerFunction = $Node.Parent
  while ($ownerFunction -and -not ($ownerFunction -is [System.Management.Automation.Language.FunctionDefinitionAst])) {
    $ownerFunction = $ownerFunction.Parent
  }
  $ownerName = $(if ($ownerFunction) { $ownerFunction.Name } else { '(최상위)' })
  return ('{0}|{1}|{2}' -f $role, $ownerName, $Node.Extent.Text)
}
foreach ($tidyPhrase in @($tidyById.Values | ForEach-Object { $_.Phrase } | Select-Object -Unique)) {
  $tidyNodes = @($workerAst.FindAll({ param($node)
        ($node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
         $node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) -and
        $node.Value.Contains($tidyPhrase) }, $true))
  $tidyActual = @(foreach ($tidyNode in $tidyNodes) { Get-TidyNodeFingerprint $tidyNode })
  $tidyWant = @($tidyById.Values | Where-Object { $_.Phrase -eq $tidyPhrase } | ForEach-Object { '{0}|{1}|{2}' -f $_.Role, $_.Function, $_.Extent })
  Check-Equal ("워커: '{0}' 문자열 = 역할·소속 함수·템플릿 그대로" -f $tidyPhrase) `
    ((@($tidyActual) | Sort-Object) -join "`n") ((@($tidyWant) | Sort-Object) -join "`n")
}

# 소스 템플릿을 표본 값으로 펼친 원문(필터 전)과 화면 표시(필터 뒤)를 정확 일치로 고정합니다 - 실로그에 아직 없는 모양,
# 화면 좌표 음수(보조 모니터), ⑤ 의 한 축만 바뀐 크기(크기/위치 판정이 '둘 다 같음' 인지)까지.
function Expand-TidyTemplate {
  param([string]$Id, [hashtable]$Vars)
  foreach ($varName in $Vars.Keys) { Set-Variable -Name $varName -Value $Vars[$varName] }
  $tidyExtent = [string]$tidyById[$Id].Extent
  return $ExecutionContext.InvokeCommand.ExpandString($tidyExtent.Substring(1, $tidyExtent.Length - 2))
}
$script:lastPillProbe = '기준(721,121) 0/27 [-18:56/7]'
$tidyParkTarget = Expand-TidyTemplate -Id 'C3' -Vars @{ park = @{ X = -20; Y = 300 } }
$tidyParkStuck = Expand-TidyTemplate -Id 'C2' -Vars @{ cursor = @{ X = -1153; Y = 954 } }
$tidyRenderCases = @(
  @{ Id = 'X3'; Vars = @{ xPick = @(1229, 67) }
     Raw = '[안내] 복귀 중 닫기(X) 후보(1229,67) 클릭을 건너뜀 (커서 미확인) - 다음 후보로'
     Shown = '[안내] 복귀 중 닫기(X) 클릭을 건너뜀 (커서 미확인) - 다음 후보로' }
  @{ Id = 'X1'; Vars = @{ xPick = @(959, 180); attempt = 8; maxAttempts = 20 }
     Raw = '[안내] 알 수 없는 화면 - 닫기(X) 후보(959,180) 클릭 시도 (8/20)'
     Shown = '[안내] 알 수 없는 화면 - 닫기(X) 클릭 시도 (8/20)' }
  @{ Id = 'H1'; Vars = @{ Label = '일반' }
     Raw = "[경고] 난이도 '일반' 선택 강조를 확인하지 못했습니다 (호출부가 오류 처리, 표본: 기준(721,121) 0/27 [-18:56/7])"
     Shown = "[경고] 난이도 '일반' 선택 강조를 확인하지 못했습니다" }
  @{ Id = 'H2'; Vars = @{ Label = '일반' }
     Raw = "[경고] 옵션 화면에서 난이도 '일반' 글자를 3회 모두 찾지 못했습니다 (호출부가 오류 처리)"
     Shown = "[경고] 옵션 화면에서 난이도 '일반' 글자를 3회 모두 찾지 못했습니다" }
  @{ Id = 'C1'; Vars = @{ parkError = $tidyParkTarget }
     Raw = '[경고] 커서 대피 실패: SetCursorPos 실패 (목표 -20,300) - 팝업 글자가 커서에 가려질 수 있습니다 (연속 실패 중에는 이 경고를 반복하지 않습니다)'
     Shown = '[경고] 커서 대피 실패: SetCursorPos 실패 - 팝업 글자가 커서에 가려질 수 있습니다' }
  @{ Id = 'C1'; Vars = @{ parkError = $tidyParkStuck }
     Raw = '[경고] 커서 대피 실패: SetCursorPos 가 먹지 않음 - 커서가 이동 전 자리(-1153,954)에 그대로입니다 - 팝업 글자가 커서에 가려질 수 있습니다 (연속 실패 중에는 이 경고를 반복하지 않습니다)'
     Shown = '[경고] 커서 대피 실패: SetCursorPos 가 먹지 않음 - 커서가 이동 전 자리에 그대로입니다 - 팝업 글자가 커서에 가려질 수 있습니다' }
  @{ Id = 'C4'; Vars = @{ cursorStreakNow = 3; X = -612; Y = 655 }
     Raw = '[경고] 커서 위치 확인이 3회 연속 실패해 목표(-612,655) 클릭을 계속 보류하고 있습니다 - 마우스를 조작 중이면 잠시 놓아 주세요 (이후 연속 실패는 기록을 생략합니다)'
     Shown = '[경고] 커서 위치 확인이 3회 연속 실패해 목표 클릭을 계속 보류하고 있습니다 - 마우스를 조작 중이면 잠시 놓아 주세요 (이후 연속 실패는 기록을 생략합니다)' }
  @{ Id = 'C5'; Vars = @{ fromPoint = @{ X = -900; Y = 420 } }
     Raw = '[생활] 목록 스크롤: 커서를 시작 지점(-900,420)으로 확인하지 못해 건너뜀'
     Shown = '[생활] 목록 스크롤: 커서를 시작 지점으로 확인하지 못해 건너뜀' }
  @{ Id = 'W1'; Vars = @{ infoW = 1038; infoH = 717; infoRect = @{ Left = -7; Top = 10 }; infoClient = '1022x678'; infoTitleBar = '39px'; infoWindowDpi = '96'; infoMonitorDpi = '96 (100%)' }
     Raw = '[준비] 게임 창 정보: 1038x717@(-7,10), 클라이언트 1022x678, 제목줄·테두리 39px, 창 DPI 96, 모니터 DPI 96 (100%)'
     Shown = '[준비] 게임 창 정보: 1038x717, 클라이언트 1022x678, 제목줄·테두리 39px, 창 DPI 96, 모니터 DPI 96 (100%)' }
  @{ Id = 'W2'; Vars = @{}
     Raw = '[준비] 게임 창 정보: 측정 불가 (GetWindowRect 실패)'
     Shown = '[준비] 게임 창 정보: 측정 불가 (GetWindowRect 실패)' }
  @{ Id = 'W4'; Vars = @{ windowMode = 'fixed'; currentWidth = 1272; currentHeight = 702; currentX = -11; currentY = 2; targetWidth = 1272; targetHeight = 717; targetX = 0; targetY = 2 }
     Raw = '[준비] 게임 창 정렬(fixed): 1272x702@(-11,2) -> 1272x717@(0,2)'
     Shown = '[준비] 게임 창 크기 조정: 1272x702 -> 1272x717' }
  @{ Id = 'W4'; Vars = @{ windowMode = 'nearest'; currentWidth = 1908; currentHeight = 1076; currentX = -5; currentY = -3; targetWidth = 1908; targetHeight = 1076; targetX = 0; targetY = 0 }
     Raw = '[준비] 게임 창 정렬(nearest): 1908x1076@(-5,-3) -> 1908x1076@(0,0)'
     Shown = '[준비] 게임 창 위치 조정: 1908x1076' }
  @{ Id = 'W4'; Vars = @{ windowMode = 'nearest'; currentWidth = 1270; currentHeight = 717; currentX = 644; currentY = 6; targetWidth = 1272; targetHeight = 717; targetX = 644; targetY = 6 }
     Raw = '[준비] 게임 창 정렬(nearest): 1270x717@(644,6) -> 1272x717@(644,6)'
     Shown = '[준비] 게임 창 크기 조정: 1270x717 -> 1272x717' }
)
foreach ($tidyRender in $tidyRenderCases) {
  $tidyRaw = Expand-TidyTemplate -Id $tidyRender.Id -Vars $tidyRender.Vars
  Check-Equal ('워커 템플릿 펼침({0}): {1}' -f $tidyRender.Id, $tidyRender.Raw) $tidyRaw $tidyRender.Raw
  Check-Equal ('GUI 정리(소스 템플릿 {0}): {1}' -f $tidyRender.Id, $tidyRender.Shown) `
    (Convert-WorkerLogLineForGui ('12:00:00 ' + $tidyRaw) $false) ('12:00:00 ' + $tidyRender.Shown)
}
# 측정 불가 예외문(W3)은 $_ 를 쓰는 템플릿이라 파이프라인 안에서 펼칩니다 - 그대로 보여야 함
$tidyW3Extent = [string]$tidyById['W3'].Extent
$tidyW3Raw = [pscustomobject]@{ Exception = [pscustomobject]@{ Message = 'GetDpiForWindow 진입점 없음' } } |
  ForEach-Object { $ExecutionContext.InvokeCommand.ExpandString($tidyW3Extent.Substring(1, $tidyW3Extent.Length - 2)) }
Check-Equal '워커 템플릿 펼침(W3): 측정 불가 예외문' $tidyW3Raw '[준비] 게임 창 정보: 측정 불가 (GetDpiForWindow 진입점 없음)'
Check-Equal 'GUI 정리(소스 템플릿 W3): 측정 불가 예외문은 그대로' `
  (Convert-WorkerLogLineForGui ('12:00:00 ' + $tidyW3Raw) $false) ('12:00:00 [준비] 게임 창 정보: 측정 불가 (GetDpiForWindow 진입점 없음)')

# ── 3차 정리 (2026-10-02 사용자 확정) - ⑥ 파티 입장 안내 '(… 자동 입장)' ⑦ 구매 팝업 '(입장 대기 중…)' ⑧ '클리어 문구(화면을 터치)' ──
# 실로그 원문 → 기대 표시 (정확 일치). 마지막 줄은 [던전] 이라 기존 규칙대로 화면에서 숨김($null)이어야 합니다(숨김이 먼저).
$tidy3RealCases = @(
  @('11:19:26 [어비스] 입장하기 클릭 - 파티원 대기 (모이면 자동 입장)', '11:19:26 [어비스] 입장하기 클릭 - 파티원 대기'),
  @('11:19:27 [어비스] 파티 매칭 대기 중... (끝나면 자동 입장)', '11:19:27 [어비스] 파티 매칭 대기 중...'),
  @('21:56:03 [어비스] 파티원 준비 대기 중... (전원 준비되면 자동 입장)', '21:56:03 [어비스] 파티원 준비 대기 중...'),
  @('11:19:42 [안내] 구매 팝업 감지 - 닫기 클릭 (입장 대기 중)', '11:19:42 [안내] 구매 팝업 감지 - 닫기 클릭'),
  @('11:22:48 [어비스] 클리어 문구(화면을 터치) 감지', '11:22:48 [어비스] 클리어 문구 감지'),
  @('15:08:11 [던전] 클리어 문구(화면을 터치) 감지', $null)
)
foreach ($tidy3Case in $tidy3RealCases) {
  Check-Equal ('GUI 3차(실로그): {0}' -f $tidy3Case[0]) (Convert-WorkerLogLineForGui $tidy3Case[0] $false) $tidy3Case[1]
}
# 보존 근접 변형 - 그대로여야 함: 끝 앵커(뒤에 글이 더 붙음), 목록 밖 앞말, 구매 팝업 줄이 아님(가드), 다른 줄 안에 인용(태그 위치
# 앵커), 쉼표형의 다른 안내
$tidy3KeepCases = @(
  '12:00:00 [어비스] 파티 매칭 대기 중... (끝나면 자동 입장) 후속문구',
  '12:00:00 [안내] 예시 안내 (곧 자동 입장)',
  '12:00:00 [안내] 다른 안내 (입장 대기 중)',
  '12:00:00 [경고] 인용: [안내] 구매 팝업 감지 - 닫기 클릭 (입장 대기 중)',
  '12:00:00 [안내] 구매 팝업 감지 - 닫기 클릭 (입장 대기 중) 후속문구',
  '12:00:00 [안내] 구매 팝업 감지 - 커서 확인 실패로 닫기 클릭을 건너뜀 (입장 대기 중, 다음 감지에서 재시도) 후속문구',
  '12:00:00 [안내] 구매 팝업 감지 - 커서 확인 실패로 닫기 클릭을 건너뜀 (입장 대기 중, 다른 안내)',
  '12:00:00 [어비스] 클리어 문구(화면을 터치) 감지 후속문구',
  '12:00:00 [안내] 인용: [어비스] 클리어 문구(화면을 터치) 감지'
)
foreach ($tidy3Keep in $tidy3KeepCases) {
  Check-Equal ('GUI 3차(보존 근접 변형): {0}' -f $tidy3Keep) (Convert-WorkerLogLineForGui $tidy3Keep $false) $tidy3Keep
}
# 소스 템플릿 펼침 - 실로그에 없는 모양(구매 팝업 건너뜀, [사냥터] 클리어 문구)과 리터럴 3줄. contentTag 는 스크립트 범위라
# 펼친 뒤 지웁니다(뒤 단언 오염 방지).
$tidy3RenderCases = @(
  @{ Id = 'A1'; Raw = '[어비스] 입장하기 클릭 - 파티원 대기 (모이면 자동 입장)'; Shown = '[어비스] 입장하기 클릭 - 파티원 대기' }
  @{ Id = 'A2'; Raw = '[어비스] 파티원 준비 대기 중... (전원 준비되면 자동 입장)'; Shown = '[어비스] 파티원 준비 대기 중...' }
  @{ Id = 'A3'; Raw = '[어비스] 파티 매칭 대기 중... (끝나면 자동 입장)'; Shown = '[어비스] 파티 매칭 대기 중...' }
  @{ Id = 'P1'; Raw = '[안내] 구매 팝업 감지 - 닫기 클릭 (입장 대기 중)'; Shown = '[안내] 구매 팝업 감지 - 닫기 클릭' }
  @{ Id = 'P2'; Raw = '[안내] 구매 팝업 감지 - 커서 확인 실패로 닫기 클릭을 건너뜀 (입장 대기 중, 다음 감지에서 재시도)'
     Shown = '[안내] 구매 팝업 감지 - 커서 확인 실패로 닫기 클릭을 건너뜀 (다음 감지에서 재시도)' }
  @{ Id = 'K1'; Tag = '[사냥터]'; Raw = '[사냥터] 클리어 문구(화면을 터치) 감지'; Shown = '[사냥터] 클리어 문구 감지' }
  @{ Id = 'K1'; Tag = '[어비스]'; Raw = '[어비스] 클리어 문구(화면을 터치) 감지'; Shown = '[어비스] 클리어 문구 감지' }
)
foreach ($tidy3Render in $tidy3RenderCases) {
  if ($tidy3Render.Tag) { $script:contentTag = $tidy3Render.Tag }
  $tidy3Raw = Expand-TidyTemplate -Id $tidy3Render.Id -Vars @{}
  Remove-Variable -Name contentTag -Scope Script -ErrorAction SilentlyContinue
  Check-Equal ('워커 템플릿 펼침({0}): {1}' -f $tidy3Render.Id, $tidy3Render.Raw) $tidy3Raw $tidy3Render.Raw
  Check-Equal ('GUI 3차(소스 템플릿 {0}): {1}' -f $tidy3Render.Id, $tidy3Render.Shown) `
    (Convert-WorkerLogLineForGui ('12:00:00 ' + $tidy3Raw) $false) ('12:00:00 ' + $tidy3Render.Shown)
}

# ── 4차 정리 (2026-10-02 사용자 확정) - ⑨ '사용자 입력 감지(입력 종류) - …' → '○○ 조작 감지 - …', 기다림 안내 2종 통일 ──
# 접두의 ○○ 는 6차(2026-10-06 사용자 확정)부터 입력 종류별입니다: 마우스 이동 → 마우스, 키/버튼 입력 → 키보드·버튼, 그 밖 → 사용자.
# 실로그 원문 → 기대 표시 (정확 일치). 뒤 3줄(조작 종료·재개·계속 중)은 그대로여야 하는 실로그입니다.
$tidy4RealCases = @(
  @('13:29:01 [안내] 사용자 입력 감지(키/버튼 입력) - 조작이 끝날 때까지 어비스 선택 화면 복귀를 멈추고 기다립니다',
    '13:29:01 [안내] 키보드·버튼 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다'),
  @('13:48:36 [안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 클리어 화면 터치(나가기 버튼 표시)을(를) 멈추고 기다립니다',
    '13:48:36 [안내] 마우스 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다'),
  @("13:25:27 [안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 난이도 '매우 어려움' 확인을 멈추고 기다립니다",
    '13:25:27 [안내] 마우스 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다'),
  @('15:09:46 [안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 자동화를 잠시 양보합니다',
    '15:09:46 [안내] 마우스 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다'),
  @('20:29:48 [안내] 사용자 입력 감지(키/버튼 입력) - 조작이 끝날 때까지 자동화를 잠시 양보합니다',
    '20:29:48 [안내] 키보드·버튼 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다'),
  # 클릭 공통 함수의 '이번 클릭은 건너뜁니다' 는 5차(아래)에서 화면 숨김으로 바뀜 - 접두 변환보다 숨김이 먼저
  @('13:27:57 [안내] 사용자 입력 감지(키/버튼 입력) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)',
    $null),
  @('13:29:05 [안내] 사용자 조작 종료 - 어비스 선택 화면 복귀를 다시 진행합니다 (4초 양보)',
    '13:29:05 [안내] 사용자 조작 종료 - 어비스 선택 화면 복귀를 다시 진행합니다 (4초 양보)'),
  @('15:09:46 [안내] 사용자 조작이 끝나 자동화를 재개합니다 (양보 1초)',
    '15:09:46 [안내] 사용자 조작이 끝나 자동화를 재개합니다 (양보 1초)'),
  @('20:23:08 [안내] 사용자 조작이 계속되고 있어 이벤트 화면 넘기기 대기 중입니다 (60초 경과)',
    '20:23:08 [안내] 사용자 조작이 계속되고 있어 이벤트 화면 넘기기 대기 중입니다 (60초 경과)')
)
foreach ($tidy4Case in $tidy4RealCases) {
  Check-Equal ('GUI 4차(실로그): {0}' -f $tidy4Case[0]) (Convert-WorkerLogLineForGui $tidy4Case[0] $false) $tidy4Case[1]
}
# 근접 변형: 앞 2줄은 그대로(다른 줄 안에 인용 - 태그 위치 / [경고] 태그 - [안내] 고정), 뒤 2줄은 기다림 안내 뒤에 글이 더 붙은 줄이라
# 접두만 바뀌고 본문은 그대로(두 통일식의 끝 앵커)
$tidy4NearCases = @(
  @('12:00:00 [경고] 인용: [안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 자동화를 잠시 양보합니다',
    '12:00:00 [경고] 인용: [안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 자동화를 잠시 양보합니다'),
  @('12:00:00 [경고] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 자동화를 잠시 양보합니다',
    '12:00:00 [경고] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 자동화를 잠시 양보합니다'),
  @('12:00:00 [안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 자동화를 잠시 양보합니다 후속문구',
    '12:00:00 [안내] 마우스 조작 감지 - 조작이 끝날 때까지 자동화를 잠시 양보합니다 후속문구'),
  @('12:00:00 [안내] 사용자 입력 감지(키/버튼 입력) - 조작이 끝날 때까지 던전 퇴장을 멈추고 기다립니다 후속문구',
    '12:00:00 [안내] 키보드·버튼 조작 감지 - 조작이 끝날 때까지 던전 퇴장을 멈추고 기다립니다 후속문구')
)
foreach ($tidy4Near in $tidy4NearCases) {
  Check-Equal ('GUI 4차(근접 변형): {0}' -f $tidy4Near[0]) (Convert-WorkerLogLineForGui $tidy4Near[0] $false) $tidy4Near[1]
}
# 소스 템플릿 펼침 - 입력 종류(마우스·키·빈 값·모르는 값)와 작업 이름·조사 표본. lastUserInputKind 는 스크립트 범위라 펼친 뒤 지웁니다.
$tidy4RenderCases = @(
  @{ Id = 'Y1'; Kind = '마우스 이동'; Vars = @{ Context = '던전 퇴장'; particle = '을' }
     Raw = '[안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 던전 퇴장을 멈추고 기다립니다'
     Shown = '[안내] 마우스 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다' }
  @{ Id = 'Y1'; Kind = '키/버튼 입력'; Vars = @{ Context = '입장하기 클릭 확인(상세 화면 종료)'; particle = '을(를)' }
     Raw = '[안내] 사용자 입력 감지(키/버튼 입력) - 조작이 끝날 때까지 입장하기 클릭 확인(상세 화면 종료)을(를) 멈추고 기다립니다'
     Shown = '[안내] 키보드·버튼 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다' }
  @{ Id = 'Y1'; Kind = ''; Vars = @{ Context = "난이도 '어려움' 확인"; particle = '을' }
     Raw = "[안내] 사용자 입력 감지() - 조작이 끝날 때까지 난이도 '어려움' 확인을 멈추고 기다립니다"
     Shown = '[안내] 사용자 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다' }
  @{ Id = 'Y2'; Kind = ''; Vars = @{}
     Raw = '[안내] 사용자 입력 감지() - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)'
     Shown = $null }   # 5차: 화면 숨김 (빈 입력 종류도 숨겨야 함)
  @{ Id = 'Y2'; Kind = '키/버튼 입력'; Vars = @{}
     Raw = '[안내] 사용자 입력 감지(키/버튼 입력) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)'
     Shown = $null }
  @{ Id = 'Y2'; Kind = '터치'; Vars = @{}
     Raw = '[안내] 사용자 입력 감지(터치) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)'
     Shown = $null }   # 5차 숨김은 입력 종류를 가리지 않음 (모르는 값도 숨김)
  @{ Id = 'Y3'; Kind = '마우스 이동'; Vars = @{}
     Raw = '[안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 자동화를 잠시 양보합니다'
     Shown = '[안내] 마우스 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다' }
  @{ Id = 'Y3'; Kind = '키/버튼 입력'; Vars = @{}
     Raw = '[안내] 사용자 입력 감지(키/버튼 입력) - 조작이 끝날 때까지 자동화를 잠시 양보합니다'
     Shown = '[안내] 키보드·버튼 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다' }
  @{ Id = 'Y3'; Kind = ''; Vars = @{}
     Raw = '[안내] 사용자 입력 감지() - 조작이 끝날 때까지 자동화를 잠시 양보합니다'
     Shown = '[안내] 사용자 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다' }
  @{ Id = 'Y4'; Kind = '키/버튼 입력'; Vars = @{ Context = '어비스 선택 화면 복귀'; particle = '를'; yieldClock = @{ Elapsed = @{ TotalSeconds = 4 } } }
     Raw = '[안내] 사용자 조작 종료 - 어비스 선택 화면 복귀를 다시 진행합니다 (4초 양보)'
     Shown = '[안내] 사용자 조작 종료 - 어비스 선택 화면 복귀를 다시 진행합니다 (4초 양보)' }
)
foreach ($tidy4Render in $tidy4RenderCases) {
  $script:lastUserInputKind = $tidy4Render.Kind
  $tidy4Raw = Expand-TidyTemplate -Id $tidy4Render.Id -Vars $tidy4Render.Vars
  Remove-Variable -Name lastUserInputKind -Scope Script -ErrorAction SilentlyContinue
  Check-Equal ('워커 템플릿 펼침({0}): {1}' -f $tidy4Render.Id, $tidy4Render.Raw) $tidy4Raw $tidy4Render.Raw
  $tidy4Want = $(if ($null -eq $tidy4Render.Shown) { $null } else { '12:00:00 ' + $tidy4Render.Shown })
  $tidy4ShownLabel = $(if ($null -eq $tidy4Render.Shown) { '(숨김)' } else { $tidy4Render.Shown })
  Check-Equal ("GUI 4차(소스 템플릿 {0}, 종류 '{1}'): {2}" -f $tidy4Render.Id, $tidy4Render.Kind, $tidy4ShownLabel) `
    (Convert-WorkerLogLineForGui ('12:00:00 ' + $tidy4Raw) $false) $tidy4Want
}

# ── 5차 (2026-10-02 사용자 확정) - 클릭 공통 함수의 '이번 클릭은 건너뜁니다' 안내를 화면에서 숨김 (파일엔 남김) ──
# 사용자 지적 원문 쌍(같은 초): 공통 줄은 숨기고, 부른 쪽 줄(무엇을 건너뛰었는지)은 그대로
Check-Equal 'GUI 5차: 공통 클릭 건너뜀 안내는 숨김 (사용자 지적 원문)' `
  (Convert-WorkerLogLineForGui '14:38:02 [안내] 사용자 입력 감지(마우스 이동) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)' $false) $null
Check-Equal 'GUI 5차: 부른 쪽 건너뜀 안내는 그대로 (사용자 지적 원문)' `
  (Convert-WorkerLogLineForGui '14:38:02 [어비스] 컷신 - 사용자 조작으로 장면 넘기기 클릭을 건너뜀 (다음 감지에서 재시도)' $false) `
  '14:38:02 [어비스] 컷신 - 사용자 조작으로 장면 넘기기 클릭을 건너뜀 (다음 감지에서 재시도)'
# 근접 변형: 뒤에 글이 더 붙으면 숨기지 않고 4차 접두 변환만(끝 앵커), 다른 줄 안에 인용·[경고] 태그는 그대로(태그 위치·[안내] 고정)
Check-Equal 'GUI 5차: 끝에 글이 더 붙으면 숨기지 않음 (접두만 변환)' `
  (Convert-WorkerLogLineForGui '12:00:00 [안내] 사용자 입력 감지(마우스 이동) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도) 후속문구' $false) `
  '12:00:00 [안내] 마우스 조작 감지 - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도) 후속문구'
Check-Equal 'GUI 5차: 인용된 공통 안내는 숨기지 않음' `
  (Convert-WorkerLogLineForGui '12:00:00 [경고] 인용: [안내] 사용자 입력 감지(마우스 이동) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)' $false) `
  '12:00:00 [경고] 인용: [안내] 사용자 입력 감지(마우스 이동) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)'
Check-Equal 'GUI 5차: [경고] 태그 줄은 숨기지 않음' `
  (Convert-WorkerLogLineForGui '12:00:00 [경고] 사용자 입력 감지(마우스 이동) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)' $false) `
  '12:00:00 [경고] 사용자 입력 감지(마우스 이동) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)'

# ── 6차 (2026-10-06 사용자 확정) - 4차에서 지운 입력 종류를 접두로 되살림: 마우스 이동 → '마우스 조작 감지',
#    키/버튼 입력 → '키보드·버튼 조작 감지', 그 밖 → '사용자 조작 감지' (키/버튼에는 제자리 클릭·휠·다른 장치 버튼도 들어가 '키보드'로 단정 안 함) ──
# 사용자 지적 원문 쌍(같은 초, run_20261006_h13m11s12.log): 공통 클릭 건너뜀은 5차대로 숨기고, 기다림 안내는 그 줄의 종류로
Check-Equal 'GUI 6차: 같은 초의 공통 클릭 건너뜀(키/버튼 입력)은 숨김 (사용자 지적 원문)' `
  (Convert-WorkerLogLineForGui '13:04:44 [안내] 사용자 입력 감지(키/버튼 입력) - 이번 클릭은 건너뜁니다 (조작이 끝나면 다음 감지에서 다시 시도)' $false) $null
Check-Equal 'GUI 6차: 기다림 안내는 그 줄의 입력 종류로 (사용자 지적 원문)' `
  (Convert-WorkerLogLineForGui '13:04:44 [안내] 사용자 입력 감지(마우스 이동) - 조작이 끝날 때까지 입장하기 클릭 확인(상세 화면 종료)을(를) 멈추고 기다립니다' $false) `
  '13:04:44 [안내] 마우스 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다'
# 워커 문자열과 정확히 같을 때만 라벨을 붙입니다 - 앞부분만 같음·앞뒤 공백·모르는 값은 '사용자'
foreach ($tidy6Kind in @('키/버튼', ' 마우스 이동', '마우스 이동 ', '마우스', '터치')) {
  Check-Equal ("GUI 6차: 워커와 다른 입력 종류 '{0}' 는 '사용자 조작 감지'" -f $tidy6Kind) `
    (Convert-WorkerLogLineForGui ('12:00:00 [안내] 사용자 입력 감지({0}) - 조작이 끝날 때까지 자동화를 잠시 양보합니다' -f $tidy6Kind) $false) `
    '12:00:00 [안내] 사용자 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다'
}
# 워커 입력 종류 전수 가드: lastUserInputKind 를 가리키는 변수 참조 전부를 '대입(= 연산, 오른쪽 상수 문자열)'·'읽기'로 나눠
# 고정합니다 - 대입은 초기값('')·'마우스 이동'·'키/버튼 입력' 3곳, 읽기는 안내 템플릿 3곳(Y1~Y3). 종류 문구를 바꾸거나 새 종류·
# 간접 대입(+=, [ref], Set-Variable 등)을 넣으면 실패하니, 그때 GUI ⑨ 의 라벨 매핑과 아래 라벨 표를 함께 손볼 것.
$tidy6KindRefs = @($workerAst.FindAll({ param($node)
      $node -is [System.Management.Automation.Language.VariableExpressionAst] -and
      $node.VariablePath.UserPath -match '^(?:\w+:)?lastUserInputKind$' }, $true))
$tidy6Assigned = New-Object System.Collections.Generic.List[string]
$tidy6Reads = 0
foreach ($tidy6Ref in $tidy6KindRefs) {
  $tidy6Owner = $tidy6Ref.Parent
  if ($tidy6Owner -is [System.Management.Automation.Language.AssignmentStatementAst] -and [object]::ReferenceEquals($tidy6Owner.Left, $tidy6Ref)) {
    if ($tidy6Owner.Operator -eq [System.Management.Automation.Language.TokenKind]::Equals -and
        $tidy6Owner.Right -is [System.Management.Automation.Language.CommandExpressionAst] -and
        $tidy6Owner.Right.Expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
      $tidy6Assigned.Add($tidy6Owner.Right.Expression.Value)
    } else {
      $tidy6Assigned.Add('<상수 아닌 대입>')
    }
  } else {
    $tidy6Reads++
  }
}
Check-Equal '워커: 입력 종류 대입 = 초기값·마우스 이동·키/버튼 입력 3곳 (= 연산, 상수 문자열)' `
  ((@($tidy6Assigned) | Sort-Object) -join '|') ((@('', '마우스 이동', '키/버튼 입력') | Sort-Object) -join '|')
Check-Equal '워커: 입력 종류 읽기 = 안내 템플릿 3곳 (Y1~Y3)' $tidy6Reads 3
# 변수 이름을 문자열로 다루는 간접 대입(Set-Variable -Name lastUserInputKind 등)도 없어야 합니다
$tidy6NameStrings = @($workerAst.FindAll({ param($node)
      $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
      $node.Value -match 'lastUserInputKind' }, $true))
Check-Equal '워커: 입력 종류 변수 이름을 문자열로 쓰는 곳 없음' $tidy6NameStrings.Count 0
# 워커에서 캡처한 종류마다 화면 라벨 = 사용자 확정 표 (워커가 새 종류를 넣으면 위 집합 단언과 이 표를 함께 손볼 것)
$tidy6Labels = @{ '마우스 이동' = '마우스'; '키/버튼 입력' = '키보드·버튼'; '' = '사용자' }
foreach ($tidy6Kind in @($tidy6Assigned | Select-Object -Unique)) {
  if (-not $tidy6Labels.ContainsKey($tidy6Kind)) {
    Check-Equal ("GUI 6차: 워커 입력 종류 '{0}' 의 화면 라벨이 정해져 있음" -f $tidy6Kind) $false $true
    continue
  }
  foreach ($tidy6Id in @('Y1', 'Y3')) {
    $script:lastUserInputKind = $tidy6Kind
    $tidy6Raw = Expand-TidyTemplate -Id $tidy6Id -Vars @{ Context = '던전 퇴장'; particle = '을' }
    Remove-Variable -Name lastUserInputKind -Scope Script -ErrorAction SilentlyContinue
    Check-Equal ("GUI 6차(워커 종류 '{0}', {1}): '{2} 조작 감지'" -f $tidy6Kind, $tidy6Id, $tidy6Labels[$tidy6Kind]) `
      (Convert-WorkerLogLineForGui ('12:00:00 ' + $tidy6Raw) $false) `
      ('12:00:00 [안내] {0} 조작 감지 - 조작이 끝날 때까지 멈추고 기다립니다' -f $tidy6Labels[$tidy6Kind])
  }
}

# ── InsideHandoff 꼬리 숨김 (2026-10-08 사용자 결정 Q9 · 구현 명세 ① 2.4 · v11 R1 3.1·6.2) - 파일 원본·판별은 원문, 화면에서만 지움 ──
# 워커 문구는 설계 R1 2.2 순서 4 그대로이고 nonce 는 GUID 'D' 형식입니다 (워커가 이 줄을 내는 단위는 ⑤ - 실로그가 생기면 그 원문을 더할 것)
$ihBody = "[완료] '다시 하기' 재입장 확인 - 직전 판을 회차로 계상, 다음 실행이 이 판을 이어받습니다"
$ihTail = ' [terminal=InsideHandoff nonce=0f8fad5b-d9cb-469f-a165-70867728950e]'
Check-Equal 'GUI Q9: InsideHandoff 완료 줄의 꼬리 0·본문 그대로' `
  (Convert-WorkerLogLineForGui "12:00:00 $ihBody$ihTail" $false) "12:00:00 $ihBody"
Check-Equal 'GUI Q9: 대문자 GUID nonce·커스텀 실행에서도 꼬리 0' `
  (Convert-WorkerLogLineForGui "12:00:00 $ihBody [terminal=InsideHandoff nonce=7C9E6679-7425-40DE-944B-E07FC1F90AE7]" $true) "12:00:00 $ihBody"
Check-Equal 'GUI Q9: 꼬리 없는 같은 줄은 그대로' (Convert-WorkerLogLineForGui "12:00:00 $ihBody" $false) "12:00:00 $ihBody"
# 근접 변형 - 그대로여야 함: 꼬리 뒤에 글이 더 붙음(끝 앵커) · 다른 terminal 값 · GUID 글자가 아닌 nonce · 꼬리 앞 공백 없음
$ihKeepCases = @(
  "12:00:00 $ihBody$ihTail 후속문구",
  "12:00:00 $ihBody [terminal=ReadySelection nonce=0f8fad5b-d9cb-469f-a165-70867728950e]",
  "12:00:00 $ihBody [terminal=InsideHandoff nonce=0f8fad5b-zzzz]",
  "12:00:00 $ihBody[terminal=InsideHandoff nonce=0f8fad5b-d9cb-469f-a165-70867728950e]"
)
foreach ($ihKeep in $ihKeepCases) {
  Check-Equal ('GUI Q9(보존 근접 변형): {0}' -f $ihKeep) (Convert-WorkerLogLineForGui $ihKeep $false) $ihKeep
}
# 수집 식(타이머 통상 tail 의 [완료] 사유 갱신 - 화면 변환 전 원문)을 소스 그대로 돌리면 사유에 꼬리가 남습니다(판별은 원문이라 숨김과
# 닿지 않음). 공통 최종 수집 경로의 같은 단언은 tests\test_abyss_handoff_gui.ps1 H1·H2 가 타이머 틱을 그대로 돌려서 합니다
$guiTailAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$null, [ref]$null)
$tailReasonIfs = @($guiTailAst.FindAll({ param($node)
      $node -is [System.Management.Automation.Language.IfStatementAst] -and
      $node.Clauses[0].Item1.Extent.Text -eq '$logLine -match ''\[완료\]\s*(.+)''' }, $true))
Check-Equal 'GUI Q9: 타이머 통상 tail 의 [완료] 사유 수집 식 1곳' $tailReasonIfs.Count 1
if ($tailReasonIfs.Count -eq 1) {
  $script:lastWorkerDoneReason = ''
  $logLine = "12:00:00 $ihBody$ihTail"
  . ([scriptblock]::Create($tailReasonIfs[0].Extent.Text))
  Check-Equal 'GUI Q9: 수집 식에는 꼬리가 남음 (화면 변환 전 원문)' $script:lastWorkerDoneReason ($ihBody.Substring('[완료] '.Length) + $ihTail)
}

# ── 어비스 클리어 완료 기록 성공 줄 숨김 (구현 명세 ① 2.10 W7 · 5절 B8 · 검토 P3-2) - 개발자 메모라 파일에만, 화면에서는 줄 전체를 숨김 ──
# 워커 문구는 소스에서 잡습니다(사본을 박지 않음): 기록 함수 Add-AbyssJournalClearedEntry 의 Write-RunLog 첫 인자 - 성공 줄([어비스] 문자열 1) ·
# 소유자 해석 실패 [경고] 문자열 1 · 저장 실패 [경고] 문자열(실패 낱말 변수 1개를 품은 확장 문자열 1 - 그 자리를 실패 낱말 3종(설계 R2 3.6)으로
# 채움. 단계 2.10 명세 대조 P3-1 로 -f 식에서 문자열로 바뀜 - 워커 로그 심각도 회귀가 문자열 인자만 분류). 성공 줄만 숨고(시각 접두 있음·없음 ·
# 커스텀·비커스텀 모두 - 워커가 모드와 무관하게 씀) 두 [경고] 줄은 그대로 보입니다(사용자가 알아야 하는 줄). 한쪽만 바뀌면(워커 문구·GUI 규칙)
# 개발자 메모 줄이 창에 뜹니다(명세 0.4 ⑦)
$clearedFunctionAst = $workerAst.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Add-AbyssJournalClearedEntry' }, $true)
$clearedSuccessTexts = @()
$clearedWarningTexts = @()
$clearedFailFormats = @()
if ($null -ne $clearedFunctionAst) {
  foreach ($clearedLogCall in @($clearedFunctionAst.FindAll({ param($node)
          $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Write-RunLog' -and $node.CommandElements.Count -ge 2 }, $true))) {
    $clearedArgument = $clearedLogCall.CommandElements[1]
    if ($clearedArgument -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
      if ($clearedArgument.Value.StartsWith('[어비스]')) { $clearedSuccessTexts += $clearedArgument.Value }
      elseif ($clearedArgument.Value.StartsWith('[경고]')) { $clearedWarningTexts += $clearedArgument.Value }
    } elseif ($clearedArgument -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
      # 저장 실패 줄 - 변수 1개(실패 낱말)를 품은 [경고] 문자열. 그 변수 자리를 {0} 으로 바꿔 아래에서 실패 낱말 3종으로 채웁니다
      $clearedNested = @($clearedArgument.NestedExpressions)
      if ($clearedArgument.Value.StartsWith('[경고]') -and ($clearedNested.Count -eq 1) -and
          ($clearedNested[0] -is [System.Management.Automation.Language.VariableExpressionAst])) {
        $clearedFailFormats += $clearedArgument.Value.Replace($clearedNested[0].Extent.Text, '{0}')
      }
    }
  }
}
Check-Equal 'GUI W7: 워커 기록 함수의 줄 원문 - 성공([어비스]) 1 · 소유자 [경고] 1 · 저장 실패 [경고](실패 낱말 변수 1개) 1' `
  ('{0}/{1}/{2}' -f $clearedSuccessTexts.Count, $clearedWarningTexts.Count, $clearedFailFormats.Count) '1/1/1'
if ($clearedSuccessTexts.Count -eq 1 -and $clearedWarningTexts.Count -eq 1 -and $clearedFailFormats.Count -eq 1) {
  $clearedSuccess = $clearedSuccessTexts[0]
  Check-Equal 'GUI W7: 성공 줄(시각 접두) → 숨김' (Convert-WorkerLogLineForGui "12:00:00 $clearedSuccess" $false) $null
  Check-Equal 'GUI W7: 성공 줄(접두 없음) → 숨김' (Convert-WorkerLogLineForGui $clearedSuccess $false) $null
  Check-Equal 'GUI W7: 성공 줄 · 커스텀 실행 → 숨김(모드 무관)' (Convert-WorkerLogLineForGui "12:00:00 $clearedSuccess" $true) $null
  Check-Equal 'GUI W7: 소유자 해석 실패 [경고] 줄은 그대로 보임' `
    (Convert-WorkerLogLineForGui "12:00:00 $($clearedWarningTexts[0])" $true) "12:00:00 $($clearedWarningTexts[0])"
  foreach ($clearedFailKind in @('파일 사용 중', '파일 손상', '기록 실패')) {
    $clearedFailLine = '12:00:00 ' + ($clearedFailFormats[0] -f $clearedFailKind)
    Check-Equal ('GUI W7: 저장 실패 [경고] 줄({0})은 그대로 보임' -f $clearedFailKind) (Convert-WorkerLogLineForGui $clearedFailLine $false) $clearedFailLine
  }
  # 근접 변형 - 그대로여야 함: 뒤에 글이 더 붙음(끝 앵커) · 다른 태그 · 다른 줄 안에 인용(머리 앵커)
  $clearedKeepCases = @(
    "12:00:00 $clearedSuccess 후속문구",
    ('12:00:00 ' + $clearedSuccess.Replace('[어비스]', '[커스텀]')),
    "12:00:00 [오류] 확인 필요 - $clearedSuccess"
  )
  foreach ($clearedKeep in $clearedKeepCases) {
    Check-Equal ('GUI W7(보존 근접 변형): {0}' -f $clearedKeep) (Convert-WorkerLogLineForGui $clearedKeep $false) $clearedKeep
  }
}

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
