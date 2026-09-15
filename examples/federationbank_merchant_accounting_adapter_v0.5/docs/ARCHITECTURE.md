# Merchant Accounting Adapter v0.5 architecture

```text
FederationBank Merchant Bank v0.15
  contracts / valuations / lifecycle / settlement evidence
                      |
                      v
federationbank.merchant.accounting.projection/0.2
  - validates actual Merchant object identity
  - binds close-out / risk-neutralisation execution
  - binds settlement obligation / instruction / observation
  - requires exact currency-scale evidence
  - emits bounded scalar Merchant accounting evidence
                      |
                      v
federationbank.merchant.accounting.event_projection/0.2
  Accounting Core accounting.event/0.1
                      |
                      v
AccountingEngine~transact()
  - exact FEDERATIONBANK_MERCHANT_BANK boundary
  - replay/conflict before policy execution
  - effective-dated Merchant policy resolution
  - exact executable policy identity
  - event/policy/evidence binding validation
                      |
                      v
Accounting Core v0.7
  accounting.posting/0.2
  accounting.store/0.1 (optional durable book)
                      |
                      v
independent FB-MERCHANT-STAT book
```

The flow is one-way with respect to Merchant authority. Accounting results do not mutate contracts, risk assessments, hedge state, close intent, collateral, settlement obligations, settlement instructions, settlement observations, custody or Retail/Core balances.

## Settlement authority split

Merchant owns three separate facts:

```text
MBSettlementObligation
      !=
MBSettlementInstructionEvidence
      !=
MBSettlementObservationEvidence
```

Accounting follows those facts rather than collapsing them.

An obligation bound to completed Merchant close-out/risk-neutralisation execution can create a settlement receivable/payable. An instruction creates no accounting cash movement. Only an externally attributable Merchant `PARTIAL` or `COMPLETE` observation can clear the recognised receivable/payable to cash at settlement agent. A failed observation does not post cash.

Merchant v0.15 independently deduplicates the external receipt by source authority plus external settlement reference. Accounting Core independently deduplicates the accounting source event. These are separate idempotency layers for separate authorities.

## Staged derivative settlement accounting

Cash settlement and derivative carrying-value derecognition are separate accounting claims.

```text
obligation recognised
  receivable/payable <-> derivative settlement control

external cash observed
  cash-at-settlement-agent <-> receivable/payable

control remains open
  until separate carrying-value/derecognition evidence
```

This prevents a successful transfer from being used as invented evidence for realised P&L or derivative derecognition.

## Book-bound settlement validation

Before a new settlement observation can post, the adapter checks the recognised obligation journal and all previously posted settlement-observation entries for that correlation. Counterparty, side, currency and cumulative clearing must agree with the accounting book. Over-clear attempts fail even if supplied scalar evidence claims a larger amount.

Exact replay is deliberately checked through Accounting Core before this validation. That preserves the v0.4 rule that an already-accounted source event returns `DUPLICATE`, while changed reuse returns `SOURCE_EVENT_CONFLICT` without being reinterpreted under current policy.

## Sealed chart migration boundary

A recovered v0.3 durable book can have a sealed chart without the v0.4 settlement accounts. v0.4 does not mutate that sealed history. Historical replay remains valid, but new settlement posting is gated by `SETTLEMENT_CHART_UPGRADE_REQUIRED`. A fresh v0.4 book carries the settlement account set.

## Replay, policy identity and precision

The source-event fingerprint is persisted on immutable journals. Semantic `policyRef` and exact executable `policyIdentity` remain distinct. Policy and bridge code use `NUMERIC DIGITS 50`; minor units are canonical exact integers and Merchant amounts require explicit exact currency-scale evidence before conversion.

## CFD close invariant

Customer close continues to produce a separate reversing Merchant contract. A reversing journal is not an accounting reversal of the original journal. `UI/client CLOSED` therefore cannot destroy the original CFD contract or its accounting evidence.

## Settlement amount determination boundary

Accounting Core v0.7 settlement-rounding support is used only as a determination service in v0.5. The adapter reconstructs contractual amount/currency/side/counterparty from the existing Merchant obligation journal, binds an explicit currency scale and settlement election, and calls `determineSettlement()`. It never calls `transactSettlement()` on this path.

A resulting `MBAccountingSettlementAmountDetermination` is evidence about a selected ruleset, not authority to rewrite the Merchant obligation. A non-zero difference is therefore labelled `MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED`; an exact result is labelled `MERCHANT_SETTLEMENT_OBSERVATION_REQUIRED`. Both are non-posting.

This deliberately prevents a legal/accounting rounding policy from becoming a hidden trade/settlement authority. If Merchant later supports contractual discharge adjustments, that must be represented by attributable Merchant-domain evidence and separately consumed by accounting.

