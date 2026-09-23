# ooRexx POSIX Foundation 0.1-dev1

Executable first implementation of `oorexx.posix/0.1`, deliberately built **on top of the Unix facilities already shipped with ooRexx 5.3.0** rather than as another general libc wrapper.

## What dev1 implements

The default `.Posix~new` provider is pure ooRexx over `RxUnixSys` / RexxUtil:

- `chmod`, `chown`, `lchown`, hard-link, symlink, mkdir, rmdir and unlink delegate directly to `RxUnixSys`;
- directory enumeration uses `SysGetdirlist` and normalizes its documented error sentinel;
- `statBasic()` exposes scalar `SysStat()` data while explicitly marking it **non-coherent**;
- credentials and passwd lookup reuse existing Unix functions;
- user lookup turns the current empty/errno-0 "not found" behaviour into structured `LOOKUP_NOT_FOUND`;
- arbitrary group lookup fails closed because qualification found a missing-record crash in the supplied runtime;
- strong xattr reads fail closed because current `SysGetxattr` / `SysListxattr` cannot distinguish legitimate empty data from error; explicitly named weak-read methods preserve that limitation.

The package also contains an **optional temporary native gap provider** (`native/rxposixgap.cpp`). It supplies the small correctness primitives proposed for eventual absorption into `RxUnixSys`:

- one-call coherent `stat`;
- one-call coherent `lstat`;
- raw `readlink` payload;
- `fsync`;
- `fdatasync`.

It returns numeric native metadata including nanosecond timestamps. It is not intended to become a permanent competing Unix library.

## Default use

```rexx
p = .Posix~new
r = p~statBasic('/tmp/file')
if r~ok then say r~value~size
else say r~error~string

::requires 'Posix.cls'
```

Set the package search path, for example:

```sh
export REXX_PATH=/path/to/oorexx_posix_v0.1-dev1/src:/path/to/oorexx_posix_v0.1-dev1/src/providers
```

## Coherent-stat development provider

Build the temporary module:

```sh
make -C native OOREXX_ROOT=/usr/local
export LD_LIBRARY_PATH="$PWD/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

Then:

```rexx
p = .PosixGapFactory~create
r = p~stat('/tmp/file')
if r~ok then do
  say r~value~device r~value~inode
  say r~value~mtimeSec r~value~mtimeNsec
end

::requires 'PosixGap.cls'
```

Applications should require the facade entry points, not provider implementation files.

## Qualification

`VALIDATION.txt` records the actual build and behaviour run against the supplied ooRexx 5.3.0 r13196 debug package. `KNOWN_ISSUES.md` records the observed missing-group lookup crash without generalising it to other ooRexx releases.
