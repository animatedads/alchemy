# NoSQLServer v0.87 — Instrumentation Mesh integration

NoSQLServer v0.87 consumes the transport-neutral `instrumentation.mesh/0.1`
observation contract through an optional adapter in
`src/NoSQLServerInstrumentation.cls`.

Instrumentation is observational only. It does not grant query, mutation,
transaction, storage, publication, or management authority.

The core `NoSQLServer.cls` has no hard dependency on Instrumentation Mesh.
`FileDatabaseEngine~instrumentation` is `.nil` by default. When an object with
`databaseEvent` is attached, the existing authoritative database operations
publish facts they already know.

## Metrics

Query execution:

- `database.query.accepted_total`
- `database.query.completed_total`
- `database.query.failed_total`
- `database.query.duration_seconds` (`DISTRIBUTION`)

Bulk result conversion:

- `database.result.last_rows`
- `database.result.last_fields`
- `database.result.materialisations_total`
- `database.result.rows_materialised_total`
- `database.result.values_materialised_total`
- `database.result.materialise_seconds` (`DISTRIBUTION`)
- `database.result.materialise_cache_hits_total`
- `database.result.json_serialisations_total`
- `database.result.json_bytes_total`
- `database.result.json_seconds` (`DISTRIBUTION`)
- `database.result.json_cache_hits_total`

Standard Instrumentation Mesh request and byte counters are also updated.

Dimensions carry `database_family=nosqlserver`, implementation, product,
release, and projection (`DIRECTORY` / `JSON`) rather than encoding those facts
into metric names.

## Bulk/cache rule

v0.87 retains v0.86's zero-copy `asArray` boundary and now caches deliberate
Directory and JSON projections. Repeating `asDirectories` or `asJson` does not
walk and serialize the same 1,400-row result again.

No instrumentation code performs an additional per-row counting pass. Result
shape is derived from the already-authoritative row count and relation width.

## Dependency

Qualified adapter dependency:

- `oorexx_instrumentation_mesh_v0.1-dev2.zip`
- SHA-256 `fc1c1bb61f91a8c6b3aec6dc94f6b12052fcaeab0c90aa2312f644f79b64d6b2`
- semantic API: `instrumentation.mesh/0.1`

A later compatible implementation of the same semantic API can replace dev2;
NoSQLServer does not depend on Queue Fabric or the mesh carrier.
