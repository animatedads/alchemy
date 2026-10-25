# XTP Gateway Service Specification — v0.1

> **2026-10-25 dev29 reconciliation:** Read `packages/oorexx_xtp_v0.1-dev29/{README.md,docs/XTP_SPEC_GAPS_DEV29.md}`. dev29 closes prior segmentation, selective-repeat, SYNC/ECHO and DIAG gaps but does not provide authenticated FIRST/CNTL or a long-lived interactive stream. Existing base DIAG VALUE=1/2/3 must not be redefined; propose gateway-specific values only under XTP-owner control. A separate ooRexx X.25 lab parser/XOT framer/VC skeleton now exists in [`packages/oorexx_x25_v0.1-dev1`](../packages/oorexx_x25_v0.1-dev1/README.md); it is not a working GatewaySession. Architecture: Tom Dyer. Coding and correction: ChatGPT GPT-6.

**Architecture:** Tom Dyer. **Coding:** ChatGPT (implementation not begun by this work). **Document/update written by:** ChatGPT (GPT-6), 24 October 2026.  
**Status:** specification only. Filtering, logging, control and inspection are design-time requirements, not post-hoc modules. **Related:** [X25_FAMILY_SPEC](X25_FAMILY_SPEC.md), [SEMANTIC_MAPPING](SEMANTIC_MAPPING.md), [OPEN_QUESTIONS](OPEN_QUESTIONS.md), [NOT_CLAIMED](NOT_CLAIMED.md).

## 1. Ownership and verified source inventory

The gateway is one independently deployable service hosting protocol-aware Session objects, policy and route translation, but **not** a replacement for SocketSelector, XTP, ConnectSelector, X.25 PLP, Firewall Controller, the degradation planner or the instrumentation plane. Its ingress and egress are independently selected and explicitly admitted, including protocol-specific controls and exit status.

**Verified from GitHub source, 2026-10-24:**
- [SocketProvider](../packages/oorexx_socket_provider/README.md) + [core classes](../packages/oorexx_socket_provider/src/SocketProvider.cls) own socket acquisition, address object identity and dynamic offers. [Compatibility ledger](../packages/oorexx_socket_provider/CURRENT_PROVIDER_COMPATIBILITY.md) says externally qualified dev16; GitHub source retains dev14 labels.
- [XTP named services](../packages/oorexx_xtp_v0.1-dev29/docs/NAMED_SERVICES.md) carry canonical service name via private FIRST descriptor 0xA11C and resolve carrier via ROUTE table, never service-record IP. [XTP dev29 README](../packages/oorexx_xtp_v0.1-dev29/README.md) and [gap ledger](../packages/oorexx_xtp_v0.1-dev29/docs/XTP_SPEC_GAPS_DEV29.md): segmented unicast messages, selective retransmission, SYNC/ECHO and DIAG exist; FIRST/CNTL authentication and persistent interactive FIRST-to-KEY context do not. Only the latter remain hard gateway ingress release gates.
- [SSH over XTP candidate4](../packages/ssh_over_xtp_v0.1-candidate4/README.md) is a development-only, one-purpose OpenSSH ProxyCommand ↔ XTP named service bridge; candidate4 explicitly uses transaction-per-frame workaround, not a persistent stream and has no candidate4 WAN qualification.
- [Operational Degradation Planner dev5](../packages/oorexx_operational_degradation_planner_v0.1-dev5/README.md) owns service class, capacity domains and reconciliation.
- [Firewall Controller](../packages/oorexx_firewall_controller/docs/ARCHITECTURE.md) owns source-specific block decisions; requester cannot select CIDR, duration or nftables commands.
- [Instrumentation sphere](../spheres/oorexx_instrumentation_mesh_gopher_sphere_v0.1/README.md), [Observation](../packages/oorexx_observation_v0.5/README.md), [Instrumentation Intentions](../packages/oorexx_instrumentation_intentions/README.md), [Storage instrumentation pattern](../packages/oorexx_storage_fabric_instrumentation_mesh_v0.1-dev5/README.md) define observation authority and AFTER-transition publication; Wire3D/Keynote projection cannot execute.
- [Inspector Clouseau](../packages/oorexx_inspector_clouseau/README.md) can observe ooRexx objects/snapshots and optionally cooperate with probes; inspection is not runtime-control authority.
- [ConnectSelector sphere](../spheres/connect_selector_gopher_sphere_v0.1/CONNECT_SELECTOR_SPHERE.md) forbids silent substitution/retry after unknown execution outcomes; Queue/JMS ACCEPTED/REJECTED/UNKNOWN remain distinct.

Anything referring to a new gateway class, cryptographic receipt format, XTP DIAG implementation, half-close capability or verified live carrier is **proposed**, not read/qualified.

## 2. Three directional use cases

**A — XTP named service -> any SocketSelector carrier.** Admit authenticated XTP FIRST name, class and policy; resolve *outbound logical service name* through dynamic SocketNegotiator; acquire selected socket by provider (TLS/TCP/UNIX/UDP/QUIC/NORM/X.25 only when its semantics fit). Do not hardcode destination family, address or port into service descriptors; retain selected address object/decision evidence. A datagram or circuit provider requires a typed adapter, not pretending to implement a byte stream.

**B — foreign socket -> temporary XTP peer -> named XTP service.** Admit foreign source identity and service binding; allocate a scoped, unprivileged ephemeral XTP peer identity (not a full MU/MI), short TTL, independent credential/lease, single-session permitted routes, anti-spoof and reaping. Bind lifetime to the original socket/session and fence/revoke on close, abort or lease expiration. **DISABLED until native XTP FIRST/CNTL authentication and persistent interactive FIRST-to-KEY context are qualified.** No fallback to naked unauthenticated XTP; no guest route-registration authority.

**C — X.25 CALL in/out ↔ XTP named service.** Inspect X.121 destination, CUG, CUD binary identifier, requested facilities, DTE/DCE endpoint and peer principal before accepting. Route to registered XTP named service or reverse to an authorised X.121 target; maintain per-VC state, LCN translation, Q/D/M, cause/diagnostic and interrupt/control sideband. Requires the independently qualified ooRexx X.25 stack from [X25 family spec](X25_FAMILY_SPEC.md) and the XTP session/authentication gates. Route changes cannot assert live VC migration. No unapproved reverse charges/fast select.

\`\`\`text
XTP named FIRST ------+                             +--> logical SocketSelector service
Foreign Socket -------+--> Admission --> Session ----+--> XTP named service (only after auth gate)
X.25 CALL/PLP --------+     Policy      Inspection   +--> X.25 CALL / circuit
                        Receipts + taps
                        |                |
                  QueueRexx MGMT    instrumentation.mesh/0.1
                  Firewall Controller (separate authority)
\`\`\`

## 3. Session object and transitions

Each \`GatewaySession\` owns stable session ID, ingress/egress typed endpoints, incoming principal and trust level, selected service descriptor identity, XTP route evidence, X.25 call/VC where relevant, immutable base admission generation, current allowed policy generation, class/governor ticket, timestamps (wall + monotonic), ordered event sequence, counters, outstanding writes, half-close states, independent ingress/egress outcomes, exit reason, receipts and capture entitlement.

\`CREATED -> ADMITTING -> CONNECTING -> ACTIVE -> DRAINING -> CLOSED\` with \`REFUSED\` and \`ABORTED\` terminals. \`HALF_CLOSED_INGRESS\` / \`HALF_CLOSED_EGRESS\` are **orthogonal per-direction flags** under ACTIVE/DRAINING, not indistinguishable global terminal states. Transition operations: \`admit\`, \`connect\`, \`data\`, \`shutdownSend\`, \`close\`, \`abort\`, \`quarantine\`, \`drain\`; typed idempotent replies. No data before both ingress and egress policies approve.

Each proposed authoritative state transition is atomic with (1) enforceable policy decision using active generation or pinned base generation, (2) bounded counters/ticket allocation, (3) ordered decision receipt, (4) state mutation, then (5) AFTER-transition telemetry emission; use durable local journal for completed/ambiguous outcomes. Rejected transitions leave state unchanged except a recorded refusal/terminal state as explicitly specified. Avoid blocking a state lock across network callbacks or inspector probes.

### Policy-generation handling

Admission pins immutable \`admissionPolicyGeneration\` and a signed/hash-identified policy snapshot. Per-transition enforcement uses the **pinned session policy** for ordinary data/volume/time-window rules; a reload cannot quietly reconfigure an active session. A new generation applies to **new sessions**. Explicit emergency revocation or compliance veto is the exception: versioned globally monotonic deny overlay may quarantine/abort old sessions, with a distinct new decision event recording both base and emergency policy generations. Existing session owners retain their previous class unless Operational Degradation Planner's independent live capacity/operating-state reconciliation requires authorised suspension/reduction; record that policy generation separately. Never let ambiguous reload silently permit new capabilities. RELOAD_POLICY performs validate/signature check, staged compilation, dry-run diagnostics, atomic activation and receipt.

## 4. Admission and inspection pipeline

1. **Ingress provenance:** obtain authenticated transport principal if supported; direct X.121, XTP KEY, TCP IP/port, PROXY preamble or CUG *alone* is not identity. PROXY information is trusted only from configured authenticated proxy peers, never arbitrary clients.
2. **Exact resource admission:** registered named service, X.121 prefix, CUG, CUD protocol, facilities, direction, peer class, allowed source, endpoint security and time window. Foreign sources default to lowest service class; elevation requires explicit authorisation by Service Descriptor + Operational Degradation Planner, not an arbitrary caller hint.
3. **Capacity:** live Operational Capacity Governor ticket per domain and service class, max sessions/bytes per second, packet count, call rate, read/write buffering, global cross-tenant pressure; enforce \`THROTTLE\`, \`REFUSE\`, \`DRAIN\`, and fail closed for \`SAMPLE/AGGREGATE\` until an approved real transform exists. Counters do not substitute for byte pacing.
4. **Protocol filters:** parse only after admitted carrier and bounded framing; optional protocol-inspector registry for X.25 PLP/PAD, XTP FIRST/service, HTTP, SSH metadata, proprietary protocols. Inspectors can \`ALLOW\`, \`DENY\`, \`NEED_MORE\` (bounded with deadline), \`QUARANTINE\`; cannot secretly rewrite payloads. Unknown/encrypted payload is opaque -> allow only when explicit opaque-pass policy is authorised, otherwise refuse; no covert TLS MITM.
5. **Outbound acquisition** via SocketSelector's current qualified offers, with fail-closed hard requirements, selected binding evidence and no silent transport downgrade/failover.
6. **Session data pump:** independently enforce per-direction limits, preserve message boundaries and sideband semantics, propagate backpressure, cancel and clean up after errors. Filters cannot be supplied as executable code by untrusted callers; plugin signing/whitelisting required.

## 5. Explicit refusal and diagnostics

Define \`GatewayDecisionReceipt\`: session id; transition; decision ALLOW/DENY/QUARANTINE/UNKNOWN; coded reason; caller trust/evidence reference; service descriptor; fixed policy generation(s); selected transport/role; timestamp/event sequence; correlation; origin; acknowledgement scope. Originating protocol gets an appropriate response:

| Ingress | Desired refusal |
| --- | --- |
| XTP | dev29 **implements** packet-type 8 DIAG: CODE=1 CONTEXT_REFUSED and VALUE=1 SERVICE_NOT_ADMITTED, 2 OVERSIZE, 3 MALFORMED, with source/return-bit binding but **without cryptographic FIRST/CNTL authentication**. Propose new versioned VALUE allocations for gateway policy, identity, facility, quota, loop and inspection refusal only through XTP owner; existing peer support and privacy must be negotiated. Do not mislabel source binding as secure authentication. |
| X.25 | Correct CLEAR REQUEST with cause/diagnostic for reject of an in-flight call, otherwise RESET or local circuit-state failure as appropriate; do not invent public X.25 cause codes for local gateway errors. |
| TCP/TLS/UNIX/other sockets | protocol-specific refusal if available, then clean close or abort; local receipt always gives explicit reason even if remote stack cannot. |
| QUIC/HTTP/RPC | native error/close code or typed application result only where protocol mapping is qualified. |

No unconditional “refusal never looks like timeout” promise is achievable on an unauthenticated peer that deliberately suppresses packets: guarantee **an explicit local decision receipt** and a remote refusal wherever that transport supports reliable response. Distinguish peer-did-not-respond from gateway-denied.

## 6. Logging, tamper evidence and capture privacy

**Three non-interchangeable streams with separate access and retention:**
1. **Decision journal:** append-only \`gateway.decision/0.1\` records (who, service, action, policy generation, coded reason, outcome, correlation, monotonic event id, UTC wall timestamp), chain each record hash to the prior committed digest. Use estate Crypto through explicit injected signing/MAC key authority; verify chaining, key rotation and authenticated anchors. A hash chain alone is tamper-*evident relative to independently retained trusted anchors*, not tamper-proof.
2. **Traffic metadata:** byte/packet counters in/out, sizes, durations, queue pressure, interarrival distributions, half-close/reset outcomes, route changes, no payload, credentials or unrestricted X.121 CUD. Lower privilege than content-capture access, bounded retention.
3. **Content capture:** **off by default**, case/ticket + security/legal authority, narrowly selected sessions, bounded byte/time quotas, encryption at rest, ring buffer, explicit expiry, two-party access as local policy demands, audit read/delete and privacy redaction. Never make content capture a prerequisite for filtering all connections.

Receipts are authoritative only for gateway decisions; downstream delivery receipts retain their own authorities. Persist journal before claiming an action is durably accepted; asynchronous telemetry follows successful authoritative state transition. If required audit storage fails, admission fails closed; active sessions follow an explicit fail-safe termination/quarantine policy, not silent log loss.

## 7. Inspection, management and separation of authority

Read-only bounded tap points: pre-admit, post-admit, pre/post outbound acquisition, post-content-decision, write/flush, read, pressure, half-close, reset, terminal. Event fields include service class, location-free semantic reference, correlation, state, coded refusal, payload-length metadata and policy generation; no payload or secret object graph by default.

[Inspector Clouseau](../packages/oorexx_inspector_clouseau/README.md) may inspect **the gateway's own Session objects** via bounded snapshot/redaction; temporary probes only with explicit inspector administrator authority, never auto-installed in transport hot path. [Instrumentation Mesh](../spheres/oorexx_instrumentation_mesh_gopher_sphere_v0.1/README.md) consumes post-transition metric/events and versioned session progress; [Instrumentation Intentions](../packages/oorexx_instrumentation_intentions/README.md) remain read-only; [Observation v0.5](../packages/oorexx_observation_v0.5/README.md) provides neutral replay/checkpoints where appropriate. Wire3D/Keynote NOC shows health/history only and cannot issue control.

**QueueRexx MANAGEMENT** provides versioned, authenticated intentions with distinct read/control ACLs:
- \`LIST_SESSIONS\`: bounded, paginated, redacted sessions with stable ID, state, class and age.
- \`EXPLAIN_DECISION(sessionId,eventId)\`: exact policy-generation-specific explain receipt and route/capacity evidence.
- \`DRAIN(session|service|gateway)\`: disallow new calls, flush already accepted bounded writes, deadline/abort on expiry.
- \`KILL(sessionId,reason)\`: authorised abort with native family-specific signal where applicable; no pretence of downstream rollback.
- \`QUARANTINE(session|principal)\`: stop data/calls and preserve evidence; independent expiry/review.
- \`RELOAD_POLICY(revisionRef)\`: validated/authorised generation activation; existing sessions pinned except explicit emergency veto.

Every mutation requires authentication, role, exact scope, reason, audit and replay-resistant request ID; no LLM/NOC recognition grants execution privilege. Do not route control through observation-only specialists.

[Firewall Controller](../packages/oorexx_firewall_controller/docs/ARCHITECTURE.md) receives hostile **authenticated peer** reports via its existing \`firewall.control/0.1\` contract. Gateway sends source+reason/evidence only; Controller chooses prefixes/durations/protected-source veto and mutates nftables. Non-IP X.121 peers cannot be turned into arbitrary CIDR blocks; quarantine the gateway circuit/principal instead.

### Instrumentation Mesh publication discipline

The verified [Instrumentation authority article](../spheres/oorexx_instrumentation_mesh_gopher_sphere_v0.1/packs/instrumentation-mesh/articles/instrumentation-mesh.authority.json) and [contract article](../spheres/oorexx_instrumentation_mesh_gopher_sphere_v0.1/packs/instrumentation-mesh/articles/instrumentation-mesh.contract.json) impose additional conditions: gateway semantic identity must be independent of carrier IP, route and 3D position; source health and evidence freshness remain separate (HEALTHY+STALE is valid); missing observations are not zeros; events are replay-safe with monotonic publication fencing and producer-declared correlation/causation, never guessed from proximity. QueueRexx control and observation transport remain independent. Rich forensic decision/capture journals do **not** get copied into bounded Instrumentation samples, and raw private RPC correlation tokens, credentials and arbitrary X.121 customer identifiers stay out of metric dimensions. See also the [Keynote NOC article](../spheres/oorexx_instrumentation_mesh_gopher_sphere_v0.1/packs/instrumentation-mesh/articles/instrumentation-mesh.keynote-noc.json) and [continuation article](../spheres/oorexx_instrumentation_mesh_gopher_sphere_v0.1/packs/instrumentation-mesh/articles/instrumentation-mesh.continuation.json): the NOC renders observations and never creates incidents or service authority.

## 8. Half-close and upstream change request

**Request to SocketProvider owner, not local patch:** \`SocketCapabilities~halfCloseSend\` (optional false by default) and \`ProviderSocketConnection~shutdownSend()\` with idempotent outcomes and explicit compatibility/NOT_SUPPORTED. Preserve \`waitDrained()\`, queued bytes and full \`close()\`. Typed state \`sendOpen/recvOpen\` and per-family error reason should be exposed. XTP dev29 has segmented message streams but still needs persistent interactive stream context and (if semantics permit) end-of-send signalling. X.25 CLEAR does not generally map to a mere TCP FIN: use per-direction state and explicit family-specific translation. Until those upstream capabilities are qualified, refuse half-close-requiring protocols rather than quietly closing both sides.

## 9. Failure and edge-condition table

| Failure / anomaly | Required behaviour |
| --- | --- |
| Half-open, SYN flood, slow-drip | admission/deadline on headers, bytes/min rates, per-principal quotas, bounded state, deterministic refusal/cancel |
| Peer never reads | high-watermark pauses upstream reader and stops X.25 receive credit / RNR where appropriate; deadline then clear/abort; never unbounded buffers |
| X.25 default 128 octets vs XTP underlay MTU | XTP dev29 already segments unicast messages (FIRST+DATA); negotiate per-VC packet size, retain X.25 PDU boundaries, cap end-to-end reassembly and qualify persistent gateway session mapping; never truncate or mislabel original data |
| Interrupt / urgent unmatched | typed sideband if qualified, otherwise explicit refuse/drop-with-fatal-policy (never silently inline with data) |
| X.25 reset vs TCP close | family-aware reset event; for stream-only target abort with typed \`RESET_UNREPRESENTABLE\`; no invented replay |
| Gateway crashes/failover mid-session | prior owner fenced; new gateway has distinct incarnation; mark in-flight outcome UNKNOWN; reopen only via newly admitted call/session and dedup when application permits |
| Policy changes mid-session | preserve admission policy generation; emergency revocation separately signed and logged; capacity governor re-evaluates under independent owner |
| Gateway loop or ping-pong | typed hop budget + immutable gateway-instance visited tokens, TTL and maximum forwarded bytes; reject loops before forwarding |
| Amplification/answer storms | per-direction byte amplification cap, connection count/rate, reject recursion, refuse misconfigured bidirectional mapping |
| Clock skew | local monotonic ordering with event sequence; wall-clock UTC and clock-confidence/skew metadata for cross-node correlation |
| Encrypted opaque data | do not impersonate endpoints; require explicit permitted opaque pass or deny |
| Outbound timeout after possible request dispatch | \`UNKNOWN\` instead of automatic retry; application-level idempotency needed |
| Repeated diagnostics/costly refusal | rate-limit malformed sources and decisions; never amplify a one-byte request into unlimited DIAG traffic |

## 10. Proven operational class and delivery honesty

The [Operational Degradation Planner dev5](../packages/oorexx_operational_degradation_planner_v0.1-dev5/README.md) supplies registered class and capacity-domain tickets. Foreign callers default to low class until a trusted rule elevates. XTP service descriptor supplies the service's registered class, not a requester. Preserve transport priority and service class separately from route metrics.

**Delivery:** X.25 D-bit delivery-confirmation semantics are not equivalent to committed application work; TCP ACK acknowledges stream bytes at transport scope only; XTP transport acknowledgement is not Queue Fabric durable acceptance. [ConnectSelector](../spheres/connect_selector_gopher_sphere_v0.1/CONNECT_SELECTOR_SPHERE.md) owns service-invocation admission and its JMS \`ACCEPTED/REJECTED/UNKNOWN\` disposition rule. Gateway may report at most the guarantee established by the weakest stage; on ambiguous transport loss report UNKNOWN and do not automatically replay unqualified side effects.

## 11. Survey — what to take and what to avoid

**Useful designs:** X.25 call-level admission/CUG/causes/diagnostics -> per-session admitted state and explicit refusal; SS7 signalling vs bearer separation -> control-plane authority distinct from data plane (analogy, not same wire); HAProxy PROXY protocol -> preserve provenance *only from trusted peers*, rule checkpoints -> staged admission; Envoy filter chains and structured access logs -> filter at distinct stages with typed receipts; nftables expiring sets -> finite-lifetime hostile-source control owned by Firewall Controller; Zeek -> structured protocol metadata distinct from opt-in packet/content capture. These are design comparisons, not claims of API compatibility.

**Kludges to reject:** NAT identity destruction followed by unauthenticated X-Forwarded-For; FTP/SIP helpers rewriting payloads without typed protocol authority; invisible stateful-firewall idle timeout; mishandled TCP half-close; logging added later in incompatible formats; TLS interception through forged endpoint identity; IP address or port number as identity. Report idle expiry explicitly in local receipts and use authenticated keepalive only within protocol authority.

## 12. Acceptance gates / dependency handover

- G0 specification approved: ownership, negative capabilities, protocol/refusal mapping and policy controls.
- G1 SocketProvider owner supplies half-close capability semantics; XTP owner supplies authenticated FIRST+CNTL, persistent interactive KEY context and gateway-specific DIAG VALUE extensions. Segmented unicast messages and base DIAG exist in dev29; this document cannot assert security or gateway qualification.
- G2 user-space ooRexx X.25 PLP/LAPB with simulated and real XOT test peers qualified; exact revision and ABI receipts.
- G3 bidirectional gateway loopback tests with deterministic sessions, policy-generation pinning, filters, journal power-loss recovery, audit failure, inspector redaction, telemetry ordering and two-side backpressure.
- G4 independent live native legacy/XOT and authenticated XTP peer interop with route changes, MI/MU placement and unauthorised access tests.
- G5 production security review, credential commissioning, opt-in capture policy and disaster-recovery evidence. No claim of live ability before all mandatory gates.

All generic gateway source should be ooRexx first; any native driver/helper requires explicit audited boundary, threading/ownership/ABI/version contract. No Python or arbitrary JSON representation is introduced for object state.
