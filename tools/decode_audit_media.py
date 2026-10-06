"""Decode the actual browser exports and write credential-free audit evidence."""
import argparse
import datetime
import hashlib
import io
import json
import re
import sqlite3
import subprocess
import zipfile
from pathlib import Path

import imageio_ffmpeg
import numpy as np
import soundfile as sf


def audio_info(source):
    info = sf.info(source)
    if hasattr(source, "seek"):
        source.seek(0)
    samples, rate = sf.read(source, always_2d=True)
    if not samples.size or not np.isfinite(samples).all():
        raise ValueError("Empty or invalid decoded PCM")
    return dict(format=info.format, subtype=info.subtype, channels=info.channels,
                sample_rate=rate, frames=len(samples),
                duration_seconds=round(len(samples) / rate, 6),
                peak=round(float(np.abs(samples).max()), 6),
                rms=round(float(np.sqrt(np.mean(samples ** 2))), 6))


def ffmpeg_decode(path):
    process = subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-hide_banner",
                              "-i", str(path), "-f", "null", "-"],
                             capture_output=True, text=True, timeout=180)
    if process.returncode:
        raise ValueError("FFmpeg decode failed: " + process.stderr[-1500:])
    inputs = process.stderr.split("Stream mapping:")[0]
    streams = [line.strip() for line in inputs.splitlines()
               if re.search(r"Stream #.*(?:Video|Audio):", line)]
    if not streams:
        raise ValueError("No audio or video stream was decoded")
    duration = re.search(r"Duration: (\d+):(\d+):([\d.]+)", inputs)
    return dict(full_decode=True, streams=streams,
                duration_seconds=round(sum(float(part) * factor
                    for part, factor in zip(duration.groups(), (3600, 60, 1))), 6)
                    if duration else None)


def artifact_info(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return dict(bytes=path.stat().st_size, sha256=digest.hexdigest(),
                modified_utc=datetime.datetime.fromtimestamp(path.stat().st_mtime,
                             datetime.timezone.utc).isoformat())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--database", type=Path)
    args = parser.parse_args()
    directory = args.directory.resolve()
    result = dict(date=datetime.datetime.now(datetime.timezone.utc).isoformat())
    result["master_wav"] = audio_info(directory / "guest-master.wav")
    result["master_mp3"] = audio_info(directory / "guest-master.mp3")
    result["visualizer_mp4"] = ffmpeg_decode(directory / "guest-visualizer.mp4")
    result["screen_recording_mp4"] = ffmpeg_decode(directory / "guest-workflow.mp4")
    with zipfile.ZipFile(directory / "guest-stems.zip") as archive:
        if set(archive.namelist()) != {"vocals.wav", "drums.wav", "bass.wav", "other.wav", "session.json"}:
            raise ValueError("Unexpected stem ZIP contents")
        result["stem_zip"] = {name: audio_info(io.BytesIO(archive.read(name)))
                              for name in archive.namelist() if name.endswith(".wav")}
        result["stem_zip"]["session_metadata"] = bool(json.loads(archive.read("session.json")))
    workflow = json.loads((directory / "guest-workflow-evidence.json").read_text())
    recording = workflow.get("recording_asset")
    if args.database and recording:
        with sqlite3.connect(f"file:{args.database.resolve().as_posix()}?mode=ro", uri=True) as database:
            row = database.execute("SELECT data FROM documents WHERE id=? AND kind='asset'", (recording["id"],)).fetchone()
            result["job_receipts_verified"] = []
            for receipt in workflow["completed_jobs"]:
                raw = database.execute("SELECT parent,data FROM documents WHERE id=? AND kind='job'", (receipt["id"],)).fetchone()
                if not raw:
                    raise ValueError("Completed browser job is absent from the isolated database")
                project_id, payload = raw
                job = json.loads(payload)
                if job["status"] != "done" or job["master_asset_id"] != receipt["master_asset_id"]:
                    raise ValueError("Browser job receipt differs from the durable completed job")
                result["job_receipts_verified"].append(receipt)
                if receipt["kind"] == "remix":
                    asset = json.loads(database.execute("SELECT data FROM documents WHERE id=?", (job["master_asset_id"],)).fetchone()[0])
                    previous = [json.loads(raw[0]) for raw in database.execute("SELECT data FROM documents WHERE kind='job' AND parent=? ORDER BY created DESC", (project_id,))]
                    previous = next(item for item in previous if item["status"] == "done" and item["job_kind"] == "generate")
                    original = json.loads(database.execute("SELECT data FROM documents WHERE id=?", (previous["master_asset_id"],)).fetchone()[0])
                    current_pcm = sf.read(asset["path"])[0]
                    original_pcm = sf.read(original["path"])[0]
                    changed = not np.array_equal(current_pcm, original_pcm)
                    exported = np.array_equal(current_pcm, sf.read(directory / "guest-master.wav")[0])
                    if not changed or not exported or not job["state"]["params"].get("bass_mute"):
                        raise ValueError("The browser did not export its genuinely changed saved bass-muted remix")
                    result["remix_validation"] = dict(different_decoded_pcm=changed,
                        maximum_pcm_delta=round(float(np.max(np.abs(current_pcm-original_pcm))), 6),
                        downloaded_wav_matches_new_master=exported, bass_mute_persisted=True,
                        waveform_bins=len(asset["metrics"]["waveform"]),
                        spectrum_frames=len(asset["metrics"]["spectrum_frames"]))
        if not row:
            raise ValueError("Recorded take is absent from the isolated database")
        saved_take = json.loads(row[0])
        if saved_take.get("consented") is not True:
            raise ValueError("Recorded take is missing its actual consent receipt")
        path = Path(saved_take["path"]).resolve()
        if not path.is_relative_to(args.database.resolve().parent):
            raise ValueError("Recorded take is outside the isolated audit workspace")
        result["synthetic_microphone_wav"] = audio_info(path)
        result["synthetic_microphone_receipt"] = dict(id=recording["id"],
            media_type=saved_take["media_type"], consented=saved_take["consented"],
            waveform_bins=len(saved_take["metrics"]["waveform"]),
            spectrum_frames=len(saved_take["metrics"]["spectrum_frames"]),
            artifact=artifact_info(path))
        if result["synthetic_microphone_wav"]["rms"] <= 0:
            raise ValueError("Synthetic microphone fixture decoded to silence")
    elif args.database:
        raise ValueError("Browser did not record an uploaded microphone take")
    result["artifacts"] = {path.name: artifact_info(path)
                           for path in directory.iterdir() if path.suffix in {".wav", ".mp3", ".mp4", ".webm", ".zip"}}
    root = Path(__file__).resolve().parent.parent
    result["build_artifacts"] = {name: artifact_info(root / relative)
        for name, relative in {
            "web_main": "flutter_app/aureon/build/web/main.dart.js",
            "web_bootstrap": "flutter_app/aureon/build/web/flutter_bootstrap.js",
            "inter_font": "flutter_app/aureon/build/web/assets/assets/fonts/Inter.ttf",
            "android_debug": "flutter_app/aureon/build/app/outputs/apk/debug/app-debug.apk",
        }.items()}
    (directory / "decoded-media-evidence.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
