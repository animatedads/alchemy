# Alchemy for Python dev4 — source-reviewed interoperation

**Status:** Python-to-Python TCP profile tests passed; *native Python-to-ooRexx runtime not yet qualified*. The SDK never substitutes an RPC transport for Connect Selector's routing decision. Existing Python macrospace live-object interoperation remains separate.

## Authority boundaries

| Authority | Reviewed source | Python responsibility |
| --- | --- | --- |
| Connect Selector | `oorexx_connect_selector_v0.1-dev2` (`oorexx.connect_selector/0.1`) | Supply operation, mode, guarantee, destination, optional explicit provider through injected native selector port; do not implement route selection or retries |
| JSON-RPC Fabric | `oorexx_json_rpc_fabric_v0.1-dev3` (`oorexx.json_rpc_fabric/0.1`) | Encode JSON-RPC 2.0 and, when intentionally configured for the socket profile, frame/deframe private `hex8` TCP messages |
| RPC Service Core | `oorexx_rpc_service_core_v0.1-dev1` (`oorexx.rpc_service_core/0.1`) | Consume an allowlisted published operation; never request an arbitrary receiver/method via reflection; expose optional bounded local callback sink |
| Serialization Selector | `serialization_selector_v0.5-sint32` | Preserve native source of typed codec/schema authority; Python JSON codec is specifically for JSON-RPC envelopes, not a replacement for protobuf/BSON/SOAP/message-payload serialization |
| Python macrospace | `oorexx_python_macrospace_poc_v0.31.7` | Adopt live retained native ooRexx objects using the separate optional in-process bridge; no re-encoding into RPC references |

### Connect Selector dev2 routing policy qualification

`ConnectRoutePolicy~new` starts in **strict/deny-unless-granted** mode. The native `ConnectSelector~new()` still accepts **no policy** and then calls registered eligible providers without policy enforcement. Security-sensitive deployments must inject the strict policy and explicit allow grants. The Python SDK cannot turn an absent native policy into authorization.

- Route grants scope to `(operation, mode, provider, destination)`; deny wins over allow.
- Named destinations must have matching native provider registration.
- Explicit provider selection cannot bypass an installed `ConnectRoutePolicy`.
- `REQUEST` / `NOTIFY` may select `DIRECT` or `RPC`; `ENQUEUE` selects `QUEUE`.
- A named service operation **is not permission**; the server binding must authenticate/authorize and enforce approved registration.
- `ConnectSelector~explain` may help identify a denied route but is not proof of execution or authorization at the time of execution.
- Native Connect Selector and JSON-RPC Fabric remain independent optional modules. No Queue Fabric dependency is introduced into JSON-RPC.

### RPC Service Core callbacks

`RpcServiceRegistry~registerMethod(service, publicOperation, target, methodName)` is an administrator/server-side capability. It invokes the *registered target instance*, not a class/method supplied by the remote caller. `registerCallbackMethod` additionally permits an in-process callback sink. `LocalRpcCallbackSink` supports the required `onNext(value)`, `onComplete([status])`, `onFault(fault)`, `isCancelled()` surface and keeps a bounded local event list; the bridge must qualify method-name projection and native argument conversion. Overflow requests cancellation and raises `ContractError`. **This is not a gRPC implementation, remote stream, or callback delivery guarantee.**

### Private JSON-RPC TCP socket profile

The accepted ooRexx `JsonRpcLengthFrame` writes `right(d2x(n),8,'0') || payload`, where `n` counts **bytes**, not Unicode characters. Python `FramedSocketTransport` does the same: `8 uppercase ASCII hexadecimal length digits + exactly n octets`. Each RPC request/notification uses one new socket; no transparent retry, connection pooling, or fallback.

- Default payload maximum: 1,048,576 bytes; an inbound advertised length outside the bound is rejected **before** reading/allocating the advertised body.
- Frame zero length is forbidden.
- TCP receive handles segmentation and detects short headers/bodies.
- A disconnected/failed request may have been executed; the SDK reports uncertain outcome, it does not replay mutations.
- Notifications do not receive response frames and offer no durability/completion claim.
- This is neither HTTP nor a general JSON-RPC framing standard. Do not point `HttpTransport` at a length-framed port.
- Loopback only by default; a remote override is an intentionally unsafe interoperability hook **without TLS/authentication**. Never expose an unauthenticated dev3 RPC server to an untrusted network, even with the override. Hardened remote connectivity requires a separately approved authenticated, encrypted connection.
- A real Python→ooRexx test requires an exact compatible ooRexx runtime, JSON-RPC Fabric dev3, Socket Provider and explicitly bound TCP listener/server; a Python loopback server double does not qualify this.

## Example: private socket endpoint

```python
from alchemy_python import FramedSocketTransport, JsonRpcClient, ServiceContract, Operation, AlchemySession

transport = FramedSocketTransport('127.0.0.1', 19192, timeout=5.0)
client = JsonRpcClient(transport)
catalog = AlchemySession(client).service(ServiceContract(
    'catalog', '1', (Operation('lookup', 'catalog.lookup'),)))
reply = catalog.lookup({'item': 'item-7'})
```

The endpoint must run JSON-RPC Fabric's **length-framed** TCP server (`JsonRpcSocketServer`), *not* its NDJSON stdio server or an HTTP listener. Service implementations/permissions must be registered before accepting traffic.

## Remaining native qualification gates

1. Obtain the exact runtime and Socket Provider from registry; resolve package versions and explicit paths rather than arbitrary `REXX_PATH` ordering.
2. Prove Python JSON-RPC request, notification and fault against **real ooRexx** framed TCP server (including Unicode and 1 MiB bounds).
3. Run Python bridge → real native `ConnectSelector~execute` and `~explain` with dev2 policy permits/denials for registered DIRECT/RPC/QUEUE and tenant-specific destinations.
4. Run Python macrospace live-object projection tests against actual compiled bridge binary, preserving re-entry, exact casing, native exception and lifetime authority.
5. Test real Queue Fabric persistent manager / ACL and journal restart, with a durable enqueue that returns `accepted` but not `completed`.
6. Qualify callback sink method projection and controlled cancellation through `RpcServiceDispatcher~invokeCallback` before claiming an ooRexx callback pass.
7. Require TLS, authentication, authorization, peer/deadline/resource controls and reviewed schema mapping before any production remote TCP release.
