# GROK REVIEW BRIEF — Algorithm Relation v0.3

## ROLE

You are reviewing an executable ooRexx testbed for a generic **Algorithm Relation** abstraction.  This is an adversarial semantic and architecture review, not a request for praise.

The previous HardWorld review led to named precedence tiers, explicit override edges, strict epistemic predicates, stronger approval binding, capability/obligation separation, rules-and-holes coverage, adversarial cases and mutation testing.

v0.3 now generalises execution so Virtual RYTA and an external deterministic Camera v0.20 condition classifier can both appear as typed relation providers.

## FILES TO READ

Read these before answering:

1. `docs/ALGORITHM_RELATION_CONTRACT.md`
2. `docs/NOSQLSERVER_ADAPTER_PLAN.md`
3. `algorithm/AlgorithmRelation.cls`
4. `algorithm/RYTAAlgorithmProvider.cls`
5. `integration/CameraCurrentConditionAlgorithmProvider.cls`
6. `tests/test_algorithm_relation_core.rex`
7. `tests/test_algorithm_relation_ryta.rex`
8. `tests/test_algorithm_relation_camera_integration.rex`
9. `ALGORITHM_RELATION_DEMO_OUTPUT.txt`
10. the existing HardWorld v0.2 rule-language/coverage documents

## CURRENT CLAIMS YOU MUST TRY TO BREAK

C1. Provider/schema catalog discovery cannot invoke the algorithm.

C2. One logical invocation under `MATERIALIZE_ONCE` executes a provider at most once.

C3. A SQL-style rescan/read cannot imply fresh computation.

C4. Adapter version, source version and source fingerprint participate in materialization identity.

C5. Provider-specific typed relations are preferable to a universal EAV schema.

C6. Unknown-column writes and rejected rows cannot silently disappear behind a "valid" result.

C7. RYTA and Camera can share the Algorithm Relation envelope without sharing domain semantics.

C8. The current contract is safe to expose to a NoSQLServer planner provided NoSQLServer supplies a real immutable input relation OID.

C9. `SIDE_EFFECT_CLASS=NONE` is sufficient for these v0.3 providers; side-effectful agent/tool providers should be a separate later contract.

C10. `DETERMINISTIC_SNAPSHOT` is an honest classification for the tested RYTA/Camera executions when model/source and input snapshots are fixed.

## ATTACK SURFACE

You MUST analyse at least the following.

### A. Invocation identity

- Can two semantically different inputs collide under one `inputOid`?
- Should `invocationId` be part of cache identity, or should materialization be content-addressed independently from invocation identity?
- Should replay identity and execution identity be distinct?
- What happens if the same invocation ID is reused after a source/model update?
- Is adapter version + source version + source fingerprint sufficient?
- Should rule/model hash, plugin set/hash, configuration and parameters be independent key fields?

### B. Input snapshot binding

- RYTA has an intrinsic `world~snapshotOid`; CameraCurrentCondition currently relies on caller-bound identity.
- Define the minimum trustworthy input-binding contract.
- Decide whether `CALLER_BOUND` inputs should be accepted at all in production.
- Propose fail-closed behaviour when the adapter can derive an input identity and it disagrees with the supplied identity.

### C. Materialize-once semantics

Attack:

- nested-loop rescans;
- CTE referenced twice;
- correlated subqueries;
- parallel plans;
- retry after transient failure;
- query cancellation;
- process crash during materialization;
- partial relation production;
- provider returns rows then throws;
- explicit `FRESH` using same invocation ID;
- cache eviction and replay;
- transaction rollback.

State what must be guaranteed by the provider engine versus NoSQLServer.

### D. Catalog / EXPLAIN purity

- Is calling `declaredSchemas()` necessarily side-effect free?
- Should provider metadata be immutable data rather than executable methods?
- How should schema versioning work?
- What if the declared schema changes between planning and execution?
- Should a schema hash be bound into the planned invocation?

### E. Type contract

v0.3 validates structural columns but does not fully enforce `INTEGER`, `NUMBER`, `BOOLEAN`, `OID`, `TEXT` types.

Define:

- minimum v0.4 type checks;
- coercion policy;
- overflow/range behaviour;
- NULL handling;
- domain/enumeration constraints;
- whether providers may omit nullable columns versus explicitly write NULL;
- schema evolution compatibility.

### F. Determinism claim

Define exactly what `DETERMINISTIC_SNAPSHOT` must mean.

For Camera, consider whether the result depends only on the supplied `CameraCurrentCondition` object or also on hidden mutable model state before that object was constructed.

For RYTA, consider plugin ordering, approval set mutation, capability defaults and model/plugin hashes.

Should the class be renamed to `DETERMINISTIC_GIVEN_MATERIALIZED_INPUT`?

### G. Source fingerprints

- Is SHA-256 of one source file sufficient for Camera?
- Should fingerprint be package-manifest hash, code hash, model-data hash, config hash, or a Merkle root over dependencies?
- How should dynamically loaded `.cls` plugins participate?
- What is the minimum viable provenance key?

### H. Side effects and future agents

The current providers declare NONE.

Propose a future taxonomy, but do not weaken v0.3.  Candidate distinctions might include:

```text
NONE
PROPOSAL_ONLY
DURABLE_REQUEST_ONLY
EXTERNAL_SIDE_EFFECT
```

Decide whether any side-effect class beyond NONE should ever be legal behind a SELECT-like Algorithm Relation operator.

### I. Planner pushdown

Define what ordinary SQL operations may safely be pushed before or after an Algorithm Relation.

Consider:

- row-fed versus relation-fed algorithms;
- LIMIT pushdown;
- projection pruning;
- predicate pushdown;
- join reordering;
- aggregation;
- repeated relation references.

Identify transformations that are semantically illegal even if they are normally legal for relational tables.

### J. Rules-and-holes equivalent for Algorithm Relations

Design a coverage taxonomy comparable to HardWorld C1-C16.

At minimum include holes for:

- unbound input identity;
- missing source fingerprint;
- schema drift;
- undeclared column;
- rejected row;
- materialization duplication;
- stale replay;
- adapter/source version collision;
- metadata execution;
- partial materialization;
- nondeterminism under deterministic declaration;
- planner illegal rescan;
- cache poisoning/aliasing.

## REQUIRED NEW TESTS

Produce at least:

- 25 adversarial cases; and
- 20 mutation operators.

Each must state:

```text
ID
mutation/input
expected detection
layer responsible
severity
```

Examples you MUST include but not merely repeat:

1. Remove source fingerprint from cache key.
2. Return a schema different from declared schema at execution.
3. `declaredSchemas()` increments provider invocation counter.
4. Same input OID, changed input payload.
5. Same invocation ID, changed model hash.
6. Provider emits one valid row then one malformed row.
7. Provider executes twice during a nested-loop rescan.
8. `FRESH` call accidentally returns old cache.
9. Planner calls evaluate during EXPLAIN.
10. Camera adapter supplied wrong source fingerprint.

## REQUIRED OUTPUT FORMAT

Return exactly these sections:

A. EXECUTIVE FINDING

B. BLOCKERS BEFORE NOSQLSERVER INTEGRATION

C. INVOCATION / MATERIALIZATION IDENTITY MODEL

D. INPUT SNAPSHOT BINDING MODEL

E. PROVIDER METADATA / SCHEMA CONTRACT

F. TYPE AND NULL SEMANTICS

G. DETERMINISM TAXONOMY

H. SOURCE / PLUGIN FINGERPRINT MODEL

I. PLANNER TRANSFORMATION TABLE

J. SIDE-EFFECT TAXONOMY

K. ALGORITHM-RELATION RULES-AND-HOLES TAXONOMY

L. ADVERSARIAL CORPUS (>=25)

M. MUTATION CATALOG (>=20)

N. PROPOSED CHANGES TO v0.3

O. QUESTIONS THAT MUST BE ANSWERED BEFORE NOSQLSERVER MERGE

Do not propose an LLM to solve semantic uncertainty.  This review concerns hard execution contracts, provenance, decision machinery and planner behaviour.
