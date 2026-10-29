# NoSQLServer engineering sphere v0.4 — 2026-10-29

Full source is now in GitHub at `packages/nosqlserver_v0.91` and `packages/nosqlserver_v0.92-dev1`.

v0.92-dev1 provides native ooRexx SQLite integer-primary-key B-tree rowid seeks and lazy row counts, with NoSQLServer's SQL predicates still authoritative. Start with `nosqlserver.sqlite-rowid-v092`.

The independent, explicitly selected patched Mark Hessling Rexx/SQL SQLite backend is at `packages/oorexx_rexxsql_backend_v0.1`. It has much faster indexed query performance in the published Semantic Source Store tests; it is not an implicit NoSQLServer SQL backend. BLOB writes are unsupported by Rexx/SQL.

NoSQLServer's writable SQLite still makes a complete SQLite backup snapshot per statement and full-table validation for guarded UPDATE/DELETE. Large-scale performance, crash recovery, distributed transactions and production readiness are unqualified.

Autobuilder is OFF. No website, mail, XTP MI/MU, LDAP or private-CA HTTPS deployment is claimed. Historical v0.79 and v0.91 intake source are preserved.
