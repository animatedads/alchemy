# Librarian v2 engineering Gopher sphere v0.1.3

**Current experimental code checkpoint:** Librarian v2 dev11, 29 October 2026.

Librarian is an evidence/meaning and comparative-media consumer. It ingests
claims from media and social sources, models source occurrences and historical
corrections/retractions, reconstructs time-scoped knowledge, and provides
conservative source-provenance observations to Communications CMS and Brand Effect.
It has no factual/causal authority and controls no HTTPS, LDAP, mail or XTP service.

## Exact source and native qualification

Cumulative archive: `librarian_v2_dev11_20261029.zip`
SHA-256: `72211d64de28424f8acdc51f62f0d07418a18e5db8f0619e216bf474158d27a8`

- New dev11: scope uncertainty from contradictory lineage forks and provenance
  cycles only to affected queried occurrences and their dependents.
- Whole-snapshot contradictory evidence remains in the canonical audit record.
- ooRexx 5.3.0 r13196 native qualification: **150 checks PASS** (137 positive,
  13 expected-negative). `rexxc` compilation and ZIP integrity also PASS.
- Dev8-dev11 deltas are committed to GitHub; earlier dev1-dev7 and pinned
  Single Time Service v0.3 dependency are carried by the cumulative ZIP.
- Single Time Service v0.9 is a separate, unqualified integration boundary.

## Gopher deployment status

**GitHub sphere source is not evidence of Alchemy runtime activation.** The
source layout is `packs/librarian-v2/` and `profiles/librarian-v2.json`.
After a supported Gopher installation/publishing action, verify:

```sh
./gopher --profile librarian-v2 context librarian-v2
./gopher --profile librarian-v2 open librarian-v2.start
./gopher --profile librarian-v2 open librarian-v2.dev11
./gopher --profile librarian-v2 open librarian-v2.qualification
```

Alchemy `sphere_check(sphereId='librarian-v2')` must report
`SPHERE_RESOLVED`, selected sphere version `0.1.3`, and source provenance.

## Coordination

Authenticated Rasen Falcon lane: `librarian_v2` (principal CHATGPT).
GitHub review: PR #53 (draft; no production promotion). Autobuilder is not
running; do not imply autobuild qualification or installation.
