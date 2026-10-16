# Go + Odin Toolkit

Scaffold funcional: interop **Go ↔ Odin** vía **ABI de C** (Odin `shared` lib + Go `cgo`).

## Estructura

| Ruta | Descripción |
|---|---|
| `go/` | Aplicación Go (cgo) |
| `odin/` | Librería Odin (`-build-mode:shared`) |
| `shared/godin.h` | Cabecera C (manual) |
| `build/` | Artefactos generados (ignorado) |
| `scripts/env.ps1` | Diagnóstico del entorno |
| `scripts/watch.ps1` | Hot-reload (Go + Odin) |
| `air.toml` | Config opcional de `air` (Go) |
| `.vscode/` | Tareas/settings/extensiones |
| `.github/workflows/` | CI (windows + linux) |
| `templates/interop-cgo/` | Plantilla reutilizable |
| `docs/` | Esta documentación |

## Recetas `just`

```powershell
just --list
just build          # odin shared -> go app
just run            # ejecuta build/app.exe
just test           # go test + odin test
just fmt            # gofmt + odin strip-semicolon
just lint           # go vet + odin check
just watch          # hot-reload: rebuild + rerun
just watch-once     # valida el watcher sin observar
just clean          # limpia build/
just docker-linux       # -> build/linux/libgodin.so + build/linux/app
just docker-linux-run   # smoke test Linux dentro del contenedor
just docker-shell       # shell interactivo (debug)
```

## API de interop

Definida en `odin/lib.odin`, declarada en `shared/godin.h`:

| Símbolo | Firma | Demuestra |
|---|---|---|
| `godin_version` | `() -> c.int` | retorno escalar |
| `godin_add` | `(c.int, c.int) -> c.int` | parámetros escalares |
| `godin_str_len` | `(cstring) -> c.int` | string C de entrada |
| `godin_sum` | `([^]c.double, c.int) -> c.double` | slice (puntero + longitud) |
| `godin_scale` | `(^Vec3, c.double)` | struct por puntero |
| `godin_make_vec3` | `(c.double, c.double, c.double) -> Vec3` | struct por valor |
| `godin_div` / `godin_last_error` | error handling | división por cero |
| `godin_apply` | `(..., ApplyFn) -> c.double` | callback (Odin llama a Go) |
| `godin_dup` / `godin_free` | ownership | memoria libc |

## Validación

```powershell
pwsh -File scripts/env.ps1
just build
just run     # -> godin_version = 1 ; godin_add = 5 ; godin_sum = 10 ; ... ; callback = 14
just test    # -> 5 tests Odin + go test
```

## Requisitos del entorno

- Go, Odin (scoop), just (scoop), MSVC `link.exe`, gcc/mingw.
- Ver `README.md` para rutas exactas.
