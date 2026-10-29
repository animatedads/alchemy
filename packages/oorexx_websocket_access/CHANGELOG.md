# Changelog

## 0.1-dev3 — 2026-10-29

- Add optional `WebSocketPlatformCrypto.cls`.
- Bind RFC 6455 `Sec-WebSocket-Accept` SHA-1 to the existing `crypto.auth/0.1` authority.
- Add standard RFC 4648 base64 encoding for handshake key/accept values.
- Add `WebSocketEntropySource` as the explicit production randomness seam.
- Add `WebSocketCryptoAuthHandshake` and `WebSocketCryptoAuthMaskSource`, sharing the injected entropy authority.
- Add deterministic RFC 6455 handshake/base64/mask adapter contract fixture.
- Keep TLS credentials and transport security below WebSocket in Socket Provider.
- Do not claim production entropy or fresh dev16 qualification.

## 0.1-dev2 — 2026-10-27

- Reassemble fragmented TEXT/BINARY messages from CONTINUATION frames.
- Permit control-frame interleaving while a fragmented data message is active.
- Fail closed on unexpected continuation and overlapping fragmented data messages.
- Bound assembled message size and use close code 1009 on overflow.
- Reject reserved opcodes, unexpected RSV bits and invalid control-frame shapes.
- Repair the dev1 close path so close control frames are written while CLOSING.
- Reconcile current external authority to Socket Provider dev16.
- Mark dev2 as SOURCE_CANDIDATE pending fresh r13196 + dev16 COTS qualification.

## 0.1-dev1 — 2026-10-07

- Initial RFC 6455 access layer over SocketStreamAdapter.
- Contract and independent Python websockets loopback qualification.
