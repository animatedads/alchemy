# Changelog

## v0.1

- Adds a durable service boundary around `federationbank_relationship_adapter_v0.1`.
- Adds idempotent action submission and explicit correlated Core Banking result ingestion.
- Persists action state before treating the relationship action as committed.
- Adds an at-least-once event outbox with stable event identities.
- Adds Queue Fabric persistent command/event transport and graph recovery.
- Adds an Account/Payments-only FederationBank port; there is intentionally no Ledger ingress.
- Preserves `NO_BANK_ACTION` as a first-class durable outcome.
- Preserves Core Banking rejection/failure as authoritative result rather than reinterpreting it.
