# ooRexx QUIC Socket Provider v0.1-dev2

A real QUIC socket-family provider behind the common ooRexx SocketProvider boundary.

QUIC remains a sibling provider. Applications, Debug Socket Transport and other
consumers see the common SocketProvider / SocketStreamAdapter contracts; they do
not acquire a separate QUIC networking API.

## dev2

- rebased on the corrected common SocketProvider `v0.1-dev14` contract;
- `QuicSocketOfferProvider` publishes dynamic negotiation evidence without
  adding QUIC-specific fields to `SocketNegotiationRequest`;
- connection and listener descriptors are exposed from the real UDP/QUIC handle;
- `pump()` drives OpenSSL QUIC events with `SSL_get_event_timeout()` and
  `SSL_handle_events()`;
- listeners expose provider-neutral `waitReady()` and nonblocking `tryAccept()`;
- accepted sockets retain their own peer `QuicSocketAddress` through the common
  ProviderSocketListener wrapper;
- TLS 1.3, ALPN, security-profile references and binary-safe stream traffic are retained.

## Boundary

```text
application / DebugSocketTransport
          |
 SocketProvider / SocketSelector
          |
 RexxQuicSocketBinding
          |
 QuicSocket / QuicSocketListener
          |
 OpenSSL QUIC
          |
 UDP + TLS 1.3
```

The address remains a full object. It contains a security-profile reference,
not certificate/key/trust material. Connection IDs, handshake mechanics,
QUIC timers and UDP details stay below the socket boundary.

## Negotiation

`QuicSocketOfferProvider` advertises the currently qualified shape:

```text
scheme      quic
family      QUIC_INET
stream      true
listener    true
sender      true
secure      true
multicast   false
```

The common negotiator can therefore select QUIC for a secure stream request
without the request naming QUIC.

## Qualification

```sh
OOREXX_ROOT=/path/to/oorexx/usr/local qualification/run_environment_test.sh
```

The environment qualification builds the native extension, verifies the common
contract and negotiation projection, creates a temporary test identity, then
performs a real OpenSSL QUIC client/server loopback using `waitReady()` +
`tryAccept()`. The payload contains an embedded NUL byte.
