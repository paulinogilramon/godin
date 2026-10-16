package main

import "fmt"

// run exercises the Odin library across the C ABI and prints a report.
func run() {
	fmt.Println("Go + Odin via C ABI")
	fmt.Printf("godin_version() = %d\n", Version())
	fmt.Printf("godin_add(2, 3) = %d\n", Add(2, 3))
	fmt.Printf("godin_str_len(%q) = %d\n", "hello from Go", StrLen("hello from Go"))
	fmt.Printf("godin_sum({1,2,3,4}) = %g\n", Sum([]float64{1, 2, 3, 4}))

	v := Scale(Vec3{X: 1, Y: 2, Z: 3}, 2)
	fmt.Printf("godin_scale({1,2,3}, 2) = {%g, %g, %g}\n", v.X, v.Y, v.Z)

	m := MakeVec3(4, 5, 6)
	fmt.Printf("godin_make_vec3(4,5,6) = {%g, %g, %g}\n", m.X, m.Y, m.Z)

	r, err := Div(6, 2)
	fmt.Printf("godin_div(6, 2) = %g  (last_error=%q)\n", r, err)
	r, err = Div(1, 0)
	fmt.Printf("godin_div(1, 0) = %g  (last_error=%q)\n", r, err)

	fmt.Printf("godin_apply({1,2,3}, go_square) = %g\n", ApplySquares([]float64{1, 2, 3}))
	fmt.Printf("godin_dup(%q) = %q (freed via godin_free)\n", "hello from Go", Dup("hello from Go"))
}

func main() {
	run()
}
