"""Optional black-box contract and SignalR checks against the running .NET gateway."""

import json, os, time
import io
import math
import struct
import wave
import httpx
import pytest
from websockets.sync.client import connect

URL = os.getenv("AUREON_GATEWAY_URL", "")
pytestmark = pytest.mark.skipif(
    not URL,
    reason="Start gateway and set AUREON_GATEWAY_URL to run black-box transport checks.",
)


def test_gateway_preserves_consented_multipart_audio_upload():
    """MVC must leave the multipart body intact for Python's UploadFile binder."""
    with httpx.Client(base_url=URL, timeout=30) as client:
        account = client.post(
            "/api/v1/auth/register",
            json={"email": f"upload-{time.time_ns()}@example.test",
                  "password": "long-test-password", "name": "Upload fixture"},
        ).json()
        headers = {"Authorization": "Bearer " + account["token"]}
        project = client.post("/api/v1/projects", headers=headers,
                              json={"title": "A real multipart take"}).json()
        source = io.BytesIO()
        with wave.open(source, "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(44100)
            output.writeframes(b"".join(struct.pack("<h", round(5000 * math.sin(2 * math.pi * 440 * n / 44100)))
                                        for n in range(4410)))
        uploaded = client.post(
            "/api/v1/assets", headers=headers,
            params={"project_id": project["id"], "consent": "true"},
            files={"file": ("owned-take.wav", source.getvalue(), "audio/wav")},
        )
        assert uploaded.status_code == 201, uploaded.text
        asset = uploaded.json()
        assert asset["consented"] is True
        assert asset["owner_id"] == account["user"]["id"]
        assert asset["media_type"] == "audio/wav"
        assert asset["id"] in {item["id"] for item in client.get("/api/v1/assets", headers=headers).json()}
        assert abs(asset["metrics"]["duration"] - 0.1) < 0.001
        saved = client.get(asset["url"])
        assert saved.status_code == 200
        with wave.open(io.BytesIO(saved.content)) as decoded:
            assert decoded.getframerate() == 44100
            assert decoded.getnframes() == 4410
            assert decoded.getsampwidth() == 3


def test_gateway_contract_streaming_and_live_events():
    with httpx.Client(base_url=URL, timeout=30) as client:
        assert client.get("/health").status_code == 200
        demo = client.post("/api/v1/demo").json()
        assert demo["job"]["id"] and "preset_id" in demo["project"]
        token = demo["token"]
        pid = demo["project"]["id"]
        headers = {"Authorization": "Bearer " + token}
        assert client.get("/api/v1/projects/" + pid).status_code == 401
        negotiate = client.post(
            "/hub/music/negotiate?negotiateVersion=1&access_token=" + token
        ).json()
        websocket = (
            URL.replace("http://", "ws://").replace("https://", "wss://")
            + "/hub/music?id="
            + negotiate["connectionToken"]
            + "&access_token="
            + token
        )
        with connect(websocket, open_timeout=10) as socket:
            socket.send('{"protocol":"json","version":1}\x1e')
            assert "{}" in socket.recv(timeout=10)
            socket.send(
                json.dumps(
                    {
                        "type": 1,
                        "invocationId": "1",
                        "target": "JoinProject",
                        "arguments": [pid],
                    }
                )
                + "\x1e"
            )
            reply = socket.recv(timeout=10)
            assert "error" not in reply, reply
            state = demo["project"]
            state["title"] = "A live, authorized edit"
            saved = client.put(
                "/api/v1/projects/" + pid,
                headers=headers,
                json={"revision": 1, "state": state},
            )
            assert saved.status_code == 200, saved.text
            deadline = time.monotonic() + 10
            received = False
            while time.monotonic() < deadline:
                raw = socket.recv(timeout=10)
                if "StudioEvent" in raw and "A live, authorized edit" in raw:
                    received = True
                    break
            assert received, (
                "The durable outbox did not reach the authorized project group."
            )
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            job = client.get(
                "/api/v1/jobs/" + demo["job"]["id"], headers=headers
            ).json()
            if job["status"] in ("done", "failed"):
                break
            time.sleep(0.2)
        assert job["status"] == "done", job
        media = client.get(
            "/api/v1/assets/" + job["master_asset_id"], headers=headers
        ).json()
        part = client.get(media["url"], headers={"Range": "bytes=0-127"})
        assert part.status_code == 206 and len(part.content) == 128
        assert "bytes 0-127/" in part.headers["content-range"]


def test_live_membership_revocation_stops_delivery():
    with httpx.Client(base_url=URL, timeout=30) as client:
        owner = client.post("/api/v1/demo").json()
        pid = owner["project"]["id"]
        owner_headers = {"Authorization": "Bearer " + owner["token"]}
        member = client.post(
            "/api/v1/auth/register",
            json={
                "email": f"live-{time.time_ns()}@example.test",
                "password": "long-test-password",
                "name": "Collaborator",
            },
        ).json()
        member_headers = {"Authorization": "Bearer " + member["token"]}
        joined = client.post(
            f"/api/v1/projects/{pid}/join",
            headers=member_headers,
            json={"code": owner["project"]["invite_code"]},
        )
        assert joined.status_code == 200
        token = member["token"]
        negotiate = client.post(
            "/hub/music/negotiate?negotiateVersion=1&access_token=" + token
        ).json()
        address = (
            URL.replace("http://", "ws://").replace("https://", "wss://")
            + "/hub/music?id="
            + negotiate["connectionToken"]
            + "&access_token="
            + token
        )
        with connect(address, open_timeout=10) as socket:
            socket.send('{"protocol":"json","version":1}\x1e')
            assert "{}" in socket.recv(timeout=10)
            socket.send(
                json.dumps(
                    {
                        "type": 1,
                        "invocationId": "join",
                        "target": "JoinProject",
                        "arguments": [pid],
                    }
                )
                + "\x1e"
            )
            while '"invocationId":"join"' not in socket.recv(timeout=10):
                pass
            assert (
                client.delete(
                    f"/api/v1/projects/{pid}/members/{member['user']['id']}",
                    headers=owner_headers,
                ).status_code
                == 200
            )
            denied = client.get("/api/v1/projects/" + pid, headers=member_headers)
            assert denied.status_code == 404
            received = False
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                packet = socket.recv(timeout=10)
                if "SessionAccessRevoked" in packet:
                    received = True
                    break
            assert received, (
                "A revoked collaborator still remained eligible for live updates."
            )
            assert (
                client.post(
                    f"/api/v1/projects/{pid}/join",
                    headers=member_headers,
                    json={"code": owner["project"]["invite_code"]},
                ).status_code
                == 404
            )
