# FederationBank Relationship Adapter Service v0.1

Durable service wrapper around `federationbank_relationship_adapter_v0.1`.

Commands:
- `FBREL.ACTION.SUBMIT`
- `FBREL.ACTION.RESULT.RECORD`
- `FBREL.ACTION.GET`

The service persists action correlation and idempotency before treating an action as committed, retains an outbox for at-least-once event delivery, and records the eventual Core Banking result without rewriting it. A specialist decision that translates to `NO_BANK_ACTION` creates a durable service action/event but no banking command.

The bank port routes only to FederationBank Account/Payments ingress. There is intentionally no Ledger submission route.

## Deliberate current boundary

The adapter emits an honest `STAFF` channel command. The unmodified FederationBank v0.9 fixture policy does not presently provide a generic STAFF policy rule for the tested transfer path, so the end-to-end qualification deliberately proves that Core Banking rejects the command with `LIMIT_POLICY_NO_RULE`. This is not patched around in the adapter: staff authority/policy is the next Core Banking concern and remains independently governed.
