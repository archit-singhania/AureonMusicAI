"""Measured audio, deterministic music creation, DSP rendering and verified exports.

No pretend model inference: local presets are explicitly algorithmic instruments.
"""

import math
import os
import shutil
import subprocess
from pathlib import Path
import numpy as np
import soundfile as sf
from scipy import signal
from settings import MAX_DURATION

PRESETS = [
    {
        "id": "afterglow",
        "title": "Afterglow",
        "genre": "rnb",
        "bpm": 88,
        "key": "A minor",
        "color": "#9877DE",
        "description": "Velvet keys, pocket drums, warm sub-bass",
    },
    {
        "id": "midnight",
        "title": "Midnight Avenue",
        "genre": "trap",
        "bpm": 140,
        "key": "D minor",
        "color": "#627CF0",
        "description": "Dark pads, crisp hats, sliding low end",
    },
    {
        "id": "daylight",
        "title": "Daylight",
        "genre": "pop",
        "bpm": 120,
        "key": "C major",
        "color": "#DD9474",
        "description": "Bright chords, four-on-the-floor energy",
    },
    {
        "id": "softfocus",
        "title": "Soft Focus",
        "genre": "rap",
        "bpm": 92,
        "key": "G minor",
        "color": "#75A58D",
        "description": "Dusty piano, swung drums, a slow Sunday",
    },
    {
        "id": "northstar",
        "title": "North Star",
        "genre": "drill",
        "bpm": 142,
        "key": "C minor",
        "color": "#AE839F",
        "description": "Syncopated bass and half-time percussion",
    },
]
STEM_NAMES = ("vocals", "drums", "bass", "other")


def ffmpeg():
    configured = os.getenv("FFMPEG_BINARY")
    if configured:
        return configured
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return None


def command(args, timeout=180):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise ValueError("Media processing failed: " + result.stderr[-600:])
    return result


def read_audio(path, sr=44100):
    try:
        y, source_sr = sf.read(str(path), dtype="float32", always_2d=True)
    except Exception:
        binary = ffmpeg()
        if not binary:
            raise ValueError("This audio format needs FFmpeg. Use WAV or FLAC instead.")
        decoded = Path(path).with_suffix(".decoded.wav")
        command(
            [
                binary,
                "-y",
                "-i",
                str(path),
                "-t",
                str(MAX_DURATION + 1),
                "-ar",
                str(sr),
                "-ac",
                "2",
                str(decoded),
            ]
        )
        y, source_sr = sf.read(str(decoded), dtype="float32", always_2d=True)
        decoded.unlink(missing_ok=True)
    if not len(y) or len(y) / source_sr > MAX_DURATION:
        raise ValueError(f"Audio must be between 0 and {MAX_DURATION} seconds.")
    if not np.isfinite(y).all():
        raise ValueError("Audio contains invalid samples.")
    if y.shape[1] == 1:
        y = np.repeat(y, 2, axis=1)
    y = y[:, :2]
    if source_sr != sr:
        gcd = math.gcd(source_sr, sr)
        y = signal.resample_poly(y, sr // gcd, source_sr // gcd, axis=0)
    return y.astype(np.float32), sr


def write_audio(path, y, sr=44100):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    if not np.isfinite(y).all() or not len(y):
        raise ValueError("Rendered audio is invalid.")
    peak = np.max(np.abs(signal.resample_poly(y, 4, 1, axis=0)))
    y = y / max(1.0, peak / 0.89)
    sf.write(str(path), y, sr, subtype="PCM_24")
    return str(path)


def synthesize_preset(preset_id, directory, bars=8, bpm=None, key=None):
    preset = next((p for p in PRESETS if p["id"] == preset_id), None)
    if not preset:
        raise ValueError("Unknown preset.")
    preset = {**preset, "bpm": bpm or preset["bpm"], "key": key or preset["key"]}
    sr, beat = 44100, 60 / preset["bpm"]
    n = int(bars * 4 * beat * sr)
    t = np.arange(n) / sr
    drums, bass, keys = [np.zeros(n, dtype=np.float32) for _ in range(3)]
    rng = np.random.default_rng(
        2026 + next(i for i, p in enumerate(PRESETS) if p["id"] == preset_id)
    )
    notes = {
        "C": 0,
        "C#": 1,
        "D": 2,
        "D#": 3,
        "E": 4,
        "F": 5,
        "F#": 6,
        "G": 7,
        "G#": 8,
        "A": 9,
        "A#": 10,
        "B": 11,
    }
    root = 36 + notes.get(preset["key"].split()[0], 0)
    major = "major" in preset["key"]
    progression = [0, 5, 9 if major else 8, 7]

    def add(target, audio, offset, gain=1):
        start = int(offset * sr)
        end = min(n, start + len(audio))
        if end > start:
            target[start:end] += audio[: end - start] * gain

    for bar in range(bars):
        chord = progression[bar % 4]
        for step in range(4):
            offset = (bar * 4 + step) * beat
            if step in (0, 2) or preset["genre"] == "pop":
                kt = np.arange(int(sr * 0.24)) / sr
                kick = np.sin(
                    2 * np.pi * (48 * kt + 18 * (1 - np.exp(-kt * 30)))
                ) * np.exp(-kt * 18)
                add(drums, kick, offset, 0.7)
            if step in (1, 3):
                st = np.arange(int(sr * 0.14)) / sr
                snare = rng.normal(0, 0.4, len(st)) * np.exp(-st * 26)
                add(drums, snare, offset, 0.6)
            bt = np.arange(int(sr * beat * 0.9)) / sr
            freq = 440 * 2 ** ((root + chord - 69) / 12)
            add(
                bass,
                np.sin(2 * np.pi * freq * bt)
                * np.exp(-bt * 2)
                * np.minimum(bt * 150, 1),
                offset,
                0.45,
            )
        for half in range(8):
            ht = np.arange(int(sr * 0.04)) / sr
            noise = rng.normal(0, 0.13, len(ht))
            noise = noise - signal.lfilter([0.2], [1, -0.8], noise)
            add(drums, noise * np.exp(-ht * 80), (bar * 4 + half * 0.5) * beat, 0.6)
        ct = np.arange(int(sr * beat * 4)) / sr
        envelope = np.minimum(ct * 10, 1) * np.exp(-ct * 0.7)
        for interval in [0, 4 if major else 3, 7, 12]:
            freq = 440 * 2 ** ((root + 24 + chord + interval - 69) / 12)
            add(
                keys,
                (
                    0.8 * np.sin(2 * np.pi * freq * ct)
                    + 0.2 * np.sin(4 * np.pi * freq * ct)
                )
                * envelope,
                bar * 4 * beat,
                0.09,
            )
    stems = {}
    for name, y in [
        ("drums", drums),
        ("bass", bass),
        ("other", keys),
        ("vocals", np.zeros(n)),
    ]:
        stereo = np.column_stack([y, y if name != "other" else np.roll(y, 240)])
        stems[name] = write_audio(Path(directory) / f"{name}.wav", stereo, sr)
    mix = sum(read_audio(p)[0] for p in stems.values())
    path = write_audio(Path(directory) / "beat.wav", mix, sr)
    return path, stems, preset


def separate(path, directory):
    y, sr = read_audio(path)
    mono = y.mean(axis=1)
    import librosa

    harmonic, percussive = librosa.effects.hpss(mono)
    lowpass = signal.butter(4, 220, fs=sr, output="sos")
    highpass = signal.butter(4, 180, "highpass", fs=sr, output="sos")
    arrays = {
        "bass": signal.sosfilt(lowpass, mono),
        "drums": signal.sosfilt(highpass, percussive),
        "other": signal.sosfilt(highpass, harmonic),
        "vocals": np.zeros_like(mono),
    }
    return {
        name: write_audio(
            Path(directory) / f"{name}.wav", np.column_stack([data, data]), sr
        )
        for name, data in arrays.items()
    }, "spectral-dsp"


def metrics(path):
    y, sr = read_audio(path)
    mono = y.mean(axis=1)
    peak = float(np.max(np.abs(y)))
    true_peak = float(np.max(np.abs(signal.resample_poly(y, 4, 1, axis=0))))
    loudness = None
    try:
        import pyloudnorm

        if len(y) > sr * 0.4:
            value = float(pyloudnorm.Meter(sr).integrated_loudness(y))
            loudness = value if math.isfinite(value) else None
    except ImportError:
        pass
    waveform = [
        round(float(np.max(np.abs(part))), 4) if len(part) else 0
        for part in np.array_split(mono, 256)
    ]
    frames = []
    bands = np.geomspace(30, 16000, 25)
    freq = np.fft.rfftfreq(2048, 1 / sr)
    for position in range(0, len(mono), max(1, int(sr * 0.15))):
        frame = mono[position : position + 2048]
        fft = (
            np.abs(
                np.fft.rfft(np.pad(frame, (0, 2048 - len(frame))) * np.hanning(2048))
            )
            / 1024
        )
        frames.append(
            [
                round(
                    float(np.max(fft[(freq >= bands[i]) & (freq < bands[i + 1])]))
                    if np.any((freq >= bands[i]) & (freq < bands[i + 1]))
                    else 0,
                    5,
                )
                for i in range(24)
            ]
        )
    return {
        "duration": round(len(y) / sr, 3),
        "sample_rate": sr,
        "peak_dbfs": round(20 * math.log10(max(peak, 1e-9)), 2),
        "true_peak_dbtp": round(20 * math.log10(max(true_peak, 1e-9)), 2),
        "integrated_lufs": round(loudness, 2) if loudness is not None else None,
        "waveform": waveform,
        "spectrum_frames": frames,
        "spectrum_interval": 0.15,
    }


def analysis(path):
    y, sr = read_audio(path, 22050)
    mono = y.mean(axis=1)
    import librosa

    tempo, frames = librosa.beat.beat_track(y=mono, sr=sr)
    bpm = float(np.asarray(tempo).reshape(-1)[0])
    chroma = librosa.feature.chroma_stft(y=mono, sr=sr).mean(axis=1)
    profiles = [
        (
            "major",
            [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88],
        ),
        (
            "minor",
            [6.33, 2.68, 3.52, 5.38, 2.6, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17],
        ),
    ]
    scores = [
        (float(np.nan_to_num(np.corrcoef(np.roll(profile, i), chroma)[0, 1])), i, mode)
        for mode, profile in profiles
        for i in range(12)
    ]
    score, note, mode = max(scores)
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return {
        "bpm": round(bpm, 1),
        "key": f"{names[note]} {mode}",
        "key_confidence": round(max(0, score), 2),
        "beat_times": librosa.frames_to_time(frames, sr=sr).tolist(),
        "duration": len(mono) / sr,
        "analysis_method": "onset tracking / chroma correlation",
    }


def render_mix(stems, params, output):
    sr = 44100
    tracks = {name: read_audio(path)[0] for name, path in stems.items()}
    length = max(len(track) for track in tracks.values())
    mix = np.zeros((length, 2), dtype=np.float32)
    solo = [name for name in STEM_NAMES if params.get(f"{name}_solo", False)]
    for name, track in tracks.items():
        if params.get(f"{name}_mute", False) or (solo and name not in solo):
            continue
        gain = float(params.get(f"{name}_gain", 0.85 if name == "drums" else 0.8))
        mix[: len(track)] += track * gain
    saturation = float(params.get("saturation", 0.1))
    if saturation > 0:
        drive = 1 + saturation * 3
        mix = np.tanh(mix * drive) / drive
    delay_mix = float(params.get("delay_mix", 0))
    if delay_mix:
        offset = int(float(params.get("delay_ms", 180)) / 1000 * sr)
        dry = mix.copy()
        for echo in range(1, 4):
            start = offset * echo
            if start < length:
                mix[start:] += dry[:-start, ::-1] * delay_mix * 0.4 ** (echo - 1)
    width = float(params.get("stereo_width", 0.5))
    mid, side = mix.mean(axis=1), (mix[:, 0] - mix[:, 1]) / 2 * width * 2
    mix = np.column_stack([mid + side, mid - side])
    reduction = float(params.get("de_esser", 0))
    if reduction:
        band = signal.sosfilt(
            signal.butter(3, [4500, 8500], "bandpass", fs=sr, output="sos"), mix, axis=0
        )
        mix -= band * reduction * 0.55
    try:
        import pyloudnorm

        loudness = pyloudnorm.Meter(sr).integrated_loudness(mix)
        if math.isfinite(loudness):
            mix *= 10 ** ((float(params.get("target_lufs", -14)) - loudness) / 20)
    except ImportError:
        pass
    return write_audio(output, mix, sr)


def export_mp3(source, output):
    binary = ffmpeg()
    if not binary:
        raise ValueError("MP3 export requires FFmpeg; WAV export remains available.")
    command(
        [
            binary,
            "-y",
            "-i",
            str(source),
            "-codec:a",
            "libmp3lame",
            "-b:a",
            "256k",
            str(output),
        ]
    )
    if not Path(output).exists() or Path(output).stat().st_size < 200:
        raise ValueError("MP3 encoding produced no usable media.")
    return str(output)


def video(source, output):
    binary = ffmpeg()
    if not binary:
        raise ValueError("Visualizer export requires FFmpeg.")
    command(
        [
            binary,
            "-y",
            "-i",
            str(source),
            "-filter_complex",
            "color=c=0x171A25:s=720x1280:r=24[bg];[0:a]showwaves=s=640x320:mode=p2p:colors=0xB7A3EE|0xF0BEAA:scale=sqrt[wave];[bg][wave]overlay=40:480[out]",
            "-map",
            "[out]",
            "-map",
            "0:a",
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-crf",
            "24",
            "-c:a",
            "aac",
            "-pix_fmt",
            "yuv420p",
            "-shortest",
            str(output),
        ],
        timeout=300,
    )
    if not Path(output).exists() or Path(output).stat().st_size < 1000:
        raise ValueError("Video encoding produced no usable media.")
    return str(output)
