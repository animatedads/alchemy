# Changelog

## v0.1

- Initial durable service boundary around FederationBank Teller Cash v0.1.
- Added `SUBMIT`, `RESUME`, `RECOVER` and `GET` command contract.
- Persist exact Staff Channel request and exact physical Teller Cash instruction together.
- Add semantic command idempotency spanning monetary and physical effects.
- Add restart-safe `READY_FOR_CORE` recovery using a distinct internal Staff Channel recovery command identity.
- Add typed Queue Fabric graph persistence and permanent command recovery.
- Add stable service event identities and at-least-once outbox delivery.
- Preserve Staff maker/checker independently from Till physical checker approval.
- Preserve Core institutional rejection separately from Core transport failure.
- Preserve post-Core `COMPENSATION_REQUIRED` and post-cash `RECONCILIATION_REQUIRED` as first-class work.
- Validate durable instruction snapshots where optional approval fields are empty.
- Explicitly prove no ATM semantics in the full chain.
