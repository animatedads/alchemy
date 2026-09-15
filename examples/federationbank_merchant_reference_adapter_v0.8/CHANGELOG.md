# Changelog

## v0.8

- Qualified against FederationBank Merchant Bank v0.13.
- Adds read-only `merchant_hedge_remediation_plans` rich relation over `MBHedgeRemediationPlan`.
- Exposes baseline assessment, projected/starting net exposure, peak transient exposure, maker/checker approval evidence and plan step count.
- Rich rows retain the original plan object; SQL cannot approve, execute or mutate plans.
- Adds a query/read-only regression for approved remediation plans.
- Extends the plan projection with execution/verification state and actual/projection exposure fields.
- Adds read-only `merchant_hedge_remediation_plan_execution` and `merchant_hedge_remediation_plan_verifications` rich relations.
- Rich rows preserve the originating `MBHedgeRemediationPlanStepExecutionEvidence` and `MBHedgeRemediationPlanExecutionVerification` objects; SQL cannot rewrite execution history or verification results.
- Adds a query/read-only regression for execution evidence, verification results and updated plan state.


## v0.6

- Dependency-only qualification against FederationBank Merchant Bank v0.11.
- No relation schema, mutation boundary, or rich-object provenance semantics changed.

## v0.5

- Qualified against reconciled FederationBank Merchant Bank v0.9.
- Adds read-only `merchant_instrument_attestations` rich relation.
- Adds read-only `merchant_market_structure_events` rich relation.
- Preserves original `MBInstrumentResolutionAttestation` / `MBMarketStructureEvent` objects on rich rows.
- Adds regression proving both relations are queryable and mutation is rejected.
- Preserves v0.4 instrument/equivalence/remediation/whole-book projections unchanged.


## v0.4

- Qualified against FederationBank Merchant Bank v0.8.
- Added read-only `merchant_cfd_hedge_book` rich relation.
- Projects aggregate contractual graph counts, gross/net base exposure, equivalence/remediation counts and counterparty/replacement risk.
- Rich rows retain exact trade/hedge membership via the original `MBCFDHedgeBookAssessment`.
- Preserved instrument, equivalence and remediation relations unchanged.

## v0.3

- Qualified against FederationBank Merchant Bank v0.8.
- Added read-only `merchant_hedge_remediation` rich relation.
- Preserves trigger assessment/equivalence evidence, policy, due time, action, resolution and escalation provenance.
- Rich rows retain the original `MBHedgeRemediationObligation` object.
- SQL mutation remains rejected.

## v0.2

- Qualified against FederationBank Merchant Bank v0.6.
- Added read-only `merchant_hedge_equivalence` rich relation over `MBHedgeEquivalenceEvidence`.
- Projects strict evidence version, supersession, effective time, legal/source provenance, both instrument-resolution references, fungibility assumptions, reason and equivalence state.
- Derives `is_current` without deleting superseded evidence.
- Preserves the originating `MBHedgeEquivalenceEvidence` object on every rich row.
- Added query regression covering healthy -> sanctions-impaired -> restored history.

## v0.1

- Added read-only `merchant_instrument_lines` rich relation.
- Preserves originating `MBInstrumentResolutionEvidence` on every projected row.
- Reuses NoSQLServer federated SQL selection and Structured Relation rich projection primitives.
- Added Citi-derived same-ISIN / same-venue / denomination-line selection regression.
