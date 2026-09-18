# Storage Fabric architecture — v0.1-dev6

Storage Fabric is not a directory-tree abstraction. It is an object/catalogue/storage system with one or more filesystem-like **namespace projections**.

```text
                         StorageObject / StorageRef
                                  |
                +-----------------+------------------+
                |                                    |
          physical locations                       EAs
 local / USB / Oracle / Drive ...        metadata / provenance / policy facts
                |                                    |
                +-----------------+------------------+
                                  |
                         StorageCatalogue
                                  |
                  +---------------+---------------+
                  |                               |
             namespaces                       workspace
       paths / query folders / views       capacity domains
                  |
       +----------+----------+
       |          |          |
      LIVE       TEST       DEVELOPMENT
```

## 1. Four different concepts

Storage Fabric keeps these distinct:

```text
OBJECT    stable identity of the thing
LOCATION  where a physical replica currently exists
PATH      how a namespace/view refers to the object
POLICY    behaviour permitted through that route
```

A pathname is therefore fluid. Moving a replica does not require renaming every logical view of the object.

## 2. Extended attributes

`StorageEA` deliberately borrows the spirit of OS/2 extended attributes rather than limiting metadata to filename conventions. An EA has a namespace, name, typed value, provenance and authority.

Examples:

```text
media.duration
capture.device
evidence.case
storage.temperature
system.release
```

EAs are first-class query inputs. Future provider-specific attributes can coexist because names are namespaced.

## 3. Query folders

`StorageQueryFolder` binds a logical folder path to a `StorageFilter`. The folder's children are projections of matching catalogue objects. There is no requirement for a matching physical directory.

A generated entry can be excluded from that view. Exclusion changes the projection only. It does not delete the StorageObject or its replicas.

Path collisions are intentionally visible: if two matching objects project to the same path/name, `resolve()` reports AMBIGUOUS rather than silently choosing one.

## 4. Route-specific write behaviour

`StorageNamespaceEntry` owns a route policy. Current policy vocabulary:

```text
READ_ONLY
DIRECT
COPY_ON_WRITE
TRACKED
VERSIONED
APPEND_ONLY
EPHEMERAL
```

This permits one `StorageRef` to be exposed through several paths with different behaviour. A TRACKED/COPY_ON_WRITE write records a `StorageChangeSet`; resolving through that change set sees the new ref, while the base namespace still resolves to the original ref.

`unlink` is a namespace operation, not object destruction. Query views use exclusion. Overlay environments record an unlink in their change set. Destructive replica/object removal remains a separate operation and must retain replica-safety rules.

## 5. LIVE / TEST / DEVELOPMENT

An environment has:

```text
environmentId
kind
parentId
baseGeneration
generation
defaultWritePolicy
```

A TEST or DEVELOPMENT namespace can inherit from its parent. Inherited entries preserve the parent's StorageRef but acquire the child environment's route semantics. Thus a large immutable Live media object can be used in Test without making another physical copy.

Current defaults:

- LIVE -> VERSIONED
- TEST -> COPY_ON_WRITE
- DEVELOPMENT -> TRACKED

A `StorageChangeSet` captures route-level changes. `StoragePromotionPlan` requires a sealed change set and a pinned target generation. If Live has moved since the plan's expected generation, promotion fails rather than silently applying to a different base.

Environment generation state and change-set evidence are now persistable. Whole-namespace crash-atomic snapshot/promotion persistence is still deliberately not claimed.


## 6. Ordered search paths / union views

`StorageUnionView` is inspired by the useful TVFS/VM-style search-path idea. Each layer maps a virtual root onto a root in an existing `StorageNamespace`. Resolution searches layers in order and returns the first match. Listing merges direct children and first-layer names shadow lower duplicates.

Example:

```text
virtual /commands
    layer 1 -> namespace A:/new
    layer 2 -> namespace B:/legacy

/common.cmd -> first matching /new/common.cmd
/old.cmd    -> /legacy/old.cmd when absent from layer 1
```

The union does not copy objects and does not imply that the participating physical stores share a capacity domain. A configured write layer may route mutations into one namespace; environment COW/TRACKED semantics remain owned by that namespace.

## 7. Fluid path aliases

`StoragePathAlias` resolves its target at access time. The alias therefore follows an advanced target binding without being recreated. The alias path carries an independent route write policy. This supports the explicit case:

```text
/X/document.txt  -> DIRECT
/Z/document.txt  -> alias /X/document.txt, TRACKED
/R/document.txt  -> alias /X/document.txt, READ_ONLY
```

A TRACKED write through Z records an overlay and leaves X unchanged. Alias loops fail closed with `LINK_LOOP`.

## 8. Persistent environment evidence

`StorageEnvironment.save/load`, `StorageChangeSet.save/load`, and `StorageEnvironmentJournal` make environment generations and change evidence restartable. Change records preserve operation, path, base/new refs and digests, route policy, sequence and sealed state. This is evidence persistence, not yet a complete namespace snapshot transaction log.

## 9. Capacity domains

Physical workspace remains independent of the logical namespace. `StoragePool` roots reserve against `capacityDomainId`, not pathname. `/srv/space`, `/var`, `/opt` and `/` can all be aliases of one underlying filesystem and therefore must share reservations.

Two separate Oracle nodes with 30 GB free each are two 30 GB capacity domains, not one 60 GB workspace for an ordinary non-distributed job.

## 10. Removable media

A removable provider has stable volume identity plus transient mount state:

```text
identity    usb-provider : volume-id : filesystem-id
mount       /run/media/...    (current observation only)
state       AVAILABLE | OFFLINE
availability INTERMITTENT
```

The catalogue keeps OFFLINE locations searchable after removal. Workspace capability is available only while the device is attached.

## 11. Performance evidence

`StoragePerformanceObservation` records sequential read/write throughput and latency as observations. Storage does not hard-code assumptions such as “USB is slow” or “cloud is fast.” The planner can consume recent observations later.

Google Drive can therefore be durable and available while still carrying poor observed transfer performance; a connected USB HDD can be intermittent yet quite acceptable for large sequential media work.

## 12. Placement boundary

Storage owns object location/capacity/performance facts. Job-to-Node Allocation owns execution eligibility and ranking. The integration should allow the planner to compare:

- move the data to the chosen job node;
- move the job to a node already holding the data;
- wait for an intermittent provider;
- choose another verified replica.

Hard security/legal/runtime eligibility remains above locality optimisation.

## 13. Bounded-memory transfer plane

The data plane is now expressed as two provider-neutral contracts:

```text
StorageByteSource
    sizeBytes
    resumeIdentity
    openAt(offset)
    readChunk(maxBytes)
    close

StorageByteSink
    resumeIdentity
    openAt(offset,totalBytes)
    writeChunk(bytes)
    flush
    close
```

`StorageResumableTransferEngine` never requests more than its configured chunk size from a source. It persists the exact transferred byte count and can reopen both ends at that offset after restart. This is equally applicable to local files, USB disks, ranged HTTP downloads, resumable cloud uploads and remote-node adapters.

Transfer evidence is deliberately ordered:

```text
read chunk
    -> write chunk
    -> flush sink
    -> advance StorageTransfer bytes
    -> persist checkpoint generation
```

Thus the checkpoint does not intentionally get ahead of the sink's flushed state. A physical sink may be ahead of the checkpoint after a crash; resume from the older checkpoint is safe because subsequent writes overwrite the suffix from the trusted byte offset.

The checkpoint journal alternates two checksummed slots. A torn newest slot does not destroy the previous complete checkpoint. Source resume identity fences stale evidence; local identity currently includes canonical path, size and timestamp. Final cryptographic verification remains a distinct state transition from COPIED, and COMMITTED remains a distinct provider/catalogue transition from VERIFIED.

## 14. Google Drive transfer protocol seam

Drive is still treated as durable/offload rather than preferred workspace. The provider now publishes resumable-upload and range-download capability plus executable protocol helpers. Non-final resumable upload chunks must be multiples of 256 KiB; the current Storage recommendation is 8 MiB. Upload continuation uses `Content-Range`, and a 308 response's `Range` header determines the acknowledged next byte rather than assuming the entire request was received. Partial downloads can be requested with byte ranges.

This is intentionally compatible with bounded finite HTTP requests: an HTTP adapter may hold one Storage chunk plus its small response in memory without ever collecting a multi-gigabyte media object. OAuth authority remains outside Storage and raw credentials must not enter the catalogue or transfer journal.



## 15. Service lifecycle is part of storage safety

A physical disk can be reliable while the account, VM, trial, tenancy or service containing it is intentionally temporary. Storage Fabric therefore does not derive durability from media type, apparent persistence or provider marketing. `StorageServiceLifecycle` records a safety class and lifecycle state independently of pool mode and performance.

```text
physical capability      service/account lifecycle      effective use
-------------------      -------------------------      -------------
fast 1 TiB NVMe          CREDIT_LIMITED + DISPOSABLE    WORKSPACE yes
                                                    -> durable safety no
```

`StoragePool~canDurable` means that the underlying pool can physically retain objects. `StoragePool~countsAsDurable` is stronger: the pool must also be SAFE and STABLE. A verified location counts as a durable replica only while it is AVAILABLE, VERIFIED, SAFE and STABLE. A disposable copy is useful evidence/materialisation but never makes deletion of the last safe replica permissible.

`TERMINATING` service capacity is not admissible for new workspace allocations. Earlier states such as CREDIT_LIMITED may remain useful for bounded work, but planner policy can include the expected service horizon and must export required durable results before completion.

This is the Azure-trial doctrine generalized: **fast/large/online is not the same property as safe**.

## 16. Storage-locality placement evidence

Storage Fabric does not choose the execution node. It publishes storage feasibility and movement facts to Job-to-Node Allocation. `StoragePlacementAdvisor` evaluates a candidate node only after, or independently from, the allocator's hard eligibility decision.

For each candidate it reports:

- whether one real workspace pool on that node can satisfy the requested reservation;
- total input bytes and how many are already AVAILABLE on that node;
- bytes that must be materialised;
- job-package bytes;
- expected output bytes;
- mandatory output-commit bytes when the selected workspace does not count as durable;
- total storage-related movement bytes;
- a descriptive action: JOB_TO_DATA, DATA_TO_JOB, MIXED or INFEASIBLE.

Capacity remains local to its real domain. Two Oracle nodes with 30 GiB free each are two independent 30 GiB candidates; a normal 40 GiB workspace fits neither. Explicitly distributed/chunkable execution would require a separate higher-level contract and is never inferred by summing node free space.

Locality is an optimization, not authority. A node containing the only local copy is still ineligible if Job-to-Node rejects it on security, legal, access, runtime, hardware or other hard requirements. Conversely, if a large input is already on an eligible node, moving a small job package to the data is normally much cheaper than moving the media to the job. Output movement is included because a job that reads little but produces a large result may reverse that conclusion.


## Provider-authoritative resume and capability secrecy (v0.1-dev6)

A local transfer checkpoint is durable Storage evidence, but it is not always the final authority on a remote provider's received byte offset. A resumable sink may implement `reconcileResume(checkpointOffset)`. Before reconstructing a COPYING transfer, the engine asks that sink for provider evidence and may move the restart offset forward or backward to the provider-acknowledged position. This is essential after torn local checkpoints, ambiguous transport failures, or partial provider acceptance.

The checkpoint advances only the number of bytes acknowledged by the sink. If Drive acknowledges only a prefix of a chunk, Storage reopens the source at the acknowledged offset and resends the suffix. It never silently skips bytes merely because they were placed on the wire.

Google Drive resumable session URIs are capability-bearing secrets. They are provider-private operational state, not object identity, and must not be persisted in generic `StorageRef`, catalogue records, transfer checkpoints, planner evidence or logs. Production restart persistence for such capabilities belongs behind a secure provider-private authority. The in-memory session store in dev6 is a qualification fixture, not a durability claim.

Authentication follows the same principle. `GoogleDriveAuthProvider` supplies a short-lived lease; the HTTP adapter uses the bearer token only for the outbound request, removes Authorization from retained request evidence, and retires the lease. `GoogleDriveSecretBrokerAuthProvider` is the protocol seam into Secret Broker v0.2.

## Google Drive data-plane adapter (v0.1-dev6)

`GoogleDriveApiAdapter` starts resumable sessions, sends bounded upload chunks, asks a session for authoritative status after ambiguous transport/5xx outcomes, performs bounded byte-range downloads, and fetches file metadata. `GoogleDriveRangeByteSource` and `GoogleDriveResumableByteSink` project those operations onto the provider-neutral streaming contracts. Final upload metadata can expose `sha256Checksum`; `GoogleDriveSha256Verifier` compares that provider evidence against a local streamed SHA-256 digest before `GoogleDriveStorageCommitter` admits the location and advances transfer state to COMMITTED.

The HTTP transport itself remains an authority seam. `StorageApiClientBridge.cls` is optional and maps finite bounded Storage requests onto API Client v0.3+; dev9 regression also passes against current v0.4.1. Storage therefore does not duplicate API Client's outbound routing/transport authority, and API Client does not become responsible for resumable-transfer semantics.

## Node inventory is topology evidence, not placement authority (dev7)

Storage Fabric now keeps node identity, provider identity, endpoint, observed devices and admitted capacity as different facts. `ed209c` does not become “52.146.17.8”; the IP address is a current endpoint observation for stable node identity `ed209c`. Likewise, `fdisk` observing `/dev/nvme0n2` at 1 TiB is not evidence that Storage may allocate it. The device remains `UNQUALIFIED` until policy/qualification creates an admitted workspace/durable role and a real capacity-domain observation.

The current ED209 test topology is intentionally heterogeneous:

```text
ed209a  Oracle      193.123.184.140
ed209b  Oracle      193.123.190.35
ed209c  Microsoft   52.146.17.8       disposable trial service
ed209d  AWS         16.170.244.216
```

The inventory can remember devices and endpoints while they are unusable. This mirrors the removable-media rule: knowledge is not availability, and presence is not admission. `StorageFleetPlacementAdvisor` therefore produces a matrix of storage facts only. It may say that `ed209a` has the data locally, `ed209b` needs materialisation, `ed209c` requires durable output export, and `ed209d` has no admitted workspace observation. Job-to-Node still evaluates hard eligibility and owns the final lease/ranking decision.

The safety invariant is deliberately conservative: unknown capacity is zero for planning, unqualified devices are not pools, separate nodes are not aggregated into one filesystem, and disposable service capacity never satisfies durable-replica safety.


## 17. FUSE filesystem surface and colon selectors (dev9)

The filesystem surface treats a path as a query over object generation, view
and stream, not merely as an underlying physical pathname.  A reserved colon
suffix on a directory component selects a Storage view:

```text
/project                 current live namespace
/project:live            explicit live view
/project:frozen          current acquired frozen generation
/project:g471            immutable generation 471
/project:history         historical generation directory
```

A non-reserved colon suffix on the final file component selects an application
named stream.  Thus `doc:thumbnail` and `doc:1` can contain bytes unrelated to
the default `doc` stream while remaining part of the same versioned object.
System-owned streams use `$`, initially `:$status` and `:$history`.

Colon parsing is deliberately performed by Storage before provider pathname
resolution.  A provider is therefore never asked to find a physical path named
`project:frozen`.

### Atomic N-file snapshot barrier

A snapshot request captures the exact member set first.  For every requested
file, Storage advances the live binding from generation S to a COW child in
S+1.  The generation-S version is the prospective snapshot member.

```text
                   barrier
                     |
        +------------+-------------+
        |                          |
   no old writer               old writer exists
        |                          |
   freeze S now                S = DRAINING
        |                          |
 live path -> S+1             live path -> S+1
                                   |
                           old handle remains on S
                           writes mirror to S+1
                                   |
                           final old writer closes
                                   |
                              freeze S
```

The dual-write rule is important.  Simply pinning an old writer to S and moving
the pathname to S+1 would lose the writer's post-barrier updates from current
live state.  Mirroring those writes into S+1 preserves normal live semantics
while still allowing S to close as an immutable historical generation.  New
post-barrier writers touch S+1 only and therefore never contaminate S.

The snapshot remains private while any member is DRAINING.  There is no
partially visible snapshot.  Only when every member is FROZEN does the state
become PUBLISHED and the directory membership become readable.

Read-only handles do not prevent freezing because Storage owns handle mode and
can prove they cannot change bytes.  Writable mmap handling is not yet claimed
by dev9; a native adapter must either account for writable mappings as writers
or fail the stronger snapshot request closed.

### Namespace atomicity

The barrier captures directory/query membership as well as byte-stream
versions.  Creates, unlinks and renames after the barrier are live-generation
mutations.  They do not appear retroactively in the frozen membership.
Application named streams freeze with their owning object version.

### Stable handoff

`:frozen` is intentionally convenient but may later point at a newer acquired
snapshot.  A downstream consistency lease therefore receives `:gN`.  For a
mount rooted at `/mnt/storage`, a prepared database snapshot can be handed to a
consumer as, for example:

```text
/mnt/storage/db:g471
```

This is the direct seam to Storage Evacuation's prepared-snapshot provider.
The filesystem supplies the immutable namespace generation; Storage Evacuation
retains transfer/verification/replication authority.

### Side-effect safety

Path lookup is not a general command interpreter.  `stat`, shell completion and
indexers issue lookups speculatively.  Therefore `:release` lookup is
observational.  State-changing actions require a mutation operation.  dev9 uses
`rmdir dir:frozen` as the explicit release of a synthetic snapshot pin; it
never means removal of the underlying live directory.

## 18. Native FUSE3 boundary

`StorageFuseOperationCore` is the ooRexx semantic authority behind future
libfuse3 callbacks.  The native adapter should be mechanically thin:
`getattr/readdir/open/read/write/release/truncate/unlink/rename/rmdir` map to
operation-core methods and preserve the returned handle token as FUSE `fh`.

The dev9 qualification environment does not provide `/dev/fuse`, `fusermount3`
or libfuse3 development/runtime libraries, so no kernel mount is claimed.
Current `oorexx_posix_v0.1-dev1` supplies useful POSIX metadata/xattr gaps but is
not a FUSE server implementation.  Foreign Runtime v0.22.6 has synchronous
callback support and is a candidate bridge mechanism, but its callback/thread
policy must be reconciled with FUSE dispatch before a multithreaded mount can be
claimed.

A pending frozen generation must never block the only FUSE dispatcher waiting
for a writer-close callback that the same dispatcher needs to process.  The
operation core therefore represents this state explicitly (`EAGAIN`) instead
of hiding an unsafe blocking wait.  A native adapter can later provide a safe
multi-request dispatcher without changing the snapshot semantics.

## dev10 native FUSE authority split

The first native mount uses a local RPC boundary rather than allowing libfuse
callbacks to acquire Storage authority.  This also avoids violating Foreign
Runtime v0.22.6's accepted callback-thread rule: arbitrary libfuse worker
threads do not callback into ooRexx.  The native shim connects to a resident
single-authority ooRexx daemon instead.

```text
libfuse callback thread
        |
        | bounded SF1 request
        v
owner-only Unix socket
        |
        v
resident ooRexx StorageFuseOperationCore
```

The initial mount itself is additionally forced single-threaded.  The RPC split
is nevertheless retained because it gives a clean future concurrency boundary
and makes crash/restart behavior observable rather than re-entrant.

### Mutation authority and page cache

`direct_io` is part of the first qualification contract.  A filesystem whose
snapshot proof depends on observing handle/write/release order cannot silently
allow a second writeback authority to reorder or retain mutations outside that
model.  Writable mmap is therefore explicitly outside the dev10 claim.

### Continuous qualification

The intended qualification sequence is:

1. one ED209 node: real libfuse3 build and mount;
2. finite soak (for example 100 iterations);
3. indefinite soak;
4. second ED209 node: repeat locally;
5. both nodes running indefinite independent soak simultaneously;
6. only after this baseline is stable, add multithreaded dispatch, cache modes,
   remote/provider-backed bytes and cross-node placement/evacuation scenarios.

## v0.1-dev13: application identity/binding boundary

Long-lived job definitions must not preserve machine-specific pathnames as data
identity.  The durable contract is an exact StorageRef/generation (or a sealed
role-named StorageRefSet).  A materialisation path is an execution-time lease
property and is disposable when that lease ends.

```text
StoragePinnedRef / StorageRefSet        durable identity
             |
             v
StorageMaterialisationAuthority        provider/node binding
             |
             v
StorageMaterialisationLease            transient localPath
             |
             v
legacy pathname consumer
```

This permits audio/video jobs to move between ED209 nodes without editing job
source or checkpoint state.  Friendly namespace paths remain valid discovery
interfaces. `StorageNamespacePinResolver` resolves them exactly once at
submission to immutable object/generation pins, so later namespace retargeting
cannot silently change a running or resumed job; only a later submission sees
the new target.

Outputs use the inverse boundary: applications state role, media type, expected
size and durability; Storage reserves a workspace path and turns successful
COPY -> VERIFY -> COMMIT publication into a new StorageRef.  The working path is
never the result identity.

## v0.1-dev13: generic virtual-media compatibility

KL10 and S/370 independently require the same Storage-side primitive: exact
object identity plus bounded random byte access, with writable media materialised
or overlaid under the emulator's own device semantics.  Storage therefore exposes
a generic virtual-media contract rather than learning any RP/CKD/CCKD format.

The presenting system owns semantic consistency.  `HOST_BYTES_ATOMIC` means the
Storage-visible bytes are a stable generation; it does not prove that a guest
DASD was between channel programs or that an application flushed its own state.
A caller requiring guest/application consistency must receive explicit evidence
from the presenting authority before that snapshot is admitted as such.

## v0.1-dev13: foreign FUSE derivative authority

Storage Fabric describes its FUSE foreign component; it does not own target
installation policy.  The detailed descriptor is
`foreign/storage-fuse3.json` and the Preferred Packager projection is carried
by `OOREXX_PACKAGE.json`.

The source/API identity is stable across nodes while compiled derivatives are
allowed to differ by target.  A derivative becomes admissible only after:

```text
build/reuse -> hash -> probe -> qualify -> seal -> COMMIT
```

The target binary's hash is therefore evidence about one qualified derivative,
not the portable identity of Storage Fabric itself.

Runtime activation never silently rebuilds a missing derivative.  This keeps
software-install authority out of the filesystem daemon and native callback
process.


## Peer object fabric

`StoragePeerByteSource` projects a remote Storage node into the existing bounded byte-source contract. The semantic authority is StorageRef + independently verified digest; QueueRexx/Queue Fabric is only the initial carrier. A peer's HAVE/STAT response is evidence, never replica admission authority.

The first admission pipeline is:

```text
peer claim -> bounded READ -> sibling staging file -> complete SHA-256
          -> publish verified target -> catalogue StorageLocation
```

The default admitted peer-cache location is `DISPOSABLE` / `TEMPORARY`; callers must explicitly choose stronger safety/lifecycle classes for an actually durable target. Existing targets are never overwritten by peer transfer authority.

QueueRexx service routes use the dedicated `STORAGE` security domain and bind the authenticated QueueRexx peer identity to `from_node`; the payload is not allowed to invent its transport identity. See `PEER_FABRIC.md`.


## Storage Relation / query projection

`StorageRelationProvider` is the structured-source seam for PostgreSQL-like,
NoSQL, ooRexx-object, EDI and other relation-capable providers. Queries are
provider-neutral ASTs and may be pushed down only through declared capability.
FUSE `:?` is one projection of this seam. Query membership and row versions
bind to Storage Fabric snapshot/generation authority; relation code does not
invent a competing snapshot subsystem. The dev14 executable surface is
read-only; the R/W contract is documented in `RELATION_QUERY.md`.

## Sequential and physical media (dev15)

Storage Fabric now distinguishes byte-addressable virtual media from sequential
record media.  `storage.fabric.sequential-media/0.1` represents cards, printed
listings and tape as ordered logical records and boundaries rather than flattening
them into anonymous bytes.

Canonical families are:

- `CARD_DECK`: fixed-width card records (normally 80 columns for IBM/Hercules).
- `PAPER_LISTING`: printed lines plus explicit page boundaries.
- `TAPE_VOLUME`: variable data blocks plus explicit filemarks.

External emulator formats are adapter concerns.  A Hercules adapter may render a
card deck as ASCII lines or 80-byte EBCDIC records, a listing as ASCII/form-feed,
or a tape volume as AWSTAPE/HET.  Storage retains record identity/order and
provenance; Hercules retains device/channel semantics.  This makes the boundary
bidirectional: reader/tape input is materialised from Storage, while punch,
printer and tape output is ingested as new Storage media objects.

The model deliberately does not place MVS datasets, JES classes, VTOCs, JCL or
tape-label semantics in Storage Fabric.  Those belong to guest/device-aware
layers above the canonical media contract.