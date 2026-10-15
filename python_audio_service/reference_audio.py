"""Measured private reference comparisons; recommendations are edits, not judgments."""
from pathlib import Path
import math
import numpy as np
import soundfile as sf
from scipy import signal
import audio_engine as audio

RATE = 44100
BANDS = {"bass": (30, 200), "low_mid": (200, 1000), "high_mid": (1000, 5000), "air": (5000, 18000)}

def measure(samples, rate):
    if len(samples) < int(rate * .5):
        raise ValueError("Reference comparison needs at least half a second of audio.")
    if not np.isfinite(samples).all() or np.max(np.abs(samples)) < 1e-7:
        raise ValueError("Silent or invalid audio cannot be matched.")
    import pyloudnorm
    loudness = float(pyloudnorm.Meter(rate).integrated_loudness(samples))
    if not math.isfinite(loudness):
        raise ValueError("Audio has no measurable integrated loudness.")
    mid = (samples[:, 0] + samples[:, 1]) / 2
    side = (samples[:, 0] - samples[:, 1]) / 2
    rms = float(np.sqrt(np.mean(samples ** 2)))
    frequencies, power = signal.welch(samples, rate, nperseg=min(4096, len(samples)), axis=0)
    power = power.mean(axis=1)
    total = float(power[(frequencies >= 30) & (frequencies < 18000)].sum())
    return {"integrated_lufs": loudness,
            "crest_db": round(20 * math.log10(float(np.abs(samples).max()) / max(rms, 1e-12)), 3),
            "stereo_width": round(float(np.sqrt(np.mean(side ** 2)) / max(np.sqrt(np.mean(mid ** 2)), 1e-9)), 4),
            "bands_percent": {name: round(100 * float(power[(frequencies >= lo) & (frequencies < hi)].sum()) / max(total, 1e-20), 3) for name, (lo, hi) in BANDS.items()},
            "frames": len(samples), "sample_rate": rate}

def compare(master, reference, directory, check=lambda: None):
    directory = Path(directory)
    pairs = []
    for source in (master, reference):
        check()
        y, rate = audio.read_audio(source, sr=RATE)
        pairs.append((y, measure(y, rate)))
    a, b = [pair[1] for pair in pairs]
    # Both auditions share a target; lower it if either sample peak would exceed -1 dBFS.
    target = min(a["integrated_lufs"], b["integrated_lufs"], -14)
    for y, measured in pairs:
        ceiling = measured["integrated_lufs"] - 1 - 20 * math.log10(float(np.abs(y).max()))
        target = min(target, ceiling)
    previews = []
    for index, (y, measured) in enumerate(pairs):
        check()
        path = directory / f"matched-{index}.wav"
        sf.write(path, y * 10 ** ((target - measured["integrated_lufs"]) / 20), RATE, subtype="PCM_24")
        previews.append(str(path))
    gain = float(np.clip(b["integrated_lufs"] - a["integrated_lufs"], -12, 12))
    width = float(np.clip(b["stereo_width"] / max(a["stereo_width"], .01), .5, 1.5)) if a["stereo_width"] >= .01 else 1
    return {"version": 1, "master": a, "reference": b, "audition_lufs": round(target, 3),
            "suggestion": {"gain_db": round(gain, 3), "width": round(width, 3)},
            "explanation": "Gain compares integrated LUFS (bounded to ±12 dB); mid/side width ratio is bounded to 0.5–1.5. Band percentages and crest factor are descriptive, not automatic EQ or quality scores. Mono sources cannot gain new stereo detail.",
            "band_delta_percent": {name: round(b["bands_percent"][name] - a["bands_percent"][name], 3) for name in BANDS}}, previews

def render(source, output, gain_db, width, check=lambda: None):
    y, rate = audio.read_audio(source, sr=RATE)
    output = Path(output)
    try:
        with sf.SoundFile(output, 'w', samplerate=rate, channels=2, subtype='PCM_24') as writer:
            for offset in range(0, len(y), 65536):
                check()
                block = y[offset:offset+65536]
                mid = block.mean(axis=1)
                side = (block[:, 0] - block[:, 1]) * .5 * width
                block = np.column_stack((mid+side, mid-side)) * 10 ** (gain_db/20)
                if not np.isfinite(block).all() or np.abs(block).max() > 1:
                    raise ValueError("Suggested settings exceed headroom. Reduce gain/width and render again.")
                writer.write(block)
        return str(output)
    except BaseException:
        output.unlink(missing_ok=True)
        raise
