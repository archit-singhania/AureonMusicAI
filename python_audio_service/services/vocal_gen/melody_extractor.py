"""
melody_extractor.py — Voice-to-MIDI / Humming-to-Melody Pitch Extractor (Pure DSP, Zero-Cost).
Extracts pitch frequencies (f0) and rhythmic note boundaries from user voice humming.
"""

import numpy as np
import librosa
import logging
from typing import List, Dict

logger = logging.getLogger(__name__)


def extract_melody_notes(audio_path: str, sr: int = 22050) -> List[Dict]:
    """
    Extracts sequence of musical notes and timestamps from humming audio.
    Returns: [{'note': 'D4', 'start': 0.5, 'duration': 0.4, 'midi': 62}, ...]
    """
    try:
        y, _ = librosa.load(audio_path, sr=sr, mono=True)
        f0, voiced_flag, _ = librosa.pyin(
            y,
            fmin=librosa.note_to_hz('C2'),
            fmax=librosa.note_to_hz('C7'),
            sr=sr,
            hop_length=512
        )

        if f0 is None or not np.any(voiced_flag):
            return []

        hop_duration = 512.0 / sr
        notes = []
        current_midi = None
        start_time = 0.0
        duration = 0.0

        for i, (freq, voiced) in enumerate(zip(f0, voiced_flag)):
            t = i * hop_duration
            if voiced and freq is not None and not np.isnan(freq):
                midi_val = int(round(librosa.hz_to_midi(freq)))
                if current_midi is None:
                    current_midi = midi_val
                    start_time = t
                    duration = hop_duration
                elif current_midi == midi_val:
                    duration += hop_duration
                else:
                    if duration > 0.08:  # Filter out transient noise glips
                        note_name = librosa.midi_to_note(current_midi)
                        notes.append({
                            "note": note_name,
                            "midi": current_midi,
                            "start": round(start_time, 3),
                            "duration": round(duration, 3)
                        })
                    current_midi = midi_val
                    start_time = t
                    duration = hop_duration
            else:
                if current_midi is not None:
                    if duration > 0.08:
                        note_name = librosa.midi_to_note(current_midi)
                        notes.append({
                            "note": note_name,
                            "midi": current_midi,
                            "start": round(start_time, 3),
                            "duration": round(duration, 3)
                        })
                    current_midi = None
                    duration = 0.0

        return notes
    except Exception as e:
        logger.warning(f"Melody extraction error: {e}")
        return []
