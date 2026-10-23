<#
.SYNOPSIS
  godin — task runner for the Go + Odin (C ABI) toolkit.

.DESCRIPTION
  Replaces `just`. Runs on PowerShell 7 (pwsh) on Windows and Linux/macOS.
  Invoke as:  godin <command> [args...]   (via godin.cmd / godin.sh wrappers)
  or:         pwsh -NoProfile -File godin.ps1 <command> [args...]

.EXAMPLE
  godin build
  godin run
  godin new ..\mytool github.com/acme/mytool
#>

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:IsWin = ($env:OS -eq 'Windows_NT')
$script:Argv = @($args)
$script:GodinVersion = '0.5.0'

function Die([string]$msg) {
  Write-Host "godin: $msg" -ForegroundColor Red
  exit 1
}

function Check([string]$what) {
  if ($LASTEXITCODE -ne 0) { Die "$what failed (exit $LASTEXITCODE)" }
}

# Odin's shared-library build needs MSVC's link.exe on Windows; ensures build/ exists.
function Add-Msvc {
  if ($script:IsWin) {
    $lk = Get-ChildItem -Path "$env:ProgramFiles\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe" `
      -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($lk) { $env:Path = "$($lk.DirectoryName);$env:Path" }
  }
  New-Item -ItemType Directory -Force -Path (Join-Path $script:Root 'build') | Out-Null
}

# Make build/ resolvable at runtime for go test / running the app.
function Add-LibPath {
  $b = Join-Path $script:Root 'build'
  if ($script:IsWin) {
    $env:Path = "$b;$env:Path"
  } else {
    $env:LD_LIBRARY_PATH = "${b}:$($env:LD_LIBRARY_PATH)"
  }
}

function Test-Has([string]$name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------- commands --

function cmd-odin-lib {
  Add-Msvc
  $out = if ($script:IsWin) { 'build/godin.dll' } else { 'build/libgodin.so' }
  & odin build odin -build-mode:shared "-out:$out"
  Check 'odin build'
}

function cmd-go-build {
  cmd-odin-lib
  $o = if ($script:IsWin) { '../build/app.exe' } else { '../build/app' }
  Push-Location (Join-Path $script:Root 'go')
  try { & go build -o $o .; Check 'go build' } finally { Pop-Location }
}

function cmd-build { cmd-go-build }

function cmd-run {
  cmd-go-build
  $name = if ($script:IsWin) { 'build/app.exe' } else { 'build/app' }
  $exe = Join-Path $script:Root $name
  & $exe
  Check 'run'
}

function cmd-test {
  cmd-odin-lib
  Add-LibPath
  Push-Location (Join-Path $script:Root 'go')
  try { & go test ./...; $g = $LASTEXITCODE } finally { Pop-Location }
  Add-Msvc
  & odin test odin
  $o = $LASTEXITCODE
  if ($g -ne 0) { Die 'go test failed' }
  if ($o -ne 0) { Die 'odin test failed' }
}

# Go race detector (cgo + Odin DLL); slower, so not part of `godin test`.
function cmd-test-race {
  cmd-odin-lib
  Add-LibPath
  Push-Location (Join-Path $script:Root 'go')
  try { & go test -race ./...; Check 'go test -race' } finally { Pop-Location }
}

function cmd-cover {
  cmd-odin-lib
  Add-LibPath
  $cov = '../build/coverage.out'
  $html = '../build/coverage.html'
  Push-Location (Join-Path $script:Root 'go')
  try {
    & go test '-covermode=atomic' "-coverprofile=$cov" './...'; Check 'go test -cover'
    & go tool cover "-func=$cov"; Check 'go cover -func'
    & go tool cover "-html=$cov" "-o=$html"; Check 'go cover -html'
  } finally { Pop-Location }
  Write-Host 'coverage -> build/coverage.html' -ForegroundColor Green
}

function cmd-fmt {
  & gofmt -w go; Check 'gofmt'
  & odin strip-semicolon odin -no-entry-point | Out-Null
  Check 'odin strip-semicolon'
}

function cmd-fmt-check {
  $diff = & gofmt -l go
  if ($diff) {
    Write-Host 'gofmt required on:' -ForegroundColor Red
    $diff
    exit 1
  }
  & odin strip-semicolon odin -no-entry-point | Out-Null
  & git diff --exit-code -- odin
  if ($LASTEXITCODE -ne 0) { Die 'odin strip-semicolon required (run godin fmt)' }
}

function cmd-lint {
  Push-Location (Join-Path $script:Root 'go')
  try { & go vet ./...; $gv = $LASTEXITCODE } finally { Pop-Location }
  if ($gv -ne 0) { Die 'go vet failed' }
  & odin check odin -no-entry-point; Check 'odin check'
  if (Test-Has 'golangci-lint') {
    Push-Location (Join-Path $script:Root 'go')
    try { & golangci-lint run; $g = $LASTEXITCODE } finally { Pop-Location }
    if ($g -ne 0) { Die 'golangci-lint failed' }
  } else {
    Write-Host 'golangci-lint not installed; skipping' -ForegroundColor Yellow
  }
}

function cmd-lint-go {
  if (-not (Test-Has 'golangci-lint')) { Die 'golangci-lint not installed' }
  Push-Location (Join-Path $script:Root 'go')
  try { & golangci-lint run; $g = $LASTEXITCODE } finally { Pop-Location }
  if ($g -ne 0) { Die 'golangci-lint failed' }
}

function cmd-doctor {
  & (Join-Path $script:Root 'scripts/doctor.ps1')
  Check 'doctor'
}

function cmd-version {
  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
  Write-Host "godin $($script:GodinVersion)"
  Write-Host "platform  $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription) ($([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture))"
  $go = Get-Command go -ErrorAction SilentlyContinue
  if ($go) { Write-Host "go        $(& go version)" } else { Write-Host 'go        (not found)' }
  $odin = Get-Command odin -ErrorAction SilentlyContinue
  if ($odin) { Write-Host "odin      $((& odin version 2>&1 | Select-Object -First 1))" } else { Write-Host 'odin      (not found)' }
  if ($pwsh) { Write-Host "pwsh      $($PSVersionTable.PSVersion)" }
}

# Full pre-push gate: formatting, lint and tests.
function cmd-check {
  cmd-fmt-check
  cmd-lint
  cmd-test
  Write-Host 'godin: all checks passed' -ForegroundColor Green
}

# Scaffold a project from this toolkit and build/run it end-to-end.
function cmd-test-template {
  & (Join-Path $script:Root 'scripts/test-template.ps1')
  Check 'test-template'
}

function cmd-clean {
  foreach ($p in @('build', '.vs', '.idea')) {
    Remove-Item -Recurse -Force (Join-Path $script:Root $p) -ErrorAction SilentlyContinue
  }
}

function cmd-watch {
  & (Join-Path $script:Root 'scripts/watch.ps1')
}

function cmd-watch-once {
  & (Join-Path $script:Root 'scripts/watch.ps1') -Once -NoRun
}

function cmd-docker-linux {
  Push-Location $script:Root
  try {
    & docker build -t godin-linux .; Check 'docker build'
    New-Item -ItemType Directory -Force -Path (Join-Path $script:Root 'build/linux') | Out-Null
    $cid = (& docker create godin-linux).Trim()
    & docker cp "${cid}:/src/build/libgodin.so" (Join-Path $script:Root 'build/linux/')
    & docker cp "${cid}:/src/build/app" (Join-Path $script:Root 'build/linux/')
    & docker rm $cid | Out-Null
  } finally { Pop-Location }
  Write-Host 'linux artifacts -> build/linux/' -ForegroundColor Green
}

function cmd-docker-linux-run {
  Push-Location $script:Root
  try {
    & docker build -t godin-linux .; Check 'docker build'
    & docker run --rm godin-linux ./build/app; Check 'docker run'
  } finally { Pop-Location }
}

function cmd-docker-shell {
  & docker run --rm -it -v "${script:Root}:/src" -w /src godin-odin bash
}

function cmd-new {
  param($rest)
  if ($rest.Count -lt 2) { Die 'usage: godin new <path> <module>' }
  & (Join-Path $script:Root 'scripts/new-project.ps1') -Path $rest[0] -Module $rest[1]
}

function Show-Help {
  Write-Host @"
godin — task runner (Go + Odin, C ABI)

  godin doctor             check the local toolchain (exit 1 if incomplete)
  godin version            runner + toolchain versions
  godin check              fmt-check + lint + test (pre-push gate)
  godin build              Odin shared lib + Go app
  godin run                build + run the app
  godin test               go test + odin test
  godin test-race          go test -race (cgo + Odin DLL)
  godin test-template      scaffold + build + run the template (smoke)
  godin cover              Go coverage -> build/coverage.html
  godin fmt                gofmt + odin strip-semicolon
  godin fmt-check          verify formatting (CI)
  godin lint               go vet + odin check + golangci-lint
  godin lint-go            golangci-lint only
  godin watch              hot-reload (rebuild + rerun)
  godin watch-once         validate the watcher without watching
  godin clean              remove build artifacts
  godin new <path> <mod>   scaffold a new project
  godin docker-linux       cross-build Linux -> build/linux/
  godin docker-linux-run   smoke-test Linux in Docker
  godin docker-shell       interactive shell in the build image
"@ -ForegroundColor Cyan
}

# ---------------------------------------------------------------- dispatch --

$cmd = if ($script:Argv.Count -gt 0) { $script:Argv[0] } else { 'help' }
$rest = @($script:Argv | Select-Object -Skip 1)

Push-Location $script:Root
try {
  switch ($cmd) {
    'doctor'           { cmd-doctor }
    'version'          { cmd-version }
    'check'            { cmd-check }
    'build'            { cmd-build }
    'odin-lib'         { cmd-odin-lib }
    'go-build'         { cmd-go-build }
    'run'              { cmd-run }
    'test'             { cmd-test }
    'test-race'        { cmd-test-race }
    'test-template'    { cmd-test-template }
    'cover'            { cmd-cover }
    'fmt'              { cmd-fmt }
    'fmt-check'        { cmd-fmt-check }
    'lint'             { cmd-lint }
    'lint-go'          { cmd-lint-go }
    'clean'            { cmd-clean }
    'watch'            { cmd-watch }
    'watch-once'       { cmd-watch-once }
    'docker-linux'     { cmd-docker-linux }
    'docker-linux-run' { cmd-docker-linux-run }
    'docker-shell'     { cmd-docker-shell }
    'new'              { cmd-new $rest }
    'help'             { Show-Help }
    default            { Show-Help; Die "unknown command: $cmd" }
  }
  exit 0
} finally {
  Pop-Location
}
