"""Room furniture for the companions' room (assets/room/*.png).

Each item is drawn on a 64×64 canvas with pixel.py, cropped to its pixels and
listed with its size in lib/companion/room_catalog.g.dart, which the app uses
to place it in the scene. Run: python tool/pets/room.py
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from pixel import (Part, Sprite, circle, ellipse, grow, half, hexc, inter, poly, ramp, rrect, sub,
                   superellipse, tube, union)

WOOD = ramp('#3a2414', '#8a5a34', '#a87244', '#c48f5c', '#e0b080', ol='#5a3a22')
WHITE = ramp('#4a4470', '#b9b6dc', '#d9d7f0', '#f6f5ff', '#ffffff', ol='#6a6496')
PINK = ramp('#6b1f3d', '#b8436b', '#e0668d', '#f58fb0', '#ffc2d6', ol='#8a2d52')
PINK_DOT = ramp('#6b1f3d', '#e6b3cb', '#f4cfe0', '#fff0f7', '#ffffff')
TEAL = ramp('#123f4a', '#1f7f8c', '#2fa3ad', '#59c7c9', '#93e3df', ol='#1d5c68')
GREEN = ramp('#1f3d2a', '#3f8a4c', '#58a862', '#7cc784', '#a8e3a6', ol='#2f5c3e')
RED = ramp('#5c1220', '#a81f35', '#d0334a', '#ee5466', '#ff8c96', ol='#7a1a2c')
LAV = ramp('#3d2f6e', '#7464b8', '#9384dc', '#b3a6f0', '#d3cbfa', ol='#55468f')
YELLOW = ramp('#6a4a08', '#d19a1a', '#eeb82a', '#ffd84a', '#fff0a0', ol='#8a6410')
CLAY = ramp('#5a2a1c', '#b85a3a', '#d4744e', '#ec9468', '#ffb890', ol='#7a3c28')
CREAM = ramp('#5a3f3a', '#c4a58e', '#ddc4ad', '#f6e7d6', '#fffaf3', ol='#7a5a52')
BLUE = ramp('#142a5c', '#1f4fa8', '#2c6ccf', '#3f8ae6', '#6fb0f5', ol='#1e3c80')
DARK = ramp('#1a1430', '#2b2150', '#3a2f6e', '#4a3f88', '#6a5fb0')
FX = {'w': hexc('#ffffff'), 'y': hexc('#ffd84a'), 'g': hexc('#58a862'), 'r': hexc('#ee5466'),
      'd': hexc('#2f5c3e'), 'n': hexc('#10235a'), 'c': hexc('#f6e7d6'), 'o': hexc('#7a1a2c'),
      'k': hexc('#3a2414')}


def win_wood(s):
    outer = rrect(32, 32, 22, 22, 3)
    panes = union(rrect(22.4, 22.4, 8.2, 8.2, 1), rrect(41.6, 22.4, 8.2, 8.2, 1),
                  rrect(22.4, 41.6, 8.2, 8.2, 1), rrect(41.6, 41.6, 8.2, 8.2, 1))
    s.add(Part('frame', sub(outer, panes), WOOD, 1, R=2.4))


def win_arch(s):
    outer = union(rrect(32, 40, 19, 16, 1.5), inter(circle(32, 26, 19), half(y1=27)))
    inner = union(rrect(32, 40, 15, 13, 1), inter(circle(32, 26, 15), half(y1=27.5)))
    bars = union(rrect(32, 32, 1.1, 26), rrect(32, 37, 16, 1.1))
    s.add(Part('frame', union(sub(outer, inner), inter(bars, inner)), WHITE, 1, R=2.2))


def win_curtain(s):
    win_wood(s)
    s.add(Part('rod', rrect(32, 8.6, 25, 1.4, 1), WOOD, 2, group='rod', R=1))
    left = poly([(8, 10), (22, 10), (18, 30), (12, 50), (8, 54)])
    right = poly([(56, 10), (42, 10), (46, 30), (52, 50), (56, 54)])
    s.add(Part('cl', grow(left, 0.6), PINK, 3, group='cur', R=4))
    s.add(Part('cr', grow(right, 0.6), PINK, 3, group='cur', R=4))
    folds = lambda x, y: np.abs(((x + y * 0.12) % 4) - 2) - 0.6
    s.add(Part('clf', inter(grow(left, 0.6), folds), PINK_DOT, 3.2, decal_of='cl', line=False, outline=False, group='cur'))
    s.add(Part('crf', inter(grow(right, 0.6), folds), PINK_DOT, 3.2, decal_of='cr', line=False, outline=False, group='cur'))


def pic_tulip(s):
    s.add(Part('frame', rrect(32, 32, 11, 13, 1.5), WOOD, 1, R=2))
    s.add(Part('mat', rrect(32, 32, 8, 10, 0.5), CREAM, 2, flat='b', outline=False, line=False))
    s.stamp(29, 24, ['r.r.r', 'rrrrr', 'rrrrr', '.rrr.', '..g..', '..g..', 'g.g.g', '.ggg.', '..g..', '..g..'], FX)


def nazar(s):
    s.add(Part('loop', sub(circle(32, 17.5, 3), circle(32, 17.5, 1.4)), YELLOW, 0.5, R=1))
    s.add(Part('n1', circle(32, 34, 13), BLUE, 1, R=6))
    s.add(Part('n2', circle(32, 34, 8.8), WHITE, 2, line=False, outline=False, flat='b'))
    s.add(Part('n3', circle(32, 34, 5.8), ramp('#142a5c', '#5ab0e8', '#7cc6f5', '#9ad8ff', '#c6eaff'), 3,
               line=False, outline=False, flat='b'))
    s.add(Part('n4', circle(32, 34, 2.8), ramp('#000000', '#0a1230', '#0a1230', '#10183c', '#1a2450'), 4,
               line=False, outline=False, flat='b'))
    s.stamp(25, 26, ['ww', 'w.'], FX)


def garland(s):
    s.add(Part('string', tube([(4, 20), (18, 27), (32, 29), (46, 27), (60, 20)], 0.7, 0.7), DARK, 1,
               flat='d1', outline=False, line=False))
    star = ['..y..', '.yyy.', 'yyyyy', '.yyy.', '.y.y.']
    for x, y in [(7, 24), (19, 29), (30, 31), (41, 29), (53, 24)]:
        s.stamp(x, y, star, FX)


def lamp(s):
    s.add(Part('base', ellipse(32, 57, 7, 2.4), WOOD, 1, R=2))
    s.add(Part('pole', rrect(32, 45, 1.2, 12, 0.4), WOOD, 1.2, group='base', R=1))
    s.add(Part('shade', grow(poly([(25, 22), (39, 22), (43, 35), (21, 35)]), 0.8), YELLOW, 2, R=5))


def lantern(s):
    s.add(Part('handle', sub(circle(32, 36, 6), circle(32, 36, 4.4)), DARK, 0.5, flat='d1', outline=False, line=False))
    s.add(Part('top', rrect(32, 40, 7, 1.8, 0.8), DARK, 2, R=1.2))
    s.add(Part('glass', rrect(32, 49, 6, 7.4, 1.6), YELLOW, 1, R=3))
    s.add(Part('bot', rrect(32, 57.4, 7.6, 1.8, 0.8), DARK, 2, group='top', R=1.2))
    s.add(Part('bars', union(rrect(26.6, 49, 0.7, 7.4), rrect(37.4, 49, 0.7, 7.4)), DARK, 3, flat='d1',
               outline=False, line=False))
    s.stamp(31, 46, ['.w.', 'www', 'www', '.w.'], FX)


def plant(s):
    pot = poly([(24, 44), (40, 44), (38, 57), (26, 57)])
    s.add(Part('pot', grow(pot, 0.8), CLAY, 2, R=4))
    for a, l in [(-50, 15), (-20, 19), (10, 20), (38, 16), (62, 12)]:
        r = np.radians(a - 90)
        cx, cy = 32 + np.cos(r) * l * 0.55, 44 + np.sin(r) * l * 0.55
        s.add(Part(f'lf{a}', ellipse(cx, cy, 3.4, l * 0.55, rot=a), GREEN, 1, group=f'lf{a}', R=2.2))


def pot_tulip(s):
    pot = poly([(23, 46), (41, 46), (39, 57), (25, 57)])
    s.add(Part('pot', grow(pot, 0.8), TEAL, 3, R=4))
    for dx, top in [(-6, 26), (0, 20), (6, 27)]:
        x = 32 + dx
        s.add(Part(f'st{dx}', rrect(x, (top + 46) / 2, 0.9, (46 - top) / 2, 0.4), GREEN, 1, group='st', R=1))
        cup = union(inter(ellipse(x, top - 2, 4.2, 5.4), half(y0=top - 5.5, y1=top + 2.6)),
                    poly([(x - 4.2, top - 4), (x - 2.6, top - 9), (x - 0.8, top - 4)]),
                    poly([(x - 1.6, top - 4), (x, top - 10), (x + 1.6, top - 4)]),
                    poly([(x + 0.8, top - 4), (x + 2.6, top - 9), (x + 4.2, top - 4)]))
        s.add(Part(f'fl{dx}', cup, RED if dx else YELLOW, 2, group=f'fl{dx}', R=2.4))
    s.add(Part('lf1', ellipse(27, 40, 2.2, 6.5, rot=-24), GREEN, 1.5, group='lf', R=1.8))
    s.add(Part('lf2', ellipse(37, 40, 2.2, 6.5, rot=24), GREEN, 1.5, group='lf', R=1.8))


def pot_lavender(s):
    pot = poly([(23, 46), (41, 46), (39, 57), (25, 57)])
    s.add(Part('pot', grow(pot, 0.8), CREAM, 3, R=4))
    for dx, top in [(-8, 22), (-3, 16), (3, 15), (8, 21)]:
        s.add(Part(f'st{dx}', tube([(32 + dx * 0.5, 46), (32 + dx, top + 12)], 0.8, 0.8), GREEN, 1, group='st', R=1))
        s.add(Part(f'fl{dx}', union(*[circle(32 + dx + (1.1 if i % 2 else -1.1), top + i * 2.5, 2.0) for i in range(6)]),
                   LAV, 2, group=f'fl{dx}', R=1.6))


def rug_pink(s):
    r = ellipse(32, 44, 27, 9)
    s.add(Part('rug', r, PINK, 1, R=4))
    s.add(Part('ring', sub(ellipse(32, 44, 21, 6.4), ellipse(32, 44, 18, 5)), PINK_DOT, 1.2, decal_of='rug',
               line=False, outline=False, group='rug'))


def kilim(s):
    r = rrect(32, 44, 27, 8.6, 1.5)
    s.add(Part('rug', r, RED, 1, R=3))
    s.add(Part('band', sub(rrect(32, 44, 23, 5.6, 0.5), rrect(32, 44, 21.4, 4.2, 0.5)), CREAM, 1.2, decal_of='rug',
               line=False, outline=False, group='rug'))
    for x in range(13, 52, 7):
        s.stamp(x, 42, ['..n..', '.nyn.', 'nyyyn', '.nyn.', '..n..'], FX, on=['rug'])
    for x in range(6, 60, 3):
        s.stamp(x, 53, ['c'], FX)
        s.stamp(x, 34, ['c'], FX)


def rug_cloud(s):
    c = union(ellipse(32, 46, 22, 6.6), circle(16, 43, 6.5), circle(26, 40, 7.5), circle(38, 40, 8), circle(49, 43, 6.5))
    s.add(Part('rug', inter(c, half(y0=33, y1=53)), WHITE, 1, R=4))


def cushion(colors, dots):
    def build(s):
        c = superellipse(32, 50, 21, 7.2, 3)
        s.add(Part('cu', c, colors, 1, R=5))
        pat = (lambda x, y: np.hypot(((x + 2) % 6) - 3, ((y + 1) % 6) - 3) - 1.0) if dots else \
              (lambda x, y: np.abs(((x + 2) % 6) - 3) - 0.9)
        s.add(Part('cd', inter(c, pat), PINK_DOT if dots else WHITE, 1.2, decal_of='cu', line=False,
                   outline=False, group='cu'))
    return build


def basket(s):
    outer = superellipse(32, 49, 24, 8.6, 2.6)
    s.add(Part('basket', outer, WOOD, 1, R=4))
    weave = lambda x, y: np.abs(((x + (y // 3) * 2) % 5) - 2.5) - 0.8
    s.add(Part('weave', inter(outer, weave, half(y0=47)), CREAM, 1.1, decal_of='basket', line=False,
               outline=False, group='basket'))
    s.add(Part('pad', ellipse(32, 45.4, 19.5, 4.2), PINK, 2, R=3))


def lights() -> Image.Image:
    """String lights across the top of the wall, drawn straight onto a wide canvas."""
    w, h = 150, 14
    img = Image.new('RGBA', (w, h))
    px = img.load()
    wire = hexc('#3a2f6e')
    bulbs = ['#ffd84a', '#ff9bb8', '#8fe3f0', '#b3a6f0', '#a8e3a6']
    for x in range(w):
        y = int(round(2 + 3.2 * np.sin(x / w * np.pi * 5) ** 2))
        px[x, y] = wire
        if x % 12 == 6:
            c = hexc(bulbs[(x // 12) % len(bulbs)])
            for dx, dy in [(0, 1), (-1, 2), (0, 2), (1, 2), (-1, 3), (0, 3), (1, 3), (0, 4)]:
                if 0 <= x + dx < w:
                    px[x + dx, y + dy] = c
            px[x, y + 2] = hexc('#ffffff')
    return img


# id -> (slot, unlock day, builder)
ITEMS = {
    'win_wood': ('window', 0, win_wood), 'win_arch': ('window', 30, win_arch), 'win_curtain': ('window', 90, win_curtain),
    'pic_tulip': ('wall', 14, pic_tulip), 'nazar': ('wall', 45, nazar), 'garland': ('wall', 120, garland),
    'lamp': ('light', 0, lamp), 'lights': ('light', 21, None), 'lantern': ('light', 60, lantern),
    'plant': ('plant', 0, plant), 'pot_tulip': ('plant', 7, pot_tulip), 'pot_lavender': ('plant', 75, pot_lavender),
    'rug_pink': ('rug', 3, rug_pink), 'kilim': ('rug', 30, kilim), 'rug_cloud': ('rug', 150, rug_cloud),
    'cushion_pink': ('cushion', 0, cushion(PINK, True)), 'cushion_blue': ('cushion', 10, cushion(TEAL, False)),
    'basket': ('cushion', 100, basket),
}


def render(item_id: str) -> Image.Image:
    slot, day, build = ITEMS[item_id]
    if build is None:
        return lights()
    s = Sprite()
    build(s)
    img = s.render()
    return img.crop(img.getbbox())


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[2]
    dest = root / 'assets' / 'room'
    dest.mkdir(parents=True, exist_ok=True)
    rows = []
    for item_id, (slot, day, _) in ITEMS.items():
        img = render(item_id)
        img.save(dest / f'{item_id}.png', optimize=True)
        rows.append(f"  '{item_id}': RoomItemArt('{item_id}', RoomSlot.{slot}, {day}, {img.width}, {img.height}),")
    dart = ("// GENERATED by tool/pets/room.py — do not edit by hand.\n"
            "part of 'room.dart';\n\n"
            "const Map<String, RoomItemArt> kRoomItems = {\n" + '\n'.join(rows) + "\n};\n")
    (root / 'lib' / 'companion' / 'room_catalog.g.dart').write_text(dart, encoding='utf-8')
    print('wrote', len(rows), 'items')
