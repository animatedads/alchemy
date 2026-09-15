# Changelog

## v0.1

Initial durable service cut for FederationBank Staff Authority.

- Adds staff context cache command/read boundary.
- Adds exact-action checker approval recording.
- Adds maker/checker action authorization command and durable authority records.
- Adds semantic command idempotency/conflict detection.
- Adds append-only durable service state via Queue Durable Store.
- Adds at-least-once event outbox with stable event identities and correlation/causation.
- Adds typed Queue Fabric command/reply/event/state persistence factories.
- Adds temporary and permanent Queue Fabric worker support.
- Adds Runtime Registry-shaped service module boundary.
- Explicitly exposes no Ledger ingress and does not execute Core Banking commands.
