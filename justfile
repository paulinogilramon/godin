# Go + Odin toolkit (C ABI)
# Windows-first; cross-compile friendly via pwsh

set shell := ["pwsh", "-NoProfile", "-Command"]

odin_out_win := "build/godin.dll"
go_out_win := "build/app.exe"

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

# Cross-build Linux artifacts in a container (Odin cannot cross-link from Windows).
# Produces build/linux/libgodin.so + build/linux/app.
docker-linux:
	@docker build -t godin-linux .
	@New-Item -ItemType Directory -Force -Path build/linux | Out-Null
	@$cid = (docker create godin-linux); docker cp "${cid}:/src/build/libgodin.so" build/linux/; docker cp "${cid}:/src/build/app" build/linux/; docker rm $cid | Out-Null; Write-Host "Linux artifacts -> build/linux/" -ForegroundColor Green

# Run the Linux app inside the container (smoke test).
docker-linux-run:
	@docker build -t godin-linux .
	@docker run --rm godin-linux ./build/app

# Interactive shell in the build image (debugging).
docker-shell:
	@docker run --rm -it -v "${PWD}:/src" -w /src godin-odin bash
