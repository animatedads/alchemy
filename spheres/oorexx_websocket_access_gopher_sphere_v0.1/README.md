# ooRexx WebSocket Access Gopher Sphere v0.1

Authoritative continuity sphere for `oorexx_websocket_access`.

WebSocket is deliberately **not a SocketProvider family**. It is an RFC 6455 access/protocol layer over a stream already acquired through the common `SocketProvider` / `SocketStreamAdapter` boundary.

Current Git source candidate: **v0.1-dev3**.

Current immutable qualified release:

- `oorexx_websocket_access_v0.1-dev1.zip`
- SHA-256 `91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`

dev2 repaired fragmentation and close sequencing. dev3 adds an optional estate crypto adapter using `crypto.auth/0.1` SHA-1 for RFC 6455 handshake accept calculation while preserving injected production entropy.

Current external socket authority remains Socket Provider v0.1-dev16, SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.

Current optional crypto authority is ooRexx Crypto v0.8.3, SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`, plus Crypto Authentication Primitives v0.1-dev1 / `crypto.auth/0.1`.

The current Library transport grid still retains the original dev1 independent COTS loopback pass as inherited dev16-era evidence. No fresh WebSocket/dev16 live rerun is claimed.

Rasen Falcon mailbox lane: `websocket-access`.

Start with `packs/websocket-access/00-sphere.json` and the articles listed in `start_here`.
