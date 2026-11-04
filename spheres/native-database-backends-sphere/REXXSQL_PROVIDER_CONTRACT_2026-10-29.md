# Rexx/SQL SQLite provider contract — 2026-10-29

This note records the Native Database Backends composition contract for consumers that
select the existing `oorexx_rexxsql_backend_v0.1` indexed SQLite implementation.

## Authority boundary

- SQLite execution remains owned by `RexxSqlSqliteBackend` / Mark Hessling Rexx/SQL.
- `RexxSqlDatabaseProvider.cls` is only the generic `DatabaseBackendSelector` adapter.
- No duplicate SQLite driver, NoSQL emulation layer, or new persistence authority is introduced.
- Backend selection remains configuration-only.

## Selector identity

The shared selector normalizes `REXXSQL-SQLITE`, `REXXSQL`, and `SQLITE` to
`REXXSQL-SQLITE` and loads `RexxSqlDatabaseProvider.cls` /
`RexxSqlDatabaseProvider`.

The provider accepts an explicit database path or environment configuration and returns a
`RexxSqlSqliteSession` only after requested capabilities have been checked.

## Migration safety contract

Supported/tested:
- indexed keyed lookup and secondary indexes;
- transactions and rollback;
- WAL for file-backed databases;
- byte-exact text, including CRLF and bound NUL text;
- BLOB read.

Not safe to assume:
- `NULL_EMPTY_DISTINCT`: unsupported; empty bound strings are mapped to SQL NULL;
- `BLOB_WRITE`: unsupported;
- `THREAD_SAFE_CONNECTIONS`: untested/unknown because Rexx/SQL has process-wide current
  connection state.

A consumer that requires any unsupported capability must fail closed. The generic provider
implements this through `requiredCapabilities`.

## NotNotes consequence

NotNotes may use this provider as its indexed persistence default only through a
MiniNotesPersistence adapter that explicitly defines its field encoding and migration rules.
It must not silently reinterpret NULL versus empty string, cannot depend on BLOB writes with
the current backend, and must not claim concurrent threaded session safety without separate
qualification. Legacy file-store migration must be explicit and reversible; there is no
silent fallback to NoSQLServer after a provider has been selected.

## Qualification boundary

The Rexx/SQL package-owned suite now includes `tests/test_database_provider.rex`, covering
provider open, WAL and fail-closed `BLOB_WRITE` / `NULL_EMPTY_DISTINCT` requirements.
The code is committed to Git; a fresh ooRexx 5.3.0 r13196 execution receipt is still required
for this 2026-10-29 increment before it is described as newly qualified.


## SSC-specific override

Semantic Source Store has a specialized Rexx/SQL provider because SSC owns an index plan
that is not a generic SQLite concern. `SemanticSourceRexxSqlProvider` now implements the
same `open(options)` provider contract and returns its index-plan-equipped executor.

Therefore SSC may use the shared selector without source edits by configuring:

```text
OOREXX_DATABASE_PROVIDER=REXXSQL-SQLITE
OOREXX_DATABASE_PROVIDER_PACKAGE=SemanticSourceRexxSqlProvider.cls
OOREXX_DATABASE_PROVIDER_CLASS=SemanticSourceRexxSqlProvider
SSC_DATABASE_ROOT=/var/lib/alchemy/semantic-source
```

Generic consumers such as NotNotes use `RexxSqlDatabaseProvider`; SSC uses the specialized
provider override. The shared selector remains service-neutral.
