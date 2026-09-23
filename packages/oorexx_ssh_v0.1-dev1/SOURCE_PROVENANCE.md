# Source provenance

Design baseline: ooRexx 5.3.0 r13196, Foreign Runtime v0.22.6, and the installed ooRexx `rxftp.cls` API precedent.

The native provider surface follows libssh's public client/server/message/channel API.  SFTP is intentionally not delegated to an external `sftp-server` process.
