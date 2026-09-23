# Security and confinement

## Archive-level fail-closed rules

Before payload extraction the parser rejects:

- malformed or trailing EOCD structure;
- ZIP64 sentinels and multi-disk records;
- encryption flags;
- unsupported methods;
- path traversal/absolute/drive/backslash/portable-name hazards;
- exact and ASCII-case-fold collisions;
- Unix symlink and special-file modes;
- inconsistent local vs central names/methods/flags/sizes/CRC;
- inconsistent data descriptors;
- local-record overlap with another entry or the central directory;
- configured declared entry/total size limits.

Method-8 decompression is bounded by the declared central-directory
uncompressed size via `oorexx-compress` module level 4. CRC32 and the exact
final size are then checked.

## Filesystem publication boundary

`extractFresh(root)` is deliberately tied to a root which does not exist before
the operation. It creates only validated regular-file/directory paths beneath
that root. This removes pre-existing symlink traversal from the normal package
RUN staging case.

The implementation does not yet possess descriptor-relative `openat` +
`O_NOFOLLOW` / equivalent primitives. Therefore it does not claim resistance to
a same-authority concurrent process which removes/replaces a directory between
checks and file opens. The preferred packager must use a private staging parent
and its single-writer transaction authority; the POSIX layer should eventually
provide a descriptor-relative sink for the stronger guarantee.
