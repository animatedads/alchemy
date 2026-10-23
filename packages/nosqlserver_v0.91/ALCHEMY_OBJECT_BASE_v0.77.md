# NoSQLServer v0.77 Alchemy Object boundary

## Purpose

v0.77 adopts `AlchemyObject` where an object represents a long-lived service,
execution authority boundary or observable engine lifecycle. It deliberately
does not turn relational values into managed objects merely because a common
base exists.

## Derived service objects

`NoSQLAlchemyObject` is the NoSQL-specific intermediate base. These public
service classes derive through it:

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

The base contributes identity, lifecycle/use telemetry, requirements, method
contracts, instrumentation and optional sealed/security surfaces. NoSQL adds
product/package/role metadata and service-use instrumentation.

## Objects intentionally not migrated

Rows, values, column definitions, predicate/expression objects, parser tokens,
geometry objects and other hot-path data remain ordinary lightweight objects.
They have data identity/semantics, not independent service lifecycle or
security authority. Migrating them would add telemetry/security overhead at the
wrong abstraction layer.

## Configuration propagation

Existing constructor signatures remain source compatible because optional
Alchemy sealer/authority parameters are appended. If supplied at a File or
Federated engine boundary they propagate to service children created by that
engine. If omitted, security/sealing remains unconfigured exactly as before.

NoSQL does not automatically claim `ALCHEMY-HOUSE-OBJECT-0.4` compliance. The
base is available; compliance must be assessed and asserted separately.

## Shared dependency

`NoSQLServer.cls` has `::requires "AlchemyObject.cls"`, so Alchemy Objects
v0.4.4 must be on the ooRexx package resolution path before this class loads.
Alchemy Objects itself consumes `crypto.cls` from `oorexx_crypto_v0.1`.
NoSQLServer vendors neither dependency.

Example:

```sh
export REXX_PATH=/opt/alchemy_objects_v0.4.4/src:/opt/oorexx_crypto_v0.1/src
rexx application.rex
```

The optional TUTOR Unicode provider remains independent of this requirement.

## Descendant-name collision exposed by this integration

The first integration attempt exposed a universal-base defect in Alchemy
Objects v0.4.3: base initialization asked `self~VERSION` / `self~SCHEMA` for
house constants. `NoSQLServerSQL` legitimately has a business `version()`
method, so descendant virtual dispatch intercepted base initialization before
the SQL executor's engine attribute had been assigned.

The correction belongs in the base, not in NoSQLServer. Alchemy Objects v0.4.4
uses `.AlchemyObject~VERSION` and `.AlchemyObject~SCHEMA` explicitly and carries
a permanent descendant-name-collision regression.
