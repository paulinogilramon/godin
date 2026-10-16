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

$just = (Get-Command just -ErrorAction SilentlyContinue)
if ($just) {
  Write-Host "just: $($just.Source) -> $(just --version)"
} else {
  Write-Warning "just: MISSING"
}
