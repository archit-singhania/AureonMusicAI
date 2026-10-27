"""Authenticated studio API. Durable jobs and versioned edits, no simulated inference."""

import asyncio, hashlib, hmac, importlib.util, json, os, re, secrets, time, zipfile
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Literal
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import delete, select, or_
import audio_engine as audio
from arrangement import Arrangement, render as render_arrangement
import reference_audio
import mastering_quality as quality_tools
from take_comping import TakeGroup
import release_kit as release_tools
from settings import ASSETS, DATA, INTERNAL_KEY, MAX_UPLOAD, ORIGINS, REDIS_URL
from store import (
    AuthSession,
    Document,
    Event,
    User,
    create,
    emit,
    identifier,
    issue_token,
    lookup_token,
    password_hash,
    password_matches,
    public,
    replace,
    session,
)

DEFAULT_PARAMS = {
    "vocals_gain": 0.8,
    "drums_gain": 0.85,
    "bass_gain": 0.8,
    "other_gain": 0.8,
    "saturation": 0.1,
    "delay_mix": 0.1,
    "delay_ms": 180.0,
    "stereo_width": 0.5,
    "de_esser": 0.2,
    "target_lufs": -14.0,
}
secret_path = DATA / "media-signing.key"
if not secret_path.exists():
    secret_path.write_bytes(secrets.token_bytes(32))
MEDIA_SECRET = secret_path.read_bytes()


class Account(BaseModel):
    email: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=10, max_length=128)
    name: str = Field(default="Creator", min_length=1, max_length=80)

    @field_validator("email")
    @classmethod
    def valid_email(cls, value):
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", value):
            raise ValueError("Enter a valid email address.")
        return value.lower().strip()


class ArtStyle(BaseModel):
    template: Literal["halo", "wave", "minimal"] = "halo"
    accent: str = Field(default="#9877DE", pattern=r"^#[0-9A-Fa-f]{6}$")
    background: str = Field(default="#191C2B", pattern=r"^#[0-9A-Fa-f]{6}$")
    caption: str = Field(default="", max_length=80)


class ReferenceSettings(BaseModel):
    asset_id: str | None = Field(default=None, max_length=80)
    gain_db: float = Field(default=0, ge=-12, le=12)
    width: float = Field(default=1, ge=0, le=2)


class ProjectState(BaseModel):
    document_version: Literal[2] = 2
    arrangement: Arrangement | None = None
    reference: ReferenceSettings = Field(default_factory=ReferenceSettings)
    mastering_quality: quality_tools.QualitySettings = Field(default_factory=quality_tools.QualitySettings)
    take_groups: list[TakeGroup] = Field(default_factory=list, max_length=8)
    release_kit: release_tools.ReleaseSettings = Field(default_factory=release_tools.ReleaseSettings)
    title: str = Field(default="Untitled session", min_length=1, max_length=100)
    genre: Literal["rnb", "trap", "pop", "rap", "drill"] = "rnb"
    lyrics: str = Field(default="", max_length=8000)
    preset_id: str = "afterglow"
    beat_asset_id: str | None = None
    vocal_asset_id: str | None = None
    cover_asset_id: str | None = None
    bpm: float = Field(default=88, ge=40, le=220)
    key: str = Field(default="A minor", max_length=30)
    language: str = Field(default="en-IN", max_length=12)
    engine: Literal["instrumental", "recording", "sarvam", "xtts"] = "instrumental"
    separation_engine: Literal["spectral-dsp", "demucs"] = "spectral-dsp"
    beat_offset_ms: float = Field(default=0, ge=-5000, le=5000)
    beats_per_bar: Literal[3, 4, 6, 8] = 4
    artwork: ArtStyle = Field(default_factory=ArtStyle)
    params: dict[str, float | bool] = Field(
        default_factory=lambda: dict(DEFAULT_PARAMS)
    )

    @field_validator("params")
    @classmethod
    def valid_params(cls, values):
        bounds = {
            **{f"{n}_gain": (0, 2) for n in audio.STEM_NAMES},
            "saturation": (0, 1),
            "delay_mix": (0, 0.8),
            "delay_ms": (20, 1000),
            "stereo_width": (0, 1),
            "de_esser": (0, 1),
            "target_lufs": (-24, -9),
        }
        for k, v in values.items():
            if k.endswith(("_mute", "_solo")) and k.split("_")[0] in audio.STEM_NAMES:
                if not isinstance(v, bool):
                    raise ValueError("Mute and solo must be booleans.")
            elif k not in bounds or not bounds[k][0] <= v <= bounds[k][1]:
                raise ValueError(f"Invalid DSP parameter {k}.")
        return values


class ProjectSave(BaseModel):
    revision: int = Field(ge=1)
    state: ProjectState
    action: str = Field(default="Saved session", max_length=120)


class JobStart(BaseModel):
    kind: Literal["generate", "remix", "video", "mp3", "arrangement_render", "reference_analysis", "reference_render", "comp_render", "release_kit", "mastering_analysis"] = "generate"
    source_master_asset_id: str | None = Field(default=None, max_length=80)
    take_group_id: str | None = Field(default=None, max_length=80)
    confirm_rights: bool = False


class Prompt(BaseModel):
    prompt: str = Field(min_length=1, max_length=2000)
    context: str = Field(default="", max_length=8000)


class Publish(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    description: str = Field(default="", max_length=1000)


class Comment(BaseModel):
    text: str = Field(min_length=1, max_length=500)


class Invite(BaseModel):
    code: str = Field(min_length=8, max_length=80)


class Revision(BaseModel):
    revision: int = Field(ge=1)


class VoiceProfile(BaseModel):
    asset_id: str
    name: str = Field(min_length=1, max_length=80)
    language: str = Field(default="en-IN", max_length=12)


def user(authorization: str = Header(default="")):
    result = (
        lookup_token(authorization.removeprefix("Bearer ").strip())
        if authorization
        else None
    )
    if not result:
        raise HTTPException(401, "Sign in to continue.")
    return result


def owned(db, doc_id, owner, kind=None):
    doc = db.get(Document, doc_id) if doc_id else None
    if not doc or (kind and doc.kind != kind):
        raise HTTPException(404, "Item not found.")
    if doc.owner != owner:
        project_id = doc.id if doc.kind == "project" else doc.parent
        project = db.get(Document, project_id) if project_id else None
        member = project and (
            project.owner == owner
            or db.scalar(
                select(Document).where(
                    Document.kind == "member",
                    Document.parent == project_id,
                    Document.owner == owner,
                )
            )
        )
        if not member:
            raise HTTPException(404, "Item not found.")
    return doc


def validate_project_assets(db, state, owner):
    if len({g.id for g in state.take_groups}) != len(state.take_groups):
        raise HTTPException(422, "Take bank identifiers must be unique.")
    for group in state.take_groups:
        for aid in group.asset_ids:
            take = owned(db, aid, owner, "asset")
            if not take.data.get("media_type", "").startswith("audio/"):
                raise HTTPException(422, "Take banks require audio assets.")
    if state.reference.asset_id:
        reference = owned(db, state.reference.asset_id, owner, "asset")
        if not reference.data.get("media_type", "").startswith("audio/"):
            raise HTTPException(422, "References require an owned audio asset.")
    for aid in (state.beat_asset_id, state.vocal_asset_id, state.cover_asset_id):
        if aid:
            owned(db, aid, owner, "asset")
    if state.arrangement:
        for track in state.arrangement.tracks:
            for clip in track.clips:
                doc = owned(db, clip.asset_id, owner, "asset")
                if not doc.data.get("media_type", "").startswith("audio/"):
                    raise HTTPException(422, "Arrangement clips require audio assets.")


def signed_asset(doc):
    expires = int(time.time()) + 3600
    signature = hmac.new(
        MEDIA_SECRET, f"{doc.id}:{expires}".encode(), hashlib.sha256
    ).hexdigest()
    data = public(doc)
    data.pop("path", None)
    data["url"] = (
        f"/api/v1/assets/{doc.id}/content?expires={expires}&signature={signature}"
    )
    return data


def asset(db, owner, project_id, path, name, mime, measured=True):
    info = audio.metrics(path) if measured and mime.startswith("audio") else {}
    from media_store import persist

    persist(path)
    return create(
        db,
        "asset",
        owner,
        {
            "name": name,
            "path": str(Path(path).resolve()),
            "media_type": mime,
            "metrics": info,
        },
        project_id,
    )


def safe_path(doc):
    path = Path(doc.data["path"]).resolve()
    if not path.is_relative_to(ASSETS):
        raise HTTPException(404, "Media is unavailable.")
    from media_store import recover

    recover(path)
    if not path.exists():
        raise HTTPException(404, "Media is unavailable.")
    return path


def progress(job_id, status=None, value=None, **changes):
    cancelled = False
    with session() as db:
        job = db.get(Document, job_id)
        if job.data.get("cancel_requested"):
            replace(
                db, job, {**job.data, "status": "cancelled", "finished_at": time.time()}
            )
            emit(db, job, "job.cancelled")
            cancelled = True
        else:
            data = {**job.data, **changes, "heartbeat": time.time()}
            if status is not None:
                data["status"] = status
            if value is not None:
                data["progress"] = value
            replace(db, job, data)
            emit(db, job, "job.progress")
    if cancelled:
        raise InterruptedError()


def voice(state, output):
    if not state["lyrics"].strip():
        raise ValueError("Add lyrics before synthesizing a vocal.")
    if state["engine"] == "sarvam":
        if not os.getenv("SARVAM_API_KEY"):
            raise ValueError(
                "Sarvam requires a provider key. Choose instrumental or your own recording."
            )
        from services.vocal_gen.sarvam_service import synthesize_sarvam_vocal

        if not synthesize_sarvam_vocal(
            state["lyrics"],
            str(output),
            genre=state["genre"],
            language_code=state["language"],
        ):
            raise ValueError(
                "Sarvam synthesis failed; no substitute vocal was generated."
            )
    else:
        if not importlib.util.find_spec("TTS"):
            raise ValueError("XTTS is not installed in this worker.")
        from TTS.api import TTS

        model = TTS(
            os.getenv("XTTS_MODEL", "tts_models/multilingual/multi-dataset/xtts_v2")
        )
        model.tts_to_file(
            text=state["lyrics"],
            speaker="Ana Florence",
            language=state["language"].split("-")[0],
            file_path=str(output),
        )


def process(job_id):
    with session() as db:
        job = db.get(Document, job_id)
        state, kind, owner, pid, source_id = (
            job.data["state"],
            job.data["job_kind"],
            job.owner,
            job.parent,
            job.data.get("source_job_id"),
        )
    directory = ASSETS / job_id
    directory.mkdir(exist_ok=True)
    try:
        if kind == "mastering_analysis":
            with session() as db:
                source = owned(db, source_id, owner, "job")
                source_master = source.data["master_asset_id"]
                master_path = safe_path(owned(db, source_master, owner, "asset"))
            progress(job_id, "analyzing", 10)
            last_check = 0.0
            def check_quality():
                nonlocal last_check
                now = time.monotonic()
                if now - last_check >= .5:
                    progress(job_id)
                    last_check = now
            report = quality_tools.analyze(master_path, quality_tools.QualitySettings.model_validate(state["mastering_quality"]), check=check_quality)
            report_path = directory / "mastering-report.json"
            report_path.write_text(json.dumps(report, allow_nan=False, indent=2), encoding="utf-8")
            with session() as db:
                report_id = asset(db, owner, pid, report_path, "Mastering quality report", "application/json", False).id
            progress(job_id, "done", 100, quality_report=report, report_asset_id=report_id, source_master_asset_id=source_master, finished_at=time.time())
        elif kind == "release_kit":
            with session() as db:
                source = owned(db, source_id, owner, "job")
                master_path = safe_path(owned(db, source.data["master_asset_id"], owner, "asset"))
            progress(job_id, "rendering", 15)
            archive, names = release_tools.build(state, master_path, directory, check=lambda: progress(job_id))
            with session() as db:
                bundle_id = asset(db, owner, pid, archive, "Release kit", "application/zip", False).id
                outputs = {name: asset(db, owner, pid, directory/name, name, "video/mp4" if name.endswith('.mp4') else "image/png", False).id for name in names if name.endswith(('.png','.mp4'))}
            progress(job_id, "done", 100, bundle_asset_id=bundle_id, output_asset_ids=outputs, finished_at=time.time())
        elif kind in ("reference_analysis", "reference_render"):
            with session() as db:
                source = owned(db, source_id, owner, "job")
                master_path = safe_path(owned(db, source.data["master_asset_id"], owner, "asset"))
                ref_path = safe_path(owned(db, state["reference"]["asset_id"], owner, "asset"))
            progress(job_id, "analyzing" if kind == "reference_analysis" else "rendering", 15)
            if kind == "reference_analysis":
                result, previews = reference_audio.compare(master_path, ref_path, directory, check=lambda: progress(job_id))
                with session() as db:
                    preview_ids = [asset(db, owner, pid, path, name, "audio/wav").id for path, name in zip(previews, ("Matched master", "Matched reference"))]
                progress(job_id, "done", 100, comparison=result, audition_asset_ids=preview_ids, source_master_asset_id=source.data["master_asset_id"], reference_asset_id=state["reference"]["asset_id"], finished_at=time.time())
            else:
                output = reference_audio.render(master_path, directory / "reference-match.wav", state["reference"]["gain_db"], state["reference"]["width"], check=lambda: progress(job_id))
                with session() as db:
                    master_id = asset(db, owner, pid, output, state["title"] + " · reference adjustment", "audio/wav").id
                progress(job_id, "done", 100, master_asset_id=master_id, stem_asset_ids={}, finished_at=time.time())
        elif kind in ("arrangement_render", "comp_render"):
            if kind == "comp_render":
                with session() as db:
                    group_id = db.get(Document, job_id).data.get("take_group_id")
                group = next((g for g in state["take_groups"] if g["id"] == group_id), None)
                if not group:
                    raise ValueError("The selected take bank is unavailable.")
                document = TakeGroup.model_validate(group).arrangement()
            else:
                document = state.get("arrangement")
            if not document:
                raise ValueError("Save an arrangement before rendering.")
            with session() as db:
                sources = {c["asset_id"]: safe_path(owned(db, c["asset_id"], owner, "asset")) for t in document["tracks"] for c in t["clips"]}
            progress(job_id, "rendering", 15)
            output = render_arrangement(document, sources, directory / "arrangement.wav", check=lambda: progress(job_id))
            progress(job_id, "rendering", 90)
            with session() as db:
                master_id = asset(db, owner, pid, output, state["title"] + " · arrangement", "audio/wav").id
            progress(job_id, "done", 100, master_asset_id=master_id, stem_asset_ids={}, finished_at=time.time(), render_scope="Sample-based edits and volume/pan automation; render-first preview")
        elif kind == "generate":
            progress(job_id, "analyzing", 10)
            if state.get("beat_asset_id"):
                with session() as db:
                    beat_path = str(
                        safe_path(owned(db, state["beat_asset_id"], owner, "asset"))
                    )
                detected = audio.analysis(beat_path)
                progress(job_id, "separating", 25)
                stems, separation = audio.separate(
                    beat_path, directory, state.get("separation_engine", "spectral-dsp")
                )
            else:
                beat_path, stems, preset = audio.synthesize_preset(
                    state["preset_id"], directory, bpm=state["bpm"], key=state["key"]
                )
                detected = {
                    "bpm": preset["bpm"],
                    "key": preset["key"],
                    "key_confidence": 1,
                    "analysis_method": "preset composition metadata",
                }
                separation = "original synthesized instrument stems"
            progress(job_id, "vocals", 50, analysis=detected, separation=separation)
            if state["engine"] == "recording":
                with session() as db:
                    y, sr = audio.read_audio(
                        safe_path(
                            owned(db, state.get("vocal_asset_id"), owner, "asset")
                        )
                    )
                stems["vocals"] = audio.write_audio(directory / "vocals.wav", y, sr)
            elif state["engine"] in ("sarvam", "xtts"):
                voice(state, directory / "vocals.wav")
                stems["vocals"] = str(directory / "vocals.wav")
            progress(job_id, "mixing", 75)
            output = audio.render_mix(stems, state["params"], directory / "master.wav")
            with session() as db:
                stem_ids = {
                    name: asset(
                        db, owner, pid, path, name.title(), "audio/wav", False
                    ).id
                    for name, path in stems.items()
                }
                master_id = asset(
                    db, owner, pid, output, state["title"], "audio/wav"
                ).id
            progress(
                job_id,
                "done",
                100,
                master_asset_id=master_id,
                stem_asset_ids=stem_ids,
                finished_at=time.time(),
            )
        else:
            with session() as db:
                source = db.get(Document, source_id)
                if not source or source.data.get("status") != "done":
                    raise ValueError("Generate a complete master first.")
                source_path = safe_path(
                    db.get(Document, source.data["master_asset_id"])
                )
                stem_ids = source.data.get("stem_asset_ids", {})
                stems = {
                    n: str(safe_path(db.get(Document, aid)))
                    for n, aid in stem_ids.items()
                }
            progress(job_id, "rendering", 20)
            if kind == "remix":
                output, mime = (
                    audio.render_mix(stems, state["params"], directory / "remix.wav"),
                    "audio/wav",
                )
            elif kind == "video":
                output, mime = (
                    audio.video(source_path, directory / "visualizer.mp4"),
                    "video/mp4",
                )
            else:
                output, mime = (
                    audio.export_mp3(source_path, directory / "master.mp3"),
                    "audio/mpeg",
                )
            progress(job_id, "rendering", 90)
            with session() as db:
                result_id = asset(
                    db, owner, pid, output, state["title"], mime, kind == "remix"
                ).id
            progress(
                job_id,
                "done",
                100,
                master_asset_id=result_id,
                stem_asset_ids=stem_ids,
                finished_at=time.time(),
            )
    except InterruptedError:
        pass
    except Exception as error:
        with session() as db:
            job = db.get(Document, job_id)
            cancelled = bool(job.data.get("cancel_requested"))
            replace(
                db,
                job,
                {
                    **job.data,
                    "status": "cancelled" if cancelled else "failed",
                    "error": None if cancelled else str(error)[:600],
                    "finished_at": time.time(),
                },
            )
            emit(db, job, "job.cancelled" if cancelled else "job.failed")


async def worker():
    while True:
        job_id = None
        with session() as db:
            for job in db.scalars(
                select(Document)
                .where(Document.kind == "job")
                .order_by(Document.created)
            ):
                stale = (
                    job.data.get("status")
                    in ("analyzing", "separating", "vocals", "mixing", "rendering")
                    and time.time() - job.data.get("heartbeat", job.updated) > 600
                )
                if job.data.get("status") == "queued" or stale:
                    try:
                        replace(
                            db,
                            job,
                            {
                                **job.data,
                                "status": "analyzing",
                                "heartbeat": time.time(),
                                "error": None,
                            },
                        )
                        job_id = job.id
                    except ValueError:
                        continue
                    break
        if job_id:
            await asyncio.to_thread(process, job_id)
        elif REDIS_URL:

            def wait_for_work():
                try:
                    import redis

                    redis.Redis.from_url(
                        REDIS_URL, socket_timeout=2, socket_connect_timeout=1
                    ).blpop("aureon:work", timeout=1)
                except Exception:
                    time.sleep(0.4)

            await asyncio.to_thread(wait_for_work)
        else:
            await asyncio.sleep(0.4)


@asynccontextmanager
async def lifespan(app):
    task = asyncio.create_task(worker())
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


app = FastAPI(title="Aureon Studio", version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ORIGINS,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
    allow_credentials=False,
)


@app.exception_handler(ValueError)
async def value_error(request, error):
    return JSONResponse(
        status_code=409 if "another device" in str(error) else 400,
        content={"detail": str(error)},
    )


@app.get("/health")
@app.get("/api/v1/health")
def health():
    return {
        "status": "ok",
        "database": "postgresql"
        if os.getenv("DATABASE_URL", "").startswith("postgres")
        else "sqlite",
        "ffmpeg": bool(audio.ffmpeg()),
    }


@app.get("/api/v1/capabilities")
def capabilities():
    return {
        "instrumental": True,
        "recording": True,
        "sarvam": bool(os.getenv("SARVAM_API_KEY")),
        "xtts": bool(importlib.util.find_spec("TTS")),
        "lyric_ai": bool(os.getenv("OLLAMA_URL")),
        "mp3": bool(audio.ffmpeg()),
        "video": bool(audio.ffmpeg()),
        "separation": "spectral-dsp",
        "demucs": bool(importlib.util.find_spec("demucs")),
        "experimental": {
            k: "unavailable" for k in ("musicgen", "rvc", "vocoder", "midi", "ableton")
        },
        "providers_note": "Configured providers can fail or incur costs. Speech synthesis is not a singing model.",
    }


@app.post("/api/v1/auth/register", status_code=201)
def register(body: Account):
    with session() as db:
        if db.scalar(select(User).where(User.email == body.email)):
            raise HTTPException(409, "Email is already registered.")
        u = User(
            id=identifier(),
            email=body.email,
            name=body.name.strip(),
            password=password_hash(body.password),
        )
        db.add(u)
        db.flush()
        return {
            "token": issue_token(db, u.id),
            "user": {"id": u.id, "name": u.name, "email": u.email},
        }


@app.post("/api/v1/auth/login")
def login(body: Account):
    with session() as db:
        u = db.scalar(select(User).where(User.email == body.email))
        if not u or not password_matches(body.password, u.password):
            raise HTTPException(401, "Email or password is incorrect.")
        return {
            "token": issue_token(db, u.id),
            "user": {"id": u.id, "name": u.name, "email": u.email},
        }


@app.get("/api/v1/auth/me")
def me(current=Depends(user)):
    return {"id": current.id, "name": current.name, "email": current.email}


@app.post("/api/v1/auth/logout")
def logout(authorization: str = Header(default=""), current=Depends(user)):
    with session() as db:
        db.execute(
            delete(AuthSession).where(
                AuthSession.token_hash
                == hashlib.sha256(
                    authorization.removeprefix("Bearer ").encode()
                ).hexdigest()
            )
        )
    return {"status": "signed_out"}


@app.post("/api/v1/demo", status_code=201)
def demo():
    with session() as db:
        u = User(
            id=identifier(),
            email=f"{identifier()}@demo.aureon.local",
            name="Guest creator",
            password=password_hash(secrets.token_urlsafe(30)),
        )
        db.add(u)
        db.flush()
        p = create(
            db,
            "project",
            u.id,
            {
                **ProjectState(
                    title="Afterglow Sessions",
                    lyrics="A little light in the midnight air\nA rhythm only we can share",
                ).model_dump(),
                "invite_code": secrets.token_urlsafe(12),
            },
        )
        j = create(
            db,
            "job",
            u.id,
            {
                "job_kind": "generate",
                "status": "queued",
                "progress": 0,
                "state": ProjectState.model_validate(p.data).model_dump(),
            },
            p.id,
        )
        return {
            "token": issue_token(db, u.id),
            "user": {"id": u.id, "name": u.name, "email": u.email},
            "project": public(p),
            "job": public(j),
        }


@app.get("/api/v1/presets")
def presets():
    return audio.PRESETS


@app.get("/api/v1/presets/{preset_id}/preview")
def preview(preset_id):
    if preset_id not in [p["id"] for p in audio.PRESETS]:
        raise HTTPException(404, "Preset not found.")
    directory = ASSETS / "previews" / preset_id
    path = directory / "beat.wav"
    if not path.exists():
        directory.mkdir(parents=True, exist_ok=True)
        audio.synthesize_preset(preset_id, directory, 4)
    return FileResponse(path, media_type="audio/wav")


@app.get("/api/v1/projects")
def projects(current=Depends(user)):
    with session() as db:
        docs = list(
            db.scalars(
                select(Document)
                .where(Document.kind == "project", Document.owner == current.id)
                .order_by(Document.updated.desc())
            )
        )
        docs += [
            db.get(Document, m.parent)
            for m in db.scalars(
                select(Document).where(
                    Document.kind == "member", Document.owner == current.id
                )
            )
        ]
        return [public(d) for d in docs if d and not d.data.get("archived")]


@app.post("/api/v1/projects", status_code=201)
def create_project(body: ProjectState, current=Depends(user)):
    with session() as db:
        validate_project_assets(db, body, current.id)
        p = create(
            db,
            "project",
            current.id,
            {**body.model_dump(), "invite_code": secrets.token_urlsafe(12)},
        )
        emit(db, p, "project.created")
        return public(p)


@app.get("/api/v1/projects/{pid}")
def project(pid, current=Depends(user)):
    with session() as db:
        return public(owned(db, pid, current.id, "project"))


def edit_history(db, project):
    history = db.scalar(
        select(Document).where(
            Document.kind == "edit_history", Document.parent == project.id
        )
    )
    return history or create(
        db, "edit_history", project.owner, {"undo": [], "redo": []}, project.id
    )


def snapshot(db, project, author, action):
    return create(
        db,
        "version",
        project.owner,
        {
            "action": action,
            "state": ProjectState.model_validate(project.data).model_dump(),
            "author": author,
        },
        project.id,
    )


def remember_edit(db, project, version):
    history = edit_history(db, project)
    replace(
        db, history, {"undo": (history.data["undo"] + [version.id])[-100:], "redo": []}
    )


@app.get("/api/v1/projects/{pid}/history")
def history_status(pid, current=Depends(user)):
    with session() as db:
        project = owned(db, pid, current.id, "project")
        data = edit_history(db, project).data
        return {"can_undo": bool(data["undo"]), "can_redo": bool(data["redo"])}

@app.post("/api/v1/projects/{pid}/arrangement/init")
def initialize_arrangement(pid, body: Revision, current=Depends(user)):
    import math
    import soundfile as sf
    with session() as db:
        project = owned(db, pid, current.id, "project")
        if project.revision != body.revision:
            raise HTTPException(409, "Project changed. Reopen before migrating arrangement.")
        if project.data.get("arrangement") is not None:
            return public(project)
        master = next((j for j in db.scalars(select(Document).where(Document.kind == "job", Document.parent == pid).order_by(Document.created.desc())) if j.data.get("status") == "done" and j.data.get("job_kind") in ("generate", "remix", "arrangement_render", "reference_render", "comp_render")), None)
        if not master:
            raise HTTPException(409, "Create a master before initializing its arrangement.")
        source = owned(db, master.data["master_asset_id"], current.id, "asset")
        info = sf.info(safe_path(source))
        length = math.ceil(info.frames * 44100 / info.samplerate)
        document = Arrangement.model_validate({"tracks": [{"id": identifier(), "name": "Original master", "clips": [{"id": identifier(), "asset_id": source.id, "start": 0, "source_start": 0, "length": length}]}]}).model_dump()
        remember_edit(db, project, snapshot(db, project, current.name, "Before arrangement migration"))
        replace(db, project, {**project.data, "document_version": 2, "arrangement": document}, body.revision)
        emit(db, project, "project.saved")
        return public(project)


def navigate_history(pid, body, current, direction):
    with session() as db:
        project = owned(db, pid, current.id, "project")
        if project.revision != body.revision:
            raise HTTPException(
                409, "This session changed on another device. Reopen before undo/redo."
            )
        history = edit_history(db, project)
        data = {key: list(value) for key, value in history.data.items()}
        if not data[direction]:
            raise HTTPException(409, f"No saved edit to {direction}.")
        target = db.get(Document, data[direction].pop())
        previous = snapshot(db, project, current.name, f"Before {direction}")
        other = "redo" if direction == "undo" else "undo"
        data[other] = (data[other] + [previous.id])[-100:]
        replace(db, history, data)
        replace(
            db,
            project,
            {**target.data["state"], "invite_code": project.data["invite_code"]},
            body.revision,
        )
        emit(db, project, f"project.{direction}")
        return {
            **public(project),
            "can_undo": bool(data["undo"]),
            "can_redo": bool(data["redo"]),
        }


@app.post("/api/v1/projects/{pid}/undo")
def undo(pid, body: Revision, current=Depends(user)):
    return navigate_history(pid, body, current, "undo")


@app.post("/api/v1/projects/{pid}/redo")
def redo(pid, body: Revision, current=Depends(user)):
    return navigate_history(pid, body, current, "redo")


@app.put("/api/v1/projects/{pid}")
def save(pid, body: ProjectSave, current=Depends(user)):
    with session() as db:
        p = owned(db, pid, current.id, "project")
        validate_project_assets(db, body.state, current.id)
        remember_edit(db, p, snapshot(db, p, current.name, body.action))
        replace(
            db,
            p,
            {**body.state.model_dump(), "invite_code": p.data["invite_code"]},
            body.revision,
        )
        emit(db, p, "project.saved")
        return public(p)


@app.delete("/api/v1/projects/{pid}")
def archive(pid, current=Depends(user)):
    with session() as db:
        p = owned(db, pid, current.id, "project")
        if p.owner != current.id:
            raise HTTPException(403, "Only the owner can archive.")
        replace(db, p, {**p.data, "archived": True})
    return {"status": "archived"}


@app.get("/api/v1/projects/{pid}/versions")
def versions(pid, current=Depends(user)):
    with session() as db:
        owned(db, pid, current.id, "project")
        return [
            public(d)
            for d in db.scalars(
                select(Document)
                .where(Document.kind == "version", Document.parent == pid)
                .order_by(Document.created.desc())
                .limit(100)
            )
        ]


@app.post("/api/v1/projects/{pid}/restore/{vid}")
def restore(pid, vid, current=Depends(user)):
    with session() as db:
        p, v = (
            owned(db, pid, current.id, "project"),
            owned(db, vid, current.id, "version"),
        )
        if v.parent != pid:
            raise HTTPException(404, "Version not found.")
        remember_edit(db, p, snapshot(db, p, current.name, "Before restore"))
        replace(db, p, {**v.data["state"], "invite_code": p.data["invite_code"]})
        emit(db, p, "project.restored")
        return public(p)


@app.post("/api/v1/assets", status_code=201)
async def upload(
    file: UploadFile = File(...),
    project_id: str = "",
    consent: bool = False,
    current=Depends(user),
):
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in (
        ".wav",
        ".mp3",
        ".m4a",
        ".ogg",
        ".flac",
        ".webm",
        ".png",
        ".jpg",
        ".jpeg",
    ):
        raise HTTPException(415, "Upload supported audio, PNG or JPEG.")
    with session() as db:
        if project_id:
            owned(db, project_id, current.id, "project")
    directory = ASSETS / identifier()
    directory.mkdir()
    path = directory / ("source" + suffix)
    size = 0
    try:
        with path.open("wb") as f:
            while data := await file.read(1024 * 1024):
                size += len(data)
                if size > MAX_UPLOAD:
                    raise HTTPException(413, "Maximum upload size is 50 MB.")
                f.write(data)
        image = suffix in (".png", ".jpg", ".jpeg")
        if image:
            from PIL import Image

            try:
                with Image.open(path) as cover:
                    if cover.width > 4096 or cover.height > 4096:
                        raise ValueError(
                            "Artwork must be at most 4096 pixels on each side."
                        )
                    cover.verify()
            except (OSError, Image.DecompressionBombError) as error:
                raise ValueError("Upload a valid PNG or JPEG image.") from error
            mime = "image/png" if suffix == ".png" else "image/jpeg"
        else:
            y, sr = await asyncio.to_thread(audio.read_audio, path)
            path = Path(audio.write_audio(directory / "source.wav", y, sr))
            mime = "audio/wav"
        with session() as db:
            a = asset(
                db, current.id, project_id, path, file.filename or "Recording", mime
            )
            a.data = {**a.data, "consented": consent, "size": size}
            return signed_asset(a)
    except Exception:
        import shutil

        shutil.rmtree(directory, ignore_errors=True)
        raise


@app.get("/api/v1/assets/{aid}/arrangement-metadata")
def arrangement_metadata(aid, current=Depends(user)):
    import math
    import soundfile as sf
    with session() as db:
        source = owned(db, aid, current.id, "asset")
        if not source.data.get("media_type", "").startswith("audio/"):
            raise HTTPException(422, "Choose an audio source.")
        info = sf.info(safe_path(source))
        return {"sample_count": math.ceil(info.frames * 44100 / info.samplerate), "sample_rate": 44100}

@app.get("/api/v1/assets")
def assets(current=Depends(user)):
    with session() as db:
        pids = list(
            db.scalars(
                select(Document.id).where(
                    Document.kind == "project", Document.owner == current.id
                )
            )
        )
        pids += list(
            db.scalars(
                select(Document.parent).where(
                    Document.kind == "member", Document.owner == current.id
                )
            )
        )
        query = (
            select(Document)
            .where(
                Document.kind == "asset",
                or_(Document.owner == current.id, Document.parent.in_(pids)),
            )
            .order_by(Document.created.desc())
            .limit(100)
        )
        return [signed_asset(a) for a in db.scalars(query)]


@app.get("/api/v1/assets/{aid}")
def get_asset(aid, current=Depends(user)):
    with session() as db:
        return signed_asset(owned(db, aid, current.id, "asset"))


@app.get("/api/v1/voice-profiles")
def voice_profiles(current=Depends(user)):
    with session() as db:
        return [
            public(p)
            for p in db.scalars(
                select(Document)
                .where(Document.kind == "voice_profile", Document.owner == current.id)
                .order_by(Document.created.desc())
            )
        ]


@app.post("/api/v1/voice-profiles", status_code=201)
def create_voice_profile(body: VoiceProfile, current=Depends(user)):
    with session() as db:
        take = owned(db, body.asset_id, current.id, "asset")
        if (
            take.owner != current.id
            or not take.data.get("consented")
            or not take.data["media_type"].startswith("audio/")
        ):
            raise HTTPException(
                403, "Use your own consented recording to create a voice profile."
            )
        return public(
            create(
                db,
                "voice_profile",
                current.id,
                {
                    **body.model_dump(),
                    "consented": True,
                    "metrics": take.data.get("metrics", {}),
                },
            )
        )


@app.post("/api/v1/projects/{pid}/voice-profiles/{profile_id}/use")
def reuse_voice_profile(pid, profile_id, current=Depends(user)):
    import shutil

    with session() as db:
        owned(db, pid, current.id, "project")
        profile = owned(db, profile_id, current.id, "voice_profile")
        take = owned(db, profile.data["asset_id"], current.id, "asset")
        directory = ASSETS / identifier()
        directory.mkdir()
        output = directory / "voice-take.wav"
        shutil.copyfile(safe_path(take), output)
        result = asset(db, current.id, pid, output, profile.data["name"], "audio/wav")
        result.data = {**result.data, "consented": True, "voice_profile_id": profile.id}
        return signed_asset(result)


@app.delete("/api/v1/voice-profiles/{profile_id}")
def delete_voice_profile(profile_id, current=Depends(user)):
    with session() as db:
        db.delete(owned(db, profile_id, current.id, "voice_profile"))
    return {"status": "removed", "recording_retained": True}


@app.get("/api/v1/assets/{aid}/content")
def content(
    aid, expires: int = 0, signature: str = "", authorization: str = Header(default="")
):
    expected = hmac.new(
        MEDIA_SECRET, f"{aid}:{expires}".encode(), hashlib.sha256
    ).hexdigest()
    signed = (
        expires >= time.time()
        and expires <= time.time() + 3601
        and hmac.compare_digest(signature, expected)
    )
    with session() as db:
        doc = (
            db.get(Document, aid)
            if signed
            else owned(db, aid, user(authorization).id, "asset")
        )
        if not doc or doc.kind != "asset":
            raise HTTPException(404, "Media not found.")
        return FileResponse(
            safe_path(doc),
            media_type=doc.data["media_type"],
            filename=Path(doc.data["path"]).name,
        )


@app.post("/api/v1/assets/{aid}/analyze")
async def analyze(aid, current=Depends(user)):
    with session() as db:
        path = safe_path(owned(db, aid, current.id, "asset"))
    result = await asyncio.to_thread(audio.analysis, path)
    with session() as db:
        a = db.get(Document, aid)
        replace(db, a, {**a.data, "analysis": result})
    return result


@app.post("/api/v1/projects/{pid}/jobs", status_code=202)
def start(
    pid,
    body: JobStart,
    idempotency_key: str = Header(default=""),
    current=Depends(user),
):
    with session() as db:
        p = owned(db, pid, current.id, "project")
        jobs = list(
            db.scalars(
                select(Document)
                .where(Document.kind == "job", Document.parent == pid)
                .order_by(Document.created.desc())
            )
        )
        existing = next(
            (
                j
                for j in jobs
                if idempotency_key and j.data.get("idempotency_key") == idempotency_key
            ),
            None,
        )
        if existing:
            return public(existing)
        if (
            sum(
                j.data.get("status") not in ("done", "failed", "cancelled")
                for j in jobs
            )
            >= 3
        ):
            raise HTTPException(429, "Wait for an active render.")
        source = next(
            (
                j
                for j in jobs
                if j.data.get("status") == "done"
                and j.data.get("job_kind") in ("generate", "remix", "arrangement_render", "reference_render", "comp_render")
            ),
            None,
        )
        if body.kind not in ("generate", "arrangement_render", "comp_render") and not source:
            raise HTTPException(409, "Generate a master first.")
        if body.kind == "remix" and not source.data.get("stem_asset_ids"):
            raise HTTPException(409, "This master has no separate stems. Generate a stem-based mix first.")
        state = ProjectState.model_validate(p.data).model_dump()
        if body.kind == "mastering_analysis" and body.source_master_asset_id != source.data.get("master_asset_id"):
            raise HTTPException(409, "The master changed. Select the current master before analysis.")
        if body.kind == "release_kit":
            if not body.confirm_rights:
                raise HTTPException(400, "Confirm credits and usage rights before exporting.")
            if body.source_master_asset_id != source.data.get("master_asset_id"):
                raise HTTPException(409, "The selected master changed. Review the export again.")
            if not state['release_kit']['artist'].strip() or not state['release_kit']['credits'].strip():
                raise HTTPException(422, "Enter artist and credits before exporting.")
        if body.kind == "comp_render":
            validate_project_assets(db, ProjectState.model_validate(p.data), current.id)
            group = next((g for g in state["take_groups"] if g["id"] == body.take_group_id), None)
            if not group or not group["phrases"]:
                raise HTTPException(422, "Select a take bank with phrase selections.")
        if body.kind in ("reference_analysis", "reference_render"):
            validate_project_assets(db, ProjectState.model_validate(p.data), current.id)
            if not state["reference"]["asset_id"]:
                raise HTTPException(422, "Select a private audio reference first.")
            if body.source_master_asset_id != source.data.get("master_asset_id"):
                raise HTTPException(409, "The master changed. Compare the current master before rendering.")
        if body.kind == "arrangement_render":
            validate_project_assets(db, ProjectState.model_validate(p.data), current.id)
            if not state.get("arrangement") or not any(t["clips"] for t in state["arrangement"]["tracks"]):
                raise HTTPException(422, "Save at least one arrangement clip before rendering.")
        if state["engine"] == "recording":
            recording = owned(db, state.get("vocal_asset_id"), current.id, "asset")
            if not recording.data.get("consented"):
                raise HTTPException(400, "Confirm permission to use this voice.")
        j = create(
            db,
            "job",
            p.owner,
            {
                "job_kind": body.kind,
                "status": "queued",
                "progress": 0,
                "state": state,
                "source_job_id": source.id if source else None,
                "take_group_id": body.take_group_id,
                "idempotency_key": idempotency_key,
            },
            pid,
        )
        emit(db, j, "job.queued")
        return public(j)


@app.get("/api/v1/jobs")
def jobs(project_id: str = "", current=Depends(user)):
    with session() as db:
        q = select(Document).where(Document.kind == "job")
        if project_id:
            owned(db, project_id, current.id, "project")
            q = q.where(Document.parent == project_id)
        else:
            q = q.where(Document.owner == current.id)
        return [
            public(d)
            for d in db.scalars(q.order_by(Document.created.desc()).limit(100))
        ]


@app.get("/api/v1/jobs/{jid}")
def job(jid, current=Depends(user)):
    with session() as db:
        return public(owned(db, jid, current.id, "job"))


@app.post("/api/v1/jobs/{jid}/cancel")
def cancel(jid, current=Depends(user)):
    with session() as db:
        j = owned(db, jid, current.id, "job")
        if j.data["status"] not in ("done", "failed", "cancelled"):
            replace(
                db,
                j,
                {
                    **j.data,
                    "cancel_requested": True,
                    "status": "cancelled"
                    if j.data["status"] == "queued"
                    else j.data["status"],
                },
            )
            emit(db, j, "job.cancel_requested")
        return public(j)


@app.post("/api/v1/jobs/{jid}/retry", status_code=202)
def retry(jid, current=Depends(user)):
    with session() as db:
        j = owned(db, jid, current.id, "job")
        if j.data["status"] not in ("failed", "cancelled"):
            raise HTTPException(409, "Only failed or cancelled jobs can be retried.")
        clone = create(
            db,
            "job",
            j.owner,
            {
                **j.data,
                "status": "queued",
                "progress": 0,
                "cancel_requested": False,
                "error": None,
                "retried_from": j.id,
                "idempotency_key": "",
            },
            j.parent,
        )
        emit(db, clone, "job.queued")
        return public(clone)


@app.get("/api/v1/jobs/{jid}/stems.zip")
def stems_zip(jid, current=Depends(user)):
    with session() as db:
        j = owned(db, jid, current.id, "job")
        if j.data["status"] != "done" or not j.data.get("stem_asset_ids"):
            raise HTTPException(409, "Stems are not ready.")
        directory = ASSETS / jid
        directory.mkdir(exist_ok=True)
        path = directory / "Aureon-stems.zip"
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
            for name, aid in j.data["stem_asset_ids"].items():
                archive.write(safe_path(db.get(Document, aid)), name + ".wav")
            archive.writestr(
                "session.json",
                json.dumps(
                    {
                        "title": j.data["state"]["title"],
                        "bpm": j.data["state"]["bpm"],
                        "key": j.data["state"]["key"],
                        "params": j.data["state"]["params"],
                    },
                    indent=2,
                ),
            )
        return FileResponse(
            path, media_type="application/zip", filename="Aureon-stems.zip"
        )


@app.post("/api/v1/lyrics")
async def lyrics(body: Prompt, current=Depends(user)):
    endpoint = os.getenv("OLLAMA_URL", "").rstrip("/")
    if not endpoint:
        raise HTTPException(
            503,
            "Lyric AI is not configured. Your editor and syllable guide remain available.",
        )
    import httpx

    try:
        async with httpx.AsyncClient(timeout=90) as client:
            r = await client.post(
                endpoint + "/api/generate",
                json={
                    "model": os.getenv("OLLAMA_MODEL", "qwen2.5:3b"),
                    "prompt": f"Write original song lyrics. Context: {body.context}\nInstruction: {body.prompt}",
                    "stream": False,
                    "think": False,
                    "options": {"num_predict": 384},
                },
            )
            r.raise_for_status()
            body = r.json()
            text = body.get("response") if isinstance(body, dict) else None
            if not isinstance(text, str) or not text.strip():
                raise ValueError("Lyric provider returned an empty response.")
            return {"lyrics": text.strip(), "source": "ollama"}
    except (httpx.HTTPError, ValueError, TypeError):
        raise HTTPException(
            503, "Lyric provider is unavailable. Your draft was preserved."
        )


@app.post("/api/v1/assets/{aid}/transcribe")
async def transcribe(aid, current=Depends(user)):
    if not os.getenv("SARVAM_API_KEY"):
        raise HTTPException(503, "Transcription requires a configured Sarvam key.")
    with session() as db:
        path = safe_path(owned(db, aid, current.id, "asset"))
    from services.vocal_gen.sarvam_service import transcribe_voice_prompt

    try:
        result = await asyncio.to_thread(transcribe_voice_prompt, str(path))
    except Exception as error:
        raise HTTPException(
            503, "Transcription provider is unavailable. Recording is preserved."
        ) from error
    if not result.get("transcript") or result.get("source") != "sarvam_saaras":
        raise HTTPException(503, "Transcription failed. Recording is preserved.")
    return result


@app.post("/api/v1/copilot")
def copilot(body: Prompt, current=Depends(user)):
    text, values, reasons = body.prompt.lower(), {}, []
    rules = [
        (
            ["warm", "tape", "vintage"],
            "saturation",
            0.5,
            "Add gentle harmonic saturation",
        ),
        (["wide", "stereo"], "stereo_width", 0.85, "Widen the side channel"),
        (["delay", "echo", "dreamy"], "delay_mix", 0.3, "Add stereo delay"),
        (["dry"], "delay_mix", 0, "Remove delay"),
        (["sibilance", "harsh", "smooth"], "de_esser", 0.7, "Reduce sibilance"),
        (["bass", "808"], "bass_gain", 1.1, "Raise the bass stem"),
        (["vocal", "voice"], "vocals_gain", 1, "Bring the voice forward"),
    ]
    for words, key, value, reason in rules:
        if any(word in text for word in words):
            values[key] = value
            reasons.append(reason)
    return {
        "params": values,
        "explanation": reasons or ["Try warmth, stereo width, delay, vocals or bass."],
        "source": "deterministic DSP assistant",
        "requires_confirmation": True,
    }


@app.post("/api/v1/projects/{pid}/artwork")
def artwork(pid, body: ArtStyle = ArtStyle(), current=Depends(user)):
    from PIL import Image, ImageDraw

    with session() as db:
        title = owned(db, pid, current.id, "project").data["title"]
    directory = ASSETS / identifier()
    directory.mkdir()
    path = directory / "artwork.png"
    image = Image.new("RGB", (1024, 1024), body.background)
    draw = ImageDraw.Draw(image)
    rgb = tuple(int(body.accent[i : i + 2], 16) for i in (1, 3, 5))
    if body.template == "halo":
        for i in range(120):
            r = 500 - i * 3
            draw.ellipse(
                (512 - r, 470 - r, 512 + r, 470 + r),
                fill=tuple(int(c * (0.35 + i / 185)) for c in rgb),
            )
    elif body.template == "wave":
        for x in range(100, 925, 22):
            height = int(70 + 200 * abs(__import__("math").sin(x / 75)))
            draw.rounded_rectangle(
                (x, 440 - height, x + 12, 440 + height), radius=6, fill=body.accent
            )
    else:
        draw.rounded_rectangle(
            (80, 90, 944, 770), radius=72, outline=body.accent, width=6
        )
    draw.line([(270, 650), (512, 200), (754, 650)], fill="#F6E9E0", width=26)
    for x, height in [(435, 90), (475, 150), (515, 210), (555, 150), (595, 90)]:
        draw.rounded_rectangle((x, 550 - height, x + 12, 550), radius=6, fill="#F6E9E0")
    draw.text((64, 880), title[:48], fill="white", font_size=40)
    draw.text((64, 945), body.caption, fill="white", font_size=24)
    image.save(path)
    with session() as db:
        return signed_asset(asset(db, current.id, pid, path, title, "image/png", False))


@app.post("/api/v1/projects/{pid}/join")
def join(pid, body: Invite, current=Depends(user)):
    with session() as db:
        p = db.get(Document, pid)
        if (
            not p
            or p.kind != "project"
            or not hmac.compare_digest(p.data.get("invite_code", ""), body.code)
        ):
            raise HTTPException(404, "This invitation is invalid.")
        if p.owner != current.id and not db.scalar(
            select(Document).where(
                Document.kind == "member",
                Document.parent == pid,
                Document.owner == current.id,
            )
        ):
            create(
                db, "member", current.id, {"name": current.name, "role": "editor"}, pid
            )
        return public(p)


@app.get("/api/v1/projects/{pid}/members")
def members(pid, current=Depends(user)):
    with session() as db:
        p = owned(db, pid, current.id, "project")
        owner = db.get(User, p.owner)
        return [{"id": owner.id, "name": owner.name, "role": "owner"}] + [
            {"id": m.owner, **m.data}
            for m in db.scalars(
                select(Document).where(
                    Document.kind == "member", Document.parent == pid
                )
            )
        ]


@app.delete("/api/v1/projects/{pid}/members/{uid}")
def remove_member(pid, uid, current=Depends(user)):
    with session() as db:
        project = owned(db, pid, current.id, "project")
        if project.owner != current.id:
            raise HTTPException(403, "Only the owner can remove collaborators.")
        db.execute(
            delete(Document).where(
                Document.kind == "member", Document.parent == pid, Document.owner == uid
            )
        )
        replace(db, project, {**project.data, "invite_code": secrets.token_urlsafe(12)})
        emit(db, project, "project.access_changed")
    return {"status": "removed"}


@app.post("/api/v1/projects/{pid}/publish", status_code=201)
def publish(pid, body: Publish, current=Depends(user)):
    with session() as db:
        p = owned(db, pid, current.id, "project")
        if p.owner != current.id:
            raise HTTPException(403, "Only the owner can publish.")
        validate_project_assets(db, ProjectState.model_validate(p.data), current.id)
        jobs = list(
            db.scalars(
                select(Document)
                .where(Document.kind == "job", Document.parent == pid)
                .order_by(Document.created.desc())
            )
        )
        master = next(
            (
                j
                for j in jobs
                if j.data.get("status") == "done"
                and j.data.get("job_kind") in ("generate", "remix", "arrangement_render", "reference_render", "comp_render")
            ),
            None,
        )
        if not master:
            raise HTTPException(409, "Generate a complete master before publishing.")
        return public(
            create(
                db,
                "publication",
                current.id,
                {
                    **body.model_dump(),
                    "artist": current.name,
                    "genre": p.data["genre"],
                    "master_asset_id": master.data["master_asset_id"],
                    "cover_asset_id": p.data.get("cover_asset_id"),
                },
                pid,
            )
        )


@app.get("/api/v1/showcase")
def showcase():
    with session() as db:
        result = []
        for p in db.scalars(
            select(Document)
            .where(Document.kind == "publication")
            .order_by(Document.created.desc())
            .limit(60)
        ):
            master = db.get(Document, p.data["master_asset_id"])
            cover = (
                db.get(Document, p.data.get("cover_asset_id"))
                if p.data.get("cover_asset_id")
                else None
            )
            likes = list(
                db.scalars(
                    select(Document).where(
                        Document.kind == "like", Document.parent == p.id
                    )
                )
            )
            result.append(
                {
                    **public(p),
                    "master": signed_asset(master),
                    "cover": signed_asset(cover) if cover else None,
                    "likes": len(likes),
                }
            )
        return result


@app.post("/api/v1/showcase/{pid}/like")
def like(pid, current=Depends(user)):
    with session() as db:
        p = db.get(Document, pid)
        if not p or p.kind != "publication":
            raise HTTPException(404, "Track not found.")
        existing = db.scalar(
            select(Document).where(
                Document.kind == "like",
                Document.parent == pid,
                Document.owner == current.id,
            )
        )
        if existing:
            db.delete(existing)
        else:
            create(db, "like", current.id, {}, pid)
        return {"liked": not bool(existing)}


@app.get("/api/v1/showcase/{pid}/comments")
def comments(pid):
    with session() as db:
        publication = db.get(Document, pid)
        if not publication or publication.kind != "publication":
            raise HTTPException(404, "Track not found.")
        return [
            public(c)
            for c in db.scalars(
                select(Document)
                .where(Document.kind == "comment", Document.parent == pid)
                .order_by(Document.created)
                .limit(100)
            )
        ]


@app.post("/api/v1/showcase/{pid}/comments", status_code=201)
def comment(pid, body: Comment, current=Depends(user)):
    with session() as db:
        p = db.get(Document, pid)
        if not p or p.kind != "publication":
            raise HTTPException(404, "Track not found.")
        return public(
            create(
                db,
                "comment",
                current.id,
                {"text": body.text, "author": current.name},
                pid,
            )
        )


@app.delete("/api/v1/showcase/{pid}/comments/{comment_id}")
def moderate_comment(pid, comment_id, current=Depends(user)):
    with session() as db:
        publication = db.get(Document, pid)
        note = db.get(Document, comment_id)
        if (
            not publication
            or publication.kind != "publication"
            or not note
            or note.kind != "comment"
            or note.parent != pid
        ):
            raise HTTPException(404, "Note not found.")
        if current.id not in (publication.owner, note.owner):
            raise HTTPException(
                403, "Only the track owner or note author can remove this note."
            )
        db.delete(note)
    return {"status": "removed"}


@app.delete("/api/v1/showcase/{pid}")
def unpublish(pid, current=Depends(user)):
    with session() as db:
        p = owned(db, pid, current.id, "publication")
        if p.owner != current.id:
            raise HTTPException(403, "Only the owner can unpublish.")
        db.delete(p)
    return {"status": "unpublished"}


@app.get("/api/v1/events")
def events(after: int = 0, project_id: str = "", current=Depends(user)):
    with session() as db:
        q = select(Event).where(Event.id > after)
        if project_id:
            owned(db, project_id, current.id, "project")
            q = q.where(Event.project_id == project_id)
        else:
            q = q.where(Event.owner == current.id)
        return [
            {"event_id": e.id, "project_id": e.project_id, **e.payload}
            for e in db.scalars(q.order_by(Event.id).limit(100))
        ]


@app.get("/internal/events")
def internal_events(after: int = 0, x_aureon_internal_key: str = Header(default="")):
    if not INTERNAL_KEY or not hmac.compare_digest(INTERNAL_KEY, x_aureon_internal_key):
        raise HTTPException(403, "Internal gateway key is required.")
    with session() as db:
        return [
            {
                "event_id": e.id,
                "project_id": e.project_id,
                "owner": e.owner,
                **e.payload,
            }
            for e in db.scalars(
                select(Event).where(Event.id > after).order_by(Event.id).limit(100)
            )
        ]
