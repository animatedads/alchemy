# Outstanding Architecture Decisions — X.25 / XTP Gateway v0.1

**Architecture:** Tom Dyer. **Coding:** ChatGPT (future). **Document/update written by:** ChatGPT (GPT-6), 24 October 2026.  
**Status:** design-only decision register. This is deliberately **not** a list of open decisions about settled RexxOS architecture. See [X25_FAMILY_SPEC](X25_FAMILY_SPEC.md), [XTP_GATEWAY_SPEC](XTP_GATEWAY_SPEC.md), [SEMANTIC_MAPPING](SEMANTIC_MAPPING.md).

## Decisions requiring Tom's authority

| Decision | Actual choice | Default recommendation / consequence |
| --- | --- | --- |
| **D-X25-01 — First real legacy interop specimen** | Which real device/line/router/telecom switch and interface is the first acceptance peer: sync HDLC serial (card, signalling/clock), LAN LLC2 (ISO 8881) or independently known XOT router? | **Start software XOT test/trace harness**, then a real XOT peer before committing to expensive serial hardware. Keep all three carrier specifications; select physical rig when its make/model, pinout/driver and DTE/DCE role are available. |
| **D-X25-02 — Baseline X.25/ISO edition and PTT/vendor facilities** | Which exact X.25 edition, modulo profile, optional facilities (CUG / reverse-charge / fast-select), national X.121 plan and X.29 PAD variant are mandatory on first deployment? | Initial strict SVC/modulo-8 with classic 128-byte packet / window-2 defaults **only where that peer profile establishes them**. Gate extras individually, do not guess operator settings. Preserve unknown options but deny unsupported requests. |
| **D-X25-03 — XTP encapsulation granularity** | Is first private XTP carriage **X.25 packet PDUs**, a higher-level \`X25CircuitEvent\` stream, or transparent LAPB frame tunnelling? | **Packet PDUs + explicit typed circuit/control envelope**. This allows per-endpoint LCN translation and independent physical links, preserves PLP semantics and avoids physical line timing claims. Raw LAPB tunnelling should be a separate transparent L2 service. This needs an XTP owner review. |
| **D-GW-01 — Gateway policy source and emergency override authority** | Which governance/identity component signs the versioned gateway policy snapshots and who can issue an active-session emergency veto? | Reuse existing estate security/identity authorities with signed immutable revision IDs and separate security-operator role for emergency deny; do not create a second trust root. Provider-specific source to be named during integration. |
| **D-GW-02 — Which ingress/application protocol may be inspected** | Are initial traffic flows opaque byte-forwarding only or is there an approved first protocol-aware inspector (e.g. X.25 PAD or a known proprietary host protocol)? | Start with structural X.25/XTP inspections plus explicit opaque-pass allowlists. No payload mutation and no decrypting MITM. Introduce content inspectors only with reference traces, owner, retention/access policy and test suite. |
| **D-GW-03 — Signed receipt durability and content-capture retention** | Which existing approved durable journal/key authority and organisational capture policy governs signing, anchor export, retention duration, access and deletion? | Use the existing Crypto + audited storage/permission services, decision journal on by default, metadata redacted and bounded, full content off by default; no arbitrary retention invented here. |

These are genuine interoperability, ownership or governance choices; default suggestions allow the software-lab work to proceed without waiting for hardware procurement.

## Already resolved, not being re-opened

- **User-space ooRexx is primary for LAPB and PLP.** [X.25 family spec](X25_FAMILY_SPEC.md) treats Linux \`AF_X25\` as optional compatibility only, acknowledging operational concerns. No kernel dependency in critical path.
- **XTP route ordering and carrier naming:** L2 MU↔MI, L3 native-IP underlay and L4 UDP underlay remain XTP's route authority, **not** X.25-native ISO layer definitions. [XTP named services](../packages/oorexx_xtp_v0.1-dev26/docs/NAMED_SERVICES.md) owns service→logical peer→route.
- **XTP selectable striping** remains the established design requirement; implementing it is another owner's qualified upstream work, not a new gateway design choice. See [dev26 gap ledger](../packages/oorexx_xtp_v0.1-dev26/docs/XTP_SPEC_GAPS_DEV26.md).
- **LDAP route distribution with manual override files**, **minimum two replicas**, and **partial materialisation** are settled estate directions, not questions for this project.
- **ConnectSelector** owns invocation policy, no silent substitution on uncertain outcomes, and Queue/JMS disposition semantics. [Sphere](../spheres/connect_selector_gopher_sphere_v0.1/CONNECT_SELECTOR_SPHERE.md).
- **SocketSelector** owns socket acquisition; only its owner may add half-close contract, and XTP owner must close authentication/persistent KEY/DIAG gaps before untrusted foreign ingress can run.
- **Firewall Controller** owns CIDR and block duration. [Authority](../packages/oorexx_firewall_controller/docs/ARCHITECTURE.md).
- **Inspection and telemetry do not mutate gateway state**. [Instrumentation Mesh](../spheres/oorexx_instrumentation_mesh_gopher_sphere_v0.1/README.md), [Inspector Clouseau](../packages/oorexx_inspector_clouseau/README.md).
- The architecture is **specified**, not implemented or security-qualified; see [NOT_CLAIMED](NOT_CLAIMED.md).

## Delegation and near-term next actions (not decisions)

1. ChatGPT: author standalone ooRexx PLP + LAPB interface, typed VC state machine and deterministic link tests; use no Python implementation as a shortcut.
2. XTP owner: specify persistent FIRST→KEY context, unicast segmentation, authenticated FIRST/CNTL and explicit DIAG including negative capability evidence. [Dev26 gaps](../packages/oorexx_xtp_v0.1-dev26/docs/XTP_SPEC_GAPS_DEV26.md).
3. SocketProvider owner: specify \`halfCloseSend\` capability and \`shutdownSend()\` with backward compatibility and tests. [Core source](../packages/oorexx_socket_provider/src/SocketProvider.cls).
4. Gateway owner: author Session, policy-generation pinning, enforcement, receipt schema and independent observation adapters; require all relevant gates before live dispatch.
5. Qualifier: provide exact-source/ABI/interpreter/hardware trace receipts. A missing peer or missing permission means NOT_RUN, not PASS.

None of the above constitutes an instruction to change another workstream's source without its owner.
