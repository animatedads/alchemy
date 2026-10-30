# ooRexx RxSock6 Gopher Sphere v0.1

Authoritative continuity sphere for the ooRexx RxSock6 IPv6 socket/provider
line.

The sphere preserves the boundaries that are easiest to lose during merges:

- stock RxSock remains IPv4-only; RxSock6 is a side-by-side sibling;
- `socket6.cls` extends `socket.cls`; it is not a cloned replacement;
- `.Socket6` / `.Inet6Address` preserve native object semantics;
- Socket Provider remains the common isolation boundary and is not amended just
  to add IPv6;
- RxSock6 dev3 owns TCP6 and UDP6 access, with object-preserving
  `.Inet6Address` identity;
- IP Multicast dev2, not RxSock6 dev3, owns the family-aware RFC 3678 multicast
  access route;
- MLDv2 is host IPv6 stack behaviour below RFC 3678 and is not represented as
  an ooRexx protocol implementation;
- repository source is currently behind the qualified estate, and missing dev3
  source must be synchronized exactly rather than reconstructed from prose;
- target deployment now has an executable fail-closed preflight that separately
  proves the checked-in TCP6 provider seam and native `socket6.cls` UDP6
  runtime closure without mislabelling the repository source;
- RxSock6 remains a sibling platform capability and does not replace the ED209
  XTP carrier contract for MI↔MU or MU↔MU internode communications.

Start with `gopher context rxsock6`.
