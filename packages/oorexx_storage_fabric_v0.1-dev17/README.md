# ooRexx Storage Fabric v0.1-dev13

Provider-neutral storage for large audio/video workloads, now with a logical namespace layer that deliberately separates **object identity**, **physical location**, **path/view**, and **write policy**.

## Implemented foundation

From v0.1-dev1:

- local, reloadable catalogue with search by name, object id, provider or locator;
- `StorageRef` identity separate from paths/provider locators;
- local filesystem metadata scanner (no file-content reads);
- capacity-domain-aware workspace pools and reservations;
- pool safety floors and best-pool allocation;
- POSIX `df -Pk` capacity probe;
- WORKSPACE / DURABLE / BOTH pool semantics;
- remote managed-node storage boundary that does not own SSH;
- Google Drive durable/catalogue provider contract with mandatory bounded-memory data plane;
- COPY -> VERIFY -> COMMIT transfer lifecycle and replica-eviction safety.

From v0.1-dev2:

- first-class extended attributes (`StorageEA`, `StorageEASet`) with namespace, type, provenance and authority fields, persisted with the catalogue and included in local search;
- logical namespaces whose paths are bindings/views over `StorageRef`, not physical locations;
- query folders: folder contents can be generated from catalogue filters, including EA predicates;
- route-specific write policies: READ_ONLY, DIRECT, COPY_ON_WRITE, TRACKED, VERSIONED, APPEND_ONLY and EPHEMERAL;
- safe query-view exclusion: removing a generated path hides that projection without destroying the underlying object;
- LIVE / TEST / DEVELOPMENT environments with different default write semantics;
- inherited namespaces: Test/Development can initially share immutable Live object refs without copying bytes;
- change-set overlays so TEST/DEV writes do not mutate their base namespace;
- generation-pinned promotion plans; a stale target generation fails preflight;
- removable-media provider with stable volume identity independent of mount path, ONLINE/OFFLINE state, intermittent availability and workspace capability only while attached;
- provider performance observations, intentionally measured rather than inferred from provider type.

From v0.1-dev3:

- TVFS-inspired ordered search-path / union views: several unrelated namespace roots can appear as one directory, searched in priority order;
- deterministic shadowing: the first layer wins a duplicate filename while lower-only names remain visible;
- fluid path aliases whose target is resolved at access time rather than copied at alias creation;
- alias-route semantics: the same target can be DIRECT through one path, TRACKED through another and READ_ONLY through a third;
- alias-loop detection which fails closed instead of recursing indefinitely;
- persistent environment generation state and persistent change-set evidence, including refs, digests, writes, unlinks and seal state;
- a small `StorageEnvironmentJournal` facade for restartable environment/change-set state.

From v0.1-dev4:

- provider-neutral `StorageByteSource` / `StorageByteSink` contracts for ranged, bounded-memory I/O;
- local file source/sink implementations that move binary data chunk-by-chunk without collecting the whole object;
- resumable `StorageResumableTransferEngine` with explicit byte offsets and restartable transfer state;
- two-slot checksummed transfer checkpoints so a torn newest checkpoint can fall back to the previous valid generation;
- source-identity fencing using canonical path, size and timestamp so stale resume evidence cannot silently attach to a changed source;
- checkpoint-before-copy safety ordering: sink flush occurs before checkpoint progress is advanced;
- cryptographic local COPY -> VERIFY support using streaming `sha256sum`, leaving COMMIT as a separate provider/catalogue decision;
- replay of a VERIFIED checkpoint without re-copying bytes;
- executable Google Drive resumable/range protocol primitives: 256 KiB non-final chunk quantum, `Content-Range` construction, server `Range` resume parsing and an 8 MiB default provider chunk recommendation.

From v0.1-dev5:

- service/account lifecycle is independent of physical-media durability: SAFE / DISPOSABLE / UNKNOWN safety and STABLE / TEMPORARY / CREDIT_LIMITED / EXPIRING / TERMINATING lifecycle states;
- disposable or non-stable service capacity may be excellent WORKSPACE while never satisfying a durable-replica requirement;
- a verified copy on disposable service capacity does not authorize eviction of the last safe durable replica;
- TERMINATING service capacity is excluded from new workspace allocation;
- storage locations persist safety, lifecycle and node-locality evidence in the catalogue;
- per-node workspace lookup preserves separate capacity domains: two 30 GiB nodes are two candidates, not a single 60 GiB workspace;
- `StoragePlacementAdvisor` reports storage feasibility and movement evidence for Job-to-Node Allocation, including local input bytes, materialisation bytes, job-package bytes and mandatory durable output export from disposable workspace;
- placement classification distinguishes JOB_TO_DATA, DATA_TO_JOB, MIXED and INFEASIBLE while explicitly leaving hard security/legal/runtime eligibility to Job-to-Node Allocation;
- durable job completion can require outputs to be committed to a safe stable provider before temporary/disposable workspace is considered releasable.

New in v0.1-dev6:

- executable Google Drive HTTP adapter for resumable session initiation, chunk PUT, provider status reconciliation, bounded Range GET and remote metadata lookup;
- short-lived authentication lease boundary, including a Secret Broker v0.2 protocol adapter; bearer credentials are injected only for the request and are removed from retained request evidence;
- resumable Drive session URIs are treated as bearer-like provider capabilities and are deliberately excluded from generic catalogue/checkpoint serialization;
- provider-authoritative resume reconciliation: before restoring a local COPYING checkpoint, a capable sink can query the provider and correct stale local progress forward or backward;
- partial remote acknowledgement is first-class: only provider-acknowledged bytes advance the checkpoint, and the source is reopened at the acknowledged offset so an unacknowledged suffix is resent;
- uncertain 5xx/transport outcomes query the Drive resumable session rather than assuming success or failure;
- bounded Drive range source and resumable Drive sink implement the provider-neutral byte source/sink contracts;
- SHA-256 verification can compare the local streamed digest with Drive's `sha256Checksum` for binary Drive content;
- COMMIT records a verified Drive location only after VERIFY, while provider lifecycle still decides whether that location counts as durable safety;
- optional `StorageApiClientHttpExecutor` bridge maps bounded Storage HTTP requests onto API Client v0.3+ without making API Client part of Storage core;
- the BashQueues Google Drive account is explicitly a disposable TEST qualification provider: useful for live destructive tests, never assumed to be a safe sole replica.

## New in v0.1-dev7

- persistent `StorageNodeInventory` separates stable node identity from provider identity, routable endpoint and block-device observations;
- current ED209 test-fleet mapping is captured as `ed209a`/`ed209b` Oracle, `ed209c` Microsoft Azure and `ed209d` AWS without treating IP address as node identity;
- `StorageDeviceObservation` records visible devices independently of workspace admission; a disk seen by `fdisk` remains `UNQUALIFIED` until an explicit storage policy admits it;
- `StorageDeviceAdmission` distinguishes UNQUALIFIED, WORKSPACE, DURABLE, BOTH and REJECTED device roles;
- node/device inventory is restart-persistent and does not manufacture free-space observations or provider safety claims;
- `StorageFleetPlacementAdvisor` emits a per-node storage-feasibility matrix across the known inventory while deliberately refusing to become Job-to-Node placement authority;
- regression proves that the Azure 1 TiB and 110 GiB observed devices do not become allocatable merely because they exist, and that unknown AWS workspace capacity is not invented;
- regression proves the two Oracle nodes remain separate capacity domains and that data already resident on `ed209a` yields JOB_TO_DATA evidence while `ed209b` yields DATA_TO_JOB evidence;
- the Azure trial node remains explicitly disposable working space: successful output still requires durable export before completion can be considered safe.


## New in v0.1-dev9 — FUSE operation core, colon streams and atomic generation snapshots

v0.1-dev9 starts the executable filesystem surface.  It does **not** yet claim a
kernel-mounted libfuse3 filesystem; instead it implements and qualifies the
filesystem operation semantics that the native FUSE callback layer must call.
This keeps the hard consistency rules in ooRexx rather than burying them in a C
mount shim.

- `StorageFuseVirtualPath` recognises reserved view selectors such as
  `mydir:frozen`, `mydir:live`, `mydir:g471` and `mydir:history` while leaving
  unknown final suffixes as application named streams (`file:1`,
  `file:thumbnail`).
- `StorageFuseOperationCore` implements FUSE-shaped `getattr`, `readdir`,
  `open`, `read`, `write`, `release`, `truncate`, `unlink`, `rename` and the
  explicit frozen-view release operation.  Results carry errno-style outcomes
  rather than pretending every logical operation succeeds.
- a file version owns a default byte stream plus independently addressable named
  streams.  Named streams are not directory entries and are frozen/versioned
  with the containing object generation.
- `StorageFuseGenerationStore` keeps open handles pinned to the version they
  opened.  A snapshot barrier advances the live path to a child generation
  without invalidating already-open handles.
- an idle requested member freezes immediately.  A member with a pre-barrier
  writer enters `DRAINING`; new opens see the new live generation while the
  existing writer remains pinned to the old snapshot generation.
- post-barrier writes from that old handle are **dual-written** into the new
  live generation.  Therefore the old writer can finish the snapshot version
  without its later writes disappearing from current live state.
- snapshot directory membership is captured at the barrier.  A file created,
  removed or renamed in the live namespace after that point does not rewrite
  the frozen membership.
- the frozen namespace is not published piecemeal.  `readdir` returns `EAGAIN`
  while any requested member is still draining, and publication occurs only
  when every requested member is frozen.
- `:frozen` is the convenient moving view; `:gN` is the immutable generation
  selector. `StorageFusePreparedSnapshotRef` deliberately hands consumers such
  as Storage Evacuation an exact `:gN` root rather than a moving alias.
- `:$status` and `:$history` are computed system streams.  Looking up
  `:release` is observational; lookup/stat/tab-completion never performs a
  destructive state transition.  In this qualification core, `rmdir
  dir:frozen` explicitly releases the synthetic snapshot pin and never removes
  the underlying live directory.

The consistency claim is **filesystem-atomic**: one frozen membership and one
set of object/stream generations.  It is not automatically an
application-consistent database checkpoint.  Application quiesce remains a
separate authority where an application requires transaction/cache semantics
stronger than filesystem ordering.

The snapshot path deliberately does not imply a full byte-for-byte copy at the
barrier.  A version may be a reference/COW overlay and materialise lazily; this
is essential for multi-gigabyte audio/video objects.

See `FUSE3_INTEGRATION.md` for the native mount boundary and current qualification
limits.

## New in v0.1-dev10 — native FUSE3 bridge candidate and soak harness

dev10 adds the first kernel-facing implementation candidate without moving Storage
authority out of ooRexx:

- `src/StorageFuseRpc.cls` defines bounded protocol `SF1` for a thin local mount
  bridge; paths and byte payloads are hex encoded so arbitrary binary content and
  colon selectors remain unambiguous;
- `bin/storage-fuse-rpcd.rex` is the resident ooRexx authority.  It was live-tested
  over ooRexx Unix Socket v0.6 / Foreign Runtime v0.22.6 with an owner-only 0600
  AF_UNIX socket;
- `native/storage_fuse3.c` maps libfuse3 callbacks to that RPC authority.  The C
  side owns callback translation only; it does not implement namespace, snapshot,
  lifecycle or policy rules;
- the adapter covers `getattr`, `readdir`, `open`, `create`, `read`, `write`,
  `release`, `mkdir`, `truncate`, `unlink`, `rename` and frozen-view `rmdir`;
- ordinary application named streams can now be created through the FUSE CREATE
  path (`file:thumbnail`) while remaining absent from normal directory listings;
- every opened data file requests FUSE `direct_io` and clears `keep_cache` for the
  first qualification line.  Kernel writeback caching and writable mmap are not
  allowed to become a second mutation authority ahead of the ooRexx generation
  engine;
- the first mount is deliberately single-threaded (`-s`).  Concurrency is a later
  qualification step, not an assumption;
- `deploy/fuse-soak.sh` continuously exercises the busy-writer generation barrier,
  post-barrier handles, exact `:gN` immutability, named streams, post-barrier
  membership exclusion and explicit frozen-pin release;
- `deploy/two-node-soak-controller.sh` can start the same indefinite soak on any
  two chosen ED209 nodes after each node has passed its local FUSE mount gate.

The local qualification container still has no real libfuse3 or `/dev/fuse`, so
dev10 does **not** claim a kernel mount here.  The complete C adapter passes strict
syntax compilation against a FUSE3 signature stub, its protocol helpers compile
and execute, and the actual ooRexx RPC daemon has been exercised over a real Unix
socket.  The next acceptance gate is a real libfuse3 build and mount on an ED209
Linux node.

## New in v0.1-dev13 — durable application bindings and common virtual-media seam

dev11 removes machine pathnames from the durable application/job contract.
Audio, video and other large-data jobs can now carry immutable `StoragePinnedRef`
/ `StorageRefSet` identities while a node-local `StorageMaterialisationLease`
contains the transient pathname needed by legacy tools such as ffmpeg.  Moving a
job between ED209 nodes therefore changes the lease binding, not the job input
identity.

New API `storage.fabric.binding/0.1` (`src/StorageBinding.cls`) provides:

- `StoragePinnedRef`: exact StorageRef + generation/digest pin; an optional
  discovery path is retained only as provenance and is excluded from durable
  identity;
- `StorageNamespacePinResolver`: resolves a friendly path exactly once at job
  submission; later alias/binding retargeting cannot mutate the submitted pin;
- `StorageRefSet`: a role-named, sealable N-object input set for jobs such as
  multi-camera/audio analysis; sealed membership cannot change after submission;
- `StorageMaterialisationLease`: the explicit boundary where node id, transient
  local pathname, verified digest and access mode live;
- `StorageMaterialisationAuthority`: provider-neutral materialisation seam which
  must return the exact pinned identity it was asked to bind;
- `StorageJobBinding`: binds one sealed input set to one execution node and exposes
  a compatibility path map only at the execution edge;
- `StorageOutputIntent`, `StorageOutputAllocator` and `StorageOutputLease`: jobs
  describe output role/media/expected size/durability rather than choosing a
  machine path.  Commit fails closed until the required SAFE replica count is
  satisfied.

The intended compatibility pattern is now:

```text
Durable job definition
    StorageRef / StorageRefSet
             |
             v
      Job-to-Node placement
             |
             v
 StorageMaterialisationLease
             |
             +-- localPath (transient compatibility only)
             +-- exact pinned identity
             +-- node / access / verification evidence
             |
             v
      ffmpeg / analyser / legacy tool
```

The same job may therefore bind `/srv/space/...` on ed209a and
`/var/lib/storage-fabric/...` on ed209c without changing its durable input
manifest.

New API `storage.fabric.virtual-media/0.1` (`src/StorageVirtualMedia.cls`) makes
the common KL10/S370 requirement explicit without importing emulator-specific
DASD semantics into Storage Fabric:

- `StorageRandomAccessByteView` adapts `StorageByteSource` to bounded
  `readAt(offset,length)` access;
- `StorageVirtualMediaDescriptor` records Storage identity, architecture/media
  metadata and lifecycle state without making provider locators authoritative;
- `StorageVirtualMediaSnapshot` distinguishes LIVE/QUIESCING/FROZEN/PUBLISHED
  virtual media and retains the presenting authority's consistency evidence;
- `StorageVirtualMediaSnapshotPolicy` distinguishes host-byte atomicity from
  guest/application consistency.  Storage may preserve bytes, but only the
  presenting emulator/application can establish its own safe quiesce boundary.

This common seam is intentionally lower-level than KL10 RPxx or IBM CKD/CCKD
semantics.  Those remain owned by their emulators; Storage Fabric owns identity,
location, transfer, verification, lifecycle and publication.

## The model

A conventional physical path such as `/srv/space/bodycam/DCIM/VIDEO/a.mp4` is a **location**. It is not the object's identity and need not be its only visible path.

One object may simultaneously appear as:

```text
/video/a.mp4
/case/123/video/a.mp4
/review/a.mp4
/search/bodycam-today/a.mp4
```

Those paths can have different semantics. For example `/X/document.txt` can be DIRECT while `/Z/document.txt` is TRACKED. A write through `/Z` is recorded in an overlay and leaves `/X` untouched.

A query folder is a view such as:

```text
/views/case42-video/
    media.type == video/quicktime
    AND EA evidence.case == CASE-42
```

No corresponding physical directory is required.

## TVFS-style search paths and fluid aliases

`StorageUnionView` deliberately borrows the useful TVFS/search-path idea: a virtual folder can search several namespace roots in a defined priority sequence without copying or reformatting their physical stores. First match wins for path resolution; directory listing merges the visible names and shadows lower duplicates.

`StoragePathAlias` is dynamic. If `/Z/document.txt` aliases `/X/document.txt`, a later DIRECT advance of X is immediately visible through Z until Z overlays it. The alias route owns its own write policy, so Z may be TRACKED while X is DIRECT.

This is a namespace composition mechanism, not a claim that Storage Fabric implements the historical TVFS.IFS interface.

## LIVE / TEST / DEVELOPMENT

The default policies are currently:

```text
LIVE         VERSIONED
TEST         COPY_ON_WRITE
DEVELOPMENT  TRACKED
```

A TEST namespace may inherit a LIVE namespace at a pinned Live generation. Until TEST changes something, both namespaces can resolve to the same immutable `StorageRef`. A TEST write creates an overlay change; Live remains unchanged. Promotion requires a sealed change set and an expected target generation, then advances the Live generation.

This is the start of environment semantics, not yet a replacement for Access Control / Permissions or Semantic Source Control. Those remain separate authorities.

## Removable media

USB disks are normal providers. Their durable identity is the configured provider/volume/filesystem identity; `/run/media/...` is merely the current mount observation. When disconnected, catalogue entries remain searchable and their location state remains OFFLINE. When connected, the provider may offer workspace capacity and observed transfer performance.

## Bounded-memory transfers

`StorageResumableTransferEngine` moves an object through source/sink adapters in fixed-size chunks. A checkpoint records the exact durable byte offset. The sink is flushed before that checkpoint is advanced, so restart evidence never intentionally claims data that has not first been flushed.

Checkpoints use two alternating files with an Adler-32 record check. If the newest slot is torn, the previous complete slot is still available. The local source identity includes canonical path, byte size and timestamp; a changed source therefore fails resume instead of silently continuing against stale evidence. Final SHA-256 verification is separate from copy completion, and `COMMITTED` remains separate again.

The default engine chunk is 8 MiB. Providers may impose their own chunk rules. Google Drive's executable protocol helper enforces the current 256 KiB multiple for non-final resumable upload chunks and supports resume-offset parsing from Drive's `Range` response header.

## Run tests with ooRexx 5.3.0 r13196

```bash
REXX_BIN=/usr/local/bin/rexx ./tests/run.sh
```

The core suite is self-contained. See `INTEGRATION.md` for authority seams into the wider ooRexx component set.

## Examples

- `examples/tom_space.rex` — probe `/srv/space` as a real capacity domain and workspace pool.
- `examples/namespace_views.rex` — Live/Test inherited refs and copy-on-write overlay behaviour.
- `examples/tvfs_union.rex` — ordered union/search-path resolution with priority shadowing.
- `examples/resumable_copy.rex` — restartable bounded-memory local copy with SHA-256 verification.

## Current deliberate boundaries

- namespace operations have an executable FUSE operation core and dev12 has now been field-qualified through a real libfuse3 `/dev/fuse` mount on ED209A; target-native qualification remains mandatory on every node;
- `StorageRef` is the namespace currency; byte movement now has a provider-neutral streaming engine, while provider-specific materialisation remains adapter work;
- environment generations and change sets are restart-persistent; whole-namespace transactional snapshot persistence is still a later increment;
- Google Drive HTTP/API Client wiring is executable and fake/provider-protocol qualified; live destructive qualification against the disposable BashQueues account remains separate;
- the local SHA-256 verifier is POSIX qualification support, not a requirement that every provider use an external command;
- access/security policy is not duplicated inside Storage Fabric.

## Next useful increments

1. live Google Drive resumable upload/range-download qualification using the disposable 15 GB BashQueues account with an authorized ooRexx credential lease;
2. remote/provider checksum verification and catalogue commit after verified transfer;
3. persistent whole-namespace snapshots / union definitions and crash-safe promotion journal;
4. provider synchronisation/freshness and removable-media discovery by stable filesystem/device identity;
5. measured transfer-time/cost estimates layered onto the implemented locality/byte-movement placement evidence;
6. promotion hooks into Semantic Source Control and Access Control without collapsing their authorities into Storage.

## New in v0.1-dev12 — FUSE is a declared foreign component

dev12 makes the native FUSE bridge consumable by Preferred Packager without
moving build/install policy into Storage Fabric.

Storage Fabric now declares `storage-fuse3` in
`foreign/storage-fuse3.json`, including its source, native API, C11/libfuse3
target requirements, build recipe, self-probe and qualification requirements.
`OOREXX_PACKAGE.json` carries the `oorexx.package/0.1` foreign declaration.

The native adapter supports `--storage-fuse-probe`, which must prove the
expected `storage.fabric.fuse.native/0.1` / `SF1` contract against the linked
libfuse runtime.  A compiled binary is not trusted merely because it exists.
Preferred Packager is expected to hash, qualify and seal the exact target
derivative before COMMIT.

Runtime startup no longer silently invokes a compiler.  A package install must
contain its qualified target derivative.  `STORAGE_FUSE_DEV_BUILD=1` remains an
explicit developer-only escape hatch for source-tree work.

`deploy/qualify-fuse-mount.sh` is now the real-kernel acceptance entrypoint.  It
requires `/dev/fuse`, mounts the filesystem and executes one complete atomic
snapshot soak cycle.  This qualification host still has no `/dev/fuse`, so the
first successful kernel mount remains an ED209 gate rather than a simulated
PASS.


## New in dev13 — peer StorageRef transfer

See `PEER_FABRIC.md`. dev13 adds `storage.fabric.peer/0.1`: HELLO/HAVE/STAT/bounded READ, verified staged remote materialisation, catalogue admission and an optional QueueRexx `bindServiceRoute()` adapter. Peer HAVE/STAT claims remain evidence only until the destination independently verifies the complete SHA-256 identity.

Authenticated transports bind the QueueRexx peer identity to the request's `from_node`; a forged node claim is rejected before Storage semantics execute. Verified peer materialisations are published only after digest equality. Their default admitted location is deliberately `DISPOSABLE` + `TEMPORARY`, so a cache copied into workspace cannot silently satisfy a durable-replica policy.

The first QueueRexx carrier hex-encodes bounded READ payloads. That is a semantic-proof carrier, not the intended high-throughput body-camera transport. `StoragePeerByteSource` is the stable seam: the carrier can later be replaced without changing StorageRef, verification or admission semantics.


## Relation/query projection (`:?`) — dev14

dev14 adds the read-only `storage.fabric.relation/0.1` capability. Structured
providers can expose a relation as a Storage namespace and accept a bounded,
provider-neutral query AST through paths such as
`/customers:?country=GB&balance>=1000`. Query membership is snapshot-bound;
FUSE is only a projection client. Mutation semantics are designed but remain
fail-closed (`EROFS`) in this release. See `RELATION_QUERY.md`.

### dev15: cards, paper and tape

`src/StorageSequentialMedia.cls` adds the provider-neutral
`storage.fabric.sequential-media/0.1` contract. It preserves fixed card records,
printed lines/page breaks, and tape blocks/filemarks and supplies strict card and
paper codecs plus adapter plans for emulator edges. This complements (rather
than replaces) `storage.fabric.virtual-media/0.1`, which remains appropriate for
random-access DASD-like images.

### dev16: Hercules card reader/punch bridge

`src/StorageHerculesSequentialMedia.cls` adds
`storage.fabric.hercules-sequential-media/0.1`, an edge adapter between the
provider-neutral `CARD_DECK` model and Hercules host card files.

Supported directions are deliberately symmetric:

- canonical ASCII 80-column deck -> Hercules 1442/2501/3505 ASCII reader file;
- Hercules 3525 ASCII punch file -> canonical 80-column deck, restoring the
  trailing blanks that Hercules intentionally removes from ASCII punch output;
- canonical EBCDIC 80-byte deck -> Hercules fixed EBCDIC reader image;
- Hercules fixed 80-byte EBCDIC punch image -> canonical EBCDIC deck.

The bridge is translation-free for EBCDIC. Storage Fabric will not guess an
ASCII/EBCDIC codepage and thereby change card contents. Translation, when
required, belongs to an explicit codepage-aware edge component.

The adapter also emits conservative 3505/3525 Hercules configuration fragments.
Paths containing whitespace are rejected rather than relying on undocumented
quoting assumptions. Over-width ASCII punch records fail closed; no implicit
`trunc` behaviour is introduced by Storage Fabric.

This is the first executable Hercules sequential-media bridge. Printer and tape
codecs remain separate follow-on adapters over the same canonical record-media
contract.


## v0.1-dev17 — Hercules paper + AWSTAPE

- Adds `StorageHerculesPrinterBridge` for 1403/3211 ASCII spool files.
  Observable lines, blank lines and form-feed page boundaries are retained as
  canonical `PAPER_LISTING` records. Hercules has already interpreted printer
  carriage-control CCWs and removed trailing blanks, so dev17 records that
  information as unrecoverable rather than inventing it.
- Adds `StorageHerculesAwsTapeCodec` for bidirectional AWSTAPE projection.
  Six-byte AWS headers remain an edge representation; canonical Storage tape
  remains blocks + filemarks. Multi-segment logical records are supported,
  including configurable segmentation up to 65535 bytes. Previous-segment
  chains, flags and truncation are validated fail-closed on ingress.
- HET compression is deliberately not guessed or reimplemented here; it
  remains a later explicit codec.