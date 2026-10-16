param()
Write-Host "==> env check" -ForegroundColor Cyan

$go = (Get-Command go -ErrorAction SilentlyContinue)
$odin = (Get-Command odin -ErrorAction SilentlyContinue)

if ($go) {
  Write-Host "go: $($go.Source) -> $(go version)"
} else {
  Write-Warning "go: MISSING"
}

if ($odin) {
  Write-Host "odin: $($odin.Source) -> $(odin version)"
} else {
  Write-Warning "odin: MISSING (scoop or winget)"
}

$scoopOdin = "$env:USERPROFILE\scoop\apps\Odin\current\odin.exe"
if (Test-Path $scoopOdin) {
  Write-Host "scoop odin: present at $scoopOdin"
}

$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue)
if ($pwsh) {
  Write-Host "pwsh: $($pwsh.Source) -> $($PSVersionTable.PSVersion)"
} else {
  Write-Warning "pwsh: MISSING (needed to run ./godin)"
}

$gci = (Get-Command golangci-lint -ErrorAction SilentlyContinue)
if ($gci) {
  Write-Host "golangci-lint: $($gci.Source) -> $(golangci-lint version --short 2>$null)"
} else {
  Write-Warning "golangci-lint: MISSING (godin lint will skip it)"
}
