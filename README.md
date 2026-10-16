# godin — Go + Odin toolkit (C ABI)

Toolkit para programar en **Go** y **Odin** simultáneamente, comunicándolos vía
**ABI de C** (Odin compila una librería compartida; Go la consume con `cgo`).

## Requisitos (en esta máquina)

- **Go** `go1.26.4 windows/amd64`
- **Odin** (scoop): `C:\Users\pauli\scoop\apps\Odin\current\odin.exe` — `dev-2026-05-nightly`
- **just** (scoop): `1.59.0`
- **MSVC** (`link.exe`): Visual Studio `18 Community`, `...\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64`
  - Odin `-build-mode:shared` (DLL) necesita `link.exe` en el `PATH`.
- **gcc/mingw** (scoop): `16.1.0` — `cgo` lo usa como toolchain.

## Quickstart

```powershell
just build      # Odin shared lib -> Go app
just run        # ejecuta build/app.exe
just test       # go test + odin test
just fmt        # gofmt + odin strip-semicolon
just lint       # go vet + odin check
just watch      # hot-reload: rebuild + rerun ante cambios
just clean      # limpia artefactos
just --list     # todas las recetas
```

## Layout

- `go/` — app Go (cgo)
- `odin/` — librería Odin (`-build-mode:shared`)
- `shared/godin.h` — cabecera C (escrita a mano; Odin no la auto-genera)
- `build/` — artefactos (`godin.dll`, `godin.lib`, `app.exe`) — ignorado
- `scripts/env.ps1` — diagnóstico del entorno
- `scripts/watch.ps1` — hot-reload (Go + Odin)
- `.vscode/` — tareas delegando a `just`
- `.github/workflows/ci.yml` — CI
- `templates/interop-cgo/` — plantilla reutilizable
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

Go (`go/main.go`) las consume con `cgo`:

```go
// #cgo CFLAGS: -I../shared
// #cgo windows LDFLAGS: -L../build -lgodin
// #include "godin.h"
import "C"

fmt.Println(int(C.godin_add(2, 3))) // 5
```

Salida de `just run`:

```
godin_version() = 1
godin_add(2, 3) = 5
godin_str_len("hello from Go") = 13
godin_sum({1,2,3,4}) = 10
godin_scale({1,2,3}, 2) = {2, 4, 6}
godin_make_vec3(4,5,6) = {4, 5, 6}
```

### Notas de plataforma

- **Windows**: Odin produce `build/godin.dll` + `build/godin.lib`; Go enlaza vía
  `-lgodin` (gcc acepta el `.lib` de MSVC). En **runtime** el `.dll` debe estar
  junto al `.exe` o en `PATH` (`just run` ya lo hace; `go test` añade
  `build/` al `PATH`).
- **Odin nightly**: el comando de formato es `odin strip-semicolon` (no existe
  `odin fmt`); `odin check`/`strip-semicolon` requieren `-no-entry-point` para
  librerías.

## Cross-compile

`just cross-linux` genera `build/libgodin.so` (target `linux_amd64`) + `build/app`.

## Hot-reload

- **Toolkit propio**: `just watch` ejecuta `scripts/watch.ps1`, que observa
  `go/`, `odin/` y `shared/`; ante cualquier cambio reconstruye (Odin lib + Go)
  y reinicia la app. Útil también: `just watch-once` (valida sin observar).
- **air** (Go): `air.toml` en la raíz; el build también recompila la lib Odin
  (`just odin-lib`). Instala con `go install github.com/air-verse/air@latest`.

