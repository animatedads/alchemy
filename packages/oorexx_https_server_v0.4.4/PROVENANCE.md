# Provenance — ooRexx HTTPS Server v0.4.4

Date: 2026-08-30

Continuation base: bounded-admission v0.4.3 working line, itself derived from sealed v0.4.2 after the independent target-host reset-storm failure.

Runtime used for local qualification: user-supplied ooRexx 5.3.0 r13196 Internal Test Version package.

Foreign Runtime input: user-supplied `oorexx_foreign_runtime_v0.17.1(1).zip`.
SHA-256: `cf03141a9d6bdf453f2a488b3d113541c932e623dd0b81e79f2b1ac7611b6801`.

Vendored exact payload hashes:
- `build/libforeign_runtime.so`: `c9313e496f51b45e6037fcd232e5fbdd12bdb1b6ffc4b3596172b093cd6ca539`
- `rexx/foreign.cls`: `18ef78729a447c4125e216bde1a86cf30e156cafa2b848d94ab06c3511cdb5d7`

The vendored files are copied directly from the supplied v0.17.1 archive. The native JSON bridge schema remains `oorexx.foreign/0.14`, as documented by v0.17.1 itself.

Foreign Runtime v0.17.1 concurrency maintenance scope: method/signature metadata wrapper materialization is moved to library initialization; concurrent `method()` / `methodByInputs()` no longer construct nested ooRexx arrays. Foreign invocation itself remains concurrent and no global invocation lock is introduced.

External HTTPS evidence carried forward:
- v0.3 target concurrency/reset segfault;
- v0.4 target mixed reset liveness timeout;
- v0.4.1 target mixed reset liveness timeout despite four native lanes;
- v0.4.2 target mixed reset liveness timeout despite memory-BIO/RxSock-only network I/O.

Server response carried into v0.4.4: fixed worker pool + bounded accepted-socket FIFO; no per-peer activity creation; memory-BIO TLS; one serialized native in-memory lane; direct handshake EOF/abort cleanup without ERROR-log amplification.
