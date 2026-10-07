# Security boundary

The WebSocket edge is not a general Queue Fabric client and the browser is not given Queue Fabric credentials.

Gateway-private material:
- Queue Fabric principal
- Queue Fabric claim token
- private bridge token
- authoritative Queue Fabric OUT queue
- underlying `ObjectQueueManager`

Browser-visible material:
- opaque `deliveryId`
- Queue Fabric package identity/provenance already intended for delivery
- semantic Wire UI payload
- `QUEUE_PUT_RESULT` correlated to browser-generated `clientPutId`
- browser-safe bootstrap: exact Wire UI ownership, module URL, WebSocket URL and fixed browser PUT queue

The browser cannot choose arbitrary Queue Fabric queues. The Node edge validates the requested PUT queue against its configured access-point binding before using the private backend.

`WireUIWebAccessPointBinding` derives queue names from `WireUIServer` and provisions ACLs through the server; it does not create an alternative naming or authority model.

The optional path token is only an access-point/development binding mechanism. Production deployment must still supply suitable TLS, origin/authentication policy, token lifetime/rotation, and reverse-proxy controls.

Application/security authority remains outside the gateway. Wire UI/FlyLo must still validate session ownership, rendered revision, semantic action, and business authorisation. AI/provider secrets and payment credentials never belong in browser bootstrap.
