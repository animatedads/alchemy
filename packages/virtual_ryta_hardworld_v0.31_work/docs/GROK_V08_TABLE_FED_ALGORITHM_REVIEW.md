# Grok adversarial review request: v0.8 Table-Fed Algorithm Relations

You are reviewing the next step of Virtual RYTA / HardWorld Algorithm Relations.

Do not praise the design unless a claim survives attack. The goal is to find semantics which would make table-fed algorithms unsafe, nondeterministic, unreproducible, misleading, or impossible to compose correctly.

## What changed

v0.7 established lazy Algorithm Relation external engines in stock NoSQLServer v0.68.

v0.8 adds the reciprocal path:

```text
SQL result
  -> frozen typed AlgorithmInputRelationSnapshot
  -> deterministic algorithm provider
  -> typed Algorithm Relations
  -> SQL
```

A live reference pipeline now runs:

```text
Virtual RYTA (Algorithm A)
  -> SQL join with persisted toy_policy
  -> frozen input relation
  -> TABLE_FEED_DECIDER (Algorithm B)
  -> SQL relation
```

Both providers execute once.

## Claims to attack

1. `BAG_UNORDERED` provides a deterministic identity for ordinary relational bag input.
2. Duplicate rows are preserved while row order is canonicalised.
3. `ORDERED` correctly makes sequence part of identity.
4. Content identity is independent of source query/source subsystem provenance.
5. Source query hash and source identity remain auditable without contaminating content identity.
6. Frozen row views prevent post-capture source mutation from changing algorithm input.
7. A fresh capture after source change produces a new content hash when the typed relation changes.
8. Algorithm B cannot cause Algorithm A to rerun merely by scanning its frozen input.
9. Repeated SQL scans of Algorithm B do not rerun A or B.
10. Catalog/schema work on Algorithm B does not execute B.
11. A score cannot defeat an inherited `PROHIBITED` or `REQUIRED` disposition in the reference provider.
12. Same content obtained from a different query can legitimately reuse deterministic computation if source provenance is not an explicit semantic input.
13. An algorithm requiring source provenance must declare it explicitly rather than relying on hidden origin identity.
14. The current snapshot boundary is sufficient to prevent a live database from moving underneath Algorithm B.
15. Composition A -> SQL -> B does not accidentally convert SQL planner behavior into algorithm behavior.
16. `AlgorithmInputRelationSnapshot` is generic enough for Camera/Librarian/scoring-matrix inputs, not RYTA-specific.
17. NoSQLServer remains an adapter/producer of input relations rather than becoming part of algorithm semantics.
18. msqlshim remains ignorant of both the upstream and downstream algorithms.

## Areas where we explicitly want criticism

### Relational identity

- Is bag canonicalisation correct for SQL duplicate semantics?
- Should NULL, numeric representations, collation, Unicode normalization, temporal values, binary values, NaN/infinity, signed zero, and geometry require stronger canonical rules?
- Should schema column order be semantic?
- Are type aliases (`INTEGER` vs compatible numeric types) identity-equivalent or distinct?
- Should canonicalization include declared domains/constraints?

### Ordering

- `ORDERED` is currently an explicit caller contract; the NoSQL capture adapter does not prove that SQL used a stable ORDER BY.
- Define the minimum honest contract for ordered table-fed algorithms.
- Consider ties in ORDER BY, locale/collation, NULL ordering, nondeterministic functions, and external source ordering.

### Snapshot timing / transactions

- What exactly must be frozen when the source SQL spans multiple engines?
- Does a sequential federated read constitute a coherent world snapshot?
- What happens if PostgreSQL, GeoPackage, an object source, and Algorithm A are observed at slightly different times?
- Should table-fed safety algorithms refuse inputs lacking a declared snapshot-consistency grade?

### Provenance

- Is it correct that query/source provenance does not affect content identity?
- When should provenance be an explicit semantic input?
- How should authority/source trust attach to individual cells/rows rather than just the relation?
- How should a relation preserve derivation lineage through joins/projections/aggregates?

### Cycles and recursion

Attack:

```text
Algorithm A -> SQL -> B -> SQL -> A
```

and deeper dependency cycles. Define detection, failure semantics, and whether any fixed-point form should ever be allowed.

### Freshness and invalidation

- Should an already materialized downstream relation ever auto-invalidate when upstream tables change?
- Current v0.8 answer is no: a snapshot is immutable; fresh evaluation requires a fresh capture/context.
- Attack that choice.

### Partial / huge relations

- source query cancellation;
- provider cancellation;
- memory exhaustion while freezing;
- partial source results;
- LIMIT accidentally changing algorithm semantics;
- streaming versus full-materialisation contracts;
- billion-row inputs;
- hashes over extremely large relations.

### Authority propagation

The reference provider mechanically propagates upstream dispositions. Attack whether `PROHIBITED`, `REQUIRED`, `SUPPRESSED`, `PERMITTED`, and `REQUIRES_APPROVAL` are compositional across policy domains.

In particular, identify cases where copying an upstream normative disposition into a downstream policy domain would be semantically invalid even though plumbing is correct.

### Coverage

The reference provider exhaustively tests:

```text
6 upstream dispositions x 3 score classes = 18 vectors
```

with zero holes.

Propose a production coverage model for relation-fed algorithms, including schema/value partitions and cross-row constraints rather than only row-local state.

## Required adversarial corpus

Provide at least 40 cases. Include, at minimum:

1. Same bag, reversed row order.
2. Same ordered rows, reversed sequence.
3. Duplicate row removed.
4. Duplicate row added.
5. NULL versus empty string.
6. integer 1 versus textual "1".
7. decimal lexical variants.
8. boolean versus integer 1.
9. Unicode normalization variants.
10. case/collation variants.
11. same content from different queries.
12. same query text against changed data.
13. source changes after freeze.
14. source changes during capture.
15. Algorithm A changes after source SQL starts.
16. Algorithm A manifest changes before B executes.
17. B metadata before A materialises.
18. concurrent capture of the same source.
19. concurrent first reads of B.
20. cancellation during capture.
21. cancellation during B.
22. partial federated-source failure.
23. two-source inconsistent snapshot.
24. three-engine snapshot skew.
25. SQL LIMIT before capture.
26. SQL LIMIT after B.
27. WHERE 1=0 source.
28. zero-row input.
29. one million duplicate rows.
30. very large text value.
31. embedded delimiters/newlines/NUL bytes.
32. malicious column name collision.
33. schema drift between captures.
34. domain constraint change with identical values.
35. A -> B -> A dependency cycle.
36. A -> B -> C chain with stale B.
37. upstream PROHIBITED at +1e100.
38. upstream REQUIRED at -1e100.
39. upstream REQUIRES_APPROVAL with positive score.
40. same materialized input replayed under another audit invocation.

Add more where appropriate.

## Required mutants

Provide at least 30 mutation operators. Include mutations that:

- make row order affect unordered bag identity;
- make row order disappear from ordered identity;
- collapse duplicate rows;
- coerce NULL to empty string;
- remove schema/type data from canonicalization;
- add source query text to content hash;
- omit content hash from downstream materialization identity;
- read live source rows during B evaluation;
- auto-refresh a frozen snapshot silently;
- turn PROHIBITED into PERMITTED;
- turn REQUIRED into score-dependent;
- let positive score defeat SUPPRESSED;
- treat REQUIRES_APPROVAL as PERMITTED;
- hide a failed/partial capture as an empty successful relation;
- allow a cycle to recurse indefinitely.

## Required response format

Return:

A. Executive verdict  
B. Claims that hold  
C. Claims that fail or need qualification  
D. Canonical relation identity proposal  
E. Snapshot/transaction consistency grades  
F. Provenance and lineage model  
G. Cycle/dependency model  
H. Authority-composition critique  
I. Coverage taxonomy  
J. 40+ adversarial cases  
K. 30+ mutants  
L. Blockers before any production table-fed decision engine

The key question is no longer whether an algorithm can look like a table. It can.

The key question is whether a **table can become an algorithm input without losing relational, temporal, provenance, authority, or execution semantics**.
