# FederationBank Staff Authority Service v0.1

Durable service boundary around `federationbank_staff_authority_v0.1`.

The service caches sealed externally authoritative staff context snapshots, records independent approvals and issues exact-action-bound Staff Authority envelopes. It deliberately does **not** become HR/IAM, execute Core Banking commands or expose a Ledger ingress path.

## Commands

- `FBSTAFF.CONTEXT.PUT` — store/update a sealed staff context snapshot supplied by an authoritative integration.
- `FBSTAFF.APPROVAL.RECORD` — record an approval after validating the approver against their own staff context and the exact action.
- `FBSTAFF.ACTION.AUTHORISE` — evaluate Staff Authority for an action using cached maker/checker contexts and approvals.
- `FBSTAFF.AUTHORITY.GET` — read a stored action authority record.
- `FBSTAFF.CONTEXT.GET` — read a cached staff context.

## Events

The service emits durable events such as:

- `FBSTAFF.CONTEXT.STORED`
- `FBSTAFF.APPROVAL.RECORDED`
- `FBSTAFF.AUTHORITY.APPROVAL_REQUIRED`
- `FBSTAFF.AUTHORITY.ISSUED`

Events retain command correlation/causation and stable service event identity.

## Durable semantics

Mutating commands use semantic command fingerprints. Repeating the same command identity and semantics is idempotent; reusing the identity for different semantics conflicts.

Committed service state is persisted before event delivery. Event publication is at-least-once through a durable outbox with stable event IDs, so a delivery failure does not roll back or lose a valid authority decision.

The Queue Fabric worker supports permanent command/event queues and typed graph recovery after Queue Fabric manager reconstruction.

## Service state

Durable state includes:

- staff context snapshots;
- approvals by exact action;
- authority/approval-required records;
- semantic command receipts;
- audit event sequence;
- pending outbox events.

## Boundary to Core Banking

The service returns authority evidence. `FederationBankStaffCommandBinder` in the domain module can bind a positive envelope to the exact ordinary `STAFF` Core Banking command. The service itself does not submit the command and therefore cannot turn Staff Authority into Core Banking or Ledger authority.

## Validation

See `VALIDATION.md` and `VALIDATION_TRANSCRIPT.txt`. Eight executable service tests pass, including restart/idempotency recovery, outbox retry, permanent Queue Fabric typed-command recovery and exact Core command binding. All service `.cls` files pass `rexxc` under ooRexx 5.3.0 r13196.
