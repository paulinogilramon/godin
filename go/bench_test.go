package main

import "testing"

func BenchmarkAdd(b *testing.B) {
	for i := 0; i < b.N; i++ {
		if Add(i, 1) != i+1 {
			b.Fatal("unexpected Add result")
		}
	}
}

func BenchmarkSum(b *testing.B) {
	xs := []float64{1, 2, 3, 4, 5, 6, 7, 8}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if Sum(xs) != 36 {
			b.Fatal("unexpected Sum result")
		}
	}
}

func BenchmarkDup(b *testing.B) {
	for i := 0; i < b.N; i++ {
		if Dup("hello from Go") != "hello from Go" {
			b.Fatal("unexpected Dup result")
		}
	}
}
