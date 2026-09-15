# FederationBank Teller Cash Service v0.1

Durable service boundary for counter-cash coordination. It composes the existing Staff Channel Service/Staff Authority chain with Teller Cash and Teller Till physical custody while preserving Core Banking as monetary authority.

This service owns **correlation and restart-safe cash work**, not workforce authority, account balances, physical till truth or Ledger truth.

## Commands

- `FBTELCASH.ACTION.SUBMIT` — create one exact cash work from a sealed Staff Channel request plus exact Teller Cash instruction, persist it, then drive Staff Channel.
- `FBTELCASH.ACTION.RESUME` — resume maker/checker work with additional Staff Authority evidence.
- `FBTELCASH.ACTION.RECOVER` — continue an exact `READY_FOR_CORE` item after infrastructure interruption.
- `FBTELCASH.ACTION.GET` — read durable Teller Cash work.

## Durable work

A `FederationBankTellerCashServiceWork` persists both:

1. the exact Staff Channel request; and
2. the exact physical Teller Cash instruction.

That is necessary because restart/recovery must not reconstruct physical details from today's screen or from mutable operational state.

Service state also persists:

- semantic command receipts;
- work state/revision;
- audit events;
- stable event IDs;
- an at-least-once delivery outbox.

Recovered instructions are re-registered immutably with the Teller Cash dispatch port before the service accepts new work.

## Institutional states

The service preserves the authority that has already committed:

- `APPROVAL_REQUIRED`
- `READY_FOR_CORE`
- `CORE_REJECTED`
- `COMPLETED`
- `COMPENSATION_REQUIRED`
- `RECONCILIATION_REQUIRED`

`READY_FOR_CORE` is deliberately not reported as an institutional success. It means Staff Authority has succeeded but the exact Core/cash execution still needs delivery/recovery.

`COMPENSATION_REQUIRED` and `RECONCILIATION_REQUIRED` *are* committed operational outcomes requiring subsequent institutional work; the service does not roll them back or disguise them as transport errors.

## Queue Fabric boundary

`FederationBankTellerCashServicePersistenceSupport` registers the complete graph required to persist/recover Teller Cash commands, work and nested Staff Channel objects through Queue Fabric v0.9-dev4.

`FederationBankTellerCashQueueWorker` supports typed permanent command queues and typed event queues. Qualification destroys and reconstructs the queue manager before consumption and then executes the recovered command graph successfully.

There is no UI, ATM route or direct Ledger ingress in this service.
