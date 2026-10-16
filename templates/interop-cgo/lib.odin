package godin

import "core:c"

foreign import "C"

@(export)
godin_version :: proc() -> c.int {
	return 1
}

@(export)
godin_add :: proc(a: c.int, b: c.int) -> c.int {
	return a + b
}
