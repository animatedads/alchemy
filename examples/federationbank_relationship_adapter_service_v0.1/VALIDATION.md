# Validation

Qualified on ooRexx 5.3.0 r13196 (Internal Test Version, build 3 Aug 2026) against the component closure from `oorexxapis(20260826-014526).zip`.

Acceptance:
- 8/8 executable service tests pass.
- Core Banking result correlation retains Core authority.
- `NO_BANK_ACTION` is durable and does not submit a bank command.
- Command idempotency prevents duplicate bank submission.
- Event delivery failure leaves committed service state in an at-least-once outbox.
- Durable service state and idempotency receipts recover across restart.
- Permanent Queue Fabric recovers a typed decision/request/case command graph.
- Bank submission port exposes Account/Payments routes and no Ledger ingress.
- Runtime Registry-shaped service module boundary is executable.
- All package `.cls` files pass `rexxc`.

See `VALIDATION_TRANSCRIPT.txt` for the executed evidence.
