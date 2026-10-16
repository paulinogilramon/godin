<#
.SYNOPSIS
  Hot-reload watcher for the Go + Odin toolkit.

.DESCRIPTION
  Watches .go, .odin and .h files. On change it rebuilds (Odin shared lib + Go
  app via `godin build`) and reruns the resulting executable. Ignores backup
  files (*~, *.tmp).

.PARAMETER IntervalMs
  Poll interval in milliseconds (default 800).

.PARAMETER Once
  Build once and exit (no watching). Useful for CI/validation.

.PARAMETER NoRun
  Watch and rebuild, but do not run the executable.

.EXAMPLE
  pwsh -File scripts/watch.ps1
  pwsh -File scripts/watch.ps1 -Once
#>
param(
  [int]$IntervalMs = 800,
  [switch]$Once,
  [switch]$NoRun
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$exeName = if ($env:OS -eq 'Windows_NT') { "app.exe" } else { "app" }
$app = Join-Path $root "build/$exeName"

function Get-Stamp {
  $dirs = @("go", "odin", "shared") | ForEach-Object { Join-Path $root $_ }
  $files = Get-ChildItem -Path $dirs -Recurse -File -Include *.go, *.odin, *.h -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '(~|\.tmp$)' }
  $parts = $files | Sort-Object FullName | ForEach-Object { "$($_.FullName):$($_.LastWriteTimeUtc.Ticks)" }
  return [string]::Join("|", $parts)
}

function Invoke-Build {
  Write-Host "[watch] building..." -ForegroundColor Cyan
  & (Join-Path $root "godin.ps1") build
  return $LASTEXITCODE -eq 0
}

$proc = $null

function Start-App {
  if ($NoRun) { return }
  if ($proc -and -not $proc.HasExited) {
    $proc.Kill()
    $proc.WaitForExit()
  }
  if (Test-Path $app) {
    $proc = Start-Process -FilePath $app -WorkingDirectory (Join-Path $root "build") -PassThru
    Write-Host "[watch] running $app (pid $($proc.Id))" -ForegroundColor Green
  }
}

if ($Once) {
  $ok = Invoke-Build
  if ($ok -and -not $NoRun) { Start-App; if ($proc) { $proc.WaitForExit() } }
  exit ($(if ($ok) { 0 } else { 1 }))
}

$last = Get-Stamp
if (Invoke-Build) { Start-App }
Write-Host "[watch] watching go/, odin/, shared/ (Ctrl+C to stop)" -ForegroundColor Yellow

try {
  while ($true) {
    Start-Sleep -Milliseconds $IntervalMs
    $now = Get-Stamp
    if ($now -ne $last) {
      $last = $now
      if (Invoke-Build) { Start-App }
    }
  }
} finally {
  if ($proc -and -not $proc.HasExited) { $proc.Kill() }
}
