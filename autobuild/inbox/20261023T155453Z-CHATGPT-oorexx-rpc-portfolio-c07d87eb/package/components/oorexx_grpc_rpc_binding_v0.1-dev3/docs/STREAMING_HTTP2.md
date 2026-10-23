# HTTP/2 server-streaming callbacks — dev3

## Scope

This release provides an **outbound HTTP/2 server-streaming client** for one
unary protobuf request followed by zero or more protobuf replies. It retains
all dev2 functionality. It is **not** a generic HTTP/2 server, does **not**
implement client-streaming/bidirectional streaming, and does **not** provide
async callback dispatch on an arbitrary ooRexx activity.

`GrpcHttp2ServerStreamClient` is a blocking caller-side API that emits decoded
messages incrementally through the caller's registered observer. The network
worker never calls ooRexx; ooRexx polls buffered native transport events from
its own activity. Protobuf remains owned by SerializationSelector v0.4 or a
compatible later schema-bound provider. No protobuf encoder is duplicated.

The API separates three authorities:

- Connect Selector controls the **choice of connector**. A specific channel
  created by application wiring is not a general routing decision. Connect
  Selector dev5's `CALLBACK` mode is **local only**; this release does not
  claim to supply a remote ConnectSelector CALLBACK adapter.
- Serialization Selector controls protobuf encoding and decoding, with explicit
  schema registration and no untyped inference from a remote payload.
- RPC Service Core controls **inbound object + method registration**, including
  callback methods. The network client does not register or reflect on server
  objects. The existing local inbound `GrpcRpcBinding~serverStream()` remains
  implemented by RPC Core's `invokeCallback`.

## API

```rexx
::requires 'GrpcHttp2ServerStreamChannel.cls'
::requires 'Protobuf.cls'
requestSchema=.directory~new
requestSchema['id']='1:uint32'
call registerProtobuf 'demo.watch.proto', requestSchema
observer=.MyObserver~new
client=.GrpcHttp2ServerStreamClient~new('https://inventory.example',10000,'/etc/ssl/certs/ca.pem')
ignored=client~bind('inventory.watch','/demo.Inventory/Watch','demo.watch.proto','demo.watch.proto')
req=.directory~new
req['id']=1
result=client~request('inventory.watch',req,observer)
/* result~status is final gRPC status; do not mistake an early onNext for success */
```

An observer must implement `onNext(decodedMessage) -> .true/.false`,
`onComplete()` and `onFault(GrpcCallResult)`. Optional `isCancelled()` can
signal cancellation between messages. Returning `.false` from `onNext` stops
reading and requests cancellation. `onComplete` occurs only after a valid
`grpc-status: 0` trailer. A nonzero remote gRPC status calls `onFault`, even
if earlier messages were already delivered. No values are rolled back.

`GrpcHttp2CallContext~new(timeoutMs,metadata)` from the *optional* unary
channel can be passed as a request context; the stream client depends only on
its `timeoutMs` and `metadata` methods. It does not load the unary helper.

`GrpcNativeStreamOpen`, `GrpcNativeStreamPoll`, `GrpcNativeStreamCancel` and
`GrpcNativeStreamClose` form the private native boundary. Session handles
are process-local, bounded (128 concurrent), never serialized and never
accepted from network clients. The opaque id is an internal handle, **not an
authorization token**. Callers must not expose raw native functions over RPC.

## Native and wire details

- TLS certificate and hostname verification on; no redirects, no proxy
  inheritance, no silent fallback to HTTP/1.1.
- Cleartext prior-knowledge h2c only for loopback endpoints.
- Request content type `application/grpc+proto`, `te: trailers`, required
  unary request frame; `grpc-timeout` propagated and enforced locally.
- Header metadata is allowlisted (no `grpc-`, pseudo or `*-bin` keys); no
  implicit credentials or compression.
- 4 MiB maximum per protobuf frame, 512 KiB maximum unread native DATA buffer,
  64 MiB aggregate body limit, 10000 decoded messages by default. Exceeding
  the application message bound terminates the stream with code 8 (resource
  exhausted).
- Network callback blocks when unread buffer reaches 512 KiB; thus HTTP/2
  receive flow is naturally throttled by consumption. This does not provide a
  separate application `request(n)` API.
- gRPC message boundaries are reconstructed across arbitrary HTTP/2 chunks.
  Trailing status is authoritative; missing, duplicated, malformed or early
  statuses are failures. TLS errors, HTTP/1.1 negotiation, deadlines and
  cancellations do not trigger retries.
- Partial streaming effects are not undone when a later fault arrives. A
  timeout/cancellation does **not** prove the server never executed work.

## Build and qualification

```sh
make -C native stream-fixture   # platform C++/libcurl engine + CLI
python3 tests/test_native_stream.py

# Build the ooRexx native library using headers for this interpreter build:
make -C native stream OOREXX_INCLUDE=/exact/oorexx/usr/local/include

# Qualify the complete native+ooRexx callback route:
OOREXX_RUNTIME_ROOT=/exact/oorexx \
 RPC_CORE_ROOT=/exact/oorexx_rpc_service_core_v0.1-dev1 \
 SERIALIZATION_ROOT=/exact/serialization_selector_v0.4 \
 ./tests/run_http2_stream.sh
```

`tests/test_native_stream.py` exercises the **same native transport engine**
from a standalone C++ CLI against an independent hyper-h2 fixture. It covers
fragmented frames, trailers, cancellation, deadlines, and TLS. The ooRexx
bridge and observer path has a dedicated test, but requires a matching runtime
and SDK. Do not count a skipped ooRexx test as a pass.

Native helper is source portable C++17/libcurl with HTTP/2 feature required.
Target-specific binaries must be rebuilt, including Termux. This development
cut does not claim broad deployment qualification.
