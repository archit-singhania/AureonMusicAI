import base64
import io
import sys
from pathlib import Path
import numpy as np
import pytest
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python_audio_service"))
from services.vocal_gen import sarvam_service as sarvam


class Response:
    def __init__(self, data):
        self.data = data

    def raise_for_status(self):
        pass

    def json(self):
        return self.data


def test_provider_missing_is_explicit(monkeypatch, tmp_path):
    monkeypatch.delenv("SARVAM_API_KEY", raising=False)
    with pytest.raises(ValueError, match="not configured"):
        sarvam.synthesize_sarvam_vocal("hello", tmp_path / "voice.wav")
    with pytest.raises(ValueError, match="not configured"):
        sarvam.transcribe_voice_prompt(tmp_path / "none.wav")


def test_current_speech_contract_returns_decodable_audio(monkeypatch, tmp_path):
    monkeypatch.setenv("SARVAM_API_KEY", "test-provider-key")
    buffer = io.BytesIO()
    sf.write(buffer, np.sin(np.arange(4000) / 16) * 0.1, 24000, format="WAV")
    calls = []

    def post(url, **kwargs):
        calls.append(kwargs)
        assert kwargs["headers"]["api-subscription-key"] == "test-provider-key"
        assert kwargs["json"]["model"] == "bulbul:v3"
        assert kwargs["json"]["language_code"] == "en-IN"
        assert "inputs" not in kwargs["json"] and "pitch" not in kwargs["json"]
        return Response({"audios": [base64.b64encode(buffer.getvalue()).decode()]})

    monkeypatch.setattr(sarvam.requests, "post", post)
    output = tmp_path / "voice.wav"
    sarvam.synthesize_sarvam_vocal("a" * 2500, str(output))
    samples, rate = sf.read(output)
    assert rate == 44100 and len(samples) > 14000 and len(calls) == 2


def test_transcription_uses_real_bounded_chunks(monkeypatch, tmp_path):
    monkeypatch.setenv("SARVAM_API_KEY", "test-provider-key")
    source = tmp_path / "voice.wav"
    sf.write(source, np.zeros(44100 * 26), 44100)
    calls = []

    def post(url, **kwargs):
        calls.append(kwargs)
        samples, rate = sf.read(io.BytesIO(kwargs["files"]["file"][1]))
        assert rate == 16000 and len(samples) <= 25 * 16000
        assert kwargs["data"] == {
            "model": "saaras:v3",
            "language_code": "unknown",
            "mode": "transcribe",
        }
        return Response(
            {"transcript": "Actual recognized speech", "language_code": "en-IN"}
        )

    monkeypatch.setattr(sarvam.requests, "post", post)
    result = sarvam.transcribe_voice_prompt(str(source))
    assert len(calls) == 2 and result["source"] == "sarvam_saaras"
    assert result["transcript"] == "Actual recognized speech Actual recognized speech"
