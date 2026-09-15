# GROK ADVERSARIAL REVIEW BRIEF — Algorithm Relation / NoSQLServer bridge v0.5

## ROLE

You are reviewing the first SQL-facing bridge for the ooRexx Algorithm Relation
substrate.  Be hostile to accidental execution, stale registrations, mutation,
identity aliasing and SQL/planner semantics.  Do not redesign HardWorld or
replace deterministic rules with an LLM.

The question is narrow:

> Is it semantically safe to expose a *previously materialized* Algorithm
> Relation to NoSQLServer v0.58 through its existing federated object-table
> backend before implementing a native Algorithm Relation planner node?

## BASELINE THAT MUST SURVIVE

HardWorld v0.2 and Algorithm Relation v0.4 semantics are unchanged:

```text
score != authority
PROHIBITED cannot be outweighed
REQUIRED cannot be suppressed by score
UNKNOWN != FALSE
CONFLICT != UNKNOWN
approval != score
capability != obligation
SIDE_EFFECT_CLASS must be NONE for SELECT-like reads
metadata cannot execute provider
materialization identity is content-addressed
provider execution identity != audit invocation identity
invalid typed results are never cached
```

## V0.5 BRIDGE SHAPE

```text
input
  -> AlgorithmRelationEngine materializes FULL typed result
  -> immutable NoSQLAlgorithmFederatedRow objects
  -> ObjectTableMapping (getter only)
  -> FederatedDatabaseEngine~register
  -> ordinary NoSQLServer SQL reads
```

NoSQLServer receives no algorithm callback.

The bridge relies on the existing v0.58 API:

```text
FederatedDatabaseEngine~new(root)
ObjectTableMapping~new(table)
mapping~column(sql_name, sql_type, getter_message)
fed~register(table, object_collection, mapping)
NoSQLServerSQL~new(fed)
```

## CLAIMS TO ATTACK

### C1 — execution barrier is structural

After `register`, SQL only reads immutable wrapper objects.  No SQL rescan path
has an object/reference capable of evaluating the provider.

Attack:

- nested-loop joins;
- repeated queries;
- CTE/repeated reference;
- ORDER BY / GROUP BY / COUNT;
- failure/retry inside NoSQLServer;
- prepared statement reuse;
- msqlshim clients issuing the same SELECT repeatedly.

Can any of those cause provider execution in this bridge?

### C2 — metadata remains pure

`buildMapping()` starts from Algorithm Relation declared schema and uses the
v0.4 read-operator bind checks.  It must not evaluate the provider.

Attack cross-package class lookup, dynamic schema methods and schema drift
between mapping creation and provider materialization.

### C3 — SQL rows are immutable snapshots

`NoSQLAlgorithmFederatedRow` copies validated values and implements zero-arg
getters through `UNKNOWN`.  Messages with arguments raise an error.  Mapping
contains no setter/factory/identity mutation contract.

Attack:

- SQL UPDATE;
- setter naming variants;
- direct ooRexx mutation attempts;
- mutable object values stored inside a cell;
- nullable `.nil` values;
- getter name collisions with inherited Object methods;
- malicious schema column named `STRING`, `CLASS`, `UNKNOWN`, `SEND`, etc.

Identify which column names must be reserved/rejected before production.

### C4 — transport provenance is distinct

Registration records:

```text
bridge_version = NOSQL-ALGREL-BRIDGE-0.5
transport_class = FEDERATED_OBJECT_SNAPSHOT
materialization_id
provider_execution_id
audit_invocation_id
input_oid
world_snapshot_oid
source_manifest_hash
```

The bridge version is not part of algorithm materialization identity.

Attack whether this separation is correct and what SQL-visible provenance is
required.

### C5 — type mapping is honest enough

```text
TEXT -> VARCHAR
OID -> VARCHAR
INTEGER -> INTEGER
NUMBER -> DECIMAL
BOOLEAN -> BOOLEAN
```

The upstream Algorithm Relation validator is authoritative.  NoSQLServer may
coerce to its native representation but may not repair rejected data.

Attack precision, `.true/.false`, NULL, OID collation, VARCHAR length,
DECIMAL scale and any v0.58 type mismatch.

### C6 — no synthetic identity in v0.5

The object-table design defines identity as optional and primarily required for
mutation.  Algorithm Relation registration is SELECT-only and therefore does
not invent a domain identity.

Attack whether v0.58 SELECT/index/planner code in fact requires identity.  If a
synthetic row identity is necessary, specify a safe deterministic transport key
that cannot be confused with a provider/domain key.

### C7 — registration freshness is explicit

A SQL table registration is one frozen materialization.  `FRESH` creates a new
Algorithm Relation result but does not silently mutate that registration.

Attack stale-table use, table-name reuse, concurrent readers, replacement and
TOCTOU between materialization and registration.

### C8 — multi-relation registration is not claimed atomic

`registerMaterializedSet()` is a convenience.  v0.5 does not claim that
registering `ryta_actions` and `ryta_trace` is atomic across both table names.

Recommend the smallest safe lifecycle contract for v0.6/native integration.

### C9 — SQL transaction boundary is honest

Algorithm evaluation has already completed before registration.  SQL rollback
does not roll it back.  Current providers are `SIDE_EFFECT_CLASS=NONE` so the
only artifact is an immutable relation.

Attack whether this remains safe under transaction snapshots and whether the
native planner node must bind algorithm materialization to query/transaction
lifetime.

### C10 — msqlshim remains ignorant

If the federated relation is an ordinary NoSQLServer table, msqlshim should only
see SQL metadata/rows.  It must not learn about provider classes, getters or
HardWorld.

Attack metadata leakage or wire-protocol assumptions.

## REQUIRED REAL ACCEPTANCE TEST TO REVIEW

`tests/run_nosqlserver_v058_live.sh` is expected to prove against actual v0.58:

```text
metadata -> 0 provider calls
materialize RYTA -> 1 provider call
register actions + trace -> still 1
SQL WHERE + ORDER BY -> still 1
repeat SQL scan -> still 1
persisted-table JOIN algorithm table -> still 1
trace SQL query -> still 1
```

Review whether this test is sufficient and add cases that are missing.

## REQUIRED RESPONSE FORMAT

Return exactly these sections.

### A. EXECUTIVE VERDICT

```text
FEDERATED_BRIDGE_SAFE_AS_READ_EXPERIMENT: YES / CONDITIONAL / NO
READY_FOR_NATIVE_PLANNER_NODE: YES / CONDITIONAL / NO
```

Name the top three remaining semantic risks.

### B. OBJECT-WRAPPER ATTACK TABLE

At least 20 cases. Columns:

```text
CASE
ATTACK
EXPECTED_SAFE_RESULT
CURRENT_DETECTOR
RECOMMENDED_CHANGE
SEVERITY
```

### C. REGISTRATION LIFECYCLE MODEL

Define:

```text
CREATE
READ
REPLAY
FRESH
REPLACE
UNREGISTER
EXPIRE
CONCURRENT_READ
```

and state which belong in v0.5, v0.6 or native planner only.

### D. SQL TRANSFORMATION TABLE

At least 20 scenarios including:

```text
WHERE
projection
LIMIT
ORDER BY
GROUP BY
COUNT
DISTINCT
UNION
LEFT JOIN
INNER JOIN
nested loop
subquery
CTE referenced twice
correlated subquery
prepared statement reuse
transaction retry
transaction rollback
EXPLAIN
msqlshim repeated query
parallel read
```

For each, state whether provider execution is possible in the v0.5 bridge and
whether native integration needs an explicit barrier rule.

### E. COLUMN-NAME / OBJECT-MESSAGE SAFETY

Attack use of `UNKNOWN` as generic getter transport.  Produce a reserved-name or
safe-name strategy covering inherited Object methods and setter-like names.

### F. TYPE / NULL MAPPING ATTACK

At least 15 cases covering all five Algorithm Relation types and NULL.

### G. PROVENANCE EXPOSURE

State which provenance fields should be queryable as:

- ordinary relation columns;
- a system/catalog relation;
- audit-only registration metadata.

### H. MUTATION CATALOG

At least 20 v0.5 mutants. Include:

```text
make wrapper writable
call provider during buildMapping
register pre-materialization input rather than result
re-materialize on every SQL scan
change NUMBER->VARCHAR
remove source manifest from registration provenance
reuse old registration after FRESH without explicit lifecycle event
permit SIDE_EFFECT_CLASS != NONE
silently invent identity from row ordinal
allow partial multi-relation registration to claim atomic success
```

### I. ADVERSARIAL CORPUS

At least 25 executable cases for the bridge/native handoff.

### J. V0.6 / NATIVE PLAN

Classify each recommendation:

```text
BLOCKER_BEFORE_REAL_V058_ACCEPTANCE
BLOCKER_BEFORE_NATIVE_PLANNER_NODE
SHOULD_DO_IN_NATIVE_NODE
DEFER
REJECT
```

## DESIGN TEST

A correct answer must mechanically preserve:

```text
Virtual RYTA provider invocation count = 1

while NoSQLServer performs:
  first SELECT
  repeated SELECT
  JOIN against persisted table
  sort/filter/aggregate over the registered table
```

If your proposal requires re-running RYTA to satisfy any of those SQL reads,
it violates the bridge contract.
