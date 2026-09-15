# Algorithm Input Consistency v0.14

## Purpose

A frozen Algorithm Input Relation is immutable after capture. That fact alone does not say that the sources from which it was captured were observed at one atomic instant.

v0.14 therefore separates **relational content identity** from **temporal consistency evidence**.

## Grades

### FROZEN_OBSERVATION

The captured typed rows are immutable after capture. No claim is made that their upstream sources were observed atomically.

This is the default and the maximum grade automatically assigned by the generic NoSQLServer/federated capture path.

### SOURCE_SNAPSHOT

Exactly one source was observed under an evidenced native snapshot boundary. The descriptor requires:

- `sourceCount = 1`;
- a non-empty snapshot token;
- evidence identifying the attestor/snapshot mechanism.

The reference implementation is NoSQLServer v0.70 `FileDatabaseEngine` transaction capture. The transaction operates on a stable clone, records a base signature, and refuses commit when the live source has changed incompatibly.

### COORDINATED_SNAPSHOT

Multiple sources were observed under one evidenced coordinator/snapshot token. The descriptor requires:

- at least one source;
- a coordinator identity;
- a non-empty snapshot token.

**v0.14 defines this grade but has no automatic attestor that awards it.** In particular, ordinary NoSQLServer federation is not promoted to this grade.

## Identity

`AlgorithmInputRelationSnapshot~contentHash` remains a hash of typed relation content and ordering semantics only.

Consistency evidence has a separate `consistencyHash`.

The provider-facing canonical form includes both:

```text
algorithmCanonicalText = relational canonical text
                       + consistency hash
                       + consistency canonical evidence
```

Therefore:

```text
same rows + different consistency evidence
    -> same contentHash
    -> different consistencyHash
    -> different algorithm materialization identity
```

This prevents provenance quality from contaminating content identity while still preventing cache aliasing across materially different evidence.

## Consumer requirements

A consumer may declare `minimumConsistency`.

Consistency is an eligibility gate, not a score adjustment.

If the actual input grade is below the required grade, the reference table-fed decision provider emits:

```text
STATE        = UNRESOLVED
DISPOSITION  = UNRESOLVED
FINAL_SELECTED = false
REASON       = INPUT_CONSISTENCY_INSUFFICIENT
```

This applies equally to positive commercial preference, `PROHIBITED`, `REQUIRED`, and every other authority disposition. A weak snapshot cannot be compensated for by a large score.

## Propagation

Algorithms that transform evidence must not silently erase temporal consistency evidence. The v0.14 Librarian relations propagate the input consistency grade/hash on document, sentence, word, target-hit and target-hit-provenance evidence rows.

A later consumer can therefore distinguish:

```text
Librarian evidence from a frozen observation
```

from:

```text
Librarian evidence from an attested source snapshot
```

without reparsing trace text or consulting hidden provider state.

## Attestation rules

A stronger grade is awarded only by an explicit attestor which understands the source's real snapshot mechanism.

The following are **not** sufficient by themselves:

- a table name;
- `snapshotGeneration` text;
- an access-path label;
- a caller assertion saying `atomic=true`;
- an immutable copy made after several unrelated reads;
- a federated query result.

Generic capture therefore remains `FROZEN_OBSERVATION` unless the caller supplies an explicitly trusted consistency descriptor through a source-specific/coordinator-specific path.

## NoSQLServer v0.70 reference attestor

`NoSQLServerAlgorithmTransactionalInputCapture.cls` uses a native single-source `FileDatabaseEngine` transaction. It requires transaction objects exposing the expected token and base-signature evidence, executes the query against the transaction's stable clone, commits the read transaction, and freezes that exact deferred result.

The generic `FederatedDatabaseEngine` transaction does not provide that contract and is intentionally not accepted as a `SOURCE_SNAPSHOT` attestor.

## Coverage

The v0.14 consistency/authority matrix exhaustively covers:

```text
3 required consistency grades
x 3 actual consistency grades
x 6 authority dispositions
x 3 score classes
= 162 vectors
```

Expected rule:

1. if actual consistency is below required consistency: `UNRESOLVED`, no execution;
2. otherwise apply the existing authority-versus-score semantics unchanged.

## Explicit non-claims

v0.14 does not claim:

- globally atomic federated reads;
- cross-database distributed snapshot coordination;
- snapshot isolation from a source merely because its rows were copied;
- that consistency grade makes semantic evidence authoritative;
- that `COORDINATED_SNAPSHOT` can currently be inferred automatically.

The grade is evidence about **when/how the input was observed**, not about whether its semantic assertions are true.
