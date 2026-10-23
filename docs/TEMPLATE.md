# Plantilla reutilizable: Go + Odin (C ABI)

Este repo es una plantilla para arrancar un proyecto que combina **Go** (cgo)
con **Odin** (shared library) a través de la **ABI de C**.

## Generar un proyecto nuevo

```powershell
pwsh -File scripts/new-project.ps1 -Path ..\mi-proyecto -Module github.com/tu-org/mi-proyecto
# o, con el task runner:
.\godin new ..\mi-proyecto github.com/tu-org/mi-proyecto
```

| Parámetro | Descripción |
|---|---|
| `-Path` | Directorio destino del proyecto nuevo. |
| `-Module` | Ruta del módulo Go (`host/owner/repo`). |
| `-Name` | Nombre del repo (opcional; por defecto, último segmento del módulo). |
| `-Force` | Sobrescribe el destino si existe. |

Qué copia y qué no:

- **Copia** el scaffolding completo: `godin.ps1`, `godin.cmd`, `godin.sh`,
  `Dockerfile`, `air.toml`, `go/`, `odin/`, `shared/`, `scripts/`, `.vscode/`,
  `.github/`, `.golangci.yml`, `.editorconfig`, `.gitattributes`, `.gitignore`,
  `.dockerignore`, `README.md`, `LICENSE`, `CHANGELOG.md`, `CONTRIBUTING.md`,
  `docs/` y `templates/`.
- **Excluye**: `.git/`, `build/`, `.vs/`, `.idea/`, `node_modules/`, logs,
  temporales y los archivos internos `GO-ODIN-TOOLKIT-PLAN.md` y `TODO.md`.

Reescritura automática:

- `go/go.mod` → `module <Module>`.
- `README.md` → badges (`OWNER`/`godin`) y título H1.

## Validar la plantilla

```powershell
godin test-template
```

Hace dos comprobaciones end-to-end en `build/` (se limpian al terminar):

1. Scaffoldea un proyecto completo, lo compila con su propio `godin` y verifica
   la salida del demo.
2. Ensambla `templates/interop-cgo` (`main.go` + `lib.odin` + `godin.h`) y
   comprueba que también compila y ejecuta.

Si falla, conserva los artefactos con
`pwsh -File scripts/test-template.ps1 -Keep` y revisa `build/template-*`.

## Pasos siguientes tras generar

```powershell
cd ..\mi-proyecto
git init
.\godin doctor
.\godin build
.\godin run
.\godin check
```

## Usarlo como template de GitHub

1. Sube este repo a GitHub.
2. En **Settings → General → Template repository**, márcalo como plantilla.
3. "Use this template" genera un repo nuevo; después ejecuta
   `scripts/new-project.ps1` o ajusta `go.mod` y badges manualmente.

> Nota: la API de demo usa el prefijo `godin_` y el paquete `godin`. Para tu
> proyecto, renombra esos símbolos según convenga (el scaffolder no lo hace
> para evitar renombres erróneos). El checklist para añadir/renombrar símbolos
> está en [`ARCHITECTURE.md`](ARCHITECTURE.md#añadir-un-símbolo-checklist).

## Qué queda a tu cargo

- `LICENSE`: el copyright dice "godin contributors"; pon tu nombre/org.
- Badges: reemplaza `OWNER` (el scaffolder ya lo hace si usas `godin new`).
- `CHANGELOG.md`: empieza tu propia historia o bórralo.
- CI: `ODIN_VERSION` / `GOLANGCI_VERSION` en `.github/workflows/ci.yml`.
