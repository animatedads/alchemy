# Changelog

## 0.1-dev7-fb1

- Delivery recovery: recovered the already-written FederationBank compatibility cut from project history and verified its original manifest before modification.
- Pre-delivery live-edge repair: `JMSBSFProvider~send` now exposes `config`, which it reads after `producer~send` to select the completion result. This prevents a successful broker send being followed by a local uninitialised object-variable failure.
- Pre-delivery BSF dispatch repair: Java `Connection.start()` is invoked with `~bsf.invoke("start")` at connect/probe/flow-probe sites so ooRexx does not intercept the call as its own `Object~start` asynchronous-message method.
- Pre-delivery BSF dispatch repair: Java `MessageProducer.send(Message)` is invoked with `~bsf.invoke("send", javaMessage)` so ooRexx does not intercept it as `Object~send`.
- Added deterministic fake-BSF/JMS edge coverage for MAP/TEXT creation, application properties, reserved bridge metadata, correlation precedence, JMSType and inbound MAP decoding.
- Re-qualified with BSF4ooRexx v850 on ooRexx 5.3.0 r13196 and an ActiveMQ JMS provider in the FederationBank test environment.
- FederationBank compatibility cut based on dev6.
- Added outbound JMS `MapMessage` creation for Java-free `JMSBridgeMessage` MAP bodies.
- Added inbound JMS `MapMessage` decoding into a persistable ooRexx Directory.
- Forwarded application JMS properties on outbound messages while reserving `AlchemyTransferId` and `AlchemyQueue` for the bridge.
- Forwarded `JMSCorrelationID` from the bridge envelope when the Queue Fabric package does not already carry one, and forwarded optional `JMSType`.
- Kept the existing TEXT path, Queue Fabric persistence identity, settlement semantics, session modes, credential handling and operational-readiness diagnostics unchanged.
- This is a narrow FederationBank compatibility candidate; live BSF/JMS broker qualification is still a separate deployment test.

## 0.1-dev6

- Incorporated the external dev5 matrix result: deterministic suite and BSF/JMS classpath PASS; TLS/authentication, JNDI, data connection, non-transacted session creation, destination lookup and consumer construction all PASS; all four AUTO/CLIENT_ACK x ADMINISTERED/GUARANTEED candidates fail only at `Connection.start()`; classification is `BROKER_FLOW_ACTIVATION_BLOCKED`; zero messages consumed.
- Added `JMSBridgeOperationalDisposition` so diagnostic success is no longer confused with deployment readiness.
- Added `JMSBridgeFlowCapabilityReport~operationalDisposition` and `~operatorAction`; the current all-start-blocked matrix maps to `EXTERNAL_BLOCKED` with `BROKER_OR_CLIENT_PROFILE_FLOW_ACTIVATION_REVIEW_REQUIRED`.
- Added `JMSQueueBridgeService~assessInboundReadiness(...)`, a stopped-state, no-receive deployment gate that returns `JMS_INBOUND_READY`, `JMS_INBOUND_EXTERNAL_BLOCKER`, or an unresolved/no-evidence result without mutating broker policy or Queue Fabric.
- Added deterministic operational-readiness coverage and expanded the capability-model assertions.
- Extended the live capability example to print deployment disposition/action and added optional `JMS_FLOW_REQUIRE_READY=1` CI gating.
- No JMS receive path, Queue Fabric persistence semantics, credential semantics, durable `alchemy.jms.message/0.1` representation, or Java/BSF package boundary changed.

## 0.1-dev5

- Incorporated the external dev4 result: the deterministic suite and BSF/JMS classpath pass, TLS/JNDI/data connection/session/destination/consumer creation pass, and the no-receive flow probe fails precisely at `FLOW_CONNECTION_START`; zero messages were consumed.
- Added Java-neutral `JMSBridgeFlowProbeEvidence` and `JMSBridgeFlowCapabilityReport` objects so endpoint capability evidence is explicit rather than embedded in console text.
- Added `JMSBridgeConfig~copyWithSessionPolicy(...)` so diagnostics can derive policy variants without mutating the production configuration object.
- Added `JMSBSFProvider~probeInboundCapabilities(...)`, a bounded no-receive matrix over AUTO_ACKNOWLEDGE / CLIENT_ACKNOWLEDGE and ADMINISTERED / GUARANTEED transport. DIRECT is optional as a diagnostic control; TRANSACTED is intentionally excluded from the monitoring matrix.
- Added deterministic classification of the all-`FLOW_CONNECTION_START` case as `BROKER_FLOW_ACTIVATION_BLOCKED` and preference ordering for usable non-transacted paths, favoring CLIENT_ACKNOWLEDGE + GUARANTEED when available.
- Added Solace `getDirectTransport()` before/after evidence so the effective administered/overridden transport policy is observable.
- Added `faa_swim_capability_probe.rex` and the explicitly gated `live-capability-probe` test mode; it activates temporary consumers but never calls `receive()`.
- Removed a duplicate `connectionFactory` assignment in bridge configuration initialization.
- No Queue Fabric, persistent `alchemy.jms.message/0.1`, or message-settlement semantics changed.

## 0.1-dev4

- Corrected the live-session architecture after FAA/SCDS evidence showed that the current monitoring profile does not support transacted JMS sessions.
- Made `AUTO_ACKNOWLEDGE` the default session policy and create it with `connection~createSession(.false, 1)`. No JMS commit/rollback is issued in that mode.
- Added optional non-transacted `CLIENT_ACKNOWLEDGE`; successful local Queue Fabric acceptance is followed by `Message~acknowledge()`, while local rejection requests `Session~recover()`.
- Retained optional `TRANSACTED` mode for brokers/client profiles that actually support local JMS transactions.
- Replaced the Java-neutral core's transaction assumption with accept/reject and complete/abort settlement semantics while accepting dev1-dev3 provider aliases for compatibility.
- Added explicit `LOCAL_ACCEPT_FAILED_AFTER_AUTO_ACK` reporting so the AUTO_ACK monitoring loss window cannot be mistaken for at-least-once delivery.
- Added `ADMINISTERED`, `DIRECT`, and `GUARANTEED` Solace transport policy selection. Vendor-specific `setDirectTransport(...)` remains confined to the BSF adapter.
- Added stage-specific live connection diagnostics and `probeInboundFlow()`, which exercises session creation, destination lookup, consumer creation and `Connection.start()` without receiving a message.
- Incorporated live evidence: authentication/TLS/JNDI/data connection succeed; AUTO_ACK session and consumer construction succeed; flow activation currently fails at `Connection.start()`; zero messages were consumed.
- Added deterministic AUTO_ACK risk, CLIENT_ACK idempotency/recovery, session-policy, and provider flow-probe tests.
- Persistent payload identity remains `alchemy.jms.message/0.1`; Queue Fabric remains free of Java/JMS/BSF dependencies.

## 0.1-dev3

- Rebased qualification on the current roll-up: Queue Fabric v0.9-dev4,
  Alchemy Objects v0.8, Runtime Registry v0.14, Secret Broker v0.2 and shared
  ooRexx Crypto v0.1.
- Corrected the runtime build identity in `JMSQueueBridge.cls` from the stale
  dev1 value to `0.1-dev3`; persistent message/API identities remain 0.1.
- Upgraded `JMSQueueBridgeService` metadata for Alchemy Objects v0.8 and added
  explicit Queue Fabric/Alchemy requirements plus current house-compliance
  declaration.
- Corrected method-policy semantics: ordinary collaborator calls are no longer
  misclassified as Alchemy authority `DELEGATE` effects. The service passes
  v0.8 STANDARD adoption with zero warnings.
- Added `JMSBridgeCredentialLease` and an `acquire()` contract for environment
  credentials so materialized username/password values have a bounded lifetime.
- Added optional `JMSQueueBridgeSecrets.cls`, integrating Secret Broker v0.2 by
  logical reference and retiring underlying broker leases immediately after a
  short-lived bridge credential pair is produced.
- Added configurable `initialContextFactory`; Solace remains the SCDS default.
- Updated the BSF provider to authenticate both JNDI and the JMS data connection
  using the standard `createConnection(username,password)` path when credentials
  are supplied.
- Added cleanup of partially opened Java/JNDI resources on connection failure and
  immediate credential-lease retirement on success/failure.
- Added `JMSBSFProvider~probe()` and `JMSQueueBridgeService~probeProvider()` for
  connect/authenticate/JNDI/destination/data-connection readiness without
  creating consumers/producers or receiving a message.
- Added an explicitly gated `faa_swim_probe.rex` live-readiness example.
- Hardened `runtimeSelfTest` to verify the complete provider method surface
  required by each enabled direction.
- Added Alchemy Objects v0.8 adoption, environment credential, Secret Broker
  credential, provider-probe and real Runtime Registry v0.14 generation tests.
- Preserved `alchemy.jms.message/0.1`, inbound transfer-id duplicate suppression,
  outbound at-least-once semantics, and Java-free durable payloads.

## 0.1-dev2

- Corrected the BSF/JMS probe error-path operator from the invalid `\\==` token
  to ooRexx `\==`.
- Recorded external Codex-machine BSF/JMS classpath evidence: Java 21,
  `javax.jms.Message`, and Solace `SolJNDIInitialContextFactory` all resolve.
- No runtime bridge, Queue Fabric, persistence, or JMS transaction semantics changed.

## 0.1-dev1

- Created side-by-side JMS/Alchemy Queue bridge package.
- Kept BSF4ooRexx/Java coupling in `JMSQueueBridgeBSF.cls`, outside Queue Fabric.
- Added Java-free persistable JMS message envelope.
- Added transacted inbound flow using Queue Fabric durable transfer receipts for
  duplicate suppression across JMS redelivery.
- Added outbound claim -> JMS commit -> local ACK flow with explicit at-least-once
  duplicate window and `AlchemyTransferId` property.
- Added environment-backed credential source so passwords are not package state.
- Added deterministic inbound duplicate, rollback, outbound failure, durable
  persistence, and Runtime Registry lifecycle tests.
- Added FAA SWIM/SCDS example configuration and consumer skeleton.
