# Security properties

- New sockets use profile-defined `SOCK_CLOEXEC`.
- Accepted sockets use `accept4(..., SOCK_CLOEXEC)` on the qualified Linux profile.
- Socket-pair descriptors use close-on-exec creation and are converted to managed Foreign Runtime handles.
- `SCM_RIGHTS` reception requests profile-defined `MSG_CMSG_CLOEXEC`; received integers are additionally converted through `F_DUPFD_CLOEXEC` into managed owners.
- Ancillary truncation fails closed. Partial descriptor sets are not returned.
- `sendAll` refuses nonblocking descriptors, avoiding ambiguous partial-prefix replay on a would-block retry.
- `SO_PEERCRED` and `SCM_CREDENTIALS` are kernel-provided attribution evidence; applications must still apply authorization policy.
- Socket options are an explicit whitelist rather than an arbitrary `setsockopt` escape hatch.
- Pathname chmod/chown verifies and pins a socket inode with `O_PATH|O_NOFOLLOW` before mutation on the qualified Linux profile.
- Socket-only unlink refuses ordinary files. Parent-directory authority is still required to make unlink race-safe at the system-design level.
- ABI-specific constants/layouts are accepted only through a Foreign Runtime-qualified ABI profile. A mismatched/unqualified profile is rejected before `dlopen()`.
- Release qualification independently compares the bridge profile with C headers, reducing the risk of a correctly labelled but incorrectly encoded ABI profile.
- C implementation-width scalar parameters use Foreign Runtime ABI-native types; aggregate offsets/padding remain separately ABI-profile-qualified, preventing a fixed-width scalar shortcut from bypassing layout qualification.
