# Job-to-Node Allocator v0.6 + network service extension

This package preserves the exact Job-to-Node Allocator v0.6 core sources and adds
`job.node.allocator.network/0.1` in `src/JobNodeNetworkService.cls`.  See
`docs/NETWORK_ALLOCATOR.md` and `VALIDATION_NETWORK.txt`.

The network service is intended for direct Queue Fabric request/reply queues.
With Queue Fabric v0.9-dev5 socket transport, allocator requests can cross hosts
using authenticated/encrypted `queue.transport/2` while all authoritative
placement mutation remains local to the allocator service.

---

# ooRexx Job-to-Node Allocator v0.6

Authority-constrained job placement across heterogeneous execution nodes.

## Core invariant

Hard eligibility is evaluated before optimisation. Security, legal, access,
runtime/software, architecture, liveness and mandatory resource constraints
are never soft scores and cannot be outweighed by idle CPU, free storage, cost
or speed.

Node capability remains distinct from transient capacity. Queue Fabric remains
transport authority, WLU remains work/capacity admission authority, and API
Client v0.2 remains authoritative for API egress-session allocation after a
general execution-node placement has been made.

## v0.6 collision merge and evidence hardening

v0.6 merges the two independently produced v0.4 branches into the durable v0.5
continuation line. The branches were complementary:

- `job_node_allocator_v0.4(3).zip` supplied authenticated liveness, ownership
  epochs/fencing, renewal and controlled node-loss recovery and was the direct
  ancestor of v0.5 restart recovery.
- `job_node_allocator_v0.4(1)(2).zip` supplied placement-evidence integrity
  hardening and an additional regression suite.

v0.6 preserves both sets of semantics and adds no softening of hard eligibility.

Merged integrity invariants:

- API Client `ApiRouteRequirement` fields (`country`, `vpn`, `network`,
  `egressClass`, required tags) are canonicalised into the job requirement and
  therefore into `requirementDigest`.
- node API-egress capability is canonicalised into node capability evidence and
  therefore into `capabilityDigest`.
- node `online` state is bound into capability evidence; revoked/offline nodes
  fail lease verification immediately.
- same-generation but different capability advertisements are rejected;
  identical repeats are idempotent.
- same-observation-generation but different capacity observations are rejected;
  identical repeats are idempotent.
- placement and renewed lease expiry are bounded by the capacity observation
  expiry used to justify placement.
- lease verification independently checks owner identity, allocator policy
  generation, node online state, capacity freshness, capability-generation
  linkage, and all requirement/capability/capacity digests.
- queue-neutral dispatch envelopes now actually retain the supplied payload;
  this is regression-tested.

These evidence rules compose with v0.4/v0.5 ownership fencing: a current
ownership epoch is necessary but not sufficient. The lease must also still be
bound to the same hard job requirements, node capability, current capacity
observation and allocator policy generation.

## Durable placement state and restart recovery

v0.5 semantics are retained:

- `JobNodeDurableJournal` stores append-only committed placement snapshots;
- committed snapshots are SHA-256 bound and may use the injected
  `JobNodeProofAuthority` for signatures;
- torn/uncommitted trailing writes are ignored, while a corrupt committed
  snapshot fails closed;
- allocator placement sequence and highest ownership epochs survive restart;
- current placement ownership is reconstructed without creating a second owner;
- reservation-bearing leases fail verification until the authoritative
  admission object has been reconstructed;
- expired persisted placements are not resurrected;
- recovery ambiguity is explicit as `RECOVERY_BLOCKED`.

### WLU v0.12 restart recovery

WLU reservation recovery persists enough of the real v0.12 `WLUReservation`
and `WLUProof` to reconstruct the authenticated reservation after restart. The
WLU authority remains authoritative: recovery checks `reservationState`, only
restores `ACTIVE` reservations, and later release still follows WLU's normal
proof-validation path.

## Placement and recovery sequence

Normal placement:

`job requirements -> hard eligibility -> live candidates -> ranking -> authoritative admission/WLU reservation -> ownership epoch -> evidence-bound placement lease -> durable checkpoint -> Queue Fabric delivery`

Restart recovery:

`last committed snapshot -> verify snapshot -> restore allocator sequence -> restore ownership epochs -> reconstruct active admissions -> restore current owners -> resume verification/renewal/recovery`

Node-loss recovery:

`liveness loss -> fence prior ownership -> release prior admission -> re-evaluate hard eligibility -> reserve -> higher ownership epoch -> dispatch`

For API work:

`general placement -> execution node -> API Client route/session reservation -> fetch -> completion to owner`

The allocator does not absorb API Client route/session allocation or Queue
Fabric transport semantics.

## Authority integrations

- Security Effect v0.10 `SecurityAssessment`;
- Legal Effect v0.14 `LegalEffectAssessment`;
- Access Permissions v0.1 `AccessControlDecision` / `PermissionDecision`;
- WLU v0.12 `WLUWorkDemand` / reservation / release / reservation-state path;
- Queue Fabric v0.9-dev4 `ObjectQueueManager~put` dispatch;
- Crypto v0.8.3 stable SHA-256 public API for evidence and journal digests;
- API Client v0.2 route/capability mesh without ownership of its egress session.

Production heartbeat, placement and durable-journal signing authorities remain
injected seams; v0.6 does not create a second trust/key-management system.
