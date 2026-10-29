# Consuming the actual ConnectSelector 0.1-dev1 contract

Source reviewed: `oorexx_connect_selector_v0.1-dev1.zip`, published
API `oorexx.connect_selector/0.1`, `src/ConnectSelector.cls`, `README.md`,
`QUALIFICATION.txt`.

This replaces the assumption in the dev2 integration document that the native
ConnectSelector API had not yet been published. The native API has been located
and the SDK side now has an explicit binding aligned with it.

## Real ooRexx public surface

```
selector = .ConnectSelector~new
selector~register(name, connector)
selector~select(intent)
selector~explain(intent)
result = selector~execute(intent, payload)

intent = .ConnectIntent~new(operation, mode, requirement, preferred, destination, options)
```

Native `ConnectIntent` modes: `REQUEST`, `NOTIFY`, `ENQUEUE`.
Requirements: `IMMEDIATE`, `BEST_EFFORT`, `DURABLE`; durable is only legal for
ENQUEUE. Preferred providers: `AUTO`, `DIRECT`, `RPC`, `QUEUE`. `DIRECT` and
`RPC` support request/notify, while `QUEUE` supports enqueue. There is no
unqualified queue-backed synchronous request/reply adapter in dev1.

Native `ConnectResult` exposes `ok`, `provider`, `accepted`, `completed`,
`durable`, `value`, `code`, `detail` as separate getters; it deliberately
preserves uncertain acknowledgement states.

## Python mapping

```
from alchemy_python import NativeConnectSelectorPort, SelectorClient, AlchemySession

# Host-provided *live* ooRexx projections. These three bindings come from
# your macrospace/embedding host. They are NOT constructed by this SDK.
# native_selector: native ConnectSelector projection
# native_new_intent: wraps .ConnectIntent~new with exact six arguments
# encode_payload: convert dict/list into native JsonValue or Array as expected
# encode_options: convert mapping into native Directory
# decode_value: convert native JsonValue/Directory/Array to Python values
# read_field: read named getter, including .true/.false -> Python bool
port = NativeConnectSelectorPort(
    native_selector, native_new_intent,
    encode_payload=encode_payload, encode_options=encode_options,
    decode_value=decode_value, read_field=read_field,
)
client = SelectorClient(port)
service = AlchemySession(client).service(published_service_contract)
service.call('catalog.lookup', {'item': 'item-7'})

# Explicit queue operation. It is not substituted for an RPC service call.
receipt = port.enqueue('tasks.submit', queue_native_payload,
    destination='WORK', requirement='DURABLE',
    options={'correlationId': 'trace-1'})
assert receipt.accepted and receipt.durable and not receipt.completed
```

This example requires the application host to provide the named objects. The
SDK cannot instantiate ooRexx classes, construct a JSON-RPC value, create
QueueFabric packages or authorise native queues itself. Those functions remain
owned by the accepted native bridges and service deployment.

**Important difference:** `ServiceContract.Operation(semantics='job')` remains
an RPC-like *service request* (`REQUEST`, `IMMEDIATE`) when accessed through
`SelectorClient`, even if that service's implementation internally enqueues
work and returns an accepted-job receipt. `NativeConnectSelectorPort.enqueue`
is the separate raw queue admission operation, and must not be passed into
`JobReceipt.parse`: the queue's `ConnectResult~value` is not necessarily a job
service receipt.

The published service API version is local SDK metadata, **not** a version
selector inside ConnectIntent dev1. The server/service registry must enforce
operation names, exact versions and caller authorisation; no service-version
pinning by ConnectSelector itself is claimed.

## Error, acknowledgement and completion

- Native failure/denial (`ok=False`) becomes `ConnectSelectionError` with its
  complete `outcome`; `accepted=True` may still be true for uncertain acks.
- `REQUEST` must report `accepted=True`, `completed=True` and a native value
  decoded by the supplied codec.
- `NOTIFY` reports acceptance at most; never claim completed execution.
- `ENQUEUE` reports queue admission, not operation execution. Durable requests
  require native `durable=True` (permanent queue plus durable store on server).
- Do not retry or switch providers after `execute` begins. Errors and timeouts
  may be ambiguous, including after a successful side effect.
- JMS inbound/outbound are separate optional bridges. The first commit occurs
  before source acknowledgement, with at-least-once behavior and possible
  duplicates. This Python integration does not implement a new JMS stack.

## Remaining qualification

This release runs SDK unit/contract tests using native-contract-shaped doubles.
The ConnectSelector package itself reports tests against injected mocks and
real JSON-RPC local loopback, but not full production Queue Manager or live
network authentication. There is **no claimed full Python -> native ooRexx ->
ConnectSelector integration test** in this release. That requires loading the
real ConnectSelector, JsonRpc Fabric and Queue Fabric packages through the
correct ooRexx registry/path, injecting proper native value codecs, and
running live direct/RPC/Queue tests in the target interpreter environment.

Do not equate Python object macrospace semantics with an RPC service facade.
