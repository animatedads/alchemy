# ooRexx Socket Provider v0.1-dev14

Standard socket acquisition for RexxOS components.

```text
logical service name
        |
        v
SocketAddressProvider
        |
        v
SocketAddress
        |
        v
SocketProvider / SocketSelector
        |
        +-- TCP  family -> RxSock
        +-- UDP  family -> RxSock datagram or injected RFC 3678 provider
        +-- UNIX family -> ooRexx Unix Socket
        +-- TLS  family -> base stream + TLS engine + key authority
        +-- XTP  family -> libxtp backend (current dev17 stream+multicast)
        +-- NORM family -> external ooRexx NORM dev3/libnorm backend
```

The names `SocketSelector`, `SocketEndpoint`, `SocketAddress`, and
`SocketCapabilities` deliberately align this component with the Optimised Queue
Transport abstraction. `SocketSelector` is a `SocketProvider`, not a second
routing/selection authority.

## dev14 — accepted peer address identity

`ProviderSocketListener~accept()` and `~tryAccept()` now preserve an accepted
provider peer's own `address` object when one is supplied. Older providers that
do not expose an accepted address retain the historical listener-address fallback.
This is a generic socket-object fix required by QUIC and equally applicable to
XTP/TCP/other providers; no protocol-specific API was added.


## Core rule

Application code asks only for:

```rexx
listener = sockets~listener("queue.control")
sender   = sockets~sender("queue.control")
```

It does not construct `.Socket`, `.UnixSocket`, TLS key files, or XTP addresses.

## Address families

### TCP / INET

```rexx
.SocketAddresses~tcp("192.0.2.10",9000)
```

The address provider supplies the dotted IP text required by RxSock. Native
construction is in `RxSockSocketBinding.cls`, not in the core provider.

### UNIX

```rexx
.SocketAddresses~unix("/run/rexxos/queue.sock")
```

Native construction is in `UnixSocketBinding.cls` and uses the existing
`.UnixSocket` / `.UnixAddress~pathname()` API.

### TLS / TLS_INET — family example

TLS is implemented as a complete example of how a new family plugs into the
standard provider without changing application code:

```rexx
addresses~register(
    "queue.control",
    .SocketAddresses~tls(
        "192.0.2.24",
        7443,
        "queue/control-prod"
    )
)
```

The address carries only `queue/control-prod`, a security-profile reference.
It carries no certificate bytes, private keys, trust bundles, or key filenames.

`TLSSocketFamily.cls` composes three authorities:

```text
base stream binding
        +
TLS engine
        +
SocketSecurityMaterialProvider
```

`SocketSecurityMaterialProvider` is the one place that resolves the profile to
key/certificate/trust material. That implementation can later be backed by
Secret Broker or another managed platform key authority.

The TLS family advertises:

```text
scheme        tls
addressFamily TLS_INET
stream        true
listener      true
sender        true
secure        true
multicast     false
```

See `examples/tls_family_example.rex` and `tests/test_tls_family_scheme.rex`.

### XTP

XTP remains deliberately opaque in this package:

```rexx
.SocketAddresses~xtp("02:AA:BB:CC:DD:EE")
.SocketAddresses~xtp("group:rexxos-discovery",.true)
```

The XTP backend may retain station/MAC-like or group-shaped identity, but the
current dev14 executable profile explicitly advertises multicast=false. Address
syntax is therefore not implementation evidence.

## Dependency isolation

`SocketProvider.cls` has no native socket dependency. Concrete bindings are
loaded separately:

- `RxSockSocketBinding.cls` -> `socket.cls` / RxSock
- `UnixSocketBinding.cls` -> `unixsocket.cls`
- `TLSSocketFamily.cls` -> injected base binding, TLS engine, and security material authority
- `XtpSocketProvider.cls` -> current XTP dev17 ooRexx adapter; `libxtp` / `liboorexx_xtp_native.so` remain external runtime dependencies and XTP retains route/carrier/multipath authority
- `RxSockUdpBinding.cls` -> ordinary IPv4 datagrams through RxSock

That allows the provider/address contract to be rolled into components before
every platform has every transport installed.

## Qualification

The supplied ooRexx 5.3.0 r13196 `.deb` was extracted and used directly for
qualification. See `VALIDATION.txt`.

## dev3 — Socket gets Intentions

Socket selection now has an explicit semantic negotiation layer rather than making
applications pick a carrier.  `SocketIntentionPort` dynamically discovers the
socket-management intentions and asks `SocketNegotiator` to resolve a
`SocketNegotiationRequest` against **current** offers every time.

The caller describes requirements such as:

```text
logical service = queue.control
role            = SENDER
stream           = required
secure           = required
multicast        = not required
local-only       = false
```

It does not say `TLS` or `TCP`.  The current offer set may contain Unix, XTP, TLS
and TCP endpoints.  Hard requirements remove unsuitable offers; deterministic
policy ranks the remaining offers.  The selected `SocketAddress` then goes back
to the ordinary `SocketProvider`, which remains the sole socket-acquisition
authority.

```text
human / service goal
        |
        v
Intention Service
        |
SocketIntentionPort   <-- dynamic discover()
        |
SocketNegotiationRequest
        |
SocketNegotiator <---- current offer providers / topology / policy
        |
SocketNegotiationSelection
        |
SocketProvider~senderAt() / ~listenerAt()
        |
TCP | UNIX | TLS | XTP binding
```

`SocketOfferProvider` is deliberately dynamic.  An XTP adapter can therefore expose
current route-table evidence, an MU/MI deployment provider can expose local Unix
endpoints, and a registry/provider can expose TCP/TLS endpoints.  No permanent
startup catalogue is assumed.

The built-in policy prefers local Unix when it satisfies the request and otherwise
orders XTP ahead of TLS/TCP for internal transport.  Those are preferences, never
permission to weaken hard requirements.  For example, a request requiring security
selects TLS in the supplied family example because the current XTP capability does
not claim a secure socket family.

The socket component publishes four semantic management intentions:
`NEGOTIATE_SOCKET`, `OPEN_SOCKET`, `LISTEN_SOCKET`, and
`EXPLAIN_SOCKET_SELECTION`.  The descriptors are ordinary objects so an Intention
Service revision can register them without this low-level package vendoring or
modifying Intention Service itself.


## dev4 — role-specific negotiated capability

Socket negotiation now permits an offer to override the broad family capability with
current implementation evidence. This is required for XTP dev9: the native library has
a persistent receive-side Listener, but the current ooRexx `XtpSocketBackend~listener()`
deliberately fails closed until a persistent Rexx/native listener binding can preserve
replay state. Therefore the current Rexx-visible XTP offer advertises sender=yes and
listener=no.

`XtpDev9SocketOfferProvider` is the convenience adapter for that state. An Intention
requesting a sender may select XTP; an Intention requesting a listener will reject the
XTP offer and choose another qualified family or return `NO_OFFER`.

Multicast is also endpoint-specific now: `requireMulticast` requires both a family that
supports multicast and an address whose `multicast` flag is true. A unicast XTP route
can no longer accidentally satisfy a multicast request.


## dev5 — XTP dev10 closes the listener gap

XTP dev10 now supplies an in-process ooRexx native binding for both sender and
persistent listener. `XtpProviderListener` retains a private native listener handle
across `accept()` calls, while `libxtp` retains replay and carrier state.

At dev5 time the package carried historical XTP capability projections that
marked multicast as available. The later Spiral 1 evidence cross-check against
libxtp dev12 showed that the executable XTP profile still excludes multicast,
so those historical projections are retained only as history and are superseded
by the dev10 evidence correction below. Current profiles are:

```text
XTP dev9 Rexx bridge   sender=yes  listener=no   multicast=no
XTP dev10 Rexx bridge  sender=yes  listener=yes  multicast=no
XTP dev12 Rexx bridge  sender=yes  listener=yes  multicast=no
```

The family address model can still retain XTP group identity, but current
implementation capability is authoritative for negotiation.
`XtpDev10SocketOfferProvider` / `XtpDev12SocketOfferProvider` therefore fail
closed for multicast until libxtp provides and qualifies that native path.

The historical dev9 profile remains available so older deployed nodes continue
to fail closed for XTP listener negotiation rather than being overclaimed.


## dev6 — discovery-first Socket Intentions

Socket Intentions now follow the portfolio's current dynamic-discovery rule.

`SocketDynamicIntentionProvider~discover(request, context)` performs a fresh bounded
observation every time. `SocketOfferObservation` gets a monotonically increasing
generation and contains only current candidate/rejection evidence.

`OPEN_SOCKET` and `LISTEN_SOCKET` are no longer advertised as permanently available.
They appear only when the current request can actually be satisfied. If a Unix
endpoint disappears, an XTP route is withdrawn, a TLS profile/address becomes
unavailable, or a role capability changes, the next discovery turn reflects that
without restarting the Intention layer.

This is deliberately discovery-first:

```text
human / service meaning
        |
        v
SocketNegotiationRequest
        |
        v
fresh provider observation
        |
        v
SocketIntentionDiscoverySnapshot
        |
        +-- NEGOTIATE_SOCKET
        +-- EXPLAIN_SOCKET_SELECTION
        +-- OPEN_SOCKET   only when sender feasible now
        `-- LISTEN_SOCKET only when listener feasible now
```

No LLM is needed for capability refresh and no discovered endpoint is cached as
permanent conversational truth.


## dev7 — selected Socket stream view

`SocketStreamAdapter` exposes `READ`, `WRITE`, `PUMP`, and `CLOSE` over an
already-selected `ProviderSocketConnection`. It does not reopen or reselect
transport.

This provides the object contract required by Debug Socket Transport while
preserving the exact `SocketAddress` object by identity.

Existing `send` / `recv` users remain unchanged.

## dev8 NORM family

Dev8 adds NORM as a first-class transport/scheme/address family while preserving provider isolation. `SocketAddresses~norm()` retains group/session address, port, interface, optional SSM source and node id. NORM session, group membership, FEC, repair, event and native descriptor mechanics remain in the external NORM provider.

`NormDev1SocketOfferProvider` lets dynamic negotiation compare a current NORM offer with XTP/TCP/TLS/UNIX offers. A message-oriented multicast request can select NORM; a stream requirement rejects it and can select XTP instead.


## dev9 — multicast membership is an object, not a socket side effect

Spiral-1 multicast work now has an explicit common contract. `SocketAddress` still identifies the transport endpoint, while `SocketMulticastMembershipRequest` describes joining that multicast address on an interface with an optional source filter and scope. `SocketProvider~join()` returns a `SocketMulticastMembership`; `listenerOn()` attaches a listener without transferring membership ownership.

```rexx
request = .SocketMulticastMembershipRequest~new(address, "eth0", source, scope)
membership = sockets~joinAt(address, request)
listener = sockets~listenerOn(membership)
...
listener~close              /* membership is still joined */
membership~leave
```

Bindings that do not implement explicit membership fail closed. The common layer does not issue `IP_ADD_MEMBERSHIP`, NORM calls, or XTP group operations itself. NORM dev2 is the first binding to consume this contract.


## dev10 — UDP/IP multicast COTS family route and capability truth

Spiral 1 now has a direct IPv4 UDP/IP family beside NORM and XTP. `SocketAddresses~udp()` represents ordinary UDP endpoints and `SocketAddresses~ipMulticast()` represents an explicitly multicast UDP group endpoint. The common provider still does not implement IP multicast itself. `RexxUdpSocketBinding` delegates sender/listener and explicit `socket.multicast.membership/0.1` operations to an injected backend.

This is intentionally the same isolation shape already used by NORM dev2: application code retains the complete `SocketAddress` and `SocketMulticastMembershipRequest` objects while the backend maps them to the COTS/native interface. RFC 3678 membership mechanics therefore remain below SocketProvider. A unicast UDP address cannot satisfy a multicast requirement because endpoint `multicast` remains a hard gate.

The Library cross-check also exposed a historical overclaim. Earlier Socket Provider profiles marked XTP multicast as available, but the current libxtp dev12 executable protocol profile still explicitly lists multicast outside the implemented subset. Dev10 therefore stops advertising XTP multicast in family and dev9/dev10/dev12 implementation capability profiles. XTP sender/listener remains available; multicast requests fail closed until a native XTP multicast path is actually qualified. Historical `SocketAddress` group identity is retained, but address syntax is not treated as implementation evidence.


## dev11 — collision merge and current provider boundary

Dev11 reconciles the colliding dev10 lines rather than choosing one and losing
the other. It carries forward all of the following at the same common boundary:

- UDP/INET and explicit IP multicast endpoint modelling;
- provider-neutral multicast membership with explicit join/leave lifetime;
- concrete ordinary RxSock UDP datagrams and ephemeral listener port `0`;
- provider-neutral descriptor/readiness delegation used by NORM dev3;
- the corrected XTP dev14 capability truth (`sender=yes`, `listener=yes`,
  `multicast=no`);
- dynamic per-turn intention/offer discovery;
- TLS security-profile authority and `SocketStreamAdapter`;
- exact `SocketAddress` object preservation.

The merge deliberately keeps `RexxUdpSocketBinding` and `RxSockUdpBinding` as
different classes. The former is an injected backend seam used by multicast
providers; the latter is a concrete RxSock IPv4 datagram implementation.

Current sibling providers remain separate components rather than being folded
into the core: RxSock6/IPv6, QUIC, NORM dev3, the RFC 3678 IP multicast provider,
and XTP dev14. See `CURRENT_PROVIDER_COMPATIBILITY.md`.

## dev12 — current XTP dev14 provider merged

The current XTP ooRexx provider adapter is now shipped directly as
`src/XtpSocketProvider.cls`.  Applications using the standard socket route no
longer need to copy the adapter out of the XTP package:

```rexx
addresses=.RegisteredSocketAddressProvider~new
addresses~register('fabric.control',.SocketAddresses~xtp('PEER'))
sockets=.SocketSelector~new(addresses)
sockets~registerBinding('XTP',.RexxXtpSocketBinding~new(.XtpSocketBackend~new))
endpoint=sockets~sender('fabric.control')
```

The native implementation is still supplied by XTP (`liboorexx_xtp_native.so`
and `libxtp`).  This is a provider merge, not a transfer of XTP transport
semantics into Socket Provider.  `XtpSocketBackend` also retains the dev14
multipath sender/listener access route for callers explicitly using XTP
facilities.  XTP multicast remains false until libxtp implements and qualifies
it.


## dev13 — current XTP dev17 multicast-stream projection

The common selector remains protocol independent. XTP dev17 is represented by
`stream=true` and `multicast=true`; a multicast-stream request is therefore the
conjunction `requireStream=true` + `requireMulticast=true`. No XTP-specific
`multicastStream` property is added to the common API. Historical XTP profiles
remain available for compatibility and keep their original capability truth.

The bundled `XtpSocketProvider.cls` is taken from XTP dev17. libxtp remains the
authority for L2/L3/L4 route selection, wire filters, multipath, ALLOC pacing,
and multicast reject suppression.
