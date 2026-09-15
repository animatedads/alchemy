# FederationBank IOM Offshore v0.9 Architecture

## 1. Boundary rule

**Channels request. Backend authorities decide and execute.**

The backend is intentionally split into three independently restartable queue workers. Queue Fabric is the service boundary. There is no browser-to-ledger path and no distributed-SQL fiction spanning the services.

## 2. Authorities

### 2.1 Account Authority

`FederationBankAccountAuthority` owns customer/account and beneficiary lifecycle state changes. The queue-facing `FederationBankAccountEngine` wraps that authority directly.

Account opening:

```text
OPEN_ACCOUNT
 -> durable idempotency lookup
 -> Security Effect / Bouncer
 -> Institutional Policy requirement resolution
 -> currency-specific Legal Effect
 -> CivicPort if required
 -> IJCIB if required
 -> final Institutional Policy decision from gathered evidence
 -> one SERIALIZABLE DB transaction
      customer (when new)
      account
      opening-decision provenance
      immutable IJCIB evidence (when present)
      durable command receipt
 -> retained account-state projection
 -> result queue
```

Beneficiary lifecycle:

```text
ADD / AMEND / SUSPEND_BENEFICIARY
 -> durable idempotency lookup
 -> Bouncer
 -> beneficiary Institutional Policy
 -> owning-account currency Legal Effect
 -> one SERIALIZABLE DB transaction
      beneficiary current state
      immutable lifecycle event + provenance
      durable receipt
 -> retained beneficiary-state projection
```

Payments consumes beneficiary state as a read model and cannot update Account Engine truth.

### 2.2 Payments Authority

Payments owns customer-facing authority to request monetary/reservation changes, never the durable change itself.

```text
TRANSFER
 -> Bouncer
 -> customer/corporate limit policy
 -> transfer-fee Institutional Policy
 -> currency Legal Effect (including derived fee facts)
 -> internal transfer+fee instruction
 -> Ledger queue

PLACE_HOLD / RELEASE_HOLD
 -> Bouncer
 -> customer/corporate reservation policy
 -> currency Legal Effect
 -> internal hold instruction
 -> Ledger queue
```

Payments authorisation changes neither book balance nor available balance. Final customer success is published only after a committed Ledger result.

### 2.3 Ledger Authority

Ledger accepts only internal instructions carrying required authority provenance.

Transfer path:

```text
internal transfer instruction
 -> durable receipt lookup
 -> validate regulatory profile / posting shape
 -> fee-aware available-balance check
 -> map fee class to Ledger-owned internal income account
 -> construct balanced transfer + fee postings
 -> DB Skeleton SERIALIZABLE transaction
      transaction header (transfer amount + fee amount)
      every transfer/fee posting leg
      limit-policy + fee-policy + security + legal provenance
      durable receipt
 -> committed result
```

Funds-reservation path:

```text
internal hold instruction
 -> durable receipt lookup
 -> validate regulatory profile / hold identity
 -> PLACE: available-balance check
 -> DB Skeleton SERIALIZABLE transaction
      hold current state
      immutable hold lifecycle event
      authority provenance
      durable receipt
 -> committed result
```

A hold is reservation truth, not a posting. `RELEASE_HOLD` changes hold state only.

The channel principal has no `PUT` grant to the Ledger command queue.

## 3. Balance semantics

```text
book(account)      = sum(committed posting amounts)
held(account)      = sum(amount of ACTIVE holds)
available(account) = book(account) - held(account)
```

A transfer from a non-negative account is permitted only if `available >= transfer amount + policy fee`. Placing/releasing holds never changes `book(account)`.


## 4. Policy fee semantics

Fee authority and monetary truth remain deliberately separated.

- Institutional Policy owns fee amount/class selection and any future waiver rules.
- Payments resolves that policy and passes evidence, not a free-form debit instruction.
- Legal Effect receives the derived `FEE_AMOUNT_MINOR` and `FEE_CLASS` facts as part of the transfer assessment.
- Ledger maps the fee class/currency to an internal income account and validates the account locally.
- A fee-bearing transfer has four posting roles: `TRANSFER_DEBIT`, `TRANSFER_CREDIT`, `FEE_DEBIT`, `FEE_CREDIT`.
- All postings for a transaction must sum to zero before DB Skeleton is invoked.
- A fee never commits in a separate transaction from the transfer that caused it.

The v0.6 fixture fees are invented corporate-policy test data, not representations of real bank pricing or regulation.

## 5. Queue-owned coordination, service-owned atomicity

Each service owns its own atomic state transition. Cross-service completion is an idempotent saga over durable Queue Fabric messages.

Queue Fabric UOWs combine input consumption and downstream publication. Poison/backout policy is bounded; repeated failures move intact to `FB.BACKEND.DLQ` with source/backout evidence.

No service treats an uncommitted downstream request as final banking truth.

## 6. Projection and SQL recovery

- Account metadata: retained Account Engine topic.
- Beneficiary read model: retained Account Engine beneficiary topic.
- Payments daily committed-transfer usage: retained fact per transaction ID.
- Ledger posting/balance truth: SQL posting history.
- Ledger hold truth: SQL `federationbank_holds` state plus immutable hold-event history.

After Ledger restart, account metadata is reconstructed from retained account projections and monetary/reservation state is hydrated from SQL.

## 7. Durable replay

Receipts are written in the same database transaction as the state change they describe.

At the Ledger boundary, both transfer and hold instructions query the durable receipt before execution. A redelivery after worker failure therefore returns a successful recovered result and hydrates missing SQL projection state rather than performing the debit or reservation twice. An idempotency key reused for a different operation fails as `IDEMPOTENCY_COLLISION`.

If the receipt exists but corresponding SQL truth cannot be reconstructed, execution fails closed.

## 8. Regulatory routing

```text
USD -> FB-IOM-USD -> FB-LEGAL-USD
AUD -> FB-IOM-AUD -> FB-LEGAL-AUD
GBP -> FB-IOM-GBP -> FB-LEGAL-GBP
EUR -> FB-IOM-EUR -> FB-LEGAL-EUR
```

The IOM booking entity, customer domicile/residence, product and channel remain separate facts for Institutional Policy and Legal Effect. Hold policies/norms in the fixture are illustrative only.

## 9. External evidence

CivicPort and IJCIB are called only by Account Authority when resolved policy requires them. IJCIB remains an awkward sealed external bureau: published semantics are preserved; unpublished reason-code meaning is not invented.

## 10. Legacy combined engine

`FederationBankEngine` is retained as a compatibility facade for earlier tests/callers. It is not part of the v0.9 three-worker runtime topology.


## 11. FX authority and monetary shape

`FX_CONVERT` remains a Payments-owned customer request and a Ledger-owned monetary event. Payments resolves normal transaction policy, FX policy, a quote and **two** Legal Effect generations (source and target currency). Ledger creates one four-leg journal using internal currency position accounts.

The accounting invariant is per currency, not across unlike units:

```text
source customer             - source amount
source FX position          + source amount
                             --------------
source currency subtotal                0

target FX position          - target amount
target customer             + target amount
                             --------------
target currency subtotal                0
```

All four legs, quote/rate evidence, both Legal Effect identities, policy/security evidence and durable receipt share one DB Skeleton transaction.

## 12. Debit-authority model

Funding checks are an authorisation rule, not an accounting axiom. Ledger distinguishes explicit debit authority rather than accepting a generic bypass flag.

- `FUNDS_REQUIRED`: ordinary debit. Available funds include an authorised overdraft and exclude active holds. The debit cannot cross the authorised floor.
- `SETTLEMENT_MUST_POST`: a previously incurred settlement/physical-cash fact. The current implementation is accepted only for `OFFLINE_WITHDRAWAL_ADVICE` with ATM delegated-stand-in evidence.
- `INTERNAL_CHARGE_POLICY_CONTROLLED`: reserved for future bank-originated charge policy.

A mandatory offline cash settlement may create `UNAUTHORISED_EXCESS`. Ledger returns the derived excess and `withdrawalsBlocked`; later ordinary debits remain funds-gated.

Account opening currently defaults `authorisedOverdraftMinor` to zero. v0.9 tests may construct an account with a fixture allowance to exercise floor semantics; a future product/account-policy slice must own assignment and durable projection of non-zero customer overdrafts.

Required ATM settlement evidence includes terminal/network identity, delegated authority, ruleset/version, physical transaction identity, terminal sequence and dispensed amount. The evidence and two monetary legs are committed together.

## 13. PHANTOM_FUNDS invariant

Channel acknowledgement, physical action and monetary truth are distinct. In particular, an internal transfer that has not durably committed cannot make its target credit spendable. The regression suite injects a transfer SQL failure, proves the target receives no credit, then records a genuine offline ATM settlement against the actual committed balance.

This prevents degraded-network behaviour from manufacturing temporary customer assets.

## 14. ATM channel boundary

`FederationBankAtmGateway` is an external channel adapter, not a fourth banking authority. It consumes the Java ATM v0.1.0 TEXT/JSON JMS contract and routes state changes through Payments. The ATM principal is never granted direct Ledger command access.

Online withdrawal is a two-identity saga around one physical cash event:

```text
WDA -> Payments authority -> Ledger PLACE_HOLD
    -> terminal persists authorisation
    -> physical dispense
WDM -> Payments authority -> Ledger RESERVATION_CONSUME
    -> ATM_WITHDRAWAL_DEBIT + ATM_CASH_SETTLEMENT_CREDIT
```

A dispenser failure sends WDC/`WITHDRAW_CANCEL`, which releases the hold and performs no monetary posting. A deposit DPM reports a physical fact already accepted by the terminal and commits the opposite two-leg ATM cash/customer journal.

The Ledger owns internal ATM cash accounts, durable idempotency and transaction-status recovery. The terminal owns physical-device evidence and a local recovery journal. Neither side conflates customer intent, physical fact and monetary truth.

The gateway returns structured result codes such as `WITHDRAW_AUTHORISED`, `WITHDRAW_COMMITTED`, `DEPOSIT_COMMITTED`, `TRANSACTION_COMMITTED` and `TRANSACTION_UNKNOWN`; clients never parse explanatory detail text to derive business state.

## 15. Non-goals

- real regulatory/legal thresholds;
- real SWIFT/settlement rails;
- AS/400/mainframe integration;
- browser/Wire UI implementation;
- distributed SQL across backend services;
- multi-writer Ledger sharding/concurrency (current queue topology assumes one ordered Ledger authority per shard).


## Offline ATM authority v0.9

Offline withdrawal authority is now an explicit retained bank fact on `FB.ATM.OFFLINE.AUTHORITY`. The ATM Gateway rebuilds these facts after restart. They are evidence of delegated authority, not monetary truth.

`RESERVED_ALLOWANCE` is backed by a Ledger hold and later consumes that reservation after the ATM reports physical dispense. `DELEGATED_STAND_IN` is a bounded, single-use risk authority with no hold; a later verified physical advice is routed as `SETTLEMENT_MUST_POST`.

Authority issuance itself passes Bouncer -> Institutional Policy -> Legal Effect. Settlement never trusts a terminal-provided authority ID alone: the Gateway resolves the retained bank record and matches terminal, customer, account, currency, rules generation, expiry and amount. The same physical advice may be replayed idempotently, but the authority cannot be reused for a second physical cash event.

The current implementation intentionally uses single-use envelopes. Cumulative multi-dispense stand-in limits require a stronger cross-process consumption/claim model and are not represented as if they were solved.
