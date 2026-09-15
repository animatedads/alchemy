# Changelog

## v0.4

- Qualified against FederationBank Merchant Bank v0.13.
- Adds `RISK.REMEDIATION.PLAN.PROPOSE`, `RISK.REMEDIATION.PLAN.APPROVE` and `RISK.REMEDIATION.PLAN.LIST`.
- Proposal identity is bound to the authenticated Merchant Risk maker; approval is restricted to `MERCHANT_RISK_APPROVER` and the Merchant domain enforces independent maker/checker.
- Plan command fingerprints include the complete ordered plan/approval semantics for idempotency conflict detection.
- Queue commands use scalar/collection plan specifications and return bounded scalar plan projections, keeping Merchant-domain plan objects off the Queue Fabric persistence boundary.
- Adds a Queue Fabric regression for plan proposal/reply serialization.
- The service still exposes no remediation execution, close-position, collateral-realisation, Core Banking or settlement command.
- Adds regressions for balanced maker/checker planning and wrong-way replacement-plan rejection.
- Adds `RISK.REMEDIATION.PLAN.EXECUTION.INGEST` and `RISK.REMEDIATION.PLAN.EXECUTION.LIST` for attributable post-action evidence; there is still no execution command.
- Execution-evidence source authority is bound to the authenticated service actor, not accepted from caller payload.
- When all plan-step evidence is present the service asks Merchant Bank for a fresh whole-book assessment and execution verification; deviations create durable `REMEDIATION_PLAN_EXECUTION_DEVIATION` work.
- Adds direct and Queue Fabric regressions for matched execution, wrong-way execution/work creation, authority spoof prevention and scalar evidence transport.


## v0.2

- Qualified against FederationBank Merchant Bank v0.11.
- Adds two-phase market-structure fan-out into customer-rooted CFD hedge-book assessment.
- Existing per-hedge response rows now include `rootTradeId`, `bookAssessmentId`, `bookState` and `netBaseExposure`.
- Adds durable whole-book work classification for directional residual, impaired contracts, unproved equivalence and counterparty risk.
- Adds privileged `RISK.BOOK.REASSESS`.
- Adds semantic market-structure event redelivery handling across different command IDs and rejects conflicting reuse of an event ID.
- Upgrades work/state persistence to v2 while registering/restoring legacy v1 types.
- Adds regressions for net-zero-impaired books, FX-driven directional residual, manual book reassessment, event redelivery/conflict, and v0.1 durable-state/work restoration.

## v0.1

- Initial operational Merchant Risk surveillance service.
- Exact settlement-line event fan-out through Merchant Bank v0.10 discovery API.
- Automatic current-evidence risk reassessment and remediation-work creation.
- Command idempotency and role boundary tests.
- Queue Fabric worker and durable service-state store.
