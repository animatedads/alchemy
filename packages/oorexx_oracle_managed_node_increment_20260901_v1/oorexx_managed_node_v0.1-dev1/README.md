# ooRexx Managed Node v0.1-dev1

First durable-node execution slice for allocator-selected Oracle-style always-on nodes.

It adds no new placement, WLU, API-egress or Queue authority. The node receives an allocator lease through `JobNodeQueueFabricDispatcher`, verifies lease proof/freshness/node binding, enforces a destination-side ownership/renewal fence, verifies a second exact `ManagedTaskAuthorization` binding placement + ownership epoch + task digest + Work Bundle digest, verifies the immutable Work Bundle, stages into an isolated root, invokes an allowlisted runtime with an argv array, captures bounded stdout/stderr, cleans the root, publishes a structured result, and ACKs only after result publication.

`ManagedNodeDispatchEnvelope` is a queue-persistable sibling of the allocator's queue-neutral dispatch envelope. This deliberately avoids changing Job-to-Node Allocator v0.6 while making permanent Queue Fabric dispatch possible. Queue type factories must be registered with `ManagedNodeQueueTypes~register(codec)` before constructing/recovering a durable queue manager.

## dev1 scope

Implemented: COMMAND/TEST/COMPUTE/FETCH/SERVICE task identities, exact execution authorization, priority constants, Work Bundle retrieval seam, allowlisted runtime command execution, timeout/output bounds, attempt result cache, permanent Queue Fabric payload persistence and result persistence.

Executed in dev1 acceptance: TEST through exact ooRexx 5.3.0 r13196.

Not yet implemented: network/TLS Managed Node Gateway, HTTPS Work Bundle repository, durable on-node attempt journal across process restart, cancellation/control queue, Secret Broker injection, API Client fetch runner, service reconciliation, and Observation v0.5 projection. Those remain separate increments rather than being faked through shell commands.

## Dependencies / qualification

Qualified with Job-to-Node Allocator v0.6, Queue Fabric v0.9-dev4, Alchemy Objects v0.8, Work Bundle v0.1-dev1 and Crypto v0.8.3 on ooRexx 5.3.0 r13196 Internal Test Version.

`tests/run.sh` proves:

- allocator-owned placement and exact runtime requirement;
- BACKGROUND queued first, later INTERACTIVE claimed first by Queue Fabric;
- permanent dispatch recovery after queue-manager restart before execution;
- exact signed task authorization binding job/placement/ownership epoch/task/bundle;
- immutable bundle verification and isolated staging;
- real ooRexx execution and structured persistent result recovery;
- destination ownership-epoch fencing;
- result-delivery retry does not re-execute the task in-process;
- FETCH and SERVICE fail closed and never reach the generic command executor.
