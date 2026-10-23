# NoSQLServer v0.90 compatibility review — NOT adopted yet

Library file: `nosqlserver_v0.90_sqlite_wal_read_write_candidate.zip` (2026-10-22). The upstream documentation reports WAL-aware coherent backup snapshots, statement-level atomicity, committed-write warnings, and external WAL concurrency probes. It explicitly does *not* claim multi-statement transactions or predicate-wide serializability.

Website Publisher v0.2 was developed against v0.89 and is a single-local-writer snapshot candidate. No implicit upgrade occurs here. Its stored editorial revision remains content identity, **not** authorization, approval, publication or a durable cross-mesh distributed transaction.

Before changing the native adapter dependency pin, run actual `native/test_native_store.rex` end-to-end with v0.90 plus negative stale-revision, concurrent-writer and crash-restart tests using supplied ooRexx 5.3.0 r13196. Review how v0.90 post-commit snapshot refresh warning is surfaced to the writer: do not blindly retry committed work. No database engine is bundled in this source package.
