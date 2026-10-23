# Arquitectura

## Objetivo

Un único repo donde Go y Odin conviven y se llaman **en ambos sentidos** a
través de la ABI de C:

- Go → Odin: cgo enlaza una shared library compilada por Odin.
- Odin → Go: Odin invoca function pointers exportados por Go (`//export`).

No hay IPC, ni JSON, ni subprocesos: es una llamada nativa.

## Layout

| Ruta | Rol |
|---|---|
| `odin/lib.odin` | Implementación y exports `@(export)`; tests unitarios |
| `shared/godin.h` | Contrato C: firmas, `Vec3`, `godin_apply_fn` (manual) |
| `go/api.go` | Fachada Go: cgo, conversión de tipos, ownership |
| `go/callback.go` | `//export go_square`, callback que Odin puede llamar |
| `go/main.go` | Demo ejecutable (`run()`) |
| `go/*_test.go` | Tests Go contra la API (cgo no se permite en `_test.go`) |
| `build/` | Artefactos: `godin.dll`/`.lib` (Win), `libgodin.so` (Linux), `app` |
| `scripts/` | `doctor`, `watch`, `new-project`, `test-template`, `coverage-check` |

## Flujo de build

```
odin/lib.odin  --(odin build -build-mode:shared)-->  build/godin.dll + godin.lib
shared/godin.h -------------------------------------^ (declaraciones)
                                                      |
go/*.go  --(go build, cgo: -L../build -lgodin)-->     build/app.exe
                                                      |
                                            runtime: app.exe + godin.dll
```

`godin build` hace ambos pasos y coloca el `.dll` junto al `.exe`, de modo que
Windows lo encuentra sin tocar el `PATH`. `godin test` añade `build/` al `PATH`
(Windows) o a `LD_LIBRARY_PATH` (Linux) antes de ejecutar `go test`.

En Linux, la shared library se llama `libgodin.so` y el binario Go del
contenedor/CI lleva `RUNPATH=$ORIGIN`.

## Contrato ABI

Reglas que hay que respetar al añadir o cambiar símbolos:

1. **Tipos C solamente** en la frontera: `c.int`, `c.double`, `cstring`,
   `rawptr`, structs con layout estable (`Vec3` = 3 × `double`).
2. **Sin runtime de Odin al otro lado**: nada de `mem.alloc`, `map`, `slice`
   de Odin con allocator propio ni excepciones/panics que crucen. La memoria
   compartida se reserva con `libc.malloc` y se libera explícitamente
   (`godin_dup` / `godin_free`).
3. **Ownership explícito**: quien asigna, libera. Documenta cada símbolo que
   devuelva memoria.
4. **Strings**: `cstring` es NUL-terminated. Un `cstring` que devuelve Odin es
   de solo lectura y vive hasta que Odin lo libere o lo reemplace. Para
   transferir ownership, usa una copia (`godin_dup`).
5. **Callbacks**: proc `"c"` (`ApplyFn :: #type proc "c" (c.double) -> c.double`)
   con la misma calling convention. Un callback de Go se exporta con
   `//export` y se pasa como puntero.
6. **Estado global**: `godin_last_error` guarda un `cstring` global; no es
   thread-safe. Si necesitas concurrencia, cambia el diseño (p. ej. error por
   llamada o thread-local).
7. **Layout**: el struct debe coincidir byte a byte. `Vec3` se declara en
   `shared/godin.h` y en Odin; si añades campos, actualiza ambos y los tests.

## Añadir un símbolo (checklist)

Ejemplo: `godin_mul(a, b: c.double) -> c.double`.

1. **Odin** — implementa y exporta en `odin/lib.odin`:

   ```odin
   @(export)
   godin_mul :: proc(a, b: c.double) -> c.double {
       return a * b
   }
   ```

2. **Header** — declara en `shared/godin.h` (dentro de `extern "C"`):

   ```c
   double godin_mul(double a, double b);
   ```

3. **Go** — envuelve en `go/api.go` con conversiones explícitas:

   ```go
   // Mul returns a*b computed in Odin.
   func Mul(a, b float64) float64 {
       return float64(C.godin_mul(C.double(a), C.double(b)))
   }
   ```

4. **Tests** — añade un test Go (`go/interop_test.go`) y uno Odin
   (`odin/lib.odin`). Recuerda: cgo no está permitido en `_test.go`, así que el
   test usa el wrapper.

5. **Ejercita el símbolo** en `go/main.go` (`run()`) si forma parte del demo.

6. **Documenta** la fila en el README y, si aplica, en este documento.

7. **Verifica**: `godin check` (fmt + lint + tests) y `godin cover` (gate 95%).

## Calidad

- `godin check` = `fmt-check` + `lint` + `test`.
- `godin test-race` usa el detector de carreras de Go (Linux en CI).
- `godin cover` escribe `build/coverage.out` / `.html` y falla si la cobertura
  total baja del 95%.
- `godin test-template` scaffoldea un proyecto y compila/ejecuta tanto el
  scaffold completo como `templates/interop-cgo`.

## CI

`.github/workflows/ci.yml`:

| Job | Qué hace |
|---|---|
| `windows` | doctor, fmt-check, lint, build, test, cover (gate), smoke run |
| `linux` | lo anterior + `clang` + `test-race` |
| `template` | matrix Windows/Linux: `godin test-template` |

## Decisiones y límites conocidos

- **Header manual**: Odin no genera cabeceras C; se mantiene a mano y el
  checklist de arriba evita el drift.
- **Cross-compile**: Odin no puede enlazar para Linux desde Windows y cgo
  necesita el toolchain del target. Por eso el cross-build es vía Docker
  (`godin docker-linux`) o CI Linux.
- **Allocator**: se usa `libc` a propósito (ver punto 2). El precio es que el
  llamador debe liberar.
- **Thread safety**: el error global es suficiente para el demo; no para un
  servidor concurrente. Está documentado como limitación, no como bug.
- **macOS**: no hay job de CI; el código es portable (clang + dylib), pero no
  está verificado en este repo.
