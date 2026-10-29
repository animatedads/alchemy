# ooRexx WebSocket Access v0.1-dev3 source candidate

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

The access layer owns RFC 6455 Upgrade negotiation, frame encoding/decoding, client masking, fragmentation sequencing and close lifecycle. It does not own native socket acquisition, route selection, TLS material or production entropy.

## dev2 protocol repairs

dev2 repaired fragmented TEXT/BINARY reassembly, control-frame interleaving, bounded message assembly, reserved/RSV validation and the dev1 close-state bug that prevented the close control frame from being written.

## dev3 estate crypto adapter

dev3 adds the optional `WebSocketPlatformCrypto.cls` adapter.

It binds RFC 6455's standards-required SHA-1 `Sec-WebSocket-Accept` calculation to the existing `crypto.auth/0.1` authority, which is the narrow SHA-1/HMAC companion to ooRexx Crypto v0.8.3. It also supplies the ordinary RFC 4648 base64 encoding needed for the handshake.

Entropy remains explicitly injected through `WebSocketEntropySource`. The same entropy authority can back both:

- the 16-byte client handshake nonce; and
- fresh four-byte client frame masks.

This adapter deliberately does **not** add another RNG, shell out to OpenSSL, acquire TLS credentials or bypass Socket Provider. Production installations must bind `WebSocketEntropySource` to the estate cryptographic/randomness authority.

TLS remains below WebSocket in the Socket Provider TLS family and its `SocketSecurityMaterialProvider`.

## Evidence state

The immutable qualified release remains **v0.1-dev1**, SHA-256
`91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`.

The current Git line is **v0.1-dev3 SOURCE_CANDIDATE**. It is not promoted until the expanded protocol and crypto-adapter tests execute under ooRexx 5.3.0 r13196 against the current Socket Provider authority.

Current external socket authority:

- Socket Provider v0.1-dev16
- SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`

Current crypto authority used by the optional adapter:

- ooRexx Crypto v0.8.3
- SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- ooRexx Crypto Authentication Primitives v0.1-dev1 / `crypto.auth/0.1`

## Non-claims

- fresh dev16 live WebSocket qualification;
- production entropy-provider binding;
- RFC 8441 WebSocket over HTTP/2;
- RFC 9220 WebSocket over HTTP/3;
- permessage-deflate/extensions.
