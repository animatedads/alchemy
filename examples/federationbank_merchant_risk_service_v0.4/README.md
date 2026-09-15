# FederationBank Merchant Risk Service v0.4

Operational surveillance around FederationBank Merchant Bank v0.13.

The service **does not own risk truth**. It accepts attributable market-structure notices, asks the Merchant domain which exact settlement-line-backed hedges and customer-rooted CFD books are affected, applies the event through the Merchant domain, triggers domain reassessment, and creates durable operational work from the resulting Merchant risk facts.

It deliberately has no `CURE`, `CLOSE_POSITION`, `POST_LEDGER`, collateral-realisation, cash-settlement or Core Banking command.

## Commands

- `RISK.WATCH.REGISTER` — privileged surveillance configuration for an existing Merchant hedge.
- `RISK.MARKET_STRUCTURE.INGEST` — records an attributable market/custody/sanctions notice and fans it out only to watched hedges referencing the exact affected `MBInstrumentResolutionEvidence`; after all affected hedges are updated, each unique customer-rooted CFD book is assessed once.
- `RISK.HEDGE.REASSESS` — asks Merchant Bank to reassess one watched hedge from current/latest-known evidence.
- `RISK.BOOK.REASSESS` — Merchant Risk asks the domain for a fresh whole-book assessment rooted at an explicit CFD contract. This creates a risk assessment fact and therefore is not a read-role operation.
- `RISK.WORK.LIST` — read-only list of open operational work.

## Whole-book operational classification

Market-structure fan-out now carries `rootTradeId`, `bookAssessmentId`, `bookState` and `netBaseExposure` on the existing per-hedge response rows. Non-ordinary whole-book states create distinct durable work:

- `CFD_BOOK_DIRECTIONAL_RESIDUAL`
- `CFD_BOOK_IMPAIRED_CONTRACTS`
- `CFD_BOOK_UNPROVED_EQUIVALENCE`
- `CFD_BOOK_COUNTERPARTY_RISK`

A net-zero book with ordinary monitoring does not create unnecessary book work. Individual `MBHedgeRemediationObligation` remains owned by Merchant Bank.

The fan-out is deliberately two-phase: all affected watched hedges receive the event/reassessment first; only then is each unique customer-rooted CFD graph assessed. This avoids publishing an intermediate book state when one event affects several legs in the same book.

## Delivery/idempotency

Command-id idempotency remains in place. v0.2 additionally treats the domain market-structure `eventId` as semantic identity: redelivery under a new transport command ID reuses the existing equivalence/risk/book facts and work; reusing the same event ID with different evidence is rejected as `EVENT_ID_CONFLICT`.

Durable work format/state are upgraded with backward restore support for v0.1 state/work records. Queue Fabric integration and the durable service-state store remain under `integration/`. Merchant Bank / Journal Pointed State remains the authority for derivative/risk truth; service persistence stores only watches, receipts, operational work and operational events.


## v0.4 — remediation planning, not execution

The service can now coordinate proposal and independent approval of Merchant-domain hedge-remediation plans. It never turns a plan into a trade. `RISK.REMEDIATION.PLAN.PROPOSE` and `...APPROVE` delegate all whole-book, policy, stale-baseline and maker/checker checks to Merchant Bank v0.13. `...PLAN.LIST` is read-only.

There is intentionally no `RISK.REMEDIATION.EXECUTE` command. Actual trade/custody/collateral actions must occur through their owning authorities and later return attributable action evidence to the Merchant domain.


### Queue boundary

Plan commands deliberately use arrays/directories of scalar fields on Queue Fabric. The service constructs the `MBHedgeRemediationPlan` inside the Merchant domain and returns a bounded scalar projection. This avoids making core Merchant-domain objects transport-persistence types simply for the convenience of the service queue.


## v0.4 execution-evidence orchestration

Risk Service still cannot execute a remediation plan. Instead, an owning Merchant execution authority can submit scalar evidence through `RISK.REMEDIATION.PLAN.EXECUTION.INGEST`. The service constructs the Merchant-domain evidence object internally and fixes `sourceAuthority` to the authenticated command actor; callers cannot spoof another authority by supplying that field.

When the final approved step has terminal evidence, the service asks Merchant Bank to create a fresh customer-rooted whole-book assessment and verifies the evidence against the approved projection. A matched result emits `HEDGE_REMEDIATION_PLAN_EXECUTION_VERIFIED`. A mismatch is retained and creates durable `REMEDIATION_PLAN_EXECUTION_DEVIATION` work plus a `HEDGE_REMEDIATION_PLAN_EXECUTION_DEVIATED` event.

`RISK.REMEDIATION.PLAN.EXECUTION.LIST` is observational. No service command cures the underlying remediation obligation, and no service command books a trade, moves collateral, settles cash or reaches into Core Banking.
