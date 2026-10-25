# X.25 SocketSelector Family Specification — v0.1

> **2026-10-25 source reconciliation (ChatGPT GPT-6):** XTP dev29 implements segmented unicast messages, selective retransmission, SYNC/ECHO and DIAG. FIRST/CNTL authentication and a persistent interactive stream context remain unresolved. Independent ooRexx lab source is in [`packages/oorexx_x25_v0.1-dev1`](../packages/oorexx_x25_v0.1-dev1/README.md), with interpreter tests only. Architecture: Tom Dyer. Coding and this correction: ChatGPT. No gateway or hardware qualification is inferred.

**Architecture:** Tom Dyer. **Coding:** ChatGPT (not undertaken by this specification). **Document/update written by:** ChatGPT (GPT-6), 24 October 2026.  
**Status:** design only. **Primary implementation:** user-space ooRexx X.25 PLP + LAPB; Linux AF_X25 is optional compatibility, not an architectural prerequisite.

## 1. Ownership and model

X.25 is a first-class, circuit- and record-oriented SocketSelector family, not a synonym for TCP, XTP, Queue Fabric or RPC. The independently usable user-space \`oorexx_x25\` library owns DTE/DCE-facing state machines, packets, link and VC lifecycles, timers, diagnostics and facilities. Concrete link drivers and the optional \`oorexx_x25_socket_binding\` are adapters, not mandatory dependencies. A separate \`oorexx_xtp_gateway\` service owns policy-admitted protocol bridges, never the X.25 normative behaviour.

**Verified repo references:** [SocketProvider source](../packages/oorexx_socket_provider/src/SocketProvider.cls) and [README](../packages/oorexx_socket_provider/README.md) establish selected SocketAddress identity, \`SocketCapabilities\` and dynamic negotiation; the [compatibility ledger](../packages/oorexx_socket_provider/CURRENT_PROVIDER_COMPATIBILITY.md) names externally qualified dev16 while in-repo sources carry dev14 labels. [XTP named service contract](../packages/oorexx_xtp_v0.1-dev29/docs/NAMED_SERVICES.md) establishes FIRST service name 0xA11C and route authority; [dev29 gap ledger](../packages/oorexx_xtp_v0.1-dev29/docs/XTP_SPEC_GAPS_DEV29.md) confirms unicast segmentation, selective retransmission, SYNC/ECHO and DIAG, while FIRST/CNTL authentication and persistent interactive FIRST-to-KEY context remain outstanding. [ConnectSelector sphere](../spheres/connect_selector_gopher_sphere_v0.1/CONNECT_SELECTOR_SPHERE.md) distinguishes invocation decisions from delivery guarantees. Those upstream files were read. The subsequent `packages/oorexx_x25_v0.1-dev1/` adds a lab-tested modulo-8 packet parser, XOT framer and non-transmitting virtual-circuit transition skeleton, not a complete X.25 stack.

**Standards:** ITU-T X.25 / ISO 8208 (version/profile-specific); LAPB via ISO/IEC 7776; X.121 addressing; ISO/IEC 8881:1989 LLC-based X.25/PLP over IEEE 802 LANs (both LLC Type 2 and Type 1 variants); [RFC 1613 XOT](https://www.rfc-editor.org/rfc/rfc1613); [RFC 1356 IP/CLNP over X.25](https://www.rfc-editor.org/rfc/rfc1356). ISO/ITU edition-specific details require authoritative conformance traces. No assumption is made that Linux lapbether implements ISO 8881.

## 2. Address and negotiated endpoint API — proposed

\`\`\`rexx
x25addr = .SocketAddresses~x25("234220123456", subaddress, callUserData, profileRef)
registeredAddresses~register("legacy.payment.switch", x25addr)
circuit = sockets~sender("legacy.payment.switch")
\`\`\`

- X.121 DTE address: 1–15 decimal digits within the chosen national/network profile. A subaddress is a separately typed and validated facility/profile field, not casually appended to the dialled number.
- Call User Data (CUD): bounded **binary bytes**, including protocol identification when applicable, never a security credential or host:port.
- \`profileRef\`: exact X.25 edition, link interface, DTE/DCE role, supported facilities, packet sequencing modulo and policy reference. Keep the complete resolved \`SocketAddress\` object, rather than flattening into strings.
- Proposed objects: \`X25Address\`, \`X25Link\`, \`X25Packet\`, \`X25CallRequest\`, \`X25FacilitySet\`, \`X25VirtualCircuit\`, \`X25CircuitReceipt\`, \`X25CauseDiagnostic\`, \`X25CallUserData\`, \`X25TransportOffer\`. VC identity is \`interfaceId+LCN+incarnation\`; XOT TCP stream ID is also part of identity.
- \`SocketProvider\` owns *which* available provider to acquire, not PLP transition logic. X.25 extension methods expose accept/call, data with Q/D/M, interrupt, reset, clear, read cause/diagnostic, and facilities; existing generic send/recv cannot express everything.
- Do **not** misrepresent an X.25 packet/circuit as a byte stream just because its XOT underlay is TCP.

### Capability truth (by actual backend and endpoint)

| Offered family/profile | stream | listener | sender | secure | multicast |
| --- | --- | --- | --- | --- | --- |
| X25 generic (abstract) | false | conditional | conditional | false | false |
| Native LAPB+PLP | false | only with qualified adapter/route | only with qualified adapter/route | false | false |
| ISO 8881 LLC2/PLP | false | only with qualified adapter | only with qualified adapter | false | false |
| RFC 1613 XOT/PLP | false | only with qualified XOT binding | only with qualified XOT binding | false | false |
| X.25 PLP over XTP (private) | false | only with qualified authenticated XTP binding | same | false | false |

\`secure=false\` at the X.25 family level: X.25 has no encryption or modern cryptographic peer identity; an authenticated VPN or deliberately qualified encapsulating security provider can **separately** satisfy security requirements, without claiming that X.25 itself is secure. Capability offers are dynamic and require current route, interface, binding, identity authority, state machine and policy evidence; absent components are \`NOT_QUALIFIED\`.

## 3. Layer/carrier matrix

The estate's L2 **MU–MI direct**, L3 **native IP**, and L4 **UDP** are XTP route **underlay** classifications; they are not claims that ISO X.25 defines those same three variants.

| Service/profile | Real link/carriage | Relation to user's L2/L3/L4 | Boundary |
| --- | --- | --- | --- |
| Native X.25 over LAPB over synchronous serial/HDLC | physical V.35/X.21/appropriate serial, clocking, FCS | legacy **L2** | native DTE/DCE profile and link timers |
| X.25/PLP over LLC Type 2 (ISO 8881) | IEEE 802 LAN/LLC2 | legacy **L2 LAN** | separately qualify LLC2, not interchangeable with LAPB |
| X.25/PLP over LLC Type 1 (ISO 8881) | ISO 8881 LLC1 profile | legacy **L2 LAN** | separate edition-specific profile and limitations |
| Linux LAPB-over-Ethernet virtual device | lapbether, where available | laboratory **L2** | Linux-specific compatibility, NOT ISO 8881 proof |
| XOT (RFC 1613) | TCP/IP to port 1998 | **L4 TCP**, **not UDP** | RFC 1613 X.25 packet framing, one TCP connection per VC |
| X.25 packet PDUs via XTP (private) | XTP's selected route | XTP **L2 direct**, **L3 raw-IP 36**, **L4 UDP** | private envelope; endpoint X.25 semantics retained |
| RFC 1356 | IP/CLNP packets **inside** X.25 circuits | opposite layering direction | optional payload-family binding, not X.25 over raw IP |

Current [IANA IP protocol registry](https://www.iana.org/assignments/protocol-numbers) assigns protocol **36 to XTP**; no raw IP protocol number specifically assigned to X.25 was identified. Do not register or transmit X.25 as protocol 36. XOT is not X.25 over UDP. If a private raw-IP X.25 encapsulation is ever required, design/number it explicitly and do not label it standard.

## 4. Portable, user-space ooRexx architecture — normative implementation choice

**Linux AF_X25/LAPB is not the primary backend.** The user has reported unreliable practical experience. The native kernel stack may be exposed as an opt-in \`LinuxX25CompatibilityBinding\` on a pinned, tested kernel, isolated behind the same contract. Its presence cannot be relied upon for correctness, portability, event instrumentation or filtering.

\`\`\`text
X25SocketFamily / X25Address / X25Circuit
  -> X25PacketEngine (call, facilities, per-LCN VC state, Q/D/M, interrupts)
  -> X25LinkService (LAPB: SABM/UA/DISC/DM/FRMR, information/supervisory frames)
  -> X25CarrierAdapter (sync serial / LLC2 / XOT TCP / XTP packet carriage)
  -> selected native OS I/O or SocketProvider/XTP
\`\`\`

**LAPB minimum:** frame encoder/decoder, HDLC delimiting/bit stuffing where hardware does not supply it, FCS, address/control, I/S/U supervisory frames, DTE/DCE, modulo/window discipline, T1 response/retransmission timer, N2 retry count, link reset, T3/idle where profile demands, SABM(E)/UA/DISC/DM/REJ/RR/RNR/FRMR handling, bounded receive/send queues, exact line-down recovery and link epoch fencing. A board/driver that already does HDLC framing/FCS must declare that so the ooRexx layer does not apply it twice.

**Packet layer minimum:** versioned X.25 packet parser, per-interface LCN allocation and state, SVC outgoing/incoming CALL and CALL ACCEPTED, CLEAR/CONFIRM, RESET/CONFIRM, RESTART/CONFIRM as appropriate, user DATA sequencing with windows, RNR/RR, interrupt delivery, Q/D/M support, segmentation/reassembly bounds, errors/causes/diagnostics, negotiated/denied facilities, per-VC timers (e.g. call/clear/reset/restart timer set per edition), no premature reuse after teardown. PVCs are a separately qualified profile. Buffers always bounded, including worst-case CUD and no-read peer.

**I/O:** synchronous serial driver or device bridge with explicit framing/clock capabilities; raw Ethernet/LLC2 with filter/privilege isolation; SocketProvider TCP for XOT; XTP's owned route and native API for private carriage. ooRexx owns state, timers, policy-readable objects, logging and discovery. Native C/C++ or existing OS calls are permitted only for hardware access, low-level raw packet I/O, buffer pinning or suitably justified time-critical frame operations; no blanket switch to Python/JSON. Native bindings declare ABI, ownership, thread attachment and exact runtime versions.

## 5. X.25 features NOT reducible to TCP

| X.25 semantic | Implementation contract | Gateway behaviour when peer has no analogue |
| --- | --- | --- |
| CALL, CALL ACCEPTED, CLEAR and cause/diagnostic | explicit transition/cause model | admit before accept, explicit typed refusal, never call TCP connect “accepted application” |
| RESET and reset diagnostic | per-VC reset, not TCP close | propagate only if target supports equivalent; otherwise abort with typed \`RESET_UNREPRESENTABLE\` |
| CUG | network facility + peer-specific admission | require CUG policy, deny unsupported CUG, no CUG-as-authentication |
| packet-size facility | common classic default 128 octets (profile authoritative) | bound fragmentation/segmentation and aggregate memory |
| window-size facility | common classic default 2 packets (profile authoritative) | independent X.25 window, no TCP window equivalence |
| throughput class | negotiated facility | map to authorised governor budget or refuse |
| reverse charging | billable policy effect | refuse by default pending cost authority |
| fast select | call-associated extended CUD, up to 128 octets in supported profile | retain data and dispatch policy on call stage, not ordinary stream data |
| INTERRUPT | out-of-band up to 32 octets in standard profile | typed event/sideband or explicit refusal; never merge into byte stream silently |
| Q bit | qualified user-data indication | preserve in message type; content filters see qualifier |
| D bit | end-to-end delivery confirmation within X.25 semantics | distinguish from local/transport/application acknowledgement; no stronger guarantee than downstream |
| M bit | more-data segmentation indicator | bounded whole-message reconstruction while preserving original units |
| CUD protocol identifier | binary application/encapsulation identification | preserve bytes; explicit allowlist for service/application mapping |
| PVC | administratively established VC | independent setup/reconnect state, no magical replay |

**X.25 PAD support:** an independent \`X25Pad\` service provides X.3 parameter registry/defaults and enforcement, X.28 asynchronous terminal↔PAD behaviour and commands, X.29 PAD↔host control messages with safe user/session policy; character encoding, echo, flow control and escape handling remain typed. No PAD capability should be advertised before separate terminal/host traces pass. PAD is not “TCP telnet” by assumption.

## 6. Private X.25-over-XTP envelope and gaps

Private encapsulation transports *X.25 packet PDUs*, not raw sync HDLC frames. Proposed versioned header: profile ID, gateway/session ID, link/interface identifier, per-side circuit ID+incarnation, original packet type and octet length, explicit Q/D/M metadata (if extracted), sequence, authenticated peer and policy context, hop budget, then losslessly retained packet bytes. Validate both outer and X.25 inner lengths. Explicit transform rules translate local LCNs; no X.121 address baked into XTP service descriptors. Per-session replay/fencing, ordered delivery, backpressure and bounded fragmentation/reassembly are prerequisites.

Do not enable a live X.25-over-XTP gateway beyond controlled laboratory work until the XTP owner closes the remaining [dev29 gaps](../packages/oorexx_xtp_v0.1-dev29/docs/XTP_SPEC_GAPS_DEV29.md): authenticated FIRST/CNTL and a persistent interactive FIRST-to-KEY context. dev29 already delivers segmented unicast messages, selective retransmission, SYNC/ECHO and refusal DIAG; those are no longer blockers as standalone features, but message segmentation does not make a persistent session. XTP route failover does **not** imply migrated X.25 VC state; circuit continuity remains unqualified.

## 7. Prioritised qualification

1. P0: pure ooRexx PLP state machine + LAPB controlled deterministic fake I/O and timed state tests; raw binary packet vectors; RFC1613 XOT framing with 4-byte header (version 0, length), segmented/coalesced TCP reads, one connection per VC and TCP/1998. No hardware claim.
2. P1: live two-ended XOT software interoperability and adversarial connection/facility/LCN tests; security envelope/peer authentication qualified.
3. P2: serial DTE/DCE hardware LAPB and ISO8881 LAN profiles independently interoperate with known peers; device remove/reset, clocking, FCS and sustained soak tests.
4. P3: X.25 over authenticated XTP L2/L3/L4 carriage and failover after all above XTP gates, including MTU/buffering/route changes, without claiming live circuit migration.

Software/test sources must use ooRexx first, real interpreter qualification, exact dependency versions/paths and provide explicit NOT_RUN/NOT_QUALIFIED for hardware and missing providers. See [NOT_CLAIMED](NOT_CLAIMED.md).
