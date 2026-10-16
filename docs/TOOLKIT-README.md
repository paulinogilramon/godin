# Go + Odin Toolkit

Scaffold funcional: interop **Go ↔ Odin** vía **ABI de C** (Odin `shared` lib + Go `cgo`).

## Estructura

| Ruta | Descripción |
|---|---|
| `go/` | Aplicación Go (cgo) |
| `odin/` | Librería Odin (`-build-mode:shared`) |
| `shared/godin.h` | Cabecera C (manual) |
| `build/` | Artefactos generados (ignorado) |
| `godin.ps1` / `.cmd` / `.sh` | Task runner (sustituye a `just`) |
| `scripts/env.ps1` | Diagnóstico del entorno |
| `scripts/watch.ps1` | Hot-reload (Go + Odin) |
| `scripts/new-project.ps1` | Scaffolding de proyectos nuevos |
| `.golangci.yml` | Config de golangci-lint |
| `Dockerfile` | Cross-build Linux |
| `air.toml` | Config opcional de `air` (Go) |
| `.vscode/` | Tareas/settings/extensiones |
| `.github/workflows/` | CI (windows + linux) |
| `templates/interop-cgo/` | Esqueleto mínimo de interop |
| `docs/` | Esta documentación (`TEMPLATE.md`, `TOOLKIT-README.md`) |

## Comandos `godin`

```powershell
.\godin help            # o: pwsh -NoProfile -File godin.ps1 help
.\godin build           # odin shared -> go app
.\godin run             # ejecuta build/app.exe
.\godin test            # go test + odin test
.\godin fmt             # gofmt + odin strip-semicolon
.\godin fmt-check       # verifica formato (CI)
.\godin lint            # go vet + odin check + golangci-lint
.\godin lint-go         # solo golangci-lint
.\godin cover           # cobertura Go -> build/coverage.html
.\godin watch           # hot-reload: rebuild + rerun
.\godin watch-once      # valida el watcher sin observar
.\godin clean           # limpia build/
.\godin new <path> <mod>    # scaffolding de un proyecto nuevo
.\godin docker-linux        # -> build/linux/libgodin.so + build/linux/app
.\godin docker-linux-run    # smoke test Linux dentro del contenedor
.\godin docker-shell        # shell interactivo (debug)
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
.\godin build
.\godin run     # -> godin_version = 1 ; godin_add = 5 ; godin_sum = 10 ; ... ; callback = 14
.\godin test    # -> tests Go + 5 tests Odin
.\godin cover   # -> cobertura Go ≈ 92%
.\godin lint    # -> go vet + odin check + golangci-lint (0 issues)
```

## Requisitos del entorno

- Go, Odin (scoop), PowerShell 7 (`pwsh`), MSVC `link.exe`, gcc/mingw.
- Ver `README.md` para rutas exactas.
