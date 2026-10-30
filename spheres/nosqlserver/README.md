# NoSQLServer engineering sphere v0.5 — 2026-10-29

Current Git source includes `packages/nosqlserver_v0.91` and the newer `packages/nosqlserver_v0.92-dev1`. v0.92-dev1 adds native SQLite INTEGER-primary-key rowid seeks and lazy row counts; NoSQLServer SQL predicates remain authoritative.

The Intention Service database-search integration is refreshed to dev30. Capability evidence now consumes the public DatabaseVersion feature registry before compatibility probes, and World population returns to exact INTEGER semantics. The source rebuild also fixes plain MySQL `INSERT INTO country` parsing and proves all 5,302 World rows can be rebuilt.

The separately selected Rexx/SQL SQLite backend remains independent. NoSQLServer writable SQLite still has the documented large-scale/performance limitations.

Autobuilder is OFF. No website, mail, XTP MI/MU, LDAP or private-CA HTTPS deployment is claimed from this sphere update.
