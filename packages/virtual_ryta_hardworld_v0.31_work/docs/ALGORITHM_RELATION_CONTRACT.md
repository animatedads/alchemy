# Algorithm Relation Contract — v0.4 candidate

## 1. Scope

An Algorithm Relation is a versioned computation that consumes a declared, materialized input and returns one or more typed relations.

It is broader than AI.  Current examples are:

- HardWorld / Virtual RYTA deterministic decision authority;
- Camera v0.20 deterministic current-condition categorization.

Future categorisers, scoring matrices, state machines and learned models can implement the same envelope without sharing domain schemas.

## 2. Provider declaration

A v0.4 provider SHALL expose without invoking its algorithm:

```text
algorithmId
algorithmVersion
sourceComponent
sourceVersion
sourceFingerprint
sourceManifestHash
sourceManifestMode
determinism
sideEffectClass
defaultMaterializePolicy
inputContract
declaredSchemas
canonicalInput(input, context)
```

Metadata methods MUST NOT call `evaluate`.

## 3. Source identity

`sourceFingerprint` remains the domain/model fingerprint.  It is not the complete executable identity.

`sourceManifestHash` is SHA-256 over a canonical source manifest containing the relevant adapter/engine/component/plugin/model fingerprints.

Strict SQL read-path eligibility requires:

```text
sourceManifestMode = FILE_HASHED
```

An unbound or incomplete external plugin/source must make the manifest non-strict and therefore ineligible for the v0.4 planner read operator.

## 4. Canonical input identity

The provider is responsible for producing a canonical representation of every input that can affect its returned relations.

The engine computes:

```text
canonicalInputHash = SHA256(provider.canonicalInput(...))
```

Caller-controlled aliases such as `inputOid` and `invocationId` are not sufficient cache identities.

For Virtual RYTA the canonical representation includes world facts, plugin set/configuration, approval set/state, approval-policy quorum/configuration, approval scope, and capability-default policy identity.

For the CameraCurrentCondition adapter the canonical representation includes all exported condition fields and a name-sorted representation of metric signals.

## 5. Materialization identity

v0.4 materialization key:

```text
algorithmId
| algorithmVersion
| sourceManifestHash
| canonicalInputHash
| worldSnapshotOid-or-no-snapshot-token
```

Explicitly excluded as primary content identity:

```text
invocationId
inputOid
requestedBy
```

Those remain audit/provenance fields.

### Required behaviours

1. Identical caller IDs with different canonical content MUST NOT collide.
2. Identical canonical content under a different audit invocation MAY reuse the materialization.
3. A reused materialization MUST return an audit view whose `INVOCATION_ID` columns are rebound to the requesting invocation.
4. Re-reading the same audit invocation MUST return the same cached view object.
5. `FRESH` MUST bypass the cache and invoke the provider again.
6. Invalid provider output MUST NOT enter the cache.

## 6. Determinism

Accepted strict declaration:

```text
DETERMINISTIC_GIVEN_MATERIALIZED_INPUT
```

Exact meaning:

> Given the identical verified source manifest, algorithm version, canonical materialized input and world snapshot identity where applicable, the provider returns identical typed relations.

A provider with unverified/incomplete source identity must not claim the strict form through the v0.4 read path.

## 7. Input immutability

The provider MUST NOT mutate its materialized input merely by being evaluated as a read source.

The RYTA adapter therefore clones `RYTAWorldState` before Virtual RYTA installs testbed capability defaults or fact-plugin contributions.

Any learning/model update belongs to a separate transaction or algorithm contract.

## 8. Typed relation contract

Allowed v0.4 declared scalar families:

```text
TEXT
OID
INTEGER
NUMBER
BOOLEAN
```

The validator also permits a column to declare an explicit finite domain.

### NULL and omission

Every declared column must be written for every accepted row.

```text
omitted column  -> MISSING_COLUMN
explicit .nil   -> SQL-like NULL candidate
```

`.nil` is accepted only if the column is nullable.

### No silent coercion

The validator checks the supplied ooRexx scalar representation; it does not coerce text between type families.

Examples:

```text
INTEGER: datatype(value,'W') must hold
NUMBER:  datatype(value,'N') must hold
BOOLEAN: value must be ooRexx true/false representation
OID:     non-empty string
TEXT:    string object
```

This is lexical typing appropriate to ooRexx, not a claim that ooRexx scalars secretly have SQL-native runtime classes.

### Sticky failures

- unknown-column writes remain row errors;
- type/domain/null/omission failures reject the row;
- rejected-row errors remain attached to the relation;
- result validation surfaces them;
- invalid results are returned for audit but never cached.

## 9. Side-effect taxonomy

Current executable providers:

```text
NONE
```

Reserved future taxonomy for design review:

```text
NONE
PROPOSAL_ONLY
DURABLE_REQUEST_ONLY
EXTERNAL_SIDE_EFFECT
```

The v0.4 SELECT/read operator accepts only `NONE`.

`EXTERNAL_SIDE_EFFECT` must never become executable behind an ordinary SQL read path.

## 10. Planner read contract

`AlgorithmRelationReadOperator` is deliberately conservative.

Bind/describe/explain:

- read only provider metadata/schema;
- never invoke the provider;
- reject non-`NONE` side-effect class;
- reject non-file-hashed source identity;
- reject non-strict determinism declaration;
- validate projection columns from metadata.

Execution order:

```text
1. execute/materialize provider once
2. obtain named relation
3. apply predicates to materialized rows
4. project requested columns
5. apply LIMIT to output
```

v0.4 has no provider predicate/projection/LIMIT pushdown API.

Pushdown can only be added later as an explicit provider capability with separate semantic tests.

## 11. Planner-safe and planner-unsafe operations

Safe after materialization:

```text
projection
filter on declared output column
ORDER/GROUP operations implemented by SQL layer
LIMIT
reread/rescan
```

Not permitted in v0.4:

```text
predicate push into provider
LIMIT push into provider
projection-driven provider execution changes
metadata-triggered execution
SELECT-triggered external side effects
```

## 12. Audit identity versus content identity

A cache hit under a new `invocationId` is not pretending the invocation never happened.

The engine produces an audit-rebound result view:

```text
same materializationKey / materializationId
same providerExecutionId
new invocationId
INVOCATION_ID columns rebound
CACHE_REPLAY trace entry
provider invocation count unchanged
```

This distinguishes:

```text
materializationId      content identity
providerExecutionId    actual provider evaluation
invocationId           client/audit invocation
inputOid               host provenance label
worldSnapshotOid       frozen-world identity
```

which were conflated in v0.3.

## v0.14 table-fed consistency identity

For providers which consume `AlgorithmInputRelationSnapshot`, the provider canonical input must use the snapshot's `algorithmCanonicalText`, not its content-only canonical text. The algorithm canonical form includes the independent consistency descriptor/hash.

This is intentional:

```text
contentHash      = what typed relation was captured
consistencyHash  = what temporal/snapshot evidence accompanied that capture
materialization  = provider/model identity + both semantic input dimensions
```

A provider may declare a minimum input consistency grade. Insufficient consistency is a decision precondition failure; it must not be represented as an ordinary preference-score adjustment.

See `ALGORITHM_INPUT_CONSISTENCY_V0.14.md`.
