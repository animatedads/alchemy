# Changelog

## 0.3 — 2026-10-23 SQLite writable candidate continuity
- Added `nosqlserver.sqlite-writable-v091`: opt-in backend, native prepared mutations, WAL-coherent snapshots, BEGIN IMMEDIATE schema/row validation and failure semantics.
- Distinguished complete GitHub v0.79 source, separately delivered complete v0.91 candidate and merged PR #20 patch intake.
- Updated start, storage, transactions, source map, qualification and continuity records; preserved historical provenance.
- Recorded explicit limitations: full database copies, O(table) write validation, no global/multi-statement serializability, no distributed guarantees or production certification.
- Repaired the package manifest to reflect all actual sphere files, including earlier Intention Service article.

## 0.2
- Added Intention Service × NoSQLServer database-search integration evidence, schema-derived traversal, dynamic discovery, execution-path selection and registered backend composition.

## 0.1
- Initial project continuity sphere from current project package and engineering doctrine.
