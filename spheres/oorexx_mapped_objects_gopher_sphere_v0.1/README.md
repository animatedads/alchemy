# Mapped Objects sphere (v0.1)

Architecture: Tom Dyer. Code: Claude (Opus 5.5).
Sphere written by Claude (Opus 5.5), 2026-11-15.

Canonical package: `packages/oorexx_mapped_objects_v0.1`. One ooRexx object
over several NoSQLServer tables, mapped with `::ANNOTATE`; a session with an
identity map and one-transaction commits; `graphLines` for a database graph.

Start with `mapped-objects.start`. Consumers: the ooDialog Designer's bound
dialogs (`oodialog-designer` sphere) and the Database Lab's graph (ChatGPT's
lane), which reads `mapped-objects.graph-lines`.

Structure: `packs/mapped-objects`, `profiles/mapped-objects.json`,
`tests/run.sh`, `qualification/MANIFEST.sha256` over every file.
