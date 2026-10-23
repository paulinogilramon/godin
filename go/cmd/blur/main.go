// Command blur is the real-world demo of the case study: Go handles CLI, image
// I/O and hashing; the hot loop runs either in pure Go or in Odin across cgo.
package main

import (
	"bytes"
	"crypto/sha256"
	"flag"
	"fmt"
	"image"
	"image/draw"
	_ "image/jpeg"
	"image/png"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"time"

	"github.com/pauli/godin/blur"
)

func main() {
	if err := run(os.Args[1:], os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "blur:", err)
		os.Exit(1)
	}
}

func run(args []string, out io.Writer) error {
	fs := flag.NewFlagSet("blur", flag.ContinueOnError)
	fs.SetOutput(out)

	in := fs.String("in", "", "input image (PNG/JPEG); empty = synthetic image")
	outPath := fs.String("out", "", "output PNG path; empty = do not write")
	opName := fs.String("op", "gauss", "kernel: box | gauss")
	impl := fs.String("impl", "odin", "implementation: go | odin | both")
	radius := fs.Int("radius", 8, "box blur radius in pixels (box only)")
	gen := fs.String("gen", "", "generate a synthetic PNG at this path and exit")
	gw := fs.Int("w", 1920, "generated image width")
	gh := fs.Int("h", 1080, "generated image height")
	seed := fs.Int64("seed", 1, "synthetic image seed")
	repeat := fs.Int("repeat", 1, "run the kernel N times (timing)")
	quiet := fs.Bool("quiet", false, "only print errors")

	if err := fs.Parse(args); err != nil {
		return err
	}
	if *repeat < 1 {
		return fmt.Errorf("repeat must be >= 1")
	}

	if *gen != "" {
		if *gw <= 0 || *gh <= 0 {
			return fmt.Errorf("invalid generated size %dx%d", *gw, *gh)
		}
		if err := writePNG(*gen, generate(*gw, *gh, *seed)); err != nil {
			return err
		}
		if !*quiet {
			_, _ = fmt.Fprintf(out, "generated %s (%dx%d, seed %d)\n", *gen, *gw, *gh, *seed)
		}
		return nil
	}

	op, err := blur.ParseOp(*opName)
	if err != nil {
		return err
	}
	if *impl != "go" && *impl != "odin" && *impl != "both" {
		return fmt.Errorf("unknown impl %q (want go, odin or both)", *impl)
	}

	var img *image.NRGBA
	if *in == "" {
		img = generate(*gw, *gh, *seed)
	} else {
		img, err = loadImage(*in)
		if err != nil {
			return err
		}
	}
	w, h := img.Rect.Dx(), img.Rect.Dy()
	n := w * h * 4
	if len(img.Pix) < n {
		return fmt.Errorf("decoded image has %d bytes, need %d", len(img.Pix), n)
	}
	src := img.Pix[:n]
	dst := make([]byte, n)
	tmp := make([]byte, n)

	impls := []string{*impl}
	if *impl == "both" {
		impls = []string{"go", "odin"}
	}

	var reference []byte
	for _, name := range impls {
		var best time.Duration
		start := time.Now()
		for i := 0; i < *repeat; i++ {
			t0 := time.Now()
			if err := blur.Apply(name, op, dst, src, tmp, w, h, *radius); err != nil {
				return err
			}
			if d := time.Since(t0); best == 0 || d < best {
				best = d
			}
		}
		elapsed := time.Since(start) / time.Duration(*repeat)
		sum := sha256.Sum256(dst)
		mp := float64(w*h) / 1e6
		if !*quiet {
			if op == blur.Box {
				_, _ = fmt.Fprintf(out, "impl=%-4s op=%-5s radius=%d size=%dx%d time=%9.3f ms best=%9.3f ms throughput=%8.1f MP/s sha256=%x\n",
					name, op, *radius, w, h, float64(elapsed.Microseconds())/1000,
					float64(best.Microseconds())/1000, mp/best.Seconds(), sum)
			} else {
				_, _ = fmt.Fprintf(out, "impl=%-4s op=%-5s size=%dx%d time=%9.3f ms best=%9.3f ms throughput=%8.1f MP/s sha256=%x\n",
					name, op, w, h, float64(elapsed.Microseconds())/1000,
					float64(best.Microseconds())/1000, mp/best.Seconds(), sum)
			}
		}
		if reference == nil {
			reference = append([]byte(nil), dst...)
			continue
		}
		if !bytes.Equal(reference, dst) {
			return fmt.Errorf("%s vs go: outputs differ", name)
		}
	}

	if *outPath != "" {
		img.Pix = dst
		if err := writePNG(*outPath, img); err != nil {
			return err
		}
		if !*quiet {
			_, _ = fmt.Fprintf(out, "wrote %s\n", *outPath)
		}
	}
	return nil
}

func loadImage(path string) (*image.NRGBA, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }()
	img, _, err := image.Decode(f)
	if err != nil {
		return nil, fmt.Errorf("decode %s: %w", path, err)
	}
	return toNRGBA(img), nil
}

func toNRGBA(img image.Image) *image.NRGBA {
	b := img.Bounds()
	dst := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Draw(dst, dst.Bounds(), img, b.Min, draw.Src)
	return dst
}

func writePNG(path string, img image.Image) error {
	if dir := filepath.Dir(path); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	if err := png.Encode(f, img); err != nil {
		_ = f.Close()
		return err
	}
	return f.Close()
}

// generate builds a deterministic image with gradients, hard-edged shapes and
// light noise: blurs are visible to the eye and reproducible across machines.
func generate(w, h int, seed int64) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	rng := rand.New(rand.NewSource(seed))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			base := uint8(0)
			if w > 1 {
				base = uint8(x * 255 / (w - 1))
			}
			vert := uint8(0)
			if h > 1 {
				vert = uint8(y * 255 / (h - 1))
			}
			r := base
			g := vert
			b := uint8(128)

			// A few hard-edged shapes so the blur has something to smooth.
			cx, cy := w/3, h/2
			dx, dy := x-cx, y-cy
			if dx*dx+dy*dy < (min(w, h)/5)*(min(w, h)/5) {
				r, g, b = 255, 64, 32
			}
			if x > w*2/3 && y < h/3 {
				r, g, b = 32, 200, 255
			}
			if (x/16+y/16)%2 == 0 && x < w/3 && y > h*2/3 {
				r, g, b = 240, 240, 240
			}

			n := uint8(rng.Intn(25))
			i := y*img.Stride + x*4
			img.Pix[i+0] = r + n
			img.Pix[i+1] = g + n
			img.Pix[i+2] = b + n
			img.Pix[i+3] = 255
		}
	}
	return img
}
