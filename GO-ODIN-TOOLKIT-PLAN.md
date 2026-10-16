# Toolkit para programar en Go y Odin simultáneamente

## 1) Definir "simultáneo" (preguntas para acotar)

Antes de diseñar archivos, necesito que me aclares el objetivo:

| Pregunta | Opciones | Notas |
|---|---|---|
| ¿Qué quieres lograr con "simultáneo"? | (a) Editar ambos idiomas en el mismo proyecto (políglota) / (b) Ejecutar herramientas/editor en paralelo / (c) Ambos + interop (Go llama Odin) / (d) Otro | Determina si necesito bindings (cgo + shared lib de Odin) o solo orquestación de tareas. |
| ¿Hay relación entre ellos? | (a) Independientes (dos apps) / (b) Acoplados (Go orquesta lógica de Odin, p.ej. rendimiento) / (c) Aún no lo sé | Si (b), priorizamos plantillas de FFI/ABI C. |
| ¿Editor/entorno? | VS Code, Neovim, Zed, Emacs, CLI-only | Para generar `.vscode/settings.json`, `tasks.json`, `launch.json` o configs agnósticos. |
| ¿Sistema objetivo? | win32 (actual), Linux, cross-compile | Afecta rutas, `.dll/.so/.a`, `odin build` flags. |
| ¿Gestor de tareas preferido? | `just` (justfile), `Taskfile.yaml` (go-task), `Makefile`, scripts `pwsh/ps1` + `bash` | Quiero elegir uno para unificar ambos. |
| ¿Necesitas hot-reload? | Sí/No (¿air para Go, y watcher para Odin?) | Útil si vas a iterar mucho. |
| ¿Quieres que incluya CI? | Sí/No (GitHub Actions) | Puede esperar, pero útil definir comandos unificados. |

Responde lo que prefieras (etiquetas (a)-(d) bastan).

## 2) Explorar el repositorio actual (lectura)

Voy a inspeccionar `C:\Users\pauli\Documents\junior\godin` para detectar lo que ya existe (Go/Odin, build, configs). Esto evita duplicar y te muestra estado real.

Llamo a un agente de exploración con esto:

- Descripción: `scan godin repo for Go+Odin workspace`
- Prompt:
  ```
  Scan C:\Users\pauli\Documents\junior\godin (read-only). 
  1) List top-level (tree-like, concise).
  2) Detect languages: *.go, go.mod, *.odin, odin.json? build scripts, justfile/Justfile, Taskfile*, Makefile, *.ps1/*.sh, README*, AGENTS*, .vscode.
  3) If .odin present: note entrypoints (main.odin/proc/*.odin), build cmds seen.
  4) If .go present: note go.mod, cmd/, internal/, pkg/.
  5) Look for existing task orchestration (tasks.json, just, task).
  6) Identify obvious interop (cgo comments, .h, -build-mode:c-shared, #cgo).
  7) Return a short inventory + 3-5 observations.
  ```
- subagent_type: `explore`
- (thoroughness: quick/medium) – empezaré con `quick`

## 3) Arquitectura propuesta del toolkit

Una vez tenga inventario + tus respuestas, estructuraría así (agnóstico a editor):

| Componente | Propósito | Sugerido |
|---|---|---|
| `workspace/` layout | Separar idiomas sin mezclar | `go/` (o raíz con go.mod), `odin/`, `shared/` (headers/libs), `build/` (artefactos), `scripts/` (unificados). |
| Task runner único | Un comando para ambos | `just` (simple, cross-platform, Windows OK). Generar `justfile` con targets: `build`, `test`, `fmt`, `lint`, `watch`, `clean`, `all`. |
| Build unificado | Compilar según relación | Si independientes: build ambos. Si acoplados: build Odin lib (`-build-mode:c-shared`) -> build Go con cgo -> link. |
| Calidad | Formato + lint | `gofmt`/`goimports`, `odin fmt` (o `odin build -vet` según versión), `go vet`, optional `golangci-lint`. |
| Hot-reload (opcional) | Iteración rápida | `air` (Go). Para Odin: simple file watcher (`fswatch`/`watchexec`/PowerShell) que re-ejecuta `odin build/run`. |
| Editor integration | DX | `.vscode/tasks.json` (invoca just), `settings.json` (format on save por archivo), `extensions.json`. También configs neutrales para otros editores. |
| Plantillas | Inicio rápido | `templates/interop-cgo/` con `lib.odin` (export), `api.h`, `main.go` con `#cgo`, ejemplo build. |
| Env/paths | Encontrar odin/go | `scripts/env.ps1`/`.env.example` con `ODIN_ROOT`, `GOOS/GOARCH`. |
| Docs | Uso | `docs/toolkit.md` (comandos, layout, interop, troubleshooting). |

Tradeoffs:
- **cgo + Odin shared**: máximo rendimiento, pero build más frágil (flags, calling convention, tipos).
- **IPC (stdin/stdout/json + subprocess)**: más desacoplado, debug fácil, overhead pequeño. Recomendado si relación no es crítica aún.
- **WASM**: porta entre ecosistemas, pero limitante si necesitas syscalls nativos.

## 4) Plan de implementación (fases, sin ediciones aún)

| Fase | Acción | Verificable |
|---|---|---|
| P0 (Descubrimiento) | Ejecutar exploración (arriba). Leer README existente. Confirmar rutas odin.exe/go. | Inventario claro + respuestas del usuario. |
| P1 (Infra base) | Diseñar `justfile` con targets mínimos (build/test/fmt/clean). Crear `scripts/` con wrappers PS1/Bash si necesario. | `just --list` conceptual (después de crear). |
| P2 (Calidad + editor) | Definir `.vscode/*` coherente con convenciones del repo. Agregar `tools/` (version pins) si útil. | Settings/tasks válidos. |
| P3 (Interop template) | Solo si (b)/(c). Esqueleto cgo+Odin compartido + README de cómo compilar en win32. | Build smoke-test plan. |
| P4 (Hot-reload + DX) | Añadir `air.toml` (Go) + watcher Odin. Documentar. | Flujo iterativo definido. |
| P5 (Docs + validación) | `docs/toolkit.md` + checklist. Plan de pruebas (build ambos, link). | Checklist ejecutable. |

## 5) Siguiente paso inmediato

1. Responde a las 7 preguntas (sección 1).
2. Yo lanzo la exploración del repo (sección 2) con el agente `explore` (solo lectura).
3. Con inventario + respuestas, genero el `justfile`, estructura, templates y `.vscode/*` propuestos **para revisión** (aún sin escribir archivos), y ajusto según lo que encuentre.

---

## 6) ESTADO FINAL (aplicado)

Decisiones del usuario:
- Objetivo: ejecutar archivos de ambos y que **se comuniquen entre sí**.
- Relación: acoplados vía **ABI de C** (Odin shared lib + Go cgo).
- Editor: **VS Code**. Target: **cross-compile**. CI: **sí**.
- Task runner / hot-reload: a criterio del agente → **just**; hot-reload documentado (air/watchexec).

Fases completadas: P0 (exploración, dir vacío salvo el plan) → P5 (docs + validación).

Verificación real (win32):
- `just build` → `build/godin.dll` + `build/godin.lib` + `build/app.exe`
- `just run`:
  ```
  godin_version() = 1
  godin_add(2, 3) = 5
  godin_str_len("hello from Go") = 13
  godin_sum({1,2,3,4}) = 10
  godin_scale({1,2,3}, 2) = {2, 4, 6}
  godin_make_vec3(4,5,6) = {4, 5, 6}
  ```
- `just test` → `go test ok` + Odin "3 tests successful"
- `just fmt` / `just lint` / `just clean` → exit 0
- `just watch-once` → build OK; watcher detecta cambios y reconstruye.

Interop cubierto: escalares, string C, slice (puntero+longitud), struct por
puntero y struct por valor. Hot-reload vía `scripts/watch.ps1` (+ `air.toml`).

Ajustes vs. plan original:
- `-build-mode:c-shared` **no existe** en el Odin nightly → `-build-mode:shared` + `shared/godin.h` manual.
- `odin fmt` **no existe** → `odin strip-semicolon`; `check`/`strip-semicolon` requieren `-no-entry-point`.
- Odin `shared` requiere **MSVC `link.exe`** → justfile lo autolocaliza.
- `cgo` usa **gcc/mingw** y enlaza el `.lib` de MSVC; `godin.dll` debe estar en PATH en runtime.

Toolchain (se mantiene vía **scoop**, no winget):
- Go `1.26.4`, Odin `dev-2026-05-nightly`, just `1.59.0`.
- Odin **no existe** en winget; reinstalar Go vía winget crearía conflicto con el shim de scoop → se acordó mantener scoop.

---

## 7) ENDURECIMIENTO (iteración 2)

1. **Repo git**: `git init` (rama `main`), `.gitattributes` (LF, CRLF en `.ps1`),
   `.gitignore` ampliado, primer commit.

2. **Cross-compile real (Linux)**: se confirmó que **Odin no puede cross-linkear
   desde Windows** (`Linking for cross compilation ... not supported`) y `cgo`
   necesita toolchain del target. Solución: **Docker**.
   - `Dockerfile` (multi-stage): `golang:1.26-bookworm` + `clang` + Odin `dev-2026-10`.
   - `just docker-linux` extrae `build/linux/{libgodin.so,app}`.
   - `just docker-linux-run` smoke test; `just docker-shell` para depurar.
   - Go Linux con `RUNPATH=$ORIGIN` para hallar `libgodin.so`.
   - Verificado: la app Linux imprime lo mismo que en Windows.

3. **Interop endurecido**:
   - **Errores**: `godin_div` + `godin_last_error` (cstring).
   - **Callbacks**: `go/callback.go` (`//export go_square`) → `godin_apply`
     (`ApplyFn = proc "c" (c.double) -> c.double`).
   - **Ownership**: `godin_dup` con `libc.malloc` + `godin_free`.
     *Hallazgo*: NO usar el allocator de Odin — su runtime no se inicializa al
     cargar la lib desde Go (segfault en `mem.alloc`).

Verificación final (win32 + Docker linux): `just build/run/test/fmt/lint` → OK;
run imprime también `godin_div`, `godin_apply` (=14) y `godin_dup`; **5 tests Odin**
+ go test; `just docker-linux-run` OK.

---

## 8) CALIDAD Y PLANTILLA (iteración 3)

1. **golangci-lint** (`v2.14.0` vía winget): `.golangci.yml` (schema v2,
   `default: standard` + errcheck/govet/staticcheck/revive/gocritic/unparam/...).
   Recetas `just lint` (incluye golangci-lint si está) y `just lint-go`.
   `just lint` → **0 issues**.

2. **Refactor cgo**: toda la capa cgo vive ahora en `go/api.go` (wrappers Go);
   `go/callback.go` exporta `go_square`; tests en `go/interop_test.go` usan
   wrappers (cgo **no está soportado en `_test.go`**). `main.go` → `run()`.
   - **Cobertura**: `just cover` → **91.8%**, HTML en `build/coverage.html`.
   - Añadido `just fmt-check` (verifica formato para CI).

3. **CI**: jobs Windows + Linux con formato, lint, build, test, cobertura
   (subida como artefacto), smoke test; `ODIN_VERSION`/`GOLANGCI_VERSION` como env.
   Badges en README (placeholder `OWNER` a sustituir al publicar).

4. **Plantilla reutilizable**: `scripts/new-project.ps1` + `just new <path> <mod>`.
   - Copia scaffolding excluyendo `.git`, `build`, `.vs`, `.idea`, `node_modules`,
     logs y `GO-ODIN-TOOLKIT-PLAN.md`.
   - Reescribe `go/go.mod` (module) y `README.md` (badges `OWNER`/`godin` + H1).
   - `docs/TEMPLATE.md` documenta uso + cómo marcar el repo como template en GitHub.
   - **Verificado**: proyecto generado (`github.com/acme/mytool`) compila y corre.

