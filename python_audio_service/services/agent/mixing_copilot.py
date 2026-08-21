"""
mixing_copilot.py — Conversational AI Mixing Engineer (Zero-Cost DSP Agent).
Translates user natural language mixing feedback into DSP parameters.
"""

import re
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)


def parse_mixing_prompt(prompt: str) -> Dict[str, Any]:
    """
    Analyzes user text/voice mixing instructions and outputs adjustments.
    Example prompts:
    - "Make the bass 3dB louder and add more reverb on the vocals"
    - "Give me heavy Travis Scott autotune and widen the stereo mix"
    - "Clean up the vocal sibilance and add warm vintage tape saturation"
    """
    p = prompt.lower()

    params = {
        "vocal_gain_delta": 0.0,
        "beat_gain_delta": 0.0,
        "reverb_amount": 0.3,
        "saturation_drive": 0.2,
        "delay_mix": 0.2,
        "stereo_width": 0.5,
        "retune_speed": 0.1,
        "de_esser": 0.4,
        "action_summary": "Applied custom studio mix adjustments."
    }

    actions = []

    # Bass adjustments
    if "more bass" in p or "boost bass" in p or "heavy 808" in p or "louder bass" in p:
        params["beat_gain_delta"] += 0.2
        actions.append("Boosted 808 & low-end by +2.0dB")
    elif "less bass" in p or "cut bass" in p:
        params["beat_gain_delta"] -= 0.2
        actions.append("Reduced low-end bass by -2.0dB")

    # Vocal presence
    if "vocal louder" in p or "boost vocal" in p or "vocals upfront" in p:
        params["vocal_gain_delta"] += 0.25
        actions.append("Elevated lead vocal presence by +2.5dB")
    elif "vocal quieter" in p or "lower vocals" in p:
        params["vocal_gain_delta"] -= 0.2
        actions.append("Tucked vocals into the pocket (-2.0dB)")

    # Reverb & Space
    if "more reverb" in p or "spacey" in p or "dreamy" in p or "lush" in p:
        params["reverb_amount"] = 0.65
        actions.append("Expanded vocal reverb decay and room space")
    elif "dry" in p or "less reverb" in p:
        params["reverb_amount"] = 0.10
        actions.append("Tightened room reflections (dry upfront vocal)")

    # Auto-Tune / Quantization
    if "travis scott" in p or "hard autotune" in p or "t-pain" in p or "robotic" in p:
        params["retune_speed"] = 0.0
        actions.append("Quantized retune speed to 0ms (Hard Cyberpunk Auto-Tune)")
    elif "natural" in p or "less autotune" in p:
        params["retune_speed"] = 0.8
        actions.append("Set retune speed to gentle acoustic tracking")

    # Tape Saturation & Warmth
    if "vintage" in p or "warm" in p or "tape" in p or "analog" in p or "distortion" in p:
        params["saturation_drive"] = 0.65
        actions.append("Injected analog tape harmonic saturation")

    # Stereo Widener
    if "wide" in p or "stereo" in p or "immersive" in p:
        params["stereo_width"] = 0.85
        actions.append("Expanded spatial stereo imaging to 85%")

    # De-Esser
    if "harsh" in p or "sibilance" in p or "clean vocals" in p or "smooth" in p:
        params["de_esser"] = 0.75
        actions.append("Applied dynamic 5.5kHz de-esser resonance cut")

    if actions:
        params["action_summary"] = " • ".join(actions)
    else:
        params["action_summary"] = "Balanced dynamic range, polished high-end exciter, and mastered to -14 LUFS."

    return params
