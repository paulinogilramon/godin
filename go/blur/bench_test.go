package blur

import (
	"fmt"
	"testing"
)

var benchSizes = []struct {
	name string
	w, h int
}{
	{"640x480", 640, 480},
	{"1920x1080", 1920, 1080},
	{"3840x2160", 3840, 2160},
}

func benchOp(b *testing.B, op Op, radius int) {
	b.Helper()
	for _, s := range benchSizes {
		n := s.w * s.h * 4
		src := pattern(n, 1)
		tmp := make([]byte, n)
		dst := make([]byte, n)
		for _, impl := range []string{"go", "odin"} {
			b.Run(fmt.Sprintf("%s/%s", s.name, impl), func(b *testing.B) {
				b.SetBytes(int64(n))
				b.ReportAllocs()
				if err := Apply(impl, op, dst, src, tmp, s.w, s.h, radius); err != nil {
					b.Fatal(err)
				}
				b.ResetTimer()
				for i := 0; i < b.N; i++ {
					if err := Apply(impl, op, dst, src, tmp, s.w, s.h, radius); err != nil {
						b.Fatal(err)
					}
				}
			})
		}
	}
}

// BenchmarkBox measures the O(1)-per-pixel box blur with radius 8.
func BenchmarkBox(b *testing.B) { benchOp(b, Box, 8) }

// BenchmarkGauss measures the compute-bound 5x5 Gaussian blur.
func BenchmarkGauss(b *testing.B) { benchOp(b, Gauss5, 0) }

// BenchmarkCallOverhead isolates the fixed cost of a cgo -> Odin call.
func BenchmarkCallOverhead(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if OdinVersion() != 1 {
			b.Fatal("bad version")
		}
	}
}

// BenchmarkTiles measures ns/px as a function of the work per cgo call. Small
// tiles are dominated by call overhead; the crossover is the amortization
// threshold quoted in the case study.
func BenchmarkTiles(b *testing.B) {
	for _, impl := range []string{"go", "odin"} {
		for _, ts := range []int{8, 16, 32, 64, 128, 256, 512} {
			n := ts * ts * 4
			src := pattern(n, 3)
			tmp := make([]byte, n)
			dst := make([]byte, n)
			b.Run(fmt.Sprintf("%s/%d", impl, ts), func(b *testing.B) {
				b.SetBytes(int64(n))
				b.ReportAllocs()
				if err := Apply(impl, Gauss5, dst, src, tmp, ts, ts, 0); err != nil {
					b.Fatal(err)
				}
				b.ResetTimer()
				for i := 0; i < b.N; i++ {
					if err := Apply(impl, Gauss5, dst, src, tmp, ts, ts, 0); err != nil {
						b.Fatal(err)
					}
				}
			})
		}
	}
}
