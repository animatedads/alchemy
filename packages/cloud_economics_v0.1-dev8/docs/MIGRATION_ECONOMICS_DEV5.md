# Cloud Economics dev5 — running-job migration advisory

## Responsibility, not dispatch

`CloudMigrationEconomics.cls` prices continuation of an already-running job on its
source node against one or more **hypothetical** checkpoint/transfer/restore
routes. It does not checkpoint a process, issue a Queue Fabric command, reserve
a node, acquire a Job-to-Node Allocator lease, operate Memory Fabric, transfer
bytes, buy a cloud instance, terminate a source node or post to the accounts
ledger. `PAPER_MOVE_FAVORED` is economic advice, **not** an execution decision.

Before a real migration, the estate must revalidate registered-job state,
current intention and WLU acceptance, checkpoint format and consistency,
Memory Fabric or Cluster Object movement semantics, namespace/data residency,
source/final fencing, destination capacity and placement lease, transfer
availability, deadline and budget, actual cloud account authorization and
post-execution invoice reconciliation. A route `intention_ref` / `route_ref`
in this module is a *reference to evidence*, not verified or signed evidence.
The configured `policy=ELIGIBLE` flag alone confers no authority.

The unchanged existing `CloudEconomicAuthorityPlanner` is the object-rich
admission interface for fresh Generalized Compute Intentions, Job-to-Node
Allocator and Memory Fabric objects. This dev5 running-job feed is not yet
wired to acquire and validate those native estate objects. Build that bridge
before any enabled movement operation is considered.

## Cost comparison

Amounts are incremental USD from the **decision epoch**, so already-spent VM
hours, prior checkpoint charges and other historical sunk costs are excluded.
The caller supplies remaining execution seconds, source prepaid remaining
seconds, residual unavoidable fees and checkpoint/transfer cost evidence.

* Stay: only future billable source compute (minus prepaid remaining seconds),
  future scratch storage, expected interruption-recovery time, and explicit
  unavoidable future commitments. Exact source billing quanta are applied.
* Move: future source compute to produce the checkpoint (net of prepaid
  seconds), future target compute including restore/warmup and expected target
  interruptions, VM startup USD, route source termination USD, one-time
  destination charges, source egress + target ingress + route transfer
  USD/GiB for state and staging bytes, checkpoint/restore I/O USD/GiB,
  destination scratch storage and unavoidable future commitments.
* Transfer seconds = (state GiB + staging GiB) × 8589.934592 / effective
  bandwidth Mbps. The estimate is not a transfer throughput guarantee.
* A move must fit the latest completion deadline and maximum downtime, have
  a matching runtime/memory/CPU/jurisdiction, use a current route and current
  capacity assertions, honor Spot policy, and clear minimum dollar **and**
  percentage savings thresholds. It also respects a minimum residence period
  following the previous move (anti-ping-pong).
* Unmovable jobs stay. If staying misses a hard deadline, a timely move can be
  favored even if it costs more, but its `savings` is then explicitly `NA`.
  If neither plan fits, the status is `PAPER_HOLD`.

### Limitations of estimates

Cost inputs need authoritative construction by their respective providers.
The current calculator assumes a fully serializable checkpoint and one
specified effective-throughput route; it does not model dynamic replicas,
GPU state compatibility, data-dirtying rate, multi-tenant throughput tails,
real provider minimum commitment plans, persistent source volumes, final
fencing/transaction handoff, stochastic tail-risk deadline guarantees or
live memory pages moving transparently. Source `checkpoint_age_s` is captured
but not used in pricing a fresh full checkpoint; it must not be taken as an
incremental-checkpoint size predictor. The interruption model is an expected
value, **not** a validated ML forecast. Unknown values are not grounds to
claim real savings; configure known terms or withhold the route.

The additional example rates in `fixtures/mobility_*.tsv` are **invented**.
They intentionally include two scenarios: a cheaper nominal instance that
loses due to minimum billing quantum, and a genuinely cheaper full migration
under a hypothetical shorter billing quantum. Never label fixture observations
as current provider prices.

## Inputs and watcher

All files use tab-separated UTF-8 without embedded tabs/newlines. Exact headers
are supplied as the first rows of:

* `fixtures/mobility_running.tsv`: one row per running job with original
  source offer ID, remaining time, deadline, state, prepaid compute remaining,
  explicit mobility mechanism, budget, resources, residency, interruption
  preference, cooldown, and financial thresholds.
* `fixtures/mobility_routes.tsv`: one row per possible directed migration,
  referenced job/source/destination and intention/route evidence IDs, current
  status/policy claims, observation and expiration timestamps, route bandwidth,
  checkpoint/restore/warmup timing, staging bytes, fee terms.
* Original `offers.tsv` and active `economics/current/terms.tsv` supply the
  same normalized instance prices and unit-aware price terms as dev4.

For every candidate route, the source and destination must both have
`approved=1`, `capacity=1`, matching `runtime`, and an unexpired quote.
This is *screening input* from the upstream adapter, not verification of a
lease. `PLANNED`/`ELIGIBLE` routes must be observed within the previous
300 seconds. `PAPER_MOVE_FAVORED` does not imply capacity is still there.

```sh
export CLOUD_ECONOMICS_STATE="$HOME/cloud-economics-state"
./tools/cloud-cost ingest fixtures/mobility_offers.tsv
./tools/cloud-cost ingest-economics fixtures/mobility_terms.tsv fixtures/workload_economics.tsv
./tools/cloud-cost ingest-mobility fixtures/mobility_running.tsv fixtures/mobility_routes.tsv
./tools/cloud-cost migration-preview 1791000000  # fixture-time simulation
./tools/cloud-cost migration-preview             # actual wall clock
./tools/cloud-cost migration-tick                # writes latest advisory, no accounts
./tools/cloud-cost opportunities                 # print last advisory
./tools/cloud-cost watch 60                      # includes migration-tick when configured
```

Mobility and cost snapshots are admitted only after native ooRexx schema/value
checks and are atomically switched. A later change to either content file is
detected using SHA-256 before a preview. Every `migration-tick` produces a
fresh `migration_latest.tsv` with evaluation epoch and immutable input
fingerprints. It is a **latest-state advisory**, not a double-entry account
or an immutable commitment. Papers buys remain in the existing
`decisions.tsv`/`accounts.tsv` and are unaffected by read-only migration
analysis. Local `flock` prevents concurrent state updates; multi-host writer
fencing still belongs to RTO2/Queue Fabric, not this local shell script.

For real deployment, continually refresh both the actual registered-job
running-state feed and native route/capacity evidence; imported fixture epoch
numbers are deliberately stale at modern wall-clock times. The `watch` service
never migrates jobs and will not turn a simulated savings result into a buy.

## Intended intention services

A future native `migration.intent/0.1` assessment should preserve original
object references and compose these independent, authoritative questions:

1. Can Registered Job/QueueRexx produce a durable consistent checkpoint at its
   current execution state, and can the target runtime resume it?
2. Can the object/data transport and memory providers transfer the actual
   continuation state within jurisdiction, confidentiality and deadline policy?
3. Does WLU allow temporary duplicate compute/capacity during the handover?
4. Does Job-to-Node Allocator admit *and lease* the destination with a fenced
   source/target hand-off (without double execution)?
5. Does financial authority authorize a real billable cloud action, including
   limits, payment, taxes and cancellability? Who reconciles actual charges?

The economic module should then consume the combined evidence and rank plans,
**never impersonate** any of these five authorities.
