"""Small pixel-art renderer used to draw RUYA's companions.

Shapes are signed distance functions (negative inside) sampled once per pixel,
so every edge is a clean 1px staircase. Each part gets four-tone shading from
the light direction (top-left), a cast shadow from the parts in front of it,
and a selective outline. Faces and props are hand-placed pixel stamps.

This file is the editable source of the sprites in assets/pets/ (GPL-3.0).
"""
from __future__ import annotations

import numpy as np
from PIL import Image

SIZE = 64
_ys, _xs = np.mgrid[0:SIZE, 0:SIZE]
X = _xs + 0.5
Y = _ys + 0.5

# Light comes from the top left; "away" points to the shadow side.
AWAY = np.array([0.55, 0.835])
TONES = ['d2', 'd1', 'b', 'l1']


def hexc(h: str, a: int = 255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def ramp(o, d2, d1, b, l1, hi=None, ol=None):
    """Colour ramp from outline to highlight; ol is the outline on the lit side."""
    r = {'o': hexc(o), 'd2': hexc(d2), 'd1': hexc(d1), 'b': hexc(b), 'l1': hexc(l1)}
    r['hi'] = hexc(hi) if hi else r['l1']
    r['ol'] = hexc(ol) if ol else r['o']
    return r


# ---------------------------------------------------------------- shapes

def ellipse(cx, cy, rx, ry, rot=0.0):
    c, s = np.cos(np.radians(rot)), np.sin(np.radians(rot))

    def f(x, y):
        dx, dy = x - cx, y - cy
        u = (dx * c + dy * s) / rx
        v = (-dx * s + dy * c) / ry
        return (np.sqrt(u * u + v * v) - 1.0) * min(rx, ry)
    return f


def superellipse(cx, cy, rx, ry, n=2.5):
    """Rounded-square ellipse, the classic chibi head shape."""
    def f(x, y):
        u = np.abs(x - cx) / rx
        v = np.abs(y - cy) / ry
        k = (u ** n + v ** n) ** (1.0 / n)
        return (k - 1.0) * min(rx, ry)
    return f


def tube(points, r0, r1):
    """Tapered stroke through points, radius r0 at the start and r1 at the end."""
    segs = []
    n = len(points) - 1
    for i in range(n):
        (ax, ay), (bx, by) = points[i], points[i + 1]
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        segs.append((ax, ay, bx, by, ra, rb))

    def f(x, y):
        d = np.full(x.shape, 1e9)
        for ax, ay, bx, by, ra, rb in segs:
            ex, ey = bx - ax, by - ay
            t = np.clip(((x - ax) * ex + (y - ay) * ey) / (ex * ex + ey * ey), 0, 1)
            qx, qy = x - ax - ex * t, y - ay - ey * t
            d = np.minimum(d, np.sqrt(qx * qx + qy * qy) - (ra + (rb - ra) * t))
        return d
    return f


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def rrect(cx, cy, hw, hh, r=0.0):
    def f(x, y):
        qx = np.abs(x - cx) - (hw - r)
        qy = np.abs(y - cy) - (hh - r)
        out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
        return out + np.minimum(np.maximum(qx, qy), 0) - r
    return f


def poly(pts):
    pts = [np.array(p, dtype=float) for p in pts]

    def f(x, y):
        d = np.full(x.shape, 1e9)
        sign = np.ones(x.shape)
        n = len(pts)
        for i in range(n):
            a, b = pts[i], pts[i - 1]
            e = b - a
            wx, wy = x - a[0], y - a[1]
            t = np.clip((wx * e[0] + wy * e[1]) / (e @ e), 0, 1)
            bx, by = wx - e[0] * t, wy - e[1] * t
            d = np.minimum(d, bx * bx + by * by)
            c1 = y >= a[1]
            c2 = y < b[1]
            c3 = e[0] * wy > e[1] * wx
            flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
            sign = np.where(flip, -sign, sign)
        return sign * np.sqrt(d)
    return f


def union(*fs):
    return lambda x, y: np.minimum.reduce([f(x, y) for f in fs])


def inter(*fs):
    return lambda x, y: np.maximum.reduce([f(x, y) for f in fs])


def sub(a, b):
    return lambda x, y: np.maximum(a(x, y), -b(x, y))


def grow(f, d):
    return lambda x, y: f(x, y) - d


def move(f, dx, dy):
    return lambda x, y: f(x - dx, y - dy)


def half(y0=None, y1=None, x0=None, x1=None):
    """Half-plane clip: keeps y >= y0, y <= y1, x >= x0, x <= x1."""
    def f(x, y):
        d = np.full(x.shape, -1e9)
        if y0 is not None:
            d = np.maximum(d, y0 - y)
        if y1 is not None:
            d = np.maximum(d, y - y1)
        if x0 is not None:
            d = np.maximum(d, x0 - x)
        if x1 is not None:
            d = np.maximum(d, x - x1)
        return d
    return f


# ---------------------------------------------------------------- parts

class Part:
    def __init__(self, name, sdf, colors, z, group=None, line=True, outline=True,
                 shade=True, decal_of=None, cast=True, receive=True, R=6.0, flat=None,
                 bias=0.0):
        self.name = name
        self.sdf = sdf
        self.colors = colors
        self.z = z
        self.group = group or name
        self.line = line          # draw a line where it overlaps parts behind it
        self.outline = outline    # draw the outer silhouette line
        self.shade = shade
        self.decal_of = decal_of  # shade with another part's form (markings)
        self.cast = cast
        self.receive = receive
        self.R = R                # thickness used to build the height field
        self.bias = bias          # brighten (+) or darken (-) the whole part
        self.flat = flat          # force a single tone


class Sprite:
    def __init__(self):
        self.parts: list[Part] = []
        self.stamps: list[tuple] = []
        self.under: list[tuple] = []   # (sdf, rgba) drawn below everything, no outline

    def add(self, part: Part):
        self.parts.append(part)
        return part

    def stamp(self, x, y, rows, pal, on=None):
        """Hand-placed pixels; with `on`, only over pixels of those parts."""
        self.stamps.append((int(x), int(y), rows, pal, set(on) if on else None))

    def shadow(self, sdf, rgba):
        self.under.append((sdf, rgba))

    def render(self, dx=0, dy=0) -> Image.Image:
        parts = sorted(self.parts, key=lambda p: p.z)
        by_name = {p.name: p for p in parts}
        idmap = np.full((SIZE, SIZE), -1)
        px, py = X - dx, Y - dy
        sdfs = []
        for i, p in enumerate(parts):
            d = p.sdf(px, py)
            sdfs.append(d)
            idmap[d <= 0] = i
        img = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)

        for sdf, rgba in self.under:
            m = (sdf(px, py) <= 0) & (idmap < 0)
            img[m] = rgba

        zs = np.array([p.z for p in parts])
        groups = [p.group for p in parts]

        def shifted(a, sx, sy, fill=-1):
            out = np.full(a.shape, fill)
            h, w = a.shape
            ys0, ys1 = max(0, sy), min(h, h + sy)
            xs0, xs1 = max(0, sx), min(w, w + sx)
            out[ys0:ys1, xs0:xs1] = a[ys0 - sy:ys1 - sy, xs0 - sx:xs1 - sx]
            return out

        # neighbour id maps (value at pixel = id of the neighbour in that direction)
        nb = {
            'l': shifted(idmap, 1, 0), 'r': shifted(idmap, -1, 0),
            'u': shifted(idmap, 0, 1), 'd': shifted(idmap, 0, -1),
        }
        # pixel up-left by (1, 2): who sits between this pixel and the light
        caster = shifted(idmap, 1, 2)

        for i, p in enumerate(parts):
            m = idmap == i
            if not m.any():
                continue
            form = by_name[p.decal_of] if p.decal_of else p
            fs = form.sdf
            tone = np.full((SIZE, SIZE), 2)
            if p.flat is not None:
                tone[:] = TONES.index(p.flat)
            elif p.shade and form.shade:
                inten = lighting(fs, px, py, form.R) + p.bias + form.bias
                tone = np.select([inten > 0.93, inten > 0.66, inten > 0.4], [3, 2, 1], 0)
            if p.receive and p.flat is None:
                c = caster
                valid = c >= 0
                cz = np.where(valid, zs[np.clip(c, 0, None)], -1)
                cg = np.array([[groups[v] if v >= 0 else None for v in row] for row in c])
                casts = np.array([[parts[v].cast if v >= 0 else False for v in row] for row in c])
                shadowed = valid & (cz > p.z) & (cg != p.group) & casts
                tone = np.where(shadowed & m, np.maximum(tone - 1, 0), tone)
            tone = despeckle(tone, m)
            for t, key in enumerate(TONES):
                sel = m & (tone == t)
                img[sel] = p.colors[key]

            # outlines
            if p.outline:
                bg_any = np.zeros((SIZE, SIZE), bool)
                bg_dark = np.zeros((SIZE, SIZE), bool)
                for k, a in nb.items():
                    is_bg = a < 0
                    bg_any |= is_bg
                    if k in ('r', 'd'):
                        bg_dark |= is_bg
                img[m & bg_any & ~bg_dark] = p.colors['ol']
                img[m & bg_dark] = p.colors['o']
            if p.line:
                line = np.zeros((SIZE, SIZE), bool)
                for a in nb.values():
                    valid = a >= 0
                    az = np.where(valid, zs[np.clip(a, 0, None)], 99)
                    ag = np.array([[groups[v] if v >= 0 else None for v in row] for row in a])
                    line |= valid & (az < p.z) & (ag != p.group)
                img[m & line] = p.colors['o']

        names = [p.name for p in parts]
        for x, y, rows, pal, on in self.stamps:
            for j, row in enumerate(rows):
                for k, ch in enumerate(row):
                    if ch in ('.', ' '):
                        continue
                    xx, yy = x + k + dx, y + j + dy
                    if not (0 <= xx < SIZE and 0 <= yy < SIZE):
                        continue
                    if on is not None and (idmap[yy, xx] < 0 or names[idmap[yy, xx]] not in on):
                        continue
                    img[yy, xx] = pal[ch]
        return Image.fromarray(img, 'RGBA')


LIGHT = np.array([-0.5, -0.72, 0.9])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def lighting(sdf, x, y, R):
    """Lambert light on a rounded height field built from the shape's depth."""
    def height(xx, yy):
        d = np.clip(-sdf(xx, yy) / R, 0, 1)
        return np.sqrt(1 - (1 - d) ** 2) * R
    e = 0.5
    zx = (height(x + e, y) - height(x - e, y)) / (2 * e)
    zy = (height(x, y + e) - height(x, y - e)) / (2 * e)
    nx, ny, nz = -zx, -zy, np.ones_like(zx)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    return (nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / n


def despeckle(tone, mask):
    """Pixels whose tone matches none of their 4 neighbours take the most common one."""
    t = tone.copy()
    h, w = t.shape
    for yy in range(h):
        for xx in range(w):
            if not mask[yy, xx]:
                continue
            nbs = [tone[yy + dy, xx + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if 0 <= xx + dx < w and 0 <= yy + dy < h and mask[yy + dy, xx + dx]]
            if len(nbs) >= 3 and tone[yy, xx] not in nbs:
                t[yy, xx] = max(set(nbs), key=nbs.count)
    return t


def mirror(rows):
    return [r[::-1] for r in rows]


def sheet(frames: list[Image.Image]) -> Image.Image:
    out = Image.new('RGBA', (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * SIZE, 0))
    return out
