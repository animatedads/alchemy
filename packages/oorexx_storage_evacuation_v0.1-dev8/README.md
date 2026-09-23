# ooRexx Storage Evacuation v0.1-dev3

A generational live-filesystem evacuation and replication authority layered above Storage Fabric.  The package is designed for a source filesystem which remains live while bulk evacuation occurs and is later quiesced for final convergence.

Correctness is transport-independent.  A transfer command returning success is not sufficient evidence of preservation.  A replica becomes current only after destination verification and a source-generation fence succeeds.

## dev3

- Durable line-oriented manifest persistence with atomic replace and round-trip recovery of object, metadata, digest and replica state.
- Nanosecond-resolution source generation fencing using GNU `stat` modification/change timestamps, closing the same-second equal-size rewrite race found during qualification.
- Local metadata materialisation for directories and symlinks.
- Hard-link reconstruction and verification by destination device+inode identity, rather than merely comparing bytes.
- Mode, uid/gid and mtime reconstruction with independent destination re-probe.
- ACL/xattr capture remains optional and fail-explicit.  When `getfacl/getfattr` capture evidence and matching `setfacl/setfattr` are available, dev3 restores and re-reads that evidence; absence is represented rather than guessed.
- Unsupported special filesystem object types fail closed.
- Verified replica evidence can be carried into a subsequent generation only when source identity is unchanged.
- `sealStablePair(previous,current)` requires two equivalent inventories and zero outstanding/error/dirty objects before sealing the current generation.

## State distinction

`TRANSFERRED`, `VERIFIED`, `VERIFIED_OLD_GENERATION`, and `VERIFIED_CURRENT` remain deliberately distinct.  A source changed after a correctly verified copy leaves a valid historical replica but does not satisfy convergence for the live source.

## Architectural boundary

Evacuation owns inventory, generations, convergence, replica authority and sealing. Storage Fabric owns byte-source/sink, resumable transfer, provider interaction and content verification. QueueRexx will own scheduling, retries, WLU/concurrency and restartable work dispatch. Network/local/USB/cloud implementations are transports/endpoints underneath those authorities.

## Current boundary

The local filesystem endpoint is the executable qualification endpoint in dev3. Azure/network endpoints, QueueRexx work-unit binding and the shared bandwidth governor are intentionally not yet added. FIFOs, sockets and device nodes are inventoried but fail closed rather than being silently omitted or falsely declared safe.

## dev3 QueueRexx / bandwidth increment
- Binds evacuation work-unit submission to exact QueueRexx v0.1-dev12 APIs without moving manifest correctness authority into QueueRexx.
- `EvacQueuePolicyGate` admits only `EVAC_*` classes at this integration boundary.
- Defines HIGH/NORMAL/BULK/RESCAN/VERIFY/FINAL evacuation job classes.
- Adds transport-neutral `EvacBandwidthGovernor` and `EvacGovernedByteSource`; the limiter is below evacuation correctness and above byte transport.
- QueueRexx v0.1-dev12 source is vendored as an exact integration dependency for reproducible qualification.

## dev4: source consistency / in-use fencing

Regular-file dispatch now performs Linux `/proc` source-use observation before transfer. Any observed foreign open file descriptor or mmap causes `WAITING_FOR_QUIESCENCE`; no bytes are dispatched under that manifest generation. A quiet window must also retain the same nanosecond source identity. After destination verification, source-use and source identity are checked again. Quiet ordinary files receive `OBSERVED_QUIESCENT`, never the stronger `APPLICATION_CONSISTENT` claim. Content equality and consistency validity remain separate evidence axes. Application/database consistency and immutable snapshot providers remain the next stronger authority layer.

## dev6 consistency groups

v0.1-dev6 adds explicit multi-file consistency authority. `EvacConsistencyGroup`
collects files which must represent one recoverable epoch.  A group transfer is
not dispatched until a provider issues one `EvacConsistencyLease` covering the
whole group.

`EvacApplicationQuiesceProvider` executes only administrator/policy supplied
quiesce and release commands; a non-zero quiesce result fails closed and copies
nothing.  Successful captures are labelled `APPLICATION_CONSISTENT`.

`EvacPreparedSnapshotProvider` consumes an already-created stable snapshot root
(the platform/filesystem adapter owns snapshot creation).  Every group member
must exist in that root before a lease is issued; successful captures are
labelled `SNAPSHOT_CONSISTENT`.

A consistency lease is evidence about source validity, not a substitute for
content verification. Every member still passes through Storage Fabric transfer
and independent destination verification. If any member fails, the group is not
promoted as a consistent epoch and release is still attempted.

## dev7/dev8 operational planning increment

The manifest is now the authority for deriving QueueRexx work intentions.  Work is
batched by compatible evacuation class and bounded by object count/bytes; large
objects remain independently resumable.  Completion evidence is applied back to
individual manifest entries idempotently.

Operational policy adds explicit include/exclude prefixes, aggregate bandwidth,
concurrency and minimum-replica targets.  `EvacDryRunReport` reports the selection
before mutation; `EvacSession` reports current generation, verified/outstanding/
dirty/error counts and verified/selected bytes.  Exclusion is explicit manifest
state and therefore remains visible to the final seal.

POSIX remains an external authority.  This increment adds no filesystem command
parsing or local POSIX replacement.
