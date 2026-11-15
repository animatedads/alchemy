# ooDialog Designer sphere (v0.1)

Architecture: Tom Dyer. Code: Claude (Opus 5.5); the Database Lab: ChatGPT.
Sphere written by Claude (Opus 5.5), 2026-11-15.

Canonical packages: `packages/oorexx_oodialog_designer_v0.9` (and v0.7, v0.8);
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
