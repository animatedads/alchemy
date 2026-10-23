# RTO Operations / Plan42 / Inspector sphere

**Sphere ID:** `rto-operations-inspector` — candidate, not registered with LLM Gopher.

Do not overwrite the existing Gopher sphere named `rto`. Its selected title is "RTO distributed secure transport"; it is distinct from the RTO command/operation system.

## Ownership and semantic boundary

REX10 integration lane owns project Inspector evidence tooling, Plan42 specifications, and project-specific RTO rules. It does not own InspectorClouseau engine, Runtime Registry publication, RTO command dispatch, or operation authority. `RTOOperationSecurityContext` remains the governing boundary. `RTOInspectorRules` binds named RTO objects to an optional Inspector; report content is not permission.

Relevant roots: RTOCommand, RTOCommandRegistry, RTOOperationRegistry, RTOOperationSecurityContext, RTOCheckBrokenSymlinks, RTOREX86LowFruitOperations.

## r141 evidence truth

- r140 imported snapshots, deterministic receipts, and trace-load acknowledgements.
- r141 recognises live-class observations only from schema-qualified snapshot `objects[].class`, never from arbitrary JSON text.
- A receipt with expected schema, matching request identity, successful status, and positive loaded rule count declares installed trace rules; it does not prove method execution.
- Invalid or symlinked evidence fails the report. No-live state remains explicitly incomplete rather than claiming runtime acceptance.
- Outputs: `alchemy.rto.inspector-live-import.v2` and `alchemy.rto.inspector-live-compare.v2`.

The complete candidate source handoff is `rto_v105r141_rex10_inspector_evidence_truth_full.zip` (SHA-256 `a0a1a50d86ba9131b6a1958c395e237319f7c01e9be1b78fbe70ab941bd047ae`).

## Outstanding qualification

1. Obtain live ooRexx Inspector receipts and snapshots from an authorized RTO run.
2. Validate every `::requires` against installed paths before execution.
3. Pin refreshed Inspector/Plan42 source revisions; do not substitute Library candidates on name alone.
4. Decide whether externally copied evidence needs cryptographic host attestation.
5. Qualify the candidate with LLM Gopher before sphere registration.
6. Reconcile and publish the complete RTO source tree to GitHub before treating this directory as the authoritative runtime.

Static proof is not executed-dispatch proof.
