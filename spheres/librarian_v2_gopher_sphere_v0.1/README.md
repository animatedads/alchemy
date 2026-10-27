# Librarian v2 engineering Gopher sphere v0.1.1

Canonical sphere ID: `librarian-v2`. Current tested experimental head: **dev9, 2026-10-27**.

The sphere covers source/evidence identity, event/proposition distinctions, publication versus observation time, correction/retraction histories, multi-parent occurrence-level provenance, comparisons, and evidence-only CMS / Brand integration boundaries.

Artifact: `librarian_v2_dev9_20261027.zip` SHA-256 `6ebb503d6db6d3ffe9dc93385c02b637af8fa21dfb6fe43da2466f0aba207496`.

**Runtime qualification:** ooRexx 5.3.0 r13196 native interpreter, 102 positive assertions plus 13 rejected invalid cases (115 passing checks), using the full zipped dependency tree and pinned Time Service v0.3. Upstream Time Service v0.9 exists but is **not** qualified here. Full sphere Gopher runtime validate/lint/activate remains outstanding.

Only dev8+dev9 source deltas have been published to the review branch. Earlier dev1–dev7 source and Time Service v0.3 dependency remain in the cumulative archive; a GitHub-only checkout is not sufficient for the full interpreter suite.

Knowledge activation, with the proper compatible Gopher installation:

```sh
./gopher --profile librarian-v2 context librarian-v2
./gopher --profile librarian-v2 open librarian-v2.start
./gopher --profile librarian-v2 open librarian-v2.dev9
./gopher --profile librarian-v2 open librarian-v2.qualification
```

Scope is **evidence and project continuity only**, not fact authority, independent-source certification, bias/causal verdicts, CMS approval or publication.

Mailbox component: `librarian_v2` on Rasen Falcon, authenticated as `CHATGPT`. Future work and missives must use this component ID.
