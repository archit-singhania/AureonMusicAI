# Aureon studio theme refinement

The maintained Flutter application now uses an explicit warm-pearl and deep-ink palette with iris, terracotta and sea-glass accents. Navigation, sheets and transport use bounded glass; the lyric editor, mix controls and analysis retain opaque tonal surfaces. All Material text roles and controls share the same typography and palette.

| Role | Light | Dark |
|---|---|---|
| Canvas | `#F8F5F0` | `#12151E` |
| Content | `#FEFCF8` | `#1C202C` |
| Primary | `#6850AD` | `#C5B3FF` |
| Secondary | `#9B4F43` | `#F0AD9E` |
| Accent | `#346A5C` | `#9CCFC0` |
| Text | `#252331` | `#F4F0F9` |

Manrope is bundled locally as a variable font for the geometric display and readable control hierarchy. Existing bundled Inter provides explicit symbol fallback, including the live-status dot. Font licences are `flutter_app/aureon/assets/fonts/Manrope-OFL.txt` and `OFL.txt`. No runtime font-provider integration is required for these two families; Flutter's fallback handling for other scripts remains platform dependent.

The brand mark and startup shell now use the same iris gradient. Buttons have theme-aware foregrounds, inputs use tonal fills, navigation has an outlined selection, and numeric action labels use tabular figures. Waveform and spectrum colors follow the current theme and repaint immediately when it changes. High contrast strengthens text and outlines; reduced transparency removes glass blur; reduced motion retains the existing disabled-transition behavior.

## Manual review

1. Open the current local web release at `http://localhost:3005` with the gateway on port 5000. The welcome screen should have a pearl canvas, floating glass rail, large Manrope heading and iris/coral artwork.
2. Choose **Try the studio** to create the labelled guest fixture. The completed studio should retain readable waveform, mixer, inspector, faders and exports. Open **Library**, **Discover**, **Activity**, and **Settings** to review the shared typography and tonal surfaces.
3. Choose **Dark** in Settings. Expect deep ink surfaces, warm pale text, lavender action controls and softer coral accents. Switch to a 390px viewport to inspect the floating navigation dock and vertically arranged studio.
4. Enable **Reduce transparency**, **Reduce motion**, and **Increase contrast**. Glass should become opaque, transitions should stop, and text/outlines should become stronger. Reload and confirm the preferences remain enabled.

Theme contrast tests require at least 4.5:1 for regular text, secondary text, primary action labels and selected navigation labels in both appearances, including high contrast. Existing responsive tests cover desktop, tablet and 390px phone layouts, with 1.6× text and a completed phone master.

Fresh screenshots and browser receipts are stored separately from earlier release evidence. The first browser attempt in `screenshots/premium-polish-2026-10-06` and `demo/premium-polish-2026-10-06` completed nine real steps with zero page errors, then timed out waiting for its stem ZIP download. That partial result is retained; it is not a full journey pass.

The gateway recorded that ZIP request as HTTP 499 after 10.73 seconds, consistent with the client's former ten-second first-byte budget. Binary exports now have a scoped sixty-second connection/first-byte budget, retaining ninety-second receive timeout and the original ten-second budget for ordinary API calls. Authenticated export tests verify those boundaries. Export errors show an actionable retry message; an empty response cannot be saved as a successful export.

## Final acceptance

| Check | Result |
|---|---|
| Final Dart analyzer | No issues found |
| Current Flutter tests | **19 passed**, including paired text/action contrast, appearance repaint and authenticated export-budget regressions |
| Current web release | Passed in **102.2 seconds** |
| Current Android debug build | Passed offline with JDK 21 in **30 seconds**; 394 tasks, 24 executed |
| Real browser feature regression | **19 steps passed**, zero page errors; ZIP returned HTTP 200/application/zip, 7,970,400 bytes in 2.36 seconds |
| Final appearance review | **7 current captures**, zero page errors; local Manrope and Inter both returned HTTP 200; desktop/phone light, dark and opaque high contrast inspected |

The full browser feature regression is in [its receipt](demo/premium-polish-final-2026-10-06/guest-workflow-evidence.json). It ran after the export repair and before the final painter-only change. The subsequent [current visual receipt](screenshots/premium-polish-current-2026-10-06/visual-receipt.json) and the 19 current Flutter tests verify that change. Processing, persistence and export code remained identical between these checks. Native device execution and reference-device 60 fps profiling remain separate from these browser/build checks.

Current captures: [welcome](screenshots/premium-polish-current-2026-10-06/welcome.png), [light desktop](screenshots/premium-polish-current-2026-10-06/studio-light.png), [dark desktop](screenshots/premium-polish-current-2026-10-06/studio-dark.png), [light phone](screenshots/premium-polish-current-2026-10-06/studio-phone-light.png), [dark phone](screenshots/premium-polish-current-2026-10-06/studio-phone-dark.png), [opaque desktop](screenshots/premium-polish-current-2026-10-06/studio-accessible.png) and [opaque phone](screenshots/premium-polish-current-2026-10-06/studio-phone-accessible.png).

The [final build receipt](demo/premium-polish-final-2026-10-06/build-receipt.json) records artifact hashes and embedded font/origin checks. The Android artifact is `flutter_app/aureon/build/app/outputs/apk/debug/app-debug.apk`, 192,455,347 bytes, SHA-256 `11f37372a2504a5a312374bd59bcebf2e49e02d8f01bbc4cdec6347dc9be5e6d`, modified 6 October 2026 at 13:32:47 +05:30. It includes the export fix and emulator gateway `http://10.0.2.2:5000`. The final web JavaScript SHA-256 is `bb12aa0537574b626bd80e2b5d9683992b53e8283ac63a07a1a5651008f277d3`; the current visual receipt matches it.
