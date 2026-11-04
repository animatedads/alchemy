# SPASH Challenger — bounded raw PTS visual context v0.2

Architecture: Tom Dyer. Implementation: ChatGPT GPT-6, 31 October 2026. Scope: independent visual evidence stream for the SPASH acoustic competition, **not** Claude's separate audio DSP line.

## Contract

1. Ingest the original `FD_DOOR_MICRO_SAMPLE_V2` and matching `FD_DOOR_MICRO_RUN_V2` TSVs. The sample index is not a substitute for presentation time, and neither the video frame rate nor the acoustic feature cadence is assumed constant.
2. Use each recorded integer `pts` and the run's positive `time_base_num / time_base_den` to derive milliseconds. Keep `time_ms` as a checked projection (tolerance 1.01 ms), not as a clock alignment with audio.
3. Stream each successive signed global displacement, signed door residual and corresponding magnitudes as an observation over its actual PTS interval. Split proportionally at exact 250/500/1000/2000-ms boundaries. At all times hold only four accumulator states, not the full source.
4. A raw interval crossing a geometry epoch, having unstable endpoint geometry, or exceeding 250 ms between observations contributes no *valid* displacement. The view retains its invalid time span and maximum gap. A trailing partial window is emitted and marked `PARTIAL_COVERAGE`. Only stable, fully covered windows are eligible for visual stratum selection.
5. Every window records `audio_clock_authority=NOT_ALIGNED`. Never assign audio-source identity, voice, bang, or synchronous correspondence from visual PTS alone; do not treat the 149 grouped TP8 mechanical events as primary motion evidence.
6. Stage output as `.INCOMPLETE`. Validate the complete run count and final PTS before promoting the resulting view. A failed late input check cannot promote a partial view; an existing view is temporarily backed up during promotion.

The derived view uses schema `spash.visual.raw-window/0.2` and records the source filename, width, PTS-relative boundary, raw steps, covered and valid geometry milliseconds, epoch, geometry status, per-second signed/unsigned motion, peak door step, maximum raw gap, clock authority and validity status.

## Native execution

From the `raw_context` directory, with ooRexx 5.3.0 r13196 installed:

```sh
REXX_BIN=rexx sh run_tests.sh
REXX_PATH="$PWD/src" rexx tools/spash_raw_visual_stream.rex /private/TP8.samples.tsv /private/TP8.run.tsv /private/derived/TP8.multiscale.windows.tsv
```

The second command is **not** claimed executed against the private original in this runtime. It requires the source/run TSVs on the execution host. The filename above is illustrative.

## Actual qualification and limitations

- Native irregular-PTS fixture: 35 samples, 23 windows (including trailing partial), validator PASS. Failure cases BAD_PTS, BAD_SOURCE and BAD_ORDER correctly rejected and did not produce final view files.
- Native test-only Storage Fabric API stub: correct original-ref linkage and explicitly `CATALOGUE_ONLY_NOT_DURABLE` metadata. This is not a live durable checkpoint or replica qualification.
- Synthetic TP8-sized throughput: 90,726 raw rows, 47,634 250/500/1000/2000-ms windows, 14.42 CPU seconds, 19,556 KiB peak resident set size, under the provided ooRexx 5.3.0 r13196 debug interpreter. The synthetic test has contrived motion and cannot support assertions about real TP8 door movement.
- The 200 real Audio V9 feature-strategy trials remain separately documented in `SPASH_RIVAL_200_native_trials_20261031.txt`: 100 configurations on 923 FD TP7 rows and 100 on 765 FC TP28 rows. Experimental merit is not speech detection accuracy; neither dataset has independent siren/klaxon confound measurements. Do not mix them into video time until an independent audio/video clock fit exists.
- The `tests/StorageFabric.cls` stub is isolated to unit tests only. Production `REXX_PATH` must resolve the genuine `packages/oorexx_storage_fabric/src/StorageFabric.cls`, and an actual authenticated source `StorageRef`, digest, catalogue persistence, verified locations, and explicit save/checkpoint discipline must be implemented by the storage owner.
- Single-pass streaming is bounded by four windows, but the output TSV grows linearly with recording duration. Partition migration/resume is not yet wired. No cross-modal synchronisation, real-audio DSP, source separation, 3D position reconstruction, cluster dispatch or genuine Storage Fabric durable commit is claimed.

## Follow-on gates

Qualify this exact Git branch checkout under r13196; process original TP8 source privately; build an epoch-safe resumable cursor at source PTS boundaries; bind source and derived view to real Storage Fabric; independently estimate audio-video offset/drift/uncertainty before join; rerun the five-method Rival rankings with explicit track/trajectory continuity resets and measured negative confounds.

Files in this increment: `src/SpashRawVisualStream.cls`, `src/SpashRawVisualStrata.cls`, `src/SpashRawVisualStorage.cls`, `tools/spash_raw_visual_stream.rex`, fixture/tests and `run_tests.sh`.
