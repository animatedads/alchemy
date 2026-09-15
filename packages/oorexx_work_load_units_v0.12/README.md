# ooRexx Work Load Units v0.12

`work.load.units/0.12` is a common workload accounting, admission and delivery-capacity primitive for ooRexx systems.

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

## Hierarchical workload budgets

`WLUHierarchy.cls` adds enterprise/tenant/service/job budget constraints without inventing additional work. A single reservation is checked against the leaf and every ancestor. The same commitment/spend is reflected at each level for constraint and audit purposes, so hierarchy figures are **not additive**.

Example:

```text
ENTERPRISE        100 WLU ceiling
  └─ FLYLO         80 WLU ceiling
      └─ SHANNON    60 WLU ceiling
          └─ CHAT   20 WLU ceiling
```

If a Gemma stage reserves 10 WLU and settles at 6 WLU, each of those four envelopes reflects the same 6 WLU actual work. It is still 6 WLU, not 24.

Child ceilings are constraints rather than pre-spent allocations. Sibling child ceilings may therefore sum beyond the parent ceiling; live reservations still have to fit every ancestor atomically. This keeps unused headroom shareable while preserving hard enterprise limits.

The hierarchy supplies authenticated node leases and authenticated work holds, idempotent hold requests, top-up, settlement/release, ancestor-limiter assessment, and explicit stale/tamper rejection.

## Work lifecycle

A workload can carry three useful quantities:

- `expectedMicroWlu` — expected work for this individual demand/reservation;
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

- `expectedMicroWlu` — initial business-job estimate supplied when the logical job opened;
- `budgetMicroWlu` — hard logical-job WLU ceiling;
- `spentMicroWlu` — actual work already incurred across all implementations;
- `committedMicroWlu` — ceilings currently reserved by active child stages;
- `remainingMicroWlu = budget - spent - committed`;
- `strategyCeilingMicroWlu` — maximum WLU ceiling of any declared fallback path;
- coverage: `FULL_STRATEGY` or `PARTIAL_STRATEGY`.

Fallback branches are alternatives, so the strategy ceiling is the current stage plus the **maximum** successor path, not the sum of mutually exclusive Grok + OpenAI branches.

A 20-WLU budget may therefore admit a conversation whose fully protected fallback graph would require 24 WLU.  The job is valid, but its lease explicitly says `PARTIAL_STRATEGY`; the scheduler must not pretend every rescue path is guaranteed.

### Live forecast revisions

The initial `expectedMicroWlu` is not silently rewritten as a job learns more. v0.5 adds an authenticated, revisioned live-forecast stream to the logical-job authority. An estimator can report:

- expected remaining WLU at the observation point;
- an upper remaining WLU estimate;
- a declared confidence value in basis points (`0..10000`);
- estimator/source and explanatory reason.

WLU records the observation tick, actual spent/committed state at that point, projected expected total, projected upper total, trend against the previous projected expected total, and any shortfall against the unchanged hard budget.

Forecast status is intentionally simple:

- `WITHIN_BUDGET` — expected and upper projections fit the hard job budget;
- `AT_RISK` — expected projection fits but the upper projection exceeds budget;
- `EXPECTED_OVER_BUDGET` — the expected projection itself exceeds budget.

A forecast is **not admission authority**. It may exceed the hard budget and still be accepted, because rejecting bad news would hide the condition the scheduler needs to see. Recording or revising a forecast reserves no account WLU, consumes no hierarchy budget and grants no additional entitlement. Policy may decide to scale, re-route, seek a larger budget, throttle other work, or continue anyway.

Each forecast revision carries the same fast internal MAC proof model as other WLU internal evidence and remains available through immutable forecast history. The confidence figure is supplied by the estimator; WLU preserves it but does not pretend to derive or statistically validate it.

See `tests/test_live_forecast.rex` and `examples/live_job_forecast.rex`.


### Contingency / standby rescue capacity

A live forecast can say that escalation is becoming plausible before the application has actually decided to switch backend. v0.6 adds an authenticated **standby intent** for that planning interval.

A standby is deliberately weaker than a reservation:

```text
forecast:  rescue may be needed
        |
        v
standby:   describe the declared rescue stage
           + WLU ceiling
           + WLU/s demand
           + expiry
           + advisory priority
        |
        +----> reserves 0 account WLU
        +----> reserves 0 hierarchy WLU
        +----> reserves 0 WLU/s
        |
application decides to switch
        |
        v
promotion: ordinary hard stage reservation
           across job + hierarchy + provider/runtime capacity
```

This lets an enterprise scheduler preserve or provision likely rescue capacity without WLU pretending that speculative work has already been admitted. The advisory priority (`0..1000`) is evidence for scheduling policy; WLU itself does not evict a lower-priority job merely because a standby has a larger number.

`WLUJobStandbyLease` binds the logical job, declared stage, stage ceiling, requested delivery rate, creation/expiry ticks, priority, lifecycle state and any promoted reservation id under the normal fast MAC.

States are:

- `ACTIVE` — planning intent is live;
- `PROMOTED` — the intent was converted into a real child reservation;
- `RELEASED` — the caller withdrew the intent;
- `EXPIRED` — effective state after the signed expiry tick has passed.

Creation, assessment and expiry of a standby do not alter the authenticated hard job counters. `assessStandby()` combines the current hard job budget and runtime demand assessment; the hierarchical bridge additionally checks the leaf and every ancestor. A failed promotion leaves the standby active so the scheduler can scale/throttle/retry rather than losing its rescue plan.

Promotion is explicit and make-before-break. Only successful promotion creates the ordinary account/bucket/WLU/s reservation and hierarchy hold. Settlement then works exactly like any other stage.

v0.6 also separates **semantic release** from **transaction rollback** in `WLUHierarchyBudgetManager`. If a hierarchy hold is created as an internal subtransaction and downstream provider/core admission then fails, `rollbackHold()` removes both the temporary commitment and its unpublished idempotency marker. Retrying the same promotion request id therefore cannot replay a released zero-commit hierarchy hold.

See `tests/test_contingency_standby.rex`, `tests/test_contingency_standby_direct.rex` and `examples/shannon_standby_rescue.rex`.


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

### Runtime route evidence and handoff accounting

Forecasts and standby claims describe what **may** happen. v0.8 adds a separate authenticated route-evidence stream describing what the application actually chose and what execution subsequently occurred. This evidence remains non-entitling: recording a fallback decision reserves zero WLU and zero WLU/s.

`recordTransition()` only accepts edges already present in the sealed `WLUJobPlan`. The application supplies an opaque `reasonCode` such as `QUALITY_POLICY`, `PROVIDER_FAILURE`, `CAPABILITY_REQUIRED`, or another policy-defined value. WLU authenticates the statement but does not inspect conversation content or decide whether the reason is substantively correct. An optional `evidenceRef` can point to richer evidence owned by another subsystem without copying that content into WLU.

Route evidence records:

- logical job and route revision;
- target stage and optional predecessor stage;
- reservation id when hard admission actually occurred;
- stage expected/ceiling WLU;
- forecast revision/status captured when the stage was admitted;
- standby lineage when a standby was promoted;
- pinned rate-card id/version;
- explicit execution versus handoff actual WLU when the caller knows the breakdown;
- application outcome/reason code and external evidence reference;
- an internal SipHash proof.

`settleStageBreakdown()` is the explicit boundary for actual handoff accounting. A stage that performs 4 WLU of backend work and 1 WLU of history/context rehydration still settles **5 WLU total** into the parent job and every hierarchy ancestor; route evidence simply preserves that 1 WLU was handoff rather than inventing another accounting dimension. Existing `settleStage()` remains compatible and records a total-only outcome when the breakdown is not known.

`routeHistory()` returns the authenticated event stream and `routeSummary()` derives counts, actual WLU, known handoff WLU and over-expected-stage counts from it. This is the evidence layer needed for later cross-job route statistics; v0.8 itself does not automatically learn or choose providers.

Transition recording and hard stage reservation are both idempotent. Replaying the same stage request no longer double-commits the logical-job ceiling, and a caller may supply a route request id so retrying the same fallback decision does not duplicate evidence.

See `tests/test_route_execution_evidence.rex`, the strengthened hierarchy/provider-plan tests, and `examples/route_execution_feedback.rex`.

### Durable route-evidence archive

v0.9 adds `WLURouteJournal.cls`, a separate append-only MAC-chained archive for logical-job route evidence. `archiveRouteHistory()` copies authenticated route events into that archive without changing job spend, commitment, account reservations, hierarchy holds or throughput allocation. The archive is idempotent on `(jobId, routeRevision)`, rejects conflicting or out-of-order replays, verifies each original event MAC, and adds a second chain MAC protecting archive order and interior deletion.

Reopening the journal after process restart reconstructs only verified historical indexes. `history(jobId)` and `summary(jobId)` reproduce durable route evidence and derived WLU/handoff totals; they do **not** reopen a logical job, recreate a reservation, grant entitlement or invoke a provider. This keeps route durability separate from active workload authority.

The accounting ledger remains separately authoritative for reservation/consumption/settlement evidence. Route evidence explains implementation choice and execution/handoff shape; it is not silently promoted into accounting authority. Key rotation is supported because both event proofs and journal-chain proofs retain algorithm/key identifiers.

See `tests/test_route_journal.rex`, `tests/test_route_journal_rotation.rex` and `examples/durable_route_replay.rex`.

### Cross-job route statistics

v0.10 adds `WLURouteAnalytics.cls`, a deliberately read-only statistics layer over **verified durable route evidence**. The analytics surface has no WLU authority: it cannot open a job, grant entitlement, reserve account WLU, acquire hierarchy holds, reserve WLU/s delivery capacity, promote standby work or invoke a provider.

`verifiedSnapshot(journal)` verifies the complete route journal once and returns an immutable evidence cut containing the exact verified event count and terminal chain tag. Multiple reports can then be derived from that same cut without repeatedly recomputing every SipHash proof or accidentally observing different journal tails. A later journal append requires a fresh snapshot to become visible. If the backing journal is subsequently damaged, an already verified snapshot remains a legitimate historical cut, but the damaged journal cannot mint a new trusted snapshot.

Stage statistics are explicitly scoped by:

- stage id;
- inclusive `windowStartTick` / `windowEndTick` (`0` means unbounded on that side);
- an optional explicit collection of logical job ids forming the cohort;
- a caller-declared `minimumSamples` threshold (default `30`).

Every `WLURouteStageStatistics` report retains the exact matched-job count and stage-close sample count alongside settled/released counts, raw application-declared outcome-code counts, actual WLU, known handoff WLU, over-expected count and the declared threshold. **Insufficient evidence is not hidden:** the report remains readable, but `sufficientSample` is false until `sampleCount >= minimumSamples`. This is intended to prevent a downstream scheduler or LLM from receiving a naked percentage with no indication of weight.

For two proportions, v0.10 also provides observed basis-point rates and 95% Wilson score intervals:

- application-declared `SUCCESS` among stage-close samples;
- stages whose authenticated actual total exceeded their admission-time expected WLU.

The qualification is important. `SUCCESS` is an opaque application outcome label authenticated by WLU; it is **not** an independent WLU judgement that a provider answered well. A Wilson interval describes sampling uncertainty around the observed proportion; it does not prove independence, eliminate selection effects, normalize prompt/model/version changes, or establish causal provider quality. Those remain external analytical responsibilities.

`transitionStatistics()` similarly counts authenticated declared fallback edges and their opaque reason codes over an exact window/cohort. It does not invent a denominator or call a transition a failure/success unless the application supplied such evidence elsewhere.

See `tests/test_route_analytics.rex` and `examples/route_statistics_report.rex`.

### Evidence-weighted route advice

v0.11 adds `WLURouteAdvisory.cls`. It turns a **verified analytics snapshot plus an explicit policy** into advisory candidate assessments; it is not an admission or execution authority. `WLUJobRouteAdvisor` accepts no `WLUAuthority`, provider transport, credential, hierarchy manager or standby authority and cannot spend/reserve WLU, reserve WLU/s, promote a standby route or invoke a backend.

The default advisory policy deliberately starts conservatively with `minimumSamples = 30`. Policy also declares a minimum 95% Wilson lower bound for application-declared `SUCCESS`, a maximum 95% Wilson upper bound for over-expected execution, and an optional observed average-actual-WLU ceiling. Small samples remain visible but are `INSUFFICIENT_SAMPLE`; they do not become decision-eligible merely because their observed percentage looks attractive.

Eligible candidates are ranked with an inspectable lexicographic rule rather than an opaque weighted score:

1. higher conservative SUCCESS lower bound;
2. lower conservative over-expected upper bound;
3. lower observed average actual WLU;
4. lower declared expected WLU.

Exact ties preserve caller candidate order. If every candidate fails the evidence gates, the result is `NO_EVIDENCE_ELIGIBLE_ROUTE`; WLU does not invent a default provider. Every assessment retains raw stage statistics, sample sufficiency, observed rates, Wilson bounds, average WLU and explicit rejection reasons. The returned recommendation also pins the analytics snapshot sequence/tag so the consumer knows exactly which historical evidence cut informed the advice.

`SUCCESS` remains an application-declared authenticated outcome code. The advisory therefore means only **"under this declared evidence policy, this candidate is preferred among the supplied choices"**. It does not convert historical labels into causal truth, erase model/prompt drift, or authorize execution. The scheduler/application remains responsible for the actual route decision, and ordinary WLU admission remains responsible for hard workload authority.

See `tests/test_route_advisory.rex` and `examples/evidence_weighted_route_advice.rex`.

### Policy-governed use of route advice

v0.12 adds `WLURouteDecisionPolicy.cls` and makes advisory output itself authenticated. A `WLURouteAdvisoryResult` now carries a SipHash proof over the exact verified analytics sequence/tag, advisory thresholds, candidate assessments and recommendation. Changing the recommendation or any covered assessment material invalidates that proof.

`WLUJobRouteDecisionGate` is the deterministic boundary between **advice** and an external scheduler's decision to act on advice. It accepts an authenticated advisory result plus the shared `InstitutionalPolicyCatalog`; it accepts no `WLUAuthority`, job manager, hierarchy manager, throughput pool, provider transport or credential and cannot reserve or spend WLU.

The domain payload `WLURouteDecisionRules` deliberately owns only WLU route-selection semantics. Publication lifecycle is not duplicated. `institutional_policy_v0.1` supplies the policy id/version, authorship/approval identifiers, effective `[from,until)` window, supersession lineage, immutable publication record and the `FIXED_REVIEWABLE_VERSIONED_ARTIFACT` execution-model declaration.

Two actor surfaces are explicit: `AUTOMATED` and `OPERATOR`. Each published rule set selects one inspectable rule from:

- `DENY`;
- `RECOMMENDED_ONLY`;
- `EVIDENCE_ELIGIBLE`;
- `DECLARED_CANDIDATE`.

For example, a production policy may allow an automated scheduler to follow **only** the evidence-weighted recommended route while allowing an operator to select any route that independently cleared the evidence gates. A different reviewed release may disable automated switching entirely.

`decide()` resolves the policy that was actually operative at the action time and returns authenticated `WLURouteDecisionEvidence` retaining the exact rich policy release, publication record, institutional execution context, advisory source sequence/tag, **advisory proof key/tag**, proposed stage, actor mode and deterministic reason code. The advisory proof identity matters because the same historical journal can legitimately be analysed under different thresholds.

`counterfactual()` evaluates an explicitly selected sealed alternative policy without pretending it was operative. Its evidence is labelled `COUNTERFACTUAL` and carries no fabricated operative publication record. `compare()` delegates generic outcome/trace comparison to `InstitutionalPolicyComparison`.

This remains a governance/evidence boundary rather than admission authority. A `PERMITTED` decision means only that the fixed institutional route-selection policy permits the external scheduler to proceed to the **ordinary WLU admission path**. It does not itself create entitlement, reservations, hierarchy holds, throughput claims, standby promotion or provider execution.

See `tests/test_route_decision_policy.rex` and `examples/policy_governed_route_decision.rex`.

## Provider-neutral external execution plans

`WLUExternalPlan.cls` imports narrow pre-admission plans without giving WLU provider authority. A compatible plan exposes only `scope`, `plannedFacts`, `ceilingMicroWlu`, `targetSeconds`, `ttlSeconds` and `requestId`; facts expose `factType`, `quantity`, and optional `source`/`dimensions`. This is intentionally compatible with Runtime Registry `AbilityWLUPlan` / `AbilityMeterFact`, but WLU does not require Runtime Registry, AI Access, Grok, OpenAI-compatible provider code, credentials, transport objects, prompts or responses.

The WLU authority re-values all imported facts under its own sealed rate card. A planner cannot understate policy valuation: a supplied ceiling below the authoritative quote fails closed with `WLU_EXTERNAL_PLAN_CEILING_BELOW_QUOTE`. The resulting `WLUJobStage` pins the quote rate-card id/version, and hard stage reservations and standby promotions preserve that generation in authenticated reservation evidence.

This allows provider-specific planners to become alternative stages of one logical chat/session. Gemma, Grok and OpenAI-compatible routes can all sit beneath `CHAT-001`; switching backend does not mint a new parent budget. If carried conversation history is already included in provider input-token facts, callers should not add a second handoff charge for the same bytes/tokens. Separate handoff WLU is only for genuinely additional conversion, replay or rehydration work.

Import itself creates no reservation and invokes no provider. `examples/provider_plan_route.rex` demonstrates the boundary.

## Alchemy Objects v0.7 adoption

Long-lived WLU behavioural objects are qualified with `AlchemyAdoptionVerifier`. v0.12 uses `alchemy_objects_v0.7`, enters the base through the preferred non-virtual `self~init:super(...)` path, supplies STANDARD metadata, produces zero `LEGACY_INIT_ENTRYPOINT` warnings, passes reserved-base inheritance integrity checks, and `WLUAuthority` also qualifies `SECURE_READY` on the supplied r13196 runtime. `WLUJobRouteDecisionGate` joins that adoption set. Value carriers remain lightweight ordinary objects.

## Optional finance/reporting adapter

`WLUReporting.cls` is intentionally downstream and optional.  It can translate settled WLU using a versioned price book for reporting, but neither `WLUAuthority` nor `WorkLoadUnits.cls` requires or understands any currency.

Removing `WLUReporting.cls` does not change workload admission, scheduling, reservations, proofs or settlement.

## Files

- `src/WorkLoadUnits.cls` — WLU units, facts, rate cards, entitlement, capacity, demand, reservations and authority;
- `src/WLUFastMac.cls` — WLU proof/key-ring compatibility facade over standalone `oorexx_crypto`;
- `src/WLULedger.cls` — authenticated durable accounting ledger and Ed25519 checkpoint boundary;
- `src/WLURouteJournal.cls` — durable MAC-chained non-entitling logical-job route-evidence archive and replay/view surface;
- `src/WLURouteAnalytics.cls` — verified-snapshot, time/cohort/sample-threshold route statistics with explicit raw counts and Wilson intervals;
- `src/WLURouteAdvisory.cls` — authenticated non-authoritative evidence-policy gating and deterministic candidate recommendation over verified analytics snapshots;
- `src/WLURouteDecisionPolicy.cls` — shared-institutional-policy-backed non-entitling scheduler decision gate with operative/counterfactual evidence;
- `src/WLUJobBudget.cls` — authenticated logical-job budgets, forecasts, standby/rescue intents, staged execution plans, route evidence and explicit handoff outcomes;
- `src/WLUHierarchy.cls` — hierarchical enterprise/tenant/service/job workload-budget constraints, authenticated holds and explicit unpublished-hold rollback;
- `src/WLUHierarchicalJob.cls` — admission bridge binding logical backend stages and standby promotion to enterprise hierarchy holds with rollback on failed admission/top-up;
- `src/WLUExternalPlan.cls` — provider-neutral import of narrow pre-admission execution plans into policy-valued logical-job stages;
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


## Crypto dependency

v0.12 does not vendor `src/crypto.cls`, any Alchemy base source, or the shared Institutional Policy source. Set `CRYPTO_SRC` (or `OOREXX_CRYPTO_SRC`) to `oorexx_crypto_v0.1/src`, `ALCHEMY_OBJECTS_SRC` to `alchemy_objects_v0.7/src`, and `INSTITUTIONAL_POLICY_SRC` to `institutional_policy_v0.1/src` when running the complete suite or using the policy-governed route-decision surface. The WLU-specific `WLUSipHash128` class is retained only as a compatibility subclass; the algorithm has one authoritative implementation in the crypto package.

## Alchemy object foundation

WLU v0.12 uses `alchemy_objects_v0.7` for long-lived authority objects. `WLUAuthority`, `WLUHierarchyBudgetManager`, `WLUJobBudgetManager`, `WLUHierarchicalJobManager`, `WLUAuthenticatedFileLedger`, `WLUJobRouteFileJournal`, `WLUJobRouteAnalytics`, `WLUJobRouteAdvisor`, `WLUExternalPlanImporter`, and `WLUJobRouteDecisionGate` inherit `AlchemyObject`. They use the preferred `self~init:super(...)` construction path and therefore expose stable construction provenance as well as object identity, method/surface contracts, lifecycle and telemetry surfaces, requirement declarations, relationship evidence, disclosure-labelled state, capability-gated introspection and SipHash-sealed evidence.

The inheritance boundary is deliberately not universal. High-frequency/value-carrier objects such as `WLUFact`, `WLUChargeLine`, quotes, reservations, leases and proofs remain lightweight ordinary ooRexx objects. WLU does not pay object-introspection overhead for every token, byte or field-write fact merely to satisfy a stylistic rule.

WLU requires the base class directly through `AlchemyObject.cls`; it does not load the broad `AlchemyObjects.cls` convenience bundle on the normal admission path. Inspector Clouseau remains a host-selected deep-inspection facility instead of becoming an implicit WLU runtime dependency.

The WLU MAC key ring is also used as the cryptographic source for Alchemy evidence/capabilities within the same internal trust domain. This does not change WLU reservation semantics or convert WLU into money.
