# Storage Fabric service admission — 23 October 2026

The optional StorageNetworkServices.cls remains socket-neutral. Only operations mapped to a canonical service through StorageNamedServiceRoutes are required to enter on an admitted XTP named context. Unbound operations continue over ordinary authenticated Socket Provider or QueueRexx paths.

## Ingress repair

The earlier guard checked the incoming service name only *when a socket happened to be supplied*. A registered READ with no socket slipped through. The repaired guard now requires a context reporting serviceName, serviceAdmitted and authenticatedPeerId. It rejects absent, unadmitted, mismatched and untrusted peer contexts. The caller-supplied authenticatedNodeId must match the context identity. The trusted listener/transport implementation, not request JSON, must supply these fields. Unbound LIST remains available over authenticated ordinary sockets.

## Qualification

Native ooRexx r13196 test_network_services.rex passed locally on 2026-10-23, including no named fallback, wrong service, cross-peer identity, unadmitted context and ordinary LIST. No live XTP TLS/authentication, FIRST-to-KEY persistence, ED209 WAN, multicast, or Azure Git recovery has been tested in this increment.

The existing GitHub Storage Gopher sphere source is v0.3; the Library contains a complete v0.7 sphere, from which a local v0.8 sphere continuation has been produced and JSON/checksum checked. This GitHub sphere article is an additive repository projection only; do not treat v0.3 as a replacement for the newer Library sphere or claim Gopher v0.8 runtime qualification.
