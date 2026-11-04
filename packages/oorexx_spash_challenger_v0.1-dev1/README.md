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


## Rival's recovered native 100-strategy engine

The Library's previously staged Rival source is now committed in `rival/` on this same independent challenger branch. It uses **existing Audio V9 spectral-track measurements**, not Python DSP, to run five candidate method profiles, five frame continuity lengths and four thresholds = **100 experimental strategies**. Native tests pass. Real FD TP7 (923 track rows) and FC TP28 (765 rows) have each completed all 100 configurations locally. Both currently rank spectral stability methods highest, with selected source-referenced candidate intervals and no semantic sound label.

The strategy code includes original/derived Storage Fabric object and extended-attribute registration, ten MU placement **plans** (not dispatch), synthetic siren/klaxon veto mechanics, and recovered video-event context with `AUDIO_SYNC=UNKNOWN`. Three-band tracks cannot test for sirens or klaxons reliably: on actual tracks confound evidence remains **UNTESTED**, not falsely negative. The earlier raw TP8 PTS source and windowing code above remain authoritative for door movement; collected event summaries are secondary.

Detailed scope and exact local results are in `rival/README.md` and `HANDOVER.md`. Full layered Audio reconstruction, true programme Strategy Layer binding, durable Storage Fabric replication, clock calibration and distributed MU work are future integration gates, not completed capabilities.
