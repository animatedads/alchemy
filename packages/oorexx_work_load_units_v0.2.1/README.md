# ooRexx Work Load Units v0.2.1

`work.load.units/0.2` is a common workload accounting, admission and delivery-capacity primitive for ooRexx systems.

## The central rule

**WLU is work, not money.**

A Work Load Unit is a stable, dimensionless normalized amount of work.  Currency, provider invoices and internal chargeback rates are deliberately outside the core WLU authority.

The second axis is **WLU/second**: the delivery capacity required to perform that work at a requested pace.

Therefore these are different statements:

- `20 WLU` — amount of work;
- `20 WLU over 20 seconds` — approximately `1 WLU/s` delivery demand;
- `20 WLU over 4 seconds` — approximately `5 WLU/s` delivery demand.

Acceleration does not multiply the work.  If parallel/speculative execution actually performs additional work, that additional work is metered and becomes additional actual WLU in the ordinary way.

## Why two axes matter

An enterprise scheduler can react to a delivery shortfall without inventing a second currency or repricing work:

1. increase a logical capacity pool because a hosting/runtime provider has provisioned another worker/session;
2. increase an AI resource pool because more model/token throughput is available;
3. reduce another live reservation's delivery rate to free capacity;
4. queue or reject the new request when no safe capacity is available.

The WLU core describes and reserves normalized demand.  It does **not** know how a cloud VM, IBM i session, GPU worker or model provider is provisioned.

## Work lifecycle

A workload can carry three useful quantities:

- `expectedMicroWlu` — current forecast;
- `ceilingMicroWlu` — hard admitted work ceiling before top-up/re-admission;
- `requestedRateMicroWluPerSecond` — requested delivery capacity.

`WLUWorkDemand` can derive the rate from an expected amount and target duration.

Example:

```rexx
demand = .WLUWorkDemand~new(20 * 1000000, 25 * 1000000, 4)
/* expected = 20 WLU, ceiling = 25 WLU, target = 4 s => 5 WLU/s */
```

At settlement, only actual work becomes spent WLU.  Unused ceiling is released.  Delivery capacity is always released because it is a capacity promise, not consumed work.

## Core objects

### `WLUFact`

A consumer reports native metering facts.  It does not decide their WLU value.

Examples include:

- `FIELD_WRITE`
- `AID`
- `SCREEN_UPDATE`
- `HOST_ROUND_TRIP`
- `CONTROL_LEASE_TIME`
- `BYTES_RX`
- `BYTES_TX`
- `KNOWN_STATE_EVALUATION`
- model input/output token counts
- queue operations
- storage or compute facts

### `WLURateCard`

A sealed, versioned policy object maps facts to normalized WLU.  A reservation captures the rate-card id and version so live policy changes never reinterpret historical work.

### `WLUAccount`

A workload **entitlement** account.  Despite the word `Account`, it is not a financial account.  It tracks granted, reserved and spent normalized work.

### `WLUCapacityBucket`

A token/burst constraint expressed in WLU with an optional WLU-per-second refill rate.  This is useful for provider-style rate/allowance enforcement and retry-after behaviour.

### `WLUThroughputPool`

A reservable delivery-capacity pool expressed in WLU/second.

It tracks:

- configured capacity rate;
- currently reserved rate;
- immediately available rate.

Provider/runtime adapters can increase capacity when they add workers.  A scheduler can reduce a live job's reservation using `changeDeliveryRate()` to throttle it.

### `WLUDemandAssessment`

A side-effect-free enterprise planning result.  It exposes:

- available entitlement and entitlement shortfall;
- temporary token/burst limiting buckets;
- available delivery rate and delivery shortfall;
- limiting throughput pools;
- retry-after information where a refillable bucket can calculate it.

### `WLUReservation`

An admitted work and delivery envelope.  The reservation proof binds identity, scope, work ceiling, expected work, rate-card generation, WLU/s delivery promise, expiry and all policy-selected capacity constraints.

The caller cannot remove mandatory account/bucket/throughput bindings.

## Admission sequence

The intended fail-closed pattern is:

```text
consumer proposes metering facts / workload demand
        |
        v
WLU policy resolves rate card + entitlement + mandatory capacity constraints
        |
        v
assessment / reservation available?
        | NO
        +----> WLU_* exhaustion result; consumer remains untouched
        |
       YES
        v
verify authenticated reservation
        |
        v
perform side effect
        |
        v
publish resulting state
        |
        v
consume / settle actual WLU
        |
        v
release unused work ceiling and delivery capacity
```

## 429-like failures

The framework deliberately distinguishes different reasons work cannot begin:

- `WLU_ENTITLEMENT_EXHAUSTED` — insufficient admitted work entitlement;
- `WLU_CAPACITY_EXHAUSTED` — temporary token/burst capacity is unavailable; may carry `retryAfterSeconds`;
- `WLU_THROUGHPUT_EXHAUSTED` — requested WLU/s delivery rate cannot currently be reserved;
- `WLU_RESERVATION_EXPIRED` — an admission proof expired before use;
- `WLU_RESERVATION_PROOF_INVALID` — reservation authentication failed.

A throughput shortfall is deliberately structured rather than automatically firing up infrastructure.  Enterprise scheduling policy decides whether to scale, throttle, queue or reject.

## Policy-owned constraints

Bindings are selected by `identity` and `scope` patterns.  The authority derives all mandatory constraints.  A consumer cannot omit a global/provider capacity pool to evade admission control.

Multiple bound buckets or throughput pools are all mandatory constraints.  This makes it possible to enforce, for example, a client entitlement, a provider/model limit and a system-wide limit at once.

## Fast internal authentication

The hot internal path uses `SipHash-2-4-128` from the standalone `oorexx_crypto` package:

- 128-bit shared secret;
- 128-bit authentication tag;
- key id and algorithm travel with the proof;
- key-ring rotation is supported.

This is a keyed internal MAC, not a portable public-key signature.

Authenticated file-ledger records are MACed and chained on the same hot path.  `WLUEd25519CheckpointAuthority` is available for occasional asymmetric checkpoints/export evidence where third-party verification is useful.

## Terminal consumer example

TN5250 remains a consumer of WLU, not an accounting authority:

```text
WLU authority
    |
    +-- identity / entitlement
    +-- work reservation
    +-- delivery-capacity reservation
    +-- authenticated proof
    |
    v
TerminalControlGate
    |
    v
exclusive terminal control lease
```

The terminal emits facts; policy values them.  Capacity denial occurs before the terminal is allowed to mutate host state.

See `tests/test_terminal_client.rex`.

## Enterprise acceleration example

See `tests/test_enterprise_acceleration.rex` and `examples/enterprise_scheduler.rex`.

The acceptance test demonstrates:

- same WLU amount under slow and accelerated delivery;
- structured throughput shortfall;
- no entitlement mutation on failed accelerated admission;
- scale-out by increasing a logical capacity pool;
- throttling a live background job by reducing only its WLU/s reservation;
- actual settlement independent of acceleration;
- changing the delivery rate of an already-admitted reservation without changing its WLU ceiling.

## Logical jobs, budgets and backend escalation

A **logical job** is the business obligation, not one implementation call.  One chat/session may legitimately move through several execution implementations while remaining one WLU budget:

```text
FlyLo / Shannon chat CHAT-001
        |
        +--> deterministic script
                 | conversation needs more capability
                 v
              Gemma
                 | still insufficient
                 +--------> Grok
                 |
                 +--------> OpenAI
```

`WLUJobBudget.cls` models this as a sealed fallback graph plus one authenticated parent budget lease.  Each implementation receives an ordinary child `WLUReservation`; it does **not** receive a fresh copy of the whole job budget.

A stage declares separately:

- its execution WLU forecast and ceiling;
- explicit entry/handoff WLU forecast and ceiling (history replay, context rehydration, state conversion, warm-up, etc.);
- its execution scope, so policy can bind different provider/model capacity pools;
- an optional delivery target / WLU-per-second promise.

The application decides *why* a fallback is required (conversation quality, capability mismatch, host error, policy, etc.).  WLU does not attempt to judge conversation quality.  It answers the enterprise question: **which declared rescue routes still fit the same job budget and current capacity?**

### Parent budget accounting

The authenticated `WLUJobLease` carries:

- `expectedMicroWlu` — business-job forecast;
- `budgetMicroWlu` — hard logical-job WLU ceiling;
- `spentMicroWlu` — actual work already incurred across all implementations;
- `committedMicroWlu` — ceilings currently reserved by active child stages;
- `remainingMicroWlu = budget - spent - committed`;
- `strategyCeilingMicroWlu` — maximum WLU ceiling of any declared fallback path;
- coverage: `FULL_STRATEGY` or `PARTIAL_STRATEGY`.

Fallback branches are alternatives, so the strategy ceiling is the current stage plus the **maximum** successor path, not the sum of mutually exclusive Grok + OpenAI branches.

A 20-WLU budget may therefore admit a conversation whose fully protected fallback graph would require 24 WLU.  The job is valid, but its lease explicitly says `PARTIAL_STRATEGY`; the scheduler must not pretend every rescue path is guaranteed.

### Make-before-break escalation

The next stage can be reserved while the current stage is still live:

```text
script has performed work
        |
        +--> reserve Gemma + history handoff
                    | admission succeeds
                    v
             release old script stage
```

This prevents a stateful consumer from dropping a functioning execution path and only then discovering that its intended replacement cannot be admitted.  The same pattern applies to Gemma -> Grok/OpenAI, terminal-session migration, hosted worker replacement, or any other staged workload.

See `tests/test_job_budget_escalation.rex` and `examples/flylo_shannon_job.rex`.

## Optional finance/reporting adapter

`WLUReporting.cls` is intentionally downstream and optional.  It can translate settled WLU using a versioned price book for reporting, but neither `WLUAuthority` nor `WorkLoadUnits.cls` requires or understands any currency.

Removing `WLUReporting.cls` does not change workload admission, scheduling, reservations, proofs or settlement.

## Files

- `src/WorkLoadUnits.cls` — WLU units, facts, rate cards, entitlement, capacity, demand, reservations and authority;
- `src/WLUFastMac.cls` — WLU proof/key-ring compatibility facade over standalone `oorexx_crypto`;
- `src/WLULedger.cls` — authenticated durable ledger and Ed25519 checkpoint boundary;
- `src/WLUJobBudget.cls` — authenticated logical-job budgets, staged execution plans and fallback assessment;
- `src/WLUReporting.cls` — optional downstream financial/reporting translation;
- standalone `oorexx_crypto_v0.1/src/crypto.cls` — authoritative cryptographic primitives;
- `tests/` — executable acceptance tests;
- `examples/` — integration examples.

## Running tests

Set `REXX` if `rexx` is not on `PATH`:

```sh
REXX=/path/to/rexx ./run_tests.sh
```

The package was developed and validated against the user-supplied Open Object Rexx 5.3.0 r13196 64-bit debug build.


## Crypto dependency (v0.2.1)

v0.2.1 no longer vendors `src/crypto.cls`. Set `CRYPTO_SRC` (or `OOREXX_CRYPTO_SRC`) to the `src/` directory of `oorexx_crypto_v0.1` when running the suite or embedding WLU. The WLU-specific `WLUSipHash128` class is retained only as a compatibility subclass; the algorithm has one authoritative implementation in the crypto package.
