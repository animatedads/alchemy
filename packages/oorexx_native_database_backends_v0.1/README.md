# ooRexx Native Database Backends v0.1

Provider-neutral database backend contracts plus the first primary native route: PostgreSQL through Foreign Runtime v0.22.2 and libpq.

## Architecture

Upper database semantics remain in Database Core. This package supplies interchangeable execution implementations and a richer capability/limitation publication layer.

- `NativeDatabaseBackend` — stable backend identity and common contract.
- `NativeDatabaseCapabilitySet` — explicit SUPPORTED / UNSUPPORTED / CONDITIONAL / UNKNOWN assertions with qualification state and evidence.
- `NativeDatabaseLimitation` — limitations are published separately from capabilities.
- `NativeDatabaseBackendSelector` — capability-based selection before acquisition.
- `NativeDatabaseBackendLease` — pins the chosen implementation. There is no mid-session/mid-transaction fallback.
- `PostgreSQLNativeBackend` — preferred Foreign Runtime/libpq implementation.
- `PostgreSQLNativeCommandExecutor` — plugs into existing Database Core without changing Database Core SQL/transaction/result objects.

The existing Database Process Command Executor remains the PostgreSQL fallback. It is not copied into this package.


## Runtime provider package selection

`DatabaseBackendSelector.cls` is the configuration-time package-selection boundary.
It is separate from `NativeDatabaseBackendSelector`: the latter chooses between
already-loaded native implementations by capability, while the former decides which
database provider package enters an ooRexx process at all.

This distinction is required because NoSQLServer and Database Core publish overlapping
public class names such as `.DatabaseRow` and `.DatabaseResult` with different
semantics. A neutral application must not statically `::requires` both class sets.
Instead it requires only `DatabaseBackendSelector.cls`; the selector uses
`Package~loadPackage()` to load the configured provider and resolves the provider
class inside that package. Provider public classes are not imported into the neutral
caller's package namespace.

Built-in provider ids are:

- `NOSQLSERVER` → `NoSQLDatabaseCoreProvider.cls`; returns NoSQLServer's existing
  namespaced Database Core facade.
- `POSTGRESQL` → `PostgreSQLDatabaseProvider.cls`; loads Database Core and the
  libpq-backed PostgreSQL implementation inside the selected provider package.
- `REXXSQL-SQLITE` (aliases `REXXSQL`, `SQLITE`) → `RexxSqlDatabaseProvider.cls`;
  selects the existing indexed Rexx/SQL SQLite backend. This is a provider adapter only,
  not another SQLite implementation.

Selection is deployment configuration:

```text
OOREXX_DATABASE_PROVIDER=NOSQLSERVER
OOREXX_NOSQL_ROOT=/var/lib/alchemy/semantic-store
```

or:

```text
OOREXX_DATABASE_PROVIDER=POSTGRESQL
SSC_DB_HOST=127.0.0.1
SSC_DB_PORT=5432
SSC_DB_NAME=semantic_source
SSC_DB_USER=semantic_source
SSC_POSTGRESQL_BRIDGE=/path/to/libpq.bridge.json
```

`SSC_DB_PASSWORD` is accepted when password authentication is required. Standard libpq `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, and `PGPASSWORD` remain fallback aliases; `OOREXX_POSTGRES_BRIDGE` is a fallback alias for `SSC_POSTGRESQL_BRIDGE`.

For the indexed Rexx/SQL SQLite provider:

```text
OOREXX_DATABASE_PROVIDER=REXXSQL-SQLITE
OOREXX_DATABASE_PATH=/var/lib/application/application.sqlite
```

Consumers with stricter persistence semantics should pass `requiredCapabilities` to the
provider. The current Rexx/SQL backend publishes `BLOB_WRITE` and
`NULL_EMPTY_DISTINCT` as unsupported and threaded connections as unqualified; selection
must fail closed rather than silently changing those semantics.

`OOREXX_DATABASE_PROVIDER_PACKAGE` and `OOREXX_DATABASE_PROVIDER_CLASS` may
override package/class resolution. An unknown or unloadable provider fails closed.
Changing backend must not require application-source edits, rewritten `::requires`
directives, or a coding agent to patch deployment files.

The selector regression deliberately loads two provider packages that both export
an incompatible public `.DatabaseRow` and proves that neither class leaks into the
neutral caller package.

## Primary/fallback policy

Selection is performed before a session/transaction is acquired. Once acquired, the implementation is pinned. A native failure is returned as a failure; SQL is never silently replayed through another backend.

## GIS direction

The existing direct-read ooRexx GeoPackage/GIS path remains the primary portability baseline because it is cross-platform and independent of external native libraries. A future Foreign Runtime acceleration implementation may advertise stronger performance/pushdown capabilities, but it will implement the same upper backend contract and the ooRexx-native route remains an eligible fallback/portable route.

## PostgreSQL v0.1 limitations

- synchronous drain of `PQgetResult` after `PQsendQuery`;
- no libpq pipeline mode yet;
- no cancellation yet;
- COPY streaming deliberately rejected;
- Database Core compatibility adapter currently synthesizes the existing psql-like tabular framing from structured libpq results;
- executor opens one libpq session per Database Core transaction; the low-level session class itself is reusable.

No PostgreSQL server is required for the offline acceptance suite; it proves libpq loading, capability publication, structured connection failure and Database Core adapter behavior.

## GeoPackage portable profile

`GeoPackageOoRexxBackend` formalizes the existing NoSQLServer pure-ooRexx direct reader as an `OOREXX_NATIVE` implementation of the same backend family. It intentionally remains read-only and requires no external sqlite3/GDAL/helper library. This is the portability baseline even after an optional Foreign Runtime accelerator is introduced.

`PostgreSQLProcessFallbackBackend` describes the existing Database Core `psql` route through the same capability/limitation contract. It remains separate implementation code; the native backend does not call it automatically after acquiring a libpq session.
