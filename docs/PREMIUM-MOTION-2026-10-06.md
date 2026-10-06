# Aureon studio motion and palettes

Aureon now uses a short, quiet motion system with the locally bundled Manrope hierarchy and Inter symbol fallback. The pearl/ink studio surfaces stay consistent across three named palettes: **Iris** (iris and warm coral), **Copper** (copper and sage), and **Tide** (sea glass and muted rose). Each palette works in light and dark appearance and persists alongside the existing comfort preferences. Navigation, monogram, waveform, spectrum, interaction accents and glass tints follow the selected palette; recorded media and instrument identity colors keep their own meaning.

| Interaction | Behavior |
|---|---|
| Workspace section | 240 ms ease-out fade with an 8 px arrival; pages mount lazily and retain their search, editor and scroll state |
| Cards and content panels | One 240 ms fade with a 6 px arrival per mounted surface; keyed data rows stay stable through polling |
| Sheets | 240 ms open / 180 ms close using the platform sheet transition, with existing close, drag, Escape and focus behavior |
| Voice consent dialog | 180 ms fade with a restrained 3% scale |
| Navigation, palette and playback feedback | 140 ms response; only the playback/status icon changes, retaining the button identity |
| Finished master and activity | A result arrival and status-icon change follow actual asset/job state; progress values still come directly from the job |
| Loading | A reserved 2 px status strip prevents network activity from shifting the page; reduced motion uses a static working strip |

No animation repeats for decoration. Motion transforms do not alter layout measurements. Inactive sections cannot paint, animate, receive keyboard focus or expose accessibility semantics. Real audio playback, measured spectrum frames, seeking, job cancellation, saving and exporting retain their existing behavior.

**Reduce motion** completes surface entrances in flight and uses instant section, palette, theme, icon, sheet and dialog transitions. Video loading uses readable static text in this mode. **Reduce transparency** makes glass opaque; **Increase contrast** strengthens content/outlines and also makes glass opaque. System animation and contrast preferences still participate in the application’s MediaQuery. Contrast checks cover regular/secondary text, action labels and selected palette/navigation labels in every palette and both appearances, including increased contrast.

## Manual expectations

1. Open the local release at `http://localhost:3005` with the gateway on port 5000. Switch among Library, Discover, Activity and Settings. Each section should arrive briefly without simultaneous outgoing controls. Enter a library search, leave and return; the text and page state should remain.
2. In Settings choose Iris, Copper and Tide, then Light and Dark. Action controls, waveform/spectrum, monogram and bounded glass should share the palette. Reload to confirm palette and comfort preferences persist.
3. Open Sign in or a studio sheet. Expect a compact entrance with readable content, an immediately usable close control and keyboard Escape dismissal. Tab through inputs and controls to inspect the normal focus outline. At 390 px, the navigation dock and sheet should fit without horizontal clipping.
4. Choose Try the studio. Real generation should show its reported progress and then reveal the measured waveform. Play and pause the actual master; the icon should respond once while the transport, editor and controls retain their identities. Activity should show the real completion and working Save action.
5. Enable Reduce motion, Reduce transparency and Increase contrast. Section/sheet changes should be instant, no decorative motion should continue, glass should be solid and text/outlines should be stronger. Reload and repeat on a 390 px viewport.

## Verification

The current analyzer, tests, builds, artifact/source hashes and actual browser results are recorded in [the motion receipt](PREMIUM-MOTION-2026-10-06.json). Browser captures and the transition-review recording are in `screenshots/premium-motion-2026-10-06`; the current real feature journey is in `demo/premium-motion-feature-2026-10-06`. These checks cover a local browser release and Android compilation. Native device execution and reference-device GPU/frame-rate profiling remain unverified.
