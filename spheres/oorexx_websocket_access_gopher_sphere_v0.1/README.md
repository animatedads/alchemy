# ooRexx WebSocket Access Gopher Sphere v0.1

Authoritative continuity sphere for `oorexx_websocket_access`.

WebSocket is an RFC 6455 access/protocol layer over socket/HTTPS-owned streams; it is not a SocketProvider family and does not own TLS.

Current Git source candidate: **v0.1-dev4**.
Immutable qualified release: **v0.1-dev1**, SHA-256 `91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`.

dev4 adds server-side RFC 6455 framing/admission and the parsed upgrade handoff needed to compose `wss://` with the project's own ooRexx HTTPS server. HTTPS keeps TCP, OpenSSL/TLS, bounded admission, HTTP parsing and lifetime; WebSocket receives only the upgraded plaintext stream abstraction and parsed request.

Current Socket Provider authority remains v0.1-dev16 (`fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`). Optional crypto authority remains Crypto v0.8.3 (`5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`) plus `crypto.auth/0.1`.

No fresh dev16 or live owned-HTTPS/wss PASS is claimed. See `websocket.https-integration`, `websocket.qualification` and `websocket.continuation`.

Rasen Falcon mailbox lane: `websocket-access`.
