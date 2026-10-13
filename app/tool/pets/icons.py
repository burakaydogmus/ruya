"""Launcher icon choices (Settings › Appearance › App icon).

For every choice this writes
  assets/icon/app_<id>.png                          64×64 art for the in-app picker
  android/.../res/drawable-nodpi/ic_app_<id>_fg.png 432×432 adaptive foreground
  android/.../res/mipmap-xxhdpi/ic_app_<id>.png     144×144 icon for Android 7
The companions come from their sprite sheets (first idle frame); the moon and
the tulip are drawn here. Run after pets.py: python tool/pets/icons.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from pixel import Part, Sprite, circle, ellipse, half, hexc, inter, poly, ramp, rrect, sub, tube, union

MOON = ramp('#6a4a08', '#d9a83a', '#f2c95a', '#ffe58a', '#fff6c8', ol='#8a6410')
GREEN = ramp('#1f3d2a', '#3f8a4c', '#58a862', '#7cc784', '#a8e3a6', ol='#2f5c3e')
RED = ramp('#5c1220', '#a81f35', '#d0334a', '#ee5466', '#ff8c96', ol='#7a1a2c')
FX = {'w': hexc('#ffffff'), 'y': hexc('#ffe58a')}

# id: (background, source); a companion id reads the sheet, otherwise a builder below
ICONS = {
    'pamuk': ('#E6DBFF', 'pamuk'),
    'tarcin': ('#FFE2C4', 'tarcin'),
    'lokum': ('#D8F3E6', 'lokum'),
    'ay': ('#2B2560', None),
    'lale': ('#FFE9D6', None),
}


def moon(s: Sprite):
    s.add(Part('moon', sub(circle(31, 33, 20), circle(40, 27, 17.5)), MOON, 1, R=7))
    star = ['..w..', '.www.', 'wwwww', '.www.', '..w..']
    s.stamp(43, 18, star, FX)
    s.stamp(50, 36, ['.y.', 'yyy', '.y.'], FX)
    s.stamp(38, 44, ['w'], FX)
    s.stamp(48, 12, ['y'], FX)


def tulip(s: Sprite):
    s.add(Part('stem', tube([(32, 34), (32, 58)], 1.6, 1.8), GREEN, 1, group='plant', R=1.6))
    s.add(Part('leafl', ellipse(24.5, 46, 4.2, 12, rot=-28), GREEN, 2, group='plant', R=3))
    s.add(Part('leafr', ellipse(39.5, 46, 4.2, 12, rot=28), GREEN, 2, group='plant', R=3))
    cup = union(inter(ellipse(32, 22, 12.5, 14.5), half(y0=12, y1=36)),
                poly([(19.5, 16), (24, 4), (29.5, 16)]),
                poly([(27, 16), (32, 2), (37, 16)]),
                poly([(34.5, 16), (40, 4), (44.5, 16)]))
    s.add(Part('cup', cup, RED, 3, R=7))


def art(icon_id: str, root: Path) -> Image.Image:
    source = ICONS[icon_id][1]
    if source:
        return Image.open(root / 'assets' / 'pets' / f'{source}.png').convert('RGBA').crop((0, 0, 64, 64))
    s = Sprite()
    {'ay': moon, 'lale': tulip}[icon_id](s)
    return s.render()


def centred(img: Image.Image, size: int, limit: int) -> Image.Image:
    """The art's pixels scaled by a whole number to fit `limit`, centred on a transparent square."""
    cut = img.crop(img.getbbox())
    k = max(1, min(limit // cut.width, limit // cut.height))
    big = cut.resize((cut.width * k, cut.height * k), Image.NEAREST)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(big, ((size - big.width) // 2, (size - big.height) // 2))
    return out


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[2]
    res = root / 'android' / 'app' / 'src' / 'main' / 'res'
    for icon_id, (bg, _) in ICONS.items():
        img = art(icon_id, root)
        centred(img, 64, 64).save(root / 'assets' / 'icon' / f'app_{icon_id}.png', optimize=True)
        # adaptive icons keep the middle 66dp of 108dp visible: stay inside 60dp
        centred(img, 432, 240).save(res / 'drawable-nodpi' / f'ic_app_{icon_id}_fg.png', optimize=True)
        legacy = Image.new('RGBA', (144, 144), (0, 0, 0, 0))
        ImageDraw.Draw(legacy).rounded_rectangle((6, 6, 137, 137), radius=30, fill=hexc(bg))
        legacy.alpha_composite(centred(img, 144, 100))
        legacy.save(res / 'mipmap-xxhdpi' / f'ic_app_{icon_id}.png', optimize=True)
    print('wrote', len(ICONS), 'icons')
