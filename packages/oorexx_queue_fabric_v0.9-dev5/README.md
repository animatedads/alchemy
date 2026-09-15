# Object Queue Fabric v0.9-dev5 (aggregate API 0.9; broker API 0.2)

> Secure inter-node transport development cut. `QueueFabricBuild` remains `VERSION 0.9` / `queue.fabric/0.9` and established durable record identities remain unchanged, while the TCP wire protocol advances deliberately from `queue.transport/1` to encrypted `queue.transport/2`. v0.9 is **not** released until the complete acceptance matrix and Alchemy Autobuild result are green.

## v0.9-dev5 secure inter-node transport slice

- retains the aggregate Queue Fabric API at `queue.fabric/0.9` and keeps `queue.fabric.transmission-envelope/1`, `queue.fabric.topic-interest/1`, `queue.fabric.topic-distribution-work/1`, `queue.fabric.remote-topic-publication/1` and QAUTH2 (`queue.auth.record/2`) unchanged;
- advances only the remote TCP wire protocol to `queue.transport/2`, making confidentiality and exact source-IP admission mandatory for the socket transport;
- requires every trusted socket peer to have an explicit **canonical numeric IPv4** source allowlist and rejects an unlisted accepted socket before reading HELLO or attempting peer authentication; CIDR, hostnames, IPv6, leading-zero forms and `0.0.0.0` are rejected by this development cut;
- derives independent client-to-server/server-to-client ChaCha20 and HMAC-SHA-512 keys from the transport PSK, authenticated peer transcript and fresh client/server nonces; secure bodies use encrypt-then-MAC and verify authentication before decryption; tests also reject cross-session replay and prove direction-separated secure frames;
- keeps HELLO/CHALLENGE metadata authenticated but visible, and deliberately makes no forward-secrecy claim for the PSK design;
- retains the executable release-boundary lock for durable identities while updating the intentional wire identity to `queue.transport/2`;
- proves **both directions** of durable compatibility with the exact accepted v0.8.2 source: v0.8.2 -> v0.9 and v0.9 -> v0.8.2, for ordinary journals and QAUTH2/HMAC-authenticated journals;
- retains the staged Alchemy Objects v0.5 adoption on long-lived runtime authorities: `ObjectQueueManager`, `QueueChannelFabric`, `QueueTopicFabric`, `QueueDistributedTopicFabric`, `QueueSocketClientTransport`, `QueueSocketListener`, broker service and admission objects;
- deliberately leaves durable work/value objects outside `AlchemyObject`, so common-base telemetry cannot leak into persisted customer graphs;
- retains Runtime Registry v0.12 lifecycle integration, WLU v0.6 pre-CLAIM admission, authenticated heartbeat, conservative ordered failover, and NoSQLServer v0.77 service/transport projections from dev2/dev3;
- updates NoSQL manager projections to report the promoted aggregate version `0.9`;
- keeps WLU optional behind `QueueBrokerAdmissionPolicy`. A WLU denial still happens before queue CLAIM, delivery-count/backout-count mutation, or transport side effects.

The release-version promotion is intentionally an **API/package identity change, not a persistence-format rewrite**. That distinction is now tested rather than left as prose.

For the intended two-server Oracle Cloud deployment, see `OCI_TWO_NODE_DEPLOYMENT.md` and `SECURE_TRANSPORT.md`.

Object Queue Fabric is an ooRexx-native queue and work-package substrate with MQ-like wiring semantics. It is deliberately **not** a shell job queue and **not** an IBM MQ compatibility layer. Queues, work packages, payloads, trigger targets, routes and units of work remain first-class ooRexx objects.

The design rule remains: **preserve rich ooRexx objects inside the fabric; project/encode only at explicit boundaries such as persistence and SQL.**

## What v0.8 provides

v0.8 retains the accepted v0.7 queue/channel/transport/topic surface and adds native **distributed topic interest propagation**. Topics remain a routing/fan-out namespace over queues: queues remain the work-delivery primitive, publication payloads remain ooRexx object graphs, and remote brokers exchange aggregated interest rather than one network subscription per application subscriber.

- Named `TEMPORARY` and `PERMANENT` queues.
- READY / INFLIGHT / TOTAL depth and bounded/unbounded capacity.
- Rich `QueueWorkPackage` envelopes carrying arbitrary live ooRexx object graphs.
- Priority ordering: higher priority first, FIFO by package sequence within a priority.
- Destructive `GET` and recoverable `CLAIM` / `ACK` / `NACK` consumption.
- Per-package TTL via `expirySeconds`.
- Queue-local earliest-expiry watermark so queues with no due TTL work avoid repeated package scans.
- Explicit `backoutCount`, queue backout threshold and backout destination.
- Queue-manager dead-letter queue, including optional backout-to-DLQ fallback.
- Same-domain expiry/dead-letter/backout movement; disposition routing never silently crosses a security domain.
- Transactional units of work: reserve GETs, stage PUTs, commit or roll back.
- UOW PUTs honour COPY/REDIRECT routing and capacity is preflighted against the transaction's **net** queue-depth effect.
- Durable UOW state is written as one replayable `UOWCOMMIT` journal record, so a committed durable consume+produce cannot replay as a half-transaction.
- PUT, GET, CLAIM, ACK, NACK, RELEASE, EXPIRE, BACKOUT, DEAD_LETTER, UOW_COMMIT, UOW_ROLLBACK, DEPTH_AT_LEAST, EMPTY and NONEMPTY triggers.
- Direct in-process trigger targets and Runtime Registry-backed persistent trigger targets.
- COPY and REDIRECT routing by routing key, including wildcard `*` routes.
- Atomic route preflight before ordinary routed PUT mutation.
- Queue-local PUT / GET / BROWSE / MANAGE ACLs and security-domain labels.
- Explicit admin-only cross-security-domain normal routing bridges.
- Append-only durable queue journal and traffic log.
- Optional HMAC-SHA-512 authenticated record chains with periodic Ed25519 checkpoints using standalone `oorexx_crypto_v0.1`.
- HMAC key rotation and Ed25519 checkpoint key rings.
- Strict recovery plus explicitly bounded torn-tail repair.
- Restart recovery of queue definitions, ACLs, package state, backout/DLQ configuration, routes and registry-backed triggers.
- Persistent INFLIGHT work recovers to READY after restart, retaining delivery count.
- NoSQLServer v0.73 read-only projections, including MQ lifecycle/UOW, channel and socket-transport observability metadata.
- Private manager authority protects internal envelope/queue/UOW mutation from references handed to callers.
- MQ-style remote queue definitions that resolve an application-visible alias to a remote queue manager, remote queue, transmission queue and sender channel.
- Named sender and receiver channels with explicit STOPPED / RUNNING / RETRYING / PAUSED state.
- Permanent transmission queues provide store-and-forward while the remote manager is unavailable or backpressured.
- Receiver channels bind expected source queue manager and inbound principal before queue ACL evaluation.
- Receiver acceptance is idempotent by `transferId`; for persistent delivery, the package insertion and transfer receipt are one durable journal mutation.
- Channel retry uses an explicit `RELEASE` queue transition: delivery count records an attempted transmission while application `backoutCount` is unchanged.
- Built-in persistent `QueueTransmissionEnvelope` preserves nested/cyclic payload graphs across transmission-queue restart.
- NoSQLServer projections extend to sender channels, receiver channels, remote queue definitions and transfer receipts.
- Real inter-process `QueueSocketClientTransport` / `QueueSocketListener` using official ooRexx socket objects rather than raw `Sock*` calls.
- One delivery request per TCP connection for simple reconnect/failure boundaries; store-and-forward and retry remain channel responsibilities.
- Bounded 8-byte length-prefixed framing with exact-read and partial-write handling.
- HMAC-SHA-512 client HELLO proof, server challenge proof, delivery proof and authenticated result frames.
- Wire authentication binds source manager, destination manager, receiver channel, principal, key id, both nonces and the exact graph-codec envelope bytes.
- Fresh-connection replay remains receiver-idempotent via the durable transfer receipt.
- Socket endpoint/listener/peer metadata is queryable through NoSQLServer without exposing HMAC key material.
- Executable ooRexx message-style source gate rejects foreign-language-shaped message syntax in first-party queue classes.
- Named topic definitions with independent ACL/security-domain roots.
- Hierarchical topic strings using `/`, with `+` for exactly one level and terminal `#` for zero-or-more levels.
- TEMPORARY and PERMANENT subscriptions wired to ordinary queue destinations.
- Subscription creation requires topic SUBSCRIBE authority plus MANAGE authority on the destination queue.
- Atomic publish fan-out through one queue-manager UOW: all currently matching subscriber queues receive the publication or none do.
- Durable and temporary retained publications, including immediate retained replay to new subscriptions.
- Persistent retained state and persistent subscriber PPUTs share the same authenticated `UOWCOMMIT` record.
- A durable subscription does not silently upgrade a non-persistent publication into persistent queue work.
- Queue deletion is blocked while a live topic subscription references the queue.
- Topic definitions, subscriptions, retained state, grants and traffic are queryable through NoSQLServer v0.73.
- Distributed topic peers exchange revisioned, path-carrying subscription-interest advertisements; one matching remote manager receives one publication regardless of its number of local subscribers.
- Downstream interest may be aggregated across multiple brokers (for example C → B → A) and withdrawn back through the same mesh.
- Publication manager paths provide split-horizon/loop suppression while preserving the original publication identity.
- Source-side local fan-out, retained state and one durable distribution intent per interested remote manager are staged in the same local UOW.
- Receiver-side subscriber PPUTs, retained state and `DTPUBRECEIPT` are committed in the same local UOW, making redelivered remote ingress idempotent across restart.
- Retained publications are handed to a newly interested remote broker through the same durable distribution queue rather than by out-of-band state copying.
- Distributed topic control/publication traffic reuses the existing remote-queue/channel/transport layer, including authenticated TCP transport.
- Distributed topic peer/interest/advertisement/receipt/traffic state is queryable through NoSQLServer without exposing transport secrets.

## Security boundary

Queue authority and durable-record cryptography are deliberately separate.

ACLs, queue ownership, manager authority and security domains control **who may perform queue operations**. `ObjectQueueCrypto.cls` controls **whether durable journal/log records can be authenticated during replay**.

With `QueueHmacSha512RecordProtector`, durable records use HMAC-SHA-512 over a SHA-512 chain and may carry periodic Ed25519 checkpoint signatures. The authoritative `crypto.cls` is supplied by standalone `oorexx_crypto_v0.1`.

`QAUTH2` is authentication/integrity, **not confidentiality**. It does not encrypt payloads or journal text. A security-domain label is also not encryption. At-rest secrecy still requires an encrypted storage layer or a future queue confidentiality codec.

Expiry, backout and dead-letter movement refuses implicit cross-domain disposition. Ordinary routing can cross domains only through the existing explicit admin-authorised route bridge.

Distributed channels add a second authority boundary. A receiver channel checks the expected source manager and inbound principal, then `ObjectQueueManager~acceptTransfer()` applies the destination queue ACL and security-domain rule. `QueueInProcessTransport` remains the reference/test transport. v0.6 additionally provides a real TCP transport whose shared-key HMAC authentication binds the source/destination manager identities, receiver channel, claimed principal, key id, both nonces and exact encoded transmission envelope before `receiveEnvelope()` is invoked.

The v0.9-dev5 TCP transport is `queue.transport/2`. It requires an explicit exact source-IP allowlist for each trusted peer and rejects an unlisted accepted socket before HELLO processing. After the authenticated challenge, DELIVER/PROBE/RESULT/HEALTH bodies are ChaCha20-encrypted and authenticated with a separate HMAC-SHA-512 key derived per connection from the transport PSK, authenticated transcript and fresh client/server nonces. HELLO/CHALLENGE metadata remains authenticated but visible. This PSK transport does **not** claim forward secrecy; see `SECURE_TRANSPORT.md` for the security and OCI deployment boundary.

Topics add a distinct wiring authority. PUBLISH, SUBSCRIBE, BROWSE and MANAGE are independent topic permissions. Creating a subscription also requires MANAGE on its destination queue, and explicit cross-domain subscriptions require manager-admin authority. Durable retained state is broker-owned journal state; a custom non-admin broker cannot commit it.

Distributed topic peers are manager-admin wiring. A peer maps one local named topic to a remote named topic through explicit control/publication remote-queue definitions. Incoming interest/publication messages are accepted only through configured peer mappings and topic security-domain checks. `allowCrossDomain` is explicit peer authority, not an implicit consequence of network reachability. Publication path metadata prevents broker loops but is not treated as an authentication primitive; authenticated peer identity continues to come from the channel/transport layer.

## Dependencies

Core queue operation requires ooRexx 5.3.0. This development cut was validated with the supplied **ooRexx 5.3.0 r13196** debug build.

The v0.9 runtime-authority layer also requires **Alchemy Objects v0.5**. `ObjectQueueManager`, channel/topic/distributed-topic fabrics and socket transport authorities now inherit `AlchemyObject`; durable work/value records deliberately do not. This is therefore a real runtime dependency for v0.9, not merely a test dependency.

The authenticated durable-store option depends on standalone `oorexx_crypto_v0.1`; set `CRYPTO_SRC`/`OOREXX_CRYPTO_SRC` to that package's `src/` directory.

Optional integrations used by this v0.9 development cut and its supplied tests:

- NoSQLServer v0.77 for queue/channel/topic/distributed/transport/service projections.
- Runtime Registry v0.12 (`runtime.registry/0.3`) for generation-managed lifecycle integration.
- Work Load Units v0.6 for the optional pre-side-effect transfer/heartbeat admission adapter.

NoSQLServer, Runtime Registry and WLU remain optional. Alchemy Objects does not: the accepted long-lived authority migration in v0.9 makes `AlchemyObject.cls` part of the core class search path.

## Alchemy Autobuild candidate manifest

`integration.json` uses `alchemy.autobuild.integration/0.3` with deterministic dependency paths and separates costly socket/crypto/compatibility work into independently timed tests. The dev5 manifest is deliberately `artifact_only`; it cannot publish `packages/oorexx_queue_fabric_v0.9` and therefore cannot accidentally turn this development cut into a release.

The manifest expects these exact repository package roots before execution:

```text
packages/oorexx_crypto_v0.1/src
packages/nosqlserver_v0.77/src
packages/runtime_registry_v0.12/src
packages/alchemy_objects_v0.5/src
packages/oorexx_work_load_units_v0.6/src
packages/oorexx_queue_fabric_v0.8.2/src
```

The final v0.9 release manifest should change from artifact-only to a source-tree publication only after the complete matrix, including full 2000-work-item concurrency and the authenticated crypto tail, is green in the authoritative Autobuild environment.

## Source layout

```text
src/ObjectQueueFabric.cls      core queue/object/UOW fabric
src/ObjectQueueCrypto.cls      authenticated durable-record adapter
oorexx_crypto_v0.1/src/crypto.cls shared SHA-512 / HMAC / Ed25519 implementation
src/ObjectQueueNoSQL.cls       NoSQLServer v0.77 base projection adapter
src/ObjectQueueChannels.cls     remote queues / sender+receiver channels / transport seam
src/ObjectQueueChannelNoSQL.cls NoSQLServer v0.77 distributed wiring projection
src/ObjectQueueSocketTransport.cls authenticated bounded TCP transport
src/ObjectQueueTransportNoSQL.cls NoSQLServer v0.77 socket transport projection
src/ObjectQueueTopics.cls      topic definitions/subscriptions/retained publish fabric
src/ObjectQueueTopicNoSQL.cls  NoSQLServer v0.77 topic projection
src/ObjectQueueDistributedTopics.cls distributed interest/pub-sub broker layer
src/ObjectQueueDistributedTopicNoSQL.cls distributed topic NoSQL projection
src/ObjectQueueBrokerService.cls AlchemyObject-based broker lifecycle/admission/retry service
src/ObjectQueueWLU.cls         optional Work Load Units v0.6 admission adapter
examples/basic_queue.rex       object queue / trigger / claim example
examples/nosql_queue.rex       SQL metadata query example
examples/distributed_queue.rex distributed remote-queue/channel example
examples/topic_queue.rex       hierarchical topic fan-out example
examples/distributed_topic.rex aggregated remote-interest/fan-out example
tests/test_queue_fabric.rex    retained functional/persistence acceptance
tests/test_queue_adversarial.rex
                               authority/recovery/atomicity acceptance
tests/test_queue_concurrency.rex
                               multi-activity producer/consumer acceptance
tests/test_queue_mq_semantics.rex
                               expiry/backout/DLQ/UOW/restart/routing tests
tests/test_queue_mq_nosql.rex  v0.8 base NoSQL projection tests
tests/test_queue_channels.rex   store-and-forward / retry / idempotency / restart tests
tests/test_queue_channel_nosql.rex
                               distributed NoSQL projection tests
tests/test_queue_uow_crypto.rex
                               authenticated one-record durable UOW test
tests/test_queue_channel_crypto.rex
                               authenticated one-record transfer acceptance test
tests/test_queue_topics.rex     topic matching/ACL/UOW/retained/recovery acceptance
tests/test_queue_topic_nosql.rex
                               topic NoSQL projection/visibility acceptance
tests/test_queue_topic_crypto.rex
                               authenticated retained+fanout UOW acceptance
tests/test_queue_distributed_topics.rex
                               two-broker aggregated-interest/fan-out acceptance
tests/test_queue_distributed_topic_multihop.rex
                               A-B-C interest aggregation/loop suppression
tests/test_queue_distributed_topic_recovery.rex
                               durable distribution/receipt/restart acceptance
tests/test_queue_distributed_topic_nosql.rex
                               distributed topic NoSQL projection acceptance
tests/test_queue_distributed_topic_socket.sh
                               real authenticated TCP distributed-topic acceptance
tests/test_queue_distributed_topic_crypto.rex
                               authenticated distributed receiver UOW acceptance
tests/test_queue_socket_framer.rex
                               bounded framing / partial-send acceptance
tests/test_queue_transport_nosql.rex
                               transport observability / secret non-projection
tests/test_queue_socket_transport.sh
                               three-process authenticated TCP + restart test
tests/test_queue_socket_security.sh
                               wrong-key/replay/backpressure transport tests
tests/test_oorexx_message_style.sh
                               first-party ooRexx message-style source gate
tests/test_crypto_known_answer.rex
tests/test_queue_crypto.rex
tests/test_queue_checkpoint.rex
tests/test_queue_rotation.rex
tests/test_queue_recovery.rex
tests/test_checkpoint_keyring.rex
run_tests.sh
```

## ObjectQueueManager

Constructor:

```rexx
manager = .ObjectQueueManager~new( -
    storeRoot, payloadCodec, adminPrincipal, runtimeRegistry, -
    recordProtector, recoveryMode, timeSource)
```

All arguments remain optional/trailing as in earlier releases. `timeSource` defaults to `QueueTimeSource`; it exists primarily to make TTL semantics deterministic and testable.

Main operations:

```text
createQueue(name, lifecycle, securityDomain, maxDepth, principal)
deleteQueue(name, principal)
grant(queue, grantee, action, principal)
revoke(queue, grantee, action, principal)
depth(queue, principal)
put(queue, payload, options, principal)
browse(queue, principal)
get(queue, principal)
claim(queue, principal)
ack(queue, packageId, claimToken, principal)
nack(queue, packageId, claimToken, principal)
release(queue, packageId, claimToken, principal, detail)
acceptTransfer(transferId, queue, payload, options, principal)
transferReceipt(transferId)
transferReceiptCount
checkpointPackage(queue, packageId, principal)
setDeadLetterQueue(queueName, principal)
configureBackout(queueName, threshold, backoutQueue, principal)
sweepExpired(queueName, principal)
beginUnitOfWork(principal)
uowGet(uow, queueName)
uowPut(uow, queueName, payload, options)
commitUnitOfWork(uow)
rollbackUnitOfWork(uow)
registerTrigger(queue, kind, target, threshold, principal)
deregisterTrigger(triggerId, principal)
registerRoute(source, routingKey, destination, mode, priority, allowCrossDomain, principal)
deregisterRoute(routeId, principal)
```

Operations return `QueueOperationResult` containing `ok`, `code`, `value`, `detail` and `triggerFailures`.

## Work packages and TTL

A PUT creates a `QueueWorkPackage`. Supported options are:

```text
priority       default 0
persistent     default false
routingKey     default ""
correlationId  default ""
replyTo        default ""
headers        default empty .Table
securityDomain default source queue security domain
expirySeconds  default 0 (never expires)
```

TTL is stored as a high-resolution fixed clock value. ooRexx's default numeric precision is too small for direct arithmetic on `TIME('F')`; v0.4 deliberately keeps that arithmetic behind `QueueTimeSource` with raised `NUMERIC DIGITS` rather than relying on visually plausible but numerically lossy Rexx expressions.

Each queue tracks both `expiringDepth` and `earliestExpiryTick`. If there is no TTL work, or the earliest TTL is still in the future, normal GET/CLAIM/BROWSE paths do not scan the queue for expiry.

Expiry is enforced lazily by `depth`, `browse`, `get`, `claim`, and explicitly by `sweepExpired`. The NoSQL adapter is a read-only snapshot and does not mutate queue state merely to make a query.

When an expired READY package is encountered:

1. if a configured same-domain DLQ exists and has capacity, the package is moved there;
2. its `deadLetterReason` becomes `EXPIRED`, `deadLetterSourceQueue` records the source, and its TTL is cleared so it does not immediately expire again;
3. otherwise it is removed and a traffic event records that dead-letter disposition was unavailable.

## Backout and dead-letter handling

`backoutCount` is separate from `deliveryCount`.

- `deliveryCount` increments when a package is claimed.
- `backoutCount` increments on an explicit `NACK` and on a UOW rollback of a reserved GET.
- `RELEASE` returns a claimed package to READY **without** incrementing `backoutCount`; sender channels use it for transient transport retry/backpressure.
- Crash recovery of an abandoned persistent INFLIGHT claim restores READY and retains delivery count; v0.4 does **not** increment backout count merely because the process restarted.

Configure an explicit backout queue:

```rexx
ignore = manager~configureBackout("WORK", 3, "WORK.BACKOUT", "admin")
```

Or configure a threshold with an empty target to use the queue-manager DLQ:

```rexx
ignore = manager~setDeadLetterQueue("DLQ", "admin")
ignore = manager~configureBackout("WORK", 3, "", "admin")
```

A permanent source may only use a permanent backout/DLQ destination. Backout/dead-letter disposition must remain in the same security domain.

At threshold, a NACK/rollback moves the **same work-package object/envelope** to the destination rather than flattening and rebuilding the payload. If the target is unavailable/full, the package is returned READY to the source rather than lost.

Permanent backout configuration and manager DLQ configuration are journalled and restored. A queue cannot be deleted while another queue references it as a backout target or while it is the configured manager DLQ.

## Units of work

A UOW is an authority-bound object owned by the manager:

```rexx
uow = manager~beginUnitOfWork("worker")~value
input = manager~uowGet(uow, "INPUT")~value
ignore = manager~uowPut(uow, "OUTPUT", transformedPayload, options)
commitResult = manager~commitUnitOfWork(uow)
```

`uowGet` reserves a READY package as INFLIGHT under an internal `UOW:<id>` claim identity. The caller may inspect/mutate the payload object, but cannot escape the UOW by using ordinary `ack()` with the user principal.

`uowPut` stages a PUT; it is not visible in queue depth until commit.

Commit revalidates every reservation, route, security boundary, persistence codec and destination capacity while holding the manager guard. Capacity is calculated from the transaction's **net effect**, so a max-depth-1 queue can atomically consume one package and produce its replacement.

For durable work, all persistent removals/additions are encoded into a single `UOWCOMMIT` journal record **before** live queue mutation. Recovery applies the enclosed operation rows as one committed unit. An authenticated store wraps that entire UOW record in one `QAUTH2` authenticated record.

A failed preflight leaves the UOW ACTIVE: reserved GETs remain reserved and staged PUTs remain invisible until the caller retries or rolls back. Rollback returns reserved packages to READY, increments their backout count and applies backout policy if the configured threshold is reached.

The queue traffic log remains an audit/event stream; it is not claimed to be transactionally atomic with the queue journal.

## Triggers

Trigger kinds in v0.5:

```text
PUT GET CLAIM ACK NACK RELEASE
EXPIRE BACKOUT DEAD_LETTER
UOW_COMMIT UOW_ROLLBACK
DEPTH_AT_LEAST EMPTY NONEMPTY
```

Direct trigger target:

```rexx
target = .QueueDirectTriggerTarget~new(handlerObject, "onQueueTrigger")
```

Runtime Registry target:

```rexx
target = .QueueRegistryTriggerTarget~new("live", "my.trigger.module", "onQueueTrigger")
```

Direct registrations are process-local. Registry-backed registrations on permanent queues persist wiring identity while executable implementation authority remains with Runtime Registry.

Trigger failures occur after the queue transition/commit and are surfaced in `QueueOperationResult~triggerFailures`; they do not retroactively unwind committed work.

## Routing

Routes match `routingKey`; `*` is a wildcard. Higher priority routes sort first.

- `COPY` preserves source delivery and creates routed package copies.
- `REDIRECT` sends the work to the destination instead of the source.

Ordinary routed PUTs preflight all targets before mutation. UOW PUTs use the same route decision model during commit and include every routed target in transaction-wide capacity/security preflight.

Cross-domain ordinary routing requires `allowCrossDomain` and admin registration. Expiry/backout/dead-letter disposition deliberately does not inherit that bridge.

## Payload persistence

`QueueGraphPayloadCodec` preserves scalar values plus nested/cyclic arrays/tables and object reference identity. Domain objects opt in through `QueuePayloadTypeRegistry` by supplying:

```text
queuePersistentType
queuePersistentState
queueRestoreState(state)
```

with a registered factory supplying `newBlank`.

The fabric does not stringify arbitrary domain objects and pretend they can later be reconstructed.

`QueueTransmissionEnvelope` is a built-in registered persistent domain type in v0.5. This is intentional: a permanent transmission queue must be able to recover remote work **before** the higher-level channel facade is constructed after restart. The envelope contains the original payload object graph plus routing/correlation/security metadata; it is not a flattened wire string.

## NoSQLServer projection

`QueueNoSQLAdapter` builds read-only object-table snapshots. Payload graphs remain objects; only management metadata is projected.

Tables:

```text
mq_manager             admin-only queue-manager metadata
mq_queues
mq_packages
mq_triggers
mq_routes
mq_traffic
mq_transfer_receipts

# when using QueueChannelNoSQLAdapter
mq_sender_channels       admin-only channel state/identity
mq_receiver_channels     admin-only channel state/identity
mq_remote_queues         aliases visible to admin or principals allowed to PUT

# when using QueueTransportNoSQLAdapter
mq_transport_endpoints   admin-only endpoint metadata/counters
mq_transport_listeners   admin-only listener metadata/counters

# when using QueueTopicNoSQLAdapter
mq_topics
mq_topic_subscriptions
mq_retained_publications
mq_topic_grants
mq_topic_traffic

# when using QueueDistributedTopicNoSQLAdapter
mq_topic_peers
mq_remote_topic_interests
mq_topic_interest_advertisements
mq_topic_distribution_receipts
mq_distributed_topic_traffic
```

v0.8 retains the lifecycle/UOW, distributed-channel, transport and local-topic projections and adds distributed topic interest/path/receipt observability.

Example:

```rexx
adapter = .QueueNoSQLAdapter~new(manager)
queryResult = adapter~query("admin", -
  "SELECT queue_name,backout_threshold,expiring_depth FROM mq_queues")
```

SQL mutation is deliberately not an alternate queue-control API.

## Topics and subscriptions

The v0.8 topic layer deliberately does not replace queues. A `QueueTopicDefinition` owns a named publication namespace, ACL and security domain; `QueueTopicSubscription` objects wire matching publications to ordinary queue destinations. Consumers therefore continue to use the existing queue GET/CLAIM/ACK/NACK/UOW semantics.

Topic roots and concrete publication strings contain no wildcard characters. Subscription patterns are relative to the named topic root: `+` matches exactly one hierarchy level, while `#` matches zero or more levels and must be the final pattern level. For example, beneath topic root `orders`, pattern `uk/+` matches `orders/uk/new` but not `orders/uk/new/priority`; pattern `#` matches the root and all descendants.

```rexx
topics = .QueueTopicFabric~new(manager)
ignore = topics~defineTopic("ORDERS", "orders", "PERMANENT", "APP", "admin")
ignore = topics~grantTopicAccess("ORDERS", "producer", .QueueTopicAccess~PUBLISH, "admin")
ignore = topics~subscribe("UK", "ORDERS", "uk/+", "ORDER.UK", "PERMANENT", "admin")

options = .table~new
options["subtopic"] = "uk/new"
options["persistent"] = .true
publishResult = topics~publish("ORDERS", payloadObject, options, "producer")
```

Publish fan-out is atomic by default. The topic fabric stages one UOW PUT per currently matching subscription, then the queue manager preflights all destinations/capacity/security/persistence constraints before mutation. If one destination cannot accept the publication, none of the fan-out is committed.

A subscription is wiring authority, not merely a read filter. Creating one requires `SUBSCRIBE` on the named topic and `MANAGE` on its destination queue. Cross-security-domain subscriptions require the explicit `allowCrossDomain` option and manager-admin authority. The topic fabric registers a queue-reference guard through the manager messaging seam, so a subscribed queue cannot be deleted until the subscription is removed.

Retained publications are one current value per concrete topic string. A new subscription may request retained replay (the default). Retained state can be temporary or durable according to its topic lifecycle. For a permanent topic, retained graph bytes are encoded by the queue graph codec; if subscriber delivery is also persistent, subscriber `PPUT` rows and `TOPICRETAIN` are placed inside the **same** `UOWCOMMIT`, which is itself one authenticated journal record when QAUTH2 protection is enabled. Durable retained broker-state extensions require the topic fabric broker principal to be the queue-manager admin; a custom non-admin broker receives `BROKER_ADMIN_REQUIRED_FOR_DURABLE_RETAIN` rather than an implicit privilege escalation.

A PERMANENT subscription requires both a PERMANENT topic and PERMANENT destination queue. This does **not** change publication persistence: a non-persistent publication delivered through a durable subscription remains non-persistent queue work and therefore does not reappear after restart.

NoSQLServer v0.73 adds read-only snapshots:

```text
mq_topics
mq_topic_subscriptions
mq_retained_publications
mq_topic_grants
mq_topic_traffic
```

`PUBLISH` does not imply `BROWSE`; `BROWSE` does not expose grant rows, which require topic `MANAGE`. Arbitrary payload objects remain outside SQL flattening.

## Distributed topic interest and publication

`QueueDistributedTopicFabric` adds broker-to-broker topic wiring without changing the consumer primitive. Each configured peer maps a local named topic to a remote named topic and names two existing remote-queue definitions: one for interest-control messages and one for remote publications.

A broker advertises **interest**, not individual subscribers. An advertisement contains a relative topic pattern, the manager where that interest originated, and the manager path it has traversed. A manager aggregates its local subscriptions with downstream advertisements and forwards the aggregate to its other peers. Split-horizon/path checks prevent an advertisement from being reflected to a manager already in its path. Withdrawals are simply newer revisioned snapshots with the relevant advertisements absent.

For example, if C is the only broker with an application subscription and C advertises `eu/#` to B, B can advertise that downstream interest to A. A then sends one remote publication to B, B performs its own local matching and stages at most one downstream publication to C, and C performs the final local fan-out. Fifty matching subscriptions at C still cost A one remote broker publication.

Publication fan-out remains locally transactional rather than pretending to be distributed XA. On the source broker, the normal topic UOW stages local subscriber PPUTs, retained state and **one `QueueTopicDistributionWork` package per interested remote manager**. The distribution queue is ordinary queue work and therefore gets the existing persistence, TTL, CLAIM/ACK, backpressure and crash-redelivery semantics. `pumpDistribution()` later hands that work to the existing remote queue/channel layer.

On the receiving broker, `QueueRemoteTopicPublication` is consumed from the publication ingress queue. The broker validates destination manager, peer/topic mapping, security domain and manager path. It then publishes locally with the original publication ID and adds a `DTPUBRECEIPT` broker row to the same local UOW. Persistent subscriber PPUTs, local `TOPICRETAIN` and `DTPUBRECEIPT` therefore commit together. If the ingress package is redelivered after a crash, the recovered receipt suppresses a second local fan-out.

Retained-state handoff follows interest. Applying a new remote-interest snapshot stages matching retained publications into the same local distribution queue; it does not copy broker state through a hidden side channel. TTL remaining at the source distribution queue is carried forward when the remote publication is staged.

Persistent distribution/control/publication objects are custom graph-codec types. **Register those factories before queue-manager recovery** when a permanent store may contain them:

```rexx
codec = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codec)
manager = .ObjectQueueManager~new(storeRoot, codec, "admin")
```

The distributed topic NoSQL adapter adds:

```text
mq_topic_peers
mq_remote_topic_interests
mq_topic_interest_advertisements
mq_topic_distribution_receipts
mq_distributed_topic_traffic
```

This is **broker-local atomicity plus durable store-and-forward**, not distributed XA. Network delivery remains at-least-once; queue transfer receipts and distributed publication receipts provide idempotent insertion/republication at their respective boundaries.

## Distributed queue-manager wiring

The v0.5 channel layer deliberately follows the useful part of IBM MQ's wiring model without becoming an IBM MQ compatibility implementation. Applications PUT to a **remote queue definition**. That definition selects a transmission queue and sender channel; the object is stored locally first and transmitted later.

Reference setup:

```rexx
transport = .QueueInProcessTransport~new
qa = .ObjectQueueManager~new(storeA, .QueueGraphPayloadCodec~new, "admin")
qb = .ObjectQueueManager~new(storeB, .QueueGraphPayloadCodec~new, "admin")

ignore = qa~createQueue("XMIT.B", "PERMANENT", "WIRE", 100, "admin")
ignore = qb~createQueue("INBOX", "PERMANENT", "WIRE", 100, "admin")
ignore = qb~grant("INBOX", "wire-b", .QueueAccess~PUT, "admin")

fa = .QueueChannelFabric~new("QM.A", qa, transport, "admin")
fb = .QueueChannelFabric~new("QM.B", qb, transport, "admin")
ignore = transport~registerEndpoint("QM.B", fb)

ignore = fa~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 0, "PERMANENT", "admin")
ignore = fb~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "PERMANENT", "admin")
ignore = fa~startSenderChannel("A.TO.B", "admin")
ignore = fb~startReceiverChannel("A.TO.B", "admin")
ignore = fa~defineRemoteQueue("B.INBOX", "INBOX", "QM.B", "XMIT.B", "A.TO.B", "WIRE", "PERMANENT", "admin", "admin")
ignore = fa~grantRemotePut("B.INBOX", "producer", "admin")

putResult = fa~put("B.INBOX", payloadObject, options, "producer")
ignore = fa~pump("A.TO.B", 0, "admin")
```

Sender failure semantics are intentionally conservative. If the remote manager is absent, the receiver channel is stopped, the destination is full, or remote acceptance otherwise fails, the claimed XMIT package is `RELEASE`d back to READY and the sender enters `RETRYING` (or `STOPPED` when a configured retry limit is reached). The source package is not destructively removed merely because a network attempt was made.

On success, the receiver calls `acceptTransfer()`. Persistent acceptance writes a `TRANSFERACCEPT` record containing both the destination `PPUT` state and the durable transfer receipt. If the sender later retransmits the same `transferId` because its acknowledgement was lost, the receiver returns the historical receipt and does not insert a second package. Transfer IDs are manager-global: reusing an existing ID for a different destination or source manager is a conflict, not a duplicate.

This is **idempotent insertion / at-least-once transport**, not a distributed XA transaction. A receiver receipt is retained after the destination package is consumed so later retransmission can still be suppressed. v0.5 does not yet implement receipt retention/compaction policy; long-lived installations must account for that durable metadata growth.

Sender/receiver definitions and remote queue definitions may be TEMPORARY or PERMANENT. Permanent sender channels require a permanent transmission queue. Permanent definitions and their explicit running/stopped/paused state are journalled. Runtime counters such as sent/retry/rejected counts are observational and are not claimed as durable accounting records.


## Authenticated TCP transport

`QueueSocketClientTransport` implements the existing channel transport contract, so `QueueChannelFabric~pump()` does not know whether delivery is in-process or over TCP. The receiver is `QueueSocketListener`; accepted `.Socket` instances are wrapped as `.StreamSocket` objects and all network I/O is expressed as messages to those objects.

The v0.9-dev5 `queue.transport/2` protocol uses a new TCP connection for each delivery or health probe. The listener first obtains the accepted socket's numeric peer address and rejects it unless it is in the configured trusted-peer allowlist. Only then does the client/server perform the HMAC-authenticated HELLO/challenge exchange. Both fresh nonces and the authenticated peer transcript feed a connection KDF that yields separate directional ChaCha20 encryption keys, HMAC-SHA-512 authentication keys and nonces. DELIVER/PROBE and RESULT/HEALTH bodies are encrypted and then MACed; receivers verify the MAC before decryption. A captured secure frame cannot simply be replayed into a fresh session because the connection keys change. If the same logical `transferId` is intentionally retransmitted through a new authenticated session, the existing durable receiver receipt suppresses duplicate insertion.

`QueueSocketFramer` prefixes every frame with an 8-hex-digit byte length, defaults to an 8 MiB maximum, reads exactly the declared number of bytes and loops on partial writes. This avoids unbounded newline framing and avoids assuming one socket send transmits the complete frame.

The transport intentionally does not persist endpoint transport keys in the queue journal. Endpoint/peer provisioning is configuration authority. NoSQL projects key identifiers and operational counters, never the key bytes. `keyId` remains an identifier rather than authority; production wiring should obtain raw key material through Secret Broker by reference. `queue.transport/2` requires at least a 256-bit transport PSK. Exact IPv4 source-address admission is qualified in dev5; IPv6 textual canonicalisation is not yet a qualification claim.

The first-party source gate also enforces several ooRexx-specific rules: no `CALL object~message`, no ordinary `RESULT = ...`, no `self~attribute = value` pseudo-field assignments, and no raw `Sock*()` calls in queue classes. The shared `crypto.cls` is tested in its own package and is not vendored here.

## Durable store and authentication

A manager with `storeRoot` uses:

```text
<storeRoot>/queue.journal
<storeRoot>/traffic.log
```

Without a protector, records use the plaintext line-oriented queue record format. With `QueueHmacSha512RecordProtector`, every durable line is wrapped in `QAUTH2`, chained and authenticated before replay.

HMAC key rotation and Ed25519 checkpoint key-ring semantics are unchanged from v0.3. Historical keys must remain available while historical records requiring them remain in the journal.

`STRICT` recovery rejects malformed/authentication-failing records and an unterminated final physical record. `REPAIR_TORN_TAIL` may repair only the physically unterminated final record; interior or terminated corruption remains fatal. Repair/normalisation is surfaced through `manager~recoveryWarnings`.

Hash chaining and embedded checkpoints cannot by themselves detect replacement of the **entire store** by an older internally valid copy. That threat still requires an externally retained chain/checkpoint head.

## Compatibility

v0.8 retains replay compatibility with the accepted v0.7 queue/channel/transport/topic record surface. v0.8 adds distributed-topic records (`DTPEER`, `DTPEERDELETE`, `DTTXREV`, `DTINTEREST`, `DTPUBRECEIPT`) and persistent distributed payload types. A v0.7 store containing permanent queues, local topics/subscriptions and retained nested object graphs has been written by the exact released v0.7 source and replayed successfully under v0.8.

The v0.9 aggregate API promotion does not introduce a new queue-journal or graph-payload encoding. dev5 retains the bilateral exact-source v0.8.2 durable compatibility fixtures: ordinary and QAUTH2/HMAC stores written by v0.8.2 replay under v0.9, and ordinary and QAUTH2/HMAC stores written by v0.9 replay under the exact accepted v0.8.2 source. This is a deliberately narrow persistence claim; it does not pretend that a v0.8.2 runtime understands the new v0.9 broker-service API.

Downgrade remains unsupported after v0.8 distributed-topic records or persistent distribution payloads have been written. **Do not downgrade a store after distributed-topic wiring has been activated.**

## Running tests

```sh
OOREXX_BIN=/path/to/oorexx/bin \
CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src \
NOSQL_SRC=/path/to/nosqlserver_v0.77/src \
RUNTIME_REGISTRY_SRC=/path/to/runtime_registry_v0.12/src \
ALCHEMY_OBJECTS_SRC=/path/to/alchemy_objects_v0.5/src \
WLU_SRC=/path/to/oorexx_work_load_units_v0.6/src \
QF_V082_SRC=/path/to/oorexx_queue_fabric_v0.8.2/src \
./run_tests.sh core
```


The v0.9 development-specific stages are deliberately separate:

```sh
./run_tests.sh service
./run_tests.sh registry
./run_tests.sh wlu
./run_tests.sh compatibility
./run_tests.sh compile
./run_tests.sh release-boundary
```

`compatibility` performs four exact-source replays using the accepted v0.8.2 core supplied through `QF_V082_SRC`: plaintext and QAUTH2/HMAC in each direction. Individual directions are also exposed as `compat-v082-v09`, `compat-v082-v09-auth`, `compat-v09-v082`, and `compat-v09-v082-auth` for independently bounded Autobuild evidence.

Topic-only semantic/NoSQL tests may also be run with:

```sh
./run_tests.sh topics
```

Distributed-topic interest/fan-out/recovery/NoSQL/socket tests are a distinct stage:

```sh
./run_tests.sh distributed-topics
```

Crypto tests are separated because the shared pure-ooRexx SHA-512/Ed25519 reference code is intentionally expensive under the supplied debug build:

```sh
./run_tests.sh crypto
./run_tests.sh crypto-known-answer
./run_tests.sh crypto-hmac
./run_tests.sh crypto-checkpoint
./run_tests.sh crypto-rotation
./run_tests.sh crypto-recovery
./run_tests.sh crypto-keyring
./run_tests.sh crypto-uow
./run_tests.sh crypto-channel
./run_tests.sh crypto-topic
./run_tests.sh crypto-distributed-topic
```

Transport can likewise be split into `transport-core`, `socket-transport`, `socket-security`, and `socket-health`. The aggregate `transport` mode remains for ordinary developer use.

Validated inherited baseline plus v0.8 topic results:

```text
retained functional acceptance       62 assertions
retained adversarial acceptance      71 assertions
concurrency                           packaged default remains 2000/2000; current constrained-container probe 200/200/0 duplicates
MQ lifecycle/UOW semantics            141 assertions
MQ NoSQL projection                   24 assertions
distributed channels                  85 assertions
distributed NoSQL projection          38 assertions
topic/pub-sub semantics                135 assertions
topic NoSQL projection                  44 assertions
distributed topics                       84 assertions
distributed topic multihop               87 assertions
distributed topic recovery               66 assertions
distributed topic NoSQL                  57 assertions
distributed topic authenticated TCP       6 assertions
bundled SHA-512 / RFC8032 KAT         PASS
HMAC durability                       20 assertions
HMAC key rotation                     16 assertions
torn-tail recovery                    20 assertions
Ed25519 checkpoint                     6 assertions
checkpoint key ring                   11 assertions
authenticated durable UOW             13 assertions
authenticated distributed transfer     17 assertions
bounded socket framing                    6 assertions
transport NoSQL                           27 assertions
three-process socket transport             6 assertions
socket security scenarios                  PASS (wrong-key, replay, backpressure, forged result)
```

## Design constraints intentionally retained

1. **Objects stay objects.** Payload identity is not replaced by implicit stringification.
2. **Flatten only at explicit boundaries.** SQL receives metadata projections; the fabric remains object-native.
3. **Manager owns envelope mutation.** A returned queue/package/UOW reference does not grant state-transition authority.
4. **Durability is enforceable.** Permanent queues and durable UOWs cannot silently degrade into process-local semantics.
5. **Trigger wiring and executable implementation are separate authorities.**
6. **Crash recovery favours visible redelivery over hidden stranded work.**
7. **Remote redelivery is explicit and idempotent.** A sender may retry; a persistent receiver receipt prevents duplicate insertion for the same transfer identity.
8. **Transport identity is not invented.** The in-process transport is a seam/test implementation, not a cryptographic network channel.
9. **ooRexx semantics win over language analogy.** Internal arrays are rebuilt densely after removals; high-resolution time arithmetic explicitly raises `NUMERIC DIGITS`; methods are messages, not field writes.
10. **Topics route to queues; they do not replace them.** Consumer delivery semantics remain queue semantics, while topic objects own matching and fan-out wiring.
11. **Durable broker state is explicit authority.** Retained-state and distributed-receipt journal extensions require manager-admin broker authority rather than silently escalating a custom broker principal.
12. **Remote interest is aggregated broker state, not cloned application subscriptions.** One matching remote manager means one distribution intent regardless of downstream subscriber count.
13. **Distributed atomicity stops at the broker boundary.** Each manager commits its own UOW and relies on durable store-and-forward plus idempotent receipts between managers.


## Shared crypto dependency (v0.8.2)

Queue Fabric no longer carries a private `src/crypto.cls`. `QueueHmacSha512` is retained as a compatibility facade but delegates to `.HMACSHA512` from `oorexx_crypto_v0.1`; Ed25519/SHA-512 likewise resolve from that package. This removes the historical three-copy crypto maintenance problem.
