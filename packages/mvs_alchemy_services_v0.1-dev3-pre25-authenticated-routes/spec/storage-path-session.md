# MAS Storage PATH session contract — pre8

The guest-facing transport is deliberately separate from PATH semantics.

Operations:

- `OPEN(path, PATHOPTS, FILEDATA) -> handle`
- `READ(handle) -> bytes`
- `WRITE(handle, bytes) -> count`
- `APPEND(handle, bytes) -> count`
- `CLOSE(handle) -> StorageRef`
- `STAT(path, view) -> metadata`
- `LIST(path) -> namespace entries`

A transport implementation may be DYN75, DIAG8, a socket, a spool/request queue,
or another qualified guest/host carrier. The carrier does not parse Storage
Fabric objects and does not own PATH semantics.

Closing a dirty/create handle publishes a new immutable StorageRef. The current
namespace binding advances to that ref; earlier refs remain catalogue history.

pre8 does not claim that MVS 3.8J JCL `PATH=` is intercepted live. That remains a
separate guest-adapter qualification gate.
