# Alchemy Website Publisher v0.3

Independent side-by-side website editorial application, using the Rasenfalcon site as reference. This GitHub review update currently includes the **native ooRexx storage integration and acceptance harness**. The complete browser/editor source and Rasenfalcon reference assets are in the v0.3 distribution ZIP and have **not yet been imported into this branch**.

## NoSQLServer selected SQLite backend

Dependency: NoSQLServer `v0.90_sqlite_wal_read_write_candidate`, SHA-256 `08534dc11858863a6efa82e4689e07ceb420691c4a9ab7fab7da69819c8cf9da`.

The publisher calls `SQLiteWritableDatabaseEngine` through NoSQLServer. Candidate revisions are immutable, one native prepared INSERT per revision, never browser/direct SQLite writes. NoSQLServer v0.90 supplies coherent WAL-aware snapshots but **not** cross-statement transactions or predicate-wide serializable multi-writer updates. Use a confined, single-writer service. No institutional approval or publication capability is granted.

## Native CLI

```sh
rexx native/publisher_store.rex init /private/publisher.sqlite
rexx native/publisher_store.rex save /private/publisher.sqlite candidate.json 0
rexx native/publisher_store.rex load /private/publisher.sqlite saved-r1.json 1
rexx native/publisher_store.rex history /private/publisher.sqlite history.tsv
rexx native/publisher_store.rex verify /private/publisher.sqlite
```

The `verify` command checks the monotonic parent chain, not signatures or editorial veracity.

## Qualification

A clean-extraction run of the complete v0.3 distribution passed **46 browser assertions** and **36 native-handoff/source assertions**. We also extracted the ooRexx **5.3.0 r13196 debug runtime** and rebuilt the native NoSQLServer v0.90 SQLite writer using its headers. The native Publisher tests passed file creation, append, exact document-byte retrieval, reopen, parent-chain verification and WAL-mode append/reopen. Python `sqlite3` was used **only** as an independent test fixture and integrity oracle, not as an application server or storage engine.

```sh
OOREXX_ROOT=/path/to/extracted/usr/local \
ALCHEMY_ROOT=/path/to/alchemy_objects_v0.8 \
CRYPTO_ROOT=/path/to/oorexx_crypto_v0.8.3 \
./tests/qualify_native.sh
```

Native end-to-end results are development-host qualification only. **Not qualified:** high-contention, crash injection, production RexxOS deployment, long-running backup cost, distributed services or live publishing. No merge to main until the entire UI source/reference assets are reconciled.

## Security / scope

No PHP, Python HTTP server, credential material, content activation, institutional authority or public deployment. Temporary SQLite backup snapshots are confined under private `TMPDIR` and removed on normal completion. Preserve committed result/warning distinction: a post-commit snapshot-refresh warning is not evidence that a write rolled back.

The Publisher-owned source lives here; NoSQLServer v0.90 remains an independently pinned upstream dependency.
