# FederationBank Staff Channel Service v0.1

Durable service boundary around `federationbank_staff_channel_v0.1`.

It owns staff-work **coordination state**, not relationship authority, workforce authority, Core Banking policy or Ledger truth.

## Commands

- `FBSTAFFCH.ACTION.SUBMIT` — prepare a new staff work item, obtain Staff Authority, persist it, and submit to Core if ready.
- `FBSTAFFCH.ACTION.RESUME` — resume exact maker/checker work with additional approvals.
- `FBSTAFFCH.ACTION.RECOVER` — explicitly continue a persisted `READY_FOR_CORE` item.
- `FBSTAFFCH.ACTION.GET` — read durable work state.

## Service-to-service Staff Authority

`FederationBankStaffChannelStaffAuthorityServicePort` does not duplicate employment/approval rules. It:

1. supplies sealed workforce/session context snapshots to FederationBank Staff Authority Service v0.1;
2. records exact-action checker approvals there;
3. asks that service to issue the staff authority envelope;
4. returns only the resulting decision/envelope to Staff Channel orchestration.

Thus Staff Channel Service remains a coordinator rather than a second Staff Authority implementation.

## Write-ahead Core semantics

The service uses a two-stage domain orchestration contract:

```text
request
  |
  v
Staff/relationship checks
  |
  v
READY_FOR_CORE
exact bound command
  |
  +--> DURABLE SERVICE SAVE
  |
  v
Core Banking submission
  |
  v
COMPLETED / CORE_REJECTED
  |
  +--> DURABLE SERVICE SAVE
```

This is deliberate. If Core transport is unavailable after the first save, restart recovers `READY_FOR_CORE` and retries the same exact idempotent Core command.

If Core commits but the final Staff Channel persistence step fails, the durable state still says `READY_FOR_CORE`; the same recovery retry reaches FederationBank Core with the same idempotency key, so Core's own committed-receipt recovery prevents a second monetary execution.

## Durable state

State includes:

- typed Staff Channel work graphs;
- exact request/command snapshots;
- Relationship Adapter evidence where applicable;
- Staff Action / Staff Authority decision / envelope;
- service command receipts;
- audit event sequence;
- pending at-least-once outbox events.

No Core receipt object is re-owned by the channel. Work retains the authoritative Core result code/detail and the Core command identity; detailed banking truth remains with Core/Ledger.

## Events

Examples:

- `FBSTAFFCH.WORK.APPROVAL_REQUIRED`
- `FBSTAFFCH.WORK.READY_FOR_CORE`
- `FBSTAFFCH.WORK.COMPLETED`
- `FBSTAFFCH.WORK.CORE_REJECTED`
- `FBSTAFFCH.WORK.REJECTED`
- `FBSTAFFCH.WORK.NO_BANK_ACTION`

Events retain correlation/causation and stable service event IDs. Publication is at-least-once via a durable outbox.

## Queue Fabric

The Queue Fabric worker supports temporary or permanent command/event queues. The persistence codec registers the Staff Channel graph plus the existing Staff Authority graph types. A permanent typed command containing staff contexts survives Queue Fabric manager destruction/reconstruction and can then be processed normally.

## Validation

Nine executable service/integration tests pass under ooRexx 5.3.0 r13196, including write-ahead Core recovery, service restart, permanent Queue Fabric recovery and the complete Relationship Case -> Relationship Adapter -> Staff Channel Service -> Staff Authority Service -> Core Banking chain.
