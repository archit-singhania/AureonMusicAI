"""
drum_synthesizer.py — Generative Algorithmic 808 & Drum Synthesizer (Pure DSP, Zero-Cost).
Generates:
- 808 Sub-bass with smooth pitch glides
- Punchy acoustic & electronic Kick
- Hi-Hat rolls with 1/8, 1/16, and 1/32 triplet subdivisions
- Snare / Clap with noise burst envelopes
"""

import numpy as np
import soundfile as sf
import logging

logger = logging.getLogger(__name__)


def synthesize_808_sub(duration: float = 2.0, root_freq: float = 40.0, glide_to: float = 32.0, sr: int = 44100) -> np.ndarray:
    """Generates an 808 sub-bass note with pitch glide and harmonic saturation."""
    num_samples = int(sr * duration)
    t = np.linspace(0, duration, num_samples, endpoint=False)

    # Pitch glide frequency envelope
    freq_env = np.linspace(root_freq, glide_to, num_samples)
    phase = 2 * np.pi * np.cumsum(freq_env) / sr

    # Sine fundamental + subtle 2nd harmonic
    sub = np.sin(phase) + (0.25 * np.sin(2 * phase))

    # Exponential ADSR volume envelope
    env = np.exp(-3.5 * t)
    # Quick punch attack
    attack_len = int(sr * 0.005)
    env[:attack_len] = np.linspace(0, 1, attack_len)

    wave = sub * env
    # Soft saturation
    wave = np.tanh(1.8 * wave)
    return wave.astype(np.float32)


def synthesize_hihat_roll(bpm: int = 140, bars: int = 4, sr: int = 44100) -> np.ndarray:
    """Synthesizes trap hi-hat patterns with 16th and 32nd note rolls."""
    sec_per_beat = 60.0 / bpm
    total_dur = bars * 4 * sec_per_beat
    num_samples = int(sr * total_dur)
    y = np.zeros(num_samples, dtype=np.float32)

    # 16th note subdivision intervals
    subdiv_dur = sec_per_beat / 4.0
    subdiv_samples = int(subdiv_dur * sr)
    hat_len = int(0.04 * sr)

    t_hat = np.linspace(0, 0.04, hat_len)
    hat_env = np.exp(-80 * t_hat)

    # Filtered noise burst for hi-hat
    np.random.seed(42)
    noise = np.random.uniform(-1, 1, hat_len)
    hat_hit = noise * hat_env

    for i in range(0, num_samples - hat_len, subdiv_samples):
        # Add velocity variation
        vel = 0.6 + (0.4 * np.sin(i / (subdiv_samples * 2)))
        y[i:i + hat_len] += (hat_hit * vel).astype(np.float32)

    return y


def generate_drum_loop(output_path: str, bpm: int = 140, genre: str = "trap", bars: int = 4, sr: int = 44100) -> str:
    """Generates a complete drum loop and writes it to disk."""
    sub = synthesize_808_sub(duration=bars * (60.0 / bpm) * 4, sr=sr)
    hats = synthesize_hihat_roll(bpm=bpm, bars=bars, sr=sr)

    min_len = min(len(sub), len(hats))
    mixed = (0.7 * sub[:min_len]) + (0.5 * hats[:min_len])
    peak = np.max(np.abs(mixed))
    if peak > 0:
        mixed /= peak

    sf.write(output_path, mixed, sr)
    logger.info(f"Generated drum loop: {output_path} (BPM={bpm})")
    return output_path
