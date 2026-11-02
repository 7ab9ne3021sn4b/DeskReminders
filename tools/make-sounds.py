# Generates Desk Reminders' own notification sounds into DeskReminders/sounds.
# They are synthesized from scratch (no samples), so they're original and MIT licensed like the app.
# Run:  python tools/make-sounds.py      (needs numpy and scipy)
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import fftconvolve, butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'DeskReminders', 'sounds')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def env(n, attack=0.008, decay=1.0):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    a = a * a * (3 - 2 * a)                      # smooth (no click) attack
    return a * np.exp(-t / decay)

def tone(freq, dur, partials, decay, attack=0.008, detune=0.0):
    n = int(dur * SR); t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dmul in partials:
        f = freq * ratio
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / (decay * dmul))
        if detune:
            out += amp * 0.5 * np.sin(2 * np.pi * f * (1 + detune) * t) * np.exp(-t / (decay * dmul))
    return out * env(n, attack, 1e9)

def place(total, sig, at):
    i = int(at * SR); total[i:i + len(sig)] += sig[:len(total) - i]

def room(x, size=0.6, mix=0.18):
    n = int(size * SR); t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / (size / 5))
    sos = butter(2, 3500, 'low', fs=SR, output='sos')   # soft, dark tail
    ir = sosfilt(sos, ir); ir /= np.sqrt(np.sum(ir ** 2))
    wet = fftconvolve(x, ir)[:len(x)]
    return (1 - mix) * x + mix * wet

def finish(x, name, peak=0.5, lowpass=7000):
    sos = butter(2, lowpass, 'low', fs=SR, output='sos')
    x = sosfilt(sos, x)
    x = room(x)
    fade = int(0.25 * SR); x[-fade:] *= np.linspace(1, 0, fade) ** 2
    x = x / np.max(np.abs(x)) * peak                    # about -6 dB: gentle, never harsh
    wavfile.write(os.path.join(OUT, f'{name}.wav'), SR, (x * 32767).astype(np.int16))
    print(f'{name}: {len(x)/SR:.2f}s')

N = lambda m: 440 * 2 ** ((m - 69) / 12)            # MIDI note -> Hz

bell = [(1, 1, 1), (2.0, 0.25, 0.6), (3.0, 0.08, 0.4), (4.2, 0.03, 0.3)]
glass = [(1, 1, 1), (2.32, 0.12, 0.5), (4.25, 0.04, 0.3)]
marimba = [(1, 1, 1), (3.93, 0.18, 0.25), (9.2, 0.03, 0.1)]
kalimba = [(1, 1, 1), (5.4, 0.12, 0.2), (2.0, 0.08, 0.5)]
warm = [(1, 1, 1), (2.76, 0.18, 0.45), (5.4, 0.05, 0.25), (0.5, 0.12, 1.3)]

def soft_chime():                      # two notes, rising a fifth
    x = np.zeros(int(2.0 * SR))
    place(x, tone(N(76), 1.8, bell, 0.55, 0.006), 0.0)
    place(x, tone(N(83), 1.7, bell, 0.6, 0.006), 0.14)
    finish(x, 'Soft chime')

def warm_bell():
    x = np.zeros(int(2.4 * SR))
    place(x, tone(N(72), 2.3, warm, 0.8, 0.01, detune=0.0015), 0.0)
    finish(x, 'Warm bell', lowpass=5000)

def marimba_s():
    x = np.zeros(int(1.4 * SR))
    place(x, tone(N(67), 1.0, marimba, 0.28, 0.004), 0.0)
    place(x, tone(N(72), 1.2, marimba, 0.32, 0.004), 0.12)
    finish(x, 'Marimba')

def glass_s():
    x = np.zeros(int(1.6 * SR))
    place(x, tone(N(93), 1.5, glass, 0.45, 0.004), 0.0)
    finish(x, 'Glass', peak=0.42)

def music_box():
    x = np.zeros(int(1.9 * SR))
    for i, m in enumerate([84, 88, 91, 96]):
        place(x, tone(N(m), 1.2, glass, 0.35, 0.003), i * 0.11)
    finish(x, 'Music box', peak=0.42)

def rising():
    x = np.zeros(int(1.9 * SR))
    for i, m in enumerate([72, 76, 79]):
        place(x, tone(N(m), 1.4, [(1, 1, 1), (2, 0.12, 0.5)], 0.45, 0.02), i * 0.16)
    finish(x, 'Rising', lowpass=4500)

def kalimba_s():
    x = np.zeros(int(1.6 * SR))
    place(x, tone(N(74), 1.3, kalimba, 0.4, 0.003), 0.0)
    place(x, tone(N(81), 1.3, kalimba, 0.4, 0.003), 0.18)
    finish(x, 'Kalimba')

def drop():
    n = int(0.9 * SR); t = np.arange(n) / SR
    f = 520 + 700 * (1 - np.exp(-t / 0.035))           # water drop: quick upward glide
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * env(n, 0.003, 0.12)
    finish(x, 'Water drop', peak=0.45, lowpass=4000)

def soft_ping():
    x = np.zeros(int(1.5 * SR))
    place(x, tone(N(81), 1.4, [(1, 1, 1), (2, 0.06, 0.4)], 0.5, 0.012), 0.0)
    finish(x, 'Soft ping', peak=0.42, lowpass=5000)

for fn in [soft_chime, warm_bell, marimba_s, glass_s, music_box, rising, kalimba_s, drop, soft_ping]:
    fn()
