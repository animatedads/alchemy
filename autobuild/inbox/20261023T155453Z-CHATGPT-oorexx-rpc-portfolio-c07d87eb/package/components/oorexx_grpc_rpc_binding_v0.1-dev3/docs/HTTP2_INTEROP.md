> **dev3 update:** This document describes the inherited dev2 *unary* channel.
> Outbound HTTP/2 *server-streaming* is added separately in [STREAMING_HTTP2.md](STREAMING_HTTP2.md);
> inbound HTTP/2 server, client-streaming and bidirectional streaming are still unsupported.

# gRPC native HTTP/2 unary client (dev2)

## Responsibilities

- **RPC Service Core**: registered ooRexx object/methods and callback contract (unchanged).
- **Serialization Selector v0.4 protobuf**: schema-bound encode/decode (unchanged).
- **Connect Selector v0.1-dev2**: route policy, direct/RPC/queue choice (unchanged).
- **GrpcRpcBinding.cls**: gRPC method registration, protobuf frames, status projection.
- **GrpcHttp2UnaryChannel.cls**: outbound unary channel, explicit endpoint and trust selection. It implements the existing `exchange(path, framed, context)` SPI required by `GrpcUnaryClient`.
- **native/grpchttp2.cpp**: native transport with libcurl HTTPS+ALPN HTTP/2 or local-loopback h2c prior knowledge. Never implements protobuf or method registration.

## Build and test

```sh
# Use explicit runtime location (nonstandard paths, including Termux installs, are valid)
make -C native OOREXX_INCLUDE="$OOREXX_RUNTIME_ROOT/usr/local/include"
export LD_LIBRARY_PATH="$PWD/native:$OOREXX_RUNTIME_ROOT/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export RPC_CORE_ROOT=/exact/rpc-service-core
export SERIALIZATION_ROOT=/exact/serialization-selector-v0.4-protobuf
export CONNECT_SELECTOR_ROOT=/exact/connect-selector-v0.1-dev2   # optional
./tests/run.sh
./tests/run_http2.sh
```

The archive includes one Linux x86-64 debug-runtime-qualified `libgrpchttp2.so` for convenience. **It is not portable**: rebuild from C++17 source for other ooRexx interpreter builds, architectures, Termux, or different native dependency versions. `pkg-config libcurl` and libcurl compiled with HTTP/2 support are required. Both `libcurl` and `libnghttp2` are native *transport* dependencies only. The core ooRexx gRPC class does not require either to load.

`tests/run_http2.sh` uses Python hyper-h2 only as an *independent test server*, never in production code. If the fixture dependency is missing, the script explicitly skips, so a green core-only test does not falsely claim HTTP/2 qualification. It generates a short-lived TLS test certificate using OpenSSL when available and removes its temporary private key on exit.

## Client usage

```rexx
::requires 'Protobuf.cls'
::requires 'GrpcHttp2UnaryChannel.cls'

/* Register protobuf providers using the API from Serialization Selector. */
req=.directory~new; req['id']='1:uint32'
res=.directory~new; res['id']='1:uint32'
call registerProtobuf 'inventory.req',req
call registerProtobuf 'inventory.res',res

/* HTTPS: uses system trust by default. To trust a private CA, inject its
 * absolute PEM path as constructor argument #3. No insecure bypass exists.
 */
channel=.GrpcHttp2UnaryChannel~new('https://rpc.example.org:443',10000)
client=.GrpcUnaryClient~new(channel)
client~bind('inventory.get','/example.Inventory/Get','inventory.req','inventory.res')
metadata=.directory~new
metadata['x-request-id']='example-001'
callContext=.GrpcHttp2CallContext~new(10000,metadata)
arguments=.directory~new
arguments['id']=41
reply=client~request('inventory.get',arguments,callContext)
```

The optional `GrpcConnectAdapter.cls` can register this same `client` with Connect Selector for RPC routes. Do not add a parallel route chooser.

## Guarantees and failure modes

- Unary uses one uncompressed five-byte-framed protobuf request and expects exactly one response if `grpc-status: 0` is present. Outbound HTTP/2 is authenticated via TLS certificate chain/hostname verification. ALPN must select HTTP/2; HTTP/1.1 fallback is refused.
- Metadata keys are validated, values may not include control bytes, and reserved gRPC/HTTP headers cannot be overwritten. Binary metadata (`-bin`) is not yet supported. `grpc-timeout` is emitted using a bounded millisecond value, and libcurl enforces a local upper bound even if the server ignores it.
- Only explicit `http://localhost` or literal IPv4/IPv6 loopback h2c endpoints are permitted; public cleartext targets are rejected. No environmental proxy, redirects or implicit retries. HTTP/2 transport failures are `UNAVAILABLE (14)`, and local timeout is `DEADLINE_EXCEEDED (4)`; **a timeout or reset does not prove that remote side effects were rolled back**.
- Max frame payload is 4 MiB in the native client; responses are also bounded. Unsupported compression and malformed/unframed responses are rejected. Status must be present and unique. Initial-header `grpc-status` is accepted only for a trailers-only response.
- The native channel does not yet implement server-streaming network consumption, client streaming, bidi streaming, grpc-web, server endpoint, live callback backpressure or gRPC authentication plugins. The prior server-streaming callback API remains local and independently tested.
- The protobuf provider currently supports a restricted schema subset; this package does not implement nested/repeated/packed fields or `.proto` compilation.

## External interoperability evidence

The independent hyper-h2 server verifies actual `POST`, `:path`, `content-type`, `te: trailers`, binary DATA frames, and `grpc-status` trailers. Tests cover request/reply, metadata, status faults, malformed response, invalid content type, duplicate and absent status, timeout enforcement, header injection rejection, and Connect Selector denial. Separate TLS tests demonstrate refusal of an unknown self-signed certificate and success with explicit CA trust plus negotiated h2.

This is **outbound unary interoperability**, not evidence of a production-qualified HTTP/2 server or a complete interoperable gRPC feature set.
