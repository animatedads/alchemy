# Architecture

```
OpenSSH / SFTP client
       |
       | SSH encrypted channel
       v
oorexx_ssh (Foreign Runtime + native SSH)
       |
       | subsystem "sftp"
       v
SftpEndpoint (Rexx)
       |
       +-- Storage Fabric backend
       +-- application virtual namespace
       `-- qualification memory backend
```

The SFTP endpoint owns protocol semantics and virtual handles.  The backend owns object/path semantics.  Neither requires `/bin/bash`, `/usr/lib/openssh/sftp-server`, nor a host pathname.

All paths are canonicalized under a virtual root.  `..` cannot escape that root.
