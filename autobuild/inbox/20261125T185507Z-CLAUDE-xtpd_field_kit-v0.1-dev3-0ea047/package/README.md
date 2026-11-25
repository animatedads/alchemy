# xtpd field kit v0.1-dev3 (grid item 1)

- **Architecture:** Tom Dyer.
- **Coding:** Claude (Opus 5.5), 25 November 2026: the kit, tools/build_kit.sh, tools/item1_files.rex and tools/rehearse.sh. xtpd v0.1-dev2 is also by Claude (Opus 5.5). The role component (xtpd_bootstrap v0.1-dev1) is by ChatGPT. ooRexx 5.3.0 is the ooRexx project's.
- **Written by:** Claude (Opus 5.5).

## What it is

`xtpd-field-kit-0.1-dev3.tar.gz` is everything needed to run xtpd v0.1-dev2 on a node without building anything there (R3). It unpacks to /opt/rexxos/xtpd-0.1-dev2 and holds:
- ooRexx 5.3.0;
- the native libraries, built from source in the Ubuntu 22.04 build container;
- the ooRexx sources of the 12 estate packages xtpd needs;
- `bin/kit-rexx`, `bin/selftest` (with `bin/selftest_ffi.rex`) and `bin/item1_files.rex`;
- libffi.so.8, from the build container.
- two systemd units.

The native parts need only the C and C++ runtimes and OpenSSL 3 (libcrypto.so.3). The kit carries its own libffi.so.8, because the foreign runtime loads it at run time.

## dev3 (25 Nov 2026), replacing dev2

- **Fault:** on Ubuntu 26.04 minimal (one of the two Vultr machines runs 26.04) there is no libffi, so the foreign runtime fell back to its three-argument dispatcher and xtpd's socket calls failed. The kit's selftest did not see it.
- **Fix:** the kit carries libffi.so.8.
- **Check:** `bin/selftest_ffi.rex` makes the same kind of calls xtpd makes (socketpair, send, poll, recvmsg, peer credentials).
- **Control:** with libffi taken out of the kit, the selftest fails, naming the fallback dispatcher. With it, the order rehearsal passes on Ubuntu 26.04 and 24.04.
- Debian 13 was not tested here: its mirror is outside this session's network allowlist.
- ORDER.md step 1 now finds ed209k's address with `ip` instead of `curl`, which a minimal Debian may lack. The address must be one of the two Vultr addresses and be on the interface.

## Use

ORDER.md is the item 1 field order for Codex. It needs Tom's direct approval, because it makes key files.

## Rehearsed

tools/rehearse.sh ran the order's own steps on loopback, as root, from the tarball, on Ubuntu 24.04 and on Ubuntu 26.04 minimal (dev3):
- the kit checksums and the selftest pass;
- the tool writes the files for both nodes, with the key files mode 600 from creation, and refuses a second run;
- cats2 catches up to epoch 2 and STATUS ends `status FRESH peer ed209k epoch 2 version 1 ready yes`;
- no 64-hex secret appears in either log.

The rehearsal found one fault before it reached a node: /dev/urandom is a transient stream, so it is read with `charin(, 32)`.

## Limits

- The role key is a TEST key: a shared-key HMAC, not the real Auth.
- The LDAP server on ed209k is the oorexx_ldap_identity fixture on 127.0.0.1. It proves the probe; it is not a production directory.
- Nothing promotes the spare yet, and the witness (cats1, R7) is not used.
