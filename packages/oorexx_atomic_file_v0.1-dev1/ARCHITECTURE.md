# Architecture

`oorexx_atomic_file` owns a state-machine promise assembled from lower filesystem primitives. It is not POSIX itself.

Independent identity:

- library: `oorexx_atomic_file_v0.1`
- API: `oorexx.atomic-file/0.1`
- entry class: `.AtomicFile`

The dev1 provider uses direct native `open/openat`, `write`, `fchmod`, `fdatasync/fsync`, `renameat`, `unlinkat` and directory sync because the current POSIX facade does not yet expose the descriptor lifecycle needed to assemble this protocol safely. Once those primitives exist in the lower platform layer, this provider can be reimplemented against them without moving Atomic File semantics into POSIX.

## Durability modes

- `NONE`: atomic replacement only; no crash-durability claim.
- `DATA`: staging-file data is synchronized before rename; parent namespace is not synchronized.
- `FULL`: staging file is synchronized before rename and the containing directory is synchronized after rename.

A failure after rename but before parent-directory sync is returned with `published == .true` and `ok == .false`. This distinction is essential: the new generation may be visible even though the requested full durability promise was not achieved.
