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
import (
	"fmt"
	"unsafe"
)

func main() {
	fmt.Println("Go + Odin via C ABI")
	fmt.Printf("godin_version() = %d\n", int(C.godin_version()))
	fmt.Printf("godin_add(2, 3) = %d\n", int(C.godin_add(2, 3)))

	msg := C.CString("hello from Go")
	defer C.free(unsafe.Pointer(msg))
	fmt.Printf("godin_str_len(%q) = %d\n", C.GoString(msg), int(C.godin_str_len(msg)))

	xs := []C.double{1, 2, 3, 4}
	fmt.Printf("godin_sum({1,2,3,4}) = %g\n", float64(C.godin_sum(&xs[0], C.int(len(xs)))))

	v := C.Vec3{x: 1, y: 2, z: 3}
	C.godin_scale(&v, C.double(2))
	fmt.Printf("godin_scale({1,2,3}, 2) = {%g, %g, %g}\n",
		float64(v.x), float64(v.y), float64(v.z))

	m := C.godin_make_vec3(4, 5, 6)
	fmt.Printf("godin_make_vec3(4,5,6) = {%g, %g, %g}\n",
		float64(m.x), float64(m.y), float64(m.z))

	// Error handling.
	fmt.Printf("godin_div(6, 2) = %g  (last_error=%q)\n",
		float64(C.godin_div(6, 2)), C.GoString(C.godin_last_error()))
	_ = C.godin_div(1, 0)
	fmt.Printf("godin_div(1, 0) = %g  (last_error=%q)\n",
		float64(C.godin_div(1, 0)), C.GoString(C.godin_last_error()))

	// Callback: Odin calls go_square for each element.
	sq := []C.double{1, 2, 3}
	fmt.Printf("godin_apply({1,2,3}, go_square) = %g\n",
		float64(C.godin_apply(&sq[0], C.int(len(sq)), C.go_square_ptr())))

	// Memory ownership: Odin-allocated string released with godin_free.
	dup := C.godin_dup(msg)
	fmt.Printf("godin_dup(%q) = %q (freed via godin_free)\n", C.GoString(msg), C.GoString(dup))
	C.godin_free(unsafe.Pointer(dup))
}
