# Storage Fabric v0.1-dev6 integration notes

## Job-to-Node Allocation / Managed Node

Storage publishes, but does not own, placement authority. v0.1-dev6 now provides `StoragePlacementAdvisor` / `StoragePlacementEvidence` for:

- object size, AVAILABLE node-local locations and bytes already local to each candidate;
- per-node workspace pools backed by their real capacity domains and reservations;
- bytes that would have to be materialised;
- job-package movement;
- expected output size and mandatory export when the chosen workspace is disposable/non-durable;
- provider availability, safety/lifecycle state and observed performance evidence.

The allocator still decides **job-to-data vs data-to-job** only after hard node eligibility. Storage must never convert locality into permission. Separate Oracle nodes remain separate capacity domains; their free bytes are not pooled for a non-distributed job. A 40 GiB ordinary workspace therefore fits neither of two independently free 30 GiB nodes.

Service lifecycle is also independent of media durability. An Azure trial/account may expose a fast large NVMe device and still be marked DISPOSABLE/CREDIT_LIMITED. Such capacity is valid scratch/materialisation space but cannot satisfy a safe-replica requirement or make a job durably complete until required outputs have been committed elsewhere.

## Semantic Source Control v0.2.3

Storage change sets are namespace/object changes, while Semantic Source Control remains authoritative for semantic source evolution and impact analysis. A later adapter can attach SSC revision/change evidence to `StorageChangeSet` / `StorageEA` provenance and require SSC-qualified evidence for selected promotions. Storage must not copy SSC internals.

## Access Control / Permissions / Security Effect

Route write policy answers “what mutation behaviour does this namespace expose?” It is not identity/security authority. Access Control still decides whether the caller may enter the protected domain; Permissions/Security Effect decide whether the operation is authorised. A READ_ONLY route is an additional Storage constraint, never a grant of permission.

## API Client / Secret Broker / Google Drive

API Client remains appropriate for Drive control-plane work (metadata, quota, resumable-session initiation) and can also carry **individual bounded finite chunk/range requests** once wrapped by a Storage adapter. Since Storage Fabric v0.1-dev4, the data plane no longer requires the whole media body to be one API Client request: the transfer engine supplies a bounded chunk, and ranged downloads bound the response body. The API Client finite-request bridge (qualified through current v0.4.1) still assembles each finite request/response body, so Storage must keep those bodies to the configured chunk size rather than treating it as an unbounded stream.

Google Drive resumable uploads are modelled with a 256 KiB non-final chunk quantum, explicit `Content-Range`, and server-acknowledged resume offsets. Range downloads provide the corresponding bounded read side. OAuth/refresh credentials remain behind Secret Broker or equivalent authority; the catalogue/checkpoints must not persist raw credentials or bearer tokens.

The BashQueues Drive account can be treated as a disposable TEST provider for live qualification. Provider tests should deliberately exercise interruption, resume, stale metadata, duplicate names, quota exhaustion, provider-side deletion, expired resumable sessions and checksum mismatch.

## Queue Fabric

Long materialisations/offloads should become durable queue work. Storage owns transfer state and verification; Queue Fabric owns dispatch/delivery. A job blocked on an OFFLINE removable provider can later be represented as waiting on storage availability rather than failing as “file not found.”

## Audio / Video consumers

Audio and Video consume `StorageRef`/namespace paths and request materialisation/workspace. They must not encode `/srv/space`, Drive ids or USB mount points as permanent object identity.


## Namespace composition / TVFS influence

Ordered union/search-path views and dynamic aliases are internal Storage namespace semantics. They do not change Access Control, Permissions, provider ownership, or capacity accounting. A path may resolve through several candidate namespace roots while each resulting StorageRef still carries its actual replica locations and each workspace remains charged to its real capacity domain.

Environment journals persist Storage generations/change evidence only. They are not a replacement for Semantic Source Control history, institutional policy evidence, or queue durability.

## Streaming transfer / Queue Fabric boundary

A resumable transfer checkpoint is Storage evidence, not a Queue Fabric delivery record. Queue work may invoke or retry a Storage transfer, but it must reuse the same transfer identity/checkpoint rather than creating a new logical copy attempt after every worker restart. COPIED, VERIFIED and COMMITTED remain separate states.

## Streaming transfer / Job-to-Node boundary

The transfer engine gives the placement planner an executable cost consequence: if a selected node lacks an input, Storage can estimate and perform bounded materialisation. This does not change the ordering rule that hard eligibility is evaluated before locality. A planner may still prefer moving a small job to a node already holding a huge verified object rather than scheduling a large transfer.


## Google Drive / API Client / Secret Broker in dev6

Storage core owns Drive resumable-transfer state, exact acknowledged offsets, range materialisation, verification and catalogue commit. It does not own generic HTTP routing or long-lived credentials.

- `StorageGoogleDrive.cls` depends only on the small `StorageHttpExecutor` and `GoogleDriveAuthProvider` protocol seams.
- `StorageApiClientBridge.cls` is optional and requires API Client v0.3+; it maps each bounded request into an `ApiRequest` and returns the finite `ApiResponse`. The Storage chunk size bounds API Client body collection.
- `GoogleDriveSecretBrokerAuthProvider` acquires a short-lived Secret Broker lease for each request and retires it afterwards. Tokens are never part of catalogue/checkpoint/provider-performance evidence.
- A resumable session URI is also secret capability material. Generic Storage persistence deliberately excludes it. A production provider that needs restart persistence must place that capability behind provider-private secure state rather than weaken the common checkpoint format.

The connected BashQueues Drive account is qualification infrastructure. It should be registered as DISPOSABLE/TEMPORARY TEST storage even if Drive as a service can ordinarily be durable. Account intent/lifecycle is part of Storage safety.

## dev7 node-inventory seam

`StorageNodeInventory` is a storage-topology evidence source, not a replacement for the Job-to-Node allocator's capability/liveness/ownership records. Stable `nodeId` is the join key. Provider and endpoint metadata may help diagnostics and transfer planning, but endpoint reachability must not be treated as authenticated liveness. `StorageFleetPlacementAdvisor` emits one `StoragePlacementEvidence` record per known node and deliberately does not select a winner.

Visible block devices are likewise evidence only. A `StorageDeviceObservation` becomes usable only through explicit admission plus a `StoragePool` and fresh `StorageCapacityObservation`. This prevents `fdisk` discovery on a cloud VM from silently turning provider-local ephemeral or otherwise unqualified disks into safe storage.

Current test identities: `ed209a` and `ed209b` are Oracle, `ed209c` is Microsoft Azure disposable trial workspace, and `ed209d` is AWS. Their addresses are current endpoints, not stable identities.


## FUSE / Storage Evacuation boundary (dev9)

The supplied Storage Evacuation v0.1-dev8 package already has a
`EvacPreparedSnapshotProvider` whose contract consumes an already-created
stable snapshot root; snapshot creation belongs to the filesystem/platform
adapter.  Storage Fabric dev9 provides that missing filesystem-side authority.

A published Storage snapshot is handed off by exact generation selector, never
by the moving `:frozen` alias:

```text
Storage Fabric mount: /mnt/storage
snapshot base:        /db
generation:           471
prepared root:        /mnt/storage/db:g471
```

Storage Fabric owns generation barriers, handle pinning, named streams and
frozen namespace membership.  Storage Evacuation owns inventory, consistency
lease use, destination transfer, verification and evacuation/replica policy.
Neither component silently upgrades filesystem consistency to application
consistency.

The ordinary-file `/proc` in-use detection in Storage Evacuation remains useful
for files outside this managed filesystem.  Inside the ooRexx filesystem,
Storage has stronger evidence because it owns the open handles and can
separate read-only handles from actual writers.

## FUSE / POSIX / Foreign Runtime boundary (dev9)

The current ooRexx POSIX package is not duplicated.  It remains the platform
metadata/xattr gap layer.  The future libfuse3 mount adapter should be a thin
native/Foreign-Runtime bridge into `StorageFuseOperationCore`; Storage's
namespace/snapshot semantics stay in ooRexx.

The native bridge is not qualified in dev9 because the build environment has no
libfuse3 or `/dev/fuse`.  This is an explicit non-claim, not a missing semantic
design: the operation core and snapshot behaviour are executable and tested.

## Native FUSE3 / ED209 qualification integration (dev10)

Dependencies for the first real mount:

- Linux FUSE3 runtime and development headers (`pkg-config fuse3`);
- ooRexx 5.3.0 r13196 or compatible runtime;
- ooRexx Foreign Runtime v0.22.6;
- ooRexx Unix Socket v0.6;
- this Storage Fabric dev10 package.

`REXX_PATH` must make `unixsocket.cls` and Foreign Runtime's `foreign.cls`
available to `bin/storage-fuse-rpcd.rex`.  The daemon binds an owner-only Unix
socket.  `native/storage_fuse3.c` is then built with `native/build-fuse3.sh` and
mounted by `deploy/start-fuse.sh`.

Do not run the first qualification with FUSE multithreading or writeback cache.
Do not claim writable mmap consistency.  `deploy/fuse-soak.sh` is the acceptance
workload for the initial direct-I/O single-thread line.

After one node passes, choose any two ED209 SSH targets explicitly and use
`deploy/two-node-soak-controller.sh`.  The test script deliberately does not
assume Oracle, Azure or AWS semantics from hostname/provider; each node first
has to pass its own local mount and storage qualification.

## Application/job binding (`storage.fabric.binding/0.1`)

Audio/video and similar jobs should persist `StoragePinnedRef` or a sealed
`StorageRefSet`, not node-local paths.  Resolve friendly namespace names with `StorageNamespacePinResolver` before
submission, pin generation/digest, then materialise only after Job-to-Node has
selected an execution node. Later namespace retargeting changes only future
submissions, never the already-submitted pin.  `StorageMaterialisationLease~localPath` is the
compatibility escape hatch for tools that require a POSIX pathname; do not copy
it into checkpoints, job definitions or provenance identity.

Output producers should reserve through `StorageOutputIntent` and publish to a
new StorageRef only after required durable replica policy is satisfied.

## Virtual media (`storage.fabric.virtual-media/0.1`)

Emulators may adapt their neutral random-access image seam to
`StorageRandomAccessByteView`, or materialise a pinned StorageRef into local
workspace for writable/random-latency-sensitive operation.  The emulator remains
authoritative for device semantics and for the quiesce operation needed to issue
`GUEST_CONSISTENT` evidence.  Storage Fabric must never infer guest consistency
from a stable host file alone.

## Preferred Packager foreign-FUSE handoff (dev12)

Storage Fabric is a consumer of Preferred Packager.  It supplies a foreign
component declaration for `storage-fuse3`; the packager decides at target RUN
whether to reuse a supplied binary or execute the declared build recipe.

The mandatory ordering is:

```text
candidate source/derivative
  -> target probe
  -> rebuild if required
  -> hash exact derivative
  -> qualification
  -> transaction seal
  -> COMMIT
```

Storage runtime scripts never substitute for this transaction authority.
For a manual developer checkout only, `STORAGE_FUSE_DEV_BUILD=1` permits a
local unsealed build so native development can continue before packaging.

On an ED209 with kernel FUSE support, run the stronger post-build gate before
starting an indefinite soak:

```sh
deploy/qualify-fuse-mount.sh /mnt/storage
deploy/fuse-soak.sh /mnt/storage 0
```


## QueueRexx peer carrier

When a QueueRexx peer relationship already exists, `StoragePeerQueueRexxBinding` creates isolated STORAGE service routes with `bindServiceRoute()`. Storage does not create another socket or trust relationship. The server binds the route's authenticated peer node to the Storage request `from_node`; mismatches fail as `PEER_IDENTITY_MISMATCH`.

For an ED209 qualification checkout, first set the dependency `REXX_PATH` and target-compatible Foreign Runtime/Crypto bridge environment, then run:

```sh
deploy/peer-queuerexx-preflight.sh
```

That compiles both qualification helpers and proves QueueRexx's default SHA-256 digest provider is usable. A target may report the accelerated Foreign Runtime provider or the pure-ooRexx fallback; transport/application qualification decides whether the latter is acceptable for the intended workload.