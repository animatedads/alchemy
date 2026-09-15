# ooRexx Storage Fabric v0.1-dev7

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

New in v0.1-dev7:

- executable Google Drive HTTP adapter for resumable session initiation, chunk PUT, provider status reconciliation, bounded Range GET and remote metadata lookup;
- short-lived authentication lease boundary, including a Secret Broker v0.2 protocol adapter; bearer credentials are injected only for the request and are removed from retained request evidence;
- resumable Drive session URIs are treated as bearer-like provider capabilities and are deliberately excluded from generic catalogue/checkpoint serialization;
- provider-authoritative resume reconciliation: before restoring a local COPYING checkpoint, a capable sink can query the provider and correct stale local progress forward or backward;
- partial remote acknowledgement is first-class: only provider-acknowledged bytes advance the checkpoint, and the source is reopened at the acknowledged offset so an unacknowledged suffix is resent;
- uncertain 5xx/transport outcomes query the Drive resumable session rather than assuming success or failure;
- bounded Drive range source and resumable Drive sink implement the provider-neutral byte source/sink contracts;
- SHA-256 verification can compare the local streamed digest with Drive's `sha256Checksum` for binary Drive content;
- COMMIT records a verified Drive location only after VERIFY, while provider lifecycle still decides whether that location counts as durable safety;
- optional `StorageApiClientHttpExecutor` bridge maps bounded Storage HTTP requests onto API Client v0.3 without making API Client part of Storage core;
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

- namespace operations are logical projections; this release does not expose a FUSE/OS-mounted filesystem;
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
