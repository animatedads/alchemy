# ooRexx Unix Socket v0.6

Unix-domain sockets for native ooRexx, implemented as an ooRexx semantic library over **ooRexx Foreign Runtime v0.22.6** and the platform C library.

v0.6 supersedes v0.5 as the continuation candidate. It contains **no Unix-socket-specific native extension** and does not modify or replace the stock `socket.cls`.

## Why this exists

The stock ooRexx `socket.cls` is an IPv4/`AF_INET` API. Its address and bind/connect contract cannot become a Unix-domain socket merely by passing an `AF_UNIX` constant.

v0.1-v0.3 established the required Unix-domain semantics with a dedicated native reference implementation. v0.4 moved the system binding onto Foreign Runtime once managed pointer graphs and binary buffer slices made `msghdr` safe. v0.5 completed that architectural move by making the **ABI profile itself executable authority** in Foreign Runtime rather than leaving x86-64 layout/constant checks in `unixsocket.cls`. v0.6 now separates two different ABI concerns cleanly: C implementation-width scalar arguments/returns use Foreign Runtime v0.22.6 ABI-native aliases (`size_t`, `ssize_t`, `socklen_t`, `unsigned long`, `short`), while structure size/offset/padding and platform constants remain controlled by the qualified ABI profile.

## Architecture

```text
ooRexx application
      |
      v
 unixsocket.cls                    semantic API / ownership rules
      |
      v
 ooRexx Foreign Runtime v0.22.6   managed resources + ABI enforcement
      |
      v
 bridge/libc-af-unix.bridge.json
      |
      +-- abiProfiles/linux-x86_64-le-lp64
      |      constants + struct layouts
      |
      v
 libc.so.6
      |
      v
 Linux AF_UNIX / poll / fcntl / recvmsg / sendmsg
```

There is no `librxunixsocket.so` in this release.

## v0.6 ABI boundary

Foreign Runtime v0.22.6 supplies:

- `runtimeInfo~abiProfile` and `abiQualified`;
- `abiProfiles` bridge sections;
- profile-scoped constants and struct layouts;
- ABI-native C scalar aliases with runtime-derived width/alignment/signedness;
- fail-closed rejection of mismatched or unqualified profiles before `dlopen()`.

`unixsocket.cls` therefore no longer embeds the Linux x86-64 values for socket flags, poll bits, `sockaddr_un` sizes, `cmsghdr` alignment, or `stat` offsets. It asks the selected qualified bridge profile for those facts. `stat`, `ucred`, `iovec`, `msghdr`, `pollfd`, and `cmsghdr` layouts are metadata-defined. Function signatures now declare their real C implementation types (`size_t`, `ssize_t`, `socklen_t`, and the Linux-qualified `nfds_t` carrier `unsigned long`) instead of freezing them as `u64/i64/u32`.

The release runner independently compiles a small C-header ABI probe and compares its constants, sizes, alignments, and offsets with the JSON profile.

## Qualified surface

- pathname, Linux abstract and unnamed Unix addresses;
- binary-safe abstract names including embedded NUL bytes;
- `SOCK_STREAM`, `SOCK_DGRAM`, `SOCK_SEQPACKET` and `socketpair`;
- `bind`, `connect`, `listen`, `accept4`, send/receive and addressed datagrams;
- semantic poll/readiness;
- blocking/nonblocking mode and would-block classification;
- `FD_CLOEXEC` by construction/receipt;
- `SO_RCVBUF` and `SO_SNDBUF` whitelist;
- `SO_PEERCRED`, `SO_PASSCRED` and per-message `SCM_CREDENTIALS`;
- `SCM_RIGHTS` descriptor transfer with owned descriptor objects;
- fail-closed ancillary truncation;
- socket-only pathname inspection/chmod/chown/unlink helpers;
- v0.4/v0.3 observable API compatibility for the qualified test surface.

## ABI introspection

```rexx
say .UnixSocket~foreignRuntimeVersion  /* 0.22.6 when qualified here */
say .UnixSocket~abiProfile            /* linux-x86_64-le-lp64 */
say .UnixSocket~abiQualified          /* 1 */
```

## Platform claim

This release includes and qualifies one concrete ABI profile: **`linux-x86_64-le-lp64`**.

Foreign Runtime v0.22.6 itself currently qualifies that same ABI-specific profile and intentionally does not claim AArch64 or other Unix ABIs. A new platform profile must have independent structure/constant evidence and Foreign Runtime qualification; copying the x86-64 profile is not acceptable.

## Dependency

Required: ooRexx Foreign Runtime **v0.22.6** or a compatible later runtime exposing:

- `transitive-struct-pinning`
- `binary-buffer-slices`
- `abi-profile-enforcement`
- `profile-scoped-layouts`
- `profile-scoped-constants`
- `abi-native-c-scalars`

v0.6 was qualified under the supplied ooRexx 5.3.0 r13196 Internal Test Version and the directly supplied Foreign Runtime v0.22.6 package.

See `INSTALL.md`, `ARCHITECTURE.md`, `SECURITY.md` and `QUALIFICATION.md`.
