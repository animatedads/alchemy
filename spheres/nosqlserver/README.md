# NoSQLServer engineering sphere — documentation revision 0.3

**Do not conflate three distinct states:**

1. Complete source in GitHub main: `packages/nosqlserver_v0.79/`, with historical read-only native SQLite/GeoPackage.
2. Complete locally delivered **v0.91 development candidate**: `nosqlserver_v0.91_sqlite_guarded_read_write_candidate.zip` (SHA-256 `d4a276007029e66512611ea7e836ca7ab30209b80ac7d46ecf1fba61121f02d0`). It adds opt-in SQLite read/write, WAL coherent snapshot reads, and the v0.91 same-table predicate mutation conflict guard.
3. Merged GitHub PR #20: `autobuild/inbox/20261023T144200Z-CHATGPT-nosqlserver-v091-sync/` contains **patch intake, not the full v0.91 executable source tree**.

Start with `nosqlserver.start` and the new `nosqlserver.sqlite-writable-v091` article. The legacy SQLite page reader remains read-only and GeoPackage does not inherit mutation authority. The selected writable engine uses SQLite's native transactional writer below NoSQLServer's SQL semantics.

**No production certification:** per-query whole-database backups, O(table-size) validation for mutation, no multi-statement or multi-table serializable transaction guarantees, no distributed MI/MU lease semantics; Instrumentation Mesh and failure-injection gates remain open.

The sphere inherits shared ooRexx source-navigation services and retains the v0.79 provenance and the separately qualified Intention Service integration article. This is architecture/continuity documentation, not a replacement runtime package.

```sh
gopher --profile nosqlserver context nosqlserver --full
gopher --profile nosqlserver search sqlite --sphere nosqlserver
```

Historical package source and candidate qualification are named explicitly in each article. Full GitHub source reconciliation remains outstanding.
