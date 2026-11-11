# NoSQLServer columnar v0.93-dev1 — sparse segments and layout selection

Status: source-only draft PR #141; separate from v0.92-dev1 production semantics.

## Physical optimisation

A single logical TableDefinition/DatabaseRow SQL relation may have a row authority and an immutable columnar shadow. The top-level NoSQLColumnarEngine now allows explicit `setLayout(table, "ROW"|"COLUMN"|"AUTO")`. ROW returns the authoritative row relation; COLUMN requests the column projection when supported; AUTO keeps a conservative row fallback for indexed primary-key equality and projections touching >=75% of physical columns. The threshold is provisional and is not a cost model based on byte statistics, compression ratio or latency.

The new `NoSQLColumnarTable~readPositions(columns, ordinals, pinnedManifest)` resolves zero-based chunk offsets from stable 1-based row ordinals and caches decoded physical segments per requested column. `selectProject` filters on predicate columns first, then reads only segments intersecting accepted ordinals. Projection remains late and unrelated columns are never fetched. The `readCount` metric on the memory qualification port and `lastSegmentsRead` on the relation expose physical reads.

In a 128-row fixture with 16-row chunks and one matching row, filtering 8 station segments then retrieving only 1 temperature segment performs 9 physical segment reads, versus 16 for the dev0 projection scan. This is a deterministic segment-read count, **not** a runtime performance benchmark.

## Safety

- Invalid row ordinals and missing/mis-sized segments fail rather than silently returning corrupt values.
- Segment decode retains NULL and binary/octet strings, including embedded NUL.
- The memory port rejects stale generation publication attempts; a failed staged write leaves the previous published manifest visible.
- Row mutations invalidate the active columnar shadow. A source generation change detected on access returns to row authority.
- A requested ROW layout requires a row engine. COLUMN requires a published shadow; complex SQL still falls back through the established SQL path.
- SQLPort remains an unqualified provider candidate: atomicity, concurrent writers, orphan generation retry, external SQLite mutation visibility and crash recovery require real backend testing. The memory-port CAS proof does not establish SQLPort atomicity.

## Reproduction and acceptance

`rexxc src/NoSQLServerColumnar.cls` — compile with ooRexx r13196.

Isolated execution (only to validate columnar algorithms): from the package's `tests` directory, set `REXX_PATH=$PWD/standins` and run `rexx v093_columnar_segment_layout_smoke.rex`. **Never use stand-ins in deployment.** To test against the real NoSQLServer, use the normal class-path dependency closure without the stand-ins directory.

The package retains `tests/v093_columnar_smoke.rex` for real `NoSQLServerSQL` pushdown. Its directive is now placed after the script body, as ooRexx requires.

**Not yet complete:** real backend qualification, SQLPort end-to-end durability, timed row/column benchmarks, production aggregation pushdown, write-optimized hybrid groups, auto-migration/physical compaction, full SQL torture corpus, crash/WAL/concurrency and governance review. The draft PR must not be merged or deployed without these gates.
