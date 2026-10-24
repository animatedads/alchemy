# NoSQLServer v0.91 — configuration-only Database Core selection

NoSQLServer and Database Core publish overlapping public class names with different
semantics. They must not be statically `::requires`-loaded into one application
package and left to class-name resolution order.

`src/NoSQLDatabaseCoreProvider.cls` is the provider package for the shared
`DatabaseBackendSelector`. It is loaded only when `NOSQLSERVER` is selected
and returns NoSQLServer's existing namespaced `FileDatabaseEngine~databaseCore`
facade. Native NoSQLServer API and result semantics are unchanged.

A neutral service requires only `DatabaseBackendSelector.cls`. Backend choice is
configuration:

```text
OOREXX_DATABASE_PROVIDER=NOSQLSERVER
OOREXX_NOSQL_ROOT=/var/lib/alchemy/semantic-store
```

or for PostgreSQL:

```text
OOREXX_DATABASE_PROVIDER=POSTGRESQL
PGHOST=...
PGPORT=5432
PGDATABASE=...
PGUSER=...
```

If provider package/class locations are not on `REXX_PATH`, set
`OOREXX_DATABASE_PROVIDER_PACKAGE` and `OOREXX_DATABASE_PROVIDER_CLASS`.

Acceptance rule: switching provider must not require editing application source,
rewriting `::requires`, replacing class names, or asking Codex/another coding
agent to patch deployment files. The selector dynamically loads only the selected
provider package and does not import its public classes into the neutral caller
package.
