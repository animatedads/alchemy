# Socket Provider — RxSock6 binding

This package is deliberately an **adapter**, not a fork of Socket Provider.

## Repository snapshot versus current estate

The executable source currently published in this directory is the historical
**v0.1-dev1** adapter over `rxsock6 0.1.1`.  It must not be mistaken for the
current qualified estate.

The current reconciled estate, recorded by the 2026-10-13 Transport/COTS
evidence, is:

- Socket Provider **v0.1-dev16** as the common isolation boundary;
- RxSock6 Socket Provider **v0.1-dev3**;
- `rxsock6 0.1.2`;
- TCP/IPv6 live qualification on ooRexx 5.3.0 r13196;
- UDP/IPv6 live qualification on `::1`, preserving the peer
  `.Inet6Address` object;
- IPv6 multicast supplied by the separate IP Multicast **v0.1-dev2** RFC 3678
  provider path, not by RxSock6 dev3.

The exact dev3 executable/source delivery still needs to be synchronized into
this repository.  Until that archive/source closure is available, do **not**
reconstruct dev3 code from prose and do not relabel the dev1 source tree as
dev3.

See `CURRENT_ESTATE.md` and the
`spheres/oorexx_rxsock6_gopher_sphere_v0.1` continuity sphere.

## Important semantic choice

IPv6 is not a new application protocol.

```text
semantic scheme:  tcp / udp
provider binding: TCP6 / UDP6
address family:   INET6
native object:    Inet6Address
native socket:    Socket6
```

Socket Intentions may therefore request ordinary TCP stream or UDP datagram
semantics while provider selection retains IPv4/IPv6 implementation choice.

## Object preservation

The preferred IPv6 address routes carry the exact `.Inet6Address` object.
Address, port, scopeId and flowInfo stay on the object rather than being
flattened into a generic string.  The current dev3 UDP6 evidence also preserves
the peer `.Inet6Address` returned by datagram receive.

## Multicast boundary

RxSock6 dev3 does **not** advertise multicast membership.

IPv6 ASM/SSM/full-state filtering is supplied by IP Multicast v0.1-dev2 using
the common provider-neutral membership boundary and native RFC 3678
`MCAST_*` operations at `IPPROTO_IPV6`.  MLDv2 (RFC 3810) remains host IPv6
stack behaviour below that socket interface.  Host membership state was
observed during qualification; this is not an ooRexx MLDv2 implementation or a
packet-conformance claim.

## Why isolated?

RxSock6, QUIC, NORM, RFC 3678 multicast and XTP remain sibling providers below
the common Socket Provider boundary.  This package must not modify
`SocketProvider.cls` merely to add IPv6 capability.

## Repository synchronization status

The dev1 tests in this directory remain evidence for the historical checked-in
snapshot.  Current estate qualification is documented separately until the
exact dev3 source delivery can be imported without invention.

## Deployment preflight

`tests/deployment_preflight.sh` now provides a fail-closed target check for the
installed IPv6 socket closure. It reruns the checked-in TCP6 provider contract /
negotiation / live loopback tests and adds a direct `socket6.cls` UDP6
connected-datagram loopback test.

The preflight deliberately reports
`RXSOCK6_PREFLIGHT_PROVIDER_DEV3_SOURCE=NOT_ASSERTED`: proving that the target
native class layer can perform UDP6 is not the same as claiming that the missing
RxSock6 Socket Provider dev3 source has been synchronized.

See `DEPLOYMENT_PREFLIGHT.md`.
