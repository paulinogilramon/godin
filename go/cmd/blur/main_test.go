package main

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestGenerateDeterministic(t *testing.T) {
	a := generate(64, 48, 7)
	b := generate(64, 48, 7)
	if !bytes.Equal(a.Pix, b.Pix) {
		t.Fatal("generate is not deterministic for the same seed")
	}
	c := generate(64, 48, 8)
	if bytes.Equal(a.Pix, c.Pix) {
		t.Fatal("different seeds produced identical images")
	}
}

func TestRunEndToEnd(t *testing.T) {
	dir := t.TempDir()
	in := filepath.Join(dir, "in.png")
	if err := run([]string{"-gen", in, "-w", "64", "-h", "48", "-seed", "3", "-quiet"}, io.Discard); err != nil {
		t.Fatalf("generate: %v", err)
	}
	if st, err := os.Stat(in); err != nil || st.Size() == 0 {
		t.Fatalf("generated file missing or empty: %v", err)
	}

	outGo := filepath.Join(dir, "go.png")
	outOdin := filepath.Join(dir, "odin.png")
	if err := run([]string{"-in", in, "-out", outGo, "-impl", "go", "-op", "box", "-radius", "3", "-quiet"}, io.Discard); err != nil {
		t.Fatalf("go: %v", err)
	}
	if err := run([]string{"-in", in, "-out", outOdin, "-impl", "odin", "-op", "box", "-radius", "3", "-quiet"}, io.Discard); err != nil {
		t.Fatalf("odin: %v", err)
	}

	goPNG, err := os.ReadFile(outGo)
	if err != nil {
		t.Fatal(err)
	}
	odinPNG, err := os.ReadFile(outOdin)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(goPNG, odinPNG) {
		t.Fatal("Go and Odin produced different PNGs")
	}

	// -impl both must succeed and write the same output.
	outBoth := filepath.Join(dir, "both.png")
	if err := run([]string{"-in", in, "-out", outBoth, "-impl", "both", "-op", "gauss", "-quiet"}, io.Discard); err != nil {
		t.Fatalf("both: %v", err)
	}
	bothPNG, err := os.ReadFile(outBoth)
	if err != nil {
		t.Fatal(err)
	}
	if len(bothPNG) == 0 {
		t.Fatal("empty output from -impl both")
	}
}

func TestRunErrors(t *testing.T) {
	cases := [][]string{
		{"-op", "nope", "-quiet"},
		{"-impl", "rust", "-quiet"},
		{"-repeat", "0", "-quiet"},
		{"-in", filepath.Join(t.TempDir(), "missing.png"), "-quiet"},
		{"-gen", filepath.Join(t.TempDir(), "x.png"), "-w", "0", "-quiet"},
	}
	for _, args := range cases {
		if err := run(args, io.Discard); err == nil {
			t.Fatalf("run(%v) = nil, want error", args)
		}
	}
}
