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
- **Docker** (opcional): para cross-build de Linux.

## Quickstart

```powershell
just build          # Odin shared lib -> Go app
just run            # ejecuta build/app.exe
just test           # go test + odin test
just fmt            # gofmt + odin strip-semicolon
just lint           # go vet + odin check
just watch          # hot-reload: rebuild + rerun ante cambios
just clean          # limpia artefactos
just --list         # todas las recetas
```

## Layout

- `go/` — app Go (cgo); `main.go` (demo), `callback.go` (función exportada a C)
- `odin/` — librería Odin (`-build-mode:shared`)
- `shared/godin.h` — cabecera C (escrita a mano; Odin no la auto-genera)
- `build/` — artefactos (`godin.dll`, `godin.lib`, `app.exe`) — ignorado
- `scripts/env.ps1` — diagnóstico del entorno
- `scripts/watch.ps1` — hot-reload (Go + Odin)
- `Dockerfile` / `.dockerignore` — cross-build Linux reproducible
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
| `godin_div` | `(c.double, c.double) -> c.double` | **manejo de errores** |
| `godin_last_error` | `() -> cstring` | último mensaje de error |
| `godin_apply` | `([^]c.double, c.int, ApplyFn) -> c.double` | **callback** (Odin llama a Go) |
| `godin_dup` | `(cstring) -> cstring` | **ownership**: memoria de libc |
| `godin_free` | `(rawptr)` | libera memoria de `godin_dup` |

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
  junto al `.exe` o en `PATH` (`just run` ya lo hace; `go test` añade
  `build/` al `PATH`).
- **Odin nightly**: el comando de formato es `odin strip-semicolon` (no existe
  `odin fmt`); `odin check`/`strip-semicolon` requieren `-no-entry-point` para
  librerías.

## Cross-compile (Linux)

Odin **no puede cross-linkear a Linux desde Windows**, y `cgo` necesita un
toolchain del target. La vía reproducible es un contenedor:

```powershell
just docker-linux       # -> build/linux/libgodin.so + build/linux/app
just docker-linux-run   # smoke test dentro del contenedor
just docker-shell       # shell interactivo para depurar
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

- **Toolkit propio**: `just watch` ejecuta `scripts/watch.ps1`, que observa
  `go/`, `odin/` y `shared/`; ante cualquier cambio reconstruye (Odin lib + Go)
  y reinicia la app. Útil también: `just watch-once` (valida sin observar).
- **air** (Go): `air.toml` en la raíz; el build también recompila la lib Odin
  (`just odin-lib`). Instala con `go install github.com/air-verse/air@latest`.

