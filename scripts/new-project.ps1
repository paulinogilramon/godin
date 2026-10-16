<#
.SYNOPSIS
  Scaffolds a new Go + Odin (C ABI) project from this toolkit.

.DESCRIPTION
  Copies the toolkit into a new directory, excluding VCS/build/dev-only files,
  then rewrites the Go module path and the GitHub badge placeholders in README.

.PARAMETER Path
  Destination directory for the new project.

.PARAMETER Module
  Go module path, e.g. github.com/acme/mytool.

.PARAMETER Name
  Project/repo name used for badges (defaults to the last module segment).

.PARAMETER Force
  Overwrite the destination directory if it exists.

.EXAMPLE
  pwsh -File scripts/new-project.ps1 -Path ..\mytool -Module github.com/acme/mytool
#>
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)][string]$Module,
  [string]$Name = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$src = Split-Path -Parent $PSScriptRoot
$dst = [System.IO.Path]::GetFullPath($Path)

if ($Module -notmatch '^[^/]+/[^/]+/.+$') {
  throw "Module must look like host/owner/repo (got: $Module)"
}

$segments = $Module -split '/'
$owner = $segments[-2]
$repo = $segments[-1]
if ([string]::IsNullOrWhiteSpace($Name)) { $Name = $repo }

if (Test-Path -LiteralPath $dst) {
  if (-not $Force) { throw "Destination already exists: $dst (use -Force to overwrite)" }
  Remove-Item -LiteralPath $dst -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $dst | Out-Null

$excludeDirs = @('.git', 'build', '.vs', '.idea', 'node_modules', '__pycache__', '.venv')
$excludeNames = @('GO-ODIN-TOOLKIT-PLAN.md')

$srcFull = [System.IO.Path]::GetFullPath($src)
Get-ChildItem -LiteralPath $srcFull -Recurse -Force -File | ForEach-Object {
  $rel = $_.FullName.Substring($srcFull.Length + 1)
  $parts = $rel -split '[\\/]'
  $inExcluded = $false
  foreach ($p in $parts[0..([Math]::Max(0, $parts.Length - 2))]) {
    if ($excludeDirs -contains $p) { $inExcluded = $true; break }
  }
  if ($inExcluded -or ($excludeNames -contains $_.Name)) { return }
  if ($_.Name -like '*.tmp' -or $_.Name -like '*~' -or $_.Name -like '*.log') { return }

  $target = Join-Path $dst $rel
  $dir = Split-Path -Parent $target
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Copy-Item -LiteralPath $_.FullName -Destination $target -Force
}

# Rewrite Go module path.
$gomod = Join-Path $dst "go/go.mod"
$lines = Get-Content -LiteralPath $gomod
$lines = $lines | ForEach-Object {
  if ($_ -match '^module\s+') { "module $Module" } else { $_ }
}
Set-Content -LiteralPath $gomod -Value $lines -Encoding utf8

# Rewrite README badge placeholders and project title.
$readme = Join-Path $dst "README.md"
if (Test-Path -LiteralPath $readme) {
  $lines = Get-Content -LiteralPath $readme
  if ($lines.Count -gt 0 -and $lines[0] -match '^#\s+(.*)$') {
    $rest = $Matches[1] -replace '^godin\b', $Name
    $lines[0] = "# $rest"
  }
  $text = ($lines -join "`n")
  $text = $text.Replace("OWNER/godin", "$owner/$repo").Replace("OWNER", $owner)
  Set-Content -LiteralPath $readme -Value $text -Encoding utf8 -NoNewline
}

Write-Host ""
Write-Host "New project created: $dst" -ForegroundColor Green
Write-Host "  module : $Module"
Write-Host "  name   : $Name"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  cd $Path"
Write-Host "  godin build"
Write-Host "  godin run"
Write-Host "  godin test"
