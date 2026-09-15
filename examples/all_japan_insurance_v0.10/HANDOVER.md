# Handover - All Japan Insurance v0.10

## Candidate baseline

`all_japan_insurance_v0.10.zip` supersedes v0.9 for the AJI direct-insurance workstream.

Current integration roll-up is `oorexxapis(20260828-191905).zip`. Its embedded `all_japan_insurance_v0.9.zip` is byte-identical to the accepted v0.9 predecessor, so v0.10 is a clean continuation rather than a divergent reconstruction.

AJI remains legal entity `ALL_JAPAN_INSURANCE_CO_LTD`, with JPY-only `AJI-STAT` accounting. Federation Intermediaries remains a separate workstream. VMM remains arm's-length.

## Retained invariants

1. Canonical seven-part quotation arithmetic is unchanged.
2. Bound product/rate/rating-function/contract/payout-function identities remain immutable.
3. Existing terms do not silently migrate to current rating or contract releases.
4. Insurance operational state remains upstream authority; Accounting does not become policy/claims/billing truth.
5. AJI functional/statutory book currency remains JPY with exponent 0.
6. Sealed account chart remains `1000`, `1100`, `2200`, `2210`, `2220`, `2230`, `6100`.
7. Non-JPY posting fails closed pending explicit FX policy.
8. Existing v0.9 accounting policy identities remain unchanged unless their semantics changed.

## Accounting dependency

v0.10 moves qualification from Accounting Core v0.4 to **Accounting Core v0.7** from the current roll-up.

- upstream ZIP SHA-256: `95b694d76e388613cafed39f752efe32ff8ce5d46401766aa2d63b9c147a5c76`
- vendored `src/`: 10/10 files byte-identical
- upstream independent suite: PASS
- AJI consumes the existing event/transaction/posting/store contracts; new tax/scope/settlement APIs are available but not treated as insurance authority.

## v0.10 billing additions

### Immutable billing items

Initial premium instalments are mirrored into explicit `DEBIT` billing items. Premium adjustments can be billed as signed economic consequences:

- positive adjustment -> `DEBIT` item;
- negative adjustment -> `CREDIT` item.

The economic adjustment must already exist under rating/policy transaction authority before `PREMIUM_BILLING_AUTHORITY` can schedule it.

### Schedule revision

`AllJapanInsuranceBillingScheduleRevision` replaces only specified **open future** debit items.

Requirements:

- exact current predecessor schedule ref;
- no stale branch;
- every replaced item belongs to the policy and remains open;
- no already-due item can be silently rescheduled;
- replacement debit total equals exact reversed outstanding total;
- replacement items name the revision as schedule/source identity.

Reversal credits are forced against their exact replaced debit. They cannot float onto unrelated balances.

Executable identity: `AJI.BILLING.REVISION.REPLACE_OPEN_FUTURE/1`.

### Allocation

`AJI.BILLING.ALLOCATE.OLDEST_DUE/1` provides deterministic allocation.

- incoming receipt/credit -> oldest open debit by due date then item ID;
- when a later debit appears, existing unapplied credits are consumed before unapplied cash;
- direct instalment collection retains exact-instament targeting.

### Overpayment

`AllJapanInsuranceBillingReceipt` supports bank-attributed receipts greater than the current open debit. Excess remains explicit unapplied cash.

`billingPosition(policyId)` exposes:

- `openDebitMinor`
- `unappliedCreditMinor`
- `unappliedCashMinor`
- signed `netDebitMinor`

A negative net debit is a customer-credit position, not revenue.

### Arrears

`arrearsAsOf()` now delegates to the billing subledger, so revised schedule items and billed adjustments participate in credit-control evidence.

## Accounting v0.10

AJI accounting advances to `all.japan.insurance.accounting/0.5` with new `BILLING_CASH_RECEIVED` policy/event identity.

Generic receipt:

```text
Dr Cash
    Cr 1100 Premium receivable / customer-credit control
```

The policy validates exact whole-yen amount plus `appliedAtReceiptMinor + unappliedAtReceiptMinor = amountMinor` and requires bank/payment evidence.

Receipt-time allocation is frozen operationally. If unapplied cash is later consumed by an endorsement debit, recreating the original accounting event produces the same fingerprint and returns `DUPLICATE`, not a changed historical event.

Legacy `PREMIUM_COLLECTED` remains available for exact instalment-specific collection and keeps its existing policy identity.

## Qualification

- AJI source/support compile: 9/9
- retained v0.9 tests: 58/58
- new v0.10 tests: 4/4
- total AJI tests: 62/62
- Accounting Core v0.7 upstream suite: PASS
- vendored Accounting Core v0.7 src: 10/10 byte-identical

Final packaging must regenerate `MANIFEST.sha256`, clean-unpack it and rerun the 62-test suite before promotion.

## Next work

Do not jump directly to IFRS 17.

The next domestic-JPY billing/accounting layer should be:

1. delinquency lifecycle/status from subledger arrears;
2. impairment/write-off authority and accounting;
3. refund consumption of unapplied credit/cash as first-class billing sources;
4. payment-plan revision rules after endorsement/cancellation;
5. only then explicit FX and jurisdiction-specific tax/settlement policy integration.
