# ooRexx WebSocket Access v0.1-dev2 source candidate

Spiral 1 COTS interface slice for RFC 6455 WebSocket.

WebSocket remains deliberately **not a new socket family**. It is an access/protocol layer over an already isolated stream. Socket acquisition remains exclusively with the estate Socket Provider:

```text
application / intention
        -> WebSocketAccess
        -> WebSocketConnection / WebSocketMessage
        -> SocketProvider~streamSender[At]()
        -> SocketStreamAdapter
        -> selected TCP or TLS binding
        -> native/COTS socket
```

The access layer owns RFC 6455 HTTP Upgrade negotiation, frame encoding/decoding, client masking, data/control sequencing and close lifecycle. It does not own native socket acquisition, socket policy, peer routing, TLS keys, entropy or digest implementation.

## dev2 source changes

dev2 closes two concrete dev1 defects and strengthens fail-closed behaviour:

- fragmented TEXT/BINARY messages are reassembled across CONTINUATION frames;
- PING/PONG/CLOSE control frames can be processed while a fragmented message is active;
- continuation without an active fragmented message fails closed with protocol close 1002;
- starting a second data message while fragmentation is active fails closed;
- assembled message size is bounded, with close 1009 on overflow;
- reserved opcodes, unexpected RSV bits and invalid control frames fail closed;
- local and peer close paths now transmit the close control frame before stream close. dev1 changed state to CLOSING and then called sendMessage(), which only permits OPEN.

## Evidence state

The immutable qualified release remains **v0.1-dev1**, SHA-256
`91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`.

dev1 evidence remains ACCESS, RFC 6455 contract PASS, SocketProvider isolation PASS and an independent Python `websockets` loopback wire PASS under ooRexx 5.3.0 r13196.

The current external socket authority is Socket Provider **v0.1-dev16**. Library reconciliation carries the dev1 COTS result as inherited evidence and explicitly says WebSocket was **not freshly rerun against dev16**.

dev2 is therefore a **source candidate** until its expanded contract suite and independent COTS wire test execute against the current Socket Provider authority.

## Security/entropy authority

`WebSocketHandshakeCrypto` remains the injected authority for client nonce and `Sec-WebSocket-Accept`. `WebSocketMaskSource` remains the injected authority for fresh client masks. Production entropy is not bundled or claimed.

## Non-claims

- RFC 8441 WebSocket over HTTP/2 is not implemented.
- RFC 9220 WebSocket over HTTP/3 is not implemented.
- permessage-deflate/extensions are not implemented.
- production nonce/mask entropy provider is not bundled.
