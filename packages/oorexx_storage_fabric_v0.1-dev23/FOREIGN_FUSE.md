# Storage Fabric foreign FUSE artefact contract — v0.1-dev12

Storage Fabric owns the declaration of the native FUSE component.  Preferred
Packager owns installation policy and target derivative authority.

The governing transaction rule is:

```text
Storage Fabric package
    describes source + build recipe + probe + qualification requirements
                    |
                    v
Preferred Packager RUN on the target
    supplied derivative usable? ---- yes ----> probe/qualify it
                 |
                 no
                 v
    execute declared build recipe
                 |
                 v
    hash exact target derivative
                 |
                 v
    execute declared probe + qualification
                 |
                 v
    seal derivative into transaction
                 |
                 v
             COMMIT eligible
```

Compilation success is not installation authority.  A target derivative is
usable only after the packager has bound its exact bytes to successful target
probe/qualification evidence and sealed them into the transaction.

## Authoritative declaration

`foreign/storage-fuse3.json` is the Storage-owned detailed declaration.
`OOREXX_PACKAGE.json` carries the subset understood by
`oorexx.package/0.1` Preferred Packager.

The component is:

- id: `storage-fuse3`
- API: `storage.fabric.fuse.native/0.1`
- RPC protocol: `SF1`
- source: `native/storage_fuse3.c`
- output: `build/storage-fuse3`
- target policy: `reuse-if-loadable-else-rebuild`
- required target build capability: C11 compiler + `pkg-config fuse3`

## Probe contract

A candidate derivative must execute:

```sh
build/storage-fuse3 --storage-fuse-probe
```

and identify the expected native API, SF1 protocol and direct-I/O first-mount
contract.  The probe calls the linked libfuse runtime, so merely possessing an
ELF file of the right name is insufficient.

`native/probe-fuse3.sh` implements the package-facing probe.

## Pre-COMMIT qualification

`native/qualify-fuse3.sh` requires:

1. the target derivative self-probe to pass;
2. the complete FUSE3 callback adapter to compile strictly against the pinned
   callback signature surface;
3. SF1 binary framing helpers to compile and execute;
4. the ooRexx FUSE RPC dispatcher regression to pass.

These checks are safe before activation and are suitable for the Preferred
Packager RUN transaction.

## Kernel-mount qualification

Actual `/dev/fuse` qualification remains a stronger target acceptance gate:

```sh
deploy/qualify-fuse-mount.sh MOUNTPOINT [STATE_DIR]
```

It requires a real `/dev/fuse`, `fusermount3`, a Packager-qualified
`build/storage-fuse3`, and the runtime ooRexx Unix Socket / Foreign Runtime
REXX_PATH.  It performs a real mount and one full atomic-snapshot soak
iteration.  Absence of kernel FUSE exits 77 and is never reported as PASS.

After that gate succeeds, the intended ED209 acceptance is:

```sh
deploy/fuse-soak.sh MOUNTPOINT 0
```

on two explicitly selected ED209 nodes.

## Runtime must not rebuild

`deploy/start-fuse.sh` will not silently compile a missing native artefact.
Package installation is expected to provide a qualified derivative.  A source
tree developer may explicitly set `STORAGE_FUSE_DEV_BUILD=1`; that path is
marked as a development build and is not package/COMMIT authority.
