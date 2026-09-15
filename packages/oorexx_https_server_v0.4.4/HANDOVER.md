# ooRexx HTTPS Server v0.4.4 handover

v0.4.4 continues the bounded-admission HTTPS line and advances the native dependency to user-supplied ooRexx Foreign Runtime v0.17.1.

## HTTPS concurrency/liveness architecture

The server keeps the v0.4.2 memory-BIO transport and the subsequent bounded pre-TLS admission design:

1. accept TCP socket;
2. pin current TLS/config generation and active-connection lease;
3. enqueue into a bounded FIFO (64 default);
4. one of 16 fixed worker activities dequeues it;
5. worker performs TLS handshake and HTTP connection synchronously;
6. worker releases the lease and returns to the FIFO.

There is no per-peer `conn~start('run')` fan-out. OpenSSL never owns or performs I/O on the accepted socket. RxSock remains sole descriptor/network owner. OpenSSL/Foreign Runtime calls run through one serialized in-memory lane, with network waits outside the lane.

## Foreign Runtime v0.17.1 concurrency repair

v0.17.1 fixes an independently reproduced v0.17.0 native introspection crash. The failing path was concurrent construction of nested Rexx metadata arrays in `signatureArray()` from `method()` / `methodByInputs()`. v0.17.1 publishes the method/signature/parameter wrapper graph once during `ForeignLibrary` initialization and resolves `methodByInputs()` to a signature index. No global foreign-call serialization was added; native invocation remains concurrent.

HTTPS does not use the repaired introspection methods in its hot TLS path; it calls `invokeArray()` directly. For that reason the worker/FIFO admission repair remains part of the server and is not removed merely because Foreign Runtime now fixes its separate race.

## Qualification

- exact supplied Foreign Runtime v0.17.1 prebuilt binary suite: PASS;
- independent source rebuild of v0.17.1 + full source-mode suite: PASS;
- repaired `test_threads.rex`: PASS 5/5 consecutive direct reruns;
- full HTTPS v0.4.4 suite against exact v0.17.1 binary: PASS;
- unchanged eight-wave 16-good + 16-reset/abort HTTPS stress at 2-second connect timeout: PASS locally;
- separate one-CPU 40-wave soak: 640/640 valid HTTPS + 640 abort peers, zero server ERROR lines, final health PASS;
- test-harness cleanup hardened so auxiliary Rexx listeners cannot leave the acceptance command hanging after verdict.

The independent OpenSSL 3.5.3 host that failed earlier reset-storm candidates remains the release-closing HTTPS portability test.
