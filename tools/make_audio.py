#!/usr/bin/env python3
"""Generates the Loot Machine's sound effects as 8-bit-ish WAVs (stdlib only).
Run from the repo root:  python3 tools/make_audio.py
"""
import math, random, struct, wave, os

RATE = 22050
random.seed(3)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def square(f, t):
    return 1.0 if math.sin(2 * math.pi * f * t) >= 0 else -1.0


def tri(f, t):
    p = (f * t) % 1.0
    return 4 * abs(p - 0.5) - 1


def env(t, dur, attack=0.005, release=None):
    release = dur * 0.6 if release is None else release
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def render(name, dur, fn, vol=0.5):
    n = int(RATE * dur)
    frames = bytearray()
    for i in range(n):
        t = i / RATE
        v = max(-1.0, min(1.0, fn(t) * vol))
        frames += struct.pack("<h", int(v * 32767))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))


def notes(seq, step, wave_fn=square, tail=0.0):
    dur = step * len(seq) + tail
    def fn(t):
        k = min(int(t / step), len(seq) - 1)
        lt = t - k * step
        f = seq[k]
        span = step + (tail if k == len(seq) - 1 else 0)
        return 0 if f == 0 else wave_fn(f, t) * env(lt, span, 0.003, span * 0.7)
    return dur, fn


# Lever: a heavy clunk, then a ratchet.
def lever(t):
    clunk = math.sin(2 * math.pi * (90 - 60 * t) * t) * math.exp(-t * 18)
    rat = (random.random() * 2 - 1) * (1.0 if (t * 40) % 1 < 0.25 else 0) * math.exp(-t * 6) * 0.5
    return clunk + rat
render("lever", 0.35, lever, 0.8)

# Reel stop: a short wooden tock.
render("stop", 0.09, lambda t: (tri(520, t) * 0.6 + (random.random() * 2 - 1) * 0.4) * math.exp(-t * 60), 0.7)

# Coin: two-tone ding (pitch-shifted in game for each pattern).
render("coin", 0.28, lambda t: square(1318 if t < 0.05 else 1760, t) * env(t, 0.28, 0.002, 0.24), 0.28)

# Jackpot / big win: rising arpeggio.
d, f = notes([523, 659, 784, 1047, 784, 1047, 1319, 1568], 0.07, square, 0.3)
render("bigwin", d, f, 0.3)

# Layoff: a nasty low buzzer.
render("layoff", 0.7, lambda t: (square(110, t) * 0.6 + square(116, t) * 0.4) * env(t, 0.7, 0.01, 0.3), 0.35)

# Buy: cash register cha-ching.
def buy(t):
    a = (random.random() * 2 - 1) * math.exp(-t * 40) * 0.6
    b = square(2093, t) * env(max(0, t - 0.08), 0.3, 0.002, 0.25) * (1 if t > 0.08 else 0)
    return a + b * 0.5
render("buy", 0.4, buy, 0.45)

# Click: UI tap.
render("click", 0.04, lambda t: square(880, t) * math.exp(-t * 90), 0.3)

# Fired: sad descending notes.
d, f = notes([392, 370, 349, 262], 0.22, tri, 0.4)
render("fired", d, f, 0.55)

# Promoted: fanfare.
d, f = notes([523, 523, 523, 659, 0, 587, 659, 784, 1047], 0.11, square, 0.5)
render("promoted", d, f, 0.3)

# Relic: shimmering chime.
render("relic", 0.9, lambda t: (tri(1568, t) + tri(2093, t * 1.003) * 0.6) * math.exp(-t * 4) * (0.6 + 0.4 * math.sin(t * 60)), 0.35)
print("sounds written to audio/")
