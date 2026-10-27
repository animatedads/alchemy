# Changelog

## 0.1-dev2 — 2026-10-27

- Reassemble fragmented TEXT/BINARY messages from CONTINUATION frames.
- Permit control-frame interleaving while a fragmented data message is active.
- Fail closed on unexpected continuation and overlapping fragmented data messages.
- Bound assembled message size and use close code 1009 on overflow.
- Reject reserved opcodes, unexpected RSV bits and invalid control-frame shapes.
- Repair the dev1 close path: close control frames are now written while the
  connection is CLOSING instead of being rejected by the OPEN-only data send path.
- Reconcile current external authority to Socket Provider dev16 without rewriting
  immutable dev1 qualification history.
- Mark dev2 as SOURCE_CANDIDATE pending fresh r13196 + dev16 COTS qualification.

## 0.1-dev1 — 2026-10-07

- Initial RFC 6455 access layer over SocketStreamAdapter.
- Contract and independent Python websockets loopback qualification.
