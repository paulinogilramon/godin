package main

/*
#cgo CFLAGS: -I../shared
#cgo windows LDFLAGS: -L../build -lgodin
#cgo linux LDFLAGS: -L../build -lgodin -ldl -lm
#include <stdlib.h>
#include "godin.h"
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
}
