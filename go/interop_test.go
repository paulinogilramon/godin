package main

import "testing"

func TestRun(t *testing.T) {
	run()
	t.Log("run() completed without panic")
}

func TestInteropScalars(t *testing.T) {
	if got := Add(2, 3); got != 5 {
		t.Fatalf("Add = %d, want 5", got)
	}
	if got := Version(); got != 1 {
		t.Fatalf("Version = %d, want 1", got)
	}
	if got := StrLen("hello"); got != 5 {
		t.Fatalf("StrLen = %d, want 5", got)
	}
}

func TestInteropSum(t *testing.T) {
	if got := Sum([]float64{1, 2, 3, 4}); got != 10 {
		t.Fatalf("Sum = %g, want 10", got)
	}
	if got := Sum(nil); got != 0 {
		t.Fatalf("Sum(nil) = %g, want 0", got)
	}
}

func TestInteropVec3(t *testing.T) {
	if got := Scale(Vec3{X: 1, Y: 2, Z: 3}, 2); got != (Vec3{X: 2, Y: 4, Z: 6}) {
		t.Fatalf("Scale = %+v, want {2 4 6}", got)
	}
	if got := MakeVec3(4, 5, 6); got != (Vec3{X: 4, Y: 5, Z: 6}) {
		t.Fatalf("MakeVec3 = %+v, want {4 5 6}", got)
	}
}

func TestInteropCallback(t *testing.T) {
	if got := ApplySquares([]float64{1, 2, 3}); got != 14 {
		t.Fatalf("ApplySquares = %g, want 14", got)
	}
}

func TestInteropError(t *testing.T) {
	if _, err := Div(1, 0); err != "division by zero" {
		t.Fatalf("Div(1,0) err = %q, want %q", err, "division by zero")
	}
	if r, err := Div(6, 2); r != 3 || err != "" {
		t.Fatalf("Div(6,2) = %g, %q; want 3, \"\"", r, err)
	}
}

func TestInteropMemory(t *testing.T) {
	if got := Dup("hello"); got != "hello" {
		t.Fatalf("Dup = %q, want %q", got, "hello")
	}
}
