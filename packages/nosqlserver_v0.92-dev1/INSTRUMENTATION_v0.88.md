# NoSQLServer v0.88 — query execution instrumentation

NoSQLServer continues to expose observation through the semantic
`instrumentation.mesh/0.1` contract.  The package does not pin itself to an
Instrumentation Mesh development archive: the current architecture catalogue may
advance from dev2 to dev3 without changing this database contract.

The observer remains optional and evidence-only.  It cannot grant query,
mutation, transaction, storage, publication or recovery authority.

## New execution evidence

v0.88 adds database-engine work evidence to the existing query/materialisation/
JSON timings:

- `database.query.rows_returned` — result rows for the most recent observed query;
- `database.query.rows_scanned` — rows examined by the engine;
- `database.query.last_rows_scanned` — ordinary current gauge for operator views;
- `database.query.scan_amplification` — rows scanned / max(rows returned, 1);
- `database.query.affected_rows` — affected rows where the result surface exposes it;
- `database.query.last_access_path` — engine access-path state.

`database.query.duration_seconds` now carries a bounded `operation` dimension
(`SELECT`, `INSERT`, `CREATE`, etc.) and every NoSQLServer metric carries
`instrumentation_api=instrumentation.mesh/0.1`.

No SQL statement text, parameter values, row contents, credentials or storage
paths are emitted.  The existing `sql_bytes` observation remains a byte count,
not query content.

These metrics complement, rather than replace:

- `database.result.materialise_seconds`;
- `database.result.json_seconds`;
- result row/field shape;
- materialisation and JSON cache-hit counters.

The purpose is to separate engine work from object materialisation and
serialization.  A high `rows_scanned` / `scan_amplification` value points to the
query/access path; low execution work with high materialisation or JSON time
points to a later database boundary.
