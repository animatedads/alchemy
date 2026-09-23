# RxUnixSys Extension Proposal v0.1

**Purpose:** minimal additions needed by the ooRexx estate without duplicating functionality already shipped in `RxUnixSys` or RexxUtil.

## Existing functionality retained as authority

No replacement is proposed for the existing process identity/signalling, UID/GID/account lookup, chmod/chown/lchown, hard/symbolic link creation, mkdir/rmdir/unlink, access checks, `SysGetdirlist`, scalar `SysStat`, xattrs, errno, uname/hostname, or RexxUtil file/fork/wait/pipe conveniences.

## P0 additions

### `SysStatInfo(path)`

One `stat()`/`stat64()` observation returned as a Directory or other structured ooRexx object containing raw numeric metadata, including nanosecond timestamp portions where the platform provides them.

Required fields: device, inode, mode, file type, link count, uid, gid, rdev, size, block size, blocks, atime seconds/nanoseconds, mtime seconds/nanoseconds, ctime seconds/nanoseconds.

Failure: structured/consistent error contract or a sentinel with immediately queryable `SysGeterrno` semantics documented unambiguously.

### `SysLstatInfo(path)`

Same result schema as `SysStatInfo`, using `lstat()` and never following the final symlink.

### `SysReadlink(path)`

Returns the symlink payload exactly as stored; no canonicalization or path resolution.

### `SysFstatatInfo(dirfd, name [, flags])`

Structured `fstatat()` result for descriptor-relative traversal. Must expose no-follow semantics.

### `SysFsync(fd)` / `SysFdatasync(fd)`

Return zero on success, -1 on native failure, with errno preserved in the normal RxUnixSys way.

## P1 additions

### `SysUtimensat(...)`

Nanosecond-preserving access/modified-time mutation, including no-follow support where the platform provides it.

### `SysStatvfs(path)`

Structured `statvfs()` data; numeric values, no human-unit formatting.

### Descriptor-relative mutation

Candidates: `SysOpenat`, `SysUnlinkat`, `SysMkdirat`, `SysRenameat`. These provide the base required for race-resistant tree traversal and durable publication.

## Process-related additions

RexxUtil already provides `SysFork()` and `SysWait()`, and RxUnixSys already provides process identity, signals and process-group/session operations. The remaining generally useful gap is not “fork”; it is managed child creation/supervision.

Candidates:

- a structured `posix_spawn[p]` wrapper that accepts argv without shell parsing, environment, and file actions;
- `SysWaitpid(pid [, options])` returning enough status to distinguish normal exit, signal termination, stopped/continued states where requested.

These should support `oorexx_process` rather than becoming a shell-command API.

## Explicit non-additions

The following should normally remain outside RxUnixSys:

- libacl POSIX ACL support;
- Linux-only `/proc` process observations;
- filesystem snapshot engines;
- cloud APIs;
- archive handling;
- recursive high-level file operations;
- shell command execution helpers.

## Compatibility rule

New primitives should be additive. Existing scalar functions (`SysStat`, `SysGetdirlist`, existing xattrs, etc.) remain unchanged so existing ooRexx programs retain compatibility.
