# Architecture

```text
application / service object
        |
SocketSelector + SocketAddress
        |
SocketMulticastMembership
        |
ProviderSocketListener / ProviderSocketConnection
        |
NormSocketBackend
        |
NormNativeApi
        |
liboorexx_norm_native.so
        |
NRL libnorm
        |
UDP / IPv4 or IPv6 multicast
        |
wire
```

NORM owns protocol mechanics; SocketProvider owns the application-visible acquisition contract. Membership lifetime is independent from listener lifetime. `NormGetDescriptor()` is projected upward as the provider descriptor; readiness is bounded with `poll(2)` and events are drained nonblocking. Event scheduling remains an external/common-runtime responsibility.

The Rexx address object retains group, port, interface, optional SSM source and node identity. It is never flattened to a generic `host:port` string.
