# QUIC socket provider architecture — dev5

QUIC is a socket family below the common SocketProvider boundary.

The ooRexx `QuicSocketAddress` is preserved as an object from negotiation and
socket acquisition through to the live connection. The address names a
security profile; `QuicSecurityProfileRegistry` resolves that reference to
provider-owned TLS material.

OpenSSL QUIC owns connection establishment, TLS 1.3, ALPN, packet protection,
connection IDs, retransmission and protocol timers. The native extension exposes
only the operations needed by the common socket shape: connect/listen/accept,
read/write, descriptor, event pump, peer address and close.

`QuicSocketOfferProvider` is a dynamic evidence adapter for SocketProvider's
existing negotiation layer. It does not become a second selection authority.

Accepted-socket address identity depends on SocketProvider dev14's generic rule:
when an accepted provider peer exposes `address`, ProviderSocketListener retains
that exact object rather than overwriting it with the listener address.


## GitHub admission note

The sealed dev3 archive retained a stale `dev2` heading here and a stale
`QuicSocketProviderBuild.VERSION` constant.  The GitHub dev3 admission corrects
those two labels to dev3 without changing the qualified transport semantics.
The sealed archive SHA remains provenance for the delivered qualification; the
repository source is the corrected continuation baseline.


## Stream-count backpressure

QUIC stream creation is flow-controlled independently of UDP writability. Dev4 exposes this below the QUIC provider seam: `tryOpenStream()` uses OpenSSL's no-block stream creation and maps only `SSL_R_STREAM_COUNT_LIMITED` to a retryable `.nil`. Other failures remain provider errors. The provider also exposes OpenSSL's negotiated local stream allowance for bidirectional and unidirectional streams. These observations are advisory and must not be promoted into generic SocketSelector policy.


## Child-stream I/O flow control

Dev5 distinguishes QUIC application flow control from transport failure. A child `QuicStream` may explicitly enter nonblocking application mode and use structured `trySend` / `tryRecv` operations. Native OpenSSL `SSL_ERROR_WANT_READ` and `SSL_ERROR_WANT_WRITE` are projected as retryable `QuicIoResult` states; fatal SSL errors remain errors.

This is deliberately below the common socket-selection contract. Generic consumers continue to see blocking byte-stream semantics through `SocketStreamAdapter`. QUIC-aware consumers may opt into the richer child-stream state after a QUIC socket has already been selected.

A write that returns `WANT_WRITE` must be retried with the same logical bytes before another I/O-triggering operation. The provider enables OpenSSL's moving-write-buffer mode for explicitly nonblocking child streams so the native memory address may change across Rexx calls while the logical write remains the same.
