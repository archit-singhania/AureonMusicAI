import os
import logging
from typing import List, Dict, Optional
import soundfile as sf
import numpy as np

from services.vocal_gen.sarvam_service import synthesize_sarvam_vocal, is_sarvam_available

logger = logging.getLogger(__name__)

MODELS_DIR = os.path.join(os.path.dirname(__file__), '../../models')
os.makedirs(MODELS_DIR, exist_ok=True)

_tts_instance = None


def get_tts():
    global _tts_instance
    if _tts_instance is None:
        try:
            from TTS.api import TTS
            logger.info("Loading Coqui XTTS-v2 model (first run will download ~2GB)...")
            _tts_instance = TTS("tts_models/multilingual/multi-dataset/xtts_v2")
            logger.info("XTTS-v2 loaded.")
        except Exception as e:
            logger.warning(f"XTTS-v2 not initialized ({e}). Will use fallback synthesis.")
            _tts_instance = None
    return _tts_instance


GENRE_SPEAKER_SETTINGS = {
    "trap": {"speed": 0.85, "pitch_shift": -2},
    "drill": {"speed": 0.95, "pitch_shift": -1},
    "rap": {"speed": 1.0, "pitch_shift": 0},
    "rnb": {"speed": 0.90, "pitch_shift": 1},
    "pop": {"speed": 1.05, "pitch_shift": 2},
}


def _generate_synthetic_tone_fallback(text: str, output_path: str, duration: float = 2.0, sr: int = 22050):
    """Generate a clean synthetic harmonic melodic vocal wave if no neural model is available offline."""
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)
    # create harmonic pitch series mimicking vocal formant
    f0 = 220.0  # A3
    signal = 0.5 * np.sin(2 * np.pi * f0 * t) + 0.25 * np.sin(2 * np.pi * 2 * f0 * t) + 0.15 * np.sin(2 * np.pi * 3 * f0 * t)
    # Apply ADSR envelope
    envelope = np.ones_like(t)
    attack = int(sr * 0.05)
    release = int(sr * 0.1)
    envelope[:attack] = np.linspace(0, 1, attack)
    envelope[-release:] = np.linspace(1, 0, release)
    signal = signal * envelope
    sf.write(output_path, signal.astype(np.float32), sr)
    logger.info(f"Synthetic fallback generated: {output_path}")


def synthesize_line(
    text: str,
    output_path: str,
    genre: str = "rap",
    speaker_wav: Optional[str] = None,
    preferred_engine: str = "auto",
    language_code: str = "en-IN",
) -> str:
    """
    Synthesize vocal line using Sarvam AI or local XTTS-v2.
    """
    # 1. Try Sarvam AI if requested or available
    if preferred_engine in ["sarvam", "auto"] and is_sarvam_available():
        res = synthesize_sarvam_vocal(text, output_path, genre=genre, language_code=language_code)
        if res and os.path.exists(output_path):
            return output_path

    # 2. Try Coqui XTTS-v2
    tts = get_tts()
    settings = GENRE_SPEAKER_SETTINGS.get(genre, GENRE_SPEAKER_SETTINGS["rap"])

    if tts is not None:
        try:
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
            logger.info(f"Synthesized with XTTS: {output_path}")
            return output_path
        except Exception as e:
            logger.warning(f"XTTS synthesis error: {e}")

    # 3. Offline harmonic fallback
    _generate_synthetic_tone_fallback(text, output_path)
    return output_path


def synthesize_all_lines(
    lines: List[str],
    job_id: str,
    temp_dir: str,
    genre: str = "rap",
    speaker_wav: Optional[str] = None,
    preferred_engine: str = "auto",
    language_code: str = "en-IN",
) -> List[str]:
    paths = []
    for i, line in enumerate(lines):
        out_path = os.path.join(temp_dir, f"{job_id}_line_{i:03d}.wav")
        synthesize_line(
            line,
            out_path,
            genre=genre,
            speaker_wav=speaker_wav,
            preferred_engine=preferred_engine,
            language_code=language_code
        )
        paths.append(out_path)
    return paths
