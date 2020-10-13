import math
import readline
import term
import os
import runtime
import sync

const (
	keys = [`w`, `a`, `s`, `d`, `q`, `e`, `i`, `k`]
	// keys = [`z`, `q`, `s`, `d`, `a`, `e`, `i`, `k`]
)

struct Args {
mut:
	colored bool
	verbose bool
}
struct Pixel {
	r int
	g int
	b int
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
struct ValPos {
	c f64
	pos int
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

fn (m Mandel)get_pixel(ix int, iy int) f64 {
	x := m.xmin + (m.xmax - m.xmin) * ix / (m.width - 1)
	y := m.ymin + (m.ymax - m.ymin) * iy / (m.height - 1)
	i := mandel_iter(x, y, m.iterations)

	if i > m.iterations {
		return -1
	} else {
		c := 3 * math.log(i) / math.log(f64(m.iterations) - 1.0)
		return c
	}
}

fn work_processor(mut work sync.Channel, mut results sync.Channel, mut wg sync.WaitGroup, m Mandel) {
	for {
		mut coord := u64(0)
		if !work.pop(&coord) {
			break
		}
		y := int(coord >> 32)
		x := int(coord & 0xFFFFFFFF)
		val := m.get_pixel(x, y)
		valpos := ValPos{val, y * m.width + x}
		results.push(&valpos)
	}
	wg.done()
}

fn get_color(c f64) Pixel {
	if c == -1 {
		return Pixel {0, 0, 0}
	} else if c < 1 {
		return Pixel {int(255 * c), 0, 0}
	} else if c < 2 {
		return Pixel {255, int(255 * (c - 1)), 0}
	} else {
		return Pixel {255, 255, int(255 * (c - 2))}
	}
}

fn mandelbrot(xmin f64, xmax f64, ymin f64, ymax f64, iterations int, args Args) {
	width, height := term.get_terminal_size()
	mut max_height := if args.colored { height * 2 } else { height }
	m := Mandel{ xmin xmax ymin ymax iterations width max_height }

	vjobs := runtime.nr_jobs()
	mut work := sync.new_channel<u64>(max_height * width)
	mut results := sync.new_channel<ValPos>(max_height * width)
	mut wg := sync.new_waitgroup()

	for y in 0..max_height {
		for x in 0..width {
			val := u64((u64(y) << 32) + u64(x))
			unsafe {
				work.push(&val)
			}
		}
	}
	work.close()
	wg.add(vjobs)
	for _ in 0..vjobs {
		go work_processor(mut work, mut results, mut wg, m)
	}
	wg.wait()
	mut arr_c := []f64{len: max_height * width,  init: -1.0}
	for _ in 0..max_height {
		for _ in 0..width {
			mut valpos := ValPos{}
			results.pop(&valpos)
			arr_c[valpos.pos] = valpos.c
		}
	}
	if args.verbose {
		println('xmin: $xmin, xmax: $xmax, ymin: $ymin, ymax: $ymax, iterations: $iterations')
	}
	if !args.colored {
		for y in 0..max_height {
			for x in 0..width {
				c := arr_c[y * width + x]
				if c == -1 {
					print('#')
				} else if c < 1 {
					print('+')
				} else if c < 2 {
					print('.')
				} else {
					print(' ')
				}
			}
			print('\n')
		}
	} else {
		for y := 0; y < max_height; y += 2 {
			for x in 0..width {
				pix1 := get_color(arr_c[y * width + x])
				pix2 := get_color(arr_c[(y + 1) * width + x])
				print(term.bg_rgb(pix2.r, pix2.g, pix2.b, term.rgb(pix1.r, pix1.g, pix1.b, '▀')))
			}
			print('\n')
		}
	}
}

fn main() {
	mut args := Args{}
	for arg in os.args {
		match arg {
			'-color' { args.colored = true }
			'-verbose' { args.verbose = true }
			else {}
		}
	}
	mut pointx := 0.0
	mut pointy := 0.0
	mut zoom := 1.0	
	mut iter := 1000.0
	width, height := term.get_terminal_size()
	ratio := f64(width) / f64(height)


	for {
		mut r := readline.Readline{}
		r.enable_raw_mode_nosig()

		mandelbrot(
			pointx - zoom * ratio / 2,
			pointx + zoom * ratio / 2,
			pointy - zoom,
			pointy + zoom,
			int(iter),
			args
		)
		input := r.read_char()
		match byte(input) {
			keys[0] {
				pointy -= zoom
			}
			keys[1] {
				pointx -= zoom
			}
			keys[2] {
				pointy += zoom
			}
			keys[3] {
				pointx += zoom
			}
			keys[4] {
				zoom *= 1.5
				iter *= 0.80
			}
			keys[5] {
				zoom *= f64(2) / 3
				iter *= 1.25
			}
			keys[6] {
				iter *= 1.5
			}
			keys[7] {
				iter *= 0.5
			}
			`\0`, 0x04 {
				break
			}
			else {}
		}
	}
}