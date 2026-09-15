# FederationBank Staff Authority Service v0.2

Durable service boundary around `federationbank_staff_authority_v0.2`.

The service caches sealed externally authoritative staff context snapshots, records independent approvals and issues exact-action-bound Staff Authority envelopes. v0.2 preserves the action's `CUSTOMER` or `INSTITUTIONAL` authority scope through the durable record, decision, envelope, event and restart path.

It deliberately does **not** become HR/IAM, RID, execute Core Banking commands or expose a Ledger ingress path.

## Commands

- `FBSTAFF.CONTEXT.PUT`
- `FBSTAFF.APPROVAL.RECORD`
- `FBSTAFF.ACTION.AUTHORISE`
- `FBSTAFF.AUTHORITY.GET`
- `FBSTAFF.CONTEXT.GET`

## Durable semantics

State format is `federationbank.staff.authority.service.state/2`. The persistence codec also registers the legacy `/1` state/action/decision/envelope types; restoring a v0.1 action without a scope migrates it as `CUSTOMER`. New action/decision/envelope objects emit their v0.2 persistent types.

Mutations remain semantic-idempotent and event publication remains at-least-once through the durable outbox. `FBSTAFF.AUTHORITY.ISSUED` and approval-required events carry the authority scope explicitly.

## Boundary to Core Banking

The service returns authority evidence only. `FederationBankStaffCommandBinder` accepts only a positive `CUSTOMER` envelope for an exact ordinary `STAFF` Core Banking command. An `INSTITUTIONAL` envelope is deliberately unusable as Core Banking authority.

## Validation

Nine executable service tests cover context, approvals, idempotency, outbox, restart, Queue Fabric recovery, exact Core binding, scope persistence and the Runtime Registry-shaped module boundary.
