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
