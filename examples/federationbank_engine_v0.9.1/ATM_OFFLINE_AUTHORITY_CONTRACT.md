# FederationBank ATM Offline Authority Extension v0.9.1

This document describes the FederationBank bank-side extension for bank-issued offline ATM authority. Java ATM v0.1.5 implements the client side of this contract and durably retains physical dispense evidence for later reconciliation.

## Core rule

Offline cash authority is issued by FederationBank while the terminal is online. An ATM-supplied `offlineAuthorityId` has no authority by itself.

FederationBank supports two single-use authority modes:

- `RESERVED_ALLOWANCE`: backed by a Ledger-owned hold. Book balance is unchanged while authority is outstanding; available balance is reduced by the reservation.
- `DELEGATED_STAND_IN`: bounded bank risk authority with no reservation. It can later produce mandatory settlement if cash has physically left the terminal, even if current funds are insufficient.

Both modes pass Bouncer -> Institutional Policy -> Legal Effect before the authority is issued.

## Request: GET_OFFLINE_ALLOWANCE

Uses the existing `federationbank.atm.request/0.1` envelope.

`data`:

```json
{
  "accountId": "GBP-001",
  "currency": "GBP",
  "amountMinor": 10000,
  "authorityMode": "RESERVED_ALLOWANCE"
}
```

`authorityMode` is `RESERVED_ALLOWANCE` or `DELEGATED_STAND_IN`.

Success codes:

- `OFFLINE_RESERVED_ALLOWANCE_ISSUED`
- `OFFLINE_STANDIN_AUTHORITY_ISSUED`

The returned `data` is a bank-owned retained authority fact:

```json
{
  "schema": "federationbank.atm.offline-authority/0.9",
  "offlineAuthorityId": "OFFAUTH-...",
  "authorityMode": "RESERVED_ALLOWANCE",
  "terminalId": "ATM-IOM-001",
  "customerId": "CUST-001",
  "accountId": "GBP-001",
  "currency": "GBP",
  "maxAmountMinor": 10000,
  "holdId": "ATM-OFFLINE-HOLD-...",
  "rulesetId": "FB-ATM-IOM-DEMO",
  "rulesVersion": "1",
  "issuedAt": "...Z",
  "expiresAt": "...Z",
  "status": "ACTIVE",
  "singleUse": "true"
}
```

Policy/security/legal provenance is also returned/preserved when available.

## Advice: OFFLINE_WITHDRAWAL_ADVICE

The ATM reports the physical cash fact using its normal durable command/idempotency identity.

`data`:

```json
{
  "offlineAuthorityId": "OFFAUTH-...",
  "accountId": "GBP-001",
  "currency": "GBP",
  "amountMinor": 10000,
  "physicalTransactionId": "PHYS-DISP-...",
  "dispensedMinor": 10000,
  "authorityMode": "RESERVED_ALLOWANCE"
}
```

FederationBank ignores client assertions about authority semantics and resolves the stored authority by `offlineAuthorityId`. It verifies terminal, original authenticated session, account, currency, ruleset/version, amount ceiling, terminal-sequence progression and single-use state.

For `RESERVED_ALLOWANCE`, the advice consumes the exact Ledger hold and produces the normal two ATM withdrawal postings.

For `DELEGATED_STAND_IN`, the advice becomes `SETTLEMENT_MUST_POST` only after the bank verifies that the authority was previously issued. This may drive the account beyond zero/authorised overdraft; resulting restriction state is then projected from Ledger truth.

A replay of the same advice idempotency key + physical transaction is safe and recovers the original durable Ledger result. Reusing the same authority for a different physical transaction is rejected.

## Delayed advice after authority expiry

Authority expiry and advice arrival are different facts.

A terminal must refuse a **new** offline dispense once the bank-issued authority has expired. If cash was physically dispensed while that authority was still valid, however, loss of connectivity may cause the advice to arrive later. v0.9.1 therefore permits bounded delayed reconciliation rather than discarding an already-incurred cash obligation.

For advice arriving after expiry, the bank requires:

- the retained bank-issued authority;
- the originally bound terminal and authenticated session history;
- matching customer/account/currency/rules;
- a forward terminal sequence relative to authority issue;
- a non-empty physical transaction identity;
- a terminal-recorded `dispensedAt`;
- `dispensedAt` inside the authority interval subject only to the bank-configured clock-skew tolerance;
- advice arrival before the bank-configured reconciliation deadline;
- the original single-use/idempotency protections.

The bank records its own `adviceReceivedAt` together with `dispensedAt`, authority issue/expiry, issuing terminal sequence, reconciliation window, clock-skew tolerance and evidence disposition in the durable settlement receipt.

LOGOFF or ordinary interactive-session timeout cannot erase cash already dispensed under authority. Recovery may resolve retained authenticated session history for the original terminal/authority only. A new session cannot appropriate an old authority.

This is a bounded trust model, not a claim that a terminal clock is cryptographic proof. The terminal-supplied time is accepted only inside an already-issued amount/identity envelope and a finite reconciliation window.

## Failure/reconciliation codes

Important structured outcomes include:

- `ATM_OFFLINE_AUTHORITY_UNKNOWN`
- `ATM_OFFLINE_AUTHORITY_EXPIRED` (legacy/current-operation use where applicable)
- `ATM_OFFLINE_PHYSICAL_TIME_REQUIRED`
- `ATM_OFFLINE_DISPENSE_OUTSIDE_AUTHORITY`
- `ATM_OFFLINE_RECONCILIATION_WINDOW_EXPIRED`
- `ATM_OFFLINE_AUTHORITY_SESSION_MISMATCH`
- `ATM_OFFLINE_AUTHORITY_SEQUENCE_INVALID`
- `ATM_OFFLINE_EVIDENCE_TIME_INVALID`
- `ATM_OFFLINE_AUTHORITY_TERMINAL_MISMATCH`
- `ATM_OFFLINE_AUTHORITY_CUSTOMER_MISMATCH`
- `ATM_OFFLINE_AUTHORITY_ACCOUNT_MISMATCH`
- `ATM_OFFLINE_AUTHORITY_CURRENCY_MISMATCH`
- `ATM_OFFLINE_AUTHORITY_RULESET_MISMATCH`
- `ATM_OFFLINE_AUTHORITY_AMOUNT_EXCEEDED`
- `ATM_OFFLINE_AUTHORITY_ALREADY_CONSUMED`

An unknown/invalid authority is not silently converted into a customer debit. It requires reconciliation/security treatment because the bank cannot prove that it delegated the cash-vending authority.

## Persistence

Authority facts are retained/persistent on Queue Fabric topic:

`FB.ATM.OFFLINE.AUTHORITY`

A restarted ATM Gateway rebuilds the authority registry from that retained topic. Monetary truth remains Ledger SQL truth; the authority topic is risk/authorization evidence, not a balance store.

## Current Java ATM compatibility

Java ATM v0.1.5 requests and persists bank-issued offline authority, refuses new vending after expiry, journals physical dispense before reconciliation, retains `dispensedAt`, and keeps unresolved advice recoverable across ordinary LOGOFF/restart handling. Its package-level tests pass independently and its composed v0.9 path is green against this authority model.
