# dev2 integration contract and qualification

## Socket Provider binding

Optional dependency is `oorexx.socket_provider` **0.1-dev14** with provider API `socket.provider/0.1`; client/side adapter has no direct `::requires` on that dependency so the core continues to load without it.

1. Deployment creates one registered logical service using `RegisteredSocketAddressProvider` and a concrete stream binding (`RxSockTcpBinding` for the verified TCP path).
2. Client injects the provider into `JsonRpcSocketTransport(provider, 'rpc.logical.service', maxFrameBytes)`.
3. A server obtains `listener=provider~listener('rpc.logical.service')` and passes it into `JsonRpcSocketServer(dispatcher,maxFrameBytes)~serveOne(listener,context)`; caller owns listener lifetime and concurrency.
4. A request opens one connection, writes exactly one framed JSON document, receives exactly one framed JSON response, and closes it. A notification sends a single document and closes without reading a response. A batch is still **one JSON document**, regardless of number of batch members.
5. Framing is 8 ASCII uppercase hex digits + body, no delimiters or trailers; the frame length is a **byte** count, not characters. 00000001 followed by `{` illustrates framing syntax but not a valid JSON document. Frames over the configured limit, nonhex lengths, empty payloads, truncated headers/bodies and send shortfalls fail closed. The codec enforces its own JSON payload limit independently.
6. `JsonRpcClient~request()` returns a -32000 transport fault for socket failures without assuming the operation did not happen. Explicit retry must be application-governed by idempotency. Notification send errors are not delivery confirmations.

This profile is a **private JSON-RPC transport framing**, not standardized JSON-RPC framing and not HTTP. It may be used by custom peers only when they explicitly adopt it.

## Instrumentation Mesh binding

`JsonRpcInstrumentedTransport` wraps any transport implementing `exchange()` and `send()` and accepts one service-owned injected `InstrumentationEmitter` from **0.1-dev3**. It records only payload byte counts and call/send lifecycle, not method names, parameters, response contents, request IDs, credentials or raw socket data. `requestCompleted` measures **local transport completion**; a JSON-RPC error returned by the peer is still a completed RPC exchange. A notification send completion is not remote execution. Instrumentation exceptions are contained and must not determine RPC success/failure.

## Known incomplete boundaries

- TLS/Unix could use the same byte-stream contract with supported provider endpoints, but are **not yet tested**; do not claim that security can be inferred from a transport scheme string.
- No HTTP(S) request handlers or WebSocket adapters, no connection pooling, no pipelining/multiplexing, no JSON-RPC server batch resource budget, and no JSON-RPC response batch correlation.
- The included server is synchronous and single-connection-per-call; use a supervised and bounded pool, verified caller identity, per-client quotas and read deadlines before broad deployment.
- Queue Fabric remains the preferred durable execution/messaging provider. There is no Queue Fabric adapter in dev2; its accepted broker contract must first be resolved and verified.
- Core `json.cls` unicode-escape and deeply nested object cases remain separate qualification work.
