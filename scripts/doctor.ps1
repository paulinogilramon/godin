<#
.SYNOPSIS
  Checks that the local toolchain can build and test this Go + Odin project.

.DESCRIPTION
  Runs read-only probes (no installs, no builds) and reports OK / WARN / FAIL
  for every dependency, with a hint when something is missing.

  Required: pwsh 7, go, odin, a native linker (MSVC link.exe on Windows,
  clang on Linux/macOS), gcc (cgo) and CGO_ENABLED=1.
  Optional: golangci-lint, docker.

  Exits 1 when a required dependency is missing, so it can gate CI.

.PARAMETER Quiet
  Only print problems and the final summary.

.EXAMPLE
  pwsh -File scripts/doctor.ps1
  godin doctor
#>
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$script:IsWin = ($env:OS -eq 'Windows_NT')
$script:OkCount = 0
$script:WarnCount = 0
$script:FailCount = 0
$script:Rows = [System.Collections.Generic.List[object]]::new()

function Add-Row([string]$Name, [string]$State, [string]$Detail) {
  switch ($State) {
    'OK' { $script:OkCount++ }
    'WARN' { $script:WarnCount++ }
    'FAIL' { $script:FailCount++ }
  }
  $script:Rows.Add([pscustomobject]@{ Name = $Name; State = $State; Detail = $Detail })
}

function Get-FirstLine([string]$exe, [string[]]$exeArgs) {
  try {
    $out = & $exe @exeArgs 2>&1 | Select-Object -First 1
    if ($null -eq $out) { return '' }
    return ([string]$out).Trim()
  } catch {
    return ''
  }
}

function Test-Tool {
  param(
    [string]$Name,
    [string]$Command,
    [string[]]$VersionArgs = @('--version'),
    [string]$Hint,
    [switch]$Optional
  )

  $cmd = Get-Command $Command -ErrorAction SilentlyContinue
  if (-not $cmd) {
    $state = if ($Optional) { 'WARN' } else { 'FAIL' }
    $detail = if ($Optional) { "not found (optional) — $Hint" } else { "not found — $Hint" }
    Add-Row $Name $state $detail
    return $null
  }

  $version = Get-FirstLine $cmd.Source $VersionArgs
  if (-not $version) { $version = $cmd.Source }
  Add-Row $Name 'OK' $version
  return $cmd.Source
}

# --- pwsh ---------------------------------------------------------------
$psMajor = $PSVersionTable.PSVersion.Major
if ($psMajor -ge 7) {
  Add-Row 'pwsh' 'OK' "$($PSVersionTable.PSVersion) ($([System.Diagnostics.Process]::GetCurrentProcess().Path))"
} else {
  Add-Row 'pwsh' 'WARN' "running Windows PowerShell $($PSVersionTable.PSVersion); install PowerShell 7 (winget install Microsoft.PowerShell)"
}

# --- go -----------------------------------------------------------------
$go = Test-Tool -Name 'go' -Command 'go' -VersionArgs @('version') `
  -Hint 'install from https://go.dev/dl/ or: scoop install go'

if ($go) {
  $cgo = Get-FirstLine 'go' @('env', 'CGO_ENABLED')
  if ($cgo -eq '1') {
    Add-Row 'cgo' 'OK' 'CGO_ENABLED=1'
  } else {
    Add-Row 'cgo' 'FAIL' "CGO_ENABLED=$cgo — run: go env -w CGO_ENABLED=1"
  }
}

# --- odin ---------------------------------------------------------------
$null = Test-Tool -Name 'odin' -Command 'odin' -VersionArgs @('version') `
  -Hint 'install from https://odin-lang.org/docs/install/ or: scoop install odin'

# --- linker (Odin shared library) ---------------------------------------
$linker = $null
if ($script:IsWin) {
  $linker = (Get-Command 'link.exe' -ErrorAction SilentlyContinue).Source
  if (-not $linker) {
    $found = Get-ChildItem -Path "$env:ProgramFiles\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe" `
      -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { $linker = $found.FullName }
  }
  if ($linker) {
    Add-Row 'link.exe' 'OK' $linker
  } else {
    Add-Row 'link.exe' 'FAIL' 'not found — install Visual Studio Build Tools with "Desktop development with C++" (godin looks under Program Files, PATH not required)'
  }
} else {
  $linker = (Get-Command 'clang' -ErrorAction SilentlyContinue).Source
  if ($linker) {
    $v = Get-FirstLine $linker @('--version')
    Add-Row 'clang' 'OK' $v
  } else {
    Add-Row 'clang' 'FAIL' 'not found — install clang (Debian/Ubuntu: sudo apt-get install clang)'
  }
}

# --- gcc (cgo toolchain) ------------------------------------------------
$null = Test-Tool -Name 'gcc' -Command 'gcc' -VersionArgs @('--version') `
  -Hint 'install mingw (Windows: scoop install mingw) or build-essential (Debian/Ubuntu)'

# --- optional -----------------------------------------------------------
$null = Test-Tool -Name 'golangci-lint' -Command 'golangci-lint' -VersionArgs @('version', '--short') `
  -Hint 'go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.14.0' -Optional

$null = Test-Tool -Name 'docker' -Command 'docker' -VersionArgs @('--version') `
  -Hint 'only needed for: godin docker-linux' -Optional

# --- report -------------------------------------------------------------
$colors = @{ OK = 'Green'; WARN = 'Yellow'; FAIL = 'Red' }
if (-not $Quiet) {
  Write-Host ''
  Write-Host 'godin doctor — toolchain' -ForegroundColor Cyan
  Write-Host ('-' * 64)
}
foreach ($row in $script:Rows) {
  if ($Quiet -and $row.State -eq 'OK') { continue }
  Write-Host ("{0,-14} {1,-5} {2}" -f $row.Name, $row.State, $row.Detail) -ForegroundColor $colors[$row.State]
}
if (-not $Quiet) { Write-Host ('-' * 64) }

$summary = "$($script:OkCount) ok, $($script:WarnCount) warn, $($script:FailCount) missing"
if ($script:FailCount -gt 0) {
  Write-Host "godin doctor: $summary" -ForegroundColor Red
  Write-Host 'Fix the FAIL entries above, then re-run: godin doctor' -ForegroundColor Yellow
  exit 1
}

Write-Host "godin doctor: $summary" -ForegroundColor Green
exit 0
