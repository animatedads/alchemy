# Spiral 1 COTS interface grid — WebSocket slice

| Standard/interface | ooRexx access route | Isolation/provider route | Native/COTS endpoint | dev1 evidence |
|---|---|---|---|---|
| RFC 6455 WebSocket client | `WebSocketAccess -> WebSocketConnection` | `SocketProvider~streamSender[At] -> SocketStreamAdapter` | TCP stream, or TLS stream when supplied by Socket Provider | ACCESS; CONTRACT PASS; live independent COTS echo qualification |
| RFC 6455 message/frame | `WebSocketMessage` + `WebSocketCodec` | existing stream only | RFC 6455 peer | masking/vector contract PASS; text/binary/control object semantics retained |
| RFC 6455 opening handshake | `WebSocketClientOptions`, `WebSocketHandshakeResult` | same isolated stream | HTTP/1.1 Upgrade peer | RFC example accept validation PASS; live COTS handshake PASS |
| RFC 8441 WebSocket over HTTP/2 | future access provider | future HTTP/2 stream provider | COTS HTTP/2 implementation | GAP — not claimed |
| RFC 9220 WebSocket over HTTP/3 | future access provider | future HTTP/3 stream provider | COTS HTTP/3 implementation | GAP — not claimed |

The WebSocket row belongs above the socket-family rows. It demonstrates a recognised COTS interface through an ooRexx access class without manufacturing a second socket authority.
