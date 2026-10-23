# Librarian v2 engineering Gopher sphere v0.1

Canonical Gopher sphere for the clean-room Librarian v2 evidence and comparative-media line.

- Sphere ID: `librarian-v2`
- Scope: dev1–dev8 source lessons and exact dev8 delivery; not production authority.
- Package: `librarian_v2_dev8_20261023.zip`, SHA-256 `17fd68b251e18ebe9f9c6902b6535db444bec1ce6a125ab6f2b8bd579250b742`
- GitHub source increment: `packages/librarian_v2_dev8/` (PR #24).
- Origin of truth: archived source + its linked claims; neither GitHub branch nor this sphere substitutes for ooRexx runtime qualification.

Install under a compatible LLM Gopher root using the directories `packs/librarian-v2/` and `profiles/librarian-v2.json`.

Typical reads:

```sh
./gopher --profile librarian-v2 context librarian-v2
./gopher --profile librarian-v2 open librarian-v2.start
./gopher --profile librarian-v2 open librarian-v2.provenance
./gopher --profile librarian-v2 search 'independence' --sphere librarian-v2
```

No automatic network ingestion, dispatch, CMS publishing or brand intervention is provided by this sphere. Read-only knowledge surface.

Qualification: JSON structure checks are separate from a full `gopher sphere edit validate/lint` and live profile test. ooRexx dev8 runtime tests are still pending.
