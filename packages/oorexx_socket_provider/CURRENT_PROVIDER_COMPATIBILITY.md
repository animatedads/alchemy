# Current Socket Provider family compatibility — 2026-10-07

Dev12 preserves the dev11 collision-reconciled common provider boundary consumed by the current sibling
providers:

| Provider | Current package | Relationship to dev12 |
|---|---|---|
| IPv4 TCP | bundled `RxSockTcpBinding` | ordinary stream binding |
| IPv4 UDP | bundled `RxSockUdpBinding` | ordinary datagram binding |
| IPv4 multicast | `oorexx_ip_multicast_v0.1-dev1` | injected RFC 3678 membership backend |
| NORM | `oorexx_norm_v0.1-dev3` | reliable multicast + descriptor/readiness |
| IPv6 TCP | `oorexx_socket_provider_rxsock6_v0.1-dev1` + `rxsock6 0.1.1` | sibling `TCP6/INET6` binding; full `Inet6Address` retained |
| QUIC | `oorexx_quic_socket_provider_v0.1-dev1` | sibling QUIC binding; OpenSSL QUIC owns native protocol |
| XTP | `oorexx_xtp_v0.1-dev17` | XTP-owned route/carrier backend; stream + multicast qualified; ALLOC pacing and reject suppression remain libxtp-owned |

The common layer remains carrier-acquisition authority.  It does not absorb
NORM, QUIC, XTP, IPv6, or RFC 3678 implementation mechanics.

## dev12 XTP provider merge

`oorexx_xtp_v0.1-dev17/rexx/XtpSocketProvider.cls` is now included in the
Socket Provider distribution as `src/XtpSocketProvider.cls`.  Its native runtime
continues to be supplied by XTP dev17.  This closes the packaging collision
without duplicating libxtp or route authority.
