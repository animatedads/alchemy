# QueueRexx provider contracts

## Provider doctrine

A provider supplies a capability; it does not own QueueBash state.

Every provider must publish stable identity/version, capabilities, platform support, job requirement support, denial reasons, safety characteristics, and explain output. Provider selection must be deterministic and observable.

## RunnerProvider

The initial contract is represented in `QueueRexxProviders.cls`:

```text
id
version
capabilities
supports(platformFacts, jobRequirement)
score(platformFacts, jobRequirement)
prepare(job/context)
launch(job/context)
observe(job/context)
terminate(job/context)
explain(platformFacts, jobRequirement)
```

In v0.1-dev8, `prepare`, `launch`, `observe`, and `terminate` are executable provider mechanics. They still do **not** own QueueBash state: `QueueExecutionService` owns execution journaling, QID locking, runtime metadata, terminal reconciliation and cancellation transitions. A provider stop acknowledgement never authorizes `cancelled` by itself; post-terminate observation must be conclusively `.QueueJobObservation~DEAD`.

### DirectRunnerProvider

Initial compatibility facts:

```text
id = direct
capabilities = local-process, pid, pgid, foreign-user-via-operator
```

Observation tests both PID and process-group membership. Linux process observation excludes zombie-only PID/PGID membership from LIVE evidence. Missing fresh launch metadata returns `.QueueJobObservation~LAUNCH_PENDING`; inconclusive metadata returns `~UNKNOWN`.

Dev8 direct launch uses a separate process group, a durable PID/PGID locator, a durable exit-code locator, and a non-capturing background launcher. Recovery can reconstruct runtime metadata from those locators after a QueueRexx crash without relaunching the payload.

### SystemdRunnerProvider

Initial compatibility facts:

```text
id = systemd
capabilities = local-transient-unit, systemd-user, systemd-unit-mainpid
```

An explicit systemd request fails when the user service is unavailable or when root is launching a foreign Unix payload user. Auto selection may choose direct instead.

A recorded `SYSTEMD_UNIT` is authoritative and evaluates `ActiveState`, `SubState`, and `MainPID`. Unknown/unqueryable systemd state returns `.QueueJobObservation~UNKNOWN`; it is not proof of death.

## PlatformFactProvider

Platform facts should become provider supplied rather than a monolithic detector. Candidate facts include:

```text
os family/version
architecture
current uid/user
payload user relationship
systemd user bus usable
cgroup features
namespace/sandbox facilities
seccomp facilities
container runtime facilities
VM facilities
cloud instance identity
network/storage abilities
Queue Fabric reachability
```

Facts need provenance, observation time, and confidence/known status. Unknown is distinct from false.

## PlacementProvider

Local runner selection and node placement are separate decisions.

The existing Job-to-Node Allocator should be the principal implementation seam for remote/distributed placement. It already embodies hard eligibility before optimisation, durable capability versus transient capacity, exclusion reasons, authority/admission seams, signed evidence binding, and ownership/liveness fencing.

The order is:

```text
job requirement
 -> node eligibility / authority / admission
 -> placement lease
 -> on selected node: runner-provider selection
```

A fast runner cannot compensate for a node that is legally, jurisdictionally, trust, runtime, or authority-ineligible.

## PolicyProvider

Policy providers return decisions; they do not move files themselves.

```text
PolicyDecision
  allowed
  reason/code
  evidence
  provider identity
  policy generation
```

`QueueTransitionService` applies a valid policy-block transition atomically.

### QueueBash class-policy provider — dev11

`QueueBashClassPolicyProvider` is the first concrete policy provider. It is compatibility-pinned to QueueBash 0.18.144 and delegates worker execution policy to QueueBash's own `_queue_job_policy_execution_check` rather than reproducing class-policy, grant, or command-bound authorisation semantics in ooRexx.

For read-only inspection the provider copies the `.job` record to a temporary file before invoking the QueueBash gate. QueueBash may append exemption evidence to that temporary copy exactly as it normally would, but the authoritative queue record is unchanged.

The provider fails closed when:

```text
exact QueueBash source is unavailable
QueueBash reports a version other than 0.18.144
provider execution cannot be completed
QID authority is ambiguous at the QueueRexx adapter
worker execution assessment is requested for a non-running record
```

`QueueBashExecutionPolicyGate` adapts the provider result to the existing typed worker-admission contract. It does not implement submit-time policy; `assessSubmit()` remains a denial until the complete QueueBash submit security surface is represented explicitly.

## ProcessObservationProvider

This may be implemented by a runner directly or delegated. Required result model:

```text
state: LIVE | DEAD | UNKNOWN | LAUNCH_PENDING
observed_at
provider
provider_version
evidence
confidence/authority
```

The kernel maps observations to allowed transitions. Providers never call `mv` on QueueBash records.

## Registration

The registry is runtime-populated. Built-ins are ordinary registered providers, not hard-coded privileged branches.

Future Runtime Registry integration should support immutable provider generations and pinned sessions so a running operation does not silently change implementation halfway through a job.


## WLU / placement authority providers

WLU is first-class job authority, not a runner-provider score. QueueRexx binds the existing Work Load Units v0.12 and Job-to-Node v0.6 classes. `QueueJobNodeWLUAdmission` reserves queue-declared ceiling work and WLU/s and returns the real reservation in Job-to-Node `reservationRef`.

`reservationRef` equality does not confer placement authority. `QueueJobNodePlacementAuthority` delegates verification to Job-to-Node `verifyLease()` using the exact placement request retained alongside the lease. Missing request/allocator/time evidence, stale capacity, generation drift, ownership fencing, lost restored admission or policy-generation mismatch all fail closed. QueueRexx records the verdict/evidence but does not implement a competing allocator.

Runner providers do not create, settle or release WLU. Placement/admission must complete first for managed jobs; runner selection remains a separate mechanism decision on the admitted node.

## Status projection providers

Retained Migratable Job topic data and WLU projection are observation/read-model inputs only. Provider projections must preserve provenance and authority flags and may never invoke queue mutation or external-authority settlement merely because a status value changed.

## Scheduler / runner separation

`QueueJobScheduler` does not choose process mechanisms. Scheduling admission answers whether a job is eligible to execute now (including WLU reservation and placement authority), then ordinary queue priority orders eligible jobs. `QueueRunnerSelector` independently selects how an admitted job runs on the chosen node. This keeps WLU/capacity, placement and process mechanism as separate authorities.

### Worker-admission ordering boundary

The QueueBash execution-policy provider is not a class/resource preflight provider. QueueBash evaluates class/resource availability before its execution-policy gate; QueueRexx must preserve that ordering when full worker-admission parity is implemented. Dev11 therefore does not interpret `policy=allow` as `worker admission=allow`.

## PeerAuthorityProvider / mesh adapters — dev12

The peer mesh is a transport/composition provider, not a new source of domain truth. A local peer handler implements `evaluate(request)` and returns `APPROVE`, `DENY`, `ABSTAIN` or `ERROR` plus typed evidence. Transport authentication only determines who may ask; it never implies `APPROVE`.

Concrete dev12 adapters project exact local authority for QueueRexx job state, QueueBash execution-policy inspection and Job-to-Node capability/capacity load evidence. Multi-peer authorization uses a fixed decision policy (`ANY`, `QUORUM`, `ALL_AVAILABLE`, `REQUIRED`, optional deny veto). A stable authorization ID binds the complete policy and subject/context into durable per-peer replay.

Provider failure is represented as peer unavailable/error evidence. Fixed thresholds are not reduced because availability changed. This is the critical distinction between resilient mesh operation and fail-open quorum degradation. See `PEER_MESH.md`.

