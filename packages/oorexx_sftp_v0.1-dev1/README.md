# ooRexx SFTP v0.1-dev1

SFTP v3 protocol functionality as an ooRexx library and, critically, a Rexx-space SSH subsystem endpoint.

This is **not** FTP-over-SSH and does not invoke an external `sftp-server` process.

The installed ooRexx `rxftp.cls` is an API precedent: file-transfer protocol functionality can be a reusable Rexx class with per-instance state.  SFTP wire semantics remain completely separate from FTP.

Dev1 implements a bounded server-side SFTP packet engine with INIT/VERSION, OPEN/CLOSE, READ/WRITE, STAT/LSTAT/FSTAT, OPENDIR/READDIR, REALPATH, MKDIR/RMDIR, REMOVE and RENAME.  Unsupported operations return `SSH_FX_OP_UNSUPPORTED` rather than falling through to host filesystem behavior.

A backend is a Rexx object.  The included memory backend proves that the SFTP namespace does not need to be a POSIX filesystem.  Storage Fabric is the intended first external backend.
