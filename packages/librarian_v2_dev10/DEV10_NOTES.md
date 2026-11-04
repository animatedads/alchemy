# Librarian v2 dev10 — canonical historical evidence identity

Date: 2026-10-28. Experimental, not production-certified.

## Defect repaired

Dev9 canonical snapshots omitted event/proposition scope, cutoff identities,
superseded evidence, and detailed contradictory/retracted lineage records.
Distinct historical evidence states could serialize identically.

Dev10 introduces `LIBRARIAN-PROVENANCE-SNAPSHOT/2`. It serializes the event,
proposition, separate publication and observation cutoff instants, zones and
TZDB editions, plus **every** eligible source occurrence record (identifier,
predecessor, action, source editions, occurrences, spans, relation, evidence
ID and temporal provenance). Records and projected outcomes are independently
sorted and length-prefixed. The result is deterministic under permutations
of independent claims.

## Boundaries

- `canonical` is a deterministic serialization, **not a cryptographic hash**.
- It identifies the query and the whole knowable evidence materialisation.
- The source-ownership/verification problem is unchanged. Source-span strings
  are not authenticated media captures.
- Single Time Service **v0.3** is the pinned qualified dependency. The newer
  v0.9 contract is not yet requalified.
- Neither independent origin nor truth, intent, causal effect, bias verdict,
  reputation effect or CMS publication is authorised.

## Reproducibility and qualification

Self-contained archive: `librarian_v2_dev10_20261028.zip`
SHA-256: `aa48ba861e5a25341349302de0e7dad64979631d33dea7c7955f6a292a187223`.

From extracted ZIP root:

```sh
REXX=/absolute/path/to/rexx REXXC=/absolute/path/to/rexxc sh tests/run_librarian_tests.sh
```

Native ooRexx 5.3.0 r13196 debug: **129 passing checks**:
116 positive assertions across 10 suites and 13 expected-negative cases.
The dev10 class compiled with rexxc; archive integrity validated.

The GitHub `packages/librarian_v2_dev10/` path is a **source delta**.
Dev1–dev9 sources and pinned Time Service v0.3 dependency remain fully
materialised in the archive; do not claim the standalone repository delta
suffices to run the complete suite.
