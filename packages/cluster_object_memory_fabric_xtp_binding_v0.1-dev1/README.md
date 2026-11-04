# Cluster Object Memory Fabric XTP binding v0.1-dev1

This is the cluster-owned composition layer that connects `cluster.object.peer/0.2` to the protected Queue Fabric XTP session transport without moving resident Memory Fabric payloads.

It does **not** modify XTP, Queue Fabric, Memory Fabric, Job-to-Node, LDAP, Secret Broker, HTTPS or Audio ownership.

## What it delivers

`ClusterObjectXtpRouteFactory` builds a `QueueXtpSessionWire` + `QueueXtpReceiptGate` + `QueueChannelFabric` + existing `ClusterObjectQueueFabricClientTransport` composition. `ClusterObjectXtpRouterTransport` selects the correct peer route and enforces one additional cluster invariant before Queue Fabric is touched: a MOVE's fenced Memory Fabric `provider_id` must belong to the selected destination route.

Queue Fabric retains durable acceptance authority. `QueueXtpReceiptGate` means the local transmission queue is ACKed only after an authenticated remote durable receipt; XTP packet/session success alone is insufficient. The existing `ClusterObjectMoveCoordinator` therefore releases the source object only after both Queue Fabric durability and the cluster MOVE response are confirmed.

## XTP baseline

The binding is written for the Queue Fabric protected-session-wire candidate of 29 October 2026 and consumes the XTP interactive session contract available in XTP dev35. The route requires a named service and the wire requests `encrypt`; it does not permit clear fallback.

XTP dev35 is source/LOCAL_PASS only. As reported by the XTP owner on 29 October 2026, no MU-to-own-MI or MU-to-MU FIELD_PASS receipt exists. Consequently the default `ClusterObjectXtpDenyReadiness` refuses every network request. A Deployment/route evidence authority must be injected before live use.

## Critical-path status

This advances MU/MI internode composition but does **not** claim internode cutover. Remaining external gates are:

1. generic Queue Fabric server-side XTP application request/response and authenticated durable receipt verifier;
2. XTP selected-route protection evidence (dev36 work is owned by XTP);
3. registered protected Queue Fabric named service on the actual MU/MI route;
4. live field receipt between real MU/MI nodes;
5. Deployment target qualification.

No resident PCM, decoded media block, tensor or other Memory Fabric payload belongs in a MOVE envelope. Only compact fenced references and runner state move.
