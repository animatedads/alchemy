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
