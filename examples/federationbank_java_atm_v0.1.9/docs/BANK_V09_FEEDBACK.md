# FederationBank v0.9 ATM feedback

Three bank-side follow-ups are recommended after v0.1.6 qualification.

## 1. Canonicalise JSON wrappers at the ATM boundary

`FederationBankAtmGateway~processBridgeMessage` currently passes the direct result of `.JSON~fromJSON()` into banking work. ooRexx `json.cls` represents JSON strings as `.JsonString`, which is semantically fine at parse time but not a persistable Queue Fabric scalar in the later payment detail. The compatibility patch in this ATM package recursively converts only `.JsonString` wrappers to ordinary strings before validation/dispatch. This should be absorbed into a future bank cut rather than remaining an external qualification patch.

## 2. Offline authority expiry versus delayed advice

`FederationBankAtmOfflineAuthorityService~validateAdvice` checks the current bank time against `expiresAt`. That is correct for deciding whether a *new physical dispense* may occur, but too strict for reconciliation of cash that already left the terminal while authority was valid.

ATM v0.1.6 records `dispensedAt` with the physical evidence and prevents server-side LOGOFF while the advice remains unresolved. A future bank cut should define a bounded evidence policy for delayed advice, for example using terminal sequence, maximum clock skew, authority issue/expiry, physical transaction identity and retained terminal telemetry. Do not simply trust an arbitrary backdated timestamp.

The invariant should be:

> expiry stops new cash from leaving; it does not erase cash that already left under valid authority.

The existing single-use/idempotency protections should remain unchanged.

## 3. Reserved offline allowance after a partial physical dispense

ATM v0.1.6 claims an offline authority durably before touching the dispenser and will never reuse an authority after any non-zero or uncertain physical outcome. That exposes a safe-but-stranded v0.9 case: a `RESERVED_ALLOWANCE` for 10000 followed by an actual partial dispense of 5000 cannot call the stock exact-amount hold consumer, so the bank returns `ATM_HOLD_MISMATCH` and the 10000 hold remains active.

See `BANK_V09_PARTIAL_CASH_FEEDBACK.md` and `integration/oorexx/federationbank_v0.9_atm_partial_reservation.patch`. The candidate semantics consume only the actual physical amount, release the unused reservation because the authority is single-use, and require `amountMinor == dispensedMinor` when that evidence is supplied.



## Unused reserved offline allowance

See `BANK_V09_OFFLINE_RELEASE_FEEDBACK.md` and `integration/oorexx/federationbank_v0.9_atm_offline_release.patch`. Stock v0.9 leaves a never-used reserved authority and its backing hold active; the candidate adds crash-safe two-phase release.
