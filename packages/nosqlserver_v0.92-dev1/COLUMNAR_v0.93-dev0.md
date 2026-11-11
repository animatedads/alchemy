# NoSQLServer columnar layer — v0.93-dev0 candidate

## Purpose

NoSQLServer maintains one logical SQL relation. The physical layout is a choice:
row-major, column-major, or later mixed groups. Existing backend engines remain
responsible for persistence, query authority, and transactional publication.
This is a source-only prototype, not a production cutover.

The new public module `NoSQLServerColumnar.cls` provides:

* `NoSQLColumnarTable` — a virtual table exposing the existing `definition`,
  `readRows` and `rowCount` contract; `project`, `selectProject` and `readColumns`
  access only named columns.
* `NoSQLColumnarEngine` — a selectable top-level engine. It offers ordinary
  `table`, `selectWhere`, `selectAll`, `execute` and `query`, plus a selective
  `selectColumnar` path used by the SQL executor when the projection and predicate
  are safe to push down. Complex SQL falls back to existing row execution.
* `NoSQLColumnarCodec` — null-aware octet-preserving scalar column segments,
  with an initial run-length encoding option. There is **no claim** of optimal
  compression; dictionary/bitpacking and codec negotiation are future work.
* `NoSQLColumnarSQLPort` — uses the injected backend's `execute`/`table` methods,
  creates independent immutable column/generation tables, and atomically publishes
  a single current-generation manifest row. Backend must support compatible DDL,
  indexed INTEGER primary-key lookup, SELECT, INSERT and UPDATE. It explicitly
  cannot support arbitrary read-only backends for physical writes.
* `NoSQLColumnarMemoryPort` — deterministic, fault-injectable qualification port;
  **not persistent**.

## Storage shape

For logical table `observations` and generation 1, the relational port uses:

* `CSM_OBSERVATIONS` as the manifest row (`id=1`, `generation`, `row_count`,
  `block_size`), published after all segments are durable.
* `CSC_12_OBSERVATIONS_1_11_TEMPERATURE` (name includes table and column lengths)
  as one immutable chunk table with indexed `chunk_id` and encoded `payload`.

The source row table is retained during shadow promotion. This preserves
recovery/fallback and is not a space-saving destructive conversion yet.

## Query execution

The optional `NoSQLServerSQL` pushdown hook is inserted after predicate
normalization in the ordinary single-relation SELECT path. Only uncomplicated
identifier projections, simple comparison/NULL/logical predicates, and simple
ORDER BY identifiers take this path. `SELECT *`, joins, unsupported expressions,
and indexed primary-key equality on a backing row engine take the legacy path.
The fast path scans filter columns first, then reads only output and sort columns
and materializes the qualifying rows. The existing SQL engine performs its own
final order/projection. The access-path evidence is `COLUMNAR_PROJECT_LATE`.

## Generation and correctness

1. Read source rows from a pinned/revision-verified source where possible.
2. Write immutable column chunks to a new generation.
3. Validate the source revision before activation.
4. Publish the new manifest with a single conditional backend statement.
5. Readers pin that generation for all columns in one query.

A failed pre-publication conversion leaves the prior manifest intact. Orphan
unpublished chunks require a subsequent reader-safe garbage collector. Strong
concurrent writer/re-reader guarantees need a backend-provided snapshot token;
source `generation` alone is insufficient for external SQLite writers.

When row mutations pass through `NoSQLColumnarEngine`, its view is invalidated.
A write performed directly to the backing engine outside the wrapper must be
caught through the revision contract or columnar optimisation must be disabled.
Do not route mutable production datasets through this prototype until that
back-end-specific snapshot qualification is complete.

## Deliberate limits

* No direct columnar INSERT/UPDATE/DELETE yet: all DML targets row authority and
  invalidates the columnar read acceleration, requiring repromotion.
* No destructive physical swap or auto-promotion based on telemetry yet.
* No GEOMETRY object encoding unless a binary codec is registered.
* No vectorised SUM/AVG/COUNT pushdown yet, only filtered projection; SQL
  aggregation still uses the existing engine.
* No portable BLOB byte semantics beyond the present core string contract.
* SQLPort's atomicity, file naming, and backend-specific transaction behavior
  must be verified for each writable backend before enabling that port.
* SQLPort stage retry and orphan garbage collection are not implemented.
* Integer parsing and aggregation precision remain subject to the existing
  NoSQLServer typed-column rules; no automatic floating conversion is added.

## Acceptance gate

Compile with ooRexx 5.3 r13196 and run
`tests/v093_columnar_smoke.rex` against the **real** NoSQLServer classes.
Exercise identical SQL against row and column layouts, with independent
oracles, selected storage backends, failure injection, snapshot concurrency,
WAL/recovery, and SQL torture regression tests before qualifying release v0.93.

Local isolated qualification on the supplied r13196 debug build currently
passes codec, projection, NULL/binary, RLE, failure-before-publish, versioning
and fast-path tests using lightweight dependency stand-ins. This **does not**
qualify the real NoSQLServer stack or the SQLPort implementation.