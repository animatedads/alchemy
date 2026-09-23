# Security

- staging objects are created in the target directory using `O_CREAT|O_EXCL|O_NOFOLLOW`.
- target symlinks are rejected by default.
- staging therefore remains on the same filesystem as the destination rename.
- no predictable `SysTempFileName` check-then-create protocol is used.
- dev1 does not claim descriptor-relative protection across every ancestor path component; that requires the planned `*at` traversal substrate.
- generation fencing is explicitly unavailable rather than emulated with a racy pre-check.
