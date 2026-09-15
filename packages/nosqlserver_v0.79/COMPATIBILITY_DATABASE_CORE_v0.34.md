# NoSQLServer compatibility with ooRexx DB Skeleton v0.34

## Scope

NoSQLServer v0.69 extends its existing namespaced Database Core compatibility
facade to the observable relational-source and spatial contracts in the
supplied ooRexx DB Skeleton v0.34.

The source packages are **not** loaded together. NoSQLServer historically
publishes several public `Database*` classes that overlap names exported by
`database_core.cls`; loading both full class sets into one ooRexx package would
create name collisions. The NoSQLServer facade therefore uses
`NoSQLDatabaseCore*` classes and mirrors the concrete v0.34 contract shape.

## Relational source surface

`engine~databaseCore()` exposes:

- `endpointIdentity()`
- `capabilities()` / `supports(capability)`
- `tables()` returning relation descriptors
- `relationalSource()`
- `tableSource(tableName)`
- existing `query`, `queryWithSchema`, `tableMetadata`, and `queryTable`

The relational source exposes identity, endpoint identity, capabilities,
relation discovery and table binding. A table source exposes identity,
capabilities, metadata, rows, query and `describe()`.

The v0.34 contract is provider-neutral. FILE, OBJECT/SNAPSHOT and external
providers continue to enter through `FederatedDatabaseEngine`; the relational
source facade does not branch on GeoPackage or snapshot classes.

## Geometry

The following v0.34 spatial information is preserved:

- common type: `GEOMETRY`
- geometry subtype, e.g. `POINT` or `POLYGON`
- SRID
- raw geometry payload
- transport encoding (`GPKGBLOBHEX` for GeoPackage geometry)

`GeoPackageDatabaseEngine~tableMetadata()` now supplies subtype/SRID metadata.
`FederatedDatabaseEngine~tableMetadata()` delegates to the owning provider when
that provider offers metadata, rather than reconstructing a generic definition
and losing provider metadata.

`NoSQLDatabaseCoreGeometryValue` exposes the typed value without flattening the
underlying `GeoPackageGeometry` object.

## Capability honesty

`SPATIALTYPES` is advertised for engines exposing `GEOMETRY_TYPED_VALUE`.
`SPATIALFUNCTIONS` is not advertised. v0.69 adds no fake spatial predicates.

## Focused acceptance

`tests/v069_dbcore_v034_compat_smoke.rex` verifies:

- federated relational-source identity and table discovery
- FILE + GeoPackage relation descriptors through one source
- table-source metadata/rows/describe
- direct GeoPackage POINT metadata with SRID 27700
- direct Database Core typed geometry value preservation
- federated metadata and typed geometry preservation
- `SPATIALTYPES` present and `SPATIALFUNCTIONS` absent
