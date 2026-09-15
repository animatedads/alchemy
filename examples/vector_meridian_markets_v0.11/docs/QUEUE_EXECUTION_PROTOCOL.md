# VMM Queue Execution Protocol v0.4

Protocol identity: `vmm.execution/0.4`

## Purpose

This protocol carries authoritative VMM external execution lifecycle messages. It is transport-neutral at the semantic level and is currently persisted through Queue Fabric v0.9-dev4.

## Persistent payloads

The persistent payload type IDs remain:

- `vmm.execution.command/1`
- `vmm.execution.ack/1`
- `vmm.execution.fill/1`
- `vmm.execution.reject/1`
- `vmm.execution.cancel/1`
- `vmm.execution.reconcile/1`

v0.4 extends command/fill state with optional smart-routing fields rather than changing the persistent type IDs.

## Execution command

`VMMExecutionCommand` carries order/correlation/idempotency identity, exact instrument line, side, notional, order type, origin evidence and authority. v0.4 additionally permits:

- `routeId`
- `targetAdapterId`

The base v0.3-style queue service leaves these blank. Smart execution requires them and sends the command only to that route's dedicated queue.

## Fill event

`VMMExecutionFillEvent` retains the venue execution reference and economics. v0.4 optionally adds:

- `routeId`
- `feeAmount`
- `rebateAmount`

These amounts are execution facts, not estimates. Booking the fill updates VMM trading cash by trade economics minus fee plus rebate. Order-level fee/rebate totals aggregate across partial fills.

## Lifecycle

```text
CREATED
  -> RISK_ACCEPTED
  -> ROUTED
  -> ACKNOWLEDGED
  -> PART_FILLED
  -> FILLED

ROUTED / ACKNOWLEDGED / PART_FILLED
  -> CANCEL_PENDING
  -> CANCELLED

ROUTED / ACKNOWLEDGED
  -> UNKNOWN_PENDING_RECONCILIATION
  -> ACKNOWLEDGED | REJECTED | CANCELLED | UNKNOWN_PENDING_RECONCILIATION
```

A timeout does not mean rejection. A cancellation request does not mean cancellation. A fill is booked as fact even when it races a later kill-switch command.

## Smart route queues

`VMMSmartExecutionService` uses:

- one permanent command queue `VMM.EXECUTION.ROUTE.<routeId>` for every `VMMVenueRoute`;
- one permanent shared event queue `VMM.EXECUTION.SMART.EVENT`.

The VMM smart-router principal may PUT/BROWSE route command queues and GET/BROWSE the event queue. Each venue adapter principal may GET/BROWSE only its registered route queue and PUT to the event queue. An adapter ID mismatch is rejected before event application.

## JSON

The JSON adapter follows `vmm.execution/0.4`. Route ID and fee/rebate fields are optional on fill events. JSON parsing only creates/publishes queue events; it does not call VMM inventory/P&L methods directly.
