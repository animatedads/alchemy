# Generic tax determination contract (`accounting.tax/0.1`)

Accounting Core v0.6 adds a generic tax-determination seam without embedding any jurisdiction's substantive tax rules in the ledger.

## Boundary

```text
supply / economic evidence
        |
        v
AccountingTaxRequest / accounting.tax.request/0.1
        |
        +-- legal entity
        +-- tax point date
        +-- currency + minor exponent
        +-- exact signed calculation basis in minor units
        +-- TaxRegistration reference
        +-- elected calculation granularity
        +-- source/evidence/correlation/dimensions
        |
        v
AccountingEngine~determineTax()
        |
        +-- active TaxRegistration
        +-- effective TaxElection
        +-- exact rulesetIdentity
        +-- exact tax-policy implementation identity
        |
        v
jurisdiction tax policy package
        |
        +-- taxability / classification
        +-- rate / fraction / formula
        +-- election-specific rounding interpretation
        +-- exact rational calculation using DIGITS 50 mechanics
        |
        v
AccountingTaxDetermination / accounting.tax.determination/0.1
        |
        v
AccountingEngine~transactTax()
        |
        v
company AccountingPolicy -> immutable journal
```

The tax policy is outside Accounting Core. The core does not know that `20%` is a UK VAT rate, that `10%` is an Australian GST rate, whether a supply is zero-rated/exempt/reverse-charged, or who is liable. Those conclusions belong to jurisdiction policy fed by authoritative supply evidence.

## Tax registration is not domicile

`AccountingTaxRegistration` belongs to a legal entity independently of incorporation country or establishment. This deliberately supports a foreign legal entity with a UK VAT registration and no UK establishment object.

A tax request names the specific registration under which the determination is sought. The engine resolves the effective `AccountingTaxElection` for the tax point date.

## Election identity

An election carries:

- semantic `taxElectionId`
- immutable `taxElectionIdentity`
- `rulesetRef`
- immutable `rulesetIdentity`
- `roundingAlgorithmRef`
- `calculationGranularity`
- return/reporting scheme
- effective dates

The registration can remain stable while an allowed method changes prospectively. Overlapping elections for one registration remain forbidden.

A request whose granularity differs from the active election is rejected as `TAX_CALCULATION_GRANULARITY_MISMATCH`.

## Executable tax policy

`AccountingTaxPolicyCatalog` dispatches by exact `rulesetIdentity`, not by country name or a mutable "current VAT rules" label.

Each tax policy has:

- `taxPolicyRef`
- immutable `taxPolicyIdentity`
- `rulesetRef`
- immutable `rulesetIdentity`

Tax policy packages must declare `::OPTIONS DIGITS 50`; lower-precision packages are rejected at registration, just like entity accounting policies.

The determination is validated back against the request, registration, election and executable policy. A policy cannot quietly return a determination for a different VAT/GST registration, election, ruleset, tax point, currency or basis.

## Exact rational arithmetic

Tax calculation and ledger storage deliberately use different representations.

Ledger money is whole minor units. Tax calculations may naturally produce fractions of a minor unit, so v0.6 adds `AccountingTaxExactAmount`:

```text
exact tax amount = signed integer numerator / positive integer denominator
```

For example, applying 20/100 to a GBP basis of 999 pence is retained exactly as:

```text
19980 / 100 minor units = 199.8 pence
```

No binary floating point is involved.

`AccountingTaxExactAmount` supports reusable jurisdiction-neutral mechanics:

- exact `basis * numerator / denominator`
- quantization to a selected sub-minor denominator
- quantization by major-currency decimal places and currency minor exponent
- final whole-minor-unit rounding

Generic arithmetic modes supplied by the core are `HALF_UP`, `TRUNCATE`, `FLOOR`, and `CEILING`. A jurisdiction policy decides if and when one of those mechanics represents the elected legal method. The semantic election remains something like `HMRC-NEAREST-PENNY`; the core does not reinterpret that label itself.

Arithmetic that could exceed the 50-digit intermediate profile is rejected rather than silently rounded.

Signed exact amounts are supported so credit-note/reversal tax determinations can be represented. Company accounting policy decides how a negative determination maps into debit/credit journal lines.

## Transport contracts

`AccountingTaxRequestCodec` implements `accounting.tax.request/0.1`.

`AccountingTaxDeterminationCodec` implements `accounting.tax.determination/0.1` and carries the exact determination fingerprint.

The contracts use Directory/JSON-shaped values and do not require a caller to share an ooRexx object instance. Queue Fabric or another transport can therefore carry tax requests/determinations without becoming tax authority.

## Tax -> accounting conversion

`AccountingTaxDetermination~toAccountingEvent()` creates a normal `AccountingEvent` whose source reference is deterministic for the registration + source tax event.

The event carries:

- signed basis and tax amount
- currency / minor exponent
- tax registration
- exact election ref + identity
- exact ruleset ref + identity
- exact tax policy ref + identity
- rounding election reference
- tax code and calculation method
- pre-round exact numerator/denominator
- journal dimensions
- tax-request and determination fingerprints

The entity's ordinary `AccountingPolicy` still decides which GL accounts to debit/credit. Tax determination does not write journals directly.

## Durable replay

`AccountingEngine~transactTax()` checks an existing native journal before tax-policy dispatch using:

```text
TAXDET:<taxRegistrationRef>:<sourceTaxEventRef>
```

and the stored `accounting.taxRequestFingerprint`.

After a tax determination has been accounted and persisted:

```text
same tax source + same request fingerprint     -> DUPLICATE
same tax source + changed request fingerprint  -> SOURCE_TAX_EVENT_CONFLICT
```

This occurs before tax ruleset or accounting-policy dispatch. Recovery therefore cannot reinterpret an already-accounted invoice through a newer tax policy.

A determination that has not been posted is not represented as native ledger truth merely because it was calculated; durable tax-accounting identity begins when the determination enters the normal immutable accounting-event path.

## Regulatory examples used for qualification

The packaged UK and Australian policy classes are deliberately **demo/qualification policies**, not production tax advice or complete jurisdiction packs.

They exist only to prove that the same generic contract can dispatch different sovereign rulesets.

Current external guidance used to shape the examples includes:

- HMRC VAT Notice 700, sections 17.5-17.6: https://www.gov.uk/guidance/vat-guide-notice-700
- HMRC VATREC12020: https://www.gov.uk/hmrc-internal-manuals/vat-trader-records/vatrec12020
- HMRC VATREC12030: https://www.gov.uk/hmrc-internal-manuals/vat-trader-records/vatrec12030
- Australian Taxation Office tax-invoice/GST rounding guidance and GSTR materials: https://www.ato.gov.au/

A production UK VAT or Australian GST pack would need its own versioned legal/tax evidence, taxability rules, rates, place-of-supply logic, exemptions, reverse charge/deemed-supplier treatment, and effective-date qualification.
