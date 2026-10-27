# Mastering quality checks

Render a master, then open Studio → Mastering quality. Set a LUFS target, estimated true-peak ceiling and silence duration threshold. Analyze saved master queues the real private Python worker through the .NET gateway. Watch Activity for processing, cancellation, failure and retry.

Results include integrated loudness, a four-times-oversampled polyphase peak estimate, full-scale frame count, stereo correlation, mono fold-down energy change and long silence ranges in canonical sample coordinates. A constant/silent source yields null where a measurement is undefined. JSON export contains the exact stored report and target profile. Old reports are explicitly historical after the current master changes.

Findings never change source audio or certify a release. Adjust the existing mix controls and render a new version before analyzing again. True peak is an estimate rather than certified conformance metering. Silence ranges have 100ms boundary resolution. Supported input is mono/stereo, 0.5 seconds–20 minutes, 8–96 kHz, with a 128 MiB decoded-input budget. Oversized/unsupported inputs fail visibly.

Contracts: additive `mastering_quality` project settings with backward-compatible defaults; `mastering_analysis` job kind; `quality_report`, `report_asset_id` and `source_master_asset_id` result fields. The gateway already forwards these snake_case payloads. Existing audio assets remain immutable and owned. Heartbeats are throttled while analysis checks cancellation.

Acceptance October 27, 2026: real DSP fixtures for clipping, silence, phase and mono loss; source hash preservation; cancellation; stale-master rejection; owned report export; real .NET gateway processing/download; Flutter phone/desktop report validation and existing widget regressions. Full Python regression: 34 passed, four optional gateway tests skipped and separately passed against the gateway. Analyzer clean.

The rebuilt release web app passed a real Chrome journey: sign in, open a generated project, request analysis from the UI, wait for the worker, and download the measured report. Downloaded JSON exactly matched the persisted job report; source audio SHA-256 stayed unchanged; no page errors occurred. Desktop light/dark and 390px phone captures and the receipt are in `screenshots/mastering-2026-10-27/`. `source-artifact.json` records relevant source and web bundle hashes. The web build is configured for the local acceptance gateway on port 5094, not public deployment.

To repeat on this configured Windows workspace, build Flutter web with `--dart-define=API_BASE_URL=http://127.0.0.1:5094`, then run `tools/mastering-browser.ps1`. It checks ports 8114/5094/3094, creates isolated fixture storage, uses the existing gateway binary, runs `tools/mastering_acceptance.cjs`, and stops only its own services. Prerequisites are the installed .NET/Python/Chrome/Playwright runtimes; paths are explicit in the runner. The runner never touches live accounts.

The Android `assembleDebug --offline` build passed. Local artifacts are `.tools/mastering-release-20261027/aureon-web-local.zip` and `aureon-android-debug.apk`; SHA-256 values are recorded in the source/artifact manifest. The ZIP's JavaScript matches the tested bundle. The APK defaults to the Android emulator host gateway `http://10.0.2.2:5000`; installation and physical playback have not been tested. It is a debug test package, not a store release.

The web build reports a Cupertino icon-font warning; no missing icons were observed in the captured mastering journey. Android reports Gradle/Kotlin plugin deprecations. Broader accessibility, performance and device verification remain release work.
