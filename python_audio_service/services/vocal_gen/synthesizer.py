import os
import logging
from TTS.api import TTS
from typing import List, Dict
import soundfile as sf
import numpy as np

logger = logging.getLogger(__name__)

MODELS_DIR = os.path.join(os.path.dirname(__file__), '../../models')
os.makedirs(MODELS_DIR, exist_ok=True)

_tts_instance = None


def get_tts() -> TTS:
    global _tts_instance
    if _tts_instance is None:
        logger.info("Loading Coqui XTTS-v2 model (first run will download ~2GB)...")
        _tts_instance = TTS("tts_models/multilingual/multi-dataset/xtts_v2")
        logger.info("XTTS-v2 loaded.")
    return _tts_instance


GENRE_SPEAKER_SETTINGS = {
    "trap": {"speed": 0.85, "pitch_shift": -2},
    "drill": {"speed": 0.95, "pitch_shift": -1},
    "rap": {"speed": 1.0, "pitch_shift": 0},
    "rnb": {"speed": 0.90, "pitch_shift": 1},
    "pop": {"speed": 1.05, "pitch_shift": 2},
}


def synthesize_line(
    text: str,
    output_path: str,
    genre: str = "rap",
    speaker_wav: str = None,
) -> str:
    tts = get_tts()
    settings = GENRE_SPEAKER_SETTINGS.get(genre, GENRE_SPEAKER_SETTINGS["rap"])

    kwargs = {
        "text": text,
        "file_path": output_path,
        "language": "en",
        "speed": settings["speed"],
    }

    if speaker_wav and os.path.exists(speaker_wav):
        kwargs["speaker_wav"] = speaker_wav
    else:
        kwargs["speaker"] = "Ana Florence"

    tts.tts_to_file(**kwargs)
    logger.info(f"Synthesized: {output_path}")
    return output_path


def synthesize_all_lines(
    lines: List[str],
    job_id: str,
    temp_dir: str,
    genre: str = "rap",
    speaker_wav: str = None,
) -> List[str]:
    paths = []
    for i, line in enumerate(lines):
        out_path = os.path.join(temp_dir, f"{job_id}_line_{i:03d}.wav")
        synthesize_line(line, out_path, genre, speaker_wav)
        paths.append(out_path)
    return paths
