# ooRexx WebSocket Access v0.1-dev1

Spiral 1 COTS interface slice for RFC 6455 WebSocket.

This is deliberately **not a new socket family**. WebSocket is an access/protocol layer over an already isolated stream. Socket acquisition remains exclusively with the estate Socket Provider:

```text
application / intention
        -> WebSocketAccess
        -> WebSocketConnection / WebSocketMessage
        -> SocketProvider~streamSender[At]()
        -> SocketStreamAdapter
        -> TCP or TLS binding
        -> native/COTS socket
```

The access layer owns RFC 6455 HTTP Upgrade negotiation, frame encoding/decoding, client masking, control frames and close lifecycle. It does not own native socket acquisition, socket policy, peer routing, TLS keys, entropy or digest implementation.

`WebSocketHandshakeCrypto` is an injected authority for the client nonce and `Sec-WebSocket-Accept` calculation. `WebSocketMaskSource` is an injected authority for fresh client frame masking keys. This keeps cryptographic/entropy authority out of protocol code and avoids shell-command crypto.

## Spiral 1 evidence

- ACCESS: `WebSocketAccess` and full `WebSocketMessage` objects exist.
- CONTRACT PASS: the RFC 6455 example handshake and masking vector are exercised.
- ISOLATION PASS: the access route consumes `SocketProvider~streamSender()` / `SocketStreamAdapter`; no direct RxSock acquisition appears in the access class.
- LIVE COTS WIRE PASS: `tests/environment_test.sh` can run the ooRexx client against Python `websockets` as an independent RFC 6455 implementation. The live test intentionally uses the RFC example client key; production entropy remains an external handshake-crypto authority and is not claimed by dev1.

## Non-claims

- RFC 8441 WebSocket over HTTP/2 is not implemented in dev1.
- RFC 9220 WebSocket over HTTP/3 is not implemented in dev1.
- permessage-deflate/extensions are not implemented.
- fragmented multi-frame message reassembly is not yet implemented; FIN/opcode identity is preserved and continuation frames are represented.
- production nonce/mask entropy provider is not bundled.
