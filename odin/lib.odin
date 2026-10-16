package godin

import "core:c"
import "core:c/libc"
import "core:mem"
import "core:testing"

foreign import "C"

Vec3 :: struct {
	x, y, z: c.double,
}

// C function-pointer type: double (*)(double)
ApplyFn :: #type proc "c" (x: c.double) -> c.double

@(private = "file")
last_error: cstring

@(private = "file")
set_error :: proc(msg: cstring) {
	last_error = msg
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

// Error handling: divides a/b and records the last error on b == 0.
@(export)
godin_div :: proc(a, b: c.double) -> c.double {
	if b == 0 {
		set_error("division by zero")
		return 0
	}
	set_error("")
	return a / b
}

// Returns the last error message (empty cstring if none).
@(export)
godin_last_error :: proc() -> cstring {
	return last_error
}

// Callback: applies f to each of n doubles and returns the sum.
// Demonstrates Odin invoking a Go function pointer across the C ABI.
@(export)
godin_apply :: proc(xs: [^]c.double, n: c.int, f: ApplyFn) -> c.double {
	total: c.double = 0
	for i in 0 ..< int(n) {
		total += f(xs[i])
	}
	return total
}

// Memory ownership: duplicates a C string into Odin-owned memory (libc malloc).
// The caller MUST release it with godin_free.
@(export)
godin_dup :: proc(s: cstring) -> cstring {
	n := len(string(s)) + 1
	buf := libc.malloc(c.size_t(n))
	if buf == nil {
		return nil
	}
	mem.copy(buf, rawptr(s), n)
	return cast(cstring)buf
}

// Frees memory previously returned by godin_dup.
@(export)
godin_free :: proc(p: rawptr) {
	if p != nil {
		libc.free(p)
	}
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

@(test)
test_godin_div_error :: proc(t: ^testing.T) {
	_ = godin_div(1, 0)
	testing.expect_value(t, string(godin_last_error()), "division by zero")
	_ = godin_div(6, 2)
	testing.expect_value(t, string(godin_last_error()), "")
}

@(test)
test_godin_dup_free :: proc(t: ^testing.T) {
	orig := cstring("hello")
	dup := godin_dup(orig)
	testing.expect_value(t, string(dup), "hello")
	testing.expect(t, rawptr(dup) != rawptr(orig), "expected a fresh allocation")
	godin_free(rawptr(dup))
}
