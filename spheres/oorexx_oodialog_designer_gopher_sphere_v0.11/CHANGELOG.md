# Changelog

## 0.11 - 2026-11-21
- Designer v0.19: qualified on ooDialog/WASM v0.27.0 and the Qt6 renderer v0.15.0.
- CORRECTION: v0.10's "RAISE of USER/ERROR is not trapped" observation was a test fault (RAISE without RETURN is an EXIT); catchcheck fixed, 9/9 on trunk. The rule is in pitfalls.

## 0.10 - 2026-11-21
- Designer v0.18: checked on the Linux Qt6 renderer (6 of 6 offscreen and on Xvfb); tests/qt; month calendar default 150x110.
- CATCH/FINALLY asked of the ooRexx (compile probe), not its revision (a git build answers r0); FINALLY no longer refused outright.
- catchcheck's first native run and the RAISE observation recorded; the Qt build recipe in build-and-test.

## 0.9 - 2026-11-20
- Designer v0.17 on ooDialog/WASM v0.23.0: resizable forms (ResizingAdmin) with per-control anchors.
- v0.16 recorded as published; its two faults recorded (no pkgcheck.rex in the package; a wrong up-down note, corrected).
- tools/mkpkg.rex in the procedure; the "..."b binary-literal trap in program-format.

## 0.8 - 2026-11-19
- Designer v0.16 on ooDialog/WASM v0.21.0: up-down with buddy, month calendar, tool tips, track bar DRAG/ENDTRACK; the page fits the window.
- v0.15 recorded as tested but not published (publish path named v0.14); tools/pkgcheck.rex added and put in the procedure.
- start, program-format, build-and-test, qualification updated.

## 0.7 - 2026-11-17
- Designer v0.15 (Autobuild: submitted 20261117T084611Z-CLAUDE-oorexx_oodialog_designer-v0.15-711768, result pending (the package lands on main only on PASS)): code assistance writes ooRexxDoc (kind DOC, AssistPlugin 0.9.0), after Rony G. Flatscher's suggestion.
- Object Editor v0.4 (branch 372715c): Document... (getDoc, setDoc, memberText) and ooRexxDoc in the Libraries panel.
- plugins, object-editor, overview-and-docs, build-and-test, qualification articles updated.

## 0.6 - 2026-11-16
- Designer v0.14 (Autobuild PASS 20261116T193840Z): ChatGPT's drag-to-connect merged (PR #3, Database Lab v0.1.3).
- build-and-test: CODEX-PC is Linux; Windows checks need Tom's machine.
- authority: Tom's decision on Fluent/WinUI controls without their host: a plain ooDialog stand-in.

## 0.5 - 2026-11-15
- Designer v0.13 (Autobuild PASS 20261115T180408Z): Rexx Parser 20261115, CATCH and FINALLY in the graph, the runtime guard and refusals.
- Pitfalls: the parser uses CATCH itself; its CPL file; the doc-comment closing quirk.
- Windows brief REQ-00004977 (wincheck, catchcheck).

## 0.4 - 2026-11-15
- Designer v0.12 (Autobuild PASS 20261115T162951Z): ChatGPT's Database Lab graph merged (47c1700); object lines filled for bound designs (OodBoundGraph.cls).
- database-lab article rewritten for the graph; open label-overlap defects (REQ-00003757).
- database-lab article: links to ChatGPT's oodialog-database-lab sphere (PR #148).

## 0.3 - 2026-11-15
- Designer v0.11 (Autobuild PASS 20261115T154919Z) and Object Editor v0.3.
- New articles: overview-and-docs (closed tree, code marks, All code, ooRexxDoc), object-editor.
- Program format: trace probes are messages that keep SIGL and RESULT.
- Pitfalls: CALL sets SIGL and drops RESULT; .Package~new line numbering in tests.

## 0.2 - 2026-11-15
- Designer v0.10: reference picker, list Add/Remove, row fields (bound-dialogs, start, qualification).
- Pitfalls: DO LABEL; long property labels scroll the page.
- Rule: a package and its sphere change together.

## 0.1 - 2026-11-15
- First sphere, written by Claude (Opus 5.5) from the published package, its README and source (SHA-256 in each article's provenance).
- Published late: the package went to alchemy main before its sphere did.
