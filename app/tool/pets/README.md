# Companion art

Everything the companions need is drawn by these scripts; nothing is edited by hand.

* `pixel.py` is the small renderer: shape fields sampled per pixel, four-tone
  lighting, selective outlines, hand-placed face and prop pixels.
* `pets.py` draws the six companions as 64×64 pixel art and writes one sprite
  sheet per companion to `app/assets/pets/<id>.png` (13 frames in a row, order
  in `FRAMES`, mirrored by `CompanionFrames` in `lib/companion/companion.dart`
  and by `PetArt.kt` for the home screen widgets). Accessories are separate
  overlay sheets with only the pixels they change:
  `app/assets/pets/acc/<id>_<accessory>.png`.
* `room.py` draws the furniture for the room (`app/assets/room/`) and writes
  the catalog the app places it with (`lib/companion/room_catalog.g.dart`).
* `icons.py` makes the launcher icon choices (in-app picture, adaptive
  foreground and the Android 7 fallback) from the sheets plus a moon and a tulip.

```bash
python3 -m venv .venv && .venv/bin/pip install pillow numpy
.venv/bin/python pets.py                 # assets/pets/ and assets/pets/acc/
.venv/bin/python pets.py --preview p.png # all frames on light and dark
.venv/bin/python room.py                 # assets/room/ and the Dart catalog
.venv/bin/python icons.py                # launcher icons (run after pets.py)
```

Interface sounds are synthesised by `../sfx.py` into `android/app/src/main/res/raw/`.

These scripts are the source of the artwork and are licensed like the app (GPL-3.0).
