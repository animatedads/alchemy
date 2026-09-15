# Changelog

## v0.3
- Added durable `AUTHORISED` work state and exact Branch Cash authority envelope.
- Endpoint protocol now carries typed authority on both release and accept.
- Added authority persistence to work graph and Queue Fabric type registry.
- Corrected the policy seam so till-to-till and other non-vault routes are authorised before physical release.
- Retained v0.1 in-transit/reconciliation/idempotency semantics.

## v0.1
- Durable branch physical-cash transfer orchestration.
- Explicit in-transit custody and reconciliation.
- Idempotent endpoint contract, command receipts and at-least-once event outbox.
- Queue Fabric graph persistence and permanent command recovery.
