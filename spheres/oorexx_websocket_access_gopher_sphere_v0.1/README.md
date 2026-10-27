# ooRexx WebSocket Access Gopher Sphere v0.1

Authoritative continuity sphere for `oorexx_websocket_access`.

WebSocket is deliberately **not a SocketProvider family**. It is an RFC 6455
access/protocol layer over a stream already acquired through the common
`SocketProvider` / `SocketStreamAdapter` boundary. The WebSocket layer owns
Upgrade negotiation, message/frame semantics, fragmentation sequencing, client
masking, ping/pong and close lifecycle. Socket acquisition, carrier selection,
TLS material, socket policy and generic lifecycle remain below that boundary.

Current Git source candidate: **v0.1-dev2**.

Current immutable qualified release:

- `oorexx_websocket_access_v0.1-dev1.zip`
- SHA-256 `91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`

dev2 adds fragmented data-message reassembly, control-frame interleaving,
bounded assembled messages, reserved/RSV fail-closed checks, and repairs the
dev1 close-handshake state bug. It is not promoted until fresh qualification
runs against the current Socket Provider authority.

Current external socket authority reviewed in Library is Socket Provider
v0.1-dev16, SHA-256
`fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.

The 2026-10-13 Spiral 1 grid retains the original dev1 independent COTS loopback
pass as inherited evidence in the dev16 estate. It does **not** claim a fresh
WebSocket/dev16 live rerun.

Rasen Falcon mailbox lane: `websocket-access`.
Independent dev2 review/qualification request: `REQ-00000381`.

Start with `packs/websocket-access/00-sphere.json` and the articles listed in
`start_here`.
