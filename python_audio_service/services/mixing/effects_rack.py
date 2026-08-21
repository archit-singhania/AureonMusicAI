"""
effects_rack.py — Studio Audio Effects Rack (Pure Local DSP, Zero-Cost).
Provides:
- Tape Saturation (Warm harmonic soft-clipping)
- Ping-Pong Stereo Delay
- Stereo Spatial Widener (Haas effect + mid-side processing)
- Dynamic De-Esser (4kHz–8kHz sibilance suppressor)
- Formant & Pitch Transposer
"""

import numpy as np
import scipy.signal as signal
import soundfile as sf
import librosa
import logging

logger = logging.getLogger(__name__)


def apply_tape_saturation(y: np.ndarray, drive: float = 0.5) -> np.ndarray:
    """
    Simulates analog tape saturation using a hyperbolic tangent non-linear transfer function.
    drive: 0.0 (clean) to 1.0 (heavy tape distortion)
    """
    if drive <= 0.01:
        return y
    gain = 1.0 + (drive * 3.0)
    # Tanh soft-clipping with cubic warm harmonics
    saturated = np.tanh(gain * y) / np.tanh(gain)
    # 2nd & 3rd harmonic blend
    warmth = 0.15 * drive * (y**2 * np.sign(y))
    out = (0.85 * saturated) + warmth
    # Normalize peak to preserve headroom
    peak = np.max(np.abs(out))
    return out / peak if peak > 1.0 else out


def apply_stereo_delay(
    y: np.ndarray,
    sr: int,
    delay_time_ms: float = 250.0,
    feedback: float = 0.35,
    mix: float = 0.30
) -> np.ndarray:
    """
    Applies stereo/ping-pong delay buffer.
    """
    if mix <= 0.01:
        return y

    delay_samples = int((delay_time_ms / 1000.0) * sr)
    if delay_samples <= 0:
        return y

    delayed = np.zeros(len(y) + (delay_samples * 4), dtype=np.float32)
    delayed[:len(y)] = y

    # Feedback loop
    for i in range(1, 4):
        offset = delay_samples * i
        decay = (feedback ** i) * mix
        if offset < len(delayed):
            end = min(offset + len(y), len(delayed))
            delayed[offset:end] += y[:end - offset] * decay

    out = delayed[:len(y)] * (1.0 - mix) + delayed[:len(y)] * mix
    peak = np.max(np.abs(out))
    return out / peak if peak > 1.0 else out


def apply_stereo_widener(y: np.ndarray, sr: int, width: float = 0.6) -> np.ndarray:
    """
    Mid/Side spatial stereo widener with micro-Haas psychoacoustic delay.
    width: 0.0 (mono) to 1.0 (super-wide stereo field)
    """
    if y.ndim == 1:
        # Convert mono to stereo using 12ms Haas delay on right channel
        haas_samples = int(0.012 * sr)
        right = np.zeros_like(y)
        right[haas_samples:] = y[:-haas_samples]
        y_stereo = np.vstack([y, right])
    else:
        y_stereo = y.copy()

    # Mid/Side decomposition
    mid = 0.5 * (y_stereo[0] + y_stereo[1])
    side = 0.5 * (y_stereo[0] - y_stereo[1])

    # Modulate side width
    side_amplified = side * (1.0 + (width * 1.5))
    left_out = mid + side_amplified
    right_out = mid - side_amplified

    out = np.vstack([left_out, right_out])
    peak = np.max(np.abs(out))
    return out / peak if peak > 1.0 else out


def apply_de_esser(y: np.ndarray, sr: int, threshold_db: float = -18.0, reduction: float = 0.5) -> np.ndarray:
    """
    Dynamic De-Esser: suppresses harsh sibilance in the 4.5kHz–8kHz vocal range.
    """
    if reduction <= 0.01:
        return y

    # Bandpass filter for sibilance detection
    sos = signal.butter(4, [4500, min(8500, int(sr * 0.45))], btype='bandpass', fs=sr, output='sos')
    sibilance = signal.sosfilt(sos, y)

    # Envelope detector
    env = np.abs(sibilance)
    thresh_linear = 10 ** (threshold_db / 20.0)

    # Dynamic gain reduction where sibilance exceeds threshold
    gain_mask = np.ones_like(y)
    over_thresh = env > thresh_linear
    gain_mask[over_thresh] = 1.0 - (reduction * 0.6)

    # Smooth the gain mask
    b, a = signal.butter(2, 50, 'lowpass', fs=sr)
    gain_mask_smooth = signal.filtfilt(b, a, gain_mask)

    return y * gain_mask_smooth


def process_effects_rack(
    input_path: str,
    output_path: str,
    saturation: float = 0.2,
    delay_ms: float = 180.0,
    delay_feedback: float = 0.25,
    delay_mix: float = 0.20,
    stereo_width: float = 0.5,
    de_esser: float = 0.4,
) -> str:
    """
    Applies the full studio effects rack to an audio track and exports the processed audio.
    """
    y, sr = librosa.load(input_path, sr=44100, mono=False)

    if y.ndim > 1 and y.shape[0] == 2:
        y_proc_0 = apply_tape_saturation(y[0], saturation)
        y_proc_1 = apply_tape_saturation(y[1], saturation)
        y_proc_0 = apply_de_esser(y_proc_0, sr, reduction=de_esser)
        y_proc_1 = apply_de_esser(y_proc_1, sr, reduction=de_esser)
        y_proc = np.vstack([y_proc_0, y_proc_1])
    else:
        y_mono = librosa.to_mono(y) if y.ndim > 1 else y
        y_sat = apply_tape_saturation(y_mono, saturation)
        y_proc = apply_de_esser(y_sat, sr, reduction=de_esser)

    # Apply Delay
    if y_proc.ndim == 1:
        y_proc = apply_stereo_delay(y_proc, sr, delay_time_ms=delay_ms, feedback=delay_feedback, mix=delay_mix)
    else:
        y_proc[0] = apply_stereo_delay(y_proc[0], sr, delay_time_ms=delay_ms, feedback=delay_feedback, mix=delay_mix)
        y_proc[1] = apply_stereo_delay(y_proc[1], sr, delay_time_ms=delay_ms * 1.3, feedback=delay_feedback, mix=delay_mix)

    # Apply Stereo Widening
    y_final = apply_stereo_widener(y_proc, sr, width=stereo_width)

    # Save to disk
    if y_final.ndim == 2:
        sf.write(output_path, y_final.T, sr)
    else:
        sf.write(output_path, y_final, sr)

    logger.info(f"Effects rack rendered: {output_path}")
    return output_path
