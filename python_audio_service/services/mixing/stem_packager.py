"""
stem_packager.py — 4-Stem DAW Package Exporter (Zero-Cost).
Packages isolated stems (vocals, drums, bass, other) + metadata into a ready-to-import ZIP archive.
"""

import os
import zipfile
import json
import logging

logger = logging.getLogger(__name__)


def package_stems_zip(
    job_id: str,
    stems_dir: str,
    output_zip_path: str,
    genre: str = "trap",
    bpm: int = 140,
    key: str = "D# Minor"
) -> str:
    """
    Creates a production-ready ZIP containing all 4 stems and DAW session metadata.
    """
    os.makedirs(os.path.dirname(output_zip_path), exist_ok=True)

    metadata = {
        "project": f"Aureon_Studio_Project_{job_id}",
        "genre": genre,
        "bpm": bpm,
        "key": key,
        "sample_rate": 44100,
        "format": "WAV 24-bit PCM",
        "stems": ["vocals.wav", "drums.wav", "bass.wav", "other.wav"]
    }

    with zipfile.ZipFile(output_zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Write metadata README
        readme_content = (
            f"=== AUREON AI MUSIC STUDIO — STEM PACKAGE ===\n\n"
            f"Job ID     : {job_id}\n"
            f"Genre      : {genre.upper()}\n"
            f"BPM        : {bpm}\n"
            f"Musical Key: {key}\n\n"
            f"Import instructions:\n"
            f"1. Open FL Studio / Ableton Live / Logic Pro.\n"
            f"2. Set project tempo to {bpm} BPM.\n"
            f"3. Drag all 4 WAV stems onto separate tracks.\n"
        )
        zipf.writestr("SESSION_INFO.txt", readme_content)
        zipf.writestr("metadata.json", json.dumps(metadata, indent=2))

        # Add each stem WAV file
        stem_names = ["vocals", "drums", "bass", "other"]
        for sname in stem_names:
            stem_file = os.path.join(stems_dir, f"{job_id}_stem_{sname}.wav")
            if os.path.exists(stem_file):
                zipf.write(stem_file, arcname=f"Stems/{sname}.wav")

    logger.info(f"Created Stem ZIP package: {output_zip_path}")
    return output_zip_path
