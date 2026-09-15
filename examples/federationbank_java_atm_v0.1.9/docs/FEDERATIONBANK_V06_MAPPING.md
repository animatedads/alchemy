# Historical Mapping to supplied FederationBank Engine v0.6

This was the original design mapping after inspecting `federationbank_engine_v0.6.zip`. FederationBank v0.8 now implements the ATM gateway; see `FEDERATIONBANK_V08_INTEGRATION.md` for the current integration status.

## Existing backend rule preserved

The engine's architecture states:

```text
Channels request. Backend authorities decide and execute.
```

Its split runtime defines:

```text
FB.ACCOUNT.COMMANDS
FB.ACCOUNT.RESULTS
FB.PAYMENTS.COMMANDS
FB.PAYMENTS.RESULTS
FB.LEDGER.COMMANDS
FB.LEDGER.RESULTS
```

The existing `fb-channel` principal can send Account and Payments commands/read results but is intentionally not granted `PUT` to `FB.LEDGER.COMMANDS`.

The ATM therefore targets a new ATM Gateway JMS boundary. That gateway is a channel adapter, not a new path around Payments/Ledger.

## Existing FederationBank command vocabulary

`FederationBankCommand` already carries the fields the ATM gateway will need when translating an accepted channel request:

```text
commandId
operation
idempotencyKey
customerId
sourceAccountId
targetAccountId
currency
amountMinor
channel
actorId
requestedAt
...
details
```

ATM-originated backend commands should set:

```text
channel = ATM
actorId = terminalId
```

The gateway should derive `customerId` from the authenticated ATM session.

## Existing hold behaviour is a good withdrawal reservation primitive

v0.6 implements:

```text
PLACE_HOLD
RELEASE_HOLD
```

through Payments and Ledger. Ledger stores hold truth independently of postings.

The engine defines:

```text
book(account)      = sum(committed postings)
held(account)      = sum(ACTIVE hold amounts)
available(account) = book(account) - held(account)
```

`placeHold` validates account ownership/currency/status, refuses non-positive amounts, checks available funds for non-negative accounts, and can persist the hold and durable receipt atomically through the SQL Ledger store.

That is why the Java ATM does not invent its own local authorisation balance. `WITHDRAW_AUTHORISE` should become a bank-owned hold/reservation.

## Existing durable replay behaviour is directly reusable

At the Ledger boundary, v0.6 recovers durable receipts by idempotency key. Re-delivery after a worker/result failure returns recovered success rather than executing the reservation/posting twice, and a reused key for a different operation is treated as an idempotency collision.

The ATM client deliberately uses stable command/idempotency identities for recovery after an uncertain JMS reply.

## Required new bank primitive: consume withdrawal reservation into postings

A normal v0.6 hold is reservation truth, not a posting. `RELEASE_HOLD` simply releases it.

An ATM withdrawal needs an additional bank-owned finalisation operation with semantics equivalent to:

```text
consume ATM hold
+ customer withdrawal debit
+ ATM cash/settlement credit
+ durable idempotent receipt
```

in one Ledger-owned atomic state transition.

The Java client calls that business operation `WITHDRAW_COMMIT`; the ATM Gateway may translate it into whatever internal schema the bank team adds.

A failed physical dispense uses the ordinary release path. A partial dispense is a reconciliation exception and must not be guessed into a normal release/commit.

## Required new bank primitive: ATM cash deposit

A cash deposit similarly needs a bank-owned balanced posting shape, for example:

```text
ATM cash/clearing debit
customer deposit credit
```

The exact internal GL account is Ledger-owned and must never be supplied by the ATM.

`DEPOSIT_COMMIT` must be idempotent because physical cash may already be inside the terminal when the JMS reply is lost.

## Account query gap

v0.6 has Ledger balance methods (`balanceMinor`, `activeHeldMinor`, `availableBalanceMinor`) and Account projections, but no external ATM/customer query endpoint.

The proposed ATM Gateway therefore needs customer-scoped:

```text
LIST_ACCOUNTS
GET_BALANCE
```

These are read/query services. They do not grant the ATM direct SQL or Ledger queue access.

## Authentication gap

v0.6 does not provide card/PIN session authentication. The Java demo therefore defines a separate `LOGON`/`LOGOFF` channel contract. The in-process demo backend supplies fake cards/PINs only so the terminal is runnable while the real bank endpoint is being built.

Production PIN semantics remain behind this boundary.

## Institutional Policy gap

The supplied v0.6 fixture policies define transaction/hold rules for channel `WEB`; there are no ATM rules in the fixture. The bank should add explicit `ATM` policy rules rather than re-labelling ATM traffic as web traffic.

The Java terminal separately consumes signed terminal operating rules such as:

```text
whether balance/withdrawal/deposit is enabled
maximum cash amounts
offline balance behaviour
offline withdrawal behaviour
offline deposit behaviour
rule validity and version
```

Those terminal rules complement, but do not replace, backend Institutional Policy and Legal Effect evaluation. A terminal saying "allowed" is never sufficient authority for Ledger.

## Existing JMS precedent

The engine already contains a bank-side external JMS adapter contract for IJCIB. That boundary is provider-owned and uses JMS `MapMessage` with its exact provider properties.

The ATM is a different, FederationBank-owned external contract, so this package uses a versioned JSON `TextMessage`. The two JMS boundaries should not be conflated.
