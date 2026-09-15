# NoSQLServer v0.71 external relation mutation compatibility

## Problem found after v0.70

The federation read path and metadata path were provider-neutral, but the
mutation path was not.

Before v0.71 the effective routing rule was:

```
OBJECT table -> ObjectDatabaseEngine
anything else -> FileDatabaseEngine
```

That was observable with the stock Virtual RYTA / HardWorld v0.11 external
Algorithm Relation.  The relation was present in the federated catalog and
could be queried normally, yet:

```
UPDATE ryta_actions ...
```

returned:

```
NOTFOUND | Table not found: ryta_actions
```

The error came from `FileDatabaseEngine`, not from the actual relation owner.
No algorithm provider execution occurred, but the diagnostic and abstraction
boundary were wrong.

## v0.71 rule

`FederatedDatabaseEngine` now resolves the table owner first using ordinary
federation precedence:

```
OBJECT -> FILE -> registered external engines
```

For a table-scoped operation:

1. no owner -> `NOTFOUND`;
2. owner lacks the requested operation -> `SQLUNSUPPORTED`;
3. owner implements the operation -> delegate normally.

The rule applies without tests for GeoPackage, Camera, Librarian, Algorithm
Relation, or any other provider identity.

## Read-only Algorithm Relations

Virtual RYTA / HardWorld v0.11 does not expose `updateWhere`, `insert`,
`insertMany`, or `deleteWhere`.  It therefore remains read-only through SQL,
but the rejection now represents the actual capability boundary:

```
SQLUNSUPPORTED | Table provider does not support UPDATE: ryta_actions
```

Metadata/catalog access remains observational and does not execute the
provider.  First row read materializes once; rescans and joins reuse the frozen
materialization.

## Writable external providers

v0.71 does not define a new provider-specific mutation API.  A writable
external engine can implement the same messages already used by FILE and
OBJECT engines:

```
insert(tableName, values)
insertMany(tableName, rows)
updateWhere(tableName, predicate, assignments)
deleteWhere(tableName, predicate)
```

The shipped v0.71 regression uses an independent helper package to prove all
four routes are reachable without adding provider-specific code to
NoSQLServer.

## What v0.71 does not claim

- Algorithm Relations have not become writable.
- GeoPackage has not become writable.
- No transaction model is invented for external providers.
- No external DDL ownership mechanism is introduced; CREATE/DROP remain the
  persistent FILE database surface.
- No Camera or Librarian semantics are interpreted by NoSQLServer.
- No spatial predicate capability is added.

The change is only the federation ownership/capability boundary.
