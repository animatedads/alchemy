# QueueRexx v0.1-dev12 validation

## Runtime

Open Object Rexx 5.3.0 r13196, user-supplied internal/debug build.

## Baselines

```text
QueueBash 0.18.144
Migratable Job v0.2.4 / migratable.job/0.2 + migratable.job.start/1 + migratable.job.placement/1
Work Load Units v0.12 / work.load.units/0.12
Job-to-Node Allocator v0.6 / job.node.allocator/0.6
Observation v0.5
Crypto v0.8.3 + Runtime Reference v0.4 + Foreign Runtime v0.22.6
```

## Dev12 authority and peer-mesh qualification

New dev12 qualification includes:

```text
test_job_node_authority_service.rex
  PASS: Queue Fabric request/reply; PLAN advisory; exact JTN v0.6
        ALLOCATE/CHECK/RENEW/RELEASE; owner ACL; durable replay/conflict;
        allocator+ledger restart; corrupt ledger fail-closed.

test_job_node_authority_socket.sh
  PASS: separate-process encrypted queue.transport/2 client Queue Fabric ->
        QueueRexx JTN authority -> client Queue Fabric.

test_job_node_network_client_socket.sh
  PASS: synchronous JobNodeNetworkAllocatorClient encrypted ALLOCATE.

test_migratable_job_network_authority.rex
  PASS: Migratable Job v0.2.4 remote PLAN/ALLOCATE/CHECK/RENEW/RELEASE,
        durable NEW intent, exact lease verification twice, standard starter,
        private worker exactly once, starter replay.

test_peer_mesh.rex
  PASS: three independent Queue Fabric managers A/B/C; A-B, A-C and B-C
        direct links; fixed quorum, REQUIRED and deny-veto; B loss degrades
        only decisions needing B; real QueueRexx JOB_CHECK; real JTN
        LOAD_CHECK; durable replay/conflict; direct B->C path; policy-bound
        authorization ID replay; changed quorum under the same authorization
        ID rejected by both peers.

test_peer_mesh_socket.sh
  PASS: separate-process authenticated/encrypted queue.transport/2
        QueueRexx A -> QueueRexx B AUTHORIZE request/reply with explicit
        manager/principal/key/source-IP trust and server-owned reply routing.

test_authority_peer_mesh_composition.rex
  PASS: QueueRexxAuthorityStack and peer mesh share one Queue Fabric manager;
        standard JOB_CHECK/POLICY_CHECK/LOAD_CHECK adapters are installed over
        the exact local authorities; semantic AUTHORIZE remains explicitly
        configured rather than inherited from transport trust.
```

The socket mesh qualification uses the supplied Crypto Foreign Runtime/OpenSSL bridge. The pure-Rexx crypto path remains functionally available but is not used as a timing substitute for the accelerated production transport proof.

The mesh has no availability-derived quorum shrink. A fixed 2-of-N remains 2-of-N when a node is down. Only a policy explicitly configured with a lower threshold may continue. A `REQUIRED` peer outage fails that decision but does not globally disable other mesh operations.


## QueueRexx regression suite

The dev1-dev6 compatibility suite remains mandatory: non-evaluating QueueBash record parsing, providers, `.JSON`/`.CSVStream`/`.Yaml`, health, locks, exclusive allocation, transitions, crash recovery, root ownership, diagnosis, typed operations, exact mixed QueueBash races, Observation, migration authority/status and accelerated SHA evidence.

Dev7 first-class WLU/status projection remains mandatory. Dev8 additionally proves WLU-aware scheduling and recovery-safe typed direct/systemd execution. Dev9 proves provider-aware runtime projection and restart reconciliation. Dev10 adds standardized provider telemetry, durable trigger replay, bounded fleet recovery, QueueBash-to-WLU staging and the Migratable Job v0.2.3 starter guard. Dev11 adds the exact QueueBash execution-policy provider/read-only policy inspection, replaces placement-token matching with authoritative Job-to-Node v0.6 current-lease verification, and binds Migratable Job v0.2.4 managed placement with durable NEW-start intent plus final under-QID launch revalidation.

The acceptance harness used here has a bounded command-execution window, while the complete `tests/run.sh` inventory can exceed that wall-clock limit because several real QueueBash mixed-engine cases deliberately hold locks for seconds. Final acceptance therefore executes the exact `run.sh` inventory in bounded groups (core/WLU authority, mixed QueueBash, migration/status, and crypto) rather than interpreting an outer harness timeout as a product failure. Every individual test remains independently timeout-bounded and must pass.


## Dev9 runtime monitoring/recovery qualification

`test_runtime_monitor.rex` proves:

```text
PASS live direct execution projects IN_SYNC from queue+journal+provider evidence
PASS bounded runtime scan includes active executions without mutating them
PASS durable exit locator projects EXIT_PENDING with RECONCILE recommendation
PASS internal recovery delegates to QueueExecutionService and commits done from durable exit evidence
PASS terminal QueueBash record projects QUEUE_TERMINAL and is never reopened
PASS launch-before-metadata failure projects METADATA_MISSING only when exactly one durable PREPARED intent exists
PASS metadata is reconstructed without relaunch and subsequent exit is reconciled normally
```

Public `runtime-status` and `runtime-scan` are read-only.  `QueueRuntimeRecoveryManager` remains an internal/API surface; there is no public runtime-recovery command.

## Dev11 QueueBash execution-policy qualification

`test_queuebash_policy_provider.sh` and `test_policy_provider_fail_closed.rex` prove:

```text
PASS exact QueueBash 0.18.144 creates the authoritative job records
PASS a blocked command is denied before command-bound authorisation exists
PASS QueueBash-generated on-file command-bound authorisation is honoured
PASS an unrelated unblocked command is allowed
PASS policy-check uses QueueBash worker policy semantics without mutating the authoritative job record
PASS worker admission consumes the same provider verdict
PASS policy provider itself never moves queue state
PASS QueueTransitionService commits denied running -> pol_blocked
PASS QueueBash sees allowed/authorised records as running and denied record as pol_blocked
PASS duplicate QID authority fails closed before policy-provider execution
PASS missing QueueBash source fails closed
PASS QueueBash compatibility-version mismatch fails closed
```

The provider is deliberately an execution-policy binding only. Typed QueueRexx submission remains deny-by-default because the current request object does not yet carry QueueBash's complete submit-time security-policy contract.


## Dev11 Job-to-Node placement-authority qualification

`test_job_node_placement_verification.rex` and the updated `test_wlu_scheduling_execution.rex` prove:

```text
PASS WLU placement lease is minted by the real Job-to-Node v0.6 allocator
PASS the real WLU reservation is retained in JobNodePlacementLease.reservationRef
PASS positive ownership epoch is allocated by Job-to-Node ownership authority
PASS exact original JobPlacementRequest is required for lease verification
PASS changed request/owner evidence invalidates the lease digest/binding
PASS current admission evidence is required for reservation-bearing leases
PASS capacity observation generation drift invalidates an old lease
PASS lease/capacity expiry fails closed
PASS node revocation fails closed
PASS QueueRexx scheduling calls Job-to-Node verifyLease() instead of trusting copied lease fields
PASS verified ownership epoch and placement evidence are projected into the scheduling verdict
PASS ordinary queue priority still orders jobs only after WLU/placement eligibility
```

A matching `reservationRef` is therefore only one binding invariant. It is not a substitute for placement authority. Job-to-Node remains authoritative for eligibility, capability/capacity evidence, policy generation, ownership fencing and lease freshness.

`QueueMemoryPlacementLeaseLookup` remains an in-process test/qualification helper for generic non-migratable WLU scheduling. Migratable NEW execution no longer depends on that lookup: v0.2.4 derives the native placement request from the application definition, and QueueRexx performs final placement revalidation in the placed-start executor. Public generic remote/fleet execution remains disabled.

## Dev10 provider telemetry / trigger / fleet qualification

The dev10 tests prove:

```text
PASS standardized provider health telemetry
PASS read-only provider-health CLI output
PASS provider telemetry -> Observation v0.5 projection without authority transfer
PASS durable idempotent trigger delivery and restart replay
PASS failed/replayed trigger bookkeeping does not directly mutate queue state
PASS bounded fleet recovery follows typed runtime recommendations
PASS reconcile actions delegate to QueueExecutionService
PASS deferred/manual-review evidence remains non-destructive
```

## Dev10 QueueBash-to-WLU bridge qualification

The bridge qualification proves a QueueBash-compatible record can be staged into the existing WLU v0.12 / Job-to-Node v0.6 authority model while preserving the shared QID and ordinary QueueBash record compatibility. It does not create a second queue format or bypass WLU reservation/placement admission.

```text
PASS QueueBash-to-QueueRexx WLU staging bridge
PASS exact WLU v0.12 reservation ceilings and WLU/s authority retained
PASS exact Job-to-Node v0.6 placement/reservationRef binding retained
PASS lifecycle recovery and WLU-first scheduling regressions retained
```

## Migratable Job standard starter qualification

QueueRexx binds the unchanged main `migratable.job/0.2` API plus standard `migratable.job.start/1`. `test_migratable_job_starter_guard.rex` proves:

```text
PASS NEW executes only while the normal shared QID lock is held
PASS exactly one authoritative running QueueBash/QueueRexx record is required
PASS same-startId durable replay is answered by Migratable Job without a second workload launch
PASS terminal QueueBash authority blocks a different NEW startId
PASS propagated workload conditions release the QID lock
PASS QueueRexx does not take ownership of starter receipts, RECOVER or HANDOFF
```

## Dev11 Migratable Job v0.2.4 managed-placement qualification

`test_migratable_job_managed_placement.rex` proves:

```text
PASS v0.2.4 PLAN/CHECK/ALLOCATE/START/ALLOCATE_START/RELEASE are upstream authority
PASS QueueRexx persists the exact NEW-start intent before authoritative allocation
PASS a fresh intent-store instance reconstructs the canonical start request after restart
PASS same verified allocation replays as PLACED_REPLAY with identical placement/ownership epoch
PASS changed startId for the same QID is rejected as durable-intent mismatch
PASS placed start holds the shared QID lock and requires authoritative running queue state
PASS QueueRexx re-runs Job-to-Node verifyLease() immediately before starter entry
PASS injected capacity-generation change after the outer v0.2.4 check is rejected before runtime launch
PASS failed/ambiguous launch leaves placement held rather than silently releasing it
PASS explicit RELEASE remains framework/Job-to-Node authority
PASS QueueRexx stores no shadow placement lease, ownership epoch or allocator verdict in its start-intent record
PASS optional QueueDurableJobNodeAllocator refuses mutation before Job-to-Node durable restore
PASS full allocator/ownership reconstruction restores exact sequence=1 and ownership epoch=1
PASS restored managed allocation returns PLACED_REPLAY without minting a second ownership epoch
PASS standard starter receipt suppresses duplicate runtime entry after a second full object reconstruction
PASS explicit RELEASE is durably checkpointed and a fourth restore does not resurrect ownership
PASS WLU-backed Job-to-Node durable restore reconstructs the authenticated active reservation proof
PASS restored WLU-backed lease verifies before scheduling/execution and terminal settlement releases WLU capacity
PASS explicit terminal placement release survives another Job-to-Node restart
PASS corrupt committed Job-to-Node durable state fails closed; adapter remains not-ready and refuses new placement mutation
```

The durable QueueRexx object is an invocation intent, not placement authority. The application definition supplies the exact `JobPlacementRequest`; Job-to-Node verifies the lease; Migratable Job owns placement audit/replay and standard start receipts.

## Dev8 typed execution qualification

The internal/API execution surface is qualified without enabling public mutation commands:

```text
PASS real direct provider start in separate process group
PASS durable PID/PGID locator and atomic exit-code locator
PASS QueueBash-compatible runtime metadata preserves unknown/original fields
PASS exit 0 reconciles running -> done
PASS non-zero exit reconciles running -> failed
PASS direct typed cancel terminates provider target before cancelled commit
PASS zombie-only PID/process-group membership is not reported LIVE
PASS crash after provider launch but before runtime metadata is reconstructed from PREPARED + PID locator without relaunch
PASS deterministic systemd selection and unit metadata with injected platform facts
PASS SYSTEMD_UNIT/MainPID observation remains authoritative
PASS systemd terminate delegation is qualified
PASS stop acknowledgement with still-LIVE observation does not commit cancelled
PASS real QueueBash 0.18.144 cancels a QueueRexx-started direct payload
PASS QueueRexx reconcile preserves that external QueueBash terminal authority
```

Direct background launch uses a dedicated no-capture system executor. This avoids coupling a deliberately long-lived background payload to ooRexx `ADDRESS SYSTEM WITH OUTPUT/ERROR` pipe lifetime; PID/PGID is instead returned through the durable locator file.

## Dev8 WLU-aware scheduling qualification

`test_wlu_scheduling_execution.rex` uses the exact WLU v0.12 and Job-to-Node v0.6 objects and proves:

```text
PASS managed WLU job is ineligible before reservation + placement
PASS ordinary eligible work may run while managed capacity authority is absent
PASS full WLU ceiling and WLU/s reservation gates eligibility
PASS matching reservationRef plus authoritative Job-to-Node v0.6 verifyLease() gates eligibility
PASS WLU is not priority currency: ordinary queue priority orders eligible jobs
PASS QueueTypedWorker activates the WLU job under normal QID authority
PASS direct provider executes the admitted job
PASS durable terminal evidence drives done and WLU settlement/release
PASS the remaining ordinary job becomes next candidate afterwards
```

## WLU declaration and QueueBash fence

```text
PASS managed QueueRexx record carries expected/ceiling/target/WLU-s demand
PASS managed job stages in QueueBash waiting with QUEUEREXX_WLU_HOLD
PASS original requested class is preserved separately
PASS real QueueBash 0.18.144 reevaluation/sentinel cannot promote the WLU hold
PASS QueueBash can still inspect/source the shared job record
```

The hold-class test matters because `waiting` alone is not an execution fence: QueueBash may reevaluate waiting jobs.

## Exact WLU Authority + Job-to-Node integration

The exact supplied WLU v0.12 and Job-to-Node v0.6 classes prove:

```text
expected work        = 2,000,000 micro-WLU
reserved ceiling     = 3,000,000 micro-WLU
requested throughput =   500,000 micro-WLU/s
```

Qualification asserts:

```text
PASS full ceiling is reserved rather than collapsed to expected work
PASS WLU/s capacity is independently reserved
PASS real reservationRef is bound into JobNodePlacementLease
PASS QueueRexx projection reads WLU authority without becoming authority
PASS understated/mutated placement demand is rejected with no authority side effect
PASS explicit release returns work reservation and WLU/s capacity
```

## WLU lifecycle / crash recovery

`test_wlu_lifecycle.rex` proves:

```text
PASS reservation binding is persisted before executable activation
PASS matching ACTIVE reservation + placement lease gates waiting -> running
PASS actual usage is recorded only while queue authority is running
PASS completion settles declared actual WLU and releases unused work/WLU-s
PASS cancellation preserves consumed WLU and releases unused work/WLU-s
PASS terminal intent is durable before queue terminal commit
PASS queue-committed/WLU-unclosed crash window is recoverable
PASS recovery is idempotent and does not double-settle
PASS externally committed terminal queue state remains authoritative
PASS ambiguous/conflicting queue evidence does not trigger destructive accounting guesses
PASS injected WLU consume condition releases the QID lock before propagation
PASS injected post-queue-commit WLU settlement condition releases the QID lock
PASS post-queue-commit injected failure is completed by lifecycle recovery without changing terminal queue authority
```

WLU reserve/release, activation, metering, terminal and recovery paths participate in the ordinary per-QID state-lock discipline. Their condition handlers release the lock before propagating an ooRexx syntax condition.

## Real QueueBash cancellation + WLU recovery

A real QueueBash 0.18.144 `queue cancel --force QID` is invoked against a QueueRexx/WLU-admitted running record while the WLU Authority remains live in the ooRexx process.

Qualification proves:

```text
PASS QueueBash commits the shared cancelled state
PASS WLU Authority remains active until accounting recovery runs
PASS QueueRexx recovery never moves/reopens the cancelled queue record
PASS measured consumed WLU remains spent
PASS unused WLU reservation is released
PASS WLU/s capacity is released
```

## Status projection

`QueueJobStatusProjector` combines, but does not collapse, durable migration authority, retained Queue Fabric status and optional WLU projection.

The exact Migratable Job v0.2.4 classes prove classification of:

```text
durable_only
live_only
in_sync
live_ahead
durable_ahead
migration_id_mismatch
state_conflict
```

The serialized durable side is explicitly authoritative; retained topic and WLU projection are read models only.

## QueueBash 0.18.144 qualification

The exact supplied hotfix tests:

```text
tests/lock_tree_owner_repair_static.sh
tests/lock_tree_owner_repair_smoke.sh
```

return success.

QueueRexx mixed-engine tests additionally prove both lock-ownership orders, both claim-race winning orders, exact record/JSON parity, QueueBash execution of a QueueRexx-submitted `/bin/true`, QueueRexx admission of a QueueBash-submitted job, WLU hold fencing, and real QueueBash cancellation/WLU accounting recovery.

## Foreign Runtime SHA-256 qualification

QueueRexx hashes through ordinary `.SHA256` and requires Runtime Reference evidence:

```text
outcomeCode = COMPLETED
providerId  = foreign.openssl.crypto
```

Pure ooRexx SHA-256 is separately tested as fallback; it is not the preferred high-throughput path.

## Upstream WLU v0.12 qualification used by dev8

The following supplied upstream tests are rerun under the same ooRexx runtime and pass:

```text
test_authority.rex
test_fast_mac.rex
test_hierarchical_job_budget.rex
test_job_budget_escalation.rex
test_enterprise_acceleration.rex
test_units_ratecard.rex
```

The complete WLU upstream suite is **not** claimed as completed in this release. Its authenticated-ledger path enters a slow pure-ooRexx Ed25519 qualification and exceeded the bounded qualification window in this environment. That is reported as an incomplete full-suite run, not as a pass or failure of the tested WLU authority semantics.

## Migratable Job v0.2.4 qualification

The exact migration binding, retained `migratable.job.status/1` subscriber, late-subscriber replay, monotonic sequence filtering, migration-aware liveness deferral and Foreign Runtime digest evidence remain mandatory. QueueRexx never treats topic delivery as mutation authority.

## Static audits

Executable QueueRexx source is checked for:

- no accidental working variable named `RESULT`;
- JSON through `.JSON`, CSV/TSV through `.CSVStream`, YAML through `.Yaml`;
- no shell `sha256sum` runtime dependency in QueueRexx source;
- class-owned constants at queue/WLU/migration/provider/event/schema boundaries;
- no `awk` dependency for QueueRexx process-start-cookie parsing.

## Safety boundary

The public CLI still has no `submit`, `run`, `cancel`, `migrate`, or `daemon` command in dev12. QueueRexx now has an executable internal/API payload-launch and scheduler surface, but public worker/daemon mutation remains disabled. WLU reservation/activation/usage/terminal/recovery and typed execution remain qualified internal/API surfaces.

## Full upstream Migratable Job v0.2.4 rerun

The supplied `run_tests.sh` is rerun unchanged with its exact Job-to-Node, Crypto, Runtime Reference, Foreign Runtime, Storage Fabric, Queue Fabric, Alchemy, Runtime Registry and Access Permissions dependencies. It passes:

```text
Foreign Runtime/OpenSSL JobNode/Migratable Job SHA-256 evidence
planned migration/fencing/re-placement/provenance
durable restart and intrinsic journaling
authority reconciliation after journal crash window
hardening and fail-closed paths
file handoff and destination acknowledgement
standard starter NEW crash-after-CLAIMED retry + durable RUNNING replay
standard starter conflicting startId rejection
standard starter RECOVER and HANDOFF flows
destination bridge through standard starter
start-receipt integrity fail-closed and safe durable layout
managed placement PLAN/CHECK/ALLOCATE/START/ALLOCATE_START/RELEASE
managed placement PLACED_REPLAY, audit receipts and START_FAILED_PLACEMENT_HELD
managed-placement failure/release semantics
Storage Fabric resumable checkpoint transfer + verified resume
Queue Fabric bound resume dispatch
QueueChannelFabric store-and-forward remote handoff
retained status-topic fan-out / late subscriber semantics
```

The Queue Fabric tests are deterministic in-process/store-and-forward qualification; they are not presented as live Internet/socket transport qualification.

## Final dev11 bounded qualification

The sealed-candidate inventory is rerun in bounded groups under the supplied ooRexx 5.3.0 r13196 runtime so outer harness wall-clock limits are not confused with product failures. Final groups pass for:

```text
pure QueueRexx mutation/recovery/execution/runtime/telemetry/trigger/fleet kernel
WLU v0.12 + Job-to-Node v0.6 integration, lifecycle, durable scheduling and lease verification
QueueBash 0.18.144 mixed locks/claim races/record parity/execution/admission/WLU fence/adoption/policy/cancel
Migratable Job v0.2.4 load, QID guard, managed placement and durable placement restart
retained migration status projection + Observation v0.5
pure ooRexx SHA fallback + Foreign Runtime/OpenSSL SHA evidence
exact QueueBash 0.18.144 lock-tree owner static/smoke hotfix tests
```

## Deliberate dev11 scope boundary

The exact QueueBash worker path performs class/resource availability before execution policy. Dev11 qualifies the execution-policy boundary only. It does not claim that a successful policy assessment proves class/resource admission, and public mutation remains disabled.

## Dev12 peer-mesh + exact network1 authority qualification

Focused authority qualification passes on ooRexx 5.3.0 r13196 with Queue Fabric v0.9-dev5, exact `job_node_allocator_v0.6-network1`, Job-to-Node v0.6, WLU v0.12 and Migratable Job v0.2.4:

- `test_peer_mesh.rex` — three-node A/B/C non-hub topology; fixed quorum, required-peer/veto behavior, degraded-peer operation, real JOB/POLICY/LOAD checks, durable replay/conflict and direct B->C traffic.
- `test_authority_peer_mesh_composition.rex` — authority server and general peer mesh share one Queue Fabric manager while transport trust remains distinct from semantic approval.
- `test_network1_mesh_composition.rex` — QueueRexx hosts the exact upstream network1 service/ledger/access policy over the general mesh; request replay/conflict and real allocator delegation; no second placement protocol.
- `test_authority_client_config.rex` — combined bootstrap configuration reconstructs QueueRexx peer binding plus exact upstream network ACL/reply binding and fails closed on malformed input.
- `test_authority_mesh_config.rex` — preferred split configuration: `queuerexx.peer.mesh.config/1` owns host/port/trust/key configuration and `queuerexx.job-node.authority-peer-clients/1` owns only client->peer operations/owner/reply semantics; ordering and missing-local-node failures are fail closed.
- `test_authority_server_recovery.rex` — Job-to-Node restore precedes network mutation, durable requests accepted before process loss drain before listen, exact response replay prevents duplicate allocation, and offline reply delivery remains durable backlog rather than authority rollback.
- `test_authority_server_wlu_restart.rex` — exact network1 ALLOCATE creates the WLU reservation; after allocator/ownership reconstruction Job-to-Node durable state restores authenticated admission evidence, the reservation remains ACTIVE and exact network CHECK verifies the reconstructed lease.
- `test_peer_mesh_socket.sh` — encrypted separate-process QueueRexx peer request/reply over exact Queue Fabric `queue.transport/2`.
- `test_network1_over_peer_mesh_socket.sh` — one authenticated encrypted peer relationship carries ordinary mesh HEALTH plus exact upstream `JobNodeNetworkAllocatorClient` ALLOCATE/CHECK/RELEASE.
- `test_migratable_job_network_authority.sh` — full remote Migratable Job v0.2.4 PLAN/ALLOCATE/CHECK/RENEW/START/replayed-START/RELEASE; exact network client, framework lease verification, second remote CHECK under QueueRexx QID lock, `migratable.job.start/1`, no local allocator fallback and private worker entered exactly once.

The unchanged upstream `job_node_allocator_v0.6-network1/run_network_tests.sh` also passes its in-process request/reply/replay/owner-authorization qualification, durable request-ledger restart replay, and encrypted two-process Queue Fabric socket qualification.

### Test-process isolation note

Prior apparent socket hangs were traced to Crypto v0.8.3 falling back to slow pure-ooRexx HMAC/ChaCha because `QF_CRYPTO_FOREIGN_BRIDGE` pointed at the native library rather than the Foreign Runtime bridge JSON. The qualified encrypted path uses the supplied OpenSSL bridge JSON; pure ooRexx SHA/crypto fallback remains independently tested rather than silently treated as a transport failure. Long release runs are therefore split into bounded groups so an outer harness timeout is not reported as a product assertion failure.

## Dev12 final release qualification

The repaired dev12 tree was requalified after replacing the provisional QueueRexx-specific Job-to-Node wire implementation with composition around the exact `job_node_allocator_v0.6-network1` package.  Release qualification was intentionally split into bounded groups so an outer harness timeout could not be mistaken for a product failure.

Final green groups include:

- all pure QueueRexx kernel/mutation/recovery/execution/provider/trigger/fleet tests;
- exact WLU v0.12 + Job-to-Node v0.6 admission, lifecycle, scheduling and lease-verification tests;
- QueueBash 0.18.144 mixed-engine lock/race, record, execution, admission, cancellation, WLU and policy-provider tests;
- Observation v0.5 bridge and provider telemetry projection;
- exact network1 peer-mesh composition, split peer/service configuration, authority restart/replay, WLU-backed restart and encrypted two-process mesh transport;
- full remote Migratable Job v0.2.4 PLAN/ALLOCATE/CHECK/RENEW/START/replayed-START/RELEASE with final remote lease recheck under the QueueRexx QID lock;
- Migratable Job v0.2.4 local managed-placement/restart/status projection regressions;
- pure ooRexx SHA fallback plus Foreign Runtime/OpenSSL accelerated QueueRexx and upstream Migratable Job digest paths;
- unchanged upstream network1 in-process replay/owner authorization, durable request-ledger restart and encrypted two-process socket qualification.

A source-wide `rexxc` pass compiled all 29 QueueRexx `.cls` packages successfully.  Static release audit found no development backup/temp files and no accidental working-variable assignment named `RESULT`.
