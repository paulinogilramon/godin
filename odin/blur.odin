package godin

import "core:c"

// Real-world image kernels used by the case study. Both are separable and
// deterministic (integer arithmetic), so Go and Odin must produce identical
// bytes. Buffers are caller-owned: no allocations cross the ABI.

@(private = "file")
GAUSS5: [5]u32 = {1, 4, 6, 4, 1}

// Horizontal box pass: src -> dst, O(1) per pixel (running sums).
@(private = "file")
box_h :: proc(src, dst: [^]u8, w, h, r: int) {
	n := 2*r + 1
	den := u32(n)
	half := u32(n / 2)

	for y in 0 ..< h {
		base := y * w * 4
		s0, s1, s2, s3: u32

		// Window for x = 0: taps -r..0 clamp to pixel 0; 1..r are real.
		s0 = u32(r+1) * u32(src[base+0])
		s1 = u32(r+1) * u32(src[base+1])
		s2 = u32(r+1) * u32(src[base+2])
		s3 = u32(r+1) * u32(src[base+3])
		for i in 1 ..= r {
			p := base + min(i, w-1)*4
			s0 += u32(src[p+0])
			s1 += u32(src[p+1])
			s2 += u32(src[p+2])
			s3 += u32(src[p+3])
		}
		d := base
		dst[d+0] = u8((s0 + half) / den)
		dst[d+1] = u8((s1 + half) / den)
		dst[d+2] = u8((s2 + half) / den)
		dst[d+3] = u8((s3 + half) / den)

		for x in 1 ..< w {
			add := base + min(x+r, w-1)*4
			sub := base + max(x-r-1, 0)*4
			s0 = s0 + u32(src[add+0]) - u32(src[sub+0])
			s1 = s1 + u32(src[add+1]) - u32(src[sub+1])
			s2 = s2 + u32(src[add+2]) - u32(src[sub+2])
			s3 = s3 + u32(src[add+3]) - u32(src[sub+3])

			d = base + x*4
			dst[d+0] = u8((s0 + half) / den)
			dst[d+1] = u8((s1 + half) / den)
			dst[d+2] = u8((s2 + half) / den)
			dst[d+3] = u8((s3 + half) / den)
		}
	}
}

// Vertical box pass: src -> dst, O(1) per pixel.
@(private = "file")
box_v :: proc(src, dst: [^]u8, w, h, r: int) {
	n := 2*r + 1
	den := u32(n)
	half := u32(n / 2)
	step := w * 4

	for x in 0 ..< w {
		base := x * 4
		s0, s1, s2, s3: u32

		s0 = u32(r+1) * u32(src[base+0])
		s1 = u32(r+1) * u32(src[base+1])
		s2 = u32(r+1) * u32(src[base+2])
		s3 = u32(r+1) * u32(src[base+3])
		for i in 1 ..= r {
			p := base + min(i, h-1)*step
			s0 += u32(src[p+0])
			s1 += u32(src[p+1])
			s2 += u32(src[p+2])
			s3 += u32(src[p+3])
		}
		d := base
		dst[d+0] = u8((s0 + half) / den)
		dst[d+1] = u8((s1 + half) / den)
		dst[d+2] = u8((s2 + half) / den)
		dst[d+3] = u8((s3 + half) / den)

		for y in 1 ..< h {
			add := base + min(y+r, h-1)*step
			sub := base + max(y-r-1, 0)*step
			s0 = s0 + u32(src[add+0]) - u32(src[sub+0])
			s1 = s1 + u32(src[add+1]) - u32(src[sub+1])
			s2 = s2 + u32(src[add+2]) - u32(src[sub+2])
			s3 = s3 + u32(src[add+3]) - u32(src[sub+3])

			d = base + y*step
			dst[d+0] = u8((s0 + half) / den)
			dst[d+1] = u8((s1 + half) / den)
			dst[d+2] = u8((s2 + half) / den)
			dst[d+3] = u8((s3 + half) / den)
		}
	}
}

// Horizontal 5-tap Gaussian (weights 1,4,6,4,1 / 16 with rounding).
@(private = "file")
gauss_h :: proc(src, dst: [^]u8, w, h: int) {
	for y in 0 ..< h {
		base := y * w * 4
		for x in 0 ..< w {
			i0 := base + max(x-2, 0)*4
			i1 := base + max(x-1, 0)*4
			i2 := base + x*4
			i3 := base + min(x+1, w-1)*4
			i4 := base + min(x+2, w-1)*4
			d := base + x*4
			for ch in 0 ..< 4 {
				s :=
					GAUSS5[0]*u32(src[i0+ch]) +
					GAUSS5[1]*u32(src[i1+ch]) +
					GAUSS5[2]*u32(src[i2+ch]) +
					GAUSS5[3]*u32(src[i3+ch]) +
					GAUSS5[4]*u32(src[i4+ch])
				dst[d+ch] = u8((s + 8) >> 4)
			}
		}
	}
}

// Vertical 5-tap Gaussian, same weights.
@(private = "file")
gauss_v :: proc(src, dst: [^]u8, w, h: int) {
	step := w * 4
	for x in 0 ..< w {
		base := x * 4
		for y in 0 ..< h {
			i0 := base + max(y-2, 0)*step
			i1 := base + max(y-1, 0)*step
			i2 := base + y*step
			i3 := base + min(y+1, h-1)*step
			i4 := base + min(y+2, h-1)*step
			d := base + y*step
			for ch in 0 ..< 4 {
				s :=
					GAUSS5[0]*u32(src[i0+ch]) +
					GAUSS5[1]*u32(src[i1+ch]) +
					GAUSS5[2]*u32(src[i2+ch]) +
					GAUSS5[3]*u32(src[i3+ch]) +
					GAUSS5[4]*u32(src[i4+ch])
				dst[d+ch] = u8((s + 8) >> 4)
			}
		}
	}
}

// Box blur of an RGBA8 image with arbitrary radius (0 = copy). `tmp` must have
// the same size as `src`/`dst` (w*h*4 bytes). Edges are clamped.
@(export)
godin_blur_box_rgba :: proc(src, dst, tmp: [^]u8, w, h, radius: c.int) {
	W, H := int(w), int(h)
	if W <= 0 || H <= 0 {
		return
	}
	R := max(int(radius), 0)
	box_h(src, tmp, W, H, R)
	box_v(tmp, dst, W, H, R)
}

// 5x5 Gaussian blur of an RGBA8 image (separable, 1/16 kernel). `tmp` must have
// the same size as `src`/`dst` (w*h*4 bytes). Edges are clamped.
@(export)
godin_blur_gauss5_rgba :: proc(src, dst, tmp: [^]u8, w, h: c.int) {
	W, H := int(w), int(h)
	if W <= 0 || H <= 0 {
		return
	}
	gauss_h(src, tmp, W, H)
	gauss_v(tmp, dst, W, H)
}
