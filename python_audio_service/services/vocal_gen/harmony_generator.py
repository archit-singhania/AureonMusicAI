"""
harmony_generator.py — Multi-Singer Duet & Vocal Harmony Generator (Pure DSP, Zero-Cost).
Creates:
- High Harmony (Major 3rd / Perfect 5th pitch shifted layer)
- Sub-Octave Thickener (-12 semitones sub-layer)
- Stereo Vocal Double (Micro-pitch detuned & panned wide)
- Whisper / Breathy Double Layer
"""

import numpy as np
import soundfile as sf
import librosa
import logging
from typing import Dict, List, Optional
from services.pitch_correction.corrector import pitch_shift_clip

logger = logging.getLogger(__name__)


def generate_backing_harmonies(
    vocal_audio_path: str,
    output_dir: str,
    job_id: str,
    key_scale: str = "minor",
    sr: int = 22050
) -> Dict[str, str]:
    """
    Generates 3 vocal harmony layers from a main vocal track:
    1. High 3rd/5th harmony
    2. Sub-octave low bass harmony
    3. Wide stereo double with micro-chorus
    """
    y_lead, _ = librosa.load(vocal_audio_path, sr=sr, mono=True)

    paths = {
        "high_harmony": f"{output_dir}/{job_id}_harmony_high.wav",
        "low_harmony": f"{output_dir}/{job_id}_harmony_low.wav",
        "stereo_double": f"{output_dir}/{job_id}_vocal_double.wav",
    }

    # 1. High Harmony (+3 or +4 semitones depending on scale)
    shift_high = 3 if key_scale.lower() == "minor" else 4
    y_high = pitch_shift_clip(y_lead, sr, shift_high) * 0.45

    # 2. Low Harmony (-12 semitones sub-octave)
    y_low = pitch_shift_clip(y_lead, sr, -12) * 0.35

    # 3. Micro-pitch stereo double (+15 cents & -15 cents detuned)
    y_detune_left = pitch_shift_clip(y_lead, sr, 0.15) * 0.4
    y_detune_right = pitch_shift_clip(y_lead, sr, -0.15) * 0.4
    y_double_stereo = np.vstack([y_detune_left, y_detune_right])

    sf.write(paths["high_harmony"], y_high, sr)
    sf.write(paths["low_harmony"], y_low, sr)
    sf.write(paths["stereo_double"], y_double_stereo.T, sr)

    logger.info(f"Generated backing harmonies for job {job_id}")
    return paths
