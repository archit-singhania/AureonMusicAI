import os
import numpy as np
import soundfile as sf
import librosa
import logging
from typing import List, Dict

logger = logging.getLogger(__name__)


def time_stretch_clip(y: np.ndarray, sr: int, target_duration: float) -> np.ndarray:
    current_duration = len(y) / sr
    if current_duration < 0.01:
        return y
    rate = current_duration / target_duration
    rate = np.clip(rate, 0.5, 2.0)
    try:
        import pyrubberband as pyrb
        stretched = pyrb.time_stretch(y, sr, 1.0 / rate)
    except Exception:
        stretched = librosa.effects.time_stretch(y, rate=rate)
    return stretched


def pitch_shift_clip(y: np.ndarray, sr: int, semitones: float) -> np.ndarray:
    if semitones == 0:
        return y
    try:
        import pyrubberband as pyrb
        return pyrb.pitch_shift(y, sr, semitones)
    except Exception:
        return librosa.effects.pitch_shift(y, sr=sr, n_steps=semitones)


def autotune_clip(y: np.ndarray, sr: int, key_note: str = "C") -> np.ndarray:
    major_scale_semitones = [0, 2, 4, 5, 7, 9, 11]
    note_to_semitone = {
        'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4,
        'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9,
        'A#': 10, 'B': 11
    }
    root = note_to_semitone.get(key_note.split()[0], 0)
    scale_notes = set((root + s) % 12 for s in major_scale_semitones)

    f0, voiced_flag, _ = librosa.pyin(
        y,
        fmin=librosa.note_to_hz('C2'),
        fmax=librosa.note_to_hz('C7'),
        sr=sr,
    )

    if f0 is None or not np.any(voiced_flag):
        return y

    corrected = y.copy()
    hop_length = 512
    frame_length = 2048

    for i, (freq, voiced) in enumerate(zip(f0, voiced_flag)):
        if not voiced or freq is None or np.isnan(freq):
            continue
        midi = librosa.hz_to_midi(freq)
        note_class = int(round(midi)) % 12
        if note_class not in scale_notes:
            closest = min(scale_notes, key=lambda n: min(abs(n - note_class), 12 - abs(n - note_class)))
            shift = closest - note_class
            if shift > 6:
                shift -= 12
            elif shift < -6:
                shift += 12
            start = i * hop_length
            end = min(start + frame_length, len(corrected))
            clip = corrected[start:end]
            if len(clip) > 0:
                try:
                    import pyrubberband as pyrb
                    corrected[start:end] = pyrb.pitch_shift(clip, sr, shift)[:end - start]
                except Exception:
                    pass

    return corrected


def align_vocals_to_beat(
    vocal_paths: List[str],
    timings: List[Dict],
    total_duration: float,
    sr: int = 22050,
) -> np.ndarray:
    output = np.zeros(int(total_duration * sr) + sr)

    for line_data, vocal_path in zip(timings, vocal_paths):
        if not os.path.exists(vocal_path):
            logger.warning(f"Missing vocal file: {vocal_path}")
            continue

        y_line, file_sr = librosa.load(vocal_path, sr=sr, mono=True)
        syl_timings = line_data.get("syllable_timings", [])

        if not syl_timings:
            continue

        line_start = syl_timings[0]["start"]
        line_end = syl_timings[-1]["start"] + syl_timings[-1]["duration"]
        target_duration = line_end - line_start

        if target_duration > 0.1:
            y_line = time_stretch_clip(y_line, sr, target_duration)

        start_sample = int(line_start * sr)
        end_sample = start_sample + len(y_line)

        if end_sample > len(output):
            end_sample = len(output)
            y_line = y_line[:end_sample - start_sample]

        output[start_sample:end_sample] += y_line

    return output
