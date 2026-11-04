# ooRexx Native Database Backends v0.2

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

## PostgreSQL v0.2 result materialisation

The native PostgreSQL route now has two deliberately separate result paths:

- `executeStream()` remains the legacy Database Core compatibility adapter and may render tabular text for existing callers.
- `querySet()` returns `PostgreSQLNativeBulkResult`, retaining the `PGresult` as one relation until a caller asks for materialisation.

`PostgreSQLNativeBulkResult~asArray` performs exactly one producer-owned tuple/field pass and then releases the native `PGresult`. Subsequent `asArray` calls return the same Array object without another native traversal. `asJson` serialises that already-materialised object graph with one `json.cls` call.

The conversion is driven from PostgreSQL field OIDs. The common scalar families are preserved at the JSON boundary: NULL, BOOLEAN, INTEGER, DECIMAL, VARCHAR/TEXT, DATE/DATETIME, BLOB and JSON/JSONB. Numeric-looking text is wrapped as `JsonString` so it cannot accidentally become a JSON number; large integer lexical values are retained exactly. PostgreSQL-specific types without a common scalar mapping remain strings rather than being guessed.

The intended bounded-result path is therefore:

```text
PGresult*
  -> one native producer materialisation pass
  -> Array<Directory>
  -> one json.cls serialization call
```

This is the normal path for bounded service/MCP result sets. Very large results still require a cursor/single-row streaming mode; v0.2 does not claim that capability.

Remaining limitations:

- synchronous drain of `PQgetResult` after `PQsendQuery`;
- no libpq pipeline mode yet;
- no cancellation yet;
- COPY streaming deliberately rejected;
- the legacy Database Core command-executor path still exists for compatibility;
- duplicate SQL output column names cannot be represented losslessly by an Array of Directories and should be aliased uniquely by the query when bulk object/JSON materialisation is requested.

## GeoPackage portable profile

`GeoPackageOoRexxBackend` formalizes the existing NoSQLServer pure-ooRexx direct reader as an `OOREXX_NATIVE` implementation of the same backend family. It intentionally remains read-only and requires no external sqlite3/GDAL/helper library. This is the portability baseline even after an optional Foreign Runtime accelerator is introduced.

`PostgreSQLProcessFallbackBackend` describes the existing Database Core `psql` route through the same capability/limitation contract. It remains separate implementation code; the native backend does not call it automatically after acquiring a libpq session.
