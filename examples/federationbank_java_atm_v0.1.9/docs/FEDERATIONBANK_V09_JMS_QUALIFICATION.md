# FederationBank v0.9 JMS qualification — ATM v0.1.6

## Baseline

- Java ATM: v0.1.6, continuing from supplied v0.1.4 and qualified v0.1.5
- FederationBank Engine: v0.9
- ooRexx JMS Queue Bridge: delivered v0.1-dev7-fb1
- Queue Fabric: v0.9-dev4
- Alchemy Objects: v0.8
- ooRexx Crypto: v0.1
- Institutional Policy: v0.8
- Legal Effect: v0.14
- Security Effect: v0.10
- DB Skeleton: v0.45
- CivicPort: v0.12
- ooRexx: 5.3.0 r13196
- BSF4ooRexx: v850 refresh

## Independent results

The delivered dev7-fb1 manifest verifies and its deterministic suite passes under the supplied ooRexx/BSF runtime, including MAP/TEXT handling, application JMS properties, correlation/JMSType, inbound idempotency/recovery, outbound semantics, operational readiness, credentials, Alchemy adoption, Secret Broker and Runtime Registry integration.

The unmodified FederationBank v0.9 ATM gateway still exposes the same JSON-boundary persistence problem seen in v0.8: `json.cls` `.JsonString` wrappers can survive into a durable Queue Fabric payment detail and cause `PAYLOAD_NOT_PERSISTABLE`. The supplied v0.9 compatibility patch canonicalises only JSON parser wrappers at the external ATM boundary. No Ledger/Payments rule is altered.

With that patch applied, both composed paths pass:

1. ordinary terminal sign-on -> logon -> balance -> withdrawal hold -> physical commit -> replay -> deposit -> replay;
2. v0.9 terminal sign-on -> logon -> `GET_OFFLINE_ALLOWANCE` -> real Ledger hold -> disconnected physical-cash evidence -> reconnect `OFFLINE_WITHDRAWAL_ADVICE` -> one settlement -> replay -> attempted authority reuse rejected.

The second path proves that offline vending authority is still created by the bank. The terminal merely retains and consumes it. The physical dispense itself is intentionally absent from the broker path because it happens during disconnection.

## v0.1.6 physical-cash safety qualification

The v0.1.6 client closes the remaining pre-dispense crash window by durably changing a selected offline authority from `ACTIVE` to `CLAIMED_LOCALLY` **before** the dispenser is invoked. A proven zero-cash failure may return that claim to `ACTIVE`; any non-zero dispense consumes it; and a restart after `DISPENSE_STARTED` with no conclusive physical result quarantines it so it cannot vend again.

The Java suite now covers all three outcomes, including a simulated process loss immediately after dispense start. It also covers a partial dispense, where `amountMinor` in the later advice is the actual cash amount and `requestedAmountMinor` preserves the customer's original request.

A stock-v0.9 composed probe establishes the bank distinction for a 10000-minor authority followed by a 5000-minor partial dispense:

- `DELEGATED_STAND_IN` already settles the actual 5000;
- `RESERVED_ALLOWANCE` returns `ATM_HOLD_MISMATCH`, leaves book balance unchanged and retains the original 10000 hold.

The package therefore includes `federationbank_v0.9_atm_partial_reservation.patch` as a **candidate bank change**, not an assumed production contract. With that patch on a disposable bank copy, the reserved allowance settles exactly the 5000 physically dispensed, releases the unused 5000 reservation, and rejects inconsistent `amountMinor`/`dispensedMinor` evidence before money moves. Existing ATM, hold-lifecycle and offline-authority bank tests remain green against the candidate.

## Remaining bank-side semantic edge

FederationBank v0.9 currently rejects an offline advice if `DateTime~new` is later than the authority's `expiresAt`. That makes arrival time stand in for dispense time. A legitimate sequence can therefore be:

```text
21:59:50 authority still valid
21:59:55 terminal dispenses cash while isolated
22:00:00 authority expires
22:01:10 network returns
22:01:11 advice rejected as expired
```

The cash fact is real and must not disappear. ATM v0.1.6 durably records `dispensedAt` and keeps the session alive while advice remains unresolved. The preferred bank follow-up is a bounded physical-evidence rule that accepts delayed reconciliation when the dispense occurred within authority validity, while preventing a terminal from backdating arbitrary cash.

This is distinct from extending the authority: the terminal must still refuse any *new* dispense after expiry.

## Reproduction

Apply `integration/oorexx/federationbank_v0.9_atm_json_boundary.patch` to a disposable FederationBank v0.9 copy, set the dependency environment variables documented by FederationBank, then run:

```bash
./scripts/test-federationbank-v09-composed.sh
```
