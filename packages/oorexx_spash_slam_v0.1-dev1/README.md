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


## Continue: accurate query-by-example and exact partial replay (2026-10-30)

**Important correction:** the first GitHub-published WAV provider accidentally divided spectral L1 difference by frequency-band count as well as normalizing by spectral-vector sum. This inflated the likeness of unrelated recordings. Commit `94c4f842c3d71ce418e7375854db7e24ce0a218d` repairs the WAV matcher: its distance is the mean *over time* of the sum of absolute differences *over frequency* divided by 2. A defective-score comparison of private source versus unrelated noise yielded about 0.975; the correctly normalized comparison was about 0.454. The earlier published high score must not be used as qualification.

Local experiments against the 9.996-second private WAV (not committed) used an inserted 2-second passage at +4 seconds with altered gain and added low noise: best exact subinterval original **2.56–3.52 s**, modified **6.56–7.52 s**, heuristic likeness **0.967561**. Independent white-noise and sine-frequency-sweep controls produced zero matches at 0.80. Same-file searches excluded trivial self-overlap but showed seven *hypothesis-only* candidates. These are not seven physical sources or proven echoes.

The new `tools/spash_render_matches.py` converts a JSON search report into *only* its matched query/candidate PCM intervals (8 kHz mono PCM16); each clip retains source/clip SHA-256, exact original sample indices and a replay receipt. The command fails closed when the source changed or when outputs already exist. It does not separate sources or produce independent microphone evidence.

```sh
python3 tools/spash_find_similar.py example.wav corpus/*.wav --min-score 0.80 > spash_matches.json
python3 tools/spash_render_matches.py --result spash_matches.json --output-dir spash_listen
sh ./run_python_tests.sh
```

The `run_python_tests.sh` suite requires Python 3 and NumPy; the native graph `run_tests.sh` continues to require ooRexx r13196. Locally observed 40 original native graph + 15 native exemplar + 9 rejected-input + 5 WAV query + 8 replay tests passing. These figures qualify **the local deliverable**, not the published GitHub PR checkout; independent source qualification of the exact branch is still required. Autobuilder is off, and neither private source WAV nor its listening outputs are published.


## V7 whole-recording deliverable and Git publication boundary

The user's private V7 recording was surveyed across 8h39m and produced a 912-clip listening archive. User-reported reviewing of hour 4 has so far found verbals in every clip listened to, but no reviewed denominator or false-negative assessment is available; do NOT generalise 100% hit rate across the entire recording. The source, clips, private indexes and source digests remain outside GitHub.

Generic public source now includes:
- `tools/spash_review_feedback.py`: hash-bound user listening review receipts; no speaker/transcript/source identity assertion
- `tools/spash_v7_scan.py`: **new streaming 2-channel high-recall reference scanner**, producing candidate plans only; NOT asserted identical to the historical 912-clip generator
- `tools/spash_v7_validate.py`: offline ZIP/extracted-library integrity audit without uploading original audio
- `tests/test_review_feedback.py`, `tests/test_v7_scan.py`, `tests/test_v7_validate.py`: synthetic and adverse tests

See `docs/V7_CORPUS_METHOD.md` for the exact historical method description, distinctions between source and listening derivatives, and qualification limits. The Python regression runner includes the new tests. **Local dev3 ZIP tests are not automatically independent exact-checkout Git qualification.**
