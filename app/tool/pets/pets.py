"""RUYA companions: Pamuk, Fıstık, Tarçın, Lokum, Mehtap, Boncuk.

Run with Pillow and NumPy installed:
    python tool/pets/pets.py            # writes assets/pets/<id>.png
    python tool/pets/pets.py --preview out.png

Each sprite sheet is one row of 64×64 frames in FRAMES order.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

import numpy as np

from pixel import (SIZE, Part, Sprite, circle, ellipse, grow, half, hexc, inter, poly, ramp,
                   rrect, sheet, sub, superellipse, tube, union)

FRAMES = ['idle0', 'idle1', 'blink', 'sleep0', 'sleep1', 'cozy0', 'cozy1',
          'comfort0', 'comfort1', 'happy0', 'happy1']

SHADOW = hexc('#2a1f4a', 60)

# ---------------------------------------------------------------- shared faces

EYE_OPEN = [
    '.kkkk.',
    'khhkkk',
    'khhkkk',
    'kkkkkk',
    'kkkkbk',
    'kkkbbk',
    '.kkkk.',
]
EYE_HAPPY = [
    '.kkkk.',
    'k....k',
]
EYE_SOFT = [
    'k....k',
    '.kkkk.',
]
MOUTH_CAT = [
    '..nn..',
    'k.kk.k',
    '.k..k.',
]
MOUTH_OPEN = [
    '.kkkk.',
    'krrrrk',
    'krttrk',
    '.kkkk.',
]
MOUTH_SMALL = [
    '..nn..',
    '..kk..',
]
BLUSH = [
    'pPPp',
    '.pp.',
]
HEART_TINY = [
    'o.o',
    'ooo',
    '.o.',
]
HEART_SMALL = [
    '.oo.oo.',
    'orrorro',
    'orhrrro',
    'orrrrro',
    '.orrro.',
    '..oro..',
    '...o...',
]
SPARKLE = [
    '...w...',
    '...w...',
    '..wyw..',
    'wwyyyww',
    '..wyw..',
    '...w...',
    '...w...',
]
SPARKLE_SMALL = [
    '.w.',
    'wyw',
    '.w.',
]
Z_BIG = [
    'zzzzz',
    '...z.',
    '..z..',
    '.z...',
    'zzzzz',
]
Z_SMALL = [
    'zzz',
    '.z.',
    'zzz',
]
STEAM_A = [
    '.s.',
    's..',
    '.s.',
]
STEAM_B = [
    '.s.',
    '..s',
    '.s.',
]
MUG_HEART = [
    'r.r',
    'rrr',
    '.r.',
]
TOES = ['o.o']

FX = {
    'w': hexc('#ffffff'), 'y': hexc('#ffe58a'),
    'z': hexc('#7f77d1'), 's': hexc('#ffffff', 190),
    'o': hexc('#a8325e'), 'r': hexc('#ff6f9c'), 'h': hexc('#ffd1e1'), 't': hexc('#ffa3be'),
}

# ---------------------------------------------------------------- props

BLANKET = ramp('#5b2a50', '#b45d8d', '#d27ea9', '#eaa0c3', '#f9c4dc', ol='#7d3b6b')
BLANKET_DOT = ramp('#5b2a50', '#e6b3cb', '#f4cfe0', '#fff0f7', '#ffffff')
BLANKET_HEM = ramp('#3a2f6b', '#6c5fb8', '#8a7ed6', '#a99ff0', '#c9c2fb')
MUG = ramp('#5a3f3a', '#c4a58e', '#ddc4ad', '#f6e7d6', '#fffaf3', ol='#7a5a52')
TEA = ramp('#5a3f3a', '#b17a2c', '#c99039', '#dfac55', '#f0cc80')
PLUSH = ramp('#6b1f3d', '#b8436b', '#e0668d', '#f58fb0', '#ffc2d6', ol='#8a2d52')


def lighter(r):
    """Same ramp one step brighter, for markings that sit in the light."""
    return {'o': r['o'], 'ol': r['ol'], 'd2': r['d1'], 'd1': r['b'], 'b': r['l1'],
            'l1': r['hi'], 'hi': r['hi']}


class Pet:
    """A pet defines its body parts, face anchors and palettes."""
    id = ''
    eye_y = 24
    eye_lx = 21
    mouth = MOUTH_CAT
    mouth_y = 31
    blush_y = 31
    blush_lx = 16
    hold_y = 49
    neck_y = 36
    toes_y = 58
    toes_lx = 24
    paw_y = 52
    paw_lx = 26
    eye_pal = {'k': '#2a2150', 'h': '#ffffff', 'b': '#6a5cc0', 'n': '#f17fae', 'r': '#e84d7c',
               't': '#ff9bb8', 'p': '#ffb3cf', 'P': '#ff96bd'}

    def __init__(self):
        self.pal = {k: hexc(v) for k, v in self.eye_pal.items()}

    def body(self, s: Sprite, hd: int):
        raise NotImplementedError

    def body_sdf(self):
        raise NotImplementedError

    def fur(self):
        raise NotImplementedError

    # ------------------------------------------------------------ paws
    def paw_colors(self):
        return self.fur()

    def prop(self, s: Sprite, state: str, f: int):
        """Pet-specific item shown in idle and happy frames."""

    def eyes(self, s: Sprite, expr: str, ey: int) -> bool:
        """Override to draw custom eyes; return True when handled."""
        return False

    def paws_front(self, s: Sprite):
        F = self.paw_colors()
        y, lx = self.paw_y, self.paw_lx + 1.6
        s.add(Part('paws', union(superellipse(lx, y, 3.2, 2.6), superellipse(64 - lx, y, 3.2, 2.6)),
                   F, 6, R=2.2))
        s.stamp(self.paw_lx, y, TOES, {'o': F['o']}, on=['paws'])
        s.stamp(64 - self.paw_lx - 3, y, TOES, {'o': F['o']}, on=['paws'])

    def hold_paws(self, s: Sprite, y: float):
        F = self.paw_colors()
        s.add(Part('hold', union(ellipse(26.6, y, 2.6, 2.3), ellipse(37.4, y, 2.6, 2.3)),
                   F, 40, R=1.6))

    def feet_toes(self, s: Sprite):
        F = self.fur()
        s.stamp(self.toes_lx, self.toes_y, TOES, {'o': F['o']})
        s.stamp(64 - self.toes_lx - 3, self.toes_y, TOES, {'o': F['o']})

    # ------------------------------------------------------------ faces
    def face(self, s: Sprite, expr: str, dy: int):
        ey = self.eye_y + dy
        lx = self.eye_lx
        rx = SIZE - lx - 6
        pal = self.pal
        if self.eyes(s, expr, ey):
            pass
        elif expr == 'open':
            s.stamp(lx, ey, EYE_OPEN, pal)
            s.stamp(rx, ey, EYE_OPEN, pal)
        elif expr == 'happy':
            s.stamp(lx, ey + 3, EYE_HAPPY, pal)
            s.stamp(rx, ey + 3, EYE_HAPPY, pal)
        else:  # blink, sleep, soft
            s.stamp(lx, ey + 4, EYE_SOFT, pal)
            s.stamp(rx, ey + 4, EYE_SOFT, pal)
        mouth = {'happy': MOUTH_OPEN, 'sleep': MOUTH_SMALL}.get(expr, self.mouth)
        mw = len(mouth[0])
        s.stamp((SIZE - mw) // 2, self.mouth_y + dy, mouth, pal)
        self.face_extra(s, dy)
        bl = self.blush_lx
        s.stamp(bl, self.blush_y + dy, BLUSH, pal)
        s.stamp(SIZE - bl - 4, self.blush_y + dy, BLUSH, pal)

    def face_extra(self, s: Sprite, dy: int):
        pass

    # ------------------------------------------------------------ frames
    def frame(self, name: str) -> Image.Image:
        s = Sprite()
        s.shadow(ellipse(32, 59.6, 17, 2.4), SHADOW)
        hd = 1 if name == 'idle1' else 0
        self.body(s, hd)
        state = name.rstrip('01')
        f = int(name[-1]) if name[-1].isdigit() else 0
        if state in ('idle', 'blink', 'happy', 'sleep'):
            self.paws_front(s)
        if state in ('idle', 'blink', 'happy'):
            self.prop(s, state, f)
        if state == 'cozy':
            self.blanket(s)
            self.mug(s, f)
        if state == 'comfort':
            self.plush(s)
        expr = {'idle': 'open', 'blink': 'blink', 'sleep': 'sleep', 'cozy': 'soft',
                'comfort': 'soft', 'happy': 'happy'}[state]
        self.face(s, expr, hd)
        if state == 'sleep':
            s.stamp(47, 12 - f, Z_BIG, FX)
            s.stamp(54, 5 - f, Z_SMALL, FX)
        if state == 'comfort':
            s.stamp(50, 16 - 2 * f, HEART_TINY, FX)
            s.stamp(10, 21 - 2 * f, HEART_TINY, FX)
        if state == 'happy':
            if f == 0:
                s.stamp(4, 12, SPARKLE, FX)
                s.stamp(54, 22, SPARKLE_SMALL, FX)
            else:
                s.stamp(52, 8, SPARKLE, FX)
                s.stamp(7, 26, SPARKLE_SMALL, FX)
        dy = -2 if name == 'happy1' else 0
        if dy:
            s.under = []
        img = s.render(0, dy)
        if dy:
            base = Sprite()
            base.shadow(ellipse(32, 59.6, 14, 2.0), SHADOW)
            img = Image.alpha_composite(base.render(), img)
        return img

    # ------------------------------------------------------------ props
    def blanket(self, s: Sprite):
        top = self.neck_y
        scallop = union(half(y1=57.5), *[circle(x, 57.6, 1.9) for x in range(16, 49, 4)])
        shape = inter(union(grow(self.body_sdf(), 1.6), ellipse(32, 56, 14.2, 3.6)),
                      half(y0=top), scallop)
        s.add(Part('blanket', shape, BLANKET, 5.5, R=5))
        dots = lambda x, y: np.hypot(((x + 2) % 6) - 3, ((y + (x // 6) % 2 * 3) % 6) - 3) - 1.0
        s.add(Part('blanket_dot', inter(shape, dots, half(y1=55.5)), BLANKET_DOT, 5.6,
                   decal_of='blanket', line=False, outline=False, group='blanket'))
        hem = inter(shape, half(y0=55.5, y1=56.5))
        s.add(Part('blanket_hem', hem, BLANKET_HEM, 5.7, decal_of='blanket', line=False,
                   outline=False, group='blanket'))

    def mug(self, s: Sprite, f: int):
        y = self.hold_y
        s.add(Part('mug', rrect(32, y, 4.8, 4.6, 1.4), MUG, 30, R=2.5))
        handle = sub(circle(37.4, y, 2.9), circle(37.4, y, 1.3))
        s.add(Part('mug_handle', handle, MUG, 29, group='mug', R=1.2))
        s.add(Part('tea', ellipse(32, y - 3.6, 3.6, 1.0), TEA, 31, outline=False, line=False,
                   flat='d1', group='mug'))
        s.stamp(31, y - 1, MUG_HEART, FX, on=['mug'])
        s.stamp(29, y - 9, STEAM_A if f == 0 else STEAM_B, FX)
        s.stamp(32, y - 10, STEAM_B if f == 0 else STEAM_A, FX)
        self.hold_paws(s, y + 1.5)

    def plush(self, s: Sprite):
        y = self.hold_y
        heart = union(circle(28.6, y - 1.6, 4.4), circle(35.4, y - 1.6, 4.4),
                      poly([(24.3, y - 0.2), (39.7, y - 0.2), (32, y + 7.8)]))
        s.add(Part('plush', heart, PLUSH, 30, R=4))
        s.stamp(26, y - 4, ['hh', 'h.'], FX)
        self.hold_paws(s, y + 1)


# ---------------------------------------------------------------- Pamuk

class Pamuk(Pet):
    """Cloud cat: snow-white fur, a cloud tuft on the forehead and a cloud-puff tail."""
    id = 'pamuk'
    FUR = ramp('#3f3568', '#9d97d4', '#c3c0ee', '#eceefe', '#ffffff', ol='#6a60a0')
    EAR_IN = ramp('#3f3568', '#d9739f', '#ee98bd', '#f8b9d5', '#ffd9ea')

    def fur(self):
        return self.FUR

    def face_extra(self, s, dy):
        w = {'w': hexc('#9d97d4')}
        s.stamp(12, 29 + dy, ['ww..', '..ww'], w)
        s.stamp(48, 29 + dy, ['..ww', 'ww..'], w)

    def body_sdf(self):
        return superellipse(32, 46.4, 13, 12, 2.2)

    def body(self, s, hd):
        F = self.FUR
        tail = union(tube([(42, 55), (49, 54), (53.5, 49), (53.5, 43), (50.5, 39.5)], 3.2, 2.5),
                     circle(50.2, 38.4, 3.3), circle(53.4, 40.6, 2.7))
        s.add(Part('tail', tail, F, 0, R=3))
        s.add(Part('body', self.body_sdf(), F, 1, R=5.5))
        chest = poly([(26, 36.5), (38, 36.5), (36.2, 44.5), (34.2, 42.6), (32, 46),
                      (29.8, 42.6), (27.8, 44.5)])
        s.add(Part('chest', inter(chest, self.body_sdf()), lighter(F), 1.5, decal_of='body',
                   line=False, outline=False, group='body'))
        s.add(Part('feet', union(superellipse(25.5, 57.4, 4.6, 2.7, 2.2), superellipse(38.5, 57.4, 4.6, 2.7, 2.2)),
                   F, 2, R=2.4))
        head = union(superellipse(32, 26.5 + hd, 16.4, 12.4, 2.3),
                     circle(29.8, 14.6 + hd, 2.6), circle(33.8, 14.0 + hd, 2.9),
                     grow(poly([(17.6, 29.8 + hd), (14.2, 34.6 + hd), (19.4, 34.2 + hd)]), 0.6),
                     grow(poly([(46.4, 29.8 + hd), (49.8, 34.6 + hd), (44.6, 34.2 + hd)]), 0.6))
        s.add(Part('head', head, F, 5, R=4.5))
        ear_l = grow(poly([(16.2, 22 + hd), (18.2, 6.4 + hd), (28.8, 15 + hd)]), 1.2)
        ear_r = grow(poly([(47.8, 22 + hd), (45.8, 6.4 + hd), (35.2, 15 + hd)]), 1.2)
        s.add(Part('ear_l', ear_l, F, 4, group='ear', R=3))
        s.add(Part('ear_r', ear_r, F, 4, group='ear', R=3))
        s.add(Part('ear_li', poly([(19, 19.6 + hd), (19.8, 10.6 + hd), (25.8, 15.6 + hd)]),
                   self.EAR_IN, 4.5, decal_of='ear_l', line=False, outline=False, group='ear'))
        s.add(Part('ear_ri', poly([(45, 19.6 + hd), (44.2, 10.6 + hd), (38.2, 15.6 + hd)]),
                   self.EAR_IN, 4.5, decal_of='ear_r', line=False, outline=False, group='ear'))


# ---------------------------------------------------------------- Fıstık

class Fistik(Pet):
    """Squirrel with a big bushy tail, ear tufts, buck teeth and an acorn."""
    id = 'fistik'
    FUR = ramp('#4a2418', '#9b5531', '#c47442', '#e3995e', '#f6bf86', hi='#ffe1b8', ol='#7a3d26')
    CREAM = ramp('#4a2418', '#d9ad84', '#ebc59e', '#f9e0c0', '#fff3e0')
    ACORN = ramp('#3a2414', '#9c6a3a', '#b98048', '#d39c5c', '#ebbd80')
    CAP = ramp('#2e1a10', '#5a3520', '#6e4329', '#855436', '#a06b48')
    mouth = ['..nn..', 'k.kk.k', '.kwwk.', '..kk..']
    mouth_y = 31
    eye_pal = dict(Pet.eye_pal, k='#2b1a14', b='#7a4a32', n='#5a2e1c', w='#ffffff')

    def fur(self):
        return self.FUR

    def body_sdf(self):
        return superellipse(32, 46.6, 12, 11.8, 2.2)

    def body(self, s, hd):
        F, C = self.FUR, self.CREAM
        tail = tube([(40, 56), (49, 55.5), (55, 49), (56.5, 40), (54, 31.5), (49, 26.5)], 5.6, 4.2)
        s.add(Part('tail', tail, F, 0, R=4))
        stripe = tube([(42, 55.5), (49.5, 54.5), (54, 48.5), (55.2, 40), (53, 32.5)], 1.6, 1.3)
        s.add(Part('tail_stripe', inter(stripe, tail), lighter(F), 0.5, decal_of='tail',
                   line=False, outline=False, group='tail'))
        s.add(Part('body', self.body_sdf(), F, 1, R=5.5))
        s.add(Part('belly', inter(ellipse(32, 48.5, 7, 8.6), self.body_sdf()), C, 1.5,
                   decal_of='body', line=False, outline=False, group='body'))
        s.add(Part('feet', union(superellipse(25.8, 57.4, 4.4, 2.7, 2.2),
                                 superellipse(38.2, 57.4, 4.4, 2.7, 2.2)), F, 2, R=2.4))
        head = union(superellipse(32, 27 + hd, 15.4, 11.8, 2.25),
                     grow(poly([(17.6, 29 + hd), (14.6, 33.8 + hd), (19.6, 33.6 + hd)]), 0.6),
                     grow(poly([(46.4, 29 + hd), (49.4, 33.8 + hd), (44.4, 33.6 + hd)]), 0.6))
        s.add(Part('head', head, F, 5, R=4.5))
        muzzle = union(ellipse(32, 32.2 + hd, 7.6, 5.2), ellipse(23.5, 31.5 + hd, 4.6, 3.4),
                       ellipse(40.5, 31.5 + hd, 4.6, 3.4))
        s.add(Part('muzzle', inter(muzzle, head), C, 5.5, decal_of='head', line=False,
                   outline=False, group='head'))
        for side in (-1, 1):
            cx = 32 + side * 9.5
            ear = grow(poly([(cx - side * 3.6, 18 + hd), (cx + side * 0.6, 7.6 + hd),
                             (cx + side * 4.2, 16 + hd)]), 1.1)
            tuft = poly([(cx - side * 0.8, 9.6 + hd), (cx + side * 0.2, 3.6 + hd),
                         (cx + side * 2.6, 8.8 + hd)])
            nm = 'ear_l' if side < 0 else 'ear_r'
            s.add(Part(nm, union(ear, tuft), F, 4, group='ear', R=2.6))
            inner = grow(poly([(cx - side * 2.2, 16.6 + hd), (cx + side * 0.6, 10.6 + hd),
                               (cx + side * 2.6, 15.6 + hd)]), 0.2)
            s.add(Part(nm + 'i', inner, C, 4.5, decal_of=nm, line=False, outline=False,
                       group='ear'))

    def prop(self, s, state, f):
        y = self.paw_y - 3.6
        s.add(Part('acorn', ellipse(32, y + 1.4, 3.2, 3.6), self.ACORN, 5.8, R=2.2))
        s.add(Part('cap', inter(ellipse(32, y - 0.6, 4.0, 2.6), half(y1=y + 0.6)), self.CAP, 5.9,
                   R=1.6, group='acorn_cap'))
        s.stamp(31, int(y) - 4, ['.o', 'o.'], {'o': self.CAP['o']})


# ---------------------------------------------------------------- Tarçın

class Tarcin(Pet):
    """Fox kit: cinnamon fur, white cheeks, dark ear tips and socks, white-tipped tail."""
    id = 'tarcin'
    FUR = ramp('#4d1f12', '#a8461f', '#d0622b', '#ef8640', '#ffad6b', hi='#ffd3a3', ol='#7f3418')
    WHITE = ramp('#4d1f12', '#d4c6c3', '#e9dfdb', '#fbf6f2', '#ffffff')
    DARK = ramp('#22100a', '#3f2117', '#52291c', '#683626', '#814836', ol='#2e150d')
    mouth = ['..nn..', 'k.kk.k', '.k..k.']
    eye_pal = dict(Pet.eye_pal, k='#2a1610', b='#8a4a2c', n='#2a1610')
    blush_y = 31

    def fur(self):
        return self.FUR

    def paw_colors(self):
        return self.DARK

    def body_sdf(self):
        return superellipse(32, 46.6, 12, 11.8, 2.2)

    def body(self, s, hd):
        F, W, D = self.FUR, self.WHITE, self.DARK
        tail = tube([(41, 56.5), (48.5, 57.6), (54.5, 54.5), (56.8, 48), (55, 41.5)], 3.6, 5.6)
        s.add(Part('tail', tail, F, 0, R=4))
        s.add(Part('tail_tip', inter(tail, circle(55.2, 41.2, 5.2)), W, 0.5, decal_of='tail',
                   line=False, outline=False, group='tail'))
        s.add(Part('body', self.body_sdf(), F, 1, R=5.5))
        chest = poly([(25.5, 36.5), (38.5, 36.5), (36.4, 46), (34.2, 43.8), (32, 48),
                      (29.8, 43.8), (27.6, 46)])
        s.add(Part('chest', inter(chest, self.body_sdf()), W, 1.5, decal_of='body', line=False,
                   outline=False, group='body'))
        s.add(Part('feet', union(superellipse(25.8, 57.4, 4.4, 2.7, 2.2),
                                 superellipse(38.2, 57.4, 4.4, 2.7, 2.2)), D, 2, R=2.4))
        head = union(superellipse(32, 26.6 + hd, 16.2, 11.4, 2.3),
                     grow(poly([(18.6, 28.2 + hd), (14.2, 34.4 + hd), (21.6, 35.2 + hd)]), 0.7),
                     grow(poly([(45.4, 28.2 + hd), (49.8, 34.4 + hd), (42.4, 35.2 + hd)]), 0.7))
        s.add(Part('head', head, F, 5, R=4.5))
        cheeks = sub(inter(head, half(y0=29.2 + hd)), poly([(27.4, 29 + hd), (36.6, 29 + hd),
                                                          (32, 33.2 + hd)]))
        s.add(Part('cheeks', union(cheeks, inter(head, ellipse(32, 34.6 + hd, 5.4, 3.6))), W,
                   5.5, decal_of='head', line=False, outline=False, group='head'))
        for side in (-1, 1):
            cx = 32 + side * 10.2
            ear = grow(poly([(cx - side * 4.4, 19 + hd), (cx + side * 0.2, 4.6 + hd),
                             (cx + side * 4.8, 16.4 + hd)]), 1.1)
            nm = 'ear_l' if side < 0 else 'ear_r'
            s.add(Part(nm, ear, F, 4, group='ear', R=2.6))
            s.add(Part(nm + 't', inter(ear, half(y1=10.4 + hd)), D, 4.4, decal_of=nm, line=False,
                       outline=False, group='ear'))
            inner = poly([(cx - side * 2.4, 17.6 + hd), (cx + side * 0.2, 9.8 + hd),
                          (cx + side * 2.8, 16 + hd)])
            s.add(Part(nm + 'i', inner, W, 4.5, decal_of=nm, line=False, outline=False,
                       group='ear'))


# ---------------------------------------------------------------- Lokum

class Lokum(Pet):
    """Rose-lokum bunny dusted with powdered sugar; one ear flops over."""
    id = 'lokum'
    FUR = ramp('#5e2443', '#c66e97', '#e090b3', '#f6b8d1', '#ffd9e8', hi='#fff1f7', ol='#8a3f68')
    INNER = ramp('#5e2443', '#d45a8a', '#e877a1', '#f797b8', '#ffb6cd')
    TAIL = ramp('#7a4a66', '#e3cbd8', '#f2e2eb', '#fff7fb', '#ffffff')
    mouth = ['..nn..', '...k..', '..k.k.']
    eye_pal = dict(Pet.eye_pal, k='#3a1730', b='#a04a7a', n='#d14b7e')
    blush_lx = 17
    SUGAR = [(20, 22), (27, 18), (40, 19), (44, 25), (23, 36), (40, 40), (27, 44), (37, 50),
             (22, 50), (43, 47), (34, 41), (18, 29), (46, 31), (30, 54)]

    def fur(self):
        return self.FUR

    def body_sdf(self):
        return superellipse(32, 46.6, 12.6, 11.8, 3.0)

    def body(self, s, hd):
        F = self.FUR
        s.add(Part('tail', circle(45.4, 53.4, 4.0), self.TAIL, 0.5, R=3))
        s.add(Part('body', self.body_sdf(), F, 1, R=5.5))
        s.add(Part('feet', union(superellipse(25.6, 57.4, 4.8, 2.7, 2.2),
                                 superellipse(38.4, 57.4, 4.8, 2.7, 2.2)), F, 2, R=2.4))
        head = superellipse(32, 27.4 + hd, 15, 12, 2.15)
        s.add(Part('head', head, F, 5, R=4.5))
        ear_l = tube([(25.6, 18 + hd), (23.6, 10 + hd), (22.6, 2.8 + hd)], 3.8, 3.2)
        ear_r = tube([(38.6, 18 + hd), (42.4, 10.6 + hd), (47.6, 7.6 + hd), (52, 9.6 + hd)],
                     3.8, 2.8)
        s.add(Part('ear_l', ear_l, F, 4, group='ear', R=2.4))
        s.add(Part('ear_r', ear_r, F, 4.2, group='ear_r', R=2.4))
        s.add(Part('ear_li', tube([(25.4, 16 + hd), (23.8, 9.8 + hd), (23.2, 5.4 + hd)], 1.6, 1.3),
                   self.INNER, 4.5, decal_of='ear_l', line=False, outline=False, group='ear'))
        s.add(Part('ear_ri', tube([(39.6, 15.8 + hd), (42.8, 11 + hd), (47.4, 9.2 + hd)], 1.6, 1.2),
                   self.INNER, 4.6, decal_of='ear_r', line=False, outline=False, group='ear_r'))

    def face_extra(self, s, dy):
        sugar = {'w': self.FUR['hi']}
        for x, y in self.SUGAR:
            yy = y + (dy if y < 38 else 0)
            s.stamp(x, yy, ['w'], sugar, on=['head', 'body', 'ear_l', 'ear_r'])


# ---------------------------------------------------------------- Mehtap

class Mehtap(Pet):
    """Owl in moonlit indigo with a cream face disc and golden eyes."""
    id = 'mehtap'
    FUR = ramp('#211a4a', '#3f3888', '#5650a8', '#706ac4', '#8f89dc', hi='#b7b2f0', ol='#352d72')
    FACE = ramp('#211a4a', '#d3c19f', '#e6d7b8', '#f6ecd8', '#fffaf0', ol='#5a4a3a')
    BELLY = ramp('#211a4a', '#7c76c8', '#948fdc', '#aea9ec', '#c9c5f7')
    WING = ramp('#1a1440', '#332c74', '#463f94', '#5b55b0', '#7670cc', ol='#241d55')
    eye_pal = dict(Pet.eye_pal, k='#1d1638', n='#e08a2e', p='#f7b6c8', P='#f39bb5')
    OWL_EYE = [
        '..oooo..',
        '.oyyyyo.',
        'oyykkyyo',
        'oykhkkyo',
        'oykkkkyo',
        'oyykkyyo',
        '.oyyyyo.',
        '..oooo..',
    ]
    OWL_CLOSED = ['o......o', '.oooooo.']
    OWL_HAPPY = ['.oooooo.', 'o......o']
    BEAK = ['obbo', '.bb.']
    blush_lx = 17
    blush_y = 33
    mouth_y = 32
    neck_y = 39

    def __init__(self):
        super().__init__()
        self.pal.update({'o': hexc('#3a2a1c'), 'y': hexc('#ffcf5c'), 'b': hexc('#f29a38'),
                         'h': hexc('#ffffff')})

    def fur(self):
        return self.FUR

    def paw_colors(self):
        return self.WING

    def body_sdf(self):
        return superellipse(32, 46.4, 13.6, 12.2, 2.2)

    def eyes(self, s, expr, ey):
        lx, rx = 20, 36
        if expr == 'open':
            s.stamp(lx, ey, self.OWL_EYE, self.pal)
            s.stamp(rx, ey, self.OWL_EYE, self.pal)
        elif expr == 'happy':
            s.stamp(lx, ey + 3, self.OWL_HAPPY, self.pal)
            s.stamp(rx, ey + 3, self.OWL_HAPPY, self.pal)
        else:
            s.stamp(lx, ey + 4, self.OWL_CLOSED, self.pal)
            s.stamp(rx, ey + 4, self.OWL_CLOSED, self.pal)
        return True

    def face(self, s, expr, dy):
        ey = self.eye_y + dy
        self.eyes(s, expr, ey)
        s.stamp(30, self.mouth_y + dy, self.BEAK, self.pal)
        s.stamp(self.blush_lx, self.blush_y + dy, BLUSH, self.pal)
        s.stamp(SIZE - self.blush_lx - 4, self.blush_y + dy, BLUSH, self.pal)

    def body(self, s, hd):
        F = self.FUR
        s.add(Part('body', self.body_sdf(), F, 1, R=5.5))
        belly = inter(ellipse(32, 48, 8.6, 9.6), self.body_sdf())
        s.add(Part('belly', belly, self.BELLY, 1.5, decal_of='body', line=False, outline=False,
                   group='body'))
        marks = {'v': self.FUR['d1']}
        for x, y in [(27, 44), (33, 44), (30, 48), (36, 48), (27, 52), (33, 52)]:
            s.stamp(x, y, ['v.v', '.v.'], marks, on=['body', 'belly'])
        for side in (-1, 1):
            nm = 'wing_l' if side < 0 else 'wing_r'
            wing = ellipse(32 + side * 12.6, 46.6, 4.4, 8.6, rot=side * -14)
            s.add(Part(nm, wing, self.WING, 3, R=3))
        s.add(Part('feet', union(superellipse(26.4, 58, 3.6, 1.9, 2), superellipse(37.6, 58, 3.6, 1.9, 2)),
                   ramp('#6a3a12', '#d9832a', '#ec9a3c', '#f7b45a', '#ffd07e'), 2, R=1.5))
        head = union(superellipse(32, 27.6 + hd, 16, 12.2, 2.3),
                     grow(poly([(17, 21 + hd), (14.4, 9.6 + hd), (24.6, 16.4 + hd)]), 0.9),
                     grow(poly([(47, 21 + hd), (49.6, 9.6 + hd), (39.4, 16.4 + hd)]), 0.9))
        s.add(Part('head', head, F, 5, R=4.5))
        disc = union(circle(24.2, 28.6 + hd, 6.9), circle(39.8, 28.6 + hd, 6.9),
                     ellipse(32, 31.4 + hd, 6.2, 5.6))
        s.add(Part('disc', inter(disc, head), self.FACE, 6, R=3.5, line=True))

    def paws_front(self, s):
        pass


# ---------------------------------------------------------------- Boncuk

class Boncuk(Pet):
    """Turtle with a blue bead-patterned shell."""
    id = 'boncuk'
    SKIN = ramp('#1f3d2a', '#4f9a5c', '#6cb876', '#8fd394', '#b5ebb3', hi='#dcf9d6', ol='#2f5c3e')
    SHELL = ramp('#142a5c', '#1f4fa8', '#2c6ccf', '#3f8ae6', '#6fb0f5', hi='#a8d6ff', ol='#1e3c80')
    PLASTRON = ramp('#4a3a1a', '#d4ad57', '#e6c673', '#f6df9a', '#fff1c4', ol='#6e5626')
    BEAD = ['.www.', 'wcccw', 'wcdcw', 'wcccw', '.www.']
    mouth = ['k....k', '.kkkk.']
    mouth_y = 31
    eye_pal = dict(Pet.eye_pal, k='#14281c', b='#3f7a52')
    neck_y = 37
    blush_lx = 19
    blush_y = 30

    def fur(self):
        return self.SKIN

    def body_sdf(self):
        return superellipse(32, 47, 15.6, 12.2, 2.3)

    def body(self, s, hd):
        K = self.SKIN
        s.add(Part('feet', union(superellipse(24.8, 57.6, 4.4, 2.6, 2.2),
                                 superellipse(39.2, 57.6, 4.4, 2.6, 2.2)), K, 0.6, R=2.4))
        s.add(Part('shell', self.body_sdf(), self.SHELL, 1, R=6))
        bead_pal = {'w': hexc('#ffffff'), 'c': hexc('#8fd3ff'), 'd': hexc('#10235a')}
        for x, y in [(17, 41), (42, 41), (15, 49), (44, 49)]:
            s.stamp(x, y, self.BEAD, bead_pal, on=['shell'])
        plastron = superellipse(32, 48.4, 9.6, 9.4, 2.4)
        s.add(Part('plastron', plastron, self.PLASTRON, 2, R=4))
        seg = {'s': self.PLASTRON['d1']}
        for y in (44, 49, 53):
            s.stamp(26, y, ['ssssssssssss'], seg, on=['plastron'])
        s.stamp(31, 40, ['ss'] * 15, seg, on=['plastron'])
        for side in (-1, 1):
            nm = 'arm_l' if side < 0 else 'arm_r'
            s.add(Part(nm, ellipse(32 + side * 15.2, 46.6, 3.0, 4.6, rot=side * 24), K, 2.5, R=2))
        head = superellipse(32, 26.4 + hd, 14, 11.6, 2.15)
        s.add(Part('head', head, K, 5, R=4.5))
        spots = {'s': K['d1']}
        s.stamp(29, 17 + hd, ['ss.', 's..'], spots, on=['head'])
        s.stamp(36, 18 + hd, ['.s', 'ss'], spots, on=['head'])

    def paws_front(self, s):
        pass


PETS = [Pamuk, Fistik, Tarcin, Lokum, Mehtap, Boncuk]



def build(pet_cls) -> Image.Image:
    pet = pet_cls()
    return sheet([pet.frame(n) for n in FRAMES])


def preview(path: str, scale: int = 6):
    rows = [build(p) for p in PETS]
    w = rows[0].width * scale
    h = SIZE * scale
    out = Image.new('RGBA', (w, h * len(rows) * 2), (0, 0, 0, 255))
    for i, r in enumerate(rows):
        big = r.resize((w, h), Image.NEAREST)
        light = Image.new('RGBA', (w, h), hexc('#f7f4ff'))
        dark = Image.new('RGBA', (w, h), hexc('#1d1a2e'))
        out.paste(Image.alpha_composite(light, big), (0, i * 2 * h))
        out.paste(Image.alpha_composite(dark, big), (0, (i * 2 + 1) * h))
    out.save(path)


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--preview':
        preview(sys.argv[2])
    else:
        dest = Path(__file__).resolve().parents[2] / 'assets' / 'pets'
        dest.mkdir(parents=True, exist_ok=True)
        for p in PETS:
            build(p).save(dest / f'{p.id}.png')
            print('wrote', dest / f'{p.id}.png')
