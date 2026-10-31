# SPASH virtual-audio execution alignment — v0.3 (31 October 2026)

Architecture and processing model: Tom Dyer. Additive native adapter: ChatGPT GPT-6.

## Supersession

**SPASH is not an alternative Python DSP stack.** Previous `spash_find_similar.py`, `spash_v7_scan.py`, local WAV/FFT comparisons and the two-interval +32 dB/four-listening-view experiment remain **historical reference/diagnostic results**. They do not own production spectral measurement, path reconstruction, virtual microphone synthesis, gain tracking or state management.

The SPASH production path must reuse these **existing Alchemy contracts**:

1. **Audio V9 Pattern Locator dev6 / Voice Recovery dev16:** the native FFT Spectral Pattern Field, time/frequency moving boxes, ML pattern hashes, coherent source/path measurements, delay, masks, gain policy and reconstructed listening products.
2. **Media Methodologies dev8:** method registry and source-lineage-aware provider profiles for `AUDIO.MULTIPATH.PATH_ESTIMATE`, `AUDIO.MULTIPATH.SPECTRAL_TRACK`, `AUDIO.MULTIPATH.MOTION_COHERENCE`, `AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY` and `AUDIO.RECON.MULTIPATH_VIRTUAL_MIC`. Continue to use its work shapes: path-estimation event halo, spectral TRACK_STATE and 8192/8192 sample halo, motion ACCUMULATOR_STATE with 1 observed sample of continuation, and virtual microphone TRACK_STATE with 8192/8192 halo. SPASH does **not** execute its own Python fallback when those providers are unavailable.
3. **Physics World dev50, geometry v0.4:** FC/FD physical microphone positions, property/room polygons, open rear stairwell aperture, rear terrain reflector, Room-F candidate trajectory evaluations, compact `physics.f11.candidate-summary/3` and the existing `F11AcousticEvidenceMatcher~score` comparison. Candidate scores are tolerance-normalized residuals, not probabilities.
4. **Audio V9 Cluster/Memory candidate20:** source PCM, STFT, curves, state and caches remain resident behind Memory Fabric block refs; only compact execution/continuation and evidence references move via already authorised Cluster Object transport. No encoded PCM in movement envelopes.
5. **SLAM bridge:** source-SHA units and SPASH namespaced nodes; continuation hypotheses remain PRIOR until checked by an independent source.

## New native adapter

`src/SpashVirtualAudioExecution.cls` defines `SpashVirtualAudioExecution`:

- Constructor **injects** a real `MediaAudioV9ProviderRegistry`, an existing observed-two-mic `SpashDualMic3D` model, and an optional Physics World matcher. These objects own their operations; no FFT/filtering algorithm was copied.
- `plan(keypointId, observedFeeds, startSample, sampleCount, sampleRate, clockEvidence, measuredPaths, requestedListeningGainDb)` resolves the five registered methodology profiles, rejects unpinned or duplicate original sources and retains exact sample bounds. The plan never claims completed DSP.
- To declare two-feed spatial execution ready, require two distinct source SHA-256s, `clockEvidence.AUTHORITY=OBSERVED_CROSS_FEED_ALIGNMENT` with its explicit uncertainty, and coherent acoustic-path records carrying an original source hash. An arbitrary string clock name or numerical path count is insufficient. This gate does not itself certify the producer's accuracy.
- `virtualField(sourceHypothesis, positionsByRole, emissionMs)` delegates to the existing two-mic model and requires **four model-only** predictions in roles `PREDICTED_SOURCE`, `STREET`, `STAIRWELL`, `OTHER_FLAT`. Positions must be passed from Physics World; no invented coordinates are built into SPASH.
- `comparePhysics(candidateSummary, observedEvidence)` delegates to the existing `F11AcousticEvidenceMatcher`. It refuses to invent a score when evidence/model is absent.
- Evidence stays at **0 dB gain**. `poi1.ogg` is a fixed, clear acoustic query: **NO GAIN, NO FILTER, NO MUTATION**. +32 dB is a *requested listening transformation* for a separately generated TP-derived candidate; Audio V9 governs floating point processing, transient hold and output limiting. Nothing changes the source acoustic signal or likelihood.

## Execution sequence

```text
POI1 (immutable query) + original FC/FD samples + source hashes
    -> Audio V9 native spectral field, observed coherent paths
    -> SPASH observation/likeness/path PRIOR graph
    -> Media Methodologies runtime selection + state/halo policy
    -> Physics World F11 3D candidate trajectories and residuals
    -> four modelled viewpoints (predicted, street, stairwell, other flat)
    -> Audio V9 native trajectory-conditioned non-amplifying reconstruction
    -> separate +32 dB / limiter listening branch for original TP sources
    -> source-hash-bound listening/human validation and SLAM evidence
```

A single physical feed or derivative channel is **not** evidence of a stereo baseline. Likewise, video-PTS vehicle/door events may condition experiments only after explicit audio/video clock calibration; they cannot admit unmeasured acoustic paths or supply inferred source locations.

## Qualification and status

Native ooRexx 5.3.0 r13196 internal test: `tests/test_virtual_audio_execution.rex` **24/24 PASS** locally, with injected provider spies verifying method-profile lookup and delegation, nonpromotion of virtual field results and POI1/gain separation. This tests **the execution seam**, not completed live FC/FD Audio V9 / Physics DSP. The existing candidate 20 Memory Fabric, Audio V9 Multipath and Physics providers must be resident and separately qualified before real end-to-end reconstruction.

One existing POI1/TP7 stage-1 experiment used Python reference analysis and produced noisy listening variants. Its numbers are retained as **REFERENCE_ONLY**, not evidence that the production model has run. Do not count any Python-matched or modelled virtual feed as an independent physical microphone.

The current branch addition is source and tests only; do not claim stage 2 real-audio improvement, unique 3D source localisation or completion of dual-mic clock mapping.
