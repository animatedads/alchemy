# Changelog

## v0.2.1

- Removes the vendored `src/crypto.cls`; WLU now depends explicitly on standalone `oorexx_crypto_v0.1`.
- Removes the private SipHash-2-4-128 implementation from `WLUFastMac.cls`; `WLUSipHash128` is now a compatibility subclass of the shared `.SipHash128`.
- Preserves WLU proof/key-ring wire semantics, SipHash algorithm id, authenticated ledger checkpoints and all v0.2 workload/budget behaviour.
- Test runner requires `CRYPTO_SRC`/`OOREXX_CRYPTO_SRC`, preventing accidental fallback to a stale local crypto copy.


## v0.2

- Added logical-job budgeting: one business job/session can span several execution implementations without minting a new budget per backend call.
- Added sealed fallback execution graphs (`WLUJobPlan` / `WLUJobStage`).
- Added explicit handoff/rehydration workload allowance for history replay and state migration.
- Added authenticated parent `WLUJobLease` with spent, committed and remaining WLU.
- Added strategy coverage (`FULL_STRATEGY` / `PARTIAL_STRATEGY`) against the maximum declared fallback path.
- Added side-effect-free fallback viability assessment against both remaining parent budget and live WLU authority capacity.
- Added make-before-break stage admission so replacement execution can be reserved before an old path is released.
- Added authoritative consumed-WLU query so releasing a child stage preserves already-incurred work in the parent budget.
- Added FlyLo/Shannon script -> Gemma -> Grok/OpenAI escalation acceptance case.

## v0.1

Initial Work Load Units framework.

- Stable integer micro-WLU representation.
- Consumer metering facts and sealed/versioned WLU rate cards.
- Entitlement accounts separate from currency.
- Refillable WLU token/burst capacity buckets with retry-after calculation.
- Work demand model with expected WLU, admitted ceiling and requested WLU/s delivery capacity.
- Reservable WLU/s throughput pools for enterprise scheduling and acceleration.
- Structured, side-effect-free demand assessment.
- Policy-owned account, bucket, throughput and rate-card bindings.
- Atomic admission across all mandatory constraints.
- Idempotent reservations and consumption operations.
- Progressive consumption, top-up, expiry, settlement and release.
- Live delivery-rate reshaping for acceleration/throttling without changing work WLU.
- Fast internal SipHash-2-4-128 reservation authentication.
- Authenticated chained durable ledger.
- Optional Ed25519 ledger checkpoints at export/trust boundaries.
- Optional downstream financial/reporting adapter kept outside the WLU core.
- TN5250 fail-before-side-effect consumer acceptance case.
- Enterprise scale-out/throttle/accelerate acceptance case.
