# 어비스 커스텀 반복 GUI의 레이아웃·설정 저장·진행 연결 계약을 검사합니다.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'mabinogi_gui.ps1'
$gui = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8

$fails = 0
function Check-Pattern {
  param([string]$Name, [string]$Pattern)
  if ($gui -match $Pattern) { "OK   $Name" }
  else { "FAIL $Name"; $script:fails++ }
}
function Check-Absent {
  param([string]$Name, [string]$Pattern)
  if ($gui -notmatch $Pattern) { "OK   $Name" }
  else { "FAIL $Name"; $script:fails++ }
}

Check-Pattern '어비스에서도 커스텀 반복 선택 가능' `
  '\$supportsCustom\s*=\s*-not\s+\$isHunting[\s\S]{0,120}\$rbCustomRepeat\.Enabled\s*=\s*\$supportsCustom'
Check-Pattern '어비스 커스텀 GUI와 던전 커스텀 실행 상태 분리' `
  '\$isDungeonCustom\s*=\s*\$isDungeon\s+-and\s+\$isCustom[\s\S]{0,120}\$isAbyssCustom\s*=\s*\$isAbyss\s+-and\s+\$isCustom'
Check-Pattern '어비스 커스텀 혼자하기·함께하기 입력' `
  '\$rbAcrSolo\.Text\s*=\s*''혼자하기''[\s\S]{0,500}\$rbAcrParty\.Text\s*=\s*''함께하기'''
Check-Pattern '어비스 커스텀 난이도 드롭다운' `
  '\$cboAcrDifficulty\s*=\s*New-Object System\.Windows\.Forms\.ComboBox[\s\S]{0,1500}''게임 그대로'',\s*''입문'',\s*''어려움'',\s*''매우 어려움'''
Check-Pattern '함께하기에서 지옥 난이도 추가' `
  'if\s*\(\$rbAcrParty\.Checked\)[\s\S]{0,250}지옥\$acrHellLevel'
Check-Pattern '어비스 던전 드롭다운 3종' `
  '\$cboAcrDungeon\s*=\s*New-Object System\.Windows\.Forms\.ComboBox[\s\S]{0,700}''허상의 정박지'',\s*''광기의 동굴'',\s*''흩어진 물길'''
Check-Pattern '함께하기 매칭 3종' `
  '\$rbAcrChance\.Text\s*=\s*''우연한 만남''[\s\S]{0,600}\$rbAcrFindParty\.Text\s*=\s*''파티 찾기''[\s\S]{0,600}\$rbAcrPartyLead\.Text\s*=\s*''파티\(파티장\)'''
Check-Pattern '함께하기일 때만 매칭 줄 표시' `
  '\$acrPartyOn\s*=\s*\$isAbyssCustom\s+-and\s+\$rbAcrParty\.Checked[\s\S]{0,120}\$pnlAcrMatching\.Visible\s*=\s*\$acrPartyOn'
Check-Pattern '어비스 커스텀 리스트 열 구성' `
  "Columns\.Add\('방식'[\s\S]{0,300}Columns\.Add\('난이도'[\s\S]{0,300}Columns\.Add\('어비스 던전'[\s\S]{0,300}Columns\.Add\('매칭'"
Check-Pattern '목록 추가·삭제·이동 시 config 즉시 저장' `
  '\$btnAcrAdd\.Add_Click[\s\S]{0,1200}Save-CustomRepeatToConfig[\s\S]{0,1200}\$btnAcrDelete\.Add_Click[\s\S]{0,1000}Save-CustomRepeatToConfig[\s\S]{0,500}\$btnAcrUp\.Add_Click\(\{ Move-AbyssCustomListRow'
Check-Pattern '어비스 목록을 별도 config 섹션에 저장' `
  'function Set-AbyssCustomRepeatOnConfig[\s\S]{0,1800}abyssCustomRepeat'
Check-Pattern '어비스 진행 초기화 활성·전용 섹션 연결' `
  '\$btnAcrReset\.Enabled\s*=\s*\$true[\s\S]{0,900}Reset-CustomProgress\s+-SectionName\s+''abyssCustomRepeat'''
Check-Pattern '시작 시 어비스 진행 섹션 선택' `
  '\$script:customConfigSection\s*=\s*\$\(if\s*\(\$rbCatAbyss\.Checked\)\s*\{\s*''abyssCustomRepeat''\s*\}\s*else\s*\{\s*''customRepeat''\s*\}\)'
Check-Pattern '던전·어비스 완료 마커 파일 분리' `
  '\$customAbyssMarkerFile\s*=\s*Join-Path[^\r\n]*abyss_custom_done\.marker[\s\S]+\$script:customMarkerFile\s*=\s*\$\(if\s*\(\$rbCatAbyss\.Checked\)'
Check-Absent '자동화 실행 미지원 표기 제거' '자동화 실행 미지원'
Check-Absent '어비스 커스텀 시작 차단 제거' '어비스 커스텀 반복은 현재 자동화 실행을 지원하지 않습니다'
Check-Pattern '상세 설정 제목 통일' '\$grpContentDetail\.Text\s*=\s*''콘텐츠 상세 설정'''
Check-Pattern '커스텀 반복 중 사냥터 미지원 표기' `
  '\$rbCatHunting\.Text\s*=\s*\$\(if \(\$isCustom\) \{ ''사냥터\(미지원\)'' \} else \{ ''사냥터'' \}\)'

exit $fails
