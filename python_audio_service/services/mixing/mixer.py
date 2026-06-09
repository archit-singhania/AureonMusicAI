import os
import subprocess
import numpy as np
import soundfile as sf
import logging
from typing import Optional

logger = logging.getLogger(__name__)

GENRE_MIX_SETTINGS = {
    "trap": {
        "vocal_gain": 1.2,
        "beat_gain": 0.85,
        "reverb": "reverb -w 40 -R 60 -r 20",
        "eq": "equalizer 200 0.5q -3 equalizer 4000 1.0q +2",
        "compression": "compand 0,1 6:-70,-60,-20 -5 -90 0.2",
    },
    "drill": {
        "vocal_gain": 1.3,
        "beat_gain": 0.80,
        "reverb": "reverb -w 20 -R 40 -r 10",
        "eq": "equalizer 300 0.5q -2 equalizer 5000 1.0q +3",
        "compression": "compand 0,0.5 6:-70,-60,-20 -5 -90 0.1",
    },
    "rap": {
        "vocal_gain": 1.1,
        "beat_gain": 0.9,
        "reverb": "reverb -w 30 -R 50 -r 15",
        "eq": "equalizer 250 0.5q -2 equalizer 3500 1.0q +2",
        "compression": "compand 0,0.5 6:-70,-60,-20 -5 -90 0.15",
    },
    "rnb": {
        "vocal_gain": 1.0,
        "beat_gain": 0.95,
        "reverb": "reverb -w 50 -R 80 -r 30",
        "eq": "equalizer 400 0.7q -1 equalizer 8000 1.0q +1",
        "compression": "compand 0,1 6:-70,-60,-20 -5 -90 0.3",
    },
    "pop": {
        "vocal_gain": 1.15,
        "beat_gain": 0.88,
        "reverb": "reverb -w 35 -R 55 -r 20",
        "eq": "equalizer 300 0.5q -2 equalizer 6000 1.0q +3",
        "compression": "compand 0,0.5 6:-70,-60,-20 -5 -90 0.2",
    },
}


def save_vocal_array(y: np.ndarray, sr: int, path: str):
    y_norm = y / (np.max(np.abs(y)) + 1e-8)
    sf.write(path, y_norm, sr)
    logger.info(f"Vocal saved: {path}")


def mix_with_ffmpeg(
    vocal_path: str,
    beat_path: str,
    output_path: str,
    genre: str = "rap",
    beat_start_offset: float = 0.0,
) -> str:
    settings = GENRE_MIX_SETTINGS.get(genre, GENRE_MIX_SETTINGS["rap"])
    vg = settings["vocal_gain"]
    bg = settings["beat_gain"]

    processed_vocal = vocal_path.replace(".wav", "_processed.wav")
    sox_cmd = [
        "sox", vocal_path, processed_vocal,
        "norm", "-3",
        *settings["compression"].split(),
        *settings["eq"].split(),
        *settings["reverb"].split(),
    ]
    try:
        subprocess.run(sox_cmd, check=True, capture_output=True)
        final_vocal = processed_vocal
    except Exception as e:
        logger.warning(f"SoX processing failed ({e}), using raw vocal")
        final_vocal = vocal_path

    cmd = [
        "ffmpeg", "-y",
        "-i", beat_path,
        "-i", final_vocal,
        "-filter_complex",
        f"[0:a]volume={bg}[beat];[1:a]volume={vg}[vocal];[beat][vocal]amix=inputs=2:duration=longest[out]",
        "-map", "[out]",
        "-ar", "44100",
        "-ac", "2",
        "-c:a", "libmp3lame",
        "-b:a", "192k",
        output_path,
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        logger.error(f"FFmpeg error: {result.stderr}")
        raise RuntimeError(f"FFmpeg mixing failed: {result.stderr}")

    logger.info(f"Mixed output: {output_path}")
    return output_path
