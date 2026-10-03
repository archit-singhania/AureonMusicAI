# Verification record

Executed on Windows, 1–3 October 2026. The final local preview uses Flutter web on port 3005, the .NET gateway on port 5000 and the Python 3.11.17 service on port 8103, with persistent private SQLite data and media. The product scope is the original 20 capabilities in [CAPABILITIES.md](CAPABILITIES.md); appearance, authentication and platform foundations are additional work.

| Check | Executed evidence |
|---|---|
| Python 3.11 core and provider regressions | `pytest tests/test_studio.py tests/test_providers.py -q`: **14 passed**. Checks decode real PCM, MP3, ZIP and MP4 outputs; changed DSP and peak protection; ownership, persistence, revisions, history, consented profile reuse, artwork templates and moderation. Cancellation during native work persists as cancelled after either success or failure. Foreign private asset references are rejected at project creation and publication. |
| Live .NET transport | `AUREON_GATEWAY_URL=http://localhost:5000 pytest tests/test_gateway.py -q`: **2 passed** against the final services. Checks cover authorized SignalR/outbox delivery, HTTP 206 byte ranges and immediate membership revocation for private API access and events. Together with the core suite, **16 backend tests passed**. |
| Additional runtime | The earlier Python 3.12 core/provider suite passed 11 tests before the final three review regressions were added. Python 3.11 now uses verified NumPy 1.26.4, SciPy 1.15.3 and Librosa 0.11.0 dependencies. Requirement markers retain Python 3.12 support. |
| .NET build and local launcher | .NET SDK 10.0.401, targeting net10.0: **0 warnings, 0 errors**. An isolated launch on ports 8113/5013 passed readiness, proxied FFmpeg health, owned-process shutdown and port-release checks. Occupied default ports are rejected before build/start. |
| Flutter | **Analyzer clean; 12 tests passed.** Coverage includes welcome/library/settings at 390/1440 px, dark studio at 390/800/840/1440 px, exact PCM WAV encoding, coordinated saves and updated library titles, grid fields, offline drafts, measured A/B and the phone artwork editor. |
| Web release | Flutter 3.47.3 release built with `API_BASE_URL=http://localhost:5000`. Output: `flutter_app/aureon/build/web`. A nonfatal missing Cupertino icon-font warning remains; Material icons are present. |
| Android debug | The final JDK 21/Android build passed using the isolated D-drive Gradle cache. It includes the responsive phone-title correction and `API_BASE_URL=http://10.0.2.2:5000`. Compilation passed; an emulator or physical device was not run. Artifact metadata appears below. |
| Real browser fixture | A fresh headless Chrome context completed nine real steps: guest creation, original render, master play/pause, saved bass mute, remix with previous master, Library reopen, WAV download, artwork render and MP4 preview. The actual video element decoded media and its playback clock advanced. **Zero page errors.** Recording, exported audio and evidence are in `docs/demo/`; 1440/390 px captures are in `docs/screenshots/`. |
| Hosting configuration | Vercel/Netlify configuration parsed. Hosted build URL validation accepts HTTPS origins and rejects public localhost/unsafe origins. No hosting target was linked or deployed. |

## Android artifact

- Path: `flutter_app/aureon/build/app/outputs/apk/debug/app-debug.apk`
- Size: **191,850,733 bytes**
- SHA-256: `91878EC07CE59022FCDF1FCCA1BEF37B0585EA2E5FC3A50C355BA04F9CD38B34`
- Compiled gateway: `http://10.0.2.2:5000`, the Android emulator's address for this host. Private media URLs returned by the service are relative and resolve through that client gateway origin.
- Debug HTTP transport is enabled for the local emulator; the release manifest disallows cleartext. A physical phone needs a reachable gateway, appropriate binding and a build using its intended HTTPS origin.

The web release and APK use the final Dart source, including the phone-title layout. CI provides manual workflow dispatch, Python 3.11/DSP/gateway checks, Flutter web/tests, Android debug and macOS unsigned iOS build/artifact jobs. No remote CI run was triggered. iOS/macOS compilation, signing and actual-device checks remain open.

## Remaining gates and practical limits

Live Sarvam calls, XTTS/Ollama inference, genuine Demucs weights/inference, Docker/Postgres/Redis/private S3 and native microphone/playback/accessibility remain unverified. Demucs tests cover explicit gating and its real-file/decoder contract with a mocked process, rather than neural inference. Imported spectral DSP is approximate and makes no vocal-isolation claim.

Uploads are limited to 50 MB and 180 seconds. Cancellation is checked between stages. The local service has one worker and permits up to three pending requests per project. Its stale-processing lease is 10 minutes. Signed private-media links expire after one hour; already issued links remain playable until expiry after membership removal.

The first Android build and temporary SQLite checks exhausted C-drive capacity. Both were retried with D-scoped `TEMP`, `TMP` and `GRADLE_USER_HOME`; no user or system files were deleted. The final 14 core/provider tests and two live gateway tests passed with the isolated D temporary directory. One upstream Starlette/httpx deprecation warning and Android toolchain deprecation warnings remain.

The authorized Git cleanup identified 2,597 existing generated/cache entries under .NET bin/obj, Flutter build/.dart_tool/plugin metadata, Python venv/__pycache__ and logs. Cleanup preserves all files on disk and private data; the final workspace integration checks the index after source edits. This agent performed no commit, push or public deployment.
