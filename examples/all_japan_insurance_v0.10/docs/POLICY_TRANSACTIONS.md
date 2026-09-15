# AJI policy financial transactions — v0.10

This module sits between rating/policy authority and Accounting. Premium calculation answers **what the contract costs**; the billing subledger answers **when and how that amount is due, collected, credited or rescheduled**.

## Authorities

- `PREMIUM_BILLING_AUTHORITY` — schedules, billing items, receipts, allocation and refunds.
- `PREMIUM_CREDIT_CONTROL_AUTHORITY` — arrears notices/cure evidence.
- `POLICY_TRANSACTION_AUTHORITY` — endorsements, cancellation and reinstatement.
- `RATING_ENGINE` — adjustment/re-rating calculations.
- `COMMISSION_SETTLEMENT_AUTHORITY` — producer settlement/recovery.
- `PREMIUM_TAX_SETTLEMENT_AUTHORITY` — premium-tax remittance/recovery.

Group ownership grants none of these automatically.

## Billing-item model

Each immutable billing item carries:

- policy;
- schedule-version ref;
- source ref/type;
- sequence and due date;
- `DEBIT` or `CREDIT`;
- exact whole-minor-unit amount and currency;
- creation time.

Initial policy instalments become `INITIAL_INSTALMENT` debit items. Authorised premium adjustments become `PREMIUM_ADJUSTMENT` debit/credit items when billing explicitly schedules them.

## Schedule revisions

A schedule revision is an immutable branch from the current billing schedule.

It names:

- revision ID;
- policy ID;
- exact predecessor ref;
- effective date;
- reason/evidence context;
- debit item IDs to replace;
- replacement debit items.

AJI rejects a stale predecessor. Replaced items must still have open balance and must not already be due before the revision effective date.

For each replaced item AJI creates a `SCHEDULE_REVERSAL` credit equal to its exact open amount and allocates that credit only to the specified old item. Replacement debit total must equal reversal total, so a scheduling operation cannot itself change written premium.

Executable schedule-replacement identity:

`AJI.BILLING.REVISION.REPLACE_OPEN_FUTURE/1`

Economic premium changes must instead enter through a calculation-backed premium adjustment.

## Receipts and allocation

A generic `AllJapanInsuranceBillingReceipt` requires payer, amount/currency, receipt time, payment reference and bank evidence.

Allocation function:

`AJI.BILLING.ALLOCATE.OLDEST_DUE/1`

A new receipt or credit is applied to the oldest open debit by due date then item ID. If a new debit appears later, AJI first consumes existing unapplied credit, then unapplied cash.

Direct collection attempts associated with an original instalment remain exact-target operations and are mirrored into the same allocation records.

## Unapplied cash and credit

A receipt may be larger than the currently open debit balance. AJI retains the remainder as `unappliedCashMinor`.

A return-premium adjustment on a fully settled policy similarly creates an unapplied credit item.

`billingPosition()` reports open debit, unapplied credit, unapplied cash and net debit. These are operational billing facts; they do not themselves create or change premium economics.

## Endorsements

Mid-term changes remain calculation-backed under the exact bound product program. Once the policy transaction is authorised, Billing may create a debit or credit item for the adjustment. The billing item cannot manufacture a premium amount different from the authorised adjustment.

## Cancellation and reinstatement

Cancellation remains calculation-backed and coverage-ending. Its negative premium adjustment can now be represented as a billing credit.

No-gap reinstatement remains a separate authorised policy event with a positive restoration adjustment. The resulting debit can consume the existing cancellation credit without recording fictional cash.

Gap-bearing reinstatement remains unsupported.

## Arrears and non-payment

`arrearsAsOf()` derives overdue open debit items from the billing subledger. This includes revised schedule items and billed premium adjustments.

Non-payment notices therefore freeze the current subledger-derived arrears position. Cancellation still requires the notice/cure workflow and the standard cancellation calculation.

## Accounting boundary

Billing owns operational allocation. Accounting owns immutable GL posting.

Creating or changing an allocation after cash receipt does **not** repost cash. The receipt accounting event freezes the applied/unapplied split observed at receipt time and remains replay-stable thereafter.

## Deferred

- delinquency-stage state machine;
- premium impairment/write-off;
- financing/interest charges;
- refund as explicit consumption of billing credit/cash sources;
- gap reinstatement;
- FX.
