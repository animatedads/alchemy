# ooRexx WebSocket Access v0.1-dev4 source candidate

RFC 6455 WebSocket access for the Alchemy socket/web estate.

WebSocket remains an access/protocol layer, not a socket family. Client connections consume `SocketProvider~streamSender[At]()`. Server connections consume an already accepted plaintext stream; for `wss://`, that stream remains owned and encrypted by the ooRexx HTTPS server.

## dev4: server and owned-HTTPS seam

dev4 adds `WebSocketServerAccess` and `WebSocketServerConnection`, including mandatory client masking, unmasked server frames, Origin allowlisting, subprotocol selection, version-13 enforcement, fragmentation, control frames and close handling.

It also adds `WebSocketUpgradeRequest` and `WebSocketServerAccess~acceptParsedRequest(...)`. This is the narrow handoff for the owned HTTPS server: HTTPS keeps TCP, OpenSSL, TLS credentials, HTTP parsing, bounded worker admission and connection lifetime; WebSocket receives only a parsed Upgrade request, a plaintext duplex wrapper, peer/address projection and any already-read post-header bytes.

The client and server paths both preserve a first WebSocket frame coalesced with the HTTP handshake instead of dropping bytes after the header terminator.

See `HTTPS_UPGRADE_CONTRACT.md`.

## Earlier candidate work

dev2 repaired fragmented-message sequencing and the dev1 close-frame state bug. dev3 added the optional `WebSocketPlatformCrypto.cls` adapter, binding the standards-required SHA-1 accept calculation to `crypto.auth/0.1` while keeping production entropy injected.

## Authority boundaries

- Socket Provider owns socket/carrier acquisition.
- ooRexx HTTPS Server owns accepted TCP, TLS/OpenSSL and HTTP parsing for wss.
- Crypto/CryptoAuth own cryptographic primitives.
- WebSocket owns RFC 6455 handshake/framing/session semantics.
- LDAP/application security owns identity and authorization; WebSocket does not.

## Evidence state

Immutable qualified release remains **v0.1-dev1**, SHA-256 `91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`.

Current Git source is **v0.1-dev4 SOURCE_CANDIDATE**. No new PASS is claimed until the expanded r13196/dev16/COTS/owned-HTTPS qualification gates in `VALIDATION_DEV4.txt` execute.

Current Socket Provider authority: v0.1-dev16, SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`.

Current optional Crypto authority: v0.8.3, SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`, plus `crypto.auth/0.1`.

## Non-claims

Fresh dev16 live qualification, live owned-HTTPS/wss integration, production entropy binding, RFC 8441, RFC 9220 and permessage-deflate remain unqualified.
