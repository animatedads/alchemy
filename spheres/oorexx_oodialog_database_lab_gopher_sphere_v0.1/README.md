# ooDialog Database Lab Gopher sphere v0.1

Architecture: Tom Dyer. Code and sphere: ChatGPT (GPT-6), 2026-11-15.

This sphere documents the Database Lab model, the Designer's SVG Graph tab,
and its contract with the mapped-object store. Begin at
`oodialog-database-lab.start`, then `oodialog-database-lab.graph-tab`.

Canonical model: `packages/oorexx_oodialog_database_lab_v0.1.2` in
`animatedads/alchemy`. Page: `oodialog-designer/site/database-lab.js` and
`.css` in `animatedads/oorexx`, feature branch
`feature/oodialog-database-graph-v3-20261115` (based on Designer v0.11).

The model owns database actions; the page projects output and sends intentions.
Database creation and schema replacement are for disposable testing only.

Offline qualification: `python3 tests/validate_sphere.py`.
