# Dynamic Story v0.1-dev1

Native ooRexx domain core, with no dependency on CMS, Queue Fabric, networking or LLM APIs.

## Status

Initial implementable domain slice; no claim of production readiness. This release has
in-memory intentions/narratives/approvals and synchronous selection. Integrations are
*contracts to be bound*, not simulated implementations. Intentions supplied to this core
must have been authorised by the actual authority service before registration. The
intention IDs in the demo are illustrative.

## Runtime

From the extracted package root:

    rexx examples/demo.rex
    rexx tests/smoke.rex

## Rules implemented

- Deterministic highest-priority matching eligible intention (caller supplies IDs).
- Unknown intentions rejected as no match; no inference or personal-data collection.
- Every claim must be approved, and explicit revocation blocks the selection.
- Decision includes source intention/narrative revisions and policy revision label.
- No silent promotion of evidence or suggested interventions into permission.

## Integration contracts (not yet implemented)

- Intention Service: only accept activated / READY-approved and authorised intent revisions.
- CMS Brand Builder: source versioned narratives, brand identity, approved claims and assets.
- Communications Management: supply campaign scope, channel policy, delivery/consent state.
- ConnectSelector: call domain API locally, over JSON-RPC, or via Queue Fabric as appropriate;
  never make queue transport mandatory for an interactive page decision.
- Institutional Policy: authoritative admission and withdrawal, independent of story ranking.
- Instrumentation: privacy-minimised observations and outcome metrics.
- LLM: deliver a bounded narrative authority packet, not a mutable system prompt.

## Known limitations / next increment

Not integrated with any portfolio package. No session state, persistence, eligibility predicates,
time/locale rules, claim expiry, live subscriptions, durable revocation fanout, approved-claim
revision propagation, consent engine, multi-tenant isolation or JSON-RPC server. No production
use until these are implemented and independently qualified.
