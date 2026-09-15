# Networkable Job-to-Node Allocator

API: `job.node.allocator.network/0.1`

The network layer is a request/reply adapter around the authoritative
`JobNodeAllocator` v0.6.  It does not move allocator authority into clients and
it does not serialise live allocator objects across the wire.

## Operations

- `PLAN` — advisory only; evaluates the supplied registry/policies but creates no admission/ownership state.
- `ALLOCATE` — authoritative allocation through `JobNodeAllocator~allocate()`.
- `CHECK` — verifies an exact lease/request pair through `verifyLease()`.
- `RENEW` — authoritative lease renewal.
- `RELEASE` — authoritative ownership/admission release.

Every request has a stable `requestId`.  The allocator service stores the
request digest and exact response.  At-least-once Queue Fabric redelivery
therefore replays the original result.  Reusing an id with different content
returns `REQUEST_ID_CONFLICT`.

The request carries a `clientId`, not an arbitrary reply queue.  The allocator
administrator binds each client id to a server-side remote reply queue alias.
This prevents a caller from using the allocator service as an open queue relay.

Queue Fabric direct queues are the control transport.  With
`QueueSocketClientTransport`/`QueueSocketListener`, requests and replies can
cross hosts using `queue.transport/2`, including source-IP admission,
authenticated peer identity, encryption and durable store-and-forward.

The server additionally applies `JobNodeNetworkAccessPolicy`; a client can be
limited by operation and bound to one `ownerNodeId`.
