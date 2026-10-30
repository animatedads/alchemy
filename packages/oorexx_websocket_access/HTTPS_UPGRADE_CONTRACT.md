# HTTPS → WebSocket upgrade handoff contract

This is the integration seam between the owned ooRexx HTTPS Server and `oorexx_websocket_access`. It exists so Rasen Falcon/Wire browser duplex traffic can run over our own HTTPS/TLS implementation without transferring TLS or socket authority into WebSocket.

## Authority split

The HTTPS server continues to own accepted TCP sockets and network I/O, TLS/OpenSSL state and certificate/key/trust material, bounded connection admission and worker leases, HTTP/1.1 parsing and request limits, and TLS-generation pinning/cleanup.

WebSocket owns only the upgraded RFC 6455 conversation: Upgrade-specific validation, application-supplied Origin/subprotocol policy, WebSocket framing/masking, fragmentation, ping/pong and close semantics.

No raw Socket, BIO, SSL, SSL_CTX or Foreign Runtime object crosses this seam.

## Required HTTPS-side handoff

After HTTPS has TLS-authenticated the connection, parsed a bounded HTTP/1.1 request head, identified a registered WebSocket-upgrade route, and retained its normal worker/admission/TLS-generation lease, it provides:

- a `WebSocketUpgradeRequest` containing method, target/path, HTTP version and normalized headers;
- a plaintext duplex wrapper implementing `read(maxBytes)`, `write(bytes)` and `close`;
- the authoritative peer/socket-address projection used for observation;
- any plaintext bytes already read beyond the HTTP request head.

The intended call is:

```rexx
connection = webSocketServer~acceptParsedRequest(
    httpsUpgradeStream,
    peerSocketAddress,
    upgradeRequest,
    webSocketOptions,
    postHeaderBytes)
```

The wrapper is not a native socket. Reads/writes continue through the HTTPS server's established TLS session, preserving memory-BIO, OpenSSL serialization, timeout and shutdown rules.

## Lifetime rule

A successful 101 handoff changes the connection from ordinary HTTP processing to upgraded mode. HTTPS must not resume normal HTTP body/routing/pipelining on that connection.

The HTTPS worker/admission/TLS-generation lease remains held until the upgraded stream closes. WebSocket close closes the wrapper; the HTTPS owner then performs ordinary TLS/TCP cleanup. A rejected upgrade stays in the normal HTTPS response path.

## Security rules

- Browser-facing deployments should use an explicit Origin allowlist.
- The WebSocket client key must be canonical for a 16-byte RFC 6455 nonce.
- Client frames must be masked; server frames must not be masked.
- Authentication and LDAP identity remain application/security authorities, not WebSocket framing semantics.
- HTTPS/mTLS identity evidence may be projected into application context but is not silently converted into WebSocket authorization.

## Current integration status

The WebSocket side is implemented in source candidate v0.1-dev4 via `WebSocketUpgradeRequest` and `WebSocketServerAccess~acceptParsedRequest(...)`.

The stable `packages/oorexx_https_server` API inspected on 2026-10-29 documents v0.4.6 and intentionally exposes no transport object through ordinary route/interceptor handlers. The remaining counterpart work is therefore a narrow explicit upgrade-stream adapter in the HTTPS component—not exposure of raw socket/TLS internals.
