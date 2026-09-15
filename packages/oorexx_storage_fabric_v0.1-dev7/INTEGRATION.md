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

API Client remains appropriate for Drive control-plane work (metadata, quota, resumable-session initiation) and can also carry **individual bounded finite chunk/range requests** once wrapped by a Storage adapter. Since Storage Fabric v0.1-dev4, the data plane no longer requires the whole media body to be one API Client request: the transfer engine supplies a bounded chunk, and ranged downloads bound the response body. The current API Client v0.3 still assembles each finite request/response body, so Storage must keep those bodies to the configured chunk size rather than treating it as an unbounded stream.

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
