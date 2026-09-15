# Changelog

## v0.13

- Adds `MBHedgeRemediationPlanStepExecutionEvidence` as attributable post-action evidence for approved remediation-plan steps.
- Wrong-way, partial, failed and not-executed outcomes are retained as facts; contradictory execution is not discarded merely because it violates the plan.
- Adds `MBHedgeRemediationPlanExecutionVerification` and current-book verification against the approved projected net exposure.
- Verification checks step order, actual object semantics, signed exposure deltas, evidence-implied book exposure and the latest customer-rooted CFD book.
- A superseded whole-book assessment cannot verify execution.
- Plan lifecycle extends through `EXECUTING`, `EVIDENCE_COMPLETE`, `VERIFIED` and `DEVIATED`; verification still does not cure the underlying hedge-remediation obligation.
- Adds regressions for matched execution, retained wrong-way execution evidence and stale-book rejection.

## v0.12

- Adds `MBHedgeRemediationPlanStep`, `MBHedgeRemediationPlan` and `MBHedgeRemediationPlanApproval`.
- Plans are bound to the current whole-CFD-book assessment and the existing domain remediation obligation.
- A net-zero impaired book cannot stage a blind replacement that introduces directional exposure; replacement plans must also neutralise the impaired hedge leg.
- Directionally residual books require a plan whose projected absolute net exposure is strictly lower.
- Plans retain projected final net exposure and peak transient exposure during the ordered sequence.
- Approval is maker/checker: proposer and approver must differ, policy references must match, and a newer whole-book assessment makes the plan stale.
- Approval does not execute trades, move collateral, realise Core assets or settle cash.
- Adds three regressions for wrong-way plan rejection, balanced replacement approval and stale-plan rejection.


## v0.11

- Adds read-only `rootCFDTradeIdForHedge(hedgeId)` for resolving nested reversal/hedge legs back to the original customer-rooted CFD contract.
- Adds read-only `rootsAffectedByInstrumentEvidence(evidenceRef)` to deduplicate customer-rooted books affected by an exact instrument-resolution evidence record.
- Adds regression covering nested hedge ancestry and deduplicated root discovery.
- Preserves all v0.10 settlement-line surveillance discovery and all reconciled v0.9 whole-book/remediation semantics.
- No Core Banking, Ledger, collateral-realisation or settlement authority is added.

## v0.10

- Adds read-only `hedgeIds` inventory for operational Merchant Risk surveillance.
- Adds `hedgesAffectedByInstrumentEvidence(evidenceRef)` to identify hedge relationships whose exact product instrument-resolution evidence references the affected settlement line.
- The query uses the Merchant domain's private trade/product resolution and does not expose mutable product/trade maps to service layers.
- No valuation, margin, remediation, collateral, settlement or Core Banking authority semantics changed from reconciled v0.9.

# Changelog

## v0.9

- Reconciles the parallel Merchant Banking lineage into the v0.8 whole-book/remediation branch.
- Adds `MBInstrumentResolutionAttestation` and `attestProductInstrumentResolution()` with strict product-version, resolution-evidence and settlement-line matching.
- Adds `MBInstrumentIdentity~sameSettlementLineIdentity()` and explicit `SETTLEMENT_LINE_HEDGE` classification without weakening exact-contract identity.
- Adds first-class `MBMarketStructureEvent` recording and `applyMarketStructureEventToHedge()`; events are bound to exact instrument-resolution evidence and advance the immutable hedge-equivalence stream.
- Preserves immediate sanctions/custody/settlement impairment without requiring a price tick.
- Retains all v0.8 hedge remediation, whole CFD reversal-graph assessment, wrong-way replacement/double-down rejection and `MITIGATED_MONITORING` semantics.
- Adds donor-lineage positive/negative regressions for attestation, settlement-line hedge identity and market-structure event application.
- No Core/Retail Banking authority or implementation is added.


## v0.8

- Added `MBCFDHedgeBookAssessment` and recursive whole-book traversal from an original CFD through hedge/reversal relationships.
- Added aggregate gross/net base-currency exposure and contract/hedge counts.
- Added latest FX-by-pair and counterparty-risk-by-trade evidence indexes for whole-book reassessment.
- Added explicit states for directional residual, impaired-contract netting, unproved equivalence, counterparty residual and monitored net-zero books.
- Added `MITIGATED_MONITORING` remediation state for replacement/transfer activity proved at whole-book level.
- A healthy replacement pair cannot mitigate if aggregate directional exposure remains non-zero.
- Replacement mitigation requires all additional hedge relationships to have proved equivalence and permits only the original remediation hedge to remain impaired.
- Original contracts and the original impairment remain live/monitored after mitigation.
- Added regressions for wrong-way double-down replacement and properly neutralised/replaced hedge books.

## v0.7

- Added durable `MBHedgeRemediationObligation` bound to the triggering risk assessment and equivalence evidence.
- Added attributable `MBHedgeRemediationActionEvidence` for fungibility restoration, custody re-homing, replacement/transfer and risk-reduction actions.
- Resolution requires a current post-action risk assessment; stale proof is rejected.
- Restored/re-homed hedges resolve only when current equivalence evidence is healthy and the proof assessment binds that exact version.
- Risk reduction alone cannot erase an impaired hedge.
- Replacement/transfer resolution is deliberately blocked until aggregate-book proof exists, preventing a superficially healthy replacement from concealing doubled exposure.
- Added explicit policy-authorised remediation escalation with retained authority/reason evidence.
- Added `MBHedgeRiskAssessment~riskTotal` as a compact evidence metric for later aggregate remediation controls.
- Preserved all v0.6 contractual, sanctions, collateral, margin/default and arm's-length invariants.

## v0.6

- Added immutable, strictly versioned `MBHedgeEquivalenceEvidence`.
- Each later equivalence observation must advance exactly one version and explicitly supersede the current observation.
- Bound equivalence evidence to the exact instrument-resolution evidence for both contractual legs where such evidence exists.
- `MBHedgeRelationship` now retains the exact evidence reference supporting its current equivalence state.
- `MBHedgeRiskAssessment` retains the exact equivalence-evidence version it consumed.
- A new sanctions/custody/settlement/fungibility observation can immediately move a hedge to `HEDGE_IMPAIRED` without waiting for a new market-price observation.
- Historical equivalence evidence remains addressable; restoration creates a new version rather than rewriting the impairment.
- Added `reassessHedgeRiskFromLatestKnown`, which reuses the last known FX/basis/counterparty evidence (or sizing FX) so a legal/operational equivalence change can be risk-assessed without inventing a new market tick.
- Retained the older `MBHedgeFungibilityEvidence` API for compatibility; v0.6 evidence is the stronger versioned contract for new integrations.

## v0.5

- Added journalled `MBReferenceDocumentEvidence` and `MBInstrumentResolutionEvidence`.
- Extended `MBInstrumentIdentity` with denomination currency, settlement-line reference, place of safekeeping and resolution-evidence provenance.
- Exact-contract identity now includes those operational identity dimensions.
- Added evidence-bound identity factory and product-registration validation.
- Added Citi multi-listed ISO 15022 regression: same ISIN and venue can still require denomination/line disambiguation; safekeeping remains distinct provenance.


## v0.4

- Corrects CFD lifecycle semantics: client "close" is an offset/reversal intent, not destruction of the original CFD promise.
- Adds distinct contractual, client-view and risk states to derivative trades.
- Rejects direct CFD `close` lifecycle mutation.
- Adds wrong-way close protection: a close intent must use opposite direction and reduce absolute net exposure.
- Adds first-class `MBInstrumentIdentity` with economic underlying, ISIN, venue, representation, currencies, conversion ratio and issuer/depositary identity.
- Adds hedge classifications for exact offset, cross-listed, DLC, depositary and underlying-only relationships.
- Adds attributable FX evidence and retained sizing FX provenance.
- Adds ongoing hedge-risk assessments for translated FX drift.
- Adds explicit counterparty-current-exposure and replacement-cost evidence for imported/external hedges.
- Adds legal/operational fungibility evidence and `HEDGE_EQUIVALENCE_IMPAIRED` state transitions for sanctions, custody, settlement, transferability and liquidity failures.
- Adds basis-risk evidence for post-event market dislocation/illiquidity.
- Separates gross contractual exposure from risk exposure for margin/leverage calculations.
- Adds default `executeRiskNeutralisation` for CFDs; the original and reversing contracts remain active while the contractual difference is netted into an unsettled Merchant settlement obligation.
- Keeps legacy legal-lifecycle close-out for non-CFD contracts only.
- Separates customer open-position count from live monitored contract count in the Merchant position projection.
- Retains all v0.3 collateral, margin cure, default, arm's-length and journal invariants.

## v0.3

- Evidence-bound margin cure.
- Deadline/default orchestration.
- Whole-portfolio close-out/net contractual settlement.
- Collateral anti-double-counting.
