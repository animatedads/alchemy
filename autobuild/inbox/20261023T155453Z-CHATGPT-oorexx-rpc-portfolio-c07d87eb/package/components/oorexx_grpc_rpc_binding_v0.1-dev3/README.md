# ooRexx gRPC RPC Binding v0.1-dev3

API: `oorexx.grpc_rpc_binding/0.1`. Retains the accepted dev2 unary and local
server-callback binding and adds an **outbound HTTP/2 server-streaming** client.

## Authorities and dependencies

- RPC Service Core v0.1-dev1 (required): explicit registration of approved
  ooRexx service objects and permitted methods; inbound dispatch and local
  callback invocation. No automatic method exposure.
- Serialization Selector v0.4-protobuf (required): schema-bound protobuf
  encoding/decoding. gRPC implements **no** protobuf codec.
- Connect Selector v0.1-dev5 (optional): transport selection and route
  governance. The gRPC protocol does **not** implement another selector.
- gRPC binding: protocol method path registry, five-byte gRPC message framing,
  status projection, streaming callback notifications.
- Optional native HTTP/2: libcurl/TLS/ALPN with C++17. `GrpcHttp2UnaryChannel.cls`
  remains intact from dev2. New `GrpcHttp2ServerStreamChannel.cls` uses a separate
  native streaming transport via pollable event queue, so network worker threads
  never directly reenter ooRexx.

## Build and tests

See [HTTP2 streaming design and qualification](docs/STREAMING_HTTP2.md).
Old dev2 tests are retained as source and are not represented as newly
executed in this environment without the ooRexx debug runtime.

```sh
./tests/run_http2_stream.sh  # runs native live HTTP/2 checks; ooRexx if exact roots supplied
```

## Explicit boundaries

No inbound HTTP/2 network server, no client-streaming or bidirectional HTTP/2,
no compression, no remote ConnectSelector CALLBACK provider, no implicit
retries, no reflection-based method dispatch, no credentials handled inside
protobuf. Local registered-object callback dispatch remains available through
`GrpcRpcBinding~serverStream` and RPC Service Core.
