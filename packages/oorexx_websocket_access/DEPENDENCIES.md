# Dependencies

## Core WebSocket access

Required:

- ooRexx 5.3.0 r13196
- Socket Provider current authority: v0.1-dev16
  - SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`

`WebSocketAccess.cls` does not require a concrete crypto implementation.

## Optional estate crypto adapter

`WebSocketPlatformCrypto.cls` binds the WebSocket handshake authority to the
existing authentication-standards crypto layer:

- ooRexx Crypto v0.8.3
  - SHA-256 `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49`
- ooRexx Crypto Authentication Primitives v0.1-dev1
  - public API `crypto.auth/0.1`
  - supplies SHA-1 required by RFC 6455

Entropy is still injected through `WebSocketEntropySource`. The adapter does
not create another RNG, shell out to OpenSSL, read keys, or acquire TLS
credentials. Production installations should bind that interface to the estate
cryptographic/randomness authority.

TLS remains entirely below WebSocket in the Socket Provider TLS family and its
`SocketSecurityMaterialProvider`.
