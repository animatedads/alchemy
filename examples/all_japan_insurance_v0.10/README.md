# All Japan Insurance v0.10

Executable direct-insurance authority for Federation's acquisition of **All Japan Insurance**, covering `PI`, `HOME` and `CAR`. Federation Intermediaries remains a separate workstream and Federation ownership does not confer AJI underwriting, policy, billing, claims or accounting authority.

v0.10 preserves the accepted v0.9 product/risk/coverage rating, seven-part quotation arithmetic, immutable rate/contract/function identities, JPY legal-entity accounting, claims reserve/payment controls, mid-term re-rating, non-payment/no-gap reinstatement, commission recovery and premium-tax settlement. It adds the first complete **immutable billing subledger skeleton** and migrates AJI qualification to **Accounting Core v0.7** from the current `oorexxapis(20260828-191905).zip` roll-up.

## Entity and currency

- legal entity: `ALL_JAPAN_INSURANCE_CO_LTD`
- accounting book: `AJI-STAT`
- functional/statutory currency: `JPY`
- JPY exponent: `0`; one integer `amountMinor` is exactly **¥1**
- every rated cost carries currency explicitly
- non-JPY accounting still fails closed pending an explicit FX policy

Rating remains currency-aware but does not perform FX translation.

## Canonical quotation calculation retained

```text
fixed element
+ proportionate element up to step
+ proportionate element over step
+ underwriter fee if over underwriting risk
+ overage
+ commission / sales cost
+ taxes
```

PI/Home/Car still compose that common kernel through immutable product programs, risk objects, coverages, rate plans, factor tables and executable rating-function identities.

## Billing subledger

v0.10 separates **economic premium truth** from **when/how the customer is billed**.

The bound quotation and authorised premium adjustments remain the source of written-premium truth. The billing subledger records immutable debit/credit items and allocations:

```text
policy premium / adjustment
        |
        v
immutable billing item
  DEBIT or CREDIT
        |
        +--> schedule revision / replacement
        +--> bank receipt
        +--> credit allocation
        `--> arrears / customer-credit position
```

Initial instalments are mirrored into billing items. A schedule revision cannot mutate them; it creates exact reversal credits against specified still-open future debit items and issues new replacement debit items. The replacement total must equal the reversed outstanding total, and the revision must name the exact current predecessor schedule ref. Stale branches fail closed.

The executable replacement identity is:

`AJI.BILLING.REVISION.REPLACE_OPEN_FUTURE/1`

## Deterministic allocation

Cash receipts and billing credits are allocated through:

`AJI.BILLING.ALLOCATE.OLDEST_DUE/1`

For a newly received source, the target is the oldest open debit by due date then item identity. Existing unapplied credits are consumed before unapplied cash when a later debit appears. This gives deterministic behaviour for:

- revised instalment schedules;
- additional-premium endorsements;
- return-premium endorsements;
- cancellation credits;
- reinstatement debits;
- customer overpayments.

A direct collection attempt tied to an existing instalment keeps its original exact-target semantics and is mirrored into the same billing subledger.

## Overpayment and unapplied cash

Generic bank receipts may exceed currently open debit items. The excess is retained as explicit `unappliedCashMinor` rather than rejected or silently treated as revenue.

If a later authorised premium debit appears, the existing unapplied cash can be deterministically allocated to it without creating a second cash event.

Receipt-time allocation evidence is frozen. A later allocation therefore does not rewrite the accounting event for the historical receipt.

## Cancellation and reinstatement

The existing component-aware cancellation engine remains authoritative for return premium. v0.10 can now bill that negative adjustment as an explicit credit item. If the policy had already been settled, the return remains an unapplied customer credit.

A no-gap reinstatement creates its own positive premium adjustment/debit. That debit may be offset against the earlier cancellation credit without inventing new cash. Coverage authority and billing authority remain distinct.

## Arrears

`arrearsAsOf()` now resolves through the billing subledger rather than only the original instalment schedule. This means revised schedules and billed adjustment items participate in overdue-position calculation.

Non-payment notices therefore consume the current billing position, while the original schedule and all subsequent revisions remain historically inspectable.

## Accounting Core v0.7

AJI accounting API advances to:

`all.japan.insurance.accounting/0.5`

AJI still uses ordinary `AccountingEvent -> AccountingEngine~transact()` posting and the durable JPY book. Accounting Core v0.7 preserves those contracts while adding generic tax/scope/settlement facilities. AJI qualifies v0.7 without transferring insurance rating, billing or tax-law authority into Accounting Core.

A new event is added:

`BILLING_CASH_RECEIVED`

Posting is:

```text
Dr Cash (1000)
    Cr Premium receivable / customer-credit control (1100)
```

Unlike legacy instalment-specific `PREMIUM_COLLECTED`, this event may legitimately move account 1100 into a credit balance representing customer overpayment/unapplied cash. The accounting event retains the **receipt-time** applied/unapplied split, so replay remains stable even after subsequent billing allocations.

The sealed AJI chart remains unchanged.

## Deliberate open seams

v0.10 still does **not** claim completion of:

- delinquency stages, impairment and premium write-off;
- payment-plan finance charges or premium-finance integration;
- gap-bearing reinstatement;
- producer/customer refund allocation as a complete billing-source consumption model;
- FX translation/remeasurement;
- jurisdiction-specific premium-tax determination through Accounting Core v0.7 tax elections;
- settlement-rounding rules for particular tenders/jurisdictions;
- IFRS 17 or Japanese statutory insurance-contract measurement/presentation;
- group consolidation.

Those remain explicit policy layers rather than implicit arithmetic inside rating or billing.

## Qualification

`./run_tests.sh` compiles six AJI source classes plus three test-support classes and executes **62 ooRexx regression tests** under ooRexx 5.3.0 r13196.

All **58 v0.9 tests remain green**. Four v0.10 tests cover:

- Accounting Core v0.7 compatibility;
- immutable revised billing schedules and stale-predecessor rejection;
- overpayment/unapplied-cash accounting with replay-stable receipt evidence;
- cancellation-credit / reinstatement-debit allocation.

Accounting Core v0.7's independent upstream suite also passes, and AJI's vendored v0.7 `src/` is byte-identical to the roll-up copy.
