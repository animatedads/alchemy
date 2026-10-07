# Socket Provider — RxSock6 binding v0.1-dev1

This package is deliberately an **adapter**, not a fork of Socket Provider.

It binds the uploaded `rxsock6 0.1.1` package into the estate `SocketProvider`
contract while preserving the rich ooRexx objects supplied by `socket6.cls`.

## Important semantic choice

IPv6 is not a new application protocol.

```text
semantic scheme:  tcp
provider binding: TCP6
address family:   INET6
native object:    Inet6Address
native socket:    Socket6
```

This means Socket Intentions may request ordinary TCP stream semantics and the
current offer set can choose either an IPv4 `INET` address or an IPv6 `INET6`
address without changing application meaning.

## Object preservation

`Inet6SocketAddress~nativeAddress` is the exact `.Inet6Address` object. Its:

- address
- port
- scopeId
- flowInfo

remain on the object and are not flattened into a generic string.

## Why isolated?

Library evidence shows Socket Provider dev9 has already overtaken the earlier
dev8 branch with UDP/IP-multicast work. This adapter therefore does not invent
another Socket Provider head. It can be applied to the current head once its
source is taken as the merge base.

## Qualification

The package contains:

- object contract test;
- semantic TCP negotiation across INET and INET6;
- real IPv6 listener/sender through SocketProvider and RxSock6.

The complete environment script is `tests/environment_test.sh`.
