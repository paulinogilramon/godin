# TODO — caso real: blur de imagen (iteración 6) [COMPLETADO]

> Caso práctico implementado y medido. Evidencia en `build/case-study/results.txt`
> e informe en [`docs/CASE-STUDY-IMAGE-BLUR.md`](docs/CASE-STUDY-IMAGE-BLUR.md).

- [x] **CS1** Kernels Odin `odin/blur.odin` + tests con referencias separables; contrato en `shared/godin.h` (`godin_blur_box_rgba`, `godin_blur_gauss5_rgba`).
- [x] **CS2** Paquete `go/blur` (Go puro + cgo), validación, API unificada `Apply`, CLI `go/cmd/blur` (`go|odin|both`, box/gauss, gen, SHA-256, igualdad forzada).
- [x] **CS3** Equivalencia y bordes cubiertos; `TestNoAllocs`; `godin test` verde.
- [x] **CS4** Benchmarks box/gauss 640/1080/4K, `BenchmarkCallOverhead`, *tile sweep* 8–512; `godin build` con `-o:speed`.
- [x] **CS5** `scripts/case-study.ps1`, comandos `godin blur/case-study/odin-variant`; variantes `minimal`/`speed`/`speed-nobounds`.
- [x] **CS6** `docs/CASE-STUDY-IMAGE-BLUR.md` con metodología, resultados medidos, *overhead* cgo, amortización, matriz de decisión, amenazas a la validez.
- [x] **CS7** Portabilidad Docker/Linux validada (hashes idénticos); CI smoke test `blur -impl both`.
- [x] **CS8** README/CHANGELOG/PLAN actualizados; `godin fmt/check/cover` verdes.
