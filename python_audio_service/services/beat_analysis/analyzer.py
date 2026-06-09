import librosa
import numpy as np
import soundfile as sf
from dataclasses import dataclass
from typing import List, Optional
import logging

logger = logging.getLogger(__name__)


@dataclass
class BeatGrid:
    bpm: float
    beat_times: List[float]
    bar_times: List[float]
    beats_per_bar: int
    total_duration: float
    key: Optional[str]
    energy: float
    genre_hint: str


def detect_key(y: np.ndarray, sr: int) -> str:
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr)
    chroma_mean = chroma.mean(axis=1)
    note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    major_profile = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
    minor_profile = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])

    major_corrs = [np.corrcoef(np.roll(major_profile, i), chroma_mean)[0, 1] for i in range(12)]
    minor_corrs = [np.corrcoef(np.roll(minor_profile, i), chroma_mean)[0, 1] for i in range(12)]

    best_major = np.argmax(major_corrs)
    best_minor = np.argmax(minor_corrs)

    if major_corrs[best_major] >= minor_corrs[best_minor]:
        return f"{note_names[best_major]} major"
    else:
        return f"{note_names[best_minor]} minor"


def hint_genre(bpm: float, energy: float) -> str:
    if bpm < 80:
        return "trap"
    elif bpm < 100:
        return "drill"
    elif bpm < 130:
        if energy > 0.6:
            return "rap"
        else:
            return "rnb"
    else:
        return "pop"


def analyze_beat(file_path: str) -> BeatGrid:
    logger.info(f"Analyzing beat: {file_path}")
    y, sr = librosa.load(file_path, sr=None, mono=True)

    tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr, units='frames')
    bpm = float(tempo) if not isinstance(tempo, np.ndarray) else float(tempo[0])
    beat_times = librosa.frames_to_time(beat_frames, sr=sr).tolist()

    beats_per_bar = 4
    bar_times = [beat_times[i] for i in range(0, len(beat_times), beats_per_bar)]

    rms = librosa.feature.rms(y=y)[0]
    energy = float(np.mean(rms) / (np.max(rms) + 1e-8))

    key = detect_key(y, sr)
    total_duration = float(librosa.get_duration(y=y, sr=sr))
    genre_hint = hint_genre(bpm, energy)

    logger.info(f"BPM={bpm:.1f}, Key={key}, Duration={total_duration:.1f}s, Genre={genre_hint}")

    return BeatGrid(
        bpm=bpm,
        beat_times=beat_times,
        bar_times=bar_times,
        beats_per_bar=beats_per_bar,
        total_duration=total_duration,
        key=key,
        energy=energy,
        genre_hint=genre_hint,
    )
