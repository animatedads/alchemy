# Settlement rounding contract — v0.7

Accounting Core separates **tax calculation rounding** from **settlement rounding**.

Tax determination decides the legally relevant tax amount. Settlement rounding decides the amount actually collected or paid after an invoice or other obligation already exists. A settlement adjustment is never allowed to rewrite the previously determined tax amount.

## APIs

- `accounting.settlement/0.1`
- `accounting.settlement.request/0.1`
- `accounting.settlement.determination/0.1`

## Election model

`AccountingSettlementRoundingElection` is effective-dated and belongs to one legal entity. It freezes:

- jurisdiction
- currency
- exact ruleset reference and identity
- rounding algorithm reference
- rounding quantum in integer minor units
- applicable tender classes (`*` means all)
- immutable election identity

Tender applicability is explicit. The core does **not** infer that settlement rounding is cash-only. Disjoint tender elections for the same jurisdiction/currency may coexist; overlapping tender scopes for overlapping dates are rejected.

Examples:

- Swedish-style policy: SEK, quantum 100 öre, all settlement tenders.
- cash-only policy: CAD, quantum 5 cents, `PHYSICAL_CASH` only.

These are qualification shapes, not bundled statements of jurisdiction law.

## Determination

An `AccountingSettlementRequest` carries the already-accounted amount, currency, tender class and exact election reference. External `AccountingSettlementPolicy` code selected by exact ruleset identity returns an `AccountingSettlementDetermination` containing:

- accounted amount
- settled amount
- signed rounding difference
- election reference and identity
- executable policy reference and identity
- ruleset reference and identity
- rounding algorithm reference
- rounding quantum
- tender class and jurisdiction
- request fingerprint and evidence

The determination becomes an ordinary `AccountingEvent` of type `SETTLEMENT_ROUNDING_DETERMINED`. Entity accounting policy, not settlement policy, selects GL accounts.

## Replay

Once accounted, `transactSettlement()` checks the durable journal's settlement-request fingerprint before election or policy dispatch. Exact replay returns `DUPLICATE`; changed reuse of the same settlement source identity returns `SOURCE_SETTLEMENT_EVENT_CONFLICT`.

## Rounding primitives

v0.7 adds neutral `HALF_EVEN` support alongside the existing exact rounding primitives. `AccountingSettlementMath~roundToQuantum()` performs integer-minor-unit quantum rounding under `DIGITS 50`.

The jurisdiction policy remains responsible for deciding whether a primitive is legally applicable.
