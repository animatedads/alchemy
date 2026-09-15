# FederationBank v0.9 ATM partial-cash feedback

ATM v0.1.6 found and closes a client-side crash window around bank-issued offline cash authority, and exposes one corresponding bank-side reconciliation edge.

## 1. Claim authority before the device call

A bank-issued offline authority must not remain locally `ACTIVE` while an irreversible dispenser operation is in progress.

ATM v0.1.6 now fsyncs:

```text
OFFLINE_AUTHORITY -> CLAIMED_LOCALLY
OFFLINE_WITHDRAWAL -> DISPENSE_STARTED
```

before calling `CashDispenser.dispense()`.

The resulting rules are deliberately conservative:

- durable zero cash -> claim may return to `ACTIVE`;
- any non-zero cash -> authority becomes `CONSUMED_LOCALLY`;
- restart with only `DISPENSE_STARTED` -> authority becomes `QUARANTINED_LOCALLY`;
- quarantined/consumed authorities are never selected for another physical vend.

This prevents a crash after device start from turning one bank authority into two physical cash events.

## 2. Partial cash is the actual monetary advice amount

If a customer requests 10000 minor units and the device reports only 5000 physically dispensed, the advice must say:

```json
{
  "requestedAmountMinor": 10000,
  "amountMinor": 5000,
  "dispensedMinor": 5000
}
```

`amountMinor` is the amount to settle. `requestedAmountMinor` is customer-intent evidence only.

The gateway candidate rejects `amountMinor != dispensedMinor` with:

```text
ATM_OFFLINE_DISPENSE_AMOUNT_MISMATCH
```

before monetary work begins.

## 3. RESERVED_ALLOWANCE partial consumption

Stock FederationBank v0.9 requires `hold.amountMinor == settlement amount` in `consumeAtmWithdrawalHold`. Therefore a 10000 reservation followed by a 5000 partial physical dispense returns `ATM_HOLD_MISMATCH`. Book balance remains unchanged and the full 10000 hold remains active.

That is safe but operationally stranded: the ATM must not reuse the single-use authority, while the customer still has the unused reservation held.

The supplied candidate patch changes the reservation rule to:

```text
0 < actual cash <= reserved ceiling
```

and then releases the entire single-use hold after posting the actual cash amount. The result records:

```text
reservedMinor
unusedReservedMinor
```

For 10000 reserved / 5000 dispensed:

```text
customer debit        5000
ATM cash settlement   5000
reservedMinor        10000
unusedReservedMinor   5000
active hold              0
```

An online `WITHDRAW_COMMIT` remains exact in practice because the ATM gateway derives its amount from the Ledger hold rather than from a client-supplied partial amount.

## Candidate patch

`integration/oorexx/federationbank_v0.9_atm_partial_reservation.patch`

The patch is intentionally separate from the bank package and is not presented as a FederationBank v0.9 replacement release.

## Qualification

Against the consolidated dependency roll-up and delivered dev7-fb1 bridge:

- stock v0.9 delegated partial stand-in settles the actual amount: PASS;
- stock v0.9 reserved partial exposes `ATM_HOLD_MISMATCH` and leaves the hold active: reproduced;
- v0.9 + candidate patch reserved partial settles actual cash and releases unused hold: PASS;
- mismatched `amountMinor` / `dispensedMinor`: rejected before money moves;
- existing ATM protocol, ATM money, offline-authority, mandatory-settlement and hold lifecycle tests: PASS.

## Separate remaining issue

Authority expiry versus delayed advice remains a separate policy/evidence problem. `dispensedAt` is evidence but should not become unrestricted authority to backdate a transaction. That issue is not weakened by this partial-cash patch.
