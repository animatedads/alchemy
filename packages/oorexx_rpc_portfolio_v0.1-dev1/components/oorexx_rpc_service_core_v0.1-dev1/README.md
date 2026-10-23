# ooRexx RPC Service Core 0.1-dev1

**API:** `oorexx.rpc_service_core/0.1`  
**Authority:** server-side registration of service objects and callable methods.  
**Minimum runtime:** ooRexx 5.3.0, qualified on r13196 debug x86-64.  
**Dependencies:** only ooRexx; SOAP, JSON-RPC, gRPC, Connect Selector, and Serialisation Selector are optional consumers.

## Register before accepting inbound traffic

```rexx
service = .Catalog~new
registry = .RpcServiceRegistry~new
ignored = registry~registerMethod('catalog','lookup',service,'fetch')
ignored = registry~registerCallbackMethod('catalog','watch',service,'watchChanges')
registry~freeze
dispatcher = .RpcServiceDispatcher~new(registry)
result = dispatcher~invoke('catalog','lookup',arguments,serverContext)
```

`registerMethod(service, publicOperation, receiverObject, receiverMethod)` calls the **same registered object instance**, using `receiverMethod(arguments,context)`; the public name need not equal the real method name. `registerObject(service,receiverObject,explicitMapping)` bulk-adds a Directory or Table of public operation names mapped to method names, validating the entire map before registration. No automatic registration of every object method is allowed. `registerCallbackMethod(...)` registers a method invoked with `(arguments,context,sink)` through `dispatcher~invokeCallback(service, operation, arguments, context, sink)`. A callback sink must implement `onNext(value)`, `onComplete([status])`, `onFault(fault)` and `isCancelled()`; the binding owns network flow control, lifetime and cancellation propagation. The core alone does **not** implement gRPC or remote callback serialization.

`registry~register(service,operation,legacyHandler)` is retained for already implemented `invoke(operation,arguments,context)` handlers. `unregister(service,operation)` revokes future lookups; `freeze()` prevents subsequent registration/revocation. Registration collisions and missing methods fail explicitly. An incoming request cannot register a receiver, choose an object class, or ask to invoke arbitrary ooRexx methods. Remote method/operation names only select keys already published by trusted server code.

## Division of responsibilities

* **ConnectSelector:** how the request travels; does not select server object methods.
* **Serialisation Selector:** bytes to/from typed payloads, including an optional schema-bound protobuf provider; never selects server object methods.
* **Protocol bindings:** SOAP envelope, JSON-RPC 2.0 envelope or future gRPC/HTTP2 envelope/status; map protocol method/route to `service,operation` and call this dispatcher.
* **RPC Service Core:** receiver registry, explicit published method mapping, callback dispatch, generic results and masked internal faults.
* **Application:** method execution and domain-level authorization using a trusted server-generated context.

Bindings must authenticate and authorize inbound traffic and supply trusted context before dispatch. Registry allowlisting alone is not remote authentication/authorization. Do not accept network-supplied authority claims as trusted context. An outbound RPC call does not imply exactly-once execution; retry policy belongs to the caller and service semantics. Synchronous callback methods can emit multiple events through a local sink; network streaming, backpressure, cancellation, deadlines and terminal gRPC status must be implemented and qualified by the protocol adapter.

## Qualification

```sh
OOREXX_RUNTIME_ROOT=/exact/oorexx/runtime sh tests/run.sh
# Optional real SOAP and JSON-RPC envelope integration against exact sources:
SOAP_ROOT=/exact/oorexx_soap_rpc_binding_v0.1-dev2 \
JSONRPC_ROOT=/exact/oorexx_json_rpc_fabric_v0.1-dev3 \
OOREXX_RUNTIME_ROOT=/exact/oorexx/runtime sh tests/run.sh
```

The SOAP dev2 package requires this exact core via `RPC_CORE_ROOT`, and no longer embeds a second copy of `RpcServiceCore.cls`.
