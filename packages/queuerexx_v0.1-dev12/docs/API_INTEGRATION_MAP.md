# Existing ooRexx API integration map

This document maps QueueRexx responsibilities onto the APIs present in the supplied 2026-09-13 ooRexx API bundle. The purpose is reuse, not duplication.

## QueueBash 0.18.144 policy compatibility boundary

QueueBash is not an ooRexx API package, but its worker execution policy is an authoritative compatibility surface for the shared queue fabric.

Dev11 binds that surface through `QueueBashClassPolicyProvider`:

- exact QueueBash 0.18.144 source is required;
- `_queue_job_policy_execution_check` owns class-policy/authorisation interpretation;
- QueueRexx supplies a temporary job-record copy for read-only assessment;
- QueueBash shared/admin policy precedence and command-bound authorisation validation are retained;
- QueueRexx receives a typed verdict/evidence object only;
- queue-state movement remains a QueueRexx/QueueBash transition-authority operation, not a provider side effect.

This avoids creating a second policy language while QueueRexx's native provider architecture matures.

## Object Queue Fabric v0.9-dev5

Grounded package: `oorexx_queue_fabric_v0.9-dev5.zip`.

Useful surfaces include `ObjectQueueManager`, permanent queues with a durable store, `QueueWorkPackage`, claim/ack/nack semantics, `QueueTriggerRegistration`, direct and Runtime-Registry trigger targets, traffic records, and recovery of durable manager state.

QueueRexx use:

- durable event/trigger delivery;
- remote/distributed event bridge;
- work notifications and control messages;
- replay-safe trigger work packages.

It is **not** the authority for QueueBash job state. A queue-fabric package points at/carries an event or operation; `.queuebash` remains the job-state authority.

## Runtime Registry v0.14

Useful doctrine: immutable runtime generations, separate code/config generations, pinned sessions, dependency closure lifecycle.

QueueRexx use:

- provider generations;
- durable trigger target lookup;
- pin a provider/trigger implementation for the lifetime of one operation;
- safe draining/upgrades.

## Job-to-Node Allocator v0.6

Grounded package: `job_node_allocator_v0.6.zip`.

Useful surfaces include `JobNodeRequirement`, `NodeCapabilityStatement`, `NodeCapacityObservation`, `JobNodeEligibilityPolicy`, hard-constraint assessors, admission authority, placement policy, signed `JobNodePlacementLease`, and liveness/ownership fencing.

QueueRexx use:

- placement before runner selection for remote/fleet jobs;
- legal/trust/runtime/capacity eligibility;
- evidence-backed node choice;
- current-lease verification through allocator `verifyLease()` rather than token matching;
- exact placement-request retention so requirement digests can be revalidated;
- dispatch ownership fencing;
- future migratable-job placement/re-placement evidence without transferring queue-state authority.

Do not collapse node placement into runner choice. `systemd` versus `direct` is a mechanism decision on a chosen node; node allocation is a separate authority decision.


### Job-to-Node network access — v0.6-network1

Grounded package: `job_node_allocator_v0.6-network1.zip`, SHA-256 `e6ea65304f51e16ee336a27783d185b09cdfff7117b4abe8ed8afabe2cb03b1f`. It keeps exact core v0.6 as authority and supplies API `job.node.allocator.network/0.1`: `JobNodeNetworkAllocatorService`, `JobNodeNetworkAllocatorClient`, `JobNodeNetworkRequestLedger`, `JobNodeNetworkAccessPolicy` and the canonical request/lease codec. QueueRexx hosts and recovers these classes; it does not reproduce them.

The network service rides a service route on the general QueueRexx peer mesh. Queue Fabric `queue.transport/2` owns authenticated delivery; `QueueRexxPeerMeshRuntime` owns reusable peer connectivity/configuration; network1 owns request/replay/ACL semantics; JobNodeAllocator v0.6 alone owns placement/admission/ownership.

## Work Load Units v0.12

Grounded API: `work.load.units/0.12`.

QueueRexx use:

- immutable expected/ceiling work declaration in micro-WLU;
- delivery-capacity demand in micro-WLU/second;
- authoritative reserve/consume/settle/release lifecycle;
- read-only WLU reservation projection for status/monitoring;
- durable reservation proof binding for crash recovery.

WLU Authority remains authoritative for work accounting. QueueRexx does not keep a competing balance. High-frequency WLU reservation proofs remain the WLU-owned SipHash-2-4-128 contract.

Job-to-Node placement carries the exact WLU reservation identifier in `reservationRef`, which gives Migratable Job a natural way to retain placement/accounting evidence through handoff without inventing another entitlement token. `reservationRef` is a binding, not a complete validity proof: QueueRexx asks Job-to-Node to verify the lease against current ownership, admission and registry evidence before scheduling it.

## Observation v0.5

Grounded package: `oorexx_observation_v0.5.zip`.

Useful surfaces include `ObservationEnvelope`, `ObservationStream`, subscriptions, acknowledgements, checkpoints, deltas, gateway leases and read-only query routing.

QueueRexx use:

- job/process health observations;
- worker/service facts;
- monitoring subscriptions;
- process/provider observation history;
- dashboard feeds without polling QueueBash files ad hoc everywhere.

Observation never grants mutation authority.

## Journal Pointed State v0.1

Grounded package: `oorexx_journal_pointed_state_v0.1.zip`.

Useful surfaces include reversible `JournalPointedState`, batched `JournalEdit`, point/delta history, `StateOfNationController`, checkpoints, and recovery coordination.

QueueRexx use:

- in-process/replayable control state;
- trigger cursor state model;
- recovery-plan checkpoints;
- provider-registry/control-plane state.

The class is not by itself permission to replace `.queuebash` state or to claim persistence that has not been configured. Durable QueueRexx recovery state must be persisted through an explicit durable sidecar.

## Database / native database backends

Grounded packages include `oorexx_db_skeleton_v0_46.zip` plus native database backend work.

QueueRexx use:

- rebuildable job/event index;
- audit/query acceleration;
- trigger registry and cursor persistence;
- provider capability history;
- health history;
- operator/dashboard queries.

SQL is a materialized view/control sidecar, not the canonical job-state store. QueueRexx must be able to rebuild it from QueueBash records/events.

Transactions are valuable for sidecar atomicity, but a SQL commit must never contradict the already-authoritative filesystem transition. Recovery reconciles sidecar state to filesystem authority.

## Rapid Crypto v0.8.3

Grounded package: `oorexx_crypto_v0.8.3.zip`.

Useful surfaces include SHA-256/SHA-512, HMAC-SHA-512, SipHash128, Ed25519, X25519, ChaCha20 and RSA.

QueueRexx use:

- job-record fingerprints;
- transition/event hashes;
- audit-chain sealing;
- provider manifest signatures;
- placement/authority proof integration;
- delivery manifest verification.

Crypto strengthens evidence; it must not invent a second state authority.

## Storage Fabric v0.1-dev7

QueueRexx use is primarily for durable external artifacts, logs, checkpoints, and controlled movement of large job outputs. It is the checkpoint-transfer authority used by the supplied Migratable Job framework for verified resumable migration state. Job state itself remains the QueueBash filesystem contract.

## Serialization classes

The runtime-supplied classes are mandatory infrastructure, not replaceable convenience helpers:

```text
json.cls      -> .JSON
csvStream.cls -> .CSVStream
Yaml.cls      -> .Yaml
```

QueueRexx will not have alternate home-grown JSON, CSV/TSV, or YAML encoders.

## Dev12 network APIs

| Surface | API | QueueRexx role | Authority retained by |
|---|---|---|---|
| Remote placement | `job.node.allocator.network/0.1` | hosts exact upstream network1 as a service route; clients use exact `JobNodeNetworkAllocatorClient` | exact JobNodeAllocator v0.6 |
| Peer control plane | `queuerexx.peer.mesh/0.1` | reusable peer connectivity/trust/routing plus typed approval/check evidence and logical service routes | each local QueueRexx/JTN/WLU/policy authority |
| Peer authorization receipt | `queuerexx.peer.authorization.receipt/1` | binds authorization ID, subject digest, fixed decision policy and peer evidence | local decision policy + authenticated peer decisions |
| Transport | `queue.transport/2` | permanent logical routes and encrypted delivery | Queue Fabric v0.9-dev5 |

Peer-mesh operations are `AUTHORIZE`, `JOB_CHECK`, `LOAD_CHECK`, `POLICY_CHECK`, `PLACEMENT_CHECK`, `MIGRATION_CHECK` and `HEALTH`. The first four have dev12 service/adapter frontage; placement/migration checks remain reserved for exact authority adapters and must not be inferred from copied status.

