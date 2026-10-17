# Storage Fabric — optional network capabilities (candidate 5)

This patch **does not** turn XTP into a hard dependency and does not replace `StoragePeerSocketPort`, `StoragePeerService`, QueueRexx, Storage authority, or Azure Git.

Sources reviewed: XTP dev22 (`XtpNamedServiceManager`, FIRST-name descriptor and multicast), Service Descriptors dev2, Operational Degradation Planner dev2, Socket Provider dev16 and Storage Fabric integration candidate4.

## Resolution and admission

- Ordinary `SocketProvider`/TCP/IP/UNIX/QueueRexx path is available when no advanced named-service binding is configured for a destination and operation.
- `StorageNamedServiceRoutes` holds **administrator-provisioned** mappings `(nodeId, operation) -> (registered service, expected logical routePeer)`. Neither names nor IP addresses are invented from filenames.
- With a mapping, `StorageServiceNetworkPort~sender` resolves the authoritative Service Descriptor Registry entry. Disabled, removed, wrong-route, planner-denied and ungoverned-capacity entries are **not downgraded to raw TCP**. Fallback is for *capability absence*, never bypassing a security/policy decision.
- XTP dev22 `XtpNamedServiceManager~sender` inserts the named-service segment in FIRST; libxtp resolves L2/L3/L4 routes. The authoritative operational class is **read from the descriptor**, never supplied by a client payload. The intended class for Storage is `normal.storage` where registered by the estate authority.
- For incoming named sockets, `StorageNamedInboundGuard` checks FIRST-selected service versus the requested Storage operation and passes separately authenticated peer identity to existing `StoragePeerService~handleFrom`. It does **not** claim FIRST alone proves an authenticated principal.
- The current dev22 operational sender gates and sets priority, but cannot be assumed to enforce all dev2 capacity caps. `StorageServiceNetworkPort` refuses constrained named traffic unless a real injected governor implements context admission **and** per-context/aggregate rate enforcement. Parallel source ranges must be scheduler-admitted; no unrestricted fan-out.

## Discovery and multicast

`StorageMulticastDiscovery` works with any injected multicast-capable sender (native XTP multicast, UDP/IP multicast, NORM, etc.). No multicast provider: it reports unavailable, and the existing authenticated unicast or QueueRexx discovery continues.

Only bounded digest+challenge `SEARCH` and `OFFER` hints are emitted; the transport/operations layer owns sender auth and multicast group membership. Multicast discovery is not a trustworthy file listing, an authentication mechanism or evidence of a durable replica. Every response must be resolved over an authenticated Storage peer catalogue/HAVE/STAT read and bytes must be verified SHA-256 before replica admission. Avoid broadcasting virtual paths, descriptions, credentials, filenames or physical locators.

`StorageSourceRangeOffer` represents a source's **explicit immutable byte range**. Allocation across MI/MU nodes, concurrency, rate limits and the durable final catalogue commit remain external owner decisions.

## Operator provisioning

Provision stable named search/acquire services through `ServiceRegistry`, bound to logical XTP route peers with the registered operational class `normal.storage`, and ensure the planner has explicit normal/degraded states. Avoid storing IP addresses in service descriptors; the XTP ROUTE table holds actual network coordinates. The class remains registry-owned.

No live registration, route changes, multicast joining, backend socket acquisition, Azure Git mutation or node commissioning is performed by this candidate. The native integration tests use injected sockets and a fake class planner. Live MI/MU source range, rate-governor and multicast validation is still required.
