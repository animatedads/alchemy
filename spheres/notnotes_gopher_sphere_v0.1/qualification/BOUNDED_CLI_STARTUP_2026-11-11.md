# NotNotes CLI bounded startup — 11 November 2026

## Finding / reuse rule

The existing Mini NotNotes application already owns `semanticCollectionRange("documents", start, count)`, a renderer-neutral contract limiting one window to at most 100 rows. Consumers **must use it** rather than constructing all document table rows on CLI or Wire renderer startup. `MiniNotesCliUi.cls` at Git main `09ce28dfbbcdeb2081f89ac3ad88b2ea2afb8f1c`, blob `29a3ed15ea49ae062a3ae51052f7f3f1eb1fa2c0`, still starts with `app~allDocuments` and `tableFromDocuments`. A source candidate changes the CLI projection to pages of 50, retains `DocKey`/documentId identity and first-party NotNotes actions, and supports PAGE NEXT/PREVIOUS as well as UP/DOWN edge navigation. Query and view surfaces retain their source identity; paging in them must not silently switch to the unfiltered collection.

## Executed native candidate evidence

- Runtime: user-supplied ooRexx 5.3.0 r13196, extracted locally without host installation.
- Isolated *historical* Library Mini NotNotes dev17: `notnotes_mini_approval_app_v0.1-dev17.zip` SHA-256 `0b074b97081ea8c7759eab069f759e4c1a98bd471f537c5d1d3590b183a23312`; this is **not** asserted byte-identical to main dev18.
- New regression with stub semantic provider rejecting `allDocuments`: **RED** on unpatched controller (rc=163, `UNBOUNDED_UI_DOCUMENT_SCAN_FORBIDDEN`).
- After bounded controller change: `BOUNDED_CLI_STARTUP_PASS total=1103 page_size=50 pages=23 initial_rows=50`; all 1,103 stable keys traversed once; filtered query/view page isolation, UP/DOWN page transitions, off-page SELECT and zero-document case passed (rc=0).
- Inherited `test_cli_ui_screen.rex`, `test_tps_designer.rex`, `test_semantic_application_projection.rex`: PASS individually under the same isolated r13196 run.
- The independent source anchor check on *current Git dev18* validated **15 exact single-occurrence replacements** against the above blob; this is **source-apply verification**, not a dev18 runtime PASS.

## Boundary / remaining release gates

This eliminates eager UI table-row creation; it does **not** eliminate `MiniNotesApp~semanticCollectionRange` calling `semanticSurfaceDocuments` / `allDocuments` internally, nor the current eager application persistence reload. Existing indexed Rexx/SQL SQLite provider remains authoritative; do not add a second database, do not claim a cold-start timing reduction until measured. Crypto signing policy remains in Crypto/Foreign Runtime; there is no signing change or bypass.

Before release: apply the patch to exact current dev18 under normal source ownership and native-qualify on the current integrated package; run 954/983/10k corpus cold-start and first-page latency, query/view filter tests, lifecycle/TPS/PDF/temporal tests, full suite, native SQLite WAL/transactions/migration, and accelerated Crypto/Foreign Runtime signing as separately governed gates. A managed Autobuild submission and its final receipt must be recorded distinctly. No production installation or ED209 qualification is claimed.

## Cross-project pointers

- `packages/notnotes_mini_approval_app_v0.1-dev18/src/MiniNotesCliUi.cls` — consumer to fix, owned by `notnotes-core`.
- `MiniNotesApp~semanticCollectionRange` — existing NotNotes contract, **reuse it**.
- `packages/oorexx_rexxsql_backend_v0.1` — indexed SQLite provider, do not fork.
- `spheres/rexxsql_backend_gopher_sphere_v0.1`: `rexxsql.pitfalls` documents the ooRexx special variable `RESULT` trap met and corrected in the fixture.
- `alchemy-programme` / Rasen Falcon Coordinator 2 — handover, evidence, acceptance boundaries.
