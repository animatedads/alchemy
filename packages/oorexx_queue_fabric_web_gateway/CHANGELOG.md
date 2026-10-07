# Changelog

## v0.2 — 2026-08-24

- Add `WireUIWebAccessPointBinding` to derive Queue Fabric queues and Wire UI ownership from the authoritative Server/application objects.
- Add browser-safe HTTP bootstrap endpoint to the WebSocket edge.
- Add optional bootstrap/environment support to `node/gateway.mjs`.
- Keep private bridge token, Queue Fabric principal, OUT queue and claim tokens out of browser bootstrap.
- Add `Cache-Control: no-store, private` and defensive response headers to bootstrap responses.
- Extend browser acceptance through `SEARCH -> OFFERS -> SELECTION -> ASK` over the real Queue Fabric manager.
- Add Server v0.8 access-point-binding acceptance and validate versioned material delivery through the browser round-trip.

## v0.1 — 2026-08-24

- Initial same-manager Queue Fabric loopback bridge and WebSocket edge.
- Ordered opaque delivery/ACK/NACK and `QUEUE_PUT_RESULT` support.
- FlyLo SEARCH -> OFFERS -> SELECTION browser acceptance.
