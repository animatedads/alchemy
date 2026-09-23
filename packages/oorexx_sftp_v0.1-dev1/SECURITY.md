# Security

* SFTP is a subsystem endpoint, not a shell command.
* Backend path resolution is virtual-root bounded; `..` escape and NUL are rejected.
* Packet size is bounded (16 MiB framing ceiling in dev1).
* READ and WRITE have independent configurable per-request byte bounds (1 MiB defaults).
* Unknown handles fail closed.
* Unsupported operations return OP_UNSUPPORTED.
* There is no implicit host-filesystem backend in dev1.
* Authentication/identity and endpoint authority are supplied by `oorexx-ssh`; SFTP does not reinterpret them.
