# NoSQLServer v0.91 — SQLite WAL read/write synchronisation intake

Status: **REVIEW / SOURCE CATCH-UP INCOMPLETE**. This is a source-patch and
validation-evidence submission, not a claimed full-package installation.

Current default branch includes \`packages/nosqlserver_v0.79/\`. The 2026-10-23
local build is the complete v0.91 development candidate, SHA-256:
\`d4a276007029e66512611ea7e836ca7ab30209b80ac7d46ecf1fba61121f02d0\`
(506,470 bytes; 247 files). Its exact predecessor v0.90 SHA-256 is:
\`08534dc11858863a6efa82e4689e07ceb420691c4a9ab7fab7da69819c8cf9da\`.

The version 0.90 to 0.91 patch is provided under patches/. It applies to the
v0.90 source files \`src/NoSQLServerSQLiteWritable.cls\` and
\`native/nosqlsqlitewriter.cpp\`. The v0.79 to v0.90 changes and the complete
v0.91 source are **not yet represented in this GitHub intake**. Do not merge or
release this intake as though it were the complete v0.91 package.

v0.91 closes a known single-table SQLite UPDATE/DELETE phantom-row window:
a write acquires BEGIN IMMEDIATE, then compares the exact immutable NoSQL
selection snapshot against the live entire target table, including rowid,
schema, typed values and even empty mutation batches, before applying the
NoSQL-approved atomic prepared operations. This is not global SERIALIZABLE
and retains the v0.90 full-database-backup read cost.

Verified locally against extracted ooRexx 5.3.0 r13196 debug and SQLite3:
v0.89 atomic read/write and BLOB/INT64 tests; v0.74 SQLite/GeoPackage;
v0.60 SQL regression; v0.90 WAL concurrent snapshot read/write; v0.91
phantom insert/zero-match/edited-row conflict and integrity checks.
Instrumentation Mesh v0.87/v0.88 optional integration and stress/crash
qualification remain open.

Release gate:
1. Materialise the COMPLETE v0.91 package under a versioned packages/ path.
2. Verify full package SHA-256 and MANIFEST.sha256.
3. Run tools/run_sqlite_rw_v091.sh and the wider environment suite.
4. Obtain normal ownership and acceptance before merging to main.

Historical packages MUST remain intact.