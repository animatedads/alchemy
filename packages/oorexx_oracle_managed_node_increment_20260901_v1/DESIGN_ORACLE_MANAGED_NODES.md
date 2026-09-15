# Oracle Managed Nodes — first implementation increment

## Purpose

Turn two already-running Oracle compute nodes into general allocator-selected managed execution nodes without reviving network-transparent Remote Rexx Objects and without duplicating existing authorities.

The node is an execution authority, not a placement authority.

## Existing authority boundaries retained

- Job-to-Node Allocator v0.6: hard eligibility, ranking, ownership epoch and placement lease.
- WLU: resource admission/reservation and settlement.
- Queue Fabric: durable prioritized delivery, claim/ACK/NACK and recovery.
- API Client: outbound API route/session selection and reservation.
- Secret Broker: secret references and short-lived secret leases; secret material is not a Work Bundle field.
- Observation v0.5: later read-only operational projections/replay.
- Semantic Source Control: source provenance reference carried by Work Bundle manifests.

## Durable node lifecycle

Colab managed-compute lifecycle is retained but adapted from ephemeral VM allocation to a slot on an existing node:

validate -> allocate eligible node -> reserve/admit -> dispatch -> verify -> isolated stage -> execute -> result/evidence -> clean -> release/settle

For a long-running service, execute/finish is not sufficient. SERVICE is deliberately reserved for a later desired-state reconciler.

## Three independent proofs

1. Placement lease: allocator says this job may execute on this node under this capability/capacity/policy/ownership epoch.
2. ManagedTaskAuthorization: execution authority signs the exact task specification and Work Bundle digest against the exact placement ID and ownership epoch.
3. Work Bundle producer proof: producer attests immutable manifest/content/provenance.

A valid Work Bundle is not execution authority. A valid placement does not authorize an arbitrary payload. A task authorization cannot move to another placement or ownership epoch.

## Work Bundle v0.1-dev1

An immutable bundle declares:

- bundle/producer/key identity;
- source provenance reference;
- creation/expiry;
- exact relative file set and SHA-256 digests;
- declared entrypoints;
- permitted task kinds;
- required logical runtimes;
- producer signature.

`WorkBundleRef` is the small control-plane identity. `WorkBundleRepository` is the retrieval seam. dev1 provides an in-memory repository only; HTTPS/artifact retrieval is the next transport increment.

Production signing adapter: Ed25519 through ooRexx Crypto. Test-only fake proof authorities are confined to qualification source.

## Managed Node v0.1-dev1

Implemented finite task identities:

- COMMAND
- TEST
- COMPUTE
- FETCH (identity only, runner deliberately absent)
- SERVICE (identity only, reconciler deliberately absent)

The normal finite runner receives a logical allowlisted runtime, declared bundle entrypoint, argv array, working directory, timeout and output limit. It does not receive an arbitrary remote shell command contract.

Current priority constants are:

- BACKGROUND = 10
- NORMAL = 50
- INTERACTIVE = 100
- CONTROL = 1000

These feed Queue Fabric. They do not alter allocator eligibility or WLU admission.

## Queue persistence seam

`JobNodeQueueFabricDispatcher` already accepts a queue-neutral envelope and Queue Fabric options, so no allocator modification is needed for INTERACTIVE priority.

Queue Fabric permanent payloads require the Queue Graph persistence contract. Allocator v0.6's `JobNodeDispatchEnvelope` is intentionally queue-neutral and does not implement that contract. dev1 therefore adds `ManagedNodeDispatchEnvelope`, a persistable sibling exposing the same dispatcher-facing getters and preserving the complete `JobNodePlacementLease` during flatten/recovery. This avoids an incompatible allocator branch.

## Result/attempt semantics

The attempt identity is bound to placement ID + ownership epoch + task ID. Destination-side monotonic fencing rejects an older ownership epoch once a newer one is observed.

The agent ACKs work only after the structured result is successfully published. An in-process attempt cache prevents execution from repeating when result publication fails and Queue Fabric redelivers the task. A durable on-node attempt journal is still required to preserve this guarantee across agent process or host restart.

## Fail-closed personality boundaries

FETCH is not implemented as curl or generic shell execution. It will become a `ManagedFetchRunner` that delegates outbound route/session authority to API Client.

SERVICE is not implemented as `start-server.sh`. It will become a desired-state `ManagedServiceSupervisor` with lease/reconciliation, health/readiness and Runtime Registry integration.

Qualification proves both validly placed/authorized task kinds are rejected before the generic executor is invoked.

## Next increment

The next useful increment should be transport and control rather than adding more local command features:

1. Managed Node Gateway over HTTPS/TLS, with the Oracle node initiating the connection and server-derived node -> fixed Queue Fabric queue binding.
2. HTTPS WorkBundleRepository, immutable retrieval by ref/digest.
3. Durable node-side attempt journal and restart recovery.
4. CONTROL-priority CANCEL/DRAIN requests bound to exact placement/ownership epoch/attempt identity.
5. Observation adapter for task/node status and replay.
6. ManagedFetchRunner backed by API Client.
7. ManagedServiceSupervisor desired-state reconciliation.

At that point the ooRexx-facing controller can expose local durable handle objects (`task~status`, `task~cancel`, `task~result`, `service~status`) without pretending the remote process/service is a transparent local object.
