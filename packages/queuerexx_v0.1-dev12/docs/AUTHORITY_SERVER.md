# QueueRexx Job-to-Node authority server — dev12

QueueRexx v0.1-dev12 can host the central Job-to-Node authority used by FD,
Migratable Job and other QueueRexx peers.  QueueRexx owns the authority-host
lifecycle and node connectivity; it does **not** fork the Job-to-Node network
protocol.

The exact network frontage is supplied by `job_node_allocator_v0.6-network1`:

```text
API: job.node.allocator.network/0.1

QueueRexx authority node
  QueueRexxPeerMeshRuntime
    general peer identity / trust / routing
    Queue Fabric permanent queues/channels
    queue.transport/2
             |
             +-- ordinary QueueRexx peer services
             |
             +-- JNA service route
                    |
                    v
          JobNodeNetworkAllocatorService      exact network1
          JobNodeNetworkRequestLedger         exact network1
          JobNodeNetworkAccessPolicy          exact network1
                    |
                    v
          JobNodeAllocator v0.6               placement authority
          JobNodeDurablePlacementManager      durable authority state
          optional QueueJobNodeWLUAdmission   WLU admission authority

remote QueueRexx / FD node
  QueueRexxPeerMeshRuntime
        |
  JobNodeNetworkAllocatorClient               exact network1
        |
  QueueRexxJobNodeNetworkAllocatorProxy       thin allocator-shaped adapter
        |
  Migratable Job v0.2.4 managed placement
        |
  QueueRexx final QID + lease fence
        |
  migratable.job.start/1
        |
  private workload worker
```

## Ownership boundary

QueueRexx owns:

- authority-host process lifecycle;
- exact JobNodeAllocator v0.6 instance;
- durable allocator journal/recovery;
- optional WLU admission composition;
- exact `JobNodeNetworkAllocatorService` hosting;
- exact `JobNodeNetworkRequestLedger` durable request replay;
- exact `JobNodeNetworkAccessPolicy` client operation/owner constraints;
- QueueRexx peer configuration and service-route composition;
- Queue Fabric `queue.transport/2` inter-node connectivity;
- service restart/recovery and durable reply backlog retry.

Job-to-Node still owns placement, admission, ownership epochs/fencing, lease
creation, verification, renewal and release.  Queue Fabric transports messages;
it does not become placement authority.  The peer mesh establishes node trust
and routes; transport trust does not grant Job-to-Node semantic authority.

Remote FD/Migratable Job nodes consume the exact upstream
`JobNodeNetworkAllocatorClient` operations:

```text
PLAN
ALLOCATE
CHECK
RENEW
RELEASE
```

There is no FD-side/local allocator fallback, no QueueRexx lease format and no
synthetic placement result.

## Durable recovery ordering

Authority startup is fail-closed and ordered:

```text
restore Job-to-Node durable allocator state
        |
open exact network1 durable request ledger
        |
restore Queue Fabric permanent queues/channels
        |
apply QueueRexx peer connectivity/trust configuration
        |
apply network1 client operation/owner/reply bindings
        |
drain requests already accepted before a crash
        |
retry staged durable replies where peers are reachable
        |
start accepting new socket transport
```

A network1 operation is authoritative once the allocator operation and exact
response have been durably recorded.  Delivery to an offline client is a
retryable transport concern: the response remains in a permanent transmission
queue.  An unavailable peer therefore cannot force QueueRexx to roll back or
repeat an already committed allocation.

Identical `requestId` + identical content replays the exact prior response.
The same `requestId` with changed content is rejected with
`REQUEST_ID_CONFLICT`.  Corrupt allocator or network-ledger state fails closed.

## Configuration split

Dev12 has two preferred configuration layers.

### 1. General node connectivity

`QueueRexxPeerMeshConfig` reads:

```text
schema: queuerexx.peer.mesh.config/1
```

Each peer supplies connectivity/trust information such as:

- `node_id`;
- Queue Fabric `manager`;
- `host` / `port`;
- `transport_principal`;
- transport `key_id` / `key_hex`;
- `allowed_source_ips`;
- ordinary peer-control `operations`;
- optional transport timeout.

This configuration creates the general QueueRexx peer relationship.  It is not
Job-to-Node authority and can be reused by health, policy, approval, migration,
future administrative services and the Job-to-Node network service.

### 2. Job-to-Node service binding

`QueueRexxAuthorityPeerClientConfig` reads:

```text
schema: queuerexx.job-node.authority-peer-clients/1
```

Each entry contains only semantic service binding:

- `client_id`;
- `peer_node_id`;
- `client_reply_queue`;
- allowed network1 `operations`;
- optional `owner_node_id`.

Host, port, transport principal and keys are deliberately absent: they already
belong to the general peer configuration.  QueueRexx applies peer configuration
first and service ACL/reply binding second, before listening for new traffic.

`QueueRexxAuthorityClientConfig` schema
`queuerexx.job-node.authority-clients/1` remains as a bootstrap/compatibility
form that can create the general peer and then bind network1 in one document.
The split configuration is preferred for a real mesh.

The server, never the request, chooses the reply route.  A client cannot turn
the authority node into an arbitrary Queue Fabric relay.

## General service routes over one peer

`QueueRexxPeerMeshRuntime~bindServiceRoute()` is service-neutral.  It gives an
application protocol its own permanent local queue, transmission queue, sender
channel, remote-queue alias and security domain while reusing the peer's
existing endpoint, inbound trust and receiver channel.

This means one authenticated QueueRexx A<->B relationship can simultaneously
carry:

```text
queuerexx.peer.mesh/0.1       ordinary typed peer checks/approvals
job.node.allocator.network/0.1 exact Job-to-Node authority service
future QueueRexx services      without another node connection
```

The services remain semantically independent even though they share transport.

## Migratable Job v0.2.4

Migratable Job remains placement/start orchestration authority.  The remote
allocator proxy merely adapts the exact network1 client to the allocator-shaped
messages expected by `MigratableJobManagedPlacementTool`.

For START:

1. Migratable Job performs its normal exact network lease check.
2. QueueRexx acquires the shared QID lock.
3. QueueRexx rechecks queue/policy authority.
4. QueueRexx performs a second remote network1 CHECK under that QID lock.
5. Only then does it enter `migratable.job.start/1`.

Starter receipt replay remains upstream-owned and prevents a duplicate private
worker.

## Qualification

Dev12 qualification includes:

- exact network1 in-process request/replay/ACL semantics over the QueueRexx
  service route;
- peer-config + semantic-service-config ordering and fail-closed malformed
  configuration;
- durable request accepted before process loss, allocator/ledger reconstruction,
  exact response replay and durable offline reply backlog;
- WLU-backed allocation restart restoring ownership plus admission proof;
- one encrypted QueueRexx peer carrying both ordinary mesh HEALTH and exact
  network1 ALLOCATE/CHECK/RELEASE traffic;
- full encrypted Migratable Job v0.2.4 remote PLAN/ALLOCATE/CHECK/RENEW/START/
  replay/RELEASE with one private-worker entry;
- unchanged upstream network1 in-process, ledger-restart and encrypted socket
  qualification.
