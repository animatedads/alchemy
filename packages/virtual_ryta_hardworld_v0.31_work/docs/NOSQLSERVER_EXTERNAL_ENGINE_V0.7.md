# NoSQLServer v0.68 Lazy Algorithm Relation External Engine

## Purpose

v0.7 is the first integration in which Algorithm Relations participate in NoSQLServer through its native **external engine** federation contract, without first manually registering a frozen object snapshot and without changing NoSQLServer core.

The eager v0.6 snapshot bridge remains valid; v0.7 adds a lazy alternative.

## Host topology

```text
FederatedDatabaseEngine
    FILE engine
    OBJECT/SNAPSHOT engine
    external engines
        GeoPackage
        Algorithm Relation external engine
            VIRTUAL_RYTA
            CAMERA_CURRENT_CONDITION
            future providers
```

NoSQLServer owns table discovery and SQL.  The external engine owns the one-time transition from algorithm definition to materialised result.

## Host-supplied class set

Because ooRexx package class environments are not a Java-style global namespace, the external-engine package does not assume that loading `NoSQLServer.cls` in a caller makes `.TableDefinition`, `.DatabaseRow`, or `.DatabaseResult` directly resolvable inside another package.

The NoSQLServer host therefore supplies those class objects explicitly:

```text
TABLE_DEFINITION
DATABASE_ROW
DATABASE_RESULT
```

This is dependency injection across the package boundary, not source copying.

## Lifecycle

### Registration / metadata phase

At construction the adapter:

1. resolves the Algorithm Relation provider;
2. freezes an `AlgorithmExecutionContext`;
3. records the provider source-manifest hash;
4. obtains the provider's canonical input representation and hashes it;
5. asks the Algorithm Relation read operator to describe declared schemas;
6. creates native NoSQLServer table definitions.

The provider algorithm is **not executed**.

These operations remain observational:

```text
readCatalog
tableNames
table
tableMetadata
tableRowCount before materialisation
SHOW TABLES
SHOW COLUMNS
```

Before materialisation, exact row count is deliberately `.nil` rather than guessed by executing the algorithm.

### First row read

`readRows` calls `ensureMaterialized`.

The one-time transition is guarded with ooRexx `guard on` so simultaneous first readers cannot both enter the provider.

Before execution the adapter verifies:

```text
current sourceManifestHash == registration sourceManifestHash
current canonicalInputHash == registration canonicalInputHash
```

Failure is fail-closed and occurs before provider execution.

If both identities remain valid, the adapter calls the normal content-addressed `AlgorithmRelationEngine~execute` once and validates the result.

### Conversion

Each declared Algorithm Relation type maps to a native NoSQLServer type:

```text
TEXT     -> VARCHAR
OID      -> VARCHAR
INTEGER  -> INTEGER
NUMBER   -> DECIMAL
BOOLEAN  -> BOOLEAN
```

The full relation is converted to native `DatabaseRow` objects and cached by relation name.

### Subsequent row reads

Rows are copied from the cached native result.  The provider is not re-entered.

Multiple relations declared by one provider share the same `AlgorithmResult`, so reading `RYTA_DECISION_TRACE` after `RYTA_ACTION_DECISIONS` does not execute RYTA again.

## No pushdown

v0.7 does not expose an algorithm predicate interface.

`selectWhere` always:

1. obtains all rows from the materialised Algorithm Relation;
2. applies the NoSQLServer predicate afterward;
3. reports `ALGORITHM_RELATION_MATERIALIZED_SCAN`.

Projection, join, sort, aggregate and LIMIT similarly remain SQL-side operations unless a future provider explicitly advertises a separately reviewed pushdown capability.

## Concurrency

Two simultaneous first readers are tested with two ooRexx activities.  Both receive the same complete RYTA relation while the provider invocation count remains one.

The current guard spans provider execution.  A provider used by this read-only contract therefore **must not callback into the same external-engine object** during execution.  Whether a future implementation should use a separate materialisation-state object/promise is intentionally left open for review.

## Failure and retry semantics

Current v0.7 behavior:

- successful materialisation is sticky for the external-engine instance;
- input/source drift before first materialisation fails closed;
- an execution/validation failure is not marked materialised;
- a later read can therefore retry after a non-materialised failure.

This retry behavior is explicitly included in the v0.7 Grok review because production policy may prefer sticky failure by execution identity rather than implicit retry.

## Side effects

The integration is intended for providers acceptable on a SQL read path.  Current RYTA and Camera providers are `SIDE_EFFECT_CLASS=NONE`.

The broader accepted direction remains:

```text
NONE
PROPOSAL_ONLY
DURABLE_REQUEST_ONLY
EXTERNAL_SIDE_EFFECT
```

`EXTERNAL_SIDE_EFFECT` must never be legal behind an ordinary SELECT-style operator.

## Validation

The same generic external-engine class has been exercised with:

### Virtual RYTA

- catalog/schema: zero provider executions;
- first SQL read: one execution;
- second relation/rescan/persisted join: still one;
- input mutation before first read: rejected before provider execution;
- concurrent first reads: exactly one provider execution.

### Camera v0.20

- catalog/schema: zero provider executions;
- first condition-table read: one execution;
- signal-table read and persisted label join: still one;
- input mutation before first read: rejected before provider execution.

### MySQL wire

With stock NoSQLServer v0.68 and msqlshim v0.08:

- `SHOW TABLES` and `SHOW COLUMNS`: zero provider executions;
- first `SELECT`: one execution;
- repeated SELECT, join and trace relation: still one execution.

No Algorithm Relation code is required in msqlshim.
