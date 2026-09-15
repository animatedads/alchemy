# Relationship Case service boundary

v0.2 remains the general domain module. The first concrete service host is `relationship_case_service_v0.1`.

The service boundary exposes:

- `CASE.OPEN`
- `CASE.ATTACH_ELEMENT`
- `CASE.TRANSITION`
- `CASE.GET`
- `CASE.FOR_SUBJECT`
- `CASE.PROJECT`

The service owns durability, idempotency, queue transport and event outbox semantics. The domain still owns case invariants and policy-gated transitions/projections.

FederationBank-specific adapters translate authoritative bank results to/from case element references; they must not allow a Relationship Case transition to post money or mutate account state directly.
