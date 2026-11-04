# ConnectSelector 0.1-dev2

**Public contract:** `oorexx.connect_selector/0.1` — application-level communication selection.

ConnectSelector makes the **interconnect decision**. The caller describes an operation, required semantics and an optional destination; it never has to import a socket, queue or RPC implementation. An application may register native DirectCall, standalone JSON-RPC and/or durable QueueFabric adapters. All are peers; QueueFabric is not a dependency of DirectCall or JSON-RPC.

A choice is made **before** invocation. After an invocation begins, an ambiguous result or exception is **never** silently retried on another provider.

| Provider | Supported modes | Qualification | Not promised |
| --- | --- | --- | --- |
| `DIRECT` | `REQUEST`, `NOTIFY` | Native handler via JSON-RPC Fabric direct connector | durability, remote completion of notify |
| `RPC` | `REQUEST`, `NOTIFY` | JSON-RPC Fabric dev2 loopback and direct | durable job, guaranteed notify delivery |
| `QUEUE` | `ENQUEUE` | Real QueueFabric dev6, journal replay and acknowledgement | synchronous request/reply; persistent receipt on an in-memory queue |

## In dev2

1. `ConnectRoutePolicy` supports explicit allow/deny grants scoped by **operation, mode, provider and destination**. It defaults to strict mode (no grant, no invocation). An explicit preferred provider cannot bypass it. Denies win over grants.
2. `ConnectSelector~register(provider, adapter, destination='')` supports multiple independently bound destinations for the same provider. A named destination never resolves to an unbound/default provider. `ConnectCallAdapter(connector,provider,boundDestination='')` independently checks its binding.
3. `ConnectQueueAdapter` checks queue existence and, if offered by the manager, `accessAllowed` before declaring a route eligible. It rejects a named destination different from its configured queue, preserves QueueFabric `replyTo`, `securityDomain` and `expirySeconds` options, and only claims durability for permanent queues with an actual durable store.
4. Optional `ConnectJmsRoutes` binds authorised JMS inbound and outbound destinations. The bridge denies a forbidden JMS source **before receive** and a forbidden target **before claim**.
5. `ConnectJmsDelivery` accepts a broker-assigned `messageId` in addition to correlation and headers. The inbound bridge copies headers and writes `connect.jms.message_id` as a reserved system field, which survives QueueFabric persistence and is available on the outbound JMS leg. This provides deduplication evidence, not exactly-once delivery.
6. Executable integration with the **real** QueueFabric 0.9-dev6 persistent manager verifies a JMS-simulated input is journaled, recovered after constructing a new manager, forwarded to the JMS-simulated output, then durably acknowledged. Both JMS directions remain injected SPI ports, **not** qualified against a live JMS broker.

## API

```rexx
::requires 'ConnectSelector.cls'
::requires 'JsonRpcFabric.cls'

registry = .JsonRpcMethodRegistry~new
registry~register('catalog.lookup',myHandler)
local = .JsonRpcDirectConnector~new(registry)
remote = .JsonRpcClient~new(.JsonRpcLoopbackTransport~new(.JsonRpcDispatcher~new(registry)))

policy = .ConnectRoutePolicy~new     /* default deny */
policy~allow('catalog.lookup','request','DIRECT','LOCAL')
policy~allow('catalog.lookup','request','RPC','REMOTE')
selector = .ConnectSelector~new(policy)
selector~register('DIRECT',.ConnectCallAdapter~new(local,'DIRECT','LOCAL'),'LOCAL')
selector~register('RPC',.ConnectCallAdapter~new(remote,'RPC','REMOTE'),'REMOTE')

intent = .ConnectIntent~new('catalog.lookup','request','immediate','AUTO','REMOTE')
result = selector~execute(intent,.Array~of(.JsonString~new('item-7')))
```

To use durable QueueFabric, the application must first provision a **permanent queue** backed by a durable store and grant the named producer PUT authority. ConnectSelector does not elevate permissions or create queues:

```rexx
producer = .ConnectQueueAdapter~new(queueManager,'WORK','producer')
selector~register('QUEUE',producer,'WORK')
policy~allow('tasks.submit','enqueue','QUEUE','WORK')
receipt = selector~execute(.ConnectIntent~new('tasks.submit','enqueue','durable','AUTO','WORK'),payload)
```

### JMS ↔ QueueFabric

```rexx
routes = .ConnectJmsRoutes~new   /* default deny both directions */
routes~allowInbound('BROKER.IN')
routes~allowOutbound('BROKER.OUT')
bridge = .ConnectJmsBridge~new(jmsPort,queueAdapter,routes)
inReceipt = bridge~fromJms('BROKER.IN')
outReceipt = bridge~toJms('BROKER.OUT')
```

`jmsPort` is injected and must implement `receive(destination) -> ConnectJmsDelivery or .nil`, `ack(handle) -> Boolean`, `recover(handle) -> Boolean`, `send(destination,payload,metadata) -> Boolean`. `receive` must **not** auto-ack. A JMS port using client acknowledgement must ensure that acknowledging one handle cannot acknowledge unrelated inflight deliveries, for example through a dedicated one-inflight consumer session or transactions. JMS delivery mode/commit remains the port's responsibility.

Inbound order: receive → QueueFabric persistent PUT → JMS ack. Outbound order: QueueFabric claim → JMS send/commit → QueueFabric ack. On a failure before the second acknowledgement, the bridge seeks source recovery or queue NACK; on acknowledgement uncertainty it explicitly returns `ACK_UNCERTAIN` or `QUEUE_ACK_UNCERTAIN`. There is no XA/2PC coordination or exactly-once assertion. Production consumers must deduplicate using stable business/message IDs; JMS IDs alone may be insufficient across message reproduction or broker migration.

Never pass untrusted Java deserialized JMS objects directly to QueueFabric's graph codec; the concrete JMS port must normalise to approved message types and an allowlisted header schema. Different security domains require explicitly authorised routes. Bridge routes apply to a bridge configured with a **single concrete Queue adapter**, not a global JMS broker access wildcard.

### Mode and result distinctions

- `REQUEST`: return a response, completed when a response (or RPC error response) exists.
- `NOTIFY`: successful send is acceptance, not evidence of downstream execution.
- `ENQUEUE`: successful PUT is acceptance into a queue, not execution of queued work; request `DURABLE` only when real journal-backed persistence applies.

`ConnectResult` fields remain `ok`, `provider`, `accepted`, `completed`, `durable`, `value`, `code`, `detail`. `ConnectSelector~explain(intent)` returns a Directory with selection outcome and the full operation/mode/destination/requirement/preference used for the decision. It deliberately does not expose payloads, secrets or connector handles.

## Exact dependency roots and qualification

The classes have no mandatory QueueFabric, JSON-RPC, JMS or Socket Provider imports. `ConnectJmsBridge.cls` requires the included `ConnectSelector.cls` at the selected source path.

- ooRexx runtime: 5.3.0 r13196 (`oorexx-5.3.0-13196.ubuntu1604debug.x86_64`).
- JSON-RPC integration: `oorexx_json_rpc_fabric_v0.1-dev2/src/`.
- Queue integration: `oorexx_queue_fabric_v0.9-dev6/src/`.
- Queue manager dependencies used in integration: `alchemy_objects_v0.8.2/src/` and `oorexx_crypto_v0.8.3/src/`.
- Socket Provider remains independent (dev14 tested by JSON-RPC Fabric, not network-qualified in this selector package).

```sh
OOREXX_RUNTIME_ROOT=/exact/path/to/extracted-ooRexx \
CONNECT_JSONRPC_ROOT=/exact/path/to/oorexx_json_rpc_fabric_v0.1-dev2 \
CONNECT_QUEUE_ROOT=/exact/path/to/oorexx_queue_fabric_v0.9-dev6 \
CONNECT_ALCHEMY_ROOT=/exact/path/to/alchemy_objects_v0.8.2 \
CONNECT_CRYPTO_ROOT=/exact/path/to/oorexx_crypto_v0.8.3 \
./tests/run.sh
```

All dependencies are explicit. The integration suite is skipped if its entire group of paths is unset; a partially defined group is an error, not an invitation to use a random dependency elsewhere in `REXX_PATH`.

### Not yet qualified

Live JMS broker/Java port, broker session transaction and redelivery, authenticated network JSON-RPC, crash interleaving across two independently failing brokers, XA/2PC or guaranteed exactly-once forwarding, service discovery or automatic lifecycle selection, and cross-process route-policy administration. Runtime exceptions raised inside an injected provider are propagated and must be treated as potentially ambiguous side effects, not as permission to retry using a different provider.

See `QUALIFICATION.txt` and `docs/ARCHITECTURE.md`.
