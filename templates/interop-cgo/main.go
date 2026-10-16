package main

/*
#cgo CFLAGS: -I../shared
#cgo windows LDFLAGS: -L../build -lgodin
#cgo linux LDFLAGS: -L../build -lgodin -ldl -lm
#include "godin.h"
*/
import "C"
import "fmt"

func main() {
	fmt.Println("Go + Odin via C ABI")
}
