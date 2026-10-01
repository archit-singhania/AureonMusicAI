"""Real user journeys against an isolated persistent database and measured audio."""

import io, json, os, sys, tempfile, time, zipfile
from pathlib import Path
import numpy as np
import pytest
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
os.environ["AUREON_DATA_DIR"] = tempfile.mkdtemp(prefix="aureon-test-")
os.environ["AUREON_INTERNAL_KEY"] = "test-internal-key"
sys.path.insert(0, str(ROOT / "python_audio_service"))
from fastapi.testclient import TestClient
from studio_api import app
from store import create, engine, session
import audio_engine as audio


@pytest.fixture()
def client():
    with TestClient(app) as client:
        yield client


def account(client):
    result = client.post("/api/v1/demo")
    assert result.status_code == 201, result.text
    body = result.json()
    return {"Authorization": "Bearer " + body["token"]}, body


def wait(client, headers, jid):
    deadline = time.monotonic() + 40
    while time.monotonic() < deadline:
        job = client.get("/api/v1/jobs/" + jid, headers=headers).json()
        if job["status"] in ("done", "failed", "cancelled"):
            return job
        time.sleep(0.1)
    pytest.fail("DSP worker did not complete within its test timeout.")


def test_accounts_ownership_and_version_conflict(client):
    h, a = account(client)
    other, _ = account(client)
    pid = a["project"]["id"]
    assert client.get("/api/v1/projects/" + pid, headers=other).status_code == 404
    assert client.get("/api/v1/projects/" + pid).status_code == 401
    assert (
        client.post(
            "/api/v1/auth/register", json={"email": "not-email", "password": "short"}
        ).status_code
        == 422
    )
    assert (
        client.post(
            "/api/v1/auth/register",
            json={
                "email": "owner@example.org",
                "password": "safe-passphrase-2026",
                "name": "Owner",
            },
        ).status_code
        == 201
    )
    assert (
        client.post(
            "/api/v1/auth/login",
            json={"email": "owner@example.org", "password": "incorrect-long-pass"},
        ).status_code
        == 401
    )
    state = {**a["project"], "title": "Saved across restarts"}
    saved = client.put(
        "/api/v1/projects/" + pid, headers=h, json={"revision": 1, "state": state}
    ).json()
    assert saved["revision"] == 2 and saved["title"] == "Saved across restarts"
    assert (
        client.put(
            "/api/v1/projects/" + pid, headers=h, json={"revision": 1, "state": state}
        ).status_code
        == 409
    )
    engine.dispose()
    assert (
        client.get("/api/v1/projects/" + pid, headers=h).json()["title"]
        == "Saved across restarts"
    )
    versions = client.get(f"/api/v1/projects/{pid}/versions", headers=h).json()
    restored = client.post(
        f"/api/v1/projects/{pid}/restore/{versions[0]['id']}", headers=h
    ).json()
    assert restored["title"] == "Afterglow Sessions"
    assert (
        client.get(
            "/internal/events", headers={"X-Aureon-Internal-Key": "wrong"}
        ).status_code
        == 403
    )
    events = client.get("/api/v1/events", headers=h).json()
    assert any(e["type"] == "project.saved" for e in events)


def test_real_generation_mix_exports_and_publication(client):
    h, a = account(client)
    pid = a["project"]["id"]
    job = wait(client, h, a["job"]["id"])
    assert job["status"] == "done", job
    master = client.get("/api/v1/assets/" + job["master_asset_id"], headers=h).json()
    measured = master["metrics"]
    assert measured["duration"] > 15 and max(measured["waveform"]) > 0.1
    assert (
        measured["true_peak_dbtp"] <= -0.7 and measured["integrated_lufs"] is not None
    )
    assert len(measured["spectrum_frames"]) > 20
    raw = client.get(master["url"])
    assert raw.status_code == 200
    y, sr = sf.read(io.BytesIO(raw.content))
    assert sr == 44100 and y.shape[1] == 2 and np.isfinite(y).all()
    pack = client.get("/api/v1/jobs/" + job["id"] + "/stems.zip", headers=h)
    with zipfile.ZipFile(io.BytesIO(pack.content)) as archive:
        assert set(archive.namelist()) == {
            "vocals.wav",
            "drums.wav",
            "bass.wav",
            "other.wav",
            "session.json",
        }
        assert json.loads(archive.read("session.json"))["bpm"] == 88
    p = client.get("/api/v1/projects/" + pid, headers=h).json()
    p["params"]["bass_gain"] = 0
    p["params"]["saturation"] = 0.7
    assert (
        client.put(
            "/api/v1/projects/" + pid,
            headers=h,
            json={"revision": p["revision"], "state": p},
        ).status_code
        == 200
    )
    remix = client.post(
        f"/api/v1/projects/{pid}/jobs", headers=h, json={"kind": "remix"}
    ).json()
    remix = wait(client, h, remix["id"])
    assert remix["status"] == "done", remix
    changed = client.get("/api/v1/assets/" + remix["master_asset_id"], headers=h).json()
    assert changed["metrics"]["waveform"] != measured["waveform"]
    if audio.ffmpeg():
        mp3 = client.post(
            f"/api/v1/projects/{pid}/jobs", headers=h, json={"kind": "mp3"}
        ).json()
        mp3 = wait(client, h, mp3["id"])
        assert mp3["status"] == "done", mp3
        encoded = client.get(
            "/api/v1/assets/" + mp3["master_asset_id"], headers=h
        ).json()
        assert len(client.get(encoded["url"]).content) > 10000
    art = client.post(f"/api/v1/projects/{pid}/artwork", headers=h)
    assert art.status_code == 200, art.text
    assert client.get(art.json()["url"]).content.startswith(b"\x89PNG")
    publication = client.post(
        f"/api/v1/projects/{pid}/publish", headers=h, json={"title": "A real track"}
    ).json()
    assert (
        client.get("/api/v1/showcase").json()[0]["master"]["id"]
        == remix["master_asset_id"]
    )
    assert client.post(f"/api/v1/showcase/{publication['id']}/like", headers=h).json()[
        "liked"
    ]
    assert (
        client.post(
            f"/api/v1/showcase/{publication['id']}/comments",
            headers=h,
            json={"text": "The actual mix sounds good."},
        ).status_code
        == 201
    )
    assert (
        client.get(f"/api/v1/showcase/{publication['id']}/comments").json()[0]["text"]
        == "The actual mix sounds good."
    )
    assert (
        client.delete(f"/api/v1/showcase/{publication['id']}", headers=h).status_code
        == 200
    )


def test_upload_validation_provider_failure_and_collaboration(client):
    h, a = account(client)
    other, b = account(client)
    pid = a["project"]["id"]
    assert (
        client.post(
            "/api/v1/assets", headers=h, files={"file": ("bad.exe", b"not audio")}
        ).status_code
        == 415
    )
    wav = io.BytesIO()
    sr = 44100
    sf.write(wav, np.sin(2 * np.pi * 220 * np.arange(sr) / sr) * 0.2, sr, format="WAV")
    upload = client.post(
        "/api/v1/assets?project_id=" + pid + "&consent=true",
        headers=h,
        files={"file": ("own-voice.wav", wav.getvalue(), "audio/wav")},
    )
    assert upload.status_code == 201, upload.text
    aid = upload.json()["id"]
    assert client.get("/api/v1/assets/" + aid, headers=other).status_code == 404
    assert (
        client.post(
            f"/api/v1/projects/{pid}/join",
            headers=other,
            json={"code": "incorrect-code"},
        ).status_code
        == 404
    )
    assert (
        client.post(
            f"/api/v1/projects/{pid}/join",
            headers=other,
            json={"code": a["project"]["invite_code"]},
        ).status_code
        == 200
    )
    assert len(client.get(f"/api/v1/projects/{pid}/members", headers=h).json()) == 2
    assert client.get("/api/v1/assets/" + aid, headers=other).status_code == 200
    assert any(
        asset["id"] == aid
        for asset in client.get("/api/v1/assets", headers=other).json()
    )
    assert (
        client.delete(
            f"/api/v1/projects/{pid}/members/{b['user']['id']}", headers=other
        ).status_code
        == 403
    )
    assert (
        client.delete(
            f"/api/v1/projects/{pid}/members/{b['user']['id']}", headers=h
        ).status_code
        == 200
    )
    assert client.get("/api/v1/assets/" + aid, headers=other).status_code == 404
    assert (
        client.post(
            f"/api/v1/projects/{pid}/join",
            headers=other,
            json={"code": a["project"]["invite_code"]},
        ).status_code
        == 404
    )
    if not os.getenv("OLLAMA_URL"):
        assert (
            client.post(
                "/api/v1/lyrics", headers=h, json={"prompt": "Original verse"}
            ).status_code
            == 503
        )
    if not os.getenv("SARVAM_API_KEY"):
        assert (
            client.post("/api/v1/assets/" + aid + "/transcribe", headers=h).status_code
            == 503
        )
    proposal = client.post(
        "/api/v1/copilot", headers=h, json={"prompt": "warm tape and wide stereo"}
    ).json()
    assert (
        proposal["params"]["saturation"] == 0.5
        and proposal["requires_confirmation"] is True
    )


def test_cancel_retry_and_invalid_parameters(client):
    h, a = account(client)
    pid = a["project"]["id"]
    state = {**a["project"], "params": {"saturation": 12}}
    assert (
        client.put(
            "/api/v1/projects/" + pid, headers=h, json={"revision": 1, "state": state}
        ).status_code
        == 422
    )
    first = client.post(
        f"/api/v1/projects/{pid}/jobs",
        headers={**h, "Idempotency-Key": "same-request"},
        json={"kind": "generate"},
    ).json()
    second = client.post(
        f"/api/v1/projects/{pid}/jobs",
        headers={**h, "Idempotency-Key": "same-request"},
        json={"kind": "generate"},
    ).json()
    assert first["id"] == second["id"]
    cancel = client.post("/api/v1/jobs/" + first["id"] + "/cancel", headers=h).json()
    assert cancel.get("cancel_requested")
    cancelled = wait(client, h, first["id"])
    assert cancelled["status"] == "cancelled"
    retry = client.post("/api/v1/jobs/" + first["id"] + "/retry", headers=h)
    assert retry.status_code == 202 and retry.json()["id"] != first["id"]


def test_video_is_actual_media(tmp_path):
    if not audio.ffmpeg():
        pytest.skip("FFmpeg unavailable")
    path, _, _ = audio.synthesize_preset("daylight", tmp_path, 1)
    output = audio.video(path, tmp_path / "video.mp4")
    data = Path(output).read_bytes()
    assert b"ftyp" in data[:48] and len(data) > 20000


def test_worker_recovers_an_expired_processing_lease(client):
    h, a = account(client)
    pid = a["project"]["id"]
    with session() as db:
        recovered = create(
            db,
            "job",
            a["user"]["id"],
            {
                "job_kind": "generate",
                "status": "mixing",
                "progress": 75,
                "heartbeat": 0,
                "state": a["project"],
                "source_job_id": None,
            },
            pid,
        )
        jid = recovered.id
    result = wait(client, h, jid)
    assert result["status"] == "done", result
    assert result["master_asset_id"] and result["progress"] == 100
