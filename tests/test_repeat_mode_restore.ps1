# 반복 모드 저장/복원이 [커스텀 반복] 선택을 깨지 않는지 (2026-08-10 11차 점검에서 신설).
#
# 왜 필요한가: 무한 / 횟수 / 시간 / **커스텀 반복** 네 라디오가 **같은 GroupBox** 소속이라
# WinForms 자동 배타가 걸립니다. 10차에서 '반복 모드 복원'을 넣으면서 그 사실을 놓쳐,
# 컨트롤 패널을 켤 때마다 커스텀 선택이 조용히 풀리고 리스트가 통째로 무시됐습니다
# (배포 차단급). 게다가 그 CheckedChanged 가 customEnabledWish 까지 지워 복구도 막혔습니다.
#
# 이 테스트는 **실제 WinForms 라디오**로 그 배타 관계를 재현해 계약을 못 박습니다.
# 소스 문자열만 보면 '순서'를 놓치기 쉬워, 여기서는 동작으로 확인합니다.
$ErrorActionPreference = 'Stop'
$fails = 0
$projectRoot = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $projectRoot 'mabinogi_gui.ps1'
$guiSource = [IO.File]::ReadAllText($guiPath)

function Assert-Case {
  param([string]$Name, $Actual, $Expect)
  if ("$Actual" -eq "$Expect") { "OK   {0}: {1}" -f $Name, $Actual }
  else { "FAIL {0}: 실제 [{1}] 기대 [{2}]" -f $Name, $Actual, $Expect; $script:fails++ }
}

Add-Type -AssemblyName System.Windows.Forms

# ── ① 실제 라디오 그룹으로 배타 관계와 복원 순서를 재현 ─────────────────────
function Test-RestoreKeepsCustom {
  # 반환: 복원이 끝난 뒤 '커스텀이 여전히 선택돼 있는가 / wish 가 살아 있는가'
  param([string]$SavedMode, [bool]$CustomEnabled, [bool]$GuardEnabled)
  $grp = New-Object System.Windows.Forms.GroupBox
  $rbInfinite = New-Object System.Windows.Forms.RadioButton
  $rbCount = New-Object System.Windows.Forms.RadioButton
  $rbTime = New-Object System.Windows.Forms.RadioButton
  $rbCustom = New-Object System.Windows.Forms.RadioButton
  foreach ($rb in @($rbInfinite, $rbCount, $rbTime, $rbCustom)) { $grp.Controls.Add($rb) }
  $script:wish = $false
  $script:crSwitching = $false
  # ★ 여기서 .GetNewClosure() 를 쓰면 **이 프로젝트가 문서화한 PS 5.1 함정**을 그대로 밟습니다:
  #   함수 안에서 만든 클로저는 새 동적 모듈을 만들고 **지역 변수만** 복사하므로 $script: 대입이
  #   테스트의 스크립트 스코프에 닿지 않습니다(작성 중 실제로 밟아 wish 단언 4건이 헛돌았습니다).
  #   센더는 $this 로 받고 클로저는 만들지 않습니다.
  $rbCustom.Add_CheckedChanged({
      if (-not $script:crSwitching) { $script:wish = [bool]$this.Checked }
    })
  try {
    # (1) 먼저 커스텀 선택 의도를 복원 (본체 Load-SettingsToUi 앞부분과 같은 순서)
    $script:wish = $CustomEnabled
    if ($CustomEnabled) { $rbCustom.Checked = $true }
    # (2) 그다음 상단 모드 복원 - 가드가 있으면 커스텀일 때 건너뜀
    if ((-not $GuardEnabled) -or (-not $rbCustom.Checked)) {
      switch ($SavedMode) {
        'count' { $rbCount.Checked = $true }
        'time' { $rbTime.Checked = $true }
        default { $rbInfinite.Checked = $true }
      }
    }
    return @{ CustomChecked = [bool]$rbCustom.Checked; Wish = [bool]$script:wish }
  } finally {
    foreach ($rb in @($rbInfinite, $rbCount, $rbTime, $rbCustom)) { $rb.Dispose() }
    $grp.Dispose()
  }
}

# 가드가 없으면(10차 상태) 저장값이 무엇이든 커스텀이 풀립니다 - 그것이 그 회귀의 정체입니다
foreach ($mode in @('', 'infinite', 'count', 'time')) {
  $broken = Test-RestoreKeepsCustom -SavedMode $mode -CustomEnabled $true -GuardEnabled $false
  Assert-Case "가드 없음(회귀 재현): mode='$mode' 이면 커스텀이 풀린다" $broken.CustomChecked $false
  Assert-Case "가드 없음(회귀 재현): wish 까지 지워진다 mode='$mode'" $broken.Wish $false
}
# 가드가 있으면 네 경우 모두 커스텀이 유지돼야 합니다
foreach ($mode in @('', 'infinite', 'count', 'time')) {
  $fixed = Test-RestoreKeepsCustom -SavedMode $mode -CustomEnabled $true -GuardEnabled $true
  Assert-Case "가드 있음: mode='$mode' 여도 커스텀 유지" $fixed.CustomChecked $true
  Assert-Case "가드 있음: wish 보존 mode='$mode'" $fixed.Wish $true
}
# 커스텀이 꺼져 있으면 저장된 모드가 정상 복원돼야 합니다 (가드가 과잉 차단하지 않는지)
$plain = Test-RestoreKeepsCustom -SavedMode 'count' -CustomEnabled $false -GuardEnabled $true
Assert-Case '커스텀 아님: 상단 모드 복원이 막히지 않는다' $plain.CustomChecked $false

# ── ② 배선 가드: 본체에 그 가드가 실제로 있는가 ─────────────────────────────
Assert-Case '배선: 커스텀이면 상단 모드 복원을 건너뛴다' `
  ([bool]($guiSource -match '(?s)if \(-not \$rbCustomRepeat\.Checked\) \{\s*\r?\n\s*try \{\s*\r?\n\s*switch \(\[string\]\$cfg\.repeat\.mode\)')) 'True'
# 저장 쪽도 같은 계약이어야 합니다 - 커스텀 중에 'infinite' 로 덮으면 사용자가 커스텀을 껐을 때
# 원래 쓰던 '횟수 N' 이 사라집니다
Assert-Case '배선: 커스텀 중에는 상단 모드를 덮어쓰지 않는다' `
  ([bool]($guiSource -match '(?s)if \(-not \$rbCustomRepeat\.Checked\) \{\s*\r?\n\s*\$repeatMode = ')) 'True'
# 네 라디오가 같은 그룹이라는 사실 자체도 고정합니다 (누가 그룹을 나누면 이 계약의 전제가 바뀜)
Assert-Case '전제: 네 라디오가 같은 GroupBox 소속' `
  ([regex]::Matches($guiSource, '\$grpRepeat\.Controls\.Add\(\$rb(Infinite|Count|Time|CustomRepeat)\)').Count) 4

exit $fails
