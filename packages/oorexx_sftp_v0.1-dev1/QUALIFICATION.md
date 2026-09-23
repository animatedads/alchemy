# Qualification

Dev1 tests cover:

1. binary u32/u64/string/frame codec round trips;
2. virtual-root path normalization and escape rejection;
3. INIT/VERSION negotiation;
4. OPEN/WRITE/READ/CLOSE exact bytes including handle use;
5. OPENDIR/READDIR/EOF;
6. MKDIR/RENAME/REMOVE/RMDIR;
7. independent read/write request bounds;
8. registration as an SSH `sftp` subsystem while shell remains denied.

No live SSH socket is claimed by this cut; live channel binding belongs to the next SSH/SFTP integration step.
