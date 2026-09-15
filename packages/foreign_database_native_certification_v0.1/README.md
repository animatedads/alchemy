# Foreign database/native GIS certification v0.1

Role: API Release Certification / End-to-End

This package is an acceptance contract, not an implementation package.

## Fixed ownership boundary

- Database Core owns native PostgreSQL/PostgreSQL+PostGIS and MySQL/MariaDB client connectivity.
- NoSQLServer owns SQLite/GeoPackage/GIS source access, federation, spatial SQL semantics, geometry/SRID semantics and optional native GIS execution kernels.
- msqlshim remains the MySQL/MariaDB wire-server compatibility adapter. It is not the native client implementation.
- Foreign Runtime owns the generic native-call/memory/resource boundary only.

## NoSQLServer SQLite rule

NoSQLServer must retain both implementations:

1. preferred Foreign Runtime -> libsqlite3 provider;
2. existing pure-ooRexx SQLite implementation as fallback/reference.

Required selection modes:

- `auto`: prefer Foreign Runtime/libsqlite3; fall back to ooRexx when unavailable or capability probe fails.
- `foreign`: require Foreign Runtime/libsqlite3 and fail explicitly if unavailable.
- `native`: force the pure-ooRexx implementation.

Fallback must be observable and capability-honest. GeoPackage and spatial semantics remain above both implementations.

## Native GIS direction

After SQLite/GeoPackage is green:

- GDAL/OGR may provide source access for vector data.
- GEOS may accelerate spatial predicates while the ooRexx implementation remains the differential oracle/fallback.
- PROJ may implement explicit coordinate transformation only; no implicit reprojection is allowed.

## Database Core direction

After NoSQL SQLite dual-path qualification:

- PostgreSQL native provider through Foreign Runtime -> libpq.
- MySQL/MariaDB native provider through Foreign Runtime -> libmariadb/libmysqlclient.
- Native transactions retain one connection handle across BEGIN/SAVEPOINT/ROLLBACK/COMMIT.
- Prepared parameters must remain typed; do not fall back to SQL string quoting.
- `pg_dump`/`pg_restore`/dump utilities may remain separate administrative command providers.

## Cross-stack loopback

A required later test is:

Database Core -> native MariaDB client -> MySQL wire -> msqlshim -> NoSQLServer -> native/fallback SQLite/GeoPackage.

msqlshim receives no version bump unless this test exposes an actual wire-protocol defect.

## Federation Bank IOM release significance

The resulting providers must survive banking-grade fault injection, rollback/retry, authority-generation pinning, audit and recovery tests. Database rollback must never be represented as rollback of already-committed external Queue/JMS effects.
