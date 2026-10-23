// Package blur implements two deterministic RGBA8 image kernels twice: once
// in Go (BoxGo, GaussGo) and once in Odin across the C ABI (BoxOdin,
// GaussOdin). It is the subject of docs/CASE-STUDY-IMAGE-BLUR.md.
//
// All functions take caller-owned buffers (src, dst and a scratch tmp of the
// same length) and perform no allocations, so both implementations can be
// compared on equal terms.
package blur

/*
#cgo CFLAGS: -I${SRCDIR}/../../shared
#cgo windows LDFLAGS: -L${SRCDIR}/../../build -lgodin
#cgo linux LDFLAGS: -L${SRCDIR}/../../build -lgodin -ldl -lm -Wl,-rpath,$ORIGIN
#include "godin.h"
*/
import "C"

import (
	"fmt"
	"unsafe"
)

// Op identifies a blur kernel.
type Op int

const (
	// Box is a separable box blur with an arbitrary radius (O(1) per pixel).
	Box Op = iota
	// Gauss5 is a separable 5x5 Gaussian blur with weights 1,4,6,4,1 / 16.
	Gauss5
)

// String returns the CLI name of the operation.
func (o Op) String() string {
	switch o {
	case Box:
		return "box"
	case Gauss5:
		return "gauss"
	default:
		return "unknown"
	}
}

// ParseOp maps a CLI name to an Op.
func ParseOp(s string) (Op, error) {
	switch s {
	case "box":
		return Box, nil
	case "gauss", "gauss5":
		return Gauss5, nil
	default:
		return 0, fmt.Errorf("blur: unknown op %q (want box or gauss)", s)
	}
}

// Pixels returns w*h*4 if the buffers are valid for that size.
func validate(dst, src, tmp []byte, w, h int) error {
	if w <= 0 || h <= 0 {
		return fmt.Errorf("blur: invalid image size %dx%d", w, h)
	}
	n := int64(w) * int64(h) * 4
	if n > int64(len(src)) {
		return fmt.Errorf("blur: src is %d bytes, need %d for %dx%d RGBA", len(src), n, w, h)
	}
	if n > int64(len(dst)) {
		return fmt.Errorf("blur: dst is %d bytes, need %d for %dx%d RGBA", len(dst), n, w, h)
	}
	if n > int64(len(tmp)) {
		return fmt.Errorf("blur: tmp is %d bytes, need %d for %dx%d RGBA", len(tmp), n, w, h)
	}
	return nil
}

// BoxGo applies the box blur in pure Go.
func BoxGo(dst, src, tmp []byte, w, h, radius int) error {
	if err := validate(dst, src, tmp, w, h); err != nil {
		return err
	}
	if radius < 0 {
		return fmt.Errorf("blur: negative radius %d", radius)
	}
	boxH(tmp, src, w, h, radius)
	boxV(dst, tmp, w, h, radius)
	return nil
}

// BoxOdin applies the box blur in Odin.
func BoxOdin(dst, src, tmp []byte, w, h, radius int) error {
	if err := validate(dst, src, tmp, w, h); err != nil {
		return err
	}
	if radius < 0 {
		return fmt.Errorf("blur: negative radius %d", radius)
	}
	C.godin_blur_box_rgba(
		(*C.uchar)(unsafe.Pointer(&src[0])),
		(*C.uchar)(unsafe.Pointer(&dst[0])),
		(*C.uchar)(unsafe.Pointer(&tmp[0])),
		C.int(w), C.int(h), C.int(radius),
	)
	return nil
}

// GaussGo applies the 5x5 Gaussian blur in pure Go.
func GaussGo(dst, src, tmp []byte, w, h int) error {
	if err := validate(dst, src, tmp, w, h); err != nil {
		return err
	}
	gaussH(tmp, src, w, h)
	gaussV(dst, tmp, w, h)
	return nil
}

// GaussOdin applies the 5x5 Gaussian blur in Odin.
func GaussOdin(dst, src, tmp []byte, w, h int) error {
	if err := validate(dst, src, tmp, w, h); err != nil {
		return err
	}
	C.godin_blur_gauss5_rgba(
		(*C.uchar)(unsafe.Pointer(&src[0])),
		(*C.uchar)(unsafe.Pointer(&dst[0])),
		(*C.uchar)(unsafe.Pointer(&tmp[0])),
		C.int(w), C.int(h),
	)
	return nil
}

// Apply runs op with the chosen implementation ("go" or "odin").
func Apply(impl string, op Op, dst, src, tmp []byte, w, h, radius int) error {
	switch impl {
	case "go":
		if op == Box {
			return BoxGo(dst, src, tmp, w, h, radius)
		}
		return GaussGo(dst, src, tmp, w, h)
	case "odin":
		if op == Box {
			return BoxOdin(dst, src, tmp, w, h, radius)
		}
		return GaussOdin(dst, src, tmp, w, h)
	default:
		return fmt.Errorf("blur: unknown impl %q (want go or odin)", impl)
	}
}

// OdinVersion returns the version reported by the Odin library. It exists to
// measure the fixed cost of a cgo call in benchmarks.
func OdinVersion() int { return int(C.godin_version()) }

// ---------------------------------------------------------------- box blur --

func boxH(dst, src []byte, w, h, r int) {
	n := 2*r + 1
	den := uint32(n)
	half := uint32(n / 2)

	for y := 0; y < h; y++ {
		base := y * w * 4

		// Taps -r..0 clamp to pixel 0; taps 1..r are real pixels.
		s0 := uint32(r+1) * uint32(src[base+0])
		s1 := uint32(r+1) * uint32(src[base+1])
		s2 := uint32(r+1) * uint32(src[base+2])
		s3 := uint32(r+1) * uint32(src[base+3])
		for i := 1; i <= r; i++ {
			p := base + min(i, w-1)*4
			s0 += uint32(src[p+0])
			s1 += uint32(src[p+1])
			s2 += uint32(src[p+2])
			s3 += uint32(src[p+3])
		}

		d := base
		dst[d+0] = byte((s0 + half) / den)
		dst[d+1] = byte((s1 + half) / den)
		dst[d+2] = byte((s2 + half) / den)
		dst[d+3] = byte((s3 + half) / den)

		for x := 1; x < w; x++ {
			add := base + min(x+r, w-1)*4
			sub := base + max(x-r-1, 0)*4
			s0 = s0 + uint32(src[add+0]) - uint32(src[sub+0])
			s1 = s1 + uint32(src[add+1]) - uint32(src[sub+1])
			s2 = s2 + uint32(src[add+2]) - uint32(src[sub+2])
			s3 = s3 + uint32(src[add+3]) - uint32(src[sub+3])

			d = base + x*4
			dst[d+0] = byte((s0 + half) / den)
			dst[d+1] = byte((s1 + half) / den)
			dst[d+2] = byte((s2 + half) / den)
			dst[d+3] = byte((s3 + half) / den)
		}
	}
}

func boxV(dst, src []byte, w, h, r int) {
	n := 2*r + 1
	den := uint32(n)
	half := uint32(n / 2)
	step := w * 4

	for x := 0; x < w; x++ {
		base := x * 4

		s0 := uint32(r+1) * uint32(src[base+0])
		s1 := uint32(r+1) * uint32(src[base+1])
		s2 := uint32(r+1) * uint32(src[base+2])
		s3 := uint32(r+1) * uint32(src[base+3])
		for i := 1; i <= r; i++ {
			p := base + min(i, h-1)*step
			s0 += uint32(src[p+0])
			s1 += uint32(src[p+1])
			s2 += uint32(src[p+2])
			s3 += uint32(src[p+3])
		}

		d := base
		dst[d+0] = byte((s0 + half) / den)
		dst[d+1] = byte((s1 + half) / den)
		dst[d+2] = byte((s2 + half) / den)
		dst[d+3] = byte((s3 + half) / den)

		for y := 1; y < h; y++ {
			add := base + min(y+r, h-1)*step
			sub := base + max(y-r-1, 0)*step
			s0 = s0 + uint32(src[add+0]) - uint32(src[sub+0])
			s1 = s1 + uint32(src[add+1]) - uint32(src[sub+1])
			s2 = s2 + uint32(src[add+2]) - uint32(src[sub+2])
			s3 = s3 + uint32(src[add+3]) - uint32(src[sub+3])

			d = base + y*step
			dst[d+0] = byte((s0 + half) / den)
			dst[d+1] = byte((s1 + half) / den)
			dst[d+2] = byte((s2 + half) / den)
			dst[d+3] = byte((s3 + half) / den)
		}
	}
}

// ------------------------------------------------------------ gaussian blur --

func gaussH(dst, src []byte, w, h int) {
	for y := 0; y < h; y++ {
		base := y * w * 4
		for x := 0; x < w; x++ {
			i0 := base + max(x-2, 0)*4
			i1 := base + max(x-1, 0)*4
			i2 := base + x*4
			i3 := base + min(x+1, w-1)*4
			i4 := base + min(x+2, w-1)*4
			d := base + x*4
			for ch := 0; ch < 4; ch++ {
				s := uint32(src[i0+ch]) +
					4*uint32(src[i1+ch]) +
					6*uint32(src[i2+ch]) +
					4*uint32(src[i3+ch]) +
					uint32(src[i4+ch])
				dst[d+ch] = byte((s + 8) >> 4)
			}
		}
	}
}

func gaussV(dst, src []byte, w, h int) {
	step := w * 4
	for x := 0; x < w; x++ {
		base := x * 4
		for y := 0; y < h; y++ {
			i0 := base + max(y-2, 0)*step
			i1 := base + max(y-1, 0)*step
			i2 := base + y*step
			i3 := base + min(y+1, h-1)*step
			i4 := base + min(y+2, h-1)*step
			d := base + y*step
			for ch := 0; ch < 4; ch++ {
				s := uint32(src[i0+ch]) +
					4*uint32(src[i1+ch]) +
					6*uint32(src[i2+ch]) +
					4*uint32(src[i3+ch]) +
					uint32(src[i4+ch])
				dst[d+ch] = byte((s + 8) >> 4)
			}
		}
	}
}
