# NoSQLServer v0.79 — Alchemy Objects v0.8 adoption boundary

## Dependency

NoSQLServer resolves `AlchemyObject.cls` through the normal ooRexx package search
path. The validated dependency is `alchemy_objects_v0.8`, with
`oorexx_crypto_v0.1` as Alchemy Objects' external cryptographic dependency.

No Alchemy Objects source is vendored into NoSQLServer.

## Adopted objects

The following long-lived/stateful service objects derive from
`NoSQLAlchemyObject` and therefore from `AlchemyObject`:

- `FileDatabaseEngine`
- `ObjectDatabaseEngine`
- `JsonDatabaseEngine`
- `SQLiteDatabaseEngine`
- `GeoPackageDatabaseEngine`
- `FederatedDatabaseEngine`
- `NoSQLServerRuntime`
- `NoSQLServerSQL`
- `DatabaseTransaction`
- `NoSQLDatabaseCoreAdapter`

NoSQL rows, scalar values, geometry values, parser/expression nodes, metadata
value records and other hot-path data objects deliberately remain lightweight.

## Construction

NoSQLServer-owned descendants now call `self~init:super(...)`. The
`NoSQLAlchemyObject~init` method builds package/role metadata then forwards to
`AlchemyObject~init`. This records construction provenance as `INIT` under
Alchemy Objects v0.8.

`initNoSQLAlchemy()` remains only as a compatibility helper for downstream
subclasses written against v0.77/v0.78; it scopes an `INIT` send to
`NoSQLAlchemyObject` rather than reintroducing virtual base dispatch.

## Adoption level

All adopted NoSQL service objects satisfy `AlchemyAdoptionVerifier` level
`STANDARD`. Tests also bind and compare an adoption checkpoint.

`SECURE_READY` is deliberately not claimed by default. A sealer and capability
authority may be supplied by a host, but Alchemy identity/introspection does not
grant SQL, storage, provider, legal or operational authority.

## Preserved database boundaries

This release does not alter:

- v0.76 POINT/POLYGON spatial predicates and GeoPackage WKB decoding;
- v0.75 optional TUTOR Unicode;
- v0.74 native ooRexx SQLite/GeoPackage reading;
- v0.73 explicit JSON relation projection;
- v0.72 general INNER JOIN ON predicates;
- provider-neutral federation/mutation dispatch;
- DB Core projection or SQL correctness semantics.
