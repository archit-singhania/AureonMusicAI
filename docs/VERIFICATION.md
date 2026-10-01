# Verification record

Executed locally on Windows, 1 October 2026. The working preview uses Flutter web 3005, .NET 5000, and Python 8103 with a private SQLite data directory.

| Check | Evidence |
|---|---|
| Python end-to-end and provider contracts | `pytest tests/test_studio.py tests/test_providers.py -q`: 9 passed. Tests decode actual PCM, assert measured headroom/finite audio, compare changed renders, inspect MP3/ZIP/MP4, validate auth/revision/ownership/cancellation/retry, expired processing-lease recovery, and official optional speech payloads. |
| Full Python/gateway suite | `AUREON_GATEWAY_URL=http://localhost:5000 pytest -q`: 11 passed after core/provider formatting and final live membership checks. |
| .NET release build | SDK 10.0.401, target net10.0: 0 warnings and 0 errors. |
| Gateway journey | `AUREON_GATEWAY_URL=http://localhost:5000 pytest tests/test_gateway.py -q`: 2 passed. Actual authorized SignalR outbox delivery and HTTP206 byte-range media and live membership revocation are exercised. |
| Flutter analyzer | Flutter 3.47.3: no issues found. |
| Flutter responsive tests | 10 passed: welcome/library/settings at 390/1440 px, editable dark studio at 390/800/840/1440 px, exact recorded PCM WAV header/payload, coordinated autosave, offline draft retention, and measured A/B attenuation/selection. |
| Flutter web build | `flutter build web --no-pub --dart-define=API_BASE_URL=http://localhost:5000`: successful release web output. |
| Manual browser review | Welcome 1440 px reviewed by root agent; original brand, readable layout. A recorded real guest workflow completed original rendering, playback, bass mute/remix, persistent reopen, and WAV download with zero page errors. See `docs/demo/`. |

Known tooling gates: Docker is unavailable on this host, so Compose/Postgres/Redis/S3 are configured but not runtime verified. Windows native plugins need Developer Mode symlinks; Android and iOS need their platform toolchains/devices. Actual microphone hardware and precise multi-player latency require device QA. Sarvam HTTP contract tests are mocked; paid provider access was not used. XTTS/GPU weights and Ollama inference were not available. GitHub Actions definitions are supplied; no remote CI was triggered.

The test-client library emits one upstream Starlette/httpx deprecation warning. Builds and tests did not expose a functional failure from it. Current processing limits are 50 MB uploads and 180 s audio; cancellation is checked between stages and stale jobs reclaim after 10 minutes.

A generated-artifact cleanup removed 2,597 already tracked cache files from the Git index without deleting disk contents: .NET bin/obj, Flutter build/.dart_tool/plugin metadata, Python venv/__pycache__, and generated service logs. Source code, real assets, platform runners and private data are preserved. No commit or push was made.
