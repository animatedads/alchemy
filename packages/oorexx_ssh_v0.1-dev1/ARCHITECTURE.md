# Architecture

```
TCP -> libssh -> Foreign Runtime -> ooRexx SSH session/channel -> endpoint registry
                                                        |-> subsystem:sftp -> Rexx SFTP endpoint
                                                        |-> exec:name      -> registered Rexx object
                                                        `-> shell           -> DENY unless installed
```

Authentication establishes cryptographic/user attribution.  Endpoint authority is evaluated separately.

No endpoint registration may imply shell interpretation.  Exec dispatch recognizes one registered verb and passes the original request to the handler; it is not a shell parser.
