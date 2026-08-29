"""Sintetiza os 5 efeitos sonoros do jogo (8-bit/retro simples) em WAV puro,
sem dependencias externas (so wave+struct da stdlib)."""

import math
import struct
import wave

SAMPLE_RATE = 44100


def square_wave(freq, duration, volume=0.3, duty=0.5):
    n = int(SAMPLE_RATE * duration)
    period = SAMPLE_RATE / freq
    samples = []
    for i in range(n):
        phase = (i % period) / period
        samples.append(volume if phase < duty else -volume)
    return samples


def envelope(samples, attack=0.004, release=0.03):
    n = len(samples)
    a = max(1, int(SAMPLE_RATE * attack))
    r = max(1, int(SAMPLE_RATE * release))
    out = list(samples)
    for i in range(min(a, n)):
        out[i] *= i / a
    for i in range(min(r, n)):
        idx = n - 1 - i
        out[idx] *= i / r
    return out


def note(freq, duration, volume=0.3, attack=0.004, release=0.05, duty=0.5):
    return envelope(square_wave(freq, duration, volume, duty), attack, release)


def chirp(freq_start, freq_end, duration, volume=0.3, attack=0.003, release=0.04):
    """Sweep senoidal (onda mais organica/macia que o square_wave, usado pros
    blips de UI) com acumulo de fase — evita clique/artefato que apareceria
    se recalculasse sin(2*pi*f*t) direto com f variando por amostra."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(n):
        progress = i / n
        freq = freq_start + (freq_end - freq_start) * progress
        phase += 2 * math.pi * freq / SAMPLE_RATE
        samples.append(volume * math.sin(phase))
    return envelope(samples, attack, release)


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)


def mix(a, b):
    n = max(len(a), len(b))
    out = []
    for i in range(n):
        va = a[i] if i < len(a) else 0.0
        vb = b[i] if i < len(b) else 0.0
        out.append(max(-1.0, min(1.0, va + vb)))
    return out


def write_wav(path, samples):
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        f.writeframes(frames)


# --- 1. Tap / coleta de comida: blip curto e agudo, tipo "pop" de moeda ---
tap = concat(
    note(1046.5, 0.045, volume=0.28, attack=0.002, release=0.03),  # C6
    note(1568.0, 0.05, volume=0.22, attack=0.002, release=0.04),  # G6
)
write_wav("tap.wav", tap)

# --- 2. Compra/desbloqueio: arpejo curto de 2 notas ascendente ---
unlock = concat(
    note(523.25, 0.09, volume=0.26, attack=0.003, release=0.03),  # C5
    note(659.25, 0.12, volume=0.28, attack=0.003, release=0.05),  # E5
)
write_wav("unlock.wav", unlock)

# --- 3. Evolucao: fanfarra de 4 notas ascendente, mais "recompensadora" ---
evolve_lead = concat(
    note(523.25, 0.09, volume=0.26, attack=0.003, release=0.02),  # C5
    note(659.25, 0.09, volume=0.27, attack=0.003, release=0.02),  # E5
    note(783.99, 0.09, volume=0.28, attack=0.003, release=0.02),  # G5
    note(1046.50, 0.22, volume=0.32, attack=0.003, release=0.12),  # C6 (sustentada)
)
# Uma segunda voz uma oitava acima na nota final, pra dar "brilho"
sparkle = concat(
    silence(0.27),
    note(2093.0, 0.20, volume=0.12, attack=0.003, release=0.12),  # C7 fraquinho
)
evolve = mix(evolve_lead, sparkle)
write_wav("evolve.wav", evolve)

# --- 4. Clique generico de UI: blip neutro e discreto ---
click = note(700.0, 0.035, volume=0.16, attack=0.001, release=0.02, duty=0.5)
write_wav("click.wav", click)

# --- 5. Reacao ao tocar um dino especifico na lista: "chirp" curto e
# brincalhao, senoidal (mais organico/fofo que os blips quadrados de UI,
# ja que aqui e o "bicho" reagindo, nao um botao) ---
poke = chirp(420.0, 920.0, 0.09, volume=0.22, attack=0.004, release=0.05)
write_wav("poke.wav", poke)

# --- 6. Marco de nivel 100 (primeira vez): fanfarra maior que a de evolucao
# normal, arpejo de 5 notas cobrindo quase duas oitavas + acorde final
# sustentado com uma voz de "brilho" uma oitava acima, pra soar como o
# "cume" da progressao de um dino em vez de mais um levelup qualquer ---
milestone_lead = concat(
    note(523.25, 0.075, volume=0.26, attack=0.003, release=0.02),  # C5
    note(659.25, 0.075, volume=0.27, attack=0.003, release=0.02),  # E5
    note(783.99, 0.075, volume=0.28, attack=0.003, release=0.02),  # G5
    note(1046.50, 0.075, volume=0.30, attack=0.003, release=0.02),  # C6
    note(1318.51, 0.32, volume=0.34, attack=0.004, release=0.16),  # E6 (sustentada)
)
milestone_sparkle = concat(
    silence(0.30),
    note(2637.02, 0.28, volume=0.14, attack=0.004, release=0.16),  # E7 fraquinho
)
milestone = mix(milestone_lead, milestone_sparkle)
write_wav("milestone.wav", milestone)

print("ok: tap.wav unlock.wav evolve.wav click.wav poke.wav milestone.wav")
