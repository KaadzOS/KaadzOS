#!/usr/bin/env python3
"""Render the KaadzOS raster artwork from the "Night" palette.

Usage: render-artwork.py <wallpaper-dir> <calamares-brand-dir> <9 colours>

The generator is deliberately dependency-free (standard library only): the ISO
and the CI runners have no ImageMagick, Inkscape or font tooling, yet swaybg
needs a PNG wallpaper and Calamares wants PNG branding assets. Everything is
computed from the same palette values as theme/generate.sh, so re-running the
theme regenerates matching artwork.
"""

import math
import struct
import sys
import zlib

wall_dir, cal_brand = sys.argv[1], sys.argv[2]
BG, BG_ALT, SURFACE, BORDER, FG, FG_ALT, FG_MUTED, ACCENT, ACCENT_ALT = [
    tuple(int(h.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4))
    for h in sys.argv[3:12]
]

# --------------------------------------------------------------------- helpers
# 5x7 bitmap font, used for the small technical captions. Each glyph is seven
# rows of five cells separated by '/'; '#' is ink.
FONT_SRC = {
    'A': '.###./#...#/#...#/#####/#...#/#...#/#...#',
    'B': '####./#...#/#...#/####./#...#/#...#/####.',
    'C': '.####/#..../#..../#..../#..../#..../.####',
    'D': '####./#...#/#...#/#...#/#...#/#...#/####.',
    'E': '#####/#..../#..../####./#..../#..../#####',
    'F': '#####/#..../#..../####./#..../#..../#....',
    'G': '.###./#...#/#..../#.###/#...#/#...#/.###.',
    'H': '#...#/#...#/#...#/#####/#...#/#...#/#...#',
    'I': '#####/..#../..#../..#../..#../..#../#####',
    'J': '..###/...#./...#./...#./...#./#..#./.##..',
    'K': '#...#/#..#./#.#../##.../#.#../#..#./#...#',
    'L': '#..../#..../#..../#..../#..../#..../#####',
    'M': '#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#',
    'N': '#...#/##..#/#.#.#/#..##/#...#/#...#/#...#',
    'O': '.###./#...#/#...#/#...#/#...#/#...#/.###.',
    'P': '####./#...#/#...#/####./#..../#..../#....',
    'Q': '.###./#...#/#...#/#...#/#.#.#/#..#./.##.#',
    'R': '####./#...#/#...#/####./#.#../#..#./#...#',
    'S': '.####/#..../#..../.###./....#/....#/####.',
    'T': '#####/..#../..#../..#../..#../..#../..#..',
    'U': '#...#/#...#/#...#/#...#/#...#/#...#/.###.',
    'V': '#...#/#...#/#...#/#...#/#...#/.#.#./..#..',
    'W': '#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#',
    'X': '#...#/#...#/.#.#./..#../.#.#./#...#/#...#',
    'Y': '#...#/#...#/.#.#./..#../..#../..#../..#..',
    'Z': '#####/....#/...#./..#../.#.../#..../#####',
    '0': '.###./#...#/#..##/#.#.#/##..#/#...#/.###.',
    '1': '..#../.##../..#../..#../..#../..#../.###.',
    '2': '.###./#...#/....#/...#./..#../.#.../#####',
    '3': '#####/...#./..#../...#./....#/#...#/.###.',
    '4': '...#./..##./.#.#./#..#./#####/...#./...#.',
    '5': '#####/#..../####./....#/....#/#...#/.###.',
    '6': '..##./.#.../#..../####./#...#/#...#/.###.',
    '7': '#####/....#/...#./..#../.#.../.#.../.#...',
    '8': '.###./#...#/#...#/.###./#...#/#...#/.###.',
    '9': '.###./#...#/#...#/.####/....#/...#./.##..',
    '.': '...../...../...../...../...../.##../.##..',
    '-': '...../...../...../#####/...../...../.....',
    '·': '...../...../...../.##../.##../...../.....',
}
FONT = {key: value.split('/') for key, value in FONT_SRC.items()}


def write_png(path, canvas):
    w, h, ch = canvas.w, canvas.h, canvas.ch
    stride = w * ch
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += canvas.buf[y * stride:(y + 1) * stride]

    def chunk(tag, data):
        body = tag + data
        return (struct.pack('>I', len(data)) + body
                + struct.pack('>I', zlib.crc32(body) & 0xffffffff))

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6 if ch == 4 else 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as handle:
        handle.write(png)
    print('wrote', path)


class Canvas:
    def __init__(self, w, h, ch=3, bg=None):
        self.w, self.h, self.ch = w, h, ch
        self.buf = bytearray(w * h * ch)
        if bg is not None:
            row = bytes(bg) * w
            for y in range(h):
                self.buf[y * w * ch:(y + 1) * w * ch] = row

    def put(self, x, y, color, alpha):
        """Source-over one pixel; alpha is 0..1 and x/y are pixel indices."""
        if alpha <= 0.0 or x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        if alpha > 1.0:
            alpha = 1.0
        i = (y * self.w + x) * self.ch
        buf = self.buf
        if self.ch == 3:
            buf[i] = int(buf[i] + (color[0] - buf[i]) * alpha)
            buf[i + 1] = int(buf[i + 1] + (color[1] - buf[i + 1]) * alpha)
            buf[i + 2] = int(buf[i + 2] + (color[2] - buf[i + 2]) * alpha)
        else:
            dst_a = buf[i + 3] / 255.0
            out_a = alpha + dst_a * (1.0 - alpha)
            if out_a <= 0.0:
                return
            for k in range(3):
                buf[i + k] = int((color[k] * alpha + buf[i + k] * dst_a * (1.0 - alpha)) / out_a)
            buf[i + 3] = int(out_a * 255)


def vertical_gradient(canvas, top, bottom):
    for y in range(canvas.h):
        t = y / (canvas.h - 1)
        row = bytes(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3))
        start = y * canvas.w * canvas.ch
        canvas.buf[start:start + canvas.w * canvas.ch] = row * canvas.w


def glow(canvas, cx, cy, radius, color, strength):
    buf, w, ch = canvas.buf, canvas.w, canvas.ch
    for y in range(canvas.h):
        dy = y + 0.5 - cy
        row = y * w * ch
        for x in range(w):
            dx = x + 0.5 - cx
            d = math.sqrt(dx * dx + dy * dy)
            if d >= radius:
                continue
            t = 1.0 - d / radius
            alpha = strength * t * t * (3.0 - 2.0 * t)
            i = row + x * ch
            buf[i] = int(buf[i] + (color[0] - buf[i]) * alpha)
            buf[i + 1] = int(buf[i + 1] + (color[1] - buf[i + 1]) * alpha)
            buf[i + 2] = int(buf[i + 2] + (color[2] - buf[i + 2]) * alpha)


def segment(canvas, start, end, color, width, alpha=1.0):
    """Anti-aliased round-capped line."""
    ax, ay = start
    bx, by = end
    pad = width + 2.0
    x0 = max(0, int(min(ax, bx) - pad))
    x1 = min(canvas.w, int(max(ax, bx) + pad) + 1)
    y0 = max(0, int(min(ay, by) - pad))
    y1 = min(canvas.h, int(max(ay, by) + pad) + 1)
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy or 1.0
    half = width / 2.0
    for y in range(y0, y1):
        py = y + 0.5
        for x in range(x0, x1):
            px = x + 0.5
            t = ((px - ax) * dx + (py - ay) * dy) / length
            if t < 0.0:
                t = 0.0
            elif t > 1.0:
                t = 1.0
            ex = px - (ax + dx * t)
            ey = py - (ay + dy * t)
            coverage = half + 0.5 - math.sqrt(ex * ex + ey * ey)
            if coverage <= 0.0:
                continue
            canvas.put(x, y, color, alpha * (1.0 if coverage >= 1.0 else coverage))


def polyline(canvas, points, color, width, alpha=1.0):
    for start, end in zip(points, points[1:]):
        segment(canvas, start, end, color, width, alpha)


def disc(canvas, cx, cy, radius, color, alpha):
    x0 = max(0, int(cx - radius - 1))
    x1 = min(canvas.w, int(cx + radius + 1) + 1)
    y0 = max(0, int(cy - radius - 1))
    y1 = min(canvas.h, int(cy + radius + 1) + 1)
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.sqrt((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2)
            coverage = radius + 0.5 - d
            if coverage <= 0.0:
                continue
            canvas.put(x, y, color, alpha * (1.0 if coverage >= 1.0 else coverage))


def text_width(text, cell, tracking=1):
    return (len(text) * (5 + tracking) - tracking) * cell


def draw_text(canvas, text, left, top, cell, color, alpha=1.0, tracking=1):
    """Bitmap text with exact area coverage, so it stays crisp at any scale."""
    stride = 5 + tracking
    x0, y0 = left, top
    x1 = x0 + text_width(text, cell, tracking)
    y1 = y0 + 7 * cell
    px0 = max(0, int(math.floor(x0)))
    px1 = min(canvas.w, int(math.ceil(x1)) + 1)
    py0 = max(0, int(math.floor(y0)))
    py1 = min(canvas.h, int(math.ceil(y1)) + 1)
    for y in range(py0, py1):
        v0 = (y + 0.5 - y0) / cell
        v1 = (y + 1.5 - y0) / cell
        gy_first = int(math.floor(v0))
        gy_last = int(math.floor(v1 - 1e-9))
        for x in range(px0, px1):
            u0 = (x + 0.5 - x0) / cell
            u1 = (x + 1.5 - x0) / cell
            gx_first = int(math.floor(u0))
            gx_last = int(math.floor(u1 - 1e-9))
            coverage = 0.0
            for gy in range(gy_first, gy_last + 1):
                overlap_y = min(v1, gy + 1.0) - max(v0, gy)
                if overlap_y <= 0.0:
                    continue
                for gx in range(gx_first, gx_last + 1):
                    index = gx // stride
                    if index < 0 or index >= len(text):
                        continue
                    column = gx - index * stride
                    if column >= 5 or gy < 0 or gy > 6:
                        continue
                    glyph = FONT.get(text[index])
                    if glyph and glyph[gy][column] == '#':
                        overlap_x = min(u1, gx + 1.0) - max(u0, gx)
                        if overlap_x > 0.0:
                            coverage += overlap_x * overlap_y
            if coverage > 0.0:
                coverage *= cell * cell
                canvas.put(x, y, color, alpha * (1.0 if coverage >= 1.0 else coverage))


def arc_points(cx, cy, rx, ry, start, end, steps=64):
    return [(cx + rx * math.cos(start + (end - start) * i / steps),
             cy + ry * math.sin(start + (end - start) * i / steps))
            for i in range(steps + 1)]


def smooth(points, samples=8):
    """Catmull-Rom through the control points (no visible corners)."""
    padded = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1], padded[i], padded[i + 1], padded[i + 2]
        for step in range(samples):
            t = step / float(samples)
            t2, t3 = t * t, t * t * t
            out.append((
                0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3),
                0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)))
    out.append(padded[-2])
    return out


# Monoline geometric glyphs on a 0..1 box (y grows downwards). Drawing the
# wordmark avoids depending on a font being installed where the artwork runs.
GLYPHS = {
    'A': [[(0.02, 1.0), (0.50, 0.0), (0.98, 1.0)], [(0.20, 0.68), (0.80, 0.68)]],
    'D': [[(0.10, 1.0), (0.10, 0.0), (0.40, 0.0)]
          + arc_points(0.40, 0.5, 0.52, 0.5, -math.pi / 2, math.pi / 2, 48)
          + [(0.10, 1.0)]],
    'K': [[(0.10, 0.0), (0.10, 1.0)],
          [(0.10, 0.50), (0.92, 0.02)],
          [(0.10, 0.50), (0.92, 0.98)]],
    'O': [arc_points(0.5, 0.5, 0.48, 0.5, 0.0, 2 * math.pi, 72)],
    'S': [smooth([(0.88, 0.16), (0.66, 0.03), (0.33, 0.03), (0.14, 0.20),
                  (0.20, 0.40), (0.50, 0.48), (0.80, 0.56), (0.86, 0.74),
                  (0.70, 0.94), (0.33, 0.97), (0.08, 0.85)], 8)],
    'Z': [[(0.05, 0.02), (0.95, 0.02), (0.05, 0.98), (0.95, 0.98)]],
}
GLYPH_ADVANCE = 0.95   # in units of the cap height
GLYPH_WIDTH = 0.82     # 0..1 glyph box width, in units of the cap height


def wordmark_width(text, height):
    return len(text) * GLYPH_ADVANCE * height - (GLYPH_ADVANCE - GLYPH_WIDTH) * height


def draw_wordmark(canvas, text, left, top, height, color, alpha=1.0):
    stroke = height * 0.105
    for index, character in enumerate(text):
        glyph = GLYPHS.get(character)
        if not glyph:
            continue
        origin_x = left + index * GLYPH_ADVANCE * height
        for path in glyph:
            points = [(origin_x + x * GLYPH_WIDTH * height, top + y * height)
                      for x, y in path]
            for start, end in zip(points, points[1:]):
                segment(canvas, start, end, color, stroke, alpha)


def mask_strokes(w, h, paths, width):
    """Coverage for a group of strokes, so overlapping joins do not double up."""
    mask = [0.0] * (w * h)
    half = width / 2.0
    for points in paths:
        for start, end in zip(points, points[1:]):
            ax, ay = start
            bx, by = end
            pad = width + 2.0
            x0 = max(0, int(min(ax, bx) - pad))
            x1 = min(w, int(max(ax, bx) + pad) + 1)
            y0 = max(0, int(min(ay, by) - pad))
            y1 = min(h, int(max(ay, by) + pad) + 1)
            dx, dy = bx - ax, by - ay
            length = dx * dx + dy * dy or 1.0
            for y in range(y0, y1):
                py = y + 0.5
                row = y * w
                for x in range(x0, x1):
                    px = x + 0.5
                    t = ((px - ax) * dx + (py - ay) * dy) / length
                    if t < 0.0:
                        t = 0.0
                    elif t > 1.0:
                        t = 1.0
                    ex = px - (ax + dx * t)
                    ey = py - (ay + dy * t)
                    coverage = half + 0.5 - math.sqrt(ex * ex + ey * ey)
                    if coverage > 0.0:
                        coverage = 1.0 if coverage >= 1.0 else coverage
                        index = row + x
                        if coverage > mask[index]:
                            mask[index] = coverage
    return mask


def composite_mask(canvas, mask, color, alpha):
    for y in range(canvas.h):
        for x in range(canvas.w):
            coverage = mask[y * canvas.w + x]
            if coverage > 0.0:
                canvas.put(x, y, color, alpha * coverage)


def mix(color_a, color_b, amount):
    return tuple(int(color_a[i] + (color_b[i] - color_a[i]) * amount) for i in range(3))


def fade_edges(canvas, color, margin):
    """Blend the border into the page background so the PNG has no hard frame."""
    w, h = canvas.w, canvas.h
    for y in range(h):
        edge_y = min(y, h - 1 - y)
        if edge_y >= margin:
            continue
        for x in range(w):
            d = min(x, w - 1 - x, edge_y)
            if d >= margin:
                continue
            t = 1.0 - d / margin
            canvas.put(x, y, color, t * t * (3.0 - 2.0 * t) * 0.85)


def rounded_rect_sd(px, py, x0, y0, x1, y1, radius):
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    qx = abs(px - cx) - ((x1 - x0) / 2.0 - radius)
    qy = abs(py - cy) - ((y1 - y0) / 2.0 - radius)
    outside = math.sqrt(max(qx, 0.0) ** 2 + max(qy, 0.0) ** 2)
    return outside + min(max(qx, qy), 0.0) - radius


# ------------------------------------------------------------------- wallpaper
# Matches wallpaper.svg: vertical base, cyan bloom toward the upper right, two
# contour lines and a single waypoint dot.
wall = Canvas(1920, 1080, 3, BG)
vertical_gradient(wall, BG_ALT, BG)
glow(wall, 1920 * 0.72, 1080 * 0.28, 1920 * 0.9, ACCENT, 0.30)
polyline(wall, [(0, 760), (520, 560), (1040, 700), (1560, 480), (1920, 600)],
         BORDER, 2.0, 0.35)
polyline(wall, [(0, 860), (520, 660), (1040, 800), (1560, 580), (1920, 700)],
         BORDER, 1.0, 0.20)
disc(wall, 1382, 302, 46, ACCENT, 0.12)
disc(wall, 1382, 302, 4, ACCENT, 0.90)
write_png(wall_dir + '/wallpaper.png', wall)

# ------------------------------------------------------------------------ logo
# A rounded tile with the accent "K" mark; shown at 80x80 in the Calamares
# sidebar and as the window icon, so it has to read small and on dark surfaces.
S = 512
logo = Canvas(S, S, 4)
margin, radius = S * 0.075, S * 0.22
border = S * 0.012
stem = S * 0.09
stem_x = S * 0.355
arm_top = (S * 0.685, S * 0.295)
arm_bottom = (S * 0.685, S * 0.705)
for y in range(S):
    for x in range(S):
        px, py = x + 0.5, y + 0.5
        sd = rounded_rect_sd(px, py, margin, margin, S - margin, S - margin, radius)
        if sd > 0.0:
            halo = max(0.0, 1.0 - sd / (S * 0.10))
            if halo > 0.0:
                logo.put(x, y, ACCENT, 0.16 * halo * halo)
            continue
        logo.put(x, y, SURFACE, 1.0)
        ring = abs(sd + border / 2.0)
        if ring < border / 2.0 + 0.5:
            logo.put(x, y, ACCENT, 0.85 * min(1.0, border / 2.0 + 0.5 - ring))
stem_path = [[(stem_x, S * 0.27), (stem_x, S * 0.73)]]
arm_paths = [[(stem_x, S * 0.50), arm_top], [(stem_x, S * 0.50), arm_bottom]]
composite_mask(logo, mask_strokes(S, S, stem_path, stem), ACCENT, 1.0)
composite_mask(logo, mask_strokes(S, S, arm_paths, stem), FG, 1.0)
write_png(cal_brand + '/logo.png', logo)

# --------------------------------------------------------------- welcome image
welcome = Canvas(1600, 900, 3, BG)
vertical_gradient(welcome, BG_ALT, BG)
glow(welcome, 800, 330, 1050, ACCENT, 0.16)
polyline(welcome, [(0, 634), (433, 467), (867, 583), (1300, 400), (1600, 500)],
         BORDER, 2.0, 0.30)
polyline(welcome, [(0, 717), (433, 550), (867, 667), (1300, 483), (1600, 583)],
         BORDER, 1.0, 0.16)

word = 'KAADZOS'
word_height = 196
word_width = wordmark_width(word, word_height)
word_left = (1600 - word_width) / 2.0
word_top = 900 * 0.42 - word_height / 2.0
advance = GLYPH_ADVANCE * word_height
draw_wordmark(welcome, word[:5], word_left, word_top, word_height, FG)
draw_wordmark(welcome, word[5:], word_left + 5 * advance, word_top, word_height, ACCENT)

rule_y = word_top + word_height + 62
rule_w = word_width * 0.30
for alpha, height in ((0.18, 12), (0.45, 6), (1.0, 3)):
    x0 = int(800 - rule_w / 2.0)
    x1 = int(800 + rule_w / 2.0)
    for y in range(int(rule_y) - height // 2, int(rule_y) + (height + 1) // 2):
        for x in range(x0, x1):
            welcome.put(x, y, ACCENT, alpha)

tag = 'DEBIAN TRIXIE · SWAY · WAYLAND'
tag_cell = 3.6
tag_left = (1600 - text_width(tag, tag_cell, 2)) / 2.0
draw_text(welcome, tag, tag_left, rule_y + 58, tag_cell, FG_ALT, alpha=0.92, tracking=2)
fade_edges(welcome, BG, 120)
write_png(cal_brand + '/welcome.png', welcome)

# --------------------------------------------------------------- slide artwork
# Deliberately quiet: the slideshow paints its text on top at 35% opacity.
slide = Canvas(1600, 900, 3, BG)
vertical_gradient(slide, BG, BG_ALT)
glow(slide, 1300, 210, 780, ACCENT_ALT, 0.13)
polyline(slide, [(0, 700), (430, 520), (860, 640), (1290, 470), (1600, 560)],
         BORDER, 2.0, 0.16)

mark_x, mark_y, mark_size = 1130, 460, 520
mark_stem = mark_size * 0.09
mark_left = mark_x - mark_size * 0.18
mark_stem_path = [[(mark_left, mark_y - mark_size * 0.23),
                   (mark_left, mark_y + mark_size * 0.23)]]
mark_arm_paths = [
    [(mark_left, mark_y), (mark_x + mark_size * 0.24, mark_y - mark_size * 0.20)],
    [(mark_left, mark_y), (mark_x + mark_size * 0.24, mark_y + mark_size * 0.20)],
]
composite_mask(slide, mask_strokes(1600, 900, mark_stem_path + mark_arm_paths, mark_stem),
               ACCENT, 0.28)
disc(slide, 1352, 152, 4, ACCENT, 0.75)
disc(slide, 1352, 152, 60, ACCENT, 0.08)

draw_wordmark(slide, 'KAADZOS', 92, 742, 26, mix(FG_ALT, BG, 0.35))
segment(slide, (92, 730), (92 + 46, 730), ACCENT, 3.0, 0.9)
fade_edges(slide, BG, 100)
write_png(cal_brand + '/slide.png', slide)
