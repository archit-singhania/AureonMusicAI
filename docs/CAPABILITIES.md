# Capability matrix

Core means implemented without a paid provider. Verified means an executed test or build in this workspace. Device checks and optional external services are recorded separately.

| # | Capability | Implementation and acceptance evidence |
|---|---|---|
| 1 | Responsive premium workspace | Flutter pearl/graphite/system themes, original brand, desktop/phone navigation; widget layouts at 390/800/840/1440 px. |
| 2 | Accessible appearance | Reduce motion/transparency, semantic controls, accessible contrast, safe area; responsive widget tests. |
| 3 | Private accounts and session authorization | Scrypt passwords, hashed expiring tokens, project ownership/editor access; auth/ownership and live gateway tests. |
| 4 | Persistent session library | SQLite locally/Postgres configuration, searchable projects, duplicate/archive; durable save/revision tests. |
| 5 | Autosave, local recovery and history | Debounced saves, optimistic revisions, device draft persistence, snapshots/restore; revision-conflict and restore tests. |
| 6 | Original preset composition | Five deterministic compositions, editable tempo/key, real preview audio; synthesis and measured-master tests. |
| 7 | Audio import and analysis | Bounded upload, codec decode, estimated BPM/key/confidence; actual WAV import tests. Estimates may be inaccurate. |
| 8 | Four-stem session | Exact generated instrument stems; imported music uses approximate HPSS spectral DSP. Real stem ZIP tested; no neural vocal isolation claim. |
| 9 | Consent-based recording workflow | Flutter microphone PCM/WAV, consent flag and owned voice upload; WAV header/upload tested, device microphone gate remains. |
| 10 | Optional multilingual speech | Sarvam Bulbul v3 adapter and local XTTS adapter; missing-provider gating and Sarvam contract tests. Paid call/XTTS weights unverified. |
| 11 | Lyric notebook and assistance | Persistent lyric drafts, approximate English syllable helper; optional real Ollama request, unavailable-provider test. Model inference unverified. |
| 12 | Live stem mixer | Common transport, gain/mute/solo, periodic drift correction, DSP render; actual changed master compared in audio tests. Hardware latency varies. |
| 13 | Real DSP processing | Tape saturation, feedback delay, stereo width, de-esser and oversampled peak protection; finite measurable changed audio tested. |
| 14 | Measured master analysis | PCM waveform/spectrum, integrated LUFS, true peak and duration; actual decoded output and headroom assertions. |
| 15 | Master A/B and loudness matching | Previous/current render playback with common seek and quieter measured-LUFS gain; measured selection/attenuation regression tested; browser audition remains a manual gate. |
| 16 | Persistent render jobs | Database-backed queue, Redis wake-up, progress, cancel/retry/idempotency, stale-job recovery; actual render/cancel/retry tests. |
| 17 | Real exports | 24-bit stereo WAV, MP3, stem/session ZIP and portrait audio visualizer MP4 via FFmpeg; decodable media/MP4 container tests. |
| 18 | Explainable mix copilot | Prompt-to-supported-DSP proposal, explicit review/apply; proposal test. Deterministic rules, not an LLM sound engineer. |
| 19 | Collaboration and live updates | Invite/join/editor/revoke, revision conflicts, authorized SignalR + event replay; member permission and gateway event tests. No simultaneous DAW sample collaboration claim. |
| 20 | Original artwork and community | Generated original cover template/image upload, real publication/master play, likes/comments/unpublish; publication/comment/like tests. No AI-image-provider claim. |

Production deployment additionally provides Postgres, Redis, private S3-compatible storage configuration, nginx streaming proxy, container definitions, and CI. Those integrations need configured service verification before production use. Historical experiments (MusicGen, RVC, vocoder, MIDI, Ableton) remain unavailable in the core capability endpoint.
