# Current provenance / integration notes

Source materials inspected for this first release:

- User-provided Open Object Rexx 5.3.0 r13196 internal debug x86_64 Debian package, executed locally without system-wide installation.
- Library `oorexx_intention_service_v0.1-dev11.zip`: existing provider-neutral recognition, NLP variants, buckets, plan assessment, READY-gated dispatch; this module's optional adapter was runtime-tested against this source.
- Library `oorexx_network_transport_intentions_v0.1-dev2.zip`: read-only Socket Provider/XTP route and network path observations, COTS interface witnesses. Do not duplicate its path selector.
- Library `rexxos_rto2_grid_v0.1-dev11.zip`: dev11 package profile (8 MUs, 16 MIs, XTP dev18, Socket Provider dev14, Memory Fabric dev7, Storage Fabric dev21, Instrumentation Mesh dev3), but these references are not dependency pins.
- Library `oorexx_xtp_v0.1-dev18.zip`: current read-only source reference for semantic XTP, not executed or path-tested here.
- Library Project Alchemy/NotNotes architecture and `General_ooRexx_Deployment_Component_v0.3.md`: authority and dependency-lock split.

Do not treat this release's sample catalog as authoritative for versions newer than the above observations. NotNotes persisted Project→Stack→Component→Paper graph should be the preferred source of descriptive component capabilities, while SSC decides versions/lineage and Deployment decides target loadability. The dev1 JSON catalog is an explicit, replaceable test provider until live catalog import is implemented.

- Library `oorexx_connect_selector_v0.1-dev1.zip` read 2026-10-08: exact contract `oorexx.connect_selector/0.1`; observed and tested against its `ConnectSelector.cls` with explicitly injected `supports` adapters. `DIRECT`, `RPC`, `QUEUE` correspond to request/notify, request/notify, and enqueue respectively. JMS bridge is separate and at-least-once; never infer transactional exactly-once.
- The optional ArchitectureConnectSelectorAdapter calls real `ConnectSelector~explain`, not execute. Integration tests use registered mock capability adapters; no live network, JMS broker or durable Queue manager was qualification-tested.

- 2026-10-09 Library `oorexx_connect_selector_v0.1-dev2.zip` reviewed and tested using its policy-scoped, destination-bound `explain()` contract. Without explicit route grants, the registered route is denied. Its optional JMS routes retain origin message IDs but are not broker-certified. Dev1's permissive test remains separate to prevent weakening dev2 policy.
- 2026-10-09 Library `project_alchemy_notnotes_corpus_v0.3.zip` located as a newer documentation graph; this release does not treat a NotNotes corpus as runtime resolution authority.
- Relationship Case v0.2 and service v0.1 descriptions in the Library distinguish typed case references and durable coordination from underlying CRM, legal, account, reputation and document truth. The relationship graph enforces that separation architecturally; no actual service calls were exercised.

- 2026-10-11 Library `oorexx_connect_selector_v0.1-dev5.zip` inspected and
  strict default-deny `explain()` regression qualified. Dev5 adds optional
  `RTO2` continuity and local callback bindings, plus read-only instrumentation.
  The Architecture adapter still recognizes the established direct/RPC/queue
  families. It must not falsely translate continuity into ordinary RPC or JMS.
- NotNotes corpus v0.5 working is present in Library; its publication is not
  dependency or deployment authority. Architectural records may ultimately
  project into the NotNotes graph after a contract-specific adapter is approved.
- Architecture Promotion explicitly consumes typed scenario comparison JSON
  and depends on host-injected approval verification. No authorisation or
  cryptographic signature verifier has been implemented by this module.
- 2026-10-11 inspected `project_alchemy_notnotes_corpus_v0.5_working(1).zip`:
  current working architecture documentation graph (34 Stack, 170 Component,
  182 exact Package and 66 curated Interaction documents). It includes an
  explicit Connection and Service Invocation stack covering ConnectSelector,
  Serialization Selector, RPC Service Core, SOAP, JSON-RPC and gRPC as distinct
  responsibilities. This is a WORKING HEAD, not an SSC revision lock. Its
  README records a NotNotes dev17 persistence reload incompatibility, so the
  planner must not assume this graph can yet be its live write authority.
