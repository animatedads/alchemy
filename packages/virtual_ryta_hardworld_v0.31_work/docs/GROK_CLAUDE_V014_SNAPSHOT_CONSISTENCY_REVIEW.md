# Grok / Claude adversarial review: v0.14 snapshot consistency

## Mission

Attack the claim that table-fed Algorithm Relations can carry explicit, auditable temporal-consistency evidence without conflating it with relational content or authority.

Do not redesign HardWorld. Find cases where a weak observation can be laundered into a stronger one, where two materially different snapshots alias identity, or where metadata/read transport accidentally changes execution semantics.

## Current grades

```text
FROZEN_OBSERVATION
SOURCE_SNAPSHOT
COORDINATED_SNAPSHOT
```

`COORDINATED_SNAPSHOT` is defined but has no automatic v0.14 attestor.

## Claims to attack

1. `contentHash` depends only on typed relational content/order mode.
2. `consistencyHash` depends on grade and canonical consistency evidence.
3. same rows/different consistency do not share algorithm materialisation identity.
4. a weak grade cannot satisfy a stronger consumer contract.
5. consistency failure produces `UNRESOLVED`; score cannot bypass it.
6. `PROHIBITED` and `REQUIRED` are not silently acted upon when the consumer says the snapshot is too weak to decide.
7. generic NoSQLServer federation never self-promotes beyond `FROZEN_OBSERVATION`.
8. NoSQLServer v0.70 single-file transactional capture deserves `SOURCE_SNAPSHOT` under the actual stable-clone/base-signature contract.
9. the exact transaction result is frozen; the attestor does not re-query after attestation.
10. source mutation/conflict causes capture failure rather than a false snapshot claim.
11. consistency evidence is immutable/canonical after snapshot construction.
12. Librarian propagates grade/hash instead of laundering temporal provenance away.
13. transformed relations cannot silently upgrade consistency.
14. metadata/schema discovery still does not execute providers.
15. MySQL PREPARE/FETCH remains transport and cannot manufacture a stronger grade.
16. BAG_UNORDERED/ORDERED semantics remain orthogonal to consistency grade.
17. duplicate evidence rows retain multiplicity while consistency identity remains deterministic.
18. source/coordinator tokens cannot be reused to alias unrelated snapshots.
19. malformed/forged descriptors fail closed.
20. no component treats consistency grade as semantic authority.

## Required hostile cases

Supply at least **45 adversarial cases**. Include at minimum:

- fake `SOURCE_SNAPSHOT` descriptor from an untrusted caller;
- stale snapshot token reused after source changes;
- same token with different base signatures;
- same rows captured from two different moments;
- same rows/different grades;
- different rows/same supplied provenance strings;
- evidence-order permutation;
- duplicate evidence entries;
- Unicode/control characters in coordinator/token/evidence;
- enormous token/evidence values;
- zero-source frozen observation;
- illegal source counts for stronger grades;
- missing coordinator for coordinated grade;
- federation incorrectly passed to the single-source attestor;
- source changes before transaction starts;
- source changes during transactional capture;
- source changes after capture;
- commit conflict;
- transaction rollback;
- transaction object lacking token/base signature;
- attestor re-query bug;
- provider exception during strict consistency handling;
- consistency downgrade through Librarian;
- consistency upgrade through Librarian;
- consistency dropped during SQL projection/reconstruction;
- consumer requiring coordinated snapshot receiving source snapshot;
- consumer requiring source snapshot receiving frozen observation;
- consumer requiring frozen observation receiving stronger grades;
- `PROHIBITED` with +1e100 under weak grade;
- `REQUIRED` with -1e100 under weak grade;
- `PERMITTED` with positive score under weak grade;
- duplicate target/evidence rows under different grades;
- BAG_UNORDERED row reorder under same grade;
- ORDERED row reorder under same grade;
- order-mode change with identical rows;
- prepared statement created before source mutation;
- metadata during in-progress source capture;
- concurrent strict consumers;
- cache replay across different consistency hashes;
- FRESH execution under unchanged content/consistency;
- process restart and stale in-memory descriptor;
- malicious sourceIdentity claiming snapshot semantics;
- `snapshotGeneration` string used as a fake attestor;
- table name/source label used as a fake attestor;
- attempted automatic COORDINATED promotion from multi-engine federation;
- nested Algorithm Relation input whose upstream consistency is weaker than claimed downstream.

## Mutation catalogue request

Supply at least **30 mutants** and state the exact test that should kill each. Include mutants that:

- remove consistency from provider canonical input;
- put consistency into `contentHash` instead;
- compare grades lexically rather than by rank;
- invert one grade rank;
- let `FROZEN_OBSERVATION` satisfy `SOURCE_SNAPSHOT`;
- turn insufficient consistency into a score penalty;
- keep upstream `PROHIBITED` active despite failed consistency gate;
- keep upstream `REQUIRED` active despite failed consistency gate;
- silently default missing grade to strongest;
- auto-promote federation to source/coordinated snapshot;
- re-query after transactional attestation;
- omit transaction base signature evidence;
- omit snapshot token from consistency hash;
- omit coordinator from coordinated hash;
- treat evidence as unordered incorrectly / ordered incorrectly;
- permit descriptor backing evidence mutation;
- drop Librarian consistency columns;
- rewrite Librarian output grade to `SOURCE_SNAPSHOT`;
- ignore model/source drift after metadata discovery;
- make PREPARE execute the provider;
- make FETCH rerun the provider.

## Questions requiring a concrete answer

1. Is the three-grade lattice sufficient, or is a partially ordered model needed once multiple heterogeneous sources exist?
2. Is `SOURCE_SNAPSHOT` too broad if individual backends offer materially different isolation guarantees?
3. What exact trust boundary should be permitted to instantiate stronger consistency descriptors?
4. Should a strong consumer return zero rows, an error relation, or `UNRESOLVED` rows on insufficient consistency? Defend the audit semantics.
5. How should consistency be composed when Algorithm B consumes outputs from Algorithms A1/A2 with different grades?
6. What proof would be sufficient before implementing `COORDINATED_SNAPSHOT`?
7. Should transaction isolation level, source version/signature and snapshot token become structured fields instead of evidence strings?
8. How should consistency evidence survive persistence/restart and remote/wire transport without trusting client-supplied labels?

## One-line design test

Given identical decision rows twice—once captured as an uncoordinated frozen observation and once through an evidenced single-source transaction—prove mechanically why they have the same relational content identity, different temporal evidence identity, and potentially different eligibility for the same HardWorld consumer.
