# Aureon Music Studio

A private music workspace built with Flutter, ASP.NET Core 10, and Python DSP. Compose an original instrumental, add your own recording, shape a four-stem mix, compare masters, and export real media from a versioned session.

The interface uses an original A/soundwave identity, pearl and graphite palettes, floating Liquid Glass-inspired navigation, transport and sheets, responsive layouts, and persistent motion/transparency/contrast controls. Editing and analysis surfaces remain readable. All waveforms, spectrum frames, loudness readings, progress events, and downloads come from actual processing.

## Start locally

Use Python 3.11 (recommended for optional ML) or 3.12, .NET SDK 10, Flutter 3.47.3, and FFmpeg. The production core has no GPU or model-download requirement. Optional ML experiments remain outside the core workflow.

```powershell
py -3.11 -m venv .runtime311
.runtime311\Scripts\python -m pip install -r python_audio_service/requirements-dev.txt
# Install FFmpeg on PATH, or use the optional portable resolver:
.runtime311\Scripts\python -m pip install imageio-ffmpeg
.\start-local.ps1 -Python "$PWD\.runtime311\Scripts\python.exe"
cd flutter_app/aureon
flutter pub get
flutter run -d chrome --web-port 3005 --dart-define=API_BASE_URL=http://localhost:5000
```

Open the studio and choose **Try the studio**. This creates an isolated account, a persistent session, and an actual queued instrumental render. Create a named account to retain access across browser sessions. Browser access tokens are held in memory; native tokens use platform secure storage. Browser drafts are saved on the current device and recovered for the same account/project revision.

Services: Flutter 3005, .NET gateway 5000, Python worker/API 8103. `start-local.ps1` shares a random internal outbox key between services. Use separate terminals with `AUREON_INTERNAL_KEY` set to the same value for troubleshooting. SQLite and private media are stored under ignored `data/`; never delete it to update code. Configure `AUREON_DATA_DIR` to relocate it.

## Container stack

Copy `.env.example` to `.env`, supply a Postgres password and an internal key, then run `docker compose up --build`. Open `http://localhost:3005`. The stack includes Postgres, Redis, Python/FFmpeg, .NET, and nginx/Flutter. Only the UI port is published. Named volumes retain database, queue, signing key, and media data. Container definitions are supplied; this workspace did not have Docker available to execute them.

For an existing public hosting account, use the target mapping and environment instructions in [HOSTING.md](docs/HOSTING.md). The frontend hosting configuration is prepared; no public destination is linked or deployed yet.

## Capabilities and evidence

The [fresh 5 October full audit](docs/FULL-AUDIT-2026-10-05.md) records the latest visual/UX repairs, executed tests, release artifacts, all 20 feature expectations and current external/device gates. Earlier verification remains a historical record.

See [manual testing](docs/MANUAL_TESTING.md), [the release plan](docs/RELEASE_PLAN.md), [the 20-capability matrix](docs/CAPABILITIES.md), [architecture](docs/ARCHITECTURE.md), [verification record](docs/VERIFICATION.md), and [portfolio walkthrough](docs/PORTFOLIO.md). The core is runnable without paid providers. Sarvam speech/transcription requires a key; lyric assistance requires a running Ollama model; XTTS is optional and unverified in this environment. Imported separation offers labeled approximate spectral DSP or an installed Demucs engine; generated presets have original instrument stems. Speech synthesis is explicitly speech, not AI singing.

```powershell
.runtime311\Scripts\python -m pytest tests/test_studio.py tests/test_providers.py -q
dotnet build dotnet_backend/AureonApi -c Release
$env:AUREON_GATEWAY_URL='http://localhost:5000'
.runtime311\Scripts\python -m pytest tests/test_gateway.py -q
cd flutter_app/aureon
flutter analyze
flutter test
flutter build web --release
```

Android, iOS, web and Windows runners and original launcher icons are included. Web release and Android debug builds passed locally. The APK, emulator gateway mapping and SHA-256 are recorded in [verification](docs/VERIFICATION.md). Native microphone/audio/filesystem flows need actual-device verification; iOS needs macOS/Xcode and this Windows host requires Developer Mode for native plugin symlinks.

## Optional providers

Configure `SARVAM_API_KEY` for Bulbul v3 speech and Saaras v3 transcription. The adapters use the official [TTS](https://docs.sarvam.ai/api-reference/text-to-speech/convert) and [STT](https://docs.sarvam.ai/api-reference/speech-to-text/transcribe) contracts and never replace errors with generated placeholders. Provider contract tests use synthetic HTTP responses; no paid provider call was made during verification.

Configure `OLLAMA_URL` and `OLLAMA_MODEL` for lyric assistance. Configure `S3_BUCKET`, `S3_ENDPOINT`, and AWS credentials for private object storage. Provider availability means configured, not a promise that credentials, model downloads, or quotas are valid. Settings and job errors expose that distinction.

Historical UI/controllers are preserved under `legacy/` for reference and are not loaded. Older Python model experiments are not exposed by the core API. Do not advertise MusicGen, RVC voice cloning, MIDI/DAW integration, professional neural separation, or singing generation as completed capabilities.
