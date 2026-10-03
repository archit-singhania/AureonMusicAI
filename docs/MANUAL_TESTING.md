# Aureon local release and manual testing

This guide tests the original 20 product capabilities. Responsive premium appearance, accessibility, accounts, private storage and platform builds are additional foundations. Hosting is deferred. The free path uses real local composition/DSP/media and needs no paid model/provider.

## Open or start the local release

The prepared preview is **http://localhost:3005**; its release files are `flutter_app/aureon/build/web`. Gateway: `http://localhost:5000`; Python: `http://127.0.0.1:8103`. Open the existing preview directly when services are running. A second launcher intentionally refuses occupied ports.

For a fresh start in this workspace, open PowerShell at `D:\remaining-4-git-projs\AureonMusicAI`:

```powershell
$env:DOTNET_ROOT='D:\remaining-4-git-projs\.tooling\dotnet'
$env:DOTNET_CLI_HOME='D:\remaining-4-git-projs\.tooling\dotnet-home'
$env:NUGET_PACKAGES='D:\remaining-4-git-projs\.tooling\nuget'
.\start-local.ps1 -Python "$PWD\.runtime311\Scripts\python.exe" -Dotnet "$env:DOTNET_ROOT\dotnet.exe"
# Foreground terminal for the built web release:
.runtime311\Scripts\python -m http.server 3005 --bind 127.0.0.1 --directory flutter_app/aureon/build/web
```

Expected output: **Studio ready** and gateway/Python/stop commands. The launcher checks both ports before starting, builds the gateway into its own ignored runtime output, checks readiness/FFmpeg, shares a private relay key, and starts hidden processes with logs under `logs/`. It records process IDs/start times. In another terminal:

```powershell
Invoke-RestMethod http://localhost:5000/health
Invoke-RestMethod http://localhost:5000/api/v1/health
```

Expect gateway `service: aureon-gateway`; proxied Python `status: ok`, `database: sqlite`, `ffmpeg: true`. Stop the frontend with Ctrl+C; use `./stop-local.ps1` for services created by this launcher. Separately launched services stop in their own terminals. Never delete `data/` to restart or update. `start_backends.ps1` now forwards to the maintained launcher.

For a clean checkout install Python 3.11 or 3.12, .NET SDK 10, Flutter 3.47.3 and FFmpeg. Create `.runtime311` with `py -3.11 -m venv .runtime311`, then install `python_audio_service/requirements-dev.txt` plus `imageio-ffmpeg` (the portable FFmpeg resolver), or put FFmpeg on PATH. The prepared workspace already has a working `.runtime311`; reuse it without recreating it. `requirements.txt` selects compatible NumPy/SciPy/Librosa versions for Python 3.11 and 3.12. Run `flutter pub get` in `flutter_app/aureon`. Windows native plugin symlinks need Developer Mode; this prepared workspace already has resolved dependencies.

Rebuild with the prepared SDK:

```powershell
$env:GIT_CONFIG_COUNT='1'
$env:GIT_CONFIG_KEY_0='safe.directory'
$env:GIT_CONFIG_VALUE_0='C:/Users/dell/develop/flutter'
$env:PUB_CACHE='D:\remaining-4-git-projs\.tooling\pub-cache'
Set-Location flutter_app/aureon
& 'C:\Users\dell\develop\flutter\bin\flutter.bat' build web --release --no-pub --no-wasm-dry-run --dart-define=API_BASE_URL=http://localhost:5000
```

For alternate ports supply `-PythonPort 8113 -GatewayPort 5013`, rebuild the frontend with that gateway, and stop with `stop-local.ps1 -GatewayPort 5013`. Change the permitted UI origin with `-UiOrigin http://localhost:YOUR_PORT`. Browser builds using localhost are for this machine; an Android emulator uses `http://10.0.2.2:5000`, while a physical phone needs a reachable HTTPS/LAN gateway and deliberate network binding/origin setup.

## Five-minute free guest walkthrough

1. Open the preview and select **Try the studio**. Expect an isolated guest account, a persistent Afterglow session and a queued original composition. Activity reflects real stages. Only completed decoded audio adds the master waveform, duration, LUFS and peak readings.
2. Select **Play master**, listen and pause. Seek within the waveform. Rename **Session title**, wait for **All changes saved**, and try **Undo** then **Redo**. The saved title should change accordingly.
3. Mute Bass with **M**, adjust tape/delay if desired, then **Render mix**. Return from Activity to Studio once complete. **Previous mix** becomes available after two completed masters; audition Current/Previous with Match loudness. Real output should differ.
4. Select **Edit cover**, choose Wave/Sage/Forest and a caption, then **Render cover**. Open Library, search the saved title, and Open it. Expect title, grid, parameters, jobs and real media retained. Save **WAV** and play it in another player.
5. Export MP3/Stem pack/Video; completed Video has **Preview video** and Save in Activity. Publish the completed master, play it from Discover, add a note and remove it as owner, then Unpublish.

The recorded `docs/demo/guest-workflow.mp4` shows a real fixture composition → playback → changed mix → reopen → WAV export → artwork render → actual MP4 preview playback. Its screen recording is silent; `guest-master.wav` is the actual exported master. No API responses or processing timers were mocked for that recording.

Guest credentials stay in browser memory. Reload/close loses that guest login even though its session/media remain on disk. Use a **named account** for sign-out/sign-in, browser reload and restart acceptance. Native tokens use secure storage. Web tokens are not persisted to browser storage; device drafts/appearance are separate preferences.

## Manual acceptance for the original 20

Record browser/device, pass/fail, output and error for each case. `VERIFICATION.md` lists executed checks; these instructions do not claim every external/device check has passed.

| # | Capability and exact action | Expected result / limitation |
|---|---|---|
| 1 | Project workspaces: named account → create/rename/edit → wait for autosave → Library/search/open → restart services/sign in. Duplicate and archive a throwaway copy. | Session/lyrics/params/jobs/media persist; renamed card updates immediately; duplicate has its own ID, archive preserves data outside active list. Offline edits retain a local draft for the same account/project revision. |
| 2 | Beat presets/metadata: preview each mood; select a preset/Create master; Import a short owned WAV/MP3; inspect Library Assets and its metadata. | Actual preview/decoded original music and bounded upload; real duration/type/name. Invalid codec/file fails clearly. Limits: 50 MB/180 seconds. |
| 3 | Analysis/grid: import → inspect populated estimated BPM/key (the analysis API also returns confidence); edit BPM/key, Beats per bar and Downbeat offset; tap grid beats during an actual master; reopen. | Saved meter/phase and tempo/key; clicked beat seeks the actual transport. Analysis is approximate. Grid editing changes navigation/metadata, not audio time-stretch. |
| 4 | Recording/transcription: Record → consent → allow microphone → Start recording → Stop & save; choose language; use Transcribe this take with configured Sarvam. Also deny mic access. | Real private PCM/WAV; denied permission creates no fake take. Visible unavailable transcription status without key. Multilingual transcription needs a real Sarvam request; hardware QA remains. |
| 5 | Lyrics: write notebook; inspect syllable/phrase guidance; Lyric revisions → Restore; optionally use contextual assistant with running Ollama. | Text/history persist; approximately similar syllable counts help phrasing. Real optional co-writing replaces lyrics through a saved revision. Missing model is clearly unavailable. English estimates are approximate. |
| 6 | Synthesis: inspect Voice mode and Settings engine status; choose instrumental/recording or configured Sarvam/XTTS; Create master. | Selected real engine/job output; unavailable options are labeled/gated and failure is explicit. Sarvam/XTTS create speech, not AI singing; keys/weights/quota are external gates. |
| 7 | Profiles: attach your own consented take → My voice profiles → name → Save attached take as profile; create another session → profile Use take. Remove profile. | Profile is private and language-labeled; an actual copied take attaches to the new session. Unsigned/other people's source is rejected. Removing profile retains source audio. No cloning/training is implied. |
| 8 | Four-stem separation: with Demucs installed choose Imported separation engine→Demucs, import an owned music file/Create master; inspect job's declared engine and solo/download all four outputs. Without engine inspect disabled option. | Installed neural process must produce actual vocals/drums/bass/other WAVs; a failed neural job does not silently become DSP. Demucs inference/weights are not locally verified. Approximate spectral DSP is labeled separately and produces no isolated vocals. Generated presets use original exact stems. |
| 9 | Stem mixing: enable live balance, seek, gain/mute/solo each stem; render/reopen. | Common clock with bounded drift correction; controls/seek affect actual players and saved render. Listen on devices for latency; no sample-accurate DAW guarantee. |
| 10 | Effects: change tape, delay, width, de-esser and target loudness; Render mix after each important change. | Actual finite changed PCM and protected peaks. Effects apply to rendered masters; small settings can be subtle. |
| 11 | Copilot: ask for warm tape/wider stereo → Suggest an adjustment → inspect proposal → Apply these settings → render. | Supported values/reasons appear before application. A deterministic explainable helper, not an LLM audio engineer. |
| 12 | A/B: create two distinct masters → Current/Previous mix → Match loudness → seek/play. | Selected metrics/audio agree; transport position survives where possible; only louder master attenuates to quieter measured LUFS. True peak is oversampled measurement, not certification. |
| 13 | Visual analysis: play/seek and inspect waveform/spectrum; independently decode the downloaded WAV. | Real PCM-derived readings and duration; no decorative fake waveform. |
| 14 | Undo/history: save title/lyrics/grid edits → Undo→Redo → stop/restart/sign in → Undo again; inspect Version history/Restore. | Durable saved edit stacks and new revision/snapshots. New saved edits clear redo. Simultaneous stale revision conflicts rather than overwrites. |
| 15 | Queue: create render/export work → Activity progress → Cancel → Retry → restart/reopen. | Durable job ID/stages and done/failed/cancelled state. Fast jobs may finish before cancel; cancellation is between stages. Stale processing lease recovers after 10 minutes. |
| 16 | Audio/archive export: WAV, MP3, Stem pack; open each outside the app. | 24-bit stereo WAV, decodable MP3, ZIP with four real WAVs and session.json. FFmpeg required for codecs. |
| 17 | Video: Video → wait for completed job → Preview video/Play video/scrub → Save MP4. | Actual portrait visualizer with master audio; browser plays real MP4. Native Windows may need external downloaded-MP4 viewer; device codec QA remains. |
| 18 | Artwork: Edit cover→Halo/Wave/Minimal, palette/background/caption→Render cover; upload an owned PNG/JPEG. | Real 1024 px original template; chosen styles persist. Images over 4096 px rejected. Optional AI image generation is not configured. |
| 19 | Collaboration: owner invitation → second named account joins using Project ID/code from its own session's invitation sheet → edit in both → owner Remove editor. | Authorized live changes and conflicts; member list updates, code rotates, editor exits private session, old invitation fails. Detailed drill below. |
| 20 | Showcase/moderation: publish completed master→public play/like/note→remove own note or track-owner remove another note→owner Unpublish. | Real public audio and persisted actions; unrelated user cannot moderate. Unpublish removes the track; notes require an existing publication. Sitewide abuse/moderator tools are future production work. |

## Two-browser permissions, persistence and queue drill

Use separate browsers/private contexts with named Owner and Editor accounts and a throwaway session. Editor creates any session first, then opens its **Invite a collaborator** sheet and uses **Join another session**.

1. Copy Owner's Project ID/code and join as Editor. Both members should appear. With one copy idle, save in the other: the newer revision should arrive via authenticated SignalR/outbox replay. Header reports Live session. Browser Network should show successful `/hub/music/negotiate` and WebSocket. Do not share token-bearing URLs/logs.
2. Edit both before autosave: one save may win; the other should display conflict/attention rather than silently discard work. Preserve the local draft and reopen the server version before choosing a restore.
3. Owner chooses **Remove** beside Editor. Member list/code update. Editor sees access changed and exits the private session; its next private lookup fails; the old code cannot rejoin. Previously issued signed playback links remain valid until their one-hour expiry; API authorization revokes immediately. Reopen fetches fresh links.
4. Cancel queued/active work and Retry. A fast completed job may beat the click. Automated tests control the worker for reliable cancellation/idempotency and stale-lease coverage. DB is authoritative; Redis is an optional wake-up transport; local worker processes one job at a time, with up to three pending requests per project.
5. Wait for All changes saved; stop/restart only owned services; sign in and reopen. Expect `data/studio.db`, `data/assets`, project states, snapshots, undo/redo, profiles, jobs and publications retained. Never clear `data/` as a troubleshooting shortcut.

Live transport regression: set `AUREON_GATEWAY_URL=http://localhost:5000`, then `.runtime311\Scripts\python -m pytest tests/test_gateway.py -q`. This exercises real authorized SignalR, byte-range HTTP206 and membership revocation. Core tests use an isolated temporary DB/media directory; they do not reset the preview library.

For this workspace, keep test temporary files on D:

```powershell
New-Item -ItemType Directory -Force .tools/temp | Out-Null
$env:TEMP="$PWD\.tools\temp"
$env:TMP=$env:TEMP
.runtime311\Scripts\python -m pytest tests/test_studio.py tests/test_providers.py -q
$env:AUREON_GATEWAY_URL='http://localhost:5000'
.runtime311\Scripts\python -m pytest tests/test_gateway.py -q
```

## Android artifact and device acceptance

The locally built debug APK is `flutter_app/aureon/build/app/outputs/apk/debug/app-debug.apk`. Its exact size and SHA-256 are in [VERIFICATION.md](VERIFICATION.md). It was built from the final Flutter source with the emulator gateway `http://10.0.2.2:5000`; signed media links resolve through that origin. With an Android emulator already running and `adb` available:

```powershell
adb install -r flutter_app/aureon/build/app/outputs/apk/debug/app-debug.apk
```

Open Aureon and repeat the free guest walkthrough. Expect real gateway connectivity, audio playback, media export and persisted session state. Test microphone permission, denial, recording, secure token storage, interruptions and resume. The APK compiled successfully; no emulator or physical-device execution was performed here. A physical phone needs a new build with a reachable gateway origin and intentional network binding. The debug manifest permits local HTTP; release builds require HTTPS. iOS is prepared for unsigned macOS CI but has not been compiled or tested on this Windows host.

## External/device gates and troubleshooting

- **Waiting for studio:** check Python `/health`, gateway `/api/v1/health`, `logs/`, compiled API_BASE_URL and exact allowed UI origin. Hard reload after replacing release files. No connection should produce a clear unavailable state.
- **Demucs:** use an isolated Python 3.11 worker, install core plus `requirements-neural.txt`, select model/device with DEMUCS_MODEL/DEMUCS_DEVICE (default htdemucs/cpu). Weights may download and CPU inference may be slow; the adapter times out after 420 seconds and fails explicitly. Test genuine outputs and audible vocal separation before advertising neural inference as verified.
- **Sarvam:** configure SARVAM_API_KEY before starting Python; test a small consented Bulbul v3/Saaras v3 request and confirm quota/audio/transcript. Contract tests are mocked, not paid-provider proof.
- **Ollama/XTTS:** run/download actual models and configure their environment. Settings availability only means configured/installed. No model output was verified here.
- **Platforms:** Android needs its SDK/device; iOS needs macOS/Xcode and signing/device QA; Windows native needs Developer Mode/plugin symlinks. Verify mic permission, playback drift, save dialogs, secure storage and accessibility on real devices. CI has Android debug and unsigned macOS iOS jobs; remote execution is separate from local results.
- **Production stack:** Docker/Postgres/Redis/private S3 configs exist but need runtime/service/backup/restore checks. Public hosting is deferred. Account recovery, quotas, malware scanning, sitewide moderation and provider spending policy are production work.

See `CAPABILITIES.md`, `VERIFICATION.md`, `ARCHITECTURE.md` and `RELEASE_PLAN.md` for honest release evidence. Do not claim legacy MusicGen/RVC/singing/MIDI/Ableton experiments as completed features.
