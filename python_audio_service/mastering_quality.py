"""Read-only, bounded mastering diagnostics. Findings are not automatic edits."""
import math
from pathlib import Path
import numpy as np
import soundfile as sf
from scipy import signal
from pydantic import BaseModel, Field


class QualitySettings(BaseModel):
    target_lufs: float = Field(default=-14, ge=-30, le=-5)
    ceiling_dbtp: float = Field(default=-1, ge=-12, le=0)
    silence_seconds: float = Field(default=2, ge=.5, le=30)


def db(value):
    return round(20 * math.log10(value), 3) if value > 1e-12 else None


def analyze(path, settings, check=lambda: None):
    """Up to 20 minutes, mono/stereo; 4x polyphase peak is an estimate."""
    info = sf.info(path)
    if info.channels not in (1, 2) or info.duration < .5 or info.duration > 1200:
        raise ValueError("Analyze mono/stereo audio between 0.5 seconds and 20 minutes.")
    if info.samplerate < 8000 or info.samplerate > 96000:
        raise ValueError("Supported sample rates: 8–96 kHz.")
    if info.frames * info.channels * 4 > 128 * 1024 * 1024:
        raise ValueError("Decoded audio exceeds the 128 MiB analysis budget. Use a shorter master or lower sample rate.")
    check()
    y, rate = sf.read(path, dtype='float32', always_2d=True)
    if not np.isfinite(y).all():
        raise ValueError("Audio contains non-finite samples.")
    peak = 0.0
    clipping = 0
    ranges = []
    silence_start = None
    block_size = max(1, rate // 10)
    for start in range(0, len(y), block_size):
        check()
        block = y[start:start + block_size]
        clipping += int(np.count_nonzero(np.any(np.abs(block) >= 1, axis=1)))
        # Overlap keeps artificial chunk-edge transients out of peak estimates.
        left, right = max(0, start - 64), min(len(y), start + len(block) + 64)
        oversampled = signal.resample_poly(y[left:right], 4, 1, axis=0)
        measured = oversampled[(start-left)*4:(start-left+len(block))*4]
        peak = max(peak, float(np.max(np.abs(measured))))
        silent = float(np.max(np.abs(block))) < .001  # -60 dBFS
        if silent and silence_start is None:
            silence_start = start
        if not silent and silence_start is not None:
            if (start-silence_start)/rate >= settings.silence_seconds:
                ranges.append({"start_sample": silence_start, "end_sample": start})
            silence_start = None
    if silence_start is not None and (len(y)-silence_start)/rate >= settings.silence_seconds:
        ranges.append({"start_sample": silence_start, "end_sample": len(y)})
    check()
    import pyloudnorm
    value = float(pyloudnorm.Meter(rate).integrated_loudness(y))
    lufs = round(value, 3) if math.isfinite(value) else None
    energy = float(np.mean(y.astype('float64') ** 2))
    mono_energy = float(np.mean(y.mean(axis=1, dtype='float64') ** 2))
    mono_loss = round(10*math.log10(max(mono_energy, 1e-20)/energy), 3) if energy > 1e-20 else None
    correlation = None
    if info.channels == 2 and np.std(y[:, 0], dtype='float64') > 1e-9 and np.std(y[:, 1], dtype='float64') > 1e-9:
        measured_correlation = float(np.corrcoef(y[:, 0], y[:, 1])[0, 1])
        correlation = round(measured_correlation, 4) if math.isfinite(measured_correlation) else None
    findings = []
    if clipping:
        findings.append({"code": "clipping", "message": f"{clipping} frames reach or exceed full scale. Inspect the source and lower render gain."})
    peak_db = db(peak)
    if peak_db is not None and peak_db > settings.ceiling_dbtp:
        findings.append({"code": "peak", "message": "Estimated true peak exceeds the selected ceiling. Review gain or limiting in a new render."})
    if lufs is None:
        findings.append({"code": "unmeasurable_loudness", "message": "No gated integrated loudness is measurable; silence is not a zero-LUFS result."})
    elif abs(lufs-settings.target_lufs) > 1:
        findings.append({"code": "loudness", "message": "Integrated loudness differs from the selected target by more than 1 LU."})
    if correlation is not None and correlation < 0:
        findings.append({"code": "phase", "message": "Negative stereo correlation: audition in mono before changing the mix."})
    if mono_loss is not None and mono_loss < -6:
        findings.append({"code": "mono_loss", "message": "Mono fold-down loses more than 6 dB of mean-square energy."})
    if ranges:
        findings.append({"code": "silence", "message": "Long sections below -60 dBFS detected; these may be intentional.", "ranges": ranges})
    check()
    return {"version": 1, "source_name": Path(path).name, "sample_rate": rate, "frames": len(y),
            "profile": settings.model_dump(), "integrated_lufs": lufs, "estimated_true_peak_dbtp": peak_db,
            "clipped_frames": clipping, "stereo_correlation": correlation, "mono_energy_delta_db": mono_loss,
            "findings": findings, "limitations": "4x polyphase true-peak estimate, not certified conformance metering. Silence boundaries use 100 ms windows. Targets are user preferences, not platform certification. Analysis never changes audio."}
