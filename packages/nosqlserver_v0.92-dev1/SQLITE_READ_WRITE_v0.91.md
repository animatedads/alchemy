# NoSQLServer v0.91 — single-table predicate concurrency guard

## Change

Previously NoSQLServer evaluated UPDATE/DELETE predicates against a stable
SQLite backup snapshot and applied selected row mutations under a later write
lock. Original-value guards detected changed selected rows, but an inserted
phantom matching the predicate could be missed.

The opt-in `SQLiteWritableDatabaseEngine` now passes the *exact* current
immutable snapshot and table name to a native `sqliteApplyBatchGuarded` bridge
for UPDATE/DELETE. After SQLite `BEGIN IMMEDIATE` succeeds and before any
mutation, the bridge opens the immutable read snapshot, compares the table's
CREATE TABLE schema and every row (rowid plus SQLite type-exact values)
against the locked live table. A mismatch causes a rollback. Empty mutation
batches perform the same validation. Only then are the NoSQL-approved prepared
statements applied atomically. This is intentionally conservative: an
unrelated change to that table can cause a retryable conflict.

## Contract

* NoSQLServer retains schema selection, predicates, authorization and SQL
  semantics. Native SQLite only validates logical equality and executes
  prepared DML inside SQLite transactions.
* This protects **single-table predicates that depend only on that table**
  from post-selection row/schema changes, including phantom insertions.
* It does **not** provide multi-statement transactions, multi-table join
  serializability, external-dependent predicate isolation, or distributed
  MI/MU shared-file transaction guarantees.
* The existing snapshot-per-statement approach still copies the whole
  database; table validation adds O(table size) scanning for UPDATE/DELETE.
  Neither is adequate for large concurrent production workloads.
* Conflict = full batch rollback, no partial commit. Successful commit is
  reported as committed even when refreshing the next snapshot fails.
* Native read-only SQLite/GeoPackage and other NoSQLServer backends are
  unaffected; the new guarded writer is explicitly selected.

## Qualification

Compiled against the supplied debug ooRexx 5.3.0 r13196 headers with
`-std=c++17 -Wall -Wextra`, linked to libsqlite3. The v0.89 atomicity,
BLOB/INT64, bootstrap, v0.74 native SQLite/GeoPackage, v0.60 SQL regression,
and v0.90 active WAL concurrent snapshot tests passed. v0.91 tests insert a
post-snapshot phantom, perform a zero-match guarded mutation and edit an
existing row, assert failure and no partial write, then refresh and apply
without conflict. Independent SQLite integrity_check passed.

The optional Instrumentation Mesh v0.87-v0.88 tests, large-scale contention,
disk-full and forced-crash tests are not certified by this change.
