# Aureon — AI Music Agent

Flutter · .NET 9 · Python · Anthropic API · FFmpeg · Coqui XTTS-v2

Upload a beat and lyrics → Aureon generates a fully mixed, auto-tuned vocal track in your chosen genre.

---

## Stack

| Layer | Tool | Port |
|---|---|---|
| Frontend | Flutter (iOS/Android/macOS) | — |
| Backend | .NET 9 Web API | 5000 |
| Audio Service | Python / FastAPI | 8000 |
| Beat Analysis | Librosa + Essentia | — |
| Vocal Synthesis | Coqui XTTS-v2 | — |
| Pitch Correction | Rubber Band Library | — |
| Mixing | FFmpeg | — |
| AI Critic | Anthropic Claude | — |

---

## Folder Structure

```
Aureon/
├── run_all.sh                  ← start everything
├── logs/                       ← runtime logs
├── beats/                      ← drop sample beats here
├── outputs/                    ← generated tracks land here
│
├── python_audio_service/       ← Phase 1–4 pipeline
│   ├── main.py                 ← FastAPI app + /generate endpoint
│   ├── job_queue.py            ← async job runner
│   ├── requirements.txt
│   ├── setup.sh
│   └── services/
│       ├── beat_analysis/
│       │   ├── analyzer.py     ← BPM, key, bar detection (Librosa)
│       │   ├── flow_engine.py  ← genre-specific syllable flow templates
│       │   └── syllable_mapper.py ← maps lyrics → beat grid
│       ├── vocal_gen/
│       │   └── synthesizer.py  ← Coqui XTTS-v2 vocal generation
│       ├── pitch_correction/
│       │   └── corrector.py    ← Rubber Band auto-tune
│       └── mixing/
│           └── mixer.py        ← FFmpeg EQ + reverb + master mix
│
├── dotnet_backend/             ← Phase 1 API layer
│   └── AureonApi/
│       ├── Program.cs          ← DI, CORS, Swagger setup
│       ├── Controllers/
│       │   └── MusicController.cs  ← /generate, /status, /download
│       ├── Models/Models.cs
│       └── Services/
│           ├── AudioServiceClient.cs  ← HTTP client → Python service
│           └── JobCacheService.cs     ← in-memory job store
│
└── flutter_app/aureon/         ← Phase 5 UI
    └── lib/
        ├── main.dart           ← app entry point
        ├── models/models.dart  ← JobStatus, GenerateResponse, etc.
        ├── services/
        │   ├── api_service.dart       ← Dio HTTP client → .NET backend
        │   └── generator_provider.dart ← ChangeNotifier, poll loop
        ├── screens/
        │   ├── home_screen.dart    ← beat upload + lyrics + genre
        │   ├── status_screen.dart  ← live pipeline progress
        │   ├── player_screen.dart  ← audio player + star rating
        │   └── history_screen.dart ← Phase 6 feedback loop
        └── widgets/
            ├── genre_chip.dart       ← animated genre selector
            ├── waveform_bar.dart     ← animated waveform animation
            ├── progress_stepper.dart ← pipeline step tracker
            └── critique_card.dart   ← AI critic results display
```

---

## Quick Start

### Prerequisites

- Python 3.11+
- .NET 9 SDK
- Flutter 3.22+
- FFmpeg (`brew install ffmpeg` / `apt install ffmpeg`)
- Rubber Band CLI (`brew install rubberband`)

### Run everything

```bash
cd ~/Documents/Aureon
chmod +x run_all.sh
./run_all.sh
```

This starts:
- Python microservice on `http://localhost:8000`
- .NET API on `http://localhost:5000`
- Flutter app on your connected device/emulator

To run backend only (no Flutter):
```bash
./run_all.sh --no-flutter
```

### First-time Python setup

```bash
cd python_audio_service
chmod +x setup.sh && ./setup.sh
```

### First-time .NET setup

```bash
cd dotnet_backend
chmod +x setup.sh && ./setup.sh
```

---

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/music/generate` | Submit beat + lyrics → returns `job_id` |
| `GET` | `/api/music/status/{jobId}` | Poll job progress (0–100%) |
| `GET` | `/api/music/download/{jobId}` | Stream finished MP3 |
| `GET` | `/api/music/health` | Health check |

### Generate Request (multipart/form-data)

```
beat        → audio file (MP3/WAV/FLAC)
lyrics      → plain text
genre       → trap | drill | rap | rnb | pop
speakerWav  → optional reference voice WAV (for XTTS cloning)
```

### Status Response

```json
{
  "job_id": "abc-123",
  "status": "mixing",
  "progress": 80,
  "output_ready": false,
  "critique": {
    "score": 0.82,
    "on_beat_ratio": 0.91,
    "approved": true,
    "issues": [],
    "overflow_lines": []
  }
}
```

---

## Pipeline (per job)

```
Beat upload
    │
    ▼
[analyzer.py]      BPM, key, time sig, bar boundaries
    │
    ▼
[syllable_mapper]  Map each lyric line → beat grid slots
    │
    ▼
[flow_engine]      Genre flow template → 3 timing candidates
    │
    ▼
[synthesizer]      Coqui XTTS-v2 → raw vocal WAV × 3
    │
    ▼
[AI Critic]        Claude evaluates on-beat ratio, overflow
    │              → picks best candidate
    ▼
[corrector]        Rubber Band pitch correction / auto-tune
    │
    ▼
[mixer]            FFmpeg: EQ + compression + reverb + mix with beat
    │
    ▼
outputs/{jobId}.mp3
```

---

## Phases

| Phase | Status | Description |
|---|---|---|
| 1 — Core Pipeline | ✅ | Python service, .NET API, basic synthesis |
| 2 — Flow Engine | ✅ | Syllable-beat alignment, genre templates, 3 candidates |
| 3 — AI Critic | ✅ | Claude evaluates and selects best candidate |
| 4 — Auto-tune + Mixing | ✅ | Rubber Band + FFmpeg EQ/reverb/master |
| 5 — Flutter UI | ✅ | Upload → Generate → Play → Download |
| 6 — Quality Loop | ✅ | Star ratings, history, CSV feedback export |

---

## Environment Variables

Set in `python_audio_service/.env` (optional):

```env
ANTHROPIC_API_KEY=sk-ant-...      # for AI Critic agent
OUTPUTS_DIR=../outputs
TEMP_DIR=./temp
MAX_CONCURRENT_JOBS=3
```

Set in `dotnet_backend/AureonApi/appsettings.json`:

```json
{
  "AudioService": { "BaseUrl": "http://localhost:8000" },
  "Urls": "http://0.0.0.0:5000"
}
```

---

## Performance Notes

- **Rap / Drill / Trap**: fastest — low pitch precision needed, CPU viable (~30–90s)
- **R&B / Pop**: slower — melodic synthesis is compute-heavy (~2–5 min on CPU)
- GPU (CUDA/MPS): reduces synthesis from minutes → seconds
- Rubber Band + FFmpeg: CPU-only, always fast

---

## Phase 6 — Feedback Dataset

Every rated track is stored locally. From the History screen, tap **Export** to generate `aureon_feedback_<timestamp>.csv`:

```csv
jobId,rating,timestamp,path
abc-123,5,2025-01-15T14:32:00,/path/to/aureon_abc-123.mp3
def-456,3,2025-01-15T15:10:00,/path/to/aureon_def-456.mp3
```

Use this CSV to fine-tune flow templates or re-rank candidate selection over time.
# AureonMusicAI
