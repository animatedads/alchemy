# FederationBank Engine v0.8 Integration

This client cut was checked against the supplied `federationbank_engine_v0.8.zip`.

## Compatibility result

FederationBank v0.8 now contains `FederationBankAtmGateway`, explicitly described by the bank as an adapter for the Java ATM v0.1.0 TEXT/JSON protocol.  The gateway implements the client operations used here:

```text
TERMINAL_SIGN_ON
GET_RULES
LOGON
LOGOFF
LIST_ACCOUNTS
GET_BALANCE
WITHDRAW_AUTHORISE
WITHDRAW_CANCEL
WITHDRAW_COMMIT
WITHDRAW_EXCEPTION
DEPOSIT_COMMIT
GET_TRANSACTION_STATUS
OFFLINE_WITHDRAWAL_ADVICE
```

The request, response and rule schemas are unchanged:

```text
federationbank.atm.request/0.1
federationbank.atm.response/0.1
federationbank.atm.rules/0.1
```

The v0.8 bank fixture rule key is public, non-secret test material and has an exact Java verification vector in `AtmTestSuite`.

```text
rulesetId: FB-ATM-IOM-DEMO
rules version: 1
keyId: FB-ATM-RULE-KEY-1
Ed25519 SPKI public key:
MCowBQYDK2VwAyEA7ndT6feJnfYbd0LC1yXNu1R3QGwUJsCa/+kuZKUp0MU=
```

The fixed ooRexx signature over the v0.8 canonical rules document verifies in the Java implementation.  Mutating the rules after signing fails verification.

## Withdrawal mapping is now implemented bank-side

The design no longer relies on a proposed backend primitive.  v0.8 implements it:

```text
WITHDRAW_AUTHORISE
    -> PLACE_HOLD through Payments -> Ledger

physical dispense
    -> durable ATM journal fact

WITHDRAW_COMMIT
    -> consume hold
    -> ATM_WITHDRAWAL_DEBIT
    -> ATM_CASH_SETTLEMENT_CREDIT
    -> durable receipt
```

The bank derives the ATM cash account from terminal + currency.  The terminal cannot nominate an internal GL account.

`WITHDRAW_CANCEL` releases the hold and causes no book movement.  `dispensedMinor` is checked against the monetary amount by the bank's ATM physical-operation security evaluation.

## Deposit mapping is now implemented bank-side

`DEPOSIT_COMMIT` becomes balanced Ledger truth:

```text
ATM_CASH_SETTLEMENT_DEBIT
ATM_DEPOSIT_CREDIT
```

The bank records terminal, network, ruleset/version, physical transaction identity and terminal sequence as evidence in the same monetary lifecycle.

## JMS bridge boundary

The v0.8 engine package exposes:

```text
FederationBankAtmGateway~processBridgeMessage(JMSBridgeMessage)
```

and validates:

```text
TextMessage body
JMSCorrelationID == commandId
FB_ATM_SCHEMA
FB_ATM_OPERATION
FB_ATM_TERMINAL_ID
FB_ATM_RULES_VERSION
```

The supplied engine declares `ooRexx JMS Queue Bridge v0.1-dev7-fb1` as a dependency.  The engine package itself contains the gateway adapter but not a standalone broker process or broker-specific deployment configuration.  The deployment therefore still has to bind `FB.ATM.REQUESTS`/per-terminal replies (and an optional rules topic) to the gateway through the chosen JMS Queue Bridge/provider.

The Java side intentionally remains broker-neutral and expects those destinations through JNDI.

## v0.8 recovery edge found during client integration

A physically accepted deposit is stronger evidence than the continuing life of the interactive customer session.

In the current v0.8 gateway, `DEPOSIT_COMMIT` resolves the original session with `allowExpired=.true`, but `FederationBankAtmSessionAuthority~resolve` still rejects a session whose status is `LOGGED_OFF`.  Therefore this sequence can strand a replay:

```text
1. customer authenticated
2. ATM physically accepts cash
3. DEPOSIT_COMMIT cannot be confirmed
4. server-side LOGOFF succeeds
5. later replay of the same physical deposit
6. SESSION_INVALID because session status is LOGGED_OFF
```

The Java v0.1.1 client adds a conservative compatibility guard: before server-side LOGOFF it attempts physical-cash recovery, and if a session-bound deposit/cancellation fact is still pending it does **not** invalidate the bank session.  The local customer interaction is still over; the retained backend session merely expires naturally.

The preferred bank-side correction is to give already-recorded physical cash recovery a durable authority independent of the interactive session's ACTIVE/LOGGED_OFF state.  This is especially important for deposit acceptance and delayed cancellation/reconciliation.

## Offline withdrawal

The bank already contains the mandatory `OFFLINE_WITHDRAWAL_ADVICE` settlement primitive and validates delegated stand-in evidence.  The Java v0.1.1 terminal still fails closed because v0.8 does not yet issue `RESERVED_ALLOWANCE` objects to it.

That is the correct mismatch: the client understands the future mode but cannot manufacture the authority locally.

## Verification performed for this client cut

- bank ZIP integrity and its `MANIFEST.sha256` checked;
- gateway request/schema/JMS metadata reviewed against the Java encoder;
- all Java ATM tests pass;
- exact v0.8 ooRexx Ed25519 rules signature verifies in Java;
- mutation of the signed rules is rejected;
- pending deposit recovery is attempted before server-side logoff;
- a failed withdrawal-cancel network call is now replayed from the terminal journal without dispensing cash.

The bank package reports its own ooRexx suite as 39 banking regressions plus runtime smoke.  That upstream run was not repeated in this Java-only environment because the ooRexx runtime and the engine's external dependency roll-up were not supplied alongside v0.8 here.
