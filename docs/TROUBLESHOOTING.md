# Troubleshooting

Empieza siempre por:

```powershell
godin doctor     # estado del toolchain
godin version    # versiones de godin/go/odin/pwsh
godin clean      # borra build/ y obliga a recompilar
```

Si `godin doctor` devuelve `exit 1`, falta una dependencia **obligatoria** y el
propio comando indica cómo instalarla.

---

## `link.exe` not found / Odin no puede enlazar la DLL (Windows)

**Síntoma**

```
Linking for ... failed
link.exe: not found
```

**Causa**: Odin usa MSVC para producir la shared library; `link.exe` solo
existe si instalaste el workload de C++.

**Fix**

1. Instala **Visual Studio Build Tools** (o Visual Studio) con
   *Desktop development with C++*.
2. Comprueba: `godin doctor` debe mostrar `link.exe OK`.
3. `godin` busca `link.exe` bajo `%ProgramFiles%\Microsoft Visual Studio\...`
   y lo añade al `PATH` del proceso; no hace falta tocar el `PATH` global.

---

## `godin.dll` no encontrada (0xc000007b / "code execution cannot proceed")

**Síntoma**: la app compila pero al ejecutar el `.exe` falla al cargar
`godin.dll`, o Windows devuelve `0xc000007b`.

**Causas**

1. El `.dll` no está junto al `.exe` ni en `PATH`.
2. Mezcla de arquitecturas: Odin x64 + gcc/mingw x86 (o viceversa).

**Fix**

- Ejecuta con `godin run` (añade `build/` al `PATH`) o copia
  `build/godin.dll` junto a `build/app.exe`.
- Usa toolchains de 64 bits: `go env GOARCH` = `amd64`, Odin x64 y mingw x64.
- `0xc000007b` casi siempre es arquitectura, no un fichero ausente.

---

## `odin: command not found` / versión distinta a la esperada

**Fix**

- Windows: `scoop install odin` (o descomprime la release y añade el directorio
  al `PATH`).
- Linux/macOS: descarga la release de Odin y exporta
  `PATH="$PATH:/ruta/a/odin"`.
- Comprueba con `odin version` y `godin doctor`.
- La CI y el `Dockerfile` fijan `ODIN_VERSION` (`dev-2026-10`). Si tu nightly
  local es más nueva y algo deja de compilar, prueba con la versión fijada.

---

## `odin build` falla con `-build-mode:c-shared`

**Causa**: ese modo no existe en las nightlies actuales.

**Fix**: usa `-build-mode:shared`. El repo ya lo hace; si copiaste comandos de
documentación antigua, actualízalos.

---

## `odin fmt` no existe / `check` pide entry point

**Fix**

- Formato: `odin strip-semicolon odin -no-entry-point` (lo hace `godin fmt`).
- `odin check` y `strip-semicolon` necesitan `-no-entry-point` en librerías.
- `godin fmt-check` verifica sin modificar (falla si hay cambios pendientes).

---

## `gcc: command not found` / `cgo: C compiler not found`

**Causa**: cgo necesita un compilador C del target.

**Fix**

- Windows: `scoop install mingw`; verifica `gcc --version`.
- Debian/Ubuntu: `sudo apt-get install build-essential`.
- macOS: `xcode-select --install`.
- Comprueba que cgo está activo: `go env CGO_ENABLED` debe ser `1`
  (`go env -w CGO_ENABLED=1`).

---

## `godin: command not found` (Linux/macOS)

`godin.sh` necesita permiso de ejecución:

```sh
chmod +x godin.sh godin.ps1
./godin.sh doctor
```

Si `pwsh` no existe, instala PowerShell 7; el runner no funciona con `sh`.

---

## `go.mod file not found` al ejecutar `go` a mano

El módulo está en `go/`, no en la raíz:

```powershell
cd go
go test ./...
```

O usa el runner desde la raíz: `godin test`. Todos los comandos de `godin`
hacen `Push-Location` internamente.

---

## `golangci-lint not installed; skipping`

Es opcional: `godin lint` sigue con `go vet` + `odin check`. Para tenerlo:

```powershell
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.14.0
```

Si tu versión es v1, la config `.golangci.yml` (schema v2) no carga.

---

## `go test -race` falla en Windows

El detector de carreras requiere cgo y gcc. Si `godin test` pasa pero
`godin test-race` no, revisa `gcc` y `CGO_ENABLED` con `godin doctor`. En CI el
`-race` solo corre en Linux.

---

## Docker: no se puede hacer cross-build Linux

**Síntoma**: `godin docker-linux` falla al arrancar o el contenedor no compila.

**Causas**

1. Docker Desktop/Engine no está corriendo.
2. Odin **no** puede cross-linkear desde Windows; hay que compilar dentro del
   contenedor (por eso existe `Dockerfile`).
3. Falta `clang` en la imagen (ya está instalado en el `Dockerfile`).

**Fix**: arranca Docker, ejecuta `godin docker-linux-run` para validar la
imagen y `godin docker-shell` para depurar dentro.

---

## Tests de Odin con memoria/allocator

No uses el allocator de Odin (`mem.alloc`) para memoria que cruza a Go: el
runtime de Odin no se inicializa al cargar la shared library desde Go
(provoca segfault). Usa `libc.malloc` + `godin_free`, como `godin_dup`.

---

## Nada de lo anterior funciona

Adjunta la salida de estos comandos al abrir un issue:

```powershell
godin doctor
godin version
godin fmt-check
godin lint
godin test
```

Y el sistema operativo/arquitectura (`$PSVersionTable`, `go env GOOS GOARCH`,
`odin version`).
