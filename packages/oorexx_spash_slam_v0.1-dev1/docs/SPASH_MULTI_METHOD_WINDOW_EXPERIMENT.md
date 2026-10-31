# SPASH windowed multi-method example search — experimental method (2026-10-31)

Architecture: Tom Dyer. Executed reference experiment and documentation: ChatGPT GPT-6.

## Purpose
Treat the short user-reviewed phone-conversation specimen and earlier short captures as acoustic examples, not named events or speaker identities. Each original recording channel is examined across the entire source timeline. No audio is excluded because there is no video event. Video events supply optional unaligned navigation context only.

## Recovered experiment summary
Six original recordings, seven actual recorded channels. Six reference examples: one approximately 5.136-second phone conversation, one approximately 9.996-second listening excerpt, one 28-second V7 excerpt and three prior subsecond acoustic clips. All source/reference audio is private and deliberately excluded from GitHub.

The 500 ms analysis scanned 51,637 channel-windows; the additional 250 ms short-example analysis scanned 103,278 channel-windows. The 154,915 views overlap and are NOT independent measurements. Search retained 4,026 method-scored candidate rows for review, NOT 4,026 confirmed human-voice matches. The balanced private review package contains 28 candidate intervals and 84 verified WAV listening derivatives: unamplified original, band-pass 180–3400 Hz, and FFT denoised. Audio sources were not modified.

## One STFT foundation, four processing views
All use 8 kHz experimental decoding, 512-point Hann-window STFT, 256-sample hop, and 24 logarithmic frequency bands spanning about 90–3800 Hz, aggregated to the block window.
- SHAPE: normalize nonnegative band amplitudes, with overall amplitude removed.
- VOICE_BAND: suppress the bands outside 240–3100 Hz, then normalize.
- RESIDUAL: subtract 85% of a nine-block running-minimum per-frequency baseline before normalization.
- CEPSTRAL: log-normalized spectrum followed by DCT-II, 10 non-DC cepstral coefficients, and vector normalization.

Each reference is decomposed into short active subsequences. Each source block trajectory is evaluated under a matching method with sliding ordered-window comparison. Spectral methods use one minus half the mean timewise spectral-vector L1 difference; cepstral uses rescaled cosine. Retain source identity, input channel, exact nominal window offset, reference span, method and evidence foundation. Score values are heuristic likeness, not calibrated probabilities. Different methods reusing the same STFT are NOT independent corroborating microphones.

## Qualification
A two-second portion of the private reference was copied into a synthetic test signal at exactly seven seconds, its amplitude multiplied by 0.7, and low noise added. All four methods recovered the known insertion at 7.0 s; the inserted-copy score exceeded both unrelated white-noise and constant-tone controls under each method. This is a unit control, not an independent speech-recognition claim. All 84 locally rendered private listening clips passed SHA-256 checks, and the ZIP passed archive CRC/integrity checks.

The recovered camera/door/vehicle event tables use decoded-video-PTS-relative times. Audio sample offsets have NOT been qualified against those clocks. Nearest-event fields are explicitly UNALIGNED hypotheses, not temporal or causal correspondences.

The running experimental code and actual private audio review outputs are delivered separately in the private package, not published in this source PR because scripts currently hardcode private local source paths. Their algorithmic ideas must be transferred behind the existing ooRexx Audio V9/Media Methodologies provider interface before production qualification.

## Next gate
Review the 28 candidate listening intervals using the private offline browser. Preserve review labels independently of similarity scores. Evaluate method-specific false positives and omitted intervals, then progress to source-clock-qualified FC/FD geometry and 3D propagation tests. No inferred transcript, speaker identity, acoustic emitter count, room location or independent virtual microphone observation.