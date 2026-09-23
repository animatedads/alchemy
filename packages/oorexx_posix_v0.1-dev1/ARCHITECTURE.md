# Architecture

`oorexx_posix_v0.1-dev1` sits above ooRexx Unix facilities rather than rebinding libc wholesale.

Authority order:

1. **RxUnixSys** for primitives it already owns.
2. **RexxUtil** where its portable/weaker semantics are sufficient.
3. **Small RxUnixSys extensions** for generally useful missing Unix primitives.
4. **Foreign/native gap providers** only as temporary or specialist seams.

The default `PosixRxUnixSysProvider` contains no new native binding. The optional `PosixGapProvider` composes that provider and overrides only strong stat/lstat/readlink/sync operations using `rxposixgap`; everything else delegates back to RxUnixSys.

A result marked `coherent=.false` MUST NOT be used as generation-fencing evidence. Consequently `PosixStat~identity` returns `.nil` for scalar `SysStat` observations; only coherent stat objects expose a strong `PosixFileIdentity`.

The gap provider is intentionally named separately from the proposed future `SysStatInfo`/`SysLstatInfo` routines so it cannot masquerade as upstream RxUnixSys authority.
