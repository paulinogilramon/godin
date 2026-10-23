package main

import "testing"

func TestRun(t *testing.T) {
	run()
	t.Log("run() completed without panic")
}

// TestMainFunc exercises the real entrypoint (it only calls run()).
func TestMainFunc(_ *testing.T) {
	main()
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

func TestInteropAddEdges(t *testing.T) {
	for _, tc := range []struct{ a, b, want int }{
		{0, 0, 0},
		{-1, -2, -3},
		{7, -7, 0},
		{-5, 3, -2},
	} {
		if got := Add(tc.a, tc.b); got != tc.want {
			t.Errorf("Add(%d, %d) = %d, want %d", tc.a, tc.b, got, tc.want)
		}
	}
}

func TestInteropStrLenEdges(t *testing.T) {
	for _, tc := range []struct {
		s    string
		want int
	}{
		{"", 0},
		{"a", 1},
		{"héllo", 6}, // UTF-8 bytes, not runes
	} {
		if got := StrLen(tc.s); got != tc.want {
			t.Errorf("StrLen(%q) = %d, want %d", tc.s, got, tc.want)
		}
	}
}

func TestInteropSum(t *testing.T) {
	if got := Sum([]float64{1, 2, 3, 4}); got != 10 {
		t.Fatalf("Sum = %g, want 10", got)
	}
	if got := Sum(nil); got != 0 {
		t.Fatalf("Sum(nil) = %g, want 0", got)
	}
	if got := Sum([]float64{42}); got != 42 {
		t.Fatalf("Sum(single) = %g, want 42", got)
	}
	if got := Sum([]float64{-1, 1, -2}); got != -2 {
		t.Fatalf("Sum(negatives) = %g, want -2", got)
	}
}

func TestInteropVec3(t *testing.T) {
	if got := Scale(Vec3{X: 1, Y: 2, Z: 3}, 2); got != (Vec3{X: 2, Y: 4, Z: 6}) {
		t.Fatalf("Scale = %+v, want {2 4 6}", got)
	}
	if got := Scale(Vec3{X: 1, Y: -2, Z: 0}, 0); got != (Vec3{}) {
		t.Fatalf("Scale(*0) = %+v, want zero", got)
	}
	if got := MakeVec3(4, 5, 6); got != (Vec3{X: 4, Y: 5, Z: 6}) {
		t.Fatalf("MakeVec3 = %+v, want {4 5 6}", got)
	}
	if got := MakeVec3(-1, 0, 2.5); got != (Vec3{X: -1, Y: 0, Z: 2.5}) {
		t.Fatalf("MakeVec3(neg) = %+v, want {-1 0 2.5}", got)
	}
}

func TestInteropCallback(t *testing.T) {
	if got := ApplySquares([]float64{1, 2, 3}); got != 14 {
		t.Fatalf("ApplySquares = %g, want 14", got)
	}
	if got := ApplySquares(nil); got != 0 {
		t.Fatalf("ApplySquares(nil) = %g, want 0", got)
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

func TestLastError(t *testing.T) {
	if _, err := Div(6, 2); err != "" {
		t.Fatalf("Div(6,2) err = %q, want empty", err)
	}
	if got := LastError(); got != "" {
		t.Fatalf("LastError after success = %q, want empty", got)
	}
	if _, err := Div(1, 0); err != "division by zero" {
		t.Fatalf("Div(1,0) err = %q", err)
	}
	if got := LastError(); got != "division by zero" {
		t.Fatalf("LastError after failure = %q, want %q", got, "division by zero")
	}
}

func TestInteropMemory(t *testing.T) {
	for _, tc := range []struct{ s, want string }{
		{"hello", "hello"},
		{"", ""},
		{"añó", "añó"},
		{"with spaces and ünïcode", "with spaces and ünïcode"},
	} {
		if got := Dup(tc.s); got != tc.want {
			t.Errorf("Dup(%q) = %q, want %q", tc.s, got, tc.want)
		}
	}
}
