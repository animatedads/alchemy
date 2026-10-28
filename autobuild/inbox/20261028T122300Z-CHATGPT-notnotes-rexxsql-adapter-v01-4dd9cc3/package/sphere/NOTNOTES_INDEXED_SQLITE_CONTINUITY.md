# NotNotes indexed SQLite continuity — candidate report

- Intention-driven NotNotes product must be indexed SQLite by default for **new** databases, via existing `RexxSqlSqliteSession` and NativeDatabaseBackend provider, not file-scan `FileDatabaseEngine`.
- Existing legacy stores must fail closed on default and require user-approved backup/migrate/reconcile with rollback; never auto-overwrite.
- NoSQLServer v0.90/.91 snapshot-per-statement SQLite is not the same high-throughput indexed backend.
- Startup app traversal fixed separately by prior two-fix Autobuild candidate `e04714a2` — avoid duplicate patches.
- Native independent fake-executor SQL contract passes; actual compiled backend and 954/10k runs remain UNQUALIFIED.
- Keep high-performance shared Crypto/Foreign Runtime signing and signature verification at the appropriate authority boundary, not on every read. Do not bypass required checks.
- Accepted source hashes, signed closure, real SQL output and migration gates must be supplied before changing NotNotes product default in production.
