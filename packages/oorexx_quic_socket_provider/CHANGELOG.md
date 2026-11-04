# Changelog

## 0.1-dev5

- Add `QuicIoStatus` / `QuicIoResult` for structured child-stream I/O outcomes.
- Add explicit child-stream `setBlockingMode()`.
- Add `trySend()` and `tryRecv()` which preserve OpenSSL QUIC `WANT_READ` / `WANT_WRITE` as retryable flow-control states.
- Enable `SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER` when a child stream is put into nonblocking application mode so Rexx retries can preserve logical write data without native pointer identity.
- Keep ordinary `send/recv` and `SocketStreamAdapter` compatibility behavior unchanged.
- Extend the multiplex qualification programs to exercise the dev5 structured I/O path.


## 0.1-dev4

- Add nonblocking `tryOpenStream()` using OpenSSL `SSL_STREAM_FLAG_NO_BLOCK`.
- Treat `SSL_R_STREAM_COUNT_LIMITED` as retryable stream-count backpressure rather than a fatal provider error on the nonblocking path.
- Expose negotiated local bidirectional/unidirectional stream availability.
- Add `canOpenStream()` as a non-authoritative convenience observation; actual stream creation remains authoritative.
- Extend multiplex qualification to exercise nonblocking stream creation and report allowance before/after creation.


## 0.1-dev3

- Add native QUIC child-stream ownership and handle registry.
- Add `QuicSocket~openStream`, `acceptStream` and `tryAcceptStream`.
- Add `QuicStream` with native stream ID, send/receive/close, parent-connection,
  peer-address projection, event pumping and `SocketStreamAdapter` compatibility.
- Explicitly enable incoming QUIC streams so peer-created streams reach the
  OpenSSL accept queue.
- Ensure connection close releases child streams before the parent QUIC
  connection.
- Add live two-stream multiplex qualification over one TLS 1.3 QUIC connection.
- Preserve the dev2 ordinary single-stream compatibility path and SocketProvider
  v0.1-dev14 object boundary.

## 0.1-dev2

- Rebase qualification copy on common SocketProvider v0.1-dev14.
- Add dynamic `QuicSocketOfferProvider` for the common negotiation layer; QUIC is
  secure stream, sender/listener yes, multicast no.
- Add native descriptor exposure for connections and listeners.
- Add OpenSSL QUIC event pumping using `SSL_get_event_timeout()` and
  `SSL_handle_events()`.
- Add provider-neutral listener `waitReady()` and nonblocking `tryAccept()`.
- Preserve the accepted QUIC peer's own `QuicSocketAddress` through the common
  `ProviderSocketListener` wrapper.
- Retain TLS 1.3, ALPN, binary-safe payloads, security-profile references and
  real loopback qualification.

## 0.1-dev1

- First actual QUIC provider delivery.
- Added `QuicSocketAddress`, `QuicSocket`, `QuicSocketListener` and SocketProvider
  binding.
- Added OpenSSL QUIC client/server native ooRexx extension.
- Added security-profile indirection.
- Added live binary-safe loopback qualification.
