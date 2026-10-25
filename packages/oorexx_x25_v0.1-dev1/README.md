# User-space ooRexx X.25 — v0.1-dev1 (lab-only)

**Architecture:** Tom Dyer. **Coding and this update:** ChatGPT (GPT-6), 25 October 2026.

This is the independent, user-space **X.25 packet-layer entry slice**, not a working telephone-network/X.25 service. Nothing uses Linux AF_X25 or the kernel LAPB module. No SocketProvider, XTP or gateway source was patched. All objects stay ooRexx-native, with the original octet stream retained.

## What runs

- `src/X25Packet.cls`: validated X.25 **modulo-8** PLP packet parsing and basic CLEAR/RESET constructor. Preserves physical wire bytes, Q/D/M, LCN and incarnation-independent channel identity, modulo-8 sequence, raw causes and diagnostics, binary data and binary CALL fields. Rejects unsupported modulo-128 rather than guessing. CALL address/facility syntax is only bounded by length, not yet accepted/negotiated as a validated facility profile.
- `src/X25Packet.cls`: `XotFramer` binary framing for RFC 1613: version **0**, big-endian 16-bit length, segmented and coalesced TCP reads, hard maximum length, poisoned failure state, incomplete EOF and exclusion of XOT-forbidden link-local packets. It neither opens TCP nor asserts a complete RFC 1613 switch/router. Real XOT requires one TCP connection per VC, port 1998, facility/window negotiation and independent interop evidence.
- `src/X25VirtualCircuit.cls`: explicit, independently testable per-(interface,LCN,incarnation) **SVC transition core** for CALL_SENT, CALL_INCOMING, ACTIVE, RESET_SENT/RECEIVED, CLEAR_SENT/RECEIVED, CLEARED and TIMED_OUT. T21 uses an **injected monotonic clock and profile-specific duration**. Unexpected/old-incarnation events fail closed; there is no implicit replay or network reply.
- `tests/*.rex`: positive, boundary, and negative tests, including split XOT reads, coalescing, malicious headers, Q bit, RR/RNR, packet limits, circuit timer expiry, and stale incarnation rejection.

## Execute against actual ooRexx

```sh
REXX_BIN=/exact/runtime/bin/rexx tests/run.sh
```

Do not assume `rexx` appears on PATH. `REXX_PATH` is configured by `run.sh`; no hidden dependency search. Version qualification depends on interpreter and ABI, not filename alone.

## Explicit exclusions / work next

- **NOT_IMPLEMENTED:** HDLC/LAPB T1,N2,FCS, modulo window, serial I/O, LLC2/ISO8881, PAD X.3/X.28/X.29, PVC, modulo-128, facility negotiation and full X.25 send windows/T22/T23 state, real XOT sockets and independent equipment interop. The new per-VC engine is a starting skeleton, **not** an X.25 protocol conformance claim.
- **No production admission:** call acceptance requires an explicit `authorised=.true` from an independently responsible policy layer; this test seam is not an authentication mechanism.
- **No XTP gateway activation:** XTP dev29 has unicast segmentation, selective retransmission, SYNC/ECHO and DIAG. It still lacks authenticated FIRST/CNTL and a persistent interactive FIRST-to-KEY context; foreign ingress remains disabled. This library does not depend on any XTP implementation.
- **No security or delivery guarantee:** X.25 is not encrypted; D-bit is not application commit. `XotFramer` must be given authenticated/trusted socket endpoints separately.

Authoritative specs are `docs/X25_FAMILY_SPEC.md`, `docs/XTP_GATEWAY_SPEC.md`, `docs/SEMANTIC_MAPPING.md`, `docs/OPEN_QUESTIONS.md`, `docs/NOT_CLAIMED.md` in the repository. The source qualification is scoped to the tests shown here.