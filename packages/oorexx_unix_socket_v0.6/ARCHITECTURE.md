# Architecture

## Decision

Unix Socket v0.6 keeps the v0.4 decision that **Foreign Runtime is the native binding authority** while `unixsocket.cls` is the semantic Unix IPC library.

The v0.5 decision remains that **ABI layout/constant facts belong to Foreign Runtime bridge profiles**, not to Rexx control code. v0.6 sharpens this boundary: implementation-width C scalars belong to Foreign Runtime's host-native datatype resolver, while aggregate layout stays profile-qualified.

The v0.3 native implementation remains a useful semantic oracle but is not the preferred system boundary.

## Managed call graph

`sendmsg(2)` and `recvmsg(2)` require a managed graph:

```text
msghdr
  +-- msg_iov ------> iovec ------> payload ForeignBuffer
  +-- msg_control ----------------> control ForeignBuffer
  +-- msg_name -------------------> sockaddr buffer
```

Foreign Runtime's managed pointer fields retain these child resources, recursively pin the graph for the call, reject pointer cycles, and prevent mutation while pinned. `ForeignBuffer~putBytes/getBytes` provides exact binary construction/parsing.

## Executable ABI authority

The default bridge uses schema `oorexx.foreign/0.22.6` and an `abiProfiles` section. Foreign Runtime selects the profile matching the actual process ABI and requires that profile to be in its qualified profile set before the native library is opened.

For the current release:

```text
runtime ABI              linux-x86_64-le-lp64
Foreign Runtime qualified yes
bridge profile present    yes
UnixSocket load            allowed
```

A mismatched or unqualified ABI fails before `dlopen()`.

The profile owns ABI-sensitive facts including:

- AF/socket/message/fcntl/poll constants;
- `sockaddr_un` size/path offset/capacity and `sa_family_t` width;
- `iovec`, `msghdr`, `pollfd`, `cmsghdr`, `ucred`, and relevant `stat` layouts;
- CMSG alignment and field offsets;
- platform-specific ancillary offsets/alignment and remaining fixed-width kernel record fields.

Function signatures and scalar struct members that are C implementation types use Foreign Runtime aliases such as `size_t`, `ssize_t`, `socklen_t`, `short`, and `unsigned long`. `unixsocket.cls` derives their sizes from Foreign Runtime when raw ancillary bytes require a width. Runtime endianness is still used to encode/decode those byte streams, while CMSG offsets/alignment remain profile evidence.

## Descriptor ownership

`socket()` and `accept4()` returns are declared as owned `POSIX_FD` scalar resources with `close` as destructor. `.UnixSocket` retains the resulting `.ForeignHandle`.

Descriptors received in `SCM_RIGHTS` arrive as raw kernel integers in ancillary bytes. Each is converted to one managed owner using profile-defined `F_DUPFD_CLOEXEC`, then the original received integer is closed.

`.UnixDescriptor~release` preserves the raw-FD transfer contract by creating a caller-owned close-on-exec duplicate and retiring the managed original. `.UnixDescriptor~transferHandle` transfers the Foreign Runtime handle directly when the consumer accepts that ownership form.

## Ancillary data

The `cmsghdr` byte stream is still constructed and parsed in ooRexx because Foreign Runtime structs do not expose arbitrary trailing flexible-array payload storage. The CMSG offsets/alignment, level/type constants, credential offsets, and FD width come from the selected ABI profile. C implementation-width fields such as `size_t` are derived from Foreign Runtime's ABI-native datatype resolver.

On `MSG_CTRUNC`, or when more rights are received than `maxDescriptors`, every identifiable received FD is closed and the operation fails with profile-defined `EMSGSIZE`. No partial capability set is exposed.

## Pathname mutation

The Linux profile supports socket-only chmod/chown using `open(O_PATH|O_NOFOLLOW)` plus profile-defined `stat` metadata to verify a socket inode, then `/proc/self/fd/<fd>` to mutate the pinned inode.

Safe unlink verifies with `lstat` and refuses non-sockets, but Linux has no general unlink-by-open-fd primitive. Parent-directory authority remains part of the security model.

## Future profiles

A future profile is not created by renaming the current JSON section. It requires independent ABI evidence and Foreign Runtime qualification. OS-specific semantic differences may also require explicit feature gating or bridge/function changes; v0.6 does not claim otherwise.
