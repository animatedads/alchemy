> **Current development contract (dev3):** `docs/CONNECT_SELECTOR_INTEGRATION.md` supersedes the connector-selection discussion below. JSON-RPC 2.0 encoding/dispatch remains authoritative here. `JsonRpcConnectorRegistry` is a deprecated compatibility class requiring explicit import; Connect Selector owns provider selection.

# JSON-RPC Fabric: intent, implementation and connector boundaries

## Intent

1. Provide a standards-based alternative to the estate's preferred Queue Fabric.
2. Keep ooRexx service contracts independent of queue/session/network mechanics.
3. Support local, system-process, system-network and external-language consumers.
4. Preserve deliberate selection of durability, invocation semantics and authority.

## Contracts that exist in dev1

| Object | Entry point | Responsibility |
| --- | --- | --- |
| `JsonRpcMethodRegistry` | `register(name, handler)` | Explicit published-method allowlist. Handler must implement `invoke(name, params, context)`. |
| `JsonRpcDispatcher` | `handleText(json, context=.nil)` | Accept one JSON document; return one JSON document or `.nil` for notifications. |
| `JsonRpcCodec` | `decode(bytes)` / `encode(object)` | Bounded JSON conversion using runtime `json.cls`. |
| `JsonRpcClient` | `request(name, params=.nil)` / `notify(name, params=.nil)` | Initiate calls and interpret replies. |
| `JsonRpcCallResult` | `ok`, `result`, `fault`, `id` | Typed client outcome, no `RESULT~` dependency in user code. |
| `JsonRpcFault` | `code`, `message`, `data` | Explicit service error; safe handler exceptions become `-32603`. |
| `JsonRpcLoopbackTransport` | `exchange(json)` / `send(json)` | Fully working same-process JSON-RPC adapter. |
| `JsonRpcDirectConnector` | `request(...)` / `notify(...)` | Native same-process invocation without JSON encode/decode. |
| `JsonRpcConnectorRegistry` | `register(name, connector)`, `request(...)`, `notify(...)` | Select a connector by explicit identity, with no silent failover. |

### Provider/transport SPI

To add a JSON-RPC wire transport, supply an object with **both**:

- `exchange(jsonText)` returning exactly the associated JSON response or `.nil` if none was received. It must respect request/response framing, deadlines, identity and connection lifetime.
- `send(jsonText)` sending a notification **without waiting for a JSON response**. Transport-level send success does not prove processing or durable delivery.

For a server endpoint, feed one complete decoded JSON document to `dispatcher~handleText`. An HTTP server can map `.nil` to a no-body success response; a socket framing transport must not treat `.nil` as a JSON `null` document. Do not assume every socket read yields an entire JSON message. Frame lengths must be bounded *before* allocating/decoding the payload.

A local direct connector can select the same service handlers without serialization, and does not imply cross-process RPC semantics.

The `stdio_server.rex` demonstration uses one JSON document per newline. An escaped `\\n` within a JSON string is fine; an unescaped physical newline is a framing boundary. It intentionally demonstrates process integration without Socket Provider.

## Connector selection and capabilities

| Capability | Queue Fabric | JSON-RPC 2.0 |
| --- | --- | --- |
| Remote method invocation | Can provide through its existing request/reply contracts | Core purpose |
| Notifications | Queue messages with fabric-specific semantics | Protocol notification; no response |
| Durable delivery / replay | Available where fabric is configured to guarantee it | Not specified |
| Queue ordering / retained status | Fabric-defined | Not specified |
| Arbitrary JSON-RPC clients | Needs a gateway/bridge | Protocol-compatible at message layer |
| Return errors | Fabric-defined status/outcome | Standard numeric code / message / optional data |
| Authentication | Configured fabric authority | Required in transport/endpoint; absent from JSON-RPC specification |

Do not automatically fail over a mutating JSON-RPC call to Queue Fabric after an ambiguous failure: the first call may have completed even when the response was lost. Route selection should be per operation or per explicitly defined policy, not by optimistic transport retries. Operation idempotency keys, deduplication and acknowledgement require a separate application contract.

## Recommended estate integration

- Service contracts (operations, schema versions, authority, error domain and idempotency) belong above both connector implementations.
- Queue Fabric remains default where durability, scheduling, job tracking, or retained state are required.
- JSON-RPC is selected for immediate external interop and lightweight request/reply.
- A future adapter from Queue Fabric must consume the exact *accepted* Queue Fabric API; do not guess signatures or duplicate its ownership/transport/security internals.
- Future network transports should consume Socket Provider rather than call RxSock or bind sockets ad hoc.
- Optional Instrumentation Mesh adapter should observe only operation name, correlation, duration, outcome and byte counts, not raw arguments/results or secrets. No instrumentation dependency is required to load this package.
- Use an explicit package-registry pin for `json.cls` and this distribution; resolve `::requires` before execution, not via whatever duplicate occurs first on REXX_PATH.

## Qualification limitations

Tested on the uploaded ooRexx debug binary, r13196. The included suite covers protocol envelopes and loopback, plus a real piped stdio demonstration. It does not qualify network bindings, TLS, competing client activities, slow input, large batch resource budgets, Unicode edge cases, or auth. The runtime `json.cls` documents some non-roundtripping of literal `\\uXXXX` sequences. These are open qualification items rather than implicitly supported features.

## dev2 implemented increments

See [DEV2_INTEGRATION.md](DEV2_INTEGRATION.md) for the exact Socket Provider and Instrumentation Mesh seams, framed TCP protocol, loopback-only examples and security restrictions. dev2 adds real TCP through an injected Socket Provider v0.1-dev14, not direct RxSock dependency, and optional Instrumentation Mesh v0.1-dev3 observation without hard dependency. Queue Fabric adapter remains pending; no invented broker signature is used. All earlier 'future network transport' statements above should now read 'TCP tested; other network families pending'.
