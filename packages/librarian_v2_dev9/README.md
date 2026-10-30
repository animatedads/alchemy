# Librarian v2 dev9 — historical occurrence-level source provenance

**Date:** 2026-10-27. **Status:** experimental native ooRexx source, not production acceptance.

The new `LibrarianProvenanceHistory.cls` defines `LibrarianProvenanceClaim`, `LibrarianProvenanceHistory`, and `LibrarianProvenanceSnapshot`.

Each assertion references an event, proposition, child and parent **source edition / occurrence / span**, declared relationship, and evidence identifier. An append-only `ASSERT`, `CORRECT`, or `RETRACT` record preserves predecessor and lineage. Historical snapshots separately enforce publication and observation cutoff time points; corrections cannot rewrite what was knowable before they arrived.

The projection retains multiple declared parents, refuses to infer verified independence, treats `CORROBORATION_CLAIM` as a reported claim (not content dependency), reports conflicting branches as unresolved, and fails closed for dependency cycles. Canonical output length-prefixes and sorts snapshot records to remove insertion-order influence from independent evidence.

**Time authority:** `LibrarianTimePoint` from the existing Librarian temporal adapter normalises via Single Time Service. The qualified archive pins Single Time Service v0.3. The upstream Time Service sphere now documents v0.9; interoperability with its API is a separate qualification requirement, not an implicit upgrade.

## Source and reproducible test artifact

The complete transitive source/test/fixture package is `librarian_v2_dev9_20261027.zip`:

- SHA-256: `6ebb503d6db6d3ffe9dc93385c02b637af8fa21dfb6fe43da2466f0aba207496`
- Contains dev1–dev8 kernels, `src/LibrarianTemporal.cls`, `src/LibrarianProvenanceGraph.cls`, Time Service v0.3, and all suite inputs.
- Includes `tests/run_librarian_tests.sh` (see packaged README for interpreter setup).

This GitHub path publishes the **dev9 source delta and its tests**. Historical v2 dependencies are not all mirrored into this branch yet; do not represent this checkout alone as a self-contained package. Until catch-up is complete, run the test runner from the exact ZIP source tree.

## Native qualification receipt

ooRexx 5.3.0 r13196 debug interpreter, 2026-10-27:
- Compiler: dev8 provenance graph and dev9 history classes compiled.
- 102 positive assertions across nine executed ooRexx suites: PASS.
- 13 negative interpreter rejection cases: PASS.
- Total: **115 PASS checks**; ZIP integrity check: PASS.

These cover exact-source occurrence ancestry, distinct as-of cutoffs, corrections, retractions, conflicting tips, multi-parent references, deterministic snapshots, cycle detection, disallowed identifiers and missing evidence.

## Critical limitations

- Exact **span references** are required but content hashes, codepoint/byte offset validation and media-capture verification remain incomplete.
- Persistence, transactions, concurrency, bounded memory and cryptographic closure are not implemented.
- Unknown independence stays unknown; no media-bias, editorial motivation, brand causal impact, communication approval or HardWorld truth verdict is authorised.
- The dev4 origin comparator retains an order-sensitive legacy path; use neither it nor the dev8 graph for authoritative bias scoring.
- Independent Time Service v0.9 adoption requires a pinned contract and separate interpreter qualification.
