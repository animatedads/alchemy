# NotNotes bounded CLI presentation — managed patch v0.1-dev1

**A source patch package, not a second NotNotes runtime.** Source authority remains `packages/notnotes_mini_approval_app_v0.1-dev18/src/MiniNotesCliUi.cls`. Apply `scripts/apply.py` against exactly Git blob `29a3ed15ea49ae062a3ae51052f7f3f1eb1fa2c0` and place its output in a disposable dev18 working tree; do not install `MiniNotesCliUi.cls` from this patch package as another class.

## Why

The current CLI `showDocuments` eagerly renders every `app~allDocuments` result. Reuse `MiniNotesApp~semanticCollectionRange("documents", start, count)` with a 50-row window; retain native `documentId`, keyboard page edges, PAGE NEXT/PREVIOUS, off-page direct select, filtering identity and lifecycle actions.

## Native qualification actually executed

In an isolated historical **Library dev17** package with user-supplied ooRexx 5.3.0 r13196 (this is **not** a dev18 runtime qualification): new 1,103-document stub test RED before patch (rc=163 `UNBOUNDED_UI_DOCUMENT_SCAN_FORBIDDEN`), GREEN after patch `BOUNDED_CLI_STARTUP_PASS total=1103 page_size=50 pages=23 initial_rows=50` (rc=0). Existing `test_cli_ui_screen.rex`, `test_tps_designer.rex`, `test_semantic_application_projection.rex` PASS separately. Rexx `RESULT` trap in the first draft of the test fixture was corrected in the fixture.

The edit plan has also been checked against the *current* dev18 Git blob, with all 15 single-occurrence anchors matching, but **dev18 native full-suite, 954/983/10k cold-start timings, indexed SQLite, WAL, migrations and accelerated Crypto/Foreign Runtime signing are NOT_RUN here**. Existing semanticCollectionRange still calls app~allDocuments internally; the first-page UI projection is bounded, total app load is not.

## Apply / qualification

`python3 scripts/apply.py --source /immutable/dev18/src/MiniNotesCliUi.cls --output /tmp/dev18-candidate/src/MiniNotesCliUi.cls`

Then run the actual dev18 native tests and full release gates under r13196 with a pinned Rexx/SQL and Crypto provider closure before promotion. No default-backend or signing policy changes in this package. Update the existing NotNotes sphere and acknowledge the Autobuild receipt separately; this submission is not itself acceptance, installation or deployment.
