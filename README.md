# godin — Go + Odin toolkit (C ABI)

<!-- Al publicar, reemplaza OWNER por tu usuario/org de GitHub. -->
[![CI](https://github.com/OWNER/godin/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/godin/actions/workflows/ci.yml)
[![Go Report Card](https://goreportcard.com/badge/github.com/OWNER/godin)](https://goreportcard.com/report/github.com/OWNER/godin)
[![Go Reference](https://pkg.go.dev/badge/github.com/OWNER/godin.svg)](https://pkg.go.dev/github.com/OWNER/godin)
![coverage](https://img.shields.io/badge/coverage-98%25-brightgreen)

Toolkit para programar en **Go** y **Odin** simultáneamente, comunicándolos vía
**ABI de C**: Odin compila una librería compartida y Go la consume con `cgo`.

Incluye **`godin`**, un task runner propio en PowerShell 7 (sin `just` ni
`make`), una plantilla reutilizable, hot-reload, cross-build Linux en Docker y
CI para Windows + Linux.

## Quickstart (3 pasos)

```powershell
git clone <tu-repo> && cd godin
.\godin doctor      # 1. comprueba el toolchain (dice qué falta y cómo instalarlo)
.\godin build       # 2. Odin shared lib + app Go
.\godin run         # 3. ejecuta el demo de interop
```

En Linux/macOS usa `./godin.sh` en lugar de `.\godin`.

Salida esperada de `godin run`:

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

## Requisitos

`godin doctor` verifica todo esto y devuelve `exit 1` si falta algo obligatorio.
Obligatorio: **pwsh 7**, **Go**, **Odin**, **linker nativo** y **gcc** (cgo).

| Dependencia | Windows | Linux / macOS |
|---|---|---|
| PowerShell 7 | `winget install Microsoft.PowerShell` | [instalación de PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Go 1.22+ | `scoop install go` o [go.dev/dl](https://go.dev/dl/) | gestor de paquetes o [go.dev/dl](https://go.dev/dl/) |
| Odin (nightly) | `scoop install odin` o [odin-lang.org/docs/install](https://odin-lang.org/docs/install/) | release de [Odin](https://github.com/odin-lang/Odin/releases) |
| Linker de la shared lib | **MSVC** `link.exe` (Build Tools con "Desktop development with C++") | `clang` |
| Toolchain de `cgo` | `scoop install mingw` (gcc) | `build-essential` (gcc) |
| golangci-lint (opcional) | `winget install GolangCI.golangci-lint` | `go install ...@v2.14.0` |
| Docker (opcional) | Docker Desktop | Docker Engine (solo para cross-build Linux) |

Versiones probadas: Go `1.26.4`, pwsh `7.6.6`, golangci-lint `2.14.0`, Odin
nightly `dev-2026-05` (Windows) y `dev-2026-10` (CI/Docker). Odin cambia a
menudo: si algo falla tras actualizar, revisa
[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Comandos

```powershell
.\godin help          # lista completa
```

| Comando | Descripción |
|---|---|
| `godin doctor` | Diagnóstico del toolchain (`exit 1` si falta algo obligatorio) |
| `godin version` | Versión del runner + go/odin/pwsh |
| `godin build` | Odin shared lib + app Go |
| `godin run` | build + ejecuta la app |
| `godin test` | `go test` + `odin test` |
| `godin test-race` | `go test -race` (cgo + DLL) |
| `godin test-template` | Scaffold + build + run de la plantilla (smoke) |
| `godin bench` | Benchmarks Go a través de cgo |
| `godin cover` | Cobertura Go → `build/coverage.html` (falla si < 95%) |
| `godin check` | `fmt-check` + `lint` + `test` (gate pre-push) |
| `godin fmt` / `fmt-check` | `gofmt` + `odin strip-semicolon` / verificación |
| `godin lint` / `lint-go` | `go vet` + `odin check` + `golangci-lint` / solo lint Go |
| `godin watch` | Hot-reload: rebuild + rerun |
| `godin watch-once` | Valida el watcher sin observar |
| `godin clean` | Elimina artefactos |
| `godin new <path> <mod>` | Scaffolding de un proyecto nuevo |
| `godin docker-linux` | Cross-build Linux → `build/linux/` |
| `godin docker-linux-run` | Smoke test Linux en Docker |
| `godin docker-shell` | Shell interactivo en la imagen de build |

## Layout

- `godin.ps1` / `godin.cmd` / `godin.sh` — task runner y lanzadores
- `go/` — app Go (cgo): `api.go` (fachada), `callback.go` (`//export`), `main.go`
- `odin/` — librería Odin (`-build-mode:shared`)
- `shared/godin.h` — cabecera C escrita a mano (Odin no la genera)
- `build/` — artefactos (`godin.dll`, `godin.lib`, `app.exe`) — ignorado
- `scripts/` — `doctor`, `watch`, `new-project`, `test-template`, `coverage-check`
- `templates/interop-cgo/` — esqueleto mínimo de interop
- `docs/` — [arquitectura](docs/ARCHITECTURE.md), [troubleshooting](docs/TROUBLESHOOTING.md), [plantilla](docs/TEMPLATE.md)
- `.github/workflows/ci.yml` — CI (Windows + Linux + smoke de plantilla)
- `Dockerfile` — cross-build Linux reproducible

## Interop (C ABI)

Odin (`odin/lib.odin`) exporta procs `@(export)` con tipos `core:c`; Go
(`go/api.go`) las declara en `shared/godin.h` y las llama con cgo:

```go
// #cgo CFLAGS: -I../shared
// #cgo windows LDFLAGS: -L../build -lgodin
// #include "godin.h"
import "C"

fmt.Println(Add(2, 3)) // 5
```

| Símbolo | Firma | Demuestra |
|---|---|---|
| `godin_version` | `() -> c.int` | retorno escalar |
| `godin_add` | `(c.int, c.int) -> c.int` | parámetros escalares |
| `godin_str_len` | `(cstring) -> c.int` | string C de entrada |
| `godin_sum` | `([^]c.double, c.int) -> c.double` | slice (puntero + longitud) |
| `godin_scale` | `(^Vec3, c.double)` | struct por puntero (out-param) |
| `godin_make_vec3` | `(c.double, c.double, c.double) -> Vec3` | struct por valor |
| `godin_div` / `godin_last_error` | `(c.double, c.double)` / `() -> cstring` | manejo de errores |
| `godin_apply` | `([^]c.double, c.int, ApplyFn) -> c.double` | callback (Odin llama a Go) |
| `godin_dup` / `godin_free` | `(cstring) -> cstring` / `(rawptr)` | ownership con libc |

Reglas clave (detalle en [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)):

- **No** cruces el allocator ni el runtime de Odin: la memoria compartida se
  reserva con `libc.malloc` (`godin_dup`) y se libera con `godin_free`.
- Los `cstring` que devuelve Odin son de solo lectura y válidos hasta la
  siguiente llamada que cambie el estado de error.
- Los callbacks deben ser procs `"c"` (misma calling convention).

### Notas de plataforma

- **Windows**: Odin produce `build/godin.dll` + `build/godin.lib`; Go enlaza con
  `-lgodin`. En runtime el `.dll` debe estar junto al `.exe` o en `PATH`
  (`godin run`/`godin test` ya lo resuelven). Odin necesita `link.exe` (MSVC).
- **Linux**: `build/libgodin.so`; el binario Go usa `RUNPATH=$ORIGIN` en el
  contenedor/CI. `godin` añade `build/` a `LD_LIBRARY_PATH`.
- **Odin nightly**: `-build-mode:shared` (no `c-shared`), `odin strip-semicolon`
  (no `odin fmt`) y `-no-entry-point` para librerías.

## Caso práctico: imagen blur (Go + Odin)

```powershell
.\godin blur -gen blur.png -w 1920 -h 1080        # generar imagen sintética
.\godin blur -in blur.png -op gauss -impl both   # comparar Go vs Odin (igualdad forzada)
.\godin case-study                               # estudio reproducible -> build/case-study/results.txt
```

Ver **[docs/CASE-STUDY-IMAGE-BLUR.md](docs/CASE-STUDY-IMAGE-BLUR.md)** con metodología,
mediciones, *tiles/cgo overhead*, variantes de optimización, portabilidad Windows/Linux
y hashes idénticos.

## Cross-compile (Linux)

Odin no puede cross-linkear a Linux desde Windows y cgo necesita el toolchain
del target, así que la vía reproducible es un contenedor:

```powershell
godin docker-linux       # -> build/linux/libgodin.so + build/linux/app
godin docker-linux-run   # smoke test dentro del contenedor
godin docker-shell       # shell interactivo para depurar
```

El `Dockerfile` usa `golang:1.26-bookworm`, instala `clang` y descarga la
release de Odin (`dev-2026-10`). En Linux nativo o CI basta con
`odin build` + `go build` (lo hacen `godin build` y el job `linux`).

## Hot-reload

- `godin watch` observa `go/`, `odin/` y `shared/`, reconstruye y reinicia la app.
- `air.toml` está incluido para `air` (Go): instala con
  `go install github.com/air-verse/air@latest` y ejecuta `air`.

## Calidad

- **Cobertura Go**: 98% (`godin cover`); el gate falla por debajo de 95%
  (`scripts/coverage-check.ps1`).
- **golangci-lint** `v2.14.0` (`.golangci.yml`); `godin lint` lo ejecuta si está.
- **CI**: formato, lint, build, test, `-race` (Linux), cobertura y smoke test en
  Windows + Linux, más un job que scaffoldea y compila la plantilla.
- **Tests**: `go test` (incluye cgo/callbacks/ownership) y `odin test`.

## Plantilla

```powershell
godin new ..\mi-proyecto github.com/tu-org/mi-proyecto
```

Copia el scaffolding, reescribe `go/go.mod` y los badges. Ver
[`docs/TEMPLATE.md`](docs/TEMPLATE.md). Para validar la plantilla de punta a
punta: `godin test-template`.

## Licencia

MIT — ver [`LICENSE`](LICENSE). Contribuciones: [`CONTRIBUTING.md`](CONTRIBUTING.md).
