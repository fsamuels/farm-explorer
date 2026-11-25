#!/usr/bin/env python3
"""Renders the relaxed electric-piano groove (D-176), kept as an alternative to the techno theme:, project/audio/farm_theme_groove.wav (D-173, D-174, D-175, D-176).

A relaxed, warm, major-key groove in C at 96 bpm: a Rhodes-style electric piano
(chords and a catchy melody with a light echo), a soft string pad, a round
bass, and a very gentle kick and shaker for a pulse. Everything is synthesised
with numpy, so the track is reproducible and carries no third-party licence.
The reverb tail rings over the start so the loop point is seamless.

    python3 tools/make_music.py        (needs numpy)
After changing it, run `godot --headless --import` in project/ before playing.
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
BPM = 96
BEAT = 60.0 / BPM
EIGHTH = BEAT / 2
BAR = BEAT * 4
OUT = Path(__file__).resolve().parent.parent / "project" / "audio" / "farm_theme_groove.wav"

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

def midi(name):
    """'G4' -> 67, 'F#3' -> 54."""
    n = NAMES[name[0]]
    rest = name[1:]
    if rest[0] == "#":
        n += 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + n

def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)

# Chord: bass note, electric-piano voicing.
CHORDS = {
    "C":  ("C2", ["E3", "G3", "B3", "D4"]),
    "Am": ("A1", ["G3", "C4", "E4", "A4"]),
    "F":  ("F2", ["A3", "C4", "E4", "G4"]),
    "G":  ("G1", ["B3", "D4", "E4", "A4"]),
    "Dm": ("D2", ["F3", "A3", "C4", "E4"]),
    "Em": ("E2", ["G3", "B3", "D4", "F#4"]),
}
SONG = "C Am F G  C Am Dm G  F G Em Am  F Dm G C".split()  # 16 bars, about 40 s

# Melody, 8 eighth-notes a bar: a pitch, '-' to hold, '.' for a rest.
MELODY = [
    "E5 - G5 - - A5 G5 -", "E5 - - C5 - E5 D5 -", "C5 - A4 - C5 - D5 E5", "D5 - - - B4 - D5 -",
    "E5 - G5 - - A5 C6 -", "B5 - A5 - G5 - E5 -", "F5 - E5 D5 - C5 D5 -", "D5 - - G5 - - B4 -",
    "A5 - G5 - E5 - C5 -", "B4 - D5 - G5 - - D5", "E5 - - G5 - B5 A5 -", "G5 - E5 - C5 - A4 -",
    "A4 - C5 - E5 - D5 C5", "D5 - F5 - A5 - G5 F5", "E5 - D5 - B4 - D5 -", "E5 - - - C5 - - -",
]

def env(n, attack, release, decay=0.0):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(attack, 1e-4))
    r = np.clip((n / SR - t) / max(release, 1e-4), 0, 1)
    return e * r * np.exp(-decay * t)

def rhodes(freq, dur, bright=1.0):
    """Electric piano: a two-operator FM tine, a short bell on the attack, a slow tremolo."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    index = (0.9 * bright) * np.exp(-3.5 * t) + 0.25
    tine = np.sin(2 * np.pi * freq * t + index * np.sin(2 * np.pi * freq * t))
    bell = 0.22 * bright * np.sin(2 * np.pi * freq * 7.0 * t + 0.5) * np.exp(-14 * t)
    body = 0.35 * np.sin(2 * np.pi * freq * 0.5 * t) * np.exp(-2.5 * t)
    trem = 1 + 0.08 * np.sin(2 * np.pi * 4.6 * t)
    return (tine + bell + body) * trem * np.exp(-1.6 * t) * env(n, 0.004, 0.3)

def bass(freq, dur):
    """Round and mellow: a sine with a little triangle-ish second harmonic."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(4 * np.pi * freq * t) * np.exp(-4 * t)
    return out * env(n, 0.012, 0.12, decay=1.4)

def pad(freqs, dur):
    """Soft strings far in the back: detuned low-passed saws, a slow swell."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for detune in (-0.003, 0.0, 0.003):
            ph = 2 * np.pi * f * (1 + detune) * t
            out += sum(np.sin(h * ph) / h ** 1.8 for h in range(1, 5))
    swell = np.minimum(1.0, t / 1.0) * np.clip((dur - t) / 1.4, 0, 1)
    return out * swell / len(freqs)

def kick():
    n = int(SR * 0.22)
    t = np.arange(n) / SR
    f = 48 + 70 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 16)

def shaker(rng):
    n = int(SR * 0.07)
    t = np.arange(n) / SR
    noise = np.diff(rng.standard_normal(n + 1))
    return noise * np.exp(-t * 55) * np.minimum(1.0, t / 0.004)

def echo(x, delay, feedback, taps):
    out = x.copy()
    d = int(delay * SR)
    for k in range(1, taps + 1):
        out[k * d:] += x[:len(x) - k * d] * feedback ** k
    return out

def reverb(x, seconds=2.4, rng=None):
    """Convolve with decaying noise (a soft room), by FFT."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * 3.0)
    ir = np.convolve(ir, np.ones(8) / 8, mode="same")
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x) + n]
    wet /= np.max(np.abs(wet)) + 1e-9
    wet *= np.max(np.abs(x))
    out = np.zeros(len(x) + n)
    out[:len(x)] += x * 0.75
    out += wet * 0.4
    return out

def render():
    rng = np.random.default_rng(176)
    total = int(SR * BAR * len(SONG))
    length = total + SR * 6
    keys = np.zeros(length)
    lead = np.zeros(length)
    low = np.zeros(length)
    drums = np.zeros(length)

    def put(buf, sound, at, gain, loose=0.008):
        at += rng.normal(0, loose)
        i = max(0, int(at * SR))
        buf[i:i + len(sound)] += sound * gain * rng.uniform(0.88, 1.0)

    for b, name in enumerate(SONG):
        t0 = b * BAR
        bass_note, voicing = CHORDS[name]
        put(keys, pad([hz(midi(n)) for n in voicing], BAR + 1.0), t0, 0.05, 0.0)
        # Electric-piano comping: beat 1, the and of 2, and beat 4.
        for slot, gain in ((0, 0.16), (3, 0.12), (6, 0.12)):
            for k, n in enumerate(voicing):
                put(keys, rhodes(hz(midi(n)), 1.4, 0.7), t0 + slot * EIGHTH + k * 0.008, gain)
        # Bass: root on 1, a short root on the and of 2, the fifth up on 4.
        r = midi(bass_note)
        put(low, bass(hz(r), BEAT * 1.6), t0, 0.5)
        put(low, bass(hz(r), BEAT * 0.8), t0 + 3 * EIGHTH, 0.4)
        put(low, bass(hz(r + 7), BEAT * 0.9), t0 + 6 * EIGHTH, 0.32)
        # A very soft pulse: kick on 1 and 3, shaker on every eighth.
        for beat in (0, 2):
            put(drums, kick(), t0 + beat * BEAT, 0.28, 0.0)
        for e in range(8):
            put(drums, shaker(rng), t0 + e * EIGHTH, 0.05 if e % 2 == 0 else 0.09, 0.0)
        # Melody.
        slots = MELODY[b].split()
        e = 0
        while e < 8:
            tok = slots[e]
            if tok in (".", "-"):
                e += 1
                continue
            run = 1
            while e + run < 8 and slots[e + run] == "-":
                run += 1
            put(lead, rhodes(hz(midi(tok)), min(run * EIGHTH + 1.2, 3.0), 1.2), t0 + e * EIGHTH, 0.22)
            e += run

    lead = echo(lead, BEAT * 0.75, 0.38, 3)
    mix = reverb((keys + lead + low + drums)[:total + SR * 2], rng=rng)
    # Seamless loop: everything past the end rings over the beginning.
    tail = mix[total:]
    out = mix[:total].copy()
    out[:len(tail)] += tail
    out = np.tanh(out * 1.2)
    out *= 10 ** (-6 / 20) / np.max(np.abs(out))
    return out

def main():
    audio = render()
    pcm = (audio * 32767).astype("<i2")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    print(f"{OUT} ({len(audio) / SR:.1f} s)")

if __name__ == "__main__":
    sys.exit(main())
