# Changelog

## 0.1-dev4 — 2026-10-29

- Add server-side RFC 6455 access over an already accepted plaintext stream.
- Add mandatory masked-client / unmasked-server frame directions.
- Add `WebSocketUpgradeRequest` and parsed HTTPS upgrade handoff.
- Preserve WebSocket bytes coalesced with client 101 or server Upgrade headers.
- Add Origin allowlisting, subprotocol selection, version-13 enforcement and canonical client-key admission.
- Add server-side fragmentation/control/close handling.
- Add explicit own-HTTPS integration contract without exposing Socket/BIO/SSL.
- Repair an intermediate source-generation escape error before qualification; no evidence is inherited from that intermediate revision.
- Keep dev4 SOURCE_CANDIDATE pending r13196/dev16/COTS/owned-HTTPS execution.

## 0.1-dev3 — 2026-10-29

- Add optional `WebSocketPlatformCrypto.cls`.
- Bind RFC 6455 `Sec-WebSocket-Accept` SHA-1 to `crypto.auth/0.1`.
- Add standard base64 and explicit `WebSocketEntropySource`.
- Keep TLS credentials and transport security below WebSocket.

## 0.1-dev2 — 2026-10-27

- Add fragmented message reassembly and control-frame interleaving.
- Repair close-frame transmission and strengthen fail-closed frame sequencing.

## 0.1-dev1 — 2026-10-07

- Initial RFC 6455 access layer over SocketStreamAdapter.
- Contract and independent Python websockets loopback qualification.
