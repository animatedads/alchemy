# Current integration baseline checked 2026-10-29

## Source and qualification split

Current Git source candidate: **ooRexx WebSocket Access v0.1-dev3**.

Immutable qualified release remains:

- `oorexx_websocket_access_v0.1-dev1.zip`
- SHA-256 `91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`
- ooRexx 5.3.0 r13196 contract pass
- independent Python `websockets` COTS loopback wire pass

dev2 repaired fragmented-message sequencing and the close-frame state defect. dev3 adds the optional estate crypto adapter for RFC 6455 SHA-1/base64 handshake calculations while keeping entropy injected.

## Current external socket authority

- Socket Provider **v0.1-dev16**
- SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`

The current Library transport reconciliation still carries WebSocket dev1's live COTS result as inherited evidence and explicitly says WebSocket was not freshly rerun against dev16.

## Crypto authority

Optional dev3 adapter:

- ooRexx Crypto **v0.8.3**
- SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- ooRexx Crypto Authentication Primitives **v0.1-dev1**
- API `crypto.auth/0.1`

`WebSocketPlatformCrypto.cls` uses the estate SHA-1 authority for `Sec-WebSocket-Accept` and standard base64 encoding. It does not own entropy. `WebSocketEntropySource` is the production binding seam for the 16-byte handshake nonce and four-byte frame masks.

Architecture remains:

```text
WebSocketAccess
  -> WebSocketConnection / WebSocketMessage
  -> SocketProvider~streamSender[At]()
  -> SocketStreamAdapter
  -> selected TCP/TLS provider
```

## dev3 qualification gates

1. run the dev2 fragmentation/close contract suite under ooRexx 5.3.0 r13196;
2. run `tests/test_platform_crypto.rex` against exact `crypto.auth/0.1` + Crypto v0.8.3;
3. run independent COTS WebSocket qualification through Socket Provider dev16;
4. exercise fragmented TEXT/BINARY and interleaved control frames on wire;
5. prove local and peer close frames are sent before stream close;
6. retain exact SocketAddress object identity;
7. bind `WebSocketEntropySource` to the estate production randomness authority before claiming production nonce/mask entropy.

## Remaining non-claims

RFC 8441, RFC 9220, permessage-deflate/extensions, fresh dev16 live qualification and the final production entropy-provider binding remain outside the qualified surface.
