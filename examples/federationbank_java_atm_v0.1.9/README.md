# FederationBank Java ATM v0.1.9

A deliberately boring, well-behaved text-mode cash-machine demo for FederationBank.

It has two interchangeable bank-network implementations:

- `demo`: an in-process FederationBank-like network simulator used to exercise the complete terminal without waiting for a bank endpoint;
- `jms`: a real JMS request/reply transport using JNDI. The JMS provider library is supplied at runtime by the deployment, not bundled into this source package.

The ATM never talks to the Ledger directly. Its architectural rule is the same one used by FederationBank v0.8:

> Channels request. Backend authorities decide and execute.

## FederationBank v0.8/v0.9 JMS qualification (retained in v0.1.9)

The v0.1.9 cut retains the v0.1.4 literal live-broker qualification through
ActiveMQ + BSF4ooRexx + the real dev7-fb1 bridge, and independently qualifies
FederationBank v0.9 through the neutral JMS/Queue Fabric path. The v0.9 composed
run covers both the ordinary online withdrawal/deposit path and a bank-issued
`RESERVED_ALLOWANCE` followed by disconnected physical cash evidence and
reconnection settlement. See `docs/FEDERATIONBANK_REAL_JMS_QUALIFICATION.md` and
`docs/FEDERATIONBANK_V09_JMS_QUALIFICATION.md`.

That test exposed a wire-only v0.8 bank defect involving ooRexx `.JsonString`
parser wrappers reaching a durable payment payload.  The minimal compatibility
patch and reproduction harness are under `integration/oorexx/`.

The live qualification used the supplied BSF4ooRexx v850 refresh, the delivered
`oorexx_jms_queue_bridge_v0.1-dev7-fb1`, ActiveMQ 5.18.3 and ooRexx 5.3.0
r13196. Provider-specific production deployment remains a deployment concern,
but the Java/JMS/BSF/ooRexx boundary is now executed rather than simulated.

## What works now

- terminal sign-on;
- signed bank rule retrieval and durable last-known-valid rule storage;
- optional durable JMS rule-topic subscription;
- customer demo logon/logoff;
- customer-scoped account listing;
- book / held / available balance enquiry;
- withdrawal authorise -> durable device evidence -> commit/cancel lifecycle;
- deposit physical receipt -> bank commit lifecycle;
- offline deposit capture-and-queue when bank rules permit it;
- offline withdrawal fail-closed by default;
- cached balances clearly marked stale when bank rules allow them;
- append-only fsynced local transaction journal;
- crash recovery that never repeats a physical cash dispense;
- replay of a pending withdrawal cancellation after a lost bank connection;
- protection against invalidating the bank session while a physical deposit, withdrawal cancellation, or offline-cash advice still needs session-bound recovery;
- exact FederationBank v0.8 ooRexx/Java Ed25519 rule-signature compatibility vector;
- idempotent retry support through stable business idempotency keys;
- dummy dispenser and deposit acceptor behind hardware-neutral interfaces;
- optional ANSI FederationBank roundel approximation;
- physical offline dispenses journal explicit `dispenseStartedAt` / `dispensedAt` evidence;
- a bank-issued offline authority is durably `CLAIMED_LOCALLY` before the dispenser is touched;
- known zero-cash dispenser failures may release that local claim, while partial/unknown outcomes consume or quarantine it so it can never vend twice;
- partial offline cash reports and settles the actual `dispensedMinor`, not the requested amount;
- unused bank-issued offline authorities are explicitly returned before LOGOFF when the bank supports `RELEASE_OFFLINE_ALLOWANCE`;
- offline-authority release is journalled as `RELEASE_PENDING` before transport and retried with the same idempotency identity after lost replies;
- dependency-free Java 17 source and tests;
- a separate read-only Brokerage/Merchant Bank position-enquiry source;
- customer-to-brokerage relationship resolution remains brokerage-owned: the ATM sends no brokerage account identifier;
- a narrow derivatives-position summary (market value, P/L, collateral/margin, count, valuation time/status/source authority) with no individual trade objects;
- brokerage positions are online-only and are never cached into the ATM physical-cash journal;
- brokerage outage is independent of retail-bank availability and cannot change withdrawable cash.

## Demo

Requires a JDK 17 or newer.

```bash
./scripts/run_demo.sh
```

The normal interactive path uses `System.console().readPassword()` and does not echo the PIN.

Demo cards are intentionally fake:

```text
Card: 4111111111111111
PIN : 1234

Card: 5555555555554444
PIN : 4321
```

The second demo customer has a separate linked retail brokerage relationship, so the customer menu can show a Merchant Bank derivatives-position summary. The first demo customer has no such relationship. The demo bank and demo brokerage can be taken offline independently.

If you intentionally pipe scripted input, the secure Java console is unavailable. The dummy demo can then be run with:

```bash
./scripts/run_demo.sh --allow-visible-demo-pin --ansi=never
```

That option is deliberately named as insecure demo behaviour and should never be used for a real terminal.

Inside the demo customer menu, option `9` toggles the simulated retail-bank connection and option `8` toggles the independent brokerage source. This proves that a brokerage outage is not a retail-bank outage. With the supplied bank rules:

- offline withdrawal requires a matching bank-issued single-use authority; the customer can reserve one while online;
- a newer signed `DENY` overrides a cached unused authority before the dispenser is touched;
- cached balance can be displayed but is labelled stale;
- a deposit may be physically received and queued for bank confirmation.

## Merchant Bank / brokerage position enquiry

v0.1.9 adds the historical-Australian-ATM-inspired feature without collapsing the Merchant Bank into the Retail Bank.

The ATM uses a separate `BrokerageNetwork` boundary and only the read-only operation `GET_MERCHANT_POSITION_SUMMARY`. It sends the authenticated retail-bank customer/session context but no brokerage account identifier. The brokerage side (or an authorised perimeter linkage service in front of it) owns the customer-to-brokerage relationship mapping and the valuation truth.

The returned Java type is deliberately narrow: `MerchantPositionSummary`. It contains market value, unrealised/realised P/L, collateral, required/available margin, position count, valuation time/status and source authority. There is no individual CFD/option/trade object in the ATM application.

The position summary is not persisted in the transaction journal and is not used by `AtmService` when computing balance or authorising cash. If the brokerage source is offline, the ATM says the position service is unavailable rather than showing a cached valuation as current.

See `BROKERAGE_POSITION_CONTRACT.md` for the cross-perimeter contract.

## Build

```bash
./scripts/build.sh
java -jar build/federationbank-atm.jar
```

The generated jar contains no broker-specific JMS classes.

## Tests

```bash
./scripts/run_tests.sh
```

The suite proves, among other things, that a lost reply after a bank-side withdrawal commit does not produce a second debit or second dispense when recovery retries the same commit.

## Real JMS mode

Copy and edit the example configuration:

```bash
cp config/atm.properties.example atm.properties
```

Set:

```properties
transport=jms
jms.initialContextFactory=...
jms.providerUrl=...
jms.connectionFactoryJndi=ConnectionFactory
jms.requestQueueJndi=FB.ATM.REQUESTS
jms.replyQueueJndi=FB.ATM.REPLIES.ATM-IOM-001
jms.rulesTopicJndi=FB.ATM.RULES
jms.durableSubscriptionName=ATM-IOM-001-RULES
jms.username=atm-iom-001
jms.passwordEnv=FB_ATM_JMS_PASSWORD
bank.rules.publicKeyBase64=...
# or, for the supplied v0.8 demo gateway only:
# bank.rules.useFederationBankV08DemoKey=true

# Optional, separate Brokerage/Merchant Bank enquiry source:
brokerage.transport=jms
brokerage.jms.initialContextFactory=...
brokerage.jms.providerUrl=...
brokerage.jms.connectionFactoryJndi=BrokerageConnectionFactory
brokerage.jms.requestQueueJndi=FB.BROKERAGE.ATM.REQUESTS
brokerage.jms.replyQueueJndi=FB.BROKERAGE.ATM.REPLIES.ATM-IOM-001
brokerage.jms.username=atm-iom-001-position-enquiry
brokerage.jms.passwordEnv=FB_ATM_BROKERAGE_JMS_PASSWORD
```

Then place the bank's JMS provider/client jars on the classpath and invoke:

```bash
java -cp 'build/federationbank-atm.jar:/path/to/provider/*' \
  com.federationbank.atm.Main --config=atm.properties --transport=jms
```

`JndiJmsBankNetwork` drives the standard JMS 1.1-compatible methods through reflection. This intentionally avoids choosing `javax.jms` vs `jakarta.jms` or a specific broker at source-build time. A provider still needs to expose its normal `ConnectionFactory`, Queue and Topic objects through JNDI.

## FederationBank v0.8

The supplied bank engine now implements the ATM gateway we were waiting for. Its exact signed rule fixture verifies in Java, and the request/response envelopes match this client's protocol. See `docs/FEDERATIONBANK_V08_INTEGRATION.md` for the mapping and one recovery edge discovered during integration.

For the v0.8 demo gateway the public fixture verification key can be selected explicitly with:

```properties
bank.rules.useFederationBankV08DemoKey=true
```

This is test fixture convenience, not production key provisioning.

## Security scope

This is a demo ATM, not production ATM/PIN-processing software. The current demo credential type is `DEMO_PIN`. A production terminal would replace it with a bank-approved PIN-block/HSM flow while leaving the application `BankNetwork` interface intact.

The application never writes PINs to its journal. Broker passwords are read from a named environment variable rather than from ordinary command-line arguments.

Bank rule documents are verified with Ed25519 before activation. Invalid, expired, downgraded or incorrectly targeted rules are rejected rather than partly applied.

## Physical cash versus bank truth

The implementation preserves three facts independently:

1. what the customer asked for;
2. what the physical device actually did;
3. what FederationBank committed as monetary truth.

A withdrawal therefore authorises/reserves first, fsyncs the authorisation locally, fsyncs `DISPENSE_STARTED`, operates the dummy dispenser, and only then commits the bank transaction. A restart after `DISPENSE_STARTED` cannot automatically re-dispense; it becomes a reconciliation case.

A deposit records physical receipt before attempting the bank credit. If the network disappears after the machine has swallowed the notes, the transaction becomes `PENDING_UPLOAD`; it does not pretend the cash was never received.

## Source layout

```text
src/main/java/com/federationbank/atm/
    Main.java
    AtmService.java
    bank/       retail-bank transport boundary, demo and JMS
    brokerage/  separate read-only Merchant Bank position source, demo and JMS
    cash/       physical device abstractions and dummy devices
    domain/     customer/account/balance/rule result types
    journal/    durable terminal sequence and transaction journal
    protocol/   JSON + request/response wire envelopes
    rules/      Ed25519 rule verification and durable rule store
    ui/         plain/ANSI text terminal
```

See `ATM_JMS_CONTRACT.md`, `BROKERAGE_POSITION_CONTRACT.md`, `SPECIFICATION.md`, `docs/FEDERATIONBANK_V08_INTEGRATION.md`, and the historical `docs/FEDERATIONBANK_V06_MAPPING.md` for the bank-side contract and engine relationship.

## FederationBank v0.9 offline authority

v0.1.7 retains and hardens the bank-side `GET_OFFLINE_ALLOWANCE` extension introduced in v0.1.3. A bank-issued `RESERVED_ALLOWANCE` or `DELEGATED_STAND_IN` envelope is durably journalled and may be used once while disconnected. Before the physical device is called, the terminal changes the local authority state from `ACTIVE` to `CLAIMED_LOCALLY`; therefore a crash at the dispenser boundary cannot leave the authority eligible for a second vend.

A durable zero-cash device result reactivates the authority. Any non-zero cash result makes it single-use locally. A partial dispense records the actual cash amount and becomes pending advice/reconciliation. A restart with only `DISPENSE_STARTED` evidence quarantines the authority rather than guessing whether cash left the machine.

The package also contains a narrow FederationBank v0.9 candidate patch for reserved partial cash. Stock v0.9 requires the advice amount to exactly equal the original hold, which strands the full reservation after a partial dispense. The candidate permits an amount up to the reserved ceiling, settles only the cash physically dispensed, releases the unused reservation, and rejects `amountMinor` / `dispensedMinor` inconsistencies before money moves. See `integration/oorexx/federationbank_v0.9_atm_partial_reservation.patch` and `docs/BANK_V09_PARTIAL_CASH_FEEDBACK.md`.



### Unused reserved allowance release

Stock FederationBank v0.9 can issue a Ledger-backed `RESERVED_ALLOWANCE`, but it has no operation to return an unused authority. The ATM therefore cannot safely end the customer lifecycle without leaving the corresponding hold active.

v0.1.7 adds `RELEASE_OFFLINE_ALLOWANCE` on the client side and includes a separately qualified bank candidate. The terminal first journals `RELEASE_PENDING`, then requests release using a stable idempotency identity. The candidate bank first persists the authority as non-vendable `RELEASE_PENDING`, then releases the backing Ledger hold, then persists `RELEASED`. A restart between those steps resumes the same release instead of reactivating the authority.

On an unmodified v0.9 gateway, `OPERATION_UNSUPPORTED` causes the terminal to restore its local authority to `ACTIVE`; it never claims that a hold was released when the bank did not support the operation.

See `integration/oorexx/federationbank_v0.9_atm_offline_release.patch` and `docs/BANK_V09_OFFLINE_RELEASE_FEEDBACK.md`.

See `docs/FEDERATIONBANK_V09_INTEGRATION.md` and `docs/FEDERATIONBANK_V09_JMS_QUALIFICATION.md`.
