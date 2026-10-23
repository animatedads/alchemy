# Cloud Economics and Workload Commissioning v0.1-dev8

**Contract:** `cloud.economics/0.1` — **mode:** `PAPER_ONLY` — **runtime:** ooRexx 5.3.0 r13196. No real cloud purchases, reservations, cancellations or payment operations exist in this package.

**dev7:** Adds `CloudMigrationContinuationBridge.cls`, a read-only native
Migratable Job `migratable.job/0.2` integration. It checks a genuine portable job
definition and destination-policy object against the dev6 native
lease/lifecycle/Memory Fabric advisory; it subsequently reconciles checkpoint
and transfer records, and estimates transferred-byte cost variance **without**
checkpointing, fencing, buying, scheduling or resuming. No record is treated as
cryptographically verified transfer, a fresh lease, or final invoice. Optional
native test requires Migratable Job v0.2.2 and the latest supplied JNA
network5/Memory Fabric dev10. See
[docs/NATIVE_CONTINUATION_AUTHORITY_DEV7.md](docs/NATIVE_CONTINUATION_AUTHORITY_DEV7.md).

**dev6:** Introduces native lease, running lifecycle and Memory Fabric
execution-context eligibility with a read-only advisor.

**dev5:** Adds `CloudMigrationEconomics.cls`, a marginal-cost, running-job
migration comparator: remaining compute vs checkpoint, transfer, restore,
startup, billing quantization, future financial liabilities, bandwidth and
anti-churn. Explicit intention/route evidence references are carried in
`PAPER_MOVE_FAVORED` advice but never mistaken for leasing or execution
rights. New atomically switched `ingest-mobility` snapshots,
`migration-preview`, `migration-tick`, and `opportunities` allow continuous
advisory monitoring without modifying the paper purchase ledger. See
[docs/MIGRATION_ECONOMICS_DEV5.md](docs/MIGRATION_ECONOMICS_DEV5.md).

**dev4:** Adds opt-in whole-job economics: real billing increments and minima,
input/output transfer, scratch/checkpoint storage, I/O traffic, measured
checkpoint scheduling overhead and explicit expected interruption/recovery
provisions. It evaluates all eligible single-node and qualified segmented
Memory Fabric alternatives and uses the resulting full cost in the *existing*
paper scheduler. Every new paper decision includes auditable component sums,
source-snapshot identity and SHA-256 fingerprints; accounting uses 20-digit
precision and still freezes on tampered receipts. `cloud-cost preview` is a
read-only what-if comparison. Load versioned, semantically validated terms and
profiles with `cloud-cost ingest-economics`; no implicit switch from dev3.
See [WHOLE_JOB_ECONOMICS_DEV4.md](docs/WHOLE_JOB_ECONOMICS_DEV4.md).

**dev3:** First read-only market observer expansion: AWS Spot tariff history
with per-zone/shape evidence; GCP unit-aware public Billing SKU component
observation and separate trend history; API throttling; and stricter provider
snapshot validation. Use `cloud-cost trends`, `cloud-cost evidence AWS` and
`cloud-cost components GCP`. These are NOT verified purchasable capacities.
Complete adapter contracts, operational enablement and proof limitations:
[`docs/PROVIDER_OBSERVATION_DEV3.md`](docs/PROVIDER_OBSERVATION_DEV3.md).

**dev2 addition:** `src/CloudEconomicsAuthority.cls` provides an object-preserving
advisory bridge that uses the actual Generalized Compute Intentions route,
Memory Fabric capacity plan and registry, and optional JobNodeAllocator policy
evidence before economic ranking. These real object interfaces are a separate,
opt-in path from the standalone TSV paper daemon. See
[`docs/AUTHORITY_BOUNDARY.md`](docs/AUTHORITY_BOUNDARY.md) for the exact
contracts, proofs and qualified limitations. Ledger audit and single-writer
local locking are also new in dev2. The simulation figures remain fixtures.

The module is the *economic advisory and simulated commissioning authority*, not a second queue or node allocator. It examines price observations and capabilities, compares feasible execution schemes, schedules or holds work, makes an idempotent **PAPER_BUY** decision and records two-sided accounting entries. The module can run continuously, accepting new jobs via a persistent spool.

## Integration boundaries

| Estate service | Its authority | Cloud Economics use |
|---|---|---|
| Generalized Compute Intentions v0.1-dev3 | Dynamic compute discovery, independently contributed assessments and non-mutating planned admission | `CloudEconomicIntentionBridge` filters market quotes to candidates admitted by an injected actual `GeneralizedComputeIntentionProvider`; a veto is never overruled |
| Job-to-Node Allocator v0.6-network3 | Hard authority/legal/capacity admission, unique placement lease and owner fencing | Future real path: planner outputs requirements; allocator must **revalidate** and allocate before any execution; no lease is made here |
| QueueRexx / WLU / Registered Job | Work admission, resource contention and authoritative lifecycle | Planner outputs `PAPER_BUY`, `PAPER_HOLD`, `NO_ELIGIBLE_OPTION` and receipts, not worker launches |
| Memory Fabric v0.1-dev7 | Provider discovery, memory segments, ownership and locality | 2 × 32 GiB requires a declared `SEGMENTED` workload, same-site eligibility and `fabric_ok=1` from a certified adapter; never merged CPUs or transparent remote pointers |
| Registered Job Economic Hold (`registered.job.economic/0.1`) | Deterministic economic holds and deadline overrides | Compatible decision vocabulary; the cost engine does **not** replace this evaluator |
| Instrumentation Mesh v0.1-dev3 | Standard semantic identity, metrics, collector and history | Optional `CloudEconomicsInstrumentation` emitter; ledger remains accounting truth |
| Cloud provider APIs / price adapters | Price and SKU facts, not job authority | Normalized timestamped quote snapshots; the public Azure adapter is read-only and **unverified for actual capacity** |

The real placement chain is: **job requirements -> capability/intent discovery -> hard admissibility -> pricing and forecast -> paper commitment -> (future real workflow) revalidate rights/capacity, secure authorisation, lease/start -> actual billing reconciliation**. This package implements through the paper commitment only.

## Running-job mobility advisory (dev5)

```sh
./tools/cloud-cost ingest fixtures/mobility_offers.tsv
./tools/cloud-cost ingest-economics fixtures/mobility_terms.tsv fixtures/workload_economics.tsv
./tools/cloud-cost ingest-mobility fixtures/mobility_running.tsv fixtures/mobility_routes.tsv
./tools/cloud-cost migration-preview 1791000000 # historical fixture scenario, no mutation
./tools/cloud-cost migration-tick               # present wall clock, latest advisory
./tools/cloud-cost opportunities                # inspect latest result
./tools/cloud-cost watch 60                     # now includes migration advisory when configured
```

No offer/route TSV may be elevated to real spend, data transfer or migration
authority. The active watcher merely writes `migration_latest.tsv`, separate
from immutable paper purchase receipts/accounts. See the dev5 design document
for exact evidence requirements, cost decomposition, snapshot validation and
limitations.

## Run and reproduce

```sh
# Install your provided ooRexx 5.3.0 r13196, then:
export REXX_BIN=rexx
export CLOUD_ECONOMICS_STATE="$HOME/cloud-economics-state"
./tools/cloud-cost ingest fixtures/offers.tsv
./tools/cloud-cost submit fixtures/jobs.tsv
./tools/cloud-cost tick
./tools/cloud-cost report
# Optional: activate a semantically validated, versioned whole-job model
./tools/cloud-cost ingest-economics fixtures/economic_terms.tsv fixtures/workload_economics.tsv
./tools/cloud-cost preview  # no ledger writes
 ./tools/cloud-cost tick     # new paper commitments use complete costs
./tools/cloud-cost audit
./tools/cloud-cost discover
./tools/cloud-cost poll
  ./tools/cloud-cost providers
  ./tools/cloud-cost trends
./tools/cloud-cost watch 60             # stays in the foreground indefinitely
```

`fixtures/` is **invented training data, not market rates**. With these fixtures a 64-GiB segmented job chooses two **AWS same-site** 32-GiB Spot capacity offers, while an incompatible contiguous-memory job chooses a single OCI 64-GiB instance. The $0.676 split cost includes two $0.28 instance-hour tariffs, $0.056 expected interruption risk provision, and $0.06 fabric overhead. It is a hypothetical example; Memory Fabric and topology certification are represented by fixture flags, not a live cluster proof.

For a persistent host run, install `deployment/cloud-economics.service` after replacing its package path and unprivileged user and configuring `CLOUD_ECONOMICS_STATE`. The process runs indefinitely in the foreground; systemd restarts it after unexpected exits. **No daemon can be kept running on your own host by merely receiving this archive.**

## Real quote monitoring

Run `./tools/cloud-cost watch 60` for observation cycles. It surveys the state of 23 registered provider *sources* and explicitly reports `OBSERVED`, `CATALOG_ONLY`, `CATALOG_CACHED`, `NO_OFFERS`, `STALE`, `UNCONFIGURED`, `INVALID_SCHEMA`, `INVALID_DATA` or `ERROR` (no fake quotes for missing sources).

- **Azure:** enable `CLOUD_ECONOMICS_AZURE_ENABLE=1` to query Microsoft's public Retail Prices API over HTTPS for the curated Linux-compatible VM metering examples in `fixtures/azure_skus.tsv`. This is advertised list pricing, including available Spot retail meter entries — **not** a Spot clearing-price/availability guarantee, account-specific discount, quota proof or permission to buy. Azure records are forced to `approved=0`, `capacity=0`, `fabric_ok=0`, `runtime=UNKNOWN` until independent authoritative adapters supply the required evidence.
- **AWS:** optional `CLOUD_ECONOMICS_AWS_ENABLE=1` enables read-only `DescribeSpotPriceHistory` plus `DescribeInstanceTypes` for an explicit region/SKU allowlist. Price-change and observation timestamps are separate. This reports Spot tariff data only; no on-demand baseline, price completeness, purchase rights or Spot capacity is implied.
- **GCP:** optional `CLOUD_ECONOMICS_GCP_ENABLE=1` with a caller-provided approved API key and curated SKU allowlist observes Compute Engine Billing v1 public component prices **with their original billing units**; it does not convert a RAM/CPU component tariff into a full VM quote or place it into the booking feed.
- **OCI / IBM and other estates:** plugin sources accept normalized read-only snapshots from official or contract-account price adapters. No claim is made that all these providers expose identical unauthenticated or cost-free price endpoints.
- **Tracked registry:** AWS, AZURE, GCP, OCI, IBM, OVH, SCALEWAY, HETZNER, OTC, ALIBABA, TENCENT, HUAWEI, COREWEAVE, LAMBDA, NVIDIA_DGX, CLOUDFLARE, FASTLY, FLY, VMWARE, OPENSTACK, OPENSHIFT, COLAB and HUGGINGFACE. A local/private-resource source can use the same read-only offer contract.

To provide a normalized provider-specific feed, place `sources/PROVIDER.tsv` under `$CLOUD_ECONOMICS_STATE` or run `./tools/cloud-cost ingest-provider AWS /path/to/aws.tsv`. Names must use the exact registered uppercase identifiers. `poll` merges all configured source snapshots atomically and updates the bounded recent price-history window. Do **not** copy real credentials to this directory or into the job/offer files. Price adapters should obtain read-only credentials from the estate identity/secret broker without logging them.

An `OBSERVED` quote is still **not eligible to book** unless it independently satisfies hard legal, runtime, region, capacity, freshness and permissions evidence. A public tariff is intentionally not entitled to be booked.

## Input contracts

`offers.tsv` is one line per **unique capacity-offer identity**. Its exact header is in `fixtures/offers.tsv`:

`id, provider, region, site, sku, purchase, mem, cpu, gpu, rate, startup, network, fabric, risk, approved, capacity, fabric_ok, ts, expiry, currency, source, jurisdiction, runtime` (tab-separated).

- Units: GiB RAM; virtual CPUs; GPU count; USD/hour (`rate`); USD start fee (`startup`); USD/GiB data movement (`network`); USD/hour fabric overhead (`fabric`); per-hour expected interruption-loss fraction (`risk`); UTC Unix seconds (`ts`/`expiry`). Only USD matching is implemented; there is no silent currency conversion.
- `approved=1` is an externally supplied **hard authority eligibility assertion**; `capacity=1` is an externally verified offer slot; `fabric_ok=1` requires Memory Fabric topology and compatible RAM semantics. An offer does not itself carry a real lease. Public scraping may not assert these flags.
- Every offer ID is treated as one reusable **time-window** capacity slot, *not* an unlimited SKU. Produce distinct IDs for separately available instances and keep provider and availability-zone identities stable. A bad external assertion can invalidate a paper decision; never promote it into real purchase authority without verification.
- `source=FIXTURE` explicitly marks invented test data and is the only type exempt from normal one-hour observation staleness; actual live/manual/contract quotes older than an hour are ineligible. All quotes expire at `expiry`.

`jobs.tsv` has the header in `fixtures/jobs.tsv`:

`id, region, mem, cpu, gpu, hours, spot, fabric_mode, nodes, deadline, budget, data, baseline, jurisdiction, runtime, delay, earliest`.

- `fabric_mode=SEGMENTED` explicitly allows segmented memory fabric. `CONTIGUOUS` forbids split memory. `nodes=1` or `2` currently. Compute requirements must be satisfiable on the primary node: **we do not add virtual CPUs across nodes**.
- `spot=0` forbids Spot; `deadline` is an absolute latest **completion** epoch (0 = no deadline); `earliest` is earliest permitted start epoch (0 = now); `delay` is maximum permissible delay in seconds, used for forecast hold.
- `budget` is a per-job paper USD upper cap (0 = unlimited). Optional `state/budget.usd` sets a **portfolio** paper budget (0 = unlimited). The paper budget never authorizes real spend.
- `baseline` is the user-declared eligible single-node, on-demand unmanaged offer ID. Empty baseline means cheapest eligible single-node on-demand quote. Missing or ineligible baseline is marked `NA`, never silently fabricated. Comparing a different workload configuration or missing baseline is not treated as savings.
- `data` is estimated egress GiB; charges include quote-supplied network and fabric overhead as well as an explicit risk provision. Other unknown charges must be included upstream before asserting `approved=1`.

## Output, finance and decision evidence

`decisions.tsv`: immutable paper commitments with job, offer identities, quoted cost, baseline, saved dollars, source, reason, forecast confidence, forecasting projection, paper mode, and scheduled start/end epochs. An accepted paper decision for the same job ID is never bought again.

`accounts.tsv`: **two-sided PAPER accounts**, one `PAPER_EXPENSE` positive posting and equal `PAPER_COMMITMENT` negative posting per job. Neither is a real invoice or card charge; replay reconciles missing postings using the unique job/account keys.

`events.tsv`: bounded-rate audit of holds and unplaced work with reason and next-check epoch. `providers.tsv`: per-provider observation status with diagnostic. `history.tsv`: bounded observed price history. `report` prints per-job managed and unmanaged totals, comparable-job savings, savings percentage and unmatched-baseline diagnostics.

`cloud-cost audit` checks every ledger posting against its immutable decision
receipt, including duplicate/orphan postings, selected quote identities, amount
mismatches and balance. A tick first repairs missing halves, audits, and refuses
new commitments if corruption persists. All state writers take a local
`flock` lock; deployment across multiple machines must instead acquire
RTO2/Queue Fabric active-writer authority.

The historical forecast is explicitly versioned as `ewma_slope_v1`: four past price samples, recency-weighted level, bounded slope estimate, simple volatility-derived confidence; it holds only with confidence >=0.7, projected saving >5%, permitted delay and enough slack before completion deadline. It is an **initial statistical predictor**, not a trained production ML model or a guaranteed future discount. Replace it with the estate ooRexx ML provider while keeping the same `estimate(...)` interface and verifying it on real price time series. Future timestamps are excluded to prevent look-ahead leakage.

### Formula and meaning (legacy dev3 estimate only)

When `ingest-economics` has activated a complete economics snapshot, the
whole-job engine replaces these rough formulas. Its breakdown and calculation
assumptions are specified in `docs/WHOLE_JOB_ECONOMICS_DEV4.md`.

For a single provider:

`cost = hourly_rate × hours + startup_fee + data_gib × network_rate + interruption_risk_fraction × hourly_rate × hours`

For a two-provider memory plan, both instance tariffs/start/risk rates are included; external data egress is charged once at the compute owner, and both fabric overhead allowances are charged. This is **conservative about declaring feasibility, not necessarily conservative about price**: if Memory Fabric traffic or network charges are unknown, the upstream adapter must refuse approval rather than assume zero.

`comparable_savings = sum(unmanaged single-node baseline cost) - sum(managed cost for the same comparable jobs)`.

## Tests

Qualification executed on ooRexx 5.3.0 r13196 (the supplied Linux debug package):

```sh
export REXX_BIN=/path/to/rexx
export GENERALIZED_INTENTIONS_ROOT=/path/to/oorexx_generalized_compute_intentions_v0.1-dev3
export INSTRUMENTATION_MESH_ROOT=/path/to/oorexx_instrumentation_mesh_v0.1-dev3
./tests/run.sh
```

Coverage: semantic and legal hard gates, split vs contiguous memory, spot policy, certified fabric locality, cost and unmanaged baseline, expiry, future-data exclusion, deadline/earliest scheduling, Generalized Compute Intentions veto, budget, idempotent commitments, interrupted double-entry reconciliation, capacity-slot non-reuse while active, provider-source schema statuses, mocked read-only Azure API parsing, and optional Instrumentation Mesh adapter. Also cross-check the upstream `oorexx_memory_fabric_v0.1-dev7/tests/test_memory_capacity_plan.rex` against the real runtime.

## Operational limitations / next stages

This is a **working paper-advisory daemon**, not an already-deployed multinational purchase agent. Before live transactions are even designed: complete provider-specific collectors, authenticated account-level costs and quota evidence, real object capability catalogues, official Memory Fabric capacity attestations (including transport/latency), full price components and currencies, forecast backtesting/ML calibration, durable ledger integrity and concurrency locking across multiple daemon instances, cancellations and releases, telemetry publisher transport, real-time allocator lease integration, per-account budget governance, and a separate explicit two-phase purchase-authorisation service. No conversion from `PAPER_ONLY` to live is possible by changing a single environment variable.

## Dev6: native estate evidence for migration advice

`src/CloudMigrationEstateBridge.cls` provides an object-level read-only
interface to actual allocator lease, lifecycle, JNA destination and Memory
Fabric execution-context evidence. `tests/test_migration_estate.rex` exercises
this bridge. **CLI mobility TSV advice is still unverified and is not upgraded
by installing dev6.** See `docs/NATIVE_MIGRATION_AUTHORITY_DEV6.md`.

## dev8: live status observation boundary

See `docs/LIVE_MIGRATION_STATUS_DEV8.md`. `status-*` commands observe
Migratable Job status only; they do not authorize or execute moves.
