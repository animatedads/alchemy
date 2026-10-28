# Librarian v2 — engineering Gopher sphere v0.1.2

Current experimental source baseline: **dev10** (2026-10-28).

This knowledge sphere documents the clean-room ooRexx Librarian rewrite. It is
not the original WordNet/HardWorld Librarian; its evidence authority excludes
truth certification, media-independence claims, causal Brand Effect and CMS
publication decisions.

## Current source and qualification

- Cumulative ZIP: `librarian_v2_dev10_20261028.zip`
- SHA-256: `aa48ba861e5a25341349302de0e7dad64979631d33dea7c7955f6a292a187223`
- Native ooRexx 5.3.0 r13196: **129 PASS checks** (116 assertions, 13 rejected invalid cases).
- Updated canonical schema: `LIBRARIAN-PROVENANCE-SNAPSHOT/2` includes full
  event/proposition query scope, knowledge cutoffs and complete historical
  source evidence rows.
- Single Time Service v0.3 is pinned. v0.9 is upstream but unqualified here.

Source deltas are in `packages/librarian_v2_dev8/`,
`packages/librarian_v2_dev9/`, and `packages/librarian_v2_dev10/`.
Earlier source and the Time Service fixture closure are bundled with the
cumulative ZIP but not entirely mirrored into GitHub.

## Gopher installation and smoke test

The repository folder is a **source**, not a live Gopher registration.
A Gopher deployment actor must package and install these files as the
`librarian-v2` sphere, preserving the canonical layout:

- `packs/librarian-v2/00-sphere.json`
- `packs/librarian-v2/01-access-policy.json`
- `packs/librarian-v2/articles/*.json`
- `profiles/librarian-v2.json`

Once deployed to the Alchemy sphere catalogue and LLM Gopher runtime:

```sh
./gopher --profile librarian-v2 context librarian-v2
./gopher --profile librarian-v2 open librarian-v2.start
./gopher --profile librarian-v2 open librarian-v2.dev10
./gopher --profile librarian-v2 open librarian-v2.qualification
```

The expected Alchemy `sphere_check(sphereId="librarian-v2")` response is
`SPHERE_RESOLVED` with version **0.1.2** and a selected manifest. Anything
else is unqualified and must not be described as deployed.

## Coordination

The authenticated Rasen Falcon lane is `librarian_v2`, created by CHATGPT.
All messages use that component ID; look for unread replies on the same lane.
Github PR #53 is the currently open draft; do not confuse the prior merged
PR #24 with the dev9/dev10 review.
