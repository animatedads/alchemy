> **dev3 update:** An outbound HTTP/2 server-streaming client is now available;
> see [STREAMING_HTTP2.md](STREAMING_HTTP2.md). Earlier exclusions in this
> document describe the original dev1 local callback binding.

# Three authorities plus distinct protocol envelopes

```
Application service object --[explicit registration]--> RpcServiceCore
                                               ^
JSON-RPC 2.0 envelope --------------------------|
SOAP 1.1/1.2 document/literal envelope --------|
gRPC framed protobuf message -- GrpcRpcBinding-|
            ^
  SerializationSelector: Protobuf provider / schema bindings
            ^
  ConnectSelector: RPC route authorization and transport selection
            ^
  HTTP/2 channel: NOT yet implemented
```

`GrpcMethodRegistry` defines each exact externally reachable path, maps it to an already-registered service and operation, and pins both protobuf formats. The client does not specify an ooRexx receiver name and cannot override a method's serializer. `RpcServiceRegistry` is a separate and mandatory second check.

Unary calls use exactly one request frame and emit one response frame on successful dispatch. Error responses carry gRPC status codes and sanitized messages, not raw native exception details. gRPC framing is not used as an ad hoc TCP wire protocol: a future network adapter must implement the HTTP/2 semantics in the gRPC protocol specification.

Server streaming uses registered callback operations; each emitted item is serialized and synchronously submitted through the supplied writer. A writer reporting failure prevents further messages. A writer that becomes cancelled is observed by `isCancelled()`, and successful completion never overrides cancellation or earlier failures. This is the local callback boundary, **not** evidence of a fully qualified HTTP/2 streaming endpoint or flow-controlled scheduling.

Client/bidirectional streaming requires a separate incremental request consumer in the RPC Core or a stream-session SPI, with explicit client half-close, callbacks and ownership. Such semantics cannot be inferred from an Array of messages, so neither mode is implemented by pretending to aggregate calls.

`GrpcConnectAdapter` uses `ConnectSelector`'s published `supports(intent)`/`execute(intent,payload)` SPI and refuses notifications and durable enqueue. ConnectSelector owns permission checks and makes the selection before any call; no fallback on uncertain outcomes. This optional file imports `ConnectSelector.cls`, but the base gRPC binding does not.
