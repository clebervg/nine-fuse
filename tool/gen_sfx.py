"""Gera efeitos sonoros sintéticos (protótipo) para o NineFuse.

Uso: python3 -I tool/gen_sfx.py <pasta_saida>
Os nomes de saída são internos; o mapeamento para assets/audio/sfx está no
README daquela pasta (ex.: tap -> select, win -> victory, swap -> button_tap).
Gera WAV 44.1kHz mono 16-bit; a conversão para o formato final é feita fora.
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

SR = 44100
rng = random.Random(9)


def env(t, dur, attack=0.005, release=None):
    release = release if release is not None else dur * 0.6
    if t < attack:
        return t / attack
    rest = dur - t
    if rest < release:
        return max(rest / release, 0.0)
    return 1.0


def tone(freq_fn, dur, wave_fn="sine", vol=0.5, attack=0.005, release=None):
    out = []
    phase = 0.0
    n = int(SR * dur)
    for i in range(n):
        t = i / SR
        f = freq_fn(t)
        phase += 2 * math.pi * f / SR
        if wave_fn == "sine":
            s = math.sin(phase)
        elif wave_fn == "tri":
            s = 2 / math.pi * math.asin(math.sin(phase))
        elif wave_fn == "square":
            s = 0.6 if math.sin(phase) >= 0 else -0.6
        else:  # sine + 2nd harmonic, "bell"
            s = 0.7 * math.sin(phase) + 0.3 * math.sin(2.01 * phase)
        out.append(s * vol * env(t, dur, attack, release))
    return out


def noise(dur, vol=0.4, lowpass=0.3, release=None):
    out, prev = [], 0.0
    n = int(SR * dur)
    for i in range(n):
        t = i / SR
        prev = prev + lowpass * (rng.uniform(-1, 1) - prev)
        out.append(prev * vol * env(t, dur, 0.002, release))
    return out


def mix(*tracks, offsets=None):
    offsets = offsets or [0] * len(tracks)
    length = max(int(o * SR) + len(tr) for tr, o in zip(tracks, offsets))
    out = [0.0] * length
    for tr, o in zip(tracks, offsets):
        start = int(o * SR)
        for i, s in enumerate(tr):
            out[start + i] += s
    return out


def seq(notes, step, dur, **kw):
    """Arpejo: lista de frequências, uma a cada `step` segundos."""
    return mix(*[tone(lambda t, f=f: f, dur, **kw) for f in notes],
               offsets=[i * step for i in range(len(notes))])


def save(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = min(1.0, 0.89 / peak)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767))
            for s in samples))


C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0

SOUNDS = {
    # Toque / seleção: clique curto e seco.
    "tap": lambda: tone(lambda t: 1800, 0.035, "tri", 0.4, release=0.03),
    "swap": lambda: tone(lambda t: 500 + 900 * t / 0.09, 0.09, "tri", 0.45),
    "invalid": lambda: mix(
        tone(lambda t: 220 - 60 * t, 0.16, "square", 0.25),
        tone(lambda t: 180 - 50 * t, 0.16, "square", 0.2), offsets=[0, 0.07]),
    "fusion": lambda: mix(
        tone(lambda t: 600 + 500 * t / 0.12, 0.12, "sine", 0.4),
        tone(lambda t: E6, 0.25, "bell", 0.3), offsets=[0, 0.08]),
    "combo": lambda: seq([C5, E5, G5, C6], 0.06, 0.18, wave_fn="bell", vol=0.35),
    "nine": lambda: mix(
        seq([G5, C6, E6, G6], 0.07, 0.35, wave_fn="bell", vol=0.3),
        tone(lambda t: 110, 0.5, "sine", 0.45, release=0.45)),
    "super_nine": lambda: mix(
        seq([C5, G5, C6, E6, G6, C6 * 2], 0.06, 0.4, wave_fn="bell", vol=0.28),
        tone(lambda t: 300 + 1500 * t / 0.5, 0.5, "tri", 0.15)),
    "nova": lambda: mix(
        noise(0.9, 0.55, 0.08, release=0.85),
        tone(lambda t: 70 + 30 * math.exp(-4 * t), 0.9, "sine", 0.6, release=0.8),
        seq([C6, E6, G6], 0.08, 0.5, wave_fn="bell", vol=0.25), offsets=[0, 0, 0.1]),
    "obstacle_break": lambda: mix(
        noise(0.18, 0.5, 0.6, release=0.16),
        tone(lambda t: 2400 - 1200 * t / 0.15, 0.15, "tri", 0.15)),
    "hammer": lambda: mix(
        tone(lambda t: 140 * math.exp(-6 * t) + 60, 0.3, "sine", 0.7, release=0.28),
        noise(0.12, 0.45, 0.4, release=0.1)),
    "bomb": lambda: mix(
        noise(0.7, 0.7, 0.05, release=0.65),
        tone(lambda t: 90 * math.exp(-3 * t) + 40, 0.7, "sine", 0.6, release=0.6)),
    "brush": lambda: mix(
        noise(0.25, 0.2, 0.9, release=0.2),
        tone(lambda t: 700 + 800 * t / 0.25, 0.25, "sine", 0.3)),
    "spin_tick": lambda: tone(lambda t: 2600, 0.02, "square", 0.25, release=0.018),
    "spin_prize": lambda: seq([C5, E5, G5, C6, E6, G6], 0.07, 0.4,
                              wave_fn="bell", vol=0.3),
    "win": lambda: mix(
        seq([C5, E5, G5], 0.11, 0.25, wave_fn="bell", vol=0.32),
        seq([C6, E6, G6, C6 * 2], 0.0, 0.8, wave_fn="bell", vol=0.18),
        offsets=[0, 0.36]),
    "lose": lambda: seq([G5 / 2, 392 * 0.9, 349.2 * 0.85, 261.6 * 0.8], 0.18, 0.4,
                        wave_fn="tri", vol=0.3),
    "coin": lambda: mix(tone(lambda t: 1975.5, 0.08, "square", 0.22, release=0.05),
                        tone(lambda t: 2637, 0.3, "square", 0.22, release=0.25),
                        offsets=[0, 0.07]),
}


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in SOUNDS.items():
        save(out / f"{name}.wav", fn())
        print(name)


if __name__ == "__main__":
    main()
