# Validation

Qualified on ooRexx 5.3.0 r13196 against the current FederationBank/API component closure.

Acceptance evidence:

- 8/8 executable service tests pass.
- Staff context snapshots are stored and used to issue maker authority.
- Maker/checker workflow rejects self-approval and accepts an eligible supervisor approval.
- Command idempotency is semantic; conflicting reuse is rejected.
- Event delivery failure leaves committed state in an at-least-once outbox and later retry succeeds.
- Durable state, typed domain graph and idempotency receipts recover across restart.
- Permanent Queue Fabric recovers a typed Staff Authority command graph after queue-manager reconstruction.
- Service-issued authority can bind only the exact Core Banking command and its evidence survives that boundary.
- Runtime Registry-shaped service boundary is executable.
- All 5 service `.cls` files pass `rexxc`.

See `VALIDATION_TRANSCRIPT.txt` for executed evidence.
