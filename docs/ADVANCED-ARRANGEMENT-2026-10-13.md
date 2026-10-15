# Arrangement timeline and automation — October 13, 2026

The first two Aureon additions are implemented. The Flutter studio edits a versioned, non-destructive arrangement; the private Python worker produces actual audio through durable `arrangement_render` jobs. The existing .NET gateway forwards authenticated snake_case contracts. Final acceptance results and source hashes are in the adjacent JSON receipt.

## Manual acceptance

1. Start services using the repository setup guide. Sign in, open an owned project in Library, and generate a master or import an audio asset. Opening an older completed project creates a single-master arrangement without modifying its source. Snapshots and undo remain available.
2. Open Studio. Expect a glass arrangement toolbar, readable beat grid, tracks and focused clip inspector. The accessible track/clip list provides selection without dragging. Light/dark themes and narrow layouts retain the palette and accessibility preferences.
3. Select a clip. Edit timeline start, source offset, length, repeats and fades; nudge or drag to move. Zoom and 1/16-beat snapping survive relaunch. Move the cursor and split a non-repeating clip outside its fades. Pieces retain contiguous source samples. Change repeating clips to one repeat before splitting.
4. Add another owned audio source as a track. Rename, mute, adjust gain/pan or remove it. Add section markers. For crossfades, overlap clips and set matching outgoing/incoming fade lengths. Original assets remain unchanged.
5. Select volume/pan automation. Add/edit/remove integer-sample points and select linear/hold interpolation. Drag handles or enter exact values through keyboard-accessible dialogs. Inspect cursor values. Volume/pan are supported; extra effects are not advertised.
6. Render arrangement and follow actual job state. Done results become playable masters; download and decode the WAV. Overloaded audio fails with a headroom instruction. Cancellation/retry use the existing queue.
7. Play the rendered preview. Expect the cursor to follow playback and retain its paused position. Edits require another render: preview plays the last completed render. Reopen and verify clips/markers/curves; undo restores a saved state.

## Limits and checks

Canonical timing is integer samples at 44,100 Hz. Sources are normalized and rendered in bounded chunks. Limits: 180 seconds, 16 tracks, 200 clips. Fade-boundary and constant-signal crossfade tests check continuity. Foreign assets, stale revisions, fractional positions, invalid bounds and unsupported envelopes are rejected.

Checks: 25 isolated Python tests; 29 Flutter regression tests plus a repeated four-test editing suite; clean analyzer; .NET Release build and three gateway checks; web Release and Android debug builds. The browser receipt records actual generation, migration, editing, rendering, playback, persistence and theme/layout captures. Physical Android/iOS, macOS/iOS builds and professional low-latency preview remain unverified or outside scope.

## Test-isolation correction

A collection-order mistake initially allowed tests to use the default local database. Tests now select a temporary database before collection. The default store was backed up to `.tools/storage-backups/2026-10-13-before-isolation-repair.db`; records of uncertain origin were preserved. The fresh isolated 25-test run supersedes earlier combined-suite results. Browser acceptance uses separate task-owned storage.

Reference-track matching is now implemented; see [its manual guide](REFERENCE-MATCHING-2026-10-13.md). Take comping and release kits remain pending. The adjacent arrangement receipt records the earlier acceptance snapshot; the reference receipt records the newer source and regression results.
