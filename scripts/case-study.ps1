# Case study: image blur, Go vs Odin across the C ABI.
#
# Produces build/case-study/results.txt with:
#   - versions and hardware
#   - correctness (Go + Odin tests, cross-impl hashes)
#   - benchmarks for three Odin build variants (minimal / speed / speed+nobounds)
#   - end-to-end CLI timings on 1080p and 4K images (Go vs Odin, 5 repeats)
#   - optional Linux (Docker) hashes + benchmarks, to compare portability
#
# Usage:
#   pwsh -NoProfile -File scripts/case-study.ps1
#   pwsh -NoProfile -File scripts/case-study.ps1 -SkipDocker -BenchTime 500ms
#
# Everything is written under build/ (gitignored); the report's tables are
# transcribed from results.txt.

[CmdletBinding()]
param(
  [string]$BenchTime = '300ms',
  [int]$BenchCount = 3,
  [int]$Cooldown = 15,
  [switch]$SkipDocker
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$run = Join-Path $root 'build/case-study'
$null = New-Item -ItemType Directory -Force -Path $run
$log = Join-Path $run 'results.txt'
$pwsh = (Get-Command pwsh).Source
$godin = Join-Path $root 'godin.ps1'
$sep = [IO.Path]::PathSeparator
$basePath = $env:PATH
$baseLd = $env:LD_LIBRARY_PATH
$blur = Join-Path $root $(if ($IsWindows) { 'build/blur.exe' } else { 'build/blur' })

Set-Content -LiteralPath $log -Encoding utf8 -Value @"
godin case study: image blur (Go vs Odin via cgo)
started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
root:    $root
bench:   benchtime=$BenchTime count=$BenchCount

"@

function Invoke-Step {
  param([string]$Title, [scriptblock]$Body)
  Write-Host "`n### $Title" -ForegroundColor Cyan
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $out = & $Body 2>&1 | Out-String
  $code = $LASTEXITCODE
  $sw.Stop()
  $text = "`n### $Title`n$out`n(exit $code, $($sw.Elapsed.ToString('mm\:ss')))"
  Add-Content -LiteralPath $log -Value $text -Encoding utf8
  Write-Host $out
  if ($code -ne 0) { throw "step failed ($code): $Title" }
}

Invoke-Step 'versions / hardware' {
  & go version
  & odin version
  if ($IsWindows) {
    Get-CimInstance Win32_Processor |
      Select-Object -First 1 Name, NumberOfCores, NumberOfLogicalProcessors |
      Format-List | Out-String
  } else {
    & uname -a
  }
}

Invoke-Step 'build library + app' {
  & $pwsh -NoProfile -File $godin build
}

$img1080 = Join-Path $run 'synthetic-1920x1080.png'
Invoke-Step 'build CLI + generate 1080p input' {
  & $pwsh -NoProfile -File $godin blur -gen $img1080 -w 1920 -h 1080 -seed 7
}

Invoke-Step 'correctness: go test + odin test' {
  & $pwsh -NoProfile -File $godin test
}

# ------------------------------------------------------- end-to-end CLI (Win) --
$env:PATH = "$(Join-Path $root 'build')$sep$basePath"
Invoke-Step 'CLI 1920x1080 box r=8 (go vs odin, 5 repeats)' {
  & $blur -in $img1080 -op box -radius 8 -impl both -repeat 5 `
    -out (Join-Path $run 'out-1080p-box.png')
}
Invoke-Step 'CLI 1920x1080 gauss (go vs odin, 5 repeats)' {
  & $blur -in $img1080 -op gauss -impl both -repeat 5 `
    -out (Join-Path $run 'out-1080p-gauss.png')
}

$img4k = Join-Path $run 'synthetic-3840x2160.png'
Invoke-Step 'CLI 3840x2160 gauss (go vs odin, 5 repeats)' {
  & $blur -gen $img4k -w 3840 -h 2160 -seed 11 -quiet
  & $blur -in $img4k -op gauss -impl both -repeat 5 `
    -out (Join-Path $run 'out-4k-gauss.png')
}
$env:PATH = $basePath

# ---------------------------------------------------------------- variants --
$variants = @(
  [pscustomobject]@{ Name = 'minimal'; Opt = 'minimal'; NoBounds = $false },
  [pscustomobject]@{ Name = 'speed'; Opt = 'speed'; NoBounds = $false },
  [pscustomobject]@{ Name = 'speed-nobounds'; Opt = 'speed'; NoBounds = $true }
)

foreach ($v in $variants) {
  $out = "build/case-study/variants/$($v.Name)"
  Invoke-Step "build odin variant: $($v.Name)" {
    $a = @('-NoProfile', '-File', $godin, 'odin-variant', '-Out', $out, '-Opt', $v.Opt)
    if ($v.NoBounds) { $a += '-NoBounds' }
    & $pwsh @a
  }
}

# -------------------------------------------------------------- benchmarks --
# Laptops throttle under sustained load, and a benchmark suite takes tens of
# seconds. Keep the variant comparison short and contiguous (1080p only), then
# run the full size/tile matrix for the release setting alone, with cooldowns.
# `-cpu 1` pins GOMAXPROCS: the kernels are single-threaded, so this removes
# runtime scheduling noise without changing the work being measured.
$shortBench = 'BenchmarkBox/1920x1080|BenchmarkGauss/1920x1080'
$fullBench = 'BenchmarkBox|BenchmarkGauss|BenchmarkCallOverhead|BenchmarkTiles'

function Invoke-Bench {
  param([string]$Title, [string]$Dir, [string]$Regex, [string]$Time, [int]$Count)
  Invoke-Step $Title {
    $env:PATH = "$Dir$sep$basePath"
    if (-not $IsWindows) { $env:LD_LIBRARY_PATH = "$Dir$sep$baseLd" }
    Push-Location (Join-Path $root 'go')
    try {
      & go test ./blur -run '^$' -cpu 1 -bench $Regex -benchmem "-benchtime=$Time" "-count=$Count"
    } finally {
      Pop-Location
      $env:PATH = $basePath
      if (-not $IsWindows) { $env:LD_LIBRARY_PATH = $baseLd }
    }
  }
}

Write-Host "`ncooldown $Cooldown s before benchmarks" -ForegroundColor DarkGray
Start-Sleep -Seconds $Cooldown

foreach ($v in $variants) {
  $dir = Join-Path $root "build/case-study/variants/$($v.Name)"
  Invoke-Bench "benchmarks 1080p: $($v.Name)" $dir $shortBench $BenchTime $BenchCount
  Start-Sleep -Seconds $Cooldown
}

Invoke-Bench 'benchmarks full matrix: speed (release setting)' `
  (Join-Path $root 'build/case-study/variants/speed') $fullBench $BenchTime $BenchCount

# -------------------------------------------------------------- Linux/Docker --
$dockerOk = $false
if (-not $SkipDocker) {
  & docker info *> $null
  $dockerOk = ($LASTEXITCODE -eq 0)
}
if ($dockerOk) {
  Invoke-Step 'linux: docker build' {
    Push-Location $root
    try { & docker build -t godin-linux . } finally { Pop-Location }
  }
  Invoke-Step 'linux: hashes + benchmarks (same CPU, libgodin.so)' {
    & docker run --rm godin-linux sh -c @'
set -e
LD_LIBRARY_PATH=/src/build ./build/blur -gen /tmp/in-1080.png -w 1920 -h 1080 -seed 7 -quiet
LD_LIBRARY_PATH=/src/build ./build/blur -in /tmp/in-1080.png -op gauss -impl both -repeat 5
LD_LIBRARY_PATH=/src/build ./build/blur -in /tmp/in-1080.png -op box -radius 8 -impl both -repeat 5
cd /src/go
LD_LIBRARY_PATH=/src/build go test ./blur -run '^$' -cpu 1 -bench 'BenchmarkBox|BenchmarkGauss|BenchmarkCallOverhead|BenchmarkTiles' -benchmem -benchtime 300ms -count 1
'@
  }
} else {
  Add-Content -LiteralPath $log -Value "`n### linux: skipped (docker unavailable or -SkipDocker)"
}

# ------------------------------------------------------------------ summary --
$hashes = Select-String -LiteralPath $log -Pattern 'sha256=([0-9a-f]{64})' |
  ForEach-Object { $_.Matches[0].Groups[1].Value } |
  Sort-Object -Unique
$summary = @"

### summary
distinct pixel hashes (expected 3: box 1080p, gauss 1080p, gauss 4K): $($hashes.Count)
$($hashes -join "`n")
finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
"@
Add-Content -LiteralPath $log -Value $summary -Encoding utf8
Write-Host $summary -ForegroundColor Green

if ($hashes.Count -ne 3) {
  throw "unexpected pixel hash count: $($hashes.Count) (Go/Odin or Windows/Linux disagree)"
}
