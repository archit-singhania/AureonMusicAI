"""
sarvam_service.py — Sarvam AI integration for Aureon AI Music Studio.
Supports:
- Sarvam Bulbul TTS (high naturalness, multilingual Indian & Global English/Hindi/Hinglish)
- Sarvam Saaras STT (Speech-to-Text for voice prompts and humming transcription)
- Zero-cost fallback to local XTTS-v2 / local engines if API key is not present.
"""

import os
import io
import json
import logging
import base64
import requests
from typing import Optional, Dict, Any, List

logger = logging.getLogger(__name__)

SARVAM_API_KEY = os.environ.get("SARVAM_API_KEY", "")
SARVAM_BASE_URL = "https://api.sarvam.ai"

# Supported Sarvam languages
SUPPORTED_LANGUAGES = {
    "en-IN": "English (Indian)",
    "hi-IN": "Hindi",
    "bn-IN": "Bengali",
    "kn-IN": "Kannada",
    "ml-IN": "Malayalam",
    "mr-IN": "Marathi",
    "od-IN": "Odia",
    "pa-IN": "Punjabi",
    "ta-IN": "Tamil",
    "te-IN": "Telugu",
    "gu-IN": "Gujarati"
}

# Mapping of musical genres to Sarvam voice presets
SARVAM_VOICE_MODES = {
    "trap": {"speaker": "meera", "pace": 0.90, "pitch": -2.0, "language": "hi-IN"},
    "drill": {"speaker": "arvind", "pace": 1.05, "pitch": -1.0, "language": "en-IN"},
    "rap": {"speaker": "arvind", "pace": 1.10, "pitch": 0.0, "language": "en-IN"},
    "rnb": {"speaker": "meera", "pace": 0.85, "pitch": 1.5, "language": "hi-IN"},
    "pop": {"speaker": "ananya", "pace": 1.0, "pitch": 2.0, "language": "en-IN"}
}


def is_sarvam_available() -> bool:
    """Check if Sarvam API key is configured."""
    return bool(SARVAM_API_KEY and SARVAM_API_KEY.strip())


def synthesize_sarvam_vocal(
    text: str,
    output_path: str,
    genre: str = "rap",
    language_code: str = "en-IN",
    speaker: Optional[str] = None
) -> Optional[str]:
    """
    Synthesize vocal line using Sarvam AI Bulbul TTS API.
    Returns output_path on success, or None on failure/fallback.
    """
    if not is_sarvam_available():
        logger.debug("Sarvam API key not set. Skipping Sarvam synthesis.")
        return None

    settings = SARVAM_VOICE_MODES.get(genre.lower(), SARVAM_VOICE_MODES["rap"])
    target_speaker = speaker or settings["speaker"]
    target_lang = language_code or settings["language"]

    headers = {
        "api-subscription-key": SARVAM_API_KEY,
        "Content-Type": "application/json"
    }

    payload = {
        "inputs": [text],
        "target_language_code": target_lang,
        "speaker": target_speaker,
        "pitch": settings["pitch"],
        "pace": settings["pace"],
        "loudness": 1.5,
        "speech_sample_rate": 22050,
        "enable_preprocessing": True,
        "model": "bulbul:v1"
    }

    try:
        logger.info(f"[Sarvam AI] Synthesizing line '{text[:30]}...' ({target_lang})")
        response = requests.post(
            f"{SARVAM_BASE_URL}/text-to-speech",
            headers=headers,
            json=payload,
            timeout=30
        )
        response.raise_for_status()
        data = response.json()

        if "audios" in data and len(data["audios"]) > 0:
            audio_base64 = data["audios"][0]
            audio_bytes = base64.b64decode(audio_base64)
            with open(output_path, "wb") as f:
                f.write(audio_bytes)
            logger.info(f"[Sarvam AI] Saved vocal line to {output_path}")
            return output_path
        else:
            logger.warning(f"[Sarvam AI] Unexpected response format: {data}")
            return None
    except Exception as e:
        logger.warning(f"[Sarvam AI] Synthesis failed: {e}. Falling back to local XTTS-v2.")
        return None


def transcribe_voice_prompt(audio_file_path: str, language_code: str = "unknown") -> Dict[str, Any]:
    """
    Transcribe spoken voice recording / humming to text using Sarvam Saaras STT.
    Falls back gracefully if API key is not present.
    """
    if not is_sarvam_available():
        return {
            "transcript": "Create a high-energy melodic track with deep 808 bass and catchy hook.",
            "language": "en",
            "source": "default_prompt"
        }

    headers = {
        "api-subscription-key": SARVAM_API_KEY
    }

    try:
        with open(audio_file_path, "rb") as f:
            files = {"file": (os.path.basename(audio_file_path), f, "audio/wav")}
            data = {
                "language_code": language_code if language_code != "unknown" else "hi-IN",
                "model": "saaras:v1"
            }
            response = requests.post(
                f"{SARVAM_BASE_URL}/speech-to-text",
                headers=headers,
                files=files,
                data=data,
                timeout=45
            )
            response.raise_for_status()
            res_json = response.json()
            transcript = res_json.get("transcript", "")
            return {
                "transcript": transcript,
                "language": res_json.get("language_code", "en-IN"),
                "source": "sarvam_saaras"
            }
    except Exception as e:
        logger.warning(f"[Sarvam AI] Speech-to-text failed: {e}")
        return {
            "transcript": "",
            "error": str(e),
            "source": "error_fallback"
        }
