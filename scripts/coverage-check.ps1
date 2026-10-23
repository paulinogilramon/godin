<#
.SYNOPSIS
  Fails when Go statement coverage is below a threshold.

.DESCRIPTION
  Reads the profile produced by `godin cover` (default build/coverage.out),
  parses the `total:` line of `go tool cover -func` and compares it with -Min.
  Uses invariant culture so it behaves the same under es-ES/de-DE locales.

.EXAMPLE
  pwsh -File scripts/coverage-check.ps1 -Min 95
#>
param(
  [double]$Min = 95,
  [string]$Profile = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Profile) { $Profile = Join-Path $root 'build/coverage.out' }

if (-not (Test-Path -LiteralPath $Profile)) {
  Write-Host "coverage: profile not found: $Profile (run: godin cover)" -ForegroundColor Red
  exit 1
}

$goDir = Join-Path $root 'go'
Push-Location $goDir
try {
  $report = & go tool cover "-func=$Profile" 2>&1
  $code = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($code -ne 0) {
  Write-Host 'coverage: go tool cover failed' -ForegroundColor Red
  $report | Write-Host
  exit 1
}

$totalLine = $report | Select-String -Pattern '^total:\s+\(statements\)\s+([0-9.]+)%$' | Select-Object -Last 1
if (-not $totalLine) {
  Write-Host 'coverage: could not parse the total line' -ForegroundColor Red
  exit 1
}

$total = [double]::Parse($totalLine.Matches[0].Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
$minText = $Min.ToString([System.Globalization.CultureInfo]::InvariantCulture)
if ($total -lt $Min) {
  Write-Host ("coverage: {0:N1}% < {1}% minimum" -f $total, $Min) -ForegroundColor Red
  exit 1
}

Write-Host ("coverage: {0:N1}% >= {1}% minimum" -f $total, $Min) -ForegroundColor Green
exit 0
