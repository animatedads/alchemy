# Storage Fabric SSH/SFTP integration

API: `storage.fabric.sftp/0.1`

## Purpose

`StorageSftpBackend` adapts the existing ooRexx SFTP v3 backend contract to
`StorageFuseOperationCore`.  An SSH subsystem can therefore expose a selected
Storage namespace directly without mapping Storage identity to a host pathname.

```text
client
  |
  | SSH encrypted channel
  v
oorexx_ssh endpoint authority
  |
  | subsystem "sftp"
  v
oorexx_sftp SftpEndpoint
  |
  v
StorageSftpBackend
  |
  v
StorageFuseOperationCore
  |
  v
Storage namespace / generations / streams
```

## Authority boundaries

- SSH owns transport, cryptographic/user attribution and endpoint authority.
- SFTP owns packet framing, request semantics and protocol handles.
- Storage Fabric owns namespace/object identity, versions, streams and mutation semantics.
- The adapter defaults to read-only; mutations must be enabled explicitly.
- No implicit shell endpoint is introduced.

## Registration

```rexx
core = .StorageFuseOperationCore~new
factory = .StorageSftpBackendFactory~new(core, "/exports", .false)
registry~registerSubsystem("sftp", factory~subsystemHandler)
```

The Storage root is a namespace prefix.  It is not a physical filesystem path.

## Supported dev18 operations

The adapter covers the SFTP dev1 backend operations used by the SFTP v3 engine:

- stat/lstat/fstat projection;
- open/create/truncate;
- bounded read/write and append;
- directory listing;
- mkdir and empty-directory rmdir;
- file rename;
- file remove.

Storage's own FUSE semantics remain authoritative.  For example, frozen views
remain read-only and `rmdir` never means recursive subtree deletion.

## SCP

The supplied `oorexx_ssh_v0.1-dev1` package explicitly states that SCP is not
implemented in that package; SCP is a sibling consumer of the SSH transport.
Storage Fabric dev18 therefore does **not** claim SCP support and does not fake
SCP by running a shell command.

When an ooRexx SCP protocol endpoint exists, it should terminate against the
same Storage semantic authority used here rather than inventing a second
remote-file identity model.

## Qualification baseline

- ooRexx 5.3.0 r13196;
- Storage Fabric v0.1-dev18;
- ooRexx SSH v0.1-dev1;
- ooRexx SFTP v0.1-dev1;
- Foreign Runtime v0.22.6.

The dev18 integration test exercises real SFTP v3 request/response frames into
the Storage backend.  It does not claim a live network listener because the
supplied SSH handoff records the qualification host's libssh 0.11.2 as below
the package's default >=0.11.5 server gate.
