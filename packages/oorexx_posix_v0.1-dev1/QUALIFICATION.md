# Qualification

Qualified against the supplied ooRexx 5.3.0 r13196 Unix/Linux debug package without installing it system-wide.

Executed coverage includes:

- default provider capability discovery;
- mkdir/unlink/rmdir;
- hard and symbolic links;
- scalar stat explicitly remaining non-coherent;
- coherent native stat/lstat with device+inode identity and nanosecond timestamps;
- stat-follow vs lstat-no-follow semantics;
- readlink payload;
- structured ENOENT failure evidence;
- credentials and passwd lookup;
- group lookup fail-closed guard;
- xattr strong-vs-weak contract;
- directory names containing spaces, tab, newline and leading dot;
- source boundary check for shell/system command regressions.

The temporary native module is compiled from source during qualification. No platform-specific binary is required as source authority.
