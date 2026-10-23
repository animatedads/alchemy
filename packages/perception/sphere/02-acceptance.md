# Perception acceptance and qualification ledger

## Current evidence (2026-10-23)
- Repository branch: `perception-portable-compute-20261023`.
- PR: https://github.com/animatedads/alchemy/pull/21 (draft).
- Implemented: minimal portable admission projection and unit-test source.
- Not verified in this GitHub increment: Python test execution, ooRexx runtime, real model inference, live MI/MU placement, Storage Fabric commit, checkpoint recovery.

## Required before accepted runtime
1. Validate schema and cross-references against the actual LLM Gopher sphere-authoring contract; this metadata is a draft, not a Gopher-validated registration.
2. Qualify tests on pinned Python and ooRexx runtime.
3. Bind actual Compute Layer, Job-to-Node and Migratable Job APIs without shadow ownership.
4. Demonstrate StoragePinnedRef input and verified durable output commit.
5. Demonstrate lease-epoch fencing, remote uncertainty and checkpoint restoration across two MUs.
6. Qualify at least one real MediaPipe face/pose model and one alternative backend; test unavailable models fail closed.
7. Verify source-global PTS, multi-person identifiers, coordinate-space declarations and uncertainty/provenance.
8. Confirm legal-region and access controls across migration.
9. Verify no identity claims from face landmarks alone.

No acceptance claims may be inferred from advisory admission tests.
