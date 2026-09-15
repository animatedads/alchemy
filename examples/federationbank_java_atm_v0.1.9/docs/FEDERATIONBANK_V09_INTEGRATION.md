# FederationBank v0.9 integration

Java ATM v0.1.7 retains the v0.1.3 client half of FederationBank v0.9 offline cash authority and adds composed JMS-shaped v0.9 qualification plus stronger physical-cash recovery evidence.

## New bank operation

`GET_OFFLINE_ALLOWANCE` is requested while online for a selected customer account, currency, amount and authority mode. The ATM accepts only a returned authority whose terminal, customer, account, currency, ruleset/version and amount ceiling match its current authenticated context.

The complete bank authority envelope is written to the existing durable ATM journal before it can be used.

## Disconnected dispense

When disconnected, the ATM will vend only if it has an unexpired ACTIVE bank-issued authority matching the terminal/session/account/currency/current signed rules and amount. There is no terminal-generated fallback authority.

Before the dispenser is invoked, the authority is durably marked `CLAIMED_LOCALLY`. A known zero-cash failure can safely return it to `ACTIVE`; any non-zero dispense moves it to `CONSUMED_LOCALLY`; and an unknown post-start outcome is quarantined across restart so the same authority cannot trigger another physical vend. The physical event is retained as `ADVICE_PENDING` when cash is known to have left.

On reconnection the exact durable identity is replayed as `OFFLINE_WITHDRAWAL_ADVICE`. FederationBank v0.9 resolves the authority from retained bank state and applies either:

- `RESERVED_ALLOWANCE`: consume the Ledger-backed hold and commit the normal ATM withdrawal legs; or
- `DELEGATED_STAND_IN`: verify the prior delegated authority and commit mandatory settlement for cash already physically dispensed.

The Java client does not trust its own copy of `authorityMode` to create banking authority; the bank resolves the retained authority by `offlineAuthorityId`.

## Qualification performed

Under ooRexx 5.3.0 r13196 with the supplied dependency roll-up and the local dev7-fb1 JMS compatibility candidate:

- `test_atm_offline_authority.rex` PASS
- `test_atm_gateway_protocol.rex` PASS
- `test_atm_gateway_money.rex` PASS
- Java ATM suite: 18 PASS, 0 FAIL

The Java offline test proves a reserved allowance reduces available funds through a hold, permits exactly one disconnected physical dispense, rejects a second dispense locally, and settles once after reconnection with replay harmless.


## Partial physical cash

The v0.1.6 advice reports `amountMinor` as the amount actually dispensed and may retain the original requested value as `requestedAmountMinor`. `dispensedMinor`, when present, must agree with `amountMinor`.

FederationBank v0.9 already permits partial actual settlement for `DELEGATED_STAND_IN`. Its stock Ledger hold consumer requires an exact amount for `RESERVED_ALLOWANCE`, so a partial physical dispense exposes `ATM_HOLD_MISMATCH` and leaves the original reservation active. The package contains a separately qualified candidate patch which permits the single-use reserved authority to settle the actual cash amount and releases the unused hold remainder. This is intentionally documented as a bank candidate rather than silently assumed by the Java client.

## Remaining bank-side lifecycle edge

The v0.8/v0.9 session implementation still requires session status `ACTIVE` even when `allowExpired=true`. Consequently a server-side LOGOFF can still invalidate later deposit/cancel/offline-advice recovery. The Java ATM continues to defer LOGOFF while session-bound physical recovery work remains pending. A future bank revision should give already-created physical-cash evidence a recovery credential/lifetime independent of an interactive customer session.


## Unused authority release

Stock FederationBank v0.9 was also probed for the no-cash path:

1. issue a 10000 `RESERVED_ALLOWANCE`;
2. observe book balance unchanged and `activeHeldMinor=10000`;
3. use no cash;
4. LOGOFF;
5. observe the authority remains `ACTIVE` and the hold remains active;
6. send `RELEASE_OFFLINE_ALLOWANCE`;
7. observe `OPERATION_UNSUPPORTED`.

v0.1.7 therefore includes a separate bank candidate implementing `RELEASE_OFFLINE_ALLOWANCE`. The candidate uses retained `RELEASE_PENDING` before the Ledger hold is released and retained `RELEASED` afterwards. A test reconstructs the gateway at the intermediate state and proves the same release idempotency identity resumes after restart.

This candidate is deliberately not folded into the claimed FederationBank v0.9 baseline.
