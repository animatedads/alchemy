# FederationBank Java Text ATM Specification v0.1

## Purpose

The Java ATM is a dummy physical cash-machine channel connected to FederationBank through JMS. It is intentionally text mode, broker-neutral and hardware-neutral.

Minimum functions:

- terminal sign-on;
- customer logon/logoff;
- account list and balance;
- withdrawal;
- deposit;
- bank-supplied operating/offline rules.

## Invariants

1. The ATM has no direct Ledger authority.
2. Customer intent, physical device fact and monetary truth are different facts.
3. No irreversible physical action is repeated merely because a JMS reply is missing.
4. Monetary retries use stable idempotency identities.
5. Bank rules are signed and fail closed.
6. Offline cash vending is denied unless the bank explicitly issued usable authority before disconnection.
7. A physically accepted deposit cannot be forgotten because the network disappeared.

## Terminal lifecycle

```text
BOOT
  -> load/verify last signed rules
  -> open durable journal + terminal sequence
  -> connect/sign on to bank
  -> request current signed rules
  -> recover unfinished monetary transactions
  -> IDLE
```

Connection states reported to the operator/customer are conceptually:

```text
ONLINE
OFFLINE_RESTRICTED
OUT_OF_SERVICE
```

## Customer lifecycle

```text
IDLE
 -> LOGON
 -> LIST_ACCOUNTS
 -> choose account
 -> BALANCE / WITHDRAW / DEPOSIT / CHANGE ACCOUNT
 -> LOGOFF
 -> IDLE
```

A PIN is read with Java's non-echoing Console API in normal terminal use and is never journalled.

## Withdrawal state machine

```text
NEW
 -> WITHDRAW_AUTHORISE
 -> AUTHORISED
 -> DISPENSE_STARTED        (fsynced before device action)
 -> DISPENSED
 -> COMMIT_REQUESTED
 -> COMMITTED
```

Zero-cash device failure becomes:

```text
DISPENSE_FAILED
 -> WITHDRAW_CANCEL
 -> CANCELLED
```

Partial/unknown physical outcome becomes:

```text
RECONCILIATION_REQUIRED
```

and is never automatically re-dispensed.

The terminal allocates the future commit identity before starting the dispenser and writes it into the durable journal. A process failure after dispense therefore cannot accidentally reuse the authorisation key as the posting/commit key.

## Deposit state machine

```text
NEW
 -> ACCEPT_STARTED
 -> CASH_ACCEPTED           (physical fact, fsynced)
 -> COMMIT_REQUESTED
 -> COMMITTED
```

If the bank network is unavailable after `CASH_ACCEPTED` and bank rules allow capture-and-queue:

```text
PENDING_UPLOAD
```

Recovery retransmits exactly the same deposit commit identity.

## Rule semantics

The terminal accepts only an Ed25519-signed, correctly targeted, non-expired rules object whose version does not go backwards.

If a bad update arrives, the update is discarded atomically; the previous valid rules remain in force until their own expiry.

Default offline withdrawal is `DENY`.

The client recognises bank-authorised offline modes but refuses to dispense without an actual bank-issued `RESERVED_ALLOWANCE` or `DELEGATED_STAND_IN` authority object. It never treats a rule flag alone as money authority.

Before any offline dispenser call, the selected authority is fsynced as `CLAIMED_LOCALLY`. A durable zero-cash failure may return it to `ACTIVE`. Any non-zero dispense makes it single-use locally; a restart with only `DISPENSE_STARTED` evidence quarantines it instead of guessing whether cash left the machine.

## Local durability

The transaction journal is append-only JSONL. Each append is forced to disk before returning.

The terminal command sequence is kept in a separate atomic file and incremented durably.

The last accepted signed rules envelope is atomically replaced on disk only after signature/target/time/version validation.

## JMS

See `ATM_JMS_CONTRACT.md`.

## Physical hardware boundary

```text
CashDispenser
DepositAcceptor
```

The shipping implementation uses:

```text
DummyCashDispenser
DummyDepositAcceptor
```

A real device integration can replace these classes without changing bank protocol or console/application flow.

## Text interface

Plain text is the compatibility baseline. ANSI branding is optional and selected by:

```text
--ansi=auto
--ansi=always
--ansi=never
```

`NO_COLOR` and dumb/non-interactive terminals suppress ANSI in auto mode.

The visual logo is decoration only; the ATM's meaning never depends on colour.

## Test boundary

The package includes a no-dependency test runner proving:

- JSON/canonical signing representation;
- logon/account/balance path;
- PIN absence from durable journal;
- lost withdrawal-commit reply -> idempotent retry -> exactly one debit;
- dispenser failure -> hold release/no debit;
- offline deposit capture -> later upload -> exactly one credit;
- tampered bank rules rejected;
- known zero-cash offline failure releases a local authority claim safely;
- partial offline cash consumes the authority and records the actual amount;
- restart after offline `DISPENSE_STARTED` quarantines the authority and prevents a second vend;
- an unused reserved offline allowance is returned before LOGOFF when the bank supports release;
- a lost release response replays the same idempotency identity without recreating or double-releasing the hold.

## v0.1.7 qualification note

FederationBank v0.9 offline authority is exercised through the same JMS-shaped Queue Fabric boundary as ordinary ATM money movement. The terminal now claims an authority durably **before** invoking the physical dispenser. That removes the crash window in which an authority could remain locally `ACTIVE` after an uncertain physical cash event.

For partial cash, `DELEGATED_STAND_IN` already settles the actual amount under stock v0.9. Stock `RESERVED_ALLOWANCE` requires an exact hold amount and therefore leaves the full hold stranded after a partial dispense. This package includes a narrow bank candidate that permits partial consumption up to the reserved ceiling, releases the unused reservation because the authority is single-use, and rejects disagreement between `amountMinor` and `dispensedMinor`.

The separate expiry/advice-time follow-up remains: bank policy should distinguish authority validity when cash physically left from delayed reconciliation after a network outage without blindly trusting a backdated terminal clock.


## Unused offline authority lifecycle

A bank-issued offline authority that was never used is not a physical cash fact. When connectivity is available, v0.1.7 attempts to return such an `ACTIVE` authority before LOGOFF.

The terminal does not simply delete its local copy. It writes `RELEASE_PENDING` first and retries the exact bank release identity after transport loss. Claimed, consumed, quarantined, or otherwise physically ambiguous authorities are never eligible for this path.

The supplied FederationBank v0.9 release candidate persists `RELEASE_PENDING` before releasing the backing Ledger hold and persists `RELEASED` only after that release succeeds. This makes a bank crash between authority deactivation and hold release recoverable without reopening vending authority.

---

# v0.1.9 Merchant Bank derivatives position enquiry

The ATM may display a current derivatives-position summary for an authenticated customer who also has a permitted retail relationship with Federation's Merchant Bank / brokerage arm.

This is a **separate source authority**, not a FederationBank retail account and not a Retail Bank Ledger projection.

```text
Retail Bank truth       -> book / held / available cash
ATM physical truth      -> cash actually dispensed / accepted
Brokerage position truth-> derivatives valuation / P&L / margin
```

The brokerage path is read-only.  The ATM does not send a brokerage account identifier, trade identifier, instrument identifier or transaction request. It sends authenticated retail customer/session context to the explicit brokerage enquiry perimeter; the brokerage side owns relationship linkage and position truth.

The v0.1.9 projection is `MerchantPositionSummary` only:

```text
relationshipId
currency
valuationTime
netMarketValueMinor
unrealisedPnlMinor
realisedPnlMinor
collateralMinor
marginRequiredMinor
availableMarginMinor
positionCount
valuationStatus
sourceAuthority
```

No individual trade/CFD/option object crosses into the ATM in this release.

The feature is online-only.  If the brokerage source cannot answer, the terminal does not reuse an earlier valuation and call it current.  Brokerage unavailability is independent of Retail Bank availability.

The following invariant is mandatory:

> Merchant-bank position information can inform an ATM display but cannot alter retail-bank available balance without an explicit arm's-length settlement having completed and the Retail Bank Ledger having posted the resulting money.

See `BROKERAGE_POSITION_CONTRACT.md` for the wire contract and trust boundary.
