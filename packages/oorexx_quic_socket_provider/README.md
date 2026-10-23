# ooRexx QUIC Socket Provider v0.1-dev3

A real QUIC socket-family provider behind the common ooRexx `SocketProvider`
boundary. The native transport is OpenSSL QUIC.

QUIC remains a sibling socket provider. Applications which only need an ordinary
stream continue to use `SocketStreamAdapter`; applications which intentionally
need QUIC multiplexing may ask the selected `QuicSocket` for child `QuicStream`
objects. No QUIC transport selection is moved into application code.

## dev3

Dev3 keeps the dev2 SocketProvider v0.1-dev14 integration and adds real QUIC
stream multiplexing.

`QuicSocket` now exposes:

```rexx
stream = socket~openStream
incoming = socket~acceptStream
incoming = socket~tryAcceptStream
```

Each returned `QuicStream` is backed by a genuine OpenSSL QUIC stream object
created or accepted with `SSL_new_stream()` / `SSL_accept_stream()`. It exposes
its QUIC stream ID, send/receive/close, parent connection, peer address through
that parent, event pumping and `asStream()`.

The existing compatibility path is retained:

```rexx
stream = socket~asStream
```

That path continues to present the ordinary generic socket stream contract. QUIC
multiplexing is therefore additive rather than a new mandatory application API.

## Boundary

```text
ordinary stream consumer                 QUIC-aware consumer
        |                                       |
 SocketStreamAdapter                       QuicStream
        |                                  /    |    \
        +----------- QuicSocket ----------+-----+-----+
                         |
                 RexxQuicSocketBinding
                         |
                 SocketProvider/Selector
                         |
                    OpenSSL QUIC
                         |
                     UDP + TLS 1.3
```

The `QuicSocketAddress` remains a full object and carries only a reference to a
security profile. Certificates, keys, trust material, connection IDs, QUIC
timers and packet mechanics remain below the socket boundary.

## Multiplexing semantics

The connection remains the lifetime owner. Child stream objects are closed
before the native connection is destroyed.

Incoming child streams are explicitly enabled at the OpenSSL connection level.
This is required so the peer's streams are placed on the accept queue instead of
being treated as unwanted legacy single-stream traffic.

A `QuicStream` can itself be wrapped in the common `SocketStreamAdapter`. This is
qualified in dev3 so consumers which receive a particular QUIC child stream do
not need a second byte-stream API.

## Negotiation

`QuicSocketOfferProvider` continues to advertise only the common socket shape:

```text
scheme      quic
family      QUIC_INET
stream      true
listener    true
sender      true
secure      true
multicast   false
```

The generic negotiation request does not contain QUIC-specific knobs.

## Qualification

```sh
OOREXX_ROOT=/path/to/oorexx/usr/local qualification/run_environment_test.sh
```

Qualification performs:

1. native C++ build against the supplied ooRexx headers;
2. native dependency check for OpenSSL;
3. temporary TLS test identity generation;
4. ooRexx address/socket contract test;
5. SocketProvider v0.1-dev14 negotiation test;
6. real binary-safe QUIC client/server loopback through the generic socket path;
7. a real two-stream QUIC multiplex test.

The multiplex test opens two independent bidirectional streams on one connection,
observes distinct QUIC stream IDs, accepts both on the peer, carries binary-safe
payloads over both, and exercises `SocketStreamAdapter` on one child stream.
