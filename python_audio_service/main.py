import os
import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import aiofiles
import uvicorn

from job_queue import create_job, get_job, worker_loop, JobStatus

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), 'temp/uploads')
os.makedirs(UPLOAD_DIR, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(worker_loop())
    logger.info("Aureon audio service started")
    yield
    task.cancel()


app = FastAPI(title="Aureon AI Music Service", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "aureon-audio"}


@app.post("/generate")
async def generate(
    beat: UploadFile = File(...),
    lyrics: str = Form(...),
    genre: str = Form("rap"),
    speaker_wav: UploadFile = File(None),
):
    if genre not in ["trap", "drill", "rap", "rnb", "pop"]:
        raise HTTPException(400, f"Invalid genre. Choose: trap, drill, rap, rnb, pop")

    beat_ext = os.path.splitext(beat.filename)[1].lower()
    if beat_ext not in [".mp3", ".wav", ".flac", ".ogg", ".m4a"]:
        raise HTTPException(400, "Beat must be mp3, wav, flac, ogg, or m4a")

    import uuid
    upload_id = str(uuid.uuid4())
    beat_path = os.path.join(UPLOAD_DIR, f"{upload_id}_beat{beat_ext}")

    async with aiofiles.open(beat_path, 'wb') as f:
        content = await beat.read()
        await f.write(content)

    speaker_path = None
    if speaker_wav:
        spk_ext = os.path.splitext(speaker_wav.filename)[1].lower()
        speaker_path = os.path.join(UPLOAD_DIR, f"{upload_id}_speaker{spk_ext}")
        async with aiofiles.open(speaker_path, 'wb') as f:
            content = await speaker_wav.read()
            await f.write(content)

    job_id = create_job(beat_path, lyrics, genre, speaker_path)
    return JSONResponse({"job_id": job_id, "status": "queued"})


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
        "output_ready": job.status == JobStatus.DONE,
    }


@app.get("/download/{job_id}")
async def download(job_id: str):
    job = get_job(job_id)
    if not job:
        raise HTTPException(404, "Job not found")
    if job.status != JobStatus.DONE or not job.output_path:
        raise HTTPException(400, f"Job not complete. Status: {job.status}")
    if not os.path.exists(job.output_path):
        raise HTTPException(500, "Output file missing")
    return FileResponse(
        job.output_path,
        media_type="audio/mpeg",
        filename=f"aureon_{job_id}.mp3",
    )


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
