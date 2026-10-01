# Aureon guest workspace demo

[Watch the recorded workflow](guest-workflow.mp4) · [Listen to the actual exported master](guest-master.wav) · [View the completed studio](completed-studio.png)

This is a real, isolated **guest fixture** workspace on the local Flutter/.NET/Python stack. The recording shows account/session creation through the UI, an original instrumental reaching completion, real master playback, muting the bass stem, rendering a changed mix, reopening the persistent session, and downloading the actual WAV. No API interception, simulated progress, fake waveforms, or paid provider were used. The capture has no browser page errors.

The MP4 is a silent screen recording at 1440×1000; the original WAV is supplied separately. The exported master is decoded and verified as 24-bit stereo WAV at 44.1kHz. `guest-workflow-evidence.json` records the completed steps and measured export metadata. `guest-workflow.webm` is the original Playwright capture.

To reproduce, start the three local services, install Playwright for Node, and run `node tools/record_demo.cjs`. This machine used the bundled Playwright runtime and installed Chrome in headless mode. The script creates a fresh browser context, enables Flutter accessibility semantics, and uses actual UI actions. `AUREON_PREVIEW` can override the URL; `AUREON_PLAYWRIGHT` can point to an alternate installed module. Capture only fixture workspaces for public portfolio evidence.
