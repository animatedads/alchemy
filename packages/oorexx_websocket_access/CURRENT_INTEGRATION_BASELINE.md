# Current integration baseline checked 2026-10-27

## Source and qualification split

Current Git source candidate: **ooRexx WebSocket Access v0.1-dev2**.

Immutable qualified release remains:

- `oorexx_websocket_access_v0.1-dev1.zip`
- SHA-256 `91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`
- ooRexx 5.3.0 r13196 contract pass
- independent Python `websockets` COTS loopback wire pass

dev2 repairs fragmented-message sequencing and the dev1 close-frame state bug, but is not promoted until the expanded tests execute against the current socket authority.

## Current external socket authority

- Socket Provider **v0.1-dev16**
- SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`

The 2026-10-13 Spiral 1 reconciliation records WebSocket as ACCESS + CONTRACT PASS with the dev1 COTS wire pass inherited into the dev16 estate. It explicitly records that WebSocket was **not freshly rerun against dev16**.

Architecture remains:

```text
WebSocketAccess
  -> WebSocketConnection / WebSocketMessage
  -> SocketProvider~streamSender[At]()
  -> SocketStreamAdapter
  -> selected TCP/TLS provider
```

## dev2 qualification gates

1. run the expanded RFC 6455 contract suite under ooRexx 5.3.0 r13196;
2. run against Socket Provider dev16, not the historical dev10 fixture;
3. exercise an independent COTS peer with fragmented TEXT/BINARY and interleaved PING;
4. prove local and peer close frames are sent before stream close;
5. retain exact SocketAddress object identity;
6. preserve fail-closed behaviour for continuation/reserved opcode/RSV/control violations.

## Remaining non-claims

RFC 8441, RFC 9220, permessage-deflate/extensions and a production nonce/mask entropy provider remain outside the implemented/qualified surface.
