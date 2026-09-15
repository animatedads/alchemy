# Changelog

## v0.9-dev5

- Advances the remote socket wire identity from `queue.transport/1` to `queue.transport/2`; durable queue, transmission-envelope, distributed-topic and QAUTH2 record identities remain unchanged.
- Makes source-address admission mandatory for socket peers. `QueueSocketListener` checks the numeric accepted peer address against the aggregate allowlist before reading HELLO, then checks the selected peer-specific allowlist again before cryptographic authentication.
- Restricts the application allowlist to canonical dotted-quad IPv4 and rejects CIDR, hostnames, IPv6, leading-zero forms, out-of-range octets and `0.0.0.0`. Re-registering a peer rebuilds the aggregate allowlist so removed addresses cannot remain admitted to the pre-authentication stage.
- Adds `ipRejectedCount` and `lastPeerAddress` listener evidence without treating an IP address as an identity credential.
- Requires transport PSKs of at least 256 bits and derives fresh per-connection directional keys from the PSK, authenticated peer transcript and independent 256-bit client/server nonces.
- Encrypts DELIVER/PROBE and RESULT/HEALTH bodies with ChaCha20 and authenticates ciphertext using a separately derived HMAC-SHA-512 key (encrypt-then-MAC, MAC verified before decryption). HELLO/CHALLENGE metadata remains authenticated but visible.
- Deliberately does not use the project X25519 surface for this release because its documented semantics are not the standards-clamped X25519 protocol. The PSK transport therefore makes no forward-secrecy claim.
- Adds secure-session tamper/direction tests and a socket-security case proving a peer with the correct key but the wrong source IP is rejected before authentication and before queue mutation.
- Qualifies the secure socket path on the supplied ooRexx 5.3.0 r13196 build with the supplied Foreign Runtime v0.22.6/OpenSSL acceleration path.
- Adds `SECURE_TRANSPORT.md` with the two-layer OCI deployment rule: restrict the Queue Fabric port at the OCI NSG/security layer and repeat the exact peer-IP rule inside Queue Fabric.
- Keeps Job-to-Node Allocator placement authority separate. Deployments may advertise a hard ability such as `QUEUE_SECURE_TRANSPORT_V2`; encryption/key ownership remains Queue Fabric/Secret Broker responsibility.

## v0.9-dev4

- Promotes `QueueFabricBuild` to `VERSION 0.9` / API `queue.fabric/0.9`. This is the aggregate package/API boundary for the broker operational lifecycle added on the v0.9 line.
- Keeps all existing durable and wire identities unchanged: `queue.fabric.transmission-envelope/1`, `queue.fabric.topic-interest/1`, `queue.fabric.topic-distribution-work/1`, `queue.fabric.remote-topic-publication/1`, `queue.auth.record/2`, `queue.auth.checkpoint/1`, and `queue.transport/1`.
- Adds `test_queue_release_boundary.rex` to lock the distinction between aggregate API version and persistent/wire format versions.
- Adds reverse durable compatibility fixtures proving v0.9-created ordinary and QAUTH2/HMAC state is readable by the exact accepted v0.8.2 source. Existing v0.8.2 -> v0.9 ordinary and authenticated replay remains.
- Updates Queue Fabric NoSQL manager projections/tests to report aggregate version `0.9`.
- Retains the Alchemy Objects v0.5 common-base adoption on long-lived runtime authorities while keeping durable graph/value records such as `QueueWorkPackage` and `QueueTransmissionEnvelope` outside `AlchemyObject`.
- Retains broker lifecycle, Runtime Registry v0.12 generation integration, WLU v0.6 pre-CLAIM admission, authenticated heartbeat, conservative ordered endpoint failover, and NoSQLServer v0.77 operational projection behavior from dev2/dev3.
- Adds an `alchemy.autobuild.integration/0.3` artifact-only candidate manifest with deterministic current dependency roots. Crypto-heavy, socket-security and each compatibility direction are separable so pure-ooRexx debug-runtime cost is visible per test rather than hidden inside one monolithic timeout.
- Adds matching granular `run_tests.sh` modes for transport, bilateral compatibility and each authenticated crypto stage; the historical aggregate modes remain available.
- Remains a development/release-candidate cut until the full v0.9 acceptance matrix and authoritative Alchemy Autobuild PASS/receipt are obtained.

## v0.9-dev2

- Revalidates the v0.9 work against `oorexxapis(6).zip` (SHA-256 `af5e121c516015319e14e806599269e0868f0011e9cfc8444b7334e64cbde4b9`) with Queue Fabric v0.8.2, Alchemy Objects v0.5, Work Load Units v0.6, NoSQLServer v0.77 and Runtime Registry v0.12.
- Keeps the inherited queue runtime identity at `VERSION 0.8` / `queue.fabric/0.8` during development; persistent/wire formats are not prematurely relabelled.
- Advances the broker operational API to `queue.broker.service/0.2`.
- Adds authenticated `PROBE` / `HEALTH` traffic to the existing `queue.transport/1` HMAC-authenticated session without mutating queue state.
- Adds ordered endpoint groups and conservative failover: connect/unavailable transport failures may advance to the next endpoint; authentication, protocol and authenticated application failures do not silently fail over.
- Adds per-endpoint health attempt/success/failure evidence and listener probe counts.
- Extends the narrow broker admission-policy boundary with separate `admitHeartbeat(...)` / `completeHeartbeat(...)` messages so health traffic can be metered independently.
- Updates `QueueBrokerWLUAdmission` for Work Load Units v0.6. WLU denial still occurs before queue CLAIM/transport side effects, and heartbeat denial occurs before any network probe.
- Adds `QueueBrokerServiceNoSQLAdapter` for service, retry and WLU operational projections and extends transport projections for ordered endpoints and health evidence. Key identifiers remain observable; HMAC key material is not projected.
- Verifies `QueueBrokerAdmissionPolicy`, `QueueBrokerService` and `QueueBrokerWLUAdmission` through Alchemy Objects v0.5 `AlchemyAdoptionVerifier` at STANDARD readiness.
- Retains Runtime Registry v0.12 generation lifecycle integration and the corrected drain quiet-cycle semantics from dev1.
- Retains exact v0.8.2 writer -> v0.9-dev2 durable nested-object replay evidence.
- Adds authenticated health/failover, failover-NoSQL, heartbeat-WLU, service-NoSQL and Alchemy-adoption fixtures.
- This remains a development cut. Broad common-base migration of accepted long-lived queue/channel/topic classes, final authenticated compatibility coverage, clean release manifest and authoritative Alchemy Autobuild PASS remain open.

## v0.8.2

- Removes vendored `src/crypto.cls` and declares standalone `oorexx_crypto_v0.1` as the single crypto implementation.
- `QueueHmacSha512` now delegates to shared `.HMACSHA512` / `.CryptoUtils` while preserving the Queue Fabric API and on-disk authentication semantics.
- Queue crypto known-answer tests remain as consumer integration tests; the complete primitive/vector battery now belongs to the crypto package.
- Test runner requires `CRYPTO_SRC`/`OOREXX_CRYPTO_SRC`, preventing accidental use of a stale crypto copy.

# Object Queue Fabric changelog

## v0.8.1

- Test-only repair; runtime/API remains `queue.fabric/0.8` and first-party runtime source is unchanged from v0.8.
- Fixes `tests/test_queue_distributed_topic_crypto.rex` line 54 to query the existing `QueueHmacSha512RecordProtector~authenticatedRecords` attribute instead of the nonexistent `~protectedRecords` message.
- The existing HMAC durability fixture already uses `~authenticatedRecords`; no crypto/runtime compatibility shim was added.
- User-side v0.8 full-suite evidence reached this fixture after passing full 2000/2000/0 concurrency, all inherited semantics/transport stages, crypto known-answer tests, HMAC durability/rotation/recovery/checkpoint tests, authenticated UOW/channel, and authenticated topic 22/22; execution then stopped solely with Error 97.1 on the bad test message.

## v0.8

- Adds native distributed pub/sub through `QueueDistributedTopicFabric`; queues remain the delivery primitive and local `QueueTopicFabric` remains the matching/fan-out authority.
- Adds configured distributed topic peers mapping a local named topic to a remote named topic through existing control/publication remote-queue definitions.
- Adds revisioned, path-carrying subscription-interest advertisements. Brokers aggregate local subscriptions with downstream interest instead of propagating individual application subscriptions.
- Adds multi-hop interest propagation and withdrawal with split-horizon/path suppression; validated A <- B <- C interest and A -> B -> C publication with C as the only application subscriber.
- Stages exactly one `QueueTopicDistributionWork` package per matching remote manager in the same source UOW as local subscriber fan-out and retained state.
- Reuses existing remote queues, transmission queues, sender/receiver channels and socket transport for actual inter-manager control/publication delivery.
- Adds `QueueRemoteTopicPublication` with origin/publication identity and manager path; receiving brokers perform local fan-out and may stage one downstream copy per interested peer.
- Adds durable `DTPUBRECEIPT` broker state. Persistent local subscriber PPUTs, local `TOPICRETAIN` and `DTPUBRECEIPT` share one receiver-side `UOWCOMMIT`, so restart/redelivery does not refanout a publication.
- Adds retained-publication handoff when new remote interest appears, using the same durable distribution queue rather than an out-of-band retained-state copy.
- Adds persistent graph-codec types for interest snapshots, distribution work and remote topic publications; `QueueDistributedTopicSupport~registerTypes(codec)` supports required pre-recovery registration.
- Adds durable distributed-peer definitions, transmit revision state, received interest snapshots and publication receipts.
- Adds `mq_topic_peers`, `mq_remote_topic_interests`, `mq_topic_interest_advertisements`, `mq_topic_distribution_receipts` and `mq_distributed_topic_traffic` NoSQLServer v0.73 projections.
- Adds two-broker, multi-hop, durable recovery, NoSQL and real authenticated-socket distributed-topic acceptance fixtures, plus an authenticated distributed receiver UOW fixture.
- Adds `examples/distributed_topic.rex`.
- Confirms the exact released v0.7 source can write a permanent local topic/subscription/retained nested-object store that v0.8 replays correctly.
- Extends the executable ooRexx message-style gate to all 11 first-party queue classes; bundled `crypto.cls` remains byte-preserved/exempt.
- Does **not** claim distributed XA or exactly-once networking. Each broker commits locally; store-and-forward plus durable queue-transfer and distributed-publication receipts provide idempotent boundaries.

## v0.7

- Adds object-native topic publish/subscribe while retaining queues as the delivery primitive.
- Adds named topic definitions with independent ACLs, security-domain roots and TEMPORARY/PERMANENT lifecycle.
- Adds hierarchical `/` topic matching: `+` matches exactly one level and terminal `#` matches zero or more levels.
- Adds TEMPORARY/PERMANENT subscriptions wired to ordinary queue destinations; subscription creation requires topic SUBSCRIBE plus destination queue MANAGE authority.
- Adds explicit admin-authorised cross-domain subscriptions.
- Adds atomic default fan-out through the existing queue-manager UOW preflight/commit path.
- Adds retained publications, retained replacement, expiry through the queue time-source abstraction, explicit clear, and immediate retained replay to new subscriptions.
- Persistent subscriber `PPUT` rows and persistent `TOPICRETAIN` state are committed in the same `UOWCOMMIT` journal envelope.
- Adds generic manager queue-reference guards; topic subscriptions prevent deletion of a referenced queue until unwired.
- Durable retained UOW extension rows require manager-admin broker authority; custom non-admin broker principals fail with `BROKER_ADMIN_REQUIRED_FOR_DURABLE_RETAIN`.
- Durable subscriptions do not upgrade non-persistent publications to persistent packages.
- Adds durable recovery for topic definitions, ACL grants/revocations, subscriptions, retained state and deletion/clear operations.
- Adds `mq_topics`, `mq_topic_subscriptions`, `mq_retained_publications`, `mq_topic_grants` and `mq_topic_traffic` NoSQLServer v0.73 projections.
- Adds topic/pub-sub acceptance, topic NoSQL acceptance and authenticated retained+fanout UOW acceptance fixtures.
- Adds `examples/topic_queue.rex`.
- Retains the v0.6 authenticated TCP transport protocol `queue.transport/1` unchanged.
- Full user-side `run_tests.sh` acceptance passed, including 2000/2000/0 concurrency and authenticated topic 22/22.

## v0.6

- Adds real inter-process TCP delivery through `QueueSocketClientTransport` and `QueueSocketListener`, while retaining the v0.5 `QueueChannelFabric` transport contract.
- Uses the official ooRexx `Socket` / `StreamSocket` classes; first-party queue code contains no raw `Sock*()` calls.
- Adds `QueueSocketFramer`: 8-hex-digit bounded length prefix, exact reads, maximum-frame enforcement, and looping partial-write handling.
- Adds HMAC-SHA-512 client HELLO authentication before server challenge generation.
- Server challenge, delivery request, and result frames are also HMAC-authenticated.
- Authentication binds source manager, destination manager, receiver channel, claimed principal, key ID, client nonce, server nonce, and exact graph-codec envelope bytes.
- Retains one delivery request per TCP connection so reconnect is explicit and the channel remains responsible for store-and-forward/retry.
- Confirms duplicate logical transfer across fresh TCP connections is suppressed by the durable receiver transfer receipt.
- Confirms wrong-key traffic cannot reach `ObjectQueueManager~acceptTransfer()`.
- Confirms authenticated remote backpressure releases the local transmission claim to READY with `deliveryCount` incremented and application `backoutCount` unchanged.
- Adds `mq_transport_endpoints` and `mq_transport_listeners` NoSQLServer v0.73 projections; key identifiers are visible to administrators but HMAC key bytes are never projected.
- Repairs `QueueChannelNoSQLAdapter~snapshotInto()` composition so already-snapshotted object tables are not incorrectly treated as live collection storage.
- Adds public `QueueHmacSha512` message object and reuses it for durable journals and transport authentication; cross-implementation HMAC fixtures remain unchanged.
- Adds an executable ooRexx message-style gate for first-party source: no `CALL object~message`, ordinary `RESULT =`, `self~attribute = value`, or raw socket routines.
- Renames the inherited `result` local in `receiveEnvelope()` to `acceptResult`, avoiding ooRexx special-variable ambiguity.
- Validated against the current project bundle baselines NoSQLServer v0.73 and Runtime Registry v0.8.
- Confirms a persistent nested-object store written by the bundled v0.5 source replays under v0.6.
- Wire transport v0.6 provides authentication/integrity only; it deliberately makes no confidentiality/TLS claim.

## v0.5

- Adds MQ-style distributed queue-manager wiring without claiming IBM MQ protocol compatibility.
- Adds persistent `QueueTransmissionEnvelope` as a built-in graph-codec domain type so permanent transmission queues recover before channel-facade construction.
- Adds remote queue definitions mapping an application alias to remote manager/queue, transmission queue and sender channel.
- Adds named sender channels with STOPPED/RUNNING/RETRYING/PAUSED state, configurable retry limit, store-and-forward pumping and runtime counters.
- Adds named receiver channels binding expected source manager and inbound principal before destination queue ACL/security checks.
- Adds `ObjectQueueManager~release()` and RELEASE triggers so transient transport retry returns a claim to READY without incrementing application `backoutCount`.
- Adds `ObjectQueueManager~acceptTransfer()` with manager-global transfer IDs and conflict detection.
- Persistent transfer acceptance journals destination package insertion plus durable transfer receipt as one `TRANSFERACCEPT` record before live mutation.
- Duplicate redelivery returns the historical transfer receipt without a second queue insertion, including after receiver restart and after the original package has later been consumed.
- Adds permanent sender/receiver/remote-queue definition journalling and restart recovery.
- Adds `QueueInProcessTransport` as an explicit reference/test transport seam; it does not claim network authentication or confidentiality.
- Adds `mq_transfer_receipts`, `mq_sender_channels`, `mq_receiver_channels` and `mq_remote_queues` NoSQLServer v0.82 projections with restricted channel visibility.
- Adds distributed channel, distributed NoSQL and authenticated-transfer acceptance suites.
- Retains the v0.4 TTL/backout/DLQ/UOW semantics and the existing HMAC/Ed25519 durable-record model.

## v0.4

- Adds per-package TTL with `expirySeconds`, persisted expiry metadata, explicit `sweepExpired()`, and automatic lazy expiry on depth/browse/get/claim paths.
- Adds queue `expiringDepth` and `earliestExpiryTick` watermarks so non-expiring/future-expiry queues avoid repeated full TTL scans.
- Adds manager-configured dead-letter queue with durable configuration and same-security-domain disposition rules.
- Adds explicit `backoutCount`, queue backout threshold/target configuration, durable recovery of that configuration, and optional fallback to the manager DLQ.
- `NACK` and UOW rollback increment backout count; threshold movement preserves the same work-package/payload object graph.
- Adds EXPIRE, BACKOUT, DEAD_LETTER, UOW_COMMIT and UOW_ROLLBACK trigger kinds.
- Adds authority-bound `QueueUnitOfWork` with `beginUnitOfWork`, `uowGet`, `uowPut`, `commitUnitOfWork` and `rollbackUnitOfWork`.
- UOW GETs reserve messages under an internal `UOW:<id>` claim identity; ordinary ACK cannot escape the transaction.
- UOW PUTs honour existing routing rules and transaction commit preflights all destinations/security/persistence requirements against the net queue-depth effect.
- Durable UOW state is encoded into one `UOWCOMMIT` journal record before live mutation; authenticated storage wraps the entire committed unit in one `QAUTH2` record.
- Adds durable v0.4 package fields for expiry, backout and disposition while retaining replay compatibility with v0.3 PPUT/PSTATE rows.
- Adds `mq_manager` and new NoSQL queue/package fields for DLQ, UOW, expiry, backout and disposition metadata.
- Prevents deletion of queues still referenced as a backout target or manager DLQ.
- Confirms v0.4 replays a durable store written by the actual v0.3 source. Downgrade after v0.4-only records is explicitly unsupported.
- Retains bundled `crypto.cls` byte-for-byte and all v0.3 authenticated-journal/key-rotation/checkpoint/recovery semantics.

## v0.3

- Retains the v0.2 `QAUTH2` durable-record envelope and SHA-512 chain format.
- Adds HMAC key rotation to `QueueHmacSha512RecordProtector`:
  - new records use the active key ID;
  - historical key IDs remain independently trusted for replay;
  - a key ID cannot be rebound to different key material;
  - `knownKeyIds` exposes identifiers only.
- Adds `QueueEd25519CheckpointKeyRing` so historical checkpoint public keys can remain trusted while a new checkpoint key becomes active.
- Required checkpoint writes now fail if the configured authority is verify-only instead of silently omitting the signature.
- Adds explicit durable-store recovery modes:
  - `STRICT` (default), which rejects malformed/authentication-failing or physically unterminated final records;
  - `REPAIR_TORN_TAIL`, which repairs only an unterminated final physical record and records a recovery warning.
- A malformed unterminated final fragment is removed in repair mode; a complete authenticated final record merely missing its line terminator is preserved and normalised.
- Appends refuse to proceed against an existing unterminated store, preventing concatenation after a framing defect.
- Adds key-rotation, torn-tail recovery and checkpoint-key-ring acceptance tests.
- Confirms v0.3 can replay an authenticated journal written by v0.2 without changing its record format.
- Continues to bundle `src/crypto.cls` byte-identically to the supplied/Runtime Registry copy.

## v0.2

- Adds an optional durable-record protection seam to `QueueDurableStore`.
- Bundles the exact `crypto.cls` used by Runtime Registry v0.3.
- Adds `QueueHmacSha512RecordProtector`:
  - SHA-512 record chain;
  - HMAC-SHA-512 authentication of each durable record;
  - fail-closed recovery on wrong key, mutation, malformed records, sequence gaps or interior deletion.
- Adds `QueueEd25519CheckpointAuthority` for periodic public-key chain anchors.
- Deliberately avoids Ed25519 on every queue traffic record; pure-ooRexx curve arithmetic is appropriate as a reference/audit path, not a per-message MQ throughput primitive.
- Adds independent SHA-512 / RFC 8032 Ed25519 known-answer tests.
- Adds cross-implementation HMAC fixture, queue restart/tamper tests and Ed25519 checkpoint tests.
- Retains the v0.1 object queue, routing, trigger, ACL, persistence, NoSQL and concurrency semantics.

## v0.1

Initial executable object-native queue fabric.
