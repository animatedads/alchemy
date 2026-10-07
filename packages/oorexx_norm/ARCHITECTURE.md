# Architecture

```text
application object / bytes
        |
SocketAddressProvider
        |
SocketSelector / SocketProvider
        |
RexxNormSocketBinding
        |
NormSocketBackend
        |
liboorexx_norm_native
        |
libnorm 1.5.x API
        |
UDP/IP multicast -> wire
```

NORM is a transport provider, not a semantic protocol. Address selection, policy and the portfolio's application contract remain outside libnorm. NORM-specific group joining, interface selection, SSM, TTL, FEC, repair, sender/receiver state and event processing remain below the provider boundary.

The native NORM descriptor is exposed on concrete NORM sockets/listeners so the common event-runtime integration can consume readiness without polling. It is not required by ordinary send/accept callers.
