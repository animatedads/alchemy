# NoSQLServer v0.84 — authoritative runtime capability evidence

v0.84 makes plain `SELECT DISTINCT` an explicit runtime capability rather than
leaving consumers to infer support from parser/executor behaviour.

The authoritative surfaces are:

- `db~version~supports("DISTINCT")`;
- `NoSQLDatabaseCoreAdapter~supports(.NoSQLDatabaseCoreCapability~DISTINCT)`;
- `NoSQLDatabaseRuntimeEvidenceProjection~lines`, which emits the downstream
  runtime-evidence statement `DATABASE CAPABILITY_DISTINCT TRUE` only when the
  active Database Core adapter advertises that capability.

`tools/nosqlserver_runtime_evidence.rex` prints that projection for environment
qualification.  The v0.84 smoke constructs duplicate-bearing data and proves
that `SELECT DISTINCT` reduces five input rows to the three distinct projected
values before accepting the capability advertisement.

`COUNT(DISTINCT ...)` remains separately advertised as `COUNT_DISTINCT`.
