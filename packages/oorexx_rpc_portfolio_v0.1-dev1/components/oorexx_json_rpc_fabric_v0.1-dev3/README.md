# JSON-RPC Fabric v0.1-dev3 — Connect Selector alignment

`oorexx.json_rpc_fabric/0.1` remains an independent, standards-based RPC
protocol implementation. Connect Selector is now the **only supported routing
authority** for DIRECT / RPC / QUEUE choices; it is an **optional** dependency.

- Protocol and Socket Provider integration from dev2 are preserved.
- The legacy `JsonRpcConnectorRegistry` is now an explicit deprecated shim
  (`src/JsonRpcLegacyConnectorRegistry.cls`), not loaded by the core.
- `JsonRpcClient~notify` now maps transport/codec exceptions to a negative send
  indication, without retry or false completion acknowledgement.
- Local direct notification rejects service-level `JsonRpcFault` results.
- Actual integration tested with `oorexx.connect_selector/0.1` dev1.

See `docs/CONNECT_SELECTOR_INTEGRATION.md` for verified calls and semantic
boundaries. TCP remains unauthenticated demo-only unless independently secured.

# ooRexx JSON-RPC Fabric 0.1-dev2

**API:** `oorexx.json_rpc_fabric/0.1`  
**Status:** development; protocol, real TCP via Socket Provider, and optional Instrumentation Mesh qualified on ooRexx 5.3.0 r13196.  
**Hard dependency:** qualified ooRexx `json.cls` only. **Queue Fabric is not required.**

JSON-RPC Fabric is an independent peer to the estate's preferred Queue Fabric, not a fake queue or automatic fallback. Applications register method handlers once, then deliberately select a connector. Direct native invocation, loopback JSON-RPC, stdio NDJSON, and Socket Provider TCP use the same `JsonRpcDispatcher` / handler contract.

## What's new in dev2

- `src/JsonRpcSocketTransport.cls`: `JsonRpcLengthFrame`, `JsonRpcSocketTransport`, and `JsonRpcSocketServer`. Acquires **every** sender via injected `SocketProvider~sender(logicalName)`. Listener is created and owned by the caller through Socket Provider. No direct RxSock calls in JSON-RPC Fabric.
- Length framing for Socket Provider streams: exactly **8 uppercase ASCII hex characters** for payload byte count, followed by that many bytes. Limit defaults to **1 MiB** on both sender/receiver, validated against the header **before** payload reads. This framing is an explicitly private transport profile, not a JSON-RPC 2.0 or HTTP framing standard.
- Correctly handles fragmented reads, writes through `sendAll()`, closes each connection, rejects corrupt/incomplete/oversize frames and never silently retries an ambiguous call.
- Optional `src/JsonRpcInstrumentation.cls` uses an **injected** `InstrumentationEmitter/0.1` with request accepted/completed/failed and bytes in/out. An observation error cannot change a transport outcome. Successful notification **send** is not proof of remote execution.
- Client `notify()` now returns the transport's explicit `.false` for a failed send instead of invariably reporting success; it still makes no delivery guarantee.
- Cross-process TCP example, real TCP in-process asynchronous worker test, simulated fragmented-stream/negative tests, and Mesh dev3 integration tests.

## Dependencies and explicit paths

Core loading uses `::requires 'JsonRpcFabric.cls'`, and `json.cls` from **the bundled ooRexx runtime**. TCP examples require `oorexx_socket_provider_v0.1-dev14/src/` (and its `RxSockSocketBinding.cls`) separately. Instrumentation tests use `oorexx_instrumentation_mesh_v0.1-dev3/src/` separately. No vendored duplicate of those packages is in this zip. Never select a random version from duplicate paths; resolve from the package registry or pass precise versions.

Quick regression using the extracted supplied debug `.deb`:

```sh
export OOREXX_RUNTIME_ROOT=/path/to/extracted-oorexx-deb
./tests/run-tests.sh
```

Include optional library tests:

```sh
export JSONRPC_SOCKET_PROVIDER_ROOT=/exact/oorexx_socket_provider_v0.1-dev14
export JSONRPC_INSTRUMENTATION_ROOT=/exact/oorexx_instrumentation_mesh_v0.1-dev3
./tests/run-tests.sh
```

Separate-process demonstration (loopback TCP only):

```sh
OOREXX_RUNTIME_ROOT=/path/to/extracted-oorexx-deb \
JSONRPC_SOCKET_PROVIDER_ROOT=/exact/oorexx_socket_provider_v0.1-dev14 \
./tests/test_socket_process.sh
```

## Method registration / application protocol

```rexx
services=.JsonRpcMethodRegistry~new
services~register('catalog.lookup', myHandler) /* invoke(name,params,context) */
server=.JsonRpcDispatcher~new(services)
client=.JsonRpcClient~new(.JsonRpcLoopbackTransport~new(server))
reply=client~request('catalog.lookup',.array~of(.JsonString~new('x-42')))
```

`JsonRpcConnectorRegistry` selects a named connector without silent fallback. A Queue Fabric bridge should be introduced only against the exact accepted broker API, never by guessing a method signature. Under the RPC connector a notification has **no response**; it is not a durable message. Durable work and retained status remain Queue Fabric responsibilities.

## Security and boundaries

The network demo is **unauthenticated localhost-only**. This dev release is **not ready for an untrusted or public network**: no verified TLS deployment, peer authentication, authorization policy, read/write deadlines, slow-client defense, concurrency quota, connection throttling, idempotency service, or distributed tracing. A blocking `recv()` may wait indefinitely without deadlines provided by its underlying socket provider. The framed TCP protocol is separate from interoperable JSON-RPC over HTTP; third-party JSON-RPC clients need a matching framing adapter or future HTTP gateway. `SocketProvider~family` must be negotiated for TLS or Unix streams before claiming them supported.

See `docs/ARCHITECTURE.md`, `docs/DEV2_INTEGRATION.md`, `OOREXX_PACKAGE.json`, and `QUALIFICATION.txt` for qualification and constraints.
