# ooRexx Queue Fabric Web Gateway v0.2

A deliberately thin browser gateway for Queue Fabric / Wire UI.

It has two trust zones:

1. `QueueFabricWebGatewayBridge.cls` runs inside the ooRexx application process and holds the **real** `ObjectQueueManager`, fixed inbound/outbound queues, gateway principal, and Queue Fabric claim tokens.
2. `websocket-edge.mjs` exposes WebSocket framing to one bound browser access point. The browser receives opaque `deliveryId` values only; Queue Fabric claim tokens and queue-manager credentials never cross the browser boundary.

The gateway knows no FlyLo business semantics. It maps only:

- browser `QUEUE_PUT` -> fixed Queue Fabric inbound queue
- Queue Fabric `CLAIM` -> browser `QUEUE_DELIVERY`
- browser `QUEUE_DELIVERY_ACK` / `NACK` -> Queue Fabric disposition
- disconnect -> Queue Fabric `RELEASE`
- Queue Fabric PUT result -> `QUEUE_PUT_RESULT` correlated by `clientPutId`
- optional browser-safe access-point bootstrap over HTTP GET

The browser cannot select another inbound queue: a frame naming a queue other than the configured binding is rejected with `QUEUE_NOT_BOUND`.

## Server-derived access-point binding

`WireUIWebAccessPointBinding.cls` removes duplicated session/queue configuration from deployment code. It is constructed with the application's existing Queue Fabric manager, `WireUIServer`, and Wire UI application object. It:

- derives the exact IN/OUT queues with `WireUIServer~directQueueName`
- provisions those queues/ACLs through `WireUIServer~provisionAccessPoint`
- creates the private bridge using the **same** `ObjectQueueManager`
- exposes `privateEdgeEnvironment()` for the Node edge
- exposes `browserBootstrap()` for browser-safe configuration

The two views are intentionally different. The browser bootstrap contains only the JS module URL, site id, gateway URL, fixed browser PUT queue, and Wire UI ownership (`applicationId`, `sessionId`, `accessPointId`). It does not contain the Queue Fabric OUT queue, gateway principal, bridge token, or claim token.

## Same-manager application seam

```rexx
binding = .WireUIWebAccessPointBinding~new(-
    manager, wireUIServer, app, -
    "browser-gateway", bridgeToken, pathToken, -
    "/alchemy-wire-ui-v0.4-dev3/src/index.js", "FLYLO")

if \binding~startBridge then ...
edgeEnvironment = binding~privateEdgeEnvironment(publicGatewayUrl)
```

`serveAsync` is unguarded and services the loopback socket on an ooRexx activity while retaining that exact manager reference. Listener shutdown uses bounded `Socket~select(..., 0.10)` readiness polling; `stop()` therefore does not rely on closing a socket from another activity to wake a blocking `accept()`.

## Browser bootstrap endpoint

When `WIRE_UI_APPLICATION_ID`, `WIRE_UI_SESSION_ID`, `WIRE_UI_ACCESS_POINT_ID`, and `WIRE_UI_MODULE_URL` are supplied to `node/gateway.mjs`, the edge serves a browser-safe bootstrap document at `/wire-ui/bootstrap` (or `WIRE_UI_BOOTSTRAP_PATH`). The same optional path token protects both WebSocket and bootstrap endpoints.

The response is `Cache-Control: no-store, private` and contains:

```json
{
  "moduleUrl": "/alchemy-wire-ui-v0.4-dev3/src/index.js",
  "gatewayUrl": "wss://host/wire-ui?token=...",
  "outboundQueue": "WIREUI.IN.ACCESS_POINT",
  "siteId": "FLYLO",
  "ownership": {
    "applicationId": "FLYLO-APP",
    "sessionId": "SESSION-...",
    "accessPointId": "ACCESS_POINT"
  }
}
```

`outboundQueue` is named from the browser's perspective: it is the fixed Queue Fabric **IN** queue to the server. The gateway independently enforces the same binding.

## Node edge environment

Required:

- `QF_BRIDGE_PORT`
- `QF_BRIDGE_TOKEN`
- `WIRE_UI_INBOUND_QUEUE`

Optional transport values:

- `QF_BRIDGE_HOST` (default `127.0.0.1`)
- `WIRE_UI_GATEWAY_HOST` (default `127.0.0.1`)
- `WIRE_UI_GATEWAY_PORT` (default ephemeral)
- `WIRE_UI_GATEWAY_PATH` (default `/wire-ui`)
- `WIRE_UI_GATEWAY_PATH_TOKEN`
- `WIRE_UI_PUBLIC_GATEWAY_URL`

Optional bootstrap values (all four required together):

- `WIRE_UI_APPLICATION_ID`
- `WIRE_UI_SESSION_ID`
- `WIRE_UI_ACCESS_POINT_ID`
- `WIRE_UI_MODULE_URL`
- optional `WIRE_UI_SITE_ID`
- optional `WIRE_UI_BOOTSTRAP_PATH`

The path token is a narrow development/access-point binding mechanism, not a replacement for deployment TLS/authentication policy.

## Acceptance

`run_tests.sh` proves:

- backend PUT reaches the real `ObjectQueueManager`
- bridge authentication is enforced
- async listener shares the exact manager object and stops cleanly
- server-derived access-point queue/ownership binding is exact
- browser bootstrap contains no private Queue Fabric material
- browser never sees the Queue Fabric claim token
- browser-selected alternate queues are rejected
- delivery ACK and `QUEUE_PUT_RESULT` correlation work
- real Queue Fabric -> bridge -> WebSocket -> Alchemy JS renders FlyLo SEARCH
- semantic `FLIGHT.SEARCH` returns through the same manager
- OFFERS render as actionable collection items
- selection returns only server-issued `offerId` plus index through `FLIGHT.SELECT`
- a generic semantic-record assistant renders and returns `ASSISTANT.ASK` through the same path
