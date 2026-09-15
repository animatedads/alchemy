# Provenance

## User-supplied production facts

The user staged on ed209i:

- `~/fcpaphos_project_v9_snippets/`: 671 files, 529 MiB;
- split by actual WAV channel count into `single_feed/` (89 mono) and `dual_feed/` (582 stereo);
- `~/fcpaphos_originals/20231009_20231010/`: 120 canonical originals, 3.998 GiB;
- FC originals under `camera_fc/` and FD originals under `camera_fd/`;
- all original basenames match `YYYYMMDD_HHMMSS_tpNNNNN_original.ogg` and exclude duplicate-prefixed / numeric-timestamp variants.

## V9 executable behaviour recovered from supplied source

V9 scans forward in wall-clock time, merges adjacent event candidates, assigns `evt_%06d`, appends the event, and increments the event number. Its snippet writer starts at `event.start - 2 seconds` by default and writes at most 10 seconds, one channel for one active camera or stereo for two active cameras. Classification is resumable: existing classification IDs are skipped, pending events are sorted by `z_rms` descending, and `max_ai_events` defaults to 300.

## Generation reconstruction

The supplied snippet inventory has 671 unique event basenames. Historical mtimes form three creation cohorts: 71 at 03:51-03:52, 300 at 04:22-04:26 and 300 at 09:55-09:59. The supplied classification JSONL contains exactly those same 671 IDs, uniquely, in the same 71 + 300 + 300 append-block structure.

The surviving event JSONL contains 801 events numbered continuously `evt_000000` through `evt_000800`, with monotonically increasing event starts. The first 371 historical snippet IDs overlap 273 current event IDs; after those existing IDs are removed, 528 current events remain pending. Sorting those pending events by `z_rms` descending and selecting 300 reproduces the final 300 snippet IDs exactly. Therefore the final generation is bound to the surviving 801-event metadata; the first 371 belong to earlier event metadata that was overwritten and must be acoustically relocated.

`reference/V9_SNIPPET_GENERATIONS.tsv` seals that conclusion. `reference/V9_GEN3_EVENTS.jsonl` and the scene manifest preserve the metadata seeds. Acoustic results remain the verification evidence.

## Sealed evidence hashes

See `reference/V9_GENERATION_PROOF.json` for machine-readable values. At v0.2 sealing (historical evidence unchanged from v0.1):

- snippet inventory SHA-256: `6aa350f9c50735b205b2c1f02c9b7ef3b2df1f47b1c8e1a6d7c33c5e730d7f33`
- V9 classifications SHA-256: `13ec772baed0b41b7cff091e094e11c875e1e308f51292ccb961f2868b97bf1b`
- surviving 801-event JSONL SHA-256: `7e971fd2b3d076b863fbd09748fc03530f7f24726978335dc657adedbbedb5e2`
- scene manifest SHA-256: `25b005c6bdfc161a026104c7292f1d6feb9d88547ab26d5731ff1c53712a8311`
- supplied V9 source SHA-256: `407565f8a298702e8da5603db93dda53386c12387dfc5cb9cdfc3407728c9dc2`
- derived 671-row generation map SHA-256: `f11d627882d4d51df6c7154dd410a39b2c21b41a139d315cdaa5794e767f0e03`

## v0.2 production-index correction

The first ed209i v0.1 production run admitted all 671 snippets and 120 originals, decoded/fingerprinted every original, inserted about 17 million postings, and then spent the dominant runtime in SQLite `CREATE INDEX postings_hash`. That phase was an implementation cost, not acoustic matching. v0.2 removes the B-tree design: because the packed landmark hash space is fixed at 18 bits (262,144 values), it uses a direct CSR-style inverted index with one offset table and packed source/frame arrays.

For continuity with an already-populated v0.1 database, `convert-sqlite` / `--salvage-v1` reads the committed `postings` table sequentially in two passes and constructs CSR without re-decoding/refingerprinting the 120 originals.
