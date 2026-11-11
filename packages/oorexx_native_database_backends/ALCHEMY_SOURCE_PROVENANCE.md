# Alchemy source provenance: `oorexx_native_database_backends`

- Source delivery: `oorexx_native_database_backends_v0.3.1.zip`
- Delivery SHA-256: `bb2eea71b6ce4c4d9d8604876df1146a12e5baeeec741c91d7091ba3596d213f`
- Delivery file timestamp: 2026-10-07T21:20:07+01:00
- Published text/source files: 26
- Embedded dependency files omitted: 0
- Generated/machine-specific files omitted: 0


## v0.3.2 Git development increment

The v0.3.1 delivery above remains the immutable parent provenance. v0.3.2 is a Git
development increment layered on that parent; it is not claimed byte-identical to the
v0.3.1 ZIP.

Added/changed source authority in v0.3.2:

- canonical `src/DatabaseBackendSelector.cls`;
- canonical `src/PostgreSQLDatabaseProvider.cls`;
- provider package-isolation regression and collision fixtures;
- `run_tests.sh` includes the selector regression;
- `integration.json` publishes v0.3.2 and targets current Git Foreign Runtime v0.22.6.

The historical `packages/oorexx_native_database_backends_v0.1` selector work is retained
as development ancestry only. The canonical v0.3.2 package is the source submitted to
Autobuild. No v0.3.2 qualification is claimed until a receipt records the exact submitted
tree and test result.
