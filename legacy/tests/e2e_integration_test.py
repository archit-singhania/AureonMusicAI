import requests
import time
import os

API_URL = "http://localhost:5000/api"
job_id = None

print("=======================================")
print("🧪 Aureon Studio E2E Integration Test")
print("=======================================")


def test_generate_beat():
    print("-> Triggering Text-to-Beat (MusicGen stub)...")
    res = requests.post(
        f"{API_URL}/advanced/musicgen",
        data={"prompt": "lofi hip hop beat", "duration": 5},
    )
    if res.status_code == 200:
        print("✅ MusicGen succeeded. Received WAV.")
        with open("test_beat.wav", "wb") as f:
            f.write(res.content)
    else:
        print(f"❌ MusicGen failed: {res.text}")


def test_full_pipeline():
    global job_id
    print("-> Triggering Full Vocal Pipeline...")
    files = {"beat": ("test_beat.wav", open("test_beat.wav", "rb"), "audio/wav")}
    data = {
        "lyrics": "Running through the night",
        "genre": "trap",
        "preferred_engine": "auto",
    }

    res = requests.post(f"{API_URL}/music/generate", files=files, data=data)
    if res.status_code == 200:
        job_id = res.json().get("job_id")
        print(f"✅ Pipeline queued. Job ID: {job_id}")
    else:
        print(f"❌ Pipeline failed: {res.text}")


def monitor_status():
    if not job_id:
        return
    print("-> Monitoring Job Status...")
    while True:
        res = requests.get(f"{API_URL}/music/status/{job_id}")
        data = res.json()
        status = data.get("status")
        print(f"   [{status}] Progress: {data.get('progress')}%")

        if status == "done":
            print("✅ Pipeline completed successfully.")
            break
        if status == "failed":
            print("❌ Pipeline failed.")
            break
        time.sleep(2)


def test_als_export():
    if not job_id:
        return
    print("-> Testing Ableton ALS Export...")
    res = requests.get(f"{API_URL}/advanced/export/als/{job_id}")
    if res.status_code == 200:
        print("✅ ALS Export succeeded.")
    else:
        print(f"❌ ALS Export failed: {res.text}")


if __name__ == "__main__":
    try:
        test_generate_beat()
        if os.path.exists("test_beat.wav"):
            test_full_pipeline()
            monitor_status()
            test_als_export()
        print("\n🎉 All tests executed.")
    except Exception as e:
        print(f"\n❌ E2E Test Error: {e}")
