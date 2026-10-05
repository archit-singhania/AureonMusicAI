# Aureon: fresh full-product audit — 5 October 2026

This audit covers the maintained Flutter studio, ASP.NET Core 10 gateway and Python 3.11 DSP service. It preserves the useful music and database in `data/`; live audit accounts, projects and renders use `.tools/audit-2026-10-05-data`. No paid requests, deployment, commit or push was made.

## Visual result and UX repairs

An original, reusable `lib/liquid_glass.dart` material now serves the floating desktop navigation, mobile dock, persistent transport and modal sheets. It combines clipped 10 px backdrop blur, pearl/graphite tint, violet lighting, a specular rim, soft elevation and pointer-following highlights. Pointer lighting only repaints on movement; it has no perpetual timer. The editor, waveform, mixer and analysis content use solid readable surfaces. This is a Liquid Glass-inspired Flutter implementation, without claiming Apple's native optical refraction renderer.

The direction follows the supplied [Liquid Glass guide](https://liquidglassdesign.com/what-is-liquid-glass) and [prompt gallery](https://liquidglassdesign.com/prompts): spacious typography, soft lighting and glass restricted to the interaction layer. Original vector brand assets and code are retained. No reference-site artwork or third-party glass dependency was copied. [Apple materials](https://developer.apple.com/design/human-interface-guidelines/materials) and [Flutter accessibility](https://docs.flutter.dev/ui/accessibility) were consulted.

- Light, dark and system appearances remain persistent. Increase contrast is now persistent, with stronger text/rims and solid glass. Reduce transparency removes blur; reduce motion and OS animation preferences remove animated navigation feedback. Selected navigation and connected-status text use legible theme-aware colors.
- The phone dock and desktop rail float within safe areas. The rail hides its secondary promotional card on shorter displays or enlarged text. Sheets float with a visible Close action and account for the on-screen keyboard. Editor labels remain visible and have semantic names. Navigation selection animates over 150 ms and pages over 260 ms when motion is enabled.
- Official OFL-licensed Inter is bundled for consistent real typography on web and native builds (876,576 bytes; SHA-256 `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031`). Custom web initialization uses the packaged CanvasKit engine and exposes accessible startup/reload feedback rather than requiring a CDN engine request.
- **Covered showcase playback repaired:** cover artwork previously replaced the only Play control. Every published track now retains an explicit Play track action; failed cover loading has a graceful original-icon fallback.
- **Preview identity repaired:** preset and showcase previews now show their actual title, duration and pause/resume transport, even before a project exists. Project master playback, grid seeking, stems and A/B restore the correct project source rather than controlling an unrelated preview.
- **Recording repaired:** consent and microphone permission remain mandatory; pending setup disables duplicate clicks, streams are retained/cancelled explicitly, PCM is capped at three minutes, final input is collected before encoding, empty recordings are rejected, and closing a sheet during an asynchronous operation cannot update a disposed widget.
- **Provider errors repaired:** malformed, empty or non-string lyric replies produce an honest HTTP 503 with the saved draft preserved. Local lyric requests have bounded generation tokens and disable reasoning output. Provider settings distinguish Configured from verified working availability.
- Copilot and public-note requests safely handle closing their sheet before the response arrives. Invalid legacy theme preferences fall back to System.

## Executed evidence

| Fresh check | Result |
|---|---|
| Python core/provider suite | **19 passed**, Python 3.11; final run 142.07 seconds. Five new invalid lyric-response cases explicitly preserve the original saved lyrics. Existing checks cover ownership, conflicts, persistence, cancellation/retry/recovery, actual changed DSP, true peak, waveform/spectrum, WAV/MP3/ZIP/MP4, profiles, artwork, moderation and neural adapter gating. |
| Live .NET contract and SignalR | **2 passed**, 10.84 seconds, real gateway on 5000. Authenticated events/outbox, ranged HTTP 206 and membership revocation were exercised. |
| .NET release build | **0 warnings, 0 errors**, .NET SDK 10.0.401, net10.0. The launcher uses a private internal relay key and readiness/FFmpeg checks. |
| Local Ollama request | Actual lyric route returned **503** in **2.56 seconds** on its final check; `/api/tags` connection was refused. `docs/demo/local-lyric-audit-2026-10-05.json` records the result without credentials. Live inference is a fresh manual gate; old installed-model evidence is not reused as a present pass. |
| Flutter final analyzer/tests | Pending final batch; update after execution. |
| Final web and Android artifacts | Pending final batch; update after execution. |
| Actual browser and media evidence | Pending final release journey; update after execution. |

Tests create their own temporary databases/media. The one existing Starlette/httpx deprecation warning does not make a failing operation appear successful. No native microphone, Android device, iOS or cloud-provider execution is implied by unit/contract tests.

## Feature inventory and manual expectations

| # | Feature and what to do | Expected result |
|---|---|---|
| 1 | Create a session, edit title/lyrics, wait for saved status, reopen from Library | A real owned project, autosave, recoverable local drafts and persisted server revisions. |
| 2 | Preview an original mood; Use this mood; import an owned WAV/MP3 | Audible original preset and controllable preview; imported metadata and privately stored media. |
| 3 | Analyze an import; edit BPM/key/meter/downbeat offset and tap beat grid | Estimates are labeled; editable values persist; grid seeks actual master. No automatic quantization claim. |
| 4 | Record, confirm consent, allow microphone, stop/save; request transcription if configured | An actual private PCM/WAV take. Denied permission has an error. Sarvam transcription requires a live key. |
| 5 | Edit lyrics, inspect flow/syllable guidance, use revisions; optional Write a revision | Saved lyrics and approximate English rhythm guidance. Working Ollama returns original text; unavailable model preserves the draft. |
| 6 | Inspect Voice mode and choose an available engine | Instrumental/own-recording work locally. Sarvam/XTTS must be configured and tested. Synthesized output is speech, not singing. |
| 7 | Save an owned consented take as a profile; use it in another session | A private reusable copied audio take; no voice-cloning/training claim. |
| 8 | Inspect separation choice and genuine Demucs option; solo the generated preset stems | Original presets have four exact instrument stems. Installed Demucs must return actual four neural stems. Approximate DSP is explicitly distinct. |
| 9 | Enable live balance; seek; change gain/mute/solo; render, save and reopen | Synchronized players and persisted mixer state, with real changed master audio. Hardware latency remains device QA. |
| 10 | Adjust effects/loudness, Render mix and audition | Real processing changes PCM; protected finite output. Effects become audible after a render. |
| 11 | Mixing copilot → describe warmth/width → review → Apply these settings → render | An explainable bounded parameter proposal; application is explicit. Deterministic assistance is honestly labeled. |
| 12 | Render two different masters; Current/Previous mix; Match loudness | Correct selected audio/metrics and measured attenuation of the louder master. No mastering-certification claim. |
| 13 | Play/seek and inspect waveform, spectrum, loudness and duration | Actual decoded PCM measurements; preview playback is not mislabeled as the project master. |
| 14 | Edit/save → Undo → Redo; inspect Version history and restore | Durable edit history/revisions; stale writes conflict instead of silently overwriting. |
| 15 | Queue a render/export; Activity → Cancel/Retry; restart and reopen | Real durable jobs/progress and terminal states. Cancellation occurs between stages; fast completed work may beat the click. |
| 16 | Download WAV, MP3 and Stem pack, then decode externally | Real 24-bit WAV, MP3, four WAV stems plus metadata ZIP; FFmpeg is required for codecs. |
| 17 | Video → completed job → Preview video → Play/seek → Save MP4 | An actual portrait visualizer with rendered master audio; missing native codec has an explicit download fallback. |
| 18 | Edit cover → choose Halo/Wave/Minimal, palette/caption → Render cover; optionally upload an image | A real original 1024 px PNG and saved style; oversized uploads fail clearly. Optional AI artwork is not configured. |
| 19 | Invite a named second account; edit both; remove member | Authenticated live updates, revision conflicts and immediate private API/event revocation. Existing signed playback links expire in an hour. |
| 20 | Share to showcase → play covered track → like/notes → remove own note/unpublish | Real public playback and durable moderation with ownership. Covers retain Play track. Sitewide abuse tooling remains a production gate. |

The longer two-browser permissions/queue/device drills remain in [MANUAL_TESTING.md](MANUAL_TESTING.md). [CAPABILITIES.md](CAPABILITIES.md) identifies optional engine limitations for each approved capability.

## Start and test yourself

In PowerShell at `D:\remaining-4-git-projs\AureonMusicAI`:

```powershell
$env:DOTNET_ROOT='D:\remaining-4-git-projs\.tooling\dotnet'
$env:DOTNET_CLI_HOME='D:\remaining-4-git-projs\.tooling\dotnet-home'
$env:NUGET_PACKAGES='D:\remaining-4-git-projs\.tooling\nuget'
$env:TEMP="$PWD\.tools\temp"
$env:TMP=$env:TEMP
.\start-local.ps1 -Python "$PWD\.runtime311\Scripts\python.exe" -Dotnet "$env:DOTNET_ROOT\dotnet.exe"
.runtime311\Scripts\python -m http.server 3005 --bind 127.0.0.1 --directory flutter_app/aureon/build/web
```

Open **http://localhost:3005** and choose Try the studio. Services must return readiness at `http://localhost:5000/health` and `http://localhost:5000/api/v1/health`. Expect pearl/graphite backgrounds, violet/coral accents, the original soundwave-A mark, softly lit glass navigation/transport/sheets and readable audio editors. At phone width the floating five-destination dock replaces the rail.

If audit services are still running, use that preview or stop only their recorded processes with `.\stop-local.ps1`. The launcher deliberately refuses occupied ports. Normal launches use `data/`; optional `AUREON_DATA_DIR` selects another directory. Never erase `data/` to upgrade the app. Web tokens intentionally live in memory; use a named account to sign in after a browser restart.

```powershell
.runtime311\Scripts\python -m pytest tests/test_studio.py tests/test_providers.py -q
$env:AUREON_GATEWAY_URL='http://localhost:5000'
.runtime311\Scripts\python -m pytest tests/test_gateway.py -q
cd flutter_app/aureon
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=http://localhost:5000
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

## Remaining honest release gates

Live Ollama/XTTS/Sarvam and actual Demucs model weights/inference require the running engines, consented inputs and any provider credentials. They fail explicitly when unavailable. No model download or paid call was made in this fresh audit. Android debug compilation alone does not prove installation/device audio/microphone/secure-storage behavior. iOS/macOS needs macOS/Xcode; unsigned CI configuration is present but a remote job was not run here. Docker/Postgres/Redis/private S3 and public hosting need their actual environments. Signing, real-device accessibility/listening and hardware performance profiling remain release gates; no universal "perfect UX" or sustained-device-60-fps claim is made.
