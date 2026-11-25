#!/usr/bin/env python3
"""Renders the game's theme, project/audio/farm_theme.wav (D-173 to D-178).

Upbeat melodic techno, an original piece in A minor at 126 bpm, 32 bars (about
61 s): four-on-the-floor kick, clap on 2 and 4, off-beat open hats, a rolling
sixteenth bass, a plucked arpeggio, supersaw chord stabs and a lead, all
ducked by the kick (a sidechain pump). It opens with a soft pad and arp swell (no kick for four bars), brings in the
beat, then the bass, drops, breaks down with a riser, drops again with the lead
and fades back to the swell so the loop comes round gently. Everything is synthesised with numpy, so it is reproducible and
carries no third-party licence. The relaxed groove is tools/make_music_groove.py.

    python3 tools/make_music.py        (needs numpy)
After changing it, run `godot --headless --import` in project/ before playing.
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
BPM = 126
BEAT = 60.0 / BPM
S16 = BEAT / 4
EIGHTH = BEAT / 2
BAR = BEAT * 4
BARS = 32
OUT = Path(__file__).resolve().parent.parent / "project" / "audio" / "farm_theme.wav"

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

def midi(name):
    n = NAMES[name[0]]
    rest = name[1:]
    if rest[0] == "#":
        n += 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + n

def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)

# Four-bar loop: i, VI, III, VII. Bass root, chord triad.
CHORDS = [
    ("A1", ["A3", "C4", "E4"]),
    ("F1", ["F3", "A3", "C4"]),
    ("C2", ["E3", "G3", "C4"]),
    ("G1", ["D4", "G3", "B3"]),
]
LEAD = [
    "E5 - - G5 - A5 - -",
    "C6 - A5 - F5 - A5 -",
    "G5 - E5 - G5 - C6 -",
    "B5 - D6 - B5 - G5 -",
]

# What plays in each bar (0 to 31).
def layers(bar):
    return {
        # A soft opening: pad and arp swell in, the hats tick in, the kick joins at bar 4.
        "kick": 4 <= bar < 30 and not 16 <= bar < 20,
        "hat": 2 <= bar < 30 and not 18 <= bar < 20,
        "clap": 8 <= bar < 16 or 20 <= bar < 30,
        "bass": 8 <= bar < 16 or 20 <= bar < 30,
        "arp": bar < 4 or 8 <= bar < 30,
        "swell": bar < 8 or bar >= 30,
        "pad": 8 <= bar < 30,
        "lead": 12 <= bar < 16 or 24 <= bar < 30,
        "riser": 16 <= bar < 20,
    }

def env(n, attack, release, decay=0.0):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(attack, 1e-4))
    r = np.clip((n / SR - t) / max(release, 1e-4), 0, 1)
    return e * r * np.exp(-decay * t)

def saw(freq, n, harmonics, rolloff=1.0, detune=0.0):
    t = np.arange(n) / SR
    ph = 2 * np.pi * freq * (1 + detune) * t
    return sum(np.sin(h * ph) / h ** rolloff for h in range(1, harmonics + 1))

def kick():
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    f = 46 + 130 * np.exp(-t * 34)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11)
    click = np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 300) * 0.3
    return body + click

def clap(rng):
    n = int(SR * 0.22)
    t = np.arange(n) / SR
    noise = np.diff(rng.standard_normal(n + 1))
    bursts = sum(np.exp(-np.clip(t - d, 0, None) * 60) * (t >= d) for d in (0.0, 0.011, 0.022))
    return noise * (bursts * 0.5 + np.exp(-t * 18) * 0.6)

def hat(rng, length):
    n = int(SR * length)
    t = np.arange(n) / SR
    return np.diff(rng.standard_normal(n + 1)) * np.exp(-t * (60 if length < 0.1 else 22))

def bass(freq, dur):
    """Rolling sub: a low saw that closes quickly, plus a clean sine under it."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = saw(freq, n, 7, 1.3) * np.exp(-9 * t) + np.sin(2 * np.pi * freq * t) * 0.9
    return out * env(n, 0.003, 0.02)

def pluck(freq, dur):
    n = int(SR * dur)
    t = np.arange(n) / SR
    return saw(freq, n, 8, 1.1) * np.exp(-16 * t) * env(n, 0.002, 0.02)

def stab(freqs, dur):
    """Supersaw chord stab: detuned saws, a little attack, a short tail."""
    n = int(SR * dur)
    out = np.zeros(n)
    for f in freqs:
        for d in (-0.006, 0.0, 0.006):
            out += saw(f, n, 6, 1.4, d)
    t = np.arange(n) / SR
    return out / len(freqs) * np.exp(-3.5 * t) * env(n, 0.006, 0.08)

def lead(freq, dur):
    n = int(SR * dur)
    t = np.arange(n) / SR
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.2)
    ph = 2 * np.pi * np.cumsum(freq * vib) / SR
    out = sum(np.sin(h * ph) / h ** 1.2 for h in range(1, 6))
    return out * env(n, 0.01, 0.08, decay=0.8)

def swell(freqs, dur):
    """A slow supersaw pad for the opening and the ending: no attack to speak of."""
    n = int(SR * dur)
    out = np.zeros(n)
    for f in freqs:
        for d in (-0.005, 0.0, 0.005):
            out += saw(f, n, 4, 1.8, d)
    return out / len(freqs) * env(n, 1.6, 1.4)

def echo(x, delay, feedback, taps):
    out = x.copy()
    d = int(delay * SR)
    for k in range(1, taps + 1):
        out[k * d:] += x[:len(x) - k * d] * feedback ** k
    return out

def reverb(x, rng, seconds=1.4):
    n = int(SR * seconds)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * 4.5)
    ir = np.convolve(ir, np.ones(6) / 6, mode="same")
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x) + n]
    wet *= np.max(np.abs(x)) / (np.max(np.abs(wet)) + 1e-9)
    out = np.zeros(len(x) + n)
    out[:len(x)] += x * 0.85
    out += wet * 0.25
    return out

def render():
    rng = np.random.default_rng(178)
    total = int(SR * BAR * BARS)
    pad_len = SR * 4
    length = total + pad_len
    drums = np.zeros(length)
    low = np.zeros(length)
    mid = np.zeros(length)   # arp, stabs, lead: these get ducked by the kick
    lead_buf = np.zeros(length)
    fx = np.zeros(length)
    duck = np.ones(length)

    def put(buf, sound, at, gain):
        i = int(at * SR)
        if 0 <= i < length:
            buf[i:i + len(sound)] += sound[:length - i] * gain

    kick_sound = kick()
    pump = 1 - 0.8 * np.exp(-np.arange(int(SR * BEAT)) / SR / 0.13)
    for bar in range(BARS):
        t0 = bar * BAR
        on = layers(bar)
        root, triad = CHORDS[bar % 4]
        r = midi(root)
        notes = [midi(n) for n in triad]
        for beat in range(4):
            tb = t0 + beat * BEAT
            if on["kick"]:
                put(drums, kick_sound, tb, 0.95)
                i = int(tb * SR)
                end = min(length, i + len(pump))
                duck[i:end] *= pump[:end - i]
            if on["clap"] and beat in (1, 3):
                put(drums, clap(rng), tb, 0.32)
            if on["hat"]:
                soft = 0.4 if bar < 4 else 1.0
                put(drums, hat(rng, 0.18), tb + EIGHTH, 0.2 * soft)      # open hat on the off-beat
                for q in (0, 2):
                    put(drums, hat(rng, 0.05), tb + q * S16, 0.05 * soft)  # quiet closed hats
        if on["bass"]:
            for s in range(16):
                if s % 4 == 0:
                    continue  # the kick has the beat
                octave = 12 if s % 4 == 3 and bar % 2 == 1 else 0
                put(low, bass(hz(r + octave), S16 * 1.6), t0 + s * S16, 0.45)
        if on["arp"]:
            tones = [notes[0], notes[1], notes[2], notes[0] + 12]
            seq = [0, 1, 2, 3, 2, 1, 0, 1]
            for s in range(16):
                n16 = bar * 16 + s
                ramp = min(1.0, n16 / 64.0) if bar < 4 else 1.0   # fades in over the first four bars
                if bar >= 28:
                    ramp = max(0.0, (30 * 16 - n16) / 32.0)       # and out over the last two
                put(mid, pluck(hz(tones[seq[s % 8]] + 12), 0.3), t0 + s * S16, 0.1 * ramp)
        if on["swell"]:
            put(mid, swell([hz(n) for n in notes], BAR + 1.4), t0, 0.07)
        if on["pad"]:
            for slot in (0, 3, 6):
                put(mid, stab([hz(n) for n in notes], 0.9), t0 + slot * EIGHTH, 0.1)
        if on["lead"]:
            slots = LEAD[bar % 4].split()
            e = 0
            while e < 8:
                if slots[e] in ("-", "."):
                    e += 1
                    continue
                run = 1
                while e + run < 8 and slots[e + run] == "-":
                    run += 1
                put(lead_buf, lead(hz(midi(slots[e])), run * EIGHTH * 0.95), t0 + e * EIGHTH, 0.14)
                e += run
        if on["riser"]:
            n = int(SR * BAR)
            t = np.arange(n) / SR
            progress = ((bar - 16) + t / BAR) / 4.0
            noise = np.diff(rng.standard_normal(n + 1))
            put(fx, noise * progress ** 2 * 0.25, t0, 1.0)
            put(fx, np.sin(2 * np.pi * (200 + 1600 * progress ** 2) * t) * progress * 0.05, t0, 1.0)

    lead_buf = echo(lead_buf, BEAT * 0.75, 0.4, 3)
    melodic = (mid + lead_buf) * duck
    body = low * duck
    mix = reverb(drums + body + melodic + fx, rng)
    tail = mix[total:]
    out = mix[:total].copy()
    out[:len(tail)] += tail   # seamless loop: the tail rings over the start
    out = np.tanh(out * 1.3)
    # Dense music, so level it by its average loudness (-21 dBFS), like the quieter tracks.
    out *= 10 ** (-21 / 20) / np.sqrt(np.mean(out ** 2))
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
