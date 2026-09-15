# ooRexx HTTPS Server v0.4.4

A small native ooRexx HTTPS/HTTP/1.1 server. RxSock owns TCP and all network I/O. OpenSSL 3 supplies TLS through ooRexx Foreign Runtime v0.17.1. Python is **not** part of the HTTPS server runtime path.

## Transport and ownership

TLS uses OpenSSL memory BIOs:

`RxSock -> OpenSSL read memory BIO -> SSL state machine -> OpenSSL write memory BIO -> RxSock`

OpenSSL never receives the accepted socket descriptor. RxSock is the sole descriptor owner. Foreign Runtime/OpenSSL calls are serialized through one short in-memory native lane; network readiness and TCP I/O happen outside that lane using nonblocking RxSock/select.

TLS 1.2 is the minimum protocol. TLS 1.3 is supported. Certificate/key validation, optional mTLS, generation-pinned hot TLS context replacement, failed-reload atomicity and graceful drain are retained.

## Bounded connection admission

The independent OpenSSL 3.5.3 host showed that v0.4.2 could still starve good handshakes during a burst of incomplete/reset TLS peers even after socket BIOs were removed. The bounded-admission line therefore does not create one ooRexx activity per accepted unauthenticated socket.

- `connectionWorkers=16` fixed worker activities are created once.
- `maxPendingConnections=64` accepted sockets are held in a bounded FIFO.
- The accept loop pins the current TLS/config generation and enqueues the lease.
- A worker dequeues and processes one connection synchronously, then returns to the FIFO.
- Queue overflow closes the just-accepted socket and releases its pinned resources immediately.

Defaults can be changed with `--workers N` and `--pending N` (`pending >= workers`).

## Foreign Runtime v0.17.1

The supplied v0.17.1 runtime preserves the v0.14 native C-provider JSON schema while fixing an externally reproduced **native introspection concurrency crash**. `ForeignMethod` / `ForeignSignature` / `ForeignParameter` wrapper graphs are materialized once at library load; `methodByInputs()` resolves to a published signature index instead of constructing nested Rexx arrays concurrently.

This repair is real but separate from the HTTPS reset-storm liveness issue: the HTTPS TLS hot path uses `invokeArray()` directly, not `method()` / `methodByInputs()`. Therefore v0.4.4 adopts v0.17.1 but retains the bounded worker/FIFO admission model rather than pretending the Foreign Runtime introspection fix replaces it.

The server loads only `foreign.cls` and `libforeign_runtime.so`. The optional Python provider is not initialized or required.

## HTTP and interceptor behavior

HTTP/1.1 supports exact routes, GET/POST/HEAD, keep-alive/pipelining, `100-continue`, binary-exact bodies, bounded headers/body/counts and conservative request framing. Duplicate `Content-Length`, unsupported `Transfer-Encoding`, invalid Host/framing and malformed requests fail closed.

The interceptor boundary remains ordered before-hooks plus reverse after-hooks, short-circuit responses, failure containment and request-local transport projections without exposing Socket/BIO/SSL/SSL_CTX/Foreign Runtime objects.

## Start

```sh
./start.sh --cert server.pem --key server.key --bind 127.0.0.1 --port 8443
```

Optional admission controls:

```sh
./start.sh --cert server.pem --key server.key --workers 16 --pending 64
```

Ready output includes the active runtime and admission policy, for example:

`OOREXX_HTTPS_READY ... foreign=0.17.1 ... native=bounded-1-nonblocking nativeLanes=1 io=memory-bio-rxsock workers=16 queue=64 ...`

## Qualification status

Local qualification uses the supplied ooRexx 5.3.0 r13196 debug build, the exact supplied Foreign Runtime v0.17.1 prebuilt runtime, and system OpenSSL 3.5.5. Foreign Runtime's own binary suite passes, including its repaired thread-safety test, 128 inherited assertions, provider-threading tests, Python multi-activity stress, PTY/errno, OpenSSL and FFmpeg probes. The repaired `test_threads.rex` also passed five consecutive direct reruns. A clean source rebuild of v0.17.1 and its full source-mode suite also pass.

The complete HTTPS suite passes locally, including ordinary 16-client concurrency and the unchanged eight-wave 16-good + 16-reset/abort stress. A separate one-CPU 40-wave soak passes 640/640 valid HTTPS requests mixed with 640 incomplete-TLS-close peers with zero server ERROR lines. The original OpenSSL 3.5.3 host remains the decisive external closure test for the HTTPS liveness defect.
