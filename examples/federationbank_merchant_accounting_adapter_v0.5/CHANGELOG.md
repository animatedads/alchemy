# Changelog

## v0.5

- Adopts Accounting Core v0.7 while retaining the existing Merchant Bank v0.15 projection, fair-value, settlement-obligation and settlement-observation semantics unchanged.
- Adds `federationbank.merchant.accounting.settlement_amount/0.1`, a bounded non-posting projection for policy-determined settlement amounts.
- Settlement-amount requests cannot supply their own amount, currency, counterparty or receivable/payable side; those facts are recovered from the already-accounted Merchant settlement-obligation journal.
- Adds exact currency-minor-exponent versus `MBAccountingCurrencyScaleEvidence` binding before Accounting Core settlement policy dispatch.
- Delegates election/tender/ruleset/executable-policy resolution to Accounting Core v0.7 `determineSettlement()` and retains exact election, ruleset, policy, rounding algorithm, quantum, jurisdiction and request fingerprint evidence.
- A zero-difference determination remains non-cash evidence and requires Merchant external settlement observation.
- A non-zero determination returns `MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED`; Accounting Core policy output alone cannot amend or discharge `MBSettlementObligation`.
- Adds explicit fail-closed `postSettlementAmountDetermination()` so a caller cannot mistake determination for a posting command.
- Adds qualification for non-zero 5-minor-unit rounding, exact no-rounding determination, tender mismatch, currency-scale exponent mismatch and unaccounted-obligation rejection with zero additional journals.
- Retains all v0.4 settlement sequencing, accounting-book over-clear protection, durable replay, precision, CFD-close and sign-crossing guarantees.

## v0.4

- Advances the Merchant projection to `federationbank.merchant.accounting.projection/0.2` over FederationBank Merchant Bank v0.15 settlement evidence.
- Adds `MBAccountingSettlementObligationEvidence`, `MBAccountingSettlementInstructionObservation` and `MBAccountingSettlementObservationEvidence`.
- Adds Accounting Core event/policy mappings for `MERCHANT_DERIVATIVE_SETTLEMENT_OBLIGATION` and `MERCHANT_DERIVATIVE_SETTLEMENT_OBSERVED`.
- Recognises Merchant settlement receivables/payables only from actual Merchant obligations bound to completed close-out or risk-neutralisation execution evidence.
- Keeps settlement instruction/dispatch observations non-posting; instruction is never cash settlement evidence.
- Clears recognised settlement receivables/payables only from externally attributable Merchant `PARTIAL`/`COMPLETE` observations; `FAILED` observations produce no accounting cash posting.
- Preserves derivative carrying-value/P&L separation through explicit derivative-settlement control accounts; cash settlement completion does not fabricate derivative derecognition or realised P&L.
- Adds independent accounting-book binding checks for obligation, counterparty, side, currency and cumulative clearing amount, preventing scalar evidence from over-clearing a recognised obligation.
- Preserves Accounting Core replay-before-policy behavior by resolving exact replay/conflict before new settlement binding checks.
- Adds backward-compatible recovery of pre-v0.4 sealed Merchant accounting charts: historical replay remains available and new settlement posting is explicitly gated by `SETTLEMENT_CHART_UPGRADE_REQUIRED`.
- Retains the v0.3 Accounting Core v0.4 event/policy path, executable policy identity, durable replay, numeric-digits-50 boundary, exact currency scale, sign-crossing fair value and CFD close/non-destruction semantics.

## v0.3

- Migrated the operational posting boundary to Accounting Core v0.4 `AccountingEvent -> AccountingEngine~transact()` instead of direct operational journal posting.
- Added effective-dated Merchant executable accounting policies for fair-value movement and mark-transition events.
- Added exact release-scoped executable `policyIdentity`; posted journals retain policy identity, event type, source-event fingerprint, source authority, counterparty and evidence binding.
- Added `federationbank.merchant.accounting.event_projection/0.1` for normalized scalar `accounting.event/0.1` projections.
- Adopted the Accounting Core v0.4 `NUMERIC DIGITS 50` contract and `::OPTIONS DIGITS 50` policy package requirement.
- Hardened signed minor-unit validation to reject values wider than 50 significant digits before policy execution.
- Added durable Merchant accounting books via Accounting Core `accounting.store/0.1` with `createDurable()` / `recoverDurable()`.
- Added restart-safe qualification proving exact replay and changed-source conflict are resolved before policy dispatch, including with no Merchant policy registered after recovery.
- Retained exact currency-scale conversion, sign-crossing fair-value accounting, CFD close/non-destruction semantics and the lifecycle settlement-evidence gate from v0.2.

## v0.2

- Added `federationbank.merchant.accounting.projection/0.1` over Merchant Bank v0.14.
- Added explicit exact currency-scale evidence and atomic previous/current fair-value transitions.
- Bound projected postings to Merchant trade, market and valuation evidence.
- Derived reversing-CFD identity from the actual Merchant close-intent graph without reversing the original journal.
- Kept lifecycle evidence non-posting until attributable settlement evidence exists.
