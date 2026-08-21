import os
import uuid
import asyncio
import logging
import shutil
from enum import Enum
from typing import Dict, Optional, Any
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

TEMP_DIR = os.path.join(os.path.dirname(__file__), '../temp')
OUTPUTS_DIR = os.path.join(os.path.dirname(__file__), '../../../outputs')
STEMS_DIR = os.path.join(OUTPUTS_DIR, 'stems')

os.makedirs(TEMP_DIR, exist_ok=True)
os.makedirs(OUTPUTS_DIR, exist_ok=True)
os.makedirs(STEMS_DIR, exist_ok=True)


class JobStatus(str, Enum):
    QUEUED = "queued"
    ANALYZING = "analyzing"
    SEPARATING_STEMS = "separating_stems"
    GENERATING_FLOW = "generating_flow"
    SYNTHESIZING = "synthesizing"
    CORRECTING = "correcting"
    MIXING = "mixing"
    DONE = "done"
    FAILED = "failed"


@dataclass
class Job:
    job_id: str
    beat_path: str
    lyrics: str
    genre: str
    speaker_wav: Optional[str]
    preferred_engine: str = "auto"
    language_code: str = "en-IN"
    scale_type: str = "minor"
    retune_speed: float = 0.1
    status: JobStatus = JobStatus.QUEUED
    progress: int = 0
    output_path: Optional[str] = None
    stems: Optional[Dict[str, str]] = None
    error: Optional[str] = None
    critique: Optional[Dict[str, Any]] = None


_jobs: Dict[str, Job] = {}
_queue: asyncio.Queue = asyncio.Queue()


def create_job(
    beat_path: str,
    lyrics: str,
    genre: str,
    speaker_wav: Optional[str] = None,
    preferred_engine: str = "auto",
    language_code: str = "en-IN",
    scale_type: str = "minor",
    retune_speed: float = 0.1
) -> str:
    job_id = str(uuid.uuid4())
    job = Job(
        job_id=job_id,
        beat_path=beat_path,
        lyrics=lyrics,
        genre=genre,
        speaker_wav=speaker_wav,
        preferred_engine=preferred_engine,
        language_code=language_code,
        scale_type=scale_type,
        retune_speed=retune_speed
    )
    _jobs[job_id] = job
    asyncio.create_task(_queue.put(job_id))
    logger.info(f"Job created: {job_id} (genre={genre}, engine={preferred_engine})")
    return job_id


def get_job(job_id: str) -> Optional[Job]:
    return _jobs.get(job_id)


def update_job(job_id: str, **kwargs):
    job = _jobs.get(job_id)
    if job:
        for k, v in kwargs.items():
            setattr(job, k, v)


async def process_job(job_id: str):
    from services.beat_analysis.analyzer import analyze_beat
    from services.beat_analysis.syllable_mapper import parse_lyrics
    from services.beat_analysis.flow_engine import generate_flow_timings, critique_flow
    from services.vocal_gen.synthesizer import synthesize_all_lines
    from services.pitch_correction.corrector import autotune_clip, align_vocals_to_beat, pitch_shift_clip
    from services.mixing.mixer import save_vocal_array, mix_with_ffmpeg
    from services.mixing.stem_separator import separate_stems

    job = _jobs.get(job_id)
    if not job:
        return

    job_temp = os.path.join(TEMP_DIR, job_id)
    job_stems_dir = os.path.join(STEMS_DIR, job_id)
    os.makedirs(job_temp, exist_ok=True)
    os.makedirs(job_stems_dir, exist_ok=True)

    try:
        # 1. Beat Analysis
        update_job(job_id, status=JobStatus.ANALYZING, progress=10)
        beat_grid = analyze_beat(job.beat_path)

        # 2. Stem Separation (Vocals, Drums, Bass, Other)
        update_job(job_id, status=JobStatus.SEPARATING_STEMS, progress=25)
        stems_dict = separate_stems(job.beat_path, job_stems_dir, job_id)

        # 3. Flow Engine & Timing
        update_job(job_id, status=JobStatus.GENERATING_FLOW, progress=40)
        flow_map = parse_lyrics(job.lyrics)
        timings = generate_flow_timings(flow_map, beat_grid, job.genre)

        critique = critique_flow(timings, beat_grid, job.genre)
        update_job(job_id, critique=critique)

        if not critique.get("approved", True) and critique.get("score", 1.0) < 0.4:
            logger.warning(f"Job {job_id}: flow critique low ({critique['score']}), regenerating...")
            timings = generate_flow_timings(flow_map, beat_grid, job.genre)

        # 4. Vocal Synthesis (Sarvam AI / XTTS-v2)
        update_job(job_id, status=JobStatus.SYNTHESIZING, progress=60)
        lines_text = [l.text for l in flow_map.lines]
        vocal_paths = synthesize_all_lines(
            lines_text,
            job_id,
            job_temp,
            job.genre,
            job.speaker_wav,
            preferred_engine=job.preferred_engine,
            language_code=job.language_code
        )

        # 5. Pitch Correction / Scale Auto-Tune
        update_job(job_id, status=JobStatus.CORRECTING, progress=75)
        key_note = beat_grid.key.split()[0] if beat_grid.key else "C"
        aligned = align_vocals_to_beat(vocal_paths, timings, beat_grid.total_duration)

        aligned_shifted = pitch_shift_clip(aligned, 22050, 0)
        aligned_tuned = autotune_clip(
            aligned_shifted,
            22050,
            key_note=key_note,
            scale_type=job.scale_type,
            retune_speed=job.retune_speed
        )

        raw_vocal_path = os.path.join(job_temp, f"{job_id}_vocal_raw.wav")
        save_vocal_array(aligned_tuned, 22050, raw_vocal_path)

        # Save vocal stem to stems directory
        stem_vocal_target = os.path.join(job_stems_dir, f"{job_id}_stem_vocals.wav")
        save_vocal_array(aligned_tuned, 22050, stem_vocal_target)
        stems_dict["vocals"] = stem_vocal_target
        update_job(job_id, stems=stems_dict)

        # 6. Master Mixing with Sidechain Ducking & LUFS Normalizer
        update_job(job_id, status=JobStatus.MIXING, progress=90)
        output_filename = f"{job_id}_final.mp3"
        output_path = os.path.join(OUTPUTS_DIR, output_filename)

        mix_with_ffmpeg(
            raw_vocal_path,
            job.beat_path,
            output_path,
            genre=job.genre,
            stems_dir=job_stems_dir,
            job_id=job_id
        )

        update_job(
            job_id,
            status=JobStatus.DONE,
            progress=100,
            output_path=output_path,
            stems=stems_dict
        )
        logger.info(f"Job {job_id} successfully finished! Output: {output_path}")

    except Exception as e:
        logger.exception(f"Job {job_id} failed: {e}")
        update_job(job_id, status=JobStatus.FAILED, error=str(e))
    finally:
        try:
            shutil.rmtree(job_temp, ignore_errors=True)
        except Exception:
            pass


async def worker_loop():
    logger.info("Aureon audio job worker initialized and listening...")
    while True:
        job_id = await _queue.get()
        await process_job(job_id)
        _queue.task_done()
