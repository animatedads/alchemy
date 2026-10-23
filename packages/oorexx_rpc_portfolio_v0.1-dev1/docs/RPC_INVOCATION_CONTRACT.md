# Registered RPC invocation / callbacks

## Registration authority

Only trusted local setup code can call `RpcServiceRegistry~registerMethod(service, operation, object, methodName)` or `registerCallbackMethod(...)`. Remote clients request the **published operation**, never a raw ooRexx method. `freeze` seals the registry against later registration or removal. The shared dispatcher returns protocol-neutral `RpcServiceResult` or `RpcServiceFault`.

A published operation's binding is exact and case-sensitive. Duplicate entries and missing object methods are rejected at registration time. The invocation must not consult `methodName` from the request body, use unbounded reflection, or authorize calls based solely on a network path.

## Callback lifecycle

For streaming, `onNext(value)` represents partial delivery; it is not an acknowledgement of RPC success. A stream concludes with **one** final terminal outcome: `onComplete()` after a successful remote final status, or `onFault(fault)` on rejection, transport failure, deadline, cancellation, malformed response, or application error. No automatic replay of partially delivered calls, and no return to success after a terminal fault. Return `false` from `onNext` to cancel outbound server streaming; native transport abort is best-effort and does not reverse already-executed server effects.

`RpcServiceDispatcher~invokeCallback()` invokes only a callback-registered operation and validates the callback sink interface before invoking the target; callback calls are not an unrestricted remote object reference mechanism.

## Wire/protocol separation

JSON-RPC preserves its `jsonrpc`, `id`, `method`, `params` and `error` schema. SOAP owns XML envelopes, namespaces and faults. gRPC owns HTTP/2 framing, trailers, status, deadlines and streaming sessions, while Serialisation Selector provides schema-bound protobuf. Transports are independent of service definitions; Connect Selector remains authoritative for choosing the route.
