# Managed remote initial start — `migratable.job.remote-start/1`

Migratable Job v0.2.5 closes the initial-placement gap left deliberately open in
v0.2.4.  Job-to-Node still decides and owns placement.  Once a `NEW` request has
a current placement lease, `MigratableJobQueuePlacedStartExecutor` can dispatch
the standard starter request to the allocated node over a Queue Fabric direct
request queue.

The destination does **not** treat queue delivery as permission to execute.  A
`MigratableJobRemoteStartService` performs these checks immediately before
calling `MigratableJobStarter`:

1. request schema/client route is authorised;
2. request mode is `NEW`;
3. lease job and destination node bind to the start request/service node;
4. the exact lease is current according to a `MigratableJobPlacedStartLeaseVerifier`;
5. only then is the standard `migratable.job.start/1` starter entered.

Two verifier implementations are supplied:

- `MigratableJobLocalPlacedStartLeaseVerifier` — verifies against a resident
  `JobNodeAllocator`;
- `MigratableJobJobNodeNetworkLeaseVerifier` — issues authoritative `CHECK`
  requests through `job.node.allocator.network/0.1`, so a destination does not
  need allocator state locally.

## Idempotency and uncertainty

The remote-start request id is the standard `startId`.  The destination keeps a
separate durable RPC ledger binding that id to the exact lease + start request +
response.  The starter's own digest-protected `start.receipts` remain the
runtime-side idempotency authority.  These are deliberately separate layers.

An exact request replay returns the recorded response. Reusing the same
`startId` with a different lease/request binding fails as
`REQUEST_ID_CONFLICT` before runtime entry.

If the source successfully queues the request but no reply is received inside
its configured wait window, the executor returns `REMOTE_START_PENDING`.
`MigratableJobManagedPlacementTool` surfaces this as
`START_PENDING_PLACEMENT_HELD`: it is not treated as failure and the Job-to-Node
placement is retained.  The caller can retry the same start id or collect the
reply later; automatic release would be unsafe because execution may already
have begun.

## Time precision

v0.2.5 also fixes an ooRexx precision trap discovered while qualifying remote
lease checks. Epoch-millisecond arithmetic performed internally by the starter
and remote-start service now raises `NUMERIC DIGITS 30` before multiplying
`TIME('T')`. Fresh network CHECK request ids use a high-resolution invocation
stamp and sequence rather than rounded epoch-millisecond text.

This protocol is for initial placement only. Planned migration destination
handoff continues to use the existing migration coordinator and
`migratable.job.handoff/2` authority path.
## RPC identity versus transport metadata

`requestId` is normally the standard `startId`.  Durable replay identity binds the
client, destination node, exact Job-to-Node lease and exact standard start
request. `sentEpochMs` is transport/audit metadata and is deliberately excluded
from that semantic digest: retrying the same start later must replay, not become a
false `REQUEST_ID_CONFLICT`. A changed lease, ownership epoch, definition or start
request under the same id still fails closed.

## Epoch precision

Migratable Job stores Unix epoch milliseconds above 10^12. ooRexx's default
`NUMERIC DIGITS 9` can round such values, and `DATATYPE(value, "W")` is itself
precision-sensitive. v0.2.5 centralises epoch conversion in `MigratableJobTime`,
uses high precision in constructors and durable reloads, and validates serialized
epochs lexically as decimal integers before conversion. Qualification covers both
starter receipts and migration/provenance journal round trips.

The exact upstream Job-to-Node Allocator v0.6 currently coerces lease
`issuedEpochMs` / `expiresEpochMs` with its own default-precision `+0`. Migratable
Job does not fork that authority here; this is recorded as an upstream precision
issue for Job-to-Node. Destination lease validity is still checked authoritatively
through the local allocator or `job.node.allocator.network/0.1`.

