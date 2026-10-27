# ooRexx X.25 v0.1-dev2 — corrective laboratory implementation

**Architecture:** Tom Dyer. **Coding and documentation:** ChatGPT (GPT-6), 27 October 2026.

Standalone **ooRexx** packet, RFC1613 XOT framing and limited SVC transition library. `oorexx_x25_v0.1-dev2` is a new package; dev1 remains immutable for comparison. This is not a LAPB implementation, an X.25 network endpoint or a live gateway. No modification to XTP libxtp, SocketProvider, native bindings or any parallel-owned package.

## Dev2 corrections from Claude's independent review REQ-00000241

- **F1:** GFI bit 8 on a CALL is **A**, not Q. Reject unsupported TOA/NPI/A=1 CALL addressing until correctly decoded. DATA Q/D/M are preserved.
- **F2:** RESTART/RESTART_CONFIRM, DIAGNOSTIC, REGISTRATION/REGISTRATION_CONFIRM are reserved to **LCN 0** in this profile.
- **F3:** DATA, CALL, CLEAR, RESET, INTERRUPT and other circuit packets cannot use LCN 0. The control constructor and LCN rewrite cannot bypass validation.
- **F4:** INTERRUPT payload length is 1–32 binary octets, inclusive.
- **F5:** After an outgoing RESET is confirmed, **both** the local send-next and remote receive-next modulo-8 sequence numbers return to zero, and remoteReady resets. Incoming RESET acknowledgement uses the same reset discipline.
- **F6:** Simultaneous CLEAR in `CLEAR_SENT` terminates as `CLEARED`; no redundant CLEAR CONFIRM is produced.
- Minor cleanup: removed unused `invalid` helper and unreachable `XotFramer~push` trailing bound check.

## New bounded interfaces

- `X25Packet~data(lcn, payload, ps, pr, q, d, m, maxData)` constructs binary modulo-8 DATA with strict range validation and immediate decode verification. `X25Packet~new(raw, maxData)` is the decoder. Other constructors are deliberately restricted to basic CLEAR/RESET and confirmations.
- `X25VirtualCircuit~new(interfaceId,lcn,incarnation,maxData,role)` has explicit DTE/DCE role (default DTE), `receiveNext`, and new `sendNext`. `noteDataSent(packet)` tracks sequence *preparation only*: it is not send-acknowledgement, a credit-window implementation or a wire transmission.
- `inspectIncoming(packet,incarnation)` is a non-mutating typed diagnostic proposal for bad P(S). `X25CircuitRejection~responsePacket` returns a fully encoded RESET (DTE cause 0 or DCE local-procedure cause 5; diagnostic 1, invalid P(S)), **without sending it**.
- `inspectRaw(raw,incarnation)` catches decoder failures. In an **ACTIVE** circuit with a matching LCN and valid modulo-8 GFI, oversized DATA maps to RESET diagnostic 39 and empty INTERRUPT to RESET diagnostic 38. Absent trustworthy channel/profile, stale incarnation, unsupported A/TOA/NPI format and other unmapped errors return `LOCAL_ONLY` and **never fabricate a wire response**. The X.25 diagnostics 1, 38 and 39 are checked against ITU-T X.25 (1993), Annex E; actual live dispatch and DTE/DCE profile conformance remain unqualified.
- `XotFramer` retains bounded incremental RFC1613 TCP framing but does not open a connection or act as an interoperable XOT endpoint.

## Tests / build dependencies

```bash
REXX_BIN=/absolute/path/to/rexx tests/run.sh
```

The shell wrapper only sets exact local source discovery through `REXX_PATH` and invokes the four pure ooRexx scripts; it is **not runtime protocol code**. A standard shell is used because test execution/pipeline exit status and explicit interpreter selection are operating-system concerns. The source and test logic are ooRexx; no Python runtime dependency. Tests use synthetic octet fixtures, injected monotonic time, no root, no network and no external interfaces. See `docs/QUALIFICATION.md` for exact evidence and non-claims.

## Non-claims and gates

**NOT IMPLEMENTED:** LAPB HDLC framing, FCS, T1/N2/retransmission, window/credit/send acknowledgements, real serial or ISO8881 LLC2, PVC/PAD, modulo128, X.121 TOA/NPI handling, complete packet/facility negotiation, real TCP/1998 XOT interop, D-bit completion, persistent gateways, cryptographic admission or end-to-end guarantees. The typed diagnostic proposal does not schedule or send RESET and has **no** timeout/clear/recovery implementation beyond dev1's narrow T21 model.

**XTP dependency:** dev30 reserves gateway DIAG 16–23 in `packages/oorexx_xtp_v0.1-dev30/docs/DIAG_REGISTRY.md`. DIAG refusal is not foreign ingress authentication; FIRST/CNTL authentication and persistent interactive context are still gates for mode B. This package neither imports XTP nor sends DIAG.

**Source:** `packages/oorexx_x25_v0.1-dev2`. Authority and continuity: `spheres/oorexx_x25_gopher_sphere_v0.1/`; gateway specs remain `docs/XTP_GATEWAY_SPEC.md` and `docs/NOT_CLAIMED.md`.