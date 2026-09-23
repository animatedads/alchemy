# ooRexx POSIX Foundation v0.1 — Design Specification

**Status:** implementation design candidate  
**Target:** ooRexx 5.3.0 r13196 Unix-like systems  
**Primary principle:** reuse the shipped ooRexx Unix facilities first; extend them where a generally useful primitive is genuinely missing; use Foreign Runtime only for the residual/specialist boundary.

## 1. Purpose

`oorexx_posix_v0.1` is not a replacement for `RxUnixSys` and is not a second general libc binding. It is the typed, evidence-grade object layer that applications can use without knowing the mixed return conventions, optional-platform behaviour, timestamp limitations, or race properties of individual Unix primitives.

The foundation exists because several unrelated applications currently know Unix command syntax (`stat`, `find`, `readlink`, `chown`, `getfattr`, `getfacl`, `df`, `touch`, `ln`, `rm`) even though ooRexx already exposes many corresponding operating-system functions directly.

The package MUST therefore preserve this authority order:

1. **RxUnixSys** for Unix primitives it already exposes with adequate semantics.
2. **RexxUtil** for portable file/process conveniences whose semantics meet the caller's requirement.
3. **RxUnixSys extensions** for missing, generally useful Unix primitives that naturally belong in the ooRexx Unix library.
4. **Foreign Runtime providers** only for residual or optional native facilities, such as libacl, sparse-file ioctls/seek semantics, or temporary compatibility implementations before a primitive is moved into RxUnixSys.

Applications consume `oorexx_posix`; they do not select this provider ladder themselves.

## 2. Existing ooRexx authority that MUST be reused

### 2.1 RxUnixSys

The supplied ooRexx 5.3.0 package ships `librxunixsys.so` and loads it using:

```rexx
::requires "rxunixsys" LIBRARY
```

The following operations are already native ooRexx Unix facilities and MUST NOT be rebound independently by `oorexx_posix` merely for convenience.

| Concern | Existing function(s) | POSIX foundation treatment |
|---|---|---|
| Process identity | `SysGetpid`, `SysGetppid`, `SysGettid` | Direct provider delegation. |
| Signals | `SysKill` | Direct provider delegation; platform layer may add typed signal/result semantics. |
| Process groups/sessions | `SysGetpgrp`, `SysSetpgid`, `SysSetpgrp`, `SysGetsid`, `SysSetsid` where shipped | Direct provider delegation. |
| UID/GID identity | `SysGetuid`, `SysGeteuid`, `SysGetgid`, `SysGetegid` | Build `PosixCredentials` from existing calls. |
| UID/GID mutation | `SysSetuid`, `SysSeteuid`, `SysSetgid`, `SysSetegid` | Keep behind explicitly privileged methods. |
| Account lookup | `SysGetpwnam`, `SysGetpwuid`, `SysGetgrnam`, `SysGetgrgid` | Build typed `PosixUser` / `PosixGroup` objects. |
| Access checks | `SysAccess`, `SysEuidaccess` | Delegate; normalize error evidence. |
| Permissions | `SysChmod` | Delegate. |
| Ownership | `SysChown`, `SysLchown` | Delegate. |
| Directory listing | `SysGetdirlist` | Use for ordinary listing; wrap its ambiguous empty-array failure contract. |
| Hard links | `SysLink` | Delegate. |
| Symbolic link creation | `SysSymlink` | Delegate. |
| Directory creation/removal | `SysMkdirUnix`, `SysRmdirUnix` | Delegate for Unix-specific semantics. |
| Unlink | `SysUnLink` | Delegate. |
| Umask | `SysUmask` | Delegate, but serialize mutation if exposed as scoped policy. |
| Basic stat fields | `SysStat` | Use only where independent field observations are sufficient; never synthesize an evidence-grade coherent stat from repeated calls. |
| xattrs | `SysGetxattr`, `SysListxattr`, `SysSetxattr`, `SysRemovexattr` where supported | Delegate, but normalize weak error signalling immediately. |
| Error text | `SysGeterrno`, `SysGeterrnomsg` | Capture immediately after a failing call. |
| Host/system facts | `SysUname`, `SysGethostname` | Delegate. |
| Descriptor close | `SysClose` | Reuse when the layer owns raw descriptors. |

`SysWordexp` is intentionally **not** a general path-normalization primitive. It performs shell-like expansion. `oorexx_posix` MUST NOT apply it implicitly to caller paths, and security-sensitive code MUST NOT use it to interpret untrusted path text. Glob/tilde expansion, when desired, is an explicit convenience operation rather than path identity.

### 2.2 RexxUtil

RexxUtil already provides useful cross-platform operations. The POSIX layer should use them when the stronger Unix contract is not required.

| Concern | Existing function | Use boundary |
|---|---|---|
| File copy | `SysFileCopy` | Convenience copy only; not metadata-faithful replication. |
| Delete file | `SysFileDelete` | Convenience deletion when no no-follow/dirfd guarantee is required. |
| Existence | `SysFileExists` | Convenience checks only; never an authorization/fencing test. |
| Move | `SysFileMove` | Convenience move; not the durable publication contract. |
| Recursive/file-pattern enumeration | `SysFileTree` | User-facing/convenience discovery; not hostile-tree traversal or coherent inventory. |
| File timestamp read | `SysGetFileDateTime` | Human/general timestamp use; second precision only. |
| File timestamp update | `SysSetFileDateTime` | Convenience touch/write-time changes; not nanosecond metadata replay. |
| Directory creation/removal | `SysMkDir`, `SysRmDir` | Portable convenience semantics. |
| Temporary-name selection | `SysTempFileName` | Non-authoritative name selection only; it does not atomically create the object. |
| Pipe creation | `SysCreatePipe` | Simple unnamed pipes where its raw-handle contract is sufficient. |
| Fork | `SysFork` | Reuse for simple fork semantics; do not pretend it is an argv-safe execution API. |
| Child wait | `SysWait` | Reuse only where waiting for child completion without PID/options control is sufficient. |
| File/link predicates | `SysIsFile`, `SysIsFileDirectory`, `SysIsFileLink` | Convenience classification; not a replacement for coherent `lstat`. |

This distinction matters: the platform should **reuse existing functionality without overstating its semantics**.

## 3. Non-goals

`oorexx_posix_v0.1` does not:

- reimplement libc wholesale;
- replace RexxUtil;
- replace `RxUnixSys`;
- become the process-execution library (`oorexx_process` owns managed execution);
- become the archive library;
- become a filesystem snapshot service;
- silently emulate absent native capabilities by shelling to commands;
- promise Linux behaviour on every Unix target;
- collapse all filesystem consistency levels into `true/false` flags.

## 4. Public package structure

Recommended development layout:

```text
oorexx_posix_v0.1/
  src/
    Posix.cls
    PosixResult.cls
    PosixCapabilities.cls
    PosixPath.cls
    PosixStat.cls
    PosixDirectory.cls
    PosixIdentity.cls
    PosixCredentials.cls
    PosixXattr.cls
    PosixAcl.cls
    PosixTimes.cls
    PosixFilesystem.cls
    PosixMutation.cls
    providers/
      PosixRxUnixSysProvider.cls
      PosixRexxUtilProvider.cls
      PosixExtendedUnixProvider.cls
      PosixForeignAclProvider.cls
      PosixLinuxSparseProvider.cls
  tests/
  README.md
  ARCHITECTURE.md
  SECURITY.md
  QUALIFICATION.md
  COMPATIBILITY.md
  VERSION
  MANIFEST.sha256
```

`Posix.cls` is the normal application entry point. Provider classes are platform implementation detail.

## 5. Core object model

### 5.1 `Posix`

A process-local facade assembled from detected capabilities.

Suggested surface:

```text
Posix~capabilities
Posix~stat(path [, options])
Posix~lstat(path [, options])
Posix~listDirectory(path [, options])
Posix~readLink(path)
Posix~mkdir(path [, mode])
Posix~removeDirectory(path)
Posix~unlink(path [, options])
Posix~link(source, target [, options])
Posix~symlink(targetText, linkPath [, options])
Posix~chmod(path, mode [, options])
Posix~chown(path, uid, gid [, options])
Posix~setTimes(path, times [, options])
Posix~xattrs(path [, options])
Posix~filesystem(path)
Posix~credentials
Posix~lookupUser(nameOrUid)
Posix~lookupGroup(nameOrGid)
```

Mutation methods return `PosixResult`; observation methods either return a result containing a typed object or raise only for programmer-contract violations. Native failures are data, not arbitrary Rexx syntax exceptions.

### 5.2 `PosixResult`

```text
PosixResult
  ok
  value
  error
  evidence
```

A failed result MUST retain enough evidence to determine what actually failed without parsing a human message.

### 5.3 `PosixError`

```text
PosixError
  operation
  path / paths
  errno
  errnoName          # when known
  message
  provider
  capability
  recoverable        # classification, not a retry command
```

The provider captures `errno` immediately after failure. It MUST NOT make another native call before preserving the error value.

### 5.4 `PosixCapabilities`

Capabilities are explicit and independently testable:

```text
posix.stat.basic
posix.stat.coherent
posix.lstat.coherent
posix.fstatat
posix.dir.iterate
posix.readlink
posix.xattr
posix.xattr.symlink
posix.acl.posix1e
posix.times.nanosecond
posix.statvfs
posix.sparse.seek-data-hole
posix.sync.fsync
posix.sync.fdatasync
posix.openat
posix.renameat
posix.unlinkat
posix.mkdirat
posix.chown
posix.lchown
posix.link
posix.symlink
```

Capability absence is not an invitation to invoke a command-line substitute.

## 6. Coherent metadata: the most important extension

### 6.1 Why repeated `SysStat` calls are insufficient

The shipped `SysStat(file, option)` uses `stat64()` but returns one selected field per invocation. It can provide device, inode, permissions, link count, uid, gid, device id, size, and timestamps. That is useful for ordinary inspection.

It is not sufficient for generation fencing. If an application calls `SysStat(path, "DEVICE")`, then `SysStat(path, "INODE")`, then `SysStat(path, "SIZE")`, the pathname can resolve to different generations between calls. A `PosixStat` assembled this way would look coherent while not actually representing one kernel observation.

Therefore:

> `Posix~stat()` MUST use a one-native-call structured stat provider when the caller requests coherent/evidence-grade metadata.

### 6.2 Proposed `PosixStat`

```text
PosixStat
  device
  inode
  mode
  fileType
  permissions
  linkCount
  uid
  gid
  rdev
  size
  blockSize
  blocks
  atimeSec
  atimeNsec
  mtimeSec
  mtimeNsec
  ctimeSec
  ctimeNsec
  birthTimeSec?       # provider-specific, optional
  birthTimeNsec?
  observedPath
  followedSymlink
  provider
```

`PosixFileIdentity` should be derived rather than separately re-probed:

```text
PosixFileIdentity
  device
  inode
  fileType
```

Applications performing generation fencing may additionally bind size/mtime/ctime according to their policy, but device+inode remains the filesystem object identity evidence.

### 6.3 Recommended RxUnixSys extension

Preferred primitive:

```text
SysStatInfo(path [, followLinks]) -> Directory
```

or, if API clarity is preferred:

```text
SysStatInfo(path)  -> Directory       # stat()
SysLstatInfo(path) -> Directory       # lstat()
```

The returned Directory should contain numeric native fields, not preformatted `ls -l` strings, and should preserve nanoseconds where the host ABI supplies them.

The POSIX facade can translate that Directory into `PosixStat`.

## 7. Directory enumeration and race-resistant traversal

### 7.1 Ordinary listing

`SysGetdirlist` is useful and should remain the ordinary provider. It already uses `opendir()` / `readdir()` rather than shelling to `find`.

Its documented weakness is that an empty array can mean either:

- directory opened successfully and contained no returned entries; or
- an error occurred opening the directory.

The wrapper MUST therefore capture/normalize the error state. If the existing primitive cannot reliably distinguish these cases, evidence-grade iteration requires a stronger primitive.

### 7.2 Evidence-grade iterator

For hostile or changing trees, the desired contract is descriptor-relative:

```text
PosixDirectoryIterator~open(path, options)
iterator~next -> PosixDirectoryEntry | nil
entry~name
entry~typeHint
entry~stat([followLinks=false])
iterator~close
```

The strongest provider should hold an open directory descriptor and use `fstatat()` / `openat()` family operations relative to that descriptor. This prevents pathname re-resolution at unrelated roots and reduces TOCTOU exposure.

Required extension candidates:

```text
SysOpenDirFd(path [, flags])
SysFstatatInfo(dirfd, name [, flags])
SysOpenat(dirfd, name, flags [, mode])
SysUnlinkat(dirfd, name [, flags])
SysMkdirat(dirfd, name, mode)
SysRenameat(oldDirfd, oldName, newDirfd, newName)
```

Not all of these must be public in v0.1; they define the secure traversal endpoint.

## 8. Symbolic links

Creation already exists through `SysSymlink`. Detection convenience exists through `SysIsFileLink`, and ownership mutation through `SysLchown`.

The missing primitive is link payload observation:

```text
SysReadlink(path) -> String
```

The function MUST return the stored link text exactly and MUST NOT canonicalize or resolve it.

`PosixLink`:

```text
PosixLink
  path
  targetText
  stat                 # lstat-derived identity
```

Storage/evacuation code must preserve `targetText`, not the resolved target pathname.

## 9. Extended attributes

`RxUnixSys` already exposes xattr primitives on supporting systems. The facade should use them rather than invoking `getfattr` / `setfattr`.

The existing getter/list return conventions are too ambiguous for evidence-grade use:

- zero-length `SysGetxattr` return can represent error but an empty attribute value is also semantically possible;
- empty `SysListxattr` array can represent either no attributes or error.

The provider MUST therefore preserve errno directly after the call. If that cannot disambiguate every supported platform safely, a future RxUnixSys structured result should be added rather than shelling out.

Suggested object:

```text
PosixExtendedAttributes
  names
  get(name)
  set(name, value [, flags])
  remove(name)
  snapshot -> Directory
```

Binary attribute values remain Rexx byte strings; no text transcoding is performed.

For symlink xattrs, `lgetxattr` / `llistxattr` / `lsetxattr` semantics should be a separately advertised capability. Do not silently follow a symlink when the caller requested link metadata fidelity.

## 10. POSIX ACLs

The supplied Unix Extensions contract does not expose POSIX ACL operations. This should remain an optional provider rather than being faked through command output.

Preferred provider: Foreign Runtime bridge to libacl on platforms where libacl is available.

```text
PosixAcl~read(path [, followLinks])
PosixAcl~entries
PosixAcl~write(path, acl [, options])
PosixAcl~toText                 # diagnostics only
```

The authoritative representation should be structured entries, not `getfacl` text.

Capability:

```text
posix.acl.posix1e
```

If unavailable, metadata replication records `UNSUPPORTED`; it does not report an empty ACL.

## 11. File times

RexxUtil `SysGetFileDateTime` / `SysSetFileDateTime` are useful portable convenience APIs but expose second-resolution text and primarily last-modified semantics.

Evidence-grade metadata replication needs numeric timespec values and `utimensat`-class mutation.

```text
PosixFileTimes
  accessSec / accessNsec
  modifySec / modifyNsec
  changeSec / changeNsec      # observed only; not user-settable
  birthSec? / birthNsec?
```

Preferred RxUnixSys addition:

```text
SysUtimensat(path, atimeSec, atimeNsec, mtimeSec, mtimeNsec [, flags])
```

or an object/directory-shaped equivalent.

The API MUST support no-follow semantics where the operating system supports setting a symlink's own timestamps.

## 12. Filesystem information

Applications currently parsing `df` should instead consume a native filesystem-information object.

Preferred RxUnixSys addition:

```text
SysStatvfs(path) -> Directory
```

`PosixFilesystemInfo` should expose at least:

```text
blockSize
fragmentSize
totalBlocks
freeBlocks
availableBlocks
totalFiles
freeFiles
filesystemId?        # when safely available
mountFlags?
nameMax
```

The layer should derive byte quantities with integer arithmetic rather than parsing human-readable units.

Mount-point discovery is a separate concern. On Linux it can be supplied by a `/proc/self/mountinfo` provider if required, but `statvfs` itself should remain portable Unix functionality.

## 13. Sparse files

Sparse-file fidelity is optional and explicitly capability-gated.

Preferred Linux/Unix provider where supported:

- `lseek(fd, ..., SEEK_DATA)`
- `lseek(fd, ..., SEEK_HOLE)`

```text
PosixExtent
  offset
  length
  kind = DATA | HOLE
```

`Posix~extents(path)` returns ordered extents and records the provider/capability used. If unsupported, callers may still copy logical bytes but MUST NOT claim sparse-layout preservation.

## 14. Durability primitives

Atomic rename alone is not a complete durable-publication contract. The POSIX layer should provide the primitives; `oorexx_atomic_file` owns the higher-level protocol.

Required capabilities:

```text
fsync(fd)
fdatasync(fd)
open(path, flags, mode)
openat(...)
rename/renameat
parent directory open + fsync
```

Preferred RxUnixSys additions:

```text
SysFsync(fd)
SysFdatasync(fd)
```

`oorexx_atomic_file` then performs the sequence appropriate to its declared durability mode, including same-filesystem staging and parent-directory synchronization where required.

`SysTempFileName` is not an atomic creation primitive and MUST NOT be used as evidence that a temporary pathname remains unused after it is returned.

## 15. Permissions and ownership

Existing `SysChmod`, `SysChown`, and `SysLchown` are authoritative primitives.

The facade adds:

- typed mode handling;
- explicit follow/no-follow policy;
- current-object identity preconditions for sensitive mutation;
- normalized errno evidence;
- optional expected identity (`device`, `inode`) fencing.

Example high-level contract:

```text
PosixMutationOptions
  followLinks
  expectedIdentity
  requireSameFilesystem
```

If the provider cannot safely satisfy `expectedIdentity`, it fails closed rather than performing a check-then-mutate pathname race.

## 16. Recursive deletion

The platform MUST NOT provide a casual `rm -rf` equivalent that follows pathnames without policy.

Two levels are acceptable:

1. **Convenience tree removal** for trusted application-owned trees, clearly named and documented.
2. **Fenced tree removal** using descriptor-relative traversal, no-follow rules, root identity pinning, filesystem-boundary policy, and explicit treatment of special files.

Storage Evacuation, package cleanup, and security-sensitive code should use the second form.

## 17. Credentials and account records

The Unix library already supplies uid/gid getters and passwd/group lookup functions. `oorexx_posix` should convert their option-driven scalar API into immutable typed objects.

```text
PosixCredentials
  uid
  euid
  gid
  egid

PosixUser
  name
  uid
  gid
  home
  shell
  gecos?

PosixGroup
  name
  gid
  members?
```

Do not repeatedly call option-selecting lookup functions after the result is obtained if a coherent structured lookup primitive later becomes available; the same consistency principle as stat applies, although passwd/group records are less time-sensitive than filesystem generation fencing.

## 18. Interaction with `oorexx_process`

POSIX and Process must not absorb each other.

Existing ooRexx already provides:

- `SysFork()` in RexxUtil;
- `SysWait()` in RexxUtil;
- `SysCreatePipe()` in RexxUtil;
- process IDs/signals/groups/sessions in RxUnixSys.

These should be reused when sufficient.

`oorexx_process` still owns the missing managed-execution contract:

```text
argv-preserving spawn/exec
explicit environment overlay
cwd
stdin/stdout/stderr actions
bounded capture
wait for a specific child
nonblocking/timed wait
exit-vs-signal status
cancellation
process-group lifecycle
start identity / PID reuse protection
```

Therefore a future RxUnixSys enhancement should prefer `posix_spawn`/`waitpid`-class primitives rather than another generic shell command runner.

## 19. Provider selection

Applications do not request `RxUnixSysProvider` or `ForeignProvider` directly.

Startup flow:

```text
PosixFactory
  -> verify Unix platform
  -> load RxUnixSys
  -> discover RexxUtil facilities
  -> discover optional extended primitives
  -> discover optional Foreign Runtime/libacl/sparse providers
  -> assemble PosixCapabilities
  -> expose Posix facade
```

Provider provenance is attached to results so qualification evidence can show which implementation path was exercised.

No provider falls back to an external command unless the caller explicitly selected a separately named compatibility/diagnostic adapter. Such an adapter is not part of the default POSIX contract.

## 20. Runtime Registry integration

Suggested capability registration record:

```text
component: oorexx_posix
api: oorexx.posix/0.1
platform: unix
providers:
  primitive: rxunixsys
  portable-file: rexxutil
  extended-stat: rxunixsys-extended | foreign-runtime
  acl: libacl-foreign | unavailable
  sparse: seek-data-hole | unavailable
capabilities: [...]
```

Runtime Registry should report actual executable capabilities, not package-presence assumptions.

## 21. Error and evidence rules

Every evidence-grade operation records:

```text
operation
provider
capability
input path(s)
follow-links policy
result code
errno / errno text on native failure
object identity where observed
```

Evidence MUST NOT contain secrets or unrelated environment state.

Human-readable messages are secondary. Domain code branches on structured fields/capabilities, not message text.

## 22. Security rules

1. Never invoke a shell for ordinary filesystem operations.
2. Never concatenate user path data into a command.
3. Never implicitly call `SysWordexp` on a caller-supplied path.
4. Never treat `exists()` followed by mutation as an authorization fence.
5. Never follow symlinks implicitly in metadata-preservation operations.
6. Never claim an operation is race-resistant unless it is descriptor-relative or otherwise pins the object identity across the mutation.
7. Never equate an empty xattr/directory result with success without disambiguating provider error state.
8. Never degrade an unavailable capability to a shell command silently.
9. Privileged credential/chroot operations require an explicit policy boundary and should not be exposed as casual convenience methods.
10. Recursive deletion must state whether it can cross mount/device boundaries.

## 23. Acceptance tests

### 23.1 Reuse tests

- prove `chmod`, `chown`, `lchown`, link, symlink, mkdir, rmdir, unlink and supported xattr normal paths flow through RxUnixSys;
- prove convenience file operations can flow through RexxUtil;
- grep/qualification test: no production call to `stat`, `find`, `readlink`, `getfattr`, `setfattr`, `getfacl`, `setfacl`, `df`, `chmod`, `chown`, `ln`, `mkdir`, `rm`, `touch` subprocesses in normal POSIX providers.

### 23.2 Stat tests

- regular file, directory, symlink, fifo/device where permitted;
- one-call identity/size/time snapshot;
- `stat` follows symlink and `lstat` does not;
- nanosecond timestamp preservation where supported;
- path replacement race fixture demonstrates that coherent stat never combines fields from two objects.

### 23.3 Directory tests

- empty directory is distinguishable from failed open;
- hidden entries are preserved according to API policy;
- filenames with spaces, tabs, newlines and non-ASCII bytes are not command-parsed;
- hostile symlink replacement during secure traversal fails closed or remains bound to pinned dirfd semantics.

### 23.4 xattr/ACL tests

- zero-length xattr value distinguishable from missing/error;
- binary values round-trip;
- unsupported capability is explicit;
- ACL round-trip where libacl provider exists.

### 23.5 Durability tests

- `fsync` and parent-directory sync primitives are callable and errors surface structurally;
- AtomicFile integration test covers crash points separately; POSIX itself only proves primitives.

### 23.6 Filesystem tests

- `statvfs` numbers are native numeric values;
- sparse extents round-trip/observation when capability exists;
- device boundary identity exposed for traversal policy.

### 23.7 Error tests

- ENOENT, EACCES, ENOTDIR, ELOOP and unsupported-operation paths retain the correct operation/path/provider evidence;
- a subsequent native call cannot overwrite the captured errno in the returned result.

## 24. Consumer migration map

### Storage Evacuation

Use `PosixStat`, `PosixFileIdentity`, `PosixDirectoryIterator`, xattrs, ACL provider, link payloads, times, filesystem identity and secure mutations. This is the highest-value first consumer because metadata correctness and generation fencing are part of its correctness claim.

Do not migrate its current stat-before/stat-after fencing onto repeated scalar `SysStat` calls. Wait for coherent stat/lstat support or use the temporary gap provider.

### QueueRexx

Move ownership/diagnostic `stat` and `chown` helpers onto `oorexx_posix`. Process identity/start-cookie remains with `oorexx_process`, with Linux `/proc` logic as a provider detail where still required.

### LLM Personal Assistant / packaging

Replace `find`, `stat`, `df`, `touch`, link/mkdir/rm shell mechanics with POSIX/RexxUtil facilities according to strength required. Archive operations remain in `oorexx_archive`.

### Release tooling

Use convenience operations for trusted build trees; use fenced traversal when validating hostile/untrusted extracted trees.

## 25. Recommended RxUnixSys extension set

### P0 — correctness enablers

```text
SysStatInfo
SysLstatInfo
SysReadlink
SysFstatatInfo
SysFsync
SysFdatasync
```

### P1 — fidelity / race resistance

```text
SysUtimensat
SysStatvfs
SysOpenat
SysUnlinkat
SysMkdirat
SysRenameat
```

### P1/P2 — process library support

```text
SysPosixSpawn / structured spawn primitive
SysWaitpid / targeted wait primitive
```

The names are proposals; the important requirement is the semantic coverage and structured return values.

## 26. What should remain outside RxUnixSys

Unless the ooRexx project explicitly chooses otherwise, these are better optional providers:

- libacl POSIX ACL operations;
- Linux-only sparse/extent/ioctl specializations;
- Linux `/proc` process start-cookie observation;
- filesystem-specific snapshot operations (Btrfs/ZFS/LVM);
- fanotify/inotify monitoring;
- cloud filesystem APIs.

They are not common Unix base primitives and should not distort the core Unix extension library.

## 27. Implementation sequence

### Step 1 — facade with zero new native code

Implement typed wrappers for existing RxUnixSys/RexxUtil operations, error normalization, capability discovery, and tests. This immediately eliminates new shell-command growth for chmod/chown/link/mkdir/unlink/xattrs/account lookup/basic listing.

### Step 2 — coherent stat/lstat/readlink gap provider

Implement the three critical metadata primitives. During development they may use a Foreign Runtime bridge. Keep the class boundary identical to the intended RxUnixSys extension so the provider can later be swapped without consumer changes.

### Step 3 — Storage Evacuation integration

Move metadata probe/materialization to the facade while retaining its existing consistency semantics. Do not weaken generation fencing for migration convenience.

### Step 4 — precise times/statvfs/durability

Add `utimensat`, `statvfs`, `fsync`/`fdatasync`, then build AtomicFile on top.

### Step 5 — descriptor-relative traversal

Add the `*at` family and secure directory iterator. Migrate recursive deletion and hostile-tree package validation.

### Step 6 — optional fidelity providers

Add ACL and sparse extent support; qualify them per platform.

## 28. Architectural decision

The POSIX foundation should be deliberately boring:

> **ooRexx already has a Unix primitive library. Use it. The new package exists to make those primitives composable, typed, explicit about evidence and errors, and strong enough for the handful of operations whose current contracts are too weak.**

This gives the estate one maintainable operating-system boundary without creating a competing Unix subsystem.
