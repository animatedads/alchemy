# Current integration baseline checked 2026-10-24

The immutable source baseline remains **ooRexx WebSocket Access v0.1-dev1**.

- Source delivery: `oorexx_websocket_access_v0.1-dev1.zip`
- SHA-256: `91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`
- Protocol surface: RFC 6455 client access over an already-isolated stream
- Original qualification: ooRexx 5.3.0 r13196 contract pass plus independent Python `websockets` COTS loopback wire pass

Current externally evidenced socket authority:

- Socket Provider **v0.1-dev16**
- SHA-256: `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`

The 2026-10-13 Spiral 1 transport reconciliation records the WebSocket route as
ACCESS + CONTRACT PASS with the dev1 live COTS wire pass inherited into the
dev16 estate. It explicitly records that WebSocket was **not freshly rerun
against dev16**. Do not upgrade that evidence into a new live-dev16 claim.

Architecture remains unchanged:

```text
WebSocketAccess
  -> WebSocketConnection / WebSocketMessage
  -> SocketProvider~streamSender[At]()
  -> SocketStreamAdapter
  -> selected TCP/TLS provider
```

WebSocket is therefore an access/protocol layer, not a new socket family. It
does not own native socket acquisition, route selection, TLS key material,
entropy, or generic socket lifecycle.

Current non-claims remain:

- RFC 8441 WebSocket over HTTP/2 is not implemented.
- RFC 9220 WebSocket over HTTP/3 is not implemented.
- permessage-deflate/extensions are not implemented.
- fragmented-message reassembly is not complete.
- a production nonce/mask entropy provider is not bundled.

Any future increment must be requalified against the current Socket Provider
authority while preserving the original dev1 provenance.
