# FUSE3 integration boundary — Storage Fabric v0.1-dev10

## What dev10 contains

dev10 contains all three layers required for the first real mount:

```text
Linux VFS / libfuse3
        |
        v
native/storage_fuse3.c          thin callback/RPC adapter
        |
        | AF_UNIX, SF1, mode 0600
        v
bin/storage-fuse-rpcd.rex       resident ooRexx authority
        |
        v
StorageFuseOperationCore        namespace/generation/snapshot semantics
```

The native process does not decide what `:frozen`, `:gN`, alternate streams,
release, rename, snapshot publication or generation pinning mean.  Those remain
owned by ooRexx.

## Current qualification status

The qualification container has no `/dev/fuse`, `fusermount3` or libfuse3
installation, so no kernel mount is claimed here.

Qualified in dev10:

- all ooRexx operation-core regression tests;
- `SF1` RPC codec and dispatcher, including binary NUL-containing data;
- live resident RPC daemon over ooRexx Unix Socket v0.6 and Foreign Runtime
  v0.22.6;
- AF_UNIX authority socket mode `0600`;
- native protocol helper strict C compilation/execution;
- complete libfuse3 callback adapter strict syntax compilation against a local
  signature stub matching the used FUSE3 high-level callback surface.

The next gate is intentionally simple: build with the target node's real
`pkg-config fuse3`, mount it, run `deploy/fuse-soak.sh`, then leave it running.

## Callback map

| libfuse3 operation | SF1 / ooRexx operation |
| --- | --- |
| `getattr` | `GETATTR` -> `StorageFuseOperationCore~getattr` |
| `readdir` | `READDIR` -> `~readdir` |
| `open` | `OPEN` -> `~open` |
| `create` | `CREATE` -> `~create` |
| `read` | `READ`, or `VREAD` for system streams |
| `write` | `WRITE` -> `~write` |
| `release` | `RELEASE` -> `~release` |
| `mkdir` | `MKDIR` -> `~mkdir` |
| `truncate` | `TRUNCATEH` / `TRUNCATE` |
| `unlink` | `UNLINK` -> `~unlink` |
| `rename` | `RENAME` -> `~rename` |
| synthetic frozen release | `RMDIR` on `dir:frozen` |

The server's `hN` handle is represented as an integer in `fuse_file_info.fh`;
the C shim reconstructs the `hN` token on subsequent callbacks.

## First-mount I/O policy

The first qualification line deliberately chooses correctness before cache
performance:

- libfuse is run single-threaded (`-s`);
- every opened data file sets `direct_io=1`;
- `keep_cache=0`;
- writable mmap is not claimed;
- FUSE writeback caching is not enabled.

The reason is architectural, not merely conservative: the ooRexx generation
engine must see writer opens, writes and releases in authority order.  A kernel
page cache silently retaining later mutation would create a second filesystem
truth and invalidate the atomic snapshot proof.

After the single-thread/direct-I/O soak is clean we can qualify concurrency and
cache modes individually.

## Pending snapshot behavior

`dir:frozen` acquisition may encounter a file handle opened before the barrier.
The snapshot enters `WAITING_FOR_HANDLES`; no partial membership is exposed.
`readdir` returns `EAGAIN` until the final old writer releases.

The FUSE daemon must therefore never synchronously wait for that writer inside
the callback that installed the barrier.  The writer's later `release` callback
is what can publish the snapshot.

## Exact-generation handoff

`:frozen` is a moving convenience selector.  Any downstream authority such as
Storage Evacuation receives an immutable exact root such as:

```text
/mnt/storage/database:g471
```

Never hand a long-lived consumer `/mnt/storage/database:frozen`.

## Alternate streams

Unknown colon suffixes on the final component remain application streams:

```text
file.dat:thumbnail
file.dat:1
```

They have independent bytes, are not directory entries, and are frozen with the
object generation.  dev10 lets FUSE `CREATE` create a previously absent named
stream on an existing base file.

System streams remain `$`-prefixed, for example `dir:$status` and
`dir:$history`.

## Continuous ED209 qualification

Once a real mount passes on one node, run:

```sh
deploy/fuse-soak.sh /path/to/mount 0
```

`0` means indefinitely.  Each iteration proves:

1. an already-open writer keeps generation S draining;
2. `:frozen` is not partially published;
3. a new post-barrier handle writes only to S+1;
4. the old S handle's later writes survive in S and are mirrored to S+1;
5. a post-barrier-created file is absent from S membership;
6. an application named stream freezes with its containing object;
7. exact `:gN` bytes do not change after later live writes;
8. releasing `dir:frozen` never removes the live directory.

After local success on two ED209 nodes, `deploy/two-node-soak-controller.sh`
starts the same indefinite workload on both.  Selection of which two nodes is
explicit at invocation time; the script does not bake provider assumptions into
the test.

## v0.1-dev12 — foreign derivative authority

The native FUSE bridge is now described as a foreign component rather than an
incidental binary produced by a deployment shell script.

Storage Fabric owns `foreign/storage-fuse3.json`: source identity, expected
native API, output, target requirements, build recipe, probe contract and
qualification gates.  `OOREXX_PACKAGE.json` exposes the executable subset to
Preferred Packager.

The package intentionally does not ship this qualification host's protocol-test
binary as a reusable FUSE artefact.  `build/storage-fuse3` is a target
derivative.  Preferred Packager decides whether a supplied derivative can be
reused or whether `native/build-fuse3.sh` must execute, then hashes, probes,
qualifies and seals the exact result before COMMIT.

`deploy/start-fuse.sh` correspondingly refuses to build a missing binary at
runtime.  Runtime activation must not create an unqualified foreign component.
Developer source trees may opt into a local build with
`STORAGE_FUSE_DEV_BUILD=1`.

The native binary now implements `--storage-fuse-probe`, which exercises the
linked libfuse runtime and declares `storage.fabric.fuse.native/0.1`, `SF1`, and
the direct-I/O first-mount contract.  `native/probe-fuse3.sh` is the Packager
probe and `native/qualify-fuse3.sh` is the pre-COMMIT qualification entrypoint.

A separate `deploy/qualify-fuse-mount.sh` is the real kernel gate.  It refuses
to convert absence of `/dev/fuse` into success, mounts through libfuse3, runs
one complete generation/snapshot soak iteration, and unmounts cleanly.

Before attempting the first ED209 build/mount, `deploy/fuse-preflight.sh` reports
kernel FUSE, fusermount3, compiler, pkg-config/libfuse3 >= 3.5, ooRexx and the
state of the target derivative without modifying the host.

## Field qualification update — ED209A / ED209B

The original dev12 build-host boundary (no `/dev/fuse`) has now been crossed on
real ED209 targets.

ED209A field evidence supplied by the deployment operator:

- Oracle Linux 9.8;
- `fuse3-devel-3.10.2-9.el9`;
- exact dev12 ZIP SHA-256
  `7b0289452eeb003613fd48267f00abca8a475fe1a80dfb2b26804bb0fca4d5dd`;
- target-local `storage-fuse3` build and native self-probe PASS;
- target-compatible Foreign Runtime selected rather than an ABI-incompatible
  same-version derivative;
- Unix Socket v0.6 bridge metadata supplied;
- genuine `/dev/fuse` mount visible as `fuse.storage-fuse3`;
- normal VFS create/read/write/copy/rename/unlink/traversal PASS;
- named-stream access and hidden enumeration PASS;
- frozen default + named-stream generation isolation PASS;
- pre-barrier writer draining and dual-generation mirroring PASS;
- 100/100 torture iterations, generations 4-103, failures 0, rc 0.

ED209B field evidence at the dev13 packaging point:

- same exact dev12 ZIP digest verified;
- `fuse3-devel` installed;
- B's own target-compatible Foreign Runtime selected;
- target-local native build/probe PASS;
- persistent genuine FUSE mount PASS;
- manual VFS create/read PASS;
- one dual-generation soak iteration PASS;
- the 100-iteration run was in progress and is not claimed by this package
  unless a later field receipt records its completion.

These are field qualification observations, not evidence generated by the
package-build host.  Every new target still requires its own native derivative
probe and live `/dev/fuse` qualification.
