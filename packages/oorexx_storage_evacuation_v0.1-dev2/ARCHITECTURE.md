# Storage Evacuation architecture — v0.1-dev2

## Authority stack

```
Evacuation Manifest / Convergence / Seal
                 |
             QueueRexx              (next increment: execution authority)
                 |
            Storage Fabric          (transfer/provider authority)
                 |
      local / USB / remote / cloud  (transport/endpoints)
```

The manifest is the source of truth for what generation of each selected filesystem object is represented by which verified replica. No transport may promote itself to correctness authority.

## Generation fencing

An inventory snapshot records stat identity including nanosecond-resolution mtime/ctime text. Before dispatch the source is re-probed. After destination content verification it is probed again. A mismatch before dispatch refuses the stale job; a mismatch after successful verification records a verified historical generation and leaves the live object DIRTY.

## Filesystem reconstruction

Content identity and filesystem reconstruction identity are separate proofs. Regular-file bytes are independently SHA-256 verified by Storage Fabric. Directories/symlinks/modes/ownership/times are reconstructed and re-probed. Hard links are reconstructed and proven by shared destination device+inode. ACL/xattr evidence is restored and re-read when the host exposes the corresponding POSIX tools.

## Stable seal

A final clean seal needs two equivalent inventories. The second inventory may inherit previously verified replica evidence only for source objects whose recorded source-generation identity is unchanged. Any new, removed, changed, unsupported, dirty or failed object prevents the seal.

This is the mechanism intended for the final quiescent pass after the live source has converged close to sync.
