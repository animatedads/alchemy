# Spiral 1 COTS interface grid — Socket Provider dev11 reconciliation

Evidence states remain distinct: **ACCESS**, **CONTRACT PASS**, **LIVE PASS** and
**INFRASTRUCTURE** are not interchangeable. A protocol/address model is never
used as evidence that the executable provider implements a feature.

| Stack/interface | ooRexx access route | Isolated provider/binding | Native/COTS endpoint | Current evidence |
|---|---|---|---|---|
| TCP / IPv4 | `SocketAddresses~tcp` -> `SocketSelector` | `RxSockTcpBinding` | RxSock / OS TCP | ACCESS; contract; live test remains environment-selectable here |
| TCP / IPv6 | `Inet6SocketAddress` -> `SocketSelector` | sibling `RxSock6SocketBinding` | `rxsock6 0.1.1` / AF_INET6 | sibling provider has real loopback qualification; complete `Inet6Address` retained |
| UDP / IPv4 datagram | `SocketAddresses~udp` -> `SocketSelector` | `RxSockUdpBinding` | RxSock / OS UDP | ACCESS; concrete datagram route retained by dev11 merge |
| Unix-domain sockets | `SocketAddresses~unix` -> `SocketSelector` | `UnixSocketBinding` | ooRexx Unix Socket / AF_UNIX | ACCESS; contract; live Unix remains environment-selectable here |
| TLS / TLS_INET | `SocketAddresses~tls` -> `SocketSelector` | `TLSSocketFamily` | injected TLS engine + key authority | ACCESS; security-profile/family contract |
| QUIC | `QuicSocketAddress` -> `SocketSelector` | sibling `RexxQuicSocketBinding` | OpenSSL QUIC / UDP / TLS 1.3 | sibling provider owns native/live qualification |
| XTP sender/listener | opaque XTP `SocketAddress` -> `SocketSelector` | XTP backend | libxtp dev14 | ACCESS; current sender/listener profile; XTP owns route/carrier qualification |
| XTP multicast | XTP group-shaped address may be retained | XTP backend | libxtp dev14 | **NOT ADVERTISED**: current executable capability is multicast=false |
| NORM reliable multicast | `SocketAddresses~norm` + common membership | `RexxNormSocketBinding` | NRL libnorm dev3 | explicit membership + descriptor/readiness; NORM owns native qualification |
| IPv4 IP multicast endpoint | `SocketAddresses~ipMulticast` | injected `RexxUdpSocketBinding` backend | sibling IP multicast provider | ACCESS; endpoint hard gate retained |
| Multicast membership lifetime | `SocketMulticastMembershipRequest` -> `joinAt` -> `listenerOn` -> `leave` | provider-neutral membership contract | NORM or RFC 3678 provider | listener lifetime remains independent of membership |
| RFC 3678 multicast socket API | `IpMulticastMembershipAccess` | sibling IP multicast native binding | `MCAST_JOIN_GROUP`, source-group operations, `MCAST_MSFILTER` | sibling package owns LIVE PASS |
| IGMPv3 host membership | indirect below RFC 3678 access | host IP stack | OS IPv4 multicast stack | access route only; no Rexx IGMP implementation claim |
| PIM-SM routing | COTS witness/control-plane provider | routing infrastructure | RFC 7761 / STD 83 router/daemon | INFRASTRUCTURE; no fabricated application socket API |

Dev11 is the common isolation boundary. RxSock6, QUIC, NORM, RFC 3678 multicast
and XTP remain separate providers/transports so their lifecycle and failure
semantics do not collapse into one monolith.

## dev12 XTP access-class witness

The standard XTP row now has its concrete ooRexx access adapter in this package:
`SocketAddresses~xtp -> SocketSelector -> RexxXtpSocketBinding -> XtpSocketBackend -> oorexx_xtp_native/libxtp dev14`.
The adapter retains native sender/listener and XTP-specific multipath access;
multicast remains explicitly false.
