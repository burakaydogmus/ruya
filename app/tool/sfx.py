"""Synthesises RUYA's four tiny interface sounds (16-bit mono WAV, 22.05 kHz).

They are generated here rather than downloaded, so there is no third-party
licence to track. Run: python tool/sfx.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050


def tone(freq, ms, vol=0.35, decay=6.0, vibrato=0.0):
    n = int(RATE * ms / 1000)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t) * min(1.0, i / (RATE * 0.004))
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 24 * t))
        out.append(vol * env * (math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t)))
    return out


def silence(ms):
    return [0.0] * int(RATE * ms / 1000)


def write(path, samples):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))


if __name__ == '__main__':
    dest = Path(__file__).resolve().parents[1] / 'android' / 'app' / 'src' / 'main' / 'res' / 'raw'
    dest.mkdir(parents=True, exist_ok=True)
    write(dest / 'sfx_select.wav', tone(1320, 45, vol=0.22, decay=40))
    write(dest / 'sfx_save.wav', tone(784, 70, decay=14) + tone(1175, 130, decay=12))
    write(dest / 'sfx_celebrate.wav', tone(784, 80, decay=10) + tone(988, 80, decay=10) + tone(1175, 80, decay=10)
          + tone(1568, 220, decay=8))
    write(dest / 'sfx_pet.wav', tone(196, 260, vol=0.3, decay=5, vibrato=0.08))
    print('wrote sounds to', dest)
