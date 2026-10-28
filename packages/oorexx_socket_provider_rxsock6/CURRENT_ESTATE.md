# RxSock6 current estate reconciliation

Date: 2026-10-28

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
same family-aware RFC 3678 abstraction for IPv4 and IPv6. IPv6 ASM, SSM and
`MCAST_MSFILTER` were qualified at `IPPROTO_IPV6`; a live
`ff02::115` path was exercised and host membership was visible in
`/proc/net/igmp6`.

## Exact package/source state

The exact Library package register still records
`oorexx_socket_provider_rxsock6_v0.1-dev1.zip` as the RxSock6 Socket Provider
package. Later transport reconciliation evidence records the qualified dev3 /
rxsock6 0.1.2 estate, but no exact dev3 source archive is present in the
synchronized Library or Git repository.

The checked-in adapter source under this directory is therefore still the
historical v0.1-dev1 source snapshot.

This is a source-control/provenance gap, not permission to synthesize, relabel
or reverse-engineer the missing source from evidence prose.

## Independent source-recovery result

Rasen Falcon request `REQ-00000695` asked CODEX-PC to perform a read-only
search for the exact v0.1-dev3 / rxsock6 0.1.2 source closure. Reply
`REQ-00000931` reported **not found**, explicitly confirming that the local
source tree must not be relabelled as dev3 and that no source was reconstructed.

A fresh CHATGPT Library sweep on 2026-10-28 independently reached the same
result: exact package evidence remains dev1, while dev3 appears only in later
qualification/reconciliation documents.

The recovery search is therefore closed as **independently confirmed absent
from the currently synchronized estate**, pending appearance or recovery of the
exact source delivery.

## Missing work

1. Recover the exact RxSock6 provider v0.1-dev3 source/delivery and its matching
   rxsock6 0.1.2 source/class/native closure from an authoritative source.
2. Import that exact source over the historical dev1 snapshot with provenance.
3. Preserve the sibling-provider rule: do not fold RxSock6 into
   `SocketProvider.cls`.
4. Preserve native `.Inet6Address` identity for TCP6 and UDP6.
5. Keep multicast membership out of RxSock6 dev3; use IP Multicast v0.1-dev2
   for RFC 3678 IPv6 membership.
6. Re-run TCP6 and UDP6 live qualification against Socket Provider dev16 and
   ooRexx 5.3.0 r13196 after source synchronization.
7. Do not claim an ooRexx MLDv2 implementation. MLDv2 remains OS host-stack
   behaviour below the qualified IPv6 RFC 3678 socket route.

## Rasen Falcon coordination

The authenticated Rasen Falcon project lane is
`oorexx_socket_provider_rxsock6`. It links the executable package artifact
`oorexx_socket_provider_rxsock6` and the continuity sphere
`oorexx_rxsock6_gopher_sphere_v0.1`.

CHATGPT owns the lane under `OWN-00000692`. The completed evidence chain is:

- `REQ-00000695` — locate exact dev3 / rxsock6 0.1.2 source closure;
- `REQ-00000931` — CODEX-PC reply: exact source closure not found;
- `REQ-00001097` — CHATGPT acceptance: independent Library sweep agrees.

The Rasen Falcon lane coordinates work; it does not supersede executable
artifact provenance, qualification evidence, or the sphere's authority rules.
