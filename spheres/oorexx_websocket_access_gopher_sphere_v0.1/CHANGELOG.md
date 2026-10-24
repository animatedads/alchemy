# Changelog

## v0.1 — 2026-10-24

- Created the ooRexx WebSocket Access continuity sphere.
- Recorded RFC 6455 WebSocket as an access/protocol layer over the shared
  SocketProvider stream seam, not as a new socket family.
- Preserved full `WebSocketMessage`, `WebSocketConnection` and address-object
  semantics across the isolation boundary.
- Recorded separate crypto/entropy authority for handshake nonce/accept and
  client masking.
- Recorded dev1 contract and independent COTS loopback qualification.
- Recorded Socket Provider dev16 as current external authority while preserving
  the exact evidence statement: the dev1 COTS pass is inherited; no fresh
  WebSocket/dev16 live rerun is claimed.
- Recorded RFC 8441, RFC 9220, extensions, complete fragmentation reassembly and
  production entropy as explicit continuation work/non-claims.
