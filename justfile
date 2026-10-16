# Go + Odin toolkit (C ABI)
# Windows-first; cross-compile friendly via pwsh

set shell := ["pwsh", "-NoProfile", "-Command"]

odin_out_win := "build/godin.dll"
odin_out_linux := "build/libgodin.so"
go_out_win := "build/app.exe"
go_out_linux := "build/app"

default: build

# Locate MSVC link.exe, prepend it to PATH, and ensure build/ exists.
# (Odin's DLL build mode needs MSVC's link.exe on Windows.)
_msvc := '$lk = (Get-ChildItem "$env:ProgramFiles\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1).DirectoryName; if ($lk) { $env:Path = "$lk;$env:Path" }; New-Item -ItemType Directory -Force -Path build | Out-Null'

odin-lib:
	@{{_msvc}}; odin build odin -build-mode:shared -out:{{odin_out_win}}

go-build: odin-lib
	@cd go; go build -o ../{{go_out_win}} .

build: go-build

run: build
	@.\{{go_out_win}}

test: odin-lib
	@$env:Path = "$PWD\build;$env:Path"; cd go; go test ./...
	@{{_msvc}}; odin test odin

fmt:
	@gofmt -w go
	@odin strip-semicolon odin -no-entry-point

lint:
	@cd go; go vet ./...
	@odin check odin -no-entry-point

clean:
	@Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue; Remove-Item -Recurse -Force .\.vs -ErrorAction SilentlyContinue; Remove-Item -Recurse -Force .\.idea -ErrorAction SilentlyContinue; exit 0

watch:
	@pwsh -NoProfile -File scripts/watch.ps1

watch-once:
	@pwsh -NoProfile -File scripts/watch.ps1 -Once -NoRun

cross-linux:
	@{{_msvc}}; odin build odin -build-mode:shared -target:linux_amd64 -out:{{odin_out_linux}}; $env:GOOS='linux'; $env:GOARCH='amd64'; cd go; go build -o ../{{go_out_linux}} .
