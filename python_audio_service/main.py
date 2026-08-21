import os
import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Query
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import aiofiles
import uvicorn

from job_queue import create_job, get_job, worker_loop, JobStatus, OUTPUTS_DIR, STEMS_DIR
from services.vocal_gen.sarvam_service import transcribe_voice_prompt, is_sarvam_available, SUPPORTED_LANGUAGES
from services.mixing.effects_rack import process_effects_rack
from services.mixing.stem_packager import package_stems_zip
from services.video.visualizer_video import generate_vertical_visualizer_video
from services.agent.mixing_copilot import parse_mixing_prompt
from services.beat_analysis.drum_synthesizer import generate_drum_loop
from services.vocal_gen.melody_extractor import extract_melody_notes

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), 'temp/uploads')
BEATS_DIR = os.path.join(os.path.dirname(__file__), '../beats')
VIDEOS_DIR = os.path.join(OUTPUTS_DIR, 'videos')
ZIPS_DIR = os.path.join(OUTPUTS_DIR, 'zips')

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(BEATS_DIR, exist_ok=True)
os.makedirs(VIDEOS_DIR, exist_ok=True)
os.makedirs(ZIPS_DIR, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(worker_loop())
    logger.info("Aureon Master Studio Microservice running on port 8000")
    yield
    task.cancel()


app = FastAPI(title="Aureon Master AI Studio Microservice", version="3.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "aureon-master-studio",
        "sarvam_enabled": is_sarvam_available(),
        "effects_rack": "active",
        "supported_languages": list(SUPPORTED_LANGUAGES.keys())
    }


@app.get("/api/presets/beats")
async def list_preset_beats():
    return [
        {"id": "beat_trap_neon", "title": "Neon Cyber Trap", "genre": "trap", "bpm": 140, "key": "D# Minor", "description": "Heavy 808 glides, crisp hi-hat rolls, atmospheric synth pads"},
        {"id": "beat_drill_london", "title": "Midnight Drill", "genre": "drill", "bpm": 142, "key": "C Minor", "description": "Aggressive sliding 808s, sliding snare patterns"},
        {"id": "beat_rap_oldschool", "title": "BoomBap Classic", "genre": "rap", "bpm": 92, "key": "G Minor", "description": "Punchy kicks, dusty vinyl piano chords"},
        {"id": "beat_rnb_silk", "title": "Velvet R&B", "genre": "rnb", "bpm": 88, "key": "A# Minor", "description": "Lush Fender Rhodes, deep sub, silky snaps"},
        {"id": "beat_pop_synthwave", "title": "Retro Sunset Pop", "genre": "pop", "bpm": 124, "key": "F Major", "description": "Uplifting 80s synth arps, driving four-on-the-floor beat"}
    ]


@app.post("/api/voice/prompt")
async def process_voice_prompt(voice_audio: UploadFile = File(...), language_code: str = Form("unknown")):
    import uuid
    uid = str(uuid.uuid4())
    ext = os.path.splitext(voice_audio.filename)[1].lower() or ".wav"
    temp_path = os.path.join(UPLOAD_DIR, f"voice_{uid}{ext}")

    async with aiofiles.open(temp_path, 'wb') as f:
        content = await voice_audio.read()
        await f.write(content)

    res = transcribe_voice_prompt(temp_path, language_code=language_code)
    try:
        os.remove(temp_path)
    except Exception:
        pass
    return res


@app.post("/api/studio/remix")
async def apply_studio_remix(
    job_id: str = Form(...),
    saturation: float = Form(0.25),
    delay_ms: float = Form(180.0),
    delay_feedback: float = Form(0.30),
    delay_mix: float = Form(0.20),
    stereo_width: float = Form(0.60),
    de_esser: float = Form(0.40)
):
    """Processes master track through the studio DSP effects rack."""
    job = get_job(job_id)
    if not job or not job.output_path or not os.path.exists(job.output_path):
        raise HTTPException(404, "Original master track not found")

    remix_output = os.path.join(OUTPUTS_DIR, f"{job_id}_remix.wav")
    process_effects_rack(
        input_path=job.output_path,
        output_path=remix_output,
        saturation=saturation,
        delay_ms=delay_ms,
        delay_feedback=delay_feedback,
        delay_mix=delay_mix,
        stereo_width=stereo_width,
        de_esser=de_esser
    )

    return JSONResponse({
        "status": "success",
        "remix_url": f"/download/{job_id}/remix",
        "message": "Studio DSP effects rack rendered successfully"
    })


@app.get("/download/{job_id}/remix")
async def download_remix(job_id: str):
    remix_path = os.path.join(OUTPUTS_DIR, f"{job_id}_remix.wav")
    if not os.path.exists(remix_path):
        raise HTTPException(404, "Remix audio not rendered yet")
    return FileResponse(remix_path, media_type="audio/wav", filename=f"aureon_{job_id}_remix.wav")


@app.get("/api/studio/stems/zip/{job_id}")
async def get_stems_zip(job_id: str):
    job_stems_dir = os.path.join(STEMS_DIR, job_id)
    zip_path = os.path.join(ZIPS_DIR, f"aureon_{job_id}_stems.zip")
    package_stems_zip(job_id, job_stems_dir, zip_path)
    return FileResponse(zip_path, media_type="application/zip", filename=f"aureon_{job_id}_stems.zip")


@app.post("/api/studio/video/{job_id}")
async def create_visualizer_video(job_id: str, genre: str = Form("trap")):
    job = get_job(job_id)
    if not job or not job.output_path or not os.path.exists(job.output_path):
        raise HTTPException(404, "Audio track not found")

    video_path = os.path.join(VIDEOS_DIR, f"{job_id}_reels.mp4")
    generate_vertical_visualizer_video(job.output_path, video_path, genre=genre)
    return FileResponse(video_path, media_type="video/mp4", filename=f"aureon_{job_id}_reels.mp4")


@app.post("/api/studio/copilot")
async def chat_with_mixing_copilot(prompt: str = Form(...)):
    """Conversational AI mixing engineer."""
    params = parse_mixing_prompt(prompt)
    return JSONResponse(params)


@app.post("/api/studio/drums/generate")
async def generate_algorithmic_drums(bpm: int = Form(140), genre: str = Form("trap")):
    import uuid
    uid = str(uuid.uuid4())
    loop_path = os.path.join(BEATS_DIR, f"drumloop_{uid}.wav")
    generate_drum_loop(loop_path, bpm=bpm, genre=genre)
    return FileResponse(loop_path, media_type="audio/wav", filename=f"aureon_drums_{bpm}bpm.wav")


@app.post("/api/studio/melody/extract")
async def extract_humming_melody(humming_audio: UploadFile = File(...)):
    import uuid
    uid = str(uuid.uuid4())
    temp_path = os.path.join(UPLOAD_DIR, f"hum_{uid}.wav")
    async with aiofiles.open(temp_path, 'wb') as f:
        content = await humming_audio.read()
        await f.write(content)
    notes = extract_melody_notes(temp_path)
    try:
        os.remove(temp_path)
    except Exception:
        pass
    return {"notes": notes}


@app.post("/generate")
async def generate(
    beat: UploadFile = File(None),
    preset_beat_id: str = Form(None),
    lyrics: str = Form(...),
    genre: str = Form("rap"),
    speaker_wav: UploadFile = File(None),
    preferred_engine: str = Form("auto"),
    language_code: str = Form("en-IN"),
    scale_type: str = Form("minor"),
    retune_speed: float = Form(0.1),
):
    import uuid
    upload_id = str(uuid.uuid4())

    if beat is not None and beat.filename:
        beat_ext = os.path.splitext(beat.filename)[1].lower()
        beat_path = os.path.join(UPLOAD_DIR, f"{upload_id}_beat{beat_ext}")
        async with aiofiles.open(beat_path, 'wb') as f:
            content = await beat.read()
            await f.write(content)
    else:
        beat_path = os.path.join(UPLOAD_DIR, f"{upload_id}_preset_beat.wav")
        generate_drum_loop(beat_path, bpm=140 if genre in ["trap", "drill"] else 95, genre=genre)

    speaker_path = None
    if speaker_wav and speaker_wav.filename:
        spk_ext = os.path.splitext(speaker_wav.filename)[1].lower()
        speaker_path = os.path.join(UPLOAD_DIR, f"{upload_id}_speaker{spk_ext}")
        async with aiofiles.open(speaker_path, 'wb') as f:
            content = await speaker_wav.read()
            await f.write(content)

    job_id = create_job(
        beat_path=beat_path,
        lyrics=lyrics,
        genre=genre,
        speaker_wav=speaker_path,
        preferred_engine=preferred_engine,
        language_code=language_code,
        scale_type=scale_type,
        retune_speed=retune_speed
    )

    return JSONResponse({
        "job_id": job_id,
        "status": "queued",
        "preferred_engine": preferred_engine,
        "language_code": language_code
    })


@app.get("/status/{job_id}")
async def status(job_id: str):
    job = get_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    return {
        "job_id": job_id,
        "status": job.status,
        "progress": job.progress,
        "error": job.error,
        "critique": job.critique,
        "stems_available": bool(job.stems),
        "output_ready": job.status == JobStatus.DONE,
    }


@app.get("/download/{job_id}")
async def download(job_id: str):
    job = get_job(job_id)
    if not job or job.status != JobStatus.DONE or not job.output_path or not os.path.exists(job.output_path):
        raise HTTPException(404, "Finished track not found")
    return FileResponse(job.output_path, media_type="audio/mpeg", filename=f"aureon_{job_id}.mp3")


@app.get("/download/{job_id}/stem/{stem_name}")
async def download_stem(job_id: str, stem_name: str):
    job = get_job(job_id)
    if not job or not job.stems or stem_name not in job.stems or not os.path.exists(job.stems[stem_name]):
        raise HTTPException(404, f"Stem {stem_name} not available")
    return FileResponse(job.stems[stem_name], media_type="audio/wav", filename=f"aureon_{job_id}_{stem_name}.wav")




# Import our new modules
from services.beat_analysis.musicgen_service import MusicGenService
from services.vocal_gen.rvc_service import RVCService
from services.mixing.match_eq import MatchEQService
from services.video.album_art_generator import AlbumArtGenerator
from services.mixing.daw_project_exporter import DAWProjectExporter
from services.agent.lyric_cowriter import LyricCoWriter

musicgen_svc = MusicGenService()
rvc_svc = RVCService()
matcheq_svc = MatchEQService()
album_art_svc = AlbumArtGenerator()
daw_exporter_svc = DAWProjectExporter()
lyric_svc = LyricCoWriter()

@app.post("/api/studio/advanced/musicgen")
async def api_musicgen(prompt: str = Form(...), duration: int = Form(15)):
    import uuid
    uid = str(uuid.uuid4())
    output_path = os.path.join(BEATS_DIR, f"musicgen_{uid}.wav")
    await musicgen_svc.generate_beat(prompt, output_path, duration)
    return FileResponse(output_path, media_type="audio/wav", filename=f"musicgen_{uid}.wav")

@app.post("/api/studio/advanced/rvc")
async def api_rvc(voice_audio: UploadFile = File(...), target_voice: str = Form("pop_star"), pitch_shift: int = Form(0)):
    import uuid
    uid = str(uuid.uuid4())
    ext = os.path.splitext(voice_audio.filename)[1].lower() or ".wav"
    temp_in = os.path.join(UPLOAD_DIR, f"rvc_in_{uid}{ext}")
    temp_out = os.path.join(OUTPUTS_DIR, f"rvc_out_{uid}.wav")

    async with aiofiles.open(temp_in, 'wb') as f:
        content = await voice_audio.read()
        await f.write(content)
        
    await rvc_svc.convert_voice(temp_in, temp_out, target_voice, pitch_shift)
    try:
        os.remove(temp_in)
    except: pass
    
    return FileResponse(temp_out, media_type="audio/wav", filename=f"rvc_{target_voice}_{uid}.wav")

@app.post("/api/studio/advanced/matcheq")
async def api_matcheq(target_audio: UploadFile = File(...), ref_audio: UploadFile = File(...)):
    import uuid
    uid = str(uuid.uuid4())
    tgt_path = os.path.join(UPLOAD_DIR, f"eq_tgt_{uid}.wav")
    ref_path = os.path.join(UPLOAD_DIR, f"eq_ref_{uid}.wav")
    out_path = os.path.join(OUTPUTS_DIR, f"eq_out_{uid}.wav")

    async with aiofiles.open(tgt_path, 'wb') as f:
        await f.write(await target_audio.read())
    async with aiofiles.open(ref_path, 'wb') as f:
        await f.write(await ref_audio.read())
        
    matcheq_svc.apply_match_eq(tgt_path, ref_path, out_path)
    return FileResponse(out_path, media_type="audio/wav", filename=f"matched_{uid}.wav")

@app.post("/api/studio/advanced/cover")
async def api_album_art(prompt: str = Form(...), job_id: str = Form(...)):
    out_path = await album_art_svc.generate_cover(prompt, job_id)
    return FileResponse(out_path, media_type="image/jpeg", filename=f"cover_{job_id}.jpg")

@app.post("/api/studio/advanced/lyrics")
async def api_lyrics(context: str = Form(""), prompt: str = Form(...)):
    result = await lyric_svc.generate_lyrics(context, prompt)
    return {"lyrics": result}

@app.get("/api/studio/stems/als/{job_id}")
async def api_als_export(job_id: str):
    job = get_job(job_id)
    if not job or not job.stems:
        raise HTTPException(404, "Job stems not found")
        
    als_path = daw_exporter_svc.export_ableton_als(job_id, job.stems)
    if not als_path:
        raise HTTPException(500, "Failed to generate .als")
        
    return FileResponse(als_path, media_type="application/gzip", filename=f"Aureon_{job_id}.als")



# Import God-Tier modules
from services.pitch_correction.vocoder import VocoderEngine
from services.mixing.noise_reduction import NeuralNoiseReduction
from services.beat_analysis.midi_generator import MidiGenerator
from services.file_management.crate_digger import CrateDigger
from services.mixing.bus_processor import BusProcessor

vocoder_svc = VocoderEngine()
denoise_svc = NeuralNoiseReduction()
midi_svc = MidiGenerator()
crate_digger_svc = CrateDigger()
bus_processor_svc = BusProcessor()

@app.post("/api/ultimate/vocoder")
async def api_vocoder(vocal: UploadFile = File(...), chords_midi: str = Form("progression.mid")):
    import uuid
    uid = str(uuid.uuid4())
    in_path = os.path.join(UPLOAD_DIR, f"vocoder_in_{uid}.wav")
    out_path = os.path.join(OUTPUTS_DIR, f"vocoder_out_{uid}.wav")

    async with aiofiles.open(in_path, 'wb') as f:
        await f.write(await vocal.read())
        
    await vocoder_svc.apply_vocoder(in_path, chords_midi, out_path)
    return FileResponse(out_path, media_type="audio/wav", filename=f"vocoder_{uid}.wav")

@app.post("/api/ultimate/denoise")
async def api_denoise(audio: UploadFile = File(...)):
    import uuid
    uid = str(uuid.uuid4())
    in_path = os.path.join(UPLOAD_DIR, f"denoise_in_{uid}.wav")
    out_path = os.path.join(OUTPUTS_DIR, f"denoise_out_{uid}.wav")

    async with aiofiles.open(in_path, 'wb') as f:
        await f.write(await audio.read())
        
    await denoise_svc.clean_audio(in_path, out_path)
    return FileResponse(out_path, media_type="audio/wav", filename=f"denoise_{uid}.wav")

@app.get("/api/ultimate/midi/{genre}/{key}")
async def api_generate_midi(genre: str, key: str):
    import uuid
    uid = str(uuid.uuid4())
    out_path = os.path.join(OUTPUTS_DIR, f"midi_{uid}.mid")
    midi_svc.generate_progression(genre, key, out_path)
    return FileResponse(out_path, media_type="audio/midi", filename=f"progression_{genre}.mid")

@app.post("/api/ultimate/cratedigger")
async def api_cratedigger(path: str = Form(...)):
    results = crate_digger_svc.analyze_directory(path)
    return JSONResponse({"samples": results})

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)


