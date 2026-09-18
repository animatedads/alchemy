# Storage Fabric peer object protocol — dev13

API: `storage.fabric.peer/0.1`

This cut introduces the smallest peer semantic required to make independently
qualified Storage nodes exchange one immutable Storage object without making
physical paths part of identity.

Operations are `HELLO`, `HAVE`, `STAT`, and bounded `READ`.

A peer's `HAVE=AVAILABLE` or `STAT` response is **evidence, not admission
authority**.  The receiving node may admit a replica/location only after the
complete bytes have been independently SHA-256 verified against the pinned
`StorageRef`.  Failed verification removes the staging file and no Storage
location is admitted.

`StoragePeerByteSource` turns a remote peer into the existing
`StorageByteSource` abstraction.  Higher Storage code therefore does not need
to know whether bytes are local, Google Drive backed, removable, or remote.

## Identity and trust boundary

The object identity carried on the wire is:

```text
StorageRef(objectId, digest)
```

Provider locators and peer-local paths are never identity.

A network carrier must bind authenticated transport identity to Storage's
`from_node`.  The QueueRexx adapter therefore calls
`StoragePeerService~handleFrom(authenticatedPeerNodeId, request)`; a payload
claiming another node fails `PEER_IDENTITY_MISMATCH` before the Storage
operation runs.

QueueRexx's normal digest provider is used for its own replay/integrity ledger.
The qualification helpers do not substitute a weak Storage-specific digest.
Where the target has a qualified Foreign Runtime/Crypto bridge the ordinary
QueueRexx provider may accelerate transparently; otherwise QueueRexx retains
its own fallback policy.

## Verified materialisation and admission

Peer materialisation deliberately separates transfer from catalogue admission:

```text
bounded READ
    -> sibling staging file
    -> complete independent SHA-256
    -> publish verified target
    -> optional StoragePeerReplicaAdmission
```

The peer transfer refuses to overwrite an existing target.  The surrounding
Storage materialisation/workspace lease is the single-writer path authority.

`StoragePeerReplicaAdmission` accepts only a `VERIFIED` materialisation whose
calculated digest equals the pinned StorageRef.  Its default StorageLocation is
classified:

```text
safety     DISPOSABLE
lifecycle  TEMPORARY
verified   true
```

so a verified workspace/cache copy does **not** silently count as a durable
replica.  A caller may select `SAFE` / `STABLE` only when the actual target and
provider policy justify those stronger claims.

## Initial QueueRexx carrier

The first wire carrier is QueueRexx's service-neutral peer route over Queue
Fabric `queue.transport/2`.  `StoragePeerQueueRexxBinding` calls
`QueueRexxPeerMeshRuntime~bindServiceRoute()` and uses a dedicated `STORAGE`
security domain.  Storage does not create a second peer socket/trust
relationship and does not fork Queue Fabric transport.

The QueueRexx adapter is optional and duck-typed: merely loading Storage Fabric
does not load QueueRexx/Queue Fabric.

The first protocol hex-encodes READ payload bytes.  That is bounded and
binary-safe but deliberately **not** the final bulk-media carrier.  A future
high-throughput carrier may replace the transport beneath
`StoragePeerByteSource` without changing StorageRef, verification, checkpoint,
or admission semantics.

## Two-node qualification

The complete first A/B proof is intentionally small:

1. A publishes immutable object X under exact StorageRef/digest.
2. Before transfer, B has no admitted location for X.
3. B requests X from A through bounded peer READ operations.
4. B stages the bytes outside the final target name.
5. B computes SHA-256 itself and publishes the target only after equality.
6. B admits its verified location; a temporary cache remains non-durable.
7. A and B may use unrelated physical paths; StorageRef X remains identical.
8. B then serves that same exact StorageRef.
9. Remove A's disposable local materialisation.
10. Materialise X back from B to A and independently verify the same digest.

At no point does a peer's path or provider locator become object identity.

## ED209 qualification helpers

`deploy/peer-queuerexx-preflight.sh` validates that the current checkout and
external QueueRexx/Queue Fabric/Crypto dependency path can load together and
compiles the two live helper programs.

`bin/storage-peer-queuerexx-server.rex` and
`bin/storage-peer-queuerexx-client.rex` construct an explicit QueueRexx peer
endpoint for bounded two-node qualification.  They are qualification helpers,
not topology authority.  Production integration should bind the same
`StoragePeerQueueRexxBinding` service to the resident QueueRexx peer mesh.

The recommended first ED209 proof is A server -> B verified materialisation,
then reverse the roles and materialise the exact object B -> A.  Both
directions must independently hash completed bytes.  The live proof is not
complete merely because QueueRexx says the peer is healthy or because a READ
request returned bytes.

## Qualification boundary of this package build

The transport-neutral protocol, materialiser, digest failure, target
non-clobber, catalogue admission, and QueueRexx route adapter are exercised in
the core regression suite.

A local two-process encrypted QueueRexx socket run was attempted on the package
build host.  The existing upstream QueueRexx encrypted peer socket regression
also exceeded the same outer execution bound there, so dev13 does **not** claim
a live QueueRexx Storage transfer from that host.  The live two-node carrier
acceptance is an ED209A/ED209B field gate, where target-compatible Foreign
Runtime/Crypto acceleration and the already-qualified QueueRexx peer estate are
available.