# NoSQLServer v0.92-dev1 — native SQLite integer primary-key B-tree seek

This source package is a side-by-side copy of the repository's v0.91 package with an opt-in-free *read-path only* optimisation for `SQLiteDatabaseEngine` and `SQLiteWritableDatabaseEngine`. No SQL evaluator is delegated to a third party.

## Change
- The ooRexx SQLite binary reader now exposes `rowByRowid(table, integer)`, descending interior SQLite table B-tree pages to fetch a single leaf cell, including negative signed 64-bit rowids and BLOB-bearing rows.
- The existing NoSQLServer `SQLComparisonPredicate` `=` on an actual `INTEGER PRIMARY KEY` rowid alias uses this seek; the candidate row is **still evaluated using NoSQLServer's predicate**.
- Non-integer literals, unqualified columns, other operators, WITHOUT ROWID tables, text or composite keys and range queries retain existing scan/error behaviour. Incompatible and out-of-range literals do not trigger this seek.
- Table row counts are lazy in SQLite metadata discovery; `tableRowCount` obtains and caches an exact count only on request. WITHOUT ROWID remains unsupported by the page reader.
- Access-path evidence is `SQLITE_NATIVE_ROWID_SEEK`, with zero or one candidate row scanned. Version identity now reports `0.92-dev1` instead of stale `0.90`.

## Qualification (2026-10-29)
Executed on the supplied ooRexx 5.3.0 r13196 debug runtime with Alchemy Objects v0.8 and Crypto v0.8.3:
- `tools/run_sqlite_rw_v092.sh`: PASS. This includes historical v0.89 atomic DML, v0.74 native SQLite/GeoPackage (updated indexed-path assertion), v0.60 SQL regression, v0.90 concurrent WAL, and v0.91 phantom-row guard tests.
- v0.92 fixture: 10,002 rows in 512-byte SQLite pages; probes signed 64-bit minimum, -1, first and deep positive keys, missing rowids, BLOB, NoSQL SQL projection and predicate filtering, direct + writable engines, and independent `PRAGMA integrity_check`.

## Scope and limits
- This reduces integer-PK lookup work inside an existing immutable SQLite image; v0.91 writable statements **still create a full-database sqlite3_backup snapshot**. End-to-end statement throughput therefore remains limited by database size.
- Generic indexes, non-integer PKs, joins, order-by pushdown, and native cursor/streaming results are not addressed.
- Existing Mark Hessling Rexx/SQL backend is a separate, faster SQLite execution implementation. Its Semantic Source Store benchmark and BLOB-write restrictions remain independent; this patch does not switch SQL authority to Rexx/SQL.
- No production multi-process, forced-crash, distributed MI/MU, or large-scale performance certification is claimed. No deployment or autobuilder execution.
