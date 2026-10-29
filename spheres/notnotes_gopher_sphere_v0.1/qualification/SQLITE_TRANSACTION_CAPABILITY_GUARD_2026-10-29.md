# NotNotes dev18 SQLite transaction capability — fail-closed guard

Date: 29 October 2026
Owner boundary: NotNotes application persistence (NOT Claude's Rexx/SQL native provider)
Status: SOURCE CANDIDATE; product/production acceptance NOT_GRANTED
Branch: `chatgpt/notnotes-transaction-capability-guard-20261029`
Parent: dependent draft application PR #69, itself based on draft SQL product-default PR #66.

## Source finding and correction

`MiniNotesPersistence~saveFrom(app)` inherited an optional transaction branch:
`transactional = db~hasMethod("beginTransaction")`. When the selected SQLite
backend was missing `beginTransaction`, the method could continue into
`DROP TABLE formats`, `DROP TABLE reports`, and further metadata DDL without
an atomic rollback boundary. Separately, `saveDocumentOnly` checked only for
`beginTransaction`, indexed SELECT, and DELETE, but not the matching
`commitTransaction` and `rollbackTransaction` capabilities.

The application now rejects `rexxsql-sqlite` full snapshots unless BEGIN,
COMMIT, and ROLLBACK methods are all available, before any table mutation.
Single-document SQLite writes likewise require the complete transaction API
before BEGIN or a document lookup. Legacy FileDatabaseEngine compatibility is
unchanged. The native SQL executor and Crypto provider have NOT been modified.

Regression candidate:
`packages/notnotes_mini_approval_app_v0.1-dev18/tests/test_sqlite_transaction_capability_guard.rex`.
It models a partial adapter that has BEGIN, per-key SELECT and DELETE but
**does not implement COMMIT or ROLLBACK**; both save entry points must reject
without performing BEGIN, DDL, or SELECT. The test must be run from the package
root with the documented `REXX_PATH`, on exact accepted source, using:
`rexx tests/test_sqlite_transaction_capability_guard.rex`.
It is not yet wired into the aggregate `run_tests.sh`; this is a known
qualification gap, not a claim of full suite acceptance.

## Executed local qualification, with limits

User-supplied ooRexx 5.3.0 r13196 extracted into an isolated directory.
The available Library NotNotes v0.1-dev17, dated 9 October, was adapted in
an isolated disposable working copy to **replicate the new dev18
transaction preconditions only**. A regression probe rejected both partial
adapter cases BEFORE any attempted SQL:
`NOTNOTES_SQLITE_TRANSACTION_GUARD_SUBSET_PASS checks=2`, process exit 0.

This test is **source-equivalent, not an exact dev18/PR #69 checkout**. The
local dev17 copy has only the dev18 guard preconditions, not its complete
SQLite delta persistence method. The exact Git regression exists as source
and requires an independent run in a clean checkout with the accepted dev18
dependency closure. A mock backend does not demonstrate physical rollback,
journal durability, concurrent sessions, or a real `librexxsql.so` call.

## Release gates retained

- Real library SQLite `rexxsql-sqlite` with Claude's patched 0005 provider;
  NULL/empty/BLOB, WAL crash/restart, 954- and 10k-document timing.
- No table mutation without a successful atomic transaction; rollback on
  injected failure; unchanged persisted approval/referral/temporal/relationship
  content after restart.
- End-to-end saved forms, intentions, dynamic reports, PDF, migration.
- Required Crypto signature and revocation policy through the existing
  accelerated `foreign.openssl.crypto`/Foreign Runtime path. Never skip required
  signing, and do not count an approval's `"SIGN"` action as a cryptographic signature.
- Full exact dev18 suite, independent peer test, upstream provider owner receipt,
  managed source acceptance, and separate installation qualification.

No live service was changed. No source was merged to main.

## Test-harness correction and negative control

The first local mock used `::method init; expose db` in a subclass of
`MiniNotesPersistence`. This was **not valid proof** because ooRexx keeps
instance-variable scope by declaring class: superclass methods saw an
uninitialised DB variable rather than the injected backend. That initial
green result is withdrawn.

The corrected test uses `.MiniNotesPersistence~define(... .Method~new(...))`
to inject a fake backend in **the production class's own scope**, without
modifying a production source file on disk. It also checks the explicit
failure message; an unrelated missing-method exception cannot pass.
Actual local source-equivalent r13196 executions:
- With the two capability checks inserted: `checks=2`, exit 0.
- Against the original unguarded October Library source: deliberately failed
  on the attempted DDL (`DDL must never be reached`), exit 1. The old
  baseline has no delta method, so this negative control proves the
  **full-save guard discrimination only**.

The new Git test source includes the corrected injection and message checks.
**Exact dev18 branch retest and aggregate suite remain NOT_RUN**.


## 29 October continued implementation: required source provider and default selector

The NotNotes dev18 draft now obtains SQLite through the **existing generic** `DatabaseBackendSelector` with provider `REXXSQL-SQLITE` and `RexxSqlDatabaseProvider.cls`, instead of calling `RexxSqlSqliteSession~open` directly. It requires indexed lookup, TRANSACTIONS, ROLLBACK, WAL, BIND_PLACMARKERS and BYTE_EXACT_TEXT before using the returned session. This is a composition contract, not a second driver.

**Detected source-version blocker:** when this stacked child PR was checked, its ancestor tree still held an older selector (Git blob `878df82b40eb727172f2daacae9d2a58e2a4c3a5`) and did not yet contain `RexxSqlDatabaseProvider.cls`. Git main contained the upstream owner source at exact blobs: selector `96eb8f187b902fd034196f11aa76cc0e61795805`, provider `6239b80747c25192f307611d3ac87bb89056058e`, RexxSqlBackend `693f0dfc65e5b8e38252a48183d28fa70df480ca`. Do not import duplicate copies into NotNotes. Until those existing upstream paths are reconciled in the final source checkout, launch scripts and opt-in native SQL test reject with `NOTNOTES_PROVIDER_NOT_READY`. Legacy `MININOTES_DB_BACKEND=file` remains explicit and independent.

**Executed isolated local native evidence this continuation:** extracted user-supplied ooRexx r13196 Debian locally; `rexxc` accepted the constructor excerpt (exit 0). The same constructor excerpt executed against a fake shared selector: accepted a compatible test session (`MOCKED_SELECTOR_SESSION_PASS`, exit 0) and rejected an explicit provider-error object before session use (ooRexx error `93.900`, exit 163). This was a **source-equivalent constructor excerpt, not a complete dev18 clean-checkout test**. No native `librexxsql.so` or real SQL data was used. The Git test fixture `tests/fixtures/DatabaseBackendSelector.cls` additionally checks the six required capabilities, but an exact Git-source run is still outstanding.

**Runner fixes actually committed:** the transaction-capability guard now executes early in `run_tests.sh` and the source-qualification runner; the latter selects historical file mode explicitly. The native SQL integration runner refuses a checkout lacking the new provider/selector contract. All are development-branch source commits only.

**Release blocker unchanged:** real shared provider integration and patched native Rexx/SQL, exact 954/10k corpus, SQLite/legacy differential tests, atomic save/restart, Time Service/ConnectSelector, and actual Crypto sign/verify authority remain unqualified. No live estate change or main merge.
