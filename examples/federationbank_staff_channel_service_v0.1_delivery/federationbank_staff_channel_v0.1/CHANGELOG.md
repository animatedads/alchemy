# Changelog

## v0.1 — 2026-08-26

- Introduced policy-driven Staff Channel orchestration independent of UI.
- Added exact durable `FederationBankCommand` snapshots for Staff Channel work.
- Added explicit `CUSTOMER_INSTRUCTION` versus `RELATIONSHIP_DECISION` origins.
- Added durable Relationship Adapter evidence with exact translated-command identity binding.
- Added first-class `NO_BANK_ACTION` outcome.
- Added Staff Authority port and local engine adapter.
- Added maker/checker resumable work state.
- Added policy-controlled `ACCOUNT`, `PAYMENTS` and `NONE` Core routes.
- Added `READY_FOR_CORE` state and exact bound-command snapshot for write-ahead service persistence.
- Added distinction between Core institutional rejection and Core transport/delivery failure.
- Added optional Relationship Adapter -> Staff Channel bridge.
- Qualified direct, relationship-driven and Core-policy-denial end-to-end paths.
