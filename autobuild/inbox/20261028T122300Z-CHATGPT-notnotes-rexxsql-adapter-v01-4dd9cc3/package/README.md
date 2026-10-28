# Mini NotNotes high-performance SQLite integration adapter v0.1-dev1 — CANDIDATE

Architecture: Tom Dyer. Adapter probe: CHATGPT, 28 October 2026.

**Existing authorities only:** NotNotes owns forms, intentions, document semantics and report exports; NoSQLServer owns the legacy database, Mark Hessling's patched Rexx/SQL `packages/oorexx_rexxsql_backend_v0.1` provides the compiled native indexed SQLite access through `RexxSqlSqliteSession`. This candidate only adapts that session to the five persistence operations that MiniNotesPersistence currently uses. It is not another SQLite driver or security authority.

## Source closure and version guard

- Evaluated against **Library** Mini NotNotes v0.1-dev17 archive SHA256 `0b074b97081ea8c7759eab069f759e4c1a98bd471f537c5d1d3590b183a23312`, created October 9. This does **not** establish compatibility with later GitHub `packages/notnotes_mini_approval_app_v0.1-dev17` or acceptance of either as the installed product.
- ooRexx 5.3.0 r13196, user-provided debug .deb SHA256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`.
- No `librexxsql.so` available in this execution environment: **a real live SQLite round trip has not been performed.** The adapter's SQL/selection contract was exercised with a fake `RexxSqlSqliteSession`-shaped executor under native ooRexx; do not promote to production.
- This is complementary to separate startup candidate **`e04714a2a1c16ee132c78dd7081462234281f30b`** (two O(n²) fixes), not a competing modification of startup sorting.

## Files

- `src/MiniNotesIndexedSqliteEngine.cls`: `MiniNotesDatabaseSelector` and thin `MiniNotesIndexedSqliteEngine` facade (`createTable`, `dropTable`, `table`, `insert`, `updateWhereEquals`, `selectAll`, `selectWindow`, `beginSave`, `finishSave`, `rollbackSave`); no sqlite3 API, dynamic linker or query engine reimplementation.
- `patches/select_rexxsql_default.patch`: candidate change to MiniNotesPersistence that selects the indexed Rexx/SQL engine by **default**. `file-legacy` is explicit compatibility only, no fallback. The product release must not use this patch until the actual library and full migration gates pass.
- `tests/test_adapter_contract.rex`: native ooRexx contract test against a fake executor, **not** a native-driver or real SQLite test.
- `tests/test_default_denial.rex`: fail-closed test; when accepted Rexx/SQL provider is absent, startup must fail, never create a file-engine database.
- `docs/QUALIFICATION.md`: exact tested and missing gates.

## Native test setup

```sh
export REXX_HOME=/path/to/extracted/deb/usr/local
export MININOTES_APP_ROOT=/path/to/notnotes_mini_approval_app_v0.1-dev17
bash tests/run.sh
```

All database-dependent logic uses the existing `RexxSqlSqliteSession` contract. The real composition root must explicitly load the accepted `RexxSqlBackend.cls` and linked patched `librexxsql.so` before calling `MiniNotesPersistence`. Presence and ABI are checked at the boundary. If unavailable, startup fails closed with a diagnostic.

## Important limitations (not release-ready)

1. `MiniNotesPersistence~saveFrom` still executes format/report/relationship drops and writes without wrapping the entire operation in one `BEGIN IMMEDIATE`/`COMMIT`. The adapter exposes transaction methods, but the application owner must integrate an abort-safe atomic boundary *before any production writes*.
2. Rexx/SQL TEXT binds turn empty strings into SQL NULL: the adapter uses `COALESCE(?, '')` on current **non-nullable** NotNotes schema. Actual NULL values are rejected, not collapsed; new nullable columns need an explicitly qualified data contract. No BLOB write support claimed.
3. Rexx/SQL has a process-wide current connection and is not qualified for multi-thread use. Use a controlled per-process session and no mid-transaction switching.
4. The existing `loadInto` still loads all document rows; `selectWindow` is available for owner integration but **startup is not yet indexed/paged**. 954-doc and >=10k corpus benchmarks remain pending.
5. No migration, backup/restore, byte-exact CRLF, approval/temporal evidence, PDF/ODT/XLSX or restart differential test on real SQLite was completed. Do not open legacy `database.yaml` as SQLite.
6. This adapter does not sign or bypass signing. Shared Crypto v0.8.3 / Runtime Reference / Foreign Runtime acceleration is a separate dependency used where required by the security contract; no repeated signing on ordinary reads is added here.

Owner: `notnotes-core` for application integration; existing Rexx/SQL backend owner for database-provider bugs; Programme Coordinator for tracking, not release acceptance.
