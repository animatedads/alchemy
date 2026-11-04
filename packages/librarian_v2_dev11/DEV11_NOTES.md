# Librarian v2 dev11 — query-scoped evidence uncertainty

2026-10-29. Native ooRexx 5.3.0 r13196 development checkpoint, **experimental, not production authority**.

## Material change

Dev10 `LibrarianProvenanceSnapshot~relationship` returned `INDETERMINATE_CONFLICT` for *every* source pair if any unrelated lineage had multiple revision tips. It similarly returned `UNRESOLVED_CYCLE` whenever *any* disconnected cycle existed in the entire event/proposition snapshot. This made independent, verifiable declared relationships unassessable for unrelated editorial disagreements.

Dev11 now records disputed **child occurrences** and scopes uncertainty to them and their downstream dependents through declared active provenance edges. Similarly, a detected cycle only blocks queries whose dependency ancestry reaches that cycle.

It preserves whole-snapshot diagnostics `conflicted` and `hasCycle`, and includes all evidence in the dev10 canonical serialization. A query involving disputed evidence remains `INDETERMINATE_CONFLICT`; a queried node that reaches a dependency cycle is `UNRESOLVED_CYCLE`. An unrelated query may still return `DECLARED_DEPENDENCY`, `DECLARED_SHARED_UPSTREAM`, or `INDEPENDENCE_NOT_ESTABLISHED`. `CORROBORATION_CLAIM` is **not** treated as a dependency edge.

### Native qualification

Complete dependency ZIP `librarian_v2_dev11_20261029.zip`, SHA-256 `72211d64de28424f8acdc51f62f0d07418a18e5db8f0619e216bf474158d27a8`.
Source `src/LibrarianProvenanceHistory.cls`, suite `tests/scoped_relationships.rex`, runner `tests/run_librarian_tests.sh`.

Supplied ooRexx 5.3.0 r13196 debug `rexx` and `rexxc`: **150 checks PASS** = 137 positive interpreter assertions (including 21 new dev11 assertions) plus 13 expected-negative cases. Compiler and ZIP integrity PASS. The GitHub dev11 source and new regression test blob hashes have been verified against the tested archive.

The repository `packages/librarian_v2_dev11/` is a **delta**; exact dev1–dev10 source and pinned Single Time Service v0.3 are in the ZIP. This branch does not yet publish the entire source closure; a GitHub-only checkout is not standalone.

### Integration and limitations

This component is an evidence consumer for Media Bias / comparative positioning and downstream Communications CMS / Brand Effect. It does not implement the priority website, LDAP, HTTPS, SMTP or XTP operational services, and does not accept their production authority. Their distinct owners should not be blocked by Librarian work.

Source media bytes/offset hashes, independent origin verification, durable ingest ordering, transactional persistence, bounded query cost, Time Service v0.9 compatibility and deployment of the Gopher sphere into Alchemy remain open. A known missing dependency edge is **not** proof of editorial independence.