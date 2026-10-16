package main

/*
#cgo CFLAGS: -I../shared
#cgo windows LDFLAGS: -L../build -lgodin
#cgo linux LDFLAGS: -L../build -lgodin -ldl -lm -Wl,-rpath,$ORIGIN
#include <stdlib.h>
#include "godin.h"

extern double go_square(double);
static godin_apply_fn go_square_ptr(void) { return go_square; }
*/
import "C"
import "unsafe"

// Version returns the Odin library version.
func Version() int { return int(C.godin_version()) }

// Add returns a + b computed in Odin.
func Add(a, b int) int { return int(C.godin_add(C.int(a), C.int(b))) }

// StrLen returns the byte length of s as measured by Odin.
func StrLen(s string) int {
	cs := C.CString(s)
	defer C.free(unsafe.Pointer(cs))
	return int(C.godin_str_len(cs))
}

// Vec3 mirrors the Odin struct across the C ABI.
type Vec3 struct{ X, Y, Z float64 }

// Sum returns the sum of xs computed in Odin.
func Sum(xs []float64) float64 {
	if len(xs) == 0 {
		return 0
	}
	cin := make([]C.double, len(xs))
	for i, x := range xs {
		cin[i] = C.double(x)
	}
	return float64(C.godin_sum(&cin[0], C.int(len(cin))))
}

// Scale multiplies v by k in Odin (struct by pointer).
func Scale(v Vec3, k float64) Vec3 {
	cv := C.Vec3{x: C.double(v.X), y: C.double(v.Y), z: C.double(v.Z)}
	C.godin_scale(&cv, C.double(k))
	return Vec3{X: float64(cv.x), Y: float64(cv.y), Z: float64(cv.z)}
}

// MakeVec3 builds a Vec3 in Odin (struct by value).
func MakeVec3(x, y, z float64) Vec3 {
	m := C.godin_make_vec3(C.double(x), C.double(y), C.double(z))
	return Vec3{X: float64(m.x), Y: float64(m.y), Z: float64(m.z)}
}

// Div returns a/b and the last error message (empty when there is none).
func Div(a, b float64) (float64, string) {
	r := float64(C.godin_div(C.double(a), C.double(b)))
	return r, C.GoString(C.godin_last_error())
}

// LastError returns the current error message from Odin.
func LastError() string { return C.GoString(C.godin_last_error()) }

// ApplySquares makes Odin call the Go callback go_square for each element and
// returns the sum (1+4+9=14 for {1,2,3}).
func ApplySquares(xs []float64) float64 {
	if len(xs) == 0 {
		return 0
	}
	cin := make([]C.double, len(xs))
	for i, x := range xs {
		cin[i] = C.double(x)
	}
	return float64(C.godin_apply(&cin[0], C.int(len(cin)), C.go_square_ptr()))
}

// Dup duplicates s in Odin-allocated memory and frees it, returning a Go string.
func Dup(s string) string {
	cs := C.CString(s)
	defer C.free(unsafe.Pointer(cs))
	dup := C.godin_dup(cs)
	if dup == nil {
		return ""
	}
	defer C.godin_free(unsafe.Pointer(dup))
	return C.GoString(dup)
}
