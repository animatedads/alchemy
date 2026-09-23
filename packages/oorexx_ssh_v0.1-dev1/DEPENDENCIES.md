# Dependencies

Hard:

* ooRexx 5.3.0 r13196 qualification baseline
* ooRexx Foreign Runtime v0.22.6 or compatible `MAIN >= 22`
* native SSH provider; first provider is libssh with client+server capability

Optional:

* Logging v0.7
* Secret Broker / credential authority
* Storage Fabric adapters in consumers

`libssh2` may be useful for client-only work but is not the server foundation because this project requires resident Rexx-space endpoints.
