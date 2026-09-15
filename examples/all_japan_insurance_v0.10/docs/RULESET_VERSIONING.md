# Contract, rating and function versioning - AJI v0.10

Effective dating answers which release applies to a **new** transaction. A bound policy answers which exact releases were incorporated into that policy term. AJI records both and never treats them as interchangeable.

## Bound term

`PolicyContractLock` retains the exact contract version, rating identity/function and term lineage. `ProductRatingProgram` in turn pins product definition and coverage rate plans/functions. Claims execute the bound payout function and mid-term exposure re-rating uses the bound product program rather than current-rate resolution.

## Configuration identity versus executable identity

Rate values/rules and executable calculation order are versioned separately. An algorithmic semantic change requires a new function reference even if configuration values happen to be unchanged.

The v0.9 transaction-level executable identities remain unchanged in v0.10:

- `AJI.MIDTERM.RERATE.PINNED_PROGRAM/1`
- `AJI.REINSTATEMENT.RESTORE_CANCELLATION_RETURN/1`

## Accounting policy identity

Accounting policies are independently versioned from insurance functions. v0.10 retains all unchanged historical identities and adds only `aji.accounting.billing-cash-received/0.1` for the new generic overpayment-capable cash path. Receipt-time evidence is frozen so later billing allocation does not alter historical accounting identity.
