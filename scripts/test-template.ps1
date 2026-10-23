<#
.SYNOPSIS
  End-to-end smoke test of the reusable template.

.DESCRIPTION
  1. Scaffolds a full project with scripts/new-project.ps1 into
     build/template-smoke, builds it with its own godin runner and asserts the
     demo output.
  2. Assembles the minimal templates/interop-cgo skeleton into
     build/template-mini (using the scaffolded runner) and builds/runs it.

  Both artifacts are removed on success unless -Keep is passed. Exits 1 on the
  first failure, so it can gate CI.

.EXAMPLE
  pwsh -File scripts/test-template.ps1
  godin test-template
#>
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$isWin = ($env:OS -eq 'Windows_NT')
$exeName = if ($isWin) { 'app.exe' } else { 'app' }
$buildDir = Join-Path $root 'build'
$scaffold = Join-Path $buildDir 'template-smoke'
$mini = Join-Path $buildDir 'template-mini'
$created = @()

function Step([string]$msg) { Write-Host "[template] $msg" -ForegroundColor Cyan }

function Invoke-Pwsh([string]$script, [string[]]$scriptArgs) {
  & pwsh -NoProfile -File $script @scriptArgs
  if ($LASTEXITCODE -ne 0) { throw "failed: $script $($scriptArgs -join ' ') (exit $LASTEXITCODE)" }
}

function Assert-Contains([string]$text, [string]$needle, [string]$what) {
  if ($text -notmatch [regex]::Escape($needle)) {
    throw "${what}: expected output to contain '$needle'. Got:`n$text"
  }
}

try {
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

  # --- 1) full scaffold --------------------------------------------------
  Step "scaffolding -> $scaffold"
  if (Test-Path -LiteralPath $scaffold) { Remove-Item -LiteralPath $scaffold -Recurse -Force }
  Invoke-Pwsh (Join-Path $PSScriptRoot 'new-project.ps1') @('-Path', $scaffold, '-Module', 'example.com/smoke/template')
  $created += $scaffold

  Step 'building scaffold'
  Invoke-Pwsh (Join-Path $scaffold 'godin.ps1') @('build')

  Step 'running scaffold'
  $env:Path = "$(Join-Path $scaffold 'build');$env:Path"
  if (-not $isWin) { $env:LD_LIBRARY_PATH = "$(Join-Path $scaffold 'build'):$($env:LD_LIBRARY_PATH)" }
  $out = & (Join-Path $scaffold "build/$exeName") 2>&1 | Out-String
  Assert-Contains $out 'godin_add(2, 3) = 5' 'scaffold run'

  # --- 2) minimal template ----------------------------------------------
  Step "assembling minimal template -> $mini"
  if (Test-Path -LiteralPath $mini) { Remove-Item -LiteralPath $mini -Recurse -Force }
  foreach ($d in @('go', 'odin', 'shared')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $mini $d) | Out-Null
  }
  $tpl = Join-Path $root 'templates/interop-cgo'
  Copy-Item (Join-Path $tpl 'main.go') (Join-Path $mini 'go/main.go')
  Copy-Item (Join-Path $tpl 'lib.odin') (Join-Path $mini 'odin/lib.odin')
  Copy-Item (Join-Path $tpl 'shared/godin.h') (Join-Path $mini 'shared/godin.h')
  foreach ($f in @('godin.ps1', 'godin.cmd', 'godin.sh')) {
    Copy-Item (Join-Path $scaffold $f) (Join-Path $mini $f)
  }
  Set-Content -Path (Join-Path $mini 'go/go.mod') -Value "module example.com/smoke/mini`n`ngo 1.22`n" -NoNewline
  $created += $mini

  Step 'building minimal template'
  Invoke-Pwsh (Join-Path $mini 'godin.ps1') @('build')

  Step 'running minimal template'
  $env:Path = "$(Join-Path $mini 'build');$env:Path"
  if (-not $isWin) { $env:LD_LIBRARY_PATH = "$(Join-Path $mini 'build'):$($env:LD_LIBRARY_PATH)" }
  $out = & (Join-Path $mini "build/$exeName") 2>&1 | Out-String
  Assert-Contains $out 'godin_add(2, 3) = 5' 'minimal template run'

  Write-Host '[template] OK: scaffold + minimal template build and run' -ForegroundColor Green
} finally {
  if (-not $Keep) {
    foreach ($dir in $created) {
      Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
  } else {
    Write-Host "[template] kept: $($created -join ', ')" -ForegroundColor Yellow
  }
}
