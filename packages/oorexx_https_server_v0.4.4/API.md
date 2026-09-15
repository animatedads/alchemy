# ooRexx HTTPS Server v0.4.4 API

## `.HttpsServerConfig`

Transport/security fields retained from v0.4.2 include bind/port, certificate/key, client CA + required-client-cert, backlog, `maxConnections`, read/write timeouts, header/body/request limits, cipher policy, bridge directory, access logging and `nativeTlsConcurrency`.

v0.4.4 adds:

- `connectionWorkers` — fixed connection worker count; default `16`, valid `1..64`.
- `maxPendingConnections` — bounded accepted-socket FIFO capacity; default `64`; must be at least `connectionWorkers`.

`nativeTlsConcurrency` remains required to equal `1` in this line.

## `.HttpsServer`

Retained methods include:

- `route(method,path,target,handlerMethod)`
- `interceptor(target,beforeMethod,afterMethod)`
- `serve`
- `stop`
- `drain(timeoutSeconds)`
- `stopAndDrain(timeoutSeconds)`
- `reloadTls(...)`

Admission observability:

- `connectionWorkerCount`
- `pendingConnectionCount`
- `connectionQueueCapacity`
- `connectionQueueHighWaterMark`
- `connectionQueueAccepted`
- `connectionQueueRejected`

TLS/runtime observability remains available through provider/runtime/policy/generation/native-lane methods.

## Admission semantics

`serve` accepts a TCP socket, acquires a generation-pinned TLS/config lease, and enqueues the tuple into a bounded FIFO. It does **not** start a new activity for that peer. A fixed `.HttpsConnectionWorker` set dequeues work and invokes `.HttpsConnection~run` synchronously.

If the pending FIFO is full, the just-accepted socket is closed and its TLS-context pin/active-connection lease is released immediately.

`stop` stops new listener admission and marks the FIFO stopped. Already queued items are drained before workers exit, preserving graceful-drain semantics.

## TLS session semantics

`.TlsSession` uses memory BIOs only. RxSock handles all network reads/writes/readiness and observes TCP EOF/reset directly. OpenSSL calls are one-lane serialized and memory-only.

A handshake that never reached an established TLS protocol skips `SSL_shutdown` during cleanup. Established TLS sessions still perform shutdown best effort.

## Request/interceptor boundary

`.HttpRequest~context` exposes `.HttpExchangeContext`, including server request ID and transport projections (peer, TLS protocol/cipher/generation) plus application-local state. No Socket/BIO/SSL/SSL_CTX/Foreign Runtime object is exposed to application policy code.
