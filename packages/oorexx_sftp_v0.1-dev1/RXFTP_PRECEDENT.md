# rxftp.cls precedent

The ooRexx distribution supplies `rxftp.cls`, an FTP client class replacing the old function library.  Its public design demonstrates useful conventions for this family:

* an object instance owns its connection/session state;
* multiple independent sessions can coexist;
* protocol functionality is available as a library rather than only an external command;
* public methods return Rexx objects/arrays rather than requiring classic stems.

SFTP does not reuse FTP wire logic.  The precedent is API shape and library placement only.
