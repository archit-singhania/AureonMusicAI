# Take comping and release kit — October 15, 2026

The Studio now includes a **Performance take room** and **Release kit atelier**, extending the existing Liquid Glass panels and accessibility preferences. These are render-first operations: edits preserve the uploaded recordings; a composite creates a new master.

## Manual acceptance

1. Start the services using the README. Sign in and import your own audio in Library. Open its project in Studio.
2. In Performance take room choose **New take bank**, give it a name, and **Add recording take**. Select a take and audition the original.
3. Choose **Select phrase**. Enter integer source/timeline sample positions and length (44,100 samples = one second). Source ranges must fit the recording. Overlap two phrases and give their overlapping ends matching fade lengths for a crossfade. Invalid bounds show a message and preserve the previous edit.
4. Choose **Render composite**. Activity shows real queue/progress/errors with cancellation and retry. When complete, transport plays the new composite. Reload/reopen: bank and phrases remain. Undo/snapshots include the take edits. Originals remain available.
5. Use the existing artwork editor to choose a template and palette. In Release kit atelier choose **Edit release identity**: artist, credits, teaser start and 1–30 second duration within the current master. Save lyrics in the project for lyric cards.
6. Choose **Review release kit**. Check the artist/credits and rights statement. Cancel creates no export. **Confirm and build kit** queues an actual export of the selected master snapshot.
7. **Download release ZIP**. It contains a real master WAV, square artwork, paginated lyric PNGs, square/portrait teaser MP4s with actual audio, credits and a SHA-256 manifest. Open each output and check hashes against the manifest. Preview the images and play/pause videos in the app.
8. Try another account: private takes, jobs and export assets must remain inaccessible. A missing FFmpeg engine, invalid teaser range or processing failure displays an error; it does not report success.

## Verification

- 31 isolated Python tests passed, including source preservation, exact output frames, crossfade continuity, ownership, confirmation, undo, every archive hash and FFmpeg decoding of audio/video in both teasers.
- 33 Flutter tests passed, including phone/desktop editor bounds and cancelled export confirmation. Flutter analysis: no issues.
- Web Release and Android debug builds passed. The real Chrome/gateway/worker journey passed composite rendering, saved identity, explicit rights confirmation, ZIP download, actual teaser playback and reload persistence without page errors. See [acceptance receipt](PRODUCTION-TOOLS-2026-10-15.json).

## Limits

Comping uses numeric phrase selection and render-first audition, rather than live DAW editing. The kit uses editable local templates and static artwork videos; it does not synthesize animations or verify legal rights. User confirmation records their declaration. Unicode font/complex-script coverage needs device-specific checks. Physical Android/iOS checks and signing are not performed here.
