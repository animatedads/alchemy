# Known gaps

* Live SSH channel framing/loop not yet connected.
* SETSTAT/FSETSTAT, READLINK/SYMLINK and extensions are currently OP_UNSUPPORTED.
* No Storage Fabric backend in this package yet.
* No client-side SFTP session API yet; dev1 prioritizes the Rexx-space endpoint.
* Directory READDIR is one batch in the reference backend; production backends need bounded pagination.
