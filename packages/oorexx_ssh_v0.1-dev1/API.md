# API

API: `ssh/0.1`

Primary classes:

* `SshForeignLibsshProvider(bridgePath, minimumServerVersion='0.11.5')`
* `SshServer(provider, registry, authority)`
* `SshEndpointRegistry`
* `SshEndpointRequest(kind,name,channel,session,metadata)`
* `SshEndpointAuthority`

`SshEndpointRegistry` methods:

* `registerSubsystem(name, handler)`
* `registerExec(verb, handler)`
* `registerShell(handler)` — explicit; there is no implicit shell
* `resolve(request) -> SshEndpointDecision`

`SshServer~resolve(identity,request)` performs endpoint authority before registry dispatch.

The libssh bridge is deliberately transport-level.  It must not own SFTP, SCP, Storage Fabric, Queue, or shell semantics.
