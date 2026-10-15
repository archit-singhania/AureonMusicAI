"""Versioned non-destructive sample edits and bounded, cancellable stereo rendering."""
from pathlib import Path
from typing import Literal
import numpy as np
import soundfile as sf
from pydantic import BaseModel, Field, StrictInt, FiniteFloat, model_validator
import audio_engine as audio
from settings import MAX_DURATION

RATE = 44100
LIMIT = RATE * MAX_DURATION

class Point(BaseModel):
    sample: StrictInt = Field(ge=0, le=LIMIT)
    value: FiniteFloat

class Envelope(BaseModel):
    parameter: Literal["volume", "pan"]
    interpolation: Literal["linear", "hold"] = "linear"
    points: list[Point] = Field(min_length=1, max_length=200)

    @model_validator(mode="after")
    def validate_points(self):
        positions = [p.sample for p in self.points]
        if positions != sorted(set(positions)):
            raise ValueError("Control points must have unique increasing sample positions.")
        low, high = (0, 2) if self.parameter == "volume" else (-1, 1)
        if any(not low <= p.value <= high for p in self.points):
            raise ValueError("Automation value is outside the supported parameter range.")
        return self

class Clip(BaseModel):
    id: str = Field(min_length=1, max_length=80)
    asset_id: str = Field(min_length=1, max_length=80)
    start: StrictInt = Field(ge=0, le=LIMIT)
    source_start: StrictInt = Field(default=0, ge=0, le=LIMIT)
    length: StrictInt = Field(ge=1, le=LIMIT)
    repeats: StrictInt = Field(default=1, ge=1, le=16)
    fade_in: StrictInt = Field(default=0, ge=0, le=LIMIT)
    fade_out: StrictInt = Field(default=0, ge=0, le=LIMIT)

    @model_validator(mode="after")
    def bounds(self):
        if self.start + self.length * self.repeats > LIMIT:
            raise ValueError("Arrangement exceeds the supported duration.")
        if self.fade_in + self.fade_out > self.length:
            raise ValueError("Clip fades must fit within the clip.")
        return self

class Track(BaseModel):
    id: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=1, max_length=100)
    gain: FiniteFloat = Field(default=1, ge=0, le=2)
    pan: FiniteFloat = Field(default=0, ge=-1, le=1)
    mute: bool = False
    clips: list[Clip] = Field(default_factory=list, max_length=100)
    automation: list[Envelope] = Field(default_factory=list, max_length=2)

    @model_validator(mode="after")
    def unique(self):
        if len({e.parameter for e in self.automation}) != len(self.automation):
            raise ValueError("Use one envelope per parameter.")
        return self

class Marker(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    sample: StrictInt = Field(ge=0, le=LIMIT)

class Arrangement(BaseModel):
    version: Literal[1] = 1
    sample_rate: Literal[44100] = RATE
    tracks: list[Track] = Field(default_factory=list, max_length=16)
    markers: list[Marker] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def unique_ids(self):
        track_ids = [t.id for t in self.tracks]
        clip_ids = [c.id for t in self.tracks for c in t.clips]
        if len(track_ids) != len(set(track_ids)) or len(clip_ids) != len(set(clip_ids)):
            raise ValueError("Track and clip identifiers must be unique.")
        if len(clip_ids) > 200 or len({c.asset_id for t in self.tracks for c in t.clips}) > 24:
            raise ValueError("Arrangement clip or source limit exceeded.")
        return self

def values(envelope, positions):
    xs = np.array([p.sample for p in envelope.points])
    ys = np.array([p.value for p in envelope.points])
    if envelope.interpolation == "linear":
        return np.interp(positions, xs, ys)
    return ys[np.clip(np.searchsorted(xs, positions, side="right") - 1, 0, len(ys) - 1)]

def render(document, sources, output, check=lambda: None, chunk_size=65536):
    document = Arrangement.model_validate(document)
    clips = [c for t in document.tracks for c in t.clips]
    if not clips:
        raise ValueError("Add at least one audio clip before rendering.")
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    normalized = {}
    handles = {}
    try:
        for index, aid in enumerate(dict.fromkeys(c.asset_id for c in clips)):
            check()
            if aid not in sources:
                raise ValueError("Arrangement source is unavailable.")
            samples, rate = audio.read_audio(sources[aid], sr=RATE)
            path = output.parent / f"source-{index}.float.wav"
            sf.write(path, samples, rate, subtype="FLOAT")
            normalized[aid] = path
            del samples
            handles[aid] = sf.SoundFile(path)
        for clip in clips:
            if clip.source_start + clip.length > handles[clip.asset_id].frames:
                raise ValueError("Clip trim extends beyond the normalized source.")
        end = max(c.start + c.length * c.repeats for c in clips)
        with sf.SoundFile(output, "w", samplerate=RATE, channels=2, subtype="PCM_24") as writer:
            for offset in range(0, end, chunk_size):
                check()
                size = min(chunk_size, end - offset)
                mix = np.zeros((size, 2), dtype=np.float64)
                positions = np.arange(offset, offset + size)
                for track in document.tracks:
                    if track.mute:
                        continue
                    block = np.zeros_like(mix)
                    for clip in track.clips:
                        for repeat in range(clip.repeats):
                            start = clip.start + repeat * clip.length
                            lo, hi = max(offset, start), min(offset + size, start + clip.length)
                            if lo >= hi:
                                continue
                            local = np.arange(lo - start, hi - start)
                            source = handles[clip.asset_id]
                            source.seek(clip.source_start + int(local[0]))
                            data = source.read(hi - lo, dtype="float64", always_2d=True)
                            fade = np.ones(len(local))
                            if clip.fade_in:
                                fade *= np.clip(local / max(1, clip.fade_in - 1), 0, 1)
                            if clip.fade_out:
                                fade *= np.clip((clip.length - 1 - local) / max(1, clip.fade_out - 1), 0, 1)
                            block[lo - offset:hi - offset] += data * fade[:, None]
                    volume = np.full(size, track.gain); pan = np.full(size, track.pan)
                    for envelope in track.automation:
                        if envelope.parameter == "volume": volume *= values(envelope, positions)
                        else: pan = values(envelope, positions)
                    # Balance law: center preserves source amplitude, sides attenuate opposite channel.
                    block[:, 0] *= volume * (1 - np.maximum(0, pan))
                    block[:, 1] *= volume * (1 + np.minimum(0, pan))
                    mix += block
                if not np.isfinite(mix).all():
                    raise ValueError("Arrangement contains invalid rendered samples.")
                if np.max(np.abs(mix)) > 1:
                    raise ValueError("Arrangement exceeds digital headroom. Lower track gains and render again.")
                writer.write(mix)
        return str(output)
    except BaseException:
        output.unlink(missing_ok=True)
        raise
    finally:
        for handle in handles.values(): handle.close()
        for path in normalized.values(): path.unlink(missing_ok=True)
