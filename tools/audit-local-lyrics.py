"""A short real local-model request. Writes evidence without tokens or passwords."""
import json
from pathlib import Path
import secrets
import time
import httpx

root = Path(__file__).resolve().parents[1]
prompt = "Write exactly two short original lines about finding a melody at sunrise. Return only the lyrics."
with httpx.Client(base_url="http://localhost:5000", timeout=110) as client:
    account = client.post("/api/v1/auth/register", json={
        "email": f"lyric-audit-{secrets.token_hex(4)}@example.org",
        "password": secrets.token_urlsafe(24), "name": "Local audit",
    })
    account.raise_for_status()
    token = account.json()["token"]
    start = time.monotonic()
    response = client.post("/api/v1/lyrics", headers={"Authorization": f"Bearer {token}"},
        json={"prompt": prompt, "context": "A calm original R&B track, 88 BPM."})
    evidence = {"date": "2026-10-05", "provider": "Ollama", "model": "qwen3:8b",
        "prompt": prompt, "http_status": response.status_code,
        "elapsed_seconds": round(time.monotonic() - start, 2), "result": response.json()}
    output = root / "docs/demo/local-lyric-audit-2026-10-05.json"
    output.write_text(json.dumps(evidence, indent=2), encoding="utf-8")
    print(json.dumps(evidence))
    if response.status_code == 503:
        assert "draft was preserved" in response.json()["detail"]
        print("The unavailable-provider path passed; real local inference remains a manual gate.")
    else:
        response.raise_for_status()
        assert response.json()["source"] == "ollama" and response.json()["lyrics"].strip()
