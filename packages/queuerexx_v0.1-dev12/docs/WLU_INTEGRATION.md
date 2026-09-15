# First-class Work Load Units integration

QueueRexx v0.1-dev8 treats Work Load Units (WLU) as a job-lifecycle authority, not as a scheduler score or an optional accounting annotation.

The exact integration target is Work Load Units v0.12 / API `work.load.units/0.12`, composed with Job-to-Node Allocator v0.6.

## 1. Job declaration

A managed QueueRexx job carries immutable work and delivery demand in its shared QueueBash-compatible record:

```text
WLU_MODE=managed
WLU_API_VERSION=work.load.units/0.12
WLU_IDENTITY=<authority identity>
WLU_SCOPE=<authority scope>
WLU_EXPECTED_MICRO_WLU=<forecast work>
WLU_CEILING_MICRO_WLU=<maximum reserved work>
WLU_TARGET_SECONDS=<target delivery duration>
WLU_REQUESTED_RATE_MICRO_WLU_PER_SECOND=<delivery capacity>
```

Internally this is `.QueueWLURequirement`, using class-owned numeric mode constants. One WLU is 1,000,000 micro-WLU.

`expectedMicroWlu` and `ceilingMicroWlu` are deliberately distinct. QueueRexx reserves the ceiling while retaining the expected amount as the forecast. Delivery demand is separately represented as micro-WLU/second.

## 2. QueueBash-visible execution fence

A plain QueueBash worker cannot enforce WLU admission. Therefore a managed job must not become ordinary executable `pending` work before WLU + placement admission.

QueueRexx initially stages a managed job in QueueBash `waiting` and writes:

```text
JOB_CLASS=QUEUEREXX_WLU_HOLD
WLU_ORIGINAL_JOB_CLASS=<requested class>
```

QueueRexx creates the corresponding QueueBash class preflight under the shared queue root. The preflight deliberately fails, making the hold visible to QueueBash itself.

This class fence is required because `waiting` alone is not authority: QueueBash sentinel/reevaluation may otherwise promote a waiting job. The original class remains durable and QueueRexx exposes it as the effective class internally.

QueueBash may still inspect, explain, diagnose, or cancel the same job record. It simply cannot unknowingly execute a WLU-managed job before WLU admission.

## 3. Authority composition

The authority split is:

```text
QueueRexx / QueueBash filesystem
    owns QID + queue state

WLU Authority
    owns work entitlement, throughput reservation, consumption and settlement

Job-to-Node Allocator
    owns placement/admission and carries WLU reservationRef

Migratable Job
    owns planned execution-ownership handoff/fencing over the placement authority
```

No layer creates a second authoritative QueueBash job record.

`QueueWLUPlacementRequestAdapter` derives Job-to-Node's expected work and requested rate directly from the shared record. `QueueJobNodeWLUAdmission` rereads the record before reservation and rejects a placement request that understates or changes those values.

QueueRexx deliberately reserves the full `ceilingMicroWlu`; it does not collapse ceiling to expected work.

The resulting real WLU reservation is returned as Job-to-Node `reservationRef`, so placement and planned migration carry existing WLU authority evidence rather than a QueueRexx-specific entitlement token.

## 4. Activation

`QueueWLUActivationService` is an internal/API surface in dev8. Activation requires:

- exactly one durable WLU binding for the QID;
- an ACTIVE reservation at WLU Authority;
- a Job-to-Node placement lease for the same QID;
- the lease `reservationRef` to equal the durable QueueRexx/WLU binding;
- acquisition of the normal QueueBash-compatible per-QID state lock.

Only then may QueueRexx request `waiting -> running` through `QueueTransitionService~transitionWithLock()`.

The activation service does not move files directly.

## 5. Metering

`QueueWLUUsageService` records actual consumption only while the authoritative QueueBash record is `running`.

Usage metering acquires the same per-QID lock used by queue transitions. This prevents a late `consume()` racing after a terminal decision.

The actual WLU Authority remains the accounting authority. QueueRexx stores no competing consumption balance.

## 6. Terminal semantics

Terminal queue state and WLU settlement are separate authorities and cannot honestly be described as one filesystem transaction. QueueRexx therefore uses a recovery-safe WLU lifecycle journal.

Class-owned lifecycle phases are:

```text
RESERVED
ACTIVATED
TERMINAL_PREPARED
QUEUE_COMMITTED
WLU_COMMITTED
RESERVATION_RELEASED
ABORTED
AMBIGUOUS
```

For QueueRexx-owned terminal operations the order is:

```text
acquire normal QID lock
  -> persist TERMINAL_PREPARED + exact reservation proof
  -> commit QueueTransitionService state transition with caller-held lock
  -> persist QUEUE_COMMITTED
  -> close WLU reservation
  -> persist WLU_COMMITTED
release QID lock
```

Terminal mapping is:

```text
complete -> done      -> settle(actual WLU)
fail     -> failed    -> settle(actual WLU)
cancel   -> cancelled -> release unused reservation while preserving consumed WLU
```

The WLU/s throughput reservation is returned when the WLU reservation closes.

All WLU lifecycle methods that hold the QueueBash-compatible QID lock install an ooRexx condition guard. If the WLU authority, journal, transition service or adapter raises a syntax condition, QueueRexx releases the QID lock before propagating the condition. A post-transition settlement exception therefore leaves durable terminal evidence and an unlocked QID for recovery rather than stranding the queue.

## 7. Crash recovery

`QueueWLULifecycleRecovery` reconciles durable QueueRexx WLU evidence against the current authorities. It never guesses a queue transition.

Important cases:

- source queue state still present after a prepared terminal intent: mark the WLU lifecycle attempt ABORTED and leave WLU active;
- expected terminal queue state is authoritative and WLU remains ACTIVE: complete the missing WLU settle/release step;
- duplicate/missing/conflicting queue state: report AMBIGUOUS and do not destructively choose;
- replay after WLU already closed: do not charge/release a second time.

The WLU reservation snapshot stored by the lifecycle journal is the exact Job-to-Node/WLU proof snapshot, not a QueueRexx reimplementation of its authentication format.

## 8. Cross-engine QueueBash terminal authority

QueueBash may cancel a running QueueRexx/WLU job without understanding WLU. That queue-state decision remains authoritative.

If QueueBash moves the shared record to `cancelled` before QueueRexx records a WLU terminal intent, recovery synthesizes only the missing accounting intent:

```text
QueueBash cancelled record remains cancelled
WLU consumed work remains spent
unused WLU reservation is released
WLU/s capacity is released
QueueRexx does not reopen or move the queue record
```

This is qualified using the real QueueBash 0.18.144 `queue cancel --force` command against an in-memory live WLU Authority.

## 9. Migration

Planned migration does not settle WLU merely because execution ownership moves. The same QID remains `running`; Job-to-Node/Migratable Job carry the placement/ownership authority and its WLU `reservationRef` through the handoff.

Future placement replacement or reservation reshaping must be performed through those authorities. Migration status publication remains a non-authoritative read model and cannot create/release WLU by itself.

## 10. Crypto/performance posture

WLU v0.12 uses SipHash-2-4-128 for its high-frequency reservation proofs. QueueRexx does not substitute a home-grown proof format.

For QueueRexx SHA-256 work where throughput matters, the existing Crypto `.SHA256` API is configured to prefer the Foreign Runtime/OpenSSL provider; pure ooRexx SHA-256 remains fallback.

## 11. Dev8 scheduling/execution boundary

WLU reservation, placement binding, activation, usage, terminal settlement/release and recovery remain qualified internal/API surfaces in dev8. Dev8 additionally makes WLU first-class in scheduling and typed execution.

`QueueWLUSchedulingAdmission` requires an ACTIVE durable reservation plus a current Job-to-Node placement lease before a managed job is eligible. Matching `reservationRef` is necessary but insufficient: QueueRexx retains the exact `JobPlacementRequest` and delegates current-lease acceptance to Job-to-Node v0.6 `verifyLease()`, which checks ownership fencing, admission restoration, lease/capacity freshness, capability/observation generations, request/capability/capacity digests and allocator policy generation. WLU does **not** become a hidden priority multiplier: after eligibility, normal QueueBash job priority orders candidates. `QueueTypedWorker` then activates the managed job under the normal QID lock and invokes `QueueExecutionService`. Durable exit evidence drives terminal WLU settlement/release through the existing lifecycle service.

Public QueueRexx `submit`, `run`, `cancel`, `migrate`, and `daemon` commands remain disabled. The executable worker/runner path is still an internal/API qualification surface.


### Dev11 current-placement verification

QueueRexx does not treat a copied placement token as authority. `QueueJobNodePlacementAuthority` is a thin verifier adapter over the supplied Job-to-Node allocator. It does not reproduce allocator rules and it does not create ownership. If the allocator, time authority, exact placement request, or current evidence is unavailable, scheduling fails closed.

The exact placement request matters because Job-to-Node binds its canonical digest into the lease. A lease cannot be safely revalidated after restart by guessing the original request from `reservationRef` or node identity alone.

Dev11 adds optional `QueueDurableJobNodeAllocator`, backed by the exact v0.6 `JobNodeDurablePlacementManager`. It refuses placement mutation until a restore pass has completed, then checkpoints allocation/renew/release so allocator sequence and ownership epochs survive restart. When `QueueJobNodeWLUAdmission` is the admission authority, Job-to-Node also snapshots and reconstructs the authenticated WLU reservation proof and verifies that WLU Authority still reports the reservation ACTIVE before restoring it. Qualification discards and rebuilds the allocator/ownership objects before scheduler admission, verifies the restored lease, executes and settles WLU, explicitly releases placement, and confirms a later restart does not resurrect ownership.

`QueueMemoryPlacementLeaseLookup` still retains request+lease only in-process for the generic non-migratable scheduling demo. The durable allocator solves authority recovery, not request/lease discovery for an arbitrary scheduler process. A future public remote scheduler must persist or deterministically reconstruct that discovery binding and repeat Job-to-Node verification at the final launch boundary. Migratable NEW workloads already obtain deterministic request reconstruction from their workload definition plus QueueRexx durable NEW intent and use v0.2.4 managed placement / placed-start revalidation.
