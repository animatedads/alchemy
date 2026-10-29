# X.25 packet-layer / XTP gateway source sphere — v0.1

**Architecture:** Tom Dyer. **Coding and writing:** ChatGPT (GPT-6), 2026-10-25.

## Authority and boundaries

1. The independently usable user-space ooRexx X.25 protocol engine owns packet, virtual circuit, timer and LAPB semantics. It is not allowed to take ownership of SocketSelector's family registration, ConnectSelector invocation or XTP route/persistence/crypto governance. Kernel AF_X25 is optional non-primary compatibility only.
2. The separate XTP Gateway owns session admission and policy, but does not silently convert X.25 circuit semantics to unqualified TCP byte-stream equivalence; no data before bilateral authorisation.
3. XTP named service descriptors hold canonical service identity and operating class, **never** IP endpoints. L2 direct, L3 raw IP protocol 36 and L4 UDP are XTP underlays; XOT is RFC 1613 X.25-over-TCP port 1998.
4. Preserve X.121/CUG/CUD, Q/D/M, packet/facility, interrupt, cause/diagnostic, exact VC incarnation, uncertain delivery semantics. X.25 D-bit is not application transaction commit.
5. Any live gateway foreign ingress requires XTP authenticated FIRST/CNTL and persistent interactive context. Instrumentation is read-only, after authoritative transitions; management intentions require separate authority; Firewall Controller owns CIDR/timeouts; no passive monitor has kill privilege.

## Verified source as of 2026-10-25

- `packages/oorexx_xtp_v0.1-dev29/README.md` and `docs/XTP_SPEC_GAPS_DEV29.md`: working dev29 features are segmented unicast payload, selective retransmission, SYNC/ECHO context binding after first echo, and DIAG for service/oversize/malformed. These do **not** provide cryptographic identity or a durable interactive streaming context.
- `packages/oorexx_xtp_v0.1-dev29/docs/NAMED_SERVICES.md`: FIRST private 0xA11C descriptor, name-to-logical peer route.
- `packages/oorexx_socket_provider/src/SocketProvider.cls`: in-repo common transport contract and capability booleans; external dev16 compatibility ledger separately authoritative for deployable version, not blanket approval of new X.25 family.
- `packages/oorexx_x25_v0.1-dev1/README.md` and `docs/QUALIFICATION.md`: the **new** code's exact supported and unsupported subset. ooRexx r13196 interpreter execution on positive and negative deterministic tests is evidence for those tests alone.
- Public protocol references: ITU-T X.25 profile must be fixed per network; RFC1613 specifies XOT header version 0/length, one TCP connection per VC, TCP 1998, local-only exclusions and mandatory explicit size/window facilities on outgoing CALL.

## Current source and gaps

`X25Packet.cls` parses a bounded modulo-8 PLP packet, preserves raw binary, 12-bit LCN, cause/diagnostic and Q/D/M; it does not negotiate unknown facility octets. `XotFramer` handles split/coalesced TCP record framing, refuses invalid version/length, refuses link-local packets and fails permanently on malformed input. `X25VirtualCircuit.cls` is a **non-transmitting** deterministic SVC transition skeleton with injected monotonic T21 and incarnation fencing.

NOT_IMPLEMENTED: independent LAPB link and T1/N2, physical/LLC2 adapters, data-window sender and end-to-end D-bit, complete facility negotiation, full XOT, PAD, PVC, modulo-128, real interoperability, production identity/crypto policy, live GatewaySession/QueueRexx MANAGEMENT and capture controls.

## Continuation protocol

- Implement a standalone ooRexx LAPB framing+state/timer package with real tests first, then PLP full facility parser/negotiation and ordered/windowed data states; do not leap to a Linux kernel driver.
- XTP dev29 transport owner alone changes FIRST/CNTL auth, persistent stream, DIAG value extensions and any XTP protocol code. New gateway adaptations must be version-gated.
- SocketProvider owner alone changes `SocketAddresses~x25` and `halfCloseSend/shutdownSend` common contracts.
- Every reviewed change updates `docs/NOT_CLAIMED.md`, qualification and this sphere. No promotion to QUALIFIED from mock or lab tests.

## 2026-10-27 dev2 review and current source correction

**Architecture:** Tom Dyer. **Coding, review response and sphere update:** ChatGPT GPT-6.

Claude's independently reproduced findings F1–F6, documented in Rasen Falcon REQ-00000241, have corrective code and interpreter tests in **new source artifact** `packages/oorexx_x25_v0.1-dev2` (dev1 remains historical). F1 rejects CALL with A=1 rather than interpreting the address block as basic BCD/Q; F2/F3 enforce channel-zero/global vs per-circuit identities; F4 enforces interrupt 1..32 octets; F5 resets both modulo-8 sequence numbers on local RESET_CONFIRM; F6 treats collision CLEAR as terminal without extra CLEAR_CONFIRM. Added `X25Packet~data` for Q/D/M, octet and P(S)/P(R) roundtrips.

The **non-transmitting typed inspection** model is explicit: DTE invalid P(S) => RESET cause 0, diag 1; DCE local procedure => RESET cause 5, diag 1. `inspectRaw` only proposes RESET diag38/39 for clearly scoped malformed packets and remains LOCAL_ONLY otherwise; it never fabricates recovery. These are testable packet objects, not submitted frames or committed receipts. Continue to fail closed until X.25 operator edition/role and link-level state machines are qualified.

**XTP source status changed:** `packages/oorexx_xtp_v0.1-dev30/docs/DIAG_REGISTRY.md` is the XTP owner's allocation authority. CODE 1/VALUES 16–23 are **reserved** as POLICY_DENIED, AUTH_REQUIRED, FACILITY_UNSUPPORTED, QUOTA_EXCEEDED, LOOP_DETECTED, INSPECTION_DENIED, NOT_READY, EMERGENCY_VETO. For DIAG wire responses: VALUE name or empty only, response no larger than provoking packet, and per-source/global rate limit. DIAG refusal may be sent before authentication; admitting foreign XTP traffic still requires FIRST/CNTL authentication. Persistent interactive FIRST-to-KEY context remains absent. This source has **no** live gateway DIAG sender.

Next highest-priority work: user-space LAPB frame/window/T1/N2 engine with deterministic injected clock and independent carrier adapters, followed by full PLP facilities, network XOT interoperability and gated GatewaySession. `docs/NOT_CLAIMED.md` remains the release truth. No Linux AF_X25 critical path.
## 2026-10-29 dev3 — implemented laboratory LAPB subset

The previous statements that **no LAPB source exists** apply only through dev2; a new and separately versioned [dev3 source artifact](../../packages/oorexx_x25_v0.1-dev3/README.md) now implements a modulo-8 LAPB frame/FCS and ASCII-bit HDLC stuffing model, DTE/DCE single-link addressing, V(S)/V(A)/V(R) receive and send states, RR/RNR/REJ, SABM/UA/DISC, caller-driven monotonic T1 and bounded N2. The exact evidence is [dev3 qualification](../../packages/oorexx_x25_v0.1-dev3/docs/QUALIFICATION.md), with six r13196 PASS suites. [DEV3_LAPB.md](DEV3_LAPB.md) is the source/ownership continuation note.

**Still not implemented/qualified:** physical sync serial or LLC2 driver, actual modem timing/clock, modulo-128, full PLP facilities/VC peer interoperability, real XOT TCP/1998, SocketProvider registration, XTP authenticated foreign ingress, persistent gateway session, MU↔MI rollout, LDAP or HTTPS integration. No privilege transfer from this lab code to XTP owner, Firewall Controller, QueueRexx MANAGEMENT or telemetry. The XTP owner has accepted DIAG 16–23 in dev30; do not invent a duplicate implementation here.

**Architecture:** Tom Dyer. **Coding and this sphere entry:** ChatGPT GPT-6. **Lane:** `x25-gateway`.
