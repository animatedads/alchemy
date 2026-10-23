# NoSQLServer v0.81 — DB2 personality metadata and schema-qualified names

v0.81 extends the DB2 personality introduced in v0.80 without moving
product-specific behaviour into the neutral SQL executor.

## Added

- current-schema qualified object references, e.g. `APP.employee`, translated
  at the personality boundary while preserving quoted string contents;
- `SYSCAT.INDEXES`;
- `SYSCAT.INDEXCOLUSE`;
- `SYSCAT.TABCONST`;
- `SYSCAT.KEYCOLUSE`;
- `SYSCAT.REFERENCES`.

Primary-key, unique and foreign-key constraint names are stable synthetic
names (`PK_*`, `UQ_*`, `FK_*`) because the current neutral NoSQLServer schema
model preserves constraint semantics but does not persist SQL constraint
names. Constraint-backed indexes are projected into the DB2 catalog. Adaptive
physical single-column indexes are also projected when an index snapshot is
present.

## Deliberate boundaries

This remains a DB2 compatibility personality, not a claim that NoSQLServer is
IBM Db2. Unsupported DB2 identity generation and `WITH UR` semantics continue
to fail explicitly. Cross-schema storage is not invented: current-schema
qualification maps onto NoSQLServer's flat physical table namespace.
