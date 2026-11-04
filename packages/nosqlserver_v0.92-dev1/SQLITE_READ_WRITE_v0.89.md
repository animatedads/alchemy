# NoSQLServer 0.89 — explicitly selected SQLite read/write storage

**Development candidate** tested with the supplied ooRexx 5.3.0 r13196 Ubuntu x86_64 debug interpreter and SQLite 3.46.1.

## The authority boundary

```
Application -> NoSQLServerSQL (SQL parser, row selection, result contract)
            -> SQLiteWritableDatabaseEngine (storage provider, name & type checks)
                -> native SQLite reader for SELECT
                -> prepared mutation batch (libnosqlsqlitewriter.so, SQLite C API)
                    -> existing .sqlite file (transactional rollback journal)
```

The application never sends its original SQL directly to SQLite for execution. SQL parsing and predicate evaluation stay in NoSQLServer. The storage writer sees only NoSQLServer-generated quoted table/column names, typed bind descriptors, and row identity/original-value guards. The native writer does *not* expose SQLite SQL query results. The class `SQLiteNativeWriteBridge` is package-scoped, not a published application API. Native package code is trusted; this is not a sandbox for untrusted code that can load arbitrary extensions.

Selection is explicit; **the old `SQLiteDatabaseEngine` remains read-only**, and GeoPackage is unchanged.

```rexx
::requires "NoSQLServerSQLiteWritable.cls"

-- Existing SQLite database:
engine = .SQLiteWritableDatabaseEngine~new("/private/database.sqlite")

-- Or create a NEW SQLite database (fails if the path already exists):
engine = .SQLiteWritableDatabaseEngine~create("/private/new.sqlite")

sql = .NoSQLServerSQL~new(engine)
rs = sql~execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT NOT NULL)")
rs = sql~execute("INSERT INTO notes (id,body) VALUES (1,'saved')")
rs = sql~execute("UPDATE notes SET body='revised' WHERE id=1")
rs = sql~execute("SELECT id,body FROM notes WHERE id=1")
rs = sql~execute("DELETE FROM notes WHERE id=1")
```

## Supported in this development increment

- SQLite file provisioning with exclusive-create and file mode `0600` on Linux.
- Native NoSQL `SELECT`, NoSQL-driven `INSERT`, `UPDATE`, `DELETE`, `CREATE TABLE`, `DROP TABLE`.
- Multi-row inserts, updates, and deletes atomic *within one statement* using `BEGIN IMMEDIATE` and `COMMIT`, with SQLite FULL synchronous mode and foreign-key constraints enabled on the write connection.
- Duplicate-key and CHECK/foreign-key failures roll back the complete statement.
- Prepared parameter binding (TEXT, BLOB, INTEGER signed 64-bit, DECIMAL finite double, NULL); embedded NUL and quotes in BLOB/TEXT stay data.
- Identifiers are validated against existing NoSQL relation metadata and double-quoted; update/delete require a declared supported primary key.
- Every UPDATE/DELETE uses a guarded PK match **and** original row values, enforcing optimistic conflict detection; if any guarded row changes, all of that statement's mutations roll back.
- After successful mutation, invalidates NoSQLServer's native SQLite header/schema snapshot before the next query.
- Existing FILE/Object/JSON/GeoPackage backends remain separately selectable.

## Deliberate restrictions — not yet production qualification

- This is not a general SQLite VM/SQL passthrough, WAL participant, or SQLite wire server. WAL databases are rejected by the writer because NoSQLServer's existing native binary reader does not apply WAL pages. Existing SQLite read-only mode retains its previous limits.
- Native readers do not yet acquire SQLite shared locks or maintain one multi-relation SQLite snapshot. External concurrent writers can therefore race the native reader. The guarded update/delete write batch detects stale selected rows, **but not every possible phantom insertion** between selection and the write lock. **Do not use this candidate for externally concurrent databases.**
- Transactions are atomic per mutating statement; no cross-statement `BEGIN`/`COMMIT`/`ROLLBACK` or savepoints are advertised. The writer implements SQLite rollback on any step error.
- UPDATE/DELETE on tables without an explicit primary key and `WITHOUT ROWID` tables fail closed. DML access to views, virtual tables, and custom SQLite rowid arrangements is not claimed.
- SQLite affinity/precision differs from NoSQL types. INTEGER binds exact signed 64-bit; DECIMAL binds finite IEEE-754 double (not arbitrary-precision decimal). Native reader support for UTF-16, virtual tables, `WITHOUT ROWID`, WAL and complex schemas remains unchanged.
- `CREATE TABLE` is restricted to NoSQL types INTEGER/DECIMAL/VARCHAR/TEXT/BLOB/DATE/DATETIME. Table DDL through FederatedDatabaseEngine still routes by default to the FILE engine. The writable SQLite backend should be used directly for SQLite DDL.
- This component is local-file storage, **not multi-MU shared SQLite storage**. Storage Fabric + lease/checkpoint and migration must be governed separately; a `.sqlite` path is not a portable distributed authority.

## Build and test

Native build prerequisites: C++17 compiler, `sqlite3` headers/library, the ooRexx 5.3 header directory (from the supplied `.deb` or installed ooRexx).

```
make -C native OOREXX_PREFIX=/path/to/oorexx/usr/local
export LD_LIBRARY_PATH="$PWD/native:/path/to/oorexx/usr/local/lib:$LD_LIBRARY_PATH"
export REXX_PATH="$PWD/src:/path/to/alchemy_objects/src:/path/to/oorexx_crypto/src:/path/to/oorexx/usr/local/bin"
# On the test development VM:
python3 tests/create_v089_fixture.py
(cd tests && /path/to/oorexx/usr/local/bin/rexx v089_sqlite_rw_contract.rex)
```

Do not install the supplied debug `.deb` on an unapproved host just to test the package. The package works with an extracted tree. A native `.so` built on one distribution should be rebuilt for a deployment target rather than assumed ABI-portable.
