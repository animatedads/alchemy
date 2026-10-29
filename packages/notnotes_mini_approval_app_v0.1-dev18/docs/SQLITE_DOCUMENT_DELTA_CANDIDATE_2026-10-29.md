# NotNotes dev18: bounded native SQLite document writes (29 October 2026)

Status: **SOURCE CANDIDATE — not qualified for production**. Base: `918434cb740c2b3eedf7f235f46145e29628c3e4` (draft PR #66). This branch changes only `packages/notnotes_mini_approval_app_v0.1-dev18`, not the existing Claude-owned Rexx/SQL provider.

## Problem and solution

Prior `MiniNotesPersistence~saveFrom(app)` began a SQLite transaction but then dropped/recreated five metadata tables, scanned *all* SQLite documents using 100-row pages to construct an `existingKeys` map, and walked/encoded `app~allDocuments` for each write, even for one edited field. Bounded SELECT pages are not bounded total work.

Added `MiniNotesPersistence~saveDocumentOnly(app,document)` and `MiniNotesRexxSqlEngine~deleteWhereEquals`. A single document edit now uses:
1. `BEGIN IMMEDIATE TRANSACTION`;
2. `SELECT ... FROM documents WHERE doc_key = ?` (indexed primary key, at most one row);
3. only changed-column `UPDATE` or first `INSERT`, without touching unrelated documents;
4. `DELETE FROM temporal_evidence WHERE doc_key = ?` and reinsert evidence only for the changed document's live fields;
5. `COMMIT`, or request `ROLLBACK` on any source-level syntax/error condition.

Added `MiniNotesApp~temporalEvidenceForDocument` (enumerates one document's existing field names) and `~persistChangedDocument`. Seven standalone document mutations now use the document path: submit, decide, createFromCommand, setUserDocumentField, createUserDocument, addDocumentReference and removeDocumentReference. All definition/report/subview changes, nested batches, explicit `persistNow`, legacy file mode, and bulk saves retain the old full-snapshot mechanism. No SQL provider fork, no new data authority, no automatic migration, no production cutover.

**Important:** The existing NotNotes `approval(...,"SIGN")` Boolean is not a cryptographic signature. This patch adds no signer and makes no signed-commit claim; real `oorexx_crypto` / Foreign Runtime verification remains a separate acceptance gate. The document transaction does not permit bypassing required signing or policy checks when those integrations are added.

## Tests / evidence

Local isolated ooRexx 5.3.0 r13196 (user-supplied Debian SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`), against **source-equivalent copy of the new method** added to the older, separately pinned 9 October Library Mini NotNotes dev17 package (not byte-identical to this dev18 source):
- `tests/test_document_delta_contract.rex` (mock backend) **PASS**: three indexed per-key reads, two commits, one requested rollback after induced temporal-evidence write failure. It deliberately implements no `selectAll`, `selectPageAfter`, or `dropTable` operations and would fail if this method used them. This confirms method semantics only, not actual SQLite I/O, durability, or signed verification.
- The older dev17 `tests/test_tps_designer.rex`: **PASS TPS designer and completion** (legacy file compat).
- The older dev17 `tests/test_batch_persistence.rex`: **PASS Mini NotNotes batch persistence / nested commit** (legacy file compat).

**NOT_RUN / release blockers:** exact new dev18 source native compile/full-suite, `librexxsql.so` (including leak patch 0005), real SQLite WAL/rollback and forced crash/restart, SQL NULL-vs-empty/BLOB, persisted approval/temporal/report differential, >=954 and >=10k real indexed write benchmarks, real Crypto/Foreign Runtime sign/verify, independent CODEX-PC and CLAUDE-PC retests. Mock transaction has no actual rollback snapshot; receipt proves that the rollback method is called, not that a physical journal was recovered.

## Required performance and correctness discriminator

At 954 and 10,000+ records, same accepted r13196, same accepted `librexxsql.so`, same frozen dataset: compare (a) unchanged save (full snapshot), (b) one-field document update (new delta path), (c) multi-document batch, (d) legacy `FileDatabaseEngine`, with query counts, elapsed and CPU. Confirm a one-field change does not visit or encode unrelated documents. Force an error after temporal delete but before temporal insert, reopen the database, and prove prior durable document and temporal rows are unchanged. Re-run intentions/forms, document links (MANY), approvals, PDF saved reports, temporal Time Service, and migration checks. Verify that all explicit full-snapshot paths remain correct and that no crypto policy is weakened.

Use existing `notnotes-core` application ownership for review/merge, and Claude's previously assigned `REQ-00001051` for **separate** Rexx/SQL provider hardening. Do not merge this into dev18 release until real-native tests pass.


## Follow-up correctness fix: SQL NULL is not empty TEXT (29 October)

`MiniNotesPersistence~columnDiffers` now compares NULL identity before textual
bytes. Both full `saveFrom` and one-key `saveDocumentOnly` use the same
predicate. Previously each normalised SQL NULL into empty text while comparing,
which could suppress the UPDATE that changes a stored NULL into an actual empty
string, or vice versa, even though `MiniNotesRexxSqlEngine~valueFragment`
correctly renders them as distinct SQL values. This is an **application-side
bug fix**, not a Rexx/SQL native provider change.

Added `tests/test_sqlite_null_empty_change_detection.rex` and wired it into
`run_tests.sh`. Eight cases cover NULL-to-empty, empty-to-NULL, unchanged
NULL, unchanged empty, exact text, case-only changes, trailing whitespace and
embedded NUL. **Local native ooRexx 5.3.0 r13196: 8/8 PASS, compile rc0,
test rc0** against a source-equivalent copy of this comparison method added
to the pinned 9 October dev17 library. **NOT an exact dev18 clean-checkout
test, native sqlite3 round trip or complete regression suite**. The native
test under the new Git branch still requires independent execution.

This does not solve arbitrary semantic round trips for nullable custom
document fields (the inherited `encodeCustomFields` may normalise nil); those
remain separate differential acceptance cases. It does protect the SQL
column-level change-detection boundary for both save paths.
