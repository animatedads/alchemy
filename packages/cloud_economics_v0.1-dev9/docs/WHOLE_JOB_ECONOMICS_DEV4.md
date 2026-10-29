# Whole-job economic decisions — 0.1-dev4

**Contract:** `cloud.economics/0.1`, extension model `whole_job_v1`. **Authority:** advisory, `PAPER_ONLY` always. This work adds price *reasoning*, not a new compute allocator or live purchasing capability.

## Enable a complete economic snapshot

```sh
export CLOUD_ECONOMICS_STATE="$HOME/cloud-economics-state"
export REXX_BIN=rexx
./tools/cloud-cost ingest fixtures/offers.tsv
./tools/cloud-cost submit fixtures/jobs.tsv
./tools/cloud-cost ingest-economics fixtures/economic_terms.tsv fixtures/workload_economics.tsv
./tools/cloud-cost preview
./tools/cloud-cost tick
./tools/cloud-cost report
./tools/cloud-cost audit
```

The first two fixture files are **illustrative**; their prices, tariffs, topology, and future times are not actual provider quotes. `preview` does not create decisions or accounts. `tick` writes **paper** commitments. The daemon remains usable with no economics snapshot, retaining dev3 behavior. An installed snapshot explicitly enables the richer model; all submitted jobs without an economic profile are held rather than receiving fabricated zero-price charges.

A snapshot consists of `economics/config.XXXXXXXX/terms.tsv`, `profiles.tsv`, and `provenance.tsv`, referenced by a single atomically replaced `economics/current` symlink. The snapshot records SHA-256 hashes for terms/profiles. CLI locks the update and paper planning cycle together. A failed import leaves the preceding active configuration in place. The controller rechecks both input file hashes before each planning cycle and refuses altered active snapshots. Old snapshots must be retained for audit/replay and protected by ordinary file ownership and backups. Hashes by themselves do **not** authenticate a malicious editor with write access.

## Required unit tariffs

`economic_terms.tsv` has **one** record per eligible offer ID, with fields:

| Field | Units / interpretation |
| --- | --- |
| `id` | Exact offer identity, unique |
| `bill_quantum_s` | Positive integer billing increment in seconds |
| `bill_min_s` | Nonnegative minimum billable seconds |
| `ingress_usd_gib` | USD per GiB of workload input transferred to execution host |
| `egress_usd_gib` | USD per GiB of workload output transferred out |
| `storage_usd_gibh` | USD per GiB-hour for scratch and *one* retained checkpoint |
| `io_usd_gib` | USD per GiB of ordinary I/O plus modelled checkpoint read/write |
| `fabric_transfer_usd_gib` | USD per GiB of memory-fabric traffic at **this** leg |

The existing `offers.tsv` still supplies hourly VM price, startup charge, quoted source/expiry, authority, legal/runtime eligibility and fixed fabric overhead. In the new model, the old aggregate `network × data` estimate is **replaced** by explicit ingress/egress terms, avoiding double counting. This is a modelled interpretation, not a claim about the billing policies of a named cloud; provider adapters must map their actual billing and free allowances faithfully. No currency conversion occurs: all prices must be USD.

An offer without an exact matching unit-tariff row **cannot** be used by `whole_job_v1`. Missing or malformed terms do not become zero-priced capacity. Observed-only AWS/Azure/GCP public prices still fail the existing `approved=1` and `capacity=1` gates. A real authority-aware integration must use `CloudEconomicAuthorityPlanner` from dev2 and its genuine upstream provider/allocator/Memory Fabric evidence before relying on a paper comparison.

## Required workload economics

`workload_economics.tsv` has one row per submitted job identity and these fields:

| Field | Units / meaning |
| --- | --- |
| `input_gib`, `output_gib` | External ingress/egress volume, GiB |
| `scratch_gib` | Scratch resource size retained for job duration, GiB |
| `io_gib` | Modelled application read/write volume, GiB |
| `checkpoint_gib` | Serialized durable state size per checkpoint, GiB |
| `checkpoint_interval_s` | Seconds of useful work between checkpoints; 0 means none |
| `checkpoint_cpu_s` | Execution CPU-seconds of overhead for each scheduled checkpoint |
| `restore_s` | Seconds to reload state after an interruption |
| `max_recovery_s` | Model admission limit on expected recovery duration for one interruption; 0 removes this bound |
| `fabric_gib_hour` | Data moved across qualified memory-fabric interfaces per job-hour |
| `spot_recovery` | `CHECKPOINT`, `FULL_RESTART`, or `FORBID` for Spot capacity |

The predictor's risk term is interpreted as an *expected interruption count per runtime-hour* and is a scenario assumption, not an empirically verified probability or interruption guarantee. Recovered work is approximated as half the checkpoint interval (bounded by job length) plus restore time. Full restart estimates half the run length plus restore time. Periodic checkpoints write/restore I/O and require extra CPU; the model bills for these additional seconds, with provider-specific rounding, then adds data movement and storage costs. In a two-leg segmented-memory scheme, the primary owns the CPU, and the secondary charges its own instance minimum/quantum, fixed fabric allowance and both ends of memory-fabric traffic. **Segmented logical memory is not equivalent to a conventional shared 64 GiB address space.**

The measured schedule time in a paper decision includes modelled extra recovery. It is an expectation, **not an operational SLA**. A deadline with high confidence, probabilistic risk or strict worst-case requirements still needs a separate reliability/admission assessment; this model should not be used to certify that deadline. Workload introspection must provide the estimated volumes, checkpoint semantics and data locality. Inventing an empty input or zero egress is prohibited by policy when the job really consumes those resources.

## Paper decision / unmanaged savings

The planner selects the cheapest current, legally and technically eligible candidate that fits job-level budget and modelled finish time. A declared single-node, on-demand unmanaged baseline is compared **for the same workload and same complete tariff/profile**. If that unmanaged offer is missing/ineligible, it reports `NA` rather than inventing a saving. Billing quanta can reverse an hourly price ranking; checkpoint/runtime and fabric traffic can similarly reverse a split-memory win.

Committed receipts embed `whole_job_v1;compute=...;startup=...;ingress=...;egress=...;storage=...;io=...;fabric_compute=...;fabric_network=...` plus billable time, expected interruptions and hashes identifying the input snapshot. `cloud-cost audit` checks the eight cost components reconcile to the paper receipt and ledger debit/credit. Long-decimal postings use 20-digit arithmetic; aggregate sums tolerate at most $0.000000000001 of calculation-order rounding **after exact per-job posting checks**. This is not a substitute for signed immutable accounting, bank or cloud invoices.

## Not yet implemented / boundaries

- Cross-node **job migration decisions**, route discovery, checkpoint transport and bandwidth verification are a separate estate-authority integration. This release costs checkpointing and fabric traffic, **not** a completed move between active machines.
- Cloud-specific billing tiers, reservations, savings plans, storage classes, provider discounts, quota availability, taxes, FX, power/carbon tradeoffs and cost reconciliation require explicit provider inputs, never extrapolated from public Spot observations.
- Operating a local continuous watcher does not grant distributed leader election, cloud capacity leases or purchasing authority. Scaling the service across nodes needs Queue Fabric / RTO2 active-writer fencing and the existing allocator's own lease semantics.
- The simple historical trend is unchanged. No trained/backtested ML pricing claim is made; a predictive model may advise a wait but must never authorize purchase.
- There are no live purchases, cloud mutations, job starts, checkpoint or transport side effects in dev4.
