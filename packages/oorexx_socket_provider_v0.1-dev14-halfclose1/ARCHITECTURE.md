# Architecture

## Optimised Queue Transport alignment

The recent Queue Transport work established the transport-independent objects:

```text
SocketSelector
SocketEndpoint
SocketAddress
SocketCapabilities
```

This package uses those semantics while preserving the requested provider names:
`SocketProvider` is the acquisition/selection object and `SocketSelector` is its
queue-transport-compatible class name. There is one authority, not two competing
selectors.

Queue framing/filtering remains above this socket family layer. A `WireFilterChain`
may encode/compress/encrypt queue frames before a transport sequences or sends
them; that is distinct from TLS, which is a socket family providing a secured
stream endpoint.

## TLS as the family proof

TLS demonstrates the full extension pattern without requiring XTP to exist:

```text
SocketAddressProvider
  -> TLS SocketAddress(host, port, securityProfile)
  -> SocketProvider
  -> TLSSocketBinding
       -> base stream binding (normally RxSock TCP)
       -> SocketSecurityMaterialProvider
       -> TLSEngine
  -> secured SocketEndpoint
```

The address side owns where the endpoint is and which security profile governs
it. The security authority owns key/certificate/trust material. The TLS engine
owns TLS protocol mechanics. The application owns none of these details.

When `rexx_sock_xtp` is written, it follows the same pattern: add/bind a family;
do not alter queue/application callers.


## Negotiated implementation capability (dev4)

Family capability and current binding capability are deliberately distinct. The
address model may preserve XTP group identity, but current executable capability is
authoritative. XTP dev14 advertises sender/listener and explicitly does not advertise
multicast. Negotiation must not infer availability from protocol theory or address
syntax.

This is the same rule that applies to TLS: a family may be supported in principle, but
a concrete offer is valid only when its address, security profile, binding and current
authority make the requested role feasible.


## XTP dev10 implementation capability

The native ooRexx XTP package now removes the shell boundary for both roles. A
Socket Intention must therefore derive feasibility from the implementation
profile attached to the current offer, not from a stale version-wide assumption.

```text
semantic requirement
   -> current XTP route/address evidence
   -> current Rexx binding capability
   -> hard role/multicast/security gates
   -> deterministic ranking
   -> SocketProvider acquisition
```

`SocketCapabilities` describes what the current binding can actually perform.
`SocketAddress.multicast` describes what the selected endpoint actually is. Both
are required for multicast negotiation.


## Dynamic Intention discovery

Socket capability is live infrastructure state, not conversational memory.
Every semantic turn that may negotiate/open/listen must refresh provider evidence.

A discovery generation is an observation identity only. It is never permission to
reuse an old address. Acquisition still re-runs negotiation through `SocketProvider`
and transport-specific authorities.

This matches the wider RexxOS Intention discipline: safe discovery is authoritative;
the model, if present at all, interprets meaning rather than carrying operational state.


## dev11 collision reconciliation

The dev10 UDP/multicast and descriptor/readiness branches are now one source line.
Socket Provider exposes transport-neutral acquisition, membership and readiness; it
does not become the protocol implementation. Concrete UDP lives in
`RxSockUdpBinding.cls`; RFC 3678 multicast, NORM, IPv6/RxSock6, QUIC and XTP remain
provider-owned below the common boundary.
