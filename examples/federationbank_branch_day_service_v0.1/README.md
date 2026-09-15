# FederationBank Branch Day Service v0.1

Durable service boundary for Branch Day create/open/begin-close/close/get operations.

Commands:

- `FBBRANCHDAY.DAY.CREATE`
- `FBBRANCHDAY.DAY.OPEN`
- `FBBRANCHDAY.DAY.BEGIN_CLOSE`
- `FBBRANCHDAY.DAY.CLOSE`
- `FBBRANCHDAY.DAY.GET`

The service provides semantic command idempotency, append-only durable Queue Fabric graph checkpoints, restart recovery, stable service events and an at-least-once event outbox. A failed closing certification remains explicitly `CLOSING`; the service does not turn an unresolved physical-cash exception into a successful close.
