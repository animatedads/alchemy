# ooRexx Native Database Backends Gopher Sphere v0.2

Authoritative continuity sphere for the provider-neutral Native Database Backends family.

It captures:
- the common backend contract and explicit implementation kinds;
- capability/limitation publication and explainable selection;
- session/transaction pinning and fail-closed fallback semantics;
- PostgreSQL Foreign Runtime/libpq primary architecture and roadmap;
- provider-neutral structured result semantics;
- pure-ooRexx GeoPackage as the portable correctness/reference path;
- future optional Foreign Runtime GIS acceleration without displacing the portable path;
- the separation between future outbound MySQL/MariaDB native clients and inbound `msqlshim`;
- dependency/non-vendoring doctrine and exact qualification boundaries.

The implementation baseline grounded by this sphere is `oorexx_native_database_backends_v0.2.zip` SHA-256 `c87731ff59d378a1bbe9470b103fe36f96e4d0a7f808c2fcdc7ac53dd9ff066b`.

The 2026-09-02 ooRexx API roll-up is recorded as a continuity source for newer companion packages. Its presence does not retroactively qualify v0.2 against every newer dependency.

## 2026-10-27 Library/Git reconciliation

The raw Library inventory now exposes `oorexx_native_database_backends_v0.3.4.zip` and `native_database_backends_gopher_sphere_v0.2.zip`, while the Project Alchemy Package Register still records v0.3.1 and this Git sphere remains v0.1 with a v0.2 implementation baseline. This is an explicit publication/reconciliation gap, not a supersession decision. See `LIBRARY_RECONCILIATION_2026-10-27.md` before importing or relabelling any head.


## 2026-10-29 indexed SQLite provider

The shared runtime selector now has a generic provider for the existing Rexx/SQL SQLite
backend. Consumer and migration constraints are recorded in
`REXXSQL_PROVIDER_CONTRACT_2026-10-29.md`. This does not change the unresolved Library
v0.3.4/Git version reconciliation recorded separately.


## 2026-11-11 canonical v0.3.2 Autobuild line

The structured sphere now records the canonical Git source increment
`oorexx_native_database_backends v0.3.2`: provider-package selection is present in the
canonical package, the selector regression is package-owned, Rexx/SQL points at the
canonical Native Database Backends source, and Autobuild targets the current Git
Foreign Runtime v0.22.6 dependency.

This does **not** supersede the separate Library artifact
`oorexx_native_database_backends_v0.3.4.zip`. That Library head remains an unreconciled
parallel line until its exact bytes are available for source/ABI comparison. The v0.3.2
Git line is therefore a test/publication candidate from the known v0.3.1 parent, not a
claim that Library v0.3.4 has been incorporated.


## 2026-11-11 Autobuild receipts

Two exact provider-composition lines are now receipt-backed:

- Native Database Backends v0.3.2 — Autobuild **PASS**, tree
  `363991d9f9959362100936d4755ee9a6c9ee57bab2c4dc85e9ef4ebb20c73dcf`.
  Selector/capability/bulk/fallback/wire-boundary gates executed. The two tests that
  require real libpq were explicitly environment-skipped because the Autobuild host
  has no `libpq.so.5` or `libpq.so`; this is not a fresh live-libpq qualification.
- Rexx/SQL SQLite v0.1.1 — Autobuild **PASS**, tree
  `754559f1c302136edc3dc20bc3f0637d8fd33fd542e12dbe65e70b6850999553`.
  Driver/backend/provider gates and SSC provider/live suites passed.

The Library `oorexx_native_database_backends_v0.3.4.zip` remains a separate,
unreconciled head and is not superseded by these Git/Autobuild receipts.
