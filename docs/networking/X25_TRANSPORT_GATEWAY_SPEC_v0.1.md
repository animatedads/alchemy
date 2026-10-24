# ooRexx X.25 Transport and Legacy Gateway — Engineering Specification 0.1

> **SUPERSEDED for implementation decisions (24 October 2026):** this earlier exploration has been replaced by the five architecture-approved specification candidates in [docs/X25_FAMILY_SPEC.md](../X25_FAMILY_SPEC.md), [docs/XTP_GATEWAY_SPEC.md](../XTP_GATEWAY_SPEC.md), [docs/SEMANTIC_MAPPING.md](../SEMANTIC_MAPPING.md), [docs/OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md) and [docs/NOT_CLAIMED.md](../NOT_CLAIMED.md). The primary X.25/LAPB/PLP backend is **user-space ooRexx**. Linux AF_X25 is optional compatibility only. X.25-over-XTP is separately specified; its L2/L3/L4 XTP underlays are not native X.25 IP protocol variants. This historical draft remains for provenance but is not the active engineering work order.


Status: **DESIGN ONLY — no X.25 runtime, carrier or hardware qualification is claimed**  
Date: 2026-10-24  
Repository: animatedads/alchemy  
Proposed owner: standalone `oorexx_x25` library and independently deployable `oorexx_x25_gateway` service  
Scope: direct L2 X.25 attachment; explicit L3 inter-site engineering profile; RFC 1613 XOT over L4 TCP; domain-isolated bridges to Alchemy.  
Decision: X.25 is an actual legacy network service with virtual-circuit semantics, **not** an alias for TCP, XTP, RPC or Queue Fabric.

## 1. Reason and intended users

Preserve useful existing terminal, banking, host, telemetry, industrial and carrier equipment by offering a standards-oriented X.25 DTE/DCE edge and a secured gateway to modern ooRexx services. The legacy equipment must continue to behave as an X.25 peer. Queue Fabric, RPC, JMS and RexxOS remain **optional applications of an admitted gateway**, never dependencies of the X.25 core.

The first deliverable should be a working two-ended software XOT lab. Hardware serial/LAPB is a separately qualified driver/profile; nothing in an XOT PASS asserts hardware timing, link-layer or real DCE interoperation.

## 2. Standards and vocabulary

- ITU-T X.25 / ISO/IEC 8208: packet-layer calls, data and virtual circuits. Exact edition/profile must be declared per link and peer. Do not silently blend facilities and modulo profiles.
- ISO/IEC 7776: LAPB-compatible HDLC data-link procedures for DTE and DCE contexts. Physical interfaces vary; DTE vs DCE clocking is hardware/profile-specific.
- X.121 numbering: legacy X.25 address space, not an IPv4/IPv6 address or proof of principal identity.
- RFC 1613 (Informational, not an Internet Standard): X.25 over TCP/XOT. **One TCP connection per VC**, destination TCP **1998**, four-octet XOT header (2-byte version 0; 2-byte X.25 packet length, network octet order). Invalid version/length closes TCP. Logical channel identity is local to the relevant interface/connection, not globally unique.
- RFC 1356 (standards track): **IP/CLNP/other network protocols over X.25** via Call User Data protocol identification and complete packet sequences. It is the reverse orientation from XOT, not a recipe for native raw-IP encapsulation of X.25.
- Neither X.25 nor ordinary XOT supplies modern encryption or strong endpoint authentication. A dialled X.121 address, TCP peer IP, LCN, or DTE/DCE role must never be accepted as a security credential.

Standards references: https://www.rfc-editor.org/rfc/rfc1613 ; https://www.rfc-editor.org/rfc/rfc1356 ; https://www.iso.org/standard/22172.html . The full X.25/ISO 8208 protocol editions and operator-specific profiles require separately licensed/reference-qualified conformance.

## 3. Layers and carrier truth

| Layer/entry | Proposed provider | Actual responsibility | Status / constraint |
| --- | --- | --- | --- |
| L2 physical equipment | synchronous serial line interface + HDLC/LAPB (DTE/DCE) | frames, FCS, SABM/UA/DISC, clocking, retries, LAPB timers/window, link state | Future; requires real adapter, platform driver and test rig |
| L2 carrier extension | explicitly configured transparent serial/HDLC pseudowire or circuit-emulation service | preserves frame ordering/boundaries and required timing; X.25 remains on the encapsulated link | Future; only through a specified/qualified pseudowire, **not** an invented X.25 Ethernet EtherType |
| L3 X.25 network service | X.25 packet layer with logical-channel routing / network-to-network gateway | X.121 route and per-link LCN translation, call admission and flow control | Future core packet-switching profile; not a generic IP socket |
| L3 inter-site IP infrastructure | explicitly configured encrypted IP tunnel or provider L3 underlay for approved encapsulation | moves packets between gateways; if raw packet-layer encapsulation is introduced, it needs a separate versioned bilateral frame specification | Proposed only; **no standard raw IP protocol number or GRE encapsulation is asserted here** |
| L4 | RFC 1613 XOT/TCP | standard interop carriage of X.25 packet layer over TCP/IP; one connection per VC | **P0 implementation target**; TCP/1998 with ingress policy and encrypted network perimeter |
| Application above X.25 | RFC 1356 IP-over-X.25; X.28/X.29 PAD, X.3 parameters; legacy vendor protocol; optional semantic adapters | consumes admitted VC data without losing binary/Q/D/M/call context | separate profiles, individually qualified |

**Crucial naming rule:** “L2/L3/L4 support” means supported attachment/carriage options, **not** three interchangeable forms of the original X.25 protocol. IP over X.25 (RFC 1356), X.25 over TCP (RFC 1613), and a private IP tunnel carrying HDLC frames are different interfaces.

## 4. Architecture and source boundaries

```text
             X.25 terminal / DTE / DCE / legacy host
                             |
                     native serial/LAPB
                             |       XOT peer via TCP/1998
                       X25LinkAdapter <---- X25XotAdapter
                             |             /
                  X25PacketEngine / X25CircuitRegistry
                             |
               X25GatewayPolicy + X121RouteAuthority
                             |
            +----------------+-----------------------+
            |                |                       |
        X25Relay         RFC1356 IP             X25ServiceAdapter
    X.25 <-> X.25        over X.25                  |
                                           SocketProvider / SocketSelector
                                           ConnectSelector / RPC / DirectCall
                                           Queue Fabric <-> JMS / RTO2
```

The stand-alone `oorexx_x25` package owns on-wire packet parsing, X.25 timers, DTE/DCE side semantics, VC state, address/facility interpretation and status causes/diagnostics. Concrete carrier adapters are optional separate modules with exact version/path dependencies; no vendored SocketProvider, XTP, Queue Fabric, RPC, Crypto or hardware driver copies. The optional gateway package owns routing, admission, auditing, bridge mappings and lifecycle. It must not duplicate network route authority or assume all bytes are text.

SocketSelector owns **socket/carrier acquisition**, including the TCP stream used for XOT, but cannot own X.25 call state. ConnectSelector owns **invocation-path authority** for an exposed service, not X.25 VC routing. XTP owns its own L2/L3/L4 route graph and must not be modified into an X.25 packet interpreter. RTO2 remains runtime continuity authority. Queue Fabric owns durable delivery semantics after a distinct, audited bridge boundary; X.25 acknowledgements are not Queue Fabric delivery receipts.

### ooRexx object seams (proposed, not existing API)

- `X25EndpointAddress`: X.121 address, subaddress/profile, incoming/outgoing peer policy; never flattened into host:port.
- `X25LinkProfile`: revision, DTE/DCE, numbering modulo, link windows/timers, maximum packet size, supported facilities, packet limits, explicit native-port identity.
- `X25Packet`: immutable validated binary bytes + parsed packet type/GFI/LCI/Q/D/M/P(S)/P(R) when applicable. Preserve original octets for interop and audit hashing.
- `X25VirtualCircuit`: unique local circuit handle; scoped `interface_id + lci + incarnation`; state, facilities, windows, timer identity, billing and route context.
- `X25CallRequest`, `X25CallResult`, `X25ClearCause`, `X25Diagnostic`: typed call outcomes and X.25 cause codes; never map a clear to a generic Boolean.
- `X25CarrierAdapter`: `open`, `readPacket`, `writePacket`, `close`, `observe`; capabilities distinguish physical LAPB frames, native X.25 packets and XOT packets.
- `X25XotSession`: strict 4-byte frame decoder + one-VC-per-TCP lifecycle; holds selected Socket connection object by identity.
- `X25RouteAuthority` and `X25GatewayPolicy`: explicit X.121 prefix/endpoint route, authorised peer, permissible facilities, security domain, concurrent VC quota, class of service and safe fallback.
- `X25GatewayReceipt`: separately records call admission/clear state and any downstream queue/RPC outcome; never conflates “received a packet” with “business transaction committed.”

All above are **names for a proposed contract** pending source/API review.

## 5. Packet engine and state behaviour

Initial profiles: X.25 basic DTE operation with modulo-8 packet sequencing, SVC call/accept/clear, data with M-bit complete-packet-sequence reconstruction, RR/RNR, reset, restart on applicable local interfaces, causes and diagnostics. Modulo-128, mixed-modulo interop, PVC XOT setup, Q-bit qualified data, D-bit confirmation, REJ, interrupt, reverse charge, fast select, CUG, throughput class, packet-size/window negotiation and X.29 PAD are tracked independently; never advertise a feature until tests exist.

- Call path: resolve incoming interface and X.121 destination; validate profile/CUD/facilities; apply admission policy; allocate an unused **local** LCI; begin call timer; accept or clear with an explicit cause.
- Circuit path: retain both ends' own LCI and modulo/window; enforce per-VC ordered packet delivery and backpressure. Do not re-use an old LCI until the old VC incarnation has ended and any delayed packets cannot be mistaken for new traffic.
- Data path: preserve binary payload and Q/D/M metadata. Negotiate maximum packet length and windows. Bound complete-sequence reassembly and buffer memory; reject unsupported facilities rather than erase them.
- Reset and restart: reset is scoped as specified by packet state; restart applies to a local interface and must **not** be blindly tunnelled over XOT (RFC 1613 §6.4). End-to-end interrupts/resets must be preserved where supported.
- Clear/failure: call clearing and confirmation use X.25 semantics. A dropped TCP path cannot prove an in-flight transaction did or did not complete; fail closed and report `UNKNOWN` at a gateway outcome boundary when appropriate.
- PVC: needs a separately qualified RFC 1613 PVC setup/compatibility state machine; reconnect is not automatically a licence to replay business data. Persistent circuits must recover explicit state, not invent “exactly once.”
- Flow-control adaptation: end-to-end vs local RR/RNR discipline must be declared. Mixed modulo 8/128 requires real translation/negotiation and appropriate P(S)/P(R) values; no raw header pass-through assumption.
- Circuit moves between MI/MU nodes require a proved continuation contract; absent that, fail old VC and establish a new call. Never silently migrate a live X.25 circuit as if it were a Queue Fabric job.

## 6. XOT P0 exact wire contract

RFC 1613 XOT frame: `uint16 version=0` + `uint16 length` in network byte order followed by **exactly** `length` bytes of one X.25 packet. A TCP read may yield partial headers/payloads or multiple consecutive frames; decoder must buffer incrementally and cap both frame length and aggregate buffer size. Reject version mismatch, impossible packet length, truncated/abnormal EOF and resource exhaustion. Do not treat TCP read boundaries as packet boundaries. No application payload in TCP SYN.

One TCP connection corresponds to exactly one X.25 VC, and the XOT session identity is not the arbitrary X.25 LCN value. The receiving X.25 side allocates/translates its own LCI. Require incoming-call validation before use. Control-packet handling, lifecycle, reset/interrupt, end-to-end versus local flow control, modulo translation and optional PVC handshake follow RFC 1613 §§5–6, **not** a generic length-prefix socket wrapper.

P0 can use a **software XOT emulator on both ends**; physical DCE or real Cisco/other XOT peer interop is a separate release gate. Test against independent implementations and supplied protocol traces before claiming RFC 1613 interoperability.

## 7. Security, policy and operator constraints

No public Internet XOT listener by default. TCP/1998 and raw serial port access are explicitly provisioned, isolated by network and identity policy, and disabled outside their allowlisted peers. For XOT, use an approved secure tunnel (e.g. authenticated VPN) or a deliberately evaluated TLS-proxy profile; the legacy XOT peer normally speaks **plain TCP** and needs an appropriate edge proxy, not invented “TLS-XOT” compliance. Encryption at the underlay does not authenticate X.121 callers by itself.

- Require per-peer facility permissions, X.121 prefix route allowlists, acceptable direction (incoming/outgoing), per-tenant security-domain isolation and maximum active calls/bytes/packet rate.
- Disallow unreviewed reverse charging and pay-per-call chargeable facilities; include a cost/charge budget and log of attempted billing flags.
- Restrict call user data, PAD terminal access and application-service bindings to explicit policies. Protect sensitive payloads; logs normally capture event fields, lengths, causes and non-reversible digests, not confidential data or credentials.
- No automatic fallback from encrypted or authenticated transport to naked XOT, and no downgrading policy because XTP/TCP route metrics prefer another path.
- Application messages may be non-idempotent; queue insertion or RPC dispatch after link loss requires a durable correlation record, deduplication policy and an `UNKNOWN` state where success cannot be proven.
- Hardware operations and routes require explicit authority. No exploratory calls to public X.121 networks during discovery.

## 8. Integration decision matrix

| Desired behaviour | Owning interface | Evidence to preserve |
| --- | --- | --- |
| Legacy device communicates with legacy host | X.25 relay + DTE/DCE/XOT adapters | two-sided VC state, facilities, clear cause |
| Legacy application speaks to a modern service | X25ServiceAdapter -> ConnectSelector | binary application framing, typed call/admission outcome, exact service/callback policy |
| Carry IP over an X.25 link | RFC 1356 profile, not SocketSelector inference | negotiated NLPID and packet sequence/MTU |
| Move durable work to Queue Fabric / JMS | explicit gateway + Queue Fabric/JMS bridge | durable insert before upstream acknowledgement; outbound JMS ACCEPTED/REJECTED/UNKNOWN |
| Reach a different MI/MU | permitted SocketProvider/XOT underlay and separately qualified VC handling | node route, incarnation/fencing, circuit state; no silent live VC migration |
| Operate legacy physical line | native serial adapter, LAPB and hardware driver | FCS, timing, line events, profile and real DCE traces |

Discovery shall expose current **qualified** offers, not a static catalogue: a host without a line card cannot offer serial LAPB; an XOT server whose safe listener is disabled cannot advertise inbound XOT; an untested PVC profile cannot be offered as supported.

## 9. Qualification and acceptance gates

**P0 — source and deterministic software lab**
1. Formal `X25Packet` decoder/parser and `X25XotSession` framing with reference fixtures and differential traces; malformed-byte corpus and bounded parsing.
2. SVC call, call accepted, data, RR/RNR, clear and TCP disconnect as reproducible in-memory simulations with exact X.25 packet-state assertions.
3. Independent XOT endpoints connected on loopback; zero/one/many TCP read boundaries, split/coalesced writes, EOF and 4-byte header poison tests.
4. Capability registry advertises XOT lab only; all unsupported facilities return explicit negative or `NOT_QUALIFIED`.
5. Exact dependency/ABI/ooRexx-r13196 source qualification, method-level comments, no Python core runtime and no fabricated test passes.

**P1 — interoperable XOT gateway**
1. RFC 1613 TCP/1998 live tests with a distinct/vendor-independent known implementation.
2. Prove parallel VCs, collision, out-of-order rejects, pressure, packet-size/window negotiation, modulo-8 and optional modulo-128, malformed XOT length, caller route restrictions.
3. Harden security domain, quotas, audit, cost/reverse-charge safety and adverse/failure tests.
4. Prove downstream Queue Fabric/RPC semantics and `UNKNOWN` on ambiguous disconnect. No “exactly once” claim without a full end-to-end model.

**P2 — native L2 qualification**
1. Real DTE/DCE-compatible interface including clocking with LAPB HDLC FCS, link up/down, frame windows/timers, reproducible traces.
2. Physical equipment interop and loopback, serial adapter unplug, busy link, signal loss and restart, including software state recovery.
3. Optional transparent L2 extension qualifies frame/timing accuracy separately from native physical link.

**P3 — packet-network services and broader legacy**
1. Native X.25 packet relay, additional SVC/PVC/facility profiles, mixed-modulo, ISDN packet-mode if demanded.
2. RFC 1356 IP/CLNP when needed, plus X.28/X.29 PAD and X.3 profile separately.
3. Multiple live MI/MU placements, high availability with **explicit** VC teardown/resumption handling; retain RTO2 runtime authority and no invented circuit continuity.

No phase may be marked production-qualified based on docs, passing parser unit tests, or simulated hardware.

## 10. Near-term task ledger

- **X25-001:** register dedicated `oorexx_x25` source owner, standards/profile matrix, API object responsibilities and negative capability truth.
- **X25-002:** implement pure ooRexx XOT 4-byte decoder/encoder and bounded tests. Reuse the actual ooRexx interpreter and available COTS socket provider; no fabricated socket layer.
- **X25-003:** implement typed VC state machine, X.121 routing and interface-scoped LCI remapping.
- **X25-004:** expose socket family via selected `SocketAddress` with faithful typed circuit API; distinguish message/VC semantics from generic stream capabilities.
- **X25-005:** independent XOT peer interop + security and failure campaign.
- **X25-006:** native LAPB driver discovery, real serial hardware acquisition and bench tests.
- **X25-007:** build gateway adapters to ConnectSelector, Queue Fabric and JMS, preserving existing authority/disposition rules.
- **X25-008:** create a source-qualified LLM Gopher X.25 engineering sphere once concrete code, revision provenance and test evidence exist; **do not** stamp design prose as a qualified sphere.

## 11. Existing Alchemy references and non-claims

Source inspected 2026-10-24:
- `packages/oorexx_socket_provider/README.md`: SocketSelector/SocketProvider, dynamic per-turn offers and exact SocketAddress identity; XTP, NORM, TLS and socket families are not X.25.
- `packages/oorexx_network_transport_intentions/README.md`: read-only transport resolution/intention reporting, not packet/circuit implementation.
- `packages/oorexx_xtp/docs/PROTOCOL_PROFILE.md`: XTP raw protocol 36, Ethernet and UDP carriage belong to **XTP**, not X.25.
- `spheres/connect_selector_gopher_sphere_v0.1/CONNECT_SELECTOR_SPHERE.md`: ConnectSelector dev6, RPC/Queue/JMS/RTO2 authority and `UNKNOWN` disposition rule.

Repository search found no dedicated X.25 implementation at this checkpoint. This document establishes a **specification and work programme**, not deployed L2/L3/L4 X.25 support.
