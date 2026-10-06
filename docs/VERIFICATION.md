# Verification record

Final local checks ran on Windows on **5–6 October 2026**. The maintained product uses Flutter 3.47.3/Dart 3.13.3, ASP.NET Core 10 and Python 3.11.17. Preview: port 3005; gateway: 5000; Python: 8103. Audit accounts and media use `.tools/audit-2026-10-05-data`; ordinary private `data/` is preserved. The approved 20 capabilities and optional engine limits are in [CAPABILITIES.md](CAPABILITIES.md). Detailed results and the manual feature inventory are in the [full audit](FULL-AUDIT-2026-10-05.md).

| Check | Executed evidence |
|---|---|
| Python core/provider regressions | **19 passed**, 142.07 seconds on 5 October. Actual PCM/MP3/ZIP/MP4 decoding, changed DSP/peak protection, ownership, persistence, revisions/history, profiles, artwork/moderation, cancellation/recovery, neural adapter gating and malformed lyric replies preserving drafts. |
| Dependencies | **62 installed distributions, 0 conflicts** in the isolated Python environment. |
| Running gateway | **3 passed**, 13.64 seconds on 6 October. Real consented multipart WAV upload/ownership/listing/PCM24 decoding, authenticated SignalR/outbox, HTTP 206 byte ranges and immediate membership revocation. **22 backend tests** across the two suites. |
| .NET release and launcher | **0 warnings, 0 errors**, 31.34 seconds after the multipart resource-filter fix; SDK 10.0.401/net10.0. Private relay/readiness/FFmpeg checks passed. |
| Flutter | **No issues found; 16 tests passed**, 4 seconds on 6 October after the full Inter theme fix. Responsive editors, 1.6× text/contrast phone and desktop, completed phone master, covered playback, WAV encoding, saves/offline drafts, grid, artwork and measured A/B. |
| Web release | **Passed**, 44.3 seconds on 6 October, `API_BASE_URL=http://localhost:5000`. Bundled Inter and CanvasKit; nonfatal existing Cupertino icon-font warning. |
| Android debug | **Passed**, 1 minute 6 seconds on 6 October; JDK 21, offline D-drive cache; 394 tasks (28 executed, 366 up-to-date). Emulator gateway `http://10.0.2.2:5000` is compiled into the kernel. Device execution remains open. |
| Headless Chrome fixture | **19 real steps, zero page errors**, Chrome 154.0.8037.95 on 6 October. Preset/master identity, autosave/reopen, changed bass-muted remix, WAV/MP3/ZIP/MP4 downloads, portrait playback, artwork/showcase publish/play/unpublish, synthetic microphone saved WAV, light/dark desktop/phone and preferences surviving reload. All nonlocal HTTP requests were blocked; form labels/values and switch titles visibly paint with bundled Inter. |
| Independent media verification | PCM24 stereo 44.1 kHz WAV and MP3, four decoded WAV stems plus session metadata, full FFmpeg decode of portrait visualizer with AAC and silent screen recording, actual stored microphone PCM, durable job receipts and changed/new-master equality. Exact measurements and hashes are in [final evidence](demo/full-audit-2026-10-06/decoded-media-evidence.json). |
| Live local lyric provider | Actual route **503 in 2.56 seconds** on 5 October; Ollama tags connection refused. [Provider receipt](demo/local-lyric-audit-2026-10-05.json). Missing engines/models remain a manual gate; historical inference is not a fresh pass. |
| Hosting configuration | Existing Vercel/Netlify and CI configurations remain available. No remote CI, target linking or deployment ran in this audit. |

The scoped proxy resource filter fixes the demonstrated consumed multipart body. Its real upload test first failed with HTTP 422 and then passed after correction. Core/provider checks were not repeated after changes confined to gateway/client.

The APK is `flutter_app/aureon/build/app/outputs/apk/debug/app-debug.apk`: **191,867,654 bytes**, SHA-256 `9329d5c104674e1a7e6de1ac8d06f1131936af1f4cb6b171561cc0504ee0cb0c`. The [decoded-media receipt](demo/full-audit-2026-10-06/decoded-media-evidence.json) also records its modification time and final web/font hashes. Debug local HTTP is enabled; release manifests disallow cleartext. A physical phone needs a reachable gateway and intended HTTPS build origin. Compilation does not prove native playback, microphone, secure storage or accessibility.

[Recorded journey and audio](demo/README.md) and [16 curated captures](screenshots/README.md) are dated 6 October. Original 3 October artifacts remain historical. Browser media is real; synthetic Chrome microphone input is explicitly a fixture. Headless frame scheduling is recorded without claiming reference-device performance.

Live Sarvam/XTTS/Ollama, genuine Demucs weights/inference, native microphone/playback/accessibility, iOS/macOS/Xcode, signing, Docker/Postgres/Redis/private S3 and public hosting remain unverified. No model download or paid call was made. Demucs tests exercise gating and actual file/decoder contracts with a mocked process; imported spectral DSP is approximate.

Uploads are limited to 50 MB and 180 seconds. Cancellation occurs between stages. Local jobs have one worker, up to three pending requests per project and a ten-minute stale-processing lease. Signed media links expire after an hour; issued links can remain playable until expiry after membership removal while private API/event authorization revokes immediately.

Existing Starlette/httpx and Android toolchain deprecation warnings remain. D-scoped temporary/runtime caches avoid C-drive pressure. Generated-cache hygiene preserves files on disk, ordinary data and private environment files. No commit, push or public deployment was made.
