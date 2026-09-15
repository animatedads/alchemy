# Changelog

## v0.2

- Adopts FederationBank Staff Authority v0.2.
- Persists `CUSTOMER` / `INSTITUTIONAL` authority scope on durable authority records.
- Carries scope in authority-issued and approval-required event payloads.
- Advances service state format to `/2` while registering and recovering legacy `/1` state and domain graph types.
- Adds institutional scope restart coverage.

## v0.1

Initial durable Staff Authority service with context cache, approval workflow, semantic idempotency, durable outbox and Queue Fabric recovery.
