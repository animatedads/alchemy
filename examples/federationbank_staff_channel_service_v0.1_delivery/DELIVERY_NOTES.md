# FederationBank Staff Channel v0.1 — Complete Delivery

This delivery contains the matching domain and service packages:

- `federationbank_staff_channel_v0.1/`
- `federationbank_staff_channel_service_v0.1/`

## Architectural boundary

The Staff Channel coordinates an already-proposed banking action through independent Relationship authority (where applicable), Staff Authority, and finally the unchanged FederationBank Core Banking authority. It does not become any of those authorities and contains no UI/browser implementation.

Direct customer instructions and Relationship Case decisions are distinct origins. Relationship-derived actions must retain exact Relationship Adapter evidence. Staff approval is bound to the exact action. `NO_BANK_ACTION` is a first-class coordinated outcome.

The service writes a `READY_FOR_CORE` work record durably before invoking Core Banking. If Core transport fails, restart/replay resumes the same exact Core command identity. Durable service state, semantic command receipts, stable events and the at-least-once outbox use Queue Fabric graph persistence.

## Qualification

Qualified under Open Object Rexx 5.3.0 r13196 — Internal Test Version:

- Staff Channel domain: 8/8 executable tests pass; 5/5 `.cls` files pass `rexxc`.
- Staff Channel Service: 9/9 executable tests pass; 6/6 `.cls` files pass `rexxc`.
- Full chain exercised: Relationship Case authority -> Relationship Adapter -> Staff Channel Service -> Staff Authority Service -> Core Banking -> Ledger.
- Fault probe exercised: service persists `READY_FOR_CORE`, Core port fails before monetary movement, a new service instance recovers the work, and replay completes the same Core command once.

See each package's `VALIDATION.md` and `VALIDATION_TRANSCRIPT.txt` for evidence.
