# Changelog

## v0.6.0

- Supersedes v0.5 as the current candidate.
- Rebases the binding contract on Foreign Runtime v0.22.6.
- Requires Foreign Runtime capability `abi-native-c-scalars`.
- Changes libc `send`/`recv`/`sendto`/`sendmsg`/`recvmsg` return and length declarations from fixed `i64/u64` carriers to native `ssize_t/size_t`.
- Changes address/option length declarations from fixed `u32` to native `socklen_t`.
- Declares `poll`'s Linux x86-64 `nfds_t` carrier as ABI-native `unsigned long`.
- Changes `iovec.iov_len`, `msghdr.msg_iovlen/msg_controllen`, `cmsghdr.cmsg_len`, and `msghdr.msg_namelen` to native C scalar aliases; `pollfd.events/revents` use native `short`.
- Derives `size_t`, `socklen_t`, `int`, and `unsigned short` widths from Foreign Runtime rather than duplicating those widths as bridge constants.
- Adds an executable 18-assertion Unix Socket native-scalar forcing test in addition to the existing independent C-header layout/constant probe.
- Preserves the complete v0.5/v0.4/v0.3 observable socket semantics and still contains no Unix-socket-specific native library.

## v0.5.0

- Supersedes v0.4 as the continuation candidate.
- Rebases the binding boundary on Foreign Runtime v0.22.5 from `oorexxapis(20260901-115339).zip`.
- Moves ABI-sensitive constants and layouts from `unixsocket.cls` into a Foreign Runtime `abiProfiles` bridge section.
- Requires Foreign Runtime executable ABI enforcement, profile-scoped layouts, and profile-scoped constants.
- Adds `.UnixSocket~abiProfile` and `.UnixSocket~abiQualified` introspection.
- Removes the class-level pointer-size/endianness/POSIX/`uname` approximation used in v0.4; Foreign Runtime now accepts or rejects the bridge profile before native library loading.
- Replaces hard-coded little-endian record helpers with runtime-native endian packing and profile-defined scalar widths/offsets.
- Moves `stat` and `ucred` access to profile-defined `ForeignStruct` layouts.
- Adds an independent C-header ABI forcing probe that verifies profile constants, structure sizes, alignments, and offsets.
- Adds a deliberate mismatched-profile test proving rejection occurs before `dlopen()`.
- Preserves the complete qualified v0.4/v0.3 Unix Socket semantic surface with no Unix-socket-specific native `.so`.

## v0.4.0

- Replaced the dedicated `librxunixsocket.so` implementation with ooRexx code over Foreign Runtime v0.22.3 and `libc.so.6` metadata.
- Established managed nested struct-pointer graphs for `msghdr -> iovec -> payload/control/name` lifetime safety.
- Preserved the v0.3 semantic API while making Foreign Runtime the native binding mechanism.
