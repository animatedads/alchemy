# Current integration baseline checked 2026-10-29

Current Git source candidate: **ooRexx WebSocket Access v0.1-dev4**.
Immutable qualified release remains dev1 (`91d244cb00216f5760bffe2e2983c1e461d89048e8fd668f4ad160636eb0a655`).

## Authorities

- Socket Provider v0.1-dev16 — `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`
- ooRexx Crypto v0.8.3 — `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- Crypto Authentication Primitives v0.1-dev1 — `crypto.auth/0.1`
- stable `packages/oorexx_https_server` API inspected 2026-10-29 — v0.4.6

The Library transport grid still records WebSocket dev1's independent live COTS pass as inherited evidence only; it explicitly does not constitute a fresh dev16 rerun.

## dev4 architecture

```text
client:
WebSocketAccess -> SocketProvider -> selected TCP/TLS stream

server wss:
ooRexx HTTPS Server
  owns TCP + TLS + HTTP parsing + admission/lifetime
       -> parsed Upgrade request + plaintext duplex wrapper
       -> WebSocketServerAccess
       -> WebSocketServerConnection
```

No raw socket, BIO, SSL, SSL_CTX or Foreign Runtime object crosses the HTTPS handoff. See `HTTPS_UPGRADE_CONTRACT.md`.

dev4 also preserves bytes that arrive after an HTTP Upgrade head in the same underlying read. This applies to both the client 101 response and server request.

## Qualification gates

The complete gates are recorded in `VALIDATION_DEV4.txt`. Until they execute, dev4 remains SOURCE_CANDIDATE and the only qualified release remains dev1.
