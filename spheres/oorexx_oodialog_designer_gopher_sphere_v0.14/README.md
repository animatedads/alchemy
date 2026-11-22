# ooDialog Designer sphere (v0.14)

Architecture: Tom Dyer. Code: Claude (Opus 5.5); the Database Lab: ChatGPT.
Sphere written by Claude (Opus 5.5), 2026-11-22.

Canonical packages: `packages/oorexx_oodialog_designer_v0.23` (and v0.7 to v0.22; v0.15 was not published), and the ooRexx Object Editor (folder `object-editor/` of the same branch);
working branch `oodialog-designer` in animatedads/oorexx. This sphere records
the designer's authority, the program and design format, bound dialogs, the
plugin host and its secrets chain, build and test, pitfalls and what is open.
It is not a copy of the code.

Start with `oodialog-designer.start`. A dialog bound to an object depends on
the `mapped-objects` sphere; the Database Lab's graph reads its
`mapped-objects.graph-lines` contract.

Structure: `packs/oodialog-designer` (sphere, access policy, articles, a
continuity corpus), `profiles/oodialog-designer.json`, `tests/run.sh`
(`validate_sphere.py`, then a Gopher context check), and
`qualification/MANIFEST.sha256` over every file.
