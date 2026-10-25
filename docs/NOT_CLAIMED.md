# Non-Claims and Qualification Ledger — X.25 Family / XTP Gateway v0.1

> **2026-10-25 audited delta:** new ooRexx X.25 dev1 laboratory source exists and ran three interpreter test suites, but does not implement LAPB, full X.25 PLP, live XOT, SocketSelector registration or any GatewaySession. XTP dev29 already has segmented unicast messages, selective retransmission, SYNC/ECHO and source-bound DIAG; it still lacks FIRST/CNTL authentication and long-lived interactive context. Architecture: Tom Dyer; coding and correction: ChatGPT GPT-6. Do not misread `SOURCE IMPLEMENTS` as field or production qualification.

**Architecture:** Tom Dyer. **Coding:** ChatGPT (not performed by this specification delivery). **Document/update written by:** ChatGPT (GPT-6), 24 October 2026.  
**Status:** FIVE-DOCUMENT DESIGN SPECIFICATIONS, NOW FOLLOWED BY A SEPARATE LIMITED ooRexx LAB IMPLEMENTATION. This ledger must accompany all references to [X25_FAMILY_SPEC](X25_FAMILY_SPEC.md), [XTP_GATEWAY_SPEC](XTP_GATEWAY_SPEC.md), [SEMANTIC_MAPPING](SEMANTIC_MAPPING.md), [OPEN_QUESTIONS](OPEN_QUESTIONS.md).

## Not implemented or qualified by these documents

| Claimed capability | Actual state as of documentation | Evidence needed before promotion |
| --- | --- | --- |
| ooRexx LAPB stack (T1/N2, FCS, window, DTE/DCE) | **PROPOSED, NOT CODED** | source, real interpreter qualification, protocol traces and physical/link test |
| ooRexx X.25 PLP SVC/PVC, facility, PAD and modem interface | **PARTIAL SOURCE: dev1 modulo-8 parser and nontransmitting SVC skeleton pass synthetic r13196 tests; full PLP, facilities, PVC, PAD and drivers NOT CODED** | per-LCN full VC and flow-window state, X.25 edition vectors, legacy equipment interoperability |
| X.25 \`SocketAddresses~x25(...)\` and new provider binding | **PROPOSED, NOT CODED** | accepted SocketProvider owner integration with exact current dev16 source and tests |
| ISO 8881 LLC2 over IEEE 802 LAN | **PROPOSED, NOT CODED** | specified LLC2 adapter, certification/known-good traces; Linux lapbether does not prove ISO 8881 |
| Native sync serial, V.35, X.21 or HDLC hardware path | **UNVERIFIED HARDWARE** | exact device/driver/clocking/loopback, DTE/DCE interoperability, sustained line soak |
| RFC 1613 XOT X.25 gateway | **PARTIAL dev1 XOT version/length framer with deterministic interpreter tests; live TCP/1998 gateway NOT CODED** | standards-compliant TCP/1998, 4-byte XOT header, one TCP stream per VC, hostile/truncated/segmented reads, independent peer interoperability |
| X.25 over XTP L2/L3/L4 | **PROPOSED PRIVATE ENCAPSULATION** | versioned envelope, authenticated XTP session context, real L2 MTU, raw-IP XTP routing and UDP-underlay qualification |
| XTP FIRST-to-KEY persistent stream | **KNOWN GAP in reviewed dev29** | accepted native XTP API + real multi-packet context tests |
| XTP unicast segmentation / arbitrary-size traffic | **XTP dev29 SOURCE IMPLEMENTS segmented unicast messages, selective retransmission and SYNC/ECHO; no gateway X.25 PDU mapping qualified** | owner-accepted source+tests as documented in dev29; new gateway persistent circuit/payload/session testing |
| XTP authenticated FIRST/CNTL | **KNOWN GAP in reviewed dev29** | cryptographically authenticated control traffic with anti-replay/time-window tests and deployment keys |
| XTP DIAG explicit refusal | **PARTIAL dev29 IMPLEMENTED (packet type 8, CODE 1; VALUE 1,2,3), SOURCE-BOUND BUT UNAUTHENTICATED; gateway VALUE mapping not accepted** | first/CNTL authentication, new gateway reason codes agreed with XTP owner; independent secure refusals |
| SocketProvider half-close / \`shutdownSend()\` | **NOT IN REVIEWED COMMON CONTRACT** | SocketProvider owner approval and regression across eligible families |
| Gateway policy/Session object, immutable generation pinning | **SPEC ONLY** | state-machine tests under concurrency, power failure, reload, emergency veto, capacity pressure |
| Tamper-evident gateway journal, opt-in captures | **SPEC ONLY** | injected Crypto/key authority, anchoring, access/retention/legal policy, journal corrupt/recovery tests |
| Hostile-source Firewall Controller integration | **EXISTING COMPONENT VERIFIED; NEW GATEWAY INTEGRATION NOT CODED** | request/receipt authorisation, replay and protected-source functional qualification |
| Instrumentation Mesh + Inspector Clouseau bridge | **EXISTING COMPONENTS VERIFIED; GATEWAY ADAPTER NOT CODED** | post-commit ordering, redaction, cardinality, read-only hooks and snapshot tests |
| Foreign ingress ephemeral XTP identity and lease | **SPEC ONLY; MUST REMAIN DISABLED** | FIRST/CNTL authentication, permission fencing, TTL cleanup, lifecycle ties, anti-spoof tests |
| X.25 CUG identity/privilege enforcement | **SPEC ONLY** | real network/operator facility profile and authenticated principal independent from address/CUG |
| Reliable application-level delivery/exactly-once across X.25/XTP/TCP/JMS | **NOT CLAIMED** | explicit end-to-end durable application acknowledgement, idempotency and transaction model |
| In-flight VC preservation across gateway/MI/MU failure | **NOT CLAIMED** | fencing, complete circuit state checkpoint and reproducible recovery with peer protocol conformity |
| Production-ready security and traffic inspection | **NOT CLAIMED** | security review, auth commissioning, bounded hostile traffic, privacy/retention review and test evidence |

## What was actually inspected

These were read in GitHub as of 2026-10-24, and **only their own stated scope** may be used:

- [SocketProvider implementation core](../packages/oorexx_socket_provider/src/SocketProvider.cls) + [README](../packages/oorexx_socket_provider/README.md) + [external dev16 compatibility ledger](../packages/oorexx_socket_provider/CURRENT_PROVIDER_COMPATIBILITY.md). In-repo historical labels are not upgraded by citation.
- [XTP dev29 named services](../packages/oorexx_xtp_v0.1-dev29/docs/NAMED_SERVICES.md), [README](../packages/oorexx_xtp_v0.1-dev29/README.md) and [dev29 gaps](../packages/oorexx_xtp_v0.1-dev29/docs/XTP_SPEC_GAPS_DEV29.md).
- [SSH-over-XTP candidate4](../packages/ssh_over_xtp_v0.1-candidate4/README.md) is **development only**, explicitly unqualified for candidate4 WAN.
- [Operational Degradation Planner dev5](../packages/oorexx_operational_degradation_planner_v0.1-dev5/README.md), [Firewall Controller](../packages/oorexx_firewall_controller/docs/ARCHITECTURE.md), [Instrumentation Mesh sphere](../spheres/oorexx_instrumentation_mesh_gopher_sphere_v0.1/README.md), [Observation v0.5](../packages/oorexx_observation_v0.5/README.md), [Instrumentation Intentions](../packages/oorexx_instrumentation_intentions/README.md), [Storage instrumentation pattern](../packages/oorexx_storage_fabric_instrumentation_mesh_v0.1-dev5/README.md), [Inspector Clouseau](../packages/oorexx_inspector_clouseau/README.md), [ConnectSelector sphere](../spheres/connect_selector_gopher_sphere_v0.1/CONNECT_SELECTOR_SPHERE.md).
- Standards/public references: [RFC 1613](https://www.rfc-editor.org/rfc/rfc1613), [RFC 1356](https://www.rfc-editor.org/rfc/rfc1356), [ISO 8881](https://www.iso.org/standard/16394.html), [IANA protocol number registry](https://www.iana.org/assignments/protocol-numbers).

No claim of current uploaded kernel driver safety, live deployed serial equipment, current XTP source/ABI above checked repo documents or passing implementation tests is made. The five canonical documents remain specification artefacts. [New ooRexx X.25 dev1 lab source](../packages/oorexx_x25_v0.1-dev1/README.md) implements only a packet decoder, XOT frame parser and an explicitly non-transmitting SVC transition subset, with bounded deterministic r13196 tests documented in [QUALIFICATION](../packages/oorexx_x25_v0.1-dev1/docs/QUALIFICATION.md).

## Dependency, implementation and safety boundaries

- ooRexx first. Native I/O bridge only for genuine low-level framing, hardware and OS/socket access; pin exact ABI/lifecycle and avoid duplicated XTP/SocketProvider/Crypto implementations. Python is not required for runtime or core tests. Do not flatten complete ooRexx objects when they cross into gateway control/telemetry.
- No live changes to MI/MU routes, firewalls, secrets, host adapters, services or operational classes are part of this delivery.
- No service opens externally by default. Do not treat source addresses/ports/X.121 as cryptographic identity. Capture is always opt-in, bounded and authorised.
- Proposed controls and X.25/XTP semantics must stay separate from existing qualified source unless explicit component-owner work is admitted.

## Admission criteria for next status

**DESIGN ACCEPTED**: review and approve the five documents.  
**SOURCE ADMITTED**: independently checked module with exact source checksum, tests, license and dependencies.  
**LAB QUALIFIED**: real ooRexx interpreter and independent software XOT peer with adverse fixtures.  
**FIELD QUALIFIED**: selected serial/LAN equipment and deployed XTP L2/L3/L4 routes measured with realistic network loss and positive authentication.  
**PRODUCTION ACCEPTED**: all security, source, recovery, policy, privacy, telemetry and owner gates signed off.

No stage may be skipped by substituting a documentation check or mocked provider for real field evidence.
