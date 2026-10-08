# Companion sprites

`pets.py` draws RUYA's six companions as 64×64 pixel art and writes one sprite
sheet per companion to `app/assets/pets/<id>.png` (11 frames in a row, order in
`FRAMES`, mirrored by `CompanionFrames` in `lib/companion/companion.dart`).
`pixel.py` is the small renderer it uses (shape fields, four-tone lighting,
selective outlines, hand-placed face and prop pixels).

```bash
python3 -m venv .venv && .venv/bin/pip install pillow numpy
.venv/bin/python pets.py                 # regenerate assets/pets/
.venv/bin/python pets.py --preview p.png # all frames on light and dark
```

These scripts are the source of the artwork and are licensed like the app (GPL-3.0).
