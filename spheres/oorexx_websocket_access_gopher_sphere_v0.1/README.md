# ooRexx WebSocket Access Gopher Sphere v0.1

Authoritative continuity sphere for `oorexx_websocket_access`.

WebSocket is deliberately **not a SocketProvider family**. It is an RFC 6455
access/protocol layer over a stream already acquired through the common
`SocketProvider` / `SocketStreamAdapter` boundary. The WebSocket layer owns
Upgrade negotiation, message/frame semantics, client masking, ping/pong and
close lifecycle. Socket acquisition, carrier selection, TLS material, socket
policy and generic lifecycle remain below that boundary.

Current grounded source release:

- `oorexx_websocket_access_v0.1-dev1.zip`
- SHA-256 `91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`

Current external socket authority reviewed in Library is Socket Provider
v0.1-dev16, SHA-256
`fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.

The 2026-10-13 Spiral 1 transport grid retains the original WebSocket dev1
independent COTS loopback pass as inherited evidence in the dev16 estate. It
does **not** claim a fresh WebSocket/dev16 live rerun.

Start with `packs/websocket-access/00-sphere.json` and the articles listed in
`start_here`.
