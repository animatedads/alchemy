# RxSock6 current estate reconciliation

Date: 2026-10-23

This file records the difference between the source currently present in this
GitHub directory and the newer qualified estate retained in project evidence.

## Current authority

| Item | Current reconciled state |
|---|---|
| Socket Provider | v0.1-dev16 |
| RxSock6 Socket Provider | v0.1-dev3 |
| RxSock6 native/class layer | 0.1.2 |
| Runtime qualification | ooRexx 5.3.0 r13196 |
| TCP6 | LIVE PASS |
| UDP6 | LIVE PASS |
| IPv6 multicast | IP Multicast v0.1-dev2 sibling provider |
| MLDv2 | host-stack behaviour below RFC 3678; not reimplemented |

RxSock6 dev3 adds the IPv6 datagram route:
`Inet6DatagramSocketAddress`, `RxSock6DatagramBinding`,
`RxSock6DatagramEndpoint`, `Sock6SendTo` and `Sock6RecvFrom`.
The live `::1` datagram qualification preserves the peer
`.Inet6Address` object.

IP Multicast v0.1-dev2 closes the separate IPv6 multicast access gap using the
same family-aware RFC 3678 abstraction for IPv4 and IPv6.  IPv6 ASM, SSM and
`MCAST_MSFILTER` were qualified at `IPPROTO_IPV6`; a live
`ff02::115` path was exercised and host membership was visible in
`/proc/net/igmp6`.

## Repository state

The checked-in adapter source under this directory is still v0.1-dev1.  The
project evidence proves a later qualified dev3 estate, but the exact dev3 source
archive is not presently synchronized here.

This is a source-control gap, not permission to synthesize the missing source.

## Missing work

1. Locate the exact RxSock6 provider v0.1-dev3 source/delivery and its matching
   rxsock6 0.1.2 source/class/native closure.
2. Import that exact source over the historical dev1 snapshot with provenance.
3. Preserve the sibling-provider rule: do not fold RxSock6 into
   `SocketProvider.cls`.
4. Preserve native `.Inet6Address` identity for TCP6 and UDP6.
5. Keep multicast membership out of RxSock6 dev3; use IP Multicast v0.1-dev2
   for RFC 3678 IPv6 membership.
6. Re-run TCP6 and UDP6 live qualification against Socket Provider dev16 and
   ooRexx 5.3.0 r13196 after source synchronization.
7. Do not claim an ooRexx MLDv2 implementation.  MLDv2 remains OS host-stack
   behaviour below the qualified IPv6 RFC 3678 socket route.
