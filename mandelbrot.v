import math
import readline
import term
import os

struct Pixel {
	r int
	g int
	b int
	c byte
}
struct Mandel {
	xmin f64
	xmax f64
	ymin f64
	ymax f64
	iterations int
	width int
	height int
}

fn mandel_iter(cx f64, cy f64, maxIter int) f64 {
	mut x := 0.0
	mut y := 0.0
	mut xx := 0.0
	mut yy := 0.0
	mut xy := 0.0

	mut i := maxIter
	for i-- != 0 && xx + yy <= 4 {
		xy = x * y
		xx = x * x
		yy = y * y
		x = xx - yy + cx
		y = xy + xy + cy
	}
	return maxIter - i
}

fn (m Mandel)get_pixel(ix int, iy int) Pixel {
	x := m.xmin + (m.xmax - m.xmin) * ix / (m.width - 1)
	y := m.ymin + (m.ymax - m.ymin) * iy / (m.height - 1)
	i := mandel_iter(x, y, m.iterations)

	if i > m.iterations {
		return Pixel {0, 0, 0, `#`}
	} else {
		c := 3 * math.log(i) / math.log(f64(m.iterations) - 1.0)
		if c < 1 {
			return Pixel {int(255 * c), 0, 0, `+`}
		} else if c < 2 {
			return Pixel {255, int(255 * (c - 1)), 0, `.`}
		} else {
			return Pixel {255, 255, int(255 * (c - 2)), ` `}
		}
	}
}

fn mandelbrot(xmin f64, xmax f64, ymin f64, ymax f64, iterations int, colored bool) {
	width, height := term.get_terminal_size()
	m := Mandel{ xmin xmax ymin ymax iterations width height }

	if !colored {
		for iy in 0..height {
			for ix in 0..width {
				pix := m.get_pixel(ix, iy)
				print(pix.c)	
			}
			print('\n')
		}
	} else {
		for iy := 0; iy < height * 2; iy += 2 {
			for ix in 0..width {
				pix1 := m.get_pixel(ix, (iy / 2))
				pix2 := m.get_pixel(ix, (iy / 2) + 1)
				print(term.bg_rgb(pix2.r, pix2.g, pix2.b, term.rgb(pix1.r, pix1.g, pix1.b, '▀')))
			}
			print('\n')
		}
	}
}

fn main() {
	colored := os.args.len == 2 && os.args[1] == '-color'
	mut pointx := 0.0
	mut pointy := 0.0
	mut zoom := 1.0	
	mut iter := 1000.0
	width, height := term.get_terminal_size()
	ratio := f64(width) / f64(height)

	println(ratio)
	for {
		mut r := readline.Readline{}
		r.enable_raw_mode_nosig()

		mandelbrot(
			pointx - zoom * ratio / 2,
			pointx + zoom * ratio / 2,
			pointy - zoom,
			pointy + zoom,
			int(iter),
			colored
		)
		input := r.read_char()
		// input := os.input('> ')
		match byte(input) {
			`d` {
				pointx += zoom
			}
			`a` {
				pointx -= zoom
			}
			`w` {
				pointy -= zoom
			}
			`s` {
				pointy += zoom
			}
			`q` {
				zoom *= 1.1
				iter *= 0.95
			}
			`e` {
				zoom *= 0.9
				iter *= 1.05
			}
			`i` {
				iter *= 1.5
			}
			`k` {
				iter *= 0.5
			}
			`\0`, 0x04 {
				break
			}
			else {}
		}
	}
}