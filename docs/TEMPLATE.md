# Plantilla reutilizable: Go + Odin (C ABI)

Este repo funciona como plantilla para arrancar un proyecto que combina **Go**
(y `cgo`) con **Odin** (librería compartida) a través de la **ABI de C**.

## Generar un proyecto nuevo

```powershell
pwsh -File scripts/new-project.ps1 -Path ..\mi-proyecto -Module github.com/tu-org/mi-proyecto
# o, desde just:
just new ..\mi-proyecto github.com/tu-org/mi-proyecto
```

Parámetros:

| Parámetro | Descripción |
|---|---|
| `-Path` | Directorio destino del proyecto nuevo. |
| `-Module` | Ruta del módulo Go (`host/owner/repo`). |
| `-Name` | Nombre del repo (opcional; por defecto = último segmento del módulo). |
| `-Force` | Sobrescribe el destino si existe. |

Qué copia y qué no:

- **Copia** el scaffolding completo: `justfile`, `Dockerfile`, `air.toml`,
  `go/`, `odin/`, `shared/`, `scripts/`, `.vscode/`, `.github/`, `.golangci.yml`, `.gitattributes`, `.gitignore`, `.dockerignore`, `README.md`, `docs/`.
- **Excluye**: `.git/`, `build/`, `.vs/`, `.idea/`, `node_modules/`, logs, temporales
  y `GO-ODIN-TOOLKIT-PLAN.md` (documenta este proyecto, no la plantilla).

Reescritura automática:

- `go/go.mod` → `module <Module>`.
- `README.md` → placeholders de badges (`OWNER`/`godin`) y el título H1.

Verificado end-to-end: el proyecto generado compila y ejecuta
(`just build`, `just run`, `just test`, `just lint`).

## Usarlo como template de GitHub

1. Sube este repo a GitHub.
2. En **Settings → General → Template repository**, márcalo como plantilla.
3. "Use this template" genera un repo nuevo; ejecuta `scripts/new-project.ps1`
   o ajusta `go.mod` y badges manualmente.

> Nota: la API de demo usa el prefijo `godin_` y el paquete `godin`. Para tu
> proyecto, renombra esos símbolos según convenga (no lo hace el scaffolder,
> para evitar renombres erróneos).

## Pasos siguientes tras generar

```powershell
cd ..\mi-proyecto
git init
just build
just run
just test
```
