# ooRexx WebDAV engineering sphere v0.1

Accepted baseline:
- ooRexx WebDAV Gateway v0.1-dev5
- canonical source `packages/oorexx_webdav`
- delivery SHA-256 `5ec140808cb95d1fbe2c6f99c2abf0f14d7f59f06fd387a490538da8aef83f2d`
- qualification: 14/14 local tests PASS under ooRexx 5.3.0 r13196

Current continuation candidate:
- WebDAV v0.1-dev6, delivery SHA-256 `8129e50b20efdaf03980eed8e9f10f09edfec45aae82a27be6a1732c1c98299e`;
- binds ordinary PUT to the HTTPS v0.4.8 bounded body-stream seam;
- full GET can return `HttpResponse~stream` over a fresh StorageByteSource;
- local-file byte sources are factory-created per request for concurrency safety;
- sequential-media PUT remains representation-aware;
- static integration qualification PASS; exact-host runtime/live TLS qualification pending.

Canonical package promotion is deliberately withheld until that new runtime gate passes.

This sphere records WebDAV protocol authority and continuation knowledge. It
does not replace HTTPS Server, Storage Fabric, Queue Fabric or Hercules media
authority.
