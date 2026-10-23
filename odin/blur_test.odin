package godin

import "core:c"
import "core:testing"

// Independent, deliberately naive reference implementations used to validate
// the optimized kernels. O(w*h*r^2) and O(w*h*25): slow but obviously correct.

@(private = "file")
ref_box :: proc(src: [^]u8, w, h, x, y, r, ch: int) -> u8 {
	n := 2*r + 1
	half := u32(n / 2)
	// Separable, with rounding after each pass (same as the optimized kernel).
	sum: u32
	for dy in -r ..= r {
		yy := clamp(y+dy, 0, h-1)
		hsum: u32
		for dx in -r ..= r {
			xx := clamp(x+dx, 0, w-1)
			hsum += u32(src[(yy*w+xx)*4+ch])
		}
		sum += (hsum + half) / u32(n)
	}
	return u8((sum + half) / u32(n))
}

@(private = "file")
ref_gauss :: proc(src: [^]u8, w, h, x, y, ch: int) -> u8 {
	k: [5]u32 = {1, 4, 6, 4, 1}
	// Separable, with rounding after each pass (same as the optimized kernel).
	sum: u32
	for i in 0 ..< 5 {
		yy := clamp(y+i-2, 0, h-1)
		hsum: u32
		for j in 0 ..< 5 {
			xx := clamp(x+j-2, 0, w-1)
			hsum += k[j] * u32(src[(yy*w+xx)*4+ch])
		}
		sum += k[i] * ((hsum + 8) >> 4)
	}
	return u8((sum + 8) >> 4)
}

@(private = "file")
fill_pattern :: proc(buf: []u8) {
	for i in 0 ..< len(buf) {
		buf[i] = u8((i*37 + (i/7)*11 + 13) % 256)
	}
}

W :: 17
H :: 11
NPX :: W * H * 4

@(test)
test_blur_box_matches_reference :: proc(t: ^testing.T) {
	src, dst, tmp: [NPX]u8
	fill_pattern(src[:])

	radii := [?]int{0, 1, 3, 20}
	for r in radii {
		for i in 0 ..< NPX {
			dst[i] = 0xFF
		}
		godin_blur_box_rgba(raw_data(src[:]), raw_data(dst[:]), raw_data(tmp[:]), W, H, c.int(r))
		for y in 0 ..< H {
			for x in 0 ..< W {
				for ch in 0 ..< 4 {
					want := ref_box(raw_data(src[:]), W, H, x, y, r, ch)
					got := dst[(y*W+x)*4+ch]
					ok := got == want
					testing.expectf(t, ok, "box r=%d (%d,%d) ch=%d: got %d, want %d", r, x, y, ch, got, want)
					if !ok {
						return
					}
				}
			}
		}
	}
}

@(test)
test_blur_gauss_matches_reference :: proc(t: ^testing.T) {
	src, dst, tmp: [NPX]u8
	fill_pattern(src[:])
	for i in 0 ..< NPX {
		dst[i] = 0xFF
	}

	godin_blur_gauss5_rgba(raw_data(src[:]), raw_data(dst[:]), raw_data(tmp[:]), W, H)

	for y in 0 ..< H {
		for x in 0 ..< W {
			for ch in 0 ..< 4 {
				want := ref_gauss(raw_data(src[:]), W, H, x, y, ch)
				got := dst[(y*W+x)*4+ch]
				ok := got == want
				testing.expectf(t, ok, "gauss (%d,%d) ch=%d: got %d, want %d", x, y, ch, got, want)
				if !ok {
					return
				}
			}
		}
	}
}

@(test)
test_blur_tiny_sizes :: proc(t: ^testing.T) {
	// 1x1: every kernel must return the input pixel unchanged.
	one_src := [4]u8{10, 20, 30, 40}
	one_dst, one_tmp: [4]u8
	godin_blur_box_rgba(raw_data(one_src[:]), raw_data(one_dst[:]), raw_data(one_tmp[:]), 1, 1, 9)
	testing.expect_value(t, one_dst, [4]u8{10, 20, 30, 40})
	godin_blur_gauss5_rgba(raw_data(one_src[:]), raw_data(one_dst[:]), raw_data(one_tmp[:]), 1, 1)
	testing.expect_value(t, one_dst, [4]u8{10, 20, 30, 40})

	// 1xN (single column) and Nx1 (single row) must not read out of bounds.
	col_src: [7 * 4]u8
	col_dst, col_tmp: [7 * 4]u8
	fill_pattern(col_src[:])
	godin_blur_box_rgba(raw_data(col_src[:]), raw_data(col_dst[:]), raw_data(col_tmp[:]), 1, 7, 2)
	godin_blur_gauss5_rgba(raw_data(col_src[:]), raw_data(col_dst[:]), raw_data(col_tmp[:]), 1, 7)

	row_src: [7 * 4]u8
	row_dst, row_tmp: [7 * 4]u8
	fill_pattern(row_src[:])
	godin_blur_box_rgba(raw_data(row_src[:]), raw_data(row_dst[:]), raw_data(row_tmp[:]), 7, 1, 2)
	godin_blur_gauss5_rgba(raw_data(row_src[:]), raw_data(row_dst[:]), raw_data(row_tmp[:]), 7, 1)

	// Empty images are a no-op (must not touch buffers).
	godin_blur_box_rgba(raw_data(one_src[:]), raw_data(one_dst[:]), raw_data(one_tmp[:]), 0, 1, 1)
	godin_blur_box_rgba(raw_data(one_src[:]), raw_data(one_dst[:]), raw_data(one_tmp[:]), 1, 0, 1)

	// Negative radius is clamped to 0 (identity).
	neg_dst: [4]u8
	godin_blur_box_rgba(raw_data(one_src[:]), raw_data(neg_dst[:]), raw_data(one_tmp[:]), 1, 1, -5)
	testing.expect_value(t, neg_dst, [4]u8{10, 20, 30, 40})
}
