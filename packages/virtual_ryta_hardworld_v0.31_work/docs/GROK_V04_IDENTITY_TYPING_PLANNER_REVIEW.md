# GROK ADVERSARIAL REVIEW BRIEF — Virtual RYTA / HardWorld Algorithm Relation v0.4

## ROLE

You are the hostile semantic/planner reviewer for an ooRexx Algorithm Relation substrate.

Do not praise the implementation unless a claim survives attack.  Look for collision, stale-identity, coercion, planner, replay, manifest and determinism holes that can produce a wrong relation while all current tests still pass.

The project is intentionally **algorithm as a relation**, not LLM as a table.

## BASELINE THAT MUST NOT BE REDESIGNED AWAY

HardWorld v0.2 semantics remain frozen:

- preference score is not authority;
- `PROHIBITED` cannot be outweighed;
- `REQUIRED` cannot be suppressed by negative score;
- `UNKNOWN` and `CONFLICT` are distinct;
- approval and capability are separate from obligation;
- safety rules use named tiers and explicit override semantics.

v0.3 established typed multi-relation providers, non-executing metadata, and materialize-once behaviour.

Your job is to attack the v0.4 tightening.

## V0.4 CLAIMS TO ATTACK

### C1 — Canonical actual input defeats caller-OID aliasing

Materialization identity no longer trusts `inputOid` or `invocationId`.

```text
canonicalInputHash = SHA256(provider.canonicalInput(actualInput, context))
```

Key:

```text
algorithmId
+ algorithmVersion
+ sourceManifestHash
+ canonicalInputHash
+ worldSnapshotOid
```

Required test behaviour:

```text
same inputOid + same invocationId + changed actual content
    => cache miss / provider executes
```

Attack canonicalization ambiguity, ordering, numeric/string representation, NULL representation, duplicate rows/items, Unicode, delimiters, plugin order, approval order and mutable nested objects.

### C2 — Audit invocation is distinct from content materialization

Same canonical materialization under a new `invocationId` may reuse the cached content.

The engine creates a replay view:

```text
same materializationKey
new invocationId
INVOCATION_ID columns rebound
CACHE_REPLAY trace
provider not rerun
```

Attack whether rebinding only `INVOCATION_ID` is sufficient provenance.  Identify any columns/trace fields that should remain original-provider-execution identity versus client/audit identity.

### C3 — Source manifest replaces single-file identity

Strict providers use SHA-256 over a canonical manifest of engine/adapter/component/plugin/model fingerprints.

```text
SOURCE_MANIFEST_MODE=FILE_HASHED
```

External plugins with no manifest fingerprint make the provider `INCOMPLETE`, and the read planner refuses them.

Attack TOCTOU, symlink replacement, manifest-file omission, dynamically loaded code, model/data files, configuration not represented in either source manifest or canonical input, and whether `sha256sum`-based hashing is acceptable for the prototype contract.

### C4 — Determinism claim is narrowed

The only strict current claim is:

```text
DETERMINISTIC_GIVEN_MATERIALIZED_INPUT
```

Definition:

> identical verified source manifest + identical canonical materialized input + identical world snapshot identity => identical typed relations.

Virtual RYTA canonical input includes world facts, plugin set/config, approvals, approval-policy quorum, approval scope and capability-default policy.

Camera canonical input includes all exported condition fields and sorted metric-signal representation.

Attack hidden state not represented by those definitions.

### C5 — Provider evaluation must not mutate input

RYTA now clones the supplied world before installing capability defaults or fact-plugin contributions.

Attack shallow-copy aliasing and nested mutable objects.  State whether v0.4 needs a generic immutable-input interface rather than provider-specific cloning.

### C6 — Type/domain enforcement is real enough for SQL exposure

Declared families:

```text
TEXT
OID
INTEGER
NUMBER
BOOLEAN
```

Rules:

- every declared column must be present;
- explicit NULL differs from omitted;
- nullable controls NULL;
- no silent coercion;
- enum/domain violations reject rows;
- unknown-column writes are sticky;
- invalid/rejected rows make result invalid;
- invalid result is not cached.

Remember ooRexx scalars are string-centric.  Attack lexical edge cases: exponents, leading zeros, whitespace, NaN/Infinity-like strings, huge integers, boolean strings, empty OIDs, Unicode text, numeric precision and downstream SQL type mapping.

### C7 — Read-only planner gate is conservative

`AlgorithmRelationReadOperator` binds only providers satisfying:

```text
SIDE_EFFECT_CLASS=NONE
SOURCE_MANIFEST_MODE=FILE_HASHED
DETERMINISM=DETERMINISTIC_GIVEN_MATERIALIZED_INPUT
```

Metadata bind/explain does not invoke provider.

There is no provider pushdown API.

Execution order is:

```text
full provider materialization
-> output filters
-> projection
-> LIMIT
```

Attack whether any SQL planner rewrite can accidentally move those operations across the materialization boundary when this contract is wrapped by NoSQLServer.

### C8 — LIMIT test proves no provider LIMIT pushdown

RYTA produces seven action rows.  A read plan requesting `LIMIT 1` returns one row, then a cache inspection proves the underlying provider materialization still contains seven rows with one provider invocation.

Attack whether this is a sufficient proof or only a toy special case.

### C9 — Incomplete external plugins fail bind

An external score plugin with no `sourceManifestHash` makes RYTA manifest mode `INCOMPLETE`; read-plan bind fails with zero provider invocations.

Attack plugin substitution and fingerprint reuse.

### C10 — Side-effect classes remain separate

Current read path accepts only `NONE`.

Proposed future taxonomy:

```text
NONE
PROPOSAL_ONLY
DURABLE_REQUEST_ONLY
EXTERNAL_SIDE_EFFECT
```

Attack whether `PROPOSAL_ONLY` can truly be considered side-effect free and whether durable request creation can ever be transactional enough to appear behind SQL write semantics.

## REQUIRED RESPONSE FORMAT

Return these sections exactly:

### A. EXECUTIVE VERDICT

- READY_FOR_NOSQLSERVER_READ_EXPERIMENT: YES / CONDITIONAL / NO
- top 3 remaining blockers

### B. CONTENT IDENTITY ATTACK TABLE

Columns:

```text
CASE
CURRENT_EXPECTED_RESULT
ATTACK
FAILURE_MODE
RECOMMENDED_FIX
BLOCKING_LEVEL
```

Minimum 20 cases.

### C. CANONICALIZATION SPECIFICATION

Propose a minimal canonical serialization contract suitable for relation/object snapshots.  It must cover ordering, type tags, length framing/escaping, NULL, booleans, numbers, text/Unicode, arrays/relations, duplicate rows, OIDs and nested objects.

Do not answer "use JSON" unless you specify a canonical JSON profile precisely enough to hash independently in two implementations.

### D. SOURCE MANIFEST / MERKLE MODEL

State whether flat canonical manifest hashing is sufficient now.  If recommending Merkle structure, specify nodes/leaves and what belongs in the root.

### E. DETERMINISM AUDIT

For RYTA and Camera separately, list every state/configuration element that must be frozen or hashed for the current claim to be true.

### F. TYPE CONTRACT ATTACK

Minimum 20 type/domain edge cases, with expected accept/reject outcome.

### G. REPLAY / AUDIT IDENTITY MODEL

Decide whether these identities are sufficient and how they should relate:

```text
materialization_id
provider_execution_id
audit_invocation_id
input_snapshot_id
world_snapshot_id
```

Explicitly address replay-view rebinding.

### H. PLANNER BOUNDARY ATTACK

Minimum 15 SQL/planner scenarios including:

- repeated CTE;
- nested loop;
- LIMIT;
- ORDER BY;
- GROUP BY;
- COUNT(*);
- LEFT JOIN;
- UNION;
- correlated input;
- EXPLAIN;
- failed query after materialization;
- transaction rollback;
- prepared statement reuse;
- parallel plan attempt;
- optimizer plan cache reuse.

For each, say which side of the Algorithm Relation execution barrier each operation is allowed to occur.

### I. MUTATION SUITE

Propose at least 25 new v0.4 mutants.  Include identity, manifest, canonicalization, type checking, invalid-result caching, replay rebinding and planner-boundary mutants.

### J. ADVERSARIAL CORPUS

Propose at least 30 executable v0.4 cases beyond the existing HardWorld corpus.

### K. V0.5 RECOMMENDATION

Classify each suggestion:

```text
BLOCKER_BEFORE_NOSQLSERVER
SHOULD_DO_DURING_FIRST_NOSQLSERVER_ADAPTER
DEFER
REJECT
```

## DESIGN TEST

Your proposed contract must answer this mechanically:

```text
1. Provider source files/model/plugin set are identical.
2. Caller reuses inputOid="X" and invocationId="I".
3. One actual input fact changes.
4. The second query is otherwise textually identical.
```

Required outcome:

```text
canonicalInputHash changes
materializationKey changes
provider executes again
old materialization remains intact
```

Then:

```text
5. A third query uses the original actual input again but invocationId="J".
```

Required outcome:

```text
canonicalInputHash equals original
materializationKey equals original
provider does not execute again
returned audit view says invocationId="J"
provider-execution provenance still identifies the original execution
```

v0.4 now carries an explicit `providerExecutionId`; attack whether its lifecycle and replay preservation are sufficient to prove the final line.
