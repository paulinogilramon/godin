package main

/*
#include "godin.h"
*/
import "C"

// go_square is exported to C and passed to Odin as a function pointer.
// Odin calls it back from godin_apply.
//
//export go_square
func go_square(x C.double) C.double {
	return x * x
}
