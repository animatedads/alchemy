# Changelog

## v0.1

Initial FederationBank Staff Authority domain cut.

- Adds externally authoritative staff principal references and authenticated session/work context.
- Adds effective-dated role assignments, bounded delegation and bounded temporary elevation.
- Adds exact staff action intents and semantic action identities.
- Adds policy-driven maker/checker authority with distinct-actor enforcement.
- Adds exact-action-bound checker approvals.
- Adds Institutional Policy release provenance to authority decisions.
- Adds sealed staff authority envelopes and exact `FederationBankCommand` binding for channel `STAFF`.
- Adds Queue Fabric persistence forms for durable domain graph transport.
- Adds separate illustrative Core Banking STAFF-channel policy fixtures to prove staff authority does not replace customer/product policy.
- Adds optional Relationship Adapter bridge and an executable Relationship Case -> relationship authority -> staff authority -> Core Banking -> Ledger integration chain.
- Uses a fixed historical effective date for fixture Core Banking policy releases so command evaluation is independent of fixture construction timing.
