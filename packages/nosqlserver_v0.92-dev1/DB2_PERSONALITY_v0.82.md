# NoSQLServer v0.82 — DB2 named constraints and explicit index DDL

v0.82 deepens the DB2 personality without pretending that NoSQLServer's
single-column adaptive index is a full Db2 index implementation.

## Added

- durable DB2 personality metadata in `db2-personality.yaml`;
- user-declared `CONSTRAINT` names preserved for supported primary-key,
  unique and single-column foreign-key semantics;
- those declared names projected through `SYSCAT.TABCONST`,
  `SYSCAT.KEYCOLUSE`, `SYSCAT.REFERENCES`, `SYSCAT.INDEXES` and
  `SYSCAT.INDEXCOLUSE`;
- `CREATE INDEX name ON table(column)` for one ordinary column;
- `DROP INDEX name`;
- explicit index names survive a fresh personality object and replace the
  synthetic adaptive-index name in DB2 catalog projection.

Constraint semantics remain authoritative in the existing NoSQLServer table
model. The sidecar stores DB2 identity/projection metadata; it is not a second
constraint engine.

## Honest boundaries

The current NoSQLServer derived-index implementation is single-column and does
not enforce uniqueness. Therefore v0.82 deliberately rejects:

- `CREATE UNIQUE INDEX`;
- multi-column `CREATE INDEX`.

Those statements fail as `SQLUNSUPPORTED`; they are not silently approximated.
The existing DB2 boundaries around `WITH UR`, identity generation and physical
cross-schema storage remain unchanged.
