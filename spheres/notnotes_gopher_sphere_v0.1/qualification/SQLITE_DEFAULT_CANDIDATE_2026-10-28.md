# NotNotes high-performance SQLite default — source candidate, 2026-10-28

**Scope:** Mini NotNotes core app; no duplicate SQL provider, new cryptographic authority or deployed service.

**Git source candidate:** [PR #66](https://github.com/animatedads/alchemy/pull/66), branch `fix/notnotes-default-rexxsql-sqlite-20261028`. The patch changes `packages/notnotes_mini_approval_app_v0.1-dev17` source **on a development branch**. It is **NOT** an accepted dev17 release, production migration, or demonstrated end-to-end SQLite qualification.

## Implemented

- `MiniNotesPersistence~init` defaults to `MININOTES_DB_BACKEND=rexxsql-sqlite`, consuming the existing `packages/oorexx_rexxsql_backend_v0.1/src/RexxSqlBackend.cls` + `NativeDatabaseBackend.cls`. Explicit `file` option still supports historic stores. Missing SQLite provider fails closed; a detected legacy `database.yaml` cannot be reinterpreted implicitly.
- `MiniNotesRexxSqlEngine.cls` implements the minimal NoSQL-style application persistence operations and transaction boundary over `RexxSqlSqliteSession`, preserving the domain-level `MiniNotesPersistence` boundary. No second SQL driver is present.
- SQLite restore, existing-document comparison, and mutation lookup use bounded 100-row rowid pages (SQLite cursor indexed); display sorting and restoration lookups no longer use quadratic scans.
- SQLite document/definition saves execute as one transaction, with failure rollback; metadata and temporal evidence reads now fail closed on SQL errors.
- New `tools/migrate_file_to_rexxsql.sh` snapshots the legacy store first, refuses source symlinks and existing targets, invokes `tools/migrate_file_to_rexxsql.rex` to copy six known tables (pre-temporal stores are supported), verifies every value and rejects unknown source tables/NULL ambiguity, and only then commits. A failed destination is not accepted; the original is never opened by the conversion Rexx process.
- Existing CLI launch scripts now resolve their *neighbouring* Rexx/SQL source provider, and inherited file-store tests select `MININOTES_DB_BACKEND=file` explicitly.
- Standalone tests: fake-provider native contract test, live adapter SQL transaction/byte round-trip test, real management-review fixture migration/reopen test. Real tests are retained as executable instructions, not falsely reported as PASS.

## Executed native evidence in this working session

- Binary: user-supplied `oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb` SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`, extracted without installing globally. Version output: ooRexx 5.3.0 r13196 (internal test), x86_64.
- `rexxc` native parser on `MiniNotesRexxSqlEngine.cls`: **PASS**.
- `rexx tests/test_rexxsql_adapter_mock.rex` against local unchanged fake SQL provider: **REXXSQL_ADAPTER_NATIVE_CONTRACT_PASS**. Verifies SQL construction, empty vs NULL literal and NUL bound value, ordered keyset query. This is *not* real SQLite, nor a pass for a native C extension.
- `rexxc` native parser on `tools/migrate_file_to_rexxsql.rex`: **PASS** including the latest catalogue/unknown-table guard, reconstructed from the exact candidate text and run under the same r13196 interpreter.
- An isolated native ooRexx test of the same 10,002-document key-bucket/sort algorithm (including duplicate keys) completed in 0.159989 s; the newly added harness against the actual MiniNotesApp method has not yet been run. Prior 954-document / 0.094 s CLI candidate evidence was measured on the older 9-Oct Library dev17, not on this branch; do not report new 954/10k benchmarks.

## Missing release gates

1. Build or supply the **existing** patched `librexxsql.so` (Rexx/SQL 2.6B3 + Alchemy patches), put it on `LD_LIBRARY_PATH` and execute `tests/test_rexxsql_adapter_live.rex` against native SQLite. Test NULL/empty, UTF-8/CRLF/NUL, WAL transaction rollback, reopen, target refusal.
2. Execute `tests/test_rexxsql_migration.sh` with the actual management-review fixture; independently verify all rows, temporal evidence, persisted reports and PDF/output semantics.
3. Full inherited `run_tests.sh` in explicit file mode and full r13196 SQLite mode, including complete process exit codes. Benchmark the same 954-document estate and >=10k documents; measure startup, 50/100-row queries and save throughput.
4. Verify actual signing contract first: current `vendor/notnotes/AlchemyNotNotes.cls` `::method approval` lines 169–173 translates `SIGN` to a Boolean `signed` approval attribute; `ApprovalSet~evaluate` stores this Boolean. That is **not a cryptographic signature**. Do not claim existing NotNotes approval rows are signed by OpenSSL. For any separately required cryptographic receipt/commit path, integrate and qualify shared Crypto v0.8.3 -> Runtime Reference v0.4 -> Foreign Runtime v0.22.2 `foreign.openssl.crypto`; preserve actual identity, tamper and revocation policy. This SQL patch neither adds nor bypasses cryptographic signing.
5. Reconcile source locks/dependencies, immutable next version of the package and sphere, and independent acceptance prior to merge/release/installation. Do not claim that changing current Git dev17 retrospectively modifies accepted Archive dev17.

**No live service, existing store, or production installation was changed.**
