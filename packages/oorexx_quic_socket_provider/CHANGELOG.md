# Changelog

## 0.1-dev2

- Rebase qualification copy on common SocketProvider v0.1-dev14.
- Add dynamic `QuicSocketOfferProvider` for the common negotiation layer; QUIC is secure stream, sender/listener yes, multicast no.
- Add native descriptor exposure for connections and listeners.
- Add OpenSSL QUIC event pumping using `SSL_get_event_timeout()` and `SSL_handle_events()`.
- Add provider-neutral listener `waitReady()` and nonblocking `tryAccept()` using `SSL_ACCEPT_CONNECTION_NO_BLOCK`.
- Preserve the accepted QUIC peer's own `QuicSocketAddress` through the common ProviderSocketListener wrapper; dev14 fixes this generically.
- Retain TLS 1.3, ALPN, binary-safe payloads, security-profile references and real loopback qualification.

# Changelog

## 0.1-dev1

- First actual QUIC provider delivery.
- Added QuicSocketAddress, QuicSocket, QuicSocketListener and SocketProvider binding.
- Added OpenSSL QUIC client/server native ooRexx extension.
- Added security-profile indirection.
- Added live binary-safe loopback qualification.
