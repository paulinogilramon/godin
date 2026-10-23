# Plan del toolkit Go + Odin (C ABI)

Objetivo: disponer de un repo **listo para usar y extender** que muestre cómo comunicar Go y Odin vía ABI de C con `cgo`, incluyendo un *task runner* propio, plantilla, hot-reload, cross-build Linux en Docker y CI.

## 1) REQUISITOS FUNCIONALES

- Mostrar interop mínimo: funciones escalares, strings C, slices, structs por valor/puntero, callbacks (Go ←→ Odin), manejo de errores y *ownership* (`malloc`/`free`).
- Odin compila a **librería compartida** (`.dll`/`.so`) con `-build-mode:shared`, exportando `@(export)` con `core:c`.
- Go consume con `cgo`, cabecera `shared/godin.h` y LDFLAGS con ruta al `build/`.
- Un solo comando `godin` (PowerShell 7) para `doctor/version/build/run/test/bench/cover/lint/fmt/watch/new/clean`.
- Plantilla reutilizable `templates/interop-cgo/` y `godin new`.
- Hot-reload (`godin watch`) con `scripts/watch.ps1`.
- Cross-build Linux reproducible vía Docker.
- CI Windows + Linux, *format-check*, *lint*, *tests*, *race* (Linux), *coverage gate* 95%.

## 2) ARQUITECTURA PROPUESTA

| Elemento | Descripción |
| --- | --- |
| `odin/lib.odin` | Librería exportada: `version/add/str_len/sum/scale/make_vec3/div/last_error/apply/dup/free`. Usa `libc` para `dup/free`. Estado de error global con *mutex*. |
| `shared/godin.h` | Contrato C (tipos `Vec3`, `godin_apply_fn`). Escrito a mano (Odin no genera headers fiables). |
| `go/api.go` | Fachada tipada, convierte entre Go y C, gestiona errores y propiedad. |
| `go/callback.go` | `//export go_square` para demostrar callback Odin→Go. |
| `go/main.go` | Demo que imprime todos los casos. |
| `godin.ps1` | *Task runner*: checks, MSVC, PATH para DLL, Go/Odin, lint, cover, etc. |
| `scripts/doctor.ps1` | Diagnóstico con `OK/WARN/FALTA` + pistas. |
| `scripts/coverage-check.ps1` | Gate ≥ 95% sobre `go test -cover`. |
| `scripts/new-project.ps1` | Scaffolding con reemplazo de módulo. |

## 3) CONVENCIONES CRÍTICAS

- **Odin shared**: usar `-build-mode:shared`; en algunos nightlies `-build-mode:c-shared` difiere; con `@(export)` `-build-mode:shared` funciona.
- **Sin entry point**: las librerías deben compilar sin `main`. Odin lo acepta con *shared*.
- **Llamadas C**: procs exportados con `proc "c"`.
- **Callbacks**: el puntero a función debe tener convención C; desde Odin pasar `go_square_ptr` o puntero exportado.
- **Ownership**: si Odin aloja memoria con `libc.malloc`, **debe** exponerse `free` (`godin_free`) y el llamador de Go liberarla (`defer C.godin_free(...)`).
- **DLL en runtime**: Windows busca en PATH o junto al .exe. `godin run/test` configuran PATH vía `Add-LibPath`.
- **rpath/Linux**: cgo añade `-Wl,-rpath,$ORIGIN` para cargar desde `build/`.

## 4) HITOS

### Iteración 1: andamiaje
- [x] Estructura `go/`, `odin/`, `shared/`, `build/`, `scripts/`
- [x] `shared/godin.h` inicial
- [x] `odin/lib.odin` con `version` y `add` exportados
- [x] `go/main.go` + `go/api.go` con cgo mínimos
- [x] `godin.ps1` con `build/run`

### Iteración 2: interop completo
- [x] `str_len`, `sum` (slice), `scale` (struct puntero), `make_vec3` (struct valor), `div` + `last_error`, `apply` + callback, `dup`/`free`
- [x] `go/callback.go` con `//export go_square`
- [x] Sincronización con *mutex* en estado de error
- [x] Demo completo en `main.go`

### Iteración 3: tooling + plantilla + hot-reload
- [x] `godin doctor`, `version`, `test`, `bench`, `fmt`, `lint`, `clean`, `new`
- [x] `scripts/watch.ps1`, `air.toml`
- [x] `templates/interop-cgo/` completo
- [x] `scripts/test-template.ps1`, `godin test-template`

### Iteración 4: cross-build, CI, docs
- [x] `Dockerfile`, `godin docker-linux/*`
- [x] `.github/workflows/ci.yml` (Windows + Linux)
- [x] `docs/ARCHITECTURE.md`, `docs/TROUBLESHOOTING.md`, `docs/TEMPLATE.md`
- [x] `CONTRIBUTING.md`, `LICENSE`, `.editorconfig`

### Iteración 5: calidad y plug-and-play (v0.5.0)
- [x] `godin check`, `test-race`, `watch-once`
- [x] Cobertura Go **98.0%**, gate 95% en `godin cover`
- [x] `godin test` pasa Go + Odin (10 tests)
- [x] Plantilla validada end-to-end
- [x] CI endurecido (concurrency, permissions, doctor, race, template)
- [x] Docs README genérico, UTF-8 corregido

### Iteración 6: caso práctico blur imagen (v0.6.0)
- [x] **Caso real**: box blur separable + Gaussian 5×5 separable sobre RGBA8
- [x] **Implementación**: `odin/blur.odin`, `go/blur/` (Go + cgo), `go/cmd/blur/` CLI `go|odin|both`
- [x] **Correctitud**: referencias independientes, `TestNoAllocs`, igualdad byte-a-byte
- [x] **Optimización**: `godin build` → `-o:speed`; estudio `minimal`/`speed`/`speed -no-bounds-check`
- [x] **Medición reproducible**: `scripts/case-study.ps1` → `build/case-study/results.txt` (benchmarks, tiles, call overhead, CLI avg+best, hashes Linux/Docker)
- [x] **Portabilidad**: Windows/Linux con **hashes de píxeles idénticos**
- [x] **CI**: smoke test blur Go==Odin
- [x] **Docs**: [`docs/CASE-STUDY-IMAGE-BLUR.md`](docs/CASE-STUDY-IMAGE-BLUR.md), README/CHANGELOG/PLAN actualizados

## 5) COMANDOS OBJETIVO

| Comando | Acción |
| --- | --- |
| `godin doctor` | Verifica pwsh/go/odin/linker/gcc/golangci-lint/docker |
| `godin version` | Muestra versiones |
| `godin build` | `odin build -build-mode:shared -o:speed` + `go build` |
| `godin run` | build + ejecutar app |
| `godin test` | `go test ./...` + `odin test` (lib cargada) |
| `godin test-race` | `go test -race` |
| `godin bench` | `go test -bench` (paquete demo) |
| `godin blur` | CLI blur (demo caso práctico) |
| `godin case-study` | Estudio reproducible |
| `godin cover` | Cobertura con gate 95% |
| `godin check` | fmt-check + lint + test |
| `godin lint` | go vet + odin check + golangci-lint |
| `godin fmt` | gofmt + odin strip-semicolon |
| `godin watch` | hot-reload |
| `godin new <path> <mod>` | scaffolding |
| `godin docker-linux` | cross-build Linux |
| `godin clean` | limpia build/ |

## 6) NOTAS TÉCNICAS

- **Odin shared exports**: declarar procs con `@(export) foo :: proc(...) -> ... {}` y `proc "c"`. Añadir al `foreign import` si se prefiere, pero `@(export)` es suficiente con `-build-mode:shared`.
- **Cabecera**: mantener `shared/godin.h` sincronizada con exports.
- **cgo**: incluir `-I../shared` y rutas `-L../build`. Windows necesita `-lgodin`; Linux `-lgodin -ldl -lm -Wl,-rpath,$ORIGIN`.
- **Errores**: Odin guarda string en buffer con mutex; Go lee con `C.GoString` y copia si se va a retener.
- **Callbacks**: usar `proc "c"` para punteros pasados a C. Exportar función Go con `//export`.
- **Tests**: `odin test` corre con el runtime de Odin; `go test` con cgo necesita la `.dll`/`.so` en PATH/LD_LIBRARY_PATH.

## 7) VERIFICACIÓN FINAL (v0.6.0)

- [x] `godin doctor` OK
- [x] `godin fmt-check` OK
- [x] `godin lint` 0 issues
- [x] `godin test` Go + Odin OK (incluye `blur` y CLI)
- [x] `godin test-race` OK
- [x] `godin cover` ≥ 98% ≥ 95%
- [x] `godin case-study` → 3 hashes idénticos, resultados medidos
- [x] `godin blur -impl both` OK Windows y Linux (Docker)
- [x] CI verde (Windows + Linux + plantilla + smoke blur)
- [x] Docs actualizados
