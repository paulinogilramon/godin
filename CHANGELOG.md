# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
versionado [SemVer](https://semver.org/lang/es/).

## [Unreleased]

### Added
- **Image blur case study** ([docs/CASE-STUDY-IMAGE-BLUR.md](docs/CASE-STUDY-IMAGE-BLUR.md)): Go CLI orchestrates I/O/validation/hashing; Odin implements separable box and 5×5 Gaussian across cgo. Reproducible `godin case-study` (benchmarks by variant/minimal/speed/nobounds, tile sweep, call overhead, Windows/Linux hashes). CLI `godin blur` (`box|gauss`, `go|odin|both`).
- `godin blur`, `godin case-study`, `godin odin-variant` commands in the task runner.
- Odin blur kernels/tests and `go/blur` package (pure Go + cgo) with `TestNoAllocs` and cross-implementation equality.
- CI smoke test “Case study smoke (Go == Odin)” on Windows and Linux.
- Docker builds `build/blur`; `go/blur` uses Linux `rpath=$ORIGIN`.

### Changed
- `godin build`/`odin-lib` now build with `-o:speed` (Odin default `-o:minimal` is significantly slower for this workload).
- `godin bench` targets `.` only; `godin cover` measures `.` and `./blur` (excludes CLI main).
- CLI `blur` reports average and best-of-N timings.

### Notes
- All blur outputs are byte-for-byte identical across Go/Odin and Windows/Linux (verified by the case study). Box blur is often memory-bandwidth limited; Gauss 5×5 separable shows ~1.2–1.9× with `-o:speed` in measured runs.


## [0.5.0] - 2026-10-23

### Added

- `godin doctor`: diagnóstico del toolchain con `OK/WARN/FALTA`, versiones,
  rutas y pistas de instalación; `exit 1` si falta algo obligatorio.
- `godin version`, `godin check` (fmt-check + lint + test), `godin test-race`,
  `godin bench`, `godin test-template`.
- Gate de cobertura Go al 95% (`scripts/coverage-check.ps1`), integrado en
  `godin cover`.
- Smoke test end-to-end de la plantilla (`scripts/test-template.ps1`):
  scaffoldea un proyecto, lo compila/ejecuta y valida también
  `templates/interop-cgo`.
- Tests Go para `LastError`, ramas vacías de `ApplySquares`/`Dup`, UTF-8,
  negativos y el entrypoint; tests Odin para versión, `str_len`, `make_vec3`,
  `apply`, `sum(n=0)`, `scale(0)`, `dup("")` y `free(nil)`.
- `docs/ARCHITECTURE.md`, `docs/TROUBLESHOOTING.md`, `CONTRIBUTING.md`,
  `LICENSE` (MIT), `.editorconfig` y este changelog.
- CI: `workflow_dispatch`, `concurrency`, `permissions`, `GO_VERSION`
  fijado, paso `doctor`, gate de cobertura, `-race` en Linux y job `template`
  en Windows + Linux.

### Changed

- README reescrito como quickstart genérico (sin rutas de máquina), tabla de
  comandos completa y enlaces a la documentación.
- `templates/interop-cgo/main.go` ahora llama de verdad a `godin_add`, no solo
  imprime un mensaje.
- `godin new` excluye `TODO.md` además del plan interno.

### Fixed

- Codificación UTF-8 de la documentación (`docs/TEMPLATE.md`,
  `docs/TOOLKIT-README.md`).
- `coverage-check` resuelve el módulo desde `go/` (antes fallaba desde la raíz).

## [0.4.0] - 2026-10-22

### Changed

- `just` sustituido por el runner propio `godin` (PowerShell 7 + wrappers
  `godin.cmd` / `godin.sh`), cross-platform.
- CI, `.vscode/tasks.json`, `air.toml` y `scripts/watch.ps1` actualizados.

### Removed

- `justfile` y la dependencia de `just`.

## [0.3.0] - 2026-10-21

### Added

- `golangci-lint` v2 con `.golangci.yml`, cobertura Go (~92%) y `fmt-check`.
- CI Windows + Linux con artefacto de cobertura y smoke test.
- Plantilla reutilizable: `scripts/new-project.ps1`, `godin new`,
  `docs/TEMPLATE.md`.

### Changed

- Toda la capa cgo vive en `go/api.go`; `main.go` delega en `run()`.

## [0.2.0] - 2026-10-20

### Added

- Cross-build Linux reproducible con Docker (`godin docker-linux*`).
- Manejo de errores (`godin_div` / `godin_last_error`), callbacks
  (`godin_apply`) y ownership (`godin_dup` / `godin_free` con libc).
- Repo git con `.gitattributes` / `.gitignore`.

## [0.1.0] - 2026-10-19

### Added

- Toolkit inicial: interop Go ↔ Odin por ABI de C (Odin shared lib + cgo).
- Layout `go/`, `odin/`, `shared/`, build unificado, hot-reload y docs.
