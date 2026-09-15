# Recovery Model

## Three different replay problems

Counter cash crosses several independently idempotent boundaries. v0.1 deliberately distinguishes:

1. **Teller Cash Service command replay** — same outer command ID/fingerprint returns the original committed work or continues a recoverable pending state.
2. **Staff Channel recovery** — an already-authorised `READY_FOR_CORE` Staff Channel item retries the exact bound Core command.
3. **Teller Till execution recovery** — an already `PREPARED` Till work is resumed, not resubmitted as a new physical action.

Collapsing these into one generic idempotency key would lose which authority has already committed.

## Withdrawal crash points

```text
cash work persisted
      |
Staff Authority succeeds
      |
READY_FOR_CORE
      |  <--- restart safe
Core debit commits
      |
CORE_COMMITTED (Till work)
      |  <--- physical failure here => COMPENSATION_REQUIRED
cash released
      |
COMPLETED
```

## Deposit crash points

```text
cash work persisted
      |
Staff Authority succeeds
      |
physical cash accepted
      |
CASH_HELD
      |  <--- account credit failure => RECONCILIATION_REQUIRED
Core credit commits
      |
COMPLETED
```

## Service-store state

Queue Fabric graph persistence retains the exact nested objects, rather than reducing the work to strings. `FederationBankTellerCashInstruction` has its own durable snapshot contract because its physical bundle/custody objects predate this service boundary.

The snapshot includes a terminal marker so empty optional Till-approval fields survive ooRexx delimiter parsing unambiguously.

## Event delivery

Mutation persistence and event delivery are separate. Service events enter a durable outbox with stable IDs. Sink failure leaves committed Teller Cash work untouched; later `flushOutbox` retries delivery at least once.
