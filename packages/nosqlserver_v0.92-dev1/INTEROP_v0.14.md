# NoSQLServer v0.14 interoperability surface

This release implements the additive shared-database abstraction requested for the native NoSQLServer backend while preserving the existing file-engine API, planner diagnostics, SQL parse/unsupported distinction, adaptive indexes/join maps, and authoritative storage rules.

The public compatibility surfaces are exercised by `tests/v014_interop_transaction_smoke.rex`. They include shared `.Error` and `.DatabaseOperationType` names, `db~transaction`, atomic staged commit, deferred queries, savepoints, prepared statements and batches, typed values, metadata adapters, direct `db~execute`/`db~query`, and version capabilities.

## Transaction publication model

A transaction takes a stable sibling copy of the database directory. SQL is queued and remains invisible. On commit, the queue is executed against the staged copy. If any operation fails, the stage is discarded and the live database is unchanged. Before publication the engine verifies that the live catalogue/table generation signature still matches the transaction's base snapshot; a conflict is refused rather than overwriting newer live state. The final staged database is published by retiring the old root and moving the staged root into its place.

The final publication registry is shared among engine objects in one ooRexx process. Cross-process distributed locking is not claimed by v0.14.

## Status semantics

- Queued operation / deferred query: `NOTEXECUTED`.
- Explicit rollback before commit: transaction result `NOTEXECUTED`; deferred queries remain empty and `NOTEXECUTED`.
- Successful commit: `COMMITTED`.
- Commit that began staged execution but failed and discarded all staged changes: `ROLLEDBACK` with `TRANSACTIONFAILED`.
- Double commit/rollback or otherwise invalid transaction state: `NOTEXECUTED` + `INVALIDSTATE`.

## Prepared values

`DatabaseValue` provides explicit NULL, BOOLEAN, INTEGER, DECIMAL, VARCHAR, DATE, DATETIME, BLOB, and UNKNOWN representations. Prepared parameters are kept as objects in the queued transaction operation and bound only during staged execution. Placeholder count and numeric/boolean shape are validated before execution; text is SQL-quoted by the binder rather than concatenated raw.
