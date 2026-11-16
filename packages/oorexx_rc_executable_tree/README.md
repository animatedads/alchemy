# ooRexx Windows Resource Script / Executable Tree

Status: **Windows-first qualification in progress; NOT 100% compatible.**

This package owns a renderer-independent application resource model, distinct from the ooDialog-on-Linux compatibility implementation. The intended pipeline is:

```
Windows .rc + headers -> preprocessing + grammar -> typed semantic JSON
                       -> live ooRexx objects + discovery-installed methods
                       -> Windows native / Wire UI renderer projections
```

Windows is the mandatory initial coverage target. OS/2 PM is a subsequent, separate parser provider, not an extension of the Windows grammar.

## Proven locally, not yet published as release-quality

Development artifacts v5–v14 were tested outside this repository. Most recent v14 checks:
- 3/3 **upstream-derived excerpts** structurally parsed by ooRexx 5.3.0.
- 23 controls identified across those excerpts.
- 15 unresolved control-ID occurrences; 0/3 qualified as semantically resolved.
- 0/26 *complete original upstream files* executed.
- No rc.exe / windres / llvm-rc compiler differential qualification.
- Neither native Win32 behavioural nor Wire UI runtime compatibility established.

The historical standalone v14 archive is **not** represented as fully merged source in this branch. Do not claim this package is a release of v14 without importing and reviewing its original `rc_to_json_v11.rex` and associated ooRexx classes.

## Acceptance gates

1. Original upstream .rc files and all local headers available, with immutable source hashes.
2. Lexical and preprocessor fidelity, including conditional branches and includes.
3. Correct typed grammar for all Windows resource families and nested scopes.
4. Resolved identities, control classes, style expressions, languages, binary asset references.
5. Deterministic round-trip/provenance, duplicate IDC_STATIC-safe per-object identity.
6. Differential compiler checks (rc.exe, windres, llvm-rc) with documented platform caveats.
7. ooDialog companion .rex callback and lifecycle equivalence.
8. Renderer-neutral event and mutation contracts; no assumption that Wire owns application logic.
9. Negative tests for unsupported features and forbidden dynamic executable sources.

## Corpus

`corpus/official_oodialog.txt` contains the first wave of 26 official upstream paths. Use `tools/corpus_inventory.rex` to inventory a local checkout before treating a parsed excerpt as a full upstream pass:

```
rexx packages/oorexx_rc_executable_tree/tools/corpus_inventory.rex --checkout /path/to/ooRexx
```
```
rexx packages/oorexx_rc_executable_tree/tests/test_rc_tools.rex
```

The tools are ooRexx (Claude (Opus 5.5), 14 Nov 2026), ported from the earlier Python `corpus_inventory.py` and `verify_release_archives.py` (ChatGPT). On the real corpus, the inventory port gives a report identical to the Python original, field for field. `verify_release_archives.rex` also checks each archive against the SHA-256 the sphere records, which the Python tool computed but never compared. Its report schema is therefore `/2`. Both log progress through `oorexx_logging_stream_target`.

Upstream: https://github.com/ooRexx/ooRexx/tree/master/samples/windows/oodialog

The ooRexx executable tree is inspired by the genuine per-instance method-discovery model in `packages/oorexx_odoo_crm_provider/src/OdooDynamicObject.cls`: create methods from approved definitions via `.Method~new` and `setMethod`, not by executing untrusted resource text.
