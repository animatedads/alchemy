# ooRexx JMS Queue Bridge v0.1-dev7-fb1

Side-by-side adapter between Java Message Service (JMS) and Alchemy Queue Fabric.
It remains deliberately outside Queue Fabric: Queue Fabric stays pure ooRexx,
while this package owns the optional BSF4ooRexx/Java/JMS boundary.

## Current qualification baseline

This development cut is based on the current API roll-up:

- ooRexx 5.3.0 r13196 debug runtime;
- `oorexx_queue_fabric_v0.9-dev4` (`queue.fabric/0.9`);
- `alchemy_objects_v0.8`;
- `runtime_registry_v0.14` (`runtime.registry/0.3` remains stable);
- `oorexx_secret_broker_v0.2` for optional credentials;
- `oorexx_crypto_v0.1`.

Live JMS additionally requires BSF4ooRexx850 and the chosen JMS provider JARs.
They are deliberately not bundled here.

### Recovered delivery status

This package is the previously written FederationBank `v0.1-dev7-fb1` compatibility cut recovered from the project file history, with one pre-delivery live-edge repair: `JMSBSFProvider~send` now exposes its existing `config` object variable before consulting `config~sessionMode` after a successful Java `producer~send`. Without that exposure, a live send could reach the broker and then fail locally while constructing the bridge result. No durable schema or Queue Fabric contract changes were made.

## Package boundary

```text
JMS broker
   |
   | javax.jms / vendor JMS implementation
   v
BSF4ooRexx / BSF.CLS
   |
JMSBSFProvider                 src/JMSQueueBridgeBSF.cls
   |
JMSQueueBridgeService         src/JMSQueueBridge.cls
   |
ObjectQueueManager
   |
Alchemy Queue Fabric
```

The Java-independent bridge, BSF/JMS binding and Secret Broker adapter remain
separate source files. Queue Fabric itself acquires no Java, JMS or BSF dependency.

## Durable message boundary

No BSF Java proxy is persisted. A JMS message is converted into the Java-free
`JMSBridgeMessage` graph before Queue Fabric acceptance.

The persistent type remains:

```text
alchemy.jms.message/0.1
```

v0.1-dev7-fb1 does not change that durable representation.

## Session policy

v0.1-dev3 incorrectly assumed that every live JMS bridge should use a transacted
session. Live FAA/SCDS diagnostics proved that assumption wrong for the current
monitoring subscription.

`JMSBridgeConfig~sessionMode` now explicitly supports:

```text
AUTO_ACKNOWLEDGE      non-transacted; JMS constant 1
CLIENT_ACKNOWLEDGE    non-transacted; JMS constant 2
TRANSACTED            local JMS transaction; optional, broker permitting
```

The default is `AUTO_ACKNOWLEDGE`, matching the current FAA monitoring profile.
The BSF provider therefore creates the default session as:

```rexx
connection~createSession(.false, 1)
```

No `commit()` or `rollback()` is issued for an AUTO_ACKNOWLEDGE session.

### AUTO_ACKNOWLEDGE monitoring semantics

With synchronous JMS receive, AUTO_ACKNOWLEDGE may acknowledge the broker message
when `receive()` returns. Queue Fabric persistence happens afterwards. Therefore
a crash or local Queue Fabric rejection in that interval can lose that observation.
The bridge reports this explicitly as:

```text
LOCAL_ACCEPT_FAILED_AFTER_AUTO_ACK
```

That mode is appropriate only when the subscription is intentionally monitoring /
best-effort and this loss window is accepted. The package does not mislabel it as
at-least-once delivery.

### CLIENT_ACKNOWLEDGE non-transacted durable semantics

`CLIENT_ACKNOWLEDGE` is available when a non-transacted provider/client profile
supports it and post-persistence acknowledgement is required. The bridge is
single-consumer and synchronous per session, so it can:

```text
JMS receive (unacknowledged)
    -> Queue Fabric acceptTransfer(...)
    -> Message~acknowledge()
```

If local acceptance fails, `Session~recover()` is requested instead of an ACK.
If acknowledgement fails after local durable acceptance, redelivery reuses the
same transfer id and Queue Fabric suppresses duplicate insertion.

That mode can provide the useful bridge property:

> at-least-once JMS delivery with idempotent Queue Fabric insertion

without requiring a transacted session. It has not yet been live-qualified on the
current FAA profile.

### TRANSACTED mode

The original transacted behavior remains available for other JMS deployments that
support it. It is no longer the default and is not required by Queue Fabric.

## Outbound reliability

For a non-transacted session:

```text
Queue CLAIM -> JMS send returns -> Queue ACK
```

There is no fake JMS commit/rollback. A send failure releases the local Queue
package. A crash after successful remote send but before local Queue ACK can
produce a duplicate on retry; `AlchemyTransferId` is attached to the JMS message
for downstream duplicate recognition.

For an explicitly transacted session, provider completion/abort maps to JMS
commit/rollback. The Java-neutral core uses settlement vocabulary rather than
assuming every provider is transactional.

## Solace transport policy

`JMSBridgeConfig~transportMode` supports:

```text
ADMINISTERED   use the JNDI ConnectionFactory exactly as provisioned (default)
DIRECT         for a Solace SolConnectionFactory, setDirectTransport(.true)
GUARANTEED     for a Solace SolConnectionFactory, setDirectTransport(.false)
```

The override is intentionally in `JMSQueueBridgeBSF.cls`; the Queue Fabric/core
bridge remains vendor-neutral.

## Live FAA/SCDS evidence carried into dev6

The external BSF/JMS host has now run the complete dev5 capability probe against
the supplied FAA endpoint.  The deterministic suite and Java/JMS classpath pass,
and the live path reaches consumer construction successfully:

```text
Java 21 / BSF4ooRexx / JMS classes                   PASS
TLS / JCSMP authentication                           PASS
JNDI InitialContext / ConnectionFactory              PASS
JMS data connection                                  PASS
non-transacted session creation                      PASS
queue destination lookup                             PASS
MessageConsumer creation                             PASS

AUTO_ACKNOWLEDGE + ADMINISTERED                      FAIL at Connection.start()
AUTO_ACKNOWLEDGE + GUARANTEED                        FAIL at Connection.start()
CLIENT_ACKNOWLEDGE + ADMINISTERED                    FAIL at Connection.start()
CLIENT_ACKNOWLEDGE + GUARANTEED                      FAIL at Connection.start()

classification                                       BROKER_FLOW_ACTIVATION_BLOCKED
messages consumed                                    0
```

The exact probe code reported by the package is:

```text
JMS_FLOW_PROBE_FAILED_AT_PROBE_CONNECTION_START
```

The remaining live issue is therefore isolated to broker-side consumer-flow
activation for this endpoint/client profile.  It is not evidence of bad credentials,
TLS, JNDI lookup, JMS session construction, queue naming, or local consumer
construction.  No receive was attempted and no FAA message was consumed.

## Stage-specific live diagnostics

The BSF provider now records an explicit stage and reports errors such as:

```text
JMS_CONNECT_FAILED_AT_SESSION
JMS_CONNECT_FAILED_AT_INBOUND_CONSUMER
JMS_CONNECT_FAILED_AT_CONNECTION_START
JMS_FLOW_PROBE_FAILED_AT_FLOW_CONNECTION_START
```

`probe()` remains connection-only and creates no consumer or producer.

`probeInboundFlow()` is the next boundary: it creates the configured session and
inbound consumer and calls `Connection.start()`, then closes everything without
calling `receive()`.

Use it explicitly:

```sh
export JMS_LIVE_FLOW_PROBE=1
export FAA_SWIM_JMS_SESSION_MODE=AUTO_ACKNOWLEDGE
export FAA_SWIM_JMS_TRANSPORT_MODE=ADMINISTERED   # or DIRECT / GUARANTEED
./run_tests.sh live-flow-probe
```

This lets one transport policy be exercised without consuming a message.

### Operational readiness disposition

v0.1-dev7-fb1 separates successful *diagnosis* from operational readiness. A capability
matrix can execute correctly while proving that the external broker refuses all
consumer-flow activation candidates. `JMSBridgeFlowCapabilityReport` therefore
exposes:

```text
classification          protocol/capability evidence
operationalDisposition  READY / EXTERNAL_BLOCKED / UNRESOLVED / NO_EVIDENCE
operatorAction          bounded next action, never an automatic broker mutation
```

For the current FAA evidence the expected deployment result is:

```text
classification          BROKER_FLOW_ACTIVATION_BLOCKED
operationalDisposition  EXTERNAL_BLOCKED
operatorAction          BROKER_OR_CLIENT_PROFILE_FLOW_ACTIVATION_REVIEW_REQUIRED
```

`JMSQueueBridgeService~assessInboundReadiness()` converts the no-receive matrix into
that deployment result while the bridge remains STOPPED. It does not start the
consumer, mutate Queue Fabric, consume a message, or silently change session or
transport policy. This prevents an externally blocked endpoint from being mistaken
for a local bridge implementation defect.

The live capability example now also prints `DISPOSITION` and `ACTION`. Diagnostic
use still exits successfully after collecting evidence. CI/deployment gates can set:

```sh
export JMS_FLOW_REQUIRE_READY=1
```

to make the same non-consuming probe return non-zero unless a usable flow actually
activates.

### Bounded capability matrix

v0.1-dev5 adds a non-consuming matrix probe so the important policy combinations
can be compared in one controlled run instead of repeatedly editing a temporary
diagnostic script. By default it tests:

```text
AUTO_ACKNOWLEDGE   + ADMINISTERED
AUTO_ACKNOWLEDGE   + GUARANTEED
CLIENT_ACKNOWLEDGE + ADMINISTERED
CLIENT_ACKNOWLEDGE + GUARANTEED
```

`TRANSACTED` is deliberately absent from this matrix: the FAA monitoring bridge
does not require it and the current router has already rejected that capability.
`DIRECT` can be included only as an explicit diagnostic control.

Each attempt performs JNDI lookup, data connection, session creation, destination
lookup, consumer creation and `Connection.start()`, then closes the resources. It
never calls `receive()`. The result is represented by Java-neutral
`JMSBridgeFlowCapabilityReport` evidence. If every candidate fails specifically
at flow activation, the report classifies the endpoint as:

```text
BROKER_FLOW_ACTIVATION_BLOCKED
```

If a usable path exists, the report prefers `CLIENT_ACKNOWLEDGE + GUARANTEED`,
then CLIENT_ACK with the administered transport, then AUTO_ACK candidates. This
is a bridge reliability preference, not an attempt to modify broker policy.

Run the live matrix explicitly:

```sh
export JMS_LIVE_CAPABILITY_PROBE=1
./run_tests.sh live-capability-probe
```

Optionally include Direct Transport as a negative/control candidate:

```sh
export JMS_FLOW_MATRIX_INCLUDE_DIRECT=1
```

For Solace connection factories, dev5 also records the effective
`getDirectTransport()` value before and after any requested override. This makes
`ADMINISTERED` observable rather than merely assumed.

## Credentials

`JMSBridgeEnvironmentCredentials` stores environment-variable names rather than
passwords. `JMSBridgeSecretBrokerCredentials` optionally uses Secret Broker v0.2
logical references. In both cases materialized credentials live in short-lived
leases and are retired after connection setup/failure.

Do not commit portal credentials to this package.

## Alchemy / Runtime Registry

`JMSQueueBridgeService` and the optional Secret Broker adapter follow Alchemy
Objects v0.8 STANDARD adoption. Ordinary collaborator invocation is classified as
`authority_effect=NONE`, not as authority delegation.

Runtime Registry lifecycle remains:

```text
runtimePrepare
runtimeSelfTest
runtimeStart
runtimeQuiesce
runtimeStop
```

The v0.14 generation lifecycle fixture is retained.

## Supported JMS bodies

The live codec is deliberately narrow:

- `javax.jms.TextMessage`: supported;
- `javax.jms.MapMessage`: supported in v0.1-dev7-fb1, with a Java-free ooRexx Directory body;
- BytesMessage: not yet enabled;
- ObjectMessage / arbitrary Java payload: rejected.

This prevents Java object graphs from leaking into durable Queue Fabric state. The
MAP codec and JMS property/correlation path have been exercised against a real
ActiveMQ broker through BSF4ooRexx v850 on ooRexx 5.3.0 r13196.

## Test matrix

```sh
export QF_SRC=/path/to/oorexx_queue_fabric_v0.9-dev4/src
export ALCHEMY_OBJECTS_SRC=/path/to/alchemy_objects_v0.8/src
export CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src
export SECRET_BROKER_SRC=/path/to/oorexx_secret_broker_v0.2/src
export RUNTIME_REGISTRY_SRC=/path/to/runtime_registry_v0.14/src

./run_tests.sh all
```

Modes:

```text
style
compile
inbound
outbound
persistence
lifecycle
session
adoption
credentials
secret
registry
bsf-probe
live-probe
live-flow-probe
live-capability-probe
live-activemq-edge
core
all
```

`bsf-probe` needs real BSF4ooRexx and JMS provider classes. The FAA/SCDS live
diagnostic modes require explicit opt-in. `live-probe`, `live-flow-probe`, and
`live-capability-probe` do not call `receive()`.

`live-activemq-edge` is an explicit development qualification mode. It requires
`JMS_LIVE_ACTIVEMQ_EDGE=1`, `ACTIVEMQ_BROKER_URL`, BSF4ooRexx, and an ActiveMQ
JMS client on the Java class path. It exercises a real broker in both directions:
real Java `MapMessage` -> bridge decode/CLIENT_ACK, and Java-free bridge MAP/TEXT
-> real broker message, including application properties, reserved bridge
metadata, `JMSCorrelationID`, and `JMSType`.
