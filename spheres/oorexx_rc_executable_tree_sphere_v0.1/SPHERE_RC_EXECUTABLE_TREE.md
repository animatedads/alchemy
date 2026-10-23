# Windows RC executable resource tree sphere v0.1

## Ownership and purpose

This sphere owns knowledge, design decisions, compatibility evidence, and next actions for interpreting Microsoft Windows resource scripts (.rc/.h), building an **executable ooRexx resource/application-object tree**, and presenting that single semantic tree through a native Windows renderer or the Wire UI family.

Project source boundary: `packages/oorexx_rc_executable_tree/`.
GitHub development: `feature/windows-rc-executable-tree-qualification` (draft PR #15).
The sphere is **not** authority for the separate ooDialog-on-Linux compatibility port; that port may consume stable contracts without waiting for this project.

## Invariants

1. **100% Windows-first** is the initial acceptance target, not a delivered achievement. OS/2 Presentation Manager support is a separate future grammar/provider; it must not contaminate Windows syntax.
2. Parsing and round-tripping preserve source locations, raw statements, language scope, preprocessor conditions and unresolved evidence. Unknown syntax must remain visible and fail a strict semantic acceptance gate, not disappear.
3. An .rc `IDC_STATIC`/negative or repeated control ID is *not* a unique object identity. Distinguish source occurrence/semantic tree UID, resource ID, and handler identity.
4. Real ooRexx methods are installed via `.Method~new` and `setMethod` using approved discovery/operation definitions, like `packages/oorexx_odoo_crm_provider/src/OdooDynamicObject.cls`. Never compile or execute arbitrary resource text.
5. Events are attached to the live application tree. Handler outcomes may include validated declarative tree mutations, with authorization, limits, lifecycle and eventual atomicity; they are not executable scripts embedded in JSON.
6. Native Windows and Wire UI are peer projection targets. Neither is the application's source of truth or owner of application logic. Do not assume ooDialog's widget hierarchy is the common architecture.
7. Do not confuse parser syntax acceptance, identifier/style/asset semantic resolution, Windows resource-compiler parity, or runtime ooDialog callback/lifecycle equivalence.

## Architecture

```text
Win32 .rc + .h + binary assets
    -> Windows lexing / preprocessing and source provenance
    -> typed resource syntax and semantic JSON
    -> approved method discovery / real ooRexx instances
    -> canonical executable UI tree + retained state + event/mutation contract
       |-> native Win32 projection (renderer only)
       |-> Wire UI projection (renderer only)
```

Windows resource families in the qualification inventory include dialog/dialogex, menu/menuex, accelerator tables, string tables, icons, cursors, bitmaps, raw data, version information, manifests, HTML and message tables where applicable. Support must include nesting, defines/conditional evaluation, SDK includes, styles, assets, language/localization, and compiler dialect differences. The supplied example-resource fixture's 10 recognised declarations is **not** a measure of comprehensive family coverage.

## Grounded history and evidence (2026-10-23)

Standalone development artifacts v5–v14 were reported and exercised in conversation/local runtime, but the historical ooRexx parser/classes have **not yet been fully imported into GitHub**. Do not mark the source-qualified head as v14.

Last explicitly preserved evidence:
- Three **upstream-derived excerpts** (`comboBoxTypes.rc`, `toolBar.rc`, `imageButton.rc`) passed structural recognition; 23 controls total.
- The three excerpts had 15 unresolved control-ID occurrences and none met fully resolved semantic acceptance.
- The official ooRexx 26-file sample manifest is known, but **zero complete original files were executed** in the earlier regression suite.
- No Windows resource compiler differential qualification or native runtime event/focus parity proven.
- A v9 local proof reportedly established per-object method binding, retained duplicate-ID separation, handler-returned declarative mutations, and JSON reconstruction. This is prior local evidence, not GitHub qualification.

Direct GitHub sources of truth are `packages/oorexx_rc_executable_tree/README.md`, `docs/INTEGRATION.md`, `corpus/official_oodialog.txt`, `tools/corpus_inventory.py`, and `tests/test_corpus_inventory.py`.

## Testing and non-negotiable acceptance

**Stage A — acquisition:** obtain original pinned official ooRexx .rc, companion .h, and .rex source files with hashes; no excerpts substituted for originals. Test corpus availability with:

```bash
python3 packages/oorexx_rc_executable_tree/tools/corpus_inventory.py --checkout /path/to/ooRexx
python3 -m unittest discover -s packages/oorexx_rc_executable_tree/tests -v
```

**Stage B — lexical/preprocessor:** expand supported includes and directives with explicit unresolved diagnostics, conditional branch semantics, source provenance, syntax errors, delimiters and literal escaping.

**Stage C — semantic:** resolve IDs/styles/control classes and correct resource kinds, preserve duplicates, language, binary asset references and block hierarchy, plus JSON round trip.

**Stage D — compiler differential:** compare with `rc.exe`, GNU `windres`, `llvm-rc` where dialects overlap. Require documented exceptions rather than silent discrepancies.

**Stage E — executable behaviour:** associate companion ooDialog Rexx event declarations, test handler signatures, control lifecycle, focus, command routing, owner draw, dialog modality, and dynamic mutation results.

**Stage F — both renderers:** native Windows and Wire UI consume equivalent stable semantic snapshots; an event reaches the *same* real ooRexx handler and makes the *same* state transition, with renderer-specific presentation alone differing.

A completed parse that leaves unresolved identifiers is a **semantic failure**. Unavailable original files are **NOT RUN**, never PASS. Full Windows coverage cannot be claimed until all stage gates pass.

## Project interfaces and adjacencies

- `packages/oorexx_odoo_crm_provider/src/OdooDynamicObject.cls`: pattern for authorized per-instance dynamic method discovery.
- `spheres/sphere_wire_ui/` and `spheres/wire_ui_swing_gopher_sphere_v0.1/`: Wire presentation authority constraints.
- `packages/oorexx_rc_executable_tree/docs/INTEGRATION.md`: coordination with native ooDialog compatibility effort.
- OS/2 PM (`DLGTEMPLATE`, `ENTRYFIELD`, `ACCELTABLE`, pointer, help resources) is deferred, but preserve extensible parser-provider boundary and explicit source geometry units/origin.

## Immediate continuation order

1. Import and review actual v11–v14 .rex parser and v9/v10 ooRexx object/event classes into this GitHub package; keep author/provenance hashes and do not overwrite stronger current source.
2. Execute the existing Python inventory unit tests and pin original upstream source corpus + includes.
3. Run **all** original .rc files and attach machine-readable failure classes and metrics.
4. Address unresolved SDK symbols/headers, resource-asset grammar and preprocessor shortcomings with regression tests.
5. Exercise compiler comparisons and companion .rex method/event linkage.
6. Qualify renderer-neutral snapshots and live dispatch against a native Windows and Wire UI host.

## Rejected shortcuts

- Treating nine or ten recognised example resource statements as 100% Windows coverage.
- Inventing sample source or counting absent upstream originals as passing.
- Turning a native renderer or Qt-based ooDialog implementation into the application's authoritative object model.
- Generating ooRexx executable source from untrusted .rc/JSON event fields.
- Merging OS/2 PM grammar into the Windows parser to accelerate the eventual legacy-port story.
