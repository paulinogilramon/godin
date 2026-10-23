# TODO — endurecer calidad y "plug and play" (iteración 5)

> Estado vivo del bucle. Cada ítem se marca `[x]` solo cuando su criterio de
> aceptación pasa en local. Un commit por ítem (`loop: <id> <resumen>`).

## P1 — Plug and play (runner)

- [x] **PP1 · `godin doctor`** — `scripts/doctor.ps1` + comando `godin doctor`.
  Comprueba pwsh, go, odin, gcc, link.exe (Win) / clang (Linux), golangci-lint
  y docker; muestra versión y ruta; `OK`/`WARN`/`FALTA` + pista de instalación.
  Sale 1 si falta algo obligatorio (pwsh/go/odin/linker).
  *Criterio:* `.\godin doctor` exit 0 aquí; con `PATH` sin `odin` → exit 1 y
  mensaje claro. Funciona en Linux (sin MSVC).

- [x] **PP2 · `godin version` + `godin check`** — versión del runner
  (`0.5.0`) + versiones de go/odin; `check` = `fmt-check` + `lint` + `test`.
  *Criterio:* ambos comandos exit 0; aparecen en `godin help` y en `.vscode/tasks.json`.

- [x] **PP3 · `godin test-race`** — `go test -race` (cgo + DLL) separado de
  `test` para no ralentizar el bucle normal.
  *Criterio:* exit 0 en win32; añadido a CI Linux.

- [x] **PP4 · `godin test-template`** — `scripts/test-template.ps1`:
  scaffold en `build/template-smoke` con `new-project.ps1`, `godin build` +
  `godin run` y comprueba salida; limpia al final. Demuestra que la plantilla
  es plug and play.
  *Criterio:* exit 0 y la salida contiene `godin_add(2, 3) = 5`.

- [ ] **PP5 · `.editorconfig`** — LF por defecto, CRLF en `.ps1/.cmd/.bat`,
  indent 2 en JSON/YAML, tabs en Go, UTF-8.
  *Criterio:* archivo presente y coherente con `.gitattributes`.

## P2 — Tests y cobertura

- [ ] **T1 · Go: cerrar gaps** — `LastError`, `ApplySquares(empty)`,
  `Dup("")`, `Dup` unicode, `Add` negativos, `Sum` un elemento, ejecutar `main()`.
  *Criterio:* `godin cover` ≥ 95% total.

- [ ] **T2 · Odin: más casos** — `godin_version`, `godin_str_len` (vacío/ASCII),
  `godin_make_vec3`, `godin_apply`, `godin_sum` con n=0, `godin_free(nil)`,
  `godin_dup` vacío.
  *Criterio:* `odin test odin` ≥ 10 tests, todos OK.

- [ ] **T3 · Benchmarks** — `go/api_test.go` con `BenchmarkAdd`/`BenchmarkSum`
  y comando `godin bench`.
  *Criterio:* `.\godin bench` exit 0 y muestra ns/op.

- [ ] **T4 · Puerta de cobertura** — `scripts/coverage-check.ps1 -Min 95`,
  invocado desde `godin cover` y CI.
  *Criterio:* con umbral 99 → exit 1; con 95 → exit 0.

## P3 — CI

- [ ] **CI1 · Workflow más robusto** — `workflow_dispatch`, `concurrency`,
  `permissions: contents: read`, `GO_VERSION` pinneado, paso `doctor`, gate de
  cobertura, `test-race` en Linux.
  *Criterio:* YAML válido (`pwsh` + parser o `actionlint` si está) y jobs
  coherentes con los comandos locales.

- [ ] **CI2 · Smoke de plantilla en CI** — job `template` en matrix
  Windows+Linux que ejecuta `godin test-template`.
  *Criterio:* job definido y reproducible en local.

## P4 — Documentación y plantilla

- [ ] **D1 · README genérico y quickstart** — quitar rutas/versiones
  personales, "3 pasos" (`doctor` → `build` → `run`), tabla de comandos
  actualizada, troubleshooting, badges con nota de `OWNER`.
  *Criterio:* README sin `C:\Users\pauli`; quickstart copiable.

- [ ] **D2 · `docs/TROUBLESHOOTING.md`** — link.exe no encontrado, DLL no
  encontrada (0xc000007b), odin nightly/versión, gcc/cgo, pwsh ausente,
  golangci-lint ausente, Docker.
  *Criterio:* cada síntoma con causa + fix verificado.

- [ ] **D3 · `docs/ARCHITECTURE.md`** — layout, flujo de build, contrato ABI,
  ownership, checklist "añadir un símbolo" (odin → header → wrapper → test → docs).
  *Criterio:* checklist aplicable a un símbolo nuevo.

- [ ] **D4 · Metadatos del repo** — `LICENSE` (MIT), `CHANGELOG.md`,
  `CONTRIBUTING.md`, actualizar `docs/TEMPLATE.md`.
  *Criterio:* archivos presentes y enlazados desde README.

- [ ] **D5 · Plantilla realmente funcional** — `templates/interop-cgo/main.go`
  llama a `godin_add` y corre; `docs/TEMPLATE.md` refleja `doctor/check`.
  *Criterio:* `godin test-template` cubre también el template suelto (PP4) y
  `templates/interop-cgo` compila por sí mismo.

## Cierre

- [ ] **Z1 · Verificación final** — `godin fmt-check`, `lint`, `test`,
  `cover`, `bench`, `test-template`, `doctor`, `run` en verde; `git status`
  limpio salvo commits del bucle.
  *Criterio:* todos exit 0 y salida documentada en `GO-ODIN-TOOLKIT-PLAN.md` §10.
