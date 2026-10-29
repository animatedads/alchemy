# NoSQLServer 0.90 — WAL-aware, coherent SQLite read/write

## Authority and selection

```
application -> NoSQLServerSQL (parser, predicate, execution, results)
            -> SQLiteWritableDatabaseEngine (selected backend)
                -> SQLite backup snapshot -> existing ooRexx native page reader
                -> prepared SQLite write bridge (BEGIN IMMEDIATE + COMMIT)
            -> SQLite 3 file, rollback-journal or WAL mode
```

The existing native `.SQLiteDatabaseEngine` remains its original read-only,
file-format parser and is **not** WAL-safe against an active external writer.
The writable engine is explicitly selected and uses SQLite's `sqlite3_backup`
API before the NoSQLServer SQL statement, yielding a consistent full database
image (including WAL frames) that is read with the original ooRexx parser.
The application SQL is never passed to SQLite as a raw executable query.

NoSQLServer SQL operations update data through previously approved NoSQL
schema/selection and typed prepared SQLite mutation instructions. The writer
uses an SQLite write transaction, synchronous FULL and foreign_keys ON.

## v0.90 changes over v0.89

- Supports reading and writing existing WAL-mode databases; no forced WAL
  checkpoint, no direct inspection of uncheckpointed WAL files.
- Reads one stable SQLite backup snapshot for each SQL `execute`; direct
  `SQLiteWritableDatabaseEngine~selectWhere` also starts a fresh snapshot.
- Keeps the same snapshot through suboperations of a single SQL statement;
  refreshed versions are used for subsequent statements.
- On committed mutations, refreshes the snapshot immediately. If that refresh
  fails, the result continues to report **committed**, with a warning; callers
  must never retry as though the write had rolled back.
- Snapshot files are created with `mkstemp` (0600), deleted on replacement or
  normal interpreter cleanup, and can only be removed by this process's tracked
  bridge method. Native SQLite is used for the backup, not SQL evaluation.

## Runtime usage

```rexx
::requires "NoSQLServerSQLiteWritable.cls"
engine = .SQLiteWritableDatabaseEngine~new("/private/existing.sqlite")
sql = .NoSQLServerSQL~new(engine)
rs = sql~execute("SELECT id,body FROM notes ORDER BY id")
rs = sql~execute("INSERT INTO notes (id,body) VALUES (2,'created')")
rs = sql~execute("UPDATE notes SET body='changed' WHERE id=2")
rs = sql~execute("DELETE FROM notes WHERE id=2")
```

Creating a new database requires explicit `.SQLiteWritableDatabaseEngine~create(path)`;
it fails if the target file already exists. Enable WAL using any normal SQLite
administration tool if desired; the engine does not silently migrate a file's
journal mode.

## Qualified evidence on 2026-10-22

- Supplied ooRexx 5.3.0 r13196 `ubuntu1604debug.x86_64.deb` extracted
  without host installation; C++17 bridge compiled with its headers.
- NoSQLServer v0.89 insert/update/delete/DDL atomicity and lossless BLOB/INT64
  regressions, plus v0.74 SQLite and GeoPackage and v0.60 SQL regression.
- An independent external SQLite connection commits paired-row changes
  repeatedly in WAL mode while NoSQLServer selects and performs writes/DDL.
  Uncheckpointed WAL is kept active; 55 SQL snapshots and 14 direct engine
  snapshots were asserted coherent, with independent integrity checks.
- Alchemy Objects v0.8 adoption, DB2 isolation, INTEGER precision and bulk
  materialisation v0.86 targeted regressions passed.
- Instrumentation Mesh tests v0.87/v0.88 were **not** run successfully in this
  isolated debug environment: the optional `InstrumentationMesh.cls` package
  was absent. This is not a regression verdict.

## Explicit limits and remaining work

1. **Selection/update races:** a mutation's selected rows are read from a
   consistent snapshot, but `BEGIN IMMEDIATE` is acquired only when the
   mutation batch is applied. Per-row original-value guards detect stale
   selected rows; concurrent phantom rows inserted between selection and
   write lock are **not** fully serialized. This is **not** serializable
   cross-process predicate mutation. Use a single writer or external
   scheduling/lease policy when predicate-wide serializability is required.
2. **Backup cost:** each query copies the full database to an owner-only
   temporary file. Cost and free-space demand scale with database size. This
   mechanism prioritizes correctness over performance; large databases need a
   direct SQLite-backed cursor/row projection, not a per-query backup.
3. **Crash cleanup:** a killed process may leave a 0600 temporary snapshot
   under `TMPDIR` (or `/tmp`). Use a private, quota-controlled local TMPDIR and
   a site-managed retention cleanup policy; treat snapshots as sensitive data.
4. **SQL/transaction scope:** INSERT/UPDATE/DELETE and DDL are atomic per SQL
   statement. Multi-statement BEGIN/COMMIT/ROLLBACK, savepoints, general JOIN
   support for this engine and full WAL reader replacement are **not** claimed.
5. **Schema limits:** unsupported `WITHOUT ROWID` tables, virtual tables, PK-less
   UPDATE/DELETE and unsupported SQLite extension types still fail closed.
6. **Thread/process scope:** do not share a single ooRexx engine instance across
   concurrent threads without an external instance lock. Multiple processes
   can read and perform nonconflicting SQLite writes through WAL, but this does
   not imply distributed Storage Fabric/MI/MU shared-file authority.
7. **Operational qualification:** no crash-injection, disk-full, high-contention
   soak, native ABI portability or production deployment acceptance is claimed.

Build using `make -C native OOREXX_PREFIX=/path/to/extracted/usr/local`.
Run `tools/run_sqlite_rw_v090.sh` with `OOREXX_ROOT`, `ALCHEMY_ROOT` and
`CRYPTO_ROOT` set to the respective extracted package roots.
