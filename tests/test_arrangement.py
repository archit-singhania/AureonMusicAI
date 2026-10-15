"""Measure sample boundaries, automation, cancellation and source preservation."""
import sys
from pathlib import Path
import numpy as np
import pytest
import soundfile as sf
from pydantic import ValidationError
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python_audio_service"))
from arrangement import Arrangement, Envelope, values, render

def document(**clip):
    return {"tracks": [{"id": "track", "name": "Track", "clips": [{"id": "clip", "asset_id": "asset", "start": 5, "source_start": 10, "length": 40, **clip}]}]}

def test_canonical_boundaries_loop_trim_and_source_preservation(tmp_path):
    source = tmp_path / "source.wav"
    sf.write(source, np.column_stack([np.arange(100) / 1000] * 2), 44100, subtype="FLOAT")
    original = source.read_bytes()
    output = render(document(repeats=2), {"asset": source}, tmp_path / "output.wav", chunk_size=13)
    y, sr = sf.read(output)
    assert sr == 44100 and y.shape == (85, 2)
    assert np.allclose(y[:5], 0)
    assert np.allclose(y[5:45, 0], np.arange(10, 50) / 1000, atol=2e-7)
    assert np.allclose(y[45:85], y[5:45])
    assert source.read_bytes() == original and not list(tmp_path.glob("source-*.float.wav"))

def test_automation_interpolation_and_crossfade_render(tmp_path):
    env = Envelope.model_validate({"parameter": "volume", "points": [{"sample": 0, "value": 0}, {"sample": 10, "value": 1}]})
    assert np.allclose(values(env, np.array([0, 5, 10, 20])), [0, .5, 1, 1])
    env.interpolation = "hold"
    assert np.allclose(values(env, np.array([0, 5, 10, 20])), [0, 0, 1, 1])
    source = tmp_path / "source.wav"; sf.write(source, np.ones((100, 2)) * .1, 44100, subtype="FLOAT")
    doc = document(start=0, source_start=0, length=100, fade_in=10, fade_out=10)
    doc["tracks"][0]["automation"] = [{"parameter": "pan", "interpolation": "hold", "points": [{"sample": 0, "value": -1}, {"sample": 50, "value": 1}]}]
    y, _ = sf.read(render(doc, {"asset": source}, tmp_path / "out.wav", chunk_size=7))
    assert y[0, 0] == y[-1, 1] == 0
    assert np.allclose(y[:50, 1], 0) and np.allclose(y[50:, 0], 0)
    assert abs(y[25, 0] - .1) < 1e-6 and abs(y[75, 1] - .1) < 1e-6

def test_invalid_edits_and_cancelled_output_cleanup(tmp_path):
    with pytest.raises(ValidationError): Arrangement.model_validate(document(start=1.5))
    with pytest.raises(ValidationError): Arrangement.model_validate(document(fade_in=30, fade_out=30))
    source = tmp_path / "source.wav"; sf.write(source, np.zeros((100, 2)), 44100)
    with pytest.raises(ValueError, match="beyond"): render(document(length=101), {"asset": source}, tmp_path / "out.wav")
    count = 0
    def stop():
        nonlocal count
        count += 1
        if count > 2: raise InterruptedError("Cancelled")
    with pytest.raises(InterruptedError): render(document(), {"asset": source}, tmp_path / "cancelled.wav", check=stop, chunk_size=8)
    assert not (tmp_path / "cancelled.wav").exists() and not list(tmp_path.glob("source-*.float.wav"))

def test_overlapping_linear_crossfades_preserve_continuous_constant_signal(tmp_path):
    source = tmp_path / 'constant.wav'
    sf.write(source, np.ones((100, 2)) * .1, 44100, subtype='FLOAT')
    doc = document(start=0,source_start=0,length=100,fade_out=20)
    doc['tracks'][0]['clips'].append({'id':'second','asset_id':'asset','start':80,'source_start':0,'length':100,'fade_in':20})
    y, _ = sf.read(render(doc,{'asset':source},tmp_path/'crossfade.wav',chunk_size=11))
    assert y.shape == (180,2) and np.allclose(y,.1,atol=2e-7)
