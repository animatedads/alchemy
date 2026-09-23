# ooRexx SSH v0.1-dev1

A Foreign-Runtime-backed SSH foundation whose first-class endpoints are ooRexx objects, not operating-system commands.

The governing rule is:

> SSH transports typed Rexx endpoints; a shell is only an optional endpoint implementation.

This first development cut establishes:

* hard dependency on ooRexx Foreign Runtime;
* native libssh provider discovery and owned native session/bind handles;
* explicit security-version gate for server mode (default minimum 0.11.5);
* endpoint request/registry model for `subsystem`, `exec`, and optional `shell` requests;
* deny-by-default shell and unknown-endpoint behavior;
* endpoint authority separate from SSH authentication;
* a libssh bridge surface sufficient for the next live server-loop cut.

It does **not** yet claim a live network listener.  The next cut will bind the message/channel loop to this endpoint registry and then host `sftp` directly in Rexx space.
