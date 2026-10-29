# ConnectSelector — engineering sphere 0.1

Owner: ConnectSelector. Interface: `oorexx.connect_selector/0.1`. Source checkpoint: dev6 (2026-10-23).
Complete dev6 ZIP SHA-256: `6ea919552264a8d50db77b2a513990226a869ebbf3ed930e98c055c8175184ae`.

## Authority and boundaries
ConnectSelector owns **which qualified invocation path** to use and **whether that route is permitted**. Providers: local DirectCall; RPC (JSON-RPC, SOAP, gRPC bindings); durable QueueFabric; runtime-continuity RTO2. JMS is a directionally controlled QueueFabric bridge rather than an interchangeable protocol.

Serialisation Selector owns representation and schema (including protobuf); RPC Service Core owns explicit registration, frozen published service/method routing and callback admission; protocol bindings own SOAP/JSON-RPC/gRPC envelopes, errors and streaming. SocketSelector owns carrier decision, not invocation semantics or RTO2 runtime authority. Dynamic intention discovery must not become a frozen catalogue in ConnectSelector.

## Invariants
1. Explicit provider choice never bypasses exact operation/mode/destination policy.
2. `REQUEST/CONTINUITY` requires an authenticated RTO2 port. Queue acceptance is not service completion; a JSON-RPC notification is not delivery confirmation; ordinary RPC is not durable.
3. No silent provider substitution, retry or failover after dispatch where outcome may be uncertain.
4. JMS→QueueFabric: durable insertion BEFORE JMS acknowledgement. QueueFabric→JMS: broker acceptance BEFORE queue acknowledgement. `ConnectJmsSendReceipt` permits `ACCEPTED`, `REJECTED`, `UNKNOWN`; ambiguous broker send (and legacy false) MUST NOT immediately nack. Exact-once is not claimed; deduplication is required.
5. RTO2 controls epoch, fencing, promotion, checkpoint/replay. Dev13 real Grid estate membership and incarnation checks are qualified; actual runtime invocation remains simulated.
6. Optional Instrumentation Mesh observer must never alter invocation or reveal operation, destination, payload, credentials or secret exception details.

## Evidence
Local r13196 ooRexx regression against pinned: JSON-RPC Fabric dev3; RPC Service Core dev1; SOAP RPC Binding dev2 and native libsoapxml; QueueFabric 0.9-dev6; Alchemy Objects 0.8.2; Crypto 0.8.3; RTO2 Grid dev13; Instrumentation Mesh dev7: PASS. Journal persistence/restart actually tested; SOAP/JSON same-object dispatch actually tested. JMS broker and live RTO2 runtime/failover NOT tested. Strict standards: 17 files, 0 errors, 0 warnings.

## Repository synchronization
`packages/oorexx_connect_selector_v0.1-dev6/patches/` contains the dev5→dev6 JMS change and test delta. That delta is not the full 24-file source release; the complete ZIP remains separately identified by checksum until imported and verified byte-for-byte. Do not claim all dev6 source is on GitHub based on this patch alone.

## Missing work (ordered)
- Import full 24-file dev6 source tree and re-run exact qualifying tests in repo.
- Implement real JMS broker adapter with explicit dispositions, redelivery/dead-letter and transactional tests; no exactly-once overclaim.
- Bind authenticated RTO2 runtime, socket carrier and fencing evidence; run live promotion/failover campaign.
- Qualify RPC binding selector on authenticated networks, callback/stream cancellation and adverse effects.
- Keep QueueFabric optional and avoid duplicating RPC Service Core or Serialisation Selector.

## ooRexx ADDRESS environments (RFE #882; 2026-10-27)

This is an **optional entry adapter** to the same ConnectSelector policy and invocation contract, **not a new provider** and not a replacement for the existing direct/RPC/QueueFabric/RTO2 stack. ooRexx `.CommandHandler~register` permits pure Rexx package-prolog registration and `::REQUIRES` usage by independently written clients. Registrations are per interpreter instance; shared objects between processes require an explicit service transport.

Provenance and eligibility: upstream announces Rexx handlers in r13288 (portable builds r13289+), `StackCommandEnvironment` in r13297 and native API interfaceVersion 102. The source baseline here remains dev6 qualified on older r13196; do not claim the new API exists in the dev6 qualification runtime.

Committed work: `examples/address_environment/AlchemyAddressProbe.cls` is a fail-closed handler, and `examples/address_environment/probe.rex` checks RC 0/13/64 through an independently required package. `qualification/ADDRESS_ENVIRONMENT_RFE882_20261027.md` documents execution instructions, version gates, authority design and the still-open qualification matrix. This **has not been executed** against the new interpreter.

Required next: workstation evidence on a compatible r13289+ runtime; verify package prolog and native stacking/forwarding, exact dependency resolution, caller stream/variable/condition authority, concurrency, refusal and transport error mapping. Production `ADDRESS ALCHEMY_CONNECT` registration is only proposed. Do not reinterpret Queue Fabric ACCEPTED as an operation success or erase an uncertain side effect.

## 2026-10-29 — dev8 reconciliation and executable local ADDRESS adapter

- **Newer Library checkpoint:** `oorexx_connect_selector_v0.1-dev8.zip`, SHA-256 `1cc89a61f2b8f4f4e4ee0b32480ce1b149658bb89a67522d466db8dfb4a296fc`. Local archive inspection: all 25 checksum-manifest entries match. It contains 26 files total (including its checksum manifest).
- **GitHub delta:** the versioned path `packages/oorexx_connect_selector_v0.1-dev8` currently has the authenticated-route-policy class and its negative test plus a README, **not** the complete 26-file Library tree. A full-source admission remains outstanding. Do not confuse partial GitHub presence with the qualified archive.
- **New actual ConnectSelector usage:** `examples/address_environment/AlchemyConnectAddressLocal.cls` is an ooRexx RFE #882 `CommandHandler` that accepts only `CALL <local-destination> <operation>`, converts the request to an explicit `ConnectIntent(...,REQUEST,IMMEDIATE,DIRECT,...)`, and invokes the existing selector/policy. Constructor enforces a trusted exact local destination (default `LOCAL`) and refuses a selector with no policy. Its return codes are 0 only for a completed result, 13 for rejected execution, 64 for invalid syntax, 70 for exceptions, 75 for accepted-but-not-completed.
- **Negative/integration source tests:** `examples/address_environment/local_connector.rex` uses a real `ConnectSelector` and `ConnectCallAdapter` and verifies allowed execution, policy denial, malformed commands, a deliberately registered `DIRECT` provider for an unauthorized REMOTE destination, and incomplete-acceptance semantics. This is *not* a live HTTPS/XTP/LDAP test; the adapter is explicitly local-only and does not bypass remote authentication.
- **Independent result:** CODEX-PC REQ-00000859 reported **BLOCKED**, installed r13196, below the RFE #882 interpreter requirement (r13289+). The local ADDRESS code and tests are **COMMITTED BUT NOT RUNTIME QUALIFIED**. Do not claim the tests PASS until an appropriate runtime executes them. Existing dev8 route-authentication tests in the Library archive are not evidence of live authenticated channels.
- **Run under a verified compatible ooRexx interpreter** after extracting exactly the dev8 ZIP, with the working directory set to this example directory, and `REXX_PATH` containing that exact extracted `src` directory plus this example directory: `rexx local_connector.rex`. Record revision, environment path, stdout/stderr, return code, source/archive digest. No autobuilder available.

### Critical-path integration seams

This adapter does not own Rasen Falcon website release, SMTP/IMAP operations, native HTTPS/private CA, LDAP validation or MU↔MI XTP transport. For remote provider admission, `ConnectAuthenticatedRoutePolicy~permitted` requires a platform-owned `authorizeRoute(intent,provider)`; a caller-populated LDAP or TLS flag is not proof. Current cross-component requests for concrete contracts are: LDAP identity REQ-00001641, native HTTPS REQ-00001643, XTP named service REQ-00001645. No remote application route may be called deployment-ready until actual authenticated peer identity, authorization, live reachability and service receipt evidence are available.

Do not ask CODEX-PC or CLAUDE-PC to write code or start unapproved host probes. The ConnectSelector code remains an admission/selection boundary, never a second authentication system or alternative transport.
