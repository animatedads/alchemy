# ooRexx Storage Evacuation v0.1-dev2

A generational live-filesystem evacuation and replication authority layered above Storage Fabric.  The package is designed for a source filesystem which remains live while bulk evacuation occurs and is later quiesced for final convergence.

Correctness is transport-independent.  A transfer command returning success is not sufficient evidence of preservation.  A replica becomes current only after destination verification and a source-generation fence succeeds.

## dev2

- Durable line-oriented manifest persistence with atomic replace and round-trip recovery of object, metadata, digest and replica state.
- Nanosecond-resolution source generation fencing using GNU `stat` modification/change timestamps, closing the same-second equal-size rewrite race found during qualification.
- Local metadata materialisation for directories and symlinks.
- Hard-link reconstruction and verification by destination device+inode identity, rather than merely comparing bytes.
- Mode, uid/gid and mtime reconstruction with independent destination re-probe.
- ACL/xattr capture remains optional and fail-explicit.  When `getfacl/getfattr` capture evidence and matching `setfacl/setfattr` are available, dev2 restores and re-reads that evidence; absence is represented rather than guessed.
- Unsupported special filesystem object types fail closed.
- Verified replica evidence can be carried into a subsequent generation only when source identity is unchanged.
- `sealStablePair(previous,current)` requires two equivalent inventories and zero outstanding/error/dirty objects before sealing the current generation.

## State distinction

`TRANSFERRED`, `VERIFIED`, `VERIFIED_OLD_GENERATION`, and `VERIFIED_CURRENT` remain deliberately distinct.  A source changed after a correctly verified copy leaves a valid historical replica but does not satisfy convergence for the live source.

## Architectural boundary

Evacuation owns inventory, generations, convergence, replica authority and sealing. Storage Fabric owns byte-source/sink, resumable transfer, provider interaction and content verification. QueueRexx will own scheduling, retries, WLU/concurrency and restartable work dispatch. Network/local/USB/cloud implementations are transports/endpoints underneath those authorities.

## Current boundary

The local filesystem endpoint is the executable qualification endpoint in dev2. Azure/network endpoints, QueueRexx work-unit binding and the shared bandwidth governor are intentionally not yet added. FIFOs, sockets and device nodes are inventoried but fail closed rather than being silently omitted or falsely declared safe.
