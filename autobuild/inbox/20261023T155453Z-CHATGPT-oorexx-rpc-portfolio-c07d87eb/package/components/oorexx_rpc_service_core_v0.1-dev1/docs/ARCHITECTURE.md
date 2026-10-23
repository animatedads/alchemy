# Inbound RPC registration and dispatch

The server controls registrations and object lifetime. A wire request controls only the exposed **service** and **public operation** plus serialised parameters, never a method selector or receiver reference.

1. Application creates the service instance(s) and registers public operation -> ooRexx method mappings.
2. Protocol ingress validates envelope and maps service/operation; it authenticates/authorizes at the transport or service policy boundary.
3. Serialisation Selector decodes the payload using an explicit codec/schema.
4. `RpcServiceDispatcher` resolves the exact pair within `RpcServiceRegistry`, invokes only the bound object/method and passes trusted context.
5. Domain results/faults go back to the appropriate SOAP/JSON-RPC/gRPC protocol binding for protocol-specific encoding.

For callbacks, the binding creates an in-process sink (`onNext`, `onComplete`, `onFault`, `isCancelled`), then calls `invokeCallback`; the registered method invokes the sink. Callback events are not transported by the RPC core and carry no artificial durability or asynchronous delivery guarantee. A full gRPC binding must support server, client and bidi streaming over HTTP/2 with flow control and protobuf schema bindings registered by Serialisation Selector; none are claimed by this core.

Default registration is closed: no arbitrary object reflection; no automatically exported methods. Registry method names and external RPC operation names may differ. The old SOAP-owned `RpcServiceCore.cls` is superseded by this canonical package; SOAP dev2 uses it as a dependency, avoiding duplicate class definitions.
