package main

/*
#cgo CFLAGS: -I../shared
#cgo windows LDFLAGS: -L../build -lgodin
#cgo linux LDFLAGS: -L../build -lgodin -ldl -lm
#include "godin.h"
*/
import "C"
import "fmt"

// Minimal end-to-end check: Go -> cgo -> Odin shared library.
func main() {
	fmt.Println("Go + Odin via C ABI")
	fmt.Printf("godin_version() = %d\n", int(C.godin_version()))
	fmt.Printf("godin_add(2, 3) = %d\n", int(C.godin_add(2, 3)))
}
