# SPASH SLAM v0.1-dev1

**Spectral Path Association and Spatial Hypotheses**

Architecture and naming: Tom Dyer. Code, tests, documentation: ChatGPT GPT-6, 2026-10-30.

Standalone experimental ooRexx module for the SLAM collective. It ingests already extracted time-frequency blocks, groups them by measured likeness, builds candidate temporal continuations, separates overlapping but independent paths, and prepares exact source-sample/frequency-band partial-replay plans. It does not decode, process or synthesize waveform audio.

## Run

With Open Object Rexx 5.3.0 r13196 on PATH, change into this package directory and run:

    sh ./run_tests.sh

Locally exercised on extracted user-supplied r13196 Debian interpreter: 40 positive assertions PASS; nine intentionally invalid cases rejected with ooRexx Error 88. No ffmpeg, rxmath, JCL, external audio or service deployment needed.

## API

- SpashObservation: exact source/sample/window/band/method identifier; normalized spectral vector; optional pitch and spatial-hypothesis label; energy and shared algorithm foundation metadata.
- SpashObservation~likeness: symmetric bounded likeness using normalized-bin L1/2 (50%), frequency (25%), bandwidth (10%) and pitch when present (15%). Missing pitch removes its weight; incompatible spectral-vector lengths are INCOMPARABLE.
- SpashGraph~add / ~build / ~familyOf / ~edges: snapshot-dependent LIKE identity families plus CONTINUATION_CANDIDATE edges. An edge requires same source and method, non-overlapping time, bounded gap, and sufficient likeness.
- SpashGraph~bestPath / ~partition: find a weighted continuation and independent disjoint candidate paths.
- SpashGraph~replayPlan: exact source-referenced start sample, count, sample rate, frequency band, method and authority label. This is a plan only, NOT audio recovery.
- SpashPoint and SpashSpatialExperiment~predict: model-only propagation arrival times for four virtual microphone positions (or other numbers of positions).

The fixture has two overlapping acoustic tracks of 3 and 2 spectral blocks. No named sounds are used. Input reversal yields the same family and chosen strongest path. A different captured feed or processing method does not automatically join an existing path. Four microphones in a synthetic geometry yield predicted offsets of 0, 100, 200 and 300 ms.

## Evidential policy

Observation identity is not real-world emitter identity. A LIKE family is a threshold-connected component, may exhibit transitive chaining, and is not an independently verified source. Caller-supplied source and method IDs must be pinned to external hashes and configuration provenance. Shared method foundations are not independent corroboration. Predicted virtual microphone arrivals cannot manufacture recorded channels. Cross-feed clock alignment, source count, event classification, speech, geometric localisation, physical confidence and forensic truth are NOT claimed.

## Limits and next slice

No DSP decoder/FFT or V9 input adapter yet. Pure memory, all-pairs similarity and naive path selection are designed for small test fixtures; numeric thresholds are uncalibrated. A later slice should use Audio V9 measured boxes/tracks with exact bin geometry and source hash, verify distributed chunk continuation, preserve ranked alternatives and create a governed partial renderer. Audio V9, Media Methodologies, Physics World, SLAM, Body SLAM and the King Kong Bundy JCL project are unchanged.

See spheres/spash_slam_gopher_sphere_v0.1.

## Query by example (experimental addition)

To ask SPASH for audio passages similar to a WAV specimen, run the measured WAV reference adapter:

    python3 tools/spash_find_similar.py example_8k_mono.wav candidate1_8k_mono.wav candidate2_8k_mono.wav --segment-seconds 0.96 --min-score 0.80

Requires Python 3 and NumPy. Inputs are **8000 Hz, mono, uncompressed 16-bit PCM WAV**, already converted explicitly; no hidden resampling. Each match returns both query and candidate subsecond ranges, source SHA-256, method, tested time scaling, tested coarse log-band frequency shift and algorithm-only likeness. It selects short active templates rather than comparing only whole recordings. Same-recording self-overlaps are excluded. It neither transcribes speech nor infers room geometry or real-world source identity.

    python3 tests/test_wav_query.py

The synthetic WAV test checks a modified-gain excerpt inserted five seconds later into another recording, rejects uncorrelated noise at the chosen threshold, and validates provenance. The supplied private WAV and any fingerprint derived from it are intentionally **not committed**.

The native class `SpashExampleSearch.cls` separately offers `find(queryObservations, candidateObservations, maxResults)` for already-extracted SPASH observation trajectories, matching across different recording IDs when sample rate and processing-method foundation are compatible. It returns ranked interval candidates and rejects unaligned, incompatible methods. Its 15 native checks run in `sh run_tests.sh`. The Python WAV reference score and native block-trajectory score are separate experimental methods, **not** one calibrated probability. A production integration requires a verified bridge and shared feature contract.
