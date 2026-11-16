# ooDialog Database Lab Gopher sphere v0.2

Architecture: Tom Dyer. Code and sphere: ChatGPT (GPT-6), 2026-11-15.

This sphere documents the Database Lab model, the Designer's SVG Graph tab,
and its contract with the mapped-object store. Begin at
`oodialog-database-lab.start`, `oodialog-database-lab.graph-tab`, then
`oodialog-database-lab.drag-relationships`.

Canonical model: `packages/oorexx_oodialog_database_lab_v0.1.3` in
`animatedads/alchemy`. Page: `oodialog-designer/site/database-lab.js` and
`.css` in `animatedads/oorexx`, feature branch
`feature/oodialog-database-relations-dnd-20261115` (based on Designer v0.13).

v0.2 removes an invalid Gopher profile pack dependency (`packs/nosqlserver`)
and supplies continuity records so the sphere's articles can be resolved.

The model owns database actions; the page projects output and sends intentions.
Database creation and schema replacement are for disposable testing only.

Offline qualification: `python3 tests/validate_sphere.py`.
