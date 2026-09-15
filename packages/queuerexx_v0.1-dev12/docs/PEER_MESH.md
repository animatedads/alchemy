# QueueRexx peer authority mesh — dev12

## Purpose

QueueRexx dev12 adds a general QueueRexx-to-QueueRexx control plane over the
existing Queue Fabric.  It is used for inter-node authorization and read-only
authority checks such as job state, policy, load/capacity, placement,
migration and health.

It is deliberately **not** a new placement authority, queue database, cluster
leader or consensus service.  Each QueueRexx node retains its own local
authorities.  The mesh transports typed requests and durable evidence between
those authorities.

```text
QueueRexx A                         QueueRexx B
-----------                         -----------
local queue authority               local queue authority
local policy                        local policy
local JTN/WLU authority             local JTN/WLU authority
       |                                   |
       +-- QueueRexx peer mesh ------------+
             permanent Queue Fabric queues/channels
             authenticated peer binding
             queue.transport/2
             durable request replay ledger
```

A third node C forms independent A<->C and B<->C links.  A is not transit for
B<->C and there is no mandatory central mesh node.

## Mesh, not hub-and-spoke

Topology is local configuration.  Every node may bind directly to multiple
peers.  Losing one peer marks that peer unavailable; it does not make the
whole mesh unavailable.

Availability is a property of each decision policy:

- `ANY` — one approval is enough, subject to configured response minima.
- `QUORUM` — fixed minimum approvals and responses.  The threshold does not
  shrink merely because peers are unavailable.
- `ALL_AVAILABLE` — every peer that actually responds must approve, with a
  configured minimum-response floor.  This mode is suitable only where that
  availability-sensitive meaning is intended.
- `REQUIRED` — named peers must approve.  A missing required peer fails that
  decision closed without blacking out unrelated work.
- `denyVeto` may make any explicit DENY fatal even when an approval threshold
  has otherwise been reached.

This allows a high-risk operation to require A+B while a routine load query
can accept two of four healthy nodes.  Node failure therefore cannot silently
weaken a policy, and unrelated node failure cannot become a global veto.

## Wire contract

API: `queuerexx.peer.mesh/0.1`

Request schema: `queuerexx.peer.mesh.request/1`

Response schema: `queuerexx.peer.mesh.response/1`

Authorization receipt schema: `queuerexx.peer.authorization.receipt/1`

Operations:

- `AUTHORIZE`
- `JOB_CHECK`
- `LOAD_CHECK`
- `POLICY_CHECK`
- `PLACEMENT_CHECK`
- `MIGRATION_CHECK`
- `HEALTH`

Payloads are Queue Fabric-persistable `Directory` graphs.  The transport does
not require a remote workload to load QueueRexx implementation classes merely
to decode an approval or check result.

## Peer identity and routing

Each administrator-created peer binding fixes:

- peer QueueRexx node ID;
- Queue Fabric manager ID;
- transport principal;
- local durable request queue;
- server-owned remote reply alias;
- operations that peer may request.

The request may not select an arbitrary reply destination.  The inbound Queue
Fabric receiver is already bound to the remote manager/principal, and the peer
service additionally verifies `from_node`, `to_node` and operation against the
local binding.

Socket peers are additionally bound to Queue Fabric transport key identity and
an explicit exact source-IP allowlist.  Queue Fabric v0.9-dev5 deliberately
opens one authenticated encrypted TCP session per delivery.  QueueRexx does
not replace that with a private socket protocol: the **logical peer link** is
persistent because its queues, channels, routing, trust and pending deliveries
are durable.  A future physically persistent/multiplexed TCP transport belongs
in Queue Fabric.

## Persistent peer configuration and service routes

General node connectivity is represented by `queuerexx.peer.mesh.config/1`. A peer entry owns the remote QueueRexx node ID/manager, host and port, transport principal, Queue Fabric key identity/material, explicit source-IP allowlist, ordinary peer-mesh operation ACL and transport timeout. Reapplying this configuration reconstructs the logical queues/channels/routes and transport trust after QueueRexx restart.

Application protocols do not repeat that connectivity configuration. `QueueRexxPeerMeshRuntime~bindServiceRoute()` creates a service-neutral route on an already bound peer: a durable local service queue, service-specific xmit queue/sender channel, remote-queue alias and security domain reuse the peer's endpoint and authenticated receiver relationship.

The first authority consumer is exact Job-to-Node network1. Its separate `queuerexx.job-node.authority-peer-clients/1` document binds only client ID -> peer node, allowed network1 operations, optional owner node and server-approved reply queue. It does not duplicate host/port/key configuration. Other QueueRexx services can use the same mechanism without becoming part of Job-to-Node authority.

## Durable replay and authorization IDs

Every peer request has a stable `request_id`.  The receiving node writes a
claim to `logs/queuerexx-peer-mesh/requests.journal` before evaluating the
local authority and stores the exact response afterward.

- same request ID + same canonical request => exact prior response replay;
- same request ID + changed request => `REQUEST_ID_CONFLICT`;
- corrupt peer ledger => service fails closed;
- a claimed request whose evaluator outcome was not durably completed is not
  silently executed again after restart.

`QueueRexxPeerAuthorizationGate` adds a transaction-level authorization ID.
For a peer P its stable request ID is derived as `authorizationId:P`.  The
complete decision policy (mode, approval/response minima, required peers and
veto setting) is embedded in the request context and therefore in the durable
request digest.  Reissuing the same authorization after restart reproduces
exact peer approvals.  Reusing the same authorization ID with a weaker quorum,
different subject, or different context conflicts instead of reinterpreting
old approval evidence.

## Local authority adapters

`QueueRexxPeerMeshAdapters.cls` supplies concrete read-only projections:

### JOB_CHECK

`QueueRexxPeerJobCheckHandler` reads the peer's exact `.queuebash`/QueueRexx
state through `QueueStateStore`.

- missing QID => DENY;
- duplicate authoritative records => ERROR;
- one record => APPROVE with QID, state, class, priority, runner and record
  path evidence.

The response is evidence from that node; it does not transfer queue-state
authority to the caller.

### POLICY_CHECK

`QueueRexxPeerPolicyCheckHandler` delegates to `QueuePolicyInspectionService`.
When the exact QueueBash policy provider is configured, QueueBash remains the
compatibility oracle and its allow/deny/error evidence is transported over the
mesh.

### LOAD_CHECK

`QueueRexxPeerJobNodeLoadHandler` reads the exact local Job-to-Node
`NodeCapabilityRegistry` capability and capacity observation.  Optional request
thresholds include minimum free memory/disk/CPU/WLU rate and maximum queue
depth/active jobs.  Missing, offline, expired or insufficient evidence denies.
The returned proof reference and capability/observation generations are
preserved.

### AUTHORIZE

Authorization is intentionally not fabricated from mere network trust.
`AUTHORIZE` must be bound to a real local approval handler.  Transport ACL says
who may ask; the handler decides whether the requested action is approved.
The multi-peer `QueueRexxPeerAuthorizationGate` then applies the caller's fixed
mesh decision policy to the authenticated peer decisions.

`PLACEMENT_CHECK` and `MIGRATION_CHECK` are reserved on the same transport
surface for exact local authority adapters.  They must delegate to
Job-to-Node/Migratable Job rather than reconstruct those authorities from
copied status fields.

## Coexistence with the Job-to-Node authority server

A QueueRexx node may simultaneously host the dev12 Job-to-Node authority and
participate in the peer mesh.  `QueueRexxAuthorityStack~enablePeerMesh()` uses
the **same** Queue Fabric manager, channel fabric, socket transport and socket
listener. Exact Job-to-Node network1 is attached with `bindServiceRoute()` rather
than by creating a second socket/trust relationship.

```text
                   QueueRexx authority node
                 /                         \
 job.node.allocator.network/0.1     queuerexx.peer.mesh/0.1
                |                           |
        exact JTN v0.6 authority     peer approvals/checks
                 \                         /
                  Queue Fabric queue.transport/2
```

The two APIs remain different authority surfaces even though transport is
shared.

## Failure semantics

- unrelated peer unavailable -> recorded in decision evidence; fixed quorum may
  still succeed;
- required peer unavailable -> that decision fails;
- authorization policy changed under an existing authorization ID -> conflict;
- unauthorized peer operation -> DENY;
- peer/request identity mismatch -> ERROR;
- corrupt replay ledger -> peer service unavailable/fail closed;
- stale JTN capacity -> LOAD_CHECK DENY;
- Queue Fabric path unavailable -> peer marked unavailable; no local fabricated
  approval;
- no leader-election or local-authority fallback is inferred from transport
  failure.

## Qualification

`test_peer_mesh.rex` proves a three-node A/B/C non-hub topology using three
independent Queue Fabric managers.  It covers fixed quorum, required-peer and
veto semantics, loss of B while A continues through C, real QueueRexx
`JOB_CHECK`, real Job-to-Node `LOAD_CHECK`, replay/conflict and direct B->C
health with A absent from the path.  It also proves policy-bound authorization
replay and rejects reuse of an authorization ID under a changed quorum.

`test_peer_mesh_socket.sh` proves a separate-process QueueRexx A -> QueueRexx B
`AUTHORIZE` request/reply over authenticated encrypted `queue.transport/2`,
with explicit manager/principal/key/source-IP trust and administrator-owned
reply routing.

`test_network1_over_peer_mesh_socket.sh` proves that one authenticated encrypted peer relationship simultaneously carries ordinary mesh `HEALTH` and the exact upstream `JobNodeNetworkAllocatorClient` ALLOCATE/CHECK/RELEASE protocol. `test_authority_mesh_config.rex` proves the split between peer connectivity/trust and semantic Job-to-Node service binding.
