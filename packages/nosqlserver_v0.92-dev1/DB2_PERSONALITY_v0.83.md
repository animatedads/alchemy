# NoSQLServer v0.83 — DB2 CURRENT ISOLATION and RR transaction personality

v0.83 adds the first transaction/session-isolation slice to the explicit DB2
personality while preserving NoSQLServer's existing serializable staged
transaction engine as the authority.

## Added

- `CURRENT ISOLATION` special-register projection;
- `SET CURRENT ISOLATION RR` and `SET CURRENT ISOLATION = RR`;
- DB2 compatibility spellings `REPEATABLE READ` and `SERIALIZABLE`, normalized
  to DB2 `RR`;
- `SET CURRENT ISOLATION RESET`;
- a DB2 personality transaction wrapper returned by `db2~transaction` /
  `db2~beginTransaction`;
- statement-level `WITH RR` inside that explicit personality transaction;
- current-schema and DB2 row-limit translation inside staged transaction SQL;
- serializable publication-conflict behaviour inherited from the authoritative
  NoSQLServer staged transaction implementation.

## Honest isolation boundary

The native NoSQLServer staged transaction engine creates a stable database
clone and publishes only if the live database signature still matches the
signature captured at transaction start. This is strong enough to map the DB2
`RR` personality onto the existing serializable transaction boundary.

It does not implement DB2's weaker lock/concurrency behaviours. Therefore the
DB2 personality deliberately rejects `UR`, `CS`, and `RS` instead of silently
upgrading or approximating them. `WITH RR` is accepted only through an explicit
DB2 personality transaction; statement-isolation clauses on direct autocommit
execution fail explicitly.

Session/index DDL, special-register queries, and synthetic `SYSCAT` projections
are not staged inside a DB2 transaction in v0.83.
