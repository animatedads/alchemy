# Alchemy source provenance: `oorexx_llm_coding_workbench`

- Current Git source baseline: `v0.1-dev15`
- Baseline date: 2026-10-29
- Primary source: `packages/oorexx_llm_coding_workbench` on `animatedads/alchemy`
- Prior sealed delivery: `oorexx_llm_coding_workbench_v0.1-dev14.zip`
- Prior delivery SHA-256: `04429c32acf45c8926dff41c16fb7e73a25d4480ba7fa199ff1b28d960032899`

## dev15 continuation

dev15 is a Git-native continuation of dev14. It adds controller-owned semantic
stale-base protection: the Workbench remembers the method revision/source state
it inspected and rejects `WRITE_METHOD` with `STALE_SEMANTIC_BASE` if that
state has moved before Development Desk mutation. The model does not supply the
base token.

This aligns the Workbench with the current Semantic Source Control exact-base
mutation direction without absorbing SSC conflict/branch authority and without
changing Coding Intentions.

## Qualification provenance

The last complete Workbench environment qualification remains the dev13 r13196
record in `docs/QUALIFICATION_r13196.txt`. dev14 and dev15 are narrow
Workbench-owned continuations. The exact earlier r13196 runtime/dependency
bundle is not mounted in the 2026-10-29 execution environment, so no new full
runtime PASS is claimed here. See the Workbench sphere qualification status for
the current limitation and Rasen Falcon coordination record.
