# Host filesystem mount / verified backup floor

Storage Fabric v0.1-dev21 provides `storage.fabric.host-filesystem/0.1` as the
mechanical host-disk seam needed by backup/evacuation tasks.

The module does **not** decide backup priority, retention, exclusions, source
cleanup or scheduling.  Those belong to the task/orchestration layer.

## Two deliberately asymmetric mounts

```text
Linux source root
    StorageHostFilesystemMount(mode=READ_ONLY)
           |
           | bounded reads only
           v
StorageHostVerifiedCopy
           |
           | resumable checkpoint
           | SHA-256 verify
           v
StorageHostFilesystemMount(mode=WRITE_COMMIT)
    USB / durable destination root
```

`READ_ONLY` is enforced by the Storage mount object even if Linux currently has
the underlying filesystem mounted read/write.  `kernelReadOnly` reports the
independent Linux mount fact so a backup task can require both when runlevel-1
or rescue-mode remounting permits it.

`WRITE_COMMIT` requires the small `storage-host-commit` helper.  The helper is
source-owned by this package and built by `native/build-host-filesystem.sh`.

## Reliable regular-file commit

One regular-file transfer follows this mechanical state flow:

1. capture exact source metadata/fingerprint;
2. copy through Storage's bounded-memory `StorageResumableTransferEngine`;
3. write only to a deterministic hidden `.sf-partial-*` file;
4. `fdatasync()` the partial before every durable checkpoint advance;
5. independently SHA-256 the source and partial destination;
6. re-probe the source fingerprint before publication;
7. publish with atomic `renameat2(RENAME_NOREPLACE)` where supported, otherwise the no-replace hard-link fallback;
8. `fdatasync()` the published file and `fsync()` the containing directory;
9. remove the hidden partial and `fsync()` the directory again;
10. only then advance the Storage transfer to `COMMITTED`.

Publication is intentionally no-replace.  A committed pathname is never silently
overwritten.  Repeating the same verified content is idempotent; a different
digest at the same final pathname fails closed.  Linux `renameat2` with
`RENAME_NOREPLACE` is preferred, with the dev19 hard-link route retained as a
compatibility fallback.  The fallback also recognises the crash state where
partial and final already name the same inode.

## Resume

The existing two-slot Storage transfer checkpoint remains authoritative for byte
progress.  The partial pathname is derived from:

```text
mount identity + transfer id + final relative path
```

so a restarted task opens the same partial file at the exact checkpoint offset.
If the source identity changed, the existing Storage checkpoint identity check
rejects resume rather than continuing against newer source bytes.

## Path confinement

Host mounts accept only Storage-relative paths.  Absolute paths, `.` / `..`,
empty path components and NUL are rejected.

Source regular-file opens canonicalise the actual target and require it to
remain beneath the mounted root.  Symlinks are returned as metadata and are not
silently followed as regular backup content.

Destination directory creation is segment-by-segment.  Existing components must
be real directories; symlink components are rejected.  Existing final and
partial entries must be real regular files and canonicalise inside the
configured destination root.

This is a Linux/POSIX qualification seam, not a claim that ordinary pathname
checks alone provide a hostile multi-user sandbox.  The intended backup run also
uses a quiet rescue/runlevel-1 system, and the native publication helper uses
`O_NOFOLLOW` for durability operations.

## Mount example

```rexx
helper='/opt/storage-fabric/build/storage-host-commit'
source=.StorageHostFilesystemMount~new('machine-root','/','READ_ONLY',helper)
usb=.StorageHostFilesystemMount~new('usb3-backup','/mnt/backup-usb','WRITE_COMMIT',helper)

say 'Storage source policy read-only:' source~readOnly
say 'Linux source mount actually ro:'  source~kernelReadOnly
say 'USB Linux mount actually rw:'     usb~kernelReadWrite
```

The higher backup task may then enumerate `source~list(...)`, assign its own
priority, and invoke `StorageHostVerifiedCopy~copyFile(...)` for the selected
regular file.  It remains responsible for what is selected and in what order.

## Non-claims

This dev20 seam deliberately does not:

- delete or rename anything in the source mount;
- decide which pseudo-filesystems or mount points belong in a backup;
- provide retention/version pruning policy;
- claim filesystem snapshots where the source filesystem has none;
- turn symlinks, devices, sockets or FIFOs into ordinary file bytes;
- infer backup priority;
- overwrite a previously committed destination pathname.

Directory/symlink metadata is observable through `StorageHostEntry`.  Higher
backup/evacuation logic may preserve richer POSIX ACL/xattr/hard-link semantics;
this module remains the byte and publication floor underneath that policy.

## Large-file precision (dev21)

Host file sizes and Storage streaming offsets are exact under a package-owned 30-digit arithmetic context. This is required because ooRexx callers normally enter at 9 digits, while ordinary Linux files exceed nine decimal digits well below 2 GiB. The caller numeric context must not change the source fence, checkpoint offset or final EOF calculation.

## Backup-task handoff (dev20)

`bin/storage-host-backup-floor` is the narrow machine-facing handoff for the
prioritised backup task.  It intentionally contains no selection or priority
logic.

```text
bin/storage-host-backup-floor preflight SOURCE_ROOT DEST_ROOT [REQUIRE_KERNEL_RO] [ALLOW_SAME_FILESYSTEM]
bin/storage-host-backup-floor copy SOURCE_ROOT DEST_ROOT SOURCE_REL DEST_REL TRANSFER_ID [CHECKPOINT_REL]
bin/storage-host-backup-floor verify SOURCE_ROOT DEST_ROOT SOURCE_REL DEST_REL
```

The wrapper preserves arbitrary POSIX path whitespace/newlines by hex-encoding
arguments before entering ooRexx.  Replies use a single `SFHOST1` tab-framed
record with hex-valued fields so the audit/priority task can parse them without
confusing pathname text with protocol framing.

Production preflight requires source and destination roots to be different
filesystem devices.  The checkpoint directory defaults to
`.storage-fabric/checkpoints` on the destination mount, so resume evidence stays
with the backup disk rather than the machine being protected.  An
`ALLOW_SAME_FILESYSTEM` escape exists only for controlled qualification; the
backup task should not use it for the real USB run.

A root source mount records its backing filesystem device.  Entries on another
device remain observable, but `byteSource` refuses their contents.  Therefore a
root audit can see a mount boundary and decide whether to create another Storage
source mount for that filesystem; Storage will not blindly cross it.

`preflight` also runs the actual destination commit helper against a tiny,
self-cleaning scratch directory.  A filesystem that cannot provide the required
no-replace publication and durability primitives is rejected before user bytes
are copied.


## Canonical checkpoint numeric evidence (dev22)

Transfer checkpoints are durable recovery evidence, not formatted operator output.  All non-negative integer fields are therefore written as plain canonical decimal digits.  A token such as `2.18468359E+9` is rejected on load even if a numeric comparison under some precision context could round it to the same apparent value.  Backup recovery must never depend on scientific-notation rendering or rounded checksums.
