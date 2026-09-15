# Virtual RYTA / HardWorld v0.4 Design

## Architectural statement

The generic primitive is **Algorithm Relation**:

```text
typed materialized input
        |
        v
versioned algorithm provider
        |
        v
one or more typed relations
        + provenance
        + validation
```

Virtual RYTA is the decision-authority specimen.  CameraCurrentCondition is the independent deterministic categorization specimen.  Neither is special-cased by the generic relation engine.

## Separation of concerns

```text
HardWorld
  defines facts, epistemic states, rules, effects, authority and approvals

VirtualRYTA
  exercises HardWorld with deliberately simple scored candidate actions

AlgorithmRelationEngine
  provides provider discovery, typed output, canonical input identity,
  content-addressed materialization and replay

AlgorithmReadOperator
  provides the first conservative planner-facing read boundary

NoSQLServer (future adapter)
  constructs relational input snapshots and places Algorithm Relation nodes
  into SQL plans

msqlshim
  remains a wire shim and sees ordinary relations/catalog metadata only
```

## Identity model

v0.4 deliberately separates five identities:

```text
materializationId
  SHA-256 of the content materialization key

providerExecutionId
  identifies the actual provider evaluation which created a materialization

invocationId
  identifies the current client/audit invocation or replay view

inputOid
  provenance label supplied/derived by the host; not trusted as cache identity

worldSnapshotOid
  identity of the frozen world snapshot when semantically distinct
```

Materialization key:

```text
algorithmId
algorithmVersion
sourceManifestHash
canonicalInputHash
worldSnapshotOid
```

`invocationId` and `inputOid` are intentionally excluded.

## Source manifest

Strict providers expose a file-hashed manifest.  The manifest includes every code/model/plugin component needed to substantiate deterministic execution.

An external plugin must provide both:

```text
canonicalConfiguration
sourceManifestHash
```

or otherwise be covered by the component's shipped file manifest.  Missing source/config identity marks the provider `INCOMPLETE` and blocks the planner read path.

## Input immutability

An Algorithm Relation evaluation is a read of a frozen input.

Virtual RYTA internally adds capability defaults and plugin facts, so its adapter clones `RYTAWorldState` before evaluation.  This prevents evaluation from mutating the content that was just hashed.

Learning/model updates remain separate operations.

## Typed output

The generic engine enforces:

```text
TEXT
OID
INTEGER
NUMBER
BOOLEAN
```

and optional finite domains.

Every column must be present.  `.nil` is explicit NULL and is accepted only for nullable columns.  Unknown columns, type errors, domain errors, omitted columns and rejected rows remain visible in result validation.

Invalid provider output is never cached.

## Planner barrier

The v0.4 read operator has no pushdown interface.

```text
bind/describe/explain
   metadata only; provider invocation count remains zero

execute
   full provider materialization
      -> filter output rows
      -> project output columns
      -> LIMIT
```

This is intentionally conservative.  Ordinary SQL work may still reduce/freeze the **input relation before the Algorithm Relation boundary** where SQL semantics permit it.  Output predicates are not rewritten into provider-specific execution.

## Side effects

The v0.4 read operator accepts only:

```text
SIDE_EFFECT_CLASS=NONE
```

Reserved future classes are design placeholders, not executable v0.4 contracts:

```text
PROPOSAL_ONLY
DURABLE_REQUEST_ONLY
EXTERNAL_SIDE_EFFECT
```

External side effects must never become an incidental consequence of a SELECT/read rescan.

## Current acceptance posture

HardWorld remains frozen and green:

```text
64 state vectors
0 holes
0 ambiguous winners
25 adversarial cases passed
16/16 mutation guards killed
```

Algorithm Relation v0.4 additionally proves:

- actual input content defeats caller-OID aliasing;
- audit replay does not rerun the provider;
- fresh execution is explicit;
- source manifest changes invalidate materialization identity;
- plugin/approval/policy changes are identity-bearing;
- incomplete external plugin identity blocks SQL-read binding;
- real Camera v0.20 adapter remains compatible;
- type/domain-invalid provider results are not cached;
- planner LIMIT/filter/projection occur after full provider materialization.
