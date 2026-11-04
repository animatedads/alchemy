# SPASH 3D acoustic reconstruction — two observed microphones, virtual field, camera-timed vehicle paths (v0.2)

**Architecture:** Tom Dyer. **This scoped integration contract and initial falsifiable two-mic model:** ChatGPT GPT-6, 30 October 2026.

## Corrected operating architecture

This builds on the existing **location/scene model** and the programme's established audio/vision/physics techniques. The 463 fully human-reviewed Tier A speech-positive clips are *temporal keypoints* within the privately supplied derived V7 recording, **not 463 different speaker locations**. The private keypoint staging plan has 349 fitting intervals, 86 withheld validation intervals and 28 embargo intervals to avoid boundary leakage. Private indexes, individual timestamps, audio, video and source hashes are not checked into Git.

For each speech keypoint:

1. Recover original independently recorded FC and FD feed windows, not only V7's derived stereo listening product. Pin exact source hashes, post-decode sample positions, channel source identifiers and an explicitly qualified FC/FD clock mapping. V7 CH1/CH2 are useful derived observations but are **not** automatically two independent microphones.
2. Load the known 3D **location model** including the two observed microphone poses, walls, static reflectors, possible source positions, and coordinate-frame transforms with uncertainties. If unavailable, geometry remains `UNKNOWN`; no silent invented metre measurements.
3. Measure a *single candidate coherent acoustic path* against both feeds. The signed observed TDOA is `t_B - t_A` with declared sign and error bounds. Compare with the predicted path difference `1000*(distance(S,B)-distance(S,A))/c` milliseconds for each 3D source candidate `S`; verify `abs(observed TDOA) <= 1000*distance(A,B)/c + tolerance`. This direct-path formula does not by itself identify which observed energy is direct vs reflected.
4. Treat two-mic TDOA as a **hyperboloid of possible 3D positions**, not unique triangulation. Use known scene constraints, different temporal speech keypoints, reflected-path curves and independent video-/vehicle-informed hypotheses to rank *competing* explanations. Multi-path inference is contingent on measured coherent acoustic evidence.
5. Place four or more **virtual microphones at candidate positions in the 3D model**, predicting relative arrival time, spectral transfer and motion/reflector effects. Virtual mic outputs are predictions derived from the scene, not extra recordings or corroborating observed channels.
6. Use *camera footage for motion timing*: frame timestamps, approved camera↔audio clock transform, direction/trajectory, visible vehicle body/location and uncertainty can condition which moving-reflector hypothesis is worth testing. Camera motion context alone contributes **zero new acoustic path admission**; measured path timing/spectral coherence must first support the reflection. Do not automatically equate camera clock with Ogg/V7 play time.
7. **Automatic levelling:** Audio V9's `AudioV9WhisperGainTracker` learns faint-speech reference from non-transient/non-vehicle windows only. A vehicle pass, loud event or impulsive probe holds the gain reference; it is not evidence that the source became loud. Dynamic spectral filtering/fusion are governed by V9's existing providers, with source-relative spectral features and conservative per-path weighting.
8. Keep at least three candidate physical paths separate: **direct speech**, **static reflection** and **moving vehicle reflection**. Also permit an independent continuous background/noise track. Reconstruct from source-native material for listening, but never use a modelled or amplified waveform as an unaltered observation. Avoid automatic deletion/hard muting of uncertain voice-like material.
9. Compare FC-only, FD-only, equal fusion, path-specific reconstruction and physics-conditioned reconstruction on *identical* withheld keypoints; retain source references, original audio, model variants, observed–predicted residuals and negative tests for every candidate. The final result may remain `UNRESOLVED`.

## Initial executable bounded experiment

- **New:** `src/SpashDualMic3D.cls` plus `tests/test_dual_mic_3d.rex`; native ooRexx 5.3.0 r13196 synthetic run: **17/17 PASS**.
- Accepts two caller-supplied `SpashPoint` microphone positions, speed of sound, candidate 3D source and optional **observed** TDOA/uncertainty. Returns an explicit result `UNTESTED`, `DELAY_COMPATIBLE_NOT_LOCALIZED`, `DELAY_INCOMPATIBLE`, `OUTSIDE_TWO_MIC_PHYSICAL_BOUND` or `AUDIO_NOT_ADMITTED`.
- The virtual microphone helper delegates to `SpashSpatialExperiment` and retains `MODEL_ONLY` on each output.
- Video frame time and clock-model ID remain context only, and cannot change an acoustically unadmitted path to an admitted one.
- `processingPlan` specifies speech-preserving filters and V9-owned gain policy; it **does not run an audio DSP filter** or claim recovered speech.
- Synthetic geometry in tests must not be misrepresented as the actual location model.

## Programme implementation seams

| Owner | Responsibility |
|---|---|
| SPASH | 463 speech-positive source-timed candidate keypoints, likeness/continuation, 3D hypothesis tests, source/measurement evidence partition |
| Audio V9 dev16 | Exact original-feed audio geometry, multi-feed alignment constraints, direct/static/transient reflection audio admission, whisper gain, dynamic filter and reconstruction |
| Physics World | Coordinate-frame scene, direct/reflected 3D propagation, moving vehicle/reflector simulation, predicted virtual observations |
| Camera/vision lane | Observed vehicle pass timing, direction, video frame/camera clock evidence and uncertainty |
| Media Methodologies | Shared method identity/foundation, tested measured path tracking, physics compatibility, virtual-mic reconstruction qualification |

The next real-data gate is *mapping the derived V7 keypoint timeline back to exact original FC/FD sample intervals and observed clock model*, and supplying the already authored 3D location model/camera vehicle tracks as explicit references. Without that gate, no physical 3D location or reduction of the 463 speech intervals is claimed.

## Privacy and qualification

Only code, synthetic fixtures and aggregate results belong in GitHub. Original microphone captures, source hashes, V7 clip library, private keypoint indexes, camera images and any full utterance text remain in private workspaces. The new ooRexx model is a **bounded first increment**, not a completed Audio V9 or Physics World production integration. Independent QA on the exact GitHub branch is still required before merge.
