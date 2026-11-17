# MIDI composition

Open Studio and find **MIDI composition**. Tap the piano roll or select **Add note**. Enter the start tick, length, pitch, velocity, and channel. Pitch 69 is A4. The numeric editor supports the full MIDI pitch range, while the grid displays pitches 49 through 72. Choose keys, bass, pad, or pluck to change the locally synthesized instrument.

Set the grid division and turn snapping on or off. **Quantize starts** moves note starts to the nearest grid position. **Undo quantize** restores the preceding positions before another score edit. The project also retains saved revisions. Loop endpoints use ticks. Setting a repeat count above one repeats that region in the rendered audio.

Choose **Import MIDI** to preview a standard type 0 or type 1 file. The preview reports unsupported events and asks before replacing the score. Import preserves ticks per quarter note, note pitch, channel, velocity, tempo changes and sustain controller events. Imported tempo events take precedence over project tempo. New scores follow project BPM until they contain an explicit tempo event.

After autosave, **Export saved MIDI** downloads a standard MIDI file containing the score's notes, tempo and sustain events. Instrument timbre and the studio loop are project settings. **Render instrument** queues a local job that creates playable PCM audio with those settings. Open Activity to inspect the job, then use its finished asset in an arrangement or export. A missing score or an excessive render duration produces an error.

The importer accepts files up to 256 KiB and scores up to 2,048 notes. The renderer checks cancellation and bounds voice processing and output duration. Older saved projects open with an empty score. Saving from an older client preserves an existing score when that client omits the MIDI field.

The automated journey imports a file, reopens the saved score, exports and reparses it, and decodes a real looped render. A separate fixture checks all four timbres, a 440 Hz tone, timing under a tempo change, and sustain after key release. Flutter coverage includes quantization undo, phone layout and large text. Physical file-picker interaction, device playback, complete browser interaction and release performance measurements remain open.
