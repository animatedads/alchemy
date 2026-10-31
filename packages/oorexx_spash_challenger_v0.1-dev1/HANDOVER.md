# SPASH Challenger: raw visual PTS handover

Date: 2026-10-31. Architecture: Tom Dyer. Claude identified the hidden source-frame timing discrepancy. ChatGPT GPT-6 implemented this independent ooRexx challenger increment. This is not a rewrite or takeover of Claude's audio work.

## Deliverables

- src/SpashRawMotionClock.cls: reads original FD_DOOR_MICRO_SAMPLE_V2 and run V2, uses 1/90000 video PTS as documented by the run, validates sample/clock/source identity, returns raw signed displacement, door residuals and irregular-PTS weighted time windows. Does not decode/audio process or infer source identity.
- tools/spash_raw_visual_index.rex: derives configurable raw-motion windows, PTS weighted, with explicit AUDIO_CLOCK_AUTHORITY=NOT_ALIGNED.
- tests synthetic irregular 60/120ms frame fixture: 24 positive checks; six fail-closed malformed source/run fixtures; run_tests.sh.
- docs/RAW_VISUAL_PTS_CORRECTION.md: timebase, frame-rate error and correction.
- private local output: 6,350 one-second windows from the actual uploaded TP8 samples; original uploaded 19MB source stays private.

## Measured original TP8 results

Original run: STEP=1, 90,748 decoded frames, 90,726 emitted raw movement rows, timebase 1/90000, last relative PTS 6,352,263ms. Across 90,725 emitted intervals mean gap 69.99948ms (14.28582Hz); near 60ms 74,880, near 120ms 15,038, other 807. Using frame ordinal x 60ms would make late events over 15 minutes early. Native ooRexx r13196 full run: 90,726 rows -> 6,350 one-second windows in 22 seconds / ~340MiB RSS. The 149 grouped events are hints, not source data.

## Programme boundaries

SPASH challenger is clean sheet; Claude owns separate audio recovery. Original visual observation identities should be registered as immutable Storage Fabric refs. Derived PTS windows are separate layers and must not replace original samples. Actual Storage Fabric binding and Strategy Layer portfolio are NOT implemented in v0.1. The independent source clock mapping to original FD/FC audio remains NOT_ALIGNED until measured, so no video-movement event may be declared synchronous with a speech segment or virtual microphone from file naming alone.

No audio DSP done in Python, ffmpeg or any other runtime here. Only ooRexx transforms visual metadata. Future acoustic processing belongs to the existing Audio V9, Layered Audio, Maths, Foreign Runtime and Physics World code.

## Next executable sequence

1. Change the in-memory raw loader into a bounded Storage Fabric cursor/resumable partition; keep PTS, sample ordinal, epoch and halo continuity; target each MU's own resource limits rather than assuming 10 MUs are collectively one memory pool.
2. Ingest full raw motion/run tables for TP7, TP9, TP10 and FC TP28-33. Never copy TP8's cadence or epoch to other videos.
3. Construct >=100 Strategy Layer combinations with PTS-based 250/500/1000/2000 ms windowing, alternative spectral/acoustic processing owners, and negative controls.
4. Prevent siren/klaxon false positive acoustic identities from eliminating coincident voice-like path evidence; preserve overlapping independent trajectories.
5. Fit FC/FD audio-video clocks with measured offsets, drift and uncertainty before any cross-modal alignment or four-position Physics World experiment.
6. Execute side-by-side held-out tests with the separate Claude workstream on original audio; use user-confirmed 463 Tier A V7 speech-positive clips as positive review evidence only, not measured recall.
7. Commit the exact checkout tests and update relevant SPASH and programme coordination lanes; no original recording, raw private sample rows, source hashes or intercepted audio in Git.

## Qualification scope

24 positive and six negative unit assertions under ooRexx 5.3.0 r13196, plus successful complete TP8 in-memory processing. These qualify raw **visual** timing, not a working 100-strategy audio competitor, real cross-modal sync or a 3D recovered voice. No merge to main is implied.


## Rival 100-strategy source recovery and real V9 execution (31 October, later increment)

Recovered the separately staged `SPASH_RIVAL_GIT_STAGING_20261031` Library source rather than reimplementing it. All seven files are now committed under `rival/` in this same branch: `src/SpashChallenger.cls`, `rival_scan.rex`, `run_tests.sh`, `tests/smoke.rex`, `tests/layers.rex`, `tests/stubs/StorageFabric.cls`, and its `README.md`.

The native ooRexx 5.3.0 r13196 unit suite passes; the local StorageFabric class stub is **test-only**. Actual production execution must load the genuine Storage Fabric classes, attach immutable original StorageRefs and qualify catalogue persistence; the current Rival code registers catalogue layers but does not checkpoint/replicate them.

Real source evidence: Audio V9 Candidate21's **already measured** FD TP7 923 spectral trajectories and FC TP28 765 spectral trajectories were scanned separately. On each, the native Rival executed **100 strategy combinations** (5 declared methods × 5 path-window lengths × 4 selection thresholds), using no Python waveform processing and no independent new FFT. The top strategies were FD `SPECTRAL_STABILITY:W32:G1` (merit 0.89128, 321 selected rows) and FC `SPECTRAL_STABILITY:W32:G0` (merit 0.88502, 456 selected rows). The reported merits are unsupervised ranking objectives, not speech-recovery accuracy. The output retained FD 2 and FC 1 selected acoustic trajectory intervals, conditional on path/spectral evidence; they are not confirmed speech.

The source TSV has **three spectral shape bands and no independent tone-persistence/sweep/two-tone measurements**. The siren/klaxon veto code is checked with synthetic confound features; on the real examples the status is `UNTESTED_CONFOUND`, not a claim that any klaxon/siren is absent or correctly classified. Overlapping possible speech must remain a distinct trajectory; do not hard-delete the underlying audio.

The older V7 362-event table was read as **video-only stratification with unknown audio clock**. The correct future input is full raw PTS movement windows from `SpashRawMotionClock.cls`, especially when dealing with door residuals; audio fusion must be gated by observed alignment. The local RivalRawVisualContext experimental adapter successfully read the complete 6,350 PTS windows and selected 20 door-motion strata, explicitly with `AUDIO_SYNC=UNMEASURED`, but its GitHub publication was blocked by tooling: **do not claim that additional adapter committed**. The core raw PTS source and 100-strategy engine are committed separately.

Ten MU strategy slots have been planned (10 configurations per slot) but **not** admitted or dispatched. No GPU, live noise-reduction rendering, native PCM optimisation, 3D source solve or independent Claude comparison has been claimed.

An aggregate local transcript of the real evaluations is available separately as `SPASH_RIVAL_200_native_trials_20261031.txt`; this private experiment artifact and source SHA values are not in Git. The Rival source's `run_tests.sh` runs synthetic tests; pass the native audio TSV and recovered video table to exercise the real-source path. Running the tests under the original repo's `rival/` folder requires `REXX_PATH` to resolve the true Storage Fabric module in production rather than the bundled test stub.
