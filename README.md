# Aureon — AI Music Studio (Supercharged Edition)

Flutter · .NET 9 SignalR · Python · Sarvam AI · Coqui XTTS-v2 · Demucs 4-Stem Separation · FFmpeg & SoX DSP

A studio-grade AI Music production suite with multimodal voice prompting, multilingual singing/rap synthesis, real-time stem mixing, and Spotify-standard mastering at **100% Zero-Cost**.

---

## 🚀 Key Features

### 🎙️ 1. Sarvam AI Voice Producer & Multimodal STT/TTS
- **Indian & Global Multilingual Flows**: Native Hindi, Hinglish, Punjabi, Tamil, and English vocal synthesis with natural inflections via Sarvam Bulbul API.
- **Saaras Speech-to-Lyrics**: Hum or speak your musical idea; Aureon transcribes and structures it into rhythmic bars.
- **Zero-Cost Fallback**: Automatic local fallback to Coqui XTTS-v2 and offline DSP models if no API key is present.

### 🎛️ 2. Interactive 4-Stem Mini-DAW Player
- **Demucs Stem Separation**: Isolates tracks into **Vocals**, **Drums**, **Bass**, and **Melody/Other**.
- **Per-Channel Mixing**: Volume faders, Solo (`S`), and Mute (`M`) controls for every stem.
- **Real-time Spectral FFT Visualizer**: Dynamic glowing multi-band audio visualizer synchronized to playback.

### ✍️ 3. AI Lyricist Studio & Flow Meter
- **Live Syllable Counter**: Real-time syllable-per-bar meter that ensures lyrics align with the BPM grid.
- **AI Auto-Write**: Instant genre-specific lyric generation for Trap, Drill, Rap, R&B, and Pop.
- **Preset Beat Explorer**: Built-in royalty-free starter beats for instant 1-tap generation.

### ⚡ 4. Real-time SignalR Streaming (.NET 9 Gateway)
- **Zero-Delay WebSocket Updates**: Replaces HTTP polling with ASP.NET Core 9 SignalR Hub (`/hub/music`).
- **Granular Pipeline Progress**: Live milestone logs for analysis, stem separation, vocal synthesis, auto-tune, and mastering.

### 🔊 5. Studio DSP Mastering Chain
- **Scale-Aware Auto-Tune**: Minor, Major, Harmonic Minor, Pentatonic, and Dorian pitch correction with configurable retune speed.
- **Vocal Pocket Sidechain Ducking**: Automatically ducks mid-frequencies on the beat when vocals hit.
- **-14 LUFS Normalizer**: True peak limiting and EBU R128 loudness normalization for broadcast quality.

---

## 🏗️ Architecture

```
Aureon/
├── dotnet_backend/             ← ASP.NET Core 9 Gateway
│   └── AureonApi/
│       ├── Hubs/
│       │   └── MusicHub.cs     ← SignalR Real-time WebSocket Hub
│       ├── Controllers/
│       │   └── MusicController.cs ← /generate, /presets, /voice/prompt, /stems
│       ├── Models/Models.cs
│       └── Services/
│           ├── AudioServiceClient.cs
│           └── JobCacheService.cs
│
├── python_audio_service/       ← AI & DSP Microservice
│   ├── main.py                 ← FastAPI app + WebSocket endpoints
│   ├── job_queue.py            ← 7-stage asynchronous DSP job pipeline
│   └── services/
│       ├── vocal_gen/
│       │   ├── sarvam_service.py ← Sarvam Bulbul TTS + Saaras STT
│       │   └── synthesizer.py   ← Multi-engine vocal synthesizer
│       ├── mixing/
│       │   ├── stem_separator.py← Demucs v4 + DSP 4-stem separator
│       │   └── mixer.py         ← Sidechain ducking & -14 LUFS mastering
│       ├── pitch_correction/
│       │   └── corrector.py     ← Scale-aware auto-tune (Travis/T-Pain styles)
│       └── beat_analysis/
│           ├── analyzer.py      ← Librosa BPM & key detection
│           └── flow_engine.py   ← Syllable-beat alignment grid
│
└── flutter_app/aureon/         ← Cyberpunk Studio UI
    └── lib/
        ├── main.dart
        ├── models/
        │   ├── models.dart
        │   └── preset_beats.dart← Built-in starter beats library
        ├── services/
        │   ├── api_service.dart
        │   ├── generator_provider.dart
        │   └── signalr_service.dart ← WebSocket live tracking
        ├── screens/
        │   ├── home_screen.dart ← Cyberpunk studio & AI lyricist
        │   ├── status_screen.dart ← Granular DSP step progress
        │   ├── player_screen.dart ← Master player & Mini-DAW
        │   └── history_screen.dart
        └── widgets/
            ├── stem_player_widget.dart ← 4-channel mini-DAW mixer
            ├── spectral_visualizer.dart← Real-time spectral FFT visualizer
            ├── voice_assistant_modal.dart ← Pulsing Sarvam voice orb
            └── syllable_counter_bar.dart ← Syllable flow meter
```

---

## ⚙️ Environment Configuration (Optional)

In `python_audio_service/.env`:
```env
SARVAM_API_KEY=your_sarvam_key_here    # (Optional) For multilingual Indian/Global singing & STT
ANTHROPIC_API_KEY=your_claude_key      # (Optional) For AI critic agent
OUTPUTS_DIR=../outputs
TEMP_DIR=./temp
```
*Note: If no API keys are provided, the system seamlessly runs 100% locally and offline at $0 cost.*

---

## 🚀 Running Aureon

```bash
# Start all microservices and frontend:
./run_all.sh

# Or start backend services only:
./run_all.sh --no-flutter
```
