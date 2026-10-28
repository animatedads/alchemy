# Alchemy NotNotes startup patch and high-performance provider handoff

Owned code remains with notnotes-core. Patch from exact Library dev17 source, no new database, no service installation.
Fix 1: replace quadratic document sorting in MiniNotesApp~sortByKey with native string-key sort and stable buckets.
Fix 2: pass freshly restored object to restoreDocumentState instead of O(n) search for each record; old method call stays supported.

Native r13196 test on Project Alchemy 954-document NotNotes v0.7 corpus copy:
Original app init 27.11s; CLI init 11.37s; semantic 50-row query timed out.
Patched app init 18.13s; whole sort 0.231s; 50-row page 0.027s; CLI init 0.094s. STARTUP_FAST_PASS docs=954.
Subphase old restoration 14.01s to new 0.37s. File NoSQL selectAll remains ~9.5-11.3s and object recreation ~6.7s.
Individual inherited test lines PASS through last batch-persistence test; no clean final full-suite exit observed (outer execution interrupted).

NEXT: library-backed high-performance SQL already exists: packages/oorexx_rexxsql_backend_v0.1, Mark Hessling Rexx/SQL 2.6B3 with four Alchemy patches. It implements NativeDatabaseBackend SQLITE with SQLite indexes and prepared binds.
On Semantic Source Store (NOT NotNotes), measured 87.4s NoSQLServer full-scanning suite vs 0.4s Rexx/SQL; GA 15/17 source files in 1547s vs 17/17 in 3s.
NotNotes MiniNotesPersistence still uses FileDatabaseEngine. NoSQLServer v0.90/v0.91 writable SQLite copies a full backup snapshot per query; do not call that high-throughput SQL.
An explicit NotNotes persistence adapter must select an accepted indexed native SQL backend using existing selector/contracts and preserve forms, references, revisions, approvals, transactions, signed evidence, native fallback, restart, migration and rollback.
Rexx/SQL limitations: BLOB writes unsupported, empty bound strings map to NULL, process-wide current connection, threading not qualified, eager result variables.

FAST CRYPTO: oorexx_crypto_v0.8.3 via Runtime Reference v0.4 and Foreign Runtime v0.22.2/libcrypto, provider foreign.openssl.crypto, with native ooRexx fallback. Verify actual provider evidence.
Do not remove required signatures. Do not redundantly sign all data on read/reload; preserve verification at authorised trust, commit, generation and revocation boundaries.
Neither Rexx/SQL nor accelerated Crypto is wired into NotNotes by this patch; both integrations remain NOT_QUALIFIED.

Apply patch only to exact original SHA256 files in evidence/SOURCE_LOCK.json, on disposable working copy, never live host. Full native suite and independent review remain required.
No secrets or production data in this patch package. Update existing NotNotes/Native DB/Crypto spheres after owner adoption.
