# godin — Go + Odin toolkit (C ABI)

<!-- Reemplaza OWNER por tu usuario/org de GitHub al publicar el repo. -->
[![CI](https://github.com/OWNER/godin/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/godin/actions/workflows/ci.yml)
[![Go Report Card](https://goreportcard.com/badge/github.com/OWNER/godin)](https://goreportcard.com/report/github.com/OWNER/godin)
[![Go Reference](https://pkg.go.dev/badge/github.com/OWNER/godin.svg)](https://pkg.go.dev/github.com/OWNER/godin)
![coverage](https://img.shields.io/badge/coverage-91%25-brightgreen)

Toolkit para programar en **Go** y **Odin** simultáneamente, comunicándolos vía
**ABI de C** (Odin compila una librería compartida; Go la consume con `cgo`).

Incluye **`godin`**, un task runner propio (PowerShell 7) que sustituye a `just`.

## Requisitos (en esta máquina)

- **Go** `go1.26.4 windows/amd64`
- **Odin** (scoop): `C:\Users\pauli\scoop\apps\Odin\current\odin.exe` — `dev-2026-05-nightly`
- **PowerShell 7** (`pwsh`) — ejecuta el task runner `godin`
- **MSVC** (`link.exe`): Visual Studio `18 Community`, `...\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64`
  - Odin `-build-mode:shared` (DLL) necesita `link.exe` en el `PATH`.
- **gcc/mingw** (scoop): `16.1.0` — `cgo` lo usa como toolchain.
- **golangci-lint** `v2.14.0` — para `godin lint`.
- **Docker** (opcional): para cross-build de Linux.

## Task runner: `godin`

Es un script PowerShell (`godin.ps1`) con wrappers `godin.cmd` (Windows) y
`godin.sh` (Linux/macOS). Uso:

```powershell
.\godin build        # o: pwsh -NoProfile -File godin.ps1 build
.\godin help         # lista de comandos
```

| Comando | Descripción |
|---|---|
| `godin build` | Odin shared lib + Go app |
| `godin run` | build + ejecuta la app |
| `godin test` | go test + odin test |
| `godin cover` | cobertura Go → `build/coverage.html` |
| `godin fmt` | gofmt + odin strip-semicolon |
| `godin fmt-check` | verifica formato (CI) |
| `godin lint` | go vet + odin check + golangci-lint |
| `godin lint-go` | solo golangci-lint |
| `godin watch` | hot-reload (rebuild + rerun) |
| `godin watch-once` | valida el watcher sin observar |
| `godin clean` | limpia artefactos |
| `godin new <path> <mod>` | scaffolding de un proyecto nuevo |
| `godin docker-linux` | cross-build Linux → `build/linux/` |
| `godin docker-linux-run` | smoke test Linux en Docker |
| `godin docker-shell` | shell interactivo en la imagen |

## Layout

- `godin.ps1` / `godin.cmd` / `godin.sh` — task runner
- `go/` — app Go (cgo); `api.go` (fachada), `callback.go` (`//export`), `main.go`
- `odin/` — librería Odin (`-build-mode:shared`)
- `shared/godin.h` — cabecera C (escrita a mano; Odin no la auto-genera)
- `build/` — artefactos (`godin.dll`, `godin.lib`, `app.exe`) — ignorado
- `scripts/env.ps1`, `scripts/watch.ps1`, `scripts/new-project.ps1`
- `Dockerfile` / `.dockerignore` — cross-build Linux reproducible
- `.vscode/` — tareas delegando a `godin`
- `.github/workflows/ci.yml` — CI
- `templates/interop-cgo/` — esqueleto mínimo de interop
- `docs/` — documentación

## Interop (C ABI)

Odin (`odin/lib.odin`) exporta procs con `@(export)` y tipos C (`core:c`):

| Símbolo | Firma | Demuestra |
|---|---|---|
| `godin_version` | `() -> c.int` | valor de retorno escalar |
| `godin_add` | `(c.int, c.int) -> c.int` | parámetros escalares |
| `godin_str_len` | `(cstring) -> c.int` | string C de entrada |
| `godin_sum` | `([^]c.double, c.int) -> c.double` | slice (puntero + longitud) |
| `godin_scale` | `(^Vec3, c.double)` | struct por puntero (out-param) |
| `godin_make_vec3` | `(c.double, c.double, c.double) -> Vec3` | struct por valor |
| `godin_div` | `(c.double, c.double) -> c.double` | **manejo de errores** |
| `godin_last_error` | `() -> cstring` | último mensaje de error |
| `godin_apply` | `([^]c.double, c.int, ApplyFn) -> c.double` | **callback** (Odin llama a Go) |
| `godin_dup` | `(cstring) -> cstring` | **ownership**: memoria de libc |
| `godin_free` | `(rawptr)` | libera memoria de `godin_dup` |

Go (`go/api.go`) las consume con `cgo`:

```go
// #cgo CFLAGS: -I../shared
// #cgo windows LDFLAGS: -L../build -lgodin
// #include "godin.h"
import "C"

fmt.Println(Add(2, 3)) // 5
```

Salida de `godin run`:

```
godin_version() = 1
godin_add(2, 3) = 5
godin_str_len("hello from Go") = 13
godin_sum({1,2,3,4}) = 10
godin_scale({1,2,3}, 2) = {2, 4, 6}
godin_make_vec3(4,5,6) = {4, 5, 6}
godin_div(6, 2) = 3  (last_error="")
godin_div(1, 0) = 0  (last_error="division by zero")
godin_apply({1,2,3}, go_square) = 14
godin_dup("hello from Go") = "hello from Go" (freed via godin_free)
```

### Patrones avanzados

- **Errores**: `godin_div` guarda el mensaje y `godin_last_error()` lo expone
  como `cstring` (vacío si no hay error).
- **Callbacks**: `go/callback.go` exporta `go_square` con `//export`; se pasa como
  puntero a `godin_apply` (tipo `ApplyFn = proc "c" (c.double) -> c.double`).
- **Ownership**: `godin_dup` reserva con `libc.malloc`; **el llamador debe**
  liberar con `godin_free`. Nota: no se usa el allocator de Odin porque el
  runtime de Odin no se inicializa al cargar la lib compartida desde Go.

### Notas de plataforma

- **Windows**: Odin produce `build/godin.dll` + `build/godin.lib`; Go enlaza vía
  `-lgodin` (gcc acepta el `.lib` de MSVC). En **runtime** el `.dll` debe estar
  junto al `.exe` o en `PATH` (`godin run` ya lo hace; `godin test` añade
  `build/` al `PATH`).
- **Odin nightly**: el comando de formato es `odin strip-semicolon` (no existe
  `odin fmt`); `odin check`/`strip-semicolon` requieren `-no-entry-point` para
  librerías.

## Cross-compile (Linux)

Odin **no puede cross-linkear a Linux desde Windows**, y `cgo` necesita un
toolchain del target. La vía reproducible es un contenedor:

```powershell
godin docker-linux       # -> build/linux/libgodin.so + build/linux/app
godin docker-linux-run   # smoke test dentro del contenedor
godin docker-shell       # shell interactivo para depurar
```

El `Dockerfile` usa `golang:1.26-bookworm`, instala `clang` (driver del linker
de Odin) y descarga la release de Odin (`dev-2026-10`). El binario Go lleva
`RUNPATH=$ORIGIN`, así encuentra `libgodin.so` en el mismo directorio.

En Linux nativo (o CI ubuntu) basta:

```sh
odin build odin -build-mode:shared -out:build/libgodin.so
go build -C go -o ../build/app .
```

## Hot-reload

- **Toolkit propio**: `godin watch` ejecuta `scripts/watch.ps1`, que observa
  `go/`, `odin/` y `shared/`; ante cualquier cambio reconstruye (Odin lib + Go)
  y reinicia la app. Útil también: `godin watch-once` (valida sin observar).
- **air** (Go): `air.toml` en la raíz; el build también recompila la lib Odin
  (`godin go-build`). Instala con `go install github.com/air-verse/air@latest`.

## Calidad

- **golangci-lint** (`v2.14.0`): config en `.golangci.yml`; `godin lint` lo ejecuta
  si está instalado. Instalación: `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.14.0`
  (o `winget install GolangCI.golangci-lint`).
- **Cobertura Go**: `godin cover` (≈92%) genera `build/coverage.out` y
  `build/coverage.html`. La capa `cgo` está en `go/api.go`; los tests usan esos
  wrappers (cgo no está soportado en archivos `_test.go`).
- **CI** (`.github/workflows/ci.yml`): jobs Windows + Linux con formato, lint,
  build, test, cobertura (artefacto) y smoke test.

## Plantilla

Este repo es una plantilla reutilizable. Genera un proyecto nuevo:

```powershell
godin new ..\mi-proyecto github.com/tu-org/mi-proyecto
```

Ver `docs/TEMPLATE.md` para detalles (qué copia, qué reescribe, y cómo usarlo
como template de GitHub).
