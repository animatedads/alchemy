# AJI JPY accounting boundary — v0.10

All Japan Insurance remains a separate legal entity and book:

- legal entity: `ALL_JAPAN_INSURANCE_CO_LTD`
- book: `AJI-STAT`
- functional currency: `JPY`
- JPY exponent: `0`
- one `amountMinor` is exactly ¥1

Insurance/rating/billing/claims truth remains outside Accounting Core. Accounting Core v0.7 owns immutable journal mechanics, durable replay and generic accounting policy infrastructure.

## Sealed chart retained

- `1000` Cash
- `1100` Premium receivable / policy customer-credit control
- `2200` Insurance premium control
- `2210` Commission payable / authorised producer recovery control
- `2220` Premium tax payable / authorised tax recovery control
- `2230` Claims outstanding
- `6100` Claims incurred control

v0.10 does not mutate the chart.

## Existing events retained

- `POLICY_BOUND`
- `PREMIUM_COLLECTED`
- `POLICY_PREMIUM_ADJUSTED`
- `COMMISSION_PAID`
- `COMMISSION_RECOVERED`
- `POLICYHOLDER_REFUND_PAID`
- `PREMIUM_TAX_REMITTED`
- `PREMIUM_TAX_RECOVERED`
- `CLAIM_RESERVE_CHANGED`
- `CLAIM_PAID`

Their existing policy identities remain stable where semantics are unchanged.

## New `BILLING_CASH_RECEIVED`

The generic billing receipt path is deliberately different from legacy instalment-specific collection.

Input evidence includes:

- billing receipt ID;
- policy and payer;
- amount/currency;
- payment/bank evidence;
- `appliedAtReceiptMinor`;
- `unappliedAtReceiptMinor`.

Accounting verifies:

```text
appliedAtReceiptMinor
+ unappliedAtReceiptMinor
= amountMinor
```

and posts:

```text
Dr 1000 Cash
    Cr 1100 Premium receivable / customer-credit control
```

If the receipt exceeds existing receivable, account 1100 may become a credit. That is a policy/customer-credit control position, not insurance revenue.

The accounting source event uses the **receipt-time** allocation snapshot. Later operational allocation of previously unapplied cash does not alter the historical cash event. Replaying the same receipt after a later premium debit therefore returns the original journal as `DUPLICATE`.

## Accounting Core v0.7

AJI consumes the same event/transaction/posting/store contracts it used previously, now qualified against Accounting Core v0.7.

v0.7 also supplies:

- generic tax determination;
- statutory scope/reporting boundaries;
- settlement-rounding election/determination.

Those capabilities are available for later AJI policy modules. v0.10 does not infer a Japan premium-tax or settlement rule merely because the generic machinery exists.

## Precision and persistence

`AllJapanInsuranceAccounting.cls` uses `::OPTIONS DIGITS 50`. Accounting Core v0.7 retains exact canonical integer money and durable replay-before-policy semantics. AJI's vendored Accounting Core v0.7 `src/` is byte-identical to the roll-up package.

## Foreign currency

Non-JPY posting still fails closed. FX must retain source currency/amount, JPY booked amount, rate/source/date and remeasurement evidence. FX is an accounting policy, not a rating side effect.

## Deferred accounting policy

v0.10 still deliberately does not assert:

- premium impairment/write-off;
- financing interest;
- full refund/customer-credit subledger reconciliation;
- jurisdiction-specific premium-tax determination;
- tender-specific settlement rounding;
- IFRS 17 / Japanese statutory insurance-contract measurement;
- insurance-service revenue recognition;
- acquisition-cost treatment;
- FX translation/remeasurement;
- group consolidation.
