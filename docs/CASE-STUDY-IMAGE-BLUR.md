# Caso práctico: desenfoque de imagen con Go + Odin (ABI C)

> **Objetivo:** demostrar, con datos reproducibles, que el toolkit `godin` permite
> delegar bucles calientes a Odin manteniendo I/O, CLI y validación en Go, midiendo
> velocidad, asignaciones, portabilidad y ergonomía.

## 1) Alcance y diseño

- **Caso real:** convolución separable sobre RGBA8.
  - *Box blur* separable con radio arbitrario (2 pasadas por eje; coste O(1) por píxel).
  - *Gaussiano 5x5* separable con pesos `(1,4,6,4,1)/16` (2 pasadas por eje). Un
    kernel simétrico de 5x5 produce 25 lecturas teóricas, pero la versión separable
    pasa a 2×5 lecturas, lo que lo hace representativo de bucles con buen reuso.
- **Arquitectura:** Go orquesta lectura/escritura PNG/JPEG, conversión a `*image.NRGBA`,
  *hashing* SHA-256, temporización y CLI. Odin implementa los bucles internos
  ([`odin/blur.odin`](../odin/blur.odin)). El contrato C está en
  [`shared/godin.h`](../shared/godin.h); los *wrappers* cgo viven en
  [`go/blur/blur.go`](../go/blur/blur.go).
- **APIs sin asignaciones:** las funciones requieren `src`, `dst`, `tmp` propiedad
  del llamador. `go test` confirma `TestNoAllocs`. Ambos *backends* usan la misma
  validación (`validate`).
- **Determinismo:** Go y Odin deben producir bytes idénticos. Las pruebas de
  equivalencia comparan contra referencias separables independientes
  ([`go/blur/blur_test.go`](../go/blur/blur_test.go), [`odin/blur_test.odin`](../odin/blur_test.odin)).
  La ejecución completa de [`scripts/case-study.ps1`](../scripts/case-study.ps1)
  comprueba 3 hashes de píxeles distintos entre ejecuciones, impls y plataformas
  y falla si hay discrepancia.

## 2) Entorno de medición

| Campo | Valor (extraído de `build/case-study/results.txt`) |
| --- | --- |
| SO | Windows 10.0.26300 (amd64), Docker Desktop/WSL2 para Linux |
| CPU | Intel(R) Core(TM) Ultra 9 185H (16C/22T), híbrido P/E/LP |
| Go | go1.26.4 windows/amd64 |
| Odin | dev-2026-05-nightly:ea5175d (MSVC *linker*) |
| Compilador/link | gcc/cgo, `odin build -build-mode:shared` |
| Modo Odin release | `-o:speed` (el script fuerza `-o:minimal` para comparar) |
| Mediciones | `go test -bench -benchmem -cpu 1 -benchtime 300ms -count 3` (mejor/minima mediana) |

> *Limitación:* portátil/laptop con *Turbo Boost* variable, *throttling* térmico
> entre suites pesadas y migración P/E. Se usan `-cpu 1`, *warmup* + `ResetTimer`,
> `-count 3`, mínimo entre repeticiones, *cooldowns* entre variantes/suites y
> CLI con 5 repeticiones reportando **promedio y mejor**. Aun así, las mediciones
> de 4K son las más ruidosas (b.N=1 en muchas iteraciones).

## 3) Coste de `cgo`

| Métrica | Windows (speed, `-cpu 1`) | Linux/WSL2 |
| --- | --- | --- |
| `BenchmarkCallOverhead` (llamada vacía Odin) | **62 ns (min)** / 90 ns (mediana) | **38 ns** (n=1) |

- En baldosas de **8×8** el kernel separable Gauss 5x5 tarda ~0.8 µs en Odin;
  el *overhead* ~60-90 ns representa **~7-10%** de la llamada.
- A partir de **~32×32** el *overhead* se amortiza hasta ser marginal
  (**~0.5-3%**); ver tabla de *tiles*.
- Con imágenes completas (≥640×480) el *overhead* fijo es irrelevante frente al
  trabajo del bucle (decenas-miles de µs).

## 4) Rendimiento por implementación y optimización

### Variante Odin (comparación justa, misma plataforma)

Las tres variantes se miden en secuencias consecutivas (1080p) para minimizar sesgo
térmico; Go aparece en cada suite como línea base.

**1080p (1920×1080, RGBA), Gauss 5x5 separable:**

| Variante Odin | Go min/med (ns) | Odin min/med (ns) | Speedup min/med | Notas |
| --- | --- | --- | --- | --- |
| `-o:minimal` (por defecto Odin) | 80.1M / 105.1M | 105.3M / 192.9M | **0.76× / 0.55×** | Más lento que Go. Justifica cambiar el valor por defecto a `-o:speed`. |
| `-o:speed` | 63.6M / 88.8M | 50.3M / 53.2M | **1.26× / 1.67×** | Ganancia clara; mucho mejor tras optimización. |
| `-o:speed -no-bounds-check` | 69.5M / 95.8M | 44.3M / 51.0M | **1.57× / 1.88×** | Mejora pequeña/variable (ver más abajo). |

**1080p Box blur r=8:**

| Variante Odin | Go min/med (ns) | Odin min/med (ns) | Speedup min/med |
| --- | --- | --- | --- |
| `-o:minimal` | 52.6M / 56.6M | 52.4M / 53.6M | 1.00× / 1.06× |
| `-o:speed` | 52.1M / 55.1M | 52.8M / 53.3M | 0.99× / 1.03× |
| `-o:speed -no-bounds-check` | 55.9M / 56.6M | 53.2M / 54.3M | 1.05× / 1.04× |

El *box blur* separable con suma acumulada es mayoritariamente **limitado por
memoria/ancho de banda** y con poca carga aritmética; las diferencias son
pequeñas o nulas. Esto es un resultado honesto (no todas las cargas ganan).

### Matriz completa (Windows, variante `speed`, mejor de 3)

| Tamaño | Box Go min/med | Box Odin min/med | Box x(min/med) | Gauss Go min/med | Gauss Odin min/med | Gauss x(min/med) |
| --- | --- | --- | --- | --- | --- | --- |
| 640×480 | 8.39M / 8.63M | 5.13M / 5.27M | **1.63× / 1.64×** | 6.79M / 7.31M | 3.66M / 3.87M | **1.86× / 1.89×** |
| 1920×1080 | 60.5M / 84.4M | 54.7M / 61.0M | 1.11× / 1.38× | 63.6M / 65.3M | 35.5M / 60.2M | **1.79× / 1.08×** |
| 3840×2160 | 479M / 486M | 315M / 432M | **1.52× / 1.12×** | 407M / 412M | 318M / 329M | **1.28× / 1.25×** |

La elevada varianza en 1920/3840 (b.N pequeño, *page faults*, *thermal throttling*,
frecuencia CPU) es visible. Las **medianas/minimas** muestran la tendencia:
Gauss gana 1.25-1.9× en tamaños razonables; *box* gana en resoluciones pequeñas
(donde cabe mejor en caché) y tiende a empatarse en 4K (limitado por memoria).

### Linux (Docker/WSL2), misma CPU, `libgodin.so` con `-o:speed`

| Tamaño | Box x(min/med) | Gauss x(min/med) |
| --- | --- | --- |
| 640×480 | 1.08× / 1.08× | **1.81× / 1.81×** |
| 1920×1080 | 1.03× / 1.03× | **1.48× / 1.48×** |
| 3840×2160 | 0.96× / 0.96× | **1.18× / 1.18×** |

Los *hashes* de píxeles son **idénticos** a Windows (misma semilla) para los tres
casos de uso, demostrando portabilidad/consistencia entre plataformas.

### Comprobación de *bounds checks*

Con `-no-bounds-check` el programa confía en las validaciones de Go (buffers,
dimensiones). En 1080p Gauss: **1.57× min / 1.88× med** vs **1.26× / 1.67×** con
checks. La ganancia es **0-20%** según tamaño y **casi nula en 4K** (limitado por
memoria). Dado el coste de seguridad reducido y la variabilidad, el *default*
documentado es **`-o:speed` con *bounds checks* habilitados**.

## 5) Amortización de *cgo*: *tile sweep* (Gauss 5x5)

Medido en Windows con la variante `speed` (`-cpu 1`, mejor de 3):

| Tile | Go min (ns) / MB/s | Odin min (ns) / MB/s | Speedup | Notas |
| --- | --- | --- | --- | --- |
| 8×8 (256 B) | 1579 / 162 | 801 / 319 | **1.97×** | *Overhead* cgo aún amortizado (kernel mucho más rápido). |
| 16×16 (1KB) | 6415 / 160 | 3099 / 330 | **2.07×** | |
| 32×32 (4KB) | 35293 / 116 | 13074 / 313 | **2.70×** | |
| 64×64 (16KB) | 91009 / 180 | 50532 / 324 | **1.80×** | |
| 128×128 (64KB) | 463916 / 141 | 222184 / 295 | **2.09×** | Entra en caché L2/L1. |
| 256×256 (256KB) | 1397700 / 188 | 920083 / 285 | **1.52×** | |
| 512×512 (1MB) | 6277385 / 167 | 4667889 / 224 | **1.34×** | Limitado por memoria. |

**Punto de equilibrio práctico:** con ~60-90 ns de *overhead*, un kernel
Gauss 5x5 en Odin (separable) alcanza paridad o superior incluso en **8×8**; para
la gran mayoría de usos reales (baldosas ≥32² o imágenes completas) el *overhead*
es despreciable. Para kernels muy baratas podría importarse, pero aquí no es el
caso.

## 6) End-to-end (CLI real)

El CLI realiza I/O, decodificación PNG/JPEG, conversión NRGBA, validación,
*hashing* y escribe salida. Tiempos con **5 repeticiones, promedio y mejor pasda**
(promedio menos sesgado por migración P/E que un solo disparo).

**Windows (ordenado después de build, antes de *benchmarks* pesados):**

| Caso | Go avg / best (ms) | Odin avg / best (ms) | Speedup best | Hash |
| --- | --- | --- | --- | --- |
| 1920×1080 Box r=8 | 51.18 / 43.19 | 43.88 / 36.46 | **1.19×** | `13e134...effc` |
| 1920×1080 Gauss 5x5 | 54.67 / 45.21 | 39.29 / 37.13 | **1.22×** | `4d8a23...e3fb` |
| 3840×2160 Gauss 5x5 | 367.59 / 352.00 | 478.72 / 295.59 | **1.19×** (mejor) | `ccddc9...686c` |

En 4K el mejor de Odin es 1.19× mientras el promedio se ve afectado por una
pasada lenta (scheduling/temperatura). Los **hashes Go/Odin coinciden** en los 3
casos.

**Linux/WSL2 (Docker):**

| Caso | Go avg / best (ms) | Odin avg / best (ms) | Speedup best |
| --- | --- | --- | --- |
| 1920×1080 Box r=8 | 56.05 / 53.65 | 52.59 / 50.00 | **1.07×** |
| 1920×1080 Gauss 5x5 | 60.13 / 51.10 | 42.01 / 38.01 | **1.34×** |

Los hashes Linux son **idénticos** a Windows, demostrando portabilidad binaria a
nivel de resultados.

## 7) Memoria y asignaciones

- **Sin asignaciones en bucles:** `go/blur/bench_test.go` usa `b.ReportAllocs()` y
  todas las mediciones muestran `0 B/op 0 allocs/op`. Las pruebas llaman
  `TestNoAllocs`.
- **Buffers propiedad del llamador:** `src/dst/tmp` se asignan en el llamador
  (Go), evitando asignaciones en el camino caliente. Esto es crítico para
  servidores/gráficos en tiempo real.
- **Copia mínima:** el CLI convierte a `*image.NRGBA` una vez.

## 8) Portabilidad y compilación cruzada

- **ABI C estable:** contrato en `shared/godin.h`, Odin `-build-mode:shared`,
  Go `cgo`. Funciona en Windows (DLL) y Linux (`.so`).
- **Detección automática de rutas:** Linux usa `-Wl,-rpath,$ORIGIN` tanto en
  `go/api.go` como en `go/blur/blur.go` para cargar la librería desde el mismo
  directorio.
- **Cross-compilación Linux:** [`Dockerfile`](../Dockerfile) construye
  `libgodin.so` + `app` + `blur` con Odin en contenedor (Odin no puede
  *cross-link* fácilmente desde Windows).
- **Verificado:** hashes idénticos Windows/Linux; *smoke test* CI ejecuta
  `blur -impl both`.

## 9) Mantenibilidad y ergonomía

| Aspecto | Go puro | Go + Odin (godin) |
| --- | --- | --- |
| I/O/CLI/validación/tests | Sencillo, idiomático | Igual en Go; Odin solo kernel. Código claro con API unificada `blur.Apply`. |
| Rendimiento kernel | Competitivo o mejor en cargas limitadas por memoria; peor en bucles aritméticamente densos tras optimizar | **1.2-1.9×** en Gauss 5x5 (optimizado `-o:speed`); empatado en *box* limitados por memoria. |
| Depuración | Más fácil (stack traces, race detector) | Los errores se propagan como mensajes; *bounds checks* configurables; separable con referencias para validar. |
| Complejidad build | Solo Go | `godin` automatiza Odin→shared lib, cgo, PATH/`rpath`. CI cubre ambas plataformas. |
| Seguridad | Go memory safe | Buffer sizes validados en Go; Odin puede usar `-no-bounds-check` solo si confianza total. |

## 10) Amenazas a la validez

- **Calor/ruido térmico:** portátil; se mitiga con *warmup*, `-cpu 1`, mejores/min
  de repeticiones, *cooldowns*, CLI con mejor de 5.
- **Híbrido P/E:** migración de hilos puede explicar varianza en 4K/CLI.
- **b.N pequeño en 4K:** 1 iteración por ejecución → muy sensible a estado
  (caché, frecuencia).
- **Docker/WSL2:** rendimiento menor que Linux nativo (visible en algunos números),
  pero **correctitud idéntica**.
- **Microarquitectura fija:** evitar `-microarch:native` para mantener portabilidad.
- **cgo overhead medido aisladamente:** `BenchmarkCallOverhead` mide llamada
  vacía (realista).
- **Resultados son de esta máquina/fecha:** reproducibles con
  `.\godin case-study` (genera `build/case-study/results.txt`).

## 11) Reproducibilidad

```powershell
.\godin doctor        # toolchain
.\godin test          # Go + Odin tests (equivalencia, sin allocs)
.\godin case-study    # benchmark + CLI + variantes + Docker + validación hashes
```

Salida: `build/case-study/results.txt`, imágenes generadas y logs. Los comandos
del *task runner* añaden PATH/`rpath` automáticamente.

## 12) Conclusión

- **Ganancias reales:** con Odin `-o:speed`, el desenfoque Gaussiano 5x5 se acelera
  **~1.2-1.9×** en 640p/1080p; en 4K **~1.25×**. *Box blur* limitado por memoria
  **0-64% según resolución** (paridad frecuente).
- **Importante:** el valor por defecto **`-o:minimal` es perjudicial** (más lento que
  Go) — el proyecto cambia `godin build` a **`-o:speed`**.
- **Coste justificado:** *overhead* cgo ~60-90 ns, amortizado completamente en
  trabajo real; buffers cero-asignación; validación compartida.
- **Portabilidad demostrada:** binarios distintos (Windows DLL / Linux .so),
  **resultados píxel-iguales** en ambas plataformas.
- **Honesto:** se documentan cargas sin ganancia (*box* 4K/memoria limitada) y
  variabilidad por termal/híbrido.

**Todos los números provienen de [`build/case-study/results.txt`](../build/case-study/results.txt)
generado por la ejecución reproducible del caso de estudio.**
