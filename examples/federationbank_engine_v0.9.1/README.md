# FederationBank IOM Offshore Banking Backend v0.9.1

FederationBank v0.9.1 is the backend reference slice for the FederationBank IOM Offshore test application. It deliberately implements core banking as **three queue-addressable services**, not one large banking process.

**Channels request. Backend authorities decide and execute.**

This package contains no Wire UI/browser code and no AS/400/mainframe adapter.

## Three backend authorities

### Account Engine

Owns customer/account and beneficiary lifecycle:

- `OPEN_ACCOUNT` authority;
- customer/account creation;
- Bouncer admission/replay handling;
- account-opening Institutional Policy;
- currency-selected Legal Effect;
- CivicPort address verification when policy requires it;
- IJCIB credit-intelligence request/consumption when policy requires it;
- atomic customer/account/evidence/receipt persistence;
- retained account-state projections for downstream services;
- `ADD_BENEFICIARY`, `AMEND_BENEFICIARY`, `SUSPEND_BENEFICIARY`;
- beneficiary Bouncer / Institutional Policy / currency-selected Legal Effect;
- atomic beneficiary master + immutable lifecycle event + durable receipt persistence;
- retained beneficiary-state projections for Payments.

The Account Engine uses `FederationBankAccountAuthority` directly. It has no transfer method and no balance/posting API.

### Payments Engine

Owns customer-facing payment and reservation authority, not monetary truth:

- `TRANSFER`, `FX_CONVERT`, `OFFLINE_WITHDRAWAL_ADVICE`, `PLACE_HOLD`, `RELEASE_HOLD` command admission;
- Bouncer checks;
- corporate/customer transaction and reservation policy;
- independent Institutional Policy resolution for transfer fees and waivers;
- currency-selected Legal Effect, with derived fee facts supplied to the legal evaluation;
- dual source/target Legal Effect evaluation for cross-currency FX;
- explicit debit-authority classification for delayed/offline settlement facts;
- rolling committed-transfer usage projection;
- read-only approved beneficiary projection;
- creation of internal Ledger instructions;
- publication of final customer outcomes only after Ledger commit.

Authorising a payment or hold does not change book balance or available balance.

### Ledger Engine

Owns monetary and funds-reservation truth:

- internal transfer, FX, mandatory offline-cash settlement and hold instructions only;
- immutable balanced journal postings, including per-currency-balanced FX journals;
- currency-specific internal FX position accounts and ATM cash/settlement accounts;
- account funds state including authorised overdraft and unauthorised excess;
- policy-fee income accounts owned as internal Ledger infrastructure;
- durable active/released holds;
- SQL transaction header + every transfer/fee leg + authority provenance + durable receipt;
- atomic hold state + immutable hold event + authority provenance + receipt;
- `SERIALIZABLE READ WRITE` DB Skeleton commit;
- durable command replay recovery across worker restart;
- SQL-backed posting, balance and hold reconstruction after worker restart.

The online/channel principal is not granted `PUT` access to the Ledger command queue.

## Queue topology

```text
Online channel
  -> FB.ACCOUNT.COMMANDS
       -> Account Engine
       -> retained account-state topic
            -> Payments projection
            -> Ledger projection
       -> retained beneficiary-state topic
            -> Payments beneficiary read model
       -> FB.ACCOUNT.RESULTS

Online channel
  -> FB.PAYMENTS.COMMANDS
       -> Payments Engine
       -> FB.LEDGER.COMMANDS
            -> Ledger Engine
            -> SQL transfer / fee / reservation commit
            -> FB.LEDGER.RESULTS
       -> Payments completion
       -> retained committed-transfer usage fact (TRANSFER only)
       -> FB.PAYMENTS.RESULTS

Malformed/backed-out backend messages
  -> FB.BACKEND.DLQ
```

Queue Fabric UOWs are used for consume + downstream publication where applicable. Backend command/projection queues have bounded backout with a durable DLQ.


## Policy-driven transfer fees

v0.6 adds transfer fees as a **separate Institutional Policy decision**, not as a hard-coded account property and not as a second convenient debit after the payment.

Payments resolves both the customer transaction-limit policy and the fee policy before constructing the internal Ledger instruction. The fee rule may vary by customer segment, currency, operation and channel. The supplied fee values are fixtures only.

For a fee-bearing transfer, Ledger commits one balanced banking transaction with explicit posting roles:

```text
TRANSFER_DEBIT   source account   - transfer amount
TRANSFER_CREDIT  target account   + transfer amount
FEE_DEBIT        source account   - policy fee
FEE_CREDIT       internal fee GL  + policy fee
                                      -----------
sum(all postings)                         0
```

The transaction header, all four postings, transaction-limit policy provenance, fee-policy provenance, Legal Effect generation, Security Effect provenance and durable command receipt share **one SERIALIZABLE DB transaction**. A database failure therefore cannot leave a successful transfer with a missing fee, a fee with a missing transfer, or only one side of either pair.

Available-funds enforcement is fee-aware:

```text
required available funds = transfer amount + fee amount
```

Payments' rolling customer transaction-usage projection records the requested transfer amount; the bank's fee is retained separately as fee evidence and journal postings.

Ledger creates the configured currency/fee-class income account as internal Ledger infrastructure (`FB-FEE-INCOME-<currency>-<fee-class>`). Channels and Payments never post to that account directly.


## v0.8: Java/JMS ATM gateway and physical-cash lifecycle

v0.8 adds a bank-side `FederationBankAtmGateway` compatible with the supplied `federationbank_java_atm_v0.1.0` TEXT/JSON JMS protocol. The ATM remains a channel: it has no direct Ledger queue access and cannot name internal settlement accounts.

The gateway provides terminal sign-on, signed rules, demo customer session authority, customer-scoped account listing, safe balance query, withdrawal authorisation/cancel/commit, deposit commit and durable transaction-status lookup. State-changing requests are translated into the existing Queue Fabric Payments -> Ledger path.

Online withdrawal preserves three distinct facts:

```text
WDA authorisation identity -> Ledger hold only
physical dispenser fact    -> terminal durable journal
WDM commit identity        -> consume hold + atomic ATM withdrawal postings
```

`WITHDRAW_AUTHORISE` changes available balance only. After the terminal reports successful physical dispense, `WITHDRAW_COMMIT` atomically releases/consumes the reservation and commits `ATM_WITHDRAWAL_DEBIT` plus `ATM_CASH_SETTLEMENT_CREDIT`. A lost WDM response can be replayed without a second physical dispense or debit. Failed dispensing uses `WITHDRAW_CANCEL` to release the hold without book movement.

For deposits, the terminal reports already-accepted physical cash with a durable DPM identity. Ledger atomically commits `ATM_CASH_SETTLEMENT_DEBIT` plus `ATM_DEPOSIT_CREDIT`. Replaying the same DPM returns the durable result without a second customer credit.

ATM cash accounts are Ledger-owned internal accounts derived from terminal + currency. The terminal never supplies an arbitrary internal GL identifier. Physical evidence, authority provenance, monetary legs and the durable receipt share one `SERIALIZABLE` database transaction.

The demo rules are signed with a fixed fixture signature/public key pair. No private signing seed is embedded in the package; production key custody is intentionally outside this test slice.

## v0.7: FX conversion and explicit debit authority

v0.8 adds two deliberately different banking cases: **cross-currency conversion** and **a debit that must be recorded because the physical economic event has already happened**.

### FX is balanced per currency

Payments resolves an FX-specific Institutional Policy rule and obtains a quote through an injected quote port. The source and target currencies each pass their own Legal Effect generation. Ledger never adds unlike currencies together. A GBP -> USD conversion is recorded as:

```text
GBP customer debit
GBP internal FX-position credit
                         GBP subtotal = 0

USD internal FX-position debit
USD customer credit
                         USD subtotal = 0
```

The quote identity, rate numerator/denominator, policy revision, markup, source Legal Effect and target Legal Effect are durable evidence in the same `SERIALIZABLE` database transaction as all four postings and the command receipt. A failed database transaction produces no customer credit and no position-account legs.

The supplied FX rates and markups are **test fixtures only**. They are not market data or real FederationBank pricing.

### Ordinary debit versus mandatory settlement

The Ledger no longer assumes that every debit is valid only when current available funds cover it. The authority is explicit:

```text
FUNDS_REQUIRED
    ordinary customer debit; may use authorised overdraft, but cannot cross its floor

SETTLEMENT_MUST_POST
    an already-incurred physical/settlement obligation must become monetary truth

INTERNAL_CHARGE_POLICY_CONTROLLED
    reserved for bank-originated charges whose floor behaviour is policy controlled
```

There is **no generic force-post flag**. The current `SETTLEMENT_MUST_POST` implementation is intentionally narrow: `OFFLINE_WITHDRAWAL_ADVICE` from an ATM channel with complete delegated-stand-in evidence. It records a cash event which has already occurred physically, even if that takes the customer below zero plus authorised overdraft.

After such a settlement Ledger derives:

```text
bookBalanceMinor
authorisedOverdraftMinor
activeHeldMinor
availableBalanceMinor
unauthorisedExcessMinor
fundsState
withdrawalsBlocked
```

A resulting `UNAUTHORISED_EXCESS` blocks later ordinary debits. The mandatory settlement privilege is not inherited by a subsequent transfer.

The v0.8 account object can carry an authorised-overdraft allowance, but **account-opening policy does not yet assign one**; newly opened accounts therefore remain zero-overdraft unless a later product/account-authority slice supplies that bank-owned setting. The overdraft values in the v0.8 debit tests are explicit fixtures.

### PHANTOM_FUNDS regression

`test_phantom_funds_regression.rex` locks a critical invariant: **a transfer credit is not spendable monetary truth unless its complete Ledger transaction committed**. A forced SQL failure leaves both sides absent. A later genuine offline cash settlement therefore operates against the real committed balance, never a channel-visible or ambiguous phantom credit.

This is deliberately aimed at degraded-network/ATM failure modes where physical cash, queue acknowledgement and monetary commit occur at different times.

## Book balance versus available balance

v0.5 introduced Ledger-owned funds reservations. A hold is deliberately **not** a double-entry posting.

```text
book balance      = sum(committed ledger postings)
active held funds = sum(ACTIVE holds for account)
available balance = book balance + authorised overdraft - active held funds
(for ordinary customer accounts; unrestricted internal accounts do not use a customer overdraft floor)
```

Placing or releasing a hold leaves book balance unchanged. A later transfer is rejected by Ledger with `INSUFFICIENT_AVAILABLE_FUNDS` if it would consume funds reserved by an active hold.

`PLACE_HOLD` and `RELEASE_HOLD` still pass the normal Payments authority path:

```text
channel request
 -> Payments Bouncer
 -> Institutional Policy
 -> currency-selected Legal Effect
 -> internal Ledger hold instruction
 -> Ledger SERIALIZABLE hold/event/receipt transaction
 -> committed result
 -> customer result
```

The fixture hold limits are Institutional Policy test data, not hard-coded account fields and not real regulation.

## Restart and replay model

The services intentionally do not pretend to share one distributed SQL transaction.

- Account state is rebuilt from retained Queue Fabric account projections.
- Payments beneficiary read state is rebuilt from retained Account Engine beneficiary projections.
- Payments rolling usage is rebuilt from one retained committed-transfer fact per banking transaction ID.
- Ledger account metadata is rebuilt from retained account projections.
- Ledger balances/posting history, including FX and offline-ATM settlement postings, are rebuilt from SQL monetary truth.
- Ledger active/released holds are rebuilt from SQL reservation truth.

Transfer and hold instructions perform a durable receipt lookup at the Ledger boundary. If a worker dies after SQL commit but before queue completion, redelivery recovers the committed receipt and SQL state rather than debiting or reserving funds twice.

## Monetary invariant

For every committed same-currency transaction `T`:

```text
sum(posting.amount_minor where transaction_id = T) = 0
```


For a multi-currency FX transaction, the stronger invariant is applied independently for each currency:

```text
for each currency C in transaction T:
    sum(posting.amount_minor where transaction_id = T and currency = C) = 0
```

A normal storage failure is not repaired with a compensating entry. Header, every posting leg, decision provenance and durable receipt commit atomically or none become visible. A later business reversal is a new balanced banking transaction.

A hold has a different invariant: hold current state, immutable hold event, authority provenance and durable receipt commit atomically, while **zero ledger postings** are created by the reservation itself.

## Regulatory and corporate-policy routing

Reference fixture routes remain deliberately distinct even though the booking entity is FederationBank IOM:

```text
USD -> FB-IOM-USD -> FB-LEGAL-USD
AUD -> FB-IOM-AUD -> FB-LEGAL-AUD
GBP -> FB-IOM-GBP -> FB-LEGAL-GBP
EUR -> FB-IOM-EUR -> FB-LEGAL-EUR
```

Currency is one decision fact among product, booking entity, customer domicile/residence, channel and transaction corridor. Corporate limits, fee rules/waivers, reservation rules and account-opening rules are owned by Institutional Policy.

All numeric limits, credit bands and legal norms supplied by `FederationBankFixtures.cls` are **test fixtures only** and are not representations of real IOM/US/Australian/UK/EU regulation.

## IJCIB credit-reference boundary

The supplied IJCIB bureau is treated as a sealed external organisation, not a FederationBank component. FederationBank preserves the bureau product as evidence rather than translating it into a friendly internal score API.

The bank-side adapter supports the IJCIB-style JMS contract including JMS `MapMessage`, exact `IJCIB_*` properties, separate request/correlation identity, nonce and request digest, opaque bureau product identifiers/references, disposition, suppression, declared scale direction, methodology, opaque reason trees and bureau-controlled refresh timing.

FederationBank policy may use published bureau semantics. It must not invent meanings for opaque IJCIB reason codes. The full bureau product is stored as immutable evidence in the same account-opening SQL transaction as customer/account creation and the durable receipt.

See `CREDIT_AGENCY_JMS_CONTRACT.md`.

## JMS Queue Bridge dependency

v0.9.1 uses the delivered `oorexx_jms_queue_bridge_v0.1-dev7-fb1`. The bridge provides outbound/inbound TEXT and MAP handling, application JMS properties, correlation/JMSType preservation and the IJCIB MAP/property edge.

The bridge has been independently qualified under ooRexx 5.3.0 r13196 with the BSF4ooRexx v850 refresh and ActiveMQ. FederationBank's own suite continues to treat transport and banking authority as separate layers.

## Legacy compatibility facade

`FederationBankEngine` remains in the package so v0.1/v0.2 regression tests and older callers continue to run. Its account-opening path delegates to the extracted `FederationBankAccountAuthority`.

The v0.9.1 three-service runtime does **not** instantiate the combined engine.

## Validation

Validated with ooRexx 5.3.0 r13196 and the versions in `DEPENDENCIES.txt`.

```bash
export INSTITUTIONAL_POLICY_SRC=/path/to/institutional_policy_v0.8/src
export LEGAL_EFFECT_SRC=/path/to/legal_effect_v0.14/src
export SECURITY_EFFECT_SRC=/path/to/security_effect_v0.10/src
export SECURITY_EFFECT_RUNTIME=/path/to/security_effect_v0.10/runtime
export QUEUE_FABRIC_SRC=/path/to/oorexx_queue_fabric_v0.9-dev4/src
export ALCHEMY_OBJECTS_SRC=/path/to/alchemy_objects_v0.8/src
export OOREXX_CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src
export DB_SKELETON_SRC=/path/to/oorexx_db_skeleton_v0_45
export CIVICPORT_SRC=/path/to/civicport_v0.12/src
export JMS_BRIDGE_SRC=/path/to/oorexx_jms_queue_bridge_v0.1-dev7-fb1/src
./run_tests.sh
```

## Validation result

The v0.9.1 cut passes **41 banking regression tests plus runtime smoke** under ooRexx 5.3.0 r13196. The offline-authority tests cover retained bank-issued `RESERVED_ALLOWANCE` and `DELEGATED_STAND_IN` envelopes, restart recovery, forgery/terminal/amount/single-use protection, reservation consumption and mandatory settlement. The original Java ATM v0.1.0 wire-compatibility tests, Java ATM v0.1.5 composed paths, and all previous FX, overdraft-floor, PHANTOM_FUNDS, queue/DLQ and restart regressions remain green.

## v0.9.1 delayed offline reconciliation

v0.9.1 closes the timing edge between **authority expiry** and **advice arrival**. Expiry still stops a terminal from performing a new offline dispense, but a cash event that occurred while bank-issued authority was valid can reconcile after connectivity returns.

Delayed reconciliation is bounded by the retained bank authority, terminal/customer/account/currency/rules binding, issuing session, forward terminal sequence, physical transaction identity, amount ceiling, bank-defined clock-skew tolerance and a finite reconciliation window. The exact bank receipt time used for the decision, the terminal-reported dispense time and the authority bounds are propagated into durable payment/Ledger receipt evidence.

Interactive session expiry or LOGOFF does not erase an already-created physical-cash obligation. Recovery may use the retained authenticated session history only for the terminal and authority to which it was originally bound. A later session cannot appropriate that authority.

v0.9.1 also absorbs the ATM JSON-boundary compatibility repair: `.JsonString` parser wrappers are canonicalised to ordinary strings before durable Queue Fabric work, without changing banking or Ledger rules.

## v0.9 offline ATM authority

v0.9 makes offline cash authority a bank-issued retained fact rather than trusting an `offlineAuthorityId` supplied by a terminal. `GET_OFFLINE_ALLOWANCE` is the bank-side extension consumed by Java ATM v0.1.5. It supports a Ledger-backed `RESERVED_ALLOWANCE` and a bounded `DELEGATED_STAND_IN` authority. Both are authorised through Bouncer, Institutional Policy and currency-selected Legal Effect before issuance.

A reserved allowance creates a real Ledger hold and therefore reduces available balance without changing book balance. A delegated stand-in authority creates no hold; after a valid physical dispense, its advice may become mandatory settlement and drive the account into unauthorised excess. Invented, expired, wrong-terminal, wrong-account, over-limit or reused authority envelopes are rejected before monetary truth. See `ATM_OFFLINE_AUTHORITY_CONTRACT.md`.

Java ATM v0.1.5 has been composed successfully with this bank-side authority model, including durable offline advice and replay; older clients remain free to fail closed if they do not implement the extension.
