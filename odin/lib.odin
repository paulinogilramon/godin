package godin

import "core:c"
import "core:testing"

foreign import "C"

Vec3 :: struct {
	x, y, z: c.double,
}

@(export)
godin_version :: proc() -> c.int {
	return 1
}

@(export)
godin_add :: proc(a: c.int, b: c.int) -> c.int {
	return a + b
}

// Returns the length (bytes) of a NUL-terminated C string.
@(export)
godin_str_len :: proc(s: cstring) -> c.int {
	return c.int(len(string(s)))
}

// Sums n doubles pointed to by xs.
@(export)
godin_sum :: proc(xs: [^]c.double, n: c.int) -> c.double {
	total: c.double = 0
	for i in 0 ..< int(n) {
		total += xs[i]
	}
	return total
}

// Scales a Vec3 in place through a pointer (out-parameter).
@(export)
godin_scale :: proc(v: ^Vec3, k: c.double) {
	v.x *= k
	v.y *= k
	v.z *= k
}

// Returns a Vec3 by value.
@(export)
godin_make_vec3 :: proc(x, y, z: c.double) -> Vec3 {
	return Vec3{x, y, z}
}

@(test)
test_godin_add :: proc(t: ^testing.T) {
	testing.expect_value(t, godin_add(2, 3), c.int(5))
}

@(test)
test_godin_sum :: proc(t: ^testing.T) {
	xs := [?]c.double{1, 2, 3, 4}
	testing.expect_value(t, godin_sum(raw_data(xs[:]), 4), c.double(10))
}

@(test)
test_godin_scale :: proc(t: ^testing.T) {
	v := Vec3{1, 2, 3}
	godin_scale(&v, 2)
	testing.expect_value(t, v, Vec3{2, 4, 6})
}
