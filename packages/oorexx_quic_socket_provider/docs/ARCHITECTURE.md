# QUIC socket provider architecture — dev2

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
