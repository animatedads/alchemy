# Changelog

## v0.1 — 2026-08-26

- Added durable Staff Channel work service.
- Added `ACTION.SUBMIT`, `ACTION.RESUME`, `ACTION.RECOVER`, `ACTION.GET` commands.
- Added semantic command idempotency and command-ID conflict protection.
- Added service-to-service adapter to FederationBank Staff Authority Service v0.1.
- Added write-ahead persistence of `READY_FOR_CORE` before Core submission.
- Added safe retry after Core transport failure and restart.
- Added durable typed work graph recovery.
- Added stable service events and at-least-once outbox.
- Added permanent Queue Fabric command/event support with typed graph recovery.
- Qualified complete Relationship Case -> Relationship Adapter -> Staff Channel Service -> Staff Authority Service -> Core Banking integration.
