package blur

import (
	"bytes"
	"math/rand"
	"testing"
)

type size struct{ w, h int }

var sizes = []size{{1, 1}, {1, 7}, {7, 1}, {2, 2}, {7, 3}, {17, 11}, {64, 48}}

func pattern(n int, seed int64) []byte {
	b := make([]byte, n)
	r := rand.New(rand.NewSource(seed))
	_, _ = r.Read(b)
	return b
}

// Naive separable references, intentionally independent from blur.go.
func refBox(src []byte, w, h, x, y, radius, ch int) byte {
	n := 2*radius + 1
	half := uint32(n / 2)
	var sum uint32
	for dy := -radius; dy <= radius; dy++ {
		yy := clamp(y+dy, h-1)
		var hs uint32
		for dx := -radius; dx <= radius; dx++ {
			xx := clamp(x+dx, w-1)
			hs += uint32(src[(yy*w+xx)*4+ch])
		}
		sum += (hs + half) / uint32(n)
	}
	return byte((sum + half) / uint32(n))
}

func refGauss(src []byte, w, h, x, y, ch int) byte {
	k := [5]uint32{1, 4, 6, 4, 1}
	var sum uint32
	for i := 0; i < 5; i++ {
		yy := clamp(y+i-2, h-1)
		var hs uint32
		for j := 0; j < 5; j++ {
			xx := clamp(x+j-2, w-1)
			hs += k[j] * uint32(src[(yy*w+xx)*4+ch])
		}
		sum += k[i] * ((hs + 8) >> 4)
	}
	return byte((sum + 8) >> 4)
}

func clamp(v, hi int) int {
	if v < 0 {
		return 0
	}
	if v > hi {
		return hi
	}
	return v
}

func refAll(op Op, src []byte, w, h, radius int) []byte {
	out := make([]byte, w*h*4)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			for ch := 0; ch < 4; ch++ {
				if op == Box {
					out[(y*w+x)*4+ch] = refBox(src, w, h, x, y, radius, ch)
				} else {
					out[(y*w+x)*4+ch] = refGauss(src, w, h, x, y, ch)
				}
			}
		}
	}
	return out
}

func TestGoAndOdinMatchReference(t *testing.T) {
	radii := []int{0, 1, 3, 50}
	for _, s := range sizes {
		n := s.w * s.h * 4
		src := pattern(n, int64(s.w*1000+s.h))
		tmp := make([]byte, n)
		wantGauss := refAll(Gauss5, src, s.w, s.h, 0)

		for _, r := range radii {
			want := refAll(Box, src, s.w, s.h, r)
			for _, impl := range []struct {
				name string
				fn   func(dst, src, tmp []byte, w, h, radius int) error
			}{
				{"go", BoxGo},
				{"odin", BoxOdin},
			} {
				dst := make([]byte, n)
				if err := impl.fn(dst, src, tmp, s.w, s.h, r); err != nil {
					t.Fatalf("%s Box %dx%d r=%d: %v", impl.name, s.w, s.h, r, err)
				}
				if !bytes.Equal(dst, want) {
					t.Fatalf("%s Box %dx%d r=%d: first diff vs reference at %d", impl.name, s.w, s.h, r, firstDiff(dst, want))
				}
			}
		}

		for _, impl := range []struct {
			name string
			fn   func(dst, src, tmp []byte, w, h int) error
		}{
			{"go", GaussGo},
			{"odin", GaussOdin},
		} {
			dst := make([]byte, n)
			if err := impl.fn(dst, src, tmp, s.w, s.h); err != nil {
				t.Fatalf("%s Gauss %dx%d: %v", impl.name, s.w, s.h, err)
			}
			if !bytes.Equal(dst, wantGauss) {
				t.Fatalf("%s Gauss %dx%d: first diff vs reference at %d", impl.name, s.w, s.h, firstDiff(dst, wantGauss))
			}
		}
	}
}

func TestGoEqualsOdinLargeImage(t *testing.T) {
	const w, h = 320, 200
	n := w * h * 4
	src := pattern(n, 99)
	tmp := make([]byte, n)

	for _, op := range []Op{Box, Gauss5} {
		goOut := make([]byte, n)
		odinOut := make([]byte, n)
		if err := Apply("go", op, goOut, src, tmp, w, h, 7); err != nil {
			t.Fatal(err)
		}
		if err := Apply("odin", op, odinOut, src, tmp, w, h, 7); err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(goOut, odinOut) {
			t.Fatalf("%s: Go and Odin differ at byte %d", op, firstDiff(goOut, odinOut))
		}
	}
}

func firstDiff(a, b []byte) int {
	for i := range a {
		if a[i] != b[i] {
			return i
		}
	}
	return -1
}

func TestValidation(t *testing.T) {
	ok := make([]byte, 4)
	for _, tc := range []struct {
		name      string
		dst, src  []byte
		tmp       []byte
		w, h, rad int
		wantErr   bool
	}{
		{"ok", ok, ok, ok, 1, 1, 1, false},
		{"zero width", ok, ok, ok, 0, 1, 1, true},
		{"negative height", ok, ok, ok, 1, -1, 1, true},
		{"short src", ok, make([]byte, 3), ok, 1, 1, 1, true},
		{"short dst", make([]byte, 3), ok, ok, 1, 1, 1, true},
		{"short tmp", ok, ok, make([]byte, 3), 1, 1, 1, true},
		{"negative radius", ok, ok, ok, 1, 1, -1, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := BoxGo(tc.dst, tc.src, tc.tmp, tc.w, tc.h, tc.rad)
			if (err != nil) != tc.wantErr {
				t.Fatalf("BoxGo error = %v, wantErr %v", err, tc.wantErr)
			}
			err = BoxOdin(tc.dst, tc.src, tc.tmp, tc.w, tc.h, tc.rad)
			if (err != nil) != tc.wantErr {
				t.Fatalf("BoxOdin error = %v, wantErr %v", err, tc.wantErr)
			}
		})
	}
}

func TestApplyAndParse(t *testing.T) {
	if _, err := ParseOp("nope"); err == nil {
		t.Fatal("ParseOp(nope) should fail")
	}
	if op, err := ParseOp("gauss5"); err != nil || op != Gauss5 {
		t.Fatalf("ParseOp(gauss5) = %v, %v", op, err)
	}
	if op, err := ParseOp("box"); err != nil || op != Box {
		t.Fatalf("ParseOp(box) = %v, %v", op, err)
	}
	if Box.String() != "box" || Gauss5.String() != "gauss" || Op(99).String() != "unknown" {
		t.Fatal("unexpected Op.String")
	}
	if err := Apply("rust", Box, make([]byte, 4), make([]byte, 4), make([]byte, 4), 1, 1, 0); err == nil {
		t.Fatal("Apply(rust) should fail")
	}
	if got := OdinVersion(); got != 1 {
		t.Fatalf("OdinVersion = %d, want 1", got)
	}
}

func TestNoAllocs(t *testing.T) {
	const w, h = 64, 48
	n := w * h * 4
	src := pattern(n, 7)
	dst := make([]byte, n)
	tmp := make([]byte, n)

	for _, op := range []Op{Box, Gauss5} {
		for _, impl := range []string{"go", "odin"} {
			allocs := testing.AllocsPerRun(3, func() {
				if err := Apply(impl, op, dst, src, tmp, w, h, 4); err != nil {
					t.Fatal(err)
				}
			})
			if allocs != 0 {
				t.Fatalf("%s/%s: %v allocs/op, want 0", impl, op, allocs)
			}
		}
	}
}
