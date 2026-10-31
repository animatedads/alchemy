# SPASH challenger — raw visual motion and PTS clock v0.1

Architect: Tom Dyer. Frame-rate discrepancy identified by Claude. ooRexx implementation: ChatGPT GPT-6, 31 October 2026.

This is a clean-sheet, separate SPASH challenger component, not a change to Claude's audio engine. It processes original visual movement metadata using ooRexx 5.3.0 r13196, not Python audio DSP. It does not perform FFT, gain, filtering, or audio rendering.

## Running

Requires FD_DOOR_MICRO_RUN_V2 run receipt and the matching FD_DOOR_MICRO_SAMPLE_V2 samples TSV:

    export REXX_PATH="$PWD/src"
    sh run_tests.sh
    rexx tools/spash_raw_visual_index.rex /PRIVATE/TP8.samples.tsv /PRIVATE/TP8.run.tsv /PRIVATE/TP8.raw_1000ms.tsv 1000

SpashRawMotionClock.cls checks original source identity, timebase numerator/denominator, video PTS versus reported milliseconds, monotonic frame ordinals, count, run end timestamp and geometry epochs. Window queries use actual PTS overlap, not sample index times a guessed FPS. They preserve signed global X/Y displacement, left/right door residuals and absolute global/door travel per observed second.

Qualification: Native r13196 on synthetic 60/120ms irregular frames 24/24 assertions PASS; six deliberately corrupted source/run variants fail closed. Actual uploaded TP8: 90,726 observations into 6,350 one-second PTS-accurate windows, 22 seconds locally; peak RSS approximately 340 MiB (in-memory indexed prototype). The original raw TSV stays untouched.

No private original movement rows, clip/audio payloads, or recording digests are uploaded to GitHub. The derived output is a local private file, not yet a Storage Fabric committed object. This prototype does not claim Strategy Layer search, 10-MU execution or audio/video clock alignment.

See docs/RAW_VISUAL_PTS_CORRECTION.md and HANDOVER.md.
