# NoSQLServer Federated Algorithm Relation Bridge v0.5

## Status

**First SQL-facing integration candidate.**

This is deliberately not yet a new SQL syntax or native NoSQLServer planner node.
It uses the existing NoSQLServer v0.58 federated object-table surface as a safe
transport for an Algorithm Relation that has already crossed its execution /
materialization boundary.

## Why this seam first

The known v0.58 federated interface already accepts an ordinary ooRexx
collection plus an explicit `ObjectTableMapping`, then sends that table through
the same SQL SELECT / WHERE / ORDER BY / JOIN path as persisted tables.

The v0.5 bridge therefore has this shape:

```text
actual algorithm input
        |
        v
AlgorithmRelationEngine
  canonical input hash
  verified source manifest
  deterministic read gate
  provider execution at most once
        |
        v
FULL MATERIALIZED TYPED RELATION
        |
        v
immutable NoSQLAlgorithmFederatedRow[]
        |
        v
ObjectTableMapping (getters only)
        |
        v
FederatedDatabaseEngine~register(...)
        |
        v
NoSQLServerSQL
  WHERE / JOIN / ORDER BY / GROUP / LIMIT / rescan
```

The SQL engine never receives a provider callback.  It receives already
materialized immutable objects.  Consequently an SQL nested-loop rescan cannot
re-execute Virtual RYTA by construction in this bridge.

## Classes

### `.NoSQLAlgorithmFederatedRow`

A generic immutable object-row wrapper.

It copies the values of one validated `AlgorithmRow` into a private Directory.
A zero-argument transport getter message returns the frozen value.  SQL columns are mapped through a collision-safe private message namespace, for example:

```text
SQL action_code -> ALGREL_COLUMN__ACTION_CODE
SQL string      -> ALGREL_COLUMN__STRING
```

The wrapper strips `ALGREL_COLUMN__` before looking up the real declared column. This avoids collisions with inherited ooRexx methods such as `string`, `class`, or `send`, while still avoiding one generated class per Algorithm Relation schema.

Messages with arguments are rejected.  No setter is exposed.

This matters because NoSQLServer's object storage is intentionally capable of
live mutation in other use cases.  Algorithm Relation rows are a different
contract: **read-only materialized snapshots**.

### `.NoSQLServerAlgorithmRelationAdapter`

Responsibilities:

```text
describe()
    metadata-only AlgorithmReadOperator bind
    provider invocation count must remain unchanged

buildMapping()
    declared Algorithm schema -> ObjectTableMapping
    does not execute provider

materialize()
    binds every declared relation first
    crosses AlgorithmRelationEngine execution boundary once
    rejects invalid results

registerMaterialized()
    typed AlgorithmRelation -> immutable row collection
    -> FederatedDatabaseEngine~register

registerMaterializedSet()
    convenience for multiple named relations from one result
```

The adapter accepts an optional mapping-factory/class object explicitly.  The
real integration runner passes `.ObjectTableMapping`.  This avoids relying on
cross-package class-name lookup and makes the dependency visible.

### `.NoSQLAlgorithmRelationRegistration`

Keeps transport provenance:

```text
bridge_version        NOSQL-ALGREL-BRIDGE-0.5
transport_class       FEDERATED_OBJECT_SNAPSHOT
table_name
algorithm_id
algorithm_version
relation_name
materialization_id
provider_execution_id
audit_invocation_id
input_oid
world_snapshot_oid
source_manifest_hash
row_count
```

The bridge identity is intentionally separate from Algorithm Relation content
identity.  Changing the SQL transport must not make a deterministic algorithm
result pretend it was recomputed.

## Type mapping

v0.5 maps the Algorithm Relation types deliberately:

```text
TEXT       -> VARCHAR
OID        -> VARCHAR
INTEGER    -> INTEGER
NUMBER     -> DECIMAL
BOOLEAN    -> BOOLEAN
```

The Algorithm Relation type/domain validator has already accepted every row
before registration.  The NoSQL mapping is a downstream representation, not an
opportunity to silently repair invalid provider output.

## Read-only rule

The bridge provides getter messages only.

It does not:

```text
set ObjectTableMapping identity
provide setter methods
provide factories
expose INSERT/DELETE behaviour
turn SQL UPDATE into algorithm mutation
```

Identity is not required for a read-only object mapping.  If a future
NoSQLServer version requires a synthetic identity for planner purposes, that
must be added as explicit transport metadata rather than pretending an
Algorithm Relation domain column is a key.

## Rescan / planner semantics

The important distinction is:

```text
ALGORITHM RESCAN             prohibited as an implicit SQL behaviour
MATERIALIZED OBJECT RESCAN   ordinary SQL behaviour
```

After registration, SQL may reread the immutable collection as often as it
likes.  This does not consult `AlgorithmRelationEngine` and therefore cannot
increment provider invocation count.

This bridge gives strong safety for:

```text
WHERE
ORDER BY
JOIN
GROUP BY / COUNT
UNION, where supported by NoSQLServer
nested-loop rereads
repeated queries against the registered snapshot
```

because those operations are downstream of materialization.

## Freshness and lifecycle

A registered table is a specific materialized snapshot.

`FRESH` in Algorithm Relation produces a new provider execution/result.  It does
**not** silently mutate an already registered SQL table in v0.5.

The safe first rule is:

> New materialization -> new registration lifecycle.

Atomic replacement / unregister semantics belong either in a later bridge
revision after inspecting the real NoSQLServer table-registration lifecycle, or
in a native planner node.  `registerMaterializedSet()` therefore makes no
cross-table atomic-registration claim in v0.5.

## Transaction semantics

Algorithm execution occurs before object-table registration in this bridge.
No SQL transaction rollback can claim to roll back that already completed
algorithm evaluation.

For current `SIDE_EFFECT_CLASS=NONE` providers this is harmless: evaluation
created only an immutable relation.

The bridge MUST NOT be extended to side-effectful providers.  A future durable
request / agent execution surface is a different contract.

## Real v0.58 acceptance runner

Run:

```bash
cd tests
./run_nosqlserver_v058_live.sh /path/to/nosqlserver_v0.58/src/NoSQLServer.cls
```

The runner creates a real `FederatedDatabaseEngine` and `NoSQLServerSQL`, then:

1. describes RYTA metadata with zero provider invocations;
2. materializes Virtual RYTA once;
3. registers `RYTA_ACTION_DECISIONS` as `ryta_actions`;
4. registers `RYTA_DECISION_TRACE` as `ryta_trace` from the same materialization;
5. SQL-selects the `PROHIBITED` rows with `WHERE` + `ORDER BY`;
6. repeats the SQL scan and asserts provider invocation count remains 1;
7. creates a persisted `action_labels` table;
8. joins persisted data to `ryta_actions` through ordinary NoSQLServer SQL;
9. attempts SQL `UPDATE` and requires rejection with frozen rows unchanged;
10. queries the trace relation;
11. asserts the provider still executed exactly once.

## What v0.5 deliberately does not claim

- It does not add syntax such as `FROM ALGORITHM(...)`.
- It does not make NoSQLServer construct Algorithm Relation inputs.
- It does not let the planner move predicates into providers.
- It does not make Algorithm Relations writable.
- It does not provide atomic table replacement/unregister semantics.
- It does not claim a SQL transaction controls an already completed algorithm
  evaluation.
- It does not alter `msqlshim`.

## Native next step

Once the bridge passes on the actual v0.58 tree, the native planner experiment
can replace the explicit pre-registration step with a dedicated read node:

```text
ALGORITHM_RELATION_SCAN
  metadata-only bind
  freeze/build input
  execute/materialize once
  expose materialized row source
```

The semantics should remain those already proven by this bridge rather than
inventing a new execution model inside NoSQLServer.
