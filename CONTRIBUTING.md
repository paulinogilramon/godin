# Contributing

Gracias por contribuir. Este repo es a la vez una herramienta y una plantilla,
así que los cambios deben dejar ambos casos funcionando.

## Setup

```powershell
git clone <repo> && cd godin
.\godin doctor     # debe salir 0
.\godin build
.\godin test
```

Si `doctor` falla, sigue las pistas que imprime o
[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Flujo de trabajo

1. Crea una rama: `git switch -c feat/mi-cambio`.
2. Haz el cambio **con tests** (Go y/u Odin según corresponda).
3. Pasa el gate local:

   ```powershell
   godin fmt
   godin check        # fmt-check + lint + test
   godin cover        # gate 95%
   godin test-template # si tocas el scaffolding o el runner
   ```

4. Actualiza docs/changelog si el cambio es visible para el usuario.
5. Abre el PR con una descripción corta y la salida de `godin check`.

## Estilo

- **Go**: `gofmt` (tabs), nombres exported documentados (`revive` con
  `exported` desactivado, pero se agradece el comentario).
- **Odin**: tabs, `odin strip-semicolon`; exports con `@(export)` y tipos
  `core:c`.
- **PowerShell**: compatible con pwsh 7; usa `Push-Location`/`finally` y
  comprueba `$LASTEXITCODE` de cada comando nativo.
- **Docs**: UTF-8, LF, sin rutas absolutas de tu máquina.
- **Commits**: imperativo y acotado (`feat: add godin doctor`,
  `fix: resolve coverage profile from go/`). Un tema por commit.

## Añadir un símbolo de interop

Sigue el checklist de
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#añadir-un-símbolo-checklist):
Odin → header → wrapper Go → tests Go/Odin → demo → docs → `godin check`.

Reglas que no se negocian:

- Nada de allocator/runtime de Odin cruzando a Go.
- Ownership explícito en cada función que devuelva memoria.
- Callbacks con calling convention `"c"`.

## CI

El workflow corre en Windows y Linux. Si tu cambio es solo de documentación,
con `godin fmt-check` suele bastar, pero el PR debe quedar en verde.

## Reportar bugs

Incluye la salida de:

```powershell
godin doctor
godin version
godin test
```

y los pasos mínimos para reproducirlo.
