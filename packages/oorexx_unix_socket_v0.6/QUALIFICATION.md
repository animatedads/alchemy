# Qualification

## Status

`oorexx_unix_socket_v0.6` supersedes v0.5 as the current candidate. It remains an ooRexx semantic library over Foreign Runtime and libc; no Unix-socket-specific native `.so` is present.

## Inputs

- ooRexx 5.3.0 r13196 Internal Test Version `.deb`: SHA-256 `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae`.
- Directly supplied `oorexx_foreign_runtime_v0.22.6(1).zip`: SHA-256 `25a7b258b7920c355b96f19807515d6fb6e419687714396589b054a7029ab465`.
- Unix Socket v0.5 baseline: SHA-256 `6d3f44a913d97768bb5be160ca7d5abd412d8f774f1ca78496c72f1403c17d53`.

## Foreign Runtime v0.22.6 forcing evidence

Foreign Runtime v0.22.6 was rebuilt from source using the headers extracted from the supplied r13196 package. The rebuilt `libforeign_runtime.so` SHA-256 is `69e17621ccde0634d34754b945bb93bb355d64a47ca44bd71f63c706e878790f`.

That rebuilt binary then passed the complete Foreign Runtime release suite under the same supplied r13196 interpreter. Relevant results include:

```text
PASS thread-safety activities
PASS 128 assertions
PASS i8/u8 scalar and struct-field support 18 assertions
PASS ABI profile qualification 17 assertions
PASS ABI-native C scalar aliases 23 assertions
PASS managed struct pointer graph and binary buffer slices
PASS Foreign Runtime -> POSIX openpty/poll/exact-binary/errno
PASS Python provider activity stress
PASS optional OpenSSL metadata probe
PASS OpenSSL EVP SHA-256 via Foreign Runtime
PASS automatic OpenSSL EVP SHA-256 outputs via Foreign Runtime
PASS OpenSSL one-shot SHA-256/SHA-512 exact binary bytes via Foreign Runtime
PASS Foreign Runtime -> FFmpeg avformat open/find/close
PASS Foreign Runtime -> FFmpeg AVChannelLayout struct
PASS Foreign Runtime -> FFmpeg planar uint8_t **
OPTIONAL Vulkan-hardware SKIP reason=no-matching-non-CPU-Intel-device
QUALIFICATION prebuilt-binary interpreter=Open Object Rexx Version 5.3.0 r13196 - Internal Test Version
```

The `prebuilt-binary` label is the Foreign Runtime runner's mode name: the binary under test was the locally source-rebuilt artifact above. A source-mode run rebuilt successfully and progressed through the same core/ABI lanes before the outer execution ceiling interrupted a later optional Python import; the complete rebuilt-binary run is therefore the recorded full-suite qualification.

## v0.6 ABI-native scalar boundary

Foreign Runtime v0.22.6 adds capability `abi-native-c-scalars`. Unix Socket v0.6 requires it and uses native C aliases where the libc prototype depends on the implementation ABI:

- `size_t` for send/receive lengths and `iovec`/`msghdr`/`cmsghdr` size fields;
- `ssize_t` for send/receive return values;
- `socklen_t` for Unix address and socket-option lengths;
- `unsigned long` for Linux x86-64 `nfds_t` in `poll`;
- `short` for `pollfd.events/revents`.

This does **not** weaken aggregate ABI qualification. `msghdr`, `cmsghdr`, `iovec`, `pollfd`, `ucred`, `stat`, constants, offsets, padding, and CMSG rules remain inside the qualified `linux-x86_64-le-lp64` bridge profile.

The release runner independently compiles `tests/abi_profile_probe.c` against the host C headers and compares the executable ABI evidence with bridge metadata. After removing four duplicated scalar-width constants now owned by Foreign Runtime, it checks 67 profile constants plus six structure layouts:

```text
PASS bridge ABI metadata matches C headers profile=linux-x86_64-le-lp64 constants=67 types=6
```

A dedicated Rexx forcing test inspects the actual Foreign Runtime signatures and struct metadata:

```text
PASS Unix Socket ABI-native C scalar binding 18 assertions
```

A deliberately mismatched AArch64 profile continues to fail before provider loading:

```text
PASS mismatched ABI profile rejected before dlopen
```

## Semantic regression qualification

The complete inherited Unix Socket surface passes through Foreign Runtime v0.22.6:

```text
PASS qualified ABI bridge resolves relative to unixsocket.cls profile= linux-x86_64-le-lp64
PASS bridge ABI metadata matches C headers profile=linux-x86_64-le-lp64 constants=67 types=6
PASS stock socket.cls rejects AF_UNIX as expected
PASS mismatched ABI profile rejected before dlopen
PASS Foreign Runtime boundary version= 0.22.6 abi= linux-x86_64-le-lp64 provider=/lib/x86_64-linux-gnu/libc.so.6
PASS Unix Socket ABI-native C scalar binding 18 assertions
PASS class smoke: socketpair, binary send/recv, peer credentials
PASS path client
PASS path server
PASS abstract client
PASS abstract server
PASS pathname SOCK_DGRAM sendTo/recvFrom with binary payload and sender address
PASS unbound SOCK_DGRAM sender is represented as UNNAMED
PASS datagram truncation is surfaced explicitly
PASS SCM_RIGHTS descriptor transfer, ownership release, and live socket use
PASS SCM_RIGHTS ancillary truncation fails closed errno=90
PASS created and SCM_RIGHTS-received descriptors default to CLOEXEC
PASS SOCK_DGRAM and SOCK_SEQPACKET socketPair transport
PASS nonblocking mode, would-block classification, semantic poll readiness, and sendAll safety
PASS explicit SO_RCVBUF/SO_SNDBUF whitelist with kernel-normalized values
PASS socket-only pathname inspection, pinned chmod/chown, and non-socket unlink refusal
PASS kernel per-message SCM_CREDENTIALS and combined ancillary receive
PASS abstract SOCK_DGRAM sendTo/recvFrom
PASS binary-safe Linux abstract namespace names including embedded NUL
PASS ALL ooRexx Unix Socket v0.6 Foreign Runtime ABI-native-scalar tests
```

## Portability claim

The only concrete aggregate ABI profile qualified here remains **Linux x86-64 little-endian LP64 (`linux-x86_64-le-lp64`)**. ABI-native scalar aliases reduce unnecessary fixed-width assumptions, but they do not authorize copying x86-64 aggregate layouts to AArch64 or another Unix family. A new platform still requires independent profile evidence and Foreign Runtime qualification.
