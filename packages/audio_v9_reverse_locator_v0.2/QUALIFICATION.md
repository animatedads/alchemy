# Audio V9 Reverse Locator v0.2 qualification

Qualification was performed against the exact user-supplied V9 source/evidence files and the historical 671-file snippet inventory.

## Provenance reconstruction

PASS:

- 671 unique surviving snippet event IDs;
- 89 mono and 582 stereo files from the historical inventory;
- V9 classification JSONL contains exactly the same 671 unique IDs;
- classification append order separates into 71 + 300 + 300 batches matching the historical snippet creation cohorts;
- surviving V9 event JSONL contains 801 continuous event IDs `evt_000000`..`evt_000800` in monotonically increasing start-time order;
- after treating the first 371 historical IDs as already classified, 528 current events remain pending;
- sorting those 528 by `z_rms` descending and applying V9 `max_ai_events=300` reproduces all 300 `gen3_current801` IDs exactly, with zero mismatch.

## Production admission

PASS synthetic admission regression:

- canonical originals are accepted only beneath `camera_fc/` and `camera_fd/`;
- single-feed snippets must be mono beneath `single_feed/`;
- dual-feed snippets must be stereo beneath `dual_feed/`;
- noncanonical original Ogg basenames fail closed;
- source index schema records source feed, size and nanosecond mtime so stale indexes can be rejected;
- CSR offsets/posting geometry is checked fail-closed before use.

The ed209i driver additionally requires the real production totals: 671 snippets, 89 mono, 582 stereo and 120 canonical originals.

## Degraded-pattern recovery

PASS synthetic end-to-end landmark regression:

- two canonical Ogg sources are created under FC and FD with different file-start wall clocks;
- a same-wall-clock 10-second query is taken from each source at different per-file offsets;
- both query channels are subjected to +32 dB-equivalent nonlinear clipping;
- source audio is indexed through the same memory-mapped ffmpeg/direct-CSR production path;
- the best joint candidate recovers the correct FC and FD source filenames;
- each recovered source offset is within 0.25 seconds of truth;
- implied FC/FD absolute wall-clock agreement is within 0.25 seconds.

Additional PASS regression:

- construct a v0.1-style SQLite `sources` + `postings` database with no hash index;
- convert it to v0.2 CSR using sequential table scans only;
- query the salvaged index with a +32 dB-equivalent clipped snippet;
- recover the correct original and offset;
- retain source-identity validation.

Final marker:

```text
PASS ALL V9 REVERSE LOCATOR TESTS
```

## Separation from Audio Rexx Search

An attempted packaging pass deliberately triggered Audio Rexx Search's existing fail-closed invariant `FAIL: Python file found in Rexx-native pack`. That invariant was preserved. The locator is therefore shipped only as this standalone companion artifact; Audio Rexx Search v0.12-dev12 remains unchanged as the pure ooRexx/native executable head.

No production ed209i acoustic index or 671-snippet location table is claimed from the ChatGPT sandbox because ed209i SSH credentials/helper access are not mounted here.

## v0.1 production observation motivating v0.2

The live ed209i v0.1 run reached 120/120 decoded/fingerprinted originals and approximately 17 million inserted landmarks, then remained CPU/disk-active for roughly 40 minutes in the SQLite hash-index build with no failure. v0.2 specifically removes that global B-tree phase. This qualification does not claim the remote v0.1 run completed or produced `locations.tsv`; only the user-reported live state is recorded.
