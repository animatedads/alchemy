# Grok Adversarial Review Request — Virtual RYTA / Algorithm Relation v0.7

## Role

Attack this design as if it were going to become a safety-relevant read-only algorithm provider behind arbitrary SQL clients.

Do not praise the architecture unless a claim survives attack.  Identify semantic holes, races, identity mistakes, SQL planner hazards, ooRexx activity/deadlock hazards, and cases where the current tests prove less than they appear to prove.

The requested output is a machine-oriented review suitable for turning directly into v0.8 tests.

## What changed since v0.6

v0.6 eagerly materialised an Algorithm Relation and registered the result as a NoSQLServer frozen object snapshot.

v0.7 additionally exposes a generic **lazy external engine** to stock NoSQLServer v0.68:

```text
catalog / metadata
    provider invocation count = 0

first row read
    provider invocation count = 1

all later reads of all provider relations
    provider invocation count = 1
```

The external-engine instance captures source-manifest hash, canonical-input hash and a frozen execution context at construction.  Immediately before first execution it verifies that source and input identities are unchanged.

First materialisation is protected by an ooRexx object guard.  Two concurrent first readers are tested and produce one provider execution.

The same external-engine class works for RYTA and Camera v0.20.

A MySQL wire test through stock NoSQLServer v0.68 + msqlshim v0.08 proves metadata at invocation count 0 and lazy first SELECT at count 1.

## Claims to attack

For each claim return `HOLDS`, `CONDITIONAL`, or `FAILS`, with a concrete counterexample where possible.

### C1 — Catalog is observational

`readCatalog`, table discovery, table metadata, row-count estimation and MySQL `SHOW TABLES` / `SHOW COLUMNS` cannot execute an algorithm.

### C2 — Exactly-once per external-engine materialisation

Simultaneous first row readers cannot produce two provider executions.

### C3 — Cross-relation sharing

Two tables declared by one provider share one provider execution rather than materialising independently.

### C4 — Lazy input is frozen semantically

Changing the effective input after registration but before first SELECT cannot cause an unnoticed computation against a different world than the one registered/planned.

### C5 — Source identity is frozen

Changing adapter/plugin/model source identity before first read cannot be silently accepted.

### C6 — SQL rescans cannot reopen execution

Nested-loop rescans, repeated statements, joins, ORDER BY, aggregates, LIMIT, prepared statements and MySQL metadata operations cannot re-enter the provider after successful materialisation.

### C7 — No unsafe pushdown

No SQL predicate, projection, LIMIT or join condition is evaluated by the algorithm provider in v0.7.

### C8 — Host class-set injection is a safe package seam

Supplying NoSQLServer class objects explicitly is sufficient to keep the plugin independent of source paths without enabling type confusion or hostile class substitution.

### C9 — Copying cached `DatabaseRow` objects is sufficient isolation

A caller cannot mutate cached relation state through a returned row or nested value.

### C10 — Current retry behavior is safe

A failed first materialisation can be retried by a later row read because `materialized` remains false.

### C11 — Holding the object guard across provider execution is acceptable

The current implementation prevents duplicate first execution without creating unacceptable deadlock/reentrancy hazards.

### C12 — `SIDE_EFFECT_CLASS=NONE` remains necessary and sufficient for SELECT use

Identify any additional properties that a provider needs before it is safe on an arbitrary SQL read path.

### C13 — External-engine instance lifetime matches materialisation lifetime

Destroying/recreating the external-engine instance cannot accidentally violate assumptions about replay or exactly-once identity.

### C14 — In-memory result caching is honest

The design does not overclaim durability/replay across process crash or NoSQLServer restart.

### C15 — Schema cannot drift between metadata and first execution

If declared schema changes after registration but before first SELECT, the design either catches it or currently has a hole.  Be explicit.

## Specific questions

1. Should the provider's **declared schema fingerprint** be captured separately at registration and rechecked before first execution?
2. Should execution failure be sticky for the external-engine instance or automatically retryable?
3. Should materialisation state be represented as `UNMATERIALIZED / MATERIALIZING / MATERIALIZED / FAILED` rather than a Boolean?
4. Should concurrent readers wait on a separate promise/state object instead of holding the external-engine object guard across provider execution?
5. Could a provider callback or logging hook send a message back to the external-engine object and deadlock under the current guard?
6. What exact objects/collections must be deep-immutable for cached rows to be safe?
7. Is `.nil` pre-materialisation row count the correct planner signal, or should there be an explicit `UNKNOWN_CARDINALITY` capability?
8. Should a provider advertise an estimated cost/cardinality without execution, and if so how do we prevent the estimate path becoming a covert algorithm invocation?
9. Does a relation alias/binding collision create any security or catalog ambiguity?
10. What should happen if two external Algorithm Relation engines advertise the same SQL table name?
11. What must be in the source manifest for dynamic ooRexx plugins loaded after adapter construction?
12. Is canonical-input hashing enough if the input object can reference mutable external resources not serialized by `canonicalInput()`?
13. Should world-snapshot identity and canonical input hash both be mandatory rather than optional/semantic conventions?
14. Could an SQL client exploit repeated failed reads to create a denial-of-service loop against an expensive deterministic provider?
15. How should cancellation/timeouts interact with a provider currently executing under the materialisation guard?
16. What does a process crash halfway through provider execution mean for future durable materialisation?
17. For prepared statements, must materialisation identity bind at PREPARE or at EXECUTE?
18. For transactions, should an unmaterialised external relation bind its world snapshot at transaction start, statement start, engine registration, or first row read?
19. Are metadata/catalog results themselves versioned strongly enough for a long-lived prepared plan?
20. What invariants must hold before any future pushdown capability is allowed?

## Required adversarial corpus

Provide at least 35 executable test cases, including at minimum:

1. two concurrent first readers;
2. ten concurrent first readers;
3. first reader fails while second waits;
4. provider callback into external-engine object;
5. source manifest changes before first read;
6. input canonical hash changes before first read;
7. declared schema changes before first read;
8. relation disappears before first read;
9. relation added before first read;
10. output violates originally catalogued type;
11. invalid row on first execution;
12. provider returns `.nil`;
13. provider raises condition;
14. repeated failed SELECTs;
15. SQL rescan in nested-loop join;
16. same relation referenced twice in self-join;
17. two provider relations joined together;
18. aggregate over materialised relation;
19. LIMIT 0;
20. LIMIT 1;
21. impossible predicate (`WHERE 1=0`);
22. metadata-only prepared statement;
23. prepared statement executed twice;
24. two simultaneous MySQL clients;
25. `SHOW TABLES` during first materialisation;
26. `SHOW COLUMNS` during first materialisation;
27. external-engine destruction/recreation;
28. NoSQLServer transaction rollback around SELECT;
29. host passes wrong class object in class set;
30. host passes malicious substitute class;
31. SQL table-name binding collision;
32. provider table-name collision with persisted table;
33. mutable nested object in cached row;
34. cancellation/timeout during materialisation;
35. process-level restart after materialisation.

Add more where the architecture invites them.

## Required mutation catalogue

Provide at least 25 mutants and state which current/new test must kill each.  Include:

- remove `guard on`;
- set `materialized=.true` before provider returns;
- skip input-hash recheck;
- skip source-manifest recheck;
- compare the wrong hash;
- execute provider from `tableRowCount`;
- execute provider from `tableMetadata`;
- execute provider from `readCatalog`;
- push predicate into provider;
- materialise each relation separately;
- reuse rows from wrong relation key;
- expose cached row array directly;
- omit `DatabaseRow~copy` on return;
- silently coerce unsupported type;
- return zero instead of unknown row count before materialisation;
- retry forever after deterministic failure;
- cache invalid AlgorithmResult;
- ignore relation missing from output;
- accept schema drift;
- accept input object whose external referenced state changed but canonical input did not;
- allow side-effect provider on SELECT;
- bind execution identity to SQL alias rather than content;
- clear materialisation on ordinary rescan;
- create one provider execution per MySQL connection;
- let metadata access alter provider state.

## Required response structure

Return:

A. Executive finding
B. Claim-by-claim table C1-C15
C. Concurrency / exactly-once analysis
D. Lazy snapshot and transaction semantics
E. Schema/metadata drift analysis
F. Failure/retry/cancellation model
G. Side-effect eligibility model
H. NoSQLServer planner hazards
I. MySQL/protocol hazards
J. 35+ adversarial tests
K. 25+ mutation tests
L. BLOCKER / SHOULD_DO_NEXT / DEFER change list
M. Exact proposed contract language for v0.8

The goal is not additional expressiveness.  The goal is to discover whether lazy Algorithm Relations are genuinely safe to expose as ordinary SQL tables while preserving the execution barrier.
