# Socket Provider dev11 collision merge

The 7 October 2026 work produced two incompatible `v0.1-dev10` heads plus the
first Spiral-1 multicast head.  Dev11 is the reconciliation point; it is not a
new selection architecture.

Merged source lines:

- `972255739d5284bfdfabf657c79f0f59440606259ed73602eaa802efadd7eb12`
  — UDP/IP multicast + RFC 3678 isolation + corrected XTP multicast capability.
- `b47456c4ad9944361f2cc2e387fc7a363979086973464c98d350f8f2b4cfd7b5`
  — concrete RxSock UDP datagram endpoint/provider work.
- `69e692cb459cba24e920446cdcaa452a7c335db33172e320210e9b5f43b77679`
  — provider-neutral descriptor/readiness (`descriptor`, `waitReady`,
  `tryAccept`, `waitDrained`) used by NORM dev3.

Conflict decisions:

1. **XTP capability truth wins.** Current XTP dev14 advertises sender/listener
   but `multicast=false`.  The older branches that reintroduced
   `multicast=true` are not carried forward.
2. **UDP remains first-class.** Ordinary RxSock UDP and explicit multicast UDP
   coexist.  Port 0 is legal for listener binding; senders still require a
   non-zero remote port in `RxSockUdpBinding`.
3. **Both UDP factory call shapes survive.** Dev11 accepts the pre-collision
   `(host, port, logicalName, metadata)` form and the datagram-branch
   `(host, port, multicast, logicalName, metadata)` form.
4. **Both multicast factory call shapes survive.** The original logical-name
   form and the interface/source-aware form are retained.
5. **Generic and concrete UDP bindings are different things.**
   `RexxUdpSocketBinding` remains the injected provider-neutral binding used by
   RFC 3678/IP multicast providers; `RxSockUdpBinding` is the concrete ordinary
   IPv4 datagram binding.
6. **Descriptor/readiness is delegation, not a new event loop.** NORM owns
   `NormGetDescriptor()` and its readiness mechanics; Socket Provider only
   exposes the transport-neutral access route.
7. **Sibling providers stay siblings.** RxSock6/IPv6, QUIC, NORM and the RFC
   3678 IP multicast provider consume this common boundary.  They are included
   in the companion roll-up but are not folded into `SocketProvider.cls`.
