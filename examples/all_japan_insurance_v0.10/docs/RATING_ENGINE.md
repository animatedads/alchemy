# All Japan Insurance v0.10 rating engine

The deterministic single-coverage rating kernel and product-composition layer remain unchanged in v0.10. Every monetary cost retains explicit currency and every plan/program retains immutable configuration and executable-function identities.

## Base quotation decomposition

```text
fixed
+ proportionate(min(B, step), rate up to step)
+ proportionate(max(B-step, 0), rate over step)
+ underwriter fee when U exceeds authority threshold
+ overage on excess underwriting risk
+ commission / sales cost
+ taxes on each rule's declared taxable basis
```

Rating basis `B` and underwriting-risk basis `U` remain distinct.

## Product composition

A product program maps each selected coverage to one exact `RatePlan`; each `RatePlan` pins the executable `ratingFunctionRef`, factor tables, modifiers, minimum-premium and proration controls. Aggregated costs retain `riskRef`, `coverageCode`, sub-rating identity and currency.

## Mid-term transaction rule

A mid-term exposure change is priced as a **difference of two complete transaction-period product ratings**, not by mutating a previously calculated premium:

```text
Delta = Rate(pinned program, AFTER, transaction proration)
      - Rate(pinned program, BEFORE, transaction proration)
```

The transaction-layer calculation identity is `AJI.MIDTERM.RERATE.PINNED_PROGRAM/1`. The rating engine itself is not given permission to resolve a new current product program.

## Currency

Japanese AJI programmes default to JPY and JPY uses whole-yen integer amounts. Rating can represent another explicitly configured currency, but foreign-currency conversion is never performed here; AJI accounting rejects non-JPY until a versioned FX policy exists.
